-- The item being dragged, shared by every grid view and equipment slot.
-- A drag starts from a grid tile or from something on the body (a worn item,
-- a hand, a hotbar slot); `entity.fromBody` marks the second kind and
-- `entity.slotId` names the slot it came from. Dragging a selected tile drags
-- the other selected tiles along (`extras`).

require "Knox/KnoxGrid"
require "TimedActions/ISInventoryTransferUtil"

KnoxDrag = KnoxDrag or {}
local D = KnoxDrag

D.entity = nil      -- tile being dragged
D.source = nil      -- grid view it came from (nil when from the body)
D.extras = {}       -- other selected tiles going along: {entity, view}
D.r = 0             -- rotation while dragging
D.grabX, D.grabY = 0, 0   -- grabbed cell inside the tile
D.upFrames = 0

function D.isActive()
    return D.entity ~= nil
end

function D.start(entity, view, grabX, grabY, extras)
    D.entity = entity
    D.source = view
    D.extras = extras or {}
    D.r = entity.r or 0
    D.grabX, D.grabY = grabX, grabY
    D.upFrames = 0
    if KnoxUISound then KnoxUISound.pick(entity.item) end
end

--- Start dragging a single item that is on the body, from slot `slotId`.
function D.startFromBody(item, slotId)
    local w, h = KnoxFootprint.get(item)
    D.start({item = item, items = {item}, w = w, h = h, r = 0, fromBody = true, slotId = slotId}, nil,
        math.floor((w - 1) / 2), math.floor((h - 1) / 2))
end

function D.cancel()
    D.entity = nil
    D.source = nil
    D.extras = {}
end

function D.rotate()
    if not D.entity then return end
    D.r = 1 - D.r
    -- keep the grabbed cell under the cursor
    D.grabX, D.grabY = D.grabY, D.grabX
end

--- The player turns the held tile (the key): as rotate, and the tile at the
--- cursor swings from the old shape into the new one (see KnoxDragLayer).
function D.turn()
    if not D.entity then return end
    D.rotate()
    D.turnedMs = getTimestampMs()
    if KnoxUISound then KnoxUISound.turn() end
end

function D.dims()
    return KnoxGrid.dims(D.entity, D.r)
end

--- Move source of a tile in a grid view.
function D.sourceOf(entity, view)
    -- some items of a stack (taken from its quick pick panel): the stack stays
    -- where it is as the tile it is, so there is no faded copy of them
    if entity.part then return nil end
    if view and view.layout then
        return {kind = "grid", key = view.layout.key, container = view.layout.container,
                x = entity.x, y = entity.y, r = entity.r or 0}
    end
    if entity.slotId then return {kind = "slot", id = entity.slotId} end
    return nil
end

--- Where the dragged item was taken from, as a move source.
function D.sourceInfo()
    if not D.entity then return nil end
    return D.sourceOf(D.entity, D.source)
end

--- Called every frame; drops the drag when the button was released outside any target.
function D.update()
    if not D.entity then return end
    if isMouseButtonDown(0) then
        D.upFrames = 0
    else
        D.upFrames = D.upFrames + 1
        if D.upFrames > 1 then D.cancel() end
    end
end

local function sourceContainer()
    return D.source and D.source.layout and D.source.layout.container
end

--- Tell the player why a drop was refused (`why`: a translation key, a text
--- already made, or nil).
function D.explain(player, why)
    if why and HaloTextHelper and HaloTextHelper.addBadText then
        HaloTextHelper.addBadText(player, string.find(why, "^IGUI_") and getText(why) or why)
    end
end

--- May `item` go into container `dest` at all (not counting grid space)?
--- @return boolean ok, string|nil why  (a translation key when there is something to tell)
function D.allowedIn(item, dest, player)
    -- a bag can't go inside itself, nor inside a bag that is (deep) inside it
    local c = dest
    for _ = 1, 32 do
        local holder = c and c:getContainingItem()
        if not holder then break end
        if holder == item then return false end
        c = holder:getContainer()
    end
    if item:getContainer() == dest then return true end          -- taking off into the same container
    local why = KnoxGrid.nestRefusal(item, dest, player)         -- bags in bags: the bag outside grows
    if why then return false, why end
    if not dest:isItemAllowed(item) then return false end
    if player and not dest:hasRoomFor(player, item) then return false end
    return true
