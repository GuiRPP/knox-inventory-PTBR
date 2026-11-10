package knox.java;

import java.nio.FloatBuffer;

import org.lwjgl.BufferUtils;

/**
 * What lives in the winter bar besides the heroes (stage 5 of the plan; the author, 2026-10-31:
 * "максимально живую" картинку): the door the storm works at and slams, the snow blown in
 * through the openings, the cigarette's smoke, the breath in the cold. Kept by the frame's
 * clock on the render thread (KnoxBarFrame.render); its own arrays, nothing new a frame.
 * Metres and seconds in here; scene units in and out.
 */
final class KnoxBarLife {
    private static final float U = KnoxBarFrame.U;
    private static final int HEROES = KnoxBarFrame.HEROES;

    // ---- the door: degrees off its place, towards shut (it hangs 71.6 degrees out into the storm;
    // shut a little short of that, or it would be in the frame's wood). A heavy door: how fast it
    // swings back, how soon it settles, how far the strongest gust drives it (past shut: a slam).
    // Tuned on the frame's gusts (2026-10-31): a slam about every half minute, not in step (7-60 s
    // apart); past half shut a tenth of the time; shut 3% of it.
    static final float SHUT = 70f, WIDE = -16f;
    private static final float SWING = 2.4f, SETTLE = 0.3f, PUSH = 85f;
    private float door, doorSpeed;
    private volatile int bangs;
    private volatile float bangPower;
    private int warmed;
    private boolean warming;

    // ---- what drifts in the air
    static final int FLAKE = 0, SMOKE = 1, BREATH = 2;
    static final int MAX = 1400, LOOK = 8;
    private final float[] x = new float[MAX], y = new float[MAX], z = new float[MAX];
    private final float[] vx = new float[MAX], vy = new float[MAX], vz = new float[MAX];
    private final float[] age = new float[MAX], life = new float[MAX], size0 = new float[MAX], size1 = new float[MAX];
    private final float[] alpha = new float[MAX], seed = new float[MAX];
    private final int[] kind = new int[MAX];
    private final boolean[] ribbon = new boolean[MAX];
    private int count;
    /** For the frame to draw: LOOK floats a particle (puff.vert), shown() of them. */
    final FloatBuffer look = BufferUtils.createFloatBuffer(MAX * LOOK);
    private int shown;

    // the snow comes in through the smashed window and the door (x0, y0, x1, y1, metres), and a
    // little through the gaps between the boards across the other one (y0, y1 of each gap)
    private static final float WALL = -8f;
    private static final float[] WINDOW = {0.65f, 0.95f, 2.35f, 2.45f}, DOORWAY = {3.35f, 0.05f, 4.35f, 2.1f};
    private static final float BOARDED_X0 = -2.15f, BOARDED_X1 = -0.75f;
    private static final float[][] GAPS = {{1.0f, 1.13f}, {1.31f, 1.45f}, {1.6f, 1.74f}, {1.93f, 2.07f}, {2.24f, 2.36f}};
    private float windowDue, doorDue, gapsDue, smokeDue;
    // the breath: when each one next breathes out, and till when; the smoke breathed out after a
    // drag: the drag's height, who drew on it, from when to when it comes out
    private final float[] nextBreath = new float[HEROES], breathUntil = new float[HEROES], breathDue = new float[HEROES];
    private float dragPeak, exhaleFrom = -1, exhaleUntil = -1, exhaleDue;
    private int exhaler = -1;
    private float clock;
    private boolean started;
    private long random = 0x2545F4914F6CDD1DL;

    /** Bangs of the door so far (for its sound), and the last one's strength 0..1. */
    int bangs() {
        return bangs;
    }

    float bangPower() {
        return bangPower;
    }

    /** The door now, degrees off its place towards shut, the rattle of its hinges over the swing. */
    float doorAngle(float time, float gust) {
        float shake = (float) (Math.sin(time * 13.0) * Math.sin(time * 7.3)) * (0.4f + 3f * gust);
        return Math.min(SHUT, door + shake);
    }

