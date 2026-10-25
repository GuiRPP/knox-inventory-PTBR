-- The item editor's presets (the author, 2026-10-25: "general presets, presets for a
-- tab of items, a preset for a mod"; the approved mockup .claude/mockups/editor).
--
-- A preset is lines as knox_overrides.txt has them, for every item ("all"), for the
-- items of one of the editor's tabs ("tab:bag", "tab:ammo"...) or for the items of
-- one mod ("mod:<its ID>"). A file each, Zomboid/Lua/knox_presets/<name>.txt:
--     # Knox Inventory preset
--     # name = Tactical Gear: compact
--     # for = mod TacticalGear            (all | tab bag | mod <mod ID>)
--     TG.TacticalPack = grid 5x6
-- knox_presets/index.txt says which are in use and which one the editor writes to.
--
-- In the game they go in layers, the narrower over the wider, item by item and part
-- by part (a size, a bag's shape, a stack, pockets, a category, a sound):
--     Knox's own (the rules, KnoxFootprintData)
--     the mod's own defaults (media/knox/item_defaults.txt)
--     the general preset in use (one)
--     a tab's preset in use (one a tab)
--     a mod's preset in use (one a mod)
--     knox_overrides.txt (the player's lines by hand, over them all)
-- A line of a preset says only what differs from the mod's own defaults: on top
-- of them it gives the item as the editor showed it.
-- In a game with others the server's presets are everyone's (KnoxNet).

require "Knox/KnoxFootprint"

KnoxPresets = KnoxPresets or {}
local P = KnoxPresets
local F = KnoxFootprint

P.DIR = "knox_presets/"
P.INDEX = P.DIR .. "index.txt"
P.HEADER = "# Knox Inventory preset"
-- the editor's tabs of items, in its column's order
P.SIDES = {"bag", "clo", "wpn", "ammo", "med", "food", "tool", "mat", "info", "misc"}

-- Scopes ---------------------------------------------------------------------------

--- "all" / "tab:bag" / "mod:Id" -> kind, value
function P.scopeOf(scope)
    local k, v = string.match(scope or "all", "^(%a+):(.*)$")
    if not k then return "all", "" end
    return k, v
end

--- 0 the general ones, 1 a tab's, 2 a mod's: the higher goes over the lower.
function P.rank(scope)
    local k = P.scopeOf(scope)
    if k == "tab" then return 1 end
    if k == "mod" then return 2 end
    return 0
end

-- (the game's display categories -> the editor's tabs; KnoxTheme.category's way)
local SIDE_BY_DISPLAY = {
    Ammo = "ammo", WeaponPart = "ammo",
    FirstAid = "med",
    Food = "food", Water = "food", WaterContainer = "food", Cooking = "food",
    Tool = "tool", Electronics = "tool", Communications = "tool", LightSource = "tool",
    VehicleMaintenance = "tool", Gardening = "tool", Fishing = "tool", Trapping = "tool",
    Literature = "info", SkillBook = "info", Key = "info", Security = "info",
    Cartography = "info", Memento = "info",
    Material = "mat", Camping = "mat",
    Weapon = "wpn", WeaponCrafted = "wpn", Explosives = "wpn",
}

local function isType(sc, name)
    if not ItemType or not ItemType[name] then return false end
    local ok, yes = pcall(function() return sc:isItemType(ItemType[name]) end)
    return ok and yes == true
end

--- The editor's tab of an item's script: its bags, its clothing, else by Knox's category.
function P.sideOf(sc)
    if not sc then return "misc" end
    if isType(sc, "CONTAINER") then return "bag" end
    if isType(sc, "CLOTHING") then return "clo" end
    local s = SIDE_BY_DISPLAY[sc:getDisplayCategory() or ""]
    if s then return s end
    if isType(sc, "WEAPON") then return "wpn" end
    if isType(sc, "FOOD") then return "food" end
    if isType(sc, "LITERATURE") or isType(sc, "KEY") then return "info" end
    return "misc"
end

--- The ID of the mod an item's script comes from; nil for the game's own.
function P.modOf(sc)
    local ok, id = pcall(function() return sc:getModID() end)
    if not ok or not id or id == "" or id == "pz-vanilla" or id == "Base" then return nil end
    return id
end

--- Is an item (its script) one a preset of `scope` may hold?
function P.holds(scope, sc)
    local k, v = P.scopeOf(scope)
    if k == "all" then return true end
    if not sc then return false end
    if k == "tab" then return P.sideOf(sc) == v end
    return P.modOf(sc) == v
end

-- Lines ----------------------------------------------------------------------------

-- the parts of a line, each set or not as a whole by a layer
local GROUPS = {
    {"w", "h"}, {"cols", "rows", "parts", "mask"}, {"stack"}, {"pockets", "pocketsAll"}, {"cat"}, {"sound"},
}

--- `top`'s parts over `base`'s (a new table; either may be nil).
function P.over(base, top)
    if not top then return base end
    if not base then return top end
    local o = {}
    for k, v in pairs(base) do o[k] = v end
    for _, g in ipairs(GROUPS) do
        local has = false
        for _, k in ipairs(g) do if top[k] ~= nil then has = true end end
        if has then for _, k in ipairs(g) do o[k] = top[k] end end
    end
    return o
end

--- What a line sets, back to its text after "=" ("1x5 grid 5x6 stack 2").
function P.restOf(o)
    local t = {}
    if o.w then table.insert(t, o.w .. "x" .. o.h) end
    if o.mask then table.insert(t, "mask " .. o.mask)
    elseif o.parts then table.insert(t, "parts " .. o.parts)
    elseif o.cols then table.insert(t, "grid " .. o.cols .. "x" .. o.rows) end
    if o.stack then table.insert(t, "stack " .. o.stack) end
    if o.pockets then table.insert(t, (o.pocketsAll and "pockets.all " or "pockets ") .. o.pockets) end
    if o.cat then table.insert(t, "category " .. o.cat) end
    if o.sound then table.insert(t, "sound " .. o.sound) end
    return table.concat(t, " ")
end

--- A preset's text as read: {name, scope, items = {ft -> o}, n, bad = {{text, why}}, read}
--- (why: "bad" a line not understood). `lines`: a list of strings.
function P.parse(lines)
    local p = {name = nil, scope = "all", items = {}, n = 0, bad = {}, read = 0}
    for _, line in ipairs(lines or {}) do
        local name = string.match(line, "^%s*#%s*name%s*=%s*(.-)%s*$")
        local scope = string.match(line, "^%s*#%s*for%s*=%s*(.-)%s*$")
        if name and name ~= "" then
            p.name = name
        elseif scope then
            local k, v = string.match(scope, "^(%a+)%s+(.-)$")
            k = k and string.lower(k)
            if k == "tab" or k == "mod" then p.scope = k .. ":" .. v else p.scope = "all" end
        elseif not string.find(line, "^%s*#") and not string.find(line, "^%s*$") then
            p.read = p.read + 1
            local key, o = F.parseLine(line)
            if key and key ~= "show_ids" then
                if not p.items[key] then p.n = p.n + 1 end
                p.items[key] = o
            else
                table.insert(p.bad, {line, "bad"})
            end
        end
    end
    return p
end

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do table.insert(out, k) end
    table.sort(out)
    return out
end
P.sortedKeys = sortedKeys

--- A preset as its file's lines.
function P.text(p)
    local k, v = P.scopeOf(p.scope)
    local out = {P.HEADER, "# name = " .. (p.name or ""), "# for = " .. (k == "all" and "all" or (k .. " " .. v))}
    for _, ft in ipairs(sortedKeys(p.items)) do
        local rest = P.restOf(p.items[ft])
        if rest ~= "" then table.insert(out, ft .. " = " .. rest) end
    end
    return out
end

-- Files ------------------------------------------------------------------------------

local function readLines(name)
    local r = getFileReader and getFileReader(name, false)
    if not r then return nil end
    local out = {}
    local line = r:readLine()
    while line do
        table.insert(out, line)
        line = r:readLine()
    end
    r:close()
    return out
end
P.readLines = readLines

local function writeLines(name, lines)
    local w = getFileWriter and getFileWriter(name, true, false)
    if not w then return false end
    for _, l in ipairs(lines) do w:write(l .. "\r\n") end
    w:close()
    return true
end
P.writeLines = writeLines

--- A file name for a preset's name: the name, without what a file's name can't have.
function P.fileFor(name, store)
    local base = string.gsub(name or "preset", "[\\/:%*%?\"<>|%.%c]", "_")
    base = string.gsub(base, "^%s+", "")
    if base == "" or base == "index" then base = "preset" end
    local taken = {}
    for _, q in ipairs(store and store.list or {}) do taken[string.lower(q.file)] = true end
    local file, n = base .. ".txt", 1
    while taken[string.lower(file)] do
        n = n + 1
        file = base .. " " .. n .. ".txt"
    end
    return file
end

--- The files in knox_presets and when each was written: {{name, date}} (newest first),
--- or nil when the Java part can't list them (an older jar).
function P.listFiles()
    if not knoxPresetFiles then return nil end
    local ok, s = pcall(knoxPresetFiles)
    if not ok or type(s) ~= "string" then return nil end
    local out = {}
    for line in string.gmatch(s, "[^\n]+") do
        local name, date = string.match(line, "^(.-)\t(.*)$")
        if name and name ~= "index.txt" then table.insert(out, {name, date}) end
    end
    return out
end

-- A store: the presets of this game (the player's own, or the server's for its admin)
--   {list = {{file, name, scope, on, items, n}}, edit = file}

--- A store from the index's lines and the files' lines (by file name).
function P.storeFrom(indexLines, files)
    local store = {list = {}, edit = nil}
    for _, l in ipairs(indexLines or {}) do
        local file, flags = string.match(l, "^%s*preset%s*=%s*(.-%.txt)%s*(%a*)%s*$")
        local edit = string.match(l, "^%s*edit%s*=%s*(.-)%s*$")
        if file then
            local lines = files[file]
            if lines and #lines > 0 then
                local p = P.parse(lines)
                p.file, p.on = file, flags == "on"
                p.name = p.name or string.gsub(file, "%.txt$", "")
                table.insert(store.list, p)
            end
        elseif edit then
            store.edit = edit
        end
    end
    -- (one in use a kind: the general ones, each tab's, each mod's - the first wins)
    local seen = {}
    for _, p in ipairs(store.list) do
        if p.on then
            if seen[p.scope] then p.on = false else seen[p.scope] = true end
        end
    end
    if not P.find(store, store.edit) then store.edit = store.list[1] and store.list[1].file or nil end
    return store
end

function P.find(store, file)
    if not file then return nil end
    for i, p in ipairs(store.list) do
        if p.file == file then return p, i end
    end
    return nil
end

function P.indexLines(store)
    local out = {"# Knox Inventory: the item editor's presets - a line each: its file, \"on\" while in use;",
                 "# \"edit\": the one the editor writes to. Written by the editor."}
    for _, p in ipairs(store.list) do
        table.insert(out, "preset = " .. p.file .. (p.on and " on" or ""))
    end
    if store.edit then table.insert(out, "edit = " .. store.edit) end
    return out
end

--- The presets of this computer (Zomboid/Lua/knox_presets).
function P.loadLocal()
    local index = readLines(P.INDEX)
    if not index then return nil end
    local files = {}
    for _, l in ipairs(index) do
        local file = string.match(l, "^%s*preset%s*=%s*(.-%.txt)")
        if file then files[file] = readLines(P.DIR .. file) end
    end
    return P.storeFrom(index, files)
end

--- The first time: the lines of knox_overrides.txt become the preset "My preset", in
--- use (the file is kept as knox_overrides_backup.txt, its moved lines turned into
--- notes) - so the editor shows and changes them, and nothing goes over its edits.
function P.migrate()
    local store = {list = {}, edit = nil}
    local name = "My preset"
    if getText then
        local ok, s = pcall(getText, "IGUI_KnoxEd_MyPreset")
        if ok and s and s ~= "IGUI_KnoxEd_MyPreset" then name = s end
    end
    local p = {name = name, scope = "all", items = {}, n = 0, on = true}
    p.file = P.fileFor(name, store)
    local lines = readLines(F.OVERRIDES_FILE)
    if lines then
        local moved, out = 0, {}
        for _, l in ipairs(lines) do
            local key, o = F.parseLine(l)
            if key and key ~= "show_ids" then
                if not p.items[key] then p.n = p.n + 1 end
                p.items[key] = P.over(p.items[key], o)
                moved = moved + 1
                table.insert(out, "# (in the preset \"" .. name .. "\" now) " .. l)
            else
                table.insert(out, l)
            end
        end
        if moved > 0 then
            writeLines("knox_overrides_backup.txt", lines)
            writeLines(F.OVERRIDES_FILE, out)
            print("[Knox] presets: " .. moved .. " line(s) of " .. F.OVERRIDES_FILE .. " moved to " .. P.DIR .. p.file)
        end
    end
    table.insert(store.list, p)
    store.edit = p.file
    P.saveLocal(store, {[p.file] = true})
    return store
end

--- Write the store here: the index, and the presets named in `which` (file -> true),
--- or all of them; `gone`: files of presets taken away (emptied, or deleted by the Java part).
function P.saveLocal(store, which, gone)
    for _, p in ipairs(store.list) do
        if not which or which[p.file] then writeLines(P.DIR .. p.file, P.text(p)) end
    end
    for file in pairs(gone or {}) do
        local ok = knoxPresetDelete and pcall(knoxPresetDelete, file)
        if not ok then writeLines(P.DIR .. file, {}) end
    end
    writeLines(P.INDEX, P.indexLines(store))
end

-- Layers -------------------------------------------------------------------------------

--- Every item's lines in effect: the mod's defaults, then the presets in use, the
--- wider first, then the player's own file - each part over the one under it.
--- @return table ft -> o
function P.effective(store, handLines)
    local out = {}
    for ft, o in pairs(F.baseOverrides or {}) do out[ft] = o end
    local byRank = {{}, {}, {}}
    for _, p in ipairs(store and store.list or {}) do
        if p.on then table.insert(byRank[P.rank(p.scope) + 1], p) end
    end
    for _, list in ipairs(byRank) do
        for _, p in ipairs(list) do
            for ft, o in pairs(p.items) do out[ft] = P.over(out[ft], o) end
        end
    end
    for _, l in ipairs(handLines or {}) do
        local key, o = F.parseLine(l)
        if key and key ~= "show_ids" then out[key] = P.over(out[key], o) end
    end
    return out
end

--- The same as lines of knox_overrides.txt (what a server sends its players).
function P.effectiveLines(store, handLines, max)
    local eff = P.effective(store, handLines)
    local out = {}
    for _, ft in ipairs(sortedKeys(eff)) do
        local rest = P.restOf(eff[ft])
        if rest ~= "" then table.insert(out, ft .. " = " .. rest) end
        if max and #out >= max then break end
    end
    return out
end

P.store = nil   -- this computer's presets (loaded with the Lua)

--- Put the presets in effect: the items' sizes worked out anew, the grids on the
--- screen built again. (Alone; with others the server's lines are in effect -
--- KnoxNet.applyConfig - and this does nothing.)
function P.apply()
    if KnoxNet and KnoxNet.mp and KnoxNet.mp() then return end
    F.useOverrides(P.effectiveLines(P.store, F.handLines))
    if P.onApplied then P.onApplied() end
end

--- Read this computer's presets (the first time: made from knox_overrides.txt) and
--- put them in effect.
function P.init()
    if not getFileReader then return end
    local ok, store = pcall(P.loadLocal)
    if not ok then print("[Knox] presets: " .. tostring(store)) store = nil end
    if not store then
        local ok2, made = pcall(P.migrate)
        store = ok2 and made or {list = {}}
        if not ok2 then print("[Knox] presets: " .. tostring(made)) end
        -- (the player's file read again: its moved lines are notes now)
        if F.loadOverrides then F.loadOverrides() end
    end
    P.store = store
    P.apply()
end

if getFileReader and not (isServer and isServer()) then
    P.init()
end

return KnoxPresets
