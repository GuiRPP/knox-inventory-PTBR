import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.imageio.ImageIO;

import knox.java.KnoxBarFrame;

import org.lwjgl.BufferUtils;
import org.lwjgl.glfw.GLFW;
import org.lwjgl.opengl.GL;
import org.lwjgl.opengl.GL33;

/**
 * The winter bar's frame without the game (2026-10-31): a hidden window on the real video
 * card, the frame's own code (KnoxBarFrame), the props of KnoxMenuSceneBar.lua. Takes a
 * picture and the time of each pass. Doesn't start the game; the heroes aren't in it.
 *
 * args: out.png width height [time] [low] [frames]
 */
public final class Harness {
    private static final float U = KnoxBarFrame.U;

    public static void main(String[] args) throws Exception {
        String out = args[0];
        int w = Integer.parseInt(args[1]), h = Integer.parseInt(args[2]);
        float time = args.length > 3 ? Float.parseFloat(args[3]) : 12f;
        boolean low = args.length > 4 && "low".equals(args[4]);
        int frames = args.length > 5 ? Integer.parseInt(args[5]) : 40;
        File mod = new File(System.getProperty("knox.mod", "."));
        String workshop = "C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/";
        File[] roots = {new File(mod, "42"), new File(mod, "common"),
            new File("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"),
            new File(workshop + "3810302175/mods/PZVoxelStudioViewpoint/common"),
            new File(workshop + "3820833348/mods/DGVWindows3D/42")};

        if (!GLFW.glfwInit()) throw new IllegalStateException("glfw");
        GLFW.glfwWindowHint(GLFW.GLFW_VISIBLE, GLFW.GLFW_FALSE);
        long window = GLFW.glfwCreateWindow(64, 64, "knox bar", 0, 0);
        if (window == 0) throw new IllegalStateException("window");
        GLFW.glfwMakeContextCurrent(window);
        GLFW.glfwSwapInterval(0);
        GL.createCapabilities();
        System.out.println(GL33.glGetString(GL33.GL_RENDERER) + " | " + GL33.glGetString(GL33.GL_VERSION));

        KnoxBarFrame frame = new KnoxBarFrame(relative -> {
            for (File r : roots) {
                File f = new File(r, relative);
                if (f.isFile()) return f;
            }
            return null;
        });
        File lua = new File(mod, "42/media/lua/client/Knox/KnoxMenuSceneBar.lua");
        readProps(lua, frame);
        long t0 = System.nanoTime();
        frame.load();
        System.out.printf("load %.0f ms%n", (System.nanoTime() - t0) / 1e6);
        // -Dbar.heroes=0: the room alone; -Dbar.glow=0..1: the smoker's drag
        if (!"0".equals(System.getProperty("bar.heroes"))) {
            readSeats(lua, frame, Float.parseFloat(System.getProperty("bar.glow", "0.3")));
        }
        frame.quality(!low);
        // -Dbar.cam=fov,ex,ey,ez,tx,ty,tz in metres: another look at the room
        String cam = System.getProperty("bar.cam");
        if (cam != null) {
            String[] c = cam.split(",");
            frame.camera(new float[] {Float.parseFloat(c[0]), Float.parseFloat(c[1]) * U, Float.parseFloat(c[2]) * U, Float.parseFloat(c[3]) * U,
                Float.parseFloat(c[4]) * U, Float.parseFloat(c[5]) * U, Float.parseFloat(c[6]) * U});
        }
        frame.profile = true;

        int tex = GL33.glGenTextures();
        GL33.glBindTexture(GL33.GL_TEXTURE_2D, tex);
        GL33.glTexImage2D(GL33.GL_TEXTURE_2D, 0, GL33.GL_RGBA8, w, h, 0, GL33.GL_RGBA, GL33.GL_UNSIGNED_BYTE, (ByteBuffer) null);
        int fbo = GL33.glGenFramebuffers();
        GL33.glBindFramebuffer(GL33.GL_FRAMEBUFFER, fbo);
        GL33.glFramebufferTexture2D(GL33.GL_FRAMEBUFFER, GL33.GL_COLOR_ATTACHMENT0, GL33.GL_TEXTURE_2D, tex, 0);
        GL33.glViewport(0, 0, w, h);

        // -Dbar.garland=1: the garland on
        if ("1".equals(System.getProperty("bar.garland"))) frame.garland(true, true);
        // -Dbar.pencil=seconds: the pencil held on its way off the counter; -Dbar.switch=1: the mouse on the switch
        knox.java.KnoxBarFrame.pencilHeld = Float.parseFloat(System.getProperty("bar.pencil", "-1"));
        frame.switchLit("1".equals(System.getProperty("bar.switch")));
        // -Dbar.page=0..1: a journal's page held on its way
        knox.java.KnoxBarFrame.pageHeld = Float.parseFloat(System.getProperty("bar.page", "-1"));
        // -Dbar.bottle=seconds: the whiskey bottle held on its way off the counter
        knox.java.KnoxBarFrame.bottleHeld = Float.parseFloat(System.getProperty("bar.bottle", "-1"));
        // -Dbar.focus=u,v,power,band[,depth]: the depth of field, focused at (u, v) of the picture (2026-11-03)
        String focus = System.getProperty("bar.focus");
        if (focus != null) {
            String[] f = focus.split(",");
            frame.focus(Float.parseFloat(f[0]), Float.parseFloat(f[1]), Float.parseFloat(f[2]), Float.parseFloat(f[3]),
                f.length > 4 ? Float.parseFloat(f[4]) : 0f);
        }
        double sum = 0;
        String report = "";
        for (int i = 0; i < frames; i++) {
            long a = System.nanoTime();
            String drag = System.getProperty("bar.drag");
            if (drag != null && emberAt != null) {
                float t = (time + i / 60f) / Float.parseFloat(drag);
                float g = Math.max(0f, 1f - Math.abs(t - (float) Math.floor(t) - 0.5f) * 8f);
                frame.ember(emberAt[0], emberAt[1], emberAt[2], g, 1f);
            }
            frame.begin();
            frame.end(time + i / 60f * (frames > 50 ? 1 : 0));
            GL33.glFinish();
            double ms = (System.nanoTime() - a) / 1e6;
            if (i > 4) sum += ms;
            if (i == frames - 1) report = frame.profileReport();
            if (frame.failure() != null) throw new IllegalStateException(frame.failure());
        }
        int err = GL33.glGetError();
        System.out.printf("door bangs %d%n", frame.doorBangs());
        System.out.printf("%dx%d %s: %.2f ms a frame (%.0f fps), gl error %d%n", w, h, low ? "low" : "high", sum / (frames - 5), 1000 / (sum / (frames - 5)), err);
        System.out.println(report);

        // -Dbar.swipe=k,dir: the menu's swipe (KnoxMenuSwipe): the room going, a plain colour coming
        String swipe = System.getProperty("bar.swipe");
        if (swipe != null) {
            String[] s = swipe.split(",");
            knox.java.KnoxMenuSwipe.take(false);
            GL33.glClearColor(0.5f, 0.1f, 0.1f, 1f);
            GL33.glClear(GL33.GL_COLOR_BUFFER_BIT);
            knox.java.KnoxMenuSwipe.draw(Float.parseFloat(s[0]), Integer.parseInt(s[1]), true, s.length > 2 ? Float.parseFloat(s[2]) : 0f);
            System.out.println("swipe failed: " + knox.java.KnoxMenuSwipe.failed() + ", gl error " + GL33.glGetError());
        }
        GL33.glBindFramebuffer(GL33.GL_READ_FRAMEBUFFER, fbo);
        ByteBuffer pixels = BufferUtils.createByteBuffer(w * h * 4);
        GL33.glPixelStorei(GL33.GL_PACK_ALIGNMENT, 1);
        GL33.glReadPixels(0, 0, w, h, GL33.GL_RGBA, GL33.GL_UNSIGNED_BYTE, pixels);
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int at = (x + (h - 1 - y) * w) * 4;
                img.setRGB(x, y, (pixels.get(at) & 255) << 16 | (pixels.get(at + 1) & 255) << 8 | (pixels.get(at + 2) & 255));
            }
        }
        ImageIO.write(img, "png", new File(out));
        frame.release();
        GLFW.glfwTerminate();
        System.exit(0);
    }

    private static final Pattern PROP = Pattern.compile("\\{id = \"(kb_\\w+)\", model = \"([\\w.]+)\"([^\\n]*)\\},?\\r?\\n");

    private static void readProps(File lua, KnoxBarFrame frame) throws Exception {
        String text = new String(Files.readAllBytes(lua.toPath()), StandardCharsets.UTF_8);
        Matcher fire = Pattern.compile("local FIRE_X, FIRE_Z = (-?[\\d.]+), (-?[\\d.]+)").matcher(text);
        fire.find();
        float fireX = Float.parseFloat(fire.group(1)), fireZ = Float.parseFloat(fire.group(2));
        String block = text.substring(text.indexOf("local PROPS = {"));
        block = block.substring(0, block.indexOf("\n}")) + "\n";
        Matcher m = PROP.matcher(block);
        int count = 0;
        // -Dbar.skip=kb_ceiling,...: props left out (a look from above)
        String skip = "," + System.getProperty("bar.skip", "") + ",";
        while (m.find()) {
            if (skip.contains("," + m.group(1) + ",")) continue;
            String r = m.group(3);
            float[] tint = {1, 1, 1};
            Matcher t = Pattern.compile("tint = \\{([^}]*)\\}").matcher(r);
            if (t.find()) {
                String[] p = t.group(1).split(",");
                for (int i = 0; i < 3; i++) tint[i] = Float.parseFloat(p[i].trim());
            }
            float s = num(r, "s", 1, fireX, fireZ);
            frame.prop(m.group(2), num(r, "x", 0, fireX, fireZ) * U, num(r, "y", 0, fireX, fireZ) + num(r, "ym", 0, fireX, fireZ) * U, num(r, "z", 0, fireX, fireZ) * U,
                num(r, "rx", 0, fireX, fireZ), num(r, "yaw", 0, fireX, fireZ), num(r, "rz", 0, fireX, fireZ),
                num(r, "sx", 1, fireX, fireZ) * s, num(r, "sy", 1, fireX, fireZ) * s, num(r, "sz", 1, fireX, fireZ) * s,
                tint[0], tint[1], tint[2], (int) num(r, "moves", 0, fireX, fireZ));
            count++;
        }
        System.out.println(count + " props");
    }

    // (stage 4, 2026-10-31) the heroes as grey stand-ins of their poses (poses.py), at the
    // places SEATS gives them; the ember at the smoker's left hand
    private static final Pattern SEAT = Pattern.compile(
        "\\{x = (-?[\\d.]+), z = (-?[\\d.]+), y = (-?[\\d.]+), face = (-?[\\d.]+), anim = \"(\\w+)\"");

    // -Dbar.drag=seconds: the smoker draws on it every so often (the smoke breathed out after it)
    private static float[] emberAt;

    private static void readSeats(File lua, KnoxBarFrame frame, float glow) throws Exception {
        String text = new String(Files.readAllBytes(lua.toPath()), StandardCharsets.UTF_8);
        String block = text.substring(text.indexOf("local SEATS = {"));
        block = block.substring(0, block.indexOf("\n}"));
        Matcher m = SEAT.matcher(block);
        float[] caps = new float[KnoxBarFrame.HEROES * KnoxBarFrame.CAPSULES * KnoxBarFrame.CAPSULE];
        int[] count = new int[KnoxBarFrame.HEROES];
        float[] mouths = new float[KnoxBarFrame.HEROES * 6];
        int h = 0;
        while (m.find() && h < KnoxBarFrame.HEROES) {
            float x = Float.parseFloat(m.group(1)) * U, z = Float.parseFloat(m.group(2)) * U, y = Float.parseFloat(m.group(3));
            double face = Math.toRadians(Float.parseFloat(m.group(4)));
            String anim = m.group(5);
            String pose = anim.contains("stool") ? "stool" : anim.contains("smoke") ? "smoke" : "stand";
            float[] p = frame.pose(pose);
            if (p == null) throw new IllegalStateException("no pose " + pose);
            float s = (float) Math.sin(face), c = (float) Math.cos(face);
            int n = Math.min(p.length / KnoxBarFrame.CAPSULE, KnoxBarFrame.CAPSULES);
            int at = h * KnoxBarFrame.CAPSULES * KnoxBarFrame.CAPSULE;
            for (int i = 0; i < n; i++) {
                int o = i * KnoxBarFrame.CAPSULE;
                for (int e = 0; e < 2; e++) {
                    float px = p[o + e * 3], py = p[o + e * 3 + 1], pz = p[o + e * 3 + 2];
                    caps[at + o + e * 3] = x + px * c + pz * s;
                    caps[at + o + e * 3 + 1] = y + py;
                    caps[at + o + e * 3 + 2] = z - px * s + pz * c;
                }
                caps[at + o + 6] = p[o + 6];
            }
            count[h] = n;
            // (stage 5) the head capsule's foot and a little ahead: the mouth, breathing the way it faces
            int head = at + 10 * KnoxBarFrame.CAPSULE;
            mouths[h * 6] = caps[head] + s * 0.08f;
            mouths[h * 6 + 1] = caps[head + 1];
            mouths[h * 6 + 2] = caps[head + 2] + c * 0.08f;
            mouths[h * 6 + 3] = s;
            mouths[h * 6 + 5] = c;
            if (pose.equals("smoke")) {
                // (the left forearm's capsule ends at the hand: Bip01_L_Hand)
                int o = at + 3 * KnoxBarFrame.CAPSULE;
                frame.ember(caps[o + 3], caps[o + 4], caps[o + 5], glow, 1f);
                emberAt = new float[] {caps[o + 3], caps[o + 4], caps[o + 5]};
            }
            System.out.printf("seat %d: %s, %d capsules%n", h + 1, pose, n);
            h++;
        }
        frame.heroes(caps, count);
        frame.mouths(mouths);
        frame.showStandIns(true);
    }

    private static float num(String rest, String key, float otherwise, float fireX, float fireZ) {
        Matcher m = Pattern.compile("\\b" + key + " = (-?[\\d.]+|FIRE_[XZ])").matcher(rest);
        if (!m.find()) return otherwise;
        String v = m.group(1);
        if ("FIRE_X".equals(v)) return fireX;
        if ("FIRE_Z".equals(v)) return fireZ;
        return Float.parseFloat(v);
    }
}
