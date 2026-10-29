package knox.java;

import java.util.function.Consumer;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.textures.Texture;
import zombie.core.textures.TextureDraw;

/**
 * The main menu fading away while a hero gets up and walks off into his save
 * (the author's wish, 2026-10-15: the buttons, the news, the title, the
 * settings - everything over the camp - goes with the music). The menu is
 * many elements of the game's and of Knox's, drawn every which way; all of it
 * ends in the SpriteRenderer, so the alpha of what is drawn there is scaled.
 * The camp itself (KnoxMenuScene and its 3D scene) and the black curtain are
 * drawn with the scaling off (knoxMenuUiSkip around them).
 *
 * Off (1) except while Lua sets it; set back to 1 when the loading screen
 * comes, and on its own when Lua has not set it for a second - the game's
 * own screens can never be left faded.
 */
public class KnoxUiFade {

    // (public: the patches' code runs inside the game's SpriteRenderer, and reads
    // them from there - package-private, the game crashed at its first frame)
    // (plain fields: Lua and the drawing are both on the main thread, and these
    // are read for every sprite drawn)
    public static float alpha = 1f;
    public static boolean skip;
    public static long setAt;

    /** The menu's alpha now (1: as it is). */
    @LuaMethod(name = "knoxMenuUiAlpha", global = true)
    public static void knoxMenuUiAlpha(double a) {
        alpha = (float) Math.max(0.0, Math.min(1.0, a));
        setAt = System.currentTimeMillis();
    }

    /** True while the camp (or the curtain) draws: not faded. */
    @LuaMethod(name = "knoxMenuUiSkip", global = true)
    public static void knoxMenuUiSkip(boolean on) {
        skip = on;
    }

    public static void off() {
        alpha = 1f;
        skip = false;
    }

    /** The alpha to draw with: `a` scaled while the menu fades. */
    public static float scaled(float a) {
        if (System.currentTimeMillis() - setAt > 1000L) {
            alpha = 1f;   // (not set any more: whatever was fading is gone)
            return a;
        }
        return a * alpha;
    }

    // The ways the UI and its text are drawn (UIElement's Draw*, AngelCodeFont):
    // each names its parameters, so the patcher takes that one overload; the
    // alpha is the 9th parameter in all of them. Outside a fade they cost a look
    // at two fields.
    // (they also count the sprites while a ready list is written or checked: KnoxDrawList)

    @Patch(className = "zombie.core.SpriteRenderer", methodName = "renderi")
    public static class Ri {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Texture tex, @Patch.Argument(1) int x, @Patch.Argument(2) int y,
                                 @Patch.Argument(3) int w, @Patch.Argument(4) int h, @Patch.Argument(5) float r,
                                 @Patch.Argument(6) float g, @Patch.Argument(7) float b,
                                 @Patch.Argument(value = 8, readOnly = false) float a,
                                 @Patch.Argument(9) Consumer<TextureDraw> c) {
            if (KnoxDrawList.counting) KnoxDrawList.sprites++;
            if (KnoxUiFade.alpha < 1f && !KnoxUiFade.skip) a = KnoxUiFade.scaled(a);
        }
    }

    @Patch(className = "zombie.core.SpriteRenderer", methodName = "render")
    public static class R {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Texture tex, @Patch.Argument(1) float x, @Patch.Argument(2) float y,
                                 @Patch.Argument(3) float w, @Patch.Argument(4) float h, @Patch.Argument(5) float r,
                                 @Patch.Argument(6) float g, @Patch.Argument(7) float b,
                                 @Patch.Argument(value = 8, readOnly = false) float a,
                                 @Patch.Argument(9) Consumer<TextureDraw> c) {
            if (KnoxDrawList.counting) KnoxDrawList.sprites++;
            if (KnoxUiFade.alpha < 1f && !KnoxUiFade.skip) a = KnoxUiFade.scaled(a);
        }
    }

    @Patch(className = "zombie.core.SpriteRenderer", methodName = "render")
    public static class RUv {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Texture tex, @Patch.Argument(1) float x, @Patch.Argument(2) float y,
                                 @Patch.Argument(3) float w, @Patch.Argument(4) float h, @Patch.Argument(5) float r,
                                 @Patch.Argument(6) float g, @Patch.Argument(7) float b,
                                 @Patch.Argument(value = 8, readOnly = false) float a,
                                 @Patch.Argument(9) float u1, @Patch.Argument(10) float v1, @Patch.Argument(11) float u2,
                                 @Patch.Argument(12) float v2, @Patch.Argument(13) float u3, @Patch.Argument(14) float v3,
                                 @Patch.Argument(15) float u4, @Patch.Argument(16) float v4) {
            if (KnoxDrawList.counting) KnoxDrawList.sprites++;
            if (KnoxUiFade.alpha < 1f && !KnoxUiFade.skip) a = KnoxUiFade.scaled(a);
        }
    }
}
