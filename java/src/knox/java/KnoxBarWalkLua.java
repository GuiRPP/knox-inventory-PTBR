package knox.java;

import me.zed_0xff.zombie_buddy.Patch;

import org.lwjgl.glfw.GLFW;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.input.GameKeyboard;
import zombie.vehicles.UI3DScene;

/**
 * The walk about the bar (KnoxBarWalk) in the game: the mouse taken and given back, the keys, the
 * camera. The mouse is the window's and the window is the render thread's: it is read there, as the
 * game polls its events (Display.processMessages), and added up for the main thread's next frame.
 * If the main thread stops asking (an error in Lua, the menu gone) the render thread gives the mouse
 * back by itself: it is never left taken.
 */
public final class KnoxBarWalkLua {
    private static final int KEY_W = 17, KEY_A = 30, KEY_S = 31, KEY_D = 32, KEY_LSHIFT = 42, KEY_RSHIFT = 54;
    private static final long GIVE_BACK_NS = 500_000_000L;
    private static final float U = KnoxBarWalk.U;

    private static final KnoxBarWalk WALK = new KnoxBarWalk();
    private static boolean on;
    private static long lastNs;

    // (between the two threads: briefly, under this lock)
    private static final Object MOUSE = new Object();
    private static volatile boolean want;
    private static long askedNs;
    private static double sumX, sumY;

    // the render thread's own
    private static boolean taken, hasLast;
    private static int modeBefore;
    private static double lastX, lastY;
    private static final double[] AT_X = new double[1], AT_Y = new double[1];

    private KnoxBarWalkLua() {
    }

    /** Every time the game has polled the window (render thread; public: patch body). */
    public static void messages() {
        if (!want && !taken) return;
        boolean keep;
        synchronized (MOUSE) {
            keep = want && System.nanoTime() - askedNs < GIVE_BACK_NS;
        }
        try {
            long window = org.lwjglx.opengl.Display.getWindow();
            if (window == 0L) return;
            if (!keep) {
                if (taken) giveBack(window);
                return;
            }
            take(window);
            if (GLFW.glfwGetWindowAttrib(window, GLFW.GLFW_FOCUSED) != GLFW.GLFW_TRUE) {
                hasLast = false;
                return;
            }
            GLFW.glfwGetCursorPos(window, AT_X, AT_Y);
            if (hasLast) {
                synchronized (MOUSE) {
                    sumX += AT_X[0] - lastX;
                    sumY += AT_Y[0] - lastY;
                }
            }
            lastX = AT_X[0];
            lastY = AT_Y[0];
            hasLast = true;
        } catch (RuntimeException | LinkageError e) {
            synchronized (MOUSE) {
                want = false;
            }
            System.out.println("[Knox] bar walk, the mouse: " + e);
        }
    }

    private static void take(long window) {
        if (!taken) {
            taken = true;
            hasLast = false;
            modeBefore = GLFW.glfwGetInputMode(window, GLFW.GLFW_CURSOR);
            if (modeBefore == GLFW.GLFW_CURSOR_DISABLED) modeBefore = GLFW.GLFW_CURSOR_NORMAL;
            if (GLFW.glfwRawMouseMotionSupported()) GLFW.glfwSetInputMode(window, GLFW.GLFW_RAW_MOUSE_MOTION, GLFW.GLFW_TRUE);
        }
        // (the game or Viewpoint may set theirs when the cursor changes: ours stays on top)
        if (GLFW.glfwGetInputMode(window, GLFW.GLFW_CURSOR) != GLFW.GLFW_CURSOR_DISABLED) {
            GLFW.glfwSetInputMode(window, GLFW.GLFW_CURSOR, GLFW.GLFW_CURSOR_DISABLED);
            hasLast = false;
        }
    }

    private static void giveBack(long window) {
        taken = false;
        if (GLFW.glfwRawMouseMotionSupported()) GLFW.glfwSetInputMode(window, GLFW.GLFW_RAW_MOUSE_MOTION, GLFW.GLFW_FALSE);
        GLFW.glfwSetInputMode(window, GLFW.GLFW_CURSOR, modeBefore);
    }

    @Patch(className = "org.lwjglx.opengl.Display", methodName = "processMessages")
    public static class Messages {
        @Patch.OnExit
        public static void exit() {
            KnoxBarWalkLua.messages();
        }
    }

    private static void mouseOn(boolean take) {
        synchronized (MOUSE) {
            want = take;
            askedNs = System.nanoTime();
            sumX = sumY = 0.0;
        }
        KnoxCursor.hide(take);
    }

