-- The test bench: a window that walks the author through the new things of a
-- release one by one. Each point says what to do and what should happen, has
-- buttons that set the scene up (a test backpack with a mess in it, a pile on
-- the floor, a line in a file) and, where it can, a check that reads the
-- result from the grids. The author marks each point "works" / "broken" and
-- may write a note; all of it goes to Zomboid/Lua/knox_testbench.txt for
-- Claude to read.
--
-- Opened by the DEV button of the Knox screen. The button is there when the
-- game runs with -debug, or in DEV mode: Insert switches it on and opens the
-- bench (knox_settings.txt dev=1), no -debug needed - on a computer
-- that has Zomboid/Lua/knox_dev.txt (any content) only.
--
-- Everything it makes is marked (modData knoxBench) and "Clean up" takes it away.

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxOrder"

KnoxTestBench = ISPanel:derive("KnoxTestBench")
local B = KnoxTestBench
local T = KnoxTheme
local REPORT = "knox_testbench.txt"
local RELEASE = "1.0 BETA"

B.state = B.state or {}   -- id -> {verdict = "ok" | "bad", auto, autoOk, note}
B.dumped = B.dumped or {}
B.taken = B.taken or {}

-- The test backpack's contents: {full type, how many, own stacks}. Things a
-- game version lacks are left out.
local MESS = {
    {"Base.Axe", 1}, {"Base.KitchenKnife", 1},
    {"Base.Bullets9mm", 12},
    {"Base.Bandage", 2, true}, {"Base.Bandage", 2, true}, {"Base.Pills", 1}, {"Base.PillsBeta", 1},
    {"Base.TinnedBeans", 2}, {"Base.Crisps", 1}, {"Base.Apple", 2}, {"Base.WaterBottle", 1},
    {"Base.Hammer", 1}, {"Base.Screwdriver", 1}, {"Base.HandTorch", 1},
    {"Base.Nails", 10, true}, {"Base.Nails", 10, true}, {"Base.DuctTape", 1},
    {"Base.Tshirt_DefaultTEXTURE", 1}, {"Base.Socks_Ankle", 1},
    {"Base.Book", 1}, {"Base.Magazine", 1},
    {"Base.Spoon", 1}, {"Base.Pencil", 1},
}
local BAG = "Base.Bag_ALICEpack"

local function exists(ft) return getScriptManager():FindItem(ft) ~= nil end

local function tag(item)
    if item then item:getModData().knoxBench = true end
    return item
end

local function halo(player, key, ...)
    if player and HaloTextHelper and HaloTextHelper.addGoodText then
        HaloTextHelper.addGoodText(player, getText(key, ...))
    end
end

local function dirtyAll()
    if KnoxScreen and KnoxScreen.instance then KnoxScreen.instance:markAllDirty() end
    if KnoxActions then
        for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
    end
end

-- The test backpack ----------------------------------------------------------------

function B.bag(player)
    if not player then return nil end
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it:getModData().knoxBenchBag then return it end
    end
    return nil
end

--- The backpack's grid: the one on the screen if it is there, else built now.
function B.layout(player)
    local bag = B.bag(player)
    if not bag then return nil end
    local inv = bag:getInventory()
    if KnoxActions then
        for _, v in ipairs(KnoxActions.allViews()) do
            if v.container == inv then
                v:rebuild()
                return v.layout, v
            end
        end
    end
    return KnoxGrid.build(inv, player), nil
end

--- Every tile of the backpack to a random place (a mess to sort).
function B.shuffle(player)
    local bag = B.bag(player)
    if not bag then return end
    local L = KnoxGrid.build(bag:getInventory(), player)
    local fresh = KnoxGrid.emptyLike(L)
    local tiles = {}
    for _, e in ipairs(L.placed) do
        if not e.ghost and not e.reserved then table.insert(tiles, e) end
    end
    for i = #tiles, 2, -1 do
        local j = ZombRand(i) + 1
        tiles[i], tiles[j] = tiles[j], tiles[i]
    end
    for _, e in ipairs(tiles) do
        local done = false
        for _ = 1, 80 do
            local r = ZombRand(2)
            local w, h = KnoxGrid.dims(e, r)
            local x, y = ZombRand(math.max(1, fresh.cols - w + 1)), ZombRand(math.max(1, fresh.baseRows - h + 1))
            if fresh:fits(x, y, w, h) then
                fresh:occupy(e, x, y, r)
                KnoxGrid.writePlace(e, L.key, x, y, r)
                done = true
                break
            end
        end
        if not done then
            local x, y, r = fresh:findFree(e)
            if x then
                fresh:occupy(e, x, y, r)
                KnoxGrid.writePlace(e, L.key, x, y, r)
            end
        end
    end
    dirtyAll()
end

function B.prepare(player, playerNum)
    local bag = B.bag(player)
    if not bag then
        local ft
        for _, b in ipairs({BAG, "Base.Bag_BigHikingBag", "Base.Bag_NormalHikingBag"}) do
            if not ft and exists(b) then ft = b end
        end
        if not ft then return end
        bag = tag(player:getInventory():AddItem(ft))
        if not bag then return end
        bag:getModData().knoxBenchBag = true
        local inv = bag:getInventory()
        for _, m in ipairs(MESS) do
            if exists(m[1]) then
                -- (some as stacks of their own: Sort must put them together)
                local stack = m[3] and KnoxGrid.newStackId() or nil
                for _ = 1, m[2] do
                    local it = tag(inv:AddItem(m[1]))
                    if it and stack then it:getModData().knoxS = stack end
                end
            end
        end
        if not player:getClothingItem_Back() then
            KnoxEquip.wearItem(player, bag, nil)
        else
            halo(player, "IGUI_KnoxTB_BackBusy")
            if KnoxContainerWindow then KnoxContainerWindow.toggle(bag, playerNum) end
        end
    end
    B.shuffle(player)
end

--- Three things out of the backpack into the pockets (their layout places stay empty).
function B.take3(player)
    local bag = B.bag(player)
    if not bag then return end
    local L = KnoxGrid.build(bag:getInventory(), player)
    local seen, n = {}, 0
    B.taken = {}
    for _, e in ipairs(L.placed) do
        local ft = e.item:getFullType()
        if n < 3 and not e.ghost and not e.reserved and not seen[ft] and not KnoxActions.isLocked(e) then
            seen[ft] = true
            n = n + 1
            for _, it in ipairs(e.items) do
                bag:getInventory():Remove(it)
                player:getInventory():AddItem(it)
                table.insert(B.taken, it)
            end
        end
    end
    dirtyAll()
