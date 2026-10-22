-- Runs KnoxSearch.lua (the searching of containers not looked into) outside the
-- game against tools/search/stubs.lua: which container gets the search (a bag
-- window, a bag on the character, the surroundings), what stays hidden while a
-- search waits, what is remembered when one is left half-way.
--
--   tools/search/test.ps1

local S = KnoxSearch
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else
        fail = fail + 1
        print("FAIL " .. name .. (detail ~= nil and (" : " .. tostring(detail)) or ""))
    end
end

-- the surroundings' container on show and its grid
local sel, selL = nil, nil
local function frame() S.tick(sel, selL) end
local function run(ms)
    for _ = 1, math.ceil(ms / 50) do
        clock = clock + 50
        frame()
    end
end
local function reset()
    S.selected = nil
    KnoxContainerWindow.list, KnoxContainerWindow.active = {}, nil
    KnoxScreen.instance.inventory.sections = {}
    sel, selL = nil, nil
    searchOn, paused = true, false
    frame()
end
local function openWindow(bag)
    local w = {view = {container = bag:getInventory(), layout = layoutOf(bag:getInventory())}}
    table.insert(KnoxContainerWindow.list, w)
    KnoxContainerWindow.active = w
    return w
end
local function closeWindow(w)
    for i, x in ipairs(KnoxContainerWindow.list) do
        if x == w then table.remove(KnoxContainerWindow.list, i) break end
    end
    if KnoxContainerWindow.active == w then KnoxContainerWindow.active = KnoxContainerWindow.list[#KnoxContainerWindow.list] end
end
local function hiddenCount(c)
    local n = 0
    for _, it in ipairs(c.items) do if S.isHidden(it) then n = n + 1 end end
    return n
end

-- 1. A cupboard not looked into: searched thing by thing, then marked -------------
reset()
local cupboard = newContainer("cupboard")
local can, knife, pills = newItem("can", cupboard), newItem("knife", cupboard), newItem("pills", cupboard)
sel, selL = cupboard, layoutOf(cupboard)
frame()
check("cupboard: search begins", S.busy(cupboard))
check("cupboard: all hidden at first", hiddenCount(cupboard) == 3, hiddenCount(cupboard))
check("cupboard: first one is current", S.stateOf(can) == "current", S.stateOf(can))
run(250)
check("cupboard: one found after 0.25 s", hiddenCount(cupboard) == 2, hiddenCount(cupboard))
check("cupboard: found one is known", S.isKnown(can))
run(600)
check("cupboard: all found", hiddenCount(cupboard) == 0, hiddenCount(cupboard))
check("cupboard: marked as looked into", cupboard.seen == true)
check("cupboard: search over", not S.busy(cupboard))

-- 2. Paused game: no time passes ------------------------------------------------------
reset()
local box = newContainer("box")
newItem("a", box); newItem("b", box)
sel, selL = box, layoutOf(box)
frame()
paused = true
run(1000)
check("paused: nothing found", hiddenCount(box) == 2, hiddenCount(box))
paused = false
run(600)
check("unpaused: found", hiddenCount(box) == 0, hiddenCount(box))

-- 3. A bag window of a bag not looked into: searched there, first -----------------------
reset()
local shelf = newContainer("shelf")
newItem("cereal", shelf); newItem("rice", shelf)
local floor = newContainer("floor", false)
local pack = newBag("plastic bag", floor)
local inner = newBag("inner bag", pack:getInventory())
local spoon = newItem("spoon", pack:getInventory())
local deep = newItem("ring", inner:getInventory())
sel, selL = shelf, layoutOf(shelf)
frame()
check("window: the shelf is searched first", S.busy(shelf))
run(250)   -- one thing of the shelf found
check("window: shelf 1 of 2 found", hiddenCount(shelf) == 1, hiddenCount(shelf))
local w = openWindow(pack)
frame()
check("window: the search moves to the bag", S.busy(pack:getInventory()))
check("window: the bag's things hidden", hiddenCount(pack:getInventory()) == 2, hiddenCount(pack:getInventory()))
check("window: the shelf waits, its unfound thing hidden", hiddenCount(shelf) == 1, hiddenCount(shelf))
check("window: the shelf's found thing still shown", not S.isHidden(shelf.items[1]))
run(600)   -- (the inner bag first: 2x2 cells, 0.55 s)
check("window: the bag's first thing found", hiddenCount(pack:getInventory()) == 1, hiddenCount(pack:getInventory()))
-- left half-way: the window is closed
closeWindow(w)
frame()
check("window closed: back to the shelf", S.busy(shelf))
run(300)
check("window closed: the shelf done", shelf.seen == true and hiddenCount(shelf) == 0)
-- opened again: only what was not found is looked for
w = openWindow(pack)
frame()
check("window again: one thing left to find", hiddenCount(pack:getInventory()) == 1, hiddenCount(pack:getInventory()))
run(700)
check("window again: the bag done and marked", pack:getInventory().seen == true and hiddenCount(pack:getInventory()) == 0)
check("window again: the inner bag not looked into", inner:getInventory().seen ~= true)
check("unseen: a thing in the inner bag", S.unseen(deep))
check("unseen: a thing found in the bag is not", not S.unseen(spoon))
closeWindow(w)
-- the bag chosen in the surroundings after all that: no search
sel, selL = pack:getInventory(), layoutOf(pack:getInventory())
frame()
check("bag in surroundings: not searched again", not S.busy(pack:getInventory()))

-- 4. A bag put on without a look: searched in its section, before the surroundings -----
reset()
local crate = newContainer("crate")
newItem("nails", crate)
local found = newBag("backpack", nil)
newItem("map", found:getInventory()); newItem("lighter", found:getInventory())
local pockets = newContainer("pockets", false)
local sections = KnoxScreen.instance.inventory.sections
table.insert(sections, {pockets = true, view = {container = pockets, layout = layoutOf(pockets)}})
local sec = {view = {container = found:getInventory(), layout = layoutOf(found:getInventory())}}
table.insert(sections, sec)
sel, selL = crate, layoutOf(crate)
frame()
check("worn bag: searched before the crate", S.busy(found:getInventory()))
check("worn bag: crate's thing hidden meanwhile", hiddenCount(crate) == 1, hiddenCount(crate))
sec.collapsed = true
frame()
check("worn bag folded: the crate is searched", S.busy(crate))
check("worn bag folded: its things stay hidden", hiddenCount(found:getInventory()) == 2, hiddenCount(found:getInventory()))
sec.collapsed = false
frame()
run(600)
check("worn bag: done", found:getInventory().seen == true)
run(300)
check("worn bag then crate: crate done", crate.seen == true)

-- 5. The pockets and a new character's kit -------------------------------------------
reset()
local inv = newContainer("main", false)
local kitBag = newBag("school bag", inv)
local kitThing = newItem("notebook", kitBag:getInventory())
fireNewGame({getInventory = function() return inv end})
local lateThing = newItem("lunchbox", kitBag:getInventory())   -- (handed out after OnNewGame)
fireTicks(5)
check("new game: the kit known", S.isKnown(kitThing))
check("new game: a thing handed out a moment later known", S.isKnown(lateThing))
check("new game: its bag marked", kitBag:getInventory().seen == true)
local apple = newItem("apple", inv)
check("pockets: never hidden", not S.isHidden(apple))

-- 6. The switch off: nothing searched, nothing hidden --------------------------------
reset()
searchOn = false
local drawer = newContainer("drawer")
local sock = newItem("sock", drawer)
sel, selL = drawer, layoutOf(drawer)
frame()
check("off: no search", not S.busy(drawer))
check("off: nothing hidden", not S.isHidden(sock))
check("off: nothing unseen", not S.unseen(sock))
-- (asked for every tile every frame: with the search off the thing's modData is
-- not read at all - the ultra pass, 2026-10-21)
local reads = 0
local glove = newItem("glove", drawer)
glove.hasModData = function() reads = reads + 1 return false end
glove.getModData = function() reads = reads + 1 return {} end
check("off: a tile's state without its modData", S.stateOf(glove) == nil and reads == 0, reads)

-- 7. A thing taken away mid-search takes no time -------------------------------------
reset()
local bin = newContainer("bin")
local first, second = newItem("first", bin, 3, 3), newItem("second", bin)
sel, selL = bin, layoutOf(bin)
frame()
moveItem(first, nil)
run(250)
check("taken away: the next one found at once", not S.isHidden(second))

-- 8. Sounds: the hands in the container, each thing as it is found --------------------
local SS = KnoxSearchSound
local function heard(name)
    for _, n in ipairs(emitted) do if n == name then return true end end
    return false
end
local function count(name)
    local k = 0
    for _, n in ipairs(emitted) do if n == name then k = k + 1 end end
    return k
end
reset()
emitted = {}
local desk = newContainer("desk")
desk.put = "DrawerWoodTransferItem"
local can = newItem("can", desk); can.ft = "Base.TinnedBeans"; can.classes.Food = true; can.tags = {"hasmetal"}
local coat = newItem("coat", desk, 2, 2); coat.classes.Clothing = true; coat.fabric = "Leather"; coat.drop = "ShouldNotPlay"
local gun = newItem("gun", desk, 2, 1); gun.drop = "M9Drop"
local rounds = newItem("rounds", desk); rounds.placeOne = "BoxOfRoundsPlaceOne"; rounds.cat = "Ammo"
local thing = newItem("thing", desk)
sel, selL = desk, layoutOf(desk)
frame()
run(150)
check("sound: the hands rummage while searching", playingNamed("RummageInInventory"))
run(4000)
check("sound: the search is over", not S.busy(desk))
check("sound: the rummage stops with it", not playingNamed("RummageInInventory"))
check("sound: a can clinks", heard("StoreItemSmallMetalBox"))
check("sound: a leather coat, not its drop", heard("StoreItemLeatherBag") and not heard("ShouldNotPlay"))
check("sound: a pistol - its material, not its drop on the floor", not heard("M9Drop"))
check("sound: a box of rounds - ammo, levelled", heard("StoreItemBulletsBandolier") and not heard("BoxOfRoundsPlaceOne"))
check("sound: an unknown thing - soft, not the drawer", heard("StoreItemFabricPouch") and not heard("DrawerWoodTransferItem"))
check("sound: one rummage at a time", count("RummageInInventory") == 1, count("RummageInInventory"))

-- the screen closed mid-search: no more ticks of the search, the loop stops on its own
reset()
emitted = {}
local shelf = newContainer("shelf")
for i = 1, 6 do newItem("x" .. i, shelf, 3, 3) end
sel, selL = shelf, layoutOf(shelf)
frame()
run(100)
check("closed: rummaging", playingNamed("RummageInInventory"))
clock = clock + 400
fireTicks(1)
check("closed: the rummage stops without the search's ticks", not playingNamed("RummageInInventory"))

-- the slider at 0: silent
reset()
emitted, searchSound = {}, 0
local crate = newContainer("crate")
newItem("a", crate); newItem("b", crate)
sel, selL = crate, layoutOf(crate)
frame()
run(2000)
check("silent: nothing played at 0 %", #emitted == 0, #emitted)
searchSound = 100

-- what things sound like
local unique = 0
local function soundOf(o, c)
    -- (a material is kept per item type: each made-up thing a type of its own)
    unique = unique + 1
    o.ft = o.ft or ("Base.Thing" .. unique)
    local it = newItem(o.name or "t", nil, 1, 1)
    for k, v in pairs(o) do it[k] = v end
    for _, cl in ipairs(o.is or {}) do it.classes[cl] = true end
    return (SS.soundOf(it, c))
end
check("kind: a glass bottle", soundOf({tap = "GetWaterFromTapGlass"}) == "WaterDispenserAddBottle")
check("kind: a plastic bottle", soundOf({tap = "GetWaterFromTapPlasticMedium"}) == "StoreItemMediumPlasticBox")
check("kind: a book", soundOf({ft = "Base.Book", cat = "Literature", is = {"Literature"}}) == "CloseBook")
check("kind: a magazine", soundOf({ft = "Base.HottieZ", cat = "Literature", is = {"Literature"}, tags = {"magazine"}}) == "PageFlipMagazine")
check("kind: a skill book", soundOf({ft = "Base.BookCarpentry1", cat = "SkillBook", is = {"Literature"}, tags = {"hardcover"}}) == "CloseBook")
check("kind: a newspaper", soundOf({ft = "Base.Newspaper", cat = "Literature", is = {"Literature"}}) == "PageFlipMagazine")
check("kind: toilet paper is not a book", soundOf({ft = "Base.ToiletPaper", cat = "Junk"}) == "StoreItemFabricPouch")
check("kind: keys", soundOf({ft = "Base.CarKey", is = {"Key"}}) == "StoreItemKeyRing")
check("kind: a turkey is not a key", soundOf({ft = "Base.Turkey", is = {"Food"}, weight = 2}) == "StoreItemSack")
check("kind: oatmeal in a bowl", soundOf({ft = "Base.Oatmeal", is = {"Food"}, model = "BowlRice_Ground"}) == "StoreItemCookieJar")
check("kind: a salad in a bowl", soundOf({ft = "Base.Salad", is = {"Food"}, model = "Salad_Ground"}) == "StoreItemCookieJar")
check("kind: pepper in a shaker", soundOf({ft = "Base.Pepper", is = {"Food"}, model = "Pepper"}) == "StoreItemMediumPlasticBox")
check("kind: chips", soundOf({ft = "Base.Crisps", is = {"Food"}, packaged = true}) == "StoreItemPlasticBag")
check("kind: a cotton shirt", soundOf({ft = "Base.Shirt", is = {"Clothing"}, fabric = "Cotton"}) == "StoreItemFabricPouch")
check("kind: pills", soundOf({ft = "Base.Pills", cat = "FirstAid"}) == "StoreItemPencilCase")
check("kind: nails", soundOf({ft = "Base.Nails", cat = "Material", tags = {"hasmetal"}}) == "StoreItemBulletsBandolier")
KnoxFootprint = {overrides = {["Base.Gizmo2"] = {sound = "glass"}}}
check("kind: the player's own line wins", soundOf({ft = "Base.Gizmo2", drop = "M9Drop"}) == "WaterDispenserAddBottle")
KnoxFootprint = nil
local backpack = newBag("pack")
backpack.inv.close = "CloseLeatherBag"
check("kind: a bag found - its material, not its zip", (SS.soundOf(backpack, nil)) == "StoreItemFabricPouch")
-- one level for all: a quiet recording raised, a loud one lowered (KnoxSoundLevelData)
emitted, volumes = {}, {}
local id1 = SS.play(getPlayer(), "StoreItemFabricPouch", 0.6)
local id2 = SS.play(getPlayer(), "PageFlipMagazine", 0.6)
check("level: a quiet event raised", math.abs(volumes[id1] - 0.6 * KnoxSoundLevel.StoreItemFabricPouch) < 1e-6 and volumes[id1] > 0.6, volumes[id1])
check("level: a loud event lowered", volumes[id2] < 0.6, volumes[id2])
local id3 = SS.play(getPlayer(), "RummageInInventory", 2)
check("level: never over 4", volumes[id3] <= 4, volumes[id3])
check("kind: nothing known, no container", soundOf({ft = "Mod.Gizmo"}) == "StoreItemFabricPouch")

-- 9. Interface sounds (KnoxUISound) ------------------------------------------------------
local U = KnoxUISound
local function newThing(o)
    local it = newItem(o.name or "t", nil, 1, 1)
    for k, v in pairs(o) do it[k] = v end
    for _, cl in ipairs(o.is or {}) do it.classes[cl] = true end
    return it
end
clock = clock + 1000
emitted = {}
U.pick(newThing({ft = "Base.Pistol", drop = "M9Drop", cat = "Weapon", tags = {"hasmetal"}, weight = 0.9}))
check("ui: a pistol lifted - metal, not its drop", emitted[1] == "StoreItemMetalToolbox" and not heard("M9Drop"), emitted[1])
clock = clock + 1000
emitted = {}
U.place(newThing({ft = "Base.TinnedBeans2", is = {"Food"}, tags = {"hasmetal"}}), nil)
U.place(newThing({ft = "Base.TinnedSoup", is = {"Food"}, tags = {"hasmetal"}}), nil)
check("ui: a can put down clinks, twice at once is once", #emitted == 1 and emitted[1] == "StoreItemSmallMetalBox", #emitted)
clock = clock + 1000
emitted = {}
U.turn()
check("ui: turned", emitted[1] == "UIObjectMenuObjectRotate")
clock = clock + 1000
emitted = {}
local sack = newBag("sack")
sack.inv.open, sack.inv.close = "OpenFabricPouch", "CloseFabricPouch"
U.bag(sack, true)
clock = clock + 1000
U.bag(sack, false)
check("ui: a bag window - its own open and close", emitted[1] == "OpenFabricPouch" and emitted[2] == "CloseFabricPouch", tostring(emitted[1]) .. " " .. tostring(emitted[2]))
clock = clock + 1000
emitted = {}
U.bag(newThing({ft = "Base.Apple"}), true)
check("ui: not a bag - nothing", #emitted == 0)
uiSound = 0
clock = clock + 1000
U.pick(newThing({ft = "Base.Book", is = {"Literature"}}))
check("ui: silent at 0 %", #emitted == 0, #emitted)
uiSound = 100

print(string.format("DONE pass=%d fail=%d", pass, fail))
