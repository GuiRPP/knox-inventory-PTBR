package knox.java;

/**
 * The winter bar's sounds of the main menu (stage 6, the author 2026-10-31): the storm and the
 * door. Two of the game's recordings make the wind, each going with the frame's gusts: higher and
 * louder in a gust, and the one from outside muffled as the door shuts on it. The door slams as
 * the frame's door does (KnoxBarLife counts its slams), and in a gust it rattles on its latch.
 * The loops are KnoxCamp's (LOOP_FILE): they die out over the loading screen as the camp's do.
 *
 * All of it on the main thread (Lua's calls), as KnoxCamp: the frame only tells how things stand.
 */
final class KnoxBarSound {
    // (the recordings' levels, rms: the wind outside 295, inside 49 - an FMOD channel takes a gain
    // over 1 -, the door shutting 2341, its latch 1325; the camp's fire plays at about 580)
    private static final float OUT_CALM = 0.4f, OUT_GUST = 0.75f, IN_CALM = 2.2f, IN_GUST = 1.6f;
    private static final float SHUT_VOL = 0.55f, SHUT_LOWPASS = 0.3f, IN_LOWPASS = 0.6f;
    private static final float START_S = 2f;
    private static final long EVERY_MS = 50L;
    private static final String BANG = "media/sound/doorclose.wav", LATCH = "media/sound/doorlocked.wav";
    // A richer storm (the author, 2026-11-01: "the boards of the house creak, the storm howls more"):
    // the howl through the boards (windowwind, rms 477), the old house creaking on and on
    // (wooddoorcreaks, 25), the boarded window rattling in a gust (windowrattle, 66); now and then
    // a board creaks (thumpsqueak5/6, ~135, lower) and a beam cracks in the frost (crackwood, 984)
    private static final float HOWL_CALM = 0.03f, HOWL_GUST = 0.5f, CREAKS_CALM = 2.4f, CREAKS_GUST = 2.2f,
        RATTLE_GUST = 2.4f;
    private static final String[] CREAK = {"media/sound/thumpsqueak5.wav", "media/sound/thumpsqueak6.wav"};
    private static final String CRACK = "media/sound/crackwood.wav";
    // and the game's own ambience of a winter storm heard from inside a house, as in the game in
    // winter: its FMOD event with the game's global parameters set the way a blizzard sets them
    // (ParameterSeason: winter 3, ParameterStorm: a blizzard 3, ParameterInside 1, the night);
    // the wind's strength goes with the frame's gusts. The game's own values go back when it
    // stops (the game sends a parameter again only once it changes)
    private static final String WORLD_EVENT = "event:/World/Ambiance";
    private static final String[] WORLD_PARAMS = {"Season", "Storm", "Inside", "SnowIntensity", "TimeOfDay", "WindIntensity"};
    private static final float[] WORLD_VALUES = {3f, 3f, 1f, 1f, 5f, 0.7f};
    private static final float WORLD_VOL = 0.8f;
    private static long world;
    private static boolean worldTried;
    private static boolean worldParams;   // the game's parameters set to the bar's: given back in worldOff
    private static long nextCreak, nextCrack;

    private static int bangsHeard;
    // the journal's page: Artlist recordings the author picked (2026-11-02, tools\sfx\bar_pages.py), each
    // heard once before any again (a shuffled round; the author: "it repeats"). Each starts so its middle
    // (PAGE_PEAK in the file, as bar_pages.py prints it) meets the page
    // standing up, half its turn (KnoxBarFrame.PAGE_TIME) after it lifts; every page of a gust its own
    // (up to PAGES_QUEUED waiting). The pencil off the counter: its roll made up (tools\sfx\bar_small.py),
    // on the floor an Artlist recording the author picked (bar_pages.py), its knock PENCIL_HIT_MS in,
    // timed to the pencil reaching the floor (KnoxBarFrame.movePencil: off the edge at 0.76 s, the floor
    // 1.1 m below at 1.23 s)
    private static final String[] PAGE = {"media/sound/knox_page/page_1.ogg", "media/sound/knox_page/page_2.ogg",
        "media/sound/knox_page/page_3.ogg", "media/sound/knox_page/page_4.ogg"};
    private static final float[] PAGE_PEAK = {0.41f, 0.30f, 0.25f, 0.20f};
    private static final int[] pageRound = {0, 1, 2, 3};
    private static final String PENCIL = "media/sound/knox_pencil_roll.wav", PENCIL_FLOOR = "media/sound/knox_page/pencil_floor.ogg";
    private static final long PENCIL_FLOOR_MS = 1230L, PENCIL_HIT_MS = 10L;
    private static long pencilFloorAt;
    private static final long PAGE_UP_MS = 400L;
    private static final int PAGES_QUEUED = 4;
    private static final long[] pageAt = new long[PAGES_QUEUED];
    private static final int[] pageClip = new int[PAGES_QUEUED];
    private static final float[] pagePitch = new float[PAGES_QUEUED];
    private static int pageNext = PAGE.length, lastPage = -1;
    private static int pagesHeard, pencilsHeard;
    private static long at, nextLatch;
    private static float started, heard = 1f;

