-- Stand-ins for the game and KnoxTheme, enough to run KnoxGenerator.lua and
-- KnoxGeneratorWindow.lua outside the game (tools/gen/test.ps1): a pretend generator
-- whose state the test sets, a clock it moves, a panel that counts what it draws and
-- checks each draw's numbers and each picture's name against the files.

require = function() end
clock = 1792000000123   -- (a real timestamp: Kahlua's % breaks on numbers this big)
function getTimestampMs() return clock end

local PICS = {}
for n in string.gmatch(pics or "", "[^,]+") do PICS["media/ui/knoxgen/" .. n .. ".png"] = true end
PICS["media/ui/knoxdash/bar.png"] = true
PICS["media/ui/knoxdash/soft.png"] = true
missingPics = {}
function getTexture(path)
    if PICS[path] then return {path = path, isReady = function() return true end} end
    missingPics[path] = true
    return nil
end
UIFont = {Small = "Small", Medium = "Medium"}

draws, bad, texts = 0, {}, {}
-- while `rec` is a table, each draw is written down in it, in screen pixels
-- (tools/gen/snap.ps1 paints them: the pictures, and the letters from Knox's atlases)
rec = nil
local function f2(v) return string.format("%.2f", v or 0) end
function record(...)
    if not rec then return end
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = type(v) == "number" and f2(v) or tostring(v)
    end
    table.insert(rec, table.concat(parts, "|"))
end
local function picName(t) return t and string.match(t.path, "([%w_]+)%.png$") or "?" end
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
    if not t then table.insert(bad, "DrawTexture without a picture") end
    badDraw("DrawTexture", x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a)
    record("Q", picName(t), x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a)
end}
mouse = nil
buttonDown = false
function isMouseButtonDown(b) return b == 0 and buttonDown end
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
function ISPanel:setAlwaysOnTop() end
function ISPanel:setWantKeyEvents() end
function ISPanel:bringToTop() end
function ISPanel:setX(v) self.x = v end
function ISPanel:setY(v) self.y = v end
function ISPanel:setWidth(v) self.width = v end
function ISPanel:setHeight(v) self.height = v end
function ISPanel:getX() return self.x end
function ISPanel:getY() return self.y end
function ISPanel:getWidth() return self.width end
function ISPanel:getHeight() return self.height end
function ISPanel:getAbsoluteX() return self.x end
function ISPanel:getAbsoluteY() return self.y end
function ISPanel:getXScroll() return 0 end
function ISPanel:getYScroll() return 0 end
function ISPanel:isMouseOver() return mouse ~= nil end
function ISPanel:getMouseX() return mouse and mouse[1] or -1 end
function ISPanel:getMouseY() return mouse and mouse[2] or -1 end
stencil, stencilMax = 0, 0
function ISPanel:setStencilRect(x, y, w, h)
    stencil = stencil + 1; stencilMax = math.max(stencilMax, stencil)
    record("S", self.x + x, self.y + y, w, h)
end
function ISPanel:clearStencilRect() if stencil > 0 then stencil = stencil - 1 end record("C") end
function ISPanel:repaintStencilRect(x, y, w, h) if stencil <= 0 then table.insert(bad, "repaintStencilRect with no clip") end end   -- (paints the outer level back: no change of the clip)
function ISPanel:addChild(c) self.children = self.children or {} table.insert(self.children, c) end
function ISPanel:drawTextureScaled(t, x, y, w, h, a, r, g, b)
    if not t then table.insert(bad, "drawTextureScaled without a picture") end
    badDraw("drawTextureScaled", x, y, w, h, a, r, g, b)
    record("P", picName(t), self.x + x, self.y + y, w, h, r, g, b, a)
end
function ISPanel:drawRect(x, y, w, h, a, r, g, b)
    badDraw("drawRect", x, y, w, h, a, r, g, b)
    record("R", self.x + x, self.y + y, w, h, r, g, b, a)
end
function ISPanel:drawRectBorder(x, y, w, h, a, r, g, b)
    badDraw("drawRectBorder", x, y, w, h, a, r, g, b)
    record("R", self.x + x, self.y + y, w, 1, r, g, b, a); record("R", self.x + x, self.y + y + h - 1, w, 1, r, g, b, a)
    record("R", self.x + x, self.y + y, 1, h, r, g, b, a); record("R", self.x + x + w - 1, self.y + y, 1, h, r, g, b, a)
end

-- KnoxTheme: the parts the window uses; text is measured as Knox's fonts about are
local function hex(h)
    local n = tonumber(string.sub(h, 2), 16)
    return {r = math.floor(n / 65536) / 255, g = math.floor(n / 256) % 256 / 255, b = n % 256 / 255}
end
KnoxTheme = {
    cell = 48, pad = 12, javaFonts = true, settings = {},
    color = {window = hex("#121414"), header = hex("#1a1d1d"), border = hex("#2a2e2e"), cell = hex("#0e1010"), tileEdge = hex("#3c4141"),
        hoverEdge = hex("#6a6f6a"), text = hex("#d9d6c8"), bright = hex("#ece8d8"), dim = hex("#8f9289"), accent = hex("#d4c38a"),
        bad = hex("#be463c"), ok = hex("#6ca050"), good = hex("#9fb36a"), warn = hex("#c9a24a"), ink = hex("#141414"), screen = hex("#0b0c0c")},
}
local T = KnoxTheme
function T.readyTex(path) return getTexture(path) end   -- (the real one: once read)
function T.ensure() end
function T.makeFont(style, px)
    local size = math.max(10, math.min(44, math.floor(px + 0.5)))
    return {knox = true, style = style, size = size, key = style .. "_" .. size}
end
function T.gameFontUpTo() return "Small" end
-- (the atlases are read here at once: the window lays its captions out again only while one is not)
function knoxFontReady() return true end
-- Knox's atlases' own numbers (media/fonts/knox/<style>_<size>.fnt), as the Java part
-- reads them: widths by advance, the ink by each letter's cell (the Java part trims the
-- cells to their pixels - a pixel or so less here)
local FNT = {}
local function fnt(f)
    local key = type(f) == "table" and f.key or "body_12"
    local d = FNT[key]
    if d then return d end
    d = {chars = {}, line = 15}
    local src = readfile(root .. "/42/media/fonts/knox/" .. key .. ".fnt") or ""
    d.line = tonumber(string.match(src, "lineHeight=(%d+)")) or 15
    for id, w, h, xo, yo, xa in string.gmatch(src, "char id=(%d+) x=%d+ y=%d+ width=(%d+) height=(%d+) xoffset=(%-?%d+) yoffset=(%-?%d+) xadvance=(%d+)") do
        d.chars[tonumber(id)] = {w = tonumber(w), h = tonumber(h), xo = tonumber(xo), yo = tonumber(yo), xa = tonumber(xa)}
    end
    FNT[key] = d
    return d
