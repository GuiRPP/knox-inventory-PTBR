-- The health tab's wounds (the redesign of 2026-10-19, the author: simpler, more
-- intuitive and interactive, every wound its own set of icons changing with its
-- state). A wound is one kind of injury on one body part, on its way of treatment:
--   path   the steps of its kind (a bleeding: bleeding > bandaged > healed; a
--          fracture: fracture > splinted > healed...), each a square icon - a base
--          (the kind) and an overlay (the state: a bandage, stitches, a splint...);
--   stage  where it is on its path now (a dirty bandage: the bandaged step, its
--          overlay dirty);
--   todo   what is to be done now (stop the bleeding, change the bandage, take the
--          splint off...), or nil while it heals on its own;
--   urgent a bleeding, a bite, an infection: its badge pulses, it leads the list.
-- Built from the statuses of KnoxHealthData.partInfo; the icons are
-- media/ui/knoxhealth/w_*.png (Knox Inventory Java/tools/healthpaint/IconGen.java).

require "Knox/KnoxHealthData"
require "Knox/KnoxHealthCare"

KnoxHealthWounds = KnoxHealthWounds or {}
local W = KnoxHealthWounds
local H = KnoxHealthData
local Care = KnoxHealthCare

local function tx(key, ...) return getText("IGUI_KnoxHP_" .. key, ...) end

local icons = {}
--- A wound icon's texture by name ("bleeding", "o_band"...), or nil.
function W.icon(name)
    if not name then return nil end
    local t = icons[name]
    if t == nil then
        t = getTexture("media/ui/knoxhealth/w_" .. name .. ".png") or false
        icons[name] = t
    end
    return t or nil
end

-- The ways of treatment: {base, overlay, name key} a step.
local HEALED = {"healed", nil, "St_Healed"}
W.PATH = {
    bleeding  = {{"bleeding", nil, "St_Bleeding"}, {"bleeding", "o_band", "St_Bandaged"}, HEALED},
    scratch   = {{"scratch", nil, "St_Open"}, {"scratch", "o_band", "St_Bandaged"}, HEALED},
    cut       = {{"cut", nil, "St_Open"}, {"cut", "o_band", "St_Bandaged"}, HEALED},
    bite      = {{"bite", nil, "St_Open"}, {"bite", "o_band", "St_Bandaged"}, HEALED},
    deepwound = {{"deepwound", nil, "St_Open"}, {"deepwound", "o_stitch", "St_Stitched"}, {"deepwound", "o_band", "St_Bandaged"}, HEALED},
    burn      = {{"burn", nil, "St_Open"}, {"burn", "o_clean", "St_Cleaned"}, {"burn", "o_band", "St_Bandaged"}, HEALED},
    fracture  = {{"fracture", nil, "St_Broken"}, {"fracture", "o_splint", "St_Splinted"}, HEALED},
    glass     = {{"glass", nil, "St_Lodged"}, {"glass", "o_removed", "St_Removed"}},
    bullet    = {{"bullet", nil, "St_Lodged"}, {"bullet", "o_removed", "St_Removed"}},
    infected  = {{"infected", nil, "St_Infected"}, {"infected", "o_clean", "St_Disinfected"}, HEALED},
}
local URGENT = {bleeding = true, bite = true, infected = true}
-- the injury's name (the game's words)
W.KIND_TEXT = {bleeding = "IGUI_health_Bleeding", bite = "IGUI_health_Bitten", deepwound = "IGUI_health_DeepWound",
    infected = "IGUI_health_Infected", fracture = "IGUI_health_Fracture", burn = "IGUI_health_Burned",
    bullet = "IGUI_health_LodgedBullet", glass = "IGUI_health_LodgedGlassShards", cut = "IGUI_health_Cut",
    scratch = "IGUI_health_Scratched"}

-- what a cover is called when it can come off, and the game's word for taking it off
local COVER = {
    bandaged = {base = "healed", overlay = "o_band", todo = "ContextMenu_Remove_Bandage"},
    dirtybandage = {base = "healed", overlay = "o_dirty", todo = "ContextMenu_Remove_Bandage"},
    stitched = {base = "healed", overlay = "o_stitch", todo = "ContextMenu_Remove_Stitch"},
    splinted = {base = "healed", overlay = "o_splint", todo = "ContextMenu_Remove_Splint"},
}

