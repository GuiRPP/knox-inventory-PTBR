-- "Inventory" column: the pockets and every worn or held bag, each as a grid.
-- Scrolls with the mouse wheel when the bags don't fit the column.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxGridView"

KnoxInventoryPanel = ISPanel:derive("KnoxInventoryPanel")

local T = KnoxTheme
-- the grid a little under its header: its compartments' frame lies outside its outer
-- lines, and the no-room mask 2 px round them - flush under the header they took its
-- last line (the author, 2026-10-21: the grid went onto the backpack's header again)
local GRID_TOP = 2
local REFRESH_MS = 500

local function round1(v)
    return tostring(math.floor(v * 10 + 0.5) / 10)
end
KnoxInventoryPanel.round1 = round1

--- Width the column needs: the widest grid we expect (8 columns) plus padding.
function KnoxInventoryPanel.columnWidth()
    return T.pad * 2 + 8 * T.cell + 1
end

--- Width of every section's header: the whole column, however narrow the grid
--- under it is (the pockets are four cells wide, a fanny pack two).
function KnoxInventoryPanel.headerW()
    return 8 * T.cell + 1
end

function KnoxInventoryPanel:new(x, y, w, h, playerNum)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.sections = {}
    o.signature = ""
    o.lastCheckMs = 0
    o.contentH = 0
    return o
end

function KnoxInventoryPanel:player()
    return getSpecificPlayer(self.playerNum)
end

-- Order of the sections: the player's own (dragging a header), kept in the
-- character's modData as container keys. Keys of bags not worn now stay in the
-- list, so a bag put on again comes back to its place; a bag never placed goes
-- after the others. Without an order: pockets first, then bags as they lie.
local MAX_ORDER = 64

local function orderList(player)
    -- (in a game with others: the character's own, kept by the server - KnoxNet)
    if KnoxNet and KnoxNet.mp() then return KnoxNet.order() end
    local md = player:getModData()
    if type(md.knoxOrder) ~= "table" then md.knoxOrder = {} end
    return md.knoxOrder
end

--- Containers on the character: pockets and worn or held bags, in the player's order.
function KnoxInventoryPanel:collectContainers()
    local player = self:player()
    local inv = player:getInventory()
    local list = {{container = inv, title = getText("IGUI_Knox_Pockets"), pockets = true}}
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if instanceof(item, "InventoryContainer") and KnoxGrid.isEquippedNow(item, player) and item:getInventory() then
            table.insert(list, {container = item:getInventory(), title = item:getDisplayName(), bag = item})
        end
    end
    local rank = {}
    for i, key in ipairs(orderList(player)) do rank[key] = i end
    for i, c in ipairs(list) do
        c.key = KnoxGrid.containerKey(c.container, player)
        c.rank = rank[c.key] or (1000 + i)   -- never placed: after the placed ones, as they lie
    end
    table.sort(list, function(a, b) return a.rank < b.rank end)
    return list
end

--- Move section `s` to stand before the section at index `at` (past the last: to the end).
function KnoxInventoryPanel:moveSection(s, at)
    local player = self:player()
    local order = orderList(player)
    -- every shown section in the list, in the order shown (new ones come last)
    local known = {}
    for _, k in ipairs(order) do known[k] = true end
    for _, sec in ipairs(self.sections) do
        if not known[sec.key] then table.insert(order, sec.key) end
    end
    local before = self.sections[at] and self.sections[at].key or nil
    for i = #order, 1, -1 do
        if order[i] == s.key then table.remove(order, i) end
    end
    local pos = #order + 1
    if before then
        for i, k in ipairs(order) do
            if k == before then pos = i break end
        end
    end
    table.insert(order, pos, s.key)
    -- forget the oldest bags not worn now when the list grows long
    local shown = {}
    for _, sec in ipairs(self.sections) do shown[sec.key] = true end
    for i = #order, 1, -1 do
        if #order <= MAX_ORDER then break end
        if not shown[order[i]] then table.remove(order, i) end
    end
    if KnoxNet and KnoxNet.mp() then KnoxNet.orderChanged() end
    self:rebuildSections()
    getSoundManager():playUISound("UIActivateButton")
end

local function signatureOf(list, player)
    local parts = {}
    for _, c in ipairs(list) do
        local cols, rows, limit = KnoxGrid.getSize(c.container, player)
        table.insert(parts, KnoxGrid.containerKey(c.container, player) .. ":" .. cols .. "x" .. rows .. "/" .. (limit or 0))
    end
    return table.concat(parts, "|")
end

-- Collapsed sections show only their header (the button at its right end),
-- by container, for the whole game session.
KnoxInventoryPanel.collapsed = KnoxInventoryPanel.collapsed or {}

-- (not isCollapsed: ISUIElement:drawRect draws nothing when self.isCollapsed is set)
function KnoxInventoryPanel:sectionCollapsed(container)
    return KnoxInventoryPanel.collapsed[KnoxGrid.containerKey(container, self:player())] == true
end

--- Fold or unfold a section: its grid rolls up under its header or comes out
--- from under it (relayout, `foldMs`), the sections under it follow. The
--- sections are not rebuilt for it (that dropped the animation, and a grid
--- unfolded that way could lie over the next header for a moment).
function KnoxInventoryPanel:toggleCollapsed(container)
    local key = KnoxGrid.containerKey(container, self:player())
    KnoxInventoryPanel.collapsed[key] = not KnoxInventoryPanel.collapsed[key] or nil
    for _, s in ipairs(self.sections) do
        if s.view.container == container then
            s.collapsed = KnoxInventoryPanel.collapsed[key] == true
            -- (turned back half-way: from where it is now)
            s.foldFrom = s.shown or (T.sectionH + (s.collapsed and s.viewH + GRID_TOP or 0))
            s.foldMs = getTimestampMs()
            s.appearMs = nil
            s.view:setVisible(false)
            if not s.collapsed then
                -- a folded grid doesn't follow what happens in its bag: up to date first
                s.view:rebuild()
                s.viewH = s.view:getHeight()
            end
        end
    end
    self:relayout()
end

--- How far right a section's grid stands: a bag with compartments in the middle
--- under its header (symmetric, as its compartments are); a plain grid at its left.
local function gridOffset(shape, viewW)
    if not shape then return 0 end
    return math.max(0, math.floor((KnoxInventoryPanel.headerW() - viewW) / 2))
end

local function shapeW(shape)
    local g = KnoxBagShapes.geometry(shape, T.cell)
    return math.max(g.w, g.ovW) + 1
end

-- A bag put on or taken off: its section doesn't just appear or vanish. A new
-- one has its header at once and its grid unrolls downwards under it - an empty
-- grid of the very width of the real one, row after row, then the things in it;
-- one that has gone rolls up the same way, and the sections under it slide up.
local SECTION_MS = 190

--- An empty grid `cols` wide showing `px` pixels of its height, at x, y (a bag
--- with compartments: its compartments, as the grid draws them - KnoxBagShapes).
local function drawUnrolled(ui, x, y, cols, px, strength, shape)
    if px <= 0 then return end
    local cs = T.cell
    if shape then
        local w = shapeW(shape)
        x = x + gridOffset(shape, w)
        KnoxGridView.drawShape(ui, x, y, shape, cs, px, strength)
        local c = T.color.accent
        ui:drawRect(x, y + px - 1, w, 1, 0.7 * strength, c.r, c.g, c.b)
        return
    end
    local w = cols * cs
    T.rect(ui, x, y, w, px, T.color.cell, T.gridAlpha() * strength)
    local line = T.color.line
    local la = T.gridLineAlpha() * strength
    for i = 0, cols do ui:drawRect(x + i * cs, y, 1, px, la, line.r, line.g, line.b) end
    for j = 0, math.floor(px / cs) do ui:drawRect(x, y + j * cs, w + 1, 1, la, line.r, line.g, line.b) end
    -- the edge it unrolls at
    local c = T.color.accent
    ui:drawRect(x, y + px - 1, w + 1, 1, 0.7 * strength, c.r, c.g, c.b)
end

function KnoxInventoryPanel:rebuildSections()
    -- what was there, to tell what has come and what has gone
    local old, oldKeys = {}, {}
    for _, s in ipairs(self.sections) do
        oldKeys[s.key] = s.y
        table.insert(old, {key = s.key, h = T.sectionH + (s.collapsed and 0 or s.view:getHeight() + GRID_TOP),
                           cols = s.view.layout.cols, shape = s.view.layout.shape, title = s.title})
        self:removeChild(s.view)
    end
    self.sections = {}

    local player = self:player()
    local list = self:collectContainers()
    self.signature = signatureOf(list, player)

    local now = getTimestampMs()
    local newKeys = {}
    for _, c in ipairs(list) do
        local view = KnoxGridView:new(T.pad, 0, c.container, self.playerNum)
        view:initialise()
        self:addChild(view)
        local collapsed = self:sectionCollapsed(c.container)
        view:setVisible(not collapsed)
        local s = {view = view, title = c.title, pockets = c.pockets, bag = c.bag, key = c.key, x = T.pad, y = 0,
                   collapsed = collapsed, viewH = view:getHeight()}
        if #old > 0 and not oldKeys[c.key] then s.appearMs = now end
        -- (it stood elsewhere before: it slides from there - see relayout)
        if oldKeys[c.key] then s.fromY, s.moveMs = oldKeys[c.key], now end
        newKeys[c.key] = true
        table.insert(self.sections, s)
    end
    -- the gone ones: each folds away before the section that now stands where it stood
    self.ghosts = self.ghosts or {}
    local at = 1
    for _, o in ipairs(old) do
        if newKeys[o.key] then
            at = at + 1
        else
            table.insert(self.ghosts, {at = at, h = o.h, ms = now, cols = o.cols, shape = o.shape, title = o.title})
        end
    end
    self:setScrollChildren(true)
    self:relayout()
end

--- Sections placed one under the other (a grid grew or shrank: overflow rows;
--- a section is unfolding or folding away: every frame until it is done).
function KnoxInventoryPanel:relayout()
    local now = getTimestampMs()
    local y = T.pad
    local busy = false
    local keep = {}
    for i = 1, #self.sections + 1 do
        for _, g in ipairs(self.ghosts or {}) do
            if g.at == i then
                local t = T.anim((now - g.ms) / SECTION_MS)
                if t < 1 then
                    local k = (1 - t) * (1 - t)
                    g.y, g.shown, g.k = y, math.floor(g.h * k + 0.5), k
                    y = y + g.shown + math.floor(T.gap * k + 0.5)
                    busy = true
                    table.insert(keep, g)
                end
            end
        end
        local s = self.sections[i]
        if s then
            s.y = y
            s.viewH = s.view:getHeight()
            local full = T.sectionH + (s.collapsed and 0 or s.viewH + GRID_TOP)
            local shown = full
            if s.foldMs then
                -- folding or unfolding (toggleCollapsed): the grid shown as an empty
                -- one rolling, the real one back when it is out
                local t = T.anim((now - s.foldMs) / SECTION_MS)
                if t >= 1 then
                    s.foldMs, s.foldFrom = nil, nil
                    s.view:setVisible(not s.collapsed)
                else
                    local k = 1 - (1 - t) * (1 - t)
                    shown = math.floor(s.foldFrom + (full - s.foldFrom) * k + 0.5)
                    s.view:setVisible(false)
                    busy = true
                end
            elseif s.appearMs then
                local t = T.anim((now - s.appearMs) / SECTION_MS)
                if t >= 1 then
                    s.appearMs = nil
                    s.view:setVisible(not s.collapsed)
                else
                    local k = 1 - (1 - t) * (1 - t)
                    shown = math.floor(full * k + 0.5)
                    s.view:setVisible(false)
                    busy = true
                end
            end
            s.shown = shown
            -- changed places (the player moved a section): it slides to the new one
            if s.moveMs then
                local t = T.anim((now - s.moveMs) / SECTION_MS)
                if t >= 1 or s.fromY == y then
                    s.moveMs = nil
                else
                    local k = 1 - (1 - t) * (1 - t)
                    s.y = math.floor(s.fromY + (y - s.fromY) * k + 0.5)
                    busy = true
                end
            end
            s.view:setY(s.y + T.sectionH + GRID_TOP)
            local gx = s.x + gridOffset(s.view.layout.shape, s.view:getWidth())
            if s.view:getX() ~= gx then s.view:setX(gx) end
            y = y + shown + T.gap
        end
    end
    self.ghosts = keep
    self.animating = busy
    self.contentH = y
    self:setScrollHeight(self.contentH)
    self:clampScroll()
end
function KnoxInventoryPanel:markAllDirty()
    for _, s in ipairs(self.sections) do s.view:markDirty() end
end

function KnoxInventoryPanel:createChildren()
    self:rebuildSections()
end

function KnoxInventoryPanel:clampScroll()
    local minY = math.min(0, self:getHeight() - self.contentH)
    local ys = self:getYScroll()
    if ys < minY then self:setYScroll(minY) elseif ys > 0 then self:setYScroll(0) end
end

function KnoxInventoryPanel:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * T.cell)
    self:clampScroll()
    return true
end

-- A bag's header says how full it is with two rows of cubes (the author's
-- choice, 2026-10-20 - "4x7+10 1.3/19" told the grid's shape, not how much
-- room is left): ten cubes are the whole bag, as many light up as it is full
-- (one at least while anything is in it), the numbers right of them. Cells
-- in sand; the weight in green, yellow from 80 % of the limit, red over it.
-- Pockets have no weight limit of their own: cells only.
local METER_CUBES = 10

