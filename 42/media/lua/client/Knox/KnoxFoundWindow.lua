-- "Found": everything the search by name has found, in one window, grouped by
-- where it lies - so that nobody has to go through the containers one by one.
-- Opened by the button next to the search field (KnoxScreen). A group per
-- container: the surroundings' ones first (only those looked into, as their
-- numbers in the list), then the character's own bags, a bag inside another
-- as a group of its own. "Take all" puts everything found around into the
-- character's bags.
--
-- The tiles are the real things, shown here: dragged out, they move from where
-- they lie; Shift+click takes one to the other side; the right button gives
-- its menu; a double click uses it (or opens a bag). The window follows the
-- search as it is typed and closes when it is emptied.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxGridView"
require "Knox/KnoxActions"
require "Knox/KnoxWindowDrag"

KnoxFoundWindow = ISPanel:derive("KnoxFoundWindow")
local W = KnoxFoundWindow
local T = KnoxTheme

W.instance = nil
local COLS = 8                -- cells across
local REBUILD_MS = 300        -- what is found is gathered again this often
local DRAG_START_PX = 5
local DOUBLE_CLICK_MS = 350
local MAX_DEPTH = 2           -- bags in bags in a container: this deep

--- Containers to look in, in order: {container, name, mine}.
local function sources(screen, player)
    local out, seen = {}, {}
    local function add(c, name, mine, depth)
        if not c or seen[c] then return end
        seen[c] = true
        table.insert(out, {container = c, name = name, mine = mine})
        if depth >= MAX_DEPTH then return end
        -- the bags lying in it, each a group of its own
        local items = c:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if instanceof(it, "InventoryContainer") and it:getInventory()
                    and not (KnoxSearch and KnoxSearch.unseen(it)) and not KnoxGrid.isEquippedNow(it, player) then
                add(it:getInventory(), it:getDisplayName(), mine, depth + 1)
            end
        end
    end
    -- around: only what has been looked into (nobody knows what is in the rest)
    local loot = screen.loot
    for _, c in ipairs(loot and loot.containers or {}) do
        local cont = c.container
        if not c.locked and (cont:getType() == "floor" or KnoxLootPanel.isSeen(cont)) then
            add(cont, c.name, false, 1)
        end
    end
    -- the character's: the pockets and every bag on it, by the inventory column's titles
    for _, s in ipairs(screen.inventory and screen.inventory.sections or {}) do
        add(s.view.container, s.title, true, 1)
    end
    return out
end

function W:new(screen, playerNum)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.screen = screen
    o.playerNum = playerNum
    o.background = false
    o.moveWithMouse = false   -- moved by its header, see KnoxWindowDrag
    o.groups = {}
    o.total = 0
    o.scroll = 0
    o.builtMs = 0
    return o
end

function W:player()
    return getSpecificPlayer(self.playerNum)
end

