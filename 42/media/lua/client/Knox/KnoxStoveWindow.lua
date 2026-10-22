-- Knox's own window for a stove's and a microwave's settings, in place of the
-- game's (two dials and two buttons): temperature and timer as stepped
-- sliders with the same stops as the game's dials, a switch, what it is doing
-- now. Opened by the game's own action (ISOvenUITimedAction: the context menu's
-- "Settings", the header button of the Knox screen), so walking up to the stove
-- stays the game's.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"

KnoxStoveWindow = ISPanel:derive("KnoxStoveWindow")
local W = KnoxStoveWindow
local T = KnoxTheme
local inRect = T.inRect

local DEG = string.char(176)   -- the degree sign (the game reads Lua files as single bytes)
-- the stops of the game's dials: temperature as the game counts it (Fahrenheit), timer in minutes
local TEMPS = {stove = {0, 50, 100, 150, 200, 250, 300}, microwave = {50, 70, 90, 110, 130}}
local TIMES = {stove = {0, 1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 60, 90, 120},
               microwave = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 45, 60}}

function W:new(character, oven, microwave)
    local c = T.cell
    local o = ISPanel:new(0, 0, c * 8, c * 5)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.playerNum = character:getPlayerNum()
    o.oven = oven
    o.kind = microwave and "microwave" or "stove"
    o.background = false
    o.moveWithMouse = false
    return o
end

local function nearest(list, value)
    local best, bestD = 1, nil
    for i, v in ipairs(list) do
        local d = math.abs(v - value)
        if not bestD or d < bestD then best, bestD = i, d end
    end
    return best
end

function W:layout()
    local pad, c = T.pad, T.cell
    local ft, fc = T.fontH(T.fontText), T.fontH(T.fontCaps)
    local R = {}
    R.headerH = T.sectionH + 6
    local w = self:getWidth()
    local s = R.headerH - 10
    R.x = {w - s - 6, 5, s, s}
    local y = R.headerH + pad
    local trackH = math.max(14, math.floor(c * 0.36))
    R.tempLabelY = y
    y = y + fc + 6
    R.temp = {pad * 2, y, w - pad * 4, trackH}
    y = y + trackH + pad + 4
    R.timeLabelY = y
    y = y + fc + 6
    R.time = {pad * 2, y, w - pad * 4, trackH}
    y = y + trackH + pad + 6
    local bh = fc + 12
    local bw = math.max(T.buttonW(getText("ContextMenu_Turn_On")), T.buttonW(getText("ContextMenu_Turn_Off"))) + 16
    R.power = {pad * 2, y, bw, bh}
    R.statusX, R.statusY = pad * 2 + bw + pad, y + math.floor((bh - ft) / 2)
    y = y + bh + pad + 2
    self:setHeight(y)
    self.R = R
end

function W:createChildren()
    self:layout()
end

function W:powered()
    local c = self.oven:getContainer()
    return c ~= nil and c:isPowered()
end

