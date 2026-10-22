-- What the health tab shows, read from the game (KnoxHealthPanel draws it):
--   * the body in seven zones, as in Tarkov: head, thorax, stomach, two arms, two
--     legs - each the game's body parts in it, its health their average, destroyed
--     when one of them is at 0;
--   * each body part's statuses ("chips"): a wound, what treats it, how long it
--     has left to heal, how bad it is (3 now, 2 untreated / minor, 1 treated);
--   * the healing times and the damage pace, measured (the game says neither);
--   * the character's moodles and stats for the left column.
-- Taken over from the author's Grid Character Hub (Parts, Healing, Header), in
-- Knox's palette and names; both mods can be on together (their own mod data).

require "Knox/KnoxTheme"
require "Knox/KnoxHealthCU"

KnoxHealthData = KnoxHealthData or {}
local H = KnoxHealthData
local CU = KnoxHealthCU

-- Zones ------------------------------------------------------------------------
-- Body part indices (BodyPartType): 0 Hand_L 1 Hand_R 2 ForeArm_L 3 ForeArm_R
-- 4 UpperArm_L 5 UpperArm_R 6 Torso_Upper 7 Torso_Lower 8 Head 9 Neck 10 Groin
-- 11 UpperLeg_L 12 UpperLeg_R 13 LowerLeg_L 14 LowerLeg_R 15 Foot_L 16 Foot_R.
-- The character's left is the screen's right (the model faces the player).
H.ZONES = {
    {id = "head",    parts = {8, 9}},
    {id = "thorax",  parts = {6}},
    {id = "stomach", parts = {7, 10}},
    {id = "rarm",    parts = {5, 3, 1}},
    {id = "larm",    parts = {4, 2, 0}},
    {id = "rleg",    parts = {12, 14, 16}},
    {id = "lleg",    parts = {11, 13, 15}},
}
H.ZONE = {}
H.zoneOfPart = {}
for i, z in ipairs(H.ZONES) do
    z.order = i
    H.ZONE[z.id] = z
    for _, p in ipairs(z.parts) do H.zoneOfPart[p] = z end
end

function H.zoneName(z)
    return getText("IGUI_KnoxHP_Zone_" .. z.id)
end

function H.bodyParts(player)
    return player:getBodyDamage():getBodyParts()
end

function H.part(player, index)
    return player:getBodyDamage():getBodyParts():get(index)
end

function H.indexOf(bp)
    return BodyPartType.ToIndex(bp:getType())
end

function H.partName(bp)
    return BodyPartType.getDisplayName(bp:getType())
end

--- Is this body part gone (Casualties Undead's amputation)?
function H.missing(player, index)
    return CU ~= nil and CU.isMissing(player, index) == true
end

--- The zone's state: hp (0..100, the average of its parts still there), lo (its
--- worst part), destroyed (one of its parts at 0 - as a limb in Tarkov; the whole
--- zone at 0 can't be seen: the game takes the parts' losses, weighted, from the
--- overall health, and a leg at 0 everywhere is death), missing (every part amputated).
function H.zoneState(player, z)
    local sum, n, lo, zero, gone = 0, 0, 100, 0, 0
    local bps = player:getBodyDamage():getBodyParts()
    for _, i in ipairs(z.parts) do
        if H.missing(player, i) then
            gone = gone + 1
        else
            local h = math.max(0, math.min(100, bps:get(i):getHealth()))
            sum, n = sum + h, n + 1
            if h < lo then lo = h end
            if h <= 0 then zero = zero + 1 end
        end
    end
    local hp = n > 0 and sum / n or 0
    return {
        hp = hp, lo = n > 0 and lo or 0,
        destroyed = n > 0 and zero > 0,
        missing = gone == #z.parts,
    }
end

-- Colours ---------------------------------------------------------------------
-- Every status its own colour: its square on the zone's plate, its row on the
-- card, its segment of the overall health bar, its tint on the model.
local function rgb(r, g, b) return {r = r, g = g, b = b} end

H.KIND_COLOR = {
    bleeding     = rgb(0.86, 0.18, 0.18),
    bite         = rgb(0.58, 0.32, 0.80),
    deepwound    = rgb(0.78, 0.20, 0.50),
    infected     = rgb(0.62, 0.72, 0.18),
    fracture     = rgb(0.82, 0.80, 0.66),
    bullet       = rgb(0.42, 0.55, 0.75),
    glass        = rgb(0.30, 0.72, 0.82),
    cut          = rgb(0.92, 0.50, 0.15),
    scratch      = rgb(0.92, 0.78, 0.28),
    burn         = rgb(0.70, 0.32, 0.12),
    pain         = rgb(0.80, 0.60, 0.50),
    stiffness    = rgb(0.60, 0.60, 0.72),
    dirtybandage = rgb(0.60, 0.48, 0.30),
    bandaged     = rgb(0.62, 0.70, 0.42),
    stitched     = rgb(0.62, 0.70, 0.42),
    splinted     = rgb(0.62, 0.70, 0.42),
    poultice     = rgb(0.50, 0.66, 0.40),
    other        = rgb(0.45, 0.45, 0.45),   -- health lost to no wound (hunger, sickness...)
}
if CU then
    for k, c in pairs(CU.KIND_COLOR) do H.KIND_COLOR[k] = rgb(c[1], c[2], c[3]) end
