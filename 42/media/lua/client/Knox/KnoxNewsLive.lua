-- The inventory and the menu on R live in a news post ("@inv", "@rmenu"; the author,
-- 2026-11-05: "the window with the magazines must repeat the game's interface exactly and
-- how it works: a tooltip on hover, a context menu on the right button, Shift shows the
-- quick items' panel and so on - and the panel on R the same way, in the block about it").
--
-- Not a picture of them: Knox's own grid (KnoxGridView), its dragging, tooltips and context
-- menu, the magazine's panel (KnoxLoad, KnoxSlotPicker) and the menu on R (KnoxRMenu) run
-- here on real things of the game, in a container of their own. Only two things are
-- pretended, as the main menu has neither: the character (a table answering what those ask
-- of one) and what runs its actions (W.queue, stepped below: the game's own actions are
-- made, their effect is done here, as it is in their perform()). Made anew each time the
-- post is opened; nothing of it reaches a save. An error is a line in console.txt and the
-- block goes away - never the game's error window over the news.
--
-- Placed by the news reader each frame (W.hostGrid, W.drawRBlock); the elements over the
-- whole UI are added and taken away before the UI is drawn (the OnPreUIDraw at the end).

require "ISUI/ISUIElement"
require "ISUI/ISContextMenu"
require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISRackFirearm"
require "Knox/KnoxTheme"
require "Knox/KnoxGridView"
require "Knox/KnoxDrag"
require "Knox/KnoxLoad"
require "Knox/KnoxSlotPicker"
require "Knox/KnoxTooltip"
require "Knox/KnoxContextMenu"
require "Knox/KnoxRMenu"

KnoxNewsLive = KnoxNewsLive or {}
local W = KnoxNewsLive
local T = KnoxTheme
local M = KnoxRMenu
local K = KnoxMagKnown
local CM = ISInventoryPaneContextMenu
local Q = ISTimedActionQueue

local ROUND_MS, MOVE_MS = 450, 900   -- a round in or out; a magazine in or out, racking
local HOLD_MS = 500                  -- (the game's and the menu on R's)
local COLS, ROWS = 8, 2
local EMPTY = {}

W.live = false        -- the post is up, its world made
W.broken = false      -- an error: no blocks until the game is started again
W.menuUp = false      -- the context menu is showing (the reader lets it have the clicks)

-- The pretend character ----------------------------------------------------------------

local function noop() return nil end

-- (anything else asked of it: nothing - not dead, not aiming, not asleep...)
W.player = W.player or setmetatable({}, {__index = function() return noop end})
local PLAYER = W.player
function PLAYER:getInventory() return W.inv end
function PLAYER:getPrimaryHandItem() return W.gun end
function PLAYER:getPlayerNum() return 0 end

-- Its actions --------------------------------------------------------------------------
-- What each does when its time comes, as its perform() and animEvent() do on a character.

local function roundsOf(item)
    return item:getAmmoType():getItemKey()
end

--- A round into the magazine. True: the action is over.
local function loadRound(a)
    local mag, inv = a.magazine, W.inv
    K.mark(mag)
    local key = roundsOf(mag)
    local n, max = mag:getCurrentAmmoCount(), mag:getMaxAmmo()
    if n >= max or inv:getItemCountRecurse(key) <= 0 then return true end
    inv:RemoveOneOf(key, true)
    mag:setCurrentAmmoCount(n + 1)
    a.knoxDone = (a.knoxDone or 0) + 1
    return a.knoxDone >= a.ammoCount or n + 1 >= max
end

--- A round out of the magazine.
local function unloadRound(a)
    local mag = a.magazine
    K.mark(mag)
    local n = mag:getCurrentAmmoCount()
    if n <= 0 then return true end
    W.inv:AddItem(instanceItem(roundsOf(mag)))
    mag:setCurrentAmmoCount(n - 1)
    return n - 1 <= 0
end

--- The magazine out of the gun: a new item, known (ISEjectMagazine:unloadAmmo).
local function ejectMag(a)
    local gun = a.gun
    local mag = instanceItem(gun:getMagazineType())
    K.mark(mag)
    mag:setCurrentAmmoCount(gun:getCurrentAmmoCount())
    W.inv:AddItem(mag)
    gun:setContainsClip(false)
    gun:setCurrentAmmoCount(0)
    return true
end

--- The magazine into the gun; with no round in the chamber it is racked after that.
local function insertMag(a)
    local gun, mag = a.gun, a.magazine
    W.inv:Remove(mag)
    gun:setCurrentAmmoCount(mag:getCurrentAmmoCount())
    gun:setContainsClip(true)
    if not gun:isRoundChambered() and gun:getCurrentAmmoCount() >= gun:getAmmoPerShoot() then
        table.insert(W.queue, ISRackFirearm:new(PLAYER, gun))
    end
    return true
end

--- The bolt: the round in the chamber comes out, the next goes in.
local function rack(a)
    local gun = a.gun
    if gun:isRoundChambered() and not gun:isJammed() then W.inv:AddItem(instanceItem(roundsOf(gun))) end
    gun:setRoundChambered(false)
    gun:setJammed(false)
    local n, per = gun:getCurrentAmmoCount(), gun:getAmmoPerShoot()
    if n >= per then
        gun:setRoundChambered(true)
        gun:setCurrentAmmoCount(n - per)
    end
    return true
end

local DO = {ISLoadBulletsInMagazine = loadRound, ISUnloadBulletsFromMagazine = unloadRound,
            ISEjectMagazine = ejectMag, ISInsertMagazine = insertMag, ISRackFirearm = rack}
local BY_ROUND = {ISLoadBulletsInMagazine = true, ISUnloadBulletsFromMagazine = true}

local function runQueue(now)
    local q = W.queue
    local a = q[1]
    if not a then return end
    if not a.action then
        -- (what the grid's bar and the menu's rows read off an action under way: KnoxGrid.useDelta)
        a.action, a.maxTime = true, -1
        if BY_ROUND[a.Type] then a.ammoCountStart = a.magazine:getCurrentAmmoCount() end
        a.knoxDue = now + (BY_ROUND[a.Type] and ROUND_MS or MOVE_MS)
    end
    if now < a.knoxDue then return end
    local fn = DO[a.Type or ""]
    if not fn or fn(a) then
        table.remove(q, 1)
    else
        a.knoxDue = now + ROUND_MS
    end
end

-- (only once: the Lua reloaded, they would be wrapped twice. Asked of the pretend character
-- only, the game's queue and hands are not touched.)
if not W.wrapped then
    W.wrapped = true
    local add, clear = Q.add, Q.clear
    function Q.add(action)
        if W.live and action.character == W.player then
            table.insert(W.queue, action)
            return nil
        end
        return add(action)
    end
    function Q.clear(character)
        if W.live and character == W.player then
            table.wipe(W.queue)
            return nil
        end
        return clear(character)
    end
    local equip = CM.equipWeapon
    function CM.equipWeapon(weapon, ...)
        if W.live and weapon == W.gun then return end   -- (it is in hand)
        return equip(weapon, ...)
    end
    local explain = KnoxDrag.explain
    function KnoxDrag.explain(player, why)
        if W.live and player == W.player then return end   -- (no one for the words to rise over)
        return explain(player, why)
    end
end

-- The world ----------------------------------------------------------------------------

local function place(item, x, y)
    item:getModData().knox = {k = "p", x = x, y = y, r = 0}
end

--- As in the approved mockup: a pistol in hand (the grid doesn't show what is in hand), two
--- magazines nobody has looked into, thirty rounds. What the gun takes is asked of the gun.
local function makeWorld()
    local inv = ItemContainer.new()
    W.inv = inv
    KnoxGrid.fixedSize[inv] = {cols = COLS, rows = ROWS}
    local gun = instanceItem("Base.Pistol")
    gun:setContainsClip(true)
    gun:setCurrentAmmoCount(9)
    gun:setRoundChambered(true)
    inv:AddItem(gun)
    W.gun = gun
    local magType = gun:getMagazineType()
    local function mag(n, x)
        local m = instanceItem(magType)
        m:setCurrentAmmoCount(n)
        place(m, x, 0)
        inv:AddItem(m)
    end
    mag(7, 1)
    mag(3, 2)
    local key = roundsOf(gun)
    for i = 1, 30 do
        local r = instanceItem(key)
        if i == 1 then place(r, 4, 1) end
        inv:AddItem(r)
    end
end

-- The grid -----------------------------------------------------------------------------

KnoxNewsGridView = KnoxGridView:derive("KnoxNewsGridView")
local V = KnoxNewsGridView

function V:new(x, y)
    local o = KnoxGridView.new(self, x, y, W.inv, 0)
    o.clip = {0, 0, 0, 0}
    return o
end

function V:player() return PLAYER end

function V:rebuild()
    KnoxGridView.rebuild(self)
    self.silhouettes = nil   -- (the places of the player's own layout are no part of this)
end

function V:inClip(x, y)
    local c = self.clip
    return x >= c[1] and y >= c[2] and x < c[1] + c[3] and y < c[2] + c[4]
end

--- A press off its shown part goes to the window it stands in.
function V:toHost(fn, x, y)
    local h = self.host
    if not (h and h[fn]) then return false end
    h[fn](h, x + self:getX(), y + self:getY())
    return true
end

function V:entityUnderMouse()
    if M.state == "open" or not self:inClip(self:getMouseX(), self:getMouseY()) then return nil end
    return KnoxGridView.entityUnderMouse(self)
end

function V:prerender()
    local ok, err = pcall(KnoxGridView.prerender, self)
    if not ok then W.problem = W.problem or err end
end

function V:render()
    local c = self.clip
    self:setStencilRect(c[1], c[2], c[3], c[4])
    local ok, err = pcall(KnoxGridView.render, self)
    self:clearStencilRect()
    if not ok then W.problem = W.problem or err end
end

local function guarded(self, fn, x, y)
    local ok, res = pcall(fn, self, x, y)
    if not ok then
        W.problem = W.problem or res
        return true
    end
    return res
end

function V:onMouseDown(x, y)
    if not self:inClip(x, y) then return self:toHost("onMouseDown", x, y) end
    return guarded(self, KnoxGridView.onMouseDown, x, y)
end

function V:onMouseUp(x, y)
    -- (let go over the cut-off part: as outside it)
    if not self:inClip(x, y) then
        guarded(self, KnoxGridView.onMouseUpOutside, x, y)
        return true
    end
    return guarded(self, KnoxGridView.onMouseUp, x, y)
end

function V:onMouseMove(dx, dy)
    return guarded(self, KnoxGridView.onMouseMove, dx, dy)
end

function V:onRightMouseUp(x, y)
    if not self:inClip(x, y) then return self:toHost("onRightMouseUp", x, y) end
    return guarded(self, KnoxGridView.onRightMouseUp, x, y)
end

--- What makes sense with one grid and no world: selecting and the menu. (Moving to another
--- container, opening a window of the thing, have nowhere to go here.)
function V:doAction(id, e)
    if id == "select" or id == "menu" then return KnoxGridView.doAction(self, id, e) end
end

-- Its context menu: the game's item menu can't be built whole (it asks a real character of
-- the game for all it offers); what a magazine and rounds have in it comes from the same
-- functions of the game, Knox's versions on top of them, in the game's order.

--- The game's "Drop": there is no floor here, the things are gone until the post is opened again.
function W.dropItems(_, items)
    for _, it in ipairs(items) do
        if not it:isFavorite() then W.inv:Remove(it) end
    end
    if W.view then W.view:markDirty() end
end

local function fillMenu(context, e, items, many)
    local item = e.item
    if not many then
        local kind = T.levelKind(item)
        if kind == "m" then
            CM.doMagazineMenu(PLAYER, item, context)
        elseif KnoxLoad.kindOf(item:getFullType()) == "ammo" then
            CM.doReloadMenuForBullets(PLAYER, item, context)
        end
    end
    context:addOption(getText("ContextMenu_Drop"), W, W.dropItems, items)
    -- "More": the game's Favorite (it keeps a thing from being dropped; a star on its tile)
    local more = context:getNew(context)
    local fav = item:isFavorite()
    local option = more:addOption(getText(fav and "ContextMenu_Unfavorite" or "IGUI_CraftUI_Favorite"), items, CM.onFavorite, item, not fav)
    option.iconTexture = getTexture(fav and "media/ui/FavoriteStarUnchecked.png" or "media/ui/FavoriteStarChecked.png")
    context:addSubMenu(context:addOption(getText("ContextMenu_More")), more)
end

function V:openMenu(e, x, y)
    local items = {}
    local groups = KnoxSelect.group(e, self, KnoxActions.allViews())
    for _, g in ipairs(groups) do
        for _, it in ipairs(g.entity.items) do table.insert(items, it) end
    end
    KnoxContextMenu.setTarget(items, 0)
    local context = ISContextMenu.get(0, self:getAbsoluteX() + x, self:getAbsoluteY() + y)
    fillMenu(context, e, items, #groups > 1)
    return true
end

-- The menu on R: on an element of its own, 0 x 0, over the post, in the post's middle ---

KnoxNewsRLayer = ISUIElement:derive("KnoxNewsRLayer")
local RL = KnoxNewsRLayer

function RL:new()
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    return o
end

function RL:render()
    if not M.state and not M.armed then return end
    local v = W.rView
    if v then
        M.ox = W.rCentre - math.floor((M.W or 0) / 2)
        local h = M.H or M.openH or 0
        M.oy = math.max(v[2], math.min(v[2] + v[4] - h, W.rMid - math.floor(h / 2)))
    end
    local ok, err = pcall(M.frame, self)
    if not ok then
        self:clearStencilRect()
        W.problem = W.problem or err
    end
end

-- Coming and going ---------------------------------------------------------------------

local function layer(el)
    el:initialise()
    el:addToUIManager()
    el:setAlwaysOnTop(true)
    return el
end

local function enter(host)
    W.live, W.host, W.want = true, host, nil
    W.queue, W.problem, W.menuUp = {}, nil, false
    W.rDownMs, W.rOpened, W.rSeen, W.rView = nil, false, nil, nil
    makeWorld()
    KnoxLoad.index()   -- (read now, with the post coming up: not as the mouse comes onto a thing)
    Q.queues[PLAYER] = {queue = W.queue}
    W.wasHide = K.hide
    K.hide = true
    if knoxHideRounds then pcall(knoxHideRounds, true) end
    -- the context menu: the game gives each player one with the world; made here its way
    W.menu = ISContextMenu:new(0, 0, 1, 1)
    W.menu:initialise()
    W.menu:addToUIManager()
    W.menu:setVisible(false)
    W.menu.player = 0
    W.menu:setAlwaysOnTop(true)
    W.oldGet = getPlayerContextMenu
    _G.getPlayerContextMenu = function() return W.menu end
    W.dragLayer = KnoxDragLayer:new()
    W.dragLayer.noTooltip = true   -- (W.step applies it, before the UI is drawn)
    layer(W.dragLayer)
    W.rLayer = layer(RL:new())
    M.layer, M.inNews = W.rLayer, true
    W.key = (KeybindId and getCore():getKey(KeybindId.RELOAD_WEAPON)) or Keyboard.KEY_R
    W.keyName = (knoxKeyName and knoxKeyName(W.key) or Keyboard.getKeyName(W.key)) or "R"
    W.keyText = getText("IGUI_Knox_NewsRHold")
    W.view = V:new(0, 0)
    W.view:initialise()
    W.view:instantiate()
    KnoxActions.newsView = W.view
end

local function drop(el)
    if el then pcall(function()
        el:setVisible(false)
        el:removeFromUIManager()
    end) end
end

--- All of it gone, each part whatever became of the others.
function W.leave()
    if not W.live then return end
    W.live, W.menuUp = false, false
    pcall(KnoxDrag.cancel)
    pcall(KnoxSelect.clear)
    pcall(function()
        M.abort()
        M.inNews, M.layer, M.failed = false, nil, false
        drop(M.catch)
        M.catch = nil
    end)
    drop(W.rLayer)
    drop(W.dragLayer)
    pcall(function()
        local P = KnoxSlotPicker
        P.request = nil
        P.close()
        for _, p in ipairs(P.dying) do
            p:setVisible(false)
            p:removeFromUIManager()
        end
        P.dying = {}
    end)
    pcall(KnoxTooltip.reset)
    pcall(function()
        local menu = W.menu
        if menu then
            for _, sub in ipairs(menu.instanceMap or EMPTY) do drop(sub) end
            if menu.toolTip then drop(menu.toolTip) end
        end
        drop(menu)
        KnoxContextMenu.target = nil
    end)
    if W.oldGet then _G.getPlayerContextMenu = W.oldGet end
    K.hide = W.wasHide == true
    if knoxHideRounds then pcall(knoxHideRounds, K.hide) end
    pcall(function()
        if W.queue then table.wipe(W.queue) end
        KnoxGrid.updateUse(PLAYER)
        Q.queues[PLAYER] = nil
    end)
    KnoxActions.newsView = nil
    pcall(function()
        local v, h = W.view, W.host
        if v then
            v:setVisible(false)
            if h and v.host == h then h:removeChild(v) end
        end
    end)
    if W.inv then
        KnoxGrid.liveGrids[W.inv] = nil
        KnoxGrid.fixedSize[W.inv] = nil
    end
    W.view, W.host, W.want, W.inv, W.gun, W.queue = nil, nil, nil, nil, nil, nil
    W.menu, W.oldGet, W.dragLayer, W.rLayer, W.rView = nil, nil, nil, nil, nil
end

function W.fail(err)
    print("[Knox] the news' live inventory is off after an error: " .. tostring(err))
    W.broken = true
    W.leave()
end

-- Each frame ---------------------------------------------------------------------------

--- Things over the post stay over it: the post is always on top, and so must they be.
local function top(el)
    if not el.knoxTop then
        el.knoxTop = true
        el:setAlwaysOnTop(true)
    end
    el:bringToTop()
end

local function tops()
    local P = KnoxSlotPicker
    if P.instance then top(P.instance) end
    for i = 1, #P.dying do top(P.dying[i]) end
    local tip = KnoxTooltip.tip
    if tip and tip.knoxShown then top(tip) end
    local menu = W.menu
    W.menuUp = menu:isAnyVisible() == true
    if W.menuUp then
        top(menu)
        for _, sub in ipairs(menu.instanceMap or EMPTY) do
            top(sub)
            if sub.toolTip then top(sub.toolTip) end
        end
        if menu.toolTip then top(menu.toolTip) end
    end
    if M.state then
        if M.catch then top(M.catch) end
        top(W.rLayer)
    end
end

--- The key held with the block on the screen: the menu, as the game's own hold brings it up.
local function pollR(now)
    if not isKeyDown(W.key) then
        W.rDownMs, W.rOpened = nil, false
        return
    end
    W.rDownMs = W.rDownMs or now
    if W.rOpened or now - W.rDownMs < HOLD_MS then return end
    if not (W.rSeen and now - W.rSeen < 200) or KnoxDrag.isActive() or W.menuUp or M.state then return end
    W.rOpened = true
    M.open(PLAYER, W.key)
end

local function step(now)
    if KnoxMenuNewsReader.instance ~= W.host then
        W.leave()
        return
    end
    KnoxGrid.updateUse(PLAYER)
    runQueue(now)
    KnoxLoad.sync()
    KnoxSlotPicker.sync(nil)
    KnoxTooltip.apply()
    pollR(now)
    tops()
end

local function liveFrame()
    if W.want and not W.live and not W.broken then
        local host = W.want
        W.want = nil
        if KnoxMenuNewsReader.instance == host then
            local ok, err = pcall(enter, host)
            if not ok then W.fail(err) end
        end
    end
    if not W.live then return end
    local ok, err = pcall(step, getTimestampMs())
    if not ok then W.problem = W.problem or err end
    if W.problem then W.fail(W.problem) end
end
Events.OnPreUIDraw.Add(liveFrame)
T.offInGame(Events.OnPreUIDraw, liveFrame, "inventory")   -- (the news in the Knox screen)

Events.OnGameStart.Add(function() W.leave() end)

-- For the reader -----------------------------------------------------------------------

--- The grid's size in pixels, with its frame.
function W.gridSize()
    return COLS * T.cell + 5, ROWS * T.cell + 5
end

--- The grid at x, y of the post (its frame there), cut to the view. The first calls only ask
--- for it: its elements come before the next frame's drawing.
function W.hostGrid(host, x, y, view)
    if W.broken then return end
    if not W.live then
        W.want = host
        return
    end
    local v = W.view
    if not v or W.host ~= host then return end
    local w, h = W.gridSize()
    T.rect(host, x, y, w, h, T.color.cell)
    T.tileFrame(host, x, y, w, h, T.color.tileFrame)
    if v.host ~= host then
        host:addChild(v)
        v.host = host
    end
    local gx, gy = x + 2, y + 2
    v:setX(gx)
    v:setY(gy)
    local c = v.clip
    local x0, y0 = math.max(view[1], gx), math.max(view[2], gy)
    local x1, y1 = math.min(view[1] + view[3], gx + w), math.min(view[2] + view[4], gy + h)
    c[1], c[2], c[3], c[4] = x0 - gx, y0 - gy, math.max(0, x1 - x0), math.max(0, y1 - y0)
    v:setVisible(c[3] > 0 and c[4] > 0)
end

--- The block about the menu on R: the key to hold on a plate in the post's colour. Holding it
--- brings the menu itself up over the plate. Returns the block's height.
function W.drawRBlock(host, centre, y, view, c)
    if W.broken then return 0 end
    local pad = T.pad
    local kh = T.fontH(T.fontTile) + 4
    local h = kh + pad * 2
    if not W.live then
        W.want = host
        return h
    end
    local w = T.keyW(W.keyName) + 6 + T.measure(T.fontText, W.keyText) + pad * 4
    local x = centre - math.floor(w / 2)
    T.rect(host, x, y, w, h, T.color.window, 0.7)
    T.tileFrame(host, x, y, w, h, c)
    T.keyHint(host, x + pad * 2, y + pad, W.keyName, W.keyText)
    -- (the menu comes where the plate is, and only while it can be seen)
    W.rCentre, W.rMid, W.rView = centre, y + math.floor(h / 2), view
    if y + h > view[2] and y < view[2] + view[4] then W.rSeen = getTimestampMs() end
    return h
end

--- Esc: the menu or what is held goes first, the post stays. True: it took the key.
function W.onEsc()
    if not W.live then return false end
    if W.menuUp and W.menu then
        W.menu:hideAndChildren()
        return true
    end
    if KnoxDrag.isActive() then
        KnoxDrag.cancel()
        return true
    end
    return false
end

return KnoxNewsLive
