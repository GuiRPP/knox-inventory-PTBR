-- The main menu in Knox's look: its items, and the mod's news.
--
-- Items: the game's own labels, drawn Knox's way (capitals in Knox's font, a
-- sand plate under the one the mouse is on). Only their drawing is replaced:
-- clicks, sounds and the gamepad stay the game's.
--
-- News: the posts of KnoxNews (media/knox/news_<lang>.txt) as cards in the
-- bottom right corner; a click opens the post over the whole screen - its
-- card on top, the text on the left (title, a line under it, then sections
-- with pictures, scrolling), a large picture on the right, "Esc - close"
-- at the bottom.
-- A post may bring pictures of its own (files of media/knox/news):
--   @banner file.png     the card's background (912 x 204)
--   @art file.png        the picture on the right of the opened post
-- Without them the stock ones of media/ui/knoxmenu are used.

require "ISUI/ISPanel"
require "OptionScreens/MainScreen"
require "Knox/KnoxTheme"
require "Knox/KnoxNews"
require "Knox/KnoxNewsBack"

local T = KnoxTheme
local DOT = string.char(183)

-- Menu items ------------------------------------------------------------------

local vanillaLabel = MainScreen.prerenderBottomPanelLabel

--- Knox's font for a menu item of this height (the game's when Knox's can't write the language).
local function menuFont(height)
    if not T.javaFonts then return UIFont.Large end
    return T.makeFont("title", math.max(14, math.min(44, height * 0.5)))
end

--- Is Knox's atlas of this font read? (They load in the background; the menu
--- shows nothing in the meantime rather than the game's font and then ours.)
local function loaded(font)
    return type(font) ~= "table" or knoxFontReady(font.style, font.size) == true
end

--- Knox's fonts are on their way: the language is theirs, the atlases not yet read.
local waitUntil = nil
local function fontsPending(...)
    if not T.on("menu") or not T.languageOk then return false end
    local pending = not T.javaFonts
    for _, font in ipairs({...}) do
        if not loaded(font) then pending = true end
    end
    if not pending then return false end
    -- (not for ever: an atlas that failed to load never gets ready, and the menu must stay usable)
    local now = getTimestampMs()
    waitUntil = waitUntil or (now + 15000)
    return now < waitUntil
end

-- Ask for the menu's atlases as early as possible, while the game still loads.
Events.OnGameBoot.Add(function()
    pcall(function()
        if not T.on("menu") then return end
        T.refresh()
        if not T.languageOk then return end
        local c = T.cell
        local line = getTextManager():getFontHeight(UIFont.Large) + 16
        for _, f in ipairs({{"body", c * 0.31}, {"title", c * 0.42}, {"head", c * 0.36}, {"head", c * 0.29},
                {"head", c * 0.25}, {"title", math.max(14, math.min(44, line * 0.5))}}) do
            knoxFontReady(f[1], math.max(10, math.min(44, math.floor(f[2] + 0.5))))
        end
    end)
end)

-- The items step aside for the scene: they fade away a few seconds after the
-- mouse has left their side of the screen and come back when it returns.
local MENU_STAY, MENU_OUT, MENU_IN = 5000, 1.2, 0.25
local menuShow = {alpha = 1, last = 0, stamp = 0}

