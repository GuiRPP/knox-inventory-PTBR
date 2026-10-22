package knox.java;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.Core;
import zombie.core.SpriteRenderer;
import zombie.core.Translator;
import zombie.core.fonts.AngelCodeFont;
import zombie.core.textures.Texture;
import zombie.ui.UIFont;

/**
 * The loading screen in Knox's look. The words are the game's own (the three
 * phrases of a new game, "Loading", the tips, "Click to start"); how they are
 * shown is ours:
 *   - behind everything the menu's camp, dimmed: sky, tree line, ground
 *   - the phrases in the middle in Knox's title font, capitals, a sand rule
 *     under them
 *   - bottom left a tip with a "Tip" plate, bottom right "Click to start" as
 *     a key hint, along the bottom edge a sand bar that runs while loading
 *     (the game tells no real progress) and is full when it is done
 *   - no walking figure
 *
 * The game's own render stays in charge of time, stages and input. While it
 * runs, what it would write is caught instead of drawn (the patches of
 * TextManager below) and its walking figure is skipped; just before it ends
 * its frame (ActiveMods.renderUI) the whole screen is drawn here from what
 * was caught. Text in fonts this does not know (errors, a lost connection)
 * is left to the game and still shows.
 */
public class KnoxLoading {

    /** the game's loading render is running */
    public static volatile boolean active;
    /** the text patches work (without them the screen is left to the game) */
    public static volatile boolean hooked;
    /** the player's switch (the mod's "new game" part): off leaves the screen to the game */
    public static volatile boolean enabled = true;
    /**
     * The game's language has letters Knox's atlases lack (Chinese, Japanese, Korean, Thai...):
     * they would come out as "???", so the screen is left to the game. Looked at on the texts
     * themselves; forgotten when the Lua reloads (the language may have changed).
     */
    public static volatile boolean foreign;

    // caught this frame
    public static String phrase, tip, start, loading;
    public static float phraseAlpha, startAlpha;

    private static final long START = System.nanoTime();

    static final float[] ACCENT = {0.831f, 0.765f, 0.541f}, BRIGHT = {0.925f, 0.910f, 0.847f}, TEXT = {0.851f, 0.839f, 0.784f},
        DIM = {0.561f, 0.573f, 0.537f}, INK = {0.078f, 0.078f, 0.078f}, WINDOW = {0.071f, 0.078f, 0.078f},
        FRAME = {0.357f, 0.380f, 0.361f}, BORDER = {0.165f, 0.180f, 0.180f};

    /** Ask for the atlases the screen writes with, ahead of time (they load in the background). */
    @LuaMethod(name = "knoxLoadingPreload", global = true)
    public static boolean knoxLoadingPreload() {
        return ready();
    }

    @LuaMethod(name = "knoxLoadingEnable", global = true)
    public static void knoxLoadingEnable(boolean on) {
        enabled = on;
        foreign = false;
    }

    /** Has the screen's text atlas every character of `text`? (Asked only once the atlases are loaded.) */
    static boolean covers(String text) {
        try {
            AngelCodeFont f = fText();
            if (f == null || f.chars == null) return false;
            for (int i = 0; i < text.length(); i++) {
                char c = text.charAt(i);
                if (c == '\n' || c == '\r' || c == '\t' || c == ' ') continue;
                if (c >= f.chars.length || f.chars[c] == null) return false;
            }
            return true;
        } catch (RuntimeException | LinkageError e) {
            return false;
        }
    }

    static String nz(String s) {
        return s == null ? "" : s;
    }

    static float cell() {
        return Math.max(30f, Core.getInstance().getScreenHeight() * 48f / 1080f);
    }

    static AngelCodeFont fTitle() { return KnoxFonts.font("title", 44); }
    static AngelCodeFont fHeader() { return KnoxFonts.font("title", cell() * 0.42); }
    static AngelCodeFont fText() { return KnoxFonts.font("body", cell() * 0.31); }
    static AngelCodeFont fCaps() { return KnoxFonts.font("head", cell() * 0.29); }
    static AngelCodeFont fTile() { return KnoxFonts.font("head", cell() * 0.25); }

    static boolean ok(AngelCodeFont f) {
        return f != null && !f.isLoading();
    }

    public static boolean ready() {
        try {
            // (all of them asked for, so that all of them start loading)
            boolean a = ok(fTitle()), b = ok(fHeader()), c = ok(fText()), d = ok(fCaps()), e = ok(fTile());
            return a && b && c && d && e;
        } catch (RuntimeException | LinkageError e) {
            return false;
        }
    }

    // ---------------------------------------------------------------- catching

    public static void begin() {
        phrase = null;
        tip = null;
        start = null;
        loading = null;
        phraseAlpha = 0f;
        startAlpha = 0f;
        active = enabled && !foreign && ready();
    }

    public static void end() {
        active = false;
    }

