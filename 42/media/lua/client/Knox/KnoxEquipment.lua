-- "Equipment" column: worn-item slots on both sides of the character's 3D
-- model, the back and the two hands below it.
--
-- A slot is a zone of the body, and everything worn there is layered in it
-- (a jacket over a sweater over a T-shirt): the outermost layer shows, the
-- mouse wheel or the arrows at its bottom go through the others.
--
-- Body locations are compared by a normalized name ("FULL_HAT", "base:fullhat"
-- and "FullHat" all become "fullhat"), so it works whatever the game's
-- location objects print as.

require "ISUI/ISPanel"
require "ISUI/ISUI3DModel"
require "ISUI/ISInventoryItem"
require "ISUI/ISInventoryPaneContextMenu"
require "Knox/KnoxTheme"
require "Knox/KnoxDrag"
require "Knox/KnoxTooltip"

local T = KnoxTheme
local DRAG_START_PX = 5
local DOUBLE_CLICK_MS = 350

KnoxEquip = KnoxEquip or {}
local E = KnoxEquip

E.norm = KnoxFootprint.norm   -- (one way to name a body location: the pockets and sizes use it too)

-- Slots (zones of the body) and the game's body locations they hold,
-- outermost layer first. Locations no slot names (mods' own) go to the
-- accessories.
E.SLOTS = {
    head  = {"FULL_HAT", "HAT"},
    face  = {"SCBA", "SCBANOTANK", "MASK_FULL", "MASK", "MASK_EYES", "EYES", "LEFT_EYE", "RIGHT_EYE",
             "SCARF", "NECK", "NECK_TEXTURE"},
    torso = {"FULL_SUIT_HEAD_SCBA", "FULL_SUIT_HEAD", "FULL_SUIT", "BOILERSUIT", "JACKET_HAT_BULKY",
             "JACKET_BULKY", "JACKET_HAT", "JACKET_DOWN", "JACKET_SUIT", "JACKET", "FULL_ROBE",
             "BATH_ROBE", "BODY_COSTUME", "FULL_TOP", "LONG_DRESS", "DRESS", "JERSEY", "SWEATER_HAT",
             "SWEATER", "SHIRT", "SHORT_SLEEVE_SHIRT", "TSHIRT", "TANK_TOP", "TORSO1LEGS1", "TORSO1",
             "VEST_TEXTURE", "UNDERWEAR_TOP"},
    armor = {"TORSO_EXTRA_VEST_BULLET", "TORSO_EXTRA_VEST", "CUIRASS", "TORSO_EXTRA",
             "SPORT_SHOULDERPAD_ON_TOP", "SPORT_SHOULDERPAD", "SHOULDERPAD_LEFT", "SHOULDERPAD_RIGHT",
             "GORGET"},
    -- arms: gloves and what guards the arms (elbow pads, forearm guards)
    hands = {"ELBOW_LEFT", "ELBOW_RIGHT", "FORE_ARM_LEFT", "FORE_ARM_RIGHT", "LEFT_ARM", "RIGHT_ARM",
             "HANDS", "HANDS_LEFT", "HANDS_RIGHT"},
    back  = {"BACK"},
    rig   = {"WEBBING", "AMMO_STRAP", "SATCHEL", "SHOULDER_HOLSTER"},
    belt  = {"BELT_EXTRA", "BELT", "FANNY_PACK_FRONT", "FANNY_PACK_BACK"},
    legs  = {"PANTS_EXTRA", "KNEE_LEFT", "KNEE_RIGHT", "THIGH_LEFT", "THIGH_RIGHT", "CALF_LEFT", "CALF_RIGHT",
             "LONG_SKIRT", "SKIRT", "PANTS", "PANTS_SKINNY", "SHORT_PANTS", "SHORTS_SHORT", "LEGS5", "LEGS1",
             "CALF_LEFT_TEXTURE", "CALF_RIGHT_TEXTURE", "CODPIECE", "UNDERWEAR_BOTTOM", "UNDERWEAR",
             "UNDERWEAR_EXTRA1", "UNDERWEAR_EXTRA2"},
    feet  = {"SHOES", "GAITER_LEFT", "GAITER_RIGHT", "ANKLE_HOLSTER", "SOCKS"},
    acc   = {"NECKLACE_LONG", "NECKLACE", "EARS", "EAR_TOP", "NOSE", "LEFT_WRIST", "RIGHT_WRIST",
             "LEFT_RING_FINGER", "RIGHT_RING_FINGER", "LEFT_MIDDLE_FINGER", "RIGHT_MIDDLE_FINGER", "TAIL"},
}
E.LEFT = {"head", "face", "torso", "armor", "hands", "acc"}
E.RIGHT = {"back", "rig", "belt", "legs", "feet"}

-- location -> {slot, order}
E.LOC = {}
for slot, locs in pairs(E.SLOTS) do
    for i, name in ipairs(locs) do E.LOC[E.norm(name)] = {slot = slot, order = i} end
end

-- Hidden things the game wears on the body: never shown.
local function isHiddenLoc(n)
    return n == "bandage" or n == "wound" or n == "zeddmg" or n == "bellybutton"
        or string.find(n, "^makeup") ~= nil
end

--- Where an item would be worn, normalized; "" if it can't be worn.
function E.wearLoc(item)
    if item:IsClothing() then return E.norm(item:getBodyLocation()) end
    local eq = item.canBeEquipped and item:canBeEquipped()
    if eq ~= nil then return E.norm(eq) end
    return ""
end

--- A mod's service item worn out of sight (Over The Shoulder's "Vision Boost":
--- hidden = true, DisplayCategory = Hidden): not a thing to show or take off.
function E.isHiddenItem(item)
    if item:getDisplayCategory() == "Hidden" then return true end
    local s = item:getScriptItem()
    return s ~= nil and s:isHidden()