    private static long trackHeard;

    private KnoxBarSound() {
    }

    /** Every frame while the bar is up: the frame tells the gust, the door and its slams. */
    static void tick(KnoxBarFrame frame) {
        // a new track: the needle goes somewhere else on the dial (the author, 2026-11-01)
        long track = KnoxMusic.channelNow();
        if (track != trackHeard) {
            trackHeard = track;
            if (track != 0L) {
                float from = frame.needleWhere(), to = KnoxCamp.rnd.nextFloat();
                if (Math.abs(to - from) < 0.2f) to = from > 0.5f ? from - 0.2f - 0.3f * to : from + 0.2f + 0.3f * to;
                frame.needleTo(to);
            }
        }
        // (kept up to date all the time: a slam while a hero was on his way is not heard when he comes back)
        int bangs = frame.doorBangs();
        boolean bang = bangs > bangsHeard;
        bangsHeard = bangs;
        int pages = frame.pagesTurned(), pencils = frame.pencilFalls();
        int newPages = Math.max(0, pages - pagesHeard);
        boolean pencil = pencils > pencilsHeard;
        pagesHeard = pages;
        pencilsHeard = pencils;
        if (KnoxCamp.departAt != 0L || KnoxCamp.endAt != 0L) return;
        KnoxCamp.onWood = true;
        KnoxRadioFx.broken = true;
        // (no fire, forest or cricket of the camp in the bar - the author, 2026-11-01)
        for (int i = 0; i < KnoxCamp.CAMP_LOOPS; i++) KnoxCamp.stopLoop(i);
        float sfx = sfx();
        // (not in the dark of the first seconds, before the wind is up. As hard as it hit: the
        // door's bounces are taps after the slam, QA 2026-10-31)
        if (bang && started >= 1f) {
            KnoxCamp.play(BANG, (0.06f + 0.4f * frame.doorBangPower()) * sfx, 0.72f + 0.1f * KnoxCamp.rnd.nextFloat(), false);
        }

        long now = System.currentTimeMillis();
        if (pencil && started >= 1f) {
            KnoxCamp.play(PENCIL, 0.28f * sfx, 1f, false);
            pencilFloorAt = now + PENCIL_FLOOR_MS - PENCIL_HIT_MS;
        }
        if (pencilFloorAt != 0L && now >= pencilFloorAt) {
            pencilFloorAt = 0L;
            KnoxCamp.play(PENCIL_FLOOR, 0.28f * sfx, 0.97f + 0.06f * KnoxCamp.rnd.nextFloat(), false);
        }
        for (int n = 0; n < newPages && started >= 1f; n++) queuePage(now);
        for (int i = 0; i < PAGES_QUEUED; i++) {
            if (pageAt[i] == 0L || now < pageAt[i]) continue;
            pageAt[i] = 0L;
            // (half as loud: they drew the ear too much - the author, 2026-11-02)
            KnoxCamp.play(PAGE[pageClip[i]], (0.05f + 0.025f * KnoxCamp.rnd.nextFloat()) * sfx, pagePitch[i], false);
        }
        // (a bag's rustle cut short: KnoxCamp does it under the camp's loops)
        if (!KnoxCamp.CUTS.isEmpty()) KnoxCamp.cuts(now);

        // (the channels' volumes and pitches: no need to touch them each frame)
        if (now - at < EVERY_MS) return;
        float dt = at == 0L ? 0f : Math.min(0.2f, (now - at) / 1000f);
        at = now;
        float gust = frame.gustNow(), open = frame.doorLetsIn();
        boolean out = KnoxCamp.alive(KnoxCamp.loopCh[KnoxCamp.WIND_OUT]), in = KnoxCamp.alive(KnoxCamp.loopCh[KnoxCamp.WIND_IN]);
        if (!out && !in) {
            // (back in the bar: from the start, no rattle left over)
            started = 0f;
            nextLatch = 0L;
            nextCreak = 0L;
            nextCrack = 0L;
        }
        started = Math.min(1f, started + dt / START_S);
        heard += (open - heard) * Math.min(1f, dt * 8f);

        float volOut = (OUT_CALM + OUT_GUST * gust) * (SHUT_VOL + (1f - SHUT_VOL) * heard) * started;
        float volIn = (IN_CALM + IN_GUST * gust) * started;
        wind(KnoxCamp.WIND_OUT, out, volOut, 0.92f + 0.2f * gust, SHUT_LOWPASS + (1f - SHUT_LOWPASS) * heard);
        wind(KnoxCamp.WIND_IN, in, volIn, 0.85f + 0.15f * gust, IN_LOWPASS);

        // (the storm's howl louder and higher in a gust: its strength squared, the calm nearly still)
        float g2 = gust * gust;
        wind(KnoxCamp.HOWL, KnoxCamp.alive(KnoxCamp.loopCh[KnoxCamp.HOWL]), (HOWL_CALM + HOWL_GUST * g2) * started,
            0.85f + 0.35f * gust, 0.55f + 0.35f * heard);
        wind(KnoxCamp.CREAKS, KnoxCamp.alive(KnoxCamp.loopCh[KnoxCamp.CREAKS]), (CREAKS_CALM + CREAKS_GUST * gust) * started,
            0.9f + 0.1f * gust, 0.8f);
        wind(KnoxCamp.RATTLE, KnoxCamp.alive(KnoxCamp.loopCh[KnoxCamp.RATTLE]), RATTLE_GUST * Math.max(0f, gust - 0.3f) * started,
            1f, 0.9f);
        world(gust);
        // (a board somewhere, sooner in a gust; a beam in the frost, seldom)
        if (started >= 1f && now >= nextCreak) {
            if (nextCreak != 0L) {
                long ch = KnoxCamp.play(CREAK[KnoxCamp.rnd.nextInt(CREAK.length)], (0.45f + 0.35f * KnoxCamp.rnd.nextFloat()) * sfx,
                    0.55f + 0.3f * KnoxCamp.rnd.nextFloat(), false);
                KnoxCamp.muffle(ch, 0.6f);
            }
            nextCreak = now + (long) ((4000 + KnoxCamp.rnd.nextInt(9000)) * (1.2f - 0.6f * gust));
        }
        if (started >= 1f && now >= nextCrack) {
            if (nextCrack != 0L) {
                long ch = KnoxCamp.play(CRACK, (0.05f + 0.03f * KnoxCamp.rnd.nextFloat()) * sfx, 0.45f + 0.15f * KnoxCamp.rnd.nextFloat(), false);
                KnoxCamp.muffle(ch, 0.35f);
            }
            nextCrack = now + 30000L + KnoxCamp.rnd.nextInt(50000);
        }

        if (gust > 0.45f && now >= nextLatch) {
            if (nextLatch != 0L) {
                KnoxCamp.play(LATCH, (0.03f + 0.06f * gust) * (0.7f + 0.3f * KnoxCamp.rnd.nextFloat()) * sfx,
                    0.85f + 0.2f * KnoxCamp.rnd.nextFloat(), false);
            }
            nextLatch = now + 1500L + KnoxCamp.rnd.nextInt(3500);
        }
    }

