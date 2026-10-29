-- The game's side for KnoxPerf.lua outside the game (tools/perf/test.ps1): events
-- that keep their handlers in a list as the game's Java does (Add appends, no check;
-- Remove takes the first equal one out), a settings file, a clock, the file the
-- counter writes. `perf` (a global from the command line): "1" or "0".

-- Paths of closures: what getFilenameOfClosure answers. A closure nobody named is
-- counted as KnoxPerf.lua's own (that is where the counter's own closures come from).
ROOT = "C:/Users/x/Zomboid/mods/Knox Inventory/42/media/lua/"
SELF = ROOT .. "shared/Knox/KnoxPerf.lua"
PATHS = setmetatable({}, {__mode = "k"})
LINES = setmetatable({}, {__mode = "k"})
function getFilenameOfClosure(fn) return PATHS[fn] or SELF end
function getFirstLineOfClosure(fn) return LINES[fn] or 1 end
function knoxFile(fn, file, line)
    PATHS[fn], LINES[fn] = ROOT .. file, line or 1
    return fn
end
function foreignFile(fn)
    PATHS[fn] = "C:/Steam/workshop/content/108600/1/mods/Other/42/media/lua/client/Other.lua"
    return fn
end

-- events as the game keeps them
LISTS = {}
Events = {}
for _, name in ipairs({"OnTick", "OnPreUIDraw", "OnPostUIDraw", "OnGameStart", "OnMainMenuEnter", "OnPlayerDeath", "OnCreatePlayer", "OnSave"}) do
    local list = {}
    LISTS[name] = list
    Events[name] = {
        Add = function(fn) table.insert(list, fn) end,
        Remove = function(fn)
            for i, f in ipairs(list) do
                if f == fn then table.remove(list, i) return end
            end
        end,
    }
end
function fire(name, ...)
    local copy = {}
    for i, f in ipairs(LISTS[name]) do copy[i] = f end
    for _, f in ipairs(copy) do f(...) end
end
ORIGINAL_ADD = Events.OnTick.Add

-- the clock: microseconds and milliseconds that move only when told
NOW_US, NOW_MS = 0, 100000
function knoxPerfNow() NOW_US = NOW_US + 1 return NOW_US end
function getTimestampMs() return NOW_MS end
function knoxPerfStats() return "100.0\t200.0\t4000.0\t5\t12\t60.0\t42\t7" end
function knoxPerfHandlers() return "OnTick=1/3" end

function isServer() return false end

-- the settings file and the file the counter writes
FILES = {["knox_settings.txt"] = "anim=1\r\ndev.perf=" .. tostring(perf or "0") .. "\r\n"}
function getFileReader(name)
    local text = FILES[name]
    if not text then return nil end
    local lines, i = {}, 0
    for l in string.gmatch(text, "[^\r\n]+") do table.insert(lines, l) end
    return {readLine = function() i = i + 1 return lines[i] end, close = function() end}
end
function getFileWriter(name, create, append)
    local buf = {}
    return {write = function(_, s) table.insert(buf, s) end,
            close = function() FILES[name] = (append and FILES[name] or "") .. table.concat(buf) end}
end
