-- KnoxGenerator.lua and KnoxGeneratorWindow.lua outside the game (tools/gen/test.ps1):
-- the chance a worn generator fails, the window on three screens in every state, the
-- cord pulled fast, slow and short, the switch, the lever, the can, the outlets, the
-- counter. Checks: no error stops it, no draw gets a number that is not one, every
-- picture asked for is there, every text is in the translations, the texts stay in
-- the window, the game's actions are queued as they should be.

local G = KnoxGenerator
local W = KnoxGeneratorWindow
local pass, fail = 0, 0
local function ok(name, cond, info)
    if cond then pass = pass + 1 else
        fail = fail + 1
        print("FAIL " .. name .. (info ~= nil and (": " .. tostring(info)) or ""))
    end
end

-- the texts of the language (RU by default): a missing key is a fault
local TX = {}
local src = readfile(root .. "/42/media/lua/shared/Translate/" .. (lang or "RU") .. "/IG_UI.json") or ""
for k, v in string.gmatch(src, '"([%w_]+)":%s*"(.-)",?\r?\n') do TX[k] = v end
local missingText = {}
function getText(k, a1, a2)
    if k == "IGUI_Lights" then return "Lights" end
    -- (the game's own words, not in Knox's files)
    if k == "ContextMenu_Turn_On" or k == "ContextMenu_Turn_Off" or k == "ContextMenu_GeneratorInfo" or k == "ContextMenu_GeneratorUnplug" then return k end
    local v = TX[k]
    if not v then missingText[k] = true return k end
    if a1 then v = string.gsub(v, "%%1", tostring(a1)) end
    if a2 then v = string.gsub(v, "%%2", tostring(a2)) end
    return v
end

-- 1. the chance --------------------------------------------------------------------------
ok("fail at 100", G.failChance(100) == 0)
ok("fail at 60", G.failChance(60) == 0)
ok("fail at 30", math.abs(G.failChance(30) - 0.5) < 1e-9, G.failChance(30))
ok("fail at 0", math.abs(G.failChance(0) - 0.8) < 1e-9, G.failChance(0))
ok("fail at 50", math.abs(G.failChance(50) - 1 / 6) < 1e-9, G.failChance(50))

local function genState() return {fuel = 6.2, cond = 82, conn = true, on = false, use = 0.25} end
do
    local g = genState(); g.cond = 30
    local gen = makeGen(g)
    rand = 0.3
    local a = ISActivateGenerator:new(player, gen, true)
    a:complete()
    ok("worn: 0.3 < 0.5 fails", g.failed == 1 and not g.on and a.knoxFailed == true)
    rand = 0.6
    a = ISActivateGenerator:new(player, gen, true)
    a:complete()
    ok("worn: 0.6 starts", g.on == true and not a.knoxFailed)
    g.cond = 100; g.on = false; rand = 0
    ISActivateGenerator:new(player, gen, true):complete()
    ok("new starts even at 0", g.on == true)
    ISActivateGenerator:new(player, gen, false):complete()
    ok("stop goes the game's way", g.on == false)
end

-- 2. the window -------------------------------------------------------------------------------
local function frame(w, n)
    for _ = 1, n or 1 do
        clock = clock + 16
        texts = {}
        w:prerender()
    end
end

local function newWindow(g)
    queue = {}
    W.instance = nil
    local gen = makeGen(g)
    local w = W.open(player, gen)
    frame(w, 3)
    return w, gen
end

