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
