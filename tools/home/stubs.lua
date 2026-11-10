-- What KnoxGrid.lua and KnoxHome.lua touch outside the game (tools/home/test.ps1):
-- the theme's switches and modules, the events, the action queue, Knox's moves.
require = function() end
KnoxTheme = {
    settings = {},
    switches = {home = true, scatter = false},
    category = {wpn = 1, ammo = 1, med = 1, food = 1, tool = 1, mat = 1, clo = 1, info = 1, misc = 1},
    choice = function(key) return KnoxTheme.settings[key] end,
    categoryOf = function(item) return item.o and item.o.cat or "misc" end,
    saveSettings = function() end,
    animOn = function() return true end,
}
function KnoxTheme.switch(key) return KnoxTheme.switches[key] == true end
function KnoxTheme.on(name) return name == "inventory" end
function KnoxTheme.offInGame() end
KnoxActions = {isLocked = function() return false end, allViews = function() return {} end}
function getSoundManager() return {playUISound = function() end} end
function isClient() return false end

-- the events: what is added kept by name, so the test can call it
TEST_EVENTS = {}
local function event(name)
    return {
        Add = function(fn) TEST_EVENTS[name] = TEST_EVENTS[name] or {}; TEST_EVENTS[name][fn] = true end,
        Remove = function(fn) if TEST_EVENTS[name] then TEST_EVENTS[name][fn] = nil end end,
    }
end
Events = {OnTick = event("OnTick"), OnEquipPrimary = event("OnEquipPrimary"), OnEquipSecondary = event("OnEquipSecondary"),
          OnClothingUpdated = event("OnClothingUpdated"), OnGameStart = event("OnGameStart")}

ISTimedActionQueue = {queues = {}}
ISBaseTimedAction = {perform = function() end, stop = function() end}

TEST_CLOCK = 1000
function getTimestampMs() return TEST_CLOCK end
function getText(key) return key end
function instanceof(obj, class)
    if type(obj) ~= "table" then return false end
    if class == "IsoPlayer" then return obj.isPlayer == true end
    return obj.classes ~= nil and obj.classes[class] == true
end
