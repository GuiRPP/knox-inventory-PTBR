-- The game's hotbar (quick slots at the bottom of the screen, outside the
-- Knox screen) in Knox's look: the same tiles as the Knox screen's quick
-- slots - category tint, icon, 2 px frame, slot number, slot name over the
-- hovered one, a sand frame on what is in hand.
--
-- Only the look and the sizes change; clicks, keys, drag and drop and the
-- slots themselves stay the game's (its getSlotIndexAt reads the same sizes).

require "Hotbar/ISHotbar"
require "ISUI/ISEquippedItem"
require "ISUI/ISInventoryPaneContextMenu"
require "Knox/KnoxTheme"
require "Knox/KnoxTooltip"
require "Knox/KnoxSlotPicker"
require "Knox/KnoxEquipment"
require "Knox/KnoxControls"
require "Knox/KnoxHotbarOrder"

local T = KnoxTheme
local O = KnoxHotbarOrder

-- without the Java part the game's hotbar stays as it is (see KnoxTheme.active);
-- with the "hotbar" module off too - nothing of the game's bar is touched, so
-- another mod's hotbar (Clean UI...) is drawn as that mod wants
if not T.on("hotbar") then return end

--- Does the hotbar of this player carry the hands (the Knox look is on)?
local function withHands(hb)
    return Knox ~= nil and Knox.forPlayer ~= nil and Knox.forPlayer(hb.playerNum, "hotbar")
end

--- Width of the hands part on the left: two tiles, then a gap with a line.
local function handsW(hb)
    if not withHands(hb) then return 0 end
    return hb.slotWidth * 2 + hb.slotPad + hb.slotPad * 3
end

--- Knox's sizes on the hotbar: slots like the Knox screen's quick slots.
local function applySizes(hb)
    T.ensure()
    local size = math.floor(T.cell * 1.17 + 0.5)
    local gap = math.max(4, math.floor(T.cell / 6))
    local margin = math.max(4, math.floor(T.pad / 2))
    local hands = withHands(hb)
    if hb.slotWidth ~= size or hb.slotPad ~= gap or hb.margins ~= margin or hb.knoxHands ~= hands then
        hb.slotWidth, hb.slotHeight, hb.slotPad, hb.margins = size, size, gap, margin
        hb.knoxHands = hands
        hb:setHeight(size + margin * 2 + 2)
        hb:setSizeAndPosition()
    end
end

-- The hands part widens the bar; the game's slot under the mouse is found
-- right of it (its clicks, drops and menus keep working on the slots).
local sizeAndPosition = ISHotbar.setSizeAndPosition
function ISHotbar:setSizeAndPosition()
    sizeAndPosition(self)
    local extra = handsW(self)
    if extra > 0 then
        self:setWidth(self.width + extra)
        self:setX(getPlayerScreenLeft(self.playerNum) + (getPlayerScreenWidth(self.playerNum) - self.width) / 2)
    end
end

