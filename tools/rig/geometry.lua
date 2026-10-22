-- Every family of KnoxBagShapes laid out by the mod's own geometry (cells `cs`
-- pixels), as text for tools\rig\sheet.ps1 to draw:
--   F<TAB>name<TAB>firstType<TAB>w<TAB>h<TAB>cells<TAB>sizeText
--   P<TAB>x<TAB>y<TAB>w<TAB>h            (a compartment: pixels, cells)
local S = KnoxBagShapes
local cs = tonumber(cell) or 40
local out = {}
for _, f in ipairs(S.FAMILIES) do
    local sh = S.compile(f.spec)
    local g = S.geometry(sh, cs)
    local m = sh.main
    local rest = sh.cells - m.w * m.h
    table.insert(out, table.concat({"F", f.name, f.types[1], g.w, g.h, sh.cells,
        m.w .. "x" .. m.h .. (rest > 0 and ("+" .. rest) or ""), f.spec}, "\t"))
    for _, p in ipairs(sh.parts) do
        local o = g.parts[p]
        table.insert(out, table.concat({"P", o.x, o.y, p.w, p.h}, "\t"))
    end
end
writefile(target, table.concat(out, "\n"))
print("families " .. #S.FAMILIES .. " -> " .. target)
