-- Setting a watch's or a clock's alarm, in Knox's look - it takes the place of
-- the game's ISAlarmClockDialog (the author, 2026-10-18: "in the style of the
-- TV and the radio: the window a little like the thing itself"). The game's
-- own calls do the work: setHour / setMinute / setAlarmSet / syncAlarmClock.
--
-- The thing itself in the middle: a wristwatch with its strap, or a desk clock
-- on its feet; on its display the alarm's time in amber digits over faint
-- "88:88" segments, small arrows over and under the hours and the minutes (the
-- wheel too), "AL" lit while the alarm is on. The alarm is switched by a key on
-- the thing itself - a watch's on its left side, a clock's on its top: pushed
-- in and lit while on (or by "AL"). No Done button: the cross, Esc or Enter set
-- it and close (walking off closes it unset, as the game's). A thread runs from
-- the thing's tile, and the tile has the sand frame of an open menu meanwhile.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxThread"

KnoxAlarmWindow = ISPanel:derive("KnoxAlarmWindow")
local A = KnoxAlarmWindow
local T = KnoxTheme

A.instance = nil
A.lastX, A.lastY = nil, nil

local inRect = T.inRect

-- the radio's handheld plastic; the display as its dial, the digits in its amber
local CASE = {r = 0x20 / 255, g = 0x24 / 255, b = 0x1d / 255}
local CASE_EDGE = {r = 0x3b / 255, g = 0x42 / 255, b = 0x35 / 255}
local STRAP = {r = 0x17 / 255, g = 0x19 / 255, b = 0x16 / 255}
local STRAP_EDGE = {r = 0x2c / 255, g = 0x30 / 255, b = 0x2a / 255}
local LCD = {r = 0x0f / 255, g = 0x12 / 255, b = 0x0e / 255}
local LCD_EDGE = {r = 0x3a / 255, g = 0x43 / 255, b = 0x36 / 255}
local AMBER = {r = 1, g = 0.71, b = 0.28}

local MIN_STEP = 10   -- as the game's dialog: the alarm goes off at a ten minutes' tick

function KnoxAlarmWindow:new(player, alarm)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.alarm = alarm
    o.wrist = instanceof(alarm, "AlarmClockClothing")
    o.hour = math.max(0, math.min(23, alarm:getHour() or 0))
    o.minute = math.floor(math.max(0, math.min(59, alarm:getMinute() or 0)) / MIN_STEP) * MIN_STEP
    o.on = alarm:isAlarmSet() == true
    o.px, o.py = player:getX(), player:getY()
    o.background = false
    o.moveWithMouse = false
    return o
end

function KnoxAlarmWindow:createChildren()
    local c, pad = T.cell, T.pad
    local L = {}
    L.headerH = T.sectionH + 4
    L.btnH = math.floor(c * 0.62 + 0.5)
    -- (the biggest of Knox's fonts is 40 px)
    L.digits = T.javaFonts and T.makeFont("head", math.min(40, c * 1.25)) or T.fontHeader
    L.small = T.fontTile
    -- each digit in a cell of its own, as wide as an 8, the colon in a narrower
    -- one between (the font's 1 is narrower than its 8: the colon stood off
    -- middle, nearer the hours - the author, 2026-10-18)
    local cellW = T.measure(L.digits, "8") + 2
    local colonW = math.max(T.measure(L.digits, ":"), math.floor(cellW * 0.6))
    local dw = cellW * 4 + colonW
    local dh = T.fontH(L.digits)
    L.cellW, L.colonW = cellW, colonW
    -- small arrows (rows of a triangle): over and under the hours and the minutes
    L.arrow = math.max(4, math.floor(c * 0.16))
    -- the display: the digits with room for the arrows above and below, "AL" in the corner
    L.lcdW = dw + math.floor(c * 1.1)
    L.lcdH = dh + L.arrow * 2 + math.floor(c * 0.55)
    local inset = math.floor(c * 0.32)
    L.caseW = L.lcdW + inset * 2
    L.caseH = L.lcdH + inset * 2
    L.strapW = math.floor(L.caseW * 0.56)
    L.strapH = self.wrist and math.floor(c * 1.0) or 0
    L.feetH = self.wrist and 0 or math.floor(c * 0.25)
    -- the alarm's button on the thing itself: a wristwatch's on its left side, a
    -- desk clock's on its top (in place of a separate "Alarm" button)
    L.keyLong = math.floor(c * 0.55)
    L.keyOut = math.max(5, math.floor(c * 0.16))
    L.topH = self.wrist and 0 or L.keyOut
    local devH = L.strapH * 2 + L.topH + L.caseH + L.feetH
    -- (no Done button: the cross or Esc sets it - the author, 2026-10-18)
    L.w = pad * 2 + L.caseW + (L.keyOut + pad) * 2
    L.devY = L.headerH + pad
    L.caseX = math.floor((L.w - L.caseW) / 2)
    L.caseY = L.devY + L.strapH + L.topH
    L.lcdX, L.lcdY = L.caseX + inset, L.caseY + inset
    L.h = L.devY + devH + pad
    local x0 = L.lcdX + math.floor((L.lcdW - dw) / 2)
    L.digitY = L.lcdY + math.floor((L.lcdH - dh) / 2)
    L.cells = {x0, x0 + cellW, x0 + cellW * 2 + colonW, x0 + cellW * 3 + colonW}
    L.colonX = x0 + cellW * 2
    L.hours = {x0, L.digitY, cellW * 2, dh}
    L.mins = {x0 + cellW * 2 + colonW, L.digitY, cellW * 2, dh}
    self.L = L
    self:setWidth(L.w)
    self:setHeight(L.h)
end

function KnoxAlarmWindow:rects()
    local L, pad = self.L, T.pad
    local R = {}
    local s = L.headerH - 8
    R.x = {L.w - s - 4, 4, s, s}
    -- the arrows: drawn small, taken by the mouse over the whole group's width
    local a = L.arrow
    local gap = math.max(3, math.floor(T.cell * 0.1))
    local function arrows(g)
        return {g[1], g[2] - a - gap, g[3], a}, {g[1], g[2] + g[4] + gap, g[3], a}
    end
    R.hUp, R.hDown = arrows(L.hours)
    R.mUp, R.mDown = arrows(L.mins)
    -- the alarm's button: out of the case's left side, or out of its top
    if self.wrist then
        R.key = {L.caseX - L.keyOut, L.caseY + math.floor(L.caseH * 0.25), L.keyOut, L.keyLong}
    else
        R.key = {L.caseX + math.floor((L.caseW - L.keyLong * 2) / 2), L.caseY - L.keyOut, L.keyLong * 2, L.keyOut}
    end
    -- "AL" on the display does the same
    R.al = {L.lcdX, L.lcdY + L.lcdH - T.fontH(L.small) - 6, T.measure(L.small, "AL") + 10, T.fontH(L.small) + 6}
    return R
end

--- Closes as the game's dialog: the thing gone, or the character walked off.
function KnoxAlarmWindow:validate()
    local a = self.alarm
    if not a or (not a:getWorldItem() and not a:getContainer()) or self.player:isDead() then
        self:close()
        return false
    end
    if math.abs(self.player:getX() - self.px) > 0.1 or math.abs(self.player:getY() - self.py) > 0.1 then
        self:close()
        return false
    end
    return true
end

--- A small triangle pointing up (dir 1) or down (-1), `r[4]` rows tall, in the
--- middle of r; lit on hover.
local function tri(ui, r, dir, hot)
    local c = hot and AMBER or LCD_EDGE
    local n = r[4]
    local cx = r[1] + math.floor(r[3] / 2)
    for i = 0, n - 1 do
        local y = dir > 0 and (r[2] + i) or (r[2] + n - 1 - i)
        ui:drawRect(cx - i, y, i * 2 + 1, 1, 1, c.r, c.g, c.b)
    end
end

function KnoxAlarmWindow:prerender()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    if not self:validate() then return end
    local L, pad = self.L, T.pad
    local w, h = self:getWidth(), self:getHeight()
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local R = self:rects()

    -- a thread from the thing's tile (with the Knox screen open), as the other windows
    if KnoxScreen and KnoxScreen.instance and KnoxThread then
        local sx, sy, sw, sh = KnoxThread.sourceRect(self.alarm)
        if sx then KnoxThread.draw(self, sx, sy, sw, sh, L.headerH, true) end
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
    -- ("Set alarm", as the menu's option - the game's dialog said "Set alarm to")
    -- (up and down by the letters' own pixels: by the font's box "Й" and "Д" set it off the bar's middle)
    T.inkLeft(self, T.fit(T.upper(getText("ContextMenu_SetAlarm")), T.fontCaps, R.x[1] - pad * 2), pad, 0, L.headerH,
        T.color.bright, T.fontCaps)
    T.closeButton(self, R.x[1], R.x[2], R.x[3], over and inRect(mx, my, R.x))

    -- the thing: a wristwatch on its strap, or a desk clock on its feet
    local cx = L.caseX + math.floor(L.caseW / 2)
    if self.wrist then
        local sx = cx - math.floor(L.strapW / 2)
        local top, bottom = L.devY, L.caseY + L.caseH
        T.rect(self, sx, top, L.strapW, L.strapH + 4, STRAP)
        T.border(self, sx, top, L.strapW, L.strapH + 4, STRAP_EDGE)
        T.rect(self, sx, bottom - 4, L.strapW, L.strapH + 4, STRAP)
        T.border(self, sx, bottom - 4, L.strapW, L.strapH + 4, STRAP_EDGE)
        -- the strap's holes
        local d = math.max(3, math.floor(T.cell * 0.09))
        for i = 1, 3 do
            local hy = bottom + math.floor(L.strapH * i / 4) - math.floor(d / 2)
            self:drawRect(cx - math.floor(d / 2), hy, d, d, 1, LCD.r, LCD.g, LCD.b)
        end
        -- the crown on the right
        T.rect(self, L.caseX + L.caseW, L.caseY + math.floor(L.caseH / 2) - 5, 5, 10, CASE_EDGE)
    else
        -- two feet under (the alarm's key on top: below)
        local fw = math.floor(L.caseW * 0.16)
        local fy = L.caseY + L.caseH - 2
        T.rect(self, L.caseX + fw, fy, fw, L.feetH + 2, CASE_EDGE)
        T.rect(self, L.caseX + L.caseW - fw * 2, fy, fw, L.feetH + 2, CASE_EDGE)
    end
    -- the alarm's key: out of the case while off, pushed in (and its edge lit
    -- amber) while on; lighter under the mouse
    do
        local k = R.key
        local hot = over and inRect(mx, my, {k[1] - 4, k[2] - 4, k[3] + 8, k[4] + 8})
        local x, y, kw, kh = k[1], k[2], k[3], k[4]
        if self.on then
            -- (in: half as far out)
            if self.wrist then x, kw = x + math.floor(kw / 2), kw - math.floor(kw / 2)
            else y, kh = y + math.floor(kh / 2), kh - math.floor(kh / 2) end
        end
        T.rect(self, x, y, kw + (self.wrist and 2 or 0), kh + (self.wrist and 0 or 2), hot and CASE_EDGE or STRAP_EDGE)
        if self.on then
            if self.wrist then T.rect(self, x, y, 1, kh, AMBER) else T.rect(self, x, y, kw, 1, AMBER) end
        end
    end
    T.rect(self, L.caseX, L.caseY, L.caseW, L.caseH, CASE)
    T.border(self, L.caseX, L.caseY, L.caseW, L.caseH, CASE_EDGE)
    T.border(self, L.caseX + 1, L.caseY + 1, L.caseW - 2, L.caseH - 2, CASE_EDGE, 0.5)

    -- the display
    T.rect(self, L.lcdX, L.lcdY, L.lcdW, L.lcdH, LCD)
    T.border(self, L.lcdX, L.lcdY, L.lcdW, L.lcdH, LCD_EDGE)
    local f = L.digits
    local digits = string.format("%02d%02d", self.hour, self.minute)
    local lit = self.on and 1 or 0.55
    local dh = L.hours[4]
    -- each digit centred in its cell by its own pixels, an unlit 8 under it
    for i = 1, 4 do
        local x = L.cells[i]
        T.inkCentre(self, "8", x, L.digitY, L.cellW, dh, AMBER.r, AMBER.g, AMBER.b, 0.07, f)
        T.inkCentre(self, string.sub(digits, i, i), x, L.digitY, L.cellW, dh, AMBER.r, AMBER.g, AMBER.b, lit, f)
    end
    -- the colon in the middle of its own cell; it blinks once a second
    local blink = math.floor(getTimestampMs() / 500) % 2 == 0
    T.inkCentre(self, ":", L.colonX, L.digitY, L.colonW, dh, AMBER.r, AMBER.g, AMBER.b, blink and lit or 0.15, f)
    -- "AL" in the corner while the alarm is on (a click on it switches it too)
    local alHot = over and inRect(mx, my, R.al)
    T.text(self, "AL", R.al[1] + 5, R.al[2] + 3, AMBER, L.small, self.on and 1 or (alHot and 0.35 or 0.12))
    for _, k in ipairs({{R.hUp, 1}, {R.hDown, -1}, {R.mUp, 1}, {R.mDown, -1}}) do
        local r = k[1]
        local hot = over and inRect(mx, my, {r[1], r[2] - 4, r[3], r[4] + 8})
        tri(self, r, k[2], hot)
    end
end

-- Input ---------------------------------------------------------------------------------

function KnoxAlarmWindow:step(what, dir)
    if what == "h" then
        self.hour = T.mod(self.hour + dir, 24)
    else
        self.minute = T.mod(self.minute + dir * MIN_STEP, 60)
    end
    getSoundManager():playUISound("UIActivateButton")
end

function KnoxAlarmWindow:onMouseDown(x, y)
    if self.foldMs then return true end
    self:bringToTop()
    local R = self:rects()
    if inRect(x, y, R.x) then self:apply() return true end   -- (closing sets it)
    local k = R.key
    if inRect(x, y, {k[1] - 4, k[2] - 4, k[3] + 8, k[4] + 8}) or inRect(x, y, R.al) then
        self.on = not self.on
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    -- (the arrows taken a little above and below what is drawn: they are small)
    local function hit(r) return inRect(x, y, {r[1], r[2] - 4, r[3], r[4] + 8}) end
    if hit(R.hUp) then self:step("h", 1) return true end
    if hit(R.hDown) then self:step("h", -1) return true end
    if hit(R.mUp) then self:step("m", 1) return true end
    if hit(R.mDown) then self:step("m", -1) return true end
    KnoxWindowDrag.begin(self, x, y, self.L.headerH)
    return true
end

KnoxWindowDrag.install(KnoxAlarmWindow)

--- The wheel over the hours or the minutes turns them.
function KnoxAlarmWindow:onMouseWheel(del)
    local L = self.L
    local mx, my = self:getMouseX(), self:getMouseY()
    local function near(g) return inRect(mx, my, {g[1] - L.arrow * 2, g[2] - L.arrow * 3, g[3] + L.arrow * 4, g[4] + L.arrow * 6}) end
    if near(L.hours) then self:step("h", del < 0 and 1 or -1)
    elseif near(L.mins) then self:step("m", del < 0 and 1 or -1) end
    return true
end

function KnoxAlarmWindow:onRightMouseUp(x, y) return true end

function KnoxAlarmWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE or key == Keyboard.KEY_RETURN
end

function KnoxAlarmWindow:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE or key == Keyboard.KEY_RETURN then self:apply() end
end

--- Set it as the game's dialog does, and close.
function KnoxAlarmWindow:apply()
    local a = self.alarm
    a:setAlarmSet(self.on)
    a:setHour(self.hour)
    a:setMinute(self.minute)
    a:syncAlarmClock()
    getSoundManager():playUISound("UIActivateButton")
    self:close()
end

function KnoxAlarmWindow:close()
    A.lastX, A.lastY = self:getX(), self:getY()
    T.fold(self, function(w)
        w:setVisible(false)
        w:removeFromUIManager()
    end)
    if A.instance == self then A.instance = nil end
end

--- Is this item's alarm window open? (its tile gets the sand frame)
function A.isOpen(item)
    return A.instance ~= nil and item ~= nil and A.instance.alarm == item
end

function A.open(player, alarm)
    if A.instance then A.instance:close() end
    local w = A:new(player, alarm)
    w:initialise()
    w:instantiate()
    w:setWantKeyEvents(true)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = A.lastX or math.floor((sw - w:getWidth()) / 2)
    local y = A.lastY or math.floor((sh - w:getHeight()) / 2)
    w:setX(math.max(0, math.min(sw - w:getWidth(), x)))
    w:setY(math.max(0, math.min(sh - w:getHeight(), y)))
    w:addToUIManager()
    A.instance = w
    return w
end

-- The game opens its dialog from ISInventoryPaneContextMenu.onSetAlarm (an item's
-- menu, and a clock lying in the world): the same steps, then this window.
local P = ISInventoryPaneContextMenu
if P and P.onSetAlarm and not P.knoxAlarmHooked then
    P.knoxAlarmHooked = true
    local original = P.onSetAlarm
    P.onSetAlarm = function(alarm, player)
        if not (T.on("devices") and Knox and Knox.forPlayer and Knox.forPlayer(player, "devices")) then
            return original(alarm, player)
        end
        local playerObj = getSpecificPlayer(player)
        -- (carried off somewhere: into the main inventory first, as the game does)
        if not alarm:getWorldItem() and (alarm:getContainer() ~= playerObj:getInventory()) then
            local action = ISInventoryTransferUtil.newInventoryTransferAction(playerObj, alarm, alarm:getContainer(), playerObj:getInventory())
            action:setOnComplete(P.onSetAlarm, alarm, player)
            ISTimedActionQueue.add(action)
            return
        end
        A.open(playerObj, alarm)
    end
end

return KnoxAlarmWindow
