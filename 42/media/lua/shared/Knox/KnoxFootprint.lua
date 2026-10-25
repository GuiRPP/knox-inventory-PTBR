-- Item footprint: how many grid cells (w x h) an item takes, how many of it one
-- tile holds, and - for a bag - the shape of its own grid.
--
-- One model for everything:
--   * a cell is volume: CELL model units a side (a baseball bat is 4 cells long,
--     a can 1); an item lies on its two longest sides;
--   * what a thing weighs bounds what it may take (models mislead both ways: an
--     open umbrella, a fish drawn large; a small heavy lump);
--   * clothing goes by where it is worn - its model is a garment laid out flat
--     and its script weight is often a placeholder;
--   * a bag's grid has CELLS_PER_CAPACITY cells per unit of the game's capacity,
--     shaped by the kind of bag; weight stays the game's own limit;
--   * small things share a tile: STACK_KG of them per cell.
--
-- The game's own items are worked out ahead: KnoxFootprintData.lua, made by
-- tools/footprint/gen.lua from a measure of every item's 3D model (DEV panel >
-- "Measure") with the rules below - this file is the only place they live.
-- Items of other mods go through the same rules at run time; their models are
-- measured by the Java part when first seen and remembered in
-- Zomboid/Lua/knox_sizes.txt, so an item keeps its size from then on.

