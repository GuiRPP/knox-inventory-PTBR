-- The battery panel (KnoxSlotPicker.wantBattery, the author's choice of battery,
-- 2026-10-29) on the game's Lua with tools/settings/stubs.lua and the real KnoxTheme
-- and KnoxSlotPicker: the one in it and the character's past a line, 4 a row, 12
-- cells at most with "+N"; what the header says over each, what a click does, and
-- what the grids are told to point at.
local T = KnoxTheme
local P = KnoxSlotPicker
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

local done = {}
local function none(t)
    for _ in pairs(t) do return false end
    return true
end
local owner = {getAbsoluteX = function() return 100 end, getAbsoluteY = function() return 100 end,
               getWidth = function() return 96 end, getHeight = function() return 48 end, item = {name = "torch"}}
local function spares(n)
    local list, charges = {}, {}
    for i = 1, n do
        list[i] = {name = "battery" .. i}
        charges[i] = 1 - i * 0.05
    end
    return list, charges
end
local function open(has, n)
    P.close()
    P.sweep()
    clock = clock + 1000
    P.sweep()
    local list, charges = spares(n)
    local b = {has = has, power = 0.23, spares = list, charges = charges,
               act = function(what, battery) done.what, done.battery = what, battery end}
    P.wantBattery(owner, "Battery", b, 0)
    P.sync(nil)
    local p = P.instance
    p.isMouseOver = function() return p.mx ~= nil end
    return p, b
end
-- the middle of cell i (indexAt's numbers: 1 the one in it, k + 1 the k-th spare)
local function at(p, i)
    local cs, gap = p.cs, p.gap
    local y = p.headH + p.pad + math.floor(cs / 2)
    if i == 1 then return p.pad + math.floor(cs / 2), y end
    local k = i - 2
    return p.sx + (k % p.cols) * (cs + gap) + math.floor(cs / 2), y + math.floor(k / p.cols) * (cs + gap)
end
local function hover(p, i)
    if i then p.mx, p.my = at(p, i) else p.mx, p.my = nil, nil end
    clock = clock + 16
    -- (asked for again every frame, as the grid does while the mouse rests on the thing)
    P.wantBattery(owner, "Battery", p.battery, 0)
    P.sync(nil)
    p:prerender()
end

-- a battery in it, three of the character's
local p, b = open(true, 3)
local cs, gap, pad = p.cs, p.gap, p.pad
check("three in a row", p.cols == 3 and p.rows == 1, p.cols .. "x" .. p.rows)
check("past the line", p.sx == pad + cs + 13, p.sx)
check("as wide as its cells", p:getWidth() >= p.sx + 3 * cs + 2 * gap + pad, p:getWidth())
check("the one in it", p:indexAt(at(p, 1)) == 1)
check("the first spare", p:indexAt(at(p, 2)) == 2)
check("the third spare", p:indexAt(at(p, 4)) == 4)
check("the line is no cell", p:indexAt(pad + cs + 6, p.headH + pad + 10) == nil)
check("a gap is no cell", p:indexAt(p.sx + cs + 1, p.headH + pad + 10) == nil)
local w = P.batteryWords()
check("over the one in it: take out", p:batteryHint(1) == w.take)
check("over a spare: replace", p:batteryHint(3) == w.swap)
check("the header's right: the charge", p.total == "23%", p.total)
hover(p, 3)
check("the spare hovered is pointed at", P.offered[b.spares[2]] == true and P.offered[b.spares[1]] == nil)
check("in sand", P.offerColor == nil)
local was = P.offered
hover(p, 3)
check("not built again the next frame", P.offered == was)
hover(p, nil)
check("nothing pointed at off the cells", none(P.offered))
p:useBattery(3)
check("a spare clicked goes in", done.what == "put" and done.battery == b.spares[2], tostring(done.what))

p, b = open(true, 3)
done = {}
p:useBattery(1)
check("the one in it clicked comes out", done.what == "take" and done.battery == nil, tostring(done.what))

-- empty
p, b = open(false, 3)
check("empty, over it: put in", p:batteryHint(1) == w.put)
check("empty, over a spare: put in", p:batteryHint(2) == w.put)
hover(p, 1)
check("empty hovered: all of them, green", P.offered[b.spares[1]] and P.offered[b.spares[3]] and P.offerColor == T.color.ok)
done = {}
p:useBattery(1)
check("empty clicked: the fullest goes in", done.what == "put" and done.battery == nil, tostring(done.what))

-- empty, none of the character's
p, b = open(false, 0)
check("none: one cell", p.cols == 1 and p:getWidth() >= pad * 2 + cs)
check("none: no hint", p:batteryHint(1) == nil)
done = {}
p:useBattery(1)
check("none: a click does nothing", done.what == nil)
hover(p, 1)
check("none hovered: nothing pointed at", none(P.offered))

-- fifteen: the eleven fullest and "+4"
p, b = open(true, 15)
check("fifteen: 11 shown, 4 more", p.shown == 11 and p.more == 4, p.shown .. "+" .. p.more)
check("fifteen: 4 a row, 3 rows", p.cols == 4 and p.rows == 3)
check("the 11th is a cell", p:indexAt(at(p, 12)) == 12)
check("\"+N\" is no cell", p:indexAt(at(p, 13)) == nil)
hover(p, 12)
check("the 11th hovered", P.offered[b.spares[11]] == true)

-- the width does not change with what the header says
p, b = open(true, 1)
local w1 = p:getWidth()
hover(p, 2)
check("the width stays under the mouse", p:getWidth() == w1)
check("as wide as the widest word", w1 >= T.measure(T.fontCaps, T.upper("Battery")) + w.width + pad * 3)

print("picker: " .. pass .. " pass, " .. fail .. " fail")
