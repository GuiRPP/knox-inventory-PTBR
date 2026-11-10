-- Things go back to their place (KnoxHome, the author 2026-11-07), outside the game
-- (tools/home/test.ps1): what the game takes out of a bag keeps its place there - held,
-- a silhouette on it, while the thing is in a hand or busy - and goes back when let go;
-- what the player moves himself stays where he put it.

local G, H = KnoxGrid, KnoxHome
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else
        fail = fail + 1
        print("FAIL " .. name .. " : " .. tostring(detail))
    end
end

local function list(t)
    local l = {t = t}
    function l:size() return #self.t end
    function l:get(i) return self.t[i + 1] end
    function l:contains(x)
        for _, v in ipairs(self.t) do if v == x then return true end end
        return false
    end
    return l
end

local function container(kind)
    local c = {items = {}, kind = kind or "bag"}
    function c:getItems() return list(self.items) end
    function c:getContainingItem() return self.holder end
    function c:getType() return self.kind end
    function c:getParent() return nil end
    function c:getCapacity() return 20 end
    function c:add(it) table.insert(self.items, it); it.container = self; return it end
    function c:remove(it)
        for i, v in ipairs(self.items) do if v == it then table.remove(self.items, i) break end end
        it.container = nil
    end
    return c
end

local SIZES = {}
local realGet, realStack = KnoxFootprint.get, KnoxFootprint.stack
KnoxFootprint.get = function(item) local s = SIZES[item.ft]; if s then return s[1], s[2] end return realGet(item) end
KnoxFootprint.stack = function(item) local s = SIZES[item.ft]; if s then return s[3] or 1 end return realStack(item) end
KnoxFootprint.isSmoke = function() return false end
G.isStackable = function() return false end
SIZES["T.Torch"] = {1, 2}
SIZES["T.Apple"] = {1, 1}
SIZES["T.Shirt"] = {2, 2}
SIZES["T.Can"] = {1, 1}

local nextId = 100
local function thing(ft)
    local it = {ft = ft, md = {}, classes = {InventoryItem = true}, id = nextId, slot = -1}
    nextId = nextId + 1
    function it:getFullType() return self.ft end
    function it:getModData() return self.md end
    function it:hasModData() return true end
    function it:getContainer() return self.container end
    function it:getFluidContainer() return nil end
    function it:getConditionMax() return 0 end
    function it:getCondition() return 0 end
    function it:getMaxAmmo() return 0 end
    function it:isHidden() return false end
    function it:isEquipped() return false end
    function it:getAttachedSlot() return self.slot end
    function it:getID() return self.id end
    function it:getDisplayName() return self.ft end
    function it:getActualWeight() return 0.5 end
    function it:getUnequippedWeight() return 0.5 end
    function it:getTex() return nil end
    return it
end

-- the character: a backpack in its pockets (the bag's place there doesn't matter here)
local player = {isPlayer = true, inv = container("none"), worn = {}, hand1 = nil, hand2 = nil}
function player:getInventory() return self.inv end
function player:getWornItems() return list(self.worn) end
function player:getPrimaryHandItem() return self.hand1 end
function player:getSecondaryHandItem() return self.hand2 end
function player:isEquipped(it) return it == self.hand1 or it == self.hand2 end
function player:getPlayerNum() return 0 end
function player:isDead() return false end
function player:isLocalPlayer() return true end
function getSpecificPlayer() return player end
function getNumActivePlayers() return 1 end

