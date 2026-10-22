-- Floating window with the grid of a bag opened from a grid (double click on
-- its tile), like the first-aid kit window in the mockup. A child of the Knox
-- screen, so it moves and closes with it. Closes itself when the bag is no
-- longer within reach (walked away, dropped, put on).

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxGridView"
require "Knox/KnoxActions"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxThread"

KnoxContainerWindow = ISPanel:derive("KnoxContainerWindow")
KnoxContainerWindow.list = {}

local T = KnoxTheme

-- The window clicked last (title, grid, or just opened) is the active one:
-- sand frame, bright while being dragged, fading to a softer sand after.
KnoxContainerWindow.active = nil
local FADE_MS = 500
local ACTIVE_DIM = 0.5

function KnoxContainerWindow:activate()
    KnoxContainerWindow.active = self
    self.raise = true   -- comes to the front (next frame)
end

--- Strength 0..1 of the sand frame: 1 while dragged, fading to ACTIVE_DIM
--- after; 0 when another window is active.
function KnoxContainerWindow:highlight()
    if KnoxContainerWindow.active ~= self then return 0 end
    if self.knoxMove then
        self.wasDragged = true
        self.dragEndMs = nil
        return 1
    end
    if self.wasDragged then
        self.wasDragged = false
        self.dragEndMs = getTimestampMs()
    end
    if not self.dragEndMs then return ACTIVE_DIM end
    local f = (getTimestampMs() - self.dragEndMs) / FADE_MS
    if f >= 1 then
        self.dragEndMs = nil
        return ACTIVE_DIM
    end
    return 1 - (1 - ACTIVE_DIM) * f
end

function KnoxContainerWindow.isOpen(item)
    for _, w in ipairs(KnoxContainerWindow.list) do
        if w.item == item then return w end
    end
    return nil
end

function KnoxContainerWindow:new(host, item, playerNum)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.host = host
    o.item = item
    o.playerNum = playerNum
    o.background = false
    o.moveWithMouse = false   -- moved by its header, see KnoxWindowDrag
    return o
end

function KnoxContainerWindow:player()
    return getSpecificPlayer(self.playerNum)
end

function KnoxContainerWindow:createChildren()
    self.headerH = T.sectionH + 4
    self.view = KnoxGridView:new(T.pad, self.headerH + T.pad, self.item:getInventory(), self.playerNum)
    self.view:initialise()
    self:addChild(self.view)
    self:fitToView()
end

function KnoxContainerWindow:fitToView()
    -- room for the title, the size and weight next to it and the close button,
    -- however narrow the grid is (a wallet's is two cells)
    -- (up to 5 cells for the name, no more: a small parcel's 2x2 grid stood in a
    -- window 8 cells wide, empty on both sides - the author, 2026-10-18; a longer
    -- name slides, T.marquee)
    local titleW = T.measure(T.fontCaps, T.upper(self.item:getDisplayName())) + T.pad * 4 + self.headerH
        + T.measure(T.fontText, "0x0  00.0/00") + 16
    self:setWidth(math.max(self.view:getWidth() + T.pad * 2, math.min(titleW, T.cell * 5)))
    self:setHeight(self.headerH + self.view:getHeight() + T.pad * 2)
    -- a window wider than its grid (a long name): the grid in the middle, not
    -- against the left edge with empty room on the right
    self.view:setX(self:centredX())
end

function KnoxContainerWindow:centredX()
    return math.floor((self:getWidth() - self.view:getWidth()) / 2)
end

function KnoxContainerWindow:markAllDirty()
    for _, v in ipairs(KnoxActions.allViews()) do v:markDirty() end
end

function KnoxContainerWindow:closeRect()
    local s = self.headerH - 8
    return self:getWidth() - s - 4, 4, s, s
end

--- Called by the screen before it draws its children (changing the children
--- list while they are being drawn is not safe): closes windows whose bag
--- went out of reach or was put on (then it is a section of the inventory
--- column), brings a clicked window to the front.
function KnoxContainerWindow.updateAll()
    local copy = {}
    for _, w in ipairs(KnoxContainerWindow.list) do table.insert(copy, w) end
    for _, w in ipairs(copy) do
        local player = w:player()
        local inv = w.item:getInventory()
        if not inv or not player or not KnoxActions.isReachable(inv, player)
            or KnoxGrid.isEquippedNow(w.item, player) then
            w:close()
        elseif w.raise then
            w.raise = false
            w.host:removeChild(w)
            w.host:addChild(w)
        end
    end
end

--- Thread from the bag's tile to this window (see KnoxThread); the active
--- window's is bright.
function KnoxContainerWindow:drawThread()
    local sx, sy, sw, sh = KnoxThread.sourceRect(self.item, self.view)
    KnoxThread.draw(self, sx, sy, sw, sh, self.headerH, KnoxContainerWindow.active == self)
end

function KnoxContainerWindow:prerender()
    local player = self:player()
    local inv = self.item:getInventory()
    if not inv or not player then return end

    -- just opened: it unfolds out of the bag's tile
    if T.unfold(self, KnoxThread.sourceRect(self.item, self.view)) then return end
    self:drawThread()
    local w, h = self:getWidth(), self:getHeight()
    local ft = T.fontH(T.fontText)
    -- soft shadow, then the frame
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, self.headerH, T.color.header)
    T.rect(self, 0, self.headerH, w, 1, T.color.border)
    -- frame: sand on the active window (bright while dragged), grey otherwise
    local hl = self:highlight()
    T.border(self, 0, 0, w, h, T.color.hoverEdge)
    if hl > 0 then
        local ac = T.color.accent
        self:drawRectBorder(0, 0, w, h, hl, ac.r, ac.g, ac.b)
        self:drawRectBorder(1, 1, w - 2, h - 2, hl, ac.r, ac.g, ac.b)
    end

    -- overflow rows came or went, the grid changed its width
    if self.view:getHeight() + self.headerH + T.pad * 2 ~= h or self.view:getX() ~= self:centredX()
        or self.view:getWidth() + T.pad * 2 > w then
        self:fitToView()
    end
    local L = self.view.layout
    local info = KnoxGrid.sizeText(L) .. "  " .. KnoxInventoryPanel.round1(inv:getCapacityWeight())
        .. "/" .. KnoxInventoryPanel.round1(inv:getEffectiveCapacity(player))
    if #L.overflow > 0 then info = getText("IGUI_Knox_Overflow", #L.overflow) .. "  " .. info end
    -- being searched (KnoxSearch): how much is found, as the surroundings say it
    if KnoxSearch and KnoxSearch.busy(inv) then info = getText("IGUI_Knox_Searching", KnoxSearch.found(), inv:getItems():size()) end
    local cx, cy, cw, ch = self:closeRect()
    local ty = math.floor((self.headerH - ft) / 2)
    local infoW = T.measure(T.fontText, info)
    T.textRight(self, info, cx - 8, ty, #L.overflow > 0 and T.color.bad or T.color.dim, T.fontText)
    -- (a long name slides to its end and back - no "...": the author, 2026-10-18)
    self.titleSt = self.titleSt or {}
    T.marquee(self, self.titleSt, T.upper(self.item:getDisplayName()), 8, math.floor((self.headerH - T.fontH(T.fontCaps)) / 2),
        cx - 16 - infoW - 8, T.color.text, T.fontCaps)

    T.closeButton(self, cx, cy, cw, self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), {cx, cy, cw, ch}))
