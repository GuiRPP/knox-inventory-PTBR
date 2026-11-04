package knox.java;

import org.lwjgl.util.vector.Matrix4f;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.skinnedmodel.advancedanimation.AnimatedModel;
import zombie.core.skinnedmodel.animation.AnimationPlayer;
import zombie.core.skinnedmodel.model.SkinningBone;
import zombie.core.skinnedmodel.model.SkinningData;
import zombie.vehicles.UI3DScene;

/**
 * The bar's camera is the eyes of the one in the room (the author's idea, 2026-11-02). Now and
 * then he looks down at his left forearm: the right hand rolls the warm jacket's sleeve up, the
 * arm turns - a bite - and the sleeve is yanked down again; or nothing there, a breath out, the
 * sleeve let down slowly. After the Wristwatch mod's look at the wrist (the author's reference):
 * the game's own character in its own clothes, his arms put over his idle clip every frame - the
 * hand where the moment wants it, the elbow bending only as an elbow does, the forearm turning
 * no further than one turns - and everything on springs, the head after the arm: nothing jumps,
 * nothing stands still.
 *
 * The narrator is a scene character Lua stands where the camera is (KnoxMenuSceneBar: the eyes),
 * his head hidden - the camera is inside it. His bones are put as KnoxLook puts a head: in the
 * hook between the clip and the pose (AnimationPlayer.applyBoneReParenting), a bone's place in the
 * model turned and made local again. The skeleton's space is a mirror of his own (KnoxBarLua.bone:
 * its z is his back): the poses below are in his own (x his left, y up, z his front, scene units)
 * and taken over to the skeleton's; the turns are done there with plain vector algebra, which
 * holds in either.
 */
public class KnoxBite {

    /**
     * Anything for the hook (KnoxLook.Hook)? It runs for every character's animation, the game's
     * zombies too: one plain read of this flag when not.
     */
    public static volatile boolean ON = false;

    private static volatile AnimationPlayer who;

    /** The moment's sounds: the game's own (a bag's rustle for the sleeve, his breath). */
    private static final String PANIC = "media/sound/male_heavybreathpanic.wav";
    private static final String RELIEF = "media/sound/male_outofbreath_05.wav";

    // ------------------------------------------------------------------- his body

    static final float K = 1.5f;   // the skeleton's units to the scene's (KnoxBarLua.bone)
    /**
     * Where the camera is in his body and what it turns about (his own space). Well behind his
     * eyes: at the bar's FOV (32 degrees, not to be changed) a forearm at an arm's length from the
     * eyes filled the picture (the author's screenshot, 2026-11-02: "very, very close - just put the
     * skeleton where you need it"). So he stands ahead of the camera, his chest, neck and head
     * hidden (UPPER), the arms kept. Lua stands him by it: KnoxMenuSceneBar's EYES_UP, EYES_AHEAD.
     */
    static final float EYE_Y = 1.40f, EYE_Z = -0.32f, NECK_Y = 1.30f, NECK_Z = -0.34f;
    private static final float HIDDEN = 0.01f;    // the size his chest and head are drawn at

    // His left wrist's places (his own space; Bob_Idle's shoulder at 0.151 1.107 -0.05, arm 0.205
    // + 0.207, the eyes at 1.37 - the body's nose tip 1.34 0.086): on the way up, clear of the jacket;
    // across before the chest for the sleeve, low and near level - the right hand comes to it from below
    // and doesn't cross it (the author's video, 2026-11-02: the arms made a cross; tools/bite/arms_check.py);
    // up across the chest, palm up, to look; nearer at the sight of it; let
    // down a little at the breath out; on the way down. (Eyes 0.26 over the shoulder, the arm 0.25
    // before them: the head bows some 30-35 degrees to it, as one does.)
    private static final float[] RAISE = {0.17f, 1.0f, 0.25f};
    private static final float[] ROLL = {-0.03f, 1.08f, 0.23f};
    private static final float[] LOOK = {-0.07f, 1.23f, 0.27f};
    private static final float[] SEEN = {-0.065f, 1.245f, 0.255f};
    private static final float[] EASED = {-0.07f, 1.20f, 0.275f};
    private static final float[] DROP_L = {0.20f, 0.90f, 0.20f};
    // what the eyes go to before the arm is there: the forearm's middle from its wrist (measured, his space)
    private static final float[] AIM_OFF = {0.055f, -0.045f, -0.045f};
    // the right one's: resting low before him between, on its way down
    private static final float[] PARK_R = {-0.12f, 0.92f, 0.15f};
    private static final float[] DROP_R = {-0.20f, 0.86f, 0.16f};
    // where the elbows go (the left out and down, the forearm near level; to look, down - the forearm
    // up across the chest; the right out to his right, a little back)
    private static final float[] POLE_L = {0.85f, -0.5f, 0.1f}, POLE_LOOK = {0.7f, -0.7f, 0f}, POLE_R = {-0.8f, -0.6f, -0.1f};
    // the left palm down for the sleeve (the forearm's back up, to the right hand)
    private static final float[] PALM_DOWN = {-0.25f, -1f, 0.1f};
    // the right hand on the sleeve: the wrist behind the palm, scene units; how far off the sleeve it
    // comes in and goes away (never through the arm: the author's video, 2026-11-02 - let go, it went
    // down through the left forearm), s it takes going. (How far off the forearm's line: SLEEVE_R.)
    private static final float PALM_FROM_WRIST = 0.0385f, LIFT = 0.07f, LET_GO = 0.3f;
    /**
     * How thick the left sleeve is where the right hand takes it, skeleton units (tools/bite/
     * roll_sleeve.py prints it: the widest of it a palm's length about the place): rows rolled 0,
     * 1/4 .. 1, by the place on the forearm, wrist 0 .. elbow 1 by tenths; the skin's where it's
     * rolled off. The palm is put over it by PALM_OVER (the author's video, 2026-11-03: a finger,
     * then the hand, then much of it through the sleeve - it was put at one place off the line, inside
     * the sleeve and the more inside the more it was rolled).
     */
    private static final float[] SLEEVE_R = {0.0269f, 0.0295f, 0.0306f, 0.0315f, 0.0325f, 0.0325f, 0.0348f, 0.0371f, 0.0388f, 0.0388f, 0.0391f,
        0.0230f, 0.0297f, 0.0328f, 0.0338f, 0.0340f, 0.0350f, 0.0366f, 0.0371f, 0.0388f, 0.0388f, 0.0391f,
        0.0179f, 0.0179f, 0.0319f, 0.0356f, 0.0365f, 0.0375f, 0.0389f, 0.0389f, 0.0388f, 0.0388f, 0.0391f,
        0.0179f, 0.0179f, 0.0179f, 0.0345f, 0.0388f, 0.0391f, 0.0412f, 0.0412f, 0.0412f, 0.0388f, 0.0391f,
        0.0179f, 0.0179f, 0.0179f, 0.0254f, 0.0322f, 0.0416f, 0.0435f, 0.0435f, 0.0435f, 0.0388f, 0.0391f};
    // the hand's line over the cloth (skeleton units): half the palm's thickness (0.0175 at the game's
    // size, HANDS of it) and a hair
    private static final float PALM_OVER = 0.0175f * 0.7f + 0.003f;
    /**
     * How far a forearm turns from the clip's own (Bob_Idle: the palms to the thighs), the
     * skeleton's way round its elbow-to-wrist: the left one's turn to the palm up is +, the right
     * one's - (measured on the clip, 2026-11-02). More to the palm up than the other way.
     */
    private static final float SUPINATE = (float) Math.toRadians(170), PRONATE = (float) Math.toRadians(100);

    // ------------------------------------------------------------------- the moment

    // its times, s: the right hand comes; pulls the sleeve up, takes a new hold, pulls again; lets go;
    // the arm turns and comes up to the eyes; it is seen; the arm comes down, palm down, as before;
    // the right hand grabs; yanks it down, again; lets go. The quiet one: no yanking - the sleeve let
    // down in one slow pull. (The arm down before the hand comes - else they cross: the author's video,
    // 2026-11-02; the bite's look kept as long, the rest a quarter second later.)
    private static final float T_RAISE = 0.42f, T_RIGHT = 0.55f, T_TUG = 1.55f, T_REGRIP = 2.1f, T_TUG2 = 2.45f,
        T_LET = 3.05f, T_TURN = 3.3f, T_SEE = 4.6f;
    private static final float B_LOWER = 6.0f, B_GRAB = 6.3f, B_YANK = 6.9f, B_REGRIP = 7.2f, B_YANK2 = 7.4f, B_DONE = 7.7f;
    private static final float N_LOWER = 5.55f, N_GRAB = 6.0f, N_DOWN = 6.45f, N_DONE = 7.7f;
    private static final float SETTLE = 1.35f;   // s after letting go, the arms back in the clip's own
    private static final float GIVE_UP = 4f;     // s more, whatever the springs say

