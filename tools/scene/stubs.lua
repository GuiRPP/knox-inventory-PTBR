-- The game under the menu's frame: KnoxMenuScene.lua, KnoxMenuPlace.lua and KnoxMenuSceneBar.lua are the
-- real ones (test.ps1). Written by QA for the overhaul, kept (2026-11-04).
require = function() end
NOW, STEP = 100000, 16
MX, MY = 5, 5
KEYS, BUTTONS = {}, {}
ANIM_ON, BAR_LOADS, BAR_FAILED, IN_MENU, POSED_ST = true, true, false, true, 2
BITE, BITE_PITCH, BITE_STARTS, BITE_STOPS = false, 0, 0, 0
HEROBOOM = false
NEAR = {}
CALLS = {begin = 0, finish = 0, solo = 0, rest = 0, stop = 0}
FILES = {}
SAVES = {}
ERRS = {}
function getTimestampMs() return NOW end
local realPrint = print
QUIET = true
print = function(s)
    s = tostring(s)
    if string.find(s, "frame error", 1, true) then table.insert(ERRS, s) end
    if not QUIET then realPrint(s) end
end
say = realPrint

Keyboard = setmetatable({}, {__index = function(t, k) return k end})
function isKeyDown(k) return KEYS[k] == true end
function isMouseButtonDown(b) return BUTTONS[b] == true end
function getMouseX() return MX end
function getMouseY() return MY end
function isDebugEnabled() return false end
function isClient() return false end
function ZombRand(a, b) if b then return a end return math.floor((a or 1) / 2) end
function ZombRandFloat(a, b) return (a + b) / 2 end
function getText(k) return k end
function getTextOrNull(k) return nil end
function getSpecificPlayer() return nil end
function getSaveInfo(rel) return SAVEINFO[rel] end
function getFullSaveDirectoryTable() return SAVES end
function getTexture(p) return {path = p} end
SOUND_SLIDER = 10
function getCore() return {getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end,
    getOptionSoundVolume = function() return SOUND_SLIDER end} end
