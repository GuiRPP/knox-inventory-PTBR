-- Before KnoxLoad.lua wraps it: the action as Gunworks makes it, all its arguments written down
-- (tools/lists/gunworks.lua).
ISLoadBulletsInMagazine = {new = function(_, player, mag, count, limit, kind)
    return {name = "loadMag", player = player, mag = mag, count = count, limit = limit, kind = kind, args = kind and 5 or (limit and 4 or 3)}
end}
