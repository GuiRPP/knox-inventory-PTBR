-- The pinned post's roadmap across (the author's mockup boosty_v1, 2026-10-25): a line in the
-- middle, a card per update above or below it in turn, left to right in time, the stages to
-- come dashed; scrolled by the wheel, a drag or the arrows, faded at its ends.
--
-- Every time the post opens the line fills with gold from its start: a glowing head runs
-- along it (the view following it, both moved in one step of the frame - two clocks made the
-- head double, the author saw it), each date square it reaches lights with a ring, its stem
-- grows and its card comes out; at "now" the head goes into its square, the future's dashes
-- draw on and its stages come up one by one. The first opening after the road got a line
-- runs in full, any later one twice as fast; a wheel or a drag finishes it at once. No sound
-- (the author tried two - "they spoil it all").
--
-- All of it is worked out from the time since the post opened: no timers, nothing made
-- while drawing (the rows and their states are made when the post opens).
-- Sizes are the mockup's at 1080p (cell 48), scaled by the cell.

require "Knox/KnoxTheme"
require "Knox/KnoxNews"

KnoxRoadmap = KnoxRoadmap or {}
local M = KnoxRoadmap
local T = KnoxTheme

local STEP, X0, LINE, TRACK_TOP = 160, 150, 218, 12
local CARD_W, CARD_H, STEM, PV_H = 210, 196, 16, 86
M.LANE_H = 464
local SPEED, WAIT = 0.56, 350      -- px a ms of the head; ms before it starts
M.GOLD = KnoxNews.PINNED_COLOR
local GOLD = M.GOLD
local HEAD = {r = 1, g = 0xf3 / 255, b = 0xd6 / 255}
local NUMBER = {r = 143 / 255, g = 146 / 255, b = 137 / 255}
-- (the game reads Lua files as single bytes: these by their codes)
local LEFT, RIGHT = string.char(8249), string.char(8250)

-- Easing ---------------------------------------------------------------------------

