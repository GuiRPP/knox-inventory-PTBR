-- Runs KnoxMaterial.classify over every item of the game's scripts (items.tsv, made by
-- parse.ps1) and writes report.txt: how many things each material got, then every
-- material's things with the rule that decided it - to be read for mistakes, which
-- go into KnoxMaterial.FIX. Run by gen.ps1 on the game's Lua outside the game.

local M = KnoxMaterial
local text = readfile(items)
local lines = {}
for l in string.gmatch(text, "[^\r\n]+") do table.insert(lines, l) end

local function split(l)
    local t = {}
    local i = 1
    while true do
        local j = string.find(l, "\t", i, true)
        if not j then table.insert(t, string.sub(l, i)) break end
        table.insert(t, string.sub(l, i, j - 1))
        i = j + 1
    end
    return t
end

local head = split(lines[1])
local col = {}
for i, h in ipairs(head) do col[h] = i end

local by, count, total = {}, {}, 0
for n = 2, #lines do
    local f = split(lines[n])
    local function v(k)
        local s = f[col[k]]
        if s == nil or s == "" then return nil end
        return s
    end
    local tags = {}
    for tg in string.gmatch(v("Tags") or "", "[^;]+") do
        tags[string.lower((string.gsub(tg, "^%s*%w+:", "")))] = true
    end
    local ty = string.lower(string.gsub(v("ItemType") or "", "^%w+:", ""))
    local info = {
        ft = v("fullType"), type = ty, cat = v("DisplayCategory"), weight = tonumber(v("Weight")),
        tags = tags, fabric = v("FabricType"), world = v("WorldStaticModel"), static = v("StaticModel"),
        drop = v("DropSound"), placeOne = v("PlaceOneSound"), tap = v("FillFromTapSound"),
        body = v("BodyLocation") and string.gsub(v("BodyLocation"), "^%w+:", "") or nil,
        foodType = v("FoodType"), packaged = v("Packaged") and string.lower(v("Packaged")) == "true",
        eatType = v("EatType"),
    }
    local mat, why = M.classify(info)
    by[mat] = by[mat] or {}
    table.insert(by[mat], {ft = info.ft, why = why, model = info.world or info.static or "", cat = info.cat or "", own = info.drop or info.placeOne})
    count[mat] = (count[mat] or 0) + 1
    total = total + 1
end

local mats = {}
for m in pairs(by) do table.insert(mats, m) end
table.sort(mats, function(a, b) return count[a] > count[b] end)

local r = {}
table.insert(r, "Knox materials: " .. total .. " items of the game's scripts (tools\\material\\gen.ps1)")
table.insert(r, "A thing with its own sound (a weapon's drop, a box of rounds) keeps it: marked *")
table.insert(r, "")
for _, m in ipairs(mats) do table.insert(r, string.format("  %-12s %5d", m, count[m])) end
for _, m in ipairs(mats) do
    table.insert(r, "")
    table.insert(r, "== " .. m .. " (" .. count[m] .. ") ==")
    table.sort(by[m], function(a, b)
        if a.why ~= b.why then return a.why < b.why end
        return a.ft < b.ft
    end)
    local lastWhy = nil
    for _, e in ipairs(by[m]) do
        if e.why ~= lastWhy then
            table.insert(r, "  -- " .. e.why)
            lastWhy = e.why
        end
        table.insert(r, string.format("    %s%s   [%s | %s]", e.own and "*" or " ", string.gsub(e.ft, "^Base%.", ""), e.cat, e.model))
    end
end
writefile(report, table.concat(r, "\r\n"))
print("items " .. total .. ", materials " .. #mats .. " -> " .. report)
