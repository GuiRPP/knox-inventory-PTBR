-- The pinned post: the roadmap and Boosty (the author's mockup boosty_v1 and its SPEC.md,
-- 2026-10-25). KnoxMenuNews's reader draws it through this when the post's type is "pinned".
--   its card     always the first; gold, the camp under a dark gradient, and every 7 s a soft
--                slanted light passes over it, its frame catching it as it goes
--   the head     two lines of one size, a warm gradient under them - the gold line below
--                lights the head like the fire, breathing, its middle wandering
--   the text     on the night road (KnoxNewsBack "road"): the post's paragraph, the support
--                block (its button opens Boosty in the browser, shimmering under the mouse),
--                the roadmap's title between two lines and the roadmap itself (KnoxRoadmap)
--   the right    Knox's coin, turning in the light over a lit grid; "thank you" under it
-- A roadmap card opens its update's post over the text (its picture and opening paragraphs,
-- as the mockup's); "< Roadmap" or Backspace brings the road back where it was.
-- Sizes are the mockup's at 1080p (cell 48), scaled by the cell.

require "Knox/KnoxTheme"
require "Knox/KnoxNews"
require "Knox/KnoxNewsBack"
require "Knox/KnoxRoadmap"

KnoxPinned = KnoxPinned or {}
local P = KnoxPinned
local T = KnoxTheme
local M = KnoxRoadmap
local GOLD = KnoxNews.PINNED_COLOR
local bez = M.bez
local tex = M.tex

P.URL = "https://boosty.to/knoxinventory/donate"
local DOT = string.char(183)
local SHINE = {r = 1, g = 226 / 255, b = 160 / 255}
local SHINE_FRAME = {r = 1, g = 250 / 255, b = 232 / 255}
local BUTTON_HOT = {r = 0xeb / 255, g = 0xd2 / 255, b = 0x9b / 255}
local EDGE_LIGHT = {r = 0xa8 / 255, g = 0x95 / 255, b = 0x5f / 255}
local EDGE_DARK = {r = 0x7d / 255, g = 0x6e / 255, b = 0x44 / 255}
local DARK = {r = 0, g = 0, b = 0}
local FACE = {r = 1, g = 1, b = 1}
local WHITE = {r = 1, g = 1, b = 1}

--- Every picture of the news asked for at the game's start (T.preloadTex): read by the time
--- they are shown, never the game's red-white squares in their place (the author, 2026-10-25).
local PINNED_PICS = {"banner", "logo", "logo_clean_128", "logo_clean_64", "glow", "fade", "band", "topo",
                     "coin_lines", "coin_fill", "pin"}
function P.preload()
    local paths = {"media/ui/knoxdash/disc.png", "media/ui/knoxdash/bar.png", "media/ui/knoxdash/soft.png", "media/ui/knoxmenu/news_banner.png", "media/ui/knoxmenu/news_art.png"}
    local base = "media/ui/knoxmenu/pinned/"
    for _, n in ipairs(PINNED_PICS) do table.insert(paths, base .. n .. ".png") end
    for i = 0, 31 do table.insert(paths, base .. string.format("glint_%02d.png", i)) end
    for i = 1, 9 do table.insert(paths, base .. "stage_" .. i .. ".png") end
    for _, post in ipairs(KnoxNews.load()) do
        for _, line in ipairs(post.body or {}) do
            local s = string.gsub(line, "^%s+", "")
            local road = string.match(s, "^@road%s+(.*)$")
            if road then
                local f = {}
                for v in string.gmatch(road .. "|", "([^|]*)|") do table.insert(f, (string.gsub(v, "^%s*(.-)%s*$", "%1"))) end
                if f[5] and f[5] ~= "" then table.insert(paths, M.previewPath(f[5])) end
            else
                local file = string.match(s, "^@banner%s+(%S+%.png)") or string.match(s, "^@art%s+(%S+%.png)")
                    or string.match(s, "^@%s*(%S+%.png)%s*$")
                if file then table.insert(paths, "media/knox/news/" .. file) end
            end
        end
    end
    T.preloadTex(paths)