    /** A page has just lifted: its recording picked and timed to the moment it stands up. */
    private static void queuePage(long now) {
        for (int i = 0; i < PAGES_QUEUED; i++) {
            if (pageAt[i] != 0L) continue;
            if (pageNext >= PAGE.length) {
                // a new round, shuffled; its first not the last one heard
                for (int k = PAGE.length - 1; k > 0; k--) {
                    int j = KnoxCamp.rnd.nextInt(k + 1), t = pageRound[k];
                    pageRound[k] = pageRound[j];
                    pageRound[j] = t;
                }
                if (pageRound[0] == lastPage) {
                    pageRound[0] = pageRound[PAGE.length - 1];
                    pageRound[PAGE.length - 1] = lastPage;
                }
                pageNext = 0;
            }
            int clip = pageRound[pageNext++];
            lastPage = clip;
            float pitch = 0.95f + 0.1f * KnoxCamp.rnd.nextFloat();
            pageClip[i] = clip;
            pagePitch[i] = pitch;
            // (a pitch plays the file faster: its peak comes sooner)
            pageAt[i] = now + Math.max(1L, PAGE_UP_MS - (long) (1000f * PAGE_PEAK[clip] / pitch));
            return;
        }
    }

    private static void wind(int i, boolean alive, float volume, float pitch, float lowPass) {
        volume *= sfx();
        // (the loop's fading over the loading screen starts from here)
        KnoxCamp.LOOP_VOL[i] = volume;
        if (!alive) {
            KnoxCamp.stopLoop(i);
            KnoxCamp.loopCh[i] = KnoxCamp.play(KnoxCamp.LOOP_FILE[i], volume, pitch, true);
            KnoxCamp.curVol[i] = volume;
        } else {
            KnoxCamp.setLoop(i, volume);
            try {
                fmod.javafmod.FMOD_Channel_SetPitch(KnoxCamp.loopCh[i], pitch);
            } catch (Throwable t) {
                // gone
            }
        }
        KnoxCamp.muffle(KnoxCamp.loopCh[i], lowPass);
    }

