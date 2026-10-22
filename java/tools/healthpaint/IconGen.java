import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.Ellipse2D;
import java.awt.geom.GeneralPath;
import java.awt.geom.Path2D;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;

import javax.imageio.ImageIO;

/**
 * The health tab's wound icons (Knox Inventory, KnoxHealthWounds): a base per kind of
 * wound and an overlay per state of its treatment, drawn on top of each other - the
 * wound's square badge changes with its state (author, 2026-10-19: "every wound its
 * own set of icons, changing with its state"). Drawn here at 4x and scaled down;
 * squared shapes where they can be (the Knox look: squares, not circles).
 *   java IconGen.java <outDir>
 * Writes w_<name>.png, 64 x 64, transparent.
 */
public class IconGen {
    static final int S = 64, K = 4;   // size, supersampling
    static final double U = S * K / 24.0;   // drawn in a 24-unit square

    static final Color BLOOD = c(0xc8443a), DARK_BLOOD = c(0x6e1f1a), SKIN = c(0xd9b08c);
    static final Color SCRATCH = c(0xebc747), CUT = c(0xeb8026), DEEP = c(0xc7337f), BITE = c(0x9452cc);
    static final Color GLASS = c(0x4db8d1), BULLET = c(0x6b8cbf), BURN = c(0xb35220), FLAME2 = c(0xf0b040);
    static final Color BONE = c(0xe8e0c8), CRACK = c(0x3a2a22), GERM = c(0x9eb82e), GERM2 = c(0x5e7016);
    static final Color BAND = c(0xeeeae0), BAND_SHADE = c(0xbdb7a8), DIRTY = c(0x8a6a3e), DIRTY2 = c(0x5e4628);
    static final Color STITCH = c(0xe6e2d6), WOOD = c(0xa67a48), WOOD2 = c(0x6e4e2a), WATER = c(0x7fc6e0);
    static final Color GOOD = c(0x9fb36a), METAL = c(0xc9ccd0), LEAF = c(0x6aa84a), LEAF2 = c(0x3e6a2a), SAND = c(0xd4c38a);

    static Color c(int rgb) { return new Color(rgb); }

    interface Draw { void on(Graphics2D g); }

