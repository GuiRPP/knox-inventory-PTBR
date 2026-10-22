-- Works out the footprint, the stack size and the bag grid of every item of the
-- game with the mod's own rules (KnoxFootprint.lua), from the measure made in
-- game (DEV panel > "Measure" -> Zomboid/Lua/knox_measure.txt, copied next to
-- this file). Run by tools/footprint/gen.ps1 on the game's own Lua:
--
--   LuaRun.java stubs.lua KnoxFootprint.lua gen.lua measure=... out=... report=...
--
-- Writes KnoxFootprintData.lua (what the mod reads) and report.txt (for the eye:
-- the spread of sizes, bags, stacks, and a balance check - typical loads against
-- each bag, by weight and by cells).

local F = KnoxFootprint

local function split(line)
    local out, from = {}, 1
    while true do
        local at = string.find(line, "|", from, true)
        if not at then
            table.insert(out, string.sub(line, from))
            return out
        end
        table.insert(out, string.sub(line, from, at - 1))
        from = at + 1
    end
end

local head
local items, byId = {}, {}
for line in string.gmatch(readfile(measure), "[^\r\n]+") do
    if string.sub(line, 1, 1) ~= "#" then
        local p = split(line)
        if not head then
            head = p
        else
            local m = {}
            for i, name in ipairs(head) do m[name] = p[i] or "" end
            local kind = m.kind
            local world, static, sprite = F.sides(m.worldSize), F.sides(m.staticSize), F.sides(m.spriteSize)
            local f = {id = m.fullType, kind = kind, weight = tonumber(m.weight) or 0, worn = F.norm(m.worn),
                       twoHand = m.twoHand == "1", ranged = m.ranged == "1", capacity = tonumber(m.capacity) or 0,
                       fluid = (tonumber(m.fluid) or 0) > 0}
            -- a weapon by the model held in the hand, anything else by the one lying on the ground
            if kind == "weapon" then f.dims = static or sprite or world else f.dims = world or static or sprite end
            if kind == "container" then
                f.wide = string.find(string.lower(m.fullType .. " " .. m.world), "duffel", 1, true) ~= nil
            end
            table.insert(items, f)
            byId[f.id] = f
        end
    end
end

-- the answers
local count, hows, dist, byKind, unknownWorn = 0, {}, {}, {}, {}
for _, f in ipairs(items) do
    do
        local w, h, how = F.byRules(f)
        f.w, f.h, f.how = w, h, how
        f.stack = F.stackRules(f, w, h)
        if f.kind == "container" and f.capacity > 0 then
            f.cols, f.minRows = F.bagRules(f)
            f.cols, f.rows = F.gridFor(f.cols, f.minRows, f.capacity)
        end
        count = count + 1
        hows[how] = (hows[how] or 0) + 1
        local key = w .. "x" .. h
        dist[key] = (dist[key] or 0) + 1
        byKind[f.kind] = byKind[f.kind] or {}
        byKind[f.kind][key] = (byKind[f.kind][key] or 0) + 1
        if f.kind == "clothing" and how ~= "worn" and how ~= "hand" then
            unknownWorn[f.worn] = (unknownWorn[f.worn] or 0) + 1
        end
    end
end

local function sortedKeys(t, byValue)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    if byValue then
        table.sort(keys, function(a, b) if t[a] ~= t[b] then return t[a] > t[b] end return a < b end)
    else
        table.sort(keys)
    end
    return keys
end

-- the data file
local ids = {}
for _, f in ipairs(items) do
    if f.w then table.insert(ids, f.id) end
end
table.sort(ids)
local lua = {
    "-- Footprints, stack sizes and bag grids of the game's own items, worked out by",
    "-- tools/footprint/gen.lua with the rules of KnoxFootprint.lua. Do not edit by hand:",
    "-- change the rules and run tools/footprint/gen.ps1 again.",
    "-- KnoxFootprintData: items one tile holds * 100 + short side * 10 + long side.",
    "-- KnoxBagData: columns of the bag's grid * 100 + its least rows.",
    "KnoxFootprintData = {",
}
for _, id in ipairs(ids) do
    local f = byId[id]
    table.insert(lua, '["' .. id .. '"]=' .. (f.stack * 100 + f.w * 10 + f.h) .. ",")
