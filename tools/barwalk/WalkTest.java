import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import knox.java.KnoxBarMesh;
import knox.java.KnoxBarWalk;

import org.joml.Matrix4f;
import org.joml.Vector3f;

/**
 * The walk about the bar, outside the game (the author, 2026-11-04): KnoxBarWalk as it is. Nothing
 * passes through anything, sliding along walls, the same motion at any frame rate, a smooth head,
 * the way in and out; and the shapes against the real models at the height of a body.
 * Run by tools\barwalk\test.ps1, a part of tools\checkall.
 */
public class WalkTest {
    static final float MENU_X = -3.4f, MENU_Y = 1.95f, MENU_Z = 3.9f, TO_X = -1f, TO_Y = 1.25f, TO_Z = -5f, FOV = 32f;
    static int failed;

    static void check(boolean ok, String what) {
        System.out.println((ok ? "ok    " : "FAIL  ") + what);
        if (!ok) failed++;
    }

    static KnoxBarWalk fresh() {
        KnoxBarWalk w = new KnoxBarWalk();
        w.begin(MENU_X, MENU_Y, MENU_Z, TO_X, TO_Y, TO_Z);
        return w;
    }

    static void run(KnoxBarWalk w, double seconds, double fps, float ahead, float side, boolean fast) {
        int frames = (int) Math.round(seconds * fps);
        for (int i = 0; i < frames; i++) {
            w.keys(ahead, side, fast);
            w.frame(1.0 / fps, MENU_X, MENU_Y, MENU_Z, TO_X, TO_Y, TO_Z, FOV);
        }
    }

    /** How far the body's edge is inside whatever it is in; 0: clear. */
    static float depth(float x, float z) {
        float[] p = {x, z, 0f, 0f};
        KnoxBarWalk.collide(p);
        return (float) Math.hypot(p[0] - x, p[1] - z);
    }

    static void noPassing() {
        Random r = new Random(4211);
        float worst = 0f;
        for (int run = 0; run < 400; run++) {
            KnoxBarWalk w = fresh();
            w.mouse(r.nextFloat() * 4000f - 2000f, 0f);
            for (int leg = 0; leg < 20; leg++) {
                float a = r.nextInt(3) - 1, s = r.nextInt(3) - 1;
                boolean fast = r.nextBoolean();
                w.mouse(r.nextFloat() * 400f - 200f, 0f);
                for (int i = 0; i < 24; i++) {
                    run(w, 1.0 / 60.0, 60.0, a, s, fast);
                    worst = Math.max(worst, depth(w.x, w.z));
                }
            }
        }
        check(worst < 0.005f, String.format(Locale.ROOT, "400 random walks: never in anything (deepest %.4f m)", worst));
    }

    static void sliding() {
        // along the counter's long side, at 45 degrees into it: the way along stays
        KnoxBarWalk w = new KnoxBarWalk();
        w.begin(0f, 1.65f, -1.0f, 1f, 1.65f, 0f);
        run(w, 0.3, 60, 1f, 0f, false);
        run(w, 1.6, 60, 1f, 0f, false);
        float x0 = w.x;
        run(w, 1f, 60, 1f, 0f, false);
        float along = w.x - x0;
        check(along > 0.75f, String.format(Locale.ROOT, "into the counter at 45 degrees, it slides: %.2f m along in a second", along));
        check(w.z < 0.48f - KnoxBarWalk.RADIUS + 0.01f, String.format(Locale.ROOT, "and stays before it: z %.3f", w.z));
    }

    static void anyFrameRate() {
        double[] rates = {30, 60, 144, 240, 37.3};
        float[][] end = new float[rates.length][];
        for (int i = 0; i < rates.length; i++) {
            KnoxBarWalk w = fresh();
            double t = 0;
            double dt = 1.0 / rates[i];
            float yaw = 0f;
            while (t < 8.0) {
                float a = t < 3 ? 1f : t < 5 ? -1f : 0f, s = t > 2 && t < 6 ? 1f : 0f;
                // (the same mouse at every rate: as a speed)
                w.mouse((float) (120.0 * dt), 0f);
                yaw += 120.0 * dt;
                w.keys(a, s, t > 4);
                w.frame(dt, MENU_X, MENU_Y, MENU_Z, TO_X, TO_Y, TO_Z, FOV);
                t += dt;
            }
            end[i] = new float[] {w.x, w.z, w.view[1]};
        }
        float worst = 0f;
        for (int i = 1; i < rates.length; i++) worst = Math.max(worst, (float) Math.hypot(end[i][0] - end[0][0], end[i][1] - end[0][1]));
        check(worst < 0.03f, String.format(Locale.ROOT, "30, 37, 60, 144, 240 frames: the same place within %.3f m", worst));
    }

