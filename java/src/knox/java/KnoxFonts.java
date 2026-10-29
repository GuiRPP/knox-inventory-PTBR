package knox.java;

import java.util.concurrent.ConcurrentHashMap;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.fonts.AngelCodeFont;
import zombie.ui.TextManager;
import zombie.ui.UIFont;

/**
 * Knox's own fonts (Fira Sans Extra Condensed, see media/fonts/knox in Knox
 * Inventory), loaded next to the game's: the game's fonts are not touched.
 *
 * Atlases are AngelCode BMFont files made by tools/fontgen/FontGen.java, one
 * per style and pixel size: media/fonts/knox/<style>_<size>.fnt with
 * <style>_<size>_0.png. Styles: "head" (semibold, letter-spaced, for caps
 * labels), "title" (bold), "body" (medium).
 *
 * Lua draws with absolute screen coordinates, like UIElement.DrawText does.
 */
public class KnoxFonts {

    public static final int MIN_SIZE = 10;
    public static final int MAX_SIZE = 44;

    private static final ConcurrentHashMap<String, AngelCodeFont> FONTS = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Boolean> FAILED = new ConcurrentHashMap<>();

    static int clampSize(double size) {
        return Math.max(MIN_SIZE, Math.min(MAX_SIZE, (int) Math.round(size)));
    }

    // (every draw, measure and height asks for its font: Knox's three styles by size
    // in arrays, without building the name of the atlas each time - v57)
    private static final String[] STYLES = {"body", "title", "head"};
    private static final AngelCodeFont[][] BY_SIZE = new AngelCodeFont[STYLES.length][MAX_SIZE + 1];

    private static int styleIndex(String style) {
        for (int i = 0; i < STYLES.length; i++) {
            if (STYLES[i].equals(style)) return i;
        }
        return -1;
    }

    /** The font of a style and size, loaded on first use; null if missing. */
    public static AngelCodeFont font(String style, double size) {
        int px = clampSize(size);
        int si = styleIndex(style);
        if (si >= 0) {
            AngelCodeFont known = BY_SIZE[si][px];
            if (known != null) return known;
        }
        String key = style + "_" + px;
        AngelCodeFont f = FONTS.get(key);
        if (f == null && !FAILED.containsKey(key)) {
            try {
                f = new AngelCodeFont("media/fonts/knox/" + key + ".fnt", "media/fonts/knox/" + key + "_0");
                FONTS.put(key, f);
            } catch (Exception e) {
                FAILED.put(key, Boolean.TRUE);
                System.out.println("[Knox] font " + key + " failed: " + e);
            }
        }
        if (f != null && si >= 0) BY_SIZE[si][px] = f;
        return f;
    }

    /** True when the style's atlas of this size loaded and is ready to draw. */
    @LuaMethod(name = "knoxFontReady", global = true)
    public static boolean knoxFontReady(String style, double size) {
        AngelCodeFont f = font(style, size);
        return f != null && !f.isLoading();
    }

    @LuaMethod(name = "knoxDrawText", global = true)
    public static void knoxDrawText(String style, double size, String text, double x, double y,
                                    double r, double g, double b, double a) {
        if (text == null) return;
        // (a ready list being written takes it down too: KnoxDrawList)
        if (KnoxDrawList.rec != null) KnoxDrawList.addText(style, size, text, x, y, r, g, b, a);
        AngelCodeFont f = font(style, size);
        if (f == null) return;
        if (f.isLoading()) {
            // the atlas is still being read (the first seconds of the main
            // menu): the game's font instead of blank blocks
            int px = clampSize(size);
            UIFont game = px < 18 ? UIFont.Small : px < 28 ? UIFont.Medium : UIFont.Large;
            TextManager.instance.DrawString(game, x, y, text, r, g, b, a);
            return;
        }
        f.drawString((float) x, (float) y, text, (float) r, (float) g, (float) b, (float) a);
    }

    /**
     * A Knox font for the game's own widgets, which take a UIFont (text boxes):
     * the atlas is put into a slot of the game's font table that the game
     * itself leaves empty (AutoNormMedium), and that UIFont is returned. One
     * font at a time; null while the atlas is loading.
     */
    @LuaMethod(name = "knoxFieldFont", global = true)
    public static UIFont knoxFieldFont(String style, double size) {
        String key = style + "_" + clampSize(size);
        AngelCodeFont[] slots = TextManager.instance.enumToFont;
        int slot = UIFont.AutoNormMedium.ordinal();
        // An atlas of its own, never the one Knox draws with: when the game
        // reloads its fonts it destroys every font of its table, and a shared
        // one would be dead for Knox too (text of that size vanished). The
        // game also empties the slot then: the atlas is loaded again.
        if (fieldFont == null || !key.equals(fieldKey) || slots[slot] != fieldFont) {
            try {
                fieldFont = new AngelCodeFont("media/fonts/knox/" + key + ".fnt", "media/fonts/knox/" + key + "_0");
                fieldKey = key;
            } catch (Exception e) {
                fieldFont = null;
                return null;
            }
            slots[slot] = fieldFont;
        }
        return fieldFont.isLoading() ? null : UIFont.AutoNormMedium;
    }

    private static AngelCodeFont fieldFont;
    private static String fieldKey;

