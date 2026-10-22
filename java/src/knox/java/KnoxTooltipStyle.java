package knox.java;

import java.lang.reflect.Field;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.Core;
import zombie.core.Translator;
import zombie.core.fonts.AngelCodeFont;
import zombie.ui.ObjectTooltip;
import zombie.ui.UIFont;

/**
 * Item tooltips in Knox's look.
 *
 * The game builds an item tooltip in Java (InventoryItem.DoTooltip draws on an
 * ObjectTooltip). Lua (KnoxTooltip.lua) wraps both of its passes, measure and
 * draw, in knoxTooltipBegin / knoxTooltipEnd. In between:
 *  - ObjectTooltip's text goes out in Knox's font, colors moved to the palette
 *    (the name on top in the bold style);
 *  - TextManager.MeasureStringX answers with Knox's widths, so the layout fits;
 *  - the line spacing and paddings follow Knox's font;
 *  - progress bars are thin Knox meters.
 * Outside of that nothing changes, other tooltips keep the game's look.
 *
 * Advice code is inlined into the game classes, so everything it uses is public.
 */
public class KnoxTooltipStyle {

    /** Set while Lua draws an item tooltip (UI thread only). */
    public static boolean active;
    public static String style = "body";
    public static String titleStyle = "title";
    public static int size = 15;
    /** Longer label and value lines are wrapped at words (descriptions made tooltips very wide). */
    public static int maxWidth = 440;
    /** Name of the item: the first text drawn, in the title style. */
    public static String title;
    public static boolean titlePending;
    /** Knox draws its own header (icon, name, category): the game's name line is left out. */
    public static boolean hideTitle;
    /** Line spacing and top padding of the current pass, for Lua's layout. */
    public static int lineNow, padYNow;

    // palette (mockup)
    static final float[] LABEL = rgb(0xb9b6a8);
    static final float[] VALUE = rgb(0xece8d8);
    static final float[] GOOD = rgb(0x9fb36a);
    static final float[] BAD = rgb(0xd98a7c);
    static final float[] TRACK = rgb(0x262a2a);

    static float[] rgb(int c) {
        return new float[] {((c >> 16) & 255) / 255f, ((c >> 8) & 255) / 255f, (c & 255) / 255f};
    }

    // ObjectTooltip's private statics, saved while ours are in place
    private static Field fLineSpacing, fPadLeft, fPadRight, fPadTop, fPadBottom;
    private static int[] saved;

    private static Field field(String name) throws ReflectiveOperationException {
        Field f = ObjectTooltip.class.getDeclaredField(name);
        f.setAccessible(true);
        return f;
    }

    /** Start of a tooltip pass: Knox's metrics in, the game's kept aside. */
    @LuaMethod(name = "knoxTooltipBegin", global = true)
    public static boolean knoxTooltipBegin(String bodyStyle, String headStyle, double fontSize, String itemName) {
        AngelCodeFont f = KnoxFonts.font(bodyStyle, fontSize);
        if (f == null || f.isLoading()) return false;
        try {
            if (fLineSpacing == null) {
                fLineSpacing = field("lineSpacing");
                fPadLeft = field("staticPadLeft");
                fPadRight = field("staticPadRight");
                fPadTop = field("staticPadTop");
                fPadBottom = field("staticPadBottom");
            }
            ObjectTooltip.checkFont();   // the game's values for the current option
            if (saved == null) {
                saved = new int[] {fLineSpacing.getInt(null), fPadLeft.getInt(null), fPadRight.getInt(null),
                        fPadTop.getInt(null), fPadBottom.getInt(null)};
            }
            int line = f.getLineHeight() + Math.max(2, (int) Math.round(fontSize * 0.3));
            int padX = Math.max(8, (int) Math.round(fontSize * 0.9));
            int padY = Math.max(6, (int) Math.round(fontSize * 0.7));
            lineNow = line;
            padYNow = padY;
            fLineSpacing.setInt(null, line);
            fPadLeft.setInt(null, padX);
            fPadRight.setInt(null, padX);
            fPadTop.setInt(null, padY);
            fPadBottom.setInt(null, padY);
        } catch (ReflectiveOperationException | RuntimeException e) {
            System.out.println("[Knox] tooltip style off: " + e);
            return false;
        }
        style = bodyStyle;
        titleStyle = headStyle;
        size = KnoxFonts.clampSize(fontSize);
        maxWidth = (int) Math.round(fontSize * 22);
        title = itemName;
        titlePending = true;
        notes.clear();   // a pass without a layout leaves no notes from the last item
        badges.clear();
        active = true;
        return true;
    }

