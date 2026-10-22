import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import se.krka.kahlua.luaj.compiler.LuaCompiler;

/**
 * Syntax check of Lua files with the game's own compiler (Kahlua):
 * java -cp projectzomboid.jar LuaCheck.java file.lua ...
 */
public class LuaCheck {
    public static void main(String[] args) throws Exception {
        int bad = 0;
        for (String a : args) {
            String src = Files.readString(Path.of(a), StandardCharsets.UTF_8);
            try {
                LuaCompiler.loadstring(src, Path.of(a).getFileName().toString(), null);
            } catch (Throwable e) {
                bad++;
                System.out.println("FAIL " + a + ": " + e.getMessage());
            }
        }
        System.out.println(bad == 0 ? "all ok (" + args.length + ")" : bad + " failed");
    }
}