--- Cells of a grid in all (its shape's, or its columns and rows).
local function totalCells(L)
    if L.shape then return L.shape.cells end
    if L.limit then return L.limit end
    return L.cols * (L.baseRows or L.rows)
end

--- One meter: `n` of METER_CUBES lit in `c`, then `text`; drawn leftwards
--- from `right`, in the middle of a header at `y`. Returns its left edge.
--- How many cubes are lit as shown: it eases toward `lit` (a cube comes up or
--- goes out over about a fifth of a second), kept in `st`.
local function shownLit(st, key, lit)
    local now = getTimestampMs()
    local was = st[key]
    local ms = st[key .. "Ms"] or now
    st[key .. "Ms"] = now
    if not T.animOn() then
        st[key] = lit
        return lit
    end
    was = was or 0   -- (a bag just shown: its cubes fill up from none)
    was = was + (lit - was) * (1 - math.exp(-math.min(100, now - ms) / 70))
    if math.abs(lit - was) < 0.002 then was = lit end
    st[key] = was
    return was
end

--- (`n` cubes; `ui` nil: only where it would end; `st`, `key`: where the cubes'
--- easing is kept)
local function meter(ui, right, y, frac, text, c, n, st, key)
    local f = T.fontText
    local tw = T.measure(f, text)
    local x = right - tw
    if ui then T.label(ui, text, {x, y, tw, T.sectionH}, T.color.dim, {font = f}) end
    local cs = math.max(5, math.floor(T.sectionH * 0.22))
    local gap = 2
    local w = n * cs + (n - 1) * gap
    x = x - 6 - w
    if not ui then return x end
    local lit = 0
    if frac > 0 then lit = math.max(1, math.min(n, math.ceil(frac * n - 1e-6))) end
    -- (in fractions of the meter, so that 10 cubes turning to 5 is not a jump)
    local shown = shownLit(st, key, lit / n) * n
    local cy = y + math.floor((T.sectionH - cs) / 2)
    for i = 0, n - 1 do
        local cx = x + i * (cs + gap)
        T.rect(ui, cx, cy, cs, cs, T.color.border)
        local a = math.max(0, math.min(1, shown - i))
        if a > 0 then T.rect(ui, cx, cy, cs, cs, c, a) end
    end
    return x
end

local function meters(ui, s, L, player, right, y, n)
    s.meterSt = s.meterSt or {}
    local wt, cap = L.container:getCapacityWeight(), L.container:getEffectiveCapacity(player)
    local frac = cap > 0 and wt / cap or 0
    local c = frac > 1 and T.color.bad or (frac >= 0.8 and T.color.warn or T.color.good)
    local x = meter(ui, right, y, frac, round1(wt) .. "/" .. round1(cap) .. " " .. getText("IGUI_Knox_Kg"), c, n, s.meterSt, "w") - 12
    local total = math.max(1, totalCells(L))
    local used = s.cellsUsed or 0
    return meter(ui, x, y, used / total, used .. "/" .. total, T.color.accent, n, s.meterSt, "c")
end

local function drawMeters(ui, s, L, player, right, y)
    -- pockets: no cubes, only the grid's size as before (the author, 2026-10-20)
    if s.pockets then
        local text = KnoxGrid.sizeText(L)
        return right - T.label(ui, text, {right, y, 0, T.sectionH}, T.color.dim, {font = T.fontText, align = "right"})
    end
    -- (the cells counted a few times a second, not every frame)
    local now = getTimestampMs()
    if not s.cellsMs or now - s.cellsMs > 250 then
        s.cellsMs = now
        s.cellsUsed = KnoxGrid.usedCells(L.container)
    end
    -- ten cubes a meter; five (a fifth each) where ten would cut the bag's name
    local n = METER_CUBES
    local need = T.measure(T.fontCaps, T.upper(s.title or "")) + 26
    if meters(nil, s, L, player, right, y, n) - s.x < need then n = 5 end
    return meters(ui, s, L, player, right, y, n)
end

function KnoxInventoryPanel:prerender()
    local now = getTimestampMs()
    if now - self.lastCheckMs > REFRESH_MS then
        self.lastCheckMs = now
        if signatureOf(self:collectContainers(), self:player()) ~= self.signature then
            self:rebuildSections()
        end
    end

    if self.animating then
        self:relayout()
    else
        for _, s in ipairs(self.sections) do
            if s.view:getHeight() ~= s.viewH then
                self:relayout()
                break
            end
        end
    end

    -- the stencil is in panel coordinates; drawing below is in scrolled content
    -- coordinates (the engine adds the scroll)
    self:setStencilRect(0, 0, self:getWidth(), self:getHeight())

    local player = self:player()
    local ft = T.fontH(T.fontText)
    local active = KnoxActions.activeContainer(player)
    local hover = self:isMouseOver() and self:sectionAtHeader(self:getMouseX(), self:getMouseY())
    -- sections rolling up: the header (its name only) and what is left of the grid
    for _, g in ipairs(self.ghosts or {}) do
        if g.shown and g.shown > 0 then
            local hh = math.min(T.sectionH, g.shown)
            T.rect(self, T.pad, g.y, KnoxInventoryPanel.headerW(), hh, T.color.header, T.bgAlpha() * g.k)
            if hh >= T.sectionH then
                T.text(self, T.upper(g.title or ""), T.pad + 8, g.y + math.floor((T.sectionH - T.fontH(T.fontCaps)) / 2),
                    T.color.dim, T.fontCaps, g.k)
            end
            drawUnrolled(self, T.pad, g.y + T.sectionH + GRID_TOP, g.cols or 1, g.shown - T.sectionH - GRID_TOP, g.k, g.shape)
        end
    end
    for _, s in ipairs(self.sections) do
      -- unrolling: its header is there at once, its grid comes out from under it
      if (s.appearMs and not s.collapsed) or s.foldMs then
          drawUnrolled(self, s.x, s.y + T.sectionH + GRID_TOP, s.view.layout.cols, (s.shown or 0) - T.sectionH - GRID_TOP, 1, s.view.layout.shape)
      end
      do
        local L = s.view.layout
        local vw = KnoxInventoryPanel.headerW()
        local sy = s.y
        local isActive = s.view.container == active
        T.rect(self, s.x, sy, vw, T.sectionH, T.color.header, T.bgAlpha())
        if hover == s and not isActive then self:drawRect(s.x, sy, vw, T.sectionH, 0.05, 1, 1, 1) end
        if isActive then
            -- the active container: a 2 px sand frame around the header, wider on the left
            T.border(self, s.x, sy, vw, T.sectionH, T.color.accent)
            T.border(self, s.x + 1, sy + 1, vw - 2, T.sectionH - 2, T.color.accent)
            T.rect(self, s.x, sy, 3, T.sectionH, T.color.accent)
        end
        -- how full it is: cubes of the cells and of the weight (see drawMeters);
        -- a note goes left of them (things that did not fit), or instead of them
        -- (a bag being searched: KnoxSearch)
        local info
        local searching = KnoxSearch and KnoxSearch.busy(L.container)
        if searching then
            info = getText("IGUI_Knox_Searching", KnoxSearch.found(), L.container:getItems():size())
        elseif #L.overflow > 0 then
            info = getText("IGUI_Knox_Overflow", #L.overflow)
        end
        -- collapse button at the right end, the info left of it
        local b = self:collapseRect(s)
        local bHover = self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), b)
        -- (pointing right: unfold; down: fold)
        T.iconButton(self, b, s.collapsed and "right" or "down", bHover)
        -- Sort (KnoxOrder): the same picture as the surroundings' header has
        local sr = self:sortRect(s)
        local sHover = self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), sr)
        T.border(self, sr[1], sr[2], sr[3], sr[4], sHover and T.color.accent or T.color.tileEdge)
        if KnoxLootPanel and KnoxLootPanel.drawIcon then
            KnoxLootPanel.drawIcon(self, sr, "sort", sHover and T.color.accent or T.color.text)
        end
        local er = self:eyeRect(s)
        if er then
            local eHover = self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), er)
            T.border(self, er[1], er[2], er[3], er[4], eHover and T.color.accent or T.color.tileEdge)
            KnoxOrder.drawEye(self, er, eHover and T.color.accent or T.color.text, KnoxOrder.ghostK())
        end
        local ty = sy + math.floor((T.sectionH - ft) / 2)
        local infoRight = (er or sr)[1] - 6
        if not searching then
            infoRight = drawMeters(self, s, L, player, infoRight, sy) - (info and 10 or 0)
        end
        local infoW = 0
        if info then
            infoW = T.label(self, info, {infoRight, sy, 0, T.sectionH}, searching and T.color.dim or T.color.bad,
                {font = T.fontText, align = "right"})
        end
        -- (a long container's name slides instead of being cut with a dot - the author,
        -- 2026-10-21; on the height the layout kit would put it at)
        local title = T.upper(s.title)
        local _, tyInk = T.inkOrigin(title, s.x + 8, sy, 0, T.sectionH, T.fontCaps)
        self.titleSt = self.titleSt or {}
        local tst = self.titleSt[s.title]
        if not tst then
            tst = {}
            self.titleSt[s.title] = tst
        end
        T.marquee(self, tst, title, s.x + 8, tyInk, infoRight - s.x - infoW - 18, isActive and T.color.accent or T.color.text, T.fontCaps)
      end
    end
