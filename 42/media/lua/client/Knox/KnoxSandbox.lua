-- New game, step 3 (Sandbox mode): the world's settings - the game's own
-- screen, rebuilt in Knox's look as three columns:
--   left      search, then the pages as cards, the game's first and the
--             mods' after them under headings of their own
--   middle    the chosen page: a row per setting, its name on the left, its
--             control on the right
--   right     help: what the setting under the mouse does and its default;
--             at the bottom the saved sets of settings
--
-- Compatibility with mods is the point of how this is done. The pages, the
-- labels and the controls are the ones the game builds from its list of
-- sandbox options, where every mod's options are too: nothing is created
-- here. They are only moved, recolored and given Knox's font, so a page or
-- an option of any mod shows up by itself, with the control of its type.
-- Reading and writing the values, the presets, the search, the gamepad stay
-- the game's code.

require "OptionScreens/SandboxOptions"
require "Knox/KnoxTheme"
require "Knox/KnoxMenuSkin"

local T = KnoxTheme
local S = KnoxMenuSkin
local DOT = string.char(183)

local function ours()
    return T.on("newgame")
end

local function colored(k, a)
    return {r = k.r, g = k.g, b = k.b, a = a}
end

--- Plain paragraphs of a tooltip (line breaks kept, rich text marks dropped).
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

-- Pages: the game's and the mods' -------------------------------------------------

--- A page of a mod: every option on it was added by a mod.
local function isModPage(page)
    local any = false
    for _, setting in ipairs(page.settings or {}) do
        local option = getSandboxOptions():getOptionByName(setting.name)
        if option then
            local ok, custom = pcall(function() return option:isCustom() end)
            if not ok or not custom then return false end
            any = true
        end
    end
    return any
end