    static void head() {
        KnoxBarWalk w = fresh();
        run(w, 1.4, 240, 0f, 0f, false);
        w.begin(0f, 1.65f, -2f, 0f, 1.65f, -8f);
        run(w, 1.3, 240, 1f, 0f, false);
        float lo = 99f, hi = -99f, jump = 0f, was = Float.NaN;
        for (int i = 0; i < 240 * 2; i++) {
            run(w, 1.0 / 240.0, 240, 1f, 0f, false);
            float y = w.view[1] / KnoxBarWalk.U;
            lo = Math.min(lo, y);
            hi = Math.max(hi, y);
            if (was == was) jump = Math.max(jump, Math.abs(y - was));
            was = y;
        }
        check(hi - lo > 0.018f && hi - lo < 0.05f, String.format(Locale.ROOT, "the head goes %.1f cm up and down on a walk", (hi - lo) * 100));
        check(jump < 0.002f, String.format(Locale.ROOT, "no jump in it: %.2f mm at most a frame at 240", jump * 1000));

        // against a wall the keys ask, the legs don't go: the head doesn't shake
        w.begin(0f, 1.65f, -0.1f, 0f, 1.65f, 5f);
        run(w, 2.5, 240, 1f, 0f, false);
        lo = 99f;
        hi = -99f;
        for (int i = 0; i < 240; i++) {
            run(w, 1.0 / 240.0, 240, 1f, 0f, false);
            float y = w.view[1] / KnoxBarWalk.U;
            lo = Math.min(lo, y);
            hi = Math.max(hi, y);
        }
        check(hi - lo < 0.012f, String.format(Locale.ROOT, "walking into the counter: only the breath, %.1f mm", (hi - lo) * 1000));

        // to a stop: no drift back
        w.begin(0f, 1.65f, -2f, 0f, 1.65f, -8f);
        run(w, 1.5, 240, 1f, 0f, false);
        float z0 = w.z;
        float least = z0;
        boolean back = false;
        for (int i = 0; i < 240; i++) {
            run(w, 1.0 / 240.0, 240, 0f, 0f, false);
            if (w.z > least + 0.0005f) back = true;
            least = Math.min(least, w.z);
        }
        check(!back && z0 - least < 0.25f, String.format(Locale.ROOT, "stops in %.2f m, no step back", z0 - least));

        KnoxBarWalk still = fresh();
        still.still = true;
        run(still, 2, 60, 1f, 0f, false);
        float a = still.view[1];
        run(still, 0.2, 60, 1f, 0f, false);
        check(Math.abs(still.view[1] - a) < 1e-4f, "animations off: the head is level");
    }

    static void look() {
        KnoxBarWalk w = new KnoxBarWalk();
        w.begin(0f, 1.65f, -2f, 0f, 1.65f, -8f);
        float y0 = w.yawNow();
        w.mouse(1000f, 0f);
        float want = w.tune[KnoxBarWalk.SENS] * 1000f;
        run(w, 0.05, 240, 0f, 0f, false);
        float at50 = (y0 - w.yawNow()) / want;
        run(w, 0.15, 240, 0f, 0f, false);
        float at200 = (y0 - w.yawNow()) / want;
        check(at50 > 0.45f && at50 < 0.85f, String.format(Locale.ROOT, "the look: %.0f%% of a turn after 50 ms", at50 * 100));
        check(at200 > 0.97f && at200 < 1.002f, String.format(Locale.ROOT, "%.0f%% after 200 ms, no overshoot", at200 * 100));
        for (int i = 0; i < 100; i++) w.mouse(0f, -5000f);
        run(w, 1, 60, 0f, 0f, false);
        check(Math.toDegrees(w.pitchNow()) <= 85.01, String.format(Locale.ROOT, "the neck stops at %.1f degrees up", Math.toDegrees(w.pitchNow())));
    }

