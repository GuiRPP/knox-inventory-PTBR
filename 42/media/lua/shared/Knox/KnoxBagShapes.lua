-- Rigs (Knox 1.0): bags with compartments, as in Tarkov - a backpack has its main
-- room, a lid, side pockets for bottles; a chest rig has its magazine pouches. A
-- big thing doesn't go into a small pocket; anything that fits does (the author,
-- 2026-10-17: no pockets for one kind of thing only).
--
-- A bag's shape is written as rows of compartments, top to bottom, separated by
-- "/"; a row is its compartments left to right, each "WxH" in cells:
--     "4x2 / 1x2 5x6 1x2"   a 4x2 lid over a 5x6 main room with a 1x2 pocket each side
-- Every row is centred under the widest one and its compartments centred on the
-- row's height: a row the same backwards is symmetric, left to right, on screen.
-- The author's rule (2026-10-17): every shape is symmetric - tools\footprint\test
-- checks each row of the families below reads the same backwards.
--
-- The grid behind it: the compartments lie in one grid of cells (logical places,
-- what an item's saved place - modData knox {x, y} - means), apart from each other
-- by a row or column of cells that are no part of the bag (KnoxGrid's Layout:blocked),
-- so nothing lies across two compartments. On screen each compartment is drawn
-- where its row puts it (KnoxBagShapes.geometry), with a narrow gap between them.
--
-- Bags of mods keep one grid as before (variant "A", the author, 2026-10-17); a
-- player or a mod's author gives one compartments in Zomboid/Lua/knox_overrides.txt:
--     Mod.Bag = parts 4x2 / 1x2 5x6 1x2
-- (KnoxFootprint.parseOverride). A player's own "grid CxR" for a bag means one grid.

KnoxBagShapes = KnoxBagShapes or {}
local S = KnoxBagShapes

-- The families: a shape, and the bags that have it. Cells as the bag's capacity
-- gives them (KnoxFootprint: two a unit), shaped into compartments; a few rounded
-- to keep the shape whole. No row wider than the inventory column (8 cells, with
-- the gaps between its compartments: 7 cells when it has more than one).
S.FAMILIES = {
    -- military packs: a lid, the main room, outer pouches
    {name = "alice", spec = "4x2 / 6x6 / 2x2 2x2 2x2",
     types = {"Bag_ALICEpack", "Bag_ALICEpack_Army", "Bag_ALICEpack_DesertCamo"}},
    {name = "survivor", spec = "3x2 3x2 / 6x6 / 4x2",
     types = {"Bag_SurvivorBag"}},
    -- hiking packs: a lid, the main room, a bottle pocket each side
    {name = "hikingBig", spec = "4x2 / 1x2 5x6 1x2",
     types = {"Bag_BigHikingBag", "Bag_BigHikingBag_Travel"}},
    {name = "hiking", spec = "4x2 / 1x2 4x7 1x2",
     types = {"Bag_NormalHikingBag", "Bag_HikingBag_Travel"}},
    -- school bags: the main room, a bottle pocket each side, a front pocket
    {name = "school", spec = "1x2 4x5 1x2 / 3x2",
     types = {"Bag_Schoolbag", "Bag_Schoolbag_Kids", "Bag_Schoolbag_Patches", "Bag_Schoolbag_Travel"}},
    {name = "schoolMedical", spec = "1x2 4x4 1x2 / 4x1",
     types = {"Bag_Schoolbag_Medical"}},
    {name = "hydration", spec = "1x4 4x4 1x4",
     types = {"Bag_HydrationBackpack", "Bag_HydrationBackpack_Camo"}},
    -- duffels: the long main room, a pocket at each end
    {name = "duffel", spec = "7x4 / 2x2 2x2",
     types = {"Bag_DuffelBag", "Bag_DuffelBagTINT", "Bag_FoodCanned", "Bag_FoodSnacks", "Bag_MoneyBag", "Bag_InmateEscapedBag"}},
    {name = "tactical", spec = "1x2 1x2 1x2 1x2 / 7x4",
     types = {"Bag_Military", "Bag_Police", "Bag_Sheriff", "Bag_SWAT", "Bag_WeaponBag"}},
    {name = "tools", spec = "2x2 2x2 2x2 / 6x4",
     types = {"Bag_ToolBag", "Bag_WorkerBag", "Bag_BreakdownBag", "Bag_BurglarBag"}},
    {name = "medical", spec = "1x2 1x2 1x2 1x2 1x2 1x2 / 6x4",
     types = {"Bag_MedicalBag"}},
    {name = "doctor", spec = "2x1 2x1 / 4x3",
     types = {"Bag_DoctorBag"}},
    -- sports and long guns
    {name = "sports", spec = "8x3 / 3x2 3x2",
     types = {"Bag_BaseballBag", "Bag_TennisBag"}},
    {name = "golf", spec = "1x6 4x6 1x6",
     types = {"Bag_GolfBag", "Bag_GolfBag_Melee"}},
    {name = "gunBag", spec = "2x2 2x2 2x2 / 8x3",
     types = {"Bag_ShotgunBag", "Bag_ShotgunDblBag", "Bag_ShotgunSawnoffBag", "Bag_ShotgunDblSawnoffBag"}},
    {name = "rifleSoft", spec = "7x1 / 2x1 2x1 2x1",
     types = {"Bag_RifleCaseCloth", "Bag_RifleCaseCloth2", "Bag_RifleCaseClothCamo", "Bag_ShotgunCaseCloth", "Bag_ShotgunCaseCloth2"}},
    -- over the shoulder
    {name = "satchel", spec = "6x3 / 3x2",
     types = {"Bag_Satchel", "Bag_Satchel_Fishing", "Bag_Satchel_Leather", "Bag_Satchel_Mail", "Bag_Satchel_Medical",
              "Bag_Satchel_Military", "Bag_SatchelPhoto", "Bag_HideSatchel", "Bag_ClothSatchel_Burlap",
              "Bag_ClothSatchel_Cotton", "Bag_ClothSatchel_Denim", "Bag_ClothSatchel_DenimBlack", "Bag_ClothSatchel_DenimLight"}},
    {name = "slingSheet", spec = "4x4 / 2x2", types = {"Bag_SheetSlingBag"}},
    {name = "slingTarp", spec = "4x5 / 2x2", types = {"Bag_TarpSlingBag"}},
    {name = "slingHide", spec = "4x6 / 2x2", types = {"Bag_HideSlingBag"}},
    {name = "crude", spec = "4x5 / 2x2 2x2", types = {"Bag_CrudeLeatherBag", "Bag_CrudeTarpBag"}},
    -- frame packs (crafted): the main room on the frame, a pouch each side, a roll under it
    {name = "framepackSmall", spec = "1x3 4x5 1x3 / 4x1", types = {"Bag_CraftedFramepack_Small", "Bag_TarpFramepack_Small"}},
    {name = "framepack", spec = "1x3 5x6 1x3 / 4x1", types = {"Bag_CraftedFramepack_Large", "Bag_TarpFramepack_Large"}},
    {name = "framepackLarge", spec = "1x4 5x7 1x4 / 5x1", types = {"Bag_CraftedFramepack_Large2"}},
    {name = "framepackHuge", spec = "1x4 5x10 1x4 / 6x2", types = {"Bag_CraftedFramepack_Large3"}},
    -- on the chest and the belt: magazine pouches
    {name = "chestRig", spec = "1x2 1x2 1x2 1x2 / 2x1", types = {"Bag_ChestRig", "Bag_ChestRig_Tarp"}},
    {name = "beltRig", spec = "1x2 1x2 1x2 1x2 / 2x2",
     types = {"Bag_ALICE_BeltSus", "Bag_ALICE_BeltSus_Camo", "Bag_ALICE_BeltSus_Green"}},
    -- cases and boxes with a tray or organizer
    {name = "briefcase", spec = "4x3 / 1x1 1x1 1x1 1x1", types = {"Briefcase", "Briefcase_Money"}},
    {name = "toolbox", spec = "1x1 1x1 1x1 1x1 / 4x3",
     types = {"Toolbox", "Toolbox_Farming", "Toolbox_Fishing", "Toolbox_Gardening", "Toolbox_Mechanic", "Bag_JanitorToolbox"}},
    {name = "tacklebox", spec = "1x1 1x1 1x1 1x1 / 4x2", types = {"Tacklebox", "Toolbox_Wooden"}},
    {name = "suitcase", spec = "3x5 3x5 / 2x1", types = {"Suitcase"}},
    {name = "firstAid", spec = "1x1 1x1 1x1 1x1 / 4x1", types = {"FirstAidKit", "FirstAidKit_New", "FirstAidKit_NewPro"}},
}

-- Bags drawn cell by cell (the author, 2026-10-19, on the balance page - 2.5 cells a
-- unit of capacity): "#" a cell, "." none; groups of cells apart from each other are
-- compartments, and a compartment may have any form (4 cells over 2). They are drawn
-- for the default size (KnoxFootprint.GENEROUS, the slider at 100 %, no Organized);
-- another size adds rows to or takes them from the main room (S.scaledMask).
-- They go over the families above. tools/footprint/bag_masks_author.txt has them as drawn.
-- (taken back by the author the same day with the rest of the balance: kept here,
-- unused - S.MASKS is empty; to bring them back, S.MASKS = S.MASKS_DRAWN)
S.MASKS_DRAWN = {
    {types = {"Bag_FannyPackFront", "Bag_FannyPackBack"}, mask = {"####", ".##."}},
    {types = {"Parcel_Small", "Present_Small"}, mask = {"###", "###"}},
    {types = {"Parcel_Medium", "Present_Medium"}, mask = {"####", "####", "####"}},
    {types = {"Bag_FishingBasket"}, mask = {"#####", "#####", "#####"}},
    {types = {"Bag_DoctorBag"}, mask = {"##.##", ".....", "#####", "#####", "#####"}},
    {types = {"Bag_SheetSlingBag"}, mask = {"######", "######", "######", "######"}},
    {types = {"Bag_Schoolbag_Medical"},
     mask = {"..####..", "..####..", "..####..", "..####..", "..####..", "#......#", "#.####.#", "..####.."}},
    {types = {"Bag_TarpSlingBag"}, mask = {"######", "######", "######", "######", "......", ".####.", ".####."}},
    {types = {"Bag_CrudeLeatherBag", "Bag_CrudeTarpBag"},
     mask = {"######", "######", "######", "######", "######", "......", "######"}},
    {types = {"Bag_HideSlingBag"}, mask = {"######", "######", "######", "######", "......", ".####.", ".####.", ".####."}},
    {types = {"Bag_CraftedFramepack_Small", "Bag_TarpFramepack_Small"},
     mask = {"#.####.#", "#.####.#", "#.####.#", "..####..", "..####..", "..####..", "........", "..####..", "..####.."}},
    {types = {"Bag_Schoolbag", "Bag_Schoolbag_Kids", "Bag_Schoolbag_Patches", "Bag_Schoolbag_Travel"},
     mask = {"..####..", "..####..", "..####..", "#.####.#", "#.####.#", "#.####.#", "........", "..####..", "..####.."}},
    {types = {"Suitcase"}, mask = {"###.###", "###.###", "###.###", "###.###", "###.###", "###.###", "###.###"}},
    -- (drawn 11 wide; made 8 - the inventory column - with the same 48 cells, 2026-10-19)
    {types = {"Bag_MedicalBag"},
     mask = {"##.##.##", "........", ".######.", ".######.", ".######.", ".######.", ".######.", ".######.", ".######."}},
    {types = {"Bag_NormalHikingBag", "Bag_HikingBag_Travel"},
     mask = {"..####..", "..####..", "........", "#.####.#", "#.####.#", "..####..", "..####..", ".######.", ".######.", ".######.", ".######."}},
    -- (drawn 9 wide; made 8: a 4x2 lid, 1x4 side pockets, a 4x9 main room - 52 cells)
    {types = {"Bag_BigHikingBag", "Bag_BigHikingBag_Travel"},
     mask = {"..####..", "..####..", "........", "#.####.#", "#.####.#", "#.####.#", "#.####.#", "..####..", "..####..", "..####..", "..####..", "..####.."}},
}

S.MASKS = {}

S.MAX_ROW_CELLS = 8          -- the inventory column (KnoxInventoryPanel.columnWidth)
S.GAP_K = 0.2                -- the gap between compartments, of a cell

--- "4x2 / 1x2 5x6 1x2" -> {{{w=4,h=2}}, {{w=1,h=2},{w=5,h=6},{w=1,h=2}}}, or nil.
function S.parse(spec)
    if type(spec) ~= "string" then return nil end
    local rows = {}
    for rowText in string.gmatch(spec .. "/", "([^/]*)/") do
        local row = {}
        for w, h in string.gmatch(rowText, "(%d+)%s*[xX]%s*(%d+)") do
            w, h = tonumber(w), tonumber(h)
            if not w or not h or w < 1 or h < 1 or w > 20 or h > 20 then return nil end
            table.insert(row, {w = w, h = h})
        end
        if #row > 0 then table.insert(rows, row) end
    end
    if #rows == 0 then return nil end
    return rows
end

--- Does every row read the same backwards (symmetric on screen)?
function S.symmetric(rows)
    for _, row in ipairs(rows) do
        for i = 1, math.floor(#row / 2) do
            local a, b = row[i], row[#row + 1 - i]
            if a.w ~= b.w or a.h ~= b.h then return false end
        end
    end
    return true
end

--- The grid of a shape: cols, rows (the logical grid, compartments a cell apart),
--- mask (index y*cols+x -> part), parts {{lx, ly, w, h, row, i}} - in the order
--- things go into them (the biggest first) - cells (how many), mainW/H, ovCols (how
--- wide the rows under the grid for what doesn't fit may be), spec, rowsSpec.
function S.compile(spec)
    local rowsSpec = type(spec) == "table" and spec or S.parse(spec)
    if not rowsSpec then return nil end
    local parts, y, cols, ovCols = {}, 0, 0, 0
    for ri, row in ipairs(rowsSpec) do
        local x, rowH, cellsW = 0, 0, 0
        for i, p in ipairs(row) do
            table.insert(parts, {lx = x, ly = y, w = p.w, h = p.h, row = ri, i = i})
            x = x + p.w + 1
            cellsW = cellsW + p.w
            rowH = math.max(rowH, p.h)
        end
        cols = math.max(cols, x - 1)
        ovCols = math.max(ovCols, cellsW)
        y = y + rowH + 1
    end
    local shape = {cols = cols, rows = y - 1, parts = parts, mask = {}, cells = 0, ovCols = ovCols,
                   rowsSpec = rowsSpec, spec = type(spec) == "string" and spec or S.text(rowsSpec)}
    for _, p in ipairs(parts) do
        for yy = p.ly, p.ly + p.h - 1 do
            for xx = p.lx, p.lx + p.w - 1 do shape.mask[yy * cols + xx] = p end
        end
        shape.cells = shape.cells + p.w * p.h
    end
    -- things go into the biggest compartment first, then down the rows
    local order = {}
    for _, p in ipairs(parts) do table.insert(order, p) end
    table.sort(order, function(a, b)
        if a.w * a.h ~= b.w * b.h then return a.w * a.h > b.w * b.h end
        if a.row ~= b.row then return a.row < b.row end
        return a.i < b.i
    end)
    shape.order = order
    shape.main = order[1]
    return shape
end

--- A shape back to its text ("4x2 / 1x2 5x6 1x2").
function S.text(rowsSpec)
    local out = {}
    for _, row in ipairs(rowsSpec) do
        local r = {}
        for _, p in ipairs(row) do table.insert(r, p.w .. "x" .. p.h) end
        table.insert(out, table.concat(r, " "))
    end
    return table.concat(out, " / ")
end

--- A shape drawn cell by cell (S.MASKS): lines of "#" and ".". Each group of cells
--- touching by a side is a compartment of any form (`free`): its box (lx, ly, w, h),
--- its cells (`n`), and the cells are in `mask` one by one. Spec "mask:####|.##.".
function S.compileMask(lines)
    if type(lines) ~= "table" or #lines == 0 then return nil end
    local rows, cols = #lines, 0
    for _, l in ipairs(lines) do cols = math.max(cols, #l) end
    local function on(x, y)
        return x >= 0 and y >= 0 and x < cols and y < rows and string.sub(lines[y + 1], x + 1, x + 1) == "#"
    end
    local shape = {cols = cols, rows = rows, parts = {}, mask = {}, cells = 0, ovCols = 0, free = true,
                   maskLines = lines, spec = "mask:" .. table.concat(lines, "|")}
    for y = 0, rows - 1 do
        local inRow = 0
        for x = 0, cols - 1 do
            if on(x, y) then
                inRow = inRow + 1
                if not shape.mask[y * cols + x] then
                    -- a new compartment: everything joined to this cell by a side
                    local p = {lx = x, ly = y, n = 0, row = y, i = x}
                    local rx, ry = x, y
                    local stack = {{x, y}}
                    shape.mask[y * cols + x] = p
                    while #stack > 0 do
                        local c = table.remove(stack)
                        p.n = p.n + 1
                        p.lx, p.ly = math.min(p.lx, c[1]), math.min(p.ly, c[2])
                        rx, ry = math.max(rx, c[1]), math.max(ry, c[2])
                        for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
                            local nx, ny = c[1] + d[1], c[2] + d[2]
                            if on(nx, ny) and not shape.mask[ny * cols + nx] then
                                shape.mask[ny * cols + nx] = p
                                table.insert(stack, {nx, ny})
                            end
                        end
                    end
                    p.w, p.h = rx - p.lx + 1, ry - p.ly + 1
                    p.rect = p.w * p.h == p.n
                    table.insert(shape.parts, p)
                    shape.cells = shape.cells + p.n
                end
            end
        end
        shape.ovCols = math.max(shape.ovCols, inRow)
    end
    if #shape.parts == 0 then return nil end
    local order = {}
    for _, p in ipairs(shape.parts) do table.insert(order, p) end
    table.sort(order, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        if a.ly ~= b.ly then return a.ly < b.ly end
        return a.lx < b.lx
    end)
    shape.order = order
    shape.main = order[1]
    return shape
end

--- Mask lines with `scale` times the cells: a row of the main room with nothing
--- else beside it (the side pockets keep their size) is taken again, or such rows
--- are taken away, as many as the difference makes; at least one row of it stays.
function S.scaledMask(lines, scale)
    if not scale or math.abs(scale - 1) < 0.01 then return lines end
    local base = S.compileMask(lines)
    if not base then return lines end
    local main, cols = base.main, base.cols
    local pure = {}
    for r = main.ly, main.ly + main.h - 1 do
        local only = true
        for x = 0, cols - 1 do
            local p = base.mask[r * cols + x]
            if p and p ~= main then only = false break end
        end
        if only then table.insert(pure, r) end
    end
    local pick = pure[#pure] or (main.ly + main.h - 1)
    local _, inRow = string.gsub(lines[pick + 1], "#", "#")
    local extra = math.floor(base.cells * (scale - 1) / math.max(1, inRow) + 0.5)
    if extra == 0 then return lines end
    local out = {}
    if extra > 0 then
        for i, l in ipairs(lines) do
            table.insert(out, l)
            if i - 1 == pick then
                for _ = 1, extra do table.insert(out, l) end
            end
        end
        return out
    end
    -- taking away: the main room's own rows from the bottom up (all its rows when none is
    -- its own alone), one of them always kept
    local rowsOf = #pure > 0 and pure or {}
    if #rowsOf == 0 then for r = main.ly, main.ly + main.h - 1 do table.insert(rowsOf, r) end end
    local drop = {}
    local n = math.min(-extra, main.h - 1, #rowsOf - (#pure == main.h and 1 or 0))
    for i = #rowsOf, #rowsOf - n + 1, -1 do drop[rowsOf[i]] = true end
    for i, l in ipairs(lines) do
        if not drop[i - 1] then table.insert(out, l) end
    end
    return out
end

--- Pixels of a free shape's columns and rows: an empty column or row (between
--- compartments) is only a gap wide, as between the families' compartments.
local function freeGeometry(shape, cs, gap)
    local lines = shape.maskLines
    local colX, rowY = {}, {}
    local x = 0
    for c = 0, shape.cols - 1 do
        colX[c] = x
        local any = false
        for _, l in ipairs(lines) do
            if string.sub(l, c + 1, c + 1) == "#" then any = true break end
        end
        x = x + (any and cs or gap)
    end
    colX[shape.cols] = x
    local y = 0
    for r = 0, shape.rows - 1 do
        rowY[r] = y
        y = y + (string.find(lines[r + 1], "#", 1, true) and cs or gap)
    end
    rowY[shape.rows] = y
    local g = {cs = cs, gap = gap, parts = {}, w = x, h = y, colX = colX, rowY = rowY}
    for _, p in ipairs(shape.parts) do g.parts[p] = {x = colX[p.lx], y = rowY[p.ly]} end
    return g
end

--- How a shape lies on screen with cells `cs` pixels: each row centred under the
--- widest, each compartment centred on its row's height, `gap` between them.
--- {w, h, gap, parts = {[part] = {x, y}}} (kept per shape and cell size: the
--- camp's bag and the grids draw the same shape at sizes of their own).
function S.geometry(shape, cs)
    shape.geos = shape.geos or {}
    local g = shape.geos[cs]
    if g then return g end
    local gap = math.max(4, math.floor(cs * S.GAP_K + 0.5))
    if shape.free then
        g = freeGeometry(shape, cs, gap)
        g.ovW = shape.ovCols * cs
        g.ovX = math.max(0, math.floor((g.w - g.ovW) / 2))
        g.ovY = g.h + gap
        shape.geos[cs] = g
        return g
    end
    g = {cs = cs, gap = gap, parts = {}, w = 0, h = 0}
    local rowW, rowH = {}, {}
    for _, p in ipairs(shape.parts) do
        rowW[p.row] = (rowW[p.row] or -gap) + p.w * cs + gap
        rowH[p.row] = math.max(rowH[p.row] or 0, p.h * cs)
    end
    for _, w in pairs(rowW) do g.w = math.max(g.w, w) end
    local top, x, lastRow = 0, 0, nil
    for _, p in ipairs(shape.parts) do
        if p.row ~= lastRow then
            if lastRow then top = top + rowH[lastRow] + gap end
            x = math.floor((g.w - rowW[p.row]) / 2)
            lastRow = p.row
        end
        g.parts[p] = {x = x, y = top + math.floor((rowH[p.row] - p.h * cs) / 2)}
        x = x + p.w * cs + gap
    end
    g.h = top + (lastRow and rowH[lastRow] or 0)
    -- the rows of what doesn't fit: centred under the compartments too, the same
    -- gap from them as between them (a block of their own, not against the last)
    g.ovW = shape.ovCols * cs
    g.ovX = math.max(0, math.floor((g.w - g.ovW) / 2))
    g.ovY = g.h + gap
    shape.geos[cs] = g
    return g
end

--- Top-left pixel of cell x,y of a bag of this shape (cells `cs` pixels): in its
--- compartment, or in the rows of what doesn't fit (from row `baseRows` down, under
--- the compartments); nil between compartments.
function S.cellPx(shape, cs, x, y, baseRows)
    local g = S.geometry(shape, cs)
    baseRows = baseRows or shape.rows
    if y >= baseRows then return g.ovX + x * cs, g.ovY + (y - baseRows) * cs end
    local p = shape.mask[y * shape.cols + x]
    if not p then return nil end
    if shape.free then return g.colX[x], g.rowY[y] end
    local o = g.parts[p]
    return o.x + (x - p.lx) * cs, o.y + (y - p.ly) * cs
end

--- The cell of a shape under pixel mx, my (its own grid, without the rows of what
--- doesn't fit), or nil between compartments.
function S.cellAtPx(shape, cs, mx, my)
    local g = S.geometry(shape, cs)
    if shape.free then
        local cx, cy
        for c = 0, shape.cols - 1 do
            if mx >= g.colX[c] and mx < g.colX[c + 1] then cx = c break end
        end
        for r = 0, shape.rows - 1 do
            if my >= g.rowY[r] and my < g.rowY[r + 1] then cy = r break end
        end
        if not cx or not cy or not shape.mask[cy * shape.cols + cx] then return nil end
        return cx, cy
    end
    for p, o in pairs(g.parts) do
        if mx >= o.x and mx < o.x + p.w * cs and my >= o.y and my < o.y + p.h * cs then
            return p.lx + math.floor((mx - o.x) / cs), p.ly + math.floor((my - o.y) / cs)
        end
    end
    return nil
end

local byType = nil
local compiled = {}

--- A shape with `scale` times its cells (KnoxFootprint.gridScale, a character's
--- Organized): the main room (the biggest compartment) gets the rows the
--- difference makes, the pockets around it stay - the shape stays symmetric
--- and no row gets wider.
function S.scaled(rowsSpec, scale)
    if not scale or math.abs(scale - 1) < 0.01 then return rowsSpec end
    local total, main = 0, nil
    for _, row in ipairs(rowsSpec) do
        for _, p in ipairs(row) do
            total = total + p.w * p.h
            if not main or p.w * p.h > main.w * main.h then main = p end
        end
    end
    local extra = math.floor(total * (scale - 1) / main.w + 0.5)
    if extra == 0 then return rowsSpec end
    local out = {}
    for _, row in ipairs(rowsSpec) do
        local r = {}
        for _, p in ipairs(row) do
            if p == main then
                table.insert(r, {w = p.w, h = math.max(1, p.h + extra)})
            else
                table.insert(r, {w = p.w, h = p.h})
            end
        end
        table.insert(out, r)
    end
    return out
end

local byMask = nil

--- The shape of a bag of this type (drawn cell by cell, else a family's), or nil.
--- `scale`: how many times the rules' cells (see S.scaled); a drawn one is drawn
--- for `drawnScale` (KnoxFootprint.GENEROUS) and is scaled by the difference.
function S.forType(fullType, scale, drawnScale)
    if not byType then
        byType, byMask = {}, {}
        for _, f in ipairs(S.FAMILIES) do
            for _, t in ipairs(f.types) do byType["Base." .. t] = f end
        end
        for i, m in ipairs(S.MASKS) do
            m.name = m.name or ("mask" .. i)
            for _, t in ipairs(m.types) do byMask["Base." .. t] = m end
        end
    end
    scale = scale or 1
    local m = byMask[fullType]
    if m then
        local rel = scale / (drawnScale or 1)
        local key = m.name .. "@" .. string.format("%.2f", rel)
        local s = compiled[key]
        if s == nil then
            s = S.compileMask(S.scaledMask(m.mask, rel)) or false
            if s then s.family = m.name end
            compiled[key] = s
        end
        return s or nil
    end
    local f = byType[fullType]
    if not f then return nil end
    local key = f.name .. "@" .. string.format("%.2f", scale)
    local s = compiled[key]
    if s == nil then
        local rows = S.parse(f.spec)
        s = rows and S.compile(S.scaled(rows, scale)) or false
        if s then s.family = f.name end
        compiled[key] = s
    end
    return s or nil
end

local fromSpec = {}

--- A shape from text (a player's line, a hero's bag written for the menu; a drawn
--- one as "mask:####|.##."), kept.
function S.fromSpec(spec)
    if not spec or spec == "" then return nil end
    local s = fromSpec[spec]
    if s == nil then
        if string.sub(spec, 1, 5) == "mask:" then
            local lines = {}
            for l in string.gmatch(string.sub(spec, 6), "[^|]+") do table.insert(lines, l) end
            s = S.compileMask(lines) or false
        else
            s = S.compile(spec) or false
        end
        fromSpec[spec] = s
    end
    return s or nil
end

return KnoxBagShapes
