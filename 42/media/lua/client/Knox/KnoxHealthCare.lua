-- Treating from the health tab (KnoxHealthPanel), with the game's own means:
--   * a body part's menu: the game's (ISHealthPanel.doBodyPartContextMenu - other
--     mods' entries in it stay), filtered to what helps - the whole part, or one of
--     its statuses - with why a treatment it calls for can't be done ("Disinfect:
--     take the bandage off first"), under a header naming the part and its state;
--   * quick treatment (Shift + click): everything the part needs that the
--     character has things for, queued in medical order;
--   * things dropped on the body: the game's drop (dropItemsOnBodyPart), Casualties
--     Undead's first;
--   * the kit: what the character carries that treats, and which parts each
--     thing would treat now (the model lights them while it's under the mouse).
-- The menus and the drop go through the game's own health panel of the player
-- (the character window's health view): its handlers are local to its file, and
-- the progress of a treatment is reported to it (setBodyPartActionForPlayer).
-- Taken over from the author's Grid Character Hub (Treatment, ItemHighlight).

require "Knox/KnoxTheme"
require "Knox/KnoxHealthCU"
require "Knox/KnoxHealthData"

KnoxHealthCare = KnoxHealthCare or {}
local C = KnoxHealthCare
local H = KnoxHealthData
local CU = KnoxHealthCU
local T = H.T

-- The game's health panel ----------------------------------------------------------

local own = {}   -- [playerNum] = a health panel of Knox's own (no character window)

--- The player's health panel the game's handlers run on: the character window's.
function C.carePanel(player)
    local n = player:getPlayerNum()
    local info = getPlayerInfoPanel and getPlayerInfoPanel(n)
    local hv = info and info.healthView
    if hv and hv.character == player then return hv end
    local p = own[n]
    if not p or p.character ~= player then
        -- (ISHealthPanel:new takes the place of the game's "the" health panel: put back)
        local was = ISHealthPanel.instance
        p = ISHealthPanel:new(player, 0, 0, 10, 10)
        p:initialise()
        p:instantiate()
        ISHealthPanel.instance = was
        own[n] = p
    end
    return p
end

--- A treatment going on on this body part: its progress 0..1 and its name.
function C.partProgress(player, bp)
    local p = C.carePanel(player)
    local act = p and p.bodyPartAction and p.bodyPartAction[bp]
    if act and act.delta then return act.delta, act.jobType end
    local q = ISTimedActionQueue.getTimedActionQueue(player)
    local a = q and q.queue and q.queue[1]
    if a and p and p.actions and p.actions[a] == bp then return a:getJobDelta(), a.jobType end
    if a and a.bodyPart == bp and a.getJobDelta then return a:getJobDelta(), a.jobType end
    return nil
end

--- Is any treatment going on (the character busy with a body part)?
function C.busy(player)
    local q = ISTimedActionQueue.getTimedActionQueue(player)
    local a = q and q.queue and q.queue[1]
    return a ~= nil and a.bodyPart ~= nil
end

-- Item checks, by the game's menu label key of the treatment -------------------------
-- (the same tests as the game's handlers: an item is one when its handler would list it)

local function hasTag(item, tag)
    if tag == nil then return false end
    local ok, res = pcall(function() return item:hasTag(tag) end)
    return ok and res == true
end

local function isDisinfectant(item)
    local ok, res = pcall(function()
        if ComponentType and item:hasComponent(ComponentType.FluidContainer) then
            local fc = item:getFluidContainer()
            local amount = fc and fc:getAmount() or 0
            return amount > 0.15 and (fc:getProperties():getAlcohol() / amount + 0.001 >= 0.4)
        end
        return item:IsDrainable() and item:getAlcoholPower() == 4.0
    end)
    return ok and res == true
end

local function isDirty(item)
    return string.find(string.lower(item:getType() or ""), "dirty") ~= nil
end

local function isGlassTool(item)
    local t = item:getType()
    return t == "Tweezers" or t == "SutureNeedleHolder" or hasTag(item, ItemTag and ItemTag.REMOVE_GLASS)
end

local function isBulletTool(item)
    local t = item:getType()
    return t == "Tweezers" or t == "SutureNeedleHolder" or hasTag(item, ItemTag and ItemTag.REMOVE_BULLET)
end

local SPLINT_PLANKS = {Plank = true, TreeBranch2 = true, WoodenStick2 = true, TreeBranch = true, WoodenStick = true}

C.CHECK = {
    ContextMenu_Bandage   = function(item) return item:getBandagePower() > 0 end,
    ContextMenu_Disinfect = isDisinfectant,
    ContextMenu_Stitch    = function(item)
        local t = item:getType()
        return t == "Needle" or t == "Thread" or t == "SutureNeedle"
            or hasTag(item, ItemTag and ItemTag.SEWING_NEEDLE) or hasTag(item, ItemTag and ItemTag.THREAD)
    end,
    ContextMenu_Remove_Glass  = isGlassTool,
    ContextMenu_Remove_Bullet = isBulletTool,
    ContextMenu_Splint = function(item)
        local t = item:getType()
        return t == "Splint" or SPLINT_PLANKS[t] == true or t == "RippedSheets"
    end,
    ContextMenu_Clean_Burn        = function(item) return item:getBandagePower() >= 2 end,
    ContextMenu_PlantainCataplasm = function(item) return item:getType() == "PlantainCataplasm" end,
    ContextMenu_ComfreyCataplasm  = function(item) return item:getType() == "ComfreyCataplasm" end,
    ContextMenu_GarlicCataplasm   = function(item) return item:getType() == "WildGarlicCataplasm" end,
}

local checkCache = {}
local function checkFor(key)
    local f = C.CHECK[key]
    if f then return f end
    local c = checkCache[key]
    if c == nil then
        c = (CU and CU.itemCheck(key)) or false
        checkCache[key] = c
    end
    return c or nil
end

local function matches(keys, item)
    for key in pairs(keys) do
        local f = checkFor(key)
        if f then
            local ok, res = pcall(f, item)
            if ok and res then return true end
        end
    end
    return false
end
C.matches = matches

--- Does this treatment apply to the body part now (the handlers' addToMenu tests)?
function C.applies(bp, key)
    local injured = (bp:HasInjury() or bp:stitched() or bp:getSplintFactor() > 0) and not bp:bandaged()
    if key == "ContextMenu_Bandage" or key == "ContextMenu_Disinfect" then return injured end
    if key == "ContextMenu_Stitch" then return injured and bp:isDeepWounded() and not bp:haveGlass() end
    if key == "ContextMenu_Remove_Glass" then return injured and bp:haveGlass() end
    if key == "ContextMenu_Remove_Bullet" then return injured and bp:haveBullet() end
    if key == "ContextMenu_Clean_Burn" then return injured and bp:isNeedBurnWash() end
    if key == "ContextMenu_Splint" then
        local t = bp:getType()
        if t == BodyPartType.Head or t == BodyPartType.Torso_Upper or t == BodyPartType.Torso_Lower then return false end
        return bp:HasInjury() and not bp:stitched() and bp:getSplintFactor() == 0 and bp:getFractureTime() > 0
    end
    if key == "ContextMenu_PlantainCataplasm" or key == "ContextMenu_ComfreyCataplasm" or key == "ContextMenu_GarlicCataplasm" then
        return injured and bp:getPlantainFactor() == 0 and bp:getComfreyFactor() == 0 and bp:getGarlicFactor() == 0
    end
    return false   -- the removals take nothing
end

--- The treatments (keys) that take a thing and would help this body part now -
--- for one status (kind), or the whole part (nil): {[key] = true}.
function C.keysFor(player, bp, kind)
    local keys = {}
    local function addKind(k)
        for _, key in ipairs(H.TREAT[k] or {}) do
            if C.CHECK[key] and C.applies(bp, key) then keys[key] = true end
        end
    end
    if kind then
        addKind(kind)
    else
        for _, c in ipairs(H.partInfo(player, bp).chips) do addKind(c.kind) end
    end
    if CU then CU.treatmentKeys(player, bp, kind, keys) end
    return keys
end

--- Would this thing treat something on the body part now?
function C.treats(player, bp, item)
    if not H.damaged(bp) and bp:getBleedingTime() <= 0 then return false end
    return matches(C.keysFor(player, bp, nil), item)
end

--- Is this a thing for the kit (anything that treats, pills, first aid)?
function C.isMedical(item)
    if instanceof(item, "InventoryContainer") then return false end
    local dc = item:getDisplayCategory()
    if dc == "FirstAid" then return true end
    if CU and CU.isMedical(item) then return true end
    for key, f in pairs(C.CHECK) do
        local ok, res = pcall(f, item)
        -- (planks and branches splint, but are not a kit's: only the ready splint)
        if ok and res and (key ~= "ContextMenu_Splint" or item:getType() == "Splint") then return true end
    end
    return false
end

-- The kit ----------------------------------------------------------------------------
-- The order of its tiles: what stops bleeding first, then cleaning, closing,
-- setting, removing, the pills, the rest.
local KIT_ORDER = {
    {"ContextMenu_Bandage"}, {"ContextMenu_Disinfect"}, {"ContextMenu_Stitch"}, {"ContextMenu_Splint"},
    {"ContextMenu_Remove_Glass"}, {"ContextMenu_PlantainCataplasm", "ContextMenu_ComfreyCataplasm", "ContextMenu_GarlicCataplasm"},
}

local function kitRank(item)
    for i, keys in ipairs(KIT_ORDER) do
        for _, key in ipairs(keys) do
            local ok, res = pcall(C.CHECK[key], item)
            if ok and res then return i end
        end
    end
    if string.find(item:getType() or "", "Pills") then return #KIT_ORDER + 1 end
    return #KIT_ORDER + 2
end

--- The things the character carries for the kit, a group per kind of thing:
--- {{type, item (the first), items, count, name, rank}}. (Cached a moment: the
--- tab asks every frame.)
local kitCache = {}
function C.kit(player)
    local n = player:getPlayerNum()
    local now = getTimestampMs()
    local c = kitCache[n]
    if c and now - c.ms < 250 then return c.list end
    local by, list = {}, {}
    local function scan(container, depth)
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if instanceof(it, "InventoryContainer") then
                if depth < 2 then scan(it:getInventory(), depth + 1) end
            elseif C.isMedical(it) then
                local key = it:getFullType()
                local g = by[key]
                if not g then
                    g = {type = key, item = it, items = {}, count = 0, name = it:getName(), rank = kitRank(it)}
                    by[key] = g
                    table.insert(list, g)
                end
                table.insert(g.items, it)
                g.count = g.count + 1
            end
        end
    end
    scan(player:getInventory(), 0)
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.name < b.name
    end)
    kitCache[n] = {ms = now, list = list}
    return list
end

function C.dropKitCache(player)
    kitCache[player:getPlayerNum()] = nil
end

--- The body parts (indices) this thing would treat now.
function C.partsFor(player, item)
    local out = {}
    local bps = player:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do
        if not H.missing(player, i) and C.treats(player, bps:get(i), item) then out[i] = true end
    end
    return out
end

-- Menus ------------------------------------------------------------------------------

-- Why a treatment a status calls for isn't offered (a translation key), or nil when it
-- just doesn't apply; past the handlers' own tests the reason is a missing thing.
local function unavailableReason(key, bp)
    local bandaged = bp:bandaged()
    if key == "ContextMenu_Bandage" then
        if bandaged then return nil end
        return "IGUI_KnoxHP_NeedBandage"
    elseif key == "ContextMenu_Disinfect" then
        if bandaged then return "IGUI_KnoxHP_RemoveBandageFirst" end
        return "IGUI_KnoxHP_NeedDisinfectant"
    elseif key == "ContextMenu_Stitch" then
        if not bp:isDeepWounded() or bp:stitched() then return nil end
        if bandaged then return "IGUI_KnoxHP_RemoveBandageFirst" end
        if bp:haveGlass() then return "IGUI_KnoxHP_RemoveGlassFirst" end
        return "IGUI_KnoxHP_NeedNeedle"
    elseif key == "ContextMenu_Splint" then
        local t = bp:getType()
        if t == BodyPartType.Head or t == BodyPartType.Torso_Upper or t == BodyPartType.Torso_Lower then return nil end
        if bp:getFractureTime() <= 0 or bp:getSplintFactor() > 0 or bp:stitched() then return nil end
        return "IGUI_KnoxHP_NeedSplint"
    elseif key == "ContextMenu_Remove_Glass" then
        if bandaged then return "IGUI_KnoxHP_RemoveBandageFirst" end
        return nil                                   -- by hand is always possible
    elseif key == "ContextMenu_Remove_Bullet" then
        if bandaged then return "IGUI_KnoxHP_RemoveBandageFirst" end
        return "IGUI_KnoxHP_NeedTweezers"
    elseif key == "ContextMenu_Clean_Burn" then
        if not bp:isNeedBurnWash() then return nil end
        if bandaged then return "IGUI_KnoxHP_RemoveBandageFirst" end
        return "IGUI_KnoxHP_NeedBandage"
    end
    return nil
end
C.unavailableReason = unavailableReason

-- Knox's icon for each treatment of the game's menus
local ICON = {
    ContextMenu_Bandage = "bandage", ContextMenu_Remove_Bandage = "unbandage",
    ContextMenu_Disinfect = "disinfect", ContextMenu_Stitch = "sew", ContextMenu_Remove_Stitch = "unstitch",
    ContextMenu_Remove_Glass = "tweezers", ContextMenu_Remove_Bullet = "tweezers",
    ContextMenu_Splint = "splint", ContextMenu_Remove_Splint = "unsplint", ContextMenu_Clean_Burn = "burn",
    ContextMenu_PlantainCataplasm = "poultice", ContextMenu_ComfreyCataplasm = "poultice",
    ContextMenu_GarlicCataplasm = "poultice",
}

local function startsWith(name, label)
    return name == label or string.sub(name, 1, #label + 2) == label .. " ("
end

local function keyOfOption(name)
    for key in pairs(ICON) do
        if startsWith(name, T(key)) then return key end
    end
    return nil
end

local function reasonTip(text)
    local tip = ISWorldObjectContextMenu.addToolTip and ISWorldObjectContextMenu.addToolTip() or ISToolTip:new()
    tip.description = text
    return tip
end

-- Adds the treatments of `keys` the menu doesn't offer, greyed out with the reason under them.
local function addUnavailable(context, bp, keys)
    local seen = {}
    for _, key in ipairs(keys) do
        if not seen[key] then
            seen[key] = true
            local label = T(key)
            local shown = false
            for _, opt in ipairs(context.options) do
                if startsWith(opt.name, label) then shown = true break end
            end
            local why = not shown and unavailableReason(key, bp)
            if why then
                local opt = context:addOption(label, nil)
                opt.notAvailable = true
                opt.toolTip = reasonTip(T(why))
                opt.knoxIconKey = ICON[key]
            end
        end
    end
end
C.addUnavailable = addUnavailable

local function vanillaLabels()
    local v = {[T("ContextMenu_Cheat")] = true}
    for _, keys in pairs(H.TREAT) do
        for _, k in ipairs(keys) do v[T(k)] = true end
    end
    return v
end

local function partTitle(player, bp)
    local z = H.zoneOfPart[H.indexOf(bp)]
    local hp = math.max(0, math.floor(bp:getHealth() + 0.5))
    local info = H.partInfo(player, bp)
    local names = {}
    for _, c in ipairs(info.chips) do
        if not c.passive then table.insert(names, c.text) end
        if #names >= 3 then break end
    end
    local sub = getText("IGUI_KnoxHP_HpOf", hp)
    if #names > 0 then sub = sub .. "  " .. string.char(183) .. "  " .. table.concat(names, ", ") end
    local icon = "zone_" .. ((z and (z.id == "larm" or z.id == "rarm") and "arm")
        or (z and (z.id == "lleg" or z.id == "rleg") and "leg") or (z and z.id) or "thorax")
    return H.partName(bp), sub, icon, H.hpColor(hp)
end

--- Opens a body part's menu at the screen point sx, sy: the whole part (kind nil)
--- or one of its statuses (kind); returns the menu (nil: nothing to do there).
function C.openMenu(player, bp, sx, sy, kind)
    local n = player:getPlayerNum()
    local panel = C.carePanel(player)
    if not panel then return nil end
    if KnoxContextMenu and KnoxContextMenu.setTitle then
        local title, sub, icon, color = partTitle(player, bp)
        if kind then
            for _, c in ipairs(H.partInfo(player, bp).chips) do
                if c.kind == kind then sub = c.label break end
            end
        end
        KnoxContextMenu.setTitle(n, title, sub, icon, color)
    end
    -- (the game's panel puts the menu at x, y of itself)
    panel:doBodyPartContextMenu(bp, sx - panel:getAbsoluteX(), sy - panel:getAbsoluteY())
    local context = getPlayerContextMenu(n)
    if not context then return nil end
    local other = kind and string.sub(kind, 1, 3) == "cu_"
    local vanilla = vanillaLabels()
    local remove = {}
    local keys = {}
    if other then
        -- a status of another mod: only the other mods' entries
        for _, opt in ipairs(context.options) do
            if vanilla[opt.name] then table.insert(remove, opt.name) end
        end
    elseif kind then
        local allowed = {}
        for _, k in ipairs(H.TREAT[kind] or {}) do
            allowed[T(k)] = true
            table.insert(keys, k)
        end
        for _, opt in ipairs(context.options) do
            if not allowed[opt.name] and not (CU and CU.menuEntryFor(kind, opt.name)) then table.insert(remove, opt.name) end
        end
    else
        -- the whole part: the game's treatments that help one of its statuses, each
        -- once with the statuses it treats in brackets; other mods' entries stay
        local treats, kinds, seenKind = {}, 0, {}
        for _, c in ipairs(H.partInfo(player, bp).chips) do
            if H.TREAT[c.kind] and not seenKind[c.kind] then
                seenKind[c.kind] = true
                kinds = kinds + 1
                local name = c.text
                local cut = string.find(name, " %(") or string.find(name, " %- ")
                if cut then name = string.sub(name, 1, cut - 1) end
                for _, k in ipairs(H.TREAT[c.kind]) do
                    local label = T(k)
                    treats[label] = treats[label] or {}
                    table.insert(treats[label], name)
                    table.insert(keys, k)
                end
            end
        end
        for _, opt in ipairs(context.options) do
            if vanilla[opt.name] and not treats[opt.name] then table.insert(remove, opt.name) end
        end
        if kinds > 1 then
            for _, opt in ipairs(context.options) do
                local names = treats[opt.name]
                if names then opt.name = opt.name .. " (" .. table.concat(names, ", ") .. ")" end
            end
        end
    end
    for _, name in ipairs(remove) do context:removeOptionByName(name) end
    if not other then addUnavailable(context, bp, keys) end
    -- quick treatment on top, when there's something it can do (and the click on the
    -- model with Shift does the same - said on its row)
    if not other then
        local steps = C.quickTreat(player, bp, true)
        if #steps > 0 then
            local opt = context:addOptionOnTop(getText("IGUI_KnoxHP_QuickTreat"), player, function(p) C.quickTreat(p, bp) end)
            opt.knoxIconKey = "heal"
            local names = {}
            for _, s in ipairs(steps) do table.insert(names, s) end
            opt.toolTip = ISWorldObjectContextMenu.addToolTip and ISWorldObjectContextMenu.addToolTip() or ISToolTip:new()
            opt.toolTip.description = table.concat(names, " " .. string.char(187) .. " ")
            opt.knoxQuick = true
        end
    end
    for _, opt in ipairs(context.options) do
        if not opt.knoxIconKey then
            local key = keyOfOption(opt.name)
            if key then opt.knoxIconKey = ICON[key] end
        end
    end
    if context:isEmpty() then
        if other then
            context:setVisible(false)
            return nil
        end
        local opt = context:addOption(T("IGUI_KnoxHP_NoTreatment"), nil)
        opt.notAvailable = true
    end
    if CU then CU.addRisks(context, player) end
    context:calcHeight()
    context:setWidth(context:calcWidth())
    context:setVisible(true)
    return context
end

-- Quick treatment ------------------------------------------------------------------------
-- In medical order, everything the part needs that the character has things for:
--   dirty bandage off -> glass out -> bullet out -> clean the burn -> disinfect an
--   infection -> the best bandage -> splint a fracture.
-- Things picked the way the game's handlers pick them, the best first (sterile over
-- plain, bandage over rag; never a dirty one). The game's timed actions, as its
-- handlers queue them (theirs are local to their file), with the step that brings a
-- thing to the main inventory first. With Casualties Undead every one of them is a
-- minigame: only the first step goes (the next click does the next).

local function reachableItems(player)
    local items = {}
    local containers = ISInventoryPaneContextMenu.getContainers(player)
    if not containers then return items end
    local done = {}
    local function scan(container, depth)
        if not container or done[container] then return end
        done[container] = true
        local list = container:getItems()
        for i = 0, list:size() - 1 do
            local item = list:get(i)
            if item:IsInventoryContainer() then
                if depth == 0 then scan(item:getInventory(), 1) end
            else
                table.insert(items, item)
            end
        end
    end
    for i = 0, containers:size() - 1 do scan(containers:get(i), 0) end
    return items
end

local function bandageScore(item)
    if item:getBandagePower() <= 0 or isDirty(item) then return nil end
    local ok, sterile = pcall(function() return item:isAlcoholic() end)
    return ((ok and sterile) and 100 or 0) + item:getBandagePower()
end

local function pick(items, used, score)
    local best, bestS
    for _, item in ipairs(items) do
        if not used[item] then
            local s = score(item)
            if s and (not bestS or s > bestS) then best, bestS = item, s end
        end
    end
    if best then used[best] = true end
    return best
end

local function bool(f) return function(item) return f(item) and 0 or nil end end

--- Queues the quick treatment of a body part (dry: only says what it would do).
--- Returns the names of the steps.
function C.quickTreat(player, bp, dry)
    local doctor, patient = player, player
    local items = reachableItems(doctor)
    local used, steps = {}, {}
    local single = CU and CU.active()
    local function more() return not (single and #steps > 0) end
    local function step(key, make, ...)
        if not more() then return end
        table.insert(steps, T(key))
        if dry then return end
        for _, it in ipairs({...}) do ISInventoryPaneContextMenu.transferIfNeeded(doctor, it) end
        ISTimedActionQueue.add(make())
    end

    local dirty = bp:bandaged() and bp:getBandageLife() <= 0
    local open = not bp:bandaged() or dirty
    if dirty then step("ContextMenu_Remove_Bandage", function() return ISApplyBandage:new(doctor, patient, nil, bp, false) end) end
    if open and bp:haveGlass() then
        local tool = pick(items, used, bool(isGlassTool))
        if tool then step("ContextMenu_Remove_Glass", function() return ISRemoveGlass:new(doctor, patient, bp, false) end, tool) end
    end
    if open and bp:haveBullet() then
        local tool = pick(items, used, bool(isBulletTool))
        if tool then step("ContextMenu_Remove_Bullet", function() return ISRemoveBullet:new(doctor, patient, bp) end, tool) end
    end
    if open and bp:getBurnTime() > 0 and bp:isNeedBurnWash() then
        local cloth = pick(items, used, function(i)
            local s = bandageScore(i)
            return s and i:getBandagePower() >= 2 and -s or nil
        end)
        if cloth then step("ContextMenu_Clean_Burn", function() return ISCleanBurn:new(doctor, patient, cloth, bp) end, cloth) end
    end
    if open and bp:isInfectedWound() then
        local alcohol = pick(items, used, bool(isDisinfectant))
        if alcohol then step("ContextMenu_Disinfect", function() return ISDisinfect:new(doctor, patient, alcohol, bp) end, alcohol) end
    end
    if open and bp:HasInjury() then
        local bandage = pick(items, used, bandageScore)
        if bandage then step("ContextMenu_Bandage", function() return ISApplyBandage:new(doctor, patient, bandage, bp, true) end, bandage) end
    end
    local t = bp:getType()
    local splintable = t ~= BodyPartType.Head and t ~= BodyPartType.Torso_Upper and t ~= BodyPartType.Torso_Lower
    if splintable and bp:getFractureTime() > 0 and bp:getSplintFactor() == 0 then
        local splint = pick(items, used, function(i) return i:getType() == "Splint" and 0 or nil end)
        if splint then
            step("ContextMenu_Splint", function() return ISSplint:new(doctor, patient, nil, splint, bp, true) end, splint)
        else
            local plank = pick(items, used, function(i) return SPLINT_PLANKS[i:getType()] and 0 or nil end)
            local sheet = plank and pick(items, used, function(i) return i:getType() == "RippedSheets" and 0 or nil end)
            if plank and sheet then
                step("ContextMenu_Splint", function() return ISSplint:new(doctor, patient, sheet, plank, bp, true) end, sheet, plank)
            end
        end
    end
    if not dry and #steps > 0 then C.dropKitCache(player) end
    return steps
end

-- Drops --------------------------------------------------------------------------------

--- Things dropped on a body part: Casualties Undead's first, then the game's. Returns
--- "menu" when the part's menu should open instead (a choice to make).
function C.drop(player, bp, items, sx, sy)
    if CU then
        local res = CU.dropItems(player, player, bp, items)
        if res == true then return true end
        if res == "menu" then
            C.openMenu(player, bp, sx, sy, nil)
            return "menu"
        end
    end
    local panel = C.carePanel(player)
    if not panel then return false end
    panel:dropItemsOnBodyPart(bp, items)
    C.dropKitCache(player)
    return true
end

return KnoxHealthCare
