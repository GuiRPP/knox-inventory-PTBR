-- A thing's state as its category's colour (condition_v3, the author, 2026-10-31) on the
-- game's Lua with tools/settings/stubs.lua and the real KnoxTheme: what a level is
-- read from, how high the colour goes, the broken thing's icon and cross.
local T = KnoxTheme
T.refresh()
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

function instanceof(o, cls) return type(o) == "table" and o.cls == cls end

-- an element writing down what is drawn on it
local UI = {}
UI.__index = UI
local rects, tex = {}, {}
function UI:drawRect(x, y, w, h, a, r, g, b) table.insert(rects, {x = x, y = y, w = w, h = h, a = a, r = r, g = g, b = b}) end
function UI:drawTextureScaledAspect(t, x, y, w, h, a, r, g, b) table.insert(tex, {t = t, x = x, y = y, w = w, h = h, a = a, r = r, g = g, b = b, kind = "icon"}) end
function UI:drawTexture(t, x, y, a, r, g, b) table.insert(tex, {t = t, x = x, y = y, a = a, r = r, g = g, b = b, kind = "cross"}) end
local ui = setmetatable({javaObject = {}}, UI)
local function clear() rects, tex = {}, {} end
-- (T.rect goes through its own colours: a colour to know the tile by)
local CAT = {r = 0.5, g = 0.25, b = 0.125}
local function isCat(r) return r.r == CAT.r and r.g == CAT.g and r.b == CAT.b end
local function isCell(r) local c = T.color.cell return r.r == c.r and r.g == c.g and r.b == c.b end

local rendered = 0
ISInventoryItem = {renderItemIcon = function() rendered = rendered + 1 end}

local Item = {}
Item.__index = Item
function Item:isBroken() return self.broken == true end
function Item:getConditionMax() return self.cmax or 0 end
function Item:getCondition() return self.c or 0 end
function Item:IsDrainable() return self.uses ~= nil end
function Item:getCurrentUsesFloat() return self.uses end
function Item:getFluidContainer() return self.fluid end
function Item:getWorldItem() return self.world end
function Item:getTex() return "tex" end
function Item:getTextureColorMask() return self.mask end
function Item:getR() return 1 end
function Item:getG() return 0.5 end
function Item:getB() return 0.25 end
local function item(t) return setmetatable(t, Item) end
local function fluid(amount, cap) return {getAmount = function() return amount end, getCapacity = function() return cap end} end

-- what a level is read from -------------------------------------------------------
local gun = item({cls = "HandWeapon", cmax = 10, c = 7})
local socks = item({cls = "Clothing", cmax = 4, c = 1})
local plain = item({cls = "Clothing", cmax = 0})
local torch = item({uses = 0.4})
local bottle = item({fluid = fluid(0.5, 2)})
local noState = item({})
local pan = item({cls = "HandWeapon", cmax = 10, c = 5, fluid = fluid(1, 2)})
local staff = item({cls = "HandWeapon", cmax = 0})
check("a weapon: condition", T.levelKind(gun) == "c" and T.itemLevel(gun) == 0.7, T.itemLevel(gun))
check("clothing: condition", T.levelKind(socks) == "c" and T.itemLevel(socks) == 0.25)
check("clothing without condition: whole", T.levelKind(plain) == false and T.itemLevel(plain) == nil)
check("a torch: what is left", T.levelKind(torch) == "u" and T.itemLevel(torch) == 0.4)
check("a bottle: what is left", T.levelKind(bottle) == "f" and T.itemLevel(bottle) == 0.25)
check("nothing to tell: whole", T.levelKind(noState) == false and T.itemLevel(noState) == nil)
check("a pan: condition, not its water", T.levelKind(pan) == "c" and T.itemLevel(pan) == 0.5)
check("a weapon with no condition: whole", T.itemLevel(staff) == nil)
check("the kind told: asked as told", T.itemLevel(gun, "c") == 0.7 and T.itemLevel(gun, false) == nil)
check("a dry bottle: nothing left, not broken", T.itemLevel(item({fluid = fluid(0, 2)})) == 0)
check("no capacity: whole", T.levelKind(item({fluid = fluid(0, 0)})) == false)
local wreck = item({cls = "HandWeapon", cmax = 10, c = 3, broken = true})
check("broken: nothing, whatever else it says", T.itemLevel(wreck) == 0)
check("a broken torch: nothing", T.itemLevel(item({uses = 0.8, broken = true})) == 0)

-- on the ground the liquid is on the object in the world (QA, 2026-10-31)
local poured = item({world = {cls = "IsoWorldInventoryObject", getFluidContainer = function() return fluid(0.8, 2) end}})
check("a bottle on the ground: what is left", T.levelKind(poured) == "f" and T.itemLevel(poured) == 0.4)
check("on the ground, the kind known", T.itemLevel(poured, "f") == 0.4)
local dropped = item({world = {cls = "IsoWorldInventoryObject", getFluidContainer = function() return nil end}})
check("no liquid on the ground either: whole", T.levelKind(dropped) == false)

-- a slot asks what it is read from once
local kinds = 0
local realKind = T.levelKind
T.levelKind = function(it) kinds = kinds + 1 return realKind(it) end
local memo = {}
T.levelOf(memo, gun)
T.levelOf(memo, gun)
check("the slot's memory: asked once", kinds == 1 and T.levelOf(memo, gun) == 0.7, kinds)
T.levelOf(memo, torch)
check("another thing: asked again", kinds == 2 and T.levelOf(memo, torch) == 0.4, kinds)
T.levelKind = realKind