    public static void main(String[] a) throws Exception {
        File out = new File(a[0]);
        out.mkdirs();
        // bases
        icon(out, "bleeding", g -> {
            fill(g, drop(12, 1.5f, 6.4f, 21f), BLOOD);
            fill(g, drop(9.8f, 10, 1.8f, 16f), new Color(255, 255, 255, 70));
        });
        icon(out, "scratch", g -> {
            for (int i = 0; i < 3; i++) {
                float o = i * 4.2f;
                stroke(g, line(5 + o, 18, 11 + o, 5), SCRATCH, 2.4f);
                stroke(g, line(5.6f + o, 17, 10.5f + o, 6.5f), BLOOD, 0.9f);
            }
        });
        icon(out, "cut", g -> {
            stroke(g, line(4.5f, 19, 19.5f, 5), CUT, 3.2f);
            stroke(g, line(5.5f, 18, 18.5f, 6), DARK_BLOOD, 1.1f);
            fill(g, drop(17.5f, 13, 2.2f, 17.5f), BLOOD);
            fill(g, drop(13, 16, 1.6f, 19.5f), BLOOD);
        });
        icon(out, "deepwound", g -> {
            GeneralPath p = new GeneralPath();
            p.moveTo(3.5 * U, 12 * U);
            p.quadTo(12 * U, 3.5 * U, 20.5 * U, 12 * U);
            p.quadTo(12 * U, 20.5 * U, 3.5 * U, 12 * U);
            p.closePath();
            fill(g, p, DEEP);
            GeneralPath q = new GeneralPath();
            q.moveTo(5.5 * U, 12 * U);
            q.quadTo(12 * U, 7.5 * U, 18.5 * U, 12 * U);
            q.quadTo(12 * U, 16.5 * U, 5.5 * U, 12 * U);
            q.closePath();
            fill(g, q, DARK_BLOOD);
        });
        icon(out, "bite", g -> {
            for (int row = 0; row < 2; row++) {
                for (int k = 0; k < 5; k++) {
                    double ang = Math.PI * (0.15 + 0.7 * k / 4.0);
                    float x = 12 + (float) Math.cos(ang) * 7.5f * (row == 0 ? -1 : 1);
                    float y = 12 + (float) Math.sin(ang) * 6f * (row == 0 ? -1 : 1);
                    fill(g, rect(x - 1.3f, y - 1.3f, 2.6f, 2.6f, 0.6f), BITE);
                }
            }
            fill(g, rect(10.8f, 10.8f, 2.4f, 2.4f, 0.5f), BLOOD);
        });
        icon(out, "glass", g -> {
            GeneralPath p = new GeneralPath();
            p.moveTo(8 * U, 3 * U); p.lineTo(18 * U, 9 * U); p.lineTo(13 * U, 21 * U); p.lineTo(6 * U, 13 * U); p.closePath();
            fill(g, p, GLASS);
            stroke(g, line(8, 3, 12.5f, 20), new Color(255, 255, 255, 140), 1f);
            stroke(g, line(9, 8, 15.5f, 10), new Color(255, 255, 255, 90), 0.8f);
        });
        icon(out, "bullet", g -> {
            GeneralPath p = new GeneralPath();
            p.moveTo(9 * U, 20 * U); p.lineTo(9 * U, 10 * U);
            p.quadTo(9 * U, 4 * U, 12 * U, 3 * U);
            p.quadTo(15 * U, 4 * U, 15 * U, 10 * U);
            p.lineTo(15 * U, 20 * U); p.closePath();
            fill(g, p, BULLET);
            fill(g, rect(8.4f, 14, 7.2f, 6.5f, 0.6f), c(0xb08a3e));
            stroke(g, line(10.3f, 6.5f, 10.3f, 13), new Color(255, 255, 255, 110), 0.9f);
        });
        icon(out, "burn", g -> {
            GeneralPath p = new GeneralPath();
            p.moveTo(12 * U, 2.5 * U);
            p.curveTo(17 * U, 8 * U, 19.5 * U, 12 * U, 18 * U, 16 * U);
            p.curveTo(16.5 * U, 20.5 * U, 7.5 * U, 20.5 * U, 6 * U, 16 * U);
            p.curveTo(4.8 * U, 12 * U, 8 * U, 10 * U, 9 * U, 6.5 * U);
            p.curveTo(10.5 * U, 9 * U, 11 * U, 10 * U, 12 * U, 2.5 * U);
            p.closePath();
            fill(g, p, BURN);
            GeneralPath q = new GeneralPath();
            q.moveTo(12 * U, 10 * U);
            q.curveTo(15 * U, 13 * U, 15.5 * U, 16 * U, 14 * U, 17.5 * U);
            q.curveTo(12.5 * U, 19 * U, 9.5 * U, 18.5 * U, 9.3 * U, 16 * U);
            q.curveTo(9.2 * U, 14 * U, 11.5 * U, 13 * U, 12 * U, 10 * U);
            q.closePath();
            fill(g, q, FLAME2);
        });
        icon(out, "fracture", g -> {
            fill(g, bone(), BONE);
            GeneralPath cr = new GeneralPath();
            cr.moveTo(9.5 * U, 14.5 * U); cr.lineTo(11.2 * U, 12.6 * U); cr.lineTo(11.6 * U, 14.4 * U); cr.lineTo(13.4 * U, 12.4 * U); cr.lineTo(14.6 * U, 10.5 * U);
            stroke(g, cr, CRACK, 1.6f);
        });
        icon(out, "infected", g -> {
            for (int k = 0; k < 8; k++) {
                double ang = Math.PI * 2 * k / 8;
                float x = 12 + (float) Math.cos(ang) * 8, y = 12 + (float) Math.sin(ang) * 8;
                stroke(g, line(12 + (float) Math.cos(ang) * 4, 12 + (float) Math.sin(ang) * 4, x, y), GERM, 1.6f);
                fill(g, rect(x - 1.2f, y - 1.2f, 2.4f, 2.4f, 0.5f), GERM);
            }
            fill(g, rect(6.8f, 6.8f, 10.4f, 10.4f, 2.5f), GERM);
            fill(g, rect(9, 9.5f, 2.4f, 2.4f, 0.6f), GERM2);
            fill(g, rect(13, 12.5f, 2f, 2f, 0.6f), GERM2);
        });
        icon(out, "destroyed", g -> {
            fill(g, rect(4, 4, 16, 16, 1.5f), c(0x1a1a1c));
            stroke(g, line(7, 7, 17, 17), BLOOD, 2.6f);
            stroke(g, line(17, 7, 7, 17), BLOOD, 2.6f);
        });
        icon(out, "other", g -> {
            fill(g, rect(10, 4.5f, 4, 15, 0.8f), SAND);
            fill(g, rect(4.5f, 10, 15, 4, 0.8f), SAND);
        });
        // overlays (the treatment's state)
        icon(out, "o_band", g -> band(g, BAND, BAND_SHADE));
        icon(out, "o_dirty", g -> {
            band(g, DIRTY, DIRTY2);
            fill(g, drop(9, 11, 1.4f, 15), DARK_BLOOD);
            fill(g, drop(15, 11.5f, 1.2f, 14.6f), DARK_BLOOD);
        });
        icon(out, "o_stitch", g -> {
            for (int k = 0; k < 4; k++) {
                float x = 7 + k * 3.4f;
                stroke(g, line(x - 1.4f, 9.5f, x + 1.4f, 14.5f), STITCH, 1.5f);
                stroke(g, line(x + 1.4f, 9.5f, x - 1.4f, 14.5f), STITCH, 1.5f);
            }
        });
        icon(out, "o_splint", g -> {
            for (int k = -1; k <= 1; k += 2) {
                GeneralPath p = new GeneralPath();
                double off = k * 3.2;
                p.moveTo((4 + off) * U, (8 - off) * U);
                p.lineTo((7 + off) * U, (5 - off) * U);
                p.lineTo((20 + off) * U, (18 - off) * U);
                p.lineTo((17 + off) * U, (21 - off) * U);
                p.closePath();
                fill(g, p, WOOD);
                stroke(g, p, WOOD2, 0.8f);
            }
            fill(g, rect(9.5f, 11, 5, 2.2f, 0.4f), BAND);
        });
        icon(out, "o_clean", g -> {
            fill(g, rect(13, 13, 10, 10, 1.6f), c(0x121414));
            fill(g, drop(18, 14, 3.2f, 21.5f), WATER);
        });
        icon(out, "o_removed", g -> {
            fill(g, rect(13, 13, 10, 10, 1.6f), c(0x121414));
            stroke(g, line(14.5f, 21.5f, 21.5f, 14.5f), METAL, 1.6f);
            stroke(g, line(16.5f, 22, 22, 16.5f), METAL, 1.6f);
        });
        icon(out, "o_poultice", g -> {
            fill(g, rect(13, 13, 10, 10, 1.6f), c(0x121414));
            GeneralPath leaf = new GeneralPath();
            leaf.moveTo(14.5 * U, 21.5 * U);
            leaf.quadTo(14.5 * U, 14.5 * U, 21.5 * U, 14.5 * U);
            leaf.quadTo(21.5 * U, 21.5 * U, 14.5 * U, 21.5 * U);
            leaf.closePath();
            fill(g, leaf, LEAF);
            stroke(g, line(15, 21, 20, 16), LEAF2, 0.8f);
        });
        icon(out, "o_heal", g -> {
            BasicStroke dash = new BasicStroke((float) (1.8 * U), BasicStroke.CAP_SQUARE, BasicStroke.JOIN_MITER, 10,
                new float[] {(float) (3 * U), (float) (2.2 * U)}, 0);
            g.setStroke(dash);
            g.setColor(GOOD);
            g.draw(rect(2.5f, 2.5f, 19, 19, 1.2f));
        });
        icon(out, "healed", g -> {
            GeneralPath p = new GeneralPath();
            p.moveTo(5.5 * U, 12.5 * U); p.lineTo(10 * U, 17 * U); p.lineTo(18.5 * U, 7 * U);
            stroke(g, p, GOOD, 3f);
        });
        System.out.println("icons written to " + out);
    }

