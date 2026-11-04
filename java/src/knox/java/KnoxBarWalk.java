package knox.java;

/**
 * Walking about the winter bar in the first person (the author, 2026-11-04: W, A, S or D in the main
 * menu, a secret; Esc goes back). Plain arithmetic, nothing of the game's: the body, its collisions,
 * the look and the head's motion, stepped at a fixed rate so that it moves the same at 30 and at 240
 * frames, and tested as it is by tools\barwalk. The game's side is KnoxBarWalkLua.
 *
 * Metres and radians; x and z as the room has them, the look along (sin yaw, cos yaw).
 */
public final class KnoxBarWalk {
    public static final float U = 1f / 1.22f;      // scene units in a metre

    // What the author tunes on the spot (keys in KnoxMenuSceneBar), kept in Zomboid\Lua\knox_bar_walk.txt
    public static final int SPEED = 0, FAST = 1, STRIDE = 2, BOB_Y = 3, BOB_X = 4, BOB_ROLL = 5, LOOK_LAG = 6, SENS = 7, IDLE = 8, FOV = 9;
    public static final String[] TUNE_NAMES = {"speed", "shift speed", "stride", "bob up", "bob side", "bob roll", "look lag", "mouse", "idle", "fov"};
    public static final float[] TUNE_START = {1.3f, 2.0f, 0.72f, 0.012f, 0.008f, 0.2f, 0.05f, 0.0016f, 1f, 60f};
    public static final float[] TUNE_STEP = {0.1f, 0.1f, 0.04f, 0.002f, 0.002f, 0.05f, 0.01f, 0.0002f, 0.1f, 2f};
    public static final float[] TUNE_MIN = {0.5f, 0.5f, 0.4f, 0f, 0f, 0f, 0.012f, 0.0002f, 0f, 40f};
    public static final float[] TUNE_MAX = {3f, 4f, 1.2f, 0.06f, 0.04f, 2f, 0.3f, 0.01f, 4f, 90f};
    public final float[] tune = TUNE_START.clone();

    private static final double STEP = 1.0 / 240.0;
    public static final float RADIUS = 0.30f;      // half the body's width
    private static final float EYES = 1.65f;       // over the floor
    private static final float BACK = 0.7f, SIDE = 0.8f;   // of the speed, going back and to the side
    private static final float GO_RATE = 19f, STOP_RATE = 26f;   // about 0.25 s up to speed, 0.18 s to a stop
    private static final float BOB_EASE = 0.12f, SETTLE = 3f;
    private static final float PITCH_MAX = (float) Math.toRadians(85), PITCH_SOFT = (float) Math.toRadians(70);
    private static final float ENTER_FOR = 1.2f, DARK_IN = 0.28f, DARK_OUT = 0.45f, GLIDE_FAR = 2.2f;
    private static final float TURN = 6.2831855f;

    // The room's walls and what stands in it, as the models have them at the height of a body
    // (tools\barwalk checks them against the models). The back wall stops at the door's opening:
    // one can go up to the threshold, not out (the author, 2026-11-04).
    public static final float X0 = -6f, X1 = 6f, Z0 = -8.35f, Z1 = 4.4f;
    // x, z, half along x, half along z, degrees
    public static final float[][] BOXES = {
        {-1.35f, -8.15f, 4.65f, 0.15f, 0f}, {5.08f, -8.15f, 0.92f, 0.15f, 0f},   // the back wall, either side of the door
        {0.17f, 0.84f, 3.63f, 0.36f, 0f},                                      // the counter
        {-4.09f, -1.12f, 0.76f, 0.85f, 101f},                                  // the cigarette machine
        {-2.27f, -5.01f, 0.27f, 0.27f, 0f},                                    // the smoker on his chair
        {-1.35f, -6.5f, 0.31f, 0.32f, 0f},                                     // the chair on its back
        {4.88f, -4.82f, 0.26f, 0.21f, -142f},                                  // the cardboard box
        {-0.04f, -7.58f, 0.48f, 0.38f, 0f},                                    // the jukebox
        {-4.58f, -7.28f, 1.42f, 0.67f, 0f},                                    // what lies by the flag
        {1.34f, -7.86f, 0.72f, 0.14f, 0f},                                     // the table in the window
    };
    // x, z, radius
    public static final float[][] ROUNDS = {
        {-1.76f, 0.04f, 0.30f},                                                 // the one asleep on his stool
        {-1.25f, -5f, 0.58f}, {-1.15f, -4.29f, 0.31f}, {-0.31f, -5.56f, 0.22f}, // the smoker's table, a chair, the cold fire
        {2.25f, -4.3f, 0.58f}, {2.92f, -4.02f, 0.34f}, {1.56f, -4.66f, 0.36f},  // the map's table and chairs
        {2.7f, -6.95f, 0.3f},                                                   // the one by the door
        {-2.55f, -4.25f, 0.18f},                                                // the smoker's bag
        {4.42f, -7.93f, 0.1f},                                                  // the door on its hinge
    };
    // The snow one walks up: x, z, half along x, half along z, height (the room's drifts)
    private static final float[][] DRIFTS = {{3.85f, -7.75f, 1.3f, 1.0f, 0.48f}, {3.55f, -6.9f, 0.9f, 1.1f, 0.14f}, {1.5f, -7.7f, 0.9f, 0.55f, 0.18f}};

