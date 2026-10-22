-- The car's radio (the author, 2026-10-18: "it should do what the game's does,
-- and have what the main menu's radio has"). The menu's player (KnoxMenuMusic,
-- its card KnoxRadioCard) plays in the car the driver sits in, MM.ctx = "car":
--   Эфир / Broadcast - the game's theme: the car's own set, as the game has it -
--         on / off, its stations (its presets and the public ones it reaches)
--         in the card's list, back / next step through them, the volume is its
--         knob, a click on the card's square opens its window (KnoxRadioWindow)
--   own music       - the player's files from its speaker, as in the menu: the
--         folders, shuffle, repeat, seek, the radio's sound
-- The music needs what the set needs: a set in the car, power (the battery,
-- the key in or the engine on), the set switched on. While it plays the set's
-- broadcast is turned down (its knob kept in the part's mod data and given
-- back), the game's music is muted, zombies hear it as they hear the set
-- (WorldSoundManager, the same range), and it waits while the game is paused.
-- Driven by the dashboard (KnoxDashboard): enter / leave.

require "Knox/KnoxTheme"
require "Knox/KnoxMenuMusic"

local T = KnoxTheme
local MM = KnoxMenuMusic

KnoxCarRadio = KnoxCarRadio or {}
local R = KnoxCarRadio

local VOL_DELAY_MS = 160     -- the knob dragged: the set is told once it rests
local NOISE_MS = 1000        -- how often zombies hear the music

local function nowMs() return getTimestampMs() end

local function part()
    local v = R.vehicle
    return v and v:getPartById("Radio") or nil
end

--- The set's DeviceData, or nil when the car has no set in it.
local function data()
    local p = part()
    if not p or not p:getInventoryItem() then return nil end
    return p:getDeviceData()
end
R.data = data
R.part = part

-- Own music going on in a car the driver has left sounds as from a closed car:
-- the body's low-pass, the cabin's boom - KnoxCarMuffle in the Java part, darker
-- the farther off (`dark` 0..1; -1: off). Without it (an older jar): as it was.
local function muffle(dark, open)
    if knoxMusicMuffle then pcall(knoxMusicMuffle, dark, open or 0) end
end

--- How open the car is, 0 (all shut) .. 1 (the author, 2026-10-21: the music
--- should sound otherwise with a window open): an open door 1, an open or broken
--- window 0.5, an open boot or hood 0.5.
local function openness(v)
    local sum = 0
    local ok = pcall(function()
        for i = 0, v:getPartCount() - 1 do
            local p = v:getPartByIndex(i)
            local w = p and p:getWindow()
            local d = p and p:getDoor()
            if w and (w:isOpen() or w:isDestroyed()) then sum = sum + 0.5 end
            if d and d:isOpen() then
                -- (DoorFrontLeft, DoorRearRight...: 1; TrunkDoor, EngineDoor: 0.5)
                sum = sum + (string.find(tostring(p:getId()), "^Door") and 1 or 0.5)
            end
        end
    end)
    return ok and math.min(1, sum) or 0
end
R.openness = openness   -- (the others' music heard from outside its car: KnoxMusicNet)

local function mhz(f)
    local v = math.floor((f or 0) / 100 + 0.5) / 10
    if v == math.floor(v) then return tostring(math.floor(v)) .. ".0" end
    return tostring(v)
end
R.mhz = mhz

local function channelName(f)
    local zr = getZomboidRadio and getZomboidRadio()
    local ok, name = pcall(function() return zr and zr:getChannelName(f) end)
    if ok and name and name ~= "" then return name end
    return nil
end

-- What the player's card asks (KnoxMenuMusic's MM.car* calls) -----------------------

function MM.carHas() return data() ~= nil end

function MM.carOn()
    local d = data()
    return d ~= nil and d:getIsTurnedOn()
end

--- May music play: the set there, switched on, with power.
function MM.carAllowed()
    local d = data()
    return d ~= nil and d:getIsTurnedOn() and d:canBePoweredHere()
