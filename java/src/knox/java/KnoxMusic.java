package knox.java;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Locale;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.ZomboidFileSystem;

/**
 * The main menu's music player (KnoxMenuMusic.lua): the player's own music.
 * Files dropped into Zomboid/knox_music (ogg, mp3, wav, flac) are played as
 * streams straight through FMOD - no sound script, no mod needed. Lua asks for
 * the list, plays one, sets its volume, and looks whether it is still playing.
 * The game's own menu music is its FMOD event, left to the game (or played by
 * Lua as a sound script when a mod has silenced it).
 */
public class KnoxMusic {

    // FMOD_2D | FMOD_CREATESTREAM | FMOD_LOOP_OFF (a stream: a long track isn't loaded whole)
    static final long MODE = 0x8L | 0x80L | 0x1L;
    private static final String[] KINDS = {".ogg", ".mp3", ".wav", ".flac"};

    private static long sound;
    private static long channel;
    private static String current;

    /** Zomboid/knox_music, made with a note in it the first time. */
    static File folder() {
        File dir = new File(ZomboidFileSystem.instance.getCacheDir(), "knox_music");
        if (!dir.isDirectory()) {
            dir.mkdirs();
        }
        File note = new File(dir, "README.txt");
        // (written again where it still sends the player to the old player at
        // the top right: it is the radio by the fire since 2026-10-15)
        if (!noteChecked && (!note.exists() || stale(note))) {
            try (Writer w = new OutputStreamWriter(new FileOutputStream(note), StandardCharsets.UTF_8)) {
                w.write("Knox Inventory - your own music for the main menu.\r\n"
                    + "Put .ogg, .mp3, .wav or .flac files here, then pick \"Mine\" on the radio by\r\n"
                    + "the fire in the main menu (each folder here is a playlist of its own).\r\n\r\n"
                    + "Knox Inventory - своя музыка для главного меню.\r\n"
                    + "Положите сюда файлы .ogg, .mp3, .wav или .flac и выберите \"Своя\" на радио\r\n"
                    + "у костра в главном меню (каждая папка здесь - свой плейлист).\r\n");
            } catch (Throwable t) {
                // no note, no harm
            }
        }
        noteChecked = true;
        return dir;
    }

    private static boolean noteChecked;

    private static boolean stale(File note) {
        try {
            return new String(java.nio.file.Files.readAllBytes(note.toPath()), StandardCharsets.UTF_8).contains("top right");
        } catch (Throwable t) {
            return false;
        }
    }

    /** Where the folder is (shown in the player). */
    @LuaMethod(name = "knoxMusicFolder", global = true)
    public static String knoxMusicFolder() {
        return folder().getAbsolutePath();
    }

    /** Open the folder in the system's file manager (a click on "My music" while it is empty). */
    @LuaMethod(name = "knoxMusicOpenFolder", global = true)
    public static boolean knoxMusicOpenFolder() {
        File dir = folder();
        try {
            new ProcessBuilder("explorer.exe", dir.getAbsolutePath()).start();
            return true;
        } catch (Throwable t) {
            try {
                java.awt.Desktop.getDesktop().open(dir);
                return true;
            } catch (Throwable t2) {
                return false;
            }
        }
    }

    private static boolean isMusic(File f) {
        if (!f.isFile()) return false;
        String n = f.getName().toLowerCase(Locale.ROOT);
        for (String k : KINDS) {
            if (n.endsWith(k)) return true;
        }
        return false;
    }

    /**
     * The music files, one a line, by path in the folder: "Song.mp3" for one lying
     * in it, "Album/Song.mp3" for one in a folder of it (one level: a folder is a
     * playlist of its own in the player). Folders first by name, files by name.
     */
    @LuaMethod(name = "knoxMusicList", global = true)
    public static String knoxMusicList() {
        File[] files = folder().listFiles();
        ArrayList<String> root = new ArrayList<>();
        ArrayList<String> nested = new ArrayList<>();
        if (files != null) {
            for (File f : files) {
                if (f.isDirectory()) {
                    File[] inner = f.listFiles();
                    if (inner == null) continue;
                    for (File g : inner) {
                        if (isMusic(g)) nested.add(f.getName() + "/" + g.getName());
                    }
                } else if (isMusic(f)) {
                    root.add(f.getName());
                }
            }
        }
        Collections.sort(nested, String.CASE_INSENSITIVE_ORDER);
        Collections.sort(root, String.CASE_INSENSITIVE_ORDER);
        nested.addAll(root);
        return String.join("\n", nested);
    }

