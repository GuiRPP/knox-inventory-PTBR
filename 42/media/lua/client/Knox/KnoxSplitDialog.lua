-- "Split stack" dialog (Alt+click on a stack): how many items to take off
-- into a tile of their own. Slider, -/+ buttons, mouse wheel.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxThread"

KnoxSplitDialog = ISPanel:derive("KnoxSplitDialog")

local T = KnoxTheme

function KnoxSplitDialog:new(entity, view, player)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.entity = entity
    o.view = view
    o.player = player
    o.max = #entity.items - 1
    o.value = math.max(1, math.floor(#entity.items / 2))
    o.background = false
    o.moveWithMouse = false   -- moved by its header, see KnoxWindowDrag
    return o
end

function KnoxSplitDialog:layout()
    local ft = T.fontH(T.fontText)
    local fh = T.fontH(T.fontHeader)
    local pad = T.pad
    local w = math.max(T.cell * 7, T.measure(T.fontText, self.entity.item:getDisplayName()) + pad * 4)
    local L = {}
    L.headerH = T.sectionH + 4
    L.nameY = L.headerH + pad
    L.valueY = L.nameY + ft + pad
    L.btn = math.floor(T.cell * 0.75)
    L.sliderY = L.valueY + fh + pad
    L.sliderH = math.max(12, math.floor(T.cell / 3))
    L.footY = L.sliderY + L.sliderH + T.fontTileH + pad * 2
    L.footH = ft + pad
    L.h = L.footY + L.footH + pad
    L.w = w
    L.trackX = pad
    L.trackW = w - pad * 2
    return L
end

function KnoxSplitDialog:createChildren()
    self.L = self:layout()
    self:setWidth(self.L.w)
    self:setHeight(self.L.h)
end

local inRect = T.inRect

function KnoxSplitDialog:rects()
    local L, pad = self.L, T.pad
    local ok, cancel = getText("IGUI_Knox_OK"), getText("IGUI_Knox_Cancel")
    local okW = T.buttonW(ok)
    local cancelW = T.buttonW(cancel)
    return {
        minus = {pad, L.valueY, L.btn, L.btn},
        plus = {L.w - pad - L.btn, L.valueY, L.btn, L.btn},
        track = {L.trackX, L.sliderY, L.trackW, L.sliderH},
        ok = {L.w - pad - okW, L.footY, okW, L.footH, ok},
        cancel = {L.w - pad * 2 - okW - cancelW, L.footY, cancelW, L.footH, cancel},
    }
end

function KnoxSplitDialog:setValue(v)
    self.value = math.max(1, math.min(self.max, math.floor(v + 0.5)))
end

function KnoxSplitDialog:valueAt(mx)
    local L = self.L
    local f = (mx - L.trackX) / math.max(1, L.trackW)
    return 1 + f * (self.max - 1)
end

local function button(ui, r, text, hover, primary, disabled)
    local font = (text == "-" or text == "+") and T.fontHeader or nil
    T.button(ui, r, text, {hover = hover, primary = primary, disabled = disabled, font = font})
end

function KnoxSplitDialog:prerender()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    local L, pad = self.L, T.pad
    local w, h = self:getWidth(), self:getHeight()
    local ft, fh = T.fontH(T.fontText), T.fontH(T.fontHeader)
    local mx, my = self:getMouseX(), self:getMouseY()
    local R = self:rects()

    if self.dragging then
        if isMouseButtonDown(0) then self:setValue(self:valueAt(mx)) else self.dragging = false end
    end

    -- thread from the stack's tile, as the bag and inspect windows have
    local sx, sy, sw, sh = KnoxThread.sourceRect(self.entity.item)
    KnoxThread.draw(self, sx, sy, sw, sh, L.headerH, true)

    -- plate as the other windows: shadow, frame, sand edge (bright while dragged)
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, L.headerH, T.color.header)
    T.rect(self, 0, L.headerH, w, 1, T.color.border)
    T.border(self, 0, 0, w, h, T.color.hoverEdge)
    local ac, a = T.color.accent, self.knoxMove and 1 or 0.5
    self:drawRectBorder(0, 0, w, h, a, ac.r, ac.g, ac.b)
    self:drawRectBorder(1, 1, w - 2, h - 2, a, ac.r, ac.g, ac.b)

    -- header: title, the stack's count, the close button
    local cx, cy, cw = self:closeRect()
    T.caps(self, getText("IGUI_Knox_Split"), pad, math.floor((L.headerH - T.fontH(T.fontCaps)) / 2), T.color.bright)
    T.textRight(self, tostring(#self.entity.items), cx - 8, math.floor((L.headerH - ft) / 2), T.color.dim, T.fontText)
    T.closeButton(self, cx, cy, cw, inRect(mx, my, {cx, cy, cw, cw}))

    T.text(self, self.entity.item:getDisplayName(), pad, L.nameY, T.color.text, T.fontText)

    -- value with -/+
    -- at a limit the button is dimmed (a stack of 2 can only give 1)
    button(self, R.minus, "-", inRect(mx, my, R.minus), false, self.value <= 1)
    button(self, R.plus, "+", inRect(mx, my, R.plus), false, self.value >= self.max)
    local valueText = self.value .. " / " .. #self.entity.items
    T.drawTextCentre(self, valueText, w / 2, L.valueY + math.floor((L.btn - fh) / 2),
        T.color.bright.r, T.color.bright.g, T.color.bright.b, 1, T.fontHeader)

    -- slider
    local tr = R.track
    T.rect(self, tr[1], tr[2] + math.floor(tr[4] / 2) - 1, tr[3], 3, T.color.line)
    local f = (self.max > 1) and (self.value - 1) / (self.max - 1) or 1
    T.rect(self, tr[1], tr[2] + math.floor(tr[4] / 2) - 1, math.floor(tr[3] * f), 3, T.color.accent)
    local kx = tr[1] + math.floor(tr[3] * f) - math.floor(tr[4] / 2)
    T.rect(self, kx, tr[2], tr[4], tr[4], T.color.accent)
    -- range under the slider
    local fy = tr[2] + tr[4] + 2
    T.text(self, "1", tr[1], fy, T.color.dim, T.fontTile)
    T.textRight(self, tostring(self.max), tr[1] + tr[3], fy, T.color.dim, T.fontTile)

    button(self, R.cancel, R.cancel[5], inRect(mx, my, R.cancel))
    button(self, R.ok, R.ok[5], inRect(mx, my, R.ok), true)
end

--- Is this item in the stack being split? (its tile gets a sand frame)
function KnoxSplitDialog.isOpen(item)
    local d = KnoxSplitDialog.instance
    if not d then return false end
    for _, it in ipairs(d.entity.items) do
        if it == item then return true end
    end
    return false
end

--- Close button in the header, as the other windows': x, y, size.
function KnoxSplitDialog:closeRect()
    local s = self.L.headerH - 8
    return self:getWidth() - s - 4, 4, s
end

function KnoxSplitDialog:onMouseDown(x, y)
    if self.foldMs then return true end
    local cx, cy, cw = self:closeRect()
    if inRect(x, y, {cx, cy, cw, cw}) then self:close() return true end
    local R = self:rects()
    if inRect(x, y, R.minus) then self:setValue(self.value - 1) return true end
    if inRect(x, y, R.plus) then self:setValue(self.value + 1) return true end
    if inRect(x, y, {R.track[1] - 6, R.track[2] - 6, R.track[3] + 12, R.track[4] + 12}) then
        self.dragging = true
        self:setValue(self:valueAt(x))
        return true
    end
    if inRect(x, y, R.ok) then
        -- only what is still in the stack's container (some may have been used
        -- or moved while the dialog was up)
        local live = {}
        for _, it in ipairs(self.entity.items) do
            if it:getContainer() == self.view.container then table.insert(live, it) end
        end
        if #live >= 2 then
            local e = {item = live[1], items = live, w = self.entity.w, h = self.entity.h}
            KnoxActions.split(e, self.view, math.min(self.value, #live - 1), self.player)
        end
        self:close()
        return true
    end
    if inRect(x, y, R.cancel) then self:close() return true end
    KnoxWindowDrag.begin(self, x, y, self.L.headerH)
    return true
end

KnoxWindowDrag.install(KnoxSplitDialog)

function KnoxSplitDialog:onMouseWheel(del)
    self:setValue(self.value - del)
    return true
end

function KnoxSplitDialog:close()
    T.fold(self, function(w)
        w:setVisible(false)
        if w.host then w.host:removeChild(w) else w:removeFromUIManager() end
    end)
    if KnoxSplitDialog.instance == self then KnoxSplitDialog.instance = nil end
end

--- Opens over the Knox screen as its last child: drawn on top of the columns
--- and the first to get the mouse.
function KnoxSplitDialog.open(entity, view, player)
    if KnoxSplitDialog.instance then KnoxSplitDialog.instance:close() end
    local d = KnoxSplitDialog:new(entity, view, player)
    d:initialise()
    d:instantiate()
    local host = KnoxScreen and KnoxScreen.instance
    local hx, hy = host and host:getAbsoluteX() or 0, host and host:getAbsoluteY() or 0
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = math.max(0, math.min(sw - d:getWidth(), math.floor(getMouseX() - d:getWidth() / 2)))
    local y = math.max(0, math.min(sh - d:getHeight(), math.floor(getMouseY() - d:getHeight() / 2)))
    d:setX(x - hx)
    d:setY(y - hy)
    if host then
        d.host = host
        host:addChild(d)
    else
        d:addToUIManager()
    end
    KnoxSplitDialog.instance = d
end