end
-- a treatment over a wound that has healed (it can come off): mint
H.HEALED = rgb(0.36, 0.80, 0.64)

function H.kindColor(kind)
    return H.KIND_COLOR[kind] or H.KIND_COLOR.other
end

--- The colour of a severity (3 now, 2 untreated, 1 treated) in the palette.
function H.sevColor(sev)
    local C = KnoxTheme.color
    if sev >= 3 then return C.bad end
    if sev >= 2 then return C.warn end
    return C.good
end

--- The colour of a health value 0..100 (green, sand, amber, red; black at 0).
function H.hpColor(hp)
    local C = KnoxTheme.color
    if hp <= 0 then return rgb(0.30, 0.30, 0.30) end
    if hp >= 85 then return C.good end
    if hp >= 50 then return C.warn end
    return C.bad
end

-- Statuses that take health, in the bar's order, with their weight when a part's
-- lost health is split between several of its statuses.
H.DAMAGE_KINDS = {
    {kind = "bleeding",  weight = 3},
    {kind = "bite",      weight = 3},
    {kind = "deepwound", weight = 2.5},
    {kind = "infected",  weight = 2},
    {kind = "fracture",  weight = 2},
    {kind = "burn",      weight = 2},
    {kind = "bullet",    weight = 1.5},
    {kind = "glass",     weight = 1.5},
    {kind = "cut",       weight = 1.5},
    {kind = "scratch",   weight = 1},
}
H.DAMAGE_WEIGHT = {}
for _, d in ipairs(H.DAMAGE_KINDS) do H.DAMAGE_WEIGHT[d.kind] = d.weight end

-- The game's treatment entries (the body part menu's labels) that act on each
-- status. The game's menu offers every treatment the part could take; a status'
-- menu keeps the ones for it:
--   bandage   - stops bleeding, covers open wounds
--   disinfect - lowers / prevents a wound's infection
--   stitch    - deep wounds only
--   plantain  - scratches, cuts, deep wounds heal faster; comfrey - fractures;
--   garlic    - an infection
-- (a wound under a bandage: "Cut - Bandaged" - taking the bandage off is on the
-- wound's own row; not on an infection, glass or a bullet)
H.TREAT = {
    bleeding     = {"ContextMenu_Bandage"},
    bite         = {"ContextMenu_Bandage", "ContextMenu_Disinfect", "ContextMenu_Remove_Bandage"},
    deepwound    = {"ContextMenu_Stitch", "ContextMenu_Bandage", "ContextMenu_Disinfect", "ContextMenu_PlantainCataplasm", "ContextMenu_Remove_Bandage"},
    fracture     = {"ContextMenu_Splint", "ContextMenu_ComfreyCataplasm"},
    infected     = {"ContextMenu_Disinfect", "ContextMenu_GarlicCataplasm"},
    bullet       = {"ContextMenu_Remove_Bullet"},
    glass        = {"ContextMenu_Remove_Glass"},
    cut          = {"ContextMenu_Bandage", "ContextMenu_Disinfect", "ContextMenu_PlantainCataplasm", "ContextMenu_Remove_Bandage"},
    scratch      = {"ContextMenu_Bandage", "ContextMenu_Disinfect", "ContextMenu_PlantainCataplasm", "ContextMenu_Remove_Bandage"},
    burn         = {"ContextMenu_Clean_Burn", "ContextMenu_Bandage", "ContextMenu_Remove_Bandage"},
    bandaged     = {"ContextMenu_Remove_Bandage"},
    dirtybandage = {"ContextMenu_Remove_Bandage"},
    stitched     = {"ContextMenu_Remove_Stitch"},
    splinted     = {"ContextMenu_Remove_Splint"},
}

local textCache = {}
local function T(key)
    local v = textCache[key]
    if not v then
        v = getText(key)
        textCache[key] = v
    end
    return v
end
H.T = T

local function suffix(key) return " (" .. T(key) .. ")" end

-- Healing ---------------------------------------------------------------------
-- The game doesn't say how fast a wound heals: each one has a timer (scratch
-- time, cut time, fracture time...) counted down at a rate that hangs on a lot
-- (bandage, disinfection, splint, sleep, food, Fast / Slow Healer, other mods).
-- So the timers are measured: sampled once a game minute, the rate is how much a
-- timer went down over the last game hours, the time left what's left over it.
--   * a timer that went up started over (a new wound of the kind);
--   * one that didn't go down over a while: "not healing";
--   * stitches count the other way: they can come out at STITCH_READY.
local WINDOW_H = 2.0
local MIN_H = 10 / 60
local STEP_H = 1 / 60
local STITCH_READY = 40
local EPS = 0.0001
H.STITCH_READY = STITCH_READY