    private static volatile boolean busy;
    private static boolean bitten, started;
    private static float t, tWas, restPitch;
    private static float wL, wR;                 // the arms' weights over the clip's own, 0..1
    private static boolean rightOn;              // the right hand at the sleeve
    private static float[] wristGoal = RAISE;    // where the left wrist goes now
    private static float grip;                   // where on the forearm, 0 the wrist .. 1 the elbow
    private static int palmMode;                 // the left palm: 0 the clip's own, 1 down, 2 to the eyes
    private static float twistRate = 6.5f;       // how fast the forearms turn (the hook's springs), 1/s

    // springs: the left wrist and elbow (his space), where on the forearm, the head
    private static final float[] wrist = new float[6], pole = new float[6], poleR = new float[6];
    private static final float[] gripS = new float[2], pitch = new float[2], yaw = new float[2];
    // the hook's: the right wrist (his space), the forearms' turns (radians)
    private static final float[] wristR = new float[6], twistL = new float[2], twistR = new float[2];
    private static float holdR;                  // the right hand's hold of the sleeve, 0..1
    private static boolean wasOn;                // (the hook's) the right hand was at the sleeve
    private static float letUntil;               // till when it goes off the sleeve after letting go
    private static final float[] LET = new float[3];   // where to (his space)
    // what Lua is given: the head's turn from rest (degrees; down -, to his left +), the eye's move
    private static float outPitch, outYaw, outUp, outAhead, outLeft;

    // from the hook (his space): where the clip has the wrists and elbows; what the eyes go to
    private static final float[] animWristL = new float[3], animWristR = new float[3];
    private static final float[] animPoleL = new float[3], animPoleR = new float[3];
    private static final float[] aim = new float[3];
    private static volatile boolean read;        // the hook has read his clip once
    private static volatile boolean aimed;
    // to the hook (his space): the left wrist and elbow as the springs have them now, the grip
    private static final float[] wantL = new float[3], wantPoleL = new float[3], wantPoleR = new float[3];
    private static volatile float wantGrip;
    private static volatile float fear;          // 0..1: the tremor after the sight of it

    /**
     * The narrator's clothes: always the same man (the author, 2026-11-02) - their colours too, not
     * the wardrobe's dice. The jacket is the game's plain one, burgundy (the author, 2026-11-03: the
     * padded one bulky, its quilting odd), its left sleeve rolling up (tools/bite/roll_sleeve.py:
     * Knox_JacketRolled).
     */
    private static final String[] CLOTHES = {"Base.Tshirt_DefaultTEXTURE", "KnoxBite.JacketRolled",
        "Base.Trousers_Padded", "Base.Shoes_WorkBoots"};
    private static final zombie.core.ImmutableColor[] TINTS = {new zombie.core.ImmutableColor(0.62f, 0.6f, 0.55f),
        new zombie.core.ImmutableColor(0.5f, 0.1f, 0.14f), new zombie.core.ImmutableColor(0.27f, 0.28f, 0.3f), null};
    /**
     * His body: the game's with narrower arms (tools/bite/slim_arms.py - the author, 2026-11-03: the
     * arms less bulky), his alone; the skin the lightest, always (the author: the hands changed
     * colour from look to look - the skin was the dice's, each dressing anew).
     */
    private static final String BODY = "skinned/Knox_NarratorBody";
    private static final int SKIN = 0;   // MaleBody01
    private static zombie.core.skinnedmodel.model.Model body;
    private static boolean bodyAsked;

    /** His own body, once asked for (the game loads it); null: none - the game's then. */
    private static zombie.core.skinnedmodel.model.Model body() {
        if (!bodyAsked) {
            bodyAsked = true;
            try {
                zombie.scripting.objects.AnimationsMesh human = zombie.scripting.ScriptManager.instance.getAnimationsMesh("Human");
                if (human != null && human.modelMesh != null) {
                    body = zombie.core.skinnedmodel.ModelManager.instance.loadModel(BODY, null, human.modelMesh, "basicEffect");
                }
            } catch (RuntimeException | LinkageError e) {
                body = null;
            }
        }
        zombie.core.skinnedmodel.model.Model m = body;
        return m != null && !m.isFailure() ? m : null;
    }
    /**
     * The bite under the sleeve: a wound on the skin (a body visual, as a bitten one has) - the game's
     * own moved to the inside of the forearm near the wrist (Knox_BiteLForearm, tools/bite/bite_texture.py):
     * the game's is on its back, halfway up - under the rolled cuff and turned away from his eyes (the
     * author's video, 2026-11-02: no bite to be seen).
     */
    private static final String WOUND = "Knox_BiteLForearm";

    /** Dress him for the next look: `bitten` - the bite is there, under the sleeve. */
    @LuaMethod(name = "knoxBiteDress", global = true)
    public static boolean knoxBiteDress(UI3DScene scene, String id, boolean bitten) {
        AnimatedModel model = KnoxMenu.modelOf(scene, id);
        if (model == null) return false;
        try {
            KnoxMenu.Owner o = new KnoxMenu.Owner();
            o.female = false;
            o.visual.setSkinTextureIndex(SKIN);
            zombie.core.skinnedmodel.model.Model own = body();
            if (own != null) o.visual.setForceModel(own);
            o.visual.setHairModel("Short");
            if (bitten) o.visual.addBodyVisualFromClothingItemName(WOUND);
            for (int n = 0; n < CLOTHES.length; n++) {
                String type = CLOTHES[n];
                zombie.scripting.objects.Item script = zombie.scripting.ScriptManager.instance.getItem(type);
                zombie.core.skinnedmodel.population.ClothingItem ci = script == null ? null : script.getClothingItemAsset();
                if (ci == null) continue;
                zombie.core.skinnedmodel.visual.ItemVisual iv = new zombie.core.skinnedmodel.visual.ItemVisual();
                iv.setItemType(type);
                iv.setClothingItemName(ci.mame);
                iv.pickUninitializedValues(ci);
                iv.setTextureChoice(0);
                iv.setBaseTexture(0);
                if (TINTS[n] != null) iv.setTint(TINTS[n]);
                o.items.add(iv);
            }
            model.setAnimSetName(KnoxMenu.ANIM_SET);
            model.setAnimate(true);
            model.setAlpha(1f);
            model.setOutfitName(null, false, true);
            KnoxMenu.setLook(model, o);
            return true;
        } catch (RuntimeException | LinkageError e) {
            return false;
        }
    }

    /**
     * The narrator is in the room: his skeleton kept his (the chest hidden, the sleeve on its bones)
     * between the looks too - the sleeve's own bones are the props', the clip would put them in his
     * hands. False: no model yet.
     */
    @LuaMethod(name = "knoxBiteHold", global = true)
    public static boolean knoxBiteHold(UI3DScene scene, String id) {
        AnimatedModel model = KnoxMenu.modelOf(scene, id);
        AnimationPlayer player = model == null || !model.hasAnimationPlayer() ? null : model.getAnimationPlayer();
        if (player == null) return false;
        who = player;
        ON = true;
        return true;
    }

    /** He looks at his arm: `bite` - there is one. False: already looking, or no model yet. */
    @LuaMethod(name = "knoxBiteStart", global = true)
    public static boolean knoxBiteStart(UI3DScene scene, String id, boolean bite) {
        if (busy) return false;
        AnimatedModel model = KnoxMenu.modelOf(scene, id);
        AnimationPlayer player = model == null || !model.hasAnimationPlayer() ? null : model.getAnimationPlayer();
        if (player == null) return false;
        bitten = bite;
        busy = true;
        started = false;
        read = false;
        aimed = false;
        t = tWas = 0f;
        rollGoal = 0f;
        wL = wR = 0f;
        rightOn = false;
        palmMode = 0;
        fear = 0f;
        twistL[0] = twistL[1] = twistR[0] = twistR[1] = 0f;
        holdR = 0f;
        wasOn = false;
        letUntil = 0f;
        pitch[0] = pitch[1] = yaw[0] = yaw[1] = 0f;
        outPitch = outYaw = outUp = outAhead = outLeft = 0f;
        lastHook = 0L;
        who = player;
        ON = true;
        return true;
    }

    /** Still looking (the narrator to be shown, the mouse's look held)? */
    @LuaMethod(name = "knoxBiteBusy", global = true)
    public static boolean knoxBiteBusy() {
        return busy;
    }

    /**
     * The player wants the bar (a click, a key): the look cut short as one would - before the sleeve
     * is up, the arm just let down; after, it is pulled down at once.
     */
    @LuaMethod(name = "knoxBiteHurry", global = true)
    public static void knoxBiteHurry() {
        if (!busy || !started) return;
        float to;
        if (t < T_LET) to = bitten ? B_DONE : N_DONE;
        else to = bitten ? B_LOWER : N_LOWER;
        if (t < to) t = tWas = to;
    }

    /** The menu is gone, or the room built anew: nothing of it is left. */
    @LuaMethod(name = "knoxBiteStop", global = true)
    public static void knoxBiteStop() {
        busy = false;
        ON = false;
        who = null;
    }

