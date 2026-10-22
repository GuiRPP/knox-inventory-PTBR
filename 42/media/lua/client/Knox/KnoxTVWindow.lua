-- A television in Knox's look: the window is the set itself. A screen with
-- what is said on it as subtitles, the channel, the time and the volume in a
-- green on-screen display, the skills a show teaches popping up as it does;
-- on the right of the cabinet the power button, the channel knob and buttons,
-- the volume knob; under the screen the video deck (a slot for a tape, play,
-- eject) when the set takes tapes.
-- It takes the place of the game's radio/TV window for televisions
-- (ISRadioWindow.activate); the game's actions do the work (ISRadioAction,
-- ISDeviceMediaAction). The lines come from the Java part (knoxDeviceText):
-- the game shows them only over the set in the world, and while the window
-- is open it doesn't (knoxHideDeviceText).

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxSlotPicker"

KnoxTVWindow = ISPanel:derive("KnoxTVWindow")
local W = KnoxTVWindow
local T = KnoxTheme

W.instance = nil
W.lastX, W.lastY = nil, nil

local inRect = T.inRect

local OSD = {r = 0.62, g = 0.88, b = 0.54}             -- the set's green on-screen text
local CABINET = {r = 0x2a / 255, g = 0x26 / 255, b = 0x22 / 255}
local CABINET_EDGE = {r = 0x3e / 255, g = 0x39 / 255, b = 0x33 / 255}
local GLASS = {r = 0.035, g = 0.045, b = 0.045}
local GLASS_ON = {r = 0.05, g = 0.075, b = 0.08}
local KNOB = {r = 0x24 / 255, g = 0x28 / 255, b = 0x28 / 255}
local LED_ON = {r = 0.45, g = 0.85, b = 0.35}
local LED_OFF = {r = 0.45, g = 0.12, b = 0.1}

local WALK_DIST = 10        -- as the game's window: it closes farther away
local VOLUME_STEPS = 10
-- quiet this long on a channel: "no signal" (the game waits about a second per
-- 10 letters between lines, up to several seconds, so after a line its own
-- time comes first)
local NO_SIGNAL_MS = 12000

-- Helpers --------------------------------------------------------------------------

--- A filled circle (rows of rects).
local function disc(ui, cx, cy, r, c, a)
    for dy = -r, r do
        local half = math.floor(math.sqrt(r * r - dy * dy) + 0.5)
        ui:drawRect(cx - half, cy + dy, half * 2 + 1, 1, a or 1, c.r, c.g, c.b)
    end
end

--- A knob: rim, face, a notch at `angle` (radians, 0 = up).
local function knob(ui, cx, cy, r, angle, hot)
    disc(ui, cx, cy, r, hot and T.color.accent or T.color.tileEdge)
    disc(ui, cx, cy, r - 2, KNOB)
    disc(ui, cx, cy - 1, r - 6, {r = KNOB.r + 0.03, g = KNOB.g + 0.03, b = KNOB.b + 0.03})
    local c = hot and T.color.accent or T.color.text
    local sx, sy = math.sin(angle), -math.cos(angle)
    for t = math.floor(r * 0.25), r - 5, 2 do
        ui:drawRect(math.floor(cx + sx * t) - 1, math.floor(cy + sy * t) - 1, 3, 3, 1, c.r, c.g, c.b)
    end
end

--- Rounded corners of the screen: the cabinet's color over them in steps.
local function roundCorners(ui, x, y, w, h, rr, c)
    for i = 0, rr - 1 do
        local d = rr - i
        local cut = rr - math.floor(math.sqrt(rr * rr - d * d) + 0.5)
        if cut > 0 then
            ui:drawRect(x, y + i, cut, 1, 1, c.r, c.g, c.b)
            ui:drawRect(x + w - cut, y + i, cut, 1, 1, c.r, c.g, c.b)
            ui:drawRect(x, y + h - 1 - i, cut, 1, 1, c.r, c.g, c.b)
            ui:drawRect(x + w - cut, y + h - 1 - i, cut, 1, 1, c.r, c.g, c.b)
        end
    end
end

--- A small triangle pointing up or down (the stat arrows), or right (play).
local function triangle(ui, x, y, s, dir, c)
    for i = 0, s - 1 do
        local len = s * 2 - 1 - i * 2
        if dir == "right" then
            ui:drawRect(x + i, y + i, 1, len, 1, c.r, c.g, c.b)
        elseif dir == "up" then
            ui:drawRect(x + i, y + s - 1 - i, len, 1, 1, c.r, c.g, c.b)
        else
            ui:drawRect(x + i, y + i, len, 1, 1, c.r, c.g, c.b)
        end
    end
end

--- The time of day as the game's clock shows it (minutes in tens, 12 or 24 hours).
local function clockText(tod)
    if not getCore():getOptionClock24Hour() then
        if tod >= 13 then tod = tod - 12 end
        if tod < 1 then tod = tod + 12 end
    end
    local hours = math.floor(tod)
    local mins = math.floor((tod - hours) * 60 / 10) * 10
    return string.format("%02d:%02d", hours, mins)
end

-- shared with the radio window
W.disc, W.knob, W.triangle, W.clockText = disc, knob, triangle, clockText

local function osdFont()
    if T.javaFonts then return T.makeFont("head", T.cell * 0.4) end
    return UIFont.Medium