require "Knox/KnoxPerf"   -- (first: Knox's performance counter times the handlers this file adds, when dev.perf=1)
require "Knox/KnoxFootprintData"
require "Knox/KnoxBagShapes"

KnoxFootprint = KnoxFootprint or {}
local F = KnoxFootprint

F.CELL = 0.115               -- model units per cell
F.CELLS_PER_CAPACITY = 2     -- cells of a bag's grid per unit of its capacity
F.CELLS_PER_CAPACITY_WORLD = 3   -- furniture, car boots, seats: roomier - there the game's weight limit decides
F.STACK_KG = 2               -- what a cell of small things may weigh
F.NEST_CAPACITY = 5          -- bags up to this capacity may lie in a bag with things in them
-- How roomy bags and pockets are: the rules' cells (two a unit of capacity), and the
-- player's own slider over them (settings, "Size of bags and pockets", 50..200 %).
-- (2026-10-19: tried a quarter more, then 2.5 a unit, then 0.875 - all taken back by
-- the author; the slider and Organized's cells stayed. A bag has 4 cells at least:
-- the author, after the rollback.)
F.GENEROUS = 1.0
F.MIN_BAG_CELLS = 4

--- How many times the rules' cells bags and pockets get now.
function F.gridScale()
    local pct = 100
    -- (in a game with others the server's, the same for every player - the author, 2026-10-20)
    if KnoxNet and KnoxNet.scale then
        pct = KnoxNet.scale
    elseif KnoxTheme and KnoxTheme.look then
        pct = KnoxTheme.look("grid.scale")
    end
    return F.GENEROUS * pct / 100
end
local TOL = 0.45             -- a side takes one more cell only past this part of it
local MAX_SHORT, MAX_LONG = 4, 6
local BAG_COLS = 8           -- the widest grid the inventory column shows

local function round(x)
    return math.floor(x + 0.5)
end

--- A body location or a "can be equipped" value as a plain name: "base:Jacket_Bulky" -> "jacketbulky".
-- (kept: the equipment column sorts what is worn by it every frame - three string
-- functions a location; there are a hundred or so locations)
local normOf, normN = {}, 0

function F.norm(loc)
    if loc == nil then return "" end
    local hit = normOf[loc]
    if hit then return hit end
    local s = string.lower(tostring(loc))
    s = string.gsub(s, "^.*[:%.]", "")
    s = string.gsub(s, "[^%a%d]", "")
    if s == "nil" then s = "" end
    normN = normN + 1
    if normN > 1000 then normOf, normN = {}, 1 end
    normOf[loc] = s
    return s
end

-- Rules -----------------------------------------------------------------------
-- They work on plain facts about an item type, so the same code serves the game
-- (facts read from a live item) and the generator (facts read from the measure):
--   id, kind ("weapon", "container", "clothing", "food", "literature", "moveable",
--   "radio", "drainable", "normal"), weight, worn (F.norm), twoHand, ranged,
--   capacity, wide (a bag carried lying: a duffel), fluid (it holds a liquid),
--   dims = {long, middle, thin} sides of the model in cells, or nil.

local function q(x)
    return math.max(1, math.ceil(x - TOL))
end

--- Short and long side of a thing by its box.
local function bySize(d, thin, maxLong)
    local h = q(d[1])
    local w
    -- a whole cell thick: bulky, its shorter side is not rounded down
    if not thin and d[3] >= 1.0 then w = math.max(1, math.ceil(d[2] - 0.1)) else w = q(d[2]) end
    if not thin and d[3] >= 2.0 then w = w + 1 end
    if w > h then w, h = h, w end
    return math.min(w, MAX_SHORT), math.min(h, maxLong or MAX_LONG)
end

-- {from kg, least cells, most cells}
local AREA = {{0, 1, 1}, {0.06, 1, 2}, {0.15, 1, 3}, {0.35, 1, 4}, {0.75, 1, 6}, {1.5, 1, 9}, {2.5, 2, 9}, {3, 2, 12},
              {5, 4, 12}, {6, 4, 16}, {10, 6, 16}, {12, 6, 24}, {20, 9, 24}, {35, 12, 24}}

--- Grow w x h to `least` cells, a side at a time, keeping as near `aspect` (long / short) as it can.
local function grow(w, h, least, aspect)
    while w * h < least do
        local canH = h < MAX_LONG
        local canW = w < MAX_SHORT and w < h
        if not canH and not canW then
            if w < MAX_SHORT then w = w + 1 else break end
        else
            local aW = canW and h / (w + 1) or 1e9
            local aH = canH and (h + 1) / w or 1e9
            if math.abs(aW - aspect) <= math.abs(aH - aspect) then w = w + 1 else h = h + 1 end
        end
    end
    return w, h
end

--- Shrink or grow w x h into the bounds of its weight.
local function bound(w, h, kg, aspect)
    local b = AREA[1]
    for i = 1, #AREA do
        if kg >= AREA[i][1] then b = AREA[i] end
    end
    while w * h > b[3] and h > 1 do
        local canW = w > 1
        local aW = canW and h / (w - 1) or 1e9
        local aH = math.max(w, h - 1) / math.min(w, h - 1)
        -- (a long thing keeps its length: a hoe is a pole, whatever its head is)
        if canW and (aspect >= 2.5 or math.abs(aW - aspect) <= math.abs(aH - aspect)) then w = w - 1 else h = h - 1 end
        if w > h then w, h = h, w end
    end
    return grow(w, h, b[2], aspect)
end

local function byWeight(kg)
    if kg < 0.3 then return 1, 1 end
    if kg < 1.0 then return 1, 2 end
    if kg < 3.0 then return 2, 2 end
    if kg < 8.0 then return 2, 3 end
    if kg < 20.0 then return 3, 3 end
    if kg < 35.0 then return 4, 4 end
    return 4, 6
end

-- Clothing by body location: {w, h}, or {w, h, from kg, w2, h2} = bigger from
-- that weight on; `thick` instead of a weight: bigger when its model is that
-- many cells high (boots against shoes: the game gives both one weight).
local WORN = {}
local function worn(names, ...)
    local size = {...}
    for name in string.gmatch(names, "%S+") do WORN[name] = size end
end
worn("eyes ears eartop nose necklace necklacelong neck necktexture leftwrist rightwrist bellybutton", 1, 1)
worn("leftmiddlefinger leftringfinger rightmiddlefinger rightringfinger lefteye righteye", 1, 1)
worn("socks underwear underwearbottom underweartop underwearextra1 underwearextra2 tail codpiece", 1, 1)
worn("gorget kneeleft kneeright elbowleft elbowright beltextra ankleholster gaiterleft gaiterright", 1, 1)
worn("makeupeyes makeupeyesshadow makeupfullface makeuplips zeddmg wound bandage", 1, 1)
worn("hands handsleft handsright", 1, 1, 0.5, 1, 2)                -- work and armoured gloves
worn("mask", 1, 1, 0.5, 1, 2)                                     -- a gas mask
worn("scarf belt maskeyes legs1 satchel leftarm rightarm", 1, 2)
worn("hat", 1, 1, 1.0, 2, 2)                                      -- caps and beanies; helmets and brimmed hats
worn("fullhat maskfull", 2, 2)
worn("tshirt tanktop shortsleeveshirt shirt jersey vesttexture", 1, 2)
worn("shortpants shortsshort skirt torsoextra", 1, 2)
worn("shoes", 1, 2, false, 2, 2)                                    -- boots
WORN.shoes.thick = 0.9
worn("calfleft calfright calflefttexture calfrighttexture thighleft thighright", 1, 2, 2.0, 2, 2)
worn("forearmleft forearmright", 1, 2, 2.0, 2, 2)
-- trousers and sweaters (hoodies too) fold as small as a T-shirt; every jacket,
-- padded and bulky ones too, is 2x2 (the author, 2026-10-20)
worn("pants pantsskinny pantsextra sweater sweaterhat", 1, 2)
worn("longskirt dress longdress", 2, 2)
worn("jackethat jacketsuit torsoextravest jacket jacketbulky jackethatbulky jacketdown", 2, 2)
worn("boilersuit fullsuit fullsuithead torso1legs1 bathrobe fulltop", 2, 2, 4.0, 2, 3)
worn("shoulderpadleft shoulderpadright", 2, 2)
worn("torsoextravestbullet cuirass back scbanotank", 2, 3)
worn("sportshoulderpad sportshoulderpadontop", 2, 3)
worn("scba", 2, 4)
F.WORN = WORN

-- Bags worn flat against the body, by where they are worn (their models are
-- laid out like garments); backpacks and bags carried in a hand go by model.
local WORN_BAG = {ammostrap = {1, 2}, shoulderholster = {1, 2}, fannypackfront = {1, 2}, fannypackback = {1, 2},
                  webbing = {2, 2}, satchel = {2, 2}}

-- Set by hand where the model misleads (a coil, a pile, a thing that folds).
local HAND = {}
local function hand(names, w, h)
    for name in string.gmatch(names, "%S+") do HAND["Base." .. name] = {w, h} end
end
hand("UmbrellaBlack UmbrellaWhite UmbrellaBlue UmbrellaRed UmbrellaTINTED", 1, 4)   -- their model is open
hand("Scythe ScytheForged", 2, 6)
hand("Rope", 1, 2)                                                                 -- a coil
hand("Grapefruit", 1, 1)                                                           -- drawn as two halves side by side
hand("NailsBox", 1, 2)                                                             -- an open carton drawn large
-- the author's look over the inventory, 2026-10-20
hand("Propane_Refill", 1, 2)                                                       -- the lamp's propane bottle
hand("SteelBar", 1, 3)
hand("CardDeck", 1, 1)
hand("Mov_PosterDroids", 2, 4)                                                     -- Dr. Oids Painting
hand("CigarBox CigarBox_Gaming CigarBox_Keepsakes CigarBox_Kids", 1, 2)
hand("Cornflour Cornflour2 Cornmeal", 2, 2)                                        -- corn flour: a sack like the flour's
-- the author's look over the kitchen and the bathroom, 2026-10-22
hand("Chocolate Butter KnifeFillet OvenMitt Toothbrush Toothpaste Tissue", 1, 1)
hand("GenericMail LetterHandwritten SheetPaper2 Flier Flier_Nolans Paperwork", 1, 1)   -- paper folds
hand("Strainer RollingPin BreadKnife SewingKit", 1, 2)
-- the author's list, 2026-10-25
hand("CuttingBoardPlastic CuttingBoardWooden BarbedWire", 2, 2)
hand("Note Doodle Brochure Straw Straw2", 1, 1)
hand("WalkieTalkie1 WalkieTalkie2 WalkieTalkie3 WalkieTalkie4 WalkieTalkie5 WalkieTalkieMakeShift", 1, 2)   -- every walkie-talkie
hand("WheatSheaf WheatSheafDried", 1, 2)
hand("Fleshing_Tool", 1, 3)
hand("Rake", 1, 4)
F.HAND = HAND

-- How many one tile holds, set by hand (over the rules' count by weight).
local HAND_STACK = {}
local function handStack(names, n)
    for name in string.gmatch(names, "%S+") do HAND_STACK["Base." .. name] = n end
end
handStack("Pillow Pillow_Crafted Pillow_Happyface Pillow_Heart Pillow_Star", 1)   -- (the author, 2026-10-20)
handStack("Propane_Refill", 1)   -- (a bottle is 1x2 because it is big: four to a tile undid that)
handStack("Remote Tweezers Tweezers_Forged", 1)   -- (the author, 2026-10-22)
handStack("GrassTuft", 10)                        -- (the author, 2026-10-22: by weight it was 4)
F.HAND_STACK = HAND_STACK

-- A bag's own grid set by hand: {columns, least rows}.
local HAND_BAG = {
    ["Base.Bag_FluteCase"] = {4, 1},     -- the flute lies in it taken apart; ours doesn't come apart
}

--- How many cells a bag of this capacity has.
function F.bagCells(capacity)
    return math.max(2, round((capacity or 0) * F.CELLS_PER_CAPACITY))
end

--- Columns for `cells` cells: the count as near as it gets, then the shape (columns / rows).
local function bestCols(cells, aspect)
    local best, bestScore
    for cols = 1, BAG_COLS do
        local rows = math.max(1, round(cells / cols))
        local a = (cols / rows) / aspect
        if a < 1 then a = 1 / a end
        local score = math.abs(cols * rows - cells) / cells * 6 + (a - 1)
        if not best or score < bestScore - 1e-9 then best, bestScore = cols, score end
    end
    return best
end

--- The shape of a bag's own grid: its columns and the least rows it has. The
--- rows follow its capacity (see F.bagGrid): a mod that makes bags bigger gets
--- more rows of the same shape.
function F.bagRules(f)
    local set = HAND_BAG[f.id]
    if set then return set[1], set[2] end
    -- a wallet (cash, a card, an ID, a photo...) and a key ring: a strip of four,
    -- and still one cell outside (see the organizer rule in F.byRules)
    local id = f.id or ""
    if string.find(id, "^Base%.Wallet") or string.find(id, "^Base%.KeyRing") then return 4, 1 end
    local cells = F.bagCells(f.capacity)
    local aspect = 1.4                                  -- carried in a hand: a little wider than tall
    if f.wide then aspect = 1.6                         -- a duffel lies on its side
    elseif f.worn == "back" then aspect = 0.8           -- a backpack stands
    elseif f.worn == "satchel" then aspect = 1.5 end
    local cols = bestCols(cells, aspect)
    local minRows = 1
    local d = f.dims
    if d and d[1] >= 2.2 * d[2] then
        -- a case for something long (a rifle, a guitar): as long inside as outside
        local s, l = bySize(d, false, BAG_COLS)
        if l >= 3 then
            local rows = math.max(1, round(cells / cols))
            if not ((cols >= l and rows >= s) or (cols >= s and rows >= l)) then cols, minRows = l, s end
        end
    end
    return cols, minRows
end

--- Columns and rows of a bag's grid for its shape and the capacity it has now.
function F.gridFor(cols, minRows, capacity)
    return cols, math.max(minRows or 1, round(F.bagCells(capacity) / cols))
end

--- Footprint by the rules: short side, long side, what it came from.
function F.byRules(f)
    local set = HAND[f.id]
    if set then return set[1], set[2], "hand" end
    local kg = f.weight or 0
    if f.kind == "clothing" then
        local r = WORN[f.worn]
        if r then
            if (r[3] and kg >= r[3] - 1e-9) or (r.thick and f.dims and f.dims[3] >= r.thick) then
                return r[4], r[5], "worn"
            end
            return r[1], r[2], "worn"
        end
    end
    local w, h, how
    local flat = f.kind == "container" and WORN_BAG[f.worn]
    if flat then
        w, h, how = flat[1], flat[2], "worn"
    elseif not f.dims then
        w, h = byWeight(kg)
        how = "weight"
    else
        local d = f.dims
        local weapon = f.kind == "weapon"     -- held by its handle: never "bulky"
        w, h = bySize(d, weapon)
        w, h = bound(w, h, kg, d[1] / math.max(0.2, d[2]))
        if weapon and f.twoHand and h < 3 then h = 3 end
        if weapon and f.ranged and h < 2 then h = 2 end          -- a handgun
        -- cutlery, a pocket knife, a scalpel: drawn twice their size, a cell is plenty
        if weapon and not f.ranged and not f.twoHand and kg < 0.35 then w, h = 1, 1 end
        -- an empty plastic, paper or garbage bag is folded (its model is a full one)
        if f.kind == "container" and kg <= 0.15 then w, h = 1, 1 end
        if f.kind == "literature" and w * h > 2 then w, h = 1, 2 end   -- paper folds
        -- a paperback takes what a magazine does (the author, 2026-10-20)
        if f.kind == "literature" and string.find(f.id or "", "^Base%.Paperback") then w, h = 1, 2 end
        how = "model"
    end
    if f.kind == "container" and (f.capacity or 0) > 0 and f.capacity <= F.NEST_CAPACITY then
        -- an organizer may lie in a bag with things in it: it can't be much
        -- smaller outside than inside, or it would multiply the room
        local cols, minRows = F.bagRules(f)
        local rows
        cols, rows = F.gridFor(cols, minRows, f.capacity)
        w, h = grow(w, h, math.ceil(cols * rows / 4), h / w)
    end
    return w, h, how
end

local NICE = {1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100}

--- How many of an item one tile of w x h holds.
function F.stackRules(f, w, h)
    if f.id and HAND_STACK[f.id] then return HAND_STACK[f.id] end
    if not (f.kind == "normal" or f.kind == "drainable") or f.fluid then return 1 end
    local kg = f.weight or 0
    if kg <= 0 then return 100 end
    local area = w * h
    local n = F.STACK_KG * area / kg
    if area > 1 then
        -- a big thing: also by what fits (a tile is one cell deep; a thing fills
        -- a good half of its box), four at most. Small things are left to their
        -- weight: their models are drawn large (a "9 mm round" is a handful).
        local d = f.dims
        if d then
            local vol = d[1] * d[2] * d[3] * 0.6
            if vol > 0 then n = math.min(n, area / vol) end
        end
        n = math.min(n, 4)
    end
    local best = 1
    for i = 1, #NICE do
        if NICE[i] <= n + 1e-9 then best = NICE[i] end
    end
    return best
end

--- "dx,dy,dz[,scale]" in model units -> {long, middle, thin} in cells, or nil.
function F.sides(text)
    if not text or text == "" then return nil end
    local d = {}
    for part in string.gmatch(text, "[^,]+") do
        if #d < 3 then
            local v = tonumber(part)
            if not v then return nil end
            table.insert(d, v / F.CELL)
        end
    end
    if #d < 3 then return nil end
    table.sort(d, function(a, b) return a > b end)
    return d
end

-- Items of other mods ---------------------------------------------------------
-- Their models are measured by the Java part (knoxMeasureModel: the mesh's box).
-- A mesh loads in the background, so the first answer may be "loading": until it
-- comes the item goes by its weight, and nothing is remembered yet.

local SIZES_FILE = "knox_sizes.txt"
local ASK_MS = 8000          -- how long one model may take to load

local learned = {}           -- full type -> "dx,dy,dz,scale", or "-" (it has no model to measure)
local asking = {}            -- full type -> {names, i, since}
local unsaved = {}

local function loadLearned()
    if not getFileReader then return end
    local r = getFileReader(SIZES_FILE, false)
    if not r then return end
    local line = r:readLine()
    while line do
        local at = string.find(line, "=", 1, true)
        if at and at > 1 then learned[string.sub(line, 1, at - 1)] = string.sub(line, at + 1) end
        line = r:readLine()
    end
    r:close()
end

local function saveLearned()
    if #unsaved == 0 or not getFileWriter then return end
    local w = getFileWriter(SIZES_FILE, true, true)
    if w then
        for _, line in ipairs(unsaved) do w:write(line .. "\r\n") end
        w:close()
    end
    unsaved = {}
end

local function remember(fullType, text)
    learned[fullType] = text
    asking[fullType] = nil
    table.insert(unsaved, fullType .. "=" .. text)
end

--- The model script behind a model's name as items give it (with or without the module).
local function modelScript(name)
    if not name or name == "" then return nil end
    local sm = getScriptManager()
    local ms = sm:getModelScript(name)
    if not ms and not string.find(name, ".", 1, true) then ms = sm:getModelScript("Base." .. name) end
    return ms and ms:getFullType() or nil
end

--- Sides of an item's model in cells; false: it has none; nil: not known yet.
local function sidesOf(item, fullType, weapon)
    local known = learned[fullType]
    if known then return F.sides(known) or false end
    if not knoxMeasureModel then return false end
    local now = getTimestampMs()
    local a = asking[fullType]
    if not a then
        -- a weapon by the model held in the hand, anything else by the one lying on the ground
        local names = {}
        local function add(name)
            local full = modelScript(name)
            if full then table.insert(names, full) end
        end
        if weapon then
            add(item:getStaticModel())
            add(item:getWeaponSprite())
            add(item:getWorldStaticModel())
        else
            add(item:getWorldStaticModel())
            add(item:getStaticModel())
        end
        a = {names = names, i = 1, since = now}
        asking[fullType] = a
    end
    while a.i <= #a.names do
        local s = knoxMeasureModel(a.names[a.i])
        if s == "loading" then
            if now - a.since < ASK_MS then return nil end
        elseif s and F.sides(s) then
            remember(fullType, s)
            return F.sides(s)
        end
        a.i = a.i + 1       -- not a model with a mesh of its own, or too slow: the next one
        a.since = now
    end
    remember(fullType, "-")
    return false
end

local function kindOf(item)
    if instanceof(item, "HandWeapon") then return "weapon" end
    if instanceof(item, "InventoryContainer") then return "container" end
    if instanceof(item, "Clothing") then return "clothing" end
    if instanceof(item, "Food") then return "food" end
    if instanceof(item, "Literature") then return "literature" end
    if instanceof(item, "Radio") then return "radio" end          -- (a Radio is a Moveable too)
    if instanceof(item, "Moveable") then return "moveable" end
    if item:IsDrainable() then return "drainable" end
    return "normal"
end

--- Facts about a live item, and whether they are final (false: its model is
--- still loading, or - furniture - they are this very item's, not its type's).
local function factsOf(item, fullType)
    local kind = kindOf(item)
    local f = {id = fullType, kind = kind, weight = item:getWeight() or 0, worn = ""}
    local final = true
    if kind == "moveable" then
        -- picked up furniture: one item type for all of it, the weight is the sprite's
        f.weight = math.max(f.weight, item:getActualWeight() or 0)
        return f, false
    end
    f.fluid = item:getFluidContainer() ~= nil
    if kind == "weapon" then
        f.twoHand = item:isTwoHandWeapon()
        f.ranged = item:isRanged()
    elseif kind == "clothing" then
        f.worn = F.norm(item:getBodyLocation())
        local r = WORN[f.worn]
        if r and not r.thick then return f, true end       -- its model isn't asked for
    elseif kind == "container" then
        local inv = item:getInventory()
        f.capacity = inv and inv:getCapacity() or 0
        f.worn = F.norm(item:canBeEquipped())
        f.wide = string.find(string.lower(fullType .. " " .. tostring(item:getWorldStaticModel())), "duffel", 1, true) ~= nil
    end
    local d = sidesOf(item, fullType, kind == "weapon")
    if d then f.dims = d elseif d == nil then final = false end
    return f, final
end

-- The player's own sizes ---------------------------------------------------------
-- Zomboid/Lua/knox_overrides.txt: a line per item, written by hand, read when the
-- mod's Lua loads (a game start, the main menu). It goes over everything else:
--   Base.Katana = 1x5            the item's cells (it still turns: 1x5 = 5x1)
--   Base.Bag_ALICEpack = grid 8x10   a bag's grid inside, whatever its capacity
--   Base.Nails = stack 50        how many share a tile
--   show_ids = yes               item tooltips show the item's ID (to write it here)
-- Asked for by a player with 200 mods (Hemalon, 2026-10-14): some mod item always
-- gets a size that is off, and some bags want more or less room.

local OVERRIDES_FILE = "knox_overrides.txt"
F.overrides = {}         -- full type -> {w, h, cols, rows, stack}
F.showIds = false

local MAX_SIDE, MAX_COLS, MAX_ROWS, MAX_STACK = 20, 20, 40, 1000
-- Knox's categories (KnoxTheme.category): weapons, ammo, medicine, food, tools,
-- materials, clothing and bags, books and keys, the rest
F.CATEGORIES = {wpn = true, ammo = true, med = true, food = true, tool = true, mat = true, clo = true, info = true, misc = true}

local function clampInt(v, lo, hi)
    v = tonumber(v)
    if not v then return nil end
    v = math.floor(v)
    if v < lo or v > hi then return nil end
    return v
end

--- One line of the file: true when it set something (comments, blank and
--- broken lines set nothing).
function F.parseOverride(line)
    line = string.gsub(line or "", "#.*$", "")
    local key, rest = string.match(line, "^%s*([^=%s]+)%s*=%s*(.-)%s*$")
    if not key or rest == "" then return false end
    rest = string.lower(rest)
    if string.lower(key) == "show_ids" then
        F.showIds = rest == "yes" or rest == "1" or rest == "true" or rest == "on"
        return true
    end
    local o = {}
    -- a bag's compartments (KnoxBagShapes): rows of WxH, "/" between rows - the
    -- rest of the line up to another word
    local parts = string.match(rest, "parts%s*([%dx%s/]+)")
    if parts then
        parts = string.gsub(string.gsub(parts, "^%s+", ""), "%s+$", "")
        if KnoxBagShapes and KnoxBagShapes.parse(parts) then o.parts = parts end
        rest = string.gsub(rest, "parts%s*[%dx%s/]+", " ")
    end
    local gc, gr = string.match(rest, "grid%s*(%d+)%s*x%s*(%d+)")
    if gc then
        o.cols, o.rows = clampInt(gc, 1, MAX_COLS), clampInt(gr, 1, MAX_ROWS)
        if not (o.cols and o.rows) then o.cols, o.rows = nil, nil end
        rest = string.gsub(rest, "grid%s*%d+%s*x%s*%d+", "")
    end
    local st = string.match(rest, "stack%s*(%d+)")
    if st then
        o.stack = clampInt(st, 1, MAX_STACK)
        rest = string.gsub(rest, "stack%s*%d+", "")
    end
    -- the category Sort and the tile's color take (Knox's own names)
    local cat = string.match(rest, "category%s*(%a+)")
    if cat and F.CATEGORIES[cat] then o.cat = cat end
    rest = string.gsub(rest, "category%s*%a*", "")
    -- what it sounds like (KnoxMaterial's names: softpaper, glass, tin, cloth...)
    local snd = string.match(rest, "sound%s*(%a+)")
    if snd then o.sound = snd end
    rest = string.gsub(rest, "sound%s*%a*", "")
    local a, b = string.match(rest, "(%d+)%s*x%s*(%d+)")
    a, b = clampInt(a, 1, MAX_SIDE), clampInt(b, 1, MAX_SIDE)
    if a and b then o.w, o.h = math.min(a, b), math.max(a, b) end   -- (short side, long side, as the rules give)
    if not (o.w or o.cols or o.stack or o.cat or o.sound or o.parts) then return false end
    F.overrides[key] = o
    return true
end

local TEMPLATE = {
    "# Knox Inventory: your own item sizes. One line per item, then exit to the main menu",
    "# and load your save again (the file is read when the mod's Lua loads).",
    "#",
    "#   Base.Katana = 1x5                 cells the item takes (it still turns)",
    "#   Base.Bag_ALICEpack = grid 8x10    a bag's grid inside, whatever its capacity",
    "#   Base.Nails = stack 50             how many share one tile",
    "#   Base.Bag_Schoolbag = grid 5x6 stack 1   (several on one line work too)",
    "#   Base.Bleach = category mat        the category Sort puts it in: wpn ammo med food",
    "#                                     tool mat clo info misc",
    "#   Mod.Bag = parts 4x2 / 1x2 5x6 1x2   a bag's compartments: rows top to bottom, \"/\" between",
    "#                                     them, each WxH in cells (a 4x2 lid over a 5x6 room with",
    "#                                     a 1x2 pocket each side); grid CxR instead = one grid",
    "#   Base.ToiletPaper = sound softpaper   what it sounds like when moved or found: softpaper paper",
    "#                                     magazine book cardboard cloth leather shoes tin metalsmall metal",
    "#                                     jewelry keys glass ceramic plastic plasticsoft pills ammo wood",
    "#                                     stone food fooddry",
    "#",
    "# The ID of an item: set show_ids to yes below, and item tooltips show it.",
    "# Lines starting with # are notes. A bag's grid has 15 rows at most.",
    "",
    "show_ids = no",
}

local function loadOverrides()
    if not getFileReader then return end
    local r = getFileReader(OVERRIDES_FILE, false)
    if not r then
        -- no file yet: one with the instructions, for the player to find and fill
        if getFileWriter then
            local w = getFileWriter(OVERRIDES_FILE, true, false)
            if w then
                for _, l in ipairs(TEMPLATE) do w:write(l .. "\r\n") end
                w:close()
            end
        end
        return
    end
    local n = 0
    local line = r:readLine()
    while line do
        if F.parseOverride(line) and not string.find(line, "^%s*show_ids") then n = n + 1 end
        line = r:readLine()
    end
    r:close()
    if n > 0 then print("[Knox] " .. OVERRIDES_FILE .. ": " .. n .. " item size(s) of the player's own") end
end

-- Answers ---------------------------------------------------------------------

local cache = {}   -- full type -> {w, h, stack, cols, minRows}

--- A game with others: the server's knox_overrides.txt lines in place of the
--- player's own (the player's show_ids stays), the answers worked out anew.
function F.useOverrides(lines)
    local showIds = F.showIds
    F.overrides = {}
    for _, l in ipairs(lines or {}) do F.parseOverride(l) end
    F.showIds = showIds
    cache = {}
end

--- The player's own sizes over what the rules or the table gave.
local function overridden(fullType, c)
    local o = F.overrides[fullType]
    if not o then return c end
    if o.w then c.w, c.h = o.w, o.h end
    if o.stack then c.stack = o.stack end
    if o.cols then c.gridCols, c.gridRows = o.cols, o.rows end
    return c
end

--- Cigarettes, cigars: food to the game, but they don't spoil and are not eaten
--- bit by bit - they stack as a pack holds them (an opened pack took 20 cells,
--- LBBz 2026-10-15). See KnoxGrid.isStackable.
F.SMOKES_STACK = 20
function F.isSmoke(item)
    return instanceof(item, "Food") and ItemTag ~= nil and ItemTag.SMOKABLE ~= nil
        and item:hasTag(ItemTag.SMOKABLE) == true
end

local function resolve(item, fullType)
    local c = F.resolveRaw(item, fullType)
    if F.isSmoke(item) and not (F.overrides[fullType] and F.overrides[fullType].stack) then
        c.stack = F.SMOKES_STACK
    end
    return c
end

function F.resolveRaw(item, fullType)
    local packed = KnoxFootprintData and KnoxFootprintData[fullType]
    if packed then
        local c = {w = math.floor(packed / 10) % 10, h = packed % 10, stack = math.floor(packed / 100)}
        local bag = KnoxBagData and KnoxBagData[fullType]
        if bag then c.cols, c.minRows = math.floor(bag / 100), bag % 100 end
        c = overridden(fullType, c)
        cache[fullType] = c
        return c
    end
    local f, final = factsOf(item, fullType)
    local c = {}
    c.w, c.h = F.byRules(f)
    c.stack = F.stackRules(f, c.w, c.h)
    if f.kind == "container" then c.cols, c.minRows = F.bagRules(f) end
    c = overridden(fullType, c)
    if final then cache[fullType] = c end
    return c
end

local function answer(item)
    local fullType = item:getFullType()
    return cache[fullType] or resolve(item, fullType)
end

--- @return number w, number h  unrotated footprint in cells (short side, long side)
--- (a bag with things in it takes more: F.bagGrowth, set by KnoxGrid)
function F.get(item)
    local c = answer(item)
    if F.bagGrowth and instanceof(item, "InventoryContainer") then return F.bagGrowth(item, c.w, c.h) end
    return c.w, c.h
end

--- The footprint of the item's type, as it lies empty.
function F.getBase(item)
    local c = answer(item)
    return c.w, c.h
end

--- Most items of this type one tile holds.
function F.stack(item)
    local c = answer(item)
    if (c.stack or 1) <= 1 and (instanceof(item, "Food") or instanceof(item, "Literature")) then
        -- food and print never stacked, so the rules gave them no stack; the plain
        -- ones do now (KnoxGrid.isStackable): by weight, as small things go
        local o = F.overrides[item:getFullType()]
        if o and o.stack then return o.stack end
        -- (set by hand: grass)
        local hs = HAND_STACK[item:getFullType()]
        if hs then return hs end
        if not c.plainStack then
            c.plainStack = F.stackRules({kind = "normal", weight = item:getWeight() or 0}, c.w, c.h)
        end
        return c.plainStack
    end
    return c.stack or 1
end

--- Columns and rows of the grid of a bag with this capacity, `scale` times the
--- rules' cells (F.gridScale and the character's Organized: KnoxGrid.getSize).
--- The shape grows both ways, no wider than the inventory column.
function F.bagGrid(item, capacity, scale)
    local c = answer(item)
    if c.gridCols then return c.gridCols, c.gridRows end   -- the player's own grid (knox_overrides.txt)
    if not c.cols then
        c.cols, c.minRows = F.bagRules({id = item:getFullType(), kind = "container", capacity = capacity, worn = ""})
    end
    scale = scale or 1
    local cols = c.cols
    local cells = math.max(F.MIN_BAG_CELLS, round((capacity or 0) * F.CELLS_PER_CAPACITY * scale))
    if scale ~= 1 then cols = math.max(1, math.min(BAG_COLS, round(cols * math.sqrt(scale)))) end
    return cols, math.max(c.minRows or 1, round(cells / cols))
end

if getFileReader and not (isServer and isServer()) then
    loadOverrides()
    loadLearned()
    local lastSave = 0
    Events.OnTick.Add(function()
        if #unsaved == 0 then return end
        local now = getTimestampMs()
        if now - lastSave < 2000 then return end
        lastSave = now
        saveLearned()
    end)
end

return KnoxFootprint