local TIMER = {
    bleeding  = function(bp) return bp:getBleedingTime() end,
    bite      = function(bp) return bp:getBiteTime() end,
    deepwound = function(bp) return bp:getDeepWoundTime() end,
    infected  = function(bp) return bp:getWoundInfectionLevel() end,
    fracture  = function(bp) return bp:getFractureTime() end,
    burn      = function(bp) return bp:getBurnTime() end,
    cut       = function(bp) return bp:getCutTime() end,
    scratch   = function(bp) return bp:getScratchTime() end,
    stitched  = function(bp) return bp:getStitchTime() end,
}
-- statuses that show another's timer: a splint the fracture's; a bandage the
-- longest of the wounds under it
local SHOWS = {
    splinted = {"fracture"},
    bandaged = {"deepwound", "bite", "burn", "cut", "scratch", "bleeding"},
    dirtybandage = {"deepwound", "bite", "burn", "cut", "scratch", "bleeding"},
}
-- no time at all for what doesn't heal on its own
local NO_ESTIMATE = {infected = true, bite = true}

local history = {}   -- [patient][part index][timer] = samples {t, v}

local function worldHours() return getGameTime():getWorldAgeHours() end

-- How the part is treated: a change changes the healing speed, the samples from
-- before it don't count.
local function treatment(bp)
    local poultice = bp:getPlantainFactor() > 0 or bp:getComfreyFactor() > 0 or bp:getGarlicFactor() > 0
    return (bp:bandaged() and (bp:getBandageLife() > 0 and "B" or "b") or "-")
        .. (bp:stitched() and "S" or "-")
        .. (bp:getSplintFactor() > 0 and "P" or "-")
        .. (poultice and "C" or "-")
end

-- Where each timer stood when its treatment began (the start of a row's progress
-- bar), in the patient's mod data so a loaded save goes on from there.
local function startStore(patient)
    local md = patient:getModData()
    md.KnoxHeal = md.KnoxHeal or {}
    return md.KnoxHeal
end

local function seriesStart(patient, i, kind, v, treat, fresh)
    local store = startStore(patient)
    local key = i .. ":" .. kind
    local e = store[key]
    if fresh and e and e.t == treat and tonumber(e.v0) and e.v0 >= v then return e.v0 end
    store[key] = {v0 = v, t = treat}
    return v
end

