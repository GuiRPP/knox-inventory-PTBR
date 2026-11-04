-- The menu on R (ammo_live, the author, 2026-10-31) on the game's Lua over load_pre and
-- rmenu_pre: the scales, the rows for each gun, the hints, the keys and the mouse,
-- what is queued. What it looks like in the game this cannot say.
local T, M, K = KnoxTheme, KnoxRMenu, KnoxMagKnown
T.active, T.modules.rmenu, T.modules.inventory = true, true, true
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

-- the scales ---------------------------------------------------------------------------
local want = {[15] = 5, [14] = 4, [10] = 4, [9] = 3, [6] = 3, [5] = 2, [4] = 2, [3] = 1, [1] = 1, [0] = 0}
for n, lit in pairs(want) do check("of 15: " .. n, M.levelOf(n, 15) == lit, M.levelOf(n, 15)) end
check("of 30, by parts", M.levelOf(20, 30) == 4 and M.levelOf(12, 30) == 3 and M.levelOf(8, 30) == 2 and M.levelOf(7, 30) == 1)
check("of 6", M.levelOf(6, 6) == 5 and M.levelOf(4, 6) == 4 and M.levelOf(1, 6) == 1)
check("no size: none", M.levelOf(3, 0) == 0)
check("rounds carried: one for a magazine's worth", M.reserveLit(0, 15) == 0 and M.reserveLit(1, 15) == 1 and M.reserveLit(15, 15) == 1 and M.reserveLit(16, 15) == 2)
check("rounds carried: 5 at most", M.reserveLit(500, 15) == 5)

-- the world -----------------------------------------------------------------------------
local function clearAll()
    for i = #INV.items, 1, -1 do INV.items[i].container = nil table.remove(INV.items, i) end
    for i = #BAG.items, 1, -1 do BAG.items[i].container = nil table.remove(BAG.items, i) end
    for i = #DONE, 1, -1 do DONE[i] = nil end
    for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
    for i = #GAME_KEYS, 1, -1 do GAME_KEYS[i] = nil end
    KEYS[R] = nil
    WINDOW, GAME_SPEED, INSTANT = nil, nil, nil
    M.abort()
    M.pressMs, M.tried, M.failed = nil, false, false
    PLAYER.primary = nil
end
local Dead = false
PLAYER.isDead = function() return Dead end
PLAYER.getPrimaryHandItem = function() return PLAYER.primary end
PLAYER.getPlayerNum = function() return 0 end
local function bump(ms) clock = clock + ms end
local function mag(n, known, ft)
    local m = newItem(ft or "Base.9mmClip", INV, {n = n})
    if known then K.mark(m) end
    return m
end
local function rounds(n, ft)
    for _ = 1, n do newItem(ft or "Base.Bullets9mm", INV) end
end
local function kinds()
    local out = {}
    for _, r in ipairs(M.rows) do table.insert(out, r.kind) end
    return table.concat(out, ",")
end
local function open() return M.open(PLAYER, R) end
local ui = KnoxRMenuLayer:new()
local function frame() M.frame(ui) end

-- a pistol ------------------------------------------------------------------------------
clearAll()
local pistol = newItem("Base.Pistol", INV, {n = 7, clip = true})
PLAYER.primary = pistol
local m1, m2, m3, m4 = mag(4, true), mag(15, true), mag(9), mag(0, true)
rounds(20)
check("opens", open() == true and M.state == "open")
check("the mouse held, the cursor hidden", RMENU_FLAG == true and M.catch:getIsVisible() == true)
check("a pistol's rows", kinds() == "swap,swap,swap,swap,all,eject,rack", kinds())
check("known fuller first, not known last", M.rows[1].m == m2 and M.rows[2].m == m1 and M.rows[3].m == m4 and M.rows[4].m == m3)
check("not known: a line", M.rows[4].known == false and M.rows[1].known == true)
check("lit: full, low, none", M.rows[1].lit == 5 and M.rows[2].lit == 2 and M.rows[3].lit == 0)
check("eject red, last but one", M.rows[6].red == true and M.rows[7].kind == "rack")
check("head", M.gun == pistol and M.title == "Base.Pistol" and M.gunNone == false)
check("the gun's scale", M.gunLit == 3, M.gunLit)
check("the chamber", M.chamber == true and M.chamberOn == false and M.jam == false)
check("rounds carried: 2 magazines' worth", M.strip and M.strip.n == 20 and M.strip.lit == 2, M.strip and M.strip.lit)

-- the frames, whatever is chosen
local function frames(n)
    for _ = 1, n do bump(40) frame() end
end
KEYS[R] = true
frames(10)
check("the plate's width at least the hints'", M.W >= M.hintsWide(), M.W)
local wasW = M.W

