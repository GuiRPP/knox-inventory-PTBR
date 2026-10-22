-- Pouring between two fluid containers, in Knox's look - it takes the place
-- of the game's ISFluidTransferUI wherever the game opens that (an item's
-- context menu, a rain barrel or a sink in the world...). The game's own
-- rules and action do the work: FluidContainer.CanTransfer / GetTransferReason
-- / Transfer (also on a copy, for the preview), ISFluidTransferAction.
--
-- Source on the left, target on the right, each a slot and a tank: the fluid
-- in its color, what leaves the source shaded, what the target gets lit in the
-- color the mix will have. In the middle: swap, the amount (presets, slider,
-- wheel), the pour button that fills with the action's progress.
-- A slot of an item offers the carried containers that fit it in the quick
-- pick panel when the mouse is over it (as the equipment slots), takes a tile
-- dragged from a Knox grid, and is cleared with a right click.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxThread"
require "Knox/KnoxSlotPicker"

KnoxFluidWindow = ISPanel:derive("KnoxFluidWindow")
local F = KnoxFluidWindow
local T = KnoxTheme

F.instance = nil
F.lastX, F.lastY = nil, nil

local inRect = T.inRect

-- Helpers --------------------------------------------------------------------------

local function fluidOf(side)
    return side.wrap and side.wrap:getFluidContainer() or nil
end

local function ownerItem(side)
    local o = side.wrap and side.wrap:getOwner()
    if o and instanceof(o, "InventoryItem") then return o end
    return nil
end

local function colorOf(fc)
    local c = fc and fc:getColor()
    if not c then return T.color.liquid end
    return {r = c:getRedFloat(), g = c:getGreenFloat(), b = c:getBlueFloat()}
end

local function amountText(fc, v)
    if fc and fc:isHiddenAmount() then return getText("Fluid_Unknown") end
    return FluidUtil.getAmountFormatted(v)
end

--- Carried items whose fluid the player can pour (pockets, bags, hands).
local function carriedFluidItems(player, except)
    local out = {}
    local function walk(c, depth)
        local items = c:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local fc = it:getFluidContainer()
            if fc and fc:canPlayerEmpty() and it ~= except and not (KnoxSearch and KnoxSearch.unseen(it)) then
                table.insert(out, it)
            end
            if depth < 3 and instanceof(it, "InventoryContainer") and it:getInventory() then
                walk(it:getInventory(), depth + 1)
            end
        end
    end
    walk(player:getInventory(), 0)
    return out
end

-- A slot as the quick pick panel sees it: where it is on screen.
local SlotRef = {}
SlotRef.__index = SlotRef
function SlotRef:rect() return self.win:slotRect(self.side) end
function SlotRef:getAbsoluteX() return self.win:getAbsoluteX() + self:rect()[1] end
function SlotRef:getAbsoluteY() return self.win:getAbsoluteY() + self:rect()[2] end
function SlotRef:getWidth() return self:rect()[3] end
function SlotRef:getHeight() return self:rect()[4] end

-- Window ------------------------------------------------------------------------------

function KnoxFluidWindow:new(player, container, source)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.home = container
    o.isIso = not (container:isItem() or container:isResource())
    -- as the game: the container goes left when it was asked as the source or has fluid in it
    local left = source or not container:getFluidContainer():isEmpty()
    o.left = {wrap = left and container or nil}
    o.right = {wrap = (not left) and container or nil}
    o.frac = 1
    o.amount, o.maxPour, o.canPour = 0, 0, false
    o.background = false
    o.moveWithMouse = false
    return o
end

