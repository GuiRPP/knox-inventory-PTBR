-- One container drawn as a grid of cells with item tiles.

require "ISUI/ISUIElement"
require "ISUI/ISInventoryItem"
require "ISUI/ISToolTipInv"
require "ISUI/ISInventoryPaneContextMenu"
require "Knox/KnoxTheme"
require "Knox/KnoxGrid"
require "Knox/KnoxDrag"
require "Knox/KnoxReasonIcons"
require "Knox/KnoxTooltip"
require "Knox/KnoxSelect"
require "Knox/KnoxActions"
require "Knox/KnoxControls"

KnoxGridView = ISUIElement:derive("KnoxGridView")

local T = KnoxTheme
local DRAG_START_PX = 5
local DOUBLE_CLICK_MS = 350

function KnoxGridView:new(x, y, container, playerNum)
    local o = ISUIElement:new(x, y, 1, 1)
    setmetatable(o, self)
    self.__index = self
    o.container = container
    o.playerNum = playerNum
    o.layout = nil
    o.dirty = true
    o.press = nil
    o.lastClickMs = 0
    o.lastClickEntity = nil
    o:rebuild()
    return o
end

function KnoxGridView:player()
    return getSpecificPlayer(self.playerNum)
end

function KnoxGridView:markDirty()
    self.dirty = true
end

-- (a tile's settling is cleared when it is drawn done; one never drawn again -
-- its grid closed, out of sight - was kept for the rest of the game)
local settlePruneMs = 0
local function pruneSettle(now)
    if now - settlePruneMs < 2000 then return end
    settlePruneMs = now
    for item, ms in pairs(KnoxGridView.settle) do
        if now - ms > 1000 then KnoxGridView.settle[item] = nil end
    end
end

