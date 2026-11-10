package knox.java;

import java.io.File;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

import se.krka.kahlua.integration.LuaReturn;
import se.krka.kahlua.integration.annotations.LuaMethod;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.LuaClosure;
import zombie.Lua.Event;
import zombie.Lua.LuaEventManager;
import zombie.Lua.LuaManager;
import zombie.ZomboidFileSystem;
import zombie.core.Translator;

/**
 * The DEV reloader's Java side (the author 2026-11-10: "see the changes live, not restart the
 * game every time - even when you change something in Java"). Only on the author's computer:
 * Lua (Knox_Hot.lua) starts it where Zomboid/Lua/knox_dev.txt is; for players nothing here
 * runs and nothing is watched.
 *
 * A thread looks at Knox's Lua folder (Lua files and the translations), at the remote's
 * request file (Zomboid/Lua/knox_remote_in.lua) and at the fast Java build's stamp
 * (java/build/hot/stamp.txt, written by java/hot.ps1) every 200 ms; what changed and stood
 * still for one more look waits for Lua, which asks (knoxHotPoll) on its own tick and does
 * the work on the game's thread: files run again (KnoxHotEngine), the texts read again, the
 * classes swapped (KnoxHotJava).
 */
public class KnoxHot {

    private static volatile Thread watcher;
    private static volatile String luaRoot;        // ".../42/media/lua/" as the game names files
    private static volatile File remoteIn;
    private static volatile File hotStamp;
    private static final LinkedHashSet<String> pending = new LinkedHashSet<>();
    private static KnoxHotEngine engine;

    // ----------------------------------------------------------------------------------------
    // the watcher

    private static final class Seen {
        long time, size;
        boolean reported = true;   // (what is there at the start is not a change)
    }

    private static void walk(File dir, Map<String, File> out) {
        File[] list = dir.listFiles();
        if (list == null) return;
        for (File f : list) {
            if (f.isDirectory()) walk(f, out);
            else {
                String n = f.getName().toLowerCase();
                if (n.endsWith(".lua") || n.endsWith(".json")) out.put(f.getPath(), f);
            }
        }
    }

