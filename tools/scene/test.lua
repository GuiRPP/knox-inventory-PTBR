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
seconds(2)
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


say("scene: " .. pass .. " pass, " .. fail .. " fail")
