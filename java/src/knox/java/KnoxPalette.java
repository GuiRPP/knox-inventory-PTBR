package knox.java;

import se.krka.kahlua.integration.annotations.LuaMethod;
import se.krka.kahlua.vm.KahluaTable;

/**
 * The skin's palette for what the Java part draws itself: the item tooltips'
 * labels, values, meters and frames (KnoxTooltipStyle) and the loading screen
 * (KnoxLoading). Lua hands over KnoxTheme.color whenever the skin changes
 * (KnoxTheme.applySkin); the colours are copied into the arrays those classes
 * draw with, in place.
 */
public class KnoxPalette {

    static boolean put(KahluaTable t, String key, float[] into) {
        Object o = t.rawget(key);
        if (!(o instanceof KahluaTable)) return false;
        KahluaTable c = (KahluaTable) o;
        Object r = c.rawget("r"), g = c.rawget("g"), b = c.rawget("b");
        if (!(r instanceof Double && g instanceof Double && b instanceof Double)) return false;
        into[0] = ((Double) r).floatValue();
        into[1] = ((Double) g).floatValue();
        into[2] = ((Double) b).floatValue();
        return true;
    }

    @LuaMethod(name = "knoxSetPalette", global = true)
    public static void knoxSetPalette(KahluaTable color) {
        if (color == null) return;
        // the loading screen
        put(color, "accent", KnoxLoading.ACCENT);
        put(color, "bright", KnoxLoading.BRIGHT);
        put(color, "text", KnoxLoading.TEXT);
        put(color, "dim", KnoxLoading.DIM);
        put(color, "ink", KnoxLoading.INK);
        put(color, "window", KnoxLoading.WINDOW);
        put(color, "tileFrame", KnoxLoading.FRAME);
        put(color, "border", KnoxLoading.BORDER);
        // the tooltips: values bright, labels between text and dim
        put(color, "bright", KnoxTooltipStyle.VALUE);
        float[] text = new float[3], dim = new float[3];
        if (put(color, "text", text) && put(color, "dim", dim)) {
            for (int i = 0; i < 3; i++) KnoxTooltipStyle.LABEL[i] = text[i] * 0.75f + dim[i] * 0.25f;
        }
        put(color, "line", KnoxTooltipStyle.TRACK);
        put(color, "tileEdge", KnoxTooltipStyle.FRAME);
        put(color, "tileFrame", KnoxTooltipStyle.TILE_FRAME);
    }
}
