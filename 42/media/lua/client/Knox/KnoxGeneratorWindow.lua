-- The generator in Knox's look, in place of the game's info window (ISGeneratorInfoWindow):
-- the window is the machine itself - a portable generator of the early 90s, mockup 18
-- approved by the author 2026-10-22 (.claude\mockups\generator_v18.html; its history in
-- ROADMAP, "Generator window"). Its sizes, colours, places and motions are the mockup's.
--   the tank       KNOX POWER, the fuel gauge E-F (a needle on a spring); next to it the
--                  can's place: a click pours the fullest can of petrol carried, a can
--                  dragged from a Knox grid pours that one - a portion every 250 ms, a
--                  click again stops it
--   the panel      ENGINE: the switch OFF / RUN and the starter cord - hold its handle
--                  and jerk it (the attempt when the cord reaches 85 % of its length, by
--                  the speed of its last ~90 ms); LOAD: the needle (L/h) and its window;
--                  LEFT: the hour meter - hours with tenths on the fuel at this load; the
--                  lamps RUN / OIL (worn: blinks under 40 %) / CO GAS (running indoors);
--                  OUTLETS 120 V: a plug for each kind of thing it powers (its name and
--                  use in the tip); the HOUSE lever (connected or not)
-- While it is open the character crouches at the generator (KnoxGeneratorUse, one
-- endless action) and everything above is done at once (KnoxGenerator.act - the start's
-- chance to fail is Knox's: a worn generator doesn't always start). Closing the window
-- ends the action; walking off ends both. Running, the body shakes and its scales are lit.
-- The body's pictures are cut from the mockup (tools\make_generator.ps1 -> media\ui\
-- knoxgen); the text is Knox's font, spaced and centred by its pixels as the mockup's.
-- Nothing new is made in render: texts are laid out when they change.
-- Module "generator" (the Modules page): off, the game's own window.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxGenerator"
require "Knox/KnoxGenDemo"

KnoxGeneratorWindow = ISPanel:derive("KnoxGeneratorWindow")
local W = KnoxGeneratorWindow
local T = KnoxTheme
local inRect = T.inRect

W.instance = nil
W.lastX, W.lastY = nil, nil

local function hex(s)
    return {r = tonumber(string.sub(s, 2, 3), 16) / 255, g = tonumber(string.sub(s, 4, 5), 16) / 255,
        b = tonumber(string.sub(s, 6, 7), 16) / 255}
end
-- the mockup's colours (the sand is the skin's: T.color.accent, lit - brighter)
local DIM, LIT = hex("#8f9289"), hex("#e6ddb8")
local BRIGHT, DIGIT = hex("#ece8d8"), hex("#f2ecd8")
local RED, GREEN = hex("#be463c"), hex("#6ca050")
local CORD = hex("#9b9d92")
local LVR_FILL, LVR_EDGE = hex("#141414"), hex("#2a2e2e")
local WHITE = {r = 1, g = 1, b = 1}
local LAMPS = {
    {id = "run", on = hex("#7fc35e"), off = hex("#1d2a1b"), y = 296},
    {id = "oil", on = hex("#e0b452"), off = hex("#2b2416"), y = 324},
    {id = "co", on = hex("#e0584c"), off = hex("#2c1715"), y = 352},
}
-- the sand lit from behind, as the mockup's #d4c38a -> #f3e3a6
local LIT_K = {r = 0xf3 / 0xd4, g = 0xe3 / 0xc3, b = 0xa6 / 0x8a}

local FC, LC, KC = {450, 104}, {272, 284}, {138, 267}   -- the fuel gauge's, the load's, the switch's middles
-- The tank, its gauge and the can's place stand 9 lower than the mockup's (the author,
-- 2026-10-22, in the game: the same room above the tank as below it - it was 3 and 21).
-- The body's pictures have it (tools\gen\bake.js); the gauge's marks and needle are cut
-- where the mockup has them and drawn TANK_DY lower.
local TANK_DY = 9
-- The load's scale: the game's raw load 0 .. 1 (a house about 0.3, a washer and dryer
-- 0.9) times the sandbox's fuel rate, as its fuel goes (0.1 by default: 0 .. 0.1 L/h).
-- (2026-10-22: 0 .. 1 L/h flat left the needle by the zero - a house took 0.03 L/h.)
local LOAD_RAW = 1.0
local function fuelRate()
    local v = SandboxVars and tonumber(SandboxVars.GeneratorFuelConsumption)
    return (v and v > 0) and v or 1
end
local WALK_DIST = 3        -- as the stove's window
-- the cord: from its hole, 18 units at rest, 100 at most; the attempt at 85 % of it
-- at 0.35 units a ms (FAST in the mockup); 6 links
local A = {x = 138, y = 334}
local L0, LMAX, END, FAST, NP = 18, 100, 0.85, 0.35, 6
local HIST = 16
local MAX_MINS = 9999 * 6   -- (the hour meter: 999,9 hours at most)
-- the counter's drums
-- the hour meter's drums: three of hours, the point, the tenths' (light, a dark figure)
local DX, MY, DW, DH = {379, 398, 417, 445}, 219, 16, 26
local TENTH = hex("#1c1e1e")
-- the pictures' boxes in units, as make_generator.ps1 cuts them (change both together)
local BOX = {
    fticks = {426, 80, 48, 48}, lticks = {213, 225, 118, 118},
    fneedle = {445, 81, 10, 46}, lneedle = {265, 228, 14, 112},
    knob = {110, 239, 56, 56}, lever = {544, 346, 26, 26}, handle = {-34, -9, 68, 28},
    plug = {499, 218, 34, 49}, lampdisc = {382, 288, 16, 16}, icon = {501, 220, 28, 26},
}
local PICS = {"under", "over", "fticks", "fticks_red", "lticks", "fneedle", "lneedle", "knob", "knobmark",
    "lever", "handle", "plug", "lampdisc", "icon_fridge", "icon_bulb", "icon_stove", "icon_plug"}
local KS = {80, 100, 133, 160, 200, 250}
-- the whole window bigger than the mockup's units (the author, 2026-10-22: "small" - 875 x 625
-- at 1080p, 1167 x 833 at 1440p; 4K takes the k250 pictures)
local SCALE = 1.25
local CAN = {550, 66 + TANK_DY, 64, 80}
local HOUSE = {488, 330, 96, 50}
-- the cross: 22 units, 6 px from the right edge as the TV's, its middle 16 units down
-- (it stood 28 units in, "not by the window's end" - the author, 2026-10-22)
local CLOSE_U, CLOSE_CY = 22, 16
-- the shake while it runs: the mockup's keyframes, 80 ms round
local SHAKE = {{0, 0}, {0.7, -0.5}, {-0.6, 0.4}, {0.4, 0.7}, {0, 0}}

-- the casing's outline in the mockup (its stroked rounded rect): inside it the window's
-- plate shows through - a news post's demo fills it itself
local CASING = {26, 42, 648, 420, 26}

--- A rounded rectangle filled (px): the middle in two rects, the corners row by row.
local function roundFill(ui, x, y, w, h, r, c)
    r = math.floor(r + 0.5)
    T.rect(ui, x, y + r, w, h - 2 * r, c)
    for i = 0, r - 1 do
        local dy = r - i - 0.5
        local inset = r - math.sqrt(math.max(0, r * r - dy * dy))
        local ix = math.floor(inset + 0.5)
        T.rect(ui, x + ix, y + i, w - 2 * ix, 1, c)
        T.rect(ui, x + ix, y + h - 1 - i, w - 2 * ix, 1, c)
    end
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function P(c, r, a)
    local rad = math.rad(a)
    return c[1] + r * math.sin(rad), c[2] - r * math.cos(rad)
end

-- Words ---------------------------------------------------------------------------------

local function tx(key, ...) return getText("IGUI_KnoxGen_" .. key, ...) end

--- L/h as words: three places under 0.1 (the game's rates are that small: 0.03 a house
--- at the default rate), two above; `fixed` keeps its zeros (the window's number doesn't
--- change width), else they go ("0,025", "0,05", "0,1"). `dec`: the language's point.
function W.number(v, dec, fixed)
    local s = string.format(v < 0.1 and "%.3f" or "%.2f", v)
    if not fixed then
        s = string.gsub(string.gsub(s, "0+$", ""), "%.$", "")
    end
    return (string.gsub(s, "%.", dec))