end

--- Boosty in the browser (the support button, the bottom bar's coin). Through the Java
--- part: the game's openUrl drops any site but its own (the button did nothing - the
--- author, 2026-10-25).
function P.openBoosty()
    getSoundManager():playUISound("UIActivateButton")
    if knoxOpenUrl then knoxOpenUrl(P.URL) end
end

-- The shimmer ----------------------------------------------------------------------

--- Where the shimmer's light is at `sec` of a cycle of `cycle` s, as the mockup's
--- @keyframes shine: from the left (1) to the right (0) in the first 38 %, then resting off.
local function shineAt(sec, cycle)
    local f = T.mod(sec, cycle) / cycle
    if f >= 0.38 then return 0 end
    return 1 - bez(0.45, 0.05, 0.35, 1, f / 0.38)
end

--- The slanted band (105 deg) over x, y, w, h at position p (1: off to the left, 0: off to
--- the right), its width a part `bw` of the box; the caller clips.
local function band(ui, x, y, w, h, p, bw, c, a)
    local t = tex("band")
    if not t or a <= 0.003 then return end
    local cx = x + (0.5 - p * 2 / 3) * 3 * w
    local half = bw * 3 * w / 2
    local slant = 0.268 * h / 2
    T.quad(ui, t, cx - half + slant, y, cx + half + slant, y, cx + half - slant, y + h, cx - half - slant, y + h, c, a)
end

--- The pinned card's light: over the card (a little past its frame), and brighter on the frame.
function P.cardShine(ui, x, y, w, h)
    if not T.animOn() then return end
    local p = shineAt(getTimestampMs() / 1000, 7)
    if p <= 0 then return end
    T.clip(ui, x, y, w, h)
    band(ui, x - 4, y - 4, w + 8, h + 8, p, 0.24, SHINE, 0.34)
    -- the frame catches it (4 px all round)
    local t = 4
    local sides = P.sides or {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}
    P.sides = sides
    sides[1][1], sides[1][2], sides[1][3], sides[1][4] = x, y, w, t
    sides[2][1], sides[2][2], sides[2][3], sides[2][4] = x, y + h - t, w, t
    sides[3][1], sides[3][2], sides[3][3], sides[3][4] = x, y + t, t, h - t * 2
    sides[4][1], sides[4][2], sides[4][3], sides[4][4] = x + w - t, y + t, t, h - t * 2
    for _, r in ipairs(sides) do
        T.clip(ui, r[1], r[2], r[3], r[4])
        band(ui, x, y, w, h, p, 0.2, SHINE_FRAME, 0.95)
    end
    T.unclip(ui)
end

--- The card's banner: the camp under its dark gradient (tools\make_pinned_art.py).
function P.banner()
    return tex("banner")
end

--- The pin on the PINNED plate, ink on gold, s px.
function P.pin(ui, x, y, s, c)
    local t = tex("pin")
    if t then ui:drawTextureScaled(t, x, y, s, s, 1, c.r, c.g, c.b) end
end

-- The coin --------------------------------------------------------------------------

-- @keyframes coinSway / coinShade / coinGlint / coinShadow of the mockup, a 10 s cycle:
-- it sways in the light, and at two thirds turns over once - darker edge on, its shadow narrower
local SHADE = {{0, 0.08}, {0.66, 0.08}, {0.72, 0.5}, {0.75, 0.1}, {0.8, 0.45}, {0.85, 0.08}, {1, 0.08}}
local SHADOW_W = {{0, 1}, {0.66, 1}, {0.72, 0.35}, {0.76, 0.9}, {0.81, 0.35}, {0.88, 1}, {1, 1}}
local SHADOW_A = {{0, 1}, {0.66, 1}, {0.72, 0.7}, {0.81, 0.7}, {0.88, 1}, {1, 1}}
local GLINTS = 32
local GLINT_NAMES = {}
for i = 0, GLINTS - 1 do GLINT_NAMES[i] = string.format("glint_%02d", i) end
local DISC = "media/ui/knoxdash/disc.png"

