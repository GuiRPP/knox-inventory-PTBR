-- What KnoxGridView.lua needs to load outside the game, over tools/settings/stubs.lua
-- (tools/lists/grid.lua): its element is a plain panel, the rest of Knox it asks
-- while it draws is made up here - as little as a grid's drawing goes.
ISUIElement = ISPanel
function instanceof() return false end
KnoxDrag = {extras = {}}
function KnoxDrag.isActive() return KnoxDrag.entity ~= nil end
KnoxTooltip = {want = function() end}
KnoxActions = {lootViews = function() return {} end, windowViews = function() return {} end,
               isLocked = function() return false end}
KnoxOrder = {silhouettes = function() return nil end, ghostK = function() return 0 end}
KnoxGrid.frame = 0
KnoxGrid.useNow = {}
KnoxGrid.pending = {}
KnoxGrid.liveGrids = {}   -- (the bags' grids up: KnoxGridView.rebuild sets them, 2026-10-29)
function KnoxGrid.useOf(items)
    for _, it in ipairs(items) do
        local p = KnoxGrid.useNow[it]
        if p then return p end
    end
    return nil
end
function KnoxGrid.dims(e, r)
    if r == 1 then return e.h, e.w end
    return e.w, e.h
end
function KnoxGrid.pendingOf() return nil end
function KnoxGrid.orderOf() return nil end
function KnoxGrid.isStackable() return false end
KnoxTheme.refresh()
