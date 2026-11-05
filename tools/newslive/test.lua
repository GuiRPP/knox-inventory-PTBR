-- The inventory and the menu on R live in a news post (KnoxNewsLive; the author, 2026-11-05),
-- on the game's Lua over tools/newslive/pre.lua: its world comes and goes whole, the actions do
-- to the things what they do in the game, the game's own queue and menu stay out of it, the key
-- brings the menu up. What it looks like, and the real tooltip and context menu in the main
-- menu, this cannot say: that is for the game.
local T, W, M, K, Q = KnoxTheme, KnoxNewsLive, KnoxRMenu, KnoxMagKnown, ISTimedActionQueue
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end
local function run(name, fn)
    local ok, err = pcall(fn)
    if not ok then check(name .. ": no error", false, err) end
end

local HOST = ISPanel:new(0, 0, 1920, 1080)
KnoxMenuNewsReader = {instance = HOST}
local VIEW = {100, 200, 1000, 600}
local function up()
    W.hostGrid(HOST, 300, 400, VIEW)
    frame()
    W.hostGrid(HOST, 300, 400, VIEW)
end
local function count(ft)
    local n = 0
    for _, it in ipairs(W.inv.items) do if it.ft == ft then n = n + 1 end end
    return n
end
local function mags()
    local out = {}
    for _, it in ipairs(W.inv.items) do if it.ft == "Base.9mmClip" then table.insert(out, it) end end
    return out