    /**
     * Each frame while busy, before the camera is set: the moment goes on by `dt`; `restDeg` is
     * the camera's pitch as the scene has it now. Returns the head's turn down from it (degrees,
     * down -); the rest: knoxBiteYaw, knoxBiteEyeUp / Ahead / Left.
     */
    @LuaMethod(name = "knoxBiteFrame", global = true)
    public static double knoxBiteFrame(double dt, double restDeg) {
        if (!busy) return 0;
        restPitch = (float) Math.toRadians(restDeg);
        float d = (float) Math.max(0, Math.min(0.1, dt));
        if (!read) return 0;   // (the hook hasn't read his clip yet: it starts from there)
        if (!started) {
            started = true;
            System.arraycopy(animWristL, 0, wrist, 0, 3);
            wrist[3] = wrist[4] = wrist[5] = 0f;
            System.arraycopy(animPoleL, 0, pole, 0, 3);
            pole[3] = pole[4] = pole[5] = 0f;
            System.arraycopy(animPoleR, 0, poleR, 0, 3);
            poleR[3] = poleR[4] = poleR[5] = 0f;
            gripS[0] = 0.03f;
            gripS[1] = 0f;
        }
        t += d;
        timeline(d);
        head(d);
        return outPitch;
    }

    @LuaMethod(name = "knoxBiteYaw", global = true)
    public static double knoxBiteYaw() {
        return outYaw;
    }

    @LuaMethod(name = "knoxBiteEyeUp", global = true)
    public static double knoxBiteEyeUp() {
        return outUp;
    }

    @LuaMethod(name = "knoxBiteEyeAhead", global = true)
    public static double knoxBiteEyeAhead() {
        return outAhead;
    }

    @LuaMethod(name = "knoxBiteEyeLeft", global = true)
    public static double knoxBiteEyeLeft() {
        return outLeft;
    }

    // ------------------------------------------------------------------- the timeline

    /** A spring of n values (x then velocity), critically damped or near it: inertia, no jumps. */
    private static void spring(float[] s, int n, float g0, float g1, float g2, float w, float zeta, float dt) {
        // (small steps: stiff springs stay steady at a slow frame)
        int steps = Math.max(1, (int) Math.ceil(dt * w / 0.15f));
        float h = dt / steps;
        for (int k = 0; k < steps; k++) {
            for (int i = 0; i < n; i++) {
                float g = i == 0 ? g0 : i == 1 ? g1 : g2;
                float a = w * w * (g - s[i]) - 2f * zeta * w * s[n + i];
                s[n + i] += a * h;
                s[i] += s[n + i] * h;
            }
        }
    }

    private static float smooth(float a, float b, float x) {
        float k = Math.max(0f, Math.min(1f, (x - a) / (b - a)));
        return k * k * (3f - 2f * k);
    }

    /** Slow, never quite repeating: the hand and the head are never still. */
    private static float drift(float time, float seed) {
        return (float) (0.5 * Math.sin(time * 1.13 + seed) + 0.3 * Math.sin(time * 2.31 + seed * 2.7)
            + 0.2 * Math.sin(time * 0.57 + seed * 1.9));
    }

    private static void timeline(float dt) {
        boolean b = bitten;
        float done = b ? B_DONE : N_DONE;
        float end = done + SETTLE;
        // the left wrist, its elbow, its palm; how fast it goes there
        float[] goal;
        float rate = 7.5f, zeta = 0.8f;
        if (t < T_RAISE) {
            goal = RAISE;
            rate = 6.5f;
        } else if (t < T_TURN) {
            goal = ROLL;
        } else if (t < T_SEE) {
            goal = LOOK;
            rate = 5.5f;
        } else if (b) {
            if (t < B_LOWER) {
                // (pulled nearer at the sight of it, at once)
                goal = SEEN;
                rate = t < T_SEE + 0.3f ? 13f : 5f;
            } else if (t < done) {
                // (down to the sleeve's place quickly, before the right hand comes)
                goal = ROLL;
                rate = 10f;
                zeta = 0.75f;
            } else {
                goal = t < done + 0.4f ? DROP_L : animWristL;
                rate = 7f;
            }
        } else {
            if (t < N_LOWER) {
                goal = EASED;
                rate = 3.5f;
            } else if (t < done) {
                goal = ROLL;
                rate = 5f;
            } else {
                goal = t < done + 0.45f ? DROP_L : animWristL;
                rate = 6f;
            }
        }
        spring(wrist, 3, goal[0], goal[1], goal[2], rate, zeta, dt);
        wristGoal = goal;
        float[] pg = t >= done ? animPoleL : t >= T_TURN && (b ? t < B_LOWER : t < N_LOWER) ? POLE_LOOK : POLE_L;
        spring(pole, 3, pg[0], pg[1], pg[2], 6f, 0.9f, dt);
        float[] pr = rightOn ? POLE_R : animPoleR;
        spring(poleR, 3, pr[0], pr[1], pr[2], 6f, 0.9f, dt);

        // the palm: down for the sleeve, to the eyes to look, down again as it is hidden (or let be)
        if (t < 0.3f) palmMode = 0;
        else if (t < T_TURN) palmMode = 1;
        else if (b ? t < B_LOWER : t < N_LOWER) palmMode = 2;
        else if (t < done) palmMode = 1;
        else palmMode = 0;
        if (b && t >= B_LOWER && t < done) twistRate = 12f;
        else if (!b && t >= T_SEE) twistRate = 3.8f;
        else twistRate = 6.5f;

        // the right hand: to the sleeve's edge at the wrist, up the forearm; a new hold, up again
        // (or down: back to the wrist)
        float g, gr = 6f;
        boolean on;
        if (t < T_RIGHT) {
            on = false;
            g = 0.03f;
        } else if (t < T_LET) {
            on = true;
            g = t < T_TUG ? 0.03f : t < T_REGRIP ? 0.36f : t < T_TUG2 ? 0.24f : 0.62f;
            if (t >= T_REGRIP && t < T_TUG2) gr = 9f;
        } else if (b) {
            on = t >= B_GRAB && t < done;
            g = t < B_YANK ? 0.62f : t < B_REGRIP ? 0.0f : t < B_YANK2 ? 0.14f : -0.03f;
            gr = t < B_YANK ? 8f : 18f;
        } else {
            on = t >= N_GRAB && t < done;
            g = t < N_DOWN ? 0.62f : 0.0f;
            gr = t < N_DOWN ? 5f : 2.6f;
        }
        rightOn = on;
        spring(gripS, 1, g, 0f, 0f, gr, 0.9f, dt);
        wantGrip = gripS[0];

        // the weights: in quickly from the clip's pose (the springs start there), out once back in it
        wL = t < end ? Math.min(1f, wL + dt / 0.25f) : Math.max(0f, wL - dt / 0.35f);
        if (on) wR = Math.min(1f, wR + dt / 0.25f);
        else if (t >= end) wR = Math.max(0f, wR - dt / 0.35f);

        // the shiver after the sight of it, fading slowly
        fear = b && t >= T_SEE ? Math.min(1f, (t - T_SEE) / 0.25f) * (1f - 0.6f * smooth(B_DONE, B_DONE + 2f, t)) : 0f;

        // the hand never still: breath and a drift of a few millimetres, the shiver on top
        float n = 0.0035f + 0.002f * fear;
        wantL[0] = wrist[0] + n * drift(t, 0.3f);
        wantL[1] = wrist[1] + n * drift(t * 1.2f, 1.7f) + 0.002f * (float) Math.sin(t * 1.6);
        wantL[2] = wrist[2] + n * drift(t * 0.9f, 4.1f);
        if (fear > 0f) {
            float s = 0.0016f * fear;
            wantL[0] += s * (float) Math.sin(t * 57.0);
            wantL[1] += s * (float) Math.sin(t * 63.0 + 1.1);
            wantL[2] += s * (float) Math.sin(t * 51.0 + 2.3);
        }
        System.arraycopy(pole, 0, wantPoleL, 0, 3);
        System.arraycopy(poleR, 0, wantPoleR, 0, 3);

        sounds(b);
        tWas = t;

        if (t >= end && wL <= 0f && wR <= 0f && Math.abs(outPitch) < 0.15f && Math.abs(outYaw) < 0.15f
            || t > end + GIVE_UP) {
            // (he stays: his skeleton kept for the next time - knoxBiteHold)
            busy = false;
            outPitch = outYaw = outUp = outAhead = outLeft = 0f;
        }
    }

    private static boolean passed(float time) {
        return tWas < time && t >= time;
    }

    /** The sleeve's rustle at each pull, his breath at the sight of it. */
    private static void sounds(boolean b) {
        if (passed(T_RIGHT + 0.4f)) KnoxCamp.knoxCampSoundCut("", 0.12, 350);
        if (passed(T_TUG + 0.05f)) KnoxCamp.knoxCampSoundCut("", 0.2, 520);
        if (passed(T_TUG2 + 0.05f)) KnoxCamp.knoxCampSoundCut("", 0.2, 520);
        if (b) {
            if (passed(T_SEE + 0.05f)) KnoxCamp.knoxCampSoundCut(PANIC, 0.3, 4500);
            if (passed(B_YANK)) KnoxCamp.knoxCampSoundCut("", 0.3, 450);
            if (passed(B_YANK2)) KnoxCamp.knoxCampSoundCut("", 0.18, 350);
        } else {
            if (passed(T_SEE + 0.15f)) KnoxCamp.knoxCampSoundCut(RELIEF, 0.26, 1400);
            if (passed(N_DOWN + 0.05f)) KnoxCamp.knoxCampSoundCut("", 0.13, 900);
        }
    }

