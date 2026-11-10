-- What KnoxNewsLive needs outside the game, over tools/settings/stubs.lua, KnoxTheme and
-- tools/lists/load_pre + rmenu_pre (loaded before KnoxSlotPicker, KnoxLoad, KnoxMagKnown,
-- KnoxRMenu, KnoxSelect and KnoxGridView, which are the real ones): the frame's event kept,
-- an element that remembers, the game's context menu and actions as far as they are asked.
PREDRAW = {}
Events.OnPreUIDraw = {Add = function(f) table.insert(PREDRAW, f) end, Remove = function() end}
function frame(ms)
    clock = clock + (ms or 16)
    for _, f in ipairs(PREDRAW) do f() end
end

-- the element (derived from what it is called on, as the game's)
function ISPanel:derive(name)
    local c = {Type = name}
    c.__index = c
    setmetatable(c, {__index = self})
    return c
end
-- (the Java part's drawing: done, nothing to look at)
local drawn = setmetatable({}, {__index = function() return function() end end})
local panelNew = ISPanel.new
function ISPanel:new(...)
    local o = panelNew(self, ...)
    o.javaObject = drawn
    return o
end
ELEMENTS = {}
function ISPanel:addToUIManager() ELEMENTS[self] = true self.inUI = true end
function ISPanel:removeFromUIManager() ELEMENTS[self] = nil self.inUI = false end
function ISPanel:setAlwaysOnTop(v) self.alwaysOnTop = v end
function ISPanel:bringToTop() TOPPED = TOPPED + 1 self.topAt = TOPPED end
function ISPanel:setVisible(v) self.vis = v end
function ISPanel:getIsVisible() return self.vis ~= false end
function ISPanel:isVisible() return self.vis ~= false end
function ISPanel:addChild(c) self.kids = self.kids or {} self.kids[c] = true c.parent = self end
function ISPanel:removeChild(c) if self.kids then self.kids[c] = nil end end
function ISPanel:getXScroll() return 0 end
function ISPanel:getYScroll() return 0 end
function ISPanel:isMouseOver() return true end
function ISPanel:setStencilRect() STENCILS = STENCILS + 1 end
function ISPanel:clearStencilRect() STENCILS = STENCILS - 1 end
TOPPED, STENCILS = 0, 0

-- the items: what the actions do to them
local any = newItem("Base.Beans")
local Item = getmetatable(any)
function Item:setCurrentAmmoCount(n) self.n = n end
function Item:setContainsClip(v) self.clip = v end
function Item:setRoundChambered(v) self.chambered = v end
function Item:setJammed(v) self.jam = v end
function Item:getAmmoPerShoot() return 1 end
function Item:isFavorite() return self.fav == true end
function Item:setFavorite(v) self.fav = v end
function Item:isHidden() return false end
-- (the tile's other questions - heat, cooking, what is read...: nothing to say)
local FIELDS = {container = true, inner = true, n = true, clip = true, jam = true, md = true, fav = true, chambered = true,
                name = true, broken = true, parts = true, rackAfter = true, spent = true, canRack = true, holder = true}
setmetatable(Item, {__index = function(_, k)
    if FIELDS[k] then return nil end
    return function() return nil end
end})

local Container = getmetatable(INV)
function Container:AddItem(it) self:add(it) return it end
function Container:Remove(it) self:remove(it) it.container = nil end
function Container:RemoveOneOf(key)
    for _, it in ipairs(self.items) do
        if it.ft == key then
            self:Remove(it)
            return true
        end
    end
    return false
end
function Container:getType() return "none" end
ItemContainer = {new = function() return newContainer("news") end}

-- the game's actions, with the fields the real ones have
local function action(name, make)
    return {new = function(_, player, a, b)
        local o = {Type = name, name = name, character = player}
        make(o, a, b)
        return o
    end}
end
ISLoadBulletsInMagazine = action("ISLoadBulletsInMagazine", function(o, mag, n) o.magazine, o.ammoCount = mag, n end)
ISUnloadBulletsFromMagazine = action("ISUnloadBulletsFromMagazine", function(o, mag) o.magazine = mag end)
ISEjectMagazine = action("ISEjectMagazine", function(o, gun) o.gun = gun end)
ISInsertMagazine = action("ISInsertMagazine", function(o, gun, mag) o.gun, o.magazine = gun, mag end)
ISRackFirearm = action("ISRackFirearm", function(o, gun) o.gun = gun end)
GAME_QUEUE = {}
ISTimedActionQueue = {queues = {},
    add = function(a) table.insert(GAME_QUEUE, a) end,
    clear = function(c) table.insert(GAME_QUEUE, {cleared = c}) end}
local CMenu = ISInventoryPaneContextMenu
CMenu.equipWeapon = function(w) table.insert(GAME_QUEUE, {equipped = w}) end
CMenu.onFavorite = function(items, _, fav) for _, it in ipairs(items) do it:setFavorite(fav) end end
CMenu.onEjectMagazine = function(p, gun) CMenu.equipWeapon(gun, true, false, 0) ISTimedActionQueue.add(ISEjectMagazine:new(p, gun)) end
CMenu.onRackGun = function(p, gun) CMenu.equipWeapon(gun, true, false, 0) ISTimedActionQueue.add(ISRackFirearm:new(p, gun)) end

-- the game's context menu
ISContextMenu = ISPanel:derive("ISContextMenu")
function ISContextMenu:new(x, y, w, h)
    local o = ISPanel.new(self, x, y, w, h)
    o.options = {}
    return o
end
function ISContextMenu:isAnyVisible() return self.vis == true end
function ISContextMenu:hideAndChildren() self.vis = false end
function ISContextMenu:addOption(name, target, fn, a, b)
    local o = {name = name, target = target, fn = fn, a = a, b = b}
    table.insert(self.options, o)
    return o
end
function ISContextMenu:getNew()
    local top = getPlayerContextMenu(0)
    local sub = ISContextMenu:new(0, 0, 1, 1)
    sub:addToUIManager()
    top.instanceMap = top.instanceMap or {}
    table.insert(top.instanceMap, sub)
    return sub
end
function ISContextMenu:addSubMenu(option, menu) option.sub = menu end
ISContextMenu.get = function(player, x, y)
    local c = getPlayerContextMenu(player)
    c.vis, c.options, c.x, c.y = true, {}, x, y
    return c
end
GAME_MENU = "the game's own"
function getPlayerContextMenu() return GAME_MENU end

-- the grid's other questions: the things go in a line of tiles as KnoxGrid.build would, each its own
KnoxGrid.frame = 0
KnoxGrid.useNow = {}
KnoxGrid.pending = {}
KnoxGrid.liveGrids = {}
KnoxGrid.fixedSize = {}
function KnoxGrid.useOf() return nil end
function KnoxGrid.updateUse(player) USE_ASKED = player end
function KnoxGrid.dims(e, r) return e.w, e.h end
function KnoxGrid.isStackable() return false end
function KnoxGrid.build(c, player)
    local fs = KnoxGrid.fixedSize[c]
    local L = {container = c, cols = fs and fs.cols or 8, rows = fs and fs.rows or 2, placed = {}, itemCount = #c.items}
    for i, it in ipairs(c.items) do
        if it ~= player:getPrimaryHandItem() then
            table.insert(L.placed, {item = it, items = {it}, x = i, y = 0, w = 1, h = 1, r = 0})
        end
    end
    function L:cellAt(x, y)
        for _, e in ipairs(self.placed) do if e.x == x and e.y == y then return e end end
        return nil
    end
    return L
end
KnoxOrder = {silhouettes = function() return {"the player's own layout"} end}
KnoxDrag.extras = {}
function KnoxDrag.isActive() return KnoxDrag.entity ~= nil end
function KnoxDrag.cancel() KnoxDrag.entity = nil end
function KnoxDrag.explain() EXPLAINED = true end
function KnoxDrag.update() end
KnoxActions = {lootViews = function() return {} end, windowViews = function() return {} end, activeBag = function() return nil end,
    isLocked = function() return false end,
    allViews = function() return KnoxActions.newsView and {KnoxActions.newsView} or {} end}
KnoxControls = {mods = function() return "" end, isHeld = function(id) return id == "quickItems" and HELD end,
    actionFor = function(_, gesture) return gesture == "rmb" and "menu" or nil end, isRotateButton = function() return false end}
KnoxTooltip = {apply = function() APPLIED = (APPLIED or 0) + 1 end, want = function() end, reset = function() RESET = true end}
KnoxContextMenu = {setTarget = function(items) TARGET = items end}
KnoxGridView_noSearch = true

-- keys, the reload key's name
KeybindId = {RELOAD_WEAPON = "reload"}
getCore().getKey = function() return R end
Keyboard.getKeyName = function() return "R" end
function T_keyHint() end
HaloTextHelper = {}
function isShiftKeyDown() return SHIFT == true end
function KnoxContextMenu.isTarget() return false end
function KnoxContextMenu.drawTarget() end