end

-- The grid joins items by type and stack id: items with no id of their own
-- (nil) all form one tile. So a tile put down on a free spot must get an id of
-- its own, or it melts into a same-type tile elsewhere in that grid (a key
-- dropped on an empty cell vanished into the key stack, a moved stack jumped).

--- Make the tile a tile of its own (stackable items only).
function D.ownTile(e)
    if KnoxGrid.isStackable(e.item) then
        KnoxGrid.setStackId(e.items, KnoxGrid.newStackId())
    end
end

--- A same-type tile in the layout that tile `e` can join (it has room left).
function D.joinTarget(layout, e)
    if not KnoxGrid.isStackable(e.item) then return nil end
    for _, t in ipairs(layout.placed) do
        -- (not a stack a search has not found yet: the thing would vanish into it)
        -- (nor a locked stack: what is locked is not added to by the quick moves)
        if not t.overflow and KnoxGrid.canMerge(e, t) and not (KnoxSearch and KnoxSearch.unseen(t.item))
                and not (KnoxActions and KnoxActions.isLocked(t)) then
            return t
        end
    end
    return nil
end

--- Where a tile goes when only the container is given (shift+click, Take all,
--- dropped on a bag): onto a same-type stack there when it has room (it joins
--- it), else the first free place as a tile of its own.
--- @return x, y, r, joined   (x is nil: no room)
function D.settle(layout, e)
    local t = D.joinTarget(layout, e)
    if t then
        KnoxGrid.setStackId(e.items, t.item:getModData().knoxS)
        t.joinN = (t.joinN or 0) + #e.items
        return t.x, t.y, t.r, true
    end
    local x, y, r = KnoxGrid.placeNew(layout, e)
    if x then D.ownTile(e) end
    return x, y, r, false
end

--- A same-type stack under the cursor in this view that the dragged tile would join.
function D.mergeTarget(view)
    if not D.entity or #D.extras > 0 or not view:isMouseOver() then return nil end
    local target = view:entityUnderMouse()
    -- (a stack with any room left: it takes what fits, the rest stays behind)
    if KnoxGrid.mergeRoom(D.entity, target) > 0 then return target end
    return nil
end

-- Dropping onto a bag's tile puts the item into that bag (first free place
-- of its grid), without opening it.

--- The bag tile under the cursor in this view (not the dragged item itself).
function D.bagUnderMouse(view)
    if not D.entity or not view:isMouseOver() then return nil end
    local t = view:entityUnderMouse()
    if not t or t.item == D.entity.item then return nil end
    if not (instanceof(t.item, "InventoryContainer") and t.item:getInventory()) then return nil end
    return t
end

local bagCache = {}   -- the last answer, for a few frames: building a grid each frame is wasteful

--- Does the dragged tile fit into that bag? Then also its grid and the place.
function D.intoBag(bag, player)
    local e = D.entity
    local now = getTimestampMs()
    local c = bagCache
    if c.bag == bag.item and c.item == e.item and c.r == D.r and now - c.ms < 200 then
        return c.ok, c.layout, c.x, c.y, c.rr, c.why
    end
    local inv = bag.item:getInventory()
    local ok, layout, x, y, rr = false, nil, nil, nil, nil
    local allowed, why = D.allowedIn(e.item, inv, player)
    if allowed then
        layout = KnoxGrid.build(inv, player)
        x, y, rr = layout:findFree(e)
        ok = x ~= nil
    end
    bagCache = {bag = bag.item, item = e.item, r = D.r, ms = now, ok = ok, layout = layout, x = x, y = y, rr = rr, why = why}
    return ok, layout, x, y, rr, why
end

--- Has the character walked away, the tile in hand, from where it lay or from
--- `dest`? Then it is not dropped: carried with the screen open, things went
--- between containers at any distance (Hókuszpókusz Kókuszpókusz, 2026-10-21).
--- Only with the Knox screen up: its surroundings list is what is in reach.
-- (a thing lying on the ground: the game's floor list is refilled as the
-- character walks, and the thing has no container of its own then - its square
-- is what counts: by the character or next to it. The bench, 2026-10-28.)
local function farOnGround(item, player)
    local wi = item.getWorldItem and item:getWorldItem()
    if not wi then return false end
    local sq, at = wi:getSquare(), player:getCurrentSquare()
    if not sq or not at then return true end
    return sq:getZ() ~= at:getZ() or math.abs(sq:getX() - at:getX()) > 1 or math.abs(sq:getY() - at:getY()) > 1
