-- Order in a grid: Sort by a rule, the player's own layouts, where new things go.
--
--   Sort      repacks a grid by the chosen rule (order.rule):
--               zones   by category, in the player's order of them (order.cats):
--                       each category a block of its own, the same things side by
--                       side, food that spoils sooner first
--               dense   biggest first, tight (what Sort did before 0.9.8)
--               name    by name
--               weight  heaviest first
--             Stacks of a kind that are not full are put together. Locked tiles
--             stay. Within one container it takes no game time.
--   Layout    the player lays a bag out by hand once and saves it (right click on
--             the header). The bag remembers each tile's place by the thing's
--             type: Sort puts things back there, new things go to their places by
--             themselves, and the place of a thing that is missing shows as a
--             pale silhouette (the author: "always"). Kept in the bag's modData
--             (it goes with the bag), the character's for the pockets, a piece
--             of furniture's or a car's for those.
--   New things (order.auto): a thing that comes into a grid without a place of
--             its own (picked up with Shift, Take all, a game action) goes to its
--             place in the layout ("layout"), else next to things of its category
--             ("zones"), or to the first free cell ("off", as before 0.9.8). Other
--             things keep off a layout's empty places while there is other room.

require "Knox/KnoxTheme"
require "Knox/KnoxGrid"

KnoxOrder = KnoxOrder or {}
local O = KnoxOrder
local T = KnoxTheme

O.CATS = {"wpn", "ammo", "med", "food", "tool", "mat", "clo", "info", "misc"}
O.RULES = {"zones", "dense", "name", "weight"}

-- Categories ---------------------------------------------------------------------

--- The player's order of the categories (order.cats: "wpn,ammo,..."); one
--- missing from it (or new in the mod) goes at the end.
function O.catOrder()
    local out, seen = {}, {}
    local saved = T.settings["order.cats"]
    if saved then
        for c in string.gmatch(saved, "[^,]+") do
            if T.category[c] and not seen[c] then
                table.insert(out, c)
                seen[c] = true
            end
        end
    end
    for _, c in ipairs(O.CATS) do
        if not seen[c] then table.insert(out, c) end
    end
    return out
end

function O.setCatOrder(list)
    T.settings["order.cats"] = table.concat(list, ",")
    T.saveSettings()
end

--- Place of a category in the player's order (1 = first).
function O.rank(cat)
    for i, c in ipairs(O.catOrder()) do
        if c == cat then return i end
    end
    return 99
end

function O.rule() return T.choice("order.rule") or "zones" end
function O.auto() return T.choice("order.auto") or "layout" end

-- Layouts ------------------------------------------------------------------------

--- Who keeps a container's layout and under which name: the bag, the
--- character (pockets), the piece of furniture or the car (by the container's
--- type: a fridge has a freezer too). The floor and corpses keep none.
--- @return object|nil holder, string sub
function O.holder(container)
    if not container then return nil end
    local item = container:getContainingItem()
    if item then return item, "main" end
    if container:getType() == "floor" then return nil end
    for n = 0, 3 do
        local p = getSpecificPlayer(n)
        if p and p:getInventory() == container then return p, "pockets" end
    end
    local parent = container:getParent()
    if not parent then return nil end
    if instanceof(parent, "IsoPlayer") then return parent, "pockets" end
    if instanceof(parent, "IsoDeadBody") or instanceof(parent, "IsoZombie") then return nil end
    if instanceof(parent, "BaseVehicle") or instanceof(parent, "IsoObject") then
        return parent, container:getType() or "main"
    end
    return nil
end