local function stageOf(kind, bp)
    local bandaged = bp:bandaged()
    local clean = bandaged and bp:getBandageLife() > 0
    if kind == "deepwound" then
        if bandaged then return 3 end
        if bp:stitched() then return 2 end
        return 1
    elseif kind == "burn" then
        if bandaged then return 3 end
        if not bp:isNeedBurnWash() then return 2 end
        return 1
    elseif kind == "fracture" then
        return bp:getSplintFactor() > 0 and 2 or 1
    elseif kind == "infected" then
        local ok, alc = pcall(function() return bp:getAlcoholLevel() end)
        return ((ok and alc and alc > 0) or bp:getGarlicFactor() > 0) and 2 or 1
    elseif kind == "glass" or kind == "bullet" then
        return 1
    end
    -- bleeding, scratch, cut, bite: covered or not
    return bandaged and 2 or 1, clean
end

local function new(index, bp, kind)
    local path = W.PATH[kind]
    return {id = index .. ":" .. kind, index = index, bp = bp, kind = kind, path = path,
            name = W.KIND_TEXT[kind] and getText(W.KIND_TEXT[kind]) or kind}
end

--- The wounds of a body part (a cover that can come off counts as one).
local function partWounds(player, index, bp, out)
    if H.missing(player, index) then return end
    if bp:getHealth() <= 0 then
        local w = {id = index .. ":destroyed", index = index, bp = bp, kind = "destroyed", base = "destroyed",
                   name = tx("Destroyed"), stage = 1, urgent = true, sev = 4}
        w.path = {{"destroyed", nil, "Destroyed"}}
        table.insert(out, w)
    end
    if not (H.damaged(bp) or bp:getBleedingTime() > 0) then return end
    local info = H.partInfo(player, bp)
    local seen = {}
    local dirty = bp:bandaged() and bp:getBandageLife() <= 0
    for _, c in ipairs(info.chips) do
        local k = c.kind
        if W.PATH[k] and not seen[k] then
            seen[k] = true
            local w = new(index, bp, k)
            w.stage = stageOf(k, bp)
            local step = w.path[w.stage]
            w.base, w.overlay = step[1], step[2]
            if dirty and w.overlay == "o_band" then w.overlay = "o_dirty" w.dirty = true end
            w.sev = c.sev
            w.heal, w.notHealing, w.progress = c.heal, c.notHealing, c.progress
            w.treated = c.treated or (w.stage > 1 and not w.dirty)
            w.urgent = URGENT[k] and w.stage == 1
            table.insert(out, w)
        end
    end
    -- a splint or stitches over a wound the list no longer names: its wound, treated
    for _, c in ipairs(info.chips) do
        local k = c.kind
        if (k == "splinted" and not seen.fracture) or (k == "stitched" and not seen.deepwound) then
            local kind = k == "splinted" and "fracture" or "deepwound"
            if not c.healed then
                local w = new(index, bp, kind)
                w.stage = k == "splinted" and 2 or (bp:bandaged() and 3 or 2)
                local step = w.path[w.stage]
                w.base, w.overlay = step[1], step[2]
                w.sev, w.heal, w.progress, w.treated = 1, c.heal, c.progress, true
                seen[kind] = true
                table.insert(out, w)
            end
        end
        -- a cover over what has healed: it can come off - the path's last step
        local cv = COVER[k]
        if cv and (c.healed or (k == "dirtybandage" and not seen.bleeding)) and not seen["cover" .. k] then
            seen["cover" .. k] = true
            local w = {id = index .. ":" .. k, index = index, bp = bp, kind = k, base = cv.base, overlay = cv.overlay,
                       name = c.text, sev = c.healed and 0 or 2, cover = cv.todo, healed = c.healed,
                       dirty = k == "dirtybandage"}
            w.path = {{cv.base, cv.overlay, c.healed and "St_CanRemove" or "St_Dirty"}}
            w.stage = 1
            table.insert(out, w)
        end
    end
    -- Casualties Undead's statuses and the rest the paths don't know: as they are
    for _, c in ipairs(info.chips) do
        if not W.PATH[c.kind] and not COVER[c.kind] and c.kind ~= "pain" and c.kind ~= "stiffness"
                and c.kind ~= "poultice" and not seen[c.kind] then
            seen[c.kind] = true
            local w = {id = index .. ":" .. c.kind, index = index, bp = bp, kind = c.kind, base = "other", name = c.text,
                       sev = c.sev, stage = 1, heal = c.heal, progress = c.progress, treated = c.treated}
            w.path = {{"other", nil, nil}}
            table.insert(out, w)
        end
    end
    -- a poultice on the part: shown on its wounds (a leaf in the corner)
    if bp:getPlantainFactor() > 0 or bp:getComfreyFactor() > 0 or bp:getGarlicFactor() > 0 then
        for _, w in ipairs(out) do if w.index == index then w.poultice = true end end
    end