-- The items move (the author's wish, 2026-10-16; following the camera's turn
-- was tried first and didn't suit): when the menu comes up, or back after it
-- stepped aside, they come in from the left one after another; under the
-- mouse the sand plate unrolls from the left and the name slides a little right.
local CASCADE_STEP, CASCADE_MS, CASCADE_PX = 55, 300, 28   -- ms between items, ms each takes, px they come from
local HOVER_PX = 10                                        -- how far the name slides under the mouse

local function ease(t)
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function menuAlpha(focused)
    local m = menuShow
    local now = getTimestampMs()
    if now - m.stamp > 1000 then m.alpha, m.last, m.inAt = 1, now, now end   -- the menu has just come up
    if m.alpha <= 0 then m.inAt = nil end                                    -- (gone: comes in again next time)
    local dt = math.min(100, now - m.stamp) / 1000
    if KnoxMenuNewsReader and KnoxMenuNewsReader.instance then
        -- a post is being read: the menu stays as it was, and its clock waits
        m.last = m.last + (now - m.stamp)
        m.stamp = now
        return m.alpha
    end
    if now ~= m.stamp then
        m.stamp = now
        local main = MainScreen.instance
        local panel = main and main.bottomPanel
        local inside = true
        if panel and T.cell then
            inside = getMouseX() < getCore():getScreenWidth() * 0.3 and getMouseY() > panel:getAbsoluteY() - T.cell
        end
        if inside then m.last = now end
        if now - m.last < MENU_STAY then
            if m.alpha <= 0 or not m.inAt then m.inAt = now end
            m.alpha = math.min(1, m.alpha + dt / MENU_IN)
        else
            m.alpha = math.max(0, m.alpha - dt / MENU_OUT)
        end
    end
    if focused then m.last = now end   -- chosen with a gamepad: stays
    return m.alpha
end

-- (assigned to every label of the menu when the main screen is built: this
-- file is loaded before that)
function MainScreen:prerenderBottomPanelLabel()
    if not T.on("menu") then return vanillaLabel(self) end
    -- PZ Optimization writes a small line ("Version ...") under its item after
    -- this returns: taken over, so that it fades with the rest of the menu.
    if self.pzoptVersion then
        self.knoxSubline, self.pzoptVersion = self.pzoptVersion, nil
    end
    T.ensure()
    self.fade:update()
    local f = self.fade:fraction()
    local big = self.font == UIFont.Large
    local text = self.translation or self.name or ""
    local w, h = self:getWidth(), self:getHeight()
    -- (by the game's own font, not the label: a mod's item may be taller than a line)
    local line = getTextManager():getFontHeight(UIFont.Large) + 16
    if fontsPending() then return end
    local font = big and menuFont(line) or T.fontTile
    if fontsPending(font) then return end
    local ma = menuAlpha(self.joypadFocused)
    if ma <= 0 then return end
    if self.knoxSubline and self.pzoptRowHgt then
        local c = self.pzoptEnabled and 0.75 or 0.45
        self:drawText(self.knoxSubline, 0, self.pzoptRowHgt - 6, c, c, c, ma, UIFont.Small)
    end
    if big then text = T.upper(text) end
    local pad = T.pad
    -- coming in: one after another, top to bottom, from a little to the left
    local dx = 0
    local inAt = menuShow.inAt
    if inAt and (not T.animOn or T.animOn()) then
        local order = math.floor(self:getY() / math.max(1, line) + 0.5)
        local k = ease((getTimestampMs() - inAt - order * CASCADE_STEP) / CASCADE_MS)
        dx = -math.floor(CASCADE_PX * (1 - k) + 0.5)
        ma = ma * k
        if ma <= 0 then return end
    end
    local off = (self.r or 1) < 0.9           -- the game greys an item out by its color
    local base = off and T.color.dim or (big and T.color.bright or T.color.dim)
    local r, g, b = base.r, base.g, base.b
    local fe = ease(f)
    if big and f > 0 then
        local a, ink = T.color.accent, T.color.ink
        local ph = math.min(h, line) - 6
        -- the plate unrolls from the left
        local pw = math.floor((w + pad * 2) * fe + 0.5)
        self:drawRect(-pad + dx, 3, pw, ph, f * ma, a.r, a.g, a.b)
        self:drawRect(-pad + dx, 3, 4, ph, f * ma, ink.r, ink.g, ink.b)
        r, g, b = r + (ink.r - r) * f, g + (ink.g - g) * f, b + (ink.b - b) * f
    end
    local y = math.floor((math.min(h, line) - T.fontH(font)) / 2)
    if not big then y = math.floor((h - T.fontH(font)) / 2) end
    local tx = pad / 2 + dx + (big and math.floor(HOVER_PX * fe + 0.5) or 0)
    if f < 0.5 then T.drawText(self, text, tx + 1, y + 1, 0, 0, 0, 0.7 * (1 - f * 2) * ma, font) end   -- over the scene
    T.drawText(self, text, tx, y, r, g, b, ma, font)
    if self.joypadFocused and self.joypadTexture then
        self:drawTextureScaled(self.joypadTexture, -32 - 10, h / 2 - 16, 32, 32, ma, 1, 1, 1)
    end
end

-- News: data ------------------------------------------------------------------

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

local MARK = {["+"] = "good", ["*"] = "accent", ["-"] = "dim", ["!"] = "bad"}
local TAG_COLOR = {update = "accent", news = "good", plans = "dim"}

local function tagColor(tag)
    if string.lower(tag or "") == "tech" then return KnoxNews.TECH_COLOR end
    return T.color[TAG_COLOR[string.lower(tag or "")] or "good"]
end

--- The language of the news file read (news_ru.txt: "ru"), for the pictures of a kind.
local function newsLang()
    return string.match(getText("IGUI_Knox_NewsFile"), "news_(%a+)%.txt") or "en"
end

local function tagText(tag)
    return getTextOrNull("IGUI_Knox_NewsTag_" .. string.lower(tag or "")) or tag or ""
end

local function newsTexture(file, stock)
    local tex = file and getTexture("media/knox/news/" .. file) or nil
    return tex or getTexture("media/ui/knoxmenu/" .. stock)
end

--- What a card and the opened post need besides the body: the first
--- paragraph (the card's second line) and the post's own pictures.
local function prepare(post)
    if post.menuReady then return end
    post.menuReady = true
    for _, line in ipairs(post.body) do
        local s = trim(line)
        local banner = string.match(s, "^@banner%s+(.+)$")
        local art = string.match(s, "^@art%s+(.+)$")
        -- @frame #rrggbb: the card's frame in a colour of its own (0.9.8: green, for the skins)
        local frame = string.match(s, "^@frame%s+#(%x%x%x%x%x%x)")
        if frame then
            post.frameColor = {r = tonumber(frame:sub(1, 2), 16) / 255, g = tonumber(frame:sub(3, 4), 16) / 255,
                               b = tonumber(frame:sub(5, 6), 16) / 255}
        elseif banner then
            post.bannerFile = trim(banner)
        elseif string.match(s, "^@back%s+(%a+)") then
            -- "@back power": a drawn backdrop of the post (KnoxNewsBack), lit by its generators
            post.back = string.match(s, "^@back%s+(%a+)")
        elseif art and trim(art) == "gen" then
            -- "@art gen": the post's generator itself in the frame, drawn by its window -
            -- sharp on any screen (a picture of it was soft, the author 2026-10-22)
            post.artGen = true
        elseif art then
            post.artFile = trim(art)
        elseif not post.lead and s ~= "" and not MARK[string.sub(s, 1, 1)] and string.sub(s, 1, 1) ~= "#"
                and string.sub(s, 1, 1) ~= "@" then
            post.lead = s
        end
    end
    post.lead = post.lead or ""
    -- a technical update: its kind's frame and pictures, unless it brings its own
    -- (tools\make_news_tech.ps1: one banner, a picture per language)
    if string.lower(post.tag or "") == "tech" then
        post.frameColor = post.frameColor or KnoxNews.TECH_COLOR
        post.bannerFile = post.bannerFile or "tech_banner.png"
        post.artFile = post.artFile or ("tech_art_" .. newsLang() .. ".png")
    end
end

local function posts()
    if not KnoxNews.posts then KnoxNews.load() end
    return KnoxNews.posts or {}
end

--- A post's body as blocks for the reader: paragraphs, headings, list items, pictures.
local function layout(post, width)
    local blocks, para = {}, {}
    local dashes = 0
    local function flush()
        if #para > 0 then
            table.insert(blocks, {kind = "text", lines = T.wrap(table.concat(para, " "), T.fontText, width)})
            para = {}
        end
    end
    for _, line in ipairs(post.body) do
        local s = trim(line)
        local mark = string.sub(s, 1, 1)
        if s == "" then
            flush()
        elseif string.sub(s, 1, 2) == "##" then
            flush()
            -- (every heading on its plate - not only one that opens a picture: the author,
            -- 2026-10-22, "frame these headings too")
            table.insert(blocks, {kind = "heading", text = trim(string.sub(s, 3)), framed = true})
        elseif MARK[mark] and string.sub(s, 2, 2) == " " then
            flush()
            local indent = math.floor(T.fontH(T.fontText) * 0.9)
            -- ("changed" in the post's own colour: the whole post keeps its palette -
            -- a technical update's steel blue, the author 2026-10-22)
            local color = (mark == "*" and post.frameColor) or T.color[MARK[mark]]
            table.insert(blocks, {kind = "item", color = color, indent = indent,
                lines = T.wrap(trim(string.sub(s, 2)), T.fontText, width - indent)})
        elseif mark == "@" then
            flush()
            if string.match(s, "^@dash") then
                -- the car's dashboard itself, live: "@dash sedan" / "@dash pickup hot"
                -- (KnoxDashboard.newsDemo); a section opened by it, as by a picture
                local body, hot = string.match(s, "^@dash%s*(%a*)%s*(%a*)")
                dashes = dashes + 1
                local last = blocks[#blocks]
                if last and last.kind == "heading" then last.framed = true end
                table.insert(blocks, {kind = "dash", body = body, hot = hot == "hot", key = dashes})
            elseif string.match(s, "^@gen") then
                -- the generator's window itself, live: "@gen" / "@gen worn"
                -- (KnoxGeneratorWindow.newsDemo); a section opened by it, as by a picture
                dashes = dashes + 1
                local last = blocks[#blocks]
                if last and last.kind == "heading" then last.framed = true end
                table.insert(blocks, {kind = "gen", worn = string.match(s, "^@gen%s+worn") ~= nil, key = dashes})
            elseif not string.match(s, "^@banner") and not string.match(s, "^@art") and not string.match(s, "^@frame") then
                local tex = getTexture("media/knox/news/" .. trim(string.sub(s, 2)))
                if tex then
                    -- a section opened by a picture: its heading gets a frame
                    local last = blocks[#blocks]
                    if last and last.kind == "heading" then last.framed = true end
                    table.insert(blocks, {kind = "image", tex = tex})
                end
            end
        else
            table.insert(para, s)
        end
    end
    flush()
    return blocks
end

local function tagPlate(ui, x, y, text, color)
    local f = T.fontTile
    text = T.upper(text)
    local w, h = T.measure(f, text) + 10, T.fontH(f) + 4
    T.rect(ui, x, y, w, h, color)
    T.text(ui, text, x + 5, y + 2, T.color.ink, f)
    return w
end

--- A news card: the banner, the post's kind, its title and first line.
local function drawCard(ui, post, x, y, w, h, hot)
    prepare(post)
    local pad = T.pad
    T.rect(ui, x, y, w, h, T.color.window)
    local tex = newsTexture(post.bannerFile, "news_banner.png")
    if tex then
        -- fills the card keeping its shape; what does not fit is cut on the left, under the text
        local tw, th = tex:getWidth(), tex:getHeight()
        local k = math.max(w / math.max(1, tw), h / math.max(1, th))
        local dw, dh = tw * k, th * k
        ui:setStencilRect(x, y, w, h)
        ui:drawTextureScaled(tex, x + w - dw, y + (h - dh) / 2, dw, dh, hot and 1 or 0.88, 1, 1, 1)
        ui:clearStencilRect()
    end
    -- sand all round, lighter under the mouse, as thick as the strip on its left
    -- once was on every side (2 px elsewhere looked uneven - asked 2026-10-14);
    -- on whole pixels, so that no side comes out thinner while the card moves
    local fx, fy, fw, fh = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
    local fc = hot and T.color.bright or (post.frameColor or T.color.accent)
    local t = 4
    T.rect(ui, fx, fy, fw, t, fc)
    T.rect(ui, fx, fy + fh - t, fw, t, fc)
    T.rect(ui, fx, fy + t, t, fh - t * 2, fc)
    T.rect(ui, fx + fw - t, fy + t, t, fh - t * 2, fc)
    local cx, cy = x + pad + 4, y + pad
    -- (the kind's plate in the post's own colour when it has one: @frame)
    if post.tag ~= "" then cx = cx + tagPlate(ui, cx, cy, tagText(post.tag), post.frameColor or tagColor(post.tag)) + 6 end
    if not KnoxNews.isSeen(post) then tagPlate(ui, cx, cy, getText("IGUI_Knox_NewsNew"), T.color.ok) end
    cx = x + pad + 4
    cy = cy + T.fontH(T.fontTile) + 4 + math.floor(pad / 2)
    local textW = w - pad * 2 - 4
    -- a line too long for the card slides to its end and back, as the radio
    -- card's (T.marquee; the author, 2026-10-22: not cut with "...")
    post.titleSt, post.leadSt = post.titleSt or {}, post.leadSt or {}
    T.marquee(ui, post.titleSt, post.title, cx + 1, cy + 1, textW, T.color.ink, T.fontHeader, 0.8)
    T.marquee(ui, post.titleSt, post.title, cx, cy, textW, T.color.bright, T.fontHeader)
    cy = cy + T.fontH(T.fontHeader) + 2
    T.marquee(ui, post.leadSt, post.lead, cx, cy, textW, post.frameColor or T.color.accent, T.fontTile)
end

--- A card is as high as its three lines and the air around them need.
local function cardSize()
    local pad = T.pad
    local h = pad + T.fontH(T.fontTile) + 4 + math.floor(pad / 2) + T.fontH(T.fontHeader) + 2
        + T.fontH(T.fontTile) + pad + math.floor(pad / 2)
    return math.floor(T.cell * 7.6), h
end

-- News: the opened post -------------------------------------------------------

KnoxMenuNewsReader = ISPanel:derive("KnoxMenuNewsReader")
local R = KnoxMenuNewsReader

function R:new(post)
    local o = ISPanel:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.wantMouseEvents = true
    o.post = post
    o.scroll = 0
    o.scrollMax = 0
    o.escDown = true
    return o
end

function R.open(post)
    R.close()
    T.ensure()
    local o = R:new(post)
    o:initialise()
    o:instantiate()
    o:addToUIManager()
    o:setAlwaysOnTop(true)
    R.instance = o
    KnoxNews.markSeen(post)
    getSoundManager():playUISound("UISelectListItem")
end

function R.close()
    local o = R.instance
    if not o then return end
    R.instance = nil
    o:removeFromUIManager()
end

function R:prerender()
    local W, H = self:getWidth(), self:getHeight()
    local pad, cell = T.pad, T.cell
    local post = self.post
    prepare(post)
    local mx, my = self:getMouseX(), self:getMouseY()

    -- Esc closes (the key is watched here: the menu under this takes no part)
    local esc = isKeyDown(Keyboard.KEY_ESCAPE) == true
    if esc and not self.escDown then
        R.close()
        return
    end
    self.escDown = esc

    self:drawRect(0, 0, W, H, 0.88, 0.02, 0.022, 0.022)
    -- a drawn backdrop ("@back power", KnoxNewsBack): lit while a generator of the post runs
    local backLit, backC = 0, post.frameColor or T.color.accent
    if post.back and KnoxNewsBack then
        local on = false
        for _, d in pairs(self.knoxGenDemos or {}) do
            if d.demo and d.demo.g.on and d:getIsVisible() then on = true end
        end
        self.backSt = self.backSt or {}
        backLit = KnoxNewsBack.litFor(self.backSt, on, getTimestampMs())
        KnoxNewsBack.grid(self, 0, 0, W, H, backC, backLit, 0.45)
    end

    -- the post's card on top
    local cw, ch = cardSize()
    drawCard(self, post, math.floor((W - cw) / 2), pad * 2, cw, ch, false)

    local top = pad * 2 + ch + pad * 2
    local bottom = H - math.floor(cell * 1.5)
    local side = math.floor(W * 0.05)
    local gap = pad * 2
    local artW = math.floor((W - side * 2 - gap) * 0.385)
    local textPanelW = W - side * 2 - gap - artW
    local panelH = bottom - top

    -- the picture on the right, whole in its frame: the frame is tall on a 16:9
    -- screen and nearly square on a wide one, and a picture filling it lost its
    -- top and bottom there (seen 2026-10-14 at 3440x1440). Pictures are drawn
    -- on the frame's own color, so the strips left over don't show.
    local ax, ay = side + textPanelW + gap, top
    T.rect(self, ax, ay, artW, panelH, T.color.cell)
    if post.back and KnoxNewsBack then KnoxNewsBack.grid(self, ax, ay, artW, panelH, backC, backLit, 1) end
    local art = not post.artGen and newsTexture(post.artFile, "news_art.png") or nil
    if post.artGen and KnoxGeneratorWindow and KnoxGeneratorWindow.newsDemo then
        -- the generator itself in the middle of the frame, standing (live: started, it
        -- lights the post's backdrop up - the author, 2026-10-22)
        local d = KnoxGeneratorWindow.newsDemo(self, "art", false, false)
        local dw, dh = d:demoSize(artW - pad * 4)
        self.artView = self.artView or {0, 0, 0, 0}
        local v = self.artView
        v[1], v[2], v[3], v[4] = ax, ay, artW, panelH
        d:hostAt(self, ax + math.floor((artW - dw) / 2), ay + math.floor((panelH - dh) / 2), v)
    elseif art then
        local tw, th = art:getWidth(), art:getHeight()
        local k = math.min(artW / math.max(1, tw), panelH / math.max(1, th))
        local dw, dh = tw * k, th * k
        self:setStencilRect(ax, ay, artW, panelH)
        self:drawTextureScaled(art, ax + (artW - dw) / 2, ay + (panelH - dh) / 2, dw, dh, 1, 1, 1, 1)
        self:clearStencilRect()
    end
    T.tileFrame(self, ax, ay, artW, panelH, T.color.tileFrame)

    -- the text on the left
    local px, pw = side, textPanelW
    T.rect(self, px, top, pw, panelH, T.color.window, 0.97)
    self.backGrid = nil
    if post.back and KnoxNewsBack then
        self:setStencilRect(px, top, pw, panelH)
        KnoxNewsBack.draw(self, post.back, px, top, pw, panelH, backC, backLit)
        self.backGrid = {backC, backLit, post.back}
        self:clearStencilRect()
    end
    T.tileFrame(self, px, top, pw, panelH, T.color.tileFrame)
    self.panel = {px, top, pw, panelH}
    self.artRect = {ax, ay, artW, panelH}
    local centre = px + math.floor(pw / 2)
    local textW = math.min(pw - pad * 8, cell * 20)
    local titleFont = T.javaFonts and T.makeFont("title", math.min(44, cell * 0.72)) or UIFont.Large
    if self.blocksW ~= textW then
        self.blocks = layout(post, textW)
        self.blocksW = textW
        self.titleLines = T.wrap(T.upper(post.title), titleFont, pw - pad * 6)
    end
    -- the head (title, tag, date) on a band of its own over the whole panel, a line of the
    -- post's colour under it: a thin grey line alone did not part it from the post (the
    -- author, 2026-10-22)
    local pc = post.frameColor or T.color.accent
    local headH = pad * 2 + #self.titleLines * T.fontH(titleFont) + math.floor(pad / 2) + T.fontH(T.fontTab) + pad + math.floor(pad / 2)
    T.rect(self, px + 2, top + 2, pw - 4, headH - 2, T.color.header)
    T.rect(self, px + 2, top + headH, pw - 4, 4, pc)   -- (2 px read thin: the author, 2026-10-22)
    local y = top + pad * 2
    for _, l in ipairs(self.titleLines) do
        T.textCentre(self, l, centre, y, T.color.bright, titleFont)
        y = y + T.fontH(titleFont)
    end
    local meta = tagText(post.tag)
    if post.version ~= "" then meta = meta .. " " .. post.version end
    if post.date ~= "" then meta = meta .. "  " .. DOT .. "  " .. post.date end
    y = y + math.floor(pad / 2)
    -- (a post with a colour of its own - @frame - has it here too: the line under the
    -- head, its headings, its pictures' frames, the scroll bar)
    T.textCentre(self, meta, centre, y, pc, T.fontTab)
    y = top + headH + 4 + pad

    -- the body scrolls under the title
    local viewTop, viewH = y, top + panelH - pad - y
    self.view = {px, viewTop, pw, viewH}
    self:setStencilRect(px, viewTop, pw, viewH)
    local lh = T.fontH(T.fontText) + 5
    local colX = centre - math.floor(textW / 2)
    y = viewTop - self.scroll + pad
    local first = true
    for _, b in ipairs(self.blocks) do
        if b.kind == "text" then
            for _, l in ipairs(b.lines) do
                if y > viewTop - lh and y < viewTop + viewH then
                    T.textCentre(self, l, centre, y, first and T.color.bright or T.color.text, T.fontText)
                end
                y = y + lh
            end
            y = y + math.floor(lh * 0.8)
            first = false
        elseif b.kind == "heading" then
            y = y + math.floor(lh * 0.8)
            if b.framed then y = y + math.floor(pad / 2) end
            if y > viewTop - lh * 3 and y < viewTop + viewH then
                if b.framed then
                    local fw = T.measure(T.fontHeader, b.text) + pad * 4
                    T.rect(self, centre - math.floor(fw / 2), y - math.floor(pad / 2), fw,
                        T.fontH(T.fontHeader) + pad, pc)
                end
                T.textCentre(self, b.text, centre, y, b.framed and T.color.ink or (post.frameColor or T.color.bright), T.fontHeader)
            end
            y = y + T.fontH(T.fontHeader) + math.floor(lh * 0.7)
            if b.framed then y = y + math.floor(pad / 2) end
            first = false
        elseif b.kind == "item" then
            local d = math.max(6, math.floor(T.fontH(T.fontText) / 3))
            if y > viewTop - lh and y < viewTop + viewH then
                T.rect(self, colX + 2, y + math.floor((T.fontH(T.fontText) - d) / 2) + 1, d, d, b.color)
            end
            for _, l in ipairs(b.lines) do
                if y > viewTop - lh and y < viewTop + viewH then
                    T.text(self, l, colX + b.indent, y, T.color.text, T.fontText)
                end
                y = y + lh
            end
            y = y + 3
        elseif b.kind == "image" then
            local tw, th = b.tex:getWidth(), b.tex:getHeight()
            local w = math.min(textW, tw)
            local h = math.floor(th * w / math.max(1, tw))
            local ix = centre - math.floor(w / 2)
            y = y + math.floor(lh * 0.4)
            self:drawTextureScaled(b.tex, ix, y, w, h, 1, 1, 1, 1)
            T.tileFrame(self, ix - 2, y - 2, w + 4, h + 4, pc)
            y = y + h + pad + math.floor(lh * 0.4)
        elseif b.kind == "dash" and KnoxDashboard and KnoxDashboard.newsDemo then
            -- the live dashboard: the panel itself on a pretend car, in the view only
            local d = KnoxDashboard.newsDemo(self, b.key, b.body, b.hot)
            local w, h = d:demoSize(textW)
            local ix = centre - math.floor(w / 2)
            y = y + math.floor(lh * 0.4)
            d:hostAt(self, ix, y, self.view)
            y = y + h + pad + math.floor(lh * 0.4)
        elseif b.kind == "gen" and KnoxGeneratorWindow and KnoxGeneratorWindow.newsDemo then
            -- the live generator: its window itself on a pretend generator, in the view only
            local d = KnoxGeneratorWindow.newsDemo(self, b.key, b.worn)
            local w, h = d:demoSize(textW)
            local ix = centre - math.floor(w / 2)
            y = y + math.floor(lh * 0.4)
            d:hostAt(self, ix, y, self.view)
            y = y + h + pad + math.floor(lh * 0.4)
        end
    end
    self:clearStencilRect()
    local contentH = y + self.scroll - viewTop + pad
    self.scrollMax = math.max(0, contentH - viewH)
    if self.scroll > self.scrollMax then self.scroll = self.scrollMax end
    self.bar = nil
    if contentH > viewH then
        local barH = math.max(cell, math.floor(viewH * viewH / contentH))
        -- the scroll bar is taken by the mouse: its knob dragged, a click on its
        -- track brings the knob there (it didn't move by the mouse: 2026-10-15)
        local drag = self.barDrag
        if drag and not isMouseButtonDown(0) then
            drag = nil
            self.barDrag = nil
        end
        if drag then
            local f = (my - drag.grab - viewTop) / math.max(1, viewH - barH)
            self.scroll = math.max(0, math.min(self.scrollMax, f * self.scrollMax))
        end
        local barY = viewTop + math.floor(self.scroll / self.scrollMax * (viewH - barH))
        -- (a wider strip than the thin line takes the mouse)
        self.bar = {track = {px + pw - 18, viewTop, 18, viewH}, knobY = barY, knobH = barH, top = viewTop, h = viewH}
        local hot = drag or T.inRect(mx, my, self.bar.track)
        -- (in the post's colour; under the mouse a lighter shade of it, not white)
        local kc = pc
        if hot then kc = {r = pc.r + (1 - pc.r) * 0.35, g = pc.g + (1 - pc.g) * 0.35, b = pc.b + (1 - pc.b) * 0.35} end
        -- (painted in render, over the fades at the view's ends)
        self.barPaint = {px + pw - 7, viewTop, viewH, px + pw - (hot and 9 or 8), barY, hot and 6 or 4, barH, kc}
    else
        self.barPaint = nil
    end

    -- how to leave
    local label = getText("IGUI_Knox_NewsClose")
    local hintW = T.measure(T.fontTile, "Esc") + 10 + 8 + T.measure(T.fontTile, label)
    local hx, hy = math.floor((W - hintW) / 2), bottom + math.floor((H - bottom - T.fontH(T.fontTile)) / 2)
    self.hint = {hx - pad, hy - pad, hintW + pad * 2, T.fontH(T.fontTile) + pad * 2}
    if T.inRect(mx, my, self.hint) then T.border(self, self.hint[1], self.hint[2], self.hint[3], self.hint[4], pc) end
    T.keyHint(self, hx, hy, "Esc", label)
end

--- Where the post goes on past its view (scrolled), it fades into the panel instead of
--- being cut off - as the inventory's columns do (T.edgeFades). Drawn here, after the
--- children: a live demo in the post (the generator, the dashboard) is one of them and
--- stood cut over a fade drawn with the text (the author, 2026-10-22).
function R:render()
    ISPanel.render(self)
    self:drawFades()
    local b = self.barPaint
    if b then
        T.rect(self, b[1], b[2], 2, b[3], T.color.border)
        T.rect(self, b[4], b[5], b[6], b[7], b[8])
    end
end

--- Where the post goes on past its view (scrolled), it fades into its panel instead of
--- being cut off, as the inventory's columns do. Not a fill laid over it: the panel
--- itself (its colour, and a drawn backdrop - the grid, the light, the bulb) is painted
--- back over the post strip by strip, more of it towards the edge, so only the post
--- fades. (A flat fill showed as a dark band over the backdrop with a visible edge -
--- the author, 2026-10-22.) Drawn after the children: a live demo in the post (the
--- generator, the dashboard) is one of them.
function R:drawFades()
    local v, pnl = self.view, self.panel
    if not v or not pnl then return end
    local now = getTimestampMs()
    local dt = math.min(100, now - (self.fadeMs or now))
    self.fadeMs = now
    local step = T.anim(math.min(1, dt / 120))
    local below = (self.scrollMax or 0) - (self.scroll or 0) > 1
    local above = (self.scroll or 0) > 1
    self.fadeBottom = (self.fadeBottom or 0) + ((below and 1 or 0) - (self.fadeBottom or 0)) * step
    self.fadeTop = (self.fadeTop or 0) + ((above and 1 or 0) - (self.fadeTop or 0)) * step
    if self.fadeBottom <= 0.01 and self.fadeTop <= 0.01 then return end
    -- (inside the panel's frame: its 2 px stay)
    local x, w = pnl[1] + 2, pnl[3] - 4
    local band = math.min(math.floor(T.cell * 1.3), math.floor(v[4] / 3))
    local c = T.color.window
    local bg = self.backGrid
    local sh = 3   -- (3 px strips: smooth enough, and each paints the backdrop again)
    local function strip(y, am)
        if am <= 0.003 then return end
        self:setStencilRect(x, y, w, sh)
        self:drawRect(x, y, w, sh, 0.97 * am, c.r, c.g, c.b)
        if bg and KnoxNewsBack then
            KnoxNewsBack.drawStrip(self, bg[3], pnl[1], pnl[2], pnl[3], pnl[4], bg[1], bg[2], y, sh, am)
        end
        self:clearStencilRect()
    end
    for i = 0, band - 1, sh do
        -- (eased: nothing where it starts, nearly the panel itself at the edge)
        local f = 1 - (i + sh / 2) / band
        local a = f * f * (3 - 2 * f) * 0.96
        if self.fadeBottom > 0.01 then strip(v[2] + v[4] - i - sh, a * self.fadeBottom) end
        if self.fadeTop > 0.01 then strip(v[2] + i, a * self.fadeTop) end
    end
end

function R:onMouseDown(x, y)
    local b = self.bar
    if b and T.inRect(x, y, b.track) then
        -- on the knob: held where it was taken; on the track: the knob's middle comes to the mouse
        local onKnob = y >= b.knobY and y < b.knobY + b.knobH
        self.barDrag = {grab = onKnob and (y - b.knobY) or math.floor(b.knobH / 2)}
        return true
    end
    if (self.hint and T.inRect(x, y, self.hint))
            or not ((self.panel and T.inRect(x, y, self.panel)) or (self.artRect and T.inRect(x, y, self.artRect))) then
        R.close()
    end
    return true
end

function R:onMouseUp(x, y) return true end
function R:onMouseMove(dx, dy) return true end
function R:onRightMouseDown(x, y) return true end

function R:onRightMouseUp(x, y)
    R.close()
    return true
end

function R:onMouseWheel(del)
    self.scroll = math.max(0, math.min(self.scrollMax or 0, self.scroll + del * T.cell))
    return true
end

-- News: the cards in the corner -----------------------------------------------

KnoxMenuNewsCards = ISPanel:derive("KnoxMenuNewsCards")
local C = KnoxMenuNewsCards
local PER_PAGE = 2

function C:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.wantMouseEvents = true
    o.page = 1
    o.wasDown = true
    return o
end

--- Size and place: the right edge, over the game's own buttons of that corner.
function C:arrange()
    T.ensure()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local cw, ch = cardSize()
    local list = posts()
    self.pages = math.max(1, math.ceil(#list / PER_PAGE))
    if self.page > self.pages then self.page = 1 end
    local shown = math.min(PER_PAGE, #list - (self.page - 1) * PER_PAGE)
    local gap = math.floor(T.pad * 0.75)
    local dots = self.pages > 1 and (T.pad * 2) or 0
    local w = cw + dots
    local h = PER_PAGE * ch + (PER_PAGE - 1) * gap
    self:setWidth(w)
    self:setHeight(h)
    self:setX(sw - w - math.floor(40 * sw / 1920))
    self:setY(sh - h - math.floor(125 * sh / 1080))
    self.cardW, self.cardH, self.gap, self.shown = cw, ch, gap, shown
end

function C:prerender()
    self:arrange()
    self.rects, self.dots = {}, {}
    if fontsPending(T.fontHeader, T.fontTile) then return end
    local list = posts()
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    -- A click is also looked for here: the game hands this element no mouse
    -- events once the main screen has been brought over it.
    local down = isMouseButtonDown(0) == true
    local main = MainScreen.instance
    if down and not self.wasDown and over and R.instance == nil and main and main.javaObject
            and knoxMenuMouseFree(self.javaObject, main.javaObject) == true then
        self:onMouseDown(mx, my)
    end
    self.wasDown = down
    self.rects = {}
    -- from the top of the block (a page's only card: the upper place)
    local y = 0
    for i = 1, self.shown do
        local post = list[(self.page - 1) * PER_PAGE + i]
        local r = {0, y, self.cardW, self.cardH}
        table.insert(self.rects, {rect = r, post = post})
        drawCard(self, post, r[1], r[2], r[3], r[4], over and T.inRect(mx, my, r))
        y = y + self.cardH + self.gap
    end
    -- pages as dots on the right
    self.dots = {}
    if self.pages > 1 then
        local d = math.max(6, math.floor(T.cell / 8))
        local step = d * 2
        local dy = math.floor((self.height - self.pages * step) / 2)
        for p = 1, self.pages do
            local r = {self.cardW + T.pad - 2, dy + (p - 1) * step - 2, d + 4, d + 4}
            table.insert(self.dots, {rect = r, page = p})
            local c = (p == self.page) and T.color.accent or T.color.tileFrame
            T.rect(self, r[1] + 2, r[2] + 2, d, d, c)
        end
    end
end

function C:onMouseDown(x, y)
    for _, c in ipairs(self.rects or {}) do
        if T.inRect(x, y, c.rect) then
            R.open(c.post)
            return true
        end
    end
    for _, d in ipairs(self.dots or {}) do
        if T.inRect(x, y, d.rect) then
            self.page = d.page
            return true
        end
    end
    return false
end

function C:onMouseWheel(del)
    if (self.pages or 1) <= 1 then return false end
    self.page = self.page + (del > 0 and 1 or -1)
    if self.page < 1 then self.page = self.pages end
    if self.page > self.pages then self.page = 1 end
    return true
end

function C.destroy()
    R.close()
    local o = C.instance
    if not o then return end
    C.instance = nil
    o:removeFromUIManager()
end

function C.create()
    C.destroy()
    if not T.on("menu") or #posts() == 0 then return end
    local main = MainScreen.instance
    if not main or main.inGame then return end
    local o = C:new()
    o:initialise()
    o:instantiate()
    o:arrange()
    o:addToUIManager()
    o:setAlwaysOnTop(true)   -- over the main screen, which comes to the top on a click
    C.instance = o
end

--- Shown with the menu's own items only: not over its sub-screens, not while a hero walks off.
local function showOrHide()
    local o = C.instance
    if not o then return end
    local main = MainScreen.instance
    local scene = KnoxMenuScene and KnoxMenuScene.instance
    local show = T.switch("news") and main ~= nil and not main.inGame and main.bottomPanel ~= nil and main:getIsVisible()
        and main.bottomPanel:getIsVisible() and R.instance == nil and (scene == nil or scene.mode == "idle")
    if show ~= o:getIsVisible() then o:setVisible(show) end
end

-- After an update with a news post, the post opens by itself, full screen, the
-- first time the menu is up (asked 2026-10-14): once the camp is in place and
-- Knox's fonts are loaded, the newest post, if it is not read yet. Opening marks
-- it read, so it does not come up again; the next update's post does.
local autoTried = false
local function openNewOnce()
    if autoTried then return end
    if not T.switch("news") then return end   -- the news cards switched off: no post opens by itself either
    local o = C.instance
    if not o or not o:getIsVisible() or R.instance then return end
    if fontsPending(T.fontHeader, T.fontTile) then return end
    autoTried = true
    local newest = posts()[1]
    if newest and not KnoxNews.isSeen(newest) then R.open(newest) end
end

Events.OnPreUIDraw.Add(showOrHide)
Events.OnPreUIDraw.Add(openNewOnce)
Events.OnMainMenuEnter.Add(C.create)
Events.OnGameStart.Add(C.destroy)
Events.OnResolutionChange.Add(function()
    if C.instance then C.create() end
end)
