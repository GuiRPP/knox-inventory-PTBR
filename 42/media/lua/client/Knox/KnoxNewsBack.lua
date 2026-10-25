-- A news post's backdrop, drawn (not a picture: sharp on any screen) - the technical
-- update's way (a faint drawing grid in the post's colour, a big faint symbol of the post
-- behind it, light under it; the author, 2026-10-22), and alive: "@back power" - a light
-- bulb that lights up with the post's generators. While every generator of the post
-- stands, the grid and the bulb are hardly there; one started (its live window in the
-- post, or in the frame on the right), the bulb flares with a flicker of its filament,
-- the grid comes out, warm light spreads under the bulb; it trembles with the engine and
-- fades when the engine stops (KnoxMenuNews: litFor, draw).
-- "@back aim" (the crosshair panel's post, 2026-10-25): the same grid and a big faint
-- sight at the lower right; while the post's panel is at work - things being found or
-- taken - the grid comes out, the sight brightens and its inner ring draws in, as if
-- it were aimed (no flicker: it is no lamp).
-- Nothing is made while drawing: the bulb's lines are worked out once per size.

require "Knox/KnoxTheme"

KnoxNewsBack = KnoxNewsBack or {}
local B = KnoxNewsBack
local T = KnoxTheme

local UP_MS, DOWN_MS = 350, 1400      -- lighting up, going out
local FLICK_MS = 420                  -- the filament's flicker as it lights

-- (only once read: T.readyTex - not the game's red-white squares, 2026-10-25)
local texPath = {}
local function tex(name)
    local p = texPath[name]
    if not p then
        p = "media/ui/knoxdash/" .. name .. ".png"
        texPath[name] = p
    end
    return T.readyTex(p)
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

-- The sight in units (its middle at 0, 0; radius 1): the outer ring and its marks stay,
-- the inner ring and the cross's inner strokes draw in as it is aimed.
local SIGHT, SIGHT_IN = {}, {}
do
    local ring = {}
    for i = 0, 72 do
        local a = math.rad(5 * i)
        table.insert(ring, math.cos(a))
        table.insert(ring, math.sin(a))
    end
    table.insert(SIGHT, ring)
    -- the cross: long strokes from the ring inwards, ticks along them
    table.insert(SIGHT, {-1.12, 0, -0.42, 0})
    table.insert(SIGHT, {0.42, 0, 1.12, 0})
    table.insert(SIGHT, {0, -1.12, 0, -0.42})
    table.insert(SIGHT, {0, 0.42, 0, 1.12})
    for _, d in ipairs({0.6, 0.8}) do
        table.insert(SIGHT, {-d, -0.05, -d, 0.05})
        table.insert(SIGHT, {d, -0.05, d, 0.05})
        table.insert(SIGHT, {-0.05, d, 0.05, d})
        table.insert(SIGHT, {-0.05, -d, 0.05, -d})
    end
    local inner = {}
    for i = 0, 72 do
        local a = math.rad(5 * i)
        table.insert(inner, 0.32 * math.cos(a))
        table.insert(inner, 0.32 * math.sin(a))
    end
    table.insert(SIGHT_IN, inner)
    table.insert(SIGHT_IN, {-0.24, 0, -0.08, 0})
    table.insert(SIGHT_IN, {0.08, 0, 0.24, 0})
    table.insert(SIGHT_IN, {0, -0.24, 0, -0.08})
    table.insert(SIGHT_IN, {0, 0.08, 0, 0.24})
end

local function lines(ui, list, cx, cy, k, th, c, a)
    for _, l in ipairs(list) do
        for i = 1, #l - 3, 2 do
            bar(ui, cx + l[i] * k, cy + l[i + 1] * k, cx + l[i + 2] * k, cy + l[i + 3] * k, th, c, a)
        end
    end
end

-- The same, only the strokes that reach into the rows ya..yb (a fade strip 3 px high:
-- drawn whole in each, the sight cost 4266 draws a frame and the menu fell to 50 FPS -
-- the author, 2026-10-25). Compared in the sight's units: a stroke left out costs two compares.
local function linesIn(ui, list, cx, cy, k, th, c, a, ya, yb)
    local ua, ub = (ya - th - cy) / k, (yb + th - cy) / k
    for _, l in ipairs(list) do
        for i = 1, #l - 3, 2 do
            local y1, y2 = l[i + 1], l[i + 3]
            if (y1 >= ua or y2 >= ua) and (y1 <= ub or y2 <= ub) then
                bar(ui, cx + l[i] * k, cy + y1 * k, cx + l[i + 2] * k, cy + y2 * k, th, c, a)
            end
        end
    end
end

--- How lit, 0..1, eased over time: `st` a table kept by the caller, `on` - is a
--- generator of the post running now.
function B.litFor(st, on, now, kind)
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
    if kind == "aim" then
        st.f = v
        return v
    end
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

-- "road": the night road of the pinned post (the author's mockup boosty_v1, 2026-10-25) - a
-- contour map drifting slowly, a dashed route round the text that a light walks along, its
-- stops lighting up as it passes, embers rising from the fire below, the fire's warmth
-- breathing, the middle under the text quieter. Its clock runs in B.draw (once a frame);
-- B.drawStrip paints again only what reaches into a fade strip.
local SAND = {r = 212 / 255, g = 195 / 255, b = 138 / 255}
local GOLD = {r = 224 / 255, g = 182 / 255, b = 94 / 255}
local EMBER = {r = 236 / 255, g = 140 / 255, b = 58 / 255}
local DARK = {r = 18 / 255, g = 20 / 255, b = 20 / 255}
local WALKER = {r = 1, g = 236 / 255, b = 190 / 255}
-- the route in parts of the panel: up the left margin, under the head, down the right one
local ROUTE = {{.30, 1.04}, {.13, .90}, {.075, .70}, {.125, .50}, {.065, .31}, {.13, .15}, {.33, .03}, {.67, .03},
               {.87, .15}, {.935, .33}, {.875, .53}, {.93, .73}, {.85, .90}, {.68, 1.04}}
local STOPS = {2, 4, 9, 11}   -- (the route's points, from 0, where a stop stands)
local EMBERS = 70

local road = {w = 0, h = 0, px = {}, py = {}, len = {}, total = 0, stopAt = {}, walk = 0,
              embers = nil, ms = nil, dash = {}, dashN = 0}

-- (only once read: T.readyTex)
local pinnedPath = {}
local function pinnedTex(name)
    local p = pinnedPath[name]
    if not p then
        p = "media/ui/knoxmenu/pinned/" .. name .. ".png"
        pinnedPath[name] = p
    end
    return T.readyTex(p)
end

--- The route for a panel w x h (px from its corner): Catmull-Rom through ROUTE, 24 steps a part.
local function buildRoute(w, h)
    road.w, road.h = w, h
    local px, py, len = road.px, road.py, road.len
    for i = #px, 1, -1 do px[i], py[i], len[i] = nil, nil, nil end
    for i = #road.stopAt, 1, -1 do road.stopAt[i] = nil end
    local n = 24
    for i = 1, #ROUTE - 1 do
        local p0, p1, p2, p3 = ROUTE[math.max(1, i - 1)], ROUTE[i], ROUTE[i + 1], ROUTE[math.min(#ROUTE, i + 2)]
        for _, si in ipairs(STOPS) do
            if si == i - 1 then table.insert(road.stopAt, #px + 1) end
        end
        for k = 0, n - 1 do
            local t = k / n
            local t2, t3 = t * t, t * t * t
            local x = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            local y = 0.5 * (2 * p1[2] + (-p0[2] + p2[2]) * t + (2 * p0[2] - 5 * p1[2] + 4 * p2[2] - p3[2]) * t2
                + (-p0[2] + 3 * p1[2] - 3 * p2[2] + p3[2]) * t3)
            table.insert(px, x * w)
            table.insert(py, y * h)
        end
    end
    table.insert(px, ROUTE[#ROUTE][1] * w)
    table.insert(py, ROUTE[#ROUTE][2] * h)
    len[1] = 0
    local total = 0
    for i = 2, #px do
        local dx, dy = px[i] - px[i - 1], py[i] - py[i - 1]
        total = total + math.sqrt(dx * dx + dy * dy)
        len[i] = total
    end
    road.total = total
end

local function newEmber(e, init, w, h)
    -- mostly at the sides and the bottom: the text's column stays calm
    local x = ZombRandFloat(0, 1) < 0.5 and ZombRandFloat(0, 1) * w * 0.2 or w * 0.8 + ZombRandFloat(0, 1) * w * 0.2
    if ZombRandFloat(0, 1) < 0.25 then x = w * (0.2 + 0.6 * ZombRandFloat(0, 1)) end
    e.x, e.y = x, init and ZombRandFloat(0, 1) * h or h + 8
    e.v = 12 + ZombRandFloat(0, 1) * 26
    e.s = ZombRandFloat(0, 1) < 0.7 and 2 or 3
    e.ph = ZombRandFloat(0, 6.28)
    e.life, e.max = 0, 7 + ZombRandFloat(0, 1) * 9
    e.c = ZombRandFloat(0, 1) < 0.3 and GOLD or EMBER
end

--- The point of the route `d` px along it (`i` - a point not past it, to start looking from).
local function along(d, i)
    local len = road.len
    while i < #len and len[i + 1] < d do i = i + 1 end
    local seg = math.max(0.0001, (len[i + 1] or len[i]) - len[i])
    local f = math.max(0, math.min(1, (d - len[i]) / seg))
    local j = math.min(#len, i + 1)
    return road.px[i] + (road.px[j] - road.px[i]) * f, road.py[i] + (road.py[j] - road.py[i]) * f, i
end

--- The night road's clock: the walker, the embers, the route's dashes for this frame.
local function stepRoad(w, h, s)
    if road.w ~= w or road.h ~= h then buildRoute(w, h) end
    local now = getTimestampMs()
    local dt = math.min(0.05, (now - (road.ms or now)) / 1000)
    road.ms = now
    road.t = now / 1000
    road.walk = T.mod(road.walk + dt * 70 * s, road.total + 400 * s)
    if not road.embers then
        road.embers = {}
        for i = 1, EMBERS do
            road.embers[i] = {}
            newEmber(road.embers[i], true, w, h)
        end
    end
    local t = road.t
    for _, e in ipairs(road.embers) do
        e.life = e.life + dt
        e.y = e.y - e.v * s * dt
        e.x = e.x + (math.sin(t * 0.7 + e.ph) * 8 + 6) * s * dt
        if e.life >= e.max or e.y < -10 then newEmber(e, false, w, h) end
    end
    -- the dashes (6 on, 8 off, creeping on): kept as numbers, x1 y1 x2 y2 by four. (along()
    -- inlined: one walk down the route a frame - it was 1.5 ms of the menu's frame, the author's
    -- "fps dropped in the menu" 2026-10-25; the same points as before)
    local dash, n = road.dash, 0
    local on, period = 6 * s, 14 * s
    local d = -T.mod(t * 6 * s, period)
    local px, py, len = road.px, road.py, road.len
    local nl, total = #len, road.total
    local i = 1
    while d < total do
        local a = d > 0 and d or 0
        local b = d + on
        if b > total then b = total end
        if b > a then
            while i < nl and len[i + 1] < a do i = i + 1 end
            local j = i < nl and i + 1 or nl
            local seg = len[j] - len[i]
            if seg < 0.0001 then seg = 0.0001 end
            local f = (a - len[i]) / seg
            if f < 0 then f = 0 elseif f > 1 then f = 1 end
            dash[n + 1], dash[n + 2] = px[i] + (px[j] - px[i]) * f, py[i] + (py[j] - py[i]) * f
            local k = i
            while k < nl and len[k + 1] < b do k = k + 1 end
            j = k < nl and k + 1 or nl
            seg = len[j] - len[k]
            if seg < 0.0001 then seg = 0.0001 end
            f = (b - len[k]) / seg
            if f < 0 then f = 0 elseif f > 1 then f = 1 end
            dash[n + 3], dash[n + 4] = px[k] + (px[j] - px[k]) * f, py[k] + (py[j] - py[k]) * f
            n = n + 4
        end
        d = d + period
    end
    road.dashN = n
    road.frame = (road.frame or 0) + 1
    -- (the walker's point: once a frame, not once a fade strip)
    road.wx, road.wy = along(math.min(road.walk, road.total), 1)
end

-- What drawRoad looks up once per call, not once per bar: the bar picture, the panel's
-- screen corner (2026-10-25, the menu's fps).
local barT, barJo, barAx, barAy = nil, nil, 0, 0
local texW, texH = {}, {}

--- bar() with those (drawRoad sets them).
local function roadBar(x0, y0, x1, y1, th, c, a)
    local dx, dy = x1 - x0, y1 - y0
    local l = math.sqrt(dx * dx + dy * dy)
    if not barT or l < 0.01 or a <= 0.003 then return end
    local h = (th + 1) / 2
    local nx, ny = -dy / l * h, dx / l * h
    local ex, ey = dx / l * th * 0.4, dy / l * th * 0.4
    local ax, ay = barAx, barAy
    barJo:DrawTexture(barT, ax + x0 - ex + nx, ay + y0 - ey + ny, ax + x1 + ex + nx, ay + y1 + ey + ny,
        ax + x1 + ex - nx, ay + y1 + ey - ny, ax + x0 - ex - nx, ay + y0 - ey - ny, c.r, c.g, c.b, a)
end

--- ui:drawTextureScaled(t, X, Y, W, H, a, r, g, b), only its part in xa..xb, ya..yb: the same
--- pixels (the same whole-pixel rect and the same mapping onto the picture), for a fade strip
--- 3 px high - not a picture the size of the panel drawn under a stencil 40 times a frame.
local function slice(t, X, Y, W, H, a, r, g, b, xa, xb, ya, yb)
    local x0, y0 = math.floor(barAx + X) - barAx, math.floor(barAy + Y) - barAy
    local w0, h0 = math.floor(W), math.floor(H)
    if w0 <= 0 or h0 <= 0 then return end
    local cx0, cx1 = x0 > xa and x0 or xa, x0 + w0 < xb and x0 + w0 or xb
    local cy0, cy1 = y0 > ya and y0 or ya, y0 + h0 < yb and y0 + h0 or yb
    if cx1 <= cx0 or cy1 <= cy0 then return end
    local tw = texW[t]
    if not tw then
        tw = t:getWidth()
        texW[t], texH[t] = tw, t:getHeight()
    end
    local th = texH[t]
    barJo:DrawSubTextureRGBA(t, (cx0 - x0) / w0 * tw, (cy0 - y0) / h0 * th, (cx1 - cx0) / w0 * tw,
        (cy1 - cy0) / h0 * th, cx0, cy0, cx1 - cx0, cy1 - cy0, r, g, b, a)
end

-- The road's pictures as the whole road drew them this frame, by nine: the picture, its
-- rect, alpha, colour - the fade strips cut their parts from these.
local pics, picN = {}, 0

--- A picture of the whole road: drawn, and kept for the strips.
local function roadTex(ui, t, X, Y, W, H, a, r, g, b)
    ui:drawTextureScaled(t, X, Y, W, H, a, r, g, b)
    pics[picN + 1], pics[picN + 2], pics[picN + 3], pics[picN + 4], pics[picN + 5] = t, X, Y, W, H
    pics[picN + 6], pics[picN + 7], pics[picN + 8], pics[picN + 9] = a, r, g, b
    picN = picN + 9
end

-- The road's dashes, trail, stops and embers sorted by rows (16 px) once a frame the fades
-- are drawn: a fade strip looks only at those near it, not at all 600 of them 40 times a
-- frame (2026-10-25). Ids by bucket; each strip draws an id once (stamp).
local IDX = 16
local idx = {frame = nil, h = nil, b0 = 0, b1 = 0,
             dash = {}, dashN = {}, trail = {}, trailN = {}, stop = {}, stopN = {}, ember = {}, emberN = {}}
local stampD, stampT, stampS, stampE = {}, {}, {}, {}
local stripId = 0

local function idxPut(list, cnt, lo, hi, id)
    local b0, b1 = math.floor(lo / IDX), math.floor(hi / IDX)
    if b0 < idx.b0 then b0 = idx.b0 end
    if b1 > idx.b1 then b1 = idx.b1 end
    for b = b0, b1 do
        local l = list[b]
        if not l then
            l = {}   -- (once a bucket; reused after)
            list[b] = l
        end
        local n = cnt[b] + 1
        l[n] = id
        cnt[b] = n
    end
end

--- (rows from the road's top; a little wider than what drawRoad's tests let into a strip)
local function buildIdx(h, s, th, q, tail, head)
    idx.frame, idx.h = road.frame, h
    idx.b0, idx.b1 = math.floor(-32 / IDX), math.floor((h + 32) / IDX)
    for b = idx.b0, idx.b1 do
        idx.dashN[b], idx.trailN[b], idx.stopN[b], idx.emberN[b] = 0, 0, 0, 0
    end
    local dash = road.dash
    for i = 1, road.dashN, 4 do
        local y1, y2 = dash[i + 1], dash[i + 3]
        if y1 > y2 then y1, y2 = y2, y1 end
        idxPut(idx.dash, idx.dashN, y1 - th - 1, y2 + th + 1, i)
    end
    local py, len = road.py, road.len
    for i = 2, #py do
        if len[i] >= tail and len[i - 1] <= head then
            local y1, y2 = py[i - 1], py[i]
            if y1 > y2 then y1, y2 = y2, y1 end
            idxPut(idx.trail, idx.trailN, y1 - th - 1, y2 + th + 1, i)
        end
    end
    for k, si in ipairs(road.stopAt) do
        idxPut(idx.stop, idx.stopN, py[si] - q * 3 - 2, py[si] + q * 3 + 2, k)
    end
    if road.embers then
        for k, e in ipairs(road.embers) do idxPut(idx.ember, idx.emberN, e.y - 2, e.y + 5, k) end
    end
end

local function roadDash(i, x, y, th, am, all, ya, yb)
    local dash = road.dash
    local y1, y2 = y + dash[i + 1], y + dash[i + 3]
    if all or ((y1 >= ya - th or y2 >= ya - th) and (y1 <= yb + th or y2 <= yb + th)) then
        roadBar(x + dash[i], y1, x + dash[i + 2], y2, th, SAND, 0.24 * am)
    end
end

local function roadTrail(i, x, y, th, am, all, ya, yb, tail, head)
    local px, py, len = road.px, road.py, road.len
    if len[i] >= tail and len[i - 1] <= head then
        local y1, y2 = y + py[i - 1], y + py[i]
        if all or ((y1 >= ya - th or y2 >= ya - th) and (y1 <= yb + th or y2 <= yb + th)) then
            local a = (len[i] - tail) / (head - tail + 1)
            roadBar(x + px[i - 1], y1, x + px[i], y2, th, GOLD, 0.85 * a * a * am)
        end
    end
end

-- the stops: hollow squares, lit for a while once the walker has passed them
local function roadStop(ui, si, x, y, s, q, am, all, ya, yb)
    local px, py, len = road.px, road.py, road.len
    local walk, total = road.walk, road.total
    local sx, sy = math.floor(x + px[si] + 0.5), math.floor(y + py[si] + 0.5)
    if all or (sy + q * 3 >= ya and sy - q * 3 <= yb) then
        local passed = walk >= len[si] and walk < total + 400 * s
        local lit = passed and math.max(0, 1 - (walk - len[si]) / (70 * s) / 5) or 0
        ui:drawRect(sx - q, sy - q, q * 2, q * 2, am, DARK.r, DARK.g, DARK.b)
        local b = q - 1
        local ba = (0.25 + 0.6 * lit) * am
        ui:drawRect(sx - b, sy - b, b * 2, 2, ba, GOLD.r, GOLD.g, GOLD.b)
        ui:drawRect(sx - b, sy + b - 2, b * 2, 2, ba, GOLD.r, GOLD.g, GOLD.b)
        ui:drawRect(sx - b, sy - b + 2, 2, b * 2 - 4, ba, GOLD.r, GOLD.g, GOLD.b)
        ui:drawRect(sx + b - 2, sy - b + 2, 2, b * 2 - 4, ba, GOLD.r, GOLD.g, GOLD.b)
        if lit > 0 then
            local m = math.floor(2 * s + 0.5)
            ui:drawRect(sx - m, sy - m, m * 2, m * 2, 0.5 * lit * am, GOLD.r, GOLD.g, GOLD.b)
            local rr = (6 + 10 * (1 - lit)) * s
            ui:drawRectBorder(math.floor(sx - rr + 0.5), math.floor(sy - rr + 0.5), math.floor(rr * 2 + 0.5),
                math.floor(rr * 2 + 0.5), 0.25 * lit * am, GOLD.r, GOLD.g, GOLD.b)
        end
    end
end

local function roadEmber(ui, e, x, y, w, s, t, am, all, ya, yb)
    local ey = y + e.y
    if all or (ey + 3 >= ya and ey <= yb) then
        local k = e.life / e.max
        local fade = math.min(1, e.life * 2) * (1 - k)
        local tw = 0.6 + 0.4 * math.sin(t * 9 + e.ph)
        local mid = math.abs(e.x - w / 2) < w * 0.3 and 0.45 or 1
        local es = math.max(2, math.floor(e.s * s + 0.5))
        ui:drawRect(math.floor(x + e.x + 0.5), math.floor(ey + 0.5), es, es, 0.75 * fade * tw * mid * am, e.c.r, e.c.g, e.c.b)
    end
end

--- The night road over x, y, w, h of `ui` (the caller clips to it); ya, yb: only what reaches
--- into those rows (a fade strip), `am` how much (nil: all of it, whole).
local function drawRoad(ui, x, y, w, h, s, ya, yb, am)
    am = am or 1
    local t = road.t or 0
    local all = ya == nil
    ya, yb = ya or y, yb or (y + h)
    barT, barJo = tex("bar"), ui.javaObject
    barAx, barAy = ui:getAbsoluteX(), ui:getAbsoluteY()
    local xa, xb = x, x + w
    -- 1. the map, drifting (two layers: parallax)
    if not all then
        -- (a fade strip: its parts of the pictures the whole road drew this frame)
        for k = 1, picN, 9 do
            slice(pics[k], pics[k + 1], pics[k + 2], pics[k + 3], pics[k + 4], pics[k + 5] * am,
                pics[k + 6], pics[k + 7], pics[k + 8], xa, xb, ya, yb)
        end
    else
        picN = 0
        local topo = pinnedTex("topo")
        if topo then
            local dx, dy = math.sin(t * 0.05) * 30 * s, math.cos(t * 0.04) * 20 * s
            roadTex(ui, topo, x + dx - 40 * s, y + dy - 30 * s, w + 80 * s, h + 60 * s, 0.17, SAND.r, SAND.g, SAND.b)
            roadTex(ui, topo, x - dx * 1.6 - 60 * s, y - dy * 1.6 + 40 * s, w * 1.25, h * 1.25, 0.07, SAND.r, SAND.g, SAND.b)
        end
        local glow = pinnedTex("glow")
        if glow then
            -- the middle under the text quieter
            local r = w * 0.6
            roadTex(ui, glow, x + w / 2 - r, y + h * 0.55 - r, r * 2, r * 2, 0.55, DARK.r, DARK.g, DARK.b)
            -- fog: three wide soft banks drifting across, slower than the map
            for k = 0, 2 do
                local fx = T.mod(t * (8 + k * 5) * s + k * 420 * s, w + 800 * s) - 400 * s
                local fy = h * (0.35 + 0.22 * k) + math.sin(t * 0.2 + k) * 30 * s
                local fr = 400 * s
                if y + fy + fr > ya and y + fy - fr < yb then
                    roadTex(ui, glow, x + fx - fr, y + fy - fr, fr * 2, fr * 2, 0.045, SAND.r, SAND.g, SAND.b)
                end
            end
            -- 2. the warmth from below, breathing like a fire
            local fl = 0.75 + 0.12 * math.sin(t * 2.1) + 0.08 * math.sin(t * 5.3 + 1) + 0.05 * math.sin(t * 11.7)
            local wr = h * 0.94
            roadTex(ui, glow, x + w / 2 - wr, y + h * 1.12 - wr, wr * 2, wr * 2, 0.30 * fl, EMBER.r, EMBER.g, EMBER.b)
        end
    end
    -- 3. the route: dashed, faint; behind the walker a glowing trail
    local th = math.max(2, math.floor(2 * s + 0.5))
    local walk, total = road.walk, road.total
    local head, tail = math.min(walk, total), math.max(0, math.min(walk, total) - 260 * s)
    local q = math.floor(5 * s + 0.5)
    if all then
        for i = 1, road.dashN, 4 do roadDash(i, x, y, th, am, true, ya, yb) end
        for i = 2, #road.px do roadTrail(i, x, y, th, am, true, ya, yb, tail, head) end
        for _, si in ipairs(road.stopAt) do roadStop(ui, si, x, y, s, q, am, true, ya, yb) end
    else
        if idx.frame ~= road.frame or idx.h ~= h then buildIdx(h, s, th, q, tail, head) end
        stripId = stripId + 1
        local b0, b1 = math.floor((ya - y) / IDX), math.floor((yb - y) / IDX)
        for bk = b0, b1 do
            local l = idx.dash[bk]
            for k = 1, idx.dashN[bk] or 0 do
                local i = l[k]
                if stampD[i] ~= stripId then
                    stampD[i] = stripId
                    roadDash(i, x, y, th, am, false, ya, yb)
                end
            end
        end
        for bk = b0, b1 do
            local l = idx.trail[bk]
            for k = 1, idx.trailN[bk] or 0 do
                local i = l[k]
                if stampT[i] ~= stripId then
                    stampT[i] = stripId
                    roadTrail(i, x, y, th, am, false, ya, yb, tail, head)
                end
            end
        end
        for bk = b0, b1 do
            local l = idx.stop[bk]
            for k = 1, idx.stopN[bk] or 0 do
                local i = l[k]
                if stampS[i] ~= stripId then
                    stampS[i] = stripId
                    roadStop(ui, road.stopAt[i], x, y, s, q, am, false, ya, yb)
                end
            end
        end
    end
    -- the walker: a small lit square with a halo
    if walk <= total and road.wx then
        local wx, wy = math.floor(x + road.wx + 0.5), math.floor(y + road.wy + 0.5)
        if all or (wy + 7 * s >= ya and wy - 7 * s <= yb) then
            local o, m = math.floor(7 * s + 0.5), math.max(2, math.floor(2.5 * s + 0.5))
            ui:drawRect(wx - o, wy - o, o * 2, o * 2, 0.18 * am, GOLD.r, GOLD.g, GOLD.b)
            ui:drawRect(wx - m, wy - m, m * 2, m * 2, 0.95 * am, WALKER.r, WALKER.g, WALKER.b)
        end
    end
    -- 4. embers
    local embers = road.embers
    if embers then
        if all then
            for _, e in ipairs(embers) do roadEmber(ui, e, x, y, w, s, t, am, true, ya, yb) end
        else
            local b0, b1 = math.floor((ya - y) / IDX), math.floor((yb - y) / IDX)
            for bk = b0, b1 do
                local l = idx.ember[bk]
                for k = 1, idx.emberN[bk] or 0 do
                    local i = l[k]
                    if stampE[i] ~= stripId then
                        stampE[i] = stripId
                        roadEmber(ui, embers[i], x, y, w, s, t, am, false, ya, yb)
                    end
                end
            end
        end
    end
end

--- The backdrop of a text panel x, y, w, h: the grid, the light and the bulb at its lower
--- right (partly off the panel: the caller clips to it).
--- The sight of "@back aim" at its place in the panel x, y, w, h, as faded in as `am`.
--- (ya, yb: only what reaches into those rows - a fade strip's; nil: all of it)
local function sight(ui, x, y, w, h, c, lit, am, ya, yb)
    local k = h * 0.3
    local cx, cy = x + w - k * 0.75, y + h - k * 0.7
    local th = math.max(2, T.cell * 0.05)
    local ki = k * (1 - 0.12 * lit)
    if ya then
        linesIn(ui, SIGHT, cx, cy, k, th, c, (0.07 + 0.13 * lit) * am, ya, yb)
        linesIn(ui, SIGHT_IN, cx, cy, ki, th, c, (0.06 + 0.3 * lit) * am, ya, yb)
    else
        lines(ui, SIGHT, cx, cy, k, th, c, (0.07 + 0.13 * lit) * am)
        -- (the inner ring draws in a little as it is aimed, and brightens most)
        lines(ui, SIGHT_IN, cx, cy, ki, th, c, (0.06 + 0.3 * lit) * am)
    end
    local d = math.max(3, math.floor(th * 1.5))
    ui:drawRect(cx - d / 2, cy - d / 2, d, d, (0.1 + 0.6 * lit) * am, T.color.accent.r, T.color.accent.g, T.color.accent.b)
end

function B.draw(ui, kind, x, y, w, h, c, lit)
    if kind == "road" then
        local s = T.cell / 48
        stepRoad(w, h, s)
        drawRoad(ui, x, y, w, h, s)
        return
    end
    if kind == "aim" then
        B.grid(ui, x, y, w, h, c, lit, 1)
        sight(ui, x, y, w, h, c, lit, 1)
        return
    end
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
    if kind == "road" then
        -- (B.draw has run this frame: only what reaches into the strip; the panel inside its frame)
        if am > 0.003 and road.t then drawRoad(ui, x + 2, y0 + 2, w - 4, h0 - 4, T.cell / 48, y, y + h, am) end
        return
    end
    if (kind ~= "power" and kind ~= "aim") or am <= 0.003 then return end
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
    if kind == "aim" then
        -- (the sight only where the strip crosses it; the caller clips to the strip)
        local k = h0 * 0.3
        local cy = y0 + h0 - k * 0.7
        if y + h > cy - 1.2 * k and y < cy + 1.2 * k then sight(ui, x, y0, w, h0, c, lit, am, y, y + h) end
        return
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
