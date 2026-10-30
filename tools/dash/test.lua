-- KnoxDashboard.lua outside the game (tools/dash/test.ps1): both bodies, every
-- state of the mockup, every control hovered, clicked, right-clicked and turned,
-- on four screens. Checks: no error stops the panel, no draw gets a number that is
-- not one, every picture asked for is there, every text is in the translations,
-- the captions stay on the panel and don't run into each other, the clicks reach
-- the game's handlers, the heater's command and the radio.

local D = KnoxDashboard
local T = KnoxTheme
local pass, fail = 0, 0
local function ok(name, cond, info)
    if cond then pass = pass + 1 else
        fail = fail + 1
        print("FAIL " .. name .. (info ~= nil and (": " .. tostring(info)) or ""))
    end
end

-- the Russian texts (the longest): getText answers from them, a missing key is a fault
-- (lang=EN: the English ones - the news pictures in English, make_news_beta3.ps1)
local RU = {}
local src = readfile(root .. "/42/media/lua/shared/Translate/" .. (lang or "RU") .. "/IG_UI.json") or ""
for k, v in string.gmatch(src, '"([%w_]+)":%s*"(.-)",?\r?\n') do RU[k] = v end
local GAME = {Tooltip_Dashboard_Headlights = 1, Tooltip_Dashboard_LockedDoors = 1, Tooltip_Dashboard_Engine = 1, Tooltip_Dashboard_Battery = 1,
    Tooltip_Dashboard_SpeedRegulator = 1, Tooltip_Dashboard_Shift = 1, Tooltip_Dashboard_Heater = 1, Tooltip_Dashboard_NoKey = 1,
    UI_Vehicle_HeaterNeedKey = 1}
local missingText = {}
function getText(k, a1)
    local v = RU[k]
    if not v then
        if GAME[k] then return "Текст игры " .. k end
        missingText[k] = true
        return k
    end
    if a1 then v = string.gsub(v, "%%1", tostring(a1)) end
    return v
end