local function sway(f)
    local rx, ry
    if f < 0.33 then
        local k = M.easeInOut(f / 0.33)
        rx, ry = 7 + (-5 - 7) * k, -18 + (16 + 18) * k
    elseif f < 0.66 then
        local k = M.easeInOut((f - 0.33) / 0.33)
        rx, ry = -5 + (7 + 5) * k, 16 + (-18 - 16) * k
    elseif f < 0.9 then
        local k = bez(0.55, 0, 0.3, 1, (f - 0.66) / 0.24)
        rx, ry = 7, -18 + 360 * k
    else
        rx, ry = 7, 342
    end
    return math.rad(rx), math.rad(ry)
end

local function glintAt(f)
    if f < 0.33 then return 1 + (0.62 - 1) * M.easeInOut(f / 0.33) end
    if f < 0.66 then return 0.62 + (1 - 0.62) * M.easeInOut((f - 0.33) / 0.33) end
    if f < 0.76 then return 1 - M.easeInOut((f - 0.66) / 0.1) end
    return 1
end

-- the coin's corners on the screen (kept: worked out every frame)
local Q = {0, 0, 0, 0, 0, 0, 0, 0}
local cosX, sinX, cosY, sinY, ccx, ccy = 1, 0, 1, 0, 0, 0

--- A point of the coin (its middle at 0, 0, 0; y down) on the screen. (Without perspective: a
--- quad is drawn as two triangles with no correction, so a face in perspective broke along
--- its diagonal - "the coin is crooked", the author 2026-10-25; turned at most 18 degrees,
--- the parallel view looks the same and its circle stays an ellipse.)
local function project(x, y, z)
    local x1 = x * cosY + z * sinY
    local z1 = -x * sinY + z * cosY
    local y2 = y * cosX - z1 * sinX
    local z2 = y * sinX + z1 * cosX
    return ccx + x1, ccy + y2
end

--- The square r (half its side) at depth z on the screen into Q; `mirror` - seen from behind.
local function square(r, z, mirror)
    local l, rr = -r, r
    if mirror then l, rr = r, -r end
    Q[1], Q[2] = project(l, -r, z)
    Q[3], Q[4] = project(rr, -r, z)
    Q[5], Q[6] = project(rr, r, z)
    Q[7], Q[8] = project(l, r, z)
end

local function drawCoin(ui, cx, cy, size, sec)
    local s = size / 300
    local f = T.mod(sec, 10) / 10
    local rx, ry = sway(f)
    cosX, sinX, cosY, sinY = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry)
    ccx, ccy = cx, cy
    local face = tex("logo")
    local disc = T.readyTex(DISC)
    -- facing us: the front; else the back (the same face, mirrored)
    local front = cosX * cosY > 0
    -- the reeded edge: discs a px apart between the faces, light and dark in turn, far to near
    if disc then
        local r = size / 2 - s
        for i = 0, 16 do
            local z = front and (i - 8) or (8 - i)
            square(r, z * s, false)
            local c = (T.mod(z, 2) == 1) and EDGE_LIGHT or EDGE_DARK
            T.quad(ui, disc, Q[1], Q[2], Q[3], Q[4], Q[5], Q[6], Q[7], Q[8], c, 1)
        end
    end
    local shade = M.keys(SHADE, f)
    local half = size / 2
    if face then
        local k = 1 - shade
        FACE.r, FACE.g, FACE.b = k, k, k
        square(half, (front and 9 or -9) * s, not front)
        T.quad(ui, face, Q[1], Q[2], Q[3], Q[4], Q[5], Q[6], Q[7], Q[8], FACE, 1)
        if front then
            -- (two frames crossfaded: one by one they stepped - "the glints lag", the author 2026-10-25)
            local gp = glintAt(f) * (GLINTS - 1)
            local g0 = math.floor(gp)
            local t = gp - g0
            local g = tex(GLINT_NAMES[g0])
            if g and t < 1 then T.quad(ui, g, Q[1], Q[2], Q[3], Q[4], Q[5], Q[6], Q[7], Q[8], WHITE, 1 - t) end
            g = g0 < GLINTS - 1 and t > 0 and tex(GLINT_NAMES[g0 + 1])
            if g then T.quad(ui, g, Q[1], Q[2], Q[3], Q[4], Q[5], Q[6], Q[7], Q[8], WHITE, t) end
        end
    end
