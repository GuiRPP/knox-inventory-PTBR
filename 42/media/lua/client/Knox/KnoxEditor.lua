-- The item editor (the author, 2026-10-25: "an editor of items right in the game:
-- bag grids and their shape, item sizes, pockets clothing gives, stacks - whether
-- an item stacks and how many a cell; presets, their export and import, a tab for
-- mods, everything back to Knox's own"), after the approved mockup
-- .claude/mockups/editor/editor_v1.html (four rounds of the design critic).
--
-- Three columns: the tabs on the left (the kinds of items, Mods, Changed, Presets),
-- the items of the tab (a search over them all), the item chosen - its size in the
-- grid, a bag's inside (compartments, one grid, cell by cell), the pockets of a
-- piece of clothing, the stack, its category and sound, the line it makes. Every
-- edit goes to one preset (KnoxPresets: "Edits go to" in the foot); Save writes
-- them and puts them in effect at once (the grids on the screen built again).
-- In dev mode the author also edits the mod's own defaults (media/knox/
-- item_defaults.txt); an admin of a server edits the server's presets.
--
-- Drawn from a list of drawing steps made again only when something changes
-- (build): a frame only plays them back, lighting what the mouse is on.

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxEditorData"

KnoxEditor = ISPanel:derive("KnoxEditor")
local E = KnoxEditor
local T = KnoxTheme
local D = KnoxEditorData
local P = KnoxPresets
local F = KnoxFootprint
local inRect = T.inRect

local SCROLL_MS, FADE_MS = 70, 120
E.SIDE = {"bag", "clo", "wpn", "ammo", "med", "food", "tool", "mat", "info", "misc"}
E.SIDE_ALL = {"bag", "clo", "wpn", "ammo", "med", "food", "tool", "mat", "info", "misc", false, "mods", "changed", false, "presets"}
local RED = {r = 0.91, g = 0.455, b = 0.416}     -- the mockup's #e8746a: what takes something away
local function WELL() return T.color.screen end   -- the inventory column's dark (the skin's)
local WHITE = {r = 1, g = 1, b = 1}
local BLACK = {r = 0, g = 0, b = 0}

local function tx(key, ...)
    return getText("IGUI_KnoxEd_" .. key, ...)
end

local function quote(s)
    return getText("IGUI_KnoxEd_Quote", s)
end

-- Building: the drawing steps and the places a click does something ------------------
-- A step is a table {k = kind, reg = region, ...}; regions: 0 the window, 1 the list
-- (scrolls), 2 the item or preset page (scrolls), 3 a dropdown's list over the page.
-- A step may light up under the mouse: hx, hy, hw, hh (in its region).

local B = nil       -- the editor being built
local REG = 0
local LENS = nil   -- the magnifier picture, got on first draw