    /** Play a file of the folder ("Song.mp3" or "Album/Song.mp3") from its start. */
    @LuaMethod(name = "knoxMusicPlay", global = true)
    public static boolean knoxMusicPlay(String name, double volume) {
        knoxMusicStop();
        File f = resolve(name);
        return f != null && playFile(f, name, volume);
    }

    /** The file of the folder a name means; null for one outside it. */
    static File resolve(String name) {
        if (name == null || name.contains("\\") || name.contains("..") || name.startsWith("/")) return null;
        String[] parts = name.split("/");
        if (parts.length > 2) return null;
        return parts.length == 2 ? new File(new File(folder(), parts[0]), parts[1]) : new File(folder(), name);
    }

    // ------------------------------------------------------------ the parked car's track
    // Own music left playing in a car while the player drives another, whose music plays
    // too (the author, 2026-10-21: both play at once). Always heard from outside its car
    // (KnoxCarMuffle.PARKED); Lua steps its list and sets its volume by the distance.
    private static long pSound, pChannel;
    private static float pVolume, pMuffle = -1f, pOpen;
    private static boolean pPaused;

    /**
     * The player's track and the parked one change places, as they play: the one
     * the player left goes on in the car left behind, the one of the car got back
     * into is the player's again (either may be none).
     */
    @LuaMethod(name = "knoxMusicSwapParked", global = true)
    public static void knoxMusicSwapParked() {
        if (fadeFrom != 0L) knoxMusicStop();
        KnoxRadioFx.detach();
        KnoxCarMuffle.MAIN.detach();
        KnoxCarMuffle.PARKED.detach();
        long s = sound, c = channel;
        float v = volumeNow, m = muffle, o = muffleOpen;
        boolean p = paused;
        sound = pSound;
        channel = pChannel;
        volumeNow = pChannel != 0L ? pVolume : volumeNow;
        muffle = pMuffle;
        muffleOpen = pOpen;
        paused = pPaused;
        current = null;
        pSound = s;
        pChannel = c;
        pVolume = v;
        pMuffle = m < 0f ? 0f : m;
        pOpen = o;
        pPaused = p;
        try {
            if (channel != 0L) {
                if (muffle >= 0f) KnoxCarMuffle.MAIN.set(channel, muffle, muffleOpen);
                fmod.javafmod.FMOD_Channel_SetVolume(channel, volumeNow * duckNow());
            }
            if (pChannel != 0L) KnoxCarMuffle.PARKED.set(pChannel, pMuffle, pOpen);
        } catch (Throwable t) {
            // gone
        }
    }

    /** The parked car's next track (from its start). */
    @LuaMethod(name = "knoxMusicParkedPlay", global = true)
    public static boolean knoxMusicParkedPlay(String name, double volume) {
        knoxMusicParkedStop();
        File f = resolve(name);
        if (f == null || !f.isFile()) return false;
        try {
            pSound = fmod.javafmod.FMOD_System_CreateSound(f.getAbsolutePath(), MODE);
            if (pSound == 0L) return false;
            pChannel = fmod.javafmod.FMOD_System_PlaySound(pSound, true);
            if (pChannel == 0L) {
                knoxMusicParkedStop();
                return false;
            }
            fmod.javafmod.FMOD_Channel_SetPriority(pChannel, 0);   // (see playFile)
            pVolume = (float) volume;
            fmod.javafmod.FMOD_Channel_SetVolume(pChannel, pVolume);
            KnoxCarMuffle.PARKED.set(pChannel, Math.max(0f, pMuffle), pOpen);
            fmod.javafmod.FMOD_Channel_SetPaused(pChannel, pPaused);
            return true;
        } catch (Throwable t) {
            knoxMusicParkedStop();
            return false;
        }
    }