end

--- Worn items sorted into slots, outermost first: {slotId = {items...}}.
function E.collect(player)
    local out = {}
    local orders = {}
    for id in pairs(E.SLOTS) do out[id] = {} end
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local w = worn:get(i)
        local item = w:getItem()
        local n = E.norm(w:getLocation())
        if item and not isHiddenLoc(n) and not E.isHiddenItem(item) then
            local m = E.LOC[n]
            if m then
                table.insert(out[m.slot], item)
                orders[item] = m.order
            else
                table.insert(out.acc, item)   -- a location of a mod's own
                orders[item] = 1000
            end
        end
    end
    for id in pairs(E.SLOTS) do
        table.sort(out[id], function(a, b) return orders[a] < orders[b] end)
    end
    return out
end

-- Slot hints ----------------------------------------------------------------------
-- Slots light up (breathing sand frame) where an item could go or is going:
--  * hovering "Attach" (or one of its slots), "Wear", "Equip..." in a context menu;
--  * hovering a piece of clothing that isn't worn: the slot it would be worn in;
--  * a queued action that puts something on, attaches it or takes it in hand
--    (also the game's own, started from a context menu).
-- Slot ids: "wear:<slot>", "hand1", "hand2", "quick:<hotbar index>".

E.hint = {}      -- id -> true, this frame
E.arriving = {}  -- id -> true, targets of queued actions
E.replace = {}   -- worn or attached item -> true: would be taken off by the hinted move

local function add(set, id) if id then set[id] = true end end

--- Worn items that putting on `item` takes off (the game's own rule, as in
--- ISInventoryPaneContextMenu.doWearClothingTooltip: same location or an
--- exclusive one).
-- (asked every frame while a thing to wear is under the mouse or held: a few calls
-- into the game per worn item - kept a moment for the same thing and the same clothes)
local replaced = {ms = -1000}

function E.replacedBy(player, item)
    local worn = player:getWornItems()
    local now = getTimestampMs()
    local r = replaced
    if r.item == item and r.player == player and r.n == worn:size() and now - r.ms < 250 then return r.list end
    local out = {}
    replaced = {item = item, player = player, n = worn:size(), ms = now, list = out}
    local group = worn:getBodyLocationGroup()
    local loc = (item:IsClothing() or item:IsInventoryContainer()) and item:getBodyLocation() or item:canBeEquipped()
    for i = 0, worn:size() - 1 do
        local w = worn:get(i)
        local other = w:getItem()
        local wl = w:getLocation()
        if other and other ~= item and ((item:getBodyLocation() and item:getBodyLocation() == wl)
                or (item:canBeEquipped() and item:canBeEquipped() == wl)
                or (loc ~= nil and group:isExclusive(loc, wl))) then
            table.insert(out, other)
        end
    end
    return out
end

local function addWearTargets(set, items, player, replace)
    for _, it in ipairs(items) do
        if E.wearLoc(it) ~= "" and not KnoxGrid.isEquippedNow(it, player) then
            add(set, E.wearTarget(it))
            for _, r in ipairs(E.replacedBy(player, it)) do replace[r] = true end
        end
    end
end

--- Hotbar slots `item` can be attached to (a bat: the back; a hammer: the belt).
local function addAttachTargets(set, item, player, replace)
    if not item:getAttachmentType() or (item:getAttachedSlot() and item:getAttachedSlot() > -1) then return end
    local hb = getPlayerHotbar(player:getPlayerNum())
    if not hb then return end
    local found = {}
    for i, slot in ipairs(hb.availableSlot) do
        if hb:canBeAttached(slot, item) then
            add(set, "quick:" .. i)
            table.insert(found, i)
        end
    end
    -- one place only: what hangs there now is taken off
    if #found == 1 and hb.attachedItems[found[1]] then replace[hb.attachedItems[found[1]]] = true end
end

--- Is this item for the hands: a weapon or tool? (Bags carried by the handle
--- are left out: they crowded the hands' quick pick.) The game makes pens,
--- pencils, spoons, forks, scissors weapons too (damage 0.1): only real
--- weapons (a kitchen knife, a broom handle and up), guns and tools count.
local HAND_CATEGORIES = {ToolWeapon = true, Explosives = true, GardeningWeapon = true, FishingWeapon = true}
function E.holdable(item)
    if not instanceof(item, "HandWeapon") then return false end
    if item:isRanged() or item:getMaxDamage() > 0.5 then return true end
    return HAND_CATEGORIES[item:getDisplayCategory() or ""] == true
end

--- The hands such an item would go to: the right one, both for a two-handed one.
local function addHandTargets(set, item, player)
    if not E.holdable(item) or KnoxGrid.isEquippedNow(item, player) then return end
    add(set, "hand1")
    if item:isTwoHandWeapon() then add(set, "hand2") end
end

local function targetItems()
    local out = {}
    local t = KnoxContextMenu and KnoxContextMenu.target
    if t then for it in pairs(t.items) do table.insert(out, it) end end
    return out
end

--- Slots a context menu option is about.
local function hintsOf(option, menu, set, player, replace)
    local f = option.onSelect
    if f and f == ISHotbar.attachItem then
        add(set, "quick:" .. tostring(option.param3))
    elseif option.subOption and option.name == getText("ContextMenu_Attach") then
        local sub = getPlayerContextMenu(menu.player):getSubInstance(option.subOption)
        for _, o in ipairs(sub and sub.options or {}) do
            if o.onSelect == ISHotbar.attachItem then add(set, "quick:" .. tostring(o.param3)) end
        end
    elseif f == ISInventoryPaneContextMenu.onWearItems or option.name == getText("ContextMenu_Wear") then
        addWearTargets(set, targetItems(), player, replace)
    elseif f == ISInventoryPaneContextMenu.OnPrimaryWeapon then
        add(set, "hand1")
    elseif f == ISInventoryPaneContextMenu.OnSecondWeapon then
        add(set, "hand2")
    elseif f == ISInventoryPaneContextMenu.OnTwoHandsEquip then
        add(set, "hand1")
        add(set, "hand2")
    end
end

--- Where a queued action puts its item.
local function targetOfAction(a, set)
    local t = a.Type
    if t == "ISAttachItemHotbar" then
        add(set, "quick:" .. tostring(a.slotIndex))
    elseif t == "ISWearClothing" and a.item then
        add(set, E.wearTarget(a.item))
    elseif t == "ISEquipWeaponAction" then
        if a.twoHands then
            add(set, "hand1")
            add(set, "hand2")
        else
            add(set, a.primary and "hand1" or "hand2")
        end
    end
end

--- Called once a frame by the screen.
function E.updateHints(player)
    local hint, arriving, replace = {}, {}, {}
    if KnoxContextMenu then
        local option, menu = KnoxContextMenu.hoveredOption()
        if option then hintsOf(option, menu, hint, player, replace) end
    end
    -- the item under the mouse, or the one being dragged: where it would go
    local item = KnoxTooltip.lastHover
    if KnoxDrag.isActive() and not KnoxDrag.entity.fromBody then item = KnoxDrag.entity.item end
    if item then
        addWearTargets(hint, {item}, player, replace)
        addAttachTargets(hint, item, player, replace)
        addHandTargets(hint, item, player)
    end
    local queues = ISTimedActionQueue.queues
    local q = queues and queues[player] and queues[player].queue
    for _, a in ipairs(q or {}) do targetOfAction(a, arriving) end
    E.hint, E.arriving, E.replace = hint, arriving, replace
end

--- Would any of these items be taken off by the hinted move?
function E.isReplaced(items)
    for _, it in ipairs(items) do
        if E.replace[it] then return true end
    end
    return false
end

--- Should slot `id` show the breathing frame?
function E.isHinted(id)
    return E.hint[id] == true or E.arriving[id] == true
end

-- Picking an item for an empty slot ---------------------------------------------
-- Hovering an empty slot shows how many carried items fit it; a click opens
-- the quick pick panel (KnoxSlotPicker) with them; the choice is put on /
-- taken in hand / attached as a tracked move.

local CANDIDATES_MS = 500

--- Everything the character carries (pockets, worn bags, bags inside them),
--- except what is worn, held or attached.
function E.carried(player)
    local out = {}
    local function walk(c, depth)
        local items = c:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            -- (not what a bag put on without a look still hides: KnoxSearch)
            if not KnoxGrid.isEquippedNow(it, player) and not (KnoxSearch and KnoxSearch.unseen(it)) then
                table.insert(out, it)
            end
            if depth < 4 and instanceof(it, "InventoryContainer") and it:getInventory() then
                walk(it:getInventory(), depth + 1)
            end
        end
    end
    walk(player:getInventory(), 0)
    return out
end

--- Carried items passing `fits`, by name; cached on `holder` for a moment.
function E.candidates(holder, player, fits)
    local now = getTimestampMs()
    local c = holder.knoxCandidates
    if c and now - c.ms < CANDIDATES_MS then return c.list end
    local list = {}
    for _, it in ipairs(E.carried(player)) do
        if fits(it) then table.insert(list, it) end
    end
    table.sort(list, function(a, b) return a:getDisplayName() < b:getDisplayName() end)
    holder.knoxCandidates = {ms = now, list = list}
    return list
end

--- Where an item lies in a grid (the source of its move), or nil.
function E.gridSourceOf(item, player)
    local c = item:getContainer()
    if not c then return nil end
    local key = KnoxGrid.containerKey(c, player)
    local p = item:getModData().knox
    if p and p.k == key then return {kind = "grid", key = key, x = p.x, y = p.y, r = p.r or 0} end
    return nil
end


--- On an empty slot under the mouse: the number of items that fit it.
function E.drawAvailable(ui, w, h, n, small)
    local c = n > 0 and T.color.accent or T.color.dim
    local nf = small and T.fontText or T.fontHeader
    local nh = T.fontH(nf)
    if small then
        T.textCentre(ui, tostring(n), math.floor(w / 2), math.floor((h - nh) / 2), c, nf)
        return
    end
    local ch = T.fontH(T.fontTile)
    local top = math.floor((h - nh - ch) / 2)
    T.textCentre(ui, tostring(n), math.floor(w / 2), top, c, nf)
    T.textCentre(ui, T.upper(getText("IGUI_Knox_Available")), math.floor(w / 2), top + nh, T.color.dim, T.fontTile)
end

-- Slot element ------------------------------------------------------------------

KnoxEquipSlot = ISUIElement:derive("KnoxEquipSlot")

--- kind: "wear" (arg = slot id) or "hand" (arg = primary true/false)
function KnoxEquipSlot:new(panel, kind, arg, label)
    local o = ISUIElement:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.panel = panel
    o.kind = kind
    o.arg = arg
    o.label = label
    o.press = nil
    o.lastClickMs = 0
    o.layer = 1   -- which worn layer shows (1 = outermost)
    return o
end

function KnoxEquipSlot:player()
    return self.panel:player()
end

function KnoxEquipSlot:items()
    local p = self.panel
    if self.kind == "wear" then return p.worn[self.arg] or {} end
    local player = self:player()
    local item
    if self.arg then item = player:getPrimaryHandItem() else item = player:getSecondaryHandItem() end
    return item and {item} or {}
end

--- Would dropping this item here do something?
function KnoxEquipSlot:accepts(item)
    if self.kind == "hand" then
        local player = self:player()
        if KnoxDrag.entity.fromBody and not (item:getAttachedSlot() and item:getAttachedSlot() > -1) then
            return false
        end
        if self.arg then return player:getPrimaryHandItem() ~= item end
        return player:getSecondaryHandItem() ~= item and not item:isTwoHandWeapon()
    end
    if KnoxDrag.entity.fromBody then return false end
    local loc = E.wearLoc(item)
    if loc == "" then return false end
    return E.wearTarget(item) == "wear:" .. self.arg
end

--- Id of this slot for moves ("hand1", "wear:head", ...).
function KnoxEquipSlot:targetId()
    -- (made once: each slot asks for it three times a frame - a new string each,
    -- the author's FPS task 2026-10-28)
    if self.tid and self.tidArg == self.arg then return self.tid end
    local id
    if self.kind == "hand" then id = self.arg and "hand1" or "hand2" else id = "wear:" .. self.arg end
    self.tid, self.tidArg = id, self.arg
    return id
end

--- Slot a wearable item lands in: "wear:<slot>" (accessories for a mod's own location).
function E.wearTarget(item)
    local m = E.LOC[E.wearLoc(item)]
    return "wear:" .. (m and m.slot or "acc")
end

--- Put on a wearable item, as a tracked move from `source`.
function E.wearItem(player, item, source)
    local playerNum = player:getPlayerNum()
    KnoxGrid.track(player, {item}, source, {kind = "slot", id = E.wearTarget(item)}, function()
        ISInventoryPaneContextMenu.wearItem(item, playerNum)
    end)
end

--- Take an item in a hand, as a tracked move from `source`.
function E.equipHand(player, item, primary, source)
    local playerNum = player:getPlayerNum()
    KnoxGrid.track(player, {item}, source, {kind = "slot", id = primary and "hand1" or "hand2"}, function()
        ISInventoryPaneContextMenu.equipWeapon(item, primary, primary and item:isTwoHandWeapon(), playerNum)
    end)
end

function KnoxEquipSlot:equip(item, source)
    if self.kind == "hand" then
        E.equipHand(self:player(), item, self.arg, source)
    else
        E.wearItem(self:player(), item, source)
    end
end

--- Take off / put away what's in this slot (double click).
function KnoxEquipSlot:unequip(item)
    local playerNum = self.panel.playerNum
    KnoxGrid.track(self:player(), {item}, {kind = "slot", id = self:targetId()}, nil, function()
        ISInventoryPaneContextMenu.unequipItem(item, playerNum)
    end)
end

--- What the slot holds: real items (those in a move are left out), and the
--- faded copy of an item leaving this slot with its progress.
function KnoxEquipSlot:contents()
    local real = {}
    for _, it in ipairs(self:items()) do
        if not KnoxGrid.pendingOf(it) then table.insert(real, it) end
    end
    local leaving, progress = KnoxGrid.leavingSlot(self.panel.pendingNow, self:targetId())
    return real, leaving, progress
end

--- Index of the layer shown: the one the hinted move would take off (so its
--- red mark is seen), else the chosen one.
function KnoxEquipSlot:shownIndex(items)
    for i, it in ipairs(items) do
        if E.replace[it] then return i end
    end
    if self.layer > #items then self.layer = math.max(1, #items) end
    return self.layer
end

--- Go through the layers (+1 deeper, -1 outward), wrapping round.
function KnoxEquipSlot:stepLayer(d)
    local n = #self:contents()
    if n < 2 then return end
    self.layer = T.mod(self.layer - 1 + d, n) + 1   -- (not %: negative in the game's Lua)
    getSoundManager():playUISound("UISelectListItem")
end

--- The arrows at the bottom corners (shown with 2+ layers): {x, y, w, h}.
function KnoxEquipSlot:arrowRects()
    local w, h = self:getWidth(), self:getHeight()
    local s = math.max(14, math.floor(math.min(w, h) / 5))
    local y = h - s - 8
    return {3, y, s, s}, {w - s - 3, y, s, s}
end

local function chevron(ui, r, dir, c)
    local s = math.max(2, math.floor(r[3] / 4))
    local cx, cy = r[1] + math.floor(r[3] / 2), r[2] + math.floor(r[4] / 2)
    for i = 0, s do
        local x = dir < 0 and (cx + math.floor(s / 2) - i) or (cx - math.floor(s / 2) + i)
        ui:drawRect(x, cy - s + i, 2, 2, 1, c.r, c.g, c.b)
        ui:drawRect(x, cy + s - i, 2, 2, 1, c.r, c.g, c.b)
    end
end

-- A slot's ready list (the inventory's FPS, stage 2 - the author, 2026-10-29): one per
-- slot of each player, for good (Java keeps every list: a screen made anew takes the same
-- ones). It holds the slot's cell, item and frame while the slot is not under the mouse
-- and its pick panel is shut; the marks over the frame (a move, a hint, the item in use)
-- are drawn after it as ever.
local slotLists = {}

--- The fill of the slot's condition meter, nil for none. (Clothing or a weapon - asked
--- of the item once, not every frame.)
local function meterFrac(slot, item)
    if not item then return nil end
    if slot.meterFor ~= item then
        slot.meterFor = item
        slot.meterKind = instanceof(item, "Clothing") or instanceof(item, "HandWeapon")
    end
    if not slot.meterKind or item:getConditionMax() <= 0 then return nil end
    return item:getCondition() / math.max(1, item:getConditionMax())
end

--- The slot's own look: its cell, the item, its condition, the name, the layers.
local function drawSlotBody(self, w, h, items, idx, item, alpha, cat, hl, over, dy, da, frac, leaving)
    T.rect(self, 0, 0, w, h, T.color.cell, T.slotAlpha())
    if cat then T.rect(self, 0, 0, w, h, cat, alpha) end
    if hl then self:drawRect(0, 0, w, h, 0.06, 1, 1, 1) end

    local fh = T.fontTileH
    if item then
        local areaH = h - fh
        local side = math.floor(math.min(w, areaH) * 0.8)
        ISInventoryItem.renderItemIcon(self, item, math.floor((w - side) / 2), fh + math.floor((areaH - side) / 2) + dy,
            alpha * da, side, side)
        if frac then
            local c = frac > 0.6 and T.color.good or (frac > 0.25 and T.color.warn or T.color.bad)
            T.tileMeter(self, 0, 0, w, h, frac, c, alpha, 0)
        end
    end
    if self.label then
        -- the name leaves room for the layer counter ("1/2") in the corner
        local room = w - 8
        if #items > 1 and not leaving then room = room - T.measure(T.fontTile, idx .. "/" .. #items) - 6 end
        T.text(self, T.fit(T.upper(self.label), T.fontTile, room), 5, 2, T.color.dim, T.fontTile, item and 1 or 0.8)
    end
    -- several layers: "2/3" in the top-right corner, arrows at the bottom
    if #items > 1 and not leaving then
        T.outlinedRight(self, idx .. "/" .. #items, w - 4, 2, T.color.bright)
        local l, r = self:arrowRects()
        local mx, my = self:getMouseX(), self:getMouseY()
        for _, a in ipairs({{l, -1}, {r, 1}}) do
            local rect = a[1]
            local hot = over and T.inRect(mx, my, rect)
            T.rect(self, rect[1], rect[2], rect[3], rect[4], T.color.window, 0.75)
            T.border(self, rect[1], rect[2], rect[3], rect[4], hot and T.color.accent or T.color.tileFrame)
            chevron(self, rect, a[2], hot and T.color.accent or T.color.text)
        end
    end
end

function KnoxEquipSlot:render()
    local w, h = self:getWidth(), self:getHeight()
    local items, leaving, progress = self:contents()
    local idx = self:shownIndex(items)
    local item = items[idx]
    local over = self:isMouseOver()
    local player = self:player()
    local alpha = 1
    local twoHandGhost = false
    if leaving then
        item, alpha = leaving, 0.4
    elseif self.kind == "hand" and not self.arg and item and item == player:getPrimaryHandItem() then
        twoHandGhost, alpha = true, 0.3     -- two-handed: shown faint in the second hand
    end
    local live = item and not leaving
    local dragging = KnoxDrag.isActive()
    local dy, da = 0, 1
    if item then dy, da = T.settleIn(self, live and item or nil) end   -- just put here: it settles in
    local frac = meterFrac(self, item)
    local cat = item and not twoHandGhost and T.category[T.categoryOf(item)] or false
    local open = not dragging and not leaving and not twoHandGhost and KnoxSlotPicker.isOpenFor(self)
    local windowOpen = live and ((KnoxInspectWindow and KnoxInspectWindow.isOpen(item))
        or (KnoxFluidWindow and KnoxFluidWindow.isOpen(item)))

    -- (from the ready list while the slot is not under the mouse and its pick panel is
    -- shut: the key is all the slot shows - the item, its place, how it comes in, its
    -- condition, the layers, its colour, a window about it)
    local L
    if not over and not open then
        L = self.readyList
        if not L then
            local key = self.panel.playerNum .. self:targetId()
            L = slotLists[key] or T.newList()
            slotLists[key], self.readyList = L, L
        end
        local layers = (#items > 1 and not leaving) and idx * 100 + #items or 0
        local flags = (leaving and 1 or 0) + (twoHandGhost and 2 or 0) + (windowOpen and 4 or 0)
        if T.listDraw(self, L, item or false, w * 10000 + h, flags, dy, da, frac or -1, layers, cat) then L = false end
    end
    if L ~= false then
        drawSlotBody(self, w, h, items, idx, item, alpha, cat, over and not dragging and live, over, dy, da, frac, leaving)
        -- under the mouse: the quick pick panel with the carried items that fit
        -- (an empty slot also shows their number and breathes in sand when some do)
        if not dragging and not leaving and not twoHandGhost then
            local canAdd = not item or self.kind == "wear"   -- a worn zone takes another layer
            if canAdd and (over or open) then
                local cands = self:candidates()
                if over and not item then E.drawAvailable(self, w, h, #cands, false) end
                if #cands > 0 then
                    if not item then T.target(self, 0, 0, w, h) end
                    if over then KnoxSlotPicker.want(self, self.label, cands, self:pickFn()) end
                end
            end
        end

        -- drag feedback
        local edge = (over and not dragging and live) and T.color.tileHover
            or (live and T.color.tileFrame or T.color.tileEdge)
        if dragging and over then
            local ok = self:accepts(KnoxDrag.entity.item)
            local c = ok and T.color.ok or T.color.bad
            self:drawRect(0, 0, w, h, 0.22, c.r, c.g, c.b)
            edge = c
        end
        if windowOpen then
            edge = T.color.accent   -- a window about it is open (inspect, pouring)
        end
        if live then T.tileFrame(self, 0, 0, w, h, edge) else T.border(self, 0, 0, w, h, edge) end
        if L then T.listEnd(L) end
    end
    -- what the hinted move would take off: red frame
    if not leaving and E.isReplaced(items) then T.replaceMark(self, 0, 0, w, h) end
    if live and KnoxContextMenu and KnoxContextMenu.isTarget(item) then
        KnoxContextMenu.drawTarget(self, 0, 0, w, h)   -- its context menu is open
    end
    if progress then T.progress(self, 0, 0, w, h, progress) end
    local use = live and KnoxGrid.useOf(items)
    if use then T.inUse(self, 0, 0, w, h, use) end
    if KnoxGrid.arrivingSlot(self.panel.pendingNow, self:targetId()) or E.isHinted(self:targetId()) then
        T.target(self, 0, 0, w, h)
    end

    if over and live and not dragging then KnoxTooltip.want(item, self.panel.playerNum) end
end

--- The item a click or drag on this slot works with: the layer shown (not one in a move).
function KnoxEquipSlot:liveItem()
    local items, leaving = self:contents()
    if leaving then return nil end
    local item = items[self:shownIndex(items)]
    if self.kind == "hand" and not self.arg and item == self:player():getPrimaryHandItem() then
        return nil   -- the second hand of a two-handed weapon: use the first hand slot
    end
    return item
end

function KnoxEquipSlot:arrowAt(x, y)
    if #self:contents() < 2 then return nil end
    local l, r = self:arrowRects()
    if T.inRect(x, y, l) then return -1 end
    if T.inRect(x, y, r) then return 1 end
    return nil
end

function KnoxEquipSlot:onMouseDown(x, y)
    local arrow = self:arrowAt(x, y)
    if arrow then
        self.press = {arrow = arrow}
        return true
    end
    self.press = {item = self:liveItem(), x = getMouseX(), y = getMouseY()}
    return true
end

function KnoxEquipSlot:onMouseMove(dx, dy)
    local p = self.press
    if p and p.item and not KnoxDrag.isActive() and isMouseButtonDown(0) then
        if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) >= DRAG_START_PX then
            KnoxDrag.startFromBody(p.item, self:targetId())
            self.press = nil
        end
    end
end

function KnoxEquipSlot:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function KnoxEquipSlot:onMouseUpOutside(x, y)
    self.press = nil
end

--- The mouse wheel goes through the layers.
function KnoxEquipSlot:onMouseWheel(del)
    if #self:contents() < 2 then return false end
    self:stepLayer(del > 0 and 1 or -1)
    return true
end

--- Carried items that fit this slot (for a worn zone: another layer for it).
function KnoxEquipSlot:candidates()
    local player = self:player()
    if self.kind == "wear" then
        local id = "wear:" .. self.arg
        return E.candidates(self, player, function(it)
            return E.wearLoc(it) ~= "" and E.wearTarget(it) == id
        end)
    elseif self.kind == "hand" then
        local primary = self.arg
        return E.candidates(self, player, function(it)
            return E.holdable(it) and (primary or not (instanceof(it, "HandWeapon") and it:isTwoHandWeapon()))
        end)
    end
    return {}
end

--- What choosing an item in the quick pick panel does: put it on / take it in hand.
function KnoxEquipSlot:pickFn()
    local player, slot = self:player(), self
    return function(it)
        local source = E.gridSourceOf(it, player)
        if slot.kind == "hand" then E.equipHand(player, it, slot.arg, source) else E.wearItem(player, it, source) end
    end
end

function KnoxEquipSlot:onMouseUp(x, y)
    if KnoxDrag.isActive() then
        local e = KnoxDrag.entity
        local ok = self:accepts(e.item)
        local source = KnoxDrag.sourceInfo()
        KnoxDrag.cancel()
        if ok then self:equip(e.item, source) end
        return true
    end
    local p = self.press
    self.press = nil
    if not p then return true end
    if p.arrow then
        if self:arrowAt(x, y) == p.arrow then self:stepLayer(p.arrow) end
        return true
    end
    local now = getTimestampMs()
    if p.item and now - self.lastClickMs < DOUBLE_CLICK_MS then
        self.lastClickMs = 0
        self:unequip(p.item)
    else
        self.lastClickMs = now
    end
    return true
end

--- The menu of the layer shown.
function KnoxEquipSlot:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end   -- (an item is held: the button may turn it, see KnoxDragLayer)

    local item = self:liveItem()
    if not item then return true end
    if KnoxContextMenu then KnoxContextMenu.setTarget({item}, self.panel.playerNum) end
    ISInventoryPaneContextMenu.createMenu(self.panel.playerNum, true, {item},
        self:getAbsoluteX() + x, self:getAbsoluteY() + y)
    return true
end

-- Panel ---------------------------------------------------------------------------

KnoxEquipmentPanel = ISPanel:derive("KnoxEquipmentPanel")

--- Sizes, all derived from the grid cell so the column scales with the screen.
function KnoxEquipmentPanel.metrics()
    local c = T.cell
    local m = {}
    m.S = math.floor(c * 1.75 + 0.5)    -- slot side
    m.g = math.max(4, math.floor(c / 6 + 0.5))   -- gap between slots
    m.gm = T.pad                         -- gap around the model
    m.width = T.pad * 2 + m.S * 5 + m.gm * 2
    return m
end

function KnoxEquipmentPanel.columnWidth()
    return KnoxEquipmentPanel.metrics().width
end

function KnoxEquipmentPanel:new(x, y, w, h, playerNum)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.worn = {}
    o.slots = {}
    o.pendingNow = {}
    return o
end

function KnoxEquipmentPanel:player()
    return getSpecificPlayer(self.playerNum)
end

local function addSlot(panel, slot, x, y, w, h)
    slot:initialise()
    slot:setX(x)
    slot:setY(y)
    slot:setWidth(w)
    slot:setHeight(h)
    panel:addChild(slot)
    table.insert(panel.slots, slot)
    return slot
end

function KnoxEquipmentPanel:createChildren()
    local m = KnoxEquipmentPanel.metrics()
    self.m = m
    local S, g, gm, pad = m.S, m.g, m.gm, T.pad
    local titleH = T.fontH(T.fontHeader)
    local top = pad + titleH + gm
    self.top = top
    self.worn = E.collect(self:player())

    -- left column: 6 square slots; right column: 5 slots stretched to the same height
    local mh = 6 * S + 5 * g
    for i, id in ipairs(E.LEFT) do
        addSlot(self, KnoxEquipSlot:new(self, "wear", id, getText("IGUI_Knox_Slot_" .. id)),
            pad, top + (i - 1) * (S + g), S, S)
    end
    local rx = self:getWidth() - pad - S
    local rn = #E.RIGHT
    local rh = math.floor((mh - (rn - 1) * g) / rn)
    for i, id in ipairs(E.RIGHT) do
        addSlot(self, KnoxEquipSlot:new(self, "wear", id, getText("IGUI_Knox_Slot_" .. id)),
            rx, top + (i - 1) * (rh + g), S, rh)
    end

    -- model box between the slot columns
    local mx = pad + S + gm
    local mw = rx - gm - mx
    self.modelBox = {x = mx, y = top, w = mw, h = mh}
    local av = ISUI3DModel:new(mx, top, mw, mh)
    av:initialise()
    av:instantiate()
    av:setDirection(IsoDirections.S)
    av:setIsometric(false)
    av:setZoom(0)
    av:setYOffset(0)
    av:setDoRandomExtAnimations(false)
    av:setAnimSetName("player-avatar")
    av:setState("idle")
    av.animateWhilePaused = true
    -- dropping clothes on the model puts them on
    local panel = self
    av.onMouseUp = function(model, x, y)
        if KnoxDrag.isActive() then
            local item = KnoxDrag.entity.item
            local fromBody = KnoxDrag.entity.fromBody
            local source = KnoxDrag.sourceInfo()
            KnoxDrag.cancel()
            if not fromBody and E.wearLoc(item) ~= "" then E.wearItem(panel:player(), item, source) end
            return true
        end
        return ISUI3DModel.onMouseUp(model, x, y)
    end
    self:addChild(av)
    self.model = av

    -- under the model: the hotbar's back slot (a bat, a rifle slung on the
    -- back; wide, two rows high), left hand above right hand beside it
    local hy = top + mh + gm
    local full = self:getWidth() - pad * 2
    local bw = math.floor((full - g) * 2 / 3)
    local hx, hw = pad + bw + g, full - bw - g
    local back = KnoxQuickSlot:new(self.screen, 0, getText("IGUI_Knox_Slot_backAttach"), "Back")
    back:initialise()
    back:setX(pad)
    back:setY(hy)
    back:setWidth(bw)
    back:setHeight(S * 2 + g)
    self:addChild(back)
    self.backSlot = back
    -- switched: left hand (secondary) on top, right hand (primary) on bottom
    addSlot(self, KnoxEquipSlot:new(self, "hand", false, getText("IGUI_Knox_Slot_secondary")), hx, hy, hw, S)
    addSlot(self, KnoxEquipSlot:new(self, "hand", true, getText("IGUI_Knox_Slot_primary")), hx, hy + S + g, hw, S)
end

-- The character model: with the Java part it repeats the character's pose
-- in the world every frame (actions, walking, aiming) and holds what the
-- character holds; its look is refreshed when clothes, hands or the hotbar
-- change, and every couple of seconds (blood, dirt).
local LOOK_MS = 2000

local function lookSignature(player, hands)
    local parts = {hands or ""}
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local it = worn:get(i):getItem()
        if it then table.insert(parts, tostring(it:getID())) end
    end
    local attached = player:getAttachedItems()
    for i = 0, attached:size() - 1 do
        local it = attached:get(i):getItem()
        if it then table.insert(parts, "a" .. tostring(it:getID())) end
    end
    local p, s = player:getPrimaryHandItem(), player:getSecondaryHandItem()
    table.insert(parts, "p" .. (p and tostring(p:getID()) or "-") .. "s" .. (s and tostring(s:getID()) or "-"))
    return table.concat(parts, ",")
end

function KnoxEquipmentPanel:updateModel(player)
    local av = self.model
    local hands = knoxAvatarHands(player)
    local sig = lookSignature(player, hands)
    local now = getTimestampMs()
    if sig ~= self.lookSig or now - (self.lookMs or 0) > LOOK_MS then
        self.lookSig, self.lookMs = sig, now
        if hands and knoxAvatarSetHands then
            local p, s = string.match(hands, "^([^|]*)|(.*)$")
            knoxAvatarSetHands(av.javaObject, p, s)
        end
        av:setCharacter(player)
    end
    -- In a car the character's skeleton is placed and scaled for its seat in
    -- that vehicle: copied here it came out huge and half out of the box (and
    -- differently in every car). There the model keeps its own standing pose.
    knoxAvatarMirror(av.javaObject, player, player:getVehicle() == nil)
end

-- The panel's title and the model's box: a ready list per player, for good (the
-- inventory's FPS, stage 2 - the author, 2026-10-29)
local panelLists = {}

function KnoxEquipmentPanel:prerender()
    local player = self:player()
    self.worn = E.collect(player)
    self.pendingNow = KnoxGrid.pendingList()   -- read by the slots while they draw

    self:updateModel(player)


    local w = self:getWidth()
    local pad = T.pad
    local fh = T.fontH(T.fontHeader)
    local ft = T.fontH(T.fontText)

    -- title: section name and who we are
    -- (the name and the day put together when the day changes, not every frame)
    local desc = player:getDescriptor()
    local days = math.floor(player:getHoursSurvived() / 24)
    local first, last = desc:getForename(), desc:getSurname()
    local hd = self.headText
    if not hd or hd.days ~= days or hd.first ~= first or hd.last ~= last then
        local who = first .. " " .. last .. ", " .. getText("IGUI_Knox_Day", days + 1)
        hd = {days = days, first = first, last = last, title = T.upper(getText("IGUI_Knox_Equipment")), who = T.upper(who)}
        self.headText = hd
    end
    -- (from the ready list while the name, the day and the sizes stay)
    local b = self.modelBox
    local L = panelLists[self.playerNum]
    if not L then
        L = T.newList()
        panelLists[self.playerNum] = L
    end
    if not T.listDraw(self, L, hd, w, b.x * 10000 + b.y, b.w * 10000 + b.h) then
        T.text(self, hd.title, pad, pad, T.color.bright, T.fontHeader)
        -- a long name or a long word for "day" must not run into the title
        local room = w - pad * 3 - T.measure(T.fontHeader, hd.title)
        -- (in capitals, in the heavier caption font, on the title's middle)
        local wf = T.fontCaps
        T.textRight(self, T.fit(hd.who, wf, room), w - pad, pad + math.floor((fh - T.fontH(wf)) / 2), T.color.text, wf)

        -- model box frame
        T.rect(self, b.x, b.y, b.w, b.h, T.color.cell, T.modelAlpha())
        T.border(self, b.x, b.y, b.w, b.h, T.color.border)
        T.listEnd(L)
    end
end