    // the body
    public float x, z;
    private float vx, vz, ax, az;
    private float yaw, pitch, yawV, pitchV, yawWant, pitchWant;
    private float phase, bob, ground;
    private double clock, left;
    private final float[] solve = new float[4];

    // the input of the frame
    private float wantAhead, wantSide;
    private boolean wantFast;
    /** Animations off: no head's motion of any kind. */
    public boolean still;

    // a pose: eye x y z, yaw, pitch, roll; the last two steps', the frame drawn between them
    private final float[] last = new float[6], now = new float[6];

    // going in and out of it
    private float walkK, dark, homeX, homeZ;
    private boolean leaving, darkPast, over;

    /** What is drawn: the eye and what it looks at in scene units, the up, the angle in degrees. */
    public final float[] view = new float[10];

    /** Starts at the menu's camera: (ex, ey, ez) towards (tx, ty, tz), metres; home: where it stands. */
    public void begin(float ex, float ey, float ez, float tx, float ty, float tz) {
        homeX = ex;
        homeZ = ez;
        solve[0] = ex;
        solve[1] = ez;
        solve[2] = solve[3] = 0f;
        collide(solve);
        x = solve[0];
        z = solve[1];
        vx = vz = ax = az = 0f;
        yaw = yawWant = (float) Math.atan2(tx - ex, tz - ez);
        pitch = pitchWant = (float) Math.atan2(ty - ey, Math.hypot(tx - ex, tz - ez));
        yawV = pitchV = 0f;
        phase = bob = 0f;
        ground = groundAt(x, z);
        clock = left = 0;
        walkK = dark = 0f;
        wantAhead = wantSide = 0f;
        wantFast = false;
        leaving = darkPast = over = false;
        pose(now);
        System.arraycopy(now, 0, last, 0, 6);
    }

    /** Esc: back to the menu's camera. */
    public void leave() {
        leaving = true;
    }

    public boolean leaving() {
        return leaving;
    }

    /** Back at the menu's camera: nothing of this is on the screen any more. */
    public boolean over() {
        return over;
    }

    /** How dark the picture is, 0..1: a long way back isn't flown through the counter. */
    public float dark() {
        return dark;
    }

    public float yawNow() {
        return yaw;
    }

    public float pitchNow() {
        return pitch;
    }

    public float speedNow() {
        return (float) Math.hypot(vx, vz);
    }

    /** Keys held this frame: -1..1 forward, -1..1 to the right. */
    public void keys(float ahead, float side, boolean fast) {
        wantAhead = ahead;
        wantSide = side;
        wantFast = fast;
    }

    /** The mouse moved since the last frame (its counts, y down the screen). */
    public void mouse(float dx, float dy) {
        float s = tune[SENS];
        yawWant -= dx * s;
        float d = -dy * s;
        // (soft towards the end of the neck's way: no wall to run into)
        if (d * pitchWant > 0f) {
            float a = (Math.abs(pitchWant) - PITCH_SOFT) / (PITCH_MAX - PITCH_SOFT);
            if (a > 0f) d *= Math.max(0f, 1f - a * a);
        }
        pitchWant = Math.max(-PITCH_MAX, Math.min(PITCH_MAX, pitchWant + d));
    }