end

local function tooFar(player, e, dest)
    local s = KnoxScreen and KnoxScreen.instance
    if not (s and s.loot and KnoxActions and KnoxActions.isReachable) then return false end
    local from = e.item:getContainer()
    return farOnGround(e.item, player)
        or (from and not KnoxActions.isReachable(from, player))
        or (dest and not KnoxActions.isReachable(dest, player)) or false
end

local farCache = {ms = 0}   -- the preview's answer, for a few frames (isReachable builds a table)

--- For the drop preview: is the dragged tile too far from its place or from
--- `dest`? Red then, as the drop is refused (the bench, 2026-10-28).
function D.tooFarFor(player, dest)
    local e = D.entity
    if not e then return false end
    local now = getTimestampMs()
    local c = farCache
    if c.item ~= e.item or c.dest ~= dest or now - c.ms >= 250 then
        c.item, c.dest, c.ms = e.item, dest, now
        c.far = tooFar(player, e, dest)
    end
    return c.far
end

-- The reason a drop here would be refused, for the plate by the cursor
-- (KnoxDragLayer:drawReason; option A, the author 2026-10-28): set each frame
-- by the grid view the held tile is over - the footprint's rect on the screen
-- and its grid's edges - and good for that frame only (`frame`, counted by the
-- drag layer).
D.frame = 0
D.hint = {frame = -1, why = nil, left = 0, right = 0}

function D.setHint(why, left, right)
    local k = D.hint
    k.frame, k.why = D.frame, why
    k.left, k.right = left, right
end

local placeCache = {ms = 0}   -- the last answer, for a few frames: a full scan of the grid

--- Is there no free place at all in this grid for the held tile, either way
--- turned? (the cells under it are taken: the plate says "no room" only when
--- that is so - a full backpack showed no words, the author 2026-10-28)
function D.noPlaceIn(layout)
    local e = D.entity
    if not e or not layout then return false end
    local now = getTimestampMs()
    local c = placeCache
    if c.layout ~= layout or c.item ~= e.item or now - c.ms >= 200 then
        c.layout, c.item, c.ms = layout, e.item, now
        c.none = layout:findFree(e) == nil
    end
    return c.none
end

local function outOfReach(player, e, dest)
    local far = tooFar(player, e, dest)
    local from = e.item:getContainer()
    -- (one line when it happens: the bench showed nothing moved but no words over the head)
    if far then
        print("[Knox] drop refused, too far: from " .. tostring(from and from:getType() or (e.item:getWorldItem() and "ground")) .. " to " .. tostring(dest and dest:getType()))
    end
    return far
end

--- Drop the dragged tile (and the selection with it) into a bag.
local function dropIntoBag(bag, player, source, extras)
    local e = D.entity
    if outOfReach(player, e, bag.item and bag.item:getInventory()) then
        D.cancel()
        D.explain(player, "IGUI_Knox_TooFar")
        return false
    end
    local ok, layout, _, _, _, why = D.intoBag(bag, player)
    D.cancel()
    bagCache = {}
    -- (it may go in but there is no place in it: said, as on the plate - it was silent)
    if not ok and not why and layout then why = "IGUI_Knox_NoRoom" end
    if not ok then
        D.explain(player, why)
        return false
    end
    local x, y, r, joined = D.settle(layout, e)
    if not x then return false end
    D.moveTo(player, e, source, layout, x, y, r)
    if not joined then
        local w, h = KnoxGrid.dims(e, r)
        layout:occupy({item = e.item, items = e.items, w = w, h = h, reserved = true}, x, y, 0)
    end
    for _, ex in ipairs(extras) do
        local te = ex.entity
        if te.item ~= bag.item and D.allowedIn(te.item, layout.container, player) then
            local fx, fy, fr, fjoined = D.settle(layout, te)
            if fx then
                D.moveTo(player, te, D.sourceOf(te, ex.view), layout, fx, fy, fr)
                if not fjoined then
                    local tw, th = KnoxGrid.dims(te, fr)
                    layout:occupy({item = te.item, items = te.items, w = tw, h = th, reserved = true}, fx, fy, 0)
                end
            end
        end
    end
    return true