-- (the game's own, as it answers: KnoxMenuSceneBar wraps it)
function getAllItemsForBodyLocation() return {"Base.Jacket_Black", "KnoxBite.JacketRolled", "Base.Vest"} end
function getSoundManager() return {playUISound = function() end} end
function instanceof() return false end
local function vec() return {set = function() end} end
local function reader(lines)
    local i = 0
    return {readLine = function() i = i + 1; return lines[i] end, close = function() end}
end
function getFileReader(name)
    local t = FILES[name]
    if not t then return nil end
    return reader(t)
end
function getFileWriter(name)
    local t = {}
    FILES[name] = t
    return {writeln = function(_, s) table.insert(t, s) end, write = function(_, s) table.insert(t, s) end, close = function() end}
end
local function noop() end
function getScriptManager()
    return {getItem = function(_, t) return {getWorldStaticModel = function() return "Bag" end, getStaticModel = function() return "Bag" end,
            getClothingItem = function() return nil end} end,
        getModelScript = function(_, n) return {getFullType = function() return "Base." .. n end, getName = function() return n end} end}
end

-- Events
Events = {}
local function event(name)
    local e = {list = {}}
    e.Add = function(f) table.insert(e.list, f) end
    e.Remove = function(f)
        for i = #e.list, 1, -1 do if e.list[i] == f then table.remove(e.list, i) end end
    end
    Events[name] = e
end
for _, n in ipairs({"OnPreUIDraw", "OnPostUIDraw", "OnMainMenuEnter", "OnGameStart", "OnResolutionChange", "OnTick", "OnTickEvenPaused",
    "EveryTenMinutes", "OnSave", "OnClothingUpdated", "OnPlayerDeath"}) do event(n) end
function fire(name, ...)
    local e, copy = Events[name], {}
    for i, f in ipairs(e.list) do copy[i] = f end
    for _, f in ipairs(copy) do f(...) end
end

-- UI
TOP = {}
ISUIElement = {}
ISUIElement.__index = ISUIElement
function ISUIElement:derive(name)
    local d = {}
    d.__index = d
    setmetatable(d, {__index = self})
    d.Type = name
    return d
end
function ISUIElement:new(x, y, w, h)
    local o = setmetatable({}, self)
    o.x, o.y, o.width, o.height, o.children, o.visible = x, y, w, h, {}, true
    return o
end
function ISUIElement:initialise() end
function ISUIElement:instantiate()
    local owner = self
    self.javaObject = setmetatable({owner = owner,
        isVisible = function() return owner.visible end, setVisible = function(_, v) owner.visible = v end},
        {__index = function() return noop end})
end
function ISUIElement:addChild(c) table.insert(self.children, c); c.parent = self end
function ISUIElement:removeChild(c)
    for i = #self.children, 1, -1 do if self.children[i] == c then table.remove(self.children, i) end end
end
function ISUIElement:addToUIManager() table.insert(TOP, 1, self); self.inUI = true end
function ISUIElement:removeFromUIManager()
    for i = #TOP, 1, -1 do if TOP[i] == self then table.remove(TOP, i) end end
    self.inUI = false
end
function ISUIElement:backMost() end
function ISUIElement:setAlwaysOnTop() end
function ISUIElement:setVisible(v) self.visible = v end
function ISUIElement:getIsVisible() return self.visible end
function ISUIElement:setX(v) self.x = v end
function ISUIElement:setY(v) self.y = v end
function ISUIElement:getY() return self.y end
function ISUIElement:setWidth(v) self.width = v end
function ISUIElement:setHeight(v) self.height = v end
function ISUIElement:getWidth() return self.width end
function ISUIElement:getHeight() return self.height end
function ISUIElement:getAbsoluteX() return self.x end
function ISUIElement:getAbsoluteY() return self.y end
function ISUIElement:drawRect() end
function ISUIElement:drawTextureScaled() end
function ISUIElement:drawText() end
function ISUIElement:drawRectBorder() end

UIManager = {isModalVisible = function() return false end,
    getUI = function()
        return {size = function() return #TOP end, get = function(_, i) return TOP[i + 1].javaObject end}
    end}

-- the camera, a pinhole
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function cross(a, b) return {a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]} end
local function norm(a) local l = math.sqrt(dot(a, a)); return {a[1] / l, a[2] / l, a[3] / l} end
CAMS = {}
function knoxMenuCamera(j, fov, ex, ey, ez, tx, ty, tz) CAMS[j] = {fov, ex, ey, ez, tx, ty, tz} end
function knoxMenuCameraOff(j) CAMS[j] = nil end
function project(j, x, y, z)
    local c = CAMS[j]
    if not c then return 0, 0 end
    local f = norm({c[5] - c[2], c[6] - c[3], c[7] - c[4]})
    local r = norm(cross(f, {0, 1, 0}))
    local u = cross(r, f)
    local p = {x - c[2], y - c[3], z - c[4]}
    local d = dot(p, f)
    local t = math.tan(math.rad(c[1]) / 2)
    local nx, ny = dot(p, r) / (d * t * 1920 / 1080), dot(p, u) / (d * t)
    return (nx + 1) / 2 * 1920, (1 - ny) / 2 * 1080
end
ISUI3DScene = ISUIElement:derive("ISUI3DScene")
function ISUI3DScene:new(x, y, w, h) return ISUIElement.new(self, x, y, w, h) end
function ISUI3DScene:instantiate()
    ISUIElement.instantiate(self)
    local j = self.javaObject
    rawset(j, "fromLua1", function(_, what, id)
        if what == "getObjectTranslation" or what == "getObjectRotation" or what == "getObjectScale" then return vec() end
    end)
    rawset(j, "fromLua2", noop)
    rawset(j, "sceneToUIX", function(_, x, y, z) local a = project(j, x, y, z); return a end)
    rawset(j, "sceneToUIY", function(_, x, y, z) local _, b = project(j, x, y, z); return b end)
end
ISUI3DModel = ISUIElement:derive("ISUI3DModel")
function ISUI3DModel:new(x, y, w, h) return ISUIElement.new(self, x, y, w, h) end
IsoDirections = {S = "S"}

-- the game's main screen
MainScreen = {}
function makeMain()
    local m = ISUIElement.new(ISUIElement, 0, 0, 1920, 1080)
    m:instantiate()
    m.inGame = false
    m.bottomPanel = ISUIElement.new(ISUIElement, 0, 0, 200, 400)
    m.soloScreen = ISUIElement.new(ISUIElement, 0, 0, 1920, 1080)
    m.soloScreen.visible = false
    m.soloScreen.panels = {{}}
    m.soloScreen.onItemClick = function() CALLS.solo = CALLS.solo + 1 end
    m.getLatestSave = noop
    MainScreen.instance = m
    TOP = {}
    m:addToUIManager()
end
LOADS = {}
MainScreen.continueLatestSave = function(mode, name)
    table.insert(LOADS, name)
    if LOAD_OK then IN_MENU = false end
end
ActiveMods = {getById = function() return {copyFrom = noop} end}

-- the theme
local function colorAny() return setmetatable({}, {__index = function() return {r = 1, g = 1, b = 1} end}) end
KnoxTheme = {color = colorAny(), pad = 6, cell = 40, active = true,
    on = function(n) return n == "menu" end, animOn = function() return ANIM_ON end, switch = function() return true end,
    ensure = noop, mod = function(a, b) return a - math.floor(a / b) * b end,
    inRect = function(x, y, r) return x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4] end,
    anim = function(t) if not ANIM_ON then return 1 end return t end,
    barLook = function(on) SKIN = on and "ice" or nil end, campLook = function() SKIN = "sand" end,
    measure = function() return 10 end, fontH = function() return 10 end, upper = function(s) return s end,
    text = noop, rect = noop, border = noop, tileFrame = noop, textCentre = noop, plate = noop, plateW = function() return 10 end}

