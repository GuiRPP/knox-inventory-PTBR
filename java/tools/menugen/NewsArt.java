import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.GradientPaint;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.Ellipse2D;
import java.awt.geom.Line2D;
import java.awt.geom.Path2D;
import java.awt.geom.Rectangle2D;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.util.Random;
import javax.imageio.ImageIO;

/**
 * Pictures of the news posts (media/knox/news): for every post a card
 * background (912 x 204, dark on its left, where the card's text lies) and
 * the picture of the opened post (900 x 1100).
 *
 *   java NewsArt.java <mod's media folder> [a screenshot of the main menu, 16:9] [one of the inventory] [name|shot|x|y|w|h[|banner or art] ...]
 *
 * menu_*     cut from the screenshot (skipped without one)
 * tvradio_*  drawn: a TV set and a radio
 * liquids_*  drawn: two tanks, liquid going from one to the other
 * stage1_*   cut from the inventory's screenshot (skipped without one)
 */
public class NewsArt {
    static final int BW = 912, BH = 204, AW = 900, AH = 1100;
    static final Color BACK = new Color(18, 20, 20), CELL = new Color(26, 29, 29), FRAME = new Color(58, 62, 60);
    static final Color SAND = new Color(212, 194, 138), INK = new Color(10, 11, 11), EMBER = new Color(226, 112, 44);
    static final Color GOOD = new Color(126, 170, 96), WATER = new Color(74, 132, 176), DIM = new Color(120, 122, 116);
    static File out;

    public static void main(String[] a) throws IOException {
        out = new File(a[0], "knox/news");
        out.mkdirs();
        if (a.length > 1) menu(ImageIO.read(new File(a[1])));
        drawn("tvradio", NewsArt::tvRadio);
        drawn("liquids", NewsArt::liquids);
        if (a.length > 2) stage1(ImageIO.read(new File(a[2])));
        // pictures inside a post: "name|screenshot|x|y|w|h" (in the pixels of a 2000 wide shot), cut as they are
        for (int i = 3; i < a.length; i++) {
            String[] p = a[i].split("\\|");
            BufferedImage shot = ImageIO.read(new File(p[1]));
            double k = shot.getWidth() / 2000.0;
            int w = Integer.parseInt(p[4]), h = Integer.parseInt(p[5]);
            BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = pen(img);
            int x = Integer.parseInt(p[2]), y = Integer.parseInt(p[3]);
            g.drawImage(shot, 0, 0, w, h, (int) (x * k), (int) (y * k), (int) ((x + w) * k), (int) ((y + h) * k), null);
            g.dispose();
            if (p.length > 6) finish(img, p[6].equals("banner"), 81);   // "banner" / "art": grain, vignette, a banner's dark left
            save(img, p[0] + ".png");
        }
    }

    interface Scene { void draw(Graphics2D g, double x, double y, double w, double h, boolean banner); }

    static Graphics2D pen(BufferedImage img) {
        Graphics2D g = img.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        return g;
    }

