-- The car's dashboard in Knox's look: in place of the game's ISVehicleDashboard,
-- for the driver, at the bottom in the middle of the screen as the game's.
-- Mockup 2 (the author, 2026-10-21: "a real car's dashboard, the buttons not all on
-- one side in a heap but each where it belongs; the radio a real radio with its own
-- face"), as a car of 1993 has it, left to right:
--   the switches by the door - the headlights (a rotary switch; the pickup's a pull
--                    knob), the doors' locks (a rocker with its LED), the trunk's
--                    release (a button with its LED; only a lockable trunk)
--   the cluster    - the tachometer, the speedometer (its figures, the gear, the
--                    cruise's mark), the fuel gauge (the filler's side) in wells
--                    under the visor; the warning lamps behind smoked glass under
--                    the small dials: engine, battery, headlights, cruise and the
--                    speed it holds. The lamps only show: the controls are elsewhere.
--   the column     - the ignition: a click on the key starts or stops the engine
--                    (the key goes to START), a right click takes it out; without
--                    it a click puts it in; hot-wired, a click joins the wires
--   the centre stack - the radio: a 1-DIN cassette set (VOL - on / off, the wheel
--                    turns it; TUNE; the display; the presets 1-6; FM / TAPE; SEEK;
--                    the deck: the player's own music is a tape in it, the eject
--                    pushes it out) - a click on its display brings up the player's
--                    card (KnoxRadioCard); under it the heater (the temperature's 7
--                    places, -25..+25 as the game's knob; on / off; the window lamp)
-- Two bodies by the car's class (its script's name): the sedan (round knobs, a visor
-- with a brow over each well) and the pickup (a rectangular cluster with bolts, a pull
-- knob, levers for the heater, the row of gears). The same radio in both.
-- Everything moves: the panel slides up and down; the needles swing on springs (to
-- the end and back as the ignition comes on); the lamps and LEDs fade, light up one
-- after another for the bulb check; the knobs turn, the rocker tilts, buttons go
-- in; the scales, captions and legends are lit from behind with the headlights,
-- more in the dark; the key turns, the wires spark; a knock makes it all flicker.
-- Clicks go to the game's dashboard's own handlers (onClick*) and to the game's
-- heater command (as its heater window sends it); the radio to KnoxCarRadio.
-- Its pictures: tools\make_dash.ps1 -> media\ui\knoxdash. Nothing new is made in
-- render: the strings, rectangles and colours are made once and filled in.
-- Module "dashboard" (the Modules page): off, the game's own dashboard.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxMenuMusic"
require "Knox/KnoxCarRadio"
require "Vehicles/ISUI/ISVehicleDashboard"
require "Knox/KnoxDashDemo"

local T = KnoxTheme
local R = KnoxCarRadio
local MM = KnoxMenuMusic

KnoxDashboard = ISPanel:derive("KnoxDashboard")
local D = KnoxDashboard

local NEEDLE = {r = 1, g = 0.71, b = 0.28}    -- lit needles and figures (the radio dial's amber)
local CRANK = {r = 1, g = 0.5, b = 0.1}        -- the engine lamp while it cranks (the game's)
local SPARK = {r = 1, g = 0.86, b = 0.55}
local GLOWC = {r = 0.96, g = 0.87, b = 0.6}    -- the backlight of the scales and legends
local VFD = {r = 1, g = 0.74, b = 0.33}        -- the radio's display
local BLACK = {r = 0, g = 0, b = 0}
local WHITE = {r = 1, g = 1, b = 1}
local PAPER = {r = 0.78, g = 0.74, b = 0.64}   -- a tape's label
local COLD_C = {r = 0.45, g = 0.66, b = 0.86}  -- the heater's blue and red (as its pictures)
local HOT_C = {r = 0.86, g = 0.36, b = 0.28}
local IN_MS, OUT_MS = 280, 200
local CHECK_MS, CHECK_STEP = 950, 45   -- the bulb check, each next lamp a moment later
local SWEEP_MS = 480                   -- the needles to the end before they settle
local FLICK_MS = 1700
local TIP_DELAY, TIP_IN = 280, 120
local SEEK_MS, VOL_MS = 700, 1400      -- the display: a seek's running figures, the volume shown
local KEY_OFF, KEY_ON, KEY_START = -35, 35, 68     -- the key's turn, degrees clockwise from up
local SPEED_MAX, TACH_MAX = 120, 7     -- km/h (the game's "fake" speed, as its needle), x1000
-- the heater's knob: its 7 places (the game's heater window's) and where it points
local TEMPS = {-25, -15, -8, 0, 8, 15, 25}
local TEMP_DEG = {-120, -80, -40, 0, 40, 80, 120}
local GEARS = {"R", "N", "1", "2", "3", "4", "5", "6"}

-- The dials, as make_dash.ps1 draws their pictures: the scale from `start` degrees
-- (0 = right, counter-clockwise) through `sweep` clockwise.
-- The numbers are Knox's font, not the pictures': scaled down by the game the
-- pictures' figures came out soft (the author, 2026-10-21: "everything smeared").
-- labels {value, text} on numR of the face's radius, numK of it high.
local function dialSpec(pic, start, sweep, vmax, labels, numR, numK)
    return {start = start, sweep = sweep, vmax = vmax, labels = labels, numR = numR, numK = numK,
        glow = pic .. "_glow", red = pic .. "_red", ticks = pic .. "_ticks"}
end
local TACH = dialSpec("tach", 210, 240, 7, {{0, "0"}, {1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}, {5, "5"}, {6, "6"}, {7, "7"}}, 0.6, 0.22)
local SPEED = dialSpec("speed", 210, 240, 120, {{0, "0"}, {20, "20"}, {40, "40"}, {60, "60"}, {80, "80"}, {100, "100"}, {120, "120"}}, 0.6, 0.17)
local FUEL = dialSpec("fuel", 150, 120, 1, {{0, "E"}, {0.5, "½"}, {1, "F"}}, 0.58, 0.24)

-- The two bodies, in the mockup's units (the panel is W x H of them; a unit is
-- a px on a 1080p screen). plates: {x, y, w, h, edge} (edge: the 2 px tile edge,
-- else the darker border); tells: the lamps behind the glass {id, x, y, w, h}.
-- (the sedan's visor is a picture: make_dash.ps1 draws it from these same dials)
local SEDAN = {
    kind = "sedan", W = 812, H = 158,
    plates = {{8, 8, 92, 142, true}, {104, 8, 342, 142, false}, {450, 66, 56, 84, false}, {510, 8, 294, 142, true}},
    shroud = {454, 70, 48, 76},
    lights = {cx = 54, cy = 42, r = 19, pull = false, capDy = 12},
    doors = {14, 92, 32, 40}, trunk = {54, 92, 32, 40},
    -- (the wells 5 apart both sides: 2 and 8 looked like a mistake - the author, 2026-10-21)
    dials = {
        -- (the small dials 3 lower: at 62 the tachometer's brow touched the plate's top
        -- and its sand was cut; the three placed so the visor's sand runs 4 to the
        -- frame on both ends - it was 1 on the left and 7 on the right, the author 2026-10-21)
        {id = "tach", cx = 162, cy = 65, R = 44, wall = 5, spec = TACH, cap = true},
        {id = "speed", cx = 281, cy = 82, R = 60, wall = 5, spec = SPEED, unit = true, digits = true, gear = true},
        {id = "fuel", cx = 394, cy = 65, R = 38, wall = 5, spec = FUEL}},
    visor = {96, 2, 356, 92},
    -- (both glasses on one line: they were 118 and 114 high - the author, 2026-10-21)
    glass = {{126, 117, 70, 28}, {348, 117, 90, 28}},
    tells = {{"engine", 133, 120, 22, 22}, {"battery", 167, 120, 22, 22}, {"lights", 353, 120, 22, 22}, {"cruise", 378, 120, 22, 22}},
    cruiseNum = {404, 121, 28, 20},
    ign = {cx = 478, cy = 108, r = 23, inner = 16},
    -- (the radio and the heater 5 from the stack's every side and from each other)
    radio = {515, 13},
    climate = {515, 90, 284, 55, knob = true},
}
local TRUCK = {
    kind = "truck", W = 860, H = 152, rugged = true,
    plates = {{8, 8, 84, 136, true}, {98, 8, 400, 136, true}, {504, 8, 52, 136, false}, {560, 8, 292, 136, true}},
    lights = {cx = 50, cy = 44, r = 15, pull = true},
    -- (the plate 22 wider for the trunk's button by the doors' rocker, as on the sedan:
    -- under the ignition it was "not like a real dash" - the author, 2026-10-28)
    doors = {14, 80, 32, 44}, trunk = {54, 80, 32, 44},
    -- (the band inside the cluster's frame, the wells wholly under it: it lay over the
    -- grey frame and the dials' tops went under it - the author, 2026-10-21)
    dials = {
        {id = "tach", cx = 150, cy = 88, R = 42, wall = 5, spec = TACH, cap = true},
        {id = "speed", cx = 257, cy = 85, R = 50, wall = 5, spec = SPEED, unit = true, digits = true},
        {id = "fuel", cx = 356, cy = 70, R = 34, wall = 5, spec = FUEL}},
    band = {100, 10, 396, 16},
    bolts = {{105, 137}, {491, 137}},
    gears = {cx = 356, y = 114, cw = 12, h = 18},
    glass = {{414, 32, 76, 104}},
    tells = {{"engine", 422, 40, 24, 24}, {"battery", 458, 40, 24, 24}, {"lights", 422, 72, 24, 24}, {"cruise", 458, 72, 24, 24}},
    cruiseNum = {422, 104, 60, 22},
    ign = {cx = 530, cy = 76, r = 22, inner = 15},
    radio = {564, 12},
    climate = {564, 88, 284, 52, knob = false},
}
-- The same body without a trunk of its own (a pickup's open bed): the plate as narrow
-- as before, the rocker alone - an empty well where a button would be looked torn out
-- (the author, 2026-10-28).
local PICKUP = {
    kind = "truck", W = 838, H = 152, rugged = true,
    plates = {{8, 8, 62, 136, true}, {76, 8, 400, 136, true}, {482, 8, 52, 136, false}, {538, 8, 292, 136, true}},
    lights = {cx = 39, cy = 44, r = 15, pull = true},
    doors = {23, 80, 32, 44},
    -- (the band inside the cluster's frame, the wells wholly under it: it lay over the
    -- grey frame and the dials' tops went under it - the author, 2026-10-21)
    dials = {
        {id = "tach", cx = 128, cy = 88, R = 42, wall = 5, spec = TACH, cap = true},
        {id = "speed", cx = 235, cy = 85, R = 50, wall = 5, spec = SPEED, unit = true, digits = true},
        {id = "fuel", cx = 334, cy = 70, R = 34, wall = 5, spec = FUEL}},
    band = {78, 10, 396, 16},
    bolts = {{83, 137}, {469, 137}},
    gears = {cx = 334, y = 114, cw = 12, h = 18},
    glass = {{392, 32, 76, 104}},
    tells = {{"engine", 400, 40, 24, 24}, {"battery", 436, 40, 24, 24}, {"lights", 400, 72, 24, 24}, {"cruise", 436, 72, 24, 24}},
    cruiseNum = {400, 104, 60, 22},
    ign = {cx = 508, cy = 76, r = 22, inner = 15},
    radio = {542, 12},
    climate = {542, 88, 284, 52, knob = false},
}
local RADIO_W, RADIO_H = 284, 72

-- the lamps and LEDs in the bulb check's order
local CHECKED = {"engine", "battery", "lights", "cruise", "doors", "trunk", "heater", "window"}
-- what a click does something to (the rest only have tips)
local CLICKS = {lights = true, doors = true, trunk = true, ign = true, vol = true, tune = true, display = true,
    p1 = true, p2 = true, p3 = true, p4 = true, p5 = true, p6 = true, fm = true, tape = true, seekL = true, seekR = true,
    eject = true, slot = true, temp = true, heater = true}
local WHEELS = {vol = true, tune = true, temp = true, lights = true, display = true}
-- no tip over these (the author, 2026-10-21): the doors, the trunk, the headlights
-- (the knob and the lamp) and everything of the radio - what they do is seen
local NO_TIP = {doors = true, trunk = true, lights = true, tt_lights = true, vol = true, tune = true, display = true,
    p1 = true, p2 = true, p3 = true, p4 = true, p5 = true, p6 = true, fm = true, tape = true, slot = true,
    eject = true, seekL = true, seekR = true, heater = true}
local PRESET = {p1 = 1, p2 = 2, p3 = 3, p4 = 4, p5 = 5, p6 = 6}

--- The car's class by its script's name: pickups, vans, SUVs, off-roaders get the
--- pickup's body, the rest (and cars of mods with other names) the sedan's. The
--- pickup's body is wider with the trunk's button when the car has a trunk (a van,
--- an SUV - linlin, 2026-10-25), as narrow as it was without one (an open bed).
local TRUCKISH = {"pickup", "truck", "van", "suv", "offroad", "bus", "step"}
local function bodyFor(v)
    local ok, name = pcall(function() return v:getScript():getName() end)
    name = ok and name and string.lower(tostring(name)) or ""
    for _, w in ipairs(TRUCKISH) do
        if string.find(name, w, 1, true) then
            local ok, bed = pcall(function() return v:getPartById("TruckBed") end)
            return (ok and bed ~= nil) and TRUCK or PICKUP
        end
    end
    return SEDAN
end

-- Pictures ---------------------------------------------------------------------------

local texCache = {}
local function tex(name)
    local t = texCache[name]
    if t == nil then
        t = getTexture("media/ui/knoxdash/" .. name .. ".png") or false
        texCache[name] = t
    end
    return t or nil
end
-- The pictures' smaller copies (make_dash.ps1, as mipmaps are): the game scales a
-- picture down without them and its edges came out jagged when it was shown much
-- smaller than drawn (the author, 2026-10-21: "the mockup is smooth, the game
-- pixelates"). sized(name, px): the smallest copy at least px across (scaled down a
-- little, never up), or the picture itself. The names are made once a picture.
local SQ = {10, 13, 16, 20, 26, 34, 44, 58, 76, 100, 130, 170, 226}
-- (the pictures' own sizes: copies are made only smaller - no file is asked for
-- that isn't there)
local BASE = {disc = 256, knurl = 256, temp_arc = 256, hub = 32, reel = 64}
local sizedNames = {}
local function sized(name, px)
    local list = sizedNames[name]
    if not list then
        list = {base = BASE[name] or (string.sub(name, 1, 4) == "key_" and 200) or 40}
        for i, d in ipairs(SQ) do list[i] = name .. "_" .. d end
        sizedNames[name] = list
    end
    for i, d in ipairs(SQ) do
        if d >= px - 0.5 then return d < list.base and list[i] or name end
    end
    return name
end
-- the dials' layers and the visor at NN/100 px a unit; the display's figures by height
local KS = {80, 100, 133, 160, 200}
local SEGH = {22, 28, 36, 46}
local SEG_H, SEGG_H = {}, {}
for i, ph in ipairs(SEGH) do
    SEG_H[i], SEGG_H[i] = {}, {}
    for d = 0, 9 do SEG_H[i][d] = "seg_" .. d .. "_h" .. ph; SEGG_H[i][d] = "seg_" .. d .. "g_h" .. ph end
end
local WHITE_TEX = nil
local function white()
    if not WHITE_TEX then WHITE_TEX = Texture.getWhite() end
    return WHITE_TEX
end
-- (the names made once: no string is built while drawing)
local RING = {16, 22, 30, 40, 54, 72, 96, 128, 170, 226}
local RING_NAME, SEG_NAME, SEGG_NAME, NUMS = {}, {}, {}, {}
for i, d in ipairs(RING) do RING_NAME[i] = "ring_" .. d end
for i = 0, 9 do SEG_NAME[i] = "seg_" .. i; SEGG_NAME[i] = "seg_" .. i .. "g" end
local PRESET_TXT, PRESET_P, PRESET_ID = {}, {}, {}
for i = 1, 6 do PRESET_TXT[i] = tostring(i); PRESET_P[i] = "P" .. i; PRESET_ID[i] = "p" .. i end
local LAMP_PIC, TT_ID = {}, {}
for _, id in ipairs({"engine", "battery", "lights", "cruise"}) do LAMP_PIC[id] = "lamp_" .. id; TT_ID[id] = "tt_" .. id end
local function num(n)
    local s = NUMS[n]
    if not s then
        s = tostring(n)
        NUMS[n] = s
    end
    return s
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function mixTo(o, a, b, k)
    o.r, o.g, o.b = a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k
    return o
end
local function mixC(a, b, k) return mixTo({}, a, b, k) end

-- Drawing ----------------------------------------------------------------------------

--- A picture on a quad (four corners: its top left, top right, bottom right,
--- bottom left) - turned and on fractions of a pixel.
local function quad(ui, t, x1, y1, x2, y2, x3, y3, x4, y4, c, a)
    if not t or a <= 0.003 then return end
    local ax, ay = ui:getAbsoluteX(), ui:getAbsoluteY()
    ui.javaObject:DrawTexture(t, ax + x1, ay + y1, ax + x2, ay + y2, ax + x3, ay + y3, ax + x4, ay + y4, c.r, c.g, c.b, a)
end

--- A line x0,y0 -> x1,y1, th thick, soft along its edges.
local function bar(ui, x0, y0, x1, y1, th, c, a)
    local dx, dy = x1 - x0, y1 - y0
    local l = math.sqrt(dx * dx + dy * dy)
    if l < 0.01 then return end
    local h = (th + 1) / 2
    local nx, ny = -dy / l * h, dx / l * h
    quad(ui, tex("bar"), x0 + nx, y0 + ny, x1 + nx, y1 + ny, x1 - nx, y1 - ny, x0 - nx, y0 - ny, c, a)
end

--- A box of units x, y, w, h in whole pixels: each edge rounded on its own, so boxes
--- with the same room between them in units have it in pixels too (rounded as a
--- corner and a size, the gaps came out 6 px on one side and 8 on the other - the
--- author, 2026-10-21).
local function snap(s, x, y, w, h)
    local x0, y0 = math.floor(x * s + 0.5), math.floor(y * s + 0.5)
    return x0, y0, math.floor((x + w) * s + 0.5) - x0, math.floor((y + h) * s + 0.5) - y0
end

--- A well of its own size (the doors' rocker, the trunk's button): rounded from its
--- corner and its width, not from both edges - side by side the two came out 42 and
--- 43 px at 1440p (the critic, 2026-10-28).
local function snapWell(s, x, y, w, h)
    return math.floor(x * s + 0.5), math.floor(y * s + 0.5), math.floor(w * s + 0.5), math.floor(h * s + 0.5)
end

local function pt(cx, cy, r, deg)
    local a = math.rad(deg)
    return cx + r * math.cos(a), cy - r * math.sin(a)
end

local function pic(ui, name, x, y, w, h, c, a)
    local t = tex(name)
    if t and a > 0.003 then ui:drawTextureScaled(t, x, y, w, h, a, c.r, c.g, c.b) end
end

local function disc(ui, cx, cy, r, c, a) pic(ui, sized("disc", r * 2), cx - r, cy - r, r * 2, r * 2, c, a) end

--- A 2 px ring of radius r: the ring picture made for the nearest size.
local function ring(ui, cx, cy, r, c, a)
    local d = r * 2
    local best, bi = 1e9, 1
    for i = 1, #RING do
        local e = math.abs(RING[i] - d) / RING[i]
        if e < best then best, bi = e, i end
    end
    pic(ui, RING_NAME[bi], cx - r, cy - r, d, d, c, a)
end

--- A picture w x h, its middle at cx, cy, turned by deg (clockwise).
local function turned(ui, name, cx, cy, w, h, deg, c, a)
    local r = math.rad(deg)
    local cs, sn = math.cos(r), math.sin(r)
    local hw, hh = w / 2, h / 2
    local x1, y1 = cx - hw * cs + hh * sn, cy - hw * sn - hh * cs
    local x2, y2 = cx + hw * cs + hh * sn, cy + hw * sn - hh * cs
    local x3, y3 = cx + hw * cs - hh * sn, cy + hw * sn + hh * cs
    local x4, y4 = cx - hw * cs - hh * sn, cy - hw * sn + hh * cs
    quad(ui, name == "white" and white() or tex(name), x1, y1, x2, y2, x3, y3, x4, y4, c, a)
end

--- The shade picture fading downwards over x, y, w, h (flipped: upwards), black or `c`.
local function shade(ui, x, y, w, h, a, up, c)
    if up then
        quad(ui, tex("grad"), x, y + h, x + w, y + h, x + w, y, x, y, c or BLACK, a)
    else
        pic(ui, "grad", x, y, w, h, c or BLACK, a)
    end
end

--- A surface as the mockup's (2026-10-21: the author missed its gradients in the
--- game): the header's colour, lit toward its top by `k` of the tile edge (toward
--- its bottom: `up`). `tmp`: a colour table to fill.
local function sheen(ui, x, y, w, h, k, a, tmp, up)
    local C = T.color
    T.rect(ui, x, y, w, h, C.header, a)
    shade(ui, x, y, w, h, a, up, mixTo(tmp, C.header, C.tileEdge, k))
end

--- A needle from its hub at cx, cy pointing at deg, with its glow.
local function needle(ui, cx, cy, deg, len, tail, w, c, a, glow)
    local r = math.rad(deg)
    local dx, dy = math.cos(r), -math.sin(r)
    local nx, ny = -dy, dx
    local tx, ty = cx + dx * len, cy + dy * len
    local bx, by = cx - dx * tail, cy - dy * tail
    if glow > 0 then
        local g = w * 5
        quad(ui, tex("glow"), tx + nx * g, ty + ny * g, tx - nx * g, ty - ny * g, bx - nx * g, by - ny * g, bx + nx * g, by + ny * g, c, a * glow)
    end
    local q = w * 2
    quad(ui, tex("needle"), tx + nx * q, ty + ny * q, tx - nx * q, ty - ny * q, bx - nx * q, by - ny * q, bx + nx * q, by + ny * q, c, a)
end

--- A small triangle pointing `dir` (1 right, -1 left) with its tip at x, y.
local function tri(ui, x, y, w, h, dir, c, a)
    quad(ui, white(), x, y, x, y, x - dir * w, y + h / 2, x - dir * w, y - h / 2, c, a)
end

--- Words: Knox's font, or the game's biggest one not taller than the place (a
--- language Knox's atlases can't write).
local function knoxFont(style, px, fallback)
    if T.javaFonts then return T.makeFont(style, px) end
    return (T.gameFontUpTo and T.gameFontUpTo(px)) or fallback
end

--- Can Knox's atlases draw Latin and digits here, whatever the language?
local function digitsReady()
    return T.javaFonts or (T.active == true and knoxFontReady ~= nil and knoxFontReady("title", 16) == true)
end

--- Numbers, gears and the presets' digits: Knox's own font even where the
--- language's letters are not in its atlases (Chinese: the game's font stood
--- twice as big over the dials - the author, 2026-10-22).
local function digitFont(style, px, fallback)
    if digitsReady() then return T.makeFont(style, px) end
    return knoxFont(style, px, fallback)
end

-- The car ------------------------------------------------------------------------

--- The game's check of the engine's parts (ISVehicleDashboard:checkEngineFull).
local function engineOk(v)
    for i = 0, v:getPartCount() - 1 do
        local part = v:getPartByIndex(i)
        local fn = part and part:getLuaFunction("checkEngine")
        if fn and not VehicleUtils.callLua(fn, v, part) then return false end
    end
    return true
end

local function keyName(k)
    local ok, s = pcall(function() return Keyboard.getKeyName(k) end)
    return ok and s or "?"
end

local function tempIndex(t)
    local best, bi = 1e9, 4
    for i, v in ipairs(TEMPS) do
        if math.abs(v - (t or 0)) < best then best, bi = math.abs(v - (t or 0)), i end
    end
    return bi
end

-- The panel ------------------------------------------------------------------------

function D:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.k = 0
    o.body = SEDAN
    -- (filled in while drawing, never made anew: a band for T.label, its options,
    -- the colours worked out each frame, the card's place)
    o.lr, o.lo = {0, 0, 0, 0}, {align = "centre"}
    o.cc = {paint = {}, scale = {}, legend = {}, amber = {}, a = {}, b = {}, c = {}}
    o.cardRect = {0, 0, 0, 0}
    o.sparks = {}
    for i = 1, 24 do o.sparks[i] = {life = 0} end
    -- the radio it drives: the car's (KnoxCarRadio and the player's music); a demo
    -- panel's is its pretend set (D.makeDemo)
    o.MM, o.R = MM, R
    o:reset()
    return o
end

--- Everything as at rest (the needles down, the lamps dark, the knobs where they are).
function D:reset()
    self.needles = {tach = {x = 0, v = 0}, speed = {x = 0, v = 0}, fuel = {x = 0, v = 0}}
    self.lampC = {}
    for _, id in ipairs(CHECKED) do self.lampC[id] = {r = T.color.dim.r, g = T.color.dim.g, b = T.color.dim.b, l = 0} end
    self.lampT = {r = 0, g = 0, b = 0}
    self.lit, self.glow, self.dark = 0, 0, 0
    self.keyVis, self.keyAng, self.keyVel = 0, KEY_OFF, 0
    self.wires = 0
    for _, p in ipairs(self.sparks) do p.life = 0 end
    self.lastMs = getTimestampMs()
    self.engineAt, self.engineOk = 0, true
    self.dayAt = 0
    self.wasPower, self.wasKey = nil, nil
    self.tipK, self.tipId, self.tipSince, self.tipAt = 0, nil, 0, 0
    self.press = {}
    self.lightsK, self.doorK, self.heatK = 0, 0, 0
    self.volKnob, self.tuneKnob, self.tempKnob = {x = 0, v = 0}, {x = 0, v = 0}, {x = 0, v = 0}
    self.tuneT = 0
    self.disp, self.tapeK, self.tapeVis, self.reel = 0, 0, 0, 0
    self.volAt, self.seekAt, self.noTapeAt = -1e9, -1e9, -1e9
    self.tapeOut, self.cardOpen = false, false
    self.hot, self.down = nil, nil
end

--- Sizes from the screen's: a px a unit at 1080p (Knox's cell, 48 px there), 1.33 at
--- 1440p. (It was 0.9: at 2560 x 1440 small in places - the author, 2026-10-21.)
local SCALE = 1.0
function D:layout()
    T.ensure()
    local s = math.max(0.6, T.cell / 48 * SCALE)
    local body = self.body
    -- (a demo no wider than the news' column it stands in: smaller as a whole)
    if self.maxW then s = math.min(s, self.maxW / body.W) end
    local digits = digitsReady()
    if s ~= self.s or self.fontsJava ~= T.javaFonts or self.fontsDigits ~= digits or body ~= self.laidBody then
        self.s, self.fontsJava, self.fontsDigits, self.laidBody = s, T.javaFonts, digits, body
        if not self.txt then self:texts() end
        self.fCap = knoxFont("head", math.max(10, 8.5 * s), UIFont.Small)
        -- (the dials' "x1000" and "km/h": Knox's font when its atlas has their letters)
        local scaleLatin = T.javaFonts or (digits and knoxFontCovers ~= nil and knoxFontCovers(self.txt.rpm .. self.txt.kmh) == true)
        self.fScale = (scaleLatin and digitFont or knoxFont)("head", math.max(10, 9.5 * s), UIFont.Small)
        self.fSpeed = digitFont("title", math.max(14, 19 * s), UIFont.Medium)
        self.fGear = digitFont("title", math.max(11, 13 * s), UIFont.Small)
        self.fCruise = digitFont("title", math.max(10, 12 * s), UIFont.Small)
        self.fSmall = knoxFont("head", math.max(10, 7.4 * s), UIFont.Small)
        self.fBtn = digitFont("title", math.max(10, 8.5 * s), UIFont.Small)
        self.fGears = digitFont("title", math.max(10, 10.5 * s), UIFont.Small)
        self.fTip = T.fontText
        self.fTipSmall = T.fontTile
        -- the dials' layers and the visor in the copy nearest this size (at least as
        -- big: scaled down a little, never up)
        local k = 200
        for _, kk in ipairs(KS) do
            if kk >= s * 100 * 0.97 then k = kk break end
        end
        local sfx = "_k" .. k
        self.kp = {}
        for _, sp in ipairs({TACH, SPEED, FUEL}) do
            self.kp[sp] = {ticks = sp.ticks .. sfx, red = sp.red .. sfx, glow = sp.glow .. sfx}
        end
        self.hood = {shadow = "hood_sedan_shadow" .. sfx, fill = "hood_sedan_fill" .. sfx, dark = "hood_sedan_dark" .. sfx,
            lip = "hood_sedan_lip" .. sfx}
        -- each dial's numbers, as big as its face says
        self.dialFont = {}
        for _, d in ipairs(body.dials) do
            self.dialFont[d] = digitFont("title", math.max(10, d.R * d.spec.numK * s), UIFont.Small)
        end
        self:buildHits()
    end
    self.W, self.H = math.floor(body.W * s + 0.5), math.floor(body.H * s + 0.5)
    if not self.txt then self:texts() end
end

--- The words, read once (getText makes no new string each frame then).
function D:texts()
    local function tx(k) return getText("IGUI_Knox_Dash_" .. k) end
    self.txt = {
        lights = tx("Cap_Lights"),
        rpm = tx("Rpm1000"), kmh = tx("Kmh"), temp = tx("Cap_Temp"), heater = tx("Cap_Heater"), window = tx("Cap_Window"),
        cold = tx("Cap_Cold"), warm = tx("Cap_Warm"), off = tx("Cap_Off"), on = tx("Cap_On"), noRadio = tx("NoRadio"),
        vol = tx("Radio_Vol"), tune = tx("Radio_Tune"), fm = tx("Radio_FM"), tape = tx("Radio_Tape"),
        seek = tx("Radio_Seek"), noTape = tx("Radio_NoTape"),
    }
end

function D:u(v) return v * self.s end

--- Where the mouse finds things: {id, x, y, w, h, round} in the panel's pixels.
function D:buildHits()
    local b, s = self.body, self.s
    local function U(v) return v * s end
    local hits = {}
    local function add(id, x, y, w, h, round) table.insert(hits, {id = id, x = U(x), y = U(y), w = U(w), h = U(h), round = round}) end
    local l = b.lights
    add("lights", l.cx - l.r - 4, l.cy - l.r - 4, l.r * 2 + 8, l.r * 2 + 8, true)
    add("doors", b.doors[1], b.doors[2], b.doors[3], b.doors[4])
    if b.trunk then add("trunk", b.trunk[1], b.trunk[2], b.trunk[3], b.trunk[4]) end
    for _, d in ipairs(b.dials) do add(d.id == "fuel" and "fuelDial" or d.id, d.cx - d.R, d.cy - d.R, d.R * 2, d.R * 2, true) end
    for _, t in ipairs(b.tells) do add("tt_" .. t[1], t[2], t[3], t[4], t[5]) end
    add("tt_cruise", b.cruiseNum[1], b.cruiseNum[2], b.cruiseNum[3], b.cruiseNum[4])
    local g = b.ign
    add("ign", g.cx - g.r, g.cy - g.r, g.r * 2, g.r * 2, true)
    -- the radio (its own units from its corner)
    local rx, ry = b.radio[1], b.radio[2]
    add("vol", rx + 8, ry + 16, 28, 28, true)
    add("tune", rx + 253, ry + 17, 26, 26, true)
    add("display", rx + 42, ry + 8, 124, 32)
    for i = 1, 6 do add("p" .. i, rx + 42 + (i - 1) * 21, ry + 44, 19, 13) end
    add("slot", rx + 172, ry + 8, 76, 20)
    add("fm", rx + 172, ry + 32, 37, 12)
    add("tape", rx + 211, ry + 32, 37, 12)
    add("seekL", rx + 172, ry + 48, 18.5, 12)
    add("seekR", rx + 190.5, ry + 48, 18.5, 12)
    add("eject", rx + 211, ry + 48, 37, 12)
    -- the heater
    local c = b.climate
    if c.knob then
        add("temp", c[1] + 36 - 20, c[2] + c[4] / 2 + 6 - 20, 40, 40, true)
        add("heater", c[1] + 76, c[2] + 10, 78, c[4] - 20)
        add("window", c[1] + 162, c[2] + 10, 42, c[4] - 20)
    else
        add("temp", c[1] + 10, c[2] + 15, 164, 20)
        add("heater", c[1] + 184, c[2] + 15, 78, 20)
        add("window", c[1] + 266, c[2] + 18, 12, 10)
    end
    self.hits = hits
end

function D:hitAt(mx, my)
    for _, h in ipairs(self.hits) do
        if h.round then
            local rx, ry = h.w / 2, h.h / 2
            local dx, dy = mx - (h.x + rx), my - (h.y + ry)
            if dx * dx + dy * dy < rx * rx then return h end
        elseif mx >= h.x and my >= h.y and mx < h.x + h.w and my < h.y + h.h then
            return h
        end
    end
    return nil
end

-- Reading the car ----------------------------------------------------------------

function D:read(now)
    local MM, R = self.MM, self.R
    if self.demo then self.demo:tick(now) end
    local v = self.vehicle
    local st = self.st or {}
    self.st = st
    st.keyIn = v:isKeysInIgnition()
    st.hot = v:isHotwired()
    st.running = v:isEngineRunning()
    st.starting = v:isStarting()
    st.started = v:isEngineStarted()
    st.power = st.keyIn or st.running
    if now >= self.engineAt then
        self.engineAt = now + 400
        local ok, res = pcall(engineOk, v)
        self.engineOk = (not ok) or res
    end
    local gas = v:getPartById("GasTank")
    st.gas = (gas and gas:isContainer() and gas:getContainerContentType()) and gas or nil
    st.fuel = 0
    if st.gas and (st.running or st.keyIn) then
        st.fuel = clamp(st.gas:getContainerContentAmount() / math.max(0.001, st.gas:getContainerCapacity()), 0, 1)
    end
    st.fuelPct = v:getRemainingFuelPercentage()
    st.kmh = math.abs(v:getCurrentSpeedKmHour()) * BaseVehicle.getFakeSpeedModifier()
    st.rpm = v:getEngineSpeed()
    st.gear = st.running and v:getTransmissionNumberLetter() or "N"
    st.charge = v:getBatteryCharge()
    st.regulator = v:isRegulator()
    st.regSpeed = v:getRegulatorSpeed()
    local engine = v:getPartById("Engine")
    st.engineCond = engine and engine:getCondition() or 0
    st.side = nil
    if st.gas and st.gas:getArea() then
        if v:leftSideFuel() then st.side = "left" elseif v:rightSideFuel() then st.side = "right" end
    end
    st.lights = v:getHeadlightsOn()
    st.lightsLit = st.lights and v:getHeadlightCanEmmitLight()
    st.doorsAll = v:areAllDoorsLocked()
    st.doorsSome = v:isAnyDoorLocked()
    st.trunkHas = v:getPartById("TruckBed") ~= nil
    st.trunkLocked = st.trunkHas and v:isTrunkLocked()
    local heater = v:getPartById("Heater")
    st.heater = heater
    local md = heater and heater:getModData()
    st.heatOn = md ~= nil and md.active == true
    st.heatTemp = md and md.temperature or 0
    st.window = st.heatOn and v:windowsOpen() > 0
    -- the dark (the scales' backlight goes with it), now and then
    if self.demo then
        self.dark = self.demo.dark
    elseif now >= self.dayAt then
        self.dayAt = now + 1000
        local ok, day = pcall(function() return getClimateManager():getDayLightStrength() end)
        self.dark = ok and day and (1 - clamp(day, 0, 1)) or 0
    end
    -- the radio (KnoxCarRadio and the player's music)
    st.rHas = MM.carHas()
    st.rOn = st.rHas and MM.carOn()
    st.rLive = st.rHas and MM.carAllowed()
    local raw = self.demo and MM.theme() or T.settings["car.music"]
    if raw ~= self.themeRaw or not self.theme then
        self.themeRaw = raw
        self.theme = MM.theme()
    end
    st.tape = self.theme == "mine"
    st.freq = MM.carChannel() or 0
    st.vol = MM.vol()
    st.mix = MM.shuffleOn()
    st.rpt = MM.repeatMode()
    st.playing = R.musicPlaying()
    st.at = MM.at or 0
    st.preset = (MM.stations() and st.at >= 1 and st.at <= 6) and st.at or 0
    return st
end

--- A lamp's or LED's colour now (into `out`) and how lit (0..1), whether it pulses.
function D:lampState(id, st, out)
    local C = T.color
    local function set(c) out.r, out.g, out.b = c.r, c.g, c.b end
    if id == "engine" then
        if not self.engineOk and st.keyIn and not st.running and not st.started then set(C.bad) return 1, true end
        if st.running then mixTo(out, C.bad, C.good, clamp(st.engineCond / 100, 0, 1)) return 1 end
        if st.started then set(CRANK) return 1 end
        return 0
    elseif id == "battery" then
        if st.running or st.keyIn then
            if st.charge > 0 then mixTo(out, C.bad, C.good, clamp(st.charge, 0, 1)) return 1 end
            set(C.bad) return 1, true
        end
        return 0
    elseif id == "lights" then
        if st.lights then
            if not st.lightsLit then set(C.bad) return 1, true end
            set(C.good) return 1
        end
        return 0
    elseif id == "cruise" then
        if st.regulator then set(C.good) return 1 end
        return 0
    elseif id == "doors" then
        if st.doorsAll then set(C.good) return 1 end
        if st.doorsSome then set(C.warn) return 1 end
        return 0
    elseif id == "trunk" then
        if st.trunkLocked then set(C.good) return 1 end
        return 0
    elseif id == "heater" then
        if st.heatOn then set(C.good) return 1 end
        return 0
    elseif id == "window" then
        if st.window and st.power then set(C.warn) return 1 end
        return 0
    end
    return 0
end

-- Motion ------------------------------------------------------------------------------

--- On a spring toward its target (a little overshoot, then still).
local function spring(n, target, dt, k, damp)
    if not T.animOn() then n.x, n.v = target, 0 return end
    local steps = dt > 0.02 and 3 or 1
    local h = dt / steps
    for _ = 1, steps do
        local acc = k * (target - n.x) - damp * n.v
        n.v = n.v + acc * h
        n.x = n.x + n.v * h
    end
end

--- A value easing toward target at `rate` per second (exponential).
local function ease(cur, target, rate, dt)
    if not T.animOn() then return target end
    local k = 1 - math.exp(-rate * dt)
    return cur + (target - cur) * k
end

function D:move(st, now, dt)
    -- the dials' light with the ignition; the backlight with the headlights, more in the dark
    self.lit = ease(self.lit, st.power and 1 or 0, 7, dt)
    self.glow = ease(self.glow, st.lightsLit and (0.3 + 0.7 * self.dark) or 0, 4, dt)
    -- the ignition came on: the bulb check, the needles' sweep
    if st.power and self.wasPower == false then
        self.checkAt = now
        self.sweepAt = now
    end
    self.wasPower = st.power
    local sweeping = self.sweepAt and now - self.sweepAt < SWEEP_MS
    -- the tachometer: cranking it shivers low
    local tachT = 0
    if sweeping then tachT = 1
    elseif st.running then tachT = clamp(st.rpm / (TACH_MAX * 1000), 0, 1.03)
    elseif st.starting then
        if now >= (self.crankAt or 0) then
            self.crankAt = now + 70
            self.crankT = 0.08 + ZombRandFloat(0, 0.09)
        end
        tachT = self.crankT or 0.1
    end
    spring(self.needles.tach, tachT, dt, 140, 13)
    spring(self.needles.speed, sweeping and 1 or (st.power and clamp(st.kmh / SPEED_MAX, 0, 1.04) or 0), dt, 110, 14)
    -- the fuel: slower, as a float in a tank
    spring(self.needles.fuel, sweeping and 1 or st.fuel, dt, 26, 9.5)
    -- the key: in (out) and its turn
    local keyShown = st.keyIn and not st.hot
    if keyShown then
        self.keyVis = ease(self.keyVis, 1, 16, dt)
    elseif math.abs(self.keyAng - KEY_OFF) < 8 or not T.animOn() then
        self.keyVis = ease(self.keyVis, 0, 14, dt)
    end
    local angT = KEY_OFF
    if keyShown and self.keyVis > 0.85 then
        angT = (st.starting and not st.running) and KEY_START or KEY_ON
    end
    local kn = self.keyN or {x = self.keyAng, v = self.keyVel}
    self.keyN = kn
    kn.x, kn.v = self.keyAng, self.keyVel
    spring(kn, angT, dt, 260, 17)
    self.keyAng, self.keyVel = kn.x, kn.v
    -- hot-wired: the ends touch while it cranks, twisted together while it runs
    self.wires = ease(self.wires, (st.hot and (st.starting or st.running)) and 1 or 0, 10, dt)
    if st.hot and st.starting and not st.running and now >= (self.sparkAt or 0) and T.animOn() then
        self.sparkAt = now + 60 + ZombRand(70)
        self:spawnSparks(now)
    end
    -- the switches turn, tilt, travel
    self.lightsK = ease(self.lightsK, st.lights and 1 or 0, 16, dt)
    self.doorK = ease(self.doorK, (st.doorsAll or st.doorsSome) and 1 or 0, 18, dt)
    self.heatK = ease(self.heatK, st.heatOn and 1 or 0, 14, dt)
    spring(self.volKnob, -135 + 270 * clamp(st.vol, 0, 1), dt, 220, 18)
    spring(self.tuneKnob, self.tuneT, dt, 220, 18)
    spring(self.tempKnob, TEMP_DEG[tempIndex(st.heatTemp)], dt, 200, 16)
    -- the radio: its display, the tape in (or out) and its reels
    self.disp = ease(self.disp, st.rLive and 1 or 0, 10, dt)
    self.tapeK = ease(self.tapeK, st.tape and 1 or 0, 9, dt)
    self.tapeVis = ease(self.tapeVis, (st.tape or self.tapeOut) and 1 or 0, 12, dt)
    if st.playing and st.tape and T.animOn() then self.reel = (self.reel + dt * 200) % 360 end
    -- the lamps and LEDs fade to their colours; the bulb check lights them in turn
    local C = T.color
    local k = T.animOn() and (1 - math.exp(-dt * 14)) or 1
    for i, id in ipairs(CHECKED) do
        local out = self.lampT
        local level, pulse = self:lampState(id, st, out)
        local cur = self.lampC[id]
        if level <= 0 then out.r, out.g, out.b = cur.r, cur.g, cur.b end
        if self.checkAt and now - self.checkAt < CHECK_MS and now - self.checkAt - (i - 1) * CHECK_STEP >= 0 then
            out.r, out.g, out.b = C.accent.r, C.accent.g, C.accent.b
            level, pulse = 1, false
        end
        if pulse and T.animOn() then level = level * (0.55 + 0.45 * (0.5 + 0.5 * math.cos(now / 1000 * math.pi * 2 * 1.25))) end
        cur.r = cur.r + (out.r - cur.r) * k
        cur.g = cur.g + (out.g - cur.g) * k
        cur.b = cur.b + (out.b - cur.b) * k
        cur.l = cur.l + (level - cur.l) * k
    end
    -- the key's sounds, as the game's dashboard plays them
    local keyIn = (st.keyIn and not st.hot) or ((st.running or st.starting) and not st.hot)
    if self.wasKey ~= nil and keyIn ~= self.wasKey and self.character then
        self.character:playSound(keyIn and "VehicleInsertIgnitionKey" or "VehicleRemoveIgnitionKey")
    end
    self.wasKey = keyIn
end

--- A few sparks where the wires' ends meet (from a pool: none made while driving).
function D:spawnSparks(now)
    local b, s = self.body, self.s
    local x, y = self:u(b.ign.cx), self:u(b.ign.cy + 18)
    local n = 3 + ZombRand(4)
    for _, p in ipairs(self.sparks) do
        if n <= 0 then break end
        if now - (p.born or 0) >= p.life then
            local a = math.rad(ZombRandFloat(20, 160))
            local sp = ZombRandFloat(30, 95) * s
            p.x, p.y = x, y
            p.vx, p.vy = math.cos(a) * sp * (ZombRand(2) == 0 and -1 or 1), -math.sin(a) * sp
            p.born, p.life, p.size = now, 180 + ZombRand(260), ZombRandFloat(2.5, 5) * s
            n = n - 1
        end
    end
end

-- Showing --------------------------------------------------------------------------

function D:place(slide, ox, oy)
    local n = self.playerNum or 0
    local sl, st = getPlayerScreenLeft(n), getPlayerScreenTop(n)
    local sw, sh = getPlayerScreenWidth(n), getPlayerScreenHeight(n)
    self:setWidth(self.W)
    self:setHeight(self.H)
    self:setX(sl + math.floor((sw - self.W) / 2) + ox)
    self:setY(st + sh - self.H + math.floor(slide + 0.5) + oy)
end

function D:prerender()
    local now = getTimestampMs()
    local dt = clamp((now - (self.lastMs or now)) / 1000, 0, 0.1)
    self.lastMs = now
    if self.demo then
        self:demoFrame(now, dt)
        return
    end
    -- coming up, going down
    if self.shownAt then
        local t = clamp(T.anim((now - self.shownAt) / IN_MS), 0, 1)
        self.k = 1 - (1 - t) ^ 3
    elseif self.goneAt then
        local t = clamp(T.anim((now - self.goneAt) / OUT_MS), 0, 1)
        self.k = (self.goneK or 1) * (1 - t * t)
        if t >= 1 then
            self.goneAt = nil
            self:removeFromUIManager()
            self.inUI = false
            return
        end
    end
    local v = self.vehicle
    if not v or not ISUIHandler.allUIVisible then return end
    self:layout()
    -- a knock to the car (the game's damage check sets its dashboard's flicker):
    -- the lights flicker, the whole panel shakes
    local vd = self.vdash
    if vd and (vd.flickingTimer or 0) > 0 then
        vd.flickingTimer = 0
        self.flickAt = now
    end
    local fl, shake = self:flicker(now)
    self.fl = fl
    local ox, oy = 0, 0
    if shake > 0 then ox, oy = math.floor(ZombRandFloat(-shake, shake) + 0.5), math.floor(ZombRandFloat(-shake, shake) + 0.5) end
    self:place((1 - self.k) * self.H * 0.7, ox, oy)
    -- (the car's radio playing in this car: the menu's player may have been
    -- stopped by the game's start after the driver was seated)
    if self.shownAt and R.ensure then R.ensure(self.character, v) end
    -- (a car gone from under the panel, a part another mod took away: the
    -- reason once in console.txt, the panel off rather than an error each frame)
    local ok, err = pcall(function()
        local st = self:read(now)
        self:move(st, now, dt)
        self:draw(st, now, dt)
    end)
    if not ok then
        print("[Knox] the dashboard stopped: " .. tostring(err))
        D.hideFor(nil)
    end
end

--- How lit the lights are this frame: flickering after a knock; how far it shakes.
function D:flicker(now)
    if not self.flickAt or now - self.flickAt > FLICK_MS then return 1, 0 end
    local p = (now - self.flickAt) / FLICK_MS
    if now >= (self.flickNext or 0) then
        self.flickNext = now + 40 + ZombRand(60)
        self.flickV = ZombRandFloat(0.15, 1)
    end
    local f = 1 - (1 - (self.flickV or 1)) * (1 - p)
    return f, (1 - p) * 2.5 * self.s
end

-- Text through the layout kit (a band and its options filled in, not made) --------------

function D:label(s, x, y, w, h, c, font, a, align)
    local r, o = self.lr, self.lo
    r[1], r[2], r[3], r[4] = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
    o.font, o.a, o.align = font, a, align or "centre"
    return T.label(self, s, r, c, o)
end

--- Text with its middle at cx, cy.
function D:labelAt(s, cx, cy, c, font, a)
    local h = T.fontH(font)
    return self:label(s, cx - 200, cy - h / 2, 400, h, c, font, a, "centre")
end

-- Drawing the panel --------------------------------------------------------------------

function D:draw(st, now, dt)
    local s, a = self.s, self.k
    local C = T.color
    local b = self.body
    local W, H = self.W, self.H
    local fl = self.fl or 1
    local cc = self.cc
    -- the paint and the light: the marks and captions painted grey, lit with the
    -- ignition; at night without the backlight hardly seen; with the headlights
    -- lit from behind in sand
    local lit = self.lit * fl
    local glow = self.glow * fl
    local nightDim = 1 - 0.55 * self.dark * (1 - self.glow)
    mixTo(cc.paint, C.tileEdge, C.dim, (0.35 + 0.65 * lit) * nightDim)
    mixTo(cc.scale, cc.paint, GLOWC, glow)
    mixTo(cc.a, C.tileEdge, C.dim, 0.75 * nightDim)
    mixTo(cc.legend, cc.a, GLOWC, glow)
    mixTo(cc.amber, C.tileEdge, NEEDLE, 0.45 + 0.55 * lit)
    self.litF, self.glowF = lit, glow
    -- what the mouse is on
    local over = self:isMouseOver() and self:inClip(self:getMouseX(), self:getMouseY())
    local h = over and self:hitAt(self:getMouseX(), self:getMouseY()) or nil
    self.hot = h and h.id or nil
    self.hotHit = h
    local U = function(v) return v * s end
    -- the case and its sand frame
    T.rect(self, 0, 0, W, H, C.window, 0.97 * a)
    T.tileFrame(self, 0, 0, W, H, C.accent, a)
    for _, p in ipairs(b.plates) do
        local x, y, w, hh = snap(s, p[1], p[2], p[3], p[4])
        T.rect(self, x, y, w, hh, C.header, a)
        T.tileFrame(self, x, y, w, hh, p[5] and C.tileEdge or C.border, a)
    end
    self:drawSwitches(st, now, a)
    self:drawCluster(st, now, a)
    self:drawColumn(st, now, dt, a)
    self:drawRadio(st, now, a)
    if b.climate.knob then self:drawClimateKnobs(st, now, a) else self:drawClimateLevers(st, now, a) end

    -- (a demo has no card: the player's card is the camp's radio there)
    if self.demo then
        self:drawTip(st, now, dt, a)
        return
    end
    -- the player's card over the radio: opened and closed by a click on its display,
    -- closed too by a click anywhere off the dashboard and off the card (the author,
    -- 2026-10-21); a press is caught as it starts, whoever takes it (the world, a window)
    D.drawnAt = now
    local pressed = isMouseButtonDown(0) or isMouseButtonDown(1)
    if pressed and not self.wasPressed and self.cardOpen and not self:isMouseOver() then
        local card = KnoxRadioCard and KnoxRadioCard.instance
        if not (card and card:getIsVisible() and card:isMouseOver()) then self.cardOpen = false end
    end
    self.wasPressed = pressed
    -- (Viewpoint: its cursor mode turned off in the car - the card folds away with it;
    -- the author, 2026-10-29)
    if self.cardOpen and knoxViewpointCursorOn then
        local cur = knoxViewpointCursorOn()
        if self.cursorWas and not cur then self.cardOpen = false end
        self.cursorWas = cur
    else
        self.cursorWas = nil
    end
    if KnoxRadioCard then
        local r = self.cardRect
        r[1], r[2] = self:getAbsoluteX() + U(b.radio[1]), self:getAbsoluteY()
        r[3], r[4] = U(RADIO_W), U(b.radio[2] + RADIO_H)
        KnoxRadioCard.track(r, self.cardOpen and self.shownAt ~= nil and st.rHas,
            getPlayerScreenLeft(self.playerNum or 0) + getPlayerScreenWidth(self.playerNum or 0))
    end
    self:drawTip(st, now, dt, a)
end

-- -- the switches by the door ------------------------------------------------------------

--- A knob: its shadow, the ridged grip (turned with it), its 2 px ring, the cap
--- with its light, the pointer at ang (degrees clockwise from up) in `mark`.
function D:knob(cx, cy, r, ang, hover, a, mark)
    local C = T.color
    pic(self, "soft", cx - r * 1.2, cy - r * 1.05, r * 2.4, r * 2.4, BLACK, 0.55 * a)
    disc(self, cx, cy, r, C.cell, a)
    turned(self, sized("knurl", r * 2), cx, cy, r * 2, r * 2, ang, C.border, a)
    ring(self, cx, cy, r, hover and C.accent or C.tileEdge, a)
    -- the cap: dark, lit from the upper left (the mockup's round gradient)
    disc(self, cx, cy, r * 0.74, C.cell, a)
    pic(self, "cap_light", cx - r * 0.74, cy - r * 0.74, r * 1.48, r * 1.48, mixTo(self.cc.b, C.header, C.tileEdge, 0.65), a)
    local x0, y0 = pt(cx, cy, r * 0.2, 90 - ang)
    local x1, y1 = pt(cx, cy, r * 0.64, 90 - ang)
    bar(self, x0, y0, x1, y1, math.max(1.5, r * 0.13), mark, a)
end

--- A LED: dark glass, lit in the lamp's colour with a glow round it.
function D:led(x, y, w, h, cur, a)
    T.rect(self, x, y, w, h, T.color.screen, a)
    local lv = cur.l * (self.fl or 1)
    if lv > 0.01 then
        pic(self, "soft", x - w * 0.5, y - h * 3, w * 2, h * 7, cur, 0.35 * lv * a)
        T.rect(self, x, y, w, h, cur, lv * a)
    end
end

--- A push button: in by a pixel for a moment when pressed; its LED (or none).
function D:button(id, x, y, w, h, hover, a, ledC)
    local C = T.color
    local p = (self.press[id] and getTimestampMs() - self.press[id] < 140) and 1 or 0
    T.rect(self, x, y, w, h, C.cell, a)
    sheen(self, x + 2, y + 2 + p, w - 4, h - 4 - p, 0.5 - 0.35 * p, a, self.cc.b)
    T.tileFrame(self, x, y, w, h, hover and C.accent or C.tileEdge, a)
    -- (the LED centred by its own whole width: half of it taken off the middle put
    -- it 1 px left at 1440p - the critic, 2026-10-28)
    if ledC then
        local lw = math.floor(self:u(10))
        self:led(x + math.floor((w - lw) / 2), y + math.floor(self:u(4)), lw, math.max(2, math.floor(self:u(2.6))), ledC, a)
    end
    return p
end

--- A small radio key: a 1 px edge at rest, 2 px sand under the mouse.
function D:key(id, x, y, w, h, a)
    local C = T.color
    local p = (self.press[id] and getTimestampMs() - self.press[id] < 140) and 1 or 0
    local hover = self.hot == id
    T.rect(self, x, y, w, h, C.cell, a)
    sheen(self, x + 1, y + 1 + p, w - 2, h - 2 - p, 0.45 - 0.35 * p, a, self.cc.b)
    if hover then T.tileFrame(self, x, y, w, h, C.accent, a) else T.border(self, x, y, w, h, C.border, a) end
    return p
end

function D:drawSwitches(st, now, a)
    local C = T.color
    local b, s = self.body, self.s
    local cc = self.cc
    local function U(v) return v * s end
    local l = b.lights
    local cx, cy, r = U(l.cx), U(l.cy), U(l.r)
    local hot = self.hot == "lights"
    local lampC = st.lights and mixTo(cc.c, C.good, cc.legend, 0.2) or cc.legend
    if not l.pull then
        -- a rotary switch: its two places, 0 and the headlamp
        local x0, y0 = pt(cx, cy, r + U(9), 90 + 38)
        local x1, y1 = pt(cx, cy, r + U(9), 90 - 38)
        self:labelAt("0", x0, y0, cc.legend, self.fBtn, a)
        local is = U(14)
        pic(self, sized("lamp_lights", is), x1 - is / 2, y1 - is / 2, is, is, lampC, a)
        self:knob(cx, cy, r, -38 + 76 * self.lightsK, hot, a, st.lights and C.good or C.accent)
    else
        -- a pull knob: pulled out it stands bigger and throws a longer shadow
        local out = self.lightsK
        local rr = r * (1 + 0.14 * out)
        pic(self, "soft", cx - rr * 1.3, cy - rr * 1.1 + U(2 + 4 * out), rr * 2.6, rr * 2.6, BLACK, (0.5 + 0.2 * out) * a)
        disc(self, cx, cy, rr, C.cell, a)
        disc(self, cx, cy, rr * 0.92, C.cell, a)
        pic(self, "cap_light", cx - rr * 0.92, cy - rr * 0.92, rr * 1.84, rr * 1.84, mixTo(cc.b, C.header, C.tileEdge, 0.7), a)
        ring(self, cx, cy, rr, hot and C.accent or C.tileEdge, a)
        pic(self, sized("lamp_lights", rr * 1.1), cx - rr * 0.55, cy - rr * 0.55, rr * 1.1, rr * 1.1, lampC, a)
    end
    -- (the pull knob without a word: its sign says it - the author, 2026-10-21)
    if not l.pull then self:labelAt(self.txt.lights, cx, U(l.cy + l.r + l.capDy), cc.legend, self.fCap, a) end
    -- the doors' locks: a rocker tilted to the locked half, its LED over it
    local d = b.doors
    local x, y, w, h = snapWell(s, d[1], d[2], d[3], d[4])
    local k = self.doorK
    T.rect(self, x, y, w, h, C.cell, a)
    local ix, iy, iw, ih = x + 3, y + 3, w - 6, h - 6
    local half = math.floor(ih / 2)
    -- (each half lit toward its outer end, the raised one more: the mockup's gradients)
    sheen(self, ix, iy, iw, half, 0.55 - 0.4 * k, a, cc.b)
    sheen(self, ix, iy + half, iw, ih - half, 0.15 + 0.4 * k, a, cc.b, true)
    T.rect(self, ix, iy + half - 1, iw, 2, BLACK, 0.55 * a)
    -- (each lock in the middle of its half, the 2 px seam left out, on whole pixels: the
    -- closed one sat 1 px low at 1080p - the critic, 2026-10-28)
    local gs = math.floor(math.min(iw, ih) * 0.62)
    local gx = x + math.floor((w - gs) / 2)
    pic(self, sized("lamp_lockc", gs), gx, iy + math.floor((half - 1 - gs) / 2), gs, gs, cc.legend, a)
    pic(self, sized("lamp_locko", gs), gx, iy + half + 1 + math.floor((ih - half - 1 - gs) / 2), gs, gs, cc.legend, a)
    T.tileFrame(self, x, y, w, h, self.hot == "doors" and C.accent or C.tileEdge, a)
    -- (centred by its own whole width, as the trunk button's: 1 px left at 1440p - the critic, 2026-10-28)
    local lw = math.floor(U(10))
    self:led(x + math.floor((w - lw) / 2), y - math.floor(U(5)), lw, math.max(2, math.floor(U(2.6))), self.lampC.doors, a)
    -- (no words under the rocker and the button: their signs say it, as on a car's;
    -- the words ran into each other with the smallest font at 1280 x 1024)
    -- the trunk's release: only with a lockable trunk (as the game's lamp); a blank without
    local t = b.trunk
    if t then
        x, y, w, h = snapWell(s, t[1], t[2], t[3], t[4])
        if st.trunkHas then
            local p = self:button("trunk", x, y, w, h, self.hot == "trunk", a, self.lampC.trunk)
            -- (in the button's very middle on whole pixels: pushed down for the LED it
            -- looked off the middle - the author, 2026-10-21)
            local is = math.floor(math.min(w, h) * 0.55 / 2) * 2
            -- (floored: an odd button and an even sign gave half a pixel at 1440p, a blur)
            pic(self, sized("lamp_trunk", is), x + math.floor((w - is) / 2), y + math.floor((h - is) / 2) + p, is, is, cc.legend, a)
        else
            T.rect(self, x, y, w, h, C.cell, a)
            T.tileFrame(self, x, y, w, h, C.border, a)
        end
    end
end

-- -- the cluster -----------------------------------------------------------------------

function D:drawCluster(st, now, a)
    local C = T.color
    local b, s = self.body, self.s
    local cc = self.cc
    local lit, glow, fl = self.litF, self.glowF, self.fl or 1
    local function U(v) return v * s end
    -- the wells: the wall darker toward the top, the 2 px rim, the face; on it the
    -- backlight, the halo, the red zone, the marks and the numbers
    for _, d in ipairs(b.dials) do
        local cx, cy, r, rb = U(d.cx), U(d.cy), U(d.R), U(d.R + d.wall)
        d.px, d.py, d.pr = cx, cy, r
        disc(self, cx, cy, rb, C.header, a)
        pic(self, "shade_disc", cx - rb, cy - rb, rb * 2, rb * 2, BLACK, a)
        ring(self, cx, cy, rb, (self.hot == d.id or (d.id == "fuel" and self.hot == "fuelDial")) and C.accent or C.tileEdge, a)
        disc(self, cx, cy, r, C.cell, a)
        local x, y, size = cx - r, cy - r, r * 2
        -- (the halo faint: strong, it blurred the marks - the author, 2026-10-21)
        if glow > 0.01 then
            pic(self, "face_glow", x, y, size, size, GLOWC, 0.05 * glow * a)
            pic(self, self.kp[d.spec].glow, x, y, size, size, GLOWC, 0.3 * glow * a)
        end
        if d.spec ~= SPEED then pic(self, self.kp[d.spec].red, x, y, size, size, C.bad, a * (0.4 + 0.6 * math.max(lit, glow))) end
        pic(self, self.kp[d.spec].ticks, x, y, size, size, cc.scale, a)
        local sp, f = d.spec, self.dialFont[d]
        for _, l in ipairs(sp.labels) do
            local lx, ly = pt(cx, cy, r * sp.numR, sp.start - sp.sweep * l[1] / sp.vmax)
            self:labelAt(l[2], math.floor(lx + 0.5), math.floor(ly + 0.5), cc.scale, f, a)
        end
    end
    local sd = b.dials[2]
    local scx, scy, sR = sd.px, sd.py, sd.pr
    -- the speedometer's sand arc up to its needle; the cruise control's mark
    local sp = clamp(self.needles.speed.x, 0, 1.04)
    if sp > 0.004 then
        local th = math.max(2, U(2.2))
        local n = math.max(1, math.ceil(SPEED.sweep * sp / 4))
        local px, py
        for i = 0, n do
            local x, y = pt(scx, scy, sR * 0.93, SPEED.start - SPEED.sweep * sp * i / n)
            if px then bar(self, px, py, x, y, th, C.accent, a * (0.5 + 0.45 * lit)) end
            px, py = x, y
        end
    end
    if st.regulator and st.regSpeed > 0 then
        local f = clamp(st.regSpeed * BaseVehicle.getFakeSpeedModifier() / SPEED_MAX, 0, 1)
        local deg = SPEED.start - SPEED.sweep * f
        local x0, y0 = pt(scx, scy, sR + U(sd.wall + 1), deg)
        local x1, y1 = pt(scx, scy, sR + U(sd.wall + 6), deg)
        bar(self, x0, y0, x1, y1, math.max(2, U(3)), C.good, a * fl)
    end
    -- captions, figures, the fuel pump
    for _, d in ipairs(b.dials) do
        local cx, cy, r = d.px, d.py, d.pr
        -- (below the 0 and the 7, over the hub: the font's numbers are bigger than the
        -- pictures' were on a small dial - they met at 1280 x 1024)
        if d.cap then self:labelAt(self.txt.rpm, cx, cy + r * 0.64, cc.scale, self.fScale, a) end
        if d.unit then self:labelAt(self.txt.kmh, cx, cy - r * 0.25, cc.scale, self.fScale, 0.9 * a) end
        if d.digits then
            local w, h = math.floor(U(d.R * 0.7)), math.floor(U(20))
            local x, y = math.floor(cx - w / 2), math.floor(cy + r * 0.36 - h / 2)
            self.speedRoll = self.speedRoll or {}
            self:drum(self.speedRoll, num(st.power and math.floor(st.kmh + 0.5) or 0), x, y, w, h, st.power and cc.amber or C.tileEdge, self.fSpeed, a, C.tileEdge)
            if d.gear then
                local gw, gh = math.floor(U(22)), math.floor(U(16))
                local gx, gy = math.floor(cx - gw / 2), math.floor(cy + r * 0.36 + U(12))
                self.gearRoll = self.gearRoll or {}
                self:drum(self.gearRoll, st.gear, gx, gy, gw, gh, st.running and cc.amber or C.dim, self.fGear, a,
                    (self.hot == "speed" or st.running) and C.accent or C.tileEdge)
            end
        end
        if d.spec == FUEL then self:drawPump(st, cx, cy, r, now, a) end
    end
    -- the row of gears (the pickup's): R N 1..n, the one engaged lit
    local g = b.gears
    if g then
        local n = 2 + (self.gearCount or 5)
        local cw, h = math.floor(U(g.cw)), math.floor(U(g.h))
        local w = cw * n + 4
        local x, y = math.floor(U(g.cx) - w / 2), math.floor(U(g.y))
        T.rect(self, x, y, w, h, C.cell, a)
        mixTo(cc.c, cc.paint, GLOWC, glow * 0.6)
        for i = 1, n do
            local on = st.running and st.gear == GEARS[i]
            local gx = x + 2 + cw * (i - 1)
            if on then T.rect(self, gx, y + 2, cw, h - 4, NEEDLE, 0.16 * a) end
            self:label(GEARS[i], gx, y, cw, h, on and cc.amber or cc.c, self.fGears, a * (on and 1 or 0.85))
        end
        T.tileFrame(self, x, y, w, h, C.tileEdge, a)
    end
    -- the needles and their caps
    for _, d in ipairs(b.dials) do
        local n = self.needles[d.id]
        local deg = d.spec.start - d.spec.sweep * clamp(n.x, -0.02, 1.05)
        local fuel = d.spec == FUEL
        needle(self, d.px, d.py, deg, d.pr * (fuel and 0.8 or 0.86), d.pr * 0.2, math.max(1.6, d.pr * 0.045), cc.amber, a, 0.25 + 0.45 * lit * math.max(0.4, glow))
        local hr = math.max(4, d.pr * (fuel and 0.17 or 0.14))
        pic(self, "soft", d.px - hr * 1.4, d.py - hr * 1.1, hr * 2.8, hr * 2.8, BLACK, 0.6 * a)
        disc(self, d.px, d.py, hr, C.cell, a)
        pic(self, "cap_light", d.px - hr, d.py - hr, hr * 2, hr * 2, mixTo(cc.b, C.tileEdge, C.dim, 0.25), a)
        ring(self, d.px, d.py, hr, C.tileEdge, a)
    end
    -- the visor's shade on the faces' upper part
    for _, d in ipairs(b.dials) do
        pic(self, "shade_disc", d.px - d.pr, d.py - d.pr, d.pr * 2, d.pr * 2, BLACK, 0.6 * a)
    end
    -- the visor: the sedan's a picture with a brow over each well; the pickup's a band
    if b.visor then
        local vx, vy, vw, vh = snap(s, b.visor[1], b.visor[2], b.visor[3], b.visor[4])
        pic(self, self.hood.shadow, vx, vy, vw, vh, BLACK, 0.8 * a)
        pic(self, self.hood.fill, vx, vy, vw, vh, C.cell, a)
        pic(self, self.hood.dark, vx, vy, vw, vh, BLACK, 0.75 * a)
        pic(self, self.hood.lip, vx, vy, vw, vh, C.accent, 0.9 * a)
    elseif b.band then
        local x, y, w, h = snap(s, b.band[1], b.band[2], b.band[3], b.band[4])
        shade(self, x, y + h, w, U(12), 0.7 * a)
        T.rect(self, x, y, w, h, C.cell, a)
        shade(self, x, y, w, h, 0.6 * a)
        -- (no frame of its own: the cluster's frame is its top and sides; its sand
        -- edge under it, from the frame on the left to the frame on the right)
        T.rect(self, x, y + h - 2, w, 2, C.accent, 0.9 * a)
        for i = 1, 7 do T.rect(self, x + math.floor(w * i / 8), y + 3, 2, h - 7, C.border, a) end
        self:bolt(x + U(7), y + h / 2, a)
        self:bolt(x + w - U(7), y + h / 2, a)
    end
    if b.bolts then
        for _, p in ipairs(b.bolts) do self:bolt(U(p[1]), U(p[2]), a) end
    end
    -- the lamps behind smoked glass: dark until lit; they only show (no clicks)
    for _, gl in ipairs(b.glass) do
        local x, y, w, h = snap(s, gl[1], gl[2], gl[3], gl[4])
        T.rect(self, x, y, w, h, C.screen, a)
        shade(self, x, y, w, h * 0.5, 0.5 * a)
        T.tileFrame(self, x, y, w, h, C.tileEdge, a)
    end
    for _, t in ipairs(b.tells) do
        local tx, ty, tw, th = snap(s, t[2], t[3], t[4], t[5])
        self:telltale(t[1], tx, ty, tw, th, a)
    end
    local cn = b.cruiseNum
    local x, y, w, h = snap(s, cn[1], cn[2], cn[3], cn[4])
    local n = math.floor((st.regSpeed or 0) + 0.5)
    self.cruiseRoll = self.cruiseRoll or {}
    self:drum(self.cruiseRoll, n > 0 and num(n) or "-", x, y, w, h, st.regulator and C.good or C.dim, self.fCruise, a * (st.regulator and fl or 0.7),
        self.hot == "tt_cruise" and C.accent or C.border)
end

function D:bolt(x, y, a)
    local C = T.color
    local r = math.max(2.5, self:u(3.4))
    disc(self, x, y, r, C.cell, a)
    ring(self, x, y, r, C.tileEdge, a)
    bar(self, x - r * 0.6, y - r * 0.3, x + r * 0.6, y + r * 0.3, 1, C.tileEdge, a)
end

--- A figure window as on a drum: the figures roll (T.rollNumber), shaded top and bottom.
function D:drum(roll, text, x, y, w, h, c, font, a, frameC)
    T.rect(self, x, y, w, h, T.color.cell, a)
    -- (the rolling figures only inside the window: they ran out over its frame - the
    -- author, 2026-10-21)
    self:clipTo(x + 2, y + 2, w - 4, h - 4)
    T.rollNumber(self, roll, text, x, y, w, h, c.r, c.g, c.b, a, font)
    self:unclip()
    shade(self, x + 2, y + 2, w - 4, (h - 4) * 0.32, 0.65 * a)
    shade(self, x + 2, y + h - 2 - (h - 4) * 0.32, w - 4, (h - 4) * 0.32, 0.65 * a, true)
    T.tileFrame(self, x, y, w, h, frameC, a)
end

--- A warning lamp behind the glass: its symbol dark until lit, a glow round it lit.
function D:telltale(id, x, y, w, h, a)
    local cur = self.lampC[id]
    local lv = cur.l * (self.fl or 1)
    if lv > 0.01 then pic(self, "soft", x - w * 0.35, y - h * 0.35, w * 1.7, h * 1.7, cur, 0.4 * lv * a) end
    -- (on whole pixels, the symbol's size even with its cell's: on fractions it
    -- stood a pixel off the middle of its frame - the author, 2026-10-21)
    local is = w - 2 * math.floor((w - math.floor(w * 0.82)) / 2)
    local c = lv > 0.01 and mixTo(self.cc.c, T.color.dim, cur, math.min(1, lv * 1.2)) or T.color.dim
    pic(self, sized(LAMP_PIC[id], is), x + (w - is) / 2, y + math.floor((h - is) / 2), is, is, c, a * (0.13 + 0.87 * lv))
    if self.hot == TT_ID[id] then T.tileFrame(self, x - 2, y - 2, w + 4, h + 4, T.color.accent, a) end
end

--- The fuel gauge's pump: its caption and its low fuel lamp (warn under 15 %, red
--- and pulsing under 5 %), the filler's side an arrow next to it (both centred
--- together by their pixels, as the author asked 2026-10-18).
function D:drawPump(st, cx, cy, r, now, a)
    local C = T.color
    local s = self.s
    local is = math.floor(r * 0.5)
    local pcy = cy + r * 0.42
    local low = st.gas and (st.running or st.keyIn) and st.fuelPct < 15
    local pc, pl = self.cc.scale, 0
    if low then
        pc = st.fuelPct < 5 and C.bad or C.warn
        pl = (st.fuelPct < 5 and T.animOn()) and (0.55 + 0.45 * (0.5 + 0.5 * math.cos(now / 1000 * math.pi * 2 * 1.25))) or 1
        pl = pl * (self.fl or 1)
        pic(self, "soft", cx - is, pcy - is, is * 2, is * 2, pc, 0.3 * pl * a)
    end
    local glyphW = is * 25 / 40
    local tw, th, gap = 5 * s, 3.5 * s, 3.5 * s
    local dir = st.side == "left" and -1 or (st.side == "right" and 1 or 0)
    local mid = cx - dir * (gap + tw) / 2
    local pa = a * (low and (0.5 + 0.5 * pl) or 1)
    pic(self, sized("lamp_fuel", is), mid - is / 2, math.floor(pcy - is / 2), is, is, pc, pa)
    -- (the filler's arrow in the pump's colour, lit and pulsing with it: sand next to
    -- the red pump looked like another lamp - the author, 2026-10-21)
    if st.side then tri(self, mid + dir * (glyphW / 2 + gap + tw), pcy, tw, th * 2, dir, pc, pa) end
    if not st.gas then self:labelAt("-", cx, cy - r * 0.2, C.tileEdge, self.fScale, a) end
end

-- -- the column: the ignition ----------------------------------------------------------

function D:drawColumn(st, now, dt, a)
    local C = T.color
    local b, s = self.body, self.s
    local function U(v) return v * s end
    if b.shroud then
        local x, y, w, h = snap(s, b.shroud[1], b.shroud[2], b.shroud[3], b.shroud[4])
        T.rect(self, x, y, w, h, C.cell, a)
        shade(self, x, y, w, h * 0.6, 0.4 * a)
    end
    local g = b.ign
    local icx, icy, ir, inr = U(g.cx), U(g.cy), U(g.r), U(g.inner)
    local hover = self.hot == "ign"
    disc(self, icx, icy, ir, C.header, a)
    pic(self, "shade_disc", icx - ir, icy - ir, ir * 2, ir * 2, BLACK, a)
    ring(self, icx, icy, ir, hover and C.accent or C.tileEdge, a)
    disc(self, icx, icy, inr, C.cell, a)
    pic(self, "cap_light", icx - inr, icy - inr, inr * 2, inr * 2, mixTo(self.cc.b, C.header, C.tileEdge, 0.6), a)
    ring(self, icx, icy, inr, C.tileEdge, a)
    -- its marks: OFF, ON (lit with the ignition), START (while it cranks)
    local function mark(deg, c, al)
        local x0, y0 = pt(icx, icy, inr + U(2), 90 - deg)
        local x1, y1 = pt(icx, icy, ir - U(3), 90 - deg)
        bar(self, x0, y0, x1, y1, math.max(1.5, U(2)), c, al)
    end
    mark(KEY_OFF, C.dim, a)
    mark(KEY_ON, st.power and NEEDLE or C.tileEdge, a * (0.5 + 0.5 * self.litF))
    mark(KEY_START, st.starting and C.warn or C.tileEdge, a)
    -- the lock's slot turns with the key
    turned(self, "white", icx, icy, U(5.2), U(18), self.keyAng, C.screen, a)
    -- the key: pushed in (from a bit bigger and clear), turning
    if self.keyVis > 0.01 then
        local kv = self.keyVis
        local size = U(88) * g.r / 31 * (1 + 0.3 * (1 - kv))
        local shiver = (st.starting and not st.running and T.animOn()) and ZombRandFloat(-1.2, 1.2) or 0
        local ang = self.keyAng + shiver
        local blade = mixTo(self.cc.b, C.accent, C.ink, 0.22)
        local so = math.max(1, U(1.5))
        turned(self, sized("key_shadow", size), icx + so, icy + so, size, size, ang, BLACK, 0.5 * a * kv)
        turned(self, sized("key_blade", size), icx, icy, size, size, ang, blade, a * kv)
        turned(self, sized("key_head", size), icx, icy, size, size, ang, hover and C.bright or C.accent, a * kv)
        turned(self, sized("key_groove", size), icx, icy, size, size, ang, blade, a * kv)
        turned(self, sized("key_edge", size), icx, icy, size, size, ang, C.bright, 0.7 * a * kv)
    end
    -- hot-wired: two wires out of the lock; their ends meet as it starts
    if st.hot then self:drawWires(icx, icy, a) end
    self:drawSparks(a, now, dt)
    -- (no caption: the key says it - the author, 2026-10-21)
end

function D:drawWires(icx, icy, a)
    local C = T.color
    local s = self.s
    local k = self.wires
    local tx, ty = icx, icy + 18 * s
    -- (each wire: from the lock down and out; its end swings to the tip)
    local function wire(dir, c)
        local x0, y0 = icx + dir * 2 * s, icy + 6 * s
        local apartX, apartY = icx + dir * 20 * s, icy + 24 * s
        local ex = apartX + (tx + dir * 1.5 * s - apartX) * k
        local ey = apartY + (ty - apartY) * k
        local c1x, c1y = icx + dir * 6 * s, icy + 18 * s
        local c2x, c2y = ex + dir * (12 - 8 * k) * s, ey - 4 * s
        local px, py
        for i = 0, 12 do
            local t = i / 12
            local u = 1 - t
            local x = u * u * u * x0 + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t * t * t * ex
            local y = u * u * u * y0 + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * ey
            if px then bar(self, px, py, x, y, math.max(1.5, 2.2 * s), c, a) end
            px, py = x, y
        end
        local cr = math.max(1.5, 2 * s)
        pic(self, sized("hub", cr * 2), ex - cr, ey - cr, cr * 2, cr * 2, C.accent, a)
    end
    wire(-1, C.bad)
    wire(1, C.warn)
end

function D:drawSparks(a, now, dt)
    local g = 260 * self.s
    for _, p in ipairs(self.sparks) do
        local age = now - (p.born or 0)
        if age < p.life then
            local t = age / p.life
            p.vy = p.vy + g * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            local sz = p.size * (1 - 0.5 * t)
            pic(self, "soft", p.x - sz, p.y - sz, sz * 2, sz * 2, SPARK, a * (1 - t))
            pic(self, sized("hub", sz * 0.6), p.x - sz * 0.3, p.y - sz * 0.3, sz * 0.6, sz * 0.6, WHITE, a * (1 - t))
        end
    end
end

-- -- the radio ---------------------------------------------------------------------------

--- Figures of the display: `value` right-aligned at xr over `places` places, the
--- point lit after place `dotAt` (0: none); each place shows a faint 8 behind.
function D:segs(value, places, dotAt, xr, y, h, a, glow, lead)
    local pitch, w = h * 0.7, h * 0.5
    local ph = h * 64 / 56
    local pw = ph * 48 / 64
    local ghost = 0.06 * self.disp + 0.04
    -- (the figures' copy nearest their height, at least as tall; else the picture)
    local seg, segg = SEG_NAME, SEGG_NAME
    for i, sh in ipairs(SEGH) do
        if sh >= ph - 0.5 then seg, segg = SEG_H[i], SEGG_H[i] break end
    end
    local v = math.floor(value + 0.5)
    for i = places, 1, -1 do
        local x = xr - (places - i + 1) * pitch + (pitch - w)
        local px, py = x - 6 * ph / 64, y - 4 * ph / 64
        pic(self, seg[8], px, py, pw, ph, VFD, ghost * a)
        local dgt = v % 10
        v = math.floor(v / 10)
        -- (no leading noughts: those places stay dark; `lead` places always shown)
        local shown = a > 0.003 and (v > 0 or dgt > 0 or i > places - (lead or 1))
        if shown then
            if glow > 0.01 then pic(self, segg[dgt], px, py, pw, ph, VFD, 0.35 * glow * a) end
            pic(self, seg[dgt], px, py, pw, ph, VFD, a)
        end
        if i == dotAt then
            local ds = math.max(2, h * 0.14 * 1.35)
            T.rect(self, x + w + (pitch - w) * 0.5 - ds / 2, y + h - ds, ds, ds, VFD, a > 0.003 and a or ghost * a)
        end
    end
end

function D:drawRadio(st, now, a)
    local C = T.color
    local b, s = self.body, self.s
    local cc = self.cc
    local rx, ry = b.radio[1], b.radio[2]
    local function X(v) return (rx + v) * s end
    local function Y(v) return (ry + v) * s end
    local function U(v) return v * s end
    local function box(bx, by, bw, bh) return snap(s, rx + bx, ry + by, bw, bh) end
    local x, y, w, h = box(0, 0, RADIO_W, RADIO_H)
    -- the faceplate
    T.rect(self, x, y, w, h, C.cell, a)
    sheen(self, x + 2, y + 2, w - 4, h - 4, 0.35, a, cc.b)
    T.tileFrame(self, x, y, w, h, C.tileEdge, a)
    if not st.rHas then
        -- no set in the car: a blank plate in its place, as in a car without a radio
        local m = math.floor(U(10))
        T.rect(self, x + m, y + m, w - m * 2, h - m * 2, C.cell, a)
        T.tileFrame(self, x + m, y + m, w - m * 2, h - m * 2, C.border, a)
        self:label(self.txt.noRadio, x, y, w, h, C.tileEdge, self.fCap, a)
        return
    end
    local legend = cc.legend
    -- VOL (pushed: on / off) and TUNE
    self:knob(X(22), Y(30), U(14), self.volKnob.x, self.hot == "vol", a, st.rOn and C.accent or C.dim)
    self:labelAt(self.txt.vol, X(22), Y(56), legend, self.fSmall, a)
    self:knob(X(266), Y(30), U(13), self.tuneKnob.x, self.hot == "tune", a, C.dim)
    self:labelAt(self.txt.tune, X(266), Y(56), legend, self.fSmall, a)
    -- the display: dark glass; lit, the figures and their legends
    local dx, dy, dw, dh = box(42, 8, 124, 32)
    T.rect(self, dx, dy, dw, dh, C.screen, a)
    shade(self, dx, dy, dw, dh * 0.5, 0.4 * a)
    T.tileFrame(self, dx, dy, dw, dh, self.hot == "display" and C.accent or C.tileEdge, a)
    local k = self.disp * (self.fl or 1)
    local ka = a * k
    local fh = U(20)
    local xr, fy = dx + dw - U(7), dy + U(6)
    local lx, ly1, ly2, lh = dx + U(6), dy + U(4), dy + U(17), U(10)
    local fs = self.fSmall
    if now - self.noTapeAt < VOL_MS then
        -- (TAPE pressed with no music of one's own: said on the display a moment)
        self:label(self.txt.noTape, dx, dy, dw, dh, VFD, fs, a)
    elseif k < 0.02 then
        self:segs(0, 4, 0, xr, fy, fh, 0, 0)
    elseif now - self.volAt < VOL_MS then
        self:label(self.txt.vol, lx, ly1, U(40), lh, VFD, fs, ka, "left")
        self:segs(st.vol * 30, 4, 0, xr, fy, fh, ka, k)
    elseif st.tape then
        self:label(self.txt.tape, lx, ly1, U(40), lh, VFD, fs, ka, "left")
        local blink = (st.playing and T.animOn() and math.floor(now / 500) % 2 == 1) and 0.55 or 1
        -- (the play sign half way between the legends on the left and the figures'
        -- places - next to the legends it looked stuck to them, the author 2026-10-21)
        local left = lx + math.max(T.measure(fs, self.txt.tape), U(26))
        local figs = xr - 2.6 * fh
        local mid = math.floor((left + figs) / 2 + 0.5)
        tri(self, mid + U(4), dy + dh / 2, U(8), U(10), 1, VFD, ka * (st.playing and blink or 0.35))
        -- the track's number (none yet: the places dark)
        self:segs(st.at % 100, 4, 0, xr, fy, fh, st.at > 0 and ka or 0, k, 2)
        -- MIX and RPT (RPT 1) as signs, faint when off
        local is = U(11)
        pic(self, sized("lamp_mix", is), lx, ly2 + lh / 2 - is / 2, is, is, VFD, ka * (st.mix and 1 or 0.08))
        pic(self, sized(st.rpt == "one" and "lamp_rpt1" or "lamp_rpt", is), lx + U(15), ly2 + lh / 2 - is / 2, is, is, VFD, ka * (st.rpt ~= "off" and 1 or 0.08))
    else
        local f = st.freq
        local seeking = now - self.seekAt < SEEK_MS and self.seekFrom and self.seekFrom ~= f
        if seeking then
            -- (the figures run up to the station found, as a seeking set's)
            local p = (now - self.seekAt) / SEEK_MS
            local span = f - self.seekFrom
            f = self.seekFrom + span * p
        end
        self:label(self.txt.fm, lx, ly1, U(30), lh, VFD, fs, ka, "left")
        if seeking then
            local on = (not T.animOn()) or math.floor(now / 150) % 2 == 0
            self:label(self.txt.seek, lx, ly2, U(30), lh, VFD, fs, ka * (on and 1 or 0.3), "left")
        elseif st.preset > 0 then
            self:label(PRESET_P[st.preset], lx, ly2, U(20), lh, VFD, fs, ka, "left")
        end
        self:segs(math.floor(f / 200 + 0.5) * 2, 4, 3, xr, fy, fh, ka, k, 2)
    end
    -- the presets 1-6; their second use (with the tape) printed under them
    local sub = mixTo(cc.c, legend, C.accent, 0.45)
    for i = 1, 6 do
        local id = PRESET_ID[i]
        local bx, by, bw, bh = box(42 + (i - 1) * 21, 44, 19, 13)
        local p = self:key(id, bx, by, bw, bh, a)
        local on = st.rLive and ((not st.tape and st.preset == i) or (st.tape and ((i == 3 and st.mix) or (i == 4 and st.rpt ~= "off"))))
        self:label(PRESET_TXT[i], bx, by + p, bw, bh, on and VFD or legend, self.fBtn, a)
        local sy = Y(64)
        local cx = bx + bw / 2
        if i == 1 then
            tri(self, cx - U(4), sy, U(4), U(5), -1, sub, a); tri(self, cx, sy, U(4), U(5), -1, sub, a)
        elseif i == 2 then
            tri(self, cx, sy, U(4), U(5), 1, sub, a); tri(self, cx + U(4), sy, U(4), U(5), 1, sub, a)
        elseif i == 3 or i == 4 then
            local is = U(8)
            pic(self, sized(i == 3 and "lamp_mix" or "lamp_rpt", is), cx - is / 2, sy - is / 2, is, is, sub, a)
        end
    end
    -- the cassette deck: its slot, a smoked window, the tape inside with its reels
    local sx, sy, sw, sh = box(172, 8, 76, 20)
    T.rect(self, sx, sy, sw, sh, C.cell, a)
    -- (every inset a whole pixel taken equally from both sides, so the gaps match)
    local m = math.floor(U(4) + 0.5)
    local wx, wy, ww, wh = sx + m, sy + math.floor(U(3)), sw - 2 * m, math.floor(U(10))
    T.rect(self, wx, wy, ww, wh, C.screen, a)
    local tk = self.tapeK * self.tapeVis
    if tk > 0.02 then
        local ti, tv = math.floor(U(8) + 0.5), math.max(1, math.floor(U(1) + 0.5))
        T.rect(self, wx + ti, wy + tv, ww - 2 * ti, wh - 2 * tv, mixTo(cc.c, C.cell, PAPER, 0.22), a * tk)
        local rd = math.floor(ww * 0.3 + 0.5)
        for j = 1, 2 do
            -- (both reels the same distance in from the window's edges)
            local rcx = j == 1 and wx + rd or wx + ww - rd
            local rr = math.floor(U(3.8) + 0.5)
            turned(self, sized("reel", rr * 2), rcx, wy + wh / 2, rr * 2, rr * 2, self.reel * (j == 1 and 1.15 or 1), C.dim, a * tk)
        end
    end
    shade(self, wx, wy, ww, wh, 0.3 * a, true)
    T.rect(self, sx + m, sy + U(15), sw - 2 * m, U(2), BLACK, a)   -- (the slot's mouth)
    T.tileFrame(self, sx, sy, sw, sh, self.hot == "slot" and C.accent or C.tileEdge, a)
    if self.tapeOut and self.tapeVis > 0.02 then
        -- pushed out: the tape's spine sticks out of the mouth
        local out = self.tapeVis * (1 - self.tapeK)
        pic(self, "soft", sx + U(4), sy + U(12), sw - U(8), U(14), BLACK, 0.6 * a * out)
        T.rect(self, sx + U(8), sy + U(14), sw - U(16), U(6) * out + U(1), mixTo(cc.c, C.tileEdge, PAPER, 0.35), a)
        T.rect(self, sx + U(16), sy + U(15), sw - U(32), math.max(1, U(3) * out), PAPER, 0.8 * a * out)
    end
    -- FM, TAPE, SEEK, EJECT
    local fx, ty, kw, kh = box(172, 32, 37, 12)
    local p = self:key("fm", fx, ty, kw, kh, a)
    self:label(self.txt.fm, fx, ty + p, kw, kh, (st.rLive and not st.tape) and VFD or legend, fs, a)
    local tx = box(211, 32, 37, 12)
    p = self:key("tape", tx, ty, kw, kh, a)
    self:label(self.txt.tape, tx, ty + p, kw, kh, (st.rLive and st.tape) and VFD or legend, fs, a)
    local _, ky = box(0, 48, 1, 1)
    local half = math.floor(kw / 2)
    p = self:key("seekL", fx, ky, half, kh, a)
    tri(self, fx + half / 2 - U(2), ky + kh / 2 + p, U(5), U(6), -1, legend, a)
    p = self:key("seekR", fx + half, ky, kw - half, kh, a)
    tri(self, fx + half + (kw - half) / 2 + U(2), ky + kh / 2 + p, U(5), U(6), 1, legend, a)
    p = self:key("eject", tx, ky, kw, kh, a)
    local ex, ey = tx + kw / 2, ky + kh / 2 + p
    quad(self, white(), ex, ey - U(3.4), ex, ey - U(3.4), ex + U(4), ey + U(0.6), ex - U(4), ey + U(0.6), legend, a)
    T.rect(self, ex - U(4), ey + U(2), U(8), math.max(1, U(1.4)), legend, a)
end

-- -- the heater ----------------------------------------------------------------------------

function D:drawClimatePlate(x, y, w, h, a)
    local C = T.color
    T.rect(self, x, y, w, h, C.cell, a)
    sheen(self, x + 2, y + 2, w - 4, h - 4, 0.3, a, self.cc.b)
    T.tileFrame(self, x, y, w, h, C.tileEdge, a)
end

function D:drawClimateKnobs(st, now, a)
    local C = T.color
    local c, s = self.body.climate, self.s
    local cc = self.cc
    local function X(v) return (c[1] + v) * s end
    local function Y(v) return (c[2] + v) * s end
    local function U(v) return v * s end
    local function box(bx, by, bw, bh) return snap(s, c[1] + bx, c[2] + by, bw, bh) end
    local px, py, pw, ph = box(0, 0, c[3], c[4])
    self:drawClimatePlate(px, py, pw, ph, a)
    -- the temperature: blue to red round the knob, a dot at each of its 7 places
    -- (the knob in the plate's middle: at 26 it was pressed to its top - the author)
    -- (6 below the plate's middle: its scale and dots stand over it, none under - in
    -- the middle it still looked pressed to the top, the author 2026-10-21)
    local cx, cy, r = X(36), Y(c[4] / 2 + 6), U(14)
    local ar = U(26)
    pic(self, sized("temp_arc", ar * 2), cx - ar, cy - ar, ar * 2, ar * 2, WHITE, a * (0.5 + 0.5 * math.max(self.litF, self.glowF)))
    self:knob(cx, cy, r, self.tempKnob.x, self.hot == "temp", a, C.accent)
    -- the heater's button with its LED, its word in the very middle
    local bx, by, bw, bh = box(76, 10, 78, c[4] - 20)
    local p = self:button("heater", bx, by, bw, bh, self.hot == "heater", a, self.lampC.heater)
    self:label(self.txt.heater, bx, by + p, bw, bh, cc.legend, self.fCap, a)
    -- a window open: the warmth goes out of it (the game's heater window says so too)
    local wx, wy, ww, wh = box(162, 10, 42, c[4] - 20)
    T.rect(self, wx, wy, ww, wh, C.screen, a)
    T.tileFrame(self, wx, wy, ww, wh, self.hot == "window" and C.accent or C.border, a)
    local wc = self.lampC.window
    local col = wc.l > 0.05 and mixTo(cc.c, C.dim, wc, wc.l) or mixTo(cc.c, C.tileEdge, C.dim, 0.2)
    if wc.l > 0.05 then pic(self, "soft", wx, wy - wh * 0.2, ww, wh * 1.4, wc, 0.25 * wc.l * a) end
    self:label(self.txt.window, wx, wy, ww, wh, col, self.fCap, a)
    -- the vents
    local vx, vy, vw, vh = box(212, 8, 64, c[4] - 16)
    T.rect(self, vx, vy, vw, vh, C.screen, a)
    mixTo(cc.c, C.header, C.tileEdge, 0.4)
    -- six slats with the same room above, between and below them (inside the 2 px
    -- frame), on whole pixels: the room at the top was bigger - the author, 2026-10-21
    local th = math.max(2, math.floor(U(2.6) + 0.5))
    local gap = (vh - 4 - 6 * th) / 7
    local mx = 2 + math.floor(gap + 0.5)
    for i = 0, 5 do T.rect(self, vx + mx, vy + 2 + math.floor(gap * (i + 1) + th * i + 0.5), vw - mx * 2, th, cc.c, a) end
    T.tileFrame(self, vx, vy, vw, vh, C.tileEdge, a)
end

function D:lever(x, y, hover, markC, a)
    local C = T.color
    local s = self.s
    local w, h = math.floor(10 * s), math.floor(18 * s)
    local lx, ly = math.floor(x - w / 2), math.floor(y - h / 2)
    pic(self, "soft", lx - w * 0.4, ly + 2 * s, w * 1.8, h * 1.2, BLACK, 0.6 * self.k)
    T.rect(self, lx, ly, w, h, C.header, a)
    T.tileFrame(self, lx, ly, w, h, hover and C.accent or C.tileEdge, a)
    T.rect(self, math.floor(x - s), ly + math.floor(3 * s), math.max(2, math.floor(2 * s)), h - math.floor(6 * s), markC, a)
end

function D:drawClimateLevers(st, now, a)
    local C = T.color
    local c, s = self.body.climate, self.s
    local cc = self.cc
    local function X(v) return (c[1] + v) * s end
    local function Y(v) return (c[2] + v) * s end
    local function U(v) return v * s end
    local px, py, pw, ph = snap(s, c[1], c[2], c[3], c[4])
    self:drawClimatePlate(px, py, pw, ph, a)
    local fs = self.fSmall
    local th = U(10)
    -- the temperature: a lever along a slot cold blue to hot red
    local tx0, tx1, ty = X(16), X(168), Y(25)
    self:labelAt(self.txt.temp, (tx0 + tx1) / 2, Y(10), cc.legend, fs, a)
    pic(self, "temp_track", tx0, ty - U(2), tx1 - tx0, U(4), WHITE, a * (0.55 + 0.45 * math.max(self.litF, self.glowF)))
    T.rect(self, tx0, ty - U(1), tx1 - tx0, U(2), BLACK, 0.5 * a)
    self:lever(tx0 + (tx1 - tx0) * ((self.tempKnob.x + 120) / 240), ty, self.hot == "temp", C.accent, a)
    self:label(self.txt.cold, tx0, Y(41) - th / 2, U(60), th, mixTo(cc.c, COLD_C, cc.legend, 0.4), fs, a, "left")
    self:label(self.txt.warm, tx1 - U(60), Y(41) - th / 2, U(60), th, mixTo(cc.b, HOT_C, cc.legend, 0.4), fs, a, "right")
    -- the heater: a lever, off / on
    local hx0, hx1 = X(190), X(256)
    self:labelAt(self.txt.heater, (hx0 + hx1) / 2, Y(10), cc.legend, fs, a)
    T.rect(self, hx0, ty - U(1), hx1 - hx0, U(2), BLACK, 0.6 * a)
    self:lever(hx0 + (hx1 - hx0) * self.heatK, ty, self.hot == "heater", st.heatOn and C.good or C.dim, a)
    self:label(self.txt.off, hx0, Y(41) - th / 2, U(30), th, cc.legend, fs, a, "left")
    self:label(self.txt.on, hx1 - U(30), Y(41) - th / 2, U(30), th, cc.legend, fs, a, "right")
    self:led(math.floor(X(268)), math.floor(Y(12)), math.floor(U(8)), math.max(2, math.floor(U(2.6))), self.lampC.heater, a)
    self:led(math.floor(X(268)), math.floor(Y(22)), math.floor(U(8)), math.max(2, math.floor(U(2.6))), self.lampC.window, a)
end

-- Tips ----------------------------------------------------------------------------------

--- A hovered thing's tip, as Knox's cards are: {title, icon, rows = {{l, v, c,
--- frac}}, lines (its note wrapped)}. Only what the panel doesn't show: the share
--- behind a lamp's colour, exact figures, why something can't work, and what a
--- control does when clicked, turned, right-clicked (the author, 2026-10-21: the
--- panel's controls are a car's now - each says what it does). Made when the
--- thing under the mouse changes and a few times a second (never each frame).
function D:tipOf(id, st)
    local MM = self.MM
    local v = self.vehicle
    local C = T.color
    local function tx(k, ...) return getText("IGUI_Knox_Dash_" .. k, ...) end
    local function pct(x) return tostring(math.floor(clamp(x, 0, 100) + 0.5)) .. "%" end
    local function share(f) return mixC(C.bad, C.good, clamp(f, 0, 1)) end
    local t = {rows = {}}
    local function row(l, val, c, frac) table.insert(t.rows, {l = l, v = val, c = c or C.text, frac = frac}) end
    if id == "lights" then
        t.title, t.icon, t.note = getText("Tooltip_Dashboard_Headlights"), "lamp_lights", tx("Tip_Click_OnOff")
        if st.lights and not st.lightsLit then t.note = tx("Lights_Dead") end
    elseif id == "doors" then
        t.title, t.icon, t.note = getText("Tooltip_Dashboard_LockedDoors"), "lamp_doors", tx("Tip_Doors")
    elseif id == "trunk" then
        t.title, t.icon, t.note = tx("Trunk"), "lamp_trunk", tx("Tip_Trunk")
    elseif id == "ign" then
        t.title = tx("Ignition_Tip")
        local chr = self.character
        if st.hot then t.note = tx("Tip_Ign_Hot")
        elseif st.keyIn then t.note = tx("Tip_Ign_Key")
        elseif chr and chr:getInventory():haveThisKeyId(v:getKeyId()) then t.note = tx("Tip_Ign_Put")
        else t.note = getText("Tooltip_Dashboard_NoKey") end
    elseif id == "tt_engine" then
        t.title, t.icon = getText("Tooltip_Dashboard_Engine"), "lamp_engine"
        row(tx("L_Condition"), pct(st.engineCond), share(st.engineCond / 100), st.engineCond / 100)
        if not self.engineOk then t.note = tx("Engine_Bad") end
    elseif id == "tt_battery" then
        t.title, t.icon = getText("Tooltip_Dashboard_Battery"), "lamp_battery"
        local b = v:getPartById("Battery")
        if b and b:getInventoryItem() then row(tx("L_Charge"), pct(st.charge * 100), share(st.charge), st.charge)
        else t.note = tx("NoBattery") end
    elseif id == "tt_lights" then
        t.title, t.icon = getText("Tooltip_Dashboard_Headlights"), "lamp_lights"
        if st.lights and not st.lightsLit then t.note = tx("Lights_Dead") end
    elseif id == "tt_cruise" then
        t.title, t.icon = tx("Cruise"), "lamp_cruise"
        local fwd, back = 0, 0
        pcall(function() fwd, back = getCore():getKey(KeybindId.FORWARD), getCore():getKey(KeybindId.BACKWARD) end)
        t.note = getText("Tooltip_Dashboard_SpeedRegulator", keyName(Keyboard.KEY_LSHIFT), keyName(fwd), keyName(back))
    elseif id == "fuelDial" then
        t.title, t.icon = tx("Fuel"), "lamp_fuel"
        if not st.gas then t.note = tx("NoTank")
        elseif st.running or st.keyIn then
            local f = st.fuelPct / 100
            row(tx("L_InTank"), pct(st.fuelPct), f < 0.05 and C.bad or (f < 0.15 and C.warn or C.text), f)
        else t.note = tx("FuelDark") end
    elseif id == "tach" then
        -- (a tip with the engine off too: a frame lit and nothing coming looked
        -- broken - the author, 2026-10-21)
        t.title = tx("Rpm")
        if st.running then
            row(tx("L_Rpm"), tx("RpmNow", tostring(math.floor(st.rpm / 50 + 0.5) * 50)), NEEDLE)
        else
            t.note = tx("Tip_Rpm_Off")
        end
    elseif id == "speed" then
        t.title = tx("Speed")
        row(tx("L_Speed"), tx("SpeedNow", tostring(st.power and math.floor(st.kmh + 0.5) or 0)), NEEDLE)
        row(getText("Tooltip_Dashboard_Shift"), st.running and st.gear or "-", C.text)
    elseif id == "vol" then
        t.title = tx("Tip_Vol")
        row(tx("L_Now"), num(math.floor(st.vol * 30 + 0.5)), C.text, st.vol)
        t.note = tx("Tip_Vol_Note")
    elseif id == "tune" then
        t.title, t.note = tx("Tip_Tune"), tx("Tip_Tune_Note")
    elseif id == "display" then
        t.title, t.note = tx("Tip_Display"), tx("Tip_Display_Note")
        local title = MM.carTitle and MM.carTitle(st.tape and "mine" or "game")
        if title then row(title, "", VFD) end
    elseif id == "fm" then
        t.title, t.note = tx("Tip_FM"), tx("Tip_FM_Note")
    elseif id == "tape" or id == "slot" then
        t.title = tx("Tip_Tape")
        if not MM.available("mine") then t.note = tx("Tip_NoTape")
        elseif st.tape then t.note = tx("Tip_Tape_In")
        else t.note = tx("Tip_Tape_Note") end
    elseif id == "eject" then
        t.title, t.note = tx("Tip_Eject"), tx("Tip_Eject_Note")
    elseif id == "seekL" or id == "seekR" then
        if st.tape then t.title, t.note = tx("Tip_Wind"), tx("Tip_Wind_Note")
        else t.title, t.note = tx("Tip_Seek"), tx("Tip_Seek_Note") end
    elseif PRESET[id] then
        local i = PRESET[id]
        if st.tape then
            local keys = {"Tip_Prev", "Tip_Next", "Tip_Mix", "Tip_Rpt"}
            if not keys[i] then return nil end
            t.title = tx(keys[i])
            if i == 4 then t.note = tx("Tip_Rpt_Note") end
        else
            t.title = tx("Tip_Station", tostring(i))
            local tr = MM.stations() and MM.list[i]
            if tr then row(tr.title, "", C.text) else t.note = tx("Tip_Station_None") end
        end
    elseif id == "temp" then
        t.title = tx("Tip_Temp")
        local tv = TEMPS[tempIndex(st.heatTemp)]
        row(tx("L_Knob"), (tv > 0 and "+" or "") .. tostring(tv), tv > 0 and HOT_C or (tv < 0 and COLD_C or C.text))
        t.note = self:heaterWhyNot(st) or tx("Tip_Temp_Note")
    elseif id == "heater" then
        t.title, t.icon = getText("Tooltip_Dashboard_Heater"), "lamp_heater"
        t.note = self:heaterWhyNot(st) or tx("Tip_Heater_Note")
    elseif id == "window" then
        t.title, t.note = tx("Tip_Window"), tx("Tip_Window_Note")
    else
        return nil
    end
    -- (a demo's tip says how to drive its pretend car: the wheel is the gas)
    if self.demo then t.note = self.demo:tipNote(id) or t.note end
    -- the note wrapped once here, not each frame
    t.lines = t.note and T.wrap(t.note, self.fTipSmall, math.floor(T.cell * 5.4)) or {}
    return t
end

--- Why the heater won't answer (the game's heater window's own reasons), or nil.
function D:heaterWhyNot(st)
    if not st.heater then return getText("IGUI_Knox_Dash_NoHeater") end
    if not st.power then return getText("UI_Vehicle_HeaterNeedKey") end
    return nil
end

--- The tip over what the mouse rests on, as a small Knox card: the sand frame,
--- the head (the icon in its cell, the name), the rows, the note; it rises into
--- place and fades as the cards do. (The radio's controls have none while its
--- card stands over them.)
function D:drawTip(st, now, dt, a)
    local id = self.hot
    if id and NO_TIP[id] then id = nil end
    if id ~= self.tipId then
        self.tipId, self.tipSince = id, now
        if id then
            self.tipRect = self.hotHit
            self.tipT, self.tipAt = nil, 0
        end
    end
    local want = id ~= nil and now - self.tipSince >= TIP_DELAY
    self.tipK = ease(self.tipK, want and 1 or 0, 1000 / TIP_IN, dt)
    if self.tipK < 0.02 then return end
    local show = self.tipId or self.tipLast
    if not show then return end
    if show ~= self.tipLast or now >= self.tipAt then
        self.tipLast, self.tipAt = show, now + 300
        self.tipT = self:tipOf(show, st)
    end
    local t = self.tipT
    if not t then return end
    local C = T.color
    local pad = T.pad
    local half = math.floor(pad / 2)
    local frame = 2
    local fH, fT, fS = T.fontHeader, T.fontText, T.fontTile
    local hH, tH, sH = T.fontH(fH), T.fontH(fT), T.fontH(fS)
    local maxW = math.floor(T.cell * 5.4)
    local cell = hH + half
    local headW = (t.icon and (cell + half) or 0) + T.measure(fH, t.title or "")
    local w = math.max(math.floor(T.cell * 3.6), headW)
    for _, r in ipairs(t.rows) do w = math.max(w, T.measure(fT, r.l) + pad * 2 + T.measure(fT, r.v)) end
    local note = t.lines
    for _, ln in ipairs(note) do w = math.max(w, T.measure(fS, ln)) end
    w = math.min(maxW, w)
    local barH = math.max(3, math.floor(T.cell * 0.08))
    local body = #t.rows > 0 or #note > 0
    local h = cell
    if body then h = h + half + 1 + half end
    for i, r in ipairs(t.rows) do
        h = h + tH + (r.frac and (2 + barH) or 0) + (i < #t.rows and half or 0)
    end
    if #note > 0 then h = h + (#t.rows > 0 and half or 0) + #note * sH end
    local W, H = w + (frame + pad) * 2, h + (frame + pad) * 2
    -- above the panel, over the middle of the thing; kept on the screen
    local r = self.tipRect
    local ax = self:getAbsoluteX()
    local sw = self.demo and getCore():getScreenWidth() or (getPlayerScreenLeft(self.playerNum or 0) + getPlayerScreenWidth(self.playerNum or 0))
    local x = math.floor((r and (r.x + r.w / 2) or self.W / 2) - W / 2)
    x = clamp(x, pad - ax, sw - pad - ax - W)
    local k = 1 - (1 - self.tipK) * (1 - self.tipK)
    local y = math.floor(-H - pad + (1 - k) * math.floor(T.cell * 0.2))
    local ta = a * self.tipK
    T.rect(self, x, y, W, H, C.window, 0.97 * ta)
    T.tileFrame(self, x, y, W, H, C.accent, ta)
    local ix, iy = x + frame + pad, y + frame + pad
    local tx = ix
    if t.icon then
        T.rect(self, ix, iy, cell, cell, C.cell, ta)
        T.tileFrame(self, ix, iy, cell, cell, C.tileEdge, ta)
        local is = math.floor(cell * 0.76 + 0.5)
        pic(self, sized(t.icon, is), ix + math.floor((cell - is) / 2), iy + math.floor((cell - is) / 2), is, is, C.text, ta)
        tx = ix + cell + half
    end
    T.inkLeft(self, T.fit(t.title or "", fH, ix + w - tx), tx, iy, cell, C.bright, fH, ta)
    local yy = iy + cell
    if body then
        yy = yy + half
        T.rect(self, ix, yy, w, 1, C.border, ta)
        yy = yy + 1 + half
    end
    for i, rw in ipairs(t.rows) do
        T.text(self, T.fit(rw.l, fT, w), ix, yy, rw.v == "" and rw.c or C.dim, fT, ta)
        if rw.v ~= "" then T.textRight(self, rw.v, ix + w, yy, rw.c, fT, ta) end
        yy = yy + tH
        if rw.frac then
            yy = yy + 2
            T.rect(self, ix, yy, w, barH, C.cell, ta)
            local fw = math.floor(w * clamp(rw.frac, 0, 1) + 0.5)
            if fw > 0 then T.rect(self, ix, yy, fw, barH, rw.c, ta) end
            yy = yy + barH
        end
        if i < #t.rows then yy = yy + half end
    end
    if #note > 0 then
        if #t.rows > 0 then yy = yy + half end
        for _, ln in ipairs(note) do
            T.text(self, ln, ix, yy, C.dim, fS, ta)
            yy = yy + sH
        end
    end
end

-- What the controls do ----------------------------------------------------------------

--- The game's dashboard's own handler (other mods' changes to them stay in force).
function D:game(fn)
    if self.demo then
        self.demo:press(fn)
        return
    end
    local vd, f = self.vdash, ISVehicleDashboard[fn]
    if vd and f then
        vd.vehicle = self.vehicle
        f(vd)
    end
end

function D:act(id, right)
    local v = self.vehicle
    if not v or (getGameSpeed() == 0 and not self.demo) then return end
    self.press[id] = getTimestampMs()
    -- (a demo: the road's part - the cruise, a bump - is its pretend car's)
    if self.demo and self.demo:act(id, right, self) then return end
    if id == "lights" then self:game("onClickHeadlights")
    elseif id == "doors" then self:game("onClickDoors")
    elseif id == "trunk" then self:game("onClickTrunk")
    elseif id == "ign" then
        -- the key: in the lock a click turns it (START, or back to stop the engine),
        -- a right click takes it out; out, a click puts it in; hot-wired, a click
        -- joins the wires (or pulls them apart)
        if right then
            if v:isKeysInIgnition() and not v:isEngineRunning() and not v:isEngineStarted() then self:game("onClickKeys") end
        elseif v:isKeysInIgnition() or v:isHotwired() or v:isEngineRunning() then
            self:game("onClickEngine")
        else
            self:game("onClickKeys")
        end
    elseif id == "temp" then self:heaterSet(false, right and -1 or 1, true)
    elseif id == "heater" then
        if right then self:game("onClickHeater") else self:heaterSet(true, 0) end
    else
        self:radioAct(id, right)
    end
end

--- The heater as the game's heater window sets it: on / off, its knob a place on
--- (`wrap`: round past the last place, as a click; the wheel stops at the ends).
function D:heaterSet(toggle, step, wrap)
    local v = self.vehicle
    local h = v:getPartById("Heater")
    if not h or not (v:isEngineRunning() or v:isKeysInIgnition()) then return end
    local md = h:getModData()
    local on, temp = md.active == true, md.temperature or 0
    if toggle then
        on = not on
        getSoundManager():playUISound("VehicleACButton")
    else
        local i = tempIndex(temp) + step
        if wrap then
            if i > #TEMPS then i = 1 elseif i < 1 then i = #TEMPS end
        else
            i = clamp(i, 1, #TEMPS)
        end
        if TEMPS[i] == temp then return end
        temp = TEMPS[i]
        getSoundManager():playUISound("VehicleACSetTemperature")
    end
    if self.demo then self.demo:heater(on, temp) return end
    sendClientCommand(self.character, "vehicle", "toggleHeater", {on = on, temp = temp})
end

--- The radio's controls (KnoxCarRadio, the player's music).
function D:radioAct(id, right)
    local MM = self.MM
    if not MM.carHas() then return end
    local now = getTimestampMs()
    local sm = getSoundManager()
    local tape = MM.theme() == "mine"
    if id == "vol" then
        sm:playUISound("VehicleRadioButton")
        if right then MM.carOpenWindow() else MM.carBroadcastToggle() end
        return
    elseif id == "display" then
        if not self.demo then self.cardOpen = not self.cardOpen end
        sm:playUISound("VehicleRadioButton")
        return
    elseif id == "tape" or id == "slot" then
        if tape and id == "tape" then return end
        self:insertTape(now)
        return
    elseif id == "eject" then
        if tape then
            -- the tape out: the broadcast again; the tape's choice kept for next time
            sm:playUISound("VehicleRadioButton")
            if not self.demo then T.settings["car.music.tape"] = T.settings["car.music"] end
            MM.choose("game")
            self.tapeOut = true
        end
        return
    end
    -- (switched off or without power its keys do nothing, as a real set's)
    if not MM.carAllowed() then return end
    sm:playUISound("VehicleRadioButton")
    if id == "fm" then
        if tape then MM.choose("game") end
    elseif id == "tune" then
        if not tape then self:seek(1, now) end
    elseif id == "seekL" or id == "seekR" then
        local dir = id == "seekR" and 1 or -1
        if tape then self:wind(dir * 10000) else self:seek(dir, now) end
    elseif PRESET[id] then
        local i = PRESET[id]
        if tape then
            if i == 1 then MM.prev() elseif i == 2 then MM.next() elseif i == 3 then MM.toggleShuffle() elseif i == 4 then MM.cycleRepeat() end
        elseif MM.stations() and MM.list[i] then
            self.seekFrom, self.seekAt = MM.carChannel(), now
            MM.play(i)
        end
    end
end

--- The tape in: the player's music (the folder chosen last time), the set on.
function D:insertTape(now)
    local MM = self.MM
    if not MM.available("mine") then
        self.noTapeAt = now
        return
    end
    getSoundManager():playUISound("VehicleRadioButton")
    local back = not self.demo and T.settings["car.music.tape"] or nil
    MM.choose((back and string.find(back, "^mine")) and back or "mine")
    if not MM.carOn() then MM.carBroadcastToggle() end
    self.tapeOut = false
end

--- To the next (previous) station on the air; the display runs its figures there.
function D:seek(dir, now)
    local MM = self.MM
    self.seekFrom, self.seekAt = MM.carChannel(), now
    if dir > 0 then MM.next() else MM.prev() end
end

--- The track wound by ms (ten seconds a press). (A demo's tape has no track to wind:
--- the player's own one is the camp radio's there.)
function D:wind(ms)
    if self.demo or not (knoxMusicPosition and knoxMusicSeek and knoxMusicLength) then return end
    local len = knoxMusicLength() or 0
    if len <= 0 then return end
    knoxMusicSeek(clamp((knoxMusicPosition() or 0) + ms, 0, len - 500))
end

--- The wheel over a knob: the headlights (up on, down off - the author, 2026-10-21),
--- the volume, the tuning (0.2 MHz a step; with the tape: the track back or on),
--- the heater.
function D:wheel(id, del)
    local MM, R = self.MM, self.R
    local dir = del < 0 and 1 or -1
    if self.demo then
        if self.demo:wheel(id, del) then return end
    elseif getGameSpeed() == 0 then
        return
    end
    if id == "temp" then
        self:heaterSet(false, dir, false)
        return
    elseif id == "lights" then
        local on = self.vehicle and self.vehicle:getHeadlightsOn()
        if (dir > 0) ~= (on == true) then self:act("lights", false) end
        return
    end
    if not MM.carHas() or not MM.carAllowed() then return end
    if id == "vol" then
        MM.setVol(clamp(MM.vol() + dir / 30, 0, 1))
        self.volAt = getTimestampMs()
    elseif id == "display" then
        -- the wheel over the display: the next (previous) station on the air, with
        -- the tape the next (previous) track (the author, 2026-10-21)
        if MM.theme() == "mine" then
            if dir > 0 then MM.next() else MM.prev() end
        else
            self:seek(dir, getTimestampMs())
        end
    elseif id == "tune" then
        self.tuneT = self.tuneT + dir * 18
        if MM.theme() == "mine" then
            if dir > 0 then MM.next() else MM.prev() end
            return
        end
        local d = R.data and R.data()
        if not d then return end
        local f = clamp(d:getChannel() + 200 * dir, d:getMinChannelRange(), d:getMaxChannelRange())
        self.seekFrom = nil
        MM.carTune(f)
    end
end

-- The mouse ---------------------------------------------------------------------------

--- A control's doing; a demo's guarded - an error there is a line in console.txt,
--- never the game's error window over the news (the author, 2026-10-21).
function D:run(f, a, b)
    if not self.demo then return f(self, a, b) end
    local ok, err = pcall(f, self, a, b)
    if not ok then print("[Knox] the news' dashboard: " .. tostring(err)) end
end

--- A demo's press off its shown part goes to the window it stands in (the news).
function D:toHost(fn, x, y)
    local h = self.host
    if not (self.demo and h and h[fn]) or self:inClip(x, y) then return false end
    h[fn](h, x + self:getX(), y + self:getY())
    return true
end

function D:onMouseDown(x, y)
    if self:toHost("onMouseDown", x, y) then return true end
    self.down = (self.hot and (CLICKS[self.hot] or (self.demo and KnoxDashDemo.clicks[self.hot]))) and self.hot or nil
    return true
end

function D:onMouseUp(x, y)
    if self:toHost("onMouseUp", x, y) then return true end
    local id = self.hot
    if id and self.down == id then self:run(self.act, id, false) end
    self.down = nil
    return true
end

function D:onMouseUpOutside(x, y) self.down = nil return true end

function D:onRightMouseDown(x, y)
    if self:toHost("onRightMouseDown", x, y) then return true end
    self.rdown = (self.hot and (CLICKS[self.hot] or (self.demo and KnoxDashDemo.clicks[self.hot]))) and self.hot or nil
    return true
end

function D:onRightMouseUp(x, y)
    if self:toHost("onRightMouseUp", x, y) then return true end
    local id = self.hot
    if id and self.rdown == id then self:run(self.act, id, true) end
    self.rdown = nil
    return true
end

function D:onMouseWheel(del)
    local id = self.hot
    if id and (WHEELS[id] or (self.demo and KnoxDashDemo.wheels[id])) then
        self:run(self.wheel, id, del)
    elseif self.demo and self.host and self.host.onMouseWheel then
        -- (a demo off its knobs: the wheel scrolls the news it stands in)
        return self.host:onMouseWheel(del)
    end
    return true
end

-- A live panel in a news post ----------------------------------------------------------
-- (the author, 2026-10-21: "players should see and feel how it works", the way the
-- mockup let one press everything) - the panel itself, on a pretend car
-- (KnoxDashDemo), placed by the window it stands in each frame (hostAt). It draws and
-- takes the mouse only in that window's view (`clip`): its body scrolls under the title.

--- A demo panel: kind "sedan" or "pickup", `hot` - hot-wired.
function D.makeDemo(kind, hot)
    local d = D:new()
    d:initialise()
    d:instantiate()
    local demo = KnoxDashDemo.new(kind, hot)
    d.demo = demo
    d.vehicle, d.character, d.playerNum = demo.car, demo.chr, 0
    d.MM, d.R = demo.mm, demo.r
    d.body = demo.kind == "pickup" and PICKUP or SEDAN
    d.gearCount = 5
    d.k = 1
    -- (the key already in, as when one sits down in a car with it: no sound)
    if demo.keyIn then d.keyVis, d.keyAng = 1, KEY_ON end
    d.wasKey = demo.keyIn
    d.clip, d.clipBox = {0, 0, 0, 0}, {0, 0, 0, 0}
    return d
end

--- How big the demo is (its scale is the screen's, as the real panel's), no wider
--- than maxW.
function D:demoSize(maxW)
    self.maxW = maxW
    self:layout()
    return self.W, self.H
end

--- The demo of a news post's "@dash <sedan|pickup> [hot]" line in a window that shows
--- news: made once per window and post line (`key`), kept for its later frames.
function D.newsDemo(host, key, kind, hot)
    host.knoxDemos = host.knoxDemos or {}
    local d = host.knoxDemos[key]
    if not d then
        d = D.makeDemo(kind, hot)
        host.knoxDemos[key] = d
    end
    return d
end

--- Each frame of the window it stands in: at x, y of `host`, shown in its view
--- {x, y, w, h} (the host's coordinates). A demo not placed for a moment hides.
function D:hostAt(host, x, y, view)
    if self.host ~= host then
        host:addChild(self)
        self.host = host
    end
    if self.broken then
        self:setVisible(false)
        return
    end
    self:layout()
    self:setX(x)
    self:setY(y)
    self:setWidth(self.W)
    self:setHeight(self.H)
    local c = self.clip
    c[1], c[2], c[3], c[4] = view[1] - x, view[2] - y, view[3], view[4]
    self.placedAt = getTimestampMs()
    self:setVisible(y + self.H > view[2] and y < view[2] + view[4])
end

--- Is a point of the panel in the part of it that shows? (Always, but a demo's.)
function D:inClip(x, y)
    local c = self.demo and self.clip
    if not c then return true end
    return x >= c[1] and y >= c[2] and x < c[1] + c[3] and y < c[2] + c[4]
end

--- Clip to a box, and back. The game's clips nest (UIElement: each one a level of
--- the stencil inside the last, a clear takes one level off): in a demo, already
--- clipped to its view, the box is a level inside it, and taking it off the box is
--- painted back to the view's level (repaintStencilRect, as the game's lists do) -
--- set again instead, everything after the first figure window was drawn inside it
--- only (the author, 2026-10-21: the radio, the key, the needles were gone).
function D:clipTo(x, y, w, h)
    local c = self.demo and self.clip
    if c then
        local x2, y2 = math.min(x + w, c[1] + c[3]), math.min(y + h, c[2] + c[4])
        x, y = math.max(x, c[1]), math.max(y, c[2])
        w, h = math.max(0, x2 - x), math.max(0, y2 - y)
        local b = self.clipBox
        b[1], b[2], b[3], b[4] = x, y, w, h
    end
    self:setStencilRect(x, y, w, h)
end

function D:unclip()
    self:clearStencilRect()
    if self.demo then
        local b = self.clipBox
        self:repaintStencilRect(b[1], b[2], b[3], b[4])
    end
end

--- A demo's frame: as the real panel's, where its window put it, clipped to its view.
function D:demoFrame(now, dt)
    if self.broken or now - (self.placedAt or 0) > 150 then
        self:setVisible(false)
        return
    end
    self:layout()
    self.k = 1
    local c = self.clip
    self:setStencilRect(c[1], c[2], c[3], c[4])
    local ok, err = pcall(function()
        local st = self:read(now)
        self:move(st, now, dt)
        self:draw(st, now, dt)
    end)
    self:clearStencilRect()
    if not ok then
        print("[Knox] the news' dashboard stopped: " .. tostring(err))
        self.broken = true
        self:setVisible(false)
    end
end

-- In and out ----------------------------------------------------------------------------

function D.show(vdash, vehicle)
    local d = D.instance
    if not d then
        d = D:new()
        d:initialise()
        d:instantiate()
        D.instance = d
    end
    local fresh = d.vehicle ~= vehicle or not d.shownAt
    d.vdash, d.vehicle, d.character, d.playerNum = vdash, vehicle, vdash.character, vdash.playerNum
    if fresh then
        d:reset()
        d.body = bodyFor(vehicle)
        local ok, n = pcall(function() return vehicle:getScript():getGearRatioCount() end)
        d.gearCount = clamp((ok and tonumber(n)) or 5, 1, 6)
        d.shownAt, d.goneAt = getTimestampMs(), nil
        -- (got in with the key already in: it is there, turned, no sound)
        local keyIn = vehicle:isKeysInIgnition() and not vehicle:isHotwired()
        if keyIn then d.keyVis, d.keyAng = 1, KEY_ON end
        d.wasKey = keyIn or ((vehicle:isEngineRunning() or vehicle:isStarting()) and not vehicle:isHotwired())
        d.wasPower = vehicle:isKeysInIgnition() or vehicle:isEngineRunning()
        if d.wasPower then d.lit = 1 end
    end
    if not d.inUI then
        d:addToUIManager()
        d.inUI = true
    end
    d:setVisible(ISUIHandler.allUIVisible ~= false and not (KnoxScreen and KnoxScreen.instance and KnoxScreen.instance:getIsVisible()))
    R.enter(vdash.character, vehicle)
    if fresh then
        -- (the knobs where they stand, not turning to there; the volume read in the
        -- car's context, R.enter's)
        d.volKnob.x = -135 + 270 * clamp(MM.vol(), 0, 1)
        local h = vehicle:getPartById("Heater")
        d.tempKnob.x = TEMP_DEG[tempIndex(h and h:getModData().temperature or 0)]
    end
end

--- Out of the car (the game calls this every tick while on foot: nothing to do then).
function D.hideFor(vdash)
    local d = D.instance
    if not d or not d.shownAt then return end
    if vdash and d.vdash ~= vdash then return end
    d.shownAt = nil
    d.goneAt, d.goneK = getTimestampMs(), d.k
    d.vehicleGone = d.vehicle
    d.cardOpen = false
    R.leave()
    if KnoxRadioCard and KnoxRadioCard.hide then KnoxRadioCard.hide() end
end

-- In place of the game's dashboard ------------------------------------------------------

local function knoxFor(vdash)
    return Knox ~= nil and Knox.forPlayer ~= nil and Knox.forPlayer(vdash.playerNum, "dashboard")
end

if not ISVehicleDashboard.knoxHooked then
    ISVehicleDashboard.knoxHooked = true
    local setVehicle = ISVehicleDashboard.setVehicle
    function ISVehicleDashboard:setVehicle(vehicle)
        if not knoxFor(self) then
            D.hideFor(self)
            return setVehicle(self, vehicle)
        end
        -- the game's panel keeps its car (other code reads it) but is never shown
        self.vehicle = vehicle
        self:removeFromUIManager()
        if vehicle then D.show(self, vehicle) else D.hideFor(self) end
    end
end

-- (for the self-test and the bench: the two bodies and how a car gets one)
D.SEDAN, D.TRUCK, D.PICKUP, D.bodyFor = SEDAN, TRUCK, PICKUP, bodyFor

return KnoxDashboard
