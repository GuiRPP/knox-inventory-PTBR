package knox.java;

import java.util.Random;

/**
 * The winter bar's radio has a sound of its own (the author, 2026-11-01: half broken, more
 * interference, not the same noise over and over, the sound itself distorted). The same EQ as the
 * radio by the fire (KnoxRadioFx), tuned otherwise and never still:
 *   - a torn speaker: a narrower band, a hard resonance that wanders, a hole in the lows' middle,
 *     a rattle high up;
 *   - the set drifting off the station: the pitch, a hair, and a lurch now and then;
 *   - a loose contact: the sound cut in bursts, a long sag when the speaker nearly gives up;
 *   - faults on the air: six kinds, several takes of each (tools/sound/make_bar_radio.py), at
 *     uneven gaps and volumes, never the same kind twice running, through the same speaker.
 * Claude can't hear: the numbers are by reasoning, for the author to set by ear.
 */
final class KnoxBarRadio {
    private KnoxBarRadio() {
    }

    private static final Random rnd = new Random();

    // {name, takes, how often against the others, how loud}
    private static final Object[][] KINDS = {
        {"buzz", 3, 2, 0.55f}, {"whistle", 4, 2, 0.45f}, {"sputter", 3, 2, 0.7f},
        {"surge", 3, 3, 0.7f}, {"pop", 4, 4, 0.85f}, {"ghost", 3, 2, 0.5f}};
    private static final int POP = 4, SURGE = 3;   // (the crackle went: "like rummaging in flesh" - the author, 2026-11-01)
    private static final int[] lastTake = new int[KINDS.length];
    private static int lastKind = -1;
    private static long nextFaultAt;

    // what is on now, to go with the radio
    private static final long[] playing = new long[4];
    private static int nextPlaying;

    // the loose contact: a burst of cuts
    private static long burstUntil, cutUntil, nextCutAt, nextBurstAt;
    private static float cutTo = 1f;
    // the speaker nearly giving up, for some seconds
    private static long sagAt, sagLen, nextSagAt;
    // a lurch off the station
    private static long lurchAt, lurchLen, nextLurchAt;
    private static float lurchBy;

    private static long tunedAt;
    private static final double p1 = rnd.nextDouble() * 6.28, p2 = rnd.nextDouble() * 6.28, p3 = rnd.nextDouble() * 6.28;

    /** The EQ, as this radio has it. The moving parts: {@link #tick}. */
    static void tone(long eq) {
        if (eq != 0L) {
            KnoxRadioFx.n(eq, 0, KnoxRadioFx.F_HIGHPASS_24); KnoxRadioFx.f(eq, 1, 480f); KnoxRadioFx.f(eq, 2, 0.707f);
            KnoxRadioFx.n(eq, 4, KnoxRadioFx.F_LOWPASS_24); KnoxRadioFx.f(eq, 5, 2500f); KnoxRadioFx.f(eq, 6, 0.9f);
            KnoxRadioFx.n(eq, 8, KnoxRadioFx.F_PEAKING); KnoxRadioFx.f(eq, 9, 1250f); KnoxRadioFx.f(eq, 10, 2.4f); KnoxRadioFx.f(eq, 11, 9f);
            KnoxRadioFx.n(eq, 12, KnoxRadioFx.F_PEAKING); KnoxRadioFx.f(eq, 13, 720f); KnoxRadioFx.f(eq, 14, 1.6f); KnoxRadioFx.f(eq, 15, -7f);
            KnoxRadioFx.n(eq, 16, KnoxRadioFx.F_PEAKING); KnoxRadioFx.f(eq, 17, 2050f); KnoxRadioFx.f(eq, 18, 5f); KnoxRadioFx.f(eq, 19, 5f);
        }
    }

    /** Just on: everything to come at its own time, not all at once. */
    static void begin(long now) {
        nextFaultAt = now + 3000L + rnd.nextInt(7000);
        nextBurstAt = now + 12000L + rnd.nextInt(20000);
        nextSagAt = now + 40000L + rnd.nextInt(50000);
        nextLurchAt = now + 15000L + rnd.nextInt(30000);
        burstUntil = cutUntil = nextCutAt = sagAt = lurchAt = 0L;
        cutTo = 1f;
    }

    /** The faults on the air stop (a pause, the radio off, the camp). */
    static void hush() {
        for (int i = 0; i < playing.length; i++) {
            KnoxCamp.stop(playing[i]);
            playing[i] = 0L;
        }
    }