end

--- The collapse button of a section's header, in content coordinates.
function KnoxInventoryPanel:collapseRect(s)
    local bs = T.sectionH - 8
    return {s.x + KnoxInventoryPanel.headerW() - bs - 4, s.y + 4, bs, bs}
end

--- The Sort button, left of the collapse button.
function KnoxInventoryPanel:sortRect(s)
    local b = self:collapseRect(s)
    return {b[1] - b[3] - 4, b[2], b[3], b[4]}
end

--- The eye (the layout's silhouettes shown or hidden) left of Sort, or nil
--- when the container has no layout.
function KnoxInventoryPanel:eyeRect(s)
    -- (whether there is a layout, asked of the container's holder a few times a
    -- second, not every frame for every header; at once when one is saved or forgotten)
    local now = getTimestampMs()
    if s.layoutStamp ~= KnoxOrder.stamp or now - (s.layoutMs or 0) > 500 then
        s.layoutStamp, s.layoutMs = KnoxOrder.stamp, now
        s.hasLayout = KnoxOrder.layoutOf(s.view.container) ~= nil
    end
    if not s.hasLayout then return nil end
    local b = self:sortRect(s)
    return {b[1] - b[3] - 4, b[2], b[3], b[4]}
end

--- Section whose header is at x,y: content coordinates, as the game gives them to
--- onMouseDown and getMouseY (the scroll already taken off - it was taken off
--- twice, and with the column scrolled the clicks hit the wrong bag: EvilToaster's
--- report, 2026-10-16).
function KnoxInventoryPanel:sectionAtHeader(x, y)
    local cy = y
    for _, s in ipairs(self.sections) do
        if x >= s.x and x < s.x + KnoxInventoryPanel.headerW() and cy >= s.y and cy < s.y + T.sectionH then return s end
    end
    return nil
end

-- A click on a header makes that container the active one; dragging a worn
-- bag's header takes the bag off (drop it on a grid, like any worn item).
local DRAG_START_PX = 5

function KnoxInventoryPanel:onMouseDown(x, y)
    local s = self:sectionAtHeader(x, y)
    if s and T.inRect(x, y, self:collapseRect(s)) then
        self.press = nil
        self:toggleCollapsed(s.view.container)
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    if s and T.inRect(x, y, self:sortRect(s)) then
        self.press = nil
        KnoxOrder.sort(s.view)
        return true
    end
    local er = s and self:eyeRect(s)
    if er and T.inRect(x, y, er) then
        self.press = nil
        KnoxOrder.toggleGhosts()
        return true
    end
    self.press = s and {section = s, x = getMouseX(), y = getMouseY()} or nil
    return true
end

--- Slot a worn or held bag is taken from (for its move).
local function slotOf(bag, player)
    if bag == player:getPrimaryHandItem() then return "hand1" end
    if bag == player:getSecondaryHandItem() then return "hand2" end
    return KnoxEquip.wearTarget(bag)
end

function KnoxInventoryPanel:onMouseMove(dx, dy)
    local p = self.press
    if not p or KnoxDrag.isActive() or not isMouseButtonDown(0) then return end
    if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) < DRAG_START_PX then return end
    self.press = nil
    local bag = p.section.bag
    if bag then
        KnoxDrag.startFromBody(bag, slotOf(bag, self:player()))
    else
        self.moving = p.section   -- the pockets: they can only change their place
    end