    @LuaMethod(name = "knoxMusicParkedPlaying", global = true)
    public static boolean knoxMusicParkedPlaying() {
        try {
            return pChannel != 0L && fmod.javafmod.FMOD_Channel_IsPlaying(pChannel);
        } catch (Throwable t) {
            return false;
        }
    }

    /** Where the parked car's track is, in ms (0 when none) - told to the others (KnoxMusicNet). */
    @LuaMethod(name = "knoxMusicParkedPosition", global = true)
    public static double knoxMusicParkedPosition() {
        try {
            return pChannel != 0L ? (double) fmod.javafmod.FMOD_Channel_GetPosition(pChannel, MS) : 0.0;
        } catch (Throwable t) {
            return 0.0;
        }
    }

    @LuaMethod(name = "knoxMusicParkedLength", global = true)
    public static double knoxMusicParkedLength() {
        try {
            return pSound != 0L ? (double) fmod.javafmod.FMOD_Sound_GetLength(pSound, MS) : 0.0;
        } catch (Throwable t) {
            return 0.0;
        }
    }

    @LuaMethod(name = "knoxMusicParkedVolume", global = true)
    public static void knoxMusicParkedVolume(double volume) {
        pVolume = (float) volume;
        try {
            if (pChannel != 0L) fmod.javafmod.FMOD_Channel_SetVolume(pChannel, pVolume);
        } catch (Throwable t) {
            // gone
        }
    }

    @LuaMethod(name = "knoxMusicParkedMuffle", global = true)
    public static void knoxMusicParkedMuffle(double dark, double open) {
        pMuffle = (float) Math.max(0.0, Math.min(1.0, dark));
        pOpen = (float) Math.max(0.0, Math.min(1.0, open));
        if (pChannel != 0L) KnoxCarMuffle.PARKED.set(pChannel, pMuffle, pOpen);
    }

    @LuaMethod(name = "knoxMusicParkedPause", global = true)
    public static void knoxMusicParkedPause(boolean paused) {
        pPaused = paused;
        try {
            if (pChannel != 0L) fmod.javafmod.FMOD_Channel_SetPaused(pChannel, paused);
        } catch (Throwable t) {
            // gone
        }
    }

    @LuaMethod(name = "knoxMusicParkedStop", global = true)
    public static void knoxMusicParkedStop() {
        KnoxCarMuffle.PARKED.detach();
        try {
            if (pChannel != 0L) fmod.javafmod.FMOD_Channel_Stop(pChannel);
        } catch (Throwable t) {
            // gone
        }
        try {
            if (pSound != 0L) fmod.javafmod.FMOD_Sound_Release(pSound);
        } catch (Throwable t) {
            // gone
        }
        pChannel = 0L;
        pSound = 0L;
        pPaused = false;
    }

    /**
     * The volume of the game's music bus (the player's slider over "Game's music";
     * set back to 1 when a game starts).
     */
    @LuaMethod(name = "knoxMusicGameVolume", global = true)
    public static void knoxMusicGameVolume(double volume) {
        try {
            long bus = fmod.javafmod.FMOD_Studio_System_GetBus("bus:/Music");
            if (bus != 0L) fmod.javafmod.FMOD_Studio_Bus_SetVolume(bus, (float) Math.max(0.0, Math.min(1.0, volume)));
        } catch (Throwable t) {
            // left as it is
        }
    }

    // The radio lying by the fire (the author's wish, 2026-10-15): the music as if
    // from its small speaker. Its sound is KnoxRadioFx's chain of FMOD effects;
    // where those can't be made, the channel's low-pass (`gain` below 1: the
    // radio on - Lua's call stays as it was).
    private static float lowPass = 1f;
    private static boolean radio;

