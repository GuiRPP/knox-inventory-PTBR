package knox.java;

import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;

import org.lwjglx.input.Cursor;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.ZomboidFileSystem;
import zombie.core.textures.Texture;
import zombie.core.utils.NativeImage;
import zombie.input.Mouse;

/**
 * Knox's mouse cursor (media/ui/knox_cursor.png in Knox Inventory).
 *
 * The game makes its cursor once at start (Mouse.initCustomCursor) from its
 * own media folder, so a mod's file never replaces it. Here the mod's image
 * becomes the system cursor, and also the game's default cursor (used again
 * when the game re-applies it) and the drawn cursor (Mouse.renderCursorTexture,
 * used while the system one is hidden).
 *
 * The skin (KnoxTheme skins, beta) repaints it: every pixel of the sand arrow
 * becomes the skin's main colour at the same brightness against the sand - the
 * fill the colour, the outline a dark shade of it, the shadow stays black
 * (knoxCursorTint). The drawn cursor takes media/ui/knox_cursor_<skin>.png when
 * the mod has one (made by tools\make_cursors.ps1), else the sand one.
 */
public class KnoxCursor {

    static final String FILE = "media/ui/knox_cursor.png";
    static boolean applied;

    // the skin: its id, and its main colour (r < 0: none, the sand arrow as it is)
    static String skin = "sand";
    static float tr = -1f, tg, tb;

    /** Put Knox's cursor on; true when it is on. */
    @LuaMethod(name = "knoxApplyCursor", global = true)
    public static boolean knoxApplyCursor() {
        if (applied) return true;
        try {
            Cursor cursor = load(FILE);
            if (cursor == null) return false;
            set("defaultCursor", cursor);
            org.lwjglx.input.Mouse.setNativeCursor(cursor);
            Texture tex = texture(FILE);
            if (tex != null) set("mouseCursorTexture", tex);
            applied = true;
            return true;
        } catch (Exception | LinkageError e) {
            System.out.println("[Knox] cursor: " + e);
            return false;
        }
    }

    // The cursor while the left button is held: the same arrow a little smaller,
    // drawn towards its tip (media/ui/knox_cursor_down.png) - it "presses".
    static final String FILE_DOWN = "media/ui/knox_cursor_down.png";
    static Cursor up, down;
    static Texture upTex, downTex;
    static boolean pressed, pressBroken;

    /** Where in a pixel int each channel lies (bit shifts r, g, b, a), found once. */
    static int[] shifts;

    /** The shifts, from the sand pixel the arrow is filled with (D4 C3 8A, opaque). */
    static int[] findShifts(IntBuffer px) {
        int[] s = {0, 8, 16, 24};
        for (int i = 0; i < px.limit(); i++) {
            int v = px.get(i);
            int sr = -1, sg = -1, sb = -1, sa = -1;
            for (int sh : s) {
                int c = (v >>> sh) & 255;
                if (c == 0xD4) sr = sh; else if (c == 0xC3) sg = sh; else if (c == 0x8A) sb = sh; else if (c == 0xFF) sa = sh;
            }
            if (sr >= 0 && sg >= 0 && sb >= 0 && sa >= 0) return new int[] {sr, sg, sb, sa};
        }
        return null;
    }

    /** The image as a cursor, repainted in the skin's colour when there is one. */
    static Cursor load(String file) throws Exception {
        String path = ZomboidFileSystem.instance.getAbsolutePath(file);
        if (path == null) return null;
        try (NativeImage image = NativeImage.read(path, true)) {
            if (image == null) return null;
            ByteBuffer bytes = image.pixels();
            IntBuffer px = bytes.asIntBuffer();
            if (tr >= 0f) {
                if (shifts == null) shifts = findShifts(px);
                if (shifts != null) {
                    ByteBuffer out = ByteBuffer.allocateDirect(px.limit() * 4).order(bytes.order());
                    IntBuffer o = out.asIntBuffer();
                    int sr = shifts[0], sg = shifts[1], sb = shifts[2], sa = shifts[3];
                    for (int i = 0; i < px.limit(); i++) {
                        int v = px.get(i);
                        int a = (v >>> sa) & 255;
                        int r = (v >>> sr) & 255, g = (v >>> sg) & 255, b = (v >>> sb) & 255;
                        // (its brightness against the sand's: the fill 1, the outline about 0.3)
                        float k = (r + g + b) / 545f;
                        int nr = Math.min(255, Math.round(tr * 255f * k));
                        int ng = Math.min(255, Math.round(tg * 255f * k));
                        int nb = Math.min(255, Math.round(tb * 255f * k));
                        o.put(i, (a << sa) | (nr << sr) | (ng << sg) | (nb << sb));
                    }
                    return new Cursor(image.width(), image.height(), 1, 1, 1, o, null);
                }
            }
            return new Cursor(image.width(), image.height(), 1, 1, 1, px, null);
        }
    }

    /** The drawn cursor: the skin's own picture if the mod has one, else the sand one. */
    static Texture texture(String file) {
        if (!"sand".equals(skin) && !"custom".equals(skin)) {
            String own = file.replace(".png", "_" + skin + ".png");
            if (ZomboidFileSystem.instance.getAbsolutePath(own) != null) {
                Texture t = Texture.getSharedTexture(own);
                if (t != null) return t;
            }
        }
        return Texture.getSharedTexture(file);
    }

    /**
     * Asked by Lua when the left button goes down or up: the pressed or the
     * plain cursor, as the system cursor, the game's default one and the drawn
     * one. False when Knox's cursor is not on or the pictures can't be read.
     */
    @LuaMethod(name = "knoxCursorPress", global = true)
    public static boolean knoxCursorPress(boolean on) {
        if (!applied || pressBroken) return false;
        if (on == pressed && up != null) return true;
        return show(on);
    }

    static boolean show(boolean on) {
        try {
            if (up == null) {
                up = load(FILE);
                down = load(FILE_DOWN);
                upTex = texture(FILE);
                downTex = texture(FILE_DOWN);
                if (up == null || down == null) {
                    pressBroken = true;
                    return false;
                }
            }
            Cursor cursor = on ? down : up;
            set("defaultCursor", cursor);
            org.lwjglx.input.Mouse.setNativeCursor(cursor);
            Texture tex = on ? downTex : upTex;
            if (tex != null) set("mouseCursorTexture", tex);
            pressed = on;
            return true;
        } catch (Exception | LinkageError e) {
            pressBroken = true;
            System.out.println("[Knox] cursor press: " + e);
            return false;
        }
    }

    /**
     * The skin's main colour for the cursor (KnoxTheme.applySkin): "sand" leaves
     * the arrow as it is drawn. Put on at once when Knox's cursor is on.
     */
    @LuaMethod(name = "knoxCursorTint", global = true)
    public static boolean knoxCursorTint(double r, double g, double b, String id) {
        String newSkin = id == null ? "sand" : id;
        float nr = "sand".equals(newSkin) ? -1f : (float) r, ng = (float) g, nb = (float) b;
        if (newSkin.equals(skin) && nr == tr && ng == tg && nb == tb) return true;
        skin = newSkin;
        tr = nr;
        tg = ng;
        tb = nb;
        up = null;
        down = null;
        if (!applied || pressBroken) return false;
        return show(pressed);
    }

    static void set(String name, Object value) throws ReflectiveOperationException {
        Field f = Mouse.class.getDeclaredField(name);
        f.setAccessible(true);
        f.set(null, value);
    }
}