end

--- Could the dragged tile go into this container at all (dropped on its name:
--- a row of the surroundings list, a header)? Not into the one it lies in.
function D.canDropInto(container, player)
    local e = D.entity
    if not e or not container then return false end
    if e.item:getContainer() == container and not e.fromBody then return false end
    return D.allowedIn(e.item, container, player)
end

--- Drop the dragged tile (and the selection with it) into a container given
--- only by itself: each tile joins a stack of its kind there or takes the
--- first free place.
function D.dropInto(container, player)
    local e = D.entity
    if not e then return false end
    local ok, why = D.canDropInto(container, player)
    if ok and outOfReach(player, e, container) then ok, why = false, "IGUI_Knox_TooFar" end
    local source, extras = D.sourceInfo(), D.extras
    D.cancel()
    if not ok then
        D.explain(player, why)
        return false
    end
    local layout = KnoxGrid.build(container, player)
    local x, y, r, joined = D.settle(layout, e)
    if not x then
        -- (the admin's Unlimited Carry: no place, it goes in all the same - KnoxActions.unlimited)
        if KnoxActions and KnoxActions.unlimited(player) and container == player:getInventory() then
            for _, item in ipairs(e.items) do
                ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), container))
            end
            return true
        end
        -- (too big for every grid of the character: into the hands)
        if KnoxActions and (container == player:getInventory() or container:isInCharacterInventory(player))
                and KnoxActions.carryIfTooBig(player, e) then
            return true
        end
        D.explain(player, "IGUI_Knox_NoRoom")
        return false
    end
    D.moveTo(player, e, source, layout, x, y, r)
    if not joined then
        local w, h = KnoxGrid.dims(e, r)
        layout:occupy({item = e.item, items = e.items, w = w, h = h, reserved = true}, x, y, 0)
    end
    for _, ex in ipairs(extras) do
        local te = ex.entity
        if te.item:getContainer() ~= container and D.allowedIn(te.item, container, player) then
            local fx, fy, fr, fjoined = D.settle(layout, te)
            if fx then
                D.moveTo(player, te, D.sourceOf(te, ex.view), layout, fx, fy, fr)
                if not fjoined then
                    local tw, th = KnoxGrid.dims(te, fr)
                    layout:occupy({item = te.item, items = te.items, w = tw, h = th, reserved = true}, fx, fy, 0)
                end
            end
        end
    end
    return true
end

--- Can the dragged tile go at x,y of this layout?
--- @return boolean ok, string|nil why
function D.canDrop(layout, x, y, player, merge)
    local e = D.entity
    if not e or not layout then return false end
    local dest = layout.container
    local sameGrid = sourceContainer() == dest
    if merge then
        if sameGrid then return true end
        return D.allowedIn(e.item, dest, player)
    end
    local w, h = D.dims()
    if y + h > (layout.baseRows or layout.rows) then return false end   -- the overflow rows take nothing
    -- (its own cells are free for a tile moved within its grid; not for some of
    -- a stack taken out of it: the stack stays where it is)
    if not layout:fits(x, y, w, h, (sameGrid and not e.part) and e or nil) then return false end
    if sameGrid then return true end
    return D.allowedIn(e.item, dest, player)
end