    /** A centred text of the game's loading render: taken (true) or left to the game. */
    public static boolean caught(UIFont font, String text, double a) {
        if (!active || font == null || text == null) return false;
        if (!covers(text)) {
            // this frame and all after it are the game's own (texts already taken this frame are lost for it)
            foreign = true;
            active = false;
            return false;
        }
        hooked = true;
        float alpha = (float) a;
        if (font == UIFont.Intro) {
            // (the three phrases are all "drawn" every frame, two of them at alpha 0)
            if (alpha > phraseAlpha || phrase == null) {
                phrase = text;
                phraseAlpha = alpha;
            }
            return true;
        }
        if (font == UIFont.NewLarge) {
            start = text;
            startAlpha = alpha;
            return true;
        }
        if (font == UIFont.NewMedium) {
            tip = text;
            return true;
        }
        if (font == UIFont.NewSmall) {
            loading = text;
            return true;
        }
        return false;
    }

    /** The dots after "Loading", written apart by the game: dropped. */
    public static boolean caughtPlain(UIFont font) {
        return active && font == UIFont.NewSmall;
    }

    @Patch(className = "zombie.gameStates.GameLoadingState", methodName = "render")
    public static class Render {
        @Patch.OnEnter
        public static void enter() {
            KnoxLoading.begin();
            KnoxMusic.loadingFrame();
            KnoxCamp.loadingFrame();
            KnoxUiFade.off();
        }

        @Patch.OnExit
        public static void exit() {
            KnoxLoading.end();
        }
    }

