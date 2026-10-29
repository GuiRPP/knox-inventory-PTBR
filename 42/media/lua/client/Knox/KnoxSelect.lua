-- Ctrl+click selection of several tiles, across every grid on the screen.
-- Stored by item, so it survives grids being rebuilt.

KnoxSelect = KnoxSelect or {}
local S = KnoxSelect

S.items = {}   -- item -> true (every member of a selected stack)
-- (toggles counted: S.items changed in place - a grid's ready list of quiet tiles,
-- KnoxGridView renderGrid, is written anew; a new selection is a new S.items)
S.toggles = S.toggles or 0

function S.isSelected(entity)
    return entity ~= nil and S.items[entity.item] == true
end

function S.toggle(entity)
    local on = not S.isSelected(entity)
    for _, it in ipairs(entity.items) do
        if on then S.items[it] = true else S.items[it] = nil end
    end
    S.toggles = S.toggles + 1
end

function S.clear()
    S.items = {}
end

function S.isEmpty()
    for _ in pairs(S.items) do return false end
    return true
end

--- Selected tiles in a layout.
function S.entitiesIn(layout)
    local out = {}
    for _, e in ipairs(layout.placed) do
        if not e.ghost and not e.reserved and S.isSelected(e) then table.insert(out, e) end
    end
    return out
end

--- The tiles an action on `entity` (in `view`) applies to, as {entity, view}:
--- the whole selection when the entity is part of it, else just the entity.
--- `views` = all grid views to look in.
function S.group(entity, view, views)
    if not S.isSelected(entity) then return {{entity = entity, view = view}} end
    local out = {}
    for _, v in ipairs(views) do
        for _, e in ipairs(S.entitiesIn(v.layout)) do
            table.insert(out, {entity = e, view = v})
        end
    end
    return out
end

return KnoxSelect
