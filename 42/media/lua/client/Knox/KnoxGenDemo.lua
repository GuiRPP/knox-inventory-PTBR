-- A generator for the generator window to work where there is none: the news post's live
-- window (the author, 2026-10-22: "as interactive as the dashboard of Behind the wheel").
-- KnoxGeneratorWindow runs on it as on a real one - the same drawing, the same clicks,
-- the same rules (KnoxGenerator.apply: the worn one fails as often as in a game) - while
-- what the game would do is done here, to this pretend generator:
--   gen   what the window asks an IsoGenerator (fuel, condition, running, the house,
--         the things it powers - a fridge, four lamps, a stove, at the game's rates)
--   chr   the character: its sounds (the menu's own: no world to sound in), its
--         electrics, a can of gasoline in its pocket
-- Time runs fast here: 6 game minutes a second, so the hour meter's tenths turn as one
-- watches. Run dry, the engine stops and a moment later the tank is filled; an empty can
-- is filled again too. Nothing of the player's own is touched.

KnoxGenDemo = KnoxGenDemo or {}
local Demo = KnoxGenDemo
Demo.__index = Demo

local RATE = 0.1              -- the game's default fuel rate: the scale 0 .. 0.1 L/h as in a game
local HOURS_A_SEC = 0.1       -- 6 game minutes a real second
local FUEL, CAN = 6.2, 5      -- the tank as it starts and is filled again; the can's litres
local REFILL_MS = 3000
-- what it powers, at the game's own rates (IsoGenerator: a fridge 0.08, a light 0.002,
-- a stove 0.09; the generator itself 0.02)
local BASE = 0.02
local THINGS = {{"DemoFridge", 0.08, 1}, {"Lights", 0.002, 4}, {"DemoStove", 0.09, 1}}

local function litres(v)
    local s = string.format("%.4f", v)
    return (string.gsub(string.gsub(s, "0+$", ""), "%.$", ""))
end

local function sound(name)
    local ok, id = pcall(function() return getSoundManager():playUISound(name) end)
    return ok and id or nil
end

--- A pretend generator: `worn` - at 30 % (the OIL lamp, a start fails half the time).
function Demo.new(worn)
    local o = setmetatable({}, Demo)
    o.g = {fuel = FUEL, cond = worn and 30 or 82, on = false, conn = true}
    o.lastMs = getTimestampMs()
    o.rate = RATE
    o:makeGenerator()
    o:makeCharacter()
    return o
end

function Demo:use()
    local raw = BASE
    for _, t in ipairs(THINGS) do raw = raw + t[2] * t[3] end
    return raw * RATE
end

function Demo:makeGenerator()
    local g, md = self.g, {}
    local list = {}
    for _, t in ipairs(THINGS) do
        local name = t[1] == "Lights" and getText("IGUI_Lights") or getText("IGUI_KnoxGen_" .. t[1])
        if t[3] > 1 then name = name .. " x" .. t[3] end
        table.insert(list, name .. " (" .. litres(t[2] * t[3] * RATE) .. " L/h)")
    end
    -- (the plugs shown before it is started, as after a run: the window keeps them so)
    md.knoxPowered = table.concat(list, "\n")
    md.knoxLoad = self:use()
    local use = self:use()
    local items = {size = function() return #list end, get = function(_, i) return list[i + 1] end}
    local sq = {getX = function() return 0 end, getY = function() return 0 end, getZ = function() return 0 end,
        isOutside = function() return true end, getBuilding = function() return nil end}
    self.gen = {
        getMaxFuel = function() return 10 end,
        getFuel = function() return g.fuel end,
        setFuel = function(_, v) g.fuel = math.max(0, math.min(10, v)) end,
        isActivated = function() return g.on end,
        setActivated = function(_, v)
            if v ~= g.on then sound(v and "GeneratorStarting" or "GeneratorStopping") end
            g.on = v
        end,
        failToStart = function() sound("GeneratorFailedToStart") end,
        sync = function() end,
        getCondition = function() return g.cond end,
        isConnected = function() return g.conn end,
        setConnected = function(_, v) g.conn = v end,
        getTotalPowerUsing = function() return use end,
        getItemsPowered = function() return items end,
        getModData = function() return md end,
        transmitModData = function() end,
        getObjectIndex = function() return 0 end,
        getSquare = function() return sq end,
        getX = function() return 0 end,
        getY = function() return 0 end,
    }
end

function Demo:makeCharacter()
    local can = {amount = CAN}
    local fc = {contains = function() return true end, getAmount = function() return can.amount end,
        adjustAmount = function(_, v) can.amount = math.max(0, v) end}
    can.getFluidContainer = function() return fc end
    can.getID = function() return 1 end
    can.syncItemFields = function() end
    can.getStaticModel = function() return nil end
    self.can = can
    local list = {size = function() return 1 end, get = function() return can end}
    local inv = {
        getAllEvalRecurse = function() return list end,
        getItemWithIDRecursiv = function() return can end,
        containsRecursive = function(_, it) return it == can end,
    }
    self.chr = {
        playSound = function(_, name) return sound(name) end,
        stopOrTriggerSound = function(_, id) if id then pcall(function() getSoundManager():stopUISound(id) end) end end,
        getInventory = function() return inv end,
        getPerkLevel = function() return 3 end,
        isRecipeActuallyKnown = function() return true end,
        getPrimaryHandItem = function() return nil end,
        getSecondaryHandItem = function() return nil end,
        getPlayerNum = function() return 0 end,
    }
end

--- Each frame: the fuel goes while it runs; dry, it stops and is filled a moment later;
--- an empty can fills again.
function Demo:tick(now)
    local dt = math.max(0, math.min(0.1, (now - self.lastMs) / 1000))
    self.lastMs = now
    local g = self.g
    if g.on then
        g.fuel = math.max(0, g.fuel - self:use() * HOURS_A_SEC * dt)
        if g.fuel <= 0 then
            self.gen:setActivated(false)
            self.dryAt = now
        end
    end
    if self.dryAt and now - self.dryAt > REFILL_MS then
        g.fuel, self.dryAt = FUEL, nil
    end
    if self.can.amount <= 0 then
        self.canAt = self.canAt or now
        if now - self.canAt > REFILL_MS then self.can.amount, self.canAt = CAN, nil end
    end
end

return KnoxGenDemo
