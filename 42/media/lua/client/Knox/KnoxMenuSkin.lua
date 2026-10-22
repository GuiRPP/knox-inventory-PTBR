-- The game's own menu screens (Load, Options, Mods) in Knox's look.
--
-- They stay the game's: the layout, the lists, every control and what it does.
-- What changes is how they are painted: Knox's panel colors and frames
-- instead of black and white ones, buttons with Knox's capitals and a sand
-- plate under the mouse, sand for the selected row of a list, the screen's
-- title in Knox's font, and a darker veil over the camp behind them.
--
-- Done from outside, element by element, each one once (what the game colors
-- later - a wrong name in red, a green "accept" - is left alone): a screen is
-- walked when it is shown and now and then while it is, for what it builds late.

require "ISUI/ISButton"
require "OptionScreens/MainScreen"
require "Knox/KnoxTheme"

local T = KnoxTheme

KnoxMenuSkin = {}
local S = KnoxMenuSkin

-- how dark the veil over the camp is under a screen (as under an opened news post)
S.VEIL = 0.66

-- The game's logo is drawn by the main screen itself, under every screen it
-- opens: left out while one is open (the menu's items are hidden then).
local vanillaMainPrerender = MainScreen.prerender
function MainScreen:prerender(...)
    local panel = self.bottomPanel
    if not (T.on("menu") or T.on("newgame")) or self.inGame or not panel then
        return vanillaMainPrerender(self, ...)
    end
    local logo = self.logoTexture
    local draw = self.drawTextureScaled
    if panel:getIsVisible() then
        -- The logo is drawn over the camp and everything of it: where a hero's
        -- card comes up under the logo (the left hero on a small screen), the
        -- logo fades out for as long as the card is shown.
        local scene = KnoxMenuScene and KnoxMenuScene.instance
        local card = scene and scene.card
        if not (card and card:getIsVisible()) then return vanillaMainPrerender(self, ...) end
        -- (The logo used to fade as a whole to a tenth: it still showed through the
        -- card, which then looked see-through. Now the logo stays as it is and only
        -- the card's own rectangle is cut out of it: it is drawn in the four pieces
        -- around the card. While the card is coming in or going out, the piece
        -- under it fades with it.)
        local cx, cy, cw, ch = card:getAbsoluteX(), card:getAbsoluteY(), card:getWidth(), card:getHeight()
        local ck = math.max(0, math.min(1, card.k or 1))
        self.drawTextureScaled = function(el, tex, x, y, w, h, a, ...)
            if not (tex == logo and cx < x + w and cx + cw > x and cy < y + h and cy + ch > y) then
                return draw(el, tex, x, y, w, h, a, ...)
            end
            -- The pieces meet on whole pixels, and the side pieces reach a pixel
            -- into the ones above and below. (Cut at the card's own coordinates -
            -- it is on a fraction of a pixel while it rises into place - a row of
            -- the logo fell between two pieces: a line across it from the card's
            -- top edge, seen in game 2026-10-13.)
            local lx = math.floor(cx - el:getAbsoluteX())   -- the card in the element's own coordinates
            local ly = math.floor(cy - el:getAbsoluteY())
            local lx1, ly1 = math.ceil(cx - el:getAbsoluteX() + cw), math.ceil(cy - el:getAbsoluteY() + ch)
            local X0, Y0, X1, Y1 = math.floor(x), math.floor(y), math.ceil(x + w), math.ceil(y + h)
            local top = math.max(Y0, math.min(ly, Y1))      -- where the piece above the card ends
            local bot = math.max(Y0, math.min(ly1, Y1))     -- where the piece below it begins
            local my0, my1 = math.max(Y0, top - 1), math.min(Y1, bot + 1)
            local pieces = {
                {X0, Y0, X1 - X0, top - Y0},                              -- above the card
                {X0, bot, X1 - X0, Y1 - bot},                             -- below it
                {X0, my0, math.min(lx, X1) - X0, my1 - my0},              -- left of it
                {math.max(X0, lx1), my0, X1 - math.max(X0, lx1), my1 - my0},   -- right of it
            }
            for _, p in ipairs(pieces) do
                if p[3] > 0 and p[4] > 0 then
                    el:setStencilRect(p[1], p[2], p[3], p[4])
                    draw(el, tex, x, y, w, h, a, ...)
                    el:clearStencilRect()
                end
            end
            if ck < 1 then
                local ux0, ux1 = math.max(X0, lx), math.min(X1, lx1)
                if ux1 > ux0 and bot > top then
                    el:setStencilRect(ux0, top, ux1 - ux0, bot - top)
                    draw(el, tex, x, y, w, h, (a or 1) * (1 - ck), ...)
                    el:clearStencilRect()
                end
            end
        end
    else
        self.drawTextureScaled = function(el, tex, ...)
            if tex ~= logo then return draw(el, tex, ...) end
        end
    end
    local ok, err = pcall(vanillaMainPrerender, self, ...)
    self.drawTextureScaled = nil
    if not ok then error(err, 0) end
end

-- fields of MainScreen holding the screens that are painted
S.SCREENS = {"loadScreen", "mainOptions", "modSelect"}

--- A grey (black, white): one of the game's own neutral colors, ours to replace.
local function neutral(c)
    return type(c) == "table" and c.r ~= nil and math.abs(c.r - c.g) < 0.08 and math.abs(c.g - c.b) < 0.08
end

local function colored(k, a)
    return {r = k.r, g = k.g, b = k.b, a = a}
end

-- Buttons -------------------------------------------------------------------------

local vanillaRender = ISButton.render

--- A painted button's text: Knox's capitals, dark on the sand plate under the mouse.
function ISButton:render()
    local title = self.title
    if not self.knoxSkin or not T.active or not T.javaFonts or self.image or self.isJoypad
            or type(title) ~= "string" or title == "" then
        return vanillaRender(self)
    end
    self.title = ""
    vanillaRender(self)   -- icons, the mouse-over callback
    self.title = title
    local font = T.fontCaps
    local text = T.upper(title)
    local w = T.measure(font, text)
    if w > self.width - 6 then
        font = T.fontTile
        w = T.measure(font, text)
        if w > self.width - 6 then
            text = T.fit(text, font, self.width - 6)
            w = T.measure(font, text)
        end
    end
    local c = (self.enable == false) and T.color.dim or T.color.bright
    local f = (self.enable ~= false and self.fade) and self.fade:fraction() or 0
    if self.knoxPrimary and self.enable ~= false then c, f = T.color.ink, 0 end   -- a sand button: dark text always
    if self.knoxDanger then f = 0 end   -- a red one: bright text always
    local ink = T.color.ink
    local tc = {r = c.r + (ink.r - c.r) * f, g = c.g + (ink.g - c.g) * f, b = c.b + (ink.b - c.b) * f}
    -- (in the middle by the letters' pixels - the layout kit; it used to be
    -- the font's line moved 2 px down by eye)
    local band = {self.titleLeft and 6 or 0, self.yoffset or 0, self.titleLeft and 0 or self.width, self.height}
    T.label(self, text, band, tc, {font = font, align = self.titleLeft and "left" or "centre"})
end

local function skinButton(b)
    if neutral(b.backgroundColor) then b.backgroundColor = colored(T.color.cell, 0.95) end
    if neutral(b.borderColor) then b.borderColor = colored(T.color.tileFrame, 1) end
    if not b.image and neutral(b.backgroundColorMouseOver) then
        b.backgroundColorMouseOver = colored(T.color.accent, 1)
        b.knoxSkin = true
    end
end

--- Paint a button Knox's way whatever the game colored it (its green "next",
--- its red "back"): `plain` is dark with a sand plate under the mouse,
--- `primary` is the sand one, the screen's way forward.
local function paint(b, bg, hover, border)
    b.backgroundColor = colored(bg, 1)
    b.backgroundColorMouseOver = colored(hover, 1)
    b.borderColor = colored(border, 1)
    -- (what ISButton:setEnable puts back each time)
    b.backgroundColorEnabled = colored(bg, 1)
    b.borderColorEnabled = colored(border, 1)
    b.knoxSkin = true
    b.knoxSkinned = true
end

function S.plain(b)
    paint(b, T.color.buttonBg, T.color.accent, T.color.tileFrame)
    b.knoxPrimary, b.knoxDanger = nil, nil
end

function S.primary(b)
    paint(b, T.color.accent, T.color.bright, T.color.accent)
    b.knoxPrimary, b.knoxDanger = true, nil
end

--- A button that destroys something ("Delete"): red, lighter under the mouse,
--- its text bright on both. Turned off it is a plain dimmed one.
function S.danger(b)
    local red = T.color.bad
    local hot = T.mix(red, T.color.bright, 0.22)
    paint(b, red, hot, red)
    b.knoxPrimary = nil
    b.knoxDanger = true
    b.knoxDangerOn = nil
    b.setEnable = function(button, on)
        button.enable = on
        -- (the game says it every frame: painted again only when it changes)
        if button.knoxDangerOn == on then return end
        button.knoxDangerOn = on
        if on then
            paint(button, red, hot, red)
        else
            paint(button, T.color.buttonBg, T.color.buttonBg, T.color.tileEdge)
        end
    end
    b:setEnable(b.enable ~= false)
end

--- Size a button to its title in Knox's capitals.
function S.fitButton(b, height)
    local font = T.fontCaps
    b:setWidth(T.measure(font, T.upper(b.title or "")) + T.pad * 5)
    b:setHeight(height)
end

-- A screen's top: its name, and where it is on the way to a new game ------------------

-- (the sandbox's settings are the third step, taken in the Sandbox mode only;
-- the choice of a world map, a step of its own with map mods, is not counted)
S.STEPS = {"IGUI_Knox_New_Mode", "IGUI_Knox_New_Spawn", "IGUI_Knox_New_World", "IGUI_Knox_New_Character"}

--- A scroll bar of the game drawn Knox's way: a thin track and a sand thumb,
--- no arrow buttons. For the bars of what is marked `knoxBar` (a list, a
--- panel) and of the drop-down lists of combo boxes marked `knoxCombo`; the
--- bar's own geometry stays the game's, so dragging and clicks work as before.
require "ISUI/ISScrollBar"
local vanillaBar = ISScrollBar.render

local function isKnoxBar(bar)
    if bar.knoxBar then return true end
    local p = bar.parent
    return p ~= nil and (p.knoxBar == true or (p.parentCombo ~= nil and p.parentCombo.knoxCombo == true))
end

-- The thumb runs the bar's whole length: at the top it starts where the first
-- row does, at the bottom it ends where the last one does (the game keeps 16
-- px at each end for its arrow buttons - with none drawn, the thumb stopped
-- short of both ends as if there were more to scroll; the author, 2026-10-20).
-- `knoxBarInset` on the bar's owner: so many pixels at the bottom that are not
-- the list's (the gap under its last card).
function ISScrollBar:render()
    if not T.active or not self.vertical or not isKnoxBar(self) then return vanillaBar(self) end
    local h = self:getHeight()
    local sh = self.parent:getScrollHeight()
    if sh <= h then
        self.barx, self.bary, self.barwidth, self.barheight = 0, 0, 0, 0
        return
    end
    -- (`knoxBarTop`: so many pixels at the top that are not the cards' - a
    -- heading over the first card; the bar starts where the card does)
    local top = self.parent.knoxBarTop or 0
    local track = math.max(8, h - top - (self.parent.knoxBarInset or 0))
    local box = math.max(8, math.floor(track * h / sh + 0.5))
    local dif = math.floor((track - box) * (self.pos or 0) + 0.5)
    self.barx, self.bary, self.barwidth, self.barheight = 5, top + dif, 8, box
    self.knoxTrack = track
    local hot = self.scrolling or (self:isMouseOver() and self:isPointOverThumb(self:getMouseX(), self:getMouseY()))
    local cx = math.floor(self.width / 2)
    if self.doSetStencil then self:setStencilRect(0, 0, self.width, self.height) end
    T.rect(self, cx, top, 2, track, T.color.border)
    T.rect(self, cx - 1, self.bary, 4, box, hot and T.color.bright or T.color.accent)
    if self.doSetStencil then self:clearStencilRect() end
end

-- (no arrow buttons at the ends: a click there is a click on the track)
local vanillaHit = ISScrollBar.hitTest
function ISScrollBar:hitTest(x, y)
    if not T.active or not self.vertical or not isKnoxBar(self) then return vanillaHit(self, x, y) end
    if not self:isPointOver(self:getAbsoluteX() + x, self:getAbsoluteY() + y) then return nil end
    if self:isPointOverThumb(x, y) then return "thumb" end
    if not self.barx or self.barwidth == 0 then return nil end
    if y < self.bary then return "trackUp" end
    return "trackDown"
end

-- (the thumb dragged: the list follows the mouse over the same length the thumb runs)
local vanillaBarMove = ISScrollBar.onMouseMove
function ISScrollBar:onMouseMove(dx, dy)
    if not (self.scrolling and T.active and self.vertical and isKnoxBar(self)) then return vanillaBarMove(self, dx, dy) end
    local owner = self.parent
    local sh, area = owner:getScrollHeight(), owner:getScrollAreaHeight()
    local room = (self.knoxTrack or self:getHeight()) - (self.barheight or 0)
    if sh <= area or room <= 0 then return end
    self.pos = math.max(0, math.min(1, (self.pos or 0) + dy / room))
    owner.knoxGlide = nil
    owner.smoothScrollTargetY, owner.smoothScrollY = nil, nil
    owner:setYScroll(-math.floor(self.pos * (sh - area) + 0.5))
end

-- Gliding scroll ------------------------------------------------------------------
--
-- The wheel over a list of the menu moves it a row a notch (a panel: so many
-- pixels), and it glides there in about a fifth of a second instead of jumping.
-- Without the animations (settings) it is there at once.

--- Glide the scrolled element `el` to `to` pixels from its top.
function S.glideTo(el, to)
    local most = math.max(0, el:getScrollHeight() - el:getHeight())
    to = math.floor(math.max(0, math.min(most, to)) + 0.5)
    el.smoothScrollTargetY, el.smoothScrollY = nil, nil   -- (the game's own glide of a list)
    if not T.animOn() then
        el.knoxGlide = nil
        el:setYScroll(-to)
        return
    end
    el.knoxGlide = to
end

--- A frame of the glide: called before the element draws itself.
function S.glideStep(el)
    local now = getTimestampMs()
    local dt = math.min(100, now - (el.knoxGlideMs or now))
    el.knoxGlideMs = now
    local to = el.knoxGlide
    if not to then return end
    if el.vscroll and el.vscroll.scrolling then
        el.knoxGlide = nil
        return
    end
    to = math.min(to, math.max(0, el:getScrollHeight() - el:getHeight()))
    local cur = -el:getYScroll()
    local nxt = cur + (to - cur) * (1 - math.exp(-dt / 55))
    -- (on whole pixels, at least one a frame: text between two pixels blurs)
    if to > cur then nxt = math.min(to, math.ceil(nxt)) else nxt = math.max(to, math.floor(nxt)) end
    if nxt == to then el.knoxGlide = nil end
    el:setYScroll(-nxt)
end

--- The wheel on a list: to the next row's top (the one before it turning
--- back), so no row is left cut in half at the top.
function S.wheelRows(list, turn)
    local at = list.knoxGlide or -list:getYScroll()
    local tops, y = {}, 0
    for _, it in ipairs(list.items or {}) do
        table.insert(tops, y)
        y = y + (it.height or list.itemheight or 0)
    end
    local to
    if turn > 0 then
        to = y
        for _, top in ipairs(tops) do
            if top > at + 0.5 then to = top break end
        end
    else
        to = 0
        for i = #tops, 1, -1 do
            if tops[i] < at - 0.5 then to = tops[i] break end
        end
    end
    S.glideTo(list, to)
    return true
end

local function glideBeforeDraw(el)
    if el.knoxGlideOn then return end
    el.knoxGlideOn = true
    local prerender = el.prerender
    el.prerender = function(e, ...)
        S.glideStep(e)
        return prerender(e, ...)
    end
end

--- A list of the game (ISScrollingListBox) scrolled a row a notch, gliding.
function S.glideList(list)
    list.onMouseWheel = S.wheelRows
    glideBeforeDraw(list)
end

--- The chosen card's look: the 2 px sand frame with the sand strip on its left.
function S.chosenFrame(ui, x, y, w, h)
    T.tileFrame(ui, x, y, w, h, T.color.accent)
    T.rect(ui, x, y, 4, h, T.color.accent)
end

--- The chosen card of a list, chosen anew: its whole sand frame slides there
--- from the card chosen before, as the chosen container's frame does in the
--- surroundings (KnoxLootPanel: 140 ms, eased; the author wanted that, not a
--- sliding strip alone, 2026-10-20). Asked from the chosen card's doDrawItem
--- with the card's rect in the list. While sliding the frame is drawn over all
--- the cards (it passes over them), after the list has drawn them.
S.MARK_MS = 140
local function markLayer(list)
    if list.knoxMarkLayer then return end
    list.knoxMarkLayer = true
    local render = list.render
    list.render = function(l, ...)
        render(l, ...)
        local d = l.knoxMarkDraw
        l.knoxMarkDraw = nil
        if d then
            l:setStencilRect(0, 0, l.width, l.height)
            S.chosenFrame(l, d[1], d[2], d[3], d[4])
            l:clearStencilRect()
        end
    end
end

--- Where a frame sliding from `from` to `to` (rects) is at `k` (0..1).
function S.between(from, to, k)
    local r = {}
    for i = 1, 4 do r[i] = math.floor(from[i] + (to[i] - from[i]) * k + 0.5) end
    return r
end

--- How far a slide that started at `t0` is: 0..1, eased; 1 when done.
function S.slideK(t0)
    local t = T.anim(math.min(1, (getTimestampMs() - t0) / S.MARK_MS))
    return 1 - (1 - t) * (1 - t), t >= 1
end

function S.slideMark(list, index, x, y, w, h)
    local m = list.knoxMark
    local rect = {x, y, w, h}
    if not m or m.index ~= index then
        -- (from where the card chosen before was drawn last)
        local was = m and m.rect
        list.knoxMark = {index = index, t0 = getTimestampMs(), from = (was and was[2] ~= y and T.animOn()) and was or nil}
        m = list.knoxMark
    end
    m.rect = rect
    if m.from then
        local k, done = S.slideK(m.t0)
        if not done then
            markLayer(list)
            list.knoxMarkDraw = S.between(m.from, rect, k)
            return
        end
        m.from = nil
    end
    S.chosenFrame(list, x, y, w, h)
end

--- A scrolled panel moved `step` pixels a notch, gliding.
function S.glidePanel(panel, step)
    panel.onMouseWheel = function(p, turn)
        if p:getScrollHeight() <= p:getHeight() then return false end
        S.glideTo(p, (p.knoxGlide or -p:getYScroll()) + turn * step)
        return true
    end
    glideBeforeDraw(panel)
end

--- A tick box of the game drawn Knox's way: a framed square, filled with sand
--- when ticked (the game's is a green check mark).
function S.tick(tick)
    if tick.knoxTick then return end
    tick.knoxTick = true
    tick.borderColor = colored(T.color.tileFrame, 1)
    local rect, texture = tick.drawRect, tick.drawTextureScaled
    tick.drawRect = function(el, x, y, w, h, a, r, g, b)
        if r == 0.3 and g == 0.3 and b == 0.3 then
            -- the box under the mouse
            local c = T.color.cell
            rect(el, x, y, w, h, 1, c.r, c.g, c.b)
            T.tileFrame(el, x, y, w, h, T.color.accent)
            return
        end
        return rect(el, x, y, w, h, a, r, g, b)
    end
    tick.drawTextureScaled = function(el, tex, x, y, w, h, a, r, g, b)
        if tex == el.tickTexture then
            local c = T.color.accent
            return rect(el, x + 2, y + 2, w - 4, h - 4, 1, c.r, c.g, c.b)
        end
        return texture(el, tex, x, y, w, h, a, r, g, b)
    end
end

--- A slider of the game in Knox's colors: a dark track, a sand handle.
function S.slider(slider)
    slider.sliderColor = colored(T.color.accent, 1)
    slider.sliderMouseOverColor = colored(T.color.bright, 1)
    slider.sliderBorderColor = colored(T.color.ink, 1)
    slider.sliderBarColor = colored(T.color.cell, 1)
    slider.sliderBarBorderColor = colored(T.color.tileFrame, 1)
    slider.buttonColor = colored(T.color.dim, 1)
    slider.buttonMouseOverColor = colored(T.color.accent, 1)
    -- no arrow buttons at its ends, no "hold a key" pop-up of the game's
    slider.doToolTip = false
    pcall(function()
        slider:deactivateToolTip()
        slider:setDoButtons(false)
    end)
end

-- The game's message boxes ("Quit?", "Delete this save?") in Knox's look: a
-- panel of Knox's in a sand frame, the text in Knox's font, the sand button
-- for "yes" / "ok" and a dark one for "no".
require "ISUI/ISModalDialog"
local vanillaModalInit = ISModalDialog.initialise
function ISModalDialog:initialise(...)
    vanillaModalInit(self, ...)
    -- a box of the main menu goes with the menu's parts, one in game with the menus module
    if getPlayer() then
        if not T.on("menus") then return end
    elseif not (T.on("menu") or T.on("newgame")) then
        return
    end
    pcall(function()
        T.ensure()
        local c, pad = T.cell, T.pad
        self.backgroundColor = colored(T.color.window, 1)
        self.borderColor = colored(T.color.accent, 1)
        local h = math.floor(c * 0.7)
        -- The game sizes a box for its small font and small buttons: made as
        -- large as Knox's text and buttons need, around the same centre.
        if T.javaFonts and type(self.text) == "string" then
            local plain = string.gsub(string.gsub(self.text, "<LINE>", "\n"), "<[^>]*>", "")
            local width = math.max(self.width, math.floor(c * 7))
            local lines = {}
            for line in string.gmatch(plain .. "\n", "([^\n]*)\n") do
                if string.gsub(line, "%s", "") == "" then
                    table.insert(lines, "")
                else
                    for _, piece in ipairs(T.wrap(line, T.fontText, width - pad * 4)) do table.insert(lines, piece) end
                end
            end
            self.knoxTextOf, self.knoxLines = self.text, lines
            local height = pad * 2 + #lines * (T.fontH(T.fontText) + 4) + pad * 2 + h + pad * 2
            local dw, dh = width - self.width, height - self.height
            local nx, ny = self.x - math.floor(dw / 2), self.y - math.floor(dh / 2)
            if self.javaObject then
                self:setX(nx)
                self:setY(ny)
                self:setWidth(width)
                self:setHeight(height)
            else
                -- (not built yet: it is built from these when it is shown)
                self.x, self.y, self.width, self.height = nx, ny, width, height
            end
        end
        local buttons = {}
        for _, name in ipairs({"yes", "no", "ok"}) do
            local b = self[name]
            if b then
                if name == "no" then S.plain(b) else S.primary(b) end
                b:setAnchorTop(true)
                b:setAnchorBottom(false)
                b:setWidth(math.max(math.floor(c * 2.2), T.measure(T.fontCaps, T.upper(b.title or "")) + pad * 4))
                b:setHeight(h)
                table.insert(buttons, b)
            end
        end
        local total = (#buttons - 1) * pad
        for _, b in ipairs(buttons) do total = total + b.width end
        local x = math.floor((self.width - total) / 2)
        for _, b in ipairs(buttons) do
            b:setX(x)
            b:setY(self.height - h - pad * 2)
            x = x + b.width + pad
        end
        -- the text: the game draws it centred in its small font
        local centre = self.drawTextCentre
        self.drawTextCentre = function(el, text, tx, ty, r, g, b, a, font)
            if font ~= UIFont.Small or not T.javaFonts or type(text) ~= "string" then
                return centre(el, text, tx, ty, r, g, b, a, font)
            end
            if el.knoxTextOf ~= text then
                el.knoxTextOf = text
                el.knoxLines = {}
                local plain = string.gsub(string.gsub(text, "<LINE>", "\n"), "<[^>]*>", "")
                for line in string.gmatch(plain .. "\n", "([^\n]*)\n") do
                    if string.gsub(line, "%s", "") == "" then
                        table.insert(el.knoxLines, "")
                    else
                        for _, piece in ipairs(T.wrap(line, T.fontText, el.width - pad * 4)) do table.insert(el.knoxLines, piece) end
                    end
                end
            end
            local lh = T.fontH(T.fontText) + 4
            local y = pad * 2
            local k = T.color.text
            for _, line in ipairs(el.knoxLines) do
                T.drawTextCentre(el, line, tx, y, k.r, k.g, k.b, 1, T.fontText)
                y = y + lh
            end
        end
        local prerender = self.prerender
        self.prerender = function(el)
            prerender(el)
            T.tileFrame(el, 0, 0, el.width, el.height, T.color.accent)
        end
    end)
end

--- A combo box of the game in Knox's look (its drop-down list gets Knox's
--- scroll bar); `font` is S.fieldFont() or nil.
function S.combo(combo, font, width, height)
    combo.backgroundColor = colored(T.color.cell, 1)
    combo.borderColor = colored(T.color.tileFrame, 1)
    combo.backgroundColorMouseOver = colored(T.color.tileEdge, 1)
    combo.textColor = colored(T.color.bright, 1)
    combo.knoxCombo = true
    if font then combo.font = font end
    if width then combo:setWidth(width) end
    if height then combo:setHeight(height) end
    -- the game's arrow picture on its right: Knox's mark instead
    if not combo.knoxArrow then
        combo.knoxArrow = true
        local texture = combo.drawTexture
        combo.drawTexture = function(el, tex, x, y, a, r, g, b)
            if tex ~= el.image or not T.active then return texture(el, tex, x, y, a, r, g, b) end
            -- (by the box's height now: its baseHeight is the game's own, from
            -- before Knox made it taller - the button came out tiny and the
            -- angle a slash, seen by the author 2026-10-20)
            S.chevron(el, el.width, el:getHeight(), el.expanded, el.disabled, el:isMouseOver())
        end
    end
end

--- The mark of a drop-down list at the right end of a box `w` x `h`: the
--- button a bag's header folds with (KnoxInventoryPanel) - a framed square
--- with an angle of 2 px dots, down; up while the list is open; sand under
--- the mouse and while open. (A bare angle of dots looked of no kind of Knox's:
--- the author, 2026-10-20.)
function S.chevron(ui, w, h, open, off, hot)
    local bs = h - 8
    T.iconButton(ui, {w - bs - 4, 4, bs, bs}, open and "up" or "down", open or hot, {off = off})
end

--- Knox's body font as a UIFont for the game's own widgets (text boxes, combo
--- boxes, labels): the Java part lends it one; nil while it can't.
function S.fieldFont()
    if not T.javaFonts or not knoxFieldFont or type(T.fontText) ~= "table" then return nil end
    return knoxFieldFont("body", T.fontText.size)
end

--- A text box of the game in Knox's look: our font, the text in the middle of
--- the box's height, dark inside, no round "clear" button of the game's.
function S.field(entry)
    local font = S.fieldFont()
    pcall(function()
        if font then
            entry.font = font
            entry.javaObject:setFont(font)
        end
        entry.javaObject:setCentreVertically(true)
        entry:setClearButton(false)
    end)
    entry.backgroundColor = colored(T.color.cell, 1)
    entry.borderColor = colored(T.color.tileFrame, 1)
    -- The engine writes a box's text 2 px from its left edge (a combo box
    -- has 10). The box is drawn S.FIELD_INSET wider to the left than the
    -- engine's text area: place a field with S.placeField, which shifts it.
    if not entry.knoxInset then
        entry.knoxInset = S.FIELD_INSET
        local rect, border = entry.drawRectStatic, entry.drawRectBorderStatic
        entry.drawRectStatic = function(el, x, y, w, h, a, r, g, b)
            if x == 0 and w == el.width then return rect(el, -el.knoxInset, y, w + el.knoxInset, h, a, r, g, b) end
            return rect(el, x, y, w, h, a, r, g, b)
        end
        entry.drawRectBorderStatic = function(el, x, y, w, h, a, r, g, b)
            if x == 0 and w == el.width then
                x, w = -el.knoxInset, w + el.knoxInset
                -- the game's red of a wrong value (an empty save name): Knox's
                -- red, 2 px as every frame that matters (1 px was too thin to
                -- see; the author, 2026-10-20)
                if r > 0.5 and g < 0.25 and b < 0.25 then
                    local c = T.color.bad
                    border(el, x, y, w, h, 1, c.r, c.g, c.b)
                    border(el, x + 1, y + 1, w - 2, h - 2, 1, c.r, c.g, c.b)
                    return
                end
            end
            return border(el, x, y, w, h, a, r, g, b)
        end
    end
end

S.FIELD_INSET = 8

--- Put a styled text box so that its drawn box takes x .. x + width.
function S.placeField(entry, x, width)
    local inset = entry.knoxInset or 0
    entry:setX(x + inset)
    if width then entry:setWidth(width - inset) end
end

function S.side(ui)
    return math.max(T.pad * 3, math.floor(ui.width * 0.04))
end

function S.headerHeight()
    return math.floor(T.cell * 1.25)
end

--- The bar on top of a rebuilt screen: the title with the sand line of an
--- active tab under it; on the right the steps of a new game, `step` lit.
function S.header(ui, title, step)
    local W, h, pad = ui.width, S.headerHeight(), T.pad
    local side = S.side(ui)
    T.rect(ui, 0, 0, W, h, T.color.header)
    T.rect(ui, 0, h - 2, W, 2, T.color.border)
    local font = T.javaFonts and T.makeFont("title", math.min(44, T.cell * 0.62)) or UIFont.Large
    local text = T.upper(title or "")
    T.text(ui, text, side, math.floor((h - T.fontH(font)) / 2), T.color.bright, font)
    T.rect(ui, side, h - 5, T.measure(font, text), 4, T.color.accent)
    if not step then return h end
    local f = T.fontCaps
    local fh = T.fontH(f)
    local box = fh + 8
    local by = math.floor((h - box) / 2)
    local x = W - side
    for i = #S.STEPS, 1, -1 do
        local label = T.upper(getText(S.STEPS[i]))
        local on, done = i == step, i < step
        x = x - T.measure(f, label)
        -- (the names and the numbers stand in the middle of the squares' height
        -- by their pixels, the numbers in the middle of their squares both ways:
        -- by the font's width and line they sat high and to one side; the author,
        -- 2026-10-20)
        T.inkLeft(ui, label, x, by, box, on and T.color.bright or T.color.dim, f)
        x = x - 8 - box
        if on then
            T.rect(ui, x, by, box, box, T.color.accent)
        else
            T.border(ui, x, by, box, box, done and T.color.accent or T.color.tileEdge)
        end
        local n = tostring(i)
        local nc = on and T.color.ink or (done and T.color.accent or T.color.dim)
        T.inkCentre(ui, n, x, by, box, box, nc.r, nc.g, nc.b, 1, f)
        if i > 1 then
            x = x - pad * 4
            T.rect(ui, x + pad, math.floor(h / 2), pad * 2, 1, T.color.tileEdge)
        end
    end
    return h
end

-- Lists ---------------------------------------------------------------------------

--- The game marks a list's selected row with one orange everywhere: sand instead.
local function skinList(l)
    if neutral(l.backgroundColor) then l.backgroundColor = colored(T.color.window, 0.92) end
    if neutral(l.borderColor) then l.borderColor = colored(T.color.tileFrame, 1) end
    local draw = l.drawRect
    if type(draw) ~= "function" then return end
    l.drawRect = function(self, x, y, w, h, a, r, g, b)
        if r == 0.7 and g == 0.35 and b == 0.15 then
            local k = T.color.accent
            return draw(self, x, y, w, h, a, k.r, k.g, k.b)
        end
        return draw(self, x, y, w, h, a, r, g, b)
    end
end

-- Screens -------------------------------------------------------------------------

--- The screen itself: a darker veil over the camp, its title in Knox's font.
local function skinScreen(s)
    if neutral(s.backgroundColor) then s.backgroundColor = {r = 0.02, g = 0.022, b = 0.022, a = S.VEIL} end
    if neutral(s.borderColor) then s.borderColor = colored(T.color.border, 0) end
    local centre = s.drawTextCentre
    if type(centre) ~= "function" then return end
    s.drawTextCentre = function(self, text, x, y, r, g, b, a, font)
        if font == UIFont.Large and T.active and T.javaFonts and type(text) == "string" then
            local size = math.max(14, math.min(44, getTextManager():getFontHeight(UIFont.Large) * 0.8))
            local c = T.color.bright
            T.drawTextCentre(self, T.upper(text), x, y, c.r, c.g, c.b, a or 1, T.makeFont("title", size))
            return
        end
        return centre(self, text, x, y, r, g, b, a, font)
    end
end

local function skinPanel(e)
    local bg = e.backgroundColor
    if neutral(bg) and (bg.a or 0) > 0.05 then e.backgroundColor = colored(T.color.window, math.max(bg.a, 0.6)) end
    local bc = e.borderColor
    if neutral(bc) and (bc.a or 0) > 0.05 then e.borderColor = colored(T.color.tileFrame, math.max(bc.a, 0.8)) end
end

local function skin(e, root)
    if root then
        skinScreen(e)
    elseif e.backgroundColorMouseOver ~= nil and e.title ~= nil and e.onclick ~= nil or e.Type == "ISButton" then
        skinButton(e)
    elseif e.items ~= nil and e.itemheight ~= nil then
        skinList(e)
    else
        skinPanel(e)
    end
end

local function walk(e, root, depth)
    if type(e) ~= "table" or depth > 14 then return end
    if not e.knoxSkinned then
        e.knoxSkinned = true
        local ok, err = pcall(skin, e, root)
        if not ok then print("[Knox] menu skin: " .. tostring(e.Type) .. ": " .. tostring(err)) end
    end
    if type(e.children) == "table" then
        for _, child in pairs(e.children) do walk(child, false, depth + 1) end
    end
end

local nextLook = 0

local function look()
    if not T.active then return end
    local now = getTimestampMs()
    if now < nextLook then return end
    nextLook = now + 400
    local main = MainScreen.instance
    if not main then return end
    -- the two small buttons in the main menu's corner (terms of service,
    -- report a bug): Knox's dark buttons of one width, kept at their right edge
    if T.on("menu") and T.javaFonts and main.knoxCorner ~= T.cell then
        main.knoxCorner = T.cell
        pcall(function()
            T.ensure()
            local wide = 0
            local buttons = {}
            for _, name in ipairs({"termsOfService", "reportBug"}) do
                local b = main[name]
                if b then
                    table.insert(buttons, b)
                    wide = math.max(wide, T.measure(T.fontCaps, T.upper(b.title or "")) + T.pad * 4)
                end
            end
            for _, b in ipairs(buttons) do
                local right = b:getX() + b:getWidth()
                S.plain(b)
                b:setWidth(wide)
                b:setX(right - wide)
            end
        end)
    end
    for _, name in ipairs(S.SCREENS) do
        local screen = main[name]
        if T.on("newgame") and screen and screen.javaObject and screen:getIsVisible() then
            T.ensure()
            walk(screen, true, 0)
        end
    end
end

Events.OnPreUIDraw.Add(look)

-- The loading screen (the Java part's KnoxLoading) writes with atlases that
-- load in the background: asked for while the menu is up, so that they are
-- there when a game is started.
local function preloadLoading()
    if T.on("newgame") and knoxLoadingPreload then pcall(knoxLoadingPreload) end
end

-- The loading screen goes with the new game screens: the Java part draws it
-- only while that part of the mod is on.
if knoxLoadingEnable then knoxLoadingEnable(T.on("newgame")) end
Events.OnMainMenuEnter.Add(preloadLoading)
