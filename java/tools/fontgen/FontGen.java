import java.awt.Color;
import java.awt.Font;
import java.awt.FontMetrics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.font.FontRenderContext;
import java.awt.font.GlyphVector;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import javax.imageio.ImageIO;

/**
 * Bitmap font atlases in the AngelCode BMFont text format Project Zomboid
 * reads (zombie.core.fonts.AngelCodeFont): <name>.fnt + <name>_0.png, white
 * glyphs with antialiased alpha, one atlas per pixel size.
 *
 *   java FontGen.java <font.ttf> <outDir> <name> <minSize> <maxSize> <tracking em>
 *
 * writes <outDir>/<name>_<size>.fnt and <name>_<size>_0.png for each size.
 * Tracking (letter spacing, in em) is baked into the advance, for the
 * uppercase condensed labels of the Knox UI.
 */
public class FontGen {

    static String charset() {
        StringBuilder sb = new StringBuilder();
        for (int c = 32; c <= 126; c++) sb.append((char) c);
        for (int c = 160; c <= 255; c++) sb.append((char) c);
        // Latin Extended-A: Polish, Czech, Slovak, Turkish, Hungarian, Croatian,
        // Lithuanian, Latvian...; and the Romanian comma letters
        for (int c = 0x100; c <= 0x17F; c++) sb.append((char) c);
        for (int c = 0x218; c <= 0x21B; c++) sb.append((char) c);
        for (int c = 0x410; c <= 0x44F; c++) sb.append((char) c);          // А..я
        sb.append("ЁёЄєІіЇїҐґЎў");
        sb.append("—–«»„“”‘’‚‹›…·•×№°±≈≤≥←→↑↓€");
        return sb.toString();
    }

    public static void main(String[] args) throws Exception {
        File ttf = new File(args[0]);
        File outDir = new File(args[1]);
        String name = args[2];
        int minSize = Integer.parseInt(args[3]);
        int maxSize = Integer.parseInt(args[4]);
        float tracking = Float.parseFloat(args[5]);
        outDir.mkdirs();
        Font base = Font.createFont(Font.TRUETYPE_FONT, ttf);
        String chars = charset();
        for (int size = minSize; size <= maxSize; size++) {
            write(base.deriveFont((float) size), chars, outDir, name + "_" + size, size, tracking);
        }
    }

    static final class Glyph {
        int id, x, y, w, h, xoff, yoff, adv;
        BufferedImage img;
    }

    static void write(Font font, String chars, File outDir, String fileName, int size, float tracking) throws Exception {
        BufferedImage scratch = new BufferedImage(1, 1, BufferedImage.TYPE_INT_ARGB);
        Graphics2D sg = scratch.createGraphics();
        hints(sg);
        sg.setFont(font);
        FontMetrics fm = sg.getFontMetrics();
        FontRenderContext frc = sg.getFontRenderContext();
        int ascent = fm.getAscent();
        int lineHeight = fm.getAscent() + fm.getDescent();
        int track = Math.round(tracking * size);
        int pad = 1;

        List<Glyph> glyphs = new ArrayList<>();
        for (int i = 0; i < chars.length(); i++) {
            char c = chars.charAt(i);
            if (!font.canDisplay(c)) continue;
            GlyphVector gv = font.createGlyphVector(frc, String.valueOf(c));
            Rectangle2D b = gv.getPixelBounds(frc, 0, 0);
            Glyph g = new Glyph();
            g.id = c;
            g.adv = Math.round((float) gv.getGlyphMetrics(0).getAdvance()) + track;
            if (c == ' ' || b.getWidth() <= 0 || b.getHeight() <= 0) {
                g.w = 0; g.h = 0; g.xoff = 0; g.yoff = 0;
            } else {
                g.w = (int) Math.ceil(b.getWidth()) + pad * 2;
                g.h = (int) Math.ceil(b.getHeight()) + pad * 2;
                g.xoff = (int) Math.floor(b.getX()) - pad;
                g.yoff = ascent + (int) Math.floor(b.getY()) - pad;
                g.img = new BufferedImage(g.w, g.h, BufferedImage.TYPE_INT_ARGB);
                Graphics2D gg = g.img.createGraphics();
                hints(gg);
                gg.setFont(font);
                gg.setColor(Color.WHITE);
                gg.drawString(String.valueOf(c), -g.xoff, ascent - g.yoff);
                gg.dispose();
            }
            glyphs.add(g);
        }
        sg.dispose();

        // pack in rows
        int atlasW = size <= 16 ? 256 : (size <= 28 ? 512 : 1024);
        int x = 1, y = 1, rowH = 0;
        for (Glyph g : glyphs) {
            if (g.img == null) continue;
            if (x + g.w + 1 > atlasW) { x = 1; y += rowH + 1; rowH = 0; }
            g.x = x; g.y = y;
            x += g.w + 1;
            rowH = Math.max(rowH, g.h);
        }
        int atlasH = 16;
        while (atlasH < y + rowH + 1) atlasH *= 2;

        BufferedImage atlas = new BufferedImage(atlasW, atlasH, BufferedImage.TYPE_INT_ARGB);
        Graphics2D ag = atlas.createGraphics();
        for (Glyph g : glyphs) {
            if (g.img != null) ag.drawImage(g.img, g.x, g.y, null);
        }
        ag.dispose();
        String png = fileName + "_0.png";
        ImageIO.write(atlas, "png", new File(outDir, png));

        try (PrintWriter out = new PrintWriter(new File(outDir, fileName + ".fnt"), StandardCharsets.UTF_8)) {
            out.printf("info face=\"%s\" size=%d bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1%n",
                font.getFontName(), size);
            out.printf("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0%n", lineHeight, ascent, atlasW, atlasH);
            out.printf("page id=0 file=\"%s\"%n", png);
            out.printf("chars count=%d%n", glyphs.size());
            for (Glyph g : glyphs) {
                out.printf("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15%n",
                    g.id, g.x, g.y, g.w, g.h, g.xoff, g.yoff, g.adv);
            }
        }
    }

    static void hints(Graphics2D g) {
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_ON);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
    }
}