    private static void fault(int kind, float volume) {
        Object[] k = KINDS[kind];
        int takes = (Integer) k[1];
        // (not the take of last time)
        int take = rnd.nextInt(takes);
        if (take == lastTake[kind]) take = (take + 1 + rnd.nextInt(takes - 1)) % takes;
        lastTake[kind] = take;
        lastKind = kind;
        float v = volume * (Float) k[3] * (0.45f + 0.55f * rnd.nextFloat());
        float pitch = 0.82f + rnd.nextFloat() * 0.36f;
        long ch = KnoxRadioFx.throughSpeaker("media/sound/knox_radio/bar_" + k[0] + "_" + (take + 1) + ".wav", v, pitch);
        KnoxCamp.stop(playing[nextPlaying]);
        playing[nextPlaying] = ch;
        nextPlaying = (nextPlaying + 1) % playing.length;
    }

    private static int pickKind() {
        int total = 0;
        for (int i = 0; i < KINDS.length; i++) if (i != lastKind) total += (Integer) KINDS[i][2];
        int at = rnd.nextInt(total);
        for (int i = 0; i < KINDS.length; i++) {
            if (i == lastKind) continue;
            at -= (Integer) KINDS[i][2];
            if (at < 0) return i;
        }
        return 0;
    }

    /**
     * Every frame the radio plays here: how much of the music comes through now (the volume's
     * part), the moving parts of the EQ set, the faults started.
     */
    static float tick(long ch, long now, float volume) {
        if (now >= nextFaultAt) {
            fault(pickKind(), volume);
            // (uneven, a rest now and then; a lot rarer: the author, 2026-11-01, "very often")
            nextFaultAt = now + (rnd.nextInt(4) == 0 ? 15000L + rnd.nextInt(15000) : 5000L + rnd.nextInt(9000));
        }
        float k = 1f;

        // a loose contact: a burst of cuts, each with its own length and depth, a knock on the way
        if (burstUntil == 0L && now >= nextBurstAt) {
            burstUntil = now + 300L + rnd.nextInt(1400);
            nextCutAt = now;
            fault(POP, volume);
        }
        if (burstUntil != 0L) {
            if (now >= burstUntil) {
                burstUntil = 0L;
                cutUntil = 0L;
                nextBurstAt = now + 15000L + rnd.nextInt(30000);
            } else if (now >= nextCutAt) {
                cutUntil = now + 25L + rnd.nextInt(150);
                nextCutAt = cutUntil + 20L + rnd.nextInt(180);
                cutTo = 0.04f + rnd.nextFloat() * 0.4f;
            }
        }
        if (cutUntil != 0L && now < cutUntil) k *= cutTo;

        // the speaker nearly giving up: thin and far for some seconds
        double sag = 0.0;
        if (sagAt == 0L && now >= nextSagAt) {
            sagAt = now;
            sagLen = 2500L + rnd.nextInt(5500);
            fault(SURGE, volume);
        }
        if (sagAt != 0L) {
            double p = (now - sagAt) / (double) sagLen;
            if (p >= 1.0) {
                sagAt = 0L;
                nextSagAt = now + 50000L + rnd.nextInt(70000);
            } else {
                sag = Math.sin(Math.PI * Math.min(1.0, p * 1.15));
                sag = Math.max(0.0, sag);
            }
        }
        k *= (float) (1.0 - 0.5 * sag);

        // (the channel's and the EQ's values: no need each frame)
        if (now - tunedAt < 40L) return k;
        tunedAt = now;
        double t = now / 1000.0;

        if (KnoxRadioFx.eq != 0L) {
            // the torn cone's resonance wanders; the band closes as the speaker sags
            float peak = (float) (1250.0 + 260.0 * Math.sin(t * 0.37 + p2) + 90.0 * Math.sin(t * 3.1 + p3));
            KnoxRadioFx.f(KnoxRadioFx.eq, 9, peak);
            KnoxRadioFx.f(KnoxRadioFx.eq, 5, (float) (2500.0 + 350.0 * Math.sin(t * 0.53 + p3) - 1100.0 * sag));
            KnoxRadioFx.f(KnoxRadioFx.eq, 1, (float) (480.0 + 260.0 * sag));
        }

        // off the station, a hair; a lurch now and then
        if (lurchAt == 0L && now >= nextLurchAt) {
            lurchAt = now;
            lurchLen = 250L + rnd.nextInt(800);
            lurchBy = (rnd.nextBoolean() ? 1f : -1f) * (0.008f + rnd.nextFloat() * 0.014f);
        }
        double lurch = 0.0;
        if (lurchAt != 0L) {
            double p = (now - lurchAt) / (double) lurchLen;
            if (p >= 1.0) {
                lurchAt = 0L;
                nextLurchAt = now + 20000L + rnd.nextInt(40000);
            } else {
                lurch = lurchBy * Math.sin(Math.PI * p);
            }
        }
        pitch(ch, (float) (1.0 + 0.003 * Math.sin(t * 0.29 + p1) + 0.0015 * Math.sin(t * 4.3 + p2) + lurch));
        return k;
    }

    static void pitch(long ch, float value) {
        try {
            if (ch != 0L) fmod.javafmod.FMOD_Channel_SetPitch(ch, value);
        } catch (Throwable e) {
            // gone
        }
    }
}
