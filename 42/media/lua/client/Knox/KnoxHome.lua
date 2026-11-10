-- Things go back to their place (the author, 2026-11-07: "a very needed thing"; the
-- approved mockup .claude/mockups/home_place.html).
--
-- A place in Knox is kept for one container (modData knox). To put a thing into a hand,
-- on the body or the belt, to eat it, drink from it, read it, the game first moves it out
-- of its bag into the pockets (transferIfNeeded): there it got a new place, the old one was
-- written over, and once let go it stayed in the pockets. Now:
--   * the place in the bag it was taken from is kept (modData knoxH) - only when the game
--     moved it: what Knox moves (drag, Shift, Take all) writes where it goes (knoxP) and so
--     is the player's own wish; and a thing the player puts somewhere himself forgets it
--     (KnoxGrid.writePlace / writePending);
--   * while it is in a hand, or lies in the pockets busy, its place waits for it: nothing
--     else may take those cells, a grey silhouette in a dashed frame is on them
--     (KnoxGrid.build, KnoxGridView.drawHeld). Worn or on the belt it may stay for hours:
--     its place is not held then (a jacket's 2x3 hole in a bag for a day) - but it goes back
--     all the same when taken off;
--   * once it is free - out of the hands, taken off, nothing in the action queue - it goes
--     back to its cells (or the nearest free place of that bag; no room, the bag gone from
--     the character: it stays in the pockets) as a move of Knox's own.
-- A thing in the pockets put into a hand keeps its pockets' place the same way (only the
-- silhouette: it never left the pockets, the grid puts it back by itself).
--
-- Costs nothing at rest: the check runs on a tick handler that is there only for a moment
-- after a timed action of the character ends, a hand is changed or clothes are - and while
-- the queue is busy with a thing that is to go back. The switch "home" (Settings > Game).

require "Knox/KnoxTheme"
require "Knox/KnoxGrid"
require "Knox/KnoxDrag"

KnoxHome = KnoxHome or {}
local H = KnoxHome
local T = KnoxTheme

H.homes = H.homes or {}   -- item -> true: things with a place in a bag to go back to (knoxH)
H.notOn = setmetatable({}, {__mode = "k"})   -- item -> the key of a bag found not on the character
H.CHECK_MS = 150          -- after an action, a hand or clothes: the game's own state settles first
H.BUSY_MS = 250           -- the queue still busy: looked at again so often

local function on()
    return T.on("inventory") and T.switch("home")
end

--- A line in console.txt, DEV mode only (the author's bench 2026-11-10: eaten or drunk in part,
--- the thing still lands in a random cell of its bag - the offline test goes home; this shows
--- where the place is lost in the game).
function H.trace(item, what)
    if not (KnoxTestBench and KnoxTestBench.devOn and KnoxTestBench.devOn()) then return end
    local md = item and item:getModData() or {}
    local function pl(p) return p and (tostring(p.k) .. " " .. tostring(p.x) .. "," .. tostring(p.y)) or "-" end
    print("[Knox] home: " .. tostring(item and item:getFullType()) .. " " .. what .. " | knox " .. pl(md.knox)
        .. " | knoxP " .. pl(md.knoxP) .. " | knoxH " .. pl(md.knoxH))
end

local function tell(item, key)
    if KnoxNet and KnoxNet.itemChanged then KnoxNet.itemChanged(item, key) end
end

--- Is `c` the pockets of a character played here?
local function pockets(c)
    for pn = 0, getNumActivePlayers() - 1 do
        local pl = getSpecificPlayer(pn)
        if pl and c == pl:getInventory() then return true end
    end
    return false
end

local function forget(item)
    if item:getModData().knoxH then H.trace(item, "forgotten") end
    H.homes[item] = nil
    local md = item:getModData()
    if md.knoxH then
        md.knoxH = nil
        tell(item, "knoxH")
    end
    -- (still in the pockets with the bag's place on it - in a hand, the screen closed: the
    -- next look would take it for a thing just taken out again. The pockets' grid gives it
    -- a place of its own.)
    local p = md.knox
    local c = item:getContainer()
    if p and p.k ~= "p" and c and pockets(c) then
        md.knox = nil
        tell(item, "knox")
    end
