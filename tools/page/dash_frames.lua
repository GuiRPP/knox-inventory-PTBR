-- KnoxDashboard.lua outside the game (tools/page/dash_frames.ps1) playing a short
-- scene for the Workshop page's GIF: the sedan at night - the key goes in, the
-- lamp check, the engine cranks and runs, the headlights light the dials, the car
-- drives off through the gears, the tape goes in; then the pickup started on the
-- wires. The car is tools/dash/stubs.lua's pretend car, its state set as the game
-- would change it; everything on the panel is the panel's own drawing, written down
-- a frame every 80 ms (snap=<folder>, painted by tools/dash/snap.ps1).

local D = KnoxDashboard
local T = KnoxTheme

-- the texts of the language asked for (lang=EN)
local TX = {}
local src = readfile(root .. "/42/media/lua/shared/Translate/" .. (lang or "EN") .. "/IG_UI.json") or ""
for k, v in string.gmatch(src, '"([%w_]+)":%s*"(.-)",?\r?\n') do TX[k] = v end
function getText(k, a1)
    local v = TX[k] or k
    if a1 then v = string.gsub(v, "%%1", tostring(a1)) end
    return v
end

-- Knox's fonts as tables (style, size), as tools/dash/test.lua has them
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

-- 1440p, the 64 px cell of every news and page picture
screenW, screenH, T.cell = 2560, 1440, 64
local vdash = {character = player, playerNum = 0, flickingTimer = 0, removeFromUIManager = function() end}

local n = 0
--- `ms` of game time; a frame written down every 80 ms of it (5 of the panel's 16)
local function play(d, ms, each)
    local steps = math.floor(ms / 16)
    for i = 1, steps do
        clock = clock + 16
        if each then each(i * 16) end
        if i % 5 == 0 then
            rec = {}
            d:prerender()
            n = n + 1
            writefile(snap .. "/" .. string.format("f%04d", n) .. ".txt", table.concat(rec, "\n"))
            rec = nil
        else
            d:prerender()
        end
    end
end

local function car(name, c)
    radio.has, radio.on, radio.power, radio.theme, radio.channel, radio.vol = true, false, true, "game", 98200, 0.6
    radio.shuffle, radio.rpt, radio.playing, radio.mine, radio.calls = false, "all", false, true, {}
    T.settings["car.music"] = "game"
    local cr = makeCar(name, c)
    mouse = nil
    ISVehicleDashboard.setVehicle(vdash, cr)
    local d = D.instance
    d.shownAt, d.goneAt = clock, nil
    ISVehicleDashboard.setVehicle(vdash, cr)
    return d
end

local function base()
    return {keyIn = false, hot = false, running = false, starting = false, kmh = 0, rpm = 0, gear = "N", fuel = 0.7, cruise = 0,
        lights = false, doors = nil, heater = true, heaterMd = {active = false, temperature = 0}, trunk = true, trunkLocked = false,
        window = false, gears = 5}
end

-- the sedan at night
daylight = 0
local c = base()
local d = car("CarNormal", c)
play(d, 700)                                  -- the panel comes up, dark
c.keyIn = true
play(d, 1800)                                 -- the key turns: the lamp check, the needles' sweep
c.starting = true
play(d, 900)                                  -- cranking
c.starting, c.running, c.rpm = false, true, 850
play(d, 700)
c.lights = true
play(d, 800)                                  -- the headlights light the dials
-- off through the gears: the speed builds, the revs climb in each and drop at a change
local gears = {{"1", 0, 18}, {"2", 18, 38}, {"3", 38, 64}}
for _, gr in ipairs(gears) do
    c.gear = gr[1]
    play(d, 1100, function(t)
        local k = math.min(1, t / 1100)
        c.kmh = gr[2] + (gr[3] - gr[2]) * k
        c.rpm = 1300 + 1900 * k
    end)
end
c.rpm = 2350
-- the tape: the radio on, own music playing (the reels turn)
radio.on, radio.theme, radio.playing = true, "mine", true
T.settings["car.music"] = "mine"
play(d, 1800)
c.doors = "all"
play(d, 900)
D.hideFor(vdash)
for _ = 1, 20 do clock = clock + 16; d:prerender() end
local sedanFrames = n

-- the pickup by day, no key: the wires spark while the engine cranks
daylight = 1
local p = base()
p.trunk, p.fuel = false, 0.35
local dp = car("PickUpTruck", p)
play(dp, 600)
p.hot, p.starting = true, true
play(dp, 1200)
p.starting, p.running, p.rpm = false, true, 900
play(dp, 1500)
print("frames " .. sedanFrames .. " " .. (n - sedanFrames))