end

--- Those three back into the backpack without a place picked (as a pickup does).
function B.back3(player)
    local bag = B.bag(player)
    if not bag then return end
    for _, it in ipairs(B.taken) do
        local c = it:getContainer()
        if c and c ~= bag:getInventory() then
            c:Remove(it)
            local md = it:getModData()
            md.knox, md.knoxP = nil, nil
            bag:getInventory():AddItem(it)
        end
    end
    B.taken = {}
    dirtyAll()
end

function B.addHammer(player)
    local bag = B.bag(player)
    if not bag or not exists("Base.Hammer") then return end
    B.hammer = tag(bag:getInventory():AddItem("Base.Hammer"))
    dirtyAll()
end

--- 300 things on the floor around the character.
function B.dump(player)
    local sq = player:getCurrentSquare()
    if not sq then return end
    local types = {}
    for _, m in ipairs(MESS) do
        if exists(m[1]) then table.insert(types, m[1]) end
    end
    if #types == 0 then return end
    for _ = 1, 300 do
        local s = getCell():getGridSquare(sq:getX() + ZombRand(3) - 1, sq:getY() + ZombRand(3) - 1, sq:getZ())
        if s and s:isFree(false) then
            local it = s:AddWorldInventoryItem(types[ZombRand(#types) + 1], ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
            if it then table.insert(B.dumped, tag(it)) end
        end
    end
    dirtyAll()
end

local function removeFromFloor(it)
    local wi = it:getWorldItem()
    if not wi then return end
    local sq = wi:getSquare()
    if sq then sq:transmitRemoveItemFromSquare(wi) end
    wi:removeFromWorld()
    wi:removeFromSquare()
end

function B.clearDump()
    for _, it in ipairs(B.dumped) do removeFromFloor(it) end
    B.dumped = {}
    dirtyAll()
end

-- Two bodies on one square (Sharp's report, 2026-10-15: a move queued from one
-- container showed faded copies of its things in another one). Containers of
-- one type on one square share a grid key ("w x,y,z,type"), and a move's source
-- is told by that key. Bodies are made until two on the square share it.
B.bodies = B.bodies or {}

local function bodyKey(body, player)
    local c = body and body:getContainer()
    return c and KnoxGrid.containerKey(c, player)
end

function B.removeBodies()
    for _, b in ipairs(B.bodies) do
        local sq = b:getSquare()
        if sq then sq:removeCorpse(b, false) end
    end
    B.bodies = {}
    dirtyAll()
end

function B.twoBodies(player)
    B.removeBodies()
    local at = player:getCurrentSquare()
    if not at or not createRandomDeadBody then return end
    local sq = getCell():getGridSquare(at:getX() + 1, at:getY(), at:getZ())
    if not sq or not sq:isFree(false) then sq = at end
    local byKey = {}
    for _ = 1, 8 do
        local b = createRandomDeadBody(sq, 0)
        if b then
            table.insert(B.bodies, b)
            local k = bodyKey(b, player)
            if k and byKey[k] then
                -- a pair: the other bodies go
                local pair = {byKey[k], b}
                for _, o in ipairs(B.bodies) do
                    if o ~= pair[1] and o ~= pair[2] then sq:removeCorpse(o, false) end
                end
                B.bodies = pair
                break
            end
            if k then byKey[k] = b end
        end
    end
    if #B.bodies ~= 2 then
        B.removeBodies()
        return
    end
    local stuff = {{"Base.Axe", "Base.Crowbar", "Base.Sledgehammer", "Base.Hammer"},
                   {"Base.Apple", "Base.Apple", "Base.Pencil"}}
    for i, b in ipairs(B.bodies) do
        local c = b:getContainer()
        for _, ft in ipairs(stuff[i]) do
            if exists(ft) then tag(c:AddItem(ft)) end
        end
        -- looked into: the search doesn't hide them
        if KnoxLootPanel and KnoxLootPanel.markSeen then KnoxLootPanel.markSeen(c) end
        if KnoxSearch then KnoxSearch.markIn(c) end
    end
    dirtyAll()
end

--- A generator in both hands, as the game carries it (Khudoz's report: put
--- into a car's trunk, it fell to the ground).
function B.generator(player)
    local ft = exists("Base.Generator") and "Base.Generator" or nil
    if not ft then return end
    local it = tag(player:getInventory():AddItem(ft))
    if not it then return end
    player:setPrimaryHandItem(it)
    player:setSecondaryHandItem(it)
    triggerEvent("OnClothingUpdated", player)
    dirtyAll()
end

--- A pot of tainted water in the pockets, to be boiled on a stove (the heat tint).
function B.waterPot(player)
    if not exists("Base.Pot") then return end
    local it = tag(player:getInventory():AddItem("Base.Pot"))
    local fc = it and it:getFluidContainer()
    if fc then pcall(function() fc:addFluid(FluidType.TaintedWater, fc:getCapacity()) end) end
    dirtyAll()
end

--- The test ALICE pack on the back (it gives the "bottom of the backpack" slot)
--- and a packed tent on the floor by the character (a player's report, 2026-10-15:
--- picked up, the tent hung itself on that slot and was nowhere to be seen).
function B.tent(player, playerNum)
    B.prepare(player, playerNum)
    local ft = exists("Base.CampingTentKit2_Packed") and "Base.CampingTentKit2_Packed" or nil
    local sq = player:getCurrentSquare()
    if not ft or not sq then return end
    local it = sq:AddWorldInventoryItem(ft, 0.5, 0.5, 0)
    if it then table.insert(B.dumped, tag(it)) end
    dirtyAll()
end

--- A car with a lockable trunk (its button: part TruckBed - a pickup's open bed has
--- none, in the game too) a few steps east, repaired, its key in the pocket, the
--- tank nearly dry (the fuel gauge's pump lit) - for the Knox dashboard's sedan.
--- `script`: another car (the pickup: the dashboard's other body).
function B.car(player, script)
    local sq = player:getCurrentSquare()
    local at = sq and getCell():getGridSquare(sq:getX() + 4, sq:getY(), sq:getZ())
    if not at then return end
    pcall(function()
        local car = addVehicleDebug(script or "Base.CarNormal", IsoDirections.S, nil, at)
        if not car then return end
        car:repair()
        player:getInventory():AddItem(car:createVehicleKey())
        local gas = car:getPartById("GasTank")
        if gas and gas:isContainer() then gas:setContainerContentAmount(gas:getContainerCapacity() * 0.12) end
    end)
    dirtyAll()
end

--- The dashboard's states on the car the player sits in: night (the scales' backlight
--- with the headlights), the tank at 4 % (the pump red and pulsing), hot-wired (the
--- key out, the wires in the lock).
function B.night() pcall(function() getGameTime():setTimeOfDay(23.0) end) end
function B.day() pcall(function() getGameTime():setTimeOfDay(12.0) end) end
function B.dry(player)
    local car = player:getVehicle()
    local gas = car and car:getPartById("GasTank")
    if gas and gas:isContainer() then gas:setContainerContentAmount(gas:getContainerCapacity() * 0.04) end
end
function B.hotwire(player)
    local car = player:getVehicle()
    if not car then return end
    pcall(function()
        if car:isEngineRunning() then car:shutOff() end
        car:setKeysInIgnition(false)
        car:setHotwired(true)
    end)
end

--- The generator window (2026-10-22): a generator two squares east - connected, the tank
--- at 62 %, condition 82 % (the mockup's) - and a full can of gasoline in the pockets;
--- the nearest generator worn, new, or with a nearly dry tank.
function B.nearGenerator(player)
    local w = KnoxGeneratorWindow and KnoxGeneratorWindow.instance
    if w and w.gen then return w.gen end
    local sq = player:getCurrentSquare()
    if not sq then return nil end
    for dx = -3, 3 do
        for dy = -3, 3 do
            local s = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            local objs = s and s:getObjects()
            for i = 0, (objs and objs:size() or 0) - 1 do
                local o = objs:get(i)
                if instanceof(o, "IsoGenerator") then return o end
            end
        end
    end
    return nil
end
function B.genPlaced(player)
    local sq = player:getCurrentSquare()
    local at = sq and getCell():getGridSquare(sq:getX() + 2, sq:getY(), sq:getZ())
    if not at then return end
    pcall(function()
        local gen = IsoGenerator.new(instanceItem("Base.Generator"), getCell(), at)
        gen:setConnected(true)
        gen:setFuel(gen:getMaxFuel() * 0.62)
        gen:setCondition(82)
        local can = player:getInventory():AddItem("Base.PetrolCan")
        local fc = can and can:getFluidContainer()
        if fc then fc:addFluid(Fluid.Petrol, fc:getCapacity()) end
        tag(can)
    end)
    dirtyAll()
end
function B.genCondition(player, c)
    local gen = B.nearGenerator(player)
    if gen then gen:setCondition(c) end
end
function B.genDry(player)
    local gen = B.nearGenerator(player)
    if gen then gen:setFuel(gen:getMaxFuel() * 0.07) end
end

--- The health tab: one wound a button (the author, 2026-10-19: all at once left no
--- time to see what each part of the tab does), through the game's own debug
--- switches (ISHealthPanel.onCheat), and with it what treats it, into the pockets
--- (what is carried already is not given twice). The game's switches toggle: one
--- already there is left as it is. No bite (it would turn the character for real).
--- Destroyed: the right foot at 0 - its zone, the right leg (only the foot: the game
--- takes each part's loss, weighted, from the overall health; the whole leg could kill).
local WOUND_SCENES = {
    {id = "Scratch", part = "ForeArm_L", cheats = {"scratched"}, kit = {"Base.Bandage", "Base.Disinfectant"}},
    {id = "Bleed", part = "ForeArm_R", cheats = {"cut", "bleeding"}, kit = {"Base.Bandage", "Base.Bandage"}},
    {id = "Deep", part = "UpperArm_L", cheats = {"deepWound"},
     kit = {"Base.SutureNeedle", "Base.Needle", "Base.Thread", "Base.Disinfectant", "Base.Bandage"}},
    {id = "Glass", part = "Hand_R", cheats = {"glass"}, kit = {"Base.Tweezers", "Base.Bandage"}},
    {id = "Fracture", part = "UpperLeg_L", cheats = {"fracture"}, kit = {"Base.Splint", "Base.ComfreyCataplasm"}},
    {id = "Burn", part = "Head", cheats = {"burned", "burnWash"}, kit = {"Base.RippedSheets", "Base.Bandage"}},
    {id = "Bullet", part = "Groin", cheats = {"bullet"}, kit = {"Base.Tweezers", "Base.Bandage"}},
    {id = "Cut", part = "Torso_Lower", cheats = {"cut"}, kit = {"Base.Bandage", "Base.Disinfectant", "Base.PlantainCataplasm"}},
    {id = "Infect", part = "LowerLeg_L", cheats = {"scratched", "infected"},
     kit = {"Base.Disinfectant", "Base.WildGarlicCataplasm", "Base.Antibiotics", "Base.Bandage"}},
    {id = "Destroy", part = "Foot_R", zero = true, kit = {"Base.Pills"}},
}
-- is the game's switch on already (they toggle)?
local HAS = {
    scratched = function(bp) return bp:scratched() end,
    cut = function(bp) return bp:isCut() end,
    bleeding = function(bp) return bp:getBleedingTime() > 0 end,
    deepWound = function(bp) return bp:getDeepWoundTime() > 0 end,
    glass = function(bp) return bp:haveGlass() end,
    fracture = function(bp) return bp:getFractureTime() > 0 end,
    burned = function(bp) return bp:getBurnTime() > 0 end,
    burnWash = function(bp) return bp:isNeedBurnWash() end,
    bullet = function(bp) return bp:haveBullet() end,
    infected = function(bp) return bp:isInfectedWound() end,
}

local function partNamed(player, name)
    local bps = player:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do
        if BodyPartType.ToString(BodyPartType.FromIndex(i)) == name then return bps:get(i) end
    end
    return nil
end

--- What treats it, into the pockets: as many of each as the scene names, less what is carried.
local function giveKit(player, list)
    local want = {}
    for _, ft in ipairs(list) do want[ft] = (want[ft] or 0) + 1 end
    for ft, n in pairs(want) do
        if exists(ft) then
            local have = 0
            pcall(function() have = player:getInventory():getCountTypeRecurse(ft) end)
            for _ = have + 1, n do tag(player:getInventory():AddItem(ft)) end
        end
    end
    dirtyAll()
end

function B.wound(player, id)
    for _, w in ipairs(WOUND_SCENES) do
        if w.id == id then
            local bp = partNamed(player, w.part)
            if bp then
                if w.zero then pcall(function() bp:SetHealth(0) end) end
                for _, what in ipairs(w.cheats or {}) do
                    local has = HAS[what]
                    local ok, on = pcall(has, bp)
                    if not (ok and on) then pcall(ISHealthPanel.onCheat, bp, what, player, nil) end
                end
            end
            giveKit(player, w.kit or {})
        end
    end
end

--- All the wounds at once (and all their things).
function B.wounds(player)
    for _, w in ipairs(WOUND_SCENES) do B.wound(player, w.id) end
end

local function woundActions()
    local list = {}
    for _, w in ipairs(WOUND_SCENES) do
        table.insert(list, {"W_" .. w.id, function(p) B.wound(p, w.id) end})
    end
    table.insert(list, {"Wounds", function(p) B.wounds(p) end})
    table.insert(list, {"Heal", function(p) B.heal(p) end})
    return list
end

--- The health tab's 3D skeleton: any part broken, one a button (the author, 2026-10-19:
--- only the left thigh could be broken, the rest of the skeleton was not to be seen).
--- A broken part under the mouse goes see-through and shows its broken bone.
local BONE_PARTS = {"Head", "Neck", "Torso_Upper", "Torso_Lower", "Groin",
                    "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R",
                    "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R"}

function B.fracture(player, part)
    local bp = partNamed(player, part)
    if bp and not HAS.fracture(bp) then pcall(ISHealthPanel.onCheat, bp, "fracture", player, nil) end
    giveKit(player, {"Base.Splint"})
end

local function boneActions()
    local list = {}
    for _, part in ipairs(BONE_PARTS) do
        table.insert(list, {"F_" .. part, function(p) B.fracture(p, part) end})
    end
    table.insert(list, {"Fractures", function(p) for _, part in ipairs(BONE_PARTS) do B.fracture(p, part) end end})
    table.insert(list, {"Heal", function(p) B.heal(p) end})
    return list
end

local function checkFractures(player)
    local n = 0
    local bps = player:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do
        if bps:get(i):getFractureTime() > 0 then n = n + 1 end
    end
    return n >= 1, getText("IGUI_KnoxTB_Res_Fractures", n)
end

--- A kit for the health tab: what treats every wound above.
local KIT = {"Base.Bandage", "Base.Bandage", "Base.AlcoholBandage", "Base.RippedSheets", "Base.RippedSheets",
             "Base.Disinfectant", "Base.Needle", "Base.Thread", "Base.SutureNeedle", "Base.Tweezers", "Base.Splint",
             "Base.Pills", "Base.PillsAntiDep", "Base.PlantainCataplasm", "Base.ComfreyCataplasm"}
function B.kit(player)
    for _, ft in ipairs(KIT) do
        if exists(ft) then tag(player:getInventory():AddItem(ft)) end
    end
    dirtyAll()
end

--- Everything healed again (the game's "full health" of the whole body).
function B.heal(player)
    pcall(function() player:getBodyDamage():RestoreToFullHealth() end)
    local md = player:getModData()
    md.KnoxHeal = nil
end

local function checkHealthTab()
    local s = KnoxScreen and KnoxScreen.instance
    local ok = s ~= nil and s.tab == "Health" and s.health ~= nil and s.health:getIsVisible()
    return ok, getText(ok and "IGUI_KnoxTB_Res_HealthKnox" or "IGUI_KnoxTB_Res_HealthNo")
end

local function checkHealthWounds(player)
    local H = KnoxHealthData
    if not H then return false, "KnoxHealthData" end
    local destroyed, hurt = 0, 0
    for _, z in ipairs(H.ZONES) do
        if H.zoneState(player, z).destroyed then destroyed = destroyed + 1 end
        if H.zoneSev(player, z) > 0 then hurt = hurt + 1 end
    end
    return destroyed + hurt >= 1, getText("IGUI_KnoxTB_Res_HealthZones", hurt, destroyed)
end

local function checkDash()
    local d = KnoxDashboard and KnoxDashboard.instance
    local ok = d ~= nil and d.shownAt ~= nil and d:getIsVisible()
    return ok, getText(ok and "IGUI_KnoxTB_Res_DashKnox" or "IGUI_KnoxTB_Res_DashNo")
end

--- Own music shared in a game with others (KnoxMusicNet): has the server answered,
--- what this player shares, hears, fetches.
local function checkMusicNet()
    local MN = KnoxMusicNet
    if not MN or not MN.client() or not knoxNetHash then return false, getText("IGUI_KnoxTB_Res_MusicNetNo") end
    local answered, share, own, heard, playing, dls = MN.status()
    return answered and share == true, getText("IGUI_KnoxTB_Res_MusicNet",
        answered and (share and "share=1" or "share=0") or "-", tostring(own), heard .. " (" .. playing .. ")", tostring(dls))
end

--- Everything the bench made: off the floor, out of the pockets and bags, the backpack too.
function B.cleanup(player)
    B.clearDump()
    B.removeBodies()
    if not player then return end
    local function walk(inv, depth)
        local items = inv:getItems()
        local gone = {}
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it:getModData().knoxBench then
                table.insert(gone, it)
            elseif depth < 3 and instanceof(it, "InventoryContainer") and it:getInventory() then
                walk(it:getInventory(), depth + 1)
            end
        end
        for _, it in ipairs(gone) do
            if it:isEquipped() or player:isEquipped(it) then player:removeWornItem(it) end
            if player:getPrimaryHandItem() == it then player:setPrimaryHandItem(nil) end
            if player:getSecondaryHandItem() == it then player:setSecondaryHandItem(nil) end
            inv:Remove(it)
        end
    end
    walk(player:getInventory(), 0)
    triggerEvent("OnClothingUpdated", player)
    B.taken = {}
    dirtyAll()
end

--- Stacks for the quick move and the stack lights: 3 bandages in the pockets
--- (one stack), 2 more on the floor by the character.
function B.bandages(player)
    if not exists("Base.Bandage") then return end
    local stack = KnoxGrid.newStackId()
    for _ = 1, 3 do
        local it = tag(player:getInventory():AddItem("Base.Bandage"))
        if it then it:getModData().knoxS = stack end
    end
    local sq = player:getCurrentSquare()
    for _ = 1, 2 do
        local it = sq and sq:AddWorldInventoryItem("Base.Bandage", ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0)
        if it then table.insert(B.dumped, tag(it)) end
    end
    dirtyAll()
end

local function readLines(file)
    local out = {}
    local r = getFileReader(file, false)
    if not r then return out end
    local line = r:readLine()
    while line do
        table.insert(out, line)
        line = r:readLine()
    end
    r:close()
    return out
end

-- Checks: read the result from the grids -------------------------------------------

local function noBag() return false, getText("IGUI_KnoxTB_Res_NoBag") end

local function checkFloor()
    local s = KnoxScreen and KnoxScreen.instance
    local v = s and s.loot and s.loot.view
    if not v or not v.container or v.container:getType() ~= "floor" then return false, getText("IGUI_KnoxTB_Res_NoFloor") end
    -- averaged over the frames since the last check (or since the floor was opened)
    local n = math.max(1, v.profN or 0)
    local per = function(ms) return string.format("%.2f", (ms or 0) / n) end
    local fps = getAverageFPS and getAverageFPS() or 0
    local ok = ((v.profR or 0) + (v.profB or 0)) / n < 1.0
    -- (getText takes four values at most: two lines)
    local text = getText("IGUI_KnoxTB_Res_FloorCost", per(v.profR), per(v.profB), tostring(v.buildCost or 0)) .. ". "
        .. getText("IGUI_KnoxTB_Res_FloorFps", tostring(#v.layout.placed), tostring(math.floor(fps)), tostring(n))
    v.profR, v.profB, v.profN = 0, 0, 0
    return ok, text
end

-- The big check-up (2026-10-21): what it changed --------------------------------------

--- The Java part of this release (v57: the fonts without a name built per draw).
local function checkJava()
    local v = knoxJavaVersion and tonumber(knoxJavaVersion()) or nil
    local ok = v ~= nil and v >= 57 and T.active == true and T.javaFonts == true
    return ok, getText("IGUI_KnoxTB_Res_Java", tostring(v or "-"), tostring(T.active), tostring(T.javaFonts))
end

--- Things on their way now and the FPS (pressed while they move); the floor's costs too.
local function checkMoving()
    local n = 0
    for _ in pairs(KnoxGrid.pending or {}) do n = n + 1 end
    local fps = getAverageFPS and math.floor(getAverageFPS()) or 0
    local text = getText("IGUI_KnoxTB_Res_Moving", n, fps)
    local floorOk, floorText = checkFloor()
    if floorOk ~= nil and KnoxScreen and KnoxScreen.instance and KnoxScreen.instance.loot and KnoxScreen.instance.loot.view then
        text = text .. ". " .. floorText
    end
    return n >= 10 and fps >= 60, text
end

--- Has the test backpack a layout (the eye on its header)?
local function checkEye(player)
    local bag = B.bag(player)
    if not bag then return noBag() end
    local has = KnoxOrder.layoutOf(bag:getInventory()) ~= nil
    return true, getText(has and "IGUI_KnoxTB_Res_EyeYes" or "IGUI_KnoxTB_Res_EyeNo")
end

--- The generator by the character, and whether the Knox window is open on it.
local function checkGen(player)
    local gen = B.nearGenerator(player)
    if not gen then return false, getText("IGUI_KnoxTB_Res_GenNone") end
    local w = KnoxGeneratorWindow and KnoxGeneratorWindow.instance
    local open = w ~= nil and w.gen == gen
    local state = (gen:isActivated() and "running" or "stopped") .. (gen:isConnected() and ", connected" or ", not connected")
    return open, getText("IGUI_KnoxTB_Res_Gen", tostring(open), string.format("%.1f", gen:getFuel()), tostring(gen:getCondition()), state)
end

-- 1.0 BETA ---------------------------------------------------------------------------

--- On the floor by the character: what the beta stacks and splits - feathers,
--- seeds, tufts of grass (one stack each), two magazines (one full, one empty:
--- two stacks), a key ring and three keys (Shift+click puts a key on the ring).
local BETA_PILE = {{"Base.ChickenFeather", 12}, {"Base.BasilSeed", 10}, {"Base.GrassTuft", 6},
                   {"Base.9mmClip", 2}, {"Base.KeyRing", 1}, {"Base.Key1", 3}}
function B.betaPile(player)
    local sq = player:getCurrentSquare()
    if not sq then return end
    local clips = 0
    for _, m in ipairs(BETA_PILE) do
        if exists(m[1]) then
            for _ = 1, m[2] do
                local it = sq:AddWorldInventoryItem(m[1], ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0)
                if it then
                    table.insert(B.dumped, tag(it))
                    if m[1] == "Base.9mmClip" then
                        clips = clips + 1
                        if clips == 1 then pcall(function() it:setCurrentAmmoCount(it:getMaxAmmo()) end) end
                    end
                end
            end
        end
    end
    dirtyAll()
end

-- The points -----------------------------------------------------------------------

-- (2026-10-20: the beta's first run in the game. The points marked "works" for
-- 0.9.8 - rig_*, menu_new, near_same, tv_back, layers_back - and the health tab,
-- hidden until 2.0, are left out; their marks: Zomboid/Lua/knox_testbench_0987.txt)
-- (2026-10-21, the big check-up: its points on top; the beta's points marked
-- "works" by the author on 21.10 - or broken and confirmed fixed the same day - left
-- out, their marks: Zomboid/Lua/knox_testbench_beta1.txt)
B.POINTS = {
    -- 1.0: the generator window (mockup 17, written 2026-10-22)
    {id = "gen_open", actions = {{"Gen", function(p) B.genPlaced(p) end}}, check = checkGen},
    {id = "gen_use", check = checkGen},
    {id = "gen_pull", check = checkGen},
    {id = "gen_worn", actions = {{"GenWorn", function(p) B.genCondition(p, 30) end}, {"GenNew", function(p) B.genCondition(p, 100) end}}, check = checkGen},
    {id = "gen_fuel", actions = {{"GenDry", function(p) B.genDry(p) end}}, check = checkGen},
    {id = "gen_house", check = checkGen},
    {id = "gen_indoor", check = checkGen},
    {id = "gen_outlets", check = checkGen},
    {id = "gen_menu", check = checkGen},
    -- 1.0: the big check-up (speed, caches, clean-up; nothing should look different)
    {id = "u_java", check = checkJava},
    {id = "u_move", actions = {{"Dump", function(p) B.dump(p) end}, {"ClearDump", function() B.clearDump() end}}, check = checkMoving},
    {id = "u_loot"},
    {id = "u_tooltip"},
    {id = "u_menu"},
    {id = "u_eye", actions = {{"Prepare", function(p, n) B.prepare(p, n) end}}, check = checkEye},
    {id = "u_equip"},
    {id = "u_found"},
    {id = "u_tv"},
    {id = "u_inspect"},
    {id = "u_search_off"},
    {id = "u_cn"},
    {id = "u_mp"},
    -- 1.0 BETA: not seen yet
    {id = "b_bike"},
    {id = "b_cursor"},
    {id = "b_stacks", actions = {{"Pile", function(p) B.betaPile(p) end}, {"ClearDump", function() B.clearDump() end}}},
    {id = "b_mp_host"},
    -- 1.0 (the car's dashboard as a car's - mockup 2, 2026-10-21 - and its radio)
    {id = "dash_truck", actions = {{"Pickup", function(p) B.car(p, "Base.PickUpTruck") end}}, check = checkDash},
    {id = "dash_night", actions = {{"Night", function() B.night() end}, {"Day", function() B.day() end}}, check = checkDash},
    {id = "dash_low", actions = {{"Dry", function(p) B.dry(p) end}}, check = checkDash},
    {id = "dash_hot", actions = {{"Hotwire", function(p) B.hotwire(p) end}}, check = checkDash},
    {id = "dash_tape", check = checkDash},
    {id = "dash_card", check = checkDash},
    {id = "dash_heater", check = checkDash},
    {id = "dash_screens", check = checkDash},
    -- (the news post's live dashboard - KnoxDashboard.makeDemo, "@dash" lines)
    {id = "dash_news"},
    -- 1.0 (own music heard by the others in a game with others - KnoxMusicNet;
    -- written 2026-10-21, two clients needed: a host and a second game)
    {id = "net_share", actions = {{"Car", function(p) B.car(p) end}}, check = checkMusicNet},
    {id = "net_outside", check = checkMusicNet},
    {id = "net_passenger", check = checkMusicNet},
    {id = "net_control", check = checkMusicNet},
    {id = "net_fetch", check = checkMusicNet},
    {id = "net_parked", actions = {{"Car", function(p) B.car(p) end}}, check = checkMusicNet},
    {id = "net_off", check = checkMusicNet},
}

-- the health tab: hidden until 2.0, on the bench only with it (dev.health=1)
if T.modules and T.modules.health then
    for _, p in ipairs({
        {id = "health_tab", check = checkHealthTab},
        {id = "health_wounds", actions = woundActions(), check = checkHealthWounds},
        {id = "health_bones", actions = boneActions(), check = checkFractures},
        {id = "health_treat", actions = {{"Kit", function(p) B.kit(p) end}}, check = checkHealthTab},
        {id = "health_menu", check = checkHealthTab},
        {id = "health_heal", actions = {{"Heal", function(p) B.heal(p) end}}, check = checkHealthTab},
        {id = "health_vanilla"},
    }) do table.insert(B.POINTS, p) end
end

-- The report ----------------------------------------------------------------------

local function clean(s) return (string.gsub(tostring(s or ""), "[|\r\n]", " ")) end

function B.save()
    local w = getFileWriter(REPORT, true, false)
    if not w then return end
    w:write("Knox test bench " .. RELEASE .. " | mod " .. tostring(Knox and Knox.VERSION or "?") .. " | ms " .. getTimestampMs() .. "\r\n")
    w:write("id|verdict|auto ok|auto|note\r\n")
    for _, p in ipairs(B.POINTS) do
        local s = B.state[p.id] or {}
        w:write(p.id .. "|" .. (s.verdict or "-") .. "|" .. (s.autoOk == nil and "-" or tostring(s.autoOk)) .. "|"
            .. clean(s.auto) .. "|" .. clean(s.note) .. "\r\n")
    end
    w:close()
end

--- The marks of an earlier run (the window may be closed and opened again, the game left).
local loaded = false
local function load()
    if loaded then return end
    loaded = true
    for _, line in ipairs(readLines(REPORT)) do
        local id, verdict, autoOk, auto, note = string.match(line, "^([%w_]+)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
        if id and id ~= "id" then
            local okv = nil
            if autoOk == "true" then okv = true elseif autoOk == "false" then okv = false end
            B.state[id] = {verdict = verdict ~= "-" and verdict or nil, autoOk = okv,
                           auto = auto ~= "" and auto or nil, note = note}
        end
    end
end

-- The window -----------------------------------------------------------------------

function B:new(host, playerNum)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.host = host
    o.playerNum = playerNum
    o.background = false
    o.moveWithMouse = false
    o.sel = 1
    return o
end

function B:player() return getSpecificPlayer(self.playerNum) end

function B:createChildren()
    load()
    local c, pad = T.cell, T.pad
    self.headerH = T.sectionH + 4
    self.listW = math.floor(c * 4.6)
    self.rowH = math.floor(c * 0.55)
    -- (no taller than 12 cells - the list scrolls with the wheel: with every point shown the
    -- window outgrew the screen and covered the game, the author 2026-10-22)
    local footH = (T.fontH(T.fontText) + 2) * 3 + T.fontTileH * 2
    local listH = self.headerH + pad + #B.POINTS * (self.rowH + 2) + pad + footH
    local w, h = math.floor(c * 15), math.max(math.floor(c * 10.5), math.min(listH + pad, math.floor(c * 12)))
    self.listTop = self.headerH + pad
    self.listBottom = h - pad - footH
    self.visRows = math.max(1, math.floor((self.listBottom - self.listTop + 2) / (self.rowH + 2)))
    self.scroll = 0
    self:setWidth(w)
    self:setHeight(h)
    local boxFont = T.gameFont(T.fontText)
    self.noteH = T.fontH(boxFont) + 8
    self.paneX = self.listW + pad * 2
    self.paneW = w - self.paneX - pad
    self.note = ISTextEntryBox:new("", self.paneX, h - pad - self.noteH, self.paneW, self.noteH)
    self.note.font = boxFont
    self.note:initialise()
    self.note:instantiate()
    self:addChild(self.note)
    self:showNote()
end

function B:point() return B.POINTS[self.sel] end

function B:stateOf(id)
    B.state[id] = B.state[id] or {}
    return B.state[id]
end

function B:showNote()
    local s = self:stateOf(self:point().id)
    self.note:setText(s.note or "")
    self.noteWas = s.note or ""
end

function B:closeRect()
    local s = self.headerH - 8
    return {self:getWidth() - s - 4, 4, s, s}
end

--- The header's buttons, right to left from Close: Clean up, Items.
function B:headerButtons()
    local cr = self:closeRect()
    local out, x = {}, cr[1] - T.pad
    -- (the tiles drawn by the Java part or all by Lua: to compare the two by eye)
    local tiles = getText(B.luaTiles and "IGUI_KnoxTB_TilesLua" or "IGUI_KnoxTB_TilesJava")
    for _, b in ipairs({{"cleanup", getText("IGUI_KnoxTB_Cleanup")}, {"items", getText("IGUI_KnoxTB_Items")}, {"tiles", tiles}}) do
        local bw = T.buttonW(b[2])
        x = x - bw
        table.insert(out, {x, cr[2], bw, cr[4], b[2], id = b[1]})
        x = x - T.pad
    end
    return out
end

function B:rowRect(i)
    return {T.pad, self.listTop + (i - 1 - self.scroll) * (self.rowH + 2), self.listW, self.rowH}
end

--- Is point i in the list's window (scrolled to)?
function B:rowShown(i)
    return i > self.scroll and i <= self.scroll + self.visRows
end

function B:scrollTo(i)
    local most = math.max(0, #B.POINTS - self.visRows)
    if i <= self.scroll then self.scroll = i - 1 elseif i > self.scroll + self.visRows then self.scroll = i - self.visRows end
    self.scroll = math.max(0, math.min(most, self.scroll))
end

function B:prerender()
    local w, h, pad = self:getWidth(), self:getHeight(), T.pad
    local ft, fc = T.fontH(T.fontText), T.fontH(T.fontCaps)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    -- the note: saved as it is typed
    local text = self.note:getText() or ""
    if text ~= self.noteWas then
        self.noteWas = text
        self:stateOf(self:point().id).note = text
        B.save()
    end

    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, self.headerH, T.color.header)
    T.tileFrame(self, 0, 0, w, h, T.color.accent)
    T.caps(self, getText("IGUI_KnoxTB_Title", RELEASE), 8, math.floor((self.headerH - fc) / 2), T.color.bright)
    local cr = self:closeRect()
    T.closeButton(self, cr[1], cr[2], cr[3], over and T.inRect(mx, my, cr))
    for _, b in ipairs(self:headerButtons()) do
        T.button(self, b, b[5], {hover = over and T.inRect(mx, my, b), font = T.fontTile})
    end

    -- the list: a mark (green works, red broken, grey not yet), the number, the name
    if self.sel ~= self.shownSel then self.shownSel = self.sel self:scrollTo(self.sel) end
    for i, p in ipairs(B.POINTS) do
        if self:rowShown(i) then
            local r = self:rowRect(i)
            local s = B.state[p.id] or {}
            local on = i == self.sel
            T.rect(self, r[1], r[2], r[3], r[4], on and T.color.header or T.color.cell)
            if over and T.inRect(mx, my, r) and not on then self:drawRect(r[1], r[2], r[3], r[4], 0.05, 1, 1, 1) end
            T.border(self, r[1], r[2], r[3], r[4], on and T.color.accent or T.color.border)
            local mc = (s.verdict == "ok" and T.color.ok) or (s.verdict == "bad" and T.color.bad) or T.color.tileEdge
            local d = math.floor(r[4] * 0.36)
            T.rect(self, r[1] + 6, r[2] + math.floor((r[4] - d) / 2), d, d, mc)
            local name = i .. ". " .. getText("IGUI_KnoxTB_" .. p.id)
            T.text(self, T.fit(name, T.fontText, r[3] - d - 18), r[1] + d + 12, r[2] + math.floor((r[4] - ft) / 2),
                on and T.color.bright or T.color.text, T.fontText)
        end
    end
    -- the scroll bar: where the shown rows are in the whole list
    if #B.POINTS > self.visRows then
        local tx, th = pad + self.listW + 3, self.listBottom - self.listTop
        T.rect(self, tx, self.listTop, 3, th, T.color.cell)
        local ty = self.listTop + math.floor(th * self.scroll / #B.POINTS)
        T.rect(self, tx, ty, 3, math.max(8, math.floor(th * self.visRows / #B.POINTS)), T.color.tileEdge)
    end
    local done = 0
    for _, p in ipairs(B.POINTS) do
        if (B.state[p.id] or {}).verdict then done = done + 1 end
    end
    local ly = self.listBottom + pad
    T.text(self, getText("IGUI_KnoxTB_Done", done, #B.POINTS), pad, ly, T.color.dim, T.fontText)
    local rl = T.wrap(getText("IGUI_KnoxTB_Report"), T.fontTile, self.listW)
    for _, l in ipairs(rl) do
        ly = ly + T.fontTileH + 2
        T.text(self, l, pad, ly, T.color.dim, T.fontTile)
    end

    -- the point: name, what to do, what should happen, its buttons, the check, the marks
    local p = self:point()
    local s = self:stateOf(p.id)
    local x, y, pw = self.paneX, self.headerH + pad, self.paneW
    T.caps(self, getText("IGUI_KnoxTB_" .. p.id), x, y, T.color.accent)
    y = y + fc + pad
    local function block(label, key)
        T.text(self, T.upper(getText(label)), x, y, T.color.dim, T.fontTile)
        y = y + T.fontTileH + 4
        for _, l in ipairs(T.wrap(getText(key), T.fontText, pw)) do
            T.text(self, l, x, y, T.color.text, T.fontText)
            y = y + ft + 2
        end
        y = y + pad
    end
    block("IGUI_KnoxTB_Do", "IGUI_KnoxTB_" .. p.id .. "_Do")
    block("IGUI_KnoxTB_Want", "IGUI_KnoxTB_" .. p.id .. "_Want")
    -- the buttons: the scene's, then Check
    self.btns = {}
    local bh = math.floor(T.cell * 0.6)
    local bx = x
    -- (in rows: a point with many scenes - the health tab's wounds, one each - wraps)
    local function place(bw)
        if bx > x and bx + bw > x + pw then
            bx = x
            y = y + bh + 6
        end
        local at = bx
        bx = bx + bw + 6
        return at
    end
    for _, a in ipairs(p.actions or {}) do
        local label = getText("IGUI_KnoxTB_A_" .. a[1])
        local bw = T.buttonW(label) + pad * 2
        local at = place(bw)
        table.insert(self.btns, {at, y, bw, bh, label, fn = a[2]})
    end
    if p.check then
        local label = getText("IGUI_KnoxTB_Check")
        local bw = T.buttonW(label) + pad * 2
        local at = place(bw)
        table.insert(self.btns, {at, y, bw, bh, label, check = true})
    end
    for _, b in ipairs(self.btns) do
        T.button(self, b, b[5], {hover = over and T.inRect(mx, my, b), primary = b.check, font = T.fontTile})
    end
    if #self.btns > 0 then y = y + bh + pad end
    if s.auto then
        for _, l in ipairs(T.wrap(s.auto, T.fontText, pw)) do
            T.text(self, l, x, y, s.autoOk and T.color.ok or T.color.bad, T.fontText)
            y = y + ft + 2
        end
    end
    -- the marks and the note, at the bottom
    local vy = self.note:getY() - pad - bh - ft - 6
    local vw = math.floor((pw - 6) / 2)
    self.verdicts = {
        {x, vy, vw, bh, getText("IGUI_KnoxTB_Works"), v = "ok"},
        {x + vw + 6, vy, vw, bh, getText("IGUI_KnoxTB_Broken"), v = "bad"},
    }
    for _, b in ipairs(self.verdicts) do
        local chosen = s.verdict == b.v
        T.button(self, b, b[5], {hover = over and T.inRect(mx, my, b), primary = chosen and b.v == "ok", font = T.fontTile})
        if chosen and b.v == "bad" then
            T.rect(self, b[1], b[2], b[3], b[4], T.color.bad, 0.35)
            T.border(self, b[1], b[2], b[3], b[4], T.color.bad)
        end
    end
    T.text(self, getText("IGUI_KnoxTB_Note"), x, self.note:getY() - ft - 4, T.color.dim, T.fontText)
end

function B:onMouseDown(x, y)
    if T.inRect(x, y, self:closeRect()) then
        self:close()
        return true
    end
    for _, b in ipairs(self:headerButtons()) do
        if T.inRect(x, y, b) then
            if b.id == "items" and KnoxDevPanel then
                KnoxDevPanel.toggle(self.host, self.playerNum)
            elseif b.id == "cleanup" then
                B.cleanup(self:player())
            elseif b.id == "tiles" then
                B.luaTiles = not B.luaTiles
            end
            getSoundManager():playUISound("UIActivateButton")
            return true
        end
    end
    for i = 1, #B.POINTS do
        if self:rowShown(i) and T.inRect(x, y, self:rowRect(i)) then
            self.sel = i
            self:showNote()
            getSoundManager():playUISound("UIActivateButton")
            return true
        end
    end
    local p = self:point()
    for _, b in ipairs(self.btns or {}) do
        if T.inRect(x, y, b) then
            getSoundManager():playUISound("UIActivateButton")
            if b.check then
                local ok, text = p.check(self:player())
                local s = self:stateOf(p.id)
                s.autoOk, s.auto = ok == true, text
                B.save()
            elseif b.fn then
                b.fn(self:player(), self.playerNum)
            end
            return true
        end
    end
    for _, b in ipairs(self.verdicts or {}) do
        if T.inRect(x, y, b) then
            local s = self:stateOf(p.id)
            s.verdict = s.verdict ~= b.v and b.v or nil
            B.save()
            getSoundManager():playUISound("UIActivateButton")
            -- marked: on to the next point not marked yet
            if s.verdict then
                for k = 1, #B.POINTS do
                    local j = (self.sel + k - 1) % #B.POINTS + 1
                    if not (B.state[B.POINTS[j].id] or {}).verdict then
                        self.sel = j
                        self:showNote()
                        break
                    end
                end
            end
            return true
        end
    end
    KnoxWindowDrag.begin(self, x, y, self.headerH)
    return true
end

KnoxWindowDrag.install(B)

function B:onRightMouseUp(x, y) return true end
function B:onMouseWheel(del)
    if self:getMouseX() < T.pad + self.listW + 8 then
        self.scroll = math.max(0, math.min(math.max(0, #B.POINTS - self.visRows), self.scroll + (del > 0 and 1 or -1)))
    end
    return true
end

function B:close()
    B.save()
    self:setVisible(false)
    self.host:removeChild(self)
    if B.instance == self then B.instance = nil end
end

function B.toggle(host, playerNum)
    if B.instance then
        B.instance:close()
        return
    end
    local p = B:new(host, playerNum)
    p:initialise()
    p:instantiate()
    -- at the right of the screen: the inventory stays in view behind it
    p:setX(host:getWidth() - p:getWidth() - T.cell)
    p:setY(math.floor((host:getHeight() - p:getHeight()) / 2))
    host:addChild(p)
    B.instance = p
end

-- DEV mode: Insert (no -debug needed) - only
-- where Zomboid/Lua/knox_dev.txt exists (the author's computer): the bench
-- hands out things, and players must not stumble on it.
local devFile = nil
local function devAllowed()
    if devFile == nil then
        local r = getFileReader("knox_dev.txt", false)
        devFile = r ~= nil
        if r then r:close() end
    end
    return devFile
end

function B.devOn()
    -- (filming: no DEV button in the shot - KnoxStudio)
    if KnoxStudio and KnoxStudio.active then return false end
    return isDebugEnabled() or (T.settings.dev == "1" and devAllowed())
end

B.devAllowed = devAllowed

-- Insert (the author's wish, 2026-10-15; was Ctrl+Shift+D): DEV mode on and the
-- bench opened - the Knox screen too, when it is closed; pressed again, the
-- bench closes. Only where knox_dev.txt is (or with -debug).
Events.OnKeyPressed.Add(function(key)
    if key ~= Keyboard.KEY_INSERT or not (devAllowed() or isDebugEnabled()) then return end
    if not getSpecificPlayer(0) or not KnoxScreen then return end
    if T.settings.dev ~= "1" then
        T.settings.dev = "1"
        T.saveSettings()
    end
    if not KnoxScreen.instance then
        Knox.open(0)
        if not KnoxScreen.instance then return end
        if B.instance then return end
    end
    B.toggle(KnoxScreen.instance, KnoxScreen.instance.playerNum or 0)
end)

return B