function KnoxFluidWindow:createChildren()
    local c, pad = T.cell, T.pad
    local L = {}
    L.headerH = T.sectionH + 4
    L.colW = math.floor(c * 3.4)
    L.midW = math.floor(c * 5)
    L.slotS = math.floor(c * 1.5)
    L.tankW = math.floor(c * 1.1)
    L.tankH = math.floor(c * 3.4)
    L.btnH = math.floor(c * 0.62 + 0.5)
    local ft, fc = T.fontH(T.fontText), T.fontH(T.fontCaps)
    L.top = L.headerH + pad
    L.capY = L.top
    L.slotY = L.capY + fc + 6
    L.nameY = L.slotY + L.slotS + 4
    L.tankY = L.nameY + ft + pad
    L.amountY = L.tankY + L.tankH + 6
    L.errY = L.amountY + ft + pad
    L.errH = ft + 8
    L.btnY = L.errY + L.errH + pad
    L.w = pad * 4 + L.colW * 2 + L.midW
    L.h = L.btnY + L.btnH + pad
    L.leftX = pad
    L.midX = pad * 2 + L.colW
    L.rightX = pad * 3 + L.colW + L.midW
    self.L = L
    self:setWidth(L.w)
    self:setHeight(L.h)
end

function KnoxFluidWindow:slotRect(side)
    local L = self.L
    local x = (side == self.left) and L.leftX or L.rightX
    return {x + math.floor((L.colW - L.slotS) / 2), L.slotY, L.slotS, L.slotS}
end

function KnoxFluidWindow:other(side)
    return side == self.left and self.right or self.left
end

--- Can this item go into that side? (as the game's verify: pourable, carried, not the other side's)
function KnoxFluidWindow:accepts(side, item)
    if self.locked or not item or (side.wrap and not ownerItem(side) and side.wrap == self.home) then return false end
    local fc = item:getFluidContainer()
    if not fc or not fc:canPlayerEmpty() or not item:isInPlayerInventory() then return false end
    return item ~= ownerItem(self:other(side))
end

--- Is this item in one of the open fluid window's slots? (its tile or slot
--- gets the sand frame, as the items of the other windows)
function F.isOpen(item)
    local w = F.instance
    return w ~= nil and item ~= nil and (ownerItem(w.left) == item or ownerItem(w.right) == item)
end

--- The slot's stand-in for the quick pick panel.
function KnoxFluidWindow:refOf(side)
    if not side.ref then side.ref = setmetatable({win = self, side = side}, SlotRef) end
    return side.ref
end

--- Carried containers that can go into this side (kept for half a second).
function KnoxFluidWindow:candidates(side)
    local now = getTimestampMs()
    if side.cands and now - side.candsMs < 500 then return side.cands end
    local out = {}
    for _, it in ipairs(carriedFluidItems(self.player, ownerItem(self:other(side)))) do
        if it ~= ownerItem(side) and self:accepts(side, it) then table.insert(out, it) end
    end
    side.cands, side.candsMs = out, now
    return out
end

--- Does this side take items? (a barrel or a sink stays where it is)
function KnoxFluidWindow:isItemSide(side)
    return not side.wrap or ownerItem(side) ~= nil
end

function KnoxFluidWindow:setSide(side, item)
    if side.copy then FluidContainer.DisposeContainer(side.copy) side.copy = nil end
    side.cands = nil
    self:other(side).cands = nil
    side.wrap = item and ISFluidContainer:new(item:getFluidContainer()) or nil
    self.frac = 1
    self.previewKey = nil
end

function KnoxFluidWindow:swap()
    self.left, self.right = self.right, self.left
    self.frac = 1
    self.previewKey = nil
    getSoundManager():playUISound("UIActivateButton")
end

-- Frame: checks, amounts, preview ------------------------------------------------------