--- Minutes left on the timer (as set, while it isn't running).
function W:minutes()
    local t, run = self.oven:getTimer() or 0, self.oven:isRunningFor() or 0
    if run > 0 then return math.max(0, math.ceil((t - run) / 60)) end
    return t / 60
end

function W:tempIndex() return nearest(TEMPS[self.kind], self.oven:getMaxTemperature() or 0) end
function W:timeIndex() return nearest(TIMES[self.kind], self:minutes()) end

function W:tempText(v)
    if getCore():isCelsius() then
        if v <= 0 then return "0" .. DEG .. "C" end
        return tostring(math.floor((v - 32) / 1.8 / 5 + 0.5) * 5) .. DEG .. "C"
    end
    return tostring(v) .. DEG .. "F"
end

--- Write the sliders' stops into the stove; `done`: tell the game it is settled.
function W:apply(tempI, timeI, done)
    local oven = self.oven
    if tempI then oven:setMaxTemperature(TEMPS[self.kind][tempI]) end
    if timeI then oven:setTimer(TIMES[self.kind][timeI] * 60) end
    if done then oven:sync() end
    if oven.syncSpriteGridObjects then oven:syncSpriteGridObjects(false, done == true) end
end

function W:toggle()
    if not self:powered() then return end
    local oven = self.oven
    if self.kind == "stove" then self.character:playSound("ToggleStove") end   -- (the game's microwave switch is silent)
    sendClientCommand(self.character, "stove", "setOvenParamsAndToggle",
        {x = oven:getX(), y = oven:getY(), z = oven:getZ(), timer = oven:getTimer(), maxTemperature = oven:getMaxTemperature()})
end

-- Drawing ----------------------------------------------------------------------------

--- A stepped slider: a track with a tick at every stop, sand up to the knob.
local function drawSlider(ui, r, n, index, hot)
    local x, y, w, h = r[1], r[2], r[3], r[4]
    local mid = y + math.floor(h / 2)
    T.rect(ui, x, mid - 2, w, 4, T.color.line)
    local kx = x + math.floor((w - 1) * (index - 1) / math.max(1, n - 1))
    T.rect(ui, x, mid - 2, kx - x, 4, T.color.accent)
    for i = 1, n do
        local tx = x + math.floor((w - 1) * (i - 1) / math.max(1, n - 1))
        T.rect(ui, tx, mid - 5, 1, 10, i <= index and T.color.accent or T.color.tileEdge)
    end
    local kw = math.max(8, math.floor(h * 0.5))
    T.rect(ui, kx - math.floor(kw / 2), y, kw, h, hot and T.color.bright or T.color.accent)
end

function W:prerender()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    local oven, chr = self.oven, self.character
    -- walked away, the stove is gone, or the character is dead (as the TV's and the radio's windows)
    if not oven or not oven:getSquare() or chr:isDead() or chr:DistTo(oven:getX(), oven:getY()) > 3 then
        self:close()
        return
    end
    local R = self.R
    local w, h = self:getWidth(), self:getHeight()
    local pad = T.pad
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()

    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, R.headerH, T.color.header)
    T.tileFrame(self, 0, 0, w, h, T.color.accent)
    T.text(self, T.upper(getText(self.kind == "microwave" and "IGUI_Knox_Microwave" or "IGUI_Knox_Stove")),
        pad, math.floor((R.headerH - T.fontH(T.fontCaps)) / 2), T.color.text, T.fontCaps)
    T.closeButton(self, R.x[1], R.x[2], R.x[3], over and inRect(mx, my, R.x))

    local temps, times = TEMPS[self.kind], TIMES[self.kind]
    local ti, mi = self:tempIndex(), self:timeIndex()
    T.text(self, T.upper(getText("IGUI_Temperature")), pad * 2, R.tempLabelY, T.color.dim, T.fontCaps)
    T.textRight(self, self:tempText(temps[ti]), w - pad * 2, R.tempLabelY, T.color.accent, T.fontCaps)
    drawSlider(self, R.temp, #temps, ti, self.sliding == "temp" or (over and inRect(mx, my, R.temp)))

    T.text(self, T.upper(getText("IGUI_Timer")), pad * 2, R.timeLabelY, T.color.dim, T.fontCaps)
    local minutes = self:minutes()
    local running = (oven:isRunningFor() or 0) > 0
    local timeText = (minutes <= 0) and getText("IGUI_Knox_Stove_NoTimer")
        or (tostring(running and minutes or times[mi]) .. " " .. getText("IGUI_Knox_Minutes"))
    T.textRight(self, timeText, w - pad * 2, R.timeLabelY, T.color.accent, T.fontCaps)
    drawSlider(self, R.time, #times, mi, self.sliding == "time" or (over and inRect(mx, my, R.time)))

    local on, powered = oven:Activated(), self:powered()
    T.button(self, R.power, getText(on and "ContextMenu_Turn_Off" or "ContextMenu_Turn_On"),
        {primary = on, hover = over and inRect(mx, my, R.power), disabled = not powered})
    local status, color
    if not powered then
        status, color = getText("IGUI_Knox_Stove_NoPower"), T.color.bad
    elseif on then
        status, color = getText("IGUI_Knox_Stove_On"), T.color.good
    else
        status, color = getText("IGUI_Knox_Stove_Off"), T.color.dim
    end
    T.text(self, T.fit(status, T.fontText, w - R.statusX - pad), R.statusX, R.statusY, color, T.fontText)
end

-- Input --------------------------------------------------------------------------------

local function stopAt(r, n, x)
    local f = (x - r[1]) / math.max(1, r[3] - 1)
    return math.max(1, math.min(n, math.floor(f * (n - 1) + 0.5) + 1))
end

function W:slide()
    local x = self:getMouseX()
    if self.sliding == "temp" then
        self:apply(stopAt(self.R.temp, #TEMPS[self.kind], x), nil, false)
    elseif self.sliding == "time" then
        self:apply(nil, stopAt(self.R.time, #TIMES[self.kind], x), false)
    end
end

function W:onMouseDown(x, y)
    if self.foldMs then return true end   -- folding away: no longer there to click
    self:bringToTop()
    local R = self.R
    if inRect(x, y, R.x) then self:close() return true end
    if inRect(x, y, R.power) then self:toggle() return true end
    -- (a little above and below the track counts too)
    for _, id in ipairs({"temp", "time"}) do
        local r = R[id]
        if inRect(x, y, {r[1] - 6, r[2] - 6, r[3] + 12, r[4] + 12}) then
            self.sliding = id
            self:slide()
            return true
        end
    end
    KnoxWindowDrag.begin(self, x, y, R.headerH)
    return true
end

KnoxWindowDrag.install(W)

local dragMove, dragStop = W.onMouseMove, W.onMouseUp

local function moved(self)
    if self.sliding then
        if isMouseButtonDown(0) then self:slide() else self:release() end
        return true
    end
    return dragMove(self, 0, 0)
end

function W:release()
    if self.sliding then
        self.sliding = nil
        self:apply(nil, nil, true)
        self.character:playSound("ToggleTemp")
    end
end

function W:onMouseMove(dx, dy) return moved(self) end
function W:onMouseMoveOutside(dx, dy) return moved(self) end

function W:onMouseUp(x, y)
    self:release()
    return dragStop(self, x, y)
end

function W:onMouseUpOutside(x, y)
    self:release()
    return dragStop(self, x, y)
end

function W:onMouseWheel(del)
    local R = self.R
    local x, y = self:getMouseX(), self:getMouseY()
    local dir = del > 0 and -1 or 1
    if y >= R.timeLabelY and y < R.power[2] then
        self:apply(nil, math.max(1, math.min(#TIMES[self.kind], self:timeIndex() + dir)), true)
    elseif y >= R.tempLabelY and y < R.timeLabelY then
        self:apply(math.max(1, math.min(#TEMPS[self.kind], self:tempIndex() + dir)), nil, true)
    end
    return true
end

function W:onRightMouseUp(x, y) return true end

function W:isKeyConsumed(key) return key == Keyboard.KEY_ESCAPE end

function W:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end

function W:close()
    W.lastX, W.lastY = self:getX(), self:getY()
    T.fold(self, function(w)
        w:setVisible(false)
        w:removeFromUIManager()
    end)
    if W.instance == self then W.instance = nil end
end

--- Open in place of the game's window.
function W.open(character, oven, microwave)
    if W.instance then
        if W.instance.oven == oven then W.instance:bringToTop() return W.instance end
        W.instance:close()
    end
    T.ensure()
    local w = W:new(character, oven, microwave)
    w:initialise()
    w:instantiate()
    w:setWantKeyEvents(true)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = W.lastX or math.floor((sw - w:getWidth()) / 2)
    local y = W.lastY or math.floor((sh - w:getHeight()) / 2)
    w:setX(math.max(0, math.min(sw - w:getWidth(), x)))
    w:setY(math.max(0, math.min(sh - w:getHeight(), y)))
    w:addToUIManager()
    w:setAlwaysOnTop(true)   -- over the Knox screen, which comes to the top on a click
    W.instance = w
    return w
end

-- The game's action opens its own window when the character has walked up:
-- ours instead, while the stove module is on (for the mouse player, as the
-- other Knox windows: Knox.forPlayer).
local function hook()
    if not ISOvenUITimedAction or W.hooked then return end
    W.hooked = true
    local perform = ISOvenUITimedAction.perform
    function ISOvenUITimedAction:perform()
        local p = self.character
        if not (Knox and Knox.forPlayer and p and Knox.forPlayer(p:getPlayerNum(), "stove")) then return perform(self) end
        ISBaseTimedAction.perform(self)
        W.open(self.character, self.mcwave or self.stove, self.mcwave ~= nil)
    end
end

Events.OnGameStart.Add(hook)

return KnoxStoveWindow