--- Move tile `e` (taken from `source`) to x,y,r of a grid layout: at once
--- inside one container, else as a tracked move of timed actions.
function D.moveTo(player, e, source, layout, x, y, r)
    -- the floor in a car (KnoxLootPanel.carFloor): out of it, as the game drops
    -- things from a car - through the door, onto the ground by it (LBBz, 2026-10-19)
    if layout.container:getType() == "floor" and player:getVehicle() then
        for _, item in ipairs(e.items) do
            if not item:isFavorite() then ISInventoryPaneContextMenu.dropItem(item, player:getPlayerNum()) end
        end
        return
    end
    local fromContainer = e.item:getContainer()
    if fromContainer == layout.container and not e.fromBody then
        KnoxGrid.writePlace(e, layout.key, x, y, r)
        -- (put down at once: no timed action of the game to make a sound of it)
        if KnoxUISound then KnoxUISound.place(e.item) end
        return
    end
    KnoxGrid.writePending(e, layout.key, x, y, r)
    local playerNum = player:getPlayerNum()
    local target = {kind = "grid", key = layout.key, container = layout.container, x = x, y = y, r = r}
    KnoxGrid.track(player, e.items, source, target, function()
        for _, item in ipairs(e.items) do
            if e.fromBody then
                if item:getAttachedSlot() and item:getAttachedSlot() > -1 then
                    getPlayerHotbar(playerNum):removeItem(item, true)
                elseif KnoxGrid.isEquippedNow(item, player) and not isForceDropHeavyItem(item) then
                    -- (not a generator or the like carried in the arms: taken out
                    -- of the hands it drops to the ground at once, and the move
                    -- into a car's trunk found nothing to move - Khudoz's report,
                    -- 2026-10-15. The transfer takes it from the hands itself, as
                    -- the game's own "Put" does.)
                    ISInventoryPaneContextMenu.unequipItem(item, playerNum)
                end
            end
            if item:getContainer() ~= layout.container then
                ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
                    player, item, item:getContainer(), layout.container))
            end
        end
    end)
end

--- Put the dragged tile(s) at x,y of the target view's container.
function D.drop(view, x, y, player)
    local e = D.entity
    local bag = D.bagUnderMouse(view)
    if bag then
        local ok = dropIntoBag(bag, player, D.sourceInfo(), D.extras)
        view:markDirty()
        return ok
    end
    local layout = view.layout
    local merge = D.mergeTarget(view)
    local ok, why = D.canDrop(layout, x, y, player, merge)
    -- it doesn't go there as it is turned, but would the other way: turn it
    if not ok and not why and not merge and e.w ~= e.h then
        D.rotate()
        local x2, y2 = view:dropCell()
        if D.canDrop(layout, x2, y2, player, nil) then
            x, y, ok = x2, y2, true
        else
            D.rotate()
        end
    end
    if ok and outOfReach(player, e, layout and layout.container) then ok, why = false, "IGUI_Knox_TooFar" end
    local fromGrid = sourceContainer()
    local fromView = D.source
    local source = D.sourceInfo()
    local extras = D.extras
    local r = D.r
    D.cancel()
    -- (heavy furniture is carried even where its tile would fit a grid of the
    -- character: KnoxActions.mustCarry; the floor, a shelf, a boot take it as before)
    local into = layout and layout.container
    if ok and KnoxActions and KnoxActions.mustCarry(e.item) and into
            and (into == player:getInventory() or into:isInCharacterInventory(player)) then
        ok, why = false, nil
    end
    if not ok then
        -- dropped on a grid of the character, but too big for any of them: into the hands
        local dest = layout and layout.container
        if not why and not merge and dest and KnoxActions and e.item:getContainer() ~= dest
                and (dest == player:getInventory() or dest:isInCharacterInventory(player))
                and KnoxActions.carryIfTooBig(player, e) then
            view:markDirty()
            return true
        end
        D.explain(player, why)
        return false
    end

    if merge then
        -- join the stack under the cursor: same stack id, its place
        local room = KnoxGrid.mergeRoom(e, merge)
        if room < #e.items then
            -- the stack takes only so many more: the last ones go, the rest
            -- stays where it was as the tile it is (no faded copy of it)
            local part = {}
            for i = #e.items - room + 1, #e.items do table.insert(part, e.items[i]) end
            e = {item = part[1], items = part, w = e.w, h = e.h, r = e.r, fromBody = e.fromBody, slotId = e.slotId}
            source = nil
        end
        KnoxGrid.setStackId(e.items, merge.item:getModData().knoxS)
        D.moveTo(player, e, source, layout, merge.x, merge.y, merge.r)
        view:markDirty()
        if fromView then fromView:markDirty() end
        return true
    end

    D.ownTile(e)
    D.moveTo(player, e, source, layout, x, y, r)

    -- other selected tiles: first free spots in the same grid (never within
    -- their own container: those stay where they are)
    if fromGrid ~= layout.container or #extras > 0 then
        local w, h = KnoxGrid.dims(e, r)
        layout:occupy({item = e.item, items = e.items, w = w, h = h, reserved = true}, x, y, 0)
        for _, ex in ipairs(extras) do
            local te = ex.entity
            if te.item:getContainer() ~= layout.container and D.allowedIn(te.item, layout.container, player) then
                local src = D.sourceOf(te, ex.view)
                local fx, fy, fr, fjoined = D.settle(layout, te)
                if fx then
                    D.moveTo(player, te, src, layout, fx, fy, fr)
                    if not fjoined then
                        local tw, th = KnoxGrid.dims(te, fr)
                        layout:occupy({item = te.item, items = te.items, w = tw, h = th, reserved = true}, fx, fy, 0)
                    end
                end
            end
        end
    end
    view:markDirty()
    return true