end
table.insert(lua, "}")
table.insert(lua, "KnoxBagData = {")
local bags = 0
for _, id in ipairs(ids) do
    local f = byId[id]
    if f.cols then
        bags = bags + 1
        table.insert(lua, '["' .. id .. '"]=' .. (f.cols * 100 + f.minRows) .. ",")
    end
end
table.insert(lua, "}")
table.insert(lua, "")
writefile(out, table.concat(lua, "\r\n"))

-- the report
local r = {}
local function add(s) table.insert(r, s) end
local function fmt(...) add(string.format(...)) end
local function pad(s, n)
    s = tostring(s)
    while #s < n do s = s .. " " end
    return s
end

add("items " .. #items .. ", footprints " .. count .. ", bags " .. bags)
local parts = {}
for _, k in ipairs(sortedKeys(hows)) do table.insert(parts, k .. "=" .. hows[k]) end
add("how: " .. table.concat(parts, ", "))
add("")
add("DISTRIBUTION")
for _, k in ipairs(sortedKeys(dist, true)) do
    fmt("%s %5d  %5.1f%%", pad(k, 5), dist[k], 100 * dist[k] / count)
end
add("")
add("BY KIND")
for _, kind in ipairs(sortedKeys(byKind)) do
    local line = {pad(kind, 11)}
    local keys = sortedKeys(byKind[kind], true)
    for i = 1, math.min(8, #keys) do table.insert(line, keys[i] .. ":" .. byKind[kind][keys[i]]) end
    add(table.concat(line, " "))
end
add("")
add("CLOTHING LOCATIONS NOT IN THE TABLE (they go by model or weight)")
for _, k in ipairs(sortedKeys(unknownWorn, true)) do add("  " .. pad(k == "" and "(none)" or k, 28) .. unknownWorn[k]) end

local function sample(title, names)
    add("")
    add(title)
    for name in string.gmatch(names, "%S+") do
        local f = byId["Base." .. name]
        if not f then
            add("  " .. pad(name, 30) .. "-")
        elseif not f.w then
            add("  " .. pad(name, 30) .. "(in game, by weight)")
        else
            local d = f.dims and string.format("%.2f %.2f %.2f", f.dims[1], f.dims[2], f.dims[3]) or ""
            fmt("  %s %5.2f kg  %dx%d  x%-3d %-6s %s", pad(name, 30), f.weight, f.w, f.h, f.stack, f.how, d)
        end
    end
end

sample("WEAPONS", "BaseballBat Crowbar Axe WoodAxe HandAxe Hammer Sledgehammer Machete Katana KitchenKnife HuntingKnife "
    .. "Screwdriver Pistol Pistol2 Revolver Revolver_Long Shotgun DoubleBarrelShotgun ShotgunSawnoff HuntingRifle "
    .. "VarmintRifle AssaultRifle AssaultRifle2 SpearCrafted Plank Golfclub Shovel Rake GardenHoe Pickaxe Saw "
    .. "Wrench PipeWrench Pan FryingPan RollingPin TennisRacket Poolcue Nightstick Stone2 Scalpel Fork "
    .. "GuitarAcoustic GuitarElectric Violin Saxophone Trumpet Flute Banjo Keytar Scythe UmbrellaBlack")
sample("FOOD AND DRINK", "TinnedBeans CannedCorn CannedSoup Crisps Cereal Bread Apple Banana Watermelon Pumpkin "
    .. "Cabbage Steak Chicken Salmon Bass Pike Egg Milk WaterBottle PopBottle Pop BeerBottle BeerCan Whiskey Wine "
    .. "Flour2 Rice Sugar Butter Cheese Chocolate Pizza Burger Icecream PeanutButter Honey Coffee2 Teabag2 "
    .. "DogfoodCan WaterDispenserBottle BucketEmpty Pot Kettle Saucepan Bowl MugWhite")
sample("SMALL THINGS AND STACKS", "Nails NailsBox Screws ScrewsBox Bullets9mm Bullets9mmBox Bullets45 ShotgunShells "
    .. "ShotgunShellsBox 223Bullets 223Box 308Bullets 9mmClip Battery Bandage AlcoholWipes Pills PillsBeta Antibiotics "
    .. "Disinfectant Matches Lighter Money Key1 Thread Needle DuctTape Twine Sheet RippedSheets ToiletPaper "
    .. "Charcoal Candle Soap2 Paperclip Cigarettes CigarettePack Woodglue Glue Scotchtape Pencil Pen Notebook "
    .. "Book Magazine Newspaper Map ComicBook SheetPaper2 CreditCard Wallet IDcard Ring_Left_RingFinger_Gold "
    .. "Twigs Log Stone2 SheetMetal SmallSheetMetal MetalPipe MetalBar ScrapMetal Wire BarbedWire RopeStack Rope "
    .. "Pillow Tarp Sandbag Gravelbag Fertilizer ConcretePowder PlasterPowder BucketConcreteFull")
sample("TOOLS AND GEAR", "Hammer Saw Screwdriver Wrench Pliers Jack TirePump LugWrench BlowTorch WeldingMask "
    .. "HandTorch Torch FlashLight_AngleHead Radio WalkieTalkie1 HamRadio1 CarBattery1 Generator PropaneTank "
    .. "PetrolCan EmptyPetrolCan Extinguisher FirstAidKit Toolbox Tent_Tarp TentPeg SleepingBag_Packed "
    .. "FishingRod FishingTackle FishingNet Trowel HandShovel WateringCan GardeningSprayEmpty Mop Broom "
    .. "Plunger Sponge Scissors Tweezers SutureNeedle Splint CorpseMale Tire OldTire1 NormalTire1 "
    .. "EngineParts NormalCarMuffler1 CarSeat TV Laptop VideoGame CDplayer Earbuds Headphones Speaker Camera")
sample("CLOTHING", "Tshirt_DefaultTEXTURE Shirt_FormalWhite Jumper_RoundNeck HoodieUP_WhiteTINT Jacket_Padded "
    .. "Jacket_Fireman Jacket_ArmyCamoGreen Vest_BulletPolice Vest_Hunting_Orange Trousers_Denim Shorts_ShortDenim "
    .. "Skirt_Knees Dress_Normal Boilersuit Shoes_Black Shoes_ArmyBoots Socks_Ankle Hat_BaseballCap Hat_Beany "
    .. "Hat_Army Hat_GasMask Hat_CrashHelmet Gloves_LeatherGloves Belt2 Glasses_Normal Scarf_White "
    .. "HazmatSuit Ghillie_Top Tie_Full Necklace_Gold WristWatch_Left_DigitalBlack")

add("")
add("BAGS (capacity, how worn -> grid, cells per capacity unit; outer size)")
local seen = {}
for _, id in ipairs(ids) do
    local f = byId[id]
    if f.cols then
        local key = f.capacity .. "|" .. f.worn .. "|" .. f.cols .. "x" .. f.rows .. "|" .. f.w .. "x" .. f.h
            .. "|" .. (f.dims and string.format("%.2f", f.dims[1]) or "")
        if not seen[key] then
            seen[key] = true
            fmt("  %s cap %4.1f  %s grid %dx%-2d = %3d (%.2f)  outer %dx%d%s", pad(string.gsub(id, "^Base%.", ""), 36), f.capacity,
                pad(f.worn, 16), f.cols, f.rows, f.cols * f.rows, f.cols * f.rows / f.capacity, f.w, f.h,
                f.capacity <= F.NEST_CAPACITY and "  organizer" or "")
        end
    end
end

-- balance: typical loads against each bag
local kits = {
    {"food for a week", "TinnedBeans*14", "Crisps*6", "Cereal*4", "Bread*2", "WaterBottle*4"},
    {"tools", "Hammer", "Saw", "Screwdriver", "Wrench", "Crowbar", "Pliers", "NailsBox", "Nails*100", "DuctTape*2",
     "Woodglue", "Jack", "TirePump", "LugWrench"},
    {"guns and ammo", "Shotgun", "Pistol", "Bullets9mmBox*4", "ShotgunShellsBox*4", "9mmClip*3", "BaseballBat", "HuntingKnife"},
    {"wardrobe", "Tshirt_DefaultTEXTURE*3", "Trousers_Denim*2", "Jacket_Padded", "Shoes_ArmyBoots", "Socks_Ankle*3", "Hat_Beany"},
    {"medical", "Bandage*10", "AlcoholWipes*4", "Pills*3", "Antibiotics*2", "FirstAidKit", "Disinfectant*2"},
    {"mixed loot run", "TinnedBeans*6", "WaterBottle*2", "Hammer", "Screwdriver", "Book*2", "Tshirt_DefaultTEXTURE*2",
     "Pistol", "Bullets9mmBox*2", "Bandage*5", "Battery*4", "HandTorch"},
    {"pockets", "Pistol", "9mmClip*2", "Lighter", "Cigarettes", "Key1*3", "Wallet", "Bandage*3", "HuntingKnife", "WaterBottle"},
}
local simBags = {"Bag_FannyPackFront", "Purse", "Lunchbox", "Toolbox", "Plasticbag", "Bag_Satchel", "Bag_Schoolbag",
                 "Suitcase", "Bag_DuffelBag", "Bag_NormalHikingBag", "Bag_BigHikingBag", "Bag_ALICEpack"}
add("")
add("KITS: weight, cells of its tiles, longest side; per bag: weight % of capacity | cells % of the grid ('!' = the longest thing doesn't fit)")
for _, kit in ipairs(kits) do
    local kg, cells, longest, miss = 0, 0, 0, {}
    for i = 2, #kit do
        local name, n = kit[i], 1
        local star = string.find(name, "*", 1, true)
        if star then name, n = string.sub(name, 1, star - 1), tonumber(string.sub(name, star + 1)) end
        local f = byId["Base." .. name]
        if not f or not f.w then
            table.insert(miss, name)
        else
            kg = kg + f.weight * n
            cells = cells + math.ceil(n / f.stack) * f.w * f.h
            longest = math.max(longest, f.h)
        end
    end
    add("")
    fmt("%s %5.1f kg  %3d cells  longest %d%s", pad(kit[1], 16), kg, cells, longest,
        #miss > 0 and ("  (not found: " .. table.concat(miss, " ") .. ")") or "")
    fmt("  %s        |  pockets: %3.0f%% of 8, %3.0f%% of 12, %3.0f%% of 16 cells", pad("", 22), 100 * cells / 8, 100 * cells / 12, 100 * cells / 16)
    for _, name in ipairs(simBags) do
        local b = byId["Base." .. name]
        if b and b.cols then
            fmt("  %s %4.0f%% | %4.0f%%%s", pad(name, 22), 100 * kg / b.capacity, 100 * cells / (b.cols * b.rows),
                longest <= math.max(b.cols, b.rows) and "" or " !")
        end
    end
end

add("")
add("ALL (id | kind | weight | how | footprint | stack | sides in cells)")
for _, f in ipairs(items) do
    add(table.concat({f.id, f.kind, string.format("%.2f", f.weight), f.how or "runtime",
        f.w and (f.w .. "x" .. f.h) or "-", f.stack or "-",
        f.dims and string.format("%.2f %.2f %.2f", f.dims[1], f.dims[2], f.dims[3]) or ""}, "|"))
end
writefile(report, table.concat(r, "\r\n"))
print("footprints " .. count .. " of " .. #items .. ", bags " .. bags .. " -> " .. out)
