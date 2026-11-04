-- What KnoxRMenu.lua and KnoxMagKnown.lua need to load outside the game, over
-- load_pre.lua: the game's reload key and round menu, the queue, an element.
SCRIPTS["Base.AssaultRifle"] = {cls = "HandWeapon", ranged = true, ammo = "Base.556Bullets", mag = "Base.556Clip", max = 30, cat = "Weapon"}
SCRIPTS["Base.Revolver"] = {cls = "HandWeapon", ranged = true, ammo = "Base.Bullets38", max = 6, cat = "Weapon", chamber = false}
SCRIPTS["Base.556Clip"] = {ammo = "Base.556Bullets", max = 30, cat = "Ammo", scriptAmmo = true}
SCRIPTS["Base.556Bullets"] = {cat = "Ammo"}
SCRIPTS["Base.Bullets38"] = {cat = "Ammo"}

-- the item's further questions
local any = newItem("Base.Beans")
local Item = getmetatable(any)
INV:remove(any)
function Item:getDisplayName() return self.name or self.ft end
function Item:getTex() return "tex:" .. self.ft end
function Item:isRanged() return SCRIPTS[self.ft].ranged == true end
function Item:hasModData() return self.md ~= nil end
function Item:getModData() self.md = self.md or {} return self.md end
function Item:isRackAfterShoot() return self.rackAfter == true end
function Item:isSpentRoundChambered() return self.spent == true end
function Item:getTextureColorMask() return nil end
function Item:getR() return 1 end
function Item:getG() return 1 end
function Item:getB() return 1 end
function Item:getWorldItem() return nil end
function Item:IsDrainable() return false end
function Item:getFluidContainer() return nil end
function Item:getConditionMax() return 0 end
function Item:isFavorite() return false end
function Item:getGunTypeString() return "Pistol" end

local Container = getmetatable(INV)
function Container:getItemCountRecurse(t) return self:getAllTypeRecurse(t):size() end
function Container:getItems() return JList(self.items) end

-- the actions: the queue is real enough to be seen and emptied
QUEUE = {}
ISTimedActionQueue = {queues = {[PLAYER] = {queue = QUEUE}},
    add = function(a)
        table.insert(QUEUE, a)
        table.insert(DONE, {"queue", a.name, a})
    end,
    clear = function()
        for i = #QUEUE, 1, -1 do QUEUE[i] = nil end
        table.insert(DONE, {"clear"})
    end}
local function action(name, field)
    return {new = function(_, player, a, b)
        local o = {name = name, Type = name, a = a, b = b, stopOnWalk = false}
        if field then o[field] = a end
        return o
    end}
end
ISLoadBulletsInMagazine = action("ISLoadBulletsInMagazine", "magazine")
ISUnloadBulletsFromMagazine = action("ISUnloadBulletsFromMagazine", "magazine")
ISReloadWeaponAction = action("ISReloadWeaponAction", "gun")
ISUnloadBulletsFromFirearm = action("ISUnloadBulletsFromFirearm", "gun")
ISEjectMagazine = action("ISEjectMagazine", "gun")
ISEjectMagazine.unloadAmmo = function(self) self.made = instanceItem("Base.9mmClip") end
ISInsertMagazine = action("ISInsertMagazine", "gun")
ISLoadBulletsInMagazine.animEvent = function() end
ISUnloadBulletsFromMagazine.animEvent = function() end
ISUnloadBulletsFromMagazine.start = function() end
ISReloadWeaponAction.canRack = function(gun) return gun.canRack ~= false end
RACK_HOOK = function() end
-- the reload key's press while loading: the game stops it and racks (as the event calls it)
ISReloadWeaponAction.OnPressReloadButton = function(p, gun) table.insert(DONE, {"stopRack", gun}) end
Events.OnPressReloadButton = {Add = function(f) PRESS_RELOAD = f end, Remove = function() end}
LOADING = false
PLAYER.getVariableBoolean = function(_, name) return name == "isLoading" and LOADING end
ISReloadWeaponAction.BeginAutomaticReload = function(p, w) table.insert(DONE, {"autoreload", w}) end
ISInventoryPaneContextMenu.transferIfNeeded = function(_, it) table.insert(DONE, {"bring", it}) end
ISInventoryPaneContextMenu.transferBullets = function(player, key, cur, max)
    return math.min(player:getInventory():getItemCountRecurse(key), max - cur)
end

