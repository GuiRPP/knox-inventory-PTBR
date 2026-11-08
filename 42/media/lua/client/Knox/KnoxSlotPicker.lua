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
-- The battery panel (the author, 2026-10-29; the mockup .claude/mockups/battery_v1.html):
-- the one in it, a line, then the character's - 4 a row, 12 cells at most (the
-- 12th says how many more there are).
local BATTERY_COLS, BATTERY_CELLS, BATTERY_SEP = 4, 12, 6

P.instance = nil
P.offerColor = nil   -- the offered tiles' frame: sand, or green (batteries for an empty battery slot)
P.request = nil
P.lastWantMs = 0
P.offered = {}   -- item -> true while the panel is up
-- (they fade in, as the grids' green - the author, 2026-10-30: "слишком резко")
P.offeredMs = 0  -- when what is offered last changed
P.offerA = 1     -- how far it has faded in (0..1), once a frame by P.sync
local OFFER_FADE_MS = 200
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
--- 2026-10-19): one slot shows whether its battery is in and its charge, the
--- character's batteries stand next to it to pick from (`battery` = {has,
--- power 0..1, spares = the character's batteries fullest first, charges = theirs,
--- act(what, battery)}); with the slot empty, the mouse on it lights the
--- batteries in the grids up green.
function P.wantBattery(owner, title, battery, playerNum)
    P.request = {owner = owner, title = title, items = {owner.item}, battery = battery, side = "right",
                 playerNum = playerNum, float = true}
end

--- A magazine or a gun under the mouse (the author, 2026-10-30; the mockup
--- .claude/mockups/magazine_v2.html): the battery panel's kin - what is in it in
--- the first cell, past the line what may go in (KnoxLoad.offer builds `load`:
--- kind, inner, spares, total, jam, hint(i), act(i)).
function P.wantLoad(owner, title, load, playerNum, side)
    P.request = {owner = owner, title = title, items = {owner.item}, load = load, side = side or "right",
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

--- Closed on the player's word (the quick items' key pressed again): what was
--- asked for this frame goes too - the thing's tile had asked for the panel
--- before the key was seen, and it opened again at once (the author, 2026-10-30).
function P.dismiss()
    P.request = nil
    P.close()
end

function P.close()
    local p = P.instance
    if not p then return end
    P.instance = nil
    P.offered = {}
    P.offerColor = nil
    if KnoxLoad then KnoxLoad.picking, KnoxLoad.panelFor = false, nil end
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
            p.groups, p.act, p.battery, p.load = req.groups, req.act, req.battery, req.load
            p:setItems(req.items)
            p.pick = req.pick
        end
    elseif P.instance and P.instance:isMouseOver() then
        P.lastWantMs = now
    end
    if P.instance and now - P.lastWantMs > GRACE_MS then P.close() end
    P.offerA = T.anim(math.max(0, math.min(1, (now - P.offeredMs) / OFFER_FADE_MS)))
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
    P.offeredMs = o.openMs
    o.groups = req.groups
    o.act = req.act
    o.battery = req.battery
    o.load = req.load
    o:setItems(req.items)
    return o
end

