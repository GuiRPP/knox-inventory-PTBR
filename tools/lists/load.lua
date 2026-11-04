-- Magazines, rounds and guns (KnoxLoad, the author, 2026-10-30) on the game's Lua
-- with tools/settings/stubs.lua, tools/lists/load_pre.lua and the real KnoxTheme,
-- KnoxSlotPicker and KnoxLoad: what fits what, what is lit up in the grids and for
-- how long, what the panel shows past its line, what each of its cells says and
-- which of the game's actions a click on it queues.
local T = KnoxTheme
local P = KnoxSlotPicker
local L = KnoxLoad
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end
local function has(t, ...)
    for _, k in ipairs({...}) do if not t[k] then return false end end
    return true
end

-- what fits what -----------------------------------------------------------------
check("a pistol is a gun", L.kindOf("Base.Pistol") == "gun")
check("a clip is a magazine", L.kindOf("Base.9mmClip") == "mag")
check("9mm are rounds", L.kindOf("Base.Bullets9mm") == "ammo")
check("its box", L.kindOf("Base.Bullets9mmBox") == "box")
check("a laser is a part", L.kindOf("Base.Laser") == "part")
check("an axe is none of them", L.kindOf("Base.Axe") == nil)
check("beans are none of them", L.kindOf("Base.Beans") == nil)
local made = INSTANCED
L.index()
check("read once", INSTANCED == made)

local f = L.fitsOf("Base.9mmClip")
check("a magazine: its rounds, their box, its gun", has(f, "Base.Bullets9mm", "Base.Bullets9mmBox", "Base.Pistol"))
check("a magazine: not shells, not .308", not f["Base.ShotgunShells"] and not f["Base.308Bullets"])
f = L.fitsOf("Base.Pistol")
check("a pistol: its magazine and the parts for it", has(f, "Base.9mmClip", "Base.Laser", "Base.Sling"))
check("a pistol takes magazines, not loose rounds", not f["Base.Bullets9mm"])
f = L.fitsOf("Base.Shotgun")
check("a shotgun: shells and their box, a part for any gun", has(f, "Base.ShotgunShells", "Base.ShotgunShellsBox", "Base.Sling"))
check("a shotgun: not the pistol's laser", not f["Base.Laser"])
f = L.fitsOf("Base.Bullets9mm")
check("9mm rounds: the magazine and the pistol", has(f, "Base.9mmClip", "Base.Pistol") and not f["Base.Shotgun"])
f = L.fitsOf("Base.Bullets9mmBox")
check("a box: as its rounds", has(f, "Base.9mmClip", "Base.Pistol"))
f = L.fitsOf("Base.Laser")
check("a laser: the pistol only", f["Base.Pistol"] and not f["Base.Shotgun"])
f = L.fitsOf("Base.Sling")
check("a part for any gun: all of them", has(f, "Base.Pistol", "Base.Shotgun"))

-- what is lit up -----------------------------------------------------------------
local mag = newItem("Base.9mmClip", INV, {n = 7})
local full = newItem("Base.9mmClip", INV, {n = 15})
local pistol = newItem("Base.Pistol", INV, {clip = true, n = 12, chambered = true})
local laser = newItem("Base.Laser", INV)
local beans = newItem("Base.Beans", INV)
local loose = {}
for i = 1, 5 do loose[i] = newItem("Base.Bullets9mm", INV) end
local bagged = {}
for i = 1, 30 do bagged[i] = newItem("Base.Bullets9mm", BAG) end
local box = newItem("Base.Bullets9mmBox", FLOOR)
local floorRounds = newItem("Base.Bullets9mm", FLOOR)
local r308 = newItem("Base.308Bullets", FLOOR)
viewOf(INV)
viewOf(BAG)
viewOf(FLOOR)
layoutAll()

local function frame(item, ms)
    clock = clock + (ms or 16)
    if item then L.hover(item) end
    L.sync()
end
frame(mag)
check("not at once (the mouse passing over)", not L.isLit(loose[1]))
frame(mag, 130)
check("after a moment: its rounds", L.isLit(loose[1]) and L.isLit(bagged[30]) and L.isLit(floorRounds))
check("the box and the gun", L.isLit(box) and L.isLit(pistol))
check("not the .308, the beans, itself", not L.isLit(r308) and not L.isLit(beans) and not L.isLit(mag))
check("not another magazine", not L.isLit(full))
local was = L.lit
frame(mag)
check("not looked for again every frame", L.lit == was)
frame(mag, 600)
check("looked for again after a while", L.lit ~= was and L.isLit(loose[1]))
frame(nil, 100)
check("the mouse off it: still lit for a moment", L.isLit(loose[1]))
frame(nil, 200)
check("then not", not L.isLit(loose[1]))

