-- The item editor's data (KnoxEditor; the author, 2026-10-25): every item the game
-- knows, by the editor's tabs; an item's values as Knox has them and as a preset
-- makes them (its "record"); the line a preset keeps for it - only what differs.
--   record: {kind = "bag" | "clo" | "item", w, h, stackOn, stack,
--            bag = {mode = "parts" | "grid" | "mask", spec, grid = {c, r}, mask, cap},
--            pockets, all, loc, tile, snd}
--   spec: rows of compartments, {{{w, h}, ...}, ...} (KnoxBagShapes.parse's way)
--   mask: rows of 0 / 1, mask[y][x]

require "Knox/KnoxPresets"

KnoxEditorData = KnoxEditorData or {}
local D = KnoxEditorData
local F, P = KnoxFootprint, KnoxPresets

-- the counts a stack steps through
D.NICE = {2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200, 250, 500, 1000}
-- Knox's categories, in the dropdown's order
D.KCATS = {"wpn", "ammo", "med", "food", "tool", "mat", "clo", "info", "misc"}
-- what a thing may sound like (KnoxMaterial.LIST), in the dropdown's order
D.SOUNDS = {"softpaper", "paper", "magazine", "book", "cardboard", "cloth", "leather", "shoes", "tin", "metalsmall",
            "metal", "jewelry", "keys", "glass", "ceramic", "plastic", "plasticsoft", "pills", "ammo", "wood", "stone",
            "food", "fooddry", "misc"}
D.MAX_W, D.MAX_H = 4, 8          -- an item's short and long side at most
D.MAX_POCKETS = 16
D.MAX_ROW = 8                    -- a bag's row of cells (the inventory column)
D.MAX_ROWS = 15                  -- a bag's grid (KnoxGrid.MAX_H)

-- The items ---------------------------------------------------------------------------

local all = nil   -- every item, made once a game

local function safe(fn, ...)
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil
end

--- A mod's name by its ID (as the game's mod list shows it).
local modNames = {}
function D.modName(id)
    if not id then return nil end
    local n = modNames[id]
    if n == nil then
        n = safe(function() return getModInfoByID(id):getName() end) or id
        modNames[id] = n
    end
    return n
end

--- Every item a player could hold, sorted by name: {ft, sc, name, low, side, mod, grp, tex}.
function D.items()
    if all then return all end
    all = {}
    local sm = ScriptManager and ScriptManager.instance
    local list = sm and sm:getAllItems()
    if not list then return all end
    for i = 0, list:size() - 1 do
        local sc = list:get(i)
        local hidden = safe(function() return sc:isHidden() or sc:getObsolete() end)
        local ft = safe(function() return sc:getFullName() end)
        if ft and not hidden then
            local name = safe(function() return sc:getDisplayName() end) or ft
            local e = {ft = ft, sc = sc, name = name, low = string.lower(name),
                       side = P.sideOf(sc), mod = P.modOf(sc)}
            if KnoxTheme then e.low = KnoxTheme.lower(name) end
            e.lowId = string.lower(ft)
            -- (groups in the bags' and the clothes' lists)
            if e.mod and (e.side == "bag" or e.side == "clo") then
                e.grp = "Grp_mods"
            elseif e.side == "bag" then
                local eq = safe(function() return sc:getCanBeEquipped() end)
                eq = eq and F.norm(eq) or ""
                e.grp = eq == "back" and "Grp_back" or (eq ~= "" and "Grp_worn" or "Grp_case")
            elseif e.side == "clo" then
                local loc = safe(function() return sc:getBodyLocation() end)
                e.loc = loc and F.norm(loc) or ""
                e.grp = (KnoxGrid.POCKETS[e.loc] or 0) > 0 and "Grp_pockets" or "Grp_nopockets"
            end
            table.insert(all, e)
        end
    end
    local GRP = {Grp_back = 1, Grp_worn = 2, Grp_case = 3, Grp_pockets = 1, Grp_nopockets = 2, Grp_mods = 9}
    table.sort(all, function(a, b)
        local ga, gb = GRP[a.grp or ""] or 0, GRP[b.grp or ""] or 0
        if ga ~= gb then return ga < gb end
        if a.low ~= b.low then return a.low < b.low end
        return a.ft < b.ft
    end)
    -- (how many are worn at each place: "for everything worn as Jacket (38)")
    D.perLoc = {}
    for _, e in ipairs(all) do
        if e.loc and e.loc ~= "" then D.perLoc[e.loc] = (D.perLoc[e.loc] or 0) + 1 end
    end
    return all
