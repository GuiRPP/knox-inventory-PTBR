-- Quick pick for an empty slot (like Active Matter): hovering an empty
-- equipment / hand / hotbar slot that some carried items fit opens a square
-- panel next to it with those items as tiles; a click on one puts it on,
-- takes it in hand or attaches it. While the panel is up the items' tiles in
-- the grids breathe, so it's clear where each one lies.
--
-- Slots ask for the panel while they draw (KnoxSlotPicker.want); the screen
-- applies it in its prerender (KnoxSlotPicker.sync), as children may only
-- change there. The panel stays while the mouse is over the slot or over it.
--
-- A stack of things that are not all alike (keys to different doors, tapes,
-- batteries with different charge) opens the same panel (KnoxSlotPicker.wantStack)
-- with one tile per kind: such a tile is dragged out, clicked out into a tile
-- of its own, or used as a tile in the grid is.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxTooltip"
require "Knox/KnoxControls"

KnoxSlotPicker = ISPanel:derive("KnoxSlotPicker")
local P = KnoxSlotPicker
local T = KnoxTheme

local GRACE_MS = 220   -- time to move the mouse from the slot onto the panel
local MAX_COLS, MAX_ROWS = 4, 4
-- a stack's kinds: up to 36 (keys to many doors were cut off after 16)
local KIND_COLS, KIND_ROWS = 6, 6
-- The panel comes out of its slot and goes back into it over a moment, and its
-- tiles settle in one after another, as tiles do in the grids.
local OPEN_MS, CLOSE_MS = 150, 110
local TILE_WAIT_MS, TILE_STEP_MS, TILE_MS = 40, 25, 130

P.instance = nil
P.offerColor = nil   -- the offered tiles' frame: sand, or green (batteries for an empty battery slot)
P.request = nil
P.lastWantMs = 0
P.offered = {}   -- item -> true while the panel is up
P.dying = {}     -- closed panels still fading out

