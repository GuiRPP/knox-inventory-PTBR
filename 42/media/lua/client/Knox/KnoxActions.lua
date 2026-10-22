-- Actions on tiles that aren't plain drags: quick transfer (Shift+click),
-- take all, sort, split a stack, Alt+click on a single item.

require "Knox/KnoxGrid"
require "Knox/KnoxDrag"
require "Knox/KnoxSelect"
require "Knox/KnoxOrder"

KnoxActions = KnoxActions or {}
local A = KnoxActions

local function screen()
    return KnoxScreen and KnoxScreen.instance
end

local function say(player, key)
    if HaloTextHelper and HaloTextHelper.addBadText then
        HaloTextHelper.addBadText(player, getText(key))
    end
end

-- Active container: the pockets or one worn bag, chosen by a click on its
-- header in the inventory column (like picking a bag in the game's own
-- inventory). Quick moves and "Take all" fill it first; the game's own
-- "Grab" options use it too.
A.active = nil

--- The active container if it is still on the character, else the pockets.
function A.activeContainer(player)
    local s = screen()
    if A.active and s and s.inventory then
        for _, sec in ipairs(s.inventory.sections) do
            if sec.view.container == A.active then return A.active end
        end
    end
    return player:getInventory()
end

function A.setActive(container, playerNum)
    A.active = container
    -- the game's inventory window follows, silently
    local page = getPlayerInventory(playerNum)
    if page and container then
        page.inventory = container
        if page.inventoryPane then page.inventoryPane.inventory = container end
    end
end

--- Grid views of the character (pockets, bags), the active container first.
function A.playerViews()
    local s = screen()
    local out = {}
    if s and s.inventory then
        local active = A.activeContainer(s:player())
        for _, sec in ipairs(s.inventory.sections) do
            -- a collapsed grid is hidden and doesn't refresh itself
            local v = sec.view
            if not v:getIsVisible() and getTimestampMs() - (v.builtMs or 0) > 250 then
                v:rebuild()
                v.builtMs = getTimestampMs()
            end
            if sec.view.container == active then table.insert(out, 1, sec.view) else table.insert(out, sec.view) end
        end
    end
    return out
end

function A.lootViews()
    local s = screen()
    if s and s.loot and s.loot.view then return {s.loot.view} end
    return {}
end

--- Grids of the open container windows (bags opened from a grid).
function A.windowViews()
    local out = {}
    for _, w in ipairs(KnoxContainerWindow and KnoxContainerWindow.list or {}) do
        if w.view then table.insert(out, w.view) end
    end
    return out
end

function A.allViews()
    local out = A.playerViews()
    for _, v in ipairs(A.lootViews()) do table.insert(out, v) end
    for _, v in ipairs(A.windowViews()) do table.insert(out, v) end
    return out
end

--- On the character's side (pockets, worn bags, anything nested in them)?
local function isPlayerView(view)
    local player = view:player()
    return view.container == player:getInventory() or view.container:isInCharacterInventory(player)
end

--- Can the character reach this container right now: on them, in one of the
--- surroundings containers, or nested (at any depth) in one of those?
function A.isReachable(container, player)
    local s = screen()
    local roots = {}
    roots[player:getInventory()] = true
    if s and s.loot then
        for _, c in ipairs(s.loot.containers) do roots[c.container] = true end
    end
    local c = container
    for _ = 1, 32 do
        if not c then return false end
        if roots[c] then return true end
        local holder = c:getContainingItem()
        if not holder then return false end
        c = holder:getContainer()
    end
    return false
end

--- A view of `views` that may take `e` (not its own container).
local function takes(v, e, player)
    return e.item:getContainer() ~= v.layout.container and KnoxDrag.allowedIn(e.item, v.layout.container, player)
end