end
function T.fontH(f) return fnt(f).line end
function T.measure(f, s)
    local d, w = fnt(f), 0
    for i = 1, #(s or "") do
        local c = d.chars[string.byte(s, i)]
        if c then w = w + c.xa end
    end
    return w
end
function T.inkBox(f, s)
    local d = fnt(f)
    local pen, l, t, r, b = 0, 1e9, 1e9, -1e9, -1e9
    for i = 1, #(s or "") do
        local c = d.chars[string.byte(s, i)]
        if c then
            if c.w > 0 and c.h > 0 and string.byte(s, i) ~= 32 then
                l, r = math.min(l, pen + c.xo), math.max(r, pen + c.xo + c.w)
                t, b = math.min(t, c.yo), math.max(b, c.yo + c.h)
            end
            pen = pen + c.xa
        end
    end
    if r < l then return 0, 0, T.measure(f, s), T.fontH(f) end
    return l, t, r, b
end
function T.drawText(ui, s, x, y, r, g, b, a, font)
    badDraw("drawText", x, y, r, g, b, a)
    table.insert(texts, {s = s, x = x, y = y, a = a})
    if type(font) == "table" then record("T", font.key, ui.x + x, ui.y + y, r, g, b, a, s) end
end
function T.inRect(x, y, r) return x >= r[1] and y >= r[2] and x < r[1] + r[3] and y < r[2] + r[4] end
local function color(c) return type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" end
function T.rect(ui, x, y, w, h, c, a)
    if not color(c) then table.insert(bad, "T.rect colour") return end
    ui:drawRect(x, y, w, h, a or 1, c.r, c.g, c.b)
