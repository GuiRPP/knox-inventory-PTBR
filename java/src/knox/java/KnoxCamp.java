package knox.java;

import java.util.Random;

import fmod.fmod.FMODManager;
import se.krka.kahlua.integration.annotations.LuaMethod;

/**
 * The camp's sounds of the main menu (KnoxMenuScene.lua), and the hero's
 * steps as he walks off into a save (the author's idea, 2026-10-15).
 *
 * The fire, the night forest and the wind loop while the camp is up. When a
 * hero gets up and walks off, his steps on the grass go with his walk (Lua
 * plays each as a foot comes down, at the clip's own footstep times). Once the
 * screen is black and the save loads, he walks on into the dark a moment, his
 * steps dying away; the camp dies out behind him over the loading screen - the
 * fire first, the wind last - and what is left of it goes when the world has
 * loaded. Over the loading screen Lua sleeps: it is kept going by each of its
 * frames (KnoxLoading's patch of its render).
 *
 * (A whole way was tried - bushes, a road, wooden steps, a door at the end -
 * and dropped by the author the same day: it says the hero arrives at a house,
 * and a save may start anywhere - in a car, in the woods.)
 *
 * The loops are the game's recordings in media/sound, played as it plays its
 * file sounds (at the volumes the sound scripts had). The steps are heavy boots
 * on a forest floor (Artlist, Immersive Foley "Heavy Boots Collection Vol 2",
 * cut into single steps) in Knox's media/sound/knox_steps: the game's own grass
 * steps sounded muffled, Kenney's CC0 ones didn't suit, and its FMOD footsteps
 * are silent outside the game (its mixer keeps in-game sounds quiet in the menu).
 *
 * All of it runs on the main thread (Lua's calls and the loading screen's
 * render): no thread of our own touches FMOD.
 */
public class KnoxCamp {

    // the loops: the fire, the night forest, the wind, and a cricket close by in
    // the grass (asked for, 2026-10-16)
    static final String[] LOOP_FILE = {
        "media/sound/PZ_Fire.wav", "media/sound/ambientOutsideCricketsOwlNight.wav", "media/sound/ambientOutsideWindyNight.wav",
        "media/sound/Cricket_Single_Close_Reverb.wav"};
    static final float[] LOOP_VOL = {0.38f, 0.8f, 0.34f, 0.12f};
    // the cricket sings now and then, not on and on, and a little slower (0.3
    // and always singing were too much - the author, 2026-10-16)
    static final int CRICKET = 3;
    static final float CRICKET_PITCH = 0.9f;
    static boolean cricketSings;
    static long cricketSwitchAt, gateAt;
    static float cricketGate;

    /** The cricket's part of its volume now: in and out softly, bouts of song and silence. */
    static float cricket(long now) {
        if (cricketSwitchAt == 0L) cricketSwitchAt = now + 2000L + rnd.nextInt(3000);
        if (now >= cricketSwitchAt) {
            cricketSings = !cricketSings;
            cricketSwitchAt = now + (cricketSings ? 2500L + rnd.nextInt(3500) : 7000L + rnd.nextInt(11000));
        }
        float dt = gateAt == 0L ? 0f : Math.min(0.2f, (now - gateAt) / 1000f);
        gateAt = now;
        float want = cricketSings ? 1f : 0f;
        float step = dt / 0.7f;
        cricketGate = cricketGate < want ? Math.min(want, cricketGate + step) : Math.max(want, cricketGate - step);
        return cricketGate;
    }

    static float gate(int i, long now) {
        return i == CRICKET ? cricket(now) : 1f;
    }
    // seconds each dies out in once the hero has gone: the fire left behind
    // first, then the cricket, the forest, the wind last
    static final float[] LOOP_FADE_S = {7f, 18f, 26f, 12f};
    // once the world has loaded, what is left of them goes in this long
    static final float LOADED_FADE_S = 2.5f;
    // the camp's end in the game: what is left dies out in this long (cut at
    // once, it was abrupt after a new character's load - the author, 2026-10-15)
    static final long END_FADE_MS = 2500L;

