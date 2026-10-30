-- Searching a container: what lies in a cupboard, a car's boot or on a corpse
-- the character has not looked into yet is not seen at once. The grid opens
-- empty and the things are found one after another, each taking a moment (a
-- big one a little longer); until a thing is found it can't be taken, and it
-- is not shown at all. Once everything is found the container is marked as
-- looked into (KnoxLootPanel.markSeen) and from then on opens as usual.
--
-- Left half-way (another container chosen, the screen closed), the search is
-- taken up from where it was: what was found stays found until the game is left.
-- The time doesn't run while the game is paused. Not searched: the floor, the
-- character's own things, containers the mark can't be kept on.
--
-- A switch in the settings (T.switch("search")); off = everything is seen at once.

require "Knox/KnoxTheme"
require "Knox/KnoxSearchSound"

KnoxSearch = KnoxSearch or {}
local S = KnoxSearch
local T = KnoxTheme

-- Time to find one thing: base + per cell over the first, up to a limit. A one-cell
-- thing 0.22 s, a pistol (2 cells) 0.33, a jacket (4) 0.55, a rifle (6) 0.77, a
-- generator the limit. (At first 320 + 45 a cell: a jacket took 0.46 s against 0.32
-- for a can - the size was counted but could not be felt; a player's remark 2026-10-13.)
local BASE_MS, CELL_MS, MAX_MS = 220, 110, 1400
-- Rummaging through rubbish takes longer (the author, 2026-10-29): a garbage can's,
-- a dumpster's things are found this many times slower (the limit too).
local TRASH = {bin = true, dumpster = true}
local TRASH_PACE = 2

S.container = nil   -- the container being searched
S.queue = {}        -- {items = {..}, ms = time it takes}: what is still to be found, in order
S.hidden = {}       -- item -> true: not found yet (in S.container)
S.current = {}      -- item -> true: being found right now
S.known = {}        -- item -> true: found in a search left half-way
S.total, S.done = 0, 0
S.spent = 0         -- ms spent on the current thing
S.selected = nil    -- the surroundings' container on show (S.tick)
S.lastMs = 0

function S.on()
    -- (in a game with others: not before the server has said what the character has searched)
    if KnoxNet and KnoxNet.mp() and not KnoxNet.ready then return false end
    return T.switch("search")
end

local function stop()
    if S.container then KnoxSearchSound.stop() end
    S.container = nil
    S.queue, S.hidden, S.current = {}, {}, {}
    S.total, S.done, S.spent = 0, 0, 0
end

--- Is this container being searched right now?
function S.busy(container)
    return S.container ~= nil and S.container == container and S.on()
end

--- How many things of the container being searched are found so far (things,
--- not tiles: what the list's number shows once the search is done).
function S.found()
    if not S.container then return 0 end
    local n = S.container:getItems():size()
    for _, q in ipairs(S.queue) do
        for _, it in ipairs(q.items) do
            if it:getContainer() == S.container then n = n - 1 end
        end
    end
    return math.max(0, n)
end

--- Is this container still to be searched (on, its mark can be kept, not looked into)?
function S.needs(container)
    return container ~= nil and S.on() and KnoxLootPanel.canMark(container) and not KnoxLootPanel.isSeen(container)
end

-- A bag opened in a window of its own (double click on its tile) is searched
-- there as in the surroundings: the window that is active gets the search, and
-- what a window not searched right now holds is hidden until the character
-- knows it (it showed everything at once: a player's report, 2026-10-14).
local function windowed(container)
    if not KnoxContainerWindow then return false end
    for _, w in ipairs(KnoxContainerWindow.list) do
        if w.view and w.view.container == container then return true end
    end
    return false
end

-- The sections of the inventory column: the bags on the character. One picked
-- up and put on without a look inside is searched there too.
local function sections()
    local screen = KnoxScreen and KnoxScreen.instance
    return screen and screen.inventory and screen.inventory.sections or {}
end

local function sectioned(container)
    for _, s in ipairs(sections()) do
        if not s.pockets and s.view and s.view.container == container then return true end
    end
    return false
end

--- "hidden", "current" (and how far, 0..1) or nil for a thing lying in a grid.
function S.stateOf(item)
    local c = item:getContainer()
    if c ~= S.container then
        -- (a container whose search waits - the surroundings' one while a bag
        -- is searched, a bag window not active, a bag on the character waiting
        -- its turn: what is not known is not seen)
        -- (asked for every tile every frame: the cheap questions first - with the
        -- search off, or the thing elsewhere, its modData is never looked at)
        if c and S.on() and (c == S.selected or windowed(c) or sectioned(c)) and not S.isKnown(item) and S.needs(c) then return "hidden" end
        return nil
    end
    if not S.hidden[item] or not S.on() then return nil end
    if S.current[item] then
        local q = S.queue[1]
        return "current", q and math.min(1, S.spent / q.ms) or 1
    end
    return "hidden"
end

function S.isHidden(item)
    return S.stateOf(item) ~= nil
end

--- Not seen by the character: hidden in a grid, or lying unknown in a container
--- not looked into that has no grid open (a bag in a cupboard). The search by
--- name counts and lists only what is seen.
function S.unseen(item)
    if S.isHidden(item) then return true end
    return not S.isKnown(item) and S.needs(item:getContainer())
end

-- Things the character knows: what it has carried, found in a search, or seen
-- in a container already looked into. A bag put down and opened again is not
-- searched for what was packed into it a minute ago (a player's remark,
-- 2026-10-14) - only for what is new in it. Kept in the thing's modData
-- (knoxK), so it lasts with the save.

-- (S.known only spares a look at the modData, which keeps it anyway: let go of
-- now and then - it held every thing seen in the game, a town's worth of them)
local KNOWN_MAX = 20000
local knownN = 0
local function remember(item)
    if knownN >= KNOWN_MAX then
        -- (things of a search left half-way are known by their modData too)
        S.known, knownN = {}, 0
    end
    S.known[item] = true
    knownN = knownN + 1
end

-- (in a game with others what a character knows is its own - the author, 2026-10-20:
-- kept by the server per character, KnoxNet; the thing's modData is the world's)
local function net()
    return KnoxNet ~= nil and KnoxNet.mp()
end

function S.isKnown(item)
    if S.known[item] then return true end
    if net() then
        if KnoxNet.isKnown(item) then
            remember(item)
            return true
        end
        return false
    end
    local md = item:hasModData() and item:getModData()
    if md and md.knoxK == true then
        remember(item)   -- (asked for every tile every frame: the modData is read once)
        return true
    end
    return false
end

function S.markKnown(item)
    if not S.known[item] then remember(item) end
    if net() then
        KnoxNet.setKnown(item)
        return
    end
    local md = item:getModData()
    if md.knoxK ~= true then md.knoxK = true end
end

-- (counted a few times a second, not every frame: the list draws every row each frame)
local knownCache, knownCacheN = {}, 0
local KNOWN_MS = 300

--- How many things in a container not searched through the character knows:
--- found in a search left half-way, or put there. `q` (optional): only those
--- the search by name lights up (KnoxGridView.hit). 0 for one never looked into.
function S.knownIn(container, q)
    if not container then return 0 end
    local now = getTimestampMs()
    local c = knownCache[container]
    if c and c.q == q and now - c.ms < KNOWN_MS then return c.n end
    local n = 0
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if S.isKnown(it) and (not q or KnoxGridView.hit(it, q)) then n = n + 1 end
    end
    -- (one entry per container ever listed: let go of when there are many)
    if not c then
        knownCacheN = knownCacheN + 1
        if knownCacheN > 500 then knownCache, knownCacheN = {}, 1 end
    end
    knownCache[container] = {q = q, ms = now, n = n}
    return n
end

--- The things lying in a container known (its own, not what is in its bags).
function S.markIn(container)
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if not S.known[it] then S.markKnown(it) end
    end
end

--- Everything in a container, at any depth, known - only the kit a new
--- character starts with (see the end of the file): a bag picked up later is
--- not known by being carried.
function S.markAllIn(container, depth)
    if not container or (depth or 0) > 3 then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if not S.known[it] then S.markKnown(it) end
        if instanceof(it, "InventoryContainer") and it:getInventory() then
            KnoxLootPanel.markSeen(it:getInventory())
            S.markAllIn(it:getInventory(), (depth or 0) + 1)
        end
    end
end

--- A container has been chosen in the surroundings: start (or take up) its
--- search if it has not been looked into. `layout`: its grid, just built.
--- @return boolean true = a search is on, the container is not to be marked as seen yet
function S.begin(container, layout)
    stop()
    if not S.on() or not container or not layout then return false end
    if not KnoxLootPanel.canMark(container) or KnoxLootPanel.isSeen(container) then return false end
    -- A body: what it wears and what hangs on it is in plain sight - the
    -- character is standing over it - and is not searched for. Only what is in
    -- its pockets is. (A player's remark, 2026-10-13: "why look for the clothes
    -- of a zombie lying right in front of you".)
    -- A mannequin the same: what it wears is on show (the author, 2026-10-18).
    local body = container:getParent()
    local worn, attached = nil, nil
    if body and (instanceof(body, "IsoDeadBody") or instanceof(body, "IsoGameCharacter")) then
        worn, attached = body:getWornItems(), body:getAttachedItems()
    elseif body and instanceof(body, "IsoMannequin") then
        worn = body:getWornItems()
    end
    local function inSight(item)
        if not body or not (worn or attached) then return false end
        if worn and worn:contains(item) then return true end
        if attached and attached:contains(item) then return true end
        -- (a body that keeps no list of what it wore: its clothes are taken as worn)
        return (worn == nil or worn:isEmpty()) and instanceof(item, "Clothing")
    end
    local tiles = {}
    for _, e in ipairs(layout.placed) do
        if not e.ghost and not e.reserved then
            local known = true
            for _, it in ipairs(e.items) do
                if not S.isKnown(it) then known = false end
            end
            if known then
                -- (carried before, or found earlier: nothing to look for)
            elseif inSight(e.item) then
                for _, it in ipairs(e.items) do S.markKnown(it) end
            else
                table.insert(tiles, e)
            end
        end
    end
    if #tiles == 0 then return false end
    -- found row after row, left to right
    table.sort(tiles, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    S.container = container
    -- (the player's own pace: the settings' "search time", 25..400 %)
    local pace = T.look("search.time") / 100
    if TRASH[container:getType()] then pace = pace * TRASH_PACE end
    for _, e in ipairs(tiles) do
        local w, h = KnoxGrid.dims(e, e.r)
        local items = {}
        for _, it in ipairs(e.items) do
            table.insert(items, it)
            S.hidden[it] = true
        end
        table.insert(S.queue, {items = items, ms = math.max(40, math.min(MAX_MS, BASE_MS + CELL_MS * (w * h - 1)) * pace)})
    end
    S.total, S.done, S.spent = #S.queue, 0, 0
    S.lastMs = getTimestampMs()
    for _, it in ipairs(S.queue[1].items) do S.current[it] = true end
    return true
end

--- Every frame while the surroundings are shown; `selected`: the container on
--- show there, `layout`: its grid. One container at a time: the active bag
--- window first, then a bag on the character (its section unfolded), then the
--- surroundings; one done or left, the next takes up from where it was.
function S.tick(selected, layout)
    S.selected = selected
    local want, wantLayout = selected, layout
    local win = KnoxContainerWindow and KnoxContainerWindow.active
    if win and win.view and not win.foldMs and S.needs(win.view.container) then
        want, wantLayout = win.view.container, win.view.layout
    else
        for _, s in ipairs(sections()) do
            if not s.pockets and not s.collapsed and s.view and S.needs(s.view.container) then
                want, wantLayout = s.view.container, s.view.layout
                break
            end
        end
    end
    if want ~= S.container then
        if S.needs(want) and wantLayout then
            if not S.begin(want, wantLayout) then KnoxLootPanel.markSeen(want) end
        elseif S.container then
            stop()
        end
        return
    end
    if not S.container then return end
    if not S.on() then
        stop()
        return
    end
    local now = getTimestampMs()
    local dt = math.min(100, now - S.lastMs)
    S.lastMs = now
    if isGamePaused() then return end
    KnoxSearchSound.rummage()
    S.spent = S.spent + dt
    local q = S.queue[1]
    -- (a thing that is gone meanwhile takes no time)
    while q do
        local here = false
        for _, it in ipairs(q.items) do
            if it:getContainer() == S.container then here = true end
        end
        if here and S.spent < q.ms then break end
        if here then
            S.spent = S.spent - q.ms
            KnoxSearchSound.found(q.items[1])   -- (a stack: one sound)
        end
        for _, it in ipairs(q.items) do
            S.hidden[it], S.current[it] = nil, nil
            S.markKnown(it)
            if here and KnoxGridView then KnoxGridView.settle[it] = now end   -- found: it settles into its cells
        end
        table.remove(S.queue, 1)
        S.done = S.done + 1
        q = S.queue[1]
        if q then
            for _, it in ipairs(q.items) do S.current[it] = true end
        end
    end
    if not q then
        local c = S.container
        stop()
        KnoxLootPanel.markSeen(c)
    end
end

--- The tile of the thing being found: a dark plate filling with sand from the
--- bottom, in a frame that breathes.
function S.drawCurrent(ui, x, y, w, h, frac, a)
    a = a or 1
    local c = T.color.accent
    T.rect(ui, x, y, w, h, T.color.header, a)
    local fh = math.floor(h * frac + 0.5)
    if fh > 0 then ui:drawRect(x, y + h - fh, w, fh, 0.16 * a, c.r, c.g, c.b) end
    local p = 0.5 + 0.5 * math.sin(getTimestampMs() / 1000 * math.pi * 2.4)
    T.tileFrame(ui, x, y, w, h, c, (0.35 + 0.4 * p) * a)
end

-- A new character knows its own kit, bags and all (a bag it starts with is
-- not searched). Only at the very start: a bag picked up later is not known
-- by being carried.
-- (a few ticks later: the game and other mods may hand out the starting
-- things after OnNewGame has gone round)
local kitFor, kitTicks = nil, 0
local function markKit()
    kitTicks = kitTicks + 1
    if kitTicks < 3 then return end
    -- (in a game with others: once the server has said what the character knows)
    if KnoxNet and KnoxNet.mp() and not KnoxNet.ready then return end
    Events.OnTick.Remove(markKit)
    if kitFor and kitFor.getInventory then S.markAllIn(kitFor:getInventory()) end
    kitFor = nil
end
Events.OnNewGame.Add(function(player)
    if not player then return end
    kitFor, kitTicks = player, 0
    Events.OnTick.Add(markKit)
end)

return KnoxSearch