end

-- Reordering: a section's header dragged (a bag's, as the bag itself, or the
-- pockets') and let go over a header, the gap above one or the free space
-- under the last section stands it there. Let go over a grid, a bag goes in
-- as before; anywhere else it is taken off as before.

--- The section being dragged by its header, or nil.
function KnoxInventoryPanel:movingSection()
    if self.moving then return self.moving end
    if KnoxDrag.isActive() and KnoxDrag.entity.fromBody then
        for _, s in ipairs(self.sections) do
            if s.bag and s.bag == KnoxDrag.entity.item then return s end
        end
    end
    return nil
end

--- Index the moved section would be put before (past the last: the end) for
--- the mouse at local x, y, or nil when it isn't over a place for it or the
--- order would not change.
function KnoxInventoryPanel:insertAt(s, x, y)
    if not self:isMouseOver() or x < 0 or x >= self:getWidth() then return nil end
    local cy = y
    local at = nil
    for i, sec in ipairs(self.sections) do
        if cy >= sec.y - T.gap and cy < sec.y + T.sectionH then at = i break end
    end
    if not at and cy >= self.contentH - T.gap then at = #self.sections + 1 end
    if not at then return nil end
    for i, sec in ipairs(self.sections) do
        if sec == s and (at == i or at == i + 1) then return nil end   -- stays where it is
    end
    return at
