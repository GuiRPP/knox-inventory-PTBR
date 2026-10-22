-- What a fluid container holds, in Knox's look - it takes the place of the
-- game's ISFluidInfoUI ("Container info" in an item's menu, a barrel's, a
-- sink's), which stayed in the game's look (the author, 2026-10-18). Built on
-- the pouring window's parts (KnoxFluidWindow): its plate, slot and tank.
--
-- The tank on the left, the fluid in its colour; on the right the container
-- (its icon and name), the fluid, and capacity / held / free; a close button.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxFluidWindow"

KnoxFluidInfo = ISPanel:derive("KnoxFluidInfo")
local I = KnoxFluidInfo
local T = KnoxTheme
local F = KnoxFluidWindow

I.instance = nil
I.lastX, I.lastY = nil, nil

local inRect = T.inRect

function KnoxFluidInfo:new(player, container)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.wrap = container
    o.isIso = not (container:isItem() or container:isResource())
    o.background = false
    o.moveWithMouse = false
    return o
end

local function ownerItem(wrap)
    local o = wrap and wrap:getOwner()
    if o and instanceof(o, "InventoryItem") then return o end
    return nil
end

function KnoxFluidInfo:createChildren()
    local c, pad = T.cell, T.pad
    local L = {}
    L.headerH = T.sectionH + 4
    L.tankW = math.floor(c * 1.1)
    L.tankH = math.floor(c * 3.4)
    L.slotS = math.floor(c * 1.2)
    L.infoW = math.floor(c * 4.4)
    L.btnH = math.floor(c * 0.62 + 0.5)
    L.rowH = T.fontH(T.fontText) + 4
    L.top = L.headerH + pad
    L.tankX = pad
    L.infoX = pad * 2 + L.tankW
    L.w = pad * 3 + L.tankW + L.infoW
    L.btnY = L.top + L.tankH + pad
    L.h = L.btnY + L.btnH + pad
    self.L = L
    self:setWidth(L.w)
    self:setHeight(L.h)
end

--- A barrel or a sink: closes when the character walks away; anything gone: closes.
function KnoxFluidInfo:validate()
    if self.player:isDead() or not ISFluidUtil.validateContainer(self.wrap) then
        self:close()
        return false
    end
    if self.isIso then
        local owner = self.wrap:getOwner()
        local sq = owner and owner.getSquare and owner:getSquare()
        local d = ISFluidUtil.isoMaxPanelDist
        if not sq or math.abs(self.player:getX() - sq:getX()) > d + 0.5 or math.abs(self.player:getY() - sq:getY()) > d + 0.5 then
            self:close()
            return false
        end
    end
    return true
end

function KnoxFluidInfo:rects()
    local L, pad = self.L, T.pad
    local R = {}
    local closeT = getText("IGUI_Knox_Close")
    R.close = {pad, L.btnY, L.w - pad * 2, L.btnH, closeT}
    local s = L.headerH - 8
    R.x = {L.w - s - 4, 4, s, s}
    R.slot = {L.infoX, L.top, L.slotS, L.slotS}
    return R
end