    // (heavy boots on the forest floor - the author's pick, 2026-10-15)
    static final String[] STEPS = new String[10];
    static {
        for (int i = 0; i < STEPS.length; i++) STEPS[i] = String.format("media/sound/knox_steps/boots_%02d.ogg", i + 1);
    }
    static final float STEP_VOL = 0.10f;   // (0.4, then 0.25 were still loud in the game - the author, 2026-10-15)
    // The dead beyond the fence (the author, 2026-10-16): their moans and the
    // shuffle of their feet as they walk. The game's own recordings - B42's
    // zombies speak through FMOD events, which its mixer keeps silent in the
    // menu; these are its plain files of the same voices. The old
    // zombierand*.wav were used before: clipped, 4-6 times louder than the owl,
    // much too loud even at 0.08. Their steps are the hero's own boots on the forest floor (STEPS; the game's zombie_footstep_m_* are on asphalt, its grass ones weren't heard - the author, 2026-10-16), quieter and less muffled than the moans. Volumes from their measured loudness (rms:
    // owl 1600, male moans ~3900, female ~2000, steps 120-400), so that a moan
    // is a little under the owl; muffled (low pass) as from far off.
    static final String[] MOAN_M = new String[8], MOAN_F = new String[9];
    static {
        for (int i = 0; i < MOAN_M.length; i++) MOAN_M[i] = String.format("media/sound/PZ_MaleZombie_%02d.wav", i + 1);
        for (int i = 0; i < MOAN_F.length; i++) MOAN_F[i] = String.format("media/sound/PZ_Female_zombie_%02d.wav", i + 1);
    }
    static final float MOAN_M_VOL = 0.03f, MOAN_F_VOL = 0.055f, ZSTEP_VOL = 0.05f;   // (0.07 / 0.13 / 0.2 sounded right in front of the author, 2026-10-16)
    static final float FAR_LOWPASS = 0.35f, STEP_LOWPASS = 0.7f;   // (1 = clear)
    static int lastMoan = -1, lastZStep = -1;

    static int pick(int n, int last) {
        int i = rnd.nextInt(n);
        if (n > 1 && i == last) i = (i + 1 + rnd.nextInt(n - 1)) % n;
        return i;
    }

    static void far(long ch) {
        muffle(ch, FAR_LOWPASS);
    }

    static void muffle(long ch, float gain) {
        try {
            if (ch != 0L) fmod.javafmod.FMOD_Channel_SetLowPassGain(ch, gain);
        } catch (Throwable t) {
            // as it is
        }
    }

    /** A moan from beyond the fence: a man's or a woman's voice, `near` 0..1 scales it. */
    @LuaMethod(name = "knoxCampMoan", global = true)
    public static void knoxCampMoan(boolean female, double near) {
        String[] set = female ? MOAN_F : MOAN_M;
        lastMoan = pick(set.length, lastMoan);
        float v = (female ? MOAN_F_VOL : MOAN_M_VOL) * (float) Math.max(0, Math.min(1, near));
        far(play(set[lastMoan % set.length], v * (0.8f + rnd.nextFloat() * 0.2f), 0.9f + rnd.nextFloat() * 0.15f, false));
    }