end

function D.byType(ft)
    D.items()
    if not D.index then
        D.index = {}
        for _, e in ipairs(all) do D.index[e.ft] = e end
    end
    return D.index[ft]
end

--- The item's picture (its script's).
function D.texture(e)
    if e.tex == nil then e.tex = safe(function() return e.sc:getNormalTexture() end) or false end
    return e.tex or nil
end

-- (a thing of each type, made once and never put in the world - as KnoxMeasure does)
local things, thingsN = {}, 0
function D.thing(ft)
    local t = things[ft]
    if t == nil then
        if thingsN > 300 then things, thingsN = {}, 0 end
        t = (instanceItem and safe(instanceItem, ft)) or false
        things[ft] = t
        thingsN = thingsN + 1
    end
    return t or nil
end

-- Records -------------------------------------------------------------------------------

local function specCopy(spec)
    local out = {}
    for ri, row in ipairs(spec) do
        out[ri] = {}
        for ci, p in ipairs(row) do out[ri][ci] = {w = p.w, h = p.h} end
    end
    return out
end
D.specCopy = specCopy

local function maskFromLines(lines, on)
    local m = {}
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, #l) end
    for y, l in ipairs(lines) do
        m[y] = {}
        for x = 1, w do m[y][x] = string.sub(l, x, x) == on and 1 or 0 end
    end
    return m
end
D.maskFromLines = maskFromLines

--- An item's values with the lines in effect now (call it in KnoxFootprint.withOverrides).
function D.recordOf(item)
    local ft = item:getFullType()
    local o = F.overrides[ft]
    local r = {}
    r.w, r.h = F.getBase(item)
    if instanceof(item, "InventoryContainer") then
        r.kind = "bag"
        local inv = item:getInventory()
        local cap = inv and inv:getCapacity() or 0
        local gc, gr = F.bagGrid(item, cap, 1)
        local fam = KnoxBagShapes.forType(ft, 1, F.GENEROUS)
        local b = {grid = {gc, math.min(gr, D.MAX_ROWS)}, cap = F.bagCells(cap)}
        if o and o.mask then
            b.mode = "mask"
            local lines = {}
            for l in string.gmatch(o.mask, "[^|]+") do table.insert(lines, l) end
            b.mask = maskFromLines(lines, "x")
        elseif o and o.parts then
            b.mode = "parts"
        elseif o and o.cols then
            b.mode = "grid"
        elseif fam then
            b.mode = fam.free and "mask" or "parts"
            if fam.free then b.mask = maskFromLines(fam.maskLines, "#") end
        else
            b.mode = "grid"
        end
        local rows = (o and o.parts and KnoxBagShapes.parse(o.parts)) or (fam and not fam.free and fam.rowsSpec)
        b.spec = rows and specCopy(rows) or {{{w = gc, h = math.min(gr, D.MAX_ROWS)}}}
        r.bag = b
    else
        r.kind = instanceof(item, "Clothing") and "clo" or "item"
        r.stackOn = KnoxGrid.isStackable(item)
        if r.stackOn then
            r.stack = F.stack(item)
        else
            r.stack = (o and o.stack and o.stack > 1 and o.stack) or (r.kind == "clo" and 2 or 4)
        end
    end
    if r.kind == "clo" then
        r.loc = F.norm(item:getBodyLocation())
        r.pockets = KnoxGrid.pocketsOf(item, r.loc) or 0
        r.all = (o and o.pocketsAll) == true
    end
    r.tile = KnoxTheme.categoryOf(item)
    r.snd = KnoxMaterial and KnoxMaterial.of(item) or "misc"
    return r