-- what a ready list goes by
check("key: no state", T.levelKey(noState, 48, nil) == -1)
check("key: dry", T.levelKey(item({}), 48, 0) == 0)
check("key: broken apart from dry", T.levelKey(item({broken = true}), 48, 0) == -2)
check("key: the colour's height", T.levelKey(gun, 48, 0.5) == 21)
check("key: a change that doesn't show, the same", T.levelKey(gun, 48, 0.5) == T.levelKey(gun, 48, 0.505))

-- how high the colour goes (the mockup's numbers: top y+3, bottom y+h-3) -----------
local X, Y, W, H = 10, 20, 48, 48
local function fillAt(level, h, a)
    clear()
    T.tileFill(ui, X, Y, W, h or H, level, CAT, a)
    return rects
end
local r = fillAt(nil)
check("no state: as full (the mockup)", #r == 2 and isCell(r[1]) and isCat(r[2]) and r[2].y == Y + 3 and r[2].y + r[2].h == Y + H - 2)
r = fillAt(0)
check("nothing left: the dark cell only", #r == 1 and isCell(r[1]) and r[1].w == W and r[1].h == H)
r = fillAt(0.5)
check("half: the dark cell, then the colour", #r == 2 and isCell(r[1]) and isCat(r[2]))
check("half: inside the 2 px frame", r[2].x == X + 2 and r[2].w == W - 4)
check("half: 21 of 42, from the bottom", r[2].y == Y + H - 3 - 21 and r[2].h == 22, r[2].y)
r = fillAt(1)
check("full: top y+3, down to the frame", r[2].y == Y + 3 and r[2].y + r[2].h == Y + H - 2, r[2].y)
r = fillAt(1.7)
check("more than full: full", r[2].y == Y + 3)
r = fillAt(0.01)
check("the least: 4 px, seen", r[2].h == 5 and r[2].y == Y + H - 3 - 4, r[2].h)
r = fillAt(0.5, 112)
check("2160p's tile: as high", r[2].y == Y + 112 - 3 - 53 and r[2].h == 54, r[2].y)
r = fillAt(0.5, nil, 0.4)
check("faded with the tile", r[1].a == 0.4 and r[2].a == 0.4)

-- the broken thing -----------------------------------------------------------------
clear()
T.brokenIcon(ui, wreck, 1, 2, 30, 0.5)
check("its picture x0.2, in its tint", #tex == 1 and tex[1].r == 0.2 and tex[1].g == 0.1 and tex[1].b == 0.05 and tex[1].a == 0.5)
clear()
T.brokenIcon(ui, item({mask = "m"}), 1, 2, 30, 1)
check("with a colour mask: just dark", tex[1].r == 0.2 and tex[1].g == 0.2 and tex[1].b == 0.2)
clear()
rendered = 0
local due = T.itemIcon(ui, wreck, 1, 2, 30, 1)
check("T.itemIcon: broken dimmed, its cross due", #tex == 1 and rendered == 0 and due == true)
clear()
due = T.itemIcon(ui, gun, 1, 2, 30, 1)
check("T.itemIcon: else as ever", #tex == 0 and rendered == 1 and due == false)

local asked = {}
local real = getTexture
getTexture = function(name)
    asked[name] = (asked[name] or 0) + 1
    return name
end
local function crossAt(w, h)
    clear()
    T.brokenMark(ui, 100, 200, w, h, 0.7)
    return tex[1]
end
local c = crossAt(56, 56)
check("a hotbar's tile: its size, red, faded", c.t == "media/ui/knox_cross_12.png" and c.r == T.color.bad.r and c.a == 0.7, c.t)
check("centred, 1:1", c.x == 100 + (56 - 28) / 2 and c.y == 200 + (56 - 28) / 2, c.x)
check("a grid's tile", crossAt(47, 47).t == "media/ui/knox_cross_10.png")
check("2160p's", crossAt(95, 95).t == "media/ui/knox_cross_20.png")
check("wide: by the short side", crossAt(95, 47).t == "media/ui/knox_cross_10.png")
check("tiny: the smallest there is", crossAt(10, 10).t == "media/ui/knox_cross_8.png")
check("huge: the largest", crossAt(1000, 1000).t == "media/ui/knox_cross_44.png")
check("read once", asked["media/ui/knox_cross_10.png"] == 1, asked["media/ui/knox_cross_10.png"])
getTexture = function() return nil end
-- (no picture: nothing, no error - a size not asked for yet)
clear()
T.brokenMark(ui, 0, 0, 200, 140, 1)
check("no picture: nothing drawn", #tex == 0)
getTexture = real

-- a key number readable over the colour
local texts = {}
local realDraw = T.drawText
T.drawText = function(_, s, x, y, cr, cg, cb, a) table.insert(texts, {s = s, x = x, y = y, r = cr, a = a}) end
T.outlinedLeft(ui, "3", 14, 21, T.color.dim, T.fontTile)
T.drawText = realDraw
check("four dark, then the number", #texts == 5 and texts[1].r == 0 and texts[5].r == T.color.dim.r and texts[5].x == 14 and texts[5].y == 21)
check("the outline: 0.9", texts[1].a == 0.9)
check("old meter gone", T.tileMeter == nil)

print(string.format("condition: %d pass, %d fail", pass, fail))