--- Some of tile `e` into stacks of its kind that have room for some but not
--- all of it, in any of `views`: those moves are made here. Returns what is
--- left of `e` (a tile of its own, or `e` itself when nothing went).
--- Asked for by the author (2026-10-15): a quick move tops up the stack the
--- character has - in the pockets or any bag - before it takes a new place.
local function topUp(views, e, player, source)
    if not KnoxGrid.isStackable(e.item) then return e end
    for _, v in ipairs(views) do
        if takes(v, e, player) then
            local L = v.layout
            for _, t in ipairs(L.placed) do
                local room = 0
                if not t.overflow and not A.isLocked(t) and not (KnoxSearch and KnoxSearch.unseen(t.item)) then
                    room = KnoxGrid.mergeRoom(e, t)
                end
                if room > 0 and room < #e.items then
                    local part, rest = {}, {}
                    for i, it in ipairs(e.items) do
                        if i <= room then table.insert(part, it) else table.insert(rest, it) end
                    end
                    KnoxGrid.setStackId(part, t.item:getModData().knoxS)
                    t.joinN = (t.joinN or 0) + #part
                    KnoxDrag.moveTo(player, {item = part[1], items = part, w = e.w, h = e.h, fromBody = e.fromBody},
                        source, L, t.x, t.y, t.r)
                    e = {item = rest[1], items = rest, w = e.w, h = e.h, r = e.r, fromBody = e.fromBody, slotId = e.slotId}
                end
            end
        end
    end
    return e
end

--- Find a place for a tile and hold it there so the next tile of the same
--- batch goes elsewhere: a stack of its kind with room for all of it, in any
--- of `views` first; else the first of `views` that has a free place for it.
local function placeIn(views, e, player)
    for _, v in ipairs(views) do
        if takes(v, e, player) then
            local t = KnoxDrag.joinTarget(v.layout, e)
            if t then
                KnoxGrid.setStackId(e.items, t.item:getModData().knoxS)
                t.joinN = (t.joinN or 0) + #e.items
                return v, t.x, t.y, t.r
            end
        end
    end
    for _, v in ipairs(views) do
        local L = v.layout
        if e.item:getContainer() ~= L.container and KnoxDrag.allowedIn(e.item, L.container, player) then
            -- onto a same-type stack with room (it joins it), else a free place
            local x, y, r, joined = KnoxDrag.settle(L, e)
            if x then
                if not joined then
                    local w, h = KnoxGrid.dims(e, r)
                    L:occupy({item = e.item, items = e.items, w = w, h = h, reserved = true}, x, y, 0)
                end
                return v, x, y, r
            end
        end
    end
    return nil
end

--- The admin power "Unlimited Carry": the game drops the weight limit, Knox its
--- cells too - what has no place goes into the pockets all the same and lies in
--- the grid's "doesn't fit" row (Brice's report, 2026-10-17: things could be
--- picked up as objects but not looted).
function A.unlimited(player)
    local ok, on = pcall(function() return player:isUnlimitedCarry() end)
    return ok and on == true
end

--- Into the pockets with no place (A.unlimited): the game's own transfers.
local function carryAnyway(player, e)
    local inv = player:getInventory()
    for _, item in ipairs(e.items) do
        if item:getContainer() ~= inv then
            ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), inv))
        end
    end
    return true
end

-- Big things (2026-10-19: a stone from a search, the parts of a bed for building,
-- ~4 players): a thing no grid of the character could hold even empty is taken
-- in both hands, as the game carries heavy things - it is on the character for
-- building and crafting, and in no grid.

--- Could a w x h tile lie in this grid if it were empty (in one of its compartments)?
local function couldHold(container, player, w, h)
    local shape = KnoxGrid.shapeOf(container, player)
    if shape then
        local function inPart(p, bw, bh)
            if bw > p.w or bh > p.h then return false end
            if not shape.free or p.rect then return true end
            -- a compartment of any form: somewhere all the block's cells are its own
            for y = p.ly, p.ly + p.h - bh do
                for x = p.lx, p.lx + p.w - bw do
                    local all = true
                    for yy = y, y + bh - 1 do
                        for xx = x, x + bw - 1 do
                            if shape.mask[yy * shape.cols + xx] ~= p then all = false break end
                        end
                        if not all then break end
                    end
                    if all then return true end
                end
            end
            return false
        end
        for _, p in ipairs(shape.parts) do
            if inPart(p, w, h) or inPart(p, h, w) then return true end
        end
        return false
    end
    local cols, rows = KnoxGrid.getSize(container, player)
    return (w <= cols and h <= rows) or (h <= cols and w <= rows)
end