    /**
     * One of the game's own sounds by its name, played in the menu as its
     * Options screen previews them (GameSounds.previewSound: an FMOD event
     * started as it is, a file through FMOD) - but without stopping another.
     * For a bag opened at the fire: the sound the game gives that bag
     * (its OpenSound / CloseSound - a zip, a sheet, leather, plastic...;
     * the author, 2026-10-16: one zip didn't suit a bag made of a sheet).
     * `gain` scales the sound's own volume. False when it can't be played.
     */
    // A bag of cloth opened or closed at the fire: the game's own rustle of a
    // thing put in a bag (PZ_PutInBag.wav: rustle, a soft thump at 0.6 s, done
    // by 1.1 s), the open one cut short and faded out. (The game's own bag
    // sounds are FMOD events its mixer keeps silent in the menu - tried
    // 2026-10-16, through its Options preview too.)
    static final String RUSTLE = "media/sound/PZ_PutInBag.wav";
    static final java.util.ArrayList<long[]> CUTS = new java.util.ArrayList<>();   // {channel, fade from ms, end ms}
    static final java.util.HashMap<Long, Float> CUT_VOL = new java.util.HashMap<>();

    /** A file played for `ms` at most (0: whole), its last 120 ms fading out. */
    @LuaMethod(name = "knoxCampSoundCut", global = true)
    public static boolean knoxCampSoundCut(String file, double volume, double ms) {
        long ch = play(file == null || file.isEmpty() ? RUSTLE : file, (float) volume, 0.97f + rnd.nextFloat() * 0.06f, false);
        if (ch == 0L) return false;
        if (ms > 0) {
            long now = System.currentTimeMillis();
            CUTS.add(new long[] {ch, now + (long) Math.max(0, ms - 120), now + (long) ms});
            CUT_VOL.put(ch, (float) volume);
        }
        return true;
    }

    /** The cut sounds fading out (every frame, from knoxCampLoops). */
    static void cuts(long now) {
        for (int i = CUTS.size() - 1; i >= 0; i--) {
            long[] c = CUTS.get(i);
            Float v = CUT_VOL.get(c[0]);
            if (now >= c[2] || !alive(c[0])) {
                stop(c[0]);
                CUTS.remove(i);
                CUT_VOL.remove(c[0]);
            } else if (now >= c[1] && v != null) {
                try {
                    fmod.javafmod.FMOD_Channel_SetVolume(c[0], v * (float) (c[2] - now) / Math.max(1, c[2] - c[1]));
                } catch (Throwable t) {
                    // gone
                }
            }
        }
    }

    /** A foot of a walking dead comes down. */
    @LuaMethod(name = "knoxCampZombieStep", global = true)
    public static void knoxCampZombieStep(double near) {
        lastZStep = pick(STEPS.length, lastZStep);
        float v = ZSTEP_VOL * (float) Math.max(0, Math.min(1, near));
        muffle(play(STEPS[lastZStep], v * (0.8f + rnd.nextFloat() * 0.2f), 0.86f + rnd.nextFloat() * 0.1f, false), STEP_LOWPASS);
    }

    // his steps go on into the dark this long after the screen went black, dying away
    static final long INTO_DARK_MS = 2800L;

    // (Bob_Walk's footsteps at 0.2 and 0.65 of its cycle - the game's defaultWalk.xml)
    static final double FOOT_A = 0.2, FOOT_B = 0.65;

    static final long[] loopCh = new long[LOOP_FILE.length];
    static final float[] curVol = new float[LOOP_FILE.length], endVol = new float[LOOP_FILE.length];
    static final Random rnd = new Random();
    static int lastPick = -1;

    static long departAt;       // 0: no hero gone
    static long loadedAt;       // 0: the world not loaded yet
    static long endAt;          // 0: not ending
    static double cycle = 1.5;  // s of a walk cycle as the scene plays it
    static long lastStepAt;
    static int lastFoot;        // 0: the foot at FOOT_A, 1: at FOOT_B
    static long nextStepAt;     // 0: no more steps

    // ------------------------------------------------------------------ playing

