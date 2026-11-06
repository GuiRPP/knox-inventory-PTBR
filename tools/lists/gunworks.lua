-- Gunworks' families of rounds (Escape From Zomboid Firearms' request, the author 2026-11-06) on the
-- game's Lua with the real KnoxCompat, KnoxLoad and KnoxDrag. Without Gunworks: tools/lists/rmenu.lua.
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

-- (the game's stand-ins of load_pre.lua, for the panel at the end)
local GAME_PLAYER, GAME_INV = PLAYER, INV
local now = 100000
getTimestampMs = function() return now end

local PLAIN, HOLLOW, CAL545 = "EFZ.Bullets556", "SWMG.556x45_Bullet_HollowPoint", "SWMG.545x39_Bullet"
local carried = {}
local PLAYER
local INV = {getCountType = function(_, key) return carried[key] or 0 end}
PLAYER = {getInventory = function() return INV end}
local AMMO = {
    ItemAmmoFamily = {["Base.9mmClip"] = "fam9", ["Base.Pistol"] = "fam9"},
    GetFamilyForItem = function(item) return item.family or (item.ft == "Base.9mmClip" and "fam9") or nil end,
    GetBulletTypesForFamily = function(family)
        if family == "fam9" then return {"Base.Bullets9mm", "Base.308Bullets"} end
        return family == "TW:ammo:556" and {PLAIN, HOLLOW} or nil
    end,
    GetAutomaticReloadAmmoType = function(_, item)
        for _, t in ipairs(AMMO_ORDER) do
            if (carried[t] or 0) > 0 and item.family == "TW:ammo:556" then return t end
        end
        return nil
    end,
}
AMMO_ORDER = {PLAIN, HOLLOW}
getActivatedMods = function() return {contains = function(_, id) return id == "SWMG" end} end
local asked
require = function(path) asked = path return AMMO end

local QUEUE = {}
ISTimedActionQueue = {add = function(a) table.insert(QUEUE, a) end}

local function mag(family)
    return {family = family, getFullType = function() return "EFZ.MagAUG" end,
        getCurrentAmmoCount = function() return 0 end, getMaxAmmo = function() return 30 end,
        getAmmoType = function() return {getItemKey = function() return PLAIN end} end,
        getContainer = function() return INV end}
end
local function round(key)
    return {getFullType = function() return key end, getContainer = function() return INV end}
end

local C, L, D = KnoxCompat, KnoxLoad, KnoxDrag

-- the family
local m = mag("TW:ammo:556")
check("a round of the family fits", C.roundFits(m, HOLLOW) == true)
check("found through Gunworks' own module", asked == "WeaponSystems/Utils/Ammo", asked)
check("another calibre does not", C.roundFits(m, CAL545) == false)
check("a magazine with no family takes none by it", C.roundFits(mag(nil), HOLLOW) == false)

-- what is loaded by itself
carried[HOLLOW] = 12
check("by itself: the rounds carried, not the magazine's own type", L.roundFor(PLAYER, m) == HOLLOW, L.roundFor(PLAYER, m))
carried[HOLLOW] = 0
check("none carried: the magazine's own type", L.roundFor(PLAYER, m) == PLAIN, L.roundFor(PLAYER, m))
check("no family: the magazine's own type", L.roundFor(PLAYER, mag(nil)) == PLAIN)

-- the wrapped action keeps all its arguments (they were lost: the packs' menus loaded the plain round)
local a = ISLoadBulletsInMagazine:new(PLAYER, m, 5, 4, HOLLOW)
check("the wrapped action keeps the limit and the kind", a.count == 5 and a.limit == 4 and a.kind == HOLLOW, a.args)

-- dragged onto the magazine
local rounds = round(HOLLOW)
local under = {item = m, items = {m}, x = 0, y = 0}
local v = {isMouseOver = function() return true end, entityUnderMouse = function() return under end}
D.entity, D.extras = {item = rounds, items = {rounds}}, {}
check("a drag of the family lights the magazine", D.magTarget(v) == under)
local wrong = round(CAL545)
D.entity = {item = wrong, items = {wrong}}
check("a drag of another calibre does not", D.magTarget(v) == nil)
D.entity = nil

carried[HOLLOW] = 3
L.loadMagazine(PLAYER, m, {items = {round(HOLLOW), round(HOLLOW), round(HOLLOW)}})
a = QUEUE[#QUEUE]
check("dropped: these rounds, as many as there are", a and a.kind == HOLLOW and a.count == 3 and a.limit == 3, a and a.kind)

-- not of the family: the game's three arguments, as before
QUEUE = {}
ISTimedActionQueue.add = function(x) table.insert(QUEUE, x) end
L.queueLoad(PLAYER, mag(nil), 2, PLAIN)
check("no family: the game's own action", QUEUE[1] and QUEUE[1].args == 3 and QUEUE[1].count == 2)

-- what fits lights up: the family's rounds, and they light up what they go in
local f = L.fitsOf("Base.9mmClip")
check("a magazine lights up the family's rounds", f["Base.Bullets9mm"] == true and f["Base.308Bullets"] == true)
check("not rounds of no family", f["Base.ShotgunShells"] == nil)
check("a round of the family is known here", L.kindOf("Base.308Bullets") == "ammo", L.kindOf("Base.308Bullets"))
f = L.fitsOf("Base.308Bullets")
check("it lights up the magazine and the gun", f["Base.9mmClip"] == true and f["Base.Pistol"] == true)
check("a magazine with no family as before", L.fitsOf("Base.Shotgun")["Base.308Bullets"] == nil)

-- a pack's box no gun names: its recipe tells what comes out
check("a box of the family's other rounds is known", L.kindOf("Base.Box308") == "box", L.kindOf("Base.Box308"))
check("the magazine lights it up", L.fitsOf("Base.9mmClip")["Base.Box308"] == true)
check("it lights up the magazine", L.fitsOf("Base.Box308")["Base.9mmClip"] == true)
local gunBoxes = {}
for _, b in ipairs(L.boxTypes(newItem("Base.Pistol"))) do gunBoxes[b] = true end
check("the gun's boxes: of all its rounds", gunBoxes["Base.Bullets9mmBox"] == true and gunBoxes["Base.Box308"] == true)
check("not another gun's", gunBoxes["Base.ShotgunShellsBox"] == nil)
local allBoxes = {}
for _, b in ipairs(L.boxTypes(nil)) do allBoxes[b] = true end
check("no gun: all the boxes", allBoxes["Base.ShotgunShellsBox"] == true and allBoxes["Base.Box308"] == true)
local opened
ISInventoryPaneContextMenu.OnNewCraft = function(_, recipe) opened = recipe.name end
check("it opens by its own recipe", L.openBox(GAME_PLAYER, newItem("Base.Box308")) == true and opened == "OpenBox308", opened)

-- the panel: every kind carried, the magazine's own first; the box last
local P = KnoxSlotPicker
local function ref(item)
    return {item = item, getAbsoluteX = function() return 300 end, getAbsoluteY = function() return 200 end,
            getWidth = function() return 48 end, getHeight = function() return 48 end}
end
local clip = newItem("Base.9mmClip", GAME_INV, {n = 7})
newItem("Base.308Bullets", GAME_INV)
newItem("Base.308Bullets", GAME_INV)
newItem("Base.Bullets9mm", GAME_INV)
local box = newItem("Base.Bullets9mmBox", GAME_INV)
newItem("Base.ShotgunShells", GAME_INV)
local r = ref(clip)
L.panelFor = clip
L.offer(r, clip, GAME_PLAYER, 0)
now = now + 130
L.offer(r, clip, GAME_PLAYER, 0)
P.sync(nil)
local l = P.instance and P.instance.load
check("the panel is up", l ~= nil)
check("all the family's piles, then the box", l and #l.spares == 3, l and #l.spares)
check("its own round first", l and l.spares[1].item:getFullType() == "Base.Bullets9mm")
check("the family's next, both of them", l and l.spares[2].item:getFullType() == "Base.308Bullets" and l.spares[2].count == 2)
check("the box last", l and l.spares[3].item == box)

-- a part that holds rounds is a magazine, and still a part of its gun (Escape From Zomboid's)
check("a part with rounds: a magazine", L.kindOf("Base.PartMag") == "mag", L.kindOf("Base.PartMag"))
check("it gets the panel", L.panelOf(newItem("Base.PartMag", nil, {n = 3})) == "mag")
check("a plain part does not", L.panelOf(newItem("Base.Laser")) == nil)
check("its rounds light it", L.fitsOf("Base.Bullets9mm")["Base.PartMag"] == true)
check("it lights its rounds and gun",
    L.fitsOf("Base.PartMag")["Base.Bullets9mm"] == true and L.fitsOf("Base.PartMag")["Base.Pistol"] == true)
check("its gun lights it", L.fitsOf("Base.Pistol")["Base.PartMag"] == true)

-- a magazine told joins its like and another leads the tile: the key's press goes with it
do
    local other = newItem("Base.9mmClip", GAME_INV, {n = 7})
    local tile = {item = other, items = {other, clip}}
    local r2 = {item = clip, sinceMs = 0}
    L.panelFor = clip
    L.follow(r2, tile)
    check("the press goes on to the tile's leader", L.panelFor == other and r2.item == other and r2.sinceMs == 0)
    L.panelFor = clip
    r2 = {item = clip}
    L.follow(r2, {item = other, items = {other}})
    check("not in that tile: nothing moves", L.panelFor == clip and r2.item == clip)
end

-- the rounds told: as the panel, not as the key
L.sync()
check("told while the panel is up", L.opened == clip and L.counting(clip))
L.panelFor = nil
check("the mouse gone on to the panel: still told", L.counting(clip))
check("another magazine is not", not L.counting(box))
P.close()
now = now + 1000
P.sweep()
L.sync()
check("the panel gone: no more", L.opened == false and not L.counting(clip), tostring(L.opened))

print(string.format("gunworks: %d pass, %d fail", pass, fail))