-- picked up furniture this heavy is carried, never packed: a fridge (the author,
-- 2026-10-21: its weight-sized tile fitted an empty backpack, so "Take" said "No
-- room" and picking it up put it into the pockets)
A.FURNITURE_HANDS_KG = 20

local function heavyFurniture(item)
    return instanceof(item, "Moveable") and not instanceof(item, "Radio")
        and math.max(item:getWeight() or 0, item:getActualWeight() or 0) >= A.FURNITURE_HANDS_KG
end

--- Must the thing be carried in the hands rather than packed (heavy furniture)?
function A.mustCarry(item) return item ~= nil and heavyFurniture(item) end

--- Is the thing too big for every grid the character has (pockets, worn bags)?
function A.tooBig(player, item)
    if heavyFurniture(item) then return true end
    local w, h = KnoxFootprint.get(item)
    local list = KnoxInventoryPanel.collectContainers({player = function() return player end})
    for _, c in ipairs(list) do
        if couldHold(c.container, player, w, h) then return false end
    end
    return true
end

--- Take a thing in both hands (into the main inventory first).
function A.carryInHands(player, item)
    local inv = player:getInventory()
    if item:getContainer() ~= inv then
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), inv))
    end
    ISTimedActionQueue.add(ISEquipWeaponAction:new(player, item, 50, true, true))
    return true
end

--- A tile that goes to the character but fits no grid: carried in the hands.
function A.carryIfTooBig(player, e)
    if not e or #e.items ~= 1 or isForceDropHeavyItem(e.item) then return false end
    if KnoxGrid.isEquippedNow(e.item, player) or not A.tooBig(player, e.item) then return false end
    return A.carryInHands(player, e.item)
end

--- Move tile `e` into `views` as a quick move does: stacks of its kind are
--- topped up first, the rest goes onto a stack with room for it or a free
--- place. @return boolean all of it went
local function moveInto(views, e, player, source, toPlayer)
    if toPlayer and #e.items == 1 and A.mustCarry(e.item) and not KnoxGrid.isEquippedNow(e.item, player) then
        return A.carryInHands(player, e.item)
    end
    local rest = topUp(views, e, player, source)
    local tv, x, y, r = placeIn(views, rest, player)
    if not tv then
        if toPlayer and A.unlimited(player) then return carryAnyway(player, rest) end
        if toPlayer and A.carryIfTooBig(player, rest) then return true end
        return false
    end
    KnoxDrag.moveTo(player, rest, source, tv.layout, x, y, r)
    return true
end

-- Locks: a locked tile stays where it is - Take all, Sort, the quick moves and
-- "all of this kind" leave it alone. Dragging it by hand still works. Kept in
-- the items' modData (knoxLock), so it lasts.

-- (in a game with others a lock is the player's own - the author, 2026-10-20: kept
-- by the server per character, KnoxNet; others see the thing unlocked)
function A.isLocked(entity)
    if entity == nil then return false end
    if KnoxNet and KnoxNet.mp() then return KnoxNet.isLocked(entity.item) end
    return entity.item:getModData().knoxLock == true
end

function A.toggleLock(entity)
    local on = not A.isLocked(entity)
    -- a tile of its own: other items of its kind must not slip into a locked stack
    if on then KnoxDrag.ownTile(entity) end
    local net = KnoxNet and KnoxNet.mp()
    for _, it in ipairs(entity.items) do
        if net then KnoxNet.setLocked(it, on) else it:getModData().knoxLock = on or nil end
    end
    getSoundManager():playUISound("UIActivateButton")
end

--- The key rings the character carries (not worn ones only: anywhere on them).
local function keyRings(player)
    local out = {}
    local function walk(inv, depth)
        if depth > 3 then return end
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if instanceof(it, "InventoryContainer") and it:getInventory() then
                if string.find(it:getFullType(), "KeyRing", 1, true) then table.insert(out, it:getInventory()) end
                walk(it:getInventory(), depth + 1)
            end
        end
    end
    walk(player:getInventory(), 0)
    return out
end

--- Shift+click on a key (Falco, 2026-10-19): onto a key ring the character
--- carries, when it is not on one yet. @return boolean it went
local function toKeyRing(e, view, player)
    if not instanceof(e.item, "Key") then return false end
    local from = e.item:getContainer()
    local holder = from and from:getContainingItem()
    if holder and string.find(holder:getFullType(), "KeyRing", 1, true) then return false end
    local rings = {}
    for _, inv in ipairs(keyRings(player)) do
        if inv ~= from and inv:isItemAllowed(e.item) then table.insert(rings, {layout = KnoxGrid.build(inv, player)}) end
    end
    if #rings == 0 then return false end
    return moveInto(rings, e, player, KnoxDrag.sourceOf(e, view), true)