frame(pistol)
frame(pistol, 130)
check("a pistol: its magazines and the laser", L.isLit(mag) and L.isLit(full) and L.isLit(laser))
check("a pistol: not loose rounds", not L.isLit(loose[1]))
pistol.parts = {Laser = newItem("Base.Laser")}
frame(pistol, 600)
check("its laser's place taken: the laser not lit", not L.isLit(laser) and L.isLit(mag))
pistol.parts = nil
frame(laser)
frame(laser, 130)
check("a laser: the pistol", L.isLit(pistol) and not L.isLit(mag))
laser.broken = true
frame(laser, 600)
check("a broken laser: nothing", not L.isLit(pistol))
laser.broken = false
frame(loose[1])
frame(loose[1], 130)
check("rounds: the magazines and the pistol", L.isLit(mag) and L.isLit(full) and L.isLit(pistol))
L.picking = true
check("the mouse on a cell of the panel: green off", not L.isLit(mag))
L.picking = false
frame(nil, 400)

-- they fade in and out (the author, 2026-10-30: "появляются слишком резко")
frame(nil, 1000)
check("none: nothing shown", L.litA == 0 and L.shown[loose[1]] == nil)
for _ = 1, 9 do frame(mag) end   -- (frames of 16 ms: lit after 120)
check("lit: fading in, not all at once", L.litA > 0 and L.litA < 0.2 and L.shown[loose[1]] == true, L.litA)
for _ = 1, 12 do frame(mag) end
check("lit: then in full", L.litA == 1)
frame(nil, 300)
check("gone: still shown, fading out", L.lit[loose[1]] == nil and L.shown[loose[1]] == true and L.litA > 0 and L.litA < 1, L.litA)
frame(nil, 100)
frame(nil, 100)
check("gone: then not shown at all", L.litA == 0 and L.shown[loose[1]] == nil)

-- the panel -----------------------------------------------------------------------
local function ref(item)
    return {item = item, getAbsoluteX = function() return 300 end, getAbsoluteY = function() return 200 end,
            getWidth = function() return 48 end, getHeight = function() return 48 end}
