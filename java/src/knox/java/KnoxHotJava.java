package knox.java;

import java.io.File;
import java.io.InputStream;
import java.lang.instrument.ClassDefinition;
import java.lang.instrument.Instrumentation;
import java.lang.invoke.MethodHandles;
import java.lang.management.ManagementFactory;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.net.URL;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import se.krka.kahlua.integration.annotations.LuaMethod;

/**
 * The DEV reloader's Java part: Knox's classes swapped in a game that is going (the author
 * 2026-11-10: "no restart at all, even when you change something in Java"). Steps 2-4 of the
 * plan in ROADMAP ("Правки без перезахода в игру"):
 *  - a class the game has loaded gets its new bytes (Instrumentation.redefineClasses - ZombieBuddy
 *    is a Java agent that may redefine and retransform, its Instrumentation is taken from it);
 *    on the usual Java (HotSpot) only the bodies of methods may change; a new method, field or
 *    lambda needs the game started on JetBrains Runtime with -XX:+AllowEnhancedClassRedefinition
 *    (tools\hot\run_jbr.ps1), where they may too;
 *  - a class it has not loaded yet, or a new one, is defined from the new bytes in Knox's own
 *    class loader and package;
 *  - a ZombieBuddy patch (@Patch): its code is written into the game's class (Advice), so the
 *    game's class is transformed again (retransformClasses) - ZombieBuddy reads the patch's
 *    bytes from Knox's class loader, so the fast build's folder is put in front of Knox's jar
 *    for that loader first;
 *  - a class with Lua functions (@LuaMethod) is exposed again (new functions appear in Lua).
 * The new classes come from java/build/hot/classes (java\hot.ps1 builds them there; the jar
 * itself is held by the game and can't be written).
 */
public final class KnoxHotJava {

    private static File hotDir;
    private static Instrumentation inst;
    private static boolean instTried;
    private static final HashMap<String, byte[]> current = new HashMap<>();   // class name -> the bytes the game has now
    private static final HashMap<String, byte[]> refused = new HashMap<>();   // class name -> bytes it could not take (said once)
    private static boolean frontDone;
    private static String frontError;

    static void setHotDir(File dir) {
        hotDir = dir;
    }

    static Instrumentation instrumentation() {
        if (!instTried) {
            instTried = true;
            try {
                Class<?> loader = Class.forName("me.zed_0xff.zombie_buddy.Loader");
                Field f = loader.getDeclaredField("g_instrumentation");
                f.setAccessible(true);
                inst = (Instrumentation) f.get(null);
            } catch (Throwable t) {
                inst = null;
            }
        }
        return inst;
    }

    static boolean available() {
        Instrumentation i = instrumentation();
        return i != null && i.isRedefineClassesSupported();
    }

    /** JetBrains Runtime with the whole-class redefinition switched on. */
    @SuppressWarnings({"unchecked", "rawtypes"})
    static boolean enhanced() {
        try {
            if (!String.valueOf(System.getProperty("java.vm.vendor")).contains("JetBrains")) return false;
            Class<?> beanClass = Class.forName("com.sun.management.HotSpotDiagnosticMXBean");
            Object bean = ManagementFactory.getPlatformMXBean((Class) beanClass);
            Object opt = beanClass.getMethod("getVMOption", String.class).invoke(bean, "AllowEnhancedClassRedefinition");
            return "true".equals(opt.getClass().getMethod("getValue").invoke(opt));
        } catch (Throwable t) {
            return false;
        }
    }

    // ----------------------------------------------------------------------------------------
    // the bytes

    static File jarFile() {
        try {
            URL u = KnoxHotJava.class.getProtectionDomain().getCodeSource().getLocation();
            File f = new File(u.toURI());
            return f.isFile() ? f : null;
        } catch (Throwable t) {
            return null;
        }
    }