    /** The head after the arm: towards what the hand is at, a little late; back to rest after it. */
    private static void head(float dt) {
        boolean b = bitten;
        float done = b ? B_DONE : N_DONE;
        boolean looking = t > 0.12f && t < done + 0.15f && aimed;
        // where the eye is now (it turns about the neck)
        float ex = outLeft, ey = EYE_Y + outUp, ez = EYE_Z + outAhead;
        float gp = restPitch, gy = 0f;
        if (looking) {
            // where the arm is going, as it comes; the arm itself once it's there
            float[] g = wristGoal;
            float near = Math.max(0f, Math.min(1f, 1f - dist(wrist, g) / 0.15f));
            float ax = g[0] + AIM_OFF[0], ay = g[1] + AIM_OFF[1], az = g[2] + AIM_OFF[2];
            ax += (aim[0] - ax) * near;
            ay += (aim[1] - ay) * near;
            az += (aim[2] - az) * near;
            float dx = ax - ex, dy = ay - ey, dz = az - ez;
            gp = (float) Math.atan2(dy, Math.sqrt(dx * dx + dz * dz));
            gy = (float) Math.atan2(dx, dz);
        }
        float rate = b && t >= B_YANK && t < done ? 6f : 4.2f;
        // (held from the rest pitch: the spring holds the turn from it)
        spring(pitch, 1, gp - restPitch, 0f, 0f, rate, 0.85f, dt);
        spring(yaw, 1, gy, 0f, 0f, rate, 0.85f, dt);
        // breathing, a breath out at the quiet one's relief, quick and shallow after the bite
        float k = Math.min(1f, t / 0.6f) * (1f - smooth(done, done + SETTLE, t));
        float breath = 0.006f * (float) Math.sin(t * 1.65) + 0.002f * drift(t * 1.7f, 0.9f);
        if (!b) breath += 0.035f * smooth(T_SEE, T_SEE + 0.5f, t) * (1f - smooth(T_SEE + 0.7f, T_SEE + 1.8f, t));
        breath += fear * (0.009f * (float) Math.sin(t * 5.3) + 0.003f * (float) Math.sin(t * 13.7));
        float p = pitch[0] + breath * k;
        float y = yaw[0] + 0.003f * drift(t * 1.3f, 2.2f) * k;
        outPitch = (float) Math.toDegrees(p);
        outYaw = (float) Math.toDegrees(y);
        // the eye about the neck: down and ahead as the head bends
        float oy = EYE_Y - NECK_Y, oz = EYE_Z - NECK_Z;
        float c = (float) Math.cos(p), s = (float) Math.sin(p);
        outUp = oy * (c - 1f) + oz * s;
        outAhead = -oy * s + oz * (c - 1f);
        outLeft = oz * (float) Math.sin(y);
    }

    // ------------------------------------------------------------------- the hook

    private static long lastHook;
    private static SkinningData bonesOf;
    private static int HEAD, UPPER, L_CLAV, R_CLAV, L_UP, L_FORE, L_HAND, R_UP, R_FORE, R_HAND, R_FINGERS, R_THUMB, ROLL_A, ROLL_B;    private static final Matrix4f MA = new Matrix4f(), MB = new Matrix4f(), MC = new Matrix4f(), CL = new Matrix4f(), CR = new Matrix4f();
    private static final float[] Q = new float[9], Q2 = new float[9];
    private static final float[] S = new float[3], E = new float[3], W = new float[3], V = new float[3], T = new float[3];
    private static final float[] U0 = new float[3], H0 = new float[3], U1 = new float[3], H1 = new float[3], F1 = new float[3];
    private static final float[] PN = new float[3], G = new float[3], X = new float[3];
    private static final float[] EL = new float[3], WL = new float[3];
    private static final float[] FINGERS = new float[3], PALM_R = new float[3], GRIP_AT = new float[3];
    private static final float[] SIDE = new float[3], OFF_AT = new float[3], AWAY_AT = new float[3], COME = new float[3];

    private static int bone(SkinningData d, String name) {
        Integer i = d.boneIndices.get(name);
        return i == null ? -1 : i;
    }

    private static boolean bones(SkinningData d) {
        if (d == bonesOf) return HEAD >= 0;
        bonesOf = d;
        HEAD = bone(d, "Bip01_Head");
        UPPER = bone(d, "Bip01_Spine1");
        L_CLAV = bone(d, "Bip01_L_Clavicle");
        R_CLAV = bone(d, "Bip01_R_Clavicle");
        L_UP = bone(d, "Bip01_L_UpperArm");
        L_FORE = bone(d, "Bip01_L_Forearm");
        L_HAND = bone(d, "Bip01_L_Hand");
        R_UP = bone(d, "Bip01_R_UpperArm");
        R_FORE = bone(d, "Bip01_R_Forearm");
        R_HAND = bone(d, "Bip01_R_Hand");
        R_FINGERS = bone(d, "Bip01_R_Finger1");
        R_THUMB = bone(d, "Bip01_R_Finger0");
        ROLL_A = bone(d, "Bip01_Prop1");
        ROLL_B = bone(d, "Bip01_Prop2");
        ELBOW[0] = bone(d, "Bip01_DressFront");
        ELBOW[1] = bone(d, "Bip01_DressFront02");
        ELBOW[2] = bone(d, "Bip01_DressBack");
        ELBOW[3] = bone(d, "Bip01_DressBack02");
        if (HEAD < 0 || UPPER < 0 || L_CLAV < 0 || R_CLAV < 0 || L_UP < 0 || L_FORE < 0 || L_HAND < 0 || R_UP < 0 || R_FORE < 0 || R_HAND < 0) HEAD = -1;
        return HEAD >= 0;
    }

    /** From the hook (KnoxLook.Hook): the narrator's arms and head over his clip. */
    public static void apply(AnimationPlayer p) {
        if (p != who) return;
        try {
            pose(p);
        } catch (RuntimeException e) {
            // a skeleton not as expected: his clip's own
        }
    }

    // his space <-> the skeleton's
    private static void toSkel(float[] his, float[] out) {
        out[0] = his[0] / K;
        out[1] = his[1] / K;
        out[2] = -his[2] / K;
    }

    private static void toHis(float[] skel, float[] out) {
        out[0] = skel[0] * K;
        out[1] = skel[1] * K;
        out[2] = -skel[2] * K;
    }

    private static void pos(Matrix4f m, float[] out) {
        // (kept transposed by the game: the place is m03 m13 m23, the axes the columns of m{i}{j})
        out[0] = m.m03;
        out[1] = m.m13;
        out[2] = m.m23;
    }

    private static void axis(Matrix4f m, int j, float[] out) {
        if (j == 0) { out[0] = m.m00; out[1] = m.m10; out[2] = m.m20; }
        else if (j == 1) { out[0] = m.m01; out[1] = m.m11; out[2] = m.m21; }
        else { out[0] = m.m02; out[1] = m.m12; out[2] = m.m22; }
    }

    private static float dot(float[] a, float[] b) {
        return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    }

    private static void cross(float[] a, float[] b, float[] out) {
        float x = a[1] * b[2] - a[2] * b[1], y = a[2] * b[0] - a[0] * b[2], z = a[0] * b[1] - a[1] * b[0];
        out[0] = x;
        out[1] = y;
        out[2] = z;
    }

    private static float norm(float[] a) {
        float l = (float) Math.sqrt(dot(a, a));
        if (l > 1e-8f) {
            a[0] /= l;
            a[1] /= l;
            a[2] /= l;
        }
        return l;
    }

    private static void sub(float[] a, float[] b, float[] out) {
        out[0] = a[0] - b[0];
        out[1] = a[1] - b[1];
        out[2] = a[2] - b[2];
    }

    /** a without its part along unit u, made unit. */
    private static float across(float[] a, float[] u) {
        float k = dot(a, u);
        a[0] -= u[0] * k;
        a[1] -= u[1] * k;
        a[2] -= u[2] * k;
        return norm(a);
    }

    /** The turn by `ang` about unit k (Rodrigues; from a to b about a x b when ang > 0). */
    private static void turnOf(float kx, float ky, float kz, float ang, float[] q) {
        float c = (float) Math.cos(ang), s = (float) Math.sin(ang), v = 1f - c;
        q[0] = c + v * kx * kx;      q[1] = v * kx * ky - s * kz; q[2] = v * kx * kz + s * ky;
        q[3] = v * kx * ky + s * kz; q[4] = c + v * ky * ky;      q[5] = v * ky * kz - s * kx;
        q[6] = v * kx * kz - s * ky; q[7] = v * ky * kz + s * kx; q[8] = c + v * kz * kz;
    }

    /** The turn taking unit a to unit b by `share` of the way. */
    private static boolean between(float[] a, float[] b, float share, float[] q) {
        cross(a, b, X);
        float s = norm(X);
        float c = dot(a, b);
        if (s < 1e-6f) return false;
        turnOf(X[0], X[1], X[2], (float) Math.atan2(s, c) * share, q);
        return true;
    }

