-- KnoxCrosshair.lua (Knox's panel in place of Viewpoint's at the crosshair) on the
-- game's Lua with tools/crosshair/stubs.lua: it builds its rows, the wheel chooses,
-- a tap on a bag looks into it and a held one takes it, take all, a long list
-- scrolls, actions with the dangerous ones last, looking away folds it.
local P = KnoxCrosshair
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

local function frames(n, ms)
    for _ = 1, n do
        clock = clock + (ms or 16)
        local ok, err = pcall(P.frame, UI)
        if not ok then error(err) end
        -- (every clip taken off by the frame's end: one left on cut away the keys - 2026-10-25)
        if STENCIL.level ~= 0 then STENCIL.left = STENCIL.left + 1 STENCIL.level = 0 end
    end
end
local function run(name, f)
    local ok, err = pcall(f)
    check(name, ok, err)
end
local function rowsOf(kind)
    local n = 0
    for _, r in ipairs(P.rows) do if r.kind == kind then n = n + 1 end end
    return n
end
local function chooseRow(pred)
    for i, r in ipairs(P.pick) do if pred(r) then P.sel = i return r end end
end

-- a cupboard: three kinds of things (two apples), a bag with two things in it
local apple1, apple2, knife = item("Apple", 0.2), item("Apple", 0.2), item("Knife", 0.7)
local pencil = item("Pencil", 0.1)
local socks = item("Socks", 0.1)
local pack = bag("Backpack", {pencil, socks})
local cup = container({apple1, apple2, knife, pack}, "crate")

run("cupboard", function()
    VP.shown, VP.kind, VP.obj, VP.containers = true, 3, {}, jlist({cup})
    frames(30)
    check("owned", VP.owned == true and P.owned == true)
    check("visible", P.visible == true)
    check("rows by kind", rowsOf("item") == 3, rowsOf("item"))
    check("apples one row of two", (function()
        for _, r in ipairs(P.rows) do if r.name == "Apple" then return r.n == 2 and r.ntext ~= nil end end
    end)())
    check("count", P.count == 4, P.count)
    check("width in its bounds", P.w >= 260 and P.w <= 340, P.w)
    check("hints: take, all, open", P.hintCount == 3, P.hintCount)
    check("stencils paired", DRAWN.stencil == DRAWN.unstencil, DRAWN.stencil .. "/" .. DRAWN.unstencil)
    check("drawn", DRAWN.label > 0 and DRAWN.rect > 0)
end)

run("wheel", function()
    local s0 = P.sel
    VP.wheel = 1
    frames(2)
    check("wheel moves the choice", P.sel == math.min(s0 + 1, #P.pick), P.sel)
    VP.wheel = -10
    frames(2)
    check("wheel stops at the top", P.sel == 1)
end)

run("take one", function()
    GRABBED = {}
    chooseRow(function(r) return r.name == "Apple" end)
    VP.pressed = 1
    frames(2)
    check("one apple taken", #GRABBED == 1 and GRABBED[1].name == "Apple", #GRABBED)
end)

run("bag tap", function()
    GRABBED = {}
    chooseRow(function(r) return r.bag ~= nil end)
    VP.pressed, VP.held = 1, true
    frames(3)   -- 48 ms held
    VP.held = false
    frames(20)
    check("nothing taken", #GRABBED == 0, #GRABBED)
    check("bag open", P.bags[pack] and P.bags[pack].to == true and P.bags[pack].k == 1)
    local inner = 0
    for _, r in ipairs(P.rows) do if r.depth == 1 and r.kind == "item" then inner = inner + 1 end end
    check("its things in the list", inner == 2, inner)
    check("hint: fold", P.shownLabels[1] == "IGUI_Knox_VPFold", P.shownLabels[1])
end)

run("take all in the bag", function()
    GRABBED = {}
    chooseRow(function(r) return r.depth == 1 end)
    VP.pressed = 2
    frames(2)
    check("the bag's two things", #GRABBED == 2 and (GRABBED[1] == pencil or GRABBED[1] == socks), #GRABBED)
end)

run("bag tap folds", function()
    chooseRow(function(r) return r.bag ~= nil end)
    VP.pressed, VP.held = 1, true
    frames(2)
    VP.held = false
    frames(25)
    check("bag folded", P.bags[pack].to == false and P.bags[pack].k == 0)
    local inner = 0
    for _, r in ipairs(P.rows) do if r.depth == 1 then inner = inner + 1 end end
    check("its things gone from the list", inner == 0, inner)
end)

run("bag hold", function()
    GRABBED = {}
    chooseRow(function(r) return r.bag ~= nil end)
    VP.pressed, VP.held = 1, true
    frames(14)   -- 224 ms > 180
    check("bag taken", #GRABBED == 1 and GRABBED[1] == pack, #GRABBED)
    check("hint: take", P.shownLabels[1] == "IGUI_Knox_VPTake", P.shownLabels[1])
    VP.held = false
    frames(2)
    check("still closed", P.bags[pack] == nil or P.bags[pack].to == false)
end)

run("a thing gone folds away", function()
    cup.items = jlist({apple1, apple2, pack})   -- the knife taken
    frames(10)
    local leaving = false
    for _, r in ipairs(P.rows) do if r.name == "Knife" and r.leaveMs then leaving = true end end
    check("knife folding", leaving)
    frames(30)
    local still = false
    for _, r in ipairs(P.rows) do if r.name == "Knife" then still = true end end
    check("knife gone", not still)
    check("count 3", P.count == 3, P.count)
end)

run("long list scrolls", function()
    local many = {}
    for i = 1, 30 do table.insert(many, item("Thing " .. string.format("%02d", i), 0.1)) end
    VP.obj, VP.containers = {}, jlist({container(many, "shelf")})
    frames(40)
    check("clipped", P.L.clipped == true)
    check("window at most 8 rows", P.L.viewH <= 8 * 32, P.L.viewH)
    VP.wheel = 20
    frames(40)
    check("scrolled", P.scroll > 0 and P.scroll <= P.L.maxScroll + 0.5, P.scroll)
end)

run("actions", function()
    VP.obj, VP.loot, VP.containers = {}, false, jlist({})
    VP.actions = {{label = "Smash Window", on = true}, {label = "Open Window", on = true}, {label = "Close Curtains", on = false}}
    frames(30)
    local order = {}
    for _, r in ipairs(P.rows) do table.insert(order, r.kind == "act" and r.name or r.kind) end
    check("dangerous last under a line", order[#order] == "Smash Window" and order[#order - 1] == "sep", table.concat(order, ","))
    check("off one not chosen", #P.pick == 2, #P.pick)
    chooseRow(function(r) return r.name == "Open Window" end)
    VP.pressed = 1
    frames(2)
    check("action run", VP.ran[#VP.ran] == 1, VP.ran[#VP.ran])
    check("hints: use only", P.hintCount == 1 and P.shownLabels[1] == "IGUI_Knox_VPUse", P.hintCount)
    -- (done: Viewpoint gathers them anew, as many as before - the row follows; 2026-10-29)
    VP.actions[2] = {label = "Close Window", on = true}
    VP.version = (VP.version or 0) + 1
    frames(10)
    local named = false
    for _, r in ipairs(P.rows) do if r.name == "Close Window" then named = true end end
    check("a renamed action shown", named)
    check("the choice stays on it", P.pick[P.sel] and P.pick[P.sel].name == "Close Window", P.pick[P.sel] and P.pick[P.sel].name)
end)

-- a locked door: Viewpoint's "[Locked]" off the name, a lock and "LOCKED" at the right (2026-10-29)
RATTLED = 0
local door = {classes = {IsoDoor = true}, ToggleDoor = function() RATTLED = RATTLED + 1 end}
run("locked door", function()
    VP.obj, VP.loot, VP.locked, VP.containers = door, false, false, jlist({})
    VP.actions = {{label = "Open Door [EC_Locked]", on = false}, {label = "Enter Vehicle [EC_Locked]", on = true}}
    VP.version = (VP.version or 0) + 1
    frames(30)
    local names, locked = {}, 0
    for _, r in ipairs(P.rows) do
        if r.kind == "act" then table.insert(names, r.name) if r.locked then locked = locked + 1 end end
    end
    check("names without the tail", names[1] == "Open Door" and names[2] == "Enter Vehicle", table.concat(names, ","))
    check("both locked", locked == 2, locked)
    -- (a locked one chosen first, not what comes after it - "Disassemble" was: the author, 2026-10-29)
    check("the locked one chosen", #P.pick == 2 and P.pick[P.sel].name == "Open Door", #P.pick)
    local ran0 = #VP.ran
    VP.pressed = 1
    frames(2)
    check("the door tried", RATTLED == 1 and #VP.ran == ran0, RATTLED)
    check("drawn", DRAWN.label > 0)
end)

-- the actions in the right-click menu's groups (the author, 2026-10-29: the mockup
-- vp_groups_v1.html, no counts, titles as the menu's): "Wash: ..." under one row that
-- unfolds, six of its rows at most, the thing washed as its picture
local shirt = item("T-Shirt", 0.2)
shirt.classes.InventoryItem = true
local function names()
    local out = {}
    for _, r in ipairs(P.rows) do
        table.insert(out, (r.kind == "act" or r.kind == "label") and (r.name or r.text) or r.kind)
    end
    return table.concat(out, ",")
end
local function rowNamed(n)
    for _, r in ipairs(P.rows) do if r.name == n then return r end end
end

run("groups", function()
    VP.obj, VP.loot, VP.locked, VP.containers = {}, false, false, jlist({})
    VP.actions = {{label = "Drink", on = true}, {label = "Wash: Yourself", on = true}, {label = "Wash: T-Shirt", on = true}}
    for i = 1, 6 do table.insert(VP.actions, {label = "Wash: Socks " .. i, on = true}) end
    for _, a in ipairs({"Fill: Bottle", "Disassemble", "Mod A", "Mod B: X", "Mod B: Y", "Smash Window"}) do
        table.insert(VP.actions, {label = a, on = true})
    end
    ViewpointInteract = {actions = {}}
    ViewpointInteract.actions[3] = {args = {n = 2, PLAYER, shirt}}
    VP.version = (VP.version or 0) + 1
    frames(30)
    check("grouped as the menu", names() == "IGUI_Knox_MenuUse,Drink,Wash,Fill: Bottle,IGUI_Knox_MenuBuild,Disassemble,"
        .. "sep,IGUI_Knox_MenuOther,sep,Smash Window", names())
    local wash = rowNamed("Wash")
    check("a group row", wash and wash.grp ~= nil and #wash.kids == 8)
    chooseRow(function(r) return r == wash end)
    frames(2)
    check("hint: unfold", P.shownLabels[1] == "IGUI_Knox_VPUnfold", P.shownLabels[1])
    VP.pressed = 1
    frames(30)
    check("nothing run", #VP.ran == 1, #VP.ran)
    local kids, shown, strips = 0, 0, 0
    for _, r in ipairs(P.rows) do
        if r.parent == wash.key and r.kind == "act" then
            kids = kids + 1
            if r.h > 0 then shown = shown + 1 end
        elseif r.kind == "gstrip" then strips = strips + 1 end
    end
    check("unfolded", kids == 8, kids)
    check("six shown", shown == 6, shown)
    check("two strips", strips == 2, strips)
    check("hint: fold", P.shownLabels[1] == "IGUI_Knox_VPFold", P.shownLabels[1])
    check("own names", rowNamed("Yourself") ~= nil and rowNamed("Socks 6") ~= nil)
    check("own icon", rowNamed("Yourself").icon and rowNamed("Yourself").icon.path == "self")
    check("the thing's picture", rowNamed("T-Shirt").item == shirt and rowNamed("T-Shirt").icon == nil)
    -- down to the last: the window follows
    VP.wheel = 8
    frames(10)
    local last = rowNamed("Socks 6")
    check("last chosen", P.pick[P.sel] == last, P.pick[P.sel] and P.pick[P.sel].name)
    check("last in the window", last.h > 0 and rowNamed("Yourself").h == 0, last.h)
    VP.pressed = 1
    frames(2)
    check("its action run", VP.ran[#VP.ran] == last.index, VP.ran[#VP.ran])
    -- "Other": the rest (a sub menu's by their whole names)
    local other = rowNamed("IGUI_Knox_MenuOther")
    check("other's rows", other and #other.kids == 3 and other.kids[2].name == "Mod B: X")
    check("width in its bounds", P.w >= 260 and P.w <= 340, P.w)
    check("stencils paired", DRAWN.stencil == DRAWN.unstencil, DRAWN.stencil .. "/" .. DRAWN.unstencil)
    -- folded back
    chooseRow(function(r) return r.name == "Wash" end)
    VP.pressed = 1
    frames(30)
    local left = 0
    for _, r in ipairs(P.rows) do if r.parent == wash.key then left = left + 1 end end
    check("folded", left == 0, left)
    -- one group of the menu's: no titles
    VP.actions = {{label = "Drink", on = true}, {label = "Wash: A", on = true}, {label = "Wash: B", on = true}}
    VP.version = VP.version + 1
    frames(30)
    check("no titles with one group", names() == "Drink,Wash", names())
    ViewpointInteract = nil
end)

-- Viewpoint's first one on top (the author, 2026-10-29: a car - first it is got into; locked,
-- the window to smash right under it; its doors under "Other")
run("car", function()
    VP.obj, VP.loot, VP.locked, VP.containers = {}, false, false, jlist({})
    VP.actions = {{label = "Enter Vehicle [EC_Locked]", on = true}, {label = "Open Door [EC_Locked]", on = true},
                  {label = "Vehicle Mechanics", on = true}, {label = "Smash Window", on = true}}
    ViewpointInteract = {actions = {{first = true}, {fn = ISVehicleMenu.onOpenDoor}}}
    VP.version = (VP.version or 0) + 1
    VP.ran = {}
    frames(30)
    check("enter first, smash under it, the rest under Other",
        names() == "Enter Vehicle,Smash Window,sep,IGUI_Knox_MenuOther", names())
    check("enter chosen", P.pick[P.sel] and P.pick[P.sel].name == "Enter Vehicle")
    local other = rowNamed("IGUI_Knox_MenuOther")
    check("the door in Other", other and other.kids and other.kids[1].name == "Open Door")
    VP.pressed = 1
    frames(2)
    check("enter run (the game says it's locked)", VP.ran[1] == 0, VP.ran[1])
    -- unlocked: smash at the bottom again
    VP.actions[1].label, VP.actions[2].label = "Enter Vehicle", "Open Door"
    VP.version = VP.version + 1
    frames(30)
    check("smash at the bottom", names() == "Enter Vehicle,sep,IGUI_Knox_MenuOther,sep,Smash Window", names())
    ViewpointInteract = nil
end)

-- a TV: Viewpoint names the panel after its first sub menu ("Disassemble") and leaves that off
-- its option ("TV"): the header the TV's name, the row "Disassemble" (the author, 2026-10-29)
run("disassemble", function()
    VP.obj, VP.loot, VP.locked, VP.containers = {moveName = "TV"}, false, false, jlist({})
    VP.title = "Disassemble"
    VP.actions = {{label = "Set Up Device", on = true}, {label = "TV Premium", on = true}}
    ViewpointInteract = {actions = {{}, {group = "Disassemble", fn = ISDisassembleMenu.disassemble}}}
    VP.version = (VP.version or 0) + 1
    frames(30)
    check("rows", names() == "IGUI_Knox_MenuBuild,Disassemble,sep,Set Up Device", names())
    check("header: the thing's name", P.title == "Named TV", P.title)
    -- what it needs, under it (the mockup vp_scrap_v1.html): can't be done - only what is missing
    local live = P.src.scrapNeeds
    P.src.scrapNeeds = function() return {{s = "Electrical 3/2", bad = false}, {s = "Screwdriver", bad = true}} end
    VP.actions[2].on = false
    VP.version = VP.version + 1
    frames(30)
    local row = rowNamed("Disassemble")
    check("only what is missing", row and row.req and #row.req == 1 and row.req[1].s == "IGUI_Knox_VPNeeds Screwdriver",
        row and row.req and row.req[1].s)
    check("a taller row", row and row.h > 32, row and row.h)
    check("all shown", row and row.reqN == 1 and row.reqMore == nil)
    -- too many: "N more" after what fits
    P.src.scrapNeeds = function()
        local t = {}
        for k = 1, 6 do table.insert(t, {s = "Some long tool number " .. k, bad = true}) end
        return t
    end
    VP.version = VP.version + 1
    frames(30)
    row = rowNamed("Disassemble")
    check("the rest as more", row and row.reqN >= 1 and row.reqN < 6 and row.reqMore ~= nil and row.reqMoreBad, row and row.reqN)
    check("width in its bounds", P.w <= 340, P.w)
    P.src.scrapNeeds = live
    -- the game's tooltip read: tools that would do instead are one need - the one the player has
    -- by its name (the author's radio: "Screwdriver · 3 more", 2026-10-29)
    local function c(r, g, b) return {r = r, g = g, b = b} end
    ISMoveableSpriteProps.bhc = {getR = function() return 1 end, getG = function() return 0 end, getB = function() return 0 end}
    local W, BAD = c(255, 255, 255), c(255, 0, 0)
    local function ln(a, ac, b, bc)
        return {{txt = a, r = ac.r, g = ac.g, b = ac.b}, b and {txt = b, r = bc.r, g = bc.g, b = bc.b} or nil}
    end
    local mine = {classes = {InventoryItem = true}, getDisplayName = function() return "My Screwdriver" end}
    local hasTool = mine
    local props = {getInfoPanelDescription = function()
        local okc = hasTool and W or BAD
        return {ln("IGUI_Name:", W, "TV", W), ln("IGUI_Skill:", W, "Electrical", W), ln("IGUI_Tool:", W, "Screwdriver", okc),
                ln("", W, "Spoon", okc), ln("", W, "Knife", okc), ln("- Items on the surface", BAD)}
    end, hasScrapTool = function() return hasTool end}
    ViewpointInteract = {actions = {{}, {args = {n = 2, PLAYER, {moveProps = props}}}}}
    local needs = live(1)
    local said = {}
    for _, p in ipairs(needs or {}) do table.insert(said, p.s .. (p.bad and "!" or "")) end
    check("alternatives one need, mine by its name", table.concat(said, ",") == "Electrical,My Screwdriver,Items on the surface!",
        table.concat(said, ","))
    hasTool = nil
    needs, said = live(1), {}
    for _, p in ipairs(needs or {}) do table.insert(said, p.s .. (p.bad and "!" or "")) end
    check("missing: the first of them", table.concat(said, ",") == "Electrical,Screwdriver!,Items on the surface!",
        table.concat(said, ","))
    ISMoveableSpriteProps.bhc = nil
    -- a TV's "Device Options": on top, chosen (the author, 2026-10-29)
    VP.actions = {{label = "Set Up Device", on = true}, {label = "TV Premium", on = true}}
    VP.actions[2].on = true
    ViewpointInteract = {actions = {{fn = ISRadioAndTvMenu.openTvPanel}, {group = "Disassemble", fn = ISDisassembleMenu.disassemble}}}
    VP.version = VP.version + 1
    frames(30)
    check("device options on top", names() == "Set Up Device,IGUI_Knox_MenuBuild,Disassemble", names())
    check("device options chosen", P.pick[P.sel] and P.pick[P.sel].name == "Set Up Device")
    -- a window: its own sub menu "Window" names the panel - not put back on its options
    -- ("Window: Close Window" - the author's screenshot, 2026-10-29)
    VP.obj = {moveName = "Window"}
    VP.title = "Window"
    VP.actions = {{label = "Close Window", on = true}, {label = "Climb Through", on = true}}
    ViewpointInteract = {actions = {{group = "Window", first = true}, {group = "Window"}}}
    VP.version = VP.version + 1
    frames(30)
    check("a window's rows by their own names", rowNamed("Close Window") ~= nil and rowNamed("Climb Through") ~= nil, names())
    check("header: the window's name", P.title == "Named Window", P.title)
    VP.title, ViewpointInteract = nil, nil
end)

-- a fence, "Disassemble" greyed out: nothing chosen - the take key the game's, F held climbs it
-- (the author, 2026-10-29); can be done - the panel's
run("take key", function()
    VP.obj, VP.loot, VP.locked, VP.containers = {moveName = "Fence"}, false, false, jlist({})
    VP.actions = {{label = "Disassemble", on = false}}
    ViewpointInteract = {actions = {{fn = ISDisassembleMenu.disassemble}}}
    VP.version = (VP.version or 0) + 1
    frames(30)
    check("nothing chosen: the game's", VP.wants == false, tostring(VP.wants))
    VP.actions[1].on = true
    VP.version = VP.version + 1
    frames(30)
    check("one to run: the panel's", VP.wants == true, tostring(VP.wants))
    VP.shown = false
    frames(5)
    check("panel gone: the game's", VP.wants == false, tostring(VP.wants))
    VP.shown = true
    ViewpointInteract = nil
end)

run("locked", function()
    VP.obj, VP.loot, VP.locked, VP.actions, VP.containers = {}, true, true, {}, jlist({cup})
    frames(30)
    check("no things when locked", rowsOf("item") == 0)
    check("sub line locked", P.sub == "IGUI_Knox_VPLocked")
    GRABBED = {}
    VP.pressed = 2
    frames(2)
    check("nothing taken when locked", #GRABBED == 0)
    VP.locked = false
end)

-- OldPoint's overhead camera: no panel there, as OldPoint hides Viewpoint's (2026-10-25)
run("overhead camera", function()
    VP.topDown = true
    frames(2)
    check("hidden overhead", P.visible == false)
    frames(20)
    VP.topDown = false
    frames(2)
    check("back after", P.visible == true)
end)

run("looked away", function()
    VP.shown = false
    frames(2)
    check("hidden", P.visible == false)
    check("ghost folding", P.ghost ~= nil)
    frames(20)
    check("ghost gone", P.ghost == nil)
end)

run("switch off", function()
    SWITCHES["vp.panel"] = false
    frames(2)
    check("let go", VP.owned == false and P.owned == false)
    SWITCHES["vp.panel"] = true
end)

run("a long name slides: its clip taken off", function()
    local long = item(string.rep("Dog treats, a book ", 6), 0.5)
    local shelf = container({long, item("Apple", 0.2)}, "crate")
    VP.shown, VP.kind, VP.obj, VP.containers = true, 3, {}, jlist({shelf})
    frames(40)
    local r = chooseRow(function(q) return q.kind == "item" and q.items and q.items[1] == long end)
    frames(40)
    check("marquee drawn", r ~= nil)
end)

-- The news' demo (KnoxCrosshairDemo, "@vp" / "@vp fridge"): the panel on a pretend world,
-- drawn between the live panel's frames - the live state is put back each time.
local HOST = {addChild = function() end}
local function demoFrames(d, n)
    for _ = 1, n do
        clock = clock + 16
        d:hostAt(HOST, 10, 10, {0, 0, 4000, 4000})
        d:render()
        if STENCIL.level ~= 0 then STENCIL.left = STENCIL.left + 1 STENCIL.level = 0 end
    end
end
local function demoCount(d)
    local n = 0
    for _, b in ipairs(d.world.boxes) do n = n + #b.items.t end
    return n
end

run("news demo: fridge", function()
    local liveRows, liveSrc = P.rows, P.src
    local d = P.newsDemo(HOST, "fridge", "fridge")
    check("made once", P.newsDemo(HOST, "fridge", "fridge") == d)
    local w, h = d:demoSize(900)
    check("size", w > 0 and h > 0, tostring(w) .. "x" .. tostring(h))
    demoFrames(d, 300)   -- (eight things, one found every 420 ms)
    check("not broken", not d.broken)
    check("live state back", P.rows == liveRows and P.src == liveSrc and P.src == P.LIVE)
    check("its own rows", d.st.rows and #d.st.rows > 0 and d.st.rows ~= liveRows)
    check("two sections", #d.world.boxes == 2)
    check("searched through", d.world.found == demoCount(d), d.world.found)
    check("drew within its plate", d.st.box ~= nil and d.st.box.W > 0)
    -- a click on a row chooses it, another click takes it
    local n0 = demoCount(d)
    d.st.sel = 1
    d.press = 1
    demoFrames(d, 60)
    check("taken", demoCount(d) < n0, demoCount(d) .. " of " .. n0)
    check("busy while taking or done", not d.broken)
    -- the crosshair: look away (the plate folds) and back
    local Z = P.Z
    local cy = math.floor(Z.GAP + Z.PH_SUB / 2 + 0.5) + Z.ROW
    d:onMouseDown(d.cx, cy)
    check("away", d.away == true)
    demoFrames(d, 30)
    d:onMouseDown(d.cx, cy)
    check("back", d.away == false)
    demoFrames(d, 30)
    check("still fine", not d.broken and d.st.visible == true)
end)

run("news demo: cupboard, the bag looked into and taken", function()
    local d = P.newsDemo(HOST, "cupboard", "cupboard")
    d:demoSize(900)
    demoFrames(d, 200)
    local bagRow
    for i, r in ipairs(d.st.pick) do if r.bag then bagRow = i end end
    check("a bag row", bagRow ~= nil)
    if not bagRow then return end
    d.st.sel = bagRow
    d.press = 1
    demoFrames(d, 40)
    local st = d.st.bags[d.st.pick[bagRow] and d.st.pick[bagRow].bag or 0]
    check("looked into", st ~= nil and st.to == true)
    -- held: the bag goes whole
    local n0 = demoCount(d)
    for i, r in ipairs(d.st.pick) do if r.bag and r.depth == 0 then d.st.sel = i end end
    d.press, d.pressing, MOUSE.down = 1, true, true
    demoFrames(d, 40)
    MOUSE.down, d.pressing = false, false
    demoFrames(d, 60)
    check("bag taken", demoCount(d) < n0, demoCount(d) .. " of " .. n0)
    -- emptied: filled again a moment later
    d.st.sel = 1
    for _ = 1, 30 do d.press = 2 demoFrames(d, 40) end
    demoFrames(d, 200)
    check("filled again", demoCount(d) > 0, demoCount(d))
    check("not broken", not d.broken)
end)

run("all along: no clip left on", function()
    check("left", STENCIL.left == 0, STENCIL.left)
    check("bad", STENCIL.bad == 0, STENCIL.bad)
end)

print("DONE pass=" .. pass .. " fail=" .. fail)