    @LuaMethod(name = "knoxMusicRadio", global = true)
    public static void knoxMusicRadio(double gain) {
        radio = gain < 1.0;
        boolean fx = radio && KnoxRadioFx.ready();
        lowPass = (radio && !fx) ? (float) Math.max(0.0, gain) : 1f;
        try {
            // (a track fading out keeps its sound to the end; a car's track heard
            // from outside keeps the car's - KnoxCarMuffle)
            if (channel != 0L && fadeFrom == 0L && muffle < 0f) {
                fmod.javafmod.FMOD_Channel_SetLowPassGain(channel, lowPass);
                KnoxRadioFx.set(channel, radio);
            }
        } catch (Throwable t) {
            // gone
        }
    }

    // The car's own music heard from outside the car (KnoxCarMuffle): -1 off, else
    // how far off one stands, 0 .. 1.
    private static float muffle = -1f, muffleOpen = 0f;

    @LuaMethod(name = "knoxMusicMuffle", global = true)
    public static void knoxMusicMuffle(double dark, double open) {
        muffle = dark < 0.0 ? -1f : (float) Math.min(1.0, dark);
        muffleOpen = (float) Math.max(0.0, Math.min(1.0, open));
        try {
            if (channel == 0L || fadeFrom != 0L) return;
            if (muffle >= 0f) {
                fmod.javafmod.FMOD_Channel_SetLowPassGain(channel, 1f);
                KnoxCarMuffle.MAIN.set(channel, muffle, muffleOpen);
            } else {
                KnoxCarMuffle.MAIN.detach();
                fmod.javafmod.FMOD_Channel_SetLowPassGain(channel, lowPass);
                if (radio) KnoxRadioFx.set(channel, true);
            }
        } catch (Throwable t) {
            // gone
        }
    }

    /** One of the radio card's other buttons pressed: a push button's click. */
    @LuaMethod(name = "knoxMusicRadioButton", global = true)
    public static void knoxMusicRadioButton() {
        KnoxRadioFx.button();
    }

    /** The radio's switch was flipped: its sound (KnoxRadioFx.switched). */
    @LuaMethod(name = "knoxMusicRadioSwitch", global = true)
    public static void knoxMusicRadioSwitch(boolean on) {
        KnoxRadioFx.switched(on, volumeNow);
    }

    private static boolean playFile(File f, String name, double volume) {
        if (!f.isFile()) return false;
        try {
            sound = fmod.javafmod.FMOD_System_CreateSound(f.getAbsolutePath(), MODE);
            if (sound == 0L) return false;
            channel = fmod.javafmod.FMOD_System_PlaySound(sound, false);
            if (channel == 0L) {
                knoxMusicStop();
                return false;
            }
            // the most important voice there is (0; FMOD's default 128): with the game's
            // voices all taken - the engine, zombies, rain, a click on the dashboard -
            // FMOD makes the least important one virtual, silent while it goes on, and
            // our track was that one (the author, 2026-10-21: the car's music went
            // quiet for a while and came back, the cruise control switched)
            fmod.javafmod.FMOD_Channel_SetPriority(channel, 0);
            fmod.javafmod.FMOD_Channel_SetVolume(channel, (float) volume * duckNow());
            paused = false;
            if (muffle >= 0f) {
                KnoxCarMuffle.MAIN.set(channel, muffle, muffleOpen);
            } else {
                if (lowPass < 1f) fmod.javafmod.FMOD_Channel_SetLowPassGain(channel, lowPass);
                if (radio) KnoxRadioFx.set(channel, true);
            }
            current = name;
            volumeNow = (float) volume;
            fadeFrom = 0L;
            return true;
        } catch (Throwable t) {
            knoxMusicStop();
            return false;
        }
    }

    // FMOD_TIMEUNIT_MS
    private static final int MS = 1;

    /** Where the track is, in ms (0 when nothing of ours plays). */
    @LuaMethod(name = "knoxMusicPosition", global = true)
    public static double knoxMusicPosition() {
        try {
            return channel != 0L ? (double) fmod.javafmod.FMOD_Channel_GetPosition(channel, MS) : 0.0;
        } catch (Throwable t) {
            return 0.0;
        }
    }

