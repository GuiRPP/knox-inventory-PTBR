import java.lang.instrument.Instrumentation;

/** Stands for ZombieBuddy's agent in the offline Java test: hands its Instrumentation to ZombieBuddy's Loader. */
public class KnoxTestAgent {
    public static void premain(String args, Instrumentation inst) throws Exception {
        java.lang.reflect.Field f = Class.forName("me.zed_0xff.zombie_buddy.Loader").getDeclaredField("g_instrumentation");
        f.setAccessible(true);
        f.set(null, inst);
    }
}