    /**
     * A step of `dt` s at the frame's `time`: the door, the snow, the smoke, the breath. ember: x y
     * z (units), its glow (below 0: none); mouths: HEROES of x y z, then which way the breath
     * goes (units; none: 0 0 0). The first step fills
     * the room as it would be after a few seconds (animations off: it stays so, and those who
     * come in later bring their smoke and breath at once: QA, 2026-10-31).
     */
    void step(float dt, float time, float[] ember, float[] mouths) {
        if (!started) {
            started = true;
            // (no sound for a slam nobody saw: the sound asks on the main thread, even meanwhile)
            warming = true;
            for (int i = 0; i < 150; i++) advance(1 / 30f, time - 5f + i / 30f, ember, mouths);
            warming = false;
            warmed = people(ember, mouths);
        }
        if (dt > 0) {
            advance(dt, time, ember, mouths);
            // (they came in with the time going: a frame without time is nothing new to them)
            warmed = Math.max(warmed, people(ember, mouths));
        } else {
            int people = people(ember, mouths);
            if (people > warmed) {
                warmed = people;
                float gust = KnoxBarFrame.gustAt(time);
                for (int i = 0; i < 150; i++) {
                    clock += 1 / 30f;
                    smokeAndBreath(1 / 30f, ember, mouths);
                    drift(1 / 30f, time, gust, false);
                }
            }
        }
        pack();
    }

    /** Who gives off smoke or breath now. */
    private int people(float[] ember, float[] mouths) {
        int n = ember[3] >= 0 ? 1 : 0;
        for (int h = 0; h < HEROES; h++) {
            int m = h * 6;
            if (mouths[m + 3] != 0 || mouths[m + 4] != 0 || mouths[m + 5] != 0) n++;
        }
        return n;
    }

    /** How far the wind lets the door stand open, 0 shut..1 (the light through it). */
    float doorLetsIn(float time, float gust) {
        return Math.max(0f, Math.min(1f, 1f - doorAngle(time, gust) / SHUT));
    }

    int shown() {
        return shown;
    }

    private void advance(float dt, float time, float[] ember, float[] mouths) {
        clock += dt;
        float gust = KnoxBarFrame.gustAt(time);
        stepDoor(dt, time, gust);

        // the snow: more in a gust; through the door as far as it stands open
        float rate = 38f * (0.2f + 1.4f * gust * gust);
        float open = doorLetsIn(time, gust);
        windowDue += rate * dt;
        doorDue += rate * open * dt;
        gapsDue += 7f * (0.15f + gust * gust) * dt;
        while (windowDue >= 1) {
            windowDue--;
            flake(WINDOW[0], WINDOW[1], WINDOW[2], WINDOW[3], gust, 1f);
        }
        while (doorDue >= 1) {
            doorDue--;
            flake(DOORWAY[0], DOORWAY[1], DOORWAY[2], DOORWAY[3], gust, 1f);
        }
        while (gapsDue >= 1) {
            gapsDue--;
            float[] g = GAPS[(int) (next() * GAPS.length) % GAPS.length];
            flake(BOARDED_X0, g[0], BOARDED_X1, g[1], gust, 0.45f);
        }

        smokeAndBreath(dt, ember, mouths);
        drift(dt, time, gust, true);
    }

    private void smokeAndBreath(float dt, float[] ember, float[] mouths) {
        // the cigarette: its smoke goes up all the time, less while it is drawn on; after a drag
        // the smoker breathes the smoke out
        float glow = ember[3];
        // (no breath from the mouth at the cigarette)
        int drawing = glow > 0.25f ? nearestMouth(mouths, ember) : -1;
        if (glow >= 0) {
            float ex = ember[0] / U, ey = ember[1] / U, ez = ember[2] / U;
            smokeDue += 16f * (1f - 0.7f * glow) * dt;
            while (smokeDue >= 1) {
                smokeDue--;
                int i = add(SMOKE, ex, ey, ez, 0f, 0.26f, 0f, 3f + 1.5f * next(), 0.01f, 0.09f + 0.05f * next(), 0.5f);
                if (i < 0) break;
                ribbon[i] = true;
            }
            if (glow > 0.55f) {
                if (glow > dragPeak) {
                    dragPeak = glow;
                    exhaler = nearestMouth(mouths, ember);
                }
            } else if (dragPeak > 0 && glow < 0.25f) {
                dragPeak = 0;
                exhaleFrom = clock + 0.35f;
                exhaleUntil = exhaleFrom + 1.1f;
            }
        } else {
            dragPeak = 0;
            smokeDue = 0;
        }

        // the breath of each, in the cold: out every 3.4-4.8 s; the smoker's after a drag is smoke
        for (int h = 0; h < HEROES; h++) {
            int m = h * 6;
            float dx = mouths[m + 3], dy = mouths[m + 4], dz = mouths[m + 5];
            if (dx == 0 && dy == 0 && dz == 0) continue;
            float mx = mouths[m] / U, my = mouths[m + 1] / U, mz = mouths[m + 2] / U;
            float len = (float) Math.sqrt(dx * dx + dy * dy + dz * dz);
            dx /= len;
            dy /= len;
            dz /= len;
            boolean smoking = h == exhaler && clock < exhaleUntil;
            if (smoking) {
                if (clock >= exhaleFrom) {
                    // (strongest at first)
                    float k = 1f - (clock - exhaleFrom) / (exhaleUntil - exhaleFrom);
                    exhaleDue += 24f * dt;
                    while (exhaleDue >= 1) {
                        exhaleDue--;
                        float sp = (0.35f + 0.35f * k) * (0.8f + 0.4f * next());
                        add(SMOKE, mx, my, mz, dx * sp + (next() - 0.5f) * 0.08f, dy * sp + (next() - 0.5f) * 0.06f, dz * sp + (next() - 0.5f) * 0.08f,
                            2.6f + 1.2f * next(), 0.04f, 0.26f + 0.1f * next(), 0.14f + 0.2f * k);
                    }
                }
                nextBreath[h] = Math.max(nextBreath[h], exhaleUntil + 1.5f);
                continue;
            }
            if (h == drawing) continue;
            if (clock >= nextBreath[h]) {
                breathUntil[h] = clock + 0.9f;
                nextBreath[h] = clock + 3.4f + 1.4f * next();
            }
            if (clock < breathUntil[h]) {
                breathDue[h] += 16f * dt;
                while (breathDue[h] >= 1) {
                    breathDue[h]--;
                    float sp = 0.3f + 0.15f * next();
                    add(BREATH, mx, my, mz, dx * sp + (next() - 0.5f) * 0.05f, dy * sp - 0.03f + (next() - 0.5f) * 0.04f, dz * sp + (next() - 0.5f) * 0.05f,
                        1.3f + 0.6f * next(), 0.02f, 0.13f + 0.05f * next(), 0.5f);
                }
            }
        }

    }

