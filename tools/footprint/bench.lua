-- What building a grid costs on big containers, outside the game on its own Lua (tools/footprint/bench.ps1):
-- the same stand-ins as test.lua, real item types from KnoxFootprintData. ms per build; compare before and after a change.
local G = KnoxGrid
local clock = 1000
function getTimestampMs() return clock end
function getText(key) return key end
local rng = 12345
function ZombRand(n) rng = (rng * 1103515245 + 12345) % 2147483648 return rng % n end
function instanceof(obj, class)
    return type(obj) == "table" and obj.classes ~= nil and obj.classes[class] == true
end
local function list(t)
    local l = {t = t}
    function l:size() return #self.t end
    function l:get(i) return self.t[i + 1] end
    return l
end
local sq = {}
function sq:getX() return 100 end
function sq:getY() return 200 end
function sq:getZ() return 0 end
local parent = {}
function parent:getSquare() return sq end
local function container(kind, capacity, withParent)
    local c = {items = {}, kind = kind, capacity = capacity or 10}
    function c:getItems() return list(self.items) end
    function c:getContainingItem() return self.holder end
    function c:getType() return self.kind end
    function c:getParent() return withParent and parent or nil end
    function c:getCapacity() return self.capacity end
    function c:getCapacityWeight() return 0 end
    function c:add(it) table.insert(self.items, it) it.container = self return it end
    return c
end
local nextId = 1
local function item(fullType, o)
    o = o or {}
    local it = {ft = fullType, md = {}, o = o, classes = {InventoryItem = true}, id = nextId}
    nextId = nextId + 1
    if o.class then it.classes[o.class] = true end
    function it:getFullType() return self.ft end
    function it:getModData() return self.md end
    function it:hasModData()
        for _ in pairs(self.md) do return true end
        return false
    end
    function it:getContainer() return self.container end
    function it:getFluidContainer() return nil end
    function it:getConditionMax() return 0 end
    function it:getMaxAmmo() return 0 end
    function it:getCurrentAmmoCount() return 0 end
    function it:getCondition() return 0 end
    function it:IsDrainable() return false end
    function it:getWeight() return 0.3 end
    function it:getActualWeight() return 0.3 end
    function it:getUnequippedWeight() return 0.3 end
    function it:getAttachedSlot() return -1 end
    function it:isEquipped() return false end
    function it:isHidden() return false end
    function it:getInventory() return nil end
    function it:getID() return self.id end
    function it:getDisplayName() return self.ft end
    return it
end
function getScriptManager() return {getModelScript = function() return nil end} end
function knoxMeasureModel() return nil end

-- real types of the game, mixed: things that stack and things that don"t
local types = {}
for ft in pairs(KnoxFootprintData) do
    if not KnoxBagData[ft] then table.insert(types, ft) end
end
table.sort(types)
local function fill(c, n, stackEvery)
    for i = 1, n do
        local ft = types[(i * 37) % #types + 1]
        local cls = (i % stackEvery == 0) and nil or "Clothing"   -- clothing: one per tile
        c:add(item(ft, {class = cls}))
    end
end

local function bench(name, fn, reps)
    local t0 = os.time()
    for _ = 1, reps do fn() end
    local ms = (os.time() - t0) * 1000 / reps
    print(string.format("%-46s %8.2f ms", name, ms))
end

-- 1. a warehouse shelf: 300 things, places saved after the first build
local shelf = container("shelves", 120, true)
fill(shelf, 300, 4)
G.build(shelf, nil)
bench("shelf 300, rebuild (places saved)", function() G.build(shelf, nil) end, 40)

-- 2. the same, first look (never placed: scattered at random)
bench("shelf 300, first build (scatter)", function()
    for _, it in ipairs(shelf.items) do it.md = {} end
    G.build(shelf, nil)
end, 10)

-- 3. a floor of 600 things (most in the overflow rows)
local floor = container("floor", 50, true)
fill(floor, 600, 3)
G.build(floor, nil)
bench("floor 600, rebuild", function() G.build(floor, nil) end, 20)

-- 4. a dry build (what nestRefusal / drag checks do)
bench("shelf 300, dry build", function() G.build(shelf, nil, true) end, 40)

-- 5. cells used of the shelf (bag headers count it a few times a second)
bench("shelf 300, usedCells", function() G.usedCells(shelf) end, 40)

-- 6. thirty things on their way at once (a Ctrl selection dropped into a bag: the
-- game merges the transfers into one action's queueList). What one frame asks of
-- the moves: the screen's and the equipment column's lists, the faded copy of
-- each thing, the source grid's build (each frame a new clock, as in the game).
do
    local from = container("shelves", 120, true)
    local moving = {}
    for i = 1, 30 do table.insert(moving, from:add(item(types[(i * 37) % #types + 1], {class = "Clothing"}))) end
    G.build(from, nil)
    local who = {}
    local transfer = {action = {}, queueList = {}}
    function transfer:getJobDelta() return 0.5 end
    for _, it in ipairs(moving) do table.insert(transfer.queueList, {items = {it}}) end
    ISTimedActionQueue = {queues = {[who] = {queue = {transfer}}}}
    local steps = {}
    for _, it in ipairs(moving) do table.insert(steps, {action = transfer, weight = 10, item = it}) end
    local rec = {source = {kind = "grid", key = "x", x = 0, y = 0, r = 0}, steps = steps, total = 300,
                 player = who, items = moving, t = clock}
    for _, it in ipairs(moving) do G.pending[it] = rec end
    bench("30 moving: one frame's questions", function()
        clock = clock + 16
        G.pendingList()
        G.pendingList()
        for _, it in ipairs(moving) do G.pendingOf(it) end
        G.build(from, nil)
    end, 20)
    G.pending = {}
    ISTimedActionQueue = nil
end

KnoxGrid.scatterOn = function() return false end
bench("shelf 300, rebuild, scatter off", function() G.build(shelf, nil) end, 40)
bench("floor 600, rebuild, scatter off", function() G.build(floor, nil) end, 20)
