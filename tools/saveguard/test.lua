-- KnoxSaveGuard outside the game (tools/saveguard/test.ps1): which saves have lost
-- Knox, what is written back, a "no" kept.

local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else fail = fail + 1; print("FAIL " .. name .. (detail and (" : " .. tostring(detail)) or "")) end
end

-- a mod list as the game's ActiveMods
local function modList(ids)
    local m = {ids = {}}
    for _, id in ipairs(ids) do table.insert(m.ids, id) end
    function m:isModActive(id) for _, x in ipairs(self.ids) do if x == id then return true end end return false end
    function m:setModActive(id, on)
        if on and not self:isModActive(id) then table.insert(self.ids, id) end
    end
    function m:copyFrom(o) self.ids = {}; for _, x in ipairs(o.ids) do table.insert(self.ids, x) end end
    return m
end

local saves = {
    {rel = "Sandbox/Lost", mods = modList({"ZombieBuddy"}), snap = true},          -- lost Knox
    {rel = "Sandbox/Fine", mods = modList({"ZombieBuddy", "KnoxInventory"}), snap = true},
    {rel = "Sandbox/NeverKnox", mods = modList({"SomeMod"}), snap = false},      -- never played with Knox
    {rel = "Sandbox/LostAll", mods = modList({}), snap = true},                  -- lost both
    {rel = "Sandbox/Beta", mods = modList({"ZombieBuddy", "KnoxInventoryBeta"}), snap = true},   -- played with the other Knox
}
function getFullSaveDirectoryTable() local t = {} for _, s in ipairs(saves) do table.insert(t, s.rel) end return t end
function getSaveInfo(rel) for _, s in ipairs(saves) do if s.rel == rel then return {activeMods = s.mods, saveName = rel, gameMode = "Sandbox"} end end end
function knoxMenuInfo(rel) for _, s in ipairs(saves) do if s.rel == rel then return s.snap and {name = "x"} or nil end end end

local written = {}
local current, default = modList({}), modList({"ZombieBuddy", "KnoxInventory", "MenuMod"})
ActiveMods = {getById = function(id) return id == "currentGame" and current or default end}
function manipulateSavefile(rel, action)
    local ids = {}
    for _, x in ipairs(current.ids) do table.insert(ids, x) end
    written[rel] = {action = action, ids = ids}
end

local files = {}
function getFileReader(name)
    local text = files[name]
    if not text then return nil end
    local lines, i = {}, 0
    for l in string.gmatch(text, "[^\r\n]+") do table.insert(lines, l) end
    return {readLine = function() i = i + 1; return lines[i] end, close = function() end}
end
function getFileWriter(name)
    local buf = {}
    return {write = function(_, s) table.insert(buf, s) end, close = function() files[name] = table.concat(buf) end}
end

local G = KnoxSaveGuard
local lost = G.lost()
local names = {}
for _, s in ipairs(lost) do names[s.rel] = true end
check("lost: the save played with Knox that has lost it", names["Sandbox/Lost"])
check("lost: one that lost both mods", names["Sandbox/LostAll"])
check("lost: not one that has Knox", not names["Sandbox/Fine"])
check("lost: not one never played with Knox", not names["Sandbox/NeverKnox"])
check("lost: not one played with the other Knox (release / beta)", not names["Sandbox/Beta"])

for _, s in ipairs(lost) do G.restore(s) end
local w = written["Sandbox/LostAll"]
check("restore: written as the game does", w and w.action == "WriteModsDotTxt")
check("restore: ZombieBuddy before Knox", w and w.ids[1] == "ZombieBuddy" and w.ids[2] == "KnoxInventory", w and table.concat(w.ids, ","))
local w2 = written["Sandbox/Lost"]
check("restore: the save's own mods kept", w2 and w2.ids[1] == "ZombieBuddy" and w2.ids[2] == "KnoxInventory" and #w2.ids == 2, w2 and table.concat(w2.ids, ","))
check("restore: the current game's list back to the menu's", current:isModActive("MenuMod"))

-- a "no" is kept
files["knox_saveguard.txt"] = "Sandbox/Lost\r\n"
saves[1].mods = modList({"ZombieBuddy"})
local again = G.lost()
local still = false
for _, s in ipairs(again) do if s.rel == "Sandbox/Lost" then still = true end end
check("skip: a save said no to is not asked again", not still)

print(string.format("DONE pass=%d fail=%d", pass, fail))