    /** A frame: dt seconds passed, the menu's camera as it is now (metres; its fov in degrees). */
    public void frame(double dt, float mx, float my, float mz, float mtx, float mty, float mtz, float menuFov) {
        left += Math.min(0.1, Math.max(0.0, dt));
        while (left >= STEP) {
            left -= STEP;
            System.arraycopy(now, 0, last, 0, 6);
            step((float) STEP);
            pose(now);
        }
        float k = (float) (left / STEP);
        float ex = last[0] + (now[0] - last[0]) * k, ey = last[1] + (now[1] - last[1]) * k, ez = last[2] + (now[2] - last[2]) * k;
        float wy = last[3] + (now[3] - last[3]) * k, wp = last[4] + (now[4] - last[4]) * k, wr = last[5] + (now[5] - last[5]) * k;
        float menuYaw = (float) Math.atan2(mtx - mx, mtz - mz);
        float menuPitch = (float) Math.atan2(mty - my, Math.hypot(mtx - mx, mtz - mz));

        // (the same glide in and out: smooth at both its ends, whatever the mouse does meanwhile)
        float w = walkK * walkK * walkK * (walkK * (walkK * 6f - 15f) + 10f);
        float px = mx + (ex - mx) * w, py = my + (ey - my) * w, pz = mz + (ez - mz) * w;
        float turn = wy - menuYaw;
        turn -= TURN * Math.round(turn / TURN);
        float vy = menuYaw + turn * w, vp = menuPitch + (wp - menuPitch) * w, vr = wr * w;
        float cp = (float) Math.cos(vp), sp = (float) Math.sin(vp), sy = (float) Math.sin(vy), cy = (float) Math.cos(vy);
        float fx = cp * sy, fy = sp, fz = cp * cy;
        // right = look x (0, 1, 0); up = right x look; then the roll
        float rx = -cy, rz = sy;
        float ux = -rz * fy, uy = rz * fx - rx * fz, uz = rx * fy;
        float sr = (float) Math.sin(vr), cr = (float) Math.cos(vr);
        view[0] = px * U;
        view[1] = py * U;
        view[2] = pz * U;
        view[3] = (px + fx * 10f) * U;
        view[4] = (py + fy * 10f) * U;
        view[5] = (pz + fz * 10f) * U;
        view[6] = ux * cr + rx * sr;
        view[7] = uy * cr;
        view[8] = uz * cr + rz * sr;
        view[9] = menuFov + (tune[FOV] - menuFov) * w;
    }

    private void leaveStep(float h) {
        if (dark <= 0f && !darkPast && Math.hypot(x - homeX, z - homeZ) <= GLIDE_FAR) {
            walkK = Math.max(0f, walkK - h / ENTER_FOR);
            if (walkK <= 0f) over = true;
        } else if (!darkPast) {
            dark = Math.min(1f, dark + h / DARK_IN);
            if (dark >= 1f) {
                darkPast = true;
                walkK = 0f;
            }
        } else {
            dark = Math.max(0f, dark - h / DARK_OUT);
            if (dark <= 0f) over = true;
        }
    }

    private void step(float h) {
        clock += h;
        if (leaving) leaveStep(h);
        else walkK = Math.min(1f, walkK + h / ENTER_FOR);

        float w = 2f / Math.max(0.012f, tune[LOOK_LAG]);
        yawV += (w * w * (yawWant - yaw) - 2f * w * yawV) * h;
        yaw += yawV * h;
        pitchV += (w * w * (pitchWant - pitch) - 2f * w * pitchV) * h;
        pitch += pitchV * h;

        float ahead = leaving ? 0f : wantAhead, side = leaving ? 0f : wantSide;
        float len = (float) Math.hypot(ahead, side);
        if (len > 1f) {
            ahead /= len;
            side /= len;
        }
        float pace = wantFast ? tune[FAST] : tune[SPEED];
        if (ahead < 0f) ahead *= BACK;
        side *= SIDE;
        float sy = (float) Math.sin(yaw), cy = (float) Math.cos(yaw);
        float wx = (sy * ahead - cy * side) * pace, wz = (cy * ahead + sy * side) * pace;
        float rate = wx * wx + wz * wz < vx * vx + vz * vz ? STOP_RATE : GO_RATE;
        ax += (rate * rate * (wx - vx) - 2f * rate * ax) * h;
        az += (rate * rate * (wz - vz) - 2f * rate * az) * h;
        vx += ax * h;
        vz += az * h;
        float ox = x, oz = z;
        solve[0] = x + vx * h;
        solve[1] = z + vz * h;
        solve[2] = vx;
        solve[3] = vz;
        collide(solve);
        x = solve[0];
        z = solve[1];
        vx = solve[2];
        vz = solve[3];

        // what the legs did, not what the keys asked: nothing shakes against a wall
        float went = (float) Math.hypot(x - ox, z - oz);
        float speed = went / h;
        phase += (float) Math.PI * went / Math.max(0.1f, tune[STRIDE]);
        if (speed < 0.1f && bob > 0.01f) {
            // (the step begun is finished)
            float to = (float) Math.ceil(phase / Math.PI) * (float) Math.PI;
            phase = Math.min(to, phase + SETTLE * h);
        }
        float wantBob = Math.min(1.3f, speed / Math.max(0.1f, tune[SPEED]));
        bob += (wantBob - bob) * (1f - (float) Math.exp(-h / BOB_EASE));
        ground += (groundAt(x, z) - ground) * (1f - (float) Math.exp(-h / 0.1f));
    }

