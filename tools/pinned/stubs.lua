-- What the pinned post's files touch (KnoxNews, KnoxNewsBack, KnoxRoadmap, KnoxPinned),
-- outside the game (tools/pinned/test.ps1): the news file read from the mod, the theme's
-- kit as far as sizes go, a ui that counts what is drawn and checks its clips.
require = function() end

clock = 100000
function getTimestampMs() return clock end
TEXTS = {IGUI_Knox_NewsFile = "news_" .. (lang or "ru") .. ".txt"}
function getText(key, a) local t = TEXTS[key] or key if a then t = t .. " " .. tostring(a) end return t end
function getTextOrNull(key) return TEXTS[key] end
TEXTURES = {}
function getTexture(path)
    local t = TEXTURES[path]
    if not t then
        t = {path = path, getWidth = function() return 912 end, getHeight = function() return 245 end, isReady = function() return true end}
        TEXTURES[path] = t
    end
    return t
end
local seed = 7
function ZombRandFloat(a, b) seed = (seed * 1103515245 + 12345) % 2147483648 return a + (b - a) * seed / 2147483648 end
function knoxFontReady() return true end
OPENED = {}
function knoxOpenUrl(u) table.insert(OPENED, u) return true end
SOUNDS = 0
function getSoundManager() return {playUISound = function() SOUNDS = SOUNDS + 1 end} end

-- the mod's files, read from the mod folder (mod= the folder)
function getModFileReader(id, path)
    local text = readfile(mod .. "/42/" .. path)
    if not text then return nil end
    local lines, i = {}, 0
    for l in string.gmatch(text, "([^\n]*)\n?") do table.insert(lines, l) end
    return {readLine = function() i = i + 1 return lines[i] end, close = function() end}
end
function getFileReader() return nil end
function getFileWriter() return {write = function() end, close = function() end} end

ISPanel = {}
ISPanel.__index = ISPanel
function ISPanel:derive(name) local o = setmetatable({Type = name}, self) self.__index = self return o end

-- the theme
KnoxTheme = {cell = 48, javaFonts = true, MOD_ID = "KnoxInventory", settings = {},
             fontHeader = {size = 20}, fontText = {size = 16}, fontTile = {size = 14}, fontTab = {size = 15}, fontCaps = {size = 14}}