end

local function subFont()
    if T.javaFonts then return T.makeFont("body", T.cell * 0.34) end
    return UIFont.Medium
end

--- Carried tapes that this set plays (pockets, bags, hands).
local function carriedMedia(player, mediaType)
    local out = {}
    local function walk(c, depth)
        local items = c:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            -- (not what a bag not searched yet still hides: KnoxSearch)
            if it:isRecordedMedia() and it:getMediaType() == mediaType and not (KnoxSearch and KnoxSearch.unseen(it)) then
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

local tapeTex
local function tapeTexture()
    if tapeTex == nil then
        local ok, tex = pcall(function()
            local si = getScriptManager():FindItem("Base.VHS_Retail")
            return si and si:getNormalTexture()
        end)
        tapeTex = (ok and tex) or getTexture("Item_Cassette3") or false
    end
    return tapeTex or nil
end

-- The tape slot as the quick pick panel sees it: where it is on screen.
local SlotRef = {}
SlotRef.__index = SlotRef
function SlotRef:rect() return self.win.R.slot end
function SlotRef:getAbsoluteX() return self.win:getAbsoluteX() + self:rect()[1] end
function SlotRef:getAbsoluteY() return self.win:getAbsoluteY() + self:rect()[2] end
function SlotRef:getWidth() return self:rect()[3] end
function SlotRef:getHeight() return self:rect()[4] end

-- Window ------------------------------------------------------------------------------

function KnoxTVWindow:new(player, device)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.device = device
    o.data = device:getDeviceData()
    o.subs = {}          -- the set's lines: {text, color, t}
    o.lastSeq = 0
    o.badges = {}        -- skills and moods the show changed: {text, color, dir, t}
    o.osdVolumeMs = 0
    o.zapMs = 0
    o.lastLineMs = getTimestampMs()
    o.background = false
    o.moveWithMouse = false
    o.slotRef = setmetatable({win = o}, SlotRef)
    return o
end

function KnoxTVWindow:hasDeck()
    return self.data and self.data:getMediaType() == 1
end

function KnoxTVWindow:createChildren()
    self:layout()
end