end
function T.border(ui, x, y, w, h, c, a)
    T.rect(ui, x, y, w, 1, c, a); T.rect(ui, x, y + h - 1, w, 1, c, a)
    T.rect(ui, x, y + 1, 1, h - 2, c, a); T.rect(ui, x + w - 1, y + 1, 1, h - 2, c, a)
end
function T.tileFrame(ui, x, y, w, h, c, a) T.border(ui, x, y, w, h, c, a) end
closeDrawn = nil
function T.closeButton(ui, x, y, s, hover)
    closeDrawn = {x, y, s}
    badDraw("closeButton", x, y, s)
    local c = hover and T.color.accent or T.color.text
    T.border(ui, x, y, s, s, hover and T.color.accent or T.color.tileEdge)
    local m = math.floor(s / 3)
    for i = 0, s - 2 * m - 2 do
        ui:drawRect(x + m + i, y + m + i, 2, 2, 1, c.r, c.g, c.b)
        ui:drawRect(x + s - m - 2 - i, y + m + i, 2, 2, 1, c.r, c.g, c.b)
    end
end
tipDrawn = nil
function T.plate(ui, r, s, o)
    if type(s) ~= "string" or #r ~= 4 or not color(o.color) then table.insert(bad, "T.plate " .. tostring(s)) end
    tipDrawn = s
    badDraw("T.plate", r[1], r[2], r[3], r[4])
    T.rect(ui, r[1], r[2], r[3], r[4], o.fill)
    T.border(ui, r[1], r[2], r[3], r[4], o.edge)
    if o.thick then T.border(ui, r[1] + 1, r[2] + 1, r[3] - 2, r[4] - 2, o.edge) end
    -- (as T.label: by the pixels sideways, by a capital up and down)
    local l, _, rr = T.inkBox(o.font, s)
    local _, top, _, bottom = T.inkBox(o.font, "H")
    T.drawText(ui, s, r[1] + math.floor((r[3] - (rr - l)) / 2 + 0.5) - l, r[2] + math.floor((r[4] - (bottom - top)) / 2 + 0.5) - top,
        o.color.r, o.color.g, o.color.b, 1, o.font)
end
function T.lower(s) return s and string.lower(s) end
function T.mod(a, n) return a - math.floor(a / n) * n end
function T.unfold() return false end
function T.fold(win, finish) finish(win) end

KnoxWindowDrag = {}
function KnoxWindowDrag.begin(win, x, y, h) win.knoxMove = {} return true end
function KnoxWindowDrag.install(c)
    c.onMouseMove = function() return true end
    c.onMouseMoveOutside = function() return true end
    c.onMouseUp = function(self) self.knoxMove = nil return true end
    c.onMouseUpOutside = function(self) self.knoxMove = nil return true end
end

-- the game
rand = 0.99
function ZombRandFloat(a, b) return a + (b - a) * rand end
function isClient() return false end
function isServer() return false end
Fluid = {Petrol = "Petrol", Water = "Water"}
Keyboard = {KEY_ESCAPE = 1}
screenW, screenH = 1920, 1080
function getCore() return {getScreenWidth = function() return screenW end, getScreenHeight = function() return screenH end} end
Events = {OnGameStart = {Add = function(f) onGameStart = f end}, OnClientCommand = {Add = function() end}, OnServerCommand = {Add = function() end},
    OnFillWorldObjectContextMenu = {Add = function(f) onFillMenu = f end}, OnObjectLeftMouseButtonUp = {Add = function(f) onLeftClick = f end}}
