-- Stand-ins for the game, KnoxTheme and the car's radio, enough to run
-- KnoxDashboard.lua outside the game (tools/dash/test.ps1): a pretend car whose
-- state the test sets, a clock it moves, a panel that only counts what it draws
-- and checks each draw's numbers and each picture's name against the files.

require = function() end
clock = 100000
function getTimestampMs() return clock end

-- the pictures there are (test.ps1 passes their names: pics="a,b,c")
local PICS = {}
for n in string.gmatch(pics or "", "[^,]+") do PICS["media/ui/knoxdash/" .. n .. ".png"] = true end
missingPics = {}
function getTexture(path)
    if PICS[path] then return {path = path} end
    missingPics[path] = true
    return nil
end
Texture = {getWhite = function() return {path = "white"} end}
UIFont = {Small = "Small", Medium = "Medium"}

-- what is drawn: counted, and checked for numbers that are not numbers; while
-- `rec` is a table, each draw is written down in it (tools/dash/snap.ps1 paints them)
draws, bad = 0, {}
rec = nil
local function f(v) return string.format("%.2f", v or 0) end
function record(kind, name, nums, c, a, extra)
    if not rec then return end
    local parts = {kind, name or "-"}
    for _, v in ipairs(nums) do table.insert(parts, f(v)) end
    table.insert(parts, f(c and c.r or 1)); table.insert(parts, f(c and c.g or 1)); table.insert(parts, f(c and c.b or 1)); table.insert(parts, f(a or 1))
    if extra then table.insert(parts, extra) end
    table.insert(rec, table.concat(parts, "|"))