    /** The eye where the body, its steps and its breath have it. */
    private void pose(float[] out) {
        float b = still ? 0f : bob, rest = still ? 0f : Math.max(0f, 1f - bob) * tune[IDLE];
        float s = (float) Math.sin(phase), c = (float) Math.cos(phase);
        // low as a foot lands, and quicker there than over the top of the step
        float stepY = ((float) Math.sqrt(s * s + 0.02f) - 0.57f) / 0.44f;
        float t = (float) clock;
        float breath = (float) (Math.sin(t * 1.57) + 0.3 * Math.sin(t * 2.71 + 1.1));
        float side = tune[BOB_X] * b * c;
        out[0] = x - (float) Math.cos(yaw) * side;
        out[1] = EYES + ground + tune[BOB_Y] * b * stepY + 0.003f * rest * breath;
        out[2] = z + (float) Math.sin(yaw) * side;
        // (never quite repeating: frequencies with no common measure)
        float n1 = (float) (Math.sin(t * 0.61) + 0.6 * Math.sin(t * 1.37 + 0.7) + 0.3 * Math.sin(t * 2.93 + 2.1));
        float n2 = (float) (Math.sin(t * 0.47 + 1.9) + 0.6 * Math.sin(t * 1.13 + 0.3) + 0.3 * Math.sin(t * 3.19 + 1.2));
        float n3 = (float) (Math.sin(t * 0.37 + 3.1) + 0.6 * Math.sin(t * 0.97 + 2.3));
        float deg = (float) Math.PI / 180f;
        out[3] = yaw + 0.07f * deg * rest * n1;
        out[4] = pitch + (0.05f * n2 + 0.04f * breath) * deg * rest;
        out[5] = (0.08f * rest * n3 + tune[BOB_ROLL] * b * c) * deg;
    }

    /** How high the snow is here. */
    public static float groundAt(float x, float z) {
        float most = 0f;
        for (float[] d : DRIFTS) {
            float a = (x - d[0]) / d[2], b = (z - d[1]) / d[3], q = 1f - a * a - b * b;
            if (q > 0f) most = Math.max(most, d[4] * q * (2f - q));
        }
        return most;
    }

    /**
     * {x, z, vx, vz}: out of whatever it stands in, by the shortest way, and what of the speed goes
     * into it taken off: what goes along stays - it slides along, it doesn't stick.
     */
    public static void collide(float[] p) {
        for (int pass = 0; pass < 3; pass++) {
            boolean hit = false;
            for (float[] r : ROUNDS) {
                float dx = p[0] - r[0], dz = p[1] - r[1], d = (float) Math.hypot(dx, dz), want = r[2] + RADIUS;
                if (d < want) {
                    hit = true;
                    if (d < 1e-5f) push(p, 1f, 0f, want);
                    else push(p, dx / d, dz / d, want - d);
                }
            }
            for (float[] b : BOXES) hit |= box(p, b);
            hit |= wall(p, 1f, 0f, X0 + RADIUS - p[0]);
            hit |= wall(p, -1f, 0f, p[0] - (X1 - RADIUS));
            hit |= wall(p, 0f, 1f, Z0 + RADIUS - p[1]);
            hit |= wall(p, 0f, -1f, p[1] - (Z1 - RADIUS));
            if (!hit) return;
        }
    }

    private static boolean box(float[] p, float[] b) {
        float a = (float) Math.toRadians(b[4]), c = (float) Math.cos(a), s = (float) Math.sin(a);
        float dx = p[0] - b[0], dz = p[1] - b[1];
        float lx = dx * c + dz * s, lz = -dx * s + dz * c;
        float nx = Math.max(-b[2], Math.min(b[2], lx)), nz = Math.max(-b[3], Math.min(b[3], lz));
        float ox = lx - nx, oz = lz - nz, d = (float) Math.hypot(ox, oz);
        float px, pz, depth;
        if (d > 1e-5f) {
            if (d >= RADIUS) return false;
            px = ox / d;
            pz = oz / d;
            depth = RADIUS - d;
        } else {
            // (inside: out by the nearest side)
            float gx = b[2] - Math.abs(lx), gz = b[3] - Math.abs(lz);
            px = gx < gz ? (lx < 0f ? -1f : 1f) : 0f;
            pz = gx < gz ? 0f : (lz < 0f ? -1f : 1f);
            depth = Math.min(gx, gz) + RADIUS;
        }
        push(p, px * c - pz * s, px * s + pz * c, depth);
        return true;
    }

    private static boolean wall(float[] p, float nx, float nz, float depth) {
        if (depth <= 0f) return false;
        push(p, nx, nz, depth);
        return true;
    }

    private static void push(float[] p, float nx, float nz, float by) {
        p[0] += nx * by;
        p[1] += nz * by;
        float into = p[2] * nx + p[3] * nz;
        if (into < 0f) {
            p[2] -= nx * into;
            p[3] -= nz * into;
        }
    }
}
