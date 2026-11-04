-- KnoxMenuPlace outside the game (tools/place/test.ps1): which scene the main
-- menu shows - the bar from November to February, the camp otherwise, and the
-- one Tab chose kept until the season changes (the author, 2026-10-31).

local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else fail = fail + 1; print("FAIL " .. name .. (detail and (" : " .. tostring(detail)) or "")) end
end

-- the player's clock and Zomboid/Lua
local month = 11
os = {date = function(f) if f == "%m" then return string.format("%02d", month) end end}
local files = {}
function getFileReader(name)
    local text = files[name]
    if not text then return nil end
    local lines, i = {}, 0
    for l in string.gmatch(text, "[^\r\n]+") do table.insert(lines, l) end
    return {readLine = function() i = i + 1; return lines[i] end, close = function() end}
end
function getFileWriter(name)
    local buf = {}
    return {writeln = function(_, s) table.insert(buf, s .. "\n") end, close = function() files[name] = table.concat(buf) end}
end

local P = KnoxMenuPlace

-- seasons
for m = 1, 12 do
    local winter = m == 11 or m == 12 or m == 1 or m == 2
    check("season " .. m, P.season(m) == (winter and "winter" or "summer"), P.season(m))
end
check("decide: nothing kept in winter -> bar", P.decide(nil, nil, "winter") == "bar")
check("decide: nothing kept in summer -> camp", P.decide(nil, nil, "summer") == "camp")
check("decide: kept this season", P.decide("camp", "winter", "winter") == "camp")
check("decide: kept last season -> the new one's own", P.decide("camp", "summer", "winter") == "bar")
check("decide: junk kept -> the season's own", P.decide("tavern", "winter", "winter") == "bar")

-- the first menu in November: the bar, written down
month = 11
check("November, first time: bar", P.current() == "bar")
check("written down", files[P.FILE] == "KP1\nbar\twinter\n", files[P.FILE])
-- Tab: the camp, kept through the winter
check("Tab -> camp", P.toggle() == "camp")
check("camp kept in November", P.current() == "camp")
month = 1
check("camp kept in January", P.current() == "camp")
month = 2
check("Tab again in February -> bar", P.toggle() == "bar")
check("bar kept in February", P.current() == "bar")
-- March: the season's own once - the camp
month = 3
check("March: camp", P.current() == "camp")
check("Tab in March -> bar", P.toggle() == "bar")
month = 7
check("bar kept in July", P.current() == "bar")
-- next November: the bar comes by itself again (after summer was spent at the camp)
check("Tab in July -> camp", P.toggle() == "camp")
month = 11
check("next November: bar", P.current() == "bar")

-- a broken file: the season's own, and the file mended
files[P.FILE] = "garbage"
month = 12
check("broken file in December: bar", P.current() == "bar")
check("mended", files[P.FILE] == "KP1\nbar\twinter\n", files[P.FILE])

-- a clock that can't be told: the camp, as the menu always was
os = {date = function() error("no clock") end}
Calendar = nil
files[P.FILE] = nil
check("no clock: summer's camp", P.current() == "camp")
os = nil
check("no os at all: summer's camp", P.current() == "camp")
-- the game's Java calendar when os.date is missing (2: its MONTH, from 0)
Calendar = {getInstance = function() return {get = function(_, f) return f == 2 and 11 or 0 end} end}
files[P.FILE] = nil
check("Java calendar in December: bar", P.current() == "bar")

print(string.format("place: %d passed, %d failed", pass, fail))
if fail > 0 then error("place: " .. fail .. " failed") end
