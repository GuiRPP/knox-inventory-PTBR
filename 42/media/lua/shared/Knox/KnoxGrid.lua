-- Grid data model: container grid sizes, stacks, where each item sits, and
-- moves in progress.
--
-- An item's place is saved in its modData:
--   knox  = {k = containerKey, x, y, r}   current place (r = 1 when rotated)
--   knoxP = {k = containerKey, x, y, r}   wanted place in a container the
--                                         item is being moved into
-- When a grid is built, an item whose saved key doesn't match the container
-- it is in now gets the first free spot.

require "Knox/KnoxFootprint"
require "Knox/KnoxNet"

KnoxGrid = KnoxGrid or {}

-- (in a game with others the places and stacks also go to the server: KnoxNet)
local function told(item, key, auto)
    if KnoxNet and KnoxNet.itemChanged then KnoxNet.itemChanged(item, key, auto) end
end

KnoxGrid.MAX_H = 15          -- rows of a bag's grid and of the floor's at most
KnoxGrid.WORLD_MAX_H = 40    -- of a piece of furniture's or a car boot's (its grid scrolls)
KnoxGrid.worldCols = 8       -- columns of the widest such grid: what the surroundings column shows (set by it, 8 to 12)

-- Pockets: the character's own grid is what the clothes worn right now have
-- pockets for, plus what bare hands and a waistband hold. By body location
-- (KnoxFootprint.norm); a location not named here has none.
KnoxGrid.POCKETS_COLS = 4
KnoxGrid.HANDS = 4
KnoxGrid.POCKETS = {
    pants = 4, pantsskinny = 4, pantsextra = 4,
    shortpants = 2, shortsshort = 2, skirt = 2, longskirt = 2, dress = 2, longdress = 2,
    jacket = 4, jacketsuit = 4, bathrobe = 4, jacketbulky = 6, jackethatbulky = 6,
    jackethat = 2, jacketdown = 2,
    torsoextravest = 4, torsoextravestbullet = 2, torsoextra = 2, sweaterhat = 2,
    boilersuit = 6, fullsuithead = 2, fulltop = 2,
}

--- Cells of a source of pockets as the player's setting makes them (KnoxFootprint.gridScale).
local function scaled(n)
    return math.max(1, math.floor(n * KnoxFootprint.gridScale() + 0.5))
end

--- Body location -> cells, from the lines that give every item worn there its
--- pockets ("pockets.all N", the item editor): made when first asked after the
--- lines change (KnoxFootprint.useOverrides empties it).
local function pocketsByLoc()
    local F = KnoxFootprint
    if F.pocketsLoc then return F.pocketsLoc end
    local t = {}
    local sm = ScriptManager and ScriptManager.instance
    for ft, o in pairs(F.overrides or {}) do
        if o.pocketsAll and sm then
            local sc = sm:getItem(ft)
            local loc = sc and sc:getBodyLocation()
            if loc then t[F.norm(loc)] = o.pockets end
        end
    end
    F.pocketsLoc = t
    return t
end

--- Cells of pockets an item worn at `loc` (KnoxFootprint.norm) gives, unscaled:
--- its own line ("pockets N"), its location's ("pockets.all N"), Knox's own; nil: none.
-- (the item editor, the author 2026-10-25: pockets set per item)
function KnoxGrid.pocketsOf(item, loc)
    local o = item and KnoxFootprint.overrides[item:getFullType()]
    local n = o and o.pockets
    if n == nil then n = pocketsByLoc()[loc] end
    if n == nil then n = KnoxGrid.POCKETS[loc] end
    if n and n > 0 then return n end
    return nil
end

--- Where the pockets come from: {{name, cells}, ...} (hands first), and their sum.
function KnoxGrid.pockets(player)
    local hands = scaled(KnoxGrid.HANDS)
    local list = {{getText("IGUI_Knox_PocketsHands"), hands}}
    local total = hands
    local worn = player:getWornItems()
    if worn then
        for i = 0, worn:size() - 1 do
            local w = worn:get(i)
            local item = w:getItem()
            local n = KnoxGrid.pocketsOf(item, KnoxFootprint.norm(w:getLocation()))
            if n and item then
                n = scaled(n)
                table.insert(list, {item:getDisplayName(), n})
                total = total + n
            end
        end
    end
    return list, total
end

--- How many cells the character's own grid has now.
function KnoxGrid.pocketCells(player)
    local total = scaled(KnoxGrid.HANDS)
    local worn = player:getWornItems()
    if worn then
        for i = 0, worn:size() - 1 do
            local w = worn:get(i)
            local n = KnoxGrid.pocketsOf(w:getItem(), KnoxFootprint.norm(w:getLocation()))
            if n then total = total + scaled(n) end
        end
    end
    return total
end

--- Stable id of a container, used to tell whether a saved place belongs to it.
function KnoxGrid.containerKey(container, player)
    if player and container == player:getInventory() then return "p" end
    local item = container:getContainingItem()
    if item then return "i" .. tostring(item:getID()) end
    local t = container:getType() or "?"
    local parent = container:getParent()
    -- a vehicle's trunk, glove box, seats: by the vehicle, which moves
    -- (by its square the places were lost after every drive)
    if parent and instanceof(parent, "BaseVehicle") and parent.getSqlId then
        -- (in a game with others the client is not told the car's sqlId - all cars
        -- had one key there: its mechanical id, which comes with the car and is kept)
        if KnoxNet and KnoxNet.mp() and parent.getMechanicalID then
            return "m" .. tostring(parent:getMechanicalID()) .. "," .. t
        end
        return "v" .. tostring(parent:getSqlId()) .. "," .. t
    end
    local sq = parent and parent.getSquare and parent:getSquare()
    if sq then
        return "w" .. sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() .. "," .. t
    end
    return "t" .. t
end

--- How many times the rules' cells a bag gets: the player's setting
--- (KnoxFootprint.gridScale) and the character's Organized / Disorganized, as
--- the game gives them more or less of a container's capacity (Sharp, 2026-10-18:
--- "Organized only adds weight" - with the weight limit of bags gone it adds cells).
function KnoxGrid.bagScale(container, player)
    local s = KnoxFootprint.gridScale()
    if player then
        local cap = container:getCapacity() or 0
        if cap > 0 then
            local ok, eff = pcall(function() return container:getEffectiveCapacity(player) end)
            if ok and eff and eff ~= cap then s = s * eff / cap end
        end
    end
    return s
end

