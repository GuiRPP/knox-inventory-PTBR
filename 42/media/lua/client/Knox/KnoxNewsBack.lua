-- A news post's backdrop, drawn (not a picture: sharp on any screen) - the technical
-- update's way (a faint drawing grid in the post's colour, a big faint symbol of the post
-- behind it, light under it; the author, 2026-10-22), and alive: "@back power" - a light
-- bulb that lights up with the post's generators. While every generator of the post
-- stands, the grid and the bulb are hardly there; one started (its live window in the
-- post, or in the frame on the right), the bulb flares with a flicker of its filament,
-- the grid comes out, warm light spreads under the bulb; it trembles with the engine and
-- fades when the engine stops (KnoxMenuNews: litFor, draw).
-- Nothing is made while drawing: the bulb's lines are worked out once per size.

require "Knox/KnoxTheme"

KnoxNewsBack = KnoxNewsBack or {}
local B = KnoxNewsBack
local T = KnoxTheme

local UP_MS, DOWN_MS = 350, 1400      -- lighting up, going out
local FLICK_MS = 420                  -- the filament's flicker as it lights

local texCache = {}
local function tex(name)
    local t = texCache[name]
    if t == nil then
        t = getTexture("media/ui/knoxdash/" .. name .. ".png") or false
        texCache[name] = t
    end
    return t or nil
end

--- A soft line x0,y0 -> x1,y1 (screen px of the ui), th thick.
local function bar(ui, x0, y0, x1, y1, th, c, a)
    local t = tex("bar")
    local dx, dy = x1 - x0, y1 - y0
    local l = math.sqrt(dx * dx + dy * dy)
    if not t or l < 0.01 or a <= 0.003 then return end
    local h = (th + 1) / 2
    local nx, ny = -dy / l * h, dx / l * h
    local ex, ey = dx / l * th * 0.4, dy / l * th * 0.4
    local ax, ay = ui:getAbsoluteX(), ui:getAbsoluteY()
    ui.javaObject:DrawTexture(t, ax + x0 - ex + nx, ay + y0 - ey + ny, ax + x1 + ex + nx, ay + y1 + ey + ny,
        ax + x1 + ex - nx, ay + y1 + ey - ny, ax + x0 - ex - nx, ay + y0 - ey - ny, c.r, c.g, c.b, a)
end