    static float[] cam(KnoxBarWalk w) {
        return new float[] {w.view[0] / KnoxBarWalk.U, w.view[1] / KnoxBarWalk.U, w.view[2] / KnoxBarWalk.U, w.view[9]};
    }

    static void inAndOut() {
        KnoxBarWalk w = fresh();
        run(w, 1.0 / 60.0, 60, 0f, 0f, false);
        float[] c = cam(w);
        check(Math.hypot(c[0] - MENU_X, c[2] - MENU_Z) < 0.01 && Math.abs(c[3] - FOV) < 0.1f, "the first frame is the menu's view");
        float worst = 0f;
        float[] was = c;
        for (int i = 0; i < 90; i++) {
            run(w, 1.0 / 60.0, 60, 0f, 0f, false);
            c = cam(w);
            worst = Math.max(worst, (float) Math.hypot(Math.hypot(c[0] - was[0], c[2] - was[2]), c[1] - was[1]));
            was = c;
        }
        check(worst < 0.03f, String.format(Locale.ROOT, "the way in is smooth: %.1f mm a frame at 60 at most", worst * 1000));
        check(Math.abs(c[3] - 60f) < 0.1f, "and ends at the walk's angle");

        // close to the menu's place: glides back
        w.leave();
        int frames = 0;
        boolean dark = false;
        while (!w.over() && frames < 400) {
            run(w, 1.0 / 60.0, 60, 1f, 0f, false);
            dark |= w.dark() > 0f;
            frames++;
        }
        c = cam(w);
        check(w.over() && !dark && Math.hypot(c[0] - MENU_X, c[2] - MENU_Z) < 0.01 && Math.abs(c[3] - FOV) < 0.1f,
            String.format(Locale.ROOT, "close by, back by a glide in %.1f s", frames / 60f));

        // far: through the dark, the view changed while nothing is seen
        w = fresh();
        run(w, 1.5, 60, 0f, 0f, false);
        w.x = 0f;
        w.z = -3f;
        run(w, 0.1, 60, 0f, 0f, false);
        w.leave();
        float most = 0f;
        frames = 0;
        float jumpLit = 0f;
        was = cam(w);
        while (!w.over() && frames < 400) {
            run(w, 1.0 / 60.0, 60, 0f, 0f, false);
            most = Math.max(most, w.dark());
            c = cam(w);
            if (w.dark() < 0.98f) jumpLit = Math.max(jumpLit, (float) Math.hypot(c[0] - was[0], c[2] - was[2]));
            was = c;
            frames++;
        }
        check(w.over() && most >= 1f && jumpLit < 0.02f, String.format(Locale.ROOT, "far away, back through the dark in %.2f s, no jump seen", frames / 60f));
    }

    // The room's models at the height of a body --------------------------------------------------

    static final float G = 0.02f, GX0 = -7f, GZ0 = -10f, LO = 0.2f, HI = 1.85f;
    static final int NX = (int) (14 / G), NZ = (int) (16 / G);

    static float num(String r, String k, float d, float fx, float fz) {
        Matcher m = Pattern.compile("\\b" + k + " = (-?[\\d.]+|FIRE_[XZ])").matcher(r);
        if (!m.find()) return d;
        String v = m.group(1);
        return v.equals("FIRE_X") ? fx : v.equals("FIRE_Z") ? fz : Float.parseFloat(v);
    }

    static File find(File[] roots, String rel) {
        for (File x : roots) {
            File f = new File(x, rel);
            if (f.isFile()) return f;
        }
        return null;
    }

