package knox.java;

import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

import me.zed_0xff.zombie_buddy.Patch;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.ZomboidFileSystem;
import zombie.core.textures.Texture;
import zombie.core.utils.NativeImage;

/**
 * While the Knox screen is open the game counts the mouse as over its
 * inventory (UIManager.isMouseOverInventory), as with its own inventory
 * windows: the character input then ignores Ctrl and the mouse buttons
 * (CharacterInputKeyBinding.isMouseOrControlKeyOverInventory), so Ctrl+click
 * selecting tiles no longer makes the character aim, and clicks don't swing.
 */
public class KnoxInput {

    /** Set by Lua when the Knox screen opens and closes. */
    public static volatile boolean screenOpen;

    /**
     * The menu on R is open (KnoxRMenu.lua, the author, 2026-10-31). Clicks made while it
     * is open it takes itself, on an element over the whole screen; this holds what was
     * already down when it opened (the right button aiming) and the keys bound to the
     * mouse. The cursor is hidden meanwhile.
     */
    public static volatile boolean rMenuOpen;

    @LuaMethod(name = "knoxSetScreenOpen", global = true)
    public static void knoxSetScreenOpen(boolean open) {
        screenOpen = open;
    }

    @LuaMethod(name = "knoxSetRMenuOpen", global = true)
    public static void knoxSetRMenuOpen(boolean open) {
        rMenuOpen = open;
        KnoxCursor.hide(open);
    }

    @Patch(className = "zombie.ui.UIManager", methodName = "isMouseOverInventory")
    public static class OverInventory {
        @Patch.OnExit
        public static void exit(@Patch.Return(readOnly = false) boolean result) {
            if (KnoxInput.screenOpen || KnoxInput.rMenuOpen) result = true;
        }
    }

    // Where a picture's pixels are (the menu on R centres its pictures by them, the author,
    // 2026-10-31). The game's packs cut the empty edges off a picture and it draws such
    // one by what is left, so it is in the middle as it is; a picture of its own file
    // keeps them: read from the file once.
    static final Map<Texture, double[]> inks = new HashMap<>();
    static final double[] NO_INK = {0, 0};

    /** How far the pixels' middle is from the picture's, in parts of its longer side. */
    static double[] inkOf(Texture t) {
        if (t == null) return NO_INK;
        double[] c = inks.get(t);
        if (c != null) return c;
        c = NO_INK;
        try {
            if (t.getWidth() == t.getWidthOrig() && t.getHeight() == t.getHeightOrig()) c = read(t.getName());
        } catch (Exception | LinkageError e) {
            System.out.println("[Knox] picture " + t.getName() + ": " + e);
        }
        inks.put(t, c);
        return c;
    }

    static double[] read(String name) {
        if (name == null) return NO_INK;
        String[] tries = {name, "media/textures/" + name + ".png", "media/ui/" + name + ".png"};
        for (String file : tries) {
            String path = ZomboidFileSystem.instance.getAbsolutePath(file);
            if (path == null) continue;
            try (NativeImage image = NativeImage.read(path, false)) {
                if (image == null) continue;
                return inkIn(image.pixels(), image.width(), image.height());
            }
        }
        return NO_INK;
    }

    /** From an image's rows of RGBA bytes. */
    static double[] inkIn(ByteBuffer px, int w, int h) {
        int left = w, right = -1, top = h, bottom = -1;
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                if ((px.get((y * w + x) * 4 + 3) & 255) < 16) continue;
                if (x < left) left = x;
                if (x > right) right = x;
                if (y < top) top = y;
                if (y > bottom) bottom = y;
            }
        }
        if (right < 0) return NO_INK;
        double side = Math.max(w, h);
        return new double[] {((left + right + 1) / 2.0 - w / 2.0) / side, ((top + bottom + 1) / 2.0 - h / 2.0) / side};
    }

    @LuaMethod(name = "knoxTexInkX", global = true)
    public static double knoxTexInkX(Texture t) {
        return inkOf(t)[0];
    }

    @LuaMethod(name = "knoxTexInkY", global = true)
    public static double knoxTexInkY(Texture t) {
        return inkOf(t)[1];
    }
}
