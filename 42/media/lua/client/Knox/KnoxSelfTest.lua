-- Developer self-test (DEV panel > "Self-test", or KnoxSelfTest.run() in the
-- Lua console). Checks what can be checked without a person at the screen:
-- fonts and text helpers, item footprints, grid layout rules (places, stacks,
-- split, rotation), drag rules, context menu sizes, item tooltips in Knox's
-- style, the inspect window's models, translations and the screen layout.
--
-- One step per tick, so the game stays responsive. Each line goes to
-- console.txt and to Zomboid/Lua/Knox_selftest.txt, which ends with
--   DONE pass=N fail=N skip=N
-- Test items are made with instanceItem and never put in the world.
-- No pcall probing: the game's debugger stops even on caught errors.

require "Knox/KnoxTheme"
require "Knox/KnoxGrid"
require "Knox/KnoxDrag"
require "Knox/KnoxEquipment"
require "Knox/KnoxContextMenu"
require "Knox/KnoxInspectWindow"
-- (KnoxScreen is used only while a test runs: requiring it here closed a
-- require loop KnoxScreen -> KnoxDevPanel -> KnoxSelfTest -> KnoxScreen)

KnoxSelfTest = KnoxSelfTest or {}
local ST = KnoxSelfTest
local T = KnoxTheme

local REPORT = "Knox_selftest.txt"
local run = nil

local function log(s)
    print("[Knox] TEST " .. s)
    local w = getFileWriter(REPORT, true, not run.fresh)
    if w then
        w:write(s .. "\r\n")
        w:close()
    end
    run.fresh = false
end

local function check(name, ok, detail)
    if ok then
        run.pass = run.pass + 1
        log("PASS " .. name)
    else
        run.fail = run.fail + 1
        log("FAIL " .. name .. " : " .. tostring(detail))
    end
    return ok
end

local function skip(name, why)
    run.skip = run.skip + 1
    log("SKIP " .. name .. " : " .. tostring(why))
end

local function info(s) log("INFO " .. s) end

-- Text from character codes and plain strings (the game reads Lua files as
-- single bytes, so no Cyrillic in string literals here).
local function w(...)
    local out = {}
    for i, c in ipairs({...}) do out[i] = type(c) == "number" and string.char(c) or c end
    return table.concat(out)
end

--- A test item, or nil when the type doesn't exist in this game version.
local function make(fullType)
    if not getScriptManager():FindItem(fullType) then return nil end
    return instanceItem(fullType)
end

-- Grid invariants: every placed tile inside the grid, cells pointing back at
-- the tile that covers them, no cell claimed twice.
local function layoutProblems(L)
    local seen = {}
    for _, e in ipairs(L.placed) do
        local w, h = KnoxGrid.dims(e, e.r)
        if e.x < 0 or e.y < 0 or e.x + w > L.cols or e.y + h > L.rows then
            return "tile out of grid: " .. e.item:getFullType()
        end
        -- a bag with compartments: whole inside one of them, or in the rows under
        -- them as wide as they are drawn
        if L.shape and e.y < (L.baseRows or L.rows) then
            local p = L:partAt(e.x, e.y)
            if not p or p ~= L:partAt(e.x + w - 1, e.y + h - 1) then
                return "tile across compartments: " .. e.item:getFullType()
            end
        elseif L.shape and e.x + w > L.shape.ovCols then
            return "tile past the rows under the compartments: " .. e.item:getFullType()
        end
        for yy = e.y, e.y + h - 1 do
            for xx = e.x, e.x + w - 1 do
                local k = yy * L.cols + xx
                if seen[k] then return "cell " .. xx .. "," .. yy .. " taken twice" end
                seen[k] = true
                if not e.overflow and L:blocked(xx, yy) then return "cell " .. xx .. "," .. yy .. " is past the grid's last cell" end
                if L:cellAt(xx, yy) ~= e then return "cell " .. xx .. "," .. yy .. " points elsewhere" end
            end
        end
    end
    return nil
end

local function tileOf(L, item)
    for _, e in ipairs(L.placed) do
        for _, it in ipairs(e.items) do
            if it == item then return e end
        end
    end
    return nil
end

-- Steps -----------------------------------------------------------------------------

local steps = {}