    @LuaMethod(name = "knoxTooltipEnd", global = true)
    public static void knoxTooltipEnd() {
        active = false;
        title = null;
        hideTitle = false;
        knownOnly = false;
        dropLabel = null;
        if (saved == null) return;
        try {
            fLineSpacing.setInt(null, saved[0]);
            fPadLeft.setInt(null, saved[1]);
            fPadRight.setInt(null, saved[2]);
            fPadTop.setInt(null, saved[3]);
            fPadBottom.setInt(null, saved[4]);
        } catch (ReflectiveOperationException | RuntimeException e) {
            // keep going, ObjectTooltip.checkFont resets them on font changes
        }
        saved = null;
    }

    /** Width (px) at which lines are wrapped, for this pass (Knox's header sets it). */
    @LuaMethod(name = "knoxTooltipWrapWidth", global = true)
    public static void knoxTooltipWrapWidth(double px) {
        maxWidth = Math.max(80, (int) Math.round(px));
    }

    @LuaMethod(name = "knoxTooltipHideTitle", global = true)
    public static void knoxTooltipHideTitle(boolean hide) {
        hideTitle = hide;
    }

    /**
     * A bag not looked into yet (Knox's search, KnoxSearch.lua): its tooltip shows
     * only the things the character knows - marked knoxK in their mod data - not
     * the whole contents (hovering a bag in a container gave away what was in it:
     * the author, 2026-10-18). Set by Lua for the tooltip being drawn; off at its end.
     */
    public static boolean knownOnly;

    @LuaMethod(name = "knoxTooltipKnownOnly", global = true)
    public static void knoxTooltipKnownOnly(boolean on) {
        knownOnly = on;
    }

    static boolean known(zombie.inventory.InventoryItem it) {
        try {
            if (!it.hasModData()) return false;
            Object v = it.getModData().rawget("knoxK");
            return Boolean.TRUE.equals(v);
        } catch (Throwable t) {
            return true;   // (can't tell: shown, as without the search)
        }
    }

    /** Line spacing of the current (or last) styled pass. */
    @LuaMethod(name = "knoxTooltipLine", global = true)
    public static int knoxTooltipLine() {
        return lineNow;
    }

    /** Top padding of the current (or last) styled pass. */
    @LuaMethod(name = "knoxTooltipPadY", global = true)
    public static int knoxTooltipPadY() {
        return padYNow;
    }

    static boolean near(double a, float b) {
        return Math.abs(a - b) < 0.02;
    }

    /** The game's colors to the palette: labels, plain values, good / bad. */
    public static float[] color(double r, double g, double b) {
        if (near(r, 1f) && near(g, 1f) && near(b, 0.8f)) return LABEL;
        if (near(r, 1f) && near(g, 1f) && near(b, 1f)) return VALUE;
        var good = Core.getInstance().getGoodHighlitedColor();
        if (near(r, good.getR()) && near(g, good.getG()) && near(b, good.getB())) return GOOD;
        var bad = Core.getInstance().getBadHighlitedColor();
        if (near(r, bad.getR()) && near(g, bad.getG()) && near(b, bad.getB())) return BAD;
        return new float[] {(float) r, (float) g, (float) b};
    }

