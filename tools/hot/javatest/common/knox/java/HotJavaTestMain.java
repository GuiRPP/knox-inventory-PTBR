package knox.java;

import java.io.File;
import java.lang.reflect.Method;

/**
 * The offline Java test of the DEV reloader (tools/hot/javatest/test.ps1): version 1 of the
 * classes is "the jar", ZombieBuddy's own engine writes the patch into knoxhottarget.Target,
 * then version 2 is swapped in by KnoxHotJava as in the game.
 */
public class HotJavaTestMain {
    static int fails = 0;

    static void check(String what, Object got, Object want) {
        boolean ok = want.equals(got);
        if (!ok) fails++;
        System.out.println((ok ? "pass " : "FAIL ") + what + ": " + got + (ok ? "" : " (want " + want + ")"));
    }

    public static void main(String[] args) throws Exception {
        Class<?> loader = Class.forName("me.zed_0xff.zombie_buddy.Loader");
        Class<?> phase = Class.forName("me.zed_0xff.zombie_buddy.Loader$Phase");
        Method apply = loader.getDeclaredMethod("ApplyPatchesFromPackage", String.class, ClassLoader.class, phase);
        apply.setAccessible(true);
        // (as ZombieBuddy's loader does for a mod's jar: it scans the jars it added)
        java.lang.reflect.Field known = loader.getDeclaredField("g_known_jars");
        known.setAccessible(true);
        @SuppressWarnings("unchecked")
        java.util.Set<java.nio.file.Path> jars = (java.util.Set<java.nio.file.Path>) known.get(null);
        jars.add(new File(args[1]).toPath());
        Object main = null;
        for (Object c : phase.getEnumConstants()) if (c.toString().equals("MAIN")) main = c;
        apply.invoke(null, "knox.java", null, main);
        check("before: plain", HotProbe.plain(), "v1");
        check("before: patched game class", knoxhottarget.Target.value(), "base+p1");
        check("before: shape", HotShape.a(), "a1");
        KnoxHotJava.setHotDir(new File(args[0]));
        String r = KnoxHotJava.apply();
        System.out.println("apply:\n" + r);
        boolean jbr = KnoxHotJava.enhanced();
        if (!jbr) {
            // plain Java: HotShape got a method - the whole build waits (nothing half-swapped)
            check("after: shape needs a restart on plain Java", r.contains("restart\tknox.java.HotShape"), true);
            check("after: it is HotShape that is named, not the others", r.contains("restart\tknox.java.HotProbe\t") || r.contains("restart\tknox.java.HotProbe$"), false);
            check("after: the new class waits too", r.contains("wait\tknox.java.HotProbe2"), true);
            check("after: the rest of the build waits with it", HotProbe.plain(), "v1");
            check("after: the patch waits too", knoxhottarget.Target.value(), "base+p1");
            check("again: the same build is not said twice", KnoxHotJava.apply(), "none");
            // the author takes the new method back out: the rest goes in
            java.nio.file.Files.copy(new File(args[2], "knox/java/HotShape.class").toPath(),
                new File(args[0], "classes/knox/java/HotShape.class").toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            r = KnoxHotJava.apply();
            System.out.println("apply after the fix:\n" + r);
        }
        check("after: new class", Class.forName("knox.java.HotProbe2").getMethod("hello").invoke(null), "new");
        check("after: plain (body swapped)", HotProbe.plain(), "v2");
        check("after: patched game class (patch written again)", knoxhottarget.Target.value(), "base+p2");
        if (jbr) check("after: shape (JBR: a method added)", HotShape.a(), "a2");
        check("again: nothing changed", KnoxHotJava.apply(), "none");
        System.out.println(fails == 0 ? "javatest: all pass" + (jbr ? " (JBR)" : "") : "javatest: " + fails + " FAIL");
        System.exit(fails == 0 ? 0 : 1);
    }
}
