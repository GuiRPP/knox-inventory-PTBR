-- A radio receiver in Knox's look: the window is the set. On top the dial:
-- the band with its scale, the saved stations as green marks, the amber
-- needle (drag it, or the wheel), the frequency and the station's name, the
-- signal bars. Under it the paper tape: what was said, with the time, the
-- frequency when it changes, the skills a show taught - it keeps going while
-- the window is closed (the Java part keeps the last lines of each set).
-- On the right the tuning and volume knobs and the station buttons; along the
-- bottom what the set takes: a battery, headphones, a disc, the microphone of a
-- ham radio, and the power switch.
-- It takes the place of the game's radio window for radios in the world, in
-- cars and carried, walkie-talkies too (1.0: a body of dark plastic instead of
-- the wooden cabinet, the microphone switch by the power); the game's actions
-- do the work (ISRadioAction, ISDeviceBatteryAction, ISDeviceMediaAction).

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxSlotPicker"
require "Knox/KnoxTVWindow"

KnoxRadioWindow = ISPanel:derive("KnoxRadioWindow")
local W = KnoxRadioWindow
local T = KnoxTheme
local TV = KnoxTVWindow

W.instance = nil
W.lastX, W.lastY = nil, nil
W.halos = {}   -- line number (of the Java part) -> skills and moods it changed
W.haloSeqs = {}   -- those line numbers, oldest first
local HALO_LINES = 1000   -- (the Java part keeps 200 lines a set)

local inRect = T.inRect

local CABINET = {r = 0x2b / 255, g = 0x22 / 255, b = 0x19 / 255}
local CABINET_EDGE = {r = 0x44 / 255, g = 0x36 / 255, b = 0x2a / 255}
local DIAL = {r = 0x16 / 255, g = 0x12 / 255, b = 0x0d / 255}
local DIAL_EDGE = {r = 0x4a / 255, g = 0x3c / 255, b = 0x2e / 255}
-- a walkie-talkie: olive-black plastic, the dial's glass darker
local HANDHELD = {
    cab = {r = 0x20 / 255, g = 0x24 / 255, b = 0x1d / 255}, cabEdge = {r = 0x3b / 255, g = 0x42 / 255, b = 0x35 / 255},
    dial = {r = 0x0f / 255, g = 0x12 / 255, b = 0x0e / 255}, dialEdge = {r = 0x3a / 255, g = 0x43 / 255, b = 0x36 / 255},
}
local WOODEN = {cab = CABINET, cabEdge = CABINET_EDGE, dial = DIAL, dialEdge = DIAL_EDGE}
local AMBER = {r = 1, g = 0.71, b = 0.28}
local SCALE = {r = 0x8a / 255, g = 0x7a / 255, b = 0x60 / 255}
local PAPER = {r = 0xe9 / 255, g = 0xe2 / 255, b = 0xcf / 255}
local PAPER_EDGE = {r = 0xb9 / 255, g = 0xae / 255, b = 0x92 / 255}
local INK = {r = 0x3a / 255, g = 0x34 / 255, b = 0x2a / 255}
local INK_DIM = {r = 0x8a / 255, g = 0x7f / 255, b = 0x68 / 255}
local INK_GOOD = {r = 0x2f / 255, g = 0x6b / 255, b = 0x3a / 255}
local INK_BAD = {r = 0x9a / 255, g = 0x34 / 255, b = 0x2a / 255}
local LED_ON = {r = 0.45, g = 0.85, b = 0.35}
local LED_OFF = {r = 0.45, g = 0.12, b = 0.1}

local WALK_DIST = 10
local VOLUME_STEPS = 10
local FREQ_STEP = 200   -- kHz, as the game's preset editor (0.2 MHz)

local function mhz(f)
    local v = math.floor(f / 100 + 0.5) / 10
    if v == math.floor(v) then return tostring(math.floor(v)) .. ".0" end
    return tostring(v)
end

local function channelName(f)
    local zr = getZomboidRadio and getZomboidRadio()
    local ok, name = pcall(function() return zr and zr:getChannelName(f) end)
    if ok and name and name ~= "" then return name end
    return nil
end

--- Carried items that pass `test` (pockets, bags, hands).
local function carried(player, test)
    local out = {}
    local function walk(c, depth)
        local items = c:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            -- (not what a bag not searched yet still hides: KnoxSearch)
            if test(it) and not (KnoxSearch and KnoxSearch.unseen(it)) then table.insert(out, it) end
            if depth < 3 and instanceof(it, "InventoryContainer") and it:getInventory() then
                walk(it:getInventory(), depth + 1)
            end
        end
    end
    walk(player:getInventory(), 0)
    return out
end

-- A slot along the bottom as the quick pick panel sees it.
local SlotRef = {}
SlotRef.__index = SlotRef
function SlotRef:rect() return self.win.R.slots[self.key].r end
function SlotRef:getAbsoluteX() return self.win:getAbsoluteX() + self:rect()[1] end
function SlotRef:getAbsoluteY() return self.win:getAbsoluteY() + self:rect()[2] end
function SlotRef:getWidth() return self:rect()[3] end
function SlotRef:getHeight() return self:rect()[4] end

-- Which devices this window is for ------------------------------------------------------

--- "InventoryItem" / "IsoObject" / "VehiclePart", as the game's window.
local function deviceTypeOf(device)
    if instanceof(device, "Radio") then return "InventoryItem" end
    if instanceof(device, "IsoWaveSignal") then return "IsoObject" end
    if instanceof(device, "VehiclePart") then return "VehiclePart" end
    return nil
end

--- A radio (not a TV): in the world, in a car, carried - a walkie-talkie too.
function W.handles(device)
    local kind = deviceTypeOf(device)
    local data = kind and device:getDeviceData()
    if not data or data:getIsTelevision() then return false end
    return true
end

--- A walkie-talkie: a carried two-way radio.
local function isWalkie(kind, data)
    return kind == "InventoryItem" and data ~= nil and data:getIsTwoWay()
end

-- Window ------------------------------------------------------------------------------

