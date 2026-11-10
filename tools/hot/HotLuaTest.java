import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.IdentityHashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import knox.java.KnoxHotEngine;
import org.luaj.kahluafork.compiler.FuncState;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaTableIterator;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaCallFrame;
import se.krka.kahlua.vm.LuaClosure;
import zombie.Lua.Event;

/**
 * "Every file loaded twice" (tools\hot\test.ps1, the author's plan 2026-11-10): all of Knox's
 * Lua files run in the game's own Lua (Kahlua) over stubs.lua, in the game's order; then every
 * file is run again - twice - by the very engine the game uses (KnoxHotEngine), and after each
 * run it is checked that
 *   - no event got a handler more or lost one;
 *   - Knox's global tables are the same tables (the other files and the open windows hold them);
 *   - no function of the game's the file wraps wraps the file's own old wrapper;
 *   - nothing written in the file still holds one of the tables the run made and threw away;
 *   - none of the file's old handlers is left beside its new ones.
 *   java HotLuaTest <stubs.lua> <Knox's media/lua folder>   (from the game's folder)
 */
public class HotLuaTest {
    static KahluaTable env;
    static KahluaThread thread;
    static J2SEPlatform platform;
    static final List<Event> events = new ArrayList<>();
    static KahluaTable eventsTable;
    static final Map<String, String> files = new LinkedHashMap<>();   // "Knox/KnoxFoo" -> path
    static final Map<String, Object> loaded = new HashMap<>();        // path -> return (or TRUE)
    static final Map<String, String> loadError = new HashMap<>();
    static int fails = 0;

    static String norm(String p) {
        return p.replace('\\', '/');
    }

    static Object[] runFile(String path) throws Exception {
        String src = Files.readString(Path.of(path), StandardCharsets.UTF_8);
        if (!src.isEmpty() && src.charAt(0) == '﻿') src = src.substring(1);
        String name = path.substring(path.lastIndexOf('/') + 1);
        FuncState.currentFile = name;
        FuncState.currentfullFile = path;
        LuaClosure c = LuaCompiler.loadstring(src, name, env);
        return thread.pcall(c, new Object[0]);
    }

    static Object require(String what) {
        String key = what.replace('.', '/').replace('\\', '/');
        String path = files.get(key);
        if (path == null) return null;
        if (loaded.containsKey(path)) return loaded.get(path) == Boolean.TRUE ? null : loaded.get(path);
        loaded.put(path, Boolean.TRUE);
        try {
            Object[] r = runFile(path);
            if (r.length > 0 && Boolean.TRUE.equals(r[0])) {
                if (r.length > 1 && r[1] != null) loaded.put(path, r[1]);
            } else {
                loadError.put(path, r.length > 1 ? String.valueOf(r[1]) : "?");
                if (System.getenv("KNOX_HOT_DEBUG") != null) {
                    System.out.println("load error " + path + ": " + (r.length > 2 ? r[2] : ""));
                    if (r.length > 3 && r[3] instanceof Throwable t) t.printStackTrace(System.out);
                }
            }
        } catch (Exception e) {
            loadError.put(path, String.valueOf(e));
        }
        Object v = loaded.get(path);
        return v == Boolean.TRUE ? null : v;
    }

    static Event addEvent(String name) {
        Event e = new Event(name, events.size());
        events.add(e);
        e.register(platform, eventsTable);
        return e;
    }

    /** The host's pcall, as KnoxHot's: {true, what it returned...} or {false, the error, the stack}. */
    static Object[] runChunk(LuaClosure f, Object[] args) {
        return thread.pcall(f, args);
    }

    static List<ArrayList<LuaClosure>> lists() {
        List<ArrayList<LuaClosure>> out = new ArrayList<>();
        for (Event e : events) out.add(e.callbacks);
        return out;
    }

    static void fail(String what) {
        fails++;
        System.out.println("FAIL " + what);
    }

    static boolean fromFile(Object o, String path) {
        return o instanceof LuaClosure c && c.prototype != null && path.equalsIgnoreCase(norm(String.valueOf(c.prototype.filename)));
    }