end

-- what to do now about a wound: {label, steps (the quick treatment's), cover (a removal)}
local function todoOf(player, w, quick)
    if w.kind == "destroyed" then return nil end
    if w.cover then
        if w.healed or w.dirty then return {label = getText(w.dirty and "IGUI_KnoxHP_Do_ChangeBandage" or w.cover), cover = w.cover} end
        return nil
    end
    local first = w.stage == 1
    local needs = first or w.dirty or (w.kind == "deepwound" and w.stage == 2) or (w.kind == "burn" and w.stage == 2)
    if not needs then return nil end
    local steps = quick(w.bp)
    if #steps > 0 then return {label = steps[1], steps = steps} end
    -- nothing at hand: what is missing
    local why
    for _, key in ipairs(H.TREAT[w.kind] or {}) do
        if Care.CHECK[key] then
            local r = Care.unavailableReason(key, w.bp)
            if r then why = r break end
        end
    end
    if w.kind == "glass" then return {label = getText("ContextMenu_Remove_Glass"), steps = {}} end
    return {label = why and getText(why) or tx("Do_Menu"), missing = true}
end

--- Every wound of the body, the most urgent first:
--- {{id, index, bp, kind, name, part, path, stage, base, overlay, sev, urgent, treated,
---   heal, progress, dirty, healed, todo = {label, steps | cover | missing}}}.
--- quick(bp): the quick treatment's steps for a part (the tab keeps them a moment).
function W.list(player, quick)
    local out = {}
    local bps = player:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do partWounds(player, i, bps:get(i), out) end
    for _, w in ipairs(out) do
        w.part = H.partName(w.bp)
        w.todo = todoOf(player, w, quick)
        -- the badge's colour: red untreated and bad, sand to do, green healing, mint healed
        local C = KnoxTheme.color
        if w.kind == "destroyed" then w.color = C.bad
        elseif w.healed then w.color = H.HEALED
        elseif w.urgent or (w.sev or 0) >= 3 and not w.treated then w.color = C.bad
        elseif w.todo and not w.todo.missing then w.color = C.warn
        elseif w.dirty then w.color = C.warn
        else w.color = C.good end
        w.rank = (w.kind == "destroyed" and 100 or 0) + (w.urgent and 50 or 0) + ((w.sev or 0) * 10)
            + ((w.todo and not w.todo.missing) and 5 or 0) - (w.treated and 3 or 0)
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.index < b.index
    end)
    return out
end

--- Takes a cover off a body part (a bandage, stitches, a splint that can come off).
function W.removeCover(player, bp, key)
    local panel = Care.carePanel(player)
    if key == "ContextMenu_Remove_Bandage" then
        ISTimedActionQueue.add(ISApplyBandage:new(player, player, nil, bp, false))
    elseif key == "ContextMenu_Remove_Stitch" then
        ISTimedActionQueue.add(ISStitch:new(player, player, nil, bp, false))
    elseif key == "ContextMenu_Remove_Splint" then
        ISTimedActionQueue.add(ISSplint:new(player, player, nil, nil, bp, false))
    end
    Care.dropKitCache(player)
    return panel
end

--- The things a wound's treatment wants, with how many are carried: {{name, have}}.
function W.needs(player, w)
    local out = {}
    if not w.todo or w.todo.cover then return out end
    local kit = Care.kit(player)
    for _, key in ipairs(H.TREAT[w.kind] or {}) do
        local f = Care.CHECK[key]
        if f and Care.applies(w.bp, key) then
            local have = 0
            for _, g in ipairs(kit) do
                local ok, res = pcall(f, g.item)
                if ok and res then have = have + g.count end
            end
            table.insert(out, {key = key, name = getText("IGUI_KnoxHP_Need_" .. key), have = have})
        end
    end
    return out
end

return KnoxHealthWounds