local bag = thing("T.Pack")
bag.classes.InventoryContainer = true
bag.inv = container("bag")
bag.inv.holder = bag
function bag:getInventory() return self.inv end
SIZES["T.Pack"] = {2, 2}
player.inv:add(bag)
local BAG = "i" .. bag:getID()
-- (the backpack a plain 8x6 grid, the pockets 8x4: their real sizes are the footprint test's)
local realSize, realShape = G.getSize, G.shapeOf
G.getSize = function(c, p)
    if c == bag.inv then return 8, 6, nil end
    if c == player.inv then return 8, 4, nil end
    return realSize(c, p)
end
G.shapeOf = function(c, p)
    if c == bag.inv or c == player.inv then return nil end
    return realShape(c, p)
end

--- Put a thing in the backpack at x,y (as the grid saved it).
local function inBag(ft, x, y)
    local it = bag.inv:add(thing(ft))
    it.md.knox = {k = BAG, x = x, y = y, r = 0}
    return it
end

--- The game takes it out into the pockets (transferIfNeeded): its saved place stays the bag's.
local function gameTakes(it)
    bag.inv:remove(it)
    player.inv:add(it)
end

local function ticks(n)
    for _ = 1, n or 1 do
        TEST_CLOCK = TEST_CLOCK + 1000
        local fns = {}
        for fn in pairs(TEST_EVENTS.OnTick or {}) do table.insert(fns, fn) end
        for _, fn in ipairs(fns) do fn() end
    end
end

local function ticking()
    for _ in pairs(TEST_EVENTS.OnTick or {}) do return true end
    return false
end

local function heldAt(L, x, y)
    local e = L.cells[y * L.cols + x + 1]
    return e ~= nil and e.held == true and e
end

-- 1. a flashlight into a hand and out again --------------------------------------------
local torch = inBag("T.Torch", 2, 0)
gameTakes(torch)
player.hand1 = torch
G.build(player.inv, player)                                  -- the pockets: it is noted
check("hand: home kept", torch.md.knoxH and torch.md.knoxH.k == BAG and torch.md.knoxH.x == 2, torch.md.knoxH)
local L = G.build(bag.inv, player, true)
check("hand: place held", heldAt(L, 2, 0) and heldAt(L, 2, 1), "cells 2,0 2,1")
check("hand: nothing else there", not L:fits(2, 0, 1, 1), "fits")
TEST_MOVES = {}
ticks(2)
check("hand: stays while in the hand", #TEST_MOVES == 0, #TEST_MOVES)
check("hand: no tick left while it waits for the hand", not ticking(), "ticking")
player.hand1 = nil
H.poke()
ticks(1)
check("hand: goes back", #TEST_MOVES == 1 and TEST_MOVES[1].key == BAG and TEST_MOVES[1].x == 2 and TEST_MOVES[1].y == 0,
    TEST_MOVES[1] and (TEST_MOVES[1].key .. " " .. TEST_MOVES[1].x .. "," .. TEST_MOVES[1].y))
check("hand: in the bag again", torch:getContainer() == bag.inv, "container")
check("hand: home forgotten", torch.md.knoxH == nil and H.homes[torch] == nil, "knoxH")
check("hand: the tick gone", not ticking(), "ticking")
L = G.build(bag.inv, player)
local at = L.cells[0 * L.cols + 2 + 1]
check("hand: lies at its cell", at and at.item == torch and not at.held, at and at.item and at.item.ft)

-- 2. half eaten: waits for the queue, then back -----------------------------------------
local apple = inBag("T.Apple", 0, 1)
gameTakes(apple)
G.build(player.inv, player)
check("eat: home kept", apple.md.knoxH ~= nil, "knoxH")
L = G.build(bag.inv, player, true)
check("eat: place held while it lies in the pockets", heldAt(L, 0, 1), "0,1")
ISTimedActionQueue.queues[player] = {queue = {{}}}
TEST_MOVES = {}
H.poke()
ticks(3)
check("eat: waits while the queue is busy", #TEST_MOVES == 0 and ticking(), #TEST_MOVES)
ISTimedActionQueue.queues[player] = {queue = {}}
ticks(1)
check("eat: back when the queue is empty", #TEST_MOVES == 1 and apple:getContainer() == bag.inv, #TEST_MOVES)
check("eat: tick gone", not ticking(), "ticking")

-- 3. used up: forgotten, nothing moves --------------------------------------------------
local can = inBag("T.Can", 3, 0)
gameTakes(can)
G.build(player.inv, player)
player.inv:remove(can)                                       -- eaten whole
TEST_MOVES = {}
H.poke()
ticks(1)
check("used up: nothing moves", #TEST_MOVES == 0, #TEST_MOVES)
check("used up: forgotten", H.homes[can] == nil, "homes")

-- 4. the player's own move into the pockets: stays there ----------------------------------
local torch2 = inBag("T.Torch", 4, 0)
G.writePending({item = torch2, items = {torch2}}, "p", 0, 0, 0)
bag.inv:remove(torch2)
player.inv:add(torch2)
G.build(player.inv, player)
check("mine: no home", torch2.md.knoxH == nil, "knoxH")
check("mine: its place is the pockets'", torch2.md.knox and torch2.md.knox.k == "p", torch2.md.knox and torch2.md.knox.k)
player.hand1 = torch2
L = G.build(player.inv, player, true)
local pe = L.cells[torch2.md.knox.y * L.cols + torch2.md.knox.x + 1]
check("mine: in a hand, its pockets' place held", pe and pe.held and pe.item == torch2, pe and tostring(pe.held))
player.hand1 = nil
TEST_MOVES = {}
H.poke()
ticks(1)
check("mine: not moved to the bag", #TEST_MOVES == 0 and torch2:getContainer() == player.inv, #TEST_MOVES)
player.inv:remove(torch2)

-- 5. worn: no place held, back when taken off ---------------------------------------------
local shirt = inBag("T.Shirt", 0, 2)
shirt.wear = "tshirt"
gameTakes(shirt)
G.build(player.inv, player)
L = G.build(bag.inv, player, true)
check("worn: not held on its way to the body either", not heldAt(L, 0, 2), "held")
player.worn = {shirt}
G.build(player.inv, player)
check("worn: home kept", shirt.md.knoxH ~= nil, "knoxH")
L = G.build(bag.inv, player, true)
check("worn: place not held", not heldAt(L, 0, 2), "held")
player.worn = {}
TEST_MOVES = {}
H.poke()
ticks(1)
check("worn: back when taken off", #TEST_MOVES == 1 and TEST_MOVES[1].x == 0 and TEST_MOVES[1].y == 2, #TEST_MOVES)

-- 6. its cells taken meanwhile: the bag's first free place ---------------------------------
local torch3 = inBag("T.Torch", 5, 0)
gameTakes(torch3)
player.worn = {torch3}                                       -- (not held: as worn)
G.build(player.inv, player)
inBag("T.Can", 5, 0)                                         -- something lies there now
player.worn = {}
TEST_MOVES = {}
H.poke()
ticks(1)
local mv = TEST_MOVES[1]
check("taken: still goes into the bag", mv and mv.key == BAG and not (mv.x == 5 and mv.y == 0),
    mv and (mv.x .. "," .. mv.y))

-- 7. the bag gone from the character: stays in the pockets -----------------------------------
local torch4 = inBag("T.Torch", 6, 0)
gameTakes(torch4)
player.hand1 = torch4
G.build(player.inv, player)
player.inv:remove(bag)
player.hand1 = nil
TEST_MOVES = {}
H.poke()
ticks(1)
check("no bag: nothing moves", #TEST_MOVES == 0 and torch4:getContainer() == player.inv, #TEST_MOVES)
check("no bag: forgotten", torch4.md.knoxH == nil, "knoxH")
player.inv:remove(torch4)
player.inv:add(bag)

-- 8. switched off: nothing kept, nothing held -----------------------------------------------
KnoxTheme.switches.home = false
local torch5 = inBag("T.Torch", 7, 0)
gameTakes(torch5)
player.hand1 = torch5
G.build(player.inv, player)
check("off: no home", torch5.md.knoxH == nil, "knoxH")
L = G.build(bag.inv, player, true)
check("off: no place held", not heldAt(L, 7, 0), "held")
KnoxTheme.switches.home = true
player.hand1 = nil

-- 9. switched off with a home waiting: forgotten, not sent back later ------------------------
local torch6 = inBag("T.Torch", 0, 3)
gameTakes(torch6)
player.hand1 = torch6
G.build(player.inv, player)
check("off later: home kept first", torch6.md.knoxH ~= nil, "knoxH")
KnoxTheme.switches.home = false
player.hand1 = nil
H.poke()
check("off later: forgotten", torch6.md.knoxH == nil and H.homes[torch6] == nil, "knoxH")
KnoxTheme.switches.home = true
TEST_MOVES = {}
H.poke()
ticks(1)
check("off later: stays in the pockets", #TEST_MOVES == 0, #TEST_MOVES)

-- 10. the player puts the thing somewhere himself: forgotten ---------------------------------
local torch7 = inBag("T.Torch", 1, 3)
gameTakes(torch7)
player.hand1 = torch7
G.build(player.inv, player)
G.writePending({item = torch7, items = {torch7}}, "p", 3, 0, 0)
check("own move: forgotten", torch7.md.knoxH == nil, "knoxH")

-- 11. taken out and laid in the pockets before it went into the hand: one silhouette, the bag's
local torch8 = inBag("T.Torch", 2, 3)
gameTakes(torch8)
G.build(player.inv, player)                                  -- (lies in the pockets a moment)
check("one: noted", torch8.md.knoxH ~= nil and torch8.md.knox.k == "p", torch8.md.knox and torch8.md.knox.k)
player.hand1 = torch8
L = G.build(player.inv, player, true)
local twice = false
for _, e in ipairs(L.placed) do if e.held and e.item == torch8 then twice = true end end
check("one: no silhouette in the pockets", not twice, "held in the pockets")
L = G.build(bag.inv, player, true)
check("one: the silhouette in the bag", heldAt(L, 2, 3), "2,3")
player.hand1 = nil
TEST_MOVES = {}
H.poke()
ticks(1)
check("one: back to the bag", #TEST_MOVES == 1 and TEST_MOVES[1].key == BAG and TEST_MOVES[1].x == 2 and TEST_MOVES[1].y == 3, #TEST_MOVES)

-- 12. a wanted place left from an old move: the player putting the thing down drops it
local torch9 = inBag("T.Torch", 4, 3)
torch9.md.knoxP = {k = "p", x = 0, y = 0, r = 0}            -- (a move into the pockets, never done)
G.writePlace({item = torch9, items = {torch9}}, BAG, 4, 3, 0)
check("stale: the player's own placing drops it", torch9.md.knoxP == nil, torch9.md.knoxP and torch9.md.knoxP.k)
torch9.md.knoxP = {k = "p", x = 0, y = 0, r = 0}
G.writePlace({item = torch9, items = {torch9}}, BAG, 4, 3, 0, true)
check("stale: a grid's own placing keeps it (it may be on its way)", torch9.md.knoxP ~= nil, "knoxP")
torch9.md.knoxP = nil

-- 13. eaten or drunk in part: the game puts it back into its bag itself (ReturnItemToOriginalContainer,
-- a move of its own): it lies at its home, not the bag's first free place (the author's bench 2026-11-08)
local apple2 = inBag("T.Apple", 6, 5)
gameTakes(apple2)
G.build(player.inv, player)
check("game back: noted", apple2.md.knoxH ~= nil and apple2.md.knox.k == "p", apple2.md.knox and apple2.md.knox.k)
player.inv:remove(apple2)
bag.inv:add(apple2)                                          -- (the game's own move: no place written)
TEST_MOVES = {}
H.poke()
ticks(1)
check("game back: at its home", apple2.md.knox and apple2.md.knox.k == BAG and apple2.md.knox.x == 6 and apple2.md.knox.y == 5,
    apple2.md.knox and (apple2.md.knox.k .. " " .. apple2.md.knox.x .. "," .. apple2.md.knox.y))
check("game back: no move of Knox's", #TEST_MOVES == 0, #TEST_MOVES)
check("game back: home forgotten", apple2.md.knoxH == nil and H.homes[apple2] == nil, "knoxH")

-- 14. the same, something put on its silhouette meanwhile: as near to it as there is room
local apple3 = inBag("T.Apple", 3, 5)
gameTakes(apple3)
G.build(player.inv, player)
inBag("T.Can", 3, 5)
player.inv:remove(apple3)
bag.inv:add(apple3)
H.poke()
ticks(1)
local p3 = apple3.md.knox
local d3 = p3 and p3.k == BAG and math.abs(p3.x - 3) + math.abs(p3.y - 5) or -1
check("covered, game back: next to its home", d3 == 1, p3 and (p3.x .. "," .. p3.y))

-- 15. its silhouette may be covered by a drag (the author 2026-11-08); the thing goes back next to it
local torch10 = inBag("T.Torch", 7, 2)
gameTakes(torch10)
player.hand1 = torch10
G.build(player.inv, player)
L = G.build(bag.inv, player, true)
check("cover: held", heldAt(L, 7, 2), "7,2")
check("cover: nothing may be put there on its own", not L:fits(7, 2, 1, 1), "fits")
check("cover: a drag may", L:fits(7, 2, 1, 1, nil, true), "fits over held")
inBag("T.Can", 7, 2)                                         -- (dropped there)
player.hand1 = nil
TEST_MOVES = {}
H.poke()
ticks(1)
local mv10 = TEST_MOVES[1]
local d10 = mv10 and mv10.key == BAG and math.abs(mv10.x - 7) + math.abs(mv10.y - 2) or -1
check("cover: goes back next to its lost place", d10 == 1, mv10 and (mv10.x .. "," .. mv10.y))

-- 16. a battery out of a flashlight: onto the batteries' stack of the bag, not a tile of
-- its own (the author 2026-11-08) - a stack with its own id, the new one with none
G.isStackable = function(it) return it.ft == "T.Battery" end
SIZES["T.Battery"] = {1, 1, 10}
local bat1, bat2 = inBag("T.Battery", 5, 5), inBag("T.Battery", 5, 5)
bat1.md.knoxS, bat2.md.knoxS = "s1", "s1"
local newBat = bag.inv:add(thing("T.Battery"))
L = G.build(bag.inv, player)
local onTile = L.cells[5 * L.cols + 5 + 1]
check("battery: onto the stack", onTile and #onTile.items == 3, onTile and #onTile.items)
check("battery: its place the stack's", newBat.md.knox and newBat.md.knox.x == 5 and newBat.md.knox.y == 5, newBat.md.knox)
check("battery: the stack's id", newBat.md.knoxS == "s1", newBat.md.knoxS)
-- (a full stack: a tile of its own)
SIZES["T.Battery"] = {1, 1, 3}
local newBat2 = bag.inv:add(thing("T.Battery"))
L = G.build(bag.inv, player)
check("battery: full stack - its own tile", newBat2.md.knoxS == nil and newBat2.md.knox
    and not (newBat2.md.knox.x == 5 and newBat2.md.knox.y == 5), newBat2.md.knox)
G.isStackable = function() return false end

print("home: " .. pass .. " pass, " .. fail .. " fail")
