import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaCallFrame;
import se.krka.kahlua.vm.LuaClosure;

/**
 * Runs Lua files, in order, in one environment of the game's own Lua (Kahlua), outside the game:
 *   java -cp projectzomboid.jar LuaRun.java stubs.lua SomeModFile.lua test.lua name=value
 * Run it from the game's folder (Kahlua reads stdlib.lua from the working directory).
 * Only the language and its standard library are there - the game's API is whatever the first
 * files define (stubs). Added: readfile(path) -> text, writefile(path, text), print to the
 * console; an argument "name=value" becomes a global string.
 */
public class LuaRun {
    public static void main(String[] args) throws Exception {
        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();   // the game sets it; pcall reads it
        env.rawset("readfile", (JavaFunction) (LuaCallFrame frame, int n) -> {
            try {
                frame.push(Files.readString(Path.of((String) frame.get(0)), StandardCharsets.UTF_8));
            } catch (Exception e) {
                frame.push(null);
            }
            return 1;
        });
        env.rawset("writefile", (JavaFunction) (LuaCallFrame frame, int n) -> {
            try {
                Files.writeString(Path.of((String) frame.get(0)), (String) frame.get(1), StandardCharsets.UTF_8);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            return 0;
        });
        // the game's print goes to its own log: ours writes to the console
        env.rawset("__out", (JavaFunction) (LuaCallFrame frame, int n) -> {
            System.out.println(String.valueOf(frame.get(0)));
            return 0;
        });
        String prelude = "print = function(...) local t = {} for i = 1, select('#', ...) do t[i] = tostring(select(i, ...)) end __out(table.concat(t, '\\t')) end";
        thread.pcall(LuaCompiler.loadstring(prelude, "prelude", env), new Object[0]);
        // name=value: a global string for the scripts (a path to read, a file to write), set before any file runs
        for (String a : args) {
            if (a.matches("^[A-Za-z_]\\w+=.*")) env.rawset(a.substring(0, a.indexOf('=')), a.substring(a.indexOf('=') + 1));
        }
        for (String a : args) {
            if (a.matches("^[A-Za-z_]\\w+=.*")) continue;
            String src = Files.readString(Path.of(a), StandardCharsets.UTF_8);
            LuaClosure c = LuaCompiler.loadstring(src, Path.of(a).getFileName().toString(), env);
            Object[] r = thread.pcall(c, new Object[0]);
            if (r.length > 0 && !Boolean.TRUE.equals(r[0])) {
                System.out.println("ERROR in " + a + ": " + (r.length > 1 ? r[1] : "?"));
                if (r.length > 2 && r[2] != null) System.out.println(r[2]);
                if (r.length > 3 && r[3] instanceof Throwable t) t.printStackTrace(System.out);
                System.exit(1);
            }
        }
    }
}