    static void band(Graphics2D g, Color c, Color shade) {
        fill(g, rect(3, 9.3f, 18, 5.4f, 0.8f), c);
        for (int k = 0; k < 4; k++) stroke(g, line(6.5f + k * 3.6f, 9.3f, 6.5f + k * 3.6f, 14.7f), shade, 0.7f);
    }

    static Path2D bone() {
        Path2D p = new Path2D.Double();
        // a shaft from bottom left to top right with two knobs at each end
        p.append(rect(7.5f, 10.2f, 9f, 3.6f, 0.5f), false);
        Path2D shape = new Path2D.Double();
        shape.append(p, false);
        java.awt.geom.Area a = new java.awt.geom.Area(rect(7f, 10.2f, 10f, 3.6f, 0.5f));
        a.add(new java.awt.geom.Area(new Ellipse2D.Double(3.2 * U, 7.8 * U, 4.6 * U, 4.6 * U)));
        a.add(new java.awt.geom.Area(new Ellipse2D.Double(3.2 * U, 11.6 * U, 4.6 * U, 4.6 * U)));
        a.add(new java.awt.geom.Area(new Ellipse2D.Double(16.2 * U, 7.8 * U, 4.6 * U, 4.6 * U)));
        a.add(new java.awt.geom.Area(new Ellipse2D.Double(16.2 * U, 11.6 * U, 4.6 * U, 4.6 * U)));
        java.awt.geom.AffineTransform t = java.awt.geom.AffineTransform.getRotateInstance(-Math.PI / 4, 12 * U, 12 * U);
        return new Path2D.Double(a.createTransformedArea(t));
    }

