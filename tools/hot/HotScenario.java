import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import knox.java.KnoxHotEngine;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.LuaClosure;
import zombie.Lua.Event;

/**
 * What a reload does, on a made-up file of Knox's (tools\hot\test.ps1, 2026-11-10): version A
 * loads, an "open window" of its class is made, then the file is changed and run again by the
 * engine, and Lua checks what the game would see: the window's methods are the new ones, the
 * class is the same table, the game's function it wraps is wrapped once, its handler is the new
 * one and sees the same table, a handler added "only once" is kept, its data tables are the same
 * tables with the new contents. Then a file that does not compile and one that fails halfway.
 */
public class HotScenario {
    static int fails = 0;

    static String root;
    static String file;

    static void write(String src) throws Exception {
        Files.writeString(Path.of(file), src, StandardCharsets.UTF_8);
    }

    static String version(String v, String wrap) {
        return "KnoxZ = ISPanel:derive(\"KnoxZ\")\n"
            + "local Z = KnoxZ\n"
            + "KnoxZState = KnoxZState or {n = 0}\n"
            + "function Z:val() return \"" + v + "\" end\n"
            + "function Z.whoAmI() return Z end\n"
            + "local vanilla = ISFoo.bar\n"
            + "function ISFoo.bar(x) return \"" + wrap + "(\" .. tostring(vanilla(x)) .. \")\" end\n"
            + "Events.OnTick.Add(function() KnoxZState.n = KnoxZState.n + 1; Z.lastTick = \"" + v + "\" end)\n"
            + "if not KnoxZState.once then KnoxZState.once = true; Events.OnSave.Add(function() KnoxZState.saved = \"" + v + "\" end) end\n"
            + "Z.colors = {a = 1, b = " + (v.equals("A") ? "2" : "3, c = 4") + "}\n"
            + "Z.list = " + (v.equals("A") ? "{\"x\", \"y\", \"z\"}" : "{\"p\"}") + "\n";
    }

    /** Runs Lua that returns "" when all is well, else what is wrong. */
    static void check(String what, String lua) throws Exception {
        Object[] r = HotLuaTest.thread.pcall(LuaCompiler.loadstring(lua, "check", HotLuaTest.env), new Object[0]);
        String got = Boolean.TRUE.equals(r[0]) ? String.valueOf(r.length > 1 ? r[1] : "") : "error " + r[1];
        boolean ok = got.isEmpty() || got.equals("null");
        if (!ok) fails++;
        System.out.println((ok ? "pass " : "FAIL ") + what + (ok ? "" : ": " + got));
    }

    static void fire(String event) {
        for (Event e : HotLuaTest.events) {
            if (!e.name.equals(event)) continue;
            for (LuaClosure c : new java.util.ArrayList<>(e.callbacks)) HotLuaTest.thread.pcall(c, new Object[0]);
        }
    }

    static int count(String event) {
        for (Event e : HotLuaTest.events) if (e.name.equals(event)) return e.callbacks.size();
        return 0;
    }

