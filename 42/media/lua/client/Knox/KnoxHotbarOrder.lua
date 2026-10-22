-- The order the quick slots are shown in (Sir Bruno, 2026-10-17: "like Clean Hot
-- Bar"; the author, 2026-10-19: slots are dragged with Alt held - the key is the
-- player's, KnoxControls "hotbarMove").
--
-- Only how they are shown and numbered changes: the game's slots stay as they are
-- (its attached items keep their slot index), so nothing of a save is touched.
-- Slot N on the screen is the slot of hotbar key N. Kept in Knox's settings as
-- the slots' kinds, "hotbar.order=Back,SmallBeltLeft,..." - slots come and go
-- with belts and holsters, a kind not named goes after the named ones.

require "Knox/KnoxTheme"

KnoxHotbarOrder = KnoxHotbarOrder or {}
local O = KnoxHotbarOrder
local T = KnoxTheme

O.stamp = 0   -- bumped on every change (the Knox screen's quick slots are laid out anew)

local function saved()
    local list, rank = {}, {}
    for kind in string.gmatch(T.settings["hotbar.order"] or "", "[^,]+") do
        if not rank[kind] then
            table.insert(list, kind)
            rank[kind] = #list
        end
    end
    return list, rank
end

--- The hotbar's slot indexes in the order they are shown.
function O.order(hb)
    local slots = hb and hb.availableSlot or {}
    local n = #slots
    local sig = n .. "|" .. tostring(T.settings["hotbar.order"])
    for i = 1, n do sig = sig .. "|" .. tostring(slots[i] and slots[i].slotType) end
    if hb.knoxOrderSig == sig and hb.knoxOrder then return hb.knoxOrder end
    local _, rank = saved()
    local idx = {}
    for i = 1, n do table.insert(idx, i) end
    table.sort(idx, function(a, b)
        local ra, rb = rank[slots[a].slotType] or (1000 + a), rank[slots[b].slotType] or (1000 + b)
        return ra < rb
    end)
    hb.knoxOrder, hb.knoxOrderSig = idx, sig
    return idx
end

--- Where slot `index` is shown (1 = leftmost).
function O.positionOf(hb, index)
    for pos, i in ipairs(O.order(hb)) do
        if i == index then return pos end
    end
    return index
end

--- The slot shown at `pos`.
function O.indexAt(hb, pos)
    return O.order(hb)[pos] or pos
end

--- Move slot `index` to be shown at `pos` (the others shift).
function O.move(hb, index, pos)
    local order = O.order(hb)
    local kinds = {}
    for _, i in ipairs(order) do
        if i ~= index then table.insert(kinds, hb.availableSlot[i].slotType) end
    end
    pos = math.max(1, math.min(#kinds + 1, pos))
    table.insert(kinds, pos, hb.availableSlot[index].slotType)
    -- the kinds of slots not on the bar now keep their place after these
    local seen = {}
    for _, k in ipairs(kinds) do seen[k] = true end
    local old = saved()
    for _, k in ipairs(old) do
        if not seen[k] then table.insert(kinds, k) end
    end
    T.settings["hotbar.order"] = table.concat(kinds, ",")
    T.saveSettings()
    hb.knoxOrder = nil
    O.stamp = O.stamp + 1
end

--- Put the order back as the game has it.
function O.reset()
    T.settings["hotbar.order"] = nil
    T.saveSettings()
    O.stamp = O.stamp + 1
end

return KnoxHotbarOrder