function P:setItems(items)
    self.items = {}
    local max = self.groups and KIND_COLS * KIND_ROWS or MAX_COLS * MAX_ROWS
    for i = 1, math.min(#items, max) do self.items[i] = items[i] end
    -- (a stack's kinds lie in the hovered tile itself: nothing to point at; the
    -- battery panel points at batteries only while the mouse is on them - drawBattery)
    if not self.battery and not self.load then
        P.offered = {}
        P.offerColor = nil
    end
    if not self.groups and not self.battery and not self.load then
        for _, it in ipairs(items) do P.offered[it] = true end
    end
    self.total = #items
    if self.battery then
        -- the header's right: the charge, or that there is none in it
        local b = self.battery
        self.total = b.has and P.percent(b.power) or getText("IGUI_Knox_BatteryNone")
        local n = b.spares and #b.spares or 0
        self.shown = n > BATTERY_CELLS and BATTERY_CELLS - 1 or n
        self.more = n - self.shown
    elseif self.load then
        -- the header's right: the rounds in it of how many, none, or jammed (KnoxLoad)
        local l = self.load
        self.total = l.total
        local n = #l.spares
        self.shown = n > BATTERY_CELLS and BATTERY_CELLS - 1 or n
        self.more = n - self.shown
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
    local bodyW
    if self.battery or self.load then
        -- (the character's batteries from sx on, past the line)
        local cells = self.shown + (self.more > 0 and 1 or 0)
        self.cols = math.max(1, math.min(BATTERY_COLS, cells))
        self.rows = math.max(1, math.ceil(cells / BATTERY_COLS))
        self.sx = pad + cs + (cells > 0 and BATTERY_SEP * 2 + 1 or 0)
        bodyW = cells > 0 and self.sx + self.cols * cs + (self.cols - 1) * gap + pad or pad * 2 + cs
        -- (a charge's number: the tops of its digits 6 px under the tile's top)
        local _, top = T.inkBox(T.fontTile, "H")
        self.percentDy = 6 - top
    else
        self.cols = math.max(1, math.min(self.groups and KIND_COLS or MAX_COLS, n))
        self.rows = math.max(1, math.ceil(n / self.cols))
        bodyW = pad * 2 + self.cols * cs + (self.cols - 1) * gap
    end
    self.headH = T.sectionH
    local countW = T.measure(T.fontCaps, tostring(self.total or n))
    -- (as wide as the widest the header may say, so it doesn't jump under the mouse)
    if self.battery then countW = math.max(countW, P.batteryWords().width) end
    if self.load then countW = math.max(countW, P.loadWords().width, T.measure(T.fontCaps, self.load.widest or "")) end
    local titleW = T.measure(T.fontCaps, T.upper(self.title)) + countW + pad * 3
    local w = math.max(bodyW, titleW)
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
    if self.battery or self.load then
        -- 1: the one in it; k + 1: the character's k-th (not the "+N" cell)
        if lx < cs and ly < cs then return 1 end
        local sl = mx - self.sx
        if sl < 0 then return nil end
        local c, r = math.floor(sl / (cs + gap)), math.floor(ly / (cs + gap))
        if c >= self.cols or r >= self.rows then return nil end
        if sl - c * (cs + gap) >= cs or ly - r * (cs + gap) >= cs then return nil end
        local k = r * self.cols + c + 1
        if k > self.shown then return nil end
        return k + 1
    end
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
    local over = not self.closeMs and self:isMouseOver()
    -- (the quick items' key pressed again, the mouse on the panel: the tooltip
    -- back - the author, 2026-10-30)
    if over and (self.battery or self.load) and P.instance == self and KnoxLoad and KnoxLoad.keyHit() then
        P.dismiss()
        over = false
    end
    -- (a battery under the mouse: what a click does, in place of the charge)
    local hi = (self.battery or self.load) and over and self:indexAt(self:getMouseX(), self:getMouseY())
    local hint = hi and (self.battery and self:batteryHint(hi) or self.load and self:loadHint(hi))
    local cc = T.color.dim
    if hint then count = hint
    elseif self.load and self.load.jam then count, cc = P.loadWords().jam, T.color.badText end   -- (jammed: in red)
    local cw = T.measure(T.fontCaps, count)
    local _, cy = T.inkOrigin(count, 0, oy, cw, self.headH, T.fontCaps)
    T.textRight(self, count, ox + w - pad, cy, cc, T.fontCaps, a)

    if self.battery then return self:drawBattery(ox, oy, a, hi, since) end
    if self.load then return self:drawLoad(ox, oy, a, hi, since) end
    local hovered = over and self:cellAt(self:getMouseX(), self:getMouseY())
    for i, it in ipairs(self.items) do
        local c, r = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
        local x, y = ox + pad + c * (cs + gap), oy + self.headH + pad + r * (cs + gap)
        -- each tile drops into its place a little after the one before it
        local tt = T.anim(math.max(0, math.min(1, (since - TILE_WAIT_MS - (i - 1) * TILE_STEP_MS) / TILE_MS)))
        local ta = a * tt
        if ta > 0.01 then
            y = y - math.floor(cs * 0.22 * (1 - tt) * (1 - tt) + 0.5)
            local g = self.groups and self.groups[i]
            -- its state: the colour's height (condition_v3, the author, 2026-10-31); a stack's
            -- kind: the charge left in all of it (as a tile in the grid)
            local level
            if g and it:IsDrainable() and not it:isBroken() then
                local sum = 0
                for _, gi in ipairs(g) do sum = sum + gi:getCurrentUsesFloat() end
                level = sum / #g
            else
                level = T.itemLevel(it)
            end
            T.tileFill(self, x, y, cs, cs, level, T.category[T.categoryOf(it)], ta)
            if it == hovered then self:drawRect(x, y, cs, cs, 0.08, 1, 1, 1) end
            local side = math.floor(cs * 0.8)
            T.itemIcon(self, it, x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2), side, ta)
            if g and #g > 1 then
                -- how many of it
                T.outlinedRight(self, tostring(#g), x + cs - 4, y + cs - T.fontTileH - 3, T.color.bright, T.fontTile, ta)
            end
            T.tileFrame(self, x, y, cs, cs, it == hovered and T.color.accent or T.color.tileFrame, ta)
        end
    end
    if hovered then KnoxTooltip.want(hovered, self.playerNum) end
end

--- A charge as the panel writes it ("23%"), made once for each number: it is
--- written every frame.
local percents = {}
function P.percent(p)
    local n = math.floor(math.max(0, math.min(1, p or 0)) * 100 + 0.5)
    local s = percents[n]
    if not s then
        s = n .. "%"
        percents[n] = s
    end
    return s
end

local mores = {}   -- "+N", made once each
local NONE = {}
local words = nil
--- What the battery panel's header says under the mouse, in capitals, and the
--- widest of it with a full charge (measured again when the font changes).
function P.batteryWords()
    if not words or words.font ~= T.fontCaps then
        words = {font = T.fontCaps, take = T.upper(getText("IGUI_Knox_BatteryTake")),
                 put = T.upper(getText("IGUI_Knox_BatteryPut")), swap = T.upper(getText("IGUI_Knox_BatterySwap"))}
        words.width = math.max(T.measure(T.fontCaps, words.take), T.measure(T.fontCaps, words.put),
            T.measure(T.fontCaps, words.swap), T.measure(T.fontCaps, "100%"))
    end
    return words
end

--- The battery panel (P.wantBattery): the battery in the thing with its charge,
--- or an empty slot with a faint battery in it; past a line, the character's
--- batteries. The mouse on one of them points at it in the grids; otherwise all
--- of them are lit up green (the empty slot hovered with none: a red frame).
local batteryTex = nil
--- `own`: the one in the thing - framed in sand always, apart from those that may
--- go in (the author, 2026-10-30)
function P:batteryTile(x, y, p, hot, a, own)
    local cs = self.cs
    local side = math.floor(cs * 0.8)
    p = math.max(0, math.min(1, p or 0))
    T.tileFill(self, x, y, cs, cs, p, T.category.tool or T.color.cell, a)   -- (what is left: the colour's height, 2026-10-31)
    if hot then self:drawRect(x, y, cs, cs, 0.08 * a, 1, 1, 1) end
    if batteryTex then
        self:drawTextureScaledAspect(batteryTex, x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2), side, side, a, 1, 1, 1)
    end
    T.outlinedRight(self, P.percent(p), x + cs - 5, y + self.percentDy, T.color.bright, T.fontTile, a)
    T.tileFrame(self, x, y, cs, cs, (hot or own) and T.color.accent or T.color.tileFrame, a)
end

function P:drawBattery(ox, oy, a, hi, since)
    local cs, gap, pad = self.cs, self.gap, self.pad
    local x, y = ox + pad, oy + self.headH + pad
    local b = self.battery
    local spares = b.spares or NONE
    if batteryTex == nil then batteryTex = getTexture("Item_Battery") or false end
    local side = math.floor(cs * 0.8)
    local inHot = hi == 1
    -- what the grids point at: the battery hovered here (sand); else every one
    -- that fits is green - KnoxLoad's, from the moment the thing is hovered (the
    -- author, 2026-10-30, "с фонариком делаем также") - set again only on a change
    local want = hi and hi > 1 and spares[hi - 1] or nil
    if P.instance == self and (want ~= self.offeredFor or spares ~= self.offeredList) then
        self.offeredFor, self.offeredList = want, spares
        P.offered, P.offerColor = {}, nil
        if want then P.offered[want], P.offeredMs = true, getTimestampMs() end
        if KnoxLoad then KnoxLoad.picking = want ~= nil end
    end
    -- (the battery under the mouse: its tooltip - the thing's own is not shown, 2026-10-30)
    if hi and hi > 1 and hi - 1 <= self.shown and spares[hi - 1] then KnoxTooltip.want(spares[hi - 1], self.playerNum) end
    if b.has then
        self:batteryTile(x, y, b.power, inHot, a, true)
    else
        T.rect(self, x, y, cs, cs, T.color.cell, a)
        if batteryTex then
            self:drawTextureScaledAspect(batteryTex, x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2), side, side, 0.22 * a, 1, 1, 1)
        end
        if inHot then
            local c = #spares > 0 and T.color.ok or T.color.bad
            self:drawRect(x, y, cs, cs, 0.2 * a, c.r, c.g, c.b)
            T.border(self, x, y, cs, cs, c, a)
        else
            T.border(self, x, y, cs, cs, T.color.tileEdge, a)
        end
    end
    local cells = self.shown + (self.more > 0 and 1 or 0)
    if cells == 0 then return end
    T.rect(self, ox + pad + cs + BATTERY_SEP, y, 1, self.rows * cs + (self.rows - 1) * gap, T.color.tileEdge, a)
    local charges = b.charges or NONE
    for k = 1, cells do
        local c, r = (k - 1) % self.cols, math.floor((k - 1) / self.cols)
        local tx, ty = ox + self.sx + c * (cs + gap), y + r * (cs + gap)
        -- each tile drops into its place a little after the one before it (as the panel's other tiles)
        local tt = T.anim(math.max(0, math.min(1, (since - TILE_WAIT_MS - k * TILE_STEP_MS) / TILE_MS)))
        local ta = a * tt
        if ta > 0.01 then
            ty = ty - math.floor(cs * 0.22 * (1 - tt) * (1 - tt) + 0.5)
            if k <= self.shown then
                self:batteryTile(tx, ty, charges[k], hi == k + 1, ta)
                -- (the empty slot hovered: the one a click puts in, framed green
                -- as the grids' batteries light up)
                if k == 1 and inHot and not b.has then T.tileFrame(self, tx, ty, cs, cs, T.color.ok, ta) end
            else
                local m = mores[self.more]
                if not m then
                    m = "+" .. self.more
                    mores[self.more] = m
                end
                T.rect(self, tx, ty, cs, cs, T.color.cell, ta)
                T.border(self, tx, ty, cs, cs, T.color.tileEdge, ta)
                local d = T.color.dim
                T.inkCentre(self, m, tx, ty, cs, cs, d.r, d.g, d.b, ta, T.fontCaps)
            end
        end
    end
end

local DRAG_START_PX = 5

--- What a click on the battery panel's cell `i` (indexAt) does, or nil (the
--- empty slot, no battery to put in).
function P:batteryHint(i)
    local b = self.battery
    if not b or not b.act or not i then return nil end
    local s = P.batteryWords()
    if i > 1 then return b.has and s.swap or s.put end
    if b.has then return s.take end
    if b.spares and #b.spares > 0 then return s.put end
    return nil
end

--- The battery panel's cell `i` clicked (or the one in it dragged out): the
--- battery in it taken out; one of the character's put in (the one in it out
--- first); the empty slot - the fullest put in (KnoxGridView.batteryAct).
function P:useBattery(i)
    local b = self.battery
    if not b or not b.act or not i then return end
    local spare = i > 1 and b.spares and b.spares[i - 1] or nil
    local what = (spare and "put") or (b.has and "take") or ((b.spares and #b.spares > 0) and "put" or nil)
    if not what then return end
    P.close()
    b.act(what, spare)
end

-- The magazine and gun panel (P.wantLoad, the author, 2026-10-30) ------------------

local loadWords = nil
--- What the magazine / gun panel's header says under the mouse, in capitals,
--- and the widest of it (measured again when the font changes).
function P.loadWords()
    if not loadWords or loadWords.font ~= T.fontCaps then
        local w = {font = T.fontCaps}
        for key, id in pairs({load = "Load", unload = "Unload", open = "Open", insert = "Insert", take = "Take",
                              swap = "Swap", rack = "Rack", jam = "Jammed"}) do
            w[key] = T.upper(getText("IGUI_Knox_Load" .. id))
        end
        local width = 0
        for key, s in pairs(w) do
            if key ~= "font" then width = math.max(width, T.measure(T.fontCaps, s)) end
        end
        w.width = width
        loadWords = w
    end
    return loadWords
end

-- a magazine's rounds as its cell writes them ("12", "12+1": one in the chamber;
-- "+1": only the one in the chamber), made once each: written every frame
local roundsText = {}
function P.rounds(n, plus)
    local key = (n or -1) * 2 + (plus and 1 or 0)
    local s = roundsText[key]
    if not s then
        s = (n and tostring(n) or "") .. (plus and "+1" or "")
        roundsText[key] = s
    end
    return s
end
local counts = {}   -- a pile's count, made once each

--- One cell of the panel: a magazine (its rounds at the top right as the
--- battery's charge), a pile of rounds or of boxes (how many, at the
--- bottom right as a stack's count in the grid). An action using it: as the grid
--- shows a thing in use.
--- `own`: what is in it (the first cell) - framed in sand always, apart from
--- what may go in (the author, 2026-10-30)
function P:loadTile(x, y, s, hot, a, own)
    local cs = self.cs
    local side = math.floor(cs * 0.8)
    T.rect(self, x, y, cs, cs, T.category[T.categoryOf(s.item)] or T.color.cell, a)
    if hot then self:drawRect(x, y, cs, cs, 0.08 * a, 1, 1, 1) end
    ISInventoryItem.renderItemIcon(self, s.item, x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2), a, side, side)
    if s.max then
        -- (the hidden rounds, the author, 2026-10-31: none written; held R tells)
        if not (KnoxMagKnown and KnoxMagKnown.hide) then
            T.outlinedRight(self, P.rounds(s.n, s.plus), x + cs - 5, y + self.percentDy, T.color.bright, T.fontTile, a)
        end
    elseif (s.count or 0) > 1 then
        local c = counts[s.count]
        if not c then
            c = tostring(s.count)
            counts[s.count] = c
        end
        T.outlinedRight(self, c, x + cs - 4, y + cs - T.fontTileH - 3, T.color.bright, T.fontTile, a)
    end
    T.tileFrame(self, x, y, cs, cs, s.jam and T.color.bad or ((hot or own) and T.color.accent or T.color.tileFrame), a)
    if s.busy then T.inUse(self, x, y, cs, cs, s.busy) end
end

--- The magazine / gun panel: what is in it (a magazine and its rounds, a gun's
--- magazine or rounds), or an empty slot with a faint magazine; past the line,
--- what may go in. The mouse on one of those points at it in the grids (sand),
--- else everything that fits is lit up green (KnoxLoad.lit). A cell whose click
--- would do nothing does not light up (a full magazine's rounds).
function P:drawLoad(ox, oy, a, hi, since)
    local cs, gap, pad = self.cs, self.gap, self.pad
    local x, y = ox + pad, oy + self.headH + pad
    local l = self.load
    local spares, inner = l.spares, l.inner
    -- what the grids point at - set again only on a change
    local want = hi and hi > 1 and hi - 1 <= self.shown and l.hint(hi) and spares[hi - 1] or nil
    if P.instance == self and (want ~= self.offeredFor or spares ~= self.offeredList) then
        self.offeredFor, self.offeredList = want, spares
        P.offered, P.offerColor = {}, nil
        if want then
            for _, it in ipairs(want.items) do P.offered[it] = true end
            P.offeredMs = getTimestampMs()
        end
        if KnoxLoad then KnoxLoad.picking = want ~= nil end
    end
    -- (the magazine or rounds under the mouse: its tooltip - the thing's own is not
    -- shown, 2026-10-30; the first cell's is a stand-in, it has none)
    local sp = hi and hi > 1 and hi - 1 <= self.shown and spares[hi - 1]
    if sp then KnoxTooltip.want(sp.item, self.playerNum) end
    local inHint = hi == 1 and l.hint(1) ~= nil
    if inner.empty then
        local side = math.floor(cs * 0.8)
        T.rect(self, x, y, cs, cs, T.color.cell, a)
        ISInventoryItem.renderItemIcon(self, inner.item, x + math.floor((cs - side) / 2), y + math.floor((cs - side) / 2), 0.22 * a, side, side)
        if inner.plus and not (KnoxMagKnown and KnoxMagKnown.hide) then T.outlinedRight(self, P.rounds(nil, true), x + cs - 5, y + self.percentDy, T.color.bright, T.fontTile, a) end
        if hi == 1 then
            local c = inHint and T.color.ok or T.color.bad
            self:drawRect(x, y, cs, cs, 0.2 * a, c.r, c.g, c.b)
            T.border(self, x, y, cs, cs, c, a)
        else
            T.border(self, x, y, cs, cs, T.color.tileEdge, a)
        end
    else
        self:loadTile(x, y, inner, inHint, a, true)
        -- (nothing to take out and nothing to put in: red, as the battery's empty slot)
        if hi == 1 and not inHint and #spares == 0 then
            local c = T.color.bad
            self:drawRect(x, y, cs, cs, 0.2 * a, c.r, c.g, c.b)
            T.tileFrame(self, x, y, cs, cs, c, a)
        end
    end
    local cells = self.shown + (self.more > 0 and 1 or 0)
    if cells == 0 then return end
    T.rect(self, ox + pad + cs + BATTERY_SEP, y, 1, self.rows * cs + (self.rows - 1) * gap, T.color.tileEdge, a)
    for k = 1, cells do
        local c, r = (k - 1) % self.cols, math.floor((k - 1) / self.cols)
        local tx, ty = ox + self.sx + c * (cs + gap), y + r * (cs + gap)
        -- each tile drops into its place a little after the one before it (as the panel's other tiles)
        local tt = T.anim(math.max(0, math.min(1, (since - TILE_WAIT_MS - k * TILE_STEP_MS) / TILE_MS)))
        local ta = a * tt
        if ta > 0.01 then
            ty = ty - math.floor(cs * 0.22 * (1 - tt) * (1 - tt) + 0.5)
            if k <= self.shown then
                self:loadTile(tx, ty, spares[k], hi == k + 1 and l.hint(k + 1) ~= nil, ta)
                -- (the empty slot hovered: the one a click puts in, framed green)
                if k == 1 and inHint and inner.empty then T.tileFrame(self, tx, ty, cs, cs, T.color.ok, ta) end
            else
                local m = mores[self.more]
                if not m then
                    m = "+" .. self.more
                    mores[self.more] = m
                end
                T.rect(self, tx, ty, cs, cs, T.color.cell, ta)
                T.border(self, tx, ty, cs, cs, T.color.tileEdge, ta)
                local d = T.color.dim
                T.inkCentre(self, m, tx, ty, cs, cs, d.r, d.g, d.b, ta, T.fontCaps)
            end
        end
    end
end

--- What a click on the magazine / gun panel's cell `i` does (its word), or nil.
function P:loadHint(i)
    local l = self.load
    if not l or not i then return nil end
    local key = l.hint(i)
    return key and P.loadWords()[key] or nil
end

--- The magazine / gun panel's cell `i` clicked (or a gun's magazine dragged out).
function P:useLoad(i)
    local l = self.load
    if not l or not i or not l.hint(i) then return end
    P.close()
    l.act(i)
end

function P:onMouseDown(x, y)
    -- a stack's kind, the battery or a magazine: a press may become a drag (see onMouseMove)
    local i = (self.act or self.battery or self.load) and not self.closeMs and self:indexAt(x, y)
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
    -- (the battery in it dragged out of its slot: taken out, into the main inventory)
    if self.battery then
        if p.i == 1 and self.battery.has then self:useBattery(1) end
        return
    end
    -- (a gun's magazine dragged out of it: taken out)
    if self.load then
        if p.i == 1 and self.load.hint(1) == "take" then self:useLoad(1) end
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
        if p and self:indexAt(x, y) == p.i then self:useBattery(p.i) end
        return true
    end
    if self.load then
        local p = self.press
        self.press = nil
        if p and self:indexAt(x, y) == p.i then self:useLoad(p.i) end
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
        if not self.closeMs then self:useBattery(self:indexAt(x, y)) end
        return true
    end
    if self.load then
        if not self.closeMs then self:useLoad(self:indexAt(x, y)) end
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
local function closedFrame()
    if KnoxScreen and KnoxScreen.instance then return end
    if KnoxNewsLive and KnoxNewsLive.live then return end   -- (the live grid of a news post keeps them itself)
    -- (a magazine's or gun's panel from the hotbar: its bar of rounds going in follows the action -
    -- the screen, which keeps it, is shut; it stood still - QA, 2026-11-04)
    local open = P.instance
    if open and open.load and KnoxGrid then pcall(KnoxGrid.updateUse, getSpecificPlayer(open.playerNum or 0)) end
    if T.on("hotbar") and (P.request or P.instance or #P.dying > 0) then P.sync(nil) end
    local K = KnoxTooltip
    if T.on("tooltips") and (K.wanted or K.lastHover or K.fold or (K.tip and K.tip.knoxShown)) then K.apply() end
end
Events.OnPreUIDraw.Add(closedFrame)
T.offInGame(Events.OnPreUIDraw, closedFrame, "inventory", "hotbar", "tooltips", "rmenu")

return KnoxSlotPicker