    /**
     * The game's sound slider, 0..1: the bar's and the look's sounds go by it (the author, 2026-11-04; the
     * camp's stay as they were). At its top, as the author set and heard them.
     */
    static float sfx() {
        try {
            return Math.max(0, Math.min(10, zombie.core.Core.getInstance().getOptionSoundVolume())) / 10f;
        } catch (Throwable t) {
            return 1f;
        }
    }

    /** The sounds are over (KnoxCamp.knoxCampEnd): back from a failed load, a slam meanwhile stays unheard. */
    static void over() {
        started = 0f;
        java.util.Arrays.fill(pageAt, 0L);
        pencilFloorAt = 0L;
        worldOff();
    }

    /** The game's winter ambience: started once, its wind set by the gust (every 50 ms). */
    private static void world(float gust) {
        try {
            if (world == 0L) {
                if (worldTried) return;
                worldTried = true;
                long ev = fmod.javafmod.FMOD_Studio_System_GetEvent(WORLD_EVENT);
                if (ev == 0L) {
                    System.out.println("[Knox] bar: no " + WORLD_EVENT);
                    return;
                }
                // (the menu has no listener of its own: the event where the listener is)
                fmod.javafmod.FMOD_Studio_Listener3D(0, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 1f, 0f, 1f, 0f);
                worldParams = true;
                for (int i = 0; i < WORLD_PARAMS.length; i++) {
                    fmod.javafmod.FMOD_Studio_System_SetParameterByName(WORLD_PARAMS[i], WORLD_VALUES[i], false);
                }
                world = fmod.javafmod.FMOD_Studio_System_CreateEventInstance(ev);
                if (world == 0L) return;
                fmod.javafmod.FMOD_Studio_EventInstance3D(world, 0f, 0f, 0f);
                fmod.javafmod.FMOD_Studio_EventInstance_SetVolume(world, 0f);
                fmod.javafmod.FMOD_Studio_StartEvent(world);
            }
            fmod.javafmod.FMOD_Studio_System_SetParameterByName("WindIntensity", 0.55f + 0.45f * gust, false);
            fmod.javafmod.FMOD_Studio_EventInstance_SetVolume(world, WORLD_VOL * started * sfx());
        } catch (Throwable t) {
            System.out.println("[Knox] bar: the game's winter ambience failed: " + t);
            worldOff();
        }
    }

    /** The game's winter ambience off (faded by FMOD) and the game's own values of its parameters back. */
    static void worldOff() {
        worldTried = false;
        if (world != 0L) stopWorld();
        // (given back even with no event made of them: winter stayed set in the game - overhaul, 2026-11-04)
        if (!worldParams) return;
        worldParams = false;
        for (String name : WORLD_PARAMS) {
            try {
                zombie.audio.FMODGlobalParameter p = fmod.fmod.FMODManager.instance.getGlobalParameter(name);
                float v = p == null ? Float.NaN : p.getCurrentValue();
                if (!Float.isNaN(v)) fmod.javafmod.FMOD_Studio_System_SetParameterByName(name, v, false);
            } catch (Throwable t) {
                // the game sets it again
            }
        }
    }

    private static void stopWorld() {
        long inst = world;
        world = 0L;
        try {
            // (false: it fades out as its event says, as the game stops its own; true cut it at once -
            // overhaul, 2026-11-04)
            fmod.javafmod.FMOD_Studio_EventInstance_Stop(inst, false);
            fmod.javafmod.FMOD_Studio_ReleaseEventInstance(inst);
        } catch (Throwable t) {
            // gone
        }
    }
}
