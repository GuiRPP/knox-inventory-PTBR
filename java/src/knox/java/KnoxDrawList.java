package knox.java;

import java.util.ArrayList;
import java.util.function.Consumer;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.Color;
import zombie.core.textures.Texture;
import zombie.core.textures.TextureDraw;
import zombie.inventory.InventoryItem;
import zombie.ui.UIElement;
import zombie.ui.UIFont;

/**
 * Ready lists (the inventory's FPS, stage 1 - the author, 2026-10-28: the open screen
 * must not cost frames, "a new jar is no problem"). A part of a Knox window that looks
 * the same frame after frame - the bottom bar's key hints, the tabs, the clock between
 * two minutes - is drawn by Lua once while Java writes down what it drew; the next
 * frames Java draws the same again in one call, no Lua, until Lua sees that what the
 * part shows has changed (its key, KnoxTheme T.listDraw) and draws it anew.
 *
 * Written down: the windows' own draw calls - UIElement.DrawTextureScaledCol (every
 * rect, frame and tinted picture of ISUIElement ends there), DrawTextureScaledAspect,
 * DrawTextureCol, the game's DrawText / DrawTextCentre / DrawTextRight, an item's icon
 * (DrawItemIcon: played back it reads the item again - its liquid, its colour) - and
 * Knox's text (knoxDrawText). Played back they are the same calls into the same windows, so
 * a window that moves takes its lists along. Anything else drawn while a list is
 * written would be missing from it: the sprites the game makes are counted while
 * writing and again on the first playing back, and a list whose counts differ is
 * not played again (Lua draws that part itself and writes it anew; console.txt says so).
 */
public class KnoxDrawList {

    static final int RECT = 0, ASPECT = 1, COL = 2, KNOX_TEXT = 3, TEXT = 4, TEXT_CENTRE = 5, TEXT_RIGHT = 6,
        SCALED = 7, PLAIN = 8, ITEM_ICON = 9;
    static final int STRIDE = 9;
    static final int MAX_OPS = 4096;

    // (public: read and called by the patches' code inside the game's classes - package-
    // private members crash the game at its first frame, IllegalAccessError)
    public static KnoxDrawList rec;      // the list being written now (null: none)
    public static boolean counting;      // sprites are counted (a list written or checked)
    public static long sprites;
    // (inside a draw that is written whole - an item's icon - the draws it makes itself
    // are not written again: played back, the icon makes them)
    public static int skip;

    static final ArrayList<KnoxDrawList> LISTS = new ArrayList<>();

    final int id;
    KnoxDrawList parent;   // (a list written inside another: its draws go to that one too)
    UIElement owner;       // Knox's text is kept relative to it
    int n;
    int[] op = new int[64];
    UIElement[] ui = new UIElement[64];
    Object[] obj = new Object[64];
    Object[] obj2 = new Object[64];
    double[] num = new double[64 * STRIDE];
    long spriteStart, spritesWritten;
    boolean ready, checked, broken, told;

    KnoxDrawList(int id) {
        this.id = id;
    }

    // (ZombieBuddy hands the @LuaMethod globals to Lua through an instance made with a
    // public constructor without arguments - none, and knoxList* never reach Lua:
    // the author's run 2026-10-28, "Cannot expose global Lua functions"; not a list)
    public KnoxDrawList() {
        this.id = -1;
    }

    static KnoxDrawList get(int id) {
        if (id < 0 || id > 100000) return null;
        while (LISTS.size() <= id) LISTS.add(null);
        KnoxDrawList l = LISTS.get(id);
        if (l == null) {
            l = new KnoxDrawList(id);
            LISTS.set(id, l);
        }
        return l;
    }

