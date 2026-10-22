-- Knox dropped out of a save: when Steam updates the mod while the game runs, the
-- mod's folder is half there for a moment (the game holds its Java part open),
-- the game counts the mod as missing until it is restarted, loads the save
-- without it and writes the save's mods.txt without it - and its own Mods
-- screen won't switch it back on before a restart (players' reports, 2026-10-16
-- and 17: "Knox disappeared from my save", "the interface is gone in the game").
--
-- In the main menu Knox looks at the latest saves: one that has Knox's own files
-- (the hero's snapshot for the camp: it was played with Knox) but no Knox in its
-- mods.txt has lost it, not had it removed. Knox asks, once, whether to add it
-- back, and writes mods.txt as the game's Mods screen does (the save's mods,
-- ZombieBuddy and Knox switched on, manipulateSavefile "WriteModsDotTxt"). A "no"
-- is kept (Zomboid/Lua/knox_saveguard.txt) and not asked again for that save.

require "Knox/KnoxTheme"
require "ISUI/ISModalDialog"
require "OptionScreens/MainScreen"

KnoxSaveGuard = KnoxSaveGuard or {}
local G = KnoxSaveGuard
local T = KnoxTheme

local FILE = "knox_saveguard.txt"
local LOOK_AT = 12        -- the newest saves looked at
local MOD_ID, JAVA_ID = T.MOD_ID, "ZombieBuddy"

local function readSkipped()
    local out = {}
    local r = getFileReader and getFileReader(FILE, false)
    if not r then return out end
    local line = r:readLine()
    while line do
        if line ~= "" then out[line] = true end
        line = r:readLine()
    end
    r:close()
    return out
end

local function writeSkipped(set)
    local w = getFileWriter and getFileWriter(FILE, true, false)
    if not w then return end
    for rel in pairs(set) do w:write(rel .. "\r\n") end
    w:close()
end

local function has(mods, id)
    return mods:isModActive(id) or mods:isModActive("\\" .. id)
end

--- Is any of Knox's mods (the release or the beta) in a save's mods? A save
--- played with the other one has Knox, not lost it - adding this one too
--- would put both in it.
local function hasKnox(mods)
    for _, id in ipairs(T.MOD_IDS) do
        if has(mods, id) then return true end
    end
    return false
end

--- The latest saves played with Knox that have lost it: {rel, name}.
function G.lost()
    local out = {}
    local ok, dirs = pcall(getFullSaveDirectoryTable)
    if not ok or not dirs or not knoxMenuInfo then return out end
    local skipped = readSkipped()
    for i, rel in ipairs(dirs) do
        if i > LOOK_AT then break end
        local okInfo, info = pcall(getSaveInfo, rel)
        if okInfo and info and info.activeMods and info.gameMode ~= "Multiplayer" and not skipped[rel] then
            local okSnap, snap = pcall(knoxMenuInfo, rel)
            if okSnap and snap and not hasKnox(info.activeMods) then
                table.insert(out, {rel = rel, name = info.saveName or rel, mods = info.activeMods})
            end
        end
    end
    return out
end

--- Knox (and ZombieBuddy, which it needs, before it) back into a save's mods.txt.
function G.restore(save)
    local cur = ActiveMods.getById("currentGame")
    cur:copyFrom(save.mods)
    if not has(cur, JAVA_ID) then cur:setModActive(JAVA_ID, true) end
    -- (the other Knox off, should the save have it: the two never go together)
    for _, id in ipairs(T.MOD_IDS) do
        if id ~= MOD_ID and has(cur, id) then
            cur:setModActive(id, false)
            cur:setModActive("\\" .. id, false)
        end
    end
    cur:setModActive(MOD_ID, true)
    manipulateSavefile(save.rel, "WriteModsDotTxt")
    -- (as the game's Mods screen leaves it: the current game's list back to the menu's)
    cur:copyFrom(ActiveMods.getById("default"))
    print("[Knox] save guard: Knox added back to the mods of " .. tostring(save.rel))
end

local function ask(list)
    local names = {}
    for _, s in ipairs(list) do table.insert(names, "\"" .. s.name .. "\"") end
    local text = getText("IGUI_Knox_SaveGuard", table.concat(names, ", "))
    local fontH = getTextManager():getFontHeight(UIFont.Small)
    local w, h = math.max(620, fontH * 32), math.max(220, fontH * 11)
    local modal = ISModalDialog:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2,
        w, h, text, true, nil, function(_, button)
            if button.internal == "YES" then
                for _, s in ipairs(list) do pcall(G.restore, s) end
            else
                local skipped = readSkipped()
                for _, s in ipairs(list) do skipped[s.rel] = true end
                writeSkipped(skipped)
            end
        end, 0)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)   -- (the main screen comes to the top on a click)
