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
    -- hidden or on its way: lowered under the screen's edge (see "Hiding" below)
    self.knoxBaseY = self:getY()
    if self.knoxHideOff and self.knoxHideOff ~= 0 then self:knoxLower() end
end

--- The bar at its place lowered by knoxHideOff. (A window of its own is kept on the screen
--- by the game's setY - getKeepOnScreen: not while lowered, or it stayed where it was and
--- only its plate was left, the author 2026-11-10.)
function ISHotbar:knoxLower()
    local off = self.knoxHideOff or 0
    if off ~= 0 then
        self.keepOnScreen = false
    elseif self.keepOnScreen == false then
        self.keepOnScreen = nil
    end
    if self.knoxBaseY then self:setY(self.knoxBaseY + off) end
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

-- The same for a hand's tile (a gun in hand: its magazine panel, 2026-10-30):
-- where the tile was drawn last.
local HandRef = {}
HandRef.__index = HandRef
function HandRef:getAbsoluteX() return self.hb:getAbsoluteX() + self.x end
function HandRef:getAbsoluteY() return self.hb:getAbsoluteY() + self.y end
function HandRef:getWidth() return self.w end
function HandRef:getHeight() return self.h end

local function handRef(hb, key, x, y, w, h)
    hb.knoxHandRefs = hb.knoxHandRefs or {}
    local r = hb.knoxHandRefs[key]
    if not r then
        r = setmetatable({hb = hb}, HandRef)
        hb.knoxHandRefs[key] = r
    end
    r.x, r.y, r.w, r.h = x, y, w, h
    return r
end

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

