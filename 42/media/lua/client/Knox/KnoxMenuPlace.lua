-- Which scene the main menu is (the author, 2026-10-31): the camp at the fire,
-- or the bar in a blizzard (KnoxMenuBar). From November to February the bar
-- comes by itself; after that the menu keeps the scene it was left on - Tab
-- switches them (KnoxMenuScene: M:updateSwitch).
--
-- Kept in Zomboid/Lua/knox_menu_place.txt (getFileWriter's own folder):
--   KP1
--   place <tab> season
-- with the season it was chosen in: a new season brings its own scene once,
-- and whatever is chosen then stays until the next one.

KnoxMenuPlace = {}
local P = KnoxMenuPlace

P.FILE = "knox_menu_place.txt"

--- "winter" (November to February) or "summer", of a month 1..12.
function P.season(month)
    if month == 11 or month == 12 or month == 1 or month == 2 then return "winter" end
    return "summer"
end

--- The scene a season brings.
function P.ofSeason(season)
    return season == "winter" and "bar" or "camp"
end

--- The scene to show: the one kept, if it was chosen this season; else the season's own.
function P.decide(kept, keptSeason, season)
    if (kept == "camp" or kept == "bar") and keptSeason == season then return kept end
    return P.ofSeason(season)
end

--- This month on the player's own clock, 1..12; nil if it can't be told.
function P.month()
    local ok, m = pcall(function() return os.date("%m") end)
    m = ok and tonumber(m) or nil
    if m and m >= 1 and m <= 12 then return m end
    ok, m = pcall(function() return Calendar.getInstance():get(2) + 1 end)   -- (2: Calendar.MONTH, from 0)
    if ok and type(m) == "number" and m >= 1 and m <= 12 then return m end
    return nil
end

local function read()
    local r = getFileReader(P.FILE, false)
    if not r then return nil, nil end
    local first, line = r:readLine(), r:readLine()
    r:close()
    if first ~= "KP1" or not line then return nil, nil end
    return string.match(line, "^(%a+)\t(%a+)")
end

local function write(place, season)
    local w = getFileWriter(P.FILE, true, false)
    if not w then return end
    w:writeln("KP1")
    w:writeln(place .. "\t" .. season)
    w:close()
end

--- The scene the menu shows now. (A month the clock can't tell counts as summer:
--- the camp, the scene the menu always had.)
function P.current()
    local season = P.season(P.month() or 7)
    local kept, keptSeason = read()
    local place = P.decide(kept, keptSeason, season)
    if kept ~= place or keptSeason ~= season then write(place, season) end
    return place
end

--- Tab: the other scene, kept for this season. Returns it.
function P.toggle()
    local place = (P.current() == "bar") and "camp" or "bar"
    write(place, P.season(P.month() or 7))
    return place
end