    /** Width of text in Knox's font (the item name in the title style). */
    public static int width(String text) {
        if (text == null) return 0;
        // the game's name line is hidden (Knox's header shows the name): it must not set
        // the tooltip's width, a long name (books, tapes) stretched the whole tooltip
        if (hideTitle && title != null && text.equals(title)) return 0;
        String st = (title != null && text.equals(title)) ? titleStyle : style;
        AngelCodeFont f = KnoxFonts.font(st, size);
        if (f == null) return 0;
        // a signed number is drawn as a badge: count its frame too
        if (badges.contains(text)) return f.getWidth(text) + Math.max(4, size / 4) * 2;
        if (text.indexOf('\n') < 0) return f.getWidth(text);
        int w = 0;
        for (String line : text.split("\n", -1)) w = Math.max(w, f.getWidth(line));
        return w;
    }

    /** Text with line breaks so that no line is wider than maxWidth (at spaces). */
    public static String wrap(String text) {
        if (text == null) return null;
        AngelCodeFont f = KnoxFonts.font(style, size);
        if (f == null || width(text) <= maxWidth) return text;
        StringBuilder out = new StringBuilder();
        String[] paragraphs = text.replaceAll("\n(?![-*\u2022])", " ").split("\n", -1);
        for (int p = 0; p < paragraphs.length; p++) {
            if (p > 0) out.append('\n');
            StringBuilder line = new StringBuilder();
            for (String word : paragraphs[p].split(" ")) {
                if (word.isEmpty()) continue;
                String tryLine = line.length() == 0 ? word : line + " " + word;
                if (line.length() > 0 && f.getWidth(tryLine) > maxWidth) {
                    out.append(line).append('\n');
                    line.setLength(0);
                    line.append(word);
                } else {
                    line.setLength(0);
                    line.append(tryLine);
                }
            }
            out.append(line);
        }
        return out.toString();
    }

    /** The layout line being drawn: its value and the x where the value column starts. */
    public static String layoutValue;
    public static int layoutValueX;

    /** align: 0 left, 1 right, 2 centre. */
    public static void draw(ObjectTooltip ui, String text, double x, double y, double r, double g, double b,
                            double a, int align) {
        if (text == null || ui.isMeasureOnly()) return;
        // values of the layout's lines: at the start of their column, not right-aligned
        if (align == 1 && text == layoutValue) {
            align = 0;
            x = layoutValueX;
            // a signed number ("+5", "-32": the effect on hunger, stress...): a small
            // badge tinted in its color, like Knox's key frames and meters
            if (badges.contains(text)) {
                badge(ui, text, x, y, r, g, b, a);
                return;
            }
        }
        boolean isTitle = titlePending && title != null && text.equals(title);
        if (isTitle) titlePending = false;
        if (isTitle && hideTitle) return;
        AngelCodeFont f = KnoxFonts.font(isTitle ? titleStyle : style, size);
        if (f == null) return;
        float[] c = isTitle ? VALUE : color(r, g, b);
        double ax0 = x + ui.getAbsoluteX() + ui.getXScroll();
        double ay = y + ui.getAbsoluteY() + ui.getYScroll();
        // wrapped text: one line under the other, at the tooltip's line spacing
        String[] lines = text.indexOf('\n') < 0 ? new String[] {text} : text.split("\n", -1);
        for (String line : lines) {
            int w = f.getWidth(line);
            double ax = ax0;
            if (align == 1) ax -= w; else if (align == 2) ax -= w / 2.0;
            f.drawString((float) ax, (float) ay, line, c[0], c[1], c[2], (float) a);
            ay += lineNow;
        }
    }

    public static void bar(ObjectTooltip ui, int x, int y, int w, int h, float f, double r, double g, double b,
                           double a) {
        if (ui.isMeasureOnly()) return;
        f = Math.max(0f, Math.min(1f, f));
        // a Knox meter: thin frame, dark track, fill in the palette's good / warn / bad
        int bh = Math.max(6, h + 1);
        int by = y + (h - bh) / 2 - 1;
        float[] c = barColor(r, g, b);
        rect(ui, x, by, w, bh, FRAME, 1.0);
        rect(ui, x + 1, by + 1, w - 2, bh - 2, TRACK, 1.0);
        int done = (int) Math.floor((w - 2) * f);
        if (done > 0) rect(ui, x + 1, by + 1, done, bh - 2, c, a);
    }