-- the hints
local s = M.hints
check("full magazine: RMB x2 unload", s.key3 == "IGUI_Knox_RMenu_RMB2 IGUI_Knox_RMenu_RMB2" and s.rmb == "IGUI_Knox_RMenu_Unload IGUI_Knox_RMenu_Unload" and s.noRmb == false, s.key3)
check("LMB swap", s.lmb == "IGUI_Knox_RMenu_Swap IGUI_Knox_RMenu_Swap" and s.noAct == false, s.lmb)
M.wheel(1) frames(1)
check("the wheel: down the list", M.sel == 2)
check("not full: RMB load", s.key3 == "IGUI_Knox_RMenu_RMB IGUI_Knox_RMenu_RMB" and s.rmb == "IGUI_Knox_RMenu_Load IGUI_Knox_RMenu_Load" and s.noRmb == false)
M.wheel(1) M.wheel(1) frames(1)
check("not known: load, whatever is in it (a hint gives nothing away)", M.sel == 4 and s.rmb == "IGUI_Knox_RMenu_Load IGUI_Knox_RMenu_Load" and s.noRmb == false)
M.wheel(1) M.wheel(1) frames(1)
check("another row: use", s.lmb == "IGUI_Knox_RMenu_Use IGUI_Knox_RMenu_Use" and s.noRmb == true)
M.wheel(-1) M.wheel(-1) M.wheel(-1) M.wheel(-1) M.wheel(-1) M.wheel(-1) frames(1)
check("the wheel goes round", M.sel == 7, M.sel)
M.wheel(1)
check("and round", M.sel == 1, M.sel)
frames(1)
check("the width stays", M.W == wasW)

-- the panel at the crosshair coming up under it: it stays (the camera turns with it open, the author 2026-11-04)
KnoxCrosshair = {visible = true}
frames(2)
check("the crosshair panel coming up: the menu stays", M.state == "open", M.state)
KnoxCrosshair = nil

-- the mouse: left
M.sel = 2
M.lmb()
local function queued(name)
    for _, a in ipairs(QUEUE) do if a.name == name then return a end end
    return nil
end
check("LMB: the old one out, the new one in", queued("ISEjectMagazine") ~= nil and queued("ISInsertMagazine") ~= nil and queued("ISInsertMagazine").b == m1)
check("LMB on the magazine: the one it was on still", M.current().m == m1)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
for i = #DONE, 1, -1 do DONE[i] = nil end
frames(1)   -- (an action over: rows anew)

-- the mouse: right, once and twice
local function selectMag(m)
    for i, r in ipairs(M.rows) do if r.m == m then M.sel = i end end