end

function KnoxInventoryPanel:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

-- Free space under the last grid: dropping a bag or clothes there puts it on.

--- The dragged item, when it could be put on from here.
function KnoxInventoryPanel:wearableDragged()
    if not KnoxDrag.isActive() or KnoxDrag.entity.fromBody then return nil end
    local item = KnoxDrag.entity.item
    if KnoxEquip.wearLoc(item) == "" or KnoxGrid.isEquippedNow(item, self:player()) then return nil end
    return item
end

--- The free area in content coordinates {x, y, w, h}, or nil when there is none.
function KnoxInventoryPanel:wearZone()
    local y = self.contentH
    local bottom = self:getHeight() - self:getYScroll() - T.pad
    if bottom - y < T.cell then return nil end
    return {T.pad, y, self:getWidth() - T.pad * 2, bottom - y}
end

function KnoxInventoryPanel:mouseInWearZone(z)
    return z and self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), z)
end

function KnoxInventoryPanel:onMouseUp(x, y)
    local moving = self:movingSection()
    if moving then
        local at = self:insertAt(moving, x, y)
        self.moving = nil
        self.press = nil
        if at then
            if KnoxDrag.isActive() then KnoxDrag.cancel() end
            self:moveSection(moving, at)
            return true
        end
    end
    local item = self:wearableDragged()
    if item then
        local over = self:mouseInWearZone(self:wearZone())
        local source = KnoxDrag.sourceInfo()
        KnoxDrag.cancel()
        if over then KnoxEquip.wearItem(self:player(), item, source) end
        return true
    end
    local p = self.press
    self.press = nil
    if p and not KnoxDrag.isActive() then
        KnoxActions.setActive(p.section.view.container, self.playerNum)
        getSoundManager():playUISound("UIActivateButton")
    end
    return true