-- The bar from a ready list (the overhaul's stage 3, 2026-11-04: by knox_perf.txt the dearest
-- thing of Knox's with the screen shut, 150-190 us a frame, what it shows hardly ever changing).
-- While the mouse is off it, nothing is dragged, no panel is open and nothing is settling in,
-- Java draws it again in one call; in all the rest Lua draws it as before. What it shows is
-- kept in hb.knoxBarShows and looked at every frame: the slots, their faint pictures and what
-- hangs in them, the hands, a gun's rounds in hand. A tile's height and colour one tile a
-- frame, in turn (a burning torch's charge moves all the time, what shows of it seldom).
-- Nothing new is made in a frame.
local barLists = {}   -- (one per player and for good: Java keeps every list)

local function isGun(item)
    return item ~= nil and instanceof(item, "HandWeapon") and item:isRanged()
end

--- Tile `at`'s thing: the slots, then the hands.
local function tileAt(hb, at, n, p, s)
    if at <= n then return hb.attachedItems[at] end
    if at == n + 1 then return p end
    return s
end

--- What shows of tile `at`'s state: its height, as T.levelKey has it.
local function levelShown(shows, at, item, size)
    if not item then return false end
    if shows.levelFor[at] ~= item then shows.levelFor[at], shows.levelFrom[at] = item, T.levelKind(item) end
    return T.levelKey(item, size, T.itemLevel(item, shows.levelFrom[at]))
end

local function barRemember(hb, n, p, s)
    local shows = hb.knoxBarShows
    if not shows then
        shows = {stamp = 0, at = 0, slot = {}, tex = {}, item = {}, level = {}, cat = {}, levelFor = {}, levelFrom = {}}
        hb.knoxBarShows = shows
    end
    shows.stamp = shows.stamp + 1
    shows.n, shows.p, shows.s, shows.hands = n, p, s, hb.knoxHands
    shows.order, shows.hide = T.settings["hotbar.order"], KnoxMagKnown and KnoxMagKnown.hide
    shows.gunP, shows.gunS = isGun(p), isGun(s)
    shows.ammoP, shows.maxP = shows.gunP and p:getCurrentAmmoCount(), shows.gunP and p:getMaxAmmo()
    shows.ammoS, shows.maxS = shows.gunS and s:getCurrentAmmoCount(), shows.gunS and s:getMaxAmmo()
    for i = 1, n do
        local slot = hb.availableSlot[i]
        shows.slot[i], shows.tex[i], shows.item[i] = slot, slot.texture, hb.attachedItems[i]
    end
    for at = 1, n + 2 do
        local item = tileAt(hb, at, n, p, s)
        shows.level[at] = levelShown(shows, at, item, hb.slotWidth)
        shows.cat[at] = item and T.categoryOf(item) or false
    end
end

--- Is the bar as its list has it? (No: Lua draws it this frame.)
local function barQuiet(hb)
    -- (T.settleIn wants no list: what is settling in changes every frame)
    if hb.knoxBarBusy ~= false or hb.knoxSlotDrag or hb.knoxHandDrag or ISMouseDrag.dragging
            or KnoxSlotPicker.instance then
        return false
    end
    local mx, my = hb:getMouseX(), hb:getMouseY()
    -- (getSlotIndexAt's reach, the hands' width past the right edge with it)
    if my >= 0 and my < hb.height and mx >= 0 and mx < hb.width + handsW(hb) then return false end
    local shows = hb.knoxBarShows
    local slots, items, chr = hb.availableSlot, hb.attachedItems, hb.chr
    local n = #slots
    local p, s = chr:getPrimaryHandItem(), chr:getSecondaryHandItem()
    local same = shows ~= nil and shows.n == n and shows.p == p and shows.s == s and shows.hands == hb.knoxHands
        and shows.order == T.settings["hotbar.order"] and shows.hide == (KnoxMagKnown and KnoxMagKnown.hide)
    if same then
        for i = 1, n do
            -- (the picture apart: other clothes giving the same slot change it on the same table)
            local slot = slots[i]
            if shows.slot[i] ~= slot or shows.tex[i] ~= slot.texture or shows.item[i] ~= items[i] then
                same = false
                break
            end
        end
    end
    if same and shows.gunP and (shows.ammoP ~= p:getCurrentAmmoCount() or shows.maxP ~= p:getMaxAmmo()) then same = false end
    if same and shows.gunS and (shows.ammoS ~= s:getCurrentAmmoCount() or shows.maxS ~= s:getMaxAmmo()) then same = false end
    if same then
        local at = shows.at % (n + 2) + 1
        shows.at = at
        local item = tileAt(hb, at, n, p, s)
        if shows.level[at] ~= levelShown(shows, at, item, hb.slotWidth)
                or shows.cat[at] ~= (item and T.categoryOf(item) or false) then
            same = false
        end
    end
    if same then return true end
    barRemember(hb, n, p, s)
    return false
end

function ISHotbar:render()
    if (self.playerNum > 0) or JoypadState.players[self.playerNum + 1] then
        self:setVisible(false)   -- as the game does: update() keeps running for refresh()
    end
    -- the Knox screen has its own quick slots over it - from its first frame drawn, not
    -- before: the game draws a window it was just given only a frame later, and that frame
    -- (the slow one, before the screen's first) showed the bar gone and no screen yet (the
    -- author, 2026-11-10: "first you see it vanish, then the menu opens")
    local screen = KnoxScreen and KnoxScreen.instance
    if screen and screen.knoxDrawn then return end
    applySizes(self)

    local w, h = self.width, self.height
    local L = barLists[self.playerNum]
    if not L then
        L = T.newList()
        barLists[self.playerNum] = L
    end
    if not L.dead and T.listsOn() and barQuiet(self) then
        if T.listDraw(self, L, w, h, self.slotWidth, self.knoxBarShows.stamp) then return end
    elseif L.writing then
        -- a frame being written fell over a Lua error and no T.listDraw comes now to start it
        -- anew: thrown away, or what is drawn now (the mouse's glow) stays in it for good
        T.listEnd(L)
        L.ok = false
    end
    self.knoxBarBusy = false

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
            -- just hung here: it settles in (one memory per slot)
            self.knoxSlotSettle = self.knoxSlotSettle or {}
            self.knoxSlotSettle[i] = self.knoxSlotSettle[i] or {}
            local memo = self.knoxSlotSettle[i]
            -- (its state: the colour's height, condition_v3, the author, 2026-10-31)
            T.tileFill(self, x, y, size, size, T.levelOf(memo, item), T.category[T.categoryOf(item)])
            local side = math.floor(size * 0.66)
            local dy, da = T.settleIn(memo, self.attachedItems[i])
            if dy ~= 0 or da ~= 1 then self.knoxBarBusy = true end
            T.itemIcon(self, item, x + math.floor((size - side) / 2), y + math.floor((size - side) / 2) + dy, side, da)
        elseif slot.texture then
            -- an empty slot: the game's faint picture of what goes there
            local side = math.floor(size * 0.5)
            self:drawTextureScaledAspect(slot.texture, x + math.floor((size - side) / 2), y + math.floor((size - side) / 2), side, side, 0.2, 1, 1, 1)
        end
        T.outlinedLeft(self, tostring(pos), x + 4, y + 1, T.color.dim, T.fontTile)   -- (hotbar key N: the Nth shown)
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
        -- a gun hung here: its magazine / rounds panel above it (KnoxLoad, 2026-10-30)
        if item and hot and not ISMouseDrag.dragging and KnoxLoad and instanceof(item, "HandWeapon") then
            KnoxLoad.offer(KnoxLoad.refOf(slotRef(self, i)), item, self.chr, self.playerNum, "above")
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
        -- (a gun with its panel above - the quick items' key held: no tooltip over
        -- the panel's cells, 2026-10-30)
        if hot and item and not ISMouseDrag.dragging then
            KnoxTooltip.want(item, self.playerNum,
                KnoxLoad and KnoxLoad.tipQuiet(item, instanceof(item, "HandWeapon") and KnoxLoad.panelOf(item) == "gun"))
        end
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
    T.listEnd(L)
end

-- Hands ----------------------------------------------------------------------------
-- What is in the hands, on the left of the bar (in place of the game's pictures
-- at the top left of the screen): the right hand, the left hand, a two-handed
-- thing across both, its state as its colour's height.
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
            -- just taken in this hand: it settles in
            self.knoxHandSettle = self.knoxHandSettle or {}
            local hk = r.both and "both" or (r[5] and "right" or "left")
            self.knoxHandSettle[hk] = self.knoxHandSettle[hk] or {}
            local memo = self.knoxHandSettle[hk]
            -- only draw category color when there's an actual item
            T.tileFill(self, x, y, w, h, T.levelOf(memo, item), T.category[T.categoryOf(item)])
            local side = math.floor(h * 0.66)
            local dy, da = T.settleIn(memo, item)
            if dy ~= 0 or da ~= 1 then self.knoxBarBusy = true end
            T.itemIcon(self, item, x + math.floor((w - side) / 2), y + math.floor((h - side) / 2) + dy, side, da)
            -- a gun's rounds: loaded / magazine
            if not (KnoxMagKnown and KnoxMagKnown.hide) and instanceof(item, "HandWeapon") and item:isRanged() then
                local text = tostring(item:getCurrentAmmoCount()) .. "/" .. tostring(item:getMaxAmmo())
                T.outlinedRight(self, text, x + w - 4, y + h - T.fontTileH - 6, T.color.bright, T.fontTile)
            end
            -- a gun in hand: its magazine / rounds panel above it, the quick items'
            -- key pressed - in place of its tooltip (the author's bench, 2026-10-30:
            -- nothing came up in hand)
            if hot and not ISMouseDrag.dragging then
                local gun = KnoxLoad and instanceof(item, "HandWeapon") and KnoxLoad.panelOf(item) == "gun"
                if gun then
                    KnoxLoad.offer(KnoxLoad.refOf(handRef(self, hk, x, y, w, h)), item, self.chr, self.playerNum, "above")
                end
                KnoxTooltip.want(item, self.playerNum, gun and KnoxLoad.tipQuiet(item, true))
            end
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

-- Hiding (the author, 2026-11-10: "the hotbar outside the inventory hides while it is not
-- in use and shows when you switch things, when a new thing comes into your hands, when the
-- mouse comes over its place... the action key calls it up for a while; down when it hides,
-- up when it shows; a setting in Knox, and a setting for its transparency").
-- Every frame update() looks whether something happened to the bar - the hands' things, a
-- slot hung or emptied, the mouse over its place, something dragged (not while the Knox
-- screen is open: nothing done there calls it up) - and keeps it up for the setting's seconds after the last of it; then
-- it slides down under the screen's edge (setSizeAndPosition lowers it by knoxHideOff). The
-- interact key, held down, calls it up only when it did nothing in the world and nothing was looked at:
-- no Viewpoint panel up, no Knox window open, the hero not climbing, opening a door, busy
-- with an action (the author, the same day). Nothing new is made in a frame.
local HIDE_UP_MS, HIDE_DOWN_MS = 180, 320   -- the slide up / down
-- The interact key calls it up held down, a little longer than the game's own hold that
-- climbs through a window or over a fence (IsoPlayer timePressedContext > 0.5 s): a short
-- press brought it up as the hero climbed (the author, 2026-11-10)
local KEY_HOLD_MS = 800
local KEY_DONE_MS = 250   -- (what the key did a moment before it was seen pressed counts too)

local function hideOn() return T.switch("hotbar.hide") end

--- The bar's alpha (the setting, 1 = as it is).
local function barAlpha() return T.look("hotbar.alpha") / 100 end

local function wake(hb) hb.knoxAwake = getTimestampMs() end

--- Is the hero doing something the interact key may have started (or anything that is not free)?
local function busy(chr)
    if chr:isPerformingAnAction() or chr:isClimbing() or chr:isBlockMovement() then return true end
    local q = ISTimedActionQueue.queues[chr]
    return q ~= nil and #q.queue > 0
end

--- Would the interact key be for something else now (a panel at the crosshair, a window)?
local function keyTaken(hb)
    if knoxVpPanelShown and knoxVpPanelShown() == true then return true end
    if KnoxCompat and KnoxCompat.windowOpen and KnoxCompat.windowOpen() then return true end
    local radial = getPlayerRadialMenu and getPlayerRadialMenu(hb.playerNum)
    if radial and radial:isReallyVisible() then return true end
    return busy(hb.chr)
end

--- What happened to the bar since the last frame: kept up by it.
local function watch(hb)
    local chr = hb.chr
    local p, s = chr:getPrimaryHandItem(), chr:getSecondaryHandItem()
    local changed = p ~= hb.knoxWatchP or s ~= hb.knoxWatchS
    hb.knoxWatchP, hb.knoxWatchS = p, s
    -- the Knox screen open: what is done there does not call the bar up after it shuts
    -- (the author, 2026-11-10: "no need to show it after every opening of the inventory");
    -- shots and reloads neither (the same day: "no need when the rounds' count changes")
    if KnoxScreen and KnoxScreen.instance then return end
    if changed then wake(hb) end
    if hb.knoxSlotDrag or hb.knoxHandDrag or ISMouseDrag.dragging or KnoxSlotPicker.instance then
        wake(hb)
        return
    end
    -- the mouse where the bar stands when it is up
    local mx, my = getMouseX(), getMouseY()
    local bottom = getPlayerScreenTop(hb.playerNum) + getPlayerScreenHeight(hb.playerNum)
    local x = hb:getX()
    if mx >= x and mx < x + hb.width and my >= bottom - hb.height and my <= bottom then wake(hb) end
    -- the interact key held: up once held long enough, unless it did something meanwhile
    local at = hb.knoxKeyAt
    if at then
        local now = knoxNowMs()
        if knoxContextDoneAt() >= at - KEY_DONE_MS or busy(chr) or not isKeyDown(hb.knoxKeyCode) then
            hb.knoxKeyAt = nil
        elseif now - at >= KEY_HOLD_MS then
            hb.knoxKeyAt = nil
            wake(hb)
        end
    end
end

--- The slide: knoxHideP 0 (up) .. 1 (down), knoxHideOff the pixels it is lowered by.
-- (a step every frame drawn - prerender - and every update: the game's update runs fewer
-- times than frames are drawn, and the slide from it went in jerks, the author 2026-11-10;
-- what happened to the bar is looked at in update only)
local function slide(hb, watching)
    local now = getTimestampMs()
    local dt = now - (hb.knoxHideT or now)
    hb.knoxHideT = now
    local p = hb.knoxHideP or 0
    local down = false
    if hideOn() then
        hb.knoxAwake = hb.knoxAwake or now   -- (switched on: up for a while first)
        if watching then watch(hb) end
        down = now - hb.knoxAwake > T.look("hotbar.hideTime") * 1000
    end
    if down then
        if p >= 1 then return end
        p = math.min(1, p + T.anim(dt / HIDE_DOWN_MS))
    else
        if p <= 0 then return end
        p = math.max(0, p - T.anim(dt / HIDE_UP_MS))
    end
    hb.knoxHideP = p
    local off = math.floor((hb.height + 2) * p * p * (3 - 2 * p) + 0.5)
    if off ~= hb.knoxHideOff then
        hb.knoxHideOff = off
        hb:knoxLower()
    end
end

-- (keys: the interact key - held, see watch; a hotbar key - up at once)
local function onKeyStart(key)
    local hb = getPlayerHotbar and getPlayerHotbar(0)
    if not hb or not hb.chr or not hideOn() or not knoxNowMs then return end
    if hb:getSlotForKey(key) ~= -1 then
        wake(hb)
    elseif getCore():isKey("Interact", key) and not keyTaken(hb) then
        hb.knoxKeyAt, hb.knoxKeyCode = knoxNowMs(), key
    end
end
Events.OnKeyStartPressed.Add(onKeyStart)

-- a slot hung, emptied, the slots changed with the clothes: up
for _, name in ipairs({"attachItem", "removeItem", "refresh"}) do
    local was = ISHotbar[name]
    if was then
        ISHotbar[name] = function(self, ...)
            if hideOn() and not (KnoxScreen and KnoxScreen.instance) then wake(self) end
            return was(self, ...)
        end
    end
end

-- (the game's own plate under Knox's - ISPanel:prerender, half black and a grey frame - faded
-- with the rest, or it stayed dark under a see-through bar)
local panelPrerender = ISHotbar.prerender
function ISHotbar:prerender()
    slide(self, false)
    if not panelPrerender or (self.knoxHideP or 0) >= 1 then return end
    local a = barAlpha()
    if a < 1 and knoxUiPartAlpha then
        knoxUiPartAlpha(a)
        local ok, err = pcall(panelPrerender, self)
        knoxUiPartAlpha(1)
        if not ok then error(err, 0) end
    else
        panelPrerender(self)
    end
end

local knoxRender = ISHotbar.render
function ISHotbar:render()
    -- down under the screen's edge: nothing to draw
    if (self.knoxHideP or 0) >= 1 and not self.knoxHandDrag then return end
    -- the bar's transparency (the setting): everything it draws, scaled at once (Java, KnoxUiFade)
    local a = barAlpha()
    if a < 1 and knoxUiPartAlpha then
        knoxUiPartAlpha(a)
        local ok, err = pcall(knoxRender, self)
        knoxUiPartAlpha(1)
        if not ok then error(err, 0) end
    else
        knoxRender(self)
    end
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
    -- (the menu told what it is about: Knox's header and groups, as in the screen -
    -- the hotbar's came without them, the author's bench 2026-10-30)
    local r = self:handAt(x, y)
    if r then
        if r[6] then
            if KnoxContextMenu then KnoxContextMenu.setTarget({r[6]}, self.playerNum) end
            ISInventoryPaneContextMenu.createMenu(self.playerNum, true, {r[6]}, getMouseX(), getMouseY())
        end
        return true
    end
    local i = self:getSlotIndexAt(x, y)
    local item = i ~= -1 and self.attachedItems[i] or nil
    if item and KnoxContextMenu then KnoxContextMenu.setTarget({item}, self.playerNum) end
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

-- The game's own item tooltip of a hotbar slot (ISHotbar:update) lay right
-- under Knox's: Knox's went for the gun's panel, the game's stayed over it (the
-- author's bench, 2026-10-30). Knox shows the slot's tooltip itself (render) - only with its tooltips
-- on: off, the game's is the only one there is (QA, 2026-11-04).
local knoxUpdate = ISHotbar.update
function ISHotbar:update()
    slide(self, true)
    knoxUpdate(self)
    if T.on("tooltips") and self.toolRender and self.toolRender:getIsVisible() then self.toolRender:setVisible(false) end
end