end

function KnoxContainerWindow:onMouseDown(x, y)
    if self.foldMs then return true end   -- folding away: no longer there to click
    local cx, cy, cw, ch = self:closeRect()
    if x >= cx and x < cx + cw and y >= cy and y < cy + ch then
        self:close()
        return true
    end
    self:activate()
    KnoxWindowDrag.begin(self, x, y, self.headerH)
    return true
end

KnoxWindowDrag.install(KnoxContainerWindow)

--- Right click on the header: Sort, its rule, the layout (KnoxOrder).
function KnoxContainerWindow:onRightMouseUp(x, y)
    if KnoxDrag.isActive() or not self.view or y >= self.headerH then return true end
    local menu = ISContextMenu.get(self.view.playerNum, self:getAbsoluteX() + x, self:getAbsoluteY() + y)
    KnoxOrder.addMenu(menu, self.view)
    return true
end

function KnoxContainerWindow:onMouseWheel(del)
    return true
end

function KnoxContainerWindow:close()
    for i, w in ipairs(KnoxContainerWindow.list) do
        if w == self then table.remove(KnoxContainerWindow.list, i) break end
    end
    if KnoxContainerWindow.active == self then
        -- the most recently opened of the remaining windows takes over
        local list = KnoxContainerWindow.list
        KnoxContainerWindow.active = list[#list]
    end
    if KnoxUISound then KnoxUISound.bag(self.item, false) end
    -- (it folds back into the bag's tile, then goes)
    T.fold(self, function(w)
        w:setVisible(false)
        w.host:removeChild(w)
    end)
end

--- Open the window of a bag, or close it when it is already open.
function KnoxContainerWindow.toggle(item, playerNum)
    local open = KnoxContainerWindow.isOpen(item)
    if open then
        open:close()
        return
    end
    local host = KnoxScreen and KnoxScreen.instance
    if not host or not item:getInventory() then return end
    local w = KnoxContainerWindow:new(host, item, playerNum)
    w:initialise()
    w:instantiate()
    -- next to the cursor, kept on screen
    local sw, sh = host:getWidth(), host:getHeight()
    local x = math.min(sw - w:getWidth() - 8, getMouseX() - host:getAbsoluteX() + T.cell)
    local y = math.min(sh - w:getHeight() - 8, getMouseY() - host:getAbsoluteY() - math.floor(T.cell / 2))
    w:setX(math.max(8, x))
    w:setY(math.max(8, y))
    host:addChild(w)
    w.openedMs = getTimestampMs()
    if KnoxUISound then KnoxUISound.bag(item, true) end
    table.insert(KnoxContainerWindow.list, w)
    KnoxContainerWindow.active = w   -- a new window is the active one (already on top)
end

function KnoxContainerWindow.closeAll()
    local copy = {}
    for _, w in ipairs(KnoxContainerWindow.list) do table.insert(copy, w) end
    for _, w in ipairs(copy) do w:close() end
end