end

function KnoxInventoryPanel:onMouseUpOutside(x, y)
    self.press = nil
    self.moving = nil
end

--- Right click on a header: Sort, its rule and the layout (KnoxOrder); move
--- the section up, down or to the top.
function KnoxInventoryPanel:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end   -- (an item is held: the button may turn it, see KnoxDragLayer)

    local s = self:sectionAtHeader(x, y)
    if not s then return true end
    -- (at the mouse on the screen: x, y are in the scrolled content)
    local menu = ISContextMenu.get(self.playerNum, getMouseX(), getMouseY())
    KnoxOrder.addMenu(menu, s.view)
    if #self.sections < 2 then return true end
    local idx = 1
    for i, sec in ipairs(self.sections) do
        if sec == s then idx = i end
    end
    local panel = self
    local function option(text, at, enabled)
        local o = menu:addOption(getText(text), panel, function() panel:moveSection(s, at) end)
        if not enabled then o.notAvailable = true end
    end
    option("IGUI_Knox_MoveTop", 1, idx > 1)
    option("IGUI_Knox_MoveUp", idx - 1, idx > 1)
    option("IGUI_Knox_MoveDown", idx + 2, idx < #self.sections)
    return true
end

--- While a header is dragged: a sand bar where the section would go; the
--- pockets' header follows the mouse as a faded plate.
function KnoxInventoryPanel:drawMoving()
    if self.moving and not isMouseButtonDown(0) then self.moving = nil end   -- let go over a grid
    local s = self:movingSection()
    if not s then return end
    local c = T.color.accent
    local w = KnoxInventoryPanel.headerW()
    local at = self:insertAt(s, self:getMouseX(), self:getMouseY())
    if at then
        local y
        if self.sections[at] then
            y = self.sections[at].y - math.floor(T.gap / 2)
        else
            y = self.contentH - math.floor(T.gap / 2)
        end
        self:drawRect(s.x, y - 2, w, 4, 1, c.r, c.g, c.b)
        self:drawRect(s.x, y - 6, 3, 12, 1, c.r, c.g, c.b)
        self:drawRect(s.x + w - 3, y - 6, 3, 12, 1, c.r, c.g, c.b)
    end
    -- the dragged section's own header dims while it is being moved
    self:drawRect(s.x, s.y, w, T.sectionH, 0.45, 0, 0, 0)
    if self.moving then
        local my = self:getMouseY() - math.floor(T.sectionH / 2)
        T.rect(self, s.x, my, w, T.sectionH, T.color.header, 0.85 * T.bgAlpha())
        T.border(self, s.x, my, w, T.sectionH, c)
        T.text(self, T.upper(s.title), s.x + 8, my + math.floor((T.sectionH - T.fontH(T.fontCaps)) / 2), T.color.accent, T.fontCaps)
    end
end

--- The mouse on the pockets' header: where their cells come from (bare hands
--- and each piece of clothing with pockets), on a plate under the header.
function KnoxInventoryPanel:drawPocketsHint()
    if not self:isMouseOver() or KnoxDrag.isActive() or self.moving or isMouseButtonDown(0) then return end
    local s = self:sectionAtHeader(self:getMouseX(), self:getMouseY())
    if not s or not s.pockets then return end
    local list = KnoxGrid.pockets(self:player())
    local f = T.fontText
    local fh = T.fontH(f)
    local w = 0
    for _, row in ipairs(list) do
        w = math.max(w, T.measure(f, row[1]) + T.measure(f, "+" .. row[2]) + 24)
    end
    w = w + 16
    local h = #list * (fh + 2) + 12
    local x, y = s.x, s.y + T.sectionH + 2
    T.rect(self, x, y, w, h, T.color.window)
    T.border(self, x, y, w, h, T.color.accent)
    local ty = y + 6
    for i, row in ipairs(list) do
        T.text(self, row[1], x + 8, ty, i == 1 and T.color.dim or T.color.text, f)
        T.textRight(self, (i == 1 and "" or "+") .. row[2], x + w - 8, ty, T.color.accent, f)
        ty = ty + fh + 2
    end
