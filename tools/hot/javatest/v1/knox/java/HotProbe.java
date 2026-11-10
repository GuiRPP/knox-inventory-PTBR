package knox.java;

import me.zed_0xff.zombie_buddy.Patch;

/** Version 1 of a class of Knox's for the offline Java test (tools/hot/javatest). */
public class HotProbe {
    public static String plain() {
        return "v1";
    }

    @Patch(className = "knoxhottarget.Target", methodName = "value")
    public static class Pt {
        @Patch.OnExit
        public static void exit(@Patch.Return(readOnly = false) String r) {
            r = r + "+p1";
        }
    }
}
