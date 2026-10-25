# Item and container icons for the mod's pictures (news, Workshop page), taken
# from the game's own files: its texture packs media\texturepacks\UI.pack and
# UI2.pack, read by java\tools\pack\PackExtract.java. Written to
# tools\art\gameicons\<our name>.png at the game's size (32x32), not shipped.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\game_icons.ps1

$ErrorActionPreference = "Stop"
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = Join-Path $env:USERPROFILE "Zomboid\tools\jdk-25\bin\java.exe"
$tool = Join-Path $PSScriptRoot '..\java\tools\pack\PackExtract.java'
$out = Join-Path $PSScriptRoot "art\gameicons"
$tmp = Join-Path $env:TEMP ("knox_icons_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force $out, $tmp | Out-Null

# (no key may be called "keys": $want.Keys would give its value, not the keys)
# our name -> the game's texture (the item scripts' Icon / IconsForTexture, "Item_" + it)
$want = [ordered]@{
    knife = "Item_KnifeChopping"; knife_pocket = "Item_KnifePocket"; pliers = "Item_Pliers"; book = "Item_Book"
    steak = "Item_Steak"; cucumber = "Item_Cucumber"; sausage = "Item_Sausage"; bottle = "Item_WaterBottle"
    chips = "Item_Crisps"; idcard = "Item_IDcard"; keyring = "Item_KeyRing"; jacket = "Item_JacketMediumBrown"
    hammer = "Item_Hammer"; bag_hiking = "Item_Hiking_Green"; bag_school = "Item_Backpack_Teal"
    c_counter = "Container_Counter"; c_dresser = "Container_Drawer"; c_shelves = "Container_Shelf"
    c_fridge = "Container_Fridge"; c_freezer = "Container_Freezer"; c_floor = "Container_Floor"
    c_trash = "Container_Garbage"; c_stove = "Container_Oven"; c_crate = "Container_Crate"
    c_microwave = "Container_Microwave"; c_pocket = "Container_Pocket"; c_trunk = "Container_CarTrunk"
    rifle = "Item_HuntingRifle"; pistol = "Item_HandGun"; shotgun = "Item_Shotgun"; bat = "Item_BaseballBat"
    beans = "Item_Beans"; nails = "Item_Nails"; screws = "Item_Screws"; ammo9 = "Item_PistolAmmo"; shells = "Item_ShotgunAmmo"
    battery = "Item_Battery"; bandage = "Item_Bandage"; pills = "Item_PillsPainkiller"; cassette = "Item_Cassette1"; disc = "Item_Disc"
    axe = "Item_Axe"; screwdriver = "Item_Screwdriver"; torch = "Item_Flashlight"; apple = "Item_Apple"
    radio = "Item_RadioBlack"; walkie = "Item_WalkieTalkieCivilian"; tv = "Item_Television"; headphones = "Item_Headphones"; microphone = "Item_Microphone"
    tshirt = "Item_TshirtGeneric"; trousers = "Item_TrousersDenimBlue"; vest = "Item_BulletVest_CamoOlive"; boots = "Item_BootsARmy"
    shoes = "Item_ShoesRunningWhite"; helmet = "Item_HelmetArmyGreen"; cap = "Item_BaseballCapBlue"; hoodie = "Item_HoodieWhite"
    duffel = "Item_Duffelbag"; riflecase = "Item_RifleCase_SoftGreen"; fannypack = "Item_FannyPack"; plasticbag = "Item_Plasticbag"
    generator = "Item_Generator"; pot = "Item_Pot"; pot_water = "Item_Pot_Water"; saucepan = "Item_SaucepanFilled"; bucket = "Item_Bucket_Water"
    tape = "Item_DuctTape"; thread = "Item_Thread"; glue = "Item_Glue"; wallet = "Item_Wallet_01"; padlock = "Item_Padlock"
    tvdinner = "Item_TVDinner"; sledge = "Item_Sledgehammer2"
    key1 = "Item_Key1"; key2 = "Item_Key2"; key3 = "Item_Key3"; key4 = "Item_Key4"; cassette2 = "Item_Cassette2"; cassette3 = "Item_Cassette3"
    body_male = "male_base"; body_female = "female_base"
    c_corpse = "Container_DeadPerson_MaleZombie"; c_body = "Container_DeadPerson_Male"; c_campfire = "Container_Campfire"
    hat_police = "Item_HatPoliceBlue"; m16 = "Item_AssaultRifle"
    bread = "Item_Bread"; sheet = "Item_Sheet"; watch = "Item_DigitalWatch_Black"; alarmclock = "Item_AlarmClock"
    rag = "Item_Rag"; sheetrope = "Item_SheetRope"
    toiletpaper = "Item_ToiletPaper"; magazine = "Item_Magazine"; clip9 = "Item_BerettaClip"; oatmeal = "Item_Oatmeal"; ammobox9 = "Item_HandgunAmmoBox"; whiskey = "Item_Whiskey"; book_skill = "Item_Book8"
    alice = "Item_AliceBag"; chestrig = "Item_ChestRig"; firstaid = "Item_FirstAid"; toolbox = "Item_Toolbox"; walkie2 = "Item_WalkieTalkieCivilian2"
    wrench = "Item_Wrench"; pipewrench = "Item_PipeWrench"; ratchet = "Item_Ratchet"; multitool = "Item_MultiTool"; hacksaw = "Item_Hacksaw"; scrap = "Item_ElectronicsScrap"
}
$regex = "^(" + (($want.Values | ForEach-Object { [regex]::Escape($_) }) -join "|") + ")$"
foreach ($pack in "UI2.pack", "UI.pack") {
    & $java $tool (Join-Path $game "media\texturepacks\$pack") $tmp $regex | Out-Null
}
$missing = @()
foreach ($k in $want.Keys) {
    $src = Join-Path $tmp ($want[$k] + ".png")
    if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $out "$k.png") -Force } else { $missing += $want[$k] }
}
# traits and occupations (the character screen) and the game modes' pictures
$traits = Join-Path $out "traits"
New-Item -ItemType Directory -Force $traits | Out-Null
foreach ($pack in "UI2.pack", "UI.pack") {
    & $java $tool (Join-Path $game "media\texturepacks\$pack") $traits "^(trait_|profession_)" | Out-Null
}
$modes = Join-Path $out "modes"
New-Item -ItemType Directory -Force $modes | Out-Null
Copy-Item (Join-Path $game "media\ui\playstyleIcons\*.png") $modes -Force
Write-Host "game icons: $($want.Count - $missing.Count) -> $out; traits $((Get-ChildItem $traits).Count); modes $((Get-ChildItem $modes).Count)"
if ($missing) { Write-Host "not found: $($missing -join ', ')" }