function KnoxTVWindow:layout()
    local c, pad = T.cell, T.pad
    local R = {}
    R.headerH = T.sectionH + 4
    local bezel = math.floor(c * 0.3)
    local scrW = math.floor(c * 7)
    local scrH = math.floor(scrW * 0.72)
    local ctrlW = math.floor(c * 2.3)
    local btnH = math.floor(c * 0.62 + 0.5)
    local deckH = self:hasDeck() and math.floor(c * 1.15) or math.floor(c * 0.45)
    R.cab = {pad, R.headerH + pad, bezel * 3 + scrW + ctrlW, bezel * 3 + scrH + deckH}
    R.screen = {R.cab[1] + bezel, R.cab[2] + bezel, scrW, scrH}
    R.deck = {R.screen[1], R.screen[2] + scrH + bezel, scrW, deckH}
    R.panel = {R.screen[1] + scrW + bezel, R.screen[2], ctrlW, scrH + bezel + deckH}

    -- the panel, top to bottom: power, channel knob, channel buttons, volume knob
    local px, pw = R.panel[1], R.panel[3]
    local y = R.panel[2]
    R.power = {px, y, pw, btnH}
    y = y + btnH + pad
    local capH = T.fontH(T.fontCaps)
    R.chanCapY = y
    y = y + capH + 4
    R.knobR = math.floor(c * 0.6)
    R.chanKnob = {px + math.floor(pw / 2), y + R.knobR, R.knobR}
    y = y + R.knobR * 2 + pad
    local cols, gap = 3, 4
    local bs = math.floor((pw - gap * (cols - 1)) / cols)
    R.chanBtns = {}
    local presets = self:presets()
    local shown = math.min(#presets, 9)
    for i = 1, shown do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        table.insert(R.chanBtns, {px + col * (bs + gap), y + row * (math.floor(bs * 0.75) + gap), bs, math.floor(bs * 0.75), i})
    end
    local rows = math.max(1, math.ceil(shown / cols))
    y = y + rows * (math.floor(bs * 0.75) + gap) + pad
    R.volCapY = y
    y = y + capH + 4
    R.volKnob = {px + math.floor(pw / 2), y + R.knobR, R.knobR}
    y = y + R.knobR * 2 + 4
    R.volTextY = y
    local panelBottom = y + T.fontH(T.fontText)
    -- a long channel list makes the cabinet taller
    local extra = math.max(0, panelBottom - (R.panel[2] + R.panel[4]))
    if extra > 0 then
        R.cab[4] = R.cab[4] + extra
        R.panel[4] = R.panel[4] + extra
        R.deck[2] = R.deck[2] + extra
        R.screen[4] = R.screen[4] + extra
    end

    -- the deck: the tape slot, its title, play and eject
    local d = R.deck
    if self:hasDeck() then
        local sh = d[4] - pad * 2
        R.slot = {d[1] + pad, d[2] + pad, math.floor(sh * 1.9), sh}
        -- play / stop and eject: square buttons with their marks (the title needs the room)
        local bs = btnH
        local by = d[2] + math.floor((d[4] - bs) / 2)
        R.eject = {d[1] + d[3] - pad - bs, by, bs, bs}
        R.play = {R.eject[1] - 4 - bs, by, bs, bs}
        R.titleX = R.slot[1] + R.slot[3] + pad
        R.titleW = R.play[1] - pad - R.titleX
    end
    local s = R.headerH - 8
    R.x = {0, 4, s, s}
    self.R = R
    local w = R.cab[1] * 2 + R.cab[3]
    R.x[1] = w - s - 4
    self:setWidth(w)
    self:setHeight(R.cab[2] + R.cab[4] + pad)
end

-- State ------------------------------------------------------------------------------

--- The set's channels: {freq, name}.
--- (asked three to five times a frame: kept a moment while their number stays)
function KnoxTVWindow:presets()
    local dp = self.data and self.data:getDevicePresets()
    local list = dp and dp:getPresets()
    local n, now = list and list:size() or -1, getTimestampMs()
    local pc = self.presetsOf
    if pc and pc.data == self.data and pc.n == n and now - pc.ms < 250 then return pc.list end
    local out = {}
    self.presetsOf = {data = self.data, n = n, ms = now, list = out}
    if list then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            table.insert(out, {freq = p:getFrequency(), name = p:getName()})
        end
    end
    return out
end

function KnoxTVWindow:channelIndex()
    local ch = self.data:getChannel()
    for i, p in ipairs(self:presets()) do
        if p.freq == ch then return i, p end
    end
    return nil, nil
end

function KnoxTVWindow:isOn()
    return self.data ~= nil and self.data:getIsTurnedOn()
end

--- The volume to show: what was asked for until the set has it (the character
--- walks over and turns the knob first), else the set's.
function KnoxTVWindow:volume()
    if self.pendingVol then return self.pendingVol end
    local dev = self.data:getDeviceVolume()
    if self.askedVol then
        if math.abs(dev - self.askedVol) < 0.01 or getTimestampMs() - self.askedVolMs > 8000 then
            self.askedVol = nil
        else
            return self.askedVol
        end
    end
    return dev
end

--- Is the set still there, and the character near it? (as the game's window)
function KnoxTVWindow:validate()
    local d = self.device
    local sq = d and d:getSquare()
    if not sq or d:getObjectIndex() < 0 or not d:getDeviceData() then self:close() return false end
    local p = self.player
    if p:isDead() or math.abs(p:getX() - d:getX()) > WALK_DIST or math.abs(p:getY() - d:getY()) > WALK_DIST then
        self:close()
        return false
    end
    self.data = d:getDeviceData()
    return true
end

--- New lines from the Java part.
function KnoxTVWindow:pollLines()
    local now = getTimestampMs()
    local s = knoxDeviceText and knoxDeviceText(self.device, self.lastSeq) or ""
    if s ~= "" then
        for line in string.gmatch(s, "[^\n]+") do
            local seq, age, r, g, b, text = string.match(line, "^(%d+)\t(%d+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t[^\t]*\t[^\t]*\t(.*)$")
            if seq then
                self.lastSeq = math.max(self.lastSeq, tonumber(seq))
                local t = now - tonumber(age)
                -- the game's markup ("[img=music]", "[col=...]"...): not words to show
                text = string.gsub(text, "%[[^%]]*%]", "")
                text = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
                table.insert(self.subs, {text = text, t = t,
                    color = {r = tonumber(r) or 1, g = tonumber(g) or 1, b = tonumber(b) or 1}})
                if t > self.lastLineMs then
                    self.lastLineMs = t
                    self.lastLineLen = string.len(text)
                end
            end
        end
        while #self.subs > 6 do table.remove(self.subs, 1) end
    end
end

--- Volume set with the wheel goes to the set once the wheel rests.
function KnoxTVWindow:flushVolume()
    if self.pendingVol and getTimestampMs() - self.pendingVolMs > 350 then
        local v = self.pendingVol
        self.pendingVol = nil
        if math.abs(v - self.data:getDeviceVolume()) > 0.001 then
            -- one action for the new value: the ones still waiting in the queue go
            local q = ISTimedActionQueue.getTimedActionQueue(self.player)
            if q and q.queue then
                for i = #q.queue, 2, -1 do
                    local a = q.queue[i]
                    if a and a.Type == "ISRadioAction" and a.mode == "SetVolume" and a.device == self.device then
                        table.remove(q.queue, i)
                    end
                end
            end
            self.askedVol, self.askedVolMs = v, getTimestampMs()
            self:act("SetVolume", v)
        end
    end
end

-- Actions ----------------------------------------------------------------------------

function KnoxTVWindow:walkTo()
    local sq = self.device:getSquare()
    return sq ~= nil and luautils.walkAdj(self.player, sq, true)
end

--- One of the game's radio actions; a remote in hand works from afar (as the game).
function KnoxTVWindow:act(mode, arg)
    if self.data:canPlayerRemoteInteract(self.player) or self:walkTo() then
        ISTimedActionQueue.add(ISRadioAction:new(mode, self.player, self.device, arg))
    end
end

function KnoxTVWindow:togglePower()
    if not self:isOn() and not self.data:canBePoweredHere() then
        self.noPowerMs = getTimestampMs()
        return
    end
    self:act("ToggleOnOff")
    getSoundManager():playUISound("UIActivateButton")
end

function KnoxTVWindow:tune(i)
    local presets = self:presets()
    if #presets == 0 or not self:isOn() then return end
    i = T.mod(i - 1, #presets) + 1   -- (not %: the channel before the first was 0 in the game's Lua)
    self.tuning = i
    self.zapMs = getTimestampMs()
    self.lastLineMs = getTimestampMs()
    self.subs = {}
    -- the screen shows the new channel at once; the set is asked once the wheel
    -- (or the clicking) rests - not an action per notch, queued one after another
    self.pendingChan, self.pendingChanMs = presets[i].freq, getTimestampMs()
end

--- The channel picked with the wheel or clicks goes to the set once they rest:
--- one action for it, the channel changes still waiting in the queue go.
function KnoxTVWindow:flushChannel(now)
    if not self.pendingChan or (not now and getTimestampMs() - self.pendingChanMs < 300) then return end
    local freq = self.pendingChan
    self.pendingChan = nil
    local q = ISTimedActionQueue.getTimedActionQueue(self.player)
    if q and q.queue then
        for i = #q.queue, 2, -1 do
            local a = q.queue[i]
            if a and a.Type == "ISRadioAction" and a.mode == "SetChannel" and a.device == self.device then
                table.remove(q.queue, i)
            end
        end
    end
    if freq ~= self.data:getChannel() then self:act("SetChannel", freq) end
end

function KnoxTVWindow:step(dir)
    local i = self.tuning or self:channelIndex() or 0
    self:tune(i + dir)
end

function KnoxTVWindow:nudgeVolume(dir)
    if not self:isOn() then return end
    local v = math.floor(self:volume() * VOLUME_STEPS + 0.5) + dir
    v = math.max(0, math.min(VOLUME_STEPS, v))
    self.pendingVol = v / VOLUME_STEPS
    self.pendingVolMs = getTimestampMs()
    self.osdVolumeMs = getTimestampMs()
end

function KnoxTVWindow:mediaParam()
    return ISDeviceBatteryAction:getDeviceDataParameter(self.player, self.device, "IsoObject")
end

function KnoxTVWindow:accepts(item)
    return self:hasDeck() and not self.data:hasMedia() and item ~= nil and item:isRecordedMedia()
        and item:getMediaType() == self.data:getMediaType()
end

function KnoxTVWindow:insert(item)
    if not self:accepts(item) then return end
    if item:getWorldItem() and not luautils.walkAdj(self.player, item:getWorldItem():getSquare(), true) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, item)
    if self:walkTo() then
        ISTimedActionQueue.add(ISDeviceMediaAction:new(self.player, false, item, self:mediaParam()))
    end
end

function KnoxTVWindow:eject()
    if not self.data:hasMedia() then return end
    if self:walkTo() then
        ISTimedActionQueue.add(ISDeviceMediaAction:new(self.player, true, nil, self:mediaParam()))
    end
end

function KnoxTVWindow:togglePlay()
    if not (self:isOn() and self.data:hasMedia()) then return end
    self:act("TogglePlayMedia")
end

-- Drawing -----------------------------------------------------------------------------

-- (the snow takes some eight hundred random numbers a frame for as long as there
-- is no signal: ZombRand is a call into the game each, these are plain Lua;
-- the game's Lua has no math.random)
local seed = getTimestampMs() % 2147483646 + 1
local function noise(n)
    seed = (seed * 16807) % 2147483647
    return math.floor(seed / 2147483647 * n)
end

function KnoxTVWindow:drawSnow(x, y, w, h, n, a)
    local s = math.max(2, math.floor(T.cell / 24))
    local rw, rh = math.max(1, w - s), math.max(1, h - s)
    for _ = 1, n do
        local v = 0.35 + noise(60) / 100
        self:drawRect(x + noise(rw), y + noise(rh), s, s, a, v, v, v)
    end
end

function KnoxTVWindow:drawScreen(mx, my)
    local R = self.R
    local x, y, w, h = R.screen[1], R.screen[2], R.screen[3], R.screen[4]
    local now = getTimestampMs()
    local on = self:isOn()
    local pad = T.pad
    T.rect(self, x, y, w, h, on and GLASS_ON or GLASS)

    if not on then
        -- glass at rest: a faint reflection across it
        for i = 0, 5 do
            self:drawRect(x + math.floor(w * 0.08) + i * 3, y + math.floor(h * 0.1), 2, math.floor(h * 0.45), 0.025, 1, 1, 1)
        end
        if self.noPowerMs and now - self.noPowerMs < 2500 then
            local f = osdFont()
            local text = getText("IGUI_RadioRequiresPowerNearby")
            T.textCentre(self, T.fit(text, T.fontText, w - pad * 2), x + math.floor(w / 2),
                y + math.floor((h - T.fontH(T.fontText)) / 2), T.color.bad, T.fontText)
        end
    else
        local playing = self.data:isPlayingMedia()
        local zapping = now - self.zapMs < 450
        local wait = math.max(NO_SIGNAL_MS, (self.lastLineLen or 0) * 100 + 6000)
        local quiet = now - self.lastLineMs > wait and not playing
        if zapping then
            self:drawSnow(x, y, w, h, 420, 0.55)
        elseif quiet then
            self:drawSnow(x, y, w, h, 260, 0.3)
        end
        -- scan lines
        for sy = y, y + h - 1, 3 do self:drawRect(x, sy, w, 1, 0.16, 0, 0, 0) end

        local f = osdFont()
        local fh = T.fontH(f)
        local small = T.fontCaps
        local ox, oy = x + pad + 4, y + pad
        -- top left: the channel (or the tape playing) and its name
        local idx, preset = self:channelIndex()
        if self.tuning and idx == self.tuning then self.tuning = nil end
        local label, sub
        if playing then
            local s = math.floor(fh * 0.55)
            triangle(self, ox, oy + math.floor((fh - s * 2) / 2) + 2, s, "right", OSD)
            T.text(self, "PLAY", ox + s + 8, oy, OSD, f)
            local md = self.data:getMediaData()
            sub = md and md:getTranslatedTitle() or ""
        else
            local i = self.tuning or idx
            label = "CH " .. (i and string.format("%02d", i) or "--")
            T.text(self, label, ox, oy, OSD, f)
            local p = self.tuning and self:presets()[self.tuning] or preset
            sub = p and p.name or ""
        end
        if self.hoverChan then
            local p = self:presets()[self.hoverChan]
            if p then sub = p.name end
        end
        if sub and sub ~= "" then
            T.text(self, T.fit(sub, small, math.floor(w * 0.6)), ox, oy + fh + 2,
                self.hoverChan and T.color.accent or OSD, small, 0.8)
        end
        -- top right: the time, as the game's clock shows it (minutes in tens, 12 or 24 hours)
        local clock = clockText(getGameTime():getTimeOfDay())
        T.textRight(self, clock, x + w - pad - 4, oy, OSD, f)

        -- skills and moods the show changed, on the right under the name line, fading
        local by = oy + fh + 2 + T.fontH(small) + 8
        local keep = {}
        for _, b in ipairs(self.badges) do
            local age = now - b.t
            if age < 5000 then
                table.insert(keep, b)
                local a = age < 4000 and 1 or (5000 - age) / 1000
                local tw = T.measure(small, b.text)
                local s = math.floor(T.fontH(small) * 0.35)
                local bw, bh = tw + s * 2 + 18, T.fontH(small) + 6
                local bx = x + w - pad - 4 - bw
                self:drawRect(bx, by, bw, bh, 0.18 * a, b.color.r, b.color.g, b.color.b)
                T.border(self, bx, by, bw, bh, b.color, a)
                T.text(self, b.text, bx + 6, by + 3, b.color, small, a)
                triangle(self, bx + 6 + tw + 6, by + math.floor((bh - s) / 2), s, b.dir, b.color)
                by = by + bh + 4
            end
        end
        self.badges = keep

        -- "no signal" in the middle, blinking
        if quiet and not zapping then
            local text = T.upper(getText("IGUI_Knox_TVNoSignal"))
            if math.floor(now / 700) % 2 == 0 then
                T.textCentre(self, text, x + math.floor(w / 2), y + math.floor((h - fh) / 2), OSD, f)
            end
        end

        -- volume: green blocks at the bottom left for a while after a change
        local volShown = now - self.osdVolumeMs < 2500
        if volShown then
            local vy = y + h - pad - fh
            T.text(self, "VOL", ox, vy, OSD, f)
            local bx = ox + T.measure(f, "VOL") + 10
            local n = math.floor(self:volume() * VOLUME_STEPS + 0.5)
            local bw2 = math.max(4, math.floor(fh * 0.32))
            for i = 1, VOLUME_STEPS do
                local a = i <= n and 1 or 0.22
                self:drawRect(bx + (i - 1) * (bw2 + 3), vy + 3, bw2, fh - 6, a, OSD.r, OSD.g, OSD.b)
            end
        end

        -- subtitles: the line being said, the one before it faded above
        self:drawSubtitles(x, y, w, h, now, volShown and (fh + pad) or 0)
    end

    -- glass edge and the rounded corners of the tube
    roundCorners(self, x, y, w, h, math.floor(T.cell * 0.28), CABINET)
    T.border(self, x - 1, y - 1, w + 2, h + 2, CABINET_EDGE)
end

local function shown(sub, now)
    local dur = math.min(9000, 1800 + string.len(sub.text) * 70)
    return now - sub.t < dur
end

function KnoxTVWindow:drawSubtitles(x, y, w, h, now, bottomGap)
    local f = subFont()
    local fh = T.fontH(f)
    local pad = T.pad
    local maxW = w - pad * 4
    local blocks = {}
    for i = #self.subs, math.max(1, #self.subs - 1), -1 do
        local s = self.subs[i]
        if shown(s, now) then table.insert(blocks, 1, {sub = s, current = i == #self.subs}) end
    end
    local yy = y + h - pad - bottomGap
    for i = #blocks, 1, -1 do
        local b = blocks[i]
        -- (wrapped once for the font and width, not every frame it is up)
        local sub = b.sub
        if sub.wrapF ~= f or sub.wrapW ~= maxW then
            sub.lines, sub.wrapF, sub.wrapW = T.wrap(sub.text, f, maxW), f, maxW
            -- the speaker's color, lifted a little so it reads on the dark glass
            local c = sub.color
            sub.lift = {r = c.r + (1 - c.r) * 0.25, g = c.g + (1 - c.g) * 0.25, b = c.b + (1 - c.b) * 0.25}
        end
        local lines, col = sub.lines, sub.lift
        local a = b.current and 1 or 0.55
        for j = #lines, 1, -1 do
            local tw = T.measure(f, lines[j])
            yy = yy - fh - 4
            local lx = x + math.floor((w - tw) / 2)
            self:drawRect(lx - 6, yy - 1, tw + 12, fh + 2, 0.6 * a, 0, 0, 0)
            T.text(self, lines[j], lx, yy, col, f, a)
        end
        yy = yy - 6
    end
end

function KnoxTVWindow:drawPanel(mx, my)
    local R = self.R
    local over = self:isMouseOver()
    local on = self:isOn()

    -- power: a button with its lamp
    local p = R.power
    local hot = over and inRect(mx, my, p)
    T.button(self, p, "", {hover = hot})
    local ls = math.floor(p[4] * 0.32)
    local lx, ly = p[1] + math.floor(p[4] * 0.35), p[2] + math.floor((p[4] - ls) / 2)
    local lc = on and LED_ON or LED_OFF
    if on then self:drawRect(lx - 3, ly - 3, ls + 6, ls + 6, 0.18, lc.r, lc.g, lc.b) end
    T.rect(self, lx, ly, ls, ls, lc)
    local cap = T.upper(getText(on and "ContextMenu_Turn_Off" or "ContextMenu_Turn_On"))
    T.text(self, cap, lx + ls + 10, p[2] + math.floor((p[4] - T.fontH(T.fontCaps)) / 2),
        hot and T.color.accent or T.color.text, T.fontCaps)

    -- channel knob and buttons
    local presets = self:presets()
    local idx = self.tuning or self:channelIndex()
    T.caps(self, getText("IGUI_Knox_TVChannel"), R.panel[1], R.chanCapY, T.color.dim)
    local k = R.chanKnob
    local kHot = over and on and (mx - k[1]) ^ 2 + (my - k[2]) ^ 2 <= k[3] ^ 2
    local n = math.max(1, #presets)
    local ang = idx and (-2.35 + 4.7 * (idx - 1) / math.max(1, n - 1)) or -2.35
    knob(self, k[1], k[2], k[3], ang, kHot)
    self.hoverChan = nil
    for _, b in ipairs(R.chanBtns) do
        local bh = over and inRect(mx, my, b)
        if bh then self.hoverChan = b[5] end
        T.button(self, b, tostring(b[5]), {hover = bh and on, active = on and idx == b[5], disabled = not on, font = T.fontCaps})
    end

    -- volume knob and its value
    T.caps(self, getText("IGUI_Knox_TVVolume"), R.panel[1], R.volCapY, T.color.dim)
    local v = R.volKnob
    local vHot = over and on and (mx - v[1]) ^ 2 + (my - v[2]) ^ 2 <= v[3] ^ 2
    local vol = self:volume()
    knob(self, v[1], v[2], v[3], -2.35 + 4.7 * vol, vHot)
    local vt = on and (vol <= 0.001 and getText("IGUI_Knox_TVMuted") or (math.floor(vol * VOLUME_STEPS + 0.5) .. " / " .. VOLUME_STEPS)) or "-"
    T.textCentre(self, vt, v[1], R.volTextY, T.color.dim, T.fontText)
end

function KnoxTVWindow:drawDeck(mx, my)
    local R = self.R
    local d = R.deck
    local pad = T.pad
    -- a darker strip with a thin slot line, as a video deck's front
    self:drawRect(d[1], d[2], d[3], d[4], 0.35, 0, 0, 0)
    T.border(self, d[1], d[2], d[3], d[4], CABINET_EDGE)
    if not self:hasDeck() then
        -- no deck: the set's name plate
        local name = T.upper(self.data:getDeviceName() or "")
        T.textCentre(self, T.fit(name, T.fontTile, d[3] - pad * 2), d[1] + math.floor(d[3] / 2),
            d[2] + math.floor((d[4] - T.fontTileH) / 2), T.color.dim, T.fontTile)
        return
    end
    local over = self:isMouseOver()
    local s = R.slot
    local has = self.data:hasMedia()
    local hot = over and inRect(mx, my, s)
    T.rect(self, s[1], s[2], s[3], s[4], T.color.cell)
    local offered = 0
    if has then
        T.rect(self, s[1], s[2], s[3], s[4], T.category.info)
        local tex = tapeTexture()
        if tex then
            local side = math.floor(s[4] * 0.85)
            self:drawTextureScaledAspect(tex, s[1] + math.floor((s[3] - side) / 2), s[2] + math.floor((s[4] - side) / 2), side, side, 1, 1, 1, 1)
        end
    else
        -- an empty slot: the cassette mouth, and the carried tapes on hover
        T.rect(self, s[1] + math.floor(s[3] * 0.15), s[2] + math.floor(s[4] / 2) - 1, math.floor(s[3] * 0.7), 3, T.color.line)
        local open = KnoxSlotPicker.isOpenFor(self.slotRef)
        if not KnoxDrag.isActive() and (hot or open) then
            local cands = carriedMedia(self.player, self.data:getMediaType())
            offered = #cands
            if hot and offered > 0 then
                local win = self
                KnoxSlotPicker.want(self.slotRef, getText("IGUI_Knox_TVTape"), cands,
                    function(it) win:insert(it) end, "above", self.playerNum, self, true)
            end
        end
    end
    local edge = has and T.color.tileFrame or T.color.tileEdge
    if hot then edge = T.color.tileHover end
    if KnoxDrag.isActive() and hot then
        local ok = self:accepts(KnoxDrag.entity.item)
        local c = ok and T.color.ok or T.color.bad
        self:drawRect(s[1], s[2], s[3], s[4], 0.22, c.r, c.g, c.b)
        edge = c
    end
    T.tileFrame(self, s[1], s[2], s[3], s[4], edge)
    if offered > 0 and not has then T.target(self, s[1], s[2], s[3], s[4]) end

    -- title of the tape
    local md = has and self.data:getMediaData()
    local title = md and md:getTranslatedTitle() or getText("IGUI_media_notape")
    local fh = T.fontH(T.fontText)
    T.text(self, T.fit(title or "", T.fontText, R.titleW), R.titleX,
        d[2] + math.floor((d[4] - fh) / 2) - (md and md:hasSubTitle() and math.floor(fh / 2) or 0),
        md and T.color.bright or T.color.dim, T.fontText)
    if md and md:hasSubTitle() then
        T.text(self, T.fit(md:getTranslatedSubTitle() or "", T.fontText, R.titleW), R.titleX,
            d[2] + math.floor((d[4] - fh) / 2) + math.floor(fh / 2), T.color.dim, T.fontText)
    end

    -- play / stop, eject
    local playing = self.data:isPlayingMedia()
    local canPlay = has and self:isOn()
    local pHot = over and inRect(mx, my, R.play) and canPlay
    T.button(self, R.play, "", {hover = pHot, disabled = not canPlay, active = playing})
    local p = R.play
    local mc = not canPlay and T.color.dim or (pHot and T.color.accent or T.color.text)
    local s = math.floor(p[4] * 0.28)
    if playing then
        -- stop: a square
        T.rect(self, p[1] + math.floor(p[3] / 2) - s, p[2] + math.floor(p[4] / 2) - s, s * 2, s * 2, mc)
    else
        triangle(self, p[1] + math.floor(p[3] / 2) - math.floor(s / 2), p[2] + math.floor(p[4] / 2) - s + 1, s, "right", mc)
    end
    local e = R.eject
    local eHot = over and inRect(mx, my, e) and has
    T.button(self, e, "", {hover = eHot, disabled = not has})
    -- eject: a triangle up over a bar
    local ec = not has and T.color.dim or (eHot and T.color.accent or T.color.text)
    local cx = e[1] + math.floor(e[3] / 2)
    local ty = e[2] + math.floor(e[4] / 2) - s
    triangle(self, cx - s + 1, ty, s, "up", ec)
    T.rect(self, cx - s + 1, ty + s + 2, s * 2 - 1, math.max(2, math.floor(s / 3)), ec)
    -- what the buttons do, as the game's names, in the tooltip line under the mouse
    if pHot or eHot then
        local tip = eHot and getText("IGUI_Knox_TVEject") or getText(playing and "IGUI_media_stop" or "IGUI_media_play")
        local tw = T.measure(T.fontText, tip) + 12
        local tx = math.min(self:getWidth() - tw - 2, mx + 12)
        local ty2 = my - T.fontH(T.fontText) - 10
        T.rect(self, tx, ty2, tw, T.fontH(T.fontText) + 4, T.color.header)
        T.border(self, tx, ty2, tw, T.fontH(T.fontText) + 4, T.color.tileEdge)
        T.text(self, tip, tx + 6, ty2 + 2, T.color.text, T.fontText)
    end
end

function KnoxTVWindow:prerender()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    if not self:validate() then return end
    KnoxSlotPicker.sync(self)
    self:pollLines()
    self:flushVolume()
    self:flushChannel()
    if self.R.deckFor ~= self:hasDeck() then self:layout() self.R.deckFor = self:hasDeck() end
    local R = self.R
    local w, h = self:getWidth(), self:getHeight()
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()

    -- plate as the other windows
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, R.headerH, T.color.header)
    T.rect(self, 0, R.headerH, w, 1, T.color.border)
    T.border(self, 0, 0, w, h, T.color.hoverEdge)
    local ac, a = T.color.accent, self.knoxMove and 1 or 0.5
    self:drawRectBorder(0, 0, w, h, a, ac.r, ac.g, ac.b)
    self:drawRectBorder(1, 1, w - 2, h - 2, a, ac.r, ac.g, ac.b)
    local title = self.data:getDeviceName() or ""
    T.caps(self, T.fit(title, T.fontCaps, R.x[1] - T.pad * 2), T.pad, math.floor((R.headerH - T.fontH(T.fontCaps)) / 2), T.color.bright)
    T.closeButton(self, R.x[1], R.x[2], R.x[3], over and inRect(mx, my, R.x))

    -- the cabinet
    local c = R.cab
    T.rect(self, c[1], c[2], c[3], c[4], CABINET)
    T.border(self, c[1], c[2], c[3], c[4], CABINET_EDGE)
    T.rect(self, c[1] + 1, c[2] + 1, c[3] - 2, 1, {r = 1, g = 1, b = 1}, 0.06)

    self:drawScreen(mx, my)
    self:drawPanel(mx, my)
    self:drawDeck(mx, my)
end

-- Input ---------------------------------------------------------------------------------

local function inKnob(x, y, k)
    return (x - k[1]) ^ 2 + (y - k[2]) ^ 2 <= k[3] ^ 2
end

function KnoxTVWindow:onMouseDown(x, y)
    if self.foldMs then return true end
    self:bringToTop()
    local R = self.R
    if inRect(x, y, R.x) then self:close() return true end
    if inRect(x, y, R.power) then self:togglePower() return true end
    if inKnob(x, y, R.chanKnob) then self:step(1) return true end
    for _, b in ipairs(R.chanBtns) do
        if inRect(x, y, b) then self:tune(b[5]) return true end
    end
    if inKnob(x, y, R.volKnob) then self:nudgeVolume(1) return true end
    if self:hasDeck() then
        if inRect(x, y, R.play) then self:togglePlay() return true end
        if inRect(x, y, R.eject) then self:eject() return true end
        if inRect(x, y, R.slot) then return true end   -- the quick pick panel does the choosing
    end
    KnoxWindowDrag.begin(self, x, y, R.headerH)
    return true
end

KnoxWindowDrag.install(KnoxTVWindow)

local dragStop = KnoxTVWindow.onMouseUp
function KnoxTVWindow:onMouseUp(x, y)
    -- a tape dropped on the slot from a Knox grid
    if KnoxDrag and KnoxDrag.isActive() and self:hasDeck() and inRect(x, y, self.R.slot) then
        local item = KnoxDrag.entity.item
        KnoxDrag.cancel()
        self:insert(item)
        return true
    end
    return dragStop(self, x, y)
end

function KnoxTVWindow:onRightMouseUp(x, y)
    if KnoxDrag and KnoxDrag.isActive() then return true end   -- (an item is held: the button may turn it, see KnoxDragLayer)
    local R = self.R
    if inKnob(x, y, R.chanKnob) then self:step(-1) return true end
    if inKnob(x, y, R.volKnob) then self:nudgeVolume(-1) return true end
    if self:hasDeck() and inRect(x, y, R.slot) then self:eject() return true end
    return true
end

function KnoxTVWindow:onMouseWheel(del)
    local R = self.R
    local x, y = self:getMouseX(), self:getMouseY()
    local dir = del > 0 and -1 or 1
    if inKnob(x, y, R.chanKnob) or inRect(x, y, R.screen) then
        self:step(dir)
    else
        self:nudgeVolume(dir)
    end
    return true
end

function KnoxTVWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function KnoxTVWindow:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end

function KnoxTVWindow:close()
    W.lastX, W.lastY = self:getX(), self:getY()
    if KnoxSlotPicker.instance and KnoxSlotPicker.instance.host == self then KnoxSlotPicker.close() end
    if self.pendingVol then self.pendingVolMs = 0 self:flushVolume() end
    self:flushChannel(true)
    T.fold(self, function(w)
        w:setVisible(false)
        w:removeFromUIManager()
    end)
    if W.instance == self then
        W.instance = nil
        if knoxHideDeviceText then knoxHideDeviceText(nil) end   -- its lines over it in the world again
    end
end

-- Skills and moods a show changes: the game shows them over the character
-- (ISRadioInteractions addHalo); the open set shows them on its screen too.
local function hookHalo()
    if not ISRadioInteractions or W.haloHooked then return end
    local inst = ISRadioInteractions:getInstance()
    if not inst or not inst.addHalo then return end
    W.haloHooked = true
    local original = inst.addHalo
    inst.addHalo = function(str, amount, inverse)
        local w = W.instance
        if w and w:isOn() and str then
            local dir, good = nil, true
            if type(amount) == "number" and amount ~= 0 then
                dir = amount > 0 and "up" or "down"
                -- as the game colors it: skills (inverse) good when up, moods good when down
                if inverse then good = amount > 0 else good = amount < 0 end
            end
            table.insert(w.badges, {text = str, dir = dir or "up", t = getTimestampMs(),
                color = good and T.color.good or T.color.bad})
            while #w.badges > 4 do table.remove(w.badges, 1) end
        end
        -- the radio's paper tape notes it under the line that taught it
        if KnoxRadioWindow and KnoxRadioWindow.noteHalo then KnoxRadioWindow.noteHalo(str, amount, inverse) end
        return original(str, amount, inverse)
    end
end
W.hookHalo = hookHalo

--- Open in place of the game's window.
function W.open(player, device)
    hookHalo()
    if W.instance then
        if W.instance.device == device then W.instance:bringToTop() return W.instance end
        W.instance:close()
    end
    local w = W:new(player, device)
    w:initialise()
    w:instantiate()
    w:setWantKeyEvents(true)
    w.R.deckFor = w:hasDeck()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = W.lastX or math.floor((sw - w:getWidth()) / 2)
    local y = W.lastY or math.floor((sh - w:getHeight()) / 2)
    w:setX(math.max(0, math.min(sw - w:getWidth(), x)))
    w:setY(math.max(0, math.min(sh - w:getHeight(), y)))
    w:addToUIManager()
    W.instance = w
    -- its lines are on the window's screen now, not over the set in the world
    if knoxHideDeviceText then knoxHideDeviceText(device) end
    return w
end

return KnoxTVWindow
