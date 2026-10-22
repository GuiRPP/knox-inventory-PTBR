package knox.java;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.BitSet;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.ZomboidFileSystem;

/**
 * Own music heard by the other players of a game with others (the author,
 * 2026-10-21: "the others near the car hear it as the owner does from outside").
 * The server has none of this (the jar is the client's only: ZombieBuddy skips
 * media/java/client on a server) - it passes strings on; here is what needs a
 * file or FMOD (KnoxMusicNet.lua drives it):
 *   - the owner's side: a file of Zomboid/knox_music by its SHA-256 (worked out
 *     off the game's thread), and its parts as base64 for the server to ask for
 *     (only of a file this player has named by its hash - no path comes in);
 *   - the listener's side: is a file of that hash here already (the cache, or one
 *     of the player's own files of that size), the parts as they come (checked:
 *     the length of each, the head of the first, the SHA-256 of the whole), the
 *     cache Zomboid/knox_music_cache/<sha256>.<ext> with its limit;
 *   - the others' tracks: up to four channels of their own, the most important
 *     voice (priority 0, as KnoxMusic.playFile), each with a car body of its own
 *     (KnoxCarMuffle.NET).
 * Nothing here is ever given a path from the network: a hash (64 hex) and one
 * of four extensions.
 */
public class KnoxMusicNet {

    static final int CHUNK = 16384;                 // a part's bytes (KnoxMusicNet.lua's CHUNK)
    static final long MAX_BYTES = 64L << 20;        // past any server's limit: never taken
    static final long CACHE_BYTES = 300L << 20;     // the listener's cache, the oldest go first
    static final int SLOTS = 4;                     // the others' tracks at once
    static final String[] KINDS = {"ogg", "mp3", "wav", "flac"};