local T = KnoxTheme
local function rgb(v) return {r = v, g = v, b = v} end
T.color = setmetatable({}, {__index = function(t, k) local c = rgb(0.5) rawset(t, k, c) return c end})
SAVED = 0
function T.saveSettings() SAVED = SAVED + 1 end
function T.animOn() return true end
function T.mod(a, b) return a - math.floor(a / b) * b end
function T.makeFont(style, size) return {style = style, size = math.floor(size + 0.5)} end
function T.measure(f, s) return string.len(s or "") * 7 end
function T.fontH() return 16 end
function T.upper(s) return string.upper(s) end
function T.fit(s) return s end
function T.inRect(x, y, r) return x >= r[1] and y >= r[2] and x < r[1] + r[3] and y < r[2] + r[4] end
function T.wrap(s, f, w)
    local out, line = {}, ""
    for word in string.gmatch(s or "", "%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if line ~= "" and T.measure(f, try) > w then table.insert(out, line) line = word else line = try end
    end
    if line ~= "" then table.insert(out, line) end
    return out
end
DRAWN = {rect = 0, label = 0, tex = 0}
local function num(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" and v ~= v then error("NaN in a draw call (arg " .. i .. ")") end
    end
end
function T.rect(ui, x, y, w, h) num(x, y, w, h) DRAWN.rect = DRAWN.rect + 1 end
function T.border(ui, x, y, w, h) num(x, y, w, h) DRAWN.rect = DRAWN.rect + 1 end
function T.tileFrame(ui, x, y, w, h) num(x, y, w, h) DRAWN.rect = DRAWN.rect + 1 end
local function text(s, r)
    assert(type(s) == "string", "a label of " .. type(s))
    assert(type(r) == "table" and #r == 4, "a label without its rect")
    num(r[1], r[2], r[3], r[4])
    DRAWN.label = DRAWN.label + 1
end
function T.label(ui, s, r) text(s, r) return T.measure(nil, s) end
function T.spaced(ui, s, r) text(s, r) return T.measure(nil, s) end
function T.plate(ui, r, s) text(s, r) end
UNREAD = {}
local function drawnTex(tex)
    DRAWN.tex = DRAWN.tex + 1
    if READY == false then local k = tex and tex.path or "nil" UNREAD[k] = (UNREAD[k] or 0) + 1 end
end
function T.quad(ui, tex, ...) num(...) drawnTex(tex) end
-- (the real ones: one clip at a time)
function T.clip(ui, x, y, w, h)
    num(x, y, w, h)
    if ui.knoxClip then ui:clearStencilRect() end
    ui:setStencilRect(x, y, math.max(0, w), math.max(0, h))
    ui.knoxClip = true
end
function T.unclip(ui) if ui.knoxClip then ui:clearStencilRect() ui.knoxClip = nil end end

-- a ui: what it draws counted, its clips never nested
MOUSE = {x = -1, y = -1, down = false}
function isMouseButtonDown(b) return b == 0 and MOUSE.down end
STENCIL = {level = 0, nested = 0, left = 0}
UI = {knoxClip = nil, javaObject = {DrawTexture = function(self, tex, ...) num(...) drawnTex(tex) end,
    -- (a part of a picture: inside the picture, and a rect on screen)
    DrawSubTextureRGBA = function(self, tex, sx, sy, sw, sh, x, y, w, h, ...)
        num(sx, sy, sw, sh, x, y, w, h, ...)
        assert(sx >= -0.001 and sy >= -0.001 and sw > 0 and sh > 0 and sx + sw <= tex:getWidth() + 0.001
            and sy + sh <= tex:getHeight() + 0.001 and w > 0 and h > 0, "a part outside its picture")
        drawnTex(tex)
    end}}
function UI:drawRect(x, y, w, h) num(x, y, w, h) DRAWN.rect = DRAWN.rect + 1 end
function UI:drawRectBorder(x, y, w, h) num(x, y, w, h) DRAWN.rect = DRAWN.rect + 1 end
function UI:drawTextureScaled(tex, x, y, w, h) assert(tex, "no texture") num(x, y, w, h) drawnTex(tex) end
function UI:setStencilRect() if STENCIL.level > 0 then STENCIL.nested = STENCIL.nested + 1 end STENCIL.level = STENCIL.level + 1 end
function UI:clearStencilRect() if STENCIL.level > 0 then STENCIL.level = STENCIL.level - 1 end end
function UI:getMouseX() return MOUSE.x end
function UI:getMouseY() return MOUSE.y end
function UI:isMouseOver() return MOUSE.x >= 0 end
function UI:getAbsoluteX() return 0 end
function UI:getAbsoluteY() return 0 end

-- the reader (KnoxMenuNews): what its opening and closing touch
MainScreen = {}
local evt = function() return {Add = function() end, Remove = function() end} end
Events = setmetatable({}, {__index = function(t, k) local e = evt() rawset(t, k, e) return e end})
function getCore() return {getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end} end
function T.ensure() end
function ISPanel:new(x, y, w, h) local o = {x = x, y = y, width = w, height = h} setmetatable(o, self) self.__index = self return o end
function ISPanel:initialise() end
function ISPanel:instantiate() end
UIM = {}
function ISPanel:addToUIManager() UIM[self] = true end
function ISPanel:removeFromUIManager() UIM[self] = nil end
function ISPanel:setAlwaysOnTop() end
function ISPanel:render() end

-- (as the real ones: a picture only once read; READY = false: none read yet)
READY = true
function T.readyTex(path) local t = getTexture(path) if not READY then return nil end return t end
function T.preloadTex(paths) for _, p in ipairs(paths) do getTexture(p) end end