    void push(int kind, UIElement u, Object o, Object o2, double a0, double a1, double a2, double a3,
              double a4, double a5, double a6, double a7, double a8) {
        if (n >= MAX_OPS) {
            broken = true;
            return;
        }
        if (n == op.length) {
            int cap = n * 2;
            op = java.util.Arrays.copyOf(op, cap);
            ui = java.util.Arrays.copyOf(ui, cap);
            obj = java.util.Arrays.copyOf(obj, cap);
            obj2 = java.util.Arrays.copyOf(obj2, cap);
            num = java.util.Arrays.copyOf(num, cap * STRIDE);
        }
        op[n] = kind;
        ui[n] = u;
        obj[n] = o;
        obj2[n] = o2;
        int k = n * STRIDE;
        num[k] = a0;
        num[k + 1] = a1;
        num[k + 2] = a2;
        num[k + 3] = a3;
        num[k + 4] = a4;
        num[k + 5] = a5;
        num[k + 6] = a6;
        num[k + 7] = a7;
        num[k + 8] = a8;
        n++;
    }

    /** A window's draw call, written into the list being written (the patches below). */
    public static void add(int kind, UIElement u, Object o, Object o2, double a0, double a1, double a2, double a3,
                           double a4, double a5, double a6, double a7, double a8) {
        KnoxDrawList l = rec;
        if (l != null && skip == 0) l.push(kind, u, o, o2, a0, a1, a2, a3, a4, a5, a6, a7, a8);
    }

    // Where a window's own draws start: its place on the screen plus its scroll, as the
    // game's draw calls take them (a list of a scrolled panel - the bags - stays right
    // when the panel scrolls)
    static double originX(UIElement u) {
        return u.getAbsoluteX() + u.getXScroll();
    }

    static double originY(UIElement u) {
        return u.getAbsoluteY() + u.getYScroll();
    }

    /** Knox's text (KnoxFonts.knoxDrawText, absolute x, y): kept relative to the list's window. */
    public static void addText(String style, double size, String text, double x, double y,
                               double r, double g, double b, double a) {
        KnoxDrawList l = rec;
        if (l == null || skip > 0) return;
        if (l.owner == null) {
            l.broken = true;
            return;
        }
        l.push(KNOX_TEXT, null, style, text, x - originX(l.owner), y - originY(l.owner), size, r, g, b, a, 0, 0);
    }

    void play() {
        for (int i = 0; i < n; i++) {
            int k = i * STRIDE;
            UIElement u = ui[i];
            switch (op[i]) {
                case RECT:
                    u.DrawTextureScaledCol((Texture) obj[i], num[k], num[k + 1], num[k + 2], num[k + 3],
                        num[k + 4], num[k + 5], num[k + 6], num[k + 7]);
                    break;
                case ASPECT:
                    u.DrawTextureScaledAspect((Texture) obj[i], num[k], num[k + 1], num[k + 2], num[k + 3],
                        num[k + 4], num[k + 5], num[k + 6], num[k + 7]);
                    break;
                case COL:
                    u.DrawTextureColor((Texture) obj[i], num[k], num[k + 1], num[k + 2], num[k + 3], num[k + 4], num[k + 5]);
                    break;
                case KNOX_TEXT:
                    KnoxFonts.knoxDrawText((String) obj[i], num[k + 2], (String) obj2[i],
                        originX(owner) + num[k], originY(owner) + num[k + 1],
                        num[k + 3], num[k + 4], num[k + 5], num[k + 6]);
                    break;
                case TEXT:
                    u.DrawText((UIFont) obj[i], (String) obj2[i], num[k], num[k + 1], num[k + 2], num[k + 3], num[k + 4], num[k + 5]);
                    break;
                case TEXT_CENTRE:
                    u.DrawTextCentre((UIFont) obj[i], (String) obj2[i], num[k], num[k + 1], num[k + 2], num[k + 3], num[k + 4], num[k + 5]);
                    break;
                case TEXT_RIGHT:
                    u.DrawTextRight((UIFont) obj[i], (String) obj2[i], num[k], num[k + 1], num[k + 2], num[k + 3], num[k + 4], num[k + 5]);
                    break;
                case SCALED:
                    u.DrawTextureScaled((Texture) obj[i], num[k], num[k + 1], num[k + 2], num[k + 3], num[k + 4]);
                    break;
                case PLAIN:
                    u.DrawTexture((Texture) obj[i], num[k], num[k + 1], num[k + 2]);
                    break;
                case ITEM_ICON:
                    u.DrawItemIcon((InventoryItem) obj[i], num[k], num[k + 1], num[k + 2], num[k + 3], num[k + 4]);
                    break;
                default:
                    break;
            }
        }
    }

