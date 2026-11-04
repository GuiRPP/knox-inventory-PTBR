-- The menu's frame itself: what H, Tab, the swipe and the narrator's look do to one another. The game is
-- a stub (stubs.lua), the three scene files real. What it looks like in the game this cannot say.
KnoxMenuPlace.month = function() return 11 end
local pass, fail = 0, 0
local function ok(name, cond, info)
    if cond then pass = pass + 1
    else fail = fail + 1; say("FAIL " .. name .. (info ~= nil and (": " .. tostring(info)) or "")) end
end
local function rectMid(r) return r[1] + r[3] / 2, r[2] + r[4] / 2 end
local THREE = {{rel = "a"}, {rel = "b"}, {rel = "c"}}
local function scenes()
    local n = 0
    for _, e in ipairs(TOP) do if e.Type == "KnoxMenuScene" or e.Type == "KnoxMenuBar" then n = n + 1 end end
    return n
end
local s, n

-- the narrator's look ---------------------------------------------------------------------
local function bar(author)
    setSaves(THREE)
    AUTHOR = author
    startMenu("bar")
    seconds(4)
    return KnoxMenuScene.instance
end
local function hurries() return CALLS.hurry or 0 end

-- B: the author's PC alone (the author, 2026-11-04)
s = bar(false)
n = BITE_STARTS
tap("KEY_B")
ok("no file of the author's: B does nothing", BITE_STARTS == n and not s.eyes.busy)
s = bar(true)
tap("KEY_B")
ok("the author's file: B starts it", BITE_STARTS == n + 1 and s.eyes.busy == true)

-- the menu goes for it and comes back (the author, 2026-11-04)
seconds(1)
ok("the menu goes away for the look", s.uiOff == true and MainScreen.instance.visible == false)
ok("that isn't H", KnoxMenuScene.uiHidden == false)
tap("KEY_H")
ok("H does nothing while he looks", KnoxMenuScene.uiHidden == false)
BITE = false
seconds(1)
ok("over: the menu back", s.uiOff == false and s.uiAway == false and MainScreen.instance.visible == true)
ok("over: nothing dimmed", s.menuK == 1, s.menuK)

