-- New game, step 3: where to start - the game's own screen (the list of
-- towns, the world map, the save's name and the world's seed), rebuilt in
-- Knox's look as three columns:
--   left      the towns as cards (the game's list box, drawn anew)
--   middle    the world map (the game's own, dragged and zoomed as before),
--             in a sand frame
--   right     the chosen town's file: its name and what the game says of it,
--             and at the bottom the save's name and the seed
-- What a choice does, the checks of the save's name, the gamepad stay the
-- game's code. "Random" is not offered. In a running game (a new character
-- after a death, split screen) and without the Java part the game's own
-- screen is left as it is.

require "OptionScreens/MapSpawnSelect"
require "Knox/KnoxTheme"
require "Knox/KnoxMenuSkin"

local T = KnoxTheme
local S = KnoxMenuSkin

local function ours()
    local main = MainScreen.instance
    return T.on("newgame") and not (main and main.inGame)
end

local function rowHeight()
    return math.floor(T.cell * 1.3)
end

--- A description as paragraphs of plain text (the game's rich text marks dropped).
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

--- A town in the list.
local function drawTown(self, y, item, alt)
    local w, h, pad = self:getWidth(), item.height, T.pad
    if self:getScrollHeight() > self:getHeight() then w = w - 18 end   -- (clear of the scroll bar)
    local rh = h - math.floor(pad / 2)
    local sel = self.selected == item.index
    local hot = self.mouseoverselected == item.index and not self:isMouseOverScrollBar()
    T.rect(self, 0, y, w, rh, sel and T.color.header or T.color.window, 0.96)
    if hot and not sel then self:drawRect(0, y, w, rh, 0.05, 1, 1, 1) end
    T.tileFrame(self, 0, y, w, rh, T.color.tileEdge)
    if sel then S.slideMark(self, item.index, 0, y, w, rh) end
    local font = T.fontHeader
    local color = sel and T.color.bright or (hot and T.color.text or T.color.dim)
    T.label(self, T.fit(T.upper(item.text or ""), font, w - pad * 3 - 4), {4 + pad, y, 0, rh}, color, {font = font})
    return y + h
end

--- A text box in Knox's look (S.field: our font, the text off the box's
--- edge, a thick red frame while the value is wrong); placed with S.placeField.
local function field(entry)
    S.field(entry)
    -- (the game marks the save's name right or wrong every frame: the right
    -- one keeps Knox's frame instead of the game's grey)
    if not entry.knoxValid then
        entry.knoxValid = true
        local setValid = entry.setValid
        entry.setValid = function(e, valid)
            if not ours() then return setValid(e, valid) end
            if valid then
                local c = T.color.tileFrame
                e.borderColor = {r = c.r, g = c.g, b = c.b, a = 1}
            else
                e.borderColor = {r = 0.7, g = 0.1, b = 0.1, a = 0.7}
            end
        end
    end
end

--- The game's text panel is kept for one thing: it plays the town's video
--- (the game writes "<video> + description" into it every frame). It is made
--- as large as the video and clips the rest; without a video it is put away.
local MARGIN = 11   -- the panel's own side margins (the game sizes the video by them)
local function showVideo(self, on)
    local rt = self.richText
    if self.knoxVideoOn == on then
        if on then
            -- the video stands a line down in the panel: lifted back; no scrolling
            local off = (rt.videoY and rt.videoY[1]) or (rt.imageY and rt.imageY[1]) or 0
            rt.marginTop = -off
            if rt:getYScroll() ~= 0 then rt:setYScroll(0) end
            if rt.vscroll and rt.vscroll:isVisible() then rt.vscroll:setVisible(false) end
        end
        return
    end
    self.knoxVideoOn = on
    rt.background = false
    rt.onMouseWheel = function() return false end
    if on then
        local v = self.knox.video
        rt:setX(v[1] - MARGIN)
        rt:setY(v[2])
        rt:setWidth(v[3] + MARGIN * 2)
        rt:setHeight(v[4])
        rt:setVisible(true)
    else
        rt:setVisible(false)
        rt:setX(-100)
        rt:setY(-100)
        rt:setWidth(0)
        rt:setHeight(0)
    end
end

local function layout(self)
    T.ensure()
    local W, H = self.width, self.height
    local c, pad = T.cell, T.pad
    local side = S.side(self)
    local btnH = math.floor(c * 0.8)
    local top = S.headerHeight() + pad * 2
    local bottom = H - btnH - pad * 4
    local colH = bottom - top
    self.backgroundColor = {r = 0.02, g = 0.022, b = 0.022, a = S.VEIL}
    self.borderColor = {r = 0, g = 0, b = 0, a = 0}

    -- the game draws its title and a frame round its text panel after this:
    -- the title is dropped, the text panel (replaced by the file) is put away
    if not self.knoxCentre then
        local centre = self.drawTextCentre
        self.knoxCentre = centre
        self.drawTextCentre = function(el, text, x, y, r, g, b, a, font)
            if font == UIFont.Large and ours() then return end
            return centre(el, text, x, y, r, g, b, a, font)
        end
    end
    if not self.knoxBorder then
        -- (the frame is white at 0.3: the only such border this screen draws)
        local border = self.drawRectBorder
        self.knoxBorder = border
        self.drawRectBorder = function(el, x, y, w, h, a, r, g, b)
            if a == 0.3 and r == 1 and g == 1 and b == 1 and ours() then return end
            return border(el, x, y, w, h, a, r, g, b)
        end
        -- the wheel over the town's file turns its description
        local wheel = self.onMouseWheel
        self.onMouseWheel = function(el, turn)
            local k = el.knox
            if ours() and k and k.textRect and T.inRect(el:getMouseX(), el:getMouseY(), k.textRect) then
                local step = turn * T.cell * 0.75
                el.knoxScroll = math.max(0, math.min(el.knoxScrollMax or 0, (el.knoxScroll or 0) + step))
                return true
            end
            -- (over the towns, in case the list itself did not take the wheel)
            local list = el.listbox
            if ours() and list and list:isVisible() and list.onMouseWheel
                    and T.inRect(el:getMouseX(), el:getMouseY(), {list:getX(), list:getY(), list:getWidth(), list:getHeight()}) then
                return list.onMouseWheel(list, turn)
            end
            if wheel then return wheel(el, turn) end
            return false
        end
    end
    self.knoxVideoOn = nil   -- (the text panel is placed by showVideo)

    -- the towns
    local listW = math.floor(math.min(c * 7, (W - side * 2) * 0.2))
    local list = self.listbox
    local rh = rowHeight()
    list.itemheight = rh
    for _, it in ipairs(list.items) do it.height = rh end
    list.doDrawItem = drawTown
    -- The wheel chooses the next town (the one before it turning back), as it
    -- turns the modes: the towns mostly all fit, and a wheel that only scrolled
    -- did nothing (the author, 2026-10-20). The map flies to it as after a click;
    -- a list longer than the column glides to keep it in sight (Knox's bar on
    -- the list's right, its thumb along the cards, not the gap under the last).
    S.glideList(list)
    list.onMouseWheel = function(l, turn)
        local n = #l.items
        if n == 0 then return true end
        local i = math.max(1, math.min(n, (l.selected or 1) + (turn > 0 and 1 or -1)))
        if i == l.selected then return true end
        l.selected = i
        getSoundManager():playUISound("UISelectListItem")
        local top, h = 0, l.items[i].height or l.itemheight
        for j = 1, i - 1 do top = top + (l.items[j].height or l.itemheight) end
        local at = l.knoxGlide or -l:getYScroll()
        if top < at then
            S.glideTo(l, top)
        elseif top + h > at + l:getHeight() then
            S.glideTo(l, top + h - l:getHeight())
        end
        return true
    end
    list.knoxBar = true
    list.knoxBarInset = math.floor(pad / 2)
    list.drawBorder = false
    list.backgroundColor = {r = 0, g = 0, b = 0, a = 0}
    list.borderColor = {r = 0, g = 0, b = 0, a = 0}
    list:setX(side)
    list:setY(top)
    list:setWidth(listW)
    list:setHeight(colH + math.floor(pad / 2))   -- (a card's gap hangs under the last one)

    -- the town's file on the right, the map takes the middle
    local fileW = math.floor(math.min(c * 8, (W - side * 2) * 0.26))
    local fx = W - side - fileW
    local mx = side + listW + pad * 2
    local mw = fx - pad * 2 - mx
    local map = self.mapPanel
    -- (inside its frame, so that the three columns share their top and bottom)
    map:setX(mx + 2)
    map:setY(top + 2)
    map:setWidth(mw - 4)
    map:setHeight(colH - 4)
    WORLD_MAP_X, WORLD_MAP_Y, WORLD_MAP_W, WORLD_MAP_H = mx + 2, top + 2, mw - 4, colH - 4
    ZOOM_X, ZOOM_Y, ZOOM_SCALE = nil, nil, nil

    -- the fields stand on the file's bottom: the save's name over the seed
    local tx, tw = fx + pad * 2, fileW - pad * 4
    local labelH = T.fontH(T.fontCaps) + math.floor(pad / 2)
    local fieldH = math.max(math.floor(c * 0.7), getTextManager():getFontHeight(UIFont.Medium) + 6)
    -- (each field has Knox's square with a cross next to it, which empties it:
    -- the game's own round one inside the box is turned off)
    local k = {file = {fx, top, fileW, colH}, map = {mx, top, mw, colH}, textX = tx, textW = tw, clears = {}}
    local y = bottom - pad * 2
    if self.seedPanel then
        local seed = self.seedPanel
        y = y - fieldH
        seed.background = false
        seed.backgroundColor = {r = 0, g = 0, b = 0, a = 0}
        seed.borderColor = {r = 0, g = 0, b = 0, a = 0}
        seed:setX(tx)
        seed:setY(y)
        seed:setWidth(tw)
        seed:setHeight(fieldH)
        if seed.seedLabel then seed.seedLabel:setVisible(false) end
        local random = seed.randomButton
        S.plain(random)
        S.fitButton(random, fieldH)
        random:setX(tw - random.width)
        random:setY(0)
        local box = seed.seedTextBox
        field(box)
        local boxW = tw - random.width - fieldH - math.floor(pad / 2) * 2
        S.placeField(box, 0, boxW)
        box:setY(0)
        box:setHeight(fieldH)
        table.insert(k.clears, {rect = {tx + boxW + math.floor(pad / 2), y, fieldH, fieldH}, box = box, owner = seed})
        y = y - labelH
        k.seedLabelY = y
        y = y - pad * 2
    end
    if self.textEntry then
        y = y - fieldH
        field(self.textEntry)
        S.placeField(self.textEntry, tx, tw - fieldH - math.floor(pad / 2))
        self.textEntry:setY(y)
        self.textEntry:setHeight(fieldH)
        table.insert(k.clears, {rect = {tx + tw - fieldH, y, fieldH, fieldH}, box = self.textEntry, owner = self.textEntry})
        y = y - labelH
        k.nameLabelY = y
        y = y - pad * 2
    end
    k.fieldsTop = y
    -- the town's video (16 : 9) stands over the fields, under the description
    local vh = math.floor(tw * 9 / 16)
    k.video = {tx, y - pad - vh, tw, vh}
    self.knox = k
    self.knoxDescFor = nil

    local by = H - btnH - pad * 2
    S.plain(self.backButton)
    S.primary(self.nextButton)
    S.fitButton(self.backButton, btnH)
    S.fitButton(self.nextButton, btnH)
    self.backButton:setX(side)
    self.backButton:setY(by)
    self.nextButton:setX(W - side - self.nextButton.width)
    self.nextButton:setY(by)
end

-- The game's own layout runs when the list is filled and when the screen's
-- size changes: ours follows it with the next frame.
local vanillaSize = MapSpawnSelect.recalculateMapSize
function MapSpawnSelect:recalculateMapSize(...)
    vanillaSize(self, ...)
    self.knoxKey = nil
end

local vanillaFill = MapSpawnSelect.fillList
function MapSpawnSelect:fillList(...)
    if not ours() then return vanillaFill(self, ...) end
    T.ensure()
    self.listbox.itemheight = rowHeight()
    vanillaFill(self, ...)
    -- "Random" is the game's entry without a region: not offered
    local list = self.listbox
    for i = #list.items, 1, -1 do
        local it = list.items[i]
        if it.item and it.item.region == nil then list:removeItemByIndex(i) end
    end
    if list.selected > #list.items then list.selected = math.max(1, #list.items) end
    self.knoxKey = nil
    self.knoxNamed = nil
end

local vanillaPrerender = MapSpawnSelect.prerender
function MapSpawnSelect:prerender(...)
    vanillaPrerender(self, ...)
    if not ours() then return end
    T.ensure()
    local key = tostring(T.cell) .. "/" .. tostring(T.javaFonts) .. "/" .. self.width .. "x" .. self.height
    if self.knoxKey ~= key then
        self.knoxKey = key
        local ok, err = pcall(layout, self)
        if not ok then
            print("[Knox] spawn select screen: " .. tostring(err))
            self.knox = nil
        end
    end
    local k = self.knox
    if not k then return end
    local pad = T.pad
    -- (the game shows its own label of the save's name again with every list)
    if self.textEntryLabel and self.textEntryLabel:isVisible() then self.textEntryLabel:setVisible(false) end
    S.header(self, getText("UI_mapspawn_title"), 2)

    -- the map's frame
    local m = k.map
    T.rect(self, m[1], m[2], m[3], m[4], T.color.cell)
    T.tileFrame(self, m[1], m[2], m[3], m[4], T.color.accent)

    -- the town's file
    local f = k.file
    T.rect(self, f[1], f[2], f[3], f[4], T.color.window, 0.96)
    T.tileFrame(self, f[1], f[2], f[3], f[4], T.color.tileFrame)
    local entry = self.listbox.items[self.listbox.selected]
    local item = entry and entry.item
    local x, y = k.textX, f[2] + pad * 2
    local video = item ~= nil and item.demoVideo ~= nil and item.demoVideo ~= ""
    showVideo(self, video)
    local textBottom = k.fieldsTop
    if video then
        local v = k.video
        textBottom = v[2] - pad
        T.rect(self, v[1], v[2], v[3], v[4], T.color.cell)
        T.tileFrame(self, v[1] - 2, v[2] - 2, v[3] + 4, v[4] + 4, T.color.accent)
    end
    -- a save needs a name: the game's own default again if the field is empty
    if not self.knoxNamed and self.textEntry and self.textEntry:isVisible() then
        self.knoxNamed = true
        if self.textEntry:getInternalText() == "" then
            local sdf = SimpleDateFormat.new("yyyy-MM-dd_HH-mm-ss", Locale.ENGLISH)
            self.textEntry:setText(sdf:format(Calendar.getInstance():getTime()))
        end
    end
    if item then
        if self.knoxDescFor ~= item then
            -- another town: its file comes up (not the first one shown)
            self.knoxFileT0 = (self.knoxDescFor ~= nil and T.animOn()) and getTimestampMs() or nil
            self.knoxDescFor = item
            self.knoxScroll = 0
            self.knoxDesc = {}
            for _, para in ipairs(paragraphs(item.desc)) do
                table.insert(self.knoxDesc, T.wrap(para, T.fontText, k.textW))
            end
        end
        local e = 1
        if self.knoxFileT0 then
            local t = math.min(1, (getTimestampMs() - self.knoxFileT0) / S.MARK_MS)
            if t >= 1 then self.knoxFileT0 = nil else e = 1 - (1 - t) * (1 - t) * (1 - t) end
        end
        local titleFont = T.javaFonts and T.makeFont("title", math.min(44, T.cell * 0.6)) or UIFont.Large
        for _, line in ipairs(T.wrap(T.upper(item.name or ""), titleFont, k.textW)) do
            T.text(self, line, x, y, T.color.bright, titleFont, e)
            y = y + T.fontH(titleFont)
        end
        y = y + math.floor(pad / 2)
        T.rect(self, x, y, math.floor(T.cell * 1.5 * (0.4 + 0.6 * e)), 3, T.color.accent, e)
        y = y + 3 + pad
        local lh = T.fontH(T.fontText) + 5
        local viewTop, viewH = y, textBottom - y
        k.textRect = {f[1], viewTop, f[3], viewH}
        local scroll = self.knoxScroll or 0
        self:setStencilRect(f[1], viewTop, f[3], viewH)
        y = viewTop - scroll
        for _, lines in ipairs(self.knoxDesc) do
            for _, line in ipairs(lines) do
                if y > viewTop - lh and y < viewTop + viewH then T.text(self, line, x, y, T.color.text, T.fontText, e) end
                y = y + lh
            end
            y = y + math.floor(lh * 0.6)
        end
        self:clearStencilRect()
        local contentH = y + scroll - viewTop
        self.knoxScrollMax = math.max(0, contentH - viewH)
        if scroll > self.knoxScrollMax then self.knoxScroll = self.knoxScrollMax end
        if contentH > viewH then
            -- more than fits: a bar on the file's edge, as in the news
            local barH = math.max(T.cell, math.floor(viewH * viewH / contentH))
            local barY = viewTop + math.floor(scroll / self.knoxScrollMax * (viewH - barH))
            T.rect(self, f[1] + f[3] - 9, viewTop, 2, viewH, T.color.border)
            T.rect(self, f[1] + f[3] - 10, barY, 4, barH, T.color.accent)
        end
    end
    if k.nameLabelY and self.textEntry and self.textEntry:isVisible() then
        T.rect(self, x, k.nameLabelY - pad, k.textW, 1, T.color.border)
        T.text(self, T.upper(getText("UI_mapselecter_savename")), x, k.nameLabelY, T.color.dim, T.fontCaps)
    end
    -- the squares that empty the fields (watched here: the seed's one lies
    -- over a panel of the game's, which takes its clicks)
    local down = isMouseButtonDown(0) == true
    local mouseX, mouseY = self:getMouseX(), self:getMouseY()
    for _, cl in ipairs(k.clears) do
        if cl.owner:isVisible() then
            local r = cl.rect
            local hot = T.inRect(mouseX, mouseY, r)
            T.rect(self, r[1], r[2], r[3], r[4], T.color.cell)
            T.closeButton(self, r[1], r[2], r[3], hot)
            if hot and down and not self.knoxWasDown then
                cl.box:setText("")
                cl.box:focus()
                getSoundManager():playUISound("UIActivateButton")
            end
        end
    end
    self.knoxWasDown = down
    if k.seedLabelY and self.seedPanel and self.seedPanel:isVisible() then
        T.text(self, T.upper(getText("UI_advWorld_seed_label")), x, k.seedLabelY, T.color.dim, T.fontCaps)
    end
end
