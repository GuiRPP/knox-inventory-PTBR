-- (snap.ps1 puts  for the editor's middle dot and  for its times sign: given back here)
function BYTE(s, i) local b = string.byte(s, i) return b == 1 and 183 or (b == 2 and 215 or b) end
-- Offline shots of the item editor: Knox's real font metrics (FONTS, from the atlases),
-- the RU texts (TR), and every drawing call written down (REC) for render.py.
local function fontOf(style, size)
    local px = math.max(10, math.min(44, math.floor(size + 0.5)))
    return FONTS[style .. "_" .. px] or FONTS[style .. "_20"]
end
function knoxFontReady() return true end
function knoxFontCovers() return true end
function knoxFontHeight(style, size) return fontOf(style, size).lh end
function knoxTextWidth(style, size, s)
    local f, w = fontOf(style, size), 0
    for i = 1, #s do
        local c = f.ch[BYTE(s, i)]
        if c then w = w + c[1] end
    end
    return w
end
function knoxTextInk(style, size, s)
    local f = fontOf(style, size)
    local pen, l, t, r, b = 0, 1e9, 1e9, -1e9, -1e9
    for i = 1, #s do
        local c = f.ch[BYTE(s, i)]
        if c then
            if c[4] > 0 and c[5] > 0 and c[6] >= 0 then
                l = math.min(l, pen + c[2] + c[6])
                r = math.max(r, pen + c[2] + c[8] + 1)
                t = math.min(t, c[3] + c[7])
                b = math.max(b, c[3] + c[9] + 1)
            end
            pen = pen + c[1]
        end
    end
    if r < l then return "" end
    return l .. "," .. t .. "," .. r .. "," .. b
end
function getText(key, ...)
    local s = TR[key] or key
    local args = {...}
    for i = 1, #args do s = string.gsub(s, "%%" .. i, (string.gsub(tostring(args[i]), "%%", "%%%%"))) end
    return s
end

REC = {}
local function codes(s)
    local t = {}
    for i = 1, #s do t[i] = BYTE(s, i) end
    return table.concat(t, ",")
end
local function rec(s) REC[#REC + 1] = s end
function knoxDrawText(style, size, s, x, y, r, g, b, a)
    local px = math.max(10, math.min(44, math.floor(size + 0.5)))
    rec("T " .. style .. "_" .. px .. " " .. x .. " " .. y .. " " .. r .. " " .. g .. " " .. b .. " " .. a .. " " .. codes(s))
end
function ISPanel:drawRect(x, y, w, h, a, r, g, b) rec("R " .. x .. " " .. y .. " " .. w .. " " .. h .. " " .. r .. " " .. g .. " " .. b .. " " .. a) end
function ISPanel:drawRectBorder(x, y, w, h, a, r, g, b) rec("B " .. x .. " " .. y .. " " .. w .. " " .. h .. " " .. r .. " " .. g .. " " .. b .. " " .. a) end
function getTexture(path) return path == "media/ui/knox_lens.png" and {lens = true} or nil end
function ISPanel:drawTextureScaledAspect(tex, x, y, w, h, a, r, g, b)
    if tex and tex.lens then rec("L " .. x .. " " .. y .. " " .. w .. " " .. h .. " " .. r .. " " .. g .. " " .. b)
    elseif tex and tex.tex and ICON[tex.tex] then rec("G " .. ICON[tex.tex] .. " " .. x .. " " .. y .. " " .. w .. " " .. h) end
end
function ISPanel:drawTextureScaled() end
function ISPanel:drawText(s, x, y, r, g, b, a) rec("T body_15 " .. x .. " " .. y .. " " .. r .. " " .. g .. " " .. b .. " " .. a .. " " .. codes(s)) end
function ISPanel:setStencilRect(x, y, w, h) rec("S " .. x .. " " .. y .. " " .. w .. " " .. h) end
function ISPanel:clearStencilRect() rec("s") end
-- (the game's text box draws its own text: as the field shows it, Knox's body font, centred)
function recBox(box)
    if not box or not box.visible or not box.x then return end
    local T = KnoxTheme
    local f = T.fontText
    local s = box.text ~= "" and box.text or (box.ph or "")
    local c = box.text ~= "" and T.color.bright or T.color.dim
    local y = box.y + math.floor((box.h - T.fontH(f)) / 2)
    knoxDrawText(f.style, f.size, s, box.x, y, c.r, c.g, c.b, 1)
    if box.focused then rec("R " .. (box.x + T.measure(f, box.text) + 1) .. " " .. (y + 2) .. " 1 " .. (T.fontH(f) - 3) .. " 1 1 1 1") end
end
function ISTextEntryBox:setPlaceholderText(s) self.ph = s end
function shot(name)
    writefile(SHOTDIR .. "/" .. name .. ".txt", table.concat(REC, "\n"))
    REC = {}
end