end

--- While something is dragged: the grids it has no place in at all (not
--- allowed there, or no room whichever way it is turned) go dim, so the eye
--- goes to the ones that take it. Asked a few times a second, not every frame.
function KnoxInventoryPanel:drawNoRoom()
    local active = KnoxDrag.isActive()
    for _, s in ipairs(self.sections) do s.view.knoxNoRoom = false end
    if not active then return end
    local e = KnoxDrag.entity
    local player = self:player()
    local now = getTimestampMs()
    for _, s in ipairs(self.sections) do
        local c = s.view.container
        if e.item:getContainer() ~= c or e.fromBody then
            local f = s.fit
            if not f or f.item ~= e.item or now - f.ms > 300 then
                local ok = KnoxDrag.allowedIn(e.item, c, player) == true
                if ok then ok = s.view.layout:findFree(e) ~= nil or KnoxDrag.joinTarget(s.view.layout, e) ~= nil end
                f = {item = e.item, ms = now, ok = ok}
                s.fit = f
            end
            if not f.ok then
                -- the header plate here; the grid darkens itself, on its own cells
                -- and compartments (KnoxGridView:drawNoRoomMask)
                self:drawRect(s.x, s.y, KnoxInventoryPanel.headerW(), T.sectionH, 0.55, 0.03, 0.03, 0.03)
                if not s.collapsed then s.view.knoxNoRoom = true end
            end
        end
    end
