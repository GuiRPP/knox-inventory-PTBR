-- New game, step 1: the game mode - the game's own screen, rebuilt in Knox's look.
--
-- The screen stays the game's object (what a choice does, the challenges and
-- their pages, the gamepad, "Choose mods" are its own code); its drawing and
-- layout are replaced:
--   on top    the title and the steps of a new game (KnoxMenuSkin.header)
--   left      the modes as a list of cards (the game's six panels, moved and
--             drawn anew: a picture and the name)
--   right     the chosen mode: the game's video of it, its name, what it is
--   bottom    Back, Choose mods, and the sand Next
-- Without the Java part (Knox off) nothing here is touched.

require "OptionScreens/NewGameScreen"
require "Knox/KnoxTheme"
require "Knox/KnoxMenuSkin"

local T = KnoxTheme
local S = KnoxMenuSkin

local VIDEO_W, VIDEO_H = 1920, 658   -- the game's mode videos

-- The order of the modes (the author, 2026-10-20): Sandbox, Apocalypse,
-- Extinction, Outbreak, Rising, Challenges (the game has Sandbox fifth). The
-- table is the one the screen shows and goes back to after the challenges:
-- reordered in place; a mode not named here (a mod's) keeps its place after them.
if T.on("newgame") then
    pcall(function()
        local modes = NewGameScreen.defaultGameModeData
        local rank = {}
        for i, m in ipairs({GameMode.SANDBOX, GameMode.APOCALYPSE, GameMode.EXTINCTION, GameMode.OUTBREAK,
                GameMode.RISING, GameMode.CHALLENGES}) do
            rank[m:toString()] = i
        end
        local was = {}
        for i, data in ipairs(modes) do was[data] = i end
        table.sort(modes, function(a, b)
            local ra, rb = rank[a.mode] or 100 + was[a], rank[b.mode] or 100 + was[b]
            return ra < rb
        end)
    end)
end

-- Turning to another mode: the sand mark slides from the row left to the new
-- one, the chosen mode's name and text come in from the side it was turned
-- to, the video comes up out of the dark.
local TURN_MS = 260

--- How far the turn to the chosen mode is: 0 just turned .. 1 done (eased).
local function turned(self)
    local s = self.knoxTurn
    if not s then return 1 end
    local t = T.anim(math.min(1, (getTimestampMs() - s.t0) / TURN_MS))
    if t >= 1 then
        self.knoxTurn = nil
        return 1
    end
    return 1 - (1 - t) * (1 - t) * (1 - t)
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

--- One mode in the list (drawn in place of the game's panel).
local function drawRow(self)
    if not self.title then return end
    local w, h, pad = self.width, self.height, T.pad
    local sel, hot = self.selected, self.mouseOver
    local screen = self.parent
    local sliding = screen and screen.knoxTurn ~= nil and screen.knoxTurn.from ~= nil
    T.rect(self, 0, 0, w, h, sel and T.color.header or T.color.window, 0.96)
    if hot and not sel then self:drawRect(0, 0, w, h, 0.05, 1, 1, 1) end
    T.tileFrame(self, 0, 0, w, h, T.color.tileEdge)
    -- (while turning, the sand frame is the screen's, sliding over the rows)
    if sel and not sliding then S.chosenFrame(self, 0, 0, w, h) end
    local alpha = sel and 1 or (hot and 0.9 or 0.6)
    local tex = self.texture
    local x = 4 + pad
    if tex then
        local tw, th = math.max(1, tex:getWidth()), math.max(1, tex:getHeight())
        if self.centerThumbnail then
            -- "more" of a long list (the challenges): an arrow alone
            local k = math.min(1, (h - pad * 2) / th)
            self:drawTextureScaled(tex, math.floor((w - tw * k) / 2), math.floor((h - th * k) / 2), tw * k, th * k, alpha, 1, 1, 1)
            return
        end
        local boxH = h - pad * 2
        local boxW = math.floor(math.min(w * 0.4, boxH * 16 / 9))
        local k = math.min(boxW / tw, boxH / th)
        T.rect(self, x, pad, boxW, boxH, T.color.cell)
        self:drawTextureScaled(tex, x + math.floor((boxW - tw * k) / 2), pad + math.floor((boxH - th * k) / 2), tw * k, th * k, alpha, 1, 1, 1)
        T.border(self, x, pad, boxW, boxH, sel and T.color.accent or T.color.border)
        x = x + boxW + pad
    end
    local font = T.fontHeader
    local color = sel and T.color.bright or (hot and T.color.text or T.color.dim)
    T.label(self, T.fit(T.upper(self.title), font, w - x - pad), {x, 0, 0, h}, color, {font = font})
end

--- Where everything stands (the cell's size, the fonts or the screen changed).
local function layout(self)
    T.ensure()
    local W, H = self.width, self.height
    local c, pad = T.cell, T.pad
    local side = S.side(self)
    local headH = S.headerHeight()
    local btnH = math.floor(c * 0.8)
    local top = headH + pad * 2
    local bottom = H - btnH - pad * 4
    self.backgroundColor = {r = 0.02, g = 0.022, b = 0.022, a = S.VEIL}   -- the camp stays seen, dimmed
    self.borderColor = {r = 0, g = 0, b = 0, a = 0}
    self.titleLabel:setVisible(false)

    -- the list
    local n = #self.panels
    local gap = math.floor(pad / 2)
    local listW = math.floor(math.min(c * 9, (W - side * 2) * 0.32))
    local rowH = math.floor(math.min(c * 3.2, (bottom - top - gap * (n - 1)) / n))   -- the list takes the whole height
    for i, panel in ipairs(self.panels) do
        panel.background = false
        panel.render = drawRow
        if panel.richText then panel.richText:setVisible(false) end
        panel:setX(side)
        panel:setY(top + (i - 1) * (rowH + gap))
        panel:setWidth(listW)
        panel:setHeight(rowH)
    end

    -- the chosen mode: a panel with the video on top, as tall as the list
    -- (whole pixels of the rows left it a few short of the column's bottom,
    -- and the panel stood lower than the last card - seen by the author 2026-10-20)
    local dx = side + listW + pad * 2
    local dw = W - side - dx
    local dh = n * rowH + (n - 1) * gap
    -- (the wheel turns the modes, not the video's text panel)
    self.richText.blockMouseWheel = true
    -- The video takes what the text under it leaves (the name and three
    -- lines). It is very wide (about 3 : 1): where the panel is taller than
    -- that, the video is shown higher and cut at its sides (up to 1.6 times).
    local titleFont = T.javaFonts and T.makeFont("title", math.min(44, T.cell * 0.6)) or UIFont.Large
    local lh = T.fontH(T.fontText) + 5
    local textH = pad * 2 + T.fontH(titleFont) + math.floor(pad / 2) + 3 + pad + lh * 3 + pad
    local visW = dw - pad * 2
    local fitH = math.floor(visW * VIDEO_H / VIDEO_W)
    local vh = math.max(c * 3, math.min(dh - pad - textH, math.floor(fitH * 1.6)))
    -- (the videos have a few dark rows on their top edge: shown a little
    -- larger than the frame, which cuts them)
    local crop = math.ceil(vh * 0.02)
    local videoH = vh + crop * 2
    local videoW = math.floor(videoH * VIDEO_W / VIDEO_H)
    local frameW = math.min(visW, videoW - crop * 2)
    local vx = dx + math.floor((dw - frameW) / 2)
    self.richText:setX(vx)
    self.richText:setY(top + pad)
    self.richText:setWidth(frameW)
    self.richText:setHeight(vh)
    self.viewDimensions.previewWidth = videoW
    self.viewDimensions.previewHeight = videoH
    self.knox = {crop = crop, detail = {dx, top, dw, dh}, video = {vx, top + pad, frameW, vh}, textY = top + pad + vh + pad * 2,
        textX = dx + pad * 2, textW = dw - pad * 4, titleFont = titleFont}
    self.knoxDescFor = nil
    self.knoxVideoOff = nil

    -- buttons: back on the left; mods and the way forward on the right
    local by = H - btnH - pad * 2
    S.plain(self.backButton)
    S.plain(self.modsButton)
    S.primary(self.nextButton)
    for _, b in ipairs({self.backButton, self.modsButton, self.nextButton}) do
        S.fitButton(b, btnH)
        b:setY(by)
    end
    self.backButton:setX(side)
    self.nextButton:setX(W - side - self.nextButton.width)
    self.modsButton:setX(self.nextButton.x - pad - self.modsButton.width)
    self:updatePreview()
end

local function layoutKey(self)
    return tostring(T.cell) .. "/" .. tostring(T.javaFonts) .. "/" .. self.width .. "x" .. self.height
end

local vanillaResolution = NewGameScreen.onResolutionChange
function NewGameScreen:onResolutionChange(...)
    vanillaResolution(self, ...)
    if not T.on("newgame") then return end
    self.knoxKey = nil   -- laid out anew with the next frame
end

-- (shown again - back from the next step: the mode it opens on is not a turn)
local vanillaVisible = NewGameScreen.setVisible
function NewGameScreen:setVisible(visible, ...)
    if visible then
        self.knoxShown, self.knoxShownY, self.knoxTurn = nil, nil, nil
    end
    return vanillaVisible(self, visible, ...)
end

local vanillaPrerender = NewGameScreen.prerender
function NewGameScreen:prerender()
    if not T.on("newgame") then return vanillaPrerender(self) end
    T.ensure()
    local key = layoutKey(self)
    if self.knoxKey ~= key then
        self.knoxKey = key
        local ok, err = pcall(layout, self)
        if not ok then
            print("[Knox] new game screen: " .. tostring(err))
            return vanillaPrerender(self)
        end
    end
    local k = self.knox
    if not k then return vanillaPrerender(self) end
    -- The game's text panel puts the video a line down when it is as wide as
    -- the panel: lifted back by as much, so the video fills its frame.
    -- (and it is larger than the frame by `crop` on every side: its top margin
    -- takes both away)
    local rt = self.richText
    local isVideo = rt.videoY and rt.videoY[1] ~= nil
    local off = (isVideo and rt.videoY[1]) or (rt.imageY and rt.imageY[1]) or 0
    rt.marginTop = -(off + (isVideo and k.crop or 0))
    ISPanelJoypad.prerender(self)
    local pad = T.pad
    S.header(self, getText("UI_NewGameScreen_title"), 1)

    -- the chosen mode
    local d, v = k.detail, k.video
    T.rect(self, d[1], d[2], d[3], d[4], T.color.window, 0.96)
    T.tileFrame(self, d[1], d[2], d[3], d[4], T.color.tileFrame)
    T.rect(self, v[1], v[2], v[3], v[4], T.color.cell)
    T.tileFrame(self, v[1] - 2, v[2] - 2, v[3] + 4, v[4] + 4, T.color.accent)
    local item = self.selectedItem
    local data = item and item.data
    -- another mode chosen (a click, the wheel, the gamepad): the turn starts
    -- (not when the screen is first shown with one)
    if data ~= self.knoxShown then
        local fromY = self.knoxShownY
        self.knoxShown = data
        self.knoxShownY = item and item.y or nil
        if fromY and item and T.animOn() then
            self.knoxTurn = {t0 = getTimestampMs(), fromY = fromY, toY = item.y, dir = item.y >= fromY and 1 or -1,
                from = {item.x, fromY, item.width, item.height}}
        end
    end
    local e = turned(self)
    self.knoxTurnK = e
    if not data or data.arrowButton then return end
    if self.knoxDescFor ~= data then
        self.knoxDescFor = data
        self.knoxDesc = {}
        for _, para in ipairs(paragraphs(getText(data.desc))) do
            table.insert(self.knoxDesc, T.wrap(para, T.fontText, k.textW))
        end
    end
    -- (the text comes in from below when the turn went down the list, from above when up)
    local shift = self.knoxTurn and math.floor((1 - e) * T.cell * 0.6 * self.knoxTurn.dir + 0.5) or 0
    local titleFont = k.titleFont
    local y = k.textY
    self:setStencilRect(d[1], d[2], d[3], d[4])
    T.text(self, T.upper(getText(data.title)), k.textX, y + shift, T.color.bright, titleFont, e)
    y = y + T.fontH(titleFont) + math.floor(pad / 2)
    T.rect(self, k.textX, y + shift, math.floor(T.cell * 1.5 * (0.4 + 0.6 * e)), 3, T.color.accent, e)
    y = y + 3 + pad
    local lh = T.fontH(T.fontText) + 5
    local limit = d[2] + d[4] - pad - lh
    for _, lines in ipairs(self.knoxDesc) do
        for _, line in ipairs(lines) do
            if y <= limit then T.text(self, line, k.textX, y + shift, T.color.text, T.fontText, e) end
            y = y + lh
        end
        y = y + math.floor(lh * 0.6)
    end
    self:clearStencilRect()
end

-- Over the children (the video, the rows): the dark the video comes up out
-- of, and the sand mark on its way to the chosen row.
local vanillaRender = NewGameScreen.render
function NewGameScreen:render(...)
    if vanillaRender then vanillaRender(self, ...) end
    if not T.on("newgame") or not self.knox then return end
    local s = self.knoxTurn
    if not s then return end
    local e = self.knoxTurnK or 1
    local v = self.knox.video
    T.rect(self, v[1], v[2], v[3], v[4], T.color.cell, 0.92 * (1 - e))
    -- the chosen row's whole sand frame slides there, as a container's does in the surroundings
    local item = self.selectedItem
    if item and s.from then
        local k, done = S.slideK(s.t0)
        if done then
            s.from = nil
        else
            local r = S.between(s.from, {item.x, item.y, item.width, item.height}, k)
            S.chosenFrame(self, r[1], r[2], r[3], r[4])
        end
    end
end

--- The wheel turns the modes, one row a notch (the arrows of a long list of
--- challenges turn its page, as a click on them does).
local vanillaWheel = NewGameScreen.onMouseWheel
function NewGameScreen:onMouseWheel(del)
    if not T.on("newgame") or not self.knox then
        if vanillaWheel then return vanillaWheel(self, del) end
        return false
    end
    local panels = self.panels
    local at
    for i, p in ipairs(panels) do
        if p == self.selectedItem then at = i end
    end
    if not at then return true end
    local step = del > 0 and 1 or -1
    local i = at + step
    while panels[i] and not panels[i].title do i = i + step end
    local p = panels[i]
    if p and p.title then
        local arrow = p.data and p.data.arrowButton
        self:onItemClick(p, 0, 0)
        if not arrow then self.selectedJoypad = i end
    end
    return true
end
