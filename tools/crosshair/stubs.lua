-- What KnoxCrosshair.lua touches, outside the game (tools/crosshair/test.ps1): the
-- Java part's knoxVpPanel* globals over a made-up thing looked at (VP), the theme's
-- layout kit as far as sizes go, KnoxGrid / KnoxSearch / Knox's grab, a ui that
-- counts what is drawn.
require = function() end

clock = 1000
function getTimestampMs() return clock end
function getText(key) return key end
function instanceof(obj, class) return type(obj) == "table" and obj.classes ~= nil and obj.classes[class] == true end
function getTexture(path) return {path = path} end
local core = {getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end}
function getCore() return core end

PLAYER = {isDead = function() return false end, getPlayerNum = function() return 0 end}
function getSpecificPlayer() return PLAYER end

-- a Java list
function jlist(t)
    t = t or {}
    return {t = t, size = function(self) return #self.t end, get = function(self, i) return self.t[i + 1] end,
            add = function(self, v) table.insert(self.t, v) end}
end
ArrayList = {new = function() return jlist({}) end}

-- things: an item, a bag (with things of its own)
local nextId = 1
function item(name, w)
    nextId = nextId + 1
    local it = {name = name, w = w or 0.5, id = nextId, classes = {}}
    it.getName = function(self) return self.name end
    it.isHidden = function() return false end
    it.getID = function(self) return self.id end
    return it
end
function container(items, type)
    local c = {items = jlist(items or {}), type = type or "crate"}
    c.getItems = function(self) return self.items end
    c.getType = function(self) return self.type end
    return c
end
function bag(name, items)
    local b = item(name, 1)
    b.classes.InventoryContainer = true
    b.inv = container(items, "bag")
    b.getInventory = function(self) return self.inv end
    return b
end

-- what Viewpoint looks at, as the Java part gives it
VP = {owned = false, shown = false, kind = 3, locked = false, loot = true, containers = jlist({}),
      actions = {}, wheel = 0, pressed = 0, held = false, left = false, obj = nil, sq = nil}
function knoxVpPanelOwn(on) VP.owned = on return on end
function knoxVpPanelShown() return VP.shown end
function knoxVpPanelKind() return VP.kind end
function knoxVpPanelLocked() return VP.locked end
function knoxVpPanelLoot() return VP.loot end
function knoxVpPanelSquare() return VP.sq end
function knoxVpPanelObject() return VP.obj end
function knoxVpPanelContainers() return VP.containers end
function knoxVpPanelTitle(c) return c and ("Title " .. c.type) or "Ground" end
function knoxVpPanelActions() return #VP.actions end
function knoxVpPanelActionLabel(i) return VP.actions[i + 1].label end
function knoxVpPanelActionOn(i) return VP.actions[i + 1].on end
function knoxVpPanelActionProgress(i) return VP.actions[i + 1].p or 0 end
function knoxVpPanelActionsTitle() return "Door" end
VP.ran = {}
function knoxVpPanelRun(i) table.insert(VP.ran, i) end
function knoxVpPanelWheel() local w = VP.wheel VP.wheel = 0 return w end
function knoxVpPanelPressed() local p = VP.pressed VP.pressed = 0 return p end
function knoxVpPanelHeld() return VP.held end
function knoxVpPanelLeft() return VP.left end

-- the theme: sizes and the kit's calls (text 7 px a letter)
KnoxTheme = {cell = 48, javaFonts = true, active = true, fontHeader = {key = "h"}, fontText = {key = "t"}, fontTile = {key = "s"}}
local T = KnoxTheme
local function rgb(v) return {r = v, g = v, b = v} end
T.color = {accent = rgb(0.8), dim = rgb(0.5), text = rgb(0.8), bright = rgb(0.9), border = rgb(0.2), header = rgb(0.1),
           window = rgb(0.07), cell = rgb(0.05), tileFrame = rgb(0.35), tileEdge = rgb(0.24)}
T.category = {misc = rgb(0.3), food = rgb(0.3)}
function T.categoryOf() return "misc" end
function T.on() return true end
SWITCHES = {["vp.panel"] = true}
function T.switch(k) return SWITCHES[k] end
function T.animOn() return true end
function T.anim(t) return math.max(0, math.min(1, t)) end
function T.makeFont(style, size) return {key = style .. size} end
function T.measure(f, s) return string.len(s or "") * 7 end
function T.upper(s) return string.upper(s) end
function T.fit(s) return s end
function T.mix(a, b, k) return {r = a.r + (b.r - a.r) * k, g = a.g + (b.g - a.g) * k, b = a.b + (b.b - a.b) * k} end
DRAWN = {rect = 0, label = 0, stencil = 0, unstencil = 0}
function T.rect() DRAWN.rect = DRAWN.rect + 1 end
function T.border() DRAWN.rect = DRAWN.rect + 1 end
function T.tileFrame() DRAWN.rect = DRAWN.rect + 1 end
function T.label(ui, s, band, c, o)
    assert(type(s) == "string", "a label of " .. type(s))
    DRAWN.label = DRAWN.label + 1
    return T.measure(nil, s)
end
function T.inkOrigin(s, x, y) return x, y end
-- (as the real one: clipped to its line, the clip taken off)
function T.marquee(ui) ui:setStencilRect() DRAWN.label = DRAWN.label + 1 ui:clearStencilRect() end
function T.fontH() return 16 end
function T.rollNumber(ui, st, s) assert(type(s) == "string") DRAWN.label = DRAWN.label + 1 end
function T.keyHint(ui, x, y, key, label)
    assert(type(key) == "string" and type(label) == "string", "a hint without its key or label")
    DRAWN.label = DRAWN.label + 2
    return x + T.measure(nil, key) + 16 + T.measure(nil, label)
end

UI = {}
function UI:drawRect() DRAWN.rect = DRAWN.rect + 1 end
function UI:drawTextureScaledAspect() DRAWN.rect = DRAWN.rect + 1 end
-- (the game's clips nest: a level each, a clear takes one off; a box taken off inside
-- another is painted back - repaintStencilRect - and never with no clip on)
STENCIL = {level = 0, left = 0, bad = 0}
function UI:setStencilRect() DRAWN.stencil = DRAWN.stencil + 1 STENCIL.level = STENCIL.level + 1 end
function UI:clearStencilRect() DRAWN.unstencil = DRAWN.unstencil + 1 if STENCIL.level > 0 then STENCIL.level = STENCIL.level - 1 end end
function UI:repaintStencilRect() if STENCIL.level <= 0 then STENCIL.bad = STENCIL.bad + 1 end end

ISInventoryItem = {renderItemIcon = function() DRAWN.rect = DRAWN.rect + 1 end}
ContainerButtonIcons = {floor = {path = "floor"}}
-- (an element as the game's: sizes, children, the mouse; it draws as UI does - the news' demo)
ISUIElement = setmetatable({}, {__index = UI})
ISUIElement.__index = ISUIElement
function ISUIElement:derive(name) local o = setmetatable({Type = name}, self) self.__index = self return o end
function ISUIElement:new(x, y, w, h) local o = setmetatable({x = x, y = y, width = w, height = h, visible = true}, self) self.__index = self return o end
function ISUIElement:initialise() end
function ISUIElement:instantiate() end
function ISUIElement:setX(v) self.x = v end
function ISUIElement:setY(v) self.y = v end
function ISUIElement:getX() return self.x end
function ISUIElement:getY() return self.y end
function ISUIElement:setWidth(v) self.width = v end
function ISUIElement:setHeight(v) self.height = v end
function ISUIElement:setVisible(v) self.visible = v end
function ISUIElement:addChild(c) end
MOUSE = {x = -1, y = -1, down = false}
function ISUIElement:getMouseX() return MOUSE.x end
function ISUIElement:getMouseY() return MOUSE.y end
function isMouseButtonDown(b) return b == 0 and MOUSE.down end
SOUNDS = 0
function getSoundManager() return {playUISound = function() SOUNDS = SOUNDS + 1 end} end
Events = {OnGameStart = {Add = function() end}}
KnoxCompat = {vpHas = function() return true end, windowOpen = function() return false end}
KnoxContextMenu = {worldLook = function(label)
    if string.find(label, "Smash") then return {path = "smash"}, "danger" end
    return {path = "icon"}, "door"
end}

-- the grids: the weight; things on their way (PENDING[item] = 0..1)
PENDING = {}
KnoxGrid = {pending = {}}
function KnoxGrid.weightOf(it) return it.w end
function KnoxGrid.pendingOf(it) local p = PENDING[it] if p then return {}, p end return nil end
function KnoxGrid.build() return {} end
KnoxSearch = {queue = {}, done = 0, spent = 0, container = nil}
function KnoxSearch.on() return false end
function KnoxSearch.busy() return false end
function KnoxSearch.needs() return false end
function KnoxSearch.unseen() return false end
function KnoxSearch.tick() end
function KnoxSearch.drawCurrent() end
ISTimedActionQueue = {getTimedActionQueue = function() return {queue = {}} end}

GRABBED = {}
Knox = {viewpointGrab = function(player, items)
    for _, it in ipairs(items) do table.insert(GRABBED, it) end
end}
