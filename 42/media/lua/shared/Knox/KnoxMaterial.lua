-- What a thing is made of, for how it sounds (KnoxSearchSound, KnoxUISound): one of
-- the materials below for every item of the game and of mods. Asked for by the
-- author, 2026-10-17, after toilet paper sounded like a book: the first rules went
-- by words in the item's name ("Paper").
--
-- Decided from the item's script, the same fields in the game (M.infoOf: the
-- item's getScriptItem) and in the review tool outside it (tools\material: every
-- item of the game's scripts, report.txt grouped by material). First match wins:
--   the player's own line (knox_overrides.txt: `Base.ToiletPaper = sound softpaper`),
--   M.FIX (things the rules get wrong, found in the report),
--   tags (glass, cans, books, magazines, ammo, metal), what a vessel is made of
--   (FillFromTapSound: glass, ceramic, metal, plastic), the 3D model's name (a
--   can, a jar, a bottle, a box), the kind of item (clothes by fabric, food by
--   type, books), then the category, and words in the name last.

KnoxMaterial = KnoxMaterial or {}
local M = KnoxMaterial

-- the materials, and the game's own sound each uses until Knox has sounds of its own
-- (every one of them measured in the game's bank and levelled: KnoxSoundLevelData.lua)
M.LIST = {
    softpaper   = {sound = "StoreItemFabricPouch"},     -- toilet paper, tissues, cotton
    paper       = {sound = "PageFlipMagazine"},         -- sheets, notes, money, maps, newspapers, seed packets
    magazine    = {sound = "PageFlipMagazine"},
    book        = {sound = "CloseBook"},
    cardboard   = {sound = "StoreItemParcelSmall"},     -- boxes, cartons, packs
    cloth       = {sound = "StoreItemFabricPouch"},     -- clothes, rags, sheets, bandages, rope
    leather     = {sound = "StoreItemLeatherBag"},
    shoes       = {sound = "StoreItemLeatherBag"},
    tin         = {sound = "StoreItemSmallMetalBox"},   -- cans, tins, small metal boxes
    metalsmall  = {sound = "StoreItemBulletsBandolier"},-- nails, screws, lids, clips, coins
    metal       = {sound = "StoreItemMetalToolbox"},    -- tools, pots, parts, weapons
    jewelry     = {sound = "StoreItemKeyRing"},         -- rings, chains, watches
    keys        = {sound = "StoreItemKeyRing"},
    glass       = {sound = "WaterDispenserAddBottle"},  -- bottles, jars
    ceramic     = {sound = "StoreItemCookieJar"},       -- mugs, bowls, plates
    plastic     = {sound = "StoreItemMediumPlasticBox"},-- hard plastic: electronics, bottles, tubes
    plasticsoft = {sound = "StoreItemPlasticBag"},      -- wrappers, packets, bags of snacks
    pills       = {sound = "StoreItemPencilCase"},
    ammo        = {sound = "StoreItemBulletsBandolier"},
    wood        = {sound = "StoreItemSmallWoodenBox"},
    stone       = {sound = "StoreItemSmallWoodenBox"},
    -- (not ForagingPickup: plants rustling, and its event is raised inside the game -
    -- measured quiet, it came out far too loud: the author, 2026-10-17)
    food        = {sound = "StoreItemSack"},            -- fresh: produce, meat, fish
    fooddry     = {sound = "StoreItemPaperBag"},        -- bread, baked things
    misc        = {sound = "StoreItemFabricPouch"},
}

-- things the rules get wrong (from tools\material\report.txt, read through 2026-10-17)
M.FIX = {}
for mat, list in pairs({
    metal = {"Extinguisher", "Bell", "UnusableMetal", "GrillBrush", "Lantern_Hurricane", "Lantern_HurricaneLit",
             "Lantern_Hurricane_Copper", "Lantern_Hurricane_CopperLit", "Lantern_Hurricane_Forged", "Lantern_Hurricane_ForgedLit",
             "Lantern_Hurricane_Gold", "Lantern_Hurricane_GoldLit", "Lantern_Hurricane_Silver", "Lantern_Hurricane_SilverLit",
             "Lantern_Propane", "Propane_Refill", "HotDrinkCopper", "HotDrinkGold", "HotDrinkSilver", "HotDrinkMetal",
             "Mov_TowelDispenser"},
    metalsmall = {"Forceps_Forged", "Tweezers", "Tweezers_Forged", "SutureNeedle", "SutureNeedleHolder", "KnittingNeedles",
                  "Needle", "Needle_Brass", "Needle_Forged", "ScissorsBlunt", "ScissorsBluntMedical"},
    tin = {"PaintBlack", "PaintBlue", "PaintBrown", "PaintCyan", "PaintGreen", "PaintGrey", "PaintLightBlue", "PaintLightBrown",
           "PaintOrange", "PaintPink", "PaintPurple", "PaintRed", "PaintTurquoise", "PaintWhite", "PaintYellow", "BeerPack"},
    ceramic = {"Plate", "TestMug", "HotDrink", "HotDrinkClay", "HotDrinkRed", "HotDrinkSpiffo", "HotDrinkTea", "HotDrinkTeaCeramic",
               "HotDrinkWhite", "TestHotDrink", "Mov_FancyToilet", "Mov_CastIronPlant", "MortarPestle"},
    glass = {"Mirror", "Cologne", "Perfume", "HotDrinkTumbler", "MilkBottle", "Bitters", "SimpleSyrup", "Vinegar2"},
    wood = {"Frame", "Chopsticks", "Cork", "Pinecone", "Splinters", "Clipboard", "ChessBlack", "ChessWhite", "Splint",
            "TongueDepressor", "SmokingPipe", "SmokingPipeUnfired", "Brush", "Paintbrush", "PaintbrushCrafted"},
    stone = {"Whetstone", "CrudeWhetstone", "KnappingTool"},
    book = {"Book_Prop", "BookFancy_Prop", "BookTrappingSet", "BookFlintKnappingSet"},
    -- (cartons and mixes: not of the food kind, so not seen by the food rules)
    cardboard = {"CigarettePack", "JuiceCranberry", "JuiceFruitpunch", "JuiceGrape", "JuiceLemon", "JuiceOrange", "JuiceTomato",
                 "Milk_Personalsized", "MilkChocolate_Personalsized", "PancakeMix", "GravyMix", "CakeBatter", "PieDough"},
    plasticsoft = {"Sponge", "Toothpaste", "TobaccoChewing", "TobaccoLoose", "Coldpack"},
    softpaper = {"AlcoholWipes", "Bandaid", "TobaccoDried"},
    cloth = {"Doily", "OvenMitt", "DryerLint", "NormalCarSeat1", "NormalCarSeat2", "NormalCarSeat3", "VanSeatsTrunk2"},
    plastic = {"KnapsackSprayer", "KnapsackSprayer_Stowed", "Zipties", "Funnel", "LightbarBlue", "LightbarRed", "LightbarRedBlue",
               "LightbarYellow", "TirePump", "MotionSensor", "RemoteCraftedV1", "RemoteCraftedV2", "RemoteCraftedV3",
               "Vinegar_Jug", "RespiratorFilters", "RespiratorFiltersRecharged"},
    food = {"ComfreyCataplasm", "PlantainCataplasm", "WildGarlicCataplasm"},
}) do
    for _, n in ipairs(list) do M.FIX["Base." .. n] = mat end
end

local function has(s, ...)
    if not s or s == "" then return false end
    for _, w in ipairs({...}) do
        if string.find(s, w, 1, true) then return true end
    end
    return false
end

-- (as has, with Lua patterns: "Pot$" - a word at the end, not "Potato")
local function hasp(s, ...)
    if not s or s == "" then return false end
    for _, p in ipairs({...}) do
        if string.find(s, p) then return true end
    end
    return false
end

local FRESH = {Vegetables = true, Vegetable = true, Fruits = true, Berry = true, Meat = true, Poultry = true,
    Fish = true, Seafood = true, Beef = true, Game = true, Venison = true, Egg = true, Mushroom = true,
    Herb = true, Greens = true, Insect = true, Citrus = true, HotPepper = true, Sausage = true, Bacon = true,
    Cheese = true, Roe = true}

--- The material of a thing from its script's fields (see the head of the file).
--- info: {ft, type, cat, weight, tags = {name = true}, fabric, world, static, drop,
---        placeOne, tap, body, foodType, packaged, eatType, fluid}
--- @return string material, string why
function M.classify(info)
    local ft = info.ft or ""
    local name = string.match(ft, "%.(.+)$") or ft
    local tags = info.tags or {}
    local ty = info.type or ""
    local cat = info.cat or ""
    -- (a model's name with or without its module: "Base.BowlRice_Ground" in the game,
    -- "BowlRice_Ground" in the scripts - the rules read it bare)
    local function bare(m) return (string.gsub(m or "", "^[%w_]+%.", "")) end
    local model = bare(info.world) .. " " .. bare(info.static)
    local w = tonumber(info.weight) or 0.1
    local fix = M.FIX[ft]
    if fix then return fix, "fix" end

    if ty == "key" then return "keys", "key" end
    -- tags and what a vessel is made of
    if tags.glass or tags.glassbottle or tags.glassbottlesmall or tags.jar then return "glass", "tag glass" end
    local tap = info.tap or ""
    if has(tap, "Glass") then return "glass", "vessel glass" end
    if has(tap, "Ceramic") then return "ceramic", "vessel ceramic" end
    if has(tap, "Metal") then
        if tags.sealedbeveragecan or tags.emptycan or has(model, "Can") then return "tin", "vessel can" end
        if w > 0.6 then return "metal", "vessel metal, heavy" end
        return "tin", "vessel metal"
    end
    if has(tap, "Plastic") then return "plastic", "vessel plastic" end
    if tags.sealedbeveragecan or tags.emptycan then return "tin", "tag can" end
    if has(name, "Corpse") then return "cloth", "a body" end
    if tags.ammocase or cat == "Ammo" or (info.placeOne or "") ~= "" then return "ammo", "ammo" end

    -- books and papers
    if tags.magazine then return "magazine", "tag magazine" end
    if tags.softcover or tags.hardcover or tags.fancybook or tags.picturebook or tags.hollowbook then return "book", "tag book" end
    if has(name, "ToiletPaper", "Tissue", "Napkin", "PaperTowel", "CottonBall") and not has(name, "Dispenser") then
        return "softpaper", "name soft paper"
    end
    if ty == "literature" or ty == "map" then
        if has(name, "Journal", "Diary", "Book", "Bible", "Notebook", "Album") then return "book", "name book" end
        if has(model, "Book") then return "book", "model book" end
        return "paper", "literature"
    end
    if tags.newspaper or (tags.isseed and has(name, "Seed")) then return "paper", "tag paper" end

    -- what is worn
    if ty == "clothing" or ty == "alarmclockclothing" then
        if ty == "alarmclockclothing" or has(name, "Ring_", "Necklace", "Earring", "Bracelet", "NoseRing", "NoseStud", "BellyButton", "Locket", "WristWatch") then
            return "jewelry", "jewelry"
        end
        if has(name, "Medal") then return "jewelry", "medal" end
        if has(name, "Bone") then return "stone", "worn bone" end
        if has(name, "GreaveWood", "VambraceWood") then return "wood", "worn wood" end
        if has(name, "GreaveMagazine", "VambraceMagazine") then return "magazine", "worn magazines" end
        if has(name, "Chainmail", "CanteenCowboy", "WeldingMask") then return "metal", "worn metal (2)" end
        if has(name, "Greave", "Vambrace", "Helmet", "HockeyMask_Metal", "HockeyMask_Gold", "HockeyMask_Silver", "HockeyMask_Copper", "Hat_ArmyWWII", "Cuirass", "Gorget") and tags.hasmetal then
            return "metal", "worn metal"
        end
        if tags.hasmetal and has(name, "Spike", "Metal") then return "metal", "worn metal (3)" end
        if has(name, "BodyArmour", "Shinpad", "ShinKneeGuard", "AthleticCup", "NeckGuard", "SCBA", "Hazmat", "Sprayer") then
            return "plastic", "worn hard plastic"
        end
        if (info.fabric == "Leather" or tags.ripclothingleather or has(name, "Belt", "Holster_Hide", "Hide", "Leather")) and not has(name, "RopeBelt") then
            return "leather", "fabric leather"
        end
        local body = info.body or ""
        if has(body, "Shoes") or has(name, "Shoes", "Boots", "Sneakers", "Slippers") then return "shoes", "footwear" end
        if tags.hasmetal and w > 0.5 then return "metal", "worn metal" end
        return "cloth", "clothing"
    end
    if ty == "container" then
        if has(name, "KeyRing") then return "keys", "key ring" end
        if info.fabric == "Leather" or has(name, "Leather", "Hide", "Wallet", "Briefcase", "Purse", "Holster") then return "leather", "bag leather" end
        if has(name, "Plasticbag", "Garbagebag", "GroceryBag", "TrashBag", "Tarp") then return "plasticsoft", "bag plastic" end
        if has(name, "Parcel", "Cardboard", "ProduceBox", "Takeout", "PaperBag", "Paperbag", "Present", "Shoebox", "Hatbox") then
            return "cardboard", "parcel or carton"
        end
        if has(name, "PhotoAlbum") then return "book", "album" end
        if has(name, "CookieJar") then return "ceramic", "cookie jar" end
        if has(name, "Toolbox_Wooden", "Humidor", "CigarBox", "JewelleryBox", "Basket", "Crate") then return "wood", "box or basket" end
        if has(name, "Toolbox", "Cashbox", "Lunchbox", "AmmoBox", "Tacklebox", "Canteen") then return "metal", "metal box" end
        if has(name, "ProtectiveCase", "Cooler", "FirstAidKit", "Flightcase", "Guitarcase", "PistolCase", "RevolverCase", "RifleCase",
               "ShotgunCase", "Suitcase", "MakeupCase", "PencilCase", "SewingKit", "CandyBucket", "Lunchbag", "Case") and not has(name, "Cloth") then
            return "plastic", "hard case"
        end
        return "cloth", "bag"
    end

    -- food
    if ty == "food" then
        -- (cooked in a pot, a pan, a tray: the vessel is what is heard)
        if hasp(name, "Pot$", "PotOf", "PotForged", "PastaPot", "RicePot", "WaterPot", "Pan$", "PanFried", "PastaPan", "RicePan",
                "Saucepan", "Griddle", "Tray", "^Bucket") then
            return "metal", "food in a pot"
        end
        if tags.hasmetal or has(model, "CanClosed", "CanOpen", "Tinned", "TinCan") then return "tin", "food in a can" end
        if has(model, "Jar") then return "glass", "food in a jar" end
        if has(model, "Bottle") then return "glass", "food in a bottle" end
        if has(model, "Box", "Carton") then return "cardboard", "food in a box" end
        if info.packaged or has(model, "Chips", "Bag", "Wrapper", "Packet") or info.foodType == "Candy" then
            return "plasticsoft", "food packaged"
        end
        if has(name, "Hemp", "Flax") then return "cloth", "fibre" end
        -- (a bowl by its model too: "Bowl - Oatmeal" is Base.Oatmeal; the author, 2026-10-17)
        if (has(name, "Bowl") and not has(name, "Bowling")) or hasp(model, "^Bowl", "Salad_Ground") then return "ceramic", "food in a bowl" end
        if has(name, "Seasoning", "Powdered", "cheese_powdered") or hasp(name, "^Pepper$") then return "plastic", "spice shaker" end
        if hasp(name, "^Oil", "Oil$") then return "glass", "oil bottle" end
        if has(name, "Butter", "Margarine") and not has(name, "Peanut") then return "plasticsoft", "wrapped" end
        if hasp(name, "^Salt$", "^Sugar$", "SugarBrown", "^Flour", "Cornmeal", "Cornflour", "Yeast") then return "cardboard", "food in a paper sack" end
        if has(name, "Antibiotics") then return "pills", "pills (food)" end
        if has(name, "GranolaBar", "Lollipop", "Gum") then return "plasticsoft", "wrapped" end
        if has(name, "CanPipe") then return "metal", "can pipe" end
        if has(name, "SmokingPipe") then return "wood", "pipe" end
        if info.foodType == "Bread" or has(name, "Bread", "Buns", "Bagel", "Muffin", "Cookie", "Cracker", "Biscuit", "Cake", "Pie", "Toast", "Croissant") then
            return "fooddry", "baked"
        end
        if has(name, "Cigarette", "Cigar") then return "softpaper", "cigarette" end
        return "food", "food"
    end

    -- furniture carried as a thing (the game's moveables): by what it is. (The
    -- category "Furniture" holds hides, tents and ores too: those first.)
    if ty == "moveable" or cat == "Furniture" then
        if has(name, "Leather", "Hide", "Pelt") and not has(name, "Tent") then return "leather", "hide" end
        if has(name, "SleepingBag", "Tent", "Cot", "Futon", "Flag", "GymnMat", "Scarecrow", "Haystack") then return "cloth", "furniture cloth" end
        if has(name, "Hematite", "Malachite", "Grave", "SaltLick") then return "stone", "furniture stone (2)" end
        if has(name, "Anvil", "Vault", "Hydrant", "Barrier", "Sign", "Toaster", "Fryer", "Espresso", "CoffeeMaker", "Hood", "Gurney",
               "Microscope", "Projector", "Duplicator", "Satellite", "Terminal", "Monitor", "Urinal", "Shower", "Chrome", "Jukebox",
               "Amplifier", "Microphone", "Fitness", "Forge", "Barrel", "Folding", "Scale", "ShoppingBasket", "FileCabinet",
               "CabinetMedical", "CabinetTool", "FirstAidCabinet") then
            return "metal", "furniture metal (2)"
        end
        if has(name, "Cone", "Flamingo", "Mannequin", "Skeleton", "Bloodbag", "OfficeChair", "Neon") then return "plastic", "furniture plastic (2)" end
        if has(name, "Poster", "MapUSA") then return "paper", "poster" end
        if has(name, "Window") then return "glass", "window" end
        if has(name, "Cardboard") then return "cardboard", "furniture cardboard" end
        if has(name, "Painting", "Plantbed", "Planter") and not has(name, "Brick") then return "wood", "furniture wood" end
        if has(name, "Curtain", "Mattress", "Pillow", "Rug", "Blanket", "Comfy", "Sofa", "Couch", "Bed", "Cushion", "Towel") then return "cloth", "furniture soft" end
        if has(name, "Fridge", "Freezer", "Stove", "Oven", "Washer", "Dryer", "Dishwasher", "Microwave", "Locker", "Metal", "Drum",
               "BBQ", "Grill", "Grinder", "AirConditioner", "Brazier", "Radiator", "Mailbox", "MailBox", "CashRegister", "Arcade", "Machine",
               "Toolbox", "ToolChest", "Safe", "Vending", "Steel", "Generator", "Heater", "CeilingFan", "Bell", "Mixer", "Dispenser") then
            if not has(name, "Fancy") or has(name, "Fridge", "Oven", "Stove") then return "metal", "furniture metal" end
        end
        if has(name, "Phone", "Speaker", "TV", "Television", "Radio", "Lamp", "Light", "Computer", "Plastic", "Bin", "Toilet", "Sink", "Clock") then
            return "plastic", "furniture plastic"
        end
        if has(name, "Skull", "Antler", "Bone") then return "stone", "bone" end
        if has(name, "Brick", "Concrete", "Stone") then return "stone", "furniture stone" end
        if has(name, "Plant", "Cactus", "Ficus", "Fern", "Bonsai", "Tree", "Flower", "Pot", "Vase", "Birdbath", "Statue", "Gnome") then
            return "ceramic", "furniture pot"
        end
        if has(name, "Mirror", "Glass", "Aquarium") then return "glass", "furniture glass" end
        return "wood", "furniture"
    end

    -- the 3D model's name
    if has(name, "Trophy") then return "metal", "trophy" end
    if has(name, "ClayJar", "ClayPot") then return "ceramic", "clay pot" end
    if has(name, "JarLid") then return "metalsmall", "lid" end
    if has(name, "Spray") then return "plastic", "name sprayer" end
    if has(name, "VHS", "Bricktoys") then return "plastic", "tape or toy" end
    if has(model, "Jar") then return "glass", "model jar" end
    if has(model, "PillBottle", "PainKillers", "Pills") or has(name, "Pills", "Vitamins", "Antibiotics", "Antidep", "BetaBlock") then
        return "pills", "pills"
    end
    if has(model, "Box", "Carton") and not has(model, "Toolbox", "Lunchbox", "Matchbox") then return "cardboard", "model box" end
    if has(name, "Cigarettes", "Matches", "Box") and not tags.hasmetal then return "cardboard", "name box" end
    if has(name, "LetterOpener") then return "metal", "letter opener" end
    if has(name, "Paperclip") then return "metalsmall", "paperclip" end
    if has(name, "CreditCard", "Plastic", "Woodglue") then return "plastic", "name plastic (3)" end
    if has(name, "Money", "Paper", "Card", "Photo", "Letter", "Note", "Envelope", "Receipt", "Ticket", "Postcard", "Flier", "Brochure", "Label", "Sticker", "Wrapping") then
        return "paper", "name paper"
    end

    -- cloth, wood, stone, metal
    if tags.binding or tags.rope or tags.sheet or tags.twine or has(name, "Rag", "Sheet", "Bandage", "Gauze", "Thread", "Yarn", "Fabric", "Twine", "Rope", "String", "Towel", "Denim", "Leather", "Fur", "Wool") then
        if has(name, "Leather", "Fur", "Hide", "Pelt") then return "leather", "name leather" end
        if has(name, "SheetMetal", "MetalSheet", "CopperSheet", "GoldSheet", "SilverSheet", "ScrapSheet") then return "metal", "sheet metal" end
        if has(name, "SheetMold") then return "stone", "clay mould" end
        if has(name, "SteelWool") then return "metalsmall", "steel wool" end
        return "cloth", "fabric"
    end
    if has(name, "Stone", "Rock", "Brick", "Concrete", "Gravel", "Flint", "Clay") and not tags.hasmetal then return "stone", "name stone" end
    if tags.hasmetal then
        if w <= 0.15 then return "metalsmall", "metal, small" end
        return "metal", "metal"
    end
    if tags.woodhandle or tags.log or has(name, "Plank", "Log", "Stick", "Branch", "Twig", "Wood", "Board", "Stake") then return "wood", "wood" end

    -- things with little else to tell by but their name
    if has(name, "Ceramic", "Teacup", "Crucible") then return "ceramic", "name ceramic" end
    if has(name, "Hide", "Pelt", "Leather", "BrainTan", "Tanned") then return "leather", "name hide" end
    if has(name, "HoodOrnament") then return "metal", "hood ornament" end
    if has(name, "PenSpiffo", "PencilSpiffo") then return "plastic", "pen" end
    if has(model, "Plush", "Pancho") or has(name, "Spiffo", "Plush", "Bunny", "Badger", "Beaver", "Hedgehog", "MoleyMole", "Goblin", "FreddyFox") then
        return "cloth", "plush toy"
    end
    if has(model, "CanOpen", "CanClosed", "DentedCan", "MysteryCan", "RationCan", "TinCan", "Tinned") then return "tin", "model can" end
    if has(name, "Wallpaper", "CapGunCap", "ChristmasHanging") then return "paper", "name paper (3)" end
    if has(name, "Tarp", "TirePiece", "FishingTrash", "DogChew", "PotScrubber", "Rubber") then return "plasticsoft", "name soft plastic" end
    if has(name, "Sandbag", "Dirtbag", "Gunny", "Sack") then return "cloth", "name sack" end
    if has(name, "Powder", "Quicklime", "Package", "Matchbox", "_box") then return "cardboard", "name paper sack or box" end
    if has(name, "Limestone") then return "stone", "name limestone" end
    if has(name, "ScrapMetal", "WeldingRod", "Rods") then return "metal", "name scrap" end
    if has(name, "LanternGlass", "SnowGlobe") then return "glass", "name glass (2)" end
    if has(name, "Button", "Disc", "GuitarPick", "Yoyo", "Scotchtape") then return "plastic", "name plastic (2)" end
    if has(name, "HobbyHorse") then return "wood", "name wood (2)" end
    if has(name, "Pen", "Pencil", "Marker", "Crayon") and not has(name, "Pendant", "Penknife") then return "plastic", "pen" end
    if cat == "WeaponPart" then
        if has(name, "RecoilPad") then return "plastic", "recoil pad" end
        if has(name, "Strap") then return "cloth", "strap" end
        return "metal", "weapon part"
    end
    if string.find(cat, "Weapon", 1, true) then
        if has(name, "hammer", "Hammer", "Axe", "Shovel", "Puller", "Gaff", "Spike", "Scope", "Sight", "Laser", "Light", "Choke", "RedDot") then
            return "metal", "weapon metal (2)"
        end
        if has(name, "Fork", "Spoon", "Knife", "Shiv", "Sawblade", "Scythe", "Hook", "BarBell", "DumbBell", "Hatchet") and not has(name, "Bone", "Jawbone") then
            return "metal", "weapon metal"
        end
        if has(name, "Bone", "Jawbone") then return "stone", "weapon bone" end
        if has(name, "Racket") then return "plastic", "racket" end
        return "wood", "weapon wood"
    end
    local lname = string.lower(name)
    if string.find(lname, "ball", 1, true) then return "plastic", "ball" end
    if cat == "Frog" or cat == "Spider" or cat == "Duck" or cat == "Bug" or cat == "Eye" then return "plasticsoft", "toy" end
    if has(name, "Flax", "Hemp", "Burlap", "Cloth", "Floss", "Dogbane", "Jute", "Net", "Line", "SleepingBag", "Tent", "Snare", "Doll", "Pillow", "Toy") then
        return "cloth", "name cloth"
    end
    if has(name, "Charcoal", "Coke", "Hematite", "Ore", "Bead", "Crystal", "Diamond", "Emerald", "Amethyst", "Ruby", "Sapphire", "Gem", "Skull", "Bone", "Mold") then
        return "stone", "name stone or bone"
    end
    if has(name, "Ornament", "Molotov") then return "glass", "name glass" end
    if has(name, "Aerosol", "SmokeBomb", "SprayCan", "SprayPaint", "WateringCan", "WateredCan") then return "tin", "name spray can" end
    if has(name, "Spray") then return "plastic", "name sprayer" end
    if string.find(name, "Pic$") or has(name, "Firecracker", "Wrapping", "Seed") then return "paper", "name paper (2)" end
    if has(name, "Bag", "Compost", "Fertilizer", "Wreath", "HotWaterBottle") then return "plasticsoft", "name soft bag" end
    if has(name, "Bucket", "Drawer", "Firewood", "Barricade", "Crate", "Spear", "Cudgel", "TrapMouse", "Firestarter") then return "wood", "name wood" end
    if has(name, "Hook", "Buckle", "Dart", "Tablets") then
        if has(name, "Tablets") then return "pills", "name tablets" end
        return "metalsmall", "name small metal"
    end
    if has(name, "Pipe", "Bomb", "Trap", "Cage", "Sensor", "Remote", "Maul") then return "metal", "name metal" end
    if has(name, "Pen", "Pencil", "Marker", "Crayon", "Ball", "Birdie", "Tee", "Dice", "Cube", "Bobber", "Lure", "Spork", "Tape", "Glue", "Epoxy", "Dye", "Repellent", "bottle") then
        return "plastic", "name plastic"
    end

    -- the kind of thing
    if cat == "Electronics" or cat == "Communications" or cat == "LightSource" or ty == "radio" or ty == "alarmclock" then
        return "plastic", "electronics"
    end
    if cat == "Bandage" or cat == "Wound" then return "cloth", "first aid cloth" end
    if cat == "FirstAid" then return "plastic", "first aid" end
    if cat == "Appearance" or cat == "Household" or cat == "Junk" or cat == "Paint" or cat == "Cooking" then return "plastic", "household" end
    if cat == "Food" then return "food", "food (category)" end
    if cat == "Clothing" or cat == "Accessory" then return "cloth", "clothing (category)" end
    if cat == "Tool" or cat == "ToolWeapon" or cat == "VehicleMaintenance" or cat == "WeaponPart" then return "metal", "tool" end
    if cat == "Literature" or cat == "SkillBook" then return "book", "literature (category)" end
    if cat == "Material" then return "misc", "material" end
    if cat == "AnimalPart" or cat == "AnimalPartWeapon" then return "food", "animal part" end
    return "misc", "nothing known"
end

-- In the game ---------------------------------------------------------------------

local function str(v)
    if v == nil then return nil end
    local s = tostring(v)
    s = string.gsub(s, "^%w+:", "")   -- ("base:food" -> "food")
    return s
end

--- The fields classify asks for, from a thing in the game.
function M.infoOf(item)
    local info = {ft = item:getFullType(), tags = {}}
    local sc = item:getScriptItem()
    if not sc then return info end
    info.type = string.lower(str(sc:getItemType()) or "")
    info.cat = sc:getDisplayCategory()
    info.weight = sc:getActualWeight()
    info.fabric = sc:getFabricType()
    info.world = sc:getWorldStaticModel()
    info.static = sc:getStaticModel()
    info.drop = sc:getDropSound()
    info.placeOne = sc:getPlaceOneSound()
    info.tap = sc:getFillFromTapSound()
    info.body = str(sc:getBodyLocation())
    info.eatType = sc:getEatType()
    local tags = sc:getTags()
    if tags then
        local it = tags:iterator()
        while it:hasNext() do info.tags[string.lower(str(it:next()) or "")] = true end
    end
    if instanceof(item, "Food") then
        info.foodType = item:getFoodType()
        info.packaged = item:isPackaged()
    end
    return info
end

local cache, cacheFor = {}, nil

--- The material of a thing in the game (cached by its type; anew when the
--- player's lines are read anew - the item editor's presets: KnoxPresets).
--- @return string material, string why
function M.of(item)
    if not item then return "misc", "no item" end
    local ft = item:getFullType()
    local overrides = KnoxFootprint and KnoxFootprint.overrides
    if cacheFor ~= overrides then cache, cacheFor = {}, overrides end
    local c = cache[ft]
    if c then return c[1], c[2] end
    local o = overrides and overrides[ft]
    local mat, why
    if o and o.sound and M.LIST[o.sound] then
        mat, why = o.sound, "knox_overrides.txt"
    else
        local ok, info = pcall(M.infoOf, item)
        if ok then
            local ok2, m, w = pcall(M.classify, info)
            if ok2 then mat, why = m, w end
        end
    end
    mat, why = mat or "misc", why or "error"
    cache[ft] = {mat, why}
    return mat, why
end

--- The game's sound standing in for a material (until Knox has its own).
function M.soundOf(mat)
    local l = M.LIST[mat] or M.LIST.misc
    return l.sound
end

return KnoxMaterial