function KnoxGridView:rebuild()
    local before = self.layout
    self.layout = KnoxGrid.build(self.container, self:player())
    self.dirty = false
    -- a tile that has come to a new place (dropped, arrived, re-packed) settles
    -- into it for a moment instead of just being there: see drawTile
    local was = self.places
    local places = {}
    local now = getTimestampMs()
    pruneSettle(now)
    for _, e in ipairs(self.layout.placed) do
        if not e.ghost and not e.reserved then
            local key = e.x .. "," .. e.y .. "," .. (e.r or 0)
            places[e.item] = key
            if was and before and was[e.item] ~= key then KnoxGridView.settle[e.item] = now end
        end
    end
    self.places = places
    -- ...and one that is gone from the grid (taken, used up; the faded copy of
    -- a thing whose move has ended) doesn't just vanish: it fades out where it was
    local shown = {}
    for _, e in ipairs(self.layout.placed) do
        if not e.reserved then
            shown[e.item] = {item = e.item, items = {e.item}, x = e.x, y = e.y, r = e.r, w = e.w, h = e.h,
                             ghost = true, from = e.ghost and 0.4 or 1}
        end
    end
    if self.shown and before then
        self.leaving = self.leaving or {}
        for item, old in pairs(self.shown) do
            if not shown[item] and #self.leaving < 40 then
                old.ms = now
                table.insert(self.leaving, old)
            end
        end
    end
    self.shown = shown
    -- Things lying in a cupboard, a fridge or an oven don't age, thaw or cook
    -- on their own in the game's data: the game brings them up to date when
    -- its own inventory list looks at them (ISInventoryPane: updateAge,
    -- updateWetness). Ours does the same, or a tile showed the state the food
    -- was in when the container was opened.
    for _, e in ipairs(self.layout.placed) do
        if not e.ghost and not e.reserved then
            local first = e.item
            if instanceof(first, "Food") then
                for _, it in ipairs(e.items) do it:updateAge() end
            elseif instanceof(first, "Clothing") then
                first:updateWetness()
            end
        end
    end
    -- What the character has in its pockets, or sees in a container already
    -- looked into, is known: put down and opened again, it is not searched for
    -- (KnoxSearch). A bag on the character is not looked into by being on it:
    -- one picked up and put on without a look is searched in its section
    -- (it showed all at once: a player's remark, 2026-10-14). What the
    -- character packed into it itself was known before it went in.
    if KnoxSearch then
        local c, player = self.container, self:player()
        if player and c == player:getInventory() then
            KnoxSearch.markIn(c)   -- (these things only, not what is in a bag among them)
        elseif c:getType() == "floor" or (KnoxLootPanel and KnoxLootPanel.isSeen(c)) then
            for _, e in ipairs(self.layout.placed) do
                if not e.ghost and not e.reserved and not KnoxSearch.isHidden(e.item) then
                    for _, it in ipairs(e.items) do
                        if not KnoxSearch.known[it] then KnoxSearch.markKnown(it) end
                    end
                end
            end
        end
    end
    -- the places of the player's layout waiting for their things (KnoxOrder)
    local okS, silh = pcall(KnoxOrder.silhouettes, self.layout)
    self.silhouettes = okS and silh or nil
    local W, H = self:pxSize()
    self:setWidth(W + 1)
    self:setHeight(H + 1)
end

-- Cells and pixels ------------------------------------------------------------
-- A grid is cells of T.cell pixels, row after row - but a bag with compartments
-- (KnoxBagShapes) has each compartment where its row puts it on screen, a narrow
-- gap between them, and the rows of what doesn't fit under them all. Everything
-- that turns a cell into pixels or back goes through these.

--- A bag's compartments, empty, at x,y of `ui` with cells `cs` pixels: each a
--- little grid of its own (the cells, their lines in the player's thickness) in a
--- frame. `clipH`: only that many pixels from the top (a section unrolling);
--- `strength`: how solid (0..1). Shared by the grid, the inventory column's
--- unrolling sections and the hero's bag in the camp (KnoxMenuBag).
function KnoxGridView.drawShape(ui, x, y, shape, cs, clipH, strength, cellAlpha)
    local g = KnoxBagShapes.geometry(shape, cs)
    strength = strength or 1
    cellAlpha = cellAlpha or T.gridAlpha() * strength
    local line, edge = T.color.line, T.color.tileEdge
    local lw, la = T.gridLine(), T.gridLineAlpha() * strength
    local lo = math.floor((lw - 1) / 2)
    local limit = clipH and (y + clipH) or nil
    if shape.free then
        -- drawn cell by cell (KnoxBagShapes.MASKS): each cell, its lines, and the
        -- compartment's frame along the sides where it ends
        local cols = shape.cols
        for yy = 0, shape.rows - 1 do
            for xx = 0, cols - 1 do
                local p = shape.mask[yy * cols + xx]
                if p then
                    local px, py = x + g.colX[xx], y + g.rowY[yy]
                    local ph = cs
                    if limit then ph = math.min(cs, limit - py) end
                    if ph > 0 then
                        T.rect(ui, px, py, cs, ph, T.color.cell, cellAlpha)
                        ui:drawRect(px - lo, py, lw, ph + 1, la, line.r, line.g, line.b)
                        ui:drawRect(px + cs - lo, py, lw, ph + 1, la, line.r, line.g, line.b)
                        ui:drawRect(px - lo, py - lo, cs + lw, lw, la, line.r, line.g, line.b)
                        if ph >= cs then ui:drawRect(px - lo, py + cs - lo, cs + lw, lw, la, line.r, line.g, line.b) end
                        local fa = 0.55 * strength
                        local function outside(nx, ny)
                            return nx < 0 or ny < 0 or nx >= cols or ny >= shape.rows or shape.mask[ny * cols + nx] ~= p
                        end
                        if outside(xx - 1, yy) then ui:drawRect(px - lo - 1, py - lo - 1, 1, ph + lw + 2, fa, edge.r, edge.g, edge.b) end
                        if outside(xx + 1, yy) then ui:drawRect(px + cs + lw - lo, py - lo - 1, 1, ph + lw + 2, fa, edge.r, edge.g, edge.b) end
                        if outside(xx, yy - 1) then ui:drawRect(px - lo - 1, py - lo - 1, cs + lw + 2, 1, fa, edge.r, edge.g, edge.b) end
                        if outside(xx, yy + 1) and ph >= cs then ui:drawRect(px - lo - 1, py + cs + lw - lo, cs + lw + 2, 1, fa, edge.r, edge.g, edge.b) end
                    end
                end
            end
        end
        return
    end
    for p, o in pairs(g.parts) do
        local px, py = x + o.x, y + o.y
        local pw, ph = p.w * cs, p.h * cs
        if limit then ph = math.min(ph, limit - py) end
        if ph > 0 then
            T.rect(ui, px, py, pw, ph, T.color.cell, cellAlpha)
            for i = 0, p.w do ui:drawRect(px + i * cs - lo, py, lw, ph + 1, la, line.r, line.g, line.b) end
            for j = 0, p.h do
                if j * cs <= ph then ui:drawRect(px - lo, py + j * cs - lo, pw + lw, lw, la, line.r, line.g, line.b) end
            end
            -- the compartment's own frame: it reads as a pouch of its own. Right
            -- outside its outer lines on all four sides (each outer line plus the
            -- frame: as thick on the right and bottom as on the left and top)
            ui:drawRectBorder(px - lo - 1, py - lo - 1, pw + lw + 2, ph + lw + 2, 0.55 * strength, edge.r, edge.g, edge.b)
        end
    end
end

--- The rows of what didn't fit (x, y, w, h: from line to line): a red tint and a
--- red frame 2 px thick on all four sides, inside its lines.
function KnoxGridView.drawOverflow(ui, x, y, w, h, a)
    local bad = T.color.bad
    ui:drawRect(x, y, w, h, 0.10 * a, bad.r, bad.g, bad.b)
    ui:drawRectBorder(x, y, w + 1, h + 1, 0.9 * a, bad.r, bad.g, bad.b)
    ui:drawRectBorder(x + 1, y + 1, w - 1, h - 1, 0.9 * a, bad.r, bad.g, bad.b)
end

--- The bag's compartments on screen (KnoxBagShapes.geometry), or nil for one grid.
function KnoxGridView:geo()
    local shape = self.layout and self.layout.shape
    return shape and KnoxBagShapes.geometry(shape, T.cell) or nil
end

--- The grid's size in pixels (without the closing line).
function KnoxGridView:pxSize()
    local cs, L = T.cell, self.layout
    local g = self:geo()
    if not g then return L.cols * cs, L.rows * cs end
    local over = L.rows - (L.baseRows or L.rows)
    return math.max(g.w, g.ovW), (over > 0 and (g.ovY + over * cs) or g.h)
end

--- Top-left pixel of cell x,y (nil between a bag's compartments).
function KnoxGridView:cellPx(x, y)
    local cs, L = T.cell, self.layout
    if not L.shape then return x * cs, y * cs end
    return KnoxBagShapes.cellPx(L.shape, cs, x, y, L.baseRows or L.rows)
end

--- The rectangle a w x h block at x,y is drawn in: x, y, w, h (inside its lines),
--- or nil when its corner is between compartments.
function KnoxGridView:blockRect(x, y, w, h)
    local px, py = self:cellPx(x, y)
    if not px then return nil end
    local cs = T.cell
    return px + 1, py + 1, w * cs - 1, h * cs - 1
end

--- The rectangle of a tile.
function KnoxGridView:tileRect(e)
    local w, h = KnoxGrid.dims(e, e.r)
    return self:blockRect(e.x, e.y, w, h)
end

--- The cell under pixel x,y of the grid, or nil (a gap between compartments).
function KnoxGridView:cellAtPx(mx, my)
    local cs, L = T.cell, self.layout
    local g = self:geo()
    if not g then return math.floor(mx / cs), math.floor(my / cs) end
    if my >= g.h then
        -- the rows under them (centred under the compartments, a gap above them)
        if my < g.ovY or mx < g.ovX or mx >= g.ovX + g.ovW then return nil end
        return math.floor((mx - g.ovX) / cs), (L.baseRows or L.rows) + math.floor((my - g.ovY) / cs)
    end
    return KnoxBagShapes.cellAtPx(L.shape, cs, mx, my)
end

--- A place of the layout whose thing is missing: the thing's picture, pale,
--- on a faint plate of its category, so the eye sees what is not there.
function KnoxGridView:drawSilhouette(en, a)
    a = a or 1
    local x, y, pw, ph = self:tileRect(en)
    if not x then return end
    T.rect(self, x, y, pw, ph, T.category[en.c or "misc"] or T.category.misc, 0.35 * a)
    T.border(self, x, y, pw, ph, T.color.tileEdge, 0.6 * a)
    local tex = en.tex and getTexture(en.tex)
    if tex then
        local side = math.floor(math.min(pw, ph) * 0.85)
        self:drawTextureScaledAspect(tex, x + math.floor((pw - side) / 2), y + math.floor((ph - side) / 2), side, side,
            0.22 * a, 0.85, 0.85, 0.85)
    end
end

function KnoxGridView:cellUnderMouse()
    local cx, cy = self:cellAtPx(self:getMouseX(), self:getMouseY())
    -- (in a gap between a bag's compartments: no cell - one far outside the grid)
    if not cx then return -100, -100 end
    return cx, cy
end

function KnoxGridView:entityUnderMouse()
    if not self:isMouseOver() then return nil end
    local cx, cy = self:cellUnderMouse()
    local e = self.layout:cellAt(cx, cy)
    if e and (e.ghost or e.reserved) then return nil end   -- a move in progress can't be grabbed
    if e and KnoxSearch and KnoxSearch.isHidden(e.item) then return nil end   -- not found yet
    return e, cx, cy
end

--- Top-left cell where the dragged tile would land.
function KnoxGridView:dropCell()
    local cx, cy = self:cellUnderMouse()
    return cx - KnoxDrag.grabX, cy - KnoxDrag.grabY
end

-- Updates -------------------------------------------------------------------

-- Taking an item in hand or putting clothes on doesn't change the container,
-- so the grid is also rebuilt every so often.
local REBUILD_MS = 250

function KnoxGridView:prerender()
    local now = getTimestampMs()
    -- the middle button has no event of its own: its press is looked for
    local mmb = isMouseButtonDown(2)
    if mmb and not self.mmbWas and self:isMouseOver() and not KnoxDrag.isActive() then
        local e = self:entityUnderMouse()
        local act = e and KnoxControls.actionFor("mouse", KnoxControls.mods() .. "mmb")
        if act then self:doAction(act, e) end
    end
    self.mmbWas = mmb
    -- A grid that takes long to build (a floor of hundreds of things, a big
    -- shelf) is built less often: a change waits a few of its build times, the
    -- look-over without a change waits 40 of them. Built every 250 ms whatever
    -- it cost, such grids took the game down to a few frames a second.
    local since = now - (self.builtMs or 0)
    local cost = self.buildCost or 0
    local changed = self.dirty or self.container:getItems():size() ~= self.layout.itemCount
        or self.epoch ~= KnoxGrid.pendingEpoch
    if (changed and since >= cost * 4) or since > math.max(REBUILD_MS, cost * 40) then
        self:rebuild()
        local done = getTimestampMs()
        self.buildCost = done - now
        self.profB = (self.profB or 0) + self.buildCost
        self.builtMs = done
        self.epoch = KnoxGrid.pendingEpoch
    end
end

-- Drawing -------------------------------------------------------------------

local function condColor(f)
    if f > 0.6 then return T.color.good end
    if f > 0.25 then return T.color.warn end
    return T.color.bad
end

-- Search by name (the field in the screen's top bar): what matches gets a sand
-- frame, the rest is dimmed; containers say how many things in them match.

--- The text searched for (lower case), or nil when nothing is.
function KnoxGridView.query()
    local q = KnoxScreen and KnoxScreen.instance and KnoxScreen.search
    if q == nil or q == "" then return nil end
    return q
end

--- Does the thing's name hold the text?
function KnoxGridView.hit(item, q)
    return string.find(T.lower(item:getDisplayName() or ""), q, 1, true) ~= nil
end

--- A tile matches when any of its things does (a stack of keys: one of them).
function KnoxGridView.entityHit(e, q)
    for _, it in ipairs(e.items) do
        if KnoxGridView.hit(it, q) then return true end
    end
    return false
end

-- How far each tile is lit up or dimmed by the search, 0..1, moving towards
-- what it should be over a moment - typing a letter more doesn't snap the
-- grids from one look to another. Kept by item; dropped once at rest with no
-- search on.
local fxOf = {}
local FX_MS = 160          -- time to come on or go off
local fxCount = 0

--- {hit, dim, flashMs} of a tile's thing; `on` = a search is on, `found` = it matches.
function KnoxGridView.searchFx(item, on, found)
    local st = fxOf[item]
    if not st and not on then return nil end   -- nothing searched, nothing going on: no state (and no clock asked, every tile every frame)
    local now = getTimestampMs()
    if not st then
        st = {hit = 0, dim = 0, ms = now}
        fxOf[item] = st
        fxCount = fxCount + 1
    end
    local wantHit = (on and found) and 1 or 0
    local wantDim = (on and not found) and 1 or 0
    local step = math.min(1, (now - st.ms) / FX_MS)
    st.ms = now
    if not T.animOn or T.animOn() then
        st.hit = st.hit + math.max(-step, math.min(step, wantHit - st.hit))
        st.dim = st.dim + math.max(-step, math.min(step, wantDim - st.dim))
    else
        st.hit, st.dim = wantHit, wantDim
    end
    -- (it has just begun to match: the frame flares once)
    if wantHit == 1 and not st.wasHit then st.flashMs = now end
    st.wasHit = wantHit == 1
    if not on and st.hit <= 0 and st.dim <= 0 then
        fxOf[item] = nil
        fxCount = fxCount - 1
        return nil
    end
    -- (a search typed over a huge base: the table is let go of now and then)
    if fxCount > 3000 and not on then fxOf, fxCount = {}, 0 end
    -- eased for the eye (kept on the state: no new table every frame)
    local h, d = st.hit, st.dim
    st.out = st.out or {}
    st.out.hit, st.out.dim, st.out.flashMs = h * h * (3 - 2 * h), d * d * (3 - 2 * d), st.flashMs
    return st.out
end

-- (counted a few times a second, not every frame: a shop has hundreds of things)
local countCache, countQ = {}, nil
local COUNT_MS = 300

--- How many things in the container (and in bags inside it) match - not
--- counting what a search has not found yet.
function KnoxGridView.countIn(container, q)
    if not container or not q then return 0 end
    -- (another text: the counts of the last one go - kept, they held every
    -- container looked at during any search of the game)
    if q ~= countQ then countCache, countQ = {}, q end
    local now = getTimestampMs()
    local c = countCache[container]
    if c and c.q == q and now - c.ms < COUNT_MS then return c.n end
    local n = 0
    local function walk(inv, depth)
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if not (KnoxSearch and KnoxSearch.unseen(it)) then
                if KnoxGridView.hit(it, q) then n = n + 1 end
                if depth < 3 and instanceof(it, "InventoryContainer") and it:getInventory() then walk(it:getInventory(), depth + 1) end
            end
        end
    end
    walk(container, 1)
    countCache[container] = {q = q, ms = now, n = n}
    return n
end

-- A stack just split off lights up for a few seconds, so it's clear where it went.
local FLASH_MS = 5000
KnoxGridView.flash = {}   -- item -> time it stops
KnoxGridView.settle = {}  -- item -> time it came to its place
KnoxGridView.fresh = {}   -- item -> true: come since the screen was last open, not looked at yet
KnoxGridView.lastClicks = {}   -- container -> {ms, mods, type}: the last click on a tile there
local SETTLE_MS = 160

function KnoxGridView.flashItems(items)
    local now = getTimestampMs()
    local untilMs = now + FLASH_MS
    for it, stop in pairs(KnoxGridView.flash) do
        if stop <= now then KnoxGridView.flash[it] = nil end   -- ones never drawn again
    end
    for _, it in ipairs(items) do KnoxGridView.flash[it] = untilMs end
end

local function drawFlash(ui, e, x, y, w, h)
    local stop = KnoxGridView.flash[e.item]
    if not stop then return end
    local left = stop - getTimestampMs()
    if left <= 0 then
        for _, it in ipairs(e.items) do KnoxGridView.flash[it] = nil end
        return
    end
    -- quick pulses, fading out over the last second
    local fade = math.min(1, left / 1000)
    local p = 0.5 + 0.5 * math.sin(getTimestampMs() / 1000 * math.pi * 3)
    local c = T.color.accent
    ui:drawRect(x, y, w, h, (0.10 + 0.14 * p) * fade, c.r, c.g, c.b)
    T.tileFrame(ui, x, y, w, h, c, (0.55 + 0.45 * p) * fade)
end

--- Has the player read this book / magazine / map, or seen / heard this tape
--- or disc? (as the game's inventory list marks it)
local function checkDone(item, player)
    if item:IsLiterature() and ISInventoryPane.isLiteratureRead(nil, player, item) then return true end
    if item:getMediaData() and (item:hasBeenSeen(player) or item:hasBeenHeard(player)) then return true end
    return instanceof(item, "MapItem") and player:hasReadMap(item)
end

-- answers kept for a second: a bookshop shelf has hundreds of tiles
local doneCache, doneMs = {}, 0
local function isDone(item, player)
    if not player then return false end
    local now = getTimestampMs()
    if now - doneMs > 1000 then doneCache, doneMs = {}, now end
    local v = doneCache[item]
    if v == nil then
        v = checkDone(item, player)
        doneCache[item] = v
    end
    return v
end

-- The favorite's star: a smooth white picture (media/ui/knox_star.png, made by
-- tools\make_star.ps1) drawn in the skin's main colour - not the game's yellow
-- star, and not pixels (both turned down by the author, 2026-10-15).
local starTex = nil

--- A read / watched mark: the tile's top right corner folded down in sand,
--- like a dog-eared page (inside the 2 px frame, flat like the rest).
local function drawDone(ui, x, y, w, alpha)
    local d = math.max(8, math.floor(T.cell / 4))
    local c = T.color.accent
    local right, top = x + w - 2, y + 2
    for i = 0, d - 1 do
        local len = d - i                       -- rows get shorter: a triangle
        ui:drawRect(right - len, top + i, len, 1, 0.9 * alpha, c.r, c.g, c.b)
    end
end

--- What a tile shows that changes slowly - its category's color, cooking,
--- wear, uses or liquid, freshness, read, locked: asked of the game once per
--- grid build (a tile is a new table each build) instead of every frame. A
--- floor of 270 things drew ~60 tiles with some 30 calls into the game each,
--- every frame: 180 FPS fell to 130 (the author's test, 2026-10-15).
function KnoxGridView:tileInfo(e)
    local d = e.draw
    if d then return d end
    local item = e.item
    d = {}
    d.cat = T.category[T.categoryOf(item)]
    d.cookBase, d.cookBar, d.cookFrac = T.cookState(item)
    d.frozen = d.cookBar == T.COOK_BLUE
    d.heat, d.heatK = T.heatState(item)   -- a pot of water on the stove: red as it heats
    if instanceof(item, "HandWeapon") or (instanceof(item, "Clothing") and item:getConditionMax() > 0) then
        d.cond = item:getCondition() / math.max(1, item:getConditionMax())
    end
    d.broken = item:isBroken()
    if item:IsDrainable() and not d.broken then
        local sum = 0
        for _, it in ipairs(e.items) do sum = sum + it:getCurrentUsesFloat() end
        d.uses = sum / math.max(1, #e.items)
    else
        local fluid = item:getFluidContainer()
        if fluid and fluid:getCapacity() > 0 then d.fluid = fluid:getAmount() / fluid:getCapacity() end
    end
    -- the icon: as ISInventoryItem.renderItemIcon draws it (a thing with a liquid
    -- mask is drawn opaque, whatever the tile's fade)
    d.hasTex = item:getTex() ~= nil
    local wi = item:getWorldItem()
    local fc = item:getFluidContainer() or (instanceof(wi, "IsoWorldInventoryObject") and wi:getFluidContainer())
    d.iconOpaque = fc and (item:getTextureFluidMask() or item:getTextureColorMask()) and true or false
    d.mixed = not e.ghost and #e.items > 1 and #KnoxGridView.kindsOf(e) > 1
    d.done = isDone(item, self:player())
    -- the game's Favorite mark (its context menu): a star in the corner, as the
    -- game's own inventory shows it (it showed nothing: Sharp, 2026-10-15)
    d.fav = item:isFavorite() == true
    d.locked = not e.ghost and KnoxActions.isLocked(e)
    if instanceof(item, "Food") then
        if item:isRotten() then d.freshColor = T.color.bad
        elseif not item:isFresh() and item:getOffAgeMax() < 1000000000 then d.freshColor = T.color.warn end
    end
    e.draw = d
    return d
end

-- Stacks of the character's own that a thing could join -----------------------------
-- The mouse on a thing lying around (in the surroundings, a bag window, the
-- Found window) or a thing held: the character's stacks of its kind light up,
-- green while there is room in them, red when they are full (the author's
-- wish, 2026-10-15). Things that don't stack show nothing.

local probeMs, probeE = -1, nil

--- The tile whose kind is looked for this frame, or nil.
function KnoxGridView.probe()
    local now = getTimestampMs()
    if now == probeMs then return probeE end
    probeMs, probeE = now, nil
    local e = KnoxDrag.entity
    if not e then
        for _, v in ipairs(KnoxActions.lootViews()) do
            if v.hovered and v:getIsVisible() then e = v.hovered end
        end
        if not e then
            for _, v in ipairs(KnoxActions.windowViews()) do
                if v.hovered and v:getIsVisible() and not v:isMine() then e = v.hovered end
            end
        end
        local fw = KnoxFoundWindow and KnoxFoundWindow.instance
        if not e and fw and fw.hoverTile and not fw.hoverMine then e = fw.hoverTile end
    end
    if e and not e.ghost and KnoxGrid.isStackable(e.item) then probeE = e end
    return probeE
end

--- Does this grid lie on the character (pockets, a worn or carried bag)?
function KnoxGridView:isMine()
    local p = self:player()
    return p ~= nil and (self.container == p:getInventory() or self.container:isInCharacterInventory(p))
end

function KnoxGridView:drawStackHints(top, bottom)
    local probe = KnoxGridView.probe()
    if not probe or not self:isMine() then return end
    local ft = probe.item:getFullType()
    for _, e in ipairs(self.layout.placed) do
        if not e.ghost and not e.reserved and not e.overflow and e.item ~= probe.item and e.y < bottom
                and e.item:getFullType() == ft and KnoxGrid.isStackable(e.item) then
            local _, h = KnoxGrid.dims(e, e.r)
            local x, y, pw, ph = self:tileRect(e)
            if e.y + h > top and x then
                local room = KnoxActions.isLocked(e) and 0 or KnoxGrid.mergeRoom(probe, e)
                local c = room > 0 and T.color.ok or T.color.bad
                self:drawRect(x, y, pw, ph, 0.18, c.r, c.g, c.b)
                T.tileFrame(self, x, y, pw, ph, c)
            end
        end
    end
end

-- The tile under the mouse rises a little, with a small hop as the mouse comes
-- onto it, and settles back when it leaves (the author's wish, 2026-10-15).
-- item -> {k = 0..1 how far up, want, ms, hop = when it was hovered, view}
KnoxGridView.lift = {}
local lifts = KnoxGridView.lift
local LIFT_MS = 110      -- up or down
local HOP_MS = 200       -- the hop over the rise

function KnoxGridView:updateLift()
    local now = getTimestampMs()
    local animOn = not T.animOn or T.animOn()
    local h = self.hovered
    local hov = (animOn and h and not h.ghost and not KnoxDrag.isActive() and not (self.band and self.band.active)) and h.item or nil
    if hov then
        local st = lifts[hov]
        if not st then
            st = {k = 0, ms = now, view = self}
            lifts[hov] = st
        end
        if st.want ~= 1 then
            st.want = 1
            st.hop = now
        end
    end
    for item, st in pairs(lifts) do
        if st.view == self then
            if item ~= hov then st.want = 0 end
            local step = math.min(100, now - st.ms) / LIFT_MS
            st.ms = now
            if st.k < st.want then st.k = math.min(st.want, st.k + step) else st.k = math.max(st.want, st.k - step) end
            if st.k <= 0 and st.want == 0 then lifts[item] = nil end
        end
    end
end

--- How many pixels the tile of `item` is lifted right now (0: it lies flat).
function KnoxGridView.liftPx(item)
    local st = lifts[item]
    if not st then return 0 end
    -- (its grid is gone or hidden: nothing brings it down any more)
    if getTimestampMs() - st.ms > 300 then
        lifts[item] = nil
        return 0
    end
    local k = st.k * st.k * (3 - 2 * st.k)
    local hop = 0
    if st.want == 1 and st.hop then
        local t = (getTimestampMs() - st.hop) / HOP_MS
        if t < 1 then hop = 0.7 * math.sin(math.pi * t) end
    end
    return math.floor(math.max(2, T.cell * 0.05) * (k + hop) + 0.5)
end

--- Nothing is happening to this tile this frame (not hovered, picked, searched,
--- settling, flashing, in use, its window open...): the Java part may draw it
--- (knoxDrawTiles), exactly as drawTile would. Only Lua tables are looked at here.
function KnoxGridView:isQuiet(e)
    local item = e.item
    if self.hovered == e or lifts[item] then return false end
    if KnoxGridView.settle[item] or KnoxGridView.flash[item] or KnoxGridView.fresh[item] then return false end
    if KnoxGridView.query() or fxOf[item] then return false end
    if KnoxSearch and KnoxSearch.on() and KnoxSearch.stateOf(item) then return false end
    if KnoxDrag.entity and KnoxGridView.isDragged(e) then return false end
    if KnoxSelect.isSelected(e) then return false end
    if KnoxContextMenu and KnoxContextMenu.isTarget(item) then return false end
    if (KnoxContainerWindow and KnoxContainerWindow.isOpen(item)) or (KnoxInspectWindow and KnoxInspectWindow.isOpen(item))
        or (KnoxSplitDialog and KnoxSplitDialog.isOpen(item)) or (KnoxFluidWindow and KnoxFluidWindow.isOpen(item))
        or (KnoxFluidInfo and KnoxFluidInfo.isOpen(item)) or (KnoxAlarmWindow and KnoxAlarmWindow.isOpen(item)) then
        return false
    end
    if KnoxSlotPicker and KnoxSlotPicker.isOffered(item) then return false end
    if KnoxGrid.useOf(e.items) then return false end
    -- (a favorite's star, the heat tint and a frozen tile's blue frame are drawn
    -- here, not by the Java part: the frame showed only under the mouse - 2026-10-18)
    local d = self:tileInfo(e)
    if d.fav or d.heat or d.frozen then return false end
    return true
end

function KnoxGridView:drawTile(e, alpha)
    local cs = T.cell
    local x, y, pw, ph = self:tileRect(e)
    if not x then return end
    local item = e.item
    -- a container being searched: what is not found yet is not shown, what is
    -- being found is a plate filling up (see KnoxSearch)
    if KnoxSearch and not e.ghost then
        local st, frac = KnoxSearch.stateOf(item)
        if st == "current" then KnoxSearch.drawCurrent(self, x, y, pw, ph, frac) end
        if st then return end
    end
    -- just come to this place: it drops into it from a little above, fading in
    local came = KnoxGridView.settle[item]
    if came and not e.ghost then
        local t = T.anim((getTimestampMs() - came) / SETTLE_MS)
        if t < 0 then return end          -- (its turn hasn't come: a grid opening row by row)
        if t >= 1 then
            KnoxGridView.settle[item] = nil
        else
            local k = (1 - t) * (1 - t)
            y = y - math.floor(cs * 0.22 * k + 0.5)
            alpha = alpha * (0.35 + 0.65 * t)
        end
    end
    -- a search by name is on: what is not looked for dims, what is lights up
    -- (both over a moment, as the text is typed: see KnoxGridView.searchFx)
    local q = not e.ghost and KnoxGridView.query()
    local found = q and KnoxGridView.entityHit(e, q)
    local sfx = not e.ghost and KnoxGridView.searchFx(item, q ~= nil and q ~= false, found)
    if sfx then alpha = alpha * (1 - 0.78 * sfx.dim) end
    local hovered = self.hovered == e and not KnoxDrag.isActive()
    local d = self:tileInfo(e)
    -- lifted under the mouse: a soft shadow where it lies, the tile above it
    local lp = not e.ghost and KnoxGridView.liftPx(item) or 0
    if lp > 0 then
        self:drawRect(x + 2, y + 3, pw - 2, ph - 2, 0.35 * alpha, 0, 0, 0)
        y = y - lp
    end
    -- never above the grid's top edge: lifted or settling, a tile of the first row
    -- went over the bag's header (the author, 2026-10-19)
    if y < 0 then y = 0 end

    T.rect(self, x, y, pw, ph, d.cat, alpha)
    -- food: frozen, cooking, done, burning - the tile takes that color
    if d.cookBase then self:drawRect(x, y, pw, ph, 0.22 * alpha, d.cookBase.r, d.cookBase.g, d.cookBase.b) end
    -- hot (red) or cold (blue), stronger the further from room temperature
    if d.heat then self:drawRect(x, y, pw, ph, 0.6 * d.heatK * alpha, d.heat.r, d.heat.g, d.heat.b) end
    if d.cookBar then
        local fh = math.floor(ph * d.cookFrac + 0.5)
        if fh > 0 then
            local b = d.cookBar
            self:drawRect(x, y + ph - fh, pw, fh, 0.5 * alpha, b.r, b.g, b.b)
            self:drawRect(x, y + ph - fh, pw, math.min(2, fh), 0.95 * alpha, b.r, b.g, b.b)
        end
    end
    if hovered then self:drawRect(x, y, pw, ph, 0.06 * alpha, 1, 1, 1) end
    if e.ghost and not e.from then
        -- being moved (the faded copy where it was): a sand frame, not faded with
        -- it, so the eye finds what is on its way (the author's wish, 2026-10-15).
        -- (`from`: a tile fading out where a thing has just gone - not this)
        T.tileFrame(self, x, y, pw, ph, T.color.accent, 0.9)
    elseif not e.ghost and KnoxContextMenu and (KnoxContextMenu.isTarget(item)
            or (KnoxAlarmWindow and KnoxAlarmWindow.isOpen(item))) then
        KnoxContextMenu.drawTarget(self, x, y, pw, ph)   -- its context menu (or alarm window) is open
    elseif KnoxSelect.isSelected(e) and not e.ghost then
        T.border(self, x, y, pw, ph, T.color.accent, alpha)
        T.border(self, x + 1, y + 1, pw - 2, ph - 2, T.color.accent, alpha)
    elseif not e.ghost and ((KnoxContainerWindow and KnoxContainerWindow.isOpen(item))
            or (KnoxInspectWindow and KnoxInspectWindow.isOpen(item))
            or (KnoxSplitDialog and KnoxSplitDialog.isOpen(item))
            or (KnoxFluidWindow and KnoxFluidWindow.isOpen(item))
            or (KnoxFluidInfo and KnoxFluidInfo.isOpen(item))) then
        T.border(self, x, y, pw, ph, T.color.accent, alpha)   -- its bag, inspect, split or fluid window is open
    elseif e.overflow then
        T.tileFrame(self, x, y, pw, ph, T.color.bad, alpha)   -- doesn't fit the grid: take it out
    elseif d.frozen then
        T.tileFrame(self, x, y, pw, ph, hovered and T.FROZEN_HOVER or T.FROZEN_FRAME, alpha)
    else
        T.tileFrame(self, x, y, pw, ph, hovered and T.color.tileHover or T.color.tileFrame, alpha)
    end

    -- icon: square, centered in the tile (no name: it is in the tooltip)
    local f, fh = T.fontTile, T.fontTileH
    local side = math.floor(math.min(pw, ph) * 0.85)
    -- being moved: the thing trembles in its steady frame, as if being taken in
    -- hand - a small uneven shake of its own for each thing, so several moves
    -- don't shake in step (the author's wish, 2026-10-15)
    local jx, jy = 0, 0
    if e.ghost and not e.from and (not T.animOn or T.animOn()) then
        -- (a pixel at most, and only now and then: the first try, 2 px and fast,
        -- shook too hard - the author, 2026-10-15)
        local t = getTimestampMs() / 1000
        local seed = (e.x or 0) * 1.7 + (e.y or 0) * 2.3
        jx = math.floor(0.45 * math.sin(t * 19 + seed) + 0.35 * math.sin(t * 11 + seed * 2.1) + 0.5)
        jy = math.floor(0.4 * math.sin(t * 15 + seed * 1.3) + 0.3 * math.sin(t * 9 + seed * 0.7) + 0.5)
    end
    -- (what ISInventoryItem.renderItemIcon does, with its questions to the game asked once: tileInfo)
    if d.hasTex then
        local ix, iy = x + math.floor((pw - side) / 2) + jx, y + math.floor((ph - side) / 2) + jy
        if d.iconOpaque and e.from then
            -- fading out where it has just gone from: a thing with a liquid mask
            -- (a water bottle) can't be drawn faded with its liquid, and stood
            -- whole on a vanishing tile - a bare icon left behind for a moment
            -- (the author's test, 2026-10-15). Its plain picture fades with the tile.
            self:drawTextureScaledAspect(item:getTex(), ix, iy, side, side, alpha, 1, 1, 1)
        else
            self.javaObject:DrawItemIcon(item, ix, iy, d.iconOpaque and 1.0 or alpha, side, side)
        end
    end

    -- thin meters at the bottom (the exact values are in the tooltip):
    -- condition (things that wear out) lowest, uses left or liquid above it;
    -- a stack's count as outlined text in the corner, like Tarkov
    local level = 0
    if d.cond then
        T.tileMeter(self, x, y, pw, ph, d.cond, condColor(d.cond), alpha, 0)
        level = 1
    end
    if d.uses then
        -- a stack of batteries, tape...: what is left in all of them together
        T.tileMeter(self, x, y, pw, ph, d.uses, T.color.accent, alpha, level)
    elseif d.fluid then
        T.tileMeter(self, x, y, pw, ph, d.fluid, T.color.liquid, alpha, level)
    end
    if d.broken then
        T.outlinedRight(self, "0%", x + pw - 4, y + ph - fh - 3, T.color.bad, f, alpha)
    elseif #e.items > 1 then
        -- (in sand: not all alike - the mouse on it shows them one by one)
        T.outlinedRight(self, tostring(#e.items), x + pw - 4, y + ph - fh - 3, d.mixed and T.color.accent or T.color.bright, f, alpha)
    end


    -- read / watched already
    if d.done then drawDone(self, x, y, pw, alpha) end
    -- the game's favorite: a star in the top right corner (left of the read mark),
    -- drawn as the padlock is - pixels of the skin's main colour, not the game's
    -- yellow picture (the author, 2026-10-15)
    if d.fav then
        starTex = starTex or getTexture("media/ui/knox_star.png")
        if starTex then
            local s = math.max(12, math.floor(cs * 0.27))
            local sx = x + pw - s - 4 - (d.done and math.max(8, math.floor(cs / 4)) or 0)
            local c = T.color.accent
            self:drawTextureScaledAspect(starTex, sx, y + 4, s, s, alpha, c.r, c.g, c.b)
        end
    end
    -- come since the screen was last open and not looked at yet: a sand dot in
    -- the bottom left corner, until the mouse has been on the tile
    if not e.ghost and KnoxGridView.fresh[item] then
        local c = T.color.accent
        local d = math.max(6, math.floor(cs / 7))
        self:drawRect(x + 4, y + ph - d - 6, d, d, alpha, c.r, c.g, c.b)
    end
    -- locked: a small sand padlock in the top left corner
    if d.locked then
        local c = T.color.accent
        local u = math.max(2, math.floor(cs / 22 + 0.5))
        local lx, ly = x + 4, y + 4
        self:drawRect(lx + u, ly, u * 3, u, alpha, c.r, c.g, c.b)
        self:drawRect(lx + u, ly, u, u * 2, alpha, c.r, c.g, c.b)
        self:drawRect(lx + u * 3, ly, u, u * 2, alpha, c.r, c.g, c.b)
        self:drawRect(lx, ly + u * 2, u * 5, u * 3, alpha, c.r, c.g, c.b)
    end

    -- looked for by name: a warm sand light over the tile and a sand frame,
    -- coming on smoothly; the moment it starts to match, the frame flares once
    if sfx and sfx.hit > 0.01 then
        local c = T.color.accent
        local h = sfx.hit
        self:drawRect(x, y, pw, ph, 0.10 * h * alpha, c.r, c.g, c.b)
        T.tileFrame(self, x, y, pw, ph, c, h * alpha)
        local fl = sfx.flashMs and (getTimestampMs() - sfx.flashMs) / 450 or 1
        if fl < 1 then
            local k = (1 - fl) * (1 - fl)
            -- (a second, brighter frame inside the first, and a light wash, fading)
            T.border(self, x + 2, y + 2, pw - 4, ph - 4, T.color.bright, 0.8 * k * alpha)
            self:drawRect(x, y, pw, ph, 0.16 * k * alpha, c.r, c.g, c.b)
        end
    end
    -- offered by the quick pick panel of a hovered empty slot
    if not e.ghost and KnoxSlotPicker and KnoxSlotPicker.isOffered(item) then T.target(self, x, y, pw, ph, KnoxSlotPicker.offerColor) end
    if not e.ghost then drawFlash(self, e, x, y, pw, ph) end

    -- an action using the item (eating, bandaging, reading...): fills up like a move
    if not e.ghost then
        local use = KnoxGrid.useOf(e.items)
        if use then T.inUse(self, x, y, pw, ph, use) end
    end

    -- food freshness dot
    local fc = d.freshColor
    if fc then
        local s = math.max(4, math.floor(cs / 10))
        self:drawRect(x + 3, y + 3, s, s, alpha, fc.r, fc.g, fc.b)
    end
end

--- The grid's rows that are on the screen and inside the element holding it:
--- first row, the row after the last.
function KnoxGridView:visibleRows()
    -- (a bag with compartments: a few dozen cells - all of it; its rows on screen
    -- don't follow its cells' rows)
    if self.layout and self.layout.shape then return 0, self.layout.rows end
    local cs = T.cell
    local ay = self:getAbsoluteY()
    local y0, y1 = 0, getCore():getScreenHeight()
    local holder = self.parent
    if holder then
        local py = holder:getAbsoluteY()
        y0, y1 = math.max(y0, py), math.min(y1, py + holder:getHeight())
    end
    return math.floor((y0 - ay) / cs), math.ceil((y1 - ay) / cs)
end

--- The dark laid over a grid the dragged thing has no place in at all (set by
--- KnoxInventoryPanel:drawNoRoom): on its own cells and compartments, lines and
--- frames - not a box from the column's edge, which missed a bag's side pockets
--- and darkened the empty room beside a narrow grid (the author, 2026-10-20).
function KnoxGridView:drawNoRoomMask()
    local cs, L = T.cell, self.layout
    local function dim(x, y, w, h) self:drawRect(x, y, w, h, 0.55, 0.03, 0.03, 0.03) end
    local g = self:geo()
    if not g then
        local w, h = self:pxSize()
        dim(-1, -1, w + 3, h + 3)
        return
    end
    local shape = L.shape
    if shape.free then
        -- cell by cell, each with its line on the left and top; the compartment's
        -- last line and frame on its right and bottom
        local cols = shape.cols
        for yy = 0, shape.rows - 1 do
            for xx = 0, cols - 1 do
                local p = shape.mask[yy * cols + xx]
                if p then
                    local right = xx + 1 >= cols or shape.mask[yy * cols + xx + 1] ~= p
                    local below = yy + 1 >= shape.rows or shape.mask[(yy + 1) * cols + xx] ~= p
                    local left = xx == 0 or shape.mask[yy * cols + xx - 1] ~= p
                    local above = yy == 0 or shape.mask[(yy - 1) * cols + xx] ~= p
                    local x0, y0 = g.colX[xx] - (left and 2 or 0), g.rowY[yy] - (above and 2 or 0)
                    local x1, y1 = g.colX[xx] + cs + (right and 3 or 0), g.rowY[yy] + cs + (below and 3 or 0)
                    dim(x0, y0, x1 - x0, y1 - y0)
                end
            end
        end
    else
        for p, o in pairs(g.parts) do dim(o.x - 2, o.y - 2, p.w * cs + 5, p.h * cs + 5) end
    end
    local base = L.baseRows or L.rows
    if L.rows > base then dim(g.ovX - 2, g.ovY - 2, g.ovW + 5, (L.rows - base) * cs + 5) end
end

function KnoxGridView:render()
    local p0 = getTimestampMs()
    self:renderGrid()
    if self.knoxNoRoom then self:drawNoRoomMask() end
    -- (what drawing the grid costs a frame, summed for the test bench: KnoxTestBench)
    self.profR = (self.profR or 0) + getTimestampMs() - p0
    self.profN = (self.profN or 0) + 1
end

function KnoxGridView:renderGrid()
    local cs = T.cell
    local L = self.layout
    local W, H = L.cols * cs, L.rows * cs

    local base = L.baseRows or L.rows
    local line = T.color.line
    -- (the lines' thickness and strength are the player's: see KnoxTheme.LOOK)
    local lw, la = T.gridLine(), T.gridLineAlpha()
    local lo = math.floor((lw - 1) / 2)
    local function vline(i, y0, y1) self:drawRect(i * cs - lo, y0, lw, y1 - y0 + 1, la, line.r, line.g, line.b) end
    local function hline(j, x1) self:drawRect(0, j * cs - lo, x1 + 1, lw, la, line.r, line.g, line.b) end
    local g = self:geo()
    if g then
        -- a bag with compartments: each its own little grid in a frame, a gap
        -- between them (KnoxBagShapes); the rows of what doesn't fit under them all
        KnoxGridView.drawShape(self, 0, 0, L.shape, cs, nil, 1)
        if L.rows > base then
            local ox, ow, oh = g.ovX, g.ovW, (L.rows - base) * cs
            T.rect(self, ox, g.ovY, ow, oh, T.color.cell, T.gridAlpha())
            for i = 0, L.shape.ovCols do self:drawRect(ox + i * cs - lo, g.ovY, lw, oh + 1, la, line.r, line.g, line.b) end
            for j = 0, L.rows - base do self:drawRect(ox - lo, g.ovY + j * cs - lo, ow + lw, lw, la, line.r, line.g, line.b) end
            KnoxGridView.drawOverflow(self, ox, g.ovY, ow, oh, 1)
        end
    elseif not L.limit then
        T.rect(self, 0, 0, W, H, T.color.cell, T.gridAlpha())
        for i = 0, L.cols do vline(i, 0, H) end
        for j = 0, L.rows do hline(j, W) end
    else
        -- the last row of the grid is not whole (the pockets: as many cells as
        -- the clothes give): `part` cells after `whole` rows; the rest of that
        -- row is no part of the grid and is left empty
        local whole = math.floor(L.limit / L.cols)
        local part = L.limit - whole * L.cols
        local wholeH = whole * cs
        T.rect(self, 0, 0, W, wholeH, T.color.cell, T.gridAlpha())
        T.rect(self, 0, wholeH, part * cs, cs, T.color.cell, T.gridAlpha())
        if L.rows > base then T.rect(self, 0, base * cs, W, (L.rows - base) * cs, T.color.cell, T.gridAlpha()) end
        for i = 0, L.cols do
            vline(i, 0, i <= part and wholeH + cs or wholeH)
            if L.rows > base then vline(i, base * cs, H) end
        end
        for j = 0, whole do hline(j, W) end
        if L.rows > base then
            for j = base, L.rows do hline(j, W) end
        else
            hline(base, part * cs)
        end
    end
    -- overflow rows (items the grid had no room for): red tint, a red line on top
    if L.rows > base and not g then
        KnoxGridView.drawOverflow(self, 0, base * cs, W, (L.rows - base) * cs, 1)
    end

    self.hovered = (self:entityUnderMouse())
    self:updateLift()
    self:offerKinds()
    self:offerBattery()
    local dragged = KnoxDrag.entity
    -- only the rows that can be seen: the grid lies in a scrolled column (or
    -- window) that shows a part of it, and a long one has hundreds of tiles
    local top, bottom = self:visibleRows()
    self.quiet = self.quiet or {}
    local quiet, nq = self.quiet, 0
    local raised = nil
    -- (the eye by the Sort button hides them: they fade as it closes)
    local gk = (self.silhouettes and #self.silhouettes > 0) and KnoxOrder.ghostK() or 0
    if gk > 0.01 then
        for _, en in ipairs(self.silhouettes) do
            local _, sh = KnoxGrid.dims(en, en.r)
            -- (not where a tile is just being dragged over or comes to: those cells aren't free any more)
            if en.y + sh > top and en.y < bottom and not L:cellAt(en.x, en.y) then self:drawSilhouette(en, gk) end
        end
    end
    for _, e in ipairs(L.placed) do
        local _, eh = KnoxGrid.dims(e, e.r)
        if e.y + eh <= top or e.y >= bottom then
            -- (out of sight)
        elseif e.reserved then
            -- cells an item is coming to: only a breathing frame, no item yet
            local rx, ry, rw, rh = self:tileRect(e)
            if rx then
                T.target(self, rx, ry, rw, rh)
                -- several moves at once: this one's turn in a sand square
                local rec = KnoxGrid.pending[e.item]
                local turn = rec and KnoxGrid.orderOf(rec)
                if turn then T.turnBadge(self, rx, ry, turn) end
            end
        elseif e.ghost then
            self:drawTile(e, 0.4)
            local _, p = KnoxGrid.pendingOf(e.item)
            local rx, ry, rw, rh = self:tileRect(e)
            if p and rx then T.progress(self, rx, ry, rw, rh, p) end
        elseif not g and knoxDrawTiles and not (KnoxTestBench and KnoxTestBench.luaTiles) and self:isQuiet(e) then
            -- (the Java part draws a grid's cells in rows: not a bag's compartments)
            nq = nq + 1
            quiet[nq] = e
        elseif lifts[e.item] then
            -- (lifted: drawn after the others, or the tile above would cover its top)
            raised = raised or {}
            table.insert(raised, e)
        else
            self:drawTile(e, KnoxGridView.isDragged(e) and 0.3 or 1)
        end
    end
    -- the quiet tiles in one call to the Java part (KnoxTiles.java), then
    -- their stack counts here (text)
    if nq > 0 then
        knoxDrawTiles(self.javaObject, quiet, nq, cs, T.color)
        local f, fh = T.fontTile, T.fontTileH
        for i = 1, nq do
            local e = quiet[i]
            local d = e.draw
            if d.broken or #e.items > 1 then
                local x, y, pw, ph = self:tileRect(e)
                if d.broken then
                    T.outlinedRight(self, "0%", x + pw - 4, y + ph - fh - 3, T.color.bad, f, 1)
                else
                    T.outlinedRight(self, tostring(#e.items), x + pw - 4, y + ph - fh - 3,
                        d.mixed and T.color.accent or T.color.bright, f, 1)
                end
            end
        end
    end
    for i = nq + 1, #quiet do quiet[i] = nil end
    for _, e in ipairs(raised or {}) do self:drawTile(e, KnoxGridView.isDragged(e) and 0.3 or 1) end
    self:drawStackHints(top, bottom)

    -- tiles fading out where a thing has just gone from
    if self.leaving and #self.leaving > 0 then
        local nowMs = getTimestampMs()
        local keep = {}
        for _, old in ipairs(self.leaving) do
            local t = T.anim((nowMs - old.ms) / 170)
            -- (not over a tile that has taken its cells meanwhile)
            if t < 1 and not L:cellAt(old.x, old.y) then
                self:drawTile(old, old.from * (1 - t) * (1 - t))
                table.insert(keep, old)
            end
        end
        self.leaving = keep
    end

    -- where the dragged tile would land: a same-type stack under the cursor
    -- lights up whole (merge), else the footprint at the cursor
    if dragged and self:isMouseOver() then
        local x, y = self:dropCell()
        local w, h = KnoxDrag.dims()
        local merge = KnoxDrag.mergeTarget(self)
        local bag = not merge and KnoxDrag.bagUnderMouse(self)
        local ok, why
        if merge then
            x, y = merge.x, merge.y
            w, h = KnoxGrid.dims(merge, merge.r)
            ok, why = KnoxDrag.canDrop(L, x, y, self:player(), merge)
        elseif bag then
            -- onto a bag: the bag lights up, green when the item fits inside
            x, y = bag.x, bag.y
            w, h = KnoxGrid.dims(bag, bag.r)
            local fits, inside, _, _, _, bagWhy = KnoxDrag.intoBag(bag, self:player())
            ok, why = fits, bagWhy
            -- (it may go in, but no place is left in it)
            if not ok and not why and inside then why = "IGUI_Knox_NoRoom" end
        else
            ok, why = KnoxDrag.canDrop(L, x, y, self:player(), merge)
            -- it doesn't go as it is turned but would the other way: shown that way
            -- (the drop turns it by itself)
            if not ok and dragged.w ~= dragged.h then
                KnoxDrag.rotate()
                local x2, y2 = self:dropCell()
                if KnoxDrag.canDrop(L, x2, y2, self:player(), nil) then
                    ok, why = true, nil
                    x, y = x2, y2
                    w, h = KnoxDrag.dims()
                end
                KnoxDrag.rotate()
            end
            -- (the cells are taken, and no other place in the grid is free: no room.
            -- Not within its own grid - rearranging a full bag)
            if not ok and not why and L.container ~= (KnoxDrag.source and KnoxDrag.source.layout and KnoxDrag.source.layout.container)
                    and KnoxDrag.noPlaceIn(L) then
                why = "IGUI_Knox_NoRoom"
            end
        end
        -- (walked away with it in hand: red, the drop is refused - KnoxDrag.tooFarFor)
        if ok and KnoxDrag.tooFarFor(self:player(), bag and bag.item:getInventory() or L.container) then
            ok, why = false, "IGUI_Knox_TooFar"
        end
        local c = ok and T.color.ok or T.color.bad
        -- clip the highlight to the grid
        local x0, y0 = math.max(0, x), math.max(0, y)
        local x1, y1 = math.min(L.cols, x + w), math.min(L.rows, y + h)
        if x1 > x0 and y1 > y0 and g then
            -- a bag with compartments: the footprint's cells that are cells of
            -- it, each lit (one block when it is all in one compartment)
            local hx, hy, hw, hh = self:blockRect(x0, y0, x1 - x0, y1 - y0)
            local p0, p1 = L:partAt(x0, y0), L:partAt(x1 - 1, y1 - 1)
            if hx and p0 and p0 == p1 then
                self:drawRect(hx, hy, hw, hh, 0.22, c.r, c.g, c.b)
                self:drawRectBorder(hx, hy, hw, hh, 1, c.r, c.g, c.b)
            else
                for yy = y0, y1 - 1 do
                    for xx = x0, x1 - 1 do
                        local qx, qy, qw, qh = self:blockRect(xx, yy, 1, 1)
                        if qx and (yy >= base or L:partAt(xx, yy)) then self:drawRect(qx, qy, qw, qh, 0.22, c.r, c.g, c.b) end
                    end
                end
            end
        elseif x1 > x0 and y1 > y0 then
            self:drawRect(x0 * cs + 1, y0 * cs + 1, (x1 - x0) * cs - 1, (y1 - y0) * cs - 1, 0.22, c.r, c.g, c.b)
            self:drawRectBorder(x0 * cs + 1, y0 * cs + 1, (x1 - x0) * cs - 1, (y1 - y0) * cs - 1, 1, c.r, c.g, c.b)
        end
        -- refused, and there are words for why: the plate by the held tile says it
        -- (KnoxDragLayer:drawReason), kept to the grid's sides
        if not ok and why then
            local ax = self:getAbsoluteX() + self:getXScroll()
            KnoxDrag.setHint(why, ax, ax + L.cols * cs + 1)
        end
    end

    self:drawBand()
    self:updateTooltip()
end

-- Drag layer: a 0x0 element kept on top of every window. It draws the
-- dragged tile at the cursor and shows the item tooltip; being 0x0 it never
-- takes a mouse click.
KnoxDragLayer = ISUIElement:derive("KnoxDragLayer")

function KnoxDragLayer:new()
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    return o
end

function KnoxDragLayer:prerender()
    KnoxDrag.update()
    -- the held item turned by a mouse button, when the player has set it so
    -- (the buttons are looked at here: any window may lie under the cursor)
    local rmb, mmb = isMouseButtonDown(1), isMouseButtonDown(2)
    if KnoxDrag.isActive() then
        if (rmb and not self.rmbWas and KnoxControls.isRotateButton("rmb"))
                or (mmb and not self.mmbWas and KnoxControls.isRotateButton("mmb")) then
            KnoxDrag.turn()
        end
    end
    self.rmbWas, self.mmbWas = rmb, mmb
    self:bringToTop()
    KnoxTooltip.apply()
end

-- Inertia: the held tile follows the cursor as a weight on a spring - a
-- bandage keeps up with it, an axe or a full bag lags behind and sways a little
-- as the mouse stops (the author's wish, 2026-10-15). Only the picture lags:
-- where the thing goes is still where the cursor is.

--- What the held tile (and what comes along with it) weighs.
local function heldWeight(e)
    local sum = 0
    local function add(t)
        for _, it in ipairs(t.items or {t.item}) do sum = sum + KnoxGrid.weightOf(it) end
    end
    add(e)
    for _, ex in ipairs(KnoxDrag.extras or {}) do add(ex.entity) end
    return sum
end

-- A very heavy thing being dragged (a generator, 40 kg) shakes, as if hard to
-- hold up: from 15 kg on, harder with the weight, full at 40 - an uneven
-- tremble with now and then a jolt (the author's wish, 2026-10-15).
local STRAIN_FROM, STRAIN_FULL = 15, 40

--- dx, dy of the shake for a load of `kg`; 0, 0 when light or animations are off.
function KnoxGridView.strain(kg)
    if not kg or kg < STRAIN_FROM or (T.animOn and not T.animOn()) then return 0, 0 end
    local k = math.min(1, (kg - STRAIN_FROM) / (STRAIN_FULL - STRAIN_FROM))
    local amp = 1 + 2 * k                       -- 1..3 px
    local t = getTimestampMs() / 1000
    local dx = 0.55 * math.sin(t * 31) + 0.35 * math.sin(t * 47 + 1.3) + 0.25 * math.sin(t * 13 + 0.4)
    local dy = 0.5 * math.sin(t * 37 + 2.1) + 0.35 * math.sin(t * 23 + 0.7)
    -- a jolt every second or so: the arms give for a moment
    local j = math.sin(t * 5.3) * math.sin(t * 2.9)
    if j > 0.8 then dy = dy + (j - 0.8) * 5 end
    return math.floor(dx * amp + 0.5), math.floor(dy * amp + 0.5)
end

--- The point the tile is drawn at: the cursor, or a spring's end behind it.
function KnoxDragLayer:follow(e)
    local mx, my = getMouseX(), getMouseY()
    if T.animOn and not T.animOn() then return mx, my end
    local now = getTimestampMs()
    local st = self.inertia
    if not st or st.entity ~= e then
        -- (heavier: a softer spring - it reaches the cursor later and swings more)
        local wgt = heldWeight(e)
        -- (a bandage: about 31 - it follows close; an axe of 3 kg: about 18; a pack of 15 kg: about 9.
        -- Tuned with the author, 2026-10-15: the first try had too little inertia, the
        -- second too much; this is halfway between them, each weight's lag about
        -- the middle of the two.)
        local omega = math.max(7, math.min(32, 32 / math.sqrt(1 + wgt * 0.7)))
        st = {entity = e, px = mx, py = my, vx = 0, vy = 0, ms = now, omega = omega, zeta = 0.56}
        self.inertia = st
    end
    local dt = math.min(0.05, (now - st.ms) / 1000)
    st.ms = now
    local steps = math.max(1, math.ceil(dt / 0.008))
    local hstep = dt / steps
    local om, z = st.omega, st.zeta
    for _ = 1, steps do
        st.vx = st.vx + (om * om * (mx - st.px) - 2 * z * om * st.vx) * hstep
        st.vy = st.vy + (om * om * (my - st.py) - 2 * z * om * st.vy) * hstep
        st.px = st.px + st.vx * hstep
        st.py = st.py + st.vy * hstep
    end
    return math.floor(st.px + 0.5), math.floor(st.py + 0.5)
end

-- The reason plate (option A in the style "Чертёж", the author 2026-10-28):
-- the held tile over a place it can't go, and caught up with the cursor (the
-- author: only then) - a plate over the held tile says why, with a picture
-- (tools/reason_icons). Over the tile, not the red footprint: over a big bag the
-- footprint is the bag, and the plate lay on the tile (the author, 2026-10-28).
-- Below the tile, clear of the arrow, when the screen's top is too near; kept
-- to the grid's sides and the screen. In 120 ms, out in 170.
-- Mockup: .claude/mockups/drop_reason.
local REASON_ICON = {IGUI_Knox_TooFar = "far", IGUI_Knox_NoRoom = "full", IGUI_Knox_BagGrowsNoRoom = "grow"}
local CURSOR_H = 27            -- Knox's arrow (knox_cursor.png) below its point
local SHADOW = {r = 0, g = 0, b = 0}
local reasonBand, reasonOpts = {0, 0, 0, 0}, {align = "centre"}
local reasonTexts, reasonPaths = {}, {}

-- the picture's size for the plate: the largest made that is no bigger than half a cell
local function reasonSize()
    local want = math.max(20, math.floor(T.cell * 0.5 + 0.5))
    local sizes = KnoxReasonIcons and KnoxReasonIcons.sizes
    if not sizes then return nil end
    local best = sizes[1]
    for i = 1, #sizes do
        if sizes[i] <= want then best = sizes[i] end
    end
    return best
end

local function reasonTex(name, size)
    local byName = reasonPaths[name]
    if not byName then
        byName = {}
        reasonPaths[name] = byName
    end
    local p = byName[size]
    if not p then
        local stem = "media/ui/knoxreason/" .. name .. "_" .. size
        p = {stem .. "_base.png", stem .. "_mark.png"}
        byName[size] = p
    end
    return T.readyTex(p[1]), T.readyTex(p[2])
end

--- `x, y, w, h`: the held tile on the screen (without its shake).
function KnoxDragLayer:drawReason(settled, x, y, w, h)
    local k = KnoxDrag.hint
    local now = getTimestampMs()
    local st = self.reasonState
    if not st then
        st = {a = 0, ms = now, why = nil, x = 0, y = 0, w = 0, h = 0, left = 0, right = 0, mouseY = 0}
        self.reasonState = st
    end
    local dt = now - st.ms
    st.ms = now
    if k.frame == KnoxDrag.frame and k.why and settled then
        if st.why ~= k.why then st.why, st.a = k.why, 0 end
        st.x, st.y, st.w, st.h = x, y, w, h
        st.left, st.right, st.mouseY = k.left, k.right, getMouseY()
        st.a = math.min(1, st.a + dt / 120)
    else
        st.a = math.max(0, st.a - dt / 170)
    end
    if st.a <= 0 or not st.why then return end

    local text = reasonTexts[st.why]
    if not text then
        text = getText(st.why)
        reasonTexts[st.why] = text
    end
    local font, pad = T.fontText, T.pad
    local left, _, right = T.inkBox(font, text)
    local tw = right - left
    local name = REASON_ICON[st.why]
    local size = name and reasonSize()
    local m = size and KnoxReasonIcons[name] and KnoxReasonIcons[name][size]
    local gap = math.floor(pad / 2)
    local bh = math.max(T.fontH(font), m and size or 0) + pad
    local bw = pad + (m and (m.w + gap) or 0) + tw + pad
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local bx = st.x + math.floor((st.w - bw) / 2)
    bx = math.max(st.left + 1, math.min(bx, st.right - 1 - bw))
    bx = math.max(0, math.min(bx, sw - bw))
    -- (above the "+N" badge of things held along with it, when there is one)
    local badge = #KnoxDrag.extras > 0 and T.fontTileH + 2 or 0
    local by = st.y - badge - gap - bh
    if by < 0 then by = math.min(sh - bh, math.max(st.y + st.h + gap, st.mouseY + CURSOR_H + 2)) end
    local a = st.a
    T.rect(self, bx + 4, by + 6, bw, bh, SHADOW, 0.45 * a)
    T.rect(self, bx, by, bw, bh, T.color.window, 0.97 * a)
    T.border(self, bx, by, bw, bh, T.color.bad, a)
    local tx = bx + pad
    if m then
        local base, mark = reasonTex(name, size)
        local iy = by + math.floor((bh - (m.bottom - m.top + 1)) / 2) - m.top
        local c, r = T.color.text, T.color.bad
        if base then self:drawTextureScaled(base, tx, iy, m.w, m.h, 0.92 * a, c.r, c.g, c.b) end
        if mark then self:drawTextureScaled(mark, tx, iy, m.w, m.h, a, r.r, r.g, r.b) end
        tx = tx + m.w + gap
    end
    reasonBand[1], reasonBand[2], reasonBand[3], reasonBand[4] = tx, by, tw, bh
    reasonOpts.font, reasonOpts.a = font, a
    T.label(self, text, reasonBand, T.color.text, reasonOpts)
end

function KnoxDragLayer:render()
    local e = KnoxDrag.entity
    if not e then
        self.inertia = nil
        KnoxDrag.frame = KnoxDrag.frame + 1
        return
    end
    local cs = T.cell
    local w, h = KnoxDrag.dims()
    local fx, fy = self:follow(e)
    local x = fx - KnoxDrag.grabX * cs - math.floor(cs / 2)
    local y = fy - KnoxDrag.grabY * cs - math.floor(cs / 2)
    local ui = self
    local pw, ph = w * cs - 1, h * cs - 1
    -- just turned with the key: it swings from the shape it had (the same
    -- tile lying the other way, held by the same cell) into the new one
    local t = KnoxDrag.turnedMs and T.anim((getTimestampMs() - KnoxDrag.turnedMs) / 130) or 1
    if t < 1 then
        local k = 1 - (1 - t) * (1 - t)
        local x0 = fx - KnoxDrag.grabY * cs - math.floor(cs / 2)
        local y0 = fy - KnoxDrag.grabX * cs - math.floor(cs / 2)
        local pw0, ph0 = h * cs - 1, w * cs - 1
        x = math.floor(x0 + (x - x0) * k + 0.5)
        y = math.floor(y0 + (y - y0) * k + 0.5)
        pw = math.floor(pw0 + (pw - pw0) * k + 0.5)
        ph = math.floor(ph0 + (ph - ph0) * k + 0.5)
    end
    -- a heavy thing shakes, tile and all (the tile itself, not what is selected
    -- along with it: one heavy thing shakes)
    local kg = 0
    for _, it in ipairs(e.items or {e.item}) do kg = kg + KnoxGrid.weightOf(it) end
    local sx, sy = KnoxGridView.strain(kg)
    local restX, restY = x, y
    x, y = x + sx, y + sy
    T.rect(ui, x, y, pw, ph, T.category[T.categoryOf(e.item)], 0.85)
    T.border(ui, x, y, pw, ph, T.color.accent, 1)
    local side = math.floor(math.min(pw, ph) * 0.72)
    ISInventoryItem.renderItemIcon(ui, e.item, x + math.floor((pw - side) / 2), y + math.floor((ph - side) / 2), 0.9, side, side)
    -- more selected tiles coming along
    local n = #KnoxDrag.extras
    if n > 0 then
        local text = "+" .. n
        local tw = T.measure(T.fontTile, text) + 8
        T.rect(ui, x + pw - tw, y - T.fontTileH - 2, tw, T.fontTileH + 2, T.color.accent)
        T.drawText(ui, text, x + pw - tw + 4, y - T.fontTileH - 1, 0.08, 0.08, 0.08, 1, T.fontTile)
    end
    -- caught up with the cursor: the reason plate may show (the author: not before)
    local st = self.inertia
    local settled = math.abs(fx - getMouseX()) <= 1 and math.abs(fy - getMouseY()) <= 1
        and (not st or (T.animOn and not T.animOn()) or math.abs(st.vx) + math.abs(st.vy) < 40)
    self:drawReason(settled, restX, restY, pw, ph)
    KnoxDrag.frame = KnoxDrag.frame + 1
end

--- Is this tile being dragged (itself or as part of the selection)?
function KnoxGridView.isDragged(e)
    if not KnoxDrag.entity then return false end
    if KnoxDrag.entity.part then return false end   -- some of a stack: the stack stays as it is
    if e.item == KnoxDrag.entity.item then return true end
    for _, ex in ipairs(KnoxDrag.extras) do
        if ex.entity.item == e.item then return true end
    end
    return false
end

-- Tooltip -------------------------------------------------------------------

-- Kinds in a stack -------------------------------------------------------------
-- A stack joins items of one type, but they need not be alike: keys to
-- different doors, a skill tape and a film, a full battery and a flat one. Such
-- a stack shows its kinds in the quick pick panel (KnoxSlotPicker.wantStack)
-- when the mouse rests on it; a kind is dragged or clicked out from there.

local KINDS_HOVER_MS = 120   -- (not for a mouse just passing over the grid)

--- What sets one item of a stack apart from the others (same text = alike).
local function kindOf(item)
    local s = item:getDisplayName() or ""
    local key = item:getKeyId()
    if key and key ~= -1 then s = s .. "|k" .. tostring(key) end
    local media = item:getMediaData()
    if media then s = s .. "|m" .. tostring(media:getId()) end
    if item:IsDrainable() then s = s .. "|u" .. tostring(math.floor(item:getCurrentUsesFloat() * 100 + 0.5)) end
    return s
end

--- The stack's items by kind: a list of lists, in the stack's order (kept on
--- the tile; a tile is made anew when its grid is rebuilt).
function KnoxGridView.kindsOf(e)
    if e.kinds then return e.kinds end
    local out, byKind = {}, {}
    if #e.items > 1 then
        for _, it in ipairs(e.items) do
            local k = kindOf(it)
            local g = byKind[k]
            if not g then
                g = {}
                byKind[k] = g
                table.insert(out, g)
            end
            table.insert(g, it)
        end
    end
    e.kinds = out
    return out
end

-- the hovered stack's place on the screen, for the panel to open beside it
local TileRef = {}
TileRef.__index = TileRef
function TileRef:rect()
    local x, y, w, h = self.view:tileRect(self.e)
    if not x then return 0, 0, T.cell - 1, T.cell - 1 end
    return x, y, w, h
end
function TileRef:getAbsoluteX() return self.view:getAbsoluteX() + (self:rect()) end
function TileRef:getAbsoluteY()
    local _, y = self:rect()
    return self.view:getAbsoluteY() + y
end
function TileRef:getWidth()
    local _, _, w = self:rect()
    return w
end
function TileRef:getHeight()
    local _, _, _, h = self:rect()
    return h
end

--- Some items of stack `e` as a tile of their own (not placed anywhere yet).
local function partOf(e, items)
    return {item = items[1], items = items, w = e.w, h = e.h, x = e.x, y = e.y, r = e.r, part = true}
end

function KnoxGridView:offerKinds()
    local e = self.hovered
    local ref = self.kindsRef
    if not e or e.ghost or KnoxDrag.isActive() or (self.band and self.band.active)
            or #KnoxGridView.kindsOf(e) < 2 then
        if ref and not KnoxSlotPicker.isOpenFor(ref) then self.kindsRef = nil end
        return
    end
    local now = getTimestampMs()
    if not ref or ref.item ~= e.item then
        ref = setmetatable({view = self, item = e.item, sinceMs = now}, TileRef)
        self.kindsRef = ref
    end
    ref.e = e   -- (the grid may have been rebuilt: the tile is a new table)
    if not KnoxSlotPicker.isOpenFor(ref) and now - ref.sinceMs < KINDS_HOVER_MS then return end
    local view = self
    KnoxSlotPicker.wantStack(ref, getText("IGUI_Knox_StackKinds"), KnoxGridView.kindsOf(e), function(what, items, mods)
        local stack = ref.e
        local part = partOf(stack, items)
        local player = view:player()
        if what == "drag" then
            local w, h = KnoxGrid.dims(part, part.r)
            KnoxDrag.start(part, view, math.floor((w - 1) / 2), math.floor((h - 1) / 2))
            return
        end
        -- a click with keys held does what it does on a tile (Shift: to the other
        -- side; the right button: its menu...); a plain one takes the kind out
        -- into a tile of its own, next to the stack
        local act = KnoxControls.actionFor("mouse", (mods or "") .. (what == "rmb" and "rmb" or "lmb"))
        if act and act ~= "select" and act ~= "alt" then
            view:doAction(act, part)
        elseif what == "click" then
            KnoxActions.takeOut(stack, items, view, player)
        end
        for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
    end, self.playerNum)
end

--- Does the item run on a battery? {has, power} (a radio's or a walkie-talkie's
--- device, a flashlight's charge), or nil.
function KnoxGridView.batteryOf(item)
    local ok, b = pcall(function()
        if instanceof(item, "Radio") then
            local dd = item:getDeviceData()
            if dd and dd:getIsBatteryPowered() then return {has = dd:getHasBattery(), power = dd:getPower()} end
            return nil
        end
        if item:IsDrainable() and item:isTorchCone() then
            local u = item:getCurrentUsesFloat() or 0
            return {has = u > 0, power = u}
        end
        return nil
    end)
    return ok and b or nil
end

--- The battery slot used (the author, 2026-10-21: it showed the battery, but it
--- could not be taken out): `remove` - the battery out into the main inventory;
--- else `battery` (the fullest of the character's) put in. As the game does it:
--- a radio's or walkie's set - its battery action, the thing in the main inventory
--- first; a flashlight - its recipes (the game's light menu).
function KnoxGridView.batteryAct(player, item, remove, battery)
    if not player or not item then return end
    local inv = player:getInventory()
    local function toMain(it)
        if it:getContainer() ~= inv then
            ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, it, it:getContainer(), inv))
        end
    end
    if instanceof(item, "Radio") then
        if not remove and not battery then return end
        toMain(item)
        if battery then toMain(battery) end
        local act = ISDeviceBatteryAction:new(player, remove, battery,
            ISDeviceBatteryAction:getDeviceDataParameter(player, item, "InventoryItem"))
        -- (the game finds the set by its ID in the main inventory only, when the
        -- action is made - a set in a bag is moved there first, by the action
        -- queued before: so it is looked for again when this one starts; the
        -- author, 2026-10-22: "attempted index: getIsBatteryPowered of non-table")
        local valid = act.isValid
        act.isValid = function(self)
            if not self.deviceData then
                self.deviceData = ISDeviceBatteryAction:getDeviceDataFromParameter(self.character, self.parameter)
            end
            return self.deviceData ~= nil and valid(self)
        end
        ISTimedActionQueue.add(act)
        return
    end
    require "ISUI/ISLightSourceRadialMenu"
    if not ISLightSourceRadialMenu then return end
    local menu = setmetatable({character = player, playerNum = player:getPlayerNum()}, {__index = ISLightSourceRadialMenu})
    if remove then menu:onRemoveBattery(item) else menu:onInsertBattery(item) end
end

--- The fullest battery of `list`, or nil.
local function fullest(list)
    local best, bp = nil, -1
    for _, it in ipairs(list or {}) do
        local p = it:getCurrentUsesFloat() or 0
        if p > bp then best, bp = it, p end
    end
    return best
end

--- A thing with a battery under the mouse: the battery slot next to it (KnoxSlotPicker.wantBattery).
function KnoxGridView:offerBattery()
    local e = self.hovered
    local ref = self.batteryRef
    local b = e and not e.ghost and #e.items == 1 and not KnoxDrag.isActive() and not (self.band and self.band.active)
        and KnoxGridView.batteryOf(e.item)
    if not b then
        if ref and not KnoxSlotPicker.isOpenFor(ref) then self.batteryRef = nil end
        return
    end
    local now = getTimestampMs()
    if not ref or ref.item ~= e.item then
        ref = setmetatable({view = self, item = e.item, sinceMs = now}, TileRef)
        self.batteryRef = ref
    end
    ref.e = e
    if not KnoxSlotPicker.isOpenFor(ref) and now - ref.sinceMs < KINDS_HOVER_MS then return end
    if not b.has then
        -- (looked for twice a second, not every frame the mouse rests on the radio)
        if not ref.spares or now - (ref.sparesMs or 0) > 500 then
            local spares = {}
            local list = self:player():getInventory():getAllTypeRecurse("Base.Battery")
            for i = 0, list:size() - 1 do table.insert(spares, list:get(i)) end
            ref.spares, ref.sparesMs = spares, now
        end
        b.spares = ref.spares
    end
    local view = self
    b.act = function(what)
        local player = view:player()
        if what == "take" then
            KnoxGridView.batteryAct(player, ref.item, true, nil)
        elseif what == "put" then
            local best = fullest(ref.spares)
            if best then KnoxGridView.batteryAct(player, ref.item, false, best) end
        end
        ref.spares = nil
        for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
    end
    KnoxSlotPicker.wantBattery(ref, getText("IGUI_Knox_Battery"), b, self.playerNum)
end

function KnoxGridView:updateTooltip()
    if self.band and self.band.active then return end   -- drawing a selection frame
    -- (a stack showing its kinds: each of them has its tooltip in the panel)
    if self.hovered and self.kindsRef and self.kindsRef.item == self.hovered.item then
        for _, it in ipairs(self.hovered.items) do KnoxGridView.fresh[it] = nil end
        return
    end
    if self.hovered then
        KnoxTooltip.want(self.hovered.item, self.playerNum)
        for _, it in ipairs(self.hovered.items) do KnoxGridView.fresh[it] = nil end   -- seen
    end
end

function KnoxGridView:onMouseWheel(del)
    if self.parent and self.parent.onMouseWheel then return self.parent:onMouseWheel(del) end
    return false
end

-- Mouse ---------------------------------------------------------------------

local function ctrlDown() return isKeyDown(Keyboard.KEY_LCONTROL) or isKeyDown(Keyboard.KEY_RCONTROL) end

--- What a gesture on a tile does is the player's to set (KnoxControls): do the action.
function KnoxGridView:doAction(id, e)
    local player = self:player()
    if id == "select" then
        KnoxSelect.toggle(e)
    elseif id == "quickMove" then
        KnoxActions.quickTransfer(e, self, player)
    elseif id == "alt" then
        KnoxActions.alt(e, self, player)
    elseif id == "open" then
        self:onDoubleClick(e)
    elseif id == "menu" then
        self:openMenu(e, self:getMouseX(), self:getMouseY())
    elseif id == "inspect" then
        KnoxInspectWindow.open(e.item, self.playerNum)
    end
end

function KnoxGridView:onMouseDown(x, y)
    -- a click in a bag window's grid makes that window the active one
    if self.parent and self.parent.activate then self.parent:activate() end
    local e, cx, cy = self:entityUnderMouse()
    if e then
        self.press = {entity = e, x = getMouseX(), y = getMouseY(), cx = cx - e.x, cy = cy - e.y,
                      mods = KnoxControls.mods()}
    else
        -- on an empty cell: a click drops the selection, a drag draws a
        -- selection frame (as on the Windows desktop); with Ctrl it adds
        local ctrl = ctrlDown()
        if not ctrl then KnoxSelect.clear() end
        local base = {}
        for it in pairs(KnoxSelect.items) do base[it] = true end
        self.band = {x0 = self:getMouseX(), y0 = self:getMouseY(), mx = getMouseX(), my = getMouseY(),
                     base = base, active = false}
    end
    return true
end

-- Selection frame --------------------------------------------------------------

local BAND_START_PX = 5

--- Follow the mouse while the frame is drawn: every tile it touches is selected.
function KnoxGridView:updateBand()
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
    local W, H = self:pxSize()
    b.x1 = math.max(0, math.min(W, self:getMouseX()))
    b.y1 = math.max(0, math.min(H, self:getMouseY()))
    local x0, x1 = math.min(b.x0, b.x1), math.max(b.x0, b.x1)
    local y0, y1 = math.min(b.y0, b.y1), math.max(b.y0, b.y1)
    local sel = {}
    for it in pairs(b.base) do sel[it] = true end
    for _, e in ipairs(self.layout.placed) do
        -- (not what a search has not found yet: a frame over it took it along)
        if not e.ghost and not e.reserved and not (KnoxSearch and KnoxSearch.isHidden(e.item)) then
            local ex0, ey0, ew, eh = self:tileRect(e)
            if ex0 and ex0 < x1 and ex0 + ew > x0 and ey0 < y1 and ey0 + eh > y0 then
                for _, it in ipairs(e.items) do sel[it] = true end
            end
        end
    end
    KnoxSelect.items = sel
end

function KnoxGridView:drawBand()
    local b = self.band
    if not b or not b.active or not b.x1 then return end
    local x, y = math.min(b.x0, b.x1), math.min(b.y0, b.y1)
    local w, h = math.abs(b.x1 - b.x0), math.abs(b.y1 - b.y0)
    local c = T.color.accent
    self:drawRect(x, y, w, h, 0.10, c.r, c.g, c.b)
    self:drawRectBorder(x, y, w, h, 0.9, c.r, c.g, c.b)
end

function KnoxGridView:onMouseMove(dx, dy)
    if self.band then self:updateBand() return end
    local p = self.press
    if p and not KnoxDrag.isActive() and isMouseButtonDown(0) then
        if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) >= DRAG_START_PX then
            -- a selected tile drags the rest of the selection along
            local extras = {}
            if KnoxSelect.isSelected(p.entity) then
                for _, g in ipairs(KnoxSelect.group(p.entity, self, KnoxActions.allViews())) do
                    if g.entity.item ~= p.entity.item then table.insert(extras, g) end
                end
            end
            KnoxDrag.start(p.entity, self, p.cx, p.cy, extras)
            self.press = nil
        end
    end
end

function KnoxGridView:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function KnoxGridView:onMouseUp(x, y)
    if self.band then
        self.band = nil
        return true
    end
    if KnoxDrag.isActive() then
        local tx, ty = self:dropCell()
        KnoxDrag.drop(self, tx, ty, self:player())
        self:markDirty()
        if self.parent and self.parent.markAllDirty then self.parent:markAllDirty() end
        return true
    end
    local p = self.press
    self.press = nil
    if p then
        -- the second click of a double click, with the same keys held, on a tile
        -- of the same kind (the first may have moved the very tile away)
        local now = getTimestampMs()
        local kind = p.entity.item:getFullType()
        local last = KnoxGridView.lastClicks[self.container]
        if last and last.mods == p.mods and last.type == kind and now - last.ms < DOUBLE_CLICK_MS then
            local act2 = KnoxControls.actionFor("mouse", p.mods .. "lmb2")
            if act2 then
                KnoxGridView.lastClicks[self.container] = nil
                self:doAction(act2, p.entity)
                return true
            end
        end
        KnoxGridView.lastClicks[self.container] = {ms = now, mods = p.mods, type = kind}
        -- a click with what was held when it began: its own action
        local act = KnoxControls.actionFor("mouse", p.mods .. "lmb")
        if act then
            self:doAction(act, p.entity)
            return true
        end
        if p.mods == "" and not KnoxSelect.isSelected(p.entity) then KnoxSelect.clear() end
    end
    return true
end

function KnoxGridView:onMouseUpOutside(x, y)
    self.press = nil
    self.band = nil
end

function KnoxGridView:onDoubleClick(e)
    -- a bag, box or kit: open (or close) its window
    if instanceof(e.item, "InventoryContainer") and e.item:getInventory() then
        KnoxContainerWindow.toggle(e.item, self.playerNum)
        return
    end
    local page = getPlayerInventory(self.playerNum)
    if page and page.inventoryPane then
        page.inventoryPane:doContextualDblClick(e.item)
    end
end

function KnoxGridView:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end   -- (an item is held: the button may turn it, see KnoxDragLayer)

    local e = self:entityUnderMouse()
    if not e then return true end
    local act = KnoxControls.actionFor("mouse", KnoxControls.mods() .. "rmb")
    if act then self:doAction(act, e) end
    return true
end

--- The game's item menu for a tile (for the whole selection, if the tile is in it).
function KnoxGridView:openMenu(e, x, y)
    local player = self:player()
    local isInInv = self.container:isInCharacterInventory(player)
    -- a selected tile: the menu works on the whole selection
    local items, entries = {}, {}
    for _, g in ipairs(KnoxSelect.group(e, self, KnoxActions.allViews())) do
        local list = g.entity.items
        for _, it in ipairs(list) do table.insert(items, it) end
        -- a stack goes to the game's menu as its own list does it: one entry,
        -- a group whose first item is there twice (its header). Given item by
        -- item, the menu counted a stack as many things and left out what it
        -- offers for one thing only ("Merge all" of thread, renaming a key...).
        if #list == 1 then
            table.insert(entries, list[1])
        else
            local group = {list[1]}
            for _, it in ipairs(list) do table.insert(group, it) end
            table.insert(entries, {items = group, count = #list, name = list[1]:getName(),
                                   cat = list[1]:getDisplayCategory() or list[1]:getCategory()})
        end
    end
    if KnoxContextMenu then KnoxContextMenu.setTarget(items, self.playerNum) end
    ISInventoryPaneContextMenu.createMenu(self.playerNum, isInInv, entries,
        self:getAbsoluteX() + x, self:getAbsoluteY() + y)
    return true
end