function KnoxFluidWindow:validate()
    -- (the character dead: it goes, as the TV's and the radio's windows do)
    if self.player:isDead() then
        self:close()
        return false
    end
    -- a barrel or a sink: the window closes when the character walks away
    if self.isIso then
        local owner = self.home:getOwner()
        local sq = owner and owner.getSquare and owner:getSquare()
        local d = ISFluidUtil.isoMaxPanelDist
        if not ISFluidUtil.validateContainer(self.home) or not sq
            or math.abs(self.player:getX() - sq:getX()) > d + 0.5 or math.abs(self.player:getY() - sq:getY()) > d + 0.5 then
            self:close()
            return false
        end
    end
    -- an item that left the inventory leaves its slot (the world container closes the window)
    for _, side in ipairs({self.left, self.right}) do
        if side.wrap and not ISFluidUtil.validateContainer(side.wrap) then
            if side.wrap == self.home then self:close() return false end
            self:setSide(side, nil)
        end
    end
    if self.action and not ISTimedActionQueue.hasAction(self.action) then self.action = nil end
    self.locked = self.action ~= nil

    local from, to = fluidOf(self.left), fluidOf(self.right)
    self.canPour, self.maxPour, self.amount, self.error = false, 0, 0, nil
    if from and to and FluidContainer.CanTransfer(from, to) then
        self.maxPour = FluidUtil.roundTransfer(math.min(from:getAmount(), to:getCapacity() - to:getAmount()))
        self.amount = FluidUtil.roundTransfer(self.maxPour * self.frac)
        self.canPour = self.amount > 0 and not self.locked
    elseif from or to then
        self.error = FluidContainer.GetTransferReason(from, to)
    end
    -- the target's look after pouring: the game's transfer on a copy of it
    local key = tostring(from) .. tostring(to) .. tostring(self.amount) .. (to and tostring(to:getAmount()) or "")
    if to and from and self.amount > 0 and key ~= self.previewKey then
        self.previewKey = key
        if not self.right.copy then self.right.copy = to:copy() end
        self.right.copy:copyFluidsFrom(to)
        FluidContainer.Transfer(from, self.right.copy, self.amount, true)
    end
    return true
end

-- Drawing -----------------------------------------------------------------------------

--- A tank: the fluid from the bottom in its color; `newRatio` the level after
--- pouring (source: what leaves is shaded; target: what comes is lit in `newColor`).
local function drawTank(ui, x, y, w, h, fc, newRatio, newColor, bad)
    T.rect(ui, x, y, w, h, T.color.cell)
    local ratio = 0
    if fc and fc:getCapacity() > 0 and not fc:isHiddenAmount() then ratio = math.min(1, fc:getAmount() / fc:getCapacity()) end
    local col = colorOf(fc)
    local fh = math.floor(h * ratio)
    if fh > 0 then ui:drawRect(x, y + h - fh, w, fh, 0.85, col.r, col.g, col.b) end
    if newRatio then
        local nh = math.floor(h * math.max(0, math.min(1, newRatio)))
        local a = 0.45 + 0.25 * math.sin(getTimestampMs() / 1000 * math.pi * 1.6)
        if nh < fh then
            ui:drawRect(x, y + h - fh, w, fh - nh, 0.6, 0.04, 0.05, 0.05)   -- what leaves
        elseif nh > fh then
            local nc = newColor or col
            ui:drawRect(x, y + h - nh, w, nh - fh, a, nc.r, nc.g, nc.b)       -- what comes
        end
        T.rect(ui, x, y + h - nh - 1, w, 2, T.color.accent)
    end
    -- quarter marks
    for i = 1, 3 do
        local my = y + h - math.floor(h * i / 4)
        T.rect(ui, x, my, math.floor(w / 4), 1, T.color.tileFrame)
        T.rect(ui, x + w - math.floor(w / 4), my, math.floor(w / 4), 1, T.color.tileFrame)
    end
    T.tileFrame(ui, x, y, w, h, bad and T.color.bad or T.color.tileFrame)
end

-- (the tank and the fluid's colour and amounts, for the container's info window too: KnoxFluidInfo)
F.drawTank, F.colorOf, F.amountText = drawTank, colorOf, amountText

--- Swap mark: two arrows, one over the other, pointing opposite ways.
local function swapArrows(ui, cx, cy, s, c)
    for k = -1, 1, 2 do
        local y = cy + k * math.floor(s / 2)
        local dir = k
        T.rect(ui, cx - s, y - 1, s * 2, 2, c)
        for i = 0, math.floor(s / 2) do
            local tip = dir < 0 and (cx - s + i) or (cx + s - i)
            ui:drawRect(tip, y - i - 1, 2, 2, 1, c.r, c.g, c.b)
            ui:drawRect(tip, y + i - 1, 2, 2, 1, c.r, c.g, c.b)
        end
    end
end