--- CSS's cubic-bezier(x1, y1, x2, y2) at t (0..1): y for the x of t.
function M.bez(x1, y1, x2, y2, t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local u = t
    for _ = 1, 6 do
        local iu = 1 - u
        local x = 3 * iu * iu * u * x1 + 3 * iu * u * u * x2 + u * u * u - t
        local dx = 3 * iu * iu * x1 + 6 * iu * u * (x2 - x1) + 3 * u * u * (1 - x2)
        if math.abs(dx) < 1e-6 then break end
        u = math.max(0, math.min(1, u - x / dx))
    end
    local iu = 1 - u
    return 3 * iu * iu * u * y1 + 3 * iu * u * u * y2 + u * u * u
end
local bez = M.bez

local function easeOut(t) return bez(0, 0, 0.58, 1, t) end
local function easeInOut(t) return bez(0.42, 0, 0.58, 1, t) end
M.easeInOut = easeInOut

-- the head's fire (@keyframes headFire: 3.2 s, ease-in-out between its stops) and its drift
-- (headDrift: 11 s there and back, -7 %..7 %)
local FIRE = {{0, 0.55}, {0.18, 0.8}, {0.24, 0.66}, {0.5, 1}, {0.62, 0.9}, {0.7, 0.97}, {1, 0.55}}

--- Keyframes {{at, value}, ...} at f (0..1), eased between them.
function M.keys(K, f)
    for i = 1, #K - 1 do
        local a, b = K[i], K[i + 1]
        if f <= b[1] then
            return a[2] + (b[2] - a[2]) * easeInOut((f - a[1]) / math.max(1e-6, b[1] - a[1]))
        end
    end
    return K[#K][2]
end

function M.fire(sec) return M.keys(FIRE, T.mod(sec, 3.2) / 3.2) end

function M.drift(sec)
    local f = T.mod(sec, 22) / 11
    if f > 1 then f = 2 - f end
    return -0.07 + 0.14 * easeInOut(f)
end

-- Textures -------------------------------------------------------------------------

-- (only once read: T.readyTex)
local texPath = {}
local function tex(name)
    local p = texPath[name]
    if not p then
        p = "media/ui/knoxmenu/pinned/" .. name .. ".png"
        texPath[name] = p
    end
    return T.readyTex(p)
end
M.tex = tex


--- A soft light (the glow picture) as an ellipse round cx, cy with radii rx, ry.
function M.glow(ui, cx, cy, rx, ry, c, a)
    local g = tex("glow")
    if g and a > 0.003 then ui:drawTextureScaled(g, cx - rx, cy - ry, rx * 2, ry * 2, a, c.r, c.g, c.b) end
end

--- A vertical fade over x, y, w, h: `a` at the top (down = true) or bottom, nothing at the other end.
function M.vfade(ui, x, y, w, h, c, a, down)
    local f = tex("fade")
    if not f then return end
    if down then
        T.quad(ui, f, x, y + h, x, y, x + w, y, x + w, y + h, c, a)
    else
        T.quad(ui, f, x, y, x, y + h, x + w, y + h, x + w, y, c, a)
    end
end

--- A horizontal fade over x, y, w, h: `a` at the right end (or the left: left = true).
function M.hfade(ui, x, y, w, h, c, a, left)
    local f = tex("fade")
    if not f then return end
    if left then
        T.quad(ui, f, x + w, y, x, y, x, y + h, x + w, y + h, c, a)
    else
        ui:drawTextureScaled(f, x, y, w, h, a, c.r, c.g, c.b)
    end
end

-- Clipping: the lane's own rect inside the view; a card's picture and band inside that.
local clipR = {0, 0, 0, 0}
local function clipTo(ui, x, y, w, h)
    local x1, y1 = math.max(x, clipR[1]), math.max(y, clipR[2])
    local x2, y2 = math.min(x + w, clipR[1] + clipR[3]), math.min(y + h, clipR[2] + clipR[4])
    if x2 <= x1 or y2 <= y1 then
        T.clip(ui, x1, y1, 0, 0)
        return false
    end
    T.clip(ui, x1, y1, x2 - x1, y2 - y1)
    return true
end
local function clipBack(ui)
    T.clip(ui, clipR[1], clipR[2], clipR[3], clipR[4])
end

-- State ----------------------------------------------------------------------------

local function lang()
    return string.match(getText("IGUI_Knox_NewsFile"), "news_(%a+)%.txt") or "en"
end

--- The paths of the road's pictures for the current language (asked early by KnoxPinned).
function M.previewPath(preview)
    return "media/knox/news/road/road_" .. preview .. "_" .. lang() .. ".png"
end

--- The road of `post` for one opening: its rows, where "now" is, how fast it plays.
function M.new(post)
    local rows = {}
    local nowI = 0
    for i, r in ipairs(KnoxNews.road(post)) do
        local row = {src = r, i = i, up = (i % 2) == 1, future = r.future,
                     hv = {from = 0, to = 0, at = 0}, pz = {from = 0, to = 0, at = 0}}
        if not r.future then nowI = i end
        if r.preview ~= "" then
            row.texPath = M.previewPath(r.preview)
        end
        table.insert(rows, row)
    end
    local st = {rows = rows, n = #rows, nowI = nowI, sx = 0, want = 0, free = false, hover = nil,
                down = nil, ms = getTimestampMs()}
    -- the first opening after a new line: in full; any later one twice as fast (the line
    -- last seen kept in Knox's settings)
    local now = rows[nowI] and rows[nowI].src
    local key = now and (now.date .. "|" .. now.version) or ""
    st.K = (T.settings["news.roadSeen"] == key) and 0.5 or 1
    if T.settings["news.roadSeen"] ~= key then
        T.settings["news.roadSeen"] = key
        T.saveSettings()
    end
    st.t0 = getTimestampMs()
    -- (the fonts of a card grown under the mouse: asked for now, they load in the background)
    if T.javaFonts then
        local c = T.cell
        for _, f in ipairs({{"head", c * 0.36}, {"body", c * 0.29}, {"head", c * 0.25}}) do
            knoxFontReady(f[1], math.floor(f[2] * 1.07 + 0.5))
        end
    end
    return st
end

--- Sizes for the cell and the lane's width (worked out when they change).
local function layout(st, laneW)
    local s = T.cell / 48
    if st.s == s and st.laneW == laneW then return end
    st.s, st.laneW = s, laneW
    st.trackW = (X0 * 2 + STEP * math.max(0, st.n - 1)) * s
    st.maxS = math.max(0, st.trackW - laneW)
    st.p0 = M.xOf(st, 1) - 60 * s
    st.pn = M.xOf(st, math.max(1, st.nowI))
    st.final = math.max(0, math.min(st.maxS, st.pn - laneW * 0.42))
    st.fontTt = T.fontTab
    st.fontSm = T.javaFonts and T.makeFont("body", T.cell * 0.29) or T.fontText
    st.fontPl = T.fontTile
    st.fontDate = T.fontTile
    st.fontArrow = T.javaFonts and T.makeFont("title", T.cell * 0.46) or T.fontHeader
    local textW = math.floor((CARD_W - 24) * s)
    for _, row in ipairs(st.rows) do
        row.lines = T.wrap(row.src.text, st.fontSm, textW)
    end
end

function M.xOf(st, i)
    return (X0 + STEP * (i - 1)) * st.s
end

--- When row i's square lights (ms since the opening); quick: lit at once by finish().
local function litAt(st, i)
    local K, s = st.K, st.s
    local t
    if i <= st.nowI then
        t = WAIT * K + (M.xOf(st, i) - st.p0) / (SPEED * s / K)
    else
        t = st.tEnd + 250 * K + (180 + (i - st.nowI - 1) * 260) * K
    end
    if st.fin and t > st.fin then return st.fin, true end
    return t, false
end

--- Finish the opening at once (a wheel, a drag, a click during it).
function M.finish(st)
    if st.fin or not st.tEnd then return end
    local e = getTimestampMs() - st.t0
    -- (as the mockup's: only while the head runs; the stages to come keep their pace)
    if e < st.tEnd then
        st.fin = e
        if not st.free then
            st.free = true
            st.want = st.final
        end
    end
end

-- Drawing --------------------------------------------------------------------------

local function animTo(v, to, now)
    if v.to ~= to then
        v.from = M.valueOf(v, now)
        v.to, v.at = to, now
    end
end

--- A spring-eased value: grows with cubic-bezier(.2, .9, .3, 1.2) in 300 ms, settles back
--- with (.2, .9, .3, 1.15) in 400 (the card's grow under the mouse); `pz` - the picture's zoom,
--- (.2, .8, .3, 1) in 450.
function M.valueOf(v, now, pic)
    local dur = pic and 450 or (v.to > v.from and 300 or 400)
    local k = math.min(1, (now - v.at) / dur)
    local e
    if pic then e = bez(0.2, 0.8, 0.3, 1, k)
    elseif v.to > v.from then e = bez(0.2, 0.9, 0.3, 1.2, k)
    else e = bez(0.2, 0.9, 0.3, 1.15, k) end
    return v.from + (v.to - v.from) * e
end

local plR, ttR, smR, dateR = {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}
local plOpts, ttOpts, smOpts, dateOpts = {align = "centre"}, {}, {}, {align = "centre"}
local arrowR, arrowOpts = {0, 0, 0, 0}, {}

local function fontAt(style, base, k)
    if k < 1.005 or type(base) ~= "table" then return base end
    local px = math.floor(base.size * k + 0.5)
    if px == base.size or knoxFontReady(style, px) ~= true then return base end
    return T.makeFont(style, px)
end

--- A plate of the card's meta: its text, fill or a 1 px frame; returns its width.
local function metaPlate(ui, x, y, h, text, font, fill, edge, color, a)
    local w = T.measure(font, text) + math.floor(16 * h / 21)
    plR[1], plR[2], plR[3], plR[4] = x, y, w, h
    if fill then T.rect(ui, x, y, w, h, fill, a) end
    if edge then T.border(ui, x, y, w, h, edge, a) end
    plOpts.font, plOpts.a = font, a
    T.label(ui, text, plR, color, plOpts)
    return w
end

--- One card at its place (cx: its middle, top: its top, k: its scale from the anchor ax, ay).
local function drawCard(ui, st, row, x, y, w, h, k, a, hv, now, sec)
    local s = st.s
    local cur, future = row.i == st.nowI, row.future
    local hot = hv > 0.02
    -- under the mouse: a shadow and a warm rim, it stands over its neighbours
    if hot and not future then
        for i = 1, 6 do
            local o = i * 4 * s
            ui:drawRectBorder(x - o, y - o + 10 * s * hv, w + o * 2, h + o * 2, 0.11 * hv * (1 - i / 7) * a, 0, 0, 0)
        end
        for i = 1, 5 do
            local o = i * 3 * s
            ui:drawRectBorder(x - o, y - o, w + o * 2, h + o * 2, 0.07 * hv * (1 - i / 6) * a, GOLD.r, GOLD.g, GOLD.b)
        end
    end
    -- the card
    if future then
        T.rect(ui, x, y, w, h, T.color.window, 0.9 * a)
    else
        T.rect(ui, x, y, w, h, T.color.window, a)
    end
    local e2 = 2   -- (the frame: 2 px, as every Knox tile's)
    local pvX, pvY, pvW, pvH = x + e2, y + e2, w - e2 * 2, PV_H * s * k
    if clipTo(ui, pvX, pvY, pvW, pvH) then
        if future then
            T.rect(ui, pvX, pvY, pvW, pvH, T.color.cell, a)
            local g = 16 * s * k
            local sand = T.color.accent
            for gx = pvX, pvX + pvW, g do ui:drawRect(gx, pvY, 1, pvH, 0.05 * a, sand.r, sand.g, sand.b) end
            for gy = pvY, pvY + pvH, g do ui:drawRect(pvX, gy, pvW, 1, 0.05 * a, sand.r, sand.g, sand.b) end
            local num = tex("stage_" .. (string.match(row.src.version, "(%d+)%s*$") or ""))
            if num then
                -- (baked at 112 px for the mockup's 56: Knox's atlases go to 44)
                local nh = num:getHeight() * 56 / 112 * s * k
                local nw = num:getWidth() * nh / num:getHeight()
                ui:drawTextureScaled(num, pvX + (pvW - nw) / 2, pvY + (pvH - nh) / 2, nw, nh, 0.35 * a, NUMBER.r, NUMBER.g, NUMBER.b)
            end
        else
            T.rect(ui, pvX, pvY, pvW, pvH, T.color.cell, a)
            local pic = row.texPath and T.readyTex(row.texPath)
            if pic then
                local z = 1 + 0.08 * M.valueOf(row.pz, now, true)
                local zw, zh = pvW * z, pvH * z
                ui:drawTextureScaled(pic, pvX + (pvW - zw) / 2, pvY + (pvH - zh) / 2, zw, zh, (hot and 1 or 0.9) * a, 1, 1, 1)
            end
        end
    end
    -- the band under the picture: the header's colour lit from its line, breathing like a fire
    local bY = y + 88 * s * k
    local bX, bW, bH = x + e2, w - e2 * 2, y + h - e2 - bY
    if clipTo(ui, bX, bY, bW, bH) then
        if not future then
            T.rect(ui, bX, bY, bW, bH, T.color.header, a)
            M.vfade(ui, bX, bY, bW, bH * 0.7, GOLD, 0.05 * a, true)
            local d = -(row.i - 1) * 0.7
            local fire = M.fire(sec - d)
            local ew = bW * 1.3
            local cx = bX + bW / 2 + M.drift(sec - d * 2.3) * ew
            M.glow(ui, cx, bY, ew * 0.5 / 0.8, bH * 1.1 / 0.8, GOLD, (cur and 0.27 or 0.17) * fire * a)
        end
    end
    clipBack(ui)
    -- its line on top: gold for "now", dashed for the future, light under the mouse
    local lc = hot and T.color.bright or (cur and GOLD or T.color.tileFrame)
    if future then
        local dsh = 6 * s
        for dx = bX, bX + bW - 1, dsh * 2 do T.rect(ui, dx, bY, math.min(dsh, bX + bW - dx), 2, T.color.tileFrame, a) end
        -- the dashed frame
        for dx = x, x + w - 1, dsh * 2 do
            T.rect(ui, dx, y, math.min(dsh, x + w - dx), 2, T.color.tileFrame, a)
            T.rect(ui, dx, y + h - 2, math.min(dsh, x + w - dx), 2, T.color.tileFrame, a)
        end
        for dy = y, y + h - 1, dsh * 2 do
            T.rect(ui, x, dy, 2, math.min(dsh, y + h - dy), T.color.tileFrame, a)
            T.rect(ui, x + w - 2, dy, 2, math.min(dsh, y + h - dy), T.color.tileFrame, a)
        end
    else
        T.rect(ui, bX, bY, bW, 2, lc, a)
        T.tileFrame(ui, x, y, w, h, lc, a)
    end
    -- the version's plate (and "Now"), the title, the line
    local ph = math.floor(21 * s * k + 0.5)
    local mx, my = x + 12 * s * k, y + 100 * s * k
    local plf = fontAt("head", st.fontPl, k)
    local v = row.src.version
    local pw
    if future then
        pw = metaPlate(ui, mx, my, ph, v, plf, nil, T.color.dim, T.color.dim, a)
    elseif cur then
        pw = metaPlate(ui, mx, my, ph, v, plf, GOLD, nil, T.color.ink, a)
        metaPlate(ui, mx + pw + 6 * s * k, my, ph, getText("IGUI_Knox_RoadNow"), plf, T.color.ok, nil, T.color.ink, a)
    else
        metaPlate(ui, mx, my, ph, v, plf, nil, T.color.accent, T.color.accent, a)
    end
    local ttf = fontAt("head", st.fontTt, k)
    ttR[1], ttR[2], ttR[3], ttR[4] = mx, y + 129 * s * k, w - 24 * s * k, 20 * s * k
    ttOpts.font, ttOpts.a = ttf, a
    T.label(ui, row.src.title, ttR, future and T.color.text or T.color.bright, ttOpts)
    local smf = fontAt("body", st.fontSm, k)
    smOpts.font, smOpts.a = smf, a
    local ly = y + 151 * s * k
    for _, l in ipairs(row.lines) do
        smR[1], smR[2], smR[3], smR[4] = mx, ly, w - 24 * s * k, 18 * s * k
        T.label(ui, l, smR, future and T.color.dim or T.color.text, smOpts)
        ly = ly + 18 * s * k
    end
end

--- The lane at lx, ly of `ui`, lw wide (M.LANE_H * scale high), clipped to `view` {x, y, w, h}.
function M.draw(ui, st, lx, ly, lw, view)
    layout(st, lw)
    local s = st.s
    local now = getTimestampMs()
    local e = now - st.t0
    local sec = now / 1000
    local K = st.K
    if not st.tEnd then st.tEnd = WAIT * K + (st.pn - st.p0) / (SPEED * s / K) end
    local laneH = M.LANE_H * s
    st.rect = st.rect or {0, 0, 0, 0}
    st.rect[1], st.rect[2], st.rect[3], st.rect[4] = lx, ly, lw, laneH
    -- the lane inside the view
    local y1, y2 = math.max(ly, view[2]), math.min(ly + laneH, view[2] + view[4])
    if y2 <= y1 then return end
    clipR[1], clipR[2], clipR[3], clipR[4] = lx, y1, lw, y2 - y1
    -- the head and the view move in one step (the author saw the head double with two clocks)
    local running = not st.fin and e < st.tEnd
    local hx = st.pn
    if running then
        hx = math.min(st.pn, st.p0 + math.max(0, e - WAIT * K) * SPEED * s / K)
        st.want = math.max(0, math.min(st.final, hx - lw * 0.55))
    elseif not st.free then
        st.free = true
        st.want = st.final
    end
    -- the drag, followed here (the reader takes no mouse moves of its own)
    local mxu, myu = ui:getMouseX(), ui:getMouseY()
    if st.down then
        if not isMouseButtonDown(0) then
            local d = st.down
            st.down = nil
            if d.moved < 6 * s and d.row and st.hover == d.row and st.onOpen then st.onOpen(st.rows[d.row]) end
        else
            st.down.moved = math.max(st.down.moved, math.abs(mxu - st.down.x))
            st.want = math.max(0, math.min(st.maxS, st.down.sx - (mxu - st.down.x)))
        end
    end
    local dt = math.min(100, now - (st.ms or now))
    st.ms = now
    st.sx = st.sx + (st.want - st.sx) * (1 - math.pow(0.86, dt / 16.7))
    if math.abs(st.want - st.sx) < 0.5 then st.sx = st.want end
    local ox = lx - math.floor(st.sx + 0.5)
    local lineY = ly + (TRACK_TOP + LINE) * s
    clipBack(ui)

    -- the line: grey where it is to come, gold as far as the head has run; the future dashed
    T.rect(ui, ox + st.p0, lineY, st.pn - st.p0, 2, T.color.tileFrame, 0.55)
    if hx > st.p0 then T.rect(ui, ox + st.p0, lineY, hx - st.p0, 2, GOLD) end
    if st.nowI < st.n then
        local nextAt = st.tEnd + 250 * K
        if st.fin and nextAt > st.fin then nextAt = st.fin end
        local k = math.max(0, math.min(1, (e - nextAt) / 900))
        local x0 = ox + st.pn
        local x1 = x0 + (M.xOf(st, st.n) + 60 * s - st.pn) * k
        local dsh = 6 * s
        for dx = x0, x1 - 1, dsh * 2 do T.rect(ui, dx, lineY, math.min(dsh, x1 - dx), 2, T.color.tileFrame) end
    end

    -- stems, squares, dates
    local stemH = STEM * s
    local q = math.floor(5 * s + 0.5)
    for i, row in ipairs(st.rows) do
        local cx = ox + M.xOf(st, i)
        local t, quick = litAt(st, i)
        local age = e - t
        row.age = age
        -- (far off the lane: nothing to draw)
        if cx > lx - CARD_W * s and cx < lx + lw + CARD_W * s then
            local sk = math.max(0, math.min(1, easeOut((age - 70 * K) / 160)))
            if sk > 0 then
                if row.up then
                    T.rect(ui, cx - 1, lineY - stemH * sk, 2, stemH * sk, T.color.tileFrame)
                else
                    T.rect(ui, cx - 1, lineY + 2, 2, stemH * sk, T.color.tileFrame)
                end
            end
            local nx, ny = cx - q, lineY - 4 * s
            if row.future then
                local na = math.max(0, math.min(1, age / 300))
                if na > 0 then
                    T.rect(ui, nx, ny, q * 2, q * 2, T.color.cell, na)
                    T.tileFrame(ui, nx, ny, q * 2, q * 2, T.color.dim, na)
                end
            elseif age >= 0 then
                if i == st.nowI then
                    -- "now" breathes once lit
                    local b = 0.5 - 0.5 * math.cos(sec / 1.25 * math.pi * 2)
                    local r = math.floor(3 * s + 0.5)
                    T.rect(ui, nx - r, ny - r, q * 2 + r * 2, q * 2 + r * 2, GOLD, 0.28 * b)
                end
                T.rect(ui, nx, ny, q * 2, q * 2, GOLD)
            else
                T.rect(ui, nx, ny, q * 2, q * 2, T.color.cell)
                T.tileFrame(ui, nx, ny, q * 2, q * 2, T.color.tileFrame)
            end
            -- the ring as the head reaches it
            if not quick and age >= 0 and age < 550 then
                local f = easeOut(age / 550)
                local rs = 20 * s * (0.5 + 1.4 * f)
                local ra = 0.9 * (1 - f)
                local rx, ry = cx - rs / 2, lineY + 1 - rs / 2
                T.tileFrame(ui, rx, ry, rs, rs, GOLD, ra)
            end
            -- the date: under the line for a card above it, over it for one below
            if row.src.date ~= "" then
                local da = math.max(0, math.min(1, (age - 70 * K) / 250))
                if da > 0 then
                    dateR[1], dateR[2], dateR[3], dateR[4] = cx - 40 * s, row.up and (lineY + 12 * s) or (lineY - 29 * s), 80 * s, 15 * s
                    dateOpts.font, dateOpts.a = st.fontDate, da
                    T.label(ui, row.src.date, dateR, T.color.dim, dateOpts)
                end
            end
        end
    end

    -- the cards: the one under the mouse last, over its neighbours
    local over = ui:isMouseOver() and T.inRect(mxu, myu, clipR)
    local hover = nil
    for i, row in ipairs(st.rows) do
        local cx = ox + M.xOf(st, i)
        local top = ly + TRACK_TOP * s + (row.up and (LINE - STEM - CARD_H) or (LINE + 2 + STEM)) * s
        row.x, row.y, row.w, row.h = cx - CARD_W * s / 2, top, CARD_W * s, CARD_H * s
        if over and not row.future and row.age and row.age >= 190 * K and mxu >= row.x and mxu < row.x + row.w
                and myu >= row.y and myu < row.y + row.h then
            hover = i
        end
    end
    st.hover = hover
    -- (the cards still settling back over the others, the one under the mouse over them all:
    -- one "raised" card was kept, so the card the mouse had just left was not drawn at all
    -- while it settled - "the previews vanish", the author 2026-10-25)
    for i, row in ipairs(st.rows) do
        animTo(row.hv, hover == i and 1 or 0, now)
        animTo(row.pz, hover == i and 1 or 0, now)
        local hv = M.valueOf(row.hv, now)
        row.hvNow = hv
        if hv <= 0.001 then M.drawRow(ui, st, row, hv, now, sec) end
    end
    for i, row in ipairs(st.rows) do
        if row.hvNow > 0.001 and hover ~= i then M.drawRow(ui, st, row, row.hvNow, now, sec) end
    end
    if hover then M.drawRow(ui, st, st.rows[hover], st.rows[hover].hvNow, now, sec) end
    clipBack(ui)

    -- the head
    local hAge = running and 0 or (e - math.min(st.tEnd, st.fin or st.tEnd))
    if running or hAge < 180 then
        local f = running and 1 or (1 - hAge / 180)
        local hs = 12 * s * (0.4 + 0.6 * f)
        local hcx, hcy = ox + hx, lineY + 1
        M.glow(ui, hcx, hcy, 36 * s, 36 * s, GOLD, 0.25 * f)
        M.glow(ui, hcx, hcy, 18 * s, 18 * s, GOLD, 0.75 * f)
        T.rect(ui, hcx - hs / 2, hcy - hs / 2, hs, hs, HEAD, f)
    end

    -- the ends fade into the panel; the arrows
    local fw = 70 * s
    M.hfade(ui, lx, y1, fw, y2 - y1, T.color.window, 0.95, true)
    M.hfade(ui, lx + lw - fw, y1, fw, y2 - y1, T.color.window, 0.95, false)
    st.arrowL = st.arrowL or {0, 0, 0, 0}
    st.arrowR = st.arrowR or {0, 0, 0, 0}
    local as = math.floor(32 * s + 0.5)
    local ay = ly + 203 * s
    st.arrowL[1], st.arrowL[2], st.arrowL[3], st.arrowL[4] = lx + 12 * s, ay, as, as
    st.arrowR[1], st.arrowR[2], st.arrowR[3], st.arrowR[4] = lx + lw - 12 * s - as, ay, as, as
    M.arrow(ui, st.arrowL, LEFT, st.sx > 1, mxu, myu)
    M.arrow(ui, st.arrowR, RIGHT, st.sx < st.maxS - 1, mxu, myu)
    T.unclip(ui)
end

--- An arrow button: a dark plate, a 1 px frame - sand and light under the mouse; dimmed when
--- the lane can go no further that way.
function M.arrow(ui, r, glyph, on, mx, my)
    local hot = on and T.inRect(mx, my, r)
    local a = on and 1 or 0.3
    arrowOpts.fill, arrowOpts.edge, arrowOpts.font, arrowOpts.a = T.color.buttonBg, hot and T.color.accent or T.color.tileEdge, nil, a
    arrowOpts.color = hot and T.color.bright or T.color.text
    T.plate(ui, r, glyph, arrowOpts)
end

--- A card, grown under the mouse from its stem by hv (0..1 eased; up to 7 %).
function M.drawRow(ui, st, row, hv, now, sec)
    local age = (row.age or -1) - 190 * st.K
    if age < 0 then return end
    local s = st.s
    -- coming out: from a little off the line, a little small (opacity .35 s, its move .4 s)
    local oa = easeOut(math.min(1, age / 350))
    local mk = bez(0.2, 0.9, 0.3, 1.15, math.min(1, age / 400))
    local from = (row.up and -10 or 10) * s * (1 - mk)
    local k0 = 0.96 + 0.04 * mk
    local k = k0 * (1 + 0.07 * hv)
    local w, h = row.w * k, row.h * k
    local ax = row.x + row.w / 2
    local x = ax - w / 2
    local y
    if row.up then y = row.y + row.h - h else y = row.y end
    y = y + from
    drawCard(ui, st, row, x, y, w, h, k, oa, hv, now, sec)
end

-- Mouse ----------------------------------------------------------------------------

--- A press in the lane: finishes the opening; an arrow scrolls by two steps; else a drag
--- starts (a press that has not moved 6 px when let go is a click on its card).
function M.onMouseDown(st, x, y)
    if not st.rect or not T.inRect(x, y, st.rect) then return false end
    M.finish(st)
    if st.arrowL and T.inRect(x, y, st.arrowL) then
        st.want = math.max(0, st.want - STEP * 2 * st.s)
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    if st.arrowR and T.inRect(x, y, st.arrowR) then
        st.want = math.min(st.maxS, st.want + STEP * 2 * st.s)
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    st.down = {x = x, sx = st.want, moved = 0, row = st.hover}
    return true
end

--- The wheel over the lane: across it, and the opening finished.
function M.onMouseWheel(st, x, y, del)
    if not st.rect or not T.inRect(x, y, st.rect) then return false end
    M.finish(st)
    st.want = math.max(0, math.min(st.maxS or 0, st.want + del * 90 * st.s))
    return true
end

return KnoxRoadmap
