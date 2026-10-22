import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;

import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.LuaClosure;
import se.krka.kahlua.vm.Prototype;

/**
 * Globals each Lua file reads and writes, from the game's own compiler
 * (Kahlua, Lua 5.1 opcodes GETGLOBAL = 5, SETGLOBAL = 7), to catch typos and
 * stray globals:
 *   java -cp projectzomboid.jar GlobalScan.java file.lua ...
 * prints "READ-ONLY name  (files)" for globals read but never set by these
 * files (game API, or a typo), then "SET name (files)" for globals they set.
 */
public class GlobalScan {
    static final Map<String, TreeSet<String>> reads = new TreeMap<>();
    static final Map<String, TreeSet<String>> sets = new TreeMap<>();

    public static void main(String[] args) throws Exception {
        for (String a : args) {
            String name = Path.of(a).getFileName().toString();
            String src = Files.readString(Path.of(a), StandardCharsets.UTF_8);
            LuaClosure c = LuaCompiler.loadstring(src, name, null);
            walk(c.prototype, name);
        }
        for (Map.Entry<String, TreeSet<String>> e : reads.entrySet()) {
            if (!sets.containsKey(e.getKey())) System.out.println("READ-ONLY " + e.getKey() + "  " + e.getValue());
        }
        for (Map.Entry<String, TreeSet<String>> e : sets.entrySet()) {
            System.out.println("SET " + e.getKey() + "  " + e.getValue());
        }
    }

    static void walk(Prototype p, String file) {
        for (int op : p.code) {
            int code = op & 63;
            if (code == 5 || code == 7) {
                int bx = op >>> 14;
                Object k = p.constants[bx];
                (code == 5 ? reads : sets).computeIfAbsent(String.valueOf(k), x -> new TreeSet<>()).add(file);
            }
        }
        if (p.prototypes != null) for (Prototype sub : p.prototypes) walk(sub, file);
    }
}
