-- The game's other tooltips in Knox's look (the author, 2026-10-18: "Replace:
-- Baseball bat" next to a menu option, a recipe's list of what it takes, every
-- such plate stood out in the game's look): ISToolTip - a title and a rich text
-- - and the recipe tooltip of the item menu (CraftTooltip, ISRecipeTooltip).
--
-- Knox's plate (the item tooltip's: window colour, frame, shadow), the title in
-- Knox's header font, the text in Knox's body font with the game's colours
-- turned into Knox's. The rich text is read here: lines, colours, indents. A
-- text with pictures in it, and classes of other mods built on ISToolTip, keep
-- the game's look - they lay themselves out in their own ways.

require "ISUI/ISToolTip"
require "ISUI/ISInventoryPaneContextMenu"
require "Knox/KnoxTheme"

KnoxOptionTooltip = {}
local K = KnoxOptionTooltip
local T = KnoxTheme

-- without the Java part (or with Knox's tooltips off) the game's tooltips stay as they are
if not T.on("tooltips") then return KnoxOptionTooltip end

local EDGE = {r = 0x4a / 255, g = 0x4f / 255, b = 0x4f / 255}   -- the item tooltip's frame
local RED = {r = 0xd9 / 255, g = 0x8a / 255, b = 0x7c / 255}
local PAD = 10

local function styled(tip)
    return T.javaFonts and (tip.Type == "ISToolTip" or tip.Type == "CraftTooltip")
end

--- The game's colour of a text, as Knox's: white - the text colour, red - Knox's
--- red, green - Knox's green; others as they are.
function K.color(r, g, b)
    r, g, b = r or 1, g or 1, b or 1
    if r > 0.9 and g > 0.9 and b > 0.9 then return T.color.text end
    if r > 0.7 and g < 0.55 and b < 0.55 then return RED end
    if g > 0.7 and r < 0.65 and b < 0.65 then return T.color.good end
    return {r = r, g = g, b = b}
end

-- Rich text ---------------------------------------------------------------------

--- The description as runs: {text = word, c = colour} and {nl = true}, {x = px};
--- nil when it holds a picture (left to the game).
local function runsOf(desc)
    if string.find(desc, "<%s*IMAGE") then return nil end
    local runs = {}
    local color, stack = T.color.text, {}
    local k = T.fontH(T.fontText) / math.max(1, getTextManager():getFontHeight(UIFont.NewSmall))
    local function words(s)
        for w in string.gmatch(s, "%S+") do table.insert(runs, {text = w, c = color}) end
    end
    local pos = 1
    while true do
        local a, b, tag = string.find(desc, "<([^>]*)>", pos)
        words(string.sub(desc, pos, (a or 0) - 1))
        if not a then break end
        local name, arg = string.match(tag, "^%s*([%a]+)%s*:?%s*(.-)%s*$")
        name = name and string.upper(name) or ""
        if name == "LINE" or name == "BR" then
            table.insert(runs, {nl = true})
        elseif name == "RGB" or name == "PUSHRGB" then
            local r, g, bb = string.match(arg, "([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)")
            if name == "PUSHRGB" then table.insert(stack, color) end
            if r then color = K.color(tonumber(r), tonumber(g), tonumber(bb)) end
        elseif name == "POPRGB" then
            color = table.remove(stack) or T.color.text
        elseif name == "RED" then
            color = RED
        elseif name == "GREEN" then
            color = T.color.good
        elseif name == "ORANGE" then
            color = T.color.warn
        elseif name == "H1" or name == "H2" then
            color = T.color.bright
        elseif name == "TEXT" then
            color = T.color.text
        elseif name == "SETX" or name == "INDENT" then
            local n = tonumber(arg)
            if n then table.insert(runs, {x = math.floor(n * k + 0.5), indent = name == "INDENT"}) end
        end
        pos = b + 1
    end
    return runs
end

--- The runs laid out in lines no wider than `maxW`: {{x, text, c}...} per line.
local function linesOf(runs, maxW)
    local font = T.fontText
    local space = T.measure(font, " ")
    local lines, line = {}, {}
    local x, indent = 0, 0
    local width = 0
    local function newLine()
        table.insert(lines, line)
        line = {}
        x = indent
    end
    for _, r in ipairs(runs) do
        if r.nl then
            newLine()
        elseif r.x then
            if r.indent then indent = r.x end
            x = math.max(x + (#line > 0 and space or 0), r.x)
        else
            local w = T.measure(font, r.text)
            local at = x + (#line > 0 and space or 0)
            if #line > 0 and at + w > maxW then
                newLine()
                at = x
            end
            table.insert(line, {x = at, text = r.text, c = r.c})
            x = at + w
            if x > width then width = x end
        end
    end
    if #line > 0 then table.insert(lines, line) end
    -- (no empty lines at the end)
    while #lines > 0 and #lines[#lines] == 0 do table.remove(lines) end
    return lines, width
end

local function lineH() return T.fontH(T.fontText) + 3 end

-- Layout --------------------------------------------------------------------------

local vanillaDoLayout = ISToolTip.doLayout
local vanillaRender = ISToolTip.render

function ISToolTip:doLayout()
    if not styled(self) then return vanillaDoLayout(self) end
    -- (laid out every frame by the game: the same text is laid out once)
    local key = tostring(self.description) .. "|" .. tostring(self.name) .. "|" .. tostring(self.footNote)
        .. "|" .. tostring(self.texture) .. "|" .. T.cell
    if self.knoxKey == key and not self.knoxPlain then
        self:setWidth(self.knoxW)
        self:setHeight(self.knoxH)
        return
    end
    self.knoxKey = key
    local runs
    if self.Type == "ISToolTip" then
        runs = runsOf(self.description or "")
        if not runs then
            self.knoxLines = nil
            self.knoxPlain = true
            return vanillaDoLayout(self)
        end
    end
    self.knoxPlain = false
    local nameW = self.name and T.measure(T.fontHeader, self.name) or 0
    local top = PAD + (self.name and (T.fontH(T.fontHeader) + 4) or 0)
    local x = PAD
    local texH = 0
    if self.texture then
        x = PAD + self.texture:getWidth() + 10
        texH = self.texture:getHeight()
    end
    local cw, ch = 0, 0
    if self.Type == "CraftTooltip" then
        -- (its own list of icons and names; its margins: 20 at the left, 10 above and below)
        cw, ch = self:layoutContents(x - 12, top - 10)
        cw, ch = cw - 12, ch - 10
    else
        -- a short text on one line; a long one wrapped at a readable width
        local _, natural = linesOf(runs, 100000)
        local maxW = math.max(math.floor(T.cell * 6), nameW - (x - PAD))
        self.knoxLines, cw = linesOf(runs, math.min(natural, maxW))
        ch = #self.knoxLines * lineH()
        if ch > 0 then ch = ch - 3 end
    end
    local w = math.max(x + cw, PAD + nameW) + PAD
    local h = math.max(top + ch, PAD + texH) + PAD
    if self.footNote then
        w = math.max(w, T.measure(T.fontTile, self.footNote) + PAD * 2)
        h = h + T.fontH(T.fontTile) + 6
    end
    self.knoxTop, self.knoxX = top, x
    self.knoxW, self.knoxH = w, h
    self:setWidth(w)
    self:setHeight(h)
end

-- (a tooltip taken from the game's pool again starts afresh)
local vanillaReset = ISToolTip.reset
function ISToolTip:reset()
    vanillaReset(self)
    self.knoxKey, self.knoxLines, self.knoxTop, self.knoxNeeds = nil, nil, nil, nil
end

-- Drawing -------------------------------------------------------------------------

--- Where the game puts it: next to the mouse, a menu's option, a button.
local function place(self)
    local mx, my = getMouseX() + 32, getMouseY() + 10
    if not self.followMouse then mx, my = self:getX(), self:getY() end
    if self.desiredX and self.desiredY then mx, my = self.desiredX, self.desiredY end
    self:setX(mx)
    self:setY(my)
    if self.contextMenu and self.contextMenu.joyfocus then
        local playerNum = self.contextMenu.player
        self:setX(getPlayerScreenLeft(playerNum) + 60)
        self:setY(getPlayerScreenTop(playerNum) + 60)
    elseif self.contextMenu and self.contextMenu.currentOptionRect then
        if self.contextMenu.currentOptionRect.height > 32 then self:setY(my + self.contextMenu.currentOptionRect.height) end
        self:adjustPositionToAvoidOverlap(self.contextMenu.currentOptionRect)
    elseif self.owner and (self.owner.isButton or self.owner.Type == "ISSkillProgressBar") then
        local r = {x = self.owner:getAbsoluteX(), y = self.owner:getAbsoluteY(), width = self.owner.width, height = self.owner.height}
        self:adjustPositionToAvoidOverlap(r)
    end
    -- (on the screen)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    self:setX(math.max(0, math.min(self:getX(), sw - self.width - 1)))
    self:setY(math.max(0, math.min(self:getY(), sh - self.height - 1)))
end

function ISToolTip:render()
    if not styled(self) or self.knoxPlain or not self.knoxTop then return vanillaRender(self) end
    place(self)
    local w, h = self.width, self.height
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window, 0.97)
    self:drawRectBorder(0, 0, w, h, 1, EDGE.r, EDGE.g, EDGE.b)
    if self.name then T.text(self, self.name, PAD, PAD - 2, T.color.bright, T.fontHeader) end
    if self.texture then
        local ty = self.name and self.knoxTop or PAD
        self:drawTextureScaled(self.texture, PAD, ty, self.texture:getWidth(), self.texture:getHeight(), 1, 1, 1, 1)
    end
    if self.Type == "CraftTooltip" then
        self:renderContents()
    else
        local y = self.knoxTop
        for _, line in ipairs(self.knoxLines or {}) do
            for _, s in ipairs(line) do T.text(self, s.text, self.knoxX + s.x, y, s.c, T.fontText) end
            y = y + lineH()
        end
    end
    if self.footNote then
        T.rect(self, PAD, h - T.fontH(T.fontTile) - 6 - PAD, w - PAD * 2, 1, T.color.border)
        T.textCentre(self, self.footNote, math.floor(w / 2), h - T.fontH(T.fontTile) - PAD + 2, T.color.dim, T.fontTile)
    end
end

-- The recipe tooltip: its names in Knox's font ---------------------------------------

local R = ISRecipeTooltip
if R then
    local vanillaAddText = R.addText
    function R:addText(x, y, text, r, g, b)
        if not styled(self) then return vanillaAddText(self, x, y, text, r, g, b) end
        local n, w = 0, 0
        for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
            n = n + 1
            w = math.max(w, T.measure(T.fontText, line))
        end
        table.insert(self.contents, {type = "text", x = x, y = y, width = w, height = T.fontH(T.fontText) * n,
                                     text = text, r = r or 1, g = g or 1, b = b or 1})
    end

    local vanillaContents = R.renderContents
    function R:renderContents()
        if not styled(self) then return vanillaContents(self) end
        local fh = T.fontH(T.fontText)
        for _, v in ipairs(self.contents or {}) do
            if v.type == "image" then
                if v.texture then self:drawTextureScaledAspect(v.texture, v.x, v.y, v.width, v.height, 1, v.r, v.g, v.b) end
            elseif v.type == "text" then
                local c, y = K.color(v.r, v.g, v.b), v.y
                for line in string.gmatch(v.text .. "\n", "([^\n]*)\n") do
                    T.text(self, line, v.x, y, c, T.fontText)
                    y = y + fh
                end
            end
        end
    end
end

return KnoxOptionTooltip
