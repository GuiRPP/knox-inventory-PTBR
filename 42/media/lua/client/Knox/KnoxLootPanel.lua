-- "Surroundings" column: the containers around the character (the floor,
-- furniture, corpses, vehicle parts, bags lying around) on the left, the grid
-- of the chosen one on the right.
--
-- The list comes from the game's own loot window (kept hidden): its
-- refreshBackpacks() knows walls, doors, vehicles and safehouse rules. We call
-- it ourselves since a hidden window doesn't update.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxGridView"
require "Knox/KnoxActions"
require "Knox/KnoxSearch"
require "ISUI/LootWindow/ISLootWindowContainerControls"

local T = KnoxTheme
local REFRESH_MS = 1000

-- Scrolling area holding the grid ------------------------------------------------

KnoxLootGridArea = ISPanel:derive("KnoxLootGridArea")

function KnoxLootGridArea:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.contentH = 0
    return o
end

function KnoxLootGridArea:setView(view)
    if self.view then self:removeChild(self.view) end
    self.view = view
    self:setYScroll(0)
    if view then
        view:setX(0)
        view:setY(0)
        self:addChild(view)
    end
end

function KnoxLootGridArea:markAllDirty()
    for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
end

function KnoxLootGridArea:clampScroll()
    local minY = math.min(0, self:getHeight() - self.contentH)
    local ys = self:getYScroll()
    if ys < minY then self:setYScroll(minY) elseif ys > 0 then self:setYScroll(0) end
end

function KnoxLootGridArea:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * T.cell)
    self:clampScroll()
    return true
end

function KnoxLootGridArea:prerender()
    self.contentH = self.view and self.view:getHeight() or 0
    self:setScrollChildren(true)
    self:setScrollHeight(self.contentH)
    self:clampScroll()
    -- (scrolled to the top: a few pixels of room above the grid, so a tile of
    -- its first row lifted under the mouse keeps its top frame - KnoxGridView
    -- lift; scrolled down, the rows above must stay hidden)
    local up = self:getYScroll() >= 0 and math.max(4, math.floor(T.cell / 10)) or 0
    self:setStencilRect(0, -up, self:getWidth(), self:getHeight() + up)
end