end

--- Not to go back: taken out of its bag for good (KnoxMain's "Place object").
H.forget = forget

--- The bag with this key ("i<id>") on the character, at any depth, or nil.
local function bagOn(player, key)
    local id = tonumber(string.sub(key, 2))
    if not id then return nil end
    local function look(c, depth)
        local items = c:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if instanceof(it, "InventoryContainer") then
                if it:getID() == id then return it end
                if depth < 6 then
                    local found = look(it:getInventory(), depth + 1)
                    if found then return found end
                end
            end
        end
        return nil
    end
    return look(player:getInventory(), 0)
end

--- Worn or on the belt: may stay so for long - its place is not held (it still goes back).
local function wornOrHung(item, player)
    local slot = item:getAttachedSlot()
    if slot and slot > -1 then return true end
    local worn = player:getWornItems()
    return worn ~= nil and worn:contains(item)
end

--- A thing that is put on (clothes, a bag): its place is never held, not even on its way
--- from the bag to the body (the author's bench, 2026-11-07: "I didn't want clothes to use
--- the silhouettes"). It still goes back when taken off.
local function wearable(item)
    return KnoxEquip ~= nil and KnoxEquip.wearLoc ~= nil and KnoxEquip.wearLoc(item) ~= ""
end

local function inHand(item, player)
    return item == player:getPrimaryHandItem() or item == player:getSecondaryHandItem()
end

local function queueBusy(player)
    local queues = ISTimedActionQueue and ISTimedActionQueue.queues
    local q = queues and queues[player]
    return q ~= nil and q.queue ~= nil and #q.queue > 0
end

-- The tick ------------------------------------------------------------------------

local wakeAt, ticking = nil, false
local tick   -- (below: it removes itself)

--- Look at the things to go back within `ms`.
function H.poke(ms)
    if not on() then
        -- switched off: no place is kept, nothing goes back later by surprise
        for it in pairs(H.homes) do forget(it) end
        return
    end
    local at = getTimestampMs() + (ms or H.CHECK_MS)
    if not wakeAt or at < wakeAt then wakeAt = at end
    if not ticking then
        ticking = true
        Events.OnTick.Add(tick)
    end
end

-- Noting ----------------------------------------------------------------------------

--- The thing has just come into the character's pockets (KnoxGrid.build of the pockets,
--- or the look after an action): if the game took it out of a bag of the character, the
--- place it lay at there is kept to go back to.
function H.note(item, player)
    local md = item:getModData()
    local p = md.knox
    if not p or md.knoxP or md.knoxH or type(p.k) ~= "string" or string.sub(p.k, 1, 1) ~= "i" then
        -- (only a thing from a bag kept back by a wanted place: the pockets' own are asked often)
        if not md.knoxH and md.knoxP and p and type(p.k) == "string" and string.sub(p.k, 1, 1) == "i" then
            H.trace(item, "not noted, a wanted place")
        end
        return
    end
    if not on() or not player or item:getContainer() ~= player:getInventory() then return end
    -- (only a bag on the character: an apple eaten from a backpack on the ground stays;
    -- asked once a thing and bag - the pockets' grid asks four times a second of all it wears)
    if H.notOn[item] == p.k then return end
    if not bagOn(player, p.k) then
        H.notOn[item] = p.k
        return
    end
    md.knoxH = {k = p.k, x = p.x, y = p.y, r = p.r}
    tell(item, "knoxH")
    H.trace(item, "noted")
    H.homes[item] = true
    H.poke()
end

--- Every thing in the pockets: the homes after a load (modData knoxH is saved), what the
--- game has taken out with the Knox screen closed.
local function scan(player)
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local md = it:getModData()
        if md.knoxH then
            H.homes[it] = true
        elseif md.knox and not md.knoxP then
            H.note(it, player)
        end
    end
end

local scanned = {}

-- Held places ----------------------------------------------------------------------

--- The places of grid `L` waiting for their things: {item, x, y, r, w, h}, or nil.
--- (KnoxGrid.build; the grid's things already placed)
function H.heldIn(L, player)
    if not on() then return nil end
    local out = nil
    local inv = player:getInventory()
    if L.key == "p" then
        -- a thing of the pockets in a hand: its place there
        if L.container ~= inv or not L.away then return nil end
        for _, it in ipairs(L.away) do
            local md = it:getModData()
            local p = md.knox
            -- (not one going back to a bag: its place waits there, not here)
            if p and p.k == "p" and not md.knoxH and inHand(it, player) and not wearable(it) then
                local w, h = KnoxFootprint.get(it)
                out = out or {}
                table.insert(out, {item = it, x = p.x, y = p.y, r = p.r == 1 and 1 or 0, w = w, h = h})
            end
        end
        return out
    end
    if string.sub(L.key, 1, 1) ~= "i" then return nil end
    local pn = player:getPlayerNum()
    if not scanned[pn] then
        scanned[pn] = true
        scan(player)
    end
    for it in pairs(H.homes) do
        local hp = it:getModData().knoxH
        if hp and hp.k == L.key and it:getContainer() == inv and not wornOrHung(it, player) and not wearable(it) then
            local w, h = KnoxFootprint.get(it)
            out = out or {}
            table.insert(out, {item = it, x = hp.x, y = hp.y, r = hp.r == 1 and 1 or 0, w = w, h = h})
        end
    end
    return out
end

-- Going back -------------------------------------------------------------------------

local function markViews()
    if KnoxScreen and KnoxScreen.instance then KnoxScreen.instance:markAllDirty() end
    if KnoxActions then
        for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
    end
end

--- Where the thing lies in the pockets' grid on the screen, as a move's source (its
--- faded copy), or nil.
local function sourceIn(item, inv)
    if not KnoxActions then return nil end
    for _, v in ipairs(KnoxActions.allViews()) do
        if v.container == inv and v.layout then
            for _, e in ipairs(v.layout.placed) do
                if e.item == item and #e.items == 1 and not e.reserved then return KnoxDrag.sourceOf(e, v) end
            end
        end
    end
    return nil
end

--- Things with one home going together (a stack's leftovers): one move.
local function goBack(player, items, hp)
    local bag = bagOn(player, hp.k)
    local first = items[1]
    if not bag then
        for _, it in ipairs(items) do forget(it) end
        return
    end
    local c = bag:getInventory()
    if not KnoxDrag.allowedIn(first, c, player) then
        for _, it in ipairs(items) do forget(it) end
        return
    end
    local L = KnoxGrid.build(c, player, true)
    -- (its own silhouette is not in its way)
    local going = {}
    for _, it in ipairs(items) do going[it] = true end
    for i = #L.placed, 1, -1 do
        local e = L.placed[i]
        if e.held and going[e.item] then L:vacate(e) end
    end
    local w, h = KnoxFootprint.get(first)
    local e = {item = first, items = items, w = w, h = h}
    local r = hp.r == 1 and 1 or 0
    local dw, dh = KnoxGrid.dims(e, r)
    local x, y
    if hp.y + dh <= (L.baseRows or L.rows) and L:fits(hp.x, hp.y, dw, dh) then
        x, y = hp.x, hp.y
        KnoxDrag.ownTile(e)
    else
        -- its cells taken. By a stack of its own kind (a stack's leftovers): onto it. By
        -- something else (put on its silhouette): as near to them as there is room - the
        -- author's bench 2026-11-08; no room at all: onto a stack of its kind anywhere
        local onIt = L:cellAt(hp.x, hp.y)
        if onIt and not onIt.held and KnoxGrid.mergeRoom(e, onIt) > 0 then
            x, y, r = KnoxDrag.settle(L, e)
        else
            x, y, r = L:nearest(e, hp.x, hp.y, r)
            if x then KnoxDrag.ownTile(e) else x, y, r = KnoxDrag.settle(L, e) end
        end
    end
    if not x then
        for _, it in ipairs(items) do forget(it) end
        return
    end
    local source = #items == 1 and sourceIn(first, player:getInventory()) or nil
    -- (the move writes where it goes: the home is forgotten with it - KnoxGrid.writePending)
    KnoxDrag.moveTo(player, e, source, L, x, y, r)
    for _, it in ipairs(items) do H.homes[it] = nil end
    markViews()
end

--- Look at the things to go back. Returns true when one waits for the queue.
local function check(player)
    local inv = player:getInventory()
    if queueBusy(player) then
        for it in pairs(H.homes) do
            if it:getContainer() == inv then return true end
        end
        return false
    end
    scan(player)
    local groups, order = nil, nil
    for it in pairs(H.homes) do
        local hp = it:getModData().knoxH
        local c = it:getContainer()
        local bag = c and c ~= inv and c:getContainingItem() or nil
        if hp and bag and "i" .. tostring(bag:getID()) == hp.k then
            -- put back into its bag by the game itself (after eating or drinking part of it):
            -- the bag's grid puts it home, or as near as it can (KnoxGrid.build - readPlace)
            H.trace(it, "back by the game")
            KnoxGrid.build(c, player)
            H.homes[it] = nil
            markViews()
        elseif not hp or c ~= inv then
            -- put elsewhere, used up, dropped: nothing to go back
            forget(it)
        elseif not wornOrHung(it, player) and not inHand(it, player) and not KnoxGrid.pending[it] then
            groups = groups or {}
            order = order or {}
            local gk = hp.k .. "|" .. tostring(hp.x) .. "|" .. tostring(hp.y) .. "|" .. it:getFullType()
            if not groups[gk] then
                groups[gk] = {hp = hp, items = {}}
                table.insert(order, gk)
            end
            table.insert(groups[gk].items, it)
        end
    end
    if order then
        for _, gk in ipairs(order) do
            local g = groups[gk]
            goBack(player, g.items, g.hp)
        end
    end
    return false
end

tick = function()
    if getTimestampMs() < wakeAt then return end
    local again = false
    if on() then
        for pn = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(pn)
            if player and not player:isDead() and check(player) then again = true end
        end
    else
        -- switched off: no place is kept, nothing goes back later by surprise
        for it in pairs(H.homes) do forget(it) end
    end
    if again then
        wakeAt = getTimestampMs() + H.BUSY_MS
    else
        wakeAt = nil
        ticking = false
        Events.OnTick.Remove(tick)
    end
end

-- When to look ------------------------------------------------------------------------

local function mine(character)
    return character ~= nil and instanceof(character, "IsoPlayer") and character:isLocalPlayer()
end

-- every timed action of the character that ends (done or stopped): taking into a hand,
-- out of it, off the belt, off the body, eating, drinking, reading, moving
if ISBaseTimedAction and not ISBaseTimedAction.knoxHomeHooked then
    ISBaseTimedAction.knoxHomeHooked = true
    local perform, stop = ISBaseTimedAction.perform, ISBaseTimedAction.stop
    ISBaseTimedAction.perform = function(self, ...)
        local r = perform(self, ...)
        if mine(self.character) then H.poke() end
        return r
    end
    ISBaseTimedAction.stop = function(self, ...)
        local r = stop(self, ...)
        if mine(self.character) then H.poke() end
        return r
    end
end

-- a hand changed or clothes put on / off without a timed action (a key, another mod)
local function onEquip(character)
    if mine(character) then H.poke() end
end
Events.OnEquipPrimary.Add(onEquip)
Events.OnEquipSecondary.Add(onEquip)
Events.OnClothingUpdated.Add(onEquip)
T.offInGame(Events.OnEquipPrimary, onEquip, "inventory")
T.offInGame(Events.OnEquipSecondary, onEquip, "inventory")
T.offInGame(Events.OnClothingUpdated, onEquip, "inventory")

-- (a new game or a load: the pockets are looked at anew)
Events.OnGameStart.Add(function()
    H.homes = {}
    H.notOn = setmetatable({}, {__mode = "k"})
    scanned = {}
    H.poke(1000)
end)

KnoxGrid.noteHome = H.note
KnoxGrid.heldIn = H.heldIn
