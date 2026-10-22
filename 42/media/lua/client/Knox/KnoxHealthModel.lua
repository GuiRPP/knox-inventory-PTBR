-- The health tab's 3D character (KnoxHealthPanel): a copy of the character's look
-- in underwear, with the injuries painted on its skin, playing what the character
-- is doing (bandaging, stitching...), facing the player.
--   * the copy: a SurvivorDesc with the character's HumanVisual (skin, hair, beard,
--     dirt, blood) wearing only underwear (white when there's none), the bandage and
--     wound models the game puts on the character, Casualties Undead's stumps -
--     the character's own clothes are not touched;
--   * the paint, per part: its worst wound's colour, green while treated, mint when
--     the treatment can come off, near-black when destroyed; a bleeding breathes; the
--     zone under the mouse or chosen is lighter; the parts a kit's thing would treat
--     glow sand; a broken long bone shows through (X-ray). Laid on the skin on the
--     GPU every frame (Java KnoxHealthPaint, M.layers); without it (an old Java part,
--     the shader failed) the old way: hidden texture-only clothing items, one per
--     body part and gender (KnoxHealth.KH_HL_*, tools/import_health_masks.ps1), worn
--     by the copy only, tinted (M.paint; the copy rebuilt at each change);
--   * the hit test: the parts' map of the front view (KnoxHealthModelData), placed
--     over the model by MODEL_CAL.
-- Taken over from the author's Grid Character Hub (Model).

require "Knox/KnoxTheme"
require "Knox/KnoxHealthCU"
require "Knox/KnoxHealthData"
require "Knox/KnoxHealthCare"

KnoxHealthModel = KnoxHealthModel or {}
local M = KnoxHealthModel
local H = KnoxHealthData
local Care = KnoxHealthCare
local CU = KnoxHealthCU
local Doll = require "Knox/KnoxHealthModelData"
M.doll = Doll

local DESC_REFRESH_MS = 3000
-- with the GPU paint the look is rebuilt when what is on the body changes (a new
-- skin is baked after the paint: a rebuild shows it clean for a frame), and now and
-- then for the dirt and the blood
local LOOK_REFRESH_MS = 30000

-- what the copy wears that the look shows: worn things, bandages and wounds
local function lookSig(player)
    local s = {}
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local item = worn:get(i):getItem()
        if item then s[#s + 1] = tostring(item:getID()) end
    end
    local bps = player:getBodyDamage():getBodyParts()
    for i = 0, bps:size() - 1 do
        local bp = bps:get(i)
        s[#s + 1] = (bp:bandaged() and "b" or "") .. (bp:getSplintFactor() > 0 and "s" or "") .. (bp:stitched() and "t" or "")
    end
    return table.concat(s, ",")
end

-- Where the body stands in the model element, as fractions of its height (the model
-- is drawn fitted to the height, centred): skull top below the top, skull to soles,
-- the body's centre off the element's (measured in game for Grid Character Hub).
M.CAL = {TOP = 0.071, HEIGHT = 0.887, CX = 0}
M.CONTENT_UNITS = 400   -- skull top to soles in the map's units
M.MARGIN_UNITS = 6

local PART_BY_INDEX = {}
for _, z in ipairs(Doll.zones) do PART_BY_INDEX[z.index] = z.part end
M.PART_BY_INDEX = PART_BY_INDEX

-- Colours on the skin: halfway to the skin's tone reads as a see-through tint (the
-- mask's opacity is fixed)
local function rgb(r, g, b) return {r = r, g = g, b = b} end
local TREAT = rgb(0.52, 0.80, 0.45)
local HEALED = rgb(0.50, 0.86, 0.76)
local NEUTRAL = rgb(0.95, 0.85, 0.72)
local DESTROYED = rgb(0.10, 0.10, 0.11)
local HOVER = rgb(1.0, 0.92, 0.70)
local PULSE_KINDS = {bleeding = true, infected = true}
local BANDAGE_LEAVES = {bite = true, infected = true, fracture = true, bullet = true, glass = true}
local PULSE_MS, PULSE_STEPS, PULSE_LIGHT = 1500, 3, 0.45
local PROGRESS_STEPS = 8

local function mix(a, b, t)
    return rgb(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
end
local function lighten(c, k) return mix(c, rgb(1, 1, 1), k) end

-- 0..1..0 over PULSE_MS in a few steps (the copy is rebuilt at each)
local function pulseLevel(now)
    local n = PULSE_STEPS * 2
    local step = math.floor((now % PULSE_MS) / PULSE_MS * n)
    if step > PULSE_STEPS then step = n - step end
    return step / PULSE_STEPS
end

local REMOVAL
local function removalJobs()
    if not REMOVAL then
        REMOVAL = {[getText("ContextMenu_Remove_Bandage")] = true, [getText("ContextMenu_Remove_Stitch")] = true,
                   [getText("ContextMenu_Remove_Splint")] = true}
    end
    return REMOVAL
end

local fallbackUnderwear = {}
local masks = {}

local function maskItem(female, index)
    local id = "KnoxHealth.KH_HL_" .. (female and "F_" or "M_") .. (PART_BY_INDEX[index] or "")
    local item = masks[id]
    if item == nil then
        local ok, res = pcall(instanceItem, id)
        item = ok and res or false
        masks[id] = item
        if not item then print("[Knox] health: mask item missing: " .. id) end
    end
    return item or nil
end

local function keepOnModel(item, locId)
    if string.find(locId, "underwear") or string.find(locId, "bandage") or string.find(locId, "wound") then return true end
    if CU and CU.keepOnModel(locId) then return true end
    local t = item:getType() or ""
    return string.find(t, "^Wound_") ~= nil or string.find(t, "^Bandage_") ~= nil
end

local function buildDesc(player, paint)
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setFemale(player:isFemale())
    desc:getHumanVisual():copyFrom(player:getHumanVisual())
    desc:getWornItems():clear()
    local hasBottom = false
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local item = worn:get(i):getItem()
        local loc = item and item:getBodyLocation()
        if loc then
            local id = string.lower(tostring(loc))
            if keepOnModel(item, id) then
                desc:setWornItem(loc, item)
                if string.find(id, "underwear") and (string.find(id, "bottom") or not string.find(id, "top")) then
                    hasBottom = true
                end
            end
        end
    end
    if not hasBottom then
        local n = player:getPlayerNum()
        local item = fallbackUnderwear[n]
        if not item then
            local ok, res = pcall(instanceItem, player:isFemale() and "Base.Underpants_White" or "Base.Boxers_White")
            if ok then item = res end
            -- (a new item gets a random tint: fixed, the same after every load)
            if item then
                pcall(function()
                    local v = item:getVisual()
                    v:setTint(ImmutableColor.new(0.82, 0.82, 0.84, 1))
                    if v.setTextureChoice then v:setTextureChoice(0) end
                    if v.setBaseTexture then v:setBaseTexture(0) end
                end)
            end
            fallbackUnderwear[n] = item
        end
        if item then desc:setWornItem(item:getBodyLocation(), item) end
    end
    for _, p in ipairs(paint) do
        local item = maskItem(player:isFemale(), p.index)
        if item then
            pcall(function() item:getVisual():setTint(ImmutableColor.new(p.color.r, p.color.g, p.color.b, 1)) end)
            desc:setWornItem(item:getBodyLocation(), item)
        end
    end
    return desc
end

-- 0..1..0 over a period, smooth (the paint on the GPU follows it every frame)
local function wave(now, ms)
    return 0.5 - 0.5 * math.cos((now % ms) / ms * 2 * math.pi)
end

-- The colour of each body part on the skin (nil: the skin as it is); `pulse`: the
-- breathing's level at a moment (stepped for the mask clothing, smooth on the GPU).
local function partColor(player, bp, now, pulse)
    local level = pulse or pulseLevel
    local info = H.partInfo(player, bp)
    local present = {}
    for _, c in ipairs(info.chips) do present[c.kind] = true end
    local kind, pulse, untreated
    for _, d in ipairs(H.DAMAGE_KINDS) do
        if present[d.kind] then
            kind = kind or d.kind
            if PULSE_KINDS[d.kind] then pulse = true end
            if BANDAGE_LEAVES[d.kind] then untreated = untreated or d.kind end
        end
    end
    local K = H.KIND_COLOR
    local color
    local progress, job = Care.partProgress(player, bp)
    local bandaged = bp:bandaged() and bp:getBandageLife() > 0
    if progress then
        local p = math.floor(math.max(0, math.min(1, progress)) * PROGRESS_STEPS + 0.5) / PROGRESS_STEPS
        local underKind = kind or H.hiddenWoundKind(bp)
        local under = underKind and K[underKind] or NEUTRAL
        if job ~= nil and removalJobs()[job] then color = mix(TREAT, under, p) else color = mix(under, TREAT, p) end
    elseif not kind and info.healed then
        color = lighten(HEALED, PULSE_LIGHT * level(now))
    elseif bandaged then
        color = untreated and K[untreated] or TREAT
    elseif present.dirtybandage or (bp:bandaged() and bp:getBandageLife() <= 0) then
        color = (present.bleeding and K.bleeding) or (untreated and K[untreated]) or K.dirtybandage
    elseif kind then
        color = K[kind]
    else
        for _, c in ipairs(info.chips) do
            if c.treated or c.kind == "stitched" or c.kind == "splinted" or c.kind == "poultice" then color = TREAT
            else color = K[c.kind] end
            if color then break end
        end
    end
    if color and not progress and pulse and (color == K.bleeding or color == K.infected) then
        color = lighten(color, PULSE_LIGHT * level(now))
    end
    return color
end

--- What is painted on the copy: {{index, color}} and a signature (the copy is
--- rebuilt when it changes). view: {hover = zone id, selected = zone id,
--- glow = {[index] = true} (the kit's thing under the mouse)}.
function M.paint(player, view)
    local list, sig = {}, {}
    local now = getTimestampMs()
    local bps = player:getBodyDamage():getBodyParts()
    -- (the game's Lua has no `next`: the kit's hover broke on it, 2026-10-19)
    local glowOn = false
    for _ in pairs(view.glow or {}) do glowOn = true break end
    local glowK = glowOn and (0.35 + 0.45 * pulseLevel(now)) or 0
    for index = 0, bps:size() - 1 do
        local bp = bps:get(index)
        local z = H.zoneOfPart[index]
        local color
        if H.missing(player, index) then
            color = nil
        elseif bp:getHealth() <= 0 then
            color = DESTROYED
        elseif H.damaged(bp) or bp:getBleedingTime() > 0 then
            color = partColor(player, bp, now)
        end
        if view.glow and view.glow[index] then
            color = mix(color or NEUTRAL, KnoxTheme.color.accent, glowK)
        end
        local zid = z and z.id
        if zid and (zid == view.hover or zid == view.selected) then
            local k = zid == view.hover and 0.42 or 0.28
            if color == DESTROYED then color = rgb(0.28, 0.28, 0.30)
            else color = color and lighten(color, k) or (zid == view.hover and HOVER or mix(NEUTRAL, HOVER, 0.6)) end
        end
        if color then
            table.insert(list, {index = index, color = color})
            table.insert(sig, index .. ":" .. math.floor(color.r * 99) .. "," .. math.floor(color.g * 99) .. "," .. math.floor(color.b * 99))
        end
    end
    return list, table.concat(sig, ";")
end

-- The paint on the GPU (Java KnoxHealthPaint) ------------------------------------------
-- Every frame, no rebuild. A part's wound colour eases to where it should be, a
-- bleeding breathes smoothly. The part under the mouse is lit as the main menu lights
-- a character under the mouse: the skin itself brighter and warmer, its colours kept
-- (light, not paint over it), coming and going smoothly; the chosen part a little. A
-- broken part under the mouse goes see-through and its broken bone shows in it: the
-- copy wears a 3D skeleton (KnoxHealth.KH_Skeleton, made from the game's body mesh by
-- Knox Inventory Java/tools/healthpaint/SkeletonGen.java), each part's bones whole and
-- broken, all hidden until Java shows one (author's idea, 19.10.2026: the bone painted
-- on the skin was never seen). The masks are the mask clothing's own textures.

local TEX_DIR = "media/textures/KnoxHealth/"
local PAINT_A = 0.55          -- a wound's colour over the skin
local DESTROYED_A = 0.85
local EASE_MS = 110           -- how fast the paint follows (a fade is over in about 0.3 s)
local SOFT = 3                -- the edge spread of a part's paint, texels of the skin
-- the light under the mouse: the skin times 1 + this (the menu's hover is x1.4 overall)
-- (Java: the skin towards white by colour x strength - "screen", the shading kept)
local LIGHT = rgb(1.0, 0.93, 0.80)
-- (0.45 read badly - author, 19.10.2026)
local HOVER_LIGHT, SELECTED_LIGHT, GLOW_LIGHT = 0.7, 0.3, 0.5
local LIGHT_SOFT = 4
-- the face lit as strongly as a limb looked washed out (author, 19.10.2026)
local LIGHT_K = {[8] = 0.65}
-- a broken part under the mouse: how see-through its skin goes
local SEE = 0.72
local SEE_SOFT = 8

local function maskPath(female, index)
    return TEX_DIR .. "hl_" .. (female and "f_" or "m_") .. (PART_BY_INDEX[index] or "") .. ".png"
end

--- Where each part's paint should be now: colours {[index] = {r, g, b, a}}, light
--- {[index] = 0..1}, the broken parts under the mouse (see-through, their bone shown)
--- {[index] = true}.
function M.targets(player, view, now)
    local out, light, xray = {}, {}, {}
    local bps = player:getBodyDamage():getBodyParts()
    local smooth = function(t) return wave(t, PULSE_MS) end
    for index = 0, bps:size() - 1 do
        local bp = bps:get(index)
        if not H.missing(player, index) then
            local z = H.zoneOfPart[index]
            local color, a
            if bp:getHealth() <= 0 then
                color, a = DESTROYED, DESTROYED_A
            elseif H.damaged(bp) or bp:getBleedingTime() > 0 then
                color = partColor(player, bp, now, smooth)
                a = color and PAINT_A or 0
                if color and bp:getBleedingTime() > 0 then a = a + 0.15 * smooth(now) end
            end
            if color and (a or 0) > 0.003 then out[index] = {color.r, color.g, color.b, a} end
            -- the light: the part under the mouse on the model alone (a forearm, not
            -- the whole arm), a plate under the mouse its whole zone; the same for the
            -- chosen; the parts a kit's thing would treat breathe with it
            local zid = z and z.id
            local hk, sk
            if view.hoverPart then hk = (index == view.hoverPart) and 1 or 0
            else hk = (zid ~= nil and zid == view.hover) and 1 or 0 end
            if view.selectedPart then sk = (index == view.selectedPart) and 1 or 0
            else sk = (zid ~= nil and zid == view.selected) and 1 or 0 end
            local l = math.max(hk * HOVER_LIGHT, sk * SELECTED_LIGHT)
            if view.glow and view.glow[index] then l = math.max(l, GLOW_LIGHT * (0.45 + 0.55 * smooth(now))) end
            if l > 0 then light[index] = l end
            if hk > 0 and bp:getFractureTime() > 0 and bp:getHealth() > 0 then xray[index] = true end
        end
    end
    return out, light, xray
end

-- a value on its way to a target (k: this frame's share); nil when gone to nothing
local function follow(t, key, target, k)
    local v = (t[key] or 0) + ((target or 0) - (t[key] or 0)) * k
    if not target and v < 0.004 then v = nil end
    t[key] = v
    return v
end

--- This frame's layers for knoxHealthPaint: {path, r, g, b, a, soft, mode, ...}
--- (mode 1: light, 2: see-through), and the skeleton's bones shown {block, alpha, ...}
--- (block: part index * 3 shared, + 2 the broken's own). Everything eases towards its
--- target (kept in av).
function M.layers(av, player, view)
    local now = getTimestampMs()
    local dt = math.min(100, now - (av.knoxPaintMs or now))
    av.knoxPaintMs = now
    local k = 1 - math.exp(-dt / EASE_MS)
    local cur = av.knoxPaint or {}
    av.knoxPaint = cur
    local want, light, xray = M.targets(player, view, now)
    local female = player:isFemale()
    local layers = {}
    local function add(path, r, g, b, a, soft, mode)
        local n = #layers
        layers[n + 1], layers[n + 2], layers[n + 3], layers[n + 4] = path, r, g, b
        layers[n + 5], layers[n + 6], layers[n + 7] = a, soft, mode
    end
    -- the wounds' colours
    for index = 0, 16 do
        local w, c = want[index], cur[index]
        if w and not c then
            -- (a part that comes up: from its own colour, clear)
            c = {w[1], w[2], w[3], 0}
            cur[index] = c
        end
        if c then
            local tr, tg, tb, ta = c[1], c[2], c[3], 0
            if w then tr, tg, tb, ta = w[1], w[2], w[3], w[4] end
            c[1] = c[1] + (tr - c[1]) * k
            c[2] = c[2] + (tg - c[2]) * k
            c[3] = c[3] + (tb - c[3]) * k
            c[4] = c[4] + (ta - c[4]) * k
            if not w and c[4] < 0.004 then
                cur[index] = nil
            else
                add(maskPath(female, index), c[1], c[2], c[3], c[4], SOFT, 0)
            end
        end
    end
    -- the light: over the wounds too, as a lamp would be
    local lk = av.knoxLight or {}
    av.knoxLight = lk
    for index = 0, 16 do
        local v = follow(lk, index, light[index], k)
        if v then add(maskPath(female, index), LIGHT.r, LIGHT.g, LIGHT.b, v * (LIGHT_K[index] or 1), LIGHT_SOFT, 1) end
    end
    -- a broken part under the mouse last: its skin see-through, its broken bone in it
    local bones = {}
    local xk = av.knoxXray or {}
    av.knoxXray = xk
    for index = 0, 16 do
        local v = follow(xk, index, xray[index] and 1 or nil, k)
        if v then
            -- (a wider soft edge: the see-through runs a little into the next part, where
            -- the bone goes on - a pelvis's wings, a femur's head)
            add(maskPath(female, index), 0, 0, 0, SEE * v, SEE_SOFT, 2)
            -- the skeleton's blocks: what the whole and the broken share, the broken's own
            bones[#bones + 1] = index * 3
            bones[#bones + 1] = v
            bones[#bones + 1] = index * 3 + 2
            bones[#bones + 1] = v
        end
    end
    return layers, bones
end

local skeletonItem
local function skeleton()
    if skeletonItem == nil then
        local ok, res = pcall(instanceItem, "KnoxHealth.KH_Skeleton")
        skeletonItem = ok and res or false
        if not skeletonItem then print("[Knox] health: the skeleton item is missing (KnoxHealth.KH_Skeleton)") end
    end
    return skeletonItem or nil
end

local function gpuPaint()
    return knoxHealthPaint ~= nil and not (knoxHealthPaintFailed and knoxHealthPaintFailed())
end
M.gpuPaint = gpuPaint

-- The model ---------------------------------------------------------------------------

--- A new model element (mouse-blind: the tab takes the mouse over it).
function M.create(parent)
    local av = ISUI3DModel:new(0, 0, 10, 10)
    av:initialise()
    av:instantiate()
    av.onMouseDown = function() return false end
    av.onMouseUp = function() return false end
    av.onRightMouseDown = function() return false end
    av.onRightMouseUp = function() return false end
    av.onMouseMove = function() return false end
    av.onMouseMoveOutside = function() return false end
    av.onMouseUpOutside = function() return false end
    av.onMouseWheel = function() return false end
    av:setDirection(IsoDirections.S)
    av:setIsometric(false)
    av:setZoom(0)
    av:setYOffset(0)
    -- (the idle pose without fidgets: the limbs stay where the hit map has them)
    av:setDoRandomExtAnimations(false)
    av.animateWhilePaused = true
    parent:addChild(av)
    return av
end

-- The model plays the character's timed action (anim set "player" with the action's
-- variables); bandaging needs the body part, putting on and off clothes the place;
-- anything not mirrored exactly gets the hands-on-self animation.
local ACTION_EXACT = {bandage = "BandageType", wearclothing = "WearClothingLocation", loot = false}
local ACTION_VARS = {"IsPerformingAnAction", "PerformingAction", "BandageType", "WearClothingLocation",
    "sneaking", "nearWallCrouching", "isTurning"}

local function syncAction(av, chr)
    local anim = chr and chr:getVariableBoolean("IsPerformingAnAction") and chr:getVariableString("PerformingAction")
    if anim and anim ~= "" then
        local key = string.lower(anim)
        local extraVar = ACTION_EXACT[key]
        local mirrored = extraVar ~= nil and anim or "TransferItemOnSelf"
        local extra
        if extraVar then
            extra = chr:getVariableString(extraVar)
            if key == "bandage" and (not extra or extra == "") then mirrored = "Loot" end
        end
        if not av.knoxAction then
            av.knoxAction = true
            av:setAnimSetName("player")
            av:setVariable("sneaking", false)
            av:setVariable("nearWallCrouching", false)
            av:setVariable("isTurning", false)
        end
        av:setVariable("IsPerformingAnAction", true)
        av:setVariable("PerformingAction", mirrored)
        if extraVar then
            if extra and extra ~= "" then av:setVariable(extraVar, extra) else av:clearVariable(extraVar) end
        end
    elseif av.knoxAction then
        av.knoxAction = false
        for _, v in ipairs(ACTION_VARS) do av:clearVariable(v) end
        av:setAnimSetName("player-avatar")
        av:setState("idle")
    end
end

local reported = {}
local function report(what, err)
    if reported[what] then return end
    reported[what] = true
    print("[Knox] health model " .. what .. ": " .. tostring(err))
end

--- Places the model over x, y, w, h and keeps its look fresh.
function M.update(av, player, x, y, w, h, view)
    if av:getX() ~= x or av:getY() ~= y or av:getWidth() ~= w or av:getHeight() ~= h then
        av:setX(x)
        av:setY(y)
        av:setWidth(w)
        av:setHeight(h)
    end
    if knoxAvatarMirror then
        -- a treatment going on (the character busy with a body part): the model takes the
        -- character's own pose, as the equipment screen's does, and the things in its
        -- hands; walking, crouching and the rest are not repeated (author, 19.10.2026: the
        -- action variables alone left the model standing still)
        local busy = Care.busy(player) and player:getVehicle() == nil
        local okM, errM = pcall(knoxAvatarMirror, av.javaObject, player, busy)
        if not okM then report("mirror", errM) end
        local hands = (busy and knoxAvatarHands and knoxAvatarHands(player)) or "|"
        if hands ~= av.knoxHands and knoxAvatarSetHands then
            av.knoxHands = hands
            local p, s = string.match(hands, "^([^|]*)|(.*)$")
            pcall(knoxAvatarSetHands, av.javaObject, p or "", s or "")
            -- (the look rebuilt: the hand models come with it)
            av.knoxSig = nil
        end
    else
        local okA, errA = pcall(syncAction, av, player)
        if not okA then report("action", errA) end
    end
    local now = getTimestampMs()
    if gpuPaint() then
        -- the look without paint, fresh now and then (dirt, blood, bandages); the
        -- paint goes over it on the GPU every frame
        local look = "gpu:" .. lookSig(player)
        if av.knoxSig ~= look or not av.knoxDescMs or now - av.knoxDescMs > LOOK_REFRESH_MS or av.knoxFor ~= player then
            av.knoxDescMs, av.knoxSig, av.knoxFor = now, look, player
            local ok, err = pcall(function()
                local desc = buildDesc(player, {})
                -- the skeleton, hidden until a broken part is under the mouse
                local sk = skeleton()
                if sk then desc:setWornItem(sk:getBodyLocation(), sk) end
                av:setSurvivorDesc(desc)
                av:setDirection(IsoDirections.S)
                av:setAnimSetName(av.knoxAction and "player" or "player-avatar")
                av:setState("idle")
            end)
            if not ok then report("look", err) end
        end
        local ok, err = pcall(function()
            local layers, bones = M.layers(av, player, view)
            knoxHealthPaint(av.javaObject, layers, bones)
        end)
        if not ok then report("paint", err) end
        if gpuPaint() then return end
        -- (the shader failed: the mask clothing from now on)
        av.knoxSig = nil
    end
    local paint, sig = M.paint(player, view)
    if sig ~= av.knoxSig or not av.knoxDescMs or now - av.knoxDescMs > DESC_REFRESH_MS or av.knoxFor ~= player then
        av.knoxDescMs, av.knoxSig, av.knoxFor = now, sig, player
        local ok, err = pcall(function()
            av:setSurvivorDesc(buildDesc(player, paint))
            av:setDirection(IsoDirections.S)
            av:setAnimSetName(av.knoxAction and "player" or "player-avatar")
            av:setState("idle")
        end)
        if not ok then report("look", err) end
    end
end

-- The hit map --------------------------------------------------------------------------

--- Where the map lies over a model element of x, y, w, h: its scale and top left.
function M.frame(x, y, w, h)
    local s = M.CAL.HEIGHT * h / M.CONTENT_UNITS
    local fx = x + w / 2 - Doll.width / 2 * s + M.CAL.CX * h
    local fy = y + M.CAL.TOP * h - M.MARGIN_UNITS * s
    return s, fx, fy
end

-- A point just off the body snaps to the nearest part within HIT_SLOP units: hands,
-- feet and the neck need no pixel aiming (the borders between parts stay).
local BYTE_A, BYTE_DOT = string.byte("a"), string.byte(".")
local HIT_SLOP = 10
local function cellAt(hit, c, r)
    if c < 0 or r < 0 or c >= hit.cols or r >= hit.rows then return nil end
    local b = string.byte(hit.data, r * hit.cols + c + 1)
    if not b or b == BYTE_DOT then return nil end
    return b - BYTE_A
end

--- The body part index under a point of the map (its units), or nil.
function M.partAt(ux, uy)
    local hit = Doll.hit
    local c, r = math.floor(ux / hit.cell), math.floor(uy / hit.cell)
    local here = cellAt(hit, c, r)
    if here then return here end
    local reach = math.ceil(HIT_SLOP / hit.cell)
    local best, bestD = nil, reach * reach + 1
    for dr = -reach, reach do
        for dc = -reach, reach do
            local d = dc * dc + dr * dr
            if d < bestD then
                local p = cellAt(hit, c + dc, r + dr)
                if p then best, bestD = p, d end
            end
        end
    end
    return best
end

--- The point on the model of a part (its centre), in the element's frame.
function M.partPoint(index, s, fx, fy)
    for _, z in ipairs(Doll.zones) do
        if z.index == index then return fx + z.cx * s, fy + z.cy * s end
    end
    return nil
end

--- The anchor of a zone on the model (where its leader line ends): the centre of
--- its parts' centres, pulled to its outer side for arms and legs.
function M.zonePoint(zone, s, fx, fy)
    local sx, sy, n = 0, 0, 0
    for _, i in ipairs(zone.parts) do
        local px, py = M.partPoint(i, s, fx, fy)
        if px then sx, sy, n = sx + px, sy + py, n + 1 end
    end
    if n == 0 then return nil end
    -- (an arm: its upper arm and forearm, the hand hangs off; a leg: the thigh and shin)
    local first, second = zone.parts[1], zone.parts[2]
    if #zone.parts == 3 and second then
        local ax, ay = M.partPoint(first, s, fx, fy)
        local bx, by = M.partPoint(second, s, fx, fy)
        return math.floor((ax + bx) / 2 + 0.5), math.floor((ay + by) / 2 + 0.5)
    end
    return math.floor(sx / n + 0.5), math.floor(sy / n + 0.5)
end

return KnoxHealthModel