end
selectMag(m1)
M.rmb()
check("RMB: not yet", #QUEUE == 0)
bump(100) frame()
check("RMB: still not, it may be the first of two", #QUEUE == 0)
bump(200) frame()
local a = queued("ISLoadBulletsInMagazine")
check("RMB: load after 250 ms", a ~= nil and a.magazine == m1 and a.b == 11, a and a.b)
check("load: walking does not stop it, as the game", a and a.stopOnWalk == false)
check("load: the magazine known", K.is(m1))
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
frames(1)
selectMag(m2)
M.rmb()
bump(100) frame()
M.rmb()
a = queued("ISUnloadBulletsFromMagazine")
check("RMB twice within 250 ms: unload at once", a ~= nil and a.magazine == m2 and a.stopOnWalk == false)
check("RMB twice: no load after", (function() bump(400) frame() return queued("ISLoadBulletsInMagazine") == nil end)())
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
frames(1)
-- (QA 2026-10-31) another row chosen between the two clicks: the first one's load, the new one waits
selectMag(m1)
M.rmb()
bump(50) frame()
selectMag(m4)
M.rmb()
a = queued("ISLoadBulletsInMagazine")
check("RMB, another row, RMB: the first loaded, not unloaded", a ~= nil and a.magazine == m1 and queued("ISUnloadBulletsFromMagazine") == nil)
check("...the second waits for its own", M.armed ~= nil and M.armedItem == m4)
bump(300) frame()
a = queued("ISLoadBulletsInMagazine")
check("...then loaded in its turn", a ~= nil and a.magazine == m4, a and a.magazine and a.magazine.n)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
frames(1)

-- not known: loading tells
local fresh = mag(3)
bump(600) frames(1)   -- (a magazine come: seen within half a second)
check("a magazine come: a row", (function() for _, r in ipairs(M.rows) do if r.m == fresh then return true end end return false end)())
selectMag(fresh)
M.rmb()
bump(300) frame()
check("loading asked: not known yet (begun and stopped, it tells nothing)", not K.is(fresh))
ISLoadBulletsInMagazine.animEvent(QUEUE[1], "InsertBullet")
check("a round in: known", K.is(fresh))
-- the fill on its row: the whole job
local job = QUEUE[1]
job.action, job.delta = true, 0.4
frames(1)
local row
for _, r in ipairs(M.rows) do if r.m == fresh then row = r end end
check("the row's fill: as far as the job", row.prog == 0.4 and row.out == false, row.prog)
local un = ISUnloadBulletsFromMagazine:new(PLAYER, fresh)
un.action, un.delta = true, 0.75
QUEUE[1] = un
frames(1)
check("unloading: the fill from the right, as much as has come out", math.abs(row.prog - 0.25) < 0.001 and row.out == true, row.prog)
QUEUE[1] = nil
frames(1)

-- let go: closes, nothing done, what is under way goes on
KEYS[R] = nil
ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(PLAYER, m1, 3))
ISFirearmRadialMenu.onKeyReleased(R)
check("let go: closed", M.state == "fold" and RMENU_FLAG == false and M.catch:getIsVisible() == false)
check("let go: the game's handler not asked", #GAME_KEYS == 0 or GAME_KEYS[#GAME_KEYS] ~= "released")
check("let go: what is under way goes on", #QUEUE == 1)
M.lmb() M.wheel(1) M.rmb()
check("closed: the mouse does nothing", #QUEUE == 1 and M.armed == nil)
bump(500) frame()
check("folded away", M.state == nil)

-- the key: short and long --------------------------------------------------------------
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
mag(5, true)
ISFirearmRadialMenu.onKeyPressed(R)
check("press: the game's, for its reload", GAME_KEYS[1] == "pressed")
KEYS[R] = true
bump(100)
ISFirearmRadialMenu.onKeyRepeat(R)
check("held a moment: nothing yet, the game's menu not asked", M.state == nil and #GAME_KEYS == 1)
ISFirearmRadialMenu.onKeyReleased(R)
check("let go early: the game's reload", GAME_KEYS[2] == "released" and M.state == nil)
for i = #GAME_KEYS, 1, -1 do GAME_KEYS[i] = nil end
ISFirearmRadialMenu.onKeyPressed(R)
bump(499)
ISFirearmRadialMenu.onKeyRepeat(R)
check("499 ms: not yet", M.state == nil)
bump(1)
ISFirearmRadialMenu.onKeyRepeat(R)
check("500 ms: it is up", M.state == "open")
check("the game's round menu never asked", GAME_KEYS[2] == nil)
frame()
ISFirearmRadialMenu.onKeyReleased(R)
check("let go after: no reload", GAME_KEYS[2] == nil and M.state == "fold")
bump(500) frame()
-- another key
for i = #GAME_KEYS, 1, -1 do GAME_KEYS[i] = nil end
ISFirearmRadialMenu.onKeyRepeat(5)
check("another key: the game's", GAME_KEYS[1] == "repeat")
-- R again while loading (QA 2026-10-31): held, the menu over it and the loading goes on;
-- short, the game's stop and rack - put off till R is let go
local function said(kind)
    for _, d in ipairs(DONE) do if d[1] == kind then return d end end
    return nil
end
clearAll()
local sgun = newItem("Base.Shotgun", INV, {n = 2})
PLAYER.primary = sgun
rounds(4, "Base.ShotgunShells")
ISTimedActionQueue.add(ISReloadWeaponAction:new(PLAYER, sgun))
LOADING = true
ISFirearmRadialMenu.onKeyPressed(R)
PRESS_RELOAD(PLAYER, sgun)
check("R while loading: the game's stop put off", said("stopRack") == nil and #QUEUE == 1)
KEYS[R] = true
bump(600)
ISFirearmRadialMenu.onKeyRepeat(R)
check("held: the menu over the loading", M.state == "open" and #QUEUE == 1)
KEYS[R] = nil
ISFirearmRadialMenu.onKeyReleased(R)
check("let go: no stop, the loading goes on", said("stopRack") == nil and #QUEUE == 1 and M.heldRack == nil)
bump(500) frame()
ISFirearmRadialMenu.onKeyPressed(R)
PRESS_RELOAD(PLAYER, sgun)
bump(100)
ISFirearmRadialMenu.onKeyReleased(R)
local stop = said("stopRack")
check("short: the game's stop and rack, on letting go", stop ~= nil and stop[2] == sgun and M.state == nil)
check("short: then the game's release", GAME_KEYS[#GAME_KEYS] == "released")
for i = #DONE, 1, -1 do DONE[i] = nil end
-- held, the menu up, something else closes it, then let go: still no stop (QA round 2)
ISFirearmRadialMenu.onKeyPressed(R)
PRESS_RELOAD(PLAYER, sgun)
KEYS[R] = true
bump(600)
ISFirearmRadialMenu.onKeyRepeat(R)
WINDOW = true
bump(10) frame()
WINDOW = nil
bump(500) frame()
KEYS[R] = nil
ISFirearmRadialMenu.onKeyReleased(R)
check("held, closed by a window, let go: no stop", M.state == nil and said("stopRack") == nil)
-- the game's "instant" round menu: the game's stop at once, as in the game
INSTANT = true
PRESS_RELOAD(PLAYER, sgun)
check("instant: the game's stop at once", said("stopRack") ~= nil and M.heldRack == nil)
INSTANT = nil
for i = #DONE, 1, -1 do DONE[i] = nil end
LOADING = false
PRESS_RELOAD(PLAYER, sgun)
check("not loading: the game's at once", said("stopRack") ~= nil)
for i = #DONE, 1, -1 do DONE[i] = nil end
LOADING = true
JoypadState.players[1] = {}
PRESS_RELOAD(PLAYER, sgun)
check("a gamepad: the game's at once", said("stopRack") ~= nil and M.heldRack == nil)
JoypadState.players[1] = nil
LOADING = false
-- instant in the game's options
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
INSTANT = true
ISFirearmRadialMenu.onKeyPressed(R)
ISFirearmRadialMenu.onKeyRepeat(R)
check("instant: at once", M.state == "open")
-- the module off: the game's own
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
T.modules.rmenu = false
ISFirearmRadialMenu.onKeyPressed(R)
bump(600)
ISFirearmRadialMenu.onKeyRepeat(R)
ISFirearmRadialMenu.onKeyReleased(R)
check("off: all the game's", GAME_KEYS[2] == "repeat" and GAME_KEYS[3] == "released" and M.state == nil)
T.modules.rmenu = true
-- a gamepad: the game's own
clearAll()
JoypadState.players[1] = {}
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
ISFirearmRadialMenu.onKeyPressed(R)
bump(600)
ISFirearmRadialMenu.onKeyRepeat(R)
check("a gamepad: the game's", GAME_KEYS[2] == "repeat" and M.state == nil)
JoypadState.players[1] = nil
-- not over a window, not paused, not busy with another's
local function holds()
    M.abort()
    M.tried = false
    ISFirearmRadialMenu.onKeyPressed(R)
    bump(600)
    ISFirearmRadialMenu.onKeyRepeat(R)
    return M.state == "open"
end
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
check("in the world: yes", holds())
WINDOW = true
check("a window open: no", not holds())
WINDOW = nil
GAME_SPEED = 0
check("paused: no", not holds())
GAME_SPEED = nil
Dead = true
check("dead: no", not holds())
Dead = false
KnoxCrosshair = {visible = true}
check("the crosshair panel: no", not holds())
KnoxCrosshair = nil
QUEUE[1] = {Type = "ISEatFoodAction"}
check("eating: no", not holds())
QUEUE[1] = {Type = "ISLoadBulletsInMagazine"}
check("its own under way: yes", holds())
QUEUE[1] = nil
-- closed by something else with R down: not again until let go
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
KEYS[R] = true
check("opens", holds())
WINDOW = true
bump(10) frame()
check("a window came: closed", M.state == "fold" and RMENU_FLAG == false)
WINDOW = nil
bump(500) frame()
ISFirearmRadialMenu.onKeyRepeat(R)
check("R still down: not again", M.state == nil)
-- died with it open
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
KEYS[R] = true
check("opens", holds())
Dead = true
frame()
check("dead: closed, the mouse let go", M.state ~= "open" and RMENU_FLAG == false)
Dead = false
-- an error in a frame: the game's menu back, the mouse let go
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
KEYS[R] = true
check("opens", holds())
local realFrame = M.frame
M.frame = function() error("boom") end
ui:render()
M.frame = realFrame
check("an error: off, let go", M.failed == true and M.state == nil and RMENU_FLAG == false)
check("an error: the numbers back with the game's menu", K.hide == false and HIDE_FLAG == false)
M.failed = false
ui:render()
check("the numbers hidden again with the menu", K.hide == true and HIDE_FLAG == true)
-- an error in a click (QA 2026-10-31): the same, and the click still taken
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
KEYS[R] = true
check("opens", holds())
local realLmb = M.lmb
M.lmb = function() error("boom") end
local took = M.catch:onMouseDown(10, 10)
M.lmb = realLmb
check("an error in a click: off, let go, taken", took == true and M.failed == true and M.state == nil and RMENU_FLAG == false and K.hide == false)
M.failed = false
-- the numbers follow the menu (QA 2026-10-31): a gamepad's player has the game's round menu, numbers and all
ui:render()
check("keyboard: hidden", K.hide == true)
JoypadState.players[1] = {}
ui:render()
check("a gamepad: shown", K.hide == false and HIDE_FLAG == false)
JoypadState.players[1] = nil
ui:render()
check("the gamepad gone: hidden", K.hide == true and HIDE_FLAG == true)

-- nothing to show -----------------------------------------------------------------------
clearAll()
ISFirearmRadialMenu.onKeyPressed(R)
bump(600)
ISFirearmRadialMenu.onKeyRepeat(R)
check("no gun, no magazines: no menu", M.state == nil and RMENU_FLAG == false)
check("no menu: not asked again", M.tried == true)
ISFirearmRadialMenu.onKeyReleased(R)
check("no menu: the game's", GAME_KEYS[#GAME_KEYS] == "released")

-- no magazine in the gun, jammed --------------------------------------------------------
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 0})
local only = mag(5, true)
check("opens", open())
check("no magazine: insert, no eject", kinds() == "insert,all,rack", kinds())
check("no magazine: a line", M.gunNone == true)
KEYS[R] = true
frame()
check("hint: insert", M.hints.lmb == "IGUI_Knox_RMenu_Insert IGUI_Knox_RMenu_Insert")
M.lmb()
check("insert: no eject", queued("ISEjectMagazine") == nil and queued("ISInsertMagazine").b == only)
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true, jam = true})
check("opens", open())
check("jammed: first row, no rack", kinds() == "unjam,eject", kinds())
check("jammed: red", M.rows[1].red == true and M.jam == true)
M.lmb()
check("unjam: the game's rack", DONE[#DONE][1] == "rack")

-- a shotgun, a revolver -----------------------------------------------------------------
clearAll()
local gun = newItem("Base.Shotgun", INV, {n = 2})
PLAYER.primary = gun
rounds(10, "Base.ShotgunShells")
check("opens", open())
check("a shotgun's rows", kinds() == "self,rack", kinds())
check("its first row: itself, its scale", M.rows[1].m == gun and M.rows[1].known == true and M.rows[1].lit == 2, M.rows[1].lit)
check("a pump's name", M.rows[2].name == "IGUI_Knox_RMenu_RackPump IGUI_Knox_RMenu_RackPump")
KEYS[R] = true
frame()
check("hints: LMB load, RMB x2 unload", M.hints.lmb == "IGUI_Knox_RMenu_Load IGUI_Knox_RMenu_Load" and M.hints.key3 == "IGUI_Knox_RMenu_RMB2 IGUI_Knox_RMenu_RMB2" and M.hints.noAct == false and M.hints.noRmb == false)
M.lmb()
a = queued("ISReloadWeaponAction")
check("LMB: loads, walking does not stop it", a and a.gun == gun and a.stopOnWalk == false)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
M.rmb() bump(50) frame() M.rmb()
a = queued("ISUnloadBulletsFromFirearm")
check("RMB twice: unloads", a and a.gun == gun and a.stopOnWalk == false)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
frames(1)
gun.n = 6
bump(200) frames(1)
check("full: LMB out", M.hints.noAct == true)
gun.n = 0
bump(200) frames(1)
check("empty: unload out", M.hints.noRmb == true)
gun.n = 2
for i = #INV.items, 1, -1 do if INV.items[i].ft == "Base.ShotgunShells" then table.remove(INV.items, i) end end
bump(200) frames(1)
check("no shells: LMB out", M.hints.noAct == true)
check("none carried: all faint", M.strip.lit == 0)

clearAll()
PLAYER.primary = newItem("Base.Revolver", INV, {n = 6})
check("opens", open())
check("a revolver: no rack, no chamber", kinds() == "self" and M.chamber == false, kinds())

-- no gun --------------------------------------------------------------------------------
clearAll()
local b1, b2 = mag(0, true), mag(7)
newItem("Base.Bullets9mmBox", INV)
rounds(30)
check("opens", open())
check("bare rows", kinds() == "bag,bag,all,box", kinds())
check("the head", M.gun == nil and M.tex == nil and M.title == "IGUI_Knox_RMenu_NoWeapon IGUI_Knox_RMenu_NoWeapon")
KEYS[R] = true
frame()
check("LMB out on a magazine", M.hints.noAct == true)
M.lmb()
check("LMB on a magazine: nothing", #QUEUE == 0)
check("the rounds follow the magazine", M.strip.key == "Base.Bullets9mm" and M.strip.n == 30)
M.sel = 4
frames(1)
check("the rounds stay on the box's row", M.strip.key == "Base.Bullets9mm")
M.lmb()
check("the box: opened", DONE[#DONE][1] == "craft", DONE[#DONE] and DONE[#DONE][1])

-- many rows: the list scrolls, the width stays ------------------------------------------
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
for _ = 1, 12 do mag(5, true) end
check("opens", open())
KEYS[R] = true
frames(10)
check("15 rows: the list is cut", M.clipped == true and #M.rows == 15)
local h0, w0 = M.H, M.W
for _ = 1, 14 do
    M.wheel(1)
    frames(12)
    local r = M.current()
    check("row " .. M.sel .. " in sight", r.y >= math.floor(M.scroll) - 1 and r.y + r.h <= M.scroll + M.viewH + 1, r.y .. " " .. M.scroll)
end
check("the plate stays as it was", M.H == h0 and M.W == w0)
check("the last chosen", M.sel == 15)

-- sizes from the cell: nothing stretched, no crooked sides ------------------------------
for _, cell in ipairs({48, 64, 96}) do
    local was = T.cell
    T.cell = cell
    clearAll()
    PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
    mag(5, true)
    check("opens at " .. cell, open())
    local Z = M.Z
    check("at " .. cell .. ": the rows' sizes grow", Z.ROW == math.floor(32 * cell / 48 + 0.5) and Z.CELL == math.floor(26 * cell / 48 + 0.5))
    check("at " .. cell .. ": five parts, four gaps", Z.SCW == 5 * Z.SW + 4 * Z.SG)
    T.cell = was
end

-- a magazine: what the character knows --------------------------------------------------
clearAll()
local found = mag(5)
check("found: not known", K.is(found) == false)
K.mark(found)
check("marked: known", K.is(found) == true and found.md.knoxMag == true)
local inMag = mag(5)
ISLoadBulletsInMagazine.animEvent({magazine = inMag, character = PLAYER}, "InsertBullet")
check("a round in: known", K.is(inMag))
local other = mag(5)
ISUnloadBulletsFromMagazine.animEvent({magazine = other, character = PLAYER}, "Other")
check("another event: no", not K.is(other))
ISUnloadBulletsFromMagazine.start({magazine = other, character = PLAYER})
check("unloading begun, rounds in it: not yet (QA 2026-10-31)", not K.is(other))
ISUnloadBulletsFromMagazine.animEvent({magazine = other, character = PLAYER}, "RemoveBullet")
check("a round out: known", K.is(other))
local hollow = mag(0)
ISUnloadBulletsFromMagazine.start({magazine = hollow, character = PLAYER})
check("unloading an empty one: over at once, known", K.is(hollow))
-- out of a gun: known as it is made
local ej = {}
local realMake = instanceItem
ISEjectMagazine.unloadAmmo(ej)
check("out of a gun: known as it is made", ej.made and K.is(ej.made))
check("the game's instanceItem back", instanceItem == realMake)
-- the hidden rounds (stage 3, the author, 2026-10-31) ------------------------------------
clearAll()
K.hide = false
local ctx = newContext()
local plainMag = mag(15)
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, plainMag, ctx)
check("not hidden: the game's menu", ctx.options[1].name == "game:mag 15")
K.hide = true
rounds(10)
local function names(c)
    local out = {}
    for _, o in ipairs(c.options) do table.insert(out, o.name) end
    return table.concat(out, ",")
end
local LOADM, UNLOADM = "IGUI_Knox_RMenu_LoadMagazine IGUI_Knox_RMenu_LoadMagazine", "ContextMenu_UnloadMagazine ContextMenu_UnloadMagazine"
ctx = newContext()
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, plainMag, ctx)
check("not known, full: both, no number", names(ctx) == LOADM .. "," .. UNLOADM, names(ctx))
local emptyMag = mag(0)
ctx = newContext()
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, emptyMag, ctx)
check("not known, empty: both", names(ctx) == LOADM .. "," .. UNLOADM, names(ctx))
local knownFull, knownEmpty = mag(15, true), mag(0, true)
ctx = newContext()
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, knownFull, ctx)
check("known, full: unload only", names(ctx) == UNLOADM, names(ctx))
ctx = newContext()
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, knownEmpty, ctx)
check("known, empty: load only", names(ctx) == LOADM, names(ctx))
ctx.options[1].fn(ctx.options[1].target, ctx.options[1].a, ctx.options[1].b)
check("load from the menu: as many as go in", DONE[#DONE][1] == "loadMenu" and DONE[#DONE][3] == 10, DONE[#DONE][3])
ctx = newContext()
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, emptyMag, ctx)
ctx.options[1].fn(ctx.options[1].target, ctx.options[1].a, ctx.options[1].b)
check("loading from the menu: known only when a round goes in (QA 2026-10-31)", not K.is(emptyMag) and DONE[#DONE][1] == "loadMenu")
-- (QA 2026-10-31) one not known and full: one round tried, not nothing done
ctx = newContext()
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, plainMag, ctx)
ctx.options[1].fn(ctx.options[1].target, ctx.options[1].a, ctx.options[1].b)
check("not known, full, loaded from the menu: one round tried", DONE[#DONE][1] == "loadMenu" and DONE[#DONE][3] == 1 and not K.is(plainMag), DONE[#DONE][3])
-- the menu on R the same way
M.player = PLAYER
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
check("R: not known and full, load: one round tried", M.load(plainMag) == true and queued("ISLoadBulletsInMagazine").b == 1 and not K.is(plainMag))
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
check("R: known and full, load: nothing", M.load(knownFull) == false and #QUEUE == 0)
-- (pressed again while the rounds are still coming over from a bag: the loading behind them stands - QA, 2026-11-04)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
local half = mag(5, true)
QUEUE[1] = {Type = "ISInventoryTransferAction"}
QUEUE[2] = {Type = "ISLoadBulletsInMagazine", magazine = half}
check("R: loading behind a transfer, pressed again: left as it is", M.load(half) == true and #QUEUE == 2 and QUEUE[1].Type == "ISInventoryTransferAction")
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
INV:remove(half)
local blank = mag(0)
check("R: not known and empty, unload: the game's action finds it so", M.unload(blank) == true and queued("ISUnloadBulletsFromMagazine") ~= nil and not K.is(blank))
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
check("R: known and empty, unload: nothing", M.unload(knownEmpty) == false and #QUEUE == 0)
M.player = nil
INV:remove(blank)
for i = #INV.items, 1, -1 do if INV.items[i].ft == "Base.Bullets9mm" then table.remove(INV.items, i) end end
local other = mag(4)
ctx = newContext()
ISInventoryPaneContextMenu.doMagazineMenu(PLAYER, other, ctx)
check("no rounds: the game's word, out", ctx.options[1].name == "ContextMenu_NoBullets ContextMenu_NoBullets" and ctx.options[1].notAvailable == true)
-- from the rounds: each magazine, no number in its tooltip
rounds(3)
ctx = newContext()
ISInventoryPaneContextMenu.doReloadMenuForBullets(PLAYER, newItem("Base.Bullets9mm"), ctx)
local saysNumber = false
for _, o in ipairs(ctx.options) do
    if string.find(o.name, "%d") then saysNumber = true end
    if o.toolTip and string.find(o.toolTip.description, "AmmoCount", 1, true) then saysNumber = true end
end
check("from the rounds: the magazines not known or not full, no numbers", #ctx.options == 4 and not saysNumber, #ctx.options)
-- a gun that takes rounds itself
local sg = newItem("Base.Shotgun", INV, {n = 2})
rounds(4, "Base.ShotgunShells")
ctx = newContext()
ISInventoryPaneContextMenu.doBulletMenu(PLAYER, sg, ctx)
check("a shotgun: load without a number, unload", ctx.options[1].name == "IGUI_Knox_RMenu_LoadGun IGUI_Knox_RMenu_LoadGun" and not ctx.options[1].notAvailable and #ctx.options == 2)
-- the game's round menu: the counts left out
ISFirearmRadialMenu.fillMenu({playerNum = 0})
check("round menu: names only", RADIAL.slices[1].text == "Eject" and RADIAL.slices[2].text == "Rack" and RADIAL.slices[3].text == "Plain")
K.hide = false
ISFirearmRadialMenu.fillMenu({playerNum = 0})
check("round menu, not hidden: as the game", RADIAL.slices[1].text == "Eject\n7 / 15")

-- the Shift panel: no numbers, an order that tells nothing
K.hide = true
local P = KnoxSlotPicker
local L = KnoxLoad
local function ref(item)
    return {item = item, getAbsoluteX = function() return 300 end, getAbsoluteY = function() return 200 end,
            getWidth = function() return 48 end, getHeight = function() return 48 end}
end
local function panel(r)
    P.close()
    clock = clock + 1000
    P.sweep()
    L.panelFor = r.item
    L.offer(r, r.item, PLAYER, 0)
    clock = clock + 130
    L.offer(r, r.item, PLAYER, 0)
    P.sync(nil)
    return P.instance, P.instance and P.instance.load
end
clearAll()
K.hide = true
local pg = newItem("Base.Pistol", INV, {n = 7, clip = true})
local u1, k1, k2, u2 = mag(15), mag(3, true), mag(12, true), mag(1)
local p, l = panel(ref(pg))
check("a pistol's panel: no number in its header", p ~= nil and l.total == "" and l.widest == "", l and l.total)
check("its spares: known fuller first, not known last", l.spares[1].item == k2 and l.spares[2].item == k1
    and (l.spares[3].item == u1 or l.spares[3].item == u2), l.spares[1].item.n)
local ru = ref(u2)
p, l = panel(ru)
check("a magazine not known: no number", l.total == "")
check("not known: unload offered, whatever is in it", l.hint(1) == "unload")
rounds(5)
L.panelFor = nil
p, l = panel(ref(u1))
check("not known and full: load still offered (nothing goes out to tell)", l.hint(2) == "load")
-- (QA 2026-10-31) ...and loading it is one round tried, not nothing done
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
local loose = {}
for _, it in ipairs(INV.items) do if it.ft == "Base.Bullets9mm" then table.insert(loose, it) end end
L.loadMagazine(PLAYER, u1, {items = loose})
local tried = queued("ISLoadBulletsInMagazine")
check("Shift: not known and full, load: one round tried", tried ~= nil and tried.b == 1 and not K.is(u1), tried and tried.b)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
K.mark(u1)
L.loadMagazine(PLAYER, u1, {items = loose})
check("Shift: known and full, load: nothing", #QUEUE == 0)
p, l = panel(ref(k2))
check("known: as it is", l.hint(1) == "unload")
K.hide = false

-- all the magazines loaded (the author, 2026-11-04) ---------------------------------------
clearAll()
K.hide = true
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
local fullK, lowK, midK, oddU = mag(15, true), mag(4, true), mag(9, true), mag(15)
rounds(18)
check("opens", open())
check("the row: after the magazines, before eject", kinds() == "swap,swap,swap,swap,all,eject,rack", kinds())
M.sel = 5
KEYS[R] = true
frames(1)
check("all: LMB load", M.hints.lmb == "IGUI_Knox_RMenu_Load IGUI_Knox_RMenu_Load" and M.hints.noAct == false and M.hints.noRmb == true)
M.lmb()
local loads = {}
for _, q in ipairs(QUEUE) do if q.name == "ISLoadBulletsInMagazine" then table.insert(loads, q) end end
check("all: fuller first, the full one left", #loads == 3 and loads[1].magazine == midK and loads[1].b == 6 and loads[2].magazine == lowK and loads[2].b == 11, #loads)
check("all: one not known and full, one round tried", loads[3] and loads[3].magazine == oddU and loads[3].b == 1)
check("all: the menu may come up over it", M.jobQueued(PLAYER) == true)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
for _ = 1, 10 do INV:remove(INV:getAllTypeRecurse("Base.Bullets9mm"):get(0)) end
M.loadAll(M.rows[5].mags)
loads = {}
for _, q in ipairs(QUEUE) do if q.name == "ISLoadBulletsInMagazine" then table.insert(loads, q) end end
check("all: as far as the rounds go", #loads == 2 and loads[2].magazine == lowK and loads[2].b == 2, #loads)
for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
for i = #INV.items, 1, -1 do if INV.items[i].ft == "Base.Bullets9mm" then table.remove(INV.items, i) end end
bump(200) frames(1)
check("no rounds: LMB out", M.hints.noAct == true)
M.lmb()
check("no rounds: nothing", #QUEUE == 0)
clearAll()
PLAYER.primary = newItem("Base.Pistol", INV, {n = 7, clip = true})
mag(15, true)
rounds(5)
check("opens", open())
check("all known full: no row", kinds() == "swap,eject,rack", kinds())
clearAll()
mag(3, true) mag(5, true)
rounds(30)
check("opens", open())
check("no gun: the row too", kinds() == "bag,bag,all", kinds())
M.sel = 3
KEYS[R] = true
frames(1)
M.lmb()
check("no gun: both loaded", (function()
    local n = 0
    for _, q in ipairs(QUEUE) do if q.name == "ISLoadBulletsInMagazine" then n = n + 1 end end
    return n
end)() == 2)
-- the scale counts the round in the chamber (the author, 2026-11-04)
clearAll()
local rifle = newItem("Base.AssaultRifle", INV, {n = 29, clip = true, chambered = true})
PLAYER.primary = rifle
check("opens", open())
check("a full magazine in: 29 + 1, a full scale", M.gunLit == 5, M.gunLit)
rifle.n = 28
bump(200) KEYS[R] = true frames(1)
check("one shot: a part less", M.gunLit == 4, M.gunLit)
clearAll()
PLAYER.primary = newItem("Base.Shotgun", INV, {n = 5, chambered = true})
check("opens", open())
check("a shotgun, 5 + 1: full", M.rows[1].lit == 5 and M.rows[1].n == 5, M.rows[1].lit)
K.hide = false

-- the magazines back from the pockets (the author, 2026-11-04) ----------------------------
local function wearing(loc, name)
    local c = newContainer(name)
    local item = newItem("Base.Beans", INV, {cls = "InventoryContainer", inner = c})
    c.holder = item
    item.getInventory = function() return c end
    table.insert(WORN, {getItem = function() return item end, getLocation = function() return loc end})
    return c
end
local function fresh2()
    clearAll()
    for i = #WORN, 1, -1 do WORN[i] = nil end
    ROOM = {}
    AIMING, CHOSEN = nil, nil
end
local function loaded(from)
    local m = newItem("Base.9mmClip", from, {n = 3})
    ISLoadBulletsInMagazine:new(PLAYER, m, 5)
    return m
end
local function looks()
    bump(200) L.lookBack()
end
fresh2()
local pack, rig = wearing("back", "pack"), wearing("webbing", "rig")
ROOM[pack], ROOM[rig] = 5, 5
CHOSEN = pack
local m5 = loaded(pack)
looks()
check("not moved to the pockets: stays", m5.container == pack)
-- out of a bag: the transfer to the pockets is queued, and the first look comes before it (QA, 2026-11-04)
local mq = loaded(pack)
QUEUE[1] = {Type = "ISInventoryTransferAction"}
looks()
INV:add(mq)
QUEUE[1] = nil
looks()
check("still in the bag, the transfer in the queue: not forgotten, goes back", mq.container == rig)
local mc = loaded(pack)
QUEUE[1] = {Type = "ISInventoryTransferAction"}
looks()
QUEUE[1] = nil
looks()
INV:add(mc)
looks()
check("the transfer given up: forgotten, not taken back later", mc.container == INV)
local mh = loaded(pack)
QUEUE[1] = {Type = "ISInventoryTransferAction"}
rig:add(mh)
looks()
QUEUE[1] = nil
INV:add(mh)
looks()
check("carried off somewhere else meanwhile: forgotten", mh.container == INV)
-- the game's own inventory: the game's way (the author, 2026-11-04)
T.modules.inventory = false
local mo = loaded(INV)
looks()
check("no Knox inventory: stays in the pockets", mo.container == INV)
T.modules.inventory = true
m5 = loaded(pack)
INV:add(m5)
QUEUE[1] = {Type = "ISInsertMagazine"}
looks()
check("back: not while there is something to do", m5.container == INV)
QUEUE[1] = nil
AIMING = true
looks()
check("back: not while aiming", m5.container == INV)
AIMING = nil
looks()
check("back: rig first, whatever is worn first", m5.container == rig)
ROOM[rig] = 0
local m6 = loaded(rig)
INV:add(m6)
looks()
check("no room in the rig: the container chosen", m6.container == pack)
CHOSEN = nil
local m6b = loaded(rig)
INV:add(m6b)
looks()
check("no room anywhere, none chosen: a backpack worn is not the one, it stays in the pockets", m6b.container == INV)
CHOSEN = pack
ROOM[rig], ROOM[pack] = 1, 5
local m7, m8 = loaded(INV), loaded(INV)
looks()
check("two, one place in the rig: one in each", (m7.container == rig and m8.container == pack) or (m7.container == pack and m8.container == rig))
-- no rig, no backpack: where it was; not onto the floor
fresh2()
local bagC = wearing("belt", "belt bag")
ROOM[bagC] = 5
local m9 = loaded(bagC)
INV:add(m9)
looks()
check("nothing worn for it: back where it was", m9.container == bagC)
local m10 = loaded(FLOOR)
INV:add(m10)
looks()
check("from the floor: it stays in the pockets", m10.container == INV)
-- put in the gun on the way (the game's reload): left alone
fresh2()
rig = wearing("webbing", "rig")
ROOM[rig] = 5
local m11 = loaded(INV)
INV:remove(m11)
m11.container = nil
looks()
check("gone into the gun: left alone", m11.container == nil and ROOM[rig] == 5)
for i = #WORN, 1, -1 do WORN[i] = nil end

print(string.format("rmenu: %d pass, %d fail", pass, fail))