--- A slot under the mouse offers `items`; `pick(item)` runs on a click.
--- `side`: where the panel opens - "right" (default, else left), "left" (else
--- right), "below" or "above".
--- `playerNum`: for the item tooltips (else the host screen's).
--- `host`: a window of its own that looks after the panel (the fluid window);
--- without it the screen does, or nothing (the hotbar). `float`: the panel
--- stands on its own over everything (it may then reach past its host's edges
--- and still take clicks).
function P.want(owner, title, items, pick, side, playerNum, host, float)
    P.request = {owner = owner, title = title, items = items, pick = pick, side = side, playerNum = playerNum,
                 host = host, float = float}
end

--- A stack under the mouse offers its kinds: `groups` = lists of its items,
--- one per kind. `act(what, group, mods)` runs on "drag" (pressed and moved),
--- "click" and "rmb" on a kind's tile. The panel floats over the screen.
function P.wantStack(owner, title, groups, act, playerNum)
    local firsts = {}
    for i, g in ipairs(groups) do firsts[i] = g[1] end
    P.request = {owner = owner, title = title, items = firsts, groups = groups, act = act, side = "right",
                 playerNum = playerNum, float = true}
end

--- A thing with a battery under the mouse (a radio, a flashlight - the author,
--- 2026-10-19): one slot shows whether its battery is in and its charge
--- (`battery` = {has, power 0..1, spares = the character's batteries}); with
--- the slot empty, the mouse on it lights the batteries in the grids up green.
function P.wantBattery(owner, title, battery, playerNum)
    P.request = {owner = owner, title = title, items = {owner.item}, battery = battery, side = "right",
                 playerNum = playerNum, float = true}
end

--- Is this item offered by the open panel? (its tile breathes)
function P.isOffered(item)
    return P.instance ~= nil and P.offered[item] == true
end

--- Is the panel open for this slot?
function P.isOpenFor(owner)
    return P.instance ~= nil and P.instance.owner == owner
end

function P.close()
    local p = P.instance
    if not p then return end
    P.instance = nil
    P.offered = {}
    P.offerColor = nil
    -- it fades out first (it takes no clicks meanwhile); P.sweep takes it away
    p.closeMs = getTimestampMs()
    table.insert(P.dying, p)
end

--- Take away the closed panels that have faded out.
function P.sweep()
    if #P.dying == 0 then return end
    local now = getTimestampMs()
    local keep = {}
    for _, p in ipairs(P.dying) do
        if T.anim((now - p.closeMs) / CLOSE_MS) >= 1 then
            p:setVisible(false)
            if p.host and not p.float then p.host:removeChild(p) else p:removeFromUIManager() end
        else
            table.insert(keep, p)
        end
    end
    P.dying = keep
end

--- Called by the screen in its prerender (host = the screen), before the UI is
--- drawn when the screen is closed (host = nil: the panel stands on its own,
--- for the game's hotbar), and by a window that holds its own panel (host =
--- the window). Each takes only the requests meant for it, and keeps only its
--- own panel.
function P.sync(host)
    local now = getTimestampMs()
    P.sweep()
    local req = P.request
    local mine = false
    if req then
        if req.host ~= nil then
            mine = req.host == host
        else
            mine = host == nil or (KnoxScreen ~= nil and host == KnoxScreen.instance)
        end
    end
    if mine then P.request = nil else req = nil end
    if P.instance and P.instance.host ~= host then
        if not req then return end   -- another host's panel: that host looks after it
        P.close()
    end
    if req and #req.items > 0 then
        P.lastWantMs = now
        local p = P.instance
        if not p or p.owner ~= req.owner then
            P.close()
            p = P:new(host, req)
            p:initialise()
            p:instantiate()
            if host and not p.float then host:addChild(p) else p:addToUIManager() end
            P.instance = p
        else
            p.groups, p.act, p.battery = req.groups, req.act, req.battery
            p:setItems(req.items)
            p.pick = req.pick
        end
    elseif P.instance and P.instance:isMouseOver() then
        P.lastWantMs = now
    end
    if P.instance and now - P.lastWantMs > GRACE_MS then P.close() end
end

function P:new(host, req)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.host = host
    o.float = req.float == true
    o.owner = req.owner
    o.title = req.title or ""
    o.pick = req.pick
    o.side = req.side or "right"
    o.playerNum = req.playerNum or (host and host.playerNum) or 0
    o.background = false
    o.moveWithMouse = false
    o.openMs = getTimestampMs()
    o.groups = req.groups
    o.act = req.act
    o.battery = req.battery
    o:setItems(req.items)
    return o
end

function P:setItems(items)
    self.items = {}
    local max = self.groups and KIND_COLS * KIND_ROWS or MAX_COLS * MAX_ROWS
    for i = 1, math.min(#items, max) do self.items[i] = items[i] end
    P.offered = {}
    P.offerColor = nil
    -- (a stack's kinds lie in the hovered tile itself: nothing to point at; the
    -- battery slot points at batteries only while the mouse is on it - prerender)
    if not self.groups and not self.battery then
        for _, it in ipairs(items) do P.offered[it] = true end
    end
    self.total = #items
    if self.battery then
        -- the header's right: the charge, or that there is none in it
        local b = self.battery
        self.total = b.has and (math.floor((b.power or 0) * 100 + 0.5) .. "%") or getText("IGUI_Knox_BatteryNone")
    end
    if self.groups then
        self.total = 0
        for _, g in ipairs(self.groups) do self.total = self.total + #g end
    end
    self:layout()
end

--- Size from the item count; placed next to the slot (right, else left), on screen.
function P:layout()
    local n = #self.items
    local cs, gap, pad = T.cell, 4, math.max(6, math.floor(T.pad / 2) + 2)
    self.cs, self.gap, self.pad = cs, gap, pad
    self.cols = math.max(1, math.min(self.groups and KIND_COLS or MAX_COLS, n))
    self.rows = math.max(1, math.ceil(n / self.cols))
    self.headH = T.sectionH
    local countW = T.measure(T.fontCaps, tostring(self.total or n))
    if self.battery then countW = math.max(countW, T.measure(T.fontCaps, self:batteryHint() or "")) end
    local titleW = T.measure(T.fontCaps, T.upper(self.title)) + countW + pad * 3
    local w = math.max(pad * 2 + self.cols * cs + (self.cols - 1) * gap, titleW)
    local h = self.headH + pad + self.rows * cs + (self.rows - 1) * gap + pad
    self:setWidth(w)
    self:setHeight(h)

    local o = self.owner
    local host = (not self.float) and self.host or nil   -- a floating panel is placed on the screen
    local hx, hy = host and host:getAbsoluteX() or 0, host and host:getAbsoluteY() or 0
    local hw = host and host:getWidth() or getCore():getScreenWidth()
    local hh = host and host:getHeight() or getCore():getScreenHeight()
    local ox, oy = o:getAbsoluteX() - hx, o:getAbsoluteY() - hy
    local x, y
    -- (fromX, fromY: the way to the slot - where the panel comes out of)
    self.fromX, self.fromY = 0, 0
    if self.side == "below" then
        x, y = ox, oy + o:getHeight() + 6
        self.fromY = -1
    elseif self.side == "above" then
        x, y = ox, oy - h - 6
        self.fromY = 1
    elseif self.side == "left" then
        x, y = ox - w - 6, oy
        self.fromX = 1
        if x < 4 then x, self.fromX = ox + o:getWidth() + 6, -1 end
    else
        x, y = ox + o:getWidth() + 6, oy
        self.fromX = -1
        if x + w > hw - 4 then x, self.fromX = ox - w - 6, 1 end
    end
    self:setX(math.max(4, math.min(x, hw - w - 4)))
    self:setY(math.max(4, math.min(y, hh - h - 4)))
end

--- The number of the tile at mx,my, or nil.
function P:indexAt(mx, my)
    local cs, gap, pad = self.cs, self.gap, self.pad
    local lx, ly = mx - pad, my - self.headH - pad
    if lx < 0 or ly < 0 then return nil end
    local c, r = math.floor(lx / (cs + gap)), math.floor(ly / (cs + gap))
    if c >= self.cols or r >= self.rows then return nil end
    if lx - c * (cs + gap) >= cs or ly - r * (cs + gap) >= cs then return nil end   -- in a gap
    local i = r * self.cols + c + 1
    if not self.items[i] then return nil end
    return i
end

function P:cellAt(mx, my)
    local i = self:indexAt(mx, my)
    return i and self.items[i]
end

function P:prerender()
    local w, h = self:getWidth(), self:getHeight()
    local pad, cs, gap = self.pad, self.cs, self.gap
    -- how far it is out: 0 at the slot, 1 in its place
    local now = getTimestampMs()
    local since = now - (self.openMs or 0)
    local k = T.anim(math.min(1, since / OPEN_MS))
    k = 1 - (1 - k) * (1 - k)
    if self.closeMs then k = k * math.max(0, 1 - T.anim((now - self.closeMs) / CLOSE_MS)) end
    local a = k
    local off = math.floor(cs * 0.3 * (1 - k) + 0.5)
    local ox, oy = (self.fromX or 0) * off, (self.fromY or 0) * off
    -- plate like Knox's windows: shadow, frame in sand (it belongs to the hovered slot)
    self:drawRect(ox + 4, oy + 6, w, h, 0.45 * a, 0, 0, 0)
    T.rect(self, ox, oy, w, h, T.color.window, a)
    T.rect(self, ox, oy, w, self.headH, T.color.header, a)
    T.rect(self, ox, oy + self.headH, w, 1, T.color.border, a)
    T.border(self, ox, oy, w, h, T.color.accent, a)
    -- the title and the count on one line, in the middle of the header by their
    -- pixels (by the fonts' line heights the caps sat high and the number low -
    -- the author, 2026-10-19: "В СТОПКЕ 2" crooked)
    T.inkLeft(self, T.upper(self.title), ox + pad, oy, self.headH, T.color.text, T.fontCaps, a)
    local count = tostring(self.total or #self.items)
    -- (the battery slot under the mouse: what a click does, in place of the charge)
    local hint = self.battery and not self.closeMs and self:isMouseOver()
        and self:indexAt(self:getMouseX(), self:getMouseY()) and self:batteryHint()
    if hint then count = hint end
    local cw = T.measure(T.fontCaps, count)
    local _, cy = T.inkOrigin(count, 0, oy, cw, self.headH, T.fontCaps)
    T.textRight(self, count, ox + w - pad, cy, T.color.dim, T.fontCaps, a)

    local over = not self.closeMs and self:isMouseOver()
    if self.battery then return self:drawBattery(ox, oy, a, over) end
    local hovered = over and self:cellAt(self:getMouseX(), self:getMouseY())
    for i, it in ipairs(self.items) do
        local c, r = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
        local x, y = ox + pad + c * (cs + gap), oy + self.headH + pad + r * (cs + gap)
        -- each tile drops into its place a little after the one before it
        local tt = T.anim(math.max(0, math.min(1, (since - TILE_WAIT_MS - (i - 1) * TILE_STEP_MS) / TILE_MS)))
        local ta = a * tt
        if ta > 0.01 then
            y = y - math.floor(cs * 0.22 * (1 - tt) * (1 - tt) + 0.5)
            T.rect(self, x, y, cs, cs, T.category[T.categoryOf(it)], ta)
            if it == hovered then self:drawRect(x, y, cs, cs, 0.08, 1, 1, 1) end
            local side = math.floor(cs * 0.8)
            ISInventoryItem.renderItemIcon(self, it, x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2), ta, side, side)
            local g = self.groups and self.groups[i]
            if g then
                -- a stack's kind: the charge left, how many of it (as a tile in the grid)
                if it:IsDrainable() and not it:isBroken() then
                    local sum = 0
                    for _, gi in ipairs(g) do sum = sum + gi:getCurrentUsesFloat() end
                    T.tileMeter(self, x, y, cs, cs, sum / #g, T.color.accent, ta, 0)
                end
                if #g > 1 then
                    T.outlinedRight(self, tostring(#g), x + cs - 4, y + cs - T.fontTileH - 3, T.color.bright, T.fontTile, ta)
                end
            end
            T.tileFrame(self, x, y, cs, cs, it == hovered and T.color.accent or T.color.tileFrame, ta)
        end
    end
    if hovered then KnoxTooltip.want(hovered, self.playerNum) end
end

--- The battery slot (P.wantBattery): the battery with its charge, or an empty
--- slot with a faint battery in it; the mouse on the empty slot lights the
--- character's batteries in the grids green (red frame: there are none).
local batteryTex = nil
function P:drawBattery(ox, oy, a, over)
    local cs, pad = self.cs, self.pad
    local x, y = ox + pad, oy + self.headH + pad
    local b = self.battery
    if batteryTex == nil then batteryTex = getTexture("Item_Battery") or false end
    local side = math.floor(cs * 0.8)
    local ix, iy = x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2)
    local hot = over and self:indexAt(self:getMouseX(), self:getMouseY()) ~= nil
    if b.has then
        P.offered, P.offerColor = {}, nil
        T.rect(self, x, y, cs, cs, T.category.tool or T.color.cell, a)
        if batteryTex then self:drawTextureScaledAspect(batteryTex, ix, iy, side, side, a, 1, 1, 1) end
        local p = math.max(0, math.min(1, b.power or 0))
        T.tileMeter(self, x, y, cs, cs, p, p > 0.25 and T.color.accent or T.color.bad, a, 0)
        T.tileFrame(self, x, y, cs, cs, hot and T.color.accent or T.color.tileFrame, a)
        return
    end
    T.rect(self, x, y, cs, cs, T.color.cell, a)
    if batteryTex then self:drawTextureScaledAspect(batteryTex, ix, iy, side, side, 0.22 * a, 1, 1, 1) end
    local spares = b.spares or {}
    if hot then
        P.offered = {}
        for _, it in ipairs(spares) do P.offered[it] = true end
        P.offerColor = T.color.ok
        local c = #spares > 0 and T.color.ok or T.color.bad
        self:drawRect(x, y, cs, cs, 0.2 * a, c.r, c.g, c.b)
        T.border(self, x, y, cs, cs, c, a)
    else
        P.offered, P.offerColor = {}, nil
        T.border(self, x, y, cs, cs, T.color.tileEdge, a)
    end
end

local DRAG_START_PX = 5

--- What a click on the battery slot does, or nil (empty, no battery to put in).
function P:batteryHint()
    local b = self.battery
    if not b or not b.act then return nil end
    if b.has then return T.upper(getText("IGUI_Knox_BatteryTake")) end
    if b.spares and #b.spares > 0 then return T.upper(getText("IGUI_Knox_BatteryPut")) end
    return nil
end

--- The battery slot clicked or dragged: its battery taken out, or (empty) the
--- fullest of the character's put in (KnoxGridView.batteryAct).
function P:useBattery()
    local b = self.battery
    if not b or not b.act then return end
    local what = b.has and "take" or ((b.spares and #b.spares > 0) and "put" or nil)
    if not what then return end
    P.close()
    b.act(what)
end

function P:onMouseDown(x, y)
    -- a stack's kind or the battery: a press may become a drag (see onMouseMove)
    local i = (self.act or self.battery) and not self.closeMs and self:indexAt(x, y)
    if i then self.press = {i = i, x = getMouseX(), y = getMouseY(), mods = KnoxControls.mods()} end
    return true
end

function P:onMouseMove(dx, dy)
    local p = self.press
    if not p or self.closeMs then return end
    if not isMouseButtonDown(0) then
        self.press = nil
        return
    end
    if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) < DRAG_START_PX then return end
    self.press = nil
    -- (the battery dragged out of its slot: taken out, into the main inventory)
    if self.battery then
        if self.battery.has then self:useBattery() end
        return
    end
    local act, g = self.act, self.groups[p.i]
    P.close()
    -- (hidden at once: the drop must reach whatever lies under it)
    self:setVisible(false)
    if g then act("drag", g, p.mods) end
end

function P:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function P:onMouseUpOutside(x, y)
    self.press = nil
end

function P:onMouseUp(x, y)
    if self.closeMs then return true end
    if self.battery then
        local p = self.press
        self.press = nil
        if p and self:indexAt(x, y) == p.i then self:useBattery() end
        return true
    end
    if self.act then
        local p = self.press
        self.press = nil
        local i = self:indexAt(x, y)
        if p and i == p.i then
            local act, g = self.act, self.groups[i]
            P.close()
            act("click", g, p.mods)
        end
        return true
    end
    local it = self:cellAt(x, y)
    if it and self.pick then
        local pick = self.pick
        P.close()
        pick(it)
    end
    return true
end

function P:onRightMouseUp(x, y)
    if self.battery then
        if not self.closeMs and self:indexAt(x, y) then self:useBattery() end
        return true
    end
    local i = self.act and not self.closeMs and self:indexAt(x, y)
    if i then
        local act, g = self.act, self.groups[i]
        P.close()
        act("rmb", g, KnoxControls.mods())
    end
    return true
end
function P:onMouseWheel(del) return true end

-- With the Knox screen closed (the game's hotbar): the panel and the item
-- tooltip are kept up to date here, before the UI is drawn (top-level
-- elements may be added or removed only outside of drawing).
-- (with nothing asked for, open or closing, and no thing hovered nor a tooltip
-- up - most frames of a game - nothing is done: Viewpoint players count every
-- frame, 2026-10-20)
Events.OnPreUIDraw.Add(function()
    if KnoxScreen and KnoxScreen.instance then return end
    if T.on("hotbar") and (P.request or P.instance or #P.dying > 0) then P.sync(nil) end
    local K = KnoxTooltip
    if T.on("tooltips") and (K.wanted or K.lastHover or K.fold or (K.tip and K.tip.knoxShown)) then K.apply() end
end)

return KnoxSlotPicker