--- The list of pages again: the game's, then the mods' under a heading.
local function group(self)
    local list = self.listbox
    local game, mods = {}, {}
    for _, it in ipairs(list.items) do
        if it.item and it.item.page then
            table.insert(isModPage(it.item.page) and mods or game, it)
        end
    end
    if #mods == 0 or #game == 0 then return end
    list:clear()
    -- (a heading is an entry without a page: the game's click handler passes
    -- it by; its empty "panel" is what the game's search walks through)
    local function heading(text, count)
        list:addItem(text, {category = true, count = count, panel = {labels = {}}})
    end
    heading(getText("IGUI_Knox_Sandbox_Game"))
    for _, it in ipairs(game) do list:addItem(it.text, it.item) end
    heading(getText("IGUI_Knox_Sandbox_Mods"), #mods)
    for _, it in ipairs(mods) do list:addItem(it.text, it.item) end
    list.selected = 2
end

-- room kept on the list's right for its scroll bar, clear of the cards
local BAR_ROOM = 18

local function drawPage(self, y, item, alt)
    local w, h, pad = self:getWidth(), item.height, T.pad
    if self:getScrollHeight() > self:getHeight() then w = w - BAR_ROOM end
    local data = item.item
    if data.category then
        local text = T.upper(item.text or "")
        if data.count then text = text .. "  " .. DOT .. "  " .. tostring(data.count) end
        local fh = T.fontH(T.fontCaps)
        T.text(self, text, 2, y + h - fh - math.floor(pad / 2), T.color.dim, T.fontCaps)
        return y + h
    end
    local rh = h - math.floor(pad / 2)
    local sel = data.panel ~= nil and data.panel == self.parent.currentPanel
    local hot = self.mouseoverselected == item.index and not self:isMouseOverScrollBar()
    T.rect(self, 0, y, w, rh, sel and T.color.header or T.color.window, 0.96)
    if hot and not sel then self:drawRect(0, y, w, rh, 0.05, 1, 1, 1) end
    T.tileFrame(self, 0, y, w, rh, T.color.tileEdge)
    if sel then S.slideMark(self, item.index, 0, y, w, rh) end
    local color = item.searchFound and T.color.good or (sel and T.color.bright or (hot and T.color.text or T.color.dim))
    local lines = item.knoxLines or {item.text or ""}
    local lh = T.fontH(T.fontText) + 2
    local ty = y + math.floor((rh - #lines * lh) / 2) + 1
    for _, line in ipairs(lines) do
        T.text(self, line, 4 + pad, ty, color, T.fontText)
        ty = ty + lh
    end
    return y + h
end

--- While there are more pages below, the list's bottom goes dark: the last
--- cards fade out into it instead of being cut off by the edge (the author,
--- 2026-10-20). The less is left below, the lighter it is - none at the end.
local FADE_STRIPS = 16
local function fadeBottom(list)
    if list.knoxFade then return end
    list.knoxFade = true
    local render = list.render
    list.render = function(l, ...)
        render(l, ...)
        if not T.active or not ours() then return end
        local h, sh = l:getHeight(), l:getScrollHeight()
        local left = sh - h + l:getYScroll()   -- (pixels still below the bottom)
        if sh <= h or left <= 0 then return end
        local fh = math.floor(T.cell * 1.4)
        local k = math.min(1, left / fh)
        local w = l:getWidth() - BAR_ROOM
        local c = T.color.screen or T.color.cell
        local step = fh / FADE_STRIPS
        for i = 0, FADE_STRIPS - 1 do
            local y0 = math.floor(h - fh + i * step)
            local y1 = math.floor(h - fh + (i + 1) * step)
            local a = k * ((i + 1) / FADE_STRIPS) ^ 1.6 * 0.96
            l:drawRectStatic(0, y0, w, y1 - y0, a, c.r, c.g, c.b)
        end
    end
end

-- The page: rows of settings ------------------------------------------------------

--- The game colors a label white, yellow (changed), grey (off) or green
--- (found by the search): Knox's colors for the same.
local function knoxLabelColor(r, g, b)
    if r == 1 and g == 1 and b == 0 then return T.color.accent end
    if r == 0 and g == 1 and b == 0 then return T.color.good end
    if r < 0.6 and g < 0.6 and b < 0.6 then return T.color.tileFrame end
    return T.color.text
end

local function styleCombo(combo, font, width, height)
    S.combo(combo, font, width, height)   -- (Knox's scroll bar in its drop-down list, Knox's mark)
    combo.knoxMarked = nil   -- (the mark of a changed setting is put on again)
end

local function styleEntry(entry, width, height)
    S.field(entry)
    entry.knoxMarked = nil
    if width then entry:setWidth(width - (entry.knoxInset or 0)) end
    if height then entry:setHeight(height) end
end

--- A setting's label and control, once: Knox's font and colors; its tooltip
--- goes to the help column instead of popping up.
local function styleSetting(panel, name, font, ctlW, ctlH)
    local label, control = panel.labels[name], panel.controls[name]
    panel.knoxTips[name] = label.tooltip
    label.tooltip = nil
    if font then
        label.font = font
        label:setWidthToName()
    end
    label.setColor = function(l, r, g, b)
        local c = knoxLabelColor(r, g, b)
        l.r, l.g, l.b = c.r, c.g, c.b
        -- (the game colors a label twice a frame, white first: its last word counts)
        l.knoxChanged = (r == 1 and g == 1 and b == 0)
    end
    local kind = control.Type
    if kind == "ISComboBox" then
        control.tooltip = nil
        styleCombo(control, font, ctlW, ctlH)
    elseif kind == "ISTextEntryBox" then
        control.tooltip = nil
        styleEntry(control, ctlW, ctlH)
    elseif kind == "SandboxAdvancedControl" then
        -- a number with a list of ready values next to it
        if control.entry then
            control.entry.tooltip = nil
            styleEntry(control.entry, nil, nil)
        end
        if control.combo then
            control.combo.tooltip = nil
            styleCombo(control.combo, font, nil, nil)
        end
    elseif kind == "ISTickBox" then
        control.tooltip = nil
        S.tick(control)
    end
end

--- A changed setting shows on its control too: a sand frame and sand text
--- (`on` false puts the plain look back).
local function markWidget(w, on)
    if not w or w.knoxMarked == on then return end
    local kind = w.Type
    local frame = on and T.color.accent or T.color.tileFrame
    local text = on and T.color.accent or T.color.bright
    if kind == "ISComboBox" then
        w.knoxMarked = on
        w.borderColor = colored(frame, 1)
        w.textColor = colored(text, 1)
    elseif kind == "ISTickBox" then
        w.knoxMarked = on
        w.borderColor = colored(frame, 1)
    elseif kind == "ISTextEntryBox" then
        -- (red green-and-blue-less is the game's mark of a wrong value: kept)
        local bc = w.borderColor
        if bc and bc.g == 0 and bc.b == 0 then return end
        w.knoxMarked = on
        -- (a text box draws a frame of alpha 1 in grey whatever its color)
        w.borderColor = colored(frame, on and 0.99 or 1)
        pcall(function() w:setTextRGBA(text.r, text.g, text.b, 1) end)
    end
end

local function markChanged(control, on)
    if control.Type == "SandboxAdvancedControl" then
        markWidget(control.entry, on)
        markWidget(control.combo, on)
    else
        markWidget(control, on)
    end
end

local function drawRows(panel)
    local k = panel.knoxLay
    if not k then return end
    local screen = panel._instance
    local over = panel:isMouseOver()
    local my = panel:getMouseY()   -- (already in the page's own, scrolled, coordinates)
    local pad = T.pad
    for _, row in ipairs(k.rows) do
        local label, control = panel.labels[row.name], panel.controls[row.name]
        if label and control then markChanged(control, label.knoxChanged == true) end
        if over and my >= row.y and my < row.y + row.h then
            T.rect(panel, 2, row.y, k.right + pad - 2, row.h, T.color.header)
            T.rect(panel, 2, row.y, 3, row.h, T.color.accent)
            if screen then screen.knoxHelp = row.name end
        end
        T.rect(panel, k.x0, row.y + row.h - 1, k.right - k.x0, 1, T.color.border)
    end
    for _, t in ipairs(k.titles) do
        T.text(panel, T.upper(t.text or ""), k.x0, t.y, T.color.bright, T.fontHeader)
        T.rect(panel, k.x0, t.y + T.fontH(T.fontHeader) + 2, math.floor(T.cell * 1.2), 3, T.color.accent)
    end
end

--- The page in the middle column: every setting a row.
local function layoutPanel(self)
    local p, k = self.currentPanel, self.knox
    if not p or not k then return end
    local c, pad = T.cell, T.pad
    local font = S.fieldFont()
    p:setX(k.panel[1])
    p:setY(k.panel[2])
    p:setWidth(k.panel[3])
    p:setHeight(k.panel[4])
    p.backgroundColor = colored(T.color.window, 0.96)
    p.borderColor = colored(T.color.tileFrame, 1)
    -- its scroll bar: Knox's, and on the page's right edge (the game leaves
    -- it where the page's edge was when the page was built)
    p.knoxBar = true
    if p.vscroll then
        pcall(function()
            p.vscroll:setAnchorRight(false)
            p.vscroll:setAnchorLeft(true)
        end)
        p.vscroll:setX(k.panel[3] - (p.vscroll.width or 13) - 2)
        p.vscroll:setHeight(k.panel[4])
    end

    -- once per page: the order of its settings and headings as the game laid
    -- them out (by height), and the hooks into its drawing
    if not p.knoxOrder then
        local order = {}
        for _, name in ipairs(p.settingNames) do
            if p.labels[name] and p.controls[name] then
                table.insert(order, {y = p.labels[name]:getY(), name = name})
            end
        end
        for _, title in ipairs(p.titles or {}) do
            table.insert(order, {y = title:getY() - 0.5, title = title})
            title:setVisible(false)
        end
        table.sort(order, function(a, b) return a.y < b.y end)
        p.knoxOrder = order
        p.knoxTips = {}
        local prerender = p.prerender
        p.prerender = function(panel)
            -- The scroll bar is tied to the page's right edge by the engine,
            -- which moves it a frame after the page's width changes (and the
            -- game changes that width on every visit): put back each frame.
            local bar = panel.vscroll
            if bar then
                local want = panel.width - (bar.width or 13) - 2
                if bar:getX() ~= want then bar:setX(want) end
                if bar:getHeight() ~= panel.height then bar:setHeight(panel.height) end
            end
            prerender(panel)
            drawRows(panel)   -- (inside the page's clip, under its controls)
        end
        -- the game's own grey bar under a hovered control: ours is drawn instead
        local rect = p.drawRect
        p.drawRect = function(panel, x, y, w, h, a, r, g, b)
            if a == 0.3 and r == 0.5 and g == 0.5 and b == 0.5 then return end
            return rect(panel, x, y, w, h, a, r, g, b)
        end
        -- the wheel moves the page about two rows a notch, gliding (the game jumps 40 px)
        S.glidePanel(p, math.floor(c * 1.5))
    end
    local styleKey = tostring(font) .. "/" .. tostring(c)
    local restyle = p.knoxStyleKey ~= styleKey
    p.knoxStyleKey = styleKey

    local ctlW = math.floor(c * 5)
    local ctlH = math.max(math.floor(c * 0.62), getTextManager():getFontHeight(UIFont.Medium) + 6)
    local x0 = pad * 2
    local right = k.panel[3] - pad * 2 - 14   -- (the scroll bar's place)
    local lay = {rows = {}, titles = {}, x0 = x0, right = right}
    local y = pad
    for _, e in ipairs(p.knoxOrder) do
        if e.title then
            y = y + pad
            table.insert(lay.titles, {y = y, text = e.title.name})
            y = y + T.fontH(T.fontHeader) + pad + 5
        else
            if restyle then
                local ok, err = pcall(styleSetting, p, e.name, font, ctlW, ctlH)
                if not ok then print("[Knox] sandbox setting " .. tostring(e.name) .. ": " .. tostring(err)) end
            end
            local label, control = p.labels[e.name], p.controls[e.name]
            local rowH = math.max(control:getHeight(), label:getHeight()) + math.floor(pad * 0.75)
            label:setX(x0)
            label:setY(y + math.floor((rowH - label:getHeight()) / 2))
            control:setX(right - control:getWidth())
            control:setY(y + math.floor((rowH - control:getHeight()) / 2))
            table.insert(lay.rows, {name = e.name, y = y, h = rowH})
            y = y + rowH
        end
    end
    p:setScrollHeight(y + pad)
    p.knoxLay = lay
end

-- The screen ----------------------------------------------------------------------

local function layout(self)
    T.ensure()
    local W, H = self.width, self.height
    local c, pad = T.cell, T.pad
    local side = S.side(self)
    local btnH = math.floor(c * 0.8)
    local top = S.headerHeight() + pad * 2
    local bottom = H - btnH - pad * 4
    local colH = bottom - top
    local gap = math.floor(pad / 2)
    local fieldH = math.max(math.floor(c * 0.7), getTextManager():getFontHeight(UIFont.Medium) + 6)
    local font = S.fieldFont()
    self.backgroundColor = {r = 0.02, g = 0.022, b = 0.022, a = S.VEIL}
    self.borderColor = {r = 0, g = 0, b = 0, a = 0}
    if not self.knoxCentre then
        -- the game's own title in the middle of the top: ours is in the header
        local centre = self.drawTextCentre
        self.knoxCentre = centre
        self.drawTextCentre = function(el, text, x, y, r, g, b, a, f)
            if f == UIFont.Large and ours() then return end
            return centre(el, text, x, y, r, g, b, a, f)
        end
    end

    -- left: the search over the list of pages
    local listW = math.floor(math.min(c * 8, (W - side * 2) * 0.24))
    S.field(self.searchEntry)
    S.placeField(self.searchEntry, side, listW)
    self.searchEntry:setY(top)
    self.searchEntry:setHeight(fieldH)
    local list = self.listbox
    local lh = T.fontH(T.fontText) + 2
    for _, it in ipairs(list.items) do
        if it.item and it.item.category then
            it.height = T.fontH(T.fontCaps) + pad * 2
        else
            it.knoxLines = T.wrap(it.text or "", T.fontText, listW - pad * 3 - 4 - BAR_ROOM)
            it.height = math.max(math.floor(c * 0.8), #it.knoxLines * lh + pad) + gap
        end
    end
    list.doDrawItem = drawPage
    list.knoxBar = true
    list.knoxBarInset = gap   -- (the thumb ends where the last card does, not under its gap)
    -- (and starts where the first card does - "Time", not the heading over it; the author, 2026-10-20)
    local first = list.items[1]
    list.knoxBarTop = (first and first.item and first.item.category) and first.height or 0
    S.glideList(list)
    fadeBottom(list)
    list.drawBorder = false
    list.backgroundColor = {r = 0, g = 0, b = 0, a = 0}
    list.borderColor = {r = 0, g = 0, b = 0, a = 0}
    list:setX(side)
    list:setY(top + fieldH + pad)
    list:setWidth(listW)
    list:setHeight(colH - fieldH - pad + gap)

    -- right: the help, with the sets of settings on its bottom
    local fileW = math.floor(math.min(c * 8, (W - side * 2) * 0.26))
    local fx = W - side - fileW
    local px = side + listW + pad * 2
    local pw = fx - pad * 2 - px
    local tx, tw = fx + pad * 2, fileW - pad * 4
    local labelH = T.fontH(T.fontCaps) + gap
    local k = {panel = {px, top, pw, colH}, file = {fx, top, fileW, colH}, textX = tx, textW = tw}
    local blockH = labelH + fieldH * 3 + gap * 2
    local by = bottom - pad * 2 - blockH
    k.presetLabelY = by
    k.helpBottom = by - pad * 2
    local preset = self.presetPanel
    preset:setX(tx)
    preset:setY(by + labelH)
    preset:setWidth(tw)
    preset:setHeight(blockH - labelH)
    for _, child in pairs(preset.children or {}) do
        if child.Type == "ISLabel" then child:setVisible(false) end
    end
    styleCombo(self.presetList, font, tw, fieldH)
    self.presetList:setX(0)
    self.presetList:setY(0)
    local bx = 0
    for _, b in ipairs({self.savePresetButton, self.deletePresetButton, self.devPresetButton}) do
        S.plain(b)
        S.fitButton(b, fieldH)
        b:setX(bx)
        b:setY(fieldH + gap)
        bx = bx + b.width + gap
        -- (the game turns "Delete" off for its own sets with a red frame on
        -- black: here an off button is only dimmed)
        b.setEnable = function(button, on) button.enable = on end
    end
    -- "Delete" is red (the author, 2026-10-20); off it stays a dimmed dark one
    S.danger(self.deletePresetButton)
    local tick = self.advancedCheckBox
    if font then tick.font = font end
    S.tick(tick)
    -- (what it does is told in the help column, not in the game's pop-up)
    if tick.tooltip then
        self.knoxAdvancedTip = tick.tooltip
        tick.tooltip = nil
    end
    tick:setX(0)
    tick:setY((fieldH + gap) * 2 + math.floor((fieldH - tick:getHeight()) / 2))
    self.knox = k

    local buttonY = H - btnH - pad * 2
    S.plain(self.backButton)
    S.primary(self.playButton)
    S.fitButton(self.backButton, btnH)
    S.fitButton(self.playButton, btnH)
    self.backButton:setX(side)
    self.backButton:setY(buttonY)
    self.playButton:setX(W - side - self.playButton.width)
    self.playButton:setY(buttonY)
    layoutPanel(self)
end

--- A setting's default as the player sees it.
local function defaultText(name, control)
    local ok, text = pcall(function()
        local option = getSandboxOptions():getOptionByName(name)
        if not option then return nil end
        local kind, value = option:getType(), option:getDefaultValue()
        if kind == "boolean" then return getText(value and "UI_Yes" or "UI_No") end
        if kind == "enum" and control and control.getOptionText then return control:getOptionText(value) end
        return tostring(value)
    end)
    return ok and text or nil
end

local function drawHelp(self)
    local k, pad = self.knox, T.pad
    local f = k.file
    T.rect(self, f[1], f[2], f[3], f[4], T.color.window, 0.96)
    T.tileFrame(self, f[1], f[2], f[3], f[4], T.color.tileFrame)
    local x, y = k.textX, f[2] + pad * 2
    local p = self.currentPanel
    local name = self.knoxHelp
    local label = p and name and p.labels[name]
    local lh = T.fontH(T.fontText) + 5
    -- the "Advanced" tick box explains itself here while the mouse is on it
    local tick = self.advancedCheckBox
    local advanced = tick ~= nil and self.knoxAdvancedTip ~= nil and tick:isMouseOver()
    if advanced then label = tick end
    if label then
        if self.knoxHelpFor ~= label then
            self.knoxHelpFor = label
            self.knoxHelpT0 = T.animOn() and getTimestampMs() or nil   -- (the help comes up)
            self.knoxHelpText = {}
            if advanced then
                self.knoxHelpTitle = T.wrap(getText("Sandbox_Advanced"), T.fontHeader, k.textW)
                for _, para in ipairs(paragraphs(self.knoxAdvancedTip)) do
                    table.insert(self.knoxHelpText, T.wrap(para, T.fontText, k.textW))
                end
                self.knoxHelpDefault = nil
            else
                self.knoxHelpTitle = T.wrap(label.name or "", T.fontHeader, k.textW)
                local default = defaultText(name, p.controls[name])
                self.knoxHelpDefault = default
                for _, para in ipairs(paragraphs(p.knoxTips and p.knoxTips[name])) do
                    -- (the game ends a tooltip with "Default = value": shown
                    -- once, as the line of its own below)
                    local own = default ~= nil and default ~= "" and string.find(para, "=", 1, true) ~= nil
                        and string.sub(para, -string.len(default)) == default
                    if not own then table.insert(self.knoxHelpText, T.wrap(para, T.fontText, k.textW)) end
                end
            end
        end
        local e = 1
        if self.knoxHelpT0 then
            local t = math.min(1, (getTimestampMs() - self.knoxHelpT0) / 160)
            if t >= 1 then self.knoxHelpT0 = nil else e = 1 - (1 - t) * (1 - t) end
        end
        for _, line in ipairs(self.knoxHelpTitle) do
            T.text(self, line, x, y, T.color.bright, T.fontHeader, e)
            y = y + T.fontH(T.fontHeader)
        end
        y = y + math.floor(pad / 2)
        T.rect(self, x, y, math.floor(T.cell * 1.5 * (0.4 + 0.6 * e)), 3, T.color.accent, e)
        y = y + 3 + pad
        for _, lines in ipairs(self.knoxHelpText) do
            for _, line in ipairs(lines) do
                if y + lh <= k.helpBottom then T.text(self, line, x, y, T.color.text, T.fontText, e) end
                y = y + lh
            end
            y = y + math.floor(lh * 0.5)
        end
        if self.knoxHelpDefault and y + lh * 2 <= k.helpBottom then
            y = y + math.floor(pad / 2)
            T.text(self, T.upper(getText("IGUI_Knox_Sandbox_Default")), x, y, T.color.dim, T.fontCaps, e)
            y = y + T.fontH(T.fontCaps) + 2
            T.text(self, T.fit(self.knoxHelpDefault, T.fontText, k.textW), x, y, T.color.bright, T.fontText, e)
        end
    else
        for _, line in ipairs(T.wrap(getText("IGUI_Knox_Sandbox_Hint"), T.fontText, k.textW)) do
            T.text(self, line, x, y, T.color.dim, T.fontText)
            y = y + lh
        end
    end
    T.rect(self, x, k.presetLabelY - pad, k.textW, 1, T.color.border)
    T.text(self, T.upper(getText("Sandbox_SavedPresets")), x, k.presetLabelY, T.color.dim, T.fontCaps)
end

local vanillaCreate = SandboxOptionsScreen.create
function SandboxOptionsScreen:create(...)
    vanillaCreate(self, ...)
    if not ours() then return end
    local ok, err = pcall(group, self)
    if not ok then print("[Knox] sandbox screen: pages not grouped: " .. tostring(err)) end
end

local vanillaPanelChange = SandboxOptionsScreen.onPanelChange
function SandboxOptionsScreen:onPanelChange(...)
    vanillaPanelChange(self, ...)
    if not ours() or not self.knox then return end
    self.knoxHelp = nil
    -- another page: it comes up out of the page's dark
    self.knoxPageT0 = T.animOn() and getTimestampMs() or nil
    local ok, err = pcall(layoutPanel, self)
    if not ok then print("[Knox] sandbox screen: page: " .. tostring(err)) end
end

local vanillaPrerender = SandboxOptionsScreen.prerender
function SandboxOptionsScreen:prerender(...)
    vanillaPrerender(self, ...)
    if not ours() then return end
    T.ensure()
    local key = tostring(T.cell) .. "/" .. tostring(T.javaFonts) .. "/" .. self.width .. "x" .. self.height
    if self.knoxKey ~= key then
        self.knoxKey = key
        local ok, err = pcall(layout, self)
        if not ok then
            print("[Knox] sandbox screen: " .. tostring(err))
            self.knox = nil
        end
    end
    if not self.knox then return end
    S.header(self, getText("UI_optionscreen_SandboxOptions"), 3)
    drawHelp(self)
end

-- Over the page (its controls are children of its own, drawn after the
-- screen): the dark a page just turned to comes up out of.
local PAGE_MS = 220
local vanillaRender = SandboxOptionsScreen.render
function SandboxOptionsScreen:render(...)
    vanillaRender(self, ...)
    if not ours() or not self.knox or not self.knoxPageT0 then return end
    local t = math.min(1, (getTimestampMs() - self.knoxPageT0) / PAGE_MS)
    if t >= 1 then
        self.knoxPageT0 = nil
        return
    end
    local e = 1 - (1 - t) * (1 - t)
    local p = self.knox.panel
    T.rect(self, p[1] + 2, p[2] + 2, p[3] - 4, p[4] - 4, T.color.window, 0.9 * (1 - e))
end
