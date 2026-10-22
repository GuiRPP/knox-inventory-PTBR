-- A car for the dashboard to drive where there is none: the news post's live panel
-- (the author, 2026-10-21: "players should see and feel how it works", the mockup's
-- way). KnoxDashboard runs on it as on a real car - the same drawing, the same
-- clicks - while what the game would do (the engine, the locks, the heater's command,
-- the car's radio) is done here, to this pretend car and its pretend set:
--   car     what the panel asks a BaseVehicle (the methods KnoxDashboard:read calls)
--   mm, r   what it asks KnoxMenuMusic and KnoxCarRadio (stations, the tape, volume)
--   chr     the driver: the key's sounds, the key in the pocket
-- Nothing of the player's own (their music, the camp's radio, a real car) is touched.
-- What a real car gets from the road, here from the mouse (the author, 2026-10-21:
-- "everything the game's dashboard does"): the wheel over the speedometer or the
-- tachometer is the gas; a click on the cruise window sets the cruise at this speed,
-- the wheel over it raises or lowers it, the gas down lets it go; a click on the
-- speedometer while driving is a bump (the panel flickers and shakes); the tank
-- empties while it runs - empty, the engine dies and a moment later it is filled.

require "Knox/KnoxTheme"

KnoxDashDemo = KnoxDashDemo or {}
local Demo = KnoxDashDemo
Demo.__index = Demo

