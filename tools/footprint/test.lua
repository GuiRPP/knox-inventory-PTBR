-- Runs the mod's footprint and grid code outside the game, on the game's own Lua,
-- against stand-ins for items, containers and the player (tools/footprint/test.ps1):
--
--   LuaRun.java stubs.lua KnoxFootprintData.lua KnoxFootprint.lua KnoxGrid.lua test.lua
--
-- It checks what the in-game self-test can't reach without the right things at
-- hand: an item of another mod going through the rules while its model loads,
-- the pockets growing with clothes, stacks splitting at their limit, bags in bags.

local F, G = KnoxFootprint, KnoxGrid
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then
        pass = pass + 1
    else
        fail = fail + 1
        print("FAIL " .. name .. " : " .. tostring(detail))
    end
end

-- stand-ins -------------------------------------------------------------------
local clock = 1000
function getTimestampMs() return clock end
function getText(key) return key end
function instanceof(obj, class)
    return type(obj) == "table" and obj.classes ~= nil and obj.classes[class] == true
end

local function list(t)
    local l = {t = t}
    function l:size() return #self.t end
    function l:get(i) return self.t[i + 1] end
    return l
end

local nextId = 1
local function container(kind, capacity)
    local c = {items = {}, kind = kind, capacity = capacity or 10}
    function c:getItems() return list(self.items) end
    function c:getContainingItem() return self.holder end
    function c:getType() return self.kind end
    function c:getParent() return nil end
    function c:getCapacity() return self.capacity end
    function c:isEmpty() return #self.items == 0 end
    function c:getCapacityWeight()
        local kg = 0
        for _, it in ipairs(self.items) do kg = kg + it:getActualWeight() end
        return kg
    end
    function c:add(it)
        table.insert(self.items, it)
        it.container = self
        return it
    end
    return c
end

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
    function it:getFluidContainer() return self.o.fluid end
    function it:getConditionMax() return 0 end
    function it:getMaxAmmo() return self.o.maxAmmo or 0 end
    function it:getCurrentAmmoCount() return self.o.ammo or 0 end
    function it:getCondition() return 0 end
    function it:IsDrainable() return self.o.drain == true end
    function it:getWeight() return self.o.weight or 0.1 end
    function it:getActualWeight() return self.o.actual or self.o.weight or 0.1 end
    function it:getUnequippedWeight() return self:getActualWeight() end
    function it:getAttachedSlot() return -1 end
    function it:isEquipped() return false end
    function it:isHidden() return self.o.hidden == true end
    function it:getInventory() return self.inv end
    function it:getID() return self.id end
    function it:getDisplayName() return self.ft end
    function it:isTwoHandWeapon() return self.o.twoHand == true end
    function it:isRanged() return self.o.ranged == true end
    function it:getBodyLocation() return self.o.worn end
    function it:canBeEquipped() return self.o.worn end
    function it:getStaticModel() return self.o.static end
    function it:getWorldStaticModel() return self.o.world end
    function it:getWeaponSprite() return self.o.sprite end
    if o.capacity then
        it.classes.InventoryContainer = true
        it.inv = container("bag", o.capacity)
        it.inv.holder = it
    end
    return it
end

local function player(wornList)
    local p = {inv = container("none", 50), worn = {}}
    for _, w in ipairs(wornList or {}) do
        local it = item(w[2], {class = "Clothing", worn = w[1]})
        local entry = {loc = w[1], it = it}
        function entry:getLocation() return self.loc end
        function entry:getItem() return self.it end
        table.insert(p.worn, entry)
    end
    function p:getInventory() return self.inv end
    function p:getWornItems() return list(self.worn) end
    function p:getPrimaryHandItem() return nil end
    function p:getSecondaryHandItem() return nil end
    function p:isEquipped() return false end
    return p
end

-- model scripts and the Java part's measure
local models = {}       -- name -> {answers...}: each call takes the next, the last one stays
function getScriptManager()
    local sm = {}
    function sm:getModelScript(name)
        if not models[name] then return nil end
        local ms = {name = name}
        function ms:getFullType() return self.name end
        return ms
    end
    return sm
end
function knoxMeasureModel(name)
    local a = models[name]
    if not a then return nil end
    if #a > 1 then return table.remove(a, 1) end
    return a[1]
end

-- the game's own items: from the data ---------------------------------------------
local function fp(it)
    local w, h = F.get(it)
    return w .. "x" .. h
end
--- (asks once: an answer may change while a model loads)
local function expect(name, it, want)
    local got = fp(it)
    check(name, got == want, got)
