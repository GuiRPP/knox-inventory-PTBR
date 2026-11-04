-- What the character knows of a magazine (the author, 2026-10-31): how many rounds are
-- in a magazine is not shown; a spare one becomes known once it has been in the gun,
-- loaded or unloaded - by any way, the game's menus too. A flag in the magazine's mod
-- data, so it lasts with the save and goes with the magazine; one that is found is
-- not known.
--
-- A magazine taken out of a gun is a new item (ISEjectMagazine:unloadAmmo): it is known
-- as it is made, before the game sends it to the client. In a game with others the
-- actions' rounds are moved on the server, which keeps the flag and sends it round.

require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISEjectMagazine"
require "TimedActions/ISLoadBulletsInMagazine"
require "TimedActions/ISUnloadBulletsFromMagazine"

KnoxMagKnown = KnoxMagKnown or {}
local K = KnoxMagKnown

-- Numbers of rounds hidden from magazines and guns (set by KnoxRMenu at the game's start:
-- the menu on R is the way to see them, so with it off all is as in the game).
K.hide = false

--- Does the character know how many rounds this magazine has?
function K.is(mag)
    return mag:hasModData() and mag:getModData().knoxMag == true
end

--- It is known from now on.
function K.mark(mag, player)
    local md = mag:getModData()
    if md.knoxMag == true then return end
    md.knoxMag = true
    if player and isServer() and syncItemModData then syncItemModData(player, mag) end
end

-- (only once: the Lua reloaded, the actions would be wrapped twice)
if not K.hooked then
    K.hooked = true

    -- the game makes the new magazine and sends it in one go: the item it asks for is
    -- marked as it is made
    local unloadAmmo = ISEjectMagazine.unloadAmmo
    function ISEjectMagazine:unloadAmmo()
        local make = instanceItem
        _G.instanceItem = function(ft)
            local it = make(ft)
            if it then K.mark(it) end
            return it
        end
        local ok, err = pcall(unloadAmmo, self)
        _G.instanceItem = make
        if not ok then print("[Knox] taking a magazine out: " .. tostring(err)) end
    end

    local function markOn(cls, round)
        local animEvent = cls.animEvent
        function cls:animEvent(event, parameter)
            if event == round and self.magazine then K.mark(self.magazine, self.character) end
            return animEvent(self, event, parameter)
        end
    end
    markOn(ISLoadBulletsInMagazine, "InsertBullet")
    markOn(ISUnloadBulletsFromMagazine, "RemoveBullet")

    -- (an empty one is unloaded at once, with no round to come out: known just the same.
    -- One with rounds only from the first round out - begun and stopped at once, it tells
    -- nothing; QA 2026-10-31)
    local start = ISUnloadBulletsFromMagazine.start
    function ISUnloadBulletsFromMagazine:start()
        local r = start(self)
        local mag = self.magazine
        if mag and mag:getCurrentAmmoCount() == 0 then K.mark(mag, self.character) end
        return r
    end
    -- (in a game with others start() is the client's: the flag set there is the client's alone,
    -- and an empty one was found out again after a reload. The server starts it too, and it sends
    -- the flag round - QA, 2026-11-04)
    local serverStart = ISUnloadBulletsFromMagazine.serverStart
    if serverStart then
        function ISUnloadBulletsFromMagazine:serverStart()
            local mag = self.magazine
            if mag and mag:getCurrentAmmoCount() == 0 then K.mark(mag, self.character) end
            return serverStart(self)
        end
    end
end

return KnoxMagKnown