    static GeneralPath drop(float cx, float top, float r, float bottom) {
        GeneralPath p = new GeneralPath();
        float cy = bottom - r;
        p.moveTo(cx * U, top * U);
        p.curveTo((cx + r * 0.3) * U, (top + (cy - top) * 0.45) * U, (cx + r) * U, (cy - r * 0.55) * U, (cx + r) * U, cy * U);
        p.curveTo((cx + r) * U, (cy + r * 0.56) * U, (cx + r * 0.56) * U, bottom * U, cx * U, bottom * U);
        p.curveTo((cx - r * 0.56) * U, bottom * U, (cx - r) * U, (cy + r * 0.56) * U, (cx - r) * U, cy * U);
        p.curveTo((cx - r) * U, (cy - r * 0.55) * U, (cx - r * 0.3) * U, (top + (cy - top) * 0.45) * U, cx * U, top * U);
        p.closePath();
        return p;
    }

    static RoundRectangle2D rect(float x, float y, float w, float h, float r) {
        return new RoundRectangle2D.Double(x * U, y * U, w * U, h * U, r * 2 * U, r * 2 * U);
    }

    static GeneralPath line(float x0, float y0, float x1, float y1) {
        GeneralPath p = new GeneralPath();
        p.moveTo(x0 * U, y0 * U);
        p.lineTo(x1 * U, y1 * U);
        return p;
    }

    static void fill(Graphics2D g, java.awt.Shape s, Color c) {
        g.setColor(c);
        g.fill(s);
    }

    static void stroke(Graphics2D g, java.awt.Shape s, Color c, float w) {
        g.setColor(c);
        g.setStroke(new BasicStroke((float) (w * U), BasicStroke.CAP_SQUARE, BasicStroke.JOIN_MITER));
        g.draw(s);
    }

    static void icon(File dir, String name, Draw d) throws Exception {
        BufferedImage big = new BufferedImage(S * K, S * K, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = big.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
        d.on(g);
        g.dispose();
        BufferedImage img = new BufferedImage(S, S, BufferedImage.TYPE_INT_ARGB);
        // (a box filter down: every 4x4 block averaged, alpha-weighted)
        for (int y = 0; y < S; y++) {
            for (int x = 0; x < S; x++) {
                long ra = 0, ga = 0, ba = 0, aa = 0;
                for (int j = 0; j < K; j++) {
                    for (int i = 0; i < K; i++) {
                        int p = big.getRGB(x * K + i, y * K + j);
                        int al = (p >>> 24) & 255;
                        aa += al;
                        ra += (long) ((p >> 16) & 255) * al;
                        ga += (long) ((p >> 8) & 255) * al;
                        ba += (long) (p & 255) * al;
                    }
                }
                int al = (int) (aa / (K * K));
                int r = aa > 0 ? (int) (ra / aa) : 0, gg = aa > 0 ? (int) (ga / aa) : 0, b = aa > 0 ? (int) (ba / aa) : 0;
                img.setRGB(x, y, (al << 24) | (r << 16) | (gg << 8) | b);
            }
        }
        ImageIO.write(img, "png", new File(dir, "w_" + name + ".png"));
    }
}
