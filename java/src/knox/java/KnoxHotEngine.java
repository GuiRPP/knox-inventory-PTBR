package knox.java;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.luaj.kahluafork.compiler.FuncState;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaTableIterator;
import se.krka.kahlua.vm.LuaClosure;
import se.krka.kahlua.vm.Prototype;
import se.krka.kahlua.vm.UpValue;

/**
 * Runs one of Knox's Lua files again in a game that is going (the DEV reloader: the
 * author 2026-11-10, "see the changes live, not restart the game every time").
 * Knows nothing of the game itself - the Lua environment, its thread and the lists of
 * event handlers are handed in - so tools/hot runs this very code offline over every
 * file of the mod ("each file loaded twice").
 *
 * What a plain second run of a file gets wrong, and what this does about it:
 *  - events: every Events.X.Add of the file adds its handler once more (the game's own
 *    reloadLuaFile skips them instead, so the old code stays on). Here the file's old
 *    handlers give their places to its new ones: each new one takes the place of the old
 *    one written nearest to it in the file; an old one no new one takes stays (it was
 *    added under an "only once" check, or the file returned early). The same closure
 *    twice in a list stays once.
 *  - a run that fails: what it did before the error stays in (methods and the like), but
 *    the file's handlers and the game's functions it wraps stay the old ones. The file is
 *    run from Lua (pcall in a Lua function - wrapper()): only so does Kahlua close the
 *    upvalues of a run that failed halfway; run straight from Java they would stay slots
 *    of the stack, and a wrapper made before the error would read somebody else's values.
 *  - the game's functions the file wraps ("local vanilla = ISFoo.bar; function
 *    ISFoo:bar() ... vanilla(self) end"): run again, it would wrap its own wrapper -
 *    Knox's part twice. Before the run each such function gets back what was there
 *    before Knox (taken when Knox's Lua began to load - baseline()), so the file wraps
 *    the game's own again; one it does not wrap again this time keeps its old wrapper.
 *  - its tables: "KnoxFoo = ISPanel:derive(...)" or "KnoxFoo = {}" makes a new table,
 *    while the other files, the open windows (their metatable) and the file's own
 *    "local F = KnoxFoo" keep the old one. Here what the new table holds is poured
 *    into the old one (functions and values replaced, what only the old one has kept:
 *    "instance" and the like), the global points to the old one again, and every
 *    reference the new run made to the new table (its closures' upvalues, tables it
 *    filled, metatables) is turned to the old one. Tables inside such a table are
 *    matched the same way (a list is replaced as a whole: what it held before goes).
 */
public final class KnoxHotEngine {

    /**
     * Calls a Lua function as the host's pcall does: {true, what it returned...} or
     * {false, the error, the Lua stack}.
     */
    public interface Runner {
        Object[] call(LuaClosure f, Object[] args);
    }

    /** The Lua that runs a file: the file is its argument (why from Lua - see above). */
    public static final String RUN_LUA = "local f = ... return pcall(f)";
    private LuaClosure wrapper;

    private LuaClosure wrapper() {
        if (wrapper == null) {
            String oldFile = FuncState.currentFile, oldFull = FuncState.currentfullFile;
            try {
                FuncState.currentFile = "knox_hot_run";
                FuncState.currentfullFile = "knox_hot_run";
                wrapper = LuaCompiler.loadstring(RUN_LUA, "knox_hot_run", env);
            } catch (Throwable t) {
                throw new RuntimeException(t);
            } finally {
                FuncState.currentFile = oldFile;
                FuncState.currentfullFile = oldFull;
            }
        }
        return wrapper;
    }

    /** {true, the file's return} or {false, the error, the Lua stack}: the host's pcall around Lua's. */
    private Object[] runChunk(Runner runner, LuaClosure chunk) {
        Object[] r = runner.call(wrapper(), new Object[] {chunk});
        if (r == null || r.length == 0 || !Boolean.TRUE.equals(r[0])) return r;
        if (Boolean.TRUE.equals(r.length > 1 ? r[1] : null)) return new Object[] {Boolean.TRUE, r.length > 2 ? r[2] : null};
        return new Object[] {Boolean.FALSE, r.length > 2 ? r[2] : "?", r.length > 3 ? r[3] : null};
    }

    public final KahluaTable env;
    /** The game's lists of handlers, one per event (Event.callbacks). */
    private final java.util.function.Supplier<List<ArrayList<LuaClosure>>> events;
    /** The folder of Knox's Lua, as the game names files ("C:/.../media/lua/"): Knox's own files. */
    private String knoxRoot = "";

