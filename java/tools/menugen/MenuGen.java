import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Random;
import java.util.TreeSet;
import javax.imageio.ImageIO;

/**
 * Generates the art of the main menu campfire scene: low-poly meshes (.x),
 * their textures, the 2D backdrop and effect textures and the model scripts.
 *
 *   java MenuGen.java "<...>\Knox Inventory\42\media" ["<game>\media"]
 *
 * Meshes are in scene units of UI3DScene with Y up: a standing character is
 * 1.47 units tall (1 unit = 1.22 m). UI3DScene draws static models unlit
 * (ambient 1, no lights), so light is baked into the textures or given by a
 * tint per object from Lua; textures hold plain colors for that reason.
 * UVs never rely on which way v runs (textures are symmetric top to bottom).
 */
public class MenuGen {

    static Path media;
    static String xHeader;

    public static void main(String[] args) throws IOException {
        media = Path.of(args[0]);
        Path game = Path.of(args.length > 1 ? args[1]
            : "C:\\Program Files (x86)\\Steam\\steamapps\\common\\ProjectZomboid\\media");
        xHeader = readTemplates(game.resolve("models_X/Static/Clothes/M_NoseStud.x"));

        Files.createDirectories(media.resolve("models_X/knoxmenu"));
        Files.createDirectories(media.resolve("textures/knoxmenu"));
        Files.createDirectories(media.resolve("ui/knoxmenu"));
        Files.createDirectories(media.resolve("scripts"));

        // "... media game flame": only the fire's 3D flame and the model scripts. (A full
        // run redraws every texture, and their noise is not the same from run to run:
        // art that was approved in game would change under it.)
        if (args.length > 2 && args[2].equals("flame")) {
            flameArt();
            burntLogTexture();
            scripts();
            System.out.println("done (flame only)");
            return;
        }
        // "... media game bar": only the winter bar's art (KnoxMenuBar) - files of
        // its own, nothing of the camp is drawn again.
        if (args.length > 2 && args[2].equals("bar")) {
            barTextures();
            barAtlas();
            barMeshes();
            barProps();
            barScripts();
            System.out.println("done (bar only)");
            return;
        }
        groundTextures();
        woodTexture();
        stoneTexture();
        charredTexture();
        embersTexture();
        planksTexture();
        crateTexture();
        canvasTexture();
        barrelTexture();
        treeTexture();

        groundMeshes();
        logMesh();
        barrelMesh();
        firepitMeshes();
        flameArt();
        burntLogTexture();
        fenceMesh();
        towerMesh();
        crateMesh();
        tentMesh();
        treeMesh();
        depthArt();
        campTextures();
        campMeshes();

        skyTexture();
        treelineTexture();
        mistTexture();
        glowTexture();
        vignetteTexture();
        flameFrames();
        newsArt("ui/knoxmenu/news_art.png", 900, 1100, false);
        newsArt("ui/knoxmenu/news_banner.png", 912, 204, true);

        scripts();
        System.out.println("done");
    }

    // ------------------------------------------------------------------ noise

    static float hash(int x, int y, int seed) {
        int h = x * 374761393 + y * 668265263 + seed * 1442695041;
        h = (h ^ (h >>> 13)) * 1274126177;
        h ^= h >>> 16;
        return (h & 0xffffff) / 16777215f;
    }

    static int wrap(int v, int period) {
        int m = v % period;
        return m < 0 ? m + period : m;
    }

    /** Value noise, repeating every `period` cells in both directions. */
    static float vnoise(double x, double y, int period, int seed) {
        int xi = (int) Math.floor(x), yi = (int) Math.floor(y);
        double fx = x - xi, fy = y - yi;
        fx = fx * fx * (3 - 2 * fx);
        fy = fy * fy * (3 - 2 * fy);
        float a = hash(wrap(xi, period), wrap(yi, period), seed);
        float b = hash(wrap(xi + 1, period), wrap(yi, period), seed);
        float c = hash(wrap(xi, period), wrap(yi + 1, period), seed);
        float d = hash(wrap(xi + 1, period), wrap(yi + 1, period), seed);
        return (float) ((a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy);
    }

    static float fbm(double x, double y, int period, int seed, int octaves) {
        float sum = 0, amp = 0.5f, norm = 0;
        for (int i = 0; i < octaves; i++) {
            sum += amp * vnoise(x, y, period, seed + i * 17);
            norm += amp;
            amp *= 0.5f;
            x *= 2;
            y *= 2;
            period *= 2;
        }
        return sum / norm;
    }

    static float clamp(double v) {
        return (float) Math.max(0, Math.min(1, v));
    }

    static float smooth(double a, double b, double x) {
        double t = Math.max(0, Math.min(1, (x - a) / (b - a)));
        return (float) (t * t * (3 - 2 * t));
    }

    static float lerp(double a, double b, double t) {
        return (float) (a + (b - a) * t);
    }

    static final Random DITHER = new Random(7);

    static int rgba(double r, double g, double b, double a) {
        // a little noise before rounding: dark gradients band otherwise
        double d = (DITHER.nextDouble() - 0.5) / 255.0;
        int ri = (int) Math.round(clamp(r + d) * 255), gi = (int) Math.round(clamp(g + d) * 255);
        int bi = (int) Math.round(clamp(b + d) * 255), ai = (int) Math.round(clamp(a) * 255);
        return (ai << 24) | (ri << 16) | (gi << 8) | bi;
    }

    static void save(BufferedImage img, String rel) throws IOException {
        File f = media.resolve(rel).toFile();
        ImageIO.write(img, "png", f);
        System.out.println(rel + " " + f.length());
    }

    // --------------------------------------------------------------- textures

    static final int GROUND_PPU = 96;          // pixels per scene unit
    static final double NEAR_HALF = 6;         // the near quad is 12 x 12 units around the fire
    static final double NEAR_GAIN = 1.5;       // near texture is stored brighter, Lua tints it by 1/gain
    static final double[] NIGHT = {0.075, 0.095, 0.15};

    /** Ground color (unlit) at a world point; repeats every 2 units. */
    static double[] groundAlbedo(double x, double z) {
        double grass = fbm(x * 2, z * 2, 4, 11, 4);
        double grain = fbm(x * 24, z * 24, 48, 23, 2);
        double pebbles = vnoise(x * 40, z * 40, 80, 31);
        double g = smooth(0.42, 0.62, grass);
        // (kept close in tone: the pattern repeats every 2 units and must not show it)
        double r = lerp(0.33, 0.27, g), gr = lerp(0.29, 0.28, g), b = lerp(0.21, 0.17, g);
        double k = 0.72 + 0.5 * grain;
        if (pebbles > 0.93) k *= 1.45;
        return new double[] {r * k, gr * k, b * k};
    }

    static void groundTextures() throws IOException {
        int n = 2 * GROUND_PPU;
        BufferedImage tile = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double[] c = groundAlbedo((x + 0.5) / GROUND_PPU, (y + 0.5) / GROUND_PPU);
                tile.setRGB(x, y, rgba(c[0] * 0.5, c[1] * 0.5, c[2] * 0.5, 1));
            }
        }
        save(tile, "textures/knoxmenu/ground_tile.png");

        int m = (int) (2 * NEAR_HALF * GROUND_PPU);
        BufferedImage near = new BufferedImage(m, m, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < m; y++) {
            for (int x = 0; x < m; x++) {
                double wx = -NEAR_HALF + (x + 0.5) / GROUND_PPU, wz = -NEAR_HALF + (y + 0.5) / GROUND_PPU;
                double[] c = groundAlbedo(wx, wz);
                double d = Math.sqrt(wx * wx + wz * wz);
                // trampled earth around the fire, scorched under it
                double worn = smooth(3.2, 1.2, d) * (0.6 + 0.4 * fbm(wx * 1.5, wz * 1.5, 64, 5, 3));
                c[0] = lerp(c[0], 0.34, worn * 0.7);
                c[1] = lerp(c[1], 0.27, worn * 0.7);
                c[2] = lerp(c[2], 0.20, worn * 0.7);
                double scorch = smooth(0.75, 0.3, d);
                for (int i = 0; i < 3; i++) c[i] *= 1 - 0.8 * scorch;
                // the fire's pool of light, fading to nothing at the quad's edge
                double pool = 1 / (1 + (d / 1.25) * (d / 1.25)) * smooth(NEAR_HALF, 3.5, d);
                pool *= 0.93 + 0.14 * fbm(wx * 3, wz * 3, 64, 9, 2);
                double lr = NIGHT[0] + 2.2 * pool, lg = NIGHT[1] + 1.15 * pool, lb = NIGHT[2] + 0.38 * pool;
                near.setRGB(x, y, rgba(c[0] * lr * NEAR_GAIN, c[1] * lg * NEAR_GAIN, c[2] * lb * NEAR_GAIN, 1));
            }
        }
        save(near, "textures/knoxmenu/ground_near.png");
    }

    static void woodTexture() throws IOException {
        int n = 256;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double u = x / (double) n, v = y / (double) n;
                double r, g, b;
                if (u < 0.75) {
                    // bark: streaks along the log, lighter on its top (v = 0.5), dark underneath
                    double streak = fbm(u * 6, v * 48, 48, 3, 3);
                    double k = (0.55 + 0.9 * streak) * (0.6 - 0.4 * Math.cos(2 * Math.PI * v));
                    r = 0.34 * k; g = 0.25 * k; b = 0.17 * k;
                } else {
                    // the cut end: rings around the middle of the strip
                    double dx = (u - 0.875) / 0.115, dy = (v - 0.5) / 0.115;
                    double d = Math.sqrt(dx * dx + dy * dy);
                    double ring = 0.5 + 0.5 * Math.sin(d * 26 + 3 * vnoise(u * 30, v * 30, 64, 8));
                    double k = d < 0.9 ? 0.75 + 0.25 * ring : 0.45;
                    r = 0.62 * k; g = 0.49 * k; b = 0.32 * k;
                }
                img.setRGB(x, y, rgba(r, g, b, 1));
            }
        }
        save(img, "textures/knoxmenu/wood.png");
    }

    static void stoneTexture() throws IOException {
        int n = 128;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double k = 0.55 + 0.7 * fbm(x / 16.0, y / 16.0, 8, 41, 4);
                img.setRGB(x, y, rgba(0.44 * k, 0.42 * k, 0.40 * k, 1));
            }
        }
        save(img, "textures/knoxmenu/stone.png");
    }

    static void charredTexture() throws IOException {
        int n = 128;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double f = fbm(x / 10.0, y / 28.0, 12, 51, 3);
                double crack = smooth(0.06, 0.0, Math.abs(f - 0.5));   // glowing cracks along a noise contour
                double k = 0.05 + 0.08 * fbm(x / 6.0, y / 6.0, 20, 52, 2);
                img.setRGB(x, y, rgba(k + 1.0 * crack, k * 0.9 + 0.42 * crack, k * 0.85 + 0.08 * crack, 1));
            }
        }
        save(img, "textures/knoxmenu/charred.png");
    }

    static void embersTexture() throws IOException {
        int n = 128;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double dx = (x - 63.5) / 64, dy = (y - 63.5) / 64;
                double d = Math.sqrt(dx * dx + dy * dy);
                double hot = smooth(0.85, 0.1, d) * (0.35 + 0.9 * fbm(x / 9.0, y / 9.0, 14, 61, 3));
                double ash = 0.07 + 0.06 * vnoise(x / 3.0, y / 3.0, 40, 62);
                img.setRGB(x, y, rgba(ash + 1.1 * hot, ash * 0.9 + 0.5 * hot * hot, ash * 0.8 + 0.1 * hot * hot, 1));
            }
        }
        save(img, "textures/knoxmenu/embers.png");
    }

    /** 8 planks side by side, the right four darker (faces turned away). */
    static void planksTexture() throws IOException {
        int n = 256;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                int col = x / 32, lx = x % 32;
                double tone = 0.8 + 0.4 * hash(col, 0, 71);
                double grain = fbm(x / 5.0, y / 60.0, 16, 72 + col, 3);
                double k = tone * (0.6 + 0.8 * grain);
                if (lx < 2 || lx > 29) k *= 0.45;                                   // plank edges
                if (hash(x / 3, y / 3, 73) > 0.992) k *= 0.5;                       // knots, nail holes
                if (col >= 4) k *= 0.6;
                img.setRGB(x, y, rgba(0.40 * k, 0.33 * k, 0.25 * k, 1));
            }
        }
        save(img, "textures/knoxmenu/planks.png");
    }

    static void crateTexture() throws IOException {
        int n = 128;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                int board = y / 21;
                double k = (0.85 + 0.3 * hash(board, 1, 81)) * (0.65 + 0.7 * fbm(x / 50.0, y / 4.0, 32, 82, 3));
                if (y % 21 < 2) k *= 0.4;
                boolean frame = x < 12 || x > 115 || y < 12 || y > 115;
                boolean brace = Math.abs(x - y) < 7 || Math.abs(x - (127 - y)) < 7;
                if (frame || brace) k = (0.55 + 0.5 * fbm(x / 6.0, y / 6.0, 24, 83, 2)) * 0.8;
                img.setRGB(x, y, rgba(0.42 * k, 0.34 * k, 0.24 * k, 1));
            }
        }
        save(img, "textures/knoxmenu/crate.png");
    }

    /** Left half: tent cloth. Right half: the same with a dark slit down the middle (the entrance). */
    static void canvasTexture() throws IOException {
        int n = 256;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double u = x / (double) n;
                double k = 0.7 + 0.45 * fbm(x / 20.0, y / 20.0, 16, 91, 3);
                k *= 0.94 + 0.06 * ((x % 4 < 2) ? 1 : 0) + 0.04 * ((y % 4 < 2) ? 1 : 0);   // weave
                if (x % 64 < 2) k *= 0.6;                                                    // seams
                double r = 0.36 * k, g = 0.37 * k, b = 0.26 * k;
                if (u >= 0.5) {
                    double slit = smooth(0.075, 0.045, Math.abs(u - 0.75));
                    r = lerp(r, 0.02, slit); g = lerp(g, 0.02, slit); b = lerp(b, 0.025, slit);
                }
                img.setRGB(x, y, rgba(r, g, b, 1));
            }
        }
        save(img, "textures/knoxmenu/canvas.png");
    }

    static void barrelTexture() throws IOException {
        int n = 256;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double u = x / (double) n, v = y / (double) n;
                double rust = smooth(0.5, 0.75, fbm(x / 22.0, y / 22.0, 12, 101, 4));
                double k = 0.75 + 0.35 * fbm(x / 7.0, y / 7.0, 40, 102, 2);
                double r = lerp(0.20, 0.36, rust) * k, g = lerp(0.27, 0.20, rust) * k, b = lerp(0.33, 0.12, rust) * k;
                if (u < 0.75) {
                    double rib = Math.min(Math.min(Math.abs(v - 0.04), Math.abs(v - 0.5)), Math.abs(v - 0.96));
                    if (rib < 0.02) { r *= 0.55; g *= 0.55; b *= 0.55; }
                } else {
                    double dx = (u - 0.875) / 0.115, dy = (v - 0.5) / 0.115;
                    double d = Math.sqrt(dx * dx + dy * dy);
                    if (d > 0.86 && d < 1) { r *= 0.5; g *= 0.5; b *= 0.5; }
                    if (d >= 1) { r *= 0.3; g *= 0.3; b *= 0.3; }
                }
                img.setRGB(x, y, rgba(r, g, b, 1));
            }
        }
        save(img, "textures/knoxmenu/barrel.png");
    }

    /** Left strip (u < 0.22): bark. The rest: fir needles, one side of the tree lighter (the moon's). */
    static void treeTexture() throws IOException {
        int n = 128;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double u = x / (double) n;
                if (u < 0.22) {
                    double k = 0.6 + 0.8 * fbm(x / 3.0, y / 24.0, 16, 201, 2);
                    img.setRGB(x, y, rgba(0.24 * k, 0.17 * k, 0.12 * k, 1));
                } else {
                    double around = (u - 0.25) / 0.75;
                    double side = 0.62 + 0.38 * Math.cos(2 * Math.PI * (around - 0.2));
                    double needles = 0.55 + 0.9 * fbm(x / 2.5, y / 14.0, 32, 202, 3);
                    double k = side * needles;
                    img.setRGB(x, y, rgba(0.17 * k, 0.29 * k, 0.17 * k, 1));
                }
            }
        }
        save(img, "textures/knoxmenu/tree.png");
    }

    // ------------------------------------------------------------ ui textures

    /**
     * The night sky, 2048 x 1024, drawn across the screen's width from its top
     * (the moon is a sprite of its own, so that it stays round and sharp).
     */
    static void skyTexture() throws IOException {
        int w = 2048, h = 1024;
        float[][][] px = new float[h][w][3];
        for (int y = 0; y < h; y++) {
            double t = Math.min(1, y / (h * 0.42));   // the horizon's glow is reached well above the bottom
            for (int x = 0; x < w; x++) {
                double cloud = smooth(0.48, 0.82, fbm(x / 260.0, y / 110.0, 64, 111, 5));
                double k = 1 - 0.5 * cloud * (1 - t * 0.6);
                px[y][x][0] = (float) (lerp(0.010, 0.062, t * t) * k);
                px[y][x][1] = (float) (lerp(0.018, 0.088, t * t) * k);
                px[y][x][2] = (float) (lerp(0.042, 0.140, t * t) * k);
            }
        }
        Random rnd = new Random(112);
        for (int i = 0; i < 1500; i++) {
            int x = 2 + rnd.nextInt(w - 4), y = 2 + (int) (Math.pow(rnd.nextDouble(), 1.6) * h * 0.5);
            float s = 0.12f + (float) Math.pow(rnd.nextDouble(), 3) * 0.88f;
            double cloud = smooth(0.48, 0.82, fbm(x / 260.0, y / 110.0, 64, 111, 5));
            s *= (float) (1 - 0.85 * cloud);
            float warm = rnd.nextFloat();
            float[] c = {s * (0.85f + 0.15f * warm), s * 0.92f, s * (1.0f - 0.2f * warm)};
            for (int ch = 0; ch < 3; ch++) px[y][x][ch] = Math.max(px[y][x][ch], c[ch]);
            if (s > 0.6f) {   // the bright ones spill into their neighbours
                int[][] around = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
                for (int[] a : around) {
                    for (int ch = 0; ch < 3; ch++) {
                        px[y + a[1]][x + a[0]][ch] = Math.max(px[y + a[1]][x + a[0]][ch], c[ch] * 0.35f);
                    }
                }
            }
        }
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++) img.setRGB(x, y, rgba(px[y][x][0], px[y][x][1], px[y][x][2], 1));
        save(img, "ui/knoxmenu/sky.png");

        // the moon: a lit disc with its seas, soft at the rim
        int n = 256;
        img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double dx = (x - 127.5) / 120.0, dy = (y - 127.5) / 120.0;
                double d = Math.sqrt(dx * dx + dy * dy);
                double seas = smooth(0.5, 0.68, fbm(x / 46.0 + 3, y / 46.0 + 7, 16, 115, 4));
                double craters = fbm(x / 9.0, y / 9.0, 64, 116, 2);
                double limb = 0.8 + 0.2 * Math.sqrt(Math.max(0, 1 - d * d));
                double k = limb * (1 - 0.28 * seas) * (0.93 + 0.14 * craters);
                img.setRGB(x, y, rgba(0.86 * k, 0.88 * k, 0.86 * k, smooth(1.0, 0.965, d)));
            }
        }
        save(img, "ui/knoxmenu/moon.png");
    }

    static void skyTextureOld() throws IOException {
        int w = 512, h = 512;
        float[][][] px = new float[h][w][3];
        for (int y = 0; y < h; y++) {
            double t = y / (double) (h - 1);
            for (int x = 0; x < w; x++) {
                double cloud = smooth(0.45, 0.8, fbm(x / 90.0, y / 45.0, 64, 111, 4));
                double k = 1 - 0.55 * cloud * (1 - t * 0.5);
                px[y][x][0] = (float) (lerp(0.010, 0.060, t * t) * k);
                px[y][x][1] = (float) (lerp(0.018, 0.085, t * t) * k);
                px[y][x][2] = (float) (lerp(0.042, 0.135, t * t) * k);
                // the moon behind thin cloud, upper right
                double dx = (x - 0.80 * w) / w, dy = (y - 0.17 * h) / h;
                double d = Math.sqrt(dx * dx + dy * dy);
                double halo = Math.exp(-d * 9) * 0.16 + Math.exp(-d * 40) * 0.25;
                px[y][x][0] += (float) (halo * 0.75);
                px[y][x][1] += (float) (halo * 0.85);
                px[y][x][2] += (float) halo;
                if (d < 0.018) {
                    px[y][x][0] = 0.74f; px[y][x][1] = 0.78f; px[y][x][2] = 0.80f;
                }
            }
        }
        Random rnd = new Random(112);
        for (int i = 0; i < 260; i++) {
            int x = rnd.nextInt(w), y = (int) (rnd.nextDouble() * rnd.nextDouble() * h * 0.8);
            float s = 0.15f + rnd.nextFloat() * rnd.nextFloat() * 0.75f;
            double cloud = smooth(0.45, 0.8, fbm(x / 90.0, y / 45.0, 64, 111, 4));
            s *= (float) (1 - cloud);
            for (int c = 0; c < 3; c++) px[y][x][c] = Math.max(px[y][x][c], s * (c == 2 ? 1f : 0.9f));
        }
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++) img.setRGB(x, y, rgba(px[y][x][0], px[y][x][1], px[y][x][2], 1));
        save(img, "ui/knoxmenu/sky.png");
    }

    /** A line of firs against the sky, two rows deep; repeats sideways. */
    static void treelineTexture() throws IOException {
        int w = 1024, h = 256;
        int[] back = new int[w], front = new int[w];
        firs(back, w, 46, 70, 185, 121);
        firs(front, w, 34, 40, 130, 122);
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++) {
            int up = h - 1 - y;
            for (int x = 0; x < w; x++) {
                if (up < front[x]) img.setRGB(x, y, rgba(0.012, 0.018, 0.030, 1));
                else if (up < back[x]) img.setRGB(x, y, rgba(0.032, 0.048, 0.078, 1));
                else img.setRGB(x, y, 0);
            }
        }
        save(img, "ui/knoxmenu/treeline.png");
    }

    static void firs(int[] top, int w, int count, int minH, int maxH, int seed) {
        Random rnd = new Random(seed);
        for (int x = 0; x < w; x++) top[x] = (int) (minH * 0.45 + 10 * vnoise(x / 40.0, 0, w / 40 + 1, seed));
        for (int i = 0; i < count; i++) {
            int cx = rnd.nextInt(w);
            int th = minH + rnd.nextInt(maxH - minH);
            double half = th * (0.17 + 0.07 * rnd.nextDouble());
            for (int dx = (int) -half; dx <= half; dx++) {
                int x = wrap(cx + dx, w);
                // height of the fir's outline over this column: tiers of drooping branches
                for (int yy = th; yy > top[x]; yy--) {
                    double tier = (yy % 13) / 13.0;
                    double width = half * (1 - yy / (double) th) * (0.62 + 0.38 * (1 - tier)) + 1.2;
                    if (Math.abs(dx) <= width) {
                        top[x] = yy;
                        break;
                    }
                }
            }
        }
    }

    static void mistTexture() throws IOException {
        int w = 8, h = 128;
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++) {
            double t = y / (double) (h - 1);
            double a = Math.sin(Math.PI * t);
            for (int x = 0; x < w; x++) img.setRGB(x, y, rgba(0.10, 0.14, 0.21, a * a * 0.75));
        }
        save(img, "ui/knoxmenu/mist.png");
    }

    static void glowTexture() throws IOException {
        int n = 256;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double dx = (x - 127.5) / 127.5, dy = (y - 127.5) / 127.5;
                double d = Math.sqrt(dx * dx + dy * dy);
                img.setRGB(x, y, rgba(1, 1, 1, Math.pow(Math.max(0, 1 - d), 2.2)));
            }
        }
        save(img, "ui/knoxmenu/glow.png");
    }

    static void vignetteTexture() throws IOException {
        int n = 256;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double dx = (x - 127.5) / 127.5, dy = (y - 127.5) / 127.5;
                double d = Math.sqrt(dx * dx + dy * dy);
                img.setRGB(x, y, rgba(0, 0, 0, smooth(0.5, 1.35, d) * 0.92));
            }
        }
        save(img, "ui/knoxmenu/vignette.png");
    }

    /** The classic cellular fire: heat rises from the bottom row and cools; one frame per step. */
    static void flameFrames() throws IOException {
        int w = 64, h = 96, frames = 24;
        float[][] heat = new float[h + 2][w];
        Random rnd = new Random(131);
        for (int step = 0; step < 200 + frames; step++) {
            for (int x = 0; x < w; x++) {
                double p = Math.max(0, 1 - Math.pow((x - 31.5) / 25.0, 4));
                // gaps in the bed of heat break the cone into tongues
                float seed = rnd.nextDouble() < 0.7 ? (float) (p * (0.6 + 0.4 * rnd.nextDouble())) : 0f;
                heat[h][x] = seed;
                heat[h + 1][x] = (float) (p * 0.8);
            }
            for (int y = 0; y < h; y++) {
                int sway = (int) Math.round(Math.sin(step * 0.4 + y * 0.11) * 1.1);
                for (int x = 0; x < w; x++) {
                    int drift = rnd.nextInt(3) - 1 + sway;
                    float sum = heat[y + 1][wrap(x - 1 + drift, w)] + heat[y + 1][wrap(x + drift, w)]
                        + heat[y + 1][wrap(x + 1 + drift, w)] + heat[y + 2][x];
                    // flames narrow as they rise: the sides cool faster
                    double side = Math.abs(x - 31.5) / 31.5;
                    float v = sum / 4.0f - (float) (0.002 + 0.012 * side * side + 0.022 * rnd.nextDouble() * rnd.nextDouble());
                    heat[y][x] = Math.max(0, v);
                }
            }
            int f = step - 200;
            if (f < 0) continue;
            BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    double t = heat[y][x];
                    double a = smooth(0.10, 0.34, t);
                    double r, g, b;
                    if (t < 0.4) {
                        double k = t / 0.4;
                        r = lerp(0.55, 0.98, k); g = lerp(0.06, 0.32, k); b = lerp(0.0, 0.03, k);
                    } else if (t < 0.7) {
                        double k = (t - 0.4) / 0.3;
                        r = lerp(0.98, 1.0, k); g = lerp(0.32, 0.74, k); b = lerp(0.03, 0.14, k);
                    } else {
                        double k = Math.min(1, (t - 0.7) / 0.3);
                        r = 1.0; g = lerp(0.74, 0.96, k); b = lerp(0.14, 0.70, k);
                    }
                    img.setRGB(x, y, rgba(r, g, b, a));
                }
            }
            save(img, String.format("ui/knoxmenu/flame_%02d.png", f));
        }
    }

    /**
     * Stock pictures for a news post that brings none of its own: the camp's
     * night in the inventory's palette (charcoal, sand, ember). The banner is
     * darker on its left, where a card's text lies.
     */
    static void newsArt(String rel, int w, int h, boolean banner) throws IOException {
        int[] back = new int[w], front = new int[w];
        firs(back, w, banner ? 26 : 22, (int) (h * 0.30), (int) (h * 0.62), 501);
        firs(front, w, banner ? 20 : 16, (int) (h * 0.16), (int) (h * 0.40), 502);
        double mx = w * (banner ? 0.80 : 0.66), my = h * (banner ? 0.36 : 0.24), mr = h * (banner ? 0.20 : 0.085);
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++) {
            double t = y / (double) (h - 1);
            for (int x = 0; x < w; x++) {
                int up = h - 1 - y;
                double grain = 0.94 + 0.12 * vnoise(x / 2.0, y / 2.0, 512, 503);
                // sky: charcoal above, an ember glow rising from the ground
                double glow = Math.exp(-Math.pow((x - w * 0.5) / (w * 0.45), 2)) * Math.pow(t, 3);
                double r = 0.070 + 0.62 * glow, g = 0.078 + 0.30 * glow, b = 0.080 + 0.08 * glow;
                double dx = x - mx, dy = y - my, d = Math.sqrt(dx * dx + dy * dy);
                double halo = Math.exp(-d / (mr * 2.2)) * 0.22;
                r += halo * 0.83; g += halo * 0.76; b += halo * 0.54;
                if (d < mr) {   // the moon, sand
                    double k = 0.86 + 0.14 * fbm(x / (mr * 0.5), y / (mr * 0.5), 16, 504, 3);
                    r = 0.83 * k; g = 0.76 * k; b = 0.54 * k;
                }
                if (up < front[x]) {
                    r = 0.030; g = 0.034; b = 0.034;
                } else if (up < back[x]) {
                    r = 0.075 + 0.20 * glow; g = 0.085 + 0.09 * glow; b = 0.085 + 0.02 * glow;
                }
                if (banner) {
                    double shade = lerp(0.30, 1.0, smooth(0.30, 0.78, x / (double) w));
                    r *= shade; g *= shade; b *= shade;
                }
                img.setRGB(x, y, rgba(r * grain, g * grain, b * grain, 1));
            }
        }
        save(img, rel);
    }

    // ----------------------------------------------------------------- meshes

    /** A 3 x 4 affine transform. */
    static final class Xf {
        final double[] m;

        Xf(double[] m) { this.m = m; }

        static Xf id() { return new Xf(new double[] {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0}); }

        static Xf move(double x, double y, double z) { return new Xf(new double[] {1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z}); }

        static Xf scale(double x, double y, double z) { return new Xf(new double[] {x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0}); }

        static Xf rotX(double deg) {
            double c = Math.cos(Math.toRadians(deg)), s = Math.sin(Math.toRadians(deg));
            return new Xf(new double[] {1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0});
        }

        static Xf rotY(double deg) {
            double c = Math.cos(Math.toRadians(deg)), s = Math.sin(Math.toRadians(deg));
            return new Xf(new double[] {c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0});
        }

        static Xf rotZ(double deg) {
            double c = Math.cos(Math.toRadians(deg)), s = Math.sin(Math.toRadians(deg));
            return new Xf(new double[] {c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0});
        }

        /** this after o: (this.then... ) p -> this * (o * p) */
        Xf mul(Xf o) {
            double[] r = new double[12];
            for (int i = 0; i < 3; i++) {
                for (int j = 0; j < 4; j++) {
                    double v = 0;
                    for (int k = 0; k < 3; k++) v += m[i * 4 + k] * o.m[k * 4 + j];
                    if (j == 3) v += m[i * 4 + 3];
                    r[i * 4 + j] = v;
                }
            }
            return new Xf(r);
        }

        double[] point(double x, double y, double z) {
            return new double[] {m[0] * x + m[1] * y + m[2] * z + m[3], m[4] * x + m[5] * y + m[6] * z + m[7],
                m[8] * x + m[9] * y + m[10] * z + m[11]};
        }
    }

    static final class Mesh {
        final List<double[]> verts = new ArrayList<>();   // x y z nx ny nz u v
        final List<int[]> tris = new ArrayList<>();

        int vert(double[] p, double[] n, double u, double v) {
            verts.add(new double[] {p[0], p[1], p[2], n[0], n[1], n[2], u, v});
            return verts.size() - 1;
        }

        static double[] normal(double[] a, double[] b, double[] c) {
            double ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
            double vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
            double nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
            double l = Math.sqrt(nx * nx + ny * ny + nz * nz);
            if (l < 1e-9) return new double[] {0, 1, 0};
            return new double[] {nx / l, ny / l, nz / l};
        }

        void tri(double[] a, double[] b, double[] c, double[] ua, double[] ub, double[] uc) {
            double[] n = normal(a, b, c);
            tris.add(new int[] {vert(a, n, ua[0], ua[1]), vert(b, n, ub[0], ub[1]), vert(c, n, uc[0], uc[1])});
        }

        /** Corners in order around the face; uv = {u0, v0, u1, v1} spread over it. */
        void quad(double[] a, double[] b, double[] c, double[] d, double[] uv) {
            double[] n = normal(a, b, c);
            int i0 = vert(a, n, uv[0], uv[1]), i1 = vert(b, n, uv[2], uv[1]);
            int i2 = vert(c, n, uv[2], uv[3]), i3 = vert(d, n, uv[0], uv[3]);
            tris.add(new int[] {i0, i1, i2});
            tris.add(new int[] {i0, i2, i3});
        }

        /**
         * A box of the given size centered at the origin, then moved by xf.
         * `front` covers the two big faces (-z and +z), `side` the other four.
         */
        void box(double sx, double sy, double sz, Xf xf, double[] front, double[] side) {
            double x = sx / 2, y = sy / 2, z = sz / 2;
            double[][] p = new double[8][];
            int i = 0;
            for (int zi = -1; zi <= 1; zi += 2)
                for (int yi = -1; yi <= 1; yi += 2)
                    for (int xi = -1; xi <= 1; xi += 2) p[i++] = xf.point(xi * x, yi * y, zi * z);
            // p index: bit0 = +x, bit1 = +y, bit2 = +z
            quad(p[4], p[5], p[7], p[6], front);   // +z
            quad(p[1], p[0], p[2], p[3], front);   // -z
            quad(p[5], p[1], p[3], p[7], side);    // +x
            quad(p[0], p[4], p[6], p[2], side);    // -x
            quad(p[6], p[7], p[3], p[2], side);    // +y
            quad(p[0], p[1], p[5], p[4], side);    // -y
        }

        /**
         * A cylinder along local Y from 0 to 1 with radius 0.5, then moved by
         * xf. The side takes u 0..0.74 along its length and v around; the caps
         * a circle in the strip right of u = 0.75.
         */
        void cylinder(int sides, Xf xf, boolean caps) {
            for (int i = 0; i < sides; i++) {
                double a0 = 2 * Math.PI * i / sides, a1 = 2 * Math.PI * (i + 1) / sides;
                double[] b0 = xf.point(0.5 * Math.cos(a0), 0, 0.5 * Math.sin(a0));
                double[] b1 = xf.point(0.5 * Math.cos(a1), 0, 0.5 * Math.sin(a1));
                double[] t0 = xf.point(0.5 * Math.cos(a0), 1, 0.5 * Math.sin(a0));
                double[] t1 = xf.point(0.5 * Math.cos(a1), 1, 0.5 * Math.sin(a1));
                double v0 = i / (double) sides, v1 = (i + 1) / (double) sides;
                double[] n = normal(b0, t0, t1);
                int i0 = vert(b0, n, 0.0, v0), i1 = vert(t0, n, 0.74, v0);
                int i2 = vert(t1, n, 0.74, v1), i3 = vert(b1, n, 0.0, v1);
                tris.add(new int[] {i0, i1, i2});
                tris.add(new int[] {i0, i2, i3});
                if (caps) {
                    for (int end = 0; end <= 1; end++) {
                        double[] c = xf.point(0, end, 0);
                        // wound so that the normal points out of the end (the models are shaded)
                        double[] e0 = end == 0 ? b0 : t1, e1 = end == 0 ? b1 : t0;
                        double ua = end == 0 ? a0 : a1, ub = end == 0 ? a1 : a0;
                        tri(c, e0, e1, new double[] {0.875, 0.5},
                            new double[] {0.875 + 0.11 * Math.cos(ua), 0.5 + 0.11 * Math.sin(ua)},
                            new double[] {0.875 + 0.11 * Math.cos(ub), 0.5 + 0.11 * Math.sin(ub)});
                    }
                }
            }
        }

        /** A lumpy ball (a rock): radius about 1 before xf; texture wrapped around it. */
        void rock(Xf xf, int seed) {
            int seg = 6, rings = 4;
            double[][][] p = new double[rings + 1][seg + 1][];
            for (int r = 0; r <= rings; r++) {
                double lat = Math.PI * r / rings;
                for (int s = 0; s <= seg; s++) {
                    int sw = s % seg;
                    double lon = 2 * Math.PI * sw / seg;
                    double k = (r == 0 || r == rings) ? 0.85 : 0.75 + 0.5 * hash(sw, r, seed);
                    p[r][s] = xf.point(k * Math.sin(lat) * Math.cos(lon), k * Math.cos(lat), k * Math.sin(lat) * Math.sin(lon));
                }
            }
            for (int r = 0; r < rings; r++) {
                for (int s = 0; s < seg; s++) {
                    double u0 = s / (double) seg, u1 = (s + 1) / (double) seg;
                    double v0 = r / (double) rings, v1 = (r + 1) / (double) rings;
                    double[] a = p[r][s], b = p[r][s + 1], c = p[r + 1][s + 1], d = p[r + 1][s];
                    if (r > 0) tri(a, b, c, new double[] {u0, v0}, new double[] {u1, v0}, new double[] {u1, v1});
                    if (r < rings - 1) tri(a, c, d, new double[] {u0, v0}, new double[] {u1, v1}, new double[] {u0, v1});
                }
            }
        }

        void write(String name) throws IOException {
            StringBuilder sb = new StringBuilder(xHeader);
            sb.append("Material KnoxMenuMat {\n 1.000000;1.000000;1.000000;1.000000;;\n 10.000000;\n")
              .append(" 0.000000;0.000000;0.000000;;\n 0.000000;0.000000;0.000000;;\n}\n\n");
            sb.append("Frame ").append(name).append(" {\n\n FrameTransformMatrix {\n")
              .append("  1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,")
              .append("0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000;;\n }\n\n");
            sb.append(" Mesh ").append(name).append(" {\n  ").append(verts.size()).append(";\n");
            for (int i = 0; i < verts.size(); i++) {
                double[] v = verts.get(i);
                sb.append(String.format(Locale.ROOT, "  %.6f;%.6f;%.6f;%s\n", v[0], v[1], v[2], i == verts.size() - 1 ? ";" : ","));
            }
            sb.append("  ").append(tris.size()).append(";\n");
            faces(sb, "  ");
            sb.append("\n  MeshNormals {\n   ").append(verts.size()).append(";\n");
            for (int i = 0; i < verts.size(); i++) {
                double[] v = verts.get(i);
                sb.append(String.format(Locale.ROOT, "   %.6f;%.6f;%.6f;%s\n", v[3], v[4], v[5], i == verts.size() - 1 ? ";" : ","));
            }
            sb.append("   ").append(tris.size()).append(";\n");
            faces(sb, "   ");
            sb.append("  }\n\n  MeshMaterialList {\n   1;\n   ").append(tris.size()).append(";\n");
            for (int i = 0; i < tris.size(); i++) sb.append("   0").append(i == tris.size() - 1 ? ";" : ",").append('\n');
            sb.append("   { KnoxMenuMat }\n  }\n\n  MeshTextureCoords c1 {\n   ").append(verts.size()).append(";\n");
            for (int i = 0; i < verts.size(); i++) {
                double[] v = verts.get(i);
                sb.append(String.format(Locale.ROOT, "   %.6f;%.6f;%s\n", v[6], v[7], i == verts.size() - 1 ? ";" : ","));
            }
            sb.append("  }\n }\n}\n");
            Path f = media.resolve("models_X/knoxmenu/" + name + ".x");
            Files.writeString(f, sb.toString(), StandardCharsets.US_ASCII);
            System.out.println("models_X/knoxmenu/" + name + ".x verts=" + verts.size() + " tris=" + tris.size());
        }

        void faces(StringBuilder sb, String indent) {
            for (int i = 0; i < tris.size(); i++) {
                int[] t = tris.get(i);
                sb.append(indent).append("3;").append(t[0]).append(',').append(t[1]).append(',').append(t[2])
                  .append(i == tris.size() - 1 ? ";;" : ";,").append('\n');
            }
        }
    }

    /** Everything of a vanilla .x file up to its material: the format line and the templates. */
    static String readTemplates(Path vanilla) throws IOException {
        StringBuilder sb = new StringBuilder();
        for (String line : Files.readAllLines(vanilla, StandardCharsets.ISO_8859_1)) {
            if (line.startsWith("Material ")) break;
            sb.append(line).append('\n');
        }
        return sb.toString();
    }

    static final double[] FULL = {0, 0, 1, 1};

    static void groundMeshes() throws IOException {
        Mesh far = new Mesh();
        for (int tz = -70; tz < 10; tz += 2) {
            for (int tx = -50; tx < 50; tx += 2) {
                if (tx >= -NEAR_HALF && tx < NEAR_HALF && tz >= -NEAR_HALF && tz < NEAR_HALF) continue;
                far.quad(new double[] {tx, 0, tz}, new double[] {tx + 2, 0, tz},
                    new double[] {tx + 2, 0, tz + 2}, new double[] {tx, 0, tz + 2}, FULL);
            }
        }
        far.write("ground_far");
        Mesh near = new Mesh();
        double h = NEAR_HALF;
        near.quad(new double[] {-h, 0, -h}, new double[] {h, 0, -h}, new double[] {h, 0, h}, new double[] {-h, 0, h}, FULL);
        near.write("ground_near");
    }

    /** Lying along X, 1 long and 1 thick, resting on the ground: scale it (length, thickness, thickness). */
    static void logMesh() throws IOException {
        Mesh m = new Mesh();
        m.cylinder(10, Xf.move(-0.5, 0.5, 0).mul(Xf.rotZ(-90)), true);
        m.write("log");
    }

    /** Standing, 1 high and 1 across. */
    static void barrelMesh() throws IOException {
        Mesh m = new Mesh();
        m.cylinder(12, Xf.id(), true);
        m.write("barrel");
    }

    static void firepitMeshes() throws IOException {
        Random rnd = new Random(141);
        Mesh stones = new Mesh();
        int count = 11;
        for (int i = 0; i < count; i++) {
            double a = 360.0 * i / count + rnd.nextDouble() * 8;
            double r = 0.11 + 0.05 * rnd.nextDouble();
            double ring = 0.50 + 0.04 * rnd.nextDouble();
            Xf xf = Xf.rotY(a).mul(Xf.move(ring, r * 0.55, 0)).mul(Xf.rotY(rnd.nextDouble() * 360))
                .mul(Xf.scale(r, r * 0.72, r * 1.15));
            stones.rock(xf, 150 + i);
        }
        stones.write("fire_stones");

        Mesh logs = new Mesh();
        int sticks = 6;
        for (int i = 0; i < sticks; i++) {
            double a = 360.0 * i / sticks + rnd.nextDouble() * 20;
            double len = 0.62 + 0.12 * rnd.nextDouble(), thick = 0.075 + 0.03 * rnd.nextDouble();
            // from the ring's inside, leaning over the middle
            Xf xf = Xf.rotY(a).mul(Xf.move(0.36, 0.02, 0)).mul(Xf.rotZ(52 + rnd.nextDouble() * 8))
                .mul(Xf.scale(thick, len, thick));
            logs.cylinder(6, xf, true);
        }
        // one burnt log lying across the bottom
        logs.cylinder(6, Xf.rotY(35).mul(Xf.move(-0.33, 0.07, 0.05)).mul(Xf.rotZ(-90)).mul(Xf.scale(0.12, 0.66, 0.12)), true);
        logs.write("fire_logs");

        Mesh embers = new Mesh();
        int seg = 14;
        double rad = 0.44;
        for (int i = 0; i < seg; i++) {
            double a0 = 2 * Math.PI * i / seg, a1 = 2 * Math.PI * (i + 1) / seg;
            embers.tri(new double[] {0, 0.02, 0}, new double[] {rad * Math.cos(a0), 0.02, rad * Math.sin(a0)},
                new double[] {rad * Math.cos(a1), 0.02, rad * Math.sin(a1)}, new double[] {0.5, 0.5},
                new double[] {0.5 + 0.5 * Math.cos(a0), 0.5 + 0.5 * Math.sin(a0)},
                new double[] {0.5 + 0.5 * Math.cos(a1), 0.5 + 0.5 * Math.sin(a1)});
        }
        embers.write("fire_embers");
    }

    /**
     * The fire itself, in 3D: one faceted tongue of flame (a low-poly teardrop,
     * 1 high, widest about 0.66 a third of the way up, its tip bent a little)
     * and three plain textures for its three layers - deep orange at the back,
     * orange, yellow at the front. Lua stands several tongues of each layer in
     * the fire pit and makes them live (stretch, sway, turn).
     * The scene draws these models unlit, so the facets are told apart by the
     * texture: it has 8 columns, each a little lighter or darker, and every
     * face lies wholly in one of them.
     */
    static void flameArt() throws IOException {
        double[][] base = {{0.80, 0.21, 0.06}, {0.97, 0.50, 0.09}, {1.00, 0.83, 0.34}};
        String[] names = {"flame_out", "flame_mid", "flame_core"};
        for (int c = 0; c < 3; c++) {
            BufferedImage img = new BufferedImage(64, 8, BufferedImage.TYPE_INT_ARGB);
            for (int x = 0; x < 64; x++) {
                double k = 0.60 + 0.58 * hash(x / 8, c, 77);   // wide apart: the facets must read
                for (int y = 0; y < 8; y++) {
                    img.setRGB(x, y, rgba(Math.min(1, base[c][0] * k), Math.min(1, base[c][1] * k),
                        Math.min(1, base[c][2] * k), 1));
                }
            }
            save(img, "textures/knoxmenu/" + names[c] + ".png");
        }

        Mesh m = new Mesh();
        int sides = 6;
        // {height, radius}: narrow at the foot too (a tongue cut off flat at the bottom made
        // the fire stand on a ruler - seen in game 2026-10-13), widest a quarter of the way up
        double[][] rings = {{0.02, 0.05}, {0.10, 0.21}, {0.25, 0.33}, {0.48, 0.28}, {0.74, 0.15}};
        double[][][] p = new double[rings.length][sides][];
        for (int r = 0; r < rings.length; r++) {
            for (int s = 0; s < sides; s++) {
                // every other ring half a step round: the sides become triangles, like a cut stone
                double a = 2 * Math.PI * (s + (r % 2) * 0.5) / sides;
                double rad = rings[r][1] * (0.86 + 0.28 * hash(s, r, 91));
                double lean = 0.05 * rings[r][0] * rings[r][0];   // the whole tongue bends a little to +x
                p[r][s] = new double[] {rad * Math.cos(a) + lean, rings[r][0], rad * Math.sin(a)};
            }
        }
        double[] tip = {0.06, 1.0, 0.02};
        double[] foot = {0, 0, 0};
        int face = 0;
        for (int r = 0; r < rings.length - 1; r++) {
            for (int s = 0; s < sides; s++) {
                double[] b0 = p[r][s], b1 = p[r][(s + 1) % sides];
                double[] t0 = p[r + 1][s], t1 = p[r + 1][(s + 1) % sides];
                flameFace(m, b0, t0, t1, face++);
                flameFace(m, b0, t1, b1, face++);
            }
        }
        for (int s = 0; s < sides; s++) {
            flameFace(m, p[rings.length - 1][s], tip, p[rings.length - 1][(s + 1) % sides], face++);
            flameFace(m, foot, p[0][s], p[0][(s + 1) % sides], face++);
        }
        m.write("flame");
    }

    /**
     * A log burning in the fire, in the look of the flames and the stones: flat
     * facets, no drawn detail. The log is a prism of 10 sides, and the scene
     * draws it unlit, so the texture gives each side one plain shade - warm and
     * light on the sides turned up to the fire, nearly black underneath - and
     * the log reads as a faceted solid. Along the log the only change is a soft
     * one: charcoal black in the middle, under the flames, with a dull red heat
     * in it, brown towards the ends. The cut ends are plain dark wood.
     * (Three tries before this, all seen in game 2026-10-13: a bright net of
     * cracks read as lava; blobs of noise read as lava still, and blurred; bark
     * streaks with glowing fissures were pulled out along the log - "a texture
     * simply stretched". Any drawn detail is stretched on a log this small: none.)
     * The side takes u 0..0.74 along the log and v around it, v = 0.5 on top
     * (as the camp's other logs); alike from both ends.
     */
    static void burntLogTexture() throws IOException {
        int n = 256, sides = 10;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double u = x / (double) n, v = y / (double) n;
                double r, g, b;
                if (u < 0.75) {
                    // one shade per side of the prism: by the middle of the side v falls on
                    double vc = (Math.floor(v * sides) + 0.5) / sides;
                    double up = 0.5 - 0.5 * Math.cos(2 * Math.PI * vc);       // 1 on top, 0 underneath
                    double burn = smooth(0.0, 1.0, 1 - Math.min(1, Math.abs(u - 0.375) / 0.33));
                    // brown wood, lit warm from above; charcoal where it burns
                    double wr = lerp(0.060, 0.50, up), wg = lerp(0.045, 0.30, up), wb = lerp(0.035, 0.15, up);
                    double cr = lerp(0.030, 0.17, up), cg = lerp(0.022, 0.095, up), cb = lerp(0.018, 0.06, up);
                    r = lerp(wr, cr, burn); g = lerp(wg, cg, burn); b = lerp(wb, cb, burn);
                    // the heat in the charcoal: strongest on the sides turned down to the embers
                    double heat = burn * burn * (0.30 + 0.45 * (1 - up));
                    r += 0.62 * heat; g += 0.15 * heat; b += 0.02 * heat;
                } else {
                    r = 0.20; g = 0.135; b = 0.09;
                }
                img.setRGB(x, y, rgba(r, g, b, 1));
            }
        }
        save(img, "textures/knoxmenu/burnt_log.png");
    }

    /** One facet of the flame: all of it in one column of the texture. */
    static void flameFace(Mesh m, double[] a, double[] b, double[] c, int face) {
        int col = (int) Math.floor(hash(face, 3, 55) * 8) % 8;
        double[] uv = {(col + 0.5) / 8.0, 0.5};
        m.tri(a, b, c, uv, uv, uv);
    }

    /** uv of one of the planks texture's 8 columns (4..7 are the dark ones). */
    static double[] plank(int col) {
        return new double[] {col / 8.0 + 0.004, 0, (col + 1) / 8.0 - 0.004, 1};
    }

    /** A rough barricade of planks, 40 units long along X, with gaps to see through. */
    static void fenceMesh() throws IOException {
        Random rnd = new Random(161);
        Mesh m = new Mesh();
        double x = -20;
        while (x < 20) {
            double w = 0.15 + 0.07 * rnd.nextDouble();
            double gap = 0.10 + 0.18 * rnd.nextDouble();
            if (rnd.nextDouble() < 0.22) {                 // a missing plank
                x += w + gap;
                continue;
            }
            double h = 1.0 + 0.38 * rnd.nextDouble();
            Xf xf = Xf.move(x + w / 2, h / 2 - 0.03, 0).mul(Xf.rotZ(rnd.nextDouble() * 6 - 3));
            m.box(w, h, 0.03, xf, plank(rnd.nextInt(4)), plank(4 + rnd.nextInt(4)));
            x += w + gap;
        }
        for (double px = -20; px <= 20; px += 2.5) {
            m.box(0.11, 1.45, 0.11, Xf.move(px, 0.725, -0.08), plank(4 + rnd.nextInt(4)), plank(4 + rnd.nextInt(4)));
        }
        for (double ry : new double[] {0.36, 0.92}) {
            for (double rx = -20; rx < 20; rx += 2.5) {
                Xf xf = Xf.move(rx + 1.25, ry + rnd.nextDouble() * 0.04, -0.045).mul(Xf.rotZ(90));
                m.box(0.09, 2.5, 0.04, xf, plank(4 + rnd.nextInt(4)), plank(4 + rnd.nextInt(4)));
            }
        }
        m.write("fence");
    }

    /** A watchtower of posts and planks: 2 x 2 at the base, platform at 3.0, roof to 5.3. */
    static void towerMesh() throws IOException {
        Random rnd = new Random(171);
        Mesh m = new Mesh();
        double half = 0.85;
        for (int sx = -1; sx <= 1; sx += 2) {
            for (int sz = -1; sz <= 1; sz += 2) {
                m.box(0.14, 3.0, 0.14, Xf.move(sx * half, 1.5, sz * half), plank(1), plank(5));
                m.box(0.10, 1.75, 0.10, Xf.move(sx * half, 3.95, sz * half), plank(2), plank(6));
            }
        }
        // cross braces on every side
        double diag = Math.sqrt(2 * half * 2 * half + 2.6 * 2.6);
        double tilt = Math.toDegrees(Math.atan2(2 * half, 2.6));
        for (int s = -1; s <= 1; s += 2) {
            m.box(0.08, diag, 0.04, Xf.move(0, 1.45, s * half).mul(Xf.rotZ(tilt * s)), plank(0), plank(4));
            m.box(0.08, diag, 0.04, Xf.move(s * half, 1.45, 0).mul(Xf.rotY(90)).mul(Xf.rotZ(tilt * s)), plank(3), plank(7));
        }
        // platform
        for (int i = 0; i < 9; i++) {
            m.box(0.22, 0.06, 2.1, Xf.move(-0.96 + i * 0.24, 3.03, 0), plank(4 + i % 4), plank(i % 4));
        }
        // walls of the platform: planks side by side, the front (+z) left half open
        for (int i = 0; i < 9; i++) {
            double off = -0.96 + i * 0.24;
            double h = 0.78 + 0.1 * rnd.nextDouble();
            m.box(0.21, h, 0.03, Xf.move(off, 3.06 + h / 2, -1.02), plank(i % 4), plank(4 + i % 4));
            if (i >= 4) m.box(0.21, h, 0.03, Xf.move(off, 3.06 + h / 2, 1.02), plank((i + 1) % 4), plank(4 + i % 4));
            m.box(0.21, h, 0.03, Xf.move(-1.02, 3.06 + h / 2, off).mul(Xf.rotY(90)), plank((i + 2) % 4), plank(4 + i % 4));
            m.box(0.21, h, 0.03, Xf.move(1.02, 3.06 + h / 2, off).mul(Xf.rotY(90)), plank((i + 3) % 4), plank(4 + i % 4));
        }
        // roof: two slopes meeting in a ridge along X
        for (int s = -1; s <= 1; s += 2) {
            for (int i = 0; i < 10; i++) {
                Xf xf = Xf.move(-1.17 + i * 0.26, 5.03, s * 0.62).mul(Xf.rotX(s * 24)).mul(Xf.rotX(90));
                m.box(0.25, 1.45, 0.04, xf, plank(4 + i % 4), plank(4 + (i + 1) % 4));
            }
        }
        // ladder up the front
        for (int s = -1; s <= 1; s += 2) {
            m.box(0.06, 3.25, 0.06, Xf.move(-0.45 + s * 0.2, 1.55, 1.25).mul(Xf.rotX(-9)), plank(2), plank(6));
        }
        for (int i = 0; i < 9; i++) {
            double y = 0.3 + i * 0.33;
            m.box(0.46, 0.04, 0.04, Xf.move(-0.45, y, 1.25 + 0.245 - y * 0.158), plank(1), plank(5));
        }
        m.write("tower");
    }

    static void crateMesh() throws IOException {
        Mesh m = new Mesh();
        m.box(1, 1, 1, Xf.move(0, 0.5, 0), FULL, FULL);
        m.write("crate");
    }

    /** A ridge tent: 1.9 wide, 1.25 high, 2.4 long along Z, the entrance at +z. */
    static void tentMesh() throws IOException {
        Mesh m = new Mesh();
        double w = 0.95, h = 1.25, l = 1.2;
        double[] cloth = {0.01, 0, 0.49, 1};
        // (corners in the order that turns the normals outwards: the models are shaded)
        m.quad(new double[] {-w, 0, -l}, new double[] {-w, 0, l}, new double[] {0, h, l}, new double[] {0, h, -l}, cloth);
        m.quad(new double[] {w, 0, l}, new double[] {w, 0, -l}, new double[] {0, h, -l}, new double[] {0, h, l}, cloth);
        for (int s = -1; s <= 1; s += 2) {
            m.tri(new double[] {-s * w, 0, s * l}, new double[] {s * w, 0, s * l}, new double[] {0, h, s * l},
                new double[] {0.5, 1}, new double[] {1, 1}, new double[] {0.75, 0});
        }
        m.write("tent");
    }

    /**
     * A fir, 1 high (scale it to its height): a trunk and five tiers of
     * branches, each a cone with a wavy rim. Open underneath, like the real thing.
     */
    static void treeMesh() throws IOException {
        Mesh m = new Mesh();
        int sides = 8;
        double tr = 0.018, th = 0.24;
        for (int i = 0; i < 6; i++) {
            double a0 = 2 * Math.PI * i / 6, a1 = 2 * Math.PI * (i + 1) / 6;
            m.quad(new double[] {tr * Math.cos(a0), 0, tr * Math.sin(a0)}, new double[] {tr * Math.cos(a1), 0, tr * Math.sin(a1)},
                new double[] {tr * Math.cos(a1), th, tr * Math.sin(a1)}, new double[] {tr * Math.cos(a0), th, tr * Math.sin(a0)},
                new double[] {0.02, 0, 0.18, 1});
        }
        int tiers = 5;
        for (int t = 0; t < tiers; t++) {
            double base = 0.12 + t * 0.165;
            double tip = t == tiers - 1 ? 1.0 : base + 0.31;
            double radius = 0.21 - t * 0.036;
            double turn = t * 0.4;
            for (int i = 0; i < sides; i++) {
                double a0 = 2 * Math.PI * i / sides + turn, a1 = 2 * Math.PI * (i + 1) / sides + turn;
                double r0 = radius * (i % 2 == 0 ? 1.0 : 0.76), r1 = radius * ((i + 1) % 2 == 0 ? 1.0 : 0.76);
                double d0 = i % 2 == 0 ? -0.025 : 0, d1 = (i + 1) % 2 == 0 ? -0.025 : 0;   // long branches droop
                double u0 = 0.25 + 0.75 * i / sides, u1 = 0.25 + 0.75 * (i + 1) / sides;
                m.tri(new double[] {0, tip, 0}, new double[] {r1 * Math.cos(a1), base + d1, r1 * Math.sin(a1)},
                    new double[] {r0 * Math.cos(a0), base + d0, r0 * Math.sin(a0)},
                    new double[] {(u0 + u1) / 2, 0.02}, new double[] {u1, 0.98}, new double[] {u0, 0.98});
            }
        }
        m.write("tree");
    }

    /** What gives the scene depth: mist standing between the rows of trees, shadows on the ground. */
    static void depthArt() throws IOException {
        // mist: wisps along a band, thickest in the middle of the texture's height
        int w = 512, h = 128;
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++) {
            double v = y / (double) (h - 1);
            double band = Math.pow(Math.sin(Math.PI * v), 2.2);
            for (int x = 0; x < w; x++) {
                double wisp = 0.45 + 0.75 * fbm(x / 64.0, y / 20.0, 8, 401, 4);
                double edge = smooth(0, 0.08, x / (double) w) * smooth(1, 0.92, x / (double) w);
                img.setRGB(x, y, rgba(0.15, 0.19, 0.27, band * wisp * 0.6 * edge));
            }
        }
        save(img, "textures/knoxmenu/haze.png");

        // a soft round shadow, stretched and turned by the scene
        int n = 128;
        img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double dx = (x - 63.5) / 63.5, dy = (y - 63.5) / 63.5;
                double d = Math.sqrt(dx * dx + dy * dy);
                img.setRGB(x, y, rgba(0.01, 0.008, 0.008, 0.62 * Math.pow(Math.max(0, 1 - d), 1.4)));
            }
        }
        save(img, "textures/knoxmenu/shadow.png");

        // crosses: boards once painted white (the same 8 columns as the planks)
        n = 256;
        img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                int col = x / 32;
                // weathered boards, greyer and a little lighter than the fence's; only a
                // trace of old paint (whitewashed ones stood out of the picture)
                double paint = 0.22 * smooth(0.5, 0.75, fbm(x / 9.0, y / 40.0, 16, 411 + col, 3));
                double k = (0.75 + 0.4 * fbm(x / 5.0, y / 50.0, 16, 412, 2)) * (col >= 4 ? 0.72 : 1);
                img.setRGB(x, y, rgba(lerp(0.47, 0.70, paint) * k, lerp(0.42, 0.68, paint) * k, lerp(0.36, 0.62, paint) * k, 1));
            }
        }
        save(img, "textures/knoxmenu/cross.png");

        // a sheet standing up, 1 wide and 1 high, for the mist
        Mesh m = new Mesh();
        m.quad(new double[] {-0.5, 0, 0}, new double[] {0.5, 0, 0}, new double[] {0.5, 1, 0}, new double[] {-0.5, 1, 0}, FULL);
        m.write("haze");
    }

    // ------------------------------------------------------------- camp things

    static void campTextures() throws IOException {
        // lantern: left half dark metal, right half the lit glass
        int n = 64;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                if (x < n / 2) {
                    double k = 0.8 + 0.4 * vnoise(x / 4.0, y / 4.0, 16, 301);
                    img.setRGB(x, y, rgba(0.13 * k, 0.13 * k, 0.14 * k, 1));
                } else {
                    double dx = (x - 47.5) / 16.0, dy = (y - 31.5) / 32.0;
                    double g = Math.max(0, 1 - (dx * dx + dy * dy));
                    img.setRGB(x, y, rgba(0.75 + 0.25 * g, 0.5 + 0.42 * g, 0.16 + 0.5 * g * g, 1));
                }
            }
        }
        save(img, "textures/knoxmenu/lantern.png");

        // the lamp's pool of light on the ground: lit earth in the middle, the
        // night ground's own color at the rim (so it reads even unblended)
        n = 256;
        img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double dx = (x - 127.5) / 127.5, dy = (y - 127.5) / 127.5;
                double r = Math.sqrt(dx * dx + dy * dy);
                double f = 1 / (1 + (r / 0.3) * (r / 0.3)) * smooth(1.0, 0.6, r);
                double[] c = groundAlbedo(dx * 3.5, dy * 3.5);
                double lr = NIGHT[0] + 1.5 * f, lg = NIGHT[1] + 1.05 * f, lb = NIGHT[2] + 0.55 * f;
                img.setRGB(x, y, rgba(c[0] * lr, c[1] * lg, c[2] * lb, smooth(1.0, 0.72, r)));
            }
        }
        save(img, "textures/knoxmenu/light_pool.png");

        // bedroll cloth: faded blue with stripes
        n = 64;
        img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double k = 0.75 + 0.4 * fbm(x / 9.0, y / 9.0, 8, 311, 3);
                boolean stripe = (x % 16) < 3;
                double r = stripe ? 0.42 : 0.20, g = stripe ? 0.38 : 0.27, b = stripe ? 0.30 : 0.36;
                img.setRGB(x, y, rgba(r * k, g * k, b * k, 1));
            }
        }
        save(img, "textures/knoxmenu/bedroll.png");

        // axe: left half the handle's wood, right half steel
        img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                if (x < n / 2) {
                    double k = 0.7 + 0.6 * fbm(x / 3.0, y / 20.0, 8, 321, 2);
                    img.setRGB(x, y, rgba(0.46 * k, 0.33 * k, 0.20 * k, 1));
                } else {
                    double k = 0.75 + 0.5 * fbm(x / 6.0, y / 6.0, 8, 322, 2);
                    img.setRGB(x, y, rgba(0.42 * k, 0.43 * k, 0.45 * k, 1));
                }
            }
        }
        save(img, "textures/knoxmenu/axe.png");

        // clothesline: 8 columns - post wood, rope, then six cloths
        int w = 256, h = 64;
        double[][] cols = {{0.36, 0.28, 0.20}, {0.50, 0.44, 0.33}, {0.55, 0.14, 0.12}, {0.20, 0.27, 0.42},
            {0.74, 0.72, 0.66}, {0.30, 0.36, 0.22}, {0.70, 0.55, 0.18}, {0.33, 0.33, 0.35}};
        img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int col = x / 32;
                double k = 0.78 + 0.4 * fbm(x / 7.0, y / 7.0, 32, 331 + col, 3);
                if (col == 2 && ((x % 8) < 2 || (y % 8) < 2)) k *= 0.55;   // the red one is plaid
                img.setRGB(x, y, rgba(cols[col][0] * k, cols[col][1] * k, cols[col][2] * k, 1));
            }
        }
        save(img, "textures/knoxmenu/clothes.png");
    }

    /** uv of one of the clothes texture's 8 columns. */
    static double[] cloth(int col) {
        return new double[] {col / 8.0 + 0.01, 0.05, (col + 1) / 8.0 - 0.01, 0.95};
    }

    static void campMeshes() throws IOException {
        // a hurricane lantern, 0.34 high, standing on the origin
        double[] metal = {0.03, 0.05, 0.47, 0.95}, glass = {0.53, 0.05, 0.97, 0.95};
        Mesh m = new Mesh();
        m.box(0.17, 0.045, 0.17, Xf.move(0, 0.0225, 0), metal, metal);
        m.box(0.12, 0.17, 0.12, Xf.move(0, 0.13, 0), glass, glass);
        m.box(0.17, 0.04, 0.17, Xf.move(0, 0.235, 0), metal, metal);
        m.box(0.08, 0.05, 0.08, Xf.move(0, 0.28, 0), metal, metal);
        for (int s = -1; s <= 1; s += 2) m.box(0.012, 0.22, 0.012, Xf.move(s * 0.09, 0.2, 0), metal, metal);
        m.box(0.2, 0.012, 0.012, Xf.move(0, 0.315, 0), metal, metal);
        m.write("lantern");

        // a post with an arm to hang the lantern from: the hook is at (0.42, 1.78)
        m = new Mesh();
        m.box(0.09, 1.95, 0.09, Xf.move(0, 0.975, 0), plank(1), plank(5));
        m.box(0.55, 0.06, 0.06, Xf.move(0.24, 1.84, 0), plank(2), plank(6));
        m.box(0.36, 0.045, 0.045, Xf.move(0.13, 1.68, 0).mul(Xf.rotZ(42)), plank(3), plank(7));
        m.box(0.015, 0.08, 0.015, Xf.move(0.42, 1.78, 0), plank(4), plank(4));
        m.write("lamp_post");

        // the lamp's light on the ground: a 1 x 1 square to scale
        m = new Mesh();
        m.quad(new double[] {-0.5, 0, -0.5}, new double[] {0.5, 0, -0.5}, new double[] {0.5, 0, 0.5},
            new double[] {-0.5, 0, 0.5}, FULL);
        m.write("light_pool");

        // firewood stacked between two stakes: logs 1 long along X, their cut ends at the sides
        Random rnd = new Random(341);
        m = new Mesh();
        int[] rows = {5, 4, 3};
        double d = 0.2;
        for (int r = 0; r < rows.length; r++) {
            for (int i = 0; i < rows[r]; i++) {
                double z = (i - (rows[r] - 1) / 2.0) * d + (rnd.nextDouble() - 0.5) * 0.02;
                double len = 0.9 + 0.2 * rnd.nextDouble();
                double thick = d * (0.86 + 0.14 * rnd.nextDouble());
                Xf xf = Xf.move(-len / 2 + (rnd.nextDouble() - 0.5) * 0.08, d / 2 + r * d * 0.87, z)
                    .mul(Xf.rotZ(-90)).mul(Xf.scale(thick, len, thick));
                m.cylinder(7, xf, true);
            }
        }
        for (int s = -1; s <= 1; s += 2) {
            m.cylinder(5, Xf.move(0.2 * s, 0, 0.56 * s).mul(Xf.scale(0.07, 0.75, 0.07)), true);
        }
        m.write("woodpile");

        // an axe struck into what it stands on: the blade's edge at the origin
        double[] wood = {0.03, 0.05, 0.47, 0.95}, steel = {0.53, 0.05, 0.97, 0.95};
        m = new Mesh();
        m.box(0.17, 0.10, 0.028, Xf.move(0.03, 0.05, 0).mul(Xf.rotZ(-18)), steel, steel);
        m.box(0.034, 0.74, 0.03, Xf.move(0.05, 0.07, 0).mul(Xf.rotZ(-52)).mul(Xf.move(0, 0.34, 0)), wood, wood);
        m.write("axe");

        // washing on a line between two posts, 3.2 wide
        m = new Mesh();
        for (int s = -1; s <= 1; s += 2) m.box(0.08, 1.75, 0.08, Xf.move(s * 1.6, 0.875, 0), cloth(0), cloth(0));
        m.box(3.2, 0.014, 0.014, Xf.move(0, 1.6, 0), cloth(1), cloth(1));
        double[][] wash = {{-1.15, 0.52, 0.56, 2}, {-0.5, 0.30, 0.78, 3}, {-0.05, 0.44, 0.50, 4},
            {0.48, 0.50, 0.60, 5}, {0.98, 0.26, 0.40, 6}, {1.3, 0.2, 0.7, 7}};
        for (double[] c : wash) {
            Xf xf = Xf.move(c[0], 1.6 - c[2] / 2, 0).mul(Xf.rotY(rnd.nextDouble() * 24 - 12))
                .mul(Xf.rotX(rnd.nextDouble() * 8 - 4));
            m.box(c[1], c[2], 0.012, xf, cloth((int) c[3]), cloth((int) c[3]));
        }
        m.write("clothesline");

        // a grave's cross of two boards, 1.05 high
        m = new Mesh();
        m.box(0.10, 1.05, 0.045, Xf.move(0, 0.525, 0), plank(0), plank(5));
        m.box(0.56, 0.10, 0.045, Xf.move(0, 0.74, 0.03).mul(Xf.rotZ(3)), plank(2), plank(6));
        m.write("cross");
    }

    // ---------------------------------------------------------------- scripts

    static void scripts() throws IOException {
        String[][] models = {
            {"GroundFar", "ground_far", "ground_tile"}, {"GroundNear", "ground_near", "ground_near"},
            {"Log", "log", "wood"}, {"Barrel", "barrel", "barrel"},
            {"FireStones", "fire_stones", "stone"}, {"FireLogs", "fire_logs", "charred"},
            {"FireEmbers", "fire_embers", "embers"}, {"Fence", "fence", "planks"},
            {"Tower", "tower", "planks"}, {"Crate", "crate", "crate"}, {"Tent", "tent", "canvas"},
            {"Tree", "tree", "tree"},
            {"Lantern", "lantern", "lantern"}, {"LampPost", "lamp_post", "planks"}, {"LightPool", "light_pool", "light_pool"},
            {"Bedroll", "log", "bedroll"}, {"Mat", "crate", "bedroll"}, {"WoodPile", "woodpile", "wood"},
            {"Stump", "barrel", "wood"}, {"Axe", "axe", "axe"}, {"Clothesline", "clothesline", "clothes"},
            {"Cross", "cross", "cross"}, {"Haze", "haze", "haze"}, {"Shadow", "light_pool", "shadow"},
            {"FlameOut", "flame", "flame_out"}, {"FlameMid", "flame", "flame_mid"}, {"FlameCore", "flame", "flame_core"},
            // a log of the fire itself: the camp's log with the charred, glowing texture
            {"LogCharred", "log", "burnt_log"},
        };
        StringBuilder sb = new StringBuilder();
        sb.append("/* Generated by Knox Inventory Java/tools/menugen/MenuGen.java - models of the\n")
          .append("   main menu campfire scene. Do not edit by hand. */\n\nmodule KnoxMenu\n{\n");
        for (String[] m : models) {
            sb.append("    model ").append(m[0]).append("\n    {\n        mesh = knoxmenu/").append(m[1])
              .append(",\n        texture = knoxmenu/").append(m[2]).append(",\n        scale = 1.0,\n    }\n\n");
        }
        sb.append("}\n");
        Files.writeString(media.resolve("scripts/knox_menu_models.txt"), sb.toString(), StandardCharsets.US_ASCII);
        System.out.println("scripts/knox_menu_models.txt");
    }

    // ------------------------------------------------------- the winter bar
    // The main menu's second scene (the author, 2026-10-31): a bar in a
    // blizzard, laid out after the approved mockup (.claude/mockups/bar_final.html,
    // variant B: the last ones leaving). Built in metres as the mockup is, written
    // in scene units.

    static final double BAR_U = 1 / 1.22;      // scene units per metre
    static final double BAR_TILE = 1.2;        // metres of wall or floor one texture covers
    static final double BAR_H = 3.2;           // the room's height
    static final double BAR_X0 = -6, BAR_X1 = 6, BAR_Z0 = -8, BAR_Z1 = 3.5;
    static final double BAR_REAR = 4.4;        // where the room ends behind the menu's camera (barRear)
    // the back wall's openings (x0, y0, x1, y1): the boarded window, the smashed one,
    // the door. The side walls have none (the mockup, 2026-10-31).
    static final double[][] BAR_BACK_HOLES = {{-2.2, 0.85, -0.7, 2.5}, {0.6, 0.85, 2.4, 2.5}, {3.3, 0, 4.4, 2.15}};
    // the boards across the boarded window: the light only comes through the gaps. Nailed on in a
    // hurry (the author, 2026-11-01: they stood too even): each its own length, width, tilt and
    // overhang, one across the others. {middle x, middle y, length, width, tilt in degrees, layer}
    static final double[][] BAR_BOARDS = {{-1.49, 0.93, 1.78, 0.15, -3.5, 0}, {-1.39, 1.22, 1.93, 0.19, 4.2, 0},
        {-1.53, 1.51, 1.68, 0.13, -1.6, 0}, {-1.46, 1.86, 1.84, 0.18, -5.2, 0}, {-1.56, 2.18, 1.64, 0.15, 2.6, 0},
        {-1.37, 2.43, 1.87, 0.12, -2.2, 0}, {-1.44, 1.66, 1.92, 0.13, 23, 1}};

    /** Where a nail of a board goes (end -1 or 1, row across its width -1..1), in the wall's plane. */
    static double[] boardNail(double[] b, int end, double row) {
        double a = Math.toRadians(b[4]), along = end * (b[2] / 2 - 0.09), across = row * b[3] * 0.27;
        return new double[] {b[0] + Math.cos(a) * along - Math.sin(a) * across, b[1] + Math.sin(a) * along + Math.cos(a) * across};
    }
    // the cold fire on the floor: its soot is in the floor's texture, KnoxMenuSceneBar puts
    // the fire itself here (the author, 2026-10-31: a little left of the mockup's and nearer)
    // (not further left: its sheet would go under the smoker's table)
    static final double BAR_FIRE_X = -0.3, BAR_FIRE_Z = -5.55;

    static void barScale(Mesh m) {
        for (double[] v : m.verts) {
            v[0] *= BAR_U;
            v[1] *= BAR_U;
            v[2] *= BAR_U;
        }
    }

    /**
     * A wall's inner face in its own XY plane (z = 0, facing +z) from x0 to x1
     * and 0 to h, with rectangular holes {x0, y0, x1, y1}, then moved by xf.
     * Its one texture is spread over the whole wall: u along it, v over the
     * top half of the image (see barBake: which way v runs does not matter).
     */
    static void wallFace(Mesh m, double x0, double x1, double h, double[][] holes, Xf xf) {
        TreeSet<Double> ys = new TreeSet<>();
        ys.add(0.0);
        ys.add(h);
        for (double[] o : holes) {
            ys.add(Math.max(0, o[1]));
            ys.add(Math.min(h, o[3]));
        }
        Double[] y = ys.toArray(new Double[0]);
        for (int b = 0; b + 1 < y.length; b++) {
            double ya = y[b], yb = y[b + 1], mid = (ya + yb) / 2;
            List<double[]> spans = new ArrayList<>();
            spans.add(new double[] {x0, x1});
            for (double[] o : holes) {
                if (mid < o[1] || mid > o[3]) continue;
                List<double[]> next = new ArrayList<>();
                for (double[] s : spans) {
                    if (o[2] <= s[0] || o[0] >= s[1]) {
                        next.add(s);
                        continue;
                    }
                    if (o[0] > s[0]) next.add(new double[] {s[0], o[0]});
                    if (o[2] < s[1]) next.add(new double[] {o[2], s[1]});
                }
                spans = next;
            }
            for (double[] s : spans) {
                double t = Math.floor(s[0] / BAR_TILE) * BAR_TILE;
                for (; t < s[1] - 1e-9; t += BAR_TILE) {
                    double a = Math.max(s[0], t), c = Math.min(s[1], t + BAR_TILE);
                    if (c - a < 1e-6) continue;
                    m.quad(xf.point(a, ya, 0), xf.point(c, ya, 0), xf.point(c, yb, 0), xf.point(a, yb, 0),
                        new double[] {(a - x0) / (x1 - x0), (h - ya) / h * 0.5, (c - x0) / (x1 - x0), (h - yb) / h * 0.5});
                }
            }
        }
    }

    /**
     * The frame round an opening of the back wall, in the wall's own plane (the mockup's):
     * posts, a head, a sill under a window; and the wall's thickness inside the opening,
     * so that it is a hole in a wall and not in a sheet.
     */
    static void barFrame(Mesh m, double[] o, Xf xf) {
        double t = 0.09, w = o[2] - o[0], hh = o[3] + t - o[1], cx = (o[0] + o[2]) / 2;
        m.box(t, hh, 0.06, xf.mul(Xf.move(o[0] - t / 2, o[1] + hh / 2, 0.01)), FULL, FULL);
        m.box(t, hh, 0.06, xf.mul(Xf.move(o[2] + t / 2, o[1] + hh / 2, 0.01)), FULL, FULL);
        m.box(w + 2 * t, t, 0.06, xf.mul(Xf.move(cx, o[3] + t / 2, 0.01)), FULL, FULL);
        if (o[1] > 0) m.box(w + 0.24, 0.05, 0.14, xf.mul(Xf.move(cx, o[1] - 0.025, 0.05)), FULL, FULL);
        double d = 0.3, hy = (o[1] + o[3]) / 2;
        m.box(0.02, o[3] - o[1], d, xf.mul(Xf.move(o[0] - 0.01, hy, -d / 2)), FULL, FULL);
        m.box(0.02, o[3] - o[1], d, xf.mul(Xf.move(o[2] + 0.01, hy, -d / 2)), FULL, FULL);
        m.box(w + 0.04, 0.02, d, xf.mul(Xf.move(cx, o[3] + 0.01, -d / 2)), FULL, FULL);
        if (o[1] > 0) m.box(w + 0.04, 0.02, d, xf.mul(Xf.move(cx, o[1] - 0.01, -d / 2)), FULL, FULL);
    }

    /** The stretches of a..b left when the cuts {from, to} are taken out of it. */
    static List<double[]> barSpans(double a, double b, double[][] cuts) {
        List<double[]> spans = new ArrayList<>();
        spans.add(new double[] {a, b});
        for (double[] c : cuts) {
            List<double[]> next = new ArrayList<>();
            for (double[] s : spans) {
                if (c[1] <= s[0] || c[0] >= s[1]) {
                    next.add(s);
                    continue;
                }
                if (c[0] > s[0]) next.add(new double[] {s[0], c[0]});
                if (c[1] < s[1]) next.add(new double[] {c[1], s[1]});
            }
            spans = next;
        }
        return spans;
    }

    /** Wet steps in from the door, the oldest dried most: x, z, the way they go (x, z), how wet. */
    static double[][] barSteps() {
        double[][] s = new double[9][];
        double dx = -1.3, dz = 3.4, l = Math.hypot(dx, dz);
        for (int i = 0; i < 9; i++) {
            double t = i / 8.0;
            s[i] = new double[] {3.6 - t * 1.3 + (i % 2 == 1 ? 0.12 : -0.12), -7.0 + t * 3.4, dx / l, dz / l, 1 - 0.55 * t};
        }
        return s;
    }

    /**
     * A surface's texture (its light is the shader's, knoxBar.frag): w x hHalf pixels of it in the top
     * half, and the same mirrored top to bottom in the bottom half. Its model
     * takes v from the top half only - read the other way round, v lands in
     * the mirror and shows the same. (Which way the game's v runs was never
     * pinned down: the camp's textures are all the same both ways.)
     * at(u, v) -> {x, y, z, nx, ny, nz, albedo r, g, b} of the surface's point.
     */
    static void barBake(String name, int w, int hHalf, java.util.function.BiFunction<Double, Double, double[]> at)
            throws IOException {
        BufferedImage img = new BufferedImage(w, hHalf * 2, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < hHalf; y++) {
            for (int x = 0; x < w; x++) {
                double[] p = at.apply((x + 0.5) / w, (y + 0.5) / hHalf);
                int c = rgba(p[6], p[7], p[8], 1);
                img.setRGB(x, y, c);
                img.setRGB(x, hHalf * 2 - 1 - y, c);
            }
        }
        save(img, "textures/knoxmenu/" + name + ".png");
    }

    /** Wall boards: vertical 0.2 m boards over a wainscot of horizontal ones up to 0.95 m. */
    static double[] barWallAlbedo(double along, double y, int seed) {
        double k;
        if (y < 0.95) {
            int row = (int) Math.floor(y / 0.16);
            double ly = y / 0.16 - row;
            k = (0.8 + 0.3 * hash(row, seed, 341)) * (0.65 + 0.7 * fbm(along * 3, y * 40, 64, 342 + row, 3));
            if (ly < 0.05 || ly > 0.95) k *= 0.45;
            return new double[] {0.27 * k, 0.18 * k, 0.12 * k};
        }
        int col = (int) Math.floor(along / 0.2);
        double lx = along / 0.2 - col;
        k = (0.85 + 0.3 * hash(col, seed, 301)) * (0.65 + 0.7 * fbm(along * 30, y * 3, 64, 302 + col, 3));
        if (lx < 0.04 || lx > 0.96) k *= 0.4;
        if (hash((int) (along * 60), (int) (y * 60), 303 + seed) > 0.996) k *= 0.55;   // nail holes, knots
        return new double[] {0.36 * k, 0.25 * k, 0.17 * k};
    }

    static void barTextures() throws IOException {
        double h = BAR_H;
        // the back wall: x from X0 to X1, facing +z
        barBake("bar_wall_back", 1024, 256, (u, v) -> {
            double x = BAR_X0 + u * (BAR_X1 - BAR_X0), y = h * (1 - v);
            double[] a = barWallAlbedo(x - BAR_X0, y, 1);
            return new double[] {x, y, BAR_Z0, 0, 0, 1, a[0], a[1], a[2]};
        });
        // the left wall: along it from z = Z1 to Z0, facing +x
        barBake("bar_wall_left", 1024, 256, (u, v) -> {
            double z = BAR_Z1 - u * (BAR_Z1 - BAR_Z0), y = h * (1 - v);
            double[] a = barWallAlbedo(u * (BAR_Z1 - BAR_Z0), y, 2);
            return new double[] {BAR_X0, y, z, 1, 0, 0, a[0], a[1], a[2]};
        });
        // the right wall: from z = Z0 to Z1, facing -x
        barBake("bar_wall_right", 1024, 256, (u, v) -> {
            double z = BAR_Z0 + u * (BAR_Z1 - BAR_Z0), y = h * (1 - v);
            double[] a = barWallAlbedo(u * (BAR_Z1 - BAR_Z0), y, 3);
            return new double[] {BAR_X1, y, z, -1, 0, 0, a[0], a[1], a[2]};
        });
        // the floor: boards along x, 0.15 m, worn; v from the back wall to the front.
        // What the weeks left on it (the mockup, 2026-10-31): soot round the cold fire,
        // wet steps in from the door, the wet where the snow blows in and melts
        double[][] steps = barSteps();
        barBake("bar_floor", 1024, 512, (u, v) -> {
            double x = BAR_X0 + u * (BAR_X1 - BAR_X0), z = BAR_Z0 + v * (BAR_Z1 - BAR_Z0);
            int row = (int) Math.floor((z - BAR_Z0) / 0.15);
            double lz = (z - BAR_Z0) / 0.15 - row;
            double k = (0.8 + 0.35 * hash(0, row, 311)) * (0.6 + 0.8 * fbm(x * 2, z * 30, 64, 312 + row, 3));
            if (lz < 0.06 || lz > 0.94) k *= 0.35;
            double cut = BAR_X0 + hash(row, 1, 313) * 3.0;           // boards 3 m long, ends staggered
            if (Math.abs(((x - cut) % 3.0 + 3.0) % 3.0) < 0.012) k *= 0.4;
            // worn paler where people walk: along the counter and to the door
            double worn = smooth(1.4, 0.0, Math.abs(z + 0.4)) * 0.25
                + smooth(1.2, 0.0, Math.abs(x - 3.85)) * smooth(-3.0, -7.6, z) * 0.2;
            k *= 1 + worn;
            double fire = Math.hypot(x - BAR_FIRE_X, (z - BAR_FIRE_Z) * 1.15);
            k *= 1 - 0.82 * smooth(1.25, 0.4, fire) * (0.7 + 0.3 * fbm(x * 2.5, z * 2.5, 64, 314, 3));
            double wet = 0;
            for (double[] s : steps) {
                double dx = x - s[0], dz = z - s[1];
                double a = (dx * s[2] + dz * s[3]) / 0.15, b = (dz * s[2] - dx * s[3]) / 0.065;
                wet = Math.max(wet, s[4] * smooth(1.0, 0.55, a * a + b * b));
            }
            wet = Math.max(wet, 0.8 * smooth(1.0, 0.45, Math.hypot((x - 3.75) / 1.5, (z + 7.3) / 1.35)));
            wet = Math.max(wet, 0.7 * smooth(1.0, 0.4, Math.hypot((x - 1.5) / 1.2, (z + 7.75) / 0.85)));
            wet *= 0.85 + 0.15 * fbm(x * 6, z * 6, 64, 315, 2);
            k *= 1 - 0.45 * wet;
            return new double[] {x, 0, z, 0, 1, 0, 0.30 * k * (1 - 0.12 * wet), 0.21 * k, 0.14 * k * (1 + 0.1 * wet)};
        });
        // the ceiling: dark planks along x
        barBake("bar_ceiling", 512, 256, (u, v) -> {
            double x = BAR_X0 + u * (BAR_X1 - BAR_X0), z = BAR_Z0 + v * (BAR_Z1 - BAR_Z0);
            int row = (int) Math.floor((z - BAR_Z0) / 0.25);
            double lz = (z - BAR_Z0) / 0.25 - row;
            double k = (0.8 + 0.3 * hash(0, row, 351)) * (0.7 + 0.6 * fbm(x * 2, z * 20, 64, 352, 3));
            if (lz < 0.05 || lz > 0.95) k *= 0.5;
            return new double[] {x, h, z, 0, -1, 0, 0.20 * k, 0.14 * k, 0.10 * k};
        });
        // varnished wood of the counter and the tables: warmer, smoother
        int n = 256;
        BufferedImage img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double grain = fbm(x / 70.0, y / 6.0, 16, 321, 4);
                double k = 0.75 + 0.5 * grain;
                img.setRGB(x, y, rgba(0.46 * k, 0.29 * k, 0.15 * k, 1));
            }
        }
        save(img, "textures/knoxmenu/bar_varnish.png");
        // dark wood: beams, trims, frames, the counter's front
        img = new BufferedImage(n, n, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double grain = fbm(x / 6.0, y / 50.0, 16, 331, 3);
                double k = 0.7 + 0.6 * grain;
                img.setRGB(x, y, rgba(0.17 * k, 0.11 * k, 0.07 * k, 1));
            }
        }
        save(img, "textures/knoxmenu/bar_dark.png");
    }

    static void barMeshes() throws IOException {
        double h = BAR_H;
        // walls (inner faces only: the camera is always inside), each with its own
        // texture and light (barTextures)
        Mesh wall = new Mesh();
        wallFace(wall, BAR_X0, BAR_X1, h, BAR_BACK_HOLES, Xf.move(0, 0, BAR_Z0));
        barScale(wall);
        wall.write("bar_wall_back");
        // the left wall's own x runs to -z (rotY 90), the right one's to +z (rotY -90)
        wall = new Mesh();
        wallFace(wall, -BAR_Z1, -BAR_Z0, h, new double[0][], Xf.move(BAR_X0, 0, 0).mul(Xf.rotY(90)));
        barScale(wall);
        wall.write("bar_wall_left");
        wall = new Mesh();
        wallFace(wall, BAR_Z0, BAR_Z1, h, new double[0][], Xf.move(BAR_X1, 0, 0).mul(Xf.rotY(-90)));
        barScale(wall);
        wall.write("bar_wall_right");

        // the floor and the ceiling, in tiles (one texture over the whole, v in its top half)
        Mesh floor = new Mesh();
        Mesh ceil = new Mesh();
        double lx = BAR_X1 - BAR_X0, lz = BAR_Z1 - BAR_Z0;
        for (double x = BAR_X0; x < BAR_X1 - 1e-9; x += BAR_TILE) {
            for (double z = BAR_Z0; z < BAR_Z1 - 1e-9; z += BAR_TILE) {
                double x1 = Math.min(BAR_X1, x + BAR_TILE), z1 = Math.min(BAR_Z1, z + BAR_TILE);
                double u0 = (x - BAR_X0) / lx, u1 = (x1 - BAR_X0) / lx;
                double v0 = (z - BAR_Z0) / lz * 0.5, v1 = (z1 - BAR_Z0) / lz * 0.5;
                floor.quad(new double[] {x, 0, z1}, new double[] {x1, 0, z1}, new double[] {x1, 0, z}, new double[] {x, 0, z},
                    new double[] {u0, v1, u1, v0});
                ceil.quad(new double[] {x, h, z}, new double[] {x1, h, z}, new double[] {x1, h, z1}, new double[] {x, h, z1},
                    new double[] {u0, v0, u1, v1});
            }
        }
        barScale(floor);
        floor.write("bar_floor");
        barScale(ceil);
        ceil.write("bar_ceiling");

        // dark wood: beams under the ceiling across the room (the mockup's), the
        // wainscot's rail and the skirting, the frames round the openings
        Mesh trim = new Mesh();
        for (double z : new double[] {-6.2, -3.6, -1.0, 1.6}) {
            trim.box(BAR_X1 - BAR_X0, 0.24, 0.22, Xf.move(0, h - 0.12, z), FULL, FULL);
        }
        Xf back = Xf.move(0, 0, BAR_Z0);
        Xf left = Xf.move(BAR_X0, 0, 0).mul(Xf.rotY(90));
        Xf right = Xf.move(BAR_X1, 0, 0).mul(Xf.rotY(-90));
        double[][] windows = new double[2][], door = {{BAR_BACK_HOLES[2][0] - 0.09, BAR_BACK_HOLES[2][2] + 0.09}};
        for (int i = 0; i < 2; i++) windows[i] = new double[] {BAR_BACK_HOLES[i][0] - 0.12, BAR_BACK_HOLES[i][2] + 0.12};
        double[][] railCuts = {windows[0], windows[1], door[0]};
        for (double[] s : barSpans(BAR_X0, BAR_X1, railCuts)) {
            trim.box(s[1] - s[0], 0.06, 0.08, back.mul(Xf.move((s[0] + s[1]) / 2, 0.97, 0.04)), FULL, FULL);
        }
        for (double[] s : barSpans(BAR_X0, BAR_X1, door)) {
            trim.box(s[1] - s[0], 0.12, 0.03, back.mul(Xf.move((s[0] + s[1]) / 2, 0.06, 0.015)), FULL, FULL);
        }
        for (Xf side : new Xf[] {left, right}) {
            double a = side == left ? -BAR_Z1 : BAR_Z0, b = side == left ? -BAR_Z0 : BAR_Z1;
            trim.box(b - a, 0.06, 0.08, side.mul(Xf.move((a + b) / 2, 0.97, 0.04)), FULL, FULL);
            trim.box(b - a, 0.12, 0.03, side.mul(Xf.move((a + b) / 2, 0.06, 0.015)), FULL, FULL);
        }
        for (double[] o : BAR_BACK_HOLES) barFrame(trim, o, back);
        barScale(trim);
        trim.write("bar_trim");

        // the boards across the boarded window (the camp's planks), nailed on crooked (BAR_BOARDS)
        Mesh boards = new Mesh();
        Random rnd = new Random(401);
        for (double[] r : BAR_BOARDS) {
            boards.box(r[2], r[3], 0.035, back.mul(Xf.move(r[0], r[1], 0.0675 + r[5] * 0.036)).mul(Xf.rotZ(r[4])),
                plank(rnd.nextInt(4)), plank(4 + rnd.nextInt(4)));
        }
        barScale(boards);
        boards.write("bar_boards");

        // the counter: its body (dark) and its top (varnished), along x; the
        // heroes sit on its far side (-z), the camera is on the barman's. Made
        // round its own middle on the floor (it is shaded by where it stands:
        // KnoxMenuBar puts it at x 0.2, z 0.83)
        Mesh body = new Mesh();
        body.box(7.0, 1.04, 0.5, Xf.move(0, 0.52, 0), FULL, FULL);
        barScale(body);
        body.write("bar_counter");
        Mesh top = new Mesh();
        top.box(7.2, 0.06, 0.68, Xf.move(0, 1.07, -0.01), FULL, FULL);
        barScale(top);
        top.write("bar_counter_top");
        barRear();
    }

    /**
     * The room closed behind the menu's camera, for the walk about the bar (the author, 2026-11-04):
     * a draft until the real fourth wall. Pieces of their own, the old ones and what the menu shows
     * stay as they are; the textures go on as in a mirror from the room's edge.
     */
    static void barRear() throws IOException {
        double h = BAR_H, lx = BAR_X1 - BAR_X0, lz = BAR_Z1 - BAR_Z0;
        Mesh floor = new Mesh(), ceil = new Mesh();
        for (double x = BAR_X0; x < BAR_X1 - 1e-9; x += BAR_TILE) {
            double x1 = Math.min(BAR_X1, x + BAR_TILE), u0 = (x - BAR_X0) / lx, u1 = (x1 - BAR_X0) / lx;
            double v0 = 0.5, v1 = (BAR_Z1 + BAR_Z1 - BAR_REAR - BAR_Z0) / lz * 0.5;
            floor.quad(new double[] {x, 0, BAR_REAR}, new double[] {x1, 0, BAR_REAR}, new double[] {x1, 0, BAR_Z1}, new double[] {x, 0, BAR_Z1},
                new double[] {u0, v1, u1, v0});
            ceil.quad(new double[] {x, h, BAR_Z1}, new double[] {x1, h, BAR_Z1}, new double[] {x1, h, BAR_REAR}, new double[] {x, h, BAR_REAR},
                new double[] {u0, v0, u1, v1});
        }
        barScale(floor);
        floor.write("bar_rear_floor");
        barScale(ceil);
        ceil.write("bar_rear_ceiling");

        double du = (BAR_REAR - BAR_Z1) / lz;
        Xf left = Xf.move(BAR_X0, 0, 0).mul(Xf.rotY(90)), right = Xf.move(BAR_X1, 0, 0).mul(Xf.rotY(-90));
        Xf rear = Xf.move(0, 0, BAR_REAR).mul(Xf.rotY(180));
        Mesh wall = new Mesh();
        wall.quad(left.point(-BAR_REAR, 0, 0), left.point(-BAR_Z1, 0, 0), left.point(-BAR_Z1, h, 0), left.point(-BAR_REAR, h, 0),
            new double[] {du, 0.5, 0, 0});
        barScale(wall);
        wall.write("bar_rear_left");
        wall = new Mesh();
        wall.quad(right.point(BAR_Z1, 0, 0), right.point(BAR_REAR, 0, 0), right.point(BAR_REAR, h, 0), right.point(BAR_Z1, h, 0),
            new double[] {1, 0.5, 1 - du, 0});
        barScale(wall);
        wall.write("bar_rear_right");
        wall = new Mesh();
        wallFace(wall, BAR_X0, BAR_X1, h, new double[0][], rear);
        barScale(wall);
        wall.write("bar_rear_wall");

        Mesh trim = new Mesh();
        double along = BAR_REAR - BAR_Z1;
        trim.box(along, 0.06, 0.08, left.mul(Xf.move(-(BAR_REAR + BAR_Z1) / 2, 0.97, 0.04)), FULL, FULL);
        trim.box(along, 0.12, 0.03, left.mul(Xf.move(-(BAR_REAR + BAR_Z1) / 2, 0.06, 0.015)), FULL, FULL);
        trim.box(along, 0.06, 0.08, right.mul(Xf.move((BAR_REAR + BAR_Z1) / 2, 0.97, 0.04)), FULL, FULL);
        trim.box(along, 0.12, 0.03, right.mul(Xf.move((BAR_REAR + BAR_Z1) / 2, 0.06, 0.015)), FULL, FULL);
        trim.box(lx, 0.06, 0.08, rear.mul(Xf.move(0, 0.97, 0.04)), FULL, FULL);
        trim.box(lx, 0.12, 0.03, rear.mul(Xf.move(0, 0.06, 0.015)), FULL, FULL);
        barScale(trim);
        trim.write("bar_rear_trim");
    }

    // ------------------------------------------------- the bar's furniture and things
    // Stage 2 (the list the author approved, 2026-10-31). Everything small shares
    // one sheet (bar_atlas) and is merged into a model per corner of the room: a
    // model is lit as a whole from where it stands, so what stands together is
    // one model - forty models, not four hundred. Each is made round its own
    // place on the floor; KnoxMenuBar: PROPS puts it there.

    static final int BA = 2048;   // the sheet's side; v only in its top half, as barBake (the author, 2026-11-01: 1024 was full)
    // materials: a row of small flat patches at the sheet's top
    static final double[][] BAR_MATS = {
        {0.46, 0.29, 0.15}, {0.17, 0.11, 0.07}, {0.70, 0.55, 0.22}, {0.38, 0.38, 0.40}, {0.09, 0.09, 0.10},   // varnish, dark, brass, metal, iron
        {0.72, 0.74, 0.76}, {0.10, 0.30, 0.13}, {0.30, 0.15, 0.05}, {0.78, 0.50, 0.10}, {0.94, 0.89, 0.78},   // chrome, green glass, brown glass, beer, foam
        {0.58, 0.67, 0.70}, {0.86, 0.81, 0.69}, {0.76, 0.71, 0.60}, {0.42, 0.15, 0.12}, {0.17, 0.17, 0.17},   // glass, paper, towel, red leather, ash
        {0.05, 0.05, 0.05}, {0.33, 0.22, 0.14}, {0.62, 0.48, 0.30}, {0.50, 0.10, 0.08}, {0.62, 0.62, 0.60},   // coal, bark, cut wood, canister, tin
        {0.86, 0.91, 0.98}, {0.23, 0.29, 0.35}, {0.03, 0.03, 0.03}, {0.90, 0.85, 0.72}, {0.35, 0.28, 0.20},   // snow, jacket, black, wax, glove
        {0.72, 0.66, 0.54}, {0.42, 0.31, 0.20}, {0.85, 0.84, 0.80}, {1.00, 0.72, 0.36}, {0.95, 0.20, 0.16},   // antler, plank, plate, flame, red bulb
        {0.20, 0.85, 0.35}, {1.00, 0.80, 0.25}, {0.25, 0.50, 1.00}, {0.16, 0.26, 0.17}, {1.00, 0.86, 0.62},   // green bulb, yellow bulb, blue bulb, lamp shade, lit bulb
        {0.34, 0.54, 0.38}, {0.60, 0.42, 0.25}, {0.33, 0.33, 0.28}, {0.36, 0.20, 0.11}, {0.46, 0.22, 0.15},   // green glass empty, brown glass empty, wool, rust, brick
        {0.21, 0.12, 0.07}, {0.80, 0.88, 0.95}, {0.52, 0.40, 0.26}, {0.25, 0.27, 0.17}, {0.10, 0.30, 0.16},   // bakelite, ice, cardboard, olive, circuit board
        {0.66, 0.38, 0.20}, {0.58, 0.10, 0.07}, {0.55, 0.30, 0.10},                                          // copper, red wire, amber glass
        {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06},   // (the first rows' ends, unused)
        {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06}, {0.06, 0.06, 0.06},
        {0.80, 0.55, 0.20}, {0.60, 0.09, 0.08}, {0.24, 0.46, 0.36}, {0.86, 0.79, 0.62}, {0.36, 0.45, 0.40}, {0.52, 0.53, 0.53},   // gold, red plastic, the jukebox's green, cream, its well, steel
    };
    static final int M_VARNISH = 0, M_DARK = 1, M_BRASS = 2, M_METAL = 3, M_IRON = 4, M_CHROME = 5, M_GREEN = 6, M_BROWN = 7,
        M_BEER = 8, M_FOAM = 9, M_GLASS = 10, M_PAPER = 11, M_TOWEL = 12, M_LEATHER = 13, M_ASH = 14, M_COAL = 15, M_BARK = 16,
        M_CUT = 17, M_CANISTER = 18, M_TIN = 19, M_SNOW = 20, M_JACKET = 21, M_BLACK = 22, M_WAX = 23, M_GLOVE = 24, M_ANTLER = 25,
        M_PLANK = 26, M_PLATE = 27, M_FLAME = 28, M_BRED = 29, M_BGREEN = 30, M_BYELLOW = 31, M_BBLUE = 32, M_SHADE = 33, M_LIT = 34, M_GREEN_E = 35, M_BROWN_E = 36,
        M_WOOL = 37, M_RUST = 38, M_BRICK = 39, M_BAKELITE = 40, M_ICE = 41, M_CARDBOARD = 42, M_OLIVE = 43, M_PCB = 44, M_COPPER = 45,
        M_WRED = 46, M_AMBER = 47, M_GOLD = 58, M_JRED = 59, M_JGREEN = 60, M_CREAM = 61, M_WELL = 62, M_STEEL = 63;

    /** A picture on the sheet, upright on a face whose first corner is its bottom left. */
    static double[] barCell(int x, int y, int w, int h) {
        double m = 1.0;
        return new double[] {(x + m) / BA, (y + h - m) / BA, (x + w - m) / BA, (y + m) / BA};
    }

    /** The material's patch: the first 48 at the sheet's top left, the rest on the right of it. */
    static int matX(int i) {
        return i < 48 ? (i % 24) * 32 : 1024 + ((i - 48) % 24) * 32;
    }

    static int matY(int i) {
        return i < 48 ? (i / 24) * 32 : ((i - 48) / 24) * 32;
    }

    static double[] barMat(int i) {
        int x = matX(i), y = matY(i);
        return new double[] {(x + 6.0) / BA, (y + 26.0) / BA, (x + 26.0) / BA, (y + 6.0) / BA};
    }

    // the pictures on the sheet, under the materials (x, y, w, h). (2026-10-31, the mockup of
    // the last ones leaving: the neon, the posters, the dartboard, the till, the TV, the
    // towel and the frosted panes went with the warm bar; the note, the mattress, the
    // radio's front, the tally of days, the map, the ammo, the cardboard and the compass came.)
    static final int[] P_LABEL_BEER = {0, 64, 128, 96}, P_LABEL_WHISKEY = {128, 64, 128, 96}, P_CAN = {256, 64, 128, 96},
        P_CAN_SOUP = {256, 288, 128, 96}, P_CAN_PEACHES = {256, 384, 128, 96}, P_CAN_CORN = {640, 352, 128, 96}, P_CAN_TUNA = {768, 352, 128, 96},
        P_CIGS = {384, 64, 64, 96}, P_CARD_BACK = {448, 64, 48, 64}, P_CARD_ACE = {496, 64, 48, 64}, P_CARD_SEVEN = {544, 64, 48, 64},
        P_NEWS = {592, 64, 128, 96}, P_CLOCK = {720, 64, 128, 128},
        P_NOTE = {0, 192, 128, 96}, P_TICKING = {128, 192, 128, 96}, P_RADIO = {256, 192, 96, 96},
        P_TALLY = {384, 192, 192, 128}, P_MAP = {384, 320, 192, 144},
        P_MISSING = {640, 192, 256, 64}, P_SHEET = {896, 192, 96, 128}, P_AMMO = {640, 256, 128, 96},
        P_JSIDE = {1024, 64, 256, 256}, P_JTITLES = {1280, 64, 256, 128}, P_JPANEL = {1024, 320, 256, 192},
        P_WGOLD = {1024, 512, 512, 64}, P_WCHROME = {1024, 576, 512, 64}, P_WRED = {1024, 640, 512, 64}, P_WGREEN = {1024, 704, 512, 64}, P_WSTEEL = {1024, 768, 512, 64},
        P_JCLOTH = {1536, 512, 256, 256}, P_WENAMEL = {1024, 832, 512, 64}, P_AIDFRONT = {1280, 200, 256, 128},
        P_JOURNAL = {1536, 768, 512, 256}, P_BANDAGE = {1536, 200, 256, 64}, P_AIDNOTE = {1536, 264, 128, 96}, P_CARDBOARD = {768, 256, 128, 96}, P_COMPASS = {896, 320, 64, 64};

    // the cigarette machine's (the author, 2026-11-02)
    static final int[] P_CIGHEAD = {0, 520, 512, 128}, P_CIGBODY = {0, 648, 256, 256}, P_CIGPACKS = {256, 648, 512, 96},
        P_CIGPLATE = {256, 744, 128, 192}, P_CIGSIGN = {384, 744, 256, 96}, P_CIGTAGS = {384, 840, 256, 32}, P_CIGNOTE = {384, 872, 128, 64},
        P_CIGTRIM = {512, 520, 512, 64};
    // what hangs on the wall by the left window (the author, 2026-11-02)
    static final int[] P_FLAG = {768, 584, 256, 144}, P_PHOTO1 = {1792, 64, 256, 192}, P_PHOTO2 = {1792, 256, 256, 192},
        P_PHOTO3 = {1792, 448, 256, 192}, P_CALENDAR = {512, 872, 128, 152}, P_PLATE = {768, 952, 128, 64};
    // the supplies' cartons, sack and boxes (the author, 2026-11-02)
    static final int[] P_BOXCANS = {768, 824, 128, 128}, P_BOXWATER = {896, 824, 128, 128}, P_SACK = {640, 840, 128, 128},
        P_CRATE = {768, 728, 128, 96}, P_AMMOBOX = {896, 728, 128, 96}, P_BOXRICE = {640, 744, 128, 96};

    static double[] barPic(int[] p) {
        return barCell(p[0], p[1], p[2], p[3]);
    }

    static void centred(java.awt.Graphics2D g, String s, int cx, int y) {
        g.drawString(s, cx - g.getFontMetrics().stringWidth(s) / 2, y);
    }

    // The heading of the wall of the missing written by hand in marker (the author, 2026-11-02: the
    // printed one read as stamped; variant A of the mockup, no line under): each stroke's points, x y
    // in pixels from the cell's top left, the letters uneven and the line going down to the right.
    static final double[][] MISSING_HAND = {
        {26.9, 51.4, 26.6, 10.2, 37.2, 36.7, 48.5, 10.7, 49.6, 52.9},
        {65.6, 10.1, 65.5, 49.3},
        {92.9, 17.1, 89.2, 12.4, 81.9, 14.2, 79.4, 23.0, 83.2, 30.9, 89.8, 34.1, 93.8, 45.0, 90.8, 51.2, 85.5, 53.3, 80.1, 47.4},
        {121.9, 20.7, 117.1, 15.3, 111.2, 17.6, 107.8, 26.5, 111.8, 34.9, 119.5, 37.0, 123.2, 45.8, 118.9, 54.1, 114.2, 55.5, 109.3, 48.8},
        {136.2, 14.1, 136.3, 56.1},
        {153.2, 56.0, 153.7, 14.7, 172.8, 54.5, 171.5, 13.6},
        {203.4, 24.7, 197.1, 19.9, 191.2, 21.2, 186.2, 35.5, 189.6, 49.3, 196.1, 58.4, 202.4, 52.7, 203.6, 42.4, 195.9, 41.2},
    };

    /** Strokes as a hand draws them: a soft curve through each one's points (as GDI+'s, tension 0.4), round ends. */
    static void barHandWord(java.awt.Graphics2D g, double[][] strokes, double x, double y, float width) {
        Object aa = g.getRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING);
        java.awt.Stroke was = g.getStroke();
        g.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING, java.awt.RenderingHints.VALUE_ANTIALIAS_ON);
        g.setStroke(new java.awt.BasicStroke(width, java.awt.BasicStroke.CAP_ROUND, java.awt.BasicStroke.JOIN_ROUND));
        double t = 0.4 / 3;
        for (double[] s : strokes) {
            int n = s.length / 2;
            java.awt.geom.Path2D.Double p = new java.awt.geom.Path2D.Double();
            p.moveTo(x + s[0], y + s[1]);
            for (int i = 0; i < n - 1; i++) {
                int a = Math.max(0, i - 1), d = Math.min(n - 1, i + 2);
                p.curveTo(x + s[2 * i] + t * (s[2 * (i + 1)] - s[2 * a]), y + s[2 * i + 1] + t * (s[2 * (i + 1) + 1] - s[2 * a + 1]),
                    x + s[2 * (i + 1)] - t * (s[2 * d] - s[2 * i]), y + s[2 * (i + 1) + 1] - t * (s[2 * d + 1] - s[2 * i + 1]),
                    x + s[2 * (i + 1)], y + s[2 * (i + 1) + 1]);
            }
            g.draw(p);
        }
        g.setStroke(was);
        g.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING, aa);
    }

    /** A can's label: the tin above and below, the band with the name, as the beans'. */
    static void canLabel(java.awt.Graphics2D g, int[] p, java.awt.Color band, java.awt.Color ink, String name) {
        g.setColor(new java.awt.Color(190, 185, 170));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(band);
        g.fillRect(p[0], p[1] + 16, p[2], 64);
        g.setColor(ink);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, name.length() > 5 ? 20 : 24));
        centred(g, name, p[0] + p[2] / 2, p[1] + 57);
    }

    /** A carton's side: kraft, its tape, what is in it printed big and a line under. */
    static void cartonSide(java.awt.Graphics2D g, Random r, int[] p, java.awt.Color inkCol, String name, String under) {
        g.setColor(new java.awt.Color(150, 112, 70));
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 26; i++) {
            g.setColor(new java.awt.Color(116 + r.nextInt(30), 84 + r.nextInt(24), 50, 60));
            g.fillRect(p[0], p[1] + r.nextInt(p[3]), p[2], 1 + r.nextInt(2));
        }
        g.setColor(new java.awt.Color(186, 164, 120));
        g.fillRect(p[0] + p[2] / 2 - 9, p[1], 18, 14);
        g.setColor(inkCol);
        g.setStroke(new java.awt.BasicStroke(3));
        g.drawRect(p[0] + 8, p[1] + 20, p[2] - 17, p[3] - 34);
        g.setStroke(new java.awt.BasicStroke(1));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, name.length() > 6 ? 19 : 26));
        centred(g, name, p[0] + p[2] / 2, p[1] + p[3] / 2 + 6);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 11));
        centred(g, under, p[0] + p[2] / 2, p[1] + p[3] - 24);
    }

    /** What the stockpile by the flag is printed with. */
    static void barAtlasSupplies(java.awt.Graphics2D g) {
        Random r = new Random(21);
        java.awt.Color black = new java.awt.Color(36, 28, 22);
        cartonSide(g, r, P_BOXCANS, black, "CANNED", "24 CANS  KEEP DRY");
        cartonSide(g, r, P_BOXWATER, new java.awt.Color(30, 56, 104), "WATER", "12 x 1 QT");
        cartonSide(g, r, P_BOXRICE, new java.awt.Color(120, 34, 28), "RICE", "20 LB");
        // the sack: burlap's weave, the mill's print
        int[] p = P_SACK;
        g.setColor(new java.awt.Color(152, 130, 94));
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < p[2]; i += 3) {
            g.setColor(new java.awt.Color(120 + r.nextInt(24), 102, 70, 90));
            g.fillRect(p[0] + i, p[1], 1, p[3]);
            g.fillRect(p[0], p[1] + i, p[2], 1);
        }
        g.setColor(new java.awt.Color(58, 44, 34));
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD, 26));
        centred(g, "FLOUR", p[0] + 64, p[1] + 68);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 13));
        centred(g, "50 LB", p[0] + 64, p[1] + 88);
        // the crate: its boards, the stencil
        p = P_CRATE;
        g.setColor(new java.awt.Color(116, 86, 54));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(new java.awt.Color(62, 44, 28));
        for (int i = 1; i < 4; i++) g.fillRect(p[0], p[1] + i * 24, p[2], 2);
        g.setColor(new java.awt.Color(34, 28, 22));
        g.setFont(new java.awt.Font("Monospaced", java.awt.Font.BOLD, 24));
        centred(g, "FOOD", p[0] + 64, p[1] + 44);
        g.setFont(new java.awt.Font("Monospaced", java.awt.Font.BOLD, 12));
        centred(g, "RELIEF - KY", p[0] + 64, p[1] + 66);
        // the ammunition's box
        p = P_AMMOBOX;
        g.setColor(new java.awt.Color(64, 72, 44));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(new java.awt.Color(208, 196, 130));
        g.setFont(new java.awt.Font("Monospaced", java.awt.Font.BOLD, 16));
        centred(g, ".308 CAL", p[0] + 64, p[1] + 46);
        g.setFont(new java.awt.Font("Monospaced", java.awt.Font.BOLD, 11));
        centred(g, "200 CARTRIDGES", p[0] + 64, p[1] + 64);
    }

    static void barAtlas() throws IOException {
        BufferedImage img = new BufferedImage(BA, BA, BufferedImage.TYPE_INT_ARGB);
        // the materials, a little uneven
        for (int i = 0; i < BAR_MATS.length; i++) {
            int ox = matX(i), oy = matY(i);
            double[] c = BAR_MATS[i];
            for (int y = 0; y < 32; y++) {
                for (int x = 0; x < 32; x++) {
                    double k = i >= M_FLAME && i <= M_LIT ? 1 : 0.97 + 0.06 * hash(ox + x, oy + y, 361);
                    img.setRGB(ox + x, oy + y, rgba(c[0] * k, c[1] * k, c[2] * k, 1));
                }
            }
        }
        java.awt.Graphics2D g = img.createGraphics();
        g.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING, java.awt.RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(java.awt.RenderingHints.KEY_TEXT_ANTIALIASING, java.awt.RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        java.awt.Color ink = new java.awt.Color(30, 24, 18), cream = new java.awt.Color(226, 214, 186);

        // the beer's label
        g.setColor(cream);
        g.fillRect(0, 64, 128, 96);
        g.setColor(new java.awt.Color(150, 40, 30));
        g.fillRect(0, 76, 128, 44);
        g.setColor(cream);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD, 32));
        centred(g, "KNOX", 64, 110);
        g.setColor(ink);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 15));
        centred(g, "LAGER", 64, 140);
        // the whiskey's
        g.setColor(new java.awt.Color(214, 190, 140));
        g.fillRect(128, 64, 128, 96);
        g.setColor(ink);
        g.drawRect(134, 70, 115, 83);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD, 23));
        centred(g, "OLD", 192, 98);
        centred(g, "KENTUCKY", 192, 122);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.PLAIN, 13));
        centred(g, "straight whiskey", 192, 144);
        // a can
        g.setColor(new java.awt.Color(170, 165, 150));
        g.fillRect(256, 64, 128, 96);
        g.setColor(new java.awt.Color(165, 60, 30));
        g.fillRect(256, 80, 128, 64);
        g.setColor(cream);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 24));
        centred(g, "BEANS", 320, 121);
        // the others on the shelf (the author, 2026-11-01: not all the same can)
        canLabel(g, P_CAN_SOUP, new java.awt.Color(214, 205, 180), new java.awt.Color(150, 30, 26), "SOUP");
        canLabel(g, P_CAN_PEACHES, new java.awt.Color(222, 138, 52), new java.awt.Color(64, 34, 16), "PEACHES");
        canLabel(g, P_CAN_CORN, new java.awt.Color(46, 96, 52), new java.awt.Color(236, 202, 84), "CORN");
        canLabel(g, P_CAN_TUNA, new java.awt.Color(36, 70, 118), new java.awt.Color(225, 225, 215), "TUNA");
        // a pack of cigarettes
        g.setColor(new java.awt.Color(190, 185, 170));
        g.fillRect(384, 64, 64, 96);
        g.setColor(new java.awt.Color(130, 30, 28));
        g.fillOval(392, 90, 48, 48);
        g.setColor(cream);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD, 13));
        centred(g, "RED", 416, 119);
        // cards
        g.setColor(new java.awt.Color(120, 40, 36));
        g.fillRect(448, 64, 48, 64);
        g.setColor(cream);
        g.drawRect(452, 68, 39, 55);
        for (int[] c : new int[][] {{496, 0}, {544, 1}}) {
            g.setColor(new java.awt.Color(232, 226, 210));
            g.fillRect(c[0], 64, 48, 64);
            g.setColor(c[1] == 0 ? ink : new java.awt.Color(160, 30, 28));
            g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD, 26));
            centred(g, c[1] == 0 ? "A" : "7", c[0] + 24, 106);
        }
        // the newspaper: a headline and grey columns
        g.setColor(new java.awt.Color(196, 190, 170));
        g.fillRect(592, 64, 128, 96);
        g.setColor(ink);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD, 15));
        centred(g, "KNOX COUNTY", 656, 80);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD, 13));
        centred(g, "QUARANTINE", 656, 95);
        g.setColor(new java.awt.Color(90, 88, 80));
        for (int c = 0; c < 3; c++) {
            for (int l = 0; l < 7; l++) g.fillRect(598 + c * 40, 102 + l * 8, 36, 3);
        }
        // the clock, stopped
        g.setColor(new java.awt.Color(40, 28, 20));
        g.fillRect(720, 64, 128, 128);
        g.setColor(new java.awt.Color(214, 204, 178));
        g.fillOval(726, 70, 116, 116);
        g.setColor(ink);
        g.setStroke(new java.awt.BasicStroke(3));
        for (int i = 0; i < 12; i++) {
            double a = i * Math.PI / 6;
            g.drawLine((int) (784 + 44 * Math.sin(a)), (int) (128 - 44 * Math.cos(a)), (int) (784 + 52 * Math.sin(a)), (int) (128 - 52 * Math.cos(a)));
        }
        g.setStroke(new java.awt.BasicStroke(5));
        g.drawLine(784, 128, 806, 142);    // twenty to four
        g.setStroke(new java.awt.BasicStroke(3));
        g.drawLine(784, 128, 744, 105);
        // the wall of the missing: its heading and a sheet with a photo
        g.setColor(new java.awt.Color(228, 222, 204));
        g.fillRect(640, 192, 256, 64);
        g.setColor(new java.awt.Color(24, 20, 18));
        barHandWord(g, MISSING_HAND, 640 + 13, 192 - 2, 7f);
        g.setColor(new java.awt.Color(224, 218, 200));
        g.fillRect(896, 192, 96, 128);
        g.setColor(new java.awt.Color(52, 46, 42));
        g.fillRect(906, 202, 76, 74);
        g.setColor(new java.awt.Color(120, 110, 100));
        g.fillOval(930, 214, 28, 32);
        g.fillRoundRect(918, 248, 52, 28, 12, 12);
        g.setColor(new java.awt.Color(80, 76, 70));
        for (int l = 0; l < 3; l++) g.fillRect(906, 286 + l * 10, l == 2 ? 44 : 76, 4);
        barAtlasLeaving(img, g, ink, cream);
        barAtlasJuke(g, ink);
        barAtlasAid(g, ink);
        barAtlasJournal(g);
        barAtlasCig(g, ink);
        barAtlasWall(g, ink);
        barAtlasSupplies(g);
        barAtlasSawSet(img, g);
        g.dispose();
        // the same mirrored in the bottom half (see barBake)
        for (int y = 0; y < BA / 2; y++) {
            for (int x = 0; x < BA; x++) img.setRGB(x, BA - 1 - y, img.getRGB(x, y));
        }
        save(img, "textures/knoxmenu/bar_atlas.png");
    }

    /** The new jukebox's pictures (the author, 2026-11-01), in the game's colours: its steel sides, the mottled panel, the song cards. */
    static void barAtlasJuke(java.awt.Graphics2D g, java.awt.Color ink) {
        Random r = new Random(1015);
        int[] p = P_JSIDE;
        g.setPaint(new java.awt.GradientPaint(0, p[1], new java.awt.Color(60, 62, 68), 0, p[1] + p[3], new java.awt.Color(34, 34, 37)));
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 260; i++) {   // rubbed and scratched
            int x = p[0] + r.nextInt(p[2]), y = p[1] + r.nextInt(p[3]);
            g.setColor(r.nextBoolean() ? new java.awt.Color(120, 120, 124, 30 + r.nextInt(50)) : new java.awt.Color(14, 12, 12, 40 + r.nextInt(70)));
            g.drawLine(x, y, Math.min(p[0] + p[2] - 1, x + r.nextInt(9) - 4), Math.min(p[1] + p[3] - 1, y + r.nextInt(30)));
        }
        p = P_JPANEL;
        g.setColor(new java.awt.Color(50, 78, 63));   // (the green of the arch: brighter, it stood out; the author, 2026-11-01)
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 700; i++) {   // the plastic's marbling
            int x = p[0] + r.nextInt(p[2] - 24), y = p[1] + r.nextInt(p[3] - 24), w = 4 + r.nextInt(20), h = 3 + r.nextInt(14);
            g.setColor(r.nextBoolean() ? new java.awt.Color(82, 116, 96, 26) : new java.awt.Color(28, 52, 42, 28));
            g.fillOval(x, y, w, h);
        }
        p = P_JTITLES;
        g.setColor(new java.awt.Color(40, 34, 30));
        g.fillRect(p[0], p[1], p[2], p[3]);
        String[] songs = {"BLUE RIVER", "LOUISVILLE", "HOME LATE", "LAST TRAIN", "SNOW WALTZ", "OLD ROAD", "MARY ANN", "NIGHT SHIFT", "DRIFTER", "SO LONG"};
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 8));
        for (int i = 0; i < songs.length; i++) {
            if (i == 3 || i == 7) continue;    // torn out long ago
            int x = p[0] + 4 + (i % 5) * 50, y = p[1] + 4 + (i / 5) * 61;
            g.setColor(new java.awt.Color(176, 156, 112));
            g.fillRect(x, y, 48, 58);
            g.setColor(new java.awt.Color(112, 44, 34));
            g.fillRect(x, y + 25, 48, 8);
            g.setColor(new java.awt.Color(58, 46, 36));
            centred(g, songs[i], x + 24, y + 16);
            centred(g, songs[(i + 3) % songs.length], x + 24, y + 48);
            for (int k = 0; k < 7; k++) {   // damp's stains
                g.setColor(new java.awt.Color(74, 52, 28, 40 + r.nextInt(50)));
                g.fillOval(x + r.nextInt(40), y + r.nextInt(50), 4 + r.nextInt(16), 4 + r.nextInt(18));
            }
        }
        // the panel, cracked, a hole kicked in a corner of it
        p = P_JPANEL;
        for (int i = 0; i < 90; i++) {
            g.setColor(new java.awt.Color(36, 28, 20, 40 + r.nextInt(60)));
            g.fillOval(p[0] + r.nextInt(p[2] - 20), p[1] + p[3] - 70 + r.nextInt(60), 6 + r.nextInt(30), 3 + r.nextInt(10));
        }
        g.setColor(new java.awt.Color(8, 7, 6));
        g.fillPolygon(new int[] {p[0] + 12, p[0] + 62, p[0] + 80, p[0] + 58, p[0] + 34, p[0] + 10}, new int[] {p[1] + 96, p[1] + 88, p[1] + 124, p[1] + 170, p[1] + 150, p[1] + 142}, 6);
        g.setStroke(new java.awt.BasicStroke(1.6f));
        g.setColor(new java.awt.Color(14, 12, 10));
        for (int[] c : new int[][] {{78, 104, 128, 66}, {128, 66, 178, 80}, {178, 80, 250, 22}, {80, 126, 136, 150}, {136, 150, 196, 186}, {58, 88, 72, 30}, {72, 30, 44, 4}}) {
            g.drawLine(p[0] + c[0], p[1] + c[1], p[0] + c[2], p[1] + c[3]);
        }
        g.setStroke(new java.awt.BasicStroke(1));
        barWorn(g, r, P_WGOLD, new java.awt.Color(146, 112, 54), 0.5);
        barWorn(g, r, P_WCHROME, new java.awt.Color(126, 128, 126), 0.45);
        barWorn(g, r, P_WRED, new java.awt.Color(112, 30, 26), 0.35);
        barWorn(g, r, P_WGREEN, new java.awt.Color(62, 96, 78), 0.3);
        barWorn(g, r, P_WSTEEL, new java.awt.Color(86, 88, 90), 0.6);
        // the speaker's cloth: rotted, torn in long rips
        p = P_JCLOTH;
        g.setColor(new java.awt.Color(24, 22, 20));
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 2600; i++) {
            g.setColor(r.nextBoolean() ? new java.awt.Color(46, 42, 36) : new java.awt.Color(12, 11, 10));
            g.fillRect(p[0] + r.nextInt(p[2]), p[1] + r.nextInt(p[3]), 2, 2);
        }
        g.setColor(new java.awt.Color(3, 3, 3));
        g.fillPolygon(new int[] {p[0] + 40, p[0] + 92, p[0] + 76, p[0] + 112, p[0] + 58, p[0] + 28}, new int[] {p[1] + 20, p[1] + 34, p[1] + 110, p[1] + 200, p[1] + 150, p[1] + 90}, 6);
        g.fillPolygon(new int[] {p[0] + 170, p[0] + 212, p[0] + 196, p[0] + 182}, new int[] {p[1] + 120, p[1] + 150, p[1] + 240, p[1] + 190}, 4);
    }

    /**
     * The cigarette machine's pictures (the author, 2026-11-02: as good as the jukebox): its oxblood
     * enamel, scratched and rusting; the lit header, dead, its paint flaking; the eight brands of
     * nobody; the coin plate; a hand-written note taped over the slot.
     */
    static void barAtlasCig(java.awt.Graphics2D g, java.awt.Color ink) {
        Random r = new Random(1976);
        java.awt.Color cream = new java.awt.Color(206, 190, 150), blood = new java.awt.Color(92, 30, 26);
        barWorn(g, r, P_CIGBODY, new java.awt.Color(86, 30, 26), 0.32);
        barWorn(g, r, P_CIGTRIM, new java.awt.Color(120, 122, 120), 0.4);
        int[] p = P_CIGBODY;
        for (int i = 0; i < 240; i++) {   // kicked, scraped along the floor
            int x = p[0] + r.nextInt(p[2]), y = p[1] + r.nextInt(p[3]);
            g.setColor(r.nextBoolean() ? new java.awt.Color(150, 120, 104, 26 + r.nextInt(40)) : new java.awt.Color(16, 10, 8, 40 + r.nextInt(60)));
            g.drawLine(x, y, Math.min(p[0] + p[2] - 1, x + r.nextInt(30) - 15), Math.min(p[1] + p[3] - 1, y + r.nextInt(12)));
        }
        // the header: cream glass painted from behind, a bar of the red, the word
        p = P_CIGHEAD;
        g.setColor(cream);
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(blood);
        g.fillRect(p[0], p[1] + 12, p[2], p[3] - 24);
        g.setColor(new java.awt.Color(164, 132, 70));
        g.fillRect(p[0], p[1] + 18, p[2], 3);
        g.fillRect(p[0], p[1] + p[3] - 21, p[2], 3);
        g.setColor(cream);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD | java.awt.Font.ITALIC, 66));
        centred(g, "Cigarettes", p[0] + p[2] / 2, p[1] + 86);
        for (int i = 0; i < 150; i++) {   // the paint flaking off the glass, the corners worst
            int x = r.nextInt(p[2]), y = r.nextInt(p[3]);
            boolean corner = x < 90 || x > p[2] - 110;
            if (!corner && r.nextInt(3) > 0) continue;
            g.setColor(new java.awt.Color(24, 20, 16, 120 + r.nextInt(120)));
            g.fillOval(p[0] + x, p[1] + y, 2 + r.nextInt(corner ? 26 : 9), 1 + r.nextInt(corner ? 14 : 5));
        }
        // a crack across it, from a blow
        g.setStroke(new java.awt.BasicStroke(1.6f));
        g.setColor(new java.awt.Color(10, 8, 7));
        int[][] crack = {{372, 0, 392, 40}, {392, 40, 366, 72}, {366, 72, 410, 128}, {392, 40, 452, 58}, {452, 58, 512, 46}};
        for (int[] c : crack) g.drawLine(p[0] + c[0], p[1] + c[1], p[0] + c[2], p[1] + c[3]);
        g.setStroke(new java.awt.BasicStroke(1));
        // the packs: nobody's brands, a pack in its colours each
        p = P_CIGPACKS;
        String[] names = {"RIDGE", "KNOX", "DIXIE", "OLD MULE", "PINE", "RANGER", "TOPAZ", "SENATE"};
        java.awt.Color[] face = {new java.awt.Color(174, 44, 36), new java.awt.Color(206, 196, 168), new java.awt.Color(40, 80, 130), new java.awt.Color(170, 130, 66),
            new java.awt.Color(44, 104, 74), new java.awt.Color(196, 184, 150), new java.awt.Color(40, 40, 46), new java.awt.Color(120, 34, 56)};
        java.awt.Color[] type = {cream, new java.awt.Color(150, 30, 28), cream, new java.awt.Color(40, 28, 16), cream, new java.awt.Color(36, 70, 50), new java.awt.Color(190, 160, 90), cream};
        for (int i = 0; i < 8; i++) {
            int x = p[0] + i * 64;
            g.setColor(face[i]);
            g.fillRect(x, p[1], 64, p[3]);
            g.setColor(new java.awt.Color(214, 208, 190));   // the foil's top
            g.fillRect(x, p[1], 64, 12);
            g.setColor(type[i]);
            if (i % 3 == 0) g.fillRect(x, p[1] + 26, 64, 4);
            if (i % 3 == 1) g.fillOval(x + 20, p[1] + 58, 24, 24);
            if (i % 3 == 2) g.fillPolygon(new int[] {x, x + 64, x + 64, x}, new int[] {p[1] + 70, p[1] + 58, p[1] + 66, p[1] + 78}, 4);
            g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, names[i].length() > 6 ? 10 : 13));
            centred(g, names[i], x + 32, p[1] + 48);
            g.setColor(new java.awt.Color(20, 14, 10, 70));
            for (int k = 0; k < 5; k++) g.fillOval(x + r.nextInt(50), p[1] + r.nextInt(84), 3 + r.nextInt(12), 3 + r.nextInt(10));
        }
        // the coin plate
        p = P_CIGPLATE;
        barWorn(g, r, p, new java.awt.Color(128, 130, 126), 0.3);
        g.setColor(new java.awt.Color(26, 22, 20));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 13));
        centred(g, "60\u00a2", p[0] + p[2] / 2, p[1] + 20);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 9));
        centred(g, "QUARTERS DIMES", p[0] + p[2] / 2, p[1] + 34);
        centred(g, "NICKELS", p[0] + p[2] / 2, p[1] + 45);
        centred(g, "PULL KNOB", p[0] + p[2] / 2, p[1] + 150);
        centred(g, "ALL THE WAY", p[0] + p[2] / 2, p[1] + 161);
        // what the machine says of itself, low on its front
        p = P_CIGSIGN;
        g.setColor(new java.awt.Color(176, 160, 124));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(new java.awt.Color(58, 40, 28));
        g.fillRect(p[0] + 4, p[1] + 4, p[2] - 8, 2);
        g.fillRect(p[0] + 4, p[1] + p[3] - 6, p[2] - 8, 2);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 19));
        centred(g, "ALL POPULAR BRANDS", p[0] + p[2] / 2, p[1] + 36);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 12));
        centred(g, "Sale to minors prohibited by Kentucky law", p[0] + p[2] / 2, p[1] + 62);
        centred(g, "Coins returned if empty", p[0] + p[2] / 2, p[1] + 78);
        for (int i = 0; i < 60; i++) {
            g.setColor(new java.awt.Color(56, 36, 18, 30 + r.nextInt(60)));
            g.fillOval(p[0] + r.nextInt(p[2] - 10), p[1] + r.nextInt(p[3] - 8), 3 + r.nextInt(24), 2 + r.nextInt(12));
        }
        // the price under each column, some tags gone
        p = P_CIGTAGS;
        g.setColor(new java.awt.Color(30, 26, 24));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 11));
        for (int i = 0; i < 8; i++) {
            if (i == 2 || i == 6) continue;
            g.setColor(new java.awt.Color(192, 176, 136));
            g.fillRect(p[0] + i * 32 + 2, p[1] + 4, 28, 24);
            g.setColor(new java.awt.Color(120, 34, 28));
            centred(g, i % 2 == 0 ? "60\u00a2" : "65\u00a2", p[0] + i * 32 + 16, p[1] + 21);
        }
        // the note taped over the slot
        p = P_CIGNOTE;
        g.setColor(new java.awt.Color(186, 176, 146));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(new java.awt.Color(44, 40, 60));
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD | java.awt.Font.ITALIC, 19));
        centred(g, "EMPTY", p[0] + p[2] / 2, p[1] + 26);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.ITALIC, 14));
        centred(g, "dont bother", p[0] + p[2] / 2, p[1] + 48);
    }

    /**
     * Somebody in a photo, in the game's build: heavy shoulders, a small head, plain clothes in
     * flat colours lit from one side. x, foot: where it stands; h its height in pixels. hat: 0 none,
     * 1 a cap, 2 a hunter's cap with flaps; beard; arm: its right arm 0 down, 1 raised, 2 round the next one.
     */
    static void photoPerson(java.awt.Graphics2D g, double x, double foot, double h, java.awt.Color top, java.awt.Color legs, java.awt.Color skin,
                            java.awt.Color hair, int hat, java.awt.Color hatCol, boolean beard, int arm) {
        double u = h / 100;
        java.awt.Color topD = top.darker(), legsD = legs.darker(), boots = new java.awt.Color(38, 28, 22);
        // the legs, the boots
        for (int s = -1; s <= 1; s += 2) {
            g.setColor(s < 0 ? legs : legsD);
            g.fill(new java.awt.geom.Rectangle2D.Double(x + (s < 0 ? -12 : 1) * u, foot - 50 * u, 11 * u, 45 * u));
            g.setColor(boots);
            g.fill(new java.awt.geom.RoundRectangle2D.Double(x + (s < 0 ? -14 : 0) * u, foot - 7 * u, 14 * u, 7 * u, 3 * u, 3 * u));
        }
        // the arms behind the body's edges
        g.setColor(topD);
        g.fill(new java.awt.geom.RoundRectangle2D.Double(x - 22 * u, foot - 82 * u, 9 * u, 38 * u, 5 * u, 5 * u));
        if (arm == 0) {
            g.fill(new java.awt.geom.RoundRectangle2D.Double(x + 13 * u, foot - 82 * u, 9 * u, 38 * u, 5 * u, 5 * u));
            g.setColor(skin);
            g.fill(new java.awt.geom.Ellipse2D.Double(x + 13.5 * u, foot - 47 * u, 8 * u, 8 * u));
        } else if (arm == 1) {
            java.awt.geom.Path2D.Double a = new java.awt.geom.Path2D.Double();
            a.moveTo(x + 13 * u, foot - 82 * u); a.lineTo(x + 30 * u, foot - 108 * u); a.lineTo(x + 37 * u, foot - 102 * u); a.lineTo(x + 21 * u, foot - 72 * u); a.closePath();
            g.fill(a);
            g.setColor(skin);
            g.fill(new java.awt.geom.Ellipse2D.Double(x + 29 * u, foot - 112 * u, 9 * u, 9 * u));
        } else {
            g.fill(new java.awt.geom.RoundRectangle2D.Double(x + 12 * u, foot - 83 * u, 34 * u, 9 * u, 5 * u, 5 * u));
        }
        g.setColor(skin);
        g.fill(new java.awt.geom.Ellipse2D.Double(x - 21.5 * u, foot - 47 * u, 8 * u, 8 * u));
        // the body, its shaded side, a collar, a zip or a shirt's front
        g.setColor(top);
        g.fill(new java.awt.geom.RoundRectangle2D.Double(x - 16 * u, foot - 86 * u, 32 * u, 40 * u, 7 * u, 7 * u));
        g.setColor(topD);
        g.fill(new java.awt.geom.Rectangle2D.Double(x + 5 * u, foot - 84 * u, 11 * u, 37 * u));
        g.setColor(new java.awt.Color(0, 0, 0, 70));
        g.fill(new java.awt.geom.Rectangle2D.Double(x - 0.7 * u, foot - 84 * u, 1.4 * u, 38 * u));
        g.setColor(new java.awt.Color(20, 16, 14));
        g.fill(new java.awt.geom.Rectangle2D.Double(x - 16 * u, foot - 50 * u, 32 * u, 4 * u));
        // the head, its neck
        g.setColor(skin);
        g.fill(new java.awt.geom.Rectangle2D.Double(x - 4 * u, foot - 90 * u, 8 * u, 7 * u));
        g.fill(new java.awt.geom.RoundRectangle2D.Double(x - 8 * u, foot - 106 * u, 16 * u, 18 * u, 8 * u, 8 * u));
        g.setColor(hair);
        g.fill(new java.awt.geom.Arc2D.Double(x - 8.5 * u, foot - 108 * u, 17 * u, 15 * u, 0, 180, java.awt.geom.Arc2D.PIE));
        if (beard) g.fill(new java.awt.geom.Arc2D.Double(x - 8 * u, foot - 100 * u, 16 * u, 13 * u, 180, 180, java.awt.geom.Arc2D.PIE));
        g.setColor(new java.awt.Color(24, 18, 14));
        g.fill(new java.awt.geom.Rectangle2D.Double(x - 4.5 * u, foot - 99 * u, 2.2 * u, 2 * u));
        g.fill(new java.awt.geom.Rectangle2D.Double(x + 2.3 * u, foot - 99 * u, 2.2 * u, 2 * u));
        if (hat > 0) {
            g.setColor(hatCol);
            g.fill(new java.awt.geom.Arc2D.Double(x - 9 * u, foot - 111 * u, 18 * u, 20 * u, 0, 180, java.awt.geom.Arc2D.PIE));
            g.fill(new java.awt.geom.Rectangle2D.Double(x - 10 * u, foot - 102 * u, 20 * u, 2.4 * u));
            if (hat == 2) {
                g.fill(new java.awt.geom.Rectangle2D.Double(x - 10 * u, foot - 102 * u, 3.2 * u, 9 * u));
                g.fill(new java.awt.geom.Rectangle2D.Double(x + 6.8 * u, foot - 102 * u, 3.2 * u, 9 * u));
            }
        }
    }

    /** What makes it an old print: its colours gone warm, the fading, the marks of years, a white border, the lab's date. */
    static void photoAge(java.awt.Graphics2D g, Random r, int[] p, String date) {
        g.setColor(new java.awt.Color(150, 110, 54, 44));
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 14; i++) {   // darker to the corners, as old prints go
            g.setColor(new java.awt.Color(46, 30, 16, 7));
            g.setStroke(new java.awt.BasicStroke(3));
            g.drawRect(p[0] + 8 + i * 3, p[1] + 8 + i * 3, p[2] - 17 - i * 6, p[3] - 17 - i * 6);
        }
        g.setStroke(new java.awt.BasicStroke(1));
        g.setColor(new java.awt.Color(226, 216, 190, 34));
        for (int i = 0; i < 3; i++) {
            int sx = p[0] + r.nextInt(p[2]), sy = p[1] + r.nextInt(p[3]);
            g.drawLine(sx, sy, sx + r.nextInt(30) - 15, sy + r.nextInt(30) - 15);
        }
        g.setColor(new java.awt.Color(214, 112, 42));
        g.setFont(new java.awt.Font("Monospaced", java.awt.Font.BOLD, 11));
        g.drawString(date, p[0] + p[2] - 62, p[1] + p[3] - 15);
        g.setColor(new java.awt.Color(208, 198, 172));
        g.setStroke(new java.awt.BasicStroke(9));
        g.drawRect(p[0] + 4, p[1] + 4, p[2] - 9, p[3] - 9);
        g.setStroke(new java.awt.BasicStroke(1));
    }

    private static java.awt.Color rgb(int r, int g, int b) {
        return new java.awt.Color(r, g, b);
    }

    /** Three men and the buck on the tailgate, the old pickup, the bare November woods. */
    static void photoHunters(java.awt.Graphics2D g, Random r, int[] p) {
        int x = p[0], y = p[1], w = p[2], h = p[3];
        g.setPaint(new java.awt.GradientPaint(0, y, rgb(166, 176, 178), 0, y + 110, rgb(198, 192, 170)));
        g.fillRect(x, y, w, h);
        for (int i = 0; i < 46; i++) {   // the woods behind
            int tx = x + r.nextInt(w);
            g.setColor(rgb(66 + r.nextInt(30), 58 + r.nextInt(20), 48));
            g.fillRect(tx, y + 18, 2 + r.nextInt(5), 100);
            g.drawLine(tx, y + 40 + r.nextInt(30), tx + r.nextInt(30) - 15, y + 14 + r.nextInt(26));
        }
        g.setColor(rgb(112, 98, 66));
        g.fillRect(x, y + 118, w, h - 118);
        g.setColor(rgb(86, 76, 50));
        for (int i = 0; i < 60; i++) g.fillOval(x + r.nextInt(w), y + 120 + r.nextInt(h - 124), 6 + r.nextInt(16), 2 + r.nextInt(4));
        // the pickup, side on, its tail to the right, its nose out of the picture
        java.awt.Color body = rgb(118, 44, 36), bodyD = rgb(82, 30, 26);
        g.setColor(body);
        g.fillRoundRect(x + 8, y + 96, 142, 36, 6, 6);
        g.fillRoundRect(x + 8, y + 62, 54, 38, 10, 10);
        g.setColor(rgb(150, 170, 176));
        g.fillRect(x + 14, y + 69, 20, 22);
        g.fillRect(x + 38, y + 69, 18, 22);
        g.setColor(bodyD);
        g.fillRect(x + 8, y + 114, 142, 5);
        g.fillRect(x + 64, y + 96, 86, 3);
        g.setColor(rgb(214, 70, 44));
        g.fillRect(x + 144, y + 102, 6, 9);
        g.setColor(rgb(170, 170, 164));
        g.fillRect(x + 8, y + 126, 148, 6);
        g.setColor(rgb(24, 22, 20));
        g.fillOval(x + 92, y + 118, 30, 30);
        g.setColor(rgb(140, 136, 126));
        g.fillOval(x + 101, y + 127, 12, 12);
        // the buck in the bed, its head hanging over the side and its antlers up
        g.setColor(rgb(120, 90, 60));
        g.fillRoundRect(x + 72, y + 78, 62, 22, 12, 12);
        g.fillRoundRect(x + 64, y + 72, 16, 14, 6, 6);
        g.setColor(rgb(226, 214, 186));
        g.fillOval(x + 124, y + 80, 9, 8);
        g.setColor(rgb(214, 202, 172));
        g.setStroke(new java.awt.BasicStroke(2.2f));
        for (int[] a : new int[][] {{68, 72, 60, 54}, {64, 64, 55, 62}, {61, 57, 66, 47}, {74, 72, 78, 50}, {76, 60, 85, 54}, {78, 54, 74, 44}}) g.drawLine(x + a[0], y + a[1], x + a[2], y + a[3]);
        g.setStroke(new java.awt.BasicStroke(1));
        // the men by the tailgate, the middle one's arm over his friend, the last with his rifle
        photoPerson(g, x + 170, y + 170, 88, rgb(96, 62, 44), rgb(46, 52, 72), rgb(198, 160, 128), rgb(34, 26, 20), 1, rgb(46, 60, 36), true, 2);
        photoPerson(g, x + 202, y + 168, 92, rgb(186, 96, 30), rgb(62, 66, 58), rgb(196, 156, 122), rgb(50, 36, 26), 2, rgb(192, 92, 26), true, 0);
        photoPerson(g, x + 232, y + 172, 84, rgb(74, 82, 56), rgb(56, 60, 76), rgb(186, 146, 116), rgb(90, 74, 56), 0, rgb(0, 0, 0), false, 0);
        g.setColor(rgb(40, 28, 20));
        g.setStroke(new java.awt.BasicStroke(3));
        g.drawLine(x + 244, y + 92, x + 224, y + 146);
        g.setStroke(new java.awt.BasicStroke(1));
        photoAge(g, r, p, "NOV 86");
    }

    /** The owner behind this very counter, a regular on his stool, the shelf of bottles and the mirror behind. */
    static void photoCounter(java.awt.Graphics2D g, Random r, int[] p) {
        int x = p[0], y = p[1], w = p[2], h = p[3];
        g.setColor(rgb(84, 58, 38));
        g.fillRect(x, y, w, h);
        for (int i = 0; i < 12; i++) {   // the boards of the wall
            g.setColor(rgb(62, 42, 28));
            g.fillRect(x + i * 22, y, 2, 130);
        }
        // the mirror, the shelf with its bottles
        g.setColor(rgb(150, 156, 146));
        g.fillRect(x + 66, y + 16, 124, 42);
        g.setColor(rgb(186, 150, 84));
        g.setStroke(new java.awt.BasicStroke(3));
        g.drawRect(x + 66, y + 16, 124, 42);
        g.setStroke(new java.awt.BasicStroke(1));
        g.setColor(rgb(52, 34, 22));
        g.fillRect(x + 14, y + 82, w - 28, 6);
        java.awt.Color[] glass = {rgb(92, 54, 26), rgb(46, 86, 56), rgb(150, 110, 50), rgb(170, 170, 150), rgb(110, 36, 30)};
        for (int i = 0; i < 18; i++) {
            int bx = x + 18 + i * 12 + r.nextInt(3), bh = 18 + r.nextInt(10);
            g.setColor(glass[r.nextInt(glass.length)]);
            g.fillRoundRect(bx, y + 82 - bh, 8, bh, 3, 3);
            g.fillRect(bx + 3, y + 82 - bh - 7, 2, 8);
            g.setColor(rgb(216, 206, 176));
            g.fillRect(bx + 1, y + 82 - bh + 8, 6, 6);
        }
        // the garland, lit, that first winter
        for (int i = 0; i < 14; i++) {
            java.awt.Color[] c = {rgb(220, 70, 50), rgb(90, 190, 90), rgb(240, 190, 70), rgb(90, 120, 220)};
            g.setColor(c[i % 4]);
            g.fillOval(x + 8 + i * 18, y + 10 + (int) (6 * Math.sin(i * 1.1)), 5, 6);
        }
        // the owner, his apron; his arm raised with a glass he's drying
        photoPerson(g, x + 100, y + 180, 118, rgb(170, 164, 146), rgb(50, 44, 40), rgb(198, 158, 124), rgb(120, 110, 96), 0, rgb(0, 0, 0), true, 1);
        g.setColor(rgb(206, 200, 182));
        g.fillRect(x + 84, y + 92, 32, 60);
        g.setColor(rgb(190, 210, 214));
        g.fillRoundRect(x + 134, y + 48, 9, 13, 2, 2);
        // the counter
        g.setPaint(new java.awt.GradientPaint(0, y + 136, rgb(110, 66, 38), 0, y + 192, rgb(58, 34, 20)));
        g.fillRect(x, y + 136, w, h - 136);
        g.setColor(rgb(150, 96, 56));
        g.fillRect(x, y + 136, w, 5);
        // the bottle, a glass; the regular at it, turned to the camera
        g.setColor(rgb(90, 52, 26));
        g.fillRoundRect(x + 146, y + 110, 11, 27, 3, 3);
        g.fillRect(x + 150, y + 100, 3, 12);
        g.setColor(rgb(214, 200, 164));
        g.fillRect(x + 147, y + 118, 9, 8);
        photoPerson(g, x + 198, y + 214, 134, rgb(58, 76, 104), rgb(46, 50, 66), rgb(192, 150, 118), rgb(44, 32, 24), 1, rgb(128, 40, 32), false, 0);
        photoAge(g, r, p, "DEC 89");
    }

    /** The bar's softball team, a summer: the back row standing, the front kneeling by the cup, the road's trees behind. */
    static void photoTeam(java.awt.Graphics2D g, Random r, int[] p) {
        int x = p[0], y = p[1], w = p[2], h = p[3];
        g.setPaint(new java.awt.GradientPaint(0, y, rgb(146, 178, 196), 0, y + 76, rgb(206, 208, 186)));
        g.fillRect(x, y, w, h);
        for (int i = 0; i < 30; i++) {
            g.setColor(rgb(58 + r.nextInt(30), 88 + r.nextInt(30), 54));
            g.fillOval(x - 10 + i * 9, y + 28 + r.nextInt(26), 28 + r.nextInt(26), 30 + r.nextInt(20));
        }
        g.setColor(rgb(94, 118, 60));
        g.fillRect(x, y + 84, w, h - 84);
        g.setColor(rgb(140, 112, 72));   // the diamond's dirt
        g.fillOval(x + 140, y + 90, 160, 34);
        java.awt.Color shirt = rgb(186, 176, 150), cap = rgb(124, 40, 32);
        java.awt.Color[] skin = {rgb(198, 158, 124), rgb(176, 134, 102), rgb(204, 168, 136), rgb(118, 84, 62), rgb(192, 150, 116)};
        java.awt.Color[] hair = {rgb(50, 36, 26), rgb(90, 66, 40), rgb(30, 24, 20), rgb(24, 20, 18), rgb(130, 100, 60)};
        int[] tall = {98, 88, 104, 92, 96}, stand = {-2, 3, 0, -3, 2}, hats = {1, 0, 1, 1, 0};
        for (int i = 0; i < 5; i++) {
            int bx = x + 44 + i * 42 + stand[i];
            photoPerson(g, bx, y + 150 + stand[i], tall[i], shirt, rgb(160, 152, 130), skin[i], hair[i], hats[i], cap, i == 0 || i == 3, i == 4 ? 1 : (i == 1 ? 2 : 0));
            // the number on the chest
            g.setColor(cap);
            g.fillRect(bx - 4, y + 150 + stand[i] - (int) (tall[i] * 0.72), 7, 9);
        }
        int[] kneel = {78, 72, 80, 74}, kneelHat = {0, 1, 1, 0};
        for (int i = 0; i < 4; i++) {
            // the front row, on one knee: cut by the ground before them
            photoPerson(g, x + 62 + i * 42 + (i == 2 ? 26 : 0) - (i == 1 ? 8 : 0), y + 188, kneel[i], shirt, rgb(150, 142, 122), skin[(i + 2) % 5], hair[(i + 3) % 5], kneelHat[i], cap, i == 2, 0);
        }
        g.setColor(rgb(94, 118, 60));
        g.fillRect(x, y + 168, w, h - 168);
        // the cup and the bat before them
        g.setColor(rgb(196, 158, 76));
        g.fillRoundRect(x + 120, y + 146, 18, 18, 6, 6);
        g.fillRect(x + 126, y + 162, 6, 8);
        g.fillRect(x + 118, y + 169, 22, 5);
        g.setColor(rgb(170, 128, 76));
        g.setStroke(new java.awt.BasicStroke(4));
        g.drawLine(x + 28, y + 178, x + 88, y + 170);
        g.setStroke(new java.awt.BasicStroke(1));
        photoAge(g, r, p, "JUL 84");
    }

    /** The bar's wall: the flag faded by years of smoke, its people's photos (the author, 2026-11-02: detailed, as the game's), a calendar stopped that July. */
    static void barAtlasWall(java.awt.Graphics2D g, java.awt.Color ink) {
        Random r = new Random(1993);
        int[] p = P_FLAG;
        java.awt.Color red = new java.awt.Color(136, 42, 38), white = new java.awt.Color(186, 176, 150), blue = new java.awt.Color(36, 46, 84);
        for (int i = 0; i < 13; i++) {
            g.setColor(i % 2 == 0 ? red : white);
            int y0 = p[1] + i * p[3] / 13, y1 = p[1] + (i + 1) * p[3] / 13;
            g.fillRect(p[0], y0, p[2], y1 - y0);
        }
        int bw = p[2] * 2 / 5, bh = p[3] * 7 / 13;
        g.setColor(blue);
        g.fillRect(p[0], p[1], bw, bh);
        g.setColor(white);
        for (int row = 0; row < 9; row++) {
            int n = row % 2 == 0 ? 6 : 5;
            for (int i = 0; i < n; i++) {
                int x = p[0] + 6 + i * (bw - 12) / 6 + (row % 2 == 0 ? 0 : (bw - 12) / 12), y = p[1] + 4 + row * (bh - 8) / 9;
                g.fillOval(x, y, 4, 4);
            }
        }
        for (int i = 0; i < 90; i++) {   // smoke, damp, a burn at the fly
            g.setColor(new java.awt.Color(44, 32, 20, 18 + r.nextInt(36)));
            g.fillOval(p[0] + r.nextInt(p[2] - 10), p[1] + r.nextInt(p[3] - 10), 8 + r.nextInt(46), 5 + r.nextInt(28));
        }
        photoHunters(g, new Random(11), P_PHOTO1);
        photoCounter(g, new Random(12), P_PHOTO2);
        photoTeam(g, new Random(13), P_PHOTO3);
        // the calendar: stopped on the month it all ended
        p = P_CALENDAR;
        g.setColor(new java.awt.Color(190, 180, 150));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(new java.awt.Color(58, 72, 56));
        g.fillRect(p[0], p[1], p[2], 54);
        g.setColor(new java.awt.Color(204, 192, 158));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 13));
        centred(g, "RIVERSIDE FEED", p[0] + p[2] / 2, p[1] + 22);
        centred(g, "& SEED", p[0] + p[2] / 2, p[1] + 38);
        g.setColor(ink);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 14));
        centred(g, "JULY 1993", p[0] + p[2] / 2, p[1] + 72);
        g.setColor(new java.awt.Color(64, 56, 46));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 9));
        for (int d = 1; d <= 31; d++) {
            int cell = d + 3;
            g.drawString(String.valueOf(d), p[0] + 8 + (cell % 7) * 16, p[1] + 88 + (cell / 7) * 13);
        }
        g.setColor(new java.awt.Color(128, 34, 28));
        for (int d = 1; d <= 8; d++) {   // crossed off, up to the eighth
            int cell = d + 3, x = p[0] + 8 + (cell % 7) * 16, y = p[1] + 88 + (cell / 7) * 13;
            g.drawLine(x - 1, y + 1, x + 11, y - 9);
        }
        // the plate
        p = P_PLATE;
        barWorn(g, r, p, new java.awt.Color(176, 170, 150), 0.25);
        g.setColor(new java.awt.Color(36, 50, 96));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 11));
        centred(g, "KENTUCKY", p[0] + p[2] / 2, p[1] + 14);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 26));
        centred(g, "BAR 093", p[0] + p[2] / 2, p[1] + 46);
    }

    /** The first aid kit's pictures: chipped enamel, its red cross, the used bandage, the list in its lid. */
    static void barAtlasAid(java.awt.Graphics2D g, java.awt.Color ink) {
        Random r = new Random(911);
        barWorn(g, r, P_WENAMEL, new java.awt.Color(62, 96, 58), 0.4);   // (green: the author, 2026-11-01)
        int[] p = P_AIDFRONT;
        barWorn(g, r, p, new java.awt.Color(62, 96, 58), 0.25);
        g.setColor(new java.awt.Color(206, 202, 186));
        int cx = p[0] + p[2] / 2, cy = p[1] + p[3] / 2;
        g.fillRect(cx - 14, cy - 44, 28, 88);
        g.fillRect(cx - 44, cy - 14, 88, 28);
        g.setColor(new java.awt.Color(62, 96, 58));
        for (int i = 0; i < 40; i++) g.fillOval(cx - 50 + r.nextInt(100), cy - 48 + r.nextInt(96), 1 + r.nextInt(5), 1 + r.nextInt(5));
        p = P_BANDAGE;
        g.setColor(new java.awt.Color(196, 190, 172));
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 2400; i++) {   // gauze: a fine uneven weave
            g.setColor(r.nextBoolean() ? new java.awt.Color(222, 216, 198, 90) : new java.awt.Color(140, 132, 112, 80));
            g.fillRect(p[0] + r.nextInt(p[2]), p[1] + r.nextInt(p[3]), 1 + r.nextInt(3), 1);
        }
        for (int i = 0; i < 26; i++) {   // old blood, thicker towards its end
            int x = p[2] / 2 + r.nextInt(p[2] / 2 - 26);
            g.setColor(new java.awt.Color(70 + r.nextInt(30), 22, 16, 90 + r.nextInt(110)));
            g.fillOval(p[0] + x, p[1] + 6 + r.nextInt(38), 6 + r.nextInt(24), 4 + r.nextInt(16));
        }
        p = P_AIDNOTE;
        g.setColor(new java.awt.Color(190, 180, 150));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setColor(ink);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 13));
        centred(g, "FIRST AID", p[0] + p[2] / 2, p[1] + 18);
        g.setColor(new java.awt.Color(76, 70, 60));
        for (int l = 0; l < 6; l++) g.fillRect(p[0] + 12, p[1] + 30 + l * 10, 70 + r.nextInt(34), 3);
    }

    /** The journal's two pages (the author, 2026-11-02): the last entry on the left in pencil, the right one clean. */
    static void barAtlasJournal(java.awt.Graphics2D g) {
        Random r = new Random(1212);
        int[] p = P_JOURNAL;
        int mid = p[0] + p[2] / 2;
        g.setColor(new java.awt.Color(204, 192, 158));
        g.fillRect(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 140; i++) {   // the paper yellowed, foxed
            g.setColor(new java.awt.Color(150, 120, 74, 8 + r.nextInt(20)));
            g.fillOval(p[0] + r.nextInt(p[2] - 40), p[1] + r.nextInt(p[3] - 30), 8 + r.nextInt(40), 6 + r.nextInt(30));
        }
        g.setColor(new java.awt.Color(150, 158, 160));
        for (int l = 0; l < 10; l++) g.fillRect(p[0] + 12, p[1] + 34 + l * 22, p[2] - 24, 1);
        for (int x = 0; x < 34; x++) {   // the shadow into the fold
            g.setColor(new java.awt.Color(40, 28, 16, Math.max(0, 110 - x * 4)));
            g.fillRect(mid - x - 1, p[1], 1, p[3]);
            g.fillRect(mid + x, p[1], 1, p[3]);
        }
        g.setColor(new java.awt.Color(46, 44, 50));
        // handwriting (the author, 2026-11-02: a book's italic didn't read as written by hand): a
        // hand's font, each letter off its line a little, its own tilt and size, the pencil's pressure uneven
        java.awt.Font hand = new java.awt.Font("Ink Free", java.awt.Font.PLAIN, 25);
        String[] lines = {"Dec 14. Snow again.", "Door won't hold much", "longer. Tom left at dawn.", "Not coming back I think.", "", "Going north tomorrow.", "Whoever finds this -", "the next page is yours.", "              - J."};
        for (int l = 0; l < lines.length; l++) {
            double x = p[0] + 14 + r.nextInt(5), base = p[1] + 29 + l * 22, drift = (r.nextDouble() - 0.5) * 0.02;
            for (int c = 0; c < lines[l].length(); c++) {
                String ch = lines[l].substring(c, c + 1);
                java.awt.Font f = hand.deriveFont(18.5f + r.nextFloat() * 2f);
                g.setFont(f);
                g.setColor(new java.awt.Color(44, 42, 50, 170 + r.nextInt(70)));
                java.awt.geom.AffineTransform keep = g.getTransform();
                g.translate(x, base + drift * (x - p[0]) + (r.nextDouble() - 0.5) * 1.6);
                g.rotate((r.nextDouble() - 0.5) * 0.09 + drift);
                g.drawString(ch, 0, 0);
                g.setTransform(keep);
                x += g.getFontMetrics(f).charWidth(lines[l].charAt(c)) + (r.nextDouble() - 0.5) * 0.8;
            }
        }
    }

    /** A painted strip gone old: the paint rubbed thin, flaked to the rust, stained in runs down it. */
    static void barWorn(java.awt.Graphics2D g, Random r, int[] p, java.awt.Color base, double rust) {
        g.setColor(base);
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setClip(p[0], p[1], p[2], p[3]);
        for (int i = 0; i < 500; i++) {   // grime
            g.setColor(new java.awt.Color(18, 14, 10, 18 + r.nextInt(36)));
            g.fillOval(p[0] + r.nextInt(p[2]), p[1] + r.nextInt(p[3]), 4 + r.nextInt(30), 2 + r.nextInt(12));
        }
        for (int i = 0; i < (int) (160 * rust); i++) {   // flakes down to rust
            int x = p[0] + r.nextInt(p[2]), y = p[1] + r.nextInt(p[3]), w = 2 + r.nextInt(16), h = 1 + r.nextInt(8);
            g.setColor(new java.awt.Color(64 + r.nextInt(44), 34 + r.nextInt(16), 16 + r.nextInt(10), 200));
            g.fillOval(x, y, w, h);
        }
        for (int i = 0; i < 120; i++) {   // scratches
            int x = p[0] + r.nextInt(p[2]), y = p[1] + r.nextInt(p[3]);
            g.setColor(new java.awt.Color(196, 192, 176, 24 + r.nextInt(40)));
            g.drawLine(x, y, x + r.nextInt(30) - 15, y + r.nextInt(8) - 4);
        }
        g.setClip(null);
    }

    /** One stroke cut by a hand: it wanders a little, its width changes on the way. */
    static void barScratch(java.awt.Graphics2D g, Random hand, java.awt.Color cut, java.awt.Color deep, double x0, double y0, double x1, double y1) {
        int parts = 4;
        double px = x0, py = y0, nx = -(y1 - y0), ny = x1 - x0, len = Math.max(1, Math.hypot(nx, ny));
        for (int i = 1; i <= parts; i++) {
            double t = i / (double) parts, off = i == parts ? 0 : (hand.nextDouble() - 0.5) * 2.4;
            double qx = x0 + (x1 - x0) * t + nx / len * off, qy = y0 + (y1 - y0) * t + ny / len * off;
            float w = 2f + hand.nextFloat() * 1.2f;
            g.setStroke(new java.awt.BasicStroke(w, java.awt.BasicStroke.CAP_ROUND, java.awt.BasicStroke.JOIN_ROUND));
            g.setColor(deep);
            g.draw(new java.awt.geom.Line2D.Double(px + 1, py + 1, qx + 1, qy + 1));
            g.setColor(cut);
            g.draw(new java.awt.geom.Line2D.Double(px, py, qx, qy));
            px = qx;
            py = qy;
        }
    }

    /**
     * The pictures of the last ones leaving (the mockup, 2026-10-31): the note left under the
     * poured glass, the mattress's ticking, the broken radio's front, the tally of days cut
     * into the wall (cut out: no wall round its strokes), the map with the way north, the
     * ammo's box, cardboard, the compass's face (cut out round).
     */
    static void barAtlasLeaving(BufferedImage img, java.awt.Graphics2D g, java.awt.Color ink, java.awt.Color cream) {
        // the note: a page torn out of a pad, a few words in pencil
        g.setColor(new java.awt.Color(214, 204, 178));
        g.fillRect(0, 192, 128, 96);
        g.setColor(new java.awt.Color(170, 182, 194));
        for (int l = 0; l < 6; l++) g.fillRect(4, 206 + l * 14, 120, 1);
        g.setColor(new java.awt.Color(196, 132, 120));
        g.fillRect(16, 196, 1, 92);
        g.setColor(new java.awt.Color(58, 58, 68));
        g.setFont(new java.awt.Font("Serif", java.awt.Font.ITALIC, 16));
        g.drawString("for whoever", 22, 218);
        g.drawString("comes next -", 26, 233);
        g.drawString("it's on me.", 30, 248);
        g.drawString("- J.", 82, 270);
        g.setComposite(java.awt.AlphaComposite.Clear);
        java.awt.Polygon torn = new java.awt.Polygon();
        torn.addPoint(0, 191);
        torn.addPoint(129, 191);
        for (int x = 128; x >= 0; x -= 8) torn.addPoint(x, 193 + (x / 8 % 3 == 0 ? 3 : x / 8 % 3));
        g.fill(torn);
        g.setComposite(java.awt.AlphaComposite.SrcOver);

        // the mattress's ticking: stripes along it, old stains
        for (int y = 0; y < 96; y++) {
            for (int x = 0; x < 128; x++) {
                int c = x % 16;
                double k = 0.92 + 0.08 * fbm(x / 9.0, y / 9.0, 16, 371, 2);
                double[] col = c >= 2 && c <= 4 ? new double[] {0.30, 0.36, 0.48} : c == 9 ? new double[] {0.48, 0.52, 0.58}
                    : new double[] {0.76, 0.73, 0.65};
                double stain = smooth(0.62, 0.78, fbm(x / 30.0, y / 22.0, 8, 372, 3));
                img.setRGB(128 + x, 192 + y, rgba(col[0] * k * (1 - 0.3 * stain), col[1] * k * (1 - 0.38 * stain), col[2] * k * (1 - 0.5 * stain), 1));
            }
        }

        // the radio's front (its right half, the left is broken off): the dial under a
        // cracked glass, the grille's cloth torn, two sockets for the knobs, one knob gone
        g.setColor(new java.awt.Color(62, 37, 22));
        g.fillRect(256, 192, 96, 96);
        g.setColor(new java.awt.Color(204, 188, 140));
        g.fillRect(262, 198, 84, 22);
        g.setColor(ink);
        for (int i = 0; i <= 20; i++) g.fillRect(266 + i * 4, 199, 1, i % 5 == 0 ? 6 : 3);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 8));
        String[] freq = {"55", "70", "90", "120", "160"};
        for (int i = 0; i < freq.length; i++) centred(g, freq[i], 270 + i * 17, 215);
        // (the needle is its own: bar_radio_needle, it moves)
        g.setColor(new java.awt.Color(236, 240, 242));
        g.setStroke(new java.awt.BasicStroke(1));
        g.drawPolyline(new int[] {262, 274, 281, 295, 306, 322, 346}, new int[] {214, 209, 212, 204, 207, 199, 202}, 7);
        g.drawPolyline(new int[] {295, 299, 297, 302}, new int[] {204, 211, 216, 220}, 4);
        g.setColor(new java.awt.Color(30, 25, 21));
        g.fillRect(262, 226, 84, 46);
        g.setColor(new java.awt.Color(8, 7, 6));
        g.fillPolygon(new int[] {266, 280, 286, 279, 284, 270, 264}, new int[] {232, 229, 238, 246, 257, 262, 249}, 7);
        g.setColor(new java.awt.Color(72, 44, 26));
        for (int y = 228; y < 272; y += 6) g.fillRect(262, y, 84, 3);
        g.setColor(new java.awt.Color(24, 16, 10));
        g.fillOval(272, 272, 14, 14);
        g.fillOval(320, 272, 14, 14);
        g.setColor(new java.awt.Color(140, 104, 76));
        g.fillPolygon(new int[] {352, 352, 338, 344}, new int[] {192, 210, 192, 199}, 4);
        Random sc = new Random(373);
        for (int i = 0; i < 9; i++) {
            int x = 258 + sc.nextInt(90), y = 194 + sc.nextInt(90);
            g.drawLine(x, y, x + sc.nextInt(15) - 7, y + sc.nextInt(9) - 4);
        }

        // the tally of days: groups of four and a fifth across, scratched by hand into the dark boards
        // (the author, 2026-11-01: dim as old cuts, no two strokes alike; straight and bright they stood out)
        java.awt.Color cut = new java.awt.Color(104, 86, 62), deep = new java.awt.Color(18, 13, 9);
        Random hand = new Random(1147);
        int[][] rows = {{4, 0}, {1, 3}};   // whole groups, single strokes after them
        for (int r = 0; r < rows.length; r++) {
            int y0 = 200 + r * 50, x = 392;
            for (int gi = 0; gi < rows[r][0] + 1; gi++) {
                int strokes = gi < rows[r][0] ? 4 : rows[r][1];
                int top = y0 + hand.nextInt(5) - 2, lean = hand.nextInt(7) - 3;
                for (int i = 0; i < strokes; i++) {
                    double sx = x + i * 7.5 + hand.nextDouble() * 3;
                    barScratch(g, hand, cut, deep, sx, top + hand.nextInt(5) - 2, sx + lean + hand.nextDouble() * 3 - 1.5, top + 34 + hand.nextInt(8));
                }
                if (gi < rows[r][0]) {
                    barScratch(g, hand, cut, deep, x - 4 + hand.nextInt(3), top + 30 + hand.nextInt(6), x + 26 + hand.nextInt(5), top + 4 + hand.nextInt(7));
                }
                x += 40 + hand.nextInt(8);
            }
        }
        g.setStroke(new java.awt.BasicStroke(1));

        // the map: roads, the river, its folds, and the way north drawn on it in red
        g.setColor(new java.awt.Color(206, 198, 170));
        g.fillRect(384, 320, 192, 144);
        g.setColor(new java.awt.Color(186, 192, 192));
        for (int x = 384; x < 576; x += 24) g.fillRect(x, 320, 1, 144);
        for (int y = 320; y < 464; y += 24) g.fillRect(384, y, 192, 1);
        g.setStroke(new java.awt.BasicStroke(3));
        g.setColor(new java.awt.Color(92, 124, 166));
        g.drawPolyline(new int[] {384, 410, 430, 452, 470, 500, 528, 552, 576}, new int[] {350, 344, 356, 348, 334, 340, 330, 338, 326}, 9);
        g.setColor(new java.awt.Color(176, 56, 44));
        g.drawPolyline(new int[] {400, 428, 460, 490, 516, 548}, new int[] {464, 430, 410, 384, 352, 320}, 6);
        g.setStroke(new java.awt.BasicStroke(2));
        g.setColor(new java.awt.Color(204, 170, 64));
        g.drawPolyline(new int[] {384, 420, 452, 470, 520, 576}, new int[] {420, 412, 424, 440, 446, 438}, 6);
        g.drawPolyline(new int[] {470, 476, 470, 482}, new int[] {440, 400, 372, 320}, 4);
        g.setColor(new java.awt.Color(150, 142, 118));
        g.setStroke(new java.awt.BasicStroke(1));
        g.drawLine(448, 320, 448, 464);
        g.drawLine(512, 320, 512, 464);
        g.drawLine(384, 392, 576, 392);
        g.setColor(ink);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 9));
        for (int[] t : new int[][] {{430, 444}, {500, 432}, {520, 362}, {470, 336}}) g.fillOval(t[0] - 2, t[1] - 2, 5, 5);
        g.drawString("MULDRAUGH", 402, 456);
        g.drawString("RIVERSIDE", 504, 426);
        g.drawString("LOUISVILLE", 522, 358);
        g.setColor(new java.awt.Color(184, 24, 24));
        g.setStroke(new java.awt.BasicStroke(3, java.awt.BasicStroke.CAP_ROUND, java.awt.BasicStroke.JOIN_ROUND, 1, new float[] {7, 5}, 0));
        g.drawPolyline(new int[] {432, 452, 474, 488, 486, 500}, new int[] {442, 418, 392, 366, 346, 328}, 6);
        g.setStroke(new java.awt.BasicStroke(3, java.awt.BasicStroke.CAP_ROUND, java.awt.BasicStroke.JOIN_ROUND));
        g.drawOval(424, 434, 16, 16);
        g.drawLine(500, 328, 492, 338);
        g.drawLine(500, 328, 506, 339);
        g.setFont(new java.awt.Font("Serif", java.awt.Font.BOLD | java.awt.Font.ITALIC, 15));
        g.drawString("N?", 510, 340);
        g.setStroke(new java.awt.BasicStroke(1));

        // the ammo's box: olive, stencilled
        g.setColor(new java.awt.Color(60, 64, 40));
        g.fillRect(640, 256, 128, 96);
        g.setColor(new java.awt.Color(196, 178, 96));
        g.drawRect(646, 262, 115, 83);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 30));
        centred(g, "9MM", 704, 304);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 11));
        centred(g, "50 CARTRIDGES", 704, 328);

        // cardboard: kraft, its fibres, a print, a strip of tape
        for (int y = 0; y < 96; y++) {
            for (int x = 0; x < 128; x++) {
                double k = 0.88 + 0.16 * fbm(x / 3.0, y / 14.0, 32, 374, 2);
                img.setRGB(768 + x, 256 + y, rgba(0.58 * k, 0.43 * k, 0.27 * k, 1));
            }
        }
        g.setColor(new java.awt.Color(62, 46, 32));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 13));
        centred(g, "THIS SIDE UP", 832, 300);
        for (int ax : new int[] {808, 856}) g.fillPolygon(new int[] {ax - 7, ax, ax + 7}, new int[] {286, 274, 286}, 3);
        g.setColor(new java.awt.Color(196, 170, 120, 170));
        g.fillRect(768, 318, 128, 14);

        // the compass's face, round
        g.setColor(new java.awt.Color(150, 120, 52));
        g.fillOval(897, 321, 62, 62);
        g.setColor(new java.awt.Color(226, 220, 198));
        g.fillOval(902, 326, 52, 52);
        g.setColor(ink);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 9));
        centred(g, "N", 928, 336);
        centred(g, "S", 928, 375);
        centred(g, "W", 908, 355);
        centred(g, "E", 948, 355);
        g.setColor(new java.awt.Color(176, 30, 26));
        g.fillPolygon(new int[] {928, 932, 928, 924}, new int[] {334, 352, 352, 352}, 4);
        g.setColor(new java.awt.Color(240, 240, 236));
        g.fillPolygon(new int[] {924, 932, 928}, new int[] {352, 352, 370}, 3);
    }

    /** A round thing turned around local Y: profile {y, radius} from the bottom up. */
    static void barLathe(Mesh m, int sides, double[][] prof, Xf xf, double[] uv, boolean top, boolean bottom) {
        barLathe(m, sides, prof, xf, uv, top, bottom, false);
    }

    /**
     * label: a printed label, its picture once on each half so that it reads the
     * right way round from any side (the preview of the game's frame, 2026-10-31:
     * the cans turned about showed "SNAEB").
     */
    static void barLathe(Mesh m, int sides, double[][] prof, Xf xf, double[] uv, boolean top, boolean bottom, boolean label) {
        double[] o = xf.point(0, 0, 0);
        for (int i = 0; i < sides; i++) {
            double a0 = 2 * Math.PI * i / sides, a1 = 2 * Math.PI * (i + 1) / sides;
            for (int s = 0; s + 1 < prof.length; s++) {
                double y0 = prof[s][0], r0 = prof[s][1], y1 = prof[s + 1][0], r1 = prof[s + 1][1];
                double dy = y1 - y0, dr = r1 - r0, l = Math.max(1e-9, Math.sqrt(dy * dy + dr * dr));
                double[] n0 = dirOf(xf, o, Math.cos(a0) * dy / l, -dr / l, Math.sin(a0) * dy / l);
                double[] n1 = dirOf(xf, o, Math.cos(a1) * dy / l, -dr / l, Math.sin(a1) * dy / l);
                double u0 = aroundU(uv, i, sides, label, false), u1 = aroundU(uv, i + 1, sides, label, true);
                double v0 = uv[1] + (uv[3] - uv[1]) * s / (prof.length - 1), v1 = uv[1] + (uv[3] - uv[1]) * (s + 1) / (prof.length - 1);
                int i0 = m.vert(xf.point(r0 * Math.cos(a0), y0, r0 * Math.sin(a0)), n0, u0, v0);
                int i1 = m.vert(xf.point(r1 * Math.cos(a0), y1, r1 * Math.sin(a0)), n0, u0, v1);
                int i2 = m.vert(xf.point(r1 * Math.cos(a1), y1, r1 * Math.sin(a1)), n1, u1, v1);
                int i3 = m.vert(xf.point(r0 * Math.cos(a1), y0, r0 * Math.sin(a1)), n1, u1, v0);
                m.tris.add(new int[] {i0, i1, i2});
                m.tris.add(new int[] {i0, i2, i3});
            }
            double[] mid = {(uv[0] + uv[2]) / 2, (uv[1] + uv[3]) / 2};
            if (top) {
                double[] e = prof[prof.length - 1];
                m.tri(xf.point(0, e[0], 0), xf.point(e[1] * Math.cos(a1), e[0], e[1] * Math.sin(a1)),
                    xf.point(e[1] * Math.cos(a0), e[0], e[1] * Math.sin(a0)), mid, mid, mid);
            }
            if (bottom) {
                double[] e = prof[0];
                m.tri(xf.point(0, e[0], 0), xf.point(e[1] * Math.cos(a0), e[0], e[1] * Math.sin(a0)),
                    xf.point(e[1] * Math.cos(a1), e[0], e[1] * Math.sin(a1)), mid, mid, mid);
            }
        }
    }

    /**
     * Round a turned thing: the whole picture over its half towards +z, read from
     * outside; the other half its mirror, or, for a label, the picture again (end:
     * the u where a face ends - at the half's seam the picture starts over).
     */
    static double aroundU(double[] uv, int i, int sides, boolean label, boolean end) {
        double t = 2.0 * i / sides;
        if (label) {
            if (t > 1 || (t == 1 && !end)) t -= 1;
        } else if (t > 1) {
            t = 2 - t;
        }
        return uv[2] - (uv[2] - uv[0]) * t;
    }

    static double[] dirOf(Xf xf, double[] o, double x, double y, double z) {
        double[] p = xf.point(x, y, z);
        double nx = p[0] - o[0], ny = p[1] - o[1], nz = p[2] - o[2];
        double l = Math.max(1e-9, Math.sqrt(nx * nx + ny * ny + nz * nz));
        return new double[] {nx / l, ny / l, nz / l};
    }

    /** A rod from a to b, thinning from ra to rb. */
    static void barLimb(Mesh m, Xf root, double[] a, double[] b, double ra, double rb, double[] uv) {
        double dx = b[0] - a[0], dy = b[1] - a[1], dz = b[2] - a[2];
        double len = Math.sqrt(dx * dx + dy * dy + dz * dz);
        dx /= len;
        dy /= len;
        dz /= len;
        // x, y, z of the rod's own axes (y along it), right-handed
        double ox = Math.abs(dy) > 0.9 ? 1 : 0, oy = Math.abs(dy) > 0.9 ? 0 : 1;
        // z = o x d
        double zx = oy * dz, zy = -ox * dz, zz = ox * dy - oy * dx;
        double zl = Math.sqrt(zx * zx + zy * zy + zz * zz);
        zx /= zl;
        zy /= zl;
        zz /= zl;
        // x = d x z
        double xx = dy * zz - dz * zy, xy = dz * zx - dx * zz, xz = dx * zy - dy * zx;
        Xf own = new Xf(new double[] {xx, dx, zx, a[0], xy, dy, zy, a[1], xz, dz, zz, a[2]});
        barLathe(m, 6, new double[][] {{0, ra}, {len, rb}}, root.mul(own), uv, true, false);
    }

    /** A box by its middle. */
    static void barBox(Mesh m, Xf root, double sx, double sy, double sz, double cx, double cy, double cz, int mat) {
        double[] uv = barMat(mat);
        m.box(sx, sy, sz, root.mul(Xf.move(cx, cy, cz)), uv, uv);
    }

    /** A flat thing lying face up, its top edge away from the camera, turned by deg. */
    static void barFlat(Mesh m, Xf root, double w, double d, double x, double y, double z, double deg, double[] uv) {
        Xf f = root.mul(Xf.move(x, y, z)).mul(Xf.rotY(deg));
        double a = w / 2, b = d / 2;
        m.quad(f.point(-a, 0, b), f.point(a, 0, b), f.point(a, 0, -b), f.point(-a, 0, -b), uv);
    }

    /** A flat thing on a wall, in the wall's own plane (facing local +z). */
    static void barSheet(Mesh m, Xf root, double w, double h, double x, double y, double z, double deg, double[] uv) {
        Xf f = root.mul(Xf.move(x, y, z)).mul(Xf.rotZ(deg));
        double a = w / 2, b = h / 2;
        m.quad(f.point(-a, -b, 0), f.point(a, -b, 0), f.point(a, b, 0), f.point(-a, b, 0), uv);
    }

    /** A full bottle: dark glass, a crown cap. */
    static void barBottle(Mesh m, Xf at, int glass, int[] label) {
        barBottleBody(m, at, glass, label);
        barLathe(m, 8, new double[][] {{0.25, 0.014}, {0.262, 0.013}}, at, barMat(M_BRASS), true, false);
    }

    /** An empty one: the same in pale glass, open. */
    static void barEmpty(Mesh m, Xf at, int glass, int[] label) {
        barBottleBody(m, at, glass == M_GREEN ? M_GREEN_E : M_BROWN_E, label);
    }

    static void barBottleBody(Mesh m, Xf at, int glass, int[] label) {
        barLathe(m, 10, new double[][] {{0, 0.033}, {0.13, 0.034}, {0.17, 0.014}, {0.25, 0.012}}, at, barMat(glass), true, true);
        double[] l = barPic(label);
        barLathe(m, 10, new double[][] {{0.03, 0.0348}, {0.115, 0.0352}}, at, l, false, false, true);
    }

    /** A bottle on its side: lying along local x, its neck to +x. */
    static void barBottleDown(Mesh m, Xf at, int glass, int[] label) {
        barEmpty(m, at.mul(Xf.move(0, 0.034, 0)).mul(Xf.rotZ(-90)), glass, label);
    }

    /**
     * A quad across a sweep, its corners' normals given: wound to face them (the shapes below
     * turn both ways).
     */
    static void barFaced(Mesh m, double[][] p, double[][] n, double[] u, double[] v) {
        double[] g = Mesh.normal(p[0], p[1], p[2]);
        int[] i = new int[4];
        for (int k = 0; k < 4; k++) i[k] = m.vert(p[k], n[k], u[k], v[k]);
        if (g[0] * n[0][0] + g[1] * n[0][1] + g[2] * n[0][2] >= 0) {
            m.tris.add(new int[] {i[0], i[1], i[2]});
            m.tris.add(new int[] {i[0], i[2], i[3]});
        } else {
            m.tris.add(new int[] {i[0], i[2], i[1]});
            m.tris.add(new int[] {i[0], i[3], i[2]});
        }
    }

    static final double JW = 0.86, JSPRING = 1.24, JFRONT = 0.3;   // the jukebox: its width, where the arch starts, its front

    /**
     * A moulding along the jukebox's arch: from y0 up one side, round, down the other. prof:
     * {inset from the outer edge, z} from the outside inwards; a surface walked this way
     * faces up and out.
     */
    static void jukeSweep(Mesh m, double[][] prof, double y0, double[] uv) {
        jukeSweep(m, prof, y0, uv, 0, 30);
    }

    /** Only its stretch from..to, of 30: 0 is the left side, 1..28 the arch, 29 the right side. */
    static void jukeSweep(Mesh m, double[][] prof, double y0, double[] uv, int from, int to) {
        int arc = 28, count = arc + 3;
        double out = JW / 2;
        for (int s = 0; s + 1 < prof.length; s++) {
            double dOut0 = prof[s][0] - prof[s + 1][0], dz0 = prof[s + 1][1] - prof[s][1];
            double na0 = 0, nz0 = 0, na1 = 0, nz1 = 0;
            for (int e = 0; e < 2; e++) {   // the normal at each end: of the parts meeting there
                int at = s + e;
                double na = 0, nz = 0;
                for (int q = Math.max(0, at - 1); q <= Math.min(prof.length - 2, at); q++) {
                    double dO = prof[q][0] - prof[q + 1][0], dZ = prof[q + 1][1] - prof[q][1], l = Math.max(1e-9, Math.hypot(dO, dZ));
                    na += dZ / l;
                    nz += -dO / l;
                }
                double l = Math.max(1e-9, Math.hypot(na, nz));
                if (e == 0) { na0 = na / l; nz0 = nz / l; } else { na1 = na / l; nz1 = nz / l; }
            }
            for (int t = from; t < to; t++) {
                double[][] p = new double[4][], n = new double[4][];
                double[] u = new double[4], v = new double[4];
                for (int c = 0; c < 4; c++) {
                    int tt = t + (c == 1 || c == 2 ? 1 : 0);
                    boolean second = c >= 2;
                    double r = out - prof[s + (second ? 1 : 0)][0], z = prof[s + (second ? 1 : 0)][1];
                    double na = second ? na1 : na0, nz = second ? nz1 : nz0;
                    double px, py, ox, oy;
                    if (tt == 0) { px = -r; py = y0; ox = -1; oy = 0; }
                    else if (tt == count - 1) { px = r; py = y0; ox = 1; oy = 0; }
                    else {
                        double a = Math.PI - Math.PI * (tt - 1) / arc;
                        ox = Math.cos(a);
                        oy = Math.sin(a);
                        px = r * ox;
                        py = JSPRING + r * oy;
                    }
                    p[c] = new double[] {px, py, z};
                    n[c] = new double[] {ox * na, oy * na, nz};
                    u[c] = uv[0] + (uv[2] - uv[0]) * tt / (count - 1.0);
                    v[c] = uv[1] + (uv[3] - uv[1]) * (s + (second ? 1 : 0)) / (prof.length - 1.0);
                }
                barFaced(m, p, n, u, v);
            }
        }
    }

    /** The flat shape of the arch at an inset, from y0 up: a sheet at z. */
    static void jukeSheet(Mesh m, double inset, double y0, double z, double[] uv, boolean back) {
        double r = JW / 2 - inset;
        double[] mid = {(uv[0] + uv[2]) / 2, (uv[1] + uv[3]) / 2};
        double[] c = {0, JSPRING, z};
        int arc = 28;
        for (int i = 0; i < arc; i++) {
            double a0 = Math.PI * i / arc, a1 = Math.PI * (i + 1) / arc;
            double[] p0 = {r * Math.cos(a0), JSPRING + r * Math.sin(a0), z}, p1 = {r * Math.cos(a1), JSPRING + r * Math.sin(a1), z};
            if (back) m.tri(c, p1, p0, mid, mid, mid); else m.tri(c, p0, p1, mid, mid, mid);
        }
        double[] a = {-r, y0, z}, b = {r, y0, z}, d = {r, JSPRING, z}, e = {-r, JSPRING, z};
        if (back) m.quad(b, a, e, d, uv); else m.quad(a, b, d, e, uv);
    }

    /** A rounded band across a sweep's profile: from inset a to b, h proud of z. */
    static double[][] jukeTube(double a, double b, double z, double h) {
        int n = 6;
        double[][] prof = new double[n + 1][];
        for (int i = 0; i <= n; i++) {
            double t = Math.PI * i / n;
            prof[i] = new double[] {(a + b) / 2 - (b - a) / 2 * Math.cos(t), z + h * Math.sin(t)};
        }
        return prof;
    }

    /**
     * A first aid kit forced open (the author, 2026-11-01), its hinge at the back, local +z to the
     * room: the tin nearly empty, a used bandage run out over the counter, empty bottles, the scissors.
     */
    static void barAidKit(Mesh m, Xf at) {
        Random r = new Random(77);
        double w = 0.27, d = 0.18, h = 0.075, t = 0.005;
        jukeBox(m, at, w, 0.004, d, 0, 0.002, 0, jukeWorn(P_WENAMEL, r));
        jukeBox(m, at, w, h, t, 0, h / 2, d / 2, jukeWorn(P_WENAMEL, r));
        jukeBox(m, at, w, h, t, 0, h / 2, -d / 2, jukeWorn(P_WENAMEL, r));
        jukeBox(m, at, t, h, d, w / 2, h / 2, 0, jukeWorn(P_WENAMEL, r));
        jukeBox(m, at, t, h, d, -w / 2, h / 2, 0, jukeWorn(P_WENAMEL, r));
        barSheet(m, at, 0.1, 0.06, 0, h / 2, d / 2 + 0.003, 0, barPic(P_AIDFRONT));
        jukeBox(m, at, 0.05, 0.016, 0.008, 0.09, h - 0.012, d / 2 + 0.005, barMat(M_RUST));   // the catch, bent
        // the lid thrown back, sprung off one hinge, the list inside it
        Xf lid = at.mul(Xf.move(0, h, -d / 2)).mul(Xf.rotZ(4)).mul(Xf.rotX(-112));
        jukeBox(m, lid, w, 0.006, d, 0, 0, d / 2, jukeWorn(P_WENAMEL, r));
        Xf in = lid.mul(Xf.move(0, -0.004, d / 2)).mul(Xf.rotX(180));
        barFlat(m, in, 0.13, 0.095, 0, 0, 0, 0, barPic(P_AIDNOTE));
        // what is left in it: the rest of the roll of gauze, an empty bottle fallen over
        barLathe(m, 14, new double[][] {{-0.024, 0.026}, {-0.02, 0.029}, {0.02, 0.029}, {0.024, 0.026}}, at.mul(Xf.move(-0.07, 0.031, 0.0)).mul(Xf.rotZ(90)).mul(Xf.rotY(14)), barMat(M_TOWEL), true, true);
        barLathe(m, 8, new double[][] {{0, 0.017}, {0.055, 0.017}, {0.066, 0.009}, {0.078, 0.008}}, at.mul(Xf.move(0.03, 0.021, -0.03)).mul(Xf.rotY(30)).mul(Xf.rotZ(-90)), barMat(M_BROWN_E), true, true);
        // the gauze run off the roll, over the tin's edge and away across the counter: a narrow
        // soft strip, sagging, wandering, creased, its end frayed thin and stained (the author,
        // 2026-11-01: it read as square plates)
        double[][] way = {{-0.07, 0.058, 0.0}, {0.03, 0.05, -0.012}, {0.125, 0.083, -0.006}, {0.15, 0.081, 0.0}, {0.168, 0.042, 0.012}, {0.188, 0.005, 0.034},
            {0.24, 0.003, 0.074}, {0.3, 0.006, 0.058}, {0.345, 0.003, 0.1}, {0.315, 0.007, 0.16}, {0.25, 0.003, 0.172}, {0.222, 0.005, 0.215}, {0.272, 0.003, 0.25}};
        double[] b = barPic(P_BANDAGE);
        int perPart = 6, parts = (way.length - 1) * perPart;
        double[][] left = new double[parts + 1][], right = new double[parts + 1][];
        for (int i = 0; i <= parts; i++) {
            int k = Math.min(way.length - 2, i / perPart);
            double f = i / (double) perPart - k;
            double[] p0 = way[Math.max(0, k - 1)], p1 = way[k], p2 = way[k + 1], p3 = way[Math.min(way.length - 1, k + 2)];
            double[] q = new double[3], tan = new double[3];
            for (int c = 0; c < 3; c++) {
                q[c] = 0.5 * (2 * p1[c] + (p2[c] - p0[c]) * f + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * f * f + (3 * p1[c] - p0[c] - 3 * p2[c] + p3[c]) * f * f * f);
                tan[c] = p2[c] - p0[c];
            }
            double l = Math.max(1e-6, Math.hypot(tan[0], tan[2]));
            double along = i / (double) parts;
            double hw = (0.0155 + 0.0025 * Math.sin(i * 1.7)) * (along > 0.93 ? (1 - along) / 0.07 * 0.8 + 0.2 : 1);
            double crease = 0.0018 * Math.sin(i * 2.3), px = -tan[2] / l * hw, pz = tan[0] / l * hw;
            left[i] = at.point(q[0] + px, Math.max(0.0015, q[1] + crease + 0.0016), q[2] + pz);
            right[i] = at.point(q[0] - px, Math.max(0.0015, q[1] - crease), q[2] - pz);
        }
        for (int i = 0; i < parts; i++) {
            double u0 = b[0] + (b[2] - b[0]) * i / parts, u1 = b[0] + (b[2] - b[0]) * (i + 1) / parts;
            double[] ua = {u0, b[1]}, ub = {u1, b[1]}, uc = {u1, b[3]}, ud = {u0, b[3]};
            m.tri(left[i], left[i + 1], right[i + 1], ua, ub, uc);
            m.tri(left[i], right[i + 1], right[i], ua, uc, ud);
            m.tri(left[i], right[i + 1], left[i + 1], ua, uc, ub);   // both faces: it turns over on its way
            m.tri(left[i], right[i], right[i + 1], ua, ud, uc);
        }
        // by it: two empty brown bottles, one with no cap, the cap; a torn packet; the scissors
        barLathe(m, 8, new double[][] {{0, 0.02}, {0.06, 0.02}, {0.072, 0.01}, {0.085, 0.009}}, at.mul(Xf.move(0.17, 0, -0.16)), barMat(M_BROWN_E), true, true);
        barLathe(m, 8, new double[][] {{0, 0.017}, {0.05, 0.017}, {0.06, 0.009}, {0.072, 0.008}}, at.mul(Xf.move(0.4, 0.017, 0.22)).mul(Xf.rotY(50)).mul(Xf.rotZ(90)), barMat(M_BROWN_E), true, true);
        barLathe(m, 8, new double[][] {{0, 0.011}, {0.012, 0.011}}, at.mul(Xf.move(0.3, 0, -0.02)), barMat(M_WAX), true, false);
        barFlat(m, at, 0.09, 0.06, -0.03, 0.002, 0.17, 24, barMat(M_PAPER));
        barFlat(m, at, 0.05, 0.05, 0.03, 0.003, 0.2, -30, barMat(M_TOWEL));
        Xf sc = at.mul(Xf.move(0.13, 0.004, 0.22)).mul(Xf.rotY(-35));
        for (int k = -1; k <= 1; k += 2) {
            barBox(m, sc.mul(Xf.rotY(k * 9)), 0.1, 0.003, 0.006, 0.05, 0, 0, M_METAL);
            barLathe(m, 8, new double[][] {{0, 0.012}, {0.003, 0.012}}, sc.mul(Xf.rotY(k * 12)).mul(Xf.move(-0.03, 0, 0)), barMat(M_IRON), true, false);
        }
    }

    /**
     * An open journal lying on its back (the author, 2026-11-02): a leather cover, the two
     * blocks of pages swelling from the fold, a ribbon.
     */
    static void barJournal(Mesh m, Xf at) {
        double w = 0.42, d = 0.27, base = 0.008;
        jukeBox(m, at, w + 0.02, 0.006, d + 0.02, 0, 0.003, 0, barMat(M_LEATHER));
        double[] pic = barPic(P_JOURNAL);
        int n = 20;
        for (int i = 0; i < n; i++) {
            double t0 = -1 + 2.0 * i / n, t1 = -1 + 2.0 * (i + 1) / n;
            double x0 = t0 * w / 2, x1 = t1 * w / 2, y0 = base + journalPage(t0), y1 = base + journalPage(t1), z = d / 2;
            double u0 = pic[0] + (pic[2] - pic[0]) * i / n, u1 = pic[0] + (pic[2] - pic[0]) * (i + 1) / n;
            m.quad(at.point(x0, y0, z), at.point(x1, y1, z), at.point(x1, y1, -z), at.point(x0, y0, -z), new double[] {u0, pic[1], u1, pic[3]});
            double[] edge = barMat(M_PAPER);
            m.quad(at.point(x0, base - 0.002, z), at.point(x1, base - 0.002, z), at.point(x1, y1, z), at.point(x0, y0, z), edge);
            m.quad(at.point(x1, base - 0.002, -z), at.point(x0, base - 0.002, -z), at.point(x0, y0, -z), at.point(x1, y1, -z), edge);
        }
        for (int sx = -1; sx <= 1; sx += 2) {   // the pages' outer edges
            double x = sx * w / 2, y = base + journalPage(sx), z = d / 2;
            double[] a = at.point(x, base - 0.002, sx * z), b = at.point(x, base - 0.002, -sx * z), c = at.point(x, y, -sx * z), e = at.point(x, y, sx * z);
            m.quad(a, b, c, e, barMat(M_PAPER));
        }
        // the ribbon out of the fold, over the front edge
        barFlat(m, at, 0.012, 0.075, 0.003, base + 0.004, d / 2 + 0.026, 7, barMat(M_JRED));
    }

    /**
     * A page the wind turns over (the author, 2026-11-02), from the fold at x 0: lying on the right
     * of the book as barJournal's does, its under side the left page's picture. room.vert turns it
     * (uPage) and it lands the same as what's there; it's only up while it turns.
     */
    static void barJournalPage(Mesh m) {
        double w = 0.42, d = 0.27, base = 0.008, lie = 0.0015;
        double[] pic = barPic(P_JOURNAL);
        double mid = (pic[0] + pic[2]) / 2, z = d / 2;
        int n = 10;
        for (int i = 0; i < n; i++) {
            double t0 = (double) i / n, t1 = (i + 1.0) / n;
            double x0 = t0 * w / 2, x1 = t1 * w / 2, y0 = base + lie + journalPage(t0), y1 = base + lie + journalPage(t1);
            m.quad(new double[] {x0, y0, z}, new double[] {x1, y1, z}, new double[] {x1, y1, -z}, new double[] {x0, y0, -z},
                new double[] {mid + (pic[2] - mid) * t0, pic[1], mid + (pic[2] - mid) * t1, pic[3]});
            m.quad(new double[] {x1, y1, z}, new double[] {x0, y0, z}, new double[] {x0, y0, -z}, new double[] {x1, y1, -z},
                new double[] {mid - (mid - pic[0]) * t1, pic[1], mid - (mid - pic[0]) * t0, pic[3]});
        }
    }

    /** How high the pages stand across the book: low in the fold, swelling, down at the edges. */
    static double journalPage(double t) {
        double a = Math.abs(t);
        return 0.024 * Math.pow(Math.sin(Math.PI * Math.pow(a, 0.75) * 0.82 + 0.1), 1.0) * (0.55 + 0.45 * (1 - a));
    }

    /** A worn patch for a small part: a piece of the strip, a different one each time. */
    static double[] jukeWorn(int[] p, Random r) {
        int w = 40 + r.nextInt(60), h = 20 + r.nextInt(30);
        return barCell(p[0] + r.nextInt(p[2] - w), p[1] + r.nextInt(p[3] - h), w, h);
    }

    static void jukeBox(Mesh m, Xf root, double sx, double sy, double sz, double cx, double cy, double cz, double[] uv) {
        m.box(sx, sy, sz, root.mul(Xf.move(cx, cy, cz)), uv, uv);
    }

    /** A disc lying in local y, a wedge of it gone (between the angles, degrees). */
    static void jukeDisc(Mesh m, Xf at, double r, double y, double[] uv, double gapFrom, double gapTo) {
        double[] mid = {(uv[0] + uv[2]) / 2, (uv[1] + uv[3]) / 2};
        int n = 40;
        for (int i = 0; i < n; i++) {
            double d0 = 360.0 * i / n, d1 = 360.0 * (i + 1) / n;
            if (d1 > gapFrom && d0 < gapTo) continue;
            double a0 = Math.toRadians(d0), a1 = Math.toRadians(d1);
            m.tri(at.point(0, y, 0), at.point(r * Math.cos(a1), y, r * Math.sin(a1)), at.point(r * Math.cos(a0), y, r * Math.sin(a0)), mid, mid, mid);
        }
    }

    /** A framed picture on the wall (its face +z, against z 0), tilted a little as nobody has set it right. */
    static void wallFrame(Mesh m, double x, double y, double w, double h, double tilt, int[] pic, double[] frame) {
        Xf at = Xf.move(x, y, 0).mul(Xf.rotZ(tilt));
        double f = 0.024;
        jukeBox(m, at, w + 2 * f, f, 0.022, 0, h / 2 + f / 2, 0.011, frame);
        jukeBox(m, at, w + 2 * f, f, 0.022, 0, -h / 2 - f / 2, 0.011, frame);
        jukeBox(m, at, f, h, 0.022, -w / 2 - f / 2, 0, 0.011, frame);
        jukeBox(m, at, f, h, 0.022, w / 2 + f / 2, 0, 0.011, frame);
        barSheet(m, at, w, h, 0, 0, 0.012, 0, barPic(pic));
    }

    /**
     * What hangs on the wall by the left window (the author, 2026-11-02: what a bar has up): the
     * flag on its nails, sagging between them, its people in frames, the calendar, a plate. Room's x and y; z 0 is before the wall.
     */
    /** A can standing at its foot, its label and its lid. */
    static void supplyCan(Mesh m, Xf at, int[] pic) {
        double r = 0.042, h = 0.12;
        barLathe(m, 14, new double[][] {{0, r}, {h, r}}, at, barPic(pic), false, false, true);
        barLathe(m, 14, new double[][] {{h, r}, {h + 0.003, r * 0.94}}, at, barMat(M_TIN), true, false);
    }

    /** A closed carton standing at its foot. */
    static void supplyCarton(Mesh m, Xf at, double w, double h, double d, int[] pic) {
        m.box(w, h, d, at.mul(Xf.move(0, h / 2, 0)), barPic(pic), barMat(M_CARDBOARD));
        barBox(m, at, 0.06, 0.002, d, 0, h + 0.001, 0, M_CREAM);
    }

    /**
     * The stockpile by the flag (the author, 2026-11-02: boxes, cans and the other things it takes
     * to sit out a winter; the bucket went). Made round x 0, z 0 with the wall at z -1.
     */
    static void barSupplies(String name) throws IOException {
        Mesh m = new Mesh();
        Xf id = Xf.move(0, 0, 0);
        Random r = new Random(1102);
        int[][] cans = {P_CAN, P_CAN_SOUP, P_CAN_PEACHES, P_CAN_CORN, P_CAN_TUNA};
        // against the wall: cartons on cartons
        Xf a = Xf.move(-0.72, 0, -0.68).mul(Xf.rotY(3));
        supplyCarton(m, a, 0.56, 0.38, 0.42, P_BOXCANS);
        supplyCarton(m, a.mul(Xf.move(0.02, 0.385, 0.01)).mul(Xf.rotY(-6)), 0.54, 0.36, 0.4, P_BOXCANS);
        supplyCarton(m, a.mul(Xf.move(-0.03, 0.75, 0.0)).mul(Xf.rotY(11)), 0.44, 0.27, 0.32, P_BOXWATER);
        supplyCarton(m, Xf.move(-1.27, 0, -0.6).mul(Xf.rotY(-14)), 0.44, 0.3, 0.34, P_BOXRICE);
        // the crate from the relief, a board of its lid gone; things on it
        Xf b = Xf.move(0.02, 0, -0.66).mul(Xf.rotY(-4));
        m.box(0.74, 0.44, 0.5, b.mul(Xf.move(0, 0.22, 0)), barPic(P_CRATE), barMat(M_PLANK));
        for (double y : new double[] {0.03, 0.41}) {
            barBox(m, b, 0.78, 0.05, 0.03, 0, y, 0.26, M_DARK);
            barBox(m, b, 0.03, 0.05, 0.52, -0.38, y, 0, M_DARK);
            barBox(m, b, 0.03, 0.05, 0.52, 0.38, y, 0, M_DARK);
        }
        Xf topOf = b.mul(Xf.move(0, 0.44, 0));
        // the ammunition, the paper's rolls on it
        Xf am = topOf.mul(Xf.move(-0.15, 0, 0.02)).mul(Xf.rotY(9));
        m.box(0.3, 0.16, 0.15, am.mul(Xf.move(0, 0.08, 0)), barPic(P_AMMOBOX), barMat(M_OLIVE));
        barBox(m, am, 0.31, 0.022, 0.16, 0, 0.165, 0, M_OLIVE);
        barBox(m, am, 0.1, 0.012, 0.02, 0, 0.183, 0, M_IRON);
        for (double[] t : new double[][] {{0.2, 0.08}, {0.32, -0.05}, {0.25, -0.1}}) {
            Xf roll = topOf.mul(Xf.move(t[0], 0, t[1]));
            barLathe(m, 14, new double[][] {{0, 0.055}, {0.105, 0.055}}, roll, barMat(M_PAPER), false, false);
            barLathe(m, 14, new double[][] {{0.105, 0.055}, {0.1051, 0.02}}, roll, barMat(M_PAPER), false, false);
            barLathe(m, 10, new double[][] {{0.1051, 0.02}, {0.09, 0.019}}, roll, barMat(M_CARDBOARD), true, false);
        }
        // flour: two sacks against the wall, a third lying over their feet
        double[][] sack = {{0, 0.13}, {0.04, 0.17}, {0.3, 0.19}, {0.52, 0.16}, {0.62, 0.07}, {0.64, 0.03}, {0.7, 0.05}};
        for (double[] t : new double[][] {{0.72, -0.75, 12, 2}, {1.14, -0.72, -9, -3}}) {
            Xf sa = Xf.move(t[0], 0, t[1]).mul(Xf.rotY(t[2])).mul(Xf.rotZ(t[3])).mul(Xf.scale(1, 1, 0.68));
            barLathe(m, 14, sack, sa, barPic(P_SACK), true, true, true);
            barLathe(m, 8, new double[][] {{0.625, 0.045}, {0.655, 0.045}}, sa, barMat(M_BLACK), false, false);
        }
        Xf lying = Xf.move(0.95, 0.15, -0.34).mul(Xf.rotY(-7)).mul(Xf.rotZ(87)).mul(Xf.move(0, -0.33, 0)).mul(Xf.scale(1, 1, 0.72));
        barLathe(m, 14, sack, lying, barPic(P_SACK), true, true, true);
        // in front: a carton open, the cans in it
        Xf o = Xf.move(-0.42, 0, -0.08).mul(Xf.rotY(17));
        double ow = 0.52, oh = 0.28, od = 0.38, fl = 0.17;
        m.box(ow, oh, 0.008, o.mul(Xf.move(0, oh / 2, od / 2)), barPic(P_BOXCANS), barMat(M_CARDBOARD));
        m.box(ow, oh, 0.008, o.mul(Xf.move(0, oh / 2, -od / 2)), barPic(P_BOXCANS), barMat(M_CARDBOARD));
        barBox(m, o, 0.008, oh, od, -ow / 2, oh / 2, 0, M_CARDBOARD);
        barBox(m, o, 0.008, oh, od, ow / 2, oh / 2, 0, M_CARDBOARD);
        barBox(m, o, ow, 0.16, od, 0, 0.08, 0, M_BLACK);
        m.box(ow, 0.008, fl, o.mul(Xf.move(0, oh, -od / 2)).mul(Xf.rotX(-38)).mul(Xf.move(0, 0, -fl / 2)), barMat(M_CARDBOARD), barMat(M_CARDBOARD));
        m.box(ow, 0.008, fl, o.mul(Xf.move(0, oh, od / 2)).mul(Xf.rotX(55)).mul(Xf.move(0, 0, fl / 2)), barMat(M_CARDBOARD), barMat(M_CARDBOARD));
        m.box(fl, 0.008, od, o.mul(Xf.move(ow / 2, oh, 0)).mul(Xf.rotZ(33)).mul(Xf.move(fl / 2, 0, 0)), barMat(M_CARDBOARD), barMat(M_CARDBOARD));
        m.box(fl, 0.008, od, o.mul(Xf.move(-ow / 2, oh, 0)).mul(Xf.rotZ(-48)).mul(Xf.move(-fl / 2, 0, 0)), barMat(M_CARDBOARD), barMat(M_CARDBOARD));
        for (int i = 0; i < 5; i++) {
            for (int k = 0; k < 3; k++) {
                if (i == 3 && k == 1) continue;   // (some taken)
                supplyCan(m, o.mul(Xf.move(-0.18 + i * 0.09, 0.16, -0.1 + k * 0.1)).mul(Xf.rotY(r.nextDouble() * 360)), cans[r.nextInt(cans.length)]);
            }
        }
        // a stack of cans on the floor, as somebody counted them
        Xf st = Xf.move(0.32, 0, 0.02).mul(Xf.rotY(-11));
        double step = 0.092;
        for (int layer = 0; layer < 3; layer++) {
            int n = 4 - layer;
            for (int i = 0; i < n; i++) {
                for (int k = 0; k < Math.max(1, 2 - layer); k++) {
                    supplyCan(m, st.mul(Xf.move((i - (n - 1) / 2.0) * step, layer * 0.124, k * step)).mul(Xf.rotY(r.nextDouble() * 360)), cans[r.nextInt(cans.length)]);
                }
            }
        }
        // one rolled off
        supplyCan(m, Xf.move(0.66, 0.042, 0.22).mul(Xf.rotY(64)).mul(Xf.rotZ(90)).mul(Xf.move(0, -0.06, 0)), P_CAN_PEACHES);
        // the water: big jugs, their blue caps
        for (double[] t : new double[][] {{-1.32, -0.08}, {-0.98, 0.14}}) {
            Xf j = Xf.move(t[0], 0, t[1]);
            barLathe(m, 16, new double[][] {{0, 0.12}, {0.015, 0.135}, {0.3, 0.135}, {0.31, 0.128}, {0.32, 0.135}, {0.36, 0.13}, {0.42, 0.06}, {0.47, 0.035}, {0.5, 0.035}}, j, barMat(M_ICE), false, true);
            barLathe(m, 12, new double[][] {{0.5, 0.04}, {0.53, 0.04}}, j, barMat(M_BBLUE), true, false);
        }
        // the fuel: a jerry can, its spout and handle
        Xf f = Xf.move(1.0, 0, 0.26).mul(Xf.rotY(-24));
        barBox(m, f, 0.3, 0.38, 0.14, 0, 0.19, 0, M_CANISTER);
        for (double x : new double[] {-0.08, 0.08}) barBox(m, f, 0.012, 0.38, 0.145, x, 0.19, 0, M_RUST);
        barLimb(m, f, new double[] {0.1, 0.38, 0}, new double[] {0.14, 0.44, 0}, 0.024, 0.02, barMat(M_IRON));
        barBox(m, f, 0.13, 0.016, 0.03, -0.05, 0.43, 0, M_CANISTER);
        barBox(m, f, 0.016, 0.05, 0.03, -0.11, 0.405, 0, M_CANISTER);
        barBox(m, f, 0.016, 0.05, 0.03, 0.01, 0.405, 0, M_CANISTER);
        barFinish(m, name);
    }

    // ----------------------------------------------------------------- what he set out on the floor

    // By the counter, where the eyes go when he looks at his arm (the author, 2026-11-04, the bare
    // floor; variant N of the sketches, on sterile gauze - variant F: the point of laying the
    // tools on something is that they stay clean): a hacksaw, a knife, a gold lighter to burn it shut, a
    // bandage, the belt for the arm, the torn wrapper of the gauze, the spirit that cleaned the blades. He means to take the arm off.
    static final int[] P_GAUZE = {0, 320, 256, 192}, P_BELT = {1024, 896, 512, 48}, P_SAWBLADE = {1024, 944, 512, 24},
        P_KNIFE = {1024, 968, 256, 32}, P_SAWPAINT = {1280, 968, 256, 24}, P_GRIP = {1280, 992, 256, 32},
        P_WRAPPER = {1856, 640, 128, 96}, P_ROLLEND = {1984, 640, 64, 64}, P_LIGHTER = {1856, 736, 64, 32}, P_SPIRIT = {1984, 704, 64, 64};
    static final double SET_GW = 1.02, SET_GD = 0.57;   // the gauze, opened out
    // the cloth grown old in its pack (the author, 2026-11-04: new white stood out of the room)
    static final double SET_R = 0.53, SET_G = 0.475, SET_B = 0.365;
    // where the blades were wiped with the spirit, still damp: x, z, radius across, radius along
    static final double[][] SET_DAMP = {{-0.02, -0.03, 0.2, 0.05}, {0.16, -0.11, 0.09, 0.05}, {0.0, 0.19, 0.15, 0.04}};

    /** What stands on the gauze, for the soft dark under it: x0, z0, x1, z1, radius, in the model's metres. */
    static final double[][] SET_SHADOWS = {
        {-0.23, -0.055, 0.29, -0.055, 0.016}, {-0.245, -0.215, 0.305, -0.215, 0.017}, {-0.245, -0.215, -0.245, -0.06, 0.017},
        {0.305, -0.215, 0.305, -0.06, 0.017}, {-0.32, -0.12, -0.285, -0.06, 0.05},
        {-0.23, 0.145, -0.1, 0.15, 0.02}, {-0.1, 0.15, 0.09, 0.155, 0.015}, {0.33, 0.105, 0.33, 0.105, 0.03}, {0.42, -0.17, 0.43, -0.07, 0.045},
    };

    /** Soft noise of its own (the sheet's other art keeps its draws: nothing of it may change). */
    static double setNoise(double[][] g, double x, double y) {
        int n = g.length;
        int xi = (int) Math.floor(x), yi = (int) Math.floor(y);
        double fx = x - xi, fy = y - yi;
        fx = fx * fx * (3 - 2 * fx);
        fy = fy * fy * (3 - 2 * fy);
        int x0 = Math.floorMod(xi, n), x1 = (x0 + 1) % n, y0 = Math.floorMod(yi, n), y1 = (y0 + 1) % n;
        double a = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * fx, b = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * fx;
        return a + (b - a) * fy;
    }

    static double[][] setGrid(Random r) {
        double[][] g = new double[32][32];
        for (double[] row : g) for (int i = 0; i < 32; i++) row[i] = r.nextDouble();
        return g;
    }

    static void setPixel(BufferedImage img, int x, int y, double a, double b, double c) {
        int ri = (int) Math.round(Math.max(0, Math.min(1, a)) * 255), gi = (int) Math.round(Math.max(0, Math.min(1, b)) * 255),
            bi = (int) Math.round(Math.max(0, Math.min(1, c)) * 255);
        img.setRGB(x, y, 0xff000000 | (ri << 16) | (gi << 8) | bi);
    }

    static double setSegment(double x, double z, double[] s) {
        double dx = s[2] - s[0], dz = s[3] - s[1], l = dx * dx + dz * dz;
        double t = l < 1e-9 ? 0 : Math.max(0, Math.min(1, ((x - s[0]) * dx + (z - s[1]) * dz) / l));
        return Math.hypot(x - s[0] - t * dx, z - s[1] - t * dz);
    }

    /** The gauze: open weave, the creases of the pack it was folded in, the dark under what lies on it. */
    static void setGauzeArt(BufferedImage img, int[] p, Random r) {
        double[][] n = setGrid(r);
        double[][] blot = setGrid(r);
        double[][] fox = new double[34][];
        for (int i = 0; i < fox.length; i++) {
            double[] c = i % 7 == 0 ? new double[] {r.nextDouble(), r.nextDouble()} : fox[i - i % 7];
            double sp = i % 7 == 0 ? 0 : 0.05 + r.nextDouble() * 0.05;
            fox[i] = new double[] {c[0] + (r.nextDouble() - 0.5) * sp * 2, c[1] + (r.nextDouble() - 0.5) * sp * 2, 1.4 + r.nextDouble() * r.nextDouble() * 1.8};
        }
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double u = (x + 0.5) / p[2], v = (y + 0.5) / p[3];
                // (no threads: drawn a texel wide in rows and columns, they ran as bands over it when
                // the eyes moved - the author's video, 2026-11-04; nothing finer than the eye keeps)
                double k = (0.9 + 0.17 * setNoise(n, u * 9, v * 7)) * (0.96 + 0.08 * setNoise(n, u * 42, v * 33));
                // its edge, loose and thin
                double edge = Math.min(Math.min(u, 1 - u) * SET_GW, Math.min(v, 1 - v) * SET_GD);
                k *= 0.8 + 0.2 * Math.min(1, edge / (0.012 + 0.02 * setNoise(n, u * 19, v * 17)));
                for (double f : new double[] {0.25, 0.5, 0.75}) k *= 1 - 0.08 * Math.exp(-Math.pow((u - f) / 0.014, 2)) + 0.04 * Math.exp(-Math.pow((u - f - 0.03) / 0.022, 2));
                for (double f : new double[] {1 / 3.0, 2 / 3.0}) k *= 1 - 0.08 * Math.exp(-Math.pow((v - f) / 0.018, 2)) + 0.04 * Math.exp(-Math.pow((v - f - 0.04) / 0.03, 2));
                // browned in patches, deepest towards its edges where the air got at it
                double age = setNoise(blot, u * 4, v * 3) * 0.7 + setNoise(blot, u * 11 + 5, v * 9) * 0.3;
                age = Math.max(0, Math.min(1, (age - 0.36) * 2.2)) + 0.35 * Math.max(0, 1 - Math.min(Math.min(u, 1 - u) * SET_GW, Math.min(v, 1 - v) * SET_GD) / 0.09);
                k *= 1 - 0.2 * age;
                for (double[] f : fox) if (Math.hypot((u - f[0]) * p[2], (v - f[1]) * p[3]) < f[2]) k *= 0.82;
                double mx = (u - 0.5) * SET_GW, mz = (v - 0.5) * SET_GD, dark = 1;
                for (double[] s : SET_SHADOWS) {
                    double d = setSegment(mx, mz + 0.006, s) / (s[4] * 1.7);
                    if (d < 1) dark = Math.min(dark, 0.52 + 0.48 * d * d * (3 - 2 * d));
                }
                k *= dark;
                for (double[] w : SET_DAMP) {
                    double d = Math.hypot((mx - w[0]) / w[2], (mz - w[1]) / w[3]) + 0.24 * (setNoise(n, u * 14, v * 12) - 0.5);
                    if (d < 1) k *= 0.76 + 0.12 * Math.max(0, 1 - (1 - d) * 7);
                }
                setPixel(img, p[0] + x, p[1] + y, SET_R * k, SET_G * k * (1 - 0.05 * age), SET_B * k * (1 - 0.14 * age));
            }
        }
    }

    /** The pictures of the things on it. Their own Random and setPixel: rgba draws from the sheet's dither. */
    static void barAtlasSawSet(BufferedImage img, java.awt.Graphics2D g) {
        Random r = new Random(1941);
        setGauzeArt(img, P_GAUZE, r);
        double[][] n = setGrid(r), n2 = setGrid(r);
        // the belt, its buckle at u 0, its holes towards the tongue: old leather, stitched, worn where it was fastened
        int[] p = P_BELT;
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double u = x / (double) p[2], v = (y + 0.5) / p[3];
                double k = 0.74 + 0.5 * setNoise(n, x * 0.04, y * 0.1) * (0.7 + 0.6 * setNoise(n2, x * 0.21, y * 0.3));
                k *= 0.82 + 0.18 * Math.min(1, Math.min(v, 1 - v) * 7);
                k *= 1 + 0.32 * Math.exp(-Math.pow((u - 0.73) / 0.09, 2));
                if ((y == 6 || y == p[3] - 7) && x % 9 < 6) k = 1.75;
                double a = 0.3, b = 0.185, c = 0.105;
                for (int h = 0; h < 5; h++) {
                    double d = Math.hypot(x - (0.66 + h * 0.062) * p[2], y - (p[3] - 1) / 2.0);
                    if (d < 3.4) k = 0.08;
                    else if (d < 6.5) k *= 0.72;
                }
                setPixel(img, p[0] + x, p[1] + y, a * k, b * k, c * k);
            }
        }
        // the blade: dark hard steel, a line of light along it, its teeth along the bottom, a pin hole at each end
        p = P_SAWBLADE;
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double v = (y + 0.5) / p[3];
                double k = 0.86 + 0.26 * setNoise(n, x * 0.03, y * 0.9);
                k += 0.75 * Math.exp(-Math.pow((v - 0.3) / 0.1, 2));
                if (v > 0.72) k *= 0.42 + 0.5 * ((x % 7) / 7.0);
                if (Math.hypot(x - 12, y - 8) < 3.2 || Math.hypot(x - (p[2] - 13), y - 8) < 3.2) k = 0.08;
                if (setNoise(n2, x * 0.11, y * 0.7) > 0.8) k *= 0.8;
                setPixel(img, p[0] + x, p[1] + y, 0.36 * k, 0.385 * k, 0.42 * k);
            }
        }
        // the knife: the steel, its edge ground bright along the bottom, the scratches of the stone
        p = P_KNIFE;
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double v = (y + 0.5) / p[3];
                double k = v > 0.66 ? 2.0 : 1.0 + 0.3 * setNoise(n, x * 0.05, y * 0.6);
                k *= 0.92 + 0.16 * setNoise(n2, (x + y * 2.2) * 0.8, y * 0.08);
                setPixel(img, p[0] + x, p[1] + y, 0.39 * k, 0.405 * k, 0.43 * k);
            }
        }
        // the saw's frame: red enamel, chipped to the iron along its edges
        p = P_SAWPAINT;
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double k = 0.8 + 0.42 * setNoise(n, x * 0.07, y * 0.3);
                if (setNoise(n2, x * 0.24, y * 0.5) > 0.76) setPixel(img, p[0] + x, p[1] + y, 0.14, 0.13, 0.12);
                else setPixel(img, p[0] + x, p[1] + y, 0.43 * k, 0.095 * k, 0.07 * k);
            }
        }
        // the grips: dark oiled wood, along the grain
        p = P_GRIP;
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double k = 0.74 + 0.6 * setNoise(n2, x * 0.025, y * 0.55) + 0.1 * Math.sin(y * 1.1 + 6 * setNoise(n, x * 0.03, y * 0.2));
                setPixel(img, p[0] + x, p[1] + y, 0.25 * k, 0.15 * k, 0.09 * k);
            }
        }
        // the end of a roll of bandage: its turns
        p = P_ROLLEND;
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double dx = x - p[2] / 2.0 + 0.5, dy = y - p[3] / 2.0 + 0.5, d = Math.hypot(dx, dy);
                double t = d / 3.2 + Math.atan2(dy, dx) / (Math.PI * 2);
                double k = 0.74 + 0.3 * Math.abs((t - Math.floor(t)) * 2 - 1);
                if (d < 7) k = 0.28;
                k *= 0.84 + 0.3 * setNoise(n, x * 0.2, y * 0.2);
                setPixel(img, p[0] + x, p[1] + y, SET_R * k, SET_G * k, SET_B * k);
            }
        }
        // the lighter's face: gold (the author, 2026-11-04: as steel it looked wrong), one soft light down it
        p = P_LIGHTER;
        for (int y = 0; y < p[3]; y++) {
            for (int x = 0; x < p[2]; x++) {
                double u = (x + 0.5) / p[2], v = (y + 0.5) / p[3];
                double k = 0.9 + 0.1 * setNoise(n2, x * 0.09, y * 1.3);
                k += 0.5 * Math.exp(-Math.pow((u - 0.34) / 0.2, 2));
                setPixel(img, p[0] + x, p[1] + y, 0.66 * k, 0.45 * k, 0.15 * k);
            }
        }
        // the spirit's label: old cream paper, a red bar
        p = P_SPIRIT;
        g.setColor(new java.awt.Color(168, 150, 112));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setClip(p[0], p[1], p[2], p[3]);
        g.setColor(new java.awt.Color(116, 34, 28));
        g.fillRect(p[0], p[1] + 6, p[2], 13);
        g.setColor(new java.awt.Color(208, 194, 158));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 10));
        centred(g, "GRAIN", p[0] + p[2] / 2, p[1] + 16);
        g.setColor(new java.awt.Color(44, 38, 32));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 10));
        centred(g, "ALCOHOL", p[0] + p[2] / 2, p[1] + 34);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 9));
        centred(g, "190 PROOF", p[0] + p[2] / 2, p[1] + 48);
        g.setClip(null);
        // the wrapper: paper, a printed band, what was in it
        p = P_WRAPPER;
        g.setColor(new java.awt.Color(214, 208, 190));
        g.fillRect(p[0], p[1], p[2], p[3]);
        g.setClip(p[0], p[1], p[2], p[3]);
        g.setColor(new java.awt.Color(58, 84, 128));
        g.fillRect(p[0], p[1] + 12, p[2], 20);
        g.setColor(new java.awt.Color(232, 228, 214));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 14));
        centred(g, "STERILE", p[0] + p[2] / 2, p[1] + 27);
        g.setColor(new java.awt.Color(46, 48, 56));
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.BOLD, 11));
        centred(g, "GAUZE DRESSING", p[0] + p[2] / 2, p[1] + 48);
        g.setFont(new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 10));
        centred(g, "36 IN. x 20 IN.", p[0] + p[2] / 2, p[1] + 62);
        centred(g, "U.S.P.  ONE ONLY", p[0] + p[2] / 2, p[1] + 74);
        g.setClip(null);
    }

    /** A strip of the sheet's picture, somewhere along it. */
    static double[] setWindow(int[] p, Random r, int w, int h) {
        return barCell(p[0] + r.nextInt(p[2] - w), p[1] + r.nextInt(p[3] - h), w, h);
    }

    /** A triangle facing up, whichever way round it was given. */
    static void setUp(Mesh m, double[] a, double[] b, double[] c, double[] ua, double[] ub, double[] uc) {
        if (Mesh.normal(a, b, c)[1] >= 0) m.tri(a, b, c, ua, ub, uc);
        else m.tri(a, c, b, ua, uc, ub);
    }

    /**
     * Cloth or paper lying on the floor: a grid over the whole of the cell, its height (u, v from
     * the far left corner) given, its edges wandering a little, its normals from its height.
     */
    static void setSheet(Mesh m, Xf at, double w, double d, int nx, int nz, double wander, Random r,
                         java.util.function.BiFunction<Double, Double, Double> lift, double[] uv) {
        double[][] g = setGrid(r);
        double[][] y = new double[nx + 1][nz + 1], px = new double[nx + 1][nz + 1], pz = new double[nx + 1][nz + 1];
        for (int i = 0; i <= nx; i++) {
            for (int j = 0; j <= nz; j++) {
                double u = i / (double) nx, v = j / (double) nz;
                y[i][j] = lift.apply(u, v);
                px[i][j] = (u - 0.5) * w + wander * (setNoise(g, 5 + v * 5, u * 2) - 0.5);
                pz[i][j] = (v - 0.5) * d + wander * (setNoise(g, u * 6, 9 + v * 2) - 0.5);
            }
        }
        double[] o = at.point(0, 0, 0);
        for (int i = 0; i < nx; i++) {
            for (int j = 0; j < nz; j++) {
                double[][] p = new double[4][], n = new double[4][];
                double[] us = new double[4], vs = new double[4];
                int[][] c = {{i, j + 1}, {i + 1, j + 1}, {i + 1, j}, {i, j}};
                for (int k = 0; k < 4; k++) {
                    int a = c[k][0], b = c[k][1];
                    p[k] = at.point(px[a][b], y[a][b], pz[a][b]);
                    double dx = (y[Math.min(nx, a + 1)][b] - y[Math.max(0, a - 1)][b]) / (2 * w / nx);
                    double dz = (y[a][Math.min(nz, b + 1)] - y[a][Math.max(0, b - 1)]) / (2 * d / nz);
                    n[k] = dirOf(at, o, -dx * 2.5, 1, -dz * 2.5);    // (its shallow folds drawn a little deeper in the light)
                    us[k] = uv[0] + (uv[2] - uv[0]) * a / nx;
                    vs[k] = uv[3] + (uv[1] - uv[3]) * b / nz;
                }
                barFaced(m, p, n, us, vs);
            }
        }
    }

    /** A flat shape on its back, its outline given in x, z round a middle it can be seen from, its top edge eased. */
    static void setPlate(Mesh m, Xf at, double[][] outline, double y0, double h, double ease, double[] uv) {
        int n = outline.length;
        double cx = 0, cz = 0, x0 = 1e9, x1 = -1e9, z0 = 1e9, z1 = -1e9;
        for (double[] q : outline) {
            cx += q[0] / n;
            cz += q[1] / n;
            x0 = Math.min(x0, q[0]);
            x1 = Math.max(x1, q[0]);
            z0 = Math.min(z0, q[1]);
            z1 = Math.max(z1, q[1]);
        }
        double[] o = at.point(0, 0, 0), mid = at.point(cx, y0 + h, cz);
        double[][] in = new double[n][];
        for (int i = 0; i < n; i++) {
            double dx = outline[i][0] - cx, dz = outline[i][1] - cz, l = Math.hypot(dx, dz);
            double k = Math.max(0.2, 1 - ease / l);
            in[i] = new double[] {cx + dx * k, cz + dz * k};
        }
        double[] muv = {uv[0] + (uv[2] - uv[0]) * (cx - x0) / (x1 - x0), uv[3] + (uv[1] - uv[3]) * (cz - z0) / (z1 - z0)};
        for (int i = 0; i < n; i++) {
            double[] a = outline[i], b = outline[(i + 1) % n], ia = in[i], ib = in[(i + 1) % n];
            double ex = b[1] - a[1], ez = a[0] - b[0], el = Math.max(1e-9, Math.hypot(ex, ez));
            ex /= el;
            ez /= el;
            if (ex * ((a[0] + b[0]) / 2 - cx) + ez * ((a[1] + b[1]) / 2 - cz) < 0) {
                ex = -ex;
                ez = -ez;
            }
            double ua = uv[0] + (uv[2] - uv[0]) * (a[0] - x0) / (x1 - x0), ub = uv[0] + (uv[2] - uv[0]) * (b[0] - x0) / (x1 - x0);
            double va = uv[3] + (uv[1] - uv[3]) * (a[1] - z0) / (z1 - z0), vb = uv[3] + (uv[1] - uv[3]) * (b[1] - z0) / (z1 - z0);
            double[] ns = dirOf(at, o, ex, 0, ez), nb = dirOf(at, o, ex * 0.7, 0.7, ez * 0.7);
            barFaced(m, new double[][] {at.point(a[0], y0, a[1]), at.point(b[0], y0, b[1]), at.point(b[0], y0 + h - ease, b[1]), at.point(a[0], y0 + h - ease, a[1])},
                new double[][] {ns, ns, ns, ns}, new double[] {ua, ub, ub, ua}, new double[] {va, vb, vb, va});
            barFaced(m, new double[][] {at.point(a[0], y0 + h - ease, a[1]), at.point(b[0], y0 + h - ease, b[1]), at.point(ib[0], y0 + h, ib[1]), at.point(ia[0], y0 + h, ia[1])},
                new double[][] {nb, nb, nb, nb}, new double[] {ua, ub, ub, ua}, new double[] {va, vb, vb, va});
            double uia = uv[0] + (uv[2] - uv[0]) * (ia[0] - x0) / (x1 - x0), uib = uv[0] + (uv[2] - uv[0]) * (ib[0] - x0) / (x1 - x0);
            double via = uv[3] + (uv[1] - uv[3]) * (ia[1] - z0) / (z1 - z0), vib = uv[3] + (uv[1] - uv[3]) * (ib[1] - z0) / (z1 - z0);
            setUp(m, mid, at.point(ia[0], y0 + h, ia[1]), at.point(ib[0], y0 + h, ib[1]), muv, new double[] {uia, via}, new double[] {uib, vib});
        }
    }

    /** A tube along flat points x, y, z: round, its bends carried through, its open ends out of sight. */
    static void setTube(Mesh m, Xf at, double[][] pts, double rad, double[] uv) {
        int sides = 10, n = pts.length;
        double[] o = at.point(0, 0, 0);
        double[][] side = new double[n][];
        for (int i = 0; i < n; i++) {
            double[] a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
            double tx = b[0] - a[0], tz = b[2] - a[2], l = Math.max(1e-9, Math.hypot(tx, tz));
            side[i] = new double[] {-tz / l, tx / l};
        }
        for (int i = 0; i + 1 < n; i++) {
            for (int s = 0; s < sides; s++) {
                double a0 = 2 * Math.PI * s / sides, a1 = 2 * Math.PI * (s + 1) / sides;
                double[][] p = new double[4][], nn = new double[4][];
                double[] an = {a0, a0, a1, a1};
                int[] at4 = {i, i + 1, i + 1, i};
                for (int k = 0; k < 4; k++) {
                    double c = Math.cos(an[k]), q = Math.sin(an[k]);
                    double[] pt = pts[at4[k]], sd = side[at4[k]];
                    p[k] = at.point(pt[0] + sd[0] * c * rad, pt[1] + q * rad, pt[2] + sd[1] * c * rad);
                    nn[k] = dirOf(at, o, sd[0] * c, q, sd[1] * c);
                }
                double u0 = uv[0] + (uv[2] - uv[0]) * i / (n - 1), u1 = uv[0] + (uv[2] - uv[0]) * (i + 1) / (n - 1);
                barFaced(m, p, nn, new double[] {u0, u1, u1, u0}, new double[] {uv[1], uv[1], uv[3], uv[3]});
            }
        }
    }

    /** A strap along points x, y, z, width w at each, thick t: its picture along it, u from its first point. */
    static void setStrap(Mesh m, Xf at, double[][] pts, double[] w, double t, double[] uv) {
        int n = pts.length;
        double[] o = at.point(0, 0, 0), len = new double[n];
        double[][] side = new double[n][];
        for (int i = 0; i < n; i++) {
            double[] a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
            double tx = b[0] - a[0], tz = b[2] - a[2], l = Math.max(1e-9, Math.hypot(tx, tz));
            side[i] = new double[] {-tz / l, tx / l};
            if (i > 0) len[i] = len[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][2] - pts[i - 1][2]);
        }
        double[] up = dirOf(at, o, 0, 1, 0);
        for (int i = 0; i + 1 < n; i++) {
            int b = i + 1;
            double ua = uv[0] + (uv[2] - uv[0]) * len[i] / len[n - 1], ub = uv[0] + (uv[2] - uv[0]) * len[b] / len[n - 1];
            double[] al = at.point(pts[i][0] - side[i][0] * w[i] / 2, pts[i][1] + t, pts[i][2] - side[i][1] * w[i] / 2);
            double[] ar = at.point(pts[i][0] + side[i][0] * w[i] / 2, pts[i][1] + t, pts[i][2] + side[i][1] * w[i] / 2);
            double[] bl = at.point(pts[b][0] - side[b][0] * w[b] / 2, pts[b][1] + t, pts[b][2] - side[b][1] * w[b] / 2);
            double[] br = at.point(pts[b][0] + side[b][0] * w[b] / 2, pts[b][1] + t, pts[b][2] + side[b][1] * w[b] / 2);
            barFaced(m, new double[][] {al, bl, br, ar}, new double[][] {up, up, up, up}, new double[] {ua, ub, ub, ua}, new double[] {uv[3], uv[3], uv[1], uv[1]});
            for (int s = -1; s <= 1; s += 2) {
                double[] nn = dirOf(at, o, side[i][0] * s, 0, side[i][1] * s);
                double[] p = s < 0 ? al : ar, q = s < 0 ? bl : br;
                double[] p2 = {p[0], p[1] - t * up[1], p[2]}, q2 = {q[0], q[1] - t * up[1], q[2]};
                barFaced(m, new double[][] {p, q, q2, p2}, new double[][] {nn, nn, nn, nn}, new double[] {ua, ub, ub, ua}, new double[] {uv[1], uv[1], uv[1], uv[1]});
            }
        }
    }

    /** An outline with its corners cut: once more each time, a hand's shape from a few points. */
    static double[][] setRound(double[][] p) {
        double[][] o = new double[p.length * 2][];
        for (int i = 0; i < p.length; i++) {
            double[] a = p[i], b = p[(i + 1) % p.length];
            o[i * 2] = new double[] {a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25};
            o[i * 2 + 1] = new double[] {a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75};
        }
        return o;
    }

    /** A hacksaw on its side, the middle of its frame at the origin: the bow to -z, the blade to +z, its teeth towards us. */
    static void setSaw(Mesh m, Xf at, double y, Random r) {
        java.util.List<double[]> path = new ArrayList<>();
        double x = 0.275, top = -0.085, turn = 0.03, tube = 0.0095;
        path.add(new double[] {-x, y + tube, 0.03});
        for (int i = 0; i <= 5; i++) {
            double a = Math.PI / 2 * i / 5;
            path.add(new double[] {-x + turn * (1 - Math.cos(a)), y + tube, top + turn * (1 - Math.sin(a))});
        }
        for (int i = 0; i <= 5; i++) {
            double a = Math.PI / 2 * i / 5;
            path.add(new double[] {x - turn * (1 - Math.sin(a)), y + tube, top + turn * (1 - Math.cos(a))});
        }
        path.add(new double[] {x, y + tube, 0.075});
        setTube(m, at, path.toArray(new double[0][]), tube, setWindow(P_SAWPAINT, r, 230, 20));
        // the blade, tight between its pins, the teeth standing proud of it
        double by = y + tube + 0.001, a = -0.262, b = 0.262, z0 = 0.063, z1 = 0.087;
        m.quad(at.point(a, by, z1), at.point(b, by, z1), at.point(b, by, z0), at.point(a, by, z0), barPic(P_SAWBLADE));
        double[] st = barMat(M_IRON);
        double[] sa = {st[0], st[1]}, sb = {st[2], st[1]}, sc = {st[0], st[3]};
        for (int i = 0; i < 62; i++) {
            double t = a + i * 0.0085;
            setUp(m, at.point(t, by, z1), at.point(t + 0.0085, by, z1), at.point(t + 0.0062, by, z1 + 0.0072), sa, sb, sc);
        }
        // its pins: the wing nut that tightens it at the far end
        Xf nut = at.mul(Xf.move(x, y + tube, 0.075));
        barBox(m, nut, 0.03, 0.02, 0.034, 0, 0, 0, M_METAL);
        barLathe(m, 12, new double[][] {{0.01, 0.009}, {0.016, 0.008}, {0.018, 0.005}}, nut, barMat(M_STEEL), true, false);
        for (int s = -1; s <= 1; s += 2) barBox(m, nut, 0.03, 0.012, 0.004, s * 0.018, 0.014, 0, M_STEEL);
        // the grip, dark wood, shaped for the hand; the rivets through it
        double[][] grip = {{-0.262, 0.018}, {-0.258, 0.094}, {-0.288, 0.116}, {-0.342, 0.128}, {-0.368, 0.098}, {-0.342, 0.058}, {-0.33, 0.012}, {-0.29, -0.004}};
        setPlate(m, at, setRound(setRound(grip)), y, 0.03, 0.006, barPic(P_GRIP));
        for (double[] q : new double[][] {{-0.292, 0.03}, {-0.318, 0.086}}) {
            barLathe(m, 8, new double[][] {{0, 0.0058}, {0.0014, 0.0034}}, at.mul(Xf.move(q[0], y + 0.03, q[1])), barMat(M_BRASS), true, false);
        }
        barBox(m, at, 0.022, 0.012, 0.03, -0.262, y + tube + 0.002, 0.075, M_METAL);
    }

    /** A knife on its side, the blade towards +x, its edge towards us. */
    static void setKnife(Mesh m, Xf at, double y) {
        double[][] blade = {{-0.005, -0.016}, {0.13, -0.016}, {0.2, 0.012}, {0.15, 0.014}, {0.06, 0.017}, {-0.005, 0.017}};
        setPlate(m, at, blade, y + 0.006, 0.0035, 0.0012, barPic(P_KNIFE));
        double[][] handle = {{-0.135, -0.014}, {-0.004, -0.017}, {-0.004, 0.018}, {-0.12, 0.021}, {-0.14, 0.008}};
        setPlate(m, at, handle, y, 0.018, 0.004, barPic(P_GRIP));
        barBox(m, at, 0.012, 0.018, 0.036, -0.002, y + 0.009, 0.0005, M_BRASS);
        for (double x : new double[] {-0.03, -0.075, -0.115}) {
            barLathe(m, 8, new double[][] {{0, 0.0052}, {0.0012, 0.003}}, at.mul(Xf.move(x, y + 0.018, 0.002)), barMat(M_BRASS), true, false);
        }
    }

    /** A gold lighter stood on end, shut: its case, the cap over it, the line between them, the hinge. */
    static void setLighter(Mesh m, Xf at) {
        double[] side = barMat(M_GOLD), cell = barPic(P_LIGHTER);
        double mid = cell[1] + (cell[3] - cell[1]) * 0.66;
        double[] lo = {cell[0], cell[1], cell[2], mid}, hi = {cell[0], mid, cell[2], cell[3]};
        m.box(0.042, 0.043, 0.015, at.mul(Xf.move(0, 0.0215, 0)), lo, side);
        barBox(m, at, 0.0425, 0.0016, 0.0155, 0, 0.0442, 0, M_BLACK);
        m.box(0.042, 0.021, 0.015, at.mul(Xf.move(0, 0.0555, 0)), hi, side);
        barBox(m, at, 0.003, 0.016, 0.004, 0.0225, 0.046, 0, M_BRASS);
    }

    /** The roll of bandage on its side. */
    static void setBandage(Mesh m, Xf at, double y) {
        double rad = 0.043, half = 0.05;
        Xf roll = at.mul(Xf.move(0, y + rad, 0)).mul(Xf.rotX(90));
        double[] cloth = barCell(P_GAUZE[0] + 12, P_GAUZE[1] + 150, 30, 24);    // (a corner of the gauze nothing lies on)
        barLathe(m, 18, new double[][] {{-half, rad}, {-half + 0.004, rad + 0.001}, {half - 0.004, rad + 0.001}, {half, rad}}, roll, cloth, false, false);
        double[] e = barPic(P_ROLLEND);
        double[] mid = {(e[0] + e[2]) / 2, (e[1] + e[3]) / 2};
        for (int i = 0; i < 18; i++) {
            double a0 = 2 * Math.PI * i / 18, a1 = 2 * Math.PI * (i + 1) / 18;
            for (int s = -1; s <= 1; s += 2) {
                double[] c = roll.point(0, s * half, 0), p = roll.point(rad * Math.cos(a0), s * half, rad * Math.sin(a0)), q = roll.point(rad * Math.cos(a1), s * half, rad * Math.sin(a1));
                double[] up = {mid[0] + (e[2] - e[0]) / 2 * Math.cos(a0), mid[1] + (e[3] - e[1]) / 2 * Math.sin(a0)};
                double[] uq = {mid[0] + (e[2] - e[0]) / 2 * Math.cos(a1), mid[1] + (e[3] - e[1]) / 2 * Math.sin(a1)};
                if (s > 0) m.tri(c, q, p, mid, uq, up);
                else m.tri(c, p, q, mid, up, uq);
            }
        }
    }

    /** The belt: dropped in a loose bend, heading +z from its buckle at the origin, lifting off the floor in the bend. */
    static void setBelt(Mesh m, Xf at, double y) {
        int n = 44;
        double step = 0.0215, a = Math.toRadians(280), px = 0, pz = 0;
        double[][] pts = new double[n][];
        double[] w = new double[n];
        for (int i = 0; i < n; i++) {
            double s = i * step;
            pts[i] = new double[] {px, y + 0.012 * Math.exp(-Math.pow((s - 0.3) / 0.1, 2)), pz};
            w[i] = 0.036 * (i > n - 4 ? Math.max(0.35, (n - i) / 4.0) : 1);
            px += step * Math.cos(a);
            pz -= step * Math.sin(a);
            a += step * (s > 0.14 && s < 0.5 ? 5.8 : -1.1);
        }
        setStrap(m, at, pts, w, 0.0038, barPic(P_BELT));
        // the buckle: a square of brass, its bar, its tongue lying over the strap; the keeper behind it
        Xf b = at.mul(Xf.rotY(280)).mul(Xf.move(-0.012, y + 0.008, 0));
        double[] brass = barMat(M_BRASS);
        double hw = 0.029, hl = 0.03;
        setTube(m, b, new double[][] {{-hl, 0, -hw}, {hl, 0, -hw}, {hl, 0, hw}, {-hl, 0, hw}, {-hl, 0, -hw}}, 0.0034, brass);
        barLimb(m, b, new double[] {0.012, 0, -hw}, new double[] {0.012, 0, hw}, 0.0025, 0.0025, brass);
        barLimb(m, b, new double[] {0.012, 0.002, 0}, new double[] {-hl, 0.003, 0}, 0.0024, 0.002, brass);
        double[] keeper = barCell(P_BELT[0] + 20, P_BELT[1] + 10, 60, 24);
        m.box(0.018, 0.009, 0.044, at.mul(Xf.rotY(280)).mul(Xf.move(0.05, y + 0.006, 0)), keeper, keeper);
    }

    /** The torn wrapper, its picture, and the strip torn off it. */
    static void setWrapper(Mesh m, Xf at, Random r) {
        setSheet(m, at, 0.24, 0.17, 12, 9, 0.012, r, (u, v) -> 0.0025 + 0.03 * Math.pow(Math.max(0, 1 - v * 1.5), 2) * (0.5 + 0.5 * Math.sin(u * 8)), barPic(P_WRAPPER));
        double[] strip = barCell(P_WRAPPER[0], P_WRAPPER[1] + 74, 128, 16);
        setSheet(m, at.mul(Xf.move(0.06, 0, 0.19)).mul(Xf.rotY(23)), 0.2, 0.024, 10, 2, 0.008, r, (u, v) -> 0.003 + 0.012 * Math.pow(Math.sin(u * Math.PI * 1.5), 2), strip);
    }

    /** The spirit he wiped the blades with: standing open, its cap beside it. */
    static void setSpirit(Mesh m, Xf at) {
        barEmpty(m, at, M_BROWN, P_SPIRIT);
        barLathe(m, 10, new double[][] {{0.2505, 0.0095}, {0.251, 0.0001}}, at, barMat(M_BLACK), false, false);
        Xf cap = at.mul(Xf.move(0.1, 0, 0.035)).mul(Xf.rotY(30));
        barLathe(m, 12, new double[][] {{0, 0.0165}, {0.015, 0.0165}, {0.017, 0.0145}}, cap, barMat(M_METAL), true, false);
    }

    static void barSawSet(String name) throws IOException {
        Mesh m = new Mesh();
        Xf root = Xf.rotY(-1.5);
        Random r = new Random(1942);
        double[][] g = setGrid(r);
        // the gauze, the folds of its pack still in it, one corner not lying down
        setSheet(m, root, SET_GW, SET_GD, 56, 32, 0.034, r, (u, v) -> {
            double y = 0.002 + 0.0028 * setNoise(g, u * 9, v * 6);
            for (double[] f : new double[][] {{0.25, 1}, {0.5, -0.5}, {0.75, 1}}) y += 0.0022 * (f[1] > 0 ? 1 : 0.4) * Math.exp(-Math.pow((u - f[0]) / 0.016, 2));
            for (double f : new double[] {1 / 3.0, 2 / 3.0}) y += 0.002 * Math.exp(-Math.pow((v - f) / 0.024, 2));
            double near = Math.max(0, 1 - Math.hypot(u, (1 - v) * 0.56) / 0.17);
            double far = Math.max(0, 1 - Math.hypot(1 - u, v * 0.56) / 0.09);
            return y + 0.03 * near * near + 0.012 * far * far;
        }, barPic(P_GAUZE));
        double base = 0.0095;
        setSaw(m, root.mul(Xf.move(0.03, 0, -0.13)).mul(Xf.rotY(2)), base, r);
        setKnife(m, root.mul(Xf.move(-0.1, 0, 0.145)).mul(Xf.rotY(4)), base);
        setLighter(m, root.mul(Xf.move(0.33, base, 0.105)).mul(Xf.rotY(18)));
        setBandage(m, root.mul(Xf.move(0.425, 0, -0.12)).mul(Xf.rotY(-4)), base);
        setBelt(m, root.mul(Xf.move(0.63, 0, -0.215)), 0.001);
        setWrapper(m, root.mul(Xf.move(-0.69, 0, -0.17)).mul(Xf.rotY(-9)), r);
        setSpirit(m, root.mul(Xf.move(-0.62, 0.001, -0.335)).mul(Xf.rotY(25)));
        barFinish(m, name);
    }

    static void barWallThings(String name) throws IOException {
        Mesh m = new Mesh();
        double[] wood = barMat(M_DARK);
        // the flag, in strips across: nailed along the top, a fold down each, the free corner hanging
        double[] flag = barPic(P_FLAG);
        double fx = -5.25, fw = 1.28, fy = 2.5, fh = 0.72;
        int n = 18;
        for (int i = 0; i < n; i++) {
            double a = (double) i / n, b = (i + 1.0) / n;
            double xa = fx + a * fw, xb = fx + b * fw;
            double za = 0.012 + 0.012 * Math.abs(Math.sin(a * 9)), zb = 0.012 + 0.012 * Math.abs(Math.sin(b * 9));
            double sa = 0.03 * Math.sin(a * Math.PI * 3) * Math.sin(a * Math.PI * 3), sb = 0.03 * Math.sin(b * Math.PI * 3) * Math.sin(b * Math.PI * 3);
            double da = 0.06 * a * a, db = 0.06 * b * b;   // (the free end hangs lower)
            double ua = flag[0] + (flag[2] - flag[0]) * a, ub = flag[0] + (flag[2] - flag[0]) * b;
            m.quad(new double[] {xa, fy - fh - da, za}, new double[] {xb, fy - fh - db, zb}, new double[] {xb, fy - sb, zb}, new double[] {xa, fy - sa, za},
                new double[] {ua, flag[1], ub, flag[3]});
        }
        for (int i = 0; i <= 3; i++) barLathe(m, 6, new double[][] {{0, 0.006}, {0.03, 0.005}}, Xf.move(fx + i * fw / 3, fy - 0.004, 0).mul(Xf.rotX(90)), barMat(M_IRON), true, false);
        // the crowd round it
        wallFrame(m, -3.55, 2.3, 0.56, 0.42, 1.2, P_PHOTO1, wood);
        wallFrame(m, -3.0, 2.28, 0.44, 0.33, -2.6, P_PHOTO2, wood);
        wallFrame(m, -3.32, 1.8, 0.52, 0.39, -4.4, P_PHOTO3, barMat(M_VARNISH));
        // the calendar on a nail, the plate
        barSheet(m, Xf.move(-2.62, 1.82, 0.008).mul(Xf.rotZ(2)), 0.24, 0.3, 0, 0, 0, 0, barPic(P_CALENDAR));
        barLathe(m, 6, new double[][] {{0, 0.004}, {0.02, 0.004}}, Xf.move(-2.62, 1.96, 0).mul(Xf.rotX(90)), barMat(M_IRON), true, false);
        barSheet(m, Xf.move(-3.72, 1.5, 0.008).mul(Xf.rotZ(-1.5)), 0.32, 0.16, 0, 0, 0, 0, barPic(P_PLATE));
        barFinish(m, name);
    }

    /** One pack (0..7) of P_CIGPACKS, whole or crushed: its face up the local +z, its foil on the top. */
    static void cigPack(Mesh m, Xf at, int brand, double[] side) {
        int[] p = P_CIGPACKS;
        double[] uv = barCell(p[0] + brand * 64, p[1], 64, p[3]);
        m.box(0.055, 0.085, 0.021, at, side, side);
        barSheet(m, at, 0.055, 0.085, 0, 0, 0.0108, 0, uv);
    }

    /**
     * The cigarette machine (the author, 2026-11-02: knocked over, as good as the jukebox: a whole
     * thing with a past). Built standing, facing +z, its foot at y 0, then laid over on its back
     * with its head to -x and rolled over to -z, its +z edge up on a crate; the scene turns it, the head to the
     * garland's wall and its face to the room (the author, 2026-11-02): someone tipped
     * it to get at it, forced its door with the bar still in the gap, pulled out the cash box,
     * took what he wanted. A column or two left inside, the rest on the floor before it.
     */
    static void barCigMachine(String name) throws IOException {
        Mesh m = new Mesh();
        Xf id = Xf.id();
        Random r = new Random(1976);
        double w = 0.66, h = 1.42, d = 0.44, zf = d / 2, t = 0.018;
        double[] body = barPic(P_CIGBODY), dark = barMat(M_BLACK), steel = barPic(P_WSTEEL);
        double[] packSide = barMat(M_DARK);
        // the shell: sides, back, top and foot, a steel kick plate
        jukeBox(m, id, t, h, d, -w / 2 + t / 2, h / 2, 0, jukeWorn(P_CIGBODY, r));
        jukeBox(m, id, t, h, d, w / 2 - t / 2, h / 2, 0, jukeWorn(P_CIGBODY, r));
        jukeBox(m, id, w, h, t, 0, h / 2, -zf + t / 2, body);
        jukeBox(m, id, w, t, d, 0, h - t / 2, 0, jukeWorn(P_CIGBODY, r));
        jukeBox(m, id, w + 0.012, 0.07, d + 0.012, 0, 0.035, 0, steel);
        // the rubber-footed foot's four feet, one gone
        for (double[] f : new double[][] {{-0.27, -0.16}, {0.27, -0.16}, {0.27, 0.16}}) {
            barLathe(m, 8, new double[][] {{-0.025, 0.024}, {0, 0.03}}, Xf.move(f[0], 0, f[1]), barMat(M_BLACK), true, true);
        }
        // a ventilation slot in each side
        for (int sx = -1; sx <= 1; sx += 2) {
            for (int i = 0; i < 6; i++) barBox(m, id, 0.004, 0.2, 0.012, sx * w / 2, 0.42, -0.12 + i * 0.03, M_BLACK);
        }

        // ---- the lower front, fixed: the panel
        double low = 0.54;
        jukeBox(m, id, w, low - 0.07, t, 0, (low + 0.07) / 2, zf - t / 2, jukeWorn(P_CIGBODY, r));
        jukeBox(m, id, w, 0.012, t + 0.006, 0, low, zf - t / 2 + 0.002, jukeWorn(P_CIGTRIM, r));
        // what it says of itself
        barSheet(m, id, 0.36, 0.135, -0.11, 0.42, zf + 0.002, 0, barPic(P_CIGSIGN));
        jukeBox(m, id, 0.376, 0.008, 0.006, -0.11, 0.491, zf + 0.002, jukeWorn(P_CIGTRIM, r));
        jukeBox(m, id, 0.376, 0.008, 0.006, -0.11, 0.349, zf + 0.002, jukeWorn(P_CIGTRIM, r));
        // the coin plate, the slot under a note, the reject lever bent, the return cup
        Xf plate = Xf.move(0.21, 0.36, zf + 0.004);
        jukeBox(m, plate, 0.13, 0.26, 0.01, 0, 0, 0, jukeWorn(P_CIGTRIM, r));
        barSheet(m, plate, 0.11, 0.2, 0, 0.02, 0.0058, 0, barPic(P_CIGPLATE));
        barBox(m, plate, 0.006, 0.034, 0.003, 0, 0.055, 0.0066, M_BLACK);
        barSheet(m, plate.mul(Xf.rotZ(-5)), 0.078, 0.042, 0.002, 0.06, 0.0078, 0, barPic(P_CIGNOTE));
        barBox(m, plate.mul(Xf.rotZ(4)), 0.086, 0.01, 0.0015, 0.002, 0.082, 0.0085, M_PAPER);   // (tape)
        barLimb(m, plate, new double[] {0.038, 0.0, 0.006}, new double[] {0.05, -0.012, 0.03}, 0.004, 0.006, jukeWorn(P_WCHROME, r));
        barBox(m, plate, 0.05, 0.03, 0.022, 0, -0.095, 0.012, M_BLACK);
        jukeBox(m, plate, 0.058, 0.006, 0.026, 0, -0.112, 0.012, jukeWorn(P_WCHROME, r));
        for (int sx = -1; sx <= 1; sx += 2) for (int sy = -1; sy <= 1; sy += 2) {
            barLathe(m, 6, new double[][] {{0.005, 0.004}, {0.009, 0.004}}, plate.mul(Xf.move(sx * 0.054, sy * 0.118, 0)).mul(Xf.rotX(90)), barMat(M_IRON), true, false);
        }
        // the pack's way out: a dark mouth, its flap hanging by one pin
        Xf tray = Xf.move(-0.11, 0.2, zf);
        barBox(m, tray, 0.36, 0.1, 0.004, 0, 0, 0.001, M_BLACK);
        jukeBox(m, tray, 0.376, 0.008, 0.012, 0, 0.054, 0.002, jukeWorn(P_WCHROME, r));
        jukeBox(m, tray, 0.376, 0.012, 0.03, 0, -0.054, 0.012, jukeWorn(P_WCHROME, r));
        jukeBox(m, tray.mul(Xf.move(-0.17, 0.046, 0.008)).mul(Xf.rotZ(-11)).mul(Xf.rotX(14)), 0.33, 0.085, 0.005, 0.165, -0.042, 0, jukeWorn(P_WCHROME, r));
        // the cash box's door hanging open, the box dragged out on the floor (below)
        Xf hatch = Xf.move(0.14, 0.12, zf + 0.002);
        barBox(m, hatch, 0.13, 0.085, 0.003, 0.07, 0, 0, M_BLACK);
        jukeBox(m, hatch.mul(Xf.rotY(-112)), 0.13, 0.085, 0.006, 0.065, 0, 0, jukeWorn(P_WSTEEL, r));

        // ---- the inside, seen through where the glass was and past the sprung door
        jukeBox(m, id, w - 2 * t, h - low - 0.03, 0.006, 0, (h + low) / 2, -zf + 0.05, jukeWorn(P_WSTEEL, r));
        double zIn = zf - 0.1;
        for (int i = 0; i <= 8; i++) {       // the columns' walls
            jukeBox(m, id, 0.004, 0.62, 0.11, -0.28 + i * 0.07, 0.92, zIn - 0.04, jukeWorn(P_WSTEEL, r));
        }
        jukeBox(m, id, w - 2 * t, 0.012, 0.16, 0, 0.61, zIn - 0.03, jukeWorn(P_WSTEEL, r));
        // what is left in them; those knocked crooked as it fell
        int[][] left = {{0, 2}, {1, 4}, {3, 1}, {4, 3}, {5, 0}, {7, 5}};
        for (int[] c : left) {
            for (int k = 0; k < c[1]; k++) {
                Xf at = Xf.move(-0.245 + c[0] * 0.07 + (r.nextDouble() - 0.5) * 0.006, 0.665 + k * 0.095, zIn + 0.012).mul(Xf.rotZ((r.nextDouble() - 0.5) * 7));
                cigPack(m, at, c[0], packSide);
            }
        }
        // the empty ones show the spiral of their pushers
        for (int c : new int[] {2, 6}) {
            barLimb(m, id, new double[] {-0.245 + c * 0.07, 0.63, zIn - 0.02}, new double[] {-0.245 + c * 0.07, 1.14, zIn - 0.02}, 0.004, 0.004, jukeWorn(P_WCHROME, r));
        }

        // ---- the door: all the upper front, its lock forced, sprung on its far hinges
        Xf door = Xf.move(-w / 2, 0, zf).mul(Xf.rotY(-13)).mul(Xf.move(w / 2, 0, -zf));
        double fT = 0.02, top = h - 0.006;
        // the frame round the window
        jukeBox(m, door, w, top - 1.17, fT, 0, (top + 1.17) / 2, zf + fT / 2, jukeWorn(P_CIGBODY, r));
        jukeBox(m, door, w, 0.1, fT, 0, low + 0.056, zf + fT / 2, jukeWorn(P_CIGBODY, r));
        jukeBox(m, door, 0.035, 0.53, fT, -w / 2 + 0.0175, 0.9, zf + fT / 2, jukeWorn(P_CIGBODY, r));
        jukeBox(m, door, 0.035, 0.53, fT, w / 2 - 0.0175, 0.9, zf + fT / 2, jukeWorn(P_CIGBODY, r));
        // chrome round the window, a piece torn off and sticking out
        jukeBox(m, door, 0.006, 0.53, 0.024, -w / 2 + 0.035, 0.9, zf + 0.012, jukeWorn(P_CIGTRIM, r));
        jukeBox(m, door, 0.006, 0.53, 0.024, w / 2 - 0.035, 0.9, zf + 0.012, jukeWorn(P_CIGTRIM, r));
        jukeBox(m, door, w - 0.07, 0.008, 0.024, 0, 1.166, zf + 0.012, jukeWorn(P_CIGTRIM, r));
        jukeBox(m, door, w * 0.52, 0.008, 0.024, 0.14, 0.636, zf + 0.012, jukeWorn(P_CIGTRIM, r));
        jukeBox(m, door.mul(Xf.move(-0.02, 0.636, zf + 0.02)).mul(Xf.rotY(-24)).mul(Xf.rotZ(-5)), w * 0.3, 0.008, 0.008, -w * 0.15, 0, 0, jukeWorn(P_CIGTRIM, r));
        // the header, its glass cracked, in a chrome frame
        barSheet(m, door, w - 0.05, 0.19, 0, 1.3, zf + fT + 0.002, 0, barPic(P_CIGHEAD));
        for (double y : new double[] {1.2, 1.4}) jukeBox(m, door, w - 0.04, 0.01, 0.012, 0, y, zf + fT + 0.004, jukeWorn(P_CIGTRIM, r));
        for (int sx = -1; sx <= 1; sx += 2) jukeBox(m, door, 0.01, 0.21, 0.012, sx * (w / 2 - 0.02), 1.3, zf + fT + 0.004, jukeWorn(P_CIGTRIM, r));
        // the knobs on their rail, a tag over each: two gone, their holes left; one pulled out and stuck, one bent
        Xf rail = Xf.move(0, 0.595, zf + fT);
        jukeBox(m, door.mul(rail), w - 0.05, 0.075, 0.004, 0, 0, 0.001, jukeWorn(P_CIGTRIM, r));
        barSheet(m, door.mul(rail), 0.56, 0.02, 0, 0.022, 0.0035, 0, barPic(P_CIGTAGS));
        for (int i = 0; i < 8; i++) {
            double x = -0.245 + i * 0.07;
            Xf at = door.mul(rail).mul(Xf.move(x, -0.012, 0)).mul(Xf.rotX(90));
            if (i == 2 || i == 6) {
                barLathe(m, 8, new double[][] {{0.003, 0.009}, {0.005, 0.009}}, at, barMat(M_BLACK), true, false);
                continue;
            }
            double pull = i == 4 ? 0.075 : 0;
            if (i == 1) at = at.mul(Xf.rotX(16)).mul(Xf.rotZ(-8));
            double[] uv = jukeWorn(P_WCHROME, r);
            barLathe(m, 8, new double[][] {{0, 0.012}, {0.006, 0.01}, {0.008, 0.005}, {0.03 + pull, 0.005}}, at, uv, false, false);
            barLathe(m, 10, new double[][] {{0.03 + pull, 0.011}, {0.035 + pull, 0.015}, {0.05 + pull, 0.015}, {0.055 + pull, 0.009}}, at, uv, false, true);
        }
        // the lock, ripped out: a hole, its bright edge
        barLathe(m, 10, new double[][] {{0.021, 0.018}, {0.023, 0.015}}, door.mul(Xf.move(w / 2 - 0.018, 0.78, zf)).mul(Xf.rotX(90)), barMat(M_BLACK), true, false);

        // the bar it was done with, still in the gap, its hook out
        double[] bar = jukeWorn(P_WSTEEL, r);
        double[][] way = {{w / 2 + 0.004, 0.86, zf + 0.012}, {w / 2 + 0.14, 0.76, zf + 0.25}, {w / 2 + 0.3, 0.67, zf + 0.5}};
        barLimb(m, id, new double[] {w / 2 - 0.05, 0.92, zf - 0.03}, way[0], 0.008, 0.011, bar);
        barLimb(m, id, way[0], way[1], 0.011, 0.012, bar);
        barLimb(m, id, way[1], way[2], 0.012, 0.012, bar);
        barLimb(m, id, way[2], new double[] {w / 2 + 0.33, 0.61, zf + 0.54}, 0.012, 0.01, bar);
        barLimb(m, id, new double[] {w / 2 + 0.33, 0.61, zf + 0.54}, new double[] {w / 2 + 0.31, 0.57, zf + 0.5}, 0.01, 0.005, bar);

        // ---- it goes over: its long way along x, the head at -x, rolled towards the camera; flat on the crate
        double roll = Math.toRadians(-32), s = Math.sin(roll), c = Math.cos(roll), minY = 1e9;
        for (double[] v : m.verts) {
            double x = v[0], y = v[1], z = v[2], nx = v[3], ny = v[4], nz = v[5];
            v[0] = h / 2 - y;
            v[1] = x * s + z * c;
            v[2] = -x * c + z * s;
            v[3] = -ny;
            v[4] = nx * s + nz * c;
            v[5] = -nx * c + nz * s;
            if (x < 1e8) minY = Math.min(minY, v[1]);
        }
        double lift = -(w / 2 * s - d / 2 * c);   // (its near back edge on the floor; the bar's end may touch down)
        for (double[] v : m.verts) v[1] += lift;

        // what it lies on, its far edge up: two old crates, one broken in, a board fallen off
        double crateH = -w / 2 * s - d / 2 * c + lift, cz = w / 2 * c - d / 2 * s;
        double[] plank = barMat(M_PLANK);
        for (double[] k : new double[][] {{0.42, 6}, {-0.36, -9}}) {
            Xf at = Xf.move(k[0], 0, cz + 0.08).mul(Xf.rotY(k[1]));
            for (int i = 0; i < 3; i++) {
                double y = 0.05 + i * (crateH - 0.06) / 2.6;
                jukeBox(m, at, 0.44, 0.075, 0.012, 0, y, 0.2, plank);
                jukeBox(m, at, 0.44, 0.075, 0.012, 0, y, -0.2, plank);
                jukeBox(m, at, 0.012, 0.075, 0.4, 0.22, y, 0, plank);
                jukeBox(m, at, 0.012, 0.075, 0.4, -0.22, y, 0, plank);
            }
            for (double[] e : new double[][] {{-0.21, -0.19}, {0.21, -0.19}, {-0.21, 0.19}, {0.21, 0.19}}) jukeBox(m, at, 0.025, crateH - 0.012, 0.025, e[0], (crateH - 0.012) / 2, e[1], barMat(M_DARK));
        }
        barBox(m, Xf.move(0.1, 0.012, cz - 0.2).mul(Xf.rotY(21)), 0.44, 0.012, 0.075, 0, 0, 0, M_PLANK);

        // the cash box on the floor before it, forced, on its side; what it held gone but for a few
        Xf cash = Xf.move(0.72, 0, -0.58).mul(Xf.rotY(38));
        double[] csteel = barPic(P_WSTEEL);
        jukeBox(m, cash, 0.13, 0.004, 0.16, 0, 0.002, 0, csteel);
        jukeBox(m, cash, 0.004, 0.075, 0.16, -0.063, 0.038, 0, jukeWorn(P_WSTEEL, r));
        jukeBox(m, cash, 0.004, 0.075, 0.16, 0.063, 0.038, 0, jukeWorn(P_WSTEEL, r));
        jukeBox(m, cash, 0.13, 0.075, 0.004, 0, 0.038, -0.078, jukeWorn(P_WSTEEL, r));
        jukeBox(m, cash, 0.13, 0.075, 0.004, 0, 0.038, 0.078, jukeWorn(P_WSTEEL, r));
        jukeBox(m, cash.mul(Xf.move(0, 0.076, -0.08)).mul(Xf.rotX(-118)), 0.13, 0.004, 0.16, 0, 0, 0.08, jukeWorn(P_WSTEEL, r));
        // the packs that fell, trodden on some, the coins that rolled
        double[][] fell = {{-0.62, 0.62, 30, 2}, {-0.42, 0.78, -40, 6}, {-0.3, 0.55, 75, 2}, {-0.12, 0.9, 12, 0}, {0.05, 0.68, -60, 3}, {0.28, 0.84, 140, 6},
            {0.38, 0.62, 50, 1}, {0.62, 0.92, -22, 4}, {-0.78, 0.85, 95, 7}, {0.9, 0.72, 15, 5}, {-0.08, 1.15, 60, 2}, {0.5, 1.12, -100, 0}, {-0.5, 1.05, 170, 3}};
        for (int i = 0; i < fell.length; i++) {
            double[] f = fell[i];
            boolean flat = i % 4 == 2;   // trodden flat
            Xf at = Xf.move(f[0], 0.012, -f[1]).mul(Xf.rotY(f[2])).mul(Xf.rotX(-90));
            if (flat) at = Xf.move(f[0], 0.006, -f[1]).mul(Xf.rotY(f[2])).mul(Xf.rotX(-90)).mul(Xf.scale(1.1, 1, 0.3));
            cigPack(m, at, (int) f[3], packSide);
        }
        // one leaning against the machine's foot
        cigPack(m, Xf.move(0.74, 0.05, -0.36).mul(Xf.rotY(90)).mul(Xf.rotX(-52)), 4, packSide);
        for (int i = 0; i < 26; i++) {
            double a = r.nextDouble() * 6.28, rr = 0.1 + r.nextDouble() * 0.5;
            double x = 0.72 + Math.cos(a) * rr * 1.6 - 0.2, z = -0.72 + Math.sin(a) * rr * 0.7;
            barLathe(m, 8, new double[][] {{0, 0.012}, {0.002, 0.012}}, Xf.move(x, 0.001, z), barMat(i % 3 == 0 ? M_COPPER : M_METAL), true, false);
        }
        barFinish(m, name);
    }

    /**
     * The jukebox, dead a long time (the author, 2026-11-01: a whole, detailed model, the game's
     * colours; then: too new - old, broken, depressing): faces +z, its feet at y = 0. It stands
     * crooked, a foot gone, propped on half a brick; its window empty, the record broken, the
     * arm snapped; a clasp and pieces of the arches gone; bars of the grille out; keys missing.
     */
    static void barJukebox(String name) throws IOException {
        Mesh m = new Mesh();
        Xf id = Xf.id();
        Random r = new Random(1942);
        double zf = JFRONT, y0 = 0.075;
        double[] side = barPic(P_JSIDE), gold = barPic(P_WGOLD), chrome = barPic(P_WCHROME), red = barPic(P_WRED), green = barPic(P_WGREEN), steel = barPic(P_WSTEEL);
        // the case: the plinth, the steel shell, its back
        jukeBox(m, id, JW + 0.05, 0.04, 0.66, 0, 0.02, 0, steel);
        jukeBox(m, id, JW + 0.02, 0.04, 0.63, 0, 0.055, 0, jukeWorn(P_WSTEEL, r));
        jukeSweep(m, new double[][] {{0, -zf}, {0, zf}}, y0, side);
        jukeSheet(m, 0, y0, -zf, side, true);
        // (its front, round the window's well: a whole sheet shut the well off)
        jukeSweep(m, new double[][] {{0.02, zf}, {0.19, zf}}, y0, steel);
        m.quad(new double[] {-(JW / 2 - 0.19), y0, zf}, new double[] {JW / 2 - 0.19, y0, zf}, new double[] {JW / 2 - 0.19, 0.97, zf}, new double[] {-(JW / 2 - 0.19), 0.97, zf}, barMat(M_IRON));
        for (int sx = -1; sx <= 1; sx += 2) {
            for (int i = 0; i < 5; i++) barBox(m, id, 0.006, 0.34, 0.016, sx * JW / 2, 0.92, -0.14 + i * 0.07, M_BLACK);
        }
        // the front's arches: gold, chrome, red, the green, chrome again; stretches torn away
        double[][] goldP = jukeTube(0.0, 0.05, zf, 0.035), redP = jukeTube(0.068, 0.092, zf, 0.022), chromeP = jukeTube(0.05, 0.068, zf, 0.016);
        jukeSweep(m, goldP, y0, gold, 0, 19);
        jukeSweep(m, goldP, y0, gold, 23, 30);
        jukeSweep(m, chromeP, y0, chrome, 0, 21);
        jukeSweep(m, chromeP, y0, chrome, 22, 30);
        jukeSweep(m, redP, y0, red, 0, 7);
        jukeSweep(m, redP, y0, red, 11, 18);
        jukeSweep(m, redP, y0, red, 24, 30);
        jukeSweep(m, new double[][] {{0.092, zf + 0.006}, {0.17, zf + 0.012}}, y0, green);
        jukeSweep(m, jukeTube(0.17, 0.19, zf + 0.008, 0.016), y0, chrome);
        // a torn end of the gold, bent out from the case
        Xf bent = Xf.move(0, JSPRING, zf).mul(Xf.rotZ(-52)).mul(Xf.move(0, JW / 2 - 0.025, 0.05)).mul(Xf.rotX(38));
        jukeBox(m, bent, 0.05, 0.016, 0.13, 0, 0, 0, jukeWorn(P_WGOLD, r));
        // the clasps: the top one crooked, the left in place; the right one gone, its screws left
        Xf c = Xf.move(0, JSPRING, zf).mul(Xf.rotZ(0)).mul(Xf.move(0.01, JW / 2 - 0.09, 0.03)).mul(Xf.rotZ(7));
        jukeBox(m, c, 0.11, 0.135, 0.03, 0, 0, 0, red);
        jukeBox(m, c, 0.01, 0.145, 0.036, -0.055, 0, 0, jukeWorn(P_WCHROME, r));
        jukeBox(m, c, 0.01, 0.145, 0.036, 0.055, 0, 0, jukeWorn(P_WCHROME, r));
        c = Xf.move(0, JSPRING, zf).mul(Xf.rotZ(58)).mul(Xf.move(0, JW / 2 - 0.09, 0.03));
        jukeBox(m, c, 0.11, 0.135, 0.03, 0, 0, 0, jukeWorn(P_WRED, r));
        jukeBox(m, c, 0.01, 0.145, 0.036, -0.055, 0, 0, jukeWorn(P_WCHROME, r));
        jukeBox(m, c, 0.01, 0.145, 0.036, 0.055, 0, 0, jukeWorn(P_WCHROME, r));
        c = Xf.move(0, JSPRING, zf).mul(Xf.rotZ(-58)).mul(Xf.move(0, JW / 2 - 0.09, 0.016));
        for (int i = -1; i <= 1; i += 2) barBox(m, c, 0.012, 0.012, 0.01, i * 0.04, 0.04, 0.012, M_BLACK);

        // the window: a shallow well, the glass gone (no shards: the author, 2026-11-01)
        double wellY = 0.97, ins = 0.19, deep = 0.06;   // (shallow: deeper, no light of the room reached the records)
        jukeSweep(m, new double[][] {{ins, zf + 0.008}, {ins, zf - deep}}, wellY, barMat(M_WELL));
        jukeSheet(m, ins, wellY, zf - deep, jukeWorn(P_WGREEN, r), false);
        // the record, slid off its spindle and hanging crooked, a wedge broken out; the arm snapped, the deck rusted
        Xf disc = Xf.move(0.025, JSPRING - 0.015, zf - deep + 0.012).mul(Xf.rotZ(-13)).mul(Xf.rotX(90));
        jukeDisc(m, disc, 0.172, 0.006, barMat(M_METAL), 304, 340);
        jukeDisc(m, disc, 0.162, 0.0072, barMat(M_COAL), 304, 340);
        for (double g : new double[] {0.14, 0.115, 0.09}) {
            jukeDisc(m, disc, g + 0.002, 0.0078, barMat(M_IRON), 304, 340);
            jukeDisc(m, disc, g - 0.002, 0.0084, barMat(M_COAL), 304, 340);
        }
        jukeDisc(m, disc, 0.05, 0.009, jukeWorn(P_WRED, r), 999, 999);
        jukeDisc(m, disc, 0.012, 0.0096, barMat(M_BLACK), 999, 999);
        barLimb(m, id, new double[] {0.2, wellY + 0.05, zf - 0.02}, new double[] {0.17, JSPRING - 0.08, zf - 0.015}, 0.008, 0.007, jukeWorn(P_WCHROME, r));
        barLimb(m, id, new double[] {0.17, JSPRING - 0.08, zf - 0.015}, new double[] {0.09, JSPRING - 0.13, zf + 0.012}, 0.007, 0.005, jukeWorn(P_WCHROME, r));
        jukeBox(m, id, 0.3, 0.05, 0.03, 0, wellY + 0.03, zf - deep + 0.015, jukeWorn(P_WSTEEL, r));

        // the selector under the window, knocked askew: its frame, the cards gone yellow, keys missing, one hanging
        Xf sel = Xf.move(0, 0.875, zf + 0.02).mul(Xf.rotX(-8)).mul(Xf.rotZ(-2.6));
        jukeBox(m, sel, JW - 2 * ins + 0.02, 0.17, 0.04, 0, 0, 0, chrome);
        barBox(m, sel, JW - 2 * ins - 0.03, 0.135, 0.004, 0, 0, 0.021, M_BLACK);
        barSheet(m, sel, 0.4, 0.085, 0, 0.022, 0.0235, 0, barPic(P_JTITLES));
        for (int row = 0; row < 2; row++) {
            for (int i = 0; i < 10; i++) {
                if ((row == 0 && (i == 2 || i == 7)) || (row == 1 && (i == 0 || i == 4 || i == 5))) continue;
                double[] uv = row == 0 ? jukeWorn(P_WGOLD, r) : jukeWorn(P_WRED, r);
                jukeBox(m, sel, 0.028, 0.012, row == 1 && i == 8 ? 0.004 : 0.012, -0.18 + i * 0.04, -0.038 - row * 0.016, 0.028, uv);
            }
        }
        jukeBox(m, sel.mul(Xf.move(-0.02, -0.065, 0.032)).mul(Xf.rotZ(38)), 0.028, 0.012, 0.012, 0, -0.012, 0, jukeWorn(P_WRED, r));
        jukeBox(m, id, JW - 2 * ins, 0.025, 0.03, 0, 0.785, zf + 0.012, jukeWorn(P_WRED, r));

        // the speaker: rotted cloth; bars out and bent; the fin across them torn off at one end
        double spMid = 0.53, spH = 0.46, spW = 0.34, spB = spMid - spH / 2, spT = spMid + spH / 2;
        barSheet(m, id, spW, spH, 0, spMid, zf + 0.008, 0, barPic(P_JCLOTH));
        for (double x : new double[] {-spW / 2, spW / 2}) jukeBox(m, id, 0.016, spH + 0.016, 0.03, x, spMid, zf + 0.018, jukeWorn(P_WCHROME, r));
        for (double y : new double[] {spB, spT}) jukeBox(m, id, spW + 0.016, 0.016, 0.03, 0, y, zf + 0.018, jukeWorn(P_WCHROME, r));
        for (int i = 0; i < 11; i++) {
            double x = -0.14 + i * 0.028;
            double[] uv = jukeWorn(P_WSTEEL, r);
            if (i == 2 || i == 6 || i == 7) continue;     // gone
            if (i == 3 || i == 9) {                       // bent out at the middle
                double bx = x + (i == 3 ? -0.018 : 0.012), bz = zf + 0.05;
                barLimb(m, id, new double[] {x, spB, zf + 0.02}, new double[] {bx, spMid, bz}, 0.006, 0.006, uv);
                barLimb(m, id, new double[] {bx, spMid, bz}, new double[] {x, spT, zf + 0.02}, 0.006, 0.006, uv);
            } else if (i == 5) {                          // broken off at the top, hanging
                barLimb(m, id, new double[] {x, spB, zf + 0.02}, new double[] {x + 0.03, spMid + 0.03, zf + 0.04}, 0.006, 0.006, uv);
            } else {
                barLathe(m, 6, new double[][] {{spB, 0.006}, {spT, 0.006}}, Xf.move(x, 0, zf + 0.02), uv, false, false);
            }
        }
        jukeBox(m, Xf.move(-spW / 2, spMid + 0.012, zf + 0.03).mul(Xf.rotZ(-16)), spW * 0.92, 0.022, 0.02, spW * 0.46, 0, 0, jukeWorn(P_WCHROME, r));
        // the tubes: the left whole and dark, the right broken off, a jagged stub, its cap left above
        Xf t = Xf.move(-0.2, 0, zf + 0.022);
        barLathe(m, 10, new double[][] {{0.3, 0.015}, {0.76, 0.015}}, t, jukeWorn(P_WGOLD, r), false, false);
        barLathe(m, 10, new double[][] {{0.28, 0.019}, {0.31, 0.019}}, t, jukeWorn(P_WCHROME, r), true, true);
        barLathe(m, 10, new double[][] {{0.75, 0.019}, {0.78, 0.019}}, t, jukeWorn(P_WCHROME, r), true, true);
        t = Xf.move(0.2, 0, zf + 0.022);
        barLathe(m, 10, new double[][] {{0.3, 0.015}, {0.43, 0.012}, {0.47, 0.003}}, t, jukeWorn(P_WGOLD, r), false, false);
        barLathe(m, 10, new double[][] {{0.28, 0.019}, {0.31, 0.019}}, t, jukeWorn(P_WCHROME, r), true, true);
        barLathe(m, 10, new double[][] {{0.71, 0.005}, {0.75, 0.012}}, t, jukeWorn(P_WGOLD, r), false, false);
        barLathe(m, 10, new double[][] {{0.75, 0.019}, {0.78, 0.019}}, t, jukeWorn(P_WCHROME, r), true, true);

        // the mottled panel low down, cracked, a hole kicked in it; the coin plate pried off, hanging on one screw
        barSheet(m, id, JW - 2 * ins, 0.18, 0, 0.19, zf + 0.012, 0, barPic(P_JPANEL));
        jukeBox(m, id, JW - 2 * ins + 0.01, 0.014, 0.024, 0, 0.285, zf + 0.012, jukeWorn(P_WCHROME, r));
        jukeBox(m, id, JW - 2 * ins + 0.01, 0.014, 0.024, 0, 0.095, zf + 0.012, jukeWorn(P_WCHROME, r));
        Xf plate = Xf.move(0.09, 0.245, zf + 0.02).mul(Xf.rotZ(-24));
        jukeBox(m, plate, 0.07, 0.11, 0.008, 0.0, -0.05, 0, jukeWorn(P_WCHROME, r));
        barBox(m, plate, 0.03, 0.004, 0.004, 0.0, -0.03, 0.005, M_BLACK);
        barBox(m, plate, 0.01, 0.01, 0.006, 0.0, -0.004, 0.005, M_BLACK);

        // snow blown in on the top and on the plinth
        jukeSweep(m, new double[][] {{-0.012, -0.22}, {-0.016, 0.0}, {-0.006, 0.24}}, y0, barMat(M_SNOW), 11, 20);
        barLathe(m, 10, new double[][] {{0.04, 0.2}, {0.056, 0.11}, {0.064, 0.03}}, Xf.move(-0.18, 0, zf + 0.04).mul(Xf.scale(1.3, 1, 0.3)), barMat(M_SNOW), true, false);

        // it leans: a foot gone on its left, half a brick under that corner
        double lean = Math.toRadians(-2.2), lc = Math.cos(lean), ls = Math.sin(lean), px = (JW + 0.05) / 2;
        for (double[] v : m.verts) {
            double x = v[0] - px, y = v[1], nx = v[3], ny = v[4];
            v[0] = px + lc * x - ls * y;
            v[1] = ls * x + lc * y;
            v[3] = lc * nx - ls * ny;
            v[4] = ls * nx + lc * ny;
        }
        barBox(m, id, 0.17, 0.034, 0.1, -JW / 2 + 0.06, 0.017, 0.16, M_BRICK);
        barBox(m, id, 0.17, 0.03, 0.1, -JW / 2 + 0.06, 0.015, -0.16, M_RUST);
        barFinish(m, name);
    }

    static void barPint(Mesh m, Xf at, boolean full) {
        if (full) {
            barLathe(m, 12, new double[][] {{0, 0.034}, {0.13, 0.043}}, at, barMat(M_BEER), false, true);
            barLathe(m, 12, new double[][] {{0.13, 0.043}, {0.16, 0.046}}, at, barMat(M_FOAM), true, false);
        } else {
            barLathe(m, 12, new double[][] {{0, 0.034}, {0.14, 0.044}}, at, barMat(M_GLASS), true, true);
        }
    }

    static void barShot(Mesh m, Xf at, boolean full) {
        barLathe(m, 8, new double[][] {{0, 0.02}, {0.06, 0.025}}, at, barMat(full ? M_BROWN : M_GLASS), true, true);
    }

    static void barAshtray(Mesh m, Xf at, int butts) {
        barLathe(m, 12, new double[][] {{0, 0.06}, {0.025, 0.07}}, at, barMat(M_IRON), true, true);
        barLathe(m, 12, new double[][] {{0.025, 0.05}, {0.027, 0.05}}, at, barMat(M_ASH), true, false);
        for (int i = 0; i < butts; i++) {
            m.box(0.04, 0.008, 0.008, at.mul(Xf.move(-0.02 + i * 0.015, 0.031, -0.02 + i * 0.018)).mul(Xf.rotY(40 + i * 65)),
                barMat(M_PAPER), barMat(M_PAPER));
        }
    }

    static void barPlate(Mesh m, Xf at) {
        barLathe(m, 12, new double[][] {{0, 0.06}, {0.018, 0.1}}, at, barMat(M_PLATE), true, true);
    }

    static void barChair(Mesh m, Xf at) {
        double[][] legs = {{-0.18, -0.18}, {0.18, -0.18}, {-0.18, 0.18}, {0.18, 0.18}};
        for (double[] l : legs) barBox(m, at, 0.04, 0.45, 0.04, l[0], 0.225, l[1], M_DARK);
        barBox(m, at, 0.42, 0.04, 0.42, 0, 0.47, 0, M_VARNISH);
        barBox(m, at, 0.04, 0.5, 0.04, -0.19, 0.74, -0.19, M_DARK);
        barBox(m, at, 0.04, 0.5, 0.04, 0.19, 0.74, -0.19, M_DARK);
        barBox(m, at, 0.4, 0.09, 0.025, 0, 0.93, -0.19, M_VARNISH);
        barBox(m, at, 0.4, 0.06, 0.025, 0, 0.72, -0.19, M_VARNISH);
    }

    static void barRoundTable(Mesh m, Xf at, double r) {
        barLathe(m, 10, new double[][] {{0.03, 0.05}, {0.74, 0.05}}, at, barMat(M_DARK), false, false);
        barLathe(m, 14, new double[][] {{0, 0.28}, {0.03, 0.25}}, at, barMat(M_DARK), true, true);
        barLathe(m, 22, new double[][] {{0.74, r}, {0.78, r}}, at, barMat(M_VARNISH), true, true);
    }

    static void barSquareTable(Mesh m, Xf at) {
        double[][] legs = {{-0.33, -0.33}, {0.33, -0.33}, {-0.33, 0.33}, {0.33, 0.33}};
        for (double[] l : legs) barBox(m, at, 0.05, 0.74, 0.05, l[0], 0.37, l[1], M_DARK);
        barBox(m, at, 0.8, 0.04, 0.8, 0, 0.76, 0, M_VARNISH);
    }

    static void barCards(Mesh m, Xf at, int seed) {
        Random rnd = new Random(seed);
        int[][] faces = {P_CARD_BACK, P_CARD_ACE, P_CARD_SEVEN, P_CARD_BACK, P_CARD_BACK, P_CARD_SEVEN};
        for (int i = 0; i < faces.length; i++) {
            barFlat(m, at, 0.06, 0.09, (rnd.nextDouble() - 0.5) * 0.22, 0.002 + i * 0.0006, (rnd.nextDouble() - 0.5) * 0.16,
                (rnd.nextDouble() - 0.5) * 120, barPic(faces[i]));
        }
    }

    /** A drift, 1 m in radius and 1 m high: Lua scales it to its place. */
    static void barDrift(String name) throws IOException {
        Mesh m = new Mesh();
        int n = 32;
        double[][] h = new double[n + 1][n + 1];
        for (int i = 0; i <= n; i++) {
            for (int j = 0; j <= n; j++) {
                double x = -1 + 2.0 * i / n, z = -1 + 2.0 * j / n, r = Math.sqrt(x * x + z * z);
                // (the mockup's dome, 2026-10-31: the room's real light showed the facets of a rougher one)
                h[i][j] = Math.sqrt(Math.max(0, 1 - r * r)) * (1 + 0.25 * Math.sin(x * 6) * Math.cos(z * 5));
            }
        }
        double[] uv = barMat(M_SNOW);
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                if (h[i][j] + h[i + 1][j] + h[i][j + 1] + h[i + 1][j + 1] <= 0) continue;
                double x0 = -1 + 2.0 * i / n, x1 = -1 + 2.0 * (i + 1) / n, z0 = -1 + 2.0 * j / n, z1 = -1 + 2.0 * (j + 1) / n;
                m.quad(new double[] {x0, h[i][j + 1], z1}, new double[] {x1, h[i + 1][j + 1], z1},
                    new double[] {x1, h[i + 1][j], z0}, new double[] {x0, h[i][j], z0}, uv);
            }
        }
        barScale(m);
        m.write(name);
    }

    static void barFinish(Mesh m, String name) throws IOException {
        barScale(m);
        m.write(name);
    }

    /** An empty glass tumbler, open at its top (its inside is a face of its own). */
    static void barTumbler(Mesh m, Xf at) {
        barLathe(m, 12, new double[][] {{0, 0.035}, {0.12, 0.04}, {0.12, 0.037}, {0.004, 0.032}}, at, barMat(M_GLASS), false, true);
    }

    /** A candle burnt down to a stub, its wick black. */
    static void barStub(Mesh m, Xf at) {
        barLathe(m, 12, new double[][] {{0, 0.035}, {0.006, 0.04}, {0.012, 0.022}, {0.04, 0.02}, {0.05, 0.016}}, at, barMat(M_WAX), true, true);
        barLimb(m, at, new double[] {0, 0.05, 0}, new double[] {0.002, 0.062, 0}, 0.0016, 0.0012, barMat(M_BLACK));
    }

    /**
     * A flat sheet held at one edge (local x 0, the picture's top), the rest free to x = length, in
     * strips across: KnoxBarFrame bends it (room.vert: uFlutter). Its face up (y).
     */
    static void barLooseSheet(Mesh m, double length, double width, double[] uv) {
        int n = 10;
        double w = width / 2, y = 0.003;
        for (int i = 0; i < n; i++) {
            double x0 = length * i / n, x1 = length * (i + 1) / n;
            double v0 = uv[3] + (uv[1] - uv[3]) * i / n, v1 = uv[3] + (uv[1] - uv[3]) * (i + 1) / n;
            m.quad(new double[] {x1, y, w}, new double[] {x1, y, -w}, new double[] {x0, y, -w}, new double[] {x0, y, w},
                new double[] {uv[0], v1, uv[2], v0});
        }
    }

    /** A newspaper dropped on the floor, a little crumpled (the mockup's). */
    static void barPaper(Mesh m, double x, double z, double deg, double s) {
        Xf f = Xf.move(x, 0, z).mul(Xf.rotY(deg));
        double w = 0.56 * s, d = 0.4 * s;
        int nx = 8, nz = 6;
        double[] uv = barPic(P_NEWS);
        double[][] y = new double[nx + 1][nz + 1];
        for (int i = 0; i <= nx; i++) {
            for (int j = 0; j <= nz; j++) {
                double lx = -w / 2 + w * i / nx, lz = -d / 2 + d * j / nz;
                // (3 mm up where it is flattest: 8 mm read as hanging over the floor - QA, 2026-10-31)
                y[i][j] = 0.003 + Math.max(0, (Math.sin(lx * 17 + deg * 0.087) * Math.cos(lz * 13) + 0.4) * 0.018);
            }
        }
        for (int i = 0; i < nx; i++) {
            for (int j = 0; j < nz; j++) {
                double lx0 = -w / 2 + w * i / nx, lx1 = -w / 2 + w * (i + 1) / nx;
                double lz0 = -d / 2 + d * j / nz, lz1 = -d / 2 + d * (j + 1) / nz;
                double u0 = uv[0] + (uv[2] - uv[0]) * i / nx, u1 = uv[0] + (uv[2] - uv[0]) * (i + 1) / nx;
                double v0 = uv[3] + (uv[1] - uv[3]) * j / nz, v1 = uv[3] + (uv[1] - uv[3]) * (j + 1) / nz;
                m.quad(f.point(lx0, y[i][j + 1], lz1), f.point(lx1, y[i + 1][j + 1], lz1), f.point(lx1, y[i + 1][j], lz0),
                    f.point(lx0, y[i][j], lz0), new double[] {u0, v1, u1, v0});
            }
        }
    }

    /** Butts on the floor round cx, cz: filters and the paper burnt down to them. */
    static void barButts(Mesh m, double cx, double cz, int n, double rad, Random rnd) {
        for (int i = 0; i < n; i++) {
            barBox(m, Xf.move(cx + (rnd.nextDouble() - 0.5) * 2 * rad, 0.0045, cz + (rnd.nextDouble() - 0.5) * 2 * rad)
                .mul(Xf.rotY(rnd.nextDouble() * 360)), 0.015 + rnd.nextDouble() * 0.015, 0.009, 0.009, 0, 0, 0,
                rnd.nextBoolean() ? M_PAPER : M_GLOVE);
        }
    }

    /**
     * A box of bakelite from x0 to x1, 0 to h, depth d round z 0, its top dented at dentX
     * (a grid that sinks there). Its front (+z) is left to a picture.
     */
    static void barShell(Mesh m, Xf at, double x0, double x1, double h, double d, double[] uv, double dentX, double dent) {
        double z0 = -d / 2, z1 = d / 2;
        m.quad(at.point(x1, 0, z0), at.point(x0, 0, z0), at.point(x0, h, z0), at.point(x1, h, z0), uv);   // back
        m.quad(at.point(x0, 0, z0), at.point(x0, 0, z1), at.point(x0, h, z1), at.point(x0, h, z0), uv);   // ends
        m.quad(at.point(x1, 0, z1), at.point(x1, 0, z0), at.point(x1, h, z0), at.point(x1, h, z1), uv);
        m.quad(at.point(x0, 0, z1), at.point(x1, 0, z1), at.point(x1, h, z1), at.point(x0, h, z1), uv);   // front, under its picture
        int nx = 8, nz = 4;
        double[][] y = new double[nx + 1][nz + 1];
        for (int i = 0; i <= nx; i++) {
            for (int j = 0; j <= nz; j++) {
                double x = x0 + (x1 - x0) * i / nx, z = z0 + d * j / nz;
                double e = (i == 0 || i == nx || j == 0 || j == nz) ? 0 : 1;
                y[i][j] = h - e * dent * Math.exp(-Math.pow((x - dentX) / 0.045, 2) - Math.pow(z / 0.035, 2));
            }
        }
        for (int i = 0; i < nx; i++) {
            for (int j = 0; j < nz; j++) {
                double xa = x0 + (x1 - x0) * i / nx, xb = x0 + (x1 - x0) * (i + 1) / nx;
                double za = z0 + d * j / nz, zb = z0 + d * (j + 1) / nz;
                m.quad(at.point(xa, y[i][j + 1], zb), at.point(xb, y[i + 1][j + 1], zb), at.point(xb, y[i + 1][j], za),
                    at.point(xa, y[i][j], za), uv);
            }
        }
    }

    static void barProps() throws IOException {
        Xf id = Xf.id();
        Mesh m;
        Random rnd = new Random(481);

        // a plain wooden stool at the counter (the author, 2026-11-02, in place of the red padded ones):
        // a round seat at the same height, four legs splayed, rungs between them
        m = new Mesh();
        barLathe(m, 20, new double[][] {{0.79, 0.17}, {0.82, 0.185}, {0.84, 0.17}}, id, barMat(M_VARNISH), true, true);
        for (int sx = -1; sx <= 1; sx += 2) for (int sz = -1; sz <= 1; sz += 2)
            barLimb(m, id, new double[] {sx * 0.11, 0.8, sz * 0.11}, new double[] {sx * 0.17, 0, sz * 0.17}, 0.018, 0.021, barMat(M_VARNISH));
        for (int s = -1; s <= 1; s += 2) {
            barLimb(m, id, new double[] {-0.148, 0.3, s * 0.148}, new double[] {0.148, 0.3, s * 0.148}, 0.012, 0.012, barMat(M_DARK));
            barLimb(m, id, new double[] {s * 0.137, 0.45, -0.137}, new double[] {s * 0.137, 0.45, 0.137}, 0.012, 0.012, barMat(M_DARK));
        }
        barFinish(m, "bar_stool");

        // panels along the counter's face on our side
        m = new Mesh();
        for (double x = -3.5; x <= 3.51; x += 0.875) barBox(m, id, 0.07, 0.94, 0.02, x, 0.52, 0.01, M_VARNISH);
        barBox(m, id, 7.0, 0.05, 0.025, 0, 0.98, 0.012, M_VARNISH);
        barBox(m, id, 7.0, 0.1, 0.03, 0, 0.05, 0.012, M_VARNISH);
        barFinish(m, "bar_counter_panels");

        // the journal left open by the empty stool (a new game), its next page clean: its own model, to be pointed at
        m = new Mesh();
        barJournal(m, Xf.rotY(10));
        barFinish(m, "bar_journal");
        m = new Mesh();
        barJournalPage(m);
        barFinish(m, "bar_journal_page");
        // the pencil by it, its axis the model's x through 0: it rolls (KnoxBarFrame's movePencil - the author, 2026-11-02)
        m = new Mesh();
        Xf pen = Xf.rotZ(90);
        barLathe(m, 6, new double[][] {{-0.075, 0.0055}, {0.065, 0.0055}}, pen, barMat(M_GOLD), true, true);
        barLathe(m, 6, new double[][] {{0.065, 0.0055}, {0.085, 0.001}}, pen, barMat(M_CUT), false, false);
        barLathe(m, 6, new double[][] {{-0.09, 0.0055}, {-0.075, 0.0055}}, pen, barMat(M_JRED), true, true);
        barFinish(m, "bar_pencil");

        // ---- the radio the music comes from (the author, 2026-10-31: no tape on it -
        // knocked about, dented, its insides showing). Bakelite, its front to +z, on the
        // counter: the right half whole but dented, the left broken open, the speaker
        // dragged out in front on its wires, the antenna bent; chips of the case round it.
        m = new Mesh();
        double[] bake = barMat(M_BAKELITE);
        barShell(m, id, -0.03, 0.17, 0.2, 0.12, bake, 0.08, 0.016);
        barSheet(m, id, 0.2, 0.2, 0.07, 0.1, 0.0605, 0, barPic(P_RADIO));
        // the knob that is left, the bare shaft of the one that is gone
        barLathe(m, 12, new double[][] {{0, 0.016}, {0.014, 0.015}, {0.019, 0.011}}, Xf.move(0.12, 0.035, 0.06).mul(Xf.rotX(90)), bake, true, false);
        barLimb(m, id, new double[] {0.02, 0.035, 0.06}, new double[] {0.02, 0.035, 0.075}, 0.0028, 0.0028, barMat(M_CHROME));
        // the left half: its case broken away - the back, the floor and the end are left,
        // jagged where they broke, and the inside shows
        Xf lh = Xf.move(-0.1, 0, 0).mul(Xf.rotZ(3));
        barBox(m, lh, 0.14, 0.004, 0.12, 0, 0.002, 0, M_BAKELITE);
        barBox(m, lh, 0.14, 0.15, 0.006, 0, 0.075, -0.057, M_BAKELITE);
        barBox(m, lh, 0.006, 0.11, 0.12, -0.067, 0.055, 0, M_BAKELITE);
        for (int i = 0; i < 6; i++) {
            double x = -0.07 + i * 0.0233, t = 0.012 + rnd.nextDouble() * 0.03;
            double[] a = lh.point(x, 0.15, -0.057), b = lh.point(x + 0.0233, 0.15, -0.057), c = lh.point(x + 0.006 + rnd.nextDouble() * 0.012, 0.15 + t, -0.057);
            m.tri(a, b, c, bake, bake, bake);
            m.tri(a, c, b, bake, bake, bake);
        }
        barBox(m, lh, 0.12, 0.006, 0.1, 0, 0.02, 0, M_METAL);                          // the chassis
        barBox(m, lh, 0.11, 0.08, 0.004, 0, 0.065, -0.045, M_PCB);                       // a board up its back
        for (double[] t : new double[][] {{-0.035, 0.01}, {0.02, 0.022}}) {              // valves
            barLathe(m, 8, new double[][] {{0, 0.011}, {0.045, 0.011}, {0.056, 0.004}}, lh.mul(Xf.move(t[0], 0.023, t[1])), barMat(M_GLASS), true, false);
        }
        barBox(m, lh, 0.03, 0.025, 0.025, 0.045, 0.036, -0.015, M_IRON);                // the transformer
        barLathe(m, 8, new double[][] {{-0.013, 0.008}, {0.013, 0.008}}, lh.mul(Xf.move(-0.01, 0.031, 0.032)).mul(Xf.rotZ(90)), barMat(M_BLACK), true, true);
        // the speaker, torn out and lying in front of it, its cone up
        Xf sp = Xf.move(-0.1, 0.03, 0.17).mul(Xf.rotY(-25)).mul(Xf.rotX(62));
        barLathe(m, 12, new double[][] {{-0.036, 0.021}, {-0.016, 0.021}}, sp, barMat(M_IRON), false, true);
        barLathe(m, 14, new double[][] {{-0.016, 0.017}, {0.02, 0.058}}, sp, barMat(M_ASH), false, false);
        barLathe(m, 14, new double[][] {{0.02, 0.058}, {-0.016, 0.017}}, sp, barMat(M_ASH), false, false);
        barLathe(m, 14, new double[][] {{0.02, 0.058}, {0.024, 0.063}}, sp, barMat(M_METAL), false, false);
        // its wires and the loose ones, over the counter
        double[][][] wires = {
            {{-0.08, 0.05, 0.0}, {-0.11, 0.06, 0.07}, {-0.12, 0.02, 0.12}, {-0.11, 0.02, 0.155}},
            {{-0.06, 0.06, -0.01}, {-0.06, 0.09, 0.06}, {-0.07, 0.04, 0.13}, {-0.09, 0.025, 0.16}},
            {{-0.13, 0.08, 0.02}, {-0.19, 0.1, 0.0}, {-0.23, 0.04, -0.02}, {-0.25, 0.004, 0.01}}};
        int[] wireMat = {M_WRED, M_COPPER, M_WRED};
        for (int w = 0; w < wires.length; w++) {
            for (int i = 0; i + 1 < wires[w].length; i++) barLimb(m, id, wires[w][i], wires[w][i + 1], 0.0025, 0.0025, barMat(wireMat[w]));
        }
        // the antenna, bent where something hit it - back over the case (towards the hero at the
        // counter it went across his face: the author's screenshot, 2026-11-01)
        barLathe(m, 8, new double[][] {{0, 0.008}, {0.012, 0.006}}, Xf.move(0.14, 0.2, -0.04), barMat(M_CHROME), true, false);
        barLimb(m, id, new double[] {0.14, 0.2, -0.04}, new double[] {0.15, 0.33, -0.05}, 0.0035, 0.0032, barMat(M_CHROME));
        barLimb(m, id, new double[] {0.15, 0.33, -0.05}, new double[] {0.07, 0.39, -0.08}, 0.003, 0.0028, barMat(M_CHROME));
        barLimb(m, id, new double[] {0.07, 0.39, -0.08}, new double[] {-0.03, 0.4, -0.07}, 0.0025, 0.0022, barMat(M_CHROME));
        for (double[] c : new double[][] {{-0.3, 0.02, 20}, {-0.2, 0.12, 70}, {0.22, 0.09, 140}, {-0.32, 0.15, 10}}) {
            barBox(m, Xf.move(c[0], 0.003, c[1]).mul(Xf.rotY(c[2])), 0.028, 0.006, 0.018, 0, 0, 0, M_BAKELITE);
        }
        barFinish(m, "bar_radio");
        // its needle, at the dial's low end: over the dial's glass (P_RADIO's x 266, y 198..220)
        m = new Mesh();
        barSheet(m, id, 0.0045, 0.0458, -0.0092, 0.1646, 0.0615, 0, barMat(M_WRED));
        barFinish(m, "bar_radio_needle");

        // ---- the counter's things, standing on its top (KnoxMenuSceneBar puts them at x 0,
        // z 0.83): the last of the supplies - a pyramid of cans, the ammo -
        // glasses, bottles. (The author, 2026-10-31: no candle by the cans.)
        m = new Mesh();
        // the first aid kit, forced open and used up, where the cans stood; no ammo on the counter (the author, 2026-11-01)
        barAidKit(m, Xf.move(-3.28, 0, 0.05).mul(Xf.rotY(9)));
        // (no candles on it, the burning one nor the stubs: the author, 2026-11-02)
        for (double x : new double[] {-0.25, 0.2, 1.4}) barTumbler(m, Xf.move(x, 0, -0.21 + rnd.nextDouble() * 0.28));
        barBottleDown(m, Xf.move(-0.9, 0, -0.21).mul(Xf.rotY(rnd.nextDouble() * 360)), M_BROWN, P_LABEL_BEER);
        barEmpty(m, Xf.move(0.7, 0, -0.08), M_GREEN, P_LABEL_BEER);
        barFinish(m, "bar_counter_things");

        // the whiskey of the hero at the counter (the author, 2026-10-31: a bottle, not a
        // glass): on the counter at the hero's place until the heroes come in
        m = new Mesh();
        barLathe(m, 10, new double[][] {{0, 0.042}, {0.18, 0.042}, {0.22, 0.016}, {0.3, 0.014}}, id, barMat(M_BROWN), true, true);
        barLathe(m, 10, new double[][] {{0.04, 0.0432}, {0.15, 0.0432}}, id, barPic(P_LABEL_WHISKEY), false, false, true);
        barLathe(m, 8, new double[][] {{0.3, 0.0155}, {0.318, 0.0155}}, id, barMat(M_DARK), true, false);
        barFinish(m, "bar_whiskey");

        // ---- the smoker's table (a mod's round table, its top 0.815 m up): what is on it,
        // the butts round it on the floor. Made round the table's foot.
        double tt = 0.815;
        m = new Mesh();
        Xf top = Xf.move(0, tt, 0);
        Xf tray = top.mul(Xf.move(0.15, 0, -0.05));
        barLathe(m, 16, new double[][] {{0, 0.06}, {0.02, 0.065}, {0.022, 0.05}, {0.008, 0.048}}, tray, barMat(M_GLASS), false, true);
        barLathe(m, 14, new double[][] {{0.009, 0.047}, {0.0095, 0.047}}, tray, barMat(M_ASH), true, false);
        for (int i = 0; i < 6; i++) {
            barBox(m, tray.mul(Xf.move((rnd.nextDouble() - 0.5) * 0.06, 0.013, (rnd.nextDouble() - 0.5) * 0.06)).mul(Xf.rotY(rnd.nextDouble() * 360)),
                0.015 + rnd.nextDouble() * 0.015, 0.008, 0.008, 0, 0, 0, i % 2 == 0 ? M_PAPER : M_GLOVE);
        }
        barEmpty(m, top.mul(Xf.move(0.35, 0, -0.25)), M_GREEN, P_LABEL_BEER);
        int[][] cards = {P_CARD_ACE, P_CARD_BACK, P_CARD_SEVEN};
        for (int i = 0; i < 9; i++) {
            barFlat(m, top, 0.06, 0.09, (rnd.nextDouble() - 0.5) * 0.5, 0.002 + i * 0.0007, -0.2 + rnd.nextDouble() * 0.45,
                rnd.nextDouble() * 360, barPic(cards[i % 3]));
        }
        barBox(m, top, 0.055, 0.02, 0.085, -0.28, 0.01, 0.05, M_PAPER);
        barFlat(m, top, 0.055, 0.085, -0.28, 0.0205, 0.05, 0, barPic(P_CIGS));
        barButts(m, -0.1, 0, 22, 0.7, rnd);
        barFinish(m, "bar_smoker_things");

        // ---- the other table: the way north on a map, a candle stub, the compass - the
        // last ones getting ready to go
        m = new Mesh();
        barFlat(m, top, 0.5, 0.38, -0.05, 0.003, 0, 23, barPic(P_MAP));
        barStub(m, top.mul(Xf.move(0.3, 0, -0.25)));
        barLathe(m, 14, new double[][] {{0, 0.03}, {0.012, 0.03}}, top.mul(Xf.move(0.2, 0, 0.15)), barMat(M_BRASS), false, true);
        barFlat(m, top, 0.06, 0.06, 0.2, 0.0125, 0.15, 30, barPic(P_COMPASS));
        barLimb(m, top, new double[] {-0.15, 0.0075, 0.08}, new double[] {0.0, 0.0075, 0.13}, 0.0035, 0.0035, barMat(M_BYELLOW));
        barFinish(m, "bar_map_things");

        // ---- the round table's leg and foot, around those of its model, down to the floor (the
        // author's screenshots, 2026-11-01: in the game the model's leg ended in the air)
        m = new Mesh();
        // (on the model's own axis, off its middle; a hair thicker, closed all round: centred on the
        // prop the model's leg stuck out at one side, "badly glued" - the author, 2026-11-02)
        Xf legAt = Xf.move(0.0061, 0, 0.0329);
        barLathe(m, 18, new double[][] {{0.02, 0.0585}, {0.71, 0.0585}}, legAt, barMat(M_DARK), false, false);
        barLathe(m, 24, new double[][] {{0, 0.37}, {0.07, 0.37}, {0.095, 0.29}, {0.13, 0.09}, {0.2, 0.0585}}, legAt, barMat(M_DARK), true, true);
        barFinish(m, "bar_table_leg");

        // ---- the tally of days cut into the wall (on the back wall)
        m = new Mesh();
        barSheet(m, id, 0.62, 0.413, 0, 0, 0, 0, barPic(P_TALLY));
        barFinish(m, "bar_tally");

        // ---- the fire they kept on a sheet of iron on the floor, gone cold: ash, burnt
        // sticks, bricks under a pot of something frozen (its soot is in the floor)
        m = new Mesh();
        barBox(m, id, 1.16, 0.012, 0.8, 0, 0.006, 0, M_RUST);
        barLathe(m, 18, new double[][] {{0.012, 0.36}, {0.02, 0.26}, {0.028, 0.08}}, id, barMat(M_ASH), true, false);
        Random fr = new Random(491);
        for (int i = 0; i < 7; i++) {
            double len = 0.3 + fr.nextDouble() * 0.2;
            m.box(0.045, 0.04, len, Xf.move((fr.nextDouble() - 0.5) * 0.4, 0.034, (fr.nextDouble() - 0.5) * 0.3)
                .mul(Xf.rotY(fr.nextDouble() * 360)).mul(Xf.rotX((fr.nextDouble() - 0.5) * 12)), barMat(M_COAL), barMat(M_COAL));
        }
        for (double[] b : new double[][] {{-0.2, -0.17}, {0.2, -0.17}, {-0.2, 0.17}, {0.2, 0.17}}) {
            m.box(0.2, 0.068, 0.1, Xf.move(b[0], 0.046, b[1]).mul(Xf.rotY(b[0] * b[1] > 0 ? 45 : -45)), barMat(M_BRICK), barMat(M_BRICK));
        }
        Xf pot = Xf.move(0, 0.08, 0);
        barLathe(m, 20, new double[][] {{0, 0.15}, {0.16, 0.16}, {0.165, 0.17}, {0.165, 0.155}, {0.012, 0.145}}, pot, barMat(M_RUST), false, true);
        barLathe(m, 18, new double[][] {{0.099, 0.149}, {0.1, 0.149}}, pot, barMat(M_GLOVE), true, false);
        barFinish(m, "bar_fire");

        barSupplies("bar_supplies");
        barSawSet("bar_saw_set");

        // ---- the door, hung at its right post (local x from -1.08 to 0; KnoxMenuSceneBar swings
        // it out into the storm): planks, two of the boards still nailed across it on the
        // inside, iron hinges, the knob
        m = new Mesh();
        barBox(m, id, 1.08, 2.12, 0.05, -0.54, 1.06, 0.025, M_PLANK);
        for (int i = 1; i < 5; i++) barBox(m, id, 0.008, 2.12, 0.004, -1.08 + i * 0.216, 1.06, 0.052, M_BLACK);
        for (double[] b : new double[][] {{0.55, 5.7}, {1.35, -6.9}}) {
            m.box(1.25, 0.17, 0.035, Xf.move(-0.55, b[0], 0.0675).mul(Xf.rotZ(b[1])), barMat(M_DARK), barMat(M_DARK));
        }
        for (double y : new double[] {0.3, 1.8}) barBox(m, id, 0.3, 0.05, 0.006, -0.15, y, 0.053, M_IRON);
        barLathe(m, 10, new double[][] {{0, 0.012}, {0.04, 0.012}, {0.05, 0.026}, {0.066, 0.022}}, Xf.move(-0.96, 1.0, 0.05).mul(Xf.rotX(90)), barMat(M_BRASS), true, false);
        barLathe(m, 10, new double[][] {{0, 0.012}, {0.04, 0.012}, {0.05, 0.026}, {0.066, 0.022}}, Xf.move(-0.96, 1.0, 0.0).mul(Xf.rotX(-90)), barMat(M_BRASS), true, false);
        barFinish(m, "bar_door");

        // the boards torn off the door, lying on one another, their nails bent; the
        // hammer by them, nails spilled round (made round x 2.7, z -6.1)
        m = new Mesh();
        Random dr = new Random(433);
        for (double[] b : new double[][] {{-0.3, -0.35, 103, 0.015}, {-0.1, -0.1, 28.6, 0.045}, {0.05, 0.1, 20, 0.075}}) {
            Xf bo = Xf.move(b[0], b[3], b[1]).mul(Xf.rotY(b[2])).mul(Xf.rotZ((dr.nextDouble() - 0.5) * 2));
            barBox(m, bo, 1.3, 0.03, 0.17, 0, 0, 0, M_PLANK);
            for (double e : new double[] {-0.58, 0.58}) {
                barLimb(m, bo, new double[] {e, 0.015, 0.03}, new double[] {e + 0.012, 0.05, 0.036}, 0.003, 0.003, barMat(M_METAL));
            }
        }
        Xf ham = Xf.move(0.25, 0, 0.2).mul(Xf.rotY(46));
        barBox(m, ham, 0.32, 0.022, 0.024, 0, 0.023, 0, M_CUT);
        barBox(m, ham, 0.06, 0.035, 0.08, 0.17, 0.0225, 0, M_IRON);
        for (int i = 0; i < 9; i++) {
            barBox(m, Xf.move(0.1 + (dr.nextDouble() - 0.5) * 0.6, 0.004, 0.1 + (dr.nextDouble() - 0.5) * 0.6).mul(Xf.rotY(dr.nextDouble() * 180)),
                0.07, 0.006, 0.006, 0, 0, 0, M_METAL);
        }
        barFinish(m, "bar_door_things");

        // ---- the windows' bits (made round x 0 at the back wall's foot): the nails of the
        // boards across the boarded one; what is left of the smashed one's sash, the snow
        // on both sills, the glass on the floor under it
        m = new Mesh();
        // (one or two nails an end, as they went in)
        Random nr = new Random(467);
        for (double[] r : BAR_BOARDS) {
            for (int end = -1; end <= 1; end += 2) {
                for (double row : nr.nextDouble() < 0.5 ? new double[] {-1, 0.8} : new double[] {nr.nextDouble() - 0.5}) {
                    double[] nail = boardNail(r, end, row);
                    barLathe(m, 8, new double[][] {{0, 0.008}, {0.006, 0.008}}, Xf.move(nail[0], nail[1], 0.085 + r[5] * 0.036).mul(Xf.rotX(90)),
                        barMat(M_METAL), true, false);
                }
            }
        }
        // (the smashed one's sash askew, as it hangs on what is left - the author, 2026-11-01)
        barBox(m, Xf.move(1.5, 1.2, 0.005).mul(Xf.rotZ(-6)), 0.1, 0.7, 0.05, 0, 0, 0, M_DARK);
        barBox(m, Xf.move(0.925, 1.7, 0.005).mul(Xf.rotZ(4.5)), 0.65, 0.08, 0.05, 0, 0, 0, M_DARK);
        barLathe(m, 14, new double[][] {{0, 1}, {0.6, 0.75}, {1, 0.3}}, Xf.move(1.5, 0.85, 0.06).mul(Xf.scale(1.0, 0.07, 0.085)), barMat(M_SNOW), true, false);
        barLathe(m, 14, new double[][] {{0, 1}, {0.6, 0.75}, {1, 0.3}}, Xf.move(-1.45, 0.85, 0.06).mul(Xf.scale(0.85, 0.045, 0.07)), barMat(M_SNOW), true, false);
        Random gs = new Random(463);
        double[] su = barMat(M_GLASS);
        for (int i = 0; i < 26; i++) {
            double x = 1.5 + (gs.nextDouble() - 0.5) * 1.8, z = 1.0 + (gs.nextDouble() - 0.5) * 1.08, a = gs.nextDouble() * 6.28;
            double s = 0.02 + gs.nextDouble() * 0.05;
            m.tri(new double[] {x, 0.008, z}, new double[] {x + s * Math.cos(a + 2.4), 0.008, z + s * Math.sin(a + 2.4)},
                new double[] {x + s * Math.cos(a), 0.008, z + s * Math.sin(a)},
                new double[] {su[0], su[1]}, new double[] {su[2], su[1]}, new double[] {su[2], su[3]});
        }
        barFinish(m, "bar_window_bits");

        // the bottom of the table shoved over in the smashed window, in the table's own place
        // (the author, 2026-11-01: the snow showed through it in the game, and through a board
        // at the height of its own bottom; a board higher up did show): a block filling it from
        // there to just over its rails, its sides just inside them. Sizes as the table's own,
        // in its units: barFinish scales from metres, so 1.22 here
        m = new Mesh();
        barBox(m, Xf.move(0, 0, 0), 0.856 * 1.22, 0.095 * 1.22, 0.392 * 1.22, 0, 0.5525 * 1.22, 0, M_BROWN);
        barFinish(m, "bar_table_under");

        // what of the smashed window shows the snow: the icicles off its head (not lit by
        // the room: knoxBarGlow; the glass left in its frame read as odd triangles and went -
        // the author, 2026-11-01)
        m = new Mesh();
        Random ic = new Random(465);
        for (int i = 0; i < 14; i++) {
            double l = 0.04 + ic.nextDouble() * 0.14;
            barLathe(m, 6, new double[][] {{-l, 0.001}, {0, 0.012}}, Xf.move(0.65 + ic.nextDouble() * 1.7, 2.5, 0.03), barMat(M_ICE), true, false);
        }
        barFinish(m, "bar_window_glass");

        // ---- the floor: what weeks of waiting leave (the mockup's), in the room's own place:
        // cans, bottles, newspapers, cardboard, butts by the counter, pill bottles, rags
        m = new Mesh();
        Random tr = new Random(497);
        double[][] cans = {{0.0, -2.5}, {1.3, -2.7}, {1.0, -3.8}, {-0.4, -3.4}, {1.6, -3.2}, {-0.7, -2.2}, {0.4, -1.6}, {2.6, -2.6},
            {-2.4, -3.6}, {-3.6, -5.6}, {-0.4, -6.35}, {1.7, -6.3}, {3.3, -3.4}, {-1.1, -1.3}, {0.9, -1.0}, {-3.0, -2.6}, {2.9, -1.7},
            {-2.0, -6.4}, {-4.3, -4.6}, {1.0, -5.2}, {3.9, -4.9}, {-4.2, -3.1}};
        for (double[] c : cans) {
            // (no cans in the room any more, the author, 2026-11-02; their draws kept: the rubbish after them stays where it lay)
            for (int d = 0; d < 5; d++) tr.nextDouble();
        }
        // (the one by the smoker's chair off his bag - QA, 2026-11-01)
        for (double[] b : new double[][] {{-0.9, -2.9}, {2.2, -2.0}, {-2.95, -4.2}, {3.6, -2.8}, {0.9, -6.4}, {-3.9, -2.2}}) {
            int glass = tr.nextDouble() < 0.5 ? M_GREEN : M_BROWN;
            Xf bt = Xf.move(b[0], 0, b[1]).mul(Xf.rotY(tr.nextDouble() * 360));
            if (tr.nextDouble() < 0.75) barBottleDown(m, bt, glass, P_LABEL_BEER); else barEmpty(m, bt, glass, P_LABEL_BEER);
        }
        for (double[] p : new double[][] {{-0.4, -4.4, 0.4, 1}, {1.7, -2.3, 1.2, 0.9}, {-2.9, -3.3, 2.2, 1.1}, {0.7, -5.75, 0.9, 1},
            {3.2, -5.2, 2.6, 0.8}, {-1.6, -2.4, 1.7, 1}, {2.6, -6.8, 0.2, 0.9}, {-3.7, -6.6, 1.1, 1}}) {
            barPaper(m, p[0], p[1], Math.toDegrees(p[2]), p[3]);
        }
        double[] kraft = barMat(M_CARDBOARD), print = barPic(P_CARDBOARD);
        for (double[] c : new double[][] {{2.9, -2.5, 1.2, 1}, {-3.4, -1.6, 0.3, 1}, {4.9, -4.8, 0.9, 0}}) {
            Xf cb = Xf.move(c[0], 0, c[1]).mul(Xf.rotY(Math.toDegrees(c[2])));
            if (c[3] > 0) {
                m.box(0.7, 0.012, 0.5, cb.mul(Xf.move(0, 0.006, 0)), kraft, print);
            } else {
                m.box(0.4, 0.3, 0.3, cb.mul(Xf.move(0, 0.15, 0)), print, kraft);
                m.box(0.4, 0.008, 0.15, cb.mul(Xf.move(0, 0.3, -0.15)).mul(Xf.rotX(-40)).mul(Xf.move(0, 0, -0.075)), kraft, kraft);
                m.box(0.4, 0.008, 0.15, cb.mul(Xf.move(0, 0.3, 0.15)).mul(Xf.rotX(52)).mul(Xf.move(0, 0, 0.075)), kraft, kraft);
            }
        }
        barButts(m, 0.2, -0.4, 10, 0.5, tr);
        for (double[] p : new double[][] {{-2.25, -6.4}, {-0.9, -6.8}}) {
            Xf pb = Xf.move(p[0], 0.016, p[1]).mul(Xf.rotY(tr.nextDouble() * 360)).mul(Xf.rotZ(90)).mul(Xf.move(0, -0.045, 0));
            barLathe(m, 8, new double[][] {{0, 0.016}, {0.07, 0.016}, {0.074, 0.009}}, pb, barMat(M_AMBER), false, true);
            barLathe(m, 8, new double[][] {{0.072, 0.012}, {0.09, 0.012}}, pb, barMat(M_PAPER), true, false);
        }
        double[] rag = barMat(M_TOWEL);
        for (int i = 0; i < 3; i++) {
            Xf rg = Xf.move(-0.6 + i * 0.3, 0, -6.75 + i * 0.1).mul(Xf.rotY(tr.nextDouble() * 360));
            for (int k = 0; k < 8; k++) {
                double xa = -0.25 + k * 0.0625, xb = xa + 0.0625;
                double ya = 0.006 + 0.01 * Math.abs(Math.sin(xa * 14)), yb = 0.006 + 0.01 * Math.abs(Math.sin(xb * 14));
                m.quad(rg.point(xa, ya, 0.035), rg.point(xb, yb, 0.035), rg.point(xb, yb, -0.035), rg.point(xa, ya, -0.035), rag);
            }
        }
        barFinish(m, "bar_trash");

        // ---- on the walls, dead: a lamp hung from where it is placed (it will sway about that point)
        m = new Mesh();
        barLimb(m, id, new double[] {0, 0, 0}, new double[] {0, -0.95, 0}, 0.006, 0.006, barMat(M_BLACK));
        barLathe(m, 18, new double[][] {{-1.13, 0.24}, {-1.0, 0.1}, {-0.95, 0.03}}, id, barMat(M_SHADE), true, true);
        barFinish(m, "bar_lamp");

        // ---- the jukebox
        barJukebox("bar_jukebox");
        barCigMachine("bar_cig_machine");
        barWallThings("bar_wall_things");

        // ---- the wall of the missing (on the back wall, right of the door): its heading. Its sheets
        // hang each on a pin of its own, in the wind (bar_sheet_missing; KnoxMenuSceneBar's SHEETS,
        // laid as Random 441 laid them here before - the author, 2026-11-02)
        m = new Mesh();
        barSheet(m, id, 0.76, 0.19, 0, 0.5, 0, 0, barPic(P_MISSING));
        barFinish(m, "bar_missing");

        // ---- loose sheets the draft lifts (stage 5, the author 2026-10-31): a newspaper's, one
        // of the missing come off the board
        m = new Mesh();
        barLooseSheet(m, 0.42, 0.56, barPic(P_NEWS));
        barFinish(m, "bar_sheet_news");
        m = new Mesh();
        barLooseSheet(m, 0.25, 0.19, barPic(P_SHEET));
        barFinish(m, "bar_sheet_missing");

        // ---- on the back wall: the antlers over the jukebox, the clock
        m = new Mesh();
        barBox(m, id, 0.3, 0.26, 0.03, 0, 0, 0.015, M_DARK);
        barLathe(m, 10, new double[][] {{-0.12, 0.03}, {0.0, 0.07}, {0.11, 0.05}}, Xf.move(0, 0, 0.09).mul(Xf.rotX(10)), barMat(M_ANTLER), true, true);
        for (int s = -1; s <= 1; s += 2) {
            double[][] beam = {{s * 0.04, 0.09, 0.09}, {s * 0.24, 0.2, 0.15}, {s * 0.42, 0.38, 0.15}, {s * 0.48, 0.62, 0.1}};
            for (int i = 0; i + 1 < beam.length; i++) barLimb(m, id, beam[i], beam[i + 1], 0.024 - i * 0.005, 0.018 - i * 0.005, barMat(M_ANTLER));
            double[][][] tines = {{{s * 0.24, 0.2, 0.15}, {s * 0.2, 0.42, 0.18}}, {{s * 0.42, 0.38, 0.15}, {s * 0.32, 0.56, 0.17}}, {{s * 0.34, 0.3, 0.15}, {s * 0.5, 0.36, 0.2}}};
            for (double[][] t : tines) barLimb(m, id, t[0], t[1], 0.014, 0.005, barMat(M_ANTLER));
        }
        barFinish(m, "bar_antlers");

        m = new Mesh();
        barLathe(m, 18, new double[][] {{0, 0.15}, {0.03, 0.15}}, Xf.rotX(90), barMat(M_DARK), false, false);
        barSheet(m, id, 0.27, 0.27, 0, 0, 0.031, 0, barPic(P_CLOCK));
        barFinish(m, "bar_clock");

        barDrift("bar_drift");

        // ---- the garland along the back wall, torn at its right end and hanging:
        // lit colored bulbs on a dark wire. (Local to its place: world x, y and
        // z - 8 + 0.08.)
        m = new Mesh();
        double[] hooks = {-5.8, -3.8, -1.8, 0.2, 2.2};
        List<double[]> pts = new ArrayList<>();
        for (int k = 0; k + 1 < hooks.length; k++) {
            for (int i = 0; i < 12; i++) {
                double t = i / 12.0;
                pts.add(new double[] {hooks[k] + (hooks[k + 1] - hooks[k]) * t, 2.95 - 0.28 * Math.sin(t * Math.PI), 0});
            }
        }
        for (int i = 0; i <= 10; i++) pts.add(new double[] {2.2 + i * 0.02, 2.95 - i * 0.11, 0.02});
        int[] bulbs = {M_BRED, M_BGREEN, M_BYELLOW, M_BBLUE};
        for (int i = 0; i + 1 < pts.size(); i++) barLimb(m, id, pts.get(i), pts.get(i + 1), 0.006, 0.006, barMat(M_BLACK));
        // (the live ones apart: they light up, KnoxBarFrame's GARLAND - the author, 2026-11-02)
        Mesh lit = new Mesh();
        for (int i = 0; i < pts.size(); i += 2) {
            double[] p = pts.get(i);
            int n = i / 2;
            int col = n % 5 == 3 ? M_ASH : bulbs[n % 4];   // every fifth is dead
            barLathe(col == M_ASH ? m : lit, 6, new double[][] {{-0.06, 0.004}, {-0.045, 0.028}, {-0.015, 0.024}, {0, 0.008}}, Xf.move(p[0], p[1], p[2]), barMat(col), true, true);
        }
        barFinish(m, "bar_garland");
        barFinish(lit, "bar_garland_bulbs");
        // its switch, hanging on a lead from the torn end (x 2.4, y 1.85, z -7.9 in the room; the lead's top
        // at 0: KnoxBarFrame swings it): an old bakelite cord switch, a brass toggle (the author, 2026-11-02:
        // the pale box with a red rocker looked like a toy), the lead going on out of its foot
        m = new Mesh();
        barLimb(m, id, new double[] {0, 0, 0}, new double[] {0, -0.27, 0}, 0.005, 0.005, barMat(M_BLACK));
        Xf sw = Xf.move(0, -0.38, 0);
        barLathe(m, 12, new double[][] {{0, 0.012}, {0.01, 0.028}, {0.085, 0.03}, {0.098, 0.022}, {0.11, 0.008}}, sw, barMat(M_BAKELITE), true, true);
        barLathe(m, 12, new double[][] {{0.044, 0.0312}, {0.052, 0.0312}}, sw, barMat(M_IRON), false, false);
        jukeBox(m, id, 0.018, 0.022, 0.006, 0, -0.325, 0.029, barMat(M_IRON));
        barLimb(m, id, new double[] {0, -0.327, 0.03}, new double[] {0, -0.302, 0.058}, 0.0035, 0.005, barMat(M_BRASS));
        barLimb(m, id, new double[] {0, -0.38, 0}, new double[] {0.006, -0.47, 0}, 0.005, 0.004, barMat(M_BLACK));
        barFinish(m, "bar_garland_switch");
    }

    /** Where a point of the jukebox's front falls in its picture. */
    // what shows the snow: not lit by the room's lamps (knoxBar.frag). (2026-10-31, the last
    // ones leaving: nothing in the room shines any more - the jukebox and the garland are dead.)
    static final java.util.Set<String> BAR_OWN_LIGHT = java.util.Set.of("WindowGlass");

    static void barScripts() throws IOException {
        String[][] models = {
            {"WallBack", "bar_wall_back", "bar_wall_back"}, {"WallLeft", "bar_wall_left", "bar_wall_left"},
            {"WallRight", "bar_wall_right", "bar_wall_right"},
            {"Floor", "bar_floor", "bar_floor"}, {"Ceiling", "bar_ceiling", "bar_ceiling"},
            {"Trim", "bar_trim", "bar_dark"}, {"Boards", "bar_boards", "planks"},
            {"RearFloor", "bar_rear_floor", "bar_floor"}, {"RearCeiling", "bar_rear_ceiling", "bar_ceiling"},
            {"RearLeft", "bar_rear_left", "bar_wall_left"}, {"RearRight", "bar_rear_right", "bar_wall_right"},
            {"RearWall", "bar_rear_wall", "bar_wall_back"}, {"RearTrim", "bar_rear_trim", "bar_dark"},
            {"Counter", "bar_counter", "bar_dark"}, {"CounterTop", "bar_counter_top", "bar_varnish"},
            {"Stool", "bar_stool", "bar_atlas"},
            {"CounterPanels", "bar_counter_panels", "bar_atlas"},
            {"Journal", "bar_journal", "bar_atlas"},
            {"JournalPage", "bar_journal_page", "bar_atlas"},
            {"Pencil", "bar_pencil", "bar_atlas"},
            {"Radio", "bar_radio", "bar_atlas"},
            {"RadioNeedle", "bar_radio_needle", "bar_atlas"},
            {"CounterThings", "bar_counter_things", "bar_atlas"},
            {"Whiskey", "bar_whiskey", "bar_atlas"},
            {"SmokerThings", "bar_smoker_things", "bar_atlas"},
            {"MapThings", "bar_map_things", "bar_atlas"},
            {"Tally", "bar_tally", "bar_atlas"},
            {"TableLeg", "bar_table_leg", "bar_atlas"},
            {"Fire", "bar_fire", "bar_atlas"},
            {"Supplies", "bar_supplies", "bar_atlas"},
            {"SawSet", "bar_saw_set", "bar_atlas"},
            {"Door", "bar_door", "bar_atlas"},
            {"DoorThings", "bar_door_things", "bar_atlas"},
            {"WindowBits", "bar_window_bits", "bar_atlas"},
            {"TableUnder", "bar_table_under", "bar_atlas"},
            {"WindowGlass", "bar_window_glass", "bar_atlas"},
            {"Trash", "bar_trash", "bar_atlas"},
            {"Lamp", "bar_lamp", "bar_atlas"},
            {"Jukebox", "bar_jukebox", "bar_atlas"},
            {"CigMachine", "bar_cig_machine", "bar_atlas"},
            {"WallThings", "bar_wall_things", "bar_atlas"},
            {"Missing", "bar_missing", "bar_atlas"},
            {"SheetNews", "bar_sheet_news", "bar_atlas"},
            {"SheetMissing", "bar_sheet_missing", "bar_atlas"},
            {"Antlers", "bar_antlers", "bar_atlas"},
            {"Clock", "bar_clock", "bar_atlas"},
            {"Drift", "bar_drift", "bar_atlas"},
            {"Garland", "bar_garland", "bar_atlas"},
            {"GarlandBulbs", "bar_garland_bulbs", "bar_atlas"},
            {"GarlandSwitch", "bar_garland_switch", "bar_atlas"},
        };
        StringBuilder sb = new StringBuilder();
        sb.append("/* Generated by Knox Inventory Java/tools/menugen/MenuGen.java (\"bar\") - models of\n")
          .append("   the main menu's winter bar (KnoxMenuBar). Do not edit by hand. */\n\nmodule KnoxMenuBar\n{\n");
        for (String[] m : models) {
            sb.append("    model ").append(m[0]).append("\n    {\n        mesh = knoxmenu/").append(m[1])
              .append(",\n        texture = knoxmenu/").append(m[2]).append(BAR_OWN_LIGHT.contains(m[0]) ? ",\n        shader = knoxBarGlow" : ",\n        shader = knoxBar").append(",\n        scale = 1.0,\n    }\n\n");
        }
        sb.append("}\n");
        Files.writeString(media.resolve("knox/bar_models.txt"), sb.toString(), StandardCharsets.US_ASCII);
        System.out.println("knox/bar_models.txt");
    }
}