-- the game's menus on magazines and guns: what they would add (the real ones' words)
local CMenu = ISInventoryPaneContextMenu
CMenu.doMagazineMenu = function(_, mag, context) context:addOption("game:mag " .. mag:getCurrentAmmoCount()) end
CMenu.doReloadMenuForBullets = function(_, _, context) context:addOption("game:bullets") end
CMenu.doBulletMenu = function(_, gun, context) context:addOption("game:gun " .. gun:getCurrentAmmoCount()) end
CMenu.onLoadBulletsInMagazine = function(_, mag, count) table.insert(DONE, {"loadMenu", mag, count}) end
CMenu.onUnloadBulletsFromMagazine = function(_, mag) table.insert(DONE, {"unloadMenu", mag}) end
CMenu.onLoadBulletsIntoFirearm = function(_, gun) table.insert(DONE, {"loadGunMenu", gun}) end
CMenu.onUnloadBulletsFromFirearm = function(_, gun) table.insert(DONE, {"unloadGunMenu", gun}) end
CMenu.addToolTip = function() return {} end
function newContext()
    local c = {options = {}}
    function c:addOption(name, target, fn, a, b)
        local o = {name = name, target = target, fn = fn, a = a, b = b}
        table.insert(self.options, o)
        return o
    end
    return c
end

-- the game's round menu (a gamepad): slices of a name and a count
RADIAL = {slices = {}}
function RADIAL:setSliceText(i, text) self.slices[i].text = text end
function getPlayerRadialMenu() return RADIAL end

-- the game's three key handlers, written down
GAME_KEYS = {}
ISFirearmRadialMenu = {
    fillMenu = function()
        RADIAL.slices = {{text = "Eject\n7 / 15"}, {text = "Rack\n7+1 / 15"}, {text = "Plain"}}
    end,
    onKeyPressed = function(k) table.insert(GAME_KEYS, "pressed") end,
    onKeyRepeat = function(k) table.insert(GAME_KEYS, "repeat") end,
    onKeyReleased = function(k) table.insert(GAME_KEYS, "released") end,
}
KeybindId = {RELOAD_WEAPON = "reload"}
R = 19
local core = getCore()
core.isKey = function(_, id, key) return id == "reload" and key == R end
core.getOptionReloadRadialInstant = function() return INSTANT == true end
KEYS = {}
function isKeyDown(k) return KEYS[k] == true end
JoypadState = {players = {}}
function getCell() return {getDrag = function() return nil end} end
ISMouseDrag = {dragging = nil}
UIManager = {getSpeedControls = function() return {getCurrentGameSpeed = function() return GAME_SPEED or 1 end} end}
KnoxCompat = {windowOpen = function() return WINDOW == true end}
KnoxGrid.useDelta = function(a) return a.delta or 0 end

-- an element: what it was told
ISUIElement = ISPanel
function ISPanel:derive(name)
    local c = {Type = name}
    c.__index = c
    setmetatable(c, {__index = ISPanel})
    return c
end
function ISPanel:drawTexture() end
function ISPanel:drawTextureScaledAspect() end

-- the Java part
RMENU_FLAG = false
function knoxSetRMenuOpen(v) RMENU_FLAG = v end
HIDE_FLAG = nil
function knoxHideRounds(v) HIDE_FLAG = v end
function knoxTexInkX() return 0.1 end
function knoxTexInkY() return -0.1 end

-- the magazines back from the pockets: what is worn, the grids' places (ROOM: container -> places left)
PLAYER.cls = "IsoPlayer"
WORN = {}
ROOM = {}
function PLAYER:getWornItems() return JList(WORN) end
function PLAYER:isAiming() return AIMING == true end
function PLAYER:isRunning() return false end
function PLAYER:isSprinting() return false end
KnoxEquip = {norm = function(s) return s end, LOC = {webbing = {slot = "rig"}, back = {slot = "back"}, belt = {slot = "belt"}}}
KnoxActions = {activeBag = function() return CHOSEN end}
KnoxFootprint = KnoxFootprint or {overrides = {}}
function KnoxFootprint.get() return 1, 2 end
KnoxDrag = {
    allowedIn = function() return true end,
    settle = function(layout)
        if (ROOM[layout.container] or 0) <= 0 then return nil end
        ROOM[layout.container] = ROOM[layout.container] - 1
        return 0, 0, 0, false
    end,
    moveTo = function(_, e, _, layout) layout.container:add(e.item) end,
}
function KnoxGrid.build(c) return {container = c, occupy = function() end} end
function KnoxGrid.dims(e) return e.w, e.h end
