package knox.java;

import se.krka.kahlua.integration.annotations.LuaMethod;
import se.krka.kahlua.vm.KahluaTable;
import zombie.inventory.InventoryItem;
import zombie.ui.UIElement;

/**
 * The quiet tiles of a Knox grid, drawn in one call (KnoxGridView.renderGrid).
 *
 * A tile is made of some ten draws (its plate, frame, icon, marks).
 * Each draw from Lua into the game costs a few microseconds of crossing over,
 * and a floor of 270 things kept 1.5 ms a frame on that alone - 180 FPS fell
 * to 125 with the floor open (the author's test, 2026-10-15). Here the same
 * draws are made from Java for every tile that nothing is happening to (not
 * hovered, selected, searched, settling, flashing...); Lua draws the others
 * itself, as before, and the stack counts over all of them (text).
 *
 * A tile is the grid's own Lua table: x, y, r, w, h, item, overflow, and
 * `draw` - what KnoxGridView:tileInfo worked out once per grid build: cat
 * (a color), cookBase, cookBar, cookFrac, level, done, locked,
 * freshColor, hasTex, iconOpaque. Colors are Lua tables {r, g, b}; the
 * palette is KnoxTheme.color. Must draw exactly what KnoxGridView:drawTile
 * draws for such a tile at full alpha.
 */
public class KnoxTiles {

    static double num(KahluaTable t, String k, double def) {
        Object o = t.rawget(k);
        return o instanceof Double ? (Double) o : def;
    }

    static boolean yes(KahluaTable t, String k) {
        return Boolean.TRUE.equals(t.rawget(k));
    }

    static KahluaTable tab(KahluaTable t, String k) {
        Object o = t.rawget(k);
        return o instanceof KahluaTable ? (KahluaTable) o : null;
    }

    static void rect(UIElement ui, double x, double y, double w, double h, KahluaTable c, double a) {
        if (c == null || w <= 0 || h <= 0) return;
        ui.DrawTextureScaledCol(null, x, y, w, h, num(c, "r", 0), num(c, "g", 0), num(c, "b", 0), a);
    }

    /**
     * A tile's background: its colour filled up to its level inside the 2 px frame, no
     * level as full (KnoxTheme.tileFill, condition_v3, the author, 2026-10-31).
     */
    static void fill(UIElement ui, KahluaTable pal, double x, double y, double w, double h, KahluaTable d) {
        KahluaTable cat = tab(d, "cat");
        Object o = d.rawget("level");
        rect(ui, x, y, w, h, tab(pal, "cell"), 1);
        double level = o instanceof Double ? (Double) o : 1;
        if (level <= 0) return;
        double fh = Math.max(4, Math.floor((h - 6) * Math.min(1, level) + 0.5));
        rect(ui, x + 2, y + h - 3 - fh, w - 4, fh + 1, cat, 1);
    }

    /**
     * Draw tiles 1..n of `list` into grid element `ui`; `cell` is the cell's
     * size in pixels, `pal` the palette. A tile that is not what this expects
     * is left out (never an error in the middle of a frame).
     */
    @LuaMethod(name = "knoxDrawTiles", global = true)
    public static void knoxDrawTiles(UIElement ui, KahluaTable list, double n, double cell, KahluaTable pal) {
        if (ui == null || list == null || pal == null) return;
        int count = (int) n;
        double cs = cell;
        KahluaTable frameC = tab(pal, "tileFrame");
        KahluaTable badC = tab(pal, "bad");
        KahluaTable accent = tab(pal, "accent");
        for (int i = 1; i <= count; i++) {
            Object o = list.rawget(i);
            if (!(o instanceof KahluaTable)) continue;
            KahluaTable e = (KahluaTable) o;
            KahluaTable d = tab(e, "draw");
            Object io = e.rawget("item");
            if (d == null || !(io instanceof InventoryItem)) continue;
            InventoryItem item = (InventoryItem) io;
            try {
                double tw = num(e, "w", 1), th = num(e, "h", 1);
                if (num(e, "r", 0) == 1) {
                    double s = tw;
                    tw = th;
                    th = s;
                }
                double x = num(e, "x", 0) * cs + 1, y = num(e, "y", 0) * cs + 1;
                double pw = tw * cs - 1, ph = th * cs - 1;

                fill(ui, pal, x, y, pw, ph, d);
                // food: frozen, cooking, done, burning
                KahluaTable cb = tab(d, "cookBase");
                if (cb != null) rect(ui, x, y, pw, ph, cb, 0.22);
                KahluaTable bar = tab(d, "cookBar");
                if (bar != null) {
                    double fh = Math.floor(ph * num(d, "cookFrac", 0) + 0.5);
                    if (fh > 0) {
                        rect(ui, x, y + ph - fh, pw, fh, bar, 0.5);
                        rect(ui, x, y + ph - fh, pw, Math.min(2, fh), bar, 0.95);
                    }
                }
                // the 2 px frame (red: it doesn't fit the grid)
                KahluaTable fc = yes(e, "overflow") ? badC : frameC;
                rect(ui, x, y, pw, 2, fc, 1);
                rect(ui, x, y + ph - 2, pw, 2, fc, 1);
                rect(ui, x, y + 2, 2, ph - 4, fc, 1);
                rect(ui, x + pw - 2, y + 2, 2, ph - 4, fc, 1);
                // the icon
                if (yes(d, "hasTex")) {
                    double side = Math.floor(Math.min(pw, ph) * 0.85);
                    ui.DrawItemIcon(item, x + Math.floor((pw - side) / 2), y + Math.floor((ph - side) / 2), 1.0, side, side);
                }
                // read / watched: the top right corner folded down
                if (yes(d, "done")) {
                    int dd = (int) Math.max(8, Math.floor(cs / 4));
                    double right = x + pw - 2, top = y + 2;
                    for (int k = 0; k < dd; k++) {
                        int len = dd - k;
                        rect(ui, right - len, top + k, len, 1, accent, 0.9);
                    }
                }
                // locked: a small padlock top left
                if (yes(d, "locked")) {
                    double u = Math.max(2, Math.floor(cs / 22 + 0.5));
                    double lx = x + 4, ly = y + 4;
                    rect(ui, lx + u, ly, u * 3, u, accent, 1);
                    rect(ui, lx + u, ly, u, u * 2, accent, 1);
                    rect(ui, lx + u * 3, ly, u, u * 2, accent, 1);
                    rect(ui, lx, ly + u * 2, u * 5, u * 3, accent, 1);
                }
                // food going stale or rotten: a dot
                KahluaTable fresh = tab(d, "freshColor");
                if (fresh != null) {
                    double s = Math.max(4, Math.floor(cs / 10));
                    rect(ui, x + 3, y + 3, s, s, fresh, 1);
                }
            } catch (RuntimeException ex) {
                // a tile not as expected: left undrawn this frame
            }
        }
    }
}
