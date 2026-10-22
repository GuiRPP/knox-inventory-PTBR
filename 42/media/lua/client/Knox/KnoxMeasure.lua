-- Developer tool (DEV panel > "Measure", or KnoxMeasure.run() in the Lua
-- console): writes down every item of the game with what its footprint in the
-- grid is to be worked out from - its kind, weight, how it is worn, and the real
-- size of its 3D models (the Java part's knoxMeasureModel: the mesh's box, no
-- texture loaded).
--
-- The result is Zomboid/Lua/knox_measure.txt, one item per line, fields split
-- by "|" (the first line names them). It is read outside the game to build the
-- mod's table of footprints; the mod itself never reads it.
--
-- A few steps per tick, so the game stays responsive (do not pause it: ticks
-- stop). Items are made with instanceItem and never put in the world.
-- No pcall probing: the game's debugger stops even on caught errors.

require "Knox/KnoxTheme"

KnoxMeasure = KnoxMeasure or {}
local M = KnoxMeasure

local FILE = "knox_measure.txt"
local ITEMS_PER_TICK = 60
local MODELS_PER_TICK = 25      -- new meshes asked for per tick
local MODEL_TIMEOUT_MS = 20000

local run = nil

function M.isRunning()
    return run ~= nil
end

--- 0..100 while it runs, nil otherwise.
function M.progress()
    if not run then return nil end
    if run.phase == "items" then
        return math.floor(40 * (run.index - 1) / math.max(1, #run.scripts))
    end
    local total = #run.modelList
    return 40 + math.floor(60 * run.modelsDone / math.max(1, total))
end

local function kind(item)
    if instanceof(item, "HandWeapon") then return "weapon" end
    if instanceof(item, "InventoryContainer") then return "container" end
    if instanceof(item, "Clothing") then return "clothing" end
    if instanceof(item, "Food") then return "food" end
    if instanceof(item, "Literature") then return "literature" end
    if instanceof(item, "Radio") then return "radio" end          -- (a Radio is a Moveable too)
    if instanceof(item, "Moveable") then return "moveable" end
    if item:IsDrainable() then return "drainable" end
    return "normal"
end

local function text(v)
    if v == nil then return "" end
    local s = tostring(v)
    s = string.gsub(s, "[|\r\n]", " ")
    return s
end

local function num(v)
    if type(v) ~= "number" then return "" end
    return string.format("%.3f", v)
end

--- The model script behind a model's name as items give it (with or without the module).
local function scriptName(name)
    if not name or name == "" then return nil end
    local sm = getScriptManager()
    local ms = sm:getModelScript(name)
    if not ms and not string.find(name, "%.") then ms = sm:getModelScript("Base." .. name) end
    return ms and ms:getFullType() or nil
end

local function wantModel(name)
    local full = scriptName(name)
    if not full then return "" end
    if run.models[full] == nil then
        run.models[full] = false          -- false: not asked for yet
        table.insert(run.modelList, full)
    end
    return full
end

local function readItem(script)
    local fullType = script:getFullName()
    local item = instanceItem(fullType)
    if not item then
        run.failed = run.failed + 1
        return
    end
    local k = kind(item)
    local rec = {
        fullType = fullType,
        kind = k,
        category = text(item:getDisplayCategory()),
        weight = num(item:getWeight()),
        actual = num(item:getActualWeight()),
        hidden = script:isHidden() and "1" or "",
        drain = item:IsDrainable() and "1" or "",
        fluid = "",
        capacity = "", reduction = "", worn = "",
        twoHand = "", ranged = "", attach = text(item:getAttachmentType()),
        world = wantModel(item:getWorldStaticModel()),
        static = wantModel(item:getStaticModel()),
        sprite = "",
    }
    local fc = item:getFluidContainer()
    if fc then rec.fluid = num(fc:getCapacity()) end
    if k == "weapon" then
        rec.twoHand = item:isTwoHandWeapon() and "1" or ""
        rec.ranged = item:isRanged() and "1" or ""
        rec.sprite = wantModel(item:getWeaponSprite())
    elseif k == "container" then
        local inv = item:getInventory()
        if inv then rec.capacity = num(inv:getCapacity()) end
        rec.reduction = num(item:getWeightReduction())
        rec.worn = text(item:canBeEquipped())
    elseif k == "clothing" then
        rec.worn = text(item:getBodyLocation())
    end
    if rec.worn == "" and item.canBeEquipped then rec.worn = text(item:canBeEquipped()) end
    table.insert(run.records, rec)
end

local FIELDS = {"fullType", "kind", "category", "weight", "actual", "hidden", "drain", "fluid", "capacity",
                "reduction", "worn", "twoHand", "ranged", "attach", "world", "worldSize", "static", "staticSize",
                "sprite", "spriteSize"}

local function sizeOf(name)
    if name == "" then return "" end
    local v = run.models[name]
    if type(v) == "string" then return v end
    return ""
end

local function finish()
    local w = getFileWriter(FILE, true, false)
    if not w then
        print("[Knox] MEASURE could not write " .. FILE)
        run = nil
        return
    end
    w:write("# Knox Inventory item measure, game " .. tostring(getCore():getVersion()) .. "\r\n")
    w:write(table.concat(FIELDS, "|") .. "\r\n")
    local measured = 0
    for _, r in ipairs(run.records) do
        r.worldSize, r.staticSize, r.spriteSize = sizeOf(r.world), sizeOf(r.static), sizeOf(r.sprite)
        if r.worldSize ~= "" or r.staticSize ~= "" or r.spriteSize ~= "" then measured = measured + 1 end
        local parts = {}
        for i, f in ipairs(FIELDS) do parts[i] = r[f] or "" end
        w:write(table.concat(parts, "|") .. "\r\n")
    end
    w:write("# DONE items=" .. #run.records .. " measured=" .. measured .. " models=" .. #run.modelList
        .. " modelsFailed=" .. run.modelsFailed .. " itemsFailed=" .. run.failed .. "\r\n")
    w:close()
    local msg = "items " .. #run.records .. ", with a measured model " .. measured .. ", models " .. #run.modelList
        .. " (failed " .. run.modelsFailed .. ")"
    print("[Knox] MEASURE done: " .. msg .. " -> Zomboid/Lua/" .. FILE)
    M.last = msg
    run = nil
end

local function stepModels()
    local now = getTimestampMs()
    -- ask for more meshes
    local started = 0
    while run.nextModel <= #run.modelList and started < MODELS_PER_TICK and #run.pending < MODELS_PER_TICK * 4 do
        local name = run.modelList[run.nextModel]
        run.nextModel = run.nextModel + 1
        table.insert(run.pending, {name = name, since = now})
        started = started + 1
    end
    -- look at the ones asked for
    local still = {}
    for _, p in ipairs(run.pending) do
        local s = knoxMeasureModel(p.name)
        if s == "loading" and now - p.since < MODEL_TIMEOUT_MS then
            table.insert(still, p)
        else
            if s == nil or s == "loading" then
                run.models[p.name] = true     -- true: no size (not static, failed, or too slow)
                run.modelsFailed = run.modelsFailed + 1
            else
                run.models[p.name] = s
            end
            run.modelsDone = run.modelsDone + 1
        end
    end
    run.pending = still
    if run.nextModel > #run.modelList and #run.pending == 0 then finish() end
end

local function onTick()
    if not run then return end
    if run.phase == "items" then
        local last = math.min(#run.scripts, run.index + ITEMS_PER_TICK - 1)
        for i = run.index, last do readItem(run.scripts[i]) end
        run.index = last + 1
        if run.index > #run.scripts then
            run.phase = "models"
            print("[Knox] MEASURE items read: " .. #run.records .. ", models to measure: " .. #run.modelList)
        end
    else
        stepModels()
    end
end

function M.run()
    if run then return end
    if not knoxMeasureModel then
        print("[Knox] MEASURE needs the Java part's knoxMeasureModel (restart the game after updating)")
        M.last = "the Java part is too old: restart the game"
        return
    end
    local scripts = {}
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local s = all:get(i)
        if not s:getObsolete() then table.insert(scripts, s) end
    end
    run = {phase = "items", scripts = scripts, index = 1, records = {}, failed = 0,
           models = {}, modelList = {}, nextModel = 1, pending = {}, modelsDone = 0, modelsFailed = 0}
    M.last = nil
    print("[Knox] MEASURE started: " .. #scripts .. " item scripts")
end

Events.OnTick.Add(onTick)

return KnoxMeasure
