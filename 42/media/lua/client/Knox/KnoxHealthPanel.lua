-- The Knox screen's Health tab (version 1.0; redesigned 2026-10-19 after the author:
-- "too loaded - only the character and a pile of numbers to get lost in; simpler,
-- intuitive, interactive, visually varied, every wound its own icons changing with
-- its state", squares as everywhere in Knox):
--   TOP     the overall health in a square (its frame fills as the health), how it
--           goes, and only the effects that are not right as plates with the game's
--           icons ("+N fine" for the rest);
--   BODY    the 3D character, and on it a square badge per wound (KnoxHealthWounds):
--           its icon (the kind, with the state over it - a bandage, stitches, a
--           splint...), its frame filling as it heals, a bleeding's pulsing;
--   RIGHT   the chosen wound's card - its way of treatment as squares (where it is
--           now in sand), what it needs and whether it is carried, one button for
--           what to do now; with nothing chosen: what matters now (the wounds to see
--           to, the most urgent first, a button each) and what is healing;
--   KIT     at the bottom: what the character carries that treats - dragged onto
--           the body, or clicked with a wound chosen.
-- The mouse: a click chooses (a badge, a part on the model, a row); the right button
-- opens the part's menu (KnoxHealthCare); Shift + click treats at once.
-- The data: KnoxHealthData, KnoxHealthWounds; the treatments: KnoxHealthCare; the model:
-- KnoxHealthModel.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxDrag"
require "Knox/KnoxTooltip"
require "Knox/KnoxHealthCU"
require "Knox/KnoxHealthData"
require "Knox/KnoxHealthCare"
require "Knox/KnoxHealthModel"
require "Knox/KnoxHealthWounds"

KnoxHealthPanel = ISPanel:derive("KnoxHealthPanel")
local P = KnoxHealthPanel
local T = KnoxTheme
local H = KnoxHealthData
local Care = KnoxHealthCare
local Model = KnoxHealthModel
local Wd = KnoxHealthWounds