    /** Play a file as the game plays its file sounds: 2D, its volume, a pitch; the channel (0 if not). */
    static long play(String file, float volume, float pitch, boolean loop) {
        try {
            long sound = FMODManager.instance.loadSound(file);
            if (sound == 0L) return 0L;
            long ch = fmod.javafmod.FMOD_System_PlaySound(sound, true);
            if (ch == 0L) return 0L;
            fmod.javafmod.FMOD_Channel_SetMode(ch, 8L);            // 2D
            if (loop) fmod.javafmod.FMOD_Channel_SetMode(ch, 2L);  // looping
            fmod.javafmod.FMOD_Channel_SetVolume(ch, volume);
            fmod.javafmod.FMOD_Channel_SetPitch(ch, pitch);
            fmod.javafmod.FMOD_Channel_SetPaused(ch, false);
            return ch;
        } catch (Throwable t) {
            return 0L;
        }
    }

    /** A step: one of them, never the same twice running, a little varied. */
    static void step(float volume) {
        int i = rnd.nextInt(STEPS.length);
        if (i == lastPick) i = (i + 1 + rnd.nextInt(STEPS.length - 1)) % STEPS.length;
        lastPick = i;
        play(STEPS[i], volume * (0.85f + rnd.nextFloat() * 0.15f), 0.94f + rnd.nextFloat() * 0.12f, false);
    }

    static boolean alive(long ch) {
        try {
            return ch != 0L && fmod.javafmod.FMOD_Channel_IsPlaying(ch);
        } catch (Throwable t) {
            return false;
        }
    }

    static void stop(long ch) {
        try {
            if (ch != 0L) fmod.javafmod.FMOD_Channel_Stop(ch);
        } catch (Throwable t) {
            // gone
        }
    }

    static void stopLoops() {
        for (int i = 0; i < loopCh.length; i++) {
            stop(loopCh[i]);
            loopCh[i] = 0L;
        }
    }

    static void setLoop(int i, float v) {
        curVol[i] = v;
        try {
            fmod.javafmod.FMOD_Channel_SetVolume(loopCh[i], v);
        } catch (Throwable t) {
            // gone
        }
    }

    /** (1 down to 0 over p 0..1, eased at both ends) */
    static float ease(double p) {
        if (p <= 0) return 1f;
        if (p >= 1) return 0f;
        return (float) ((1.0 + Math.cos(Math.PI * p)) / 2.0);
    }

    /** The time from the last step to the next: the clip's footsteps aren't evenly spaced. */
    static long gap() {
        double frac = lastFoot == 0 ? FOOT_B - FOOT_A : 1.0 - FOOT_B + FOOT_A;
        return (long) (cycle * frac * 1000.0);
    }

    // ---------------------------------------------------------------- from Lua

    /**
     * The camp's loops on (started where not playing, at their volumes; called every
     * frame - the cricket's song comes and goes) or off.
     * Ignored once a hero has gone or the camp is ending: the loops are this side's then.
     */
    @LuaMethod(name = "knoxCampLoops", global = true)
    public static void knoxCampLoops(boolean on) {
        if (departAt != 0L || endAt != 0L) return;
        if (!on) {
            stopLoops();
            return;
        }
        long now = System.currentTimeMillis();
        if (!CUTS.isEmpty()) cuts(now);
        for (int i = 0; i < loopCh.length; i++) {
            float g = gate(i, now);
            if (!alive(loopCh[i])) {
                loopCh[i] = play(LOOP_FILE[i], LOOP_VOL[i] * g, i == CRICKET ? CRICKET_PITCH : 1f, true);
                curVol[i] = LOOP_VOL[i] * g;
            } else if (i == CRICKET) {
                setLoop(i, LOOP_VOL[i] * g);
            }
        }
    }

    /** A foot of the walking hero comes down (foot 0 at the clip's first footstep, 1 at its second). */
    @LuaMethod(name = "knoxCampStep", global = true)
    public static void knoxCampStep(double foot) {
        lastStepAt = System.currentTimeMillis();
        lastFoot = foot >= 0.5 ? 1 : 0;
        step(STEP_VOL);
    }