function KnoxRadioWindow:new(player, device)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.device = device
    o.kind = deviceTypeOf(device)
    o.data = device:getDeviceData()
    o.skin = isWalkie(o.kind, o.data) and HANDHELD or WOODEN
    o.entries = {}       -- the tape: {seq, text, color, channel, tod}
    o.lastSeq = 0
    o.scroll = 0         -- rows up from the newest
    o.rowsDirty = true
    o.background = false
    o.moveWithMouse = false
    o.refs = {}
    return o
end

function KnoxRadioWindow:ref(key)
    if not self.refs[key] then self.refs[key] = setmetatable({win = self, key = key}, SlotRef) end
    return self.refs[key]
end

function KnoxRadioWindow:createChildren()
    self:layout()
end

function KnoxRadioWindow:tunable()
    return not self.data:isNoTransmit()
end

function KnoxRadioWindow:layout()
    local c, pad = T.cell, T.pad
    local d = self.data
    local R = {}
    R.headerH = T.sectionH + 4
    local bezel = math.floor(c * 0.3)
    local innerW = math.floor(c * 10)
    local btnH = math.floor(c * 0.62 + 0.5)
    local ctrlW = math.floor(c * 2.6)
    -- two knobs share the panel: each caption needs its half (RU "НАСТРОЙКА" / "ГРОМКОСТЬ"
    -- ran into each other at 2.6 cells); the window grows, the tape keeps its width
    if self:tunable() then
        local capW = math.max(T.measure(T.fontCaps, T.upper(getText("IGUI_Knox_RadioTuning"))),
            T.measure(T.fontCaps, T.upper(getText("IGUI_Knox_TVVolume"))))
        local need = (capW + 8) * 2
        if need > ctrlW then
            innerW = innerW + need - ctrlW
            ctrlW = need
        end
    end
    local tapeW = innerW - ctrlW - bezel
    R.cab = {pad, R.headerH + pad, innerW + bezel * 2, 0}
    local x0, y = R.cab[1] + bezel, R.cab[2] + bezel
    if self:tunable() then
        R.dial = {x0, y, innerW, math.floor(c * 1.7)}
        y = y + R.dial[4] + bezel
    end
    local midH = math.floor(c * 3.6)
    R.tape = {x0, y, tapeW, midH}
    R.panel = {x0 + tapeW + bezel, y, ctrlW, midH}

    -- the panel: two knobs side by side, the station buttons under them
    local capH = T.fontH(T.fontCaps)
    local px, pw = R.panel[1], R.panel[3]
    R.knobR = math.floor(c * 0.5)
    local ky = y + capH + 4 + R.knobR
    if self:tunable() then
        R.tuneKnob = {px + math.floor(pw / 4), ky, R.knobR}
        R.volKnob = {px + math.floor(pw * 3 / 4), ky, R.knobR}
    else
        R.volKnob = {px + math.floor(pw / 2), ky, R.knobR}
    end
    R.capY = y
    R.knobTextY = ky + R.knobR + 4
    R.presetY = R.knobTextY + T.fontH(T.fontText) + pad
    R.presetBtns = {}
    if self:tunable() then
        local cols, gap = 4, 4
        local bs = math.floor((pw - gap * (cols - 1)) / cols)
        local bh = math.floor(bs * 0.75)
        local presets = self:presets()
        local maxP = self:maxPresets()
        local n = math.min(#presets, 11)
        local slots = n + ((#presets < maxP) and 1 or 0)   -- "+" to save the station
        for i = 1, slots do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            local b = {px + col * (bs + gap), R.presetY + row * (bh + gap), bs, bh, i <= n and i or 0}
            table.insert(R.presetBtns, b)
        end
        local rows = math.max(1, math.ceil(slots / cols))
        local bottom = R.presetY + rows * (bh + gap)
        if bottom > R.panel[2] + R.panel[4] then
            local extra = bottom - (R.panel[2] + R.panel[4])
            R.panel[4] = R.panel[4] + extra
            R.tape[4] = R.tape[4] + extra
        end
    end
    y = R.tape[2] + R.tape[4] + bezel

    -- the bottom strip: what the set takes, then the power switch on the right
    local sh = btnH + 8
    R.strip = {x0, y, innerW, sh}
    R.slots = {}
    local sx = x0
    local slotW = math.floor(sh * 1.5)
    local function slot(key)
        R.slots[key] = {r = {sx, y, slotW, sh}}
        sx = sx + slotW + 6
        return R.slots[key]
    end
    if d:getIsBatteryPowered() then
        local s = slot("battery")
        s.textX = sx
        sx = sx + T.measure(T.fontText, "100%") + pad
    end
    if d:getIsPortable() then slot("headphones") end
    if d:getMediaType() == 0 then
        local s = slot("disc")
        local bs = btnH
        s.play = {sx, y + math.floor((sh - bs) / 2), bs, bs}
        s.eject = {sx + bs + 4, s.play[2], bs, bs}
        sx = sx + bs * 2 + 4 + 6
        s.titleX = sx
    end
    local powerW = T.buttonW(getText("ContextMenu_Turn_Off")) + btnH
    R.power = {x0 + innerW - powerW, y + math.floor((sh - btnH) / 2), powerW, btnH}
    if d:getIsTwoWay() then
        local mw = T.buttonW(getText("IGUI_Knox_RadioMic")) + btnH
        R.mic = {R.power[1] - 6 - mw, R.power[2], mw, btnH}
    end
    if R.slots.disc then R.slots.disc.titleW = (R.mic and R.mic[1] or R.power[1]) - pad - R.slots.disc.titleX end
    y = y + sh + bezel
    R.cab[4] = y - R.cab[2]

    local s = R.headerH - 8
    local w = R.cab[1] * 2 + R.cab[3]
    R.x = {w - s - 4, 4, s, s}
    self.R = R
    self.layoutKey = self:layoutKeyNow()
    self.rowsDirty = true
    self:setWidth(w)
    self:setHeight(R.cab[2] + R.cab[4] + pad)
end

function KnoxRadioWindow:layoutKeyNow()
    return tostring(#self:presets()) .. "/" .. tostring(self.data:getMediaType())
end

-- State ------------------------------------------------------------------------------

function KnoxRadioWindow:presetList()
    local dp = self.data:getDevicePresets()
    return dp and dp:getPresets()
end

function KnoxRadioWindow:maxPresets()
    local dp = self.data:getDevicePresets()
    return dp and dp:getMaxPresets() or 0
end

--- (asked five or six times a frame: kept a moment while their number stays;
--- saving or removing one drops it at once)
function KnoxRadioWindow:presets()
    local list = self:presetList()
    local n, now = list and list:size() or -1, getTimestampMs()
    local pc = self.presetsOf
    if pc and pc.list == list and pc.n == n and now - pc.ms < 250 then return pc.out end
    local out = {}
    self.presetsOf = {list = list, n = n, ms = now, out = out}
    if list then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            table.insert(out, {freq = p:getFrequency(), name = p:getName(), entry = p})
        end
    end
    return out
end

function KnoxRadioWindow:isOn()
    return self.data:getIsTurnedOn()
end

function KnoxRadioWindow:range()
    return self.data:getMinChannelRange(), self.data:getMaxChannelRange()
end

--- The frequency to show: being dragged / wheeled, asked for until the set has it, else the set's.
function KnoxRadioWindow:freq()
    if self.pendingFreq then return self.pendingFreq end
    local dev = self.data:getChannel()
    if self.askedFreq then
        if dev == self.askedFreq or getTimestampMs() - self.askedFreqMs > 8000 then
            self.askedFreq = nil
        else
            return self.askedFreq
        end
    end
    return dev
end

function KnoxRadioWindow:volume()
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

--- Is the set still there, and in reach? (as the game's window)
function KnoxRadioWindow:validate()
    local d, p = self.device, self.player
    if p:isDead() or not d:getDeviceData() then self:close() return false end
    self.data = d:getDeviceData()
    if self.kind == "InventoryItem" then
        -- a carried radio: in a hand or on the back, else it is switched off (as the game)
        if p:getPrimaryHandItem() ~= d and p:getSecondaryHandItem() ~= d and p:getClothingItem_Back() ~= d then
            if self.data:getIsTurnedOn() then
                self.data:setIsTurnedOn(false)
                d:setActivated(false)
            end
            self:close()
            return false
        end
    elseif self.kind == "IsoObject" then
        if not d:getSquare() or d:getObjectIndex() < 0
            or math.abs(p:getX() - d:getX()) > WALK_DIST or math.abs(p:getY() - d:getY()) > WALK_DIST then
            self:close()
            return false
        end
    elseif self.kind == "VehiclePart" then
        local it = d:getItemType()
        if (it and not it:isEmpty() and not d:getInventoryItem()) or not d:getVehicle()
            or math.abs(p:getX() - d:getX()) > WALK_DIST or math.abs(p:getY() - d:getY()) > WALK_DIST then
            self:close()
            return false
        end
    end
    return true
end

--- New lines from the Java part (also the ones from while the window was closed).
function KnoxRadioWindow:pollLines()
    local s = knoxDeviceText and knoxDeviceText(self.device, self.lastSeq) or ""
    if s == "" then return end
    local added = 0
    for line in string.gmatch(s, "[^\n]+") do
        local seq, _, r, g, b, ch, tod, text =
            string.match(line, "^(%d+)\t(%d+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]*)\t(.*)$")
        if seq then
            seq = tonumber(seq)
            self.lastSeq = math.max(self.lastSeq, seq)
            text = string.gsub(text, "%[[^%]]*%]", "")
            text = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
            if text ~= "" then
                table.insert(self.entries, {seq = seq, text = text, channel = tonumber(ch) or 0,
                    tod = tonumber(tod) or 0, color = {r = tonumber(r) or 1, g = tonumber(g) or 1, b = tonumber(b) or 1}})
                added = added + 1
            end
        end
    end
    while #self.entries > 200 do table.remove(self.entries, 1) end
    if added > 0 then
        self.rowsDirty = true
        self.keepScroll = self.scroll > 0
    end
end

function KnoxRadioWindow:flush()
    local now = getTimestampMs()
    if self.pendingVol and now - self.pendingVolMs > 350 then
        local v = self.pendingVol
        self.pendingVol = nil
        if math.abs(v - self.data:getDeviceVolume()) > 0.001 then
            self:dropQueued("SetVolume")
            self.askedVol, self.askedVolMs = v, now
            self:act("SetVolume", v)
        end
    end
    if self.pendingFreq and not self.draggingDial and now - self.pendingFreqMs > 400 then
        local f = self.pendingFreq
        self.pendingFreq = nil
        if f ~= self.data:getChannel() then
            self:dropQueued("SetChannel")
            self.askedFreq, self.askedFreqMs = f, now
            self:act("SetChannel", f)
        end
    end
end

-- Actions ----------------------------------------------------------------------------

function KnoxRadioWindow:walkTo()
    local d, p = self.device, self.player
    if self.kind == "InventoryItem" then return true end
    if self.kind == "IsoObject" then
        local sq = d:getSquare()
        return sq ~= nil and luautils.walkAdj(p, sq, true)
    end
    if self.kind == "VehiclePart" then return p:getVehicle() == d:getVehicle() end
    return false
end

function KnoxRadioWindow:act(mode, arg)
    if self.data:canPlayerRemoteInteract(self.player) or self:walkTo() then
        ISTimedActionQueue.add(ISRadioAction:new(mode, self.player, self.device, arg))
    end
end

--- Waiting (not started) radio actions of this kind for this set leave the queue.
function KnoxRadioWindow:dropQueued(mode)
    local q = ISTimedActionQueue.getTimedActionQueue(self.player)
    if not (q and q.queue) then return end
    for i = #q.queue, 2, -1 do
        local a = q.queue[i]
        if a and a.Type == "ISRadioAction" and a.mode == mode and a.device == self.device then
            table.remove(q.queue, i)
        end
    end
end

function KnoxRadioWindow:param()
    return ISDeviceBatteryAction:getDeviceDataParameter(self.player, self.device, self.kind)
end

function KnoxRadioWindow:togglePower()
    local d = self.data
    if not self:isOn() then
        local ok = (d:getIsBatteryPowered() and d:getPower() > 0) or ((not d:getIsBatteryPowered()) and d:canBePoweredHere())
        if not ok then
            self.noPowerMs = getTimestampMs()
            return
        end
    end
    self:act("ToggleOnOff")
    getSoundManager():playUISound("UIActivateButton")
end

function KnoxRadioWindow:snap(f)
    local lo, hi = self:range()
    f = lo + math.floor((f - lo) / FREQ_STEP + 0.5) * FREQ_STEP
    return math.max(lo, math.min(hi, f))
end

function KnoxRadioWindow:tuneTo(f, now)
    if not self:isOn() or not self:tunable() then return end
    self.pendingFreq = self:snap(f)
    self.pendingFreqMs = now and 0 or getTimestampMs()
end

function KnoxRadioWindow:stepFreq(dir)
    self:tuneTo(self:freq() + dir * FREQ_STEP)
end

function KnoxRadioWindow:nudgeVolume(dir)
    if not self:isOn() then return end
    local v = math.floor(self:volume() * VOLUME_STEPS + 0.5) + dir
    v = math.max(0, math.min(VOLUME_STEPS, v))
    self.pendingVol = v / VOLUME_STEPS
    self.pendingVolMs = getTimestampMs()
end

function KnoxRadioWindow:savePreset()
    local list = self:presetList()
    if not list or list:size() >= self:maxPresets() then return end
    local f = self:freq()
    for _, p in ipairs(self:presets()) do
        if p.freq == f then return end
    end
    list:add(PresetEntry.new(channelName(f) or (mhz(f) .. " MHz"), f))
    self.presetsOf = nil
    self.data:transmitPresets()
    getSoundManager():playUISound("UIActivateButton")
end

function KnoxRadioWindow:removePreset(i)
    local p = self:presets()[i]
    local list = self:presetList()
    if not p or not list then return end
    list:remove(p.entry)
    self.presetsOf = nil
    self.data:transmitPresets()
end

-- The slots along the bottom: battery, headphones, disc.
function KnoxRadioWindow:slotAccepts(key, item)
    if not item then return false end
    local d = self.data
    if key == "battery" then return not d:getHasBattery() and item:getFullType() == "Base.Battery" end
    if key == "headphones" then
        local t = item:getFullType()
        return d:getHeadphoneType() < 0 and (t == "Base.Headphones" or t == "Base.Earbuds")
    end
    if key == "disc" then
        return not d:hasMedia() and item:isRecordedMedia() and item:getMediaType() == d:getMediaType()
    end
    return false
end

function KnoxRadioWindow:slotCandidates(key)
    local win = self
    local list = carried(self.player, function(it) return win:slotAccepts(key, it) end)
    if key == "battery" then
        table.sort(list, function(a, b) return a:getCurrentUsesFloat() > b:getCurrentUsesFloat() end)
    end
    return list
end

function KnoxRadioWindow:slotFilled(key)
    local d = self.data
    if key == "battery" then return d:getHasBattery() end
    if key == "headphones" then return d:getHeadphoneType() >= 0 end
    if key == "disc" then return d:hasMedia() end
    return false
end

function KnoxRadioWindow:slotInsert(key, item)
    if not self:slotAccepts(key, item) then return end
    if item:getWorldItem() and not luautils.walkAdj(self.player, item:getWorldItem():getSquare(), true) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, item)
    if not self:walkTo() then return end
    if key == "battery" then
        ISTimedActionQueue.add(ISDeviceBatteryAction:new(self.player, false, item, self:param()))
    elseif key == "headphones" then
        ISTimedActionQueue.add(ISRadioAction:new("AddHeadphones", self.player, self.device, item))
    elseif key == "disc" then
        ISTimedActionQueue.add(ISDeviceMediaAction:new(self.player, false, item, self:param()))
    end
end

function KnoxRadioWindow:slotRemove(key)
    if not self:slotFilled(key) or not self:walkTo() then return end
    if key == "battery" then
        ISTimedActionQueue.add(ISDeviceBatteryAction:new(self.player, true, nil, self:param()))
    elseif key == "headphones" then
        ISTimedActionQueue.add(ISRadioAction:new("RemoveHeadphones", self.player, self.device))
    elseif key == "disc" then
        ISTimedActionQueue.add(ISDeviceMediaAction:new(self.player, true, nil, self:param()))
    end
end

local SLOT_INFO = {
    battery = {tex = "Item_Battery", title = "IGUI_Knox_RadioBatteries"},
    headphones = {tex = "Item_Headphones", title = "IGUI_Knox_RadioHeadphones"},
    disc = {tex = "Item_Disc", title = "IGUI_Knox_RadioDiscs"},
}

-- Drawing -----------------------------------------------------------------------------

--- Label step for the scale: about six numbers across the band.
local function labelStep(span)
    for _, s in ipairs({500, 1000, 2000, 4000, 5000, 10000, 20000, 50000, 100000, 200000, 500000}) do
        if span / s <= 7 then return s end
    end
    return 1000000
end

function KnoxRadioWindow:freqX(f)
    local R = self.R
    local lo, hi = self:range()
    local x0, w = R.dial[1] + T.pad, R.dial[3] - T.pad * 2
    return x0 + math.floor(w * (f - lo) / math.max(1, hi - lo) + 0.5)
end

function KnoxRadioWindow:xFreq(x)
    local R = self.R
    local lo, hi = self:range()
    local x0, w = R.dial[1] + T.pad, R.dial[3] - T.pad * 2
    return lo + (hi - lo) * math.max(0, math.min(1, (x - x0) / math.max(1, w)))
end

function KnoxRadioWindow:drawDial(mx, my)
    local R = self.R
    local d = R.dial
    local on = self:isOn()
    local pad = T.pad
    T.rect(self, d[1], d[2], d[3], d[4], self.skin.dial)
    T.border(self, d[1], d[2], d[3], d[4], self.skin.dialEdge)
    -- the lamp behind the glass when it is on
    if on then self:drawRect(d[1] + 1, d[2] + 1, d[3] - 2, d[4] - 2, 0.06, AMBER.r, AMBER.g, AMBER.b) end

    local lo, hi = self:range()
    local step = labelStep(hi - lo)
    local minor = step / 5
    local sy = d[2] + math.floor(d[4] * 0.22)
    local tickH = math.floor(d[4] * 0.22)
    local a = on and 1 or 0.55
    local first = math.ceil(lo / minor) * minor
    local f = first
    while f <= hi do
        local x = self:freqX(f)
        local major = math.abs(f / step - math.floor(f / step + 0.5)) < 0.001
        local h = major and tickH or math.floor(tickH / 2)
        self:drawRect(x, sy + tickH - h, 1, h, a, SCALE.r, SCALE.g, SCALE.b)
        if major then
            local label = string.gsub(mhz(f), "%.0$", "")
            T.textCentre(self, label, x, sy + tickH + 2, SCALE, T.fontTile, a)
        end
        f = f + minor
    end

    -- saved stations: green marks over the scale (the hovered one lit)
    self.hoverMark = nil
    local ms = math.max(5, math.floor(T.cell * 0.12))
    for i, p in ipairs(self:presets()) do
        local x = self:freqX(p.freq)
        local hot = self:isMouseOver() and math.abs(mx - x) <= ms and my >= d[2] and my < sy + tickH
        if hot then self.hoverMark = i end
        local c = hot and T.color.accent or T.color.good
        self:drawRect(x - ms, sy - ms - 2, ms * 2 + 1, ms, on and 1 or 0.5, c.r, c.g, c.b)
    end

    -- the needle
    local nf = self:freq()
    local nx = self:freqX(nf)
    if on then self:drawRect(nx - 3, d[2] + 3, 7, d[4] - 6, 0.12, AMBER.r, AMBER.g, AMBER.b) end
    self:drawRect(nx - 1, d[2] + 3, 2, d[4] - 6, on and 1 or 0.5, AMBER.r, AMBER.g, AMBER.b)

    -- readout: frequency and station; signal bars on the right
    local ry = d[2] + d[4] - T.fontH(T.fontText) - 4
    if not on then
        if self.noPowerMs and getTimestampMs() - self.noPowerMs < 2500 then
            T.text(self, getText("IGUI_Knox_RadioNoPower"), d[1] + pad, ry, T.color.bad, T.fontText)
        end
        return
    end
    local name = channelName(nf)
    for _, p in ipairs(self:presets()) do
        if p.freq == nf and not name then name = p.name end
    end
    if self.hoverMark then
        local p = self:presets()[self.hoverMark]
        nf, name = p.freq, p.name
    elseif self.hoverPreset then
        local p = self:presets()[self.hoverPreset]
        if p then nf, name = p.freq, p.name end
    end
    local text = mhz(nf) .. " MHz" .. (name and ("  " .. name) or "")
    T.text(self, T.fit(text, T.fontText, d[3] - pad * 2 - 40), d[1] + pad, ry,
        (self.hoverMark or self.hoverPreset) and T.color.accent or AMBER, T.fontText)
    local receiving = self.data:isReceivingSignal()
    local bw, gap = 4, 2
    local bx = d[1] + d[3] - pad - 4 * (bw + gap)
    for i = 1, 4 do
        local h = 3 + i * 3
        local lit = receiving
        local c = lit and AMBER or SCALE
        self:drawRect(bx + (i - 1) * (bw + gap), ry + T.fontH(T.fontText) - h, bw, h, lit and 1 or 0.35, c.r, c.g, c.b)
    end
end

--- The tape's rows (wrapped lines, separators, notes), oldest first.
function KnoxRadioWindow:buildRows()
    local R = self.R
    local pad = T.pad
    local f = T.fontText
    local timeW = T.measure(f, "00:00") + 8
    local textW = R.tape[3] - pad * 2 - timeW
    local rows = {}
    local lastCh = nil
    for _, e in ipairs(self.entries) do
        if self:tunable() and e.channel ~= lastCh then
            local name = channelName(e.channel)
            table.insert(rows, {sep = mhz(e.channel) .. " MHz" .. (name and (" " .. string.char(183) .. " " .. name) or "")})
            lastCh = e.channel
        end
        local c = e.color
        local static = math.abs(c.r - c.g) < 0.02 and math.abs(c.g - c.b) < 0.02 and c.r < 0.7
        -- the speaker's color, darkened to read as ink on the paper
        local ink = static and INK_DIM or {r = c.r * 0.5, g = c.g * 0.5, b = c.b * 0.5}
        if not static and c.r + c.g + c.b > 2.6 then ink = INK end
        for i, line in ipairs(T.wrap(e.text, f, textW)) do
            table.insert(rows, {time = i == 1 and TV.clockText(e.tod) or nil, text = line, color = ink})
        end
        for _, h in ipairs(W.halos[e.seq] or {}) do
            table.insert(rows, {note = h})
        end
    end
    self.rows = rows
    self.timeW = timeW
    self.rowsDirty = false
end

function KnoxRadioWindow:drawTape(mx, my)
    local R = self.R
    local t = R.tape
    local pad = T.pad
    T.rect(self, t[1], t[2], t[3], t[4], PAPER)
    T.border(self, t[1], t[2], t[3], t[4], PAPER_EDGE)
    if self.rowsDirty then
        local before = self.rows and #self.rows or 0
        self:buildRows()
        if self.keepScroll then self.scroll = self.scroll + math.max(0, #self.rows - before) end
        self.keepScroll = false
    end
    local f = T.fontText
    local rowH = T.fontH(f) + 3
    -- ruled lines
    for ly = t[2] + pad + rowH - 2, t[2] + t[4] - 4, rowH do
        self:drawRect(t[1] + 2, ly, t[3] - 4, 1, 0.06, 0, 0, 0)
    end
    local visible = math.max(1, math.floor((t[4] - pad * 2) / rowH))
    local rows = self.rows or {}
    if #rows == 0 then
        local msg = getText("IGUI_Knox_RadioTapeEmpty")
        local lines = T.wrap(msg, f, t[3] - pad * 4)
        local yy = t[2] + math.floor((t[4] - #lines * rowH) / 2)
        for _, l in ipairs(lines) do
            T.textCentre(self, l, t[1] + math.floor(t[3] / 2), yy, INK_DIM, f)
            yy = yy + rowH
        end
        return
    end
    self.scroll = math.max(0, math.min(self.scroll, #rows - visible))
    local last = #rows - self.scroll
    local firstRow = math.max(1, last - visible + 1)
    local yy = t[2] + pad
    if last - firstRow + 1 < visible then yy = t[2] + pad + (visible - (last - firstRow + 1)) * rowH end
    local tx = t[1] + pad + self.timeW
    for i = firstRow, last do
        local r = rows[i]
        if r.sep then
            local s = "- " .. r.sep .. " -"
            T.textCentre(self, T.fit(s, f, t[3] - pad * 2), t[1] + math.floor(t[3] / 2), yy, INK_DIM, f)
        elseif r.note then
            local h = r.note
            local c = h.good and INK_GOOD or INK_BAD
            T.text(self, h.text, tx, yy, c, f)
            local s = math.floor(T.fontH(f) * 0.3)
            TV.triangle(self, tx + T.measure(f, h.text) + 6, yy + math.floor((T.fontH(f) - s) / 2), s, h.dir, c)
        else
            if r.time then T.text(self, r.time, t[1] + pad, yy, INK_DIM, f) end
            T.text(self, r.text, tx, yy, r.color, f)
        end
        yy = yy + rowH
    end
    -- scrolled back: a mark that newer lines are below
    if self.scroll > 0 then
        local s = math.floor(T.cell * 0.12)
        local cx = t[1] + t[3] - pad - s
        TV.triangle(self, cx - s, t[2] + t[4] - pad - s, s, "down", INK_DIM)
    end
end

function KnoxRadioWindow:drawPanel(mx, my)
    local R = self.R
    local over = self:isMouseOver()
    local on = self:isOn()
    local function inKnob(k) return k and (mx - k[1]) ^ 2 + (my - k[2]) ^ 2 <= k[3] ^ 2 end
    local lo, hi = self:range()
    if R.tuneKnob then
        local k = R.tuneKnob
        T.textCentre(self, T.upper(getText("IGUI_Knox_RadioTuning")), k[1], R.capY, T.color.dim, T.fontCaps)
        TV.knob(self, k[1], k[2], k[3], -2.35 + 4.7 * (self:freq() - lo) / math.max(1, hi - lo), over and on and inKnob(k))
    end
    local v = R.volKnob
    T.textCentre(self, T.upper(getText("IGUI_Knox_TVVolume")), v[1], R.capY, T.color.dim, T.fontCaps)
    local vol = self:volume()
    TV.knob(self, v[1], v[2], v[3], -2.35 + 4.7 * vol, over and on and inKnob(v))
    local vt = on and (vol <= 0.001 and getText("IGUI_Knox_TVMuted") or (math.floor(vol * VOLUME_STEPS + 0.5) .. " / " .. VOLUME_STEPS)) or "-"
    T.textCentre(self, vt, v[1], R.knobTextY, T.color.dim, T.fontText)
    if R.tuneKnob then
        T.textCentre(self, on and mhz(self:freq()) or "-", R.tuneKnob[1], R.knobTextY, T.color.dim, T.fontText)
    end

    -- station buttons; "+" saves the station tuned in
    self.hoverPreset = nil
    self.tipPanel = nil
    local cur = self:freq()
    local presets = self:presets()
    for _, b in ipairs(R.presetBtns) do
        local hot = over and inRect(mx, my, b)
        if b[5] > 0 then
            if hot then
                self.hoverPreset = b[5]
                if on then self.tipPanel = getText("IGUI_Knox_RadioForget") end
            end
            local p = presets[b[5]]
            T.button(self, b, tostring(b[5]), {hover = hot and on, active = on and p and p.freq == cur, disabled = not on, font = T.fontCaps})
        else
            T.button(self, b, "+", {hover = hot and on, disabled = not on, font = T.fontCaps})
            if hot and on then self.tipPanel = getText("IGUI_Knox_RadioSave") end
        end
    end
end

function KnoxRadioWindow:drawSlot(key, mx, my)
    local R = self.R
    local s = R.slots[key]
    local r = s.r
    local over = self:isMouseOver()
    local hot = over and inRect(mx, my, r)
    local filled = self:slotFilled(key)
    T.rect(self, r[1], r[2], r[3], r[4], T.color.cell)
    local info = SLOT_INFO[key]
    local texName = info.tex
    if key == "headphones" and self.data:getHeadphoneType() == 1 then texName = "Item_Earbuds" end
    local tex = getTexture(texName)
    local side = math.floor(r[4] * 0.8)
    if tex then
        self:drawTextureScaledAspect(tex, r[1] + math.floor((r[3] - side) / 2), r[2] + math.floor((r[4] - side) / 2),
            side, side, filled and 1 or 0.18, 1, 1, 1)
    end
    local offered = 0
    if not filled then
        local open = KnoxSlotPicker.isOpenFor(self:ref(key))
        if not KnoxDrag.isActive() and (hot or open) then
            local cands = self:slotCandidates(key)
            offered = #cands
            if hot and offered > 0 then
                local win = self
                KnoxSlotPicker.want(self:ref(key), getText(info.title), cands,
                    function(it) win:slotInsert(key, it) end, "above", self.playerNum, self, true)
            end
        end
    end
    local edge = filled and T.color.tileFrame or T.color.tileEdge
    if hot then edge = T.color.tileHover end
    if KnoxDrag.isActive() and hot then
        local ok = self:slotAccepts(key, KnoxDrag.entity.item)
        local c = ok and T.color.ok or T.color.bad
        self:drawRect(r[1], r[2], r[3], r[4], 0.22, c.r, c.g, c.b)
        edge = c
    end
    T.tileFrame(self, r[1], r[2], r[3], r[4], edge)
    if offered > 0 then T.target(self, r[1], r[2], r[3], r[4]) end
    if hot and filled then self.tip = getText("IGUI_Knox_RadioRemoveHint") end
end

function KnoxRadioWindow:drawStrip(mx, my)
    local R = self.R
    local st = R.strip
    local over = self:isMouseOver()
    local d = self.data
    local on = self:isOn()
    local fh = T.fontH(T.fontText)
    self.tip = nil
    for _, key in ipairs({"battery", "headphones", "disc"}) do
        if R.slots[key] then self:drawSlot(key, mx, my) end
    end
    -- battery charge next to its slot
    local b = R.slots.battery
    if b then
        local p = d:getHasBattery() and d:getPower() or 0
        local c = p > 0.5 and T.color.good or (p > 0.2 and T.color.warn or T.color.bad)
        T.text(self, d:getHasBattery() and (math.floor(p * 100 + 0.5) .. "%") or "-", b.textX,
            st[2] + math.floor((st[4] - fh) / 2), d:getHasBattery() and c or T.color.dim, T.fontText)
    end
    -- the disc: play / stop, eject, its title
    local s = R.slots.disc
    if s then
        local has = d:hasMedia()
        local playing = d:isPlayingMedia()
        local canPlay = has and on
        local pHot = over and inRect(mx, my, s.play) and canPlay
        T.button(self, s.play, "", {hover = pHot, disabled = not canPlay, active = playing})
        local p = s.play
        local mc = not canPlay and T.color.dim or (pHot and T.color.accent or T.color.text)
        local sz = math.floor(p[4] * 0.28)
        if playing then
            T.rect(self, p[1] + math.floor(p[3] / 2) - sz, p[2] + math.floor(p[4] / 2) - sz, sz * 2, sz * 2, mc)
        else
            TV.triangle(self, p[1] + math.floor(p[3] / 2) - math.floor(sz / 2), p[2] + math.floor(p[4] / 2) - sz + 1, sz, "right", mc)
        end
        local e = s.eject
        local eHot = over and inRect(mx, my, e) and has
        T.button(self, e, "", {hover = eHot, disabled = not has})
        local ec = not has and T.color.dim or (eHot and T.color.accent or T.color.text)
        local cx, ty = e[1] + math.floor(e[3] / 2), e[2] + math.floor(e[4] / 2) - sz
        TV.triangle(self, cx - sz + 1, ty, sz, "up", ec)
        T.rect(self, cx - sz + 1, ty + sz + 2, sz * 2 - 1, math.max(2, math.floor(sz / 3)), ec)
        if pHot then self.tip = getText(playing and "IGUI_media_stop" or "IGUI_media_play") end
        if eHot then self.tip = getText("IGUI_Knox_TVEject") end
        local md = has and d:getMediaData()
        local title = md and md:getTranslatedTitle() or getText("IGUI_media_nocd")
        if s.titleW and s.titleW > 20 then
            T.text(self, T.fit(title or "", T.fontText, s.titleW), s.titleX, st[2] + math.floor((st[4] - fh) / 2),
                md and T.color.bright or T.color.dim, T.fontText)
        end
    end
    -- microphone of a ham radio
    if R.mic then
        local live = not d:getMicIsMuted()
        T.button(self, R.mic, "", {hover = over and inRect(mx, my, R.mic), active = live})
        local m = R.mic
        local ls = math.floor(m[4] * 0.3)
        local lc = live and T.color.bad or LED_OFF
        T.rect(self, m[1] + math.floor(m[4] * 0.35), m[2] + math.floor((m[4] - ls) / 2), ls, ls, lc)
        T.text(self, T.upper(getText("IGUI_Knox_RadioMic")), m[1] + math.floor(m[4] * 0.35) + ls + 8,
            m[2] + math.floor((m[4] - T.fontH(T.fontCaps)) / 2), live and T.color.bright or T.color.text, T.fontCaps)
    end
    -- power, with its lamp
    local p = R.power
    local hot = over and inRect(mx, my, p)
    T.button(self, p, "", {hover = hot})
    local ls = math.floor(p[4] * 0.32)
    local lx, ly = p[1] + math.floor(p[4] * 0.35), p[2] + math.floor((p[4] - ls) / 2)
    local lc = on and LED_ON or LED_OFF
    if on then self:drawRect(lx - 3, ly - 3, ls + 6, ls + 6, 0.18, lc.r, lc.g, lc.b) end
    T.rect(self, lx, ly, ls, ls, lc)
    T.text(self, T.upper(getText(on and "ContextMenu_Turn_Off" or "ContextMenu_Turn_On")), lx + ls + 10,
        p[2] + math.floor((p[4] - T.fontH(T.fontCaps)) / 2), hot and T.color.accent or T.color.text, T.fontCaps)
end

function KnoxRadioWindow:drawTip(mx, my)
    local tip = self.tip or self.tipPanel
    if not tip then return end
    local tw = T.measure(T.fontText, tip) + 12
    local th = T.fontH(T.fontText) + 4
    local tx = math.min(self:getWidth() - tw - 2, mx + 12)
    local ty = my - th - 8
    T.rect(self, tx, ty, tw, th, T.color.header)
    T.border(self, tx, ty, tw, th, T.color.tileEdge)
    T.text(self, tip, tx + 6, ty + 2, T.color.text, T.fontText)
end

function KnoxRadioWindow:prerender()
    if T.unfold(self) then return end   -- opening or closing: only its plate
    if not self:validate() then return end
    KnoxSlotPicker.sync(self)
    if self.layoutKey ~= self:layoutKeyNow() then self:layout() end
    self:pollLines()
    if self.draggingDial then
        if isMouseButtonDown(0) then
            self:tuneTo(self:xFreq(self:getMouseX()))
        else
            self.draggingDial = false
            self.pendingFreqMs = 0
        end
    end
    self:flush()
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
    T.rect(self, c[1], c[2], c[3], c[4], self.skin.cab)
    T.border(self, c[1], c[2], c[3], c[4], self.skin.cabEdge)
    T.rect(self, c[1] + 1, c[2] + 1, c[3] - 2, 1, {r = 1, g = 1, b = 1}, 0.06)

    self:drawPanel(mx, my)          -- first: the hovered station shows on the dial
    if R.dial then self:drawDial(mx, my) end
    self:drawTape(mx, my)
    self:drawStrip(mx, my)
    self:drawTip(mx, my)
end

-- Input ---------------------------------------------------------------------------------

local function inKnob(x, y, k)
    return k ~= nil and (x - k[1]) ^ 2 + (y - k[2]) ^ 2 <= k[3] ^ 2
end

function KnoxRadioWindow:onMouseDown(x, y)
    if self.foldMs then return true end
    self:bringToTop()
    local R = self.R
    if inRect(x, y, R.x) then self:close() return true end
    if inRect(x, y, R.power) then self:togglePower() return true end
    if R.mic and inRect(x, y, R.mic) then
        self:act("MuteMicrophone", not self.data:getMicIsMuted())
        return true
    end
    if R.dial and inRect(x, y, R.dial) then
        if self:isOn() then
            if self.hoverMark then
                self:tuneTo(self:presets()[self.hoverMark].freq, true)
            else
                self.draggingDial = true
                self:tuneTo(self:xFreq(x))
            end
        end
        return true
    end
    if inKnob(x, y, R.tuneKnob) then self:stepFreq(1) return true end
    if inKnob(x, y, R.volKnob) then self:nudgeVolume(1) return true end
    for _, b in ipairs(R.presetBtns) do
        if inRect(x, y, b) then
            if b[5] > 0 then
                local p = self:presets()[b[5]]
                if p then self:tuneTo(p.freq, true) end
            elseif self:isOn() then
                self:savePreset()
            end
            return true
        end
    end
    local s = R.slots.disc
    if s then
        if inRect(x, y, s.play) then
            if self:isOn() and self.data:hasMedia() then self:act("TogglePlayMedia") end
            return true
        end
        if inRect(x, y, s.eject) then self:slotRemove("disc") return true end
    end
    for key, sl in pairs(R.slots) do
        if inRect(x, y, sl.r) then return true end   -- the quick pick panel does the choosing
    end
    KnoxWindowDrag.begin(self, x, y, R.headerH)
    return true
end

KnoxWindowDrag.install(KnoxRadioWindow)

local dragStop = KnoxRadioWindow.onMouseUp
function KnoxRadioWindow:onMouseUp(x, y)
    if self.draggingDial then
        self.draggingDial = false
        self.pendingFreqMs = 0   -- tune at once
    end
    -- an item dropped on a slot from a Knox grid
    if KnoxDrag and KnoxDrag.isActive() then
        for key, sl in pairs(self.R.slots) do
            if inRect(x, y, sl.r) then
                local item = KnoxDrag.entity.item
                KnoxDrag.cancel()
                self:slotInsert(key, item)
                return true
            end
        end
    end
    return dragStop(self, x, y)
end

function KnoxRadioWindow:onRightMouseUp(x, y)
    if KnoxDrag and KnoxDrag.isActive() then return true end   -- (an item is held: the button may turn it, see KnoxDragLayer)
    local R = self.R
    if inKnob(x, y, R.tuneKnob) then self:stepFreq(-1) return true end
    if inKnob(x, y, R.volKnob) then self:nudgeVolume(-1) return true end
    for _, b in ipairs(R.presetBtns) do
        if b[5] > 0 and inRect(x, y, b) then self:removePreset(b[5]) return true end
    end
    for key, sl in pairs(R.slots) do
        if inRect(x, y, sl.r) then self:slotRemove(key) return true end
    end
    return true
end

function KnoxRadioWindow:onMouseWheel(del)
    local R = self.R
    local x, y = self:getMouseX(), self:getMouseY()
    local dir = del > 0 and -1 or 1
    if inRect(x, y, R.tape) then
        self.scroll = math.max(0, self.scroll - dir * 3)
    elseif (R.dial and inRect(x, y, R.dial)) or inKnob(x, y, R.tuneKnob) then
        self:stepFreq(dir)
    else
        self:nudgeVolume(dir)
    end
    return true
end

function KnoxRadioWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function KnoxRadioWindow:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end

function KnoxRadioWindow:close()
    W.lastX, W.lastY = self:getX(), self:getY()
    if KnoxSlotPicker.instance and KnoxSlotPicker.instance.host == self then KnoxSlotPicker.close() end
    if self.pendingVol then self.pendingVolMs = 0 end
    if self.pendingFreq then self.pendingFreqMs = 0 self.draggingDial = false end
    if self.pendingVol or self.pendingFreq then self:flush() end
    T.fold(self, function(w)
        w:setVisible(false)
        w:removeFromUIManager()
    end)
    if W.instance == self then
        W.instance = nil
        if knoxHideDeviceText then knoxHideDeviceText(nil) end
    end
end

--- A skill or mood a broadcast changed: noted under the line that did it (the
--- last line the Java part kept), on whichever set's tape shows that line.
function W.noteHalo(str, amount, inverse)
    if not str or not knoxDeviceTextSeq then return end
    local seq = knoxDeviceTextSeq()
    local dir, good = "up", true
    if type(amount) == "number" and amount ~= 0 then
        dir = amount > 0 and "up" or "down"
        if inverse then good = amount > 0 else good = amount < 0 end
    end
    if not W.halos[seq] then
        -- (the oldest lines' notes go: the table no longer grows for the whole
        -- game - SΞNSΞI's report, 2026-10-28)
        table.insert(W.haloSeqs, seq)
        if #W.haloSeqs > HALO_LINES then W.halos[table.remove(W.haloSeqs, 1)] = nil end
        W.halos[seq] = {}
    end
    table.insert(W.halos[seq], {text = str, dir = dir, good = good})
    local w = W.instance
    if w then w.rowsDirty = true end
end

function W.isOpenFor(device)
    return W.instance ~= nil and W.instance.device == device
end

--- Open in place of the game's window.
function W.open(player, device)
    if W.instance then
        if W.instance.device == device then W.instance:bringToTop() return W.instance end
        W.instance:close()
    end
    local w = W:new(player, device)
    w:initialise()
    w:instantiate()
    w:setWantKeyEvents(true)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = W.lastX or math.floor((sw - w:getWidth()) / 2)
    local y = W.lastY or math.floor((sh - w:getHeight()) / 2)
    w:setX(math.max(0, math.min(sw - w:getWidth(), x)))
    w:setY(math.max(0, math.min(sh - w:getHeight(), y)))
    w:addToUIManager()
    W.instance = w
    if knoxHideDeviceText then knoxHideDeviceText(device) end
    return w
end

return KnoxRadioWindow