    @LuaMethod(name = "knoxTextWidth", global = true)
    public static int knoxTextWidth(String style, double size, String text) {
        if (text == null) return 0;
        AngelCodeFont f = font(style, size);
        return f == null ? 0 : f.getWidth(text);
    }

    /**
     * Do Knox's atlases have every character of `text`? (They hold Latin with
     * its European accents and Cyrillic; Chinese, Japanese, Korean, Thai,
     * Arabic... are not there, and the game's fonts are used instead.)
     */
    @LuaMethod(name = "knoxFontCovers", global = true)
    public static boolean knoxFontCovers(String text) {
        if (text == null) return true;
        AngelCodeFont f = font("body", 16);
        if (f == null || f.chars == null) return false;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c == '\n' || c == '\r' || c == '\t') continue;
            if (c >= f.chars.length || f.chars[c] == null) return false;
        }
        return true;
    }

    /**
     * Where the ink of `text` is, drawn at 0,0: "left,top,right,bottom" in
     * pixels. The width and the line height of a font say where the next
     * letter or line goes, not where this one's pixels are (spacing after the
     * last letter, room for accents above and tails below): a number centred
     * by them in a small plate sits off its middle. Empty when unknown.
     */
    @LuaMethod(name = "knoxTextInk", global = true)
    public static String knoxTextInk(String style, double size, String text) {
        AngelCodeFont f = text == null ? null : font(style, size);
        if (f == null || f.chars == null || f.isLoading()) return "";
        // a glyph's cell in the atlas is wider than its letter (antialiasing
        // room, the font's own side space): the letter's own pixels are found
        // once per atlas (seen 2026-10-14: a "1" by its cell sat off the middle)
        short[][] tight = tightBoxes(style + "_" + clampSize(size), f);
        int pen = 0, left = Integer.MAX_VALUE, top = Integer.MAX_VALUE, right = Integer.MIN_VALUE, bottom = Integer.MIN_VALUE;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            AngelCodeFont.CharDef d = c < f.chars.length ? f.chars[c] : null;
            if (d == null) continue;
            if (d.width > 0 && d.height > 0) {
                short[] t = tight != null && c < tight.length ? tight[c] : null;
                if (t != null) {
                    if (t[0] >= 0) {   // (an empty one - a space - has no pixels)
                        left = Math.min(left, pen + d.xoffset + t[0]);
                        right = Math.max(right, pen + d.xoffset + t[2] + 1);
                        top = Math.min(top, d.yoffset + t[1]);
                        bottom = Math.max(bottom, d.yoffset + t[3] + 1);
                    }
                } else {
                    left = Math.min(left, pen + d.xoffset);
                    right = Math.max(right, pen + d.xoffset + d.width);
                    top = Math.min(top, d.yoffset);
                    bottom = Math.max(bottom, d.yoffset + d.height);
                }
            }
            pen += d.xadvance;
        }
        if (right < left) return "";
        return left + "," + top + "," + right + "," + bottom;
    }

    /** per atlas: per char {left, top, right, bottom} of its pixels inside its cell ({-1..} = none) */
    private static final ConcurrentHashMap<String, short[][]> TIGHT = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Boolean> TIGHT_FAILED = new ConcurrentHashMap<>();

    /** The letters' own pixel boxes of an atlas, read from its picture once; null if it can't be read. */
    static short[][] tightBoxes(String key, AngelCodeFont f) {
        short[][] t = TIGHT.get(key);
        if (t != null || TIGHT_FAILED.containsKey(key)) return t;
        try {
            String path = zombie.ZomboidFileSystem.instance.getString("media/fonts/knox/" + key + "_0.png");
            java.awt.image.BufferedImage img = javax.imageio.ImageIO.read(new java.io.File(path));
            if (img == null) throw new java.io.IOException("no picture " + path);
            t = new short[f.chars.length][];
            for (int c = 0; c < f.chars.length; c++) {
                AngelCodeFont.CharDef d = f.chars[c];
                if (d == null || d.width <= 0 || d.height <= 0) continue;
                int l = Integer.MAX_VALUE, tp = Integer.MAX_VALUE, r = -1, b = -1;
                for (int yy = 0; yy < d.height; yy++) {
                    int py = d.y + yy;
                    if (py < 0 || py >= img.getHeight()) continue;
                    for (int xx = 0; xx < d.width; xx++) {
                        int px = d.x + xx;
                        if (px < 0 || px >= img.getWidth()) continue;
                        // (a pixel counts when it is clearly there, not a faint antialiasing edge)
                        int a = (img.getRGB(px, py) >>> 24) & 0xff;
                        if (a < 96) continue;
                        l = Math.min(l, xx);
                        r = Math.max(r, xx);
                        tp = Math.min(tp, yy);
                        b = Math.max(b, yy);
                    }
                }
                t[c] = r < 0 ? new short[] {-1, -1, -1, -1} : new short[] {(short) l, (short) tp, (short) r, (short) b};
            }
            TIGHT.put(key, t);
            return t;
        } catch (Exception | LinkageError e) {
            TIGHT_FAILED.put(key, Boolean.TRUE);
            System.out.println("[Knox] font " + key + ": letters' pixels not read (" + e + "), cells used");
            return null;
        }
    }

    @LuaMethod(name = "knoxFontHeight", global = true)
    public static int knoxFontHeight(String style, double size) {
        AngelCodeFont f = font(style, size);
        return f == null ? clampSize(size) : f.getLineHeight();
    }
}