    static void setup(String stubs) throws Exception {
        platform = new J2SEPlatform();
        // (the standard library's Lua part is compiled here: not under the name of the file compiled last)
        FuncState.currentFile = "stdlib.lua";
        FuncState.currentfullFile = "stdlib.lua";
        env = platform.newEnvironment();
        thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        zombie.Lua.LuaManager.env = env;   // (Kahlua's stack traces ask it for the mod's name)
        events.clear();
        loaded.clear();
        loadError.clear();
        thread.pcall(LuaCompiler.loadstring("print = function() end", "prelude", env), new Object[0]);

        // the game's Events: real ones (zombie.Lua.Event), made when first asked for
        eventsTable = platform.newTable();
        env.rawset("Events", eventsTable);
        KahluaTable evMeta = platform.newTable();
        evMeta.rawset("__index", (JavaFunction) (LuaCallFrame frame, int n) -> {
            Object k = frame.get(1);
            if (!(k instanceof String s)) {
                frame.push(null);
                return 1;
            }
            addEvent(s);
            frame.push(eventsTable.rawget(s));
            return 1;
        });
        eventsTable.setMetatable(evMeta);
        env.rawset("getFilenameOfClosure", (JavaFunction) (LuaCallFrame frame, int n) -> {
            Object c = frame.get(0);
            frame.push(c instanceof LuaClosure lc ? lc.prototype.filename : null);
            return 1;
        });
        env.rawset("getFirstLineOfClosure", (JavaFunction) (LuaCallFrame frame, int n) -> {
            Object c = frame.get(0);
            frame.push(c instanceof LuaClosure lc && lc.prototype.lines.length > 0 ? (double) lc.prototype.lines[0] : 0.0);
            return 1;
        });
        env.rawset("require", (JavaFunction) (LuaCallFrame frame, int n) -> {
            frame.push(require(String.valueOf(frame.get(0))));
            return 1;
        });
        Object[] sr = runFile(norm(new File(stubs).getAbsolutePath()));
        if (!Boolean.TRUE.equals(sr[0])) throw new RuntimeException("stubs.lua: " + sr[1]);
    }

    /** Knox's files as the game loads them: shared, then client (baseline: what the game's tables hold, before client). */
    static void loadAll(KnoxHotEngine engine) {
        boolean based = false;
        for (Map.Entry<String, String> e : files.entrySet()) {
            if (engine != null && !based && e.getValue().contains("/client/")) {
                engine.baseline();
                based = true;
            }
            require(e.getKey());
        }
    }