function KnoxFluidWindow:drawSide(side, x, caption, mx, my)
    local L, pad = self.L, T.pad
    local fc = fluidOf(side)
    local over = self:isMouseOver()
    T.caps(self, caption, x + math.floor((L.colW - T.measure(T.fontCaps, T.upper(caption))) / 2), L.capY, T.color.dim)

    -- slot: the item's icon, the world object's picture, or "+" to choose
    local r = self:slotRect(side)
    local hot = over and inRect(mx, my, r)
    T.rect(self, r[1], r[2], r[3], r[4], T.color.cell)
    local item = ownerItem(side)
    if item then
        T.rect(self, r[1], r[2], r[3], r[4], T.category[T.categoryOf(item)])
        local s = math.floor(r[3] * 0.8)
        ISInventoryItem.renderItemIcon(self, item, r[1] + math.floor((r[3] - s) / 2), r[2] + math.floor((r[4] - s) / 2), 1, s, s)
        if hot and not KnoxDrag.isActive() then KnoxTooltip.want(item, self.playerNum) end
    elseif side.wrap then
        local owner = side.wrap:getOwner()
        local tex = owner and owner.getTextureName and owner:getTextureName() and getTexture(owner:getTextureName())
        if tex then self:drawTextureScaledAspect(tex, r[1] + 2, r[2] + 2, r[3] - 4, r[4] - 4, 1, 1, 1, 1) end
    end
    -- the quick pick panel of carried containers, as the equipment slots
    local offered = 0
    local ref = self:refOf(side)
    local open = KnoxSlotPicker.isOpenFor(ref)
    if self:isItemSide(side) and not self.locked and not KnoxDrag.isActive() and (hot or open) then
        local cands = self:candidates(side)
        offered = #cands
        if hot and not side.wrap then
            -- an empty slot: how many fit
            local c = offered > 0 and T.color.accent or T.color.dim
            T.textCentre(self, tostring(offered), r[1] + math.floor(r[3] / 2),
                r[2] + math.floor((r[4] - T.fontH(T.fontHeader)) / 2), c, T.fontHeader)
        end
        if hot and offered > 0 then
            local win = self
            -- the source's panel opens to the left, the target's to the right, over the window
            local where = side == self.left and "left" or "right"
            KnoxSlotPicker.want(ref, caption, cands, function(it) win:setSide(side, it) end, where, self.playerNum, self, true)
        end
    elseif not side.wrap then
        -- an empty slot at rest: a faint "+"
        local s = math.floor(r[3] / 5)
        local cx, cy = r[1] + math.floor(r[3] / 2), r[2] + math.floor(r[4] / 2)
        T.rect(self, cx - s, cy - 1, s * 2, 2, T.color.dim)
        T.rect(self, cx - 1, cy - s, 2, s * 2, T.color.dim)
    end
    local edge = (item or side.wrap) and T.color.tileFrame or T.color.tileEdge
    if hot and not side.wrap or (hot and item) then edge = T.color.tileHover end
    if KnoxDrag.isActive() and hot then
        local ok = self:accepts(side, KnoxDrag.entity.item)
        local c = ok and T.color.ok or T.color.bad
        self:drawRect(r[1], r[2], r[3], r[4], 0.22, c.r, c.g, c.b)
        edge = c
    end
    T.tileFrame(self, r[1], r[2], r[3], r[4], edge)
    if offered > 0 and not side.wrap then T.target(self, r[1], r[2], r[3], r[4]) end

    -- name, tank, amount
    local name = fc and fc:getTranslatedContainerName() or getText("IGUI_Knox_FluidChoose")
    T.textCentre(self, T.fit(name, T.fontText, L.colW), x + math.floor(L.colW / 2), L.nameY, fc and T.color.text or T.color.dim, T.fontText)
    local tx = x + math.floor((L.colW - L.tankW) / 2)
    local newRatio, newColor = nil, nil
    if fc and self.amount > 0 and fc:getCapacity() > 0 then
        if side == self.left then
            newRatio = (fc:getAmount() - self.amount) / fc:getCapacity()
        else
            newRatio = (fc:getAmount() + self.amount) / fc:getCapacity()
            newColor = side.copy and colorOf(side.copy) or nil
        end
    end
    -- which tank is the reason it can't pour (as the game marks its panels)
    local bad = false
    if self.error then
        local f, t = fluidOf(self.left), fluidOf(self.right)
        if not f or f:isEmpty() then bad = side == self.left
        elseif not t or t:isFull() then bad = side == self.right
        else bad = true end
    end
    drawTank(self, tx, L.tankY, L.tankW, L.tankH, fc, newRatio, newColor, bad)
    if fc then
        local text = amountText(fc, fc:getAmount()) .. " / " .. amountText(fc, fc:getCapacity())
        T.textCentre(self, text, x + math.floor(L.colW / 2), L.amountY, T.color.dim, T.fontText)
    end
