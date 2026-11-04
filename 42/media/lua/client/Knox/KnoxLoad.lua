-- Magazines, rounds and guns (the author, 2026-10-30; the mockup
-- .claude/mockups/magazine_v2.html): the mouse on one of them lights up green, in
-- the grids, what fits it - a magazine: its rounds, their boxes and the guns it goes
-- in; a gun: its magazines (rounds and boxes when it takes them itself) and the
-- parts that go on it; rounds or a box: the magazines and guns they go in; a part:
-- the guns it goes on. A magazine or a gun also gets the battery panel's kin
-- (KnoxSlotPicker.wantLoad): what is in it, then what may go in - loading,
-- unloading, a magazine in, out or swapped, the gun racked - all by the game's own
-- actions, as its menus do them (a magazine is loaded in the main inventory; a
-- magazine goes in and out with the gun in hand - the game's menu takes it in hand,
-- and so it stays: the author's answer).
--
-- What fits what is read once, the first time a thing is hovered: the game keeps a
-- gun's magazine and its box of rounds, and a part's guns, only on the item, so one
-- of each kind is made and read (instanceItem; KnoxPerf "load: index").

require "Knox/KnoxTheme"
require "Knox/KnoxSlotPicker"
require "TimedActions/ISLoadBulletsInMagazine"

KnoxLoad = KnoxLoad or {}
local L = KnoxLoad
local T = KnoxTheme

local HOVER_MS = 120     -- (not for a mouse just passing over the grid: as a stack's kinds)
local GRACE_MS = 220     -- the mouse on its way from the thing to its panel
local REFRESH_MS = 500   -- what fits and what may go in, looked for again (containers change)
L.SHELLS = "Base.ShotgunShells"
-- the game's recipes that open a box of rounds (recipes_ammunition.txt)
local OPEN_BOX = {"OpenBoxOfBullets50", "OpenBoxOfBullets20", "OpenBoxOfShotgunShells"}

local EMPTY = {}
L.lit = EMPTY        -- item -> true: what fits the thing under the mouse (green in the grids)
L.picking = false    -- the mouse on a cell of the panel: the grids point at that one only (sand)
-- (the author, 2026-10-30: "появляются слишком резко" - they fade in and out)
L.shown = EMPTY      -- what the grids draw green: L.lit, or the last of it while it fades out
L.litA = 0           -- how strongly (0..1)
local FADE_MS = 200

--- Is the quick items' key held (Shift by default)?
function L.held()
    return KnoxControls ~= nil and KnoxControls.isHeld("quickItems")
end

-- The quick items' key switches (the author, 2026-10-30): the tooltip by default;
-- pressed over a thing with a panel - its panel; pressed again - the tooltip back.
L.panelFor = nil   -- the thing the key asked the panel for
local keyWas, keyMs, keyHit = false, -1, false
local KEY_GAP_MS = 250   -- not asked this long: the mouse has only just come onto a thing
--- Was the key pressed down just now? (the same answer to every caller in a frame)
function L.keyHit()
    local now = getTimestampMs()
    if now ~= keyMs then
        local down = L.held()
        -- (a key already held as the mouse comes onto the thing is no press over it: Shift+click
        -- along a row, a run past the hotbar - QA, 2026-11-04; the author 2026-10-30: "pressed over it")
        keyHit = down and not keyWas and now - keyMs < KEY_GAP_MS
        keyMs = now
        keyWas = down
    end
    return keyHit
end

-- What fits what -------------------------------------------------------------------

local idx = nil

local function none(s)
    if s == nil or s == "" then return nil end
    return s
end

local function ammoEntry(key)
    local a = idx.ammo[key]
    if not a then
        a = {mags = {}, guns = {}, boxes = {}}
        idx.ammo[key] = a
    end
    return a
end

--- One of each gun, magazine and part made and read (once; the samples kept for
--- the panel's pictures).
function L.index()
    if idx then return idx end
    local Pf = KnoxPerf
    local pt = Pf and Pf.detail and Pf.now()
    idx = {gun = {}, mag = {}, part = {}, ammo = {}, box = {}, sample = {}, anyPart = {}}
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local s = all:get(i)
        pcall(function()
            local ft = s:getFullName()
            if s:isRanged() then
                local it = instanceItem(ft)
                local at = it and instanceof(it, "HandWeapon") and it:getAmmoType()
                if at then
                    local g = {mag = none(it:getMagazineType()), ammo = at:getItemKey(), box = none(it:getAmmoBox())}
                    idx.gun[ft] = g
                    local a = ammoEntry(g.ammo)
                    a.guns[ft] = true
                    if g.box then
                        a.boxes[g.box] = true
                        idx.box[g.box] = g.ammo
                    end
                end
            elseif tostring(s:getItemType()) == "base:weaponpart" then
                local it = instanceItem(ft)
                if it and instanceof(it, "WeaponPart") then
                    local on = {}
                    local list = it:getMountOn()
                    local n = list and list:size() or 0
                    for k = 0, n - 1 do on[list:get(k)] = true end
                    idx.part[ft] = {type = it:getPartType(), on = n > 0 and on or false}
                    if n == 0 then idx.anyPart[ft] = true end
                end
            elseif s:getAmmoType() then
                local it = instanceItem(ft)
                if it and not instanceof(it, "HandWeapon") and (it:getMaxAmmo() or 0) > 0 then
                    idx.mag[ft] = {ammo = s:getAmmoType():getItemKey(), guns = {}}
                    idx.sample[ft] = it
                end
            end
        end)
    end
    for gft, g in pairs(idx.gun) do
        local m = g.mag and idx.mag[g.mag]
        if m then m.guns[gft] = true end
    end
    for mft, m in pairs(idx.mag) do ammoEntry(m.ammo).mags[mft] = true end
    if pt then Pf.part("load: index", pt) end
    return idx
end

--- What the item is here: "gun", "mag", "ammo", "box", "part", or nil.
function L.kindOf(ft)
    local x = L.index()
    if x.gun[ft] then return "gun" end
    if x.mag[ft] then return "mag" end
    if x.ammo[ft] then return "ammo" end
    if x.box[ft] then return "box" end
    if x.part[ft] then return "part" end
    return nil
end

local fitCache = {}
-- a flashlight, a radio on batteries (as KnoxGridView.batteryOf found it): its
-- batteries light up too, the panel open or not (the author, 2026-10-30)
local batteryFt = {}
local BATTERY_FITS = {["Base.Battery"] = true}
--- The types that fit a thing of type `ft`: type -> true (made once a type).
function L.fitsOf(ft)
    if batteryFt[ft] then return BATTERY_FITS end
    local f = fitCache[ft]
    if f then return f end
    local x = L.index()
    f = {}
    local function addAmmo(key)
        local a = x.ammo[key]
        if not a then return end
        f[key] = true
        for b in pairs(a.boxes) do f[b] = true end
    end
    local function intoOf(key)   -- the magazines and guns rounds of `key` go in
        local a = x.ammo[key]
        if not a then return end
        for m in pairs(a.mags) do f[m] = true end
        for g in pairs(a.guns) do f[g] = true end
    end
    local g, m, p = x.gun[ft], x.mag[ft], x.part[ft]
    if g then
        if g.mag then f[g.mag] = true else addAmmo(g.ammo) end
        for pft, part in pairs(x.part) do
            if not part.on or part.on[ft] then f[pft] = true end
        end
    elseif m then
        addAmmo(m.ammo)
        for gft in pairs(m.guns) do f[gft] = true end
    elseif x.ammo[ft] then
        intoOf(ft)
    elseif x.box[ft] then
        intoOf(x.box[ft])
    elseif p then
        if p.on then
            for gft in pairs(p.on) do f[gft] = true end
        else
            for gft in pairs(x.gun) do f[gft] = true end
        end
    end
    fitCache[ft] = f
    return f
end

--- Does `other` (type `oft`) fit `item` (type `ft`) right now? The types say so; a
--- part also needs its place on the gun free and itself whole (as the game's menu).
local function fitsNow(item, ft, other, oft)
    local x = idx
    local part = x.part[oft]
    if part and x.gun[ft] then
        return not other:isBroken() and item:getWeaponPart(part.type) == nil
    end
    part = x.part[ft]
    if part and x.gun[oft] then
        return not item:isBroken() and other:getWeaponPart(part.type) == nil
    end
    return true
end

-- What is lit up ------------------------------------------------------------------

local want = nil       -- the thing hovered this frame (L.hover)
local cur = nil        -- the thing the lit ones are for
local curFt = nil
local sinceMs, lastMs, litMs = 0, 0, 0

--- The thing under the mouse (a grid's tile, a hand or hotbar slot): asked for
--- every frame while it is hovered.
function L.hover(item)
    want = item
end

local function rebuild(now)
    litMs = now
    local fits = curFt and L.fitsOf(curFt)
    if not fits then
        L.lit = EMPTY
        return
    end
    local Pf = KnoxPerf
    local pt = Pf and Pf.detail and Pf.now()
    local lit, n = {}, 0
    local views = KnoxActions and KnoxActions.allViews() or {}
    for _, v in ipairs(views) do
        local placed = v.layout and v.layout.placed
        for _, e in ipairs(placed or EMPTY) do
            local it = e.item
            if it and it ~= cur and not e.ghost then
                local ft = it:getFullType()
                if fits[ft] and fitsNow(cur, curFt, it, ft) then
                    for _, x in ipairs(e.items) do lit[x] = true end
                    n = n + 1
                end
            end
        end
    end
    -- (the same ones as before: the same table - a calm grid keeps its ready list while it stays,
    -- KnoxGridView renderGrid)
    local old, same = L.lit, n > 0
    if same then
        local m = 0
        for x in pairs(old) do
            if not lit[x] then same = false break end
            m = m + 1
        end
        local k = 0
        for _ in pairs(lit) do k = k + 1 end
        same = same and m == k
    end
    if not same then L.lit = n > 0 and lit or EMPTY end
    if pt then Pf.part("load: lit", pt, n) end
end

--- What is lit up follows the mouse (L.sync).
local function track(now)
    local item = want
    want = nil
    if item then
        lastMs = now
        if item ~= cur then
            cur, curFt, sinceMs = item, nil, now
            L.lit = EMPTY
            local ok, ft = pcall(function() return item:getFullType() end)
            if ok and ft and L.kindOf(ft) then
                curFt = ft
            elseif ok and ft and KnoxGridView and KnoxGridView.batteryOf(item) then
                batteryFt[ft] = true
                curFt = ft
            end
        end
        if curFt and now - sinceMs >= HOVER_MS and (litMs < sinceMs or now - litMs > REFRESH_MS) then rebuild(now) end
        return
    end
    if not cur then return end
    -- (the mouse gone on to the thing's panel: they stay lit while it is open)
    local p = KnoxSlotPicker.instance
    if p and (p.load or p.battery) and p.owner and p.owner.item == cur then
        if now - litMs > REFRESH_MS then rebuild(now) end
        return
    end
    if now - lastMs > GRACE_MS then
        cur, curFt = nil, nil
        L.lit = EMPTY
    end
end

local fadeMs = 0
--- Once a frame, by the screen (its prerender): the lit ones follow the mouse,
--- fading in and out.
function L.sync()
    local now = getTimestampMs()
    track(now)
    local on = L.lit ~= EMPTY and not L.picking
    if on then L.shown = L.lit end
    -- (the animations off: at once - overhaul, 2026-11-04)
    local step = T.animOn() and math.max(0, math.min(100, now - fadeMs)) / FADE_MS or 1
    fadeMs = now
    if on then
        L.litA = math.min(1, L.litA + step)
    else
        L.litA = math.max(0, L.litA - step)
        if L.litA == 0 then L.shown = EMPTY end
    end
end

-- The panel -----------------------------------------------------------------------

local function sampleOf(ft)
    local s = idx.sample[ft]
    if s == nil then
        local ok, it = pcall(instanceItem, ft)
        s = ok and it or false
        idx.sample[ft] = s
    end
    return s or nil
end

--- One of this type, to read and show its picture (the menu on R).
function L.sample(ft)
    L.index()
    return sampleOf(ft)
end

-- the containers to look in: the character's (and all inside), and the ones
-- around while the Knox screen is open (not a locked one)
local function sources(player)
    local out = {player:getInventory()}
    local s = KnoxScreen and KnoxScreen.instance
    if s and s.loot and s.loot.containers and s.playerNum == player:getPlayerNum() then
        for _, c in ipairs(s.loot.containers) do
            if c.container and not c.locked then table.insert(out, c.container) end
        end
    end
    return out
end

local function inMain(player, it)
    return it:getContainer() == player:getInventory()
end

--- Piles of rounds of `key` and boxes of them: one per container and type, the
--- main inventory's first, then the bags', then those around; boxes last.
local function piles(player, key)
    local out, boxes, seen = {}, {}, {}
    local types = {key}
    for b in pairs(idx.ammo[key] and idx.ammo[key].boxes or EMPTY) do table.insert(types, b) end
    table.sort(types, function(a, b)
        if a == key or b == key then return a == key end
        return a < b
    end)
    for order, c in ipairs(sources(player)) do
        for _, t in ipairs(types) do
            local list = c:getAllTypeRecurse(t)
            local byBox = {}
            for i = 0, list:size() - 1 do
                local it = list:get(i)
                if not seen[it] then
                    seen[it] = true
                    local where = it:getContainer()
                    local g = byBox[where]
                    if not g then
                        g = {item = it, items = {}, box = t ~= key, order = order + (inMain(player, it) and 0 or 0.5)}
                        byBox[where] = g
                        table.insert(t ~= key and boxes or out, g)
                    end
                    table.insert(g.items, it)
                end
            end
        end
    end
    for _, g in ipairs(out) do g.count = #g.items end
    for _, g in ipairs(boxes) do g.count = #g.items end
    table.sort(out, function(a, b) return a.order < b.order end)
    for _, g in ipairs(boxes) do table.insert(out, g) end
    return out
end

--- Magazines of type `mt`, one cell each, the fullest first.
local function magazines(player, mt, except)
    local out, seen = {}, {}
    for _, c in ipairs(sources(player)) do
        local list = c:getAllTypeRecurse(mt)
        for i = 0, list:size() - 1 do
            local it = list:get(i)
            if it ~= except and not seen[it] then
                seen[it] = true
                local n = it:getCurrentAmmoCount()
                -- (hidden rounds: the order must not tell - known fuller first, not known last)
                local rank = n
                if KnoxMagKnown and KnoxMagKnown.hide then rank = KnoxMagKnown.is(it) and n + 1 or 0 end
                table.insert(out, {item = it, items = {it}, n = n, max = it:getMaxAmmo(), rank = rank, id = it:getID()})
            end
        end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.id < b.id
    end)
    return out
end

local function dirty()
    for _, v in ipairs(KnoxActions and KnoxActions.allViews() or EMPTY) do v:markDirty() end
end

local function toMain(player, it)
    local inv = player:getInventory()
    if it:getContainer() ~= inv then
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, it, it:getContainer(), inv))
    end
end

-- The game's actions -----------------------------------------------------------------

--- Rounds of `pile` into the magazine (as the game's "Load": in the main inventory,
--- as many as go in; those already in the main inventory go in too).
function L.loadMagazine(player, mag, pile)
    local key = mag:getAmmoType():getItemKey()
    local need = mag:getMaxAmmo() - mag:getCurrentAmmoCount()
    -- (a full one not known: one round tried, the try is how it is found out - nothing done
    -- at all would tell it free; QA 2026-10-31)
    local K = KnoxMagKnown
    if need <= 0 and K and K.hide and not K.is(mag) then need = 1 end
    if need <= 0 then return end
    toMain(player, mag)
    local moved, there = 0, 0
    for _, it in ipairs(pile.items) do
        if moved >= need then break end
        if inMain(player, it) then there = there + 1 end
        toMain(player, it)
        moved = moved + 1
    end
    local count = math.min(need, moved + player:getInventory():getCountType(key) - there)
    if count > 0 then ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, mag, count)) end
end

function L.unloadMagazine(player, mag)
    toMain(player, mag)
    ISTimedActionQueue.add(ISUnloadBulletsFromMagazine:new(player, mag))
end

-- Magazines back from the pockets (the author, 2026-11-04): a magazine is loaded in the
-- main inventory, and stayed there - with a rig on, each had to be carried back by hand.
-- Whatever asked for the loading (the menu on R, the Shift panel, the game's menus), once
-- the character has nothing left to do, a magazine still in the pockets goes to the rig,
-- no room or none: to the container chosen by a click on its header (KnoxActions, the one
-- quick moves go to), then to where it was taken from. One the game went on to put in the
-- gun is not in the pockets by then, so it stays out of this.
local LOOK_MS = 150
local TRIES = 2          -- (asked to wait by what the player did next: tried again)
local waiting = {}       -- magazine -> {player =, from = where it was, tries =}
local looking = false
local nextLook = 0

--- Where a magazine of `from` goes: first the one that has room.
local function homesFor(player, from)
    local out = {}
    local E = KnoxEquip
    local worn = player:getWornItems()
    for i = 0, worn and worn:size() - 1 or -1 do
        local w = worn:get(i)
        local at = E.LOC[E.norm(w:getLocation())]
        local item = w:getItem()
        if at and at.slot == "rig" and item and instanceof(item, "InventoryContainer") then
            table.insert(out, item:getInventory())
        end
    end
    local chosen = KnoxActions and KnoxActions.activeBag(player)
    if chosen then table.insert(out, chosen) end
    if from and from ~= player:getInventory() and from:isInCharacterInventory(player) then
        table.insert(out, from)
    end
    return out
end

--- Into the first of `homes` with a place for it, as a quick move (cells and pouches
--- counted, `layouts`: the grids of this go, with what is on its way there held).
local function sendHome(player, mag, homes, layouts)
    local D = KnoxDrag
    local w, h = KnoxFootprint.get(mag, mag:getFullType())
    local e = {item = mag, items = {mag}, w = w, h = h}
    for _, c in ipairs(homes) do
        if D.allowedIn(mag, c, player) then
            local layout = layouts[c] or KnoxGrid.build(c, player)
            layouts[c] = layout
            local x, y, r, joined = D.settle(layout, e)
            if x then
                D.moveTo(player, e, nil, layout, x, y, r)
                if not joined then
                    local tw, th = KnoxGrid.dims(e, r)
                    layout:occupy({item = mag, items = e.items, w = tw, h = th, reserved = true}, x, y, 0)
                end
                return true
            end
        end
    end
    return false
end

--- Anything in the queue of actions?
local function isBusy(player)
    local q = ISTimedActionQueue.queues and ISTimedActionQueue.queues[player]
    return q ~= nil and q.queue ~= nil and #q.queue > 0
end

--- Nothing to do and not aiming or running (those stop a transfer)?
local function isFree(player)
    if isBusy(player) then return false end
    return not (player:isAiming() or player:isRunning() or player:isSprinting())
end

--- Where it goes back to, and off it goes (both inside the one guard: a homes' look failing
--- stopped the whole tick - QA, 2026-11-04).
local function sendBack(player, mag, from, layouts)
    return sendHome(player, mag, homesFor(player, from), layouts)
end

local function lookBack()
    local now = getTimestampMs()
    if now < nextLook then return end
    nextLook = now + LOOK_MS
    local layouts, free, askedOf
    for mag, w in pairs(waiting) do
        local player = w.player
        local at = mag:getContainer()
        if player:isDead() then
            waiting[mag] = nil
        elseif at ~= player:getInventory() then
            -- (still in the rig or the bag it was asked out of: the transfer to the pockets is in the
            -- queue, the first look comes before it - QA, 2026-11-04. Anywhere else, or nothing queued:
            -- the player took it somewhere, or changed their mind)
            if at ~= w.from or not isBusy(player) then waiting[mag] = nil end
        else
            if askedOf ~= player then askedOf, free = player, isFree(player) end
            if free then
                layouts = layouts or {}
                w.tries = w.tries + 1
                local ok, sent = pcall(sendBack, player, mag, w.from, layouts)
                if not ok then print("[Knox] a magazine back: " .. tostring(sent)) end
                if not ok or not sent or w.tries >= TRIES then waiting[mag] = nil end
            end
        end
    end
    local left = false
    for _ in pairs(waiting) do left = true break end
    if not left then
        looking = false
        Events.OnTick.Remove(lookBack)
    end
end
L.lookBack = lookBack

--- Loading of `mag` was asked for: remembered, with where it is now.
local function noteLoading(player, mag)
    -- (with the game's own inventory the game's way stands: the author, 2026-11-04)
    if not T.on("inventory") or not mag or waiting[mag] or not instanceof(player, "IsoPlayer") then return end
    waiting[mag] = {player = player, from = mag:getContainer(), tries = 0}
    if not looking then
        looking = true
        Events.OnTick.Add(lookBack)
    end
end

if ISLoadBulletsInMagazine and not L.loadWrapped then
    L.loadWrapped = true
    local new = ISLoadBulletsInMagazine.new
    function ISLoadBulletsInMagazine:new(character, magazine, ammoCount)
        noteLoading(character, magazine)
        return new(self, character, magazine, ammoCount)
    end
end

--- A box opened (its recipe, as the game's menu on the box).
function L.openBox(player, box)
    for _, name in ipairs(OPEN_BOX) do
        local recipe = getScriptManager():getCraftRecipe(name)
        -- (a plain answer: an error() caught by pcall is still logged by the game
        -- as an error - the author's bench, 2026-10-30, two for a box of shells)
        local ok, fits = false, false
        if recipe then
            ok, fits = pcall(function()
                local inputs = recipe:getInputs()
                for i = 0, inputs:size() - 1 do
                    if inputs:get(i):canUseItem(box, player) then return true end
                end
                return false
            end)
        end
        if ok and fits then
            ISInventoryPaneContextMenu.OnNewCraft(box, recipe, player:getPlayerNum(), false)
            return true
        end
    end
    return false
end

--- A magazine into the gun, in hand (the one in it out first).
function L.insertMagazine(player, gun, mag)
    toMain(player, mag)
    ISInventoryPaneContextMenu.equipWeapon(gun, true, false, player:getPlayerNum())
    if gun:isContainsClip() then ISTimedActionQueue.add(ISEjectMagazine:new(player, gun)) end
    ISTimedActionQueue.add(ISInsertMagazine:new(player, gun, mag))
end

--- Rounds of `pile` into a gun that takes them itself (in hand; those of the pile
--- around brought to the main inventory first, the rest as the game's menu does).
function L.loadGun(player, gun, pile)
    local need = gun:getMaxAmmo() - gun:getCurrentAmmoCount()
    local inv, moved = player:getInventory(), 0
    for _, it in ipairs(pile.items) do
        if moved >= need then break end
        local c = it:getContainer()
        if c ~= inv and not (c and c:isInCharacterInventory(player)) then toMain(player, it) end
        moved = moved + 1
    end
    ISInventoryPaneContextMenu.onLoadBulletsIntoFirearm(player, gun)
end

-- What the panel's cells say and do ------------------------------------------------

--- What a click on cell `i` (1: what is in it, k + 1: the k-th past the line) does.
local function hintOf(l, i)
    local inner, sp = l.inner, i > 1 and l.spares[i - 1] or nil
    if i > 1 and not sp then return nil end
    if l.kind == "mag" then
        if i == 1 then
            if inner.jam then return "rack" end
            if not inner.empty then return "take" end
            return #l.spares > 0 and "insert" or nil
        end
        return inner.empty and "insert" or "swap"
    end
    -- a magazine, or a gun that takes rounds itself
    if i == 1 then
        if l.gun and inner.jam then return "rack" end
        return (inner.masked or (inner.n or 0) > 0) and "unload" or nil
    end
    if sp.box then return "open" end
    return (inner.masked or (inner.n or 0) < (inner.max or 0)) and "load" or nil
end

local function actOn(l, i)
    local player, item = l.player, l.item
    local sp = i > 1 and l.spares[i - 1] or nil
    local what = hintOf(l, i)
    if what == "rack" then
        ISInventoryPaneContextMenu.onRackGun(player, item)
    elseif what == "take" then
        ISInventoryPaneContextMenu.onEjectMagazine(player, item)
    elseif what == "insert" or what == "swap" then
        sp = sp or l.spares[1]
        if sp then L.insertMagazine(player, item, sp.item) end
    elseif what == "unload" then
        if l.gun then ISInventoryPaneContextMenu.onUnloadBulletsFromFirearm(player, item)
        else L.unloadMagazine(player, item) end
    elseif what == "open" then
        L.openBox(player, sp.item)
    elseif what == "load" then
        if l.gun then L.loadGun(player, item, sp) else L.loadMagazine(player, item, sp) end
    end
    l.sparesMs = nil
    dirty()
end

local roundsWide = {}   -- "15/15", made once a capacity
local totals = {}       -- "7/15", made once each

local function total(n, max)
    local key = n * 1000 + max
    local s = totals[key]
    if not s then
        s = n .. "/" .. max
        totals[key] = s
    end
    return s
end

--- The panel's `load` for this magazine or gun (nil: none - not one, or nothing to
--- load it with known), made once for the owner and kept up to date: what is in it
--- every frame, what may go in twice a second.
local function loadOf(ref, item, player)
    local x = L.index()
    local ft = ref.ft
    if not ft then
        ft = item:getFullType()
        ref.ft = ft
    end
    local g, m = x.gun[ft], x.mag[ft]
    if not g and not m then return nil end
    local l = ref.load
    if not l then
        l = {inner = {}, spares = EMPTY, item = item, player = player, gun = g ~= nil}
        l.hint = function(i) return hintOf(l, i) end
        l.act = function(i) actOn(l, i) end
        if g and g.mag then
            l.kind = "mag"
            l.title = getText("IGUI_Knox_LoadMag")
            l.inner.item = sampleOf(g.mag) or item
        else
            local key = g and g.ammo or m.ammo
            l.kind = "rounds"
            l.key = key
            l.title = getText(key == L.SHELLS and "IGUI_Knox_LoadShells" or "IGUI_Knox_LoadRounds")
            l.inner.item = g and (sampleOf(key) or item) or item
        end
        ref.load = l
    end
    local inner = l.inner
    inner.max = item:getMaxAmmo()
    local cap = inner.max
    local hide = KnoxMagKnown and KnoxMagKnown.hide
    l.widest = roundsWide[cap]
    if not l.widest then
        l.widest = cap .. "/" .. cap
        roundsWide[cap] = l.widest
    end
    if hide then l.widest = "" end
    inner.busy = KnoxGrid.useNow[item]
    if g then
        inner.jam = item:isJammed()
        inner.plus = item:haveChamber() and item:isRoundChambered()
        inner.empty = g.mag ~= nil and not item:isContainsClip()
        inner.n = (not inner.empty) and item:getCurrentAmmoCount() or nil
    else
        inner.jam, inner.plus, inner.empty = false, false, false
        inner.n = item:getCurrentAmmoCount()
    end
    l.jam = inner.jam
    -- (hidden rounds: no number; a magazine not known takes either click, none going out
    -- tells how many it holds)
    inner.masked = hide and not g and not KnoxMagKnown.is(item) or false
    l.total = inner.empty and getText("IGUI_Knox_LoadNone") or (hide and "" or total(inner.n or 0, cap))
    local now = getTimestampMs()
    if not l.sparesMs or now - l.sparesMs > REFRESH_MS then
        l.sparesMs = now
        local Pf = KnoxPerf
        local pt = Pf and Pf.detail and Pf.now()
        if l.kind == "mag" then l.spares = magazines(player, g.mag, nil)
        else l.spares = piles(player, l.key) end
        if pt then Pf.part("load: spares", pt, #l.spares) end
    end
    return l
end

--- A thing under the mouse that may be a magazine or a gun: its panel next to
--- `ref` (a table placed on the screen as a UI element: getAbsoluteX/Y,
--- getWidth/Height; `ref.item` the thing), once the mouse has rested on it.
--- `side`: where the panel opens (KnoxSlotPicker.want's).
function L.offer(ref, item, player, playerNum, side)
    if not item or not player then return end
    local now = getTimestampMs()
    if ref.item ~= item then
        ref.item, ref.ft, ref.load, ref.sinceMs = item, nil, nil, now
    end
    ref.sinceMs = ref.sinceMs or now
    -- (only once the quick items' key asked for it; open, it stays while the mouse
    -- is on the thing or the panel, or until the key is pressed again)
    if not KnoxSlotPicker.isOpenFor(ref) and (L.panelFor ~= item or now - ref.sinceMs < HOVER_MS) then return end
    local ok, l = pcall(loadOf, ref, item, player)
    if not ok or not l then return end
    KnoxSlotPicker.wantLoad(ref, l.title, l, playerNum, side)
end

-- a slot placed on the screen (a hand, a quick slot, the game's hotbar): its
-- panel's owner, apart from the slot's own quick pick panel
local SlotRef = {}
SlotRef.__index = SlotRef
function SlotRef:getAbsoluteX() return self.ui:getAbsoluteX() end
function SlotRef:getAbsoluteY() return self.ui:getAbsoluteY() end
function SlotRef:getWidth() return self.ui:getWidth() end
function SlotRef:getHeight() return self.ui:getHeight() end

--- The panel's owner for slot `ui` (kept on it).
function L.refOf(ui)
    local r = ui.knoxLoadRef
    if not r then
        r = setmetatable({ui = ui}, SlotRef)
        ui.knoxLoadRef = r
    end
    return r
end

--- A slot holding `item` under the mouse: what fits lights up, a gun's panel opens.
function L.slotHover(ui, item, player, playerNum, side)
    if not item or not player then return end
    L.hover(item)
    if instanceof(item, "HandWeapon") then L.offer(L.refOf(ui), item, player, playerNum, side) end
end

local panelItem, panelKind = nil, nil
--- Does the item get the panel ("gun" / "mag", else nil)? (the last item asked
--- kept: asked every frame the mouse rests on it)
function L.panelOf(item)
    if item ~= panelItem then
        panelItem, panelKind = item, nil
        local ok, k = pcall(function() return L.kindOf(item:getFullType()) end)
        if ok and (k == "gun" or k == "mag") then panelKind = k end
    end
    return panelKind
end

--- Is the panel open for this item?
local function openOn(item)
    local p = KnoxSlotPicker.instance
    return p ~= nil and p.owner ~= nil and p.owner.item == item
end

--- The item's own tooltip left out? With its panel up, or asked for by the key:
--- it lay over the panel's cells - each cell has its own tooltip (the author,
--- 2026-10-30). The key pressed over it switches between the two. Asked every
--- frame for the thing under the mouse; `has`: it gets a panel here.
function L.tipQuiet(item, has)
    -- (the key pressed over another thing that never got its panel: forgotten)
    if L.panelFor and L.panelFor ~= item and not openOn(L.panelFor) then L.panelFor = nil end
    -- (asked over any thing: the key's state followed while the mouse goes from one to the next)
    local hit = L.keyHit()
    if not has then return false end
    if hit then
        if L.panelFor == item or openOn(item) then
            L.panelFor = nil
            if openOn(item) then KnoxSlotPicker.dismiss() end
        else
            L.panelFor = item
        end
    end
    return L.panelFor == item or openOn(item)
end

return KnoxLoad