    /** The bytes of a class as the game loaded it: the last swapped in, else the jar's. */
    private static byte[] currentBytes(String name, JarFile jar) {
        byte[] b = current.get(name);
        if (b != null) return b;
        if (jar == null) return null;
        try {
            JarEntry e = jar.getJarEntry(name.replace('.', '/') + ".class");
            if (e == null) return null;
            try (InputStream in = jar.getInputStream(e)) {
                return in.readAllBytes();
            }
        } catch (Exception ex) {
            return null;
        }
    }

    private static void collect(File dir, String pkg, Map<String, File> out) {
        File[] list = dir.listFiles();
        if (list == null) return;
        for (File f : list) {
            if (f.isDirectory()) collect(f, pkg + f.getName() + ".", out);
            else if (f.getName().endsWith(".class")) out.put(pkg + f.getName().substring(0, f.getName().length() - 6), f);
        }
    }

    static boolean newerThanJar() {
        File jar = jarFile();
        File stamp = hotDir == null ? null : new File(hotDir, "stamp.txt");
        return jar != null && stamp != null && stamp.isFile() && stamp.lastModified() > jar.lastModified();
    }

    // ----------------------------------------------------------------------------------------
    // ZombieBuddy's reading of the patches: the fast build first

    /**
     * Puts the fast build's folder before everything else Knox's class loader (the system one -
     * ZombieBuddy adds mods' jars to it) looks in, so a patch's bytes ZombieBuddy reads to write
     * it into the game's class are the new ones. java.base's loader package is opened to Knox
     * for it (Instrumentation may do that). DEV only, once.
     */
    private static boolean front() {
        if (frontDone) return frontError == null;
        frontDone = true;
        try {
            Instrumentation i = instrumentation();
            Module base = Object.class.getModule();
            i.redefineModule(base, Set.of(), Map.of(), Map.of("jdk.internal.loader", Set.of(KnoxHotJava.class.getModule())), Set.of(), Map.of());
            ClassLoader app = KnoxHotJava.class.getClassLoader();
            Class<?> builtin = Class.forName("jdk.internal.loader.BuiltinClassLoader");
            if (!builtin.isInstance(app)) throw new IllegalStateException("Knox's loader is " + app.getClass().getName());
            Field ucpField = builtin.getDeclaredField("ucp");
            ucpField.setAccessible(true);
            Object ucp = ucpField.get(app);
            Class<?> ucpClass = ucp.getClass();
            URL url = new File(hotDir, "classes").toURI().toURL();
            Method getLoader = ucpClass.getDeclaredMethod("getLoader", URL.class);
            getLoader.setAccessible(true);
            Object loader = getLoader.invoke(ucp, url);
            Field loadersField = ucpClass.getDeclaredField("loaders");
            loadersField.setAccessible(true);
            @SuppressWarnings("unchecked")
            List<Object> loaders = (List<Object>) loadersField.get(ucp);
            synchronized (ucp) {
                loaders.add(0, loader);
            }
            try {
                Field pathField = ucpClass.getDeclaredField("path");
                pathField.setAccessible(true);
                @SuppressWarnings("unchecked")
                List<URL> path = (List<URL>) pathField.get(ucp);
                synchronized (ucp) {
                    path.add(0, url);
                }
            } catch (NoSuchFieldException ignored) {
                // (only for the list of URLs it shows)
            }
            return true;
        } catch (Throwable t) {
            frontError = String.valueOf(t);
            return false;
        }
    }

    // ----------------------------------------------------------------------------------------
    // the swap

    private static String annotationTarget(Class<?> c) {
        try {
            me.zed_0xff.zombie_buddy.Patch p = c.getAnnotation(me.zed_0xff.zombie_buddy.Patch.class);
            return p == null ? null : p.className();
        } catch (Throwable t) {
            return null;
        }
    }

    private static boolean hasLuaMethods(Class<?> c) {
        try {
            for (Method m : c.getDeclaredMethods()) {
                LuaMethod a = m.getAnnotation(LuaMethod.class);
                if (a != null && a.global()) return true;
            }
        } catch (Throwable t) {
            // (a class that can't be looked at: nothing to expose)
        }
        return false;
    }

