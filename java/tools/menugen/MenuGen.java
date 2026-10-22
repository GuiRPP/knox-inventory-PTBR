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
}