local function op(t)
    t.reg = REG
    B.ops[#B.ops + 1] = t
    return t
end

local function lit(t, x, y, w, h)
    t.hx, t.hy, t.hw, t.hh = x, y, w, h
    return t
end

local function rect(x, y, w, h, c, a)
    return op({k = "rect", x = x, y = y, w = w, h = h, c = c, a = a or 1})
end

local function border(x, y, w, h, c)
    return op({k = "border", x = x, y = y, w = w, h = h, c = c})
end

local function frame(x, y, w, h, c)
    return op({k = "frame", x = x, y = y, w = w, h = h, c = c})
end

--- Text in the band x, y, w, h (T.label): align "left" / "right" / "centre".
local function label(s, x, y, w, h, c, font, align, a)
    return op({k = "label", s = s, x = x, y = y, w = w, h = h, c = c, font = font or T.fontText, align = align or "left", a = a or 1})
end

local function hit(x, y, w, h, fn, rmb)
    B.hits[#B.hits + 1] = {x = x, y = y, w = w, h = h, reg = REG, fn = fn, rmb = rmb}
end

--- A button (T.button): o = {primary, disabled, font, col, fn}.
local function button(x, y, w, h, s, o)
    o = o or {}
    local t = op({k = "button", x = x, y = y, w = w, h = h, s = s, font = o.font or T.fontCaps, primary = o.primary,
                  disabled = o.disabled, col = o.col})
    if not o.disabled then
        lit(t, x, y, w, h)
        if o.fn then hit(x, y, w, h, o.fn) end
    end
    return t
end

local function textW(font, s)
    return math.ceil(T.measure(font, s))
end

--- The small plate with dark text (CHANGED, IN USE); its right edge at x. Returns its width.
local function plate(s, x, y, h, c)
    local m = T.upper(s)
    local mw = math.floor(T.measure(T.fontTile, m) + 0.5) + 10
    rect(x - mw, y, mw, h, c)
    label(m, x - mw, y, mw, h, T.color.ink, T.fontTile, "centre")
    return mw
end

--- The same plate as a frame (EDITS).
local function plateLine(s, x, y, h, c)
    local m = T.upper(s)
    local mw = math.floor(T.measure(T.fontTile, m) + 0.5) + 10
    border(x - mw, y, mw, h, c)
    label(m, x - mw, y, mw, h, c, T.fontTile, "centre")
    return mw
end

-- Layout ---------------------------------------------------------------------------------

function E:layout()
    T.ensure()
    local c, pad = T.cell, T.pad
    local fc = T.fontH(T.fontCaps)
    local L = {}
    L.c, L.pad = c, pad
    L.headerH = fc + math.floor(pad / 2) + 8
    local sw = math.floor(c * 3.0)
    for _, s in ipairs(E.SIDE_ALL) do
        if s then sw = math.max(sw, textW(T.fontCaps, T.upper(tx("Cat_" .. s))) + pad * 4 + textW(T.fontTile, "00") + pad) end
    end
    L.sideW = sw
    L.listW = math.floor(c * 7.2)
    L.edW = math.floor(c * 15.6)
    L.w = L.sideW + 1 + L.listW + 1 + L.edW
    L.h = math.min(math.floor(c * 17.5), getCore():getScreenHeight() - c * 2)
    L.viewY = L.headerH + 1
    L.footH = math.floor(c * 0.7)
    L.footZone = pad * 2 + L.footH + pad * 2
    L.viewH = L.h - L.footZone - L.viewY
    L.footY = L.h - pad * 2 - L.footH
    L.itemH = math.floor(c * 0.85)
    L.listX = L.sideW + 1
    L.edX = L.listX + L.listW + 1
    L.ex0, L.ex1 = L.edX + pad * 2, L.w - pad * 2
    L.searchH = math.floor(c * 0.7)
    L.rowH = math.floor(c * 0.85)
    L.grpH = fc + pad
    L.choiceH = math.floor(c * 0.31) * 2
    L.stepB, L.stepV = L.choiceH, math.floor(c * 1.05)
    L.box = math.floor(c * 0.5)
    L.tileS = math.floor(c * 1.5)
    L.textH = T.fontH(T.fontText)
    L.capsH = fc
    L.tileH = T.fontH(T.fontTile)
    L.editView = {L.edX, L.viewY, L.edW, L.viewH}
    return L
end

-- The presets ----------------------------------------------------------------------------

--- The preset edits go to (the mod's defaults in dev mode; Knox's own when there is none).
function E:target()
    if self.layer == "mod" then return self.defaultsP end
    local p = self.store and P.find(self.store, self.store.edit)
    return p or self.knoxP
end

function E:setTarget(p)
    if p.defaults or p.builtin then return end
    self.store.edit = p.file
    self.layer = "player"
end

function E:generalOn()
    for _, q in ipairs(self.store.list) do
        if q.on and q.scope == "all" then return q end
    end
    return nil
end

--- One in use a kind: one general, one a tab, one a mod (Knox's own: no general one).
function E:setOn(p, on)
    if p.builtin then
        for _, q in ipairs(self.store.list) do if q.scope == "all" then q.on = false end end
        return
    end
    if on then
        for _, q in ipairs(self.store.list) do if q.scope == p.scope then q.on = false end end
    end
    p.on = on
end

function E:isOn(p)
    if p.builtin then return self:generalOn() == nil end
    return p.on == true
end

--- Does a preset hold this item (it is of its tab, its mod)?
local function holds(p, e)
    local k, v = P.scopeOf(p.scope)
    if k == "all" then return true end
    if k == "tab" then return e.side == v end
    return e.mod == v
end

--- A narrower preset in use with a line for the item: the game shows that one.
function E:overOf(ft)
    local t = self:target()
    if t.defaults then return nil end
    local e = D.byType(ft)
    if not e then return nil end
    local best = nil
    for _, q in ipairs(self.store.list) do
        if q.on and P.rank(q.scope) > P.rank(t.scope) and holds(q, e) and q.items[ft] and (not best or P.rank(q.scope) > P.rank(best.scope)) then
            best = q
        end
    end
    return best
end

function E:scopeText(scope)
    local k, v = P.scopeOf(scope)
    if k == "all" then return tx("For_all") end
    if k == "tab" then return tx("For_cat", tx("Cat_" .. v)) end
    return tx("For_mod", D.modName(v))
end

function E:groupOf(p)
    local k, v = P.scopeOf(p.scope)
    if k == "all" then return tx("Grp_all") end
    if k == "tab" then return tx("Cat_" .. v) end
    return tx("Grp_modP", D.modName(v))
end

local function sortKey(p)
    local k, v = P.scopeOf(p.scope)
    if p.builtin then return "0" end
    if k == "all" then return "1" end
    if k == "tab" then
        for i, s in ipairs(E.SIDE) do if s == v then return "2" .. string.format("%02d", i) end end
    end
    return "3" .. string.lower(D.modName(v) or v)
end

--- A new preset in the store (not in use yet).
function E:addPreset(name, scope, items)
    local p = {name = name, scope = scope or "all", items = items or {}, on = false}
    p.file = P.fileFor(name, self.store)
    D.count(p)
    table.insert(self.store.list, p)
    return p
end

local function copyItems(items)
    local out = {}
    for ft, o in pairs(items) do
        local c = {}
        for k, v in pairs(o) do c[k] = v end
        out[ft] = c
    end
    return out
end

-- Saved or not: each preset's text as it was saved, its being in use, the index

local function presetKey(p)
    return table.concat(P.text(p), "\n") .. (p.on and "|on" or "")
end

function E:snapshot()
    self.saved = {}
    if self.store then
        for _, p in ipairs(self.store.list) do self.saved[p.file] = {key = presetKey(p), items = copyItems(p.items)} end
        self.savedEdit = self.store.edit
    end
    self.savedDefaults = self.defaultsP and copyItems(self.defaultsP.items) or nil
    self.gone = {}
end

--- How many things are not saved: items changed, presets made, taken away, put in or out of use.
local function itemsDiff(a, b)
    local n = 0
    for ft, o in pairs(a) do
        if not b[ft] or P.restOf(b[ft]) ~= P.restOf(o) then n = n + 1 end
    end
    for ft in pairs(b) do if not a[ft] then n = n + 1 end end
    return n
end

function E:unsavedN()
    local n = 0
    if self.store then
        for _, p in ipairs(self.store.list) do
            local s = self.saved[p.file]
            if not s then
                n = n + 1 + D.count(p)
            elseif s.key ~= presetKey(p) then
                n = n + math.max(1, itemsDiff(p.items, s.items))
            end
        end
        for _ in pairs(self.gone) do n = n + 1 end
    end
    if self.defaultsP and self.savedDefaults then n = n + itemsDiff(self.defaultsP.items, self.savedDefaults) end
    return n
end

-- Edits ----------------------------------------------------------------------------------

--- Change the chosen item in the preset edits go to (Knox's own can't be: a new preset
--- is made for it, as the mockup does).
function E:edit(fn)
    local p = self:target()
    if p.builtin then
        -- (in use when Knox's own was: the edit shows at once)
        local was = self:isOn(p)
        p = self:addPreset(tx("NewName"), "all", {})
        self:setTarget(p)
        if was then self:setOn(p, true) end
    end
    local ft = self.sel
    local r = ft and D.recordIn(p, ft)
    if not r then return end
    table.insert(self.undo, {p = p, ft = ft, line = p.items[ft]})
    local nr = D.copy(r)
    fn(nr)
    D.setRecord(p, ft, nr)
    self:build()
end

function E:undoLast()
    local u = table.remove(self.undo)
    if not u then return end
    if u.items then
        u.p.items = u.items
        D.forget(u.p)
    else
        u.p.items[u.ft] = u.line
        D.forget(u.p, u.ft)
        if u.p == self:target() and u.ft ~= self.sel and self.side ~= "presets" then self:pick(u.ft) end
    end
    D.count(u.p)
    self:clampPart()
    self:build()
end

--- Every item of a preset back to Knox's own (can be undone).
function E:resetPreset(p)
    table.insert(self.undo, {p = p, items = p.items})
    p.items = {}
    p.n = 0
    D.forget(p)
end

-- The list --------------------------------------------------------------------------------

function E:listItems()
    local out = {}
    local p = self:target()
    local q = self.query
    for _, e in ipairs(D.items()) do
        local ok
        if q then
            ok = string.find(e.low, q, 1, true) ~= nil or string.find(e.lowId, q, 1, true) ~= nil
        elseif self.side == "changed" then
            ok = p.items[e.ft] ~= nil
        elseif self.side == "mods" then
            ok = e.mod ~= nil
        else
            ok = e.side == self.side
        end
        if ok and holds(p, e) then out[#out + 1] = e end
    end
    if self.side == "mods" and not q then
        -- (the mods' items by mod, in their order; they are in their tabs too)
        local pos = {}
        for i, e in ipairs(out) do pos[e] = i end
        table.sort(out, function(a, b)
            local ma, mb = string.lower(D.modName(a.mod)), string.lower(D.modName(b.mod))
            if ma ~= mb then return ma < mb end
            return pos[a] < pos[b]
        end)
    end
    return out
end

--- Choose an item: its first compartment (the second row's when there are rows, as the mockup).
function E:pick(ft)
    self.sel = ft
    self.part = {1, 1}
    self.popup = nil
    local r = D.recordIn(self:target(), ft)
    if r and r.bag and #r.bag.spec > 1 then self.part = {2, 1} end
    self.eScroll, self.eTarget = 0, 0
end

function E:clampPart()
    local r = self.sel and D.recordIn(self:target(), self.sel)
    if r and r.bag then
        local spec = r.bag.spec
        self.part[1] = math.max(1, math.min(self.part[1], #spec))
        self.part[2] = math.max(1, math.min(self.part[2], #spec[self.part[1]]))
    end
end

function E:goSide(s)
    self.side = s
    self.popup = nil
    self.lScroll, self.lTarget, self.eScroll, self.eTarget = 0, 0, 0, 0
    self.flash = nil
    if self.searchBox then self.searchBox:setText("") end
    self.query = nil
    if s == "presets" then
        self.psel = self:target()
        return
    end
    local l = self:listItems()
    local found = false
    for _, e in ipairs(l) do if e.ft == self.sel then found = true end end
    if #l > 0 and not found then self:pick(l[1].ft) end
end

--- To the edited preset's items.
function E:goScope(p)
    local k, v = P.scopeOf(p.scope)
    self:goSide(k == "tab" and v or (k == "mod" and "mods" or "bag"))
end

-- Build: the column of tabs ----------------------------------------------------------------

function E:buildSide()
    local L, pad = self.L, T.pad
    local y = L.viewY + pad * 2 + math.floor((L.searchH - L.itemH) / 2)
    local p = self:target()
    for _, s in ipairs(E.SIDE_ALL) do
        if not s then
            rect(pad * 2, y + math.floor(pad / 2), L.sideW - pad * 4, 1, T.color.line)
            y = y + pad
        else
            -- (a tab with nothing the edited preset may hold is dim; worked out once a scope)
            if self.offFor ~= p.scope then
                self.offFor, self.offs = p.scope, {}
                for _, s2 in ipairs(E.SIDE_ALL) do if s2 and s2 ~= "changed" and s2 ~= "presets" then self.offs[s2] = true end end
                for _, e in ipairs(D.items()) do
                    if holds(p, e) then
                        self.offs[e.side] = nil
                        if e.mod then self.offs.mods = nil end
                    end
                end
            end
            local off = self.offs[s] == true
            local on = not self.query and self.side == s
            if on then
                rect(2, y, L.sideW - 2, L.itemH, T.color.header)
                rect(2, y, 3, L.itemH, T.color.accent)
            end
            local t = label(T.upper(tx("Cat_" .. s)), pad * 2, y, L.sideW - pad * 3, L.itemH, on and T.color.bright or T.color.dim, T.fontCaps, "left", off and 0.35 or 1)
            if not off then
                if not on then t.hc = T.color.text lit(t, 0, y, L.sideW, L.itemH) end
                if s == "changed" then
                    local n = 0
                    for ft in pairs(p.items) do
                        local e = D.byType(ft)
                        if e and holds(p, e) then n = n + 1 end
                    end
                    if n > 0 then label(tostring(n), 0, y, L.sideW - pad * 2, L.itemH, T.color.accent, T.fontCaps, "right") end
                end
                hit(0, y, L.sideW, L.itemH, function() self:goSide(s) end)
            end
            y = y + L.itemH
        end
    end
end

-- Build: the list of items ------------------------------------------------------------------

function E:buildList()
    local L, pad = self.L, T.pad
    local x0, w = L.listX + pad * 2, L.listW - pad * 4
    self.searchR = {x0, L.viewY + pad * 2, w, L.searchH}
    -- the search field's plate and lens, as the mockup has them (25.10, found on the shots)
    local sy = L.viewY + pad * 2
    rect(x0, sy, w, L.searchH, T.color.cell)
    local t = border(x0, sy, w, L.searchH, T.color.tileEdge)
    t.hc, t.box = T.color.accent, self.searchBox
    lit(t, x0, sy, w, L.searchH)
    local ls = math.floor(L.searchH * 0.5)
    t = op({k = "lens", x = x0 + pad, y = sy + math.floor((L.searchH - ls) / 2), w = ls, h = ls, c = T.color.dim})
    t.hc, t.box = T.color.accent, self.searchBox
    lit(t, x0, sy, w, L.searchH)
    local vy = L.viewY + pad * 2 + L.searchH + pad
    local p = self:target()
    if self.side == "changed" and not self.query then
        -- everything of the edited preset back to Knox's own, asked twice
        local sure = self.resetAsk
        button(x0, vy, w, L.choiceH, sure and tx("ResetSure") or tx("ResetAllChanged"), {font = T.fontTile,
            col = sure and T.color.warn or RED, disabled = D.count(p) == 0,
            fn = function() if self.asked == "reset" then self:resetPreset(p) else self.resetAsk = true end end})
        vy = vy + L.choiceH + pad
    end
    local vh = L.viewY + L.viewH - vy
    self.listView = {L.listX, vy, L.listW, vh}
    REG = 1
    local items = self:listItems()
    self.listN = #items
    -- (where each row is: made for all, drawn for those in sight - see E:prerender)
    local y, lastG = vy, nil
    local perMod = {}
    for _, e in ipairs(items) do if e.mod then perMod[e.mod] = (perMod[e.mod] or 0) + 1 end end
    local top, bottom = vy + self.lTarget - L.viewH, vy + self.lTarget + L.viewH * 2
    self.listWin = {self.lTarget - L.viewH, self.lTarget + L.viewH}
    for _, e in ipairs(items) do
        local grp = nil
        if not self.query then
            if self.side == "mods" then grp = tx("Grp_modP", D.modName(e.mod)) .. " · " .. perMod[e.mod]
            elseif (self.side == "bag" or self.side == "clo") and e.grp then grp = tx(e.grp) end
        end
        if grp and grp ~= lastG then
            if y + L.grpH >= top and y <= bottom then
                label(T.upper(grp), x0, y + math.floor(pad / 2), 0, L.grpH - math.floor(pad / 2), T.color.dim, T.fontTile)
            end
            y = y + L.grpH
            lastG = grp
        end
        if y + L.rowH >= top and y <= bottom then
            local on = e.ft == self.sel
            local rx, rw = L.listX + 1, L.listW - 2
            if on then
                rect(rx, y, rw, L.rowH, T.color.header)
                rect(rx, y, 3, L.rowH, T.color.accent)
            else
                lit(rect(rx, y, rw, L.rowH, WHITE, 0.04), rx, y, rw, L.rowH).only = true
            end
            local r = D.recordIn(p, e.ft)
            local ib = L.rowH - 6
            rect(x0, y + 3, ib, ib, T.category[r and r.tile or "misc"] or T.category.misc)
            border(x0, y + 3, ib, ib, T.color.tileEdge)
            local tex = D.texture(e)
            if tex then op({k = "tex", tex = tex, x = x0, y = y + 3, w = ib, h = ib}) end
            local szw = textW(T.fontTile, "0×0") + pad
            if r then
                local sz = math.min(r.w, r.h) .. "×" .. math.max(r.w, r.h)
                label(sz, 0, y, x0 + w, L.rowH, p.items[e.ft] and T.color.accent or T.color.dim, T.fontTile, "right")
            end
            local nx = x0 + ib + pad
            label(T.fit(e.name, T.fontText, x0 + w - szw - nx - pad), nx, y, 0, L.rowH, on and T.color.bright or T.color.text)
            local ft = e.ft
            hit(rx, y, rw, L.rowH, function() self:pick(ft) end)
        end
        y = y + L.rowH
    end
    if #items == 0 then label(tx("NoneFound"), x0, y + pad, 0, L.rowH, T.color.dim) end
    self.lMax = math.max(0, y - vy - vh + pad)
    op({k = "fade", which = 1})
    REG = 0
end

-- Build: the item ----------------------------------------------------------------------------

--- [−] value [+]; returns its width. o = {canMinus, canPlus, minus, plus, changed, off, vw}
function E:stepper(x, y, val, o)
    local L = self.L
    local b, vw = L.stepB, o.vw or L.stepV
    if o.off then o.canMinus, o.canPlus = false, false end
    local function side(bx, plus, can, fn)
        rect(bx, y, b, b, T.color.buttonBg)
        local t = border(bx, y, b, b, T.color.tileEdge)
        local m = op({k = "pm", x = bx, y = y, w = b, h = b, plus = plus, c = can and T.color.text or T.color.dim, a = can and 1 or 0.35})
        if can then
            t.hc, m.hc = T.color.accent, T.color.accent
            lit(t, bx, y, b, b)
            lit(m, bx, y, b, b)
            hit(bx, y, b, b, fn)
        end
    end
    side(x, false, o.canMinus, o.minus)
    side(x + b + 2 + vw + 2, true, o.canPlus, o.plus)
    local vx = x + b + 2
    rect(vx, y, vw, b, T.color.cell)
    border(vx, y, vw, b, o.changed and T.color.accent or T.color.tileEdge)
    label(tostring(val), vx, y, vw, b, o.off and T.color.dim or (o.changed and T.color.accent or T.color.bright), T.fontCaps, "centre", o.off and 0.5 or 1)
    return b * 2 + vw + 4
end

--- A box to tick and its name; w: the width that takes the click; changed: a CHANGED plate after it.
function E:check(x, y, on, s, fn, w, changed)
    local L, pad = self.L, T.pad
    local b = L.box
    local rw = w or (b + pad + textW(T.fontText, s))
    rect(x, y, b, b, T.color.cell)
    local t = border(x, y, b, b, on and T.color.accent or T.color.tileEdge)
    t.hc = T.color.accent
    lit(t, x, y, rw, b)
    if on then rect(x + 4, y + 4, b - 8, b - 8, T.color.accent) end
    label(s, x + b + pad, y, 0, b, on and T.color.bright or T.color.text)
    if changed then
        local m = T.upper(tx("Changed"))
        local mw = math.floor(T.measure(T.fontTile, m) + 0.5) + 10
        local ph = L.tileH + 4
        plate(tx("Changed"), x + b + pad + textW(T.fontText, s) + pad + mw, y + math.floor((b - ph) / 2), ph, T.color.accent)
    end
    hit(x, y, rw, b, fn)
end

function E:section(s, y, line)
    local L, pad = self.L, T.pad
    if line then rect(L.ex0, y - pad, L.ex1 - L.ex0, 1, T.color.line) end
    label(T.upper(s), L.ex0, y, 0, L.capsH, T.color.accent, T.fontCaps)
    return y + L.capsH + pad
end

local function itemTex(e, x, y, w, h)
    local tex = e and D.texture(e)
    if not tex then return end
    local k = math.floor(math.min(w, h) * 0.85)   -- (KnoxGridView: a square of 85% of the short side)
    op({k = "tex", tex = tex, x = x + math.floor((w - k) / 2 + 0.5), y = y + math.floor((h - k) / 2 + 0.5), w = k, h = k})
end

--- The item's tile as the grid draws it: its category's color, its frame, its picture.
local function itemTile(e, tile, x, y, cs, w, h)
    local tw, th = h * cs, w * cs
    rect(x, y, tw, th, T.category[tile] or T.category.misc)
    frame(x, y, tw, th, T.color.tileFrame)
    itemTex(e, x, y, tw, th)
end

function E:buildItem()
    local L, pad, c = self.L, T.pad, T.cell
    local x0, x1 = L.ex0, L.ex1
    REG = 2
    local y = L.viewY + pad * 2
    local p = self:target()
    local e = self.sel and D.byType(self.sel)
    local u = e and D.recordIn(p, e.ft)
    local d = e and D.defaultOf(p, e.ft)
    if not (u and d) then
        label(tx("NoneFound"), x0, y, 0, L.textH, T.color.dim)
        self.eMax = 0
        op({k = "fade", which = 2})
        REG = 0
        return
    end
    local ft = e.ft
    -- the item: its tile, name and ID; Changed + Reset or "as Knox has it"
    local TS = L.tileS
    rect(x0, y, TS, TS, T.category[u.tile] or T.category.misc)
    frame(x0, y, TS, TS, T.color.tileFrame)
    itemTex(e, x0, y, TS, TS)
    local nx = x0 + TS + pad * 2
    local chg = p.items[ft] ~= nil
    local nameR = x1
    local ov = self:isOn(p) and self:overOf(ft) or nil
    if chg then
        local rw = textW(T.fontTile, T.upper(tx("Reset"))) + pad * 2
        local rr = {x1 - rw, y + math.floor((TS - L.choiceH) / 2), rw, L.choiceH}
        button(rr[1], rr[2], rr[3], rr[4], tx("Reset"), {font = T.fontTile, fn = function()
            self:edit(function(o) for k, v in pairs(D.copy(d)) do o[k] = v end end)
        end})
        local pw = plate(tx("Changed"), rr[1] - pad, rr[2] + math.floor((L.choiceH - L.tileH - 4) / 2), L.tileH + 4, T.color.accent)
        nameR = rr[1] - pad * 2 - pw
    elseif not ov then
        local s = T.upper(tx("Default"))
        label(s, x1 - 400, y, 400, TS, T.color.dim, T.fontTile, "right")
        nameR = x1 - textW(T.fontTile, s) - pad * 2
    end
    local nh = L.capsH + 2 + L.textH
    local gy0 = y + math.floor((TS - nh) / 2)
    label(T.fit(T.upper(e.name), T.fontCaps, nameR - nx), nx, gy0, 0, L.capsH, T.color.bright, T.fontCaps)
    local idText = ft .. (e.mod and ("  ·  " .. D.modName(e.mod)) or "")
    label(T.fit(idText, T.fontText, nameR - nx), nx, gy0 + L.capsH + 2, 0, L.textH, T.color.dim)
    y = y + TS + pad * 3
    -- the band: another preset goes over this item in the game, or this one isn't in use
    if not p.defaults and (not self:isOn(p) or ov) then
        local other = nil
        if not ov then
            for _, q in ipairs(self.store.list) do if q.on and q.scope == p.scope then other = q end end
        end
        local bs = ov and tx("EditThere") or (other and tx("MakeActive", quote(other.name)) or tx("TurnOn"))
        local bw = textW(T.fontTile, T.upper(bs)) + pad * 2
        local bh = L.choiceH + pad * 2
        local by = y - math.floor(pad / 2)
        rect(x0, by, x1 - x0, bh, T.color.warn, 0.12)
        rect(x0, by, 3, bh, T.color.warn)
        local msg = ov and tx("Over", quote(ov.name)) or tx("Off", quote(p.name))
        label(T.fit(msg, T.fontText, x1 - x0 - bw - pad * 3 - 3), x0 + 3 + pad, by, 0, bh, T.color.warn)
        button(x1 - pad - bw, by + pad, bw, L.choiceH, bs, {font = T.fontTile, fn = function()
            if ov then self:setTarget(ov) else self:setOn(p, true) end
        end})
        y = by + bh + math.floor(pad * 2.5) + pad
    end

    -- the size in the grid
    y = self:section(tx("Sec_size"), y, true)
    local ry = y
    local x = x0
    local function word(s)
        label(s, x, ry, 0, L.stepB, T.color.text)
        x = x + textW(T.fontText, s) + pad
    end
    local function sideStep(key)
        return {canMinus = u[key] > 1, canPlus = u[key] < (key == "w" and D.MAX_W or D.MAX_H), changed = u[key] ~= d[key],
                minus = function() self:edit(function(o) o[key] = o[key] - 1 end) end,
                plus = function() self:edit(function(o) o[key] = o[key] + 1 end) end}
    end
    word(tx("Width"))
    x = x + self:stepper(x, ry, u.w, sideStep("w")) + pad * 3
    word(tx("Length"))
    x = x + self:stepper(x, ry, u.h, sideStep("h"))
    local hintY = ry + L.stepB + pad
    label(tx("RulesSize", math.min(d.w, d.h) .. "×" .. math.max(d.w, d.h), tx(u.kind == "clo" and "How_worn" or "How_model")), x0, hintY, 0, L.textH, T.color.dim)
    -- a preview: the tile on a few cells, as the inventory draws it
    local px = x + pad * 4
    local availW, availH = x1 - px, L.stepB + pad + L.textH
    local sw, lw = math.min(u.w, u.h), math.max(u.w, u.h)
    local pcs = math.max(8, math.floor(math.min(c * 0.62, availW / (lw + 1), availH / sw)))
    itemTile(e, u.tile, x1 - lw * pcs, ry + math.floor((availH - sw * pcs) / 2), pcs, sw, lw)
    y = hintY + L.textH + pad * 3

    if u.kind == "bag" then y = self:buildBag(e, u, d, y) end
    if u.kind == "clo" then y = self:buildPockets(e, u, d, y) end
    if u.stackOn ~= nil then
        y = self:section(tx("Sec_stack"), y + pad, true)
        self:check(x0, y, u.stackOn, tx("Stacks"), function() self:edit(function(o) o.stackOn = not o.stackOn end) end, nil, u.stackOn ~= d.stackOn)
        y = y + L.box + pad
        -- the count under it, at the left, as the size's and the pockets' steppers
        local s = tx("StackN")
        local sx = x0 + textW(T.fontText, s) + pad
        label(s, x0, y, 0, L.stepB, u.stackOn and T.color.text or T.color.dim)
        local i = 1
        for k, v in ipairs(D.NICE) do if v <= u.stack then i = k end end
        self:stepper(sx, y, u.stack, {off = not u.stackOn, canMinus = u.stack > D.NICE[1], canPlus = i < #D.NICE,
            changed = u.stackOn and u.stack ~= d.stack,
            minus = function() self:edit(function(o)
                local j = 1
                for k, v in ipairs(D.NICE) do if v < o.stack then j = k end end
                o.stack = D.NICE[j]
            end) end,
            plus = function() self:edit(function(o)
                for _, v in ipairs(D.NICE) do if v > o.stack then o.stack = v return end end
            end) end})
        y = y + L.stepB + pad
        label(d.stackOn and tx("RulesStack", d.stack) or tx("RulesNoStack"), x0, y, 0, L.textH, T.color.dim)
        y = y + L.textH + 2
        -- (turned on for a kind of thing Knox never stacks: what the rule will be)
        if u.stackOn and not d.stackOn then
            label(tx("StackSame"), x0, y, 0, L.textH, T.color.warn)
            y = y + L.textH + 2
        end
        y = y + pad * 3 - 2
    end
    -- category and sound: dropdowns
    y = self:section(tx("Sec_look"), y + pad, true)
    local ddW = math.floor((x1 - x0 - pad) / 2)
    self:dropdown(x0, y, ddW, L.choiceH, tx("Category"), getText("IGUI_Knox_Cat_" .. u.tile), T.category[u.tile], u.tile ~= d.tile, "cat")
    self:dropdown(x0 + ddW + pad, y, x1 - x0 - ddW - pad, L.choiceH, tx("Sound"), tx("Snd_" .. u.snd), nil, u.snd ~= d.snd, "snd")
    y = y + L.choiceH + pad * 3
    -- the line for the file
    y = self:section(tx("Sec_line"), y + pad, true)
    local line = p.items[ft] and (ft .. " = " .. P.restOf(p.items[ft])) or nil
    local cw = textW(T.fontTile, T.upper(tx("Copy"))) + pad * 2
    local ww = x1 - x0 - cw - pad
    rect(x0, y, ww, L.choiceH, T.color.cell)
    border(x0, y, ww, L.choiceH, T.color.tileEdge)
    -- (the game's monospace font: the line as the file has it)
    label(T.fit(line or tx("NoLine"), UIFont.Code, ww - pad * 2), x0 + pad, y, 0, L.choiceH, line and T.color.bright or T.color.dim, UIFont.Code)
    button(x1 - cw, y, cw, L.choiceH, tx("Copy"), {font = T.fontTile, disabled = not line, fn = function()
        if Clipboard then Clipboard.setClipboard(line) end
    end})
    y = y + L.choiceH + pad * 2
    self.eMax = math.max(0, y - L.viewY - L.viewH)
    op({k = "fade", which = 2})
    REG = 0
end

function E:dropdown(x, y, w, h, name, value, swatch, changed, kind)
    local pad = T.pad
    local open = self.popup and self.popup.kind == kind
    rect(x, y, w, h, T.color.buttonBg)
    local t = border(x, y, w, h, (open or changed) and T.color.accent or T.color.tileEdge)
    t.hc = T.color.accent
    lit(t, x, y, w, h)
    local nm = T.upper(name)
    local cx = x + pad
    label(nm, cx, y, 0, h, T.color.dim, T.fontTile)
    cx = cx + textW(T.fontTile, nm) + pad
    local sx0 = cx
    if swatch then
        local s = math.floor(h * 0.5)
        local sy = y + math.floor((h - s) / 2)
        rect(cx, sy, s, s, swatch)
        border(cx, sy, s, s, T.color.tileHover)
        cx = cx + s + pad
    end
    -- the chevron
    local n = math.max(3, math.floor(h / 7))
    local ch = op({k = "chev", x = x + w - pad - n, y = y + math.floor((h - n) / 2), n = n, c = open and T.color.accent or T.color.text})
    ch.hc = T.color.accent
    lit(ch, x, y, w, h)
    label(T.fit(value, T.fontText, x + w - pad * 2 - n * 2 - cx), cx, y, 0, h, changed and T.color.accent or T.color.bright)
    hit(x, y, w, h, function() self.popup = {kind = kind, x = x, y = y, w = w, h = h, sx = sx0} end)
end

function E:buildPopup()
    local pp = self.popup
    if not pp then return end
    local L, pad, c = self.L, T.pad, T.cell
    local u = D.recordIn(self:target(), self.sel)
    if not u then return end
    REG = 3
    local keys = pp.kind == "cat" and D.KCATS or D.SOUNDS
    local rh = math.floor(c * 0.55)
    local cols = pp.kind == "snd" and 2 or 1
    local x0 = pp.sx - pad - 2
    local w = pp.x + pp.w - x0
    local per = math.ceil(#keys / cols)
    local h = per * rh + pad
    local y0 = pp.y + pp.h + 2
    if y0 + h - self.eScroll > L.viewY + L.viewH then y0 = pp.y - h - 2 end
    rect(x0 + 3, y0 + 4, w, h, BLACK, 0.45)
    rect(x0, y0, w, h, T.color.window)
    border(x0, y0, w, h, T.color.accent)
    local cw = math.floor(w / cols)
    for i, k in ipairs(keys) do
        local col, row = math.floor((i - 1) / per), (i - 1) % per
        local rx, ry, rw = x0 + col * cw + 2, y0 + math.floor(pad / 2) + row * rh, cw - 4
        local cur = (pp.kind == "cat" and u.tile or u.snd) == k
        if cur then
            rect(rx, ry, rw, rh, T.color.header)
            rect(rx, ry, 3, rh, T.color.accent)
        else
            lit(rect(rx, ry, rw, rh, WHITE, 0.05), rx, ry, rw, rh).only = true
        end
        local x = rx + pad
        if pp.kind == "cat" then
            local s = math.floor(L.choiceH * 0.5)
            local sy = ry + math.floor((rh - s) / 2)
            rect(x, sy, s, s, T.category[k])
            border(x, sy, s, s, T.color.tileHover)
            x = x + s + pad
        end
        local name = pp.kind == "cat" and getText("IGUI_Knox_Cat_" .. k) or tx("Snd_" .. k)
        label(T.fit(name, T.fontText, rx + rw - x - pad), x, ry, 0, rh, cur and T.color.bright or T.color.text)
        hit(rx, ry, rw, rh, function()
            self.popup = nil
            self:edit(function(o) if pp.kind == "cat" then o.tile = k else o.snd = k end end)
        end)
    end
    self.popupR = {x0, y0, w, h}
    REG = 0
end

-- Build: a bag's inside --------------------------------------------------------------------

local function cellsAt(x, y, w, h, cs, fill)
    rect(x, y, w * cs, h * cs, fill or T.color.cell)
    for i = 1, w - 1 do rect(x + i * cs, y, 1, h * cs, T.color.line) end
    for j = 1, h - 1 do rect(x, y + j * cs, w * cs, 1, T.color.line) end
    border(x, y, w * cs, h * cs, T.color.border)
end

local function well(x, y, w, h, changed)
    rect(x, y, w, h, WELL())
    border(x, y, w, h, changed and T.color.accent or T.color.border)
end

function E:buildBag(e, u, d, y)
    local L, pad, c = self.L, T.pad, T.cell
    local x0, x1 = L.ex0, L.ex1
    local b = u.bag
    y = self:section(tx("Sec_inside"), y + pad, true)
    -- the three ways, as the settings' choices
    local modes = {"parts", "grid", "mask"}
    local gap = 4
    local bw = math.floor((x1 - x0 - gap * 2) / 3)
    for i, m in ipairs(modes) do
        local bx = x0 + (i - 1) * (bw + gap)
        button(bx, y, i == 3 and (x1 - bx) or bw, L.choiceH, tx("Mode_" .. m), {font = T.fontTile, primary = b.mode == m, fn = function()
            if b.mode == m then return end
            self:edit(function(o)
                local ob = o.bag
                if m == "mask" and not ob.mask then
                    ob.mask = D.specToMask(ob.mode == "grid" and {{{w = ob.grid[1], h = ob.grid[2]}}} or ob.spec)
                end
                if m == "mask" then D.maskCanvas(ob.mask) end
                ob.mode = m
            end)
        end})
    end
    y = y + L.choiceH + pad * 2
    -- the shape on the left, the panel on the right
    local panW = math.floor(c * 5.2)
    local zx, zw, px = x0, x1 - x0 - panW - pad * 3, x1 - panW
    local changed = D.bagKey(b) ~= D.bagKey(d.bag)
    local zh
    if b.mode == "parts" then zh = self:buildParts(b, zx, y, zw, changed)
    elseif b.mode == "grid" then zh = self:buildGrid(b, zx, y, zw, changed)
    else zh = self:buildMask(b, zx, y, zw, changed) end
    local ph = self:buildBagPanel(u, d, px, y, panW)
    return y + math.max(zh, ph) + pad * 3
end

--- KnoxBagShapes' way: rows centred under the widest, compartments centred on their row.
local function geometry(spec, cs)
    local gap = math.max(2, math.floor(cs * 0.2 + 0.5))
    local rows, W, H = {}, 0, 0
    for ri, row in ipairs(spec) do
        local rw, rh = 0, 0
        for _, p in ipairs(row) do
            rw = rw + p.w * cs
            rh = math.max(rh, p.h * cs)
        end
        rw = rw + (#row - 1) * gap
        rows[ri] = {w = rw, h = rh}
        W = math.max(W, rw)
        H = H + rh
    end
    H = H + (#spec - 1) * gap
    local parts, y = {}, 0
    for ri, row in ipairs(spec) do
        local x = (W - rows[ri].w) / 2
        for ci, p in ipairs(row) do
            parts[#parts + 1] = {ri = ri, ci = ci, x = math.floor(x + 0.5), y = math.floor(y + (rows[ri].h - p.h * cs) / 2 + 0.5), w = p.w, h = p.h}
            x = x + p.w * cs + gap
        end
        y = y + rows[ri].h + gap
    end
    return W, H, parts
end

function E:buildParts(b, zx, top, zw, changed)
    local pad, c = T.pad, T.cell
    local spec = b.spec
    local lw, lh, most = 0, 0, 1
    for _, row in ipairs(spec) do
        local w = 0
        for _, p in ipairs(row) do w = w + p.w end
        lw = math.max(lw, w)
        lh = lh + D.rowHeight(row)
        most = math.max(most, #row)
    end
    local cs = math.max(10, math.floor(math.min(c * 0.72, (zw - pad * 4) / (lw + (most - 1) * 0.2), (c * 9) / (lh + #spec * 0.2))))
    local W, H, parts = geometry(spec, cs)
    local wh = H + pad * 4
    well(zx, top, zw, wh, changed)
    local ox, oy = zx + math.floor((zw - W) / 2), top + pad * 2
    for _, p in ipairs(parts) do
        local on = p.ri == self.part[1] and p.ci == self.part[2]
        local rx, ry, rw, rh = ox + p.x, oy + p.y, p.w * cs, p.h * cs
        cellsAt(rx, ry, p.w, p.h, cs)
        if on then
            frame(rx - 2, ry - 2, rw + 4, rh + 4, T.color.tileHover)
        else
            lit(frame(rx - 1, ry - 1, rw + 2, rh + 2, T.color.tileHover), rx, ry, rw, rh).only = true
        end
        if rw >= c * 0.9 and rh >= self.L.tileH + 4 then
            label(p.w .. "×" .. p.h, rx, ry, rw, rh, on and T.color.accent or T.color.dim, T.fontTile, "centre")
        end
        local ri, ci = p.ri, p.ci
        hit(rx, ry, rw, rh, function() self.part = {ri, ci} end)
    end
    return wh
end

function E:buildGrid(b, zx, top, zw, changed)
    local pad, c = T.pad, T.cell
    local gc, gr = b.grid[1], b.grid[2]
    local cs = math.max(10, math.floor(math.min(c * 0.72, (zw - pad * 4) / gc, (c * 9) / gr)))
    local wh = gr * cs + pad * 4
    well(zx, top, zw, wh, changed)
    cellsAt(zx + math.floor((zw - gc * cs) / 2), top + pad * 2, gc, gr, cs)
    return wh
end

function E:buildMask(b, zx, top, zw, changed)
    local pad, c = T.pad, T.cell
    local m = b.mask
    local H, W = #m, #m[1]
    local cs = math.max(10, math.floor(math.min(c * 0.6, (zw - pad * 4) / W, (c * 9) / H)))
    local wh = H * cs + pad * 4
    well(zx, top, zw, wh, changed)
    local ox, oy = zx + math.floor((zw - W * cs) / 2), top + pad * 2
    local id = D.maskGroups(m)
    local edge = T.color.tileFrame
    for y = 1, H do
        for x = 1, W do
            local cx, cy = ox + (x - 1) * cs, oy + (y - 1) * cs
            if m[y][x] == 1 then
                rect(cx, cy, cs, cs, T.color.cell)
                -- the compartment's outline: an edge where the next cell is not of it
                local g = id[y][x]
                rect(cx, cy, cs, 1, (y > 1 and id[y - 1][x] == g) and T.color.line or edge)
                if not (y < H and id[y + 1][x] == g) then rect(cx, cy + cs - 1, cs, 1, edge) end
                rect(cx, cy, 1, cs, (x > 1 and id[y][x - 1] == g) and T.color.line or edge)
                if not (x < W and id[y][x + 1] == g) then rect(cx + cs - 1, cy, 1, cs, edge) end
            else
                -- an empty place: a small dot in its middle
                rect(cx + math.floor(cs / 2) - 1, cy + math.floor(cs / 2) - 1, 2, 2, T.color.tileEdge)
            end
            lit(border(cx, cy, cs, cs, T.color.accent), cx, cy, cs, cs).only = true
        end
    end
    -- the canvas takes a press (LMB adds, RMB takes away) and a drag
    local canvas = {ox = ox, oy = oy, cs = cs, W = W, H = H}
    local function paint(v)
        return function()
            local mx, my = self:mouseIn(2)
            local x, y = math.floor((mx - ox) / cs) + 1, math.floor((my - oy) / cs) + 1
            if x < 1 or y < 1 or x > W or y > H then return end
            canvas.v = v
            self.paint = canvas
            self:edit(function(o) o.bag.mask[y][x] = v end)
        end
    end
    hit(ox, oy, W * cs, H * cs, paint(1))
    hit(ox, oy, W * cs, H * cs, paint(0), true)
    return wh
end

function E:buildBagPanel(u, d, px, top, pw)
    local L, pad = self.L, T.pad
    local b = u.bag
    local y = top
    local function row(s, val, o)
        label(s, px, y, 0, L.stepB, T.color.text)
        self:stepper(px + pw - (L.stepB * 2 + L.stepV + 4), y, val, o)
        y = y + L.stepB + pad
    end
    local function bagEdit(fn)
        self:edit(function(o) fn(o.bag) end)
        self:clampPart()
        self:build()
    end
    if b.mode == "parts" then
        local spec = b.spec
        local n, idx = 0, 0
        for ri, r in ipairs(spec) do
            for ci = 1, #r do
                n = n + 1
                if ri == self.part[1] and ci == self.part[2] then idx = n end
            end
        end
        label(T.upper(tx("Part")), px, y, 0, L.capsH, T.color.dim, T.fontCaps)
        label(tx("PartOf", idx, n), px, y, pw, L.capsH, T.color.bright, T.fontCaps, "right")
        y = y + L.capsH + pad
        local ri, ci = self.part[1], self.part[2]
        local rowA = spec[ri]
        local cur = rowA[ci]
        local twin = #rowA + 1 - ci
        local function set(k, dv)
            bagEdit(function(ob)
                local r2 = ob.spec[ri]
                r2[ci][k] = r2[ci][k] + dv
                if self.mirror and twin ~= ci then r2[twin][k] = r2[ci][k] end
            end)
        end
        local wide = D.rowCells(rowA)
        row(tx("Width"), cur.w, {canMinus = cur.w > 1, canPlus = wide < D.MAX_ROW, minus = function() set("w", -1) end, plus = function() set("w", 1) end})
        row(tx("Height"), cur.h, {canMinus = cur.h > 1, canPlus = cur.h < 10, minus = function() set("h", -1) end, plus = function() set("h", 1) end})
        self:check(px, y, self.mirror, tx("Mirror"), function() self.mirror = not self.mirror end, pw)
        y = y + L.box + pad * 2
        local bh = L.choiceH
        local half = math.floor((pw - 4) / 2)
        button(px, y, pw, bh, tx("AddInRow"), {font = T.fontTile, disabled = wide + 2 > D.MAX_ROW, fn = function()
            bagEdit(function(ob)
                local r2 = ob.spec[ri]
                if self.mirror then
                    table.insert(r2, 1, {w = 1, h = 2})
                    table.insert(r2, {w = 1, h = 2})
                    self.part = {ri, ci + 1}
                else
                    table.insert(r2, {w = 1, h = 2})
                end
            end)
        end})
        y = y + bh + 4
        button(px, y, half, bh, tx("AddRowUp"), {font = T.fontTile, disabled = #spec >= 6, fn = function()
            bagEdit(function(ob) table.insert(ob.spec, ri, {{w = 2, h = 1}}) self.part = {ri, 1} end)
        end})
        button(px + half + 4, y, pw - half - 4, bh, tx("AddRowDown"), {font = T.fontTile, disabled = #spec >= 6, fn = function()
            bagEdit(function(ob) table.insert(ob.spec, ri + 1, {{w = 2, h = 1}}) self.part = {ri + 1, 1} end)
        end})
        y = y + bh + 4
        button(px, y, pw, bh, tx("Remove"), {font = T.fontTile, col = RED, disabled = n <= 1, fn = function()
            bagEdit(function(ob)
                local r2 = ob.spec[ri]
                if self.mirror and twin ~= ci then
                    table.remove(r2, math.max(ci, twin))
                    table.remove(r2, math.min(ci, twin))
                else
                    table.remove(r2, ci)
                end
                if #r2 == 0 then table.remove(ob.spec, ri) end
                self.part = {math.min(ri, #ob.spec), 1}
            end)
        end})
        y = y + bh + pad * 2
    elseif b.mode == "grid" then
        local gc, gr = b.grid[1], b.grid[2]
        row(tx("Cols"), gc, {canMinus = gc > 1, canPlus = gc < D.MAX_ROW,
            minus = function() bagEdit(function(ob) ob.grid[1] = ob.grid[1] - 1 end) end,
            plus = function() bagEdit(function(ob) ob.grid[1] = ob.grid[1] + 1 end) end})
        row(tx("Rows"), gr, {canMinus = gr > 1, canPlus = gr < D.MAX_ROWS,
            minus = function() bagEdit(function(ob) ob.grid[2] = ob.grid[2] - 1 end) end,
            plus = function() bagEdit(function(ob) ob.grid[2] = ob.grid[2] + 1 end) end})
        y = y + pad
    else
        for _, ln in ipairs(T.wrap(tx("MaskHelp"), T.fontText, pw)) do
            label(ln, px, y, 0, L.textH, T.color.dim)
            y = y + L.textH + 2
        end
        y = y + pad
        local half, bh = math.floor((pw - 4) / 2), L.choiceH
        button(px, y, half, bh, tx("Clear"), {font = T.fontTile, fn = function()
            bagEdit(function(ob)
                for _, r in ipairs(ob.mask) do for x = 1, #r do r[x] = 0 end end
            end)
        end})
        button(px + half + 4, y, pw - half - 4, bh, tx("FromParts"), {font = T.fontTile, fn = function()
            bagEdit(function(ob) ob.mask = D.specToMask(ob.spec) end)
        end})
        y = y + bh + pad * 2
    end
    -- the count, against what the game's capacity gives
    rect(px, y - pad, pw, 1, T.color.line)
    label(tx("Cells", D.bagCellsOf(b)), px, y, 0, L.textH, T.color.bright)
    y = y + L.textH + 2
    label(tx("GameGives", b.cap or 0), px, y, 0, L.textH, T.color.dim)
    y = y + L.textH + 2
    local wide, tall = false, false
    if b.mode == "parts" then
        for _, r in ipairs(b.spec) do if D.rowCells(r) > D.MAX_ROW then wide = true end end
        tall = D.specRows(b.spec) > D.MAX_ROWS
    elseif b.mode == "grid" then
        tall = b.grid[2] > D.MAX_ROWS
    end
    if wide then label(tx("TooWide"), px, y, 0, L.textH, T.color.warn) y = y + L.textH + 2 end
    if tall then label(tx("TooTall"), px, y, 0, L.textH, T.color.warn) y = y + L.textH + 2 end
    return y - top
end

-- Build: clothing's pockets ---------------------------------------------------------------

function E:buildPockets(e, u, d, y)
    local L, pad, c = self.L, T.pad, T.cell
    local x0 = L.ex0
    y = self:section(tx("Sec_pockets"), y + pad, true)
    local s = tx("PocketsN")
    label(s, x0, y, 0, L.stepB, T.color.text)
    self:stepper(x0 + textW(T.fontText, s) + pad, y, u.pockets, {canMinus = u.pockets > 0, canPlus = u.pockets < D.MAX_POCKETS,
        changed = u.pockets ~= d.pockets,
        minus = function() self:edit(function(o) o.pockets = o.pockets - 1 end) end,
        plus = function() self:edit(function(o) o.pockets = o.pockets + 1 end) end})
    y = y + L.stepB + pad
    D.items()
    self:check(x0, y, u.all, tx("PocketsAll", u.loc or "", (D.perLoc and D.perLoc[u.loc]) or 1),
        function() self:edit(function(o) o.all = not o.all end) end, nil, u.all ~= d.all)
    y = y + L.box + pad * 2
    -- the pockets as the character's grid shows them: 4 wide, the hands first
    local cols, hands, n = KnoxGrid.POCKETS_COLS, KnoxGrid.HANDS, u.pockets
    local cs = math.floor(c * 0.62)
    local tot = hands + n
    local rows = math.ceil(tot / cols)
    local gw = cols * cs
    local gx, gy = x0 + pad, y + pad
    well(gx - pad, gy - pad, gw + pad * 2, rows * cs + pad * 2)
    cellsAt(gx, gy, cols, rows, cs)
    -- (past the count the row is none: the well's dark)
    for i = tot, rows * cols - 1 do rect(gx + (i % cols) * cs + 1, gy + math.floor(i / cols) * cs + 1, cs - 1, cs - 2, WELL()) end
    for i = hands, tot - 1 do rect(gx + (i % cols) * cs + 1, gy + math.floor(i / cols) * cs + 1, cs - 1, cs - 1, T.color.accent, 0.12) end
    for i = hands, tot - 1 do border(gx + (i % cols) * cs, gy + math.floor(i / cols) * cs, cs + 1, cs + 1, T.color.accent) end
    label(n > 0 and tx("PocketsPreview", hands, n) or tx("PocketsNone"), gx + gw + pad * 3, gy, 0, rows * cs, T.color.dim)
    return gy + rows * cs + pad + pad * 3
end

-- Build: the presets -------------------------------------------------------------------------

--- a pencil, lying from bottom left to top right in an s x s square: its tip, a gap,
--- its body, its dim end
local function pencil(x, y, s, col)
    local n = math.max(7, s - 3)
    local x0 = x + math.floor((s - n - 2) / 2)
    local y0 = y + math.floor((s + n + 2) / 2)
    rect(x0, y0 - 1, 1, 1, col)
    rect(x0 + 1, y0 - 3, 2, 2, col)
    for i = 4, n - 1 do rect(x0 + i, y0 - i - 2, 3, 3, i >= n - 2 and T.color.dim or col) end
end

function E:presetsInOrder()
    local list = {self.knoxP}
    for _, p in ipairs(self.store.list) do list[#list + 1] = p end
    local pos = {}
    for i, p in ipairs(list) do pos[p] = i end
    table.sort(list, function(a, b)
        local ka, kb = sortKey(a), sortKey(b)
        if ka ~= kb then return ka < kb end
        return pos[a] < pos[b]
    end)
    if self.devOn then table.insert(list, self.defaultsP) end
    return list
end

function E:buildPresetList()
    local L, pad = self.L, T.pad
    local x0, w = L.listX + pad * 2, L.listW - pad * 4
    local top = L.viewY + pad * 2
    local half = math.floor((w - 4) / 2)
    button(x0, top, half, L.searchH, tx("PresetNew"), {font = T.fontTile, primary = self.psel == "new", fn = function()
        self.psel, self.flash, self.eScroll, self.eTarget = "new", nil, 0, 0
        self.fieldFor = nil
    end})
    button(x0 + half + 4, top, w - half - 4, L.searchH, tx("PresetImport"), {font = T.fontTile, primary = self.psel == "import", fn = function()
        self.psel, self.imp, self.impFrom, self.eScroll, self.eTarget = "import", nil, nil, 0, 0
        self.impRows = nil
    end})
    local vy = top + L.searchH + pad
    local vh = L.viewY + L.viewH - vy
    self.listView = {L.listX, vy, L.listW, vh}
    REG = 1
    local y, last = vy, nil
    local target = self:target()
    local numW = 0
    for _, q in ipairs(self.store.list) do numW = math.max(numW, textW(T.fontTile, tostring(D.count(q)))) end
    local inUseW = math.floor(T.measure(T.fontTile, T.upper(tx("InUse"))) + 0.5) + 10
    for _, p in ipairs(self:presetsInOrder()) do
        local grp = p.defaults and tx("Layer_mod") or self:groupOf(p)
        if grp ~= last then
            label(T.upper(grp), x0, y + math.floor(pad / 2), 0, L.grpH - math.floor(pad / 2), T.color.dim, T.fontTile)
            y = y + L.grpH
            last = grp
        end
        local rx, rw = L.listX + 1, L.listW - 2
        local on = self.psel == p
        if on then
            rect(rx, y, rw, L.rowH, T.color.header)
            rect(rx, y, 3, L.rowH, T.color.accent)
        else
            lit(rect(rx, y, rw, L.rowH, WHITE, 0.04), rx, y, rw, L.rowH).only = true
        end
        local ph = L.tileH + 4
        local py = y + math.floor((L.rowH - ph) / 2)
        local right = x0 + w
        if self:isOn(p) then plate(tx("InUse"), right, py, ph, T.color.accent) end
        right = right - inUseW - pad
        if not p.builtin then label(tostring(D.count(p)), 0, y, right, L.rowH, T.color.dim, T.fontTile, "right") end
        right = right - numW - pad
        -- the pencil: in the margin left of the names; where that is too narrow (720), after the name
        local mine = p == target
        local inMargin = pad * 2 - 8 >= 10
        local ps = inMargin and math.min(L.textH, pad * 2 - 8) or L.textH
        if mine and inMargin then pencil(L.listX + 5, y + math.floor((L.rowH - ps) / 2), ps, T.color.accent) end
        local nm = T.fit(p.name, T.fontText, right - x0 - ((mine and not inMargin) and (ps + pad) or 0))
        label(nm, x0, y, 0, L.rowH, on and T.color.bright or T.color.text)
        if mine and not inMargin then pencil(x0 + textW(T.fontText, nm) + pad, y + math.floor((L.rowH - ps) / 2), ps, T.color.accent) end
        hit(rx, y, rw, L.rowH, function()
            self.psel, self.flash, self.eScroll, self.eTarget = p, nil, 0, 0
            self.renaming = nil
        end)
        y = y + L.rowH
    end
    self.lMax = math.max(0, y - vy - vh + pad)
    op({k = "fade", which = 1})
    REG = 0
end

--- A page's head: a name over a line, as the item's (without a tile), something on the right.
function E:pageHead(title, sub, y, right)
    local L = self.L
    local x0, x1 = L.ex0, L.ex1
    local TS = L.tileS
    local nh = L.capsH + 2 + L.textH
    local gy0 = y + math.floor((TS - nh) / 2)
    local nameR = right and right(y, TS) or x1
    label(T.fit(T.upper(title), T.fontCaps, nameR - x0), x0, gy0, 0, L.capsH, T.color.bright, T.fontCaps)
    label(T.fit(sub, T.fontText, nameR - x0), x0, gy0 + L.capsH + 2, 0, L.textH, T.color.dim)
    return y + TS + T.pad * 3
end

function E:para(s, y)
    local L = self.L
    for _, ln in ipairs(T.wrap(s, T.fontText, L.ex1 - L.ex0)) do
        label(ln, L.ex0, y, 0, L.textH, T.color.dim)
        y = y + L.textH + 2
    end
    return y
end

--- Buttons in a row, each as wide as its word: list of {text, o}; one that doesn't
--- fit goes under (a long "Sure?" of a language). Returns the bottom of the last row.
function E:buttonRow(list, x, y)
    local L, pad = self.L, T.pad
    local x0 = x
    for _, it in ipairs(list) do
        local bw = math.min(textW(T.fontTile, T.upper(it[1])) + pad * 4, L.ex1 - x0)
        if x > x0 and x + bw > L.ex1 then x, y = x0, y + L.choiceH + pad end
        button(x, y, bw, L.choiceH, T.fit(it[1], T.fontTile, bw - pad * 2), it[2])
        x = x + bw + pad
    end
    return y + L.choiceH
end

--- Choices in rows of `per`, as the bag's modes: list of {text, on, fn, disabled}.
function E:choices(list, per, y)
    local L, pad = self.L, T.pad
    local x0, x1 = L.ex0, L.ex1
    local cw = math.floor((x1 - x0 - pad * (per - 1)) / per)
    for n, it in ipairs(list) do
        local col = (n - 1) % per
        local bx = x0 + col * (cw + pad)
        button(bx, y + math.floor((n - 1) / per) * (L.choiceH + pad), col == per - 1 and (x1 - bx) or cw, L.choiceH, it[1],
            {font = T.fontTile, primary = it[2], fn = it[3], disabled = it[4]})
    end
    return y + math.ceil(#list / per) * (L.choiceH + pad) - pad
end

--- The text field over the page (the game's text box, Knox's font): where it goes this build.
function E:field(y, text)
    local L = self.L
    rect(L.ex0, y, L.ex1 - L.ex0, L.choiceH, T.color.cell)
    local t = border(L.ex0, y, L.ex1 - L.ex0, L.choiceH, T.color.tileEdge)
    t.hc = T.color.accent
    lit(t, L.ex0, y, L.ex1 - L.ex0, L.choiceH)
    self.fieldAt = {L.ex0 + T.pad, y, L.ex1 - L.ex0 - T.pad * 2, L.choiceH}
    if self.fieldFor ~= self.fieldWant then
        self.fieldFor = self.fieldWant
        self.nameBox:setText(text or "")
    end
end

function E:buildPresetPage()
    local L, pad = self.L, T.pad
    REG = 2
    local y = L.viewY + pad * 2
    self.fieldAt = nil
    if self.psel == "import" then y = self:buildImport(y)
    elseif self.psel == "new" then y = self:buildNew(y)
    else y = self:buildPreset(self.psel, y) end
    self.eMax = math.max(0, y - L.viewY - L.viewH)
    op({k = "fade", which = 2})
    REG = 0
end

function E:buildPreset(p, y)
    local L, pad = self.L, T.pad
    local x0, x1 = L.ex0, L.ex1
    local k, v = P.scopeOf(p.scope)
    local n = D.count(p)
    local sub
    if p.builtin then sub = tx("BuiltinSub")
    elseif p.defaults then sub = tx("DefaultsSub", n)
    else sub = tx("PresetSub", self:scopeText(p.scope), n) end
    local target = self:target()
    y = self:pageHead(p.name, sub, y, function(top, TS)
        local r = x1
        local by = top + math.floor((TS - L.choiceH) / 2)
        local ph = L.tileH + 4
        local function btn(t, fn)
            local bw = textW(T.fontTile, T.upper(t)) + pad * 2
            button(r - bw, by, bw, L.choiceH, t, {font = T.fontTile, fn = fn})
            r = r - bw - pad
        end
        if not p.defaults then
            if not self:isOn(p) then
                local g0 = nil
                for _, q in ipairs(self.store.list) do if q.on and q.scope == p.scope then g0 = q end end
                if p.builtin then g0 = self:generalOn() end
                btn(g0 and tx("MakeActive", quote(g0.name)) or tx("TurnOn"), function() self:setOn(p, true) end)
            else
                if k ~= "all" then btn(tx("TurnOff"), function() self:setOn(p, false) end) end
                r = r - plate(tx("InUse"), r, top + math.floor((TS - ph) / 2), ph, T.color.accent) - pad
            end
        end
        if p == target then r = r - plateLine(tx("EditsMark"), r, top + math.floor((TS - ph) / 2), ph, T.color.accent) - pad end
        return r - pad
    end)
    -- how it goes with the others
    local layer
    if p.defaults then layer = tx("LayerDefaults")
    elseif k == "all" then layer = tx("LayerAll")
    elseif k == "tab" then layer = tx("LayerCat", tx("Cat_" .. v))
    else layer = tx("LayerMod", D.modName(v)) end
    y = self:para(layer, y - pad * 2) + pad * 3
    -- the preset itself
    if not p.defaults then
        y = self:section(tx("Sec_preset"), y, true)
        local list = {}
        if not p.builtin and p ~= target then
            list[#list + 1] = {tx("EditIt"), {font = T.fontTile, fn = function() self:setTarget(p) self:goScope(p) end}}
        end
        if not p.builtin then
            list[#list + 1] = {self.renaming == p and tx("RenameDone") or tx("Rename"), {font = T.fontTile, fn = function()
                -- (the click itself ended a renaming of this one: "Done")
                if self.wasRenaming ~= p then self.renaming, self.fieldWant = p, "rename:" .. tostring(p.file) end
            end}}
        end
        list[#list + 1] = {tx("CopyP"), {font = T.fontTile, fn = function()
            local q = self:addPreset(p.name .. " " .. tx("CopySuffix"), p.scope, copyItems(p.items))
            self.psel, self.flash = q, nil
        end}}
        if not p.builtin then
            local sure = self.delAsk == p
            list[#list + 1] = {sure and tx("DelSure") or tx("Delete"), {font = T.fontTile, col = sure and T.color.warn or RED,
                disabled = p == target or (p.on and k == "all"), fn = function()
                    if self.askedDel ~= p then self.delAsk = p return end
                    local _, i = P.find(self.store, p.file)
                    if i then table.remove(self.store.list, i) end
                    if self.saved[p.file] then self.gone[p.file] = true end
                    self.psel = target
                end}}
        end
        y = self:buttonRow(list, x0, y) + pad
        if self.renaming == p then
            self:field(y, p.name)
            y = y + L.choiceH + pad
        end
        y = y + pad * 2
    end
    -- what it changes; a click opens the item (in the edited preset)
    local ch = {}
    for ft in pairs(p.items) do ch[#ch + 1] = ft end
    table.sort(ch, function(a, b)
        local ea, eb = D.byType(a), D.byType(b)
        return (ea and ea.low or a) < (eb and eb.low or b)
    end)
    y = self:section(tx("Sec_changes") .. "  ·  " .. #ch, y + pad, true)
    if #ch == 0 then
        label(tx("NoChanges"), x0, y, 0, L.textH, T.color.dim)
        y = y + L.textH + pad
    end
    for _, ft in ipairs(ch) do
        local e = D.byType(ft)
        local can = p == target and e ~= nil
        local rx, rw = x0 - pad, x1 - x0 + pad * 2
        if can then lit(rect(rx, y, rw, L.rowH, WHITE, 0.04), rx, y, rw, L.rowH).only = true end
        local ib = L.rowH - 6
        local o = p.items[ft]
        rect(x0, y + 3, ib, ib, T.category[o.cat or (e and D.recordIn(p, ft) or {}).tile or "misc"] or T.category.misc)
        border(x0, y + 3, ib, ib, T.color.tileEdge)
        if e then itemTex(e, x0, y + 3, ib, ib) end
        local mw = math.floor((x1 - x0) * 0.45)
        label(T.fit(P.restOf(o), UIFont.Code, mw), x1 - mw, y, mw, L.rowH, T.color.dim, UIFont.Code)
        local t = label(T.fit(e and e.name or ft, T.fontText, x1 - mw - pad - (x0 + ib + pad)), x0 + ib + pad, y, 0, L.rowH, T.color.text)
        if can then
            t.hc = T.color.bright
            lit(t, rx, y, rw, L.rowH)
            hit(rx, y, rw, L.rowH, function()
                self.side, self.query = e.side, nil
                if self.searchBox then self.searchBox:setText("") end
                self.lScroll, self.lTarget = 0, 0
                self:pick(ft)
            end)
        end
        y = y + L.rowH
    end
    y = y + pad * 3
    -- export
    y = self:section(tx("Sec_export"), y + pad, true)
    y = self:para(tx("ExportHelp"), y) + pad
    y = self:buttonRow({
        {tx("ToClipboard"), {font = T.fontTile, disabled = #ch == 0, fn = function()
            local lines = P.text(p)
            if Clipboard then Clipboard.setClipboard(table.concat(lines, "\n")) end
            self.flash = tx("Copied", #lines)
        end}},
        {tx("ToFile"), {font = T.fontTile, disabled = #ch == 0 or p.builtin, fn = function()
            local file = p.file or P.fileFor(p.name, self.store)
            P.writeLines(P.DIR .. file, P.text(p))
            self.flash = tx("SavedFile", file)
        end}}}, x0, y) + pad
    if self.flash then
        label(T.fit(self.flash, T.fontText, x1 - x0), x0, y, 0, L.textH, T.color.accent)
        y = y + L.textH + pad
    end
    y = y + pad * 2
    -- reset: asked twice
    if not p.builtin then
        y = self:section(tx("Sec_reset"), y + pad, true)
        y = self:para(tx("ResetHelp"), y) + pad
        local sure = self.resetAsk
        y = self:buttonRow({{sure and tx("ResetSure") or tx("ResetAll"), {font = T.fontTile, col = sure and T.color.warn or RED, disabled = #ch == 0,
            fn = function() if self.asked == "reset" then self:resetPreset(p) else self.resetAsk = true end end}}}, x0, y) + pad * 3
    end
    return y
end

function E:modsList()
    local seen, out = {}, {}
    for _, e in ipairs(D.items()) do
        if e.mod and not seen[e.mod] then
            seen[e.mod] = true
            out[#out + 1] = e.mod
        end
    end
    table.sort(out, function(a, b) return string.lower(D.modName(a)) < string.lower(D.modName(b)) end)
    return out
end

function E:newScope()
    if self.nScope == "cat" then return "tab:" .. self.nCat end
    if self.nScope == "mod" and self.nMod then return "mod:" .. self.nMod end
    return "all"
end

function E:buildNew(y)
    local L, pad = self.L, T.pad
    local x0, x1 = L.ex0, L.ex1
    local mods = self:modsList()
    if self.nScope == "mod" and not self.nMod then self.nMod = mods[1] end
    local sc = self:newScope()
    local gp = self:generalOn()
    local mine = {}
    if gp then
        for ft, o in pairs(gp.items) do
            local e = D.byType(ft)
            if e and holds({scope = sc}, e) then mine[ft] = o end
        end
    end
    local mineN = 0
    for _ in pairs(mine) do mineN = mineN + 1 end
    if mineN == 0 and self.nStart == "mine" then self.nStart = "knox" end
    y = self:pageHead(tx("NewTitle"), tx("NewSub"), y, function(top, TS)
        local bw = textW(T.fontTile, T.upper(tx("Create"))) + pad * 4
        local bx, by = x1 - bw, top + math.floor((TS - L.choiceH) / 2)
        button(bx, by, bw, L.choiceH, tx("Create"), {font = T.fontTile, primary = true, disabled = sc == "mod:", fn = function()
            local name = self:fieldText(tx("NewName"))
            local p = self:addPreset(name, sc, self.nStart == "mine" and copyItems(mine) or {})
            self.psel = p
            self:setTarget(p)
        end})
        return bx - pad * 2
    end)
    y = self:section(tx("Sec_name"), y, true)
    self.fieldWant = "new"
    self:field(y, tx("NewName"))
    y = y + L.choiceH + pad * 3
    -- what it is for: every item, a tab, a mod
    y = self:section(tx("Sec_for"), y + pad, true)
    y = self:choices({{tx("ForAllB"), self.nScope == "all", function() self.nScope = "all" end},
                      {tx("ForCatB"), self.nScope == "cat", function() self.nScope = "cat" end},
                      {tx("ForModB"), self.nScope == "mod", function() self.nScope = "mod" end, #mods == 0}}, 4, y) + pad
    if self.nScope == "cat" then
        local list = {}
        for _, s in ipairs(E.SIDE) do list[#list + 1] = {tx("Cat_" .. s), self.nCat == s, function() self.nCat = s end} end
        y = self:choices(list, 4, y + pad) + pad
    elseif self.nScope == "mod" then
        local list = {}
        for _, m in ipairs(mods) do list[#list + 1] = {T.fit(D.modName(m), T.fontTile, T.cell * 3), self.nMod == m, function() self.nMod = m end} end
        y = self:choices(list, 4, y + pad) + pad
    end
    if self.nScope ~= "all" then
        local k, v = P.scopeOf(sc)
        y = self:para(k == "tab" and tx("LayerCat", tx("Cat_" .. v)) or tx("LayerMod", D.modName(v)), y)
    end
    y = y + pad * 3
    -- start from Knox's own, or from what the general preset in use already changes there
    y = self:section(tx("Sec_start"), y + pad, true)
    local cw = math.floor((x1 - x0 - pad) / 2)
    button(x0, y, cw, L.choiceH, tx("StartKnox"), {font = T.fontTile, primary = self.nStart == "knox", fn = function() self.nStart = "knox" end})
    button(x0 + cw + pad, y, x1 - x0 - cw - pad, L.choiceH, tx("StartMine", gp and quote(gp.name) or "", mineN),
        {font = T.fontTile, primary = self.nStart == "mine", disabled = mineN == 0, fn = function() self.nStart = "mine" end})
    y = y + L.choiceH + pad * 3
    return y
end

function E:loadImport(lines, from)
    self.imp = D.readImport(lines)
    self.impFrom = from
    self.fieldWant = "import:" .. tostring(from)
end

function E:buildImport(y)
    local L, pad = self.L, T.pad
    local x0, x1 = L.ex0, L.ex1
    local imp = self.imp
    y = self:pageHead(tx("ImportTitle"), tx("ImportSub"), y, imp and imp.ok > 0 and function(top, TS)
        local bw = textW(T.fontTile, T.upper(tx("AddPreset"))) + pad * 4
        local bx, by = x1 - bw, top + math.floor((TS - L.choiceH) / 2)
        button(bx, by, bw, L.choiceH, tx("AddPreset"), {font = T.fontTile, primary = true, fn = function()
            local p = self:addPreset(self:fieldText(imp.preset.name or tx("ImportedName")), imp.preset.scope, imp.preset.items)
            self.psel, self.imp, self.impFrom = p, nil, nil
            self.eScroll, self.eTarget = 0, 0
        end})
        return bx - pad * 2
    end or nil)
    -- where from: the clipboard, then the folder's files (the Java part lists them)
    y = self:section(tx("Sec_from"), y, true)
    -- (the folder read once a visit of the page, not at every build)
    if not self.impRows then
        local rows = {{name = tx("Clip"), key = "clip", note = tx("ClipSub")}}
        local files = P.listFiles()
        if files then
            for _, f in ipairs(files) do
                if not (self.store and P.find(self.store, f[1])) then
                    local lines = P.readLines(P.DIR .. f[1])
                    local pp = lines and P.parse(lines)
                    rows[#rows + 1] = {name = f[1], key = f[1], note = (pp and self:scopeText(pp.scope) or "") .. "  ·  " .. f[2], lines = lines}
                end
            end
        end
        self.impRows, self.impNoFolder = rows, files == nil
    end
    local rows = self.impRows
    for _, f in ipairs(rows) do
        local rx, rw = x0 - pad, x1 - x0 + pad * 2
        local on = self.impFrom == f.key
        if on then
            rect(rx, y, rw, L.rowH, T.color.header)
            rect(rx, y, 3, L.rowH, T.color.accent)
        else
            lit(rect(rx, y, rw, L.rowH, WHITE, 0.04), rx, y, rw, L.rowH).only = true
        end
        label(f.name, x0, y, 0, L.rowH, on and T.color.bright or T.color.text)
        label(f.note, 0, y, x1, L.rowH, T.color.dim, T.fontText, "right")
        hit(rx, y, rw, L.rowH, function()
            if f.key == "clip" then
                local s = Clipboard and Clipboard.getClipboard() or ""
                self:loadImport(D.splitLines(s), "clip")
            else
                self:loadImport(f.lines or {}, f.key)
            end
        end)
        y = y + L.rowH
    end
    if self.impNoFolder then
        label(tx("NoFolder"), x0, y + 2, 0, L.textH, T.color.dim)
        y = y + L.textH + 4
    end
    y = y + pad * 3
    if not imp then return y end
    -- the name; what it is for; how much was read
    y = self:section(tx("Sec_name"), y + pad, true)
    self:field(y, imp.preset.name or (self.impFrom ~= "clip" and string.gsub(self.impFrom, "%.txt$", "")) or tx("ImportedName"))
    y = y + L.choiceH + pad
    label(tx("FileFor", self:scopeText(imp.preset.scope)), x0, y, 0, L.textH, T.color.text)
    y = y + L.textH + 2
    local a = tx("ReadSum", imp.lines, imp.ok) .. (imp.bad > 0 and " · " or "")
    label(a, x0, y, 0, L.textH, T.color.dim)
    if imp.bad > 0 then label(tx("ReadErr", imp.bad), x0 + T.measure(T.fontText, a), y, 0, L.textH, RED) end
    y = y + L.textH + pad * 3
    -- what was read: each line, what it is about or what is wrong with it
    y = self:section(tx("Sec_read"), y + pad, true)
    local lh = L.textH + 6
    local shown = math.min(#imp.rows, 200)
    well(x0, y, x1 - x0, shown * lh + pad * 2)
    local _, modId = P.scopeOf(imp.preset.scope)
    for i = 1, shown do
        local l = imp.rows[i]
        local yy = y + pad + (i - 1) * lh
        local note = l.err and tx(l.err, D.modName(modId) or modId) or l.note or ""
        local nw = note ~= "" and textW(T.fontText, note) or 0
        label(T.fit(l.text, UIFont.Code, x1 - x0 - pad * 4 - nw), x0 + pad, yy, 0, lh, l.err and RED or (l.ok and T.color.bright or T.color.dim), UIFont.Code)
        if note ~= "" then label(note, 0, yy, x1 - pad, lh, l.err and RED or T.color.dim, T.fontText, "right") end
    end
    y = y + shown * lh + pad * 5
    return y
end

-- Build: the foot ------------------------------------------------------------------------------

function E:buildFoot()
    local L, pad, c = self.L, T.pad, T.cell
    local W, y, fh = L.w, L.footY, L.footH
    rect(0, L.h - L.footZone, W, 1, T.color.border)
    local un = self:unsavedN()
    self.unsaved = un
    local bw = math.floor(c * 2.6)
    local function wOf(s) return math.max(textW(T.fontCaps, T.upper(s)) + pad * 4, bw) end
    local sw, cw, uw = wOf(tx("Save")), wOf(tx("Close")), wOf(tx("Undo"))
    local RS = {W - pad * 2 - sw, y, sw, fh}
    local RC = {RS[1] - pad - cw, y, cw, fh}
    local RU = {RC[1] - pad - uw, y, uw, fh}
    button(RU[1], RU[2], RU[3], RU[4], tx("Undo"), {disabled = #self.undo == 0, fn = function() self:undoLast() end})
    button(RC[1], RC[2], RC[3], RC[4], tx("Close"), {fn = function()
        if un > 0 and self.asked ~= "close" then self.closeAsk = true return end
        self:close()
    end})
    button(RS[1], RS[2], RS[3], RS[4], tx("Save"), {primary = un > 0, disabled = un == 0 or self.waiting, fn = function() self:save() end})
    -- on the left: where it goes
    local x = pad * 2
    local room = RU[1] - pad * 2   -- (nothing of the left runs under the buttons)
    if self.devOn then
        local s = T.upper(tx("SaveTo"))
        label(T.fit(s, T.fontTile, room - x), x, y, 0, fh, T.color.dim, T.fontTile)
        x = x + textW(T.fontTile, s) + pad
        for _, k in ipairs({"player", "mod"}) do
            local w = math.max(0, math.min(textW(T.fontTile, T.upper(tx("Layer_" .. k))) + pad * 3, room - x))
            if w > pad * 3 then
                button(x, y, w, fh, T.fit(tx("Layer_" .. k), T.fontTile, w - pad * 2), {font = T.fontTile, primary = self.layer == k, fn = function()
                    self.layer = k
                    if self.side == "presets" then self.psel = self:target() end
                end})
            end
            x = x + w + 4
        end
        x = x + pad * 2
    elseif self.server then
        local s = T.fit(tx("ServerNote"), T.fontText, room - x)
        label(s, x, y, 0, fh, T.color.warn)
        x = x + textW(T.fontText, s) + pad * 3
    else
        local s = T.fit(T.upper(tx("PresetFoot")), T.fontTile, room - x)
        label(s, x, y, 0, fh, T.color.dim, T.fontTile)
        x = x + textW(T.fontTile, s) + pad
        local t = self:target()
        local nm = T.fit(quote(t.name), T.fontText, math.max(0, RU[1] - pad * 4 - x - c * 3))
        local nw = textW(T.fontText, nm)
        local tl = label(nm, x, y, nw, fh, T.color.bright)
        tl.hc = T.color.accent
        lit(tl, x, y, nw, fh)
        hit(x, y, nw, fh, function()
            self:goSide("presets")
            self.psel = self:target()
        end)
        x = x + nw + pad
        local o = "· " .. tx("OffShort")
        local ow = self:isOn(t) and 0 or (textW(T.fontText, o) + pad)
        local sc = "· " .. self:scopeText(t.scope)
        local sw2 = textW(T.fontText, sc) + pad
        if t.scope ~= "all" and x + sw2 + ow < RU[1] - pad * 4 - c * 3 then
            label(sc, x, y, 0, fh, T.color.dim)
            x = x + sw2
        end
        if not self:isOn(t) and x + ow < room then
            label(o, x, y, 0, fh, T.color.warn)
            x = x + ow
        end
        x = x + pad * 2
        if self.mpLocal then
            -- (a game with others: the server's sizes are in effect, these are for playing alone)
            local s2 = tx("MPNote")
            if x + textW(T.fontText, s2) < RU[1] - c * 2 then
                label(s2, x, y, 0, fh, T.color.dim)
                x = x + textW(T.fontText, s2) + pad * 2
            end
        end
    end
    if un > 0 and x < RU[1] - c * 2 then
        label(T.fit(self.closeAsk and tx("CloseUnsaved") or tx("Unsaved", un), T.fontText, RU[1] - pad * 2 - x), x, y, 0, fh,
            self.closeAsk and T.color.warn or T.color.accent)
    end
end

-- Build: all of it ---------------------------------------------------------------------------

function E:build()
    local L = self.L
    B = self
    REG = 0
    self.ops, self.hits = {}, {}
    local W, H = L.w, L.h
    local pad = T.pad
    op({k = "shadow"})
    rect(0, 0, W, H, T.color.window)
    rect(0, 0, W, L.headerH, T.color.header)
    rect(0, L.headerH, W, 1, T.color.border)
    label(T.fit(T.upper(tx("Title")), T.fontCaps, W - L.headerH - pad * 2), pad * 2, 0, 0, L.headerH, T.color.bright, T.fontCaps)
    local cs = L.headerH - 8
    self.closeR = {W - cs - 4, 4, cs, cs}
    local cb = op({k = "close", x = self.closeR[1], y = 4, w = cs, h = cs})
    lit(cb, self.closeR[1], 4, cs, cs)
    hit(self.closeR[1], 4, cs, cs, function()
        if self.unsaved and self.unsaved > 0 and self.asked ~= "close" then self.closeAsk = true return end
        self:close()
    end)
    if not self.store then
        -- (the server's presets on their way)
        label(tx("Loading"), L.listX + pad * 2, L.viewY + pad * 2, 0, L.textH, T.color.dim)
        self.listView, self.searchR = nil, nil
        self:buildFoot()
        op({k = "frameAll"})
        B = nil
        return
    end
    self:buildSide()
    rect(L.sideW, L.viewY, 1, H - L.viewY - L.footZone, T.color.border)
    if self.side == "presets" then
        self.searchR = nil
        self:buildPresetList()
        rect(L.edX - 1, L.viewY, 1, H - L.viewY - L.footZone, T.color.border)
        self:buildPresetPage()
    else
        self:buildList()
        rect(L.edX - 1, L.viewY, 1, H - L.viewY - L.footZone, T.color.border)
        self.fieldAt = nil
        self:buildItem()
    end
    self:buildFoot()
    self:buildPopup()
    op({k = "frameAll"})
    B = nil
end

-- Drawing ------------------------------------------------------------------------------------

local R1 = {0, 0, 0, 0}
local labelOpts, buttonOpts = {}, {}

--- How far a region is moved by its scroll.
function E:dyOf(reg)
    if reg == 1 then return -math.floor(self.lScroll + 0.5) end
    if reg == 2 or reg == 3 then return -math.floor(self.eScroll + 0.5) end
    return 0
end

function E:clipOf(reg)
    if reg == 1 then return self.listView end
    if reg == 2 then return self.L.editView end
    return nil
end

--- The mouse in a region's own coordinates.
function E:mouseIn(reg)
    return self:getMouseX(), self:getMouseY() - self:dyOf(reg)
end

--- Is the mouse on t (its lit rect), where its region shows it?
function E:isLit(t, mx, my, dy)
    if not t.hx then return false end
    if self.popup and t.reg ~= 3 then return false end
    local clip = self:clipOf(t.reg)
    if clip and not inRect(mx, my, clip) then return false end
    return mx >= t.hx and my >= t.hy + dy and mx < t.hx + t.hw and my < t.hy + dy + t.hh
end

function E:drawFade(which, dt)
    local L = self.L
    local view = which == 1 and self.listView or L.editView
    if not view then return end
    local scroll, max = which == 1 and self.lScroll or self.eScroll, which == 1 and self.lMax or self.eMax
    local f = which == 1 and self.fadeL or self.fadeE
    local step = T.anim(math.min(1, dt / FADE_MS))
    f[1] = f[1] + (((scroll > 1) and 1 or 0) - f[1]) * step
    f[2] = f[2] + (((max - scroll > 1) and 1 or 0) - f[2]) * step
    if f[1] < 0.01 and f[2] < 0.01 then return end
    local band = math.floor(T.cell)
    local c = T.color.window
    for i = 0, band - 1, 2 do
        local k = 1 - i / band
        local a = k * k * 0.95
        if f[2] > 0.01 then self:drawRect(view[1], view[2] + view[4] - i - 2, view[3], 2, a * f[2], c.r, c.g, c.b) end
        if f[1] > 0.01 then self:drawRect(view[1], view[2] + i, view[3], 2, a * f[1], c.r, c.g, c.b) end
    end
end

function E:drawOp(t, dy, mx, my, dt)
    local k = t.k
    local on = t.hx and self:isLit(t, mx, my, dy)
    if t.box and t.box:isFocused() then on = true end
    if t.only and not on then return end
    local y = t.y and (t.y + dy)
    if k == "rect" then
        T.rect(self, t.x, y, t.w, t.h, t.c, t.a)
    elseif k == "label" then
        R1[1], R1[2], R1[3], R1[4] = t.x, y, t.w, t.h
        labelOpts.font, labelOpts.align, labelOpts.a = t.font, t.align, t.a
        T.label(self, t.s, R1, on and t.hc or t.c, labelOpts)
    elseif k == "border" then
        T.border(self, t.x, y, t.w, t.h, on and t.hc or t.c)
    elseif k == "frame" then
        T.tileFrame(self, t.x, y, t.w, t.h, on and t.hc or t.c)
    elseif k == "button" then
        R1[1], R1[2], R1[3], R1[4] = t.x, y, t.w, t.h
        buttonOpts.hover, buttonOpts.primary, buttonOpts.disabled, buttonOpts.font, buttonOpts.color = on, t.primary, t.disabled, t.font, t.col
        T.button(self, R1, t.s, buttonOpts)
    elseif k == "tex" then
        self:drawTextureScaledAspect(t.tex, t.x, y, t.w, t.h, 1, 1, 1, 1)
    elseif k == "lens" then
        -- Knox's magnifier picture (as KnoxScreen's search), tinted
        if LENS == nil then LENS = getTexture("media/ui/knox_lens.png") or false end
        local c = on and t.hc or t.c
        if LENS then self:drawTextureScaledAspect(LENS, t.x, y, t.w, t.h, 1, c.r, c.g, c.b) end
    elseif k == "pm" then
        -- − and + as bars, in the middle of their box (no font)
        local n = math.max(6, math.floor(t.w * 0.36 + 0.5))
        n = n - n % 2
        local c = on and t.hc or t.c
        local cx, cy = t.x + math.floor((t.w - n) / 2), y + math.floor((t.h - 2) / 2)
        T.rect(self, cx, cy, n, 2, c, t.a)
        if t.plus then T.rect(self, t.x + math.floor((t.w - 2) / 2), y + math.floor((t.h - n) / 2), 2, n, c, t.a) end
    elseif k == "chev" then
        local c = on and t.hc or t.c
        for i = 0, t.n - 1 do self:drawRect(t.x - (t.n - 1 - i), y + i, (t.n - 1 - i) * 2 + 1, 1, 1, c.r, c.g, c.b) end
    elseif k == "close" then
        T.closeButton(self, t.x, y, t.w, on)
    elseif k == "shadow" then
        self:drawRect(4, 6, self.L.w, self.L.h, 0.45, 0, 0, 0)
    elseif k == "frameAll" then
        T.tileFrame(self, 0, 0, self.L.w, self.L.h, T.color.accent)
    end
end

function E:prerender()
    local L = self.L
    local now = getTimestampMs()
    local dt = math.min(100, now - (self.frameMs or now))
    self.frameMs = now
    local mx, my = self:getMouseX(), self:getMouseY()
    self:follow()
    -- the scroll glides to where the wheel sent it
    local step = T.anim(math.min(1, dt / SCROLL_MS))
    self.lTarget = math.max(0, math.min(self.lMax or 0, self.lTarget))
    self.eTarget = math.max(0, math.min(self.eMax or 0, self.eTarget))
    self.lScroll = self.lScroll + (self.lTarget - self.lScroll) * step
    if math.abs(self.lTarget - self.lScroll) < 0.5 then self.lScroll = self.lTarget end
    self.eScroll = self.eScroll + (self.eTarget - self.eScroll) * step
    if math.abs(self.eTarget - self.eScroll) < 0.5 then self.eScroll = self.eTarget end
    -- (the list's rows are made for the part in sight: further, made again)
    local win = self.listWin
    if win and self.side ~= "presets" and (self.lTarget < win[1] or self.lTarget > win[2]) then self:build() end
    local ops = self.ops
    local reg = -1
    for i = 1, #ops do
        local t = ops[i]
        if t.reg ~= reg then
            if reg == 1 or reg == 2 then self:clearStencilRect() end
            reg = t.reg
            local clip = self:clipOf(reg)
            if clip then self:setStencilRect(clip[1], clip[2], clip[3], clip[4]) end
        end
        if t.k == "fade" then
            self:drawFade(t.which, dt)
        else
            local dy = self:dyOf(reg)
            -- (only what is in sight)
            local clip = self:clipOf(reg)
            if not clip or not t.y or (t.y + dy + (t.h or 0) >= clip[2] and t.y + dy <= clip[2] + clip[4]) then
                self:drawOp(t, dy, mx, my, dt)
            end
        end
    end
    if reg == 1 or reg == 2 then self:clearStencilRect() end
    self:placeFields()
end

-- The text fields ------------------------------------------------------------------------------

local function makeBox(self, placeholder)
    local box = ISTextEntryBox:new("", 0, 0, 10, 10)
    local font = T.javaFonts and knoxFieldFont and type(T.fontText) == "table" and knoxFieldFont("body", T.fontText.size) or nil
    box.font = font or T.gameFont(T.fontText)
    box:initialise()
    box:instantiate()
    pcall(function()
        if font then box.javaObject:setFont(font) end
        box.javaObject:setCentreVertically(true)
        box:setClearButton(false)
    end)
    box.prerender = function() end   -- (its plate is drawn by the editor)
    local c, d = T.color.bright, T.color.dim
    box:setTextRGBA(c.r, c.g, c.b, 1)
    if placeholder then
        box:setPlaceholderText(placeholder)
        box:setPlaceholderTextRGBA(d.r, d.g, d.b, 1)
    end
    self:addChild(box)
    return box
end

function E:fieldText(fallback)
    local s = self.nameBox and self.nameBox:getText() or ""
    s = string.gsub(string.gsub(s, "^%s+", ""), "%s+$", "")
    if s == "" then return fallback end
    return s
end

function E:commitRename()
    local p = self.renaming
    self.renaming = nil
    if p then p.name = self:fieldText(p.name) end
    self:build()
end

--- The fields where this build put them (the name field moves with the page's scroll).
function E:placeFields()
    local L = self.L
    local sb = self.searchBox
    if sb then
        local r = self.searchR
        if r then
            local ix = r[1] + T.pad * 2 + math.floor(L.searchH * 0.5)
            sb:setX(ix)
            sb:setY(r[2])
            sb:setWidth(r[1] + r[3] - ix - T.pad)
            sb:setHeight(r[4])
            if not sb:getIsVisible() then sb:setVisible(true) end
            -- what is searched for: trimmed, in lower case (the list made anew when it changes)
            local text = sb:getText() or ""
            if text ~= self.searchWas then
                self.searchWas = text
                local q = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
                self.query = q ~= "" and T.lower(q) or nil
                self.lScroll, self.lTarget = 0, 0
                if self.query then
                    local l = self:listItems()
                    if #l > 0 then
                        local found = false
                        for _, e in ipairs(l) do if e.ft == self.sel then found = true end end
                        if not found then self:pick(l[1].ft) end
                    end
                end
                self:build()
            end
        elseif sb:getIsVisible() then
            sb:setVisible(false)
        end
    end
    local nb = self.nameBox
    if nb then
        local r = self.fieldAt
        local y = r and (r[2] - math.floor(self.eScroll + 0.5))
        if r and y >= L.viewY and y + r[4] <= L.viewY + L.viewH then
            nb:setX(r[1])
            nb:setY(y)
            nb:setWidth(r[3])
            nb:setHeight(r[4])
            if not nb:getIsVisible() then nb:setVisible(true) end
        elseif nb:getIsVisible() then
            if nb:isFocused() and not r then nb:unfocus() end
            nb:setVisible(false)
        end
    end
end

-- Mouse and keys ---------------------------------------------------------------------------------

--- A mask being painted: the cells the mouse goes over take the value it started with.
function E:follow()
    local pt = self.paint
    if not pt then return end
    if not (isMouseButtonDown(0) or isMouseButtonDown(1)) then
        self.paint = nil
        return
    end
    local mx, my = self:mouseIn(2)
    local x, y = math.floor((mx - pt.ox) / pt.cs) + 1, math.floor((my - pt.oy) / pt.cs) + 1
    if x < 1 or y < 1 or x > pt.W or y > pt.H then return end
    local r = D.recordIn(self:target(), self.sel)
    if r and r.bag and r.bag.mask and r.bag.mask[y][x] ~= pt.v then
        local nr = D.copy(r)
        nr.bag.mask[y][x] = pt.v
        D.setRecord(self:target(), self.sel, nr)
        self:build()
    end
end

function E:click(x, y, rmb)
    -- two clicks to be sure: what the last click armed
    self.asked = (self.resetAsk and "reset") or (self.closeAsk and "close") or nil
    self.askedDel = self.delAsk
    self.resetAsk, self.closeAsk, self.delAsk = false, false, nil
    self.wasRenaming = self.renaming
    if self.renaming and not (self.fieldAt and inRect(x, y + math.floor(self.eScroll + 0.5), self.fieldAt)) then
        -- (a click elsewhere ends the renaming, keeping the name typed)
        local p = self.renaming
        self.renaming = nil
        p.name = self:fieldText(p.name)
    end
    -- an open list takes the click: a row picks, anywhere else only closes it
    if self.popup then
        for i = #self.hits, 1, -1 do
            local h = self.hits[i]
            if h.reg == 3 and not rmb then
                local dy = self:dyOf(3)
                if x >= h.x and y >= h.y + dy and x < h.x + h.w and y < h.y + dy + h.h then
                    h.fn()
                    self:build()
                    return true
                end
            end
        end
        self.popup = nil
        self:build()
        return true
    end
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if (h.rmb == true) == (rmb == true) then
            local dy = self:dyOf(h.reg)
            local clip = self:clipOf(h.reg)
            if (not clip or inRect(x, y, clip)) and x >= h.x and y >= h.y + dy and x < h.x + h.w and y < h.y + dy + h.h then
                h.fn()
                if self.ops then self:build() end
                getSoundManager():playUISound("UIActivateButton")
                return true
            end
        end
    end
    self:build()
    return false
end

function E:onMouseDown(x, y)
    if self.nameBox and self.nameBox:isFocused() and not (self.fieldAt and inRect(x, y + math.floor(self.eScroll + 0.5), self.fieldAt)) then
        self.nameBox:unfocus()
    end
    if self.searchBox and self.searchBox:isFocused() and not (self.searchR and inRect(x, y, self.searchR)) then
        self.searchBox:unfocus()
    end
    if self.searchR and inRect(x, y, self.searchR) and self.searchBox then
        self.searchBox:focus()
        return true
    end
    if self:click(x, y, false) then return true end
    KnoxWindowDrag.begin(self, x, y, self.L.headerH)
    return true
end

function E:onRightMouseDown(x, y)
    self:click(x, y, true)
    return true
end

function E:onRightMouseUp(x, y)
    self.paint = nil
    return true
end

function E:onMouseWheel(del)
    local L = self.L
    local mx, my = self:getMouseX(), self:getMouseY()
    local step = del * (L.textH + 2) * 3
    if self.popup then return true end
    if self.listView and inRect(mx, my, self.listView) then
        self.lTarget = math.max(0, math.min(self.lMax or 0, self.lTarget + step))
    elseif inRect(mx, my, L.editView) then
        self.eTarget = math.max(0, math.min(self.eMax or 0, self.eTarget + step))
    end
    return true
end

KnoxWindowDrag.install(E)
local dragUp = E.onMouseUp
function E:onMouseUp(x, y)
    self.paint = nil
    return dragUp(self, x, y)
end

function E:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE or (key == Keyboard.KEY_Z and isCtrlKeyDown())
end

function E:onKeyRelease(key)
    if self.nameBox and self.nameBox:isFocused() then return end
    if self.searchBox and self.searchBox:isFocused() then return end
    if key == Keyboard.KEY_ESCAPE then
        if self.popup then self.popup = nil self:build() return end
        if self.unsaved and self.unsaved > 0 and not self.closeAsk then
            self.closeAsk = true
            self:build()
            return
        end
        self:close()
    elseif key == Keyboard.KEY_Z and isCtrlKeyDown() then
        self:undoLast()
    end
end

-- Save -----------------------------------------------------------------------------------------

function E:save()
    -- (a name being typed is the preset's)
    if self.renaming then self:commitRename() end
    if self.layer == "mod" or (self.defaultsP and self.savedDefaults and itemsDiff(self.defaultsP.items, self.savedDefaults) > 0) then
        self:saveDefaults()
    end
    if self.server then
        local files = {}
        for _, p in ipairs(self.store.list) do files[p.file] = P.text(p) end
        sendClientCommand(getSpecificPlayer(0), KnoxNet.MODULE, "presetsPut", {index = P.indexLines(self.store), files = files})
        self.waiting = true
    else
        P.saveLocal(self.store, nil, self.gone)
        P.store = self.store
        D.forgetAll()
        P.apply()
    end
    self:snapshot()
    self.undo = {}
    self:build()
end

--- The mod's own defaults (dev mode): media/knox/item_defaults.txt in the mod's folder.
function E:saveDefaults()
    local p = self.defaultsP
    local lines = {"# Knox Inventory: the mod's own item defaults (written by the item editor in dev mode).",
                   "# The lowest layer: presets and knox_overrides.txt go over them."}
    for _, ft in ipairs(P.sortedKeys(p.items)) do
        local rest = P.restOf(p.items[ft])
        if rest ~= "" then lines[#lines + 1] = ft .. " = " .. rest end
    end
    local w = getModFileWriter and getModFileWriter(T.MOD_ID, F.DEFAULTS_FILE, true, false)
    if w then
        for _, l in ipairs(lines) do w:write(l .. "\r\n") end
        w:close()
    end
    F.loadDefaults()
    D.forgetAll()
    P.apply()
end

--- The server's presets came (asked for on opening; again after a save).
function E.onServerPresets(args)
    local self = E.instance
    if not self or not self.server then return end
    local files = {}
    for file, lines in pairs(type(args.files) == "table" and args.files or {}) do
        local t = {}
        for _, l in ipairs(lines) do t[#t + 1] = tostring(l) end
        files[file] = t
    end
    local index = {}
    for _, l in ipairs(type(args.index) == "table" and args.index or {}) do index[#index + 1] = tostring(l) end
    self.store = P.storeFrom(index, files)
    self.waiting = false
    D.forgetAll()
    self:snapshot()
    if self.psel ~= "new" and self.psel ~= "import" then self.psel = self:target() end
    self:build()
end

-- Opening ------------------------------------------------------------------------------------------

function E:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false
    o.side, o.psel = "bag", nil
    o.part, o.mirror = {1, 1}, true
    o.lScroll, o.lTarget, o.eScroll, o.eTarget = 0, 0, 0, 0
    o.lMax, o.eMax = 0, 0
    o.fadeL, o.fadeE = {0, 0}, {0, 0}
    o.undo, o.gone, o.saved = {}, {}, {}
    o.layer = "player"
    o.nScope, o.nCat, o.nStart = "all", "bag", "knox"
    o.knoxP = {builtin = true, name = tx("KnoxDefault"), scope = "all", items = {}, n = 0}
    o.devOn = KnoxTestBench ~= nil and KnoxTestBench.devOn ~= nil and KnoxTestBench.devOn() == true
    if o.devOn then
        o.defaultsP = {defaults = true, name = tx("Layer_mod"), scope = "all", items = copyItems(F.baseOverrides or {}), on = true}
        D.count(o.defaultsP)
    end
    local mp = KnoxNet and KnoxNet.mp and KnoxNet.mp()
    if mp and KnoxNet.isAdmin(getSpecificPlayer(0)) then
        o.server = true
        o.store = nil   -- asked for (E.open)
    else
        o.store = P.store or {list = {}}
        o.mpLocal = mp
    end
    return o
end

function E:createChildren()
    self.L = self:layout()
    self:setWidth(self.L.w)
    self:setHeight(self.L.h)
    self.searchBox = makeBox(self, tx("Search"))
    self.searchBox:setVisible(false)
    self.nameBox = makeBox(self, nil)
    self.nameBox:setVisible(false)
    self.nameBox.onCommandEntered = function()
        if self.renaming then self:commitRename() end
        self.nameBox:unfocus()
    end
end

function E:close()
    self.paint = nil
    self:setVisible(false)
    self:removeFromUIManager()
    if E.instance == self then E.instance = nil end
end

--- Open the editor (on the item `ft` when given).
function E.open(ft)
    if E.instance then
        if ft then E.instance:openOn(ft) end
        E.instance:bringToTop()
        return E.instance
    end
    T.ensure()
    local w = E:new()
    w:initialise()
    w:instantiate()
    w:setWantKeyEvents(true)
    w:setX(math.floor((getCore():getScreenWidth() - w:getWidth()) / 2))
    w:setY(math.floor((getCore():getScreenHeight() - w:getHeight()) / 2))
    w:addToUIManager()
    w:setAlwaysOnTop(true)
    E.instance = w
    w:snapshot()
    if w.server then
        sendClientCommand(getSpecificPlayer(0), KnoxNet.MODULE, "presetsGet", {})
    end
    if ft then
        w:openOn(ft)
    else
        w:goSide("bag")
    end
    w:build()
    return w
end

--- Go to an item: its tab, chosen.
function E:openOn(ft)
    local e = D.byType(ft)
    if not e then return end
    if self.store and not holds(self:target(), e) then
        -- (the edited preset can't hold it: back to the general one)
        local g = self:generalOn()
        if g then self:setTarget(g) end
    end
    self:goSide(e.side)
    self:pick(ft)
    self:build()
end

if KnoxNet then KnoxNet.onPresets = E.onServerPresets end

-- The grids on the screen follow presets put in effect
P.onApplied = function()
    if KnoxScreen and KnoxScreen.instance and KnoxScreen.instance.markAllDirty then KnoxScreen.instance:markAllDirty() end
end

-- "Item editor" on an item's menu
local function onFillMenu(playerNum, context, items)
    if Knox and Knox.forPlayer and not Knox.forPlayer(playerNum) then return end
    local first = items and items[1]
    if not first then return end
    local item = instanceof(first, "InventoryItem") and first or (first.items and first.items[1])
    if not item then return end
    context:addOption(tx("Open"), item:getFullType(), function(ft) E.open(ft) end)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillMenu)

return KnoxEditor