end

--- Where the grids go on past the column's edge (scrolled), they fade into the
--- column (T.edgeFades; `dt`: ms since the last frame).
function KnoxInventoryPanel:drawEdgeFades(dt)
    -- (inside the column's frame: its left and right edges stay as they are; the
    -- column is as wide as this panel and starts where it does)
    T.edgeFades(self, self.contentH, 1, self:getWidth() - 2, dt)
end

function KnoxInventoryPanel:render()
    self:drawMoving()
    self:drawNoRoom()
    self:drawPocketsHint()
    -- dragging a bag or clothes: the free area offers to put it on
    -- (it comes in and goes out over a moment, not at once)
    local z = self:wearableDragged() and self:wearZone()
    local now = getTimestampMs()
    local dt = math.min(100, now - (self.wearMs or now))
    self.wearMs = now
    local shown = self.wearShown or 0
    -- the nearer the held thing is brought to it, the brighter it is: faint
    -- from across the screen, full when the thing is over it
    local want = 0
    if z then
        local mx, my = self:getMouseX(), self:getMouseY()
        local dx = math.max(z[1] - mx, 0, mx - (z[1] + z[3]))
        local dy = math.max(z[2] - my, 0, my - (z[2] + z[4]))
        local far = math.sqrt(dx * dx + dy * dy) / (T.cell * 9)
        want = 0.25 + 0.75 * (1 - math.min(1, far))
    end
    shown = shown + (want - shown) * T.anim(math.min(1, dt / 70))
    if shown < 0.02 and not z then shown = 0 end
    self.wearShown = shown
    if z then self.wearRect = z else z = self.wearRect end
    if z and shown > 0 then
        local hot = self:wearableDragged() ~= nil and self:mouseInWearZone(z)
        local c = T.color.accent
        self:drawRect(z[1], z[2], z[3], z[4], (hot and 0.14 or 0.05) * shown, c.r, c.g, c.b)
        T.border(self, z[1], z[2], z[3], z[4], c, (hot and 1 or 0.45) * shown)
        if hot then T.border(self, z[1] + 1, z[2] + 1, z[3] - 2, z[4] - 2, c, shown) end
        local fh = T.fontH(T.fontCaps)
        T.textCentre(self, T.upper(getText("IGUI_Knox_DropToWear")), z[1] + math.floor(z[3] / 2),
            z[2] + math.floor((z[4] - fh) / 2), hot and T.color.accent or T.color.dim, T.fontCaps, shown)
    end
    self:drawEdgeFades(dt)
    self:clearStencilRect()
    -- scroll bar when the content is taller than the column: from the level of the
    -- first section's header down, in the middle of the strip right of the headers
    -- (air on both sides, not against the column's edge)
    local h = self:getHeight()
    if self.contentH > h then
        local top = T.pad
        local trackH = h - top
        local barH = math.max(T.cell, math.floor(trackH * h / self.contentH))
        local barY = top + math.floor(-self:getYScroll() / (self.contentH - h) * (trackH - barH))
        local left = T.pad + KnoxInventoryPanel.headerW()
        local bx = left + math.floor((self:getWidth() - left - 3) / 2)
        local c = T.color.tileEdge
        self:drawRect(bx, barY - self:getYScroll(), 3, barH, 1, c.r, c.g, c.b)
    end
end
