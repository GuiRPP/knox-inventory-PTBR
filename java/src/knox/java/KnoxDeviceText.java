package knox.java;

import java.util.ArrayDeque;
import java.util.WeakHashMap;

import me.zed_0xff.zombie_buddy.Patch;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.GameTime;
import zombie.chat.ChatElement;
import zombie.inventory.types.Radio;
import zombie.iso.objects.IsoWaveSignal;
import zombie.radio.devices.DeviceData;
import zombie.ui.UIFont;
import zombie.vehicles.VehiclePart;

/**
 * What a television or a radio says, for Knox's TV and radio windows: the
 * TV's subtitles, the radio's paper tape. The game shows these lines only over
 * the device (or, for a radio in hand, over the character) and tells Lua only
 * about the ones that carry skill or mood codes (OnDeviceText), so every line
 * a device shows is kept here: the last ones per device, with the frequency
 * and the game time they came at.
 * While a device's window is open its lines are not shown in the world.
 *
 * Every advice of a patch on an overloaded method names the same arguments:
 * an advice without them made ZombieBuddy apply the patch to every overload,
 * and the ones it didn't fit failed the whole class.
 */
public class KnoxDeviceText {

    public static final class Line {
        public long seq;
        public long ms;
        public String text;
        public float r, g, b;
        public int channel;
        public float timeOfDay;
    }

    static final int KEEP = 200;
    static final WeakHashMap<Object, ArrayDeque<Line>> lines = new WeakHashMap<>();
    static long seq;

    public static void add(Object device, DeviceData d, String text, float r, float g, float b) {
        if (device == null || text == null) return;
        Line l = new Line();
        l.text = text.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ');
        l.r = r;
        l.g = g;
        l.b = b;
        l.ms = System.currentTimeMillis();
        l.channel = d != null ? d.getChannel() : 0;
        l.timeOfDay = GameTime.getInstance().getTimeOfDay();
        synchronized (lines) {
            l.seq = ++seq;
            ArrayDeque<Line> q = lines.computeIfAbsent(device, k -> new ArrayDeque<>());
            q.addLast(l);
            while (q.size() > KEEP) q.removeFirst();
        }
    }

    /**
     * The device's lines newer than `since`, one per line:
     * "seq TAB ageMs TAB r TAB g TAB b TAB channel TAB timeOfDay TAB text". Empty when none.
     */
    @LuaMethod(name = "knoxDeviceText", global = true)
    public static String knoxDeviceText(Object device, double since) {
        StringBuilder out = new StringBuilder();
        long now = System.currentTimeMillis();
        synchronized (lines) {
            ArrayDeque<Line> q = lines.get(device);
            if (q == null) return "";
            for (Line l : q) {
                if (l.seq <= since) continue;
                out.append(l.seq).append('\t').append(now - l.ms).append('\t')
                   .append(l.r).append('\t').append(l.g).append('\t').append(l.b).append('\t')
                   .append(l.channel).append('\t').append(l.timeOfDay).append('\t')
                   .append(l.text).append('\n');
            }
        }
        return out.toString();
    }

    /** Number of the last line kept (of any device). */
    @LuaMethod(name = "knoxDeviceTextSeq", global = true)
    public static double knoxDeviceTextSeq() {
        synchronized (lines) {
            return seq;
        }
    }

    // Hiding the open device's lines in the world -----------------------------------

    /** The device whose window is open: its lines are in that window, not in the world. */
    public static volatile Object hidden;
    /** Set while the hidden carried radio adds a line: the character doesn't "say" it. */
    public static boolean suppress;

    @LuaMethod(name = "knoxHideDeviceText", global = true)
    public static void knoxHideDeviceText(Object device) {
        hidden = device;
    }