end
local function untilIdle()
    local guard = 0
    while #W.queue > 0 and guard < 200 do
        frame(100)
        guard = guard + 1
    end
    check("the queue runs out", #W.queue == 0, #W.queue)
end

--- The key's block on the screen, frame after frame.
local function hold(ms)
    for _ = 1, math.ceil(ms / 16) do
        W.drawRBlock(HOST, 600, 500, VIEW, {r = 0.5, g = 0.7, b = 0.9})
        frame(16)
        if M.state then W.rLayer:render() end
    end
end

run("it comes", function()
    check("nothing yet", not W.live and W.view == nil)
    W.hostGrid(HOST, 300, 400, VIEW)
    check("asked only, during the drawing", W.want == HOST and not W.live)
    frame()
    check("before the next frame's drawing: up", W.live and W.view ~= nil and W.problem == nil, W.problem)
    check("the world: a gun in hand, two magazines, thirty rounds", W.gun ~= nil and PLAYER ~= W.player
        and W.player:getPrimaryHandItem() == W.gun and #mags() == 2 and count("Base.Bullets9mm") == 30)
    check("the grid is 8 x 2", W.view.layout.cols == 8 and W.view.layout.rows == 2)
    check("the gun in hand is no tile", (function()
        for _, e in ipairs(W.view.layout.placed) do if e.item == W.gun then return false end end
        return true
    end)())
    check("the player's own layout has no part in it", W.view.silhouettes == nil)
    check("how many rounds: hidden", K.hide == true and HIDE_FLAG == true)
    local m = mags()
    check("not known", not K.is(m[1]) and T.magLevel(m[1]) == T.LEVEL_UNKNOWN)
    check("the magazines in their places", m[1]:getModData().knox.x == 1 and m[2]:getModData().knox.x == 2)
    check("the context menu is its own", getPlayerContextMenu(0) == W.menu and W.menu ~= GAME_MENU)
    check("the menu on R draws on its own layer", M.layer == W.rLayer and M.inNews == true)
    check("everything over the post", W.menu.alwaysOnTop and W.dragLayer.alwaysOnTop and W.rLayer.alwaysOnTop)
    check("the layer leaves the tooltip to the frame", W.dragLayer.noTooltip == true)
    check("the grids are told", KnoxActions.newsView == W.view)
end)

run("it stands in the post", function()
    W.hostGrid(HOST, 300, 400, VIEW)
    local v = W.view
    check("a child of the post", v.parent == HOST)
    check("inside its frame", v:getX() == 302 and v:getY() == 402, v:getX())
    check("whole", v.clip[1] == 0 and v.clip[2] == 0 and v.clip[3] == 8 * T.cell + 5 and v.clip[4] == 2 * T.cell + 5)
    check("shown", v.vis == true)
    W.hostGrid(HOST, 300, 150, VIEW)   -- (scrolled, its top past the view's)
    check("its top cut off", v.clip[2] == 200 - 152, v.clip[2])
    check("off the cut part the mouse finds nothing", v:inClip(10, 5) == false and v:inClip(10, 60) == true)
    W.hostGrid(HOST, 300, -500, VIEW)
    check("out of the view: hidden", v.vis == false)
    W.hostGrid(HOST, 300, 400, VIEW)
    local down
    function HOST:onMouseDown(x, y) down = {x, y} return true end
    W.hostGrid(HOST, 300, 150, VIEW)
    v:onMouseDown(10, 5)
    check("a click on the cut part goes to the post", down and down[1] == 312 and down[2] == 157)
    HOST.onMouseDown = nil
    W.hostGrid(HOST, 300, 400, VIEW)
end)

run("every frame it is drawn with the real grid, cut to the view", function()
    local v = W.view
    local s0 = STENCILS
    v:prerender()
    v:render()
    check("no problem", W.problem == nil, W.problem)
    check("the stencil given back", STENCILS == s0)
    check("the tooltip applied before the drawing", (APPLIED or 0) > 0)
end)

run("the actions do what they do in the game, the game's queue stays out", function()
    local m = mags()
    local a, b = m[1], m[2]
    -- rounds dragged onto a magazine (real KnoxLoad)
    local rounds = {}
    for _, it in ipairs(W.inv.items) do
        if it.ft == "Base.Bullets9mm" and #rounds < 5 then table.insert(rounds, it) end
    end
    KnoxLoad.loadMagazine(W.player, a, {items = rounds})
    check("into the post's queue", #W.queue == 1 and W.queue[1].Type == "ISLoadBulletsInMagazine" and #GAME_QUEUE == 0, #W.queue)
    frame(10)
    check("under way, as the grid reads it", W.queue[1].action == true and W.queue[1].ammoCountStart == 7 and W.queue[1].maxTime == -1)
    untilIdle()
    check("the rounds went in: as many as fit, as in the game", a.n == 15 and count("Base.Bullets9mm") == 22, a.n)
    check("and now it is known", K.is(a) and not K.is(b))
    -- out of a magazine
    KnoxLoad.unloadMagazine(W.player, b)
    untilIdle()
    check("rounds out", b.n == 0 and count("Base.Bullets9mm") == 25, b.n)
    check("known too", K.is(b))
    -- a cleared queue
    KnoxLoad.loadMagazine(W.player, b, {items = {}})
    Q.clear(W.player)
    check("cleared", #W.queue == 0)
    check("the game's queue never asked", #GAME_QUEUE == 0)
end)

run("the gun: out, in, the bolt", function()
    local gun = W.gun
    ISInventoryPaneContextMenu.onEjectMagazine(W.player, gun)
    check("no asking the game to take it in hand", #GAME_QUEUE == 0)
    untilIdle()
    check("out of the gun: a new magazine with its rounds, known", gun:isContainsClip() == false and gun:getCurrentAmmoCount() == 0 and #mags() == 3)
    local out
    for _, m in ipairs(mags()) do if m.n == 9 then out = m end end
    check("nine in it", out ~= nil and K.is(out))
    gun:setRoundChambered(false)
    KnoxLoad.insertMagazine(W.player, gun, out)
    check("in, the game's way", #W.queue == 1 and W.queue[1].Type == "ISInsertMagazine", #W.queue)
    frame(10)
    frame(1000)
    check("the bolt after it: nothing in the chamber", #W.queue == 1 and W.queue[1].Type == "ISRackFirearm")
    check("in the gun", gun:isContainsClip() == true and gun:getCurrentAmmoCount() == 9 and #mags() == 2)
    untilIdle()
    check("racked", gun:isRoundChambered() == true and gun:getCurrentAmmoCount() == 8)
    local before = count("Base.Bullets9mm")
    ISInventoryPaneContextMenu.onRackGun(W.player, gun)
    untilIdle()
    check("racked again: the round comes out", count("Base.Bullets9mm") == before + 1 and gun:getCurrentAmmoCount() == 7)
end)

run("the context menu", function()
    local v = W.view
    v:rebuild()
    local magE, roundE
    for _, e in ipairs(v.layout.placed) do
        if e.item.ft == "Base.9mmClip" then magE = e end
        if e.item.ft == "Base.Bullets9mm" then roundE = e end
    end
    v:openMenu(magE, 5, 6)
    local menu = W.menu
    check("up at the mouse", menu.vis == true and menu.x == v:getAbsoluteX() + 5, menu.x)
    check("for the tile", TARGET and TARGET[1] == magE.item)
    check("the game's magazine menu first", menu.options[1].name ~= "ContextMenu_Drop ContextMenu_Drop", menu.options[1] and menu.options[1].name)
    local names = {}
    for _, o in ipairs(menu.options) do names[o.name] = o end
    check("drop", names["ContextMenu_Drop ContextMenu_Drop"] ~= nil)
    local more = names["ContextMenu_More ContextMenu_More"]
    check("more, with the star", more and more.sub and #more.sub.options == 1)
    frame()
    check("the reader knows", W.menuUp == true)
    check("over the post", menu.topAt ~= nil and more.sub.alwaysOnTop == true)
    -- the star
    local fav = more.sub.options[1]
    fav.fn(fav.target, fav.a, fav.b)
    check("a favorite", magE.item:isFavorite() == true)
    -- Esc shuts the menu, not the post
    check("Esc: the menu", W.onEsc() == true and menu.vis == false)
    frame()
    check("the reader knows it is gone", W.menuUp == false)
    check("Esc again: the post's", W.onEsc() == false)
    -- a favorite stays; another thing goes
    local d = names["ContextMenu_Drop ContextMenu_Drop"]
    local nm = #mags()
    d.fn(d.target, d.a, d.b)
    check("a favorite isn't dropped", #mags() == nm)
    v:openMenu(roundE, 5, 6)
    check("rounds: what they load comes first", menu.options[1].name ~= "ContextMenu_Drop ContextMenu_Drop", menu.options[1].name)
    local dropRounds
    for _, o in ipairs(menu.options) do if o.name == "ContextMenu_Drop ContextMenu_Drop" then dropRounds = o end end
    local n0 = count("Base.Bullets9mm")
    dropRounds.fn(dropRounds.target, dropRounds.a, dropRounds.b)
    check("dropped: gone from here", count("Base.Bullets9mm") == n0 - 1, count("Base.Bullets9mm"))
    W.menu:hideAndChildren()
    frame()
    check("what has nowhere to go here does nothing", v:doAction("quickMove", roundE) == nil and v:doAction("inspect", roundE) == nil)
end)

run("the menu on R", function()
    check("no plate yet, no menu", M.state == nil)
    local h = W.drawRBlock(HOST, 600, 500, VIEW, {r = 0.5, g = 0.7, b = 0.9})
    check("a plate as high as its key", h > 0)
    KEYS[R] = true
    hold(300)
    check("a short press: nothing", M.state == nil)
    hold(300)
    check("held: it opens, on the pretend character", M.state == "open" and M.player == W.player, M.state)
    check("the mouse is its own", M.catch ~= nil and M.catch.alwaysOnTop == true)
    check("the rows: this gun's magazines", #M.rows >= 2, #M.rows)
    check("no tooltip under it", W.view:entityUnderMouse() == nil)
    W.rLayer:render()
    check("it stands in the post", M.ox == 600 - math.floor((M.W or 0) / 2) and M.oy >= VIEW[2] and W.problem == nil, W.problem)
    hold(1000)
    W.rLayer:render()
    check("drawn with no error", W.problem == nil, W.problem)
    check("still open with the key held", M.state == "open", M.state)
    KEYS[R] = nil
    frame(16)
    W.rLayer:render()
    check("let go: it folds", M.state == "fold", M.state)
    frame(2000)
    W.rLayer:render()
    check("gone", M.state == nil, M.state)
    -- not while the block is off the screen
    KEYS[R] = true
    W.drawRBlock(HOST, 600, 5000, VIEW, {r = 0.5, g = 0.7, b = 0.9})
    frame(3000)
    check("off the screen: no", M.state == nil, M.state)
    KEYS[R] = nil
    frame()
end)

run("the game's queue and hands are only passed on", function()
    local other = {}
    Q.add({character = other})
    check("another's action: the game's", #GAME_QUEUE == 1 and GAME_QUEUE[1].character == other)
    Q.clear(other)
    check("another's clear: the game's", GAME_QUEUE[2].cleared == other)
    ISInventoryPaneContextMenu.equipWeapon("another gun", true, false, 0)
    check("another gun: the game's", GAME_QUEUE[3].equipped == "another gun")
    for i = #GAME_QUEUE, 1, -1 do GAME_QUEUE[i] = nil end
end)

run("the post closed: all of it gone", function()
    local view, drag, layer, menu, inv = W.view, W.dragLayer, W.rLayer, W.menu, W.inv
    KEYS[R] = true
    hold(600)
    check("the menu on R open as it closes", M.state == "open", M.state)
    KnoxMenuNewsReader.instance = nil
    frame()
    KEYS[R] = nil
    check("not live", W.live == false)
    check("no menu on R", M.state == nil and M.layer == nil and M.catch == nil and M.inNews == false)
    check("the Java flags back", RMENU_FLAG == false and HIDE_FLAG == false and K.hide == false)
    check("the elements gone", not drag.inUI and not layer.inUI and not menu.inUI)
    check("the game's menu back", getPlayerContextMenu(0) == GAME_MENU)
    check("the queue gone", ISTimedActionQueue.queues[W.player] == nil)
    check("the grids told", KnoxActions.newsView == nil)
    check("the view out of the post", not (HOST.kids and HOST.kids[view]))
    check("the container forgotten", KnoxGrid.fixedSize[inv] == nil and KnoxGrid.liveGrids[inv] == nil)
    check("the tooltip reset", RESET == true)
    check("Esc is the post's", W.onEsc() == false)
    Q.add({character = W.player})
    check("after it: not caught", #GAME_QUEUE == 1)
    for i = #GAME_QUEUE, 1, -1 do GAME_QUEUE[i] = nil end
    frame()
    check("nothing comes back by itself", W.live == false and W.view == nil)
end)

run("opened again: new things, as they were", function()
    KnoxMenuNewsReader.instance = HOST
    up()
    check("up", W.live and W.problem == nil, W.problem)
    local m = mags()
    check("two magazines, not known", #m == 2 and not K.is(m[1]) and not K.is(m[2]))
    check("thirty rounds", count("Base.Bullets9mm") == 30)
end)

run("an error is a line, and the block goes away", function()
    local say = print
    local said = 0
    print = function(s) said = said + 1 LAST = s end
    local renderWas = KnoxGridView.render
    KnoxGridView.render = function() error("broken on purpose") end
    W.view:render()
    frame()
    KnoxGridView.render = renderWas
    print = say
    check("one line", said == 1 and string.find(LAST, "[Knox]", 1, true) ~= nil, said)
    check("off", W.broken == true and W.live == false)
    check("all gone", getPlayerContextMenu(0) == GAME_MENU and M.layer == nil and K.hide == false)
    W.hostGrid(HOST, 300, 400, VIEW)
    check("no block any more", W.want == nil and W.drawRBlock(HOST, 600, 500, VIEW, {r = 0, g = 0, b = 0}) == 0)
    frame()
    check("it doesn't come back", W.live == false)
end)

-- a long bag name in a scrolled column (the players' "black bars", 2026-11-05)
run("a sliding name's clip goes with the scroll, no hole left", function()
    local T = KnoxTheme
    local calls = {}
    local ui = {}
    function ui:getXScroll() return 0 end
    function ui:getYScroll() return -120 end
    function ui:setStencilRect(x, y, w, h) table.insert(calls, {"set", x, y, w, h}) end
    function ui:clearStencilRect() table.insert(calls, {"clear"}) end
    function ui:repaintStencilRect(x, y, w, h) table.insert(calls, {"back", x, y, w, h}) end
    local textWas, measureWas = T.text, T.measure
    local at
    T.text = function(_, _, x, y) at = {x, y} end
    T.measure = function() return 500 end
    T.marquee(ui, {}, "a long name", 10, 200, 100, T.color.text, T.fontCaps, 1, {0, 0, 300, 400})
    check("the clip on the name: 200 down, 120 scrolled", calls[1][1] == "set" and calls[1][3] == 200 - 2 - 120, calls[1][3])
    check("the text in the content, where it stands", at[2] == 200, at[2])
    check("taken off", calls[2][1] == "clear")
    check("its box painted back", calls[3] and calls[3][1] == "back" and calls[3][3] == 78, calls[3] and calls[3][3])
    -- scrolled off the top: cut to the column
    calls = {}
    T.marquee(ui, {}, "a long name", 10, 120, 100, T.color.text, T.fontCaps, 1, {0, 0, 300, 400})
    check("cut to the column", calls[3] and calls[3][3] == 0 and calls[3][5] < T.fontH(T.fontCaps) + 4, calls[3] and calls[3][5])
    -- gone from it: nothing to paint
    calls = {}
    T.marquee(ui, {}, "a long name", 10, 50, 100, T.color.text, T.fontCaps, 1, {0, 0, 300, 400})
    check("out of it: no paint", calls[3] == nil)
    T.text, T.measure = textWas, measureWas
end)

check("no stencil left on", STENCILS == 0, STENCILS)
print("DONE pass=" .. pass .. " fail=" .. fail)