function KnoxLootGridArea:render()
    -- a grid taller than the column (a car's boot, a big shelf): its rows fade at
    -- the edges as the inventory column's do (the author, 2026-10-22)
    local now = getTimestampMs()
    local dt = math.min(100, now - (self.fadeMs or now))
    self.fadeMs = now
    T.edgeFades(self, self.contentH, 0, self:getWidth(), dt)
    self:clearStencilRect()
    local h = self:getHeight()
    if self.contentH > h then
        local barH = math.max(T.cell, math.floor(h * h / self.contentH))
        local barY = math.floor(-self:getYScroll() / (self.contentH - h) * (h - barH))
        local c = T.color.tileEdge
        self:drawRect(self:getWidth() - 4, barY - self:getYScroll(), 3, barH, 1, c.r, c.g, c.b)
    end
end

-- Panel ----------------------------------------------------------------------------

-- A container the character may not open: one built by another player and
-- locked to them - the only case the game itself locks a container button.
-- (Asked of the object, not of the game's button: a mod that rebuilds those
-- buttons left them without `onclick`, and every row, the floor too, came out
-- locked - a player's screenshots, 2026-10-16.)
local function lockedFor(container, player)
    local obj = container:getParent()
    return player ~= nil and obj ~= nil and instanceof(obj, "IsoThumpable") and obj:isLockedToCharacter(player) == true
end

KnoxLootPanel = ISPanel:derive("KnoxLootPanel")

function KnoxLootPanel:new(x, y, w, h, playerNum)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.containers = {}
    o.selected = nil
    o.view = nil
    o.lastRefreshMs = 0
    return o
end

function KnoxLootPanel:player()
    return getSpecificPlayer(self.playerNum)
end

function KnoxLootPanel:metrics()
    local ft = T.fontH(T.fontText)
    local m = {}
    m.listW = math.floor(T.cell * 4.6 + 0.5)
    m.rowH = ft * 2 + T.pad
    m.gap = math.max(4, math.floor(T.cell / 8))
    m.gridX = m.listW + T.pad
    m.headerH = T.sectionH + 4
    return m
end

function KnoxLootPanel:createChildren()
    local m = self:metrics()
    self.m = m
    self.area = KnoxLootGridArea:new(m.gridX, m.headerH, self:getWidth() - m.gridX, self:getHeight() - m.headerH)
    self.area:initialise()
    self:addChild(self.area)
    -- big containers get a grid as wide as this column shows (see KnoxGrid.getSize)
    KnoxGrid.worldCols = math.max(8, math.min(12, math.floor((self.area:getWidth() - 6) / T.cell)))
    self:refresh(true)
end

-- Containers ------------------------------------------------------------------------

function KnoxLootPanel:refresh(force)
    local player = self:player()
    local page = getPlayerLoot(self.playerNum)
    if not player or not page then return end
    local now = getTimestampMs()
    local sq, dir = player:getCurrentSquare(), player:getDir()
    -- The game's search for containers around is slow where there are many of
    -- them (a warehouse, a big base): then it is done less often - a change or
    -- a step waits a few of its run times, the look-over without one 40 of them.
    local since = now - self.lastRefreshMs
    local cost = self.refreshCost or 0
    local moved = sq ~= self.lastSquare or dir ~= self.lastDir
    local scanned = false
    if force or ((KnoxLootPanel.dirty or moved) and since >= cost * 4)
        or since > math.max(REFRESH_MS, cost * 40) then
        scanned = true
        KnoxLootPanel.dirty = false
        self.lastSquare, self.lastDir = sq, dir
        page:refreshBackpacks()
        local done = getTimestampMs()
        self.refreshCost = done - now
        self.lastRefreshMs = done
    end

    local only = KnoxLootPanel.onlyOpened()
    -- in a car: the floor outside, to drop things through the door, when the game
    -- lets one (its "Drop": the door or its window open, or no window) - the
    -- game's list has no floor there, and the screen covers the world it was
    -- dropped onto (LBBz, 2026-10-19)
    local carDrop = player:getVehicle() ~= nil and KnoxLootPanel.canDropFromCar(player)
    local backpacks = page.backpacks or {}
    -- (the column's list made anew only when the game's has changed - it refreshes
    -- it on its own too: ISInventoryPage.dirtyUI - or what picks from it has: made
    -- every frame, it cost a table and a few calls into the game per container)
    if scanned or only ~= self.listOnly or self.opened ~= self.listOpened or carDrop ~= self.listCarDrop
            or not self:sameSource(backpacks) then
        self.listOnly, self.listOpened, self.listCarDrop = only, self.opened, carDrop
        local src = {}
        for i, b in ipairs(backpacks) do src[i] = {c = b.inventory, n = b.name, i = b.textureOverride or b.image} end
        self.listSrc = src
        local list = {}
        -- (the setting "Surroundings: only the opened one": that container, the
        -- others of the same piece of furniture - a fridge's freezer, an oven's top
        -- shelf; with the fridge opened its freezer could not be reached, The
        -- laziest's report, 2026-10-16 - and the floor)
        local openedObj = only and self.opened and self.opened:getParent() or nil
        -- (furniture only: a car's trunk opened from outside is that trunk alone)
        if openedObj and (not instanceof(openedObj, "IsoObject") or instanceof(openedObj, "BaseVehicle")) then openedObj = nil end
        for _, b in ipairs(backpacks) do
            local c = b.inventory
            if c and (not only or c == self.opened or c:getType() == "floor"
                    or (openedObj ~= nil and c:getParent() == openedObj)) then
                table.insert(list, {container = c, name = b.name or "?",
                                    icon = b.textureOverride or b.image, locked = lockedFor(c, player)})
            end
        end
        if carDrop then
            table.insert(list, {container = KnoxLootPanel.carFloor(), name = getTextOrNull("IGUI_ContainerTitle_floor") or "",
                                icon = ContainerButtonIcons and ContainerButtonIcons.floor or nil, locked = false})
        end
        self.containers = list
    end
    local list = self.containers

    -- keep the chosen container while it is still around, else take the one
    -- the game picked (the one the character faces), else the first
    local keep = false
    for _, c in ipairs(list) do
        if c.container == self.selected and not c.locked then keep = true end
    end
    if not keep then
        local pick
        for _, c in ipairs(list) do
            if not c.locked and c.container == page.inventory then pick = c.container end
        end
        if not pick then
            for _, c in ipairs(list) do
                if not c.locked then pick = c.container break end
            end
        end
        -- (a failure here is told in the log by name, see report)
        local ok, err = pcall(self.select, self, pick, false)
        if not ok then
            if self.lastFail ~= tostring(err) then
                self.lastFail = tostring(err)
                print("[Knox] surroundings: choosing " .. tostring(pick and pick:getType()) .. " failed: " .. tostring(err))
            end
        end
    else
        -- the game's loot window follows our choice (its context menu
        -- actions like "Put in" use it), silently
        page.inventory = self.selected
        if page.inventoryPane then page.inventoryPane.inventory = self.selected end
    end
    -- (only when the game looked round again or the choice changed: built every
    -- frame it cost a string per container per frame - a performance pass, 2026-10-16)
    if scanned or self.selected ~= self.reportedSel then
        self.reportedSel = self.selected
        self:report(page, only)
    end
end

--- Is the game's list the one the column's list was made from? (table reads only:
--- its buttons are a pool the game fills anew, so their containers are compared)
function KnoxLootPanel:sameSource(backpacks)
    local src = self.listSrc
    if not src or #src ~= #backpacks then return false end
    for i, b in ipairs(backpacks) do
        local s = src[i]
        if s.c ~= b.inventory or s.n ~= b.name or s.i ~= (b.textureOverride or b.image) then return false end
    end
    return true
end

-- What the column was given and what it made of it, a line in console.txt
-- each time that changes (40 at most a game). A player's containers were all
-- shown locked and none could be chosen, and the log had nothing to tell why
-- (2026-10-16).
local reportsLeft = 40
function KnoxLootPanel:report(page, only)
    if reportsLeft <= 0 then return end
    local parts = {}
    for _, b in ipairs(page.backpacks or {}) do
        local c = b.inventory
        local mark = ""
        if c == nil then mark = "!nocontainer"
        else
            for _, e in ipairs(self.containers) do
                if e.container == c and e.locked then mark = "!locked" end
            end
            if c == self.selected then mark = mark .. "*" end
        end
        table.insert(parts, tostring(c and c:getType() or "?") .. mark .. (b.onclick == nil and "~" or ""))
    end
    local line = "game " .. #(page.backpacks or {}) .. " [" .. table.concat(parts, " ") .. "], listed " .. #self.containers
        .. ", scope " .. tostring(T.choice("loot.scope")) .. (only and " (only opened)" or "")
        .. ", chosen " .. tostring(self.selected and self.selected:getType() or "none")
        .. ", grid " .. tostring(self.view ~= nil)
    if line == self.lastReport then return end
    self.lastReport = line
    reportsLeft = reportsLeft - 1
    print("[Knox] surroundings: " .. line)
end

--- Does the column list only the opened container and the floor? (the setting
--- loot.scope; "auto": while Viewpoint's own view is on - looking around in 3D,
--- the containers are gone through one by one, as in its crosshair loot menu;
--- not with OldPoint's overhead camera, which sees all around as the game's does)
function KnoxLootPanel.onlyOpened()
    -- in a car: its seats, glove box and trunk are all within reach (and nothing
    -- there is "opened" from the world: the list would be empty)
    local p = getSpecificPlayer(0)
    if p and p:getVehicle() then return false end
    local v = T.choice("loot.scope")
    if v == "opened" then return true end
    if v == "all" then return false end
    return KnoxCompat ~= nil and KnoxCompat.viewpointLooking()
end

--- May the character drop things out of the car? The game's own rule for its
--- "Drop" (ISInventoryPaneContextMenu): a door by the seat, and that door or its
--- window open (or broken, or no window). Its drop goes through that door.
function KnoxLootPanel.canDropFromCar(player)
    local vehicle = player:getVehicle()
    if not vehicle then return false end
    local ok, can = pcall(function()
        local door = vehicle:getPassengerDoor(vehicle:getSeat(player))
        if not door then return false end
        local d = door:getDoor()
        if not d or d:isOpen() then return true end
        local wp = VehicleUtils.getChildWindow(door)
        local w = wp and wp:getWindow()
        return w == nil or w:isOpen() or w:isDestroyed()
    end)
    return ok and can == true
end

--- The floor shown in a car: a container of Knox's own, always empty (the
--- game's floor container isn't emptied in a car - it still held what lay by
--- the car when the character got in). What is dropped on it goes out (KnoxDrag.moveTo).
local carFloor = nil
function KnoxLootPanel.carFloor()
    if not carFloor then
        carFloor = ItemContainer.new("floor", nil, nil)
        carFloor:setExplored(true)
    end
    return carFloor
end

--- Show a given container (one clicked in the world): fresh list, then select it.
--- It is "the opened one" for the setting above.
function KnoxLootPanel:focus(container)
    self.opened = container
    self:refresh(true)
    for _, c in ipairs(self.containers) do
        if c.container == container then
            if not c.locked then self:select(container, false) end   -- the game already played the open sound
            return
        end
    end
    -- (asked to open a container the game's own list doesn't have - Viewpoint's
    -- loot key, a mod: said once per kind, "containers don't open" can be told apart)
    local kind = tostring(container and container:getType())
    KnoxLootPanel.notListed = KnoxLootPanel.notListed or {}
    if container and not KnoxLootPanel.notListed[kind] then
        KnoxLootPanel.notListed[kind] = true
        print("[Knox] surroundings: asked to open " .. kind .. ", not in the game's list of containers around")
    end
end

-- Looked into already: a container opened in Knox gets a mark in the list. It
-- is kept on what the container belongs to (the furniture, the corpse, the car
-- part, the bag), so it lasts with the save. The game's own "explored" can't
-- tell: it is set on every container around when they get their loot.

--- What keeps the mark and under which key; nil when none can (the floor, the
--- character's own pockets - never searched).
local function seenHolder(container)
    if container:getType() == "floor" then return nil end
    local item = container:getContainingItem()
    if item then return item, "knoxSeen" end
    local part = container:getVehiclePart()
    if part then return part, "knoxSeen" end
    local obj = container:getParent()
    if obj and instanceof(obj, "IsoPlayer") then return nil end
    -- an object may hold several containers (a fridge and its freezer)
    if obj and obj.getModData then return obj, "knoxSeen_" .. tostring(container:getType()) end
    return nil
end

--- Can the mark be kept for this container at all?
function KnoxLootPanel.canMark(container)
    return seenHolder(container) ~= nil
end

-- (in a game with others a search is the character's own - the author, 2026-10-20:
-- kept by the server per character under the container's key, KnoxNet)
local function netKey(container)
    if not (KnoxNet and KnoxNet.mp()) then return nil end
    return KnoxGrid.containerKey(container, nil)
end

function KnoxLootPanel.isSeen(container)
    local owner, key = seenHolder(container)
    if not owner then return false end
    local nk = netKey(container)
    if nk then return KnoxNet.isSeen(nk) end
    -- (asked every frame for every row and tile: a thing or object with no
    -- modData yet is not given an empty one just by being looked at)
    if (instanceof(owner, "InventoryItem") or instanceof(owner, "IsoObject")) and not owner:hasModData() then return false end
    return owner:getModData()[key] == true
end

function KnoxLootPanel.markSeen(container)
    local owner, key = seenHolder(container)
    if not owner then return end
    local nk = netKey(container)
    if nk then KnoxNet.setSeen(nk, true) else owner:getModData()[key] = true end
end

--- Not looked into any more (the filming mode's "search again": KnoxStudio).
function KnoxLootPanel.unmarkSeen(container)
    local owner, key = seenHolder(container)
    if not owner then return end
    local nk = netKey(container)
    if nk then
        KnoxNet.setSeen(nk, false)
    elseif not (instanceof(owner, "InventoryItem") or instanceof(owner, "IsoObject")) or owner:hasModData() then
        owner:getModData()[key] = nil
    end
end

function KnoxLootPanel:select(container, byUser)
    if container == self.selected and self.view then return end
    -- the chosen row's sand frame slides from the old row to the new one
    for i, c in ipairs(self.containers) do
        if c.container == self.selected then
            self.selFrom = (i - 1) * (self.m.rowH + self.m.gap)
            self.selMs = getTimestampMs()
        end
    end
    self.selected = container
    local page = getPlayerLoot(self.playerNum)
    if container and page then
        if byUser then
            page:setNewContainer(container)   -- also plays the open sound
        else
            page.inventory = container
            if page.inventoryPane then page.inventoryPane.inventory = container end
        end
    end
    local oldW = self.view and self.view:getWidth() or 0
    local oldH = self.view and self.view:getHeight() or 0
    -- what lay in the grid being left: it fades out while the grid changes its size
    local gone = {}
    if self.view and byUser then
        for _, e in ipairs(self.view.layout.placed) do
            -- (not what a search left half-way has not found yet: it must not show
            -- while fading out either - seen in game 2026-10-14)
            -- (the thing being found right now: its filling plate fades out with the rest)
            -- (kept in pixels: a bag with compartments has its tiles where they are)
            local st, frac = KnoxSearch.stateOf(e.item)
            local px, py, pw, ph = self.view:tileRect(e)
            if px then px = px + self.view:getX() end
            if px and st == "current" and #gone < 80 then
                table.insert(gone, {searchPlate = true, frac = frac, x = px, y = py, w = pw, h = ph, a = 1})
            end
            if px and not e.reserved and #gone < 80 and not KnoxSearch.isHidden(e.item) then
                table.insert(gone, {item = e.item, x = px, y = py, w = pw, h = ph, a = e.ghost and 0.4 or 1})
            end
        end
    end
    if container then
        self.view = KnoxGridView:new(0, 0, container, self.playerNum)
        self.view:initialise()
        -- not looked into yet: it is searched first, and marked when that is done
        -- (see KnoxSearch); else it is marked at once
        if not KnoxSearch.begin(container, self.view.layout) then KnoxLootPanel.markSeen(container) end
        if byUser then
            local now = getTimestampMs()
            -- the grid first changes its size from the last container's to this
            -- one's (an empty grid stretching or shrinking: see prerender)...
            local wait = 0
            if oldW > 0 then
                self.morph = {w = oldW, h = oldH, ms = now, gone = gone}
                wait = 150
            end
            -- ...then its things settle into their cells, row after row
            for _, e in ipairs(self.view.layout.placed) do
                KnoxGridView.settle[e.item] = now + wait + math.min(160, e.y * 22)
            end
        end
    else
        self.view = nil
    end
    self.area:setView(self.view)
end

-- Drawing -------------------------------------------------------------------------------

-- Which picture a button of the object's own action gets, by the name of the
-- game's handler behind it (first match; anything else: three dots).
local ACTION_ICONS = {
    {"MoveToFloor", "floor"}, {"RemoveAll", "cross"}, {"RemoveCampfire", "cross"},
    {"Settings", "sliders"}, {"SetMode", "sliders"}, {"Toggle", "power"},
    {"RemoveTank", "minus"}, {"PutOut", "minus"}, {"AddTank", "plus"}, {"AddFuel", "plus"}, {"AddCorpse", "plus"},
    {"LightFuel", "fire"}, {"LockTrunk", "lock"}, {"CloseTrunk", "lid"}, {"WearAll", "plus"},
}

local function actionIcon(handlerType)
    for _, pair in ipairs(ACTION_ICONS) do
        if string.find(handlerType or "", pair[1], 1, true) then return pair[2] end
    end
    return "dots"
end

--- How far right the grid stands under its header: a bag with compartments
--- narrower than the header (six cells at least) in the middle, symmetric as its
--- compartments are; a plain grid at the left.
function KnoxLootPanel:gridOffset()
    local v = self.view
    if not (v and v.layout and v.layout.shape) then return 0 end
    local w = math.min(self:getWidth() - self.m.gridX, math.max(v:getWidth(), 6 * T.cell + 1))
    return math.max(0, math.floor((w - v:getWidth()) / 2))
end

--- The chosen container's header: as wide as its grid (six cells at least),
--- the name and the size on the left, small square picture buttons at its
--- right end - Sort, Take all, then one for each action the object itself
--- offers (move to the floor, remove all, switch on, settings, lock the
--- boot...). A button's name shows under it while the mouse is on it.
--- @return {w, h, info, bad, textRight, buttons = {{rect, title, id, icon, action}}}
function KnoxLootPanel:headerLayout()
    local m, pad = self.m, T.pad
    local L = self.view and self.view.layout
    local w = math.min(self:getWidth() - m.gridX, math.max(self.view and self.view:getWidth() or 0, 6 * T.cell + 1))
    -- between two containers the header goes from the last one's width to this one's with the grid
    local morph = self.morph
    if morph then
        local t = T.anim(math.max(0, math.min(1, (getTimestampMs() - morph.ms) / 150)))
        local e = 1 - (1 - t) * (1 - t)
        local w0 = math.min(self:getWidth() - m.gridX, math.max(morph.w, 6 * T.cell + 1))
        w = math.floor(w0 + (w - w0) * e + 0.5)
    end
    local out = {w = w, h = m.headerH, buttons = {}, info = "", textRight = m.gridX + w - pad}
    if not (L and self.selected) then return out end
    out.info = KnoxGrid.sizeText(L)
    -- being searched: how many things are found so far, of all in it - things,
    -- as the list's plate counts (the tiles of this go only, 0 / 5, didn't
    -- count what an earlier go had found while the plate said 2)
    if KnoxSearch.busy(self.selected) then
        out.info = getText("IGUI_Knox_Searching", KnoxSearch.found(), self.selected:getItems():size())
    end
    out.bad = #L.overflow > 0
    if out.bad then out.info = getText("IGUI_Knox_Overflow", #L.overflow) .. "  " .. out.info end
    local list = {{title = getText("IGUI_Knox_SortFull"), id = "sort", icon = "sort"}}
    -- the eye: the layout's silhouettes shown or hidden (only where there is a layout)
    if KnoxOrder.layoutOf(self.selected) then
        table.insert(list, {title = getText(KnoxOrder.ghostsOn() and "IGUI_Knox_Order_HideGhosts" or "IGUI_Knox_Order_ShowGhosts"),
                            id = "ghosts", icon = "eye"})
    end
    table.insert(list, {title = getText("IGUI_Knox_TakeAll"), id = "take", icon = "take"})
    for _, a in ipairs(self:objectActions()) do
        table.insert(list, {title = a.title, id = "act", icon = actionIcon(a.type), action = a})
    end
    local s = m.headerH - 6
    local x = m.gridX + w - 3
    for _, b in ipairs(list) do
        b.rect = {x - s, 3, s, s}
        out.textRight = b.rect[1] - pad
        x = x - s - 4
        table.insert(out.buttons, b)
    end
    return out
end

--- The picture of a header button, drawn of plain rectangles inside rect `r`.
local function drawIcon(ui, r, icon, c, a)
    local s = r[3]
    local u = math.max(2, math.floor(s / 9 + 0.5))        -- stroke
    local p = math.floor(s * 0.24 + 0.5)                  -- margin
    local x0, y0, w = r[1] + p, r[2] + p, s - p * 2
    local x1, y1 = x0 + w, y0 + w
    local cx, cy = r[1] + math.floor(s / 2), r[2] + math.floor(s / 2)
    local hu = math.floor(u / 2)
    local function box(x, y, bw, bh) ui:drawRect(x, y, bw, bh, a or 1, c.r, c.g, c.b) end
    if icon == "eye" then
        KnoxOrder.drawEye(ui, r, c, KnoxOrder.ghostK(), a)
    elseif icon == "sort" then
        -- three bars, each shorter than the one above
        local step = math.floor((w - u) / 2)
        box(x0, y0, w, u)
        box(x0, y0 + step, math.floor(w * 0.66 + 0.5), u)
        box(x0, y0 + step * 2, math.floor(w * 0.33 + 0.5), u)
    elseif icon == "take" then
        -- an arrow to the left, towards the character's bags, onto a line
        local head = math.max(3, math.floor(w * 0.36 + 0.5))
        local tip = x0 + u + 1
        box(tip + head, cy - hu, x1 - tip - head, u)
        for i = 0, head - 1 do box(tip + i, cy - i, 1, i * 2 + 1) end
        box(x0, y0, u, w)
    elseif icon == "floor" then
        -- an arrow down onto a line: to the floor
        local head = math.max(3, math.floor(w * 0.36 + 0.5))
        local base = y1 - u
        local tip = base - 2
        box(cx - hu, y0, u, tip - head - y0 + 1)
        for i = 0, head - 1 do box(cx - i, tip - i, i * 2 + 1, 1) end
        box(x0, base, w, u)
    elseif icon == "cross" then
        for i = 0, w - u do
            box(x0 + i, y0 + i, u, u)
            box(x1 - u - i, y0 + i, u, u)
        end
    elseif icon == "plus" or icon == "minus" then
        box(x0, cy - hu, w, u)
        if icon == "plus" then box(cx - hu, y0, u, w) end
    elseif icon == "power" then
        -- a bar in an open ring
        box(cx - hu, y0 - 1, u, math.floor(w * 0.5))
        local top = y0 + math.floor(w * 0.3)
        box(x0, top, u, y1 - top)
        box(x1 - u, top, u, y1 - top)
        box(x0, y1 - u, w, u)
    elseif icon == "sliders" then
        -- three lines, a knob at a different place on each
        local step = math.floor((w - u) / 2)
        local knob = u + 2
        for i = 0, 2 do
            local y = y0 + step * i
            box(x0, y, w, math.max(1, u - 1))
            local kx = x0 + math.floor((w - knob) * ((i == 1) and 0.75 or (i == 0 and 0.2 or 0.45)))
            box(kx, y - 1, knob, u + 1)
        end
    elseif icon == "fire" then
        -- a flame: a pointed top widening to a flat base
        for i = 0, w - 1 do
            local half = math.floor(i * 0.5)
            box(cx - half, y0 + i, half * 2 + 1, 1)
        end
        box(x0 + 1, y1 - u, w - 2, u)
    elseif icon == "lock" then
        local body = math.floor(w * 0.55)
        box(x0, y1 - body, w, body)
        local sw = math.floor(w * 0.6)
        local sx = cx - math.floor(sw / 2)
        box(sx, y0, sw, u)
        box(sx, y0, u, w - body)
        box(sx + sw - u, y0, u, w - body)
    elseif icon == "lid" then
        -- closing: a lid coming down onto a box
        box(x0, y0, w, u)
        for i = 0, math.floor(w * 0.3) do box(cx - i, y0 + u + 2 + math.floor(w * 0.3) - i, i * 2 + 1, 1) end
        box(x0, y1 - u, w, u)
    else
        -- three dots
        local d = u + 1
        local gap = math.floor((w - d * 3) / 2)
        for i = 0, 2 do box(x0 + i * (d + gap), cy - math.floor(d / 2), d, d) end
    end
end
KnoxLootPanel.drawIcon = drawIcon   -- (the Sort button of the character's bags draws the same picture)
local inRect = T.inRect

-- What the game's loot window offers for the object of the chosen container
-- (a bin's "Remove all", a stove's "Turn on" and settings, a fireplace's fuel,
-- a car trunk's lock...): the game's own handlers say when and what
-- (ISLootWindowContainerControls); Knox draws them as its buttons in the
-- header. Take all stays Knox's own; picture-only buttons are left out.
local SKIP_HANDLERS = {
    ISLootWindowObjectControlHandler_TakeAll = true, ISLootWindowFloorControlHandler_TakeAll = true,
    ISLootWindowObjectControlHandler_TakeSameType = true, ISLootWindowFloorControlHandler_TakeSameType = true,
}

--- The object a container belongs to, as the game's loot window finds it.
local function objectOf(container)
    local outer = container:getOutermostContainer()
    if outer and outer:getVehiclePart() then return outer:getVehiclePart():getVehicle() end
    if container:getContainingItem() then return container:getContainingItem():getWorldItem() end
    return container:getParent()
end

--- {handler, title} for the chosen container: asked of the game's handlers a
--- few times a second (some twenty of them, a pcall or two each - they were asked
--- every frame), anew at once when another container is chosen or a button of
--- the header is pressed (KnoxLootPanel:actionsChanged).
local ACTIONS_MS = 200

function KnoxLootPanel:objectActions()
    local now = getTimestampMs()
    local c = self.actionsFor
    if c and c.container == self.selected and now - c.ms < ACTIONS_MS then return c.list end
    local list = self:askObjectActions()
    self.actionsFor = {container = self.selected, ms = now, list = list}
    return list
end

function KnoxLootPanel:actionsChanged()
    self.actionsFor = nil
end

function KnoxLootPanel:askObjectActions()
    local out = {}
    local page = getPlayerLoot(self.playerNum)
    local container = self.selected
    if not page or not container or not ISLootWindowContainerControls_HandlerList then return out end
    local object = objectOf(container)
    local list
    if object then
        list = ISLootWindowContainerControls_HandlerList
    elseif container:getType() == "floor" then
        list = ISLootWindowContainerControls_FloorHandlerList
    end
    if not list then return out end
    self.handlers = self.handlers or {}
    local player = self:player()
    for _, cls in ipairs(list) do
        if not SKIP_HANDLERS[cls.Type] then
            local h = self.handlers[cls]
            if not h then
                h = cls:new()
                self.handlers[cls] = h
            end
            h.lootWindow, h.playerNum, h.playerObj = page, self.playerNum, player
            h.object, h.container = object, container
            local ok, visible = pcall(h.shouldBeVisible, h)
            if ok and visible then
                local ok2, control = pcall(h.getControl, h)
                local title = ok2 and control and control.title or ""
                if title ~= "" then
                    -- a switch (stove, washer, dryer, barbecue): is the thing on now?
                    local on = false
                    if object and string.find(cls.Type or "", "Toggle", 1, true) then
                        if object.Activated then on = object:Activated() == true
                        elseif object.isActivated then on = object:isActivated() == true end
                    end
                    table.insert(out, {handler = h, title = title, type = cls.Type, on = on})
                end
            end
        end
    end
    return out
end

function KnoxLootPanel:runAction(a)
    local ok, err = pcall(a.handler.perform, a.handler)
    if not ok then print("[Knox] loot action: " .. tostring(err)) end
    self:actionsChanged()   -- (a switch turned: lit or not at once)
    -- the game's "Remove all?" question: over the Knox screen, always
    local page = getPlayerLoot(self.playerNum)
    local dlg = page and page.inventoryPane and page.inventoryPane.removeAllDialog
    if dlg then
        dlg:setAlwaysOnTop(true)
        dlg:bringToTop()
    end
    -- a menu the handler opened (fuel to add...) goes to the mouse, not to the hidden game window
    local menu = getPlayerContextMenu(self.playerNum)
    if menu and menu:getIsVisible() then
        menu:setX(getMouseX())
        menu:setY(getMouseY())
    end
end

function KnoxLootPanel:prerender()
    if self.queuedAction then
        local a = self.queuedAction
        self.queuedAction = nil
        self:runAction(a)
    end
    self:refresh(false)
    KnoxSearch.tick(self.selected, self.view and self.view.layout)
    local m, pad = self.m, T.pad
    local player = self:player()
    local ft = T.fontH(T.fontText)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()

    -- container list: scrolls with the wheel when it is taller than the column
    -- (a shop, a car with all its parts), clipped to the column
    local listH = self:getHeight()
    local total = #self.containers * (m.rowH + m.gap) - m.gap
    self.listScroll = math.max(0, math.min(self.listScroll or 0, total - listH))
    self:setStencilRect(0, 0, m.listW, listH)
    self.rowRects = {}
    local y = -self.listScroll
    for _, c in ipairs(self.containers) do
        local r = {0, y, m.listW, m.rowH}
        table.insert(self.rowRects, {rect = r, entry = c})
        local active = c.container == self.selected
        local hover = over and inRect(mx, my, r) and not c.locked
        T.rect(self, r[1], r[2], r[3], r[4], active and T.color.header or T.color.cell, T.bgAlpha())
        if hover then self:drawRect(r[1], r[2], r[3], r[4], 0.05, 1, 1, 1) end
        -- (while the chosen row's frame is sliding to it, the row has a plain one)
        local sliding = active and self.selMs ~= nil and T.anim((getTimestampMs() - self.selMs) / 140) < 1
        if sliding then self.selRow = r end
        T.tileFrame(self, r[1], r[2], r[3], r[4], (active and not sliding) and T.color.accent or T.color.border)   -- two pixels thick
        -- an item held over the row: it can be dropped on it, into that container
        -- (green: it may go there, red: it may not)
        if hover and KnoxDrag.isActive() then
            local dc = (KnoxDrag.canDropInto(c.container, player) and not KnoxDrag.tooFarFor(player, c.container)) and T.color.ok or T.color.bad
            self:drawRect(r[1], r[2], r[3], r[4], 0.18, dc.r, dc.g, dc.b)
            T.tileFrame(self, r[1], r[2], r[3], r[4], dc)
        end
        local ix = 12
        local iconS = math.floor((m.rowH - 7) * 0.7)   -- the icon's place; the picture itself: see below
        -- icon, name and count: centred in the row
        local area = m.rowH
        local iy = y + math.floor((area - iconS) / 2)
        local ty = y + math.floor((area - ft) / 2)
        -- the picture sits on a small framed plate of its own, like an item on
        -- its tile (bare on the row it looked lost); sand frame on the chosen one
        local fp = 3
        T.rect(self, ix - fp, iy - fp, iconS + fp * 2, iconS + fp * 2, T.color.header)
        T.tileFrame(self, ix - fp, iy - fp, iconS + fp * 2, iconS + fp * 2, active and T.color.accent or T.color.tileEdge,
            c.locked and 0.4 or 1)
        if c.icon then
            -- the game's container pictures are small pixel art: stretched or
            -- squeezed to an odd size they blur. Drawn at their own size or a
            -- whole number of times it, centred in the icon's place
            local tw, th = c.icon:getWidth(), c.icon:getHeight()
            local side = math.max(tw, th)
            if side > 0 and side <= iconS then
                local n = math.max(1, math.floor(iconS / side))
                self:drawTextureScaled(c.icon, ix + math.floor((iconS - tw * n) / 2), iy + math.floor((iconS - th * n) / 2),
                    tw * n, th * n, c.locked and 0.4 or 1, 1, 1, 1)
            else
                self:drawTextureScaledAspect(c.icon, ix, iy, iconS, iconS, c.locked and 0.4 or 1, 1, 1, 1)
            end
        end
        -- how many things are in it, in a small sand frame near the right edge.
        -- Not looked into yet: nobody knows - the plate is grey and empty;
        -- looked into: sand with the number, and the name a little dimmer
        local seen = c.container:getType() == "floor" or KnoxLootPanel.isSeen(c.container)
        local unknown = not seen and not c.locked
        local countText = unknown and "" or tostring(c.container:getItems():size())
        -- Looked into but not searched through (being searched now, or a search
        -- left half-way - switched to another container): how many things are
        -- found so far, sand on a dark plate in a sand frame. The rest of what is
        -- in it stays unknown; the plate fills with sand once all is found. (It
        -- was grey and empty as if never looked into: a player's remark, 14.10.)
        local partial = false
        if unknown then
            local busy = KnoxSearch.busy(c.container)
            local n = busy and KnoxSearch.found() or KnoxSearch.knownIn(c.container)
            if busy or n > 0 then
                unknown, partial = false, true
                countText = tostring(n)
            end
        end
        -- a search by name is on: a container looked into says how many things
        -- in it match (sand plate; grey with a dim 0 when none) - a half searched
        -- one, how many of what is found so far. One not looked into says
        -- nothing: nobody knows what is in it.
        local q = KnoxGridView.query()
        local plateOff = unknown
        local zero = false
        if q and (seen or partial) and not c.locked then
            local n = seen and KnoxGridView.countIn(c.container, q) or KnoxSearch.knownIn(c.container, q)
            countText = tostring(n)
            plateOff = n == 0
            zero = n == 0
            if zero then partial = false end
        end
        local cf = T.fontCaps
        local boxH = ft + 4
        local boxW = math.max(boxH, T.measure(cf, countText) + 10)
        local boxX = m.listW - 10 - boxW
        local cw = boxW + 4
        local nameX = ix + iconS + 12
        local nameC = c.locked and T.color.dim or (active and T.color.bright or (seen and T.color.dim or T.color.text))
        -- (a long name is not cut with a dot: it slides to show its end and back -
        -- the author, 2026-10-21: «Водительское сидень.»)
        self.nameSt = self.nameSt or {}
        local nst = self.nameSt[c.container]
        if not nst then
            nst = {}
            self.nameSt[c.container] = nst
        end
        T.marquee(self, nst, c.name, nameX, ty, m.listW - nameX - cw - 12, nameC, T.fontText)
        -- a plate with the number in the heavier caps font: sand with black
        -- when looked into, plain grey when not yet; centred by its pixels
        -- The plate turns from grey to sand over a moment (a container just
        -- looked into, a search begun), and its number rolls when it changes.
        self.plates = self.plates or {}
        local st = self.plates[c.container]
        local nowMs = getTimestampMs()
        if not st then
            st = {mix = (unknown or partial) and 0 or 1, part = partial and 1 or 0, ms = nowMs}
            self.plates[c.container] = st
        end
        local want = (plateOff or partial) and 0 or 1
        local wantPart = partial and 1 or 0
        local k = T.anim(math.min(1, math.min(100, nowMs - st.ms) / 140))
        st.mix = st.mix + (want - st.mix) * k
        if math.abs(want - st.mix) < 0.02 then st.mix = want end
        st.part = (st.part or 0) + (wantPart - (st.part or 0)) * k
        if math.abs(wantPart - st.part) < 0.02 then st.part = wantPart end
        st.ms = nowMs
        local pa = c.locked and 0.35 or 1
        st.base = T.mixInto(st.base or {}, T.color.tileEdge, T.color.accent, st.mix)
        local base = st.base
        if st.part > 0 then
            st.basePart = T.mixInto(st.basePart or {}, base, T.color.cell, st.part)
            base = st.basePart
        end
        T.rect(self, boxX, ty - 2, boxW, boxH, base, pa)
        if st.part > 0 then
            -- half searched: a sand frame and a sand number on the dark plate
            -- (2 px, as the frame of the row's icon - the user, 14.10)
            local a = T.color.accent
            T.tileFrame(self, boxX, ty - 2, boxW, boxH, a, st.part * pa)
            T.rollNumber(self, st, countText, boxX, ty - 2, boxW, boxH, a.r, a.g, a.b, st.part, cf)
        else
            T.rollNumber(self, st, countText, boxX, ty - 2, boxW, boxH, 0.08, 0.08, 0.08, st.mix, cf)
        end
        if zero then
            local dc = T.color.dim
            T.inkCentre(self, "0", boxX, ty - 2, boxW, boxH, dc.r, dc.g, dc.b, 1 - st.mix, cf)   -- (by its pixels, as the plates' numbers)
        end
        -- (just clicked: the row dips for a moment)
        local rp = self.rowPress
        if rp and rp.container == c.container then
            local pt = T.anim((nowMs - rp.ms) / 130)
            if pt < 1 then
                self:drawRect(r[1] + 2, r[2] + 2, r[3] - 4, r[4] - 4, 0.22 * (1 - pt), 0, 0, 0)
            else
                self.rowPress = nil
            end
        end

        y = y + m.rowH + m.gap
    end
    -- the chosen row's frame on its way from the row chosen before
    if self.selRow and self.selMs and self.selFrom then
        local t = T.anim((getTimestampMs() - self.selMs) / 140)
        if t < 1 then
            local k = 1 - (1 - t) * (1 - t)
            local r = self.selRow
            local from = self.selFrom - self.listScroll
            T.tileFrame(self, r[1], math.floor(from + (r[2] - from) * k + 0.5), r[3], r[4], T.color.accent)
        end
    end
    self.selRow = nil
    self:clearStencilRect()
    if total > listH then
        local barH = math.max(T.cell, math.floor(listH * listH / total))
        local barY = math.floor(self.listScroll / (total - listH) * (listH - barH))
        local c = T.color.tileEdge
        self:drawRect(m.listW + 2, barY, 3, barH, 1, c.r, c.g, c.b)
    end

    -- header of the chosen container
    local hx = m.gridX
    local H = self:headerLayout()
    self.header = H
    if self.view then
        local gx = self:gridOffset()
        if self.view:getX() ~= gx then self.view:setX(gx) end
    end
    self.iconHint = nil
    if self.area:getY() ~= H.h then self.area:setY(H.h) end
    if self.area:getHeight() ~= self:getHeight() - H.h then self.area:setHeight(self:getHeight() - H.h) end
    T.rect(self, hx, 0, H.w, H.h, T.color.header, T.bgAlpha())
    -- between two containers: an empty grid going from the size of the last
    -- one to the size of this one; then the real grid
    local morph = self.morph
    if morph and self.view then
        local t = T.anim((getTimestampMs() - morph.ms) / 150)
        if t >= 1 then
            self.morph = nil
            self.view:setVisible(true)
        else
            self.view:setVisible(false)
            local e = 1 - (1 - t) * (1 - t)
            local cs = T.cell
            local gw = math.floor(morph.w + (self.view:getWidth() - morph.w) * e + 0.5)
            local gh = math.min(math.floor(morph.h + (self.view:getHeight() - morph.h) * e + 0.5), self:getHeight() - H.h)
            local shape = self.view.layout and self.view.layout.shape
            if shape then
                -- into a bag with compartments: the plate gives way to them as it
                -- takes their size (not a plain grid that snaps into them at the end)
                T.rect(self, hx, H.h, gw, gh, T.color.cell, T.gridAlpha() * (1 - e))
                KnoxGridView.drawShape(self, hx + self:gridOffset(), H.h, shape, cs, gh, e)
            else
                T.rect(self, hx, H.h, gw, gh, T.color.cell, T.gridAlpha())
                local line = T.color.line
                local la = T.gridLineAlpha()
                for i = 0, math.floor(gw / cs) do self:drawRect(hx + i * cs, H.h, 1, gh, la, line.r, line.g, line.b) end
                for j = 0, math.floor(gh / cs) do self:drawRect(hx, H.h + j * cs, gw, 1, la, line.r, line.g, line.b) end
                self:drawRect(hx + gw - 1, H.h, 1, gh, la, line.r, line.g, line.b)
                self:drawRect(hx, H.h + gh - 1, gw, 1, la, line.r, line.g, line.b)
            end
            -- the last container's things, fading out where they lay
            local fade = (1 - t) * (1 - t)
            for _, o in ipairs(morph.gone or {}) do
                local tx, ty = hx + o.x, H.h + o.y
                local pw, ph = o.w, o.h
                if o.searchPlate and ty + ph <= self:getHeight() then
                    KnoxSearch.drawCurrent(self, tx, ty, pw, ph, o.frac or 0, o.a * fade)
                elseif ty + ph <= self:getHeight() then
                    local a = o.a * fade
                    T.rect(self, tx, ty, pw, ph, T.category[T.categoryOf(o.item)], a)
                    T.tileFrame(self, tx, ty, pw, ph, T.color.tileFrame, a)
                    local side = math.floor(math.min(pw, ph) * 0.85)
                    ISInventoryItem.renderItemIcon(self, o.item, tx + math.floor((pw - side) / 2), ty + math.floor((ph - side) / 2), a, side, side)
                end
            end
        end
    end
    -- an item held over the header: dropped there it goes into this container
    if self.selected and KnoxDrag.isActive() and over and inRect(mx, my, {hx, 0, H.w, H.h}) then
        local dc = (KnoxDrag.canDropInto(self.selected, player) and not KnoxDrag.tooFarFor(player, self.selected)) and T.color.ok or T.color.bad
        self:drawRect(hx, 0, H.w, H.h, 0.18, dc.r, dc.g, dc.b)
        T.border(self, hx, 0, H.w, H.h, dc)
    end
    -- a container that is a thing to carry (a bag lying around): under the
    -- mouse its header gets a faint sand frame - it can be taken by it
    if self.selected and not KnoxDrag.isActive() and over and inRect(mx, my, {hx, 0, H.w, H.h})
            and KnoxLootPanel.takeable(self.selected, player) then
        local onButton = false
        for _, b in ipairs(H.buttons) do
            if inRect(mx, my, b.rect) then onButton = true end
        end
        if not onButton then T.border(self, hx, 0, H.w, H.h, T.color.accent, 0.55) end
    end
    if self.view and self.selected then
        local name = ""
        for _, c in ipairs(self.containers) do
            if c.container == self.selected then name = c.name end
        end
        local ty = math.floor((m.headerH - ft) / 2)
        local infoW = T.measure(T.fontText, H.info)
        T.textRight(self, H.info, H.textRight, ty, H.bad and T.color.bad or T.color.dim, T.fontText)
        self.headSt = self.headSt or {}
        T.marquee(self, self.headSt, T.upper(name), hx + 6, math.floor((m.headerH - T.fontH(T.fontCaps)) / 2), H.textRight - infoW - pad - hx - 6, T.color.text, T.fontCaps)
        for _, b in ipairs(H.buttons) do
            local hover = over and inRect(mx, my, b.rect)
            -- a switch that is on: a lit green plate with a dark picture
            local lit = b.action and b.action.on
            -- pressed: the plate sinks a pixel into its frame, darker, for as
            -- long as the button is held and a moment after a quick click
            local bp = self.btnPress
            local down = bp ~= nil and bp.title == b.title
                and ((hover and isMouseButtonDown(0)) or T.anim((getTimestampMs() - bp.ms) / 120) < 1)
            local br = b.rect
            if down then br = {b.rect[1] + 1, b.rect[2] + 1, b.rect[3] - 2, b.rect[4] - 2} end
            T.button(self, br, "", {hover = hover})
            if lit then
                T.rect(self, br[1], br[2], br[3], br[4], T.color.good)
                T.border(self, br[1], br[2], br[3], br[4], hover and T.color.bright or T.color.good)
            end
            if down then
                self:drawRect(br[1], br[2], br[3], br[4], 0.3, 0, 0, 0)
                T.border(self, b.rect[1], b.rect[2], b.rect[3], b.rect[4], T.color.accent)
            end
            -- (the object's own actions in green, as the game marks them)
            local c = hover and T.color.accent or (b.action and T.color.good or T.color.text)
            if lit then c = {r = 0.08, g = 0.08, b = 0.08} end
            drawIcon(self, down and {b.rect[1], b.rect[2] + 1, b.rect[3], b.rect[4]} or b.rect, b.icon, c)
            if hover then self.iconHint = b end
        end
    end
end

--- Over the grid (drawn after it): the name of the header button under the mouse.
function KnoxLootPanel:render()
    local b = self.iconHint
    if not b then return end
    local f = T.fontCaps
    local w = T.measure(f, T.upper(b.title)) + 16
    local h = T.fontH(f) + 8
    local x = math.max(self.m.gridX, b.rect[1] + b.rect[3] - w)
    local y = b.rect[2] + b.rect[4] + 4
    T.rect(self, x, y, w, h, T.color.window)
    T.border(self, x, y, w, h, T.color.accent)
    T.text(self, T.upper(b.title), x + 8, y + 4, T.color.text, f)
end
function KnoxLootPanel:onMouseWheel(del)
    -- over the list of containers or the chosen one's header: the wheel goes to
    -- the next or the previous container (as over the game's own loot window),
    -- skipping locked ones, and the list follows so the chosen row stays in view
    local m = self.m
    if self:getMouseX() < m.listW or self:getMouseY() < m.headerH then
        local n = #self.containers
        if n == 0 then return true end
        local at = 0
        for i, c in ipairs(self.containers) do
            if c.container == self.selected then at = i end
        end
        local dir = del > 0 and 1 or -1
        local i = at
        for _ = 1, n do
            i = i + dir
            if i < 1 or i > n then break end              -- (stops at the ends, doesn't wrap)
            if not self.containers[i].locked then
                self:select(self.containers[i].container, true)
                local top = (i - 1) * (m.rowH + m.gap)
                local scroll = self.listScroll or 0
                if top < scroll then scroll = top end
                if top + m.rowH > scroll + self:getHeight() then scroll = top + m.rowH - self:getHeight() end
                self.listScroll = scroll
                break
            end
        end
        return true
    end
    return false
end

-- Taking a container itself: a bag, a backpack, a garbage bag lying around is
-- a thing that can be carried - its header (or its row in the list) is
-- dragged like a tile, to a grid of the character's, a slot on the body, a
-- hand. Furniture, a corpse, a car's trunk are not things: they don't move.
local DRAG_START_PX = 5

--- The item a surroundings container is, if it can be picked up; else nil.
function KnoxLootPanel.takeable(container, player)
    if not container or container:getType() == "floor" or container:getVehiclePart() then return nil end
    local item = container:getContainingItem()
    if not item or not instanceof(item, "InventoryContainer") then return nil end
    local holder = item:getContainer()
    if not holder or (player and holder:isInCharacterInventory(player)) then return nil end
    return item
end

--- Take the container's item in hand, as a tile from nowhere in particular
--- (it lies in the world: the move picks it up from where it is).
function KnoxLootPanel:dragContainer(item, p)
    local w, h = KnoxFootprint.get(item)
    KnoxDrag.start({item = item, items = {item}, w = w, h = h, r = 0, fromWorld = true}, nil,
        math.floor((w - 1) / 2), math.floor((h - 1) / 2))
end

function KnoxLootPanel:onMouseMove(dx, dy)
    local p = self.grab
    if not p or KnoxDrag.isActive() then return end
    if not isMouseButtonDown(0) then
        self.grab = nil
        return
    end
    if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) < DRAG_START_PX then return end
    self.grab = nil
    -- (still there, still not carried: the press was a moment ago)
    if KnoxLootPanel.takeable(p.container, self:player()) == p.item then self:dragContainer(p.item, p) end
end

function KnoxLootPanel:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function KnoxLootPanel:onMouseUpOutside(x, y)
    self.grab = nil
end

--- An item let go over a container's name - a row of the list or the chosen
--- one's header - goes into that container.
function KnoxLootPanel:onMouseUp(x, y)
    self.grab = nil
    if not KnoxDrag.isActive() then return true end
    local target
    for _, rr in ipairs(self.rowRects or {}) do
        if inRect(x, y, rr.rect) and y >= 0 and y < self:getHeight() and not rr.entry.locked then
            target = rr.entry.container
        end
    end
    local H = self.header
    if not target and H and self.selected and inRect(x, y, {self.m.gridX, 0, H.w, H.h}) then target = self.selected end
    if target then
        KnoxDrag.dropInto(target, self:player())
    else
        KnoxDrag.cancel()
    end
    for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
    return true
end

function KnoxLootPanel:onMouseDown(x, y)
    for _, rr in ipairs(self.rowRects or {}) do
        if inRect(x, y, rr.rect) and y >= 0 and y < self:getHeight() then
            if not rr.entry.locked then
                self.rowPress = {container = rr.entry.container, ms = getTimestampMs()}
                self:select(rr.entry.container, true)
                self:grabAt(rr.entry.container)
            end
            return true
        end
    end
    if self.view then
        for _, b in ipairs(self.header and self.header.buttons or {}) do
            if inRect(x, y, b.rect) then
                self.btnPress = {title = b.title, ms = getTimestampMs()}
                self:actionsChanged()
                if b.id == "take" then
                    KnoxActions.takeAll(self.view, self:player())
                elseif b.id == "sort" then
                    KnoxActions.sort(self.view)
                elseif b.id == "ghosts" then
                    KnoxOrder.toggleGhosts()
                else
                    getSoundManager():playUISound("UIActivateButton")
                    -- next frame: the click brings the Knox screen to the top after
                    -- this, over the window the action opens ("Remove all?")
                    self.queuedAction = b.action
                end
                return true
            end
        end
        -- the header itself (not a button): the container may be taken by it
        local H = self.header
        if H and inRect(x, y, {self.m.gridX, 0, H.w, H.h}) then self:grabAt(self.selected) end
    end
    return true
end

--- Right click on the chosen container's header: Sort, its rule, the layout (KnoxOrder).
function KnoxLootPanel:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end
    local H = self.header
    if self.view and H and self.selected and inRect(x, y, {self.m.gridX, 0, H.w, H.h}) then
        local menu = ISContextMenu.get(self:player():getPlayerNum(), self:getAbsoluteX() + x, self:getAbsoluteY() + y)
        KnoxOrder.addMenu(menu, self.view)
    end
    return true
end

--- A press on a container's name: if it is a thing to carry, a drag may start (see onMouseMove).
function KnoxLootPanel:grabAt(container)
    local item = KnoxLootPanel.takeable(container, self:player())
    self.grab = item and {container = container, item = item, x = getMouseX(), y = getMouseY()} or nil
end