    /** All of it along; flakes: the snow too. */
    private void drift(float dt, float time, float gust, boolean flakes) {
        for (int i = 0; i < count; ) {
            if (!flakes && kind[i] == FLAKE) {
                i++;
                continue;
            }
            age[i] += dt;
            if (age[i] >= life[i] || !move(i, dt, time, gust) ) {
                remove(i);
                continue;
            }
            i++;
        }
    }

    private void stepDoor(float dt, float time, float gust) {
        float target = PUSH * gust * gust * gust * (0.82f + 0.22f * (float) Math.sin(time * 0.117f + 2f))
            + 1.2f * (float) Math.sin(time * 0.9f);
        // (in steps of 1/120 s at most: a long frame doesn't fling it)
        int steps = Math.max(1, (int) Math.ceil(dt * 120f));
        float h = dt / steps;
        for (int s = 0; s < steps; s++) {
            doorSpeed += (-SWING * SWING * (door - target) - 2f * SETTLE * SWING * doorSpeed) * h;
            door += doorSpeed * h;
            if (door > SHUT) {
                door = SHUT;
                if (doorSpeed > 0) {
                    if (doorSpeed > 8f && !warming) {
                        bangPower = Math.min(1f, doorSpeed / 120f);
                        bangs++;
                    }
                    doorSpeed = -doorSpeed * 0.35f;
                }
            } else if (door < WIDE) {
                door = WIDE;
                if (doorSpeed < 0) doorSpeed = -doorSpeed * 0.3f;
            }
        }
    }

    /** A flake blown in through an opening (metres), at the speed the gust gives it. */
    private void flake(float x0, float y0, float x1, float y1, float gust, float strength) {
        float sp = (1.6f + 2.4f * gust) * (0.6f + 0.6f * next()) * strength;
        add(FLAKE, x0 + (x1 - x0) * next(), y0 + (y1 - y0) * next(), WALL + 0.04f,
            sp * (0.2f + 0.3f * next()), sp * (next() - 0.55f) * 0.5f, sp,
            2.5f + 2.5f * next(), 0.008f + 0.012f * next(), 0, 0.7f + 0.3f * next());
    }

