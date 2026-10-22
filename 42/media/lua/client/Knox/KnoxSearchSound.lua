-- The sounds of a search (KnoxSearch): the character's hands going through the
-- container while it lasts, and a short sound of the thing itself each time
-- one is found - a can clinks, a book thuds shut, a jacket rustles, a pistol
-- clanks. All of them the game's own sounds (FMOD events, played on the
-- character's emitter as the game's own transfers are: heard by the player
-- only, never by the dead).
--
-- What a thing sounds like: its material (KnoxMaterial: every item of the game read
-- through by its rules, a mod's by the same rules; the player's own line in
-- knox_overrides.txt first), the game's sound standing in for it. So every thing
-- gets a sound, a mod's too.
--
-- One level for all (the author, 2026-10-17: "some very quiet, some loud"): every
-- event is played with the volume that levels it (KnoxSoundLevelData.lua, measured
-- from its recordings in the game's bank: tools\sound\levels.ps1). The things' own
-- sounds (a weapon's drop on the floor, ~250 of them, not in the bank by name) are
-- not used any more: they were the loudest jumps.
--
-- Loudness: the settings' "Search sounds" slider (search.sound, 0 = off).
-- Asked for by the author, 2026-10-16.

require "Knox/KnoxTheme"
require "Knox/KnoxMaterial"
require "Knox/KnoxSoundLevelData"

KnoxSearchSound = KnoxSearchSound or {}
local SS = KnoxSearchSound
local T = KnoxTheme

-- loudness at 100 %, over the levelled event: a thing found, and the hands'
-- rummage under it (a background, some 7 dB below)
local VOL = {foley = 0.6, rummage = 0.45}
-- (a search may find five small things a second: not every one of them is heard)
local GAP_MS = 140

local lastFound = 0
local loop, loopPlayer, loopSeen = nil, nil, 0

local function volume()
    return T.look("search.sound") / 100
end

--- The FMOD event a thing sounds like (found, lifted, put down: KnoxUISound too).
function SS.soundOf(item)
    return KnoxMaterial.soundOf(KnoxMaterial.of(item))
end

-- (FMOD takes volumes over 1: a quiet recording is raised, not only loud ones lowered)
local MAX_VOL = 4

local function play(player, name, vol)
    if vol <= 0 then return nil end
    local level = KnoxSoundLevel and KnoxSoundLevel[name] or 1
    local em = player:getEmitter()
    local id = em:playSound(name)
    if id and id ~= 0 then em:setVolume(id, math.min(MAX_VOL, vol * level)) end
    return id
end
SS.play = play   -- (KnoxUISound)

--- A thing has just been found (KnoxSearch.tick).
function SS.found(item)
    local v = volume()
    if v <= 0 then return end
    local now = getTimestampMs()
    if now - lastFound < GAP_MS then return end
    local player = getPlayer()
    if not player then return end
    lastFound = now
    local ok, name = pcall(SS.soundOf, item)
    if ok and name then play(player, name, VOL.foley * v) end
end

local function stopLoop()
    if loop and loopPlayer then loopPlayer:getEmitter():stopSound(loop) end
    loop, loopPlayer = nil, nil
end

-- (the loop is stopped by the search when it ends; if the screen is closed
-- meanwhile the search's tick is no longer called: a frame without one stops it)
local function watch()
    if loop and getTimestampMs() - loopSeen < 250 and not isGamePaused() then return end
    stopLoop()
    Events.OnTick.Remove(watch)
end

--- Every frame of a search: the hands going through the container.
function SS.rummage()
    loopSeen = getTimestampMs()
    if loop then
        if not loopPlayer:getEmitter():isPlaying(loop) then loop = nil end   -- (ran out: again)
        if loop then return end
    end
    local v = volume()
    local player = getPlayer()
    if v <= 0 or not player or isGamePaused() then return end
    loopPlayer = player
    loop = play(player, "RummageInInventory", VOL.rummage * v)
    if loop then
        Events.OnTick.Remove(watch)
        Events.OnTick.Add(watch)
    end
end

--- The search is over or left.
function SS.stop()
    stopLoop()
end

return KnoxSearchSound
