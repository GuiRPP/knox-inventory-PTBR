-- The shots: the real KnoxEditor in states the author would look at.
function getModInfoByID(id) return {getName = function() return id == "TacticalGear" and "Tactical Gear" or id end} end
local E, D, T = KnoxEditor, KnoxEditorData, KnoxTheme
local W
local function settle(mx, my)
    W.x, W.y = 0, 0
    W.mx, W.my = mx or -500, my or -500
    for _ = 1, 40 do
        clock = clock + 16
        W:prerender()
    end
    REC = {}
    clock = clock + 16
    W:prerender()
    recBox(W.searchBox)
    recBox(W.nameBox)
end
local function open(ft)
    if E.instance then E.instance:close() end
    E.open(ft)
    W = E.instance
    W.x, W.y = 0, 0
end
local function take(name, mx, my)
    W:build()
    settle(mx, my)
    shot(name)
    print("shot " .. name .. " " .. W.L.w .. "x" .. W.L.h)
end
local function find(kind, s)
    for _, t in ipairs(W.ops) do if t.k == kind and t.s == s then return t end end
end
local function tx(k, ...) return getText("IGUI_KnoxEd_" .. k, ...) end

-- 1. the school bag: compartments; the mouse on a compartment
open("Base.Bag_Schoolbag")
take("01_bag_parts")
-- 2. a changed bag: one grid, wider; with "Changed" and the line
W:edit(function(o) o.bag.mode = "grid" o.bag.grid = {6, 6} end)
take("02_bag_grid_changed")
-- 3. the fanny pack cell by cell: two compartments drawn
open("Base.Bag_FannyPackFront")
W:edit(function(o)
    local ob = o.bag
    ob.mask = D.specToMask(ob.spec)
    D.maskCanvas(ob.mask)
    ob.mode = "mask"
    for y = 1, #ob.mask do for x = 1, #ob.mask[1] do ob.mask[y][x] = 0 end end
    for _, c in ipairs({{3, 1}, {4, 1}, {5, 1}, {6, 1}, {3, 2}, {4, 2}, {5, 2}, {6, 2}, {1, 1}, {1, 2}, {8, 1}, {8, 2}}) do ob.mask[c[2]][c[1]] = 1 end
    D.maskCanvas(ob.mask)
end)
take("03_bag_mask")
-- 4. the jacket: pockets, for every jacket
open("Base.Jacket_Padded")
W:edit(function(o) o.pockets = 8 o.all = true end)
take("04_clothing_pockets")
-- 5. the pistol made to stack
open("Base.Pistol")
W:edit(function(o) o.stackOn = true o.stack = 5 end)
take("05_stack")
-- 6. the pen: the category's list open
open("Base.Pen")
local dd = find("label", T.upper(tx("Category")))
W.eScroll, W.eTarget = 0, 0
for _, h in ipairs(W.hits) do
    if dd and h.reg == 2 and h.x <= dd.x and h.x + h.w > dd.x and h.y <= dd.y and h.y + h.h > dd.y then
        W.eTarget = math.max(0, math.min(W.eMax, h.y - W.L.viewY - W.L.viewH + h.h + T.cell * 4))
        W.eScroll = W.eTarget
        h.fn()
        break
    end
end
take("06_category_list")
W.popup = nil
-- 7. a search over every tab
open("Base.Pen")
W.searchBox:setText(STR["x:q_bag"])
W.searchBox.focused = true
settle()
take("07_search")
W.searchBox:setText("")
W.searchBox.focused = false
-- 8. the mods' tab
open("TG.TacticalPack")
W:goSide("mods")
take("08_mods_tab")
-- 9. presets: a Bags preset made and in use; the general one edited -> "overridden"
open("Base.Bag_Schoolbag")
local p = W:addPreset(STR["x:p_name"], "tab:bag", {})
W:setTarget(p)
W:setOn(p, true)
W:edit(function(o) o.bag.mode = "grid" o.bag.grid = {5, 5} end)
local mine = W.store.list[1]
W:setTarget(mine)
take("09_overridden_band")
-- 10. the presets' list and a preset's page
W:setTarget(p)
W:goSide("presets")
W.psel = p
take("10_preset_page")
-- 11. a new preset
W.psel = "new"
W.nScope, W.nCat = "cat", "clo"
W.fieldFor = nil
take("11_new_preset")
-- 12. import from the clipboard, with errors
CLIP = table.concat({"# Knox Inventory preset", STR["x:imp_name"], "# for = mod TacticalGear",
    "TG.TacticalPack = grid 5x6", "TG.Vest = pockets.all 6", "TG.Knife = 1x2 stack 1", "Base.Axe = 1x3",
    "No.Such = 1x1", STR["x:imp_bad"]}, "\n")
W.psel = "import"
W.impRows = nil
W:build()
W:loadImport(D.splitLines(CLIP), "clip")
take("12_import")
-- 13. the changed tab, the reset asked
W:goSide("changed")
W.resetAsk = true
take("13_changed_reset_ask")
-- 14. 1280x720
W:close()
SCREEN.w, SCREEN.h = 1280, 720
T.refresh()
open("Base.Bag_ALICEpack")
take("14_720_bag")
W:goSide("presets")
W.psel = W:target()
take("15_720_presets")
W:close()
-- 16. dev: the mod's defaults
SCREEN.w, SCREEN.h = 1920, 1080
T.refresh()
KnoxTestBench = {devOn = function() return true end}
open("Base.Hammer")
W.layer = "mod"
W:edit(function(o) o.w, o.h = 1, 3 end)
take("16_dev_defaults")
-- news: the military backpack's compartments (the main one chosen), at 1080
KnoxTestBench = nil
open("Base.Bag_ALICEpack")
take("20_alice")
-- news: the big hiking backpack drawn cell by cell, the mouse on the canvas
open("Base.Bag_BigHikingBag")
W:edit(function(o)
    local ob = o.bag
    local rows = {"..xxxxx..", ".........", "x.xxxxx.x", "x.xxxxx.x", "..xxxxx..", "..xxxxx.."}
    ob.mask = {}
    for y, r in ipairs(rows) do
        ob.mask[y] = {}
        for x = 1, #r do ob.mask[y][x] = string.sub(r, x, x) == "x" and 1 or 0 end
    end
    D.maskCanvas(ob.mask)
    ob.mode = "mask"
end)
take("21_mask_hiking")