    static final float[] FRAME = rgb(0x3c4141);
    static final float[] TILE_FRAME = rgb(0x5b615c);   // item tiles' frame (KnoxTheme tileFrame)
    static final float[] WARN = rgb(0xc9a24a);

    static void rect(ObjectTooltip ui, int x, int y, int w, int h, float[] c, double a) {
        ui.DrawTextureScaledColor(null, (double) x, (double) y, (double) w, (double) h,
                (double) c[0], (double) c[1], (double) c[2], a);
    }

    /**
     * Values drawn as badges in this pass: signed numbers ("+5", "-32") and any
     * value the game colored good or bad ("5 (+5)" next to what is worn).
     */
    public static final java.util.HashSet<String> badges = new java.util.HashSet<>();

    static boolean isBadge(ObjectTooltip.LayoutItem it) {
        if (it.value == null || it.progressFraction != -1.0f) return false;
        if (isSigned(it.value)) return true;
        float[] c = color(it.r1, it.g1, it.b1);
        return c == GOOD || c == BAD;
    }

    static boolean isSigned(String s) {
        return s.length() > 1 && (s.charAt(0) == '+' || s.charAt(0) == '-') && Character.isDigit(s.charAt(1));
    }

    static void badge(ObjectTooltip ui, String text, double x, double y, double r, double g, double b, double a) {
        AngelCodeFont f = KnoxFonts.font(style, size);
        if (f == null) return;
        float[] c = color(r, g, b);
        int padX = Math.max(4, size / 4);
        int w = f.getWidth(text) + padX * 2;
        int h = f.getLineHeight();
        int bx = (int) x, by = (int) y;
        ui.DrawTextureScaledColor(null, (double) bx, (double) by, (double) w, (double) h,
                (double) c[0], (double) c[1], (double) c[2], 0.16 * a);
        rect(ui, bx, by, w, 1, c, 0.7 * a);
        rect(ui, bx, by + h - 1, w, 1, c, 0.7 * a);
        rect(ui, bx, by, 1, h, c, 0.7 * a);
        rect(ui, bx + w - 1, by, 1, h, c, 0.7 * a);
        double ax = bx + padX + ui.getAbsoluteX() + ui.getXScroll();
        double ay = by + ui.getAbsoluteY() + ui.getYScroll();
        f.drawString((float) ax, (float) ay, text, c[0], c[1], c[2], (float) a);
    }

    /** The game's bar colors (green ... yellow ... red) to the palette. */
    static float[] barColor(double r, double g, double b) {
        if (g > r * 1.3) return GOOD;
        if (r > g * 1.3) return BAD;
        return WARN;
    }

    // Patches ---------------------------------------------------------------------