    /** A device in the world draws its lines over itself here (nothing else). */
    @Patch(className = "zombie.iso.objects.IsoWaveSignal", methodName = "renderlast")
    public static class WorldText {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.This IsoWaveSignal self) {
            return self == KnoxDeviceText.hidden;
        }
    }

    /** A carried radio: the character "says" the line. */
    @Patch(className = "zombie.characters.IsoGameCharacter", methodName = "SayRadio")
    public static class PlayerSay {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) String line, @Patch.Argument(1) float r,
                                    @Patch.Argument(2) float g, @Patch.Argument(3) float b,
                                    @Patch.Argument(4) UIFont font, @Patch.Argument(5) float range,
                                    @Patch.Argument(6) int channel, @Patch.Argument(7) String type) {
            return KnoxDeviceText.suppress;
        }
    }

    // Catching the lines ----------------------------------------------------------------

    /** The overload every AddDeviceText of a device in the world ends in. */
    @Patch(className = "zombie.iso.objects.IsoWaveSignal", methodName = "AddDeviceText")
    public static class Text {
        @Patch.OnEnter
        public static void enter(@Patch.This IsoWaveSignal self,
                                 @Patch.Argument(0) String line, @Patch.Argument(1) float r,
                                 @Patch.Argument(2) float g, @Patch.Argument(3) float b,
                                 @Patch.Argument(4) String guid, @Patch.Argument(5) String codes,
                                 @Patch.Argument(6) int distance, @Patch.Argument(7) boolean attract) {
            // as the game: only a device that is on and not muted shows the line
            DeviceData d = self.getDeviceData();
            if (d != null && d.getIsTurnedOn() && d.getDeviceVolume() > 0.0f) {
                KnoxDeviceText.add(self, d, line, r, g, b);
            }
        }
    }

    /** A radio carried by the character (in hand, on the back). */
    @Patch(className = "zombie.inventory.types.Radio", methodName = "AddDeviceText")
    public static class ItemText {
        @Patch.OnEnter
        public static void enter(@Patch.This Radio self,
                                 @Patch.Argument(0) String line, @Patch.Argument(1) float r,
                                 @Patch.Argument(2) float g, @Patch.Argument(3) float b,
                                 @Patch.Argument(4) String guid, @Patch.Argument(5) String codes,
                                 @Patch.Argument(6) int distance) {
            DeviceData d = self.getDeviceData();
            if (d != null && self.getPlayer() != null && d.getDeviceVolume() > 0.0f) {
                KnoxDeviceText.add(self, d, line, r, g, b);
            }
            KnoxDeviceText.suppress = self == KnoxDeviceText.hidden;
        }

        @Patch.OnExit
        public static void exit(@Patch.Argument(0) String line, @Patch.Argument(1) float r,
                                @Patch.Argument(2) float g, @Patch.Argument(3) float b,
                                @Patch.Argument(4) String guid, @Patch.Argument(5) String codes,
                                @Patch.Argument(6) int distance) {
            KnoxDeviceText.suppress = false;
        }
    }

    /** A car's radio; while its window is open the line it just put over the car is taken off. */
    @Patch(className = "zombie.vehicles.VehiclePart", methodName = "AddDeviceText")
    public static class VehicleText {
        @Patch.OnEnter
        public static void enter(@Patch.This VehiclePart self,
                                 @Patch.Argument(0) String line, @Patch.Argument(1) float r,
                                 @Patch.Argument(2) float g, @Patch.Argument(3) float b,
                                 @Patch.Argument(4) String guid, @Patch.Argument(5) String codes,
                                 @Patch.Argument(6) int distance) {
            DeviceData d = self.getDeviceData();
            if (d != null && d.getIsTurnedOn() && d.getDeviceVolume() > 0.0f) {
                KnoxDeviceText.add(self, d, line, r, g, b);
            }
        }

        @Patch.OnExit
        public static void exit(@Patch.This VehiclePart self,
                                @Patch.Argument(0) String line, @Patch.Argument(1) float r,
                                @Patch.Argument(2) float g, @Patch.Argument(3) float b,
                                @Patch.Argument(4) String guid, @Patch.Argument(5) String codes,
                                @Patch.Argument(6) int distance) {
            if (self == KnoxDeviceText.hidden) {
                ChatElement c = self.getChatElement();
                if (c != null) {
                    for (int p = 0; p < 4; p++) c.clear(p);
                }
            }
        }
    }
}