    /** W, A, S or D in the menu: from the menu's camera (scene units). */
    @LuaMethod(name = "knoxBarWalkStart", global = true)
    public static void knoxBarWalkStart(double ex, double ey, double ez, double tx, double ty, double tz) {
        WALK.begin((float) ex / U, (float) ey / U, (float) ez / U, (float) tx / U, (float) ty / U, (float) tz / U);
        lastNs = System.nanoTime();
        on = true;
        mouseOn(true);
    }

    /** Esc: on the way back; it ends by itself (knoxBarWalkStep says so). */
    @LuaMethod(name = "knoxBarWalkLeave", global = true)
    public static void knoxBarWalkLeave() {
        if (on) WALK.leave();
    }

    /** Stopped at once: the scene is going, whatever happened. */
    @LuaMethod(name = "knoxBarWalkStop", global = true)
    public static void knoxBarWalkStop(UI3DScene scene) {
        float[] c = scene == null ? null : KnoxMenu.CAMERAS.get(scene);
        if (c != null) {
            c[8] = 0f;
            c[9] = 1f;
            c[10] = 0f;
        }
        if (!on) return;
        on = false;
        mouseOn(false);
    }

    /**
     * Each frame while walking, with the menu's camera as it is now. The view comes from
     * knoxBarWalkView; its up goes straight to the camera. False: over, the menu's camera is back.
     */
    @LuaMethod(name = "knoxBarWalkStep", global = true)
    public static boolean knoxBarWalkStep(UI3DScene scene, double fov, double ex, double ey, double ez, double tx, double ty, double tz, boolean still) {
        if (!on) return false;
        long ns = System.nanoTime();
        double dt = (ns - lastNs) / 1e9;
        lastNs = ns;
        double dx, dy;
        synchronized (MOUSE) {
            dx = sumX;
            dy = sumY;
            sumX = sumY = 0.0;
            askedNs = ns;
        }
        boolean active = org.lwjglx.opengl.Display.isActive();
        if (active && !WALK.leaving()) WALK.mouse((float) dx, (float) dy);
        float ahead = 0f, side = 0f;
        if (active) {
            if (GameKeyboard.isKeyDown(KEY_W)) ahead += 1f;
            if (GameKeyboard.isKeyDown(KEY_S)) ahead -= 1f;
            if (GameKeyboard.isKeyDown(KEY_D)) side += 1f;
            if (GameKeyboard.isKeyDown(KEY_A)) side -= 1f;
        }
        WALK.keys(ahead, side, active && (GameKeyboard.isKeyDown(KEY_LSHIFT) || GameKeyboard.isKeyDown(KEY_RSHIFT)));
        WALK.still = still;
        WALK.frame(dt, (float) ex / U, (float) ey / U, (float) ez / U, (float) tx / U, (float) ty / U, (float) tz / U, (float) fov);
        if (WALK.over()) {
            knoxBarWalkStop(scene);
            return false;
        }
        float[] c = scene == null ? null : KnoxMenu.CAMERAS.get(scene);
        if (c != null) {
            c[8] = WALK.view[6];
            c[9] = WALK.view[7];
            c[10] = WALK.view[8];
        }
        return true;
    }

    /** The view as walked: 0..2 the eye, 3..5 where it looks (scene units), 9 the angle. */
    @LuaMethod(name = "knoxBarWalkView", global = true)
    public static double knoxBarWalkView(int i) {
        return WALK.view[i];
    }

    /** How dark the picture is, 0..1 (a long way back to the menu's place). */
    @LuaMethod(name = "knoxBarWalkDark", global = true)
    public static double knoxBarWalkDark() {
        return on ? WALK.dark() : 0.0;
    }

    @LuaMethod(name = "knoxBarWalkTunes", global = true)
    public static int knoxBarWalkTunes() {
        return WALK.tune.length;
    }

    @LuaMethod(name = "knoxBarWalkTuneName", global = true)
    public static String knoxBarWalkTuneName(int which) {
        return KnoxBarWalk.TUNE_NAMES[which];
    }

    @LuaMethod(name = "knoxBarWalkTune", global = true)
    public static double knoxBarWalkTune(int which) {
        return WALK.tune[which];
    }

    /** Sets one of the numbers the author tunes, inside its limits. */
    @LuaMethod(name = "knoxBarWalkTuneSet", global = true)
    public static void knoxBarWalkTuneSet(int which, double value) {
        if (which < 0 || which >= WALK.tune.length) return;
        WALK.tune[which] = Math.max(KnoxBarWalk.TUNE_MIN[which], Math.min(KnoxBarWalk.TUNE_MAX[which], (float) value));
    }

    /** One step of it up or down. */
    @LuaMethod(name = "knoxBarWalkTuneBy", global = true)
    public static void knoxBarWalkTuneBy(int which, int steps) {
        knoxBarWalkTuneSet(which, WALK.tune[which] + (double) steps * KnoxBarWalk.TUNE_STEP[which]);
    }
}
