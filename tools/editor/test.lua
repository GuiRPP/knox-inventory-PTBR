-- KnoxEditor.lua (the item editor, the author 2026-10-25) on the game's Lua with
-- tools/settings/stubs.lua and tools/editor/stubs.lua, over the real KnoxTheme,
-- KnoxFootprint, KnoxGrid, KnoxBagShapes, KnoxPresets: the player's old lines
-- become a preset, every item has a record, every tab and page draws (at 1080 and
-- 720), edits make the lines they should and Save puts them in effect (sizes, a
-- bag's shape, stacks, pockets), presets are made, put in use, exported, imported,
-- deleted, reset; a frame draws without building anew; the author's defaults.
local T, E, D, P, F, G = KnoxTheme, KnoxEditor, KnoxEditorData, KnoxPresets, KnoxFootprint, KnoxGrid
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info ~= nil and (": " .. tostring(info)) or "")) end
end
local function run(name, f)
    local ok, err = pcall(f)
    check(name, ok, err)
end
local function tx(k) return getText("IGUI_KnoxEd_" .. k) end

local W
local function frames(n)
    for _ = 1, n or 1 do
        clock = clock + 16
        W:prerender()
    end
end
local function open(ft)
    if E.instance then E.instance:close() end
    E.open(ft)
    W = E.instance
    frames(2)
end
--- the drawing step of a button (or a label) with this text
local function find(kind, s)
    for _, t in ipairs(W.ops) do
        if t.k == kind and t.s == s then return t end
    end
    return nil
end
--- scroll its page so it shows, then press it
local function pressOp(t)
    local L = W.L
    if t.reg == 2 then
        W.eTarget = math.max(0, math.min(W.eMax, t.y - L.viewY - 10))
        W.eScroll = W.eTarget
    elseif t.reg == 1 then
        W.lTarget = math.max(0, math.min(W.lMax, t.y - W.listView[2] - 4))
        W.lScroll = W.lTarget
    end
    local x, y = t.x + math.floor(t.w / 2), t.y + W:dyOf(t.reg) + math.floor(t.h / 2)
    W.mx, W.my = x, y
    W:onMouseDown(x, y)
    W:onMouseUp(x, y)
    frames(1)
end
local function press(key)
    local t = find("button", tx(key))
    check("button " .. key, t ~= nil)
    if t then pressOp(t) end
end
local function target() return W:target() end
local function line(ft)
    local o = target().items[ft]
    return o and P.restOf(o) or nil
end
--- every step of the window's own region inside it; nothing left in a stencil
local function inside(name)
    local L = W.L
    local bad = nil
    for _, t in ipairs(W.ops) do
        if t.reg == 0 and t.x and t.w then
            local w = t.w
            if t.k == "label" and t.align == "left" then w = math.max(w, T.measure(t.font, t.s)) end
            if t.x < 0 or t.y < 0 or t.x + w > L.w + 1 or t.y + (t.h or 0) > L.h + 1 then bad = (t.s or t.k) .. " @" .. t.x .. "," .. t.y end
        end
    end
    check(name .. ": inside the window", bad == nil, bad)
    check(name .. ": stencils even", W.stencils == 0, W.stencils)
end