    public static int run(String stubs) throws Exception {
        File dir = Files.createTempDirectory("knox_hot_scenario").toFile();
        File knox = new File(dir, "42/media/lua/client/Knox");
        knox.mkdirs();
        root = HotLuaTest.norm(new File(dir, "42/media/lua").getAbsolutePath()) + "/";
        file = HotLuaTest.norm(new File(knox, "KnoxZ.lua").getAbsolutePath());

        HotLuaTest.setup(stubs);
        HotLuaTest.thread.pcall(LuaCompiler.loadstring("ISFoo = {bar = function(x) return 'base' end}\nISBar = {go = function() return 'base' end}",
            "game", HotLuaTest.env), new Object[0]);
        KnoxHotEngine engine = new KnoxHotEngine(HotLuaTest.env, HotLuaTest::lists);
        engine.eventNames = () -> {
            java.util.List<String> n = new java.util.ArrayList<>();
            for (Event e : HotLuaTest.events) n.add(e.name);
            return n;
        };
        engine.setKnoxRoot(root);
        engine.baseline();
        write(version("A", "knox"));
        Object[] r = HotLuaTest.runFile(file);
        if (!Boolean.TRUE.equals(r[0])) throw new RuntimeException("version A: " + r[1]);
        check("A loaded", "KnoxT_OLD, KnoxT_COLORS, KnoxT_LIST = KnoxZ, KnoxZ.colors, KnoxZ.list; KnoxT_WIN = KnoxZ:new()\n"
            + "if KnoxT_WIN:val() ~= 'A' then return 'val ' .. tostring(KnoxT_WIN:val()) end\n"
            + "if ISFoo.bar(1) ~= 'knox(base)' then return ISFoo.bar(1) end return ''");

        write(version("B", "knox2"));
        String err = engine.run(file, file, HotLuaTest::runChunk);
        if (err != null) {
            fails++;
            System.out.println("FAIL B ran again: " + err);
        }
        check("B: the class is the same table", "if KnoxZ ~= KnoxT_OLD then return 'another table' end return ''");
        check("B: the open window has the new method", "if KnoxT_WIN:val() ~= 'B' then return tostring(KnoxT_WIN:val()) end return ''");
        check("B: the file's own local is the old table", "if KnoxZ.whoAmI() ~= KnoxT_OLD then return 'the new one' end return ''");
        check("B: the game's function wrapped once", "if ISFoo.bar(1) ~= 'knox2(base)' then return ISFoo.bar(1) end return ''");
        check("B: data tables are the same, with the new contents",
            "if KnoxZ.colors ~= KnoxT_COLORS or KnoxT_COLORS.b ~= 3 or KnoxT_COLORS.c ~= 4 then return 'colors' end\n"
            + "if KnoxZ.list ~= KnoxT_LIST or #KnoxT_LIST ~= 1 or KnoxT_LIST[1] ~= 'p' then return 'list ' .. #KnoxT_LIST end return ''");
        if (count("OnTick") != 1) {
            fails++;
            System.out.println("FAIL B: OnTick has " + count("OnTick") + " handlers");
        } else System.out.println("pass B: OnTick has one handler");
        if (count("OnSave") != 1) {
            fails++;
            System.out.println("FAIL B: OnSave has " + count("OnSave") + " handlers (added once, kept)");
        } else System.out.println("pass B: OnSave (added only once) kept");
        fire("OnTick");
        fire("OnSave");
        check("B: the new handler runs, on the old table", "if KnoxT_OLD.lastTick ~= 'B' then return tostring(KnoxT_OLD.lastTick) end return ''");
        check("B: the kept handler is the old one", "if KnoxZState.saved ~= 'A' then return tostring(KnoxZState.saved) end return ''");

        write("KnoxZ = ISPanel:derive(\"KnoxZ\"\nfunction KnoxZ:val() return 'C' end\n");
        err = engine.run(file, file, HotLuaTest::runChunk);
        if (err == null) {
            fails++;
            System.out.println("FAIL C (does not compile) said no error");
        } else System.out.println("pass C (does not compile): " + err.split("\n")[0]);
        check("C: nothing changed", "if KnoxZ ~= KnoxT_OLD or KnoxT_WIN:val() ~= 'B' then return tostring(KnoxT_WIN:val()) end return ''");

        write(version("D", "knox4").replace("Events.OnTick.Add", "error('halfway')\nEvents.OnTick.Add"));
        err = engine.run(file, file, HotLuaTest::runChunk);
        if (err == null) {
            fails++;
            System.out.println("FAIL D (fails halfway) said no error");
        } else System.out.println("pass D (fails halfway): " + err.split("\n")[0]);
        check("D: what ran before the error is in", "if KnoxT_WIN:val() ~= 'D' then return tostring(KnoxT_WIN:val()) end return ''");
        check("D: the game's function still wrapped once", "if ISFoo.bar(1) ~= 'knox4(base)' then return ISFoo.bar(1) end return ''");
        if (count("OnTick") != 1) {
            fails++;
            System.out.println("FAIL D: OnTick has " + count("OnTick") + " handlers");
        } else System.out.println("pass D: OnTick keeps its one handler");
        fire("OnTick");
        check("D: the handler kept is B's", "if KnoxT_OLD.lastTick ~= 'B' then return tostring(KnoxT_OLD.lastTick) end return ''");

        // E-G (QA 2026-11-10): a handler added while playing (start/stop), a handler taken out
        // of the file, a function of the game another mod wrapped after Knox
        String fileY = HotLuaTest.norm(new File(knox, "KnoxY.lua").getAbsolutePath());
        File other = new File(dir, "othermod/media/lua/client/Other.lua");
        other.getParentFile().mkdirs();
        Files.writeString(other.toPath(), "local prev = ISBar.go\nISBar.go = function() return 'o(' .. prev() .. ')' end\n", StandardCharsets.UTF_8);
        String y1 = "KnoxY = KnoxY or {}\nKnoxYState = KnoxYState or {n = 0}\nlocal Y = KnoxY\n"
            + "local function onTick() KnoxYState.n = KnoxYState.n + 1 end\n"
            + "function Y.start() Events.OnTick.Add(onTick) end\n"
            + "function Y.stop() Events.OnTick.Remove(onTick) end\n"
            + "function Y.v() return 'V1' end\n"
            + "Events.OnSave.Add(function() KnoxYState.saved = 1 end)\n"
            + "local vanilla = ISBar.go\nfunction ISBar.go() return 'y(' .. tostring(vanilla()) .. ')' end\n";
        Files.writeString(Path.of(fileY), y1, StandardCharsets.UTF_8);
        r = HotLuaTest.runFile(fileY);
        if (!Boolean.TRUE.equals(r[0])) throw new RuntimeException("KnoxY: " + r[1]);
        r = HotLuaTest.runFile(HotLuaTest.norm(other.getAbsolutePath()));
        if (!Boolean.TRUE.equals(r[0])) throw new RuntimeException("Other.lua: " + r[1]);
        check("E: another mod wrapped after Knox", "if ISBar.go() ~= 'o(y(base))' then return ISBar.go() end return ''");
        int ticks = count("OnTick"), saves = count("OnSave");
        check("E: started while playing", "KnoxY.start() return ''");
        String y2 = y1.replace("'V1'", "'V2'").replace("Events.OnSave.Add(function() KnoxYState.saved = 1 end)\n", "").replace("'y('", "'y2('");
        Files.writeString(Path.of(fileY), y2, StandardCharsets.UTF_8);
        err = engine.run(fileY, fileY, HotLuaTest::runChunk);
        if (err != null) {
            fails++;
            System.out.println("FAIL E ran again: " + err);
        }
        check("E: new code in", "if KnoxY.v() ~= 'V2' then return KnoxY.v() end return ''");
        check("G: wrapped once, from outside the other mod's", "if ISBar.go() ~= 'y2(o(base))' then return ISBar.go() end return ''");
        if (count("OnTick") != ticks + 1) {
            fails++;
            System.out.println("FAIL E: OnTick has " + count("OnTick") + " handlers, want " + (ticks + 1));
        } else System.out.println("pass E: the handler added while playing is not doubled");
        check("E: the new stop finds it", "KnoxY.stop() return ''");
        if (count("OnTick") != ticks) {
            fails++;
            System.out.println("FAIL E: after stop OnTick has " + count("OnTick") + ", want " + ticks);
        } else System.out.println("pass E: after the new stop it is gone");
        boolean warned = false;
        for (String w : engine.warnings) if (w.contains("OnSave")) warned = true;
        if (!warned || count("OnSave") != saves) {
            fails++;
            System.out.println("FAIL F: a handler taken out of the file - warned " + warned + ", OnSave " + count("OnSave") + " (was " + saves + ")");
        } else System.out.println("pass F: a handler taken out of the file is said: " + engine.warnings.get(0));
        System.out.println(fails == 0 ? "scenario: all pass" : "scenario: " + fails + " FAIL");
        try (java.util.stream.Stream<Path> s = Files.walk(dir.toPath())) {
            s.sorted(java.util.Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
        }
        return fails;
    }
}