    /** What stands where: which prop is in each cell (index into names, -1 none). */
    static int[] slice(File mod, List<String> names) throws Exception {
        String w = "C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/";
        File[] roots = {new File(mod, "42"), new File(mod, "common"), new File("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"),
            new File(w + "3810302175/mods/PZVoxelStudioViewpoint/common"), new File(w + "3820833348/mods/DGVWindows3D/42")};
        Map<String, String> models = new HashMap<>();
        Pattern model = Pattern.compile("model (\\w+)\\s*\\{\\s*mesh = ([^,]+),");
        for (String[] l : new String[][] {{"42/media/knox/bar_models.txt", "KnoxMenuBar."}, {"42/media/knox/bar_vp.txt", "KnoxMenuBarVp."}}) {
            Matcher m = model.matcher(Files.readString(new File(mod, l[0]).toPath(), StandardCharsets.UTF_8));
            while (m.find()) {
                String me = m.group(2).trim();
                models.put(l[1] + m.group(1), me.startsWith("media/") ? me : "media/models_X/" + me + ".x");
            }
        }
        String text = Files.readString(new File(mod, "42/media/lua/client/Knox/KnoxMenuSceneBar.lua").toPath(), StandardCharsets.UTF_8);
        Matcher fire = Pattern.compile("local FIRE_X, FIRE_Z = (-?[\\d.]+), (-?[\\d.]+)").matcher(text);
        fire.find();
        float fx = Float.parseFloat(fire.group(1)), fz = Float.parseFloat(fire.group(2));
        String block = text.substring(text.indexOf("local PROPS = {"));
        block = block.substring(0, block.indexOf("\n}")) + "\n";
        Matcher m = Pattern.compile("\\{id = \"(kb_\\w+)\", model = \"([\\w.]+)\"([^\n]*)\\},?\r?\n").matcher(block);
        int[] cells = new int[NX * NZ];
        java.util.Arrays.fill(cells, -1);
        float U = KnoxBarWalk.U;
        while (m.find()) {
            String id = m.group(1), r = m.group(3), mesh = models.get(m.group(2));
            // (the snow is walked on; the walls are the room's bounds; the floor and the ceiling aren't at this height)
            if (mesh == null || id.contains("drift") || id.contains("floor") || id.contains("ceiling") || id.contains("rear") || id.contains("wall_")
                || id.equals("kb_trim") || id.contains("trash") || id.contains("garland") || id.contains("window") || id.equals("kb_boards")) continue;
            File f = find(roots, mesh);
            if (f == null) continue;
            KnoxBarMesh me = mesh.endsWith(".obj") ? KnoxBarMesh.readObj(f) : KnoxBarMesh.readX(f);
            float s = num(r, "s", 1, fx, fz);
            Matrix4f mat = new Matrix4f().translate(num(r, "x", 0, fx, fz) * U, num(r, "y", 0, fx, fz) + num(r, "ym", 0, fx, fz) * U, num(r, "z", 0, fx, fz) * U)
                .rotateXYZ((float) Math.toRadians(num(r, "rx", 0, fx, fz)), (float) Math.toRadians(num(r, "yaw", 0, fx, fz)), (float) Math.toRadians(num(r, "rz", 0, fx, fz)))
                .scale(num(r, "sx", 1, fx, fz) * s, num(r, "sy", 1, fx, fz) * s, num(r, "sz", 1, fx, fz) * s);
            names.add(id);
            int who = names.size() - 1;
            float[] v = me.vertices;
            int[] ix = me.indices;
            Vector3f p = new Vector3f(), q = new Vector3f(), t = new Vector3f();
            for (int i = 0; i + 2 < ix.length; i += 3) {
                int A = ix[i] * 8, B = ix[i + 1] * 8, C = ix[i + 2] * 8;
                p.set(v[A], v[A + 1], v[A + 2]);
                mat.transformPosition(p).div(U);
                q.set(v[B], v[B + 1], v[B + 2]);
                mat.transformPosition(q).div(U);
                t.set(v[C], v[C + 1], v[C + 2]);
                mat.transformPosition(t).div(U);
                Vector3f e1 = new Vector3f(q).sub(p), e2 = new Vector3f(t).sub(p);
                int n = Math.max(2, (int) (Math.max(e1.length(), e2.length()) / (G * 0.7f)));
                for (int a = 0; a <= n; a++) {
                    for (int b = 0; b <= n - a; b++) {
                        float k1 = a / (float) n, k2 = b / (float) n, y = p.y + e1.y * k1 + e2.y * k2;
                        if (y < LO || y > HI) continue;
                        int gx = (int) ((p.x + e1.x * k1 + e2.x * k2 - GX0) / G), gz = (int) ((p.z + e1.z * k1 + e2.z * k2 - GZ0) / G);
                        if (gx >= 0 && gz >= 0 && gx < NX && gz < NZ) cells[gx + gz * NX] = who;
                    }
                }
            }
        }
        return cells;
    }