end

function MM.carGetVolume()
    if R.pendVol then return R.pendVol end
    local d = data()
    return d and d:getDeviceVolume() or 0
end

function MM.carSetVolume(v)
    if not data() then return end
    R.pendVol, R.pendVolMs = math.max(0, math.min(1, v)), nowMs()
end

function MM.carChannel()
    local d = data()
    return d and d:getChannel() or nil
end

function MM.carTune(f)
    local d = data()
    if not d or not d:getIsTurnedOn() or not f or f == d:getChannel() then return end
    d:setChannel(f)
    R.tunedMs = nowMs()
end

local STEP = 200        -- kHz, as the game's radios tune
local airCache = {}
--- Frequencies from lo to hi that have a station's name (a broadcast on them).
function R.onAir(lo, hi)
    local key = tostring(lo) .. ":" .. tostring(hi)
    local hit = airCache[key]
    if hit and getTimestampMs() - hit.at < 60000 then return hit.list end
    local list = {}
    local zr = getZomboidRadio and getZomboidRadio()
    if zr and lo and hi and hi > lo then
        local f = math.ceil(lo / STEP) * STEP
        local n = 0
        while f <= hi and n < 400 do
            if channelName(f) then table.insert(list, f) end
            f, n = f + STEP, n + 1
        end
    end
    airCache[key] = {at = getTimestampMs(), list = list}
    return list
end