-- Knox's Java: what is not listed below answers nil
for name in string.gmatch(KNOX_CALLS or "", "[%w_]+") do
    _G[name] = function() return nil end
end
function knoxMenuCamera(j, fov, ex, ey, ez, tx, ty, tz) CAMS[j] = {fov, ex, ey, ez, tx, ty, tz} end
function knoxMenuCameraOff(j) CAMS[j] = nil end
function knoxMenuInit() return true end
function knoxMenuInfo(rel) return SNAPS[rel] end
function knoxMenuDress(j, id, rel) return SNAPS[rel] ~= nil end
function knoxMenuDressUI(j, rel) return SNAPS[rel] ~= nil end
function knoxMenuAnim() return true end
function knoxMenuClothesReady() return true end
function knoxMenuPosed() return POSED_ST end
function knoxMenuReady() return true end
function knoxMenuInMenu() return IN_MENU end
function knoxMenuMouseFree() return MOUSE_FREE ~= false end
function knoxMenuClipSeconds() return 1 end
function knoxMenuClipStride() return 1 end
function knoxMenuTrackFraction() return -1 end
function knoxMenuCharInfo() return "" end
function knoxMenuWhy() return "" end
function knoxBarStart() CALLS.barStart = (CALLS.barStart or 0) + 1 end
function knoxBarLoad() return BAR_LOADS end
function knoxBarFailed() return BAR_FAILED end
function knoxBarClothesLoaded() return true end
function knoxBarDead() return true end
function knoxBarBegin() CALLS.begin = CALLS.begin + 1 end
function knoxBarEnd() CALLS.finish = CALLS.finish + 1 end
function knoxBarRest() CALLS.rest = CALLS.rest + 1 end
function knoxBarStop() CALLS.stop = CALLS.stop + 1 end
function knoxBarEmber() return 0 end
function knoxBarBottleBreaks() return 0 end
function knoxBarHero() if HEROBOOM then error("boom in knoxBarHero") end end
function knoxBiteStart() BITE = true; BITE_STARTS = BITE_STARTS + 1; return true end
function knoxBiteStop() BITE = false; BITE_STOPS = BITE_STOPS + 1 end
function knoxBiteHurry() CALLS.hurry = (CALLS.hurry or 0) + 1 end
function knoxBiteDress() return true end
function knoxBiteHold() return true end
function knoxBiteBusy() return BITE end
function knoxBiteFrame() return BITE_PITCH end
function knoxBiteYaw() return 0 end
function knoxBiteEyeUp() return 0 end
function knoxBiteEyeAhead() return 0 end
function knoxBiteEyeLeft() return 0 end
function knoxMenuSwipeFailed() return false end
function knoxMenuSwipeTake() end
function knoxMenuSwipeDraw() end
function knoxMenuSwipeFree() CALLS.swipeFree = (CALLS.swipeFree or 0) + 1 end
function knoxCampTick() return false end
function knoxMenuTintClear() NEAR = {}; CALLS.tintClear = (CALLS.tintClear or 0) + 1 end
function knoxMenuShadeNear(x, y, z) NEAR[x .. "," .. y .. "," .. z] = true end
function knoxMenuTintNear(x, y, z, r, a) local k = x .. "," .. y .. "," .. z; if a < 0 then NEAR[k] = nil else NEAR[k] = true end end
function knoxMenuTakeOff() end