end

-- A save that never had Knox (Knox switched on in the menu, the save made before,
-- or with the mod off): the game loads it with the save's own mods, without Knox -
-- "the mod doesn't work: the menu is Knox's, the inventory is the game's" (the most
-- common complaint, ~19 players by 2026-10-19). On loading such a save Knox asks
-- whether to add it; "Play without Knox" is kept for that save.

local function askOnLoad(info, go)
    local rel = info.saveDir
    local text = getText("IGUI_Knox_SaveGuard_Load", tostring(info.saveName or rel))
    local fontH = getTextManager():getFontHeight(UIFont.Small)
    local w, h = math.max(620, fontH * 32), math.max(220, fontH * 11)
    local modal = ISModalDialog:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2,
        w, h, text, true, nil, function(_, button)
            if button.internal == "YES" then
                local ok, err = pcall(G.restore, {rel = rel, mods = info.activeMods})
                if not ok then print("[Knox] save guard: could not add Knox to " .. tostring(rel) .. ": " .. tostring(err)) end
            else
                local skipped = readSkipped()
                skipped[rel] = true
                writeSkipped(skipped)
            end
            go()
        end, 0)
    modal:initialise()
    if modal.yes then modal.yes:setTitle(getText("IGUI_Knox_SaveGuard_Add")) end
    if modal.no then modal.no:setTitle(getText("IGUI_Knox_SaveGuard_Without")) end
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
end

--- The save being loaded has no Knox, and the player hasn't said to play it without: ask.
local function needsAsk()
    if not T.active then return nil end
    local ok, info = pcall(getSaveInfo, getWorld():getWorld())
    if not ok or not info or not info.activeMods or not info.saveDir then return nil end
    if info.gameMode == "Multiplayer" or hasKnox(info.activeMods) then return nil end
    if readSkipped()[info.saveDir] then return nil end
    return info
end

if MainScreen and MainScreen.continueLatestSaveAux and not MainScreen.knoxSaveGuardHooked then
    MainScreen.knoxSaveGuardHooked = true
    local aux = MainScreen.continueLatestSaveAux
    MainScreen.continueLatestSaveAux = function(fromResetLua, checkWorldVersion)
        -- (only the first call of a load: after a reset of the Lua or the world
        -- version question it comes again with the answer already given)
        if not fromResetLua and checkWorldVersion == nil then
            local info = needsAsk()
            if info then
                askOnLoad(info, function() aux(fromResetLua, checkWorldVersion) end)
                return
            end
        end
        return aux(fromResetLua, checkWorldVersion)
    end
end

-- (a few ticks into the menu: its screens are built, the saves listed)
local waitTicks = 0
local function check()
    waitTicks = waitTicks + 1
    if waitTicks < 20 then return end
    Events.OnTick.Remove(check)
    if not T.active then return end
    local ok, list = pcall(G.lost)
    if ok and #list > 0 then ask(list) end
end

Events.OnMainMenuEnter.Add(function()
    waitTicks = 0
    Events.OnTick.Remove(check)
    Events.OnTick.Add(check)
end)

return KnoxSaveGuard