    /** What every function of the game's tables was before Knox's Lua began to load. */
    private final IdentityHashMap<KahluaTable, HashMap<Object, Object>> baseline = new IdentityHashMap<>();

    // the last run, for the report
    public String lastReport = "";
    public Object lastReturn;
    /** The last run's new tables and the old ones they were poured into (the offline test looks at them). */
    public final IdentityHashMap<KahluaTable, KahluaTable> lastMap = new IdentityHashMap<>();
    /** The last run kept the file's old handlers (it failed, or added none: an early return). */
    public boolean lastKeptHandlers;
    public final List<String> warnings = new ArrayList<>();
    /** The events' names, in the order of the lists (for the warnings); null - by number. */
    public java.util.function.Supplier<List<String>> eventNames;

    public KnoxHotEngine(KahluaTable env, java.util.function.Supplier<List<ArrayList<LuaClosure>>> events) {
        this.env = env;
        this.events = events;
    }

    public void setKnoxRoot(String root) {
        knoxRoot = norm(root);
        if (!knoxRoot.endsWith("/")) knoxRoot += "/";
    }

    public String knoxRoot() {
        return knoxRoot;
    }

    // ----------------------------------------------------------------------------------------
    // names

    static String norm(String path) {
        return path == null ? "" : path.replace('\\', '/');
    }

    static boolean same(String a, String b) {
        return a != null && b != null && norm(a).equalsIgnoreCase(norm(b));
    }

    static String fileOf(LuaClosure c) {
        return c == null || c.prototype == null ? null : c.prototype.filename;
    }

    private boolean isKnoxFile(String f) {
        if (f == null) return false;
        f = norm(f);
        if (!knoxRoot.isEmpty()) return f.regionMatches(true, 0, knoxRoot, 0, knoxRoot.length());
        return f.contains("/Knox/Knox");
    }

    /** KnoxPerf hands the game timed wrappers of Knox's handlers: its closures are someone else's. */
    private static boolean isWrapperFile(String f) {
        return f != null && norm(f).toLowerCase().endsWith("/knoxperf.lua");
    }

    static boolean isKnoxName(Object k) {
        return k instanceof String s && s.startsWith("Knox");
    }

    /** A handler is the file's: written in it, or a wrapper (KnoxPerf's, another mod's profiler) of one written in it. */
    private boolean handlerOf(LuaClosure c, String file, int depth) {
        String f = fileOf(c);
        if (same(f, file)) return true;
        if (depth >= 2) return false;
        if (isKnoxFile(f) && !isWrapperFile(f)) return false;   // another of Knox's files: its own
        if (c.upvalues == null) return false;
        for (UpValue u : c.upvalues) {
            Object v = u == null ? null : u.getValue();
            if (v instanceof LuaClosure lc && handlerOf(lc, file, depth + 1)) return true;
        }
        return false;
    }

    /** The line a handler is written on in `file` (a wrapper's: what it wraps). */
    private int lineOf(LuaClosure c, String file) {
        LuaClosure in = innerOf(c, file, 0);
        LuaClosure x = in != null ? in : c;
        return x.prototype != null && x.prototype.lines != null && x.prototype.lines.length > 0 ? x.prototype.lines[0] : 0;
    }

    private LuaClosure innerOf(LuaClosure c, String file, int depth) {
        if (same(fileOf(c), file)) return c;
        if (depth >= 2 || c.upvalues == null) return null;
        for (UpValue u : c.upvalues) {
            Object v = u == null ? null : u.getValue();
            if (v instanceof LuaClosure lc) {
                LuaClosure in = innerOf(lc, file, depth + 1);
                if (in != null) return in;
            }
        }
        return null;
    }

    // ----------------------------------------------------------------------------------------
    // the baseline

    /**
     * What the game's tables (and the game's global functions) hold now: called as Knox's Lua
     * starts to load. Knox's own globals are not the game's.
     */
    public int baseline() {
        baseline.clear();
        HashMap<Object, Object> globals = new HashMap<>();
        int n = 0;
        KahluaTableIterator it = env.iterator();
        while (it.advance()) {
            Object k = it.getKey();
            Object v = it.getValue();
            if (isKnoxName(k)) continue;
            globals.put(k, v);
            if (!(v instanceof KahluaTable t) || t == env || baseline.containsKey(t)) continue;
            HashMap<Object, Object> vals = new HashMap<>();
            KahluaTableIterator ti = t.iterator();
            while (ti.advance()) vals.put(ti.getKey(), ti.getValue());
            baseline.put(t, vals);
            n++;
        }
        baseline.put(env, globals);
        return n;
    }

