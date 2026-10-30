-- A grid with its ready lists (KnoxGridView:renderGrid, the inventory's FPS stage 3,
-- 2026-10-29) on the game's Lua with tools/settings/stubs.lua, the real KnoxTheme,
-- KnoxSelect and KnoxGridView and a made-up Java part: the cells are written once and
-- played back while the grid's size is the same; a calm grid's quiet tiles too, until
-- it is built again; a tile under the mouse, flashing, settling, selected, with its
-- window open or on its way is drawn by Lua over the played list, and once it is quiet
-- again the list is written anew; with a thing held, a search by name or a thing in
-- use every tile is looked at by Lua as before; a bag with compartments keeps its
-- list only while all its tiles are quiet.
local T = KnoxTheme
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

-- the Java part: lists begun, ended, played; the quiet tiles it drew
local J = {begun = 0, ended = 0, played = 0, tiles = 0}
local lists = {}
knoxListBegin = function(jo, id) J.begun = J.begun + 1 J.rec = id lists[id] = nil end
knoxListEnd = function() J.ended = J.ended + 1 lists[J.rec] = true J.rec = nil return true end
knoxListDraw = function(jo, id)
    if not lists[id] then return 0 end
    J.played = J.played + 1
    return 2
end
knoxDrawTiles = function(jo, list, n) J.tiles = J.tiles + n DRAWN = DRAWN + n end

T.category.misc = T.category.misc or {r = 0.2, g = 0.2, b = 0.2}
local cat = T.category.misc

local function item(name)
    return {name = name, getFullType = function() return name end, getDisplayName = function() return name end}
end
local function tile(it, x, y, n)
    local items = {it}
    for i = 2, n or 1 do items[i] = item(it.name .. i) end
    return {item = it, items = items, x = x, y = y, w = 1, h = 1, r = 0, draw = {cat = cat}}
end
local function layout(placed, shape, cols)
    local L = {cols = cols or 6, rows = 4, placed = placed, shape = shape}
    function L:cellAt(x, y)
        for _, e in ipairs(self.placed) do
            if e.x == x and e.y == y then return e end
        end
        return nil
    end
    return L
end

local a, b, c = item("Apple"), item("Bullets"), item("Cup")
local A, B, C = tile(a, 0, 0), tile(b, 1, 0, 3), tile(c, 2, 1)
local NEXT = layout({A, B, C})
KnoxGrid.build = function() return NEXT end
local view = KnoxGridView:new(0, 0, {}, 0)
local hover = nil
function view:entityUnderMouse() return hover end
function view:offerKinds() end
function view:offerBattery() end