    static void againstModels(File mod) throws Exception {
        List<String> names = new ArrayList<>();
        int[] cells = slice(mod, names);
        // the body's own middle, where a solid would be plainly walked through
        float core = 0.2f;
        int reach = (int) (core / G) + 1;
        Map<String, Integer> through = new HashMap<>();
        String where = "";
        int free = 0;
        int cx = (int) ((14f + 0f) / 0.05f), cz = (int) (16f / 0.05f);
        boolean[] open = new boolean[cx * cz], seen = new boolean[cx * cz];
        for (int iz = 0; iz < cz; iz++) {
            for (int ix = 0; ix < cx; ix++) {
                float x = GX0 + ix * 0.05f, z = GZ0 + iz * 0.05f;
                open[ix + iz * cx] = depth(x, z) < 1e-5f;
            }
        }
        // what can be reached from the menu's place
        ArrayDeque<Integer> go = new ArrayDeque<>();
        int start = (int) ((MENU_X - GX0) / 0.05f) + (int) ((MENU_Z - 0.3f - GZ0) / 0.05f) * cx;
        check(open[start], "the menu's place is open");
        go.add(start);
        seen[start] = true;
        while (!go.isEmpty()) {
            int at = go.poll();
            free++;
            int ix = at % cx, iz = at / cx;
            for (int[] d : new int[][] {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
                int nx = ix + d[0], nz = iz + d[1];
                if (nx < 0 || nz < 0 || nx >= cx || nz >= cz) continue;
                int n = nx + nz * cx;
                if (open[n] && !seen[n]) {
                    seen[n] = true;
                    go.add(n);
                }
            }
            float x = GX0 + ix * 0.05f, z = GZ0 + iz * 0.05f;
            int gx = (int) ((x - GX0) / G), gz = (int) ((z - GZ0) / G);
            for (int a = -reach; a <= reach; a++) {
                for (int b = -reach; b <= reach; b++) {
                    int c = gx + a + (gz + b) * NX;
                    if (a * a + b * b > (core / G) * (core / G) || c < 0 || c >= cells.length) continue;
                    if (cells[c] >= 0) {
                        through.merge(names.get(cells[c]), 1, Integer::sum);
                        where = String.format(Locale.ROOT, " (last: body at %.2f, %.2f)", x, z);
                    }
                }
            }
        }
        check(through.isEmpty(), "no model at a body's height where the body can go" + (through.isEmpty() ? "" : ": " + through + where));
        System.out.printf(Locale.ROOT, "      walkable %.0f sq m%n", free * 0.05f * 0.05f);
        for (float[] place : new float[][] {{3.85f, -8.0f}, {-3f, -2.8f}, {0f, -7f}, {5f, -2f}, {-5.5f, -5f}, {5.5f, 3.5f}, {-5f, 0.8f}, {4.9f, 0.8f}, {-2f, 3f}}) {
            int ix = (int) ((place[0] - GX0) / 0.05f), iz = (int) ((place[1] - GZ0) / 0.05f);
            boolean near = false;
            for (int a = -5; a <= 5; a++) for (int b = -5; b <= 5; b++) near |= seen[ix + a + (iz + b) * cx];
            check(near, String.format(Locale.ROOT, "reachable: %.1f, %.1f", place[0], place[1]));
        }
    }

    public static void main(String[] args) throws Exception {
        noPassing();
        sliding();
        anyFrameRate();
        head();
        look();
        inAndOut();
        againstModels(new File(args[0]));
        if (failed > 0) {
            System.out.println(failed + " FAILED");
            System.exit(1);
        }
        System.out.println("bar walk: all passed");
    }
}
