-- Between KnoxGrid.lua and KnoxHome.lua (tools/home/test.ps1): Knox's moves as the test
-- sees them. A move is put down at once: written where it goes, the thing in the container.
TEST_MOVES = {}
KnoxDrag = {}
function KnoxDrag.allowedIn() return true end
function KnoxDrag.ownTile() end
function KnoxDrag.sourceOf() return nil end
function KnoxDrag.settle(L, e)
    local x, y, r = KnoxGrid.placeNew(L, e)
    return x, y, r, false
end
function KnoxDrag.moveTo(player, e, source, L, x, y, r)
    table.insert(TEST_MOVES, {items = e.items, key = L.key, x = x, y = y, r = r})
    KnoxGrid.writePending(e, L.key, x, y, r)
    for _, it in ipairs(e.items) do
        local from = it:getContainer()
        if from then from:remove(it) end
        L.container:add(it)
    end
end
-- what is put on: by a field of the test's own
KnoxEquip = {wearLoc = function(item) return item.wear or "" end}