-- (asked a dozen times a frame: kept while the sizes stay; only read)
local metricsOf
function W:metrics()
    local mm = metricsOf
    if mm and mm.cell == T.cell and mm.pad == T.pad then return mm end
    local m = {cell = T.cell, pad = T.pad}
    metricsOf = m
    -- (taller than a bag window's: bigger buttons, plates and title - asked 2026-10-14)
    m.frame = 2                    -- the window's frame, drawn inside its edge
    m.headerH = math.floor(T.cell * 0.72 + 0.5) + m.frame
    m.headH = m.headerH - m.frame  -- the header's own band, under the frame
    m.barH = math.floor(T.cell * 0.6 + 0.5)   -- a group's title bar
    m.w = COLS * T.cell + 1 + T.pad * 2
    return m
end

--- First free place of a w x h tile in an occupancy grid of COLS columns.
local function place(occ, w, h)
    for y = 0, 200 do
        for x = 0, COLS - w do
            local free = true
            for yy = y, y + h - 1 do
                for xx = x, x + w - 1 do
                    if occ[yy * COLS + xx] then free = false break end
                end
                if not free then break end
            end
            if free then
                for yy = y, y + h - 1 do
                    for xx = x, x + w - 1 do occ[yy * COLS + xx] = true end
                end
                return x, y
            end
        end
    end
    return 0, 0
end

-- The groups live on from one gathering to the next (by their container), so
-- that what changes moves instead of jumping: a thing that is gone fades out
-- where it lay, a new one settles in, a group no longer there fades out as the
-- ones under it slide up, a new group fades in. A thing being moved (a drag,
-- Take all) is shown as the grids show it - faded, with the move's progress -
-- until the move is done.
local FADE_MS = 200          -- a group or a thing coming or going
local SETTLE_MS = 160        -- a new thing dropping into its cell
local SLIDE_MS = 90          -- groups sliding to their new places (the time constant)

--- Gather what is found, now, and lay it out.
function W:rebuild()
    local q = KnoxGridView.query()
    local player = self:player()
    local now = getTimestampMs()
    self.builtMs = now
    self.query = q
    local fresh = {}
    if q and player then
        for _, src in ipairs(sources(self.screen, player)) do
            local L = KnoxGrid.build(src.container, player)
            local tiles = {}
            for _, e in ipairs(L.placed) do
                -- (a thing on its way out of here: its faded copy, which the grid
                -- also shows; what is on its way in shows where it comes from)
                if not e.reserved and not (KnoxSearch and KnoxSearch.unseen(e.item))
                        and KnoxGridView.entityHit(e, q) then
                    table.insert(tiles, e)
                end
            end
            if #tiles > 0 then
                -- biggest first, packed into a strip as wide as the window
                table.sort(tiles, function(a, b)
                    local sa, sb = a.w * a.h, b.w * b.h
                    if sa ~= sb then return sa > sb end
                    return a.item:getFullType() < b.item:getFullType()
                end)
                local occ, rows, n = {}, 0, 0
                for _, e in ipairs(tiles) do
                    local w, h = KnoxGrid.dims(e, e.r)
                    if w > COLS then w, h = h, w end
                    w = math.min(w, COLS)
                    e.fx, e.fy = place(occ, w, h)
                    e.fw, e.fh = w, h
                    rows = math.max(rows, e.fy + h)
                    n = n + #e.items
                end
                table.insert(fresh, {src = src, tiles = tiles, rows = rows, n = n, container = src.container})
            end
        end
    end
    -- carry the groups over: what they showed, where they are, how solid
    local old, oldBy = self.groups or {}, {}
    for _, g in ipairs(old) do oldBy[g.container] = g end
    local seen = {}
    for _, g in ipairs(fresh) do
        local o = oldBy[g.container]
        seen[g.container] = true
        if o and not o.gone then
            g.y, g.a, g.plate = o.y, o.a, o.plate
            g.leaving = o.leaving or {}
            g.arrive = o.arrive or {}
            local was, has = {}, {}
            for _, e in ipairs(o.tiles) do was[e.item] = e end
            for _, e in ipairs(g.tiles) do has[e.item] = e end
            for item, e in pairs(was) do
                if not has[item] then table.insert(g.leaving, {e = e, ms = now}) end
            end
            for item in pairs(has) do
                if not was[item] then g.arrive[item] = now end
            end
        else
            g.a, g.leaving, g.arrive = 0, {}, {}   -- (a new group: fades in where it belongs)
        end
    end
    -- groups that are gone stay a moment, fading, where they were
    local merged = {}
    for _, g in ipairs(fresh) do table.insert(merged, g) end
    for i, o in ipairs(old) do
        if not seen[o.container] then
            if not o.gone then o.gone, o.goneMs = true, now end
            -- after the group that was before it, if it is still there
            local at = 1
            for k = i - 1, 1, -1 do
                local before = old[k].container
                for mi, mg in ipairs(merged) do
                    if mg.container == before then at = mi + 1 break end
                end
                if at > 1 then break end
            end
            table.insert(merged, math.min(at, #merged + 1), o)
        end
    end
    self.groups = merged
    self.total = 0
    for _, g in ipairs(merged) do
        if not g.gone then self.total = self.total + g.n end
    end
end

--- A group's height: its bar, its cells, the gap under it.
local function groupH(m, g)
    return m.barH + g.rows * T.cell + 1 + T.pad
end

--- Every frame: groups fade in or out and slide to their places; the window
--- follows the height of what it holds, up to the screen, then scrolls.
function W:animate()
    local m = self:metrics()
    local now = getTimestampMs()
    local dt = math.min(100, now - (self.animMs or now))
    self.animMs = now
    local fade = T.animOn and not T.animOn() and 1 or math.min(1, dt / FADE_MS)
    local keep = {}
    local y = 0
    for _, g in ipairs(self.groups) do
        if g.gone then
            g.a = math.max(0, (g.a or 1) - fade)
        else
            g.a = math.min(1, (g.a or 0) + fade)
        end
        if not (g.gone and g.a <= 0) then
            table.insert(keep, g)
            g.target = y
            if g.y == nil then g.y = y end
            local k = (T.animOn and not T.animOn()) and 1 or math.min(1, dt / SLIDE_MS)
            g.y = g.y + (y - g.y) * k
            if math.abs(y - g.y) < 0.5 then g.y = y end
            -- (a group going takes less and less room)
            local share = g.gone and (g.a * g.a) or 1
            y = y + groupH(m, g) * share
        end
    end
    self.groups = keep
    self.contentH = y
    local maxH = self.screen:getHeight() - self:getY() - T.cell
    local h = m.headerH + T.pad + math.max(T.cell, math.floor(y + 0.5))
    self:setWidth(m.w)
    self:setHeight(math.max(m.headerH + T.cell, math.min(h, maxH)))
    self.scroll = math.max(0, math.min(self.scroll, self.contentH - (self:getHeight() - m.headerH - T.pad)))
end

--- (kept for the open: lay out at once)
function W:layout()
    self:animate()
end
--- Number of things found, for the button (counted by the window's own rule).
function W.count(screen)
    local w = W.instance
    if w and w.query == KnoxGridView.query() then return w.total end
    local q = KnoxGridView.query()
    local player = screen:player()
    if not q or not player then return 0 end
    local n = 0
    for _, src in ipairs(sources(screen, player)) do
        local items = src.container:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if not KnoxGrid.isEquippedNow(it, player) and not (KnoxSearch and KnoxSearch.unseen(it))
                    and KnoxGridView.hit(it, q) then
                n = n + 1
            end
        end
    end
    return n
end

-- Geometry ---------------------------------------------------------------------------

-- The header: the title starts where the groups' names do; its buttons sit at
-- the window's right edge (inside the 2 px frame) and keep the bar's margin
-- (T.barMargin) above, below, between them and from that edge.

--- Right edge of the groups' count plates (and of the header's close cross).
function W:rightEdge()
    local m = self:metrics()
    return T.pad + COLS * T.cell + 1 - T.barMargin(m.barH)
end

function W:closeRect()
    local m = self:metrics()
    local mg = T.barMargin(m.headH)
    local s = m.headH - mg * 2
    return {self:getWidth() - m.frame - mg - s, m.frame + mg, s, s}
end

--- "Take all": as tall as the close cross, a margin left of it.
function W:takeRect()
    local c = self:closeRect()
    local mg = T.barMargin(self:metrics().headH)
    local text = T.upper(getText("IGUI_Knox_TakeFound"))
    -- (its caption with the same room each side as above and below it)
    local pad = math.floor(c[4] * 0.5 + 0.5)
    local w = T.measure(T.fontCaps, text) + pad * 2
    return {c[1] - mg - w, c[2], w, c[4]}, text
end

--- Top-left of the group's tiles area and of a tile, in the window.
function W:tileRect(g, e)
    local m = self:metrics()
    local x = T.pad + e.fx * T.cell + 1
    local y = m.headerH + T.pad + math.floor((g.y or 0) + 0.5) + m.barH + e.fy * T.cell + 1 - self.scroll
    return {x, y, e.fw * T.cell - 1, e.fh * T.cell - 1}
end

function W:tileAt(mx, my)
    local m = self:metrics()
    if my < m.headerH then return nil end
    for _, g in ipairs(self.groups) do
        if not g.gone then
            for _, e in ipairs(g.tiles) do
                -- (a thing being moved can't be taken: as in the grids)
                if not e.ghost and T.inRect(mx, my, self:tileRect(g, e)) then return e, g end
            end
        end
    end
    return nil
end

--- The card of a group in the window: {x, y, w, h}.
function W:cardRect(g)
    local m = self:metrics()
    local gy = m.headerH + T.pad + math.floor((g.y or 0) + 0.5) - self.scroll
    return {T.pad, gy, COLS * T.cell + 1, m.barH + g.rows * T.cell + 1}
end

--- The group whose card is at mx, my (a thing held over it goes into its container).
function W:groupAt(mx, my)
    if my <= self:metrics().headerH then return nil end
    for _, g in ipairs(self.groups) do
        if not g.gone and T.inRect(mx, my, self:cardRect(g)) then return g end
    end
    return nil
end

--- Things around to take (not on the character already, not being moved).
function W:aroundTiles()
    local out = {}
    for _, g in ipairs(self.groups) do
        if not g.src.mine and not g.gone then
            for _, e in ipairs(g.tiles) do
                if not e.ghost then table.insert(out, e) end
            end
        end
    end
    return out
end
-- Drawing ----------------------------------------------------------------------------

local function drawTile(ui, e, r, hover, a)
    a = a or 1
    local item = e.item
    -- being moved: faded, with the move's progress over it (as the grids show it)
    if e.ghost then a = a * 0.4 end
    local picked = not e.ghost and KnoxSelect.isSelected(e)
    T.rect(ui, r[1], r[2], r[3], r[4], T.category[T.categoryOf(item)], a)
    local c = T.color.accent
    -- (every tile here has a sand frame - it was found; a picked one is lit
    -- and framed in white over it)
    ui:drawRect(r[1], r[2], r[3], r[4], (picked and 0.22 or 0.08) * a, c.r, c.g, c.b)
    if hover then ui:drawRect(r[1], r[2], r[3], r[4], 0.06 * a, 1, 1, 1) end
    local side = math.floor(math.min(r[3], r[4]) * 0.85)
    ISInventoryItem.renderItemIcon(ui, item, r[1] + math.floor((r[3] - side) / 2), r[2] + math.floor((r[4] - side) / 2), a, side, side)
    T.tileFrame(ui, r[1], r[2], r[3], r[4], (hover or picked) and T.color.bright or c, a)
    if #e.items > 1 then
        T.outlinedRight(ui, tostring(#e.items), r[1] + r[3] - 4, r[2] + r[4] - T.fontTileH - 3, T.color.bright, T.fontTile, a)
    end
    if e.ghost then
        local _, p = KnoxGrid.pendingOf(e.item)
        if p then T.progress(ui, r[1], r[2], r[3], r[4], p) end
    end
end
function W:prerender()
    local q = KnoxGridView.query()
    -- the search emptied: it folds back into its button
    if not q and not self.foldMs then self:close() end
    local br = self.screen.foundRect and self.screen:foundRect()
    local sx = br and (self.screen:getAbsoluteX() + br[1])
    local sy = br and (self.screen:getAbsoluteY() + br[2])
    if self.foldMs then
        T.unfold(self, sx, sy, br and br[3], br and br[4])
        return
    end
    if q ~= self.query or getTimestampMs() - self.builtMs > REBUILD_MS then self:rebuild() end
    self:animate()
    -- it unfolds out of its button on the top bar
    if T.unfold(self, sx, sy, br and br[3], br and br[4]) then return end

    local m = self:metrics()
    local w, h = self:getWidth(), self:getHeight()
    local ft = T.fontH(T.fontText)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, m.headerH, T.color.header)
    T.rect(self, 0, m.headerH, w, 1, T.color.border)
    T.tileFrame(self, 0, 0, w, h, T.color.accent)

    -- header: the title with what is searched, how much is found (a plate as
    -- the surroundings' list has), Take all, close
    local cr = self:closeRect()
    local tr, takeText = self:takeRect()
    local canTake = #self:aroundTiles() > 0
    local takeHot = over and T.inRect(mx, my, tr) and canTake
    T.button(self, tr, "", {hover = takeHot, disabled = not canTake})
    if takeHot then T.tileFrame(self, tr[1], tr[2], tr[3], tr[4], T.color.accent) end   -- (sand frames are 2 px)
    local tc = takeHot and T.color.accent or T.color.text
    T.inkCentre(self, takeText, tr[1], tr[2], tr[3], tr[4], tc.r, tc.g, tc.b, canTake and 1 or 0.3, T.fontCaps)
    T.closeButton(self, cr[1], cr[2], cr[3], over and T.inRect(mx, my, cr))
    self.totalPlate = self.totalPlate or {}
    -- (a pixel inside the buttons' height above and below: a solid plate looks
    -- taller than a framed button of the same size)
    local px = T.countPlate(self, self.totalPlate, tostring(self.total), tr[1] - T.barMargin(m.headH), m.frame, m.headH, self.total > 0, 1)
    local title = T.upper(getText("IGUI_Knox_FoundTitle", self.screen.searchBox and self.screen.searchBox:getText() or ""))
    -- (from where the groups' names start)
    -- (in the header's band under the frame, in the tabs' bigger capitals)
    T.inkLeft(self, T.fit(title, T.fontTab, px - T.pad - 8 - 12), T.pad + 8, m.frame, m.headH, T.color.text, T.fontTab)
    -- the groups, clipped to the body
    local bodyY = m.headerH + 1
    self:setStencilRect(0, bodyY, w, h - bodyY)
    self.hoverTile = nil
    if self.total == 0 and #self.groups == 0 then
        T.textCentre(self, getText("IGUI_Knox_FoundNone"), math.floor(w / 2), bodyY + T.pad + math.floor((T.cell - ft) / 2), T.color.dim, T.fontText)
    end
    local now = getTimestampMs()
    for _, g in ipairs(self.groups) do
        local ga = g.a or 1
        ga = ga * ga * (3 - 2 * ga)
        local gy = m.headerH + T.pad + math.floor(g.y + 0.5) - self.scroll
        local gx, gw = T.pad, COLS * T.cell + 1
        local gh = m.barH + g.rows * T.cell + 1
        -- each container a card of its own: a title bar (its name, its count
        -- on a plate) over a grid of cells, framed, a gap to the next one
        T.rect(self, gx, gy, gw, m.barH, T.color.header, ga)
        T.rect(self, gx, gy + m.barH - 1, gw, 1, T.color.border, ga)
        g.plate = g.plate or {}
        local px = T.countPlate(self, g.plate, tostring(g.n), self:rightEdge(), gy, m.barH, true, nil, ga)
        local name = T.upper(g.src.name or "?")
        if g.src.mine then name = name .. "  " .. T.upper(getText("IGUI_Knox_FoundMine")) end
        -- (the character's own containers in sand: name and card frame - the author's wish, 2026-10-15)
        T.inkLeft(self, T.fit(name, T.fontCaps, px - gx - 16), gx + 8, gy, m.barH, g.src.mine and T.color.accent or T.color.text, T.fontCaps, ga)
        -- the cells, lined as a grid is
        local ay = gy + m.barH
        T.rect(self, gx, ay, gw, g.rows * T.cell + 1, T.color.cell, T.gridAlpha() * ga)
        local line, la = T.color.line, T.gridLineAlpha() * ga
        for i = 0, COLS do self:drawRect(gx + i * T.cell, ay, 1, g.rows * T.cell + 1, la, line.r, line.g, line.b) end
        for j = 0, g.rows do self:drawRect(gx, ay + j * T.cell, gw, 1, la, line.r, line.g, line.b) end
        for _, e in ipairs(g.tiles) do
            local r = self:tileRect(g, e)
            local ta = ga
            -- just come: it drops into its cell from a little above, fading in
            local came = g.arrive and g.arrive[e.item]
            if came then
                local t = T.anim(math.min(1, (now - came) / SETTLE_MS))
                if t >= 1 then
                    g.arrive[e.item] = nil
                else
                    local k = (1 - t) * (1 - t)
                    r[2] = r[2] - math.floor(T.cell * 0.22 * k + 0.5)
                    ta = ta * (0.35 + 0.65 * t)
                end
            end
            local hover = not g.gone and not e.ghost and over and my > bodyY and T.inRect(mx, my, r) and not KnoxDrag.isActive()
            if hover then self.hoverTile, self.hoverMine = e, g.src.mine end
            drawTile(self, e, r, hover, ta)
        end
        -- gone from it: fading out where it lay
        local stay = {}
        for _, l in ipairs(g.leaving or {}) do
            local t = T.anim(math.min(1, (now - l.ms) / FADE_MS))
            if t < 1 then
                local k = (1 - t) * (1 - t)
                drawTile(self, l.e, self:tileRect(g, l.e), false, ga * k)
                table.insert(stay, l)
            end
        end
        g.leaving = stay
        if g.src.mine then
            T.tileFrame(self, gx, gy, gw, gh, T.color.accent, ga)
        else
            T.border(self, gx, gy, gw, gh, T.color.tileEdge, ga)
        end
        -- a thing held over the card: let go, it goes into that container
        -- (green: it may, red: it may not - no room, a bag into a bag...)
        if KnoxDrag.isActive() and not g.gone and over and T.inRect(mx, my, {gx, gy, gw, gh}) then
            local dc = KnoxDrag.canDropInto(g.container, self:player()) and T.color.ok or T.color.bad
            self:drawRect(gx, gy, gw, gh, 0.16, dc.r, dc.g, dc.b)
            T.tileFrame(self, gx, gy, gw, gh, dc)
        end
    end
    -- the selection frame being drawn
    local b = self.band
    if b and b.active and b.x1 then
        local c = T.color.accent
        local x0, y0 = math.min(b.x0, b.x1), math.min(b.y0, b.y1)
        local bw, bh = math.abs(b.x1 - b.x0), math.abs(b.y1 - b.y0)
        self:drawRect(x0, y0, bw, bh, 0.10, c.r, c.g, c.b)
        self:drawRectBorder(x0, y0, bw, bh, 0.9, c.r, c.g, c.b)
    end
    self:clearStencilRect()
    if self.hoverTile and not (b and b.active) then KnoxTooltip.want(self.hoverTile.item, self.playerNum) end
end

-- Selection, as in the grids: Ctrl+click picks a tile, a frame drawn from an
-- empty place picks every tile it touches (with Ctrl: adds to what is picked).
-- The picked things are KnoxSelect's, the same as the grids' (asked for by the
-- author, 2026-10-15).

local BAND_START_PX = 5

--- The window's tiles that are picked, as {e, g}.
function W:picked()
    local out = {}
    for _, g in ipairs(self.groups) do
        if not g.gone then
            for _, e in ipairs(g.tiles) do
                if not e.ghost and KnoxSelect.isSelected(e) then table.insert(out, {e = e, g = g}) end
            end
        end
    end
    return out
end

function W:updateBand()
    local b = self.band
    if not b then return end
    if not isMouseButtonDown(0) then
        self.band = nil
        return
    end
    if not b.active then
        if math.abs(getMouseX() - b.mx) + math.abs(getMouseY() - b.my) < BAND_START_PX then return end
        b.active = true
    end
    local m = self:metrics()
    b.x1 = math.max(0, math.min(self:getWidth(), self:getMouseX()))
    b.y1 = math.max(m.headerH, math.min(self:getHeight(), self:getMouseY()))
    local x0, x1 = math.min(b.x0, b.x1), math.max(b.x0, b.x1)
    local y0, y1 = math.min(b.y0, b.y1), math.max(b.y0, b.y1)
    local sel = {}
    for it in pairs(b.base) do sel[it] = true end
    for _, g in ipairs(self.groups) do
        if not g.gone then
            for _, e in ipairs(g.tiles) do
                if not e.ghost then
                    local r = self:tileRect(g, e)
                    if r[1] < x1 and r[1] + r[3] > x0 and r[2] < y1 and r[2] + r[4] > y0 then
                        for _, it in ipairs(e.items) do sel[it] = true end
                    end
                end
            end
        end
    end
    KnoxSelect.items = sel
end

-- Mouse -------------------------------------------------------------------------------

function W:onMouseDown(x, y)
    if self.foldMs then return true end
    local m = self:metrics()
    if T.inRect(x, y, self:closeRect()) then
        self:close()
        return true
    end
    local tr = self:takeRect()
    if T.inRect(x, y, tr) then
        local tiles = self:aroundTiles()
        if #tiles > 0 then
            getSoundManager():playUISound("UIActivateButton")
            KnoxActions.moveTiles(tiles, KnoxActions.playerViews(), self:player())
            self.builtMs = 0
        end
        return true
    end
    local e, g = self:tileAt(x, y)
    if e then
        self.press = {e = e, g = g, x = getMouseX(), y = getMouseY(), mods = KnoxControls.mods()}
        return true
    end
    if y < m.headerH then
        KnoxWindowDrag.begin(self, x, y, m.headerH)
        return true
    end
    -- an empty place: a click drops what is picked, a drag draws a frame (with Ctrl it adds)
    local ctrl = isKeyDown(Keyboard.KEY_LCONTROL) or isKeyDown(Keyboard.KEY_RCONTROL)
    if not ctrl then KnoxSelect.clear() end
    local base = {}
    for it in pairs(KnoxSelect.items) do base[it] = true end
    self.band = {x0 = x, y0 = y, mx = getMouseX(), my = getMouseY(), base = base, active = false}
    return true
end

--- A tile of the window, as a tile from nowhere in particular (it lies in its
--- own container, which may not be shown: no faded copy is left there).
local function asPart(e)
    return {item = e.item, items = e.items, w = e.w, h = e.h, r = e.r, part = true}
end

function W:onMouseMove(dx, dy)
    KnoxWindowDrag.update(self)   -- (moved by its header)
    if self.band then
        self:updateBand()
        return
    end
    local p = self.press
    if not p or KnoxDrag.isActive() then return end
    if not isMouseButtonDown(0) then
        self.press = nil
        return
    end
    if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) < DRAG_START_PX then return end
    self.press = nil
    local part = asPart(p.e)
    local w, h = KnoxGrid.dims(part, part.r)
    -- a picked tile takes the rest of what is picked here along
    local extras = {}
    if KnoxSelect.isSelected(p.e) then
        for _, s in ipairs(self:picked()) do
            if s.e.item ~= p.e.item then table.insert(extras, {entity = asPart(s.e)}) end
        end
    end
    KnoxDrag.start(part, nil, math.floor((w - 1) / 2), math.floor((h - 1) / 2), extras)
end

function W:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function W:onMouseUpOutside(x, y)
    KnoxWindowDrag.stop(self)
    self.press = nil
    self.band = nil
end

function W:onMouseUp(x, y)
    KnoxWindowDrag.stop(self)
    if self.band then
        self.band = nil
        return true
    end
    if KnoxDrag.isActive() then
        -- let go over a card: into that card's container, at its first free place
        -- (or onto a stack of its kind there); anywhere else in the window: nothing
        local g = self:groupAt(x, y)
        if g then
            KnoxDrag.dropInto(g.container, self:player())
            for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
            self.builtMs = 0
        end
        return true
    end
    local p = self.press
    self.press = nil
    if not p then return true end
    local player = self:player()
    local now = getTimestampMs()
    local act = KnoxControls.actionFor("mouse", p.mods .. "lmb")
    if self.lastClick and self.lastClick.e == p.e.item and now - self.lastClick.ms < DOUBLE_CLICK_MS then
        act = KnoxControls.actionFor("mouse", p.mods .. "lmb2") or act
        self.lastClick = nil
    else
        self.lastClick = {e = p.e.item, ms = now}
    end
    if act == "select" then
        KnoxSelect.toggle(p.e)
    elseif act == "quickMove" then
        -- to the other side: what is around into the character's bags, the
        -- character's own into the container open in the surroundings (a
        -- picked tile: everything picked here, each to its other side)
        local list = KnoxSelect.isSelected(p.e) and self:picked() or {{e = p.e, g = p.g}}
        local around, mine = {}, {}
        for _, s in ipairs(list) do table.insert(s.g.src.mine and mine or around, s.e) end
        if #around > 0 then KnoxActions.moveTiles(around, KnoxActions.playerViews(), player) end
        if #mine > 0 then KnoxActions.moveTiles(mine, KnoxActions.lootViews(), player) end
        KnoxSelect.clear()
        self.builtMs = 0
    elseif act == "open" then
        if instanceof(p.e.item, "InventoryContainer") and p.e.item:getInventory() then
            KnoxContainerWindow.toggle(p.e.item, self.playerNum)
        else
            local page = getPlayerInventory(self.playerNum)
            if page and page.inventoryPane then page.inventoryPane:doContextualDblClick(p.e.item) end
        end
    elseif act == "inspect" then
        KnoxInspectWindow.open(p.e.item, self.playerNum)
    end
    return true
end

function W:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end
    local e, g = self:tileAt(x, y)
    if not e then return true end
    local player = self:player()
    local list = e.items
    local entry = list[1]
    if #list > 1 then
        -- a stack as the game's own list gives it: one entry, its first thing twice
        local group = {list[1]}
        for _, it in ipairs(list) do table.insert(group, it) end
        entry = {items = group, count = #list, name = list[1]:getName(), cat = list[1]:getDisplayCategory() or list[1]:getCategory()}
    end
    if KnoxContextMenu then KnoxContextMenu.setTarget(list, self.playerNum) end
    ISInventoryPaneContextMenu.createMenu(self.playerNum, g.container:isInCharacterInventory(player) or g.container == player:getInventory(),
        {entry}, getMouseX(), getMouseY())
    return true
end

function W:onMouseWheel(del)
    local m = self:metrics()
    local view = self:getHeight() - m.headerH - T.pad
    self.scroll = math.max(0, math.min(self.scroll + del * T.cell, math.max(0, self.contentH - view)))
    return true
end

-- Life ------------------------------------------------------------------------------------

function W:close()
    if W.instance == self then W.instance = nil end
    T.fold(self, function(w)
        w:setVisible(false)
        w.screen:removeChild(w)
    end)
end

--- Open the window under the button, or close it when it is open.
function W.toggle(screen)
    if W.instance then
        W.instance:close()
        return
    end
    if not KnoxGridView.query() then return end
    local w = W:new(screen, screen.playerNum)
    w:initialise()
    w:instantiate()
    local br = screen:foundRect()
    w:setX(math.max(8, math.min(br[1], screen:getWidth() - w:metrics().w - 8)))
    w:setY(screen.topH + 8)
    w:rebuild()
    -- (opening: everything there at once - the window itself unfolds)
    for _, g in ipairs(w.groups) do g.a, g.arrive = 1, {} end
    w:animate()
    screen:addChild(w)
    w.openedMs = getTimestampMs()
    W.instance = w
end

return KnoxFoundWindow
