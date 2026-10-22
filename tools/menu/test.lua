-- Knox's context menu outside the game (tools/menu/test.ps1): the layout is asked
-- every frame and made anew only when something it reads has changed - the
-- options, an icon or a reason set after addOption, a sub menu filled later,
-- "Other" opening, the sizes, the gamepad - and kept otherwise.

local K = KnoxContextMenu
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else
        fail = fail + 1
        print("FAIL " .. name .. " : " .. tostring(detail))
    end
end

local function frame(menu, n)
    for _ = 1, n or 1 do
        clock = clock + 16
        menu:prerender()
    end
end
local function builds(menu) return menu.knoxLayoutN or 0 end
local function rowOf(menu, option)
    for _, r in ipairs(menu.knoxL.rows) do
        if r.kind == "opt" and menu.options[r.i] == option then return r end
    end
    return nil
end
local P = ISInventoryPaneContextMenu

-- a plain menu (not about Knox's items) ------------------------------------------
local m = getPlayerContextMenu(0)
m:clear()
local a = m:addOption("Something", nil, function() end)
local b = m:addOption("Something else", nil, function() end)
frame(m)
local n0, L0 = builds(m), m.knoxL
frame(m, 60)
check("a menu standing still is laid out once", builds(m) == n0 and m.knoxL == L0, builds(m) - n0)

-- the game sets an option's picture right after addOption: the names move right
local w0 = m.knoxL.w
b.iconTexture = getTexture("media/ui/x.png")
frame(m)
check("an icon set after addOption: laid out anew", builds(m) == n0 + 1, builds(m) - n0)
check("... and the menu wider by the icon column", m.knoxL.w == w0 + m.knoxIcon + m.knoxGap, m.knoxL.w - w0)
frame(m, 10)
check("... then kept again", builds(m) == n0 + 1, builds(m) - n0)

-- an option made unavailable, with its reason
b.notAvailable = true
b.toolTip = {description = "<RGB:1,0,0> Needs a can opener <LINE> more"}
frame(m)
local r = rowOf(m, b)
check("unavailable: laid out anew with its reason", r and r.reason == "Needs a can opener", r and r.reason)
b.toolTip.description = "Too heavy"
frame(m)
r = rowOf(m, b)
check("its reason changed: shown", r and r.reason == "Too heavy", r and r.reason)

-- a new option: in the list at once
local nb = builds(m)
local c = m:addOption("Third", nil, function() end)
frame(m)
check("an option added: in the layout", rowOf(m, c) ~= nil and builds(m) > nb, builds(m) - nb)
nb = builds(m)
frame(m, 10)
check("... and kept after", builds(m) == nb, builds(m) - nb)

-- a short sub menu filled after its row was laid out: chips on the row
local eat = m:addOption("ContextMenu_Eat", nil, nil)
local sub = m:getNew(m)
m:addSubMenu(eat, sub)
frame(m)
check("an empty sub menu: no chips yet", rowOf(m, eat) and rowOf(m, eat).chips == nil, "chips")
sub:addOption("ContextMenu_Eat_All", nil, P.onEatItems)
sub:addOption("ContextMenu_Eat_Half", nil, P.onEatItems)
frame(m)
r = rowOf(m, eat)
check("its options came: the row has chips", r and r.chips and #r.chips == 2, r and r.chips and #r.chips)

-- the gamepad: no chips (its sub menu stays)
JoypadState.players[1] = {}
frame(m)
r = rowOf(m, eat)
check("a gamepad: chips gone", r and r.chips == nil, "chips")
JoypadState.players[1] = nil
frame(m)
r = rowOf(m, eat)
check("the mouse again: chips back", r and r.chips and #r.chips == 2, "chips")

-- the sizes
nb = builds(m)
KnoxTheme.cell = 64
frame(m)
check("the cell size changed: laid out anew", builds(m) > nb and m.itemHgt == math.floor(64 * 0.67 + 0.5), m.itemHgt)
KnoxTheme.cell = 48
frame(m)

-- the same option tables, wiped and filled anew (the game's option pool)
local before = {}
for _, o in ipairs(m.options) do before[o] = true end
m:clear()
local x1 = m:addOption("Fresh one", nil, function() end)
local x2 = m:addOption("Fresh two", nil, function() end)
frame(m)
check("the pool gives the same tables back", before[x1] == true or before[x2] == true, "new tables")
check("... and the menu shows the new names", rowOf(m, x1) ~= nil and rowOf(m, x2) ~= nil and #m.knoxL.rows == 2,
    #m.knoxL.rows)

-- an item's menu: its header (the tooltip's) and "Other" folding ------------------
local item = {classes = {InventoryItem = true}}
function item:getFullType() return "Base.Apple" end
function item:getName() return "Apple" end
function item:getDisplayName() return "Apple" end
K.setTarget({item}, 0)
m:clear()
m:addOption("ContextMenu_Eat", item, P.onEatItems)
m:addOption("ContextMenu_Wear", item, P.onWearItems)
local o1 = m:addOption("Other mod's thing", item, function() end)
m:addOption("Another mod's thing", item, function() end)
m:addOption("ContextMenu_Drop", item, P.onDropItems)
frame(m)
check("an item's menu has its header", m.knoxL.rows[1].kind == "head", m.knoxL.rows[1].kind)
local h0 = KnoxTooltip.headers
nb = builds(m)
frame(m, 60)
check("its header is not made again while it stands", KnoxTooltip.headers == h0 and builds(m) == nb,
    (KnoxTooltip.headers - h0) .. " headers")
r = rowOf(m, o1)
check("\"Other\" folded", r and r.fold and r.h == 0, r and r.h)
m.knoxOtherWant = true
local moving = 0
for _ = 1, 30 do
    local n = builds(m)
    frame(m)
    if builds(m) > n then moving = moving + 1 end
end
r = rowOf(m, o1)
check("\"Other\" opening: laid out while it moves (170 ms)", moving >= 9 and moving <= 13, moving)
check("... open in the end", r and r.h == r.fullH, r and r.h)
nb = builds(m)
frame(m, 20)
check("... then kept", builds(m) == nb, builds(m) - nb)

-- a sub menu's layout follows its parent's (its header comes from its option)
local holder = m:addOption("Sub holder", item, nil)
local s2 = m:getNew(m)
m:addSubMenu(holder, s2)
s2:addOption("Inside", item, function() end)
frame(m)
frame(s2)
local sn = builds(s2)
frame(s2, 10)
check("a sub menu standing still is kept", builds(s2) == sn, builds(s2) - sn)
m.knoxOtherWant = false
frame(m)
frame(s2)
check("its parent laid out anew: the sub menu too", builds(s2) == sn + 1, builds(s2) - sn)

print("DONE pass=" .. pass .. " fail=" .. fail)
