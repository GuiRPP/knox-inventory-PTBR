package knox.java;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.Lua.LuaManager;

/**
 * The item editor's presets (KnoxPresets.lua, KnoxEditor.lua; the author, 2026-10-25):
 * Zomboid/Lua/knox_presets. Lua reads and writes the files itself; it can't list a
 * folder (the import shows the files a player dropped there) nor take a file away.
 */
public class KnoxPresetFiles {

    static File folder() {
        return new File(LuaManager.getLuaCacheDir(), "knox_presets");
    }

    /** The folder's .txt files, newest first: "name\tdd.MM\n" each. */
    @LuaMethod(name = "knoxPresetFiles", global = true)
    public static String knoxPresetFiles() {
        File[] files = folder().listFiles((dir, name) -> name.toLowerCase().endsWith(".txt"));
        if (files == null) return "";
        Arrays.sort(files, Comparator.comparingLong(File::lastModified).reversed());
        SimpleDateFormat day = new SimpleDateFormat("dd.MM");
        StringBuilder out = new StringBuilder();
        for (File f : files) {
            if (!f.isFile() || f.length() == 0) continue;
            out.append(f.getName()).append('\t').append(day.format(new Date(f.lastModified()))).append('\n');
        }
        return out.toString();
    }

    /** Take a preset's file away (a plain name of the folder, .txt). */
    @LuaMethod(name = "knoxPresetDelete", global = true)
    public static boolean knoxPresetDelete(String name) {
        if (name == null || name.contains("/") || name.contains("\\") || name.contains("..")
                || !name.toLowerCase().endsWith(".txt") || name.equalsIgnoreCase("index.txt")) {
            return false;
        }
        File f = new File(folder(), name);
        return f.isFile() && f.delete();
    }
}
