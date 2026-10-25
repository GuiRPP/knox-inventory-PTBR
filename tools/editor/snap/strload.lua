-- the shots' Russian texts, read whole (see strings.py)
TR, STR = {}, {}
for line in string.gmatch(readfile(SHOTSRC .. "/strings_" .. LANG .. ".txt"), "[^\r\n]+") do
    local i = string.find(line, "\t", 1, true)
    if i then
        local k, v = string.sub(line, 1, i - 1), string.sub(line, i + 1)
        TR[k], STR[k] = v, v
    end
end