    /** How long the track is, in ms (0 when unknown). */
    @LuaMethod(name = "knoxMusicLength", global = true)
    public static double knoxMusicLength() {
        try {
            return sound != 0L ? (double) fmod.javafmod.FMOD_Sound_GetLength(sound, MS) : 0.0;
        } catch (Throwable t) {
            return 0.0;
        }
    }

    /** Go to a place in the track, in ms (the radio card's seek bar). */
    @LuaMethod(name = "knoxMusicSeek", global = true)
    public static void knoxMusicSeek(double ms) {
        try {
            if (channel != 0L) fmod.javafmod.FMOD_Channel_SetPosition(channel, (long) Math.max(0.0, ms));
        } catch (Throwable t) {
            // gone
        }
    }

    @LuaMethod(name = "knoxMusicVolume", global = true)
    public static void knoxMusicVolume(double volume) {
        volumeNow = (float) volume;
        apply();
    }

    // Ducked while a hero walks off into a save (the author, 2026-10-15: his steps
    // were lost under the music): the volume eased to a part of itself and back.
    private static float duckFrom = 1f, duckTo = 1f;
    private static long duckAt, duckMs;

    static float duckNow() {
        if (duckMs <= 0L) return duckTo;
        double p = (System.currentTimeMillis() - duckAt) / (double) duckMs;
        if (p >= 1.0) return duckTo;
        return duckFrom + (duckTo - duckFrom) * (float) ((1.0 - Math.cos(Math.PI * Math.max(0.0, p))) / 2.0);
    }

    /** Ease the music to `to` of its volume over ms (1: back to full). */
    @LuaMethod(name = "knoxMusicDuck", global = true)
    public static void knoxMusicDuck(double to, double ms) {
        duckFrom = duckNow();
        duckTo = (float) Math.max(0.0, Math.min(1.0, to));
        duckAt = System.currentTimeMillis();
        duckMs = (long) Math.max(0.0, ms);
        apply();
    }

    /** Every frame of the menu: a duck on its way. */
    @LuaMethod(name = "knoxMusicTick", global = true)
    public static void knoxMusicTick() {
        apply();
    }

    /** The volume as set, ducked (a fade sets its own). */
    static void apply() {
        if (channel == 0L || fadeFrom != 0L) return;
        try {
            // (paused: the radio's air stays quiet - a volume set meanwhile brought
            // it back, the author, 2026-10-21: the noise went on with the track paused)
            float k = 1f;
            if (paused) KnoxRadioFx.quiet(); else k = KnoxRadioFx.level(channel, volumeNow);
            fmod.javafmod.FMOD_Channel_SetVolume(channel, volumeNow * duckNow() * k);
        } catch (Throwable t) {
            // gone
        }
    }

    private static boolean paused;

    @LuaMethod(name = "knoxMusicPause", global = true)
    public static void knoxMusicPause(boolean paused) {
        KnoxMusic.paused = paused;
        if (paused) KnoxRadioFx.quiet();
        try {
            if (channel != 0L) fmod.javafmod.FMOD_Channel_SetPaused(channel, paused);
        } catch (Throwable t) {
            // gone
        }
    }

    /** Is a file of ours still playing (false once it has ended)? */
    @LuaMethod(name = "knoxMusicPlaying", global = true)
    public static boolean knoxMusicPlaying() {
        try {
            return channel != 0L && fmod.javafmod.FMOD_Channel_IsPlaying(channel);
        } catch (Throwable t) {
            return false;
        }
    }

    @LuaMethod(name = "knoxMusicStop", global = true)
    public static void knoxMusicStop() {
        KnoxRadioFx.detach();
        KnoxCarMuffle.MAIN.detach();
        paused = false;
        try {
            if (channel != 0L) fmod.javafmod.FMOD_Channel_Stop(channel);
        } catch (Throwable t) {
            // gone
        }
        try {
            if (sound != 0L) fmod.javafmod.FMOD_Sound_Release(sound);
        } catch (Throwable t) {
            // gone
        }
        channel = 0L;
        sound = 0L;
        current = null;
        fadeFrom = 0L;
    }

