-- An equipment slot with its ready list (KnoxEquipSlot:render, the inventory's FPS
-- stage 2, 2026-10-29) on the game's Lua with tools/settings/stubs.lua, the real
-- KnoxTheme and KnoxEquipment and a made-up Java part: the slot is written once and
-- played back while it shows the same; under the mouse, with its pick panel open or
-- with an item held over it, it is drawn by Lua as before; the marks over the frame (a
-- move's progress, the item in use, a hint) are drawn after the list, also when it plays.
local T = KnoxTheme
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

-- the Java part: lists begun, ended, played
local J = {begun = 0, ended = 0, played = 0}
local lists = {}
knoxListBegin = function(jo, id) J.begun = J.begun + 1 J.rec = id end
knoxListEnd = function() J.ended = J.ended + 1 lists[J.rec] = true J.rec = nil return true end
knoxListDraw = function(jo, id)
    if not lists[id] then return 0 end
    J.played = J.played + 1
    return 2
end

-- what the slot reads of the rest of Knox
local moving = {leaving = nil, progress = nil, arriving = false}
KnoxGrid.pendingOf = function() return nil end
KnoxGrid.leavingSlot = function() return moving.leaving, moving.progress end
KnoxGrid.arrivingSlot = function() return moving.arriving end
KnoxGrid.useOf = function() return moving.use end
KnoxGrid.pendingList = function() return {} end
KnoxDrag = {isActive = function() return moving.drag == true end, entity = {}}
KnoxSlotPicker = {isOpenFor = function() return moving.picker == true end, want = function() end}
KnoxTooltip = {want = function() end}
ISInventoryItem = {renderItemIcon = function(ui) ui:drawRect() end}
T.categoryOf = function() return "misc" end
T.category.misc = T.category.misc or {r = 0.2, g = 0.2, b = 0.2}
function instanceof(o, kind) return o.kind == kind end

local function item(name, kind, cond)
    return {name = name, kind = kind, getConditionMax = function() return cond and 10 or 0 end,
            getCondition = function() return cond or 0 end, getFullType = function() return name end}
end

local hat, cap = item("Hat", "Clothing", 7), item("Cap", "Clothing", 10)
local panel = {playerNum = 0, worn = {head = {hat}}, pendingNow = {}}
function panel:player() return PLAYER end
local slot = KnoxEquipSlot:new(panel, "wear", "head", "Head")
slot:setWidth(60)
slot:setHeight(70)
local overSlot = false
function slot:isMouseOver() return overSlot end
-- (what fits it and whether a held item may go here: not this test's)
function slot:candidates() return {} end
function slot:accepts() return true end

-- one frame: how many draws Lua made
local function frame()
    J.begun, J.ended, J.played = 0, 0, 0
    DRAWN = 0
    clock = clock + 16
    slot:render()
    return DRAWN
end

-- (an item just shown in the slot settles in for 160 ms: frames past that)
local function settle()
    for _ = 1, 15 do frame() end
end

do
    local first = frame()
    check("first frame: written", J.begun == 1 and J.ended == 1 and first > 0, first)
    check("second frame: played, Lua draws nothing", frame() == 0 and J.played == 1 and J.begun == 0)
    check("third frame: played", frame() == 0 and J.played == 1)
end

do
    overSlot = true
    local n = frame()
    check("under the mouse: Lua draws it all", n > 0 and J.begun == 0 and J.played == 0, n)
    overSlot = false
    check("mouse gone: played again", frame() == 0 and J.played == 1)
    moving.picker = true
    check("pick panel open: Lua draws", frame() > 0 and J.played == 0 and J.begun == 0)
    moving.picker = nil
    check("pick panel shut: played", frame() == 0 and J.played == 1)
end

do
    -- another item comes into the slot: written anew, its settling in each frame
    panel.worn.head = {cap}
    check("new item: written", frame() > 0 and J.begun == 1)
    local written = 0
    for _ = 1, 15 do
        frame()
        written = written + J.begun
    end
    check("settling in: written while it moves", written >= 5, written)
    frame()
    check("settled: played", frame() == 0 and J.played == 1)
end

do
    -- the condition drops: written anew
    hat.getCondition = function() return 3 end
    panel.worn.head = {hat}
    settle()
    check("worse condition: played once settled", frame() == 0 and J.played == 1)
    hat.getCondition = function() return 2 end
    check("condition changes: written", frame() > 0 and J.begun == 1)
end

do
    -- two layers: the counter and the arrows, the layer shown is in the key
    panel.worn.head = {hat, cap}
    frame()
    check("two layers: played after", frame() == 0 and J.played == 1)
    slot.layer = 2
    check("other layer: written", frame() > 0 and J.begun == 1)
    settle()
    check("other layer: played", frame() == 0 and J.played == 1)
    slot.layer = 1
    panel.worn.head = {hat}
    settle()
end

do
    -- marks over the frame: drawn by Lua after the played list
    moving.progress = 0.5
    local n = frame()
    check("a move's progress: drawn over the played list", n > 0 and J.played == 1 and J.begun == 0, n)
    moving.progress = nil
    moving.arriving = true
    n = frame()
    check("a hint: drawn over the played list", n > 0 and J.played == 1, n)
    moving.arriving = false
    check("marks gone: nothing from Lua", frame() == 0)
end

do
    -- an item held over another slot changes nothing here; over this one - Lua
    moving.drag = true
    check("dragging elsewhere: played", frame() == 0 and J.played == 1)
    overSlot = true
    KnoxDrag.entity.item = cap
    KnoxDrag.entity.fromBody = false
    check("dragged over it: Lua draws", frame() > 0 and J.played == 0)
    overSlot = false
    moving.drag = nil
end

do
    -- the item leaving the slot (a move away): faded, with its own key
    moving.leaving = cap
    panel.worn.head = {}
    check("leaving: written", frame() > 0 and J.begun == 1)
    moving.leaving = nil
    check("empty slot: written", frame() > 0 and J.begun == 1)
    check("empty slot: played", frame() == 0 and J.played == 1)
end

do
    -- the lists switched off for the measure: Lua alone
    T.listsOff = true
    check("lists off: Lua draws", frame() > 0 and J.played == 0 and J.begun == 0)
    T.listsOff = nil
    check("lists on: written", frame() > 0 and J.begun == 1)
end

print("slot: " .. pass .. " pass, " .. fail .. " fail")
