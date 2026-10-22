-- New game, step 4: the survivor - the game's two screens (occupation and
-- traits; appearance and clothing) shown as one, in Knox's look:
--   left      who the survivor is so far: name, occupation, points left,
--             the chosen traits as chips (a click gives one back), skills
--   middle    the survivor: the game's own 3D preview
--   right     what is being changed, by tabs: Occupation, Traits (one list
--             with filters; excluded traits stay visible, dimmed, with the
--             reason), Appearance, Clothing
--   bottom    Back; the saved builds or outfits of the open tab; Random;
--             Play
--
-- How it holds together. The game's appearance screen (CharacterCreationMain)
-- is the one shown: it owns the preview, the appearance and clothing panels
-- and "Play". The occupation screen (CharacterCreationProfession) is never
-- shown but stays the keeper of the occupation, the traits, the points and
-- the builds: every click here calls its own functions, and its lists are
-- what is drawn. So occupations, traits and clothes added by mods are simply
-- there, and what a choice does is the game's code. The appearance and
-- clothing controls are the game's own, moved and recolored.
-- In a running game (a new character after death, split screen) and without
-- the Java part both screens are left as the game has them.

require "OptionScreens/CharacterCreationMain"
require "OptionScreens/CharacterCreationProfession"
require "ISUI/ISScrollingListBox"
require "Knox/KnoxTheme"
require "Knox/KnoxMenuSkin"

local T = KnoxTheme
local S = KnoxMenuSkin

local TABS = {
    {id = "prof", text = "IGUI_Knox_Char_Prof"},
    {id = "traits", text = "IGUI_Knox_Char_Traits"},
    {id = "look", text = "IGUI_Knox_Char_Look"},
    {id = "clothes", text = "IGUI_Knox_Char_Clothes"},
}
local FILTERS = {
    {id = "all", text = "IGUI_Knox_Char_All"},
    {id = "good", text = "IGUI_Knox_Char_Good"},
    {id = "bad", text = "IGUI_Knox_Char_Bad"},
}

local function oursMain(self)
    local main = MainScreen.instance
    return T.on("newgame") and main ~= nil and not main.inGame and self == main.charCreationMain
        and main.charCreationProfession ~= nil
end

local function oursProf(self)
    local main = MainScreen.instance
    return T.on("newgame") and main ~= nil and not main.inGame and self == main.charCreationProfession
        and main.charCreationMain ~= nil
end

--- The hidden occupation screen: the keeper of occupation, traits and points.
local function keeper()
    return MainScreen.instance.charCreationProfession
end

local function colored(k, a)
    return {r = k.r, g = k.g, b = k.b, a = a}
end

--- Plain paragraphs of a description.
local function paragraphs(s)
    s = string.gsub(s or "", "<LINE>", "\n")
    s = string.gsub(s, "<BR>", "\n")
    s = string.gsub(s, "<[^>]*>", "")
    local out = {}
    for line in string.gmatch(s .. "\n", "([^\n]*)\n") do
        line = string.gsub(line, "^%s*(.-)%s*$", "%1")
        if line ~= "" then table.insert(out, line) end
    end
    return out
end

--- What the info box under the lists tells: set by the row under the mouse.
local function tell(screen, key, title, text, note, noteColor)
    local info = screen.knoxInfo
    if info and info.key == key then return end
    screen.knoxInfo = {key = key, title = title, text = text, note = note, noteColor = noteColor}
end

-- Occupations ---------------------------------------------------------------------

local function drawProf(self, y, item, alt)
    local screen = self.parent
    local w, h, pad = self:getWidth(), item.height, T.pad
    if self:getScrollHeight() > self:getHeight() then w = w - 18 end
    local rh = h - math.floor(pad / 2)
    local def = item.item
    local sel = keeper().profession == def
    local hot = self.mouseoverselected == item.index and not self:isMouseOverScrollBar() and self:isMouseOver()
    T.rect(self, 0, y, w, rh, sel and T.color.header or T.color.window, 0.96)
    if hot and not sel then self:drawRect(0, y, w, rh, 0.05, 1, 1, 1) end
    T.tileFrame(self, 0, y, w, rh, sel and T.color.accent or T.color.tileEdge)
    if sel then T.rect(self, 0, y, 4, rh, T.color.accent) end
    local x = 4 + pad
    local tex = def:getTexture()
    if tex then
        local s = rh - pad
        local k = math.min(s / math.max(1, tex:getWidth()), s / math.max(1, tex:getHeight()))
        local tw, th = tex:getWidth() * k, tex:getHeight() * k
        self:drawTextureScaled(tex, x + math.floor((s - tw) / 2), y + math.floor((rh - th) / 2), tw, th, sel and 1 or 0.75, 1, 1, 1)
        x = x + s + pad
    end
    local font = T.fontHeader
    local cost = def:getCost()
    local costText = (cost > 0 and "+" or "") .. tostring(cost)
    local cw = T.measure(font, costText)
    T.text(self, costText, w - pad - cw, y + math.floor((rh - T.fontH(font)) / 2), cost < 0 and T.color.bad or T.color.good, font)
    local color = sel and T.color.bright or (hot and T.color.text or T.color.dim)
    T.text(self, T.fit(T.upper(def:getUIName() or ""), font, w - x - pad * 2 - cw), x, y + math.floor((rh - T.fontH(font)) / 2), color, font)
    if hot then tell(screen, def, def:getUIName(), def:getDescription(), costText, cost < 0 and T.color.bad or T.color.good) end
    return y + h
end

local function clickProf(self, def)
    local k = keeper()
    for i, it in ipairs(k.listboxProf.items) do
        if it.item == def then
            k.listboxProf.selected = i
            k:onSelectProf(def)
            getSoundManager():playUISound("UIActivateButton")
            return
        end
    end
end

-- Traits --------------------------------------------------------------------------