end

function KnoxFluidWindow:rects()
    local L, pad = self.L, T.pad
    local R = {}
    local mx, mw = L.midX, L.midW
    R.swap = {mx + math.floor(mw * 0.15), L.slotY + math.floor((L.slotS - L.btnH) / 2), math.floor(mw * 0.7), L.btnH}
    local y = L.tankY + T.fontH(T.fontText) + pad
    local pw = math.floor((mw - 3 * 4) / 4)
    R.presets = {}
    for i, f in ipairs({0.25, 0.5, 0.75, 1}) do
        table.insert(R.presets, {mx + (i - 1) * (pw + 4), y, pw, L.btnH, f})
    end
    R.track = {mx, y + L.btnH + pad, mw, math.max(12, math.floor(T.cell / 3))}
    R.amountY = R.track[2] + R.track[4] + pad
    local pourT, closeT = getText("Fluid_Transfer"), getText("Fluid_Close")
    local pw2, cw = T.buttonW(pourT), T.buttonW(closeT)
    R.close = {L.w - pad - cw, L.btnY, cw, L.btnH, closeT}
    R.pour = {L.w - pad * 2 - cw - pw2, L.btnY, pw2, L.btnH, pourT}
    local s = L.headerH - 8
    R.x = {L.w - s - 4, 4, s, s}
    return R
end

