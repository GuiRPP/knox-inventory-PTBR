-- Sort (KnoxOrder.sort) in a bag with compartments (KnoxBagShapes), outside the game
-- (tools/order/test.ps1): after every rule each thing lies whole inside one
-- compartment, nothing that had room is left out, and the result is stable.

local G, O, S = KnoxGrid, KnoxOrder, KnoxBagShapes
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else
        fail = fail + 1
        print("FAIL " .. name .. " : " .. tostring(detail))
    end
end

local clock = 1000
function getTimestampMs() clock = clock + 1 return clock end
function getText(key) return key end
function instanceof(obj, class) return type(obj) == "table" and obj.classes ~= nil and obj.classes[class] == true end

local function list(t)
    local l = {t = t}
    function l:size() return #self.t end
    function l:get(i) return self.t[i + 1] end
    return l
end

local nextId = 1
local function container(capacity)
    local c = {items = {}, capacity = capacity}
    function c:getItems() return list(self.items) end
    function c:getContainingItem() return self.holder end
    function c:getType() return "bag" end
    function c:getParent() return nil end
    function c:getCapacity() return self.capacity end
    function c:add(it) table.insert(self.items, it); it.container = self; return it end
    return c
end

-- a thing with a size of its own (KnoxFootprint's answer is fixed for the test)
local function thing(ft, w, h, cat, stack)
    local it = {ft = ft, md = {}, o = {cat = cat}, classes = {InventoryItem = true}, id = nextId, w = w, h = h, stack = stack}
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
    function it:getAttachedSlot() return -1 end
    function it:getID() return self.id end
    function it:getDisplayName() return self.ft end
    function it:getActualWeight() return 0.5 end
    function it:getUnequippedWeight() return self:getActualWeight() end
    function it:getTex() return nil end
    return it
end
-- the sizes: what KnoxFootprint gives each test type
local SIZES = {}
local realGet, realStack = KnoxFootprint.get, KnoxFootprint.stack
KnoxFootprint.get = function(item) local s = SIZES[item.ft]; if s then return s[1], s[2] end return realGet(item) end
KnoxFootprint.stack = function(item) local s = SIZES[item.ft]; if s then return s[3] or 1 end return realStack(item) end
KnoxFootprint.isSmoke = function() return false end
G.isStackable = function(item) local s = SIZES[item.ft]; return s ~= nil and (s[3] or 1) > 1 end

local function bagOf(ft, cap)
    local bag = thing(ft, 2, 2, "clo")
    bag.classes.InventoryContainer = true
    bag.inv = container(cap)
    bag.inv.holder = bag
    function bag:getInventory() return self.inv end
    return bag
end

local naked = {inv = container(50)}
function naked:getInventory() return self.inv end
function naked:getWornItems() return list({}) end
function naked:getPrimaryHandItem() return nil end
function naked:getSecondaryHandItem() return nil end
function naked:isEquipped() return false end

--- Every thing of the layout whole inside one compartment (or in the rows under it).
local function allInside(L)
    for _, e in ipairs(L.placed) do
        local w, h = G.dims(e, e.r)
        if e.y < L.baseRows then
            local p = L:partAt(e.x, e.y)
            if not p or p ~= L:partAt(e.x + w - 1, e.y + h - 1) then return false, e.item.ft .. " at " .. e.x .. "," .. e.y end
        end
    end
    return true
end

SIZES["T.Bat"] = {1, 4}
SIZES["T.Bottle"] = {1, 2}
SIZES["T.Book"] = {2, 2}
SIZES["T.Can"] = {1, 1, 10}
SIZES["T.Pills"] = {1, 1, 5}
SIZES["T.Rifle"] = {1, 6}

for _, family in ipairs({"Bag_Schoolbag", "Bag_ALICEpack", "Bag_BigHikingBag", "Bag_ChestRig", "Bag_DuffelBag", "Toolbox"}) do
    local ft = "Base." .. family
    local shape = S.forType(ft)
    for _, rule in ipairs(O.RULES) do
        KnoxTheme.settings["order.rule"] = rule
        local bag = bagOf(ft, 15)
        local inv = bag.inv
        -- a mix that fills it about half
        local fill = math.floor(shape.cells * 0.5)
        local adds = {"T.Book", "T.Bottle", "T.Can", "T.Can", "T.Pills", "T.Bat", "T.Can", "T.Bottle"}
        local used, i = 0, 0
        while used < fill do
            i = i + 1
            local ft2 = adds[(i - 1) % #adds + 1]
            local s = SIZES[ft2]
            inv:add(thing(ft2, s[1], s[2], ft2 == "T.Book" and "info" or (ft2 == "T.Bat" and "wpn" or "food")))
            used = used + s[1] * s[2]
        end
        local L = G.build(inv, naked)
        local over0 = #L.overflow
        local ok0, why0 = allInside(L)
        check(family .. " " .. rule .. ": built inside the compartments", ok0, why0)
        O.sort({layout = L, container = inv, markDirty = function() end}, rule)
        local L2 = G.build(inv, naked)
        local ok, why = allInside(L2)
        check(family .. " " .. rule .. ": sorted inside the compartments", ok, why)
        check(family .. " " .. rule .. ": nothing more left out", #L2.overflow <= over0, #L2.overflow .. " > " .. over0)
        -- stable: sorting twice changes nothing
        O.sort({layout = L2, container = inv, markDirty = function() end}, rule)
        local L3 = G.build(inv, naked)
        local same = true
        for _, e in ipairs(L2.placed) do
            for _, e3 in ipairs(L3.placed) do
                if e3.item == e.item and (e3.x ~= e.x or e3.y ~= e.y) then same = false end
            end
        end
        check(family .. " " .. rule .. ": a second sort keeps it", same, "moved")
    end
end

-- a thing too long for any compartment of the chest rig: it lies under it, not across
do
    local rig = bagOf("Base.Bag_ChestRig", 5)
    rig.inv:add(thing("T.Rifle", 1, 6, "wpn"))
    local L = G.build(rig.inv, naked)
    check("chest rig: a rifle doesn't go in", #L.overflow == 1, #L.overflow)
    check("chest rig: it lies in the rows under it", L.overflow[1] and L.overflow[1].y >= L.baseRows, "inside")
end

print(string.format("DONE pass=%d fail=%d", pass, fail))
