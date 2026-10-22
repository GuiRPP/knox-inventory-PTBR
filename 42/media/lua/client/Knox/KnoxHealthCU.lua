-- The health tab and Casualties Undead (workshop 3805748433, mod id
-- CasualtiesUndead) - taken over from the author's Grid Character Hub.
--
-- CU works with the game's health panel, and most of it reaches Knox's untouched:
--   * its treatments are the game's timed actions turned into minigames; the
--     quick treatment and the drops queue those same actions;
--   * its body part menu entries (amputate, tourniquet, procedures, stumps) are
--     added in ISHealthPanel.doBodyPartContextMenu, which Knox's menus call;
-- What it draws itself is redone here: its stumps and conditions become chips
-- on the part's card, its missing limbs can't be hovered or dropped on, its
-- complication risk is written on each treatment, its vitals stand under the
-- overall health. Everything goes through CU's own API at call time, guarded: a
-- CU update that renames something only loses the extras.

KnoxHealthCU = KnoxHealthCU or {}
local Compat = KnoxHealthCU

-- chip colours (CU's own: red, amber, grey; stumps in its stump colours)
Compat.KIND_COLOR = {
    cu_stump_open   = {0.89, 0.28, 0.28},
    cu_stump_sealed = {0.85, 0.75, 0.40},
    cu_stump_crude  = {0.78, 0.66, 0.38},
    cu_prosthetic   = {0.55, 0.72, 0.62},
    cu_bad          = {0.86, 0.16, 0.16},
    cu_warn         = {0.92, 0.72, 0.16},
    cu_info         = {0.66, 0.67, 0.68},
}

local function api()
    local CU = CasualtiesUndead
    if type(CU) ~= "table" then return nil end
    return CU
end

function Compat.active()
    return api() ~= nil
end

local reported = false
local function guard(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        if not reported then
            reported = true
            print("[Knox] Casualties Undead compat error: " .. tostring(res))
        end
        return nil
    end
    return res
end

--- Worn items CU puts on the character for amputations (cut masks, stumps,
--- prostheses) are the body: the model keeps them. Not the wheelchair.
function Compat.keepOnModel(locId)
    return string.find(locId, "^casualtiesundead:") ~= nil and locId ~= "casualtiesundead:wheelchair"
end

--- add(text, kind, severity) for each of CU's facts about this body part.
function Compat.chips(patient, bp, add)
    local CU = api()
    if not CU or not patient then return end
    guard(function()
        local L = CU.Limbs
        if L and L.anyAmputation and L.anyAmputation(patient) then
            local part = L.partName(bp)
            for _, id in ipairs(L.ORDER) do
                local e = L.entry(patient, id)
                if e and L.stumpPartName(id, e.level) == part then
                    local life = math.max(0, math.min(1, e.life or 1))
                    local key, kind, sev
                    if not e.sealed then
                        key, kind, sev = "IGUI_CU_Stump_Open", "cu_stump_open", 3
                    elseif e.prosthetic and L.isCrude(e.prosthetic) then
                        key = "IGUI_CU_Stump_Crude"
                        if life < 0.25 then kind, sev = "cu_bad", 3
                        elseif life < 0.5 then kind, sev = "cu_warn", 2
                        else kind, sev = "cu_stump_crude", 1 end
                    elseif e.prosthetic then
                        key, kind, sev = "IGUI_CU_Stump_Prosthetic", "cu_prosthetic", 1
                    else
                        key, kind, sev = "IGUI_CU_Stump_Sealed", "cu_stump_sealed", 1
                    end
                    add(getText(key, getText("IGUI_CU_Limb_" .. id), math.floor(life * 100 + 0.5)), kind, sev)
                end
            end
        end
        -- a tourniquet: it stems the bleeding and must come off before it hurts the limb
        local Tq = CU.Tourniquet
        local on = Tq and Tq.active and Tq.active(patient, bp)
        if on then
            local age = CU.worldMinutes and on.at and (CU.worldMinutes() - on.at) or 0
            local harm = Tq.damageMinutes and age >= Tq.damageMinutes()
            local name = getItemNameFromFullType("CasualtiesUndead.Tourniquet") or "Tourniquet"
            add(name, harm and "cu_bad" or "cu_warn", harm and 3 or 2)
        end
        local C = CU.Conditions
        if C and C.enabled and C.enabled() and C.atPart and CU.Terms then
            for _, entry in ipairs(C.atPart(patient, bp)) do
                local g = entry.grade or 1
                local kind = (g >= 3 and "cu_bad") or (g == 2 and "cu_warn") or "cu_info"
                add(CU.Terms.name(entry.id), kind, g >= 3 and 3 or (g == 2 and 2 or 1))
            end
        end
    end)
end

-- Items: CU's for what CU would offer on a body part ("CU:..." keys next to the
-- game's menu label keys; Compat.itemCheck turns a key into the item test).
local SWALLOW = {
    diuretic = "CasualtiesUndead.Diuretic",
    anticoagulant = "CasualtiesUndead.Anticoagulant",
    antibiotics = "Base.Antibiotics",
}
local PROC_TYPES = {
    decompress = {"CasualtiesUndead.ChestNeedle"},
    fluids = {"CasualtiesUndead.SalineBag"},
    strap = {"Base.Bandage", "Base.BandageBox", "Base.RippedSheets", "Base.RippedSheetsDirty"},
}
local SAW_TAGS = {"base:saw", "base:smallsaw", "base:crudesaw"}
local BLADE_CATEGORIES = {"SMALL_BLADE", "LONG_BLADE", "AXE", "SPEAR"}

local function typeIn(types)
    local set = {}
    for _, t in ipairs(types) do set[t] = true end
    return function(item) return set[item:getFullType()] == true end
end

local function isSaw(item)
    local L = api().Limbs
    for _, name in ipairs(L.SAW_TAGS or SAW_TAGS) do
        if L.hasTag(item, name) then return true end
    end
    return false
end

local function isBlade(item)
    if not (instanceof(item, "HandWeapon") and not item:isRanged()) or not WeaponCategory then return false end
    for _, cat in ipairs(BLADE_CATEGORIES) do
        if WeaponCategory[cat] and item:isOfWeaponCategory(WeaponCategory[cat]) then return true end
    end
    return false
end

--- Adds the CU keys for a body part to `keys` (kind: one status, nil: the whole part).
function Compat.treatmentKeys(patient, bp, kind, keys)
    local CU = api()
    if not CU or not patient then return end
    local all = kind == nil or string.sub(kind, 1, 3) == "cu_"
    guard(function()
        local part = BodyPartType.ToString(bp:getType())
        local L, Tq = CU.Limbs, CU.Tourniquet
        if (all or kind == "bleeding") and Tq and Tq.enabled() and Tq.PARTS[part]
                and bp:getBleedingTime() > 0 and not Tq.active(patient, bp) then
            keys["CU:tourniquet"] = true
        end
        if (all or kind == "bite" or kind == "infected") and L and CU.sandbox("Amputation", true) == true
                and L.PART[part] and L.amputationLevels(patient, part) then
            keys["CU:saw"] = true
        end
        if not all then return end
        if L and L.anyAmputation(patient) then
            for _, id in ipairs(L.ORDER) do
                local e = L.entry(patient, id)
                if e and L.stumpPartName(id, e.level) == part then
                    if not e.sealed then keys["CU:heat"] = true
                    elseif not e.prosthetic then keys["CU:prosthetic:" .. id] = true end
                end
            end
        end
        if CU.Defib and (part == "Torso_Upper" or part == "Neck") and CU.Defib.worthIt(patient) then
            keys["CU:defib"] = true
        end
        local C, Pr = CU.Conditions, CU.Procedures
        if C and C.enabled() and Pr then
            for _, id in ipairs(Pr.ORDER) do
                local spec = Pr.LIST[id]
                if spec and C.wants(patient, id) then
                    local site = spec.site
                    if type(site) == "function" then site = site(patient) end
                    if site and site:getType() == bp:getType() then keys["CU:proc:" .. id] = true end
                end
            end
            if #C.atPart(patient, bp) > 0 then
                for id in pairs(SWALLOW) do
                    if C.wants(patient, id) then keys["CU:swallow:" .. id] = true end
                end
            end
        end
    end)
end

--- The item test for a "CU:..." key (nil for other keys).
function Compat.itemCheck(key)
    if type(key) ~= "string" or string.sub(key, 1, 3) ~= "CU:" then return nil end
    local CU = api()
    if not CU then return nil end
    if key == "CU:tourniquet" then return typeIn({"CasualtiesUndead.Tourniquet"}) end
    if key == "CU:saw" then return isSaw end
    if key == "CU:heat" then return function(item) return CU.Heat.isTool(item) end end
    if key == "CU:defib" then return typeIn({CU.Defib.ITEM}) end
    local id = string.match(key, "^CU:prosthetic:(.+)$")
    if id then return function(item) return CU.Limbs.fitsLimb(id, item:getFullType()) end end
    local proc = string.match(key, "^CU:proc:(.+)$")
    if proc then
        if PROC_TYPES[proc] then return typeIn(PROC_TYPES[proc]) end
        if proc == "trepan" then return isSaw end
        if proc == "debride" or proc == "fasciotomy" then return isBlade end
        return nil
    end
    local s = string.match(key, "^CU:swallow:(.+)$")
    if s and SWALLOW[s] then return typeIn({SWALLOW[s]}) end
    return nil
end

--- Is this one of CU's items (it belongs in the health tab's kit)?
function Compat.isMedical(item)
    if not api() then return false end
    local m = item:getModule()
    return m == "CasualtiesUndead"
end

-- Vitals (pulse, blood pressure, SpO2, blood volume), coloured by the thresholds
-- of CU's own chart; nil without CU or with its vitals report off.
local vitalsCache = {}
local VITALS_MS = 400

function Compat.vitals(patient)
    local CU = api()
    if not (CU and CU.Physio and patient and ISCUVitalsUI) then return nil end
    return guard(function()
        if not ISCUVitalsUI:enabled() then return nil end
        local now = getTimestampMs()
        local c = vitalsCache[patient]
        if not c or now - c.t > VITALS_MS then
            c = {t = now, v = CU.Physio.read(patient)}
            vitalsCache[patient] = c
        end
        local v = c.v
        if not v then return nil end
        local dead = v.rhythm == "arrest"
        return {
            {label = getText("IGUI_KnoxHP_VitalPulse"), value = dead and "---" or tostring(math.floor(v.bpm + 0.5)),
             level = dead and 3 or ((v.bpm >= 130 or v.bpm <= 48 or v.rhythm ~= "sinus") and 2 or 1)},
            {label = getText("IGUI_KnoxHP_VitalBP"), value = string.format("%d/%d", v.systolic, v.diastolic),
             level = v.shock and 3 or (v.systolic < 100 and 2 or 1)},
            {label = "SpO2", value = string.format("%d%%", v.saturation),
             level = v.hypoxic and 3 or (v.saturation < 94 and 2 or 1)},
            {label = getText("IGUI_KnoxHP_VitalBlood"), value = string.format("%d%%", math.floor(v.volume * 100 + 0.5)),
             level = v.volume < 0.6 and 3 or (v.volume < 0.82 and 2 or 1)},
        }
    end)
end

-- Drops: CU's items on a body part start CU's action there through CU's own menu
-- functions. true: done; "menu": the part's menu should open instead (a choice
-- to make, or why it can't be done); nil: the game's drop.
local function stumpAt(CU, patient, part)
    local L = CU.Limbs
    if not (L and L.anyAmputation(patient)) then return nil end
    for _, id in ipairs(L.ORDER) do
        local e = L.entry(patient, id)
        if e and L.stumpPartName(id, e.level) == part then return id, e end
    end
    return nil
end

local function dropOne(CU, doctor, patient, bp, item)
    local Mn = CU.Menus
    if not (Mn and doctor and patient) then return nil end
    local part = BodyPartType.ToString(bp:getType())
    local full = item:getFullType()
    if full == "CasualtiesUndead.Tourniquet" then
        local Tq = CU.Tourniquet
        if Tq and Tq.enabled() and Tq.PARTS[part] and not Tq.active(patient, bp) and bp:getBleedingTime() > 0 then
            Mn.tourniquet(doctor, patient, bp, item, false)
            return true
        end
        return "menu"
    end
    if CU.Defib and full == CU.Defib.ITEM then
        if (part == "Torso_Upper" or part == "Neck") and not CU.Defib.refuse(doctor, patient) then
            Mn.defib(doctor, patient)
            return true
        end
        return "menu"
    end
    local id, e = stumpAt(CU, patient, part)
    if id and not e.sealed and CU.Heat and CU.Heat.isTool(item) then
        if CU.Heat.temp(item) >= CU.Heat.threshold() then
            Mn.cauterize(doctor, patient, item, id)
            return true
        end
        return "menu"
    end
    if id and e.sealed and not e.prosthetic and CU.Limbs.fitsLimb(id, full) then
        Mn.fitProsthetic(doctor, patient, item, id)
        return true
    end
    if isSaw(item) and CU.Limbs.PART[part] and CU.sandbox("Amputation", true) == true then return "menu" end
    local C, Pr = CU.Conditions, CU.Procedures
    if C and Pr then
        for proc, types in pairs(PROC_TYPES) do
            if proc ~= "strap" and typeIn(types)(item) and C.wants(patient, proc) then
                local site = Pr.LIST[proc] and Pr.LIST[proc].site
                if type(site) == "function" then site = site(patient) end
                local onSite = site and site:getType() == bp:getType()
                if proc == "fluids" then onSite = string.find(part, "Arm") ~= nil or string.find(part, "Hand") ~= nil end
                if onSite and not Pr.refuse(doctor, patient, proc) then
                    Mn.procedure(doctor, patient, proc)
                    return true
                end
                return "menu"
            end
        end
    end
    local spec = Mn.MEDICINE and Mn.MEDICINE[full]
    if spec and spec.swallow and doctor == patient then
        Mn.swallow(doctor, item)
        return true
    end
    return nil
end

function Compat.dropItems(doctor, patient, bp, items)
    local CU = api()
    if not CU then return nil end
    return guard(function()
        for _, item in ipairs(items) do
            local res = dropOne(CU, doctor, patient, bp, item)
            if res then return res end
        end
        return nil
    end)
end

-- Status menus: CU's entries that treat a game status stay in that status' menu.
local MENU_FOR_KIND = {
    bleeding = {"ContextMenu_CU_TourniquetApply", "ContextMenu_CU_TourniquetRemove"},
    bite     = {"ContextMenu_CU_Amputate"},
}

local function labelPrefix(key)
    local s = getText(key)
    if s == key then return nil end
    local cut = string.find(s, "%", 1, true)
    if cut then s = string.sub(s, 1, cut - 1) end
    s = string.gsub(s, "%s+$", "")
    return s ~= "" and s or nil
end

function Compat.menuEntryFor(kind, name)
    local keys = api() and MENU_FOR_KIND[kind]
    if not keys or type(name) ~= "string" then return false end
    for _, key in ipairs(keys) do
        local p = labelPrefix(key)
        if p and string.sub(name, 1, #p) == p then return true end
    end
    return false
end

-- Complication risk: CU rolls for one after every treatment it knows; each such
-- entry of the menus says the chance of it for this doctor ("Remove bandage
-- (risk 6-25%)" - with a minigame it depends on how well it's played).
local RISK_VANILLA = {
    ContextMenu_Bandage           = {"ISApplyBandage", true},
    ContextMenu_Remove_Bandage    = {"ISApplyBandage", false},
    ContextMenu_Disinfect         = {"ISDisinfect"},
    ContextMenu_Stitch            = {"ISStitch", true},
    ContextMenu_Remove_Stitch     = {"ISStitch", false},
    ContextMenu_Remove_Glass      = {"ISRemoveGlass"},
    ContextMenu_Remove_Bullet     = {"ISRemoveBullet"},
    ContextMenu_Splint            = {"ISSplint", true},
    ContextMenu_Remove_Splint     = {"ISSplint", false},
    ContextMenu_Clean_Burn        = {"ISCleanBurn"},
    ContextMenu_PlantainCataplasm = {"ISPlantainCataplasm"},
    ContextMenu_ComfreyCataplasm  = {"ISComfreyCataplasm"},
    ContextMenu_GarlicCataplasm   = {"ISGarlicCataplasm"},
    ContextMenu_CU_Amputate       = {"CUAmputateAction"},
    ContextMenu_CU_Procedures     = {"CUProcedureAction"},
    ContextMenu_CU_Dose           = {"CUDoseAction"},
}

local function cuEntryAction(M, opt)
    local f = opt.onSelect
    if not f then return nil end
    if f == M.tourniquet then return "CUTourniquetAction", {remove = opt.param4 == true} end
    if f == M.cauterize then return "CUCauterizeAction", {} end
    if f == M.fitProsthetic then return "CUFitProstheticAction", {} end
    if f == M.removeProsthetic then return "CURemoveProstheticAction", {} end
    if f == M.procedure then return "CUProcedureAction", {} end
    if f == M.dose then return "CUDoseAction", {} end
    return nil
end

local function startsWithLabel(name, label)
    return name == label or string.sub(name, 1, #label + 2) == label .. " ("
end

local function riskText(CU, doctor, className, action)
    local Co = CU.Complications
    if not (Co and Co.enabled and Co.enabled() and Co.chance and Co.FOR and Co.FOR[className]) then return nil end
    local level = doctor:getPerkLevel(Perks.Doctor)
    local play = false
    if CasualtiesUndeadActions and CasualtiesUndeadActions.wouldPlay then
        play = CasualtiesUndeadActions.wouldPlay(doctor, className, action) == true
    elseif CU.minigameAllowed then
        play = CU.minigameAllowed(className, action) == true
    end
    local lo, hi
    if play then lo, hi = Co.chance(level, 1), Co.chance(level, 0)
    else lo = Co.chance(level, nil); hi = lo end
    local a, b = math.floor(lo * 100 + 0.5), math.floor(hi * 100 + 0.5)
    if b <= 0 then return nil end
    return getText("IGUI_KnoxHP_Risk") .. " " .. ((a == b) and (a .. "%") or (a .. "-" .. b .. "%"))
end

function Compat.addRisks(context, doctor)
    local CU = api()
    if not (CU and context and doctor) then return end
    guard(function()
        local labels = {}
        for key, spec in pairs(RISK_VANILLA) do
            local l = getText(key)
            if l ~= key then labels[#labels + 1] = {label = l, spec = spec} end
        end
        for _, opt in ipairs(context.options) do
            if not opt.notAvailable and type(opt.name) == "string" then
                local className, action
                if CU.Menus then className, action = cuEntryAction(CU.Menus, opt) end
                if not className then
                    for _, l in ipairs(labels) do
                        if startsWithLabel(opt.name, l.label) then
                            className = l.spec[1]
                            action = {doIt = l.spec[2] ~= false}
                            break
                        end
                    end
                end
                if className then
                    local ok, text = pcall(riskText, CU, doctor, className, action)
                    if ok and text then opt.name = opt.name .. " (" .. text .. ")" end
                end
            end
        end
    end)
end

--- Is the body part with this index gone (amputated, not even a stump)?
function Compat.isMissing(patient, index)
    local CU = api()
    if not (CU and CU.Limbs and CU.Limbs.isMissing and patient) then return false end
    return guard(function()
        if not CU.Limbs.anyAmputation(patient) then return false end
        return CU.Limbs.isMissing(patient, BodyPartType.ToString(BodyPartType.FromIndex(index))) == true
    end) == true
end

return KnoxHealthCU
