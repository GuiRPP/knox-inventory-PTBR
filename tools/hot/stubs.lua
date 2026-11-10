-- The game under "every file loaded twice" (tools\hot\test.ps1, 2026-11-10): not the game's
-- API, only enough of it for Knox's files to run their top level - what each file does when
-- it loads (defines its tables and functions, adds its handlers, wraps the game's functions).
-- Anything not written here answers: an unknown global is a "game thing" G that can be
-- called, indexed (a field of it is another G, made once and kept) and counted with;
-- an unknown IS... global is a class of the game's UI (derive / new as the game's own).

-- (STUB_MADE: the globals and their fields made here - the test's second pass makes them
-- before Knox's files, as the game has them; then what Knox wraps was there before Knox)
STUB_MADE = {}
local G = {}          -- the metatable of the game things
local function thing(name)
    return setmetatable({__stub = name}, G)
end
G.__index = function(t, k)
    local name = tostring(rawget(t, "__stub"))
    local v = thing(name .. "." .. tostring(k))
    rawset(t, k, v)
    if type(k) == "string" and not string.find(name, "[%.%(]") then table.insert(STUB_MADE, name .. "\t" .. k) end
    return v
end
G.__call = function(self, ...) return thing(tostring(rawget(self, "__stub")) .. "()") end
local function one() return 1 end
G.__add, G.__sub, G.__mul, G.__div, G.__mod, G.__pow, G.__unm = one, one, one, one, one, one, one
G.__concat = function(a, b)
    local sa = type(a) == "table" and tostring(rawget(a, "__stub")) or tostring(a)
    local sb = type(b) == "table" and tostring(rawget(b, "__stub")) or tostring(b)
    return sa .. sb
end
G.__len = function() return 0 end
G.__lt = function() return false end
G.__le = function() return true end
STUB_THING = thing

-- the game's UI classes, as its ISBaseObject does it
ISBaseObject = {Type = "ISBaseObject"}
local stubMethod = function() return thing("method()") end
-- (a method the stubs don't have answers as one; "instance" - no window open)
setmetatable(ISBaseObject, {__index = function(t, k) if k == "instance" then return nil end return stubMethod end})
function ISBaseObject:derive(type)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = type
    return o
end
function ISBaseObject:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end
ISUIElement = ISBaseObject:derive("ISUIElement")
function ISUIElement:new(x, y, w, h)
    local o = ISBaseObject.new(self)
    o.x, o.y, o.width, o.height = x, y, w, h
    return o
end
ISPanel = ISUIElement:derive("ISPanel")

-- the globals Knox's files read as they load
local mt = {}
mt.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    if string.sub(k, 1, 4) == "Knox" then return nil end   -- (X = X or {} - its own)
    if string.sub(k, 1, 4) == "knox" then return nil end   -- (Knox's Java part: not here, as without the jar)
    local v
    if string.sub(k, 1, 2) == "IS" then v = ISUIElement:derive(k) else v = thing(k) end
    rawset(t, k, v)
    table.insert(STUB_MADE, k)
    return v
end
setmetatable(_G, mt)

function isServer() return false end
function isClient() return false end
function isDebugEnabled() return false end
function getDebug() return false end
function getText(k) return tostring(k) end
function getTextOrNull() return nil end
function getFileReader() return nil end
function getModFileReader() return nil end
function getFileWriter() return nil end
function getTimestampMs() return 100000 end
function getTimestamp() return 100 end
function instanceof() return false end
function getSpecificPlayer() return nil end
function getPlayer() return nil end
function getActivatedMods() return thing("mods") end
local core = thing("core")
rawset(core, "getScreenWidth", function() return 1920 end)
rawset(core, "getScreenHeight", function() return 1080 end)
rawset(core, "getOptionFontSize", function() return 1 end)
function getCore() return core end
Keyboard = setmetatable({}, {__index = function(t, k) return 1 end})
UIFont = setmetatable({}, {__index = function(t, k) return k end})
SandboxVars = setmetatable({}, {__index = function(t, k) return thing("SandboxVars." .. k) end})