end

--- The right panel: a lit grid, a soft breathing glow, the coin and its shadow, "thank you".
local capR, capOpts = {0, 0, 0, 0}, {}
function P.drawRight(ui, x, y, w, h)
    local s = T.cell / 48
    local sec = getTimestampMs() / 1000
    T.rect(ui, x, y, w, h, T.color.cell)
    -- the grid, 48 px, from the middle
    local g = 48 * s
    local mx = x + w / 2
    local gx = mx - g / 2 - math.floor((w / 2) / g + 1) * g
    while gx < x + w do
        if gx >= x then ui:drawRect(math.floor(gx), y, 1, h, 0.06, GOLD.r, GOLD.g, GOLD.b) end
        gx = gx + g
    end
    local my = y + h / 2
    local gy = my - g / 2 - math.floor((h / 2) / g + 1) * g
    while gy < y + h do
        if gy >= y then ui:drawRect(x, math.floor(gy), w, 1, 0.06, GOLD.r, GOLD.g, GOLD.b) end
        gy = gy + g
    end
    local cx, cy = x + w / 2, y + h * 0.42
    T.clip(ui, x, y, w, h)
    local pulse = 0.75 + 0.25 * M.easeInOut(1 - math.abs(T.mod(sec, 4) / 2 - 1))
    M.glow(ui, cx, cy, 310 * s * 0.62 / 0.8, 310 * s * 0.62 / 0.8, GOLD, 0.16 * pulse)
    -- the coin, its shadow under it
    local size = 300 * s
    -- (the shadow first: the coin stands over it)
    local f = T.mod(sec, 10) / 10
    local sw, sa = M.keys(SHADOW_W, f), M.keys(SHADOW_A, f)
    M.glow(ui, cx, cy + (168 + 13) * s, 115 * s * sw / 0.8, 13 * s / 0.8, DARK, 0.6 * sa)
    drawCoin(ui, cx, cy, size, sec)
    T.unclip(ui)
    local font = P.bigFont()
    capOpts.font, capOpts.ls = font, s
    capR[1], capR[2], capR[3], capR[4] = x, cy + 190 * s, w, 42 * s
    T.spaced(ui, getText("IGUI_Knox_PinnedThanks"), capR, T.color.bright, capOpts)
    capR[2] = capR[2] + 42 * s
    T.spaced(ui, T.upper(getText("IGUI_Knox_PinnedThanks2")), capR, GOLD, capOpts)
end

--- 35 px bold at 1080p: the head's lines and "thank you".
function P.bigFont()
    return T.javaFonts and T.makeFont("title", math.min(44, T.cell * 0.72)) or UIFont.Large
end

-- The post ---------------------------------------------------------------------------

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