-- no hints, and a click only cuts it short
s = bar(true)
local h1 = s.heroAt[1]
MX, MY = rectMid(s:rectOf(h1))
seconds(1)
ok("at rest: the hero under the mouse", s.hover == h1, s.hover and s.hover.id)
tap("KEY_B")
frame(2)
ok("in the look: no hero pointed at", s.hover == nil, s.hover and s.hover.id)
seconds(1)
ok("in the look: no hero's card", not s.card.visible)
n = hurries()
LOADS = {}
BUTTONS[0] = true
frame(2)
BUTTONS[0] = nil
frame(2)
ok("a click cuts it short", hurries() == n + 1, hurries())
ok("that click does nothing else", s.mode == "idle" and #LOADS == 0, s.mode)
BUTTONS[1] = true
frame(2)
BUTTONS[1] = nil
frame(2)
ok("nor the right one", not s.ctxMenu)
BITE = false
seconds(1)
ok("over: the hero under the mouse again", s.hover == h1, s.hover and s.hover.id)

-- the same with the menu put away by H: it stays away, the hints go and come back
s = bar(true)
h1 = s.heroAt[1]
tap("KEY_H")
seconds(1)
ok("H: the menu away", s.uiOff == true)
MX, MY = rectMid(s:rectOf(h1))
seconds(1)
ok("H: a hero's hint still there", s.hover == h1, s.hover and s.hover.id)
tap("KEY_B")
frame(2)
ok("H, in the look: no hint", s.hover == nil, s.hover and s.hover.id)
BITE = false
seconds(1)
ok("H, over: the hint back", s.hover == h1, s.hover and s.hover.id)
ok("H, over: the menu still away", KnoxMenuScene.uiHidden == true and s.uiOff == true and MainScreen.instance.visible == false)

-- the radio
s = bar(true)
local radio = {}
KnoxRadioCard = {track = function(r, hover) radio.up, radio.hover = true, hover end, hide = function() radio.up = false end}
MX, MY = rectMid(s:radioRect())
frame(3)
ok("the radio's card at rest", s.radioHover == true and radio.up == true and radio.hover == true)
tap("KEY_B")
frame(2)
ok("in the look: no radio's card", s.radioHover == false and radio.up == false)
BITE = false
frame(3)
ok("over: the radio's card back", s.radioHover == true and radio.up == true)
KnoxRadioCard = nil

-- the garland's switch
s = bar(true)
local lit = {}
local lit0 = knoxBarSwitchLit
knoxBarSwitchLit = function(on) table.insert(lit, on) end
-- (the view turns after the mouse: aimed again till it rests on the switch)
for _ = 1, 120 do
    MX, MY = rectMid(s:switchRect())
    frame(1)
end
ok("the switch lit at rest", s.switchHover == true and lit[#lit] == true)
tap("KEY_B")
frame(2)
ok("in the look: the switch not lit", s.switchHover == false and lit[#lit] == false)
BITE = false
seconds(1)
ok("over: the switch lit again", s.switchHover == true and lit[#lit] == true)
knoxBarSwitchLit = lit0

-- a keepsake on the floor
s = bar(true)
h1 = s.heroAt[1]
local keep0 = KnoxMenuKeep
KnoxMenuKeep = {list = {{obj = true, type = "Base.Spoon", x = h1.x, z = h1.z}}, modelOf = function() return nil end}
MX, MY = s:toScreen(h1.x, 0.05, h1.z)
frame(3)
ok("a keepsake under the mouse at rest", s.keepHover ~= nil)
tap("KEY_B")
frame(2)
ok("in the look: no keepsake lit", s.keepHover == nil)
BITE = false
frame(3)
ok("over: the keepsake lit again", s.keepHover ~= nil)
KnoxMenuKeep = keep0

-- what comes in the middle of it
for name, open in pairs({
    ["Knox's settings"] = function() KnoxSettings = {instance = {}} end,
    ["the item editor"] = function() KnoxEditor = {instance = {}} end,
    ["a news post"] = function() KnoxMenuNewsReader = {instance = {}} end,
    ["a dialog"] = function() UIManager.isModalVisible = function() return true end end,
}) do
    s = bar(true)
    tap("KEY_B")
    n = hurries()
    open()
    frame(2)
    ok(name .. " in the middle: cut short", hurries() == n + 1, hurries())
    UIManager.isModalVisible = function() return false end
    BITE = false
    frame(2)
end
s = bar(true)
tap("KEY_B")
seconds(1)
n = hurries()
tap("KEY_TAB")
ok("Tab in the look: cut short", hurries() == n + 1, hurries())
BITE = false
seconds(4)
ok("Tab in the look: the camp up, the menu back", KnoxMenuScene.instance.Type == "KnoxMenuScene" and scenes() == 1
    and MainScreen.instance.visible == true and not KnoxMenuScene.instance.uiOff, MainScreen.instance.visible)

-- B with the radio's card up under the mouse: nothing (QA, 2026-11-04)
s = bar(true)
local card = {visible = false}
KnoxRadioCard = {instance = {getIsVisible = function() return card.visible end},
    track = function(_, over) if over or card.visible then card.visible = true end end,
    hide = function() card.visible = false end}
MX, MY = rectMid(s:radioRect())
frame(3)
MX, MY = 5, 5
MOUSE_FREE = false
frame(2)
n = BITE_STARTS
tap("KEY_B")
frame(3)
ok("B with the radio's card under the mouse: no look", BITE_STARTS == n, BITE_STARTS - n)
ok("B with the radio's card under the mouse: the card stays", card.visible == true)
MOUSE_FREE = nil
card.visible = false
KnoxRadioCard = nil
frame(2)
tap("KEY_B")
frame(3)
ok("the card gone: B starts it", BITE_STARTS == n + 1, BITE_STARTS - n)
BITE = false
seconds(1)

-- the frame failing every time in the look, before the look's own part: the menu back, H alive (QA, 2026-11-04)
s = bar(true)
tap("KEY_B")
seconds(1)
ok("in the look: the menu away", s.uiAway == true and s.uiOff == true)
local errs0 = #ERRS
KnoxMenuNewsCards = setmetatable({}, {__index = function() error("boom in the news cards") end})
seconds(0.5)
ok("failing every frame: the frame told it", #ERRS > errs0, #ERRS)
ok("failing every frame: the menu back", s.uiAway == false and MainScreen.instance.visible == true, MainScreen.instance.visible)
tap("KEY_H")
frame(2)
ok("failing every frame: H works", KnoxMenuScene.uiHidden == true)
KnoxMenuNewsCards = nil
BITE = false
seconds(1)

-- the swipe off: built anew at once
s = bar(true)
ANIM_ON = false
tap("KEY_B")
seconds(1)
ok("no animations: away", s.uiOff == true)
tap("KEY_TAB")
BITE = false
seconds(2)
ok("no animations, Tab in the look: the menu back", MainScreen.instance.visible == true and not KnoxMenuScene.instance.uiOff)

-- it doesn't start of itself over anything
local function autoStarts(setup, teardown)
    setSaves(THREE)
    AUTHOR = false
    startMenu("bar")
    STEP = 100
    seconds(5)
    MX, MY = 5, 5
    setup()
    BITE_STARTS = 0
    seconds(600)
    local c = BITE_STARTS
    BITE = false
    teardown()
    STEP = 16
    return c
end
local nothing = function() end
ok("left alone: he looks (600 s)", autoStarts(nothing, nothing) >= 1)
ok("Knox's settings open: he doesn't", autoStarts(function() KnoxSettings = {instance = {}} end, function() KnoxSettings = nil end) == 0)
ok("the item editor open: he doesn't", autoStarts(function() KnoxEditor = {instance = {}} end, function() KnoxEditor = nil end) == 0)
ok("a news post open: he doesn't", autoStarts(function() KnoxMenuNewsReader = {instance = {}} end, function() KnoxMenuNewsReader = nil end) == 0)
ok("the game's screens over the menu: he doesn't", autoStarts(function() MainScreen.instance.bottomPanel:setVisible(false) end, nothing) == 0)
ok("a dialog: he doesn't", autoStarts(function() UIManager.isModalVisible = function() return true end end,
    function() UIManager.isModalVisible = function() return false end end) == 0)
ok("the mouse on a hero: he doesn't", autoStarts(function()
    MX, MY = rectMid(KnoxMenuScene.instance:rectOf(KnoxMenuScene.instance.heroAt[1]))
end, nothing) == 0)
ok("the mouse on the radio: he doesn't", autoStarts(function()
    KnoxRadioCard = {track = nothing, hide = nothing}
    MX, MY = rectMid(KnoxMenuScene.instance:radioRect())
end, function() KnoxRadioCard = nil end) == 0)
-- (the radio's card stays up by itself while the mouse is on it, and the mouse isn't the scene's there: QA, 2026-11-04)
card = {visible = false}
ok("the radio's card up, the mouse on it: he doesn't", autoStarts(function()
    KnoxRadioCard = {instance = {getIsVisible = function() return card.visible end},
        track = function(_, over) if over or card.visible then card.visible = true end end,
        hide = function() card.visible = false end}
    MX, MY = rectMid(KnoxMenuScene.instance:radioRect())
    frame(3)
    MX, MY = 5, 5
    MOUSE_FREE = false
end, function() MOUSE_FREE = nil end) == 0)
ok("and the card stays", card.visible == true)
KnoxRadioCard = nil
ok("the mouse on the menu's buttons: he doesn't", autoStarts(function() MOUSE_FREE = false end, function() MOUSE_FREE = nil end) == 0)

-- the look hook goes off with the scene, and with no scene there too (a Lua reset, QA 2026-11-04)
s = bar(false)
local cleared, clear0 = 0, knoxMenuLookClear
knoxMenuLookClear = function() cleared = cleared + 1 end
KnoxMenuScene.instance = nil
KnoxMenuScene.destroy()
ok("no scene: the look hook cleared all the same", cleared == 1, cleared)
knoxMenuLookClear = clear0
AUTHOR = false

-- Tab, H and the look at random, quickly ---------------------------------------------------
local seed = 12345
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
for run = 1, 4 do
    setSaves(THREE)
    AUTHOR = true
    startMenu(run % 2 == 0 and "camp" or "bar")
    if run == 4 then ANIM_ON = false end
    seconds(3)
    for i = 1, 3000 do
        local k = rnd(40)
        if k == 0 then KEYS["KEY_TAB"] = not KEYS["KEY_TAB"] end
        if k == 1 then KEYS["KEY_H"] = not KEYS["KEY_H"] end
        if k == 2 then KEYS["KEY_B"] = not KEYS["KEY_B"] end
        if k == 3 then BITE = false end
        frame(1)
    end
    KEYS = {}
    BITE = false
    seconds(6)
    local inst = KnoxMenuScene.instance
    ok("run " .. run .. ": no error in a frame", #ERRS == 0, ERRS[1])
    ok("run " .. run .. ": swipe over", KnoxMenuScene.swipe == nil)
    ok("run " .. run .. ": one scene on the UI", scenes() == 1, scenes())
    ok("run " .. run .. ": nothing left queued", #Events.OnPreUIDraw.list == 0, #Events.OnPreUIDraw.list)
    ok("run " .. run .. ": the menu visible iff not hidden", MainScreen.instance.visible == (not KnoxMenuScene.uiHidden), tostring(MainScreen.instance.visible) .. " hidden=" .. tostring(KnoxMenuScene.uiHidden))
    ok("run " .. run .. ": the skin is the scene's", (inst.Type == "KnoxMenuBar" and SKIN == "ice") or (inst.Type == "KnoxMenuScene" and SKIN == "sand"), tostring(inst.Type) .. "/" .. tostring(SKIN))
end

AUTHOR = false

-- an error in the middle of the frame --------------------------------------------------------
setSaves(THREE)
startMenu("bar")
seconds(3)
s = KnoxMenuScene.instance
local b0, e0 = CALLS.begin, CALLS.finish
HEROBOOM = true
frame(3)
HEROBOOM = false
frame(3)
ok("told once", #ERRS == 1, #ERRS)
ok("the frame goes on after", CALLS.begin - b0 >= 3)


-- the bar can't be: back to the camp ---------------------------------------------------------
setSaves(THREE)
TOP = {}
FILES = {["knox_menu_place.txt"] = {"KP1", "bar\twinter"}}
makeMain()
NEAR, ERRS, LOADS = {}, {}, {}
KEYS, BUTTONS = {}, {}
BAR_LOADS, BAR_FAILED, IN_MENU, POSED_ST, ANIM_ON = false, false, true, 2, true
KnoxMenuScene.instance, KnoxMenuScene.swipe, KnoxMenuScene.barFailed = nil, nil, nil
Events.OnPreUIDraw.list = {}
fire("OnMainMenuEnter")
seconds(3)
s = KnoxMenuScene.instance
ok("no pack: the camp", s.Type == "KnoxMenuScene", s.Type)
ok("no pack: sand", SKIN == "sand", SKIN)
ok("no pack: flagged", KnoxMenuScene.barFailed == true)
tap("KEY_TAB")
seconds(2)
ok("no pack: Tab does nothing", KnoxMenuScene.instance == s and KnoxMenuScene.swipe == nil)
setSaves(THREE)
startMenu("bar")
seconds(3)
BAR_FAILED = true
seconds(1)
BAR_FAILED = false
s = KnoxMenuScene.instance
ok("the video card refuses: the camp", s.Type == "KnoxMenuScene", s.Type)
ok("the video card refuses: flagged", KnoxMenuScene.barFailed == true)
ok("the video card refuses: nothing queued", #Events.OnPreUIDraw.list == 0)
-- it refuses in the middle of a swipe to the bar
setSaves(THREE)
startMenu("camp")
seconds(3)
KEYS["KEY_TAB"] = true
frame(4)
KEYS["KEY_TAB"] = nil
BAR_FAILED = true
seconds(1)
BAR_FAILED = false
seconds(2)
s = KnoxMenuScene.instance
ok("refuses mid swipe: the camp", s.Type == "KnoxMenuScene", s.Type)
ok("refuses mid swipe: over", KnoxMenuScene.swipe == nil and scenes() == 1, scenes())


-- a resolution change and the game's start in a swipe ------------------------------------------
setSaves(THREE)
startMenu("bar")
seconds(3)
KEYS["KEY_TAB"] = true
frame(10)
KEYS["KEY_TAB"] = nil
ok("in a swipe", KnoxMenuScene.swipe ~= nil)
fire("OnResolutionChange")
seconds(1)
ok("resolution: swipe gone", KnoxMenuScene.swipe == nil)
ok("resolution: one scene", scenes() == 1, scenes())
ok("resolution: no error", #ERRS == 0, ERRS[1])
setSaves(THREE)
startMenu("bar")
seconds(3)
KEYS["KEY_TAB"] = true
frame(10)
KEYS["KEY_TAB"] = nil
fire("OnGameStart")
ok("game's start: no scene left", scenes() == 0, scenes())
ok("game's start: no skin of the menu", SKIN == nil, SKIN)


-- the walk is parked: no key starts it (the author, 2026-11-04) --------------------------------
setSaves(THREE)
startMenu("bar")
seconds(3)
s = KnoxMenuScene.instance
local walked = 0
for _, name in ipairs({"knoxBarWalkStart", "knoxBarWalkStep", "knoxBarWalkLeave", "knoxBarWalkView", "knoxBarWalkDark", "knoxBarWalkTunes", "knoxBarWalkTune"}) do
    _G[name] = function() walked = walked + 1 end
end
for _, k in ipairs({"KEY_W", "KEY_A", "KEY_S", "KEY_D", "KEY_LBRACKET", "KEY_RBRACKET", "KEY_MINUS", "KEY_EQUALS", "KEY_ESCAPE"}) do tap(k) end
seconds(1)
ok("no key starts it", not s.walking)
ok("none of its Java is called", walked == 0, walked)
ok("the menu is not hidden by it", KnoxMenuScene.uiHidden == false)
ok("the view stays", s.viewFov == nil)


-- the overhaul's stage 2 ----------------------------------------------------------------------------
-- the camp gone by a swipe: the bar's things keep their light (the tints are all cleared at once)
local function tintsLost(sc)
    local n = 0
    for _, o in ipairs(sc.objects) do
        if o.tinted and o.world and not o.height and not o.tint and not NEAR[-o.px .. "," .. o.py .. "," .. o.pz] then n = n + 1 end
    end
    return n
end
setSaves(THREE)
startMenu("camp")
seconds(4)
local camp = KnoxMenuScene.instance
KEYS["KEY_TAB"] = true
frame(4)
KEYS["KEY_TAB"] = nil
for _ = 1, 40 do
    frame(1)
    if KnoxMenuScene.instance ~= camp then break end
end
s = KnoxMenuScene.instance
ok("Tab: the bar is up under the swipe", s ~= camp and s.Type == "KnoxMenuBar", s.Type)
s.revealDone = true     -- (its light spread already: nobody lights them again of himself)
seconds(3)
ok("Tab over: the camp gone", camp.retired == true and KnoxMenuScene.swipe == nil)
ok("Tab over: nothing of the bar left in full light", tintsLost(s) == 0, tintsLost(s))

-- H, then the diary: the new game's screen is seen
setSaves(THREE)
startMenu("camp")
seconds(4)
s = KnoxMenuScene.instance
tap("KEY_H")
seconds(1)
ok("H: the menu away", s.uiOff == true and MainScreen.instance.visible == false)
s:newGame()
ok("the diary: a new game's screen open", CALLS.solo >= 1 and MainScreen.instance.soloScreen.visible == true)
ok("the diary: the menu back with it", KnoxMenuScene.uiHidden == false and s.uiOff == false and MainScreen.instance.visible == true)
seconds(1)
ok("the diary: not dimmed", s.menuK == 1, s.menuK)

-- a load that fails: the one asleep back in his rest as it is now
local function comeBackWith(stir, side, empty)
    setSaves(THREE)
    startMenu("bar")
    seconds(4)
    local sc = KnoxMenuScene.instance
    local c = sc.heroAt[1]
    c.sleepSide, c.sleepEmpty, c.stir = side, empty, stir
    sc:leave(c)
    sc:comeBack()
    return c, sc
end
local c = comeBackWith({kind = "swat", at = 0, knocked = true})
ok("a failed load, swatted: the hand empty", c.anim == "knoxbar_stool_e" and c.sleepEmpty == true, c.anim)
ok("a failed load, swatted: the stir over", c.stir == nil)
c = comeBackWith({kind = "swat", at = 0})
ok("a failed load, about to swat: round the bottle still", c.anim == "knoxbar_stool" and not c.sleepEmpty, c.anim)
c = comeBackWith({kind = "shift", at = 0})
ok("a failed load, shifting: on his other side", c.anim == "knoxbar_stool_b" and c.sleepSide == "b", c.anim)
c = comeBackWith(nil, "b", true)
ok("a failed load, at rest: as he was", c.anim == "knoxbar_stool_eb", c.anim)
c = comeBackWith(nil)
ok("a failed load, untouched: as he was", c.anim == "knoxbar_stool", c.anim)

-- H, Tab, and no scene comes: the menu shown again
setSaves(THREE)
startMenu("camp")
seconds(4)
tap("KEY_H")
seconds(1)
ok("H before it: away", MainScreen.instance.visible == false)
local init0 = knoxMenuInit
knoxMenuInit = function() return false end
tap("KEY_TAB")
seconds(2)
knoxMenuInit = init0
ok("no scene came: the menu shown", MainScreen.instance.visible == true, MainScreen.instance.visible)
ok("no scene came: not hidden any more", KnoxMenuScene.uiHidden == false and KnoxMenuScene.uiHidList == nil)
ok("no scene came: the swipe over", KnoxMenuScene.swipe == nil and KnoxMenuScene.instance == nil)

-- the bar swiped out takes the narrator's look with it
s = bar(true)
tap("KEY_B")
seconds(1)
ok("in the look", s.eyes.busy == true)
n = BITE_STOPS
tap("KEY_TAB")
seconds(4)
ok("Tab, the look not over yet: it stops with the bar", BITE_STOPS > n and BITE == false, BITE_STOPS - n)
AUTHOR = false

-- a key held through a rebuild is no press
setSaves(THREE)
startMenu("camp")
seconds(4)
KEYS["KEY_H"] = true
frame(2)
ok("H held: away", KnoxMenuScene.uiHidden == true)
KEYS["KEY_H"] = nil
frame(2)
tap("KEY_H")
ok("H again: back", KnoxMenuScene.uiHidden == false)
KEYS["KEY_H"] = true
KnoxMenuScene.uiHidden = false
KnoxMenuScene.create()
seconds(1)
ok("H held through a rebuild: nothing", KnoxMenuScene.uiHidden == false)
KEYS["KEY_H"] = nil
frame(2)
tap("KEY_H")
ok("H let go and pressed: works", KnoxMenuScene.uiHidden == true)
s = bar(true)
n = BITE_STARTS
KEYS["KEY_B"] = true
KnoxMenuScene.create()
seconds(4)
ok("B held through a rebuild: no look", BITE_STARTS == n, BITE_STARTS - n)
KEYS["KEY_B"] = nil
frame(2)
tap("KEY_B")
ok("B let go and pressed: the look", BITE_STARTS == n + 1, BITE_STARTS - n)
BITE = false
AUTHOR = false

-- the bar's frame failing time after time: the camp; failing now and then: the bar stays
setSaves(THREE)
startMenu("bar")
seconds(3)
s = KnoxMenuScene.instance
HEROBOOM = true
frame(10)
HEROBOOM = false
seconds(2)
ok("a few frames fail: the bar stays", KnoxMenuScene.instance == s and not KnoxMenuScene.barFailed)
KnoxMenuNewsCards = setmetatable({}, {__index = function() error("boom in the news cards") end})
seconds(3)
KnoxMenuNewsCards = nil
seconds(1)
ok("every frame fails: the camp", KnoxMenuScene.instance.Type == "KnoxMenuScene", KnoxMenuScene.instance.Type)
ok("every frame fails: flagged", KnoxMenuScene.barFailed == true)
ok("every frame fails: one scene", scenes() == 1, scenes())
s = KnoxMenuScene.instance
KnoxMenuNewsCards = setmetatable({}, {__index = function() error("boom in the news cards") end})
seconds(3)
KnoxMenuNewsCards = nil
seconds(1)
ok("in the camp: nowhere to go, it stays", KnoxMenuScene.instance == s)

-- the bar's build failing at its very start, the swipe under way: the camp goes on, nothing thrown (QA)
KnoxMenuScene.barFailed = nil
setSaves(THREE)
startMenu("camp")
seconds(4)
local aim0, thrown = KnoxMenuBar.aimCamera, 0
KnoxMenuBar.aimCamera = function() error("boom before its objects") end
KEYS["KEY_TAB"] = true
for _ = 1, 8 do if not pcall(frame, 1) then thrown = thrown + 1 end end
KEYS["KEY_TAB"] = nil
for _ = 1, 200 do if not pcall(frame, 1) then thrown = thrown + 1 end end
KnoxMenuBar.aimCamera = aim0
ok("the build failing at its start: nothing thrown", thrown == 0, thrown)
ok("the build failing at its start: a camp up", KnoxMenuScene.instance and KnoxMenuScene.instance.Type == "KnoxMenuScene", KnoxMenuScene.instance and KnoxMenuScene.instance.Type)
ok("the build failing at its start: flagged", KnoxMenuScene.barFailed == true)
ok("the build failing at its start: one scene", scenes() == 1, scenes())
ok("the build failing at its start: the swipe over", KnoxMenuScene.swipe == nil)
KnoxMenuScene.barFailed = nil

-- nothing is taken out of a bag in the bar; the camp as it was
ok("the bar: no keepsakes", KnoxMenuBar.noKeeps == true)
ok("the camp: keepsakes", KnoxMenuScene.noKeeps == nil)

-- the bar's sounds by the game's sound slider
setSaves(THREE)
startMenu("bar")
seconds(3)
s = KnoxMenuScene.instance
local moan0, moanNear = knoxCampMoan, nil
knoxCampMoan = function(_, near) moanNear = near end
ok("the slider at its top: as they were", s:sfxK() == 1, s:sfxK())
SOUND_SLIDER = 5
ok("the slider half way: half", s:sfxK() == 0.5, s:sfxK())
s.moanAt = s.clock
frame(2)
ok("a moan by the slider", moanNear == 0.5, moanNear)
SOUND_SLIDER = 0
ok("the slider down: none", s:sfxK() == 0, s:sfxK())
SOUND_SLIDER = 10
knoxCampMoan = moan0
ok("the camp's: no slider of its own", KnoxMenuScene.sfxK == nil)

-- the narrator's clothes out of the character creation's list of all clothes
local all = getAllItemsForBodyLocation("base:jacket")
ok("all clothes: none of the narrator's", #all == 2 and all[1] == "Base.Jacket_Black" and all[2] == "Base.Vest", #all)

-- H with the animations off: at once
setSaves(THREE)
startMenu("camp")
seconds(4)
s = KnoxMenuScene.instance
ANIM_ON = false
KEYS["KEY_H"] = true
frame(3)
KEYS["KEY_H"] = nil
frame(1)
ok("no animations, H: gone at once", s.menuK == 0 and s.uiOff == true, s.menuK)
tap("KEY_H")
frame(2)
ok("no animations, H again: back at once", s.menuK == 1 and s.uiOff == false, s.menuK)
ANIM_ON = true

say("scene: " .. pass .. " pass, " .. fail .. " fail")