    // ----------------------------------------------------------------------------------------
    // the run

    private static final class Hook {
        KahluaTable t;
        Object key;
        Object wrapper;
        Object base;
    }

    /** Knox's old wrapper inside another mod's (it wrapped the game's function after Knox did). */
    private static final class Inner {
        KahluaTable t;
        Object key;
        LuaClosure outer;
        UpValue up;
        LuaClosure wrapper;
    }

    /**
     * Runs `path` again (compiled anew from the file). `name` is the file's name as the game
     * gave it (its closures carry it); null - the path. Returns null when it went well, else
     * the error; lastReport says what was done.
     */
    public String run(String path, String name, Runner runner) {
        warnings.clear();
        lastReturn = null;
        lastMap.clear();
        lastKeptHandlers = false;
        if (name == null) name = norm(path);
        String shortName = name.substring(name.lastIndexOf('/') + 1);
        String src;
        try {
            src = Files.readString(Path.of(path), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "cannot read " + path + ": " + e;
        }
        if (!src.isEmpty() && src.charAt(0) == '\uFEFF') src = src.substring(1);
        LuaClosure chunk;
        String oldFile = FuncState.currentFile, oldFull = FuncState.currentfullFile;
        try {
            FuncState.currentFile = shortName;
            FuncState.currentfullFile = name;
            chunk = LuaCompiler.loadstring(src, shortName, env);
        } catch (Throwable e) {
            return String.valueOf(e.getMessage() != null ? e.getMessage() : e);
        } finally {
            FuncState.currentFile = oldFile;
            FuncState.currentfullFile = oldFull;
        }

        // the globals before (which tables were Knox's and which the game's)
        HashMap<Object, Object> before = new HashMap<>();
        Set<KahluaTable> foreign = Collections.newSetFromMap(new IdentityHashMap<>());
        KahluaTableIterator gi = env.iterator();
        while (gi.advance()) {
            Object k = gi.getKey(), v = gi.getValue();
            if (!(v instanceof KahluaTable t)) continue;
            before.put(k, v);
            if (!isKnoxName(k)) foreign.add(t);
        }

        // the game's functions the file wraps: back to what they were before Knox
        List<Hook> hooks = new ArrayList<>();
        List<Inner> inners = new ArrayList<>();
        List<KahluaTable> scan = new ArrayList<>(foreign);
        scan.remove(env);
        scan.add(env);
        for (KahluaTable t : scan) {
            KahluaTableIterator ti = t.iterator();
            List<Object[]> found = new ArrayList<>();
            HashMap<Object, Object> had = baseline.get(t);
            while (ti.advance()) {
                if (!(ti.getValue() instanceof LuaClosure c) || !same(fileOf(c), name)) continue;
                // (the globals: only a function of the game's the file wrapped - its own are its own)
                if (t == env && (had == null || !had.containsKey(ti.getKey()))) continue;
                found.add(new Object[] {ti.getKey(), c});
            }
            for (Object[] kv : found) {
                Hook h = new Hook();
                h.t = t;
                h.key = kv[0];
                h.wrapper = kv[1];
                boolean known = false;
                HashMap<Object, Object> b = baseline.get(t);
                if (b != null) {
                    Object base = b.get(h.key);
                    if (!(base instanceof LuaClosure bc && same(fileOf(bc), name))) {
                        h.base = base;
                        known = true;
                    }
                }
                if (!known) {
                    // (no baseline: the one function of somebody else's the wrapper holds - the original)
                    Object only = null;
                    int count = 0;
                    LuaClosure w = (LuaClosure) h.wrapper;
                    if (w.upvalues != null) {
                        for (UpValue u : w.upvalues) {
                            Object v = u == null ? null : u.getValue();
                            if (v instanceof LuaClosure lc && !same(fileOf(lc), name) && v != only) {
                                only = v;
                                count++;
                            }
                        }
                    }
                    if (count == 1) {
                        h.base = only;
                        known = true;
                    }
                }
                if (!known) {
                    warnings.add("wraps " + h.key + " of a table of the game - what it wrapped is not known: it may be wrapped twice now");
                    continue;
                }
                t.rawset(h.key, h.base);
                hooks.add(h);
            }
            // another mod wrapped it after Knox (QA 2026-11-10: knox2(other(knox(base)))): Knox's
            // old wrapper is taken out of the middle - the other's holds what Knox wrapped - and
            // the run wraps the whole once, from outside: knox2(other(base))
            HashMap<Object, Object> b = baseline.get(t);
            if (b == null) continue;
            List<Object[]> outer = new ArrayList<>();
            ti = t.iterator();
            while (ti.advance()) {
                if (ti.getValue() instanceof LuaClosure c && !same(fileOf(c), name) && !isKnoxFile(fileOf(c)) && c.upvalues != null
                    && b.containsKey(ti.getKey()) && b.get(ti.getKey()) != c) outer.add(new Object[] {ti.getKey(), c});
            }
            for (Object[] kv : outer) {
                LuaClosure f = (LuaClosure) kv[1];
                Object base = b.get(kv[0]);
                if (base instanceof LuaClosure bc && same(fileOf(bc), name)) continue;
                for (UpValue u : f.upvalues) {
                    if (u == null || open(u)) continue;
                    // (Knox's wrapper of this very function: one of the file's that holds what was there before Knox)
                    if (u.getValue() instanceof LuaClosure w && same(fileOf(w), name) && holds(w, base)) {
                        Inner in = new Inner();
                        in.t = t;
                        in.key = kv[0];
                        in.outer = f;
                        in.up = u;
                        in.wrapper = w;
                        u.setValue(base);
                        inners.add(in);
                        break;
                    }
                }
            }
        }

        // its handlers now
        List<ArrayList<LuaClosure>> lists = events.get();
        List<ArrayList<LuaClosure>> oldLists = new ArrayList<>();
        List<Set<LuaClosure>> oldOwn = new ArrayList<>();
        for (ArrayList<LuaClosure> l : lists) {
            Set<LuaClosure> own = Collections.newSetFromMap(new IdentityHashMap<>());
            for (LuaClosure c : l) if (c != null && handlerOf(c, name, 0)) own.add(c);
            oldLists.add(new ArrayList<>(l));
            oldOwn.add(own);
        }

        // the run
        Object[] r;
        try {
            r = runChunk(runner, chunk);
        } catch (Throwable e) {
            r = new Object[] {Boolean.FALSE, String.valueOf(e)};
        }
        boolean ok = r != null && r.length > 0 && Boolean.TRUE.equals(r[0]);
        String error = null;
        if (!ok) {
            StringBuilder sb = new StringBuilder();
            sb.append(r != null && r.length > 1 ? String.valueOf(r[1]) : "?");
            if (r != null && r.length > 2 && r[2] != null) sb.append("\n").append(r[2]);
            error = sb.toString();
        } else if (r.length > 1) {
            lastReturn = r[1];
        }

        // the handlers: the new ones in the old ones' places
        // (Add appends: what stands after the old list is what the run added - the file's
        // own and anybody else's; if the run took something out, by who was there before)
        int added = 0, gone = 0, total = 0;
        List<List<LuaClosure>> bases = new ArrayList<>(), fresh = new ArrayList<>(), others = new ArrayList<>();
        for (int i = 0; i < lists.size(); i++) {
            ArrayList<LuaClosure> l = lists.get(i);
            List<LuaClosure> old = i < oldLists.size() ? oldLists.get(i) : Collections.emptyList();
            boolean prefix = l.size() >= old.size();
            for (int j = 0; prefix && j < old.size(); j++) prefix = l.get(j) == old.get(j);
            List<LuaClosure> base = new ArrayList<>(), nw = new ArrayList<>(), other = new ArrayList<>();
            if (prefix) {
                base.addAll(old);
                for (int j = old.size(); j < l.size(); j++) {
                    LuaClosure c = l.get(j);
                    if (c != null && handlerOf(c, name, 0)) nw.add(c); else other.add(c);
                }
            } else {
                Set<LuaClosure> was = Collections.newSetFromMap(new IdentityHashMap<>());
                was.addAll(old);
                for (LuaClosure c : l) {
                    if (was.contains(c)) base.add(c);
                    else if (c != null && handlerOf(c, name, 0)) nw.add(c);
                    else other.add(c);
                }
            }
            bases.add(base);
            fresh.add(nw);
            others.add(other);
            total += nw.size();
        }
        Set<Prototype> freshProtos = null;   // (made when first needed: every function the new file has)
        Set<LuaClosure> inLists = null;
        List<LuaClosure> freshMade = null;
        int swappedSame = 0;
        List<String> names = eventNames != null ? eventNames.get() : null;
        // (failed: the old ones stay, the new ones go)
        boolean keepOld = !ok;
        lastKeptHandlers = keepOld || total == 0;
        for (int i = 0; i < lists.size(); i++) {
            ArrayList<LuaClosure> l = lists.get(i);
            Set<LuaClosure> own = i < oldOwn.size() ? oldOwn.get(i) : Collections.emptySet();
            List<LuaClosure> nw = fresh.get(i);
            if (own.isEmpty() && nw.isEmpty()) continue;
            // each new handler takes the place of the old one written nearest to it in the file;
            // an old one no new one takes stays (added under an "only once" check the run passed by)
            IdentityHashMap<LuaClosure, LuaClosure> newFor = new IdentityHashMap<>();
            boolean[] placed = new boolean[nw.size()];
            if (!keepOld && !nw.isEmpty()) {
                List<LuaClosure> olds = new ArrayList<>();
                for (LuaClosure c : bases.get(i)) if (own.contains(c)) olds.add(c);
                List<int[]> cand = new ArrayList<>();
                for (int a = 0; a < olds.size(); a++) {
                    for (int b = 0; b < nw.size(); b++) {
                        cand.add(new int[] {Math.abs(lineOf(olds.get(a), name) - lineOf(nw.get(b), name)), a, b});
                    }
                }
                cand.sort((x, y) -> x[0] != y[0] ? Integer.compare(x[0], y[0]) : x[1] != y[1] ? Integer.compare(x[1], y[1]) : Integer.compare(x[2], y[2]));
                boolean[] usedOld = new boolean[olds.size()];
                for (int[] c : cand) {
                    if (usedOld[c[1]] || placed[c[2]]) continue;
                    usedOld[c[1]] = true;
                    placed[c[2]] = true;
                    newFor.put(olds.get(c[1]), nw.get(c[2]));
                }
            }
            ArrayList<LuaClosure> out = new ArrayList<>(l.size());
            for (LuaClosure c : bases.get(i)) {
                LuaClosure n = newFor.get(c);
                if (n == null && !keepOld && own.contains(c)) {
                    // an old one of the file's no new one took (QA 2026-11-10): added while the
                    // game runs (start/stop - the new stop's Remove would not find the old one),
                    // added under an "only once" check, or no longer in the file
                    if (freshProtos == null) {
                        freshProtos = Collections.newSetFromMap(new IdentityHashMap<>());
                        protos(chunk.prototype, freshProtos);
                        inLists = Collections.newSetFromMap(new IdentityHashMap<>());
                        for (ArrayList<LuaClosure> x : lists) inLists.addAll(x);
                        freshMade = madeBy(name, freshProtos, foreign);
                    }
                    LuaClosure twin = same(fileOf(c), name) ? sameCode(c, freshMade, inLists) : null;
                    if (twin != null) {
                        // the same function, made anew by this run: it stands in (the new code's Remove finds it)
                        inLists.add(twin);
                        n = twin;
                        swappedSame++;
                    } else if (!sameCodeIn(c, name, freshProtos)) {
                        // (unchanged code that the run did not add: "only once" - stays quietly)
                        warnings.add(eventName(names, i) + ": the old handler of line " + lineOf(c, name)
                            + " stays - this run did not add it again (added while playing and changed since, or taken out of the file: restart to be sure)");
                    }
                }
                if (n != null) out.add(n); else out.add(c);
            }
            if (keepOld) gone += nw.size();
            else {
                for (int b = 0; b < nw.size(); b++) {
                    if (!placed[b]) {
                        out.add(nw.get(b));
                        added++;
                    }
                }
            }
            out.addAll(others.get(i));
            // the same closure twice: once
            Set<LuaClosure> seen = Collections.newSetFromMap(new IdentityHashMap<>());
            ArrayList<LuaClosure> dedup = new ArrayList<>(out.size());
            for (LuaClosure c : out) if (seen.add(c)) dedup.add(c);
            l.clear();
            l.addAll(dedup);
        }

        // the wrappers it did not put back: the old ones stay
        int rewrapped = 0;
        for (Hook h : hooks) {
            if (h.t.rawget(h.key) == h.base) h.t.rawset(h.key, h.wrapper); else rewrapped++;
        }
        // (inside another mod's: not wrapped again from outside - Knox's old one back inside)
        for (Inner in : inners) {
            if (in.t.rawget(in.key) == in.outer) in.up.setValue(in.wrapper); else rewrapped++;
        }

        // its tables: the new poured into the old
        IdentityHashMap<KahluaTable, KahluaTable> map = new IdentityHashMap<>();
        List<KahluaTable[]> pairs = new ArrayList<>();
        for (Map.Entry<Object, Object> e : before.entrySet()) {
            if (!isKnoxName(e.getKey())) continue;
            Object now = env.rawget(e.getKey());
            if (now instanceof KahluaTable nt && nt != e.getValue() && !foreign.contains(nt) && !map.containsKey(nt)) {
                pair(nt, (KahluaTable) e.getValue(), map, pairs, foreign, 0);
            }
        }
        for (KahluaTable[] p : pairs) pour(p[0], p[1], map);
        for (Map.Entry<Object, Object> e : before.entrySet()) {
            Object now = env.rawget(e.getKey());
            if (now instanceof KahluaTable nt && map.get(nt) == e.getValue()) env.rawset(e.getKey(), e.getValue());
        }
        if (lastReturn instanceof KahluaTable rt && map.containsKey(rt)) lastReturn = map.get(rt);

        lastMap.putAll(map);
        // every reference to a new table made by this run: to the old one
        int rebound = 0;
        if (!map.isEmpty()) rebound = rebind(name, map, foreign, lists);

        lastReport = "handlers " + (keepOld ? "kept" : "new " + total + ", more " + added + ", dropped " + gone + ", made anew " + swappedSame) + ", game functions wrapped again "
            + rewrapped + "/" + (hooks.size() + inners.size()) + ", tables kept " + pairs.size() + ", references turned " + rebound;
        return error;
    }

    // ----------------------------------------------------------------------------------------
    // tables

    private static boolean isList(KahluaTable t) {
        int n = t.len();
        if (n <= 0) return false;
        int count = 0;
        KahluaTableIterator it = t.iterator();
        while (it.advance()) {
            if (!(it.getKey() instanceof Double d) || d != Math.floor(d) || d < 1 || d > n) return false;
            count++;
        }
        return count == n;
    }

    private void pair(KahluaTable nt, KahluaTable ot, IdentityHashMap<KahluaTable, KahluaTable> map, List<KahluaTable[]> pairs,
                      Set<KahluaTable> foreign, int depth) {
        map.put(nt, ot);
        pairs.add(new KahluaTable[] {nt, ot});
        if (depth >= 4 || isList(nt)) return;
        KahluaTableIterator it = nt.iterator();
        List<Object[]> sub = new ArrayList<>();
        while (it.advance()) {
            if (it.getValue() instanceof KahluaTable nv) {
                Object ov = ot.rawget(it.getKey());
                if (ov instanceof KahluaTable o && o != nv && !foreign.contains(nv) && !foreign.contains(o)
                    && !map.containsKey(nv) && !map.containsValue(o)) {
                    sub.add(new Object[] {nv, o});
                }
            }
        }
        for (Object[] s : sub) pair((KahluaTable) s[0], (KahluaTable) s[1], map, pairs, foreign, depth + 1);
    }

    private static Object tr(Object v, IdentityHashMap<KahluaTable, KahluaTable> map) {
        if (v instanceof KahluaTable t) {
            KahluaTable o = map.get(t);
            if (o != null) return o;
        }
        return v;
    }

    private static void pour(KahluaTable nt, KahluaTable ot, IdentityHashMap<KahluaTable, KahluaTable> map) {
        if (isList(nt) && (ot.isEmpty() || isList(ot))) ot.wipe();
        KahluaTableIterator it = nt.iterator();
        List<Object[]> kv = new ArrayList<>();
        while (it.advance()) kv.add(new Object[] {it.getKey(), it.getValue()});
        for (Object[] e : kv) ot.rawset(e[0], tr(e[1], map));
        KahluaTable mt = nt.getMetatable();
        if (mt != null) ot.setMetatable((KahluaTable) tr(mt, map));
    }

    // ----------------------------------------------------------------------------------------
    // handlers the run did not add (added while playing, "only once")

    /** Does the closure hold `v` as one of its (closed) upvalues? */
    private static boolean holds(LuaClosure c, Object v) {
        if (c.upvalues == null || v == null) return false;
        for (UpValue u : c.upvalues) if (u != null && !open(u) && u.getValue() == v) return true;
        return false;
    }

    /** Every function written in a compiled file (its prototype and the ones inside it). */
    private static void protos(Prototype p, Set<Prototype> out) {
        if (p == null || !out.add(p) || p.prototypes == null) return;
        for (Prototype q : p.prototypes) protos(q, out);
    }

    /**
     * The closures this run made (of the new file's functions) that can be reached from
     * Knox's globals: what a "start" of the file would add as a handler is there - a local
     * function is an upvalue of the functions that use it.
     */
    private List<LuaClosure> madeBy(String file, Set<Prototype> fresh, Set<KahluaTable> foreign) {
        List<LuaClosure> out = new ArrayList<>();
        Set<Object> seen = Collections.newSetFromMap(new IdentityHashMap<>());
        ArrayDeque<Object> queue = new ArrayDeque<>();
        KahluaTableIterator gi = env.iterator();
        while (gi.advance()) {
            if (isKnoxName(gi.getKey()) && (gi.getValue() instanceof KahluaTable || gi.getValue() instanceof LuaClosure)) queue.add(gi.getValue());
        }
        if (lastReturn != null) queue.add(lastReturn);
        int nodes = 0;
        while (!queue.isEmpty() && nodes < 400000) {
            Object o = queue.poll();
            if (o == null || !seen.add(o)) continue;
            nodes++;
            if (o instanceof LuaClosure c) {
                if (fresh.contains(c.prototype)) out.add(c);
                if (c.upvalues == null || !same(fileOf(c), file)) continue;
                for (UpValue u : c.upvalues) {
                    if (u == null || open(u)) continue;
                    Object v = u.getValue();
                    if (v instanceof LuaClosure || (v instanceof KahluaTable t && !foreign.contains(t))) queue.add(v);
                }
            } else if (o instanceof KahluaTable t) {
                if (foreign.contains(t) || t == env) continue;
                KahluaTable mt = t.getMetatable();
                if (mt != null && !foreign.contains(mt)) queue.add(mt);
                KahluaTableIterator it = t.iterator();
                while (it.advance()) {
                    Object v = it.getValue();
                    if (v instanceof LuaClosure || (v instanceof KahluaTable vt && !foreign.contains(vt))) queue.add(v);
                }
            }
        }
        return out;
    }

    private static boolean sameProto(Prototype a, Prototype b) {
        return a != null && b != null && a != b && a.numParams == b.numParams && a.numUpvalues == b.numUpvalues
            && Arrays.equals(a.code, b.code) && Arrays.equals(a.constants, b.constants);
    }

    /** A closure the run made of the very same function as the old handler (its code unchanged), not a handler yet. */
    private static LuaClosure sameCode(LuaClosure old, List<LuaClosure> made, Set<LuaClosure> inLists) {
        LuaClosure found = null;
        for (LuaClosure c : made) {
            if (inLists.contains(c) || !sameProto(old.prototype, c.prototype)) continue;
            if (found != null && found.prototype != c.prototype) return null;   // (two such functions: can't tell)
            if (found == null) found = c;
        }
        return found;
    }

    /** The new file still has the old handler's function, unchanged (only not added this time). */
    private boolean sameCodeIn(LuaClosure old, String file, Set<Prototype> fresh) {
        LuaClosure in = innerOf(old, file, 0);
        Prototype p = (in != null ? in : old).prototype;
        for (Prototype q : fresh) if (sameProto(p, q)) return true;
        return false;
    }

    private static String eventName(List<String> names, int i) {
        return names != null && i < names.size() ? "Events." + names.get(i) : "event #" + i;
    }

    /**
     * Walks what can be reached from Knox's globals, the handlers and the file's return: the
     * file's closures get their upvalues turned, tables their values and metatables. The game's
     * own tables are not walked into. Returns how many references were turned.
     */
    private int rebind(String file, IdentityHashMap<KahluaTable, KahluaTable> map, Set<KahluaTable> foreign,
                       List<ArrayList<LuaClosure>> lists) {
        Set<Object> seen = Collections.newSetFromMap(new IdentityHashMap<>());
        ArrayDeque<Object> queue = new ArrayDeque<>();
        Set<KahluaTable> dead = Collections.newSetFromMap(new IdentityHashMap<>());
        dead.addAll(map.keySet());
        KahluaTableIterator gi = env.iterator();
        while (gi.advance()) {
            if (isKnoxName(gi.getKey()) && gi.getValue() instanceof KahluaTable t) queue.add(t);
        }
        for (ArrayList<LuaClosure> l : lists) queue.addAll(l);
        if (lastReturn != null) queue.add(lastReturn);
        int turned = 0, nodes = 0;
        while (!queue.isEmpty() && nodes < 400000) {
            Object o = queue.poll();
            if (o == null || !seen.add(o)) continue;
            nodes++;
            if (o instanceof LuaClosure c) {
                if (c.upvalues == null) continue;
                boolean mine = same(fileOf(c), file);
                for (UpValue u : c.upvalues) {
                    if (u == null || open(u)) continue;
                    Object v = u.getValue();
                    if (mine && v instanceof KahluaTable vt && dead.contains(vt)) {
                        u.setValue(map.get(vt));
                        turned++;
                        v = map.get(vt);
                    }
                    if (v instanceof LuaClosure || (v instanceof KahluaTable t && !foreign.contains(t))) queue.add(v);
                }
            } else if (o instanceof KahluaTable t) {
                if (foreign.contains(t) || dead.contains(t)) continue;
                KahluaTable mt = t.getMetatable();
                if (mt != null && dead.contains(mt)) {
                    t.setMetatable(map.get(mt));
                    turned++;
                }
                List<Object[]> fix = null;
                KahluaTableIterator it = t.iterator();
                while (it.advance()) {
                    Object v = it.getValue();
                    if (v instanceof KahluaTable vt && dead.contains(vt)) {
                        if (fix == null) fix = new ArrayList<>();
                        fix.add(new Object[] {it.getKey(), map.get(vt)});
                        v = map.get(vt);
                    }
                    if (v instanceof LuaClosure || (v instanceof KahluaTable vt2 && !foreign.contains(vt2))) queue.add(v);
                }
                if (fix != null) {
                    for (Object[] f : fix) t.rawset(f[0], f[1]);
                    turned += fix.size();
                }
            }
        }
        if (nodes >= 400000) warnings.add("stopped walking the tables after 400000 - some references may still point to the new tables");
        return turned;
    }

    // ----------------------------------------------------------------------------------------
    // checks for the offline test

    /** The closures written in `file` that still hold (as an upvalue) one of `tables`. */
    public int stillHeld(String file, Set<KahluaTable> tables) {
        Set<Object> seen = Collections.newSetFromMap(new IdentityHashMap<>());
        ArrayDeque<Object> queue = new ArrayDeque<>();
        queue.add(env);
        for (ArrayList<LuaClosure> l : events.get()) queue.addAll(l);
        int n = 0;
        while (!queue.isEmpty()) {
            Object o = queue.poll();
            if (o == null || !seen.add(o)) continue;
            if (o instanceof LuaClosure c) {
                if (c.upvalues == null) continue;
                for (UpValue u : c.upvalues) {
                    Object v = u == null ? null : u.getValue();
                    if (v instanceof KahluaTable vt && tables.contains(vt) && same(fileOf(c), file)) n++;
                    if (v instanceof LuaClosure || v instanceof KahluaTable) queue.add(v);
                }
            } else if (o instanceof KahluaTable t) {
                KahluaTableIterator it = t.iterator();
                while (it.advance()) {
                    Object v = it.getValue();
                    if (v instanceof LuaClosure || v instanceof KahluaTable) queue.add(v);
                }
                if (t.getMetatable() != null) queue.add(t.getMetatable());
            }
        }
        return n;
    }

    private static java.lang.reflect.Field upCoroutine;
    private static boolean upTried;

    /**
     * Is the upvalue still a slot of a running function's stack (not closed)? Such a one is not
     * turned: its slot may be somebody else's by now. (A run that fails halfway closes its
     * upvalues when it is called from Lua - as the game calls it - but not when called from
     * Java with nothing running.)
     */
    private static boolean open(UpValue u) {
        if (!upTried) {
            upTried = true;
            try {
                upCoroutine = UpValue.class.getDeclaredField("coroutine");
                upCoroutine.setAccessible(true);
            } catch (Throwable t) {
                upCoroutine = null;
            }
        }
        try {
            return upCoroutine != null && upCoroutine.get(u) != null;
        } catch (Throwable t) {
            return false;
        }
    }

    /** Upvalues of a closure (the offline test looks for a wrapper that wraps its own old self). */
    public static List<Object> upvaluesOf(LuaClosure c) {
        List<Object> out = new ArrayList<>();
        if (c.upvalues != null) for (UpValue u : c.upvalues) out.add(u == null ? null : u.getValue());
        return out;
    }

    public static Set<String> filesOf(Iterable<LuaClosure> cs) {
        Set<String> s = new HashSet<>();
        for (LuaClosure c : cs) s.add(fileOf(c));
        return s;
    }
}