    public static void main(String[] args) throws Exception {
        // what a reload does, on a made-up file (HotScenario)
        fails += HotScenario.run(args[0]);

        // Knox's files: shared, then client; by name, case aside
        String root = norm(new File(args[1]).getAbsolutePath());
        if (!root.endsWith("/")) root += "/";
        for (String sub : new String[] {"shared", "client"}) {
            List<String> list = new ArrayList<>();
            File dir = new File(root + sub);
            Files.walk(dir.toPath()).filter(p -> p.toString().endsWith(".lua")).forEach(p -> list.add(norm(p.toString())));
            list.sort(String.CASE_INSENSITIVE_ORDER);
            for (String p : list) {
                String rel = p.substring((root + sub + "/").length());
                files.put(rel.substring(0, rel.length() - 4), p);
            }
        }

        // first pass: which of the game's things the files touch
        setup(args[0]);
        loadAll(null);
        List<String> made = new ArrayList<>();
        KahluaTable list = (KahluaTable) env.rawget("STUB_MADE");
        for (int i = 1; i <= list.len(); i++) made.add(String.valueOf(list.rawget(i)));

        // second pass: those made first, as the game has them before Knox
        setup(args[0]);
        StringBuilder pre = new StringBuilder("local _\n");
        for (String m : made) {
            String[] p = m.split("\t");
            if (p.length == 1) pre.append("_ = _G[\"").append(p[0]).append("\"]\n");
            else pre.append("_ = _G[\"").append(p[0]).append("\"][\"").append(p[1]).append("\"]\n");
        }
        Object[] pr = thread.pcall(LuaCompiler.loadstring(pre.toString(), "precreate", env), new Object[0]);
        if (!Boolean.TRUE.equals(pr[0])) throw new RuntimeException("precreate: " + pr[1]);

        KnoxHotEngine engine = new KnoxHotEngine(env, HotLuaTest::lists);
        engine.setKnoxRoot(root);
        loadAll(engine);

        int ran = 0, skipped = 0;
        for (String path : files.values()) {
            String name = path.substring(path.lastIndexOf('/') + 1);
            if (loadError.containsKey(path)) {
                skipped++;
                System.out.println("skip " + name + " (does not load over the stubs: " + firstLine(loadError.get(path)) + ")");
                continue;
            }
            for (int pass = 1; pass <= 2; pass++) {
                String what = name + " run again (" + pass + ")";
                // before
                Map<String, Integer> counts = new HashMap<>();
                for (Event e : events) counts.put(e.name, e.callbacks.size());
                Map<Object, Object> knoxTables = new HashMap<>();
                KahluaTableIterator gi = env.iterator();
                while (gi.advance()) {
                    if (gi.getKey() instanceof String k && k.startsWith("Knox") && gi.getValue() instanceof KahluaTable) knoxTables.put(k, gi.getValue());
                }
                Map<String, Object> wrappers = new HashMap<>();
                Map<String, KahluaTable> wrapTables = new HashMap<>();
                gi = env.iterator();
                while (gi.advance()) {
                    if (gi.getKey() instanceof String k && !k.startsWith("Knox") && gi.getValue() instanceof KahluaTable t) {
                        KahluaTableIterator ti = t.iterator();
                        while (ti.advance()) {
                            if (fromFile(ti.getValue(), path)) {
                                wrappers.put(k + "." + ti.getKey(), ti.getValue());
                                wrapTables.put(k + "." + ti.getKey(), t);
                            }
                        }
                    }
                }
                Set<LuaClosure> oldHandlers = Collections.newSetFromMap(new IdentityHashMap<>());
                Map<String, Integer> oldCount = new HashMap<>();
                for (Event e : events) for (LuaClosure c : e.callbacks) {
                    if (fromFile(c, path)) {
                        oldHandlers.add(c);
                        oldCount.merge(e.name, 1, Integer::sum);
                    }
                }

                String err = engine.run(path, path, HotLuaTest::runChunk);
                if (err != null) {
                    fail(what + ": " + firstLine(err));
                    break;
                }
                for (String w : engine.warnings) System.out.println("warn " + what + ": " + w);
                // handlers
                for (Event e : events) {
                    Integer was = counts.get(e.name);
                    int now = e.callbacks.size();
                    if (was == null) was = 0;
                    if (was != now) fail(what + ": " + e.name + " had " + was + " handlers, now " + now);
                }
                // (an old one may stay only where the run added fewer than there were: an "only once" check)
                for (Event e : events) {
                    int olds = 0, news = 0;
                    for (LuaClosure c : e.callbacks) {
                        if (oldHandlers.contains(c)) olds++;
                        else if (fromFile(c, path)) news++;
                    }
                    if (olds > 0 && news >= oldCount.getOrDefault(e.name, 0)) {
                        fail(what + ": an old handler of " + e.name + " stayed beside the new ones");
                    }
                }
                // tables
                for (Map.Entry<Object, Object> e : knoxTables.entrySet()) {
                    Object now = env.rawget(e.getKey());
                    if (now != e.getValue()) fail(what + ": " + e.getKey() + " is another table now");
                }
                // wrappers of the game's functions
                for (Map.Entry<String, Object> w : wrappers.entrySet()) {
                    KahluaTable t = wrapTables.get(w.getKey());
                    String key = w.getKey().substring(w.getKey().indexOf('.') + 1);
                    Object now = t.rawget(key);
                    if (now instanceof LuaClosure nc && nc != w.getValue()) {
                        if (holds(nc, w.getValue(), 3, Collections.newSetFromMap(new IdentityHashMap<>()))) {
                            fail(what + ": " + w.getKey() + " wraps its own old wrapper");
                        }
                    }
                }
                // references to the thrown-away tables
                if (!engine.lastMap.isEmpty()) {
                    Set<KahluaTable> dead = Collections.newSetFromMap(new IdentityHashMap<>());
                    dead.addAll(engine.lastMap.keySet());
                    int held = engine.stillHeld(path, dead);
                    if (held > 0) fail(what + ": " + held + " upvalue(s) of the file still hold a thrown-away table");
                }
            }
            ran++;
        }
        System.out.println("hot: " + files.size() + " files, " + ran + " run again twice, " + skipped + " skipped (not loading over the stubs)");
        System.out.println(fails == 0 ? "hot: all pass" : "hot: " + fails + " FAIL");
        System.exit(fails == 0 ? 0 : 1);
    }

    static boolean holds(LuaClosure c, Object target, int depth, Set<Object> seen) {
        if (!seen.add(c)) return false;
        for (Object v : KnoxHotEngine.upvaluesOf(c)) {
            if (v == target) return true;
            if (depth > 0 && v instanceof LuaClosure lc && holds(lc, target, depth - 1, seen)) return true;
        }
        return false;
    }

    static String firstLine(String s) {
        if (s == null) return "";
        int i = s.indexOf('\n');
        return i < 0 ? s : s.substring(0, i);
    }

    static int firstLineOf(LuaClosure c) {
        return c.prototype.lines.length > 0 ? c.prototype.lines[0] : 0;
    }
}