    /** False: it's gone (on the floor, out of the room). */
    private boolean move(int i, float dt, float time, float gust) {
        float s = seed[i] * 6.2832f;
        float px = x[i], py = y[i], pz = z[i];
        float ax, ay, az, k;
        if (kind[i] == FLAKE) {
            // the draft from the openings dies away into the room; the flake falls, whirled about
            float inflow = (1.2f + 2.6f * gust) * (float) Math.exp(-(pz - WALL) / 1.8f);
            float whirl = 0.35f * (0.3f + gust);
            ax = 0.3f * inflow + whirl * (float) Math.sin(1.7f * py + 0.9f * time + s);
            ay = -0.55f + 0.7f * whirl * (float) Math.sin(1.1f * pz + 1.3f * time + s * 1.7f);
            az = inflow + whirl * (float) Math.sin(1.3f * px - 0.7f * time + s * 0.5f);
            k = 2.2f;
        } else {
            // smoke and breath: rising while warm, the room's slow draft, torn more as they spread
            float t = age[i] / life[i];
            float drift = 0.3f * (0.4f + 1.2f * gust) * (float) Math.exp(-(pz - WALL) / 2.5f);
            float whirl = 0.05f + 0.12f * t;
            // (the cigarette's: one ribbon, all of it bent by the same air; the rest each its own)
            if (ribbon[i]) s = 0f;
            float rise = kind[i] == SMOKE ? 0.34f * (1f - 0.7f * t) : 0.07f * (1f - t);
            ax = 0.3f * drift + whirl * (float) Math.sin(2.3f * py + 1.1f * time + s);
            ay = rise + 0.6f * whirl * (float) Math.sin(1.9f * px - 0.8f * time + s * 1.3f);
            az = drift + whirl * (float) Math.sin(2.1f * py - 0.9f * time + s * 0.7f);
            k = kind[i] == SMOKE ? 1.4f : 2.0f;
        }
        float pull = Math.min(1f, dt * k);
        vx[i] += (ax - vx[i]) * pull;
        vy[i] += (ay - vy[i]) * pull;
        vz[i] += (az - vz[i]) * pull;
        x[i] = px + vx[i] * dt;
        y[i] = py + vy[i] * dt;
        z[i] = pz + vz[i] * dt;
        if (kind[i] == FLAKE && y[i] <= 0.005f) return false;
        return x[i] > -6f && x[i] < 6f && z[i] > WALL - 0.5f && z[i] < 3.5f && y[i] < 3.2f;
    }

    private void pack() {
        look.clear();
        for (int i = 0; i < count; i++) {
            float t = age[i] / life[i];
            float a, size;
            if (kind[i] == FLAKE) {
                a = alpha[i] * Math.min(1f, age[i] / 0.12f) * Math.min(1f, (life[i] - age[i]) / 0.5f);
                size = size0[i];
            } else {
                float fade = (float) Math.pow(1f - t, kind[i] == SMOKE ? 1.6f : 1.3f);
                a = alpha[i] * Math.min(1f, age[i] / (kind[i] == SMOKE ? 0.25f : 0.15f)) * fade;
                size = size0[i] + (size1[i] - size0[i]) * (ribbon[i] ? t : (float) Math.sqrt(t));
            }
            look.put(x[i] * U).put(y[i] * U).put(z[i] * U).put(size * U);
            look.put(a).put(kind[i]).put(seed[i]).put(t);
        }
        look.flip();
        shown = count;
    }

    /** A new one (metres, m/s), or -1: there's no room for it. */
    private int add(int what, float px, float py, float pz, float sx, float sy, float sz, float lifetime, float from, float to, float a) {
        if (count >= MAX) return -1;
        int i = count++;
        kind[i] = what;
        ribbon[i] = false;
        x[i] = px;
        y[i] = py;
        z[i] = pz;
        vx[i] = sx;
        vy[i] = sy;
        vz[i] = sz;
        age[i] = 0;
        life[i] = lifetime;
        size0[i] = from;
        size1[i] = to;
        alpha[i] = a;
        seed[i] = next();
        return i;
    }

    private void remove(int i) {
        int last = --count;
        kind[i] = kind[last];
        ribbon[i] = ribbon[last];
        x[i] = x[last];
        y[i] = y[last];
        z[i] = z[last];
        vx[i] = vx[last];
        vy[i] = vy[last];
        vz[i] = vz[last];
        age[i] = age[last];
        life[i] = life[last];
        size0[i] = size0[last];
        size1[i] = size1[last];
        alpha[i] = alpha[last];
        seed[i] = seed[last];
    }

    private int nearestMouth(float[] mouths, float[] ember) {
        int best = -1;
        float bestD = Float.MAX_VALUE;
        for (int h = 0; h < HEROES; h++) {
            int m = h * 6;
            if (mouths[m + 3] == 0 && mouths[m + 4] == 0 && mouths[m + 5] == 0) continue;
            float dx = mouths[m] - ember[0], dy = mouths[m + 1] - ember[1], dz = mouths[m + 2] - ember[2];
            float d = dx * dx + dy * dy + dz * dz;
            if (d < bestD) {
                bestD = d;
                best = h;
            }
        }
        return best;
    }

    /** 0..1, its own (xorshift): the same room each time it is built. */
    private float next() {
        random ^= random << 13;
        random ^= random >>> 7;
        random ^= random << 17;
        return (random >>> 40) / (float) (1L << 24);
    }
}