function KnoxFluidWindow:prerender()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    if not self:validate() then return end
    KnoxSlotPicker.sync(self)   -- its own quick pick panel (drawn over the screen with it)
    if self.dragging then
        if isMouseButtonDown(0) then self:slideTo(self:getMouseX()) else self.dragging = false end
    end
    local L, pad = self.L, T.pad
    local w, h = self:getWidth(), self:getHeight()
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local R = self:rects()

    -- threads from the items' tiles (with the Knox screen open)
    if KnoxScreen and KnoxScreen.instance then
        for _, side in ipairs({self.left, self.right}) do
            local item = ownerItem(side)
            if item then
                local sx, sy, sw, sh = KnoxThread.sourceRect(item)
                KnoxThread.draw(self, sx, sy, sw, sh, L.headerH, true)
            end
        end
    end

    -- plate as the other windows
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, L.headerH, T.color.header)
    T.rect(self, 0, L.headerH, w, 1, T.color.border)
    T.border(self, 0, 0, w, h, T.color.hoverEdge)
    local ac, a = T.color.accent, self.knoxMove and 1 or 0.5
    self:drawRectBorder(0, 0, w, h, a, ac.r, ac.g, ac.b)
    self:drawRectBorder(1, 1, w - 2, h - 2, a, ac.r, ac.g, ac.b)
    T.caps(self, getText("Fluid_Transfer_Fluids"), pad, math.floor((L.headerH - T.fontH(T.fontCaps)) / 2), T.color.bright)
    T.closeButton(self, R.x[1], R.x[2], R.x[3], over and inRect(mx, my, R.x))

    self:drawSide(self.left, L.leftX, getText("Fluid_Source"), mx, my)
    self:drawSide(self.right, L.rightX, getText("Fluid_Target"), mx, my)

    -- middle: swap, the fluid, presets, slider, amount
    local cx = L.midX + math.floor(L.midW / 2)
    local sHot = over and inRect(mx, my, R.swap) and not self.locked
    T.button(self, R.swap, "", {hover = sHot, disabled = self.locked})
    -- the arrows and the caption together, centred in the button
    local swapC = sHot and T.color.accent or T.color.text
    local swapText = T.upper(getText("Fluid_Swap"))
    local s = math.floor(R.swap[4] * 0.28)
    local gap = math.floor(R.swap[4] * 0.35)
    local total = s * 2 + gap + T.measure(T.fontCaps, swapText)
    local x0 = R.swap[1] + math.floor((R.swap[3] - total) / 2)
    swapArrows(self, x0 + s, R.swap[2] + math.floor(R.swap[4] / 2), s, swapC)
    T.text(self, swapText, x0 + s * 2 + gap, R.swap[2] + math.floor((R.swap[4] - T.fontH(T.fontCaps)) / 2), swapC, T.fontCaps)

    local from = fluidOf(self.left)
    if from and from:getPrimaryFluid() then
        local fname = string.gsub(from:getUiName(), "%b()$", "")
        local col = colorOf(from)
        local tw = T.measure(T.fontText, fname)
        local d = math.max(8, math.floor(T.fontH(T.fontText) * 0.6))
        local x0 = cx - math.floor((tw + d + 6) / 2)
        self:drawRect(x0, L.tankY + math.floor((T.fontH(T.fontText) - d) / 2), d, d, 1, col.r, col.g, col.b)
        T.text(self, fname, x0 + d + 6, L.tankY, T.color.bright, T.fontText)
    end
    for i, p in ipairs(R.presets) do
        local label = i == 4 and getText("IGUI_Knox_FluidAll") or (math.floor(p[5] * 100) .. "%")
        local on = math.abs(self.frac - p[5]) < 0.001
        T.button(self, p, label, {hover = over and inRect(mx, my, p) and self.maxPour > 0, active = on,
            disabled = self.maxPour <= 0, font = T.fontTile})
    end
    local tr = R.track
    local ty = tr[2] + math.floor(tr[4] / 2) - 1
    T.rect(self, tr[1], ty, tr[3], 3, T.color.line)
    T.rect(self, tr[1], ty, math.floor(tr[3] * self.frac), 3, self.maxPour > 0 and T.color.accent or T.color.dim)
    local kx = tr[1] + math.floor(tr[3] * self.frac) - math.floor(tr[4] / 2)
    T.rect(self, kx, tr[2], tr[4], tr[4], self.maxPour > 0 and T.color.accent or T.color.dim)
    local big = amountText(from, self.amount)
    T.textCentre(self, big, cx, R.amountY, self.amount > 0 and T.color.bright or T.color.dim, T.fontHeader)
    T.textCentre(self, getText("IGUI_Knox_FluidOfMax", amountText(from, self.maxPour)), cx,
        R.amountY + T.fontH(T.fontHeader), T.color.dim, T.fontText)

    -- why it can't pour: a red plate
    if self.error and self.error ~= "" then
        local ew = math.min(L.w - pad * 2, T.measure(T.fontText, self.error) + 20)
        local ex = math.floor((L.w - ew) / 2)
        local b = T.color.bad
        self:drawRect(ex, L.errY, ew, L.errH, 0.22, b.r, b.g, b.b)
        T.border(self, ex, L.errY, ew, L.errH, b)
        T.textCentre(self, T.fit(self.error, T.fontText, ew - 12), math.floor(L.w / 2), L.errY + 4, T.color.bright, T.fontText)
    end

    -- buttons: pour (sand; fills with the action's progress), close
    T.button(self, R.pour, R.pour[5], {primary = true, hover = over and inRect(mx, my, R.pour) and self.canPour,
        disabled = not self.canPour})
    if self.action and self.action.action then
        local p = math.max(0, math.min(1, self.action:getJobDelta()))
        self:drawRect(R.pour[1], R.pour[2], math.floor(R.pour[3] * p), R.pour[4], 0.35, 1, 1, 1)
    end
    T.button(self, R.close, R.close[5], {hover = over and inRect(mx, my, R.close)})
end

-- Input ---------------------------------------------------------------------------------

function KnoxFluidWindow:slideTo(mx)
    local tr = self:rects().track
    self.frac = math.max(0, math.min(1, (mx - tr[1]) / math.max(1, tr[3])))
end

function KnoxFluidWindow:onMouseDown(x, y)
    if self.foldMs then return true end
    self:bringToTop()
    local R = self:rects()
    if inRect(x, y, R.x) then self:close() return true end
    if inRect(x, y, R.close) then self:close() return true end
    if inRect(x, y, R.pour) then self:pour() return true end
    if not self.locked then
        if inRect(x, y, R.swap) then self:swap() return true end
        for _, p in ipairs(R.presets) do
            if inRect(x, y, p) then
                self.frac = p[5]
                getSoundManager():playUISound("UIActivateButton")
                return true
            end
        end
        local tr = R.track
        if inRect(x, y, {tr[1] - 6, tr[2] - 6, tr[3] + 12, tr[4] + 12}) then
            self.dragging = true
            self:slideTo(x)
            return true
        end
        for _, side in ipairs({self.left, self.right}) do
            if inRect(x, y, self:slotRect(side)) then return true end   -- the quick pick panel does the choosing
        end
    end
    KnoxWindowDrag.begin(self, x, y, self.L.headerH)
    return true
end

KnoxWindowDrag.install(KnoxFluidWindow)

local dragStop = KnoxFluidWindow.onMouseUp
function KnoxFluidWindow:onMouseUp(x, y)
    self.dragging = false
    -- a tile dropped on a slot from a Knox grid
    if KnoxDrag and KnoxDrag.isActive() then
        local item = KnoxDrag.entity.item
        for _, side in ipairs({self.left, self.right}) do
            if inRect(x, y, self:slotRect(side)) then
                KnoxDrag.cancel()
                if self:accepts(side, item) then self:setSide(side, item) end
                return true
            end
        end
    end
    return dragStop(self, x, y)
end

function KnoxFluidWindow:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end   -- (an item is held: the button may turn it, see KnoxDragLayer)

    for _, side in ipairs({self.left, self.right}) do
        if not self.locked and ownerItem(side) and inRect(x, y, self:slotRect(side)) then
            self:setSide(side, nil)
            return true
        end
    end
    return true
end

function KnoxFluidWindow:onMouseWheel(del)
    if not self.locked and self.maxPour > 0 then
        self.frac = math.max(0, math.min(1, self.frac - del * 0.05))
    end
    return true
end

function KnoxFluidWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function KnoxFluidWindow:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end

--- Pour: as the game's window (walk to a world container first; copies of the
--- containers for the action).
function KnoxFluidWindow:pour()
    if not self.canPour then return end
    if self.isIso and not ISFluidUtil.doWalkTo(self.player, self.home) then return end
    local from, to = fluidOf(self.left), fluidOf(self.right)
    if not (from and to and FluidContainer.CanTransfer(from, to)) then return end
    local l, r = self.left.wrap:copy(), self.right.wrap:copy()
    self.action = ISFluidTransferAction:new(self.player, l, l:getFluidObject(), r, r:getFluidObject(), self.amount)
    ISTimedActionQueue.add(self.action)
    getSoundManager():playUISound("UIActivateButton")
end

function KnoxFluidWindow:close()
    F.lastX, F.lastY = self:getX(), self:getY()
    if KnoxSlotPicker.instance and KnoxSlotPicker.instance.host == self then KnoxSlotPicker.close() end
    for _, side in ipairs({self.left, self.right}) do
        if side.copy then FluidContainer.DisposeContainer(side.copy) side.copy = nil end
    end
    T.fold(self, function(w)
        w:setVisible(false)
        w:removeFromUIManager()
    end)
    if F.instance == self then F.instance = nil end
end

--- Open in place of the game's window.
function F.open(player, container, source)
    if F.instance then F.instance:close() end
    local w = F:new(player, container, source)
    w:initialise()
    w:instantiate()
    w:setWantKeyEvents(true)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = F.lastX or math.floor((sw - w:getWidth()) / 2)
    local y = F.lastY or math.floor((sh - w:getHeight()) / 2)
    w:setX(math.max(0, math.min(sw - w:getWidth(), x)))
    w:setY(math.max(0, math.min(sh - w:getHeight(), y)))
    w:addToUIManager()
    F.instance = w
    return w
end

return KnoxFluidWindow