--- The pinned post's body as blocks: paragraphs, the support block, the roadmap (where its
--- first @road line stands).
local function blocksOf(post, textW, font)
    local blocks, para = {}, {}
    local function flush()
        if #para > 0 then
            table.insert(blocks, {kind = "text", lines = T.wrap(table.concat(para, " "), font, textW)})
            para = {}
        end
    end
    local road = false
    for _, line in ipairs(post.body) do
        local s = trim(line)
        if s == "" then
            flush()
        elseif string.match(s, "^@boosty") then
            flush()
            table.insert(blocks, {kind = "boosty"})
        elseif string.match(s, "^@road") then
            flush()
            if not road then
                road = true
                table.insert(blocks, {kind = "road"})
            end
        elseif string.sub(s, 1, 1) ~= "@" and string.sub(s, 1, 1) ~= ";" then
            table.insert(para, s)
        end
    end
    flush()
    return blocks
end

local paraR, paraOpts = {0, 0, 0, 0}, {align = "centre"}
local btnR, btnOpts = {0, 0, 0, 0}, {align = "centre"}
local labR, labOpts = {0, 0, 0, 0}, {}
local headR, headOpts = {0, 0, 0, 0}, {}

--- Fonts and texts of the support block for this width (worked out when they change).
local function supportLayout(st, colW, s)
    if st.supW == colW then return end
    st.supW = colW
    st.fB = T.fontHeader
    st.fSpan = T.fontText
    st.fBtn = T.fontCaps
    st.fUnder = T.javaFonts and T.makeFont("body", T.cell * 0.25) or T.fontTile
    st.btnText = T.upper(getText("IGUI_Knox_PinnedButton"))
    st.under = getText("IGUI_Knox_PinnedUnder")
    st.btnW = T.measure(st.fBtn, st.btnText) + 48 * s
    st.rightW = math.max(st.btnW, T.measure(st.fUnder, st.under))
    local txtW = colW - 4 - 40 * s - 64 * s - 20 * s - 20 * s - st.rightW
    st.txtW = txtW
    st.spanLines = T.wrap(getText("IGUI_Knox_PinnedSupportText"), st.fSpan, txtW)
    local txtH = 24 * s + 2 * s + #st.spanLines * 20 * s
    st.supInner = math.max(64 * s, txtH, 34 * s + 6 * s + 15 * s)
    st.supH = st.supInner + 30 * s + 4
end