    private static void watch() {
        HashMap<String, Seen> seen = new HashMap<>();
        boolean first = true;
        while (watcher == Thread.currentThread()) {
            try {
                HashMap<String, File> files = new HashMap<>();
                walk(new File(luaRoot), files);
                if (remoteIn != null) files.put(remoteIn.getPath(), remoteIn);
                if (hotStamp != null) files.put(hotStamp.getPath(), hotStamp);
                for (Map.Entry<String, File> e : files.entrySet()) {
                    File f = e.getValue();
                    if (!f.exists()) continue;
                    long t = f.lastModified(), s = f.length();
                    Seen was = seen.get(e.getKey());
                    if (was == null) {
                        was = new Seen();
                        was.time = t;
                        was.size = s;
                        was.reported = first;   // a file that appears later is new: reported
                        seen.put(e.getKey(), was);
                        continue;
                    }
                    if (was.time != t || was.size != s) {
                        // changed - wait for it to stand still one look (an editor writing in parts)
                        was.time = t;
                        was.size = s;
                        was.reported = false;
                        continue;
                    }
                    if (!was.reported) {
                        was.reported = true;
                        String what;
                        if (remoteIn != null && f.equals(remoteIn)) what = "cmd";
                        else if (hotStamp != null && f.equals(hotStamp)) what = "java";
                        else if (f.getName().toLowerCase().endsWith(".json")) what = "lang\t" + KnoxHotEngine.norm(f.getPath());
                        else if (KnoxHotEngine.norm(f.getPath()).toLowerCase().contains("/media/lua/server/")) continue;   // (the server's: not run on the client)
                        else what = "lua\t" + KnoxHotEngine.norm(f.getPath());
                        synchronized (pending) {
                            pending.add(what);
                        }
                    }
                }
                first = false;
                Thread.sleep(200);
            } catch (InterruptedException e) {
                return;
            } catch (Throwable t) {
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    return;
                }
            }
        }
    }

    // ----------------------------------------------------------------------------------------
    // only on the author's computer
    //
    // ZombieBuddy puts every global @LuaMethod of the jar into every player's Lua, so the
    // check can't be Lua's alone (QA 2026-11-10: any mod could have called knoxHotStart with
    // its own folder and had its classes defined in Knox's package). Here: nothing works
    // without Zomboid/Lua/knox_dev.txt; Knox's folders come from where the jar itself lies,
    // not from what Lua says; only Knox's own .lua files are run.

    private static Boolean devOn;

    static boolean dev() {
        if (devOn == null) {
            boolean on;
            try {
                on = new File(ZomboidFileSystem.instance.getCacheDir() + File.separator + "Lua" + File.separator + "knox_dev.txt").isFile();
            } catch (Throwable t) {
                on = false;
            }
            devOn = on;
        }
        return devOn;
    }

    /** The jar's version folder ("<mod>/42/": the jar is <mod>/42/media/java/client/X.jar), or null. */
    private static File versionDir() {
        File f = KnoxHotJava.jarFile();
        for (int i = 0; i < 4 && f != null; i++) f = f.getParentFile();
        return f;
    }

    /** knoxHotStart said yes (the author's computer, Knox's own folder). */
    private static boolean started() {
        return luaRoot != null && dev();
    }

    /** Is `path` one of Knox's own Lua files (under the folder the jar's mod has)? */
    private static boolean knoxLua(String path) {
        String r = luaRoot;
        if (r == null || path == null) return false;
        String p = KnoxHotEngine.norm(path);
        return p.toLowerCase().endsWith(".lua") && p.length() > r.length() && p.substring(0, r.length()).equalsIgnoreCase(r)
            && !p.contains("/../");
    }

    /**
     * Starts watching (once; again - the same thread goes on). `root` is Knox's media/lua/
     * folder as the game names its files - it must be the folder of the mod the jar is in.
     * Returns what is on: "lua", plus "java" when the fast Java build's folder is there and
     * the classes can be swapped, plus "jbr" when they can be swapped whole (new methods and
     * fields: JetBrains Runtime); nil - off (not the author's computer, or not Knox's folder).
     */
    @LuaMethod(name = "knoxHotStart", global = true)
    public static String knoxHotStart(String root) {
        if (!dev() || root == null || root.isEmpty()) return null;
        String r = KnoxHotEngine.norm(root);
        if (!r.endsWith("/")) r += "/";
        File ver = versionDir();
        if (ver == null) return null;
        String expected = KnoxHotEngine.norm(new File(ver, "media" + File.separator + "lua").getAbsolutePath()) + "/";
        if (!r.equalsIgnoreCase(expected)) {
            // (the same folder written another way - a junction, a short name: by what it is)
            try {
                if (!new File(r).getCanonicalFile().equals(new File(expected).getCanonicalFile())) return null;
            } catch (Exception ex) {
                return null;
            }
        }
        luaRoot = r;
        engine().setKnoxRoot(r);
        try {
            remoteIn = new File(ZomboidFileSystem.instance.getCacheDir() + File.separator + "Lua" + File.separator + "knox_remote_in.lua");
        } catch (Throwable t) {
            remoteIn = null;
        }
        // (the repository's layout: <mod>/42/ -> <mod>/java/build/hot)
        File modDir = ver.getParentFile();
        File hot = modDir != null ? new File(modDir, "java" + File.separator + "build" + File.separator + "hot") : null;
        hotStamp = hot != null ? new File(hot, "stamp.txt") : null;
        KnoxHotJava.setHotDir(hot);
        if (watcher == null) {
            Thread t = new Thread(KnoxHot::watch, "Knox DEV reloader");
            t.setDaemon(true);
            t.setPriority(Thread.MIN_PRIORITY);
            watcher = t;
            t.start();
        }
        String on = "lua";
        if (hot != null && KnoxHotJava.available()) on += ",java";
        if (KnoxHotJava.enhanced()) on += ",jbr";
        return on;
    }

    /** What changed since the last ask, a line each ("lua\t<path>", "lang\t<path>", "cmd", "java"); nil - nothing. */
    @LuaMethod(name = "knoxHotPoll", global = true)
    public static String knoxHotPoll() {
        if (!started()) return null;
        synchronized (pending) {
            if (pending.isEmpty()) return null;
            String s = String.join("\n", pending);
            pending.clear();
            return s;
        }
    }

    // ----------------------------------------------------------------------------------------
    // Lua files

    @SuppressWarnings("unchecked")
    private static List<ArrayList<LuaClosure>> eventLists() {
        List<ArrayList<LuaClosure>> out = new ArrayList<>();
        try {
            Field f = LuaEventManager.class.getDeclaredField("EventList");
            f.setAccessible(true);
            for (Event e : (ArrayList<Event>) f.get(null)) out.add(e.callbacks);
        } catch (Throwable t) {
            // (no lists: the handlers can't be swapped - the run still goes)
        }
        return out;
    }

    @SuppressWarnings("unchecked")
    private static List<String> eventNames() {
        List<String> out = new ArrayList<>();
        try {
            Field f = LuaEventManager.class.getDeclaredField("EventList");
            f.setAccessible(true);
            for (Event e : (ArrayList<Event>) f.get(null)) out.add(e.name);
        } catch (Throwable t) {
            // (by number then)
        }
        return out;
    }

    /** (a new one for each Lua of the game: going into a game and back to the menu the game makes its Lua anew) */
    private static KnoxHotEngine engine() {
        if (engine == null || engine.env != LuaManager.env) {
            engine = new KnoxHotEngine(LuaManager.env, KnoxHot::eventLists);
            engine.eventNames = KnoxHot::eventNames;
            if (luaRoot != null) engine.setKnoxRoot(luaRoot);
        }
        return engine;
    }

    /** What the game's tables hold now, before Knox's files (Knox_Hot.lua, the first of them, asks). */
    @LuaMethod(name = "knoxHotBaseline", global = true)
    public static int knoxHotBaseline() {
        if (!dev()) return 0;
        return engine().baseline();
    }

    /** The game's name of a file of its Lua (as `loaded` and the closures have it), or null. */
    private static String loadedName(String path) {
        for (String s : LuaManager.loaded) if (KnoxHotEngine.same(s, path)) return s;
        return null;
    }

    private static void clearCache(String field) {
        try {
            Field f = LuaManager.class.getDeclaredField(field);
            f.setAccessible(true);
            ((Map<?, ?>) f.get(null)).clear();
        } catch (Throwable t) {
            // (an older or newer game without it)
        }
    }

    /**
     * Runs a Lua file of Knox again (see KnoxHotEngine). Returns "ok\t<report>" or
     * "error\t<message and the Lua stack>"; a warning goes after the report on lines of its own.
     */
    @LuaMethod(name = "knoxHotRun", global = true)
    public static String knoxHotRun(String path) {
        if (!started()) return "error\toff";
        if (!knoxLua(path)) return "error\tnot a Lua file of Knox: " + path;
        KnoxHotEngine e = engine();
        String name = loadedName(path);
        boolean known = name != null;
        if (name == null) name = KnoxHotEngine.norm(path);
        String error = e.run(path, name, (f, args) -> {
            LuaReturn r = LuaManager.caller.protectedCall(LuaManager.thread, f, args);
            if (r.isSuccess()) {
                Object[] out = new Object[r.size() + 1];
                out[0] = Boolean.TRUE;
                for (int i = 0; i < r.size(); i++) out[i + 1] = r.get(i);
                return out;
            }
            String stack = r.getLuaStackTrace();
            Throwable j = r.getJavaException();
            return new Object[] {Boolean.FALSE, r.getErrorString(), (stack != null ? stack : "") + (j != null ? "\n" + j : "")};
        });
        clearCache("luaFunctionMap");
        clearCache("luaTableMap");
        if (!known) LuaManager.loaded.add(name);
        if (e.lastReturn != null) LuaManager.loadedReturn.put(name, e.lastReturn);
        StringBuilder sb = new StringBuilder();
        sb.append(error == null ? "ok\t" + e.lastReport : "error\t" + error);
        for (String w : e.warnings) sb.append("\nwarning\t").append(w);
        return sb.toString();
    }

    /** The translations read again (the game's own, as when its language is changed). */
    @LuaMethod(name = "knoxHotLang", global = true)
    public static String knoxHotLang() {
        if (!started()) return "error\toff";
        try {
            Translator.loadFiles();
            return "ok";
        } catch (Throwable t) {
            return "error\t" + t;
        }
    }

    // ----------------------------------------------------------------------------------------
    // Java

    /** The fast Java build's classes swapped in (KnoxHotJava): a line for each class. */
    @LuaMethod(name = "knoxHotJava", global = true)
    public static String knoxHotJava() {
        if (!started()) return "off\tthe DEV reloader is off";
        return KnoxHotJava.apply();
    }

    /** Is the fast Java build newer than what the game started with (asked once, at the start)? */
    @LuaMethod(name = "knoxHotJavaNewer", global = true)
    public static boolean knoxHotJavaNewer() {
        return started() && KnoxHotJava.newerThanJar();
    }
}