function KnoxFluidInfo:prerender()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    if not self:validate() then return end
    local L, pad = self.L, T.pad
    local w, h = self:getWidth(), self:getHeight()
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local R = self:rects()
    local fc = self.wrap:getFluidContainer()

    -- a thread from the item's tile (with the Knox screen open)
    local item = ownerItem(self.wrap)
    if item and KnoxScreen and KnoxScreen.instance and KnoxThread then
        local sx, sy, sw, sh = KnoxThread.sourceRect(item)
        KnoxThread.draw(self, sx, sy, sw, sh, L.headerH, true)
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
    T.caps(self, T.fit(getText("Fluid_Info_Panel"), T.fontCaps, R.x[1] - pad * 2), pad,
        math.floor((L.headerH - T.fontH(T.fontCaps)) / 2), T.color.bright)
    T.closeButton(self, R.x[1], R.x[2], R.x[3], over and inRect(mx, my, R.x))

    -- the tank
    F.drawTank(self, L.tankX, L.top, L.tankW, L.tankH, fc, nil, nil, false)

    -- the container: its icon (or the world object's picture) and its name
    local r = R.slot
    T.rect(self, r[1], r[2], r[3], r[4], item and T.category[T.categoryOf(item)] or T.color.cell)
    if item then
        local s = math.floor(r[3] * 0.8)
        ISInventoryItem.renderItemIcon(self, item, r[1] + math.floor((r[3] - s) / 2), r[2] + math.floor((r[4] - s) / 2), 1, s, s)
        if over and inRect(mx, my, r) and KnoxTooltip then KnoxTooltip.want(item, self.playerNum) end
    else
        local owner = self.wrap:getOwner()
        local tex = owner and owner.getTextureName and owner:getTextureName() and getTexture(owner:getTextureName())
        if tex then self:drawTextureScaledAspect(tex, r[1] + 2, r[2] + 2, r[3] - 4, r[4] - 4, 1, 1, 1, 1) end
    end
    T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.tileFrame)
    local nx = r[1] + r[3] + pad
    local nameW = L.w - pad - nx
    local name = fc and fc:getTranslatedContainerName() or ""
    local fh = T.fontH(T.fontText)
    T.text(self, T.fit(name, T.fontText, nameW), nx, r[2] + math.floor((r[4] - fh) / 2), T.color.bright, T.fontText)

    -- the fluid: a swatch of its colour and its name (or "empty")
    local y = r[2] + r[4] + pad
    if fc and not fc:isEmpty() and fc:getPrimaryFluid() then
        local fname = string.gsub(fc:getUiName(), "%b()$", "")
        if fc:isHiddenAmount() then fname = getText("Fluid_Unknown") end
        local col = F.colorOf(fc)
        local d = math.max(8, math.floor(fh * 0.6))
        self:drawRect(L.infoX, y + math.floor((fh - d) / 2), d, d, 1, col.r, col.g, col.b)
        T.text(self, T.fit(fname, T.fontText, L.infoW - d - 6), L.infoX + d + 6, y, T.color.text, T.fontText)
    else
        T.text(self, getText("IGUI_Knox_FluidNone"), L.infoX, y, T.color.dim, T.fontText)
    end
    y = y + L.rowH + math.floor(pad / 2)
    T.rect(self, L.infoX, y, L.infoW, 1, T.color.border)
    y = y + math.floor(pad / 2) + 2

    -- capacity, held, free: label on the left, the figure on the right
    if fc then
        local cap, amt = fc:getCapacity(), fc:getAmount()
        local rows = {
            {getText("Fluid_Capacity"), F.amountText(fc, cap)},
            {getText("IGUI_Knox_FluidHeld"), F.amountText(fc, amt)},
            {getText("IGUI_Knox_FluidFree"), F.amountText(fc, math.max(0, cap - amt))},
        }
        local right = L.infoX + L.infoW
        for _, row in ipairs(rows) do
            T.text(self, row[1], L.infoX, y, T.color.dim, T.fontText)
            T.textRight(self, row[2], right, y, T.color.bright, T.fontText)
            y = y + L.rowH
        end
    end

    T.button(self, R.close, R.close[5], {hover = over and inRect(mx, my, R.close)})
end

-- Input ---------------------------------------------------------------------------------

function KnoxFluidInfo:onMouseDown(x, y)
    if self.foldMs then return true end
    self:bringToTop()
    local R = self:rects()
    if inRect(x, y, R.x) or inRect(x, y, R.close) then
        self:close()
        return true
    end
    KnoxWindowDrag.begin(self, x, y, self.L.headerH)
    return true
end

KnoxWindowDrag.install(KnoxFluidInfo)

function KnoxFluidInfo:onRightMouseUp(x, y) return true end

function KnoxFluidInfo:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function KnoxFluidInfo:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end

function KnoxFluidInfo:close()
    I.lastX, I.lastY = self:getX(), self:getY()
    T.fold(self, function(w)
        w:setVisible(false)
        w:removeFromUIManager()
    end)
    if I.instance == self then I.instance = nil end
end

--- Is this item's info window open? (its tile gets the sand frame, as for the other windows)
function I.isOpen(item)
    local w = I.instance
    return w ~= nil and item ~= nil and ownerItem(w.wrap) == item
end

--- Open in place of the game's window.
function I.open(player, container)
    if I.instance then I.instance:close() end
    local w = I:new(player, container)
    w:initialise()
    w:instantiate()
    w:setWantKeyEvents(true)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = I.lastX or math.floor((sw - w:getWidth()) / 2)
    local y = I.lastY or math.floor((sh - w:getHeight()) / 2)
    w:setX(math.max(0, math.min(sw - w:getWidth(), x)))
    w:setY(math.max(0, math.min(sh - w:getHeight(), y)))
    w:addToUIManager()
    I.instance = w
    return w
end

return KnoxFluidInfo
