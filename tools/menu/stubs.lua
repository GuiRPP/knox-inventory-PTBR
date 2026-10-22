-- What KnoxContextMenu.lua touches while it loads and lays a menu out, outside the
-- game (tools/menu/test.ps1): the game's ISContextMenu as far as options and sub
-- menus go (its option pool, addOption, getNew - copied from the game's file), the
-- theme's sizes, the item tooltip's header.
require = function() end
if not table.wipe then
    function table.wipe(t)
        local keys = {}
        for k in pairs(t) do table.insert(keys, k) end
        for _, k in ipairs(keys) do t[k] = nil end
    end
end

clock = 1000
function getTimestampMs() return clock end
function getText(key) return key end
function getTextOrNull() return nil end
function instanceof(obj, class) return type(obj) == "table" and obj.classes ~= nil and obj.classes[class] == true end
function getTexture(path) return {path = path} end
WHITE = {path = "white"}
Texture = {getWhite = function() return WHITE end}
JoypadState = {players = {}}
UIFont = {Small = "Small", Medium = "Medium", Large = "Large"}
local core = {
    getOptionContextMenuFont = function() return "Medium" end,
    getScreenWidth = function() return 3440 end,
    getScreenHeight = function() return 1440 end,
    getGameMode = function() return "Survival" end,
}
function getCore() return core end
function getSpecificPlayer() return nil end
function getSoundManager() return {playUISound = function() end} end
UIManager = {getMillisSinceLastRender = function() return 16 end}

-- the game's functions the menu knows options by
ISInventoryPaneContextMenu = {
    OnNewCraft = function() end, onEatItems = function() end, onDropItems = function() end,
    onGrabItems = function() end, onWearItems = function() end, onPutItems = function() end,
}
ISHotbar = {removeItem = function() end, attachItem = function() end}
ISInventoryPage = {}
ISFluidContainerMenu = {}

KnoxTheme = {cell = 48, pad = 8, javaFonts = true, color = {},
             fontTile = {key = "tile"}, fontHeader = {key = "header"}, fontText = {key = "text"}}
local T = KnoxTheme
function T.on() return true end
function T.ensure() end
function T.animOn() return true end
function T.makeFont(style, size) return {key = style .. size, size = size} end
function T.fontH(f) return 16 end
function T.measure(f, s) return string.len(s or "") * 7 end
function T.upper(s) return string.upper(s) end
function T.fit(s) return s end

-- the tooltip's header (KnoxTooltip.header): counted, it is the dearest part
KnoxTooltip = {GAP = 8, MORPH_MS = 180, headers = 0}
function KnoxTooltip.baseWidth() return 300 end
function KnoxTooltip.widthFor() return 320 end
function KnoxTooltip.startFold() return nil end
function KnoxTooltip.ease(t) return t end
function KnoxTooltip.header(item, name, bw)
    KnoxTooltip.headers = KnoxTooltip.headers + 1
    return {h = 44, lines = {name}, item = item}
end

-- ISContextMenu: the game's option list and sub menus, no drawing
ISContextMenu = {}
ISContextMenu.__index = ISContextMenu

function ISContextMenu:new()
    local o = setmetatable({}, self)
    o.player = 0
    o.options, o.optionPool, o.numOptions = {}, {}, 1
    o.subMenuPool, o.instanceMap, o.subOptionNums = {}, {}, 0
    o.x, o.y, o.width, o.height = 0, 0, 100, 0
    o.scrollHeight, o.yScroll, o.scrollAreaHeight = 0, 0, 0
    o.padY, o.mouseOver = 6, -1
    return o
end

local roots = {}
function getPlayerContextMenu(n)
    n = n or 0
    if not roots[n] then
        roots[n] = ISContextMenu:new()
        roots[n].player = n
    end
    return roots[n]
end

function ISContextMenu:allocOption(name, target, onSelect, param1, param2)
    if #self.optionPool == 0 then table.insert(self.optionPool, {}) end
    local option = table.remove(self.optionPool, #self.optionPool)
    table.wipe(option)
    option.id = self.numOptions
    option.name = name
    option.onSelect = onSelect
    option.target = target
    option.param1 = param1
    option.param2 = param2
    option.subOption = nil
    return option
end

function ISContextMenu:addOption(name, target, onSelect, param1, param2)
    local option = self:allocOption(name, target, onSelect, param1, param2)
    option.iconTexture = nil
    option.color = nil
    self.options[self.numOptions] = option
    self.numOptions = self.numOptions + 1
    self:calcHeight()
    self:setWidth(self:calcWidth())
    return option
end

function ISContextMenu:addSubMenu(option, menu) option.subOption = menu.subOptionNums end

function ISContextMenu:getNew(parentContext)
    local context = getPlayerContextMenu(parentContext.player)
    local sub = table.remove(context.subMenuPool) or ISContextMenu:new()
    sub:clear()
    sub.parent = parentContext
    sub.player = parentContext.player
    context.subOptionNums = context.subOptionNums + 1
    sub.subOptionNums = context.subOptionNums
    context.instanceMap[context.subOptionNums] = sub
    return sub
end

function ISContextMenu:getSubMenu(num) return getPlayerContextMenu(self.player):getSubInstance(num) end
function ISContextMenu:getSubInstance(num) return self.instanceMap[num] end

function ISContextMenu:clear()
    for _, option in ipairs(self.options) do table.insert(self.optionPool, option) end
    table.wipe(self.options)
    self.numOptions = 1
    self.mouseOver = -1
    self.subMenu = nil
    self:setHeight(0)
end

function ISContextMenu:isEmpty() return self.numOptions == 1 end
function ISContextMenu:setFont(font) self.font = font or UIFont.Medium end
function ISContextMenu:calcHeight() end
function ISContextMenu:calcWidth() return 100 end
function ISContextMenu:prerender() end
function ISContextMenu:render() end
function ISContextMenu:getItemY(i) return 0 end
function ISContextMenu:onMouseUp() end
function ISContextMenu:setX(x) self.x = x end
function ISContextMenu:setY(y) self.y = y end
function ISContextMenu:getX() return self.x end
function ISContextMenu:getY() return self.y end
function ISContextMenu:setWidth(w) self.width = w end
function ISContextMenu:setHeight(h) self.height = h end
function ISContextMenu:getWidth() return self.width end
function ISContextMenu:getHeight() return self.height end
function ISContextMenu:setScrollHeight(h) self.scrollHeight = h end
function ISContextMenu:getScrollHeight() return self.scrollHeight end
function ISContextMenu:getScrollAreaHeight() return self.scrollAreaHeight or 0 end
function ISContextMenu:getYScroll() return self.yScroll end
function ISContextMenu:setYScroll(y) self.yScroll = y end
function ISContextMenu:isVisible() return true end
function ISContextMenu:getIsVisible() return true end
function ISContextMenu:isAnyVisible() return true end