-- one frame of `v`: how many draws Lua made
-- built again (and what left the grid not faded out: not this test's)
local function rebuild(v)
    v:rebuild()
    v.leaving = nil
end

local function frame(v)
    J.begun, J.ended, J.played, J.tiles = 0, 0, 0, 0
    DRAWN = 0
    clock = clock + 16
    KnoxGrid.frame = KnoxGrid.frame + 1
    ;(v or view):renderGrid()
    return DRAWN
end

-- frames until Lua draws nothing and both lists play (a lift, a flash, a fade over)
local function calmDown(v, n)
    local written = 0
    for _ = 1, n or 40 do
        if frame(v) == 0 and J.played == 2 then return written end
        written = written + J.begun
    end
    return -1
end

do
    local first = frame()
    check("first frame: cells and tiles written", J.begun == 2 and J.ended == 2 and J.tiles == 3 and first > 3, first)
    check("second frame: both played, Lua draws nothing", frame() == 0 and J.played == 2 and J.begun == 0 and J.tiles == 0)
    check("third frame: played", frame() == 0 and J.played == 2)
end

do
    hover = A
    local n = frame()
    check("mouse on a tile: the tiles written anew, the cells played", J.begun == 1 and J.played == 1 and J.tiles == 2 and n > 2, n)
    n = frame()
    check("mouse on it: the list played, the tile drawn by Lua", J.played == 2 and J.begun == 0 and J.tiles == 0 and n > 0, n)
    for _ = 1, 8 do frame() end   -- (lifted all the way)
    hover = nil
    n = frame()
    check("mouse gone: written anew, the tile still coming down by Lua", J.begun == 1 and J.tiles == 2 and n > 2, n)
    local w = calmDown()
    check("down: written once more, then played", w >= 1, w)
    check("down: the tile among the quiet", frame() == 0 and J.played == 2)
end

do
    KnoxGridView.flashItems({b})
    frame()
    check("a flash: written anew, the stack drawn by Lua", J.begun == 1 and J.tiles == 2)
    local n = frame()
    check("flashing: played, the flash by Lua", J.played == 2 and n > 0, n)
    clock = clock + 6000
    local w = calmDown()
    check("flash over: written anew, then played", w >= 1, w)
end

do
    -- the stack's count: in the list, not drawn by Lua when it plays
    check("the stack's count played with the list", frame() == 0 and J.played == 2)
end

do
    KnoxDrag.entity = {item = a, items = {a}}
    local n = frame()
    check("a thing held: Lua looks at every tile, no tiles' list", J.played == 1 and J.begun == 0 and J.tiles == 2 and n > 2, n)
    check("held: still Lua", frame() > 2 and J.played == 1 and J.tiles == 2)
    KnoxDrag.entity = nil
    frame()
    check("let go: written anew", J.begun == 1 and J.tiles == 3)
    check("let go: played", frame() == 0 and J.played == 2)
end

do
    KnoxScreen = {instance = {}, search = "u"}
    local n = frame()
    check("a search by name: Lua", J.played == 1 and J.tiles == 0 and n > 0, n)
    KnoxScreen.search = ""
    local w = calmDown(nil, 60)
    check("search gone: tiles fade back, then played", w >= 1, w)
    KnoxScreen = nil
end

do
    KnoxSelect.toggle(C)
    frame()
    check("a tile selected: written anew, it by Lua", J.begun == 1 and J.tiles == 2)
    local n = frame()
    check("selected: played, its frame by Lua", J.played == 2 and n > 0, n)
    KnoxSelect.clear()
    frame()
    check("selection gone: written anew", J.begun == 1 and J.tiles == 3)
    check("selection gone: played", frame() == 0 and J.played == 2)
end

do
    KnoxContainerWindow = {list = {}}
    function KnoxContainerWindow.isOpen(it)
        for _, w in ipairs(KnoxContainerWindow.list) do
            if w.item == it then return w end
        end
        return nil
    end
    check("no window yet: played", frame() == 0 and J.played == 2)
    table.insert(KnoxContainerWindow.list, {item = c})
    frame()
    check("a thing's window opens: written anew, its tile by Lua", J.begun == 1 and J.tiles == 2)
    check("window open: played, the tile's frame by Lua", frame() > 0 and J.played == 2 and J.begun == 0)
    KnoxContainerWindow.list = {}
    frame()
    check("window shut: written anew", J.begun == 1 and J.tiles == 3)
    check("window shut: played", frame() == 0 and J.played == 2)
end

do
    KnoxGrid.useNow = {[a] = 0.5}
    local n = frame()
    check("a thing in use: Lua", J.played == 1 and J.tiles == 2 and n > 0, n)
    KnoxGrid.useNow = {}
    frame()
    check("use over: written anew", J.begun == 1 and J.tiles == 3)
end

do
    -- built again: a new layout - the tiles written anew, the cells (same size) played
    NEXT = layout({tile(a, 0, 0), tile(b, 1, 0, 3), tile(c, 2, 1)})
    rebuild(view)
    frame()
    check("built again: tiles written, cells played", J.begun == 1 and J.played == 1 and J.tiles == 3)
    check("built again: played", frame() == 0 and J.played == 2)
    -- a thing moved to another cell: it settles in, drawn by Lua, then quiet
    NEXT = layout({tile(a, 0, 0), tile(b, 1, 0, 3), tile(c, 4, 2)})
    rebuild(view)
    local n = frame()
    check("a thing moved: settles in by Lua", J.begun == 1 and J.tiles == 2 and n > 0, n)
    local w = calmDown()
    check("settled: written anew, then played", w >= 1, w)
end

do
    -- a move on its way: its reserved cells breathe (Lua) over the played list
    local d = item("Drill")
    local R = {item = d, items = {d}, x = 5, y = 3, w = 1, h = 1, r = 0, reserved = true, draw = {cat = cat}}
    NEXT = layout({tile(a, 0, 0), tile(b, 1, 0, 3), tile(c, 4, 2), R})
    rebuild(view)
    frame()
    check("a move on its way: written", J.begun == 1 and J.tiles == 3)
    local n = frame()
    check("on its way: played, its cells by Lua", J.played == 2 and J.tiles == 0 and n > 0, n)
end

do
    -- scrolled: other rows on the screen, the list anew
    view.visibleRows = function() return 1, 4 end
    frame()
    check("scrolled: written anew with the rows in sight", J.begun == 1 and J.tiles == 1)
    view.visibleRows = nil
    frame()
    check("scrolled back: written anew", J.begun == 1 and J.tiles == 3)
end

do
    -- another size: the cells written anew
    NEXT = layout({tile(a, 0, 0)}, nil, 8)
    rebuild(view)
    frame()
    check("another size: the cells written anew", J.begun == 2)
    check("another size: played", frame() == 0 and J.played == 2)
end

do
    T.listsOff = true
    local n = frame()
    check("lists off: Lua alone", J.played == 0 and J.begun == 0 and J.tiles == 1 and n > 1, n)
    T.listsOff = nil
    frame()
    check("lists on: both written", J.begun == 2)
    KnoxSettings = {instance = {}}
    frame()
    check("settings open: Lua alone", J.played == 0 and J.begun == 0 and J.tiles == 1)
    KnoxSettings = nil
    frame()
    check("settings shut: both written", J.begun == 2)
end

do
    -- a bag with compartments: Lua draws its tiles one by one - the list holds them all
    local part = {w = 6, h = 4}
    KnoxBagShapes = {
        geometry = function(_, cs)
            return {w = 6 * cs, h = 4 * cs, ovX = 0, ovY = 4 * cs, ovW = 0, parts = {[part] = {x = 0, y = 0}}}
        end,
        cellPx = function(_, cs, x, y) return x * cs, y * cs end,
    }
    local shape = {parts = {part}, ovCols = 0}
    local P, rope = tile(item("Pen"), 0, 0), item("Rope")
    NEXT = layout({P, tile(rope, 2, 1)}, shape)
    local bag = KnoxGridView:new(0, 0, {}, 0)
    local over = nil
    function bag:entityUnderMouse() return over end
    function bag:offerKinds() end
    function bag:offerBattery() end
    local n = frame(bag)
    check("bag: cells and tiles written by Lua", J.begun == 2 and J.tiles == 0 and n > 2, n)
    check("bag: played", frame(bag) == 0 and J.played == 2)
    over = P
    n = frame(bag)
    check("bag, mouse on a tile: all by Lua, the cells played", J.begun == 0 and J.played == 1 and n > 2, n)
    check("bag, mouse on it: still Lua", frame(bag) > 2 and J.played == 1)
    for _ = 1, 8 do frame(bag) end   -- (lifted all the way)
    over = nil
    for _ = 1, 30 do frame(bag) end
    check("bag, mouse gone while it came down: Lua until it is built again", J.begun == 0 and J.played == 1)
    NEXT = layout({tile(P.item, 0, 0), tile(rope, 2, 1)}, shape)
    rebuild(bag)
    frame(bag)
    check("bag built again: written", J.begun == 1)
    check("bag: played again", frame(bag) == 0 and J.played == 2)
end

print("grid: " .. pass .. " pass, " .. fail .. " fail")