function instanceof(o, c) return type(o) == "table" and o.class == c end
function getSpecificPlayer() return player end
luautils = {walkAdj = function() return true end}
Knox = {forPlayer = function() return true end}
queue = {}
ISTimedActionQueue = {add = function(a) table.insert(queue, a) end, getTimedActionQueue = function() return {queue = queue} end}
-- the game's base action, as much of it as KnoxGeneratorUse touches
ISBaseTimedAction = {}
ISBaseTimedAction.__index = ISBaseTimedAction
function ISBaseTimedAction:derive(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = name
    return o
end
function ISBaseTimedAction.new(class, character)
    local o = {character = character}
    setmetatable(o, class)
    class.__index = class
    return o
end
function ISBaseTimedAction:perform() for i, a in ipairs(queue) do if a == self then table.remove(queue, i) break end end end
function ISBaseTimedAction:stop() for i, a in ipairs(queue) do if a == self then table.remove(queue, i) break end end end
function ISBaseTimedAction:forceComplete() self.completed = true end
function ISBaseTimedAction:setActionAnim(a) self.anim = a end
function ISBaseTimedAction:setOverrideHandModels(p, s) self.hands = p end
ISActivateGenerator = ISBaseTimedAction:derive("ISActivateGenerator")
function ISActivateGenerator:new(character, generator, activate)
    local o = ISBaseTimedAction.new(self, character)
    o.generator, o.activate = generator, activate
    return o
end
function ISActivateGenerator:complete()
    self.generator:setActivated(self.activate)
    return true
end
ISGeneratorInfoAction = {perform = function() end, new = function(_, p, gen) return {Type = "ISGeneratorInfoAction", object = gen} end}
Perks = {Electricity = "Electricity"}
perk, knowsGenerator = 3, false

--- A pretend generator: `g` holds its state.
function makeGen(g)
    local md = {}
    local o = {g = g}
    o.getMaxFuel = function() return 10 end
    o.getFuel = function() return g.fuel end
    o.setFuel = function(_, v) g.fuel = v end
    o.isActivated = function() return g.on end
    o.setActivated = function(_, v) g.on = v end
    o.failToStart = function() g.failed = (g.failed or 0) + 1 end
    o.sync = function() end
    o.getCondition = function() return g.cond end
    o.setCondition = function(_, v) g.cond = v end
    o.isConnected = function() return g.conn end
    o.setConnected = function(_, v) g.conn = v end
    o.getTotalPowerUsing = function() return g.on and g.use or 0.02 end
    o.getItemsPowered = function()
        local list = g.items or {}
        return {size = function() return #list end, get = function(_, i) return list[i + 1] end}
    end
    o.getModData = function() return md end
    o.transmitModData = function() end
    o.getObjectIndex = function() return g.gone and -1 or 3 end
    o.getSquare = function() return {isOutside = function() return not g.inside end, getBuilding = function() return g.inside and {} or nil end,
        getX = function() return 10 end, getY = function() return 10 end, getZ = function() return 0 end} end
    o.class = "IsoGenerator"
    o.getX = function() return 10 end
    o.getY = function() return 10 end
    return o
end
cans = {}
sounds, stopped = {}, nil
player = {
    vars = {},
    getPlayerNum = function() return 0 end,
    isDead = function() return false end,
    DistTo = function() return playerDist or 1 end,
    getPrimaryHandItem = function() return nil end,
    getSecondaryHandItem = function() return nil end,
    getVehicle = function() return nil end,
    getPerkLevel = function() return perk end,
    isRecipeActuallyKnown = function(_, r) return r == "Generator" and knowsGenerator end,
    playSound = function(_, name) table.insert(sounds, name) return name end,
    stopOrTriggerSound = function(_, s) stopped = s end,
    SetVariable = function(self, k, v) self.vars[k] = v end,
    faceThisObject = function() end,
    shouldBeTurning = function() return false end,
    getInventory = function()
        return {
            getAllEvalRecurse = function(_, f)
                local out = {}
                for _, c in ipairs(cans) do if f(c) then table.insert(out, c) end end
                return {size = function() return #out end, get = function(_, i) return out[i + 1] end}
            end,
            getItemWithIDRecursiv = function(_, id)
                for _, c in ipairs(cans) do if c.id == id then return c end end
                return nil
            end,
            containsRecursive = function(_, item)
                for _, c in ipairs(cans) do if c == item then return true end end
                return false
            end,
        }
    end,
}
--- A can of `fluid` holding `amount` litres, its id `id`.
function makeCan(fluid, amount, id)
    local can = {amount = amount, id = id or 0}
    local fc = {contains = function(_, f) return f == fluid end, getAmount = function() return can.amount end,
        adjustAmount = function(_, v) can.amount = v end}
    can.getFluidContainer = function() return fc end
    can.getID = function() return can.id end
    can.syncItemFields = function() end
    can.getStaticModel = function() return "GasCan" end
    return can
end
-- the menu's sounds (the news' demo plays the generator's through them)
uiSounds = {}
function getSoundManager()
    return {playUISound = function(_, name) table.insert(uiSounds, name) return #uiSounds end, stopUISound = function() end}
end