end
local function open(r)
    P.close()
    clock = clock + 1000
    P.sweep()
    L.panelFor = r.item   -- (the quick items' key pressed over it)
    L.offer(r, r.item, PLAYER, 0)
    clock = clock + 130
    L.offer(r, r.item, PLAYER, 0)
    P.sync(nil)
    return P.instance, P.instance and P.instance.load
end
local function act(l, i)
    DONE = {}
    l.act(i)
    return DONE
end
local function find(done, name)
    for _, d in ipairs(done) do
        if d[1] == name or d[2] == name then return d end
    end
    return nil
end

local rm = ref(mag)
L.offer(rm, mag, PLAYER, 0)
check("no panel at once", P.request == nil or P.request.owner ~= rm)
local p, l = open(rm)
check("a magazine's panel", p ~= nil and l ~= nil and l.kind == "rounds")
check("its title: rounds", p.title == getText("IGUI_Knox_LoadRounds"))
check("the header: 7/15", p.total == "7/15", p.total)
check("past the line: the piles - pocket, bag, floor, then the box", #l.spares == 4, #l.spares)
check("the main inventory's first", l.spares[1].item.container == INV and l.spares[1].count == 5, l.spares[1].count)
check("then the bag's", l.spares[2].item.container == BAG and l.spares[2].count == 30)
check("then the floor's", l.spares[3].item.container == FLOOR and l.spares[3].count == 1)
check("the box last", l.spares[4].box == true and l.spares[4].item == box)
check("over it: unload", l.hint(1) == "unload")
check("over rounds: load", l.hint(2) == "load" and l.hint(4) == "load")
check("over the box: open", l.hint(5) == "open")
check("as wide as the header may get", p:getWidth() >= T.measure(T.fontCaps, T.upper(p.title)) + P.loadWords().width + p.pad * 3)
local d = act(l, 3)
local q = find(d, "loadMag")
check("the bag's rounds: in the main inventory first, then loaded", q ~= nil and q[3].b == 8, q and q[3].b)
local moves = 0
for _, x in ipairs(d) do if x[2] == "move" then moves = moves + 1 end end
check("as many moved as go in", moves == 8, moves)
d = act(l, 4)
q = find(d, "loadMag")
check("the floor's one: moved, and the pocket's go in too", find(d, "move") ~= nil and q and q[3].b == 6, q and q[3].b)
d = act(l, 5)
q = find(d, "craft")
check("the box opened by its recipe", q ~= nil and q[2] == box and q[3] == "OpenBoxOfBullets50")
d = act(l, 1)
check("unloaded", find(d, "unloadMag") ~= nil)

local pf = ref(full)
p, l = open(pf)
check("full: nothing to load", l.hint(2) == nil and l.hint(5) == "open")
check("full: the header 15/15", p.total == "15/15")

local empty = newItem("Base.9mmClip", INV, {n = 0})
local savedBag = BAG.items
BAG.items = {}
local savedInv = {}
for _, it in ipairs(INV.items) do table.insert(savedInv, it) end
for i = #INV.items, 1, -1 do if INV.items[i].ft == "Base.Bullets9mm" then table.remove(INV.items, i) end end
local savedFloor = FLOOR.items
FLOOR.items = {}
p, l = open(ref(empty))
check("empty, no rounds anywhere: nothing past the line", #l.spares == 0)
check("empty, no rounds: no click", l.hint(1) == nil)
BAG.items, FLOOR.items, INV.items = savedBag, savedFloor, savedInv

-- the pistol's panel
local rp = ref(pistol)
p, l = open(rp)
check("a pistol's panel: magazines", l.kind == "mag" and p.title == getText("IGUI_Knox_LoadMag"))
check("in it: 12 and one in the chamber", l.inner.n == 12 and l.inner.plus == true)
check("its spares: the fullest first", l.spares[1].item == full and l.spares[#l.spares].n <= l.spares[1].n)
check("over its magazine: take out", l.hint(1) == "take")
check("over a spare: replace", l.hint(2) == "swap")
d = act(l, 2)
local eq, ej, ins = find(d, "equip"), find(d, "eject"), find(d, "insert")
check("replace: in hand, the old one out, the chosen in", eq and ej and ins and ins[3].b == full)
d = act(l, 1)
check("take out: the game's eject", find(d, "ejectMenu") ~= nil)
pistol.clip, pistol.n = false, 0
p, l = open(rp)
check("without a magazine: none in the header", p.total == getText("IGUI_Knox_LoadNone"))
check("without: over the slot, insert", l.hint(1) == "insert" and l.hint(2) == "insert")
d = act(l, 1)
ins = find(d, "insert")
check("the empty slot clicked: the fullest goes in, none taken out", ins and ins[3].b == full and not find(d, "eject"))
pistol.jam = true
p, l = open(rp)
check("jammed: rack", l.hint(1) == "rack" and l.jam == true)
d = act(l, 1)
check("racked by the game's menu", find(d, "rack") ~= nil)
pistol.jam = false

-- a shotgun takes its shells itself
local shotgun = newItem("Base.Shotgun", INV, {n = 3, chambered = true})
local shells = {}
for i = 1, 12 do shells[i] = newItem("Base.ShotgunShells", INV) end
local sbox = newItem("Base.ShotgunShellsBox", FLOOR)
layoutAll()
p, l = open(ref(shotgun))
check("a shotgun's panel: shells", l.kind == "rounds" and p.title == getText("IGUI_Knox_LoadShells"))
check("3+1 in it", l.inner.n == 3 and l.inner.plus == true and P.rounds(3, true) == "3+1")
check("its shells, then their box", l.spares[1].count == 12 and l.spares[#l.spares].item == sbox)
check("over it: unload; over shells: load; the box: open", l.hint(1) == "unload" and l.hint(2) == "load" and l.hint(3) == "open")
d = act(l, 2)
check("loaded by the game's menu", find(d, "loadGun") ~= nil and not find(d, "move"))
d = act(l, 1)
check("unloaded by the game's menu", find(d, "unloadGun") ~= nil)
d = act(l, 3)
q = find(d, "craft")
check("its box opened", q and q[3] == "OpenBoxOfShotgunShells")

-- the panel drawn, and what it points at
p, l = open(rm)
p.isMouseOver = function() return p.mx ~= nil end
local function at(i)
    local cs, gap = p.cs, p.gap
    local y = p.headH + p.pad + math.floor(cs / 2)
    if i == 1 then return p.pad + math.floor(cs / 2), y end
    local k = i - 2
    return p.sx + (k % p.cols) * (cs + gap) + math.floor(cs / 2), y + math.floor(k / p.cols) * (cs + gap)
end
local function hover(i)
    if i then p.mx, p.my = at(i) else p.mx, p.my = nil, nil end
    clock = clock + 16
    L.offer(rm, mag, PLAYER, 0)
    P.sync(nil)
    local ok, err = pcall(p.prerender, p)
    if not ok then check("drawn", false, err) end
end
local tipOf
KnoxTooltip.want = function(item) tipOf = item end
hover(nil)
check("off the cells: green", L.picking == false)
check("off the cells: no tooltip from the panel", tipOf == nil)
hover(3)
check("over the bag's pile: it pointed at in sand", L.picking == true and P.offered[bagged[1]] and P.offered[bagged[30]] and not P.offered[loose[1]])
check("over the bag's pile: its tooltip", tipOf == bagged[1] or tipOf == p.load.spares[2].item)
tipOf = nil
hover(1)
check("over the magazine: green again", L.picking == false)
check("over the first cell: no tooltip (a stand-in)", tipOf == nil)
KnoxTooltip.want = function() end
check("the header under the mouse", p:loadHint(1) == P.loadWords().unload)
P.close()
check("closed: green", L.picking == false)

-- what has the panel, so no tooltip of its own over its cells (2026-10-30)
check("a gun: its panel", L.panelOf(newItem("Base.Pistol")) == "gun")
check("a magazine: its panel", L.panelOf(newItem("Base.9mmClip")) == "mag")
check("rounds, an axe: none", L.panelOf(newItem("Base.Bullets9mm")) == nil and L.panelOf(newItem("Base.Axe")) == nil)
check("nothing: none", L.panelOf(nil) == nil)

-- the tooltip by default; the quick items' key pressed - the panel, pressed again -
-- the tooltip back (the author, 2026-10-30)
HELD = false
local m2 = newItem("Base.9mmClip", INV)
local r2 = ref(m2)
local function tick(held)
    HELD = held
    clock = clock + 16
    local q = L.tipQuiet(m2, true)
    L.offer(r2, m2, PLAYER, 0)
    P.sync(nil)
    return q
end
P.close()
clock = clock + 1000
check("key up: the tooltip shown", tick(false) == false)
clock = clock + 200
tick(false)
check("key up: no panel, rested or not", P.instance == nil)
check("key pressed: no tooltip", tick(true) == true)
check("key held: still none", tick(true) == true)
check("key let go: still none", tick(false) == true)
for _ = 1, 10 do tick(false) end
check("then the panel", P.instance ~= nil and P.instance.owner == r2)
check("key pressed again: the tooltip back", tick(true) == false)
check("...and the panel gone", P.instance == nil)
for _ = 1, 10 do tick(false) end
check("...and it stays gone", P.instance == nil and tick(false) == false)
check("nothing with no panel quiet", L.tipQuiet(m2, false) == false)
local m3 = newItem("Base.9mmClip", INV)
HELD = false
clock = clock + 16
L.tipQuiet(m3, true)
HELD = true
clock = clock + 16
L.tipQuiet(m3, true)   -- (pressed over it; its panel not up yet)
clock = clock + 16
L.tipQuiet(newItem("Base.Bullets9mm"), false)
check("pressed, then gone on to another thing: forgotten", L.panelFor == nil)
HELD = false
P.close()

-- as the game goes in a frame: the tile asks for its panel, then its tooltip sees
-- the key - pressed again, the panel went and came back at once (the author, 2026-10-30)
do
    local m4 = newItem("Base.9mmClip", INV)
    local r4 = ref(m4)
    local function frame(held)
        HELD = held
        clock = clock + 16
        L.offer(r4, m4, PLAYER, 0)
        local q = L.tipQuiet(m4, true)
        P.sync(nil)
        return q
    end
    P.close()
    clock = clock + 1000
    frame(false)
    frame(true)
    for _ = 1, 12 do frame(false) end
    check("game order: the panel up", P.instance ~= nil and P.instance.owner == r4)
    check("game order: pressed again, the tooltip back", frame(true) == false)
    for _ = 1, 3 do frame(false) end
    check("game order: the panel stays gone", P.instance == nil)
    HELD = false
    P.close()
end

print("load: " .. pass .. " pass, " .. fail .. " fail")