end

function D.copy(r)
    local o = {}
    for k, v in pairs(r) do o[k] = v end
    if r.bag then
        local b = {}
        for k, v in pairs(r.bag) do b[k] = v end
        b.grid = {r.bag.grid[1], r.bag.grid[2]}
        b.spec = specCopy(r.bag.spec)
        if r.bag.mask then
            b.mask = {}
            for y, row in ipairs(r.bag.mask) do
                b.mask[y] = {}
                for x, v in ipairs(row) do b.mask[y][x] = v end
            end
        end
        o.bag = b
    end
    return o
end

--- A bag's spec as text ("4x2 / 1x2 5x6 1x2").
function D.specText(spec)
    return KnoxBagShapes.text(spec)
end

--- A mask as the line writes it: the box of its cells, x a cell, . none, "|" between rows.
function D.maskText(m)
    if not m then return "" end
    local y0, y1, x0, x1 = nil, nil, nil, nil
    for y, row in ipairs(m) do
        for x, v in ipairs(row) do
            if v == 1 then
                y0, y1 = y0 or y, y
                x0 = x0 and math.min(x0, x) or x
                x1 = x1 and math.max(x1, x) or x
            end
        end
    end
    if not y0 then return "" end
    local out = {}
    for y = y0, y1 do
        local t = {}
        for x = x0, x1 do t[#t + 1] = m[y][x] == 1 and "x" or "." end
        out[#out + 1] = table.concat(t)
    end
    return table.concat(out, "|")
end

function D.maskCells(m)
    local n = 0
    for _, row in ipairs(m or {}) do
        for _, v in ipairs(row) do n = n + v end
    end
    return n
end

function D.specCells(spec)
    local n = 0
    for _, row in ipairs(spec) do
        for _, p in ipairs(row) do n = n + p.w * p.h end
    end
    return n
end

--- Cells of a row of compartments with the one-cell gaps between them.
function D.rowCells(row)
    local n = 0
    for _, p in ipairs(row) do n = n + p.w end
    return n + math.max(0, #row - 1)
end

function D.rowHeight(row)
    local h = 0
    for _, p in ipairs(row) do h = math.max(h, p.h) end
    return h
end

--- How tall a spec stands (its rows and the gaps between them).
function D.specRows(spec)
    local n = 0
    for _, row in ipairs(spec) do n = n + D.rowHeight(row) end
    return n + math.max(0, #spec - 1)
end

function D.bagCellsOf(b)
    if b.mode == "grid" then return b.grid[1] * b.grid[2] end
    if b.mode == "mask" then return D.maskCells(b.mask) end
    return D.specCells(b.spec)
end

--- Compartments -> cells (a cell of nothing between them), for "cell by cell": as
--- wide as the inventory column at least, a spare row under it.
function D.specToMask(spec)
    local lw = 0
    for _, row in ipairs(spec) do lw = math.max(lw, D.rowCells(row)) end
    local rows = {}
    for ri, row in ipairs(spec) do
        local rh, rw = D.rowHeight(row), D.rowCells(row)
        local block = {}
        for y = 1, rh do
            block[y] = {}
            for x = 1, lw do block[y][x] = 0 end
        end
        local x = math.floor((lw - rw) / 2)
        for _, p in ipairs(row) do
            local y0 = math.floor((rh - p.h) / 2)
            for yy = 1, p.h do
                for xx = 1, p.w do block[y0 + yy][x + xx] = 1 end
            end
            x = x + p.w + 1
        end
        if ri > 1 then
            local gap = {}
            for i = 1, lw do gap[i] = 0 end
            rows[#rows + 1] = gap
        end
        for _, b in ipairs(block) do rows[#rows + 1] = b end
    end
    local W = math.max(D.MAX_ROW, lw)
    local off = math.floor((W - lw) / 2)
    local m = {}
    for y, r in ipairs(rows) do
        m[y] = {}
        for x = 1, W do m[y][x] = r[x - off] or 0 end
    end
    if #m < D.MAX_ROWS then
        local spare = {}
        for x = 1, W do spare[x] = 0 end
        m[#m + 1] = spare
    end
    return m
end

--- A mask's canvas: as wide as the column, a spare row under its cells (edited in place).
function D.maskCanvas(m)
    local W = D.MAX_ROW
    for _, row in ipairs(m) do W = math.max(W, #row) end
    for _, row in ipairs(m) do
        for x = #row + 1, W do row[x] = 0 end
    end
    local last = m[#m]
    local empty = true
    for _, v in ipairs(last or {}) do if v == 1 then empty = false end end
    if not empty and #m < D.MAX_ROWS then
        local spare = {}
        for x = 1, W do spare[x] = 0 end
        m[#m + 1] = spare
    end
    return m
end

--- Groups of mask cells touching by a side: id[y][x] -> group, and how many groups.
function D.maskGroups(m)
    local H = #m
    local W = H > 0 and #m[1] or 0
    local id, n = {}, 0
    for y = 1, H do
        id[y] = {}
        for x = 1, W do id[y][x] = 0 end
    end
    for y = 1, H do
        for x = 1, W do
            if m[y][x] == 1 and id[y][x] == 0 then
                n = n + 1
                id[y][x] = n
                local stack = {{x, y}}
                while #stack > 0 do
                    local c = table.remove(stack)
                    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
                        local px, py = c[1] + d[1], c[2] + d[2]
                        if px >= 1 and py >= 1 and px <= W and py <= H and m[py][px] == 1 and id[py][px] == 0 then
                            id[py][px] = n
                            stack[#stack + 1] = {px, py}
                        end
                    end
                end
            end
        end
    end
    return id, n
end

--- A bag's shape as a key: two shapes the same are the same key.
function D.bagKey(b)
    if not b then return "" end
    if b.mode == "grid" then return "g" .. b.grid[1] .. "x" .. b.grid[2] end
    if b.mode == "mask" then return "m" .. D.maskText(b.mask) end
    return "p" .. D.specText(b.spec)
end

--- The line a preset keeps for an item: what `r` has that `d` (as Knox has it) has
--- not; nil when nothing differs.
function D.lineOf(r, d)
    local o, any = {}, false
    if math.min(r.w, r.h) ~= math.min(d.w, d.h) or math.max(r.w, r.h) ~= math.max(d.w, d.h) then
        o.w, o.h = math.min(r.w, r.h), math.max(r.w, r.h)
        any = true
    end
    if r.bag and D.bagKey(r.bag) ~= D.bagKey(d.bag) then
        local b = r.bag
        if b.mode == "grid" then o.cols, o.rows = b.grid[1], b.grid[2]
        elseif b.mode == "mask" then o.mask = D.maskText(b.mask)
        else o.parts = D.specText(b.spec) end
        any = true
    end
    if r.stackOn ~= nil and (r.stackOn ~= d.stackOn or (r.stackOn and r.stack ~= d.stack)) then
        o.stack = r.stackOn and r.stack or 1
        any = true
    end
    if r.pockets ~= nil and (r.pockets ~= d.pockets or r.all ~= d.all) then
        o.pockets, o.pocketsAll = r.pockets, r.all or nil
        any = true
    end
    if r.tile ~= d.tile then o.cat, any = r.tile, true end
    if r.snd ~= d.snd then o.sound, any = r.snd, true end
    if not any then return nil end
    return o
end

-- Presets in the editor ------------------------------------------------------------------
-- The editor works on a store (KnoxPresets): this computer's, or the server's for its
-- admin. The mod's defaults are a preset of their own there for the author (dev mode):
-- {defaults = true, items = KnoxFootprint.baseOverrides' copy} - as Knox has it for
-- them is the rules alone.

local EMPTY = {}

--- The lines an item is worked out with as Knox has it, for the preset `p`.
local function baseFor(p)
    if p and p.defaults then return EMPTY end
    return F.baseOverrides
end

local recs = setmetatable({}, {__mode = "k"})   -- preset -> ft -> record
local defs = {}                                 -- "b" / "d" -> ft -> record

function D.forget(p, ft)
    if p and recs[p] then
        if ft then recs[p][ft] = nil else recs[p] = nil end
    end
end

function D.forgetAll()
    recs = setmetatable({}, {__mode = "k"})
    defs = {}
end

--- An item as Knox has it (for the preset p: the mod's defaults are Knox's, unless p is them).
function D.defaultOf(p, ft)
    local key = (p and p.defaults) and "d" or "b"
    defs[key] = defs[key] or {}
    local r = defs[key][ft]
    if r == nil then
        local item = D.thing(ft)
        r = item and F.withOverrides(baseFor(p), D.recordOf, item) or false
        defs[key][ft] = r
    end
    return r or nil
end

--- An item as the preset p gives it.
function D.recordIn(p, ft)
    recs[p] = recs[p] or {}
    local r = recs[p][ft]
    if r == nil then
        local line = p.items[ft]
        if not line then
            local d = D.defaultOf(p, ft)
            r = d and D.copy(d) or false
        else
            local item = D.thing(ft)
            local base = baseFor(p)
            r = item and F.withOverrides({[ft] = p.defaults and line or P.over(base[ft], line)}, D.recordOf, item) or false
        end
        recs[p][ft] = r
    end
    return r or nil
end

--- The preset p's item changed to the record r: its line made anew (none when as Knox has it).
function D.setRecord(p, ft, r)
    recs[p] = recs[p] or {}
    recs[p][ft] = r
    local d = D.defaultOf(p, ft)
    local had = p.items[ft] ~= nil
    p.items[ft] = d and D.lineOf(r, d) or nil
    if had and not p.items[ft] then p.n = (p.n or 1) - 1 end
    if not had and p.items[ft] then p.n = (p.n or 0) + 1 end
end

--- How many items a preset changes.
function D.count(p)
    local n = 0
    for _ in pairs(p.items) do n = n + 1 end
    p.n = n
    return n
end

-- Import ---------------------------------------------------------------------------------

--- Lines read for an import: the preset, and each line with what it is about or
--- what is wrong ({text, ok, note}).
function D.readImport(lines)
    local p = P.parse(lines)
    local rows, ok, bad = {}, 0, 0
    local sm = ScriptManager and ScriptManager.instance
    local items = {}
    for _, line in ipairs(lines) do
        if string.find(line, "^%s*$") then
            -- (blank lines are left out)
        elseif string.find(line, "^%s*#") then
            table.insert(rows, {text = line})
        else
            local key, o = F.parseLine(line)
            local row = {text = line}
            if not key or key == "show_ids" then
                row.err = "Err_bad"
            else
                local sc = sm and sm:getItem(key)
                if not sc then
                    row.err = "Err_id"
                elseif not P.holds(p.scope, sc) then
                    row.err = "Err_scope"
                else
                    row.ok = true
                    local e = D.byType(key)
                    row.note = e and e.name or key
                    items[key] = P.over(items[key], o)
                end
            end
            if row.ok then ok = ok + 1 elseif row.err then bad = bad + 1 end
            table.insert(rows, row)
        end
    end
    p.items = items
    D.count(p)
    return {preset = p, rows = rows, ok = ok, bad = bad, lines = ok + bad}
end

--- A text from the clipboard as lines.
function D.splitLines(s)
    local out = {}
    for l in string.gmatch((s or "") .. "\n", "([^\r\n]*)\r?\n") do table.insert(out, l) end
    return out
end

return KnoxEditorData
