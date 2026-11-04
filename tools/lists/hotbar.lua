-- The game's hotbar with its ready list (KnoxHotbar.lua, the overhaul's stage 3, 2026-11-04) on
-- the game's Lua with tools/settings/stubs.lua, the real KnoxTheme, KnoxHotbarOrder and KnoxHotbar
-- and a made-up Java part: written once and played back while it shows the same; anything it
-- shows changing is drawn anew, and all that moves or answers the mouse is drawn by Lua as before.
local T = KnoxTheme
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

local J = {begun = 0, ended = 0, played = 0, ready = {}}
local lists = {}
-- the screen: every draw of the bar as a line, and the lines each list holds
local screen = {}
local function mark(...)
    local line = ""
    for i = 1, select("#", ...) do line = line .. " " .. tostring(select(i, ...)) end
    screen[#screen + 1] = line
    if J.rec then table.insert(lists[J.rec], line) end
end
knoxListBegin = function(jo, id) J.begun = J.begun + 1 J.rec = id lists[id] = {} J.ready[id] = nil end
knoxListEnd = function() J.ended = J.ended + 1 J.ready[J.rec] = true J.rec = nil return true end
knoxListDraw = function(jo, id)
    if not J.ready[id] then return 0 end
    J.played = J.played + 1
    for _, line in ipairs(lists[id]) do screen[#screen + 1] = line end
    return 2
end

-- what is drawn: the icons, the rects and the texts
local D = {icons = 0}
ISInventoryItem = {renderItemIcon = function(ui, item, ...) D.icons = D.icons + 1 mark("icon", item.name, ...) end}
T.categoryOf = function(item) return item and item.cat or "misc" end
T.category.misc = T.category.misc or {r = 0.2, g = 0.2, b = 0.2}
T.category.food = T.category.food or {r = 0.1, g = 0.5, b = 0.1}
local drawText0 = T.drawText
T.drawText = function(ui, text, ...) mark("text", text, ...) end

local function item(name, cond)
    local it = {name = name, kind = "Item", cond = cond, cat = "misc", broken = false}
    it.isBroken = function() return it.broken end
    it.getConditionMax = function() return it.cond and 10 or 0 end
    it.getCondition = function() return it.cond or 0 end
    it.IsDrainable = function() return false end
    it.getFluidContainer = function() return nil end
    it.getWorldItem = function() return nil end
    it.getFullType = function() return name end
    it.getTex = function() return nil end
    return it
end
local function gun(name, ammo, max)
    local g = item(name, 10)
    g.kind = "HandWeapon"
    g.ammo, g.max = ammo, max
    g.isRanged = function() return true end
    g.getCurrentAmmoCount = function() return g.ammo end
    g.getMaxAmmo = function() return g.max end
    return g
end
-- (a thing's level is read from its kind: the theme's own, on the stand-ins)
local levelKind0 = T.levelKind
T.levelKind = function(it)
    if it.cond then return "c" end
    return false
end

local chr = {hand = nil, off = nil}
chr.getPrimaryHandItem = function() return chr.hand end
chr.getSecondaryHandItem = function() return chr.off end
chr.getPlayerNum = function() return 0 end

local hb = ISHotbar.new and setmetatable({}, ISHotbar) or {}
ISPanel.new(hb, 0, 0, 600, 60)
setmetatable(hb, ISHotbar)
hb.playerNum, hb.chr, hb.width, hb.height, hb.margins, hb.slotWidth, hb.slotHeight, hb.slotPad = 0, chr, 600, 60, 4, 60, 60, 4
hb.javaObject = {}
hb.availableSlot = {
    {slotType = "Back", name = "Back", def = {attachments = {}}},
    {slotType = "Belt", name = "Belt", def = {attachments = {}}},
    {slotType = "Holster", name = "Holster", def = {attachments = {}}},
}
hb.attachedItems = {}
local MX, MY = 2000, 2000
function hb:getMouseX() return MX end
function hb:getMouseY() return MY end
function hb:isMouseOver() return MX >= 0 and MY >= 0 and MX < self.width and MY < self.height end
function hb:setHeight(v) self.height = v end
function hb:setWidth(v) self.width = v end
function hb:setX() end
function hb:getAbsoluteX() return 0 end
function hb:getAbsoluteY() return 0 end
function hb:setVisible() end
function hb:canBeAttached() return true end
for _, m in ipairs({"drawRect", "drawRectBorder", "drawTextureScaled", "drawTextureScaledAspect"}) do
    hb[m] = function(self, ...) mark(m, ...) end
end

local function frames(n)
    for _ = 1, n or 1 do
        clock = clock + 16
        hb:render()
    end
end
--- Lets what changed be seen, what is settling in settle, and the list be written.
local function settle()
    frames(1)
    clock = clock + 1000
    frames(6)
end
local function counted(n)
    local b, p, i = J.begun, J.played, D.icons
    frames(n or 1)
    return J.begun - b, J.played - p, D.icons - i
end

--- One frame's picture.
local function shot()
    screen = {}
    clock = clock + 16
    hb:render()
    return table.concat(screen, ";")
end
local function has(s, what) return string.find(s, what, 1, true) ~= nil end
--- What the list plays is what Lua draws. Gives the picture.
local function sameAsLua(name)
    settle()
    local p0 = J.played
    local fromList = shot()
    check(name .. ": played", J.played == p0 + 1, J.played - p0)
    T.listsOff = true
    local byLua = shot()
    T.listsOff = nil
    check(name .. ": the list draws what Lua draws", fromList == byLua, fromList .. " <> " .. byLua)
    return fromList
end

T.listsOff = nil
KnoxSettings = nil
local torch = item("Torch", 8)
hb.attachedItems[2] = torch

-- written once, then played
settle()
check("written once", J.begun == 1 and J.ended == 1, J.begun)
local nb, np, ni = counted(5)
check("then played: not written again", nb == 0, nb)
check("then played: every frame", np == 5, np)
check("then played: no icons from Lua", ni == 0, ni)

-- the mouse on it: Lua, as before; off it again: the same list
MX, MY = 100, 30
nb, np, ni = counted(5)
check("mouse on it: not played", np == 0, np)
check("mouse on it: not written", nb == 0, nb)
check("mouse on it: drawn by Lua", ni == 5, ni)
MX, MY = hb.width + 10, 30
nb, np = counted(3)
check("mouse past the right edge, within the hands' reach: drawn by Lua (the slot answers there)", np == 0, np)
MX, MY = hb.width + 2000, 30
nb, np = counted(3)
check("mouse far past the right edge: played", np == 3 and nb == 0, np)
MX, MY = -50, 30
nb, np = counted(3)
check("mouse left of it: played", np == 3 and nb == 0, np)
MX, MY = 100, -5
nb, np = counted(3)
check("mouse just above it: played", np == 3 and nb == 0, np)
MX, MY = 100, hb.height + 5
nb, np = counted(3)
check("mouse just below it: played", np == 3 and nb == 0, np)
MX, MY = 2000, 2000
nb, np = counted(3)
check("mouse off: played without writing", nb == 0 and np == 3, nb .. " " .. np)

-- the first thing a slot ever has comes without settling, as it did
local b0 = J.begun
local axe = item("Axe", 5)
hb.attachedItems[1] = axe
nb, np = counted(1)
check("first hung: not played that frame", np == 0, np)
settle()
check("first hung: written anew", J.begun == b0 + 1, J.begun - b0)

-- taken off
b0 = J.begun
hb.attachedItems[1] = nil
nb, np = counted(1)
check("taken off: not played that frame", np == 0, np)
settle()
check("taken off: written anew", J.begun == b0 + 1, J.begun - b0)

-- another thing hung: it settles in by Lua, frame by frame, and is written only when settled
b0 = J.begun
hb.attachedItems[1] = item("Saw", 5)
nb, np, ni = counted(3)
check("hung: not played", np == 0, np)
check("hung: not written while it settles", nb == 0, nb)
check("hung: its settling is Lua's", ni == 6, ni)
settle()
check("hung: written once when settled", J.begun == b0 + 1, J.begun - b0)
nb, np = counted(3)
check("hung: played after", nb == 0 and np == 3, nb .. " " .. np)

-- a slot's faint picture: other clothes giving the same slot change it on the same table
b0 = J.begun
hb.availableSlot[3].texture = "BeltPicture"
settle()
check("an empty slot's picture: written anew", J.begun == b0 + 1, J.begun - b0)
check("an empty slot's picture: on the screen", has(sameAsLua("an empty slot"), "BeltPicture"))
hb.availableSlot[3].texture = "WebbingPicture"
settle()
local pic = shot()
check("another picture on the same slot: on the screen", has(pic, "WebbingPicture") and not has(pic, "BeltPicture"), pic)
hb.availableSlot[3].texture = nil
settle()
check("the picture gone: off the screen", not has(shot(), "WebbingPicture"))

-- a thing's height changing shows within the round of its tiles, without a word
b0 = J.begun
torch.cond = 2
frames(6)
check("worn down: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
torch.cond = 2.0001
frames(12)
check("a change that doesn't show: not written", J.begun == b0, J.begun - b0)
torch.broken = true
frames(12)
check("broken: written anew", J.begun >= b0 + 1, J.begun - b0)
sameAsLua("broken")
torch.broken = false
torch.cond = 8
sameAsLua("worn")
-- its colour
b0 = J.begun
torch.cat = "food"
frames(12)
check("another colour: written anew", J.begun == b0 + 1, J.begun - b0)
torch.cat = "misc"
settle()

-- in hand: the frame on the slot, the hands' tiles
b0 = J.begun
chr.hand = torch
nb, np = counted(1)
check("taken in hand: not played that frame", np == 0, np)
settle()
check("taken in hand: written anew", J.begun == b0 + 1, J.begun - b0)
sameAsLua("in hand")
chr.hand = item("Knife", 5)
settle()
-- another thing in that hand: it settles in by Lua, and is written only when settled
b0 = J.begun
chr.hand = item("Spoon", 5)
nb, np = counted(3)
check("another in hand: not played", np == 0, np)
check("another in hand: not written while it settles", nb == 0, nb)
settle()
check("another in hand: written once when settled", J.begun == b0 + 1, J.begun - b0)
-- the left hand
chr.hand = nil
settle()
chr.off = item("Fork", 5)
nb, np = counted(1)
check("taken in the left hand: not played that frame", np == 0, np)
chr.off = nil
settle()
-- the same thing in both hands
local spade = item("Spade", 5)
chr.hand, chr.off = spade, spade
sameAsLua("both hands")
chr.off = nil
nb, np = counted(1)
check("a hand let go: not played that frame", np == 0, np)
chr.hand = nil
settle()

-- the hands' tiles are in the round of tiles too: a thing wears down in hand most of all
local club = item("Club", 8)
chr.hand = club
settle()
b0 = J.begun
club.cond = 2
frames(12)
check("worn in the right hand: written anew", J.begun == b0 + 1, J.begun - b0)
chr.hand, chr.off = nil, club
settle()
b0 = J.begun
club.cond = 5
frames(12)
check("worn in the left hand: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
club.cat = "food"
frames(12)
check("another colour in the left hand: written anew", J.begun == b0 + 1, J.begun - b0)
chr.off = nil
settle()

-- a gun in hand: its rounds at once
local pistol = gun("Pistol", 7, 15)
chr.hand = pistol
check("gun: its rounds drawn", has(sameAsLua("a gun in hand"), "7/15"))
b0 = J.begun
nb, np = counted(2)
check("gun: played", np == 2 and nb == 0, np)
pistol.ammo = 6
nb, np = counted(1)
check("a shot: not played that very frame", np == 0, np)
frames(3)
check("a shot: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
pistol.max = 30
nb, np = counted(1)
check("a bigger magazine: not played that frame", np == 0, np)
frames(3)
check("a bigger magazine: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
chr.off = gun("Pistol2", 3, 15)
settle()
b0 = J.begun
chr.off.ammo = 2
frames(3)
check("the left hand's gun too", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
chr.off.max = 30
nb, np = counted(1)
check("the left hand's bigger magazine: not played that frame", np == 0, np)
frames(3)
check("the left hand's bigger magazine: written anew", J.begun == b0 + 1, J.begun - b0)
chr.hand, chr.off = nil, nil
settle()

-- whatever moves or answers: Lua
local function byLua(name, on, off)
    settle()
    on()
    local nb1, np1 = counted(3)
    check(name .. ": not played", np1 == 0, np1)
    check(name .. ": not written", nb1 == 0, nb1)
    off()
    frames(4)
    local nb2, np2 = counted(2)
    check(name .. ": played again after", np2 == 2 and nb2 == 0, np2)
end
byLua("a thing dragged", function() ISMouseDrag.dragging = {} end, function() ISMouseDrag.dragging = nil end)
byLua("a slot moved", function() MOUSE.down[0] = true hb.knoxSlotDrag = {index = 1, x = 0, y = 0} end,
    function() MOUSE.down[0] = nil hb.knoxSlotDrag = nil end)
byLua("a thing moved from the hand", function() MOUSE.down[0] = true hb.knoxHandDrag = {item = torch, x = 0, y = 0} end,
    function() MOUSE.down[0] = nil hb.knoxHandDrag = nil end)
byLua("a pick panel open", function() KnoxSlotPicker.instance = {} end, function() KnoxSlotPicker.instance = nil end)
byLua("the settings open", function() KnoxSettings = {instance = {}} end, function() KnoxSettings = nil end)
byLua("lists off (the bench's auto measure)", function() T.listsOff = true end, function() T.listsOff = nil end)

-- the bar itself: its slots, their order, its size
settle()
b0 = J.begun
table.insert(hb.availableSlot, {slotType = "Rifle", name = "Rifle", def = {attachments = {}}})
settle()
check("another slot: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
hb.availableSlot[4] = {slotType = "Other", name = "Other", def = {attachments = {}}}
settle()
check("a slot of another kind in its place: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
local gone = table.remove(hb.availableSlot)
settle()
check("a slot gone: written anew", J.begun == b0 + 1, J.begun - b0)
table.insert(hb.availableSlot, gone)
settle()
b0 = J.begun
T.settings["hotbar.order"] = "Rifle,Back"
settle()
check("another order: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
hb.width = 700
settle()
check("another width: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
T.listEpoch = T.listEpoch + 1
settle()
check("the look changed: written anew", J.begun == b0 + 1, J.begun - b0)
b0 = J.begun
KnoxMagKnown = {hide = true}
settle()
check("the rounds hidden: written anew", J.begun == b0 + 1, J.begun - b0)
KnoxMagKnown = nil
settle()

-- the hands' part gone with the Knox look off
b0 = J.begun
local forPlayer0 = Knox.forPlayer
Knox.forPlayer = function() return false end
settle()
check("no hands: written anew", J.begun == b0 + 1, J.begun - b0)
Knox.forPlayer = forPlayer0
settle()

-- the Knox screen open: nothing at all
KnoxScreen = {instance = {}}
local a0, b1, p1 = D.icons, J.begun, J.played
frames(3)
check("the Knox screen open: nothing", D.icons == a0 and J.begun == b1 and J.played == p1)
KnoxScreen = nil
settle()

-- a Lua error in the frame being written, then the mouse on the bar (no T.listDraw then):
-- Java stops writing at once, what is drawn under the mouse stays out of the list
settle()
hb.width = hb.width + 5
local outlined0 = T.outlinedLeft
T.outlinedLeft = function() error("boom") end
clock = clock + 16
local fine = pcall(hb.render, hb)
T.outlinedLeft = outlined0
check("a frame failed while written", not fine and J.rec ~= nil, tostring(J.rec))
MX, MY = 100, 30
local glow = shot()
check("under the mouse: Lua draws the glow", has(glow, "0.06 1 1 1"), glow)
check("under the mouse: the list is shut", J.rec == nil, tostring(J.rec))
MX, MY = 2000, 2000
b0 = J.begun
settle()
check("off the bar: written anew", J.begun == b0 + 1, J.begun - b0)
local off = shot()
check("off the bar: no glow played back", not has(off, "0.06 1 1 1"), off)

-- a list Java could not play back: Lua from now on
local draw0 = knoxListDraw
knoxListDraw = function() return 0 end
frames(12)
knoxListDraw = draw0
nb, np, ni = counted(3)
check("a list that fails: Lua from now on", np == 0 and nb == 0 and ni > 0, np)

T.levelKind = levelKind0
T.drawText = drawText0
print("hotbar: " .. pass .. " pass, " .. fail .. " fail")