end

--- Shift+click: the tile (or the whole selection) to the other side - from
--- the character to the open surroundings container, or back into the
--- pockets and bags. A key goes onto a key ring the character has.
function A.quickTransfer(entity, view, player)
    local group = KnoxSelect.group(entity, view, A.allViews())
    local moved, failed = 0, 0
    for _, g in ipairs(group) do
        local toPlayer = not isPlayerView(g.view)
        local targets = toPlayer and A.playerViews() or A.lootViews()
        if A.isLocked(g.entity) then
            -- (a locked tile stays, and is no failure)
        elseif toKeyRing(g.entity, g.view, player) then
            moved = moved + 1
        elseif moveInto(targets, g.entity, player, KnoxDrag.sourceOf(g.entity, g.view), toPlayer) then
            moved = moved + 1
        else
            failed = failed + 1
        end
    end
    if failed > 0 then say(player, "IGUI_Knox_NoRoom") end
    KnoxSelect.clear()
    for _, v in ipairs(A.allViews()) do v:markDirty() end
end

--- Everything in the open surroundings container into the pockets and bags.
function A.takeAll(view, player)
    local failed = 0
    for _, e in ipairs(view.layout.placed) do
        -- (a container being searched: only what has been found)
        if not e.ghost and not e.reserved and not A.isLocked(e) and not (KnoxSearch and KnoxSearch.isHidden(e.item)) then
            if not moveInto(A.playerViews(), e, player, KnoxDrag.sourceOf(e, view), true) then failed = failed + 1 end
        end
    end
    if failed > 0 then say(player, "IGUI_Knox_NoRoom") end
    for _, v in ipairs(A.allViews()) do v:markDirty() end
end

--- Move tiles of any containers (the search's "found" window: they lie in
--- different ones, opened or not) into the first of `views` that takes each.
--- A tile's source is not drawn as a faded copy (no grid of it may be shown).
--- @return number failed
function A.moveTiles(tiles, views, player)
    local failed = 0
    for _, e in ipairs(tiles) do
        if not A.isLocked(e) and not moveInto(views, e, player, nil) then failed = failed + 1 end
    end
    if failed > 0 then say(player, "IGUI_Knox_NoRoom") end
    for _, v in ipairs(A.allViews()) do v:markDirty() end
    return failed
end

-- Taking with no Knox screen open: Viewpoint's Grab (its loot panel, one thing
-- or all) and the game's own "Grab" on things on the ground. They put
-- everything into the pockets, room or not: the things lay there red, "doesn't
-- fit" (pascal's report, 2026-10-15). Now each thing goes where a quick move
-- would put it - onto a stack of its kind, else the first grid with room - and
-- what has no room stays where it is ("No room"). What a search has not found
-- is not taken.

--- The character's own grids: the screen's when it is open (unless `fresh`),
--- else built here.
local function ownViews(player, fresh)
    local s = screen()
    if not fresh and s and s.inventory then return A.playerViews() end
    local out = {}
    local list = KnoxInventoryPanel.collectContainers({player = function() return player end})
    for _, c in ipairs(list) do
        table.insert(out, {layout = KnoxGrid.build(c.container, player)})
    end
    return out
end

local function tileOf(item)
    local w, h = KnoxFootprint.get(item)
    return {item = item, items = {item}, w = w, h = h}
end

