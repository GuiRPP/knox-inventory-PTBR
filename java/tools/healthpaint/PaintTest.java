import java.awt.image.BufferedImage;
import java.io.File;
import java.util.ArrayList;

import javax.imageio.ImageIO;

import knox.java.KnoxHealthPaint;
import knox.java.KnoxHealthPaint.Layer;
import knox.java.KnoxHealthPaint.Mask;

/**
 * The health paint's mixing (KnoxHealthPaint.paint) on a real skin, outside the
 * game: a broken left thigh under X-ray, a bleeding forearm, the light of the
 * hover on the right forearm and on the head.
 *   java -cp "KnoxInventoryJava.jar;projectzomboid.jar" PaintTest.java skin.png flipY masksDir out.png
 * skin.png: a dump of the skin (flipY 1: rows bottom first, as the first dumps were).
 */
public class PaintTest {
    public static void main(String[] args) throws Exception {
        BufferedImage skin = ImageIO.read(new File(args[0]));
        boolean flip = args[1].equals("1");
        File dir = new File(args[2]);
        int w = skin.getWidth(), h = skin.getHeight();
        byte[] clean = new byte[w * h * 4], out = new byte[w * h * 4];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int c = skin.getRGB(x, flip ? h - 1 - y : y);
                int i = (y * w + x) * 4;
                clean[i] = (byte) (c >> 16);
                clean[i + 1] = (byte) (c >> 8);
                clean[i + 2] = (byte) c;
                clean[i + 3] = (byte) (c >>> 24);
            }
        }
        ArrayList<Layer> ls = new ArrayList<>();
        // a fracture's colour on the thigh, the X-ray, a bleeding forearm, the hover's light
        // (as KnoxHealthModel.layers makes them, 2026-10-19)
        ls.add(layer(dir, "hl_m_UpperLeg_L", 3, 0.82f, 0.80f, 0.66f, 0.55f, false));
        ls.add(layer(dir, "hl_m_ForeArm_L", 3, 0.86f, 0.16f, 0.14f, 0.65f, false));
        ls.add(layer(dir, "hl_m_ForeArm_R", 4, 1.0f, 0.93f, 0.80f, 0.7f, true));
        ls.add(layer(dir, "hl_m_Head", 4, 1.0f, 0.93f, 0.80f, 0.7f * 0.65f, true));
        // the broken thigh under the mouse: see-through (its alpha down, premultiplied)
        Layer see = layer(dir, "hl_m_UpperLeg_L", 3, 0, 0, 0, 0.72f, false);
        see.see = true;
        ls.add(see);
        long t0 = System.nanoTime();
        int n = 200;
        for (int i = 0; i < n; i++) KnoxHealthPaint.paint(clean, out, w, h, ls);
        System.out.printf("paint: %.3f ms a frame (%d layers, %dx%d)%n", (System.nanoTime() - t0) / 1e6 / n, ls.size(), w, h);
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int i = (y * w + x) * 4;
                img.setRGB(x, y, (255 << 24) | ((out[i] & 255) << 16) | ((out[i + 1] & 255) << 8) | (out[i + 2] & 255));
            }
        }
        ImageIO.write(img, "png", new File(args[3]));
        System.out.println("written " + args[3]);
    }

    static Layer layer(File dir, String name, float soft, float r, float g, float b, float a, boolean light) throws Exception {
        Mask m = KnoxHealthPaint.load(new File(dir, name + ".png"));
        if (soft >= 0.5f) m = KnoxHealthPaint.soften(m, soft);
        Layer l = new Layer();
        l.mask = m;
        l.r = r; l.g = g; l.b = b; l.a = a; l.light = light;
        return l;
    }
}