local function sample(patient)
    local t = worldHours()
    local h = history[patient]
    if not h or t < h.last then
        h = {last = -1, treat = {}}
        history[patient] = h
    end
    if h.last >= 0 and t - h.last < STEP_H then return h end
    h.last = t
    local bps = patient:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do
        local bp = bps:get(i)
        local parts = h[i]
        local treat = treatment(bp)
        local fresh = not parts
        if not parts or h.treat[i] ~= treat then
            parts = {}
            h[i] = parts
            h.treat[i] = treat
        end
        for kind, read in pairs(TIMER) do
            local v = read(bp) or 0
            local s = parts[kind]
            if v <= 0 then
                startStore(patient)[i .. ":" .. kind] = nil
                parts[kind] = nil
            else
                local last = s and s[#s]
                local up = kind == "stitched"
                local restart = last ~= nil and ((not up and kind ~= "infected" and v > last.v + EPS)
                    or (up and v < last.v - EPS))
                if not s or restart then
                    s = {v0 = seriesStart(patient, i, kind, v, treat, fresh and not restart)}
                    parts[kind] = s
                end
                table.insert(s, {t = t, v = v})
                while #s > 2 and t - s[1].t > WINDOW_H do table.remove(s, 1) end
            end
        end
    end
    return h
end

-- Game hours left for one timer: a number, false (not healing), nil (not known yet).
local function left(h, index, kind)
    local s = h[index] and h[index][kind]
    if not s or #s < 2 then return nil end
    local first, last = s[1], s[#s]
    local dt = last.t - first.t
    if dt < MIN_H then return nil end
    if kind == "stitched" then
        if last.v >= STITCH_READY then return nil end
        local rate = (last.v - first.v) / dt
        if rate <= EPS then return false end
        return (STITCH_READY - last.v) / rate
    end
    local rate = (first.v - last.v) / dt
    if rate <= EPS then return false end
    return last.v / rate
end

--- Game hours left for a status of this body part (false: not healing; nil: no
--- timer, or not known yet).
function H.healEstimate(patient, bp, kind)
    if not patient or NO_ESTIMATE[kind] then return nil end
    local ok, h = pcall(sample, patient)
    if not ok or not h then return nil end
    local index = H.indexOf(bp)
    local timers = SHOWS[kind] or (TIMER[kind] and {kind})
    if not timers then return nil end
    local best, any = nil, false
    for _, timer in ipairs(timers) do
        if not NO_ESTIMATE[timer] then
            local v = left(h, index, timer)
            if v == false then return false end
            if v then
                any = true
                if not best or v > best then best = v end
            end
        end
    end
    return any and best or nil
end

--- How far a treated status has healed since its treatment began, 0..1.
function H.healProgress(patient, bp, kind)
    if kind == "stitched" then
        return math.max(0, math.min(1, bp:getStitchTime() / STITCH_READY))
    end
    if not patient or NO_ESTIMATE[kind] then return nil end
    local ok, h = pcall(sample, patient)
    if not ok or not h then return nil end
    local parts = h[H.indexOf(bp)]
    local timers = SHOWS[kind] or (TIMER[kind] and {kind})
    if not (parts and timers) then return nil end
    local worst
    for _, timer in ipairs(timers) do
        local s = parts[timer]
        if not NO_ESTIMATE[timer] and s and #s > 0 and s.v0 and s.v0 > 0 then
            local p = math.max(0, math.min(1, 1 - s[#s].v / s.v0))
            if not worst or p < worst then worst = p end
        end
    end
    return worst
end

--- Is what this treatment was for healed (it can come off)?
function H.healed(bp, kind)
    if kind == "bandaged" or kind == "dirtybandage" then
        return bp:getScratchTime() <= 0 and bp:getCutTime() <= 0 and bp:getDeepWoundTime() <= 0
            and bp:getBurnTime() <= 0 and bp:getBleedingTime() <= 0 and bp:getBiteTime() <= 0
            and not bp:bitten() and bp:getWoundInfectionLevel() <= 0
            and not bp:haveGlass() and not bp:haveBullet()
    elseif kind == "splinted" then
        return bp:getFractureTime() <= 0
    elseif kind == "stitched" then
        return bp:getStitchTime() >= STITCH_READY
    end
    return false
end

--- "~40 min" / "~5 h" / "~3 d", or "not healing" (false).
function H.healText(hours)
    if hours == false then return T("IGUI_KnoxHP_NotHealing") end
    if hours < 1 then
        local m = math.max(5, math.floor(hours * 60 / 5 + 0.5) * 5)
        if m < 60 then return getText("IGUI_KnoxHP_HealMin", m) end
        hours = 1
    end
    if hours < 36 then return getText("IGUI_KnoxHP_HealHours", math.max(1, math.floor(hours + 0.5))) end
    return getText("IGUI_KnoxHP_HealDays", math.floor(hours / 24 + 0.5))
end

-- Statuses of a body part ------------------------------------------------------

-- passive on their own (a bandage, stitches, a splint until what they treat healed)
local PASSIVE = {
    bandaged = true, stitched = true, splinted = true, poultice = true,
    pain = true, stiffness = true,
    cu_prosthetic = true, cu_stump_crude = true, cu_info = true,
}
local WOUND = {cut = true, scratch = true, deepwound = true, burn = true}

--- The doctor's level the statuses are told with (the game's rule: a better
--- doctor sees more - how bad a wound is, an infection early).
function H.doctorLevel(player)
    return player:getPerkLevel(Perks.Doctor)
end

--- The statuses ("chips") of a body part, active first, and its severity:
--- {chips = {{text, label, kind, sev, color, passive, healed, heal, progress}}, sev, healed}
function H.buildPartInfo(patient, bp, doc)
    local chips, sev = {}, 0
    local function add(text, s, kind)
        table.insert(chips, {text = text, kind = kind, sev = s})
        if s > sev then sev = s end
    end
    doc = doc or 0
    local cheat = ISHealthPanel and ISHealthPanel.cheat
    local bandaged = bp:bandaged()
    local covered = (bandaged and bp:getBandageLife() > 0) or bp:stitched()
    local dirty = bandaged and bp:getBandageLife() <= 0
    local coverText = bandaged and T(dirty and "IGUI_health_DirtyBandage" or "IGUI_health_Bandaged")
    local covers = false
    -- a wound under a bandage: the game says scratched() / isCut() / bitten() are
    -- false there, but its timer runs; shown as "Cut - Bandaged"
    local function under(text)
        if not bandaged then return text end
        covers = true
        return text .. " - " .. coverText
    end

    if bp:bleeding() then add(T("IGUI_health_Bleeding"), 3, "bleeding") end
    if bp:bitten() or bp:getBiteTime() > 0 then add(under(T("IGUI_health_Bitten")), 3, "bite") end
    if bp:deepWounded() or (bandaged and bp:getDeepWoundTime() > 0) then
        local t = ""
        if doc > 4 or cheat then
            if bp:getDeepWoundTime() > 10 then t = suffix("IGUI_health_Severe")
            elseif bp:getDeepWoundTime() > 8 then t = suffix("IGUI_health_Moderate") end
        end
        add(under(T("IGUI_health_DeepWound") .. t), covered and 1 or 3, "deepwound")
    end
    if bp:getFractureTime() > 0 and bp:getSplintFactor() == 0 then
        local t = ""
        if doc > 6 or cheat then
            if bp:getFractureTime() > 50 then t = suffix("IGUI_health_Severe")
            elseif bp:getFractureTime() > 20 then t = suffix("IGUI_health_Moderate") end
        end
        add(T("IGUI_health_Fracture") .. t, 3, "fracture")
    end
    if bp:isInfectedWound() then
        if doc > 8 or (bp:getWoundInfectionLevel() * 10 >= (2.5 - doc)) or cheat then
            add(T("IGUI_health_Infected"), 3, "infected")
        end
    end
    if bp:haveBullet() then add(T("IGUI_health_LodgedBullet"), 3, "bullet") end
    if bp:haveGlass() then add(T("IGUI_health_LodgedGlassShards"), 3, "glass") end
    if bp:isCut() or (bandaged and bp:getCutTime() > 0) then
        local t = ""
        if doc > 2 or cheat then
            if bp:getCutTime() > 17 then t = suffix("IGUI_health_Severe")
            elseif bp:getCutTime() > 14 then t = suffix("IGUI_health_Moderate") end
        end
        add(under(T("IGUI_health_Cut") .. t), covered and 1 or 2, "cut")
    end
    if bp:scratched() or (bandaged and bp:getScratchTime() > 0) then
        local t = ""
        if doc > 2 or cheat then
            if bp:getScratchTime() > 17 then t = suffix("IGUI_health_Severe")
            elseif bp:getScratchTime() > 14 then t = suffix("IGUI_health_Moderate") end
        end
        add(under(T("IGUI_health_Scratched") .. t), covered and 1 or 2, "scratch")
    end
    if bp:getBurnTime() > 0 then
        local t = ""
        if not bandaged and (doc > 4 or cheat) and bp:isNeedBurnWash() then t = suffix("IGUI_health_NeedCleaning") end
        add(under(T("IGUI_health_Burned") .. t), covered and 1 or 2, "burn")
    end
    if bp:getAdditionalPain() > 10 then
        add(T(bp:getAdditionalPain() > 50 and "IGUI_health_HeavyPain" or "IGUI_health_Pain"), 2, "pain")
    end
    if bp:getStiffness() >= 5 then
        add(T(bp:getStiffness() < 20 and "IGUI_health_MinorStiffness" or "IGUI_health_Stiffness"), 2, "stiffness")
    end
    if bandaged and not covers then
        if not dirty then add(T("IGUI_health_Bandaged"), 1, "bandaged")
        else add(T("IGUI_health_DirtyBandage"), 2, "dirtybandage") end
    end
    if bp:stitched() then
        local t = ""
        if doc > 6 or cheat then
            t = bp:getStitchTime() > STITCH_READY and suffix("IGUI_health_Good") or suffix("IGUI_health_NeedTime")
        end
        add(T("IGUI_health_Stitched") .. t, 1, "stitched")
    end
    if bp:getSplintFactor() > 0 then
        local t = ""
        if doc > 4 or cheat then
            if bp:getSplintFactor() > 4 then t = suffix("IGUI_health_Good")
            elseif bp:getFractureTime() > 2 then t = suffix("IGUI_health_Moderate") end
        end
        add(T("IGUI_health_Splinted") .. t, 1, "splinted")
    end
    if bp:getPlantainFactor() > 0 then add(T("ContextMenu_PlantainCataplasm"), 1, "poultice") end
    if bp:getComfreyFactor() > 0 then add(T("ContextMenu_ComfreyCataplasm"), 1, "poultice") end
    if bp:getGarlicFactor() > 0 then add(T("ContextMenu_GarlicCataplasm"), 1, "poultice") end
    if CU then CU.chips(patient, bp, function(text, kind, s) add(text, s, kind) end) end

    local healed = false
    local cleanCover = bandaged and not dirty
    local C = KnoxTheme.color
    for _, c in ipairs(chips) do
        local k = c.kind
        c.color = H.kindColor(k)
        if H.healed(bp, k) then
            c.healed, healed = true, true
            c.color = H.HEALED
        else
            local h = H.healEstimate(patient, bp, k)
            if h ~= nil then c.heal = H.healText(h) c.notHealing = h == false end
        end
        -- active (something to do now) or passive (going its own way): the card
        -- shows the active ones first, the passive ones dimmed under them
        if c.healed or k == "bite" then c.passive = false
        elseif cleanCover and WOUND[k] then c.passive = true
        else c.passive = PASSIVE[k] == true end
        -- being treated: a wound under a clean bandage, a bandage, stitches, a
        -- splint - filled as it heals
        local treated = (WOUND[k] and cleanCover) or k == "bandaged" or k == "stitched" or k == "splinted"
        if treated and not c.healed then
            c.treated = true
            c.progress = H.healProgress(patient, bp, k)
        end
        if WOUND[k] and dirty then c.color = H.KIND_COLOR.dirtybandage end
        c.sevColor = c.healed and H.HEALED or (c.treated and C.good or H.sevColor(c.sev))
        c.label = c.heal and (c.text .. "  " .. c.heal) or c.text
    end
    local ordered = {}
    for _, c in ipairs(chips) do if not c.passive then table.insert(ordered, c) end end
    for _, c in ipairs(chips) do if c.passive then table.insert(ordered, c) end end
    return {chips = ordered, sev = sev, healed = healed}
end

-- partInfo is asked for many times a frame (plates, cards, the model, the pace):
-- kept per body part for the current millisecond.
local infoCache, infoCacheT, infoDoc = {}, -1, -1
function H.partInfo(patient, bp)
    local now = getTimestampMs()
    local doc = H.doctorLevel(patient)
    if now ~= infoCacheT or doc ~= infoDoc then infoCache, infoCacheT, infoDoc = {}, now, doc end
    local info = infoCache[bp]
    if not info then
        info = H.buildPartInfo(patient, bp, doc)
        infoCache[bp] = info
    end
    return info
end

--- Does this body part have anything to show (the game's own rule for its list)?
function H.damaged(bp)
    return bp:HasInjury() or bp:bandaged() or bp:stitched() or bp:getSplintFactor() > 0
        or bp:getAdditionalPain() > 10 or bp:getStiffness() > 5
end

--- The zone's statuses, one per kind (the worst of its parts'), for the plate's
--- squares: {{kind, color, sev, healed}} by severity.
function H.zoneKinds(patient, z)
    local by, list = {}, {}
    local bps = patient:getBodyDamage():getBodyParts()
    for _, i in ipairs(z.parts) do
        local bp = bps:get(i)
        if H.damaged(bp) or bp:getBleedingTime() > 0 then
            for _, c in ipairs(H.partInfo(patient, bp).chips) do
                local had = by[c.kind]
                if not had or c.sev > had.sev then
                    local e = {kind = c.kind, color = c.color, sev = c.healed and 0 or c.sev, healed = c.healed, treated = c.treated}
                    if had then
                        for j, v in ipairs(list) do if v == had then list[j] = e end end
                    else
                        table.insert(list, e)
                    end
                    by[c.kind] = e
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.sev ~= b.sev then return a.sev > b.sev end
        return a.kind < b.kind
    end)
    return list
end

--- The zone's worst severity (0: nothing).
function H.zoneSev(patient, z)
    local sev = 0
    local bps = patient:getBodyDamage():getBodyParts()
    for _, i in ipairs(z.parts) do
        local bp = bps:get(i)
        if H.damaged(bp) then
            local s = H.partInfo(patient, bp).sev
            if s > sev then sev = s end
        end
    end
    return sev
end

--- Is something in the zone bleeding (its plate pulses)?
function H.zoneBleeding(patient, z)
    local bps = patient:getBodyDamage():getBodyParts()
    for _, i in ipairs(z.parts) do
        if bps:get(i):bleeding() then return true end
    end
    return false
end

-- The most damaging wound of a part, those under a bandage too (for the model).
function H.hiddenWoundKind(bp)
    local found = {
        bleeding  = bp:getBleedingTime() > 0,
        bite      = bp:bitten() or bp:getBiteTime() > 0,
        deepwound = bp:getDeepWoundTime() > 0,
        infected  = bp:getWoundInfectionLevel() > 0,
        fracture  = bp:getFractureTime() > 0,
        burn      = bp:getBurnTime() > 0,
        bullet    = bp:haveBullet(),
        glass     = bp:haveGlass(),
        cut       = bp:getCutTime() > 0,
        scratch   = bp:getScratchTime() > 0,
    }
    for _, d in ipairs(H.DAMAGE_KINDS) do
        if found[d.kind] then return d.kind end
    end
    return nil
end

-- Damage pace ------------------------------------------------------------------
-- How fast each status takes health, measured: the overall health and every
-- part's are sampled once a game minute over the last game hour; the overall drop
-- per hour is split between the statuses by where it happens (a part's own drop
-- to its damaging statuses by weight, a drop no part explains to "other").
local TREND_WINDOW_H = 1.0
local TREND_MIN_H = 3 / 60
local trends = {}

local function sampleTrend(patient)
    local now = worldHours()
    local s = trends[patient]
    if not s or (s[#s] and now < s[#s].t) then
        s = {}
        trends[patient] = s
    end
    local last = s[#s]
    if last and now - last.t > TREND_WINDOW_H then
        s = {}
        trends[patient] = s
        last = nil
    end
    if not last or now - last.t >= STEP_H then
        local parts = {}
        local bps = patient:getBodyDamage():getBodyParts()
        for i = 0, bps:size() - 1 do parts[i] = bps:get(i):getHealth() end
        table.insert(s, {t = now, h = patient:getBodyDamage():getHealth(), parts = parts})
        while #s > 2 and now - s[1].t > TREND_WINDOW_H do table.remove(s, 1) end
    end
    return s, now
end

--- {[kind] = health per game hour} of the kinds taking health now; {} when the
--- health holds or heals; nil while there's too little data.
function H.damageRates(patient)
    local ok, s, now = pcall(sampleTrend, patient)
    if not ok or not s or not s[1] then return nil end
    local first = s[1]
    local dt = now - first.t
    if dt < TREND_MIN_H then return nil end
    local health = patient:getBodyDamage():getHealth()
    local total = (first.h - health) / dt
    local rates = {}
    if total <= 0 then return rates end
    local share, shareSum = {}, 0
    local bps = patient:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do
        local bp = bps:get(i)
        local was = first.parts[i]
        local drop = was and (was - bp:getHealth()) or 0
        if drop > 0 then
            local kinds, wsum = {}, 0
            if H.damaged(bp) then
                for _, c in ipairs(H.partInfo(patient, bp).chips) do
                    local wgt = H.DAMAGE_WEIGHT[c.kind]
                    if wgt and not kinds[c.kind] then
                        kinds[c.kind] = wgt
                        wsum = wsum + wgt
                    end
                end
            end
            if wsum > 0 then
                for kind, wgt in pairs(kinds) do share[kind] = (share[kind] or 0) + drop * wgt / wsum end
            else
                share.other = (share.other or 0) + drop
            end
            shareSum = shareSum + drop
        end
    end
    if shareSum <= 0 then
        rates.other = total
    else
        for kind, v in pairs(share) do rates[kind] = total * v / shareSum end
    end
    return rates
end

--- How fast the overall health goes: health lost per game hour (below 0: it
--- comes back), nil while there's too little data.
function H.healthPace(patient)
    local ok, s, now = pcall(sampleTrend, patient)
    if not ok or not s or not s[1] then return nil end
    local dt = now - s[1].t
    if dt < TREND_MIN_H then return nil end
    return (s[1].h - patient:getBodyDamage():getHealth()) / dt
end

--- Counters for the overall block: wounds (parts with an injury or an open
--- stump), bleeding parts, bites (bandaged ones too).
function H.counters(patient)
    local wounds, bleeding, bites = 0, 0, 0
    local bps = patient:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do
        local bp = bps:get(i)
        if H.damaged(bp) then
            for _, c in ipairs(H.partInfo(patient, bp).chips) do
                if H.DAMAGE_WEIGHT[c.kind] or c.kind == "cu_stump_open" then
                    wounds = wounds + 1
                    break
                end
            end
        end
        if bp:bleeding() then bleeding = bleeding + 1 end
        if bp:bitten() or bp:getBiteTime() > 0 then bites = bites + 1 end
    end
    return {wounds = wounds, bleeding = bleeding, bites = bites}
end

-- local players are sampled in the background, so the times and the pace are
-- there as soon as the tab opens
-- (only with the Health tab on: off - as for every player now - it ran each game
-- minute, many times a second asleep, and wrote its notes into every save)
Events.EveryOneMinute.Add(function()
    if not KnoxTheme.on("health") then return end
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then
            pcall(sample, p)
            pcall(sampleTrend, p)
        end
    end
end)

-- Moodles and stats --------------------------------------------------------------
-- Moodles in the game's own order and icons (zombie.ui.MoodleTextureSet).
H.MOODLES = {
    {"ENDURANCE", "Status_DifficultyBreathing"}, {"TIRED", "Mood_Sleepy"}, {"HUNGRY", "Status_Hunger"},
    {"PANIC", "Mood_Panicked"}, {"SICK", "Mood_Nauseous"}, {"BORED", "Mood_Bored"}, {"UNHAPPY", "Mood_Sad"},
    {"BLEEDING", "Status_Bleeding"}, {"WET", "Status_Wet"}, {"HAS_A_COLD", "Mood_Ill"}, {"ANGRY", "Mood_Angry"},
    {"STRESS", "Mood_Stressed"}, {"THIRST", "Status_Thirst"}, {"INJURED", "Status_InjuredMinor"},
    {"PAIN", "Mood_Pained"}, {"HEAVY_LOAD", "Status_HeavyLoad"}, {"DRUNK", "Mood_Drunk"}, {"DEAD", "Mood_Dead"},
    {"ZOMBIE", "Mood_Zombified"}, {"NOXIOUS_SMELL", "Mood_NoxiousSmell"}, {"FOOD_EATEN", "Status_Hunger"},
    {"HYPERTHERMIA", "Status_TemperatureHot"}, {"HYPOTHERMIA", "Status_TemperatureLow"},
    {"WINDCHILL", "Status_Windchill"}, {"CANT_SPRINT", "Status_MovementRestricted"},
    {"UNCOMFORTABLE", "Mood_Discomfort"},
}
local ICON_SIZES = {32, 48, 64, 80, 96, 128}
local iconCache = {}

--- The moodle's icon in the smallest of the game's sizes not under `px`.
function H.moodleIcon(name, px)
    local size = 128
    for _, s in ipairs(ICON_SIZES) do
        if s >= px then size = s break end
    end
    local key = name .. size
    local tex = iconCache[key]
    if tex == nil then
        tex = getTexture("media/ui/Moodles/" .. size .. "/" .. name .. ".png") or false
        iconCache[key] = tex
    end
    return tex or nil
end

--- The moodles the character has: {{type, id, icon, level (1..4), good (1 good,
--- 2 bad, 0 neutral), name, desc}}, bad ones first, then by level.
function H.moodles(player)
    local m = player:getMoodles()
    local out = {}
    for i, e in ipairs(H.MOODLES) do
        local t = MoodleType[e[1]]
        if t then
            local ok, lvl = pcall(m.getMoodleLevel, m, t)
            if ok and lvl and lvl > 0 then
                local gbn = m:getGoodBadNeutral(t)
                local icon = e[2]
                if e[1] == "INJURED" and lvl >= 3 then icon = "Status_InjuredMajor" end
                table.insert(out, {
                    type = t, id = e[1], icon = icon, level = lvl, good = gbn, order = i,
                    name = m:getMoodleDisplayString(t), desc = m:getMoodleDescriptionString(t),
                })
            end
        end
    end
    table.sort(out, function(a, b)
        local ga, gb = a.good == 2 and 0 or (a.good == 0 and 1 or 2), b.good == 2 and 0 or (b.good == 0 and 1 or 2)
        if ga ~= gb then return ga < gb end
        if a.level ~= b.level then return a.level > b.level end
        return a.order < b.order
    end)
    return out
end

-- Stats for the left column's bars: the value 0..1 the bar fills to, and which
-- way is bad ("high": the fuller the worse; "low": the emptier the worse).
local function stat(player, name)
    local s = CharacterStat and CharacterStat[name]
    if not s then return nil end
    local ok, v = pcall(function() return player:getStats():get(s) end)
    return ok and tonumber(v) or nil
end
H.stat = stat

H.STATS = {
    {id = "hunger",    stat = "HUNGER",     max = 1,   bad = "high"},
    {id = "thirst",    stat = "THIRST",     max = 1,   bad = "high"},
    {id = "endurance", stat = "ENDURANCE",  max = 1,   bad = "low"},
    {id = "fatigue",   stat = "FATIGUE",    max = 1,   bad = "high"},
    {id = "pain",      stat = "PAIN",       max = 100, bad = "high"},
    {id = "stress",    stat = "STRESS",     max = 1,   bad = "high"},
    {id = "sickness",  stat = "SICKNESS",   max = 1,   bad = "high"},
}

--- {{id, name, frac (0..1), danger (0..1, how bad), value text}}.
function H.stats(player)
    local out = {}
    for _, s in ipairs(H.STATS) do
        local v = stat(player, s.stat)
        if v then
            local frac = math.max(0, math.min(1, v / s.max))
            local danger = s.bad == "high" and frac or (1 - frac)
            table.insert(out, {id = s.id, name = T("IGUI_KnoxHP_Stat_" .. s.id), frac = frac, danger = danger,
                value = tostring(math.floor(frac * 100 + 0.5))})
        end
    end
    return out
end

--- Body temperature, "36.6", and its danger 0..1 (fever or cold).
function H.temperature(player)
    local v = stat(player, "TEMPERATURE")
    if not v then
        local ok, t = pcall(function() return player:getBodyDamage():getTemperature() end)
        v = ok and tonumber(t) or nil
    end
    if not v then return nil end
    local d = 0
    if v > 37.5 then d = math.min(1, (v - 37.5) / 3) elseif v < 36 then d = math.min(1, (36 - v) / 6) end
    return string.format("%.1f", v), d
end

return KnoxHealthData