end
local function num(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" and (v ~= v or v == math.huge or v == -math.huge) then return false end
    end
    return true
end
function badDraw(what, ...)
    if not num(...) then table.insert(bad, what) end
    draws = draws + 1
end

local javaObject = {DrawTexture = function(self, t, x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a)
    badDraw("DrawTexture", x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a)
    record("Q", t and string.match(t.path, "([%w_]+)%.png$") or "white", {x1, y1, x2, y2, x3, y3, x4, y4}, {r = r, g = g, b = b}, a)
end}
mouse = nil   -- {x, y} on the panel, or nil
ISPanel = {}
ISPanel.__index = ISPanel
function ISPanel:derive(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = name
    return o
end
function ISPanel:new(x, y, w, h)
    local o = {x = x, y = y, width = w, height = h, javaObject = javaObject, visible = true}
    setmetatable(o, self)
    self.__index = self
    return o
end
function ISPanel:initialise() end
function ISPanel:instantiate() end
function ISPanel:addToUIManager() self.inManager = true end
function ISPanel:removeFromUIManager() self.inManager = false end
function ISPanel:setVisible(v) self.visible = v end
function ISPanel:getIsVisible() return self.visible end
function ISPanel:setX(v) self.x = v end
function ISPanel:setY(v) self.y = v end
function ISPanel:setWidth(v) self.width = v end
function ISPanel:setHeight(v) self.height = v end
function ISPanel:addChild(c) self.children = self.children or {}; table.insert(self.children, c) end
function ISPanel:getX() return self.x end
function ISPanel:getY() return self.y end
function ISPanel:getAbsoluteX() return self.x end
function ISPanel:getAbsoluteY() return self.y end
function ISPanel:isMouseOver() return mouse ~= nil end
-- (as the game's UIElement: the clips nest, a clear takes one level off; the most
-- levels at once are kept - the test looks they never pile up)
stencil, stencilMax = 0, 0
function ISPanel:setStencilRect(x, y, w, h) stencil = stencil + 1; stencilMax = math.max(stencilMax, stencil) end
function ISPanel:clearStencilRect() if stencil > 0 then stencil = stencil - 1 end end
function ISPanel:repaintStencilRect(x, y, w, h) if stencil <= 0 then table.insert(bad, "repaintStencilRect with no clip") end end
function ISPanel:getMouseX() return mouse and mouse[1] or -1 end
function ISPanel:getMouseY() return mouse and mouse[2] or -1 end
function ISPanel:drawTextureScaled(t, x, y, w, h, a, r, g, b)
    if not t then table.insert(bad, "drawTextureScaled without a picture") end
    badDraw("drawTextureScaled", x, y, w, h, a, r, g, b)
    record("P", t and string.match(t.path, "([%w_]+)%.png$") or "?", {self.x + x, self.y + y, w, h}, {r = r, g = g, b = b}, a)
end
function ISPanel:drawRect(x, y, w, h, a, r, g, b)
    badDraw("drawRect", x, y, w, h, a, r, g, b)
    record("R", nil, {self.x + x, self.y + y, w, h}, {r = r, g = g, b = b}, a)
end
function ISPanel:drawRectBorder(x, y, w, h, a, r, g, b) badDraw("drawRectBorder", x, y, w, h, a, r, g, b) end
ISUIHandler = {allUIVisible = true}
buttonDown = false
function isMouseButtonDown(b) return b == 0 and buttonDown end

-- KnoxTheme: the parts the dashboard uses; the layout kit checks its arguments
-- and remembers each band (the test looks whether they stay on the panel)
labels = {}
local function hex(h)
    local n = tonumber(string.sub(h, 2), 16)
    return {r = math.floor(n / 65536) / 255, g = math.floor(n / 256) % 256 / 255, b = n % 256 / 255}
end
-- (Knox's default skin, KnoxTheme)
KnoxTheme = {
    cell = 48, pad = 12, javaFonts = false, settings = {},
    color = {window = hex("#121414"), header = hex("#1a1d1d"), border = hex("#2a2e2e"), cell = hex("#0e1010"), tileEdge = hex("#3c4141"),
        text = hex("#d9d6c8"), bright = hex("#ece8d8"), dim = hex("#8f9289"), accent = hex("#d4c38a"), bad = hex("#be463c"),
        good = hex("#9fb36a"), warn = hex("#c9a24a"), ink = hex("#141414"), screen = hex("#0b0c0c")},
    fontText = "Small", fontTile = "Small", fontHeader = "Medium",
}
local T = KnoxTheme
function T.ensure() end
function T.animOn() return true end
function T.anim(t) return t end
function T.fontH(f) return 14 end
function T.measure(f, s) return #(s or "") * 7 end
function T.fit(s) return s end
function T.wrap(s, f, w) return {s} end
function T.makeFont(style, px) return {style = style, size = px} end
local function color(c) return type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" end
function T.label(ui, s, r, c, o)
    if type(s) ~= "string" or type(r) ~= "table" or #r ~= 4 or not color(c) or type(o) ~= "table" then
        table.insert(bad, "T.label " .. tostring(s))
    end
    badDraw("T.label", r[1], r[2], r[3], r[4], o.a)
    table.insert(labels, {s = s, x = r[1], y = r[2], w = r[3], h = r[4], tip = inTip})
    local size = type(o.font) == "table" and o.font.size or 12
    record("L", s, {ui.x + r[1], ui.y + r[2], r[3], r[4], size}, c, o.a, (o.align or "left") .. "|" .. (type(o.font) == "table" and o.font.style or "body"))
    return T.measure(o.font, s)
end
-- (as KnoxTheme draws them: through the element's drawRect)
function T.rect(ui, x, y, w, h, c, a)
    if not color(c) then table.insert(bad, "T.rect colour") return end
    ui:drawRect(x, y, w, h, a or 1, c.r, c.g, c.b)
end
function T.border(ui, x, y, w, h, c, a)
    T.rect(ui, x, y, w, 1, c, a); T.rect(ui, x, y + h - 1, w, 1, c, a)
    T.rect(ui, x, y + 1, 1, h - 2, c, a); T.rect(ui, x + w - 1, y + 1, 1, h - 2, c, a)
end
function T.tileFrame(ui, x, y, w, h, c, a)
    if not color(c) then table.insert(bad, "T.tileFrame colour") return end
    T.rect(ui, x, y, w, 2, c, a); T.rect(ui, x, y + h - 2, w, 2, c, a)
    T.rect(ui, x, y + 2, 2, h - 4, c, a); T.rect(ui, x + w - 2, y + 2, 2, h - 4, c, a)
end
function T.rollNumber(ui, st, s, x, y, w, h, r, g, b, a, font)
    if type(st) ~= "table" or type(s) ~= "string" then table.insert(bad, "T.rollNumber " .. tostring(s)) end
    st.text = s
    badDraw("T.rollNumber", x, y, w, h, r, g, b, a)
    record("L", s, {ui.x + x, ui.y + y, w, h, type(font) == "table" and font.size or 12}, {r = r, g = g, b = b}, a, "centre|title")
end
function T.inkLeft(ui, s, x, y, h, c, font, a)
    badDraw("T.inkLeft", x, y, h, a)
    record("L", s, {ui.x + x, ui.y + y, 400, h, type(font) == "table" and font.size or 14}, c, a, "left|title")
    return 10
end
function T.text(ui, s, x, y, c, font, a)
    badDraw("T.text", x, y, a)
    local size = type(font) == "table" and font.size or 14
    record("L", s, {ui.x + x, ui.y + y, 400, size * 1.25, size}, c, a, "left|" .. (type(font) == "table" and font.style or "body"))
end
function T.textRight(ui, s, x, y, c, font, a)
    badDraw("T.textRight", x, y, a)
    local size = type(font) == "table" and font.size or 14
    record("L", s, {ui.x + x - 400, ui.y + y, 400, size * 1.25, size}, c, a, "right|" .. (type(font) == "table" and font.style or "body"))
end

-- the player's music and the car's radio (KnoxMenuMusic, KnoxCarRadio)
radio = {has = true, on = true, power = true, theme = "game", channel = 98200, vol = 0.6, shuffle = false, rpt = "all",
    playing = false, mine = true, calls = {}}
local function said(what) table.insert(radio.calls, what) end
KnoxMenuMusic = {at = 0, list = {}}
local MM = KnoxMenuMusic
function MM.carHas() return radio.has end
function MM.carOn() return radio.has and radio.on end
function MM.carAllowed() return radio.has and radio.on and radio.power end
function MM.theme() return radio.theme end
function MM.carChannel() return radio.channel end
function MM.vol() return radio.vol end
function MM.shuffleOn() return radio.shuffle end
function MM.repeatMode() return radio.rpt end
function MM.stations() return radio.theme == "game" end
function MM.available(id) return radio.mine end
function MM.carTitle() return "98.2   Station" end
function MM.choose(v) radio.theme = string.match(v, "^mine") and "mine" or "game"; T.settings["car.music"] = v; said("choose " .. v) end
function MM.next() said("next") end
function MM.prev() said("prev") end
function MM.play(i) said("play " .. i) end
function MM.setVol(v) radio.vol = v; said("vol") end
function MM.carTune(f) radio.channel = f; said("tune " .. f) end
function MM.toggleShuffle() radio.shuffle = not radio.shuffle; said("shuffle") end
function MM.cycleRepeat() said("repeat") end
function MM.carBroadcastToggle() radio.on = not radio.on; said("power") end
function MM.carOpenWindow() said("window") end
KnoxCarRadio = {}
function KnoxCarRadio.ensure() end
function KnoxCarRadio.enter() end
function KnoxCarRadio.leave() end
function KnoxCarRadio.musicPlaying() return radio.playing end
function KnoxCarRadio.data()
    return {getChannel = function() return radio.channel end, getMinChannelRange = function() return 88000 end,
        getMaxChannelRange = function() return 108000 end}
end
cardTracks = 0
KnoxRadioCard = {track = function(r, over) if over then cardTracks = cardTracks + 1 end end, hide = function() end}
knoxMusicLength = function() return 200000 end
knoxMusicPosition = function() return 50000 end
knoxMusicSeek = function(ms) said("seek " .. math.floor(ms)) end

-- the game
gameCalls = {}
ISVehicleDashboard = {}
for _, fn in ipairs({"onClickHeadlights", "onClickDoors", "onClickTrunk", "onClickEngine", "onClickKeys", "onClickHeater", "onClickRadio"}) do
    ISVehicleDashboard[fn] = function(self) table.insert(gameCalls, fn) end
end
function ISVehicleDashboard:setVehicle(v) end
commands = {}
function sendClientCommand(player, module, command, args) table.insert(commands, {command = command, on = args.on, temp = args.temp}) end
function getGameSpeed() return 1 end
local sounds = {playUISound = function() end}
function getSoundManager() return sounds end
function getPlayerScreenLeft() return 0 end
function getPlayerScreenTop() return 0 end
screenW, screenH = 1920, 1080
function getPlayerScreenWidth() return screenW end
function getPlayerScreenHeight() return screenH end
BaseVehicle = {getFakeSpeedModifier = function() return 1.6 end}
daylight = 1
function getClimateManager() return {getDayLightStrength = function() return daylight end} end
function getCore() return {getKey = function() return 17 end, getScreenWidth = function() return screenW end} end
Keyboard = {KEY_LSHIFT = 42, getKeyName = function(k) return "K" .. k end}
KeybindId = {FORWARD = 1, BACKWARD = 2}
function getText(k, ...) return k end
function ZombRand(n) return math.floor(n / 2) end
function ZombRandFloat(a, b) return (a + b) / 2 end
VehicleUtils = {callLua = function() return true end}
Knox = {forPlayer = function() return true end}

--- A pretend car: `c` holds what it says (the test changes it between frames).
function makeCar(name, c)
    local car = {c = c}
    local parts = {
        GasTank = {isContainer = function() return true end, getContainerContentType = function() return "Gasoline" end,
            getContainerContentAmount = function() return c.fuel * 60 end, getContainerCapacity = function() return 60 end,
            getArea = function() return "GasTank" end},
        Engine = {getCondition = function() return 80 end},
        Battery = {getInventoryItem = function() return {} end},
    }
    if c.heater then parts.Heater = {getModData = function() return c.heaterMd end} end
    if c.trunk then parts.TruckBed = {} end
    car.getScript = function() return {getName = function() return name end, getGearRatioCount = function() return c.gears or 5 end} end
    car.getPartById = function(_, id) return parts[id] end
    car.getPartCount = function() return 0 end
    car.isKeysInIgnition = function() return c.keyIn end
    car.isHotwired = function() return c.hot end
    car.isEngineRunning = function() return c.running end
    car.isStarting = function() return c.starting end
    car.isEngineStarted = function() return c.starting or c.running end
    car.getRemainingFuelPercentage = function() return c.fuel * 100 end
    car.getCurrentSpeedKmHour = function() return c.kmh / 1.6 end
    car.getEngineSpeed = function() return c.rpm end
    car.getTransmissionNumberLetter = function() return c.gear end
    car.getBatteryCharge = function() return 0.9 end
    car.isRegulator = function() return c.cruise > 0 end
    car.getRegulatorSpeed = function() return c.cruise end
    car.leftSideFuel = function() return true end
    car.rightSideFuel = function() return false end
    car.getHeadlightsOn = function() return c.lights end
    car.getHeadlightCanEmmitLight = function() return true end
    car.areAllDoorsLocked = function() return c.doors == "all" end
    car.isAnyDoorLocked = function() return c.doors ~= nil end
    car.isTrunkLocked = function() return c.trunkLocked end
    car.windowsOpen = function() return c.window and 1 or 0 end
    car.getKeyId = function() return 7 end
    return car
end
player = {playSound = function() end, getInventory = function() return {haveThisKeyId = function() return true end} end}
