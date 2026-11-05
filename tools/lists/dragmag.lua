-- Rounds dropped onto a magazine (the author, 2026-11-05) on the game's Lua with the real KnoxDrag.
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end
instanceof = instanceof or function() return false end

-- rounds dropped onto a magazine (the author, 2026-11-05)
do
    local known = {}
    KnoxMagKnown = {hide = true, is = function(m) return known[m] == true end}
    local function mag(n, cap, key)
        return {getCurrentAmmoCount = function() return n end, getMaxAmmo = function() return cap end,
            getAmmoType = function() return {getItemKey = function() return key end} end,
            getContainer = function() return "bag" end}
    end
    local rounds = {getFullType = function() return "Base.9mm" end, getContainer = function() return "bag" end}
    local under
    local v = {isMouseOver = function() return true end, entityUnderMouse = function() return under end, markDirty = function() end}
    local function over(m) under = {item = m, items = {m}, x = 0, y = 0} return under end
    local D = KnoxDrag
    D.entity, D.extras = {item = rounds, items = {rounds}}, {}
    local half, full, other = mag(7, 15, "Base.9mm"), mag(15, 15, "Base.9mm"), mag(0, 15, "Base.45")
    known[half], known[full], known[other] = true, true, true
    over(half)
    check("rounds on a magazine with room: yes", D.magTarget(v) == under)
    over(full)
    check("known to be full: no", D.magTarget(v) == nil)
    over(other)
    check("other rounds: no", D.magTarget(v) == nil)
    local hidden = mag(15, 15, "Base.9mm")
    over(hidden)
    check("not checked, full inside: looks the same", D.magTarget(v) == under)
    local t = over(half)
    t.items = {full, half}
    local _, m = D.magTarget(v)
    check("a stack: the one with room", m == half)
    D.extras = {{}}
    over(half)
    check("with others held: no", D.magTarget(v) == nil)
    D.extras = {}
    local gun = mag(0, 15, "Base.9mm")
    local realI = instanceof
    instanceof = function(o, c) return o == gun and c == "HandWeapon" end
    over(gun)
    check("a gun: not this way", D.magTarget(v) == nil)
    instanceof = realI
    local asked
    local realLoad = KnoxLoad and KnoxLoad.loadMagazine
    KnoxLoad = KnoxLoad or {}
    KnoxLoad.loadMagazine = function(p, mm, pile) asked = {p = p, m = mm, pile = pile} end
    over(half)
    check("dropped: loaded", D.drop(v, 0, 0, "player") == true and asked and asked.m == half and asked.pile.items[1] == rounds)
    check("dropped: the drag is over", D.entity == nil)
    KnoxLoad.loadMagazine = realLoad
    KnoxMagKnown = nil
end

print("dragmag: " .. pass .. " pass, " .. fail .. " fail")