-- Knox's fonts as tables (style, size): widths from the size, as the real ones about are
T.javaFonts = true
T.fontText, T.fontTile, T.fontHeader = {style = "body", size = 15}, {style = "head", size = 12}, {style = "title", size = 20}
function T.fontH(f) return type(f) == "table" and math.floor(f.size * 1.25) or 14 end
function T.measure(f, s)
    local size = type(f) == "table" and f.size or 12
    local k = (type(f) == "table" and f.style == "head") and 0.66 or 0.58
    return math.floor(#(s or "") * size * k + 0.5)
end
function T.wrap(text, f, width)
    local out, cur = {}, ""
    for word in string.gmatch(text, "%S+") do
        local t = cur == "" and word or (cur .. " " .. word)
        if T.measure(f, t) > width and cur ~= "" then table.insert(out, cur); cur = word else cur = t end
    end
    if cur ~= "" then table.insert(out, cur) end
    return out
end
local drawTip = D.drawTip
function D:drawTip(...) inTip = true; drawTip(self, ...); inTip = false end
local label = T.label
function T.label(ui, s, r, c, o)
    local w = label(ui, s, r, c, o)
    local l = labels[#labels]
    l.align, l.font, l.a = o.align or "left", o.font, o.a or 1
    return w
end

local vdash = {character = player, playerNum = 0, flickingTimer = 0, removeFromUIManager = function() end}

local function base()
    return {keyIn = false, hot = false, running = false, starting = false, kmh = 0, rpm = 0, gear = "N", fuel = 0.6, cruise = 0,
        lights = false, doors = nil, heater = true, heaterMd = {active = false, temperature = 0}, trunk = true, trunkLocked = false,
        window = false, gears = 5}
end
local function radioReset()
    radio.has, radio.on, radio.power, radio.theme, radio.channel, radio.vol = true, false, true, "game", 98200, 0.6
    radio.shuffle, radio.rpt, radio.playing, radio.mine, radio.calls = false, "all", false, true, {}
    T.settings["car.music"] = "game"
    daylight = 1
end

local STATES = {
    {"off", function(c) end},
    {"ign", function(c) c.keyIn = true end},
    {"night", function(c)
        c.keyIn, c.running, c.kmh, c.rpm, c.gear, c.lights, c.cruise, c.doors = true, true, 64, 2350, "3", true, 60, "all"
        c.heaterMd.active, c.heaterMd.temperature, c.trunkLocked = true, 15, true
        radio.on, daylight = true, 0
    end},
    {"low", function(c) c.keyIn, c.running, c.kmh, c.rpm, c.gear, c.fuel = true, true, 47, 1900, "2", 0.04 end},
    {"hot", function(c) c.hot, c.starting = true, true end},
    {"fm", function(c) c.keyIn, c.running, c.rpm, c.doors = true, true, 850, "some"; radio.on = true end},
    {"tape", function(c)
        c.keyIn, c.running, c.rpm, c.window, c.heaterMd.active = true, true, 850, true, true
        radio.on, radio.theme, radio.playing, radio.shuffle, radio.rpt = true, "mine", true, true, "one"
        T.settings["car.music"] = "mine"
    end},
    {"noradio", function(c) c.keyIn = true; radio.has = false end},
    {"noheater", function(c) c.keyIn, c.heater = true, false end},
}

local function frames(d, n)
    for _ = 1, n do
        clock = clock + 16
        d:prerender()
    end
end

--- The captions on the panel: each on it, none over another.
local function captions(tag, d)
    local out, boxes = {}, {}
    for _, l in ipairs(labels) do
        if not l.tip and l.a > 0.05 and l.s ~= "" then
            local tw = T.measure(l.font, l.s)
            local x0
            if l.align == "centre" then x0 = l.x + l.w / 2 - tw / 2
            elseif l.align == "right" then x0 = l.x + l.w - tw
            else x0 = l.x end
            local size = type(l.font) == "table" and l.font.size or 12
            local cy = l.y + l.h / 2
            local box = {s = l.s, x0 = x0, x1 = x0 + tw, y0 = cy - size * 0.36, y1 = cy + size * 0.36}
            if box.x0 < 0 or box.x1 > d.W or box.y0 < 0 or box.y1 > d.H then table.insert(out, l.s .. " off the panel") end
            table.insert(boxes, box)
        end
    end
    for i = 1, #boxes do
        for j = i + 1, #boxes do
            local a, b = boxes[i], boxes[j]
            if a.x0 < b.x1 - 1 and b.x0 < a.x1 - 1 and a.y0 < b.y1 - 1 and b.y0 < a.y1 - 1 and not (a.s == b.s and a.x0 == b.x0) then
                table.insert(out, a.s .. " over " .. b.s)
            end
        end
    end
    ok(tag .. ": captions on the panel, apart", #out == 0, table.concat(out, "; "))
end

local SCREENS = {{1920, 1080, 48}, {2560, 1440, 64}, {3840, 2160, 96}, {1280, 1024, 37}}
for _, scr in ipairs(SCREENS) do
    screenW, screenH, T.cell = scr[1], scr[2], scr[3]
    -- (a van: the pickup's body with a lockable trunk - its button, linlin 2026-10-25)
    for _, carName in ipairs({"CarNormal", "PickUpTruck", "Van"}) do
        for _, st in ipairs(STATES) do
            local tag = scr[1] .. "x" .. scr[2] .. " " .. carName .. " " .. st[1]
            radioReset()
            local c = base()
            if carName == "PickUpTruck" then c.trunk = false end
            st[2](c)
            local car = makeCar(carName, c)
            mouse = nil
            ISVehicleDashboard.setVehicle(vdash, car)
            local d = D.instance
            d.shownAt, d.goneAt = clock, nil   -- (a fresh car: the last one's panel went away)
            ISVehicleDashboard.setVehicle(vdash, car)
            bad, draws, labels = {}, 0, {}
            frames(d, 90)
            ok(tag .. ": drawn, no error", d.shownAt ~= nil and draws > 200, draws)
            ok(tag .. ": no draw with a broken number", #bad == 0, table.concat(bad, ","))
            ok(tag .. ": the body", d.body == (carName == "CarNormal" and D.SEDAN or carName == "Van" and D.TRUCK or D.PICKUP))
            if carName == "Van" then
                local has = false
                for _, h in ipairs(d.hits) do if h.id == "trunk" then has = true end end
                ok(tag .. ": the trunk's button", has)
            end
            ok(tag .. ": fits the screen", d.W <= screenW and d.H <= screenH * 0.16, d.W .. "x" .. d.H)
            labels = {}
            frames(d, 1)
            captions(tag, d)
            -- every control: found under the mouse, its tip, a click, a right click, the wheel
            if scr[3] == 48 then
                for _, h in ipairs(d.hits) do
                    local cx, cy = h.x + h.w / 2, h.y + h.h / 2
                    local found = d:hitAt(cx, cy)
                    ok(tag .. ": " .. h.id .. " found under the mouse", found and found.id == h.id, found and found.id)
                    mouse = {cx, cy}
                    frames(d, 25)
                    d:onMouseDown(cx, cy); d:onMouseUp(cx, cy); frames(d, 2)
                    d:onRightMouseDown(cx, cy); d:onRightMouseUp(cx, cy); frames(d, 2)
                    d:onMouseWheel(-1); d:onMouseWheel(1); frames(d, 2)
                    ok(tag .. ": " .. h.id .. " hovered and used, no error", d.shownAt ~= nil and #bad == 0, table.concat(bad, ","))
                end
                mouse = nil
            end
            D.hideFor(vdash)
            frames(d, 20)
        end
    end
end

-- What the clicks reach (the sedan, the key in, the engine off, the radio on)
screenW, screenH, T.cell = 1920, 1080, 48
radioReset()
local c = base()
c.keyIn = true
radio.on = true
local car = makeCar("CarNormal", c)
ISVehicleDashboard.setVehicle(vdash, car)
local d = D.instance
d.shownAt, d.goneAt = clock, nil
frames(d, 10)
local function hitOf(id) for _, h in ipairs(d.hits) do if h.id == id then return h end end end
local function click(id, right)
    local h = hitOf(id)
    mouse = {h.x + h.w / 2, h.y + h.h / 2}
    frames(d, 1)
    if right then d:onRightMouseDown(0, 0); d:onRightMouseUp(0, 0) else d:onMouseDown(0, 0); d:onMouseUp(0, 0) end
    frames(d, 1)
end
local function said(list, what) for _, v in ipairs(list) do if v == what then return true end end return false end
gameCalls = {}
click("lights"); ok("lights: the game's handler", said(gameCalls, "onClickHeadlights"))
click("doors"); ok("doors: the game's handler", said(gameCalls, "onClickDoors"))
click("trunk"); ok("trunk: the game's handler", said(gameCalls, "onClickTrunk"))
gameCalls = {}
click("ign"); ok("the key in: a click starts", said(gameCalls, "onClickEngine") and not said(gameCalls, "onClickKeys"))
gameCalls = {}
click("ign", true); ok("the key in: a right click takes it out", said(gameCalls, "onClickKeys"))
c.keyIn = false
gameCalls = {}
click("ign"); ok("no key: a click puts it in", said(gameCalls, "onClickKeys"))
c.keyIn, c.hot = false, true
gameCalls = {}
click("ign"); ok("hot-wired: a click joins the wires", said(gameCalls, "onClickEngine"))
c.hot, c.keyIn = false, true
commands = {}
click("heater"); ok("heater: the game's command, on", commands[1] and commands[1].command == "toggleHeater" and commands[1].on == true)
c.heaterMd.temperature = 0
commands = {}
click("temp"); ok("temperature: a click turns it a place up", commands[1] and commands[1].temp == 8, commands[1] and commands[1].temp)
c.heaterMd.temperature = 25
commands = {}
click("temp"); ok("temperature: past the last place round to the first", commands[1] and commands[1].temp == -25, commands[1] and commands[1].temp)
gameCalls = {}
click("heater", true); ok("heater: a right click opens the game's window", said(gameCalls, "onClickHeater"))
radio.calls = {}
click("vol"); ok("VOL: a click switches the set", said(radio.calls, "power"))
radio.on = true
click("vol", true); ok("VOL: a right click opens the set's window", said(radio.calls, "window"))
radio.calls = {}
KnoxMenuMusic.list = {{title = "88.6"}, {title = "91.4"}, {title = "95.0"}, {title = "98.2"}, {title = "101.6"}, {title = "104.8"}}
click("p3"); ok("preset 3: tunes the third station", said(radio.calls, "play 3"))
click("seekR"); ok("SEEK: next station", said(radio.calls, "next"))
click("tune"); ok("TUNE: a click seeks", said(radio.calls, "next"))
radio.calls = {}
local h = hitOf("tune"); mouse = {h.x + h.w / 2, h.y + h.h / 2}; frames(d, 1); d:onMouseWheel(-1)
ok("TUNE: the wheel steps 0.2 MHz", said(radio.calls, "tune 98400"))
radio.calls = {}
h = hitOf("display"); mouse = {h.x + h.w / 2, h.y + h.h / 2}; frames(d, 1); d:onMouseWheel(-1)
ok("the display's wheel: the next station", said(radio.calls, "next"))
gameCalls = {}
h = hitOf("lights"); mouse = {h.x + h.w / 2, h.y + h.h / 2}; frames(d, 1)
c.lights = false; d:onMouseWheel(1)
ok("the headlight knob: the wheel down leaves them off", not said(gameCalls, "onClickHeadlights"))
d:onMouseWheel(-1)
ok("the headlight knob: the wheel up switches them on", said(gameCalls, "onClickHeadlights"))
h = hitOf("vol"); mouse = {h.x + h.w / 2, h.y + h.h / 2}; frames(d, 1); d:onMouseWheel(-1)
ok("VOL: the wheel turns the volume", said(radio.calls, "vol") and d.volAt == clock)
radio.calls = {}
click("slot"); ok("the slot: the tape in, own music", radio.theme == "mine" and said(radio.calls, "choose mine"))
radio.calls = {}
click("p1"); click("p2"); click("p3"); click("p4")
ok("with the tape: 1 back, 2 on, 3 MIX, 4 RPT", said(radio.calls, "prev") and said(radio.calls, "next") and said(radio.calls, "shuffle") and said(radio.calls, "repeat"))
radio.calls = {}
click("seekR"); ok("with the tape: SEEK winds on 10 s", said(radio.calls, "seek 60000"))
radio.calls = {}
h = hitOf("tune"); mouse = {h.x + h.w / 2, h.y + h.h / 2}; frames(d, 1); d:onMouseWheel(-1); d:onMouseWheel(1)
ok("with the tape: TUNE's wheel steps through the tracks", said(radio.calls, "next") and said(radio.calls, "prev"))
radio.calls = {}
h = hitOf("display"); mouse = {h.x + h.w / 2, h.y + h.h / 2}; frames(d, 1); d:onMouseWheel(-1); d:onMouseWheel(1)
ok("with the tape: the display's wheel steps through the tracks", said(radio.calls, "next") and said(radio.calls, "prev"))
T.settings["car.music"] = "mine:Road"
radio.theme = "mine"
click("eject"); ok("eject: the broadcast, the tape out", radio.theme == "game" and d.tapeOut == true and T.settings["car.music.tape"] == "mine:Road")
click("slot"); ok("the tape back: its folder kept", T.settings["car.music"] == "mine:Road" and d.tapeOut == false)
click("display"); frames(d, 2); ok("the display: the card opens", d.cardOpen == true and cardTracks > 0)
click("display"); ok("the display again: the card closes", d.cardOpen == false)
click("display")
mouse = nil
buttonDown = true; frames(d, 1); buttonDown = false; frames(d, 1)
ok("a click off the dashboard: the card closes", d.cardOpen == false)
click("display")
buttonDown = true; frames(d, 1); buttonDown = false; frames(d, 1)
ok("a press on the dashboard: the card stays", d.cardOpen == true)
click("display")
radio.mine = false
radio.theme = "game"
click("slot"); ok("no music of one's own: NO TAPE, the broadcast stays", radio.theme == "game" and clock - d.noTapeAt < 100)
D.hideFor(vdash)
frames(d, 20)

-- snapshots (snap=<folder>): a frame of each written down for tools\dash\snap.ps1
if snap then
    local SNAPS = {
        {"sedan_night_1080", "CarNormal", 3, nil, 1},
        {"sedan_ign_1080", "CarNormal", 2, nil, 1, 380},
        {"sedan_tape_1080", "CarNormal", 7, "display", 1},
        {"truck_low_1080", "PickUpTruck", 4, "fuelDial", 1},
        {"truck_fm_1080", "PickUpTruck", 6, "vol", 1},
        {"truck_hot_1080", "PickUpTruck", 5, nil, 1, 700},
        {"sedan_night_1440", "CarNormal", 3, nil, 2},
        {"sedan_fm_1280", "CarNormal", 6, nil, 4},
        -- (the news pictures of the beta's update 3 - tools\make_news_beta3.ps1)
        {"news_sedan_1440", "CarNormal", 3, nil, 2},
        {"news_truck_1440", "PickUpTruck", 3, nil, 2},
        {"news_tape_1440", "CarNormal", 7, nil, 2},
        -- (the radio's close-up at 4K: drawn pixel for pixel, not blown up from 1440p)
        {"news_tape_2160", "CarNormal", 7, nil, 3},
        {"news_hot_1440", "PickUpTruck", 5, nil, 2, 700},
        -- (the pickup's body with its trunk's button: a van, 2026-10-28)
        {"van_night_1080", "Van", 3, nil, 1},
        {"van_trunk_1080", "Van", 6, "trunk", 1},
        {"van_night_1440", "Van", 3, nil, 2},
        {"van_night_2160", "Van", 3, nil, 3},
        {"van_fm_1280", "Van", 6, nil, 4},
        {"pickup_night_1440", "PickUpTruck", 3, nil, 2},
    }
    for _, sn in ipairs(SNAPS) do
        local scr = SCREENS[sn[5]]
        screenW, screenH, T.cell = scr[1], scr[2], scr[3]
        radioReset()
        local cs = base()
        if sn[2] == "PickUpTruck" then cs.trunk = false end
        STATES[sn[3]][2](cs)
        local carS = makeCar(sn[2], cs)
        mouse = nil
        ISVehicleDashboard.setVehicle(vdash, carS)
        local ds = D.instance
        ds.shownAt, ds.goneAt = clock, nil
        ISVehicleDashboard.setVehicle(vdash, carS)
        if sn[6] then
            -- (a moment after the key goes in - the bulb check, the needles' sweep - or
            -- after the wires first touch)
            local keyIn = cs.keyIn
            cs.keyIn = false
            frames(ds, 30)
            cs.keyIn = keyIn
            frames(ds, math.floor(sn[6] / 16))
        else
            frames(ds, 120)
        end
        if sn[4] then
            for _, hh in ipairs(ds.hits) do if hh.id == sn[4] then mouse = {hh.x + hh.w / 2, hh.y + hh.h / 2} end end
            frames(ds, 40)
        end
        rec = {}
        frames(ds, 1)
        writefile(snap .. "/" .. sn[1] .. ".txt", table.concat(rec, "\n"))
        rec = nil
        D.hideFor(vdash)
        frames(ds, 20)
    end
end

-- the news' live panel (KnoxDashboard.demo): the same panel on a pretend car - its
-- controls drive that car, nothing goes to the game, the camp's radio or the settings
do
    screenW, screenH, T.cell = 1920, 1080, 48
    local host = {wheeled = 0, downs = 0}
    function host:onMouseWheel(d) self.wheeled = self.wheeled + 1 return true end
    function host:onMouseDown(x, y) self.downs = self.downs + 1 return true end
    function host:addChild(c) self.child = c end
    local calls0, cmds0, radio0 = #gameCalls, #commands, #radio.calls
    local tape0 = T.settings["car.music.tape"]
    for _, kind in ipairs({"sedan", "pickup"}) do
        local d = D.newsDemo(host, kind, kind, false)
        ok("demo " .. kind .. ": made once a line", D.newsDemo(host, kind, kind, false) == d)
        local w, h = d:demoSize(700)
        ok("demo " .. kind .. ": no wider than the column", w <= 700, w)
        local view = {0, 0, 2000, 2000}
        local function frame(n)
            for _ = 1, n do
                clock = clock + 16
                d:hostAt(host, 10, 50, view)
                d:prerender()
            end
        end
        local function at(id)
            for _, hh in ipairs(d.hits) do if hh.id == id then return {hh.x + hh.w / 2, hh.y + hh.h / 2} end end
        end
        local function click(id, right)
            mouse = at(id)
            ok("demo " .. kind .. ": there is " .. id, mouse ~= nil)
            if not mouse then return end
            frame(2)
            if right then d:onRightMouseDown(mouse[1], mouse[2]); d:onRightMouseUp(mouse[1], mouse[2])
            else d:onMouseDown(mouse[1], mouse[2]); d:onMouseUp(mouse[1], mouse[2]) end
            frame(2)
        end
        stencilMax, draws = 0, 0
        frame(10)
        ok("demo " .. kind .. ": drawn", d.visible and not d.broken and d.host == host and draws > 2000, draws)
        -- (the clips nest in the game: one for its view, one more for a figure window,
        -- all off by the frame's end - piled up, all after the first window was lost)
        ok("demo " .. kind .. ": its clips nest two deep at most, none left", stencilMax <= 2 and stencil == 0,
            tostring(stencilMax) .. " " .. tostring(stencil))
        click("ign")
        frame(80)
        ok("demo " .. kind .. ": the key starts the engine", d.demo.running)
        mouse = at("speed")
        frame(2)
        for _ = 1, 5 do d:onMouseWheel(-1) end
        frame(250)
        ok("demo " .. kind .. ": the wheel over the speedometer is the gas", d.demo.kmh > 20 and d.demo.gear ~= "N" and d.demo.rpm > 1000,
            tostring(d.demo.kmh) .. " " .. tostring(d.demo.gear))
        ok("demo " .. kind .. ": the speedometer's tip says so", d.tipT and d.tipT.note == getText("IGUI_Knox_Dash_Demo_Gas"),
            d.tipT and d.tipT.note)
        -- the road's part: the cruise, a bump
        click("tt_cruise")
        local cr = d.demo.cruiseKmh
        ok("demo " .. kind .. ": a click on the cruise window sets it", d.demo.cruise and cr >= 20 and cr % 5 == 0 and d.st.regulator, cr)
        mouse = at("tt_cruise")
        frame(2)
        d:onMouseWheel(-1)
        frame(200)
        ok("demo " .. kind .. ": the wheel over it, faster", d.demo.cruiseKmh == cr + 5 and math.abs(d.demo.kmh - (cr + 5)) < 3,
            tostring(d.demo.cruiseKmh) .. " " .. tostring(d.demo.kmh))
        mouse = at("speed")
        frame(2)
        d:onMouseWheel(1)
        ok("demo " .. kind .. ": the gas down lets the cruise go", not d.demo.cruise)
        click("speed")
        ok("demo " .. kind .. ": a click on the speedometer, a bump", d.flickAt ~= nil and clock - d.flickAt < 200)
        click("lights")
        ok("demo " .. kind .. ": the lights", d.demo.lights)
        click("doors")
        ok("demo " .. kind .. ": the locks", d.demo.doors == "all")
        if kind == "sedan" then
            click("trunk")
            ok("demo sedan: the trunk", d.demo.trunkLocked)
        end
        click("heater")
        ok("demo " .. kind .. ": the heater", d.demo.heat.active)
        click("temp")
        ok("demo " .. kind .. ": its knob", d.demo.heat.temperature == 8, d.demo.heat.temperature)
        click("slot")
        ok("demo " .. kind .. ": the tape in", d.demo.radio.theme == "mine" and d.demo.r.musicPlaying())
        click("p2")
        ok("demo " .. kind .. ": a tape's key", d.demo.radio.track == 2)
        click("eject")
        ok("demo " .. kind .. ": the tape out", d.demo.radio.theme == "game")
        click("p2")
        ok("demo " .. kind .. ": a station", d.demo.radio.freq == 91200)
        -- back from the first station and the first track: round to the last (the
        -- game's Lua: -1 % 6 is -1 - station 0 was an error, the author 2026-10-21)
        click("p1")
        mouse = at("display")
        frame(2)
        d:onMouseWheel(1)
        ok("demo " .. kind .. ": back from the first station, the last", d.demo.radio.freq == 101200 and d.demo.mm.at == 6, d.demo.radio.freq)
        d.demo.mm.choose("mine")
        d.demo.radio.track = 1
        d:onMouseWheel(1)
        ok("demo " .. kind .. ": back from the first track, the last", d.demo.radio.track == 8, d.demo.radio.track)
        d.demo.mm.choose("game")
        -- the tank empties while it runs: empty, the engine dies, then it is filled
        d.demo.fuel = 0.0005
        frame(30)
        ok("demo " .. kind .. ": the tank empty, the engine dies", not d.demo.running)
        frame(200)
        ok("demo " .. kind .. ": then it is filled", d.demo.fuel > 0.5)
        click("ign")
        frame(80)
        ok("demo " .. kind .. ": starts again", d.demo.running)
        click("ign")
        ok("demo " .. kind .. ": the engine off", not d.demo.running)
        click("ign", true)
        frame(20)
        ok("demo " .. kind .. ": the key out", not d.demo.keyIn)
        -- off its knobs the wheel scrolls the news; a press where it is hidden is the news'
        mouse = {1, 1}
        frame(2)
        local wh = host.wheeled
        d:onMouseWheel(1)
        ok("demo " .. kind .. ": the wheel off the knobs scrolls the news", host.wheeled == wh + 1)
        view[2] = 50 + h - 10
        frame(2)
        local dn = host.downs
        d:onMouseDown(5, 5)
        ok("demo " .. kind .. ": a press in its hidden part is the news'", host.downs == dn + 1)
        view[2] = 4000
        frame(2)
        ok("demo " .. kind .. ": out of the view, hidden", not d.visible)
        view[2] = 0
        frame(2)
        clock = clock + 400
        d:prerender()
        ok("demo " .. kind .. ": no longer placed, hidden", not d.visible)
        ok("demo " .. kind .. ": no error", not d.broken)
    end
    mouse = nil
    ok("demo: nothing went to the game, the camp's radio or the settings",
        #gameCalls == calls0 and #commands == cmds0 and #radio.calls == radio0 and T.settings["car.music.tape"] == tape0)
end

ok("every clip set is cleared", stencil == 0, stencil)
-- the dials' tips: the tachometer's with the engine off too, the speedometer's
radioReset()
local c2 = base()
c2.keyIn = true
ISVehicleDashboard.setVehicle(vdash, makeCar("CarNormal", c2))
local d2 = D.instance
d2.shownAt, d2.goneAt = clock, nil
frames(d2, 5)
for _, id in ipairs({"tach", "speed"}) do
    for _, hh in ipairs(d2.hits) do if hh.id == id then mouse = {hh.x + hh.w / 2, hh.y + hh.h / 2} end end
    frames(d2, 40)
    ok(id .. ": its tip with the engine off", d2.tipT ~= nil and d2.tipK > 0.5)
end
mouse = nil
D.hideFor(vdash)
frames(d2, 20)

local miss = {}
for k in pairs(missingPics) do table.insert(miss, k) end
ok("every picture asked for is there", #miss == 0, table.concat(miss, ", "))
miss = {}
for k in pairs(missingText) do table.insert(miss, k) end
ok("every text is translated", #miss == 0, table.concat(miss, ", "))
print(string.format("DONE pass=%d fail=%d", pass, fail))