    /** The screen is black and the save loads: his last steps and the camp's end are ours from here. */
    @LuaMethod(name = "knoxCampDepart", global = true)
    public static void knoxCampDepart(double cycleSeconds) {
        long now = System.currentTimeMillis();
        departAt = now;
        loadedAt = 0L;
        endAt = 0L;
        if (cycleSeconds > 0.3 && lastStepAt != 0L && now - lastStepAt < 2000L) {
            cycle = cycleSeconds;
            nextStepAt = Math.max(now, lastStepAt + gap());
        } else {
            nextStepAt = 0L;   // (no one walking - a risen hero fades away)
        }
    }

    /** Lua's frames between the launch and the loading screen, and in the game while the camp dies out: false once all is done. */
    @LuaMethod(name = "knoxCampTick", global = true)
    public static boolean knoxCampTick() {
        tick();
        return departAt != 0L || endAt != 0L;
    }

    /**
     * The game has started, or the load never did. Softly (the game's start),
     * what is left of the camp dies out (Lua ticks it); else it stops.
     */
    @LuaMethod(name = "knoxCampEnd", global = true)
    public static void knoxCampEnd(boolean soft) {
        departAt = 0L;
        loadedAt = 0L;
        lastStepAt = 0L;
        nextStepAt = 0L;
        boolean any = false;
        for (int i = 0; i < loopCh.length; i++) {
            endVol[i] = alive(loopCh[i]) ? curVol[i] : 0f;
            any |= endVol[i] > 0f;
        }
        if (soft && any) {
            if (endAt == 0L) endAt = System.currentTimeMillis();
            return;
        }
        endAt = 0L;
        stopLoops();
    }

    // -------------------------------------------------------------- the loading

    /** Every frame of the loading screen (KnoxLoading's patch of its render). */
    public static void loadingFrame() {
        // a load not begun by a hero walking off (a new game, the game's Load
        // screen): the camp still dies out over it
        if (departAt == 0L && endAt == 0L) {
            for (long ch : loopCh) {
                if (alive(ch)) {
                    knoxCampDepart(0);
                    break;
                }
            }
        }
        tick();
    }

    static void tick() {
        long now = System.currentTimeMillis();
        if (endAt != 0L) {
            float f = ease((now - endAt) / (double) END_FADE_MS);
            for (int i = 0; i < loopCh.length; i++) {
                if (loopCh[i] == 0L) continue;
                if (f <= 0f || !alive(loopCh[i])) {
                    stop(loopCh[i]);
                    loopCh[i] = 0L;
                } else {
                    setLoop(i, endVol[i] * f);
                }
            }
            if (f <= 0f) endAt = 0L;
            return;
        }
        if (departAt == 0L) return;
        try {
            if (loadedAt == 0L && KnoxMusic.loaded()) loadedAt = now;

            // the camp behind him
            boolean anyLoop = false;
            for (int i = 0; i < loopCh.length; i++) {
                if (loopCh[i] == 0L) continue;
                float f = ease((now - departAt) / 1000.0 / LOOP_FADE_S[i]);
                if (loadedAt != 0L) f = Math.min(f, ease((now - loadedAt) / 1000.0 / LOADED_FADE_S));
                if (f <= 0f || !alive(loopCh[i])) {
                    stop(loopCh[i]);
                    loopCh[i] = 0L;
                    continue;
                }
                anyLoop = true;
                setLoop(i, LOOP_VOL[i] * f * gate(i, now));
            }

            // his last steps, dying away into the dark
            if (nextStepAt != 0L && now >= nextStepAt) {
                float k = ease((now - departAt) / (double) INTO_DARK_MS);
                if (k <= 0.05f) {
                    nextStepAt = 0L;
                } else {
                    step(STEP_VOL * k);
                    lastFoot = 1 - lastFoot;
                    nextStepAt = now + gap();
                }
            }

            if (nextStepAt == 0L && !anyLoop) departAt = 0L;
        } catch (Throwable t) {
            // the sounds stay as they are; the game's start stops them
        }
    }
}
