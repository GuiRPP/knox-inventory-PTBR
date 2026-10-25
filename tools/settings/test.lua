-- KnoxSettings.lua (the settings window remade with pages in a column and a view
-- that scrolls, 2026-10-25) on the game's Lua with tools/settings/stubs.lua: every
-- setting is on a page once, every page draws, the window fits a 720 px screen,
-- the wheel / the thumb / the track scroll it within its limits, a slider and the
-- categories' drag work on a scrolled page, a click out of the view is not taken,
-- Apply only where it means something, a plate catches a key.
local T, S = KnoxTheme, KnoxSettings
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end
local function run(name, f)
    local ok, err = pcall(f)
    check(name, ok, err)
end

local W
local function open()
    if S.instance then S.instance:close() end
    S.open()
    W = S.instance
end
local function frames(n)
    for _ = 1, n or 1 do
        clock = clock + 16
        W:prerender()
    end
end
local function mouse(x, y) W.mx, W.my = x, y end
local function page(p)
    for i, q in ipairs(S.PAGES) do
        if q == p then
            local r = W:sideRect(i)
            W:onMouseDown(r[1] + 5, r[2] + 2)
            W:onMouseUp(r[1] + 5, r[2] + 2)
        end
    end
    check("page " .. p, W.page == p, W.page)
end
local function item(p, kind, key)
    for _, e in ipairs(W.L.pages[p].items) do
        if e.kind == kind and (key == nil or e.key == key) then return e end
    end
end
local function settle()
    for _ = 1, 60 do frames() end
end

