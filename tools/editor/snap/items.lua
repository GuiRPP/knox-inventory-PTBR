-- the items of the news pictures: the game's own types, names (strings_<lang>.txt) and icons
local I = {
    {"Base.Bag_Schoolbag", "Backpack_Teal", kind = "CONTAINER", equip = "Back", cap = 15},
    {"Base.Bag_ALICEpack", "AliceBag", kind = "CONTAINER", equip = "Back", cap = 28},
    {"Base.Bag_BigHikingBag", "BigHiking_Green", kind = "CONTAINER", equip = "Back", cap = 26},
    {"Base.Bag_NormalHikingBag", "Hiking_Red", kind = "CONTAINER", equip = "Back", cap = 20},
    {"Base.Bag_DuffelBag", "Duffelbag", kind = "CONTAINER", equip = "Back", cap = 18},
    {"Base.Bag_Satchel", "Satchel_Leather", kind = "CONTAINER", equip = "SatchelLeft", cap = 8},
    {"Base.Bag_FannyPackFront", "FannyPack", kind = "CONTAINER", equip = "FannyPackFront", cap = 1},
    {"Base.Bag_ChestRig", "ChestRig", kind = "CONTAINER", equip = "Webbing", cap = 6},
    {"Base.Toolbox", "Toolbox", kind = "CONTAINER", cap = 10},
    {"Base.Bag_RifleCase", "RifleCase_HardGreen", kind = "CONTAINER", cap = 7},
    {"Base.Jacket_Padded", "JacketPadded_White", kind = "CLOTHING", worn = "JacketBulky"},
    {"Base.Jacket_Black", "JacketLeatherBlack", kind = "CLOTHING", worn = "Jacket"},
    {"Base.Jacket_WhiteTINT", "Jacket_White", kind = "CLOTHING", worn = "Jacket"},
    {"Base.Trousers_Denim", "TrousersDenimBlue", kind = "CLOTHING", worn = "Pants"},
    {"Base.Trousers_CamoGreen", "TrousersCamoGreen", kind = "CLOTHING", worn = "Pants"},
    {"Base.Vest_BulletArmy", "BulletVestCamo", kind = "CLOTHING", worn = "TorsoExtraVestBullet"},
    {"Base.Tshirt_ArmyGreen", "TshirtGeneric", kind = "CLOTHING", worn = "Tshirt"},
    {"Base.Hat_Beany", "BeanieGeneric", kind = "CLOTHING", worn = "Hat"},
    {"Base.Shoes_ArmyBoots", "BootsARmy", kind = "CLOTHING", worn = "Shoes"},
    {"Base.Axe", "Axe", kind = "WEAPON", cat = "Weapon", weapon = true},
    {"Base.Pistol", "HandGun3", kind = "WEAPON", cat = "Weapon", weapon = true},
    {"Base.Shotgun", "Firearm_PumpShotgun", kind = "WEAPON", cat = "Weapon", weapon = true},
    {"Base.BaseballBat", "BaseballBat", kind = "WEAPON", cat = "Weapon", weapon = true},
    {"Base.Bullets9mm", "PistolAmmo", cat = "Ammo"},
    {"Base.ShotgunShells", "ShotgunAmmo", cat = "Ammo"},
    {"Base.Nails", "Nails", cat = "Material"},
    {"Base.Plank", "Plank", cat = "Material"},
    {"Base.TinnedBeans", "Beans", kind = "FOOD", cat = "Food", food = true},
    {"Base.WaterBottle", "WaterBottle", kind = "FOOD", cat = "Food", food = true},
    {"Base.Bandage", "Bandage", cat = "FirstAid"},
    {"Base.Pills", "PillsPainkiller", cat = "FirstAid"},
    {"Base.Hammer", "Hammer", cat = "Tool", weapon = true},
    {"Base.Screwdriver", "Screwdriver", cat = "Tool"},
    {"Base.Book", "Book", kind = "LITERATURE", cat = "Literature"},
    {"Base.Key1", "Key1", kind = "KEY", cat = "Key"},
    {"Base.Pen", "Pen"},
    {"Base.Battery", "Battery"},
    {"TG.TacticalPack", "Backpack_Black", mod = "TacticalGear", kind = "CONTAINER", equip = "Back", cap = 22},
    {"TG.Vest", "BulletVestCamo", mod = "TacticalGear", kind = "CLOTHING", worn = "TorsoExtraVest"},
    {"TG.Knife", "HuntingKnife", mod = "TacticalGear", kind = "WEAPON", cat = "Weapon", weapon = true},
}
SCRIPTS, ICON = {}, {}
for _, d in ipairs(I) do
    d.ft, d.name = d[1], STR["item:" .. d[1]]
    ICON[d.ft] = "Item_" .. d[2]
    d[1], d[2] = nil, nil
    SCRIPTS[#SCRIPTS + 1] = d
end
