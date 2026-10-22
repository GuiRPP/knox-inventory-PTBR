package knox.java;

import java.util.Random;
import java.util.function.LongPredicate;

import fmod.javafmodJNI;

/**
 * The radio by the fire as a radio (the author, 2026-10-15: the channel's
 * low-pass alone was "not a radio"; hiss, interference, a bit of room asked
 * for). The menu's own music, while it plays "from the radio", goes through a
 * chain of FMOD's own effects (on a channel group of its own - below):
 *   - a small speaker's band: highs and lows cut, a nasal bump in the middle
 *     (multiband EQ);
 *   - a little breakup of a cheap amplifier (distortion);
 *   - the box: a very short echo;
 *   - the camp around it: a short, dark reverb.
 * And the air: the signal swells and sinks a little all the time, and now and
 * then sinks away for a moment into the air's noise (media/sound/knox_radio/
 * air.wav, made by Knox), which goes through the same speaker. The steady hiss
 * under it all is KnoxRadioStatic (Lua).
 *
 * The game's FMOD bridge creates an effect by its type number, and those
 * numbers moved between FMOD versions: each effect is told apart by how its
 * parameters take values (counts and ranges), not trusted by number.
 */
public class KnoxRadioFx {

    // FMOD 2.03's numbers (looked at first; the rest are searched)
    static final int GUESS_EQ = 32, GUESS_DIST = 9, GUESS_ECHO = 6, GUESS_REVERB = 17;
    // FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE
    static final int F_OFF = 0, F_LOWPASS_24 = 2, F_HIGHPASS_24 = 5, F_PEAKING = 9;

    static boolean tried;
    static long eq, dist, echo, reverb;
    static long attachedTo;
    static boolean on;

    static final Random rnd = new Random();
    static final double p1 = rnd.nextDouble() * 6.28, p2 = rnd.nextDouble() * 6.28, p3 = rnd.nextDouble() * 6.28;
    static long dropAt, dropLen, nextDrop;

    static int f(long d, int i, float v) {
        return javafmodJNI.FMOD_DSP_SetParameterFloat(d, i, v);
    }

    static int n(long d, int i, int v) {
        return javafmodJNI.FMOD_DSP_SetParameterInt(d, i, v);
    }

    // how each one takes its values (FMOD_OK is 0)
    static boolean isEq(long d) {
        return n(d, 0, 0) == 0 && n(d, 4, 0) == 0 && n(d, 8, 0) == 0 && n(d, 12, 0) == 0 && n(d, 16, 0) == 0
            && f(d, 1, 1000f) == 0 && f(d, 19, 0f) == 0;
    }

    static boolean isDist(long d) {
        return f(d, 0, 0.5f) == 0 && f(d, 0, -20f) != 0 && f(d, 0, 5000f) != 0 && f(d, 1, 0f) != 0;
    }

    static boolean isEcho(long d) {
        return f(d, 0, 50f) == 0 && f(d, 1, 20f) == 0 && f(d, 2, 0f) == 0 && f(d, 3, -10f) == 0 && f(d, 0, 5f) != 0;
    }

    static boolean isReverb(long d) {
        return f(d, 0, 1500f) == 0 && f(d, 11, -20f) == 0 && f(d, 12, 0f) == 0 && f(d, 0, 50f) != 0 && f(d, 13, 0f) != 0;
    }

    static long create(int type) {
        try {
            return javafmodJNI.FMOD_System_CreateDSPByType(type);
        } catch (Throwable t) {
            return 0L;
        }
    }

    static void release(long d) {
        try {
            if (d != 0L) javafmodJNI.FMOD_DSP_Release(d);
        } catch (Throwable t) {
            // gone
        }
    }

    /** The effect that takes values as `is` says: the guess first, then every type there is. */
    static long find(int guess, LongPredicate is) {
        long d = create(guess);
        if (d != 0L) {
            if (is.test(d)) return d;
            release(d);
        }
        for (int t = 1; t <= 40; t++) {
            if (t == guess) continue;
            d = create(t);
            if (d == 0L) continue;
            boolean ok = false;
            try {
                ok = is.test(d);
            } catch (Throwable e) {
                ok = false;
            }
            if (ok) return d;
            release(d);
        }
        return 0L;
    }