end
check("data: bat", fp(item("Base.BaseballBat")) == "1x4", fp(item("Base.BaseballBat")))
check("data: can", fp(item("Base.TinnedBeans")) == "1x1", fp(item("Base.TinnedBeans")))
check("data: pistol", fp(item("Base.Pistol")) == "1x2", fp(item("Base.Pistol")))
check("data: nails stack", F.stack(item("Base.Nails")) == 40, F.stack(item("Base.Nails")))
check("data: 9 mm stack", F.stack(item("Base.Bullets9mm")) == 100, F.stack(item("Base.Bullets9mm")))
check("data: a weapon doesn't stack", F.stack(item("Base.Axe")) == 1, F.stack(item("Base.Axe")))
-- the author's look over the kitchen and the bathroom (2026-10-22): sizes, stacks
do
    local want = {Chocolate = "1x1", KnifeFillet = "1x1", Strainer = "1x2", Butter = "1x1", RollingPin = "1x2",
                  OvenMitt = "1x1", BreadKnife = "1x2", Toothbrush = "1x1", SewingKit = "1x2", Toothpaste = "1x1",
                  GenericMail = "1x1", LetterHandwritten = "1x1", SheetPaper2 = "1x1", Tissue = "1x1",
                  Flier = "1x1", Flier_Nolans = "1x1", Paperwork = "1x1"}
    local bad = {}
    for name, size in pairs(want) do
        local got = fp(item("Base." .. name))
        if got ~= size then table.insert(bad, name .. " " .. got) end
    end
    check("data: the kitchen's and bathroom's sizes", #bad == 0, table.concat(bad, ", "))
    check("data: a TV remote doesn't stack", F.stack(item("Base.Remote")) == 1, F.stack(item("Base.Remote")))
    check("data: tweezers don't stack", F.stack(item("Base.Tweezers")) == 1 and F.stack(item("Base.Tweezers_Forged")) == 1,
        F.stack(item("Base.Tweezers")))
    -- grass is food: its stack is the hand-set 10, not the count by weight
    local grass = item("Base.GrassTuft", {class = "Food", weight = 0.4})
    check("data: grass 10 a tile", F.stack(grass) == 10, F.stack(grass))
end
do
    local c, r = F.bagGrid(item("Base.Bag_Schoolbag"), 15)
    check("data: school bag grid", c == 5 and r == 6, c .. "x" .. r)
    c, r = F.bagGrid(item("Base.Bag_Schoolbag"), 30)       -- a mod doubled its capacity
    check("data: school bag, capacity doubled", c == 5 and r == 12, c .. "x" .. r)
    c, r = F.bagGrid(item("Base.Bag_RifleCase"), 7)
    check("data: rifle case grid", c == 7 and r == 2, c .. "x" .. r)
    c, r = F.bagGrid(item("Base.Bag_FannyPackFront"), 1)
    -- (a bag has 4 cells at least: F.MIN_BAG_CELLS, the author 2026-10-19)
    check("data: fanny pack grid", c == 2 and r == 2, c .. "x" .. r)
    c, r = F.bagGrid(item("Base.Bag_DuffelBag"), 18)
    check("data: duffel is wide", c > r, c .. "x" .. r)
    c, r = F.bagGrid(item("Base.Bag_ALICEpack"), 28)
    check("data: backpack is tall", r > c and c * r == 56, c .. "x" .. r)
end

-- items of other mods: the rules, the model coming late -----------------------------
models["Mod.RifleModel"] = {"loading", "loading", "0.04,0.12,0.90,1.0"}     -- a rifle 90 units long... 0.9 = 7.8 cells
local rifle = item("Mod.Rifle", {class = "HandWeapon", weight = 4, twoHand = true, ranged = true, static = "Mod.RifleModel"})
expect("mod weapon, model loading: by weight", rifle, "2x3")
expect("mod weapon, still loading", rifle, "2x3")
expect("mod weapon, model in: long and thin", rifle, "1x6")
models["Mod.RifleModel"] = {"0.5,0.5,0.5"}                                   -- (were it asked again, it would change)
expect("mod weapon: remembered", rifle, "1x6")

models["Mod.SlowModel"] = {"loading"}
local slow = item("Mod.Slow", {weight = 0.5, world = "Mod.SlowModel"})
expect("mod item, model never loads: by weight", slow, "1x2")
clock = clock + 20000
expect("mod item, gave up waiting: by weight for good", slow, "1x2")
models["Mod.SlowModel"] = {"0.9,0.9,0.9"}
expect("mod item: not asked again", slow, "1x2")

local nomodel = item("Mod.Gem", {weight = 0.01})
check("mod item without a model", fp(nomodel) == "1x1" and F.stack(nomodel) == 100, fp(nomodel) .. " x" .. F.stack(nomodel))

local shirt = item("Mod.Shirt", {class = "Clothing", worn = "base:TShirt", weight = 1})
expect("mod clothing by where it is worn", shirt, "1x2")
local coat = item("Mod.Coat", {class = "Clothing", worn = "Base.Jacket_Bulky", weight = 2})
expect("mod bulky jacket", coat, "2x2")   -- (every jacket 2x2: the author, 2026-10-20)
models["Mod.BootModel"] = {"0.13,0.13,0.16"}
models["Mod.ShoeModel"] = {"0.06,0.16,0.17"}
check("mod boots (a tall model)", fp(item("Mod.Boots", {class = "Clothing", worn = "base:shoes", world = "Mod.BootModel"})) == "2x2", "")
check("mod shoes (a low model)", fp(item("Mod.Shoes", {class = "Clothing", worn = "base:shoes", world = "Mod.ShoeModel"})) == "1x2", "")
local odd = item("Mod.Cape", {class = "Clothing", worn = "mod:Cape", weight = 1.2})
expect("mod clothing at a location of its own: by weight", odd, "2x2")

local sofa = item("Moveables.Moveable", {class = "Moveable", weight = 25})
expect("furniture by its weight", sofa, "4x4")
sofa.o.weight = 2
expect("furniture: this very item's weight", sofa, "2x2")

do
    models["Mod.PackModel"] = {"0.25,0.30,0.28"}
    local pack = item("Mod.BigPack", {capacity = 30, worn = "base:back", weight = 2, world = "Mod.PackModel"})
    local c, r = F.bagGrid(pack, 30)
    check("mod backpack: about 60 cells, tall", math.abs(c * r - 60) <= 3 and r > c, c .. "x" .. r)
    local duffel = item("Mod.TacticalDuffel", {capacity = 18, worn = "base:back", weight = 1})
    c, r = F.bagGrid(duffel, 18)
    check("mod duffel by its name: wide", c > r, c .. "x" .. r)
    local pouch = item("Mod.Pouch", {capacity = 3, weight = 0.1})
    c, r = F.bagGrid(pouch, 3)
    local w, h = F.get(pouch)
    check("mod organizer: outside a quarter of the inside at least", w * h * 4 >= c * r, w .. "x" .. h .. " for " .. c .. "x" .. r)
end

-- pockets -----------------------------------------------------------------------
local naked = player({})
local c, r, limit = G.getSize(naked.inv, naked)
check("pockets, no clothes: 4 cells", c == 4 and r == 1 and limit == nil, c .. "x" .. r .. " " .. tostring(limit))
local dressed = player({{"base:pants", "Jeans"}, {"base:tshirt", "T"}, {"base:jacket", "Jacket"}, {"base:shoes", "Shoes"}})
c, r, limit = G.getSize(dressed.inv, dressed)
check("pockets, jeans and a jacket: 12 cells", c == 4 and r == 3 and limit == nil, c .. "x" .. r .. " " .. tostring(limit))
local hoodie = player({{"base:pants", "Jeans"}, {"base:sweaterhat", "Hoodie"}})
c, r, limit = G.getSize(hoodie.inv, hoodie)
check("pockets, jeans and a hoodie: 10 cells, the last row cut", c == 4 and r == 3 and limit == 10, c .. "x" .. r .. " " .. tostring(limit))
do
    local rows, total = G.pockets(hoodie)
    check("pockets: where from", #rows == 3 and total == 10 and rows[2][2] == 4, #rows .. " " .. total)
end

-- a grid with its last row cut
do
    for _ = 1, 12 do hoodie.inv:add(item("Base.TinnedBeans", {class = "Food"})) end
    local L = G.build(hoodie.inv, hoodie)
    check("cut grid: ten cans in, two left over", #L.overflow == 2 and L.baseRows == 3 and L.rows > 3, #L.overflow .. " rows " .. L.rows)
    local bad = 0
    for _, e in ipairs(L.placed) do
        if not e.overflow and L:blocked(e.x, e.y) then bad = bad + 1 end
        if e.overflow and e.y < L.baseRows then bad = bad + 1 end
    end
    check("cut grid: nothing on the cells it doesn't have", bad == 0, bad)
    check("cut grid: size as text", G.sizeText(L) == "4x2+2", G.sizeText(L))
    -- a 2x2 thing can't sit on the cut corner
    check("cut grid: block over the cut", not G.emptyLike(L):fits(2, 1, 2, 2), "fits")
    check("cut grid: block beside the cut", G.emptyLike(L):fits(0, 1, 2, 2), "refused")
    local E = G.emptyLike(L)
    check("emptyLike keeps the cut", E.limit == 10 and E.rows == 3, tostring(E.limit))
end

-- stacks ------------------------------------------------------------------------
do
    local bag = item("Base.Bag_Schoolbag", {capacity = 15})
    for _ = 1, 95 do bag.inv:add(item("Base.Nails")) end
    local L = G.build(bag.inv, naked)
    local sizes = {}
    for _, e in ipairs(L.placed) do table.insert(sizes, #e.items) end
    table.sort(sizes)
    check("stacks: 95 nails in tiles of 40", table.concat(sizes, ",") == "15,40,40", table.concat(sizes, ","))
    check("stacks: the bag's compartments", L.shape ~= nil and L.shape.cells == 30, L.shape and L.shape.cells)
    local a, b = L.placed[1], L.placed[2]
    check("stacks: two full tiles don't merge", not G.canMerge(a, b), "merged")
    -- saved places survive a rebuild
    local before = {}
    for _, e in ipairs(L.placed) do before[e.item] = e.x .. "," .. e.y end
    local L2 = G.build(bag.inv, naked)
    local moved = 0
    for _, e in ipairs(L2.placed) do
        if before[e.item] ~= e.x .. "," .. e.y then moved = moved + 1 end
    end
    check("stacks: places stable across rebuilds", moved == 0 and #L2.placed == 3, moved)
end

-- bags in bags ------------------------------------------------------------------
-- (2026-10-19: any bag goes into another and grows with what is in it; refused only
-- when a bag lying in a grid would grow and no longer fit there)
do
    local big = item("Base.Bag_ALICEpack", {capacity = 28})
    local school = item("Base.Bag_Schoolbag", {capacity = 15})
    local kit = item("Base.FirstAidKit", {capacity = 4})
    local nail = item("Base.Nails")
    check("nest: an empty bag into a bag", G.nestRefusal(school, big.inv) == nil, "refused")
    local w0, h0 = F.get(school)
    school.inv:add(item("Base.Nails"))
    check("nest: a bag with things in it", G.nestRefusal(school, big.inv) == nil, tostring(G.nestRefusal(school, big.inv)))
    local w1, h1 = F.get(school)
    check("nest: a bag with things in it grows", w1 * h1 > w0 * h0, w0 .. "x" .. h0 .. " -> " .. w1 .. "x" .. h1)
    check("nest: ...into the pockets", G.nestRefusal(school, naked.inv) == nil, "refused")
    check("nest: ...onto a shelf", G.nestRefusal(school, container("shelves", 30)) == nil, "refused")
    local kw, kh = F.getBase(kit)
    kit.inv:add(item("Base.Bandage"))
    check("nest: an organizer with things in it", G.nestRefusal(kit, big.inv) == nil, "refused")
    local kw1, kh1 = F.get(kit)
    check("nest: an organizer doesn't grow", kw1 == kw and kh1 == kh, kw .. "x" .. kh .. " -> " .. kw1 .. "x" .. kh1)
    local empty = item("Base.Bag_Schoolbag", {capacity = 15})
    big.inv:add(empty)
    check("nest: into a bag lying in a bag, room to grow", G.nestRefusal(nail, empty.inv) == nil, tostring(G.nestRefusal(nail, empty.inv)))
    big.inv:add(kit)
    check("nest: into an organizer lying in a bag", G.nestRefusal(nail, kit.inv) == nil, "refused")
    check("nest: into a bag on its own", G.nestRefusal(nail, big.inv) == nil, "refused")
    -- a full bag with an empty one in it: the one inside can't grow
    local outer = item("Mod.KnoxTestOuter", {capacity = 6})
    local inner = outer.inv:add(item("Mod.KnoxTestInner", {capacity = 10}))
    for _ = 1, G.totalCells(outer.inv, nil) - 1 do outer.inv:add(item("Mod.KnoxTestShirt", {class = "Clothing"})) end
    local nail2 = item("Base.Nails")
    check("nest: into a bag lying in a full bag", G.nestRefusal(nail2, inner.inv) == "IGUI_Knox_BagGrowsNoRoom", tostring(G.nestRefusal(nail2, inner.inv)))
    -- a mod's bag hung on something, in no grid (redchili's bicycle saddlebags,
    -- Sari-n 2026-10-20): its container doesn't list it - nothing to outgrow
    local bike = container("shelves", 10)
    local saddle = item("Mod.KnoxTestSaddlebag", {capacity = 10})
    saddle.container = bike
    check("nest: into a bag in no grid (bicycle saddlebag)", G.nestRefusal(item("Base.Nails"), saddle.inv) == nil, tostring(G.nestRefusal(item("Base.Nails"), saddle.inv)))
end

-- furniture and car boots: roomier than bags, wider when big -----------------------
do
    local function size(capacity)
        local c, r = G.getSize(container("shelves", capacity), naked)
        return c .. "x" .. r
    end
    check("world: a dishwasher (12)", size(12) == "8x5", size(12))
    check("world: a small boot (24) beats the biggest backpack", size(24) == "8x9", size(24))
    check("world: a seat (4)", size(4) == "6x2", size(4))
    check("world: a big boot (60), narrow screen", size(60) == "8x23", size(60))
    G.worldCols = 12
    check("world: a big boot (60), wide screen", size(60) == "12x15", size(60))
    check("world: a small one stays narrow", size(12) == "8x5", size(12))
    G.worldCols = 8
    check("data: a cap is smaller than a T-shirt", fp(item("Base.Hat_BaseballCap")) == "1x1" and fp(item("Base.Tshirt_DefaultTEXTURE")) == "1x2", fp(item("Base.Hat_BaseballCap")))
    check("data: a spoon", fp(item("Base.Spoon")) == "1x1", fp(item("Base.Spoon")))
    check("data: an empty plastic bag", fp(item("Base.Plasticbag")) == "1x1", fp(item("Base.Plasticbag")))
    -- thirteen plastic bags in a plastic bag, as the game leaves them in car boots
    local bag = item("Base.Plasticbag_Bags", {capacity = 8})
    for _ = 1, 13 do bag.inv:add(item("Base.Plasticbag", {capacity = 8})) end
    local L = G.build(bag.inv, naked)
    check("data: thirteen bags in a bag", #L.overflow == 0 and L.cols * L.rows == 16, #L.overflow .. " left over in " .. L.cols .. "x" .. L.rows)
end

-- things found in furniture lie at random places; an overfull shelf loses nothing --
do
    local seed = 7
    function ZombRand(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
    local sq = {getX = function() return 1 end, getY = function() return 2 end, getZ = function() return 0 end}
    local obj = {getSquare = function() return sq end}
    local function furniture(capacity)
        local c = container("shelves", capacity)
        function c:getParent() return obj end
        return c
    end
    local shelf = furniture(12)
    for _ = 1, 10 do shelf:add(item("Mod.KnoxTestShirt", {class = "Clothing"})) end
    local L = G.build(shelf, naked)
    local placed = 0
    for _, it in ipairs(shelf.items) do if it.md.knox then placed = placed + 1 end end
    check("scatter: all found things placed", #L.overflow == 0 and placed == 10, #L.overflow .. " over, " .. placed .. " placed")
    local L2 = G.build(shelf, naked)
    local moved = 0
    for _, e in ipairs(L2.placed) do
        local p = e.item.md.knox
        if not p or p.x ~= e.x or p.y ~= e.y then moved = moved + 1 end
    end
    check("scatter: places kept on the next build", moved == 0, moved)
    -- more than fits: what has room is placed, the rest lies under the grid, nothing lost
    local full = furniture(4)
    for _ = 1, 40 do full:add(item("Mod.KnoxTestShirt", {class = "Clothing"})) end
    local cells = G.totalCells(full, naked)
    local L3 = G.build(full, naked)
    check("overfull: every thing shown", #L3.placed == 40, #L3.placed)
    check("overfull: the grid filled first", #L3.placed - #L3.overflow == cells, (#L3.placed - #L3.overflow) .. " of " .. cells)
    local L4 = G.build(full, naked)
    check("overfull: the same on the next build", #L4.overflow == #L3.overflow, #L4.overflow)
end

-- magazines: loaded and empty ones are tiles of their own (Nik_135) ----------------
do
    local bag = item("Base.Bag_Schoolbag", {capacity = 15})
    local full1 = bag.inv:add(item("Base.9mmClip", {maxAmmo = 15, ammo = 15}))
    local full2 = bag.inv:add(item("Base.9mmClip", {maxAmmo = 15, ammo = 15}))
    local empty = bag.inv:add(item("Base.9mmClip", {maxAmmo = 15, ammo = 0}))
    local L = G.build(bag.inv, naked)
    local tiles = 0
    for _, e in ipairs(L.placed) do if e.item:getFullType() == "Base.9mmClip" then tiles = tiles + 1 end end
    check("magazines: full ones stack, the empty one apart", tiles == 2, tiles .. " tiles")
    check("magazines: an empty one doesn't merge into full ones",
        G.mergeRoom({item = empty, items = {empty}}, {item = full1, items = {full1, full2}}) == 0)
    local full3 = item("Base.9mmClip", {maxAmmo = 15, ammo = 15})
    check("magazines: a full one merges into full ones",
        G.mergeRoom({item = full3, items = {full3}}, {item = full1, items = {full1, full2}}) == 1)
end

-- hidden items (an unarmed-combat mod's fists) get no tile -------------------------
do
    local bag = item("Base.Bag_Schoolbag", {capacity = 15})
    bag.inv:add(item("Base.TinnedBeans"))
    bag.inv:add(item("Mod.Fists", {hidden = true}))
    local L = G.build(bag.inv, naked)
    local n = 0
    for _ in ipairs(L.overflow) do n = n + 1 end
    check("hidden: one tile, nothing left over", #L.placed == 1 and n == 0 and L.placed[1].item:getFullType() == "Base.TinnedBeans",
        #L.placed .. " tiles, " .. n .. " left over")
end

-- topping a stack up, and a move arriving on a stack -----------------------------
do
    local bag = item("Base.Bag_Schoolbag", {capacity = 15})
    local stack = {}
    for _ = 1, 30 do table.insert(stack, bag.inv:add(item("Base.Nails"))) end
    local L = G.build(bag.inv, naked)
    local target = L.placed[1]
    G.writePlace(target, L.key, 2, 1, 0)                   -- the player put it there
    L = G.build(bag.inv, naked)
    target = L.placed[1]
    check("merge: the stack is where it was put", target.x == 2 and target.y == 1 and #target.items == 30, target.x .. "," .. target.y)

    local other = container("shelves", 30)
    local coming = {}
    for _ = 1, 25 do table.insert(coming, other:add(item("Base.Nails"))) end
    local tile = {item = coming[1], items = coming, w = 1, h = 1}
    check("merge: room for ten of the twenty-five", G.mergeRoom(tile, target) == 10, G.mergeRoom(tile, target))
    check("merge: not whole", not G.canMerge(tile, target), "whole")

    -- ten of them on their way to the stack (a timed action in the queue)
    local part = {}
    for i = 16, 25 do table.insert(part, coming[i]) end
    local action = {}
    ISTimedActionQueue = {queues = {[naked] = {queue = {action}}}}
    local rec = {source = nil, target = {kind = "grid", key = L.key, x = 2, y = 1, r = 0},
                 steps = {{action = action, weight = 1}}, total = 1, player = naked, items = part, t = getTimestampMs()}
    for _, it in ipairs(part) do
        G.pending[it] = rec
        it.md.knoxP = {k = L.key, x = 2, y = 1, r = 0}
    end
    G.pendingEpoch = G.pendingEpoch + 1   -- (as KnoxGrid.track does: the list of moves is made anew)
    local during = G.build(bag.inv, naked)
    local t2
    for _, e in ipairs(during.placed) do
        if not e.reserved and not e.ghost then t2 = e end
    end
    check("merge: the stack stays put while the rest is on its way", t2 and t2.x == 2 and t2.y == 1, t2 and (t2.x .. "," .. t2.y) or "gone")
    -- they arrive: in the bag now, with the stack's id, the action over
    ISTimedActionQueue.queues[naked].queue = {}
    for _, it in ipairs(part) do bag.inv:add(it) end
    local after = G.build(bag.inv, naked)
    check("merge: one stack of forty at its place", #after.placed == 1 and #after.placed[1].items == 40
        and after.placed[1].x == 2 and after.placed[1].y == 1,
        #after.placed .. " tiles, " .. #after.placed[1].items .. " at " .. after.placed[1].x .. "," .. after.placed[1].y)
end

-- many things on their way at once: one look at the queue a frame, still exact ----
-- (the game merges transfers between two containers into one action's queueList;
-- a move was asked for each item and faded tile, each ask going through the whole
-- queue: 30 things moving cost ~29 ms a frame - the ultra pass, 2026-10-21)
do
    local from = container("shelves", 30)
    local moving = {}
    for _ = 1, 30 do table.insert(moving, from:add(item("Base.Nails", {class = "Clothing"}))) end
    local transfer = {action = {}, queueList = {}}
    function transfer:getJobDelta() return 0.5 end
    for _, it in ipairs(moving) do table.insert(transfer.queueList, {items = {it}}) end
    ISTimedActionQueue = {queues = {[naked] = {queue = {transfer}}}}
    local steps = {}
    for _, it in ipairs(moving) do table.insert(steps, {action = transfer, weight = 10, item = it}) end
    local rec = {source = {kind = "grid", key = "x", x = 0, y = 0, r = 0}, steps = steps, total = 300,
                 player = naked, items = moving, t = getTimestampMs()}
    for _, it in ipairs(moving) do G.pending[it] = rec end
    G.pendingEpoch = G.pendingEpoch + 1
    local near = function(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-6 end
    local list = G.pendingList()
    check("moves: all thirty listed", #list == 30, #list)
    -- (progress once a move, entries kept, slots apart - 500 bullets, 2026-10-28)
    local same = true
    for _, g in ipairs(list) do if not near(g.progress, list[1].progress) then same = false end end
    check("moves: one progress for all items of a move", same)
    check("moves: in the list", G.inList(moving[7], list) and not G.inList(from:add(item("Base.Pen")), list))
    check("moves: none from or to a slot", #list.slots == 0 and G.leavingSlot(list, "hands") == nil, #list.slots)
    -- (one list a frame for all who ask - the screen, the slots, each grid's build:
    -- 300 us a frame with 500 bullets moved, the author's bench 2026-10-28)
    check("moves: the same list for all who ask in a frame", G.pendingList() == list)
    -- (a frame takes several milliseconds: by the clock it was made anew 2 times a
    -- frame all the same - the author's bench 2026-10-28)
    clock = clock + 5
    check("moves: the same list in a frame while the clock goes on", G.pendingList() == list)
    -- (kept from frame to frame while the moves and the queue are as they were, only the
    -- progress brought up to date: made anew every frame, 260 bullets cost up to 4.5 ms -
    -- the author's detailed bench 2026-10-29)
    clock = clock + 11
    G.frame = G.frame + 1
    function transfer:getJobDelta() return 0.8 end
    local kept = G.pendingList()
    check("moves: the same list the next frame", kept == list and G.inList(moving[7], kept))
    check("moves: ...its progress up to date", near(kept[1].progress, 1 - (300 - 10 * 0.8) / 300)
        and near(kept[30].progress, kept[1].progress), kept[1].progress)
    function transfer:getJobDelta() return 0.5 end
    check("moves: ...and once a frame (the game's tick moves it, not the drawing)", near(G.pendingList()[1].progress, kept[1].progress))
    G.frame = G.frame + 1
    check("moves: the next frame again up to date", near(G.pendingList()[1].progress, 1 - 295 / 300), G.pendingList()[1].progress)
    -- a move over (its record gone from the queue's look by its age): made anew
    G.pendingEpoch = G.pendingEpoch + 1
    local again = G.pendingList()
    check("moves: a new list in the same frame when a move starts or ends", again ~= list)
    check("moves: an item's entry kept from list to list", again[1] == list[1] and G.inList(moving[7], again))
    check("moves: an older list no longer counts", not G.inList(moving[7], list))
    G.pendingEpoch = G.pendingEpoch + 1
    local third = G.pendingList()
    check("moves: made anew again on the next start or end", third ~= again and G.inList(moving[7], third))
    table.insert(transfer.queueList, {items = {}})
    local fourth = G.pendingList()
    check("moves: a new list in the same frame when the queue changes", fourth ~= third)
    table.remove(transfer.queueList)
    local _, p1 = G.pendingOf(moving[30])
    check("moves: progress of the first entry only (half of one of thirty)", near(p1, 1 - 295 / 300), p1)
    -- the first thing is over (its entry gone) in the same millisecond: asked anew
    table.remove(transfer.queueList, 1)
    local _, p2 = G.pendingOf(moving[30])
    check("moves: an entry gone in the same ms is seen", near(p2, 1 - 285 / 300), p2)
    -- the clock goes on, the next half done
    clock = clock + 16
    local _, p3 = G.pendingOf(moving[2])
    check("moves: the same next frame", near(p3, 1 - 285 / 300), p3)
    -- two moves queued one after another: numbered 1 and 2
    local other = {action = {}}
    function other:getJobDelta() return 0 end
    local lone = from:add(item("Base.Hammer"))
    local rec2 = {steps = {{action = other, weight = 5}}, total = 5, player = naked, items = {lone}, t = getTimestampMs()}
    G.pending[lone] = rec2
    table.insert(ISTimedActionQueue.queues[naked].queue, other)
    clock = clock + 16
    check("moves: turns in queue order", G.orderOf(rec) == 1 and G.orderOf(rec2) == 2,
        tostring(G.orderOf(rec)) .. "," .. tostring(G.orderOf(rec2)))
    -- the queue emptied in the same millisecond: every move is over
    ISTimedActionQueue.queues[naked].queue = {}
    check("moves: over at once when the queue empties", G.pendingOf(moving[5]) == nil and G.pendingOf(lone) == nil)
    check("moves: none left", #G.pendingList() == 0, #G.pendingList())
    G.pending = {}
    ISTimedActionQueue = nil
end

-- what stacks: a type's kind looked at once (its class and tags), the rest each time -
-- (ten looks at Java a thing: 500 bullets, a build up to 9 ms - the author's bench 2026-10-28)
do
    local function food(ft)
        local it = item(ft, {class = "Food"})
        it.rotten = false
        function it:getOffAgeMax() return 1000000000 end
        function it:isCookable() return false end
        function it:isCooked() return false end
        function it:isBurnt() return false end
        function it:isRotten() return self.rotten end
        function it:getPoisonPower() return 0 end
        function it:isTainted() return false end
        function it:isFrozen() return false end
        function it:getHungChange() return 0 end
        function it:getBaseHunger() return 0 end
        return it
    end
    local S = G.isStackable
    check("stacks: bullets", S(item("Base.Bullets9mm")) and S(item("Base.Bullets9mm")))
    check("stacks: not a shirt, a gun, a bag",
        not S(item("Mod.KnoxShirt2", {class = "Clothing"})) and not S(item("Mod.KnoxGun2", {class = "HandWeapon"}))
        and not S(item("Mod.KnoxBag2", {capacity = 5})))
    local feather = food("Mod.KnoxFeather")
    check("stacks: a feather (asked for)", S(feather) and S(food("Mod.KnoxFeather")))
    feather.rotten = true
    check("stacks: ...not one that is not like the others, its type known", not S(feather) and S(food("Mod.KnoxFeather")))
    check("stacks: not food nobody asked for", not S(food("Mod.KnoxApple")) and not S(food("Mod.KnoxApple")))
    local full = item("Mod.KnoxCan", {fluid = {isEmpty = function() return false end}})
    check("stacks: not a thing with a fluid in it, a type known as plain", S(item("Mod.KnoxCan")) and not S(full))
    -- (whether a type wears down and holds rounds is the type's, asked once; the wear
    -- and the rounds stay each thing's own - the author's detailed bench 2026-10-29)
    local function pipe(cond)
        local it = item("Mod.KnoxPipe")
        function it:getConditionMax() return 10 end
        function it:getCondition() return cond end
        return it
    end
    check("stacks: a whole thing of a type that wears", S(pipe(10)))
    check("stacks: ...not a worn one, its type known", not S(pipe(4)) and S(pipe(10)))
    local K = G.stackKey
    local m1, m2, m3 = item("Mod.KnoxMag", {maxAmmo = 15, ammo = 3}), item("Mod.KnoxMag", {maxAmmo = 15, ammo = 15}),
        item("Mod.KnoxMag", {maxAmmo = 15, ammo = 3})
    check("stacks: magazines apart by their rounds, the type known", K(m1) ~= K(m2) and K(m1) == K(m3), K(m1) .. " / " .. K(m2))
    check("stacks: no rounds in the key of a type that holds none", not string.find(K(item("Base.Bullets9mm")), "|r", 1, true))
    F.overrides["Mod.KnoxCan"] = {stack = 1}
    check("stacks: the player's \"stack 1\" after it was known", not S(item("Mod.KnoxCan")))
    F.overrides["Mod.KnoxCan"] = nil
end

-- a bag's meter counts its cells by the grid's build, as KnoxGrid.usedCells does -----
-- (counted on their own four times a second, a bag of 500 bullets took up to 6 ms a
-- count - the author's bench 2026-10-28): stacks over their limit, what is hidden,
-- what is in a hand or on the hotbar, what is on its way
do
    local function same(name, L, c)
        local a, b = G.cellsOf(L), G.usedCells(c)
        check(name, a == b, tostring(a) .. " by the build, " .. tostring(b) .. " counted")
    end
    local bag = item("Base.Bag_Schoolbag", {capacity = 15})
    for _ = 1, 50 do bag.inv:add(item("Base.Nails")) end             -- 40 a tile: two tiles
    bag.inv:add(item("Base.9mmClip", {maxAmmo = 15, ammo = 15}))
    bag.inv:add(item("Base.9mmClip", {maxAmmo = 15, ammo = 15}))
    bag.inv:add(item("Base.9mmClip", {maxAmmo = 15, ammo = 0}))
    bag.inv:add(item("Base.BaseballBat"))
    bag.inv:add(item("Mod.Fists", {hidden = true}))
    local L = G.build(bag.inv, naked)
    same("cells: stacks, a bat, a hidden thing", L, bag.inv)
    check("cells: kept on the build", G.cellsOf(L) == L.used and L.used ~= nil)

    -- the player's own: a hammer in the hand, a knife on the hotbar in a bag on the back
    local p = player({})
    local hammer = p.inv:add(item("Base.Hammer"))
    function p:getPrimaryHandItem() return hammer end
    for _ = 1, 3 do p.inv:add(item("Base.Nails")) end
    local pack = p.inv:add(item("Base.Bag_Schoolbag", {capacity = 15}))
    local knife = pack.inv:add(item("Base.HuntingKnife"))
    function knife:getAttachedSlot() return 2 end
    pack.inv:add(item("Base.Pen"))
    local PL = G.build(p.inv, p)
    local inHand = false
    for _, e in ipairs(PL.placed) do if e.item == hammer then inHand = true end end
    check("cells: the hammer in the hand has no tile", not inHand)
    same("cells: what is in the hand counted all the same", PL, p.inv)
    local BL = G.build(pack.inv, p)
    check("cells: the knife on the hotbar has no tile", #BL.placed == 1, #BL.placed .. " tiles")
    same("cells: in a bag on the player, what is on the hotbar counted", BL, pack.inv)
    -- (a dead one's knife on its belt is loot: a tile, as before)
    local body = container("corpse", 30)
    local loot = body:add(item("Base.HuntingKnife"))
    function loot:getAttachedSlot() return 2 end
    local CL = G.build(body, p)
    check("cells: a dead one's things are loot", #CL.placed == 1 and CL.placed[1].item == loot, #CL.placed)
    same("cells: a dead one's things counted", CL, body)

    -- 25 of 60 nails on their way
    local from = item("Base.Bag_Schoolbag", {capacity = 15})
    local nails = {}
    for _ = 1, 60 do table.insert(nails, from.inv:add(item("Base.Nails"))) end
    local part = {}
    for i = 36, 60 do table.insert(part, nails[i]) end
    local action = {action = {}}
    function action:getJobDelta() return 0 end
    ISTimedActionQueue = {queues = {[naked] = {queue = {action}}}}
    local rec = {steps = {{action = action, weight = 1}}, total = 1, player = naked, items = part, t = getTimestampMs()}
    for _, it in ipairs(part) do G.pending[it] = rec end
    G.pendingEpoch = G.pendingEpoch + 1
    local ML = G.build(from.inv, naked)
    local shown = 0
    for _, e in ipairs(ML.placed) do shown = shown + #e.items end
    check("cells: what is on its way has no tile", shown == 35, shown)
    same("cells: what is on its way counted all the same", ML, from.inv)
    clock = clock + 16
    G.frame = G.frame + 1
    same("cells: and the next frame's build too", G.build(from.inv, naked), from.inv)
    G.pending = {}
    ISTimedActionQueue = nil
end

-- a car's things found at random places in a game with others too ("m" keys) --------
do
    local function trunk(mp)
        local car = {classes = {BaseVehicle = true}}
        function car:getSqlId() return 7 end
        function car:getMechanicalID() return 70 end
        local c = container("TruckBed", 4)
        function c:getParent() return car end
        c:add(item("Mod.KnoxTestShirt", {class = "Clothing"}))
        local keep = KnoxNet
        KnoxNet = mp and {mp = function() return true end, itemChanged = function() end} or nil
        local zr = ZombRand
        ZombRand = function(n) return n - 1 end   -- the last free spot: not where packing puts a thing
        local L = G.build(c, naked)
        ZombRand, KnoxNet = zr, keep
        return L
    end
    local sp, mp = trunk(false), trunk(true)
    check("scatter: a car alone (v key)", string.sub(sp.key, 1, 1) == "v" and (sp.placed[1].x ~= 0 or sp.placed[1].y ~= 0),
        sp.key .. " " .. sp.placed[1].x .. "," .. sp.placed[1].y)
    check("scatter: a car in a game with others (m key)", string.sub(mp.key, 1, 1) == "m" and (mp.placed[1].x ~= 0 or mp.placed[1].y ~= 0),
        mp.key .. " " .. mp.placed[1].x .. "," .. mp.placed[1].y)
end

-- the player's own sizes (knox_overrides.txt) ----------------------------------------
do
    check("overrides: a size line", F.parseOverride("Base.Katana = 5x1"))
    check("overrides: a grid line", F.parseOverride("Base.Bag_BigHikingBag=grid 8 x 10"))
    check("overrides: a stack line, a note after it", F.parseOverride("  Base.Screws = STACK 25   # more screws"))
    check("overrides: several on one line", F.parseOverride("Base.Bag_Schoolbag = grid 3x3 stack 1"))
    check("overrides: show ids", F.parseOverride("show_ids = yes") and F.showIds == true)
    check("overrides: a note is nothing", not F.parseOverride("# Base.Axe = 9x9"))
    check("overrides: nonsense is nothing", not F.parseOverride("Base.Axe = big"))
    check("overrides: out of range is nothing", not F.parseOverride("Base.Axe = 0x50"))
    check("overrides: no value is nothing", not F.parseOverride("Base.Axe ="))
    check("overrides: size, turned to short x long", fp(item("Base.Katana")) == "1x5", fp(item("Base.Katana")))
    local c, r = F.bagGrid(item("Base.Bag_BigHikingBag", {capacity = 22}), 22)
    check("overrides: a bag's own grid, whatever its capacity", c == 8 and r == 10, c .. "x" .. r)
    check("overrides: stack", F.stack(item("Base.Screws")) == 25, F.stack(item("Base.Screws")))
    c, r = F.bagGrid(item("Base.Bag_Schoolbag"), 15)
    check("overrides: a size set earlier in the run stays cached (read at load only)", c == 5 and r == 6, c .. "x" .. r)
    check("overrides: the rest unchanged", fp(item("Base.Pistol")) == "1x2", fp(item("Base.Pistol")))
end

-- rigs: bags with compartments (KnoxBagShapes) -----------------------------------
do
    local S = KnoxBagShapes
    -- (the overrides above gave these bags a grid of their own: one grid - not here)
    F.overrides["Base.Bag_Schoolbag"], F.overrides["Base.Bag_BigHikingBag"] = nil, nil
    -- the capacity of the first bag of each family (the game's scripts): its cells
    -- are two a unit, a couple more or fewer where the shape needed it
    local CAP = {
        alice = 28, survivor = 28, hikingBig = 22, hiking = 20, school = 15, schoolMedical = 12, hydration = 12,
        duffel = 18, tactical = 18, tools = 18, medical = 18, doctor = 8, sports = 18, golf = 18, gunBag = 18,
        rifleSoft = 7, satchel = 12, slingSheet = 10, slingTarp = 12, slingHide = 14, crude = 14,
        framepackSmall = 15, framepack = 20, framepackLarge = 25, framepackHuge = 35, chestRig = 5, beltRig = 6,
        briefcase = 8, toolbox = 8, tacklebox = 6, suitcase = 16, firstAid = 4,
    }
    local seen, families = {}, 0
    local CS = 64
    for _, f in ipairs(S.FAMILIES) do
        families = families + 1
        local rows = S.parse(f.spec)
        check("rigs " .. f.name .. ": its shape reads", rows ~= nil, f.spec)
        if rows then
            -- the author's rule: symmetric, left to right
            check("rigs " .. f.name .. ": symmetric", S.symmetric(rows), f.spec)
            local sh = S.compile(f.spec)
            check("rigs " .. f.name .. ": no taller than a bag's grid", sh.rows <= G.MAX_H, sh.rows)
            local g = S.geometry(sh, CS)
            -- fits the inventory column (8 cells wide)
            check("rigs " .. f.name .. ": fits the inventory column", g.w <= S.MAX_ROW_CELLS * CS, g.w)
            check("rigs " .. f.name .. ": the rows under it no wider than it", sh.ovCols * CS <= g.w, sh.ovCols)
            local want = CAP[f.name]
            check("rigs " .. f.name .. ": cells by its capacity", want and math.abs(sh.cells - want * 2) <= 2,
                sh.cells .. " for capacity " .. tostring(want))
            -- symmetric on screen too: each compartment's mirror lies mirrored
            local byPos = {}
            for p, o in pairs(g.parts) do byPos[p.row .. ":" .. p.i] = {p = p, o = o} end
            local mirrored = true
            for p, o in pairs(g.parts) do
                local n = #rows[p.row]
                local m = byPos[p.row .. ":" .. (n + 1 - p.i)]
                local right = g.w - (o.x + p.w * CS)
                if not m or math.abs(m.o.x - right) > 1 or m.o.y ~= o.y then mirrored = false end
            end
            check("rigs " .. f.name .. ": mirrored on screen", mirrored, f.spec)
            -- no two compartments overlap, on screen or in the grid
            local overlap = false
            for p, o in pairs(g.parts) do
                for q, oq in pairs(g.parts) do
                    if p ~= q and o.x < oq.x + q.w * CS and oq.x < o.x + p.w * CS and o.y < oq.y + q.h * CS and oq.y < o.y + p.h * CS then
                        overlap = true
                    end
                end
            end
            check("rigs " .. f.name .. ": compartments apart", not overlap, f.spec)
        end
        for _, t in ipairs(f.types) do
            check("rigs: " .. t .. " in one family only", not seen[t], seen[t])
            seen[t] = f.name
        end
    end
    check("rigs: the families", families >= 25, families)
    check("rigs: a bag with no family keeps one grid", S.forType("Base.Bag_Gunny") == nil and S.forType("Mod.Thing") == nil, "shaped")

    -- the school bag: a 4x5 main room, a 1x2 bottle pocket each side, a 3x2 front pocket
    local bag = item("Base.Bag_Schoolbag", {capacity = 15})
    local L = G.build(bag.inv, naked)
    local sh = L.shape
    check("rigs school: shaped", sh ~= nil and sh.family == "school", sh and sh.family)
    check("rigs school: size text", G.sizeText(L) == "4x5+10", G.sizeText(L))
    local main = sh.main
    check("rigs school: the main room first", main.w == 4 and main.h == 5, main.w .. "x" .. main.h)
    -- a block across two compartments, or on a cell between them, doesn't fit
    local side = sh.parts[1]                       -- the left bottle pocket (1x2)
    check("rigs school: inside a pocket fits", L:fits(side.lx, side.ly, 1, 2), "no")
    check("rigs school: across a pocket and the main room doesn't", not L:fits(side.lx, side.ly, 3, 1), "fits")
    check("rigs school: on the cells between doesn't", not L:fits(side.lx + 1, side.ly, 1, 1), "fits")
    check("rigs school: between is blocked", L:blocked(side.lx + 1, side.ly), "free")
    check("rigs school: too long for any part doesn't fit the main room", not L:fits(main.lx, main.ly, 1, 6), "fits")
    -- things go into the main room first, then the pockets
    local t1 = bag.inv:add(item("Base.TinnedBeans"))
    L = G.build(bag.inv, naked)
    local placed = L.placed[1]
    check("rigs school: a new thing goes into the main room", L:partAt(placed.x, placed.y) == main,
        placed.x .. "," .. placed.y)
    -- a thing bigger than the main room's free space but fitting a pocket goes there
    local L2 = G.emptyLike(L)
    check("rigs school: emptyLike keeps the compartments", L2.shape == sh, "lost")
    for y = main.ly, main.ly + main.h - 1 do
        for x = main.lx, main.lx + main.w - 1 do
            L2:occupy({item = {}, items = {}, w = 1, h = 1}, x, y, 0)
        end
    end
    local bottle = {item = {}, items = {}, w = 1, h = 2}
    local bx, by = L2:findFree(bottle)
    local bp = bx and L2:partAt(bx, by)
    -- (the next biggest: the 3x2 front pocket before the 1x2 side ones)
    check("rigs school: a bottle into a pocket when the main room is full", bp ~= nil and bp ~= main and bp.w == 3,
        tostring(bx) .. "," .. tostring(by))
    -- an old save: a place in a cell that is no cell of the bag any more - it moves in
    local t2 = bag.inv:add(item("Base.Book"))
    t2.md.knox = {k = G.containerKey(bag.inv, naked), x = side.lx + 1, y = side.ly, r = 0}
    L = G.build(bag.inv, naked)
    local moved = nil
    for _, e in ipairs(L.placed) do if e.item == t2 then moved = e end end
    check("rigs school: an old place between compartments moves into one", moved and L:partAt(moved.x, moved.y) ~= nil,
        moved and (moved.x .. "," .. moved.y))
    check("rigs school: the moved place is saved", t2.md.knox and L:partAt(t2.md.knox.x, t2.md.knox.y) ~= nil, "not saved")
    -- too much: what doesn't fit lies under it, no wider than its widest row of cells
    local heap = item("Base.Bag_Schoolbag", {capacity = 15})
    for _ = 1, 40 do heap.inv:add(item("Base.Book")) end
    local LH = G.build(heap.inv, naked)
    local widest = 0
    for _, e in ipairs(LH.overflow) do
        local w = G.dims(e, e.r)
        widest = math.max(widest, e.x + w)
    end
    check("rigs school: things that don't fit lie under it", #LH.overflow > 0 and LH.rows > LH.baseRows, #LH.overflow)
    check("rigs school: no wider than its rows of cells", widest <= LH.shape.ovCols, widest)
    -- a drop in the rows under it: as wide as they are drawn, not as the grid's columns
    local ovY = LH.rows - 1
    local function freeRowEnd()
        for x = LH.shape.ovCols - 1, 0, -1 do
            if not LH:cellAt(x, ovY) then return x end
        end
    end
    local fx = freeRowEnd()
    check("rigs school: under it, a free cell of the rows takes a thing", fx == nil or LH:fits(fx, ovY, 1, 1), fx)
    check("rigs school: under it, past the rows' width doesn't", LH.cols <= LH.shape.ovCols
        or not LH:fits(LH.shape.ovCols, ovY, 1, 1), LH.shape.ovCols .. " of " .. LH.cols)
    -- screen positions: a cell, a gap, the rows under it
    local g = S.geometry(sh, CS)
    local px, py = S.cellPx(sh, CS, main.lx, main.ly, sh.rows)
    check("rigs school: a cell of the main room on screen", px == g.parts[main].x and py == g.parts[main].y, px)
    check("rigs school: no pixel for a cell between", S.cellPx(sh, CS, side.lx + 1, side.ly, sh.rows) == nil, "pixel")
    local ox, oy = S.cellPx(sh, CS, 2, sh.rows, sh.rows)
    check("rigs school: the first row under it", ox == g.ovX + 2 * CS and oy == g.h + g.gap and g.ovY == oy, ox .. "," .. oy)
    -- the rows under it centred under the compartments (symmetric, as they are)
    check("rigs school: the rows under it centred", math.abs((g.w - g.ovX - g.ovW) - g.ovX) <= 1,
        g.ovX .. " | " .. (g.w - g.ovX - g.ovW))
    -- every family at the cell sizes the game uses: centred too
    for _, f in ipairs(S.FAMILIES) do
        local shf = S.compile(f.spec)
        for _, cs in ipairs({32, 41, 54, 64}) do
            local gf = S.geometry(shf, cs)
            check("rigs " .. f.name .. " " .. cs .. ": rows under it centred",
                gf.ovX >= 0 and math.abs((gf.w - gf.ovX - gf.ovW) - gf.ovX) <= 1, gf.ovX)
        end
    end
end

-- the player's own compartments, and their own grid (knox_overrides.txt) ----------
do
    check("rigs overrides: a parts line", F.parseOverride("Mod.Pack = parts 2x2 / 1x2 4x3 1x2"))
    check("rigs overrides: a grid line", F.parseOverride("Base.Bag_ALICEpack = grid 7x8"))
    check("rigs overrides: nonsense parts are nothing", not F.parseOverride("Mod.Bad = parts big"))
    local modBag = item("Mod.Pack", {capacity = 12})
    local L = G.build(modBag.inv, naked)
    check("rigs overrides: a mod's bag gets them", L.shape ~= nil and L.shape.cells == 4 + 2 + 12 + 2, L.shape and L.shape.cells)
    local alice = item("Base.Bag_ALICEpack", {capacity = 28})
    local LA = G.build(alice.inv, naked)
    check("rigs overrides: a grid of their own means one grid", LA.shape == nil and LA.cols == 7 and LA.rows == 8,
        LA.cols .. "x" .. LA.rows)
    F.overrides["Base.Bag_ALICEpack"] = nil
    F.overrides["Mod.Pack"] = nil
end

-- the counter's detailed mode inside a build (the grids' long builds, 2026-10-29):
-- its parts are counted, and the grid comes out the same as with it off --------
do
    local function shape(L)
        local out = {}
        for _, e in ipairs(L.placed) do
            table.insert(out, e.x .. "," .. e.y .. "," .. (e.r or 0) .. ":" .. #e.items .. (e.ghost and "g" or ""))
        end
        table.sort(out)
        return table.concat(out, " ") .. " | " .. #L.overflow .. " | " .. G.cellsOf(L)
    end
    local function scene()
        local outer = item("Base.Bag_DuffelBag", {capacity = 18})
        local inner = outer.inv:add(item("Base.Bag_Schoolbag", {capacity = 15}))
        local bullets = {}
        for _ = 1, 250 do table.insert(bullets, inner.inv:add(item("Base.Bullets9mm"))) end
        for _ = 1, 4 do outer.inv:add(item("Base.Hammer")) end
        -- ten bullets on their way out of the inner bag
        local transfer = {action = {}, queueList = {}}
        function transfer:getJobDelta() return 0.25 end
        local moving, steps = {}, {}
        for i = 1, 10 do
            table.insert(moving, bullets[i])
            table.insert(transfer.queueList, {items = {bullets[i]}})
            table.insert(steps, {action = transfer, weight = 1, item = bullets[i]})
        end
        ISTimedActionQueue = {queues = {[naked] = {queue = {transfer}}}}
        G.pending = {}
        local rec = {source = {kind = "grid", key = G.containerKey(inner.inv, naked), x = 0, y = 0, r = 0},
                     steps = steps, total = 10, player = naked, items = moving, t = getTimestampMs()}
        for _, it in ipairs(moving) do G.pending[it] = rec end
        G.pendingEpoch = G.pendingEpoch + 1
        G.frame = G.frame + 1
        return outer, inner
    end
    local o1, i1 = scene()
    local offOuter, offInner = shape(G.build(o1.inv, naked)), shape(G.build(i1.inv, naked))
    local offNest = G.nestRefusal(item("Base.Nails"), i1.inv, naked)
    local recs = {}
    KnoxPerf = {detail = true, now = function() return 0 end}
    function KnoxPerf.addPart(name, us, n)
        local r = recs[name] or {calls = 0, n = 0}
        recs[name] = r
        r.calls = r.calls + 1
        r.n = r.n + (n or 0)
    end
    function KnoxPerf.part(name, t0, n)
        KnoxPerf.addPart(name, 0, n)
        return 0
    end
    local o2, i2 = scene()
    local onOuter, onInner = shape(G.build(o2.inv, naked)), shape(G.build(i2.inv, naked))
    local onNest = G.nestRefusal(item("Base.Nails"), i2.inv, naked)
    KnoxPerf = nil
    check("detail: the bag's grid the same", onInner == offInner, offInner .. " / " .. onInner)
    check("detail: the outer grid the same", onOuter == offOuter, offOuter .. " / " .. onOuter)
    check("detail: bag in a bag the same", onNest == offNest, tostring(offNest) .. " / " .. tostring(onNest))
    local function has(name, calls, n)
        local r = recs[name]
        check("detail: part " .. name, r ~= nil and (calls == nil or r.calls == calls) and (n == nil or r.n == n),
            r and (r.calls .. " calls, n=" .. r.n) or "missing")
    end
    has("part: grid build 0 size, shape")
    has("part: grid build 1 moves")
    has("part: grid build 2 things")
    has("part: grid build 2a worn / in hand")
    has("part: grid build 2b stacks")
    has("part: grid build 2c sizes")
    has("part: grid build 3 saved places")
    has("part: grid build 4 found in the world")
    has("part: grid build 5 new places")
    has("part: grid build 6 not fitting")
    has("part: bag growth, counted anew", nil, 250)
    has("part: bag in a bag, checked")
    has("part: moves list, made", 1, 10)
    has("part: moves list, kept")
    has("part: moves list, progress of moves", 1)
    has("part: moves list, queue looked over", nil, 10)
    G.pending = {}
    ISTimedActionQueue = nil
end

-- a bag's cells from its own grid on the screen, the tile around it a frame later
-- (500 bullets moved: their bag counted anew up to 4.4 ms ~7 times a second, the
-- author's bench 2026-10-29; the author: "давай попробуем") -------------------------
do
    local outer = item("Base.Bag_DuffelBag", {capacity = 18})
    local inner = outer.inv:add(item("Base.Bag_Schoolbag", {capacity = 15}))
    inner.inv:add(item("Base.Hammer"))
    local function tileOf(L)
        for _, e in ipairs(L.placed) do
            if e.item == inner then return e.w .. "x" .. e.h end
        end
        return "none"
    end
    local view = {prerenderMs = clock}
    local function innerBuilt()
        view.layout = G.build(inner.inv, naked, false, true)
        view.prerenderMs = clock
        G.liveGrids[inner.inv] = view
    end
    innerBuilt()
    check("bag's grid: its count is the counted one", G.cellsOf(view.layout) == G.usedCells(inner.inv),
        G.cellsOf(view.layout) .. " / " .. G.usedCells(inner.inv))
    local old = tileOf(G.build(outer.inv, naked, false, true))
    -- the bag filled; its grid not built again yet
    for _ = 1, 8 do inner.inv:add(item("Base.Hammer")) end
    local exact = tileOf(G.build(outer.inv, naked))
    check("bag's grid: (the bag grows when filled - the case is real)", exact ~= old, old .. " / " .. exact)
    -- (`exact` was asked of a build that doesn't wait: the bag's size is known now; a new
    -- one for the waiting builds)
    local inner2 = outer.inv:add(item("Base.Bag_Schoolbag", {capacity = 15}))
    inner2.inv:add(item("Base.Hammer"))
    inner = inner2
    innerBuilt()
    old = tileOf(G.build(outer.inv, naked, false, true))
    for _ = 1, 8 do inner.inv:add(item("Base.Hammer")) end
    local L1 = G.build(outer.inv, naked, false, true)
    check("bag's grid: a grid on the screen waits a frame - the tile as it was", tileOf(L1) == old and L1.bagWait == true,
        tileOf(L1) .. " " .. tostring(L1.bagWait))
    G.frame = G.frame + 1
    innerBuilt()
    local L2 = G.build(outer.inv, naked, false, true)
    check("bag's grid: the next frame, from the bag's grid - grown", tileOf(L2) == exact and not L2.bagWait,
        tileOf(L2) .. " " .. tostring(L2.bagWait))
    -- its grid not built again: three frames of waiting, then counted
    for _ = 1, 8 do inner.inv:add(item("Base.Hammer")) end
    local waited = 0
    for _ = 1, 5 do
        G.frame = G.frame + 1
        if G.build(outer.inv, naked, false, true).bagWait then waited = waited + 1 end
    end
    check("bag's grid: no more than three frames of waiting", waited == 3, waited)
    -- the bag's grid gone from the screen: counted at once
    for _ = 1, 8 do inner.inv:add(item("Base.Hammer")) end
    view.prerenderMs = clock - 1000
    G.frame = G.frame + 1
    check("bag's grid: not on the screen - no waiting", not G.build(outer.inv, naked, false, true).bagWait)
    G.liveGrids[inner.inv] = nil
end

print("pass " .. pass .. ", fail " .. fail)