    // The way into a game (the author, 2026-10-15/16): the menu's track goes on
    // over the loading screen and over "Click to start"; after the click it fades
    // in the game - Lua starts it and steps it each tick, and brings the game's
    // music back after it.
    private static float volumeNow = 1f;   // the volume as last set: the fade's start
    private static long fadeFrom, fadeMs;

    static void fadeStart(long ms) {
        if (channel == 0L || fadeFrom != 0L) return;
        fadeFrom = System.currentTimeMillis();
        fadeMs = Math.max(1L, ms);
        KnoxRadioFx.quiet();   // (the air goes at once: the music fades alone)
    }

    /** One step of the fade: false once there is nothing (more) to fade. */
    static boolean fadeStep() {
        if (channel == 0L || fadeFrom == 0L) return false;
        double p = (System.currentTimeMillis() - fadeFrom) / (double) fadeMs;
        if (p >= 1.0) {
            knoxMusicStop();
            return false;
        }
        // (eased at both ends: no step at its start, no cut at its end)
        float v = (float) (volumeNow * duckNow() * (1.0 + Math.cos(Math.PI * p)) / 2.0);
        try {
            fmod.javafmod.FMOD_Channel_SetVolume(channel, v);
        } catch (Throwable t) {
            // gone
        }
        return true;
    }

    /** Fade the track out over ms (one already fading keeps its own pace). */
    @LuaMethod(name = "knoxMusicFadeOut", global = true)
    public static boolean knoxMusicFadeOut(double ms) {
        fadeStart((long) ms);
        return fadeFrom != 0L;
    }

    @LuaMethod(name = "knoxMusicFadeStep", global = true)
    public static boolean knoxMusicFadeStep() {
        return fadeStep();
    }

    private static java.lang.reflect.Field fDone, fPlayer, fShown;
    private static boolean fieldsTried;

    /** Has the world loaded, "Click to start" up (GameLoadingState's own flags)? */
    static boolean loaded() {
        try {
            if (!fieldsTried) {
                fieldsTried = true;
                Class<?> c = zombie.gameStates.GameLoadingState.class;
                java.lang.reflect.Field a = c.getDeclaredField("done"), b = c.getDeclaredField("playerCreated"),
                    d = c.getDeclaredField("showedClickToSkip");
                a.setAccessible(true);
                b.setAccessible(true);
                d.setAccessible(true);
                fDone = a;
                fPlayer = b;
                fShown = d;
            }
            return fDone != null && fDone.getBoolean(null) && fPlayer.getBoolean(null) && fShown.getBoolean(null);
        } catch (Throwable t) {
            return false;
        }
    }

    /** Every frame of the loading screen (KnoxLoading's patch of its render). */
    public static void loadingFrame() {
        try {
            if (channel == 0L) return;
            // (no fade here: the track plays on over "Click to start" and fades
            // after the click, in the game - begun at the world's load it was
            // nearly gone by the click: the author, 2026-10-16)
            if (fadeFrom != 0L) fadeStep();
            else apply();
        } catch (Throwable t) {
            // the music goes on as it is; the game stops it
        }
    }

    /**
     * The game's music (the one FMOD event "Music/Main" behind every vanilla track)
     * goes through the bus "bus:/Music": muted while another theme plays in the menu,
     * back when the game's own is chosen or a game starts.
     */
    @LuaMethod(name = "knoxMusicMuteGame", global = true)
    public static void knoxMusicMuteGame(boolean mute) {
        try {
            long bus = fmod.javafmod.FMOD_Studio_System_GetBus("bus:/Music");
            if (bus != 0L) fmod.javafmod.FMOD_Studio_Bus_SetMute(bus, mute);
        } catch (Throwable t) {
            // left as it is
        }
    }

    // ---------------------------------------------------------------- mods' music

    /**
     * per GameSound: is it a mod's music (asked once a sound script). Not per
     * emitter's sound: the emitter takes those from a pool, and one that had
     * played a click stayed "not music" when it came back with The Walking
     * Dead's next track - which then played over the radio (the author,
     * 2026-10-21).
     */
    static final java.util.Map<Object, Boolean> FOREIGN =
        java.util.Collections.synchronizedMap(new java.util.WeakHashMap<>());
    static java.lang.reflect.Field emInstances, emToStart, sClip;
    /**
     * what mods' music is turned to now: 1 = as the mod plays it. (Public, as is
     * isForeignMusic: the patch's code is woven into the game's class, which may
     * reach only public members - package-private ones crashed the game at start,
     * IllegalAccessError, 2026-10-20.)
     */
    public static volatile float foreignGain = 1f;