    @Patch(className = "zombie.ui.ObjectTooltip", methodName = "DrawText")
    public static class Text {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This ObjectTooltip self,
                                    @Patch.Argument(0) UIFont font, @Patch.Argument(1) String text,
                                    @Patch.Argument(2) double x, @Patch.Argument(3) double y,
                                    @Patch.Argument(4) double r, @Patch.Argument(5) double g,
                                    @Patch.Argument(6) double b, @Patch.Argument(7) double a) {
            if (!active) return false;
            draw(self, text, x, y, r, g, b, a, 0);
            return true;
        }
    }

    @Patch(className = "zombie.ui.ObjectTooltip", methodName = "DrawTextRight")
    public static class TextRight {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This ObjectTooltip self,
                                    @Patch.Argument(0) UIFont font, @Patch.Argument(1) String text,
                                    @Patch.Argument(2) double x, @Patch.Argument(3) double y,
                                    @Patch.Argument(4) double r, @Patch.Argument(5) double g,
                                    @Patch.Argument(6) double b, @Patch.Argument(7) double a) {
            if (!active) return false;
            draw(self, text, x, y, r, g, b, a, 1);
            return true;
        }
    }

    @Patch(className = "zombie.ui.ObjectTooltip", methodName = "DrawTextCentre")
    public static class TextCentre {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This ObjectTooltip self,
                                    @Patch.Argument(0) UIFont font, @Patch.Argument(1) String text,
                                    @Patch.Argument(2) double x, @Patch.Argument(3) double y,
                                    @Patch.Argument(4) double r, @Patch.Argument(5) double g,
                                    @Patch.Argument(6) double b, @Patch.Argument(7) double a) {
            if (!active) return false;
            draw(self, text, x, y, r, g, b, a, 2);
            return true;
        }
    }

    @Patch(className = "zombie.ui.ObjectTooltip", methodName = "DrawProgressBar")
    public static class ProgressBar {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This ObjectTooltip self,
                                    @Patch.Argument(0) int x, @Patch.Argument(1) int y,
                                    @Patch.Argument(2) int w, @Patch.Argument(3) int h,
                                    @Patch.Argument(4) float f, @Patch.Argument(5) double r,
                                    @Patch.Argument(6) double g, @Patch.Argument(7) double b,
                                    @Patch.Argument(8) double a) {
            if (!active) return false;
            bar(self, x, y, w, h, f, r, g, b, a);
            return true;
        }
    }

    @Patch(className = "zombie.ui.TextManager", methodName = "MeasureStringX")
    public static class Measure {
        @Patch.OnExit
        public static void exit(@Patch.Argument(0) UIFont font, @Patch.Argument(1) String text,
                                @Patch.Return(readOnly = false) int result) {
            if (active) result = width(text);
        }
    }

    private static String weightLabel;
    /** A line Knox draws itself (the item's description), left out of the game's part. */
    public static String dropLabel;

    @LuaMethod(name = "knoxTooltipDropLine", global = true)
    public static void knoxTooltipDropLine(String text) {
        dropLabel = text;
    }
    private static boolean wrapLogged;

    /** Before the game measures a line: long text wrapped at maxWidth. */
    public static void wrapItem(ObjectTooltip.LayoutItem item) {
        String l = wrap(item.label);
        String v = item.value == null ? null : wrap(item.value);
        if (!wrapLogged && ((l != null && l != item.label) || (v != null && v != item.value))) {
            wrapLogged = true;
            System.out.println("[Knox] tooltip lines wrapped at " + maxWidth + " px");
        }
        item.label = l;
        item.value = v;
        if (isBadge(item)) badges.add(item.value);
    }

    /** Prose lines (notes such as "less effective one-handed") taken out of the game's part, for Knox's description block: "r;g;b;text" each. */
    public static final java.util.ArrayList<String> notes = new java.util.ArrayList<>();

    @LuaMethod(name = "knoxTooltipNotes", global = true)
    public static String knoxTooltipNotes() {
        return String.join("\n", notes);
    }

    static boolean isNote(ObjectTooltip.LayoutItem it) {
        if (it.label == null || it.hasValue || it.progressFraction != -1.0f) return false;
        String l = it.label.trim();
        if (l.endsWith(":")) return false;
        return l.split("\\s+").length >= 4;
    }

    /** Lines Knox's header already shows (the weight) are left out; prose notes move to Knox's description block. */
    public static void dropDuplicates(ObjectTooltip.Layout layout) {
        if (weightLabel == null) weightLabel = Translator.getText("Tooltip_item_Weight", new Object[0]) + ":";
        notes.clear();
        layout.items.removeIf(it -> {
            if (it.label != null && (it.label.equals(weightLabel) || it.label.equals(dropLabel))) return true;
            // the durability component's lines: untranslated English ("Material: Metal_Light")
            if (it.label != null && (it.label.equals("Material:") || it.label.equals("Hit Points:"))) return true;
            if (isNote(it)) {
                float[] c = color(it.r0, it.g0, it.b0);
                notes.add(c[0] + ";" + c[1] + ";" + c[2] + ";" + it.label.replace('\n', ' '));
                return true;
            }
            return false;
        });
        // the value column starts after the longest label of any line, also of lines without
        // a value ("Nutrition:"), which the game leaves out of that width
        int labelW = 0;
        for (ObjectTooltip.LayoutItem it : layout.items) {
            if (it.label != null && it.label.indexOf('\n') < 0) labelW = Math.max(labelW, width(it.label));
        }
        layout.minLabelWidth = Math.max(layout.minLabelWidth, labelW);
    }

    @Patch(className = "zombie.ui.ObjectTooltip$LayoutItem", methodName = "calcSizes")
    public static class WrapLines {
        @Patch.OnEnter
        public static void enter(@Patch.This ObjectTooltip.LayoutItem self) {
            if (active) wrapItem(self);
        }
    }

    @Patch(className = "zombie.ui.ObjectTooltip$Layout", methodName = "render")
    public static class DropDuplicates {
        @Patch.OnEnter
        public static void enter(@Patch.This ObjectTooltip.Layout self) {
            if (active && hideTitle) dropDuplicates(self);
        }
    }

    @Patch(className = "zombie.ui.ObjectTooltip$LayoutItem", methodName = "render")
    public static class ValueColumn {
        @Patch.OnEnter
        public static void enter(@Patch.This ObjectTooltip.LayoutItem self, @Patch.Argument(0) int x,
                                 @Patch.Argument(1) int y, @Patch.Argument(2) int mid) {
            if (!active) return;
            layoutValue = self.value;
            layoutValueX = x + mid;
        }

        @Patch.OnExit
        public static void exit() {
            layoutValue = null;
        }
    }

    /**
     * A container's tooltip: the game's lines, then its contents as icons, each
     * in a small framed cell with gaps between them, in rows (the game drew
     * them edge to edge in one row). One icon per item name, as the game does.
     */
    public static void containerTooltip(zombie.inventory.types.InventoryContainer bag, ObjectTooltip ui) {
        ui.render();
        bag.DoTooltipEmbedded(ui, null, 0);
        int y = ui.getHeight().intValue() - ui.padBottom;
        java.util.ArrayList<zombie.inventory.InventoryItem> all = bag.getItemContainer().getItems();
        java.util.ArrayList<zombie.inventory.InventoryItem> items = all;
        if (knownOnly) {
            items = new java.util.ArrayList<>();
            for (zombie.inventory.InventoryItem it : all) if (known(it)) items.add(it);
        }
        if (!items.isEmpty()) {
            AngelCodeFont f = KnoxFonts.font(style, size);
            int fontH = f == null ? lineNow : f.getLineHeight();
            int icon = Math.max(16, fontH);
            int pad = 4, gap = 4, frame = 2;
            int cell = icon + pad * 2;
            int left = ui.padLeft;
            int right = (int) Math.max(ui.getWidth(), 160) - ui.padRight;
            int x = left;
            // 8 px under the last line's text, like the gaps elsewhere (its line spacing doesn't count)
            y += 8 - Math.max(0, lineNow - fontH);
            java.util.HashSet<String> names = new java.util.HashSet<>();
            boolean any = false;
            for (int i = items.size() - 1; i >= 0; --i) {
                zombie.inventory.InventoryItem it = items.get(i);
                if (it.getName() != null) {
                    if (names.contains(it.getName())) continue;
                    names.add(it.getName());
                }
                if (any && x + cell > right) {   // next row
                    x = left;
                    y += cell + gap;
                }
                if (!ui.isMeasureOnly()) {
                    rect(ui, x, y, cell, cell, TILE_FRAME, 1.0);
                    rect(ui, x + frame, y + frame, cell - frame * 2, cell - frame * 2, TRACK, 1.0);
                }
                ui.DrawTextureScaledAspect(it.getTex(), x + pad, y + pad, icon, icon, 1.0, 1.0, 1.0, 1.0);
                x += cell + gap;
                any = true;
            }
            y += cell;
            // Knox's layout cuts one line's spacing under the last line: give it back
            y += Math.max(0, lineNow - fontH);
        }
        ui.setHeight(y + ui.padBottom);
    }

    @Patch(className = "zombie.inventory.types.InventoryContainer", methodName = "DoTooltip")
    public static class ContainerIcons {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This zombie.inventory.types.InventoryContainer self,
                                    @Patch.AllArguments Object[] args) {
            if (!active || !hideTitle || args.length != 1 || !(args[0] instanceof ObjectTooltip)) return false;
            containerTooltip(self, (ObjectTooltip) args[0]);
            return true;
        }
    }
}