-- the player's old lines became "My preset" ----------------------------------------
run("migrated", function()
    local s = P.store
    check("one preset", s and #s.list == 1, s and #s.list)
    local p = s.list[1]
    check("my preset in use", p.on == true and s.edit == p.file, p.file)
    check("its line", p.items["Base.Axe"] and p.items["Base.Axe"].h == 3)
    check("backup kept", FILES["knox_overrides_backup.txt"] ~= nil)
    check("old line a note", string.find(FILES["knox_overrides.txt"], "# (in the preset", 1, true) ~= nil, FILES["knox_overrides.txt"])
    check("index written", string.find(FILES["knox_presets/index.txt"] or "", "preset = " .. p.file .. " on", 1, true) ~= nil)
    check("in effect", F.overrides["Base.Axe"] and F.overrides["Base.Axe"].h == 3)
end)

-- the items and their records -----------------------------------------------------------
run("items", function()
    local l = D.items()
    check("all but the hidden", #l == #SCRIPTS - 1, #l)
    local want = {["Base.Bag_Schoolbag"] = "bag", ["Base.Jacket_Padded"] = "clo", ["Base.Axe"] = "wpn", ["Base.Bullets9mm"] = "ammo",
                  ["Base.TinnedBeans"] = "food", ["Base.Bandage"] = "med", ["Base.Hammer"] = "tool", ["Base.Nails"] = "mat",
                  ["Base.Book"] = "info", ["Base.Pen"] = "misc", ["TG.TacticalPack"] = "bag"}
    for ft, s in pairs(want) do check("side " .. ft, D.byType(ft).side == s, D.byType(ft).side) end
    check("mod of a mod's item", D.byType("TG.Vest").mod == "TacticalGear")
    check("no mod of the game's", D.byType("Base.Axe").mod == nil)
    check("group: backpacks", D.byType("Base.Bag_Schoolbag").grp == "Grp_back")
    check("group: a mod's bag", D.byType("TG.TacticalPack").grp == "Grp_mods")
    check("per place", D.perLoc.jacket == 2, D.perLoc.jacket)
end)

run("records", function()
    for _, d in ipairs(SCRIPTS) do
        if not d.hidden then
            local ok, r = pcall(D.recordOf, instanceItem(d.ft))
            check("record " .. d.ft, ok and r ~= nil, r)
        end
    end
    local p = P.store.list[1]
    local bag = D.recordIn(p, "Base.Bag_Schoolbag")
    check("bag record", bag and bag.kind == "bag" and bag.bag and #bag.bag.spec >= 1)
    local jk = D.recordIn(p, "Base.Jacket_Padded")
    check("jacket pockets", jk and jk.kind == "clo" and jk.pockets == 4 and jk.loc == "jacket", jk and jk.pockets)
    local axe = D.recordIn(p, "Base.Axe")
    check("axe as the preset has it", axe and math.max(axe.w, axe.h) == 3, axe and (axe.w .. "x" .. axe.h))
    check("nails stack", D.recordIn(p, "Base.Nails").stackOn == true)
    check("a pistol doesn't", D.recordIn(p, "Base.Pistol").stackOn == false)
end)

-- the window --------------------------------------------------------------------------------
run("opens", function()
    open()
    check("window", W ~= nil and W.L ~= nil and #W.ops > 0)
    check("on the bags", W.side == "bag" and W.sel ~= nil, W.sel)
    check("fits 1080", W.L.h <= SCREEN.h - T.cell * 2 and W.L.w <= SCREEN.w, W.L.w .. "x" .. W.L.h)
    inside("bags")
end)

run("every tab draws", function()
    for _, s in ipairs(E.SIDE_ALL) do
        if s then
            W:goSide(s)
            W:build()
            frames(3)
            check("tab " .. s, W.side == s)
            inside("tab " .. s)
        end
    end
end)

run("a frame doesn't build", function()
    W:goSide("bag")
    W:build()
    frames(2)
    local n, b = 0, W.build
    W.build = function(self) n = n + 1 return b(self) end
    local d0 = DRAWN
    frames(30)
    W.build = nil
    check("no build in 30 frames", n == 0, n)
    check("draws", DRAWN > d0)
    -- (the list is drawn for the rows near the view: a frame plays back a few hundred steps)
    check("steps a frame", #W.ops < 2500, #W.ops)
end)

run("search", function()
    W.searchBox:setText("jack")
    frames(1)
    local l = W:listItems()
    check("two jackets", #l == 2, #l)
    W.searchBox:setText("tg.")
    frames(1)
    check("by ID", #W:listItems() == 3, #W:listItems())
    W.searchBox:setText("")
    frames(1)
    check("cleared", W.query == nil)
end)

-- edits and Save --------------------------------------------------------------------------
run("size", function()
    open("Base.Pen")
    check("on the pen", W.sel == "Base.Pen" and W.side == "misc", W.side)
    local r = D.recordIn(target(), "Base.Pen")
    W:edit(function(o) o.h = o.h + 1 end)
    check("a line", line("Base.Pen") ~= nil, line("Base.Pen"))
    check("unsaved", W:unsavedN() == 1, W:unsavedN())
    press("Undo")
    check("undone", line("Base.Pen") == nil and W:unsavedN() == 0, W:unsavedN())
    W:edit(function(o) o.w, o.h = 2, 2 end)
    check("2x2", line("Base.Pen") == "2x2", line("Base.Pen"))
    press("Save")
    check("saved", W:unsavedN() == 0, W:unsavedN())
    local w, h = F.getBase(instanceItem("Base.Pen"))
    check("in effect", w == 2 and h == 2, w .. "x" .. h)
    check("written", string.find(FILES["knox_presets/" .. target().file], "Base.Pen = 2x2", 1, true) ~= nil)
    -- the reset in the head brings it back to Knox's own
    press("Reset")
    check("reset", line("Base.Pen") == nil)
    press("Save")
    w, h = F.getBase(instanceItem("Base.Pen"))
    check("Knox's own again", w * h == r.w * r.h, w .. "x" .. h)
end)

run("bag: grid, parts, mask", function()
    open("Base.Bag_Schoolbag")
    press("Mode_grid")
    check("grid mode", D.recordIn(target(), W.sel).bag.mode == "grid")
    W:edit(function(o) o.bag.grid = {6, 7} end)
    check("grid line", line(W.sel) and string.find(line(W.sel), "grid 6x7", 1, true) ~= nil, line(W.sel))
    press("Mode_parts")
    press("AddRowDown")
    local r = D.recordIn(target(), W.sel)
    check("a row added", r.bag.mode == "parts" and #r.bag.spec >= 2, #r.bag.spec)
    check("parts line", string.find(line(W.sel) or "", "parts", 1, true) ~= nil, line(W.sel))
    local n = #r.bag.spec
    press("Remove")
    check("one taken away", #D.recordIn(target(), W.sel).bag.spec <= n)
    press("Mode_mask")
    r = D.recordIn(target(), W.sel)
    check("mask from the parts", r.bag.mode == "mask" and D.maskCells(r.bag.mask) > 0)
    check("canvas as wide as the column", #r.bag.mask[1] >= D.MAX_ROW, #r.bag.mask[1])
    frames(2)
    inside("mask")
    press("Clear")
    W:edit(function(o) o.bag.mask[1][1], o.bag.mask[1][2], o.bag.mask[2][2] = 1, 1, 1 end)
    check("mask line", line(W.sel) == "mask xx|.x", line(W.sel))
    press("Save")
    local o = F.overrides[W.sel]
    check("mask in effect", o and o.mask == "xx|.x", o and o.mask)
    local key, back = F.parseLine(W.sel .. " = " .. line(W.sel))
    check("the line reads back", key == W.sel and back.mask == "xx|.x")
    -- painting: a press on the canvas and a drag over it
    local cv = nil
    for _, h in ipairs(W.hits) do if h.reg == 2 and h.w > T.cell then cv = cv or h end end
    check("canvas hit", cv ~= nil)
end)

run("stack", function()
    open("Base.Pistol")
    W:edit(function(o) o.stackOn = true o.stack = 5 end)
    check("stack line", line("Base.Pistol") == "stack 5", line("Base.Pistol"))
    frames(2)
    check("same-only note", find("label", tx("StackSame")) ~= nil)
    open("Base.Nails")
    W:edit(function(o) o.stackOn = false end)
    check("never", line("Base.Nails") == "stack 1", line("Base.Nails"))
    press("Save")
    check("pistols stack", G.isStackable(instanceItem("Base.Pistol")) == true)
    check("five a cell", F.stack(instanceItem("Base.Pistol")) == 5, F.stack(instanceItem("Base.Pistol")))
    check("nails don't", G.isStackable(instanceItem("Base.Nails")) == false)
end)

run("pockets", function()
    open("Base.Jacket_Padded")
    W:edit(function(o) o.pockets = 6 o.all = true end)
    check("pockets line", line("Base.Jacket_Padded") == "pockets.all 6", line("Base.Jacket_Padded"))
    press("Save")
    check("this one", G.pocketsOf(instanceItem("Base.Jacket_Padded"), "jacket") == 6)
    check("every jacket", G.pocketsOf(instanceItem("Base.Jacket_Black"), "jacket") == 6, G.pocketsOf(instanceItem("Base.Jacket_Black"), "jacket"))
    W:edit(function(o) o.pockets = 0 o.all = false end)
    check("none", line("Base.Jacket_Padded") == "pockets 0", line("Base.Jacket_Padded"))
    press("Save")
    check("no pockets", G.pocketsOf(instanceItem("Base.Jacket_Padded"), "jacket") == nil)
end)

run("category and sound", function()
    open("Base.Pen")
    local dd = find("label", T.upper(tx("Category")))
    check("dropdown", dd ~= nil)
    W.popup = nil
    W:edit(function(o) o.tile = "tool" o.snd = "plastic" end)
    check("line", line("Base.Pen") == "category tool sound plastic", line("Base.Pen"))
    -- the dropdown's list: a row picks
    W.popup = {kind = "snd", x = W.L.ex0, y = W.L.viewY + 200, w = 2400, h = W.L.choiceH, sx = W.L.ex0 + 40}
    W:build()
    frames(2)
    local row = find("label", tx("Snd_glass"))
    check("sound row", row ~= nil)
    if row then
        W:onMouseDown(row.x + 2, row.y + W:dyOf(3) + 2)
        check("picked", D.recordIn(target(), "Base.Pen").snd == "glass" and W.popup == nil, D.recordIn(target(), "Base.Pen").snd)
    end
    press("Reset")
    press("Save")
end)

-- presets ------------------------------------------------------------------------------------
run("presets page", function()
    open()
    W:goSide("presets")
    W:build()
    frames(2)
    inside("presets")
    check("Knox's own and mine", #W:presetsInOrder() == 2, #W:presetsInOrder())
    press("PresetNew")
    check("new page", W.psel == "new")
    W.nameBox:setText("Bags tight")
    press("ForCatB")
    check("for a tab", W.nScope == "cat")
    frames(1)
    local b = find("button", tx("Cat_bag"))
    if b then pressOp(b) end
    press("Create")
    local p = target()
    check("made and edited", p.name == "Bags tight" and p.scope == "tab:bag", p.name .. " " .. p.scope)
    check("not in use yet", p.on == false)
    check("unsaved", W:unsavedN() >= 1)
    inside("preset page")
    W:goScope(p)
    check("to its tab", W.side == "bag")
    W:edit(function(o) o.w, o.h = 1, 1 end)
    frames(1)
    check("off band", find("button", tx("TurnOn")) ~= nil)
    press("TurnOn")
    check("in use", p.on == true)
    -- the general one under it: this item shows the tab's
    local mine = P.store.list[1]
    W:setTarget(mine)
    W:build()
    check("over", W:overOf(W.sel) == p)
    frames(1)
    check("edit there", find("button", tx("EditThere")) ~= nil)
    press("EditThere")
    check("back to the tab's", target() == p)
    press("Save")
    check("index: both", string.find(FILES["knox_presets/index.txt"], "Bags tight.txt on", 1, true) ~= nil, FILES["knox_presets/index.txt"])
    local w, h = F.getBase(instanceItem(W.sel))
    check("tab preset in effect", w == 1 and h == 1, w .. "x" .. h)
end)

run("export and import", function()
    W:goSide("presets")
    W.psel = target()
    W:build()
    frames(1)
    press("ToClipboard")
    check("clipboard", string.find(CLIP, "# Knox Inventory preset", 1, true) == 1 and string.find(CLIP, "# for = tab bag", 1, true) ~= nil, CLIP)
    press("ToFile")
    check("file", FILES["knox_presets/" .. target().file] ~= nil)
    CLIP = table.concat({"# Knox Inventory preset", "# name = TG compact", "# for = mod TacticalGear",
        "TG.TacticalPack = grid 5x6", "TG.Vest = pockets 2", "Base.Axe = 1x2", "No.Such = 1x1", "TG.Knife = whatever"}, "\n")
    press("PresetImport")
    check("import page", W.psel == "import")
    local clip = find("label", tx("Clip"))
    check("clipboard row", clip ~= nil)
    if clip then
        W.mx, W.my = clip.x + 2, clip.y + W:dyOf(2) + 2
        W:onMouseDown(W.mx, W.my)
        frames(2)
    end
    local imp = W.imp
    check("read", imp ~= nil and imp.ok == 2 and imp.bad == 3, imp and (imp.ok .. "/" .. imp.bad))
    check("for the mod", imp and imp.preset.scope == "mod:TacticalGear")
    inside("import")
    press("AddPreset")
    local q = W.psel
    check("added", type(q) == "table" and q.scope == "mod:TacticalGear" and D.count(q) == 2, type(q) == "table" and q.scope)
    check("named from the file", type(q) == "table" and q.name == "TG compact", type(q) == "table" and q.name)
    -- delete it: asked twice
    W:build()
    frames(1)
    press("Delete")
    check("asks", W.delAsk == q)
    frames(1)
    press("DelSure")
    local _, i = P.find(W.store, q.file)
    check("deleted", i == nil)
end)

run("copy, rename", function()
    W:goSide("presets")
    W.psel = target()
    W:build()
    frames(1)
    local n = #W.store.list
    press("CopyP")
    check("a copy", #W.store.list == n + 1 and type(W.psel) == "table" and W.psel ~= target())
    press("Rename")
    check("renaming", W.renaming == W.psel)
    frames(1)
    check("field shown", W.nameBox:getIsVisible())
    W.nameBox:setText("Copy renamed")
    press("RenameDone")
    check("renamed", W.psel.name == "Copy renamed", W.psel.name)
    check("not renaming", W.renaming == nil)
end)

run("reset all changed", function()
    W:setTarget(P.store.list[1])
    W:goSide("changed")
    W:build()
    frames(1)
    local n = D.count(target())
    check("has changes", n > 0, n)
    press("ResetAllChanged")
    check("asks", W.resetAsk == true)
    press("ResetSure")
    check("all reset", D.count(target()) == 0, D.count(target()))
    press("Undo")
    check("undone", D.count(target()) == n, D.count(target()))
end)

run("close asks when unsaved", function()
    W:edit(function(o) o.h = o.h + 1 end)
    W:onKeyRelease(Keyboard.KEY_ESCAPE)
    check("asked", E.instance == W and W.closeAsk == true)
    W:onKeyRelease(Keyboard.KEY_ESCAPE)
    check("closed", E.instance == nil)
end)

-- a small screen ---------------------------------------------------------------------------------
run("720", function()
    SCREEN.w, SCREEN.h = 1280, 720
    T.refresh()
    open("Base.Bag_ALICEpack")
    check("fits 720", W.L.h <= 720 and W.L.w <= 1280, W.L.w .. "x" .. W.L.h)
    for _, s in ipairs(E.SIDE_ALL) do
        if s then
            W:goSide(s)
            W:build()
            frames(2)
            inside("720 " .. s)
        end
    end
    W:goSide("presets")
    for _, ps in ipairs({"new", "import"}) do
        W.psel = ps
        W:build()
        frames(2)
        inside("720 " .. ps)
    end
    W:close()
    SCREEN.w, SCREEN.h = 1920, 1080
    T.refresh()
end)

-- the author's defaults (dev mode) ----------------------------------------------------------------
run("mod defaults", function()
    KnoxTestBench = {devOn = function() return true end}
    open("Base.Hammer")
    check("dev", W.devOn == true and W.defaultsP ~= nil)
    W.layer = "mod"
    W:edit(function(o) o.w, o.h = 1, 4 end)
    check("its line", W.defaultsP.items["Base.Hammer"] ~= nil)
    press("Save")
    local f = MODFILES[F.DEFAULTS_FILE] or ""
    check("written to the mod", string.find(f, "Base.Hammer = 1x4", 1, true) ~= nil, f)
    check("read back", F.baseOverrides["Base.Hammer"] and F.baseOverrides["Base.Hammer"].h == 4)
    local w, h = F.getBase(instanceItem("Base.Hammer"))
    check("in effect", w == 1 and h == 4, w .. "x" .. h)
    -- for a player's preset that is Knox's own now
    W.layer = "player"
    W:setTarget(P.store.list[1])
    local d = D.defaultOf(target(), "Base.Hammer")
    check("players' default", d and d.h == 4, d and d.h)
    W:close()
    KnoxTestBench = nil
end)

-- the item's menu ----------------------------------------------------------------------------------
run("menu", function()
    check("menu added", MENU_FN ~= nil)
    local opt = nil
    local ctx = {addOption = function(_, name, a, f) opt = {name, a, f} end}
    MENU_FN(0, ctx, {instanceItem("Base.Axe")})
    check("option", opt and opt[1] == tx("Open"))
    if opt then opt[3](opt[2]) end
    check("opened on it", E.instance and E.instance.sel == "Base.Axe")
    if E.instance then E.instance:close() end
end)

-- the main menu's Knox tab: its editor part (2026-10-25, the author: the editor before the game) --
run("menu tab", function()
    if not KnoxSettingsTab then check("KnoxSettingsTab loaded", false) return end
    local tab = KnoxSettingsTab:new()
    tab:place()
    check("an editor part", tab.edLabel == T.upper(tx("Title")) and tab.line2 ~= nil)
    check("after the settings", tab.line2 > tab.line1 + tab.wLabel)
    check("whole in the frame", tab:getWidth() == tab.line2 + 1 + T.pad * 2 + tab.wEd + T.pad * 3, tab:getWidth())
    local setOpen, setFn = 0, KnoxSettings.open
    KnoxSettings.open = function() setOpen = setOpen + 1 end
    tab:onMouseDown(5, 5) tab:onMouseUp(tab.line2 - 2, 5)
    check("left of the line: settings", setOpen == 1 and E.instance == nil)
    tab:onMouseDown(5, 5) tab:onMouseUp(tab.line2 + 2, 5)
    check("right of it: the editor, on the bags", E.instance ~= nil and setOpen == 1 and E.instance.side == "bag")
    tab.mx = tab.line2 + 4
    tab.isMouseOver = function() return true end
    local okDraw = pcall(tab.prerender, tab)
    check("drawn with the mouse on it", okDraw)
    if E.instance then E.instance:close() end
    KnoxSettings.open = setFn
end)

print(pass .. " pass, " .. fail .. " fail")