-- a hero's bag
KnoxMenuBag = {read = function(rel) return {back = {type = "Base.Bag"}, sections = {}} end, sound = noop}

-- one frame of the UI
local function drawEl(el)
    if el.visible == false then return end
    if el.prerender then el:prerender() end
    for _, c in ipairs(el.children) do drawEl(c) end
    if el.render then el:render() end
end
function frame(n)
    for _ = 1, n or 1 do
        NOW = NOW + STEP
        fire("OnPreUIDraw")
        local copy = {}
        for i, e in ipairs(TOP) do copy[i] = e end
        for _, e in ipairs(copy) do drawEl(e) end
        fire("OnPostUIDraw")
    end
end
function seconds(s) frame(math.ceil(s * 1000 / STEP)) end

-- the saves
function setSaves(list)
    SAVES, SAVEINFO, SNAPS = {}, {}, {}
    for i, s in ipairs(list) do
        SAVES[i] = s.rel
        SAVEINFO[s.rel] = {saveName = s.rel, gameMode = "Sandbox", playerAlive = not s.dead, lastPlayed = "x", players = {}}
        if s.snap ~= false then SNAPS[s.rel] = {name = s.rel, dead = s.dead == true, hours = 48, kills = 1, health = 100, extra = "", female = false} end
    end
end
function startMenu(place, season)
    TOP = {}
    FILES = {}
    if AUTHOR then FILES["knox_author.txt"] = {"x"} end
    if place then FILES["knox_menu_place.txt"] = {"KP1", place .. "\t" .. (season or "winter")} end
    makeMain()
    NEAR, ERRS, LOADS = {}, {}, {}
    IN_MENU, POSED_ST, BAR_FAILED, BAR_LOADS, ANIM_ON = true, 2, false, true, true
    BITE, BITE_PITCH, HEROBOOM, LOAD_OK = false, 0, false, false
    KEYS, BUTTONS = {}, {}
    MX, MY = 5, 5
    KnoxMenuScene.instance = nil
    KnoxMenuScene.swipe = nil
    KnoxMenuScene.barFailed = nil
    KnoxMenuScene.uiHidden = false
    KnoxMenuScene.uiHidList = nil
    KnoxSettings, KnoxEditor, KnoxMenuNewsReader, KnoxMenuNewsCards, KnoxRadioCard, KnoxBagCard = nil, nil, nil, nil, nil, nil
    Events.OnPreUIDraw.list = {}
    fire("OnMainMenuEnter")
end
function tap(key, hold)
    KEYS[key] = true
    frame(hold or 2)
    KEYS[key] = nil
    frame(1)
end
function clickAt(x, y)
    MX, MY = x, y
    frame(2)
    BUTTONS[0] = true
    frame(2)
    BUTTONS[0] = nil
    frame(1)
end