    static void make() {
        if (tried) return;
        tried = true;
        try {
            eq = find(GUESS_EQ, KnoxRadioFx::isEq);
            dist = find(GUESS_DIST, KnoxRadioFx::isDist);
            echo = find(GUESS_ECHO, KnoxRadioFx::isEcho);
            reverb = find(GUESS_REVERB, KnoxRadioFx::isReverb);
            if (eq != 0L) {
                // the speaker's band, and its nasal middle
                n(eq, 0, F_HIGHPASS_24); f(eq, 1, 320f); f(eq, 2, 0.707f);
                n(eq, 4, F_LOWPASS_24); f(eq, 5, 3300f); f(eq, 6, 0.707f);
                n(eq, 8, F_PEAKING); f(eq, 9, 1500f); f(eq, 10, 1.1f); f(eq, 11, 6f);
                n(eq, 12, F_PEAKING); f(eq, 13, 600f); f(eq, 14, 1.0f); f(eq, 15, -3f);
                n(eq, 16, F_OFF);
            }
            if (dist != 0L) f(dist, 0, 0.28f);
            if (echo != 0L) {
                // the box: a very short echo, quiet
                f(echo, 0, 18f); f(echo, 1, 28f); f(echo, 2, 0f); f(echo, 3, -13f);
            }
            if (reverb != 0L) {
                // a short dark reverb: by a fire in the woods, not a hall
                f(reverb, 0, 900f); f(reverb, 1, 12f); f(reverb, 2, 20f); f(reverb, 3, 4000f);
                f(reverb, 4, 45f); f(reverb, 5, 70f); f(reverb, 6, 80f); f(reverb, 7, 250f);
                f(reverb, 8, 0f); f(reverb, 9, 3500f); f(reverb, 10, 55f); f(reverb, 11, -17f); f(reverb, 12, 0f);
            }
            System.out.println("[Knox] radio sound: eq " + (eq != 0L) + ", distortion " + (dist != 0L)
                + ", echo " + (echo != 0L) + ", reverb " + (reverb != 0L));
        } catch (Throwable t) {
            System.out.println("[Knox] radio sound: no effects (" + t + ")");
            eq = dist = echo = reverb = 0L;
        }
    }

    /** Are the effects there (else Knox falls back to the channel's low-pass)? */
    static boolean ready() {
        make();
        return eq != 0L;
    }

    // The music and the air play in one channel group of their own, the effects
    // on the group: both come out of the same small speaker. (At first the
    // effects sat on the music's channel and the interference was played beside
    // it - "digital noise over the music, not from the radio": the author,
    // 2026-10-16.)
    static long group, noiseCh;
    static boolean groupFx;
    static final String AIR = "media/sound/knox_radio/air.wav";
    // the air: a breath of it always, and in a dropout the music sinks into it
    static final float AIR_BASE = 0.05f, AIR_DROP = 0.75f, MUSIC_DROP = 0.88f;

    static boolean makeGroup() {
        if (group != 0L) return groupFx;
        try {
            group = fmod.javafmod.FMOD_System_CreateChannelGroup("KnoxRadio");
            if (group == 0L) return false;
            // (each at the head: the one added first ends up first in the signal's way)
            for (long d : new long[] {eq, dist, echo, reverb}) {
                if (d != 0L) javafmodJNI.FMOD_ChannelGroup_AddDSP(group, 0, d);
            }
            groupFx = true;
        } catch (Throwable t) {
            groupFx = false;
        }
        return groupFx;
    }

    static void toGroup(long ch, long g) {
        try {
            if (ch != 0L && g != 0L) fmod.javafmod.FMOD_Channel_SetChannelGroup(ch, g);
        } catch (Throwable t) {
            // left where it is
        }
    }

    /** The air's loop, into the radio's group, silent until set. */
    static void startAir() {
        if (KnoxCamp.alive(noiseCh)) return;
        try {
            long sound = fmod.fmod.FMODManager.instance.loadSound(AIR);
            if (sound == 0L) return;
            long ch = fmod.javafmod.FMOD_System_PlaySound(sound, true);
            if (ch == 0L) return;
            fmod.javafmod.FMOD_Channel_SetMode(ch, 8L);
            fmod.javafmod.FMOD_Channel_SetMode(ch, 2L);
            fmod.javafmod.FMOD_Channel_SetVolume(ch, 0f);
            toGroup(ch, group);
            fmod.javafmod.FMOD_Channel_SetPaused(ch, false);
            noiseCh = ch;
        } catch (Throwable t) {
            noiseCh = 0L;
        }
    }

    static void airVolume(float v) {
        try {
            if (noiseCh != 0L) fmod.javafmod.FMOD_Channel_SetVolume(noiseCh, v);
        } catch (Throwable t) {
            // gone
        }
    }

    /** The radio's sound on the channel or off it. */
    static void set(long ch, boolean want) {
        on = want;
        if (ch == 0L) return;
        if (want && attachedTo != ch && ready() && makeGroup()) {
            detach();
            toGroup(ch, group);
            attachedTo = ch;
            startAir();
            nextDrop = System.currentTimeMillis() + 8000L + rnd.nextInt(12000);
        } else if (!want) {
            detach();
        }
    }

    /** Off the radio (before the channel stops, or the radio is turned off): the music back to the master group, the air gone. */
    static void detach() {
        long ch = attachedTo;
        attachedTo = 0L;
        dropAt = 0L;
        KnoxCamp.stop(noiseCh);
        noiseCh = 0L;
        if (ch == 0L) return;
        try {
            toGroup(ch, fmod.javafmod.FMOD_System_GetMasterChannelGroup());
        } catch (Throwable t) {
            // gone with its channel
        }
    }

    /** The air hushed (the music paused, or fading out at the game's start). */
    static void quiet() {
        airVolume(0f);
    }

