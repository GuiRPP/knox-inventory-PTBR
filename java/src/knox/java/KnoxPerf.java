package knox.java;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;

import se.krka.kahlua.integration.annotations.LuaMethod;
import se.krka.kahlua.vm.LuaClosure;
import zombie.Lua.Event;
import zombie.Lua.LuaEventManager;
import zombie.ui.UIManager;

/**
 * Knox's own performance counter (the author's task, 2026-10-24: players wrote
 * that Knox costs ms and gets worse the longer they play). Off unless the
 * Lua side (KnoxPerf.lua, dev.perf=1) asks; nothing here hangs on the game's
 * hot paths - only what Lua calls a few times in ten seconds, and the clock.
 * The game's Lua clocks (os.clock, getTimestampMs) count whole milliseconds,
 * and Knox's handlers take microseconds: hence knoxPerfNow.
 */
public class KnoxPerf {

    /** Microseconds of a steady clock (System.nanoTime), for timing one call. */
    @LuaMethod(name = "knoxPerfNow", global = true)
    public static double knoxPerfNow() {
        return System.nanoTime() / 1000.0;
    }

    /**
     * "heap used MB, heap committed MB, heap max MB, GC count, GC ms, FPS,
     * UI elements, device text lines" - tab-separated, for knox_perf.txt.
     */
    @LuaMethod(name = "knoxPerfStats", global = true)
    public static String knoxPerfStats() {
        Runtime rt = Runtime.getRuntime();
        double mb = 1024.0 * 1024.0;
        long gcCount = -1, gcMs = -1;
        try {
            gcCount = 0;
            gcMs = 0;
            for (GarbageCollectorMXBean gc : ManagementFactory.getGarbageCollectorMXBeans()) {
                if (gc.getCollectionCount() > 0) gcCount += gc.getCollectionCount();
                if (gc.getCollectionTime() > 0) gcMs += gc.getCollectionTime();
            }
        } catch (RuntimeException | LinkageError e) {
            gcCount = -1;
            gcMs = -1;
        }
        int ui = -1;
        try {
            ui = UIManager.UI.size();
        } catch (RuntimeException | LinkageError e) {
            // (no count)
        }
        int lines = 0;
        synchronized (KnoxDeviceText.lines) {
            for (java.util.ArrayDeque<KnoxDeviceText.Line> q : KnoxDeviceText.lines.values()) lines += q.size();
        }
        return String.format(Locale.ROOT, "%.1f\t%.1f\t%.1f\t%d\t%d\t%.1f\t%d\t%d",
            (rt.totalMemory() - rt.freeMemory()) / mb, rt.totalMemory() / mb, rt.maxMemory() / mb,
            gcCount, gcMs, fps(), ui, lines);
    }

    static float fps() {
        try {
            return zombie.GameWindow.averageFPS;
        } catch (RuntimeException | LinkageError e) {
            return -1f;
        }
    }

    /**
     * How many handlers each event has, and how many of them were written in
     * Knox's files (by the file of the closure): "OnTick=9/41 OnPreUIDraw=11/30 ..."
     * for every event that has one of Knox's. The game drops them all on the
     * way to the menu (IngameState.exit); this shows they don't pile up within
     * a game either. (A profiler that wraps handlers - PeePee - hands the game
     * its own closures: they count as not Knox's.)
     */
    @LuaMethod(name = "knoxPerfHandlers", global = true)
    public static String knoxPerfHandlers() {
        ArrayList<Event> list = new ArrayList<>();
        HashMap<String, Event> map = new HashMap<>();
        try {
            LuaEventManager.getEvents(list, map);
        } catch (RuntimeException | LinkageError e) {
            return "?";
        }
        StringBuilder sb = new StringBuilder();
        for (Event e : list) {
            int all = e.callbacks.size(), knox = 0;
            for (int i = 0; i < all; i++) {
                if (isKnox(e.callbacks.get(i))) knox++;
            }
            if (knox == 0) continue;
            if (sb.length() > 0) sb.append(' ');
            sb.append(e.name).append('=').append(knox).append('/').append(all);
        }
        return sb.toString();
    }

    static boolean isKnox(LuaClosure c) {
        if (c == null || c.prototype == null || c.prototype.filename == null) return false;
        String f = c.prototype.filename.replace('\\', '/');
        return f.contains("/Knox/Knox");
    }
}