--- Take `items` (a Lua list) into the pockets and bags. `walk(item)` queues the
--- way to the first thing taken (false: it can't be reached); it is asked only
--- when something has room, so a full character doesn't walk for nothing.
--- @return number taken
function A.grab(player, items, walk)
    local seen = {}
    for _, item in ipairs(items) do
        if item and not (KnoxSearch and KnoxSearch.unseen(item)) then table.insert(seen, item) end
    end
    if #seen == 0 then return 0 end
    -- (a dry run on grids of their own: does anything have room?)
    local dry, any = ownViews(player, true), false
    for _, item in ipairs(seen) do
        -- (placing gives the thing a stack id: put back, or a thing left lying
        -- would stand apart from its stack there)
        local had = item:hasModData() and item:getModData().knoxS or nil
        local fits = placeIn(dry, tileOf(item), player) ~= nil
        -- (and told so: in a game with others the server kept the tried one, and
        -- the thing left lying stood apart from its stack for everyone)
        if item:hasModData() and item:getModData().knoxS ~= had then KnoxGrid.setStackId({item}, had) end
        -- (a thing too big for any grid goes into the hands: A.carryIfTooBig)
        if not fits and not isForceDropHeavyItem(item) and A.tooBig(player, item) then fits = true end
        if fits then any = true break end
    end
    if not any and A.unlimited(player) then any = true end
    if not any then
        say(player, "IGUI_Knox_NoRoom")
        return 0
    end
    if not walk(seen[1]) then return 0 end
    local views = ownViews(player)
    local taken, failed = 0, 0
    for _, item in ipairs(seen) do
        if moveInto(views, tileOf(item), player, nil, true) then taken = taken + 1 else failed = failed + 1 end
    end
    if failed > 0 then say(player, "IGUI_Knox_NoRoom") end
    for _, v in ipairs(A.allViews()) do v:markDirty() end
    return taken
end

--- Repack a grid by the player's rule and layout (see KnoxOrder).
function A.sort(view)
    KnoxOrder.sort(view)
end

--- Split `count` items off a stack into a tile of their own, at the first
--- free place of the same grid.
function A.split(entity, view, count, player)
    local n = #entity.items
    if count < 1 or count >= n then return end
    local part = {}
    for i = n - count + 1, n do table.insert(part, entity.items[i]) end
    A.takeOut(entity, part, view, player)
end

--- Take these items of a stack out into a tile of their own, at the first free
--- place of the same grid (the stack's quick pick panel: that key, that tape).
function A.takeOut(entity, part, view, player)
    local e = {item = part[1], items = part, w = entity.w, h = entity.h}
    local x, y, r = view.layout:findFree(e)
    if not x then
        say(player, "IGUI_Knox_NoRoom")
        return
    end
    KnoxGrid.setStackId(part, KnoxGrid.newStackId())
    KnoxGrid.writePlace(e, view.layout.key, x, y, r)
    KnoxGridView.flashItems(part)   -- where the new stack went
    view:markDirty()
end

--- Alt+click: a stack opens the split dialog (a stack of two has nothing to
--- choose and splits 1 + 1 at once); a single item is put on or taken in hand
--- when it can be.
function A.alt(entity, view, player)
    if #entity.items == 2 then
        A.split(entity, view, 1, player)
        return
    end
    if #entity.items > 2 then
        KnoxSplitDialog.open(entity, view, player)
        return
    end
    local item = entity.item
    local source = KnoxDrag.sourceOf(entity, view)
    if KnoxEquip.wearLoc(item) ~= "" then
        KnoxEquip.wearItem(player, item, source)
    elseif instanceof(item, "HandWeapon") then
        KnoxEquip.equipHand(player, item, true, source)
    end
end

-- Furniture picked up with the game's furniture mode ("Pick up") goes straight
-- into the main inventory - the pockets. Heavy furniture is then taken into the
-- hands, as Knox's own "Take" does (the author, 2026-10-21: a fridge).
require "Moveables/ISMoveableSpriteProps"
if ISMoveableSpriteProps and not ISMoveableSpriteProps.knoxHooked then
    ISMoveableSpriteProps.knoxHooked = true
    local pickUp = ISMoveableSpriteProps.pickUpMoveable
    function ISMoveableSpriteProps:pickUpMoveable(character, square, createItem, forceAllow)
        local inv = instanceof(character, "IsoPlayer") and character:getInventory() or nil
        local before = inv and inv:getItems():size() or 0
        local res = pickUp(self, character, square, createItem, forceAllow)
        if inv and Knox and Knox.forPlayer and Knox.forPlayer(character:getPlayerNum()) then
            local items = inv:getItems()
            for i = before, items:size() - 1 do
                local it = items:get(i)
                if A.mustCarry(it) and not KnoxGrid.isEquippedNow(it, character) then
                    A.carryInHands(character, it)
                    break
                end
            end
        end
        return res
    end
end

return KnoxActions