    /** Is this sound of the UI emitter a mod's music (not Knox's own)? */
    public static boolean isForeignMusic(Object s) {
        zombie.audio.GameSound gs;
        try {
            if (sClip == null) sClip = KnoxMenu.find(s.getClass(), "clip");
            zombie.audio.GameSoundClip clip = sClip == null ? null : (zombie.audio.GameSoundClip) sClip.get(s);
            gs = clip == null ? null : clip.gameSound;
        } catch (Throwable t) {
            return false;
        }
        if (gs == null) return false;
        Boolean known = FOREIGN.get(gs);
        if (known != null) return known;
        String name = gs.getName();
        String cat = gs.getCategory();
        boolean music = !(name != null && name.startsWith("Knox"))   // the radio's own
            && (gs.master == zombie.audio.GameSound.MasterVolume.Music
                || (cat != null && cat.toLowerCase(Locale.ROOT).contains("music")));
        FOREIGN.put(gs, music);
        return music;
    }

    /**
     * The volume the emitter gives a sound, every tick (FMODSoundEmitter's sounds
     * ask getVolume() and pass it to FMOD): a mod's music comes out at
     * foreignGain of it. So a mod's next track starts as quiet as its last one
     * was - setting its volume field each frame from Lua let a new track sound
     * out at full before it was caught, and the mod's own changes fought it (the
     * author, 2026-10-20: The Walking Dead's music came on, then broke off as its
     * track changed).
     */
    @Patch(className = "fmod.fmod.FMODSoundEmitter$Sound", methodName = "getVolume")
    public static class ForeignVolume {
        @Patch.OnExit
        public static void exit(@Patch.This Object self, @Patch.Return(readOnly = false) float result) {
            if (KnoxMusic.foreignGain < 0.999f && KnoxMusic.isForeignMusic(self)) result = result * KnoxMusic.foreignGain;
        }
    }

    /**
     * Music that mods play in the main menu themselves, through the game's UI
     * emitter (a soundtrack mod with a playlist of its own - The Walking Dead's,
     * 2026-10-16: it played over Knox's radio whatever was chosen, and the radio
     * could not stop it). Any sound on that emitter whose category or volume
     * slider is music, but Knox's own, comes out at `gain` of its own volume (the
     * ForeignVolume patch above): the radio's volume with the game's music chosen,
     * 0 with the player's own music, on pause or stopped (muted, not stopped -
     * stopped, such a mod starts its next track at once), 1 to give it back as it
     * was. Returns how many such sounds play.
     */
    @LuaMethod(name = "knoxMusicForeign", global = true)
    public static int knoxMusicForeign(double gain) {
        foreignGain = (float) Math.max(0, Math.min(1, gain));
        try {
            if (!(zombie.SoundManager.instance instanceof zombie.SoundManager)) return 0;
            fmod.fmod.FMODSoundEmitter em = ((zombie.SoundManager) zombie.SoundManager.instance).getUIEmitter();
            if (em == null) return 0;
            if (emInstances == null) {
                emInstances = KnoxMenu.find(em.getClass(), "instances");
                emToStart = KnoxMenu.find(em.getClass(), "toStart");
            }
            if (emInstances == null) return 0;
            int n = 0;
            for (java.lang.reflect.Field lf : new java.lang.reflect.Field[] {emInstances, emToStart}) {
                if (lf == null) continue;
                java.util.ArrayList<?> list = (java.util.ArrayList<?>) lf.get(em);
                for (int i = 0; i < list.size(); i++) {
                    Object s = list.get(i);
                    if (s != null && isForeignMusic(s)) n++;
                }
            }
            return n;
        } catch (Throwable t) {
            return 0;
        }
    }
}
