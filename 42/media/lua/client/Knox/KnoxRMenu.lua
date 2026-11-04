-- The menu on R (the author, 2026-10-31; the approved mockup .claude/mockups/ammo_live.html),
-- in the world only: a short press of the reload key is the game's reload, as ever; held,
-- this comes up in place of the game's round menu. Let go, it closes and does nothing.
-- The wheel chooses a row, the left button does it, the right button loads the chosen
-- magazine, twice within 250 ms unloads it. While it is open the mouse does nothing to
-- the game (an element over the whole screen takes its clicks and wheel, KnoxInput holds
-- what was already down and hides the cursor).
--
-- Its plate and rows are kin of the crosshair panel's (KnoxCrosshair): the same sizes
-- from the cell, the same plate, opening, highlight and hints. The game's own actions do
-- the work; loading and unloading go on after R is let go; walking does not stop them,
-- running does, as in the game (the author, 2026-11-04).
--
-- A gamepad keeps the game's round menu. The "rmenu" module off, or anything amiss here,
-- and the game's own comes back.

require "Knox/KnoxTheme"
require "Knox/KnoxLoad"
require "Knox/KnoxMagKnown"
require "ISUI/ISFirearmRadialMenu"
require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISReloadWeaponAction"

KnoxRMenu = KnoxRMenu or {}
local M = KnoxRMenu
local T = KnoxTheme
local L = KnoxLoad
local K = KnoxMagKnown