local MINUS = "-"                -- (the Knox fonts' own minus is the hyphen)
local RAQUO = string.char(187)   -- »
local DRAG_PX = 5

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function tx(key, ...) return getText("IGUI_KnoxHP_" .. key, ...) end

-- The panel ---------------------------------------------------------------------------

function P:new(x, y, w, h, playerNum, screen)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.playerNum = playerNum
    o.screen = screen
    o.anim = {}
    o.st = {}
    o.hits = {}
    o.scroll, o.scrollTo = 0, 0
    o.openMs = getTimestampMs()
    return o
end

function P:player()
    return getSpecificPlayer(self.playerNum)
end

function P:createChildren()
    self.model = Model.create(self)
end

--- Shown again (the tab chosen): the columns come up anew.
function P:shown()
    self.openMs = getTimestampMs()
    self.press = nil
end

--- A value on its way to `target`: it moves over a moment instead of jumping.
function P:ease(key, target, ms)
    local now = getTimestampMs()
    local s = self.anim[key]
    if not s then
        s = {v = target, ms = now}
        self.anim[key] = s
        return target
    end
    local dt = math.min(100, now - s.ms)
    s.ms = now
    s.v = s.v + (target - s.v) * T.anim(math.min(1, dt / (ms or 90)))
    if math.abs(target - s.v) < 0.002 then s.v = target end
    return s.v
end

--- State kept with a thing drawn (rolling numbers, sliding text).
function P:state(key)
    local s = self.st[key]
    if not s then
        s = {}
        self.st[key] = s
    end
    return s
end

function P:hit(kind, x, y, w, h, data)
    data = data or {}
    data.kind, data.rect = kind, {x, y, w, h}
    table.insert(self.hits, data)
    return data
end

function P:hitAt(x, y)
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if T.inRect(x, y, h.rect) and not (h.clip and not T.inRect(x, y, h.clip)) then return h end
    end
    return nil
end

-- the columns' coming up when the tab opens: alpha and how far still below
local function intro(self, delay)
    local t = (getTimestampMs() - self.openMs - delay) / 320
    local k = clamp(T.anim(t), 0, 1)
    k = 1 - (1 - k) * (1 - k) * (1 - k)
    return k, math.floor((1 - k) * T.pad * 1.5 + 0.5)
end

--- The fonts and sizes from the cell (again when the screen's cell or size changes).
function P:metrics()
    local W, Hh = self:getWidth(), self:getHeight()
    if self.mCell == T.cell and self.mFonts == T.javaFonts and self.mW == W and self.mH == Hh then return self.m end
    local c = T.cell
    local m = {}
    m.c, m.pad = c, T.pad
    m.gap = self.screen and self.screen.margin or math.floor(c * 0.42 + 0.5)
    m.big = T.javaFonts and T.makeFont("title", c * 0.62) or UIFont.Large
    m.topH = math.floor(c * 1.35 + 0.5)
    m.tile = math.floor(c * 1.0 + 0.5)
    m.kitH = T.fontH(T.fontCaps) + math.floor(T.pad * 0.6) + m.tile
    m.midY = m.topH + m.gap
    m.midH = Hh - m.midY - m.gap - m.kitH
    m.rw = clamp(math.floor(W * 0.36 + 0.5), c * 7, c * 10)
    m.bw = W - m.rw - m.gap
    m.rx = m.bw + m.gap
    m.badge = math.max(18, math.floor(c * 0.6 + 0.5))
    self.m, self.mCell, self.mFonts, self.mW, self.mH = m, T.cell, T.javaFonts, W, Hh
    return m
end

local function panelBg(ui, x, y, w, h, a)
    T.rect(ui, x, y, w, h, T.color.window, T.bgAlpha() * a)
    T.border(ui, x, y, w, h, T.color.border, a)
end

--- A section's title: dim capitals and a line after them to the right edge.
local function section(ui, text, x, y, w, a)
    local f = T.fontCaps
    local s = T.upper(text)
    T.text(ui, s, x, y, T.color.dim, f, a)
    local lw = T.measure(f, s)
    local ly = y + math.floor(T.fontH(f) / 2)
    if x + lw + T.pad < x + w then T.rect(ui, x + lw + T.pad, ly, w - lw - T.pad, 1, T.color.border, a) end
    return T.fontH(f) + math.floor(T.pad * 0.6)
end

-- A square frame that fills clockwise from the top left as `frac` goes 0..1 (the
-- health, a wound's healing): the Knox squares' answer to a ring.
local function squareProgress(ui, x, y, s, th, frac, c, a)
    frac = clamp(frac, 0, 1)
    if frac <= 0 then return end
    local side = s - th
    local len = side * 4 * frac
    local function seg(dx0, dy0, w, h) T.rect(ui, dx0, dy0, w, h, c, a) end
    local l = math.min(len, side)
    seg(x, y, l + th, th)
    len = len - side
    if len > 0 then l = math.min(len, side) seg(x + s - th, y, th, l + th) len = len - side end
    if len > 0 then l = math.min(len, side) seg(x + s - th - l, y + s - th, l + th, th) len = len - side end
    if len > 0 then l = math.min(len, side) seg(x, y + s - th - l, th, l + th) end
end

--- A wound's icon in a square: its base, the state over it, a poultice's leaf.
local function woundIcon(ui, base, overlay, x, y, s, a, poultice)
    local inset = math.floor(s * 0.12)
    local is = s - inset * 2
    local tb = Wd.icon(base)
    if tb then ui:drawTextureScaled(tb, x + inset, y + inset, is, is, a, 1, 1, 1) end
    local to = Wd.icon(overlay)
    if to then ui:drawTextureScaled(to, x + inset, y + inset, is, is, a, 1, 1, 1) end
    if poultice then
        local tp = Wd.icon("o_poultice")
        if tp then ui:drawTextureScaled(tp, x + inset, y + inset, is, is, a, 1, 1, 1) end
    end
end

-- Frame -------------------------------------------------------------------------------

function P:prerender()
    local player = self:player()
    if not player then return end
    local m = self:metrics()
    self.hits = {}
    self.mx, self.my = self:getMouseX(), self:getMouseY()
    self.hot = self:isMouseOver() or (self.model ~= nil and self.model:isMouseOver())
    local menu = getPlayerContextMenu(self.playerNum)
    self.menuOpen = menu ~= nil and menu:isAnyVisible()
    local W = self:getWidth()

    self.wounds = Wd.list(player, function(bp) return self:quickSteps(player, bp) end)
    -- the chosen wound gone (healed, taken off): the next one of its part, or none
    if self.selWound and not self:wound(self.selWound) then
        local nextW
        for _, w in ipairs(self.wounds) do if w.index == self.selPart then nextW = w break end end
        self.selWound = nextW and nextW.id or nil
        if not nextW then self.selPart = nil end
    end

    local aT, dT = intro(self, 0)
    local aB, dB = intro(self, 60)
    local aR, dR = intro(self, 120)
    local aK, dK = intro(self, 160)
    self:drawTop(player, m, 0, dT, W, m.topH, aT)
    panelBg(self, 0, m.midY + dB, m.bw, m.midH - dB, aB)
    self:drawBodyBack(player, m, 0, m.midY + dB, m.bw, m.midH - dB, aB)
    panelBg(self, m.rx, m.midY + dR, m.rw, m.midH - dR, aR)
    self:drawSide(player, m, m.rx, m.midY + dR, m.rw, m.midH - dR, aR)
    self:drawKit(player, m, 0, self:getHeight() - m.kitH + dK, W, m.kitH, aK)
    self:updateModel(player)
end

function P:render()
    local player = self:player()
    if not player then return end
    local m = self.m
    if not m then return end
    local aB = intro(self, 60)
    self:drawBadges(player, m, aB)
    self:drawFloat(player, m)
    -- what is under the mouse, for the next frame's lights
    local hv = (self.hot and not self.menuOpen) and self:hitAt(self.mx, self.my) or nil
    if self.menuOpen and self.hover then hv = self.hover end
    self.hover = hv
    if hv and hv.kind == "kit" and not KnoxDrag.isActive() and not self.menuOpen then
        KnoxTooltip.want(hv.group.item, self.playerNum)
    end
end

function P:wound(id)
    for _, w in ipairs(self.wounds or {}) do if w.id == id then return w end end
    return nil
end

-- TOP -------------------------------------------------------------------------------------

function P:statusText(player)
    local ok, s = pcall(function()
        local p = Care.carePanel(player)
        return p and p.healthPanel and p.healthPanel.javaObject and p.healthPanel.javaObject:getDamageStatusString()
    end)
    return ok and s or nil
end

function P:drawTop(player, m, x, y, w, h, a)
    local C = T.color
    local pad = m.pad
    panelBg(self, x, y, w, h, a)
    -- the health: a square, its frame filling as it, the number in it
    local health = player:getBodyDamage():getHealth()
    local hpc = H.hpColor(health)
    local s = h - pad * 2
    local sx, sy = x + pad, y + pad
    local th = math.max(3, math.floor(s * 0.09))
    T.rect(self, sx, sy, s, s, C.header, a)
    T.border(self, sx, sy, s, s, C.tileEdge, a)
    local frac = clamp(self:ease("hpSq", health / 100, 160), 0, 1)
    squareProgress(self, sx, sy, s, th, frac, hpc, a)
    local num = tostring(math.max(0, math.floor(self:ease("hp", health, 140) + 0.5)))
    local nw = T.measure(m.big, num)
    T.rollNumber(self, self:state("hpNum"), num, sx + math.floor((s - nw) / 2), sy + math.floor((s - T.fontH(m.big)) / 2),
        nw, T.fontH(m.big), hpc.r, hpc.g, hpc.b, a, m.big)
    -- its words: the game's state, how it goes
    local tx0 = sx + s + pad
    T.caps(self, tx("Health"), tx0, sy, C.bright, T.fontHeader, a)
    local status = self:statusText(player) or ""
    local pace = H.healthPace(player)
    local paceText, paceC = "", C.dim
    if pace and pace > 0.05 then paceText, paceC = tx("Worsening"), C.bad
    elseif pace and pace < -0.05 then paceText, paceC = tx("Improving"), C.good
    elseif pace then paceText = tx("PaceStable") end
    local line2 = status
    if paceText ~= "" then line2 = (line2 ~= "" and (line2 .. "  " .. string.char(183) .. "  ") or "") .. paceText end
    T.text(self, line2, tx0, sy + T.fontH(T.fontHeader) + 2, paceText ~= "" and paceC or C.dim, T.fontText, a)

    -- the effects that are not right, from the right edge; the rest as "+N fine"
    local list = H.moodles(player)
    local bad, fine = {}, 0
    for _, e in ipairs(list) do
        if e.good == 2 then table.insert(bad, e) else fine = fine + 1 end
    end
    local ch = math.floor(h * 0.5)
    local cy = y + math.floor((h - ch) / 2)
    local right = x + w - pad
    local leftLimit = tx0 + math.max(T.measure(T.fontHeader, T.upper(tx("Health"))), T.measure(T.fontText, line2)) + pad * 2
    local f = T.fontTile
    local function plate(text, tex, tone, hitData)
        local s2 = T.upper(text)
        local is = ch - 6
        local pw = (tex and is + 6 or 0) + T.measure(f, s2) + 14
        if right - pw < leftLimit then return false end
        local px = right - pw
        T.rect(self, px, cy, pw, ch, C.header, a)
        T.border(self, px, cy, pw, ch, tone and T.mix(C.tileEdge, tone, 0.6) or C.tileEdge, a)
        local ix = px + 7
        if tex then
            self:drawTextureScaledAspect(tex, px + 4, cy + 3, is, is, a, 1, 1, 1)
            ix = px + 4 + is + 5
        end
        T.inkLeft(self, s2, ix, cy, ch, tone and C.bright or C.dim, f, a)
        if hitData then self:hit("effect", px, cy, pw, ch, hitData) end
        right = px - 5
        return true
    end
    if fine > 0 then plate(tx("FineMore", fine), nil, nil, nil) end
    for i = #bad, 1, -1 do
        local e = bad[i]
        local tone = e.level >= 3 and C.bad or C.warn
        if not plate(e.name or "", H.moodleIcon(e.icon, ch), tone, {effect = e}) then break end
    end
    if #bad == 0 and #list == 0 then plate(tx("NoEffects"), nil, nil, nil) end
end

-- BODY ------------------------------------------------------------------------------------

function P:drawBodyBack(player, m, x, y, w, h, a)
    local C = T.color
    local pad = m.pad
    local hintH = T.fontH(T.fontTile) + 8
    local g = {bx = x + 1, by = y + 1, bw = w - 2, bh = h - hintH - pad - 2, hintH = hintH}
    g.hintY = g.by + g.bh + math.floor(pad / 2)
    self.geo = g
    T.rect(self, g.bx, g.by, g.bw, g.bh, C.cell, T.modelAlpha() * a)
    -- the four corner marks of a scope
    local cl = math.floor(m.c * 0.3)
    local cc = T.mix(C.border, C.accent, 0.35)
    for _, cn in ipairs({{g.bx + 6, g.by + 6, 1, 1}, {g.bx + g.bw - 7, g.by + 6, -1, 1},
                         {g.bx + 6, g.by + g.bh - 7, 1, -1}, {g.bx + g.bw - 7, g.by + g.bh - 7, -1, -1}}) do
        local cx0, cy0, sx, sy = cn[1], cn[2], cn[3], cn[4]
        T.rect(self, sx > 0 and cx0 or cx0 - cl + 1, cy0, cl, 1, cc, a)
        T.rect(self, cx0, sy > 0 and cy0 or cy0 - cl + 1, 1, cl, cc, a)
    end
    -- the doctor's level at the top left of the box
    T.text(self, T.upper(tx("Doctor", H.doctorLevel(player))), g.bx + pad, g.by + pad, C.dim, T.fontTile, a)
    -- the hints under it
    local hints = {{tx("KeyLmb"), tx("HintSelect")}, {tx("KeyRmb"), tx("HintMenu")}, {tx("KeyShiftLmb"), tx("HintQuick")}}
    local total = 0
    for _, hk in ipairs(hints) do total = total + T.measure(T.fontTile, hk[1]) + 10 + 6 + T.measure(T.fontText, hk[2]) + pad end
    local hx = x + math.floor((w - total + pad) / 2)
    for _, hk in ipairs(hints) do hx = T.keyHint(self, hx, g.hintY, hk[1], hk[2], hintH) + pad end
end

--- The view the model's paint follows: the part under the mouse (on the model, or a
--- badge's), the chosen wound's part, the parts the kit's thing would treat.
function P:modelView(player)
    local hv = self.hover
    local view = {selected = nil, selectedPart = self.selPart}
    if hv and (hv.kind == "part" or hv.kind == "badge" or hv.kind == "row") then
        view.hoverPart = hv.part
        view.hover = hv.part and H.zoneOfPart[hv.part] and H.zoneOfPart[hv.part].id
    end
    local item
    if KnoxDrag.isActive() and KnoxDrag.entity and KnoxDrag.entity.fromKit then
        item = KnoxDrag.entity.item
    elseif hv and hv.kind == "kit" then
        item = hv.group.item
    end
    if item then
        local now = getTimestampMs()
        local gc = self.glowCache
        if not gc or gc.item ~= item or now - gc.ms > 400 then
            gc = {item = item, ms = now, parts = Care.partsFor(player, item)}
            self.glowCache = gc
        end
        view.glow = gc.parts
    end
    return view
end

function P:updateModel(player)
    local g = self.geo
    if not (g and self.model) then return end
    local view = self:modelView(player)
    self.view = view
    -- the model fitted to the box's height, in the middle of it
    local bodyAspect = Model.CAL.HEIGHT * Model.doll.width / Model.CONTENT_UNITS
    local mh = g.bh - 2
    local mw = math.min(g.bw - 2, math.floor(mh * bodyAspect / 0.94))
    mh = math.min(mh, math.floor(mw / bodyAspect * 0.94))
    local mx = g.bx + 1 + math.floor((g.bw - 2 - mw) / 2)
    local my = g.by + 1 + math.floor((g.bh - 2 - mh) / 2)
    local ok, err = pcall(Model.update, self.model, player, mx, my, mw, mh, view)
    if not ok and not self.modelErr then
        self.modelErr = true
        print("[Knox] health model: " .. tostring(err))
    end
    local s, fx, fy = Model.frame(mx, my, mw, mh)
    g.s, g.fx, g.fy = s, fx, fy
    -- the body under the mouse (the hit map; inside the model's box only)
    if self.hot and T.inRect(self.mx, self.my, {g.bx, g.by, g.bw, g.bh}) then
        local idx = Model.partAt((self.mx - fx) / s, (self.my - fy) / s)
        if idx and not H.missing(player, idx) then
            local z = H.zoneOfPart[idx]
            self:hit("part", self.mx - 1, self.my - 1, 3, 3, {part = idx, zone = z and z.id})
        end
    end
end

--- The badges over the model: a square per wound on its part (several on one part
--- side by side), its icon, its frame filling as it heals, the urgent ones pulsing.
function P:drawBadges(player, m, a)
    local g = self.geo
    if not (g and g.s) then return end
    local C = T.color
    local bs = m.badge
    local byPart, order = {}, {}
    for _, w in ipairs(self.wounds or {}) do
        if not byPart[w.index] then byPart[w.index] = {} table.insert(order, w.index) end
        table.insert(byPart[w.index], w)
    end
    local now = getTimestampMs()
    local pulse = 0.5 + 0.5 * math.sin(now / 1000 * math.pi * 1.8)
    for _, index in ipairs(order) do
        local list = byPart[index]
        local px, py = Model.partPoint(index, g.s, g.fx, g.fy)
        if px then
            local n = #list
            local gap = 3
            local total = n * bs + (n - 1) * gap
            local x0 = math.floor(px - total / 2 + 0.5)
            local y0 = math.floor(py - bs / 2 + 0.5)
            for k, w in ipairs(list) do
                local x = x0 + (k - 1) * (bs + gap)
                local key = "bdg" .. w.id
                local appear = self:ease(key, 1, 220)
                local ba = a * appear
                local sel = self.selWound == w.id
                local hot = self.hover and self.hover.kind == "badge" and self.hover.id == w.id
                T.rect(self, x, y0, bs, bs, C.window, 0.92 * ba)
                T.border(self, x, y0, bs, bs, C.tileEdge, ba)
                local th = math.max(2, math.floor(bs * 0.09))
                local frac = w.progress or ((w.stage or 1) / math.max(1, #(w.path or {1})))
                if w.kind == "destroyed" then frac = 1 end
                local fa = ba
                if w.urgent then fa = ba * (0.35 + 0.65 * pulse) end
                squareProgress(self, x, y0, bs, th, math.max(0.12, frac), w.color, fa)
                woundIcon(self, w.base, w.overlay, x, y0, bs, ba, w.poultice)
                if sel or hot then T.tileFrame(self, x - 3, y0 - 3, bs + 6, bs + 6, sel and C.accent or C.tileHover, ba) end
                self:hit("badge", x - 2, y0 - 2, bs + 4, bs + 4, {id = w.id, part = w.index, wound = w})
            end
        end
    end
end

--- Floating labels at the mouse: the part or the badge under it, a step of a path,
--- the thing dragged onto the body.
function P:drawFloat(player, m)
    local hv = self.hover
    if not (self.hot and hv) or self.menuOpen then return end
    local C = T.color
    local lines = {}
    if hv.kind == "part" then
        local bp = H.part(player, hv.part)
        local hp = math.max(0, math.floor(bp:getHealth() + 0.5))
        table.insert(lines, {T.upper(H.partName(bp)) .. "  " .. hp, H.hpColor(hp), T.fontCaps})
        if KnoxDrag.isActive() and KnoxDrag.entity then
            local item = KnoxDrag.entity.item
            local ok = Care.treats(player, bp, item)
            table.insert(lines, {(ok and (item:getName() .. "  " .. RAQUO .. "  " .. tx("WillTreat")) or tx("WontHelp")),
                ok and C.good or C.bad, T.fontTile})
        else
            for _, w in ipairs(self.wounds or {}) do
                if w.index == hv.part then table.insert(lines, {self:woundTitle(w), w.color, T.fontTile}) end
            end
        end
    elseif hv.kind == "badge" then
        local w = hv.wound
        table.insert(lines, {T.upper(self:woundTitle(w)), w.color, T.fontCaps})
        table.insert(lines, {w.part .. (w.heal and ("  " .. string.char(183) .. "  " .. w.heal) or ""), C.dim, T.fontTile})
        if w.todo then table.insert(lines, {w.todo.label, w.todo.missing and C.bad or C.accent, T.fontTile}) end
    elseif hv.kind == "step" then
        table.insert(lines, {hv.name, C.text, T.fontTile})
    elseif hv.kind == "effect" then
        local e = hv.effect
        table.insert(lines, {e.name or "", C.bright, T.fontCaps})
        if e.desc and e.desc ~= "" then table.insert(lines, {string.gsub(e.desc, "%s+", " "), C.dim, T.fontTile}) end
    else
        return
    end
    local pad = 6
    local w, h = 0, pad
    for _, l in ipairs(lines) do
        w = math.max(w, T.measure(l[3], l[1]))
        h = h + T.fontH(l[3]) + 2
    end
    w = w + pad * 2
    h = h + pad - 2
    local x, y = self.mx + 18, self.my + 14
    if x + w > self:getWidth() then x = self.mx - 12 - w end
    if y + h > self:getHeight() then y = self.my - 8 - h end
    T.rect(self, x, y, w, h, C.window, 0.95)
    T.tileFrame(self, x, y, w, h, C.tileFrame)
    local ly = y + pad
    for _, l in ipairs(lines) do
        T.text(self, l[1], x + pad, ly, l[2], l[3])
        ly = ly + T.fontH(l[3]) + 2
    end
end

--- A wound's name now: its step's name on its path ("Bandaged"), or its own.
function P:woundTitle(w)
    local step = w.path and w.path[w.stage or 1]
    local key = step and step[3]
    local stepName = key and tx(key)
    if w.dirty and not w.cover then stepName = tx("St_Dirty") end
    if not stepName or w.kind == "destroyed" then return w.name end
    if (w.stage or 1) == 1 and not w.cover then return w.name end
    return w.name .. " " .. string.char(183) .. " " .. stepName
end

-- RIGHT -----------------------------------------------------------------------------------

function P:drawSide(player, m, x, y, w, h, a)
    local w0 = self.selWound and self:wound(self.selWound)
    if w0 then self:drawCard(player, m, w0, x, y, w, h, a)
    else self:drawOverview(player, m, x, y, w, h, a) end
end

--- A row's square icon tile.
local function tile(ui, w, x, y, s, a, frame)
    local C = T.color
    T.rect(ui, x, y, s, s, C.cell, a)
    T.border(ui, x, y, s, s, frame or T.mix(C.tileEdge, w.color, 0.75), a)
    woundIcon(ui, w.base, w.overlay, x, y, s, a, w.poultice)
end

function P:drawOverview(player, m, x, y, w, h, a)
    local C = T.color
    local pad = m.pad
    local ix, iw = x + pad, w - pad * 2
    local todo, healing = {}, {}
    for _, wd in ipairs(self.wounds or {}) do
        if wd.todo then table.insert(todo, wd) else table.insert(healing, wd) end
    end
    local areaY, areaH = y + pad, h - pad * 2
    local clip = {x + 1, areaY, w - 2, areaH}
    self.sideRect = clip
    local cy = areaY - math.floor(self.scroll + 0.5)
    self:setStencilRect(clip[1], clip[2], clip[3], clip[4])
    local rh = math.floor(m.c * 0.9 + 0.5)
    local ts = rh - 8
    local bf = T.fontTile
    local btnH = T.fontH(bf) + 10
    if #todo == 0 and #healing == 0 then
        local my = areaY + math.floor(areaH * 0.38)
        local tex = Wd.icon("healed")
        local is = math.floor(m.c * 1.1)
        if tex then self:drawTextureScaled(tex, ix + math.floor((iw - is) / 2), my - is - pad, is, is, 0.9 * a, 1, 1, 1) end
        T.textCentre(self, T.upper(tx("AllGood")), ix + math.floor(iw / 2), my, C.text, T.fontCaps, a)
        T.textCentre(self, tx("AllGoodSub"), ix + math.floor(iw / 2), my + T.fontH(T.fontCaps) + 4, C.dim, T.fontText, a)
    end
    if #todo > 0 then
        cy = cy + section(self, tx("Important"), ix, cy, iw, a)
        for _, wd in ipairs(todo) do
            local hot = self.hover and (self.hover.kind == "row" or self.hover.kind == "rowbtn") and self.hover.id == wd.id
            if hot then self:drawRect(ix - 3, cy, iw + 6, rh, 0.06 * a, 1, 1, 1) end
            tile(self, wd, ix, cy + 4, ts, a)
            -- the button at the right: urgent in red, else sand
            local btnT = wd.todo.missing and tx("BtnMenu") or (wd.urgent and tx("BtnUrgent") or tx("BtnTreat"))
            local bw = T.measure(bf, T.upper(btnT)) + T.pad * 2
            local bx = ix + iw - bw
            local by = cy + math.floor((rh - btnH) / 2)
            local hotB = self.hover and self.hover.kind == "rowbtn" and self.hover.id == wd.id
            T.button(self, {bx, by, bw, btnH}, btnT, {hover = hotB, primary = not wd.todo.missing, font = bf})
            local tx0 = ix + ts + 8
            local tw = bx - 8 - tx0
            T.marquee(self, self:state("ot" .. wd.id), wd.todo.label, tx0, cy + 4, tw, wd.todo.missing and C.bad or C.bright, T.fontText, a)
            T.marquee(self, self:state("os" .. wd.id), wd.part .. "  " .. string.char(183) .. "  " .. self:woundTitle(wd),
                tx0, cy + 4 + T.fontH(T.fontText) + 1, tw, C.dim, T.fontTile, a)
            self:hit("row", ix - 3, cy, iw + 6, rh, {id = wd.id, part = wd.index, wound = wd, clip = clip})
            self:hit("rowbtn", bx, by, bw, btnH, {id = wd.id, part = wd.index, wound = wd, clip = clip})
            T.rect(self, ix, cy + rh, iw, 1, C.border, a)
            cy = cy + rh + 2
        end
        cy = cy + pad
    end
    if #healing > 0 then
        cy = cy + section(self, tx("HealingNow"), ix, cy, iw, a)
        for _, wd in ipairs(healing) do
            local hot = self.hover and self.hover.kind == "row" and self.hover.id == wd.id
            if hot then self:drawRect(ix - 3, cy, iw + 6, rh, 0.06 * a, 1, 1, 1) end
            tile(self, wd, ix, cy + 4, ts, a)
            local tx0 = ix + ts + 8
            local right = wd.notHealing and wd.heal or wd.heal
            local rw = right and T.measure(bf, T.upper(right)) or 0
            if right then T.textRight(self, T.upper(right), ix + iw, cy + 4, wd.notHealing and C.bad or C.dim, bf, a) end
            local tw = iw - ts - 8 - (rw > 0 and rw + 8 or 0)
            T.marquee(self, self:state("ht" .. wd.id), self:woundTitle(wd), tx0, cy + 4, tw, C.text, T.fontText, a)
            T.text(self, wd.part, tx0, cy + 4 + T.fontH(T.fontText) + 1, C.dim, T.fontTile, a)
            -- how far along: a thin bar under it
            if wd.progress then
                local barY = cy + rh - 4
                T.rect(self, tx0, barY, ix + iw - tx0, 2, C.line, a)
                T.rect(self, tx0, barY, math.floor((ix + iw - tx0) * clamp(self:ease("hp" .. wd.id, wd.progress, 300), 0, 1) + 0.5), 2, H.HEALED, a)
            end
            self:hit("row", ix - 3, cy, iw + 6, rh, {id = wd.id, part = wd.index, wound = wd, clip = clip})
            cy = cy + rh + 2
        end
    end
    self:clearStencilRect()
    local contentH = cy + math.floor(self.scroll + 0.5) - areaY
    self.maxScroll = math.max(0, contentH - areaH)
    self.scrollTo = clamp(self.scrollTo, 0, self.maxScroll)
    self.scroll = self:ease("scroll", self.scrollTo, 70)
end

--- The chosen wound: its icon and name, its way of treatment as squares, what it
--- needs, the treatment going on, one button for what to do now.
function P:drawCard(player, m, wd, x, y, w, h, a)
    local C = T.color
    local pad = m.pad
    local ix, iw = x + pad, w - pad * 2
    local cy = y + pad
    -- the head
    local hs = math.floor(m.c * 1.25 + 0.5)
    tile(self, wd, ix, cy, hs, a, wd.color)
    local th = math.max(2, math.floor(hs * 0.06))
    squareProgress(self, ix, cy, hs, th, math.max(0.12, wd.progress or ((wd.stage or 1) / math.max(1, #wd.path))), wd.color, a)
    local tx0 = ix + hs + pad
    local tw = ix + iw - tx0
    T.marquee(self, self:state("cn" .. wd.id), T.upper(self:woundTitle(wd)), tx0, cy + 2, tw, C.bright, T.fontCaps, a)
    T.marquee(self, self:state("cp" .. wd.id), wd.part, tx0, cy + 2 + T.fontH(T.fontCaps) + 2, tw, C.text, T.fontText, a)
    if wd.heal then
        T.text(self, wd.heal, tx0, cy + 2 + T.fontH(T.fontCaps) + 2 + T.fontH(T.fontText) + 2,
            wd.notHealing and C.bad or C.dim, T.fontTile, a)
    end
    cy = cy + hs + pad

    -- the way of treatment: a square per step, where it is now in sand
    if #wd.path > 1 then
        cy = cy + section(self, tx("Path"), ix, cy, iw, a)
        local n = #wd.path
        local ss = math.floor(m.c * 0.8 + 0.5)
        local link = math.max(8, math.floor((iw - n * ss) / math.max(1, n - 1)))
        link = math.min(link, math.floor(ss * 0.9))
        local sx = ix
        for i, step in ipairs(wd.path) do
            local past, now = i < (wd.stage or 1), i == (wd.stage or 1)
            local sa = past and 0.45 * a or (now and a or 0.75 * a)
            local over = step[2]
            if now and wd.dirty and over == "o_band" then over = "o_dirty" end
            T.rect(self, sx, cy, ss, ss, C.cell, sa)
            if now then T.tileFrame(self, sx - 2, cy - 2, ss + 4, ss + 4, C.accent, a)
            else T.border(self, sx, cy, ss, ss, C.tileEdge, sa) end
            woundIcon(self, step[1], over, sx, cy, ss, sa, false)
            self:hit("step", sx, cy, ss, ss, {name = step[3] and tx(step[3]) or wd.name})
            if i < n then
                T.rect(self, sx + ss + 2, cy + math.floor(ss / 2) - 1, link - 4, 2, past and C.good or C.tileEdge, a)
            end
            sx = sx + ss + link
        end
        cy = cy + ss + pad
    end

    -- what it needs
    local needs = Wd.needs(player, wd)
    if #needs > 0 then
        cy = cy + section(self, tx("Needs"), ix, cy, iw, a)
        for _, nd in ipairs(needs) do
            T.text(self, nd.name, ix, cy, C.text, T.fontText, a)
            local have = nd.have > 0
            T.textRight(self, have and tx("Have", nd.have) or tx("HaveNone"), ix + iw, cy, have and C.good or C.bad, T.fontText, a)
            cy = cy + T.fontH(T.fontText) + 4
        end
        cy = cy + math.floor(pad / 2)
    end

    -- the treatment going on: its name and a sand bar
    local progress, job = Care.partProgress(player, wd.bp)
    if progress then
        local tht = T.fontH(T.fontTile) + 10
        local p = clamp(progress, 0, 1)
        T.rect(self, ix, cy, iw, tht, C.accent, 0.12 * a)
        T.rect(self, ix, cy, math.floor(iw * p + 0.5), tht, C.accent, 0.28 * a)
        T.inkLeft(self, T.upper(job or tx("Treating")), ix + 6, cy, tht, C.accent, T.fontTile, a)
        T.textRight(self, math.floor(p * 100 + 0.5) .. "%", ix + iw - 6, cy + math.floor((tht - T.fontH(T.fontTile)) / 2), C.accent, T.fontTile, a)
        cy = cy + tht + pad
    end

    -- the buttons at the bottom: what to do now (or why it can't be), the menu, back
    local bf = T.fontTile
    local btnH = T.fontH(bf) + 12
    local by = y + h - pad - btnH
    local backT, menuT = tx("BtnBack"), tx("BtnMenu")
    local backW = T.measure(bf, T.upper(backT)) + T.pad * 2
    local menuW = T.measure(bf, T.upper(menuT)) + T.pad * 2
    local bx = ix + iw - backW
    local hv = self.hover
    T.button(self, {bx, by, backW, btnH}, backT, {hover = hv and hv.kind == "cardbtn" and hv.btn == "back", font = bf})
    self:hit("cardbtn", bx, by, backW, btnH, {btn = "back"})
    bx = bx - 6 - menuW
    T.button(self, {bx, by, menuW, btnH}, menuT, {hover = hv and hv.kind == "cardbtn" and hv.btn == "menu", font = bf})
    self:hit("cardbtn", bx, by, menuW, btnH, {btn = "menu", wound = wd})
    local room = bx - 6 - ix
    if wd.todo and not wd.todo.missing then
        local label = wd.todo.label
        if wd.todo.steps and #wd.todo.steps > 1 then label = label .. " +" .. (#wd.todo.steps - 1) end
        local s = T.fit(T.upper(label), bf, room - T.pad * 2)
        local doW = math.min(room, T.measure(bf, s) + T.pad * 2)
        T.button(self, {ix, by, doW, btnH}, s, {hover = hv and hv.kind == "cardbtn" and hv.btn == "do", primary = true, font = bf})
        self:hit("cardbtn", ix, by, doW, btnH, {btn = "do", wound = wd})
        -- the steps of the quick treatment above the button
        if wd.todo.steps and #wd.todo.steps > 1 then
            T.marquee(self, self:state("cs" .. wd.id), table.concat(wd.todo.steps, " " .. RAQUO .. " "), ix,
                by - T.fontH(bf) - 4, iw, C.dim, bf, a)
        end
    elseif wd.todo and wd.todo.missing then
        T.marquee(self, self:state("cm" .. wd.id), wd.todo.label, ix, by + math.floor((btnH - T.fontH(T.fontText)) / 2), room, C.bad, T.fontText, a)
    else
        T.marquee(self, self:state("cw" .. wd.id), tx("JustHeals"), ix, by + math.floor((btnH - T.fontH(T.fontText)) / 2), room, C.good, T.fontText, a)
    end
end

-- what the quick treatment of a part would do (asked many times a frame: kept a moment)
function P:quickSteps(player, bp)
    self.quickCache = self.quickCache or {}
    local now = getTimestampMs()
    local c = self.quickCache[bp]
    if c and now - c.ms < 500 then return c.steps end
    local ok, steps = pcall(Care.quickTreat, player, bp, true)
    steps = ok and steps or {}
    self.quickCache[bp] = {ms = now, steps = steps}
    return steps
end

-- KIT ----------------------------------------------------------------------------------------

function P:drawKit(player, m, x, y, w, h, a)
    local C = T.color
    local pad = m.pad
    local ix, iw = x, w
    local kit = Care.kit(player)
    local secH = section(self, getText("IGUI_KnoxHP_Kit"), ix, y, iw, a)
    -- the hint at the right of its title
    local wd = self.selWound and self:wound(self.selWound)
    local selBp = wd and wd.bp
    local hint = selBp and tx("KitApply", H.partName(selBp)) or tx("KitHint")
    local hf = T.fontTile
    local titleW = T.measure(T.fontCaps, T.upper(getText("IGUI_KnoxHP_Kit")))
    local hintS = T.upper(hint)
    local hw = math.min(T.measure(hf, hintS), iw - titleW - pad * 3)
    if hw > 0 then
        T.rect(self, ix + iw - hw - pad, y, hw + pad, T.fontH(T.fontCaps), C.screen or C.window, a)
        T.marquee(self, self:state("kitHint"), hintS, ix + iw - hw, y + math.floor((T.fontH(T.fontCaps) - T.fontH(hf)) / 2), hw,
            selBp and C.accent or C.dim, hf, a)
    end
    local ts = m.tile
    local ty = y + secH
    if #kit == 0 then
        T.text(self, tx("KitEmpty"), ix, ty + math.floor((ts - T.fontH(T.fontText)) / 2), C.dim, T.fontText, a)
        return
    end
    local kgap = 4
    local cap = math.max(1, math.floor((iw + kgap) / (ts + kgap)))
    local dragged = KnoxDrag.isActive() and KnoxDrag.entity and KnoxDrag.entity.fromKit and KnoxDrag.entity.item
    for i, g in ipairs(kit) do
        if i > cap then break end
        local tx0 = ix + (i - 1) * (ts + kgap)
        local overflow = (i == cap and #kit > cap)
        local hot = self.hover and self.hover.kind == "kit" and self.hover.group.type == g.type
        local helps = selBp and Care.treats(player, selBp, g.item)
        local ka = (dragged and dragged:getFullType() == g.type and g.count == 1) and 0.4 * a or a
        T.rect(self, tx0, ty, ts, ts, C.cell, T.slotAlpha() * a)
        T.rect(self, tx0, ty, ts, ts, T.category[T.categoryOf(g.item)] or T.category.med, ka)
        if overflow then
            T.inkCentre(self, "+" .. (#kit - cap + 1), tx0, ty, ts, ts, C.text.r, C.text.g, C.text.b, a, T.fontCaps)
            T.border(self, tx0, ty, ts, ts, C.tileEdge, a)
        else
            local side = math.floor(ts * 0.72)
            ISInventoryItem.renderItemIcon(self, g.item, tx0 + math.floor((ts - side) / 2), ty + math.floor((ts - side) / 2), ka, side, side)
            if g.count > 1 then
                T.outlinedRight(self, string.char(215) .. g.count, tx0 + ts - 4, ty + ts - T.fontTileH - 3, C.bright, T.fontTile, a)
            end
            T.tileFrame(self, tx0, ty, ts, ts, hot and C.tileHover or C.tileFrame, a)
            -- it would treat the chosen wound's part: a breathing sand frame
            if helps then T.target(self, tx0 + 2, ty + 2, ts - 4, ts - 4) end
            if KnoxContextMenu and KnoxContextMenu.isTarget(g.item) then KnoxContextMenu.drawTarget(self, tx0, ty, ts, ts) end
            self:hit("kit", tx0, ty, ts, ts, {group = g})
        end
    end
end

-- The mouse ---------------------------------------------------------------------------------

function P:onMouseDown(x, y)
    local h = self:hitAt(x, y)
    self.press = {hit = h, x = getMouseX(), y = getMouseY()}
    return true
end

function P:onMouseMove(dx, dy)
    local p = self.press
    if p and p.hit and p.hit.kind == "kit" and not KnoxDrag.isActive() and isMouseButtonDown(0) then
        if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) >= DRAG_PX then
            local g = p.hit.group
            local item = g.items[1] or g.item
            local w, h = KnoxFootprint.get(item)
            KnoxDrag.start({item = item, items = {item}, w = w, h = h, r = 0, fromKit = true}, nil,
                math.floor((w - 1) / 2), math.floor((h - 1) / 2))
            self.press = nil
        end
    end
end

function P:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function P:onMouseUpOutside(x, y)
    self.press = nil
end

--- Chooses a wound (again: back to the overview).
function P:choose(w)
    if not w or self.selWound == w.id then
        self.selWound, self.selPart = nil, nil
    else
        self.selWound, self.selPart = w.id, w.index
    end
    self.scrollTo = 0
    getSoundManager():playUISound("UIActivateButton")
end

--- Does what a wound needs now: its quick treatment, a cover taken off, or the menu.
function P:act(player, w, sx, sy)
    if not w then return end
    local t = w.todo
    if t and t.cover then
        Wd.removeCover(player, w.bp, t.cover)
        getSoundManager():playUISound("UIActivateButton")
    elseif t and not t.missing then
        self:quick(player, w.bp)
    else
        Care.openMenu(player, w.bp, sx or getMouseX(), sy or getMouseY(), w.kind)
    end
    self.quickCache = nil
end

function P:quick(player, bp)
    local steps = Care.quickTreat(player, bp)
    self.quickCache = nil
    if #steps == 0 then
        if HaloTextHelper and HaloTextHelper.addBadText then HaloTextHelper.addBadText(player, tx("NothingToQuick")) end
    else
        getSoundManager():playUISound("UIActivateButton")
    end
end

-- the part's first wound (the list's order: the most urgent)
function P:firstWound(index)
    for _, w in ipairs(self.wounds or {}) do if w.index == index then return w end end
    return nil
end

function P:onMouseUp(x, y)
    local player = self:player()
    local hit = self:hitAt(x, y)
    if KnoxDrag.isActive() then
        local e = KnoxDrag.entity
        KnoxDrag.cancel()
        self.press = nil
        local index = hit and (hit.kind == "part" or hit.kind == "badge") and hit.part
        if index and e and e.item and player then
            Care.drop(player, H.part(player, index), {e.item}, getMouseX(), getMouseY())
            self.quickCache = nil
        end
        return true
    end
    local p = self.press
    self.press = nil
    if not (p and p.hit and hit and player) or p.hit.kind ~= hit.kind then return true end
    local k = hit.kind
    if k == "badge" or k == "row" then
        if hit.id ~= p.hit.id then return true end
        if isShiftKeyDown() then self:act(player, hit.wound) else self:choose(hit.wound) end
    elseif k == "rowbtn" and hit.id == p.hit.id then
        self:act(player, hit.wound)
    elseif k == "part" then
        local w = self:firstWound(hit.part)
        if isShiftKeyDown() then
            if w then self:act(player, w) else self:quick(player, H.part(player, hit.part)) end
        elseif w then
            self:choose(w)
        else
            self.selWound, self.selPart = nil, nil
        end
    elseif k == "cardbtn" and hit.btn == p.hit.btn then
        if hit.btn == "back" then
            self.selWound, self.selPart = nil, nil
            getSoundManager():playUISound("UIActivateButton")
        elseif hit.btn == "menu" then
            Care.openMenu(player, hit.wound.bp, getMouseX(), getMouseY(), hit.wound.kind)
        elseif hit.btn == "do" then
            self:act(player, hit.wound)
        end
    elseif k == "kit" and hit.group.type == p.hit.group.type then
        -- a click on the kit's thing: used on the chosen wound's part
        local w = self.selWound and self:wound(self.selWound)
        if w then
            if Care.treats(player, w.bp, hit.group.item) then
                Care.drop(player, w.bp, {hit.group.items[1] or hit.group.item}, getMouseX(), getMouseY())
                self.quickCache = nil
            elseif HaloTextHelper and HaloTextHelper.addBadText then
                HaloTextHelper.addBadText(player, tx("WontHelp"))
            end
        end
    end
    return true
end

function P:onRightMouseDown(x, y)
    return true
end

function P:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end
    local player = self:player()
    local hit = self:hitAt(x, y)
    if not (player and hit) then return true end
    local k = hit.kind
    if k == "kit" then
        local items = hit.group.items
        if KnoxContextMenu then KnoxContextMenu.setTarget({items[1]}, self.playerNum) end
        ISInventoryPaneContextMenu.createMenu(self.playerNum, true, {items[1]}, getMouseX(), getMouseY())
    elseif hit.wound then
        Care.openMenu(player, hit.wound.bp, getMouseX(), getMouseY(), hit.wound.kind)
    elseif k == "part" then
        Care.openMenu(player, H.part(player, hit.part), getMouseX(), getMouseY(), nil)
    end
    return true
end

function P:onMouseWheel(del)
    local r = self.sideRect
    if r and T.inRect(self:getMouseX(), self:getMouseY(), r) and (self.maxScroll or 0) > 0 then
        self.scrollTo = clamp(self.scrollTo + del * T.cell * 1.5, 0, self.maxScroll)
    end
    return true
end

-- The health key ----------------------------------------------------------------------------
-- The game's health window (its key, its other ways there) opens the Knox screen on
-- this tab instead; again on it, the screen closes. Not with a gamepad, in split
-- screen, in the tutorial, nor with the module or the inventory screen off
-- (Knox.forPlayer): there it stays the game's.

--- The Knox screen on the Health tab (closed when it already is).
function KnoxHealthPanel.openTab(playerNum)
    local s = KnoxScreen.instance
    if s and s.tab == "Health" then
        s:close()
        return
    end
    if not s then
        Knox.open(playerNum)
        s = KnoxScreen.instance
    end
    if s then s:setTab("Health") end
end

require "XpSystem/ISUI/ISCharacterInfoWindow"
if ISCharacterInfoWindow and not ISCharacterInfoWindow.knoxHealthHooked then
    ISCharacterInfoWindow.knoxHealthHooked = true
    local toggleView = ISCharacterInfoWindow.toggleView
    function ISCharacterInfoWindow:toggleView(view)
        local n = self.playerNum or 0
        if view == xpSystemText.health and Knox and Knox.forPlayer and Knox.forPlayer(n, "health")
                and Knox.forPlayer(n, "inventory") then
            local ok, err = pcall(KnoxHealthPanel.openTab, n)
            if ok then return end
            print("[Knox] health tab: " .. tostring(err))
        end
        return toggleView(self, view)
    end
end

return KnoxHealthPanel
