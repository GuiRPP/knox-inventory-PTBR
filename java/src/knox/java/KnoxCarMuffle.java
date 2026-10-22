package knox.java;

import fmod.javafmodJNI;

/**
 * Own music left playing in a car the driver has got out of (the author,
 * 2026-10-21: "the sound of music playing inside a closed car while you are
 * outside"). Built like the radio's sound (KnoxRadioFx: FMOD's own effects on a
 * channel group of its own, each effect found by how it takes its values):
 *   - the body: almost no highs through steel and glass - a steep low-pass,
 *     darker the farther off one stands (`set(ch, k)`, k 0 by the car .. 1 far);
 *   - the cabin's boom: the bass and the low middle carry, a bump at ~120 Hz and
 *     a smaller one at ~250 Hz; no rumble under 45 Hz;
 *   - the panels: a very short, quiet echo - a box ringing a little.
 * No hiss and no air: the radio's chain (and its noise) is off the track meanwhile.
 * Two of them: MAIN for the player's track, PARKED for the one left playing in
 * another car (KnoxMusic's parked track - the author, 2026-10-21: both cars play);
 * and NET, one for each of the other players' tracks heard here (KnoxMusicNet).
 */
public class KnoxCarMuffle {

    static final int F_OFF = 0, F_LOWPASS_24 = 2, F_HIGHPASS_12 = 4, F_PEAKING = 9;
    // the body's low-pass: by the car .. far off - shut, and with it open (a door
    // or the windows: the author, 2026-10-21 - the music sounds otherwise then)
    static final float CUT_NEAR = 950f, CUT_FAR = 380f;
    static final float OPEN_CUT_NEAR = 5200f, OPEN_CUT_FAR = 1600f;
    // the cabin's boom (shut .. open): an open car booms less, rings less
    static final float BOOM = 6f, BOOM_OPEN = 1.5f, LOWMID = 2.5f, LOWMID_OPEN = 0.5f;
    static final float ECHO_WET = -16f, ECHO_WET_OPEN = -26f;

    static final KnoxCarMuffle MAIN = new KnoxCarMuffle("KnoxCarMuffle", true);
    static final KnoxCarMuffle PARKED = new KnoxCarMuffle("KnoxCarMuffleParked", false);
    // the other players' tracks (KnoxMusicNet's slots): a body of its own each
    static final KnoxCarMuffle[] NET = new KnoxCarMuffle[KnoxMusicNet.SLOTS];
    static {
        for (int i = 0; i < NET.length; i++) NET[i] = new KnoxCarMuffle("KnoxCarMuffleNet" + i, false);
    }

    final String name;
    final boolean ownsRadio;   // the player's track: the radio's chain comes off it first
    boolean tried;
    long eq, echo, group;
    long attachedTo;
    float darkNow = -1f, openNow = -1f;

    KnoxCarMuffle(String name, boolean ownsRadio) {
        this.name = name;
        this.ownsRadio = ownsRadio;
    }

    static float logMix(float a, float b, float k) {
        return (float) (a * Math.pow(b / a, k));
    }

    static int f(long d, int i, float v) {
        return javafmodJNI.FMOD_DSP_SetParameterFloat(d, i, v);
    }

    static int n(long d, int i, int v) {
        return javafmodJNI.FMOD_DSP_SetParameterInt(d, i, v);
    }

    boolean ready() {
        if (!tried) {
            tried = true;
            try {
                eq = KnoxRadioFx.find(KnoxRadioFx.GUESS_EQ, KnoxRadioFx::isEq);
                echo = KnoxRadioFx.find(KnoxRadioFx.GUESS_ECHO, KnoxRadioFx::isEcho);
                if (eq != 0L) {
                    n(eq, 0, F_LOWPASS_24); f(eq, 1, CUT_NEAR); f(eq, 2, 0.707f);
                    n(eq, 4, F_PEAKING); f(eq, 5, 120f); f(eq, 6, 0.9f); f(eq, 7, 6f);
                    n(eq, 8, F_PEAKING); f(eq, 9, 250f); f(eq, 10, 1.0f); f(eq, 11, 2.5f);
                    n(eq, 12, F_HIGHPASS_12); f(eq, 13, 45f); f(eq, 14, 0.707f);
                    n(eq, 16, F_OFF);
                }
                if (echo != 0L) {
                    f(echo, 0, 7f); f(echo, 1, 12f); f(echo, 2, 0f); f(echo, 3, -16f);
                }
                if (eq != 0L) {
                    group = fmod.javafmod.FMOD_System_CreateChannelGroup(name);
                    if (group != 0L) {
                        for (long d : new long[] {eq, echo}) {
                            if (d != 0L) javafmodJNI.FMOD_ChannelGroup_AddDSP(group, 0, d);
                        }
                    }
                }
                System.out.println("[Knox] car muffle " + name + ": eq " + (eq != 0L) + ", echo " + (echo != 0L) + ", group " + (group != 0L));
            } catch (Throwable t) {
                System.out.println("[Knox] car muffle " + name + ": no effects (" + t + ")");
                eq = echo = group = 0L;
            }
        }
        return group != 0L;
    }

    /**
     * The track `ch` muffled, `dark` 0 (by the car) .. 1 (far off), `open` 0 (the
     * car shut) .. 1 (a door open, the windows down); a negative `dark`: off it.
     */
    void set(long ch, float dark, float open) {
        if (dark < 0f) {
            detach();
            return;
        }
        if (ch == 0L || !ready()) return;
        if (attachedTo != ch) {
            if (ownsRadio) KnoxRadioFx.detach();
            KnoxRadioFx.toGroup(ch, group);
            attachedTo = ch;
            darkNow = openNow = -1f;
        }
        float k = Math.max(0f, Math.min(1f, dark));
        float o = Math.max(0f, Math.min(1f, open));
        if (Math.abs(k - darkNow) <= 0.01f && Math.abs(o - openNow) <= 0.01f) return;
        darkNow = k;
        openNow = o;
        // (by the ear's scale: the cut moves evenly in octaves)
        float cut = logMix(logMix(CUT_NEAR, OPEN_CUT_NEAR, o), logMix(CUT_FAR, OPEN_CUT_FAR, o), k);
        try {
            f(eq, 1, cut);
            f(eq, 7, BOOM + (BOOM_OPEN - BOOM) * o);
            f(eq, 11, LOWMID + (LOWMID_OPEN - LOWMID) * o);
            if (echo != 0L) f(echo, 3, ECHO_WET + (ECHO_WET_OPEN - ECHO_WET) * o);
        } catch (Throwable t) {
            // left as it was
        }
    }

    boolean on() {
        return attachedTo != 0L;
    }

    /** Off the car's sound: the track back to the master group (the radio's chain is Lua's to put back). */
    void detach() {
        long ch = attachedTo;
        attachedTo = 0L;
        darkNow = openNow = -1f;
        if (ch == 0L) return;
        try {
            KnoxRadioFx.toGroup(ch, fmod.javafmod.FMOD_System_GetMasterChannelGroup());
        } catch (Throwable t) {
            // gone with its channel
        }
    }
}