steps[#steps + 1] = function(p)
    info("Knox Inventory " .. tostring(Knox and Knox.VERSION) .. ", game " .. getCore():getVersion()
        .. ", screen " .. getCore():getScreenWidth() .. "x" .. getCore():getScreenHeight() .. ", cell " .. T.cell)
    if knoxJavaVersion then
        info("Java part v" .. tostring(knoxJavaVersion()))
        check("java fonts ready", T.javaFonts, "knoxFontReady false - atlases in media/fonts/knox not loaded")
        check("java tooltip hooks present", knoxTooltipBegin ~= nil and knoxTooltipEnd ~= nil, "old KnoxInventoryJava.jar - restart the game")
        check("java avatar mirror present", knoxAvatarMirror ~= nil and knoxAvatarHands ~= nil, "old KnoxInventoryJava.jar - restart the game")
        if knoxAvatarHands then info("hands now: " .. tostring(knoxAvatarHands(p))) end
    else
        check("java part loaded", false, "KnoxInventoryJava.jar not loaded - ZombieBuddy missing or not started")
    end
    check("inspect model scripts loaded",
        getScriptManager():getModelScript("KnoxInspect.SchoolBag_Ground__Bag_SchoolBag_0") ~= nil,
        "media/scripts/knox_inspect_models.txt not parsed")
end

steps[#steps + 1] = function(p)
    -- Kahlua strings: one code per character (the text helpers rely on it)
    check("strings are wide characters", string.byte(getText("IGUI_Knox_Pockets"), 1) > 255 or getText("IGUI_Knox_Pockets") == "Pockets", "string.byte of a translated text = " .. tostring(string.byte(getText("IGUI_Knox_Pockets"), 1)))
    local lowerRu, upperRu = w(1097, 1080, 1090, ", ", 1105, 1078, " ", 1080, " Zed"), w(1065, 1048, 1058, ", ", 1025, 1046, " ", 1048, " ZED")
    check("upper: Cyrillic", T.upper(lowerRu) == upperRu, T.upper(lowerRu))
    local long = string.rep(w(1046, 1046, 1046, 1046, " "), 10)
    local cut = T.fit(long, T.fontText, 60)
    check("fit: cuts to width", T.measure(T.fontText, cut) <= 60 and string.sub(cut, -1) == ".", cut)
    local knife = w(1053, 1086, 1078)
    check("fit: keeps short text", T.fit(knife, T.fontText, 500) == knife, T.fit(knife, T.fontText, 500))
    for _, role in ipairs({"fontHeader", "fontTab", "fontText", "fontCaps", "fontTile"}) do
        local f = T[role]
        local h, wd = T.fontH(f), T.measure(f, w(1055, 1088, 1086, 1074, 1077, 1088, 1082, 1072))
        check("font " .. role, h > 4 and wd > 10, "height " .. tostring(h) .. ", width " .. tostring(wd))
    end
    check("gameFont is a game font", type(T.gameFont(T.fontText)) ~= "table", "got a Knox handle")
    check("font sizes ordered", T.fontH(T.fontHeader) >= T.fontH(T.fontText) and T.fontH(T.fontText) >= T.fontH(T.fontTile),
        T.fontH(T.fontHeader) .. " / " .. T.fontH(T.fontText) .. " / " .. T.fontH(T.fontTile))
end

local SAMPLE = {
    "Base.Axe", "Base.BaseballBat", "Base.Pistol", "Base.HuntingKnife", "Base.Hammer",
    "Base.Tshirt_DefaultTEXTURE_TINT", "Base.Shoes_Black", "Base.Hat_BaseballCap",
    "Base.TinnedBeans", "Base.Apple", "Base.Crisps", "Base.WaterBottle", "Base.PopBottle",
    "Base.Nails", "Base.Bandage", "Base.Pills", "Base.Book", "Base.Magazine", "Base.Lighter",
    "Base.Bag_Schoolbag", "Base.Bag_ALICEpack", "Base.FirstAidKit", "Base.Toolbox", "Base.Garbagebag",
    "Base.Key1", "Base.Money", "Base.Plank", "Base.Battery",
}

steps[#steps + 1] = function(p)
    local bad, made = {}, 0
    for _, ft in ipairs(SAMPLE) do
        local item = make(ft)
        if item then
            made = made + 1
            local w, h = KnoxFootprint.get(item)
            -- short side first, within what the rules ever give
            if not (w >= 1 and h >= w and w <= 4 and h <= 6) then table.insert(bad, ft .. "=" .. w .. "x" .. h) end
            local stack = KnoxGrid.stackLimit(item)
            if not (stack >= 1 and stack <= 100) then table.insert(bad, ft .. " stack " .. tostring(stack)) end
        end
    end
    info("footprints: " .. made .. " of " .. #SAMPLE .. " sample types exist")
    check("footprints within 1..4 x 1..6, stacks 1..100", #bad == 0, table.concat(bad, ", "))
    -- sizes that anchor the scale: a bat is four cells long, a can one, a handgun two
    for _, a in ipairs({{"Base.BaseballBat", 1, 4}, {"Base.TinnedBeans", 1, 1}, {"Base.Pistol", 1, 2}}) do
        local item = make(a[1])
        if item then
            local w, h = KnoxFootprint.get(item)
            check("footprint " .. a[1], w == a[2] and h == a[3], w .. "x" .. h)
        end
    end
    local nails = make("Base.Nails")
    if nails then check("stack: nails by the dozen", KnoxGrid.stackLimit(nails) >= 20, KnoxGrid.stackLimit(nails)) end
    -- every container type: a grid of sane size, about two cells per unit of capacity;
    -- a bag with compartments (KnoxBagShapes) as wide on screen as 8 cells at most
    local wrong, n, shaped = {}, 0, 0
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local s = scripts:get(i)
        if s:isItemType(ItemType.CONTAINER) and not s:getObsolete() and not s:isHidden() then
            local bag = instanceItem(s:getFullName())
            local inv = bag and bag:getInventory()
            if inv then
                n = n + 1
                local c, r = KnoxGrid.getSize(inv, p)
                local shape = KnoxGrid.shapeOf(inv, p)
                local cells, wide = c * r, c
                if shape then
                    shaped = shaped + 1
                    cells = shape.cells
                    wide = KnoxBagShapes.geometry(shape, T.cell).w / T.cell
                end
                if c < 1 or r < 1 or wide > 8 or r > KnoxGrid.MAX_H or cells < inv:getCapacity() * 1.5 then
                    table.insert(wrong, s:getFullName() .. "=" .. (shape and shape.spec or (c .. "x" .. r)))
                end
            end
        end
    end
    check("bag grids (" .. n .. ", " .. shaped .. " with compartments)", #wrong == 0, table.concat(wrong, ", "))
    -- the pockets: bare hands plus what the clothes worn now give
    local list, total = KnoxGrid.pockets(p)
    local cols, rows, limit = KnoxGrid.getSize(p:getInventory(), p)
    local parts = {}
    for _, row in ipairs(list) do table.insert(parts, row[1] .. " " .. row[2]) end
    info("pockets: " .. total .. " cells (" .. table.concat(parts, ", ") .. "), grid " .. cols .. "x" .. rows
        .. (limit and (", last cell " .. limit) or ""))
    check("pockets grid", cols == KnoxGrid.POCKETS_COLS and total >= KnoxGrid.HANDS and (limit or cols * rows) == total
        and total == KnoxGrid.pocketCells(p), total .. " cells in " .. cols .. "x" .. rows)
    local PL = KnoxGrid.build(p:getInventory(), p)
    check("pockets layout invariants", layoutProblems(PL) == nil, layoutProblems(PL))
end

-- a grid whose last row is not whole, and a stack past what a tile holds
steps[#steps + 1] = function(p)
    local bag = make("Base.Bag_Schoolbag")
    if not bag or not bag:getInventory() or not getScriptManager():FindItem("Base.Nails") then
        return skip("stack limit", "no school bag or nails")
    end
    local inv = bag:getInventory()
    local first = inv:AddItem("Base.Nails")
    local limit = KnoxGrid.stackLimit(first)
    for _ = 1, limit + 4 do inv:AddItem("Base.Nails") end
    local L = KnoxGrid.build(inv, p)
    local tiles, most = 0, 0
    for _, e in ipairs(L.placed) do
        tiles = tiles + 1
        most = math.max(most, #e.items)
    end
    check("stack limit: " .. (limit + 5) .. " nails in two tiles of " .. limit .. " at most", tiles == 2 and most == limit,
        tiles .. " tiles, biggest " .. most)
    -- the same grid with its last row cut to two cells: nothing lands past them
    -- (as one plain grid: a row cut short is what the pockets have, not a bag with
    -- compartments - their own test is the next step)
    local cut = KnoxGrid.emptyLike(L)
    cut.shape = nil
    cut.limit = (cut.rows - 1) * cut.cols + 2
    local e = {item = first, items = {first}, w = 1, h = 1}
    check("cut row: a cell of it is free", cut:fits(1, cut.rows - 1, 1, 1), "refused")
    check("cut row: past its last cell is not", not cut:fits(2, cut.rows - 1, 1, 1), "allowed")
    check("cut row: a block reaching past it is not", not cut:fits(1, cut.rows - 2, 2, 2), "allowed")
    check("cut row: a block above it is free", cut:fits(1, cut.rows - 3, 2, 2), "refused")
    local n = 0
    for _ = 1, cut.cols * cut.rows do
        local x, y, r = cut:findFree(e)
        if not x then break end
        cut:occupy({item = first, items = {first}, w = 1, h = 1}, x, y, r)
        n = n + 1
    end
    check("cut row: holds " .. cut.limit .. " cells", n == cut.limit, n)
end

-- a bag with compartments (KnoxBagShapes): things lie whole inside one of them,
-- the main room fills first, a cell between them is no cell, and on screen a
-- compartment's cell turns back into the same cell
steps[#steps + 1] = function(p)
    local bag = make("Base.Bag_Schoolbag")
    if not bag or not bag:getInventory() then return skip("compartments", "no school bag") end
    local inv = bag:getInventory()
    local L = KnoxGrid.build(inv, p)
    local shape = L.shape
    if not check("compartments: the school bag has them", shape ~= nil, "one grid") then return end
    local main = shape.main
    check("compartments: a block in the main room fits", L:fits(main.lx, main.ly, 2, 2), "refused")
    local side = shape.parts[1] ~= main and shape.parts[1] or shape.parts[2]
    check("compartments: a block across two of them doesn't",
        not L:fits(side.lx, side.ly, side.w + 2, 1) and not L:fits(main.lx + main.w - 1, main.ly, 2, 1), "allowed")
    local gapX = side.lx + side.w
    check("compartments: the cell between them is no cell", L:blocked(gapX, side.ly) and L:partAt(gapX, side.ly) == nil, "a cell")
    local probe = make("Base.TinnedBeans")
    if probe then
        local x, y = L:findFree({item = probe, items = {probe}, w = 1, h = 1})
        check("compartments: the main room first", x and L:partAt(x, y) == main, tostring(x) .. "," .. tostring(y))
    end
    local view = KnoxGridView:new(0, 0, inv, p:getPlayerNum())
    local bad = 0
    for _, part in ipairs(shape.parts) do
        for yy = part.ly, part.ly + part.h - 1 do
            for xx = part.lx, part.lx + part.w - 1 do
                -- (a compartment of any form: only its own cells of its box)
                if shape.mask[yy * shape.cols + xx] == part then
                    local px, py = view:cellPx(xx, yy)
                    local cx, cy = view:cellAtPx(px + 1, py + 1)
                    if cx ~= xx or cy ~= yy then bad = bad + 1 end
                end
            end
        end
    end
    check("compartments: cells to pixels and back", bad == 0, bad .. " cells off")
    local wide = view:pxSize()
    check("compartments: as wide as 8 cells at most", wide <= 8 * T.cell, wide .. " px")
    check("compartments: size text", string.find(KnoxGrid.sizeText(L), "+", 1, true) ~= nil, KnoxGrid.sizeText(L))
end

steps[#steps + 1] = function(p)
    local bag = make("Base.Bag_Schoolbag")
    if not bag or not bag:getInventory() then return skip("grid layout", "no school bag") end
    local inv = bag:getInventory()
    local cols, rows = KnoxGrid.getSize(inv, p)
    check("bag grid size", cols >= 1 and rows >= 1, cols .. "x" .. rows)
    for _, ft in ipairs({"Base.Hammer", "Base.TinnedBeans", "Base.TinnedBeans", "Base.WaterBottle", "Base.Book", "Base.Apple"}) do
        if getScriptManager():FindItem(ft) then inv:AddItem(ft) end
    end
    local nails = {}
    for _ = 1, 5 do
        if getScriptManager():FindItem("Base.Nails") then table.insert(nails, inv:AddItem("Base.Nails")) end
    end
    local L = KnoxGrid.build(inv, p)
    check("layout invariants", layoutProblems(L) == nil, layoutProblems(L))
    check("nothing overflows", #L.overflow == 0, #L.overflow .. " tiles left out")
    local count = 0
    for _, e in ipairs(L.placed) do count = count + #e.items end
    local shown = 0   -- (an unarmed-combat mod's hidden fists get no tile)
    for i = 0, inv:getItems():size() - 1 do
        if not inv:getItems():get(i):isHidden() then shown = shown + 1 end
    end
    check("every item on a tile", count == shown, count .. " of " .. shown)

    if #nails == 5 then
        local t = tileOf(L, nails[1])
        check("stack: 5 nails share a tile", t ~= nil and #t.items == 5, t and #t.items or "no tile")
        -- split 2 off, as KnoxActions.split does
        KnoxGrid.setStackId({nails[4], nails[5]}, KnoxGrid.newStackId())
        local L2 = KnoxGrid.build(inv, p)
        local a, b = tileOf(L2, nails[1]), tileOf(L2, nails[5])
        check("split: two tiles 3 + 2", a and b and a ~= b and #a.items == 3 and #b.items == 2,
            (a and #a.items or "?") .. " + " .. (b and #b.items or "?"))
        check("split: invariants", layoutProblems(L2) == nil, layoutProblems(L2))
        check("merge allowed for same type", KnoxGrid.canMerge(b, a), "canMerge false")
        local other
        for _, t in ipairs(L2.placed) do
            if t.item:getFullType() ~= "Base.Nails" then other = t break end
        end
        if other then check("merge refused for other type", not KnoxGrid.canMerge(b, other), "canMerge true") end
        KnoxGrid.setStackId({nails[4], nails[5]}, nil)
        local L3 = KnoxGrid.build(inv, p)
        check("merge back: one tile of 5", tileOf(L3, nails[5]) == tileOf(L3, nails[1]) and #tileOf(L3, nails[1]).items == 5,
            "tiles differ")
    else
        skip("stacks", "no Base.Nails")
    end

    -- saved places survive a rebuild
    local before = {}
    for _, e in ipairs(L.placed) do before[e.item] = e.x .. "," .. e.y .. "," .. e.r end
    local again = KnoxGrid.build(inv, p)
    local moved = 0
    for _, e in ipairs(again.placed) do
        if before[e.item] and before[e.item] ~= (e.x .. "," .. e.y .. "," .. e.r) then moved = moved + 1 end
    end
    check("places stable across rebuilds", moved == 0, moved .. " tiles moved")

    -- a rotated place is kept
    local e = again.placed[1]
    if e and e.w ~= e.h then
        local fx, fy = again:findFree({item = e.item, items = e.items, w = e.h, h = e.w})
        if fx then
            KnoxGrid.writePlace(e, again.key, fx, fy, 1)
            local L4 = KnoxGrid.build(inv, p)
            local t = tileOf(L4, e.item)
            check("rotation saved", t and t.r == 1, t and ("r=" .. t.r) or "no tile")
            check("rotation: invariants", layoutProblems(L4) == nil, layoutProblems(L4))
        else
            skip("rotation", "no room to rotate")
        end
    else
        skip("rotation", "first tile is square")
    end
end

steps[#steps + 1] = function(p)
    local outer, inner = make("Base.Bag_ALICEpack"), make("Base.Bag_Schoolbag")
    if not (outer and inner) then return skip("drag rules", "bags missing") end
    check("bag can't go into itself", not KnoxDrag.allowedIn(outer, outer:getInventory(), p), "allowed")
    outer:getInventory():AddItem(inner)
    check("bag can't go into a bag inside it", not KnoxDrag.allowedIn(outer, inner:getInventory(), p), "allowed")
    local nails = make("Base.Nails")
    if nails then check("nails into a bag", KnoxDrag.allowedIn(nails, outer:getInventory(), p), "refused") end
    -- bags in bags (2026-10-19): any bag goes into another; one with things in it
    -- takes more cells, in steps; things go into a bag that lies in another
    local third, kit = make("Base.Bag_Schoolbag"), make("Base.FirstAidKit")
    if third then
        local w0, h0 = KnoxFootprint.get(third)
        check("empty bag into a bag", KnoxDrag.allowedIn(third, outer:getInventory(), p), "refused")
        third:getInventory():AddItem("Base.Nails")
        local ok, why = KnoxDrag.allowedIn(third, outer:getInventory(), p)
        check("bag with things in it into a bag", ok, tostring(why))
        local w1, h1 = KnoxFootprint.get(third)
        check("bag with things in it grows", w1 * h1 > w0 * h0, w0 .. "x" .. h0 .. " -> " .. w1 .. "x" .. h1)
        local total = KnoxGrid.totalCells(third:getInventory(), nil)
        local fw, fh = KnoxGrid.steppedBag(third:getInventory(), w0, h0, total, total)
        check("full bag takes about its cells", fw * fh >= total and fw * fh <= total * 1.5, fw .. "x" .. fh .. " of " .. total)
        check("bag with things in it into the pockets", KnoxGrid.nestRefusal(third, p:getInventory(), p) == nil, "refused")
    end
    if kit and kit:getInventory() then
        kit:getInventory():AddItem("Base.Bandage")
        check("organizer with things in it into a bag", KnoxGrid.nestRefusal(kit, outer:getInventory(), p) == nil, "refused")
    end
    if nails then
        local ok, why = KnoxDrag.allowedIn(nails, inner:getInventory(), p)
        check("things into a bag that lies in a bag", ok, tostring(why))
    end
end

-- Bags of any form (KnoxBagShapes.compileMask; the drawn ones are kept unused,
-- S.MASKS_DRAWN): the fanny pack's 4 over 2 as one compartment - a 4x1 fits its
-- top row, a 2x2 not at its left corner but in its middle
steps[#steps + 1] = function(p)
    local s = KnoxBagShapes.compileMask({"####", ".##."})
    if not check("free shapes: compile", s ~= nil and s.cells == 6 and #s.parts == 1, s and s.cells) then return end
    local L = setmetatable({}, getmetatable(KnoxGrid.build(p:getInventory(), p, true)))
    L.cols, L.rows, L.baseRows, L.shape, L.cells, L.placed, L.overflow = s.cols, s.rows, s.rows, s, {}, {}, {}
    check("free shapes: a 4x1 along the top fits", L:fits(0, 0, 4, 1), "refused")
    check("free shapes: a 2x2 at the left corner doesn't", not L:fits(0, 0, 2, 2), "allowed")
    check("free shapes: a 2x2 in the middle fits", L:fits(1, 0, 2, 2), "refused")
end

-- Things found in the world scattered (KnoxGrid.build): a random place is a free
-- one, and a tile taken off leaves its cells free
steps[#steps + 1] = function(p)
    local L = setmetatable({}, getmetatable(KnoxGrid.build(p:getInventory(), p, true)))
    L.cols, L.rows, L.baseRows, L.cells, L.placed, L.overflow = 4, 3, 3, {}, {}, {}
    local big = {w = 2, h = 2, items = {}}
    L:occupy(big, 1, 0, 0)
    local ok = true
    for _ = 1, 20 do
        local e = {w = 2, h = 1, items = {}}
        local x, y, r = L:findRandom(e)
        local w, h = KnoxGrid.dims(e, r or 0)
        if not x or not L:fits(x, y, w, h) then ok = false end
    end
    check("scatter: a random place is free", ok, "taken")
    L:vacate(big)
    check("scatter: a tile taken off frees its cells", L:fits(0, 0, 4, 3) and #L.placed == 0, "still there")
end

-- Grids and stacks after the complaints' review (2026-10-19)
steps[#steps + 1] = function(p)
    local school = make("Base.Bag_Schoolbag")
    if school and school:getInventory() then
        local cells = KnoxGrid.totalCells(school:getInventory(), p)
        local want = school:getInventory():getCapacity() * KnoxFootprint.CELLS_PER_CAPACITY * KnoxFootprint.gridScale()
        check("school bag follows the size setting", math.abs(cells - want) <= want * 0.25, cells .. " for " .. want)
    end
    for _, ft in ipairs({"Base.WheatSeed", "Base.ChickenFeather", "Base.GrassTuft"}) do
        local it = make(ft)
        if it then
            check(ft .. " stacks", KnoxGrid.isStackable(it) and KnoxGrid.stackLimit(it) > 1,
                tostring(KnoxGrid.isStackable(it)) .. " " .. tostring(KnoxGrid.stackLimit(it)))
        end
    end
    local apple = make("Base.Apple")
    if apple then check("fresh food doesn't stack", not KnoxGrid.isStackable(apple), "stacks") end
    for _, ft in ipairs({"Base.Magazine", "Base.HayTuft", "Base.TunaTin", "Base.Crackers"}) do
        local it = make(ft)
        if it then check(ft .. " doesn't stack (taken back)", not KnoxGrid.isStackable(it), "stacks") end
    end
    local ring = make("Base.KeyRing")
    if ring and ring:getInventory() then
        local w0, h0 = KnoxFootprint.get(ring)
        ring:getInventory():AddItem("Base.Key1")
        local w1, h1 = KnoxFootprint.get(ring)
        check("key ring doesn't grow with keys", w0 == w1 and h0 == h1, w0 .. "x" .. h0 .. " -> " .. w1 .. "x" .. h1)
    end
    check("own inventory key bound", KnoxControls.get("toggle") ~= "", "unbound")
end

steps[#steps + 1] = function(p)
    local m = ISContextMenu:new(0, 0, 1, 1, 1)
    m:initialise()
    m:setFontFromOption()
    check("menu: Knox sizes applied", m.knoxFont ~= nil and m.itemHgt > m.fontHgt, "itemHgt " .. tostring(m.itemHgt))
    m:addOption("Inspect", nil, nil)
    local o = m:addOption("A very long context menu option to check the menu width", nil, nil)
    o.notAvailable = true
    local w = m:calcWidth()
    check("menu: width fits the longest option", w >= T.measure(m.knoxFont, o.name), w)
    check("menu: height = rows", m:getHeight() == 2 * m.itemHgt + m.padTopBottom * 2, m:getHeight())
    local item = make("Base.Hammer")
    if item then
        KnoxContextMenu.setTarget({item}, p:getPlayerNum())
        local shown = getPlayerContextMenu(p:getPlayerNum()):isAnyVisible()
        check("menu target only while a menu is open", KnoxContextMenu.isTarget(item) == shown, "isTarget mismatch")
        KnoxContextMenu.target = nil
    end
end

-- Knox's item menu (2026-10-18): a header, the game's actions in groups, the
-- dangerous ones last, a reason under an option that can't be chosen; the rows
-- map back to the game's options under the mouse.
steps[#steps + 1] = function(p)
    if not (T.on and T.on("menus")) then return skip("menu layout", "Knox menus off") end
    if not T.javaFonts then return skip("menu layout", "Java part or fonts missing (the header is the tooltip's)") end
    local item = make("Base.Hammer")
    if not item then return skip("menu layout", "no hammer") end
    local P = ISInventoryPaneContextMenu
    local m = ISContextMenu:new(0, 0, 1, 1, 1)
    m:initialise()
    m:setFontFromOption()
    m.parent = nil   -- (a root menu, as ISContextMenu.get makes it)
    m.knoxTarget = {list = {item}}
    local drop = m:addOption("Drop", {item}, P.onDropItems, 0)
    local wear = m:addOption("Equip", {item}, P.OnPrimaryWeapon, 0)
    local mod = m:addOption("Some mod's option", nil, function() end)
    local grab = m:addOption("Grab", {item}, P.onGrabItems, 0)
    local dark = m:addOption("Read", {item}, P.onLiteratureItems, 0)
    dark.notAvailable = true
    dark.toolTip = {description = " <RGB:1,0,0> Too dark <LINE> to read here"}
    local put = m:addOption("Put", {item}, P.onPutItems, 0)
    m:calcHeight()
    local L = m.knoxL
    local kinds, order = {}, {}
    for _, r in ipairs(L.rows) do
        table.insert(kinds, r.kind)
        if r.kind == "opt" then table.insert(order, m.options[r.i]) end
    end
    -- (2026-10-18: on top the main action - a hammer's: into the hand; "Read" can't be done:
    -- it stays in its group; "Other" folded; "Put in the container" left out)
    check("menu: header on an item's menu", kinds[1] == "head", table.concat(kinds, ","))
    check("menu: the main action on top, then the groups' labels", L.grouped and kinds[2] == "opt" and kinds[3] == "label",
        table.concat(kinds, ","))
    check("menu: dangerous last, after a line", order[#order] == drop and kinds[#kinds - 1] == "sep", table.concat(kinds, ","))
    check("menu: order (main, use, move, other)",
        order[1] == wear and order[2] == dark and order[3] == grab and order[4] == mod, "order")
    check("menu: Other folded", L.byIndex[mod.id] and L.byIndex[mod.id].h == 0, "not folded")
    check("menu: Put in the container left out", L.byIndex[put.id] == nil, "shown")
    local dr = L.byIndex[dark.id]
    check("menu: reason under the option", dr and dr.reason == "Too dark" and dr.h > m.itemHgt, dr and tostring(dr.reason))
    local sum = 0
    for _, r in ipairs(L.rows) do sum = sum + r.h end
    check("menu: height = its rows", m:getHeight() == sum + m.padTopBottom * 2, m:getHeight() .. " vs " .. sum)
    local hits = true
    for _, r in ipairs(L.rows) do
        if r.h >= 1 then
            local y = m.padTopBottom + r.y + math.floor(r.h / 2)
            local at = m:getIndexAt(5, y)
            if (r.kind == "opt" and at ~= r.i) or (r.kind ~= "opt" and at ~= -1) then hits = false end
        end
    end
    check("menu: the mouse finds the option of each row", hits, "getIndexAt")
    -- a menu not about Knox's items keeps the game's order
    local w = ISContextMenu:new(0, 0, 1, 1, 1)
    w:initialise()
    w:setFontFromOption()
    w:addOption("Drop", {item}, P.onDropItems, 0)
    w:addOption("Equip", {item}, P.OnPrimaryWeapon, 0)
    check("menu: other menus as they came", not w.knoxL.grouped and w.knoxL.rows[1].i == 1, "grouped")
    -- the world's menu (2026-10-18): the place's header, its objects on top, the
    -- groups, the dangerous last; an object's sub menu with the object's header
    local wm = ISContextMenu:new(0, 0, 1, 1, 1)
    wm:initialise()
    wm:setFontFromOption()
    wm.parent = nil
    wm.knoxWorld = {square = nil, ground = 0}
    local walk = wm:addOption(getText("ContextMenu_Walk_to"), nil, function() end)
    local sink = wm:addOption("Sink")
    local sub = ISContextMenu:getNew(wm)
    wm:addSubMenu(sink, sub)
    sub:addOption(getText("ContextMenu_Drink"), nil, function() end)
    sub:addOption(getText("ContextMenu_Destroy"), nil, function() end)
    local modOpt = wm:addOption("Some mod's option", nil, function() end)
    local destroy = wm:addOption(getText("ContextMenu_Destroy"), nil, function() end)
    wm:calcHeight()
    local WL = wm.knoxL
    local wk, wo = {}, {}
    for _, r in ipairs(WL.rows) do
        table.insert(wk, r.kind)
        if r.kind == "opt" then table.insert(wo, wm.options[r.i]) end
    end
    check("world menu: the place's header", wk[1] == "whead", table.concat(wk, ","))
    check("world menu: the object on top", wo[1] == sink, table.concat(wk, ","))
    check("world menu: the dangerous last, after a line", wo[#wo] == destroy and wk[#wk - 1] == "sep", table.concat(wk, ","))
    check("world menu: groups", WL.grouped and wo[2] == walk and WL.byIndex[modOpt.id] ~= nil, table.concat(wk, ","))
    sub:calcHeight()
    local SL = sub.knoxL
    check("world menu: the object's sub menu has its header", SL.rows[1] and SL.rows[1].kind == "whead" and SL.rows[1].wh.title == "Sink",
        SL.rows[1] and SL.rows[1].kind or "none")
end

-- The car's dashboard (2026-10-18; as a car's, 2026-10-21): its pictures, the game's
-- dashboard taken over, the two bodies (which car gets which, everything inside
-- its panel), the radio's stations step and the player's card in the car.
local DASH_PICS = {"disc", "hub", "soft", "needle", "glow", "bar", "grad", "shade_disc", "face_glow", "cap_light", "knurl", "reel",
                   "key_blade", "key_head", "key_groove", "key_edge", "key_shadow",
                   "tach_ticks_k100", "tach_red_k133", "tach_glow_k160", "speed_ticks_k80", "speed_glow_k200",
                   "fuel_ticks_k133", "fuel_red_k100", "fuel_glow_k100",
                   "hood_sedan_fill_k100", "hood_sedan_dark_k133", "hood_sedan_lip_k160", "hood_sedan_shadow_k200",
                   "disc_44", "knurl_34", "lamp_engine_26", "key_head_100", "seg_8_h28", "seg_1g_h36",
                   "ring_16", "ring_22", "ring_30", "ring_40", "ring_54", "ring_72", "ring_96", "ring_128", "ring_170", "ring_226",
                   "seg_0", "seg_1", "seg_2", "seg_3", "seg_4", "seg_5", "seg_6", "seg_7", "seg_8", "seg_9", "seg_8g", "seg_1g",
                   "temp_arc", "temp_track",
                   "lamp_engine", "lamp_battery", "lamp_lights", "lamp_doors", "lamp_heater", "lamp_cruise",
                   "lamp_trunk", "lamp_fuel", "lamp_lockc", "lamp_locko", "lamp_mix", "lamp_rpt", "lamp_rpt1"}

--- A pretend car with a script of this name (for which body it gets).
local function carNamed(name)
    return {getScript = function() return {getName = function() return name end} end}
end

--- Is r = {x, y, w, h} inside {X, Y, W, H}?
local function inside(r, box)
    return r[1] >= box[1] and r[2] >= box[2] and r[1] + r[3] <= box[1] + box[3] and r[2] + r[4] <= box[2] + box[4]
end

steps[#steps + 1] = function(p)
    if not (T.on and T.on("dashboard")) then return skip("dashboard", "Knox dashboard off") end
    local missing = {}
    for _, n in ipairs(DASH_PICS) do
        if not getTexture("media/ui/knoxdash/" .. n .. ".png") then table.insert(missing, n) end
    end
    check("dashboard: its pictures", #missing == 0, table.concat(missing, ","))
    check("dashboard: the game's dashboard taken over", ISVehicleDashboard and ISVehicleDashboard.knoxHooked == true, "not hooked")
    local KD = KnoxDashboard
    if KD and KD.bodyFor then
        local wrong = {}
        for name, want in pairs({CarNormal = KD.SEDAN, CarLuxury = KD.SEDAN, SportsCar = KD.SEDAN, PickUpTruck = KD.TRUCK,
            PickUpVanLightsFire = KD.TRUCK, VanAmbulance = KD.TRUCK, StepVan_Mail = KD.TRUCK, SUV = KD.TRUCK, OffRoad = KD.TRUCK}) do
            if KD.bodyFor(carNamed(name)) ~= want then table.insert(wrong, name) end
        end
        check("dashboard: sedans and pickups by the car's script", #wrong == 0, table.concat(wrong, ","))
        -- every plate inside the panel; the radio and the heater inside the centre stack
        local out = {}
        for _, b in ipairs({KD.SEDAN, KD.TRUCK}) do
            local panel = {0, 0, b.W, b.H}
            for i, pl in ipairs(b.plates) do
                if not inside(pl, panel) then table.insert(out, b.kind .. " plate " .. i) end
            end
            local stack = b.plates[#b.plates]
            if not inside({b.radio[1], b.radio[2], 284, 72}, stack) then table.insert(out, b.kind .. " radio") end
            if not inside(b.climate, stack) then table.insert(out, b.kind .. " heater") end
            for _, d in ipairs(b.dials) do
                local r = d.R + d.wall
                if not inside({d.cx - r, d.cy - r, r * 2, r * 2}, panel) then table.insert(out, b.kind .. " " .. d.id) end
            end
        end
        check("dashboard: everything inside its panel", #out == 0, table.concat(out, ","))
    end
    local MM = KnoxMenuMusic
    check("dashboard: the car's radio answers the card", MM and MM.carStations and MM.carTitle and MM.carAllowed and MM.carOpenWindow,
        "KnoxCarRadio")
    -- (a car's stations in the list, back / next step through them: the menu's
    -- player in the car's context, played with a pretend set)
    if MM and MM.carStations then
        local saved = {ctx = MM.ctx, list = MM.list, at = MM.at, st = MM.carStations, tune = MM.carTune, music = T.settings["car.music"]}
        local tuned
        MM.ctx = "car"
        T.settings["car.music"] = "game"
        MM.carStations = function() return {{freq = 88000, title = "88.0"}, {freq = 91200, title = "91.2"}, {freq = 99400, title = "99.4"}} end
        MM.carTune = function(f) tuned = f end
        MM.buildList()
        MM.at = 3
        MM.next()
        check("dashboard: next station wraps to the first", tuned == 88000 and MM.at == 1, tostring(tuned))
        MM.prev()
        check("dashboard: back from the first to the last", tuned == 99400 and MM.at == 3, tostring(tuned))
        check("dashboard: the list is the stations", #MM.list == 3 and MM.list[2].kind == "station", tostring(#MM.list))
        MM.ctx, MM.list, MM.at, MM.carStations, MM.carTune = saved.ctx, saved.list, saved.at, saved.st, saved.tune
        T.settings["car.music"] = saved.music
    end
end

-- The health tab (1.0, 2026-10-18): its masks, the hit map against the parts, the
-- zones, its icons and texts, every reading of the body without an error, the
-- titled menu of a body part, the tab in the screen.
local HEALTH_ICONS = {"heal", "disinfect", "unbandage", "splint", "tweezers", "burn", "poultice", "unstitch", "unsplint",
                      "bandage", "sew", "zone_head", "zone_thorax", "zone_stomach", "zone_arm", "zone_leg"}
local HEALTH_TEXTS = {"State", "Body", "Damage", "Kit", "Stats", "Effects", "AllBody", "Destroyed", "Missing", "Doctor",
    "HpOf", "Pace", "PaceWait", "PaceStable", "PaceOther", "PerHour", "Wounds", "Bleeding", "Bites", "NoInjuries", "More",
    "NoEffects", "NoDamage", "NoDamageSub", "ZoneHealthy", "ZoneHealthySub", "HealMin", "HealHours", "HealDays",
    "NotHealing", "CanRemove", "QuickTreat", "BtnQuick", "BtnMenu", "NothingToQuick", "WillTreat", "WontHelp", "Treating",
    "KitEmpty", "KitHint", "KitApply", "KeyLmb", "KeyRmb", "KeyShiftLmb", "HintSelect", "HintMenu", "HintQuick",
    "NoTreatment", "NeedBandage", "NeedDisinfectant", "NeedNeedle", "NeedSplint", "NeedTweezers", "RemoveBandageFirst",
    "RemoveGlassFirst", "Risk", "VitalPulse", "VitalBP", "VitalBlood", "Stat_temperature",
    "Health", "Worsening", "Improving", "FineMore", "Important", "HealingNow", "Path", "Needs", "Have", "HaveNone", "BtnBack", "BtnTreat", "BtnUrgent", "AllGood", "AllGoodSub", "JustHeals", "Do_ChangeBandage", "Do_Menu", "St_Bleeding", "St_Bandaged", "St_Open", "St_Stitched", "St_Cleaned", "St_Broken", "St_Splinted", "St_Lodged", "St_Removed", "St_Infected", "St_Disinfected", "St_Healed", "St_CanRemove", "St_Dirty", "Need_ContextMenu_Bandage", "Need_ContextMenu_Disinfect", "Need_ContextMenu_Stitch", "Need_ContextMenu_Remove_Glass", "Need_ContextMenu_Remove_Bullet", "Need_ContextMenu_Splint", "Need_ContextMenu_Clean_Burn", "Need_ContextMenu_PlantainCataplasm", "Need_ContextMenu_ComfreyCataplasm", "Need_ContextMenu_GarlicCataplasm"}

steps[#steps + 1] = function(p)
    if not (T.on and T.on("health") and KnoxHealthPanel) then return skip("health tab", "health module off") end
    local H, Care, Model = KnoxHealthData, KnoxHealthCare, KnoxHealthModel
    -- the masks: a hidden item and its picture per part and gender
    local missing = {}
    for _, z in ipairs(Model.doll.zones) do
        for _, g in ipairs({"M", "F"}) do
            if not getScriptManager():FindItem("KnoxHealth.KH_HL_" .. g .. "_" .. z.part) then table.insert(missing, g .. "_" .. z.part) end
            if not getTexture("media/textures/KnoxHealth/hl_" .. string.lower(g) .. "_" .. z.part .. ".png") then
                table.insert(missing, "tex " .. g .. "_" .. z.part)
            end
        end
    end
    check("health: the model's masks", #missing == 0, table.concat(missing, ","))
    -- the 3D skeleton (Knox Inventory Java/tools/healthpaint/SkeletonGen.java): its item and texture
    check("health: the skeleton", getScriptManager():FindItem("KnoxHealth.KH_Skeleton") ~= nil
        and getTexture("media/textures/KnoxHealth/knox_skeleton.png") ~= nil,
        "KnoxHealth.KH_Skeleton or media/textures/KnoxHealth/knox_skeleton.png missing")
    -- the paint on the GPU (Java v48): there, or the mask clothing stays
    if knoxHealthPaint then
        check("health: skin paint", not (knoxHealthPaintFailed and knoxHealthPaintFailed()),
            "a GL step failed - the model is painted with mask clothing (console: [Knox] health paint)")
    else
        info("health: GPU paint not in this Java part (v" .. tostring(knoxJavaVersion and knoxJavaVersion()) .. ") - mask clothing")
    end
    -- the hit map: each part's centre finds that part
    local wrong = {}
    for _, z in ipairs(Model.doll.zones) do
        local at = Model.partAt(z.cx, z.cy)
        if at ~= z.index then table.insert(wrong, z.part .. "->" .. tostring(at)) end
    end
    check("health: the hit map finds every part", #wrong == 0, table.concat(wrong, ","))
    -- the zones: every body part in exactly one
    local seen, dup = {}, {}
    for _, z in ipairs(H.ZONES) do
        for _, i in ipairs(z.parts) do
            if seen[i] then table.insert(dup, tostring(i)) end
            seen[i] = true
        end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    check("health: seven zones cover the 17 parts", #H.ZONES == 7 and n == 17 and #dup == 0, n .. " parts, twice: " .. table.concat(dup, ","))
    local noIcon = {}
    for _, name in ipairs(HEALTH_ICONS) do
        if not getTexture("media/ui/knoxicons/menu_" .. name .. ".png") then table.insert(noIcon, name) end
    end
    check("health: its icons", #noIcon == 0, table.concat(noIcon, ","))
    local noText = {}
    for _, key in ipairs(HEALTH_TEXTS) do
        if not getTextOrNull("IGUI_KnoxHP_" .. key) then table.insert(noText, key) end
    end
    for _, z in ipairs(H.ZONES) do
        if not getTextOrNull("IGUI_KnoxHP_Zone_" .. z.id) then table.insert(noText, "Zone_" .. z.id) end
    end
    for _, s in ipairs(H.STATS) do
        if not getTextOrNull("IGUI_KnoxHP_Stat_" .. s.id) then table.insert(noText, "Stat_" .. s.id) end
    end
    check("health: its texts", #noText == 0, table.concat(noText, ","))
    -- every reading of the body, on this character as it is
    local ok, err = pcall(function()
        local bps = p:getBodyDamage():getBodyParts()
        for i = 0, bps:size() - 1 do
            local bp = bps:get(i)
            H.buildPartInfo(p, bp, H.doctorLevel(p))
            Care.keysFor(p, bp, nil)
            Care.quickTreat(p, bp, true)
        end
        for _, z in ipairs(H.ZONES) do
            H.zoneState(p, z)
            H.zoneKinds(p, z)
            H.zoneSev(p, z)
        end
        H.damageRates(p)
        H.healthPace(p)
        H.counters(p)
        H.moodles(p)
        H.stats(p)
        H.temperature(p)
        Care.kit(p)
        -- (the model's paint with a kit's thing under the mouse: it broke on `next`, 2026-10-19)
        Model.paint(p, {hover = "head", selected = "larm", glow = {[0] = true, [6] = true}})
        Model.paint(p, {})
        -- the GPU paint's layers: the same view, twice (the colours ease)
        local av = {}
        Model.layers(av, p, {hover = "head", selected = "larm", glow = {[0] = true, [6] = true}})
        Model.layers(av, p, {})
        -- the wounds (the redesigned tab's badges and rows) and what each needs
        for _, w in ipairs(KnoxHealthWounds.list(p, function(bp) return Care.quickTreat(p, bp, true) end)) do
            KnoxHealthWounds.needs(p, w)
        end
    end)
    check("health: reading the body", ok, tostring(err))
    -- the wound icons (Knox Inventory Java/tools/healthpaint/IconGen.java)
    local noWIcon = {}
    for _, name in ipairs({"bleeding", "scratch", "cut", "deepwound", "bite", "glass", "bullet", "burn", "fracture",
                           "infected", "destroyed", "other", "healed", "o_band", "o_dirty", "o_stitch", "o_splint",
                           "o_clean", "o_removed", "o_poultice", "o_heal"}) do
        if not KnoxHealthWounds.icon(name) then table.insert(noWIcon, name) end
    end
    check("health: the wound icons", #noWIcon == 0, table.concat(noWIcon, ","))
    -- a body part's menu: the titled header, as the world's
    if T.on("menus") and KnoxContextMenu and KnoxContextMenu.setTitle and T.javaFonts then
        local menu = getPlayerContextMenu(p:getPlayerNum())
        if menu then
            KnoxContextMenu.setTitle(p:getPlayerNum(), "Forearm", "Health 80/100", "zone_arm", T.color.good)
            menu:clear()
            menu:addOption(getText("ContextMenu_Bandage"), nil, function() end)
            menu:calcHeight()
            local L = menu.knoxL
            local r = L and L.rows[1]
            check("health: a part's menu has its header", r and r.kind == "whead" and r.wh.kind == "title" and r.wh.title == "Forearm",
                r and r.kind or "none")
            menu:clear()
            menu:setVisible(false)
        end
    end
    -- the tab in the screen
    local wasOpen = KnoxScreen.instance ~= nil
    if not wasOpen then KnoxScreen.toggle(p:getPlayerNum()) end
    local s = KnoxScreen.instance
    if s then
        local was = s.tab
        s:setTab("Health")
        check("health: the tab opens in the screen", s.tab == "Health" and s.health ~= nil and s.health:getIsVisible()
            and not s.inventory:getIsVisible(), tostring(s.tab))
        if s.health then
            local m = s.health:metrics()
            check("health: the body and the side fit", m.rx + m.rw <= s.health:getWidth() + 1 and m.bw > T.cell * 8
                and m.midH > T.cell * 6, m.bw .. "/" .. m.rw .. " x " .. m.midH)
        end
        s:setTab(was ~= "Health" and was or "Equipment")
        check("health: the tab hides again", not (s.health and s.health:getIsVisible()), "still shown")
        if not wasOpen then s:close() end
    end
end

local TOOLTIP_ITEMS = {"Base.Axe", "Base.Tshirt_DefaultTEXTURE_TINT", "Base.TinnedBeans", "Base.WaterBottle",
                       "Base.Lighter", "Base.Book", "Base.Bag_Schoolbag", "Base.Nails"}

steps[#steps + 1] = function(p)
    if not (knoxTooltipBegin and T.javaFonts) then return skip("styled tooltips", "Java part or fonts missing") end
    for _, ft in ipairs(TOOLTIP_ITEMS) do
        local item = make(ft)
        if item then
            local tip = ObjectTooltip.new()
            tip:setCharacter(p)
            local spacing = tip:getLineSpacing()
            tip:setWidth(50)
            tip:setMeasureOnly(true)
            local styled = knoxTooltipBegin("body", "title", T.cell * 0.31, item:getName(p))
            item:DoTooltip(tip)
            knoxTooltipEnd()
            tip:setMeasureOnly(false)
            local w, h = tip:getWidth(), tip:getHeight()
            check("tooltip " .. ft, styled and w > 50 and h > T.fontH(T.fontText), "styled=" .. tostring(styled) .. " " .. w .. "x" .. h)
            if tip:getLineSpacing() ~= spacing then
                check("tooltip statics restored", false, spacing .. " -> " .. tip:getLineSpacing())
            end
        end
    end
end

steps[#steps + 1] = function(p)
    local found, total = 0, 0
    for _, ft in ipairs({"Base.Axe", "Base.Hammer", "Base.WaterBottle", "Base.Bag_Schoolbag", "Base.TinnedBeans"}) do
        local item = make(ft)
        if item then
            total = total + 1
            local model = KnoxInspectScene.modelFor(item)
            if model then found = found + 1 else info("no 3D model for " .. ft .. " (icon shown)") end
        end
    end
    check("inspect: models found", found >= total - 1, found .. " of " .. total)
    local bag = make("Base.Bag_Schoolbag")
    if bag then
        local model = KnoxInspectScene.modelFor(bag)
        check("inspect: bag uses its textured copy", model and string.find(model, "^KnoxInspect%.") ~= nil, tostring(model))
    end
end

steps[#steps + 1] = function(p)
    local missing = {}
    local function need(key) if not getTextOrNull(key) then table.insert(missing, key) end end
    for id in pairs(KnoxEquip.SLOTS) do need("IGUI_Knox_Slot_" .. id) end
    for _, id in ipairs({"primary", "secondary", "backAttach"}) do need("IGUI_Knox_Slot_" .. id) end
    for _, id in ipairs(KnoxScreen.TABS) do need("IGUI_Knox_Tab_" .. id) end
    need("IGUI_Knox_Tab_Surroundings")
    -- every module's switch in the settings: its name, what it does, its group
    for _, name in ipairs(T.MODULES) do
        need("IGUI_Knox_Module_" .. name)
        need("IGUI_Knox_Module_" .. name .. "_Info")
    end
    for _, g in ipairs(T.MODULE_GROUPS) do need("IGUI_Knox_Modules_Group_" .. g.id) end
    for _, id in ipairs({"Condition", "Damage", "Range", "Speed", "Crit", "Ammo", "Bite", "Scratch", "Bullet",
                         "Insulation", "Wind", "Water", "Hunger", "Thirst", "Calories", "Freshness", "Capacity",
                         "Filled", "Reduction", "Left", "Fluid", "Weight", "Size"}) do
        need("IGUI_Knox_Stat_" .. id)
    end
    check("translations present", #missing == 0, table.concat(missing, ", "))
    local hints = 0
    for part in string.gmatch(getText("IGUI_Knox_Hints"), "[^;]+") do
        if string.find(part, "|") then hints = hints + 1 end
    end
    check("key hints parse", hints >= 5, hints)
    local worn = KnoxEquip.collect(p)
    local n = 0
    for id in pairs(KnoxEquip.SLOTS) do n = n + #worn[id] end
    info("worn items sorted into slots: " .. n)
end

steps[#steps + 1] = function(p)
    local wasOpen = KnoxScreen.instance ~= nil
    if not wasOpen then KnoxScreen.toggle(p:getPlayerNum()) end
    local s = KnoxScreen.instance
    if not s then return check("screen opens", false, "no instance") end
    local W = s:getWidth()
    check("screen fills the screen", W == getCore():getScreenWidth() and s:getHeight() == getCore():getScreenHeight(),
        W .. "x" .. s:getHeight())
    local last = s.columns[3]
    check("columns fit", last.x + last.w <= W, (last.x + last.w) .. " > " .. W)
    check("surroundings column shown", s.loot ~= nil, "screen too narrow: " .. last.w .. " px")
    local tabs = s:tabRects()
    local tabsEnd = tabs[#tabs].x + tabs[#tabs].w
    -- left to right: tabs ... DEV, weight bar, close
    local dx = s:devRect()
    local closeX = s:closeRect()
    local limit = dx or (closeX - T.pad * 2 - T.cell * 5)
    check("tabs clear of the weight bar", tabsEnd < limit, tabsEnd .. " >= " .. limit)
    s:setTab("News")     -- (Skills, Crafting... open the game's own windows and close the screen)
    check("tab switch hides columns", not s.inventory:getIsVisible(), "inventory still visible")
    s:setTab("Equipment")
    check("tab switch back", s.inventory:getIsVisible() and s.equipment:getIsVisible(), "columns hidden")
    if not wasOpen then s:close() end
end

-- The big check-up (2026-10-21): the Java part this Lua needs; the text sizes kept
-- in Lua are the Java part's; a context menu keeps its layout while nothing in it
-- changes and lays itself out anew when an option gets its picture after addOption.
steps[#steps + 1] = function(p)
    local v = knoxJavaVersion and tonumber(knoxJavaVersion()) or nil
    check("java part as new as the Lua needs", v ~= nil and v >= T.JAVA_NEEDED, "v" .. tostring(v) .. ", needed " .. T.JAVA_NEEDED)
    if T.javaFonts then
        local bad = {}
        local s = w(1055, 1088, 1086, 1074, 1077, 1088, 1082, 1072) .. " 42 Zed"
        for _, role in ipairs({"fontHeader", "fontTab", "fontText", "fontCaps", "fontTile"}) do
            local f = T[role]
            local a, b, j = T.measure(f, s), T.measure(f, s), knoxTextWidth(f.style, f.size, s)
            if a ~= j or b ~= j then table.insert(bad, role .. " width " .. a .. "/" .. b .. "/" .. j) end
            if T.fontH(f) ~= knoxFontHeight(f.style, f.size) then table.insert(bad, role .. " height") end
        end
        check("kept text sizes = the Java part's", #bad == 0, table.concat(bad, ", "))
    else
        skip("kept text sizes", "the game's fonts (Java part or language)")
    end
    if not (T.on and T.on("menus")) then return skip("menu layout kept", "Knox menus off") end
    local tex = getTexture("media/ui/knoxicons/menu_eat.png")
    if not tex then return skip("menu layout kept", "no menu icon texture") end
    local m = ISContextMenu:new(0, 0, 1, 1, 1)
    m:initialise()
    m:setFontFromOption()
    m:addOption("An option with a long name to widen the menu", nil, function() end)
    local two = m:addOption("Another option with a long name", nil, function() end)
    local L, n = m.knoxL, m.knoxLayoutN
    m:calcHeight()
    check("menu: its layout kept while nothing changes", m.knoxL == L and m.knoxLayoutN == n,
        tostring(m.knoxLayoutN) .. " vs " .. tostring(n))
    two.iconTexture = tex
    m:calcHeight()
    check("menu: a picture set after addOption lays it out anew, wider", m.knoxL ~= L and m.knoxL.w > L.w,
        tostring(L and L.w) .. " -> " .. tostring(m.knoxL and m.knoxL.w))
end

-- Runner -----------------------------------------------------------------------------

local function finishRun()
    log(string.format("DONE pass=%d fail=%d skip=%d", run.pass, run.fail, run.skip))
    local p = run.player
    if p and HaloTextHelper then
        local text = getText("IGUI_Knox_DevTestDone", run.pass, run.fail, run.skip)
        if run.fail > 0 then HaloTextHelper.addBadText(p, text) else HaloTextHelper.addGoodText(p, text) end
    end
    ST.last = {pass = run.pass, fail = run.fail, skip = run.skip}
    run = nil
end

local function onTick()
    if not run then return end
    local step = steps[run.i]
    if not step then return finishRun() end
    run.i = run.i + 1
    step(run.player)
end

function ST.run(playerNum)
    if run then return end
    local p = getSpecificPlayer(playerNum or 0)
    if not p then return end
    if not T.cell then T.refresh() end
    run = {i = 1, pass = 0, fail = 0, skip = 0, player = p, fresh = true}
    log("Knox self-test, game hour " .. math.floor(getGameTime():getWorldAgeHours()))
end

function ST.isRunning() return run ~= nil end

Events.OnTick.Add(onTick)

return KnoxSelfTest