    /** Bone idx turned by q about its own place, in the model (its children with it). */
    private static void turn(AnimationPlayer p, SkinningData d, int idx, float[] q, float scale) {
        SkinningBone b = d.getBoneAt(idx);
        if (b == null || b.parent == null || idx >= p.boneTransforms.length) return;
        Matrix4f m = p.getBoneModelTransform(idx, MA);
        float a00 = m.m00, a01 = m.m01, a02 = m.m02, a10 = m.m10, a11 = m.m11, a12 = m.m12, a20 = m.m20, a21 = m.m21, a22 = m.m22;
        m.m00 = (q[0] * a00 + q[1] * a10 + q[2] * a20) * scale;
        m.m01 = (q[0] * a01 + q[1] * a11 + q[2] * a21) * scale;
        m.m02 = (q[0] * a02 + q[1] * a12 + q[2] * a22) * scale;
        m.m10 = (q[3] * a00 + q[4] * a10 + q[5] * a20) * scale;
        m.m11 = (q[3] * a01 + q[4] * a11 + q[5] * a21) * scale;
        m.m12 = (q[3] * a02 + q[4] * a12 + q[5] * a22) * scale;
        m.m20 = (q[6] * a00 + q[7] * a10 + q[8] * a20) * scale;
        m.m21 = (q[6] * a01 + q[7] * a11 + q[8] * a21) * scale;
        m.m22 = (q[6] * a02 + q[7] * a12 + q[8] * a22) * scale;
        Matrix4f parent = p.getBoneModelTransform(b.parent.index, MB);
        if (Matrix4f.invert(parent, MC) == null) return;
        p.boneTransforms[idx].mul(m, MC);
    }

    private static final float[] NONE = {1, 0, 0, 0, 1, 0, 0, 0, 1};

    /** Bone idx put where `model` has it in the model, made local to its parent as it is now. */
    private static void place(AnimationPlayer p, SkinningData d, int idx, Matrix4f model) {
        SkinningBone b = d.getBoneAt(idx);
        if (b == null || b.parent == null || idx >= p.boneTransforms.length) return;
        if (Matrix4f.invert(p.getBoneModelTransform(b.parent.index, MB), MC) == null) return;
        p.boneTransforms[idx].mul(model, MC);
    }

    private static void at(AnimationPlayer p, int idx, float[] out) {
        pos(p.getBoneModelTransform(idx, MA), out);
    }

    /** Where the clip has an arm, in his space: the wrist, and the elbow's way off the shoulder-wrist line. */
    private static void readArm(AnimationPlayer p, int up, int fore, int hand, float[] wristOut, float[] poleOut) {
        at(p, up, S);
        at(p, fore, E);
        at(p, hand, W);
        toHis(W, wristOut);
        sub(W, S, V);
        norm(V);
        sub(E, S, G);
        if (across(G, V) < 1e-6f) { G[0] = 0f; G[1] = -1f; G[2] = 0f; }
        toHis(G, poleOut);
        norm(poleOut);
    }

    private static void pose(AnimationPlayer p) {
        SkinningData d = p.getSkinningData();
        if (d == null || d.boneIndices == null || p.boneTransforms == null || !bones(d)) return;
        long now = System.nanoTime();
        float dt = lastHook == 0L ? 1f / 60f : Math.max(0f, Math.min(0.05f, (now - lastHook) * 1e-9f));
        lastHook = now;

        // his chest, neck and head away (the camera looks over where they were), the arms where the
        // clip has them: their collarbones put back as they were
        p.getBoneModelTransform(L_CLAV, CL);
        p.getBoneModelTransform(R_CLAV, CR);
        turn(p, d, UPPER, NONE, HIDDEN);
        place(p, d, L_CLAV, CL);
        place(p, d, R_CLAV, CR);
        twistedL = 0f;
        if (busy) arms(p, d, dt);
        // his hands smaller, the fingers with them - the game's, this near, are giant (the author,
        // 2026-11-02; smaller still 2026-11-03); after the arms, whose turns take the hands' axes as
        // unit ones. (The arms narrowed by their bones were odd at the elbows: his body's arms are
        // narrower in its mesh instead - BODY.)
        turn(p, d, L_HAND, NONE, HANDS);
        turn(p, d, R_HAND, NONE, HANDS);
        sleeve(p, d, dt);
        openElbow(p, d, L_UP, L_FORE, L_HAND);
        openElbow(p, d, R_UP, R_FORE, R_HAND);
        elbows(p, d);
        if (busy) {
            view();
            tuck(p, d, L_UP, L_FORE);
            tuck(p, d, R_UP, R_FORE);
        }
    }

    private static final float HANDS = 0.7f;
    private static final float HOLD_RATE = 4f, R_TURN_RATE = 9f;   // the right hand closing on the sleeve, 1/s; its forearm's turn

    private static void arms(AnimationPlayer p, SkinningData d, float dt) {
        readArm(p, L_UP, L_FORE, L_HAND, animWristL, animPoleL);
        readArm(p, R_UP, R_FORE, R_HAND, animWristR, animPoleR);
        if (!read) {
            read = true;
            System.arraycopy(animWristR, 0, wristR, 0, 3);
            wristR[3] = wristR[4] = wristR[5] = 0f;
            return;
        }
        float wl = wL, wr = wR;
        if (wl <= 0f) return;

        // the left arm: to the wrist the springs have, the elbow down and out
        toSkel(wantL, T);
        lerpFromClip(p, L_HAND, T, wl);
        toSkel(wantPoleL, G);
        reach(p, d, L_UP, L_FORE, L_HAND, T, G);
        float[] palm = null;
        if (palmMode == 1) {
            toSkel(PALM_DOWN, PN);
            palm = PN;
        } else if (palmMode == 2) {
            // the inside of the forearm to the eye
            at(p, L_FORE, E);
            at(p, L_HAND, W);
            V[0] = outLeft;
            V[1] = EYE_Y + outUp;
            V[2] = EYE_Z + outAhead;
            toSkel(V, PN);
            for (int i = 0; i < 3; i++) PN[i] -= (E[i] + W[i]) * 0.5f;
            palm = PN;
        }
        twist(p, d, L_FORE, L_HAND, palm, twistL, 1f, 0f, dt);
        straighten(p, d, L_HAND, L_FORE, 0.8f * wl);

        // what the eyes go to: the forearm a little up from its middle, towards the grip while the
        // right hand works
        at(p, L_FORE, EL);
        at(p, L_HAND, WL);
        float gs = wantGrip;
        for (int i = 0; i < 3; i++) V[i] = EL[i] + (WL[i] - EL[i]) * 0.58f;
        if (wr > 0f && rightOn) {
            float k = 0.3f;
            for (int i = 0; i < 3; i++) V[i] += ((WL[i] + (EL[i] - WL[i]) * gs) - V[i]) * k;
        }
        toHis(V, aim);
        aimed = true;

        if (wr <= 0f) return;
        // the right hand: on the forearm's near top side, whichever way it is turned - it comes from
        // below, his right, the fingers along the forearm to the elbow and over it, the wrist near
        // straight (the author's video, 2026-11-02: the hand bent hard down over the top, its forearm
        // across the left one; tools/bite/arms_check.py)
        sub(WL, EL, F1);
        norm(F1);
        G[0] = 0f;
        G[1] = 1f;
        G[2] = 0f;
        if (across(G, F1) < 1e-6f) { G[0] = 0f; G[1] = 0f; G[2] = -1f; }
        // (his front: the skeleton's -z)
        cross(F1, G, X);
        if (X[2] > 0f) { X[0] = -X[0]; X[1] = -X[1]; X[2] = -X[2]; }
        float[] fingers = FINGERS, palmR = PALM_R, side = SIDE;
        for (int i = 0; i < 3; i++) side[i] = G[i] * 0.5f - X[i] * 0.9f;
        norm(side);
        for (int i = 0; i < 3; i++) fingers[i] = -F1[i] * 0.6f + G[i] * 0.6f + X[i] * 0.3f;
        norm(fingers);
        float k = dot(fingers, side) * 0.5f;
        for (int i = 0; i < 3; i++) fingers[i] -= side[i] * k;
        norm(fingers);
        for (int i = 0; i < 3; i++) palmR[i] = -side[i];
        across(palmR, fingers);
        float off = sleeveR(gs, roll) + PALM_OVER, back = PALM_FROM_WRIST / K, lift = LIFT / K;
        for (int i = 0; i < 3; i++) T[i] = WL[i] + (EL[i] - WL[i]) * gs + side[i] * off - fingers[i] * back;
        toHis(T, GRIP_AT);
        for (int i = 0; i < 3; i++) V[i] = T[i] + side[i] * lift;
        toHis(V, OFF_AT);
        // (letting go it goes towards him and down, not up off the top: up, its forearm stood on end
        // and the hand with it - the author's video, 2026-11-02)
        for (int i = 0; i < 3; i++) V[i] = -X[i] * 0.85f - G[i] * 0.5f;
        norm(V);
        for (int i = 0; i < 3; i++) V[i] = T[i] + V[i] * lift;
        toHis(V, AWAY_AT);
        // its spring (his space): onto the sleeve from off its side, closing in as it comes; off it
        // again the same way when it lets go, then down
        float[] go;
        if (rightOn) {
            wasOn = true;
            float c = Math.max(0f, Math.min(1f, (dist(wristR, GRIP_AT) - 0.02f) / 0.1f));
            for (int i = 0; i < 3; i++) COME[i] = GRIP_AT[i] + (OFF_AT[i] - GRIP_AT[i]) * c;
            go = COME;
        } else {
            if (wasOn) {
                wasOn = false;
                if (holdR > 0.3f) {
                    System.arraycopy(AWAY_AT, 0, LET, 0, 3);
                    letUntil = t + LET_GO;
                }
            }
            if (t < letUntil) go = LET;
            else if (t < (bitten ? B_DONE : N_DONE)) go = PARK_R;
            else go = wristR[1] > 0.9f && wristR[2] > 0.1f ? DROP_R : animWristR;
        }
        // (once it has hold of the sleeve it keeps it, through the quick pulls too)
        float close = Math.max(0f, Math.min(1f, 1f - (dist(wristR, GRIP_AT) - 0.015f) / 0.08f));
        float holdGoal = !rightOn ? 0f : holdR > 0.5f || close > 0.9f ? 1f : close;
        // (the hand keeps its shape a while going away, easing open on the way down)
        float ease = !rightOn && t < letUntil ? 2.5f : 6f;
        holdR += Math.max(-dt * ease, Math.min(dt * HOLD_RATE, holdGoal - holdR));
        float stiff = rightOn && holdR > 0.5f ? 22f : 10f;
        spring(wristR, 3, go[0], go[1], go[2], stiff, 0.85f, dt);
        toSkel(wristR, T);
        lerpFromClip(p, R_HAND, T, wr);
        toSkel(wantPoleR, G);
        reach(p, d, R_UP, R_FORE, R_HAND, T, G);
        float hold = holdR;
        // (the forearm turns the hand to the sleeve, ahead of it: a wrist bends but doesn't turn about
        // itself - the hand alone was wrung some 100 degrees at the grab, the author's screenshot,
        // 2026-11-04; and as quick in the slow quiet one)
        float turnRate = twistRate;
        twistRate = Math.max(turnRate, R_TURN_RATE);
        twist(p, d, R_FORE, R_HAND, rightOn || hold > 0.05f ? palmR : null, twistR, -1f, 0f, dt);
        twistRate = turnRate;
        straighten(p, d, R_HAND, R_FORE, 0.6f * wr);
        if (hold > 0f) {
            orient(p, d, R_HAND, fingers, palmR, hold * wr);
            // (round the cloth, not into it: the author's video, 2026-11-03 - a finger through the sleeve)
            curl(p, d, R_FINGERS, R_HAND, 0.7f * hold * wr);
            curl(p, d, R_THUMB, R_HAND, 0.35f * hold * wr);
        }
    }