-- The light bulb in units (its glass's middle at 0, -0.35; about 1.7 high): the glass, its
-- neck and screw, the filament, the rays round its top. Each a polyline {x1, y1, x2, y2, ...}.
local BULB, FILAMENT, RAYS = {}, {}, {}
do
    local glass = {}
    for i = 0, 40 do
        local a = math.rad(-35 + 250 * i / 40)
        table.insert(glass, 0.55 * math.cos(a))
        table.insert(glass, -0.35 - 0.55 * math.sin(a))
    end
    table.insert(BULB, glass)
    table.insert(BULB, {0.45, -0.035, 0.25, 0.32})
    table.insert(BULB, {-0.45, -0.035, -0.25, 0.32})
    table.insert(BULB, {-0.25, 0.32, 0.25, 0.32})
    for _, y in ipairs({0.42, 0.52, 0.62}) do table.insert(BULB, {-0.24, y, 0.24, y}) end
    table.insert(BULB, {-0.25, 0.32, -0.22, 0.68, -0.1, 0.76, 0.1, 0.76, 0.22, 0.68, 0.25, 0.32})
    FILAMENT[1] = {-0.13, 0.32, -0.13, -0.18, -0.07, -0.3, 0, -0.18, 0.07, -0.3, 0.13, -0.18, 0.13, 0.32}
    for i = 0, 6 do
        local a = math.rad(15 + 150 * i / 6)
        local cs, sn = math.cos(a), math.sin(a)
        table.insert(RAYS, {0.74 * cs, -0.35 - 0.74 * sn, 0.96 * cs, -0.35 - 0.96 * sn})
    end
end

local function lines(ui, list, cx, cy, k, th, c, a)
    for _, l in ipairs(list) do
        for i = 1, #l - 3, 2 do
            bar(ui, cx + l[i] * k, cy + l[i + 1] * k, cx + l[i + 2] * k, cy + l[i + 3] * k, th, c, a)
        end
    end
end

--- How lit, 0..1, eased over time: `st` a table kept by the caller, `on` - is a
--- generator of the post running now.
function B.litFor(st, on, now)
    local dt = math.max(0, math.min(100, now - (st.at or now)))
    st.at = now
    local v = st.v or 0
    if on then
        if v == 0 then st.since = now end
        v = math.min(1, v + dt / UP_MS)
    else
        v = math.max(0, v - dt / DOWN_MS)
    end
    st.v = v
    -- the filament as it lights: a few quick dips; running: a slight tremble
    local f = v
    if on then
        local age = now - (st.since or now)
        if age < FLICK_MS then
            f = v * (0.45 + 0.55 * (T.mod(math.floor(age / 55), 3) == 1 and 0.3 or 1))
        else
            f = v * (0.93 + 0.07 * ZombRandFloat(0, 1))
        end
    end
    st.f = f
    return f
end

local warm = {r = 1, g = 0.86, b = 0.55}
local tmpC = {r = 0, g = 0, b = 0}

--- The grid over x, y, w, h of `ui` (its px), in `c`, as lit as `lit`, `dim` - its weight
--- (1 the text's panel, less the screen behind it).
function B.grid(ui, x, y, w, h, c, lit, dim)
    local step = math.max(12, math.floor(T.cell / 2))
    local minor, major = (0.04 + 0.035 * lit) * dim, (0.08 + 0.07 * lit) * dim
    local i = 0
    for gx = x + step, x + w - 1, step do
        i = i + 1
        ui:drawRect(gx, y, 1, h, i % 4 == 0 and major or minor, c.r, c.g, c.b)
    end
    i = 0
    for gy = y + step, y + h - 1, step do
        i = i + 1
        ui:drawRect(x, gy, w, 1, i % 4 == 0 and major or minor, c.r, c.g, c.b)
    end
end

--- The backdrop of a text panel x, y, w, h: the grid, the light and the bulb at its lower
--- right (partly off the panel: the caller clips to it).
function B.draw(ui, kind, x, y, w, h, c, lit)
    if kind ~= "power" then return end
    B.grid(ui, x, y, w, h, c, lit, 1)
    local k = h * 0.3
    local cx, cy = x + w - k * 0.62, y + h - k * 0.42
    -- the light under the bulb (the menu's soft round picture, warm)
    local soft = tex("soft")
    if soft and lit > 0.01 then
        tmpC.r, tmpC.g, tmpC.b = c.r + (warm.r - c.r) * 0.5, c.g + (warm.g - c.g) * 0.5, c.b + (warm.b - c.b) * 0.5
        local r = k * 2.6
        ui:drawTextureScaled(soft, cx - r, cy - 0.35 * k - r, r * 2, r * 2, 0.26 * lit, tmpC.r, tmpC.g, tmpC.b)
    end
    local th = math.max(2, T.cell * 0.05)
    local a = 0.08 + 0.14 * lit
    lines(ui, BULB, cx, cy, k, th, c, a)
    lines(ui, RAYS, cx, cy, k, th, c, 0.03 + 0.16 * lit)
    -- the filament: glows warm when lit
    lines(ui, FILAMENT, cx, cy, k, th, lit > 0.01 and warm or c, 0.08 + 0.7 * lit)
end

--- The backdrop again, only in the rows y..y+h of the panel x, y0, w, h0 and as faded in
--- as `am` (the caller clips to the strip): where a scrolled post fades into its panel,
--- the panel is painted back over it strip by strip - the grid, the light and the bulb
--- stay whole and only the post fades (a flat fill there hid them in a dark band - the
--- author, 2026-10-22).
function B.drawStrip(ui, kind, x, y0, w, h0, c, lit, y, h, am)
    if kind ~= "power" or am <= 0.003 then return end
    local step = math.max(12, math.floor(T.cell / 2))
    local minor, major = (0.04 + 0.035 * lit) * am, (0.08 + 0.07 * lit) * am
    local i = 0
    for gx = x + step, x + w - 1, step do
        i = i + 1
        ui:drawRect(gx, y, 1, h, i % 4 == 0 and major or minor, c.r, c.g, c.b)
    end
    i = 0
    for gy = y0 + step, y0 + h0 - 1, step do
        i = i + 1
        if gy >= y and gy < y + h then ui:drawRect(x, gy, w, 1, i % 4 == 0 and major or minor, c.r, c.g, c.b) end
    end
    local k = h0 * 0.3
    local cx, cy = x + w - k * 0.62, y0 + h0 - k * 0.42
    local soft = tex("soft")
    if soft and lit > 0.01 then
        local r = k * 2.6
        local gy = cy - 0.35 * k - r
        if y + h > gy and y < gy + r * 2 then
            tmpC.r, tmpC.g, tmpC.b = c.r + (warm.r - c.r) * 0.5, c.g + (warm.g - c.g) * 0.5, c.b + (warm.b - c.b) * 0.5
            ui:drawTextureScaled(soft, cx - r, gy, r * 2, r * 2, 0.26 * lit * am, tmpC.r, tmpC.g, tmpC.b)
        end
    end
    -- the bulb only where the strip crosses it
    local th = math.max(2, T.cell * 0.05)
    if y + h > cy - 1.31 * k - th and y < cy + 0.76 * k + th then
        lines(ui, BULB, cx, cy, k, th, c, (0.08 + 0.14 * lit) * am)
        lines(ui, RAYS, cx, cy, k, th, c, (0.03 + 0.16 * lit) * am)
        lines(ui, FILAMENT, cx, cy, k, th, lit > 0.01 and warm or c, (0.08 + 0.7 * lit) * am)
    end
end

return KnoxNewsBack