    /** Film grain, a vignette and, for a card, the dark left side. */
    static void finish(BufferedImage img, boolean banner, long seed) {
        Random rnd = new Random(seed);
        int w = img.getWidth(), h = img.getHeight();
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int c = img.getRGB(x, y);
                double k = 0.95 + 0.10 * rnd.nextDouble();
                double dx = (x - w * 0.5) / (w * 0.5), dy = (y - h * 0.5) / (h * 0.5);
                k *= 1 - 0.30 * Math.min(1, dx * dx * dx * dx + dy * dy * dy * dy);
                if (banner) {
                    double t = Math.max(0, Math.min(1, (x / (double) w - 0.28) / 0.44));
                    k *= 0.26 + 0.74 * t * t * (3 - 2 * t);
                }
                int r = (int) Math.min(255, ((c >> 16) & 255) * k), g = (int) Math.min(255, ((c >> 8) & 255) * k),
                    b = (int) Math.min(255, (c & 255) * k);
                img.setRGB(x, y, 0xFF000000 | r << 16 | g << 8 | b);
            }
        }
    }

    static void save(BufferedImage img, String name) throws IOException {
        ImageIO.write(img, "png", new File(out, name));
        System.out.println(name + " " + img.getWidth() + "x" + img.getHeight());
    }

    static void drawn(String name, Scene s) throws IOException {
        for (int i = 0; i < 2; i++) {
            boolean banner = i == 0;
            int w = banner ? BW : AW, h = banner ? BH : AH;
            BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = pen(img);
            g.setPaint(new GradientPaint(0, 0, new Color(24, 27, 27), 0, h, new Color(12, 13, 13)));
            g.fillRect(0, 0, w, h);
            // a faint grid, as behind the inventory
            g.setColor(new Color(255, 255, 255, 7));
            int step = banner ? 34 : 60;
            for (int x = step; x < w; x += step) g.drawLine(x, 0, x, h);
            for (int y = step; y < h; y += step) g.drawLine(0, y, w, y);
            if (banner) s.draw(g, w * 0.50, h * 0.08, w * 0.47, h * 0.84, true);
            else s.draw(g, w * 0.10, h * 0.10, w * 0.80, h * 0.80, false);
            g.dispose();
            finish(img, banner, name.hashCode());
            save(img, name + (banner ? "_banner.png" : "_art.png"));
        }
    }

    /** The two pictures of the main menu's post, cut from a screenshot of it. */
    static void menu(BufferedImage shot) throws IOException {
        double k = shot.getWidth() / 2000.0;
        cut(shot, k, 800, 95, 746, 912, AW, AH, false, "menu_art.png");
        cut(shot, k, 500, 505, 1000, 224, BW, BH, true, "menu_banner.png");
    }

    static void stage1(BufferedImage shot) throws IOException {
        double k = shot.getWidth() / 2000.0;
        cut(shot, k, 20, 0, 920, 1125, AW, AH, false, "stage1_art.png");
        cut(shot, k, 700, 130, 1000, 224, BW, BH, true, "stage1_banner.png");
    }

    static void cut(BufferedImage shot, double k, int x, int y, int w, int h, int ow, int oh, boolean banner, String name)
            throws IOException {
        BufferedImage img = new BufferedImage(ow, oh, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = pen(img);
        g.drawImage(shot, 0, 0, ow, oh, (int) (x * k), (int) (y * k), (int) ((x + w) * k), (int) ((y + h) * k), null);
        g.dispose();
        finish(img, banner, 7);
        save(img, name);
    }

    // ------------------------------------------------------------------ scenes

    static void box(Graphics2D g, double x, double y, double w, double h, double arc, Color fill, Color line, double lw) {
        RoundRectangle2D r = new RoundRectangle2D.Double(x, y, w, h, arc, arc);
        if (fill != null) { g.setColor(fill); g.fill(r); }
        if (line != null) { g.setColor(line); g.setStroke(new BasicStroke((float) lw)); g.draw(r); }
    }

    static void knob(Graphics2D g, double cx, double cy, double r, double deg) {
        g.setColor(new Color(40, 43, 42));
        g.fill(new Ellipse2D.Double(cx - r, cy - r, r * 2, r * 2));
        g.setColor(FRAME);
        g.setStroke(new BasicStroke((float) Math.max(1.5, r * 0.12)));
        g.draw(new Ellipse2D.Double(cx - r, cy - r, r * 2, r * 2));
        g.setColor(SAND);
        double a = Math.toRadians(deg);
        g.draw(new Line2D.Double(cx + Math.cos(a) * r * 0.25, cy + Math.sin(a) * r * 0.25, cx + Math.cos(a) * r * 0.85,
            cy + Math.sin(a) * r * 0.85));
    }

    static void tv(Graphics2D g, double x, double y, double w, double h) {
        double u = Math.min(w, h) / 100;
        box(g, x, y, w, h, u * 8, new Color(34, 31, 27), new Color(70, 62, 50), u * 1.2);
        double sw = w * 0.72, sx = x + u * 6, sy = y + u * 6, sh = h - u * 12;
        box(g, sx - u * 1.5, sy - u * 1.5, sw + u * 3, sh + u * 3, u * 10, INK, null, 0);
        // the picture: snow, lines, a brighter band
        BufferedImage snow = new BufferedImage((int) sw, (int) sh, BufferedImage.TYPE_INT_RGB);
        Random rnd = new Random(42);
        for (int py = 0; py < snow.getHeight(); py++) {
            double band = Math.exp(-Math.pow((py - snow.getHeight() * 0.62) / (snow.getHeight() * 0.07), 2));
            for (int px = 0; px < snow.getWidth(); px++) {
                double v = 0.16 + 0.34 * rnd.nextDouble() + 0.22 * band;
                if (py % 3 == 0) v *= 0.6;
                double ex = (px - snow.getWidth() * 0.5) / (snow.getWidth() * 0.5), ey = (py - snow.getHeight() * 0.5) / (snow.getHeight() * 0.5);
                v *= 1 - 0.55 * (ex * ex + ey * ey) / 2;
                int r = (int) (v * 205), gg = (int) (v * 225), b = (int) (v * 215);
                snow.setRGB(px, py, r << 16 | gg << 8 | b);
            }
        }
        java.awt.Shape old = g.getClip();
        g.clip(new RoundRectangle2D.Double(sx, sy, sw, sh, u * 9, u * 9));
        g.drawImage(snow, (int) sx, (int) sy, null);
        // the on-screen display: a channel plate and a volume bar
        g.setColor(GOOD);
        g.fill(new Rectangle2D.Double(sx + u * 5, sy + u * 5, u * 13, u * 5));
        for (int i = 0; i < 12; i++) {
            g.setColor(i < 7 ? GOOD : new Color(126, 170, 96, 70));
            g.fill(new Rectangle2D.Double(sx + u * 5 + i * u * 3.2, sy + sh - u * 9, u * 2, u * 4));
        }
        g.setClip(old);
        // the panel on the right: two knobs and channel buttons
        double px = sx + sw + u * 3, pw = x + w - u * 5 - px, cx = px + pw / 2;
        knob(g, cx, y + h * 0.22, Math.min(pw * 0.36, h * 0.12), -60);
        knob(g, cx, y + h * 0.47, Math.min(pw * 0.36, h * 0.12), 40);
        for (int i = 0; i < 4; i++) {
            box(g, px + pw * 0.08 + (i % 2) * pw * 0.46, y + h * 0.66 + (i / 2) * h * 0.11, pw * 0.38, h * 0.075, u * 1.5,
                i == 1 ? SAND : new Color(52, 55, 53), null, 0);
        }
    }

    static void radio(Graphics2D g, double x, double y, double w, double h) {
        double u = Math.min(w, h) / 100;
        box(g, x, y, w, h, u * 8, new Color(30, 33, 32), FRAME, u * 1.4);
        // the speaker
        double gw = w * 0.30, gx = x + u * 8, gy = y + u * 10, gh = h - u * 20;
        box(g, gx, gy, gw, gh, u * 4, INK, null, 0);
        g.setColor(new Color(64, 68, 66));
        g.setStroke(new BasicStroke((float) (u * 1.6)));
        for (double ly = gy + u * 6; ly < gy + gh - u * 4; ly += u * 7) g.draw(new Line2D.Double(gx + u * 5, ly, gx + gw - u * 5, ly));
        // the dial: ticks, remembered stations, the needle
        double dx = gx + gw + u * 8, dw = x + w - u * 8 - dx, dy = y + u * 12, dh = h * 0.34;
        box(g, dx, dy, dw, dh, u * 2, new Color(205, 190, 142), null, 0);
        g.setColor(INK);
        for (int i = 0; i <= 40; i++) {
            double tx = dx + dw * 0.04 + dw * 0.92 * i / 40;
            g.setStroke(new BasicStroke((float) (i % 5 == 0 ? u * 1.1 : u * 0.6)));
            g.draw(new Line2D.Double(tx, dy + dh * (i % 5 == 0 ? 0.30 : 0.48), tx, dy + dh * 0.78));
        }
        g.setColor(new Color(70, 120, 60));
        for (double s : new double[] {0.22, 0.55, 0.81}) g.fill(new Rectangle2D.Double(dx + dw * s, dy + dh * 0.08, u * 2.2, dh * 0.16));
        g.setColor(EMBER);
        g.setStroke(new BasicStroke((float) (u * 1.4)));
        g.draw(new Line2D.Double(dx + dw * 0.63, dy - u, dx + dw * 0.63, dy + dh + u));
        // knobs and station buttons
        double ky = y + h * 0.72, r = Math.min(h * 0.14, dw * 0.10);
        knob(g, dx + r, ky, r, -120);
        knob(g, dx + dw - r, ky, r, 20);
        for (int i = 0; i < 4; i++) {
            box(g, dx + r * 2.6 + i * (dw - r * 5.2) / 4, ky - r * 0.55, (dw - r * 5.2) / 4 - u * 2, r * 1.1, u * 1.5,
                i == 2 ? GOOD : new Color(52, 55, 53), null, 0);
        }
    }

    static void tvRadio(Graphics2D g, double x, double y, double w, double h, boolean banner) {
        if (banner) {
            tv(g, x + w * 0.02, y, w * 0.50, h);
            radio(g, x + w * 0.56, y + h * 0.22, w * 0.44, h * 0.78);
        } else {
            tv(g, x, y + h * 0.04, w, h * 0.52);
            // an aerial
            g.setColor(DIM);
            g.setStroke(new BasicStroke(4));
            g.draw(new Line2D.Double(x + w * 0.50, y + h * 0.04, x + w * 0.28, y - h * 0.06));
            g.draw(new Line2D.Double(x + w * 0.50, y + h * 0.04, x + w * 0.74, y - h * 0.06));
            radio(g, x + w * 0.06, y + h * 0.66, w * 0.88, h * 0.32);
        }
    }

    static void tank(Graphics2D g, double x, double y, double w, double h, double level, Color liquid, double ghost) {
        double u = w / 100;
        box(g, x, y, w, h, u * 6, CELL, null, 0);
        double ih = h - u * 12, iy = y + u * 6, ix = x + u * 6, iw = w - u * 12;
        java.awt.Shape old = g.getClip();
        g.clip(new RoundRectangle2D.Double(ix, iy, iw, ih, u * 4, u * 4));
        g.setColor(INK);
        g.fill(new Rectangle2D.Double(ix, iy, iw, ih));
        if (ghost > 0) {   // what the pour will add
            g.setColor(new Color(liquid.getRed(), liquid.getGreen(), liquid.getBlue(), 80));
            g.fill(new Rectangle2D.Double(ix, iy + ih * (1 - level - ghost), iw, ih * ghost));
        }
        g.setPaint(new GradientPaint(0, (float) (iy + ih * (1 - level)), liquid, 0, (float) (iy + ih), liquid.darker().darker()));
        g.fill(new Rectangle2D.Double(ix, iy + ih * (1 - level), iw, ih * level));
        g.setColor(new Color(255, 255, 255, 60));
        g.fill(new Rectangle2D.Double(ix, iy + ih * (1 - level), iw, Math.max(2, u * 2)));
        g.setClip(old);
        g.setColor(new Color(255, 255, 255, 46));
        g.setStroke(new BasicStroke((float) Math.max(1, u * 1.2)));
        for (int i = 1; i < 4; i++) g.draw(new Line2D.Double(ix, iy + ih * i / 4, ix + iw * 0.22, iy + ih * i / 4));
        box(g, x, y, w, h, u * 6, null, FRAME, Math.max(2, u * 2.4));
    }

    static void liquids(Graphics2D g, double x, double y, double w, double h, boolean banner) {
        double tw = w * (banner ? 0.24 : 0.36), th = banner ? h : h * 0.74;
        double lx = x + (banner ? w * 0.10 : 0), rx = x + w - tw - (banner ? w * 0.10 : 0);
        tank(g, lx, y, tw, th, 0.72, WATER, 0);
        tank(g, rx, y, tw, th, 0.24, WATER, 0.30);
        // the arrow between them
        double ax = lx + tw + w * 0.04, bx = rx - w * 0.04, ay = y + th * 0.5, s = Math.min(w, h) * (banner ? 0.10 : 0.05);
        g.setColor(SAND);
        g.setStroke(new BasicStroke((float) (s * 0.45)));
        g.draw(new Line2D.Double(ax, ay, bx - s, ay));
        Path2D head = new Path2D.Double();
        head.moveTo(bx, ay); head.lineTo(bx - s * 1.5, ay - s); head.lineTo(bx - s * 1.5, ay + s); head.closePath();
        g.fill(head);
        if (!banner) {   // the buttons 25 / 50 / 75 / all
            double by = y + th + h * 0.07, bw = w * 0.21, bh = h * 0.09;
            for (int i = 0; i < 4; i++) {
                double bx2 = x + i * (w - bw) / 3;
                box(g, bx2, by, bw, bh, 6, i == 1 ? SAND : CELL, FRAME, 3);
                g.setColor(i == 1 ? INK : DIM);
                double fill = (i + 1) / 4.0;
                g.fill(new Rectangle2D.Double(bx2 + bw * 0.18, by + bh * 0.42, bw * 0.64 * fill, bh * 0.16));
            }
        }
    }
}
