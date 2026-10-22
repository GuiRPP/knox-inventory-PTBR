-- Stand-ins for the game and the rest of Knox, enough to run KnoxSearch.lua
-- outside the game (tools/search/test.ps1). Containers know whether their mark
-- can be kept (`markable`) and whether they were looked into (`seen`).

require = function() end
clock = 1000
paused = false
function getTimestampMs() return clock end
function isGamePaused() return paused end
function instanceof(obj, class)
    return type(obj) == "table" and obj.classes ~= nil and obj.classes[class] == true
end

local handlers, ticks = {}, {}
Events = {
    OnNewGame = {Add = function(f) handlers.newGame = f end},
    OnTick = {Add = function(f) ticks[f] = true end, Remove = function(f) ticks[f] = nil end},
}
function fireNewGame(player) handlers.newGame(player) end
function fireTicks(n)
    for _ = 1, n do
        local now = {}
        for f in pairs(ticks) do table.insert(now, f) end
        for _, f in ipairs(now) do f() end
    end
end

-- the character's emitter: what it played, what still plays (KnoxSearchSound)
emitted, playing, volumes = {}, {}, {}
local nextSound = 1
local emitter = {}
function emitter:playSound(name)
    local id = nextSound
    nextSound = nextSound + 1
    table.insert(emitted, name)
    playing[id] = name
    return id
end
function emitter:setVolume(id, v) volumes[id] = v end
function emitter:stopSound(id) playing[id] = nil end
function emitter:isPlaying(id) return playing[id] ~= nil end
local player = {getEmitter = function() return emitter end}
function getPlayer() return player end
function playingNamed(name)
    for _, n in pairs(playing) do if n == name then return true end end
    return false
end

searchOn = true
searchSound = 100
uiSound = 100
KnoxTheme = {
    switch = function(id) return id == "search" and searchOn end,
    look = function(id)
        if id == "search.sound" then return searchSound end
        if id == "ui.sound" then return uiSound end
        return 100
    end,
    color = {accent = {r = 1, g = 1, b = 1}, header = {r = 0, g = 0, b = 0}},
    rect = function() end,
    tileFrame = function() end,
}

KnoxLootPanel = {}
function KnoxLootPanel.canMark(c) return c.markable == true end
function KnoxLootPanel.isSeen(c) return c.seen == true end
function KnoxLootPanel.markSeen(c) if c.markable then c.seen = true end end

KnoxGrid = {dims = function(e, r) return e.w, e.h end}
KnoxGridView = {settle = {}, hit = function(it, q) return it.name:find(q, 1, true) ~= nil end}
KnoxContainerWindow = {list = {}, active = nil}
KnoxScreen = {instance = {inventory = {sections = {}}}}

local function list(t)
    local l = {t = t}
    function l:size() return #self.t end
    function l:get(i) return self.t[i + 1] end
    return l
end

function newContainer(name, markable)
    local c = {name = name, items = {}, markable = markable ~= false}
    function c:getItems() return list(self.items) end
    function c:getParent() return nil end
    function c:getPutSound() return self.put end
    function c:getOpenSound() return self.open end
    function c:getCloseSound() return self.close end
    return c
end

function newItem(name, c, w, h)
    local it = {name = name, classes = {}, w = w or 1, h = h or 1}
    function it:getContainer() return self.container end
    function it:hasModData() return self.md ~= nil end
    function it:getModData() self.md = self.md or {}; return self.md end
    function it:getDisplayName() return self.name end
    -- (what KnoxSearchSound asks: `o` of newItem's caller sets them)
    function it:getFullType() return self.ft or ("Base." .. self.name) end
    function it:getPlaceOneSound() return self.placeOne end
    function it:getDropSound() return self.drop end
    function it:getDisplayCategory() return self.cat end
    function it:getFabricType() return self.fabric end
    function it:getFillFromTapSound() return self.tap end
    function it:isPackaged() return self.packaged == true end
    function it:getActualWeight() return self.weight or 0.1 end
    function it:getUnequippedWeight() return self:getActualWeight() end
    function it:getFoodType() return self.foodType end
    -- its script, what KnoxMaterial reads (tags: a list of names; the kind from the classes)
    function it:getScriptItem()
        local me = self
        local sc = {}
        function sc:getItemType()
            if me.itype then return me.itype end
            for _, k in ipairs({"Food", "Clothing", "Literature", "Key", "InventoryContainer"}) do
                if me.classes[k] then return "base:" .. (k == "InventoryContainer" and "container" or string.lower(k)) end
            end
            return "base:normal"
        end
        function sc:getDisplayCategory() return me.cat end
        function sc:getActualWeight() return me.weight or 0.1 end
        function sc:getFabricType() return me.fabric end
        function sc:getWorldStaticModel() return me.model end
        function sc:getStaticModel() return nil end
        function sc:getDropSound() return me.drop end
        function sc:getPlaceOneSound() return me.placeOne end
        function sc:getFillFromTapSound() return me.tap end
        function sc:getBodyLocation() return nil end
        function sc:getEatType() return nil end
        function sc:getTags()
            local list = me.tags or {}
            return {iterator = function()
                local i = 0
                return {hasNext = function() return i < #list end, next = function() i = i + 1; return "base:" .. list[i] end}
            end}
        end
        return sc
    end
    if c then moveItem(it, c) end
    return it
end

function newBag(name, c)
    local bag = newItem(name, c, 2, 2)
    bag.classes.InventoryContainer = true
    bag.inv = newContainer(name .. " inside")
    function bag:getInventory() return self.inv end
    return bag
end

function moveItem(it, to)
    local from = it.container
    if from then
        for i, x in ipairs(from.items) do
            if x == it then table.remove(from.items, i) break end
        end
    end
    it.container = to
    if to then table.insert(to.items, it) end
end

--- The grid of a container: one tile per item, laid out in a row.
function layoutOf(c)
    local L = {container = c, placed = {}}
    for i, it in ipairs(c.items) do
        table.insert(L.placed, {item = it, items = {it}, x = i - 1, y = 0, w = it.w, h = it.h, r = 0})
    end
    return L
end