    // Lua -------------------------------------------------------------------------------

    /** Start writing list `id` of window `owner` (what is drawn now is written down). */
    @LuaMethod(name = "knoxListBegin", global = true)
    public static void knoxListBegin(UIElement owner, double id) {
        KnoxDrawList l = get((int) id);
        if (l == null) return;
        if (rec == null) skip = 0;   // (an icon's end missed: not left skipping)
        l.parent = rec == l ? null : rec;
        l.owner = owner;
        l.n = 0;
        l.ready = false;
        l.checked = false;
        l.broken = false;
        l.spriteStart = sprites;
        rec = l;
        counting = true;
    }

    /** The list written: true when it can be played back. */
    @LuaMethod(name = "knoxListEnd", global = true)
    public static boolean knoxListEnd() {
        KnoxDrawList l = rec;
        if (l == null) return false;
        rec = l.parent;
        counting = rec != null;
        l.spritesWritten = sprites - l.spriteStart;
        // (a list inside another: the other one draws all of it too)
        KnoxDrawList p = l.parent;
        l.parent = null;
        if (p != null) {
            for (int i = 0; i < l.n; i++) {
                int k = i * STRIDE;
                double dx = 0, dy = 0;
                if (l.op[i] == KNOX_TEXT && p.owner != null && l.owner != null) {
                    dx = originX(l.owner) - originX(p.owner);
                    dy = originY(l.owner) - originY(p.owner);
                }
                p.push(l.op[i], l.ui[i], l.obj[i], l.obj2[i], l.num[k] + dx, l.num[k + 1] + dy, l.num[k + 2],
                    l.num[k + 3], l.num[k + 4], l.num[k + 5], l.num[k + 6], l.num[k + 7], l.num[k + 8]);
            }
        }
        l.ready = !l.broken && l.owner != null;
        return l.ready;
    }

    /**
     * Draw list `id` of window `owner` again. 0: not drawn (none, broken, another
     * window's) - Lua draws the part itself; 1: drawn; 2: drawn and, played the first
     * time, it drew as many sprites as when it was written.
     */
    @LuaMethod(name = "knoxListDraw", global = true)
    public static int knoxListDraw(UIElement owner, double id) {
        int i = (int) id;
        if (i < 0 || i >= LISTS.size()) return 0;
        KnoxDrawList l = LISTS.get(i);
        if (l == null || !l.ready || l.owner != owner) return 0;
        boolean check = !l.checked && rec == null;
        long start = sprites;
        if (check) counting = true;
        try {
            l.play();
        } catch (Throwable t) {
            l.ready = false;
            if (check) counting = false;
            System.out.println("[Knox] ready list " + i + " failed to draw: " + t);
            return 0;
        }
        if (!check) return 1;
        counting = false;
        l.checked = true;
        long drawn = sprites - start;
        if (drawn != l.spritesWritten) {
            l.ready = false;
            if (!l.told) {
                l.told = true;
                System.out.println("[Knox] ready list " + i + ": written " + l.spritesWritten + " sprites, drawn "
                    + drawn + " - written again (" + l.n + " calls)");
            }
            return 1;
        }
        return 2;
    }

    // What is written: the windows' draw calls --------------------------------------------
    // (each patch names every parameter: the patcher takes that one overload; outside a
    // list they cost a look at `rec`)