--- All the traits for the one list: {def, state = "chosen" | "granted" |
--- "open" | "excluded", by = label of the trait that excludes it}.
local function traitRows(filter)
    local k = keeper()
    local chosen, open = {}, {}
    for _, it in ipairs(k.listboxTraitSelected.items) do chosen[it.item:getLabel()] = it.item end
    for _, it in ipairs(k.listboxTrait.items) do open[it.item:getLabel()] = true end
    for _, it in ipairs(k.listboxBadTrait.items) do open[it.item:getLabel()] = true end
    local rows = {}
    local all = CharacterTraitDefinition.getTraits()
    for i = 0, all:size() - 1 do
        local def = all:get(i)
        local label = def:getLabel()
        local cost = def:getCost()
        local row = nil
        if chosen[label] then
            row = {def = def, state = def:isFree() and "granted" or "chosen"}
        elseif not def:isFree() and cost ~= 0 and k:isTraitEnabled(def) then
            if open[label] then
                row = {def = def, state = "open"}
            else
                row = {def = def, state = "excluded"}
                for _, other in pairs(chosen) do
                    if def:isMutuallyExclusive(other) then
                        row.by = other:getLabel()
                        break
                    end
                end
            end
        end
        if row then
            local good = cost > 0
            local shown = filter == "all" or (filter == "good" and good) or (filter == "bad" and cost < 0)
            if row.state == "granted" then shown = filter ~= "bad" end
            if shown then
                -- granted first, then the positive by cost, then the negative
                row.rank = row.state == "granted" and 0 or (good and 1 or 2)
                row.cost = math.abs(cost)
                row.label = label
                table.insert(rows, row)
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.cost ~= b.cost then return a.cost < b.cost end
        return a.label < b.label
    end)
    return rows
end

local function drawTrait(self, y, item, alt)
    local screen = self.parent
    local w, h, pad = self:getWidth(), item.height, T.pad
    if self:getScrollHeight() > self:getHeight() then w = w - 18 end
    local rh = h - 3
    local row = item.item
    local def = row.def
    local state = row.state
    local on = state == "chosen" or state == "granted"
    local off = state == "excluded"
    local hot = self.mouseoverselected == item.index and not self:isMouseOverScrollBar() and self:isMouseOver()
    T.rect(self, 0, y, w, rh, on and T.color.header or T.color.window, off and 0.6 or 0.96)
    if hot and not on and not off then self:drawRect(0, y, w, rh, 0.05, 1, 1, 1) end
    T.tileFrame(self, 0, y, w, rh, on and T.color.accent or (off and T.color.border or T.color.tileEdge))
    if on then T.rect(self, 0, y, 4, rh, T.color.accent) end
    local alpha = off and 0.4 or 1
    local x = 4 + pad
    local tex = def:getTexture()
    if tex then
        local s = math.min(rh - 6, math.floor(T.cell * 0.45))
        self:drawTextureScaled(tex, x, y + math.floor((rh - s) / 2), s, s, alpha, 1, 1, 1)
        x = x + s + pad
    end
    local cost = def:getCost()
    local good = cost > 0
    local font = T.fontText
    local ty = y + math.floor((rh - T.fontH(font)) / 2)
    local right, rightColor
    if state == "granted" then
        right, rightColor = getText("IGUI_Knox_Char_Granted"), T.color.dim
    elseif off then
        right, rightColor = getText("IGUI_Knox_Char_Excluded", row.by or "?"), T.color.dim
    else
        -- a positive trait takes points, a negative one gives them
        right, rightColor = (good and "-" or "+") .. tostring(math.abs(cost)), good and T.color.good or T.color.bad
    end
    local rw = T.measure(font, right)
    T.text(self, right, w - pad - rw, ty, rightColor, font, alpha)
    local color = off and T.color.dim or (good and T.color.good or (cost < 0 and T.color.bad or T.color.text))
    if on then color = T.color.bright end
    T.text(self, T.fit(def:getLabel() or "", font, w - x - pad * 2 - rw), x, ty, color, font, alpha)
    if hot then tell(screen, def, def:getLabel(), def:getDescription(), right, rightColor) end
    return y + h
end

local function clickTrait(self, row)
    local k = keeper()
    local def = row.def
    if row.state == "open" then
        k:addTrait(def)
        k:checkXPBoost()
        getSoundManager():playUISound("UIActivateButton")
    elseif row.state == "chosen" then
        for i, it in ipairs(k.listboxTraitSelected.items) do
            if it.item == def then
                k:removeTrait(i)
                k:checkXPBoost()
                getSoundManager():playUISound("UIActivateButton")
                break
            end
        end
    end
end