local HOLD_MS = 500               -- (the game's: ISFirearmRadialMenu)
local DOUBLE_MS = 250             -- two right clicks within this: unload
local UNFOLD_MS, FOLD_MS, SHOW_MS = 170, 130, 110   -- (as the crosshair panel's)
local HINT_MS = 200
local REFRESH_MS = 100            -- what is in the magazines, the rounds carried
local RECOUNT_MS = 500            -- a magazine come or gone
local MAX_ROWS = 8
local SHELLS = "Base.ShotgunShells"
-- (the crosshair panel's and the context menu's colours)
local BLACK = {r = 0, g = 0, b = 0}
local EDGE = {r = 74 / 255, g = 79 / 255, b = 79 / 255}
local HOVER = {r = 35 / 255, g = 39 / 255, b = 42 / 255}
local RED = {r = 217 / 255, g = 138 / 255, b = 124 / 255}
local WHITE = {r = 1, g = 1, b = 1}

-- the actions that move rounds, and what they work on (as KnoxGrid's bar)
local JOB = {ISLoadBulletsInMagazine = "magazine", ISUnloadBulletsFromMagazine = "magazine",
             ISReloadWeaponAction = "gun", ISUnloadBulletsFromFirearm = "gun"}
local JOB_OUT = {ISUnloadBulletsFromMagazine = true, ISUnloadBulletsFromFirearm = true}
-- the menu may come up over these (its own, under way)
local ITS_OWN = {ISLoadBulletsInMagazine = true, ISUnloadBulletsFromMagazine = true, ISReloadWeaponAction = true,
                 ISUnloadBulletsFromFirearm = true, ISInsertMagazine = true, ISEjectMagazine = true, ISRackFirearm = true}

M.state = nil      -- nil closed, "open", "fold" folding away
M.failed = false   -- anything amiss: the game's round menu until the Lua reloads
M.rows = {}
M.sel = 1

-- Sizes, from the cell ------------------------------------------------------------------

local Z = {}
local function sizes()
    local c = T.cell
    if Z.cell == c and Z.java == T.javaFonts then return end
    local s = c / 48
    local function px(n) return math.max(1, math.floor(n * s + 0.5)) end
    Z.cell, Z.java = c, T.javaFonts
    Z.GAP, Z.M, Z.ROW = px(8), px(7), px(32)
    Z.L = Z.GAP + Z.M
    Z.CELL, Z.IC = px(26), px(22)
    Z.TX = Z.L + Z.CELL + px(10)
    Z.MINW, Z.MAXW, Z.STRIP, Z.ROUNDS = px(260), px(370), px(14), px(32)
    Z.KH, Z.HINT_GAP = px(20), px(16)
    Z.GROW_H, Z.GROW_CELL = px(6), px(4)
    Z.PH = px(7) * 2 + px(43)
    Z.SW, Z.SG, Z.SH = px(18), px(2), px(5)
    Z.SCW = 5 * Z.SW + 4 * Z.SG
    Z.P5, Z.P8, Z.P9, Z.P10, Z.P14, Z.P16, Z.P20 = px(5), px(8), px(9), px(10), px(14), px(16), px(20)
    Z.LEFT = px(48)
    Z.big = T.javaFonts and T.makeFont("body", c * 0.31 + 2 * s) or T.fontText
    Z.wide = nil
end
M.Z = Z

local STR
local function strings()
    if STR then return STR end
    local function tx(k) return getText("IGUI_Knox_RMenu_" .. k) end
    STR = {wheel = tx("Wheel"), pick = tx("Pick"), lmb = tx("LMB"), rmb = tx("RMB"), rmb2 = tx("RMB2"),
           swap = tx("Swap"), insert = tx("Insert"), load = tx("Load"), unload = tx("Unload"), use = tx("Use"),
           eject = tx("Eject"), bolt = tx("RackBolt"), pump = tx("RackPump"), unjam = tx("Unjam"),
           noGun = tx("NoWeapon"), magsRounds = tx("MagsRounds"), box = tx("OpenBox"), rounds = tx("Rounds"),
           loadAll = tx("LoadAll")}
    return STR
end

-- The scales ------------------------------------------------------------------------------

--- Parts lit of 5 for n rounds of cap (for 15: 15 - 5, 10-14 - 4, 6-9 - 3, 4-5 - 2, 1-3 - 1, 0 - 0).
function M.levelOf(n, cap)
    if cap <= 0 or n <= 0 then return 0 end
    if n >= cap then return 5 end
    local f = n / cap
    if f >= 2 / 3 then return 4 end
    if f >= 0.4 then return 3 end
    if f >= 0.25 then return 2 end
    return 1
end

--- Parts lit of the rounds carried: one for a magazine's worth, 5 at most.
function M.reserveLit(n, cap)
    if n <= 0 then return 0 end
    return math.min(5, math.ceil(n / math.max(1, cap)))
end

-- What is in it ---------------------------------------------------------------------------

local inkCache = {}
--- How far a picture's pixels are off its middle, in parts of its side (KnoxInput.java).
local function inkOf(tex)
    if not tex then return nil end
    local i = inkCache[tex]
    if not i then
        i = {x = knoxTexInkX and knoxTexInkX(tex) or 0, y = knoxTexInkY and knoxTexInkY(tex) or 0}
        inkCache[tex] = i
    end
    return i
end

local function picture(ui, tex, ink, x, y, side, a, c)
    if not tex then return end
    c = c or WHITE
    local dx, dy = 0, 0
    if ink then dx, dy = math.floor(ink.x * side + 0.5), math.floor(ink.y * side + 0.5) end
    ui:drawTextureScaledAspect(tex, x - dx, y - dy, side, side, a, c.r, c.g, c.b)
end

local function gunOf(player)
    local it = player:getPrimaryHandItem()
    if it and instanceof(it, "HandWeapon") and it:isRanged() then return it end
    return nil
end

local function queueOf(player)
    local q = ISTimedActionQueue.queues and ISTimedActionQueue.queues[player]
    return q and q.queue or nil
end

local function isBusy(player)
    local q = queueOf(player)
    return q ~= nil and #q > 0
end

local function newRow(kind, item, name, tex)
    local cat = item and T.category[T.categoryOf(item)] or T.category.misc
    return {kind = kind, item = item, name = name, tex = tex or (item and item:getTex()), ink = inkOf(tex or (item and item:getTex())),
            cat = cat, edge = T.mix(cat, WHITE, 0.3), grow = 0, h = Z.ROW, y = 0, n = 0, cap = 0, lit = 0, known = false}
end

local function magRow(kind, mag)
    local r = newRow(kind, mag, mag:getDisplayName())
    r.m = mag
    r.key = mag:getAmmoType() and mag:getAmmoType():getItemKey() or nil
    return r
end

--- The magazines carried, known fuller first, not known last (the order is made only
--- on opening and after an action: not while one is being loaded).
local function sortMags(list)
    table.sort(list, function(a, b)
        local ka, kb = K.is(a) and a:getCurrentAmmoCount() + 1 or 0, K.is(b) and b:getCurrentAmmoCount() + 1 or 0
        if ka ~= kb then return ka > kb end
        return a:getID() < b:getID()
    end)
end

local function carried(player, ft, out)
    local got = player:getInventory():getAllTypeRecurse(ft)
    for i = 0, got:size() - 1 do table.insert(out, got:get(i)) end
    return out
end

--- All the magazines the character has, of any gun (no gun in hand).
local function allMags(player)
    local out = {}
    for ft in pairs(L.index().mag) do carried(player, ft, out) end
    return out
end

local function firstBox(player, mags)
    local x = L.index()
    local seen = {}
    for _, m in ipairs(mags) do
        local at = m:getAmmoType()
        local key = at and at:getItemKey()
        if key and not seen[key] then
            seen[key] = true
            local entry = x.ammo[key]
            if entry then
                for box in pairs(entry.boxes) do
                    local got = player:getInventory():getAllTypeRecurse(box)
                    if got:size() > 0 then return got:get(0) end
                end
            end
        end
    end
    return nil
end

--- The row that loads them all (the author, 2026-11-04), when one of them may take
--- rounds: all but those known to be full.
local function allRow(mags, item, rows)
    for _, m in ipairs(mags) do
        if not (K.is(m) and m:getCurrentAmmoCount() >= m:getMaxAmmo()) then
            local r = newRow("all", item, strings().loadAll)
            r.mags = mags
            table.insert(rows, r)
            return
        end
    end
end

--- Rows and head for what is in hand. Returns nothing to show: no rows.
function M.rowsOf(player)
    local s = strings()
    local rows = {}
    local gun = gunOf(player)
    if not gun then
        local mags = allMags(player)
        sortMags(mags)
        for _, m in ipairs(mags) do table.insert(rows, magRow("bag", m)) end
        allRow(mags, mags[1], rows)
        local box = #mags > 0 and firstBox(player, mags) or nil
        if box then table.insert(rows, newRow("box", box, s.box)) end
        return rows, nil
    end
    local magType = gun:getMagazineType()
    local jam = gun:isJammed()
    if jam then
        local r = newRow("unjam", gun, s.unjam)
        r.red = true
        table.insert(rows, r)
    end
    if magType and magType ~= "" then
        local mags = carried(player, magType, {})
        sortMags(mags)
        for _, m in ipairs(mags) do table.insert(rows, magRow(gun:isContainsClip() and "swap" or "insert", m)) end
        allRow(mags, L.sample(magType) or gun, rows)
        if gun:isContainsClip() then
            local sample = L.sample(magType)
            local r = newRow("eject", sample or gun, s.eject)
            r.red = true
            table.insert(rows, r)
        end
    else
        local r = newRow("self", gun, gun:getDisplayName())
        r.m = gun
        r.key = gun:getAmmoType() and gun:getAmmoType():getItemKey() or nil
        table.insert(rows, jam and 2 or 1, r)
    end
    if gun:haveChamber() and not jam then
        local at = gun:getAmmoType()
        local shells = at and at:getItemKey() == SHELLS
        table.insert(rows, newRow("rack", gun, shells and s.pump or s.bolt))
    end
    return rows, gun
end

--- The block of rounds under the line: for the row's rounds (no gun in hand: as the
--- chosen magazine's; a row of no magazine: as it was).
local strips = {}
local function stripFor(key, cap)
    local b = strips[key]
    if not b then
        local sample = L.sample(key)
        local cat = sample and T.category[T.categoryOf(sample)] or T.category.ammo or T.category.misc
        local tex = sample and sample:getTex() or nil
        b = {key = key, tex = tex, ink = inkOf(tex), cat = cat, edge = T.mix(cat, WHITE, 0.3), n = 0, lit = 0}
        strips[key] = b
    end
    b.cap = cap
    return b
end

local function readStrip(player)
    local b = M.strip
    if not b then return end
    b.n = player:getInventory():getItemCountRecurse(b.key)
    b.lit = M.reserveLit(b.n, b.cap)
end

local function chooseStrip(player)
    local r = M.rows[M.sel]
    local gun = M.gun
    local b = M.strip
    if gun then
        local at = gun:getAmmoType()
        if at then b = stripFor(at:getItemKey(), gun:getMaxAmmo()) end
    elseif r and r.key then
        b = stripFor(r.key, r.m:getMaxAmmo())
    end
    if b ~= M.strip then
        M.strip = b
        readStrip(player)
    end
end

--- Are there rounds for any of them? (Rounds of `mags`, the first of a type asked: they
--- lie by type.)
local function anyRounds(player, mags)
    local inv = player:getInventory()
    local last
    for _, m in ipairs(mags) do
        local at = m:getAmmoType()
        local key = at and at:getItemKey()
        if key and key ~= last and not (K.is(m) and m:getCurrentAmmoCount() >= m:getMaxAmmo()) then
            if inv:getItemCountRecurse(key) > 0 then return true end
            last = key
        end
    end
    return false
end

--- What a gun holds: the magazine and the round the rack took out of it for the chamber
--- (a full magazine of 30 goes in as 29 + 1: the scale lost a part - the author, 2026-11-04).
local function inGun(gun)
    return gun:getCurrentAmmoCount() + (gun:isRoundChambered() and 1 or 0)
end

local function readRows(player)
    for _, r in ipairs(M.rows) do
        if r.m then
            r.n, r.cap = r.m:getCurrentAmmoCount(), r.m:getMaxAmmo()
            r.known = r.kind == "self" or K.is(r.m)
            r.lit = M.levelOf(r.kind == "self" and inGun(r.m) or r.n, r.cap)
        elseif r.kind == "all" then
            r.able = anyRounds(player, r.mags)
        end
    end
    local gun = M.gun
    if gun then
        M.gunLit = M.levelOf(inGun(gun), gun:getMaxAmmo())
        M.gunNone = (gun:getMagazineType() ~= nil and gun:getMagazineType() ~= "") and not gun:isContainsClip()
        M.chamber = gun:haveChamber() or false
        M.chamberOn = M.chamber and gun:isRoundChambered()
        M.jam = gun:isJammed()
        M.canRack = ISReloadWeaponAction.canRack(gun)
    end
    readStrip(player)
end

--- How wide the hints can get in this language: the plate takes that, whatever is chosen
--- (the mockup: a plate of one width for each language).
local function hintsWide()
    if Z.wide then return Z.wide end
    local s = strings()
    local function pair(key, label)
        return T.measure(T.fontTile, key) + 10 + 6 + T.measure(T.fontText, label)
    end
    local lmb = 0
    for _, l in ipairs({s.swap, s.insert, s.load, s.use}) do lmb = math.max(lmb, pair(s.lmb, l)) end
    Z.wide = 2 * Z.L + pair(s.wheel, s.pick) + Z.HINT_GAP + lmb + Z.HINT_GAP
        + math.max(pair(s.rmb, s.load), pair(s.rmb2, s.unload))
    return Z.wide
end
M.hintsWide = hintsWide

--- The plate's width (once at opening: it stays while the rows change and scroll) and
--- the rows' names cut to it.
local function fitRows(wasW)
    local W = wasW
    if not W then
        local need = 0
        for _, r in ipairs(M.rows) do
            need = math.max(need, Z.TX + math.floor(Z.GROW_CELL / 2) + T.measure(Z.big, r.name) + Z.L + 1
                + (r.m and (Z.P16 + Z.SCW) or 0))
        end
        W = math.max(hintsWide(), math.min(Z.MAXW, math.max(Z.MINW, need)))
        M.W = W
    end
    for _, r in ipairs(M.rows) do
        local nx = Z.TX + math.floor(Z.GROW_CELL / 2)
        local room = W - nx - Z.L - (r.m and (Z.P16 + Z.SCW) or 0)
        r.fit, r.fitBig = T.fit(r.name, T.fontText, room), T.fit(r.name, Z.big, room)
    end
end

--- Rows anew (on opening, after an action, a magazine come or gone); the choice stays
--- on its row, or where it was. False: nothing to show.
function M.build(player, keepW)
    local rows, gun = M.rowsOf(player)
    if #rows == 0 then return false end
    local was = M.rows[M.sel]
    local wasItem, wasKind = was and was.item, was and was.kind
    local oldGrow = M.rows
    M.rows, M.gun = rows, gun
    local sel = math.min(M.sel, #rows)
    if wasItem then
        for i, r in ipairs(rows) do
            if r.item == wasItem and r.kind == wasKind then sel = i break end
        end
    end
    M.sel = sel
    for i, r in ipairs(rows) do
        local o = oldGrow[i]
        r.grow = i == sel and 1 or 0
        r.h = Z.ROW + Z.GROW_H * r.grow
        if o and o.item == r.item and o.kind == r.kind then r.grow, r.h = o.grow, o.h end
    end
    local s = strings()
    if gun then
        M.title, M.tex = gun:getDisplayName(), gun:getTex()
        M.ink, M.sub = inkOf(M.tex), nil
    else
        M.title, M.sub = s.noGun, s.magsRounds
        M.tex, M.ink = nil, nil
    end
    fitRows(keepW and M.W or nil)
    chooseStrip(player)
    readRows(player)
    M.magCount = M.countMags(player)
    return true
end

--- What says a rebuild is due: the magazines carried, what is in the gun.
function M.countMags(player)
    local gun = M.gun
    if gun then
        local n = 0
        local t = gun:getMagazineType()
        if t and t ~= "" then n = player:getInventory():getAllTypeRecurse(t):size() end
        return n * 4 + (gun:isContainsClip() and 1 or 0) + (gun:isJammed() and 2 or 0)
    end
    local n = 0
    for ft in pairs(L.index().mag) do n = n + player:getInventory():getAllTypeRecurse(ft):size() end
    return n
end

-- May it open? ----------------------------------------------------------------------------

--- Is what it started still queued? (Rounds brought from a bag go first.)
function M.jobQueued(player)
    local q = queueOf(player)
    if not q or not M.job then return false end
    for i = 1, #q do
        local field = JOB[q[i].Type or ""]
        if field and q[i][field] == M.job then return true end
    end
    return false
end

--- This part of the mod on, and this player's keyboard? (A gamepad: the game's round menu.)
function M.on()
    return not M.failed and T.on("rmenu") and not (JoypadState and JoypadState.players and JoypadState.players[1])
end

--- The rounds hidden while this menu is the way to see them: the module on, no error, the
--- keyboard (QA 2026-10-31: on a gamepad or after an error the game's round menu is back,
--- and with it the numbers). Each frame, a change only now and then.
function M.syncHide()
    local on = M.on() == true
    if on == K.hide then return end
    K.hide = on
    if knoxHideRounds then pcall(knoxHideRounds, on) end
end

--- The world, with nothing of ours or the game's over it.
local function inWorld()
    if KnoxCompat and KnoxCompat.windowOpen() then return false end
    if MainScreen and MainScreen.instance and MainScreen.instance:getIsVisible() then return false end
    return true
end

local function canHold(player)
    if not player or player:isDead() then return false end
    local sc = UIManager.getSpeedControls and UIManager.getSpeedControls()
    if sc and sc:getCurrentGameSpeed() == 0 then return false end
    if getCell():getDrag(0) then return false end
    if ISMouseDrag and ISMouseDrag.dragging then return false end
    if KnoxCrosshair and KnoxCrosshair.visible then return false end   -- (R there: take all)
    if not inWorld() then return false end
    local q = queueOf(player)
    local a = q and q[1]
    if a and not ITS_OWN[a.Type or ""] and not M.jobQueued(player) then return false end
    return true
end

-- Input -----------------------------------------------------------------------------------

M.catch = nil      -- the element over the whole screen

local function release()
    if knoxSetRMenuOpen then pcall(knoxSetRMenuOpen, false) end
    if M.catch then M.catch:setVisible(false) end
end

--- Close it: let go of the mouse now, fold away.
function M.close()
    if M.state ~= "open" then return end
    M.state = "fold"
    M.foldMs = getTimestampMs()
    M.tried = true   -- (closed by something else with R still down: not again until it is let go)
    release()
end

--- At once, nothing left (dead, an error, back to the main menu).
function M.abort()
    release()
    M.state, M.armed, M.armedItem, M.job, M.heldRack = nil, nil, nil, nil, nil
end

--- The element over the whole screen: it takes the clicks and the wheel while the menu is open.
KnoxRMenuCatch = ISUIElement:derive("KnoxRMenuCatch")
function KnoxRMenuCatch:new()
    local o = ISUIElement:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    setmetatable(o, self)
    self.__index = self
    return o
end
-- (anything amiss in them: the game's round menu back, the mouse let go - QA 2026-10-31)
local function guarded(fn, a)
    local ok, err = pcall(fn, a)
    if not ok then M.fail(err) end
    return true
end
function KnoxRMenuCatch:onMouseDown() return guarded(M.lmb) end
function KnoxRMenuCatch:onMouseUp() return true end
function KnoxRMenuCatch:onMouseUpOutside() return true end
function KnoxRMenuCatch:onRightMouseDown() return guarded(M.rmb) end
function KnoxRMenuCatch:onRightMouseUp() return true end
function KnoxRMenuCatch:onRightMouseUpOutside() return true end
function KnoxRMenuCatch:onMiddleMouseDown() return true end
function KnoxRMenuCatch:onMiddleMouseUp() return true end
function KnoxRMenuCatch:onMouseWheel(del) return guarded(M.wheel, del) end

--- Open it for the player, held key `key`. False: nothing to show.
function M.open(player, key)
    if M.state == "open" then return true end
    sizes()
    M.player, M.key = player, key
    M.rows, M.sel, M.strip = {}, 1, nil
    if not M.build(player, false) then return false end
    local now = getTimestampMs()
    M.state, M.openMs, M.lastMs = "open", now, now
    M.refreshMs, M.recountMs = now, now
    M.alpha, M.hiA, M.scroll, M.hiY, M.hiH = 0, 0, 0, 0, 0
    M.hintsMs, M.hintKey2, M.hintLabel2 = nil, nil, nil
    M.wasBusy = isBusy(player)
    -- (the top stays where it is, whatever happens to the rows)
    local rowsH = math.min(#M.rows, MAX_ROWS) * Z.ROW + Z.GROW_H + (#M.rows > MAX_ROWS and 2 * Z.STRIP or 0)
    local H = Z.GAP + Z.PH + Z.GAP + rowsH + Z.GAP + 1 + Z.GAP + Z.ROUNDS + Z.GAP + 1 + Z.GAP + Z.KH + Z.GAP
    M.ox, M.oy = Z.LEFT, math.floor((getCore():getScreenHeight() - H) / 2)
    if not M.catch then
        M.catch = KnoxRMenuCatch:new()
        M.catch:initialise()
        M.catch:addToUIManager()
        M.catch:setAlwaysOnTop(true)
    end
    M.catch:setWidth(getCore():getScreenWidth())
    M.catch:setHeight(getCore():getScreenHeight())
    M.catch:setVisible(true)
    M.catch:bringToTop()
    if M.layer then M.layer:bringToTop() end
    if knoxSetRMenuOpen then knoxSetRMenuOpen(true) end
    M.heldRack = nil   -- (held: the menu, not the game's stop and rack - even if something else closes it; QA 2026-10-31)
    return true
end

function M.current()
    return M.rows[M.sel]
end

function M.wheel(del)
    if M.state ~= "open" then return end
    local n = #M.rows
    if n == 0 then return end
    M.sel = (M.sel - 1 + (del > 0 and 1 or -1) + n) % n + 1
    chooseStrip(M.player)
end

--- Whatever of its own is under way gives way to what was asked now.
local function clearBusy(player)
    if isBusy(player) then ISTimedActionQueue.clear(player) end
end

local function jobAction(player)
    local q = queueOf(player)
    return q and q[1] or nil
end

--- The action under way, when it is loading or unloading `item`; and which.
local function jobOn(player, item)
    local a = jobAction(player)
    local field = a and JOB[a.Type or ""]
    if field and a[field] == item then return a, JOB_OUT[a.Type] == true end
    return nil, false
end

--- Load a magazine, or the gun that takes rounds itself. (The game's menus' way: as many
--- rounds as go in brought to the main inventory, then the action.)
function M.load(item)
    local player = M.player
    if not player or not item then return false end
    local a, out = jobOn(player, item)
    if a and not out then return true end   -- (already at it)
    local cap, n = item:getMaxAmmo(), item:getCurrentAmmoCount()
    local at = item:getAmmoType()
    local key = at and at:getItemKey()
    if not key or player:getInventory():getItemCountRecurse(key) <= 0 then return false end
    local isGun = instanceof(item, "HandWeapon")
    if isGun and item:isJammed() then return false end
    -- (one not known that is full: one round tried, the try is how it is found out - nothing
    -- done at all would tell it free; QA 2026-10-31. Known: from the first round in, KnoxMagKnown.)
    local blind = not isGun and n >= cap and not K.is(item)
    if n >= cap and not blind then return false end
    clearBusy(player)
    if not isGun then ISInventoryPaneContextMenu.transferIfNeeded(player, item) end
    local count = ISInventoryPaneContextMenu.transferBullets(player, key, blind and 0 or n, blind and 1 or cap)
    if count <= 0 then return false end
    M.job = item
    if isGun then
        ISTimedActionQueue.add(ISReloadWeaponAction:new(player, item))
    else
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, item, count))
    end
    return true
end

--- Unload a magazine, or the gun that takes rounds itself.
function M.unload(item)
    local player = M.player
    if not player or not item then return false end
    local a, out = jobOn(player, item)
    if a and out then return true end
    local isGun = instanceof(item, "HandWeapon")
    -- (one not known that is empty: unloaded all the same, the game's action finds it so)
    if item:getCurrentAmmoCount() <= 0 and (isGun or K.is(item)) then return false end
    clearBusy(player)
    M.job = item
    if isGun then
        ISTimedActionQueue.add(ISUnloadBulletsFromFirearm:new(player, item))
    else
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
        ISTimedActionQueue.add(ISUnloadBulletsFromMagazine:new(player, item))
    end
    return true
end

--- All of them, one after another, fuller first (the author, 2026-11-04): the rounds they
--- take brought once, then each magazine as M.load. Those the rounds don't reach are left.
--- One not known that is full: one round tried, as M.load.
function M.loadAll(mags)
    local player = M.player
    local inv = player:getInventory()
    local have, bring, plan = {}, {}, {}
    for _, mag in ipairs(mags) do
        local n, cap = mag:getCurrentAmmoCount(), mag:getMaxAmmo()
        local at = mag:getAmmoType()
        local key = at and at:getItemKey()
        if key and mag:getContainer() and not (K.is(mag) and n >= cap) then
            if have[key] == nil then have[key] = inv:getItemCountRecurse(key) end
            if have[key] > 0 then
                local count = n < cap and math.min(cap - n, have[key]) or 1
                if n < cap then have[key] = have[key] - count end
                bring[key] = n < cap and (bring[key] or 0) + count or math.max(bring[key] or 0, 1)
                table.insert(plan, {mag = mag, count = count})
            end
        end
    end
    if #plan == 0 then return false end
    clearBusy(player)
    for key, count in pairs(bring) do
        ISInventoryPaneContextMenu.transferBullets(player, key, 0, count)
    end
    for _, p in ipairs(plan) do
        ISInventoryPaneContextMenu.transferIfNeeded(player, p.mag)
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, p.mag, p.count))
    end
    M.job = plan[#plan].mag   -- (the menu may come up over the whole of it: M.jobQueued)
    return true
end

--- The left button: what the chosen row is for.
function M.lmb()
    if M.state ~= "open" then return end
    local r, player, gun = M.current(), M.player, M.gun
    if not r then return end
    if r.kind == "bag" then return end
    if r.kind == "self" then
        if M.canLoad(r) then M.load(r.m) end
        return
    end
    if r.kind == "all" then
        if r.able then M.loadAll(r.mags) end
    elseif r.kind == "box" then
        clearBusy(player)
        L.openBox(player, r.item)
    elseif r.kind == "swap" or r.kind == "insert" then
        clearBusy(player)
        L.insertMagazine(player, gun, r.m)
    elseif r.kind == "eject" then
        clearBusy(player)
        ISInventoryPaneContextMenu.onEjectMagazine(player, gun)
    elseif r.kind == "rack" or r.kind == "unjam" then
        if not ISReloadWeaponAction.canRack(gun) then return end
        clearBusy(player)
        ISInventoryPaneContextMenu.onRackGun(player, gun)
    end
    M.wasBusy = true   -- (the rows anew when it is over)
end

--- The right button: once loads the chosen magazine a moment later, twice unloads it.
function M.rmb()
    if M.state ~= "open" then return end
    local r = M.current()
    if M.armed then
        local item = M.armedItem
        M.armed, M.armedItem = nil, nil
        if r and r.m == item then
            M.unload(item)
            M.wasBusy = true
            return
        end
        -- (another row chosen between the two: the first was one click, load it - QA 2026-10-31)
        M.load(item)
        M.wasBusy = true
    end
    if not r or not r.m then return end
    M.armed, M.armedItem = getTimestampMs(), r.m
end

--- Its time up: one click. (Also after R is let go: it was asked for.)
local function fireArmed(now)
    if not M.armed or now - M.armed < DOUBLE_MS then return end
    local item = M.armedItem
    M.armed, M.armedItem = nil, nil
    local player = M.player
    if player and not player:isDead() and item then
        M.load(item)
        M.wasBusy = true
    end
end

--- Can this row be loaded now? (Rounds carried and room; how much is in one not known
--- is not given away by a hint going out.)
function M.canLoad(r)
    if not r or not r.m then return false end
    if r.kind == "self" and M.jam then return false end
    if r.known and r.n >= r.cap then return false end
    local b = M.strip
    if b and b.n > 0 then return true end
    local a, out = jobOn(M.player, r.m)
    return a ~= nil and not out
end

-- The R key ------------------------------------------------------------------------------

local function isReload(key)
    return KeybindId ~= nil and getCore():isKey(KeybindId.RELOAD_WEAPON, key)
end

M.pressMs = nil    -- when the key went down
M.tried = false    -- this press found nothing to show
M.heldRack = nil   -- the gun the game would have stopped loading and racked on this press

local FRM = ISFirearmRadialMenu
if not M.wrapped then
    M.wrapped = true
    -- (the game hooks these three up at OnGameStart, reading them off the table then)
    local onPressed, onRepeat, onReleased = FRM.onKeyPressed, FRM.onKeyRepeat, FRM.onKeyReleased

    -- R pressed while loading: the game stops it and racks at once (QA 2026-10-31: R held
    -- again to see the menu over a shotgun being loaded from it cut the loading short). Put
    -- off till R is let go: a short press is the game's, as ever; held, the menu comes up
    -- over the loading and it goes on. (The game's "instant" round menu: as the game, at
    -- once - every press opens the menu there, R would never stop loading.)
    local pressReload = ISReloadWeaponAction.OnPressReloadButton
    if pressReload then
        Events.OnPressReloadButton.Remove(pressReload)
        Events.OnPressReloadButton.Add(function(player, gun)
            if M.on() and player == getSpecificPlayer(0) and player:getVariableBoolean("isLoading")
                    and not getCore():getOptionReloadRadialInstant() then
                M.heldRack = gun
                return
            end
            pressReload(player, gun)
        end)
    end

    function FRM.onKeyPressed(key)
        if isReload(key) and M.on() then
            M.pressMs, M.tried = getTimestampMs(), false
        end
        return onPressed(key)   -- (the game's reload on a short press hangs on it)
    end

    function FRM.onKeyRepeat(key)
        if not isReload(key) or not M.on() then return onRepeat(key) end
        if M.state == "open" or M.tried or not M.pressMs then return end
        local delay = getCore():getOptionReloadRadialInstant() and 0 or HOLD_MS
        if getTimestampMs() - M.pressMs < delay then return end
        local player = getSpecificPlayer(0)
        if not canHold(player) then return end
        local ok, opened = pcall(M.open, player, key)
        if not ok then
            M.fail(opened)
        elseif not opened then
            M.tried = true
        end
    end

    function FRM.onKeyReleased(key)
        if isReload(key) and M.on() then
            M.pressMs = nil
            local rack = M.heldRack
            M.heldRack = nil
            if M.state == "open" then
                M.close()
                return   -- (let go: closed, nothing done)
            end
            if M.state == "fold" then return end
            local player = getSpecificPlayer(0)
            if rack and pressReload and player and not player:isDead() then pressReload(player, rack) end
        end
        return onReleased(key)
    end

end

--- Anything amiss: the game's round menu is back, said once.
function M.fail(err)
    M.failed = true
    M.abort()
    M.syncHide()
    print("[Knox] the menu on R is off after an error, the game's is back: " .. tostring(err))
end

-- Drawing ---------------------------------------------------------------------------------

local band, labelOpts = {0, 0, 0, 0}, {}
local function label(ui, s, x, y, w, h, c, font, a)
    band[1], band[2], band[3], band[4] = x, y, w, h
    labelOpts.font, labelOpts.a = font, a
    return T.label(ui, s, band, c, labelOpts)
end

--- The five parts: `lit` of them, in sand or, two and less, in red; none lit: all faint red.
--- Not known: a thin line in their place.
local function drawScale(ui, x, y, lit, known, a)
    local C = T.color
    if not known then
        T.rect(ui, x, y + math.floor(Z.SH / 2), Z.SCW, 1, C.tileEdge, a)
        return
    end
    local low = lit <= 2
    for i = 0, 4 do
        local px = x + i * (Z.SW + Z.SG)
        if i < lit then
            T.rect(ui, px, y, Z.SW, Z.SH, low and RED or C.accent, a)
        elseif lit == 0 then
            T.rect(ui, px, y, Z.SW, Z.SH, RED, 0.45 * a)
        else
            T.rect(ui, px, y, Z.SW, Z.SH, C.tileEdge, a)
        end
    end
end

local chamberTex = {}
--- The chamber: a part of the scale with a pointed end, a round lying on its side.
local function drawChamber(ui, x, y, on, jam, a)
    local h = math.max(4, math.min(12, Z.SH))
    local tex = chamberTex[h]
    if tex == nil then
        tex = getTexture("media/ui/knox_chamber_" .. h .. ".png") or false
        chamberTex[h] = tex
    end
    if not tex then return end
    local c = jam and RED or (on and T.color.accent or T.color.tileEdge)
    ui:drawTexture(tex, x, y, a, c.r, c.g, c.b)
end

local palmTex = nil
local function drawHead(ui, ox, oy, W, a)
    local C = T.color
    local hx, hy, hw, ph = ox + Z.GAP, oy + Z.GAP, W - 2 * Z.GAP, Z.PH
    T.rect(ui, hx, hy, hw, ph, C.header, a)
    T.tileFrame(ui, hx, hy, hw, ph, C.tileFrame, a)
    local cx, cy, cell = hx + Z.M, hy + Z.M, ph - 2 * Z.M
    T.rect(ui, cx, cy, cell, cell, C.cell, a)
    if M.tex then
        local is = math.floor(cell * 0.8 + 0.5)
        picture(ui, M.tex, M.ink, cx + math.floor((cell - is) / 2), cy + math.floor((cell - is) / 2), is, a)
    else
        if palmTex == nil then palmTex = getTexture("media/ui/knox_hand_left.png") or false end
        if palmTex then
            local is = cell - 2 * Z.P5
            picture(ui, palmTex, nil, cx + Z.P5, cy + Z.P5, is, a, C.tileEdge)
        end
    end
    T.tileFrame(ui, cx, cy, cell, cell, C.tileEdge, a)
    local tx = cx + cell + Z.P10
    local tw = hx + hw - Z.M - tx
    local cap = T.capH(T.fontHeader)
    local title = T.fit(M.title, T.fontHeader, tw)
    local mid = cy + cell / 2
    if M.sub then
        -- the name and what is under it, about the picture's middle
        local top = math.floor(mid - (cap + Z.P20) / 2)
        label(ui, title, tx, top, tw, cap, C.bright, T.fontHeader, a)
        local subCap = T.capH(T.fontTile)
        label(ui, T.fit(M.sub, T.fontTile, tw), tx, top + cap + Z.P20 - subCap, tw, subCap, C.dim, T.fontTile, a)
        return
    end
    local top = math.floor(mid - (cap + Z.P9 + Z.SH) / 2)
    label(ui, title, tx, top, tw, cap, C.bright, T.fontHeader, a)
    local sy = top + cap + Z.P9
    drawScale(ui, tx, sy, M.gunLit, not M.gunNone, a)
    if M.chamber then drawChamber(ui, tx + Z.SCW + Z.P8, sy, M.chamberOn, M.jam, a) end
end

local function drawRow(ui, r, ox, y, W, chosen, a)
    local C = T.color
    local h, g = r.h, r.grow
    if r.prog and r.prog > 0 then
        local px0 = chosen and 3 or 1
        local pw = math.floor((W - 1 - px0) * math.min(1, r.prog) + 0.5)
        if r.out then
            T.rect(ui, ox + W - 1 - pw, y, pw, h, C.bad, 0.3 * a)
        else
            T.rect(ui, ox + px0, y, pw, h, C.accent, 0.22 * a)
        end
    end
    -- its tile, the chosen one grown
    local cs = Z.CELL + math.floor(Z.GROW_CELL * g + 0.5)
    local is = Z.IC + math.floor(Z.GROW_CELL * g + 0.5)
    local tx0 = ox + Z.L + math.floor((Z.CELL - cs) / 2)
    local ty0 = y + math.floor((h - cs) / 2)
    T.rect(ui, tx0, ty0, cs, cs, r.cat, a)
    picture(ui, r.tex, r.ink, tx0 + math.floor((cs - is) / 2), ty0 + math.floor((cs - is) / 2), is, a)
    T.border(ui, tx0, ty0, cs, cs, r.edge, a)
    -- its name, a size up when chosen
    local nx = ox + Z.TX + math.floor(Z.GROW_CELL / 2 * g + 0.5)
    local col = r.red and RED or (chosen and C.bright or C.text)
    local big = g > 0.5
    label(ui, big and r.fitBig or r.fit, nx, y, W - (nx - ox), h, col, big and Z.big or T.fontText, a)
    if r.m then
        drawScale(ui, ox + W - Z.L - Z.SCW, y + math.floor((h - Z.SH) / 2 + 0.5), r.lit, r.known, a)
    end
end

local function chevron(ui, x, y, s, up, c, a)
    for i = 0, s do
        local yy = up and (y + i) or (y + s - i)
        ui:drawRect(x - i, yy, 2, 2, a, c.r, c.g, c.b)
        ui:drawRect(x + i, yy, 2, 2, a, c.r, c.g, c.b)
    end
end

local function scrollStrip(ui, ox, y, W, up, on, a)
    T.rect(ui, ox + 1, y, W - 2, Z.STRIP, T.color.header, a)
    chevron(ui, ox + math.floor(W / 2) - 1, y + math.floor(Z.STRIP / 2) - 3, 4, up, T.color.text, (on and 1 or 0.3) * a)
end

-- the hints: the keys and words now, the ones before while they change
local shown = {key3 = nil, lmb = nil, rmb = nil, noAct = false, noRmb = false}
local before = {key3 = nil, lmb = nil, rmb = nil, noAct = false, noRmb = false}

local function chooseHints(now)
    local s = strings()
    local r = M.current()
    local lmb, noAct = s.use, false
    if r then
        if r.kind == "swap" then lmb = s.swap
        elseif r.kind == "insert" then lmb = s.insert
        elseif r.kind == "bag" then lmb, noAct = s.swap, true
        elseif r.kind == "self" then lmb, noAct = s.load, not M.canLoad(r)
        elseif r.kind == "all" then lmb, noAct = s.load, not r.able
        elseif r.kind == "rack" or r.kind == "unjam" then noAct = not M.canRack
        end
    end
    local key3, rmb, noRmb = s.rmb, s.load, not M.canLoad(r)
    if r and r.m and (r.kind == "self" or (r.known and r.n >= r.cap)) then
        key3, rmb = s.rmb2, s.unload
        noRmb = r.kind == "self" and r.n <= 0
    end
    if shown.lmb ~= lmb or shown.key3 ~= key3 or shown.rmb ~= rmb or shown.noAct ~= noAct or shown.noRmb ~= noRmb then
        if shown.lmb then
            before.key3, before.lmb, before.rmb, before.noAct, before.noRmb = shown.key3, shown.lmb, shown.rmb, shown.noAct, shown.noRmb
            M.hintsMs = now
        end
        shown.key3, shown.lmb, shown.rmb, shown.noAct, shown.noRmb = key3, lmb, rmb, noAct, noRmb
    end
end
M.hints = shown

local function drawHints(ui, x, y, h, a)
    local s = strings()
    x = T.keyHint(ui, x, y, s.wheel, s.pick, Z.KH, a) + Z.HINT_GAP
    x = T.keyHint(ui, x, y, s.lmb, h.lmb, Z.KH, h.noAct and 0.5 * a or a) + Z.HINT_GAP
    T.keyHint(ui, x, y, h.key3, h.rmb, Z.KH, h.noRmb and 0.5 * a or a)
end

local function ease(k)
    if k < 0.5 then return 2 * k * k end
    local v = -2 * k + 2
    return 1 - v * v / 2
end

--- The heights of the rows, the plate's, where the list and the foot are.
local function layout(dt)
    local kg = T.animOn() and (1 - math.exp(-dt / 60)) or 1
    local y, total = 0, 0
    for i, r in ipairs(M.rows) do
        local to = i == M.sel and 1 or 0
        r.grow = r.grow + (to - r.grow) * kg
        if math.abs(to - r.grow) < 0.01 then r.grow = to end
        r.h = Z.ROW + math.floor(Z.GROW_H * r.grow + 0.5)
        r.y = y
        y = y + r.h
    end
    total = y
    local clipped = #M.rows > MAX_ROWS
    local viewH = clipped and (MAX_ROWS * Z.ROW + Z.GROW_H) or total
    local regionH = clipped and (viewH + 2 * Z.STRIP) or viewH
    local listY = Z.GAP + Z.PH + Z.GAP
    M.clipped, M.viewH, M.regionH, M.listY, M.total = clipped, viewH, regionH, listY, total
    M.viewY = listY + (clipped and Z.STRIP or 0)
    M.footY = listY + regionH + Z.GAP + 1 + Z.GAP + Z.ROUNDS + Z.GAP
    M.H = M.footY + 1 + Z.GAP + Z.KH + Z.GAP
end

local function foldPlate(ui, k, m)
    local C = T.color
    local W, H = M.W, M.H or 0
    local sw, sh = W * 0.3, H * 0.3
    local sx, sy = M.ox + (W - sw) / 2, M.oy + (H - sh) / 2
    local x = math.floor(sx + (M.ox - sx) * k)
    local y = math.floor(sy + (M.oy - sy) * k)
    local fw, fh = math.floor(sw + (W - sw) * k), math.floor(sh + (H - sh) * k)
    local a = (0.15 + 0.8 * k) * (m or 1)
    T.rect(ui, x, y, fw, fh, C.window, a)
    T.rect(ui, x, y, fw, math.min(fh, math.floor((Z.GAP + Z.PH + Z.GAP) * k + 0.5)), C.header, a)
    T.border(ui, x, y, fw, fh, C.accent, a)
end

local function draw(ui, now)
    local C = T.color
    local ox, oy, W, H = M.ox, M.oy, M.W, M.H
    local a = M.alpha
    -- the plate as the item tooltip's and the crosshair panel's
    T.rect(ui, ox + 4, oy + 6, W, H, BLACK, 0.45)
    T.rect(ui, ox, oy, W, H, C.window, 0.97)
    T.border(ui, ox, oy, W, H, EDGE, 1)
    drawHead(ui, ox, oy, W, a)
    -- the list: the highlight glides under it
    if M.clipped then ui:setStencilRect(ox, oy + M.viewY, W, M.viewH) end
    local ly = oy + M.viewY - math.floor(M.scroll + 0.5)
    if M.hiA > 0.02 then
        local by, bh = ly + math.floor(M.hiY + 0.5), math.floor(M.hiH + 0.5)
        T.rect(ui, ox + 1, by, W - 2, bh, HOVER, M.hiA * a)
        T.rect(ui, ox + 1, by, 2, bh, C.accent, M.hiA * a)
    end
    for i, r in ipairs(M.rows) do
        local ry = ly + r.y
        if ry + r.h > oy + M.viewY and ry < oy + M.viewY + M.viewH then
            drawRow(ui, r, ox, ry, W, i == M.sel, a)
        end
    end
    if M.clipped then
        ui:clearStencilRect()
        scrollStrip(ui, ox, oy + M.listY, W, true, M.scroll > 1, a)
        scrollStrip(ui, ox, oy + M.listY + M.regionH - Z.STRIP, W, false, M.scroll < M.total - M.viewH - 1, a)
    end
    -- the rounds, under a thin line
    local b = M.strip
    local sy = oy + M.footY - Z.GAP - Z.ROUNDS
    T.rect(ui, ox + Z.L, sy - Z.GAP - 1, W - 2 * Z.L, 1, C.border, a)
    if b then
        local tx0, ty0 = ox + Z.L, sy + math.floor((Z.ROUNDS - Z.CELL) / 2)
        T.rect(ui, tx0, ty0, Z.CELL, Z.CELL, b.cat, a)
        picture(ui, b.tex, b.ink, tx0 + math.floor((Z.CELL - Z.IC) / 2), ty0 + math.floor((Z.CELL - Z.IC) / 2), Z.IC, a)
        T.border(ui, tx0, ty0, Z.CELL, Z.CELL, b.edge, a)
        label(ui, strings().rounds, ox + Z.TX, sy, W - Z.TX, Z.ROUNDS, C.text, T.fontText, a)
        drawScale(ui, ox + W - Z.L - Z.SCW, sy + math.floor((Z.ROUNDS - Z.SH) / 2 + 0.5), b.lit, true, a)
    end
    -- the keys, under a thin line
    T.rect(ui, ox + Z.L, oy + M.footY, W - 2 * Z.L, 1, C.border, a)
    local ky = oy + M.footY + 1 + Z.GAP
    local hk = M.hintsMs and math.min(1, (now - M.hintsMs) / HINT_MS) or 1
    if not T.animOn() then hk = 1 end
    if hk < 1 and before.lmb then
        ui:setStencilRect(ox, ky - 2, W, Z.KH + 4)
        if hk < 0.5 then
            local e = ease(hk * 2)
            drawHints(ui, ox + Z.L, ky - math.floor(e * 3 + 0.5), before, (1 - e) * a)
        else
            local e = ease(hk * 2 - 1)
            drawHints(ui, ox + Z.L, ky + math.floor((1 - e) * 4 + 0.5), shown, e * a)
        end
        ui:clearStencilRect()
    else
        drawHints(ui, ox + Z.L, ky, shown, a)
    end
end

--- The rows' fills: the action under way, on its row - the whole job, not one round.
local function readJob(player)
    local a = jobAction(player)
    local field = a and a.action and JOB[a.Type or ""]
    local item = field and a[field]
    for _, r in ipairs(M.rows) do
        if r.m and r.m == item and KnoxGrid.useDelta then
            local d = KnoxGrid.useDelta(a)
            local out = JOB_OUT[a.Type] == true
            r.prog, r.out = out and 1 - d or d, out
        else
            r.prog, r.out = nil, false
        end
    end
end

local function stillOpen(player)
    if not player or player:isDead() or not M.on() then return false end
    if M.key and not isKeyDown(M.key) then return false end
    local sc = UIManager.getSpeedControls and UIManager.getSpeedControls()
    if sc and sc:getCurrentGameSpeed() == 0 then return false end
    if not inWorld() then return false end
    return true
end

--- One frame of it, on its layer. (Closed and with nothing asked for: nothing at all.)
function M.frame(ui)
    local now = getTimestampMs()
    if M.armed then fireArmed(now) end
    local state = M.state
    if not state then return end
    if state == "open" and not stillOpen(M.player) then
        M.close()
        state = M.state
    end
    if state == "fold" then
        local t = math.min(1, T.anim((now - M.foldMs) / FOLD_MS))
        local k = (1 - t) * (1 - t)
        if k > 0.01 and M.H then foldPlate(ui, k) end
        if t >= 1 then M.state = nil end
        return
    end
    local player = M.player
    local dt = math.max(1, math.min(100, now - M.lastMs))
    M.lastMs = now
    -- the gun changed in hand, a magazine come or gone, an action over: the rows anew
    local busy = isBusy(player)
    local again = gunOf(player) ~= M.gun or (M.wasBusy and not busy)
    if not again and now - M.recountMs >= RECOUNT_MS then
        M.recountMs = now
        again = M.countMags(player) ~= M.magCount
    end
    M.wasBusy = busy
    if again then
        if not M.build(player, true) then
            M.close()
            return
        end
    elseif now - M.refreshMs >= REFRESH_MS then
        M.refreshMs = now
        readRows(player)
    end
    readJob(player)
    chooseHints(now)
    layout(dt)
    -- the highlight follows the row, the scroll keeps it in sight
    local k = T.animOn() and (1 - math.exp(-dt / 38)) or 1
    local r0 = M.current()
    if r0 then
        local target = M.scroll
        if M.clipped then
            if r0.y < target then target = r0.y end
            if r0.y + r0.h > target + M.viewH then target = r0.y + r0.h - M.viewH end
            target = math.max(0, math.min(M.total - M.viewH, target))
        else
            target = 0
        end
        M.scroll = M.scroll + (target - M.scroll) * k
        if M.hiA < 0.05 then M.hiY, M.hiH = r0.y, r0.h end
        M.hiY = M.hiY + (r0.y - M.hiY) * k
        M.hiH = M.hiH + (r0.h - M.hiH) * k
        M.hiA = M.hiA + (1 - M.hiA) * k
    end
    -- opening: the empty plate unfolds, then what is in it shows
    local ut = T.anim((now - M.openMs) / UNFOLD_MS)
    if ut < 1 then
        foldPlate(ui, 1 - (1 - ut) * (1 - ut))
        return
    end
    M.alpha = T.animOn() and math.min(1, (now - M.openMs - UNFOLD_MS) / SHOW_MS) or 1
    draw(ui, now)
    if M.alpha < 1 then foldPlate(ui, 1, 1 - M.alpha) end
end

-- The element it is drawn on: 0 x 0 at the screen's corner - never takes a click.
KnoxRMenuLayer = ISUIElement:derive("KnoxRMenuLayer")

function KnoxRMenuLayer:new()
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    return o
end

function KnoxRMenuLayer:render()
    M.syncHide()
    if not M.state and not M.armed then return end
    local ok, err = pcall(M.frame, self)
    if not ok then
        pcall(self.clearStencilRect, self)
        M.fail(err)
    end
end

-- The hidden rounds in the game's menus (the author, 2026-10-31): a number in "Insert N
-- bullets" or a magazine's line tells what is in it, so does an option missing for a
-- full or an empty one. With the menu on R on: words without numbers; one not known
-- offers both. (Their tooltips: KnoxTooltipStyle.)
local CM = ISInventoryPaneContextMenu
if CM and not M.menusWrapped then
    M.menusWrapped = true
    local doMagazineMenu, doReloadMenuForBullets, doBulletMenu = CM.doMagazineMenu, CM.doReloadMenuForBullets, CM.doBulletMenu
    local onLoadInMagazine = CM.onLoadBulletsInMagazine

    --- As many as go in, by what the character has.
    local function roundsFor(playerObj, mag)
        local key = mag:getAmmoType():getItemKey()
        local have = playerObj:getInventory():getItemCountRecurse(key)
        return have, math.min(have, mag:getMaxAmmo() - mag:getCurrentAmmoCount())
    end
    local function loadIt(playerObj, mag, count)
        -- (one not known that is full: one round tried, as the menu on R - QA 2026-10-31)
        if count <= 0 and not K.is(mag) then count = 1 end
        onLoadInMagazine(playerObj, mag, count)
    end
    local function may(mag, room)
        return not K.is(mag) or room
    end

    function CM.doMagazineMenu(playerObj, magazine, context)
        if not K.hide then return doMagazineMenu(playerObj, magazine, context) end
        local n, cap = magazine:getCurrentAmmoCount(), magazine:getMaxAmmo()
        if may(magazine, n < cap) then
            local have, count = roundsFor(playerObj, magazine)
            if have == 0 then
                local option = context:addOption(getText("ContextMenu_NoBullets", 0))
                option.notAvailable = true
            else
                context:addOption(getText("IGUI_Knox_RMenu_LoadMagazine"), playerObj, loadIt, magazine, count)
            end
        end
        if may(magazine, n > 0) then
            context:addOption(getText("ContextMenu_UnloadMagazine"), playerObj, CM.onUnloadBulletsFromMagazine, magazine)
        end
    end

    function CM.doReloadMenuForBullets(playerObj, bullet, context)
        if not K.hide then return doReloadMenuForBullets(playerObj, bullet, context) end
        local items = playerObj:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local ammoType = item:getAmmoType()
            local itemKey = ammoType and ammoType:getItemKey()
            if itemKey == bullet:getFullType() then
                if instanceof(item, "HandWeapon") then
                    if not item:getMagazineType() then CM.doBulletMenu(playerObj, item, context) end
                elseif may(item, item:getCurrentAmmoCount() < item:getMaxAmmo()) then
                    local _, count = roundsFor(playerObj, item)
                    local option = context:addOption(getText("IGUI_Knox_RMenu_LoadMagazine"), playerObj, loadIt, item, count)
                    local tooltip = CM.addToolTip()
                    tooltip.description = getText("ContextMenu_Magazine") .. ": " .. getText(item:getDisplayName()) .. "\n"
                        .. getText("ContextMenu_GunType") .. ": " .. item:getGunTypeString()
                    option.toolTip = tooltip
                end
            end
        end
    end

    -- the game's round menu: each slice's second line is the count - left out. (A gamepad's
    -- player sees it with the numbers, M.syncHide; this is for another mod bringing it up.)
    local fillMenu = FRM.fillMenu
    function FRM:fillMenu()
        fillMenu(self)
        if not K.hide then return end
        local menu = getPlayerRadialMenu(self.playerNum)
        for i, s in ipairs(menu.slices) do
            local first = s.text and string.match(s.text, "^([^\n]*)\n")
            if first then menu:setSliceText(i, first) end
        end
    end

    function CM.doBulletMenu(playerObj, weapon, context)
        if not K.hide then return doBulletMenu(playerObj, weapon, context) end
        local have = playerObj:getInventory():getItemCountRecurse(weapon:getAmmoType():getItemKey())
        local option = context:addOption(getText("IGUI_Knox_RMenu_LoadGun", weapon:getDisplayName()), playerObj, CM.onLoadBulletsIntoFirearm, weapon)
        if have <= 0 or weapon:getCurrentAmmoCount() >= weapon:getMaxAmmo() then option.notAvailable = true end
        if weapon:getCurrentAmmoCount() > 0 then
            context:addOption(getText("ContextMenu_UnloadRounds", weapon:getDisplayName()), playerObj, CM.onUnloadBulletsFromFirearm, weapon)
        end
    end
end

Events.OnGameStart.Add(function()
    -- (a world entered with it left on: the Java part outlives the Lua)
    if knoxSetRMenuOpen then pcall(knoxSetRMenuOpen, false) end
    K.hide = M.on() == true
    if knoxHideRounds then pcall(knoxHideRounds, K.hide) end
    if not T.active or M.layer then return end
    M.layer = KnoxRMenuLayer:new()
    M.layer:initialise()
    M.layer:addToUIManager()
    M.layer:setAlwaysOnTop(true)
end)

-- (the player gone, the world left: the mouse let go, whatever was open)
Events.OnPlayerDeath.Add(function(player)
    if M.player == player then M.abort() end
end)

Events.OnMainMenuEnter.Add(function() M.abort() end)

return KnoxRMenu