--- The saved layout of a container: {cols, e = {{t, x, y, r, w, h, tex}, ...}}, or nil.
--- (in a game with others the pockets' layout is the character's own, kept by the
--- server - KnoxNet; a bag's goes through the server with the bag)
local function netPockets(holder)
    return KnoxNet ~= nil and KnoxNet.mp() and instanceof(holder, "IsoPlayer")
end

function O.layoutOf(container)
    local holder, sub = O.holder(container)
    if not holder or not holder.getModData then return nil end
    if netPockets(holder) then
        local tpl = KnoxNet.pocketsLayout()
        if type(tpl) ~= "table" or type(tpl.e) ~= "table" then return nil end
        return tpl
    end
    local all = holder:getModData().knoxT
    local tpl = type(all) == "table" and all[sub] or nil
    if type(tpl) ~= "table" or type(tpl.e) ~= "table" then return nil end
    return tpl
end

O.stamp = 0   -- bumped when a layout is saved or forgotten (the headers' eyes look again)

local function setLayout(container, tpl)
    local holder, sub = O.holder(container)
    if not holder or not holder.getModData then return false end
    O.stamp = O.stamp + 1
    if netPockets(holder) then
        KnoxNet.setPocketsLayout(tpl)
        return true
    end
    local md = holder:getModData()
    if type(md.knoxT) ~= "table" then md.knoxT = {} end
    md.knoxT[sub] = tpl
    -- (a piece of furniture in a game with others: its data goes to the server;
    -- a bag's through Knox's own way, KnoxNet)
    if isClient() and holder.transmitModData then pcall(function() holder:transmitModData() end) end
    if KnoxNet and instanceof(holder, "InventoryItem") then KnoxNet.itemChanged(holder, "knoxT") end
    return true
end

function O.canKeepLayout(container)
    return O.holder(container) ~= nil
end

--- Save a grid as it lies now as its container's layout.
function O.saveLayout(view)
    local L = view.layout
    local list = {}
    for _, e in ipairs(L.placed) do
        if not e.ghost and not e.reserved and not e.overflow and not (KnoxSearch and KnoxSearch.isHidden(e.item)) then
            local tex = e.item:getTex()
            table.insert(list, {t = e.item:getFullType(), x = e.x, y = e.y, r = e.r or 0, w = e.w, h = e.h,
                                tex = tex and tex:getName() or nil, c = T.categoryOf(e.item)})
        end
    end
    if setLayout(L.container, {cols = L.cols, e = list}) then
        getSoundManager():playUISound("UIActivateButton")
        view:markDirty()
    end
end

function O.forgetLayout(view)
    if setLayout(view.layout.container, nil) then
        getSoundManager():playUISound("UIActivateButton")
        view:markDirty()
    end
end

--- Entries of a layout that fit this grid.
local function entriesIn(L, tpl)
    local out = {}
    if not tpl then return out end
    for _, en in ipairs(tpl.e) do
        if type(en) == "table" and en.t and en.x and en.y and en.w and en.h then
            local w, h = KnoxGrid.dims(en, en.r)
            if en.x >= 0 and en.y >= 0 and en.x + w <= L.cols and en.y + h <= (L.baseRows or L.rows) then
                table.insert(out, en)
            end
        end
    end
    return out
end

--- Is a layout's entry taken by its own thing (one of that type at that place)?
local function filled(L, en)
    local e = L:cellAt(en.x, en.y)
    return e ~= nil and e.x == en.x and e.y == en.y and (e.r or 0) == (en.r or 0)
        and e.item:getFullType() == en.t
end

--- The layout's places that wait for their thing: free cells, the thing not
--- there. Drawn as pale silhouettes (KnoxGridView), kept free by other things.
function O.silhouettes(L)
    local tpl = O.layoutOf(L.container)
    if not tpl then return nil end
    local out = {}
    for _, en in ipairs(entriesIn(L, tpl)) do
        if not filled(L, en) then
            local w, h = KnoxGrid.dims(en, en.r)
            if L:fits(en.x, en.y, w, h) then table.insert(out, en) end
        end
    end
    return out
end

--- Cells of the empty places of a layout: index -> true.
local function avoidOf(L, tpl, fits)
    local avoid = {}
    for _, en in ipairs(entriesIn(L, tpl)) do
        local w, h = KnoxGrid.dims(en, en.r)
        if not filled(L, en) and (not fits or L:fits(en.x, en.y, w, h)) then
            for yy = en.y, en.y + h - 1 do
                for xx = en.x, en.x + w - 1 do avoid[yy * L.cols + xx] = true end
            end
        end
    end
    return avoid
end

-- Finding a place -------------------------------------------------------------------

--- First free place for `e` from row `fromY` down (upright before turned),
--- keeping off the `avoid` cells.
local function findFrom(L, e, fromY, avoid)
    local rows = L.baseRows or L.rows
    for _, r in ipairs({0, 1}) do
        local w, h = KnoxGrid.dims(e, r)
        if r == 0 or w ~= h then
            for y = math.max(0, fromY or 0), rows - h do
                for x = 0, L.cols - w do
                    if L:fits(x, y, w, h) then
                        local clear = true
                        if avoid then
                            for yy = y, y + h - 1 do
                                for xx = x, x + w - 1 do
                                    if avoid[yy * L.cols + xx] then clear = false break end
                                end
                                if not clear then break end
                            end
                        end
                        if clear then return x, y, r end
                    end
                end
            end
        end
    end
    return nil
end

--- Is the block clear of the `avoid` cells (those of `own` don't count)?
local function clearOf(L, x, y, w, h, avoid, own)
    if not avoid then return true end
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do
            local k = yy * L.cols + xx
            if avoid[k] and not (own and own[k]) then return false end
        end
    end
    return true
end

local function cellsOf(L, en)
    local out = {}
    local w, h = KnoxGrid.dims(en, en.r)
    for yy = en.y, en.y + h - 1 do
        for xx = en.x, en.x + w - 1 do out[yy * L.cols + xx] = true end
    end
    return out
end

--- An empty place of the layout kept for a thing of the same category (the
--- bat's place for an axe): x, y, r where `e` fits on it, or nil.
local function emptyOfCat(L, tpl, e, cat, avoid)
    for _, en in ipairs(entriesIn(L, tpl)) do
        if en.c == cat and not filled(L, en) then
            local own = cellsOf(L, en)
            -- (turned as the place is first, then the other way)
            for _, r in ipairs({en.r or 0, 1 - (en.r or 0)}) do
                local w, h = KnoxGrid.dims(e, r)
                if L:fits(en.x, en.y, w, h) and clearOf(L, en.x, en.y, w, h, avoid, own) then return en.x, en.y, r end
            end
        end
    end
    return nil
end

--- The free place nearest to any of `anchors` (tiles or layout entries), or nil.
local function nearOf(L, e, anchors, avoid)
    if #anchors == 0 then return nil end
    local rows = L.baseRows or L.rows
    local best, bx, by, br
    for _, r in ipairs({0, 1}) do
        local w, h = KnoxGrid.dims(e, r)
        if r == 0 or w ~= h then
            for y = 0, rows - h do
                for x = 0, L.cols - w do
                    if L:fits(x, y, w, h) and clearOf(L, x, y, w, h, avoid) then
                        local d
                        for _, a in ipairs(anchors) do
                            local aw, ah = KnoxGrid.dims(a, a.r)
                            local gx = math.max(0, a.x - (x + w), x - (a.x + aw))
                            local gy = math.max(0, a.y - (y + h), y - (a.y + ah))
                            local s = math.max(gx, gy) * 100 + math.abs(x - a.x) + math.abs(y - a.y)
                            if not d or s < d then d = s end
                        end
                        if not best or d < best then best, bx, by, br = d, x, y, r end
                    end
                end
            end
        end
    end
    return bx, by, br
end

--- The free place nearest to the layout's places of the thing's category:
--- things of a kind the bag was laid out with go where that kind was put.
local function nearCat(L, e, tpl, cat, avoid)
    local anchors = {}
    for _, en in ipairs(entriesIn(L, tpl)) do
        if en.c == cat then table.insert(anchors, en) end
    end
    return nearOf(L, e, anchors, avoid)
end

--- The free place nearest to the things of the same type already in the grid
--- (a second chocolate bar goes by the first one, wherever that lies - not to
--- the top row of the food; the author's wish, 2026-10-15).
local function nearSame(L, e, avoid)
    -- (not the floor: a heap of hundreds is laid out as it comes, and this
    -- looks at every free cell for every anchor - see the floor's speed, B6)
    if L.container and L.container:getType() == "floor" then return nil end
    local ft = e.item:getFullType()
    local anchors = {}
    for _, t in ipairs(L.placed) do
        if not t.ghost and not t.overflow and t.item ~= e.item and t.item:getFullType() == ft then
            table.insert(anchors, t)
            if #anchors >= 8 then break end
        end
    end
    return nearOf(L, e, anchors, avoid)
end

--- Where a thing coming into a grid without a place of its own goes.
function O.placeNew(L, e)
    local mode = O.auto()
    -- (no room at all - a full floor's things going to the rows under it,
    -- every build: one look, as before, and no more)
    local fx, fy, fr = L:findFree(e)
    if mode == "off" or not fx then return fx, fy, fr end
    local tpl = O.layoutOf(L.container)
    local ft = e.item:getFullType()
    if tpl and mode == "layout" then
        for _, en in ipairs(entriesIn(L, tpl)) do
            if en.t == ft and en.w == e.w and en.h == e.h then
                local w, h = KnoxGrid.dims(e, en.r)
                if L:fits(en.x, en.y, w, h) then return en.x, en.y, en.r end
            end
        end
    end
    local avoid = tpl and avoidOf(L, tpl, false) or nil
    local cat = T.categoryOf(e.item)
    -- the same thing already lies in the grid: by its side
    do
        local x, y, r = nearSame(L, e, avoid)
        if x then return x, y, r end
    end
    -- no place of its own in the layout: an empty place of its category there,
    -- else as near the places of its category as there is room (the author's
    -- wish, 2026-10-15: an axe goes where the bat was put)
    if tpl and mode == "layout" then
        local x, y, r = emptyOfCat(L, tpl, e, cat, avoid)
        if not x then x, y, r = nearCat(L, e, tpl, cat, avoid) end
        if x then return x, y, r end
    end
    -- next to the things of its category: from the first row they lie in
    -- (the rows are found once per grid build, then kept up to date)
    local tops = L.knoxCatTop
    if not tops then
        tops = {}
        for _, t in ipairs(L.placed) do
            if not t.ghost and not t.overflow then
                local c = T.categoryOf(t.item)
                if not tops[c] or t.y < tops[c] then tops[c] = t.y end
            end
        end
        L.knoxCatTop = tops
    end
    local from = tops[cat]
    local x, y, r
    if from then x, y, r = findFrom(L, e, from, avoid) end
    if not x then x, y, r = findFrom(L, e, 0, avoid) end
    if not x then x, y, r = fx, fy, fr end
    if not tops[cat] or y < tops[cat] then tops[cat] = y end
    return x, y, r
end

KnoxGrid.placer = O.placeNew

-- Sort ---------------------------------------------------------------------------

local function weightOf(e)
    local sum = 0
    for _, it in ipairs(e.items) do sum = sum + KnoxGrid.weightOf(it) end
    return sum
end

--- Hours a food has before it goes stale (things that don't spoil: very many).
local function freshLeft(item)
    if not instanceof(item, "Food") then return 1e9 end
    local off = item:getOffAge() or 0
    if off <= 0 or (item:getOffAgeMax() or 0) >= 1000000000 then return 1e9 end
    return off - (item:getAge() or 0)
end

local function compare(rule)
    return function(a, b)
        if rule == "name" then
            local na, nb = a.item:getDisplayName() or "", b.item:getDisplayName() or ""
            if na ~= nb then return na < nb end
        elseif rule == "weight" then
            local wa, wb = weightOf(a), weightOf(b)
            if math.abs(wa - wb) > 0.001 then return wa > wb end
        end
        if rule == "zones" and a.rank ~= b.rank then return a.rank < b.rank end
        local sa, sb = a.w * a.h, b.w * b.h
        if sa ~= sb then return sa > sb end
        local ta, tb = a.item:getFullType(), b.item:getFullType()
        if ta ~= tb then return ta < tb end
        local fa, fb = freshLeft(a.item), freshLeft(b.item)
        if fa ~= fb then return fa < fb end
        return #a.items > #b.items
    end
end

--- Stacks of a kind that are not full, put together: tiles anew, each at
--- most a full stack, each its own stack id.
local function mergeStacks(tiles)
    local out, byType = {}, {}
    for _, e in ipairs(tiles) do
        if #e.items >= 1 and KnoxGrid.isStackable(e.item) then
            local ft = e.item:getFullType() .. KnoxGrid.stateOf(e.item)   -- (magazines by rounds, print by its title)
            local g = byType[ft]
            if not g then
                g = {first = e, items = {}}
                byType[ft] = g
                table.insert(out, g)
            end
            for _, it in ipairs(e.items) do table.insert(g.items, it) end
        else
            table.insert(out, e)
        end
    end
    local tilesOut = {}
    for _, g in ipairs(out) do
        if g.first then
            local limit = math.max(1, KnoxGrid.stackLimit(g.first.item))
            local i = 1
            while i <= #g.items do
                local part = {}
                for k = i, math.min(#g.items, i + limit - 1) do table.insert(part, g.items[k]) end
                KnoxGrid.setStackId(part, KnoxGrid.newStackId())
                table.insert(tilesOut, {item = part[1], items = part, w = g.first.w, h = g.first.h})
                i = i + limit
            end
        else
            table.insert(tilesOut, g)
        end
    end
    return tilesOut
end

--- Pack `tiles` into `fresh`: the layout's places first, then the rest by the
--- rule. Zones are tried in three ways (`how`), the tidiest first:
---   shelf  each category starts on a row of its own, under the one before (clear blocks)
---   flow   each starts no higher than the row where the one before ended
---          (they share rows, like lines of text)
---   big    the big things in zones first, then the small ones into the holes
---          next to their category (a bag nearly full)
--- Returns the tiles that found no place.
local function pack(fresh, tiles, rule, tpl, how)
    local left = {}
    for _, e in ipairs(tiles) do table.insert(left, e) end
    -- 1. the layout: each entry takes a tile of its type and size
    if tpl then
        for _, en in ipairs(entriesIn(fresh, tpl)) do
            for i, e in ipairs(left) do
                if e.item:getFullType() == en.t and e.w == en.w and e.h == en.h then
                    local w, h = KnoxGrid.dims(e, en.r)
                    if fresh:fits(en.x, en.y, w, h) then
                        fresh:occupy(e, en.x, en.y, en.r)
                        table.remove(left, i)
                    end
                    break
                end
            end
        end
        -- 1b. an empty place of the layout takes a thing of its category
        -- (no bat: the axe lies where the bat was put); 1c. the other things
        -- of a category the layout has go as near its places as there is room
        local catAvoid = avoidOf(fresh, tpl, true)
        table.sort(left, function(a, b) return a.w * a.h > b.w * b.h end)   -- (big ones first: fewer holes)
        local i = 1
        while i <= #left do
            local e = left[i]
            local cat = T.categoryOf(e.item)
            local x, y, r = emptyOfCat(fresh, tpl, e, cat, catAvoid)
            if x then
                fresh:occupy(e, x, y, r)
                table.remove(left, i)
                catAvoid = avoidOf(fresh, tpl, true)
            else
                i = i + 1
            end
        end
        i = 1
        while i <= #left do
            local e = left[i]
            local x, y, r = nearCat(fresh, e, tpl, T.categoryOf(e.item), catAvoid)
            if x then
                fresh:occupy(e, x, y, r)
                table.remove(left, i)
            else
                i = i + 1
            end
        end
    end
    local avoid = tpl and avoidOf(fresh, tpl, true) or nil
    -- 2. the rest by the rule
    for _, e in ipairs(left) do e.rank = O.rank(T.categoryOf(e.item)) end
    table.sort(left, compare(rule))
    local failed = {}
    local tops = {}   -- category rank -> its first row so far
    local strict = how == "shelf"
    local function put(e, from)
        local x, y, r = findFrom(fresh, e, from, avoid)
        if not x and not strict then x, y, r = findFrom(fresh, e, 0, avoid) end
        if not x and not strict then x, y, r = fresh:findFree(e) end
        if not x then
            table.insert(failed, e)
            return nil
        end
        fresh:occupy(e, x, y, r)
        if not tops[e.rank] or y < tops[e.rank] then tops[e.rank] = y end
        local _, h = KnoxGrid.dims(e, r)
        return y, h
    end
    if rule ~= "zones" then
        for _, e in ipairs(left) do put(e, 0) end
        return failed
    end
    local list, rest = left, {}
    if how == "big" then
        list = {}
        for _, e in ipairs(left) do
            if e.w * e.h >= 4 then table.insert(list, e) else table.insert(rest, e) end
        end
    end
    local zoneTop, lastRank, groupTop, groupBottom = 0, nil, 0, 0
    for _, e in ipairs(list) do
        if e.rank ~= lastRank then
            if lastRank then zoneTop = strict and groupBottom or groupTop end
            lastRank = e.rank
            groupTop, groupBottom = zoneTop, zoneTop
        end
        local y, h = put(e, zoneTop)
        if y then
            if y > groupTop then groupTop = y end
            if y + h > groupBottom then groupBottom = y + h end
        elseif strict then
            return failed   -- (blocks don't fit: the next way is tried)
        end
    end
    -- the small things: from their category's first row (or the one before it)
    for _, e in ipairs(rest) do
        local from = tops[e.rank]
        if not from then
            from = 0
            for rank, y in pairs(tops) do
                if rank < e.rank and y > from then from = y end
            end
        end
        put(e, from)
    end
    return failed
end

--- Repack a grid by the rule (and its layout, if it has one).
function O.sort(view, rule)
    if KnoxSearch and KnoxSearch.busy(view.container) then return end   -- not while it is being searched
    rule = rule or O.rule()
    local L = view.layout
    local tiles = {}
    for _, e in ipairs(L.placed) do
        -- (nor while its search waits: things not found yet would be packed too)
        if KnoxSearch and KnoxSearch.isHidden(e.item) then return end
        if not e.ghost and not e.reserved and not KnoxActions.isLocked(e) then table.insert(tiles, e) end
    end
    local function fixed()
        -- a fresh layout holding the moves in progress and the locked tiles
        local f = KnoxGrid.emptyLike(L)
        for _, e in ipairs(L.placed) do
            if e.ghost or e.reserved or KnoxActions.isLocked(e) then f:occupy(e, e.x, e.y, e.r) end
        end
        return f
    end
    local tpl = O.layoutOf(L.container)
    local merged = mergeStacks(tiles)
    local fresh, failed
    for _, how in ipairs(rule == "zones" and {"shelf", "flow", "big"} or {"flow"}) do
        fresh = fixed()
        failed = pack(fresh, merged, rule, tpl, how)
        if #failed == 0 then break end
    end
    if #failed > 0 and (rule ~= "dense" or tpl) then
        -- the rule's order left things out that a tight packing takes in: tight
        fresh = fixed()
        failed = pack(fresh, merged, "dense", nil, "flow")
    end
    for _, e in ipairs(fresh.placed) do
        if not e.ghost and not e.reserved and not KnoxActions.isLocked(e) then
            KnoxGrid.writePlace(e, L.key, e.x, e.y, e.r)
        end
    end
    getSoundManager():playUISound("UIActivateButton")
    view:markDirty()
end

-- The layouts' silhouettes shown or not: the eye by the Sort button --------------
-- (the author's wish, 2026-10-15). One switch for every grid (order.ghosts);
-- the eye closes and opens over a moment, the silhouettes fade with it.

function O.ghostsOn() return T.settings["order.ghosts"] ~= "0" end

function O.toggleGhosts()
    T.settings["order.ghosts"] = O.ghostsOn() and "0" or "1"
    T.saveSettings()
    getSoundManager():playUISound("UIActivateButton")
end

local eyeK, eyeMs = nil, 0
local EYE_MS = 220

--- How open the eye is now, 0..1, moving towards the switch.
function O.ghostK()
    local want = O.ghostsOn() and 1 or 0
    local now = getTimestampMs()
    if eyeK == nil or (T.animOn and not T.animOn()) then eyeK = want end
    local step = math.min(100, now - eyeMs) / EYE_MS
    eyeMs = now
    if eyeK < want then eyeK = math.min(want, eyeK + step) elseif eyeK > want then eyeK = math.max(want, eyeK - step) end
    return eyeK * eyeK * (3 - 2 * eyeK)
end

--- An eye drawn of plain rectangles in square `r`, open `k` (0 closed .. 1
--- open): two lids that part from a line, the pupil showing as they do; shut,
--- three short lashes hang under the line.
function O.drawEye(ui, r, c, k, a)
    a = a or 1
    local s = r[3]
    local u = math.max(2, math.floor(s / 10 + 0.5))           -- stroke
    local cx, cy = r[1] + math.floor(s / 2), r[2] + math.floor(s / 2)
    local half = math.floor(s * 0.36)                          -- half the eye's width
    local open = s * 0.27 * k                                  -- half its height, at the middle
    local function box(x, y, w, h, al) ui:drawRect(x, y, w, h, (al or 1) * a, c.r, c.g, c.b) end
    for dx = -half, half do
        local t = dx / half
        -- (an almond: pointed corners, round in the middle)
        local h = math.floor(open * (1 - t * t) + 0.5)
        box(cx + dx, cy - h - math.floor(u / 2), 1, u)          -- upper lid
        if h > 0 then box(cx + dx, cy + h - math.floor(u / 2), 1, u) end   -- lower lid
    end
    -- the pupil, as much of it as the lids let show
    local p = math.floor(s * 0.15 + 0.5)
    local inside = math.floor(open) - u
    for dy = -p, p do
        if math.abs(dy) <= inside then
            local w = math.floor(math.sqrt(math.max(0, p * p - dy * dy)) + 0.5)
            box(cx - w, cy + dy, w * 2 + 1, 1)
        end
    end
    -- shut: lashes under the line
    if k < 0.5 then
        local la = 1 - k * 2
        local len = math.max(2, math.floor(s * 0.1))
        for _, dx in ipairs({-math.floor(half * 0.6), 0, math.floor(half * 0.6)}) do
            box(cx + dx - math.floor(u / 2), cy + math.floor(u / 2) + 1, u, len, la)
        end
    end
end

-- The menu of a grid's header ------------------------------------------------------

--- Sort, the rule, the layout: added to a context menu for a grid view.
function O.addMenu(menu, view)
    if not view or not view.layout then return end
    menu:addOption(getText("IGUI_Knox_Order_Sort"), view, function(v) O.sort(v) end)
    local rules = menu:addOption(getText("IGUI_Knox_Order_Rule"), nil, nil)
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(rules, sub)
    local cur = O.rule()
    for _, r in ipairs(O.RULES) do
        local name = getText("IGUI_Knox_Choice_order_rule_" .. r)
        if r == cur then name = getText("IGUI_Knox_Order_Current", name) end
        local o = sub:addOption(name, r, function(rr)
            T.settings["order.rule"] = rr
            T.saveSettings()
            O.sort(view, rr)
        end)
        o.knoxIconKey = "rule_" .. r   -- (menu_rule_zones / dense / name / weight)
    end
    local c = view.layout.container
    if O.canKeepLayout(c) then
        menu:addOption(getText("IGUI_Knox_Order_SaveLayout"), view, function(v) O.saveLayout(v) end)
        if O.layoutOf(c) then
            menu:addOption(getText("IGUI_Knox_Order_ForgetLayout"), view, function(v) O.forgetLayout(v) end)
        end
    end
end

return O