end

-- Hand-off: the Knox screen closed while an item was still held with the
-- mouse. The items become the game's drag (ISMouseDrag), which the game's
-- windows take on release (a TV's or radio's media slot, the hotbar...);
-- the item is drawn at the cursor until the button is let go.

KnoxHandOffLayer = ISUIElement:derive("KnoxHandOffLayer")

function KnoxHandOffLayer:new(item)
    local o = ISUIElement:new(0, 0, 0, 0)   -- 0x0: never takes a click
    setmetatable(o, self)
    self.__index = self
    o.item = item
    return o
end

function KnoxHandOffLayer:render()
    local T = KnoxTheme
    local cs = T.cell
    local x, y = getMouseX() - math.floor(cs / 2), getMouseY() - math.floor(cs / 2)
    T.rect(self, x, y, cs, cs, T.category[T.categoryOf(self.item)], 0.85)
    T.border(self, x, y, cs, cs, T.color.accent, 1)
    local side = math.floor(cs * 0.72)
    ISInventoryItem.renderItemIcon(self, self.item, x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2), 0.9, side, side)
end

D.handed = nil   -- {items, layer, upFrames} while handed off

function D.handOff()
    if not D.entity then return end
    local items = {}
    for _, it in ipairs(D.entity.items) do table.insert(items, it) end
    for _, ex in ipairs(D.extras) do
        for _, it in ipairs(ex.entity.items) do table.insert(items, it) end
    end
    ISMouseDrag.dragging = items
    ISMouseDrag.draggingFocus = D   -- not any game window: none treats it as its own drag
    -- (the drag as it was, to take back when the screen opens again with the
    -- button still held: the bench, 2026-10-28 - no highlight, no "too far")
    D.handed = {items = items, item = D.entity.item, upFrames = 0,
                entity = D.entity, source = D.source, extras = D.extras, r = D.r, grabX = D.grabX, grabY = D.grabY}
end

--- The Knox screen opened again while the handed-off items are still held:
--- they are Knox's drag again (lit where they would land, refused when far).
function D.takeBack()
    local h = D.handed
    if not h or ISMouseDrag.dragging ~= h.items or not isMouseButtonDown(0) then return end
    D.entity, D.source, D.extras = h.entity, h.source, h.extras
    D.r, D.grabX, D.grabY = h.r, h.grabX, h.grabY
    D.upFrames = 0
    ISMouseDrag.dragging = nil
    ISMouseDrag.draggingFocus = nil
    if h.layer then h.layer:removeFromUIManager() end
    D.handed = nil
end

-- Kept up to date before the UI is drawn (top-level elements may be added or
-- removed only outside of drawing).
Events.OnPreUIDraw.Add(function()
    local h = D.handed
    if not h then return end
    local ours = ISMouseDrag.dragging == h.items
    if ours and isMouseButtonDown(0) then
        h.upFrames = 0
    else
        h.upFrames = h.upFrames + 1
    end
    -- released (a window has had its mouse-up by now) or taken over by the game
    if not ours or h.upFrames > 1 then
        if ours then
            ISMouseDrag.dragging = nil
            ISMouseDrag.draggingFocus = nil
        end
        if h.layer then h.layer:removeFromUIManager() end
        D.handed = nil
        return
    end
    if not h.layer then
        h.layer = KnoxHandOffLayer:new(h.item)
        h.layer:initialise()
        h.layer:addToUIManager()
    end
    h.layer:bringToTop()
end)

return KnoxDrag