--- A bag's compartments (KnoxBagShapes), or nil for one grid: its family's shape,
--- or the player's own line in knox_overrides.txt ("parts ..." gives one, "mask ..."
--- one drawn cell by cell, "grid CxR" takes it away).
function KnoxGrid.shapeOf(container, player)
    if not KnoxBagShapes or (player and container == player:getInventory()) then return nil end
    local item = container:getContainingItem()
    if not item then return nil end
    local ft = item:getFullType()
    local o = KnoxFootprint.overrides and KnoxFootprint.overrides[ft]
    local shape
    if o and o.mask then
        -- (written with x for a cell: "#" starts a note in the file)
        shape = KnoxBagShapes.fromSpec("mask:" .. string.gsub(o.mask, "x", "#"))
    elseif o and o.parts then
        shape = KnoxBagShapes.fromSpec(o.parts)
    elseif o and o.cols then
        return nil
    else
        shape = KnoxBagShapes.forType(ft, KnoxGrid.bagScale(container, player), KnoxFootprint.GENEROUS)
    end
    -- (taller than a bag's grid may be: one grid after all)
    if shape and shape.rows > KnoxGrid.MAX_H then return nil end
    return shape
end

--- Size of a container's grid. `limit` is set when its last row is not whole:
--- only the first `limit` cells (row by row) are cells of the grid.
--- @return number cols, number rows, number|nil limit
function KnoxGrid.getSize(container, player)
    local shape = KnoxGrid.shapeOf(container, player)
    if shape then return shape.cols, shape.rows end
    if player and container == player:getInventory() then
        local cells = KnoxGrid.pocketCells(player)
        local cols = KnoxGrid.POCKETS_COLS
        local rows = math.ceil(cells / cols)
        return cols, rows, (cells < cols * rows) and cells or nil
    end
    local item = container:getContainingItem()
    if item then
        -- a bag: cells by its capacity, shape by its kind (see KnoxFootprint)
        local cols, rows = KnoxFootprint.bagGrid(item, container:getCapacity() or 0, KnoxGrid.bagScale(container, player))
        return cols, math.min(KnoxGrid.MAX_H, rows)
    end
    local parent = container:getParent()
    if parent and instanceof(parent, "IsoDeadBody") then return 6, 8 end
    if container:getType() == "floor" then return 8, KnoxGrid.MAX_H end
    -- Furniture, car boots, seats: three cells per unit of capacity, half as
    -- many again as a bag has. A bag is short of room; a cupboard or a boot is
    -- not - there the game's weight limit decides, and what the game itself
    -- put in must fit. Big ones get a wider grid.
    local cap = container:getCapacity() or 0
    local cells = math.max(6, math.floor(cap * KnoxFootprint.CELLS_PER_CAPACITY_WORLD + 0.5))
    local cols = 6
    if cells > 72 then cols = KnoxGrid.worldCols elseif cells > 24 then cols = 8 end
    local rows = math.min(KnoxGrid.WORLD_MAX_H, math.max(2, math.ceil(cells / cols)))
    return cols, rows
end

-- What things of a type are, as isStackable sees it - the same for all of them: a
-- thing's class and tags come from its type's script. (Asked anew for each thing,
-- some ten looks at Java each: 500 bullets in a bag, its build up to 9 ms four times
-- a second - the author's bench 2026-10-28.)
local kindOf = {}   -- full type -> "smoke" | "asked" (food players asked to stack) | "never" | "plain"
-- (and whether a plain thing's type wears down: the game sets a thing's own maximum
-- only where its type has one - a car's parts, furniture. Asked of each of 500 bullets
-- every build and every count of their bag's cells: up to 5.3 ms a count, the author's
-- detailed bench 2026-10-29. A fluid in it stays asked of each thing.)
local wearsOf = {}   -- full type -> true | false

local function kindOfType(item, ft)
    local k
    -- cigarettes and cigars are food that never spoils: they stack (not poisoned ones)
    if KnoxFootprint.isSmoke(item) then
        k = "smoke"
    -- the small things players asked to stack (2026-10-19; only feathers, seeds and
    -- grass, the author - magazines, hay, crackers and cans taken back) - and only as
    -- long as each is like the others (not spoiled...)
    elseif instanceof(item, "Food") then
        k = KnoxGrid.askedToStack(item) and "asked" or "never"
    elseif instanceof(item, "HandWeapon") or instanceof(item, "Clothing")
        or instanceof(item, "InventoryContainer") or instanceof(item, "Literature")
        or instanceof(item, "Moveable") or instanceof(item, "Radio") then
        k = "never"
    else
        k = "plain"
    end
    kindOf[ft] = k
    if k == "plain" then wearsOf[ft] = item:getConditionMax() > 0 end
    return k
end

--- Items of one type that share a single tile (ammo, nails, pills...; also
--- things used up bit by bit - batteries, tape, thread). How many: stackLimit.
--- (`ft`: its full type, when the caller has it - one look at Java less)
function KnoxGrid.isStackable(item, ft)
    -- the player's own line: "stack 1" never, "stack N" any alike ones (the item editor,
    -- the author 2026-10-25: whether a thing stacks and how many)
    ft = ft or item:getFullType()
    local o = KnoxFootprint.overrides[ft]
    if o and o.stack then
        if o.stack <= 1 then return false end
        return KnoxGrid.isAlike(item)
    end
    local k = kindOf[ft] or kindOfType(item, ft)
    if k == "smoke" then return (item:getPoisonPower() or 0) <= 0 end
    if k == "asked" then return KnoxGrid.isPlainFood(item) end
    if k == "never" then return false end
    if item:getFluidContainer() then return false end
    if wearsOf[ft] and item:getCondition() < item:getConditionMax() then
        return false
    end
    return true
end

--- Can this thing share a tile with others of its type, whatever its kind: nothing
--- in it, whole, clean, the same in every piece. (What a "stack N" line asks of a
--- kind Knox never stacks - a pistol, a shirt, a can of food.) A bag never does.
function KnoxGrid.isAlike(item)
    if instanceof(item, "InventoryContainer") or instanceof(item, "Moveable") then return false end
    local fc = item:getFluidContainer()
    if fc and not fc:isEmpty() then return false end
    if item:getConditionMax() > 0 and item:getCondition() < item:getConditionMax() then return false end
    if instanceof(item, "Food") then return KnoxGrid.isPlainFood(item) end
    if instanceof(item, "Clothing") then
        local ok, clean = pcall(function()
            return (item:getDirtyness() or 0) <= 0 and (item:getBloodlevel() or 0) <= 0 and (item:getWetness() or 0) <= 0
                and (item:getHolesNumber() or 0) == 0
        end)
        return ok and clean == true
    end
    if instanceof(item, "HandWeapon") then
        -- (a gun with a round in it or a part on it is not like the others)
        local ok, plain = pcall(function()
            return (item:getCurrentAmmoCount() or 0) == 0 and not item:isRoundChambered() and item:getAllWeaponParts():size() == 0
        end)
        return ok and plain == true
    end
    return true
end

-- Food players asked to stack, by type (and seeds and feathers by their tags)
local ASKED = {["Base.GrassTuft"] = true}

function KnoxGrid.askedToStack(item)
    local ft = item:getFullType()
    if ASKED[ft] then return true end
    if ItemTag and item.hasTag then
        local ok, yes = pcall(function()
            return (ItemTag.FEATHER ~= nil and item:hasTag(ItemTag.FEATHER)) or (ItemTag.IS_SEED ~= nil and item:hasTag(ItemTag.IS_SEED))
        end)
        if ok and yes then return true end
    end
    -- (tags not known by these names: by the type's name)
    return string.find(ft, "Feather$") ~= nil or string.find(ft, "Seeds?$") ~= nil
end

--- Food that is the same in every piece: it never spoils, isn't cooked, eaten
--- into, poisoned or frozen (a seed, a feather, a tuft of hay, a closed can).
function KnoxGrid.isPlainFood(item)
    local ok, plain = pcall(function()
        if item:getFluidContainer() then return false end
        if (item:getOffAgeMax() or 0) < 1000000000 then return false end
        if item:isCookable() or item:isCooked() or item:isBurnt() or item:isRotten() then return false end
        if (item:getPoisonPower() or 0) > 0 or item:isTainted() or item:isFrozen() then return false end
        if math.abs((item:getHungChange() or 0) - (item:getBaseHunger() or 0)) > 0.0001 then return false end
        return true
    end)
    return ok and plain == true
end

local named = {}   -- full type -> its things told apart by their names too: print, food (by its class, as kindOf)
local loads = {}   -- full type -> it holds rounds (a magazine, a gun: its type's maximum)

local function stateFor(item, ft)
    local ld = loads[ft]
    if ld == nil then
        ld = (item:getMaxAmmo() or 0) > 0
        loads[ft] = ld
    end
    local s = ld and KnoxGrid.rounds(item) or ""
    local nm = named[ft]
    if nm == nil then
        nm = instanceof(item, "Literature") or instanceof(item, "Food")
        named[ft] = nm
    end
    if nm then
        s = s .. "|" .. tostring(item:getDisplayName())
        if item:hasModData() then
            local md = item:getModData()
            if md.literatureTitle then s = s .. "|" .. tostring(md.literatureTitle) end
            if md.printMedia then s = s .. "|" .. tostring(md.printMedia) end
        end
    end
    return s
end

--- What tells apart things of one type that may not share a tile: the rounds in a
--- magazine, the title a piece of print got (the game gives magazines and papers
--- one of their own), the name a thing shows.
function KnoxGrid.stateOf(item)
    return stateFor(item, item:getFullType())
end

--- What an item weighs carried loose, as the game counts it: the thing and what
--- is in it - the water in a bottle, the rounds in a magazine, a bag's contents.
--- (getActualWeight is the empty thing alone: a full jerrycan showed 1 kg, and
--- dragging a full bottle promised the weight of an empty one - 2026-10-18.)
function KnoxGrid.weightOf(item)
    return item:getUnequippedWeight() or item:getActualWeight() or 0
end

--- Most items of this type one tile holds: by weight - what a cell of small
--- things may weigh - and for big things by what fits (see KnoxFootprint).
function KnoxGrid.stackLimit(item)
    return KnoxFootprint.stack(item)
end

-- Bags in bags (the author, 2026-10-19): any bag goes into another, and a bag
-- with things in it takes more cells, in steps - empty: its own size; up to half
-- of its cells taken: halfway to full; more: about as many cells as it holds.
-- So a bag in a bag never makes more room than there is.

--- How many cells a container's grid has.
function KnoxGrid.totalCells(container, player)
    local shape = KnoxGrid.shapeOf(container, player)
    if shape then return shape.cells end
    local cols, rows, limit = KnoxGrid.getSize(container, player)
    return limit or cols * rows
end

--- How many cells the things in a container take (stacks counted as their tiles;
--- a bag in it as it lies now). `extra`: one more thing as if it were in.
function KnoxGrid.usedCells(container, extra)
    local n, stacks = 0, {}
    local function add(item)
        if item:isHidden() then return end
        local ft = item:getFullType()   -- (asked once, handed on)
        local w, h = KnoxFootprint.get(item, ft)
        if KnoxGrid.isStackable(item, ft) then
            local key = KnoxGrid.stackKey(item, ft)
            local s = stacks[key]
            if not s then
                s = {count = 0, area = w * h, limit = math.max(1, KnoxGrid.stackLimit(item))}
                stacks[key] = s
            end
            s.count = s.count + 1
        else
            n = n + w * h
        end
    end
    local items = container:getItems()
    for i = 0, items:size() - 1 do add(items:get(i)) end
    if extra then add(extra) end
    for _, s in pairs(stacks) do n = n + math.ceil(s.count / s.limit) * s.area end
    return n
end

--- A footprint of about `cells` cells, as long as the grid it stands for (`aspect`
--- = its long side / its short side), never under w x h.
local function footprintOf(cells, aspect, w, h)
    local long = math.min(KnoxGrid.MAX_H, math.max(h, math.ceil(math.sqrt(cells * aspect))))
    local short = math.min(8, math.max(w, math.ceil(cells / long)))
    if short > long then short, long = long, short end
    return short, long
end

--- The tile of a bag with `used` of its `total` cells taken (empty: w x h).
function KnoxGrid.steppedBag(container, w, h, used, total)
    if used <= 0 or total <= 0 then return w, h end
    local cols, rows = KnoxGrid.getSize(container, nil)
    local aspect = math.max(cols, rows) / math.max(1, math.min(cols, rows))
    local cells = total
    if used * 2 <= total then cells = math.floor((w * h + total) / 2 + 0.5) end
    return footprintOf(cells, aspect, w, h)
end

local grown = {}       -- item ID -> {sig, w, h, bw, bh, waits}
local grownN = 0

-- The bags' own grids up on the screen (KnoxGridView sets them: container -> its view,
-- its `layout` and `prerenderMs`): a bag's cells are taken from its grid's build, not
-- counted again - 500 bullets moved, their bag counted anew up to 4.4 ms, ~7 times a
-- second, just after its own grid had counted them (the author's bench 2026-10-29; the
-- author: "давай попробуем" - the bag's tile in the grid around it a frame later).
KnoxGrid.liveGrids = setmetatable({}, {__mode = "k"})
local waitIn = nil   -- the layout being built (not a dry one): it may wait for a bag's grid
local WAITS = 3      -- frames a bag's tile may wait in a row; then it is counted

--- KnoxFootprint.get for a bag: its tile as it is filled now.
function KnoxGrid.bagFootprint(item, w, h)
    local inv = item:getInventory()
    if not inv then return w, h end
    local count = inv:getItems():size()
    if count == 0 then return w, h end
    -- a key ring, a wallet, a first aid kit: small organizers keep their size
    -- (they are already as big outside as they hold - KnoxFootprint.byRules; the
    -- author, 2026-10-19: a key ring with keys grew to 1x4)
    if (inv:getCapacity() or 0) <= KnoxFootprint.NEST_CAPACITY then return w, h end
    local id = item:getID()
    -- (w x h too: the sizes may change while the game runs - the server's, KnoxNet)
    local sig = count .. "|" .. tostring(inv:getCapacityWeight()) .. "|" .. tostring(KnoxFootprint.gridScale()) .. "|" .. w .. "x" .. h
    local c = grown[id]
    if c and c.sig == sig then return c.w, c.h end
    -- (the detailed counter: how often a bag is counted anew and what it costs - the
    -- grids' long builds with 500 bullets moved, 2026-10-29)
    local Pf = KnoxPerf
    local pt = Pf and Pf.detail and Pf.now()
    local used
    local v = KnoxGrid.liveGrids[inv]
    local L = v and v.layout
    if L and L.itemCount == count and L.frame ~= nil and L.frame >= KnoxGrid.frame - 1 then
        -- its own grid has just been built with these things in it: its count
        used = KnoxGrid.cellsOf(L)
        if pt then pt = Pf.part("part: bag growth, from its grid", pt, count) end
    elseif waitIn and waitIn.frame == KnoxGrid.frame and c and c.bw == w and c.bh == h and (c.waits or 0) < WAITS
        and v and v.prerenderMs and getTimestampMs() - v.prerenderMs <= 250 then
        -- its grid is up and builds anew in a moment: the tile as it was, this once, and
        -- the grid being built looks again the next frame (KnoxGridView.prerender)
        c.waits = (c.waits or 0) + 1
        waitIn.bagWait = true
        if pt then Pf.part("part: bag growth, waits for its grid", pt, count) end
        return c.w, c.h
    else
        used = KnoxGrid.usedCells(inv)
        if pt then pt = Pf.part("part: bag growth, counted anew", pt, count) end
    end
    local gw, gh = KnoxGrid.steppedBag(inv, w, h, used, KnoxGrid.totalCells(inv, nil))
    if grownN > 4000 then grown, grownN = {}, 0 end
    if not c then grownN = grownN + 1 end
    grown[id] = {sig = sig, w = gw, h = gh, bw = w, bh = h}
    return gw, gh
end
KnoxFootprint.bagGrowth = KnoxGrid.bagFootprint

local nestCache = {}

--- Why `item` can't go into container `dest` because of bags in bags, or nil:
--- a bag lying in a grid grows with what is put into it - refused when it would
--- no longer fit there (at its place or any other free one).
function KnoxGrid.nestRefusal(item, dest, player)
    local holder = dest:getContainingItem()
    if not holder then return nil end                       -- pockets, a shelf, a trunk, the floor
    local outer = holder:getContainer()
    if not outer or item:getContainer() == dest then return nil end
    if player and KnoxGrid.isEquippedNow(holder, player) then return nil end   -- worn, in a hand: in no grid
    local now = getTimestampMs()
    local c = nestCache
    if c.item == item and c.dest == dest and now - c.ms < 300 then return c.why end
    local inv = holder:getInventory()
    if not inv or (inv:getCapacity() or 0) <= KnoxFootprint.NEST_CAPACITY then return nil end   -- an organizer doesn't grow
    local Pf = KnoxPerf
    local pt = Pf and Pf.detail and Pf.now()   -- (the detailed counter, 2026-10-29)
    local w0, h0 = KnoxFootprint.get(holder)
    local bw, bh = KnoxFootprint.getBase(holder)
    local w1, h1 = KnoxGrid.steppedBag(inv, bw, bh, KnoxGrid.usedCells(inv, item), KnoxGrid.totalCells(inv, nil))
    local why = nil
    if w1 ~= w0 or h1 ~= h0 then
        local L = KnoxGrid.build(outer, player, true)
        local own
        for _, e in ipairs(L.placed) do
            if e.item == holder then own = e break end
        end
        local grownE = {item = holder, items = {holder}, w = w1, h = h1}
        -- not laid out in that grid (a mod's bag hung on something - redchili's
        -- bicycle saddlebags, Sari-n 2026-10-20 - or already not fitting): there is
        -- no place for it to outgrow, nothing to refuse
        local ok = not own or own.overflow == true
        if not ok then
            local dw, dh = KnoxGrid.dims(grownE, own.r or 0)
            ok = L:fits(own.x, own.y, dw, dh, own)
            if not ok then
                -- (somewhere else in that grid, with its own cells free)
                for _, r in ipairs({0, 1}) do
                    local ww, hh = KnoxGrid.dims(grownE, r)
                    for y = 0, (L.baseRows or L.rows) - hh do
                        for x = 0, L.cols - ww do
                            if L:fits(x, y, ww, hh, own) then ok = true break end
                        end
                        if ok then break end
                    end
                    if ok then break end
                end
            end
        end
        if not ok then why = "IGUI_Knox_BagGrowsNoRoom" end
    end
    if pt then Pf.part("part: bag in a bag, checked", pt, inv:getItems():size()) end
    nestCache = {item = item, dest = dest, ms = now, why = why}
    return why
end

-- Moves in progress ------------------------------------------------------------
-- A drop queues timed actions (move to the main inventory, put on, take in
-- hand...). Until all of them finish, the item stays where it was taken from
-- as a faded copy filling up with the progress, and appears at the new place
-- only at the end. Its cells at the target are kept free meanwhile.
--   source/target = {kind = "grid", key, container?, x, y, r} or {kind = "slot", id}
-- A move ends when none of its actions are left in the queue (done or cancelled).

KnoxGrid.pending = {}       -- item -> record
KnoxGrid.pendingEpoch = 0   -- bumped when a move ends, so grids rebuild at once
local PENDING_MAX_MS = 60000

local function queueOf(player)
    local queues = ISTimedActionQueue and ISTimedActionQueue.queues
    local q = queues and queues[player]
    return q and q.queue
end

local function finish(item)
    KnoxGrid.pending[item] = nil
    KnoxGrid.pendingEpoch = KnoxGrid.pendingEpoch + 1
end

--- Run queueFn; the actions it queues become the steps of the move of `items`.
--- A transfer step is followed by its item: the game merges queued transfers
--- between the same two containers into the first one (its queueList), and
--- the merged actions are wiped from the queue.
function KnoxGrid.track(player, items, source, target, queueFn)
    local before = queueOf(player)
    local n0 = before and #before or 0
    queueFn()
    local q = queueOf(player)
    if not q then return end
    -- each step weighs its duration, so the whole chain fills one bar evenly
    local steps, total = {}, 0
    for i = n0 + 1, #q do
        local a = q[i]
        local wgt = math.max(1, tonumber(a.maxTime) or 1)
        table.insert(steps, {action = a, weight = wgt, item = a.queueList and a.item or nil})
        total = total + wgt
    end
    if total == 0 then return end
    local rec = {source = source, target = target, steps = steps, total = total,
                 player = player, items = items, t = getTimestampMs()}
    for _, it in ipairs(items) do KnoxGrid.pending[it] = rec end
    KnoxGrid.pendingEpoch = KnoxGrid.pendingEpoch + 1
end

-- The queue as the moves see it, looked at once for all of them in a frame: the
-- queued transfer carrying each item (its action, the index of its entry in the
-- action's queueList: 1 = being moved now) and each action's place in the queue.
-- A move was asked for each of its items and each faded tile of it, and every
-- ask went through the whole queue for each of its steps: thirty things on their
-- way at once cost some 29 ms a frame (offline bench; 30-35 FPS while they moved,
-- the author's test bench 2026-10-21). Made anew when the queue's shape changes (an
-- action done, a transfer's entry taken off - the game takes off a whole entry at
-- once, up to 20 small things of a type: ISInventoryTransferAction - or merged), so a
-- move that has just ended is never taken for running; when a move starts or ends;
-- and every QI_MS all the same. (By the clock's millisecond, as at first, it was made
-- anew every frame: 285 things on their way looked over ~175 times a second, up to
-- 0.9 ms each - the author's detailed bench 2026-10-29.)
local qi = {stamp = 0, ms = -1, n = -1, act = {}, entry = {}, pos = {}}
local QI_MS = 250

local function queueIndex(q)
    local now = getTimestampMs()
    local first = q[1]
    local fl = first and first.queueList
    local flN = fl and #fl or -1
    if qi.q == q and now - qi.ms < QI_MS and qi.epoch == KnoxGrid.pendingEpoch and qi.n == #q
        and qi.first == first and qi.flN == flN then
        return qi
    end
    local Pf = KnoxPerf
    local pt = Pf and Pf.detail and Pf.now()   -- (the detailed counter, 2026-10-29)
    local seen = 0
    qi.q, qi.ms, qi.epoch, qi.n, qi.first, qi.flN = q, now, KnoxGrid.pendingEpoch, #q, first, flN
    qi.stamp = qi.stamp + 1
    local act, entry, pos = {}, {}, {}
    for i, a in ipairs(q) do
        pos[a] = i
        if a.queueList then
            for k, e in ipairs(a.queueList) do
                for _, it in ipairs(e.items or {}) do
                    if act[it] == nil then act[it], entry[it] = a, k end
                    seen = seen + 1
                end
            end
        end
    end
    qi.act, qi.entry, qi.pos = act, entry, pos
    if pt then Pf.part("part: moves list, queue looked over", pt, seen) end
    return qi
end

local function deltaOf(a)
    if not a.action then return 0 end
    return math.max(0, math.min(1, a:getJobDelta() or 0))
end

--- Progress 0..1 of a move, or nil when it is over (done or cancelled).
--- (worked out once per look at the queue, then kept on the move: all its items share it.
--- What of the move is still queued, and what of that the action under way carries, is
--- the queue's: counted once per look at it. A frame takes only the action's progress -
--- its steps were gone over every frame, 260 bullets: up to 3.7 ms, the author's
--- detailed bench 2026-10-29. A move's progress goes on only in the game's tick: once
--- a frame.)
local function progressOf(rec)
    if getTimestampMs() - rec.t > PENDING_MAX_MS then return nil end
    local q = queueOf(rec.player)
    if not q then return nil end
    local ix = queueIndex(q)
    if rec.pStamp ~= ix.stamp then
        local left, under, any = 0, 0, false   -- weights still queued, of them the action's under way
        for _, s in ipairs(rec.steps) do
            if s.item then
                local a = ix.act[s.item]
                if a then
                    any = true
                    left = left + s.weight
                    if a == q[1] and ix.entry[s.item] == 1 then under = under + s.weight end
                end
            else
                local i = ix.pos[s.action]
                if i then
                    any = true
                    left = left + s.weight
                    if i == 1 then under = under + s.weight end
                end
            end
        end
        rec.pStamp, rec.left, rec.under, rec.any, rec.pFrame = ix.stamp, left, under, any, nil
    end
    if not rec.any then
        rec.p = false
        return nil
    end
    if rec.pFrame ~= KnoxGrid.frame then
        local delta = rec.under > 0 and deltaOf(q[1]) or 0
        rec.pFrame, rec.p = KnoxGrid.frame, 1 - (rec.left - rec.under * delta) / rec.total
    end
    return rec.p
end

-- (an item's entry kept from one list to the next, its progress brought up to date:
-- 500 bullets on their way made 500 tables a call, 2-3 calls a frame)
local entryOf = setmetatable({}, {__mode = "k"})

--- Moves still running: list of {item, rec, progress}; `list.slots` - those of
--- them from or to a slot. Drops finished ones.
--- (the progress worked out once a move, not once an item: 500 bullets moved, the
--- list took up to 20 ms and most of each grid's build - the author, 2026-10-28)
local listN = 0

-- (made once a frame and handed to all who ask in it: the screen, the slots and
-- every grid's build asked for it each, 2-3 times a frame - 300 us a frame with
-- 500 bullets on their way, the author's bench 2026-10-28. The same list in a frame
-- as long as the moves and each mover's queue are as they were: a move's progress
-- goes on only in the game's tick, not while the screen is drawn. By the clock's
-- millisecond, as at first, it was made anew 2 times a frame all the same - a frame
-- takes several: the author's bench, 2026-10-28.)
-- (and kept from frame to frame while they are as they were, only each move's progress
-- brought up to date: made anew every frame, 260 bullets on their way cost 0.45-0.6 ms
-- a frame, up to 4.5 ms - the author's detailed bench 2026-10-29)
KnoxGrid.frame = 0   -- frames drawn
if Events and Events.OnPreUIDraw then Events.OnPreUIDraw.Add(function() KnoxGrid.frame = KnoxGrid.frame + 1 end) end
local last = {frame = -1}

local function lastHolds()
    if not last.list or last.epoch ~= KnoxGrid.pendingEpoch or last.pending ~= KnoxGrid.pending then
        return false
    end
    for player, shape in pairs(last.queues) do
        local q = queueOf(player)
        local first = q and q[1]
        local fl = first and first.queueList
        if shape.q ~= q or shape.n ~= (q and #q or -1) or shape.first ~= first or shape.flN ~= (fl and #fl or -1) then
            return false
        end
    end
    return true
end

function KnoxGrid.pendingList()
    -- (the detailed counter: the list kept or made, its parts - 500 bullets moved:
    -- ~0.6 ms a frame, now and then up to 7 ms, the author's bench 2026-10-29)
    local Pf = KnoxPerf
    local pt = Pf and Pf.detail and Pf.now()
    if lastHolds() then
        if last.frame == KnoxGrid.frame then
            if pt then Pf.part("part: moves list, kept", pt) end
            return last.list
        end
        -- a new frame, the same moves: their progress (one look a move); one over -
        -- made anew below, which lets it go
        local over = false
        for _, rec in ipairs(last.recs) do
            if not progressOf(rec) then over = true break end
        end
        if not over then
            local list = last.list
            for i = 1, #list do
                local g = list[i]
                g.progress = g.rec.p
            end
            last.frame = KnoxGrid.frame
            if pt then Pf.part("part: moves list, progress brought up", pt, #list) end
            return list
        end
    end
    if pt then pt = Pf.part("part: moves list, looked if kept", pt) end
    local progUs, c0 = 0, 0
    listN = listN + 1
    local list, slots, recP, done = {n = listN}, {}, {}, nil
    local queues, recs = {}, {}
    for item, rec in pairs(KnoxGrid.pending) do
        local p = recP[rec]
        if p == nil then
            if pt then c0 = Pf.now() end
            p = progressOf(rec) or false
            if pt then progUs = progUs + Pf.now() - c0 end
            recP[rec] = p
            if p then table.insert(recs, rec) end
            if rec.player ~= nil and not queues[rec.player] then
                local q = queueOf(rec.player)
                local first = q and q[1]
                local fl = first and first.queueList
                queues[rec.player] = {q = q, n = q and #q or -1, first = first, flN = fl and #fl or -1}
            end
        end
        if p then
            local g = entryOf[item]
            if not g or g.rec ~= rec then
                g = {item = item, rec = rec}
                entryOf[item] = g
            end
            g.progress, g.listN = p, listN
            table.insert(list, g)
            local s, t = rec.source, rec.target
            if (s and s.kind == "slot") or (t and t.kind == "slot") then table.insert(slots, g) end
        else
            done = done or {}
            table.insert(done, item)
        end
    end
    if pt then
        Pf.addPart("part: moves list, progress of moves", progUs)
        pt = Pf.part("part: moves list, made", pt, #list)
    end
    if done then
        for _, item in ipairs(done) do finish(item) end
    end
    if pt and done then Pf.part("part: moves list, ended", pt, #done) end
    list.slots = slots
    last.frame, last.epoch, last.pending, last.queues, last.list = KnoxGrid.frame, KnoxGrid.pendingEpoch, KnoxGrid.pending, queues, list
    last.recs = recs
    return list
end

-- Order of the moves: when several run at once (a Ctrl selection dropped
-- somewhere), each faded copy shows its turn. A move's place in the queue is
-- that of its first step still waiting (a merged transfer counts by its
-- entry in the action's queueList).
local orderCache = {ms = -1}

local function queueKey(rec, q)
    local ix = queueIndex(q)
    local best
    for _, s in ipairs(rec.steps) do
        local key
        if s.item then
            local a = ix.act[s.item]
            if a then key = ix.pos[a] * 1000 + ix.entry[s.item] end
        else
            local i = ix.pos[s.action]
            if i then key = i * 1000 end
        end
        if key and (not best or key < best) then best = key end
    end
    return best
end

-- A move keeps the number it got (2 stays 2 when move 1 is done). New moves
-- are numbered in queue order after the highest number still running; when
-- nothing is running any more the count starts again at 1.
local turnsGiven = 0   -- numbers handed out in the current run of moves

--- Turn of a move (fixed once given), or nil when it is the only one.
function KnoxGrid.orderOf(rec)
    local now = getTimestampMs()
    if orderCache.ms ~= now then
        orderCache.ms = now
        local fresh, seen, top, any = {}, {}, 0, false
        for _, r in pairs(KnoxGrid.pending) do
            if not seen[r] then
                seen[r] = true
                any = true
                if r.turn then
                    top = math.max(top, r.turn)
                else
                    local q = queueOf(r.player)
                    local key = q and queueKey(r, q)
                    if key then table.insert(fresh, {rec = r, key = key}) end
                end
            end
        end
        if not any then turnsGiven = 0 end
        table.sort(fresh, function(a, b) return a.key < b.key end)
        for i, x in ipairs(fresh) do
            x.rec.turn = top + i
            turnsGiven = turnsGiven + 1
        end
    end
    if turnsGiven < 2 then return nil end
    return rec.turn
end

--- The running move of an item: record, progress; or nil.
function KnoxGrid.pendingOf(item)
    local rec = KnoxGrid.pending[item]
    if not rec then return nil end
    local p = progressOf(rec)
    if not p then
        finish(item)
        return nil
    end
    return rec, p
end

--- Is the item in this list of moves (one that pendingList made)?
function KnoxGrid.inList(item, list)
    local g = entryOf[item]
    return g ~= nil and g.listN == list.n
end

--- The move leaving a slot right now: item, progress; or nil.
--- (`list.slots` when there: every slot looked over all 500 bullets of a move each frame)
function KnoxGrid.leavingSlot(list, id)
    for _, g in ipairs(list.slots or list) do
        local s = g.rec.source
        if s and s.kind == "slot" and s.id == id then return g.item, g.progress end
    end
    return nil
end

--- Is an item on its way to slot `id`?
function KnoxGrid.arrivingSlot(list, id)
    for _, g in ipairs(list.slots or list) do
        local t = g.rec.target
        if t and t.kind == "slot" and t.id == id then return true end
    end
    return false
end

-- Items in use ------------------------------------------------------------------
-- The character's current timed action (eating, bandaging, reading, a grab
-- from a context menu...) fills the tiles of the items it works with, like a
-- move does. Its items are found among the action's fields.

KnoxGrid.useNow = {}   -- item -> progress 0..1, refreshed once a frame by the screen

function KnoxGrid.updateUse(player)
    local map = {}
    local q = queueOf(player)
    local a = q and q[1]
    if a and a.action then
        local d = deltaOf(a)
        local function take(v)
            if type(v) ~= "userdata" then return end
            if instanceof(v, "InventoryItem") then
                if not KnoxGrid.pending[v] then map[v] = d end
            elseif instanceof(v, "ArrayList") then
                -- a recipe's action keeps what it works on in lists (tearing a
                -- sheet, sawing a log: ISHandcraftAction.items)
                for i = 0, math.min(v:size(), 60) - 1 do
                    local it = v:get(i)
                    if type(it) == "userdata" and instanceof(it, "InventoryItem") and not KnoxGrid.pending[it] then map[it] = d end
                end
            end
        end
        for _, v in pairs(a) do
            if type(v) == "table" then
                -- (one level down: a recipe's inputs picked by hand are a table of lists)
                if v ~= a.character then
                    local n = 0
                    for _, vv in pairs(v) do
                        n = n + 1
                        if n > 40 then break end
                        take(vv)
                    end
                end
            else
                take(v)
            end
        end
    end
    KnoxGrid.useNow = map
end

--- Progress of the action using one of these items, or nil.
function KnoxGrid.useOf(items)
    for _, it in ipairs(items) do
        local p = KnoxGrid.useNow[it]
        if p then return p end
    end
    return nil
end

--- Does the item lie in the player's own inventory (directly or inside a bag
--- that does)? Only such items can be "worn, held or on the hotbar" for the
--- player. Items in a corpse, on a shelf or in a trunk can carry the game's own
--- worn / attached flags (a zombie's clothes and bag), but they are loot, not
--- something on the player's body, and must stay visible in their grid.
local function inPlayers(c, player)
    local inv = player:getInventory()
    for _ = 1, 12 do
        if not c then return false end
        if c == inv then return true end
        local holder = c:getContainingItem()
        if not holder then return false end
        c = holder:getContainer()
    end
    return false
end

local function lieOnPlayer(item, player)
    return inPlayers(item:getContainer(), player)
end

-- (`hand1`, `hand2`: the player's hands, looked at once for a whole grid's build)
local function equippedOn(item, player, hand1, hand2)
    -- items in hands stay in the main inventory; isEquipped() doesn't count them in B42
    if item == hand1 or item == hand2 then return true end
    if player:isEquipped(item) or item:isEquipped() then return true end
    local slot = item:getAttachedSlot()
    return slot ~= nil and slot > -1
end

--- Worn, in a hand or on the hotbar right now.
function KnoxGrid.isEquippedNow(item, player)
    if not player then return false end
    if not lieOnPlayer(item, player) then return false end
    return equippedOn(item, player, player:getPrimaryHandItem(), player:getSecondaryHandItem())
end

-- Places ------------------------------------------------------------------------

local function readPlace(item, key)
    local md = item:getModData()
    local p = md.knoxP
    if p and p.k == key then return p, true end
    p = md.knox
    if p and p.k == key then return p, false end
    return nil
end

--- `auto`: the grid found the place itself (a build), not the player.
function KnoxGrid.writePlace(entity, key, x, y, r, auto)
    for i = 1, #entity.items do
        local item = entity.items[i]
        local md = item:getModData()
        md.knox = {k = key, x = x, y = y, r = r}
        told(item, "knox", auto)
        -- a wanted place in another container stays: the item may be on its way
        -- there (taken off into the pockets first, then moved to a bag)
        if md.knoxP and md.knoxP.k == key then
            md.knoxP = nil
            told(item, "knoxP", auto)
        end
    end
end

function KnoxGrid.writePending(entity, key, x, y, r)
    for i = 1, #entity.items do
        entity.items[i]:getModData().knoxP = {k = key, x = x, y = y, r = r}
        told(entity.items[i], "knoxP")
    end
end

--- Footprint of an entity with rotation applied.
function KnoxGrid.dims(entity, r)
    if r == 1 then return entity.h, entity.w end
    return entity.w, entity.h
end

-- Layout ------------------------------------------------------------------

local Layout = {}
Layout.__index = Layout

function Layout:cellAt(x, y)
    if x < 0 or y < 0 or x >= self.cols or y >= self.rows then return nil end
    return self.cells[y * self.cols + x + 1]
end

--- Is x,y inside the grid's rectangle but not a cell of it (past its last cell,
--- or between a bag's compartments)?
function Layout:blocked(x, y)
    if y >= (self.baseRows or self.rows) then return false end
    if self.shape then return self.shape.mask[y * self.cols + x] == nil end
    return self.limit ~= nil and y * self.cols + x >= self.limit
end

--- The compartment a cell of the grid proper is in (bags with compartments), or nil.
function Layout:partAt(x, y)
    if not self.shape or y >= (self.baseRows or self.rows) or x < 0 or y < 0 or x >= self.cols then return nil end
    return self.shape.mask[y * self.cols + x]
end

--- Free for a w x h block at x,y? `ignore` = entity allowed to overlap (itself).
function Layout:fits(x, y, w, h, ignore)
    if x < 0 or y < 0 or x + w > self.cols or y + h > self.rows then return false end
    if self.limit then
        -- the grid's cells run row by row: the block is inside when the last of
        -- its cells in the grid proper is (the overflow rows under it are whole)
        local last = math.min(y + h - 1, (self.baseRows or self.rows) - 1)
        if last >= y and last * self.cols + x + w - 1 >= self.limit then return false end
    end
    local shape = self.shape
    if shape and y < (self.baseRows or self.rows) then
        -- all of it in one compartment (they are apart: a block across two has
        -- cells between them in it)
        local part = shape.mask[y * self.cols + x]
        if not part or x + w > part.lx + part.w or y + h > part.ly + part.h then return false end
        -- a compartment of any form (drawn cell by cell): every cell of the block in it
        if shape.free and not part.rect then
            for yy = y, y + h - 1 do
                for xx = x, x + w - 1 do
                    if shape.mask[yy * self.cols + xx] ~= part then return false end
                end
            end
        end
    elseif shape and x + w > shape.ovCols then
        -- the rows under the compartments are only as wide as they are drawn
        return false
    end
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do
            local e = self.cells[yy * self.cols + xx + 1]
            -- compared by item: the grid may have been rebuilt since `ignore` was taken
            if e and not (ignore and e.item == ignore.item) then return false end
        end
    end
    return true
end

function Layout:occupy(entity, x, y, r)
    local w, h = KnoxGrid.dims(entity, r)
    entity.x, entity.y, entity.r = x, y, r
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do
            self.cells[yy * self.cols + xx + 1] = entity
        end
    end
    table.insert(self.placed, entity)
end

--- First free spot scanning rows top to bottom, upright before rotated; only
--- in the grid proper unless `anyRow` (the overflow rows under it too).
function Layout:findFree(entity, ignore, anyRow)
    local rows = anyRow and self.rows or (self.baseRows or self.rows)
    if self.shape then
        -- a bag with compartments: the biggest first (the main room), each upright
        -- before turned, then the next
        for _, p in ipairs(self.shape.order) do
            for _, r in ipairs({0, 1}) do
                local w, h = KnoxGrid.dims(entity, r)
                if (r == 0 or w ~= h) and w <= p.w and h <= p.h then
                    for y = p.ly, p.ly + p.h - h do
                        for x = p.lx, p.lx + p.w - w do
                            if self:fits(x, y, w, h, ignore) then return x, y, r end
                        end
                    end
                end
            end
        end
        if not anyRow then return nil end
    end
    for _, r in ipairs({0, 1}) do
        local w, h = KnoxGrid.dims(entity, r)
        if r == 0 or w ~= h then
            for y = 0, rows - h do
                for x = 0, self.cols - w do
                    if self:fits(x, y, w, h, ignore) then return x, y, r end
                end
            end
        end
    end
    return nil
end

--- A free spot picked at random in the grid proper, either way up (nil: none).
function Layout:findRandom(entity)
    local rows = self.baseRows or self.rows
    local spots = {}
    for _, r in ipairs({0, 1}) do
        local w, h = KnoxGrid.dims(entity, r)
        if r == 0 or w ~= h then
            for y = 0, rows - h do
                for x = 0, self.cols - w do
                    if self:fits(x, y, w, h) then table.insert(spots, {x, y, r}) end
                end
            end
        end
    end
    if #spots == 0 then return nil end
    local s = spots[ZombRand(#spots) + 1]
    return s[1], s[2], s[3]
end

--- Take a tile off its cells again (undoing occupy).
function Layout:vacate(entity)
    local w, h = KnoxGrid.dims(entity, entity.r)
    for yy = entity.y, entity.y + h - 1 do
        for xx = entity.x, entity.x + w - 1 do
            if self.cells[yy * self.cols + xx + 1] == entity then self.cells[yy * self.cols + xx + 1] = nil end
        end
    end
    for i = #self.placed, 1, -1 do
        if self.placed[i] == entity then table.remove(self.placed, i) break end
    end
end

--- Things found in the world lie as they were thrown in, not in rows (the author,
--- 2026-10-19): a tile in a container of the world (furniture, a car, a body - not
--- the floor) whose items never had a place in any grid.
local function untouchedLoot(e, key, container)
    local k = string.sub(key, 1, 1)
    -- (a car is "v" alone and "m" in a game with others: KnoxGrid.containerKey)
    if (k ~= "w" and k ~= "v" and k ~= "m") or container:getType() == "floor" then return false end
    for _, it in ipairs(e.items) do
        local md = it:getModData()
        if md.knox or md.knoxP then return false end
    end
    return true
end

function KnoxGrid.scatterOn()
    return KnoxTheme == nil or KnoxTheme.switch == nil or KnoxTheme.switch("scatter")
end

--- Where a tile that comes without a place of its own goes: the place the
--- player's order gives it (KnoxOrder sets KnoxGrid.placer: its layout,
--- next to its category), else the first free one.
function KnoxGrid.placeNew(layout, entity)
    if KnoxGrid.placer then
        local ok, x, y, r = pcall(KnoxGrid.placer, layout, entity)
        if ok then return x, y, r end
    end
    return layout:findFree(entity)
end

-- Stacks: items of one type share a tile. A split-off part gets its own stack
-- id (modData knoxS) and so its own tile; merging gives it the other's id.
local stackCounter = 0

function KnoxGrid.newStackId()
    stackCounter = stackCounter + 1
    return tostring(getTimestampMs()) .. "-" .. stackCounter
end

-- A magazine stacks only with magazines holding as many rounds: loaded and empty ones
-- in one tile could be loaded only one at a time, from the first (Nik_135, 2026-10-17).
local function rounds(item)
    if (item:getMaxAmmo() or 0) <= 0 then return "" end
    return "|r" .. tostring(item:getCurrentAmmoCount() or 0)
end
KnoxGrid.rounds = rounds

--- (`ft`: its full type, when the caller has it)
function KnoxGrid.stackKey(item, ft)
    ft = ft or item:getFullType()
    return ft .. stateFor(item, ft) .. "|" .. tostring(item:getModData().knoxS or "")
end

function KnoxGrid.setStackId(items, id)
    for _, it in ipairs(items) do
        it:getModData().knoxS = id
        told(it, "knoxS")
    end
end

--- How many items of tile `a` the stack `b` can take in: 0 when the two don't
--- stack together or `b` is full (a tile holds stackLimit items).
function KnoxGrid.mergeRoom(a, b)
    if not (a ~= nil and b ~= nil and a.item ~= b.item and not b.ghost and not b.reserved
        and KnoxGrid.isStackable(a.item) and KnoxGrid.isStackable(b.item)
        and a.item:getFullType() == b.item:getFullType() and KnoxGrid.stateOf(a.item) == KnoxGrid.stateOf(b.item)) then
        return 0
    end
    local room = KnoxGrid.stackLimit(b.item) - #b.items - (b.joinN or 0)
    return math.max(0, math.min(#a.items, room))
end

--- Can tile `a` join the stack `b` whole? (What wouldn't fit would pop out as
--- a tile of its own at some other place: a move that only picks the container
--- joins a stack whole or not at all. A tile dropped on a stack by hand tops it
--- up and keeps the rest: see KnoxDrag.drop.)
function KnoxGrid.canMerge(a, b)
    return a ~= nil and KnoxGrid.mergeRoom(a, b) == #a.items
end

-- KnoxGrid.isEquippedNow for a thing of `container` (`onPlayer`, `hand1`, `hand2`: of it and the player)
local function equippedHere(item, container, player, onPlayer, hand1, hand2)
    if not player then return false end
    if item:getContainer() ~= container then return KnoxGrid.isEquippedNow(item, player) end
    return onPlayer and equippedOn(item, player, hand1, hand2)
end

--- Group the container's visible items into entities (tiles). Items on the
--- body or in a move are left out: a move shows as its faded copy instead.
--- Also counts the cells it all takes, as KnoxGrid.usedCells does (KnoxGrid.cellsOf):
--- the tiles' cells and stacks here, what is left out kept to be counted when asked.
local function collectEntities(container, player, moving)
    local entities = {}
    local stacks = {}
    local tally, loose, away, moved = {}, 0, nil, nil   -- stack key -> {n, area, limit, item}
    local items = container:getItems()
    -- (the detailed counter: the look at "worn, in a hand" and at stacks, summed over
    -- the things - the grids' long builds, 2026-10-29)
    local Pf = KnoxPerf
    local pd = Pf and Pf.detail and Pf.now
    local wornUs, stackUs, sizeUs, c0 = 0, 0, 0, 0
    -- (whether the container is on the player, and its hands: once for the grid, not
    -- once a thing - a bag's chain of holders was walked up for each of 500 bullets)
    local onPlayer = player ~= nil and inPlayers(container, player)
    local hand1 = onPlayer and player:getPrimaryHandItem()
    local hand2 = onPlayer and player:getSecondaryHandItem()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        -- (not what the game hides from its own inventory either: item:isHidden() -
        -- the fists of unarmed-combat mods, Hardship Brawler's, Bruce Lee's gloves,
        -- piled up in the pockets as tiles: AssassinKody's and Eleorn's reports, 2026-10-16)
        if not item:isHidden() then
            -- (on its way: by the list the build has just made, not asked again item
            -- by item - two looks at the clock each, 33 000 a 10 s with 500 bullets moved)
            local g = entryOf[item]
            if pd then c0 = pd() end
            local worn = not (g and g.listN == moving.n) and equippedHere(item, container, player, onPlayer, hand1, hand2)
            if pd then wornUs = wornUs + pd() - c0 end
            if g and g.listN == moving.n then
                moved = moved or {}
                table.insert(moved, g)
            elseif worn then
                away = away or {}
                table.insert(away, item)
            else
                -- (asked once, and the stack's key made only for what stacks)
                if pd then c0 = pd() end
                local fullType = item:getFullType()   -- (asked once, handed on)
                local stackable = KnoxGrid.isStackable(item, fullType)
                local ft = stackable and KnoxGrid.stackKey(item, fullType)
                local t = stackable and tally[ft]
                local stack = t and stacks[ft]
                -- (a stack's limit asked once a build: it is its type's - KnoxFootprint.stack)
                local limit = t and t.limit
                if t and not limit then
                    limit = KnoxGrid.stackLimit(item)
                    t.limit = limit
                end
                if stack and limit and #stack.items >= limit then stack = nil end   -- full: a new tile
                if pd then stackUs = stackUs + pd() - c0 end
                if stack then
                    table.insert(stack.items, item)
                    t.n = t.n + 1
                else
                    if pd then c0 = pd() end
                    local w, h = KnoxFootprint.get(item, fullType)
                    if pd then sizeUs = sizeUs + pd() - c0 end
                    local e = {item = item, items = {item}, w = w, h = h}
                    table.insert(entities, e)
                    if stackable then
                        stacks[ft] = e
                        if t then
                            t.n = t.n + 1
                        else
                            tally[ft] = {n = 1, area = w * h, item = item}
                        end
                    else
                        loose = loose + w * h
                    end
                end
            end
        end
    end
    if pd then
        Pf.addPart("part: grid build 2a worn / in hand", wornUs)
        Pf.addPart("part: grid build 2b stacks", stackUs)
        Pf.addPart("part: grid build 2c sizes", sizeUs, #entities)
    end
    return entities, tally, loose, away, moved
end

--- How many cells the things in a built grid's container take: what KnoxGrid.usedCells
--- says, from what the build has already looked at (once a build, kept on it).
--- (the bags' meters counted them on their own four times a second: up to 6 ms a
--- count for a bag of 500 bullets - the author's bench 2026-10-28)
function KnoxGrid.cellsOf(L)
    if L.used then return L.used end
    local tally = L.tally
    if not tally then return KnoxGrid.usedCells(L.container) end   -- (not a build's: emptyLike)
    local n = L.loose
    local function add(item, key)
        if key then
            local t = tally[key]
            if t then t.n = t.n + 1 else tally[key] = {n = 1, item = item} end
        else
            local w, h = KnoxFootprint.get(item)
            n = n + w * h
        end
    end
    if L.away then
        for _, item in ipairs(L.away) do add(item, KnoxGrid.isStackable(item) and KnoxGrid.stackKey(item)) end
    end
    -- (a thing on its way keeps its stack's key for the move - set before it starts,
    -- KnoxDrag, KnoxActions: 500 bullets moved, each looked at once, not each build)
    if L.moved then
        for _, g in ipairs(L.moved) do
            if g.cellKey == nil then g.cellKey = KnoxGrid.isStackable(g.item) and KnoxGrid.stackKey(g.item) end
            add(g.item, g.cellKey)
        end
    end
    for _, t in pairs(tally) do
        if not t.area then
            local w, h = KnoxFootprint.get(t.item)
            t.area = w * h
        end
        local limit = t.n > 1 and math.max(1, t.limit or KnoxGrid.stackLimit(t.item)) or 1
        n = n + math.ceil(t.n / limit) * t.area
    end
    L.used = n
    return n
end

--- Build the grid for a container. Saves first-free places it picks - unless
--- `dry`: then the places are only worked out, nothing is written on the items
--- (what a hero carries, written for the menu's bag while the player may use
--- the game's own inventory: KnoxMenuBag - their things must not change).
--- `mayWait`: a grid on the screen, built again when it asks - a bag's tile in it
--- may wait a frame for the bag's own grid (bagFootprint); a drop, an action, a dry
--- build get every size at once.
function KnoxGrid.build(container, player, dry, mayWait)
    -- (the detailed counter: each step's time - the grids' long builds, 2026-10-29)
    local Pf = KnoxPerf
    local pt = Pf and Pf.detail and Pf.now()
    local cols, rows, limit = KnoxGrid.getSize(container, player)
    local key = KnoxGrid.containerKey(container, player)
    local layout = setmetatable({
        container = container, key = key, cols = cols, rows = rows, baseRows = rows, limit = limit,
        shape = KnoxGrid.shapeOf(container, player), cells = {}, placed = {}, overflow = {},
        frame = KnoxGrid.frame,
    }, Layout)
    local outerWait = waitIn
    waitIn = (mayWait and not dry) and layout or nil
    if pt then pt = Pf.part("part: grid build 0 size, shape", pt) end

    -- Moves first: the faded copy of an item leaving this grid keeps its old
    -- cells. The cells an item is coming to are held (nothing drawn there),
    -- but only after the tiles that lie in the grid have taken their places:
    -- items coming to join a stack must not push that stack off its cells.
    local seen, coming = {}, {}
    local moving = KnoxGrid.pendingList()
    for _, g in ipairs(moving) do
        local rec = g.rec
        if not seen[rec] then
            seen[rec] = true
            local w, h = KnoxFootprint.get(g.item)
            local s, t = rec.source, rec.target
            -- (by the container itself when the move knows it: two of one type
            -- on one square - bodies in a pile - share a key, and the faded
            -- copies showed in both; Sharp's report, 2026-10-15)
            if s and s.kind == "grid" and s.key == key and (s.container == nil or s.container == container) then
                local e = {item = g.item, items = rec.items, w = w, h = h, ghost = true}
                local dw, dh = KnoxGrid.dims(e, s.r)
                if layout:fits(s.x, s.y, dw, dh) then layout:occupy(e, s.x, s.y, s.r) end
            end
            if t and t.kind == "grid" and t.key == key and (t.container == nil or t.container == container) then
                table.insert(coming, {e = {item = g.item, items = rec.items, w = w, h = h, reserved = true}, t = t})
            end
        end
    end

    if pt then pt = Pf.part("part: grid build 1 moves", pt, #moving) end

    local entities
    entities, layout.tally, layout.loose, layout.away, layout.moved = collectEntities(container, player, moving)
    if pt then pt = Pf.part("part: grid build 2 things", pt, container:getItems():size()) end
    local homeless = {}

    -- Saved places. A stack keeps the place of its first member that has one.
    for _, e in ipairs(entities) do
        local place, pending
        for _, it in ipairs(e.items) do
            place, pending = readPlace(it, key)
            if place then break end
        end
        local r = place and (place.r == 1 and 1 or 0) or 0
        local w, h = KnoxGrid.dims(e, r)
        if place and layout:fits(place.x, place.y, w, h) then
            layout:occupy(e, place.x, place.y, r)
            if pending and not dry then KnoxGrid.writePlace(e, key, place.x, place.y, r, true) end
        else
            table.insert(homeless, e)
        end
    end

    for _, c in ipairs(coming) do
        local dw, dh = KnoxGrid.dims(c.e, c.t.r)
        if layout:fits(c.t.x, c.t.y, dw, dh) then layout:occupy(c.e, c.t.x, c.t.y, c.t.r) end
    end

    if pt then pt = Pf.part("part: grid build 3 saved places", pt, #entities) end

    -- found in the world, never placed: at random free places, the biggest first;
    -- when one finds no room so (the others took it in bits), they all go back to
    -- the ordinary placing below, which packs them
    if not dry and KnoxGrid.scatterOn() then
        local loot, rest = {}, {}
        for _, e in ipairs(homeless) do
            table.insert(untouchedLoot(e, key, container) and loot or rest, e)
        end
        -- (more of them than there are free cells: it can't come out - and what
        -- never fits stays "never placed", tried again every build: 4 of 8 ms of
        -- a full shelf's)
        if #loot > 0 then
            local need, free = 0, 0
            for _, e in ipairs(loot) do need = need + e.w * e.h end
            for y = 0, layout.baseRows - 1 do
                for x = 0, cols - 1 do
                    if not layout.cells[y * cols + x + 1] and not layout:blocked(x, y) then free = free + 1 end
                end
            end
            if need > free then loot = {} end
        end
        if #loot > 0 then
            table.sort(loot, function(a, b) return a.w * a.h > b.w * b.h end)
            local done = {}
            for _, e in ipairs(loot) do
                local x, y, r = layout:findRandom(e)
                if not x then
                    for _, d in ipairs(done) do layout:vacate(d) end
                    done = nil
                    break
                end
                layout:occupy(e, x, y, r)
                table.insert(done, e)
            end
            if done then
                for _, e in ipairs(done) do KnoxGrid.writePlace(e, key, e.x, e.y, e.r, true) end
                homeless = rest
            end
        end
    end

    if pt then pt = Pf.part("part: grid build 4 found in the world", pt) end

    -- (a tile that found no room: no tile at least as big either way finds any -
    -- the grid only fills up. Without this a shelf of 300 things that don't all
    -- fit looked over the whole grid for each of the rest: 55 of 56 ms a build)
    local failed = {}
    for _, e in ipairs(homeless) do
        local s, l = math.min(e.w, e.h), math.max(e.w, e.h)
        local hopeless = false
        for _, f in ipairs(failed) do
            if s >= f[1] and l >= f[2] then hopeless = true break end
        end
        local x, y, r
        if not hopeless then x, y, r = KnoxGrid.placeNew(layout, e) end
        if x then
            layout:occupy(e, x, y, r)
            if not dry then KnoxGrid.writePlace(e, key, x, y, r, true) end
        else
            if not hopeless then table.insert(failed, {s, l}) end
            table.insert(layout.overflow, e)
        end
    end

    if pt then pt = Pf.part("part: grid build 5 new places", pt, #homeless) end

    -- Items the game put in although the grid has no room left (spawned,
    -- crafted, added by its own actions - it only checks weight): shown in
    -- extra rows under the grid, marked, until there is room in it. Nothing
    -- can be dropped there; their places aren't saved, so a later build moves
    -- them into the grid as soon as it fits.
    -- They are stacked in one pass, each where its columns' tops are lowest
    -- (a skyline): looking for the first free spot in the whole grid for each
    -- of them, and growing it a row at a time, took half a second for a floor
    -- of hundreds of things - built four times a second, the game crawled.
    -- (a bag with compartments: the rows under it as wide as its widest row of
    -- cells - narrower than its grid, whose compartments are apart)
    local ovCols = layout.shape and layout.shape.ovCols or cols
    local top = {}
    for x = 0, ovCols - 1 do top[x] = layout.baseRows end
    for _, e in ipairs(layout.overflow) do
        e.overflow = true
        -- wider than the grid even turned (a long item in a narrow pouch):
        -- shown squeezed to the grid's width, so it is never lost from view
        if math.min(e.w, e.h) > ovCols then
            e.w, e.h = ovCols, math.min(math.max(e.w, e.h), ovCols)
        end
        local r = (e.w > ovCols) and 1 or 0
        local w, h = KnoxGrid.dims(e, r)
        local bestX, bestY = 0, nil
        for x = 0, ovCols - w do
            local y = top[x]
            for xx = x + 1, x + w - 1 do
                if top[xx] > y then y = top[xx] end
            end
            if not bestY or y < bestY then bestX, bestY = x, y end
        end
        for xx = bestX, bestX + w - 1 do top[xx] = bestY + h end
        layout.rows = math.max(layout.rows, bestY + h)
        layout:occupy(e, bestX, bestY, r)
    end

    if pt then Pf.part("part: grid build 6 not fitting", pt, #layout.overflow) end

    layout.itemCount = container:getItems():size()
    waitIn = outerWait
    return layout
end

--- A grid's size as text: "5x6"; "4x2+2" when its last row is not whole; a bag
--- with compartments: its main room and the cells of the rest, "5x6+12".
function KnoxGrid.sizeText(L)
    local base = L.baseRows or L.rows
    if L.shape then
        local m = L.shape.main
        -- (a main room of any form, drawn cell by cell: the bag's cells in all)
        if L.shape.free and not m.rect then return tostring(L.shape.cells) end
        local rest = L.shape.cells - m.w * m.h
        return m.w .. "x" .. m.h .. (rest > 0 and ("+" .. rest) or "")
    end
    if not L.limit then return L.cols .. "x" .. base end
    local whole = math.floor(L.limit / L.cols)
    return L.cols .. "x" .. whole .. "+" .. (L.limit - whole * L.cols)
end

--- An empty layout of the same grid (for repacking it).
function KnoxGrid.emptyLike(L)
    return setmetatable({container = L.container, key = L.key, cols = L.cols, rows = L.baseRows or L.rows,
                         baseRows = L.baseRows or L.rows, limit = L.limit, shape = L.shape,
                         cells = {}, placed = {}, overflow = {}}, Layout)
end

return KnoxGrid