--- The stations the card lists: the set's presets and the public stations in
--- its range (the ones the game's sets come tuned to), by frequency.
function MM.carStations()
    local d = data()
    if not d then return {} end
    local lo, hi = d:getMinChannelRange(), d:getMaxChannelRange()
    local out, seen = {}, {}
    local function add(f, name)
        f = tonumber(f)
        if not f or f < lo or f > hi or seen[f] then return end
        seen[f] = true
        name = (name and name ~= "") and name or channelName(f)
        table.insert(out, {freq = f, title = mhz(f) .. (name and ("   " .. name) or " MHz")})
    end
    local dp = d:getDevicePresets()
    local list = dp and dp:getPresets()
    if list then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            add(p:getFrequency(), p:getName())
        end
    end
    -- the stations on the air in its range: every 0.2 MHz step asked for its
    -- name (the game's channel map can't be walked from Lua - its key set is a
    -- Java class Lua doesn't see: an error, 2026-10-18); worked out once per range
    for _, f in ipairs(R.onAir(lo, hi)) do add(f) end
    add(d:getChannel())
    table.sort(out, function(a, b) return a.freq < b.freq end)
    return out
end

--- The set on / off, as the game's dashboard (switched straight, no action).
function MM.carBroadcastToggle()
    local d = data()
    if not d then return end
    if d:getIsTurnedOn() then
        d:setIsTurnedOn(false)
    elseif d:canBePoweredHere() then
        -- (switched on for own music: the broadcast down before it is heard - the
        -- author, 2026-10-21: a track started from the card brought the station too)
        if MM.theme() == "mine" then R.setMuted(true, true) end
        d:setIsTurnedOn(true)
    else
        R.noPowerMs = nowMs()
    end
end

--- The card's title in the car: the set not there, off, without power; the
--- broadcast's station or disc. nil: the track's own title.
function MM.carTitle(theme)
    local d = data()
    if not d then return getText("IGUI_KnoxMusic_CarNone") end
    if not d:getIsTurnedOn() then
        if not d:canBePoweredHere() or nowMs() - (R.noPowerMs or 0) < 2500 then return getText("IGUI_KnoxMusic_CarNoPower") end
        return getText("IGUI_KnoxMusic_CarSilent")
    end
    if theme == "game" then
        if d:isPlayingMedia() then
            local md = d:getMediaData()
            local t = md and md:getTranslatedTitle()
            if t and t ~= "" then return t end
        end
        local f = d:getChannel()
        local name = channelName(f)
        return name and (name .. "   " .. mhz(f)) or (mhz(f) .. " MHz")
    end
    return nil
end

--- The set's window (the game's, or Knox's in its place), as the lamp's click.
function MM.carOpenWindow()
    local p, pl = part(), R.player
    if not p or not pl or not p:getInventoryItem() or not p:getDeviceData() then return end
    if ISRadioWindow and ISRadioWindow.isActive(pl, p) then
        ISRadioWindow.closeIfActive(pl, p)
    elseif ISVehicleMenu and ISVehicleMenu.onSignalDevice then
        ISVehicleMenu.onSignalDevice(pl, p)
    end
end

-- In and out ------------------------------------------------------------------------

function R.isOn() return R.vehicle ~= nil end

--- Is the car's music playing now (the tape's reels turn in the dashboard's radio)?
function R.musicPlaying()
    return R.vehicle ~= nil and MM.active and MM.playing ~= nil and not MM.paused and not MM.hold
end

--- Is the car's own music still going on - a track playing, or the gap before the
--- next (the author, 2026-10-21: outside the car a track ended and the broadcast
--- came back in place of the next one), or the game paused under it?
function R.musicGoesOn()
    return R.vehicle ~= nil and MM.active and not MM.paused
        and (MM.playing ~= nil or (not MM.ended and #MM.list > 0))
end

--- May the music heard from outside the car be left playing in it while the driver
--- drives another (its own music, a file of the folder - KnoxMusic's parked track)?
local function canPark()
    return knoxMusicSwapParked ~= nil and R.outside and R.musicGoesOn() and MM.theme() == "mine"
        and MM.carAllowed() and (MM.playing == nil or MM.playing.kind == "file")
end

--- What the car left behind plays on: its list, where it is, how loud by the car.
local function parkedOf()
    local d = data()
    local tr = MM.list[MM.at]
    local list = {}
    for i, t in ipairs(MM.list) do list[i] = t end
    local wait = MM.playing == nil and math.max(0, ((MM.nextAt or 0) - getTimestampMs() / 1000) * 1000) or 0
    return {vehicle = R.vehicle, player = R.player, list = list, at = MM.at, playing = MM.playing ~= nil and tr ~= nil,
        nextAt = nowMs() + wait, base = MM.carTrackVolume(), range = 5 + (d and d:getBaseVolumeRange() or 0) * MM.vol()}
end

--- The driver got in (or the dashboard came up for the driver's car).
-- (the author, 2026-10-21: own music left playing in a car goes on when the driver
-- drives off in another, whose music plays too - "both play at once": the one left
-- is the parked track, R.parked; back in that car, its music is the player's again)
function R.enter(player, vehicle)
    if not T.active or not vehicle then return end
    if R.vehicle == vehicle and R.player == player then
        if R.outside then R.backInside() end   -- (back in the car its music kept playing in)
        return
    end
    local was = R.parked ~= nil and R.parked.vehicle == vehicle and R.parked or nil
    local left
    if R.vehicle then
        if canPark() then
            -- (two cars at most: a third car's music stops)
            if R.parked and not was then R.unparkStop() end
            left = parkedOf()
            R.leave(true, true)
        else
            R.leave(true)
        end
    end
    -- the two tracks change places as they play (either may be none)
    if left or was then knoxMusicSwapParked() end
    R.parked = left
    R.player, R.vehicle = player, vehicle
    R.muted, R.noiseAt = nil, 0
    MM.ctx = "car"
    MM.active = true
    MM.hold = false
    MM.resumeAt = nil
    if was then
        -- back in the car its music went on in: the same track, from where it is
        MM.list, MM.at, MM.ended, MM.paused = was.list, was.at, false, false
        local tr = was.list[was.at]
        MM.playing = (was.playing and tr) and {kind = "file", name = tr.name} or nil
        MM.nextAt = was.playing and 0 or was.nextAt / 1000
        R.muted = true   -- (its broadcast is down already, its knob in the part's mod data)
        muffle(-1)
        MM.applyRadio()
    else
        MM.apply()
    end
end

--- Still playing in this car? (The menu's player is stopped when a game starts -
--- after the game may already have seated the driver: entered again then.)
function R.ensure(player, vehicle)
    if R.vehicle == vehicle and R.player == player and MM.active and MM.ctx == "car" then return end
    if R.vehicle ~= vehicle or R.player ~= player then
        R.enter(player, vehicle)
        return
    end
    R.vehicle = nil
    R.enter(player, vehicle)
end

--- Out of the car (or the dashboard gone): the music off, the set's knob given back -
--- unless own music plays: then it goes on from the car (R.goOutside). `force`: off.
--- `park`: the track not stopped - it goes on in the car as the parked one (R.enter).
function R.leave(force, park)
    if not R.vehicle then return end
    if not force and not R.outside and R.musicGoesOn() and MM.theme() == "mine" and MM.carAllowed() then
        R.goOutside()
        return
    end
    if R.outside then
        R.outside, MM.carOutside, MM.carFar = nil, nil, nil
        if not park then muffle(-1) end
    end
    R.flushVolume(true)
    if park then MM.playing = nil else MM.stopTrack() end
    MM.hold = false
    if knoxMusicPause and not park then pcall(knoxMusicPause, false) end
    MM.active = false
    MM.applyRadio()   -- (the hiss and the filter off)
    if MM.carMuted then
        MM.carMuted = false
        if knoxMusicMuteGame then knoxMusicMuteGame(false) end
    end
    if MM.carForeign then
        MM.carForeign = false
        if knoxMusicForeign then knoxMusicForeign(1) end   -- (mods' soundtracks back as they were)
    end
    -- (parked: its broadcast stays down under the music going on in it)
    if park then R.muted = nil else R.setMuted(false) end
    if KnoxRadioCard and KnoxRadioCard.hide then KnoxRadioCard.hide() end
    T.saveSettings()
    R.vehicle, R.player = nil, nil
end

function R.flushVolume(now)
    if not R.pendVol then return end
    if not now and nowMs() - (R.pendVolMs or 0) < VOL_DELAY_MS then return end
    local d, v = data(), R.pendVol
    R.pendVol = nil
    if d and math.abs(d:getDeviceVolume() - v) > 0.001 then d:setDeviceVolume(v) end
end

--- The set's broadcast down under the music (its knob kept), or given back.
--- (Held down every tick: the set switched on, or the game, may give it its
--- volume back.) `force`: said again even if it is so already.
function R.setMuted(want, force)
    local p, d = part(), data()
    if want and want == R.muted and not force then
        if d and d:getDeviceVolume() > 0 then d:setDeviceVolume(0) end
        return
    end
    if want == R.muted and not force then return end
    R.muted = want
    if not p or not d then return end
    local md = p:getModData()
    if want then
        if md.knoxVol == nil then md.knoxVol = d:getDeviceVolume() end
        if d:getDeviceVolume() > 0 then d:setDeviceVolume(0) end
        -- (what the set already plays, cut too - not only what comes next)
        local em = d:getEmitter()
        if em then pcall(function() em:setVolumeAll(0) end) end
    elseif md.knoxVol ~= nil then
        d:setDeviceVolume(md.knoxVol)
        md.knoxVol = nil
    end
    print("[Knox] car radio: broadcast " .. (want and "down under own music" or "back") .. ", set volume " .. tostring(d:getDeviceVolume()))
end

-- Own music left playing when the driver gets out (the author, 2026-10-21: "as the
-- radio goes on"): it goes on from the car, quieter with the distance - silent past
-- the range zombies hear it at, though it goes on however far (the author,
-- 2026-10-21: it must not stop when walked away from) - and stops for good when
-- the set goes off or loses power, or in another car.
local OUTSIDE_VOL = 0.85

local function outsideGain(pl, v)
    local d = data()
    if not d then return 0 end
    local range = 5 + d:getBaseVolumeRange() * MM.vol()
    local dx, dy = pl:getX() - v:getX(), pl:getY() - v:getY()
    local dist = math.sqrt(dx * dx + dy * dy) + math.abs(pl:getZ() - v:getZ()) * 3
    return math.max(0, 1 - dist / math.max(1, range))
end

function R.goOutside()
    R.outside = true
    MM.carOutside = true
    R.openAt, R.open, R.openSaid = nil, nil, nil
    MM.stopHiss()
    -- (the driver just got out: the door is open)
    local v = R.vehicle
    muffle(0, v and openness(v) or 0)
end

function R.backInside()
    R.outside = nil
    MM.carOutside = nil
    MM.carFar = nil
    muffle(-1)
    MM.applyRadio()
end

-- The parked car's music (R.enter): its own list stepped here as KnoxMenuMusic steps
-- the player's, heard as from outside a car - by the distance, through its body.
local PARK_GAP_MS = 3000   -- quiet between two tracks (KnoxMenuMusic's GAP_S)

local function setOf(v)
    local p = v and v:getPartById("Radio")
    if not p or not p:getInventoryItem() then return nil, nil end
    return p:getDeviceData(), p
end

--- The parked car's music off for good, its broadcast's knob given back.
function R.unparkStop()
    local P = R.parked
    if not P then return end
    R.parked = nil
    if knoxMusicParkedStop then knoxMusicParkedStop() end
    local d, p = setOf(P.vehicle)
    local md = p and p:getModData()
    if d and md and md.knoxVol ~= nil then
        d:setDeviceVolume(md.knoxVol)
        md.knoxVol = nil
    end
end

local function parkedTick()
    local P = R.parked
    if not P then return end
    local pl, v = P.player, P.vehicle
    local d = setOf(v)
    -- (the set off or without power, the player dead: off for good)
    if not pl or pl:isDead() or not d or not d:getIsTurnedOn() or not d:canBePoweredHere() then
        R.unparkStop()
        return
    end
    local hold = getGameSpeed and getGameSpeed() == 0
    if hold ~= (P.hold == true) then
        P.hold = hold
        knoxMusicParkedPause(hold)
    end
    if hold then return end
    -- (the game may give the set its volume back: down again)
    if d:getDeviceVolume() > 0 then d:setDeviceVolume(0) end
    local t = nowMs()
    if P.playing and not knoxMusicParkedPlaying() then
        P.playing = false
        P.nextAt = t + PARK_GAP_MS
        -- the last track of a list played once: the end
        if MM.repeatMode() == "off" and P.at >= #P.list then R.unparkStop() return end
    end
    local n = #P.list
    if not P.playing and t >= P.nextAt then
        if n == 0 then R.unparkStop() return end
        local i = (MM.repeatMode() == "one" and P.at > 0) and P.at or P.at + 1
        if i > n then i = 1 end
        P.at = i
        local tr = P.list[i]
        P.playing = tr ~= nil and tr.kind == "file" and knoxMusicParkedPlay(tr.name, 0) == true
        P.nextAt = t + PARK_GAP_MS
        P.lookAt = nil
    end
    -- by the distance and how open the car is, a few times a second
    if not P.lookAt or t >= P.lookAt then
        P.lookAt = t + 200
        local dx, dy = pl:getX() - v:getX(), pl:getY() - v:getY()
        local dist = math.sqrt(dx * dx + dy * dy) + math.abs(pl:getZ() - v:getZ()) * 3
        local gain = math.max(0, 1 - dist / math.max(1, P.range))
        local open = openness(v)
        knoxMusicParkedVolume(P.base * gain * (0.55 + 0.45 * open) * OUTSIDE_VOL)
        knoxMusicParkedMuffle(1 - gain, open)
    end
    -- zombies hear it as they hear the set
    if P.playing and t >= (P.noiseAt or 0) and addSound then
        P.noiseAt = t + NOISE_MS
        local radius = 5 + math.floor(math.max(0, P.range - 5))
        addSound(v, math.floor(v:getX()), math.floor(v:getY()), math.floor(v:getZ()), radius, math.floor(100 * math.min(1, P.base)))
    end
end

local function tick()
    parkedTick()
    -- the card over the dashboard's radio goes with the dashboard (hidden under the
    -- Knox screen, gone with the car)
    local card = KnoxRadioCard and KnoxRadioCard.instance
    if card and MM.ctx == "car" and card:getIsVisible() and nowMs() - ((KnoxDashboard and KnoxDashboard.drawnAt) or 0) > 250 then
        KnoxRadioCard.hide()
    end
    if not R.vehicle then return end
    local pl, v = R.player, R.vehicle
    -- (a car gone from under the driver - died, teleported: out)
    if not pl or pl:isDead() then R.leave(true) return end
    -- back in that car on any seat (the dashboard, and R.enter with it, is the
    -- driver's only - the author, 2026-10-21: a passenger kept the outside sound)
    if R.outside and pl:getVehicle() == v then R.backInside() end
    if pl:getVehicle() ~= v then
        if R.outside then
            -- (the music stopped, the set off: off for good; in another car it goes
            -- on - as its passenger, from here; at its wheel, as the parked one: R.enter)
            if not R.musicGoesOn() or not MM.carAllowed() then R.leave(true) return end
            local gain = outsideGain(pl, v)
            -- (the windows and doors looked at a few times a second)
            local t = nowMs()
            if not R.openAt or t >= R.openAt then
                R.openAt = t + 300
                R.open = openness(v)
            end
            local open = R.open or 0
            -- a shut car is quieter too: through glass and steel; and from outside a
            -- little quieter in all (the author, 2026-10-21: "just a bit quieter")
            local vol = gain * (0.55 + 0.45 * open) * OUTSIDE_VOL
            if math.abs(vol - (MM.carFar or 1)) > 0.01 or open ~= R.openSaid then
                MM.carFar = vol
                R.openSaid = open
                MM.applyVolume()
                muffle(1 - gain, open)
            end
        else
            R.leave()
            if not R.outside then return end
        end
    end
    R.flushVolume(false)
    -- the game paused: the track waits (and the hiss with it)
    local hold = getGameSpeed and getGameSpeed() == 0
    if hold ~= (MM.hold == true) then
        MM.hold = hold
        if MM.playing and MM.playing.kind == "file" and not MM.paused and knoxMusicPause then knoxMusicPause(hold) end
        if hold then MM.stopHiss() else MM.applyRadio() end
    end
    -- own music chosen and able to play: the set's broadcast down under it - from
    -- the moment it is chosen, a track playing or not (the author, 2026-10-21: the
    -- stations went on after switching to own music)
    local mine = MM.theme() == "mine" and MM.carAllowed()
    R.setMuted(mine)
    -- zombies hear it as they hear the set: its range at this volume
    if R.musicPlaying() then
        local t = nowMs()
        if t >= (R.noiseAt or 0) then
            R.noiseAt = t + NOISE_MS
            local d = data()
            local vol = MM.vol()
            if d and vol > 0 and addSound then
                local radius = 5 + math.floor(d:getBaseVolumeRange() * vol)
                addSound(v, math.floor(v:getX()), math.floor(v:getY()), math.floor(v:getZ()), radius, math.floor(100 * vol))
            end
        end
    end
end

local tickEvent = Events.OnTickEvenPaused or Events.OnTick
tickEvent.Add(tick)

-- (Lua loaded anew - a game left for the menu, another started: a parked car's
-- track the old Lua left in the Java part has no car any more)
if knoxMusicParkedStop then knoxMusicParkedStop() end

return KnoxCarRadio
