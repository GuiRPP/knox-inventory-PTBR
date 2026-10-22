-- The sounds of handling things in the Knox screen, where the game makes none:
--   a thing lifted with the mouse        - its own material, softly (a can, a
--                                          jacket, a book...; KnoxSearchSound.soundOf)
--   put down in the same bag or merged   - the same, a little louder (a move
--                                          to another container is a timed action
--                                          of the game: it has its own sounds)
--   turned in the hand (R)               - the game's own "rotate" of placing furniture
--   a bag's window opened / closed       - that bag's own open / close sound (a zip,
--                                          a rustle), as the game's windows do
-- Choosing a container in the surroundings already plays its own open sound (the
-- game's loot window does it: KnoxLootPanel:select -> setNewContainer).
-- The game's own FMOD events on the character's emitter: the player hears them,
-- the dead don't. Loudness: the settings' "Interface sounds" slider (ui.sound, 0 = off).
-- Asked for by the author, 2026-10-17.

require "Knox/KnoxTheme"
require "Knox/KnoxSearchSound"

KnoxUISound = KnoxUISound or {}
local U = KnoxUISound
local T = KnoxTheme
local SS = KnoxSearchSound

local VOL = {pick = 0.55, place = 0.75, turn = 0.5, bag = 0.8}
-- (a pick and its drop a moment later are both heard; the same sound twice
-- within this is one: a selection of five tiles put down at once)
local GAP_MS = 90

local last = {}

local function volume()
    return T.look("ui.sound") / 100
end

local function emit(name, vol)
    if not name or name == "" then return end
    local v = volume() * vol
    if v <= 0 or isGamePaused() then return end
    local now = getTimestampMs()
    if last[name] and now - last[name] < GAP_MS then return end
    local player = getPlayer()
    if not player then return end
    last[name] = now
    SS.play(player, name, v)
end

--- A thing lifted with the mouse (KnoxDrag.start).
function U.pick(item)
    if not item then return end
    local ok, name = pcall(SS.soundOf, item)
    if ok then emit(name, VOL.pick) end
end

--- A thing put down where it is at once: within its own container, or onto a stack there.
function U.place(item)
    if not item then return end
    local ok, name = pcall(SS.soundOf, item)
    if ok then emit(name, VOL.place) end
end

--- The held thing turned.
function U.turn()
    emit("UIObjectMenuObjectRotate", VOL.turn)
end

--- A bag's own window opened (true) or closed (false).
function U.bag(item, open)
    local inv = item and instanceof(item, "InventoryContainer") and item:getInventory()
    if not inv then return end
    local name
    if open then name = inv:getOpenSound() else name = inv:getCloseSound() or inv:getOpenSound() end   -- (some bags have only the one)
    emit(name, VOL.bag)
end

return KnoxUISound