for _, screen in ipairs({{1920, 1080, 48}, {2560, 1440, 64}, {3840, 2160, 96}}) do
    screenW, screenH, KnoxTheme.cell = screen[1], screen[2], screen[3]
    missingPics = {}
    local g = genState()
    g.items = {"Fridge (0.08 L/h)", "Lights x4 (0.008 L/h)", "Stove (0.09 L/h)"}
    local w, gen = newWindow(g)
    local tag = screen[2] .. "p"
    local s = w.s
    ok(tag .. " size", w:getWidth() == math.floor(700 * s + 0.5) and w:getHeight() == math.floor(500 * s + 0.5), w:getWidth())
    local miss = {}
    for p in pairs(missingPics) do table.insert(miss, p) end
    ok(tag .. " pictures", #miss == 0, table.concat(miss, " "))
    -- running, indoors, worn: every lamp, the shake, the plugs
    g.on, g.inside, g.cond = true, true, 30
    w.itemsAt = 0
    frame(w, 30)
    local inside = true
    for _, t in ipairs(texts) do
        if t.x < -2 or t.y < -2 or t.x > w:getWidth() or t.y > w:getHeight() then inside = false end
    end
    ok(tag .. " texts in the window", inside)
    ok(tag .. " plugs", #w.items == 3 and w.items[1].icon == "icon_fridge" and w.items[2].icon == "icon_bulb" and w.items[3].icon == "icon_stove",
        w.items[1] and w.items[1].icon)
    ok(tag .. " needle up on its spring", w.N.a > -120, w.N.a)
    -- a tip over the first outlet
    mouse = {(496 + 19) * s, (215 + 20) * s}
    tipDrawn = nil
    frame(w, 1)
    ok(tag .. " tip", tipDrawn ~= nil and string.find(tipDrawn, "Fridge", 1, true) ~= nil, tipDrawn)
    mouse = {(496 + 42 + 19) * s, (215 + 52 + 20) * s}
    frame(w, 1)
    ok(tag .. " free outlet tip", tipDrawn == getText("IGUI_KnoxGen_FreeOutlet"), tipDrawn)
    mouse = nil
    ok(tag .. " cross in the corner", closeDrawn ~= nil and w:getWidth() - (closeDrawn[1] + closeDrawn[3]) == 6 and closeDrawn[2] < 12 * s,
        closeDrawn and (closeDrawn[1] .. "," .. closeDrawn[2]))
end
screenW, screenH, KnoxTheme.cell = 1920, 1080, 48

-- the controls: a click, a pull of the cord ------------------------------------------------------
local function click(w, ux, uy)
    local s = w.s
    mouse = {ux * s, uy * s}
    w:onMouseDown(mouse[1], mouse[2])
    w:onMouseUp(mouse[1], mouse[2])
    frame(w, 1)
end

--- Hold the handle and pull it down `dist` units in `steps` frames, then let go.
local function pull(w, dist, steps, sideways)
    local s = w.s
    local H = w.R[6]
    local x, y = H.x, H.y + 4
    mouse = {x * s, y * s}
    w:onMouseDown(mouse[1], mouse[2])
    buttonDown = true
    for i = 1, steps do
        mouse = {(x + (sideways or 0) * i / steps) * s, (y + dist * i / steps) * s}
        frame(w, 1)
    end
    buttonDown = false
    frame(w, 1)
    w:onMouseUp(mouse[1], mouse[2])
    mouse = nil
    frame(w, 20)
end

-- 3. the controls: everything at once (2026-10-22: no timed action for each) ------------------
do
    rand = 0.99
    local g = genState()
    local w = newWindow(g)
    pull(w, 110, 4)
    ok("no RUN: no start", not g.on)
    sounds = {}
    click(w, 138, 267)
    ok("switch to RUN kept, clicks", w.gen:getModData().knoxSwitch == true and sounds[1] == "ToggleStove", sounds[1])
    frame(w, 20)
    ok("knob turned", math.abs(w.knob.a - 40) < 0.5, w.knob.a)
    pull(w, 110, 60)
    ok("slow: too slow", not g.on)
    pull(w, 50, 4)
    ok("short: not far", not g.on)
    -- worn (30 %): half the pulls fail - this one does (0.3 < 0.5)
    g.cond, rand = 30, 0.3
    pull(w, 110, 4, 40)
    ok("worn: fails at once", not g.on and g.failed == 1)
    ok("cord back in", w.L <= 18.01, w.L)
    rand = 0.6
    pull(w, 110, 4)
    ok("starts at once", g.on == true)
    pull(w, 110, 4)
    -- the lever: not while it runs
    click(w, 536, 359)
    ok("lever while running", g.conn)
    -- the switch to OFF stops it at once
    click(w, 138, 267)
    ok("OFF stops it at once", g.on == false)
    sounds = {}
    click(w, 536, 359)
    ok("lever: unplugged at once", g.conn == false and sounds[1] == "LightSwitch", sounds[1])
    frame(w, 20)
    ok("lever slid to OFF", math.abs(w.LV.x + 43) < 0.5, w.LV.x)
    -- disconnected it won't start
    click(w, 138, 267)   -- (the switch was turned OFF above: back to RUN)
    pull(w, 110, 4)
    ok("disconnected: no start", not g.on)
    -- plugging in wants Electricity 3 or the magazine
    perk, knowsGenerator = 0, false
    click(w, 536, 359)
    ok("no skill: stays unplugged", g.conn == false)
    knowsGenerator = true
    click(w, 536, 359)
    ok("the magazine read: plugged", g.conn == true)
    perk, knowsGenerator = 3, false
    -- the can: none carried; then the fuller of two, poured a portion every 250 ms
    cans = {}
    click(w, 582, 115)
    ok("no can", w.pour == nil)
    cans = {makeCan("Water", 4, 1), makeCan("Petrol", 2, 2), makeCan("Petrol", 5, 3)}
    g.fuel = 6.2
    sounds = {}
    click(w, 582, 115)
    ok("pouring starts, its sound", w.pour ~= nil and w.pour.id == 3 and sounds[1] == "GeneratorAddFuel", sounds[1])
    for _ = 1, 4 do clock = clock + 250; frame(w, 1) end
    -- (the first portion with the click, then one each 250 ms)
    ok("poured from the fuller can", math.abs(g.fuel - (6.2 + 5 * 0.3)) < 0.01 and math.abs(cans[3].amount - (5 - 1.5)) < 0.01,
        g.fuel .. " " .. cans[3].amount)
    click(w, 582, 115)
    ok("a click again stops it", w.pour == nil and stopped == sounds[1])
    click(w, 582, 115)
    for _ = 1, 40 do clock = clock + 250; frame(w, 1) end
    ok("stops at a full tank", w.pour == nil and math.abs(g.fuel - 10) < 0.001, g.fuel)
    -- a can that isn't on the character
    g.fuel = 2
    local far = makeCan("Petrol", 5, 9)
    w:refuel(far)
    ok("a can not carried", w.pour == nil)
    -- Esc closes
    w:onKeyRelease(Keyboard.KEY_ESCAPE)
    ok("Esc closes", W.instance == nil and not w.inManager)
end

-- 4. the hour meter, the scale, more kinds than outlets, walking away ---------------------------
do
    rand = 0.5   -- (the needles' tremble even both ways)
    local g = genState()
    g.on, g.use = true, 0.25
    local w = newWindow(g)
    frame(w, 40)
    local d = w.drums
    ok("meter 024,8", d[1].pos == 0 and d[2].pos == 2 and d[3].pos == 4 and d[4].pos == 8,
        d[1].pos .. d[2].pos .. d[3].pos .. d[4].pos)
    g.fuel = 6.0
    clock = clock + 300
    frame(w, 40)
    ok("meter rolls to 024,0", d[1].pos == 0 and d[2].pos == 2 and d[3].pos == 4 and d[4].pos == 0,
        d[1].pos .. d[2].pos .. d[3].pos .. d[4].pos)
    ok("HOURS stamped under it", w.cap.hours ~= nil and w.cap.hours.text == getText("IGUI_KnoxGen_Hours"))
    ok("load needle at a quarter", math.abs(w.N.a - (-60)) < 3, w.N.a)
    g.items = {"Fridge (0.08 L/h)", "Lights x4 (0.008 L/h)", "Stove (0.09 L/h)", "Radio (0.01 L/h)", "Television (0.03 L/h)"}
    w.itemsAt = 0
    frame(w, 1)
    mouse = {(496 + 42 + 19) * w.s, (215 + 52 + 20) * w.s}
    frame(w, 1)
    ok("+N tip lists the rest", tipDrawn == "Radio, Television", tipDrawn)
    ok("+N said", w.moreText == "+2", w.moreText)
    mouse = nil
    ok("running: switch at RUN", w.gen:getModData().knoxSwitch == true and math.abs(w.knob.a - 40) < 0.5, w.knob.a)
    -- stopped: its plugs stay, the time at its last load; with fuel left the switch to OFF
    g.on = false
    w.itemsAt = 0
    clock = clock + 300
    frame(w, 40)
    ok("stopped keeps plugs", #w.items == 5)
    ok("stopped: time at the last load", w.mins == math.floor(6.0 / 0.25 * 60), w.mins)
    ok("needle down", w.N.a < -115, w.N.a)
    ok("stopped elsewhere: switch to OFF", w.gen:getModData().knoxSwitch == false and math.abs(w.knob.a + 40) < 0.5, w.knob.a)
    -- run dry: the switch stays at RUN
    g.on = true
    frame(w, 20)
    g.on, g.fuel = false, 0
    frame(w, 20)
    ok("run dry: switch stays at RUN", w.gen:getModData().knoxSwitch == true and math.abs(w.knob.a - 40) < 0.5, w.knob.a)
    playerDist = 5
    frame(w, 1)
    ok("walked away: closed", W.instance == nil)
    playerDist = nil
end

-- 4b. the game's default fuel rate (0.1): a house's 0.03 L/h a third up the scale; 10 L
-- last 333,3 hours on the meter
do
    rand = 0.5
    SandboxVars = {GeneratorFuelConsumption = 0.1}
    local g = genState()
    g.on, g.use, g.fuel = true, 0.03, 10
    local w = newWindow(g)
    frame(w, 60)
    ok("scale to 0,1 at rate 0.1", w.cap.num4.text == "0,1" and w.cap.num1.text == "0,025", w.cap.num4.text .. " " .. w.cap.num1.text)
    ok("0.03 L/h a third up", math.abs(w.N.a - (-48)) < 4, w.N.a)
    ok("load said in three places", w.loadText == "0,030 " .. getText("IGUI_KnoxGen_PerHour"), w.loadText)
    local d = w.drums
    ok("meter 333,3", d[1].pos == 3 and d[2].pos == 3 and d[3].pos == 3 and d[4].pos == 3,
        d[1].pos .. d[2].pos .. d[3].pos .. d[4].pos)
    g.use = 0.001   -- 10 000 hours: the meter stops at 999,9
    clock = clock + 300
    frame(w, 60)
    ok("meter at most 999,9", d[1].pos == 9 and d[2].pos == 9 and d[3].pos == 9 and d[4].pos == 9,
        d[1].pos .. d[2].pos .. d[3].pos .. d[4].pos)
    SandboxVars = nil
    W.instance = nil
end

-- 5. the character at the generator: the game's info action opens Knox's window and one
-- endless action; closing ends it, its end closes the window
do
    onGameStart()
    W.instance = nil
    queue = {}
    local gen = makeGen(genState())
    ISGeneratorInfoAction.perform({character = player, object = gen})
    local w = W.instance
    local act = queue[1]
    ok("info action opens the window", w ~= nil and w.gen == gen)
    ok("and the endless action at it", act ~= nil and act.Type == "KnoxGeneratorUse" and act.maxTime == -1 and act.stopOnWalk, act and act.Type)
    act:start()
    ok("the game's crouch", act.anim == "Loot" and player.vars.LootPosition == "Low", act.anim)
    act:update()
    ok("goes on while the window is open", not act.completed)
    w:close()
    act:update()
    ok("the window closed: the action ends", act.completed == true)
    -- walked off: the action stops, the window goes
    W.instance = nil
    queue = {}
    ISGeneratorInfoAction.perform({character = player, object = gen})
    w, act = W.instance, queue[1]
    act:stop()
    ok("walked off: the window closes", W.instance == nil and not w.inManager)
    -- another action queued behind it: it ends, the window goes
    W.instance = nil
    queue = {}
    ISGeneratorInfoAction.perform({character = player, object = gen})
    w, act = W.instance, queue[1]
    table.insert(queue, {Type = "ISInventoryTransferAction"})
    act:update()
    act:perform()
    ok("another action: the window closes", act.completed and W.instance == nil)
    -- pouring: the game's refuelling, the can in the hands; stopped: the crouch again
    W.instance = nil
    queue = {}
    ISGeneratorInfoAction.perform({character = player, object = gen})
    w, act = W.instance, queue[1]
    act:start()
    gen.g.fuel = 2
    cans = {makeCan("Petrol", 5, 7)}
    w:refuel(nil)
    ok("pouring: the refuel animation, can in hand", act.anim == "refuelgascan" and act.hands == "GasCan", act.anim)
    w:refuel(nil)
    ok("stopped: back to the crouch", act.anim == "Loot" and act.hands == nil, act.anim)
    w:close()
end

-- 6. the game's menu: the generator's Turn on / Turn off gone (the lamp's stay); a left
-- click on a generator walks up and opens the window
do
    local function menu(names)
        local m = {options = {}}
        for _, n in ipairs(names) do table.insert(m.options, {name = n}) end
        function m:removeOptionByName(n)
            for i, o in ipairs(self.options) do if o.name == n then table.remove(self.options, i) return end end
        end
        return m
    end
    local genMenu = menu({getText("ContextMenu_Turn_On"), getText("ContextMenu_GeneratorInfo"), getText("ContextMenu_GeneratorUnplug")})
    local lampMenu = menu({getText("ContextMenu_Turn_On")})
    local top = menu({"Generator", "Lamp"})
    top.options[1].subOption, top.options[2].subOption = 1, 2
    function top:getSubMenu(n) return n == 1 and genMenu or lampMenu end
    function genMenu:getSubMenu() return nil end
    function lampMenu:getSubMenu() return nil end
    onFillMenu(0, top, {}, false)
    ok("generator's Turn on gone", #genMenu.options == 2 and genMenu.options[1].name == getText("ContextMenu_GeneratorInfo"))
    ok("a lamp's Turn on stays", #lampMenu.options == 1)
    W.instance = nil
    queue = {}
    local gen = makeGen(genState())
    onLeftClick(gen, 0, 0)
    ok("left click: the info action queued", queue[1] ~= nil and queue[1].Type == "ISGeneratorInfoAction" and queue[1].object == gen)
    queue = {}
    onLeftClick({class = "IsoObject"}, 0, 0)
    ok("left click elsewhere: nothing", #queue == 0)
end

-- 6b. the news post's live window: the same window on a pretend generator, in the reader's
-- view; its controls work, time runs fast, a press off the view goes to the reader
do
    rand = 0.99
    local hostDowns, hostWheels = 0, 0
    local host = {onMouseDown = function() hostDowns = hostDowns + 1 end, onMouseWheel = function() hostWheels = hostWheels + 1 return true end}
    function host:addChild(c) self.child = c end
    local d = W.newsDemo(host, 1, false)
    ok("demo made once per line", W.newsDemo(host, 1, false) == d)
    local w, h = d:demoSize(600)
    ok("demo no wider than the column", w <= 600 and h > 0, w)
    local view = {0, 0, 800, 2000}
    local function dframe(n)
        for _ = 1, n or 1 do
            clock = clock + 16
            d:hostAt(host, 10, 20, view)
            d:prerender()
        end
    end
    dframe(5)
    ok("demo draws", not d.broken and d.visible ~= false and host.child == d)
    ok("demo: the empty bands cut", h == math.floor(452 * d.s + 0.5) and d.y == 20 - math.floor(30 * d.s + 0.5), h .. " " .. d.y)
    ok("demo: no window instance", W.instance == nil)
    ok("demo: plugs before it runs", #d.items == 3, #d.items)
    ok("demo: the scale by the game's default rate", d.cap.num4.text == "0,1", d.cap.num4.text)
    -- the switch, the cord: it starts, its sound through the menu's sounds
    uiSounds = {}
    local s = d.s
    mouse = {138 * s, 267 * s}
    d:onMouseDown(mouse[1], mouse[2]); d:onMouseUp(mouse[1], mouse[2])
    dframe(20)
    local H = d.R[6]
    mouse = {H.x * s, (H.y + 4) * s}
    d:onMouseDown(mouse[1], mouse[2])
    buttonDown = true
    for i = 1, 4 do
        mouse = {H.x * s, (H.y + 4 + 110 * i / 4) * s}
        dframe(1)
    end
    buttonDown = false
    dframe(1)
    d:onMouseUp(mouse[1], mouse[2])
    mouse = nil
    ok("demo starts", d.gen:isActivated() == true)
    local heard = false
    for _, n in ipairs(uiSounds) do if n == "GeneratorStarting" then heard = true end end
    ok("demo: the starting sound", heard)
    -- time runs: the meter's tenths turn
    local fuel0 = d.gen:getFuel()
    for _ = 1, 60 do clock = clock + 100; d:hostAt(host, 10, 20, view); d:prerender() end
    ok("demo: fuel goes while it runs", d.gen:getFuel() < fuel0, fuel0 - d.gen:getFuel())
    -- the can: pours from the pretend can
    d.demo.g.fuel = 5
    mouse = {582 * s, 115 * s}
    d:onMouseDown(mouse[1], mouse[2]); d:onMouseUp(mouse[1], mouse[2])
    mouse = nil
    for _ = 1, 4 do clock = clock + 250; d:hostAt(host, 10, 20, view); d:prerender() end
    ok("demo pours", d.demo.can.amount < 5 and d.gen:getFuel() > 5, d.demo.can.amount)
    -- off the shown part: the press and the wheel go to the reader
    view = {0, 0, 800, 50}
    dframe(1)
    d:onMouseDown(100, 400)
    ok("a press off the view goes to the reader", hostDowns == 1, hostDowns)
    d:onMouseWheel(1)
    ok("the wheel scrolls the reader", hostWheels == 1)
    -- not placed for a while: it hides
    clock = clock + 500
    d:prerender()
    ok("not placed: hidden", d.visible == false)
    -- the worn one: OIL, half the pulls fail - no error
    local dw = W.newsDemo(host, 2, true)
    dw:demoSize(600)
    view = {0, 0, 800, 2000}
    for _ = 1, 5 do clock = clock + 16; dw:hostAt(host, 10, 20, view); dw:prerender() end
    rand = 0.3
    dw.demo.gen:getModData().knoxSwitch = true
    dw:jerk(1)
    ok("worn demo fails a pull", not dw.gen:isActivated() and not dw.broken)
    ok("demo clips nest at most two", stencilMax <= 2, stencilMax)
end

-- 6c. the post's drawn backdrop: lit while a generator of the post runs
do
    local NB = KnoxNewsBack
    local st = {}
    clock = clock + 1000
    local f = NB.litFor(st, false, clock)
    ok("backdrop dark while all stand", f == 0)
    for _ = 1, 30 do clock = clock + 16; f = NB.litFor(st, true, clock) end
    ok("lights up in a moment", st.v == 1 and f > 0.9, st.v)
    for _ = 1, 30 do clock = clock + 16; NB.litFor(st, false, clock) end
    ok("fades slowly when stopped", st.v > 0.3 and st.v < 1, st.v)
    for _ = 1, 200 do clock = clock + 16; NB.litFor(st, false, clock) end
    ok("out at last", st.v == 0)
    local ui = ISPanel:new(0, 0, 800, 600)
    draws0 = draws
    NB.draw(ui, "power", 0, 0, 800, 600, KnoxTheme.color.accent, 1)
    ok("backdrop draws", draws > draws0)
end

-- 7. snapshots (snap=<folder>): a frame of each state written down for tools\gen\snap.ps1
if snap then
    rand = 0.5
    SandboxVars = {GeneratorFuelConsumption = 0.1}   -- (the game's default: a house 0.03 L/h)
    local function shot(w, name)
        rec = {}
        record("W", w.x, w.y, w:getWidth(), w:getHeight())
        frame(w, 1)
        writefile(snap .. "/" .. name .. ".txt", table.concat(rec, "\n"))
        rec = nil
    end
    local three = {"Fridge (0.08 L/h)", "Lights x4 (0.008 L/h)", "Stove (0.09 L/h)"}
    for _, sc in ipairs({{1920, 1080, 48, "1080"}, {2560, 1440, 64, "1440"}}) do
        screenW, screenH, KnoxTheme.cell = sc[1], sc[2], sc[3]
        local g = genState()
        g.items = three
        g.use, g.fuel = 0.03, 10
        local w = newWindow(g)
        shot(w, sc[4] .. "_1_idle")
        g.on = true
        w.itemsAt = 0
        frame(w, 60)
        shot(w, sc[4] .. "_2_running")
        g.inside, g.cond = true, 30
        clock = clock + (800 - KnoxTheme.mod(clock, 800))   -- (the blinking lamps lit)
        frame(w, 1)
        shot(w, sc[4] .. "_3_worn_inside")
        g.inside, g.cond = false, 82
        mouse = {(496 + 19) * w.s, (215 + 20) * w.s}
        frame(w, 1)
        shot(w, sc[4] .. "_4_tip")
        -- the cord held, pulled down and aside
        local H = w.R[6]
        mouse = {H.x * w.s, (H.y + 4) * w.s}
        w:onMouseDown(mouse[1], mouse[2])
        buttonDown = true
        for i = 1, 20 do
            mouse = {(H.x + 30 * i / 20) * w.s, (H.y + 4 + 45 * i / 20) * w.s}
            frame(w, 1)
        end
        shot(w, sc[4] .. "_5_pulling")
        buttonDown = false
        frame(w, 1)
        mouse = nil
        g.on, g.conn = false, false
        frame(w, 60)
        shot(w, sc[4] .. "_6_off_unplugged")
        W.instance = nil
    end
    -- the news post's pictures (tools\make_news_gen.ps1): the demo window, no plate, 1440p
    screenW, screenH, KnoxTheme.cell = 2560, 1440, 64
    local host = {addChild = function() end}
    local view = {0, 0, 4000, 4000}
    local d = W.makeDemo(false)
    d:demoSize(99999)
    local function df(n)
        for _ = 1, n do clock = clock + 16; d:hostAt(host, 10, 20, view); d:prerender() end
    end
    local function dshot(name)
        rec = {}
        df(1)
        record("W", d:getX(), d:getY(), d:getWidth(), d:getHeight())
        writefile(snap .. "/" .. name .. ".txt", table.concat(rec, "\n"))
        rec = nil
    end
    df(5)
    d.gen:getModData().knoxSwitch = true
    d.demo.g.on = true
    df(90)
    dshot("news_run")
    local H = d.R[6]
    mouse = {H.x * d.s, (H.y + 4) * d.s}
    d:onMouseDown(mouse[1], mouse[2])
    buttonDown = true
    for i = 1, 20 do
        mouse = {(H.x + 34 * i / 20) * d.s, (H.y + 4 + 52 * i / 20) * d.s}
        df(1)
    end
    dshot("news_pull")
    buttonDown = false
    mouse = nil
    -- the card's banner: the load dial 204 px high, drawn at that size (no scaling: sharp)
    KnoxTheme.cell = 204 / 144 * 48 / 1.25
    d = W.makeDemo(false, true)
    d:demoSize(99999)
    df(90)
    dshot("news_banner")
    -- the post's backdrop with its text, dark and lit (1440p: the reader's text panel)
    KnoxTheme.cell = 64
    local body, head = KnoxTheme.makeFont("body", 64 * 0.31), KnoxTheme.makeFont("title", 64 * 0.42)
    local lines = {}
    for l in string.gmatch(getText("IGUI_KnoxGen_Spec") .. "\n", "[^\n]+") do table.insert(lines, l) end
    for _, lit in ipairs({0, 1}) do
        local ui = ISPanel:new(0, 0, 1500, 1000)
        rec = {}
        ui:drawRect(0, 0, 1500, 1000, 0.97, 0.071, 0.078, 0.078)
        KnoxNewsBack.draw(ui, "power", 0, 0, 1500, 1000, KnoxTheme.color.accent, lit)
        -- (the post's own kind of words: a long Russian text cut in lines, as the reader wraps)
        local text = getText("IGUI_KnoxTB_gen_fuel_Want") .. " " .. getText("IGUI_KnoxTB_gen_pull_Want")
        local y = 120
        for i = 1, 16 do
            KnoxTheme.drawText(ui, string.sub(text, (i - 1) * 88 + 1, i * 88), 300, y, 0.85, 0.84, 0.78, 1, body)
            y = y + 36
        end
        record("W", 0, 0, 1500, 1000)
        writefile(snap .. "/back_" .. (lit > 0 and "on" or "off") .. ".txt", table.concat(rec, "\n"))
        rec = nil
    end
end

local miss = {}
for k in pairs(missingText) do table.insert(miss, k) end
ok("texts", #miss == 0, table.concat(miss, " "))
ok("draws", #bad == 0, table.concat(bad, ", "))
ok("clips nest at most two (a demo: its view and a drum)", stencilMax <= 2, stencilMax)
print("pass " .. pass .. " fail " .. fail .. " draws " .. draws)