    // The two text patches name every parameter: the patcher picks the one
    // overload with these types (the game has several), and nothing is boxed
    // or allocated - these run for every text the game draws, anywhere, and
    // outside the loading screen cost one look at `active`.
    @Patch(className = "zombie.ui.TextManager", methodName = "DrawStringCentre")
    public static class Centre {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) UIFont font, @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                    @Patch.Argument(3) String text, @Patch.Argument(4) double r, @Patch.Argument(5) double g,
                                    @Patch.Argument(6) double b, @Patch.Argument(7) double a) {
            return KnoxLoading.active && KnoxLoading.caught(font, text, a);
        }
    }

    @Patch(className = "zombie.ui.TextManager", methodName = "DrawString")
    public static class Plain {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) UIFont font, @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                    @Patch.Argument(3) String text, @Patch.Argument(4) double r, @Patch.Argument(5) double g,
                                    @Patch.Argument(6) double b, @Patch.Argument(7) double a) {
            return KnoxLoading.active && KnoxLoading.caughtPlain(font);
        }
    }

    @Patch(className = "zombie.core.textures.AnimatedTexture", methodName = "render")
    public static class Figure {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter() {
            return KnoxLoading.active && KnoxLoading.hooked;
        }
    }

    @Patch(className = "zombie.modding.ActiveMods", methodName = "renderUI")
    public static class Frame {
        @Patch.OnEnter
        public static void enter() {
            if (KnoxLoading.active && KnoxLoading.hooked) KnoxLoading.draw();
        }
    }

    // ----------------------------------------------------------------- drawing

    static void rect(float x, float y, float w, float h, float[] c, float a) {
        SpriteRenderer.instance.renderi(null, (int) x, (int) y, (int) w, (int) h, c[0], c[1], c[2], a, null);
    }

    static void frame(float x, float y, float w, float h, float[] c, float a, int t) {
        rect(x, y, w, t, c, a);
        rect(x, y + h - t, w, t, c, a);
        rect(x, y, t, h, c, a);
        rect(x + w - t, y, t, h, c, a);
    }

    static void tex(String path, float x, float y, float w, float h, float r, float g, float b, float a) {
        Texture t = Texture.getSharedTexture(path);
        if (t == null) return;
        SpriteRenderer.instance.render(t, x, y, w, h, r, g, b, a, null);
    }

    static void text(AngelCodeFont f, String s, float x, float y, float[] c, float a) {
        f.drawString((float) (int) x, (float) (int) y, s, c[0], c[1], c[2], a);
    }

    /**
     * How far a letter moves the pen: the font's own step (xadvance). The game's
     * getWidth of one letter is the width of its picture instead, without the
     * room the font gives it on either side - letters were set apart by that,
     * and the ones with wide sides (Г, Т, А) stood further from the next one
     * than the rest (seen by the author 2026-10-20).
     */
    static float advance(AngelCodeFont f, char ch) {
        if (ch == ' ') return f.getLineHeight() * 0.28f;
        return f.getWidth(String.valueOf(ch), true);
    }

    /** Width of capitals written with `track` px between letters at `scale`. */
    static float spacedWidth(AngelCodeFont f, String s, float scale, float track) {
        float w = 0;
        for (int i = 0; i < s.length(); i++) w += advance(f, s.charAt(i)) * scale + track;
        return w - track;
    }

    static void spaced(AngelCodeFont f, String s, float x, float y, float scale, float track, float[] c, float a) {
        // (every letter at the nearest whole pixel of its true place: cut down
        // one by one, the gaps came out a pixel apart here and there)
        float pen = x;
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            if (ch != ' ') f.drawString((float) Math.round(pen), (float) (int) y, scale, String.valueOf(ch), c[0], c[1], c[2], a);
            pen += advance(f, ch) * scale + track;
        }
    }

    static String tr(String key) {
        String s = Translator.getTextOrNull(key);
        return s == null ? null : s;
    }

    public static void draw() {
        try {
            drawAll();
        } catch (RuntimeException | LinkageError e) {
            active = false;   // this frame stays as it is; the game's own text comes back with the next
            hooked = false;
            System.out.println("[Knox] loading screen: " + e);
        }
    }

    static void drawAll() {
        int W = Core.getInstance().getScreenWidth(), H = Core.getInstance().getScreenHeight();
        float c = cell();
        int pad = (int) (c / 4);
        int side = Math.max(pad * 3, (int) (W * 0.04f));
        float time = (System.nanoTime() - START) / 1e9f;
        AngelCodeFont title = fTitle(), body = fText(), caps = fCaps(), tile = fTile();
        // (a card of the hero being loaded stood top left; the user had it removed)

        // the camp, dimmed: night sky, the tree line, dark ground
        rect(0, 0, W, H, new float[] {0.012f, 0.014f, 0.02f}, 1f);
        tex("media/ui/knoxmenu/sky.png", 0, 0, W, W / 2f, 1f, 1f, 1f, 0.38f);
        Texture trees = Texture.getSharedTexture("media/ui/knoxmenu/treeline.png");
        float ground = H * 0.80f;
        if (trees != null && trees.getWidth() > 0) {
            float th = W * (float) trees.getHeight() / trees.getWidth();
            SpriteRenderer.instance.render(trees, 0, ground - th, W, th, 0.55f, 0.6f, 0.7f, 0.9f, null);
        }
        rect(0, ground, W, H - ground, new float[] {0.02f, 0.021f, 0.024f}, 1f);
        // (the fire's last glow stood at the bottom: the user had it removed)
        tex("media/ui/knoxmenu/vignette.png", 0, 0, W, H, 1f, 1f, 1f, 1f);

        // the phrase, in the middle
        if (phrase != null && phraseAlpha > 0.004f) {
            String s = phrase.toUpperCase();
            float scale = Math.min(1.6f, Math.max(1f, (H * 0.05f) / 44f));
            float track = c * 0.09f;
            float w = spacedWidth(title, s, scale, track);
            float max = W - side * 2;
            if (w > max) {
                scale *= max / w;
                track *= max / w;
                w = spacedWidth(title, s, scale, track);
            }
            float lh = title.getLineHeight() * scale;
            float y = H / 2f - lh / 2f;
            spaced(title, s, W / 2f - w / 2f, y, scale, track, BRIGHT, phraseAlpha);
            float rule = c * 1.6f;
            rect(W / 2f - rule / 2f, y + lh + pad / 2f, rule, 3, ACCENT, phraseAlpha);
        }

        // bottom row: a tip on the left, "click to start" on the right
        float rowY = H - pad * 2 - 4 - body.getLineHeight();
        float x = side;
        if (tip != null && !tip.isEmpty()) {
            String tag = nz(tr("IGUI_Knox_Load_Tip")).toUpperCase();
            if (!tag.isEmpty()) {
                float tw = tile.getWidth(tag) + 12, th = tile.getLineHeight() + 4;
                float ty = rowY + (body.getLineHeight() - th) / 2f;
                rect(x, ty, tw, th, ACCENT, 1f);
                text(tile, tag, x + 6, ty + 2, INK, 1f);
                x += tw + pad;
            }
            text(body, tip, x, rowY, DIM, 1f);
        } else if (loading != null && start == null) {
            text(caps, loading.replace(".", "").toUpperCase(), x, rowY + 2, DIM, 1f);
        }
        boolean done = start != null;
        if (done) {
            String key = nz(tr("IGUI_Knox_Load_Click"));
            String label = nz(tr("IGUI_Knox_Load_Start"));
            if (label.isEmpty()) label = start;
            float kw = key.isEmpty() ? 0 : tile.getWidth(key) + 14;
            float kh = tile.getLineHeight() + 8;
            float lw = caps.getWidth(label.toUpperCase());
            float sx = W - side - lw - (kw > 0 ? kw + pad : 0);
            float a = Math.max(0.35f, startAlpha);
            if (kw > 0) {
                float ky = rowY + (body.getLineHeight() - kh) / 2f;
                rect(sx, ky, kw, kh, WINDOW, 1f);
                frame(sx, ky, kw, kh, FRAME, 1f, 2);
                text(tile, key, sx + 7, ky + 4, BRIGHT, 1f);
                sx += kw + pad;
            }
            text(caps, label.toUpperCase(), sx, rowY + 2, ACCENT, a);
        }

        // the bar along the bottom edge: runs while loading, full when done
        rect(0, H - 4, W, 4, BORDER, 1f);
        if (done) {
            rect(0, H - 4, W, 4, ACCENT, 1f);
        } else {
            float seg = W * 0.22f;
            float px = ((time * 0.32f) % 1f) * (W + seg) - seg;
            float x0 = Math.max(0, px), x1 = Math.min(W, px + seg);
            if (x1 > x0) rect(x0, H - 4, x1 - x0, 4, ACCENT, 1f);
        }
    }
}