end

--- A font of the mockup's weight at `px`: Knox's (500 body, 600 head, 700 title), or the
--- game's for a language Knox's atlases can't write.
local function fontFor(weight, px)
    local style = weight == 700 and "title" or (weight == 500 and "body" or "head")
    if T.javaFonts then return T.makeFont(style, px), style end
    return T.gameFontUpTo(px * 1.3) or UIFont.Small, nil
end

--- Is a font's atlas read? (Knox's load in the background; the game's are always there.)
local function fontReady(font)
    return type(font) ~= "table" or knoxFontReady(font.style, font.size) == true
end

--- A caption laid out as the mockup's place(): letter by letter with its spacing, in the
--- middle of its pixels sideways (the spacing after the last letter not counted), up and
--- down by a capital's height (a number by its own), made smaller to fit `maxw`.
--- spec: {text, cx, cy, fs, weight, ls, maxw} in units; fills spec.chars, xs, dx, dy, font.
local function lay(spec, s)
    local text = spec.text or ""
    local fs, ls = spec.fs, spec.ls or 0
    for _ = 1, 12 do
        local px = fs * s
        local font, style = fontFor(spec.weight or 600, px)
        -- (Knox's "head" has its spacing in its letters already: about 0.05 em)
        local extra = ls * s
        local track = style == "head" and math.floor(0.05 * math.floor(px + 0.5) + 0.5) or 0
        extra = extra - track
        -- a space as wide as the mockup's (a quarter of the size and the spacing): the
        -- atlases' 3 px read as none between spaced capitals ("РОЗЕТКИ120 В", "СЕТЬДОМА" -
        -- the author, 2026-10-22)
        local space = math.floor(0.26 * px + 0.5) + track
        extra = math.max(0, extra)
        local chars, xs = {}, {}
        if ls == 0 then
            chars[1], xs[1] = text, 0
        else
            local x = 0
            for i = 1, #text do
                local ch = string.sub(text, i, i)
                chars[i], xs[i] = ch, x
                x = x + (ch == " " and space or T.measure(font, ch)) + extra
            end
        end
        local n = #chars
        local left, right = 0, 0
        if n > 0 then
            local l1 = T.inkBox(font, chars[1])
            local _, _, rn = T.inkBox(font, chars[n])
            left, right = xs[1] + l1, xs[n] + rn
        end
        local digits = string.find(text, "^%d$") ~= nil   -- (the mockup: a lone digit by its own pixels)
        local _, top, _, bottom = T.inkBox(font, digits and text or "H")
        if not spec.maxw or right - left <= spec.maxw * s or (px <= 10 and ls == 0) then
            spec.chars, spec.xs, spec.font = chars, xs, font
            spec.dx, spec.dy = -(left + right) / 2, -(top + bottom) / 2
            spec.inkW = right - left
            return spec
        end
        if px <= 10 then
            ls = 0   -- (Knox's atlases go no smaller than 10 px: the spacing goes first)
        else
            local k = spec.maxw * s / (right - left)
            fs, ls = fs * math.min(k, 0.97), ls * math.min(k, 0.97)
        end
    end
    return spec
end

--- Draw a laid out caption at its place, moved by the shake ox, oy (px).
local function say(ui, spec, ox, oy, c, a)
    if not spec.chars or a <= 0.003 then return end
    local s = ui.s
    local bx = math.floor(ox + spec.cx * s + spec.dx + 0.5)
    local by = math.floor(oy + spec.cy * s + spec.dy + 0.5)
    for i = 1, #spec.chars do
        T.drawText(ui, spec.chars[i], bx + spec.xs[i], by, c.r, c.g, c.b, a, spec.font)
    end
end

-- Pictures -------------------------------------------------------------------------------

local function quad(ui, t, x1, y1, x2, y2, x3, y3, x4, y4, c, a)
    if not t or a <= 0.003 then return end
    local ax, ay = ui:getAbsoluteX(), ui:getAbsoluteY()
    ui.javaObject:DrawTexture(t, ax + x1, ay + y1, ax + x2, ay + y2, ax + x3, ay + y3, ax + x4, ay + y4, c.r, c.g, c.b, a)
end

--- A picture over the units' box b, moved by ox, oy px.
local function pic(ui, t, b, ox, oy, c, a)
    if not t then return end
    local s = ui.s
    ui:drawTextureScaled(t, ox + b[1] * s, oy + b[2] * s, b[3] * s, b[4] * s, a or 1, c.r, c.g, c.b)
end

--- The same over x, y, w, h (units): no box table made for a picture placed each frame.
local function picAt(ui, t, x, y, w, h, ox, oy, c, a)
    if not t then return end
    local s = ui.s
    ui:drawTextureScaled(t, ox + x * s, oy + y * s, w * s, h * s, a or 1, c.r, c.g, c.b)
end

--- A picture whose box b (units, as cut) turns by deg (clockwise, as SVG's rotate) round
--- px, py (units), then moves by mx, my (units) and ox, oy (px).
local function turned(ui, t, b, px, py, deg, mx, my, ox, oy, c, a)
    if not t then return end
    local s = ui.s
    local r = math.rad(deg)
    local cs, sn = math.cos(r), math.sin(r)
    local l, tp = b[1] - px, b[2] - py
    local rr, bt = l + b[3], tp + b[4]
    local cx, cy = ox + (px + mx) * s, oy + (py + my) * s
    quad(ui, t,
        cx + (l * cs - tp * sn) * s, cy + (l * sn + tp * cs) * s,
        cx + (rr * cs - tp * sn) * s, cy + (rr * sn + tp * cs) * s,
        cx + (rr * cs - bt * sn) * s, cy + (rr * sn + bt * cs) * s,
        cx + (l * cs - bt * sn) * s, cy + (l * sn + bt * cs) * s, c, a)
end

local barTex = nil
--- A soft line x0,y0 -> x1,y1 (px), th px thick (the dashboard's bar picture).
local function bar(ui, x0, y0, x1, y1, th, c, a)
    if barTex == nil then barTex = getTexture("media/ui/knoxdash/bar.png") or false end
    local dx, dy = x1 - x0, y1 - y0
    local l = math.sqrt(dx * dx + dy * dy)
    if l < 0.01 or not barTex then return end
    local h = (th + 1) / 2
    local nx, ny = -dy / l * h, dx / l * h
    -- (a little longer both ways: the joints of a bent cord without gaps)
    local ex, ey = dx / l * th * 0.4, dy / l * th * 0.4
    quad(ui, barTex, x0 - ex + nx, y0 - ey + ny, x1 + ex + nx, y1 + ey + ny, x1 + ex - nx, y1 + ey - ny,
        x0 - ex - nx, y0 - ey - ny, c, a)
end

-- The generator ---------------------------------------------------------------------------

--- The kinds of things a generator powers, as the game lists them ("Fridge", "Lights x4",
--- each "(0.13 L/h)" after it): {name, use (L/h), icon}. The icon by words in the name,
--- the language's own (IGUI_KnoxGen_Words_*: parts of words, by commas - the game reads
--- Lua files as single bytes, so no Cyrillic here); anything else - a plug.
-- (English words too, for mods' things named in English whatever the language)
local WORDS = nil
local ENGLISH = {fridge = ",fridge,freezer", stove = ",stove,oven,microwave"}
local function words()
    if WORDS then return WORDS end
    WORDS = {}
    for _, kind in ipairs({"fridge", "stove"}) do
        local list = {}
        for w in string.gmatch(getText("IGUI_KnoxGen_Words_" .. kind) .. ENGLISH[kind], "[^,]+") do
            local low = T.lower(w)
            if low and low ~= "" then table.insert(list, low) end
        end
        table.insert(WORDS, {"icon_" .. kind, list})
    end
    return WORDS
end

local function iconOf(name)
    if name == getText("IGUI_Lights") then return "icon_bulb" end
    local low = T.lower(name) or ""
    for _, kind in ipairs(words()) do
        for _, w in ipairs(kind[2]) do
            if string.find(low, w, 1, true) then return kind[1] end
        end
    end
    return "icon_plug"
end

local function parseItems(list)
    local out = {}
    if not list then return out end
    for i = 0, list:size() - 1 do
        local line = tostring(list:get(i) or "")
        local name, use = string.match(line, "^(.-)%s*%(([%d%.,]+)[^%)]*%)%s*$")
        if not name then name, use = line, "0" end
        use = tonumber((string.gsub(use, ",", "."))) or 0
        local base = string.match(name, "^(.-)%s+x%d+$") or name
        table.insert(out, {name = name, use = use, icon = iconOf(base)})
    end
    return out
end

-- The window ----------------------------------------------------------------------------------

function W:new(player, gen)
    local o = ISPanel:new(0, 0, 700, 500)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.gen = gen
    o.background = false
    o.moveWithMouse = false
    o.s = 1
    -- the motions: needles on springs, the switch, the lever, the drums, the cord
    o.N = {a = -120, w = 0}
    o.F = {a = -60 + 120 * o:fuelFrac(), w = 0}
    o.knob = {a = o:switchOn() and 40 or -40, from = 0, to = 0, t0 = 0}
    o.LV = {x = gen:isConnected() and 0 or -43, from = 0, to = 0, t0 = 0}
    o.house = gen:isConnected()
    o.drums = {}
    for i = 1, 4 do o.drums[i] = {pos = 0, from = 0, to = 0, t0 = 0} end
    o.R = {}
    for i = 0, NP do
        local y = A.y + L0 * i / NP
        o.R[i] = {x = A.x, y = y, px = A.x, py = y}
    end
    o.L = L0
    o.histT, o.histL, o.histN = {}, {}, 0
    for i = 1, HIST do o.histT[i], o.histL[i] = 0, 0 end
    o.lastMs = getTimestampMs()
    o.itemsAt, o.items = 0, {}
    o.insideAt, o.inside = 0, false
    o.mins, o.minsAt = -1, 0
    o.dtext = {}   -- the texts that change, laid out when they do
    o.tipKey = nil
    o.dec, o.unit = tx("Decimal"), tx("PerHour")
    o.loadKey, o.loadText = nil, nil
    o.lampOn = {false, false, false}
    o.wantDrums = {0, 0, 0, 0}
    return o
end

function W:fuelFrac()
    local m = self.gen:getMaxFuel()
    return m > 0 and clamp(self.gen:getFuel() / m, 0, 1) or 0
end

--- The switch: ENGINE RUN is kept on the generator (the game has no such switch: a
--- running one is at RUN whatever was kept).
function W:switchOn()
    if self.gen:isActivated() then return true end
    return self.gen:getModData().knoxSwitch == true
end

--- Sizes from the screen's, as the dashboard's: a unit is SCALE px at 1080p (Knox's cell 48).
function W:layout()
    T.ensure()
    local s = math.max(0.6, T.cell / 48 * SCALE)
    -- (a news post's demo: no wider than the column it stands in)
    if self.maxW then s = math.min(s, self.maxW / 700) end
    if s == self.laidS and self.laidFonts == T.javaFonts then return end
    self.s, self.laidS, self.laidFonts = s, s, T.javaFonts
    self:setWidth(math.floor(700 * s + 0.5))
    self:setHeight(math.floor(500 * s + 0.5))
    local k = 200
    for _, kk in ipairs(KS) do
        if kk >= s * 100 * 0.97 then k = kk break end
    end
    self.tex = {}
    for _, name in ipairs(PICS) do
        self.tex[name] = getTexture("media/ui/knoxgen/" .. name .. "_k" .. k .. ".png")
    end
    -- the captions that stay (the mockup's text elements, its numbers)
    local e = {}
    e[1], e[2] = P(FC, 15, -95)
    e[2] = e[2] + TANK_DY
    local f = {}
    f[1], f[2] = P(FC, 15, 95)
    f[2] = f[2] + TANK_DY
    local L = {
        power = {text = "KNOX POWER", cx = 229, cy = 93 + TANK_DY, fs = 27, weight = 700, ls = 7, maxw = 266, sand = true},
        spec = {text = tx("Spec"), cx = 229, cy = 121 + TANK_DY, fs = 11, weight = 500, ls = 3, maxw = 266},
        E = {text = "E", cx = e[1], cy = e[2], fs = 9, red = true},
        F = {text = "F", cx = f[1], cy = f[2], fs = 9, sand = true, lit = true},
        -- (inside the face's black: 7 px in the mockup, Knox's smallest atlas is 10)
        fuel = {text = tx("Fuel"), cx = 450, cy = 118 + TANK_DY, fs = 7, ls = 1, maxw = 40, lit = true},
        off = {text = tx("Off"), cx = 104, cy = 220, fs = 9, ls = 1},
        run = {text = tx("Run"), cx = 174, cy = 220, fs = 9, ls = 1, sand = true, lit = true},
        house = {text = tx("House"), cx = 536, cy = 339, fs = 8, ls = 1, lit = true},
        hvOn = {text = tx("On"), cx = 520, cy = 359, fs = 9, ls = 1, green = true},
        hvOff = {text = tx("Off"), cx = 548, cy = 359, fs = 9, ls = 1},
    }
    local plates = {{88, 100, "Engine"}, {222, 100, "Load"}, {370, 100, "Left"}, {488, 96, "Outlets"}}
    for i, p in ipairs(plates) do
        L["plate" .. i] = {text = tx(p[3]), cx = p[1] + p[2] / 2, cy = 196, fs = 10, ls = 2, maxw = p[2] - 12, lit = true}
    end
    local lampKeys = {"LampRun", "LampOil", "LampCo"}
    for i, l in ipairs(LAMPS) do
        L["lamp" .. i] = {text = tx(lampKeys[i]), cx = 435, cy = l.y, fs = 9, ls = 1, maxw = 58, lit = true}
    end
    -- the load's scale: 0 .. loadMax L/h on its five big marks (0 / 0,025 / 0,05 /
    -- 0,075 / 0,1 at the default rate)
    local dec = tx("Decimal")
    self.loadMax = LOAD_RAW * (self.demo and self.demo.rate or fuelRate())
    for i = 0, 4 do
        local x, y = P(LC, 37, -120 + i * 60)
        L["num" .. i] = {text = W.number(self.loadMax * i / 4, dec), cx = x, cy = y, fs = 10, lit = true}
    end
    for _, spec in pairs(L) do lay(spec, s) end
    -- the scale's numbers inside its big marks (they begin 45 out): each moved in so its
    -- letters end 4 short of them along its own direction - "0,025" and "0,075" ran
    -- over the marks at 37 (the author, 2026-10-22)
    do
        local hf = L.num0.font
        local _, top, _, bottom = T.inkBox(hf, "H")
        local hh = (bottom - top) / s / 2
        for i = 0, 4 do
            local spec, a = L["num" .. i], -120 + i * 60
            local hw = (spec.inkW or 0) / s / 2
            local reach = math.abs(hw * math.sin(math.rad(a))) + math.abs(hh * math.cos(math.rad(a)))
            spec.cx, spec.cy = P(LC, math.min(37, 41 - reach), a)
        end
    end
    self.cap = L
    -- the order they are drawn in (no pairs() in render)
    self.order = {L.power, L.spec, L.E, L.F, L.fuel, L.off, L.run, L.plate1, L.plate2, L.plate3, L.plate4,
        L.lamp1, L.lamp2, L.lamp3, L.num0, L.num1, L.num2, L.num3, L.num4, L.house}
    -- what the counter counts, stamped under it (mockup 18)
    L.hours = lay({text = tx("Hours"), cx = 420, cy = 264.5, fs = 8, ls = 1, lit = true}, s)
    table.insert(self.order, L.hours)
    -- the drums' digits, each centred by its own pixels
    self.digit = {}
    for d = 0, 9 do
        self.digit[d] = lay({text = tostring(d), cx = 0, cy = 0, fs = 17}, s)
    end
    self.dtext = {}
    local cs = math.floor(CLOSE_U * s + 0.5)
    self.closeR = {self:getWidth() - cs - 6, math.floor(CLOSE_CY * s - cs / 2 + 0.5), cs, cs}
    self.tipR, self.tipOpts = {0, 0, 0, 0}, {fill = T.color.header, edge = T.color.accent, thick = true, color = BRIGHT}
    self.lit, self.litSand = {r = 0, g = 0, b = 0}, {r = 0, g = 0, b = 0}
    self.lampC = {r = 0, g = 0, b = 0}
    -- (a font still being read gives no ink box: its captions came out off centre in a
    -- news post's demo, laid out while the post opened and its smaller atlases were on
    -- their way - the author, 2026-10-22; laid out again until they are all there)
    local pending = false
    for _, spec in ipairs(self.order) do
        if not fontReady(spec.font) then pending = true end
    end
    if not fontReady(self.digit[0].font) then pending = true end
    if pending then self.laidS = nil end
end

--- A text that changes (the load, the +N): laid out again only when it does.
function W:dyn(key, text, cx, cy, fs, weight, maxw)
    local d = self.dtext[key]
    if d and d.text == text and d.cx == cx and d.cy == cy then return d end
    d = lay({text = text, cx = cx, cy = cy, fs = fs, weight = weight, maxw = maxw}, self.s)
    self.dtext[key] = d
    return d
end

-- Reading the generator ------------------------------------------------------------------------

--- The load the needle shows (L/h): running - the game's total (the sandbox's rate in it).
function W:load()
    if not self.gen:isActivated() then return 0 end
    return self.gen:getTotalPowerUsing() or 0
end

--- Minutes the fuel lasts at this load (stopped: at the load it had last, kept on it).
function W:minutesLeft()
    local gen = self.gen
    local use = gen:isActivated() and (gen:getTotalPowerUsing() or 0) or (tonumber(gen:getModData().knoxLoad) or gen:getTotalPowerUsing() or 0)
    if use <= 0 then return MAX_MINS end
    return clamp(math.floor(gen:getFuel() / use * 60), 0, MAX_MINS)
end

--- The things it powers (asked of the game once a second; kept on the generator so a
--- stopped one still shows its plugs).
function W:pollItems(now)
    if now < self.itemsAt then return end
    self.itemsAt = now + 1000
    local gen = self.gen
    local md = gen:getModData()
    if gen:isActivated() then
        local list = gen:getItemsPowered()
        local items = parseItems(list)
        local keep = {}
        for i, it in ipairs(items) do keep[i] = tostring(list:get(i - 1)) end
        local joined = table.concat(keep, "\n")
        if md.knoxPowered ~= joined then md.knoxPowered = joined end
        local use = gen:getTotalPowerUsing() or 0
        if use > 0 then md.knoxLoad = use end
        self.items = items
    else
        local list = {}
        for line in string.gmatch(md.knoxPowered or "", "[^\n]+") do table.insert(list, line) end
        self.items = parseItems({size = function() return #list end, get = function(_, i) return list[i + 1] end})
    end
    local sq = gen:getSquare()
    self.inside = sq ~= nil and not sq:isOutside() and sq:getBuilding() ~= nil
end

-- Doing things (at once, while the character works the generator: KnoxGenerator.act) -----------

local function petrolCans(player)
    local found = player:getInventory():getAllEvalRecurse(function(item)
        local fc = item:getFluidContainer()
        return fc ~= nil and fc:contains(Fluid.Petrol)
    end)
    return found
end

--- The endless action at this generator (KnoxGeneratorUse), if it is the one running.
function W:useAction()
    if self.demo then return nil end
    local q = ISTimedActionQueue.getTimedActionQueue(self.player)
    local a = q and q.queue and q.queue[1]
    if a and a.Type == "KnoxGeneratorUse" and a.generator == self.gen then return a end
    return nil
end

--- A command to the generator: its outcome at once alone; with others nil, and the
--- server's answer comes to onResult.
function W:send(cmd, args)
    local res = KnoxGenerator.act(self.player, self.gen, cmd, args)
    if res then self:onResult(cmd, res) end
    return res
end

function W:toggleSwitch()
    local gen = self.gen
    local on = not self:switchOn()
    gen:getModData().knoxSwitch = on
    if isClient() then gen:transmitModData() end
    self.knob.from, self.knob.to, self.knob.t0 = on and -40 or 40, on and 40 or -40, getTimestampMs()
    self.player:playSound("ToggleStove")   -- (a rotary switch's click: the game's stove knob)
    if not on and gen:isActivated() then self:send("stop") end
end

--- A jerk of the cord at `sp` units a ms.
function W:jerk(sp)
    local gen = self.gen
    -- (too slow, at OFF, dry, broken or not connected: the engine only turns over)
    if gen:isActivated() or sp < FAST or not self:switchOn() or gen:getFuel() <= 0 or gen:getCondition() <= 0
        or not gen:isConnected() then return end
    self:send("start")
end

--- What came of a command (at once alone; the server's answer with others).
function W:onResult(cmd, res)
    if cmd == "start" then
        if not res.ok and res.why == "fail" then
            -- (with others the server doesn't sound it: the game plays it here)
            if isClient() then self.gen:failToStart() end
            -- a jolt, as a stalled engine gives
            self.N.w, self.F.w = self.N.w + 4, self.F.w + 1
        end
    elseif cmd == "fuel" then
        if not res.ok or res.full or (tonumber(res.left) or 1) <= 0 then
            self:stopPour()
        end
    end
end

function W:toggleHouse()
    local gen = self.gen
    if gen:isActivated() then return end
    local plug = not gen:isConnected()
    if plug and not KnoxGenerator.canPlug(self.player) then return end
    self.player:playSound("LightSwitch")   -- (the lever's click)
    self:send("plug", {plug = plug})
end

--- Pour a can into the tank, a portion every 250 ms while the window is open: the one
--- given (dragged), else the fullest carried. A click on the can's place again stops it.
function W:refuel(item)
    if self.pour then
        self:stopPour()
        return
    end
    local gen = self.gen
    if gen:getFuel() >= gen:getMaxFuel() - 0.001 then return end
    if item then
        local fc = item:getFluidContainer()
        if not fc or not fc:contains(Fluid.Petrol) then return end
        -- (the can must be on the character: in the hands, the pockets, a bag worn)
        if not self.player:getInventory():containsRecursive(item) then return end
    else
        local cans = petrolCans(self.player)
        local most = 0
        for i = 0, cans:size() - 1 do
            local it = cans:get(i)
            local amount = it:getFluidContainer():getAmount()
            if amount > most then item, most = it, amount end
        end
        if not item then return end
    end
    self.pour = {id = item:getID(), next = 0}
    self.pourArgs = {id = item:getID(), amount = KnoxGenerator.POUR}
    self.pourSound = self.player:playSound("GeneratorAddFuel")
    local act = self:useAction()
    if act then act:pouring(item) end
end

function W:stepPour(now)
    local p = self.pour
    if not p or now < p.next then return end
    p.next = now + 250
    self:send("fuel", self.pourArgs)
end

function W:stopPour()
    if not self.pour then return end
    self.pour = nil
    local act = self:useAction()
    if act then act:pouring(nil) end
    if self.pourSound then self.player:stopOrTriggerSound(self.pourSound) end
    self.pourSound = nil
end

-- Motion -----------------------------------------------------------------------------------------

local function ease(k) return 1 - (1 - k) ^ 3 end

--- The drums to the time `m` (minutes): each turns on its own, the short way round.
function W:meterTo(m, now, instant)
    -- an hour meter (mockup 18, the author 2026-10-22: no modes, all of it a mechanism):
    -- hours with tenths, 000,0 .. 999,9 - a tenth is 6 minutes (10 L at 0.03 L/h: 333,3)
    local t = math.min(9999, math.floor(m / 6))
    local want = self.wantDrums
    want[1], want[2], want[3], want[4] = math.floor(t / 1000) % 10, math.floor(t / 100) % 10, math.floor(t / 10) % 10, t % 10
    for i, d in ipairs(self.drums) do
        local v = want[i]
        if instant then
            d.pos, d.t0 = v, 0
        else
            local cur = math.floor((d.t0 > 0 and d.to or d.pos) + 0.5) % 10
            if v ~= cur then
                local from, to = d.pos, v
                if to < from and from - to > 5 then to = to + 10 elseif to > from and to - from > 5 then from = from + 10 end
                d.from, d.to, d.t0 = from, to, now
            end
        end
    end
end

function W:stepMotion(now, dt)
    local gen = self.gen
    local running = gen:isActivated()
    -- needles on springs (the mockup's numbers: dt in 16 ms frames)
    local N, F = self.N, self.F
    local tg = running and (-120 + 240 * clamp(self:load() / self.loadMax, 0, 1.02)) or -120
    N.w = N.w + ((tg - N.a) * 0.05 - N.w * 0.18) * dt
    if running then N.w = N.w + ZombRandFloat(-0.5, 0.5) * 1.6 * dt end
    N.a = N.a + N.w * dt
    if N.a < -123 then N.a, N.w = -123, math.abs(N.w) * 0.4 end
    local ft = -60 + 120 * self:fuelFrac()
    F.w = F.w + ((ft - F.a) * 0.04 - F.w * 0.2) * dt
    if running then F.w = F.w + ZombRandFloat(-0.5, 0.5) * 0.45 * dt end
    F.a = F.a + F.w * dt
    -- the switch follows the engine started or stopped elsewhere (the game's menu): a
    -- running one is at RUN; stopped with fuel left - turned to OFF; run dry - left at RUN
    local kn = self.knob
    local md = gen:getModData()
    if running and md.knoxSwitch ~= true then md.knoxSwitch = true end
    if running ~= self.wasRunning and self.wasRunning ~= nil then
        local want = running or gen:getFuel() <= 0
        if (md.knoxSwitch == true) ~= want then
            md.knoxSwitch = want
            if isClient() then gen:transmitModData() end
            kn.from, kn.to, kn.t0 = kn.a, want and 40 or -40, now
        end
    end
    self.wasRunning = running
    -- the switch: 220 ms with a little swing at the end
    if kn.t0 > 0 then
        local k = math.min(1, (now - kn.t0) / 220)
        local o = k < 1 and math.sin(k * 9) * (1 - k) * 6 or 0
        kn.a = kn.from + (kn.to - kn.from) * ease(k) + o
        if k >= 1 then kn.t0 = 0 end
    else
        kn.a = self:switchOn() and 40 or -40
    end
    -- the lever follows the generator's own state
    local conn = gen:isConnected()
    local LV = self.LV
    if conn ~= self.house then
        self.house = conn
        LV.from, LV.to, LV.t0 = LV.x, conn and 0 or -43, now
    end
    if LV.t0 > 0 then
        local k = math.min(1, (now - LV.t0) / 220)
        local o = k < 1 and math.sin(k * math.pi * 2) * (1 - k) * 3 or 0
        local sign = LV.to > LV.from and 1 or (LV.to < LV.from and -1 or 0)
        LV.x = LV.from + (LV.to - LV.from) * ease(k) + o * sign
        if k >= 1 then LV.t0 = 0 end
    end
    -- the drums
    for _, d in ipairs(self.drums) do
        if d.t0 > 0 then
            local k = math.min(1, (now - d.t0) / 320)
            local e = k < 1 and (ease(k) + math.sin(k * math.pi) * 0.05) or 1
            d.pos = d.from + (d.to - d.from) * e
            if k >= 1 then d.pos, d.t0 = math.floor(d.to + 0.5) % 10, 0 end
        end
    end
    self:stepCord(dt, running)
end

--- The cord: 6 links that bend, sag and pull back in (the mockup's rope()).
function W:stepCord(dt, running)
    local R, drag = self.R, self.drag
    if not drag and self.L > L0 then self.L = math.max(L0, self.L - 7 * dt) end
    local seg = self.L / NP
    for i = 1, NP do
        local p = R[i]
        if i == NP and drag then
            p.px, p.py = p.x, p.y
            p.x = p.x + (drag.tx - p.x) * 0.7
            p.y = p.y + (drag.ty - p.y) * 0.7
        else
            local vx, vy = (p.x - p.px) * 0.9, (p.y - p.py) * 0.9
            p.px, p.py = p.x, p.y
            p.x = p.x + vx
            p.y = p.y + vy + (i == NP and 0.8 or 0.12) * dt * dt
            if running and i == NP then
                p.x = p.x + ZombRandFloat(-0.5, 0.5) * 0.4
                p.y = p.y + ZombRandFloat(-0.5, 0.5) * 0.25
            end
        end
    end
    local H = R[NP]
    for i = 1, NP - 1 do
        local k = i / NP
        local sx, sy = A.x + (H.x - A.x) * k, A.y + (H.y - A.y) * k
        R[i].x = R[i].x + (sx - R[i].x) * 0.35
        R[i].y = R[i].y + (sy - R[i].y) * 0.35
    end
    for _ = 1, 10 do
        R[0].x, R[0].y = A.x, A.y
        for i = 0, NP - 1 do
            local a, b = R[i], R[i + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < 0.0001 then d = 1 end
            if d > seg then
                local df = (d - seg) / d
                local wa = i == 0 and 0 or (i + 1 == NP and (drag and 1 or 0.7) or 0.5)
                local wb = i == 0 and 1 or (i + 1 == NP and (drag and 0 or 0.3) or 0.5)
                local tw = wa + wb
                if tw == 0 then tw = 1 end
                a.x, a.y = a.x + dx * df * wa / tw, a.y + dy * df * wa / tw
                b.x, b.y = b.x - dx * df * wb / tw, b.y - dy * df * wb / tw
            end
        end
    end
    for i = 1, NP do
        if R[i].y < A.y + 2 then R[i].y = A.y + 2 end
    end
end

--- The handle held at the mouse (units); the jerk when the cord reaches the end.
function W:pullTo(now)
    local drag = self.drag
    local s = self.s
    local x = self:getMouseX() / s + drag.ox
    local y = self:getMouseY() / s + drag.oy
    local dx, dy = x - A.x, y - A.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d > LMAX then x, y = A.x + dx / d * LMAX, A.y + dy / d * LMAX end
    if y < A.y + 8 then y = A.y + 8 end
    drag.tx, drag.ty = x, y
    self.L = clamp(math.sqrt((x - A.x) ^ 2 + (y - A.y) ^ 2), L0, LMAX)
    local frac = (self.L - L0) / (LMAX - L0)
    -- the last ~90 ms of the cord's length (a ring of samples)
    self.histN = self.histN % HIST + 1
    self.histT[self.histN], self.histL[self.histN] = now, self.L
    if not drag.fired and frac >= END then
        drag.fired = true
        local t0, l0 = now, self.L
        for i = 1, HIST do
            local t = self.histT[i]
            if t > 0 and now - t <= 90 and t < t0 then t0, l0 = t, self.histL[i] end
        end
        self:jerk((self.L - l0) / math.max(1, now - t0))
    end
end

function W:releaseCord()
    self.drag = nil
end

-- Drawing ------------------------------------------------------------------------------------------

function W:prerender()
    if self.demo then return self:demoFrame() end
    self:layout()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    local gen, chr = self.gen, self.player
    if not gen or gen:getObjectIndex() == -1 or not gen:getSquare() or chr:isDead()
        or chr:DistTo(gen:getX(), gen:getY()) > WALK_DIST then
        self:close()
        return
    end
    self:frame(getTimestampMs())
end

--- A frame: the motions, then the machine (in a window, on its plate with its cross; a
--- news post's demo, the machine alone).
function W:frame(now)
    local gen = self.gen
    local dt = math.min(32, now - self.lastMs) / 16
    self.lastMs = now
    self:pollItems(now)
    self:stepPour(now)
    if self.drag then
        if isMouseButtonDown(0) then self:pullTo(now) else self:releaseCord() end
    end
    self:stepMotion(now, dt)
    if now >= self.minsAt then
        self.minsAt = now + 250
        local m = self:minutesLeft()
        if m ~= self.mins then
            self:meterTo(m, now, self.mins < 0)
            self.mins = m
        end
    end

    local s, w, h = self.s, self:getWidth(), self:getHeight()
    local running = gen:isActivated()
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local tex = self.tex
    local C = T.color
    -- the colours of this frame (sand by the skin; lit while it runs)
    local sand = C.accent
    local ls = self.litSand
    ls.r, ls.g, ls.b = math.min(1, sand.r * LIT_K.r), math.min(1, sand.g * LIT_K.g), math.min(1, sand.b * LIT_K.b)
    local sandNow = running and ls or sand
    local dimNow = running and LIT or DIM

    -- the window: its plate as the other device windows' (the TV's); a demo has none, only
    -- the inside of the casing filled as the plate shows through it in the game (the post's
    -- grid showed through the machine; filled whole, the demo stood on a dark box - the
    -- author, 2026-10-22: "только внутри самого генератора")
    if self.demo then
        roundFill(self, CASING[1] * s, CASING[2] * s, CASING[3] * s, CASING[4] * s, CASING[5] * s, C.screen)
    else
        self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
        T.rect(self, 0, 0, w, h, C.screen)
        T.border(self, 0, 0, w, h, C.hoverEdge)
        local fa = self.knoxMove and 1 or 0.5
        self:drawRectBorder(0, 0, w, h, fa, sand.r, sand.g, sand.b)
        self:drawRectBorder(1, 1, w - 2, h - 2, fa, sand.r, sand.g, sand.b)
    end

    -- the shake (the body only: the cross and the cord stay)
    local ox, oy = 0, 0
    if running then
        -- (T.mod: Kahlua's % breaks on numbers as big as a timestamp - 1792000000123 % 80
        -- came out 1620201308363 and the window stopped on its first frame, 2026-10-22)
        local t = T.mod(now, 80) / 20
        local i = math.floor(t)
        local k = t - i
        local a, b = SHAKE[i + 1], SHAKE[i + 2]
        ox, oy = (a[1] + (b[1] - a[1]) * k) * s, (a[2] + (b[2] - a[2]) * k) * s
    end

    pic(self, tex.under, {0, 0, 700, 500}, ox, oy, WHITE, 1)
    -- the lamps (blinking: a step of 0.4 s at a fifth)
    local blink = T.mod(now, 800) < 400 and 1 or 0.2
    local lit = self.lampOn
    lit[1], lit[2], lit[3] = running, gen:getCondition() < 40, running and self.inside
    local lb = BOX.lampdisc
    for i, l in ipairs(LAMPS) do
        local on = lit[i]
        picAt(self, tex.lampdisc, lb[1], l.y - 8, lb[3], lb[4], ox, oy, on and l.on or l.off, (on and i > 1) and blink or 1)
    end
    -- the scales' marks
    local fb = BOX.fticks
    picAt(self, tex.fticks, fb[1], fb[2] + TANK_DY, fb[3], fb[4], ox, oy, dimNow, 1)
    picAt(self, tex.fticks_red, fb[1], fb[2] + TANK_DY, fb[3], fb[4], ox, oy, RED, 1)
    pic(self, tex.lticks, BOX.lticks, ox, oy, dimNow, 1)
    -- the captions (the sand ones lit too, as the mockup's data-on)
    for _, spec in ipairs(self.order) do
        local c = spec.red and RED or (spec.sand and sandNow or (spec.lit and dimNow or DIM))
        say(self, spec, ox, oy, c, 1)
    end
    self:drawDrums(ox, oy)
    -- the load's window: its frame as wide as its text (the text made when it changes)
    local load = self:load()
    local lk = math.floor(load * 1000 + 0.5)
    if lk ~= self.loadKey then
        self.loadKey = lk
        self.loadText = W.number(lk / 1000, self.dec, true) .. " " .. self.unit
    end
    local lv = self:dyn("lv", self.loadText, 272, 326, 11, 500)
    -- (4 units each side of the text, 14 high round its line - 16 in the mockup: the wider
    -- "0,030 л/ч" pressed the frame's corners to the face's rim - the author, 2026-10-22)
    local bw = math.ceil((lv.inkW or 0) / s) + 8
    local bx, by = math.floor(ox + (272 - bw / 2) * s + 0.5), math.floor(oy + 319 * s + 0.5)
    local bwp, bhp = math.floor(bw * s + 0.5), math.floor(14 * s + 0.5)
    T.rect(self, bx, by, bwp, bhp, LVR_FILL)
    T.border(self, bx, by, bwp, bhp, LVR_EDGE)
    say(self, lv, ox, oy, BRIGHT, 1)
    -- the needles, then the hubs and the glass over them
    turned(self, tex.lneedle, BOX.lneedle, LC[1], LC[2], self.N.a, 0, 0, ox, oy, WHITE, 1)
    turned(self, tex.fneedle, BOX.fneedle, FC[1], FC[2], self.F.a, 0, TANK_DY, ox, oy, WHITE, 1)
    pic(self, tex.over, {0, 0, 700, 500}, ox, oy, WHITE, 1)
    -- the switch
    turned(self, tex.knob, BOX.knob, KC[1], KC[2], self.knob.a, 0, 0, ox, oy, WHITE, 1)
    turned(self, tex.knobmark, BOX.knob, KC[1], KC[2], self.knob.a, 0, 0, ox, oy, sand, 1)
    self:drawOutlets(ox, oy, sandNow)
    -- the house's lever and its ON / OFF
    local onA = clamp(1 - math.abs(self.LV.x) / 43, 0, 1)
    say(self, self.cap.hvOn, ox, oy, GREEN, onA)
    say(self, self.cap.hvOff, ox, oy, DIM, 1 - onA)
    turned(self, tex.lever, BOX.lever, 557, 359, 0, self.LV.x, 0, ox, oy, sand, 1)
    -- a can held over its place: green it takes it, red it doesn't
    if KnoxDrag and KnoxDrag.isActive() and self:overUnits(mx, my, CAN) then
        local item = KnoxDrag.entity and KnoxDrag.entity.item
        local fc = item and item.getFluidContainer and item:getFluidContainer()
        local ok = fc ~= nil and fc:contains(Fluid.Petrol)
        local c = ok and C.ok or C.bad
        local r = self:px(CAN, ox, oy)
        self:drawRect(r[1], r[2], r[3], r[4], 0.22, c.r, c.g, c.b)
        T.tileFrame(self, r[1], r[2], r[3], r[4], c)
    elseif self.pour then
        -- pouring: the place's frame breathes in sand
        local r = self:px(CAN, ox, oy)
        T.tileFrame(self, r[1], r[2], r[3], r[4], sand, 0.45 + 0.4 * math.sin(T.mod(now, 900) / 900 * math.pi * 2))
    end

    -- not shaken: the cross, the cord and its handle, the tip (no message line over the
    -- generator, no hint, no words for what happens - the author, 2026-10-22)
    if not self.demo then
        local cr = self.closeR
        T.closeButton(self, cr[1], cr[2], cr[3], over and inRect(mx, my, cr))
    end
    self:drawCord()
    self:drawTip(mx, my, over)
end

--- A box of units in px (moved by the shake), into a table kept for it.
function W:px(b, ox, oy)
    local r = self.pxR or {0, 0, 0, 0}
    self.pxR = r
    local s = self.s
    r[1], r[2] = math.floor(ox + b[1] * s + 0.5), math.floor(oy + b[2] * s + 0.5)
    r[3], r[4] = math.floor(b[3] * s + 0.5), math.floor(b[4] * s + 0.5)
    return r
end

function W:overUnits(mx, my, b)
    local s = self.s
    return mx >= b[1] * s and mx < (b[1] + b[3]) * s and my >= b[2] * s and my < (b[2] + b[4]) * s
end

--- The counter: each drum's two digits in its window, rolled by its position.
function W:drawDrums(ox, oy)
    local s = self.s
    for i, d in ipairs(self.drums) do
        local x = DX[i]
        local cx, cy0 = ox + (x + DW / 2) * s, oy + (MY + DH / 2) * s
        local x0, y0 = math.floor(ox + x * s + 0.5), math.floor(oy + MY * s + 0.5)
        self:clipTo(x0, y0, math.floor((x + DW) * s + ox + 0.5) - x0, math.floor((MY + DH) * s + oy + 0.5) - y0)
        -- (T.mod: a drum's swing past 0 goes below it, and Kahlua's % keeps the sign)
        local p = T.mod(d.pos, 10)
        local n = math.floor(p)
        for j = 0, 1 do
            local spec = self.digit[T.mod(n + j, 10)]
            local cy = cy0 + (n + j - p) * DH * s
            local bx = math.floor(cx + spec.dx + 0.5)
            local by = math.floor(cy + spec.dy + 0.5)
            local c = i == 4 and TENTH or DIGIT
            T.drawText(self, spec.chars[1], bx, by, c.r, c.g, c.b, 1, spec.font)
        end
        self:unclip()
    end
end

--- The outlets: a plug for each kind of thing it powers; past four, the fourth says +N.
function W:drawOutlets(ox, oy, sandNow)
    local items = self.items
    local n = #items
    for i = 0, 3 do
        local it = items[i + 1]
        if it then
            local dx, dy = (i % 2) * 42, math.floor(i / 2) * 52
            local p = BOX.plug
            picAt(self, self.tex.plug, p[1] + dx, p[2] + dy, p[3], p[4], ox, oy, WHITE, 1)
            local b = BOX.icon
            if i == 3 and n > 4 then
                if self.moreN ~= n then self.moreN, self.moreText = n, "+" .. tostring(n - 3) end
                local more = self:dyn("more", self.moreText, b[1] + dx + b[3] / 2, b[2] + dy + b[4] / 2, 10, 600)
                say(self, more, ox, oy, sandNow, 1)
            else
                picAt(self, self.tex[it.icon], b[1] + dx, b[2] + dy, b[3], b[4], ox, oy, sandNow, 1)
            end
        end
    end
end


--- The tip over an outlet: what it powers and how much it takes.
function W:drawTip(mx, my, over)
    if not over or self.drag or (KnoxDrag and KnoxDrag.isActive()) then return end
    local hit
    local s = self.s
    local ux, uy = mx / s, my / s
    for i = 0, 3 do
        local x, y = 496 + (i % 2) * 42, 215 + math.floor(i / 2) * 52
        if ux >= x and ux < x + 38 and uy >= y and uy < y + 44 then hit = i break end
    end
    if not hit then self.tipKey = nil return end
    local items, n = self.items, #self.items
    local key = hit * 1000 + n
    if self.tipKey ~= key or self.tipItems ~= items then
        self.tipKey, self.tipItems = key, items
        local dec, unit = self.dec, self.unit
        local it = items[hit + 1]
        if not it then
            self.tipText = tx("FreeOutlet")
        elseif hit == 3 and n > 4 then
            local names = {}
            for j = 4, n do table.insert(names, items[j].name) end
            self.tipText = table.concat(names, ", ")
        else
            self.tipText = tx("Tip", it.name, W.number(it.use, dec) .. " " .. unit)
        end
    end
    local font = fontFor(500, 11 * s)
    local tw = math.ceil(T.measure(font, self.tipText) + 18 * s)
    local th = math.floor(20 * s + 0.5)
    local cx = (496 + (hit % 2) * 42 + 19) * s
    local r = self.tipR
    r[1] = math.floor(clamp(cx - tw / 2, 4 * s, self:getWidth() - tw - 4 * s) + 0.5)
    r[2] = math.floor((215 + math.floor(hit / 2) * 52 - 4) * s + 0.5) - th
    r[3], r[4] = tw, th
    self.tipOpts.font, self.tipOpts.edge, self.tipOpts.fill = font, T.color.accent, T.color.header
    T.plate(self, r, self.tipText, self.tipOpts)
end

--- The cord from its hole to the handle, and the handle turned along its last link.
function W:drawCord()
    local s, R = self.s, self.R
    -- the mockup's path: quadratic pieces through the links' middles
    local th = 2.5 * s
    local px0, py0 = R[0].x * s, R[0].y * s
    for i = 1, NP - 1 do
        local m, nx = R[i], R[i + 1]
        local ex, ey = (m.x + nx.x) / 2, (m.y + nx.y) / 2
        for k = 1, 4 do
            local t = k / 4
            local u = 1 - t
            -- from the last end (px0, py0 in px) through m to the middle e
            local sx, sy = (i == 1) and R[0].x or (R[i - 1].x + m.x) / 2, (i == 1) and R[0].y or (R[i - 1].y + m.y) / 2
            local x = (u * u * sx + 2 * u * t * m.x + t * t * ex) * s
            local y = (u * u * sy + 2 * u * t * m.y + t * t * ey) * s
            bar(self, px0, py0, x, y, th, CORD, 1)
            px0, py0 = x, y
        end
    end
    local a, b = R[NP - 1], R[NP]
    bar(self, px0, py0, b.x * s, b.y * s, th, CORD, 1)
    local ang = math.deg(math.atan2(b.x - a.x, b.y - a.y))
    self.handleAng = -ang
    turned(self, self.tex.handle, BOX.handle, 0, 0, -ang, b.x, b.y + 4, 0, 0, WHITE, 1)
end

-- A live window in a news post -----------------------------------------------------------------
-- (the author, 2026-10-22: "as interactive as the dashboard of Behind the wheel") - the
-- window itself on a pretend generator (KnoxGenDemo), no plate and no cross, placed by the
-- news reader each frame (hostAt). It draws and takes the mouse only in the reader's view
-- (`demoClip`): its body scrolls under the post's title, as the dashboard's demo does.

--- A demo window: `worn` - a generator at 30 %; `running` - started already, its switch at RUN.
function W.makeDemo(worn, running)
    local demo = KnoxGenDemo.new(worn)
    if running then
        demo.g.on = true
        demo.gen:getModData().knoxSwitch = true
    end
    local w = W:new(demo.chr, demo.gen)
    w.demo = demo
    w.demoClip, w.clipBox = {0, 0, 0, 0}, {0, 0, 0, 0}
    w:initialise()
    w:instantiate()
    return w
end

--- The demo of a news post's "@gen [worn]" line in a window that shows news: made once per
--- window and post line (`key`), kept for its later frames.
function W.newsDemo(host, key, worn, running)
    host.knoxGenDemos = host.knoxGenDemos or {}
    local w = host.knoxGenDemos[key]
    if not w then
        w = W.makeDemo(worn, running)
        host.knoxGenDemos[key] = w
    end
    return w
end

-- (a demo shows the machine only: the window's empty band over its frame - where the
-- message line was - and under its feet are cut off; a post's heading stood far above it,
-- the author 2026-10-22)
local DEMO_TOP, DEMO_BOTTOM = 30, 482

--- How big the demo is (the screen's scale, as the real window's), no wider than maxW.
function W:demoSize(maxW)
    self.maxW = maxW
    self:layout()
    return self:getWidth(), math.floor((DEMO_BOTTOM - DEMO_TOP) * self.s + 0.5)
end

--- Each frame of the window it stands in: at x, y of `host`, shown in its view {x, y, w, h}
--- (the host's coordinates). A demo not placed for a moment hides.
function W:hostAt(host, x, y, view)
    if self.host ~= host then
        host:addChild(self)
        self.host = host
    end
    if self.broken then
        self:setVisible(false)
        return
    end
    self:layout()
    -- (the window sits its cut band higher: its machine starts at y; the clip is the view
    -- and the cut part both)
    local top, h = math.floor(DEMO_TOP * self.s + 0.5), math.floor((DEMO_BOTTOM - DEMO_TOP) * self.s + 0.5)
    self:setX(x)
    self:setY(y - top)
    local c = self.demoClip
    local cy0, cy1 = math.max(view[2], y), math.min(view[2] + view[4], y + h)
    c[1], c[2], c[3], c[4] = view[1] - x, cy0 - (y - top), view[3], math.max(0, cy1 - cy0)
    self.placedAt = getTimestampMs()
    self:setVisible(y + h > view[2] and y < view[2] + view[4])
end

--- Is a point of the window in the part of it that shows? (Always, but a demo's.)
function W:inClip(x, y)
    local c = self.demo and self.demoClip
    if not c then return true end
    return x >= c[1] and y >= c[2] and x < c[1] + c[3] and y < c[2] + c[4]
end

--- Clip to a box, and back (the drums' windows). A demo is clipped to its view already:
--- the box is a level inside it, and taking it off is painted back to the view's level
--- (as the dashboard's demo does - set again, everything after was drawn inside the box).
function W:clipTo(x, y, w, h)
    local c = self.demo and self.demoClip
    if c then
        local x2, y2 = math.min(x + w, c[1] + c[3]), math.min(y + h, c[2] + c[4])
        x, y = math.max(x, c[1]), math.max(y, c[2])
        w, h = math.max(0, x2 - x), math.max(0, y2 - y)
        local b = self.clipBox
        b[1], b[2], b[3], b[4] = x, y, w, h
    end
    self:setStencilRect(x, y, w, h)
end

function W:unclip()
    self:clearStencilRect()
    if self.demo then
        local b = self.clipBox
        self:repaintStencilRect(b[1], b[2], b[3], b[4])
    end
end

--- A demo's press off its shown part goes to the window it stands in (the news).
function W:toHost(fn, x, y)
    local h = self.host
    if not (self.demo and h and h[fn]) or self:inClip(x, y) then return false end
    h[fn](h, x + self:getX(), y + self:getY())
    return true
end

--- A control's doing; a demo's guarded - an error there is a line in console.txt, never
--- the game's error window over the news.
function W:run(f, a)
    if not self.demo then return f(self, a) end
    local ok, err = pcall(f, self, a)
    if not ok then print("[Knox] the news' generator: " .. tostring(err)) end
end

--- A demo's frame: as the real window's, where its reader put it, clipped to its view.
function W:demoFrame()
    local now = getTimestampMs()
    if self.broken or now - (self.placedAt or 0) > 150 then
        self:setVisible(false)
        return
    end
    self:layout()
    local c = self.demoClip
    self:setStencilRect(c[1], c[2], c[3], c[4])
    local ok, err = pcall(function()
        self.demo:tick(now)
        self:frame(now)
    end)
    self:clearStencilRect()
    if not ok then
        print("[Knox] the news' generator stopped: " .. tostring(err))
        self.broken = true
        self:setVisible(false)
    end
end

-- Input --------------------------------------------------------------------------------------------

--- Is the mouse (px) on the handle? (in the handle's own turned frame)
function W:onHandle(x, y)
    local s, H = self.s, self.R[NP]
    local ux, uy = x / s - H.x, y / s - (H.y + 4)
    local r = math.rad(self.handleAng or 0)
    local lx = ux * math.cos(r) + uy * math.sin(r)
    local ly = -ux * math.sin(r) + uy * math.cos(r)
    return lx >= -34 and lx <= 34 and ly >= -9 and ly <= 18
end

function W:onMouseDown(x, y)
    if self.foldMs or self:toHost("onMouseDown", x, y) then return true end
    local s = self.s
    if not self.demo then
        self:bringToTop()
        if inRect(x, y, self.closeR) then self:close() return true end
    end
    if self:onHandle(x, y) then
        local H = self.R[NP]
        self.drag = {ox = H.x - x / s, oy = H.y - y / s, fired = false, tx = H.x, ty = H.y}
        for i = 1, HIST do self.histT[i] = 0 end
        self.histN = 0
        return true
    end
    local dx, dy = x / s - KC[1], y / s - KC[2]
    if dx * dx + dy * dy <= 30 * 30 then self:run(self.toggleSwitch) return true end
    if self:overUnits(x, y, HOUSE) then self:run(self.toggleHouse) return true end
    if self:overUnits(x, y, CAN) then self:run(self.refuel) return true end
    if not self.demo then KnoxWindowDrag.begin(self, x, y, self:getHeight()) end
    return true
end

KnoxWindowDrag.install(W)

local dragStop = W.onMouseUp
function W:onMouseUp(x, y)
    if self.drag then self:releaseCord() end
    if self:toHost("onMouseUp", x, y) then return true end
    -- a can dropped on its place from a Knox grid
    if KnoxDrag and KnoxDrag.isActive() and self:overUnits(x, y, CAN) then
        local item = KnoxDrag.entity.item
        KnoxDrag.cancel()
        self:refuel(item)
        return true
    end
    return dragStop(self, x, y)
end

local dragStopOut = W.onMouseUpOutside
function W:onMouseUpOutside(x, y)
    if self.drag then self:releaseCord() end
    return dragStopOut(self, x, y)
end

function W:onRightMouseUp(x, y)
    return true
end

--- (a demo: the wheel scrolls the news it stands in)
function W:onMouseWheel(del)
    if self.demo and self.host and self.host.onMouseWheel then return self.host:onMouseWheel(del) end
    return false
end

function W:isKeyConsumed(key) return key == Keyboard.KEY_ESCAPE end

function W:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end

function W:close()
    W.lastX, W.lastY = self:getX(), self:getY()
    self.drag = nil
    self:stopPour()
    T.fold(self, function(w)
        w:setVisible(false)
        w:removeFromUIManager()
    end)
    if W.instance == self then W.instance = nil end
end

--- Open in place of the game's window.
function W.open(player, gen)
    if W.instance then
        if W.instance.gen == gen then W.instance:bringToTop() return W.instance end
        W.instance:close()
    end
    T.ensure()
    local w = W:new(player, gen)
    w:initialise()
    w:instantiate()
    w:layout()
    w:setWantKeyEvents(true)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = W.lastX or math.floor((sw - w:getWidth()) / 2)
    local y = W.lastY or math.floor((sh - w:getHeight()) / 2)
    w:setX(math.max(0, math.min(sw - w:getWidth(), x)))
    w:setY(math.max(0, math.min(sh - w:getHeight(), y)))
    w:addToUIManager()
    w:setAlwaysOnTop(true)   -- over the Knox screen, which comes to the top on a click
    W.instance = w
    return w
end

-- The game's info action opens its own window once the character has walked up:
-- ours instead, while the generator module is on (for the mouse player, Knox.forPlayer).
local function hook()
    if not ISGeneratorInfoAction or W.hooked then return end
    W.hooked = true
    local perform = ISGeneratorInfoAction.perform
    function ISGeneratorInfoAction:perform()
        local p = self.character
        if not (Knox and Knox.forPlayer and p and Knox.forPlayer(p:getPlayerNum(), "generator")) then return perform(self) end
        ISBaseTimedAction.perform(self)
        local already = W.instance ~= nil and W.instance.gen == self.object
        W.open(p, self.object)
        -- at the generator while the window is open (its controls work at once; open
        -- already, the action is there too)
        if not already then ISTimedActionQueue.add(KnoxGeneratorUse:new(p, self.object)) end
    end
end

Events.OnGameStart.Add(hook)

-- The generator's own "Turn on" / "Turn off" of the game's menu are gone, the window
-- does both; a left click on a generator in the world opens it (the author, 2026-10-22).
-- (only in the menu holding the generator's "Info": a lamp's "Turn on" elsewhere stays)
local function trimMenu(playerNum, context, worldobjects, test)
    if test or not context or not (Knox and Knox.forPlayer and Knox.forPlayer(playerNum, "generator")) then return end
    local info = getText("ContextMenu_GeneratorInfo")
    local on, off = getText("ContextMenu_Turn_On"), getText("ContextMenu_Turn_Off")
    local seen = {}
    local function trim(menu)
        if not menu or not menu.options or seen[menu] then return end
        seen[menu] = true
        for _, o in ipairs(menu.options) do
            if o.name == info then
                menu:removeOptionByName(on)
                menu:removeOptionByName(off)
                break
            end
        end
        for _, o in ipairs(menu.options) do
            if o.subOption then trim(menu:getSubMenu(o.subOption)) end
        end
    end
    trim(context)
end

local function leftClick(object, x, y)
    if not object or not instanceof(object, "IsoGenerator") then return end
    local p = getSpecificPlayer(0)
    if not p or p:getVehicle() or not (Knox and Knox.forPlayer and Knox.forPlayer(0, "generator")) then return end
    if KnoxDrag and KnoxDrag.isActive() then return end
    if W.instance and W.instance.gen == object then W.instance:bringToTop() return end
    if object:getSquare() and luautils.walkAdj(p, object:getSquare()) then
        ISTimedActionQueue.add(ISGeneratorInfoAction:new(p, object))
    end
end

if Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(trimMenu) end
if Events.OnObjectLeftMouseButtonUp then Events.OnObjectLeftMouseButtonUp.Add(leftClick) end

return KnoxGeneratorWindow