    // ------------------------------------------------------------------- the sleeve

    /**
     * The left sleeve's last rings, each set on a bone of its own bound as the forearm is
     * (tools/bite/roll_sleeve.py; the props', nothing else is worn on them): rolled all the way, the
     * ring about s0 (elbow 0, wrist 1) goes to s1, the rings spread b times about it, b times as wide.
     * Ring A the padding bunched above, B the cuff - to the middle of the forearm.
     */
    private static final float[] ROLL_A_IS = {0.62f, 0.40f, 0.5f, 1.32f}, ROLL_B_IS = {0.95f, 0.47f, 1.4f, 1.42f};
    // the right hand's place on the forearm (0 the wrist .. 1 the elbow) that has the cuff all the way up
    private static final float CUFF_AT = 0.03f, CUFF_UP = 0.45f;
    private static float roll, rollGoal;         // how far it is rolled, 0..1
    private static final Matrix4f MD = new Matrix4f();
    private static final float[] AX = new float[3];

    /** The sleeve where the right hand has it: up as it pulls, down as it pulls the other way. */
    private static void sleeve(AnimationPlayer p, SkinningData d, float dt) {
        if (ROLL_A < 0 || ROLL_B < 0) return;
        if (busy && started) {
            boolean b = bitten;
            float done = b ? B_DONE : N_DONE;
            float k = Math.max(0f, Math.min(1f, (wantGrip - CUFF_AT) / (CUFF_UP - CUFF_AT)));
            boolean held = holdR > 0.5f;
            // (held up as the hand takes a new hold lower; down only by the hand, or of itself once let go)
            if (t < T_LET + 0.3f) {
                if (held && k > rollGoal) rollGoal = k;
            } else if (t >= (b ? B_GRAB : N_GRAB) && t < done) {
                if (held && k < rollGoal) rollGoal = k;
            } else if (t >= done) {
                rollGoal = 0f;
            }
        } else {
            rollGoal = 0f;
        }
        // (the cloth after the hand, a touch late; sliding down of itself slower)
        float rate = rollGoal >= roll ? 9f : busy ? 9f : 2.5f;
        roll += (rollGoal - roll) * Math.min(1f, dt * rate);
        if (roll < 1e-4f) roll = 0f;
        ring(p, d, ROLL_A, ROLL_A_IS, roll);
        ring(p, d, ROLL_B, ROLL_B_IS, roll);
    }