-- (the slots are shown in the player's order: KnoxHotbarOrder)
local slotIndexAt = ISHotbar.getSlotIndexAt
function ISHotbar:getSlotIndexAt(x, y)
    local pos = slotIndexAt(self, x - handsW(self), y)
    if pos == -1 then return -1 end
    return O.indexAt(self, pos)
end

--- The place a slot is shown at under x (1 = leftmost), or -1.
function ISHotbar:knoxPositionAt(x, y)
    return slotIndexAt(self, x - handsW(self), y)
end

-- hotbar key N is the slot shown Nth
local slotForKey = ISHotbar.getSlotForKey
function ISHotbar:getSlotForKey(key)
    local pos = slotForKey(self, key)
    if pos == -1 then return -1 end
    return O.indexAt(self, pos)
end

--- The thin meter along a tile's bottom, as on the Knox grids: condition of a
--- weapon, what is left of a battery or tape.
local function drawMeter(ui, item, x, y, w, h)
    if instanceof(item, "HandWeapon") and item:getConditionMax() > 0 then
        local f = item:getCondition() / math.max(1, item:getConditionMax())
        local c = f > 0.5 and T.color.good or (f > 0.25 and T.color.warn or T.color.bad)
        T.tileMeter(ui, x, y, w, h, f, c, 1, 0)
    elseif item:IsDrainable() then
        T.tileMeter(ui, x, y, w, h, item:getCurrentUsesFloat(), T.color.accent, 1, 0)
    end
end

local function inHand(chr, item)
    return item == chr:getPrimaryHandItem() or item == chr:getSecondaryHandItem()
end

-- One stand-in per hotbar slot for the quick pick panel: where the slot is on
-- screen (the panel opens above it) and a cache of what fits it.
local SlotRef = {}
SlotRef.__index = SlotRef
function SlotRef:getAbsoluteX() return self.hb:getAbsoluteX() + handsW(self.hb) + self.hb.margins + 1 + (O.positionOf(self.hb, self.i) - 1) * (self.hb.slotWidth + self.hb.slotPad) end
function SlotRef:getAbsoluteY() return self.hb:getAbsoluteY() + self.hb.margins + 1 end
function SlotRef:getWidth() return self.hb.slotWidth end
function SlotRef:getHeight() return self.hb.slotHeight end

local function slotRef(hb, i)
    hb.knoxRefs = hb.knoxRefs or {}
    local r = hb.knoxRefs[i]
    if not r then
        r = setmetatable({hb = hb, i = i}, SlotRef)
        hb.knoxRefs[i] = r
    end
    return r
end

--- Carried items that can hang in slot i, and what choosing one does.
local function offer(hb, i, slot)
    local ref = slotRef(hb, i)
    local chr = hb.chr
    local items = KnoxEquip.candidates(ref, chr, function(it)
        return it:getAttachmentType() ~= nil and hb:canBeAttached(slot, it)
    end)
    local pick = function(it)
        KnoxGrid.track(chr, {it}, KnoxEquip.gridSourceOf(it, chr), {kind = "slot", id = "quick:" .. i}, function()
            hb:attachItem(it, slot.def.attachments[it:getAttachmentType()], i, slot.def, true)
        end)
    end
    return ref, items, pick
end

function ISHotbar:render()
    if (self.playerNum > 0) or JoypadState.players[self.playerNum + 1] then
        self:setVisible(false)   -- as the game does: update() keeps running for refresh()
    end
    -- the Knox screen has its own quick slots over it
    if KnoxScreen and KnoxScreen.instance then return end
    applySizes(self)

    local w, h = self.width, self.height
    -- plate: the Knox bottom bar's color, a thin frame
    T.rect(self, 0, 0, w, h, T.color.header, 0.85)
    T.border(self, 0, 0, w, h, T.color.border)

    local over = self:getSlotIndexAt(self:getMouseX(), self:getMouseY())
    local dragged = nil
    if ISMouseDrag.dragging and over ~= -1 then
        local slot = self.availableSlot[over]
        for _, it in ipairs(ISInventoryPane.getActualItems(ISMouseDrag.dragging)) do
            if self:canBeAttached(slot, it) then dragged = it break end
        end
    end

    local size, y = self.slotWidth, self.margins + 1
    self:drawHands()
    local x = handsW(self) + self.margins + 1
    local moving = self.knoxSlotDrag and self.knoxSlotDrag.moved and self.knoxSlotDrag or nil
    for pos, i in ipairs(O.order(self)) do
        local slot = self.availableSlot[i]
        local item = self.attachedItems[i]
        local hot = i == over and not moving
        T.rect(self, x, y, size, size, T.color.cell)
        if hot and dragged then item = dragged end
        if item then
            T.rect(self, x, y, size, size, T.category[T.categoryOf(item)])
            local side = math.floor(size * 0.66)
            -- just hung here: it settles in (one memory per slot)
            self.knoxSlotSettle = self.knoxSlotSettle or {}
            self.knoxSlotSettle[i] = self.knoxSlotSettle[i] or {}
            local dy, da = T.settleIn(self.knoxSlotSettle[i], self.attachedItems[i])
            ISInventoryItem.renderItemIcon(self, item, x + math.floor((size - side) / 2), y + math.floor((size - side) / 2) + dy, da, side, side)
            drawMeter(self, item, x, y, size, size)
        elseif slot.texture then
            -- an empty slot: the game's faint picture of what goes there
            local side = math.floor(size * 0.5)
            self:drawTextureScaledAspect(slot.texture, x + math.floor((size - side) / 2), y + math.floor((size - side) / 2), side, side, 0.2, 1, 1, 1)
        end
        T.text(self, tostring(pos), x + 4, y + 1, T.color.dim, T.fontTile)   -- (hotbar key N: the Nth shown)
        if moving and moving.index == i then self:drawRect(x, y, size, size, 0.55, 0, 0, 0) end   -- being moved

        -- an empty slot under the mouse: how many carried items can hang here, and
        -- the quick pick panel above it when some can (as in the Knox screen)
        local offered = false
        if not item and not ISMouseDrag.dragging then
            local ref = slotRef(self, i)
            local open = KnoxSlotPicker.isOpenFor(ref)
            if hot or open then
                local _, cands, pick = offer(self, i, slot)
                if hot then
                    local c = #cands > 0 and T.color.accent or T.color.dim
                    T.textCentre(self, tostring(#cands), x + math.floor(size / 2), y + math.floor((size - T.fontH(T.fontText)) / 2), c, T.fontText)
                end
                if #cands > 0 then
                    offered = true
                    local name = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name
                    if hot then KnoxSlotPicker.want(ref, name, cands, pick, "above", self.playerNum) end
                end
            end
        end

        local edge = item and T.color.tileFrame or T.color.tileEdge
        if hot then
            if ISMouseDrag.dragging then
                local c = dragged and T.color.ok or T.color.bad
                self:drawRect(x, y, size, size, 0.22, c.r, c.g, c.b)
                edge = c
            else
                self:drawRect(x, y, size, size, 0.06, 1, 1, 1)
                edge = item and T.color.tileHover or T.color.hoverEdge
            end
        end
        if item and inHand(self.chr, item) then edge = T.color.accent end   -- taken in hand
        -- the item's tooltip (shown before the next frame by KnoxSlotPicker's OnPreUIDraw)
        if hot and item and not ISMouseDrag.dragging then KnoxTooltip.want(item, self.playerNum) end
        if item then T.tileFrame(self, x, y, size, size, edge) else T.border(self, x, y, size, size, edge) end
        if offered then T.target(self, x, y, size, size) end   -- its quick pick panel

        -- the hovered slot's name above the bar, in a small plate (the quick pick
        -- panel has it in its header)
        if hot and not offered then
            local name = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name
            local f = T.fontTile
            local tw, th = T.measure(f, name) + 10, T.fontH(f) + 4
            local tx = x + math.floor((size - tw) / 2)
            T.rect(self, tx, -th - 4, tw, th, T.color.window, 0.92)
            T.border(self, tx, -th - 4, tw, th, T.color.tileFrame)
            T.text(self, name, tx + 5, -th - 2, T.color.text, f)
        end
        x = x + size + self.slotPad
    end
end

-- Hands ----------------------------------------------------------------------------
-- What is in the hands, on the left of the bar (in place of the game's pictures
-- at the top left of the screen): the right hand, the left hand, a two-handed
-- thing across both. Condition along the bottom, a gun's rounds in the corner.
-- Hover: the tooltip; click: out of the hand; right click: its menu; an item
-- dropped from a game window: into that hand.

--- {x, y, w, h, primary, item} for each tile to draw (one when both hands hold one thing).
function ISHotbar:handRects()
    if not withHands(self) then return {} end
    local size, y = self.slotWidth, self.margins + 1
    local x1 = self.margins + 1
    local x2 = x1 + size + self.slotPad
    local p, s = self.chr:getPrimaryHandItem(), self.chr:getSecondaryHandItem()
    if p and p == s then
        return {{x1, y, size * 2 + self.slotPad, size, true, p, both = true}}
    end
    -- switched: left hand (secondary) on the left, right hand (primary) on the right
    return {{x1, y, size, size, false, s}, {x2, y, size, size, true, p}}
end

function ISHotbar:handAt(mx, my)
    for _, r in ipairs(self:handRects()) do
        if T.inRect(mx, my, r) then return r end
    end
    return nil
end

--- An open palm in the middle of an empty hand's tile x, y, w, h: Knox's own
--- smooth pictures (tools/make_hands.ps1 draws them, white, leaning outwards:
--- the left hand to the left, the right one to the right), tinted the grey of
--- an empty tile's frame.
local palmTex = {}
local function drawPalm(ui, x, y, w, h, primary)
    local key = primary and "right" or "left"
    if palmTex[key] == nil then palmTex[key] = getTexture("media/ui/knox_hand_" .. key .. ".png") or false end
    local tex = palmTex[key]
    if not tex then return end
    local c = T.color.tileEdge
    local side = math.floor(math.min(w, h) * 0.78)
    ui:drawTextureScaledAspect(tex, x + math.floor((w - side) / 2), y + math.floor((h - side) / 2), side, side, 1, c.r, c.g, c.b)
end

function ISHotbar:drawHands()
    local rects = self:handRects()
    if #rects == 0 then return end
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    for _, r in ipairs(rects) do
        local x, y, w, h, item = r[1], r[2], r[3], r[4], r[6]
        local hot = over and T.inRect(mx, my, r)
        T.rect(self, x, y, w, h, T.color.cell)
        if item then
            -- only draw category color when there's an actual item
            T.rect(self, x, y, w, h, T.category[T.categoryOf(item)])
            local side = math.floor(h * 0.66)
            -- just taken in this hand: it settles in
            self.knoxHandSettle = self.knoxHandSettle or {}
            local hk = r.both and "both" or (r[5] and "right" or "left")
            self.knoxHandSettle[hk] = self.knoxHandSettle[hk] or {}
            local dy, da = T.settleIn(self.knoxHandSettle[hk], item)
            ISInventoryItem.renderItemIcon(self, item, x + math.floor((w - side) / 2), y + math.floor((h - side) / 2) + dy, da, side, side)
            drawMeter(self, item, x, y, w, h)
            -- a gun's rounds: loaded / magazine
            if instanceof(item, "HandWeapon") and item:isRanged() then
                local text = tostring(item:getCurrentAmmoCount()) .. "/" .. tostring(item:getMaxAmmo())
                T.outlinedRight(self, text, x + w - 4, y + h - T.fontTileH - 6, T.color.bright, T.fontTile)
            end
            if hot and not ISMouseDrag.dragging then KnoxTooltip.want(item, self.playerNum) end
        end
        -- an empty hand: a small grey palm in the middle of the tile (no
        -- caption); with something in the hand it goes
        if not item then drawPalm(self, x, y, w, h, r[5]) end
        local edge = item and T.color.accent or T.color.tileEdge   -- in hand: the sand frame
        if hot then
            if ISMouseDrag.dragging then
                local c = T.color.ok
                self:drawRect(x, y, w, h, 0.22, c.r, c.g, c.b)
                edge = c
            else
                self:drawRect(x, y, w, h, 0.06, 1, 1, 1)
                edge = item and T.color.tileHover or T.color.hoverEdge
            end
        end
        if item then T.tileFrame(self, x, y, w, h, edge) else T.border(self, x, y, w, h, edge) end
    end
end

-- Dragging out of a hand (the author's wish, 2026-10-15): pressed on a hand's
-- tile and moved a few pixels, the thing follows the mouse; let go off the
-- hotbar - over the world - it is dropped on the ground (the game's own "Drop":
-- out of the hand first, a heavy thing too). Let go on the hotbar, nothing
-- happens. A press without a move stays a click (out of the hand).
local DRAG_PX = 6

local mouseDown = ISHotbar.onMouseDown
function ISHotbar:onMouseDown(x, y)
    -- with the slot-moving key held (Alt unless set otherwise): a slot is taken to another place
    if KnoxControls.isHeld("hotbarMove") and not ISMouseDrag.dragging then
        local pos = self:knoxPositionAt(x, y)
        if pos ~= -1 and not self:handAt(x, y) then
            self.knoxSlotDrag = {index = O.indexAt(self, pos), x = getMouseX(), y = getMouseY()}
            return true
        end
    end
    local r = self:handAt(x, y)
    if r and r[6] then
        self.knoxHandDrag = {item = r[6], x = getMouseX(), y = getMouseY()}
        return true
    end
    if mouseDown then return mouseDown(self, x, y) end
    return false
end

local function handDragMoved(d)
    return d.moved or math.abs(getMouseX() - d.x) + math.abs(getMouseY() - d.y) >= DRAG_PX
end

function ISHotbar:onMouseUpOutside(x, y)
    self.knoxSlotDrag = nil   -- a slot let go off the bar: it stays where it was
    local d = self.knoxHandDrag
    self.knoxHandDrag = nil
    if not d or not handDragMoved(d) then return end
    local item = d.item
    if item:getContainer() ~= self.chr:getInventory() then return end
    -- over another window (chat, the sidebar): not the world, nothing happens
    local over = false
    pcall(function()
        local ui = UIManager.getUI()
        for i = 0, ui:size() - 1 do
            local el = ui:get(i)
            if el ~= self.javaObject and el:isVisible() and el:isMouseOver() then over = true break end
        end
    end)
    if over then return end
    -- (a favorite is not dropped, as by the game's own "Drop")
    if item:isFavorite() then return end
    ISInventoryPaneContextMenu.dropItem(item, self.playerNum)
end

--- A slot being moved: its tile at the mouse, a sand frame where it would go.
local function drawSlotDrag(hb)
    local sd = hb.knoxSlotDrag
    if not sd then return end
    if not isMouseButtonDown(0) then
        hb.knoxSlotDrag = nil
        return
    end
    if not handDragMoved(sd) then return end
    sd.moved = true
    local size, pad = hb.slotWidth, hb.slotPad
    local pos = hb:knoxPositionAt(hb:getMouseX(), math.floor(hb.height / 2))
    if pos ~= -1 then
        local tx = handsW(hb) + hb.margins + 1 + (pos - 1) * (size + pad)
        T.tileFrame(hb, tx - 2, hb.margins - 1, size + 4, size + 4, T.color.accent)
    end
    local mx, my = getMouseX() - hb:getAbsoluteX(), getMouseY() - hb:getAbsoluteY()
    local x, y = math.floor(mx - size / 2), math.floor(my - size / 2)
    local item = hb.attachedItems[sd.index]
    T.rect(hb, x, y, size, size, item and T.category[T.categoryOf(item)] or T.color.cell, 0.9)
    if item then
        local side = math.floor(size * 0.66)
        ISInventoryItem.renderItemIcon(hb, item, x + math.floor((size - side) / 2), y + math.floor((size - side) / 2), 1, side, side)
    end
    T.tileFrame(hb, x, y, size, size, T.color.accent)
end

local knoxRender = ISHotbar.render
function ISHotbar:render()
    knoxRender(self)
    if not (KnoxScreen and KnoxScreen.instance) then drawSlotDrag(self) end
    local d = self.knoxHandDrag
    if not d then return end
    if not isMouseButtonDown(0) then
        -- (let go somewhere no event told us about)
        self.knoxHandDrag = nil
        return
    end
    if KnoxScreen and KnoxScreen.instance then return end
    if not handDragMoved(d) then return end
    d.moved = true
    -- the thing at the mouse, as a tile being dragged in the Knox screen
    local size = self.slotWidth
    local mx, my = getMouseX() - self:getAbsoluteX(), getMouseY() - self:getAbsoluteY()
    -- (a generator and the like shake, tile and all: hard to hold up - KnoxGridView.strain)
    local sx, sy = 0, 0
    if KnoxGridView and KnoxGridView.strain then sx, sy = KnoxGridView.strain(KnoxGrid.weightOf(d.item)) end
    local x, y = math.floor(mx - size / 2) + sx, math.floor(my - size / 2) + sy
    T.rect(self, x, y, size, size, T.category[T.categoryOf(d.item)], 0.85)
    local side = math.floor(size * 0.66)
    ISInventoryItem.renderItemIcon(self, d.item, x + math.floor((size - side) / 2), y + math.floor((size - side) / 2), 1, side, side)
    T.tileFrame(self, x, y, size, size, T.color.accent)
end

local mouseUp = ISHotbar.onMouseUp
function ISHotbar:onMouseUp(x, y)
    local sd = self.knoxSlotDrag
    if sd then
        -- a slot let go on the bar: shown there from now on (a press without a move: nothing)
        self.knoxSlotDrag = nil
        if sd.moved then
            local pos = self:knoxPositionAt(x, math.floor(self.height / 2))
            if pos ~= -1 and pos ~= O.positionOf(self, sd.index) then
                O.move(self, sd.index, pos)
                getSoundManager():playUISound("UIActivateButton")
            end
        end
        return true
    end
    local d = self.knoxHandDrag
    self.knoxHandDrag = nil
    if d and handDragMoved(d) then return true end   -- dragged and let go on the bar: nothing
    local r = self:handAt(x, y)
    if r then
        local item = r[6]
        if ISMouseDrag.dragging then
            -- an item from a game window: into this hand
            for _, it in ipairs(ISInventoryPane.getActualItems(ISMouseDrag.dragging)) do
                if it ~= item and not it:IsClothing() then
                    ISInventoryPaneContextMenu.equipWeapon(it, r[5], it:isTwoHandWeapon(), self.playerNum)
                    break
                end
            end
        elseif item then
            ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
        end
        return true
    end
    return mouseUp(self, x, y)
end

local rightMouseUp = ISHotbar.onRightMouseUp
function ISHotbar:onRightMouseUp(x, y)
    local r = self:handAt(x, y)
    if r then
        if r[6] then
            ISInventoryPaneContextMenu.createMenu(self.playerNum, true, {r[6]}, getMouseX(), getMouseY())
        end
        return true
    end
    return rightMouseUp(self, x, y)
end

-- The game's pictures of the hands at the top left (its sidebar) go: the hands
-- are on the hotbar now. The sidebar's buttons move up into their place.
local equippedInit = ISEquippedItem.initialise
function ISEquippedItem:initialise()
    equippedInit(self)
    if not (Knox and Knox.forPlayer and Knox.forPlayer(self.chr:getPlayerNum(), "hotbar")) then return end
    local main, off = self.mainHand, self.offHand
    if not (main and off) then return end
    local dy = off:getBottom() - main:getY()
    if self.invBtn then dy = self.invBtn:getY() - main:getY() end
    for _, child in pairs(self.children or {}) do
        if child ~= main and child ~= off then child:setY(child:getY() - dy) end
    end
    -- the furniture button's popup (pick up, place, rotate...) is no child of
    -- the sidebar but a window of its own, placed over its button: left where
    -- it was, it opened a few buttons lower - away from the mouse, so it shut
    -- at once and covered the buttons under it
    if self.movablePopup then self.movablePopup:setY(self.movablePopup:getY() - dy) end
    main:setVisible(false)
    off:setVisible(false)
    -- the hand pictures are drawn at these places: far off the screen
    main:setX(-100000)
    off:setX(-100000)
    self:setHeight(math.max(1, self:getHeight() - dy))
    -- and their hover hints go with them
    local keep = {}
    local p, s = getText("IGUI_PrimaryTooltip"), getText("IGUI_SecondaryTooltip")
    for _, m in ipairs(self.mouseOverList or {}) do
        if m.displayString ~= p and m.displayString ~= s then table.insert(keep, m) end
    end
    self.mouseOverList = keep
end