    private static final ExecutorService WORK = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "KnoxMusicNet");
        t.setDaemon(true);
        return t;
    });

    // ------------------------------------------------------------------ checks

    static boolean isHex(String h) {
        if (h == null || h.length() != 64) return false;
        for (int i = 0; i < 64; i++) {
            char c = h.charAt(i);
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
        }
        return true;
    }

    static boolean isKind(String ext) {
        for (String k : KINDS) {
            if (k.equals(ext)) return true;
        }
        return false;
    }

    static String kindOf(File f) {
        String n = f.getName().toLowerCase(Locale.ROOT);
        int dot = n.lastIndexOf('.');
        String ext = dot < 0 ? "" : n.substring(dot + 1);
        return isKind(ext) ? ext : null;
    }

    /** Does a file of this kind start so (its own signature)? */
    static boolean audioHead(byte[] b, int n, String ext) {
        boolean id3 = n >= 3 && b[0] == 'I' && b[1] == 'D' && b[2] == '3';
        switch (ext) {
            case "ogg":
                return n >= 4 && b[0] == 'O' && b[1] == 'g' && b[2] == 'g' && b[3] == 'S';
            case "flac":
                return id3 || (n >= 4 && b[0] == 'f' && b[1] == 'L' && b[2] == 'a' && b[3] == 'C');
            case "wav":
                return n >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                    && b[8] == 'W' && b[9] == 'A' && b[10] == 'V' && b[11] == 'E';
            case "mp3":
                return id3 || (n >= 2 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xE0) == 0xE0);
            default:
                return false;
        }
    }

    static boolean audioFile(File f, String ext) {
        byte[] b = new byte[12];
        try (InputStream in = new FileInputStream(f)) {
            int n = in.readNBytes(b, 0, 12);
            return audioHead(b, n, ext);
        } catch (Throwable t) {
            return false;
        }
    }

    static String sha256(File f) {
        try (InputStream in = new FileInputStream(f)) {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] buf = new byte[1 << 16];
            int n;
            while ((n = in.read(buf)) > 0) md.update(buf, 0, n);
            StringBuilder sb = new StringBuilder(64);
            for (byte x : md.digest()) sb.append(String.format("%02x", x & 0xFF));
            return sb.toString();
        } catch (Throwable t) {
            return null;
        }
    }

    static File cacheDir() {
        File dir = new File(ZomboidFileSystem.instance.getCacheDir(), "knox_music_cache");
        if (!dir.isDirectory()) dir.mkdirs();
        return dir;
    }

    // ------------------------------------------------------------------ hashes of files here

    /** A file's hash as worked out, kept while the file is as it was then. */
    static final class Hashed {
        final long size, mtime;
        final String hex;   // null: not music (no hash, never shared)

        Hashed(long size, long mtime, String hex) {
            this.size = size;
            this.mtime = mtime;
            this.hex = hex;
        }
    }

    static final ConcurrentHashMap<String, Hashed> BY_PATH = new ConcurrentHashMap<>();
    static final ConcurrentHashMap<String, Boolean> HASHING = new ConcurrentHashMap<>();
    /** hash -> a file here with it: own (announced), found among the player's own, cached */
    static final ConcurrentHashMap<String, File> BY_HASH = new ConcurrentHashMap<>();
    /** the hashes this player has announced: only their parts are ever read out */
    static final ConcurrentHashMap<String, File> OWN = new ConcurrentHashMap<>();

    static Hashed known(File f) {
        Hashed h = BY_PATH.get(f.getAbsolutePath());
        return h != null && h.size == f.length() && h.mtime == f.lastModified() ? h : null;
    }

    /** Work the file's hash out off the game's thread (once at a time per file). */
    static void hashLater(File f) {
        String key = f.getAbsolutePath();
        if (HASHING.putIfAbsent(key, Boolean.TRUE) != null) return;
        WORK.execute(() -> {
            try {
                long size = f.length(), mtime = f.lastModified();
                String ext = kindOf(f);
                String hex = (ext != null && size > 0 && size <= MAX_BYTES && audioFile(f, ext)) ? sha256(f) : null;
                BY_PATH.put(key, new Hashed(size, mtime, hex));
                if (hex != null) BY_HASH.putIfAbsent(hex, f);
            } finally {
                HASHING.remove(key);
            }
        });
    }

    /**
     * The owner's track: "hash|size|ext" of a file of the folder ("Song.mp3",
     * "Album/Song.mp3"); "" while it is worked out; "-" for one not to share
     * (not music by its head, too big); nil for no such file.
     */
    @LuaMethod(name = "knoxNetHash", global = true)
    public static String knoxNetHash(String name) {
        File f = KnoxMusic.resolve(name);
        if (f == null || !f.isFile()) return null;
        Hashed h = known(f);
        if (h == null) {
            hashLater(f);
            return "";
        }
        if (h.hex == null) return "-";
        OWN.put(h.hex, f);
        BY_HASH.put(h.hex, f);
        return h.hex + "|" + h.size + "|" + kindOf(f);
    }

    /** A part of one's own announced file, base64; nil for another hash or a changed file. */
    @LuaMethod(name = "knoxNetChunk", global = true)
    public static String knoxNetChunk(String hex, double index) {
        File f = isHex(hex) ? OWN.get(hex) : null;
        if (f == null) return null;
        Hashed h = known(f);
        if (h == null || !hex.equals(h.hex)) return null;
        long at = (long) index * CHUNK;
        if (index < 0 || at >= h.size) return null;
        int n = (int) Math.min(CHUNK, h.size - at);
        byte[] b = new byte[n];
        try (RandomAccessFile raf = new RandomAccessFile(f, "r")) {
            raf.seek(at);
            raf.readFully(b);
        } catch (Throwable t) {
            return null;
        }
        return Base64.getEncoder().encodeToString(b);
    }

    // ------------------------------------------------------------------ the listener: is it here?

    // the player's own files by their size (a match by size only is then hashed)
    private static HashMap<Long, List<File>> bySize;
    private static long bySizeAt;

    static List<File> ownOfSize(long size) {
        long now = System.currentTimeMillis();
        if (bySize == null || now - bySizeAt > 30000L) {
            HashMap<Long, List<File>> m = new HashMap<>();
            for (String name : KnoxMusic.knoxMusicList().split("\n")) {
                if (name.isEmpty()) continue;
                File f = KnoxMusic.resolve(name);
                if (f != null && f.isFile()) m.computeIfAbsent(f.length(), k -> new ArrayList<>()).add(f);
            }
            bySize = m;
            bySizeAt = now;
        }
        List<File> l = bySize.get(size);
        return l != null ? l : List.of();
    }

    static File cached(String hex, String ext) {
        return new File(cacheDir(), hex + "." + ext);
    }

    /** The file of this hash here, or null. */
    static File fileOf(String hex) {
        File f = BY_HASH.get(hex);
        if (f != null) {
            Hashed h = known(f);
            if (f.isFile() && (h == null || hex.equals(h.hex))) return f;
            BY_HASH.remove(hex);
        }
        for (String k : KINDS) {
            File c = cached(hex, k);
            if (c.isFile()) return c;
        }
        return null;
    }

    /**
     * Is the file of this hash here: 1 yes (the cache, or one of the player's
     * own); 0 no (to be fetched); -1 being looked at (one of the player's own of
     * that size is being hashed); -2 never (not a hash, a kind, a size taken).
     */
    @LuaMethod(name = "knoxNetHave", global = true)
    public static double knoxNetHave(String hex, double size, String ext) {
        if (!isHex(hex) || !isKind(ext) || size <= 0 || size > MAX_BYTES) return -2;
        File c = cached(hex, ext);
        if (c.isFile() && c.length() == (long) size) {
            c.setLastModified(System.currentTimeMillis());
            BY_HASH.put(hex, c);
            return 1;
        }
        if (BY_HASH.containsKey(hex) && fileOf(hex) != null) return 1;
        boolean waiting = false;
        for (File f : ownOfSize((long) size)) {
            Hashed h = known(f);
            if (h == null) {
                hashLater(f);
                waiting = true;
            } else if (hex.equals(h.hex)) {
                BY_HASH.put(hex, f);
                return 1;
            }
        }
        if (waiting) return -1;
        Receiving r = RECV.get(hex);
        return r != null && r.state == 2 ? -1 : 0;
    }

    // ------------------------------------------------------------------ the listener: the parts coming

    static final class Receiving {
        final String hex, ext;
        final long size;
        final int parts;
        final BitSet got;
        final File part;
        RandomAccessFile raf;
        volatile int state = 1;   // 1 receiving, 2 checking, 3 done, -1 failed

        Receiving(String hex, long size, String ext, File part) {
            this.hex = hex;
            this.size = size;
            this.ext = ext;
            this.parts = (int) ((size + CHUNK - 1) / CHUNK);
            this.got = new BitSet(parts);
            this.part = part;
        }

        void close() {
            try {
                if (raf != null) raf.close();
            } catch (Throwable t) {
                // closed
            }
            raf = null;
        }
    }

    static final ConcurrentHashMap<String, Receiving> RECV = new ConcurrentHashMap<>();

    /** The parts of a file of this hash are to come (false: not taken). */
    @LuaMethod(name = "knoxNetRecvBegin", global = true)
    public static boolean knoxNetRecvBegin(String hex, double size, String ext) {
        if (!isHex(hex) || !isKind(ext) || size <= 0 || size > MAX_BYTES) return false;
        Receiving r = RECV.get(hex);
        if (r != null && r.state > 0) return true;
        if (r != null) RECV.remove(hex);
        File part = new File(cacheDir(), hex + ".part");
        try {
            Receiving n = new Receiving(hex, (long) size, ext, part);
            n.raf = new RandomAccessFile(part, "rw");
            n.raf.setLength(n.size);
            RECV.put(hex, n);
            return true;
        } catch (Throwable t) {
            part.delete();
            return false;
        }
    }

    /**
     * A part come: 0 taken (more to come), 2 the last one (the whole is being
     * checked: knoxNetRecvState), -1 refused (the file given up).
     */
    @LuaMethod(name = "knoxNetRecv", global = true)
    public static double knoxNetRecv(String hex, double index, String b64) {
        Receiving r = isHex(hex) ? RECV.get(hex) : null;
        if (r == null || r.state == -1) return -1;
        if (r.state != 1 || r.raf == null) return 0;   // (a part again, the whole already here)
        int i = (int) index;
        if (i < 0 || i >= r.parts || b64 == null) return fail(r);
        if (r.got.get(i)) return 0;
        byte[] b;
        try {
            b = Base64.getDecoder().decode(b64);
        } catch (Throwable t) {
            return fail(r);
        }
        long at = (long) i * CHUNK;
        if (b.length != (int) Math.min(CHUNK, r.size - at)) return fail(r);
        if (i == 0 && !audioHead(b, b.length, r.ext)) return fail(r);
        try {
            r.raf.seek(at);
            r.raf.write(b);
        } catch (Throwable t) {
            return fail(r);
        }
        r.got.set(i);
        if (r.got.cardinality() < r.parts) return 0;
        r.close();
        r.state = 2;
        WORK.execute(() -> check(r));
        return 2;
    }

    static double fail(Receiving r) {
        r.close();
        r.state = -1;
        r.part.delete();
        return -1;
    }

    /** The whole file: its hash as said, then into the cache (the oldest out past its limit). */
    static void check(Receiving r) {
        String hex = sha256(r.part);
        if (!r.hex.equals(hex) || !audioFile(r.part, r.ext)) {
            r.part.delete();
            r.state = -1;
            return;
        }
        File to = cached(r.hex, r.ext);
        to.delete();
        if (!r.part.renameTo(to)) {
            r.part.delete();
            r.state = -1;
            return;
        }
        BY_HASH.put(r.hex, to);
        prune(to);
        r.state = 3;
    }

    static void prune(File keep) {
        File[] files = cacheDir().listFiles();
        if (files == null) return;
        long total = 0;
        for (File f : files) total += f.length();
        if (total <= CACHE_BYTES) return;
        Arrays.sort(files, (a, b) -> Long.compare(a.lastModified(), b.lastModified()));
        for (File f : files) {
            if (total <= CACHE_BYTES) break;
            if (f.equals(keep) || f.getName().endsWith(".part")) continue;
            total -= f.length();
            f.delete();
        }
    }

    /** 0 nothing coming, 1 receiving, 2 checking, 3 done (in the cache), -1 failed. */
    @LuaMethod(name = "knoxNetRecvState", global = true)
    public static double knoxNetRecvState(String hex) {
        Receiving r = isHex(hex) ? RECV.get(hex) : null;
        if (r == null) return 0;
        if (r.state == 3 || r.state == -1) RECV.remove(hex);
        return r.state;
    }

    /** The first part still missing (to ask for again), -1 for none. */
    @LuaMethod(name = "knoxNetRecvNext", global = true)
    public static double knoxNetRecvNext(String hex) {
        Receiving r = isHex(hex) ? RECV.get(hex) : null;
        if (r == null || r.state != 1) return -1;
        int i = r.got.nextClearBit(0);
        return i < r.parts ? i : -1;
    }

    @LuaMethod(name = "knoxNetRecvCancel", global = true)
    public static void knoxNetRecvCancel(String hex) {
        Receiving r = isHex(hex) ? RECV.remove(hex) : null;
        if (r != null && r.state == 1) {
            r.close();
            r.part.delete();
        }
    }

    /** A cached file FMOD could not play: gone, not to be played again. */
    @LuaMethod(name = "knoxNetForget", global = true)
    public static void knoxNetForget(String hex) {
        if (!isHex(hex)) return;
        BY_HASH.remove(hex);
        for (String k : KINDS) {
            File c = cached(hex, k);
            if (c.isFile()) c.delete();
        }
    }

    // ------------------------------------------------------------------ the others' tracks

    private static final long[] SND = new long[SLOTS], CH = new long[SLOTS];

    static boolean slotOk(double slot) {
        return slot >= 0 && slot < SLOTS;
    }

    /** Play the file of this hash in slot 0..3 from posMs, at a volume, paused or not. */
    @LuaMethod(name = "knoxNetPlay", global = true)
    public static boolean knoxNetPlay(double slot, String hex, double posMs, double volume, boolean paused) {
        if (!slotOk(slot)) return false;
        int s = (int) slot;
        knoxNetStop(slot);
        File f = isHex(hex) ? fileOf(hex) : null;
        if (f == null) return false;
        try {
            SND[s] = fmod.javafmod.FMOD_System_CreateSound(f.getAbsolutePath(), KnoxMusic.MODE);
            if (SND[s] == 0L) return false;
            CH[s] = fmod.javafmod.FMOD_System_PlaySound(SND[s], true);
            if (CH[s] == 0L) {
                knoxNetStop(slot);
                return false;
            }
            fmod.javafmod.FMOD_Channel_SetPriority(CH[s], 0);   // (see KnoxMusic.playFile)
            fmod.javafmod.FMOD_Channel_SetVolume(CH[s], (float) volume);
            if (posMs > 0) fmod.javafmod.FMOD_Channel_SetPosition(CH[s], (long) posMs);
            fmod.javafmod.FMOD_Channel_SetPaused(CH[s], paused);
            return true;
        } catch (Throwable t) {
            knoxNetStop(slot);
            return false;
        }
    }

    @LuaMethod(name = "knoxNetVolume", global = true)
    public static void knoxNetVolume(double slot, double volume) {
        if (!slotOk(slot)) return;
        try {
            if (CH[(int) slot] != 0L) fmod.javafmod.FMOD_Channel_SetVolume(CH[(int) slot], (float) volume);
        } catch (Throwable t) {
            // gone
        }
    }

    /** Heard from outside its car (KnoxCarMuffle, dark 0..1, open 0..1); a negative dark: from inside. */
    @LuaMethod(name = "knoxNetMuffle", global = true)
    public static void knoxNetMuffle(double slot, double dark, double open) {
        if (!slotOk(slot)) return;
        long ch = CH[(int) slot];
        if (ch == 0L) return;
        KnoxCarMuffle.NET[(int) slot].set(ch, dark < 0 ? -1f : (float) Math.min(1.0, dark),
            (float) Math.max(0.0, Math.min(1.0, open)));
    }

    /** The radio's sound of the owner's set, as a plain low-pass (1: off). */
    @LuaMethod(name = "knoxNetLowPass", global = true)
    public static void knoxNetLowPass(double slot, double gain) {
        if (!slotOk(slot)) return;
        try {
            if (CH[(int) slot] != 0L) fmod.javafmod.FMOD_Channel_SetLowPassGain(CH[(int) slot], (float) Math.max(0.0, Math.min(1.0, gain)));
        } catch (Throwable t) {
            // gone
        }
    }

    @LuaMethod(name = "knoxNetPause", global = true)
    public static void knoxNetPause(double slot, boolean paused) {
        if (!slotOk(slot)) return;
        try {
            if (CH[(int) slot] != 0L) fmod.javafmod.FMOD_Channel_SetPaused(CH[(int) slot], paused);
        } catch (Throwable t) {
            // gone
        }
    }

    @LuaMethod(name = "knoxNetSeek", global = true)
    public static void knoxNetSeek(double slot, double ms) {
        if (!slotOk(slot)) return;
        try {
            if (CH[(int) slot] != 0L) fmod.javafmod.FMOD_Channel_SetPosition(CH[(int) slot], (long) Math.max(0.0, ms));
        } catch (Throwable t) {
            // gone
        }
    }

    @LuaMethod(name = "knoxNetPosition", global = true)
    public static double knoxNetPosition(double slot) {
        if (!slotOk(slot)) return 0;
        try {
            return CH[(int) slot] != 0L ? (double) fmod.javafmod.FMOD_Channel_GetPosition(CH[(int) slot], 1) : 0.0;
        } catch (Throwable t) {
            return 0.0;
        }
    }

    /** Still playing (true while paused too; false once it has ended)? */
    @LuaMethod(name = "knoxNetPlaying", global = true)
    public static boolean knoxNetPlaying(double slot) {
        if (!slotOk(slot)) return false;
        try {
            return CH[(int) slot] != 0L && fmod.javafmod.FMOD_Channel_IsPlaying(CH[(int) slot]);
        } catch (Throwable t) {
            return false;
        }
    }

    @LuaMethod(name = "knoxNetStop", global = true)
    public static void knoxNetStop(double slot) {
        if (!slotOk(slot)) return;
        int s = (int) slot;
        KnoxCarMuffle.NET[s].detach();
        try {
            if (CH[s] != 0L) fmod.javafmod.FMOD_Channel_Stop(CH[s]);
        } catch (Throwable t) {
            // gone
        }
        try {
            if (SND[s] != 0L) fmod.javafmod.FMOD_Sound_Release(SND[s]);
        } catch (Throwable t) {
            // gone
        }
        CH[s] = 0L;
        SND[s] = 0L;
    }

    /** All the others' tracks off, the parts coming given up (Lua loaded anew, the game left). */
    @LuaMethod(name = "knoxNetStopAll", global = true)
    public static void knoxNetStopAll() {
        for (int s = 0; s < SLOTS; s++) knoxNetStop(s);
        for (String hex : new ArrayList<>(RECV.keySet())) knoxNetRecvCancel(hex);
    }
}
