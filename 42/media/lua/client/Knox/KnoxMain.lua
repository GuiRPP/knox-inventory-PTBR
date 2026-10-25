-- Entry point: the inventory key and game events.
-- The game's own inventory windows stay alive (much of the game reads their
-- state) but are never shown: the inventory key opens the Knox screen instead.

require "Knox/KnoxTheme"
require "Knox/KnoxControls"
require "Knox/KnoxDrag"
require "Knox/KnoxScreen"
require "Knox/KnoxLootPanel"
require "ISUI/ISModalDialog"
require "Fluids/ISFluidTransferUI"
require "Knox/KnoxFluidWindow"
require "Fluids/ISFluidInfoUI"
require "Knox/KnoxFluidInfo"
require "RadioCom/ISRadioWindow"
require "Knox/KnoxTVWindow"
require "Knox/KnoxRadioWindow"
require "Knox/KnoxHandModels"
require "Knox/KnoxStoveWindow"
require "Knox/KnoxCompat"

Knox = Knox or {}
Knox.VERSION = "1.0-beta"   -- (the 1.0 beta, shipped as a mod of its own next to 0.9.8.7: 2026-10-20)

--- Does a part of Knox stand in for the game's window for this player? `module`:
--- which part (KnoxTheme.MODULES; the inventory screen when not given). It is
--- made for the mouse: the first player, not on a controller (a controller
--- player and split-screen players keep the game's windows), and not in the
--- tutorial (its steps watch the game's windows).
function Knox.forPlayer(playerNum, module)
    playerNum = playerNum or 0
    module = module or "inventory"
    -- (Knox.failed: the inventory screen could not be built - its windows only;
    -- Knox.vanillaShot: the filming mode shows the game's own windows for a while, KnoxStudio)
    return KnoxTheme.on(module) and not (module == "inventory" and Knox.failed) and not Knox.vanillaShot
        and playerNum == 0 and getSpecificPlayer(0) ~= nil
        and not (JoypadState and JoypadState.players and JoypadState.players[1])
        and getCore():getGameMode() ~= "Tutorial"
end

local function hideVanilla(playerNum)
    if not Knox.forPlayer(playerNum) then return end
    local inv, loot = getPlayerInventory(playerNum), getPlayerLoot(playerNum)
    if inv and inv:getIsVisible() then inv:setVisible(false) end
    if loot and loot:getIsVisible() then loot:setVisible(false) end
end

--- Is a Knox text field being typed in (the screen's search, the developer panel's)?
local function typing()
    local s = KnoxScreen and KnoxScreen.instance
    if s and s.searchFocused and s:searchFocused() then return true end
    local dev = KnoxDevPanel and KnoxDevPanel.instance
    local box = dev and dev.search
    return box ~= nil and box.isFocused ~= nil and box:isFocused()
end

-- The inventory key closes the screen and nothing may open it again on the same press. The game's
-- own handler of the key is taken off the event when a game starts, but a mod that wraps it puts it
-- back: it then shows the game's loot window right after the screen has closed, and showing that
-- window opens the screen (hookLootShow) - the screen "would not close on Tab".
local KEY_GUARD = 350

--- The screen could not be built (an error in Knox, or in something it shows - an
--- item of another mod): rather than no inventory at all ("Tab does nothing"), the
--- game's own windows until the game is restarted, and the reason in console.txt.
local function screenFailed(err)
    print("[Knox] ERROR: the inventory screen failed to open; the game's inventory is used until restart: " .. tostring(err))
    Knox.failed = tostring(err)
    local s = KnoxScreen.instance or KnoxScreen.building
    KnoxScreen.instance, KnoxScreen.building = nil, nil
    if s then
        -- (the dashboard and the game's hotbar it hid come back)
        if s.restoreHidden then s:restoreHidden() end
        if s.dragLayer then pcall(function() s.dragLayer:removeFromUIManager() end) end
        pcall(function() s:removeFromUIManager() end)
    end
    if knoxSetScreenOpen then pcall(knoxSetScreenOpen, false) end
    if knoxViewpointCursor then pcall(knoxViewpointCursor, false, false) end
    local inv, loot = getPlayerInventory(0), getPlayerLoot(0)
    if inv then inv:setVisible(true) end
    if loot then loot:setVisible(true) end
end

--- Open the Knox screen (on a container, or as it was), guarded: see screenFailed.
function Knox.open(playerNum, container)
    local ok, err = pcall(function()
        if container then KnoxScreen.openWith(playerNum, container) else KnoxScreen.toggle(playerNum) end
    end)
    if not ok then screenFailed(err) end
    return ok
end

-- Why the inventory key did not open the screen, once per reason in console.txt: players
-- write "Tab does nothing" (four of them by 2026-10-17) and it can't be told apart from here.
local keyWhy = nil
local function keyNote(why)
    if why == keyWhy then return end
    keyWhy = why
    print("[Knox] inventory key: " .. why)
end

--- Is something else using Knox's own key right now? Tab is also the game's key
--- for the chat's channel (while typing in it) and for the mode of a furniture or
--- placing cursor.
local function keyBusy()
    if ISChat and ISChat.focused then return true end
    local cell = getCell()
    return cell ~= nil and cell:getDrag(0) ~= nil
end

local function onKeyPressed(key)
    local game = getCore():isKey(KeybindId.TOGGLE_INVENTORY, key)
    -- Knox's own key (KnoxControls "toggle", Tab unless the player set another)
    local own = KnoxControls ~= nil and KnoxControls.isKey("toggle", key) and not game
    if not (game or own) or not getSpecificPlayer(0) then return end
    if not KnoxTheme.on("inventory") then   -- inactive: the game's own key handler stays
        if game then keyNote(KnoxTheme.active and "the inventory module is off (Knox settings)" or "Knox inactive (Java part), the game's inventory") end
        return
    end
    if typing() then return end
    if own and keyBusy() and not KnoxScreen.instance then return end
    if KnoxScreen.instance then
        -- (opened a moment ago by this very key press: the game's own handler of the key, where
        -- another mod has put it back, shows its loot window first, and that opens the screen)
        if getTimestampMs() - (KnoxScreen.openedAt or 0) < KEY_GUARD then return end
        KnoxScreen.instance:close()
    elseif getTimestampMs() - (KnoxScreen.closedAt or 0) < KEY_GUARD then
        return   -- closed by this very press (the screen's own key handler was first)
    elseif not Knox.forPlayer(0) then
        -- on a controller, in the tutorial: the game's windows, as without the mod
        keyNote(Knox.failed and ("the screen failed earlier: " .. Knox.failed)
            or (JoypadState and JoypadState.players and JoypadState.players[1]) and "a controller is player 1's: the game's windows"
            or "the game's windows (tutorial)")
        if ISInventoryPage.onKeyPressed then ISInventoryPage.onKeyPressed(key) end
    elseif getGameSpeed() > 0 then
        if Knox.open(0) then keyWhy = nil end
    else
        keyNote("the game is paused (the game's own inventory doesn't open then either)")
    end
end


local function onContainerUpdate()
    KnoxLootPanel.dirty = true
    local s = KnoxScreen.instance
    if s then s:markAllDirty() end
end
-- (a game with others: the server's sizes or the character's own data have come)
if KnoxNet then KnoxNet.onChanged = onContainerUpdate end

local function onPlayerDeath(player)
    local s = KnoxScreen.instance
    if s and player == s:player() then s:close() end
end

local function onResolutionChange()
    KnoxTheme.refresh()
    if KnoxScreen.instance then
        KnoxScreen.instance:close()
        Knox.open(0)
    end
end

-- Something in the game may show its windows again (a container opened from
-- the world, a mod): keep them hidden.
-- A controller taking player 1 over with the screen open (Viewpoint gives the
-- player to a pad as soon as it is touched): the screen is for the mouse - it
-- closes, and the pad gets the game's windows, as it does on the inventory key.
local tick = 0
local function onTick()
    tick = tick + 1
    if tick % 15 ~= 0 or not getSpecificPlayer(0) then return end
    if KnoxScreen.instance and JoypadState and JoypadState.players and JoypadState.players[1] then
        print("[Knox] a controller took player 1 over: the screen closes, the game's windows for the pad")
        KnoxScreen.instance:close()
    end
    hideVanilla(0)
end

-- Clicking a container in the world: the game selects it in its loot window
-- and shows that window. We hide it again at once and open the Knox screen on
-- that container instead.
local function hookWorldClick()
    if not ISObjectClickHandler or ISObjectClickHandler.knoxHooked then return end
    ISObjectClickHandler.knoxHooked = true
    local original = ISObjectClickHandler.doClick
    ISObjectClickHandler.doClick = function(object, x, y)
        original(object, x, y)
        local loot = getPlayerLoot(0)
        if loot and loot:getIsVisible() and Knox.forPlayer(0) then
            loot:setVisible(false)
            Knox.open(0, loot.inventory)
        end
    end
end

-- Any game code that shows the loot window (opening a car's trunk selects
-- the trunk and shows it; mods may do the same) opens the Knox screen on that
-- container instead. Without this the game's window flashed until the next
-- hide in onTick, and the Knox screen stayed closed.
local function hookLootShow()
    if ISInventoryPage.knoxShowHooked then return end
    ISInventoryPage.knoxShowHooked = true
    local original = ISInventoryPage.setVisible or ISUIElement.setVisible
    local opening = false
    ISInventoryPage.setVisible = function(self, visible)
        if visible and not self.onCharacter and not opening and Knox.forPlayer(self.player or 0) then
            if not KnoxScreen.instance and getTimestampMs() - (KnoxScreen.closedAt or 0) < KEY_GUARD then
                -- the screen has just been closed with the inventory key: it stays closed
                return original(self, false)
            end
            -- the container the game wants shown: a forced one (trunk), else its current one
            local container = self.forceSelectedContainer or self.inventory
            original(self, false)
            opening = true
            local ok = Knox.open(self.player or 0, container)
            opening = false
            -- (failed: the game's windows from now on - this one too)
            if not ok then return original(self, true) end
            return
        end
        return original(self, visible)
    end
end

-- "Place item" (on the ground, in 3D): the game hands the mouse to a placing
-- cursor in the world, so the screen gets out of the way.
local function hookPlaceItem()
    local P = ISInventoryPaneContextMenu
    if not P or not P.onPlaceItemOnGround or P.knoxPlaceHooked then return end
    P.knoxPlaceHooked = true
    local original = P.onPlaceItemOnGround
    P.onPlaceItemOnGround = function(items, playerObj)
        if KnoxScreen.instance then KnoxScreen.instance:close() end
        return original(items, playerObj)
    end
end

-- Pouring fluids: the game opens its window through ISFluidTransferUI.OpenPanel
-- (item menus, barrels, sinks, crafting slots); the Knox window takes its place.
local function hookFluidTransfer()
    if not ISFluidTransferUI or ISFluidTransferUI.knoxHooked then return end
    ISFluidTransferUI.knoxHooked = true
    local original = ISFluidTransferUI.OpenPanel
    ISFluidTransferUI.OpenPanel = function(player, container, source)
        if player and container and Knox.forPlayer(player:getPlayerNum(), "fluids")
            and ISFluidUtil.validateContainer(container) and container:isValid() then
            return KnoxFluidWindow.open(player, container, source)
        end
        return original(player, container, source)
    end
end

-- A container's info ("Container info" in its menu): the Knox window takes the
-- place of the game's ISFluidInfoUI too (2026-10-18).
local function hookFluidInfo()
    if not ISFluidInfoUI or ISFluidInfoUI.knoxHooked then return end
    ISFluidInfoUI.knoxHooked = true
    local original = ISFluidInfoUI.OpenPanel
    ISFluidInfoUI.OpenPanel = function(player, container)
        if player and container and Knox.forPlayer(player:getPlayerNum(), "fluids")
            and ISFluidUtil.validateContainer(container) and container:isValid() then
            return KnoxFluidInfo.open(player, container)
        end
        return original(player, container)
    end
end

-- A television's or a radio's window: the game opens it through
-- ISRadioWindow.activate (clicking the set, its context menu, equipping a
-- radio or a walkie-talkie, the car's dashboard); the Knox set takes its place.
-- The dashboard's radio button asks isActive /
-- closeIfActive to toggle it: those answer for the Knox window too.
local function hookRadioWindow()
    if not ISRadioWindow or ISRadioWindow.knoxHooked then return end
    ISRadioWindow.knoxHooked = true
    local function knoxFor(player, device)
        if not (player and device and device.getDeviceData and device:getDeviceData()) then return nil end
        if not Knox.forPlayer(player:getPlayerNum(), "devices") then return nil end
        if instanceof(device, "IsoTelevision") then return KnoxTVWindow end
        if KnoxRadioWindow.handles(device) then return KnoxRadioWindow end
        return nil
    end
    local activate, isActive, closeIfActive = ISRadioWindow.activate, ISRadioWindow.isActive, ISRadioWindow.closeIfActive
    ISRadioWindow.activate = function(player, device, ...)
        local K = knoxFor(player, device)
        if K then return K.open(player, device) end
        return activate(player, device, ...)
    end
    ISRadioWindow.isActive = function(player, device, ...)
        local K = knoxFor(player, device)
        if K then return K.instance ~= nil and K.instance.device == device end
        return isActive(player, device, ...)
    end
    ISRadioWindow.closeIfActive = function(player, device, ...)
        local K = knoxFor(player, device)
        if K then
            if K.instance and K.instance.device == device then K.instance:close() end
            return
        end
        return closeIfActive(player, device, ...)
    end
    -- skills a broadcast teaches: on the TV's screen and the radio's tape
    KnoxTVWindow.hookHalo()
end

-- The game's furniture button tooltip writes the name of its "Toggle mode" key
-- when it is made (ISMoveablesIconToolTip:new) and while moving furniture. A key
-- with no name - unbound when Tab was given to the inventory, or a mouse button
-- - throws there, and the game stops building the player's interface: no
-- hotbar, no car dashboard for the rest of the game (Aygrol1's log, 2026-10-20).
-- Then the tooltip is made without the key's name.
require "Moveables/ISMoveablesIconToolTip"
if ISMoveablesIconToolTip and not ISMoveablesIconToolTip.knoxGuarded then
    ISMoveablesIconToolTip.knoxGuarded = true
    local tipNew, tipRender = ISMoveablesIconToolTip.new, ISMoveablesIconToolTip.render
    local said = false
    local function say(err)
        if said then return end
        said = true
        local key = nil
        pcall(function() key = getCore():getKey(KeybindId.TOGGLE_MODE) end)
        print("[Knox] the game's \"Toggle mode\" key (" .. tostring(key) .. ") has no name; its furniture tooltip goes without it: " .. tostring(err))
    end
    function ISMoveablesIconToolTip:new(x, y, width, height, marginOffset)
        local ok, o = pcall(tipNew, self, x, y, width, height, marginOffset)
        if ok then return o end
        say(o)
        o = ISPanel:new(x, y, width, math.max(height, getTextManager():getFontHeight(UIFont.Small) * 2))
        setmetatable(o, self)
        self.__index = self
        o.marginOffset = marginOffset or 0
        o.background = true
        o.subText = ""
        o.backgroundColor = {r = 0, g = 0, b = 0, a = 0.35}
        o.borderColor = {r = 0.80, g = 0.80, b = 0.80, a = 0}
        o.anchorLeft, o.anchorRight, o.anchorTop, o.anchorBottom = true, false, true, false
        o.fontheight = getTextManager():getFontHeight(UIFont.Small)
        return o
    end
    function ISMoveablesIconToolTip:render()
        local ok, err = pcall(tipRender, self)
        if not ok then
            say(err)
            ISPanel.render(self)
        end
    end
end

-- Knox's mouse cursor (media/ui/knox_cursor.png, set by the Java part): put on
-- as soon as the mod's Lua runs (the main menu) and again in game.
local function applyCursor()
    if KnoxTheme.active and not knoxApplyCursor() then print("[Knox] cursor not applied") end
end
applyCursor()
Events.OnMainMenuEnter.Add(applyCursor)

-- The cursor "presses" while the left button is held: the Java part swaps it
-- for a slightly smaller one (knoxCursorPress). Looked at before every UI
-- frame, in the menu and in a game; told to Java only when the button changes.
-- Off with the inventory's animations.
local cursorDown = false
Events.OnPreUIDraw.Add(function()
    if not KnoxTheme.active or not knoxCursorPress then return end
    local down = isMouseButtonDown(0) == true and KnoxTheme.animOn()
    if down ~= cursorDown then
        cursorDown = down
        knoxCursorPress(down)
    end
end)

-- Viewpoint (first person): it keeps the mouse for looking around until its
-- cursor mode is on (the middle button). While anything of Knox is open the
-- cursor is there, at once and all the time - the middle button is Knox's
-- inspect gesture and must not send the mouse back to the view; closed, the
-- view gets the mouse back (the Java part: knoxViewpointCursor, knoxViewpointKeep).
-- Which windows: KnoxCompat.windowOpen.
local knoxWindowOpen = KnoxCompat.windowOpen

-- Viewpoint's loot panel (what a container looked at holds) shows only what the
-- character has found: the Java part asks this for each thing while the
-- container search is on (KnoxViewpoint.seenOnly; pascal's report, 2026-10-15).
function KnoxViewpointUnseen(item)
    return KnoxSearch ~= nil and KnoxTheme.on("inventory") and KnoxSearch.unseen(item) == true
end

local viewpointWant = false
local searchSaid = nil
Knox.viewpointLookAfter = false   -- the screen came from Viewpoint's loot key: closed, back to looking
-- (only with Viewpoint: without it nothing of this runs a frame - it was asked every frame anyway)
if KnoxCompat.vpHas("cursor") or KnoxCompat.vpHas("rows") then
    Events.OnPreUIDraw.Add(function()
        if not getSpecificPlayer(0) then return end
        -- (told to Java when it changes, not every frame)
        if knoxViewpointSearch then
            local on = KnoxTheme.on("inventory") and KnoxSearch ~= nil and KnoxSearch.on() == true
            if on ~= searchSaid then
                searchSaid = on
                knoxViewpointSearch(on)
            end
        end
        if not knoxViewpointCursor then return end
        local want = knoxWindowOpen()
        if want ~= viewpointWant then
            viewpointWant = want
            knoxViewpointCursor(want, Knox.viewpointLookAfter)
            if not want then Knox.viewpointLookAfter = false end
        end
        if want and knoxViewpointKeep then knoxViewpointKeep() end
    end)
end

-- Viewpoint's loot key opens the game's loot window on the container looked at
-- (and shows it before choosing the container): the Knox screen opens on that
-- container instead, and the same key closes it again.
--- A thing lying on the ground into the floor container, as the game's loot
--- window has it (a transfer takes it from there).
local function knoxFromGround(item, n)
    if item:getWorldItem() == nil then return end
    local floor = ISInventoryPage.GetFloorContainer(n)
    if floor and not floor:contains(item) then floor:AddItem(item) end
end

local function hookViewpoint()
    if not ViewpointLoot or ViewpointLoot.knoxHooked then return end
    ViewpointLoot.knoxHooked = true
    -- (each pair only when Viewpoint still has both: a version without them keeps
    -- its own, and the log says which - KnoxCompat.report)
    if KnoxCompat.luaHas("ViewpointLoot", ViewpointLoot, {"openWindow", "closeWindow"}) then
        local open, close = ViewpointLoot.openWindow, ViewpointLoot.closeWindow
        ViewpointLoot.openWindow = function(player, container, ...)
            local n = player and player:getPlayerNum() or 0
            if not Knox.forPlayer(n) then return open(player, container, ...) end
            -- Viewpoint gives the first container of what is looked at (a fridge, never
            -- its freezer; a car's first part within reach): the one whose row is chosen
            -- in its panel (the wheel) is opened instead
            -- (Knox's crosshair panel shown: the row chosen in it - 2026-10-25)
            local chosen = KnoxCrosshair and KnoxCrosshair.owned and KnoxCrosshair.chosen() or nil
            if not chosen then
                chosen = KnoxCompat.vpHas("menu") and knoxViewpointChosen and knoxViewpointChosen() or nil
            end
            if chosen and container and chosen ~= container then container = chosen end
            if not KnoxScreen.instance then Knox.viewpointLookAfter = true end
            ViewpointLoot.knoxOpened = KnoxScreen.instance == nil
            if not Knox.open(n, container or ISInventoryPage.GetFloorContainer(n)) then
                return open(player, container, ...)   -- (failed: Viewpoint's own window)
            end
        end
        ViewpointLoot.closeWindow = function(player, ...)
            local n = player and player:getPlayerNum() or 0
            if not Knox.forPlayer(n) then return close(player, ...) end
            if KnoxScreen.instance and ViewpointLoot.knoxOpened then KnoxScreen.instance:close() end
            ViewpointLoot.knoxOpened = false
        end
    end
    -- Its Grab (one thing, or all of the panel) goes through the Knox grids:
    -- only what has room, nothing a search has not found (KnoxActions.grab).
    -- Furniture and bodies, carried in the arms, stay Viewpoint's.
    if not KnoxCompat.luaHas("ViewpointLoot", ViewpointLoot, {"take", "takeAll"}) then return end
    local take, takeAll = ViewpointLoot.take, ViewpointLoot.takeAll
    local function heavy(item)
        return isForceDropHeavyItem(item) or item:isHumanCorpse()
    end
    local function grab(player, list)
        local n = player:getPlayerNum()
        local walk = function(item) return luautils.walkToContainer(item:getContainer(), n) end
        -- (no bar over the head for these, as Viewpoint has it)
        local add = ISTimedActionQueue.add
        ISTimedActionQueue.add = function(action)
            action.useProgressBar = false
            return add(action)
        end
        local ok, err = pcall(KnoxActions.grab, player, list, walk)
        ISTimedActionQueue.add = add
        if not ok then error(err) end
    end
    ViewpointLoot.take = function(player, item, ...)
        local n = player and player:getPlayerNum() or 0
        if not Knox.forPlayer(n) or not item or heavy(item) then return take(player, item, ...) end
        knoxFromGround(item, n)
        grab(player, {item})
    end
    ViewpointLoot.takeAll = function(player, items, ...)
        local n = player and player:getPlayerNum() or 0
        if not Knox.forPlayer(n) or not items then return takeAll(player, items, ...) end
        local list, big = {}, nil
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if heavy(item) then
                big = big or item
            elseif not item:isUnwanted(player) then
                knoxFromGround(item, n)
                table.insert(list, item)
            end
        end
        if #list == 0 then
            if big then take(player, big) end
            return
        end
        grab(player, list)
    end
    -- Knox's crosshair panel takes the same way (KnoxCrosshair; the author,
    -- 2026-10-25): `items` a Lua list - one thing, or all of a list in the panel
    Knox.viewpointGrab = function(player, items)
        local n = player:getPlayerNum()
        local list = {}
        for _, item in ipairs(items) do
            if heavy(item) then
                if #items == 1 then return take(player, item) end
            elseif #items == 1 or not item:isUnwanted(player) then
                knoxFromGround(item, n)
                table.insert(list, item)
            end
        end
        if #list > 0 then grab(player, list) end
    end
end

-- The game's own "Grab" on things lying on the ground (a right click in the
-- world) put them into the pockets, room or not: now through the Knox grids too.
local function hookWorldGrab()
    local W = ISWorldObjectContextMenu
    if not W or W.knoxGrabHooked then return end
    W.knoxGrabHooked = true
    local function grab(WItems, n, count)
        local playerObj = getSpecificPlayer(n)
        local items = {}
        for i = 1, math.min(count, #WItems) do
            local item = WItems[i]:getItem()
            if item then
                knoxFromGround(item, n)
                table.insert(items, item)
            end
        end
        local sq = WItems[1]:getSquare()
        KnoxActions.grab(playerObj, items, function() return sq ~= nil and luautils.walkAdj(playerObj, sq) end)
    end
    local one, half, all = W.onGrabWItem, W.onGrabHalfWItems, W.onGrabAllWItems
    W.onGrabWItem = function(worldobjects, WItem, player, ...)
        if not Knox.forPlayer(player) or not WItem then return one(worldobjects, WItem, player, ...) end
        grab({WItem}, player, 1)
    end
    W.onGrabHalfWItems = function(worldobjects, WItems, player, ...)
        if not Knox.forPlayer(player) or not WItems or #WItems == 0 then return half(worldobjects, WItems, player, ...) end
        grab(WItems, player, math.ceil(#WItems / 2))
    end
    W.onGrabAllWItems = function(worldobjects, WItems, player, ...)
        if not Knox.forPlayer(player) or not WItems or #WItems == 0 then return all(worldobjects, WItems, player, ...) end
        grab(WItems, player, #WItems)
    end

    -- The item menu's Grab / Grab one / Grab half (a right click on a thing of
    -- the surroundings): into the pockets, room or not, and past the stack of
    -- its kind (the author's test, 2026-10-15) - now through the grids too.
    -- Bodies and furniture stay the game's.
    local P = ISInventoryPaneContextMenu
    if not P or P.knoxGrabHooked then return end
    P.knoxGrabHooked = true
    local function itemsMenu(orig, pick)
        return function(items, player, ...)
            local playerObj = getSpecificPlayer(player)
            if not Knox.forPlayer(player) or not playerObj then return orig(items, player, ...) end
            local flat = {}
            for _, k in ipairs(ISInventoryPane.getActualItems(items)) do
                if instanceof(k, "InventoryItem") then table.insert(flat, k) end
            end
            local list = {}
            for _, k in ipairs(flat) do
                if k:isHumanCorpse() or isForceDropHeavyItem(k) then return orig(items, player, ...) end
                local c = k:getContainer()
                if c and c ~= playerObj:getInventory() and not c:isInCharacterInventory(playerObj) then
                    table.insert(list, k)
                end
            end
            list = pick(list)
            if #list == 0 then return end
            for _, k in ipairs(list) do knoxFromGround(k, player) end
            KnoxActions.grab(playerObj, list, function(item) return luautils.walkToContainer(item:getContainer(), player) end)
        end
    end
    P.onGrabItems = itemsMenu(P.onGrabItems, function(l) return l end)
    P.onGrabOneItems = itemsMenu(P.onGrabOneItems, function(l) return {l[1]} end)
    P.onGrabHalfItems = itemsMenu(P.onGrabHalfItems, function(l)
        local out = {}
        for i = 1, math.min(#l, math.max(1, math.floor(#l / 2))) do table.insert(out, l[i]) end
        return out
    end)
end

-- Project Viewpoint QOL frees the cursor while the game's own windows are open
-- and takes it back when they close. It doesn't see the Knox screen (the game's
-- inventory windows stay hidden), so right after Tab it thinks the inventory
-- closed again, and after a right-click menu in Knox closes it takes the mouse
-- back - with the screen still open. Its lock waits while anything of Knox is
-- open (the cursor stays there anyway, see above: a lock let through only
-- grabbed the mouse for a frame and threw the cursor to the middle).
local function hookViewpointQOL()
    local b = ViewpointQOL
    if type(b) ~= "table" or type(b.lockMouse) ~= "function" or b.knoxHooked then return end
    local lock = b.lockMouse
    local ok = pcall(function()
        b.lockMouse = function(...)
            if knoxWindowOpen() then return end
            return lock(...)
        end
        b.knoxHooked = true
    end)
    print("[Knox] Project Viewpoint QOL " .. (ok and b.knoxHooked and "found: its cursor lock waits for Knox windows" or "found, but its cursor lock could not be wrapped"))
end

--- The Java part didn't load: say so, with what to do - in the main menu
--- (the mod has just been enabled: the game must be restarted) and once a
--- game starts.
local function tellJavaMissing(inMenu)
    local key = KnoxTheme.javaVersion and "IGUI_Knox_JavaOld" or (inMenu and "IGUI_Knox_JavaRestart" or "IGUI_Knox_JavaMissing")
    local text = getText(key, tostring(KnoxTheme.javaVersion or ""), tostring(KnoxTheme.JAVA_NEEDED))
    local fontH = getTextManager():getFontHeight(UIFont.Small)
    local w, h = math.max(640, fontH * 34), math.max(240, fontH * 14)
    local modal = ISModalDialog:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2,
        w, h, text, false, nil, nil, 0)
    modal:initialise()
    modal:addToUIManager()
    if inMenu then modal:setAlwaysOnTop(true) end   -- the main screen comes to the top on a click
end

Events.OnMainMenuEnter.Add(function()
    if not KnoxTheme.active then tellJavaMissing(true) end
end)

Events.OnGameStart.Add(function()
    if not KnoxTheme.active then
        -- nothing of the game is replaced: its own windows, keys and menus stay
        print("[Knox] Knox Inventory " .. Knox.VERSION .. " inactive: Java part "
            .. (KnoxTheme.javaVersion and ("v" .. KnoxTheme.javaVersion .. ", needs v" .. KnoxTheme.JAVA_NEEDED) or "not loaded (ZombieBuddy)"))
        tellJavaMissing(false)
        return
    end
    applyCursor()
    KnoxTheme.refresh()
    -- each part in a game on its own (KnoxTheme.MODULES); the ones switched off
    -- leave the game's windows, keys and menus as they are
    local on = {}
    for _, name in ipairs(KnoxTheme.MODULE_GROUPS[1].list) do
        if KnoxTheme.on(name) then table.insert(on, name) end
    end
    print("[Knox] Knox Inventory " .. Knox.VERSION .. " loaded, Java part v" .. KnoxTheme.javaVersion .. ", cell "
        .. KnoxTheme.cell .. " px, in game: " .. (#on > 0 and table.concat(on, " ") or "nothing (all modules off)"))
    if KnoxTheme.on("fluids") then
        hookFluidTransfer()
        hookFluidInfo()
    end
    if KnoxTheme.on("devices") then hookRadioWindow() end
    -- (Project Viewpoint QOL's cursor lock waits for any Knox window)
    if #on > 0 then hookViewpointQOL() end
    if not KnoxTheme.on("inventory") then return end
    -- the inventory key no longer toggles the game's windows
    Events.OnKeyPressed.Remove(ISInventoryPage.onKeyPressed)
    hookWorldClick()
    hookLootShow()
    hookPlaceItem()
    hookViewpoint()
    hookWorldGrab()
    hideVanilla(0)
    -- the inspect window's textured bag/clothes models (media/scripts/knox_inspect_models.txt)
    local probe = getScriptManager():getModelScript("KnoxInspect.SchoolBag_Ground__Bag_SchoolBag_0")
    print("[Knox] inspect model scripts " .. (probe and "loaded" or "NOT loaded"))
end)
-- (after the hooks above: Viewpoint's parts found and off, one line - KnoxCompat)
Events.OnGameStart.Add(function()
    if KnoxTheme.active then KnoxCompat.report() end
end)
Events.OnKeyPressed.Add(onKeyPressed)
Events.OnContainerUpdate.Add(onContainerUpdate)
Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnResolutionChange.Add(onResolutionChange)
Events.OnTick.Add(onTick)