--- The support block at x, y (colW wide); returns its height.
local function drawSupport(ui, st, x, y, colW, s, mx, my, now)
    supportLayout(st, colW, s)
    local h = st.supH
    -- a light gold wash, top to bottom, in a 2 px gold frame
    T.rect(ui, x, y, colW, h, GOLD, 0.02)
    M.vfade(ui, x, y, colW, h, GOLD, 0.05, true)
    T.tileFrame(ui, x, y, colW, h, GOLD)
    local ix, iy = x + 2 + 20 * s, y + 2 + 16 * s
    local inner = st.supInner
    local logo = tex("logo_clean_128")
    if logo then ui:drawTextureScaled(logo, ix, iy + (inner - 64 * s) / 2, 64 * s, 64 * s, 1, 1, 1, 1) end
    -- the text
    local tx = ix + 64 * s + 20 * s
    local txtH = 24 * s + 2 * s + #st.spanLines * 20 * s
    local ty = iy + (inner - txtH) / 2
    labR[1], labR[2], labR[3], labR[4] = tx, ty, st.txtW, 24 * s
    labOpts.font, labOpts.align = st.fB, nil
    T.label(ui, getText("IGUI_Knox_PinnedSupport"), labR, T.color.bright, labOpts)
    ty = ty + 26 * s
    labOpts.font = st.fSpan
    for _, l in ipairs(st.spanLines) do
        labR[2], labR[4] = ty, 20 * s
        T.label(ui, l, labR, T.color.text, labOpts)
        ty = ty + 20 * s
    end
    -- the button, "opens in your browser" under it
    local colH = 34 * s + 6 * s + 15 * s
    local rx = x + colW - 2 - 20 * s - st.rightW
    local by = iy + (inner - colH) / 2
    -- (on whole pixels: at a fraction its 1 px frames fell between pixels, uneven - "the button
    -- is crooked", the author 2026-10-25)
    btnR[1], btnR[2] = math.floor(rx + st.rightW - st.btnW + 0.5), math.floor(by + 0.5)
    btnR[3], btnR[4] = math.floor(st.btnW + 0.5), math.floor(34 * s + 0.5)
    st.btn = st.btn or {0, 0, 0, 0}
    st.btn[1], st.btn[2], st.btn[3], st.btn[4] = btnR[1], btnR[2], btnR[3], btnR[4]
    local hot = st.inView and T.inRect(mx, my, btnR)
    if hot and not st.btnHotAt then st.btnHotAt = now end
    if not hot then st.btnHotAt = nil end
    T.rect(ui, btnR[1], btnR[2], btnR[3], btnR[4], hot and BUTTON_HOT or GOLD)
    -- under the mouse it shimmers as the card does: the same light, ~1 s over it, every 2.6 s,
    -- under its caption (the letters stay sharp)
    if hot and T.animOn() then
        local p = shineAt((now - st.btnHotAt) / 1000, 2.6)
        if p > 0 then
            T.clip(ui, btnR[1], btnR[2], btnR[3], btnR[4])
            band(ui, btnR[1], btnR[2], btnR[3], btnR[4], p, 0.24, SHINE, 0.62)
            if st.clip then T.clip(ui, st.clip[1] + 2, st.clip[2], st.clip[3] - 4, st.clip[4]) end
        end
        T.border(ui, btnR[1], btnR[2], btnR[3], btnR[4], T.color.bright)
        T.border(ui, btnR[1] + 1, btnR[2] + 1, btnR[3] - 2, btnR[4] - 2, T.color.bright)
    else
        T.border(ui, btnR[1], btnR[2], btnR[3], btnR[4], GOLD)
    end
    btnOpts.font = st.fBtn
    T.label(ui, st.btnText, btnR, T.color.ink, btnOpts)
    labR[1], labR[2], labR[3], labR[4] = rx, by + 40 * s, st.rightW, 15 * s
    labOpts.font, labOpts.align = st.fUnder, "right"
    T.label(ui, st.under, labR, T.color.dim, labOpts)
    labOpts.align = nil
    return h
end

--- The roadmap's title: ROADMAP in gold between two lines fading out to the sides, each
--- ending at the text in a square, as the road's dates.
local function drawRoadTitle(ui, colX, y, colW, s)
    local font = T.javaFonts and T.makeFont("title", T.cell * 0.46) or T.fontHeader
    local text = T.upper(getText("IGUI_Knox_Roadmap"))
    headR[1], headR[2], headR[3], headR[4] = colX, y, colW, 26 * s
    headOpts.font, headOpts.ls = font, 2 * s
    local tw = T.spaced(ui, text, headR, GOLD, headOpts)
    local cx = colX + colW / 2
    local gap = 16 * s
    local ly = math.floor(y + 13 * s)
    local l1 = cx - tw / 2 - gap
    local r1 = cx + tw / 2 + gap
    M.hfade(ui, colX, ly, l1 - colX, 2, GOLD, 0.75, false)
    M.hfade(ui, r1, ly, colX + colW - r1, 2, GOLD, 0.75, true)
    local q = math.floor(10 * s + 0.5)
    T.rect(ui, l1 + 1 - q, ly - 4 * s, q, q, GOLD)
    T.rect(ui, r1 - 1, ly - 4 * s, q, q, GOLD)
end

--- The pinned post's left panel px, top, pw, ph (inside its 2 px frame): the backdrop, the
--- head, the body scrolled by `scroll`. Sets ui.view, ui.panel, ui.backGrid; returns the
--- body's height (for the scroll bar).
function P.drawLeft(ui, post, st, px, top, pw, ph, scroll)
    local s = T.cell / 48
    local now = getTimestampMs()
    local sec = now / 1000
    local mx, my = ui:getMouseX(), ui:getMouseY()
    T.rect(ui, px, top, pw, ph, T.color.window, 0.97)
    T.clip(ui, px + 2, top + 2, pw - 4, ph - 4)
    KnoxNewsBack.draw(ui, "road", px + 2, top + 2, pw - 4, ph - 4, GOLD, 0)
    ui.backGrid = ui.backGrid or {}
    ui.backGrid[1], ui.backGrid[2], ui.backGrid[3] = GOLD, 0, "road"
    -- the head: a band of the header's colour, lit from its gold line like the fire
    local hx, hy, hw, hh = px + 2, top + 2, pw - 4, 124 * s
    T.rect(ui, hx, hy, hw, hh, T.color.header)
    M.vfade(ui, hx, hy + hh * 0.3, hw, hh * 0.7, GOLD, 0.06, false)
    T.clip(ui, hx, hy, hw, hh)
    local ew = hw * 1.3
    M.glow(ui, hx + hw / 2 + M.drift(sec) * ew, hy + hh, ew * 0.48, hh * 1.2, GOLD, 0.2 * M.fire(sec))
    T.unclip(ui)
    T.rect(ui, hx, hy + hh, hw, 4 * s, GOLD)
    local big = P.bigFont()
    headR[1], headR[2], headR[3], headR[4] = hx, hy + 22 * s, hw, 42 * s
    headOpts.font, headOpts.ls = big, s
    T.spaced(ui, T.upper(post.title), headR, T.color.bright, headOpts)
    headR[2] = headR[2] + 42 * s
    st.meta = st.meta or T.upper(getText("IGUI_Knox_NewsTag_pinned") .. "  " .. DOT .. "  " .. getText("IGUI_Knox_PinnedUpdated", post.date))
    T.spaced(ui, st.meta, headR, GOLD, headOpts)

    -- the body, scrolled
    local viewTop = top + 2 + 144 * s
    local viewH = top + ph - 2 - 12 * s - viewTop
    ui.view = ui.view or {0, 0, 0, 0}
    local v = ui.view
    v[1], v[2], v[3], v[4] = px, viewTop, pw, viewH
    ui.panel = ui.panel or {0, 0, 0, 0}
    ui.panel[1], ui.panel[2], ui.panel[3], ui.panel[4] = px, top, pw, ph
    st.clip = v
    st.inView = ui:isMouseOver() and T.inRect(mx, my, v)
    T.clip(ui, px + 2, viewTop, pw - 4, viewH)
    local colW = math.min(720 * s, pw - 4 - 40 * s)
    local colX = math.floor(px + (pw - colW) / 2)
    local font = T.fontText
    if st.blocksW ~= colW then
        st.blocks = blocksOf(post, colW, font)
        st.blocksW = colW
    end
    local y = viewTop + 12 * s - scroll
    local lh = 20 * s
    local first = true
    st.road = st.road or M.new(post)
    for _, b in ipairs(st.blocks) do
        if b.kind == "text" then
            paraOpts.font = font
            for _, l in ipairs(b.lines) do
                if y > viewTop - lh and y < viewTop + viewH then
                    paraR[1], paraR[2], paraR[3], paraR[4] = colX, y, colW, lh
                    T.label(ui, l, paraR, first and T.color.bright or T.color.text, paraOpts)
                end
                y = y + lh
            end
            y = y + 16 * s
            first = false
        elseif b.kind == "boosty" then
            y = y + 6 * s
            st.supY = y
            y = y + drawSupport(ui, st, colX, y, colW, s, mx, my, now) + 4 * s
        elseif b.kind == "road" then
            y = y + 26 * s
            drawRoadTitle(ui, colX, y, colW, s)
            y = y + 26 * s + 10 * s + 4 * s
            M.draw(ui, st.road, px + 2, y, pw - 4, v)
            T.clip(ui, px + 2, viewTop, pw - 4, viewH)
            y = y + M.LANE_H * s
        end
    end
    T.unclip(ui)
    return y + scroll - viewTop
end

return KnoxPinned