--- The trait list again when what the keeper holds, or the filter, changed.
local function syncTraits(self)
    local k = keeper()
    local key = tostring(#k.listboxTraitSelected.items) .. "/" .. tostring(#k.listboxTrait.items) .. "/"
        .. tostring(#k.listboxBadTrait.items) .. "/" .. tostring(self.knoxFilter) .. "/" .. tostring(k.profession)
    if self.knoxTraitKey == key then return end
    self.knoxTraitKey = key
    local list = self.knoxTraits
    local scroll = list:getYScroll()
    list:clear()
    for _, row in ipairs(traitRows(self.knoxFilter)) do list:addItem(row.label, row) end
    list.selected = -1
    list:setYScroll(scroll)
end

local function syncProfs(self)
    local k = keeper()
    local list = self.knoxProfs
    if #list.items == #k.listboxProf.items then return end
    list:clear()
    for _, it in ipairs(k.listboxProf.items) do list:addItem(it.text, it.item) end
    list.selected = -1
end

-- The game's own controls, in Knox's look -----------------------------------------

--- The appearance and clothing panels: fonts, colors, tick boxes, buttons.
--- Returns true when something was newly styled (the panel is laid out again).
local function styleTree(e, font, depth)
    local changed = false
    if type(e.children) ~= "table" or depth > 3 then return false end
    for _, c in pairs(e.children) do
        local kind = c.Type
        local key = tostring(font)
        if c.knoxStyle ~= key then
            local done = true
            if kind == "ISLabel" then
                if font then
                    -- (section titles are the game's medium font: kept apart by color)
                    local title = c.font == UIFont.Medium or c.knoxTitle
                    c.knoxTitle = title
                    c.font = font
                    c:setWidthToName()
                    local k = title and T.color.bright or T.color.dim
                    c.r, c.g, c.b = k.r, k.g, k.b
                end
            elseif kind == "ISComboBox" then
                S.combo(c, font)
            elseif kind == "ISTextEntryBox" then
                S.field(c)
            elseif kind == "ISTickBox" then
                if font then c.font = font end
                S.tick(c)
            elseif kind == "ISSliderPanel" then
                S.slider(c)
            elseif kind == "ISButton" then
                -- (a button without a title is a color swatch: left as it is)
                if not c.image and type(c.title) == "string" and c.title ~= "" then S.plain(c) end
            else
                done = false
                if styleTree(c, font, depth + 1) then changed = true end
            end
            if done then
                c.knoxStyle = key
                changed = true
            end
        end
    end
    return changed
end

-- Appearance and clothing: the game's panels in two columns -----------------------

--- The appearance panel. The game lines its controls up against the panel's
--- right edge, 300 px wide at most, one under another; here its sections
--- (name, body, voice, hair, beard) fill two columns. Put in place of the
--- panel's own positionRelativeToScrollBar, so the game's calls land here.
local function arrangeLook(panel)
    local pad, c = T.pad, T.cell
    if not c then return end
    local cw = panel.columnWidth or 0
    local kind, divider, wide = {}, {}, {}
    for _, v in pairs(panel.reposTable) do kind[v] = "head" end
    for _, v in pairs(panel.repos2Table) do kind[v] = "title" end
    for _, v in pairs(panel.repos3Table) do kind[v] = "control" end
    for _, v in pairs(panel.dividerResizeTable) do divider[v] = true end
    for _, v in pairs(panel.comboResizeTable) do wide[v] = true end
    local kids, heads, total = {}, {}, 0
    -- Controls a mod puts side by side in one row (NeatUI Hairstyler: the hair
    -- menu button and the hair color swatch) keep their distance from each
    -- other: all moved to the same x, the swatch hid the button - "how do I
    -- change the hairstyle" (the user, 2026-10-14). By the row's leftmost one.
    local rowLeft = {}
    for _, ch in pairs(panel.children) do
        if ch.Type ~= "ISScrollBar" then
            if ch.knoxY0 == nil then ch.knoxY0 = ch:getY() end   -- where the game put it
            if ch.knoxX0 == nil then ch.knoxX0 = ch:getX() end
            table.insert(kids, ch)
            total = math.max(total, ch.knoxY0 + ch:getHeight())
            if kind[ch] == "head" then table.insert(heads, ch) end
            if not kind[ch] and not divider[ch] then
                local row = math.floor(ch.knoxY0 / 4)
                rowLeft[row] = math.min(rowLeft[row] or ch.knoxX0, ch.knoxX0)
            end
        end
    end
    table.sort(heads, function(a, b) return a.knoxY0 < b.knoxY0 end)
    -- the section the second column starts with: the one that makes the
    -- two columns closest in height
    local shiftY, best = nil, nil
    for _, h in ipairs(heads) do
        local worst = math.max(h.knoxY0, total - h.knoxY0)
        if not best or worst < best then best, shiftY = worst, h.knoxY0 end
    end
    local colW = math.floor((panel.width - 16) / 2)
    local ctlW = math.floor(math.min(c * 8, colW - cw - 10 - pad * 3))
    for _, ch in ipairs(kids) do
        local second = shiftY ~= nil and ch.knoxY0 >= shiftY - 1
        local base = pad + (second and colW or 0)
        if divider[ch] then
            ch:setX(base)
            ch:setWidth(colW - pad * 3)
        elseif kind[ch] == "head" then
            ch:setX(base)
        elseif kind[ch] == "title" then
            ch:setX(base + cw - ch:getWidth())
        else
            -- (a text box is drawn `knoxInset` wider to its left: S.field)
            local shift = 0
            if not kind[ch] then
                local left = rowLeft[math.floor(ch.knoxY0 / 4)]
                if left then shift = math.max(0, ch.knoxX0 - left) end
            end
            ch:setX(base + cw + 10 + (ch.knoxInset or 0) + shift)
        end
        if wide[ch] then ch:setWidth(ctlW - (ch.knoxInset or 0)) end
        ch:setY(ch.knoxY0 - (second and shiftY or 0))
    end
    panel:setScrollHeight(math.max(shiftY or total, total - (shiftY or 0)) + pad)
end

--- A clothing label no longer than `width` in the game's small font (the
--- game measures the labels in it to place the rows).
local function shorten(label, width)
    if not label.knoxFull then label.knoxFull = label.name end
    local tm = getTextManager()
    local text = label.knoxFull
    if tm:MeasureStringX(UIFont.Small, text) > width then
        local n = string.len(text)
        while n > 3 and tm:MeasureStringX(UIFont.Small, string.sub(text, 1, n) .. "..") > width do n = n - 1 end
        text = string.sub(text, 1, n) .. ".."
    end
    if label.name ~= text then
        label.name = text
        label:setWidthToName()
    end
end

local function clothingParts(self, loc)
    return {self.clothingComboLabel and self.clothingComboLabel[loc], self.clothingCombo and self.clothingCombo[loc],
        self.clothingColorBtn and self.clothingColorBtn[loc], self.clothingTextureCombo and self.clothingTextureCombo[loc],
        self.clothingDecalCombo and self.clothingDecalCombo[loc]}
end

-- The clothing panel: the game's rows (a label, a list, a color, a pattern)
-- in two columns. The game places a row by the panel's width: it is shown
-- half of it while it does, and the second half of the rows is then moved
-- right and up.
local vanillaArrangeRow = CharacterCreationMain.arrangeClothingRightSideElements
function CharacterCreationMain:arrangeClothingRightSideElements(bodyLocation)
    vanillaArrangeRow(self, bodyLocation)
    local lay = oursMain(self) and self.knoxCloth
    if not lay or not lay.second[bodyLocation] then return end
    for i = 1, 5 do
        local el = clothingParts(self, bodyLocation)[i]
        if el then el:setX(el:getX() + lay.dx) end
    end
end

local vanillaArrangeClothing = CharacterCreationMain.arrangeClothingUI
function CharacterCreationMain:arrangeClothingUI()
    if not oursMain(self) or not self.knox or not self.clothingCombo then return vanillaArrangeClothing(self) end
    local panel = self.clothingPanel
    local real = panel.width
    local colW = math.floor((real - 24) / 2)
    -- rows by height, top to bottom (the height the game gave them)
    local rows = {}
    for loc, combo in pairs(self.clothingCombo) do
        for i = 1, 5 do
            local el = clothingParts(self, loc)[i]
            if el and el.knoxY0 == nil then el.knoxY0 = el:getY() end
        end
        table.insert(rows, {loc = loc, y = combo.knoxY0 or combo:getY()})
        local label = self.clothingComboLabel[loc]
        if label then shorten(label, math.floor(colW * 0.34)) end
    end
    table.sort(rows, function(a, b) return a.y < b.y end)
    local half = math.ceil(#rows / 2)
    local lay = {dx = colW, second = {}}
    local lift = (#rows > half) and (rows[half + 1].y - rows[1].y) or 0
    for i, row in ipairs(rows) do
        local second = i > half
        lay.second[row.loc] = second
        for j = 1, 5 do
            local el = clothingParts(self, row.loc)[j]
            if el then el:setY(el.knoxY0 - (second and lift or 0)) end
        end
    end
    self.knoxCloth = lay
    panel.width = colW          -- (what the game's arranging reads)
    local ok, err = pcall(vanillaArrangeClothing, self)
    panel.width = real
    if not ok then print("[Knox] character screen: clothing: " .. tostring(err)) end
    if self.clothingRect then self.clothingRect:setWidth(real - 24) end
    if #rows > 0 then
        local step = (#rows > 1) and (rows[2].y - rows[1].y) or 30
        panel:setScrollHeight(rows[1].y + half * step + T.pad)
    end
end

-- The color picker (skin, hair, clothes): the game's own, in Knox's look -----------
-- A panel of Knox's with a sand frame, Knox's font on the labels, sand
-- sliders, the sand "accept" button, and frames of Knox's grey in place of
-- the white ones round the color field. What it does is the game's: the
-- color changes as it is picked, "Accept" or a click outside closes it.

local function stylePicker(picker)
    local font = S.fieldFont()
    local key = tostring(font)
    if picker.knoxPicker == key then return end
    picker.knoxPicker = key
    picker.backgroundColor = colored(T.color.window, 1)
    picker.borderColor = colored(T.color.accent, 1)
    for _, c in pairs(picker.children or {}) do
        local kind = c.Type
        if kind == "ISLabel" then
            if font then
                c.font = font
                c:setWidthToName()
            end
            c.r, c.g, c.b = T.color.dim.r, T.color.dim.g, T.color.dim.b
        elseif kind == "ISSliderPanel" then
            S.slider(c)
        elseif kind == "ISButton" then
            S.primary(c)
        end
    end
    if picker.knoxHooked then return end
    picker.knoxHooked = true
    if picker.colors and picker.columns and picker.buttonSize then
        -- The palette (skin, hair): swatches with a little air between them
        -- in frames of Knox's; the chosen one in sand, the one under the
        -- mouse in a light frame. Where a swatch is stays the game's, so its
        -- clicks land as before.
        picker.render = function(el)
            local size, edge = el.buttonSize, el.borderSize or 0
            local mx, my = el:getMouseX(), el:getMouseY()
            for i, color in ipairs(el.colors) do
                local x = edge + ((i - 1) % el.columns) * size
                local y = edge + math.floor((i - 1) / el.columns) * size
                el:drawRect(x + 2, y + 2, size - 4, size - 4, 1, color.r, color.g, color.b)
                local hot = mx >= x and mx < x + size and my >= y and my < y + size
                if i == el.index then
                    T.tileFrame(el, x, y, size, size, T.color.accent)
                elseif hot then
                    T.tileFrame(el, x, y, size, size, T.color.bright)
                else
                    T.border(el, x + 2, y + 2, size - 4, size - 4, T.color.ink)
                end
            end
            T.tileFrame(el, 0, 0, el.width, el.height, T.color.accent)
        end
        return
    end
    local border = picker.drawRectBorder
    picker.drawRectBorder = function(el, x, y, w, h, a, r, g, b)
        if r == 1 and g == 1 and b == 1 then
            local k = T.color.tileFrame
            return border(el, x, y, w, h, a, k.r, k.g, k.b)
        end
        return border(el, x, y, w, h, a, r, g, b)
    end
    local render = picker.render
    picker.render = function(el)
        render(el)
        T.tileFrame(el, 0, 0, el.width, el.height, T.color.accent)   -- the 2 px frame of Knox's windows
    end
end

local vanillaShowPicker = CharacterCreationMain.showColorPicker
function CharacterCreationMain:showColorPicker(picker)
    vanillaShowPicker(self, picker)
    if oursMain(self) and picker then pcall(stylePicker, picker) end
end

-- Layout --------------------------------------------------------------------------

--- The wheel turns a list by whole rows, so no row is ever cut in half.
local function wheelByRows(list, turn)
    local step = list.itemheight
    local most = math.max(0, list:getScrollHeight() - list:getHeight())
    local y = -list:getYScroll() + turn * step
    y = math.max(0, math.min(most, math.floor(y / step + 0.5) * step))
    list.smoothScrollTargetY = nil
    list.smoothScrollY = nil
    list:setYScroll(-y)
    return true
end

local function newList(self, draw, click)
    local list = ISScrollingListBox:new(0, 0, 100, 100)
    list:initialise()
    list:instantiate()
    list.drawBorder = false
    list.backgroundColor = {r = 0, g = 0, b = 0, a = 0}
    list.borderColor = {r = 0, g = 0, b = 0, a = 0}
    list.knoxBar = true
    list.doDrawItem = draw
    list.onMouseWheel = wheelByRows
    list:setOnMouseDownFunction(self, click)
    self:addChild(list)
    return list
end

local function setTab(self, id)
    self.knoxTab = id
    self.knoxInfo = nil
    local k = keeper()
    local build = id == "prof" or id == "traits"
    self.knoxProfs:setVisible(id == "prof")
    self.knoxTraits:setVisible(id == "traits")
    self.characterPanel:setVisible(id == "look")
    self.clothingPanel:setVisible(id == "clothes")
    k.presetPanel:setVisible(build)
    k.randomButton:setVisible(build)
    k.resetButton:setVisible(build)
    self.presetPanel:setVisible(not build)
    self.randomButton:setVisible(not build)
end

--- Once: the two lists, and what is borrowed from the hidden occupation
--- screen for the bottom row (its builds, "Random", "Reset traits").
local function setup(self)
    local k = keeper()
    self.knoxProfs = newList(self, drawProf, clickProf)
    self.knoxTraits = newList(self, drawTrait, clickTrait)
    for _, el in ipairs({k.presetPanel, k.randomButton, k.resetButton}) do
        k:removeChild(el)
        self:addChild(el)
    end
    -- The bottom row is placed by hand. The game ties these to the bottom or
    -- right edge of what they are in, and the engine moves them when that
    -- changes its size (the saved builds dropped below "Back"): untied.
    for _, el in ipairs({self.presetPanel, self.savedBuilds, self.saveBuildButton, self.deleteBuildButton,
            k.presetPanel, k.savedBuilds, k.saveBuildButton, k.deleteBuildButton, k.randomButton, k.resetButton,
            self.randomButton, self.backButton, self.playButton}) do
        el:setAnchorLeft(true)
        el:setAnchorRight(false)
        el:setAnchorTop(true)
        el:setAnchorBottom(false)
    end
    self.characterPanel.positionRelativeToScrollBar = arrangeLook
    -- (an off button here is only dimmed: the game frames it in red on black)
    local quiet = function(button, on) button.enable = on end
    self.playButton.setEnable = quiet
    self.deleteBuildButton.setEnable = quiet
    k.deleteBuildButton.setEnable = quiet
    -- the screen's own clicks: tabs, filters, the chips of chosen traits
    local down = self.onMouseDown
    self.onMouseDown = function(el, x, y)
        if oursMain(el) and el.knox then
            for _, t in ipairs(el.knox.tabs) do
                if T.inRect(x, y, t.rect) then
                    setTab(el, t.id)
                    getSoundManager():playUISound("UIActivateTab")
                    return true
                end
            end
            if el.knoxTab == "traits" then
                for _, f in ipairs(el.knox.filters) do
                    if T.inRect(x, y, f.rect) then
                        el.knoxFilter = f.id
                        return true
                    end
                end
            end
            for _, chip in ipairs(el.knoxChips or {}) do
                if T.inRect(x, y, chip.rect) then
                    local kp = keeper()
                    kp:removeTrait(chip.index)
                    kp:checkXPBoost()
                    return true
                end
            end
        end
        if down then return down(el, x, y) end
    end
    -- the wheel over the summary scrolls its traits and skills (drawSummary)
    local wheel = self.onMouseWheel
    self.onMouseWheel = function(el, del)
        if oursMain(el) and el.knoxSumArea and (el.knoxSumMax or 0) > 0
                and T.inRect(el:getMouseX(), el:getMouseY(), el.knoxSumArea) then
            local step = math.floor(T.cell * 0.6)
            el.knoxSumScroll = math.max(0, math.min(el.knoxSumMax, (el.knoxSumScroll or 0) + del * step))
            return true
        end
        if wheel then return wheel(el, del) end
        return false
    end
    local centre = self.drawTextCentre
    self.drawTextCentre = function(el, text, x, y, r, g, b, a, font)
        if font == UIFont.Large and oursMain(el) then return end   -- the game's title: ours is in the header
        return centre(el, text, x, y, r, g, b, a, font)
    end
    -- the preview's own grey frame: a sand one is drawn round it instead
    local avatar = self.avatarPanel
    local border = avatar.drawRectBorder
    avatar.drawRectBorder = function(el, x, y, w, h, a, r, g, b)
        if r == 0.3 and g == 0.3 and b == 0.3 then return end
        return border(el, x, y, w, h, a, r, g, b)
    end
    self.knoxFilter = "all"
    self.knoxSetup = true
end

--- A row of buttons of height `h` from `x` to the right; returns the next x.
local function rowOf(buttons, x, y, h, gap)
    for _, b in ipairs(buttons) do
        S.plain(b)
        S.fitButton(b, h)
        b:setX(x)
        b:setY(y)
        x = x + b.width + gap
    end
    return x
end

local function layoutPresets(panel, combo, save, delete, x, y, h, font)
    local gap = math.floor(T.pad / 2)
    S.combo(combo, font, math.floor(T.cell * 5), h)
    combo:setX(0)
    combo:setY(0)
    local nx = rowOf({save, delete}, combo.width + gap, 0, h, gap)
    panel:setX(x)
    panel:setY(y)
    panel:setWidth(nx - gap)
    panel:setHeight(h)
end

local function layout(self)
    T.ensure()
    if not self.knoxSetup then setup(self) end
    local k = keeper()
    local W, H = self.width, self.height
    local c, pad = T.cell, T.pad
    local side = S.side(self)
    local btnH = math.floor(c * 0.8)
    local top = S.headerHeight() + pad * 2
    local bottom = H - btnH - pad * 4
    local colH = bottom - top
    local gap = pad * 2
    local font = S.fieldFont()
    self.backgroundColor = {r = 0.02, g = 0.022, b = 0.022, a = S.VEIL}
    self.borderColor = {r = 0, g = 0, b = 0, a = 0}

    -- left: the summary; middle: the preview, as wide as its height asks (1 : 2)
    local sumW = math.floor(math.min(c * 7, (W - side * 2) * 0.22))
    local avatar = self.avatarPanel
    local under = getTextManager():getFontHeight(UIFont.Small) + 6 + 10   -- the preview's own row under the model
    local avH = colH
    local avW = math.floor((avH - under) / 2) + 8
    local most = math.floor((W - side * 2) * 0.3)
    if avW > most then
        avW = most
        avH = (avW - 8) * 2 + under
    end
    local ax = side + sumW + gap
    avatar:setX(ax)
    avatar:setY(top + math.floor((colH - avH) / 2))
    avatar:setWidth(avW)
    avatar:setHeight(avH)
    avatar:rescaleAvatarViewer()
    if avatar.animCombo then S.combo(avatar.animCombo, font) end

    -- right: the tabs over what is being changed
    local rx = ax + avW + gap
    local rw = W - side - rx
    local tabH = T.fontH(T.fontTab) + pad * 2
    local lay = {sum = {side, top, sumW, colH}, avatar = {ax, top, avW, colH}, right = {rx, top, rw, colH}, tabs = {}, filters = {}}
    local tx = rx
    for _, tab in ipairs(TABS) do
        local text = T.upper(getText(tab.text))
        local tw = T.measure(T.fontTab, text) + pad * 4
        table.insert(lay.tabs, {id = tab.id, text = text, rect = {tx, top, tw, tabH}})
        tx = tx + tw
    end
    local ctop = top + tabH + pad
    -- the info box is as high as a title and four lines; a list above it
    -- takes whole rows only, what is left over goes to the box
    local infoH = T.fontH(T.fontHeader) + (T.fontH(T.fontText) + 4) * 4 + pad * 2
    local filterH = T.fontH(T.fontCaps) + pad
    local profRow, traitRow = math.floor(c * 1.25), math.floor(c * 0.72)
    local profTop, traitTop = ctop, ctop + filterH + pad
    local profH = math.floor((bottom - infoH - pad - profTop) / profRow) * profRow
    local traitH = math.floor((bottom - infoH - pad - traitTop) / traitRow) * traitRow
    lay.infoProf = {rx, profTop + profH + pad, rw, bottom - (profTop + profH + pad)}
    lay.infoTraits = {rx, traitTop + traitH + pad, rw, bottom - (traitTop + traitH + pad)}
    local fx = rx
    for _, f in ipairs(FILTERS) do
        local text = T.upper(getText(f.text))
        local fw = T.measure(T.fontCaps, text) + pad * 3
        table.insert(lay.filters, {id = f.id, text = text, rect = {fx, ctop, fw, filterH}})
        fx = fx + fw + math.floor(pad / 2)
    end
    local profs, traits = self.knoxProfs, self.knoxTraits
    profs.itemheight = profRow
    traits.itemheight = traitRow
    for _, it in ipairs(profs.items) do it.height = profRow end
    for _, it in ipairs(traits.items) do it.height = traitRow end
    profs:setX(rx)
    profs:setY(profTop)
    profs:setWidth(rw)
    profs:setHeight(profH)
    traits:setX(rx)
    traits:setY(traitTop)
    traits:setWidth(rw)
    traits:setHeight(traitH)
    -- the game's two panels take the whole column under the tabs
    for _, panel in ipairs({self.characterPanel, self.clothingPanel}) do
        panel:setX(rx + pad)
        panel:setY(ctop + pad)
        panel:setWidth(rw - pad * 2)
        panel:setHeight(bottom - ctop - pad * 2)
        panel.knoxBar = true
    end
    lay.panel = {rx, ctop, rw, bottom - ctop}

    -- bottom: Back, the saved builds / outfits; Random (and Reset), Play
    local by = H - btnH - pad * 2
    S.plain(self.backButton)
    S.fitButton(self.backButton, btnH)
    self.backButton:setX(side)
    self.backButton:setY(by)
    local px = side + self.backButton.width + pad * 2
    layoutPresets(k.presetPanel, k.savedBuilds, k.saveBuildButton, k.deleteBuildButton, px, by, btnH, font)
    layoutPresets(self.presetPanel, self.savedBuilds, self.saveBuildButton, self.deleteBuildButton, px, by, btnH, font)
    S.primary(self.playButton)
    S.fitButton(self.playButton, btnH)
    self.playButton:setX(W - side - self.playButton.width)
    self.playButton:setY(by)
    local half = math.floor(pad / 2)
    for _, b in ipairs({self.randomButton, k.randomButton}) do
        S.plain(b)
        S.fitButton(b, btnH)
        b:setX(self.playButton.x - half - b.width)
        b:setY(by)
    end
    S.plain(k.resetButton)
    S.fitButton(k.resetButton, btnH)
    k.resetButton:setX(k.randomButton.x - half - k.resetButton.width)
    k.resetButton:setY(by)

    self.knox = lay
    self.knoxInfoFor = nil
    self.knoxStyleAt = 0
    setTab(self, self.knoxTab or "prof")
end

-- Drawing -------------------------------------------------------------------------

local function drawSummary(self)
    local k, pad = self.knox, T.pad
    local kp = keeper()
    local r = k.sum
    T.rect(self, r[1], r[2], r[3], r[4], T.color.window, 0.96)
    T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.tileFrame)
    T.rect(self, r[1], r[2], 4, r[4], T.color.accent)
    local x, w = r[1] + pad * 2, r[3] - pad * 4
    local y = r[2] + pad * 2
    local limit = r[2] + r[4] - pad
    local name = ""
    if self.forenameEntry and self.surnameEntry then
        name = (self.forenameEntry:getText() or "") .. " " .. (self.surnameEntry:getText() or "")
    end
    local titleFont = T.javaFonts and T.makeFont("title", math.min(44, T.cell * 0.55)) or UIFont.Large
    for _, line in ipairs(T.wrap(name, titleFont, w)) do
        T.text(self, line, x, y, T.color.bright, titleFont)
        y = y + T.fontH(titleFont)
    end
    if kp.profession then
        T.text(self, T.fit(kp.profession:getUIName() or "", T.fontHeader, w), x, y, T.color.accent, T.fontHeader)
        y = y + T.fontH(T.fontHeader)
    end
    y = y + pad
    T.rect(self, x, y, w, 1, T.color.border)
    y = y + pad

    -- points
    local points = kp:PointToSpend()
    T.text(self, T.upper(getText("IGUI_Knox_Char_Points")), x, y, T.color.dim, T.fontCaps)
    y = y + T.fontH(T.fontCaps) + 2
    local big = T.javaFonts and T.makeFont("title", math.min(44, T.cell * 0.7)) or UIFont.Large
    T.text(self, (points > 0 and "+" or "") .. tostring(points), x, y, points < 0 and T.color.bad or T.color.good, big)
    y = y + T.fontH(big)
    if points < 0 then
        for _, line in ipairs(T.wrap(getText("IGUI_Knox_Char_NoPoints"), T.fontTile, w)) do
            T.text(self, line, x, y, T.color.bad, T.fontTile)
            y = y + T.fontH(T.fontTile) + 1
        end
    end
    y = y + pad

    -- The chosen traits and the skills under them scroll with the wheel when
    -- they are longer than the column (Tatsuya, 2026-10-19: with many traits the
    -- skills could not be seen). The name, the occupation and the points stay.
    local top = y
    local scroll = math.max(0, math.min(self.knoxSumScroll or 0, self.knoxSumMax or 0))
    self.knoxSumScroll = scroll
    self.knoxSumArea = {r[1], top, r[3], limit - top}
    y = y - scroll
    self:setStencilRect(r[1], top, r[3], limit - top)

    -- the chosen traits as chips; a click gives one back (not a granted one)
    local items = kp.listboxTraitSelected.items
    T.text(self, T.upper(getText("IGUI_Knox_Char_Traits")) .. "  " .. string.char(183) .. "  " .. tostring(#items), x, y, T.color.dim, T.fontCaps)
    y = y + T.fontH(T.fontCaps) + math.floor(pad / 2)
    self.knoxChips = {}
    self.knoxChipTip = nil
    local mx, my = self:getMouseX(), self:getMouseY()
    local seen = my >= top and my < limit   -- (the mouse over the part of the list that is shown)
    local chipH = T.fontH(T.fontTile) + 8
    local cx = x
    if #items == 0 then
        T.text(self, getText("IGUI_Knox_Char_NoTraits"), x, y, T.color.dim, T.fontTile)
        y = y + chipH
    else
        for i, it in ipairs(items) do
            local def = it.item
            local label = T.fit(def:getLabel() or "", T.fontTile, w - 14)
            local cw = T.measure(T.fontTile, label) + 14
            if cx + cw > x + w and cx > x then
                cx = x
                y = y + chipH + 4
            end
            local cost = def:getCost()
            local color = def:isFree() and T.color.tileFrame or (cost > 0 and T.color.good or T.color.bad)
            local rect = {cx, y, cw, chipH}
            local over = seen and T.inRect(mx, my, rect)
            if over then self.knoxChipTip = {def = def, rect = rect} end
            local hot = not def:isFree() and over
            T.rect(self, cx, y, cw, chipH, hot and T.color.header or T.color.cell)
            T.tileFrame(self, cx, y, cw, chipH, hot and T.color.accent or color)
            T.text(self, label, cx + 7, y + 4, def:isFree() and T.color.dim or T.color.bright, T.fontTile)
            if not def:isFree() and y + chipH > top and y < limit then table.insert(self.knoxChips, {rect = rect, index = i}) end
            cx = cx + cw + 4
        end
        y = y + chipH
    end
    y = y + pad * 2

    -- skills the survivor starts with
    T.text(self, T.upper(getText("IGUI_Knox_Char_Skills")), x, y, T.color.dim, T.fontCaps)
    y = y + T.fontH(T.fontCaps) + math.floor(pad / 2)
    local lh = T.fontH(T.fontTile) + 10
    for _, it in ipairs(kp.listboxXpBoost.items) do
        local level = math.max(0, math.min(10, it.item.level or 0))
        T.text(self, T.fit(it.text or "", T.fontTile, w - pad * 3), x, y, T.color.text, T.fontTile)
        T.textRight(self, tostring(level), x + w, y, T.color.bright, T.fontTile)
        T.rect(self, x, y + T.fontH(T.fontTile) + 2, w, 3, T.color.cell)
        T.rect(self, x, y + T.fontH(T.fontTile) + 2, math.floor(w * level / 10), 3, T.color.accent)
        y = y + lh
    end
    self:clearStencilRect()
    -- how far it scrolls; a thin sand bar on the right edge shows where it is
    local content = y + scroll - top
    local view = limit - top
    self.knoxSumMax = math.max(0, content - view)
    if self.knoxSumMax > 0 then
        local barH = math.max(T.cell, math.floor(view * view / content))
        local barY = top + math.floor((view - barH) * scroll / self.knoxSumMax)
        T.rect(self, r[1] + r[3] - 4, barY, 3, barH, T.color.accent)
    end
end

local function drawRight(self)
    local k, pad = self.knox, T.pad
    local tab = self.knoxTab
    local mx, my = self:getMouseX(), self:getMouseY()
    -- tabs: the open one has the sand line of an active tab
    local r = k.right
    T.rect(self, r[1], r[2] + k.tabs[1].rect[4] - 2, r[3], 2, T.color.border)
    for _, t in ipairs(k.tabs) do
        local on = t.id == tab
        local hot = T.inRect(mx, my, t.rect)
        local tr = t.rect
        if on then T.rect(self, tr[1], tr[2] + tr[4] - 4, tr[3], 4, T.color.accent) end
        T.textCentre(self, t.text, tr[1] + math.floor(tr[3] / 2), tr[2] + math.floor((tr[4] - T.fontH(T.fontTab)) / 2) - 2,
            on and T.color.bright or (hot and T.color.text or T.color.dim), T.fontTab)
    end
    if tab == "look" or tab == "clothes" then
        local p = k.panel
        T.rect(self, p[1], p[2], p[3], p[4], T.color.window, 0.96)
        T.tileFrame(self, p[1], p[2], p[3], p[4], T.color.tileFrame)
        return
    end
    if tab == "traits" then
        for _, f in ipairs(k.filters) do
            local on = f.id == self.knoxFilter
            local fr = f.rect
            T.rect(self, fr[1], fr[2], fr[3], fr[4], on and T.color.accent or T.color.cell)
            T.tileFrame(self, fr[1], fr[2], fr[3], fr[4], on and T.color.accent or (T.inRect(mx, my, fr) and T.color.tileHover or T.color.tileEdge))
            T.textCentre(self, f.text, fr[1] + math.floor(fr[3] / 2), fr[2] + math.floor((fr[4] - T.fontH(T.fontCaps)) / 2),
                on and T.color.ink or T.color.text, T.fontCaps)
        end
    end
    -- the info box: what the row under the mouse is
    local b = (tab == "traits") and k.infoTraits or k.infoProf
    T.rect(self, b[1], b[2], b[3], b[4], T.color.window, 0.96)
    T.tileFrame(self, b[1], b[2], b[3], b[4], T.color.tileFrame)
    local x, y, w = b[1] + pad * 2, b[2] + pad, b[3] - pad * 4
    local info = self.knoxInfo
    local lh = T.fontH(T.fontText) + 4
    if not info then
        for _, line in ipairs(T.wrap(getText("IGUI_Knox_Char_Hint"), T.fontText, w)) do
            T.text(self, line, x, y, T.color.dim, T.fontText)
            y = y + lh
        end
        return
    end
    if self.knoxInfoFor ~= info then
        self.knoxInfoFor = info
        self.knoxInfoLines = {}
        for _, para in ipairs(paragraphs(info.text)) do
            for _, line in ipairs(T.wrap(para, T.fontText, w)) do table.insert(self.knoxInfoLines, line) end
        end
    end
    local nw = info.note and T.measure(T.fontHeader, info.note) or 0
    T.text(self, T.fit(info.title or "", T.fontHeader, w - nw - pad), x, y, T.color.bright, T.fontHeader)
    if info.note then T.text(self, info.note, x + w - nw, y, info.noteColor or T.color.dim, T.fontHeader) end
    y = y + T.fontH(T.fontHeader) + math.floor(pad / 2)
    for _, line in ipairs(self.knoxInfoLines) do
        if y + lh > b[2] + b[4] - math.floor(pad / 2) then break end
        T.text(self, line, x, y, T.color.text, T.fontText)
        y = y + lh
    end
end

--- What the trait chip under the mouse is: a Knox tooltip next to it (drawn
--- after the screen's children, over them).
local function drawChipTip(self)
    local tip = self.knoxChipTip
    if not tip or not self.knox then return end
    local def, pad = tip.def, T.pad
    if self.knoxTipFor ~= def then
        self.knoxTipFor = def
        self.knoxTipLines = {}
        local w = math.floor(T.cell * 7)
        for _, para in ipairs(paragraphs(def:getDescription())) do
            for _, line in ipairs(T.wrap(para, T.fontText, w - pad * 2)) do table.insert(self.knoxTipLines, line) end
        end
    end
    local cost = def:getCost()
    local note = def:isFree() and getText("IGUI_Knox_Char_Granted") or ((cost > 0 and "-" or "+") .. tostring(math.abs(cost)))
    local noteColor = def:isFree() and T.color.dim or (cost > 0 and T.color.good or T.color.bad)
    local title = def:getLabel() or ""
    local lh = T.fontH(T.fontText) + 3
    local w = math.floor(T.cell * 7)
    w = math.max(w, T.measure(T.fontHeader, title) + T.measure(T.fontHeader, note) + pad * 4)
    local h = pad + T.fontH(T.fontHeader) + math.floor(pad / 2) + #self.knoxTipLines * lh + pad
    local r = tip.rect
    local x = math.min(self.width - w - pad, r[1] + math.floor(pad / 2))
    local y = r[2] + r[4] + 4
    if y + h > self.height - pad then y = r[2] - h - 4 end
    T.rect(self, x, y, w, h, T.color.window, 0.98)
    T.tileFrame(self, x, y, w, h, T.color.accent)
    T.text(self, title, x + pad, y + pad, T.color.bright, T.fontHeader)
    T.text(self, note, x + w - pad - T.measure(T.fontHeader, note), y + pad, noteColor, T.fontHeader)
    local ty = y + pad + T.fontH(T.fontHeader) + math.floor(pad / 2)
    for _, line in ipairs(self.knoxTipLines) do
        T.text(self, line, x + pad, ty, T.color.text, T.fontText)
        ty = ty + lh
    end
end

local vanillaRender = CharacterCreationMain.render
function CharacterCreationMain:render(...)
    vanillaRender(self, ...)
    if oursMain(self) then pcall(drawChipTip, self) end
end

-- Hooks ---------------------------------------------------------------------------

-- Wherever the game opens the occupation screen, the one screen opens instead.
local vanillaProfVisible = CharacterCreationProfession.setVisible
function CharacterCreationProfession:setVisible(visible, joypadData)
    if visible and oursProf(self) then
        vanillaProfVisible(self, false)
        MainScreen.instance.charCreationMain:setVisible(true, joypadData)
        return
    end
    return vanillaProfVisible(self, visible, joypadData)
end

-- "Back" leaves the way the occupation screen would (it knows where it was come from).
local vanillaOption = CharacterCreationMain.onOptionMouseDown
function CharacterCreationMain:onOptionMouseDown(button, x, y)
    if button and button.internal == "BACK" and oursMain(self) then
        self:setVisible(false)
        keeper():onOptionMouseDown({internal = "BACK"})
        return
    end
    return vanillaOption(self, button, x, y)
end

local vanillaResolution = CharacterCreationMain.onResolutionChange
function CharacterCreationMain:onResolutionChange(...)
    vanillaResolution(self, ...)
    if oursMain(self) then self.knoxKey = nil end
end

local vanillaPrerender = CharacterCreationMain.prerender
function CharacterCreationMain:prerender(...)
    vanillaPrerender(self, ...)
    if not oursMain(self) then return end
    T.ensure()
    local key = tostring(T.cell) .. "/" .. tostring(T.javaFonts) .. "/" .. self.width .. "x" .. self.height
    if self.knoxKey ~= key then
        self.knoxKey = key
        local ok, err = pcall(layout, self)
        if not ok then
            print("[Knox] character screen: " .. tostring(err))
            self.knox = nil
        end
    end
    if not self.knox then return end
    local kp = keeper()
    -- (the game sets this while the occupation screen draws, which it no
    -- longer does; its own code and mods look the screen up by it)
    CharacterCreationProfession.instance = kp
    local ok, err = pcall(function()
        syncProfs(self)
        syncTraits(self)
        -- the game's controls are restyled as they appear (clothing ones come and go)
        local now = getTimestampMs()
        if now >= (self.knoxStyleAt or 0) then
            self.knoxStyleAt = now + 400
            local font = S.fieldFont()
            styleTree(self.characterPanel, font, 0)
            if styleTree(self.clothingPanel, font, 0) then self:arrangeClothingUI() end
        end
        -- (the game sets the appearance panel's scroll height again on every
        -- click in it: the two columns are laid out each frame, it is cheap)
        if self.knoxTab == "look" then self.characterPanel:positionRelativeToScrollBar() end
        self.playButton:setEnable(kp:PointToSpend() >= 0)
        kp.deleteBuildButton:setEnable(kp.savedBuilds.selected ~= 0)
        S.header(self, getText("IGUI_Knox_Char_Title"), 4)
        local a = self.avatarPanel
        local model = a.avatarPanel
        if model then
            T.tileFrame(self, a:getX() + model:getX() - 2, a:getY() + model:getY() - 2, model:getWidth() + 4, model:getHeight() + 4, T.color.accent)
        end
        drawSummary(self)
        drawRight(self)
    end)
    if not ok and self.knoxError ~= err then
        self.knoxError = err
        print("[Knox] character screen: " .. tostring(err))
    end
end