    @Patch(className = "zombie.ui.UIElement", methodName = "DrawTextureScaledCol")
    public static class ScaledCol {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) Texture tex,
                                 @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                 @Patch.Argument(3) double w, @Patch.Argument(4) double h,
                                 @Patch.Argument(5) double r, @Patch.Argument(6) double g,
                                 @Patch.Argument(7) double b, @Patch.Argument(8) double a) {
            if (KnoxDrawList.rec != null) KnoxDrawList.add(0, self, tex, null, x, y, w, h, r, g, b, a, 0);
        }
    }

    @Patch(className = "zombie.ui.UIElement", methodName = "DrawTextureScaledAspect")
    public static class ScaledAspect {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) Texture tex,
                                 @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                 @Patch.Argument(3) double w, @Patch.Argument(4) double h,
                                 @Patch.Argument(5) double r, @Patch.Argument(6) double g,
                                 @Patch.Argument(7) double b, @Patch.Argument(8) double a) {
            if (KnoxDrawList.rec != null) KnoxDrawList.add(1, self, tex, null, x, y, w, h, r, g, b, a, 0);
        }
    }

    // (DrawTextureColor puts its colour into a shared Color and calls this one)
    @Patch(className = "zombie.ui.UIElement", methodName = "DrawTextureCol")
    public static class TextureCol {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) Texture tex,
                                 @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                 @Patch.Argument(3) Color c) {
            if (KnoxDrawList.rec != null && c != null) {
                KnoxDrawList.add(2, self, tex, null, x, y, c.r, c.g, c.b, c.a, 0, 0, 0);
            }
        }
    }

    @Patch(className = "zombie.ui.UIElement", methodName = "DrawTextureScaled")
    public static class Scaled {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) Texture tex,
                                 @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                 @Patch.Argument(3) double w, @Patch.Argument(4) double h,
                                 @Patch.Argument(5) double a) {
            if (KnoxDrawList.rec != null) KnoxDrawList.add(7, self, tex, null, x, y, w, h, a, 0, 0, 0, 0);
        }
    }

    @Patch(className = "zombie.ui.UIElement", methodName = "DrawTexture")
    public static class Plain {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) Texture tex,
                                 @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                 @Patch.Argument(3) double a) {
            if (KnoxDrawList.rec != null) KnoxDrawList.add(8, self, tex, null, x, y, a, 0, 0, 0, 0, 0, 0);
        }
    }

    @Patch(className = "zombie.ui.UIElement", methodName = "DrawText")
    public static class Text {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) UIFont font,
                                 @Patch.Argument(1) String text, @Patch.Argument(2) double x,
                                 @Patch.Argument(3) double y, @Patch.Argument(4) double r,
                                 @Patch.Argument(5) double g, @Patch.Argument(6) double b,
                                 @Patch.Argument(7) double a) {
            if (KnoxDrawList.rec != null) KnoxDrawList.add(4, self, font, text, x, y, r, g, b, a, 0, 0, 0);
        }
    }

    @Patch(className = "zombie.ui.UIElement", methodName = "DrawTextCentre")
    public static class TextCentre {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) UIFont font,
                                 @Patch.Argument(1) String text, @Patch.Argument(2) double x,
                                 @Patch.Argument(3) double y, @Patch.Argument(4) double r,
                                 @Patch.Argument(5) double g, @Patch.Argument(6) double b,
                                 @Patch.Argument(7) double a) {
            if (KnoxDrawList.rec != null) KnoxDrawList.add(5, self, font, text, x, y, r, g, b, a, 0, 0, 0);
        }
    }

    @Patch(className = "zombie.ui.UIElement", methodName = "DrawTextRight")
    public static class TextRight {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) UIFont font,
                                 @Patch.Argument(1) String text, @Patch.Argument(2) double x,
                                 @Patch.Argument(3) double y, @Patch.Argument(4) double r,
                                 @Patch.Argument(5) double g, @Patch.Argument(6) double b,
                                 @Patch.Argument(7) double a) {
            if (KnoxDrawList.rec != null) KnoxDrawList.add(6, self, font, text, x, y, r, g, b, a, 0, 0, 0);
        }
    }

    // (x, y, alpha, w, h - as ISUIElement:drawItemIcon passes them)
    @Patch(className = "zombie.ui.UIElement", methodName = "DrawItemIcon")
    public static class ItemIcon {
        @Patch.OnEnter
        public static void enter(@Patch.This UIElement self, @Patch.Argument(0) InventoryItem item,
                                 @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                 @Patch.Argument(3) double a, @Patch.Argument(4) double w,
                                 @Patch.Argument(5) double h) {
            if (KnoxDrawList.rec != null) {
                KnoxDrawList.add(9, self, item, null, x, y, a, w, h, 0, 0, 0, 0);
                KnoxDrawList.skip++;
            }
        }

        @Patch.OnExit
        public static void exit(@Patch.Argument(0) InventoryItem item,
                                @Patch.Argument(1) double x, @Patch.Argument(2) double y,
                                @Patch.Argument(3) double a, @Patch.Argument(4) double w,
                                @Patch.Argument(5) double h) {
            if (KnoxDrawList.skip > 0) KnoxDrawList.skip--;
        }
    }

    // The sprites counted: the ways of the SpriteRenderer the windows draw by that
    // KnoxUiFade does not patch already (it counts in its own three)

    @Patch(className = "zombie.core.SpriteRenderer", methodName = "render")
    public static class CountQuad {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Texture tex, @Patch.Argument(1) double x1, @Patch.Argument(2) double y1,
                                 @Patch.Argument(3) double x2, @Patch.Argument(4) double y2, @Patch.Argument(5) double x3,
                                 @Patch.Argument(6) double y3, @Patch.Argument(7) double x4, @Patch.Argument(8) double y4,
                                 @Patch.Argument(9) float r1, @Patch.Argument(10) float g1, @Patch.Argument(11) float b1,
                                 @Patch.Argument(12) float a1, @Patch.Argument(13) float r2, @Patch.Argument(14) float g2,
                                 @Patch.Argument(15) float b2, @Patch.Argument(16) float a2, @Patch.Argument(17) float r3,
                                 @Patch.Argument(18) float g3, @Patch.Argument(19) float b3, @Patch.Argument(20) float a3,
                                 @Patch.Argument(21) float r4, @Patch.Argument(22) float g4, @Patch.Argument(23) float b4,
                                 @Patch.Argument(24) float a4, @Patch.Argument(25) Consumer<TextureDraw> c) {
            if (KnoxDrawList.counting) KnoxDrawList.sprites++;
        }
    }

    @Patch(className = "zombie.core.SpriteRenderer", methodName = "renderflipped")
    public static class CountFlipped {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Texture tex, @Patch.Argument(1) float x, @Patch.Argument(2) float y,
                                 @Patch.Argument(3) float w, @Patch.Argument(4) float h, @Patch.Argument(5) float r,
                                 @Patch.Argument(6) float g, @Patch.Argument(7) float b, @Patch.Argument(8) float a,
                                 @Patch.Argument(9) Consumer<TextureDraw> c) {
            if (KnoxDrawList.counting) KnoxDrawList.sprites++;
        }
    }

    @Patch(className = "zombie.core.SpriteRenderer", methodName = "renderPoly")
    public static class CountPoly {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Texture tex, @Patch.Argument(1) float x1, @Patch.Argument(2) float y1,
                                 @Patch.Argument(3) float x2, @Patch.Argument(4) float y2, @Patch.Argument(5) float x3,
                                 @Patch.Argument(6) float y3, @Patch.Argument(7) float x4, @Patch.Argument(8) float y4,
                                 @Patch.Argument(9) float r, @Patch.Argument(10) float g, @Patch.Argument(11) float b,
                                 @Patch.Argument(12) float a) {
            if (KnoxDrawList.counting) KnoxDrawList.sprites++;
        }
    }

    @Patch(className = "zombie.core.SpriteRenderer", methodName = "renderline")
    public static class CountLine {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) Texture tex, @Patch.Argument(1) int x1, @Patch.Argument(2) int y1,
                                 @Patch.Argument(3) int x2, @Patch.Argument(4) int y2, @Patch.Argument(5) float r,
                                 @Patch.Argument(6) float g, @Patch.Argument(7) float b, @Patch.Argument(8) float a,
                                 @Patch.Argument(9) float thickness) {
            if (KnoxDrawList.counting) KnoxDrawList.sprites++;
        }
    }
}