    /** One set of rings: the forearm's own place, slid up it and widened by k of the way. */
    private static void ring(AnimationPlayer p, SkinningData d, int idx, float[] is, float k) {
        // the forearm's way to the wrist in its own frame (the hand's place in it)
        Matrix4f f = p.getBoneModelTransform(L_FORE, MA);
        if (Matrix4f.invert(f, MC) == null) return;
        at(p, L_HAND, W);
        for (int i = 0; i < 3; i++) {
            AX[i] = (i == 0 ? MC.m00 : i == 1 ? MC.m10 : MC.m20) * W[0] + (i == 0 ? MC.m01 : i == 1 ? MC.m11 : MC.m21) * W[1]
                + (i == 0 ? MC.m02 : i == 1 ? MC.m12 : MC.m22) * W[2] + (i == 0 ? MC.m03 : i == 1 ? MC.m13 : MC.m23);
        }
        float len = norm(AX);
        if (len < 1e-6f) return;
        // R = a uu' + c (I - uu'), moved t along u; the bone's place = the forearm's x R
        float a = 1f + k * (is[2] - 1f), c = 1f + k * (is[3] - 1f), tr = k * len * (is[1] - is[2] * is[0]);
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) Q[i * 3 + j] = (a - c) * AX[i] * AX[j] + (i == j ? c : 0f);
        }
        f = p.getBoneModelTransform(L_FORE, MA);
        float f00 = f.m00, f01 = f.m01, f02 = f.m02, f10 = f.m10, f11 = f.m11, f12 = f.m12, f20 = f.m20, f21 = f.m21, f22 = f.m22;
        MD.setIdentity();
        MD.m00 = f00 * Q[0] + f01 * Q[3] + f02 * Q[6];
        MD.m01 = f00 * Q[1] + f01 * Q[4] + f02 * Q[7];
        MD.m02 = f00 * Q[2] + f01 * Q[5] + f02 * Q[8];
        MD.m10 = f10 * Q[0] + f11 * Q[3] + f12 * Q[6];
        MD.m11 = f10 * Q[1] + f11 * Q[4] + f12 * Q[7];
        MD.m12 = f10 * Q[2] + f11 * Q[5] + f12 * Q[8];
        MD.m20 = f20 * Q[0] + f21 * Q[3] + f22 * Q[6];
        MD.m21 = f20 * Q[1] + f21 * Q[4] + f22 * Q[7];
        MD.m22 = f20 * Q[2] + f21 * Q[5] + f22 * Q[8];
        MD.m03 = f.m03 + tr * (f00 * AX[0] + f01 * AX[1] + f02 * AX[2]);
        MD.m13 = f.m13 + tr * (f10 * AX[0] + f11 * AX[1] + f12 * AX[2]);
        MD.m23 = f.m23 + tr * (f20 * AX[0] + f21 * AX[1] + f22 * AX[2]);
        place(p, d, idx, MD);
    }

    // ------------------------------------------------------------------- the shoulders

    // No shoulders in the picture (the author, 2026-11-04: "вообще не нравятся как выглядят плечи ... чтобы
    // их было не видно"), the rest of the moment as it was. The arms are reached as ever, then each elbow
    // opened to ELBOW_OPEN at least, by the upper arm alone, in the arm's own bend: its far end leaves
    // the view, the sleeves' tops plain tubes past it (tools/bite/slim_arms.py: shoulder_tube). Lowered
    // joints took the forearms elsewhere (jar 126); swung to a fixed place, the elbow bent the wrong
    // way (jar 127). Picked by the author from pictures, 2026-11-04 (.claude/mockups, variant В).
    private static final float ELBOW_OPEN = (float) Math.toRadians(150);
    private static final Matrix4f FORE_AT = new Matrix4f(), UP_AT = new Matrix4f();
    private static final float[] CL0 = new float[3], CL1 = new float[3];

    private static void openElbow(AnimationPlayer p, SkinningData d, int up, int fore, int hand) {
        p.getBoneModelTransform(fore, FORE_AT);
        p.getBoneModelTransform(up, UP_AT);
        pos(FORE_AT, E);
        pos(UP_AT, S);
        at(p, hand, W);
        sub(S, E, CL0);
        sub(W, E, CL1);
        if (norm(CL0) < 1e-6f || norm(CL1) < 1e-6f) return;
        float a = dist(S, E);
        cross(CL0, CL1, X);
        float sn = norm(X), ang = (float) Math.atan2(sn, dot(CL0, CL1));
        if (sn < 1e-6f || ang >= ELBOW_OPEN) return;
        turnOf(X[0], X[1], X[2], ang - ELBOW_OPEN, Q);
        rot(UP_AT, RK);
        mul3(Q, RK, RS);
        UP_AT.m00 = RS[0]; UP_AT.m01 = RS[1]; UP_AT.m02 = RS[2];
        UP_AT.m10 = RS[3]; UP_AT.m11 = RS[4]; UP_AT.m12 = RS[5];
        UP_AT.m20 = RS[6]; UP_AT.m21 = RS[7]; UP_AT.m22 = RS[8];
        UP_AT.m03 = E[0] + a * (Q[0] * CL0[0] + Q[1] * CL0[1] + Q[2] * CL0[2]);
        UP_AT.m13 = E[1] + a * (Q[3] * CL0[0] + Q[4] * CL0[1] + Q[5] * CL0[2]);
        UP_AT.m23 = E[2] + a * (Q[6] * CL0[0] + Q[7] * CL0[1] + Q[8] * CL0[2]);
        place(p, d, up, UP_AT);
        place(p, d, fore, FORE_AT);
    }

    // The sleeve's top goes on past the shoulder (SLEEVE_REACH upper arms from the elbow) to leave the
    // view from a bent arm; from a hanging one it stood up into the picture, at the start and the end
    // of the moment (the author's screenshot, 2026-11-04: "видно плечи, которые появляются слева и
    // справа"). While its end would be seen and the elbow isn't, the upper arm is drawn smaller about
    // the elbow, its end just out of the view: nothing that is seen moves. Evenly, as the chest is.
    private static final float SLEEVE_REACH = 2.3f;   // tools/bite/slim_arms.py: TUBE_END
    private static final float VIEW_TAN = (float) Math.tan(Math.toRadians(16));   // half the bar's FOV
    private static final float VIEW_MARGIN = 0.10f;   // (his space) the sleeve's width and a little
    private static final float TUCK_LEAST = 0.1f;
    private static final float[] VE = new float[3], VF = new float[3], VR = new float[3], VU = new float[3];
    private static final float[] REACH_D = new float[3], SK = new float[3], PT = new float[3];
    private static float viewWide;

    /** The view as Lua has it this frame (his space; KnoxMenuSceneBar: viewOffset). */
    private static void view() {
        float pt = restPitch + (float) Math.toRadians(outPitch), yw = (float) Math.toRadians(outYaw);
        float cp = (float) Math.cos(pt);
        VE[0] = outLeft;
        VE[1] = EYE_Y + outUp;
        VE[2] = EYE_Z + outAhead;
        VF[0] = cp * (float) Math.sin(yw);
        VF[1] = (float) Math.sin(pt);
        VF[2] = cp * (float) Math.cos(yw);
        VR[0] = VF[2];
        VR[1] = 0f;
        VR[2] = -VF[0];
        norm(VR);
        cross(VF, VR, VU);
        zombie.core.Core c = zombie.core.Core.getInstance();
        viewWide = VIEW_TAN * c.getScreenWidth() / Math.max(1, c.getScreenHeight());
    }

    /** Is this skeleton's place in the picture, near enough? */
    private static boolean inView(float[] skel) {
        toHis(skel, PT);
        sub(PT, VE, PT);
        float z = dot(PT, VF);
        return z >= 0.02f && Math.abs(dot(PT, VR)) < viewWide * z + VIEW_MARGIN && Math.abs(dot(PT, VU)) < VIEW_TAN * z + VIEW_MARGIN;
    }

    private static void tuck(AnimationPlayer p, SkinningData d, int up, int fore) {
        p.getBoneModelTransform(fore, FORE_AT);
        p.getBoneModelTransform(up, UP_AT);
        pos(FORE_AT, E);
        pos(UP_AT, S);
        sub(S, E, REACH_D);
        for (int i = 0; i < 3; i++) SK[i] = E[i] + REACH_D[i] * SLEEVE_REACH;
        if (!inView(SK) || inView(E)) return;
        float lo = 0f, hi = 1f;
        for (int n = 0; n < 8; n++) {
            float m = (lo + hi) * 0.5f;
            for (int i = 0; i < 3; i++) SK[i] = E[i] + REACH_D[i] * SLEEVE_REACH * m;
            if (inView(SK)) hi = m;
            else lo = m;
        }
        float k = Math.max(TUCK_LEAST, lo);
        UP_AT.m00 *= k; UP_AT.m01 *= k; UP_AT.m02 *= k;
        UP_AT.m10 *= k; UP_AT.m11 *= k; UP_AT.m12 *= k;
        UP_AT.m20 *= k; UP_AT.m21 *= k; UP_AT.m22 *= k;
        UP_AT.m03 = E[0] + REACH_D[0] * k;
        UP_AT.m13 = E[1] + REACH_D[1] * k;
        UP_AT.m23 = E[2] + REACH_D[2] * k;
        place(p, d, up, UP_AT);
        place(p, d, fore, FORE_AT);
    }

    // ------------------------------------------------------------------- the left elbow

    /**
     * The left elbow's helpers (the author 2026-11-03: "куртка до сих пор сужается в районе локтя, плюс
     * имеет дыры"): the forearm turned about itself up to 170 degrees as he looks at it, and a point at
     * the elbow blended between the upper arm and the forearm was drawn in to near nothing. His body
     * and the jacket (tools/bite/slim_arms.py: bend_weights) have the elbow on four bones more - the
     * dress's, nothing of his wears them - each a step from the upper arm to the forearm: SWING_SHARE
     * of the elbow's bend (over the first three, by the elbow), TWIST_SHARE of the forearm's turn
     * about itself (down to the middle of the forearm, as a forearm turns). Put each frame, at the
     * elbow (the clip's are by his hips). The same shares as slim_arms.py's.
     */
    private static final float[] SWING_SHARE = {1f / 3f, 2f / 3f, 1f, 1f};
    private static final float[] TWIST_SHARE = {0.2f, 0.4f, 0.6f, 0.8f};
    private static final int[] ELBOW = new int[4];
    private static float twistedL;               // the left forearm's turn about itself this frame (twist)
    private static final float[] RU = new float[9], RS = new float[9], RK = new float[9];

    private static void elbows(AnimationPlayer p, SkinningData d) {
        if (ELBOW[0] < 0) return;
        rot(p.getBoneModelTransform(L_UP, MA), RU);
        Matrix4f f = p.getBoneModelTransform(L_FORE, MB);
        at(p, L_HAND, W);
        pos(f, E);
        sub(W, E, F1);
        if (norm(F1) < 1e-6f) return;
        // the forearm without its turn about itself; the bend from the upper arm to it (RS)
        turnOf(F1[0], F1[1], F1[2], -twistedL, Q);
        rot(f, RK);
        mul3(Q, RK, RS);
        mul3t(RS, RU, RK);
        // its axis and angle
        float ax = RK[7] - RK[5], ay = RK[2] - RK[6], az = RK[3] - RK[1];
        float s = (float) Math.sqrt(ax * ax + ay * ay + az * az);
        float ang = (float) Math.atan2(s, RK[0] + RK[4] + RK[8] - 1f);
        if (s > 1e-6f) { ax /= s; ay /= s; az /= s; } else { ax = 1f; ay = 0f; az = 0f; ang = 0f; }
        for (int k = 0; k < 4; k++) {
            if (ELBOW[k] < 0) continue;
            turnOf(ax, ay, az, ang * SWING_SHARE[k], Q2);
            mul3(Q2, RU, RS);
            turnOf(F1[0], F1[1], F1[2], twistedL * TWIST_SHARE[k], Q);
            mul3(Q, RS, RK);
            MD.setIdentity();
            MD.m00 = RK[0]; MD.m01 = RK[1]; MD.m02 = RK[2];
            MD.m10 = RK[3]; MD.m11 = RK[4]; MD.m12 = RK[5];
            MD.m20 = RK[6]; MD.m21 = RK[7]; MD.m22 = RK[8];
            MD.m03 = E[0]; MD.m13 = E[1]; MD.m23 = E[2];
            // (in the skeleton's order: each one's parent put first)
            place(p, d, ELBOW[k], MD);
        }
    }

    /** A bone's turn in the model (its axes the columns), row by row. */
    private static void rot(Matrix4f m, float[] r) {
        r[0] = m.m00; r[1] = m.m01; r[2] = m.m02;
        r[3] = m.m10; r[4] = m.m11; r[5] = m.m12;
        r[6] = m.m20; r[7] = m.m21; r[8] = m.m22;
    }

    /** out = a b (3x3, row by row; out not a or b). */
    private static void mul3(float[] a, float[] b, float[] out) {
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) out[i * 3 + j] = a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j];
        }
    }

    /** out = a b' (3x3, row by row; out not a or b). */
    private static void mul3t(float[] a, float[] b, float[] out) {
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) out[i * 3 + j] = a[i * 3] * b[j * 3] + a[i * 3 + 1] * b[j * 3 + 1] + a[i * 3 + 2] * b[j * 3 + 2];
        }
    }

    /** SLEEVE_R where the hand is (`at`: wrist 0 .. elbow 1) and as far as it is rolled (0..1). */
    private static float sleeveR(float at, float rolled) {
        float x = Math.max(0f, Math.min(10f, at * 10f)), y = Math.max(0f, Math.min(4f, rolled * 4f));
        int i = Math.min(9, (int) x), j = Math.min(3, (int) y);
        float fx = x - i, fy = y - j;
        float a = SLEEVE_R[j * 11 + i] + (SLEEVE_R[j * 11 + i + 1] - SLEEVE_R[j * 11 + i]) * fx;
        float b = SLEEVE_R[(j + 1) * 11 + i] + (SLEEVE_R[(j + 1) * 11 + i + 1] - SLEEVE_R[(j + 1) * 11 + i]) * fx;
        return a + (b - a) * fy;
    }

    private static float dist(float[] a, float[] b) {
        float x = a[0] - b[0], y = a[1] - b[1], z = a[2] - b[2];
        return (float) Math.sqrt(x * x + y * y + z * z);
    }

    /** Target t taken `w` of the way from where the clip has the hand. */
    private static void lerpFromClip(AnimationPlayer p, int hand, float[] t, float w) {
        if (w >= 1f) return;
        at(p, hand, W);
        for (int i = 0; i < 3; i++) t[i] = W[i] + (t[i] - W[i]) * w;
    }

    /**
     * Two bones to put the wrist at t (skeleton's space), the elbow towards `poleDir`. The elbow
     * bends as one: about the upper arm's own y (the clip's hinge - Bob_Idle, 2026-11-02), the arm's
     * plane kept on it, so it never bends sideways or turns on a pivot.
     */
    private static void reach(AnimationPlayer p, SkinningData d, int up, int fore, int hand, float[] t, float[] poleDir) {
        at(p, up, S);
        at(p, fore, E);
        at(p, hand, W);
        float a = dist(E, S), b = dist(W, E);
        sub(t, S, V);
        float to = norm(V);
        // (never quite straight: the hinge's plane stays known)
        float reachMax = (a + b) * 0.97f, reachMin = Math.abs(a - b) + 0.02f * (a + b);
        float dd = Math.max(reachMin, Math.min(reachMax, to));
        float cosA = (a * a + dd * dd - b * b) / (2f * a * dd);
        float sinA = (float) Math.sqrt(Math.max(0f, 1f - cosA * cosA));
        G[0] = poleDir[0]; G[1] = poleDir[1]; G[2] = poleDir[2];
        if (across(G, V) < 1e-6f) return;
        // the new elbow, the forearm's way to the (reachable) wrist
        float ex = S[0] + V[0] * a * cosA + G[0] * a * sinA;
        float ey = S[1] + V[1] * a * cosA + G[1] * a * sinA;
        float ez = S[2] + V[2] * a * cosA + G[2] * a * sinA;
        U1[0] = ex - S[0]; U1[1] = ey - S[1]; U1[2] = ez - S[2];
        norm(U1);
        F1[0] = S[0] + V[0] * dd - ex; F1[1] = S[1] + V[1] * dd - ey; F1[2] = S[2] + V[2] * dd - ez;
        norm(F1);
        cross(U1, F1, H1);
        if (norm(H1) < 1e-4f) return;
        // the upper arm: its long axis and its hinge (y) onto the new ones
        Matrix4f m = p.getBoneModelTransform(up, MA);
        sub(E, S, U0);
        norm(U0);
        axis(m, 1, H0);
        if (across(H0, U0) < 1e-6f) return;
        cross(U0, H0, X);   // (the third axes)
        float w0x = X[0], w0y = X[1], w0z = X[2];
        cross(U1, H1, X);
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                float w0 = j == 0 ? w0x : j == 1 ? w0y : w0z;
                Q[i * 3 + j] = U1[i] * U0[j] + H1[i] * H0[j] + X[i] * w0;
            }
        }
        turn(p, d, up, Q, 1f);
        // the forearm: from where it now points to the wrist (about the hinge, near enough)
        at(p, fore, E);
        at(p, hand, W);
        sub(W, E, U0);
        norm(U0);
        if (between(U0, F1, 1f, Q)) turn(p, d, fore, Q, 1f);
    }

    /**
     * A forearm turned about itself so its palm (the hand's z) faces `want` (skeleton's space; null:
     * `rest` radians from the clip's own), on a spring; never further than a forearm turns (side +1
     * the left, -1 the right).
     */
    private static void twist(AnimationPlayer p, SkinningData d, int fore, int hand, float[] want, float[] state, float side,
                              float rest, float dt) {
        at(p, fore, E);
        at(p, hand, W);
        sub(W, E, F1);
        norm(F1);
        float goal = rest;
        if (want != null) {
            // (want may be PN itself: taken first)
            G[0] = want[0]; G[1] = want[1]; G[2] = want[2];
            norm(G);
            axis(p.getBoneModelTransform(hand, MA), 2, PN);
            // (a palm's way along the forearm says nothing of its turn: held where it is)
            goal = state[0];
            if (across(PN, F1) > 1e-6f && across(G, F1) > 0.35f) {
                cross(PN, G, X);
                goal = (float) Math.atan2(dot(F1, X), dot(PN, G));
                // the way round a forearm can go: from where it is, within its turn
                float lo = side > 0 ? -PRONATE : -SUPINATE, hi = side > 0 ? SUPINATE : PRONATE;
                float best = Float.NaN;
                for (int k = -1; k <= 1; k++) {
                    float c = goal + k * (float) (2 * Math.PI);
                    if (c < lo || c > hi) continue;
                    if (Float.isNaN(best) || Math.abs(c - state[0]) < Math.abs(best - state[0])) best = c;
                }
                goal = Float.isNaN(best) ? Math.max(lo, Math.min(hi, goal)) : best;
            }
        }
        goal += 0.035f * drift(t * 1.1f, side * 3f);
        spring(state, 1, goal, 0f, 0f, twistRate, 0.85f, dt);
        turnOf(F1[0], F1[1], F1[2], state[0], Q);
        turn(p, d, fore, Q, 1f);
        if (fore == L_FORE) twistedL = state[0];
    }

    /** The hand's fingers (its x) brought `share` of the way to along its forearm. */
    private static void straighten(AnimationPlayer p, SkinningData d, int hand, int fore, float share) {
        if (share <= 0f) return;
        at(p, fore, E);
        at(p, hand, W);
        sub(W, E, F1);
        norm(F1);
        axis(p.getBoneModelTransform(hand, MA), 0, U0);
        norm(U0);
        if (between(U0, F1, share, Q)) turn(p, d, hand, Q, 1f);
    }

    /** The hand's fingers and palm (its x and z) brought `share` of the way to these. */
    private static void orient(AnimationPlayer p, SkinningData d, int hand, float[] fingers, float[] palm, float share) {
        Matrix4f m = p.getBoneModelTransform(hand, MA);
        axis(m, 0, U0);
        axis(m, 2, H0);
        // the turn from the hand's frame now to the wanted one: [x, z x x, z] each
        cross(H0, U0, X);
        float n0x = X[0], n0y = X[1], n0z = X[2];
        cross(palm, fingers, X);
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                float n0 = j == 0 ? n0x : j == 1 ? n0y : n0z;
                Q2[i * 3 + j] = fingers[i] * U0[j] + X[i] * n0 + palm[i] * H0[j];
            }
        }
        // its axis and angle, the angle taken by share
        float c = Math.max(-1f, Math.min(1f, (Q2[0] + Q2[4] + Q2[8] - 1f) * 0.5f));
        V[0] = Q2[7] - Q2[5];
        V[1] = Q2[2] - Q2[6];
        V[2] = Q2[3] - Q2[1];
        if (norm(V) < 1e-6f) return;
        turnOf(V[0], V[1], V[2], (float) Math.acos(c) * share, Q);
        turn(p, d, hand, Q, 1f);
    }

    /** Fingers closed round what the palm holds: turned from along the hand towards its palm. */
    private static void curl(AnimationPlayer p, SkinningData d, int finger, int hand, float angle) {
        if (finger < 0 || angle <= 0f) return;
        Matrix4f m = p.getBoneModelTransform(hand, MA);
        axis(m, 2, H0);
        axis(p.getBoneModelTransform(finger, MA), 0, U0);
        norm(U0);
        cross(U0, H0, X);
        if (norm(X) < 1e-6f) return;
        turnOf(X[0], X[1], X[2], angle, Q);
        turn(p, d, finger, Q, 1f);
    }
}