local START_MS = 900            -- the starter turning before it catches
local FULL = 0.62               -- the tank as it starts, and as it is filled again
local REFILL_MS = 2500          -- an empty tank filled again after
local CRUISE_MIN = 20
local IDLE_RPM = 800
local TOP_KMH = 110
-- the gears by speed: {up to km/h, its letter, from km/h}
local GEARS = {{1, "N", 0}, {20, "1", 0}, {38, "2", 14}, {58, "3", 30}, {82, "4", 48}, {200, "5", 66}}
-- the presets of the set (a car's radio comes tuned to the public stations)
local STATIONS = {
    {freq = 89400, name = "Knox Country"}, {freq = 91200, name = "WBLA"}, {freq = 93200, name = "LBMW - Kentucky Radio"},
    {freq = 98000, name = "NNR Radio"}, {freq = 99600, name = "Knox County Radio"}, {freq = 101200, name = "KnoxTalk Radio"}}
local TRACKS = 8

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function mhz(f)
    local v = math.floor(f / 100 + 0.5) / 10
    if v == math.floor(v) then return tostring(math.floor(v)) .. ".0" end
    return tostring(v)
end

--- A pretend car: `kind` "sedan" or "pickup"; `hot` - hot-wired, no key.
function Demo.new(kind, hot)
    local o = setmetatable({}, Demo)
    o.kind = kind == "pickup" and "pickup" or "sedan"
    o.hot = hot == true
    o.keyIn = not o.hot
    o.running, o.startAt = false, nil
    o.kmh, o.target, o.rpm = 0, 0, 0
    o.lights, o.doors, o.trunkLocked = false, nil, false
    o.fuel = FULL
    o.cruise, o.cruiseKmh = false, 0
    o.heat = {active = false, temperature = 0}
    -- an evening: the scales hardly seen until the headlights light them
    o.dark = 0.7
    o.lastMs = getTimestampMs()
    o:makeCar()
    o:makeRadio()
    o:makeDriver()
    return o
end

--- Each frame before the panel reads the car: the starter, the speed easing to the gas.
function Demo:tick(now)
    local dt = clamp((now - self.lastMs) / 1000, 0, 0.1)
    self.lastMs = now
    if self.startAt and now - self.startAt >= START_MS then
        self.startAt = nil
        -- (an empty tank: the starter turns and nothing catches, as in a car)
        self.running = self.fuel > 0
    end
    -- the tank: a little at idle, more the faster; empty, the engine dies
    if self.running then
        self.fuel = math.max(0, self.fuel - dt * (0.0008 + self.kmh * 0.00005))
        if self.fuel <= 0 then
            self.running, self.emptyAt = false, now
        end
    elseif self.fuel <= 0 and self.emptyAt and now - self.emptyAt >= REFILL_MS then
        self.fuel, self.emptyAt = FULL, nil
    end
    if not self.running then
        self.target, self.cruise = 0, false
    elseif self.cruise then
        self.target = self.cruiseKmh
    end
    -- (the speed after the gas, slower to fall than to rise, as a car rolls on)
    local rate = self.target > self.kmh and 1.6 or 0.9
    self.kmh = self.kmh + (self.target - self.kmh) * (1 - math.exp(-rate * dt))
    if self.kmh < 0.3 and self.target == 0 then self.kmh = 0 end
    -- the gear and the revs within it
    self.gear = "N"
    local rpm = 0
    if self.running then
        rpm = IDLE_RPM
        for _, g in ipairs(GEARS) do
            if self.kmh < g[1] then
                self.gear = g[2]
                if g[2] ~= "N" then
                    rpm = 1100 + 3600 * clamp((self.kmh - g[3]) / math.max(1, g[1] - g[3]), 0, 1)
                end
                break
            end
        end
    end
    self.rpm = self.rpm + (rpm - self.rpm) * (1 - math.exp(-8 * dt))
end

-- The car -----------------------------------------------------------------------------

function Demo:makeCar()
    local d = self
    local car, parts = {}, {}
    parts.GasTank = {isContainer = function() return true end, getContainerContentType = function() return "Gasoline" end,
        getContainerContentAmount = function() return d.fuel * 60 end, getContainerCapacity = function() return 60 end,
        getArea = function() return "GasTank" end}
    parts.Engine = {getCondition = function() return 86 end}
    parts.Battery = {getInventoryItem = function() return true end}
    parts.Heater = {getModData = function() return d.heat end}
    -- (a sedan's trunk has its button; a pickup's bed none)
    if self.kind == "sedan" then parts.TruckBed = {} end
    function car:getScript() return {getName = function() return d.kind == "pickup" and "PickUpTruck" or "CarNormal" end,
        getGearRatioCount = function() return 5 end} end
    function car:getPartById(id) return parts[id] end
    function car:getPartCount() return 0 end
    function car:isKeysInIgnition() return d.keyIn end
    function car:isHotwired() return d.hot end
    function car:isEngineRunning() return d.running end
    function car:isStarting() return d.startAt ~= nil end
    function car:isEngineStarted() return d.startAt ~= nil or d.running end
    function car:getRemainingFuelPercentage() return d.fuel * 100 end
    -- (the panel shows the game's "fake" speed: the real one times its modifier)
    function car:getCurrentSpeedKmHour() return d.kmh / BaseVehicle.getFakeSpeedModifier() end
    function car:getEngineSpeed() return d.rpm end
    function car:getTransmissionNumberLetter() return d.gear or "N" end
    function car:getBatteryCharge() return 0.92 end
    -- (the game's regulator speed is the real one: the panel's mark multiplies it)
    function car:isRegulator() return d.cruise end
    function car:getRegulatorSpeed() return d.cruise and d.cruiseKmh / BaseVehicle.getFakeSpeedModifier() or 0 end
    function car:leftSideFuel() return true end
    function car:rightSideFuel() return false end
    function car:getHeadlightsOn() return d.lights end
    function car:getHeadlightCanEmmitLight() return true end
    function car:areAllDoorsLocked() return d.doors == "all" end
    function car:isAnyDoorLocked() return d.doors ~= nil end
    function car:isTrunkLocked() return d.trunkLocked end
    function car:windowsOpen() return 0 end
    function car:getKeyId() return 1 end
    self.car = car
end

--- The game's dashboard's handlers (KnoxDashboard:game), done to this car.
function Demo:press(fn)
    if fn == "onClickHeadlights" then
        self.lights = not self.lights
    elseif fn == "onClickDoors" then
        self.doors = self.doors == nil and "all" or nil
    elseif fn == "onClickTrunk" then
        self.trunkLocked = not self.trunkLocked
    elseif fn == "onClickKeys" then
        if self.keyIn then
            if not self.running and not self.startAt then self.keyIn = false end
        elseif not self.hot then
            self.keyIn = true
        end
    elseif fn == "onClickEngine" then
        if self.running or self.startAt then
            self.running, self.startAt, self.target = false, nil, 0
        elseif self.keyIn or self.hot then
            self.startAt = getTimestampMs()
        end
    end
end

--- The heater's command (the game's "toggleHeater"), done here.
function Demo:heater(on, temp)
    self.heat.active, self.heat.temperature = on == true, temp or 0
end

-- what the wheel turns and a click does here and not on a real car (the road's part)
Demo.wheels = {speed = true, tach = true, tt_cruise = true}
Demo.clicks = {speed = true, tt_cruise = true}

--- The wheel over the speedometer or the tachometer: the gas (down lets the cruise
--- go, as the brake does); over the cruise window: its speed. True when taken.
function Demo:wheel(id, del)
    if not Demo.wheels[id] then return false end
    if not self.running then return true end
    local up = del < 0
    if id == "tt_cruise" then
        if self.cruise then self.cruiseKmh = clamp(self.cruiseKmh + (up and 5 or -5), CRUISE_MIN, TOP_KMH) end
        return true
    end
    if self.cruise and not up then self.cruise = false end
    self.target = clamp((self.cruise and self.cruiseKmh or self.target) + (up and 12 or -12), 0, TOP_KMH)
    if self.cruise then self.cruiseKmh = math.max(CRUISE_MIN, self.target) end
    return true
end

--- A click the road's part takes (the cruise, a bump); true when taken.
function Demo:act(id, right, panel)
    if not Demo.clicks[id] or right then return false end
    if id == "tt_cruise" then
        if self.cruise then
            self.cruise = false
        elseif self.running and self.kmh >= CRUISE_MIN then
            self.cruise, self.cruiseKmh = true, math.floor(self.kmh / 5 + 0.5) * 5
        end
    elseif id == "speed" and self.running and self.kmh > 5 then
        -- a bump: the game's damage check flickers its dashboard - the lights, the shake
        panel.flickAt = getTimestampMs()
    end
    return true
end

--- The line a tip gets here (how to drive the pretend car), or nil.
function Demo:tipNote(id)
    if id == "tt_cruise" then return getText("IGUI_Knox_Dash_Demo_Cruise") end
    if Demo.wheels[id] then
        return getText(self.running and "IGUI_Knox_Dash_Demo_Gas" or "IGUI_Knox_Dash_Demo_Start")
    end
    return nil
end

-- The radio -----------------------------------------------------------------------------

function Demo:makeRadio()
    local d = self
    local r = {on = true, theme = "game", freq = STATIONS[4].freq, vol = 0.5, shuffle = false, rpt = "all", track = 1}
    self.radio = r
    local list = {}
    for i, s in ipairs(STATIONS) do list[i] = {freq = s.freq, title = mhz(s.freq) .. "   " .. s.name} end
    local mm = {list = list, at = 4}
    local function sync()
        mm.at = 0
        if r.theme == "mine" then mm.at = r.track return end
        for i, s in ipairs(list) do if s.freq == r.freq then mm.at = i end end
    end
    function mm.carHas() return true end
    function mm.carOn() return r.on end
    function mm.carAllowed() return r.on end
    function mm.theme() return r.theme end
    function mm.carChannel() return r.freq end
    function mm.vol() return r.vol end
    function mm.shuffleOn() return r.shuffle end
    function mm.repeatMode() return r.rpt end
    function mm.stations() return r.theme == "game" end
    function mm.available() return true end
    function mm.carTitle(theme)
        if not r.on then return getText("IGUI_KnoxMusic_CarSilent") end
        if theme == "game" then
            for _, s in ipairs(STATIONS) do if s.freq == r.freq then return s.name .. "   " .. mhz(s.freq) end end
            return mhz(r.freq) .. " MHz"
        end
        return nil
    end
    function mm.carOpenWindow() end
    function mm.carBroadcastToggle() r.on = not r.on end
    function mm.choose(v)
        r.theme = string.find(tostring(v), "^mine") and "mine" or "game"
        sync()
    end
    -- (round by hand: the game's Lua gives a negative remainder for a negative number -
    -- back from the first station was station 0, an error, the author 2026-10-21)
    local function round(i, n)
        while i < 1 do i = i + n end
        while i > n do i = i - n end
        return i
    end
    local function step(dir)
        if r.theme == "mine" then
            r.track = round(r.track + dir, TRACKS)
        else
            local i = mm.at
            if i < 1 then i = dir > 0 and 0 or #list + 1 end
            r.freq = list[round(i + dir, #list)].freq
        end
        sync()
    end
    function mm.next() step(1) end
    function mm.prev() step(-1) end
    function mm.play(i)
        if list[i] then r.freq = list[i].freq end
        sync()
    end
    function mm.setVol(v) r.vol = clamp(v, 0, 1) end
    function mm.carTune(f)
        r.freq = f
        sync()
    end
    function mm.toggleShuffle() r.shuffle = not r.shuffle end
    function mm.cycleRepeat() r.rpt = (r.rpt == "all") and "one" or (r.rpt == "one" and "off" or "all") end
    self.mm = mm
    local set = {getChannel = function() return r.freq end, getMinChannelRange = function() return 88000 end,
        getMaxChannelRange = function() return 108000 end}
    self.r = {musicPlaying = function() return r.on and r.theme == "mine" end, data = function() return set end}
    sync()
end

-- The driver ----------------------------------------------------------------------------

function Demo:makeDriver()
    local inv = {haveThisKeyId = function() return true end}
    self.chr = {
        playSound = function(_, name) pcall(function() getSoundManager():playUISound(name) end) end,
        getInventory = function() return inv end,
    }
end

return KnoxDashDemo