    /**
     * The air's part of the music's volume now (1 with the radio off), the air's
     * own volume set with it: the signal swells and sinks a little all the time,
     * and now and then sinks away into the air for a moment.
     */
    static float level(long ch, float volume) {
        if (!on || attachedTo == 0L || attachedTo != ch) return 1f;
        long now = System.currentTimeMillis();
        double t = now / 1000.0;
        // (three slow waves: never quite the same twice)
        double sway = 0.5 + 0.5 * Math.sin(t * 0.41 + p1) * Math.sin(t * 0.17 + p2) + 0.15 * Math.sin(t * 1.3 + p3);
        sway = Math.max(0.0, Math.min(1.0, sway));
        float k = (float) (1.0 - 0.14 * sway);
        double dip = 0.0;
        if (dropAt == 0L && now >= nextDrop) {
            dropAt = now;
            dropLen = 900L + rnd.nextInt(1600);
        }
        if (dropAt != 0L) {
            double p = (now - dropAt) / (double) dropLen;
            if (p >= 1.0) {
                dropAt = 0L;
                nextDrop = now + 15000L + rnd.nextInt(30000);
            } else {
                // (in over a third, eased; out slower)
                double q = p < 0.33 ? p / 0.33 : 1.0 - (p - 0.33) / 0.67;
                dip = (1.0 - Math.cos(Math.PI * q)) / 2.0;
            }
        }
        k *= (float) (1.0 - MUSIC_DROP * dip);
        airVolume(volume * (float) (AIR_BASE * (0.6 + 0.8 * sway) + AIR_DROP * dip));
        return k;
    }

    // The switch (the author asked for it, 2026-10-16): the snap of the switch
    // itself, dry; then, through the speaker, the station tuned in - the air
    // with a whistle sliding down to it, the music coming up out of it - or,
    // turned off, the speaker's thump with the air dying. (The game's own radio
    // sounds are in-game events, silent in the menu like its footsteps.)
    // (several takes of each, never the same twice running - one each got old
    // fast: the author, 2026-10-16)
    static final String[] SWITCH = takes("switch", 4), TUNE_IN = takes("tune_in", 4), POWER_OFF = takes("power_off", 3);
    // the card's other buttons: the radio's own push buttons (asked for, 2026-10-16).
    // Real ones, the author's picks: a tape deck's key, two of an old device's
    // buttons, an old plastic button (Artlist; the synthesised ones sounded
    // "too modern, not analogue")
    static final String[] BUTTON = {
        "media/sound/knox_radio/press_1.ogg", "media/sound/knox_radio/press_2.ogg",
        "media/sound/knox_radio/press_3.ogg", "media/sound/knox_radio/press_4.ogg"};
    static final float BUTTON_VOL = 0.45f;
    static final int[] lastTake = {-1, -1, -1, -1};

    static void button() {
        KnoxCamp.play(pick(BUTTON, 3), BUTTON_VOL, 0.95f + rnd.nextFloat() * 0.1f, false);
    }

    static String[] takes(String name, int n) {
        String[] a = new String[n];
        for (int i = 0; i < n; i++) a[i] = "media/sound/knox_radio/" + name + "_" + (i + 1) + ".wav";
        return a;
    }

    static String pick(String[] set, int slot) {
        int i = rnd.nextInt(set.length);
        if (set.length > 1 && i == lastTake[slot]) i = (i + 1 + rnd.nextInt(set.length - 1)) % set.length;
        lastTake[slot] = i;
        return set[i];
    }
    static final float SWITCH_VOL = 0.35f, TAIL_VOL = 0.6f;

    /** A file through the radio's speaker (its group), once. */
    static void throughSpeaker(String file, float volume) {
        if (!ready() || !makeGroup()) return;
        try {
            long sound = fmod.fmod.FMODManager.instance.loadSound(file);
            if (sound == 0L) return;
            long ch = fmod.javafmod.FMOD_System_PlaySound(sound, true);
            if (ch == 0L) return;
            fmod.javafmod.FMOD_Channel_SetMode(ch, 8L);
            fmod.javafmod.FMOD_Channel_SetVolume(ch, volume);
            toGroup(ch, group);
            fmod.javafmod.FMOD_Channel_SetPaused(ch, false);
        } catch (Throwable t) {
            // no sound
        }
    }

    static void switched(boolean nowOn, float musicVolume) {
        KnoxCamp.play(pick(SWITCH, 0), SWITCH_VOL, 0.97f + rnd.nextFloat() * 0.06f, false);
        float v = Math.max(0.15f, musicVolume) * TAIL_VOL;
        if (nowOn) {
            throughSpeaker(pick(TUNE_IN, 1), v);
            // the music out of the air: a dropout begun at its deepest
            if (attachedTo != 0L) {
                long now = System.currentTimeMillis();
                dropLen = 1600L;
                dropAt = now - (long) (dropLen * 0.33);
            }
        } else {
            throughSpeaker(pick(POWER_OFF, 2), v);
        }
    }
}