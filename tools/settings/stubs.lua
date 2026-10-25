-- What KnoxSettings.lua touches, outside the game (tools/settings/test.ps1): the
-- real KnoxTheme / KnoxControls / KnoxOrder / KnoxWindowDrag over made-up fonts
-- (a letter is 7 px, a capital's line 16), ISPanel as far as a window goes, a
-- screen whose height the test sets, the mouse the test moves.
require = function() end

clock = 1000
function getTimestampMs() return clock end
-- (a text the length of a real one: its key twice, so wraps and widths are tried)
function getText(key, ...) return key .. " " .. key end
SCREEN = {w = 1920, h = 1080}
local core = {getScreenWidth = function() return SCREEN.w end, getScreenHeight = function() return SCREEN.h end,
              getOptionFontSizeReal = function() return 1 end, DelayResetLua = function() end,
              getOptionLanguageName = function() return "EN" end}
function getCore() return core end
function getPlayer() return PLAYER end
PLAYER = {isDead = function() return false end, getPlayerNum = function() return 0 end}
function getSpecificPlayer() return PLAYER end
function getFileReader() return nil end
function getFileWriter() return {write = function() end, close = function() end} end
function getSoundManager() return {playUISound = function() end} end
function getTexture() return nil end
function isClient() return false end
function isServer() return false end
MOUSE = {down = {}}
function isMouseButtonDown(b) return MOUSE.down[b] == true end
function isKeyDown() return false end
Keyboard = {KEY_ESCAPE = 1, KEY_DELETE = 211, KEY_BACK = 14, KEY_LSHIFT = 42, KEY_RSHIFT = 54,
            KEY_LCONTROL = 29, KEY_RCONTROL = 157, KEY_LMENU = 56, KEY_RMENU = 184, KEY_TAB = 15}
setmetatable(Keyboard, {__index = function() return 0 end})
Translator = {getLanguage = function() return {name = function() return "EN" end} end}

local events = {}
Events = setmetatable({}, {__index = function(t, k)
    local e = {Add = function() end, Remove = function() end}
    rawset(t, k, e)
    return e
end})

-- the Java part's fonts
function knoxFontHeight(style, size) return 16 end
function knoxTextWidth(style, size, s) return #s * 7 end
function knoxTextInk(style, size, s) return "0,3," .. (#s * 7) .. ",14" end
function knoxFontReady() return true end
function knoxFontCovers() return true end
function getTextOrNull(key) return key end
function getKeyName(k) return "K" .. k end
function knoxDrawText() DRAWN = DRAWN + 1 end
function knoxJavaVersion() return 61 end
local tm = {getFontHeight = function() return 16 end, MeasureStringX = function(_, f, s) return #s * 7 end}
function getTextManager() return tm end
UIFont = setmetatable({}, {__index = function(_, k) return k end})
DRAWN = 0

-- ISPanel: a window as far as KnoxSettings goes
ISPanel = {}
ISPanel.__index = ISPanel
function ISPanel:derive(name)
    local c = {Type = name}
    c.__index = c
    setmetatable(c, {__index = ISPanel})
    return c
end
function ISPanel:new(x, y, w, h)
    local o = {x = x, y = y, w = w, h = h, javaObject = {}, mx = 0, my = 0, stencils = 0}
    setmetatable(o, self)
    self.__index = self
    return o
end
function ISPanel:initialise() end
function ISPanel:instantiate() if self.createChildren then self:createChildren() end end
function ISPanel:getWidth() return self.w end
function ISPanel:getHeight() return self.h end
function ISPanel:setWidth(w) self.w = w end
function ISPanel:setHeight(h) self.h = h end
function ISPanel:setX(x) self.x = x end
function ISPanel:setY(y) self.y = y end
function ISPanel:getX() return self.x end
function ISPanel:getY() return self.y end
function ISPanel:getAbsoluteX() return self.x end
function ISPanel:getAbsoluteY() return self.y end
function ISPanel:getXScroll() return 0 end
function ISPanel:getYScroll() return 0 end
function ISPanel:getMouseX() return self.mx end
function ISPanel:getMouseY() return self.my end
function ISPanel:isMouseOver() return false end
function ISPanel:drawRect() DRAWN = DRAWN + 1 end
function ISPanel:drawRectBorder() DRAWN = DRAWN + 1 end
function ISPanel:drawTextureScaled() end
function ISPanel:drawText() DRAWN = DRAWN + 1 end
function ISPanel:setStencilRect() self.stencils = self.stencils + 1 end
function ISPanel:clearStencilRect() self.stencils = self.stencils - 1 end
function ISPanel:addToUIManager() end
function ISPanel:removeFromUIManager() end
function ISPanel:setAlwaysOnTop() end
function ISPanel:setVisible(v) self.visible = v end
function ISPanel:getIsVisible() return self.visible ~= false end
function ISPanel:setWantKeyEvents() end
function ISPanel:addChild() end
function ISPanel:bringToTop() end
ISButton = ISPanel
MainScreen = {}
KnoxGrid = {}