    private static String expose(Class<?> c) {
        try {
            Constructor<?> k = c.getDeclaredConstructor();
            k.setAccessible(true);
            Object o = k.newInstance();
            Class<?> lm = Class.forName("zombie.Lua.LuaManager");
            Object exposer = lm.getField("exposer").get(null);
            exposer.getClass().getMethod("exposeGlobalFunctions", Object.class).invoke(exposer, o);
            return null;
        } catch (Throwable t) {
            return String.valueOf(t);
        }
    }

    private static String why(Throwable t) {
        String m = t.getMessage();
        if (m == null) m = t.getClass().getSimpleName();
        if (t instanceof UnsupportedOperationException || m.contains("attempted to")) {
            return "shape: its make-up changed (a method, field or lambda added or taken away) - plain Java swaps bodies only (" + m + ")";
        }
        return m;
    }

    /**
     * A class file's fields and methods, "F name desc" / "M name desc" (its static init left
     * out - its body may change), or null when it can't be read: two classes of one make-up
     * have the same set.
     */
    static java.util.Set<String> members(byte[] b) {
        if (b == null) return null;
        try {
            java.io.DataInputStream in = new java.io.DataInputStream(new java.io.ByteArrayInputStream(b));
            if (in.readInt() != 0xCAFEBABE) return null;
            in.readUnsignedShort();
            in.readUnsignedShort();
            int n = in.readUnsignedShort();
            String[] utf = new String[n];
            for (int k = 1; k < n; k++) {
                int tag = in.readUnsignedByte();
                switch (tag) {
                    case 1 -> utf[k] = in.readUTF();
                    case 3, 4, 9, 10, 11, 12, 17, 18 -> in.readInt();
                    case 5, 6 -> {
                        in.readLong();
                        k++;
                    }
                    case 7, 8, 16, 19, 20 -> in.readUnsignedShort();
                    case 15 -> {
                        in.readUnsignedByte();
                        in.readUnsignedShort();
                    }
                    default -> {
                        return null;
                    }
                }
            }
            in.readUnsignedShort();   // access
            in.readUnsignedShort();   // this
            in.readUnsignedShort();   // super
            int ifaces = in.readUnsignedShort();
            for (int k = 0; k < ifaces; k++) in.readUnsignedShort();
            java.util.Set<String> out = new java.util.HashSet<>();
            for (int pass = 0; pass < 2; pass++) {
                int count = in.readUnsignedShort();
                for (int m = 0; m < count; m++) {
                    in.readUnsignedShort();
                    String name = utf[in.readUnsignedShort()];
                    String desc = utf[in.readUnsignedShort()];
                    if (!"<clinit>".equals(name)) out.add((pass == 0 ? "F " : "M ") + name + " " + desc);
                    int attrs = in.readUnsignedShort();
                    for (int a = 0; a < attrs; a++) {
                        in.readUnsignedShort();
                        in.skipNBytes(in.readInt() & 0xFFFFFFFFL);
                    }
                }
            }
            return out;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Swaps in what changed in the fast build. Returns a line a class: "ok\t<class>\t<what>",
     * "restart\t<class>\t<why>" (the game has to start again for it), "error\t<class>\t<why>";
     * or "none" when nothing changed, "off\t<why>" when nothing can be swapped.
     */
    static String apply() {
        if (hotDir == null) return "off\tno java/build/hot (the mod is not run from its repository)";
        Instrumentation i = instrumentation();
        if (i == null) return "off\tno Instrumentation from ZombieBuddy";
        if (!i.isRedefineClassesSupported()) return "off\tthis Java can't redefine classes";
        File classes = new File(hotDir, "classes");
        HashMap<String, File> files = new HashMap<>();
        collect(classes, "", files);
        if (files.isEmpty()) return "off\tjava/build/hot/classes is empty (java\\hot.ps1)";

        HashMap<String, Class<?>> loaded = new HashMap<>();
        ClassLoader knox = KnoxHotJava.class.getClassLoader();
        for (Class<?> c : i.getAllLoadedClasses()) {
            if (c.getClassLoader() == knox && files.containsKey(c.getName())) loaded.put(c.getName(), c);
        }

        List<String> out = new ArrayList<>();
        HashMap<String, byte[]> changed = new HashMap<>();
        HashMap<String, byte[]> oldBytes = new HashMap<>();   // (what the game has of each changed one)
        File jarF = jarFile();
        try (JarFile jar = jarF != null ? new JarFile(jarF) : null) {
            for (Map.Entry<String, File> e : files.entrySet()) {
                byte[] now;
                try {
                    now = Files.readAllBytes(e.getValue().toPath());
                } catch (Exception ex) {
                    out.add("error\t" + e.getKey() + "\tcannot read: " + ex);
                    continue;
                }
                byte[] was = currentBytes(e.getKey(), jar);
                if (was == null || !Arrays.equals(was, now)) {
                    changed.put(e.getKey(), now);
                    if (was != null) oldBytes.put(e.getKey(), was);
                }
            }
        } catch (Exception ex) {
            return "error\t-\tcannot read the jar: " + ex;
        }
        if (changed.isEmpty()) return "none";
        // the very build that was refused last time: said once already
        boolean sameRefused = changed.size() == refused.size();
        for (Map.Entry<String, byte[]> e : changed.entrySet()) {
            byte[] no = refused.get(e.getKey());
            if (no == null || !Arrays.equals(no, e.getValue())) sameRefused = false;
        }
        if (sameRefused) return "none";

        // new classes and ones the game has not loaded yet: defined from the new bytes
        // (the outer ones first - a nested class names its outer one)
        List<String> names = new ArrayList<>(changed.keySet());
        names.sort((a, b) -> Integer.compare(a.length(), b.length()));
        MethodHandles.Lookup lookup;
        try {
            lookup = MethodHandles.privateLookupIn(KnoxHotJava.class, MethodHandles.lookup());
        } catch (Throwable t) {
            lookup = null;
        }
        LinkedHashSet<Class<?>> exposeAgain = new LinkedHashSet<>();
        List<String> patchTargets = new ArrayList<>();
        List<ClassDefinition> defs = new ArrayList<>();
        List<String> defNames = new ArrayList<>();
        List<String> newOnes = new ArrayList<>();
        for (String n : names) {
            byte[] b = changed.get(n);
            Class<?> c = loaded.get(n);
            if (c == null) {
                if (lookup == null || !n.startsWith(KnoxHotJava.class.getPackageName() + ".")) {
                    out.add("restart\t" + n + "\tpackage: not in Knox's package - can't be defined here");
                    continue;
                }
                // (defined after the loaded ones are swapped - and only if they are: QA 2026-11-10)
                newOnes.add(n);
                continue;
            }
            String target = annotationTarget(c);
            if (target != null) {
                // a patch: ZombieBuddy writes it into the game's class again (reading the new
                // bytes); the patch class itself is swapped too (what the written-in code calls)
                patchTargets.add(target + "\t" + n);
            }
            defs.add(new ClassDefinition(c, b));
            defNames.add(n);
        }

        // loaded classes: all at once or none (QA 2026-11-10: swapped one by one, a class could
        // call a new method of one that was refused - NoSuchMethodError, maybe in the game's
        // drawing). One that can't be swapped holds back the whole build: restart.
        boolean swapped = true;
        if (!defs.isEmpty()) {
            try {
                i.redefineClasses(defs.toArray(new ClassDefinition[0]));
                refused.clear();
                for (int k = 0; k < defs.size(); k++) {
                    current.put(defNames.get(k), changed.get(defNames.get(k)));
                    if (annotationTarget(defs.get(k).getDefinitionClass()) == null) out.add("ok\t" + defNames.get(k) + "\tswapped");
                    if (hasLuaMethods(defs.get(k).getDefinitionClass())) exposeAgain.add(defs.get(k).getDefinitionClass());
                }
            } catch (Throwable all) {
                swapped = false;
                refused.clear();
                for (String n : changed.keySet()) refused.put(n, changed.get(n));
                // which one changed its make-up: its fields and methods against what the game has
                // (the JVM does not say); the rest only waits for it
                List<String> culprits = new ArrayList<>();
                if (all instanceof UnsupportedOperationException) {
                    for (String n : defNames) {
                        Set<String> a = members(oldBytes.get(n)), b = members(changed.get(n));
                        if (a != null && b != null && !a.equals(b)) culprits.add(n);
                    }
                }
                for (String n : defNames) {
                    if (culprits.isEmpty() || culprits.contains(n)) {
                        out.add((all instanceof UnsupportedOperationException ? "restart\t" : "error\t") + n + "\t" + why(all));
                    } else {
                        out.add("wait\t" + n + "\twaits for the classes above (the build goes in whole or not at all)");
                    }
                }
                for (String n : newOnes) out.add("wait\t" + n + "\tnew, waits with the build");
            }
        }

        // new classes: defined (the build went in, or nothing loaded changed)
        if (swapped) {
            for (String n : newOnes) {
                byte[] b = changed.get(n);
                try {
                    Class<?> nc = lookup.defineClass(b);
                    current.put(n, b);
                    String target = annotationTarget(nc);
                    out.add("ok\t" + n + "\t" + (target != null ? "new patch (applies when " + target + " loads)" : "defined"));
                    if (hasLuaMethods(nc)) exposeAgain.add(nc);
                } catch (LinkageError le) {
                    // (loaded meanwhile by somebody, from the jar: the next build swaps it)
                    out.add("error\t" + n + "\tloaded meanwhile - run java\\hot.ps1 again: " + le);
                } catch (Throwable t) {
                    out.add("error\t" + n + "\t" + t);
                }
            }
        }

        // patches: the game's classes they are in, transformed again
        if (swapped && !patchTargets.isEmpty()) {
            if (!front()) {
                for (String pt : patchTargets) {
                    String[] p = pt.split("\t");
                    out.add("restart\t" + p[1] + "\tpatch: of " + p[0] + " - can't make ZombieBuddy read the new bytes (" + frontError + ")");
                }
            } else {
                LinkedHashSet<String> targets = new LinkedHashSet<>();
                for (String pt : patchTargets) targets.add(pt.split("\t")[0]);
                HashMap<String, Class<?>> gameLoaded = new HashMap<>();
                for (Class<?> c : i.getAllLoadedClasses()) if (targets.contains(c.getName())) gameLoaded.put(c.getName(), c);
                HashMap<String, String> result = new HashMap<>();
                for (String t : targets) {
                    Class<?> c = gameLoaded.get(t);
                    if (c == null) {
                        result.put(t, "ok\tapplies when " + t + " loads");
                        continue;
                    }
                    try {
                        i.retransformClasses(c);
                        result.put(t, "ok\twritten into " + t + " again");
                    } catch (Throwable ex) {
                        result.put(t, (ex instanceof UnsupportedOperationException ? "restart" : "error") + "\t" + t + ": " + why(ex));
                    }
                }
                for (String pt : patchTargets) {
                    String[] p = pt.split("\t");
                    String r = result.get(p[0]);
                    int tab = r.indexOf('\t');
                    out.add(r.substring(0, tab) + "\t" + p[1] + "\t" + r.substring(tab + 1));
                }
            }
        }

        // Lua functions: exposed again (a new one appears; a swapped one is the same function anyway)
        for (Class<?> c : exposeAgain) {
            String err = expose(c);
            if (err != null) out.add("error\t" + c.getName() + "\tLua functions not exposed again: " + err);
        }
        return String.join("\n", out);
    }
}