run("opens", function()
    open()
    check("window", W ~= nil and W.L ~= nil)
    check("seven pages", #S.PAGES == 7)
end)

run("every setting once", function()
    local seen = {}
    for _, p in ipairs(S.PAGES) do
        for _, e in ipairs(W.L.pages[p].items) do
            if e.key and e.kind ~= "sec" then
                local k = e.kind .. ":" .. e.key
                check("once " .. k, not seen[k], p)
                seen[k] = true
            end
        end
    end
    for _, s in ipairs(T.LOOK) do check("slider " .. s.key, seen["slider:" .. s.key]) end
    for _, s in ipairs(T.SWITCHES) do
        -- (vp.panel: only with Viewpoint's panel - none here)
        if s.only == "viewpoint" then check("hidden " .. s.key, not seen["switch:" .. s.key])
        else check("switch " .. s.key, seen["switch:" .. s.key]) end
    end
    for _, s in ipairs(T.CHOICES) do check("choice " .. s.key, seen["choice:" .. s.key]) end
    for _, name in ipairs(T.MODULES) do check("module " .. name, seen["mod:" .. name]) end
    for _, a in ipairs(KnoxControls.ACTIONS) do check("bind " .. a.id, seen["bind:" .. a.id]) end
    check("camp", item("menu", "camp") ~= nil)
    check("cats", item("order", "cats") ~= nil)
    check("skins", item("look", "skins") ~= nil)
end)

run("every page draws", function()
    for _, p in ipairs(S.PAGES) do
        page(p)
        DRAWN = 0
        mouse(W.L.x0 + 10, W.L.viewY + 40)
        local ok, err = pcall(frames, 3)
        check("draws " .. p, ok, err)
        check("drew " .. p, DRAWN > 20, DRAWN)
        check("stencil " .. p, W.stencils == 0, W.stencils)
    end
end)

run("one height, within 15 cells", function()
    local L = W.L
    check("content", L.viewH <= T.cell * 15 + 1, L.viewH)
    check("fits 1080", W:getHeight() <= 1080 - T.cell * 2, W:getHeight())
end)

run("720p", function()
    SCREEN.h = 720
    T.refresh()
    open()
    local L = W.L
    check("fits 720", W:getHeight() <= 720 - T.cell * 2, W:getHeight())
    check("view", L.viewH > T.cell * 4, L.viewH)
    -- (the test's texts are shorter than the real ones: a lower screen, so pages scroll)
    SCREEN.h = 560
    open()
    page("look")
    check("look scrolls", W:maxScroll() > 0, W:maxScroll())
    check("bar", W:bar() ~= nil)
end)

run("wheel", function()
    page("look")
    local L = W.L
    mouse(L.x0 + 20, L.viewY + 30)
    W:onMouseWheel(1)
    check("target", W.target > 0, W.target)
    settle()
    check("glided", W.scroll == W.target, W.scroll)
    for _ = 1, 200 do W:onMouseWheel(1) end
    settle()
    check("max", W.scroll == W:maxScroll(), W.scroll .. " / " .. W:maxScroll())
    check("fade top", W.fadeTop > 0.9, W.fadeTop)
    check("no fade bottom", W.fadeBottom < 0.1, W.fadeBottom)
    for _ = 1, 200 do W:onMouseWheel(-1) end
    settle()
    check("top", W.scroll == 0, W.scroll)
    -- over the pages' column: nothing
    mouse(10, L.viewY + 30)
    W:onMouseWheel(1)
    check("column", W.target == 0, W.target)
end)

run("thumb and track", function()
    page("look")
    local bx, top, track, box, by = W:bar()
    mouse(bx, by + 2)
    W:onMouseDown(bx, by + 2)
    check("taken", W.thumbDrag ~= nil)
    MOUSE.down[0] = true
    mouse(bx, by + 2 + math.floor((track - box) / 2))
    frames()
    check("half", math.abs(W.scroll - W:maxScroll() / 2) < W:maxScroll() * 0.05 + 1, W.scroll)
    MOUSE.down[0] = false
    W:onMouseUp(bx, by)
    frames()
    check("let go", W.thumbDrag == nil)
    -- the track under the thumb: a page down
    local was = W.target
    bx, top, track, box, by = W:bar()
    W:onMouseDown(bx, top + track - 1)
    check("page down", W.target > was, W.target)
    W:onMouseUp(bx, top + track - 1)
    settle()
end)

run("slider on a scrolled page", function()
    page("look")
    local e = item("look", "slider", "look.bg")
    local L = W.L
    -- scrolled so the slider is in the view, but not where it was at the top
    W.target = math.min(W:maxScroll(), e.y - L.viewH / 2)
    settle()
    check("scrolled", W.scroll > 0, W.scroll)
    local oy = W:pageTop()
    local y = oy + e.y + math.floor(L.sliderH / 2)
    check("in view", y > L.viewY and y < L.viewY + L.viewH, y)
    mouse(L.sliderX + L.sliderW, y)
    W:onMouseDown(L.sliderX + L.sliderW, y)
    check("sliding", W.sliding == e)
    MOUSE.down[0] = true
    frames()
    check("max", tonumber(T.settings["look.bg"]) == e.spec.max, T.settings["look.bg"])
    mouse(L.sliderX - 50, y)
    frames()
    check("min", tonumber(T.settings["look.bg"]) == e.spec.min, T.settings["look.bg"])
    MOUSE.down[0] = false
    frames()
    W:onMouseUp(L.sliderX, y)
    check("let go", W.sliding == nil)
end)

run("a click out of the view", function()
    page("modules")
    local L = W.L
    -- a module's row scrolled out of the view - under the header or over the
    -- foot - but still inside the window: its place there is not it
    local e, y
    for _, s in ipairs({0, W:maxScroll()}) do
        W.target = s
        settle()
        for _, it in ipairs(W.L.pages.modules.items) do
            local iy = W:pageTop() + it.y + 4
            local out = iy < L.viewY or iy >= L.viewY + L.viewH
            if not e and it.kind == "mod" and out and iy > 0 and iy < W:getHeight() - T.pad * 2 - L.footH then e, y = it, iy end
        end
        if e then break end
    end
    check("one out", e ~= nil, W:maxScroll())
    if e then
        local was = W.want[e.key]
        W:onMouseDown(L.x0 + 10, y)
        W:onMouseUp(L.x0 + 10, y)
        check("not taken", W.want[e.key] == was)
    end
    KnoxWindowDrag.stop(W)
end)

run("page change: back to the top", function()
    page("look")
    W.target = W:maxScroll()
    settle()
    page("order")
    check("top", W.scroll == 0 and W.target == 0, W.scroll)
    check("remembered", S.lastPage == "order")
end)

run("apply only where it means something", function()
    page("look")
    check("none on look", not W:hasApply())
    local cr = W:closeButtonRect()
    check("close at the right", cr[1] + cr[3] == W:getWidth() - T.pad * 2, cr[1] + cr[3])
    page("modules")
    check("on modules", W:hasApply())
    local name = T.MODULES[1]
    W.want[name] = not W.want[name]
    page("look")
    check("changed: on look", W:hasApply())
    W.want[name] = not W.want[name]
    check("back: gone", not W:hasApply())
end)

run("module row with the scroll", function()
    page("modules")
    W.target = W:maxScroll()
    settle()
    local items = W.L.pages.modules.items
    local last
    for _, e in ipairs(items) do if e.kind == "mod" then last = e end end
    local y = W:pageTop() + last.y + 4
    local was = W.want[last.key]
    if y > W.L.viewY and y < W.L.viewY + W.L.viewH then
        W:onMouseDown(W.L.x0 + 10, y)
        W:onMouseUp(W.L.x0 + 10, y)
        check("toggled", W.want[last.key] == not was)
        W.want[last.key] = was
    else
        check("last module in view", false, y)
    end
end)

run("categories dragged on a scrolled page", function()
    page("order")
    W.target = W:maxScroll()
    settle()
    local before = KnoxOrder.catOrder()
    local oy = W:pageTop()
    local row = W:catRects(1, oy)
    local x, y = row[1] + 20, row[2] + 3
    if y < W.L.viewY then
        -- (the first row scrolled away at this size: take the last in view)
        check("first row in view", false, y)
        return
    end
    mouse(x, y)
    W:onMouseDown(x, y)
    check("taken", W.catDrag ~= nil)
    MOUSE.down[0] = true
    local row3 = W:catRects(3, oy)
    local ty = row3[2] + 3
    mouse(x, ty)
    frames()
    MOUSE.down[0] = false
    W:onMouseUp(x, ty)
    local after = KnoxOrder.catOrder()
    check("moved", after[3] == before[1] and after[1] == before[2], table.concat(after, ","))
    -- and an arrow: down on the first
    local _, _, down = W:catRects(1, W:pageTop())
    W:onMouseDown(down[1] + 2, down[2] + 2)
    W:onMouseUp(down[1] + 2, down[2] + 2)
    local again = KnoxOrder.catOrder()
    check("arrow", again[2] == after[1], table.concat(again, ","))
end)

run("a plate catches a key", function()
    page("controls")
    local e
    for _, it in ipairs(W.L.pages.controls.items) do
        if it.kind == "bind" and KnoxControls.action(it.key).kind == "key" then e = it break end
    end
    check("a key action", e ~= nil)
    W.target = 0
    settle()
    local r = W:plateRect(e, W:pageTop())
    local x, y = r[1] + 4, r[2] + 4
    W:onMouseDown(x, y)
    W:onMouseUp(x, y)
    check("catching", W.capture ~= nil and W.capture.id == e.key)
    frames()
    W:keyReleased(30)
    check("bound", KnoxControls.get(e.key) == "key:30", KnoxControls.get(e.key))
    check("done", W.capture == nil)
    clock = clock + 200
    check("esc closes", W:keyReleased(Keyboard.KEY_ESCAPE) and S.instance == nil)
end)

run("main menu: the modules first", function()
    S.lastPage = nil
    local was = PLAYER
    PLAYER = nil
    open()
    check("modules", W.page == "modules", W.page)
    PLAYER = was
    W:close()
end)

print(string.format("settings: %d pass, %d FAIL", pass, fail))
