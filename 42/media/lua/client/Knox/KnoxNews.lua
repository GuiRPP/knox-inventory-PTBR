-- News: what the author writes before each release, shipped with the mod and
-- shown as a page of the Knox screen (a click on "KNOX INVENTORY - STAGE 1"
-- in the top bar). A feed of posts on the left, the chosen post on the right.
--
-- The posts live in 42\media\knox\news_<lang>.txt (UTF-8); which file a
-- language reads is the translation IGUI_Knox_NewsFile, so languages without
-- their own file get the English one. Format (see the files' own header):
--   # version | date | type | title    a new post (version may be empty;
--                                       type: update, news or plans)
--   ## heading                          a section heading inside a post
--   + text   - added      * text - changed
--   - text   - fixed      ! text - important
--   @ picture.png                       a picture from media\knox\news\
--   anything else                       text; an empty line starts a paragraph
--   ; comment                           ignored
-- Posts already read are kept in Zomboid\Lua\knox_news_seen.txt.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxCrosshairDemo"

KnoxNews = ISPanel:derive("KnoxNews")
local N = KnoxNews
local T = KnoxTheme

local MOD_ID = T.MOD_ID
local openOpts = {primary = true}   -- (a post's button: drawn every frame, its options filled in)   -- (the release or the beta: whose files these are)
local SEEN_FILE = "knox_news_seen.txt"
local DOT = string.char(183)   -- the game reads Lua files as single bytes: the middle dot by its code

-- Data -----------------------------------------------------------------------------

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

local function readModFile(path)
    local r = getModFileReader(MOD_ID, path, false)
    if not r then return nil end
    local lines = {}
    local line = r:readLine()
    while line do
        table.insert(lines, line)
        line = r:readLine()
    end
    r:close()
    return lines
end

--- Posts of the current language: {id, version, date, tag, title, body = {lines}}.
function N.load()
    local lines = readModFile("media/knox/" .. getText("IGUI_Knox_NewsFile"))
        or readModFile("media/knox/news_en.txt") or {}
    local posts, cur = {}, nil
    for _, raw in ipairs(lines) do
        local line = string.gsub(raw, "\r", "")
        if string.sub(line, 1, 1) == ";" then
            -- comment
        elseif string.match(line, "^#[^#]") then
            local fields = {}
            for f in string.gmatch(string.sub(line, 2) .. "|", "([^|]*)|") do table.insert(fields, trim(f)) end
            local n = #fields
            cur = {version = n >= 4 and fields[1] or "", date = n >= 3 and fields[n - 2] or (n == 2 and fields[1] or ""),
                   tag = n >= 3 and fields[n - 1] or "", title = fields[n] or "", body = {}}
            cur.id = cur.version .. "|" .. cur.date .. "|" .. cur.title
            table.insert(posts, cur)
        elseif cur then
            table.insert(cur.body, line)
        end
    end
    -- the pinned post (type "pinned": the roadmap and Boosty, the author 2026-10-25) is the
    -- first card always, and it is new again only when its roadmap gets a line: read by
    -- the last released line, not by its title and date
    for i, p in ipairs(posts) do
        if string.lower(p.tag) == "pinned" then
            local last = N.roadNow(p)
            p.id = "pinned|" .. (last and (last.date .. "|" .. last.version) or p.date)
            if i > 1 then
                table.remove(posts, i)
                table.insert(posts, 1, p)
            end
            break
        end
    end
    N.posts = posts
    return posts
end

function N.isPinned(p)
    return p ~= nil and string.lower(p.tag or "") == "pinned"
end

--- The pinned post's colour: coin gold, warmer than the sand (the mockup's --gold).
N.PINNED_COLOR = {r = 0xe0 / 255, g = 0xb6 / 255, b = 0x5e / 255}

--- The pinned post's roadmap, from its lines
---   @road date | version | title | text | picture | the post it opens
--- (date "-": a stage to come; picture: road_<name>_<lang>.png of media/knox/news/road;
--- the post: the title of an update in the same file). Read once per post.
function N.road(p)
    if p.road then return p.road end
    local rows = {}
    for _, line in ipairs(p.body or {}) do
        local s = string.match(line, "^%s*@road%s+(.*)$")
        if s then
            local f = {}
            for v in string.gmatch(s .. "|", "([^|]*)|") do table.insert(f, trim(v)) end
            local row = {date = f[1] or "", version = f[2] or "", title = f[3] or "", text = f[4] or "",
                         preview = f[5] or "", link = f[6] or ""}
            row.future = row.date == "-" or row.date == ""
            if row.future then row.date = "" end
            table.insert(rows, row)
        end
    end
    p.road = rows
    return rows
end

--- The roadmap's "now": its last released line (nil: none).
function N.roadNow(p)
    local rows = N.road(p)
    for i = #rows, 1, -1 do
        if not rows[i].future then return rows[i], i end
    end
    return nil
end

--- The post of this file with this title (a roadmap card opens it).
function N.byTitle(title)
    if not N.posts then N.load() end
    for _, p in ipairs(N.posts) do
        if p.title == title then return p end
    end
    return nil
end

local seen = nil

local function loadSeen()
    seen = {}
    local r = getFileReader(SEEN_FILE, false)
    if not r then return end
    local line = r:readLine()
    while line do
        seen[line] = true
        line = r:readLine()
    end
    r:close()
end

local function saveSeen()
    local w = getFileWriter(SEEN_FILE, true, false)
    if not w then return end
    for id in pairs(seen) do w:write(id .. "\n") end
    w:close()
end

function N.isSeen(post)
    if not seen then loadSeen() end
    return seen[post.id] == true
end

function N.markSeen(post)
    if N.isSeen(post) then return end
    seen[post.id] = true
    saveSeen()
end

--- A post new again (the bench: the pinned post opening by itself, 2026-10-25).
function N.markUnseen(post)
    if not N.isSeen(post) then return end
    seen[post.id] = nil
    saveSeen()
end

--- Are there posts not read yet? (the dot on the top bar's stage plate)
function N.hasUnread()
    if not N.posts then N.load() end
    for _, p in ipairs(N.posts) do
        if not N.isSeen(p) then return true end
    end
    return false
end

-- Colors of a post's tag and of list markers
local MARK = {["+"] = "good", ["*"] = "accent", ["-"] = "dim", ["!"] = "bad"}

-- A post's type is a fixed word (update, news, plans): its plate color, and
-- its caption from the translation IGUI_Knox_NewsTag_<type> (another word
-- is shown as written, in the news color).
local TAG_COLOR = {update = "accent", news = "good", plans = "dim"}

-- a technical update (fixes, speed, compatibility - no new content; the author,
-- 2026-10-22): steel blue, its own pictures (see KnoxMenuNews)
N.TECH_COLOR = {r = 0x86 / 255, g = 0xa8 / 255, b = 0xbf / 255}

local function tagColor(tag)
    if string.lower(tag or "") == "tech" then return N.TECH_COLOR end
    if string.lower(tag or "") == "pinned" then return N.PINNED_COLOR end
    return T.color[TAG_COLOR[string.lower(tag or "")] or "good"]
end

local function tagText(tag)
    return getTextOrNull("IGUI_Knox_NewsTag_" .. string.lower(tag or "")) or tag
end

--- A post's own colour, or the main one: @frame #rrggbb (0.9.8's green), a technical
--- update's steel blue. Its plate, the line under its title, its headings, its
--- "changed" markers, its pictures' frames and its scroll bar take it - the post
--- keeps one palette (the author, 2026-10-22).
function N.colorOf(p)
    if p.frameColor == nil then
        p.frameColor = false
        for _, line in ipairs(p.body or {}) do
            local hx = string.match(line, "^%s*@frame%s+#(%x%x%x%x%x%x)")
            if hx then
                p.frameColor = {r = tonumber(hx:sub(1, 2), 16) / 255, g = tonumber(hx:sub(3, 4), 16) / 255,
                                b = tonumber(hx:sub(5, 6), 16) / 255}
            end
        end
        if not p.frameColor and string.lower(p.tag or "") == "tech" then p.frameColor = N.TECH_COLOR end
        if not p.frameColor and N.isPinned(p) then p.frameColor = N.PINNED_COLOR end
    end
    return p.frameColor or T.color.accent
end

--- A post's body as blocks for one text width: paragraphs, headings, list
--- items (marker color), pictures.
local function layoutBody(post, width)
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
            table.insert(blocks, {kind = "heading", text = trim(string.sub(s, 3))})
        elseif MARK[mark] and string.sub(s, 2, 2) == " " then
            flush()
            local indent = math.floor(T.fontH(T.fontText) * 0.9)
            local color = (mark == "*" and N.colorOf(post)) or T.color[MARK[mark]]
            table.insert(blocks, {kind = "item", color = color, indent = indent,
                                  lines = T.wrap(trim(string.sub(s, 2)), T.fontText, width - indent)})
        elseif mark == "@" then
            flush()
            -- (@banner and @art are the main menu's pictures of the post, not the body's;
            -- @dash is the car's dashboard itself, live - KnoxDashboard.newsDemo)
            if string.match(s, "^@dash") then
                local body, hot = string.match(s, "^@dash%s*(%a*)%s*(%a*)")
                dashes = dashes + 1
                table.insert(blocks, {kind = "dash", body = body, hot = hot == "hot", key = (post.title or "") .. "#" .. dashes})
            elseif string.match(s, "^@gen") then
                -- (@gen [worn]: the generator's window itself, live - KnoxGeneratorWindow.newsDemo)
                dashes = dashes + 1
                table.insert(blocks, {kind = "gen", worn = string.match(s, "^@gen%s+worn") ~= nil, key = (post.title or "") .. "#" .. dashes})
            elseif string.match(s, "^@vp") then
                -- (@vp [fridge]: Knox's crosshair panel itself, live - KnoxCrosshairDemo)
                dashes = dashes + 1
                table.insert(blocks, {kind = "vp", place = string.match(s, "^@vp%s*(%a*)"), key = (post.title or "") .. "#" .. dashes})
            elseif string.match(s, "^@open%s+settings") then
                -- (a button that opens Knox's settings window itself)
                table.insert(blocks, {kind = "open", what = "settings", text = getText("IGUI_Knox_NewsOpenSettings"), rect = {0, 0, 0, 0}})
            elseif not string.match(s, "^@banner") and not string.match(s, "^@art") and not string.match(s, "^@frame") then
                local tex = getTexture("media/knox/news/" .. trim(string.sub(s, 2)))
                if tex then table.insert(blocks, {kind = "image", tex = tex}) end
            end
        else
            table.insert(para, s)
        end
    end
    flush()
    return blocks
end

-- Page ----------------------------------------------------------------------------

function KnoxNews:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.listScroll = 0
    o.bodyScroll = 0
    return o
end

function KnoxNews:createChildren()
    self:reload()
end

function KnoxNews:reload()
    self.posts = N.load()
    -- (the pinned post opens over the screen, as in the menu: the newest other one is shown here)
    self.selected = N.isPinned(self.posts[1]) and self.posts[2] or self.posts[1]
    self.blocks = nil
    if self.selected then N.markSeen(self.selected) end
end

--- Sizes from the cell: the feed column on the left, the post on the right.
function KnoxNews:metrics()
    local c, pad = T.cell, T.pad
    local m = {}
    m.listW = math.floor(c * 8.5)
    m.headH = T.fontH(T.fontHeader) + pad * 2
    m.cardH = T.fontH(T.fontTile) + T.fontH(T.fontText) * 2 + pad * 2
    m.cardGap = math.max(4, math.floor(c / 8))
    m.readX = pad + m.listW + pad * 2
    m.readW = self:getWidth() - m.readX - pad
    m.textW = math.min(m.readW - pad * 4, c * 22)   -- lines no longer than easy reading
    return m
end

function KnoxNews:select(post)
    -- the pinned post: its roadmap and Boosty over the whole screen, as the main menu shows
    -- it (the author, 2026-10-25) - this page's reader has none of that
    if N.isPinned(post) and KnoxMenuNewsReader then
        KnoxMenuNewsReader.open(post)
        return
    end
    if post == self.selected then return end
    self.selected = post
    self.blocks = nil
    self.bodyScroll = 0
    N.markSeen(post)
    getSoundManager():playUISound("UISelectListItem")
end

local function tagPlate(ui, x, y, tag, color)
    local f = T.fontTile
    local text = T.upper(tag)
    local w, h = T.measure(f, text) + 10, T.fontH(f) + 4
    T.rect(ui, x, y, w, h, color)
    T.text(ui, text, x + 5, y + 2, T.color.ink, f)
    return w
end

function KnoxNews:prerender()
    local W, H = self:getWidth(), self:getHeight()
    local m = self:metrics()
    self.m = m
    local pad = T.pad
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()

    -- panels, as the screen's columns
    T.rect(self, 0, 0, W, H, T.color.window)
    T.border(self, 0, 0, W, H, T.color.border)
    T.rect(self, m.readX - pad, 0, 1, H, T.color.border)

    -- feed: title, then the posts as cards (scrolls with the wheel)
    T.caps(self, getText("IGUI_Knox_News"), pad, pad, T.color.bright, T.fontHeader)
    T.textRight(self, tostring(#self.posts), pad + m.listW, pad + T.fontH(T.fontHeader) - T.fontH(T.fontText),
        T.color.dim, T.fontText)
    local listTop, listH = m.headH, H - m.headH - pad
    local total = #self.posts * (m.cardH + m.cardGap)
    self.listScroll = math.max(0, math.min(self.listScroll, total - listH))
    self:setStencilRect(0, listTop, m.readX - pad, listH)
    self.cards = {}
    local y = listTop - self.listScroll
    for _, p in ipairs(self.posts) do
        local r = {pad, y, m.listW, m.cardH}
        table.insert(self.cards, {rect = r, post = p})
        local sel = p == self.selected
        local hot = over and T.inRect(mx, my, r) and my >= listTop
        T.rect(self, r[1], r[2], r[3], r[4], sel and T.color.header or T.color.cell)
        if hot and not sel then self:drawRect(r[1], r[2], r[3], r[4], 0.05, 1, 1, 1) end
        T.border(self, r[1], r[2], r[3], r[4], sel and N.colorOf(p) or T.color.border)
        if sel then T.rect(self, r[1], r[2], 3, r[4], N.colorOf(p)) end
        local cx, cy = r[1] + pad, r[2] + pad
        if p.tag ~= "" then tagPlate(self, cx, cy, tagText(p.tag), tagColor(p.tag)) end
        if not N.isSeen(p) then
            local d = math.max(6, math.floor(T.cell / 7))
            local c = T.color.accent
            local a = 0.55 + 0.45 * math.sin(getTimestampMs() / 1000 * math.pi * 1.6)
            self:drawRect(r[1] + r[3] - pad - d, cy + 2, d, d, a, c.r, c.g, c.b)
        end
        cy = cy + T.fontH(T.fontTile) + 6
        T.text(self, T.fit(p.title, T.fontText, r[3] - pad * 2), cx, cy, sel and T.color.bright or T.color.text, T.fontText)
        cy = cy + T.fontH(T.fontText)
        local meta = p.version ~= "" and (p.version .. "  " .. DOT .. "  " .. p.date) or p.date
        T.text(self, meta, cx, cy, T.color.dim, T.fontText)
        y = y + m.cardH + m.cardGap
    end
    self:clearStencilRect()
    if #self.posts == 0 then
        T.text(self, getText("IGUI_Knox_NewsEmpty"), pad, listTop, T.color.dim, T.fontText)
    end

    -- the post
    local p = self.selected
    if not p then return end
    local pc = N.colorOf(p)
    local rx = m.readX + pad
    if not self.blocks or self.blocksW ~= m.textW then
        self.blocks = layoutBody(p, m.textW)
        self.blocksW = m.textW
        self.titleLines = T.wrap(p.title, T.fontHeader, m.textW)
    end
    local top = pad
    local viewH = H - top - pad
    self:setStencilRect(m.readX, top, W - m.readX, viewH)
    y = top - self.bodyScroll
    -- tag, version and date over the title
    local px = rx
    if p.tag ~= "" then px = px + tagPlate(self, rx, y + 2, tagText(p.tag), p.frameColor or tagColor(p.tag)) + 10 end
    local meta = p.version ~= "" and (p.version .. "  " .. DOT .. "  " .. p.date) or p.date
    T.text(self, meta, px, y + 2, T.color.dim, T.fontText)
    y = y + T.fontH(T.fontText) + pad
    for _, l in ipairs(self.titleLines) do
        T.text(self, l, rx, y, T.color.bright, T.fontHeader)
        y = y + T.fontH(T.fontHeader)
    end
    y = y + pad
    T.rect(self, rx, y, m.textW, 2, pc)
    y = y + pad + 2
    local lh = T.fontH(T.fontText) + 4
    for _, b in ipairs(self.blocks) do
        if b.kind == "text" then
            for _, l in ipairs(b.lines) do
                T.text(self, l, rx, y, T.color.text, T.fontText)
                y = y + lh
            end
            y = y + math.floor(lh * 0.6)
        elseif b.kind == "heading" then
            y = y + math.floor(lh * 0.4)
            T.caps(self, b.text, rx, y, pc)
            y = y + T.fontH(T.fontCaps) + 4
            T.rect(self, rx, y, m.textW, 1, T.color.border)
            y = y + math.floor(lh * 0.5)
        elseif b.kind == "item" then
            local d = math.max(6, math.floor(T.fontH(T.fontText) / 3))
            T.rect(self, rx + 2, y + math.floor((T.fontH(T.fontText) - d) / 2) + 1, d, d, b.color)
            for _, l in ipairs(b.lines) do
                T.text(self, l, rx + b.indent, y, T.color.text, T.fontText)
                y = y + lh
            end
            y = y + 2
        elseif b.kind == "image" then
            local tw, th = b.tex:getWidth(), b.tex:getHeight()
            local w = math.min(m.textW, tw)
            local h = math.floor(th * w / math.max(1, tw))
            T.rect(self, rx - 2, y - 2, w + 4, h + 4, T.color.cell)
            if b.tex:isReady() then self:drawTextureScaled(b.tex, rx, y, w, h, 1, 1, 1, 1) end   -- (not before it is read: red-white squares, 2026-10-25)
            T.border(self, rx - 2, y - 2, w + 4, h + 4, T.color.border)
            y = y + h + pad
        elseif b.kind == "dash" and KnoxDashboard and KnoxDashboard.newsDemo then
            local d = KnoxDashboard.newsDemo(self, b.key, b.body, b.hot)
            local _, h = d:demoSize(m.textW)
            self.dashView = self.dashView or {0, 0, 0, 0}
            local v = self.dashView
            v[1], v[2], v[3], v[4] = m.readX, top, W - m.readX, viewH
            d:hostAt(self, rx, y, v)
            y = y + h + pad
        elseif b.kind == "gen" and KnoxGeneratorWindow and KnoxGeneratorWindow.newsDemo then
            local d = KnoxGeneratorWindow.newsDemo(self, b.key, b.worn)
            local _, h = d:demoSize(m.textW)
            self.dashView = self.dashView or {0, 0, 0, 0}
            local v = self.dashView
            v[1], v[2], v[3], v[4] = m.readX, top, W - m.readX, viewH
            d:hostAt(self, rx, y, v)
            y = y + h + pad
        elseif b.kind == "open" then
            local r = b.rect
            local bw, bh = T.buttonW(b.text) + pad * 2, math.floor(T.cell * 0.7)
            r[1], r[2], r[3], r[4] = rx, y, bw, bh
            b.shown = y + bh > top and y < top + viewH
            if b.shown then
                openOpts.hover = T.inRect(self:getMouseX(), self:getMouseY(), r)
                T.button(self, r, b.text, openOpts)
            end
            y = y + bh + pad
        elseif b.kind == "vp" and KnoxCrosshair and KnoxCrosshair.newsDemo then
            local d = KnoxCrosshair.newsDemo(self, b.key, b.place)
            local _, h = d:demoSize(m.textW)
            self.dashView = self.dashView or {0, 0, 0, 0}
            local v = self.dashView
            v[1], v[2], v[3], v[4] = m.readX, top, W - m.readX, viewH
            d:hostAt(self, rx, y, v)
            y = y + h + pad
        end
    end
    self:clearStencilRect()
    -- how far the post can scroll; a bar when it's longer than the view
    local contentH = y + self.bodyScroll - top
    self.bodyMax = math.max(0, contentH - viewH)
    if self.bodyScroll > self.bodyMax then self.bodyScroll = self.bodyMax end
    self.bar = nil
    if contentH > viewH then
        local barH = math.max(T.cell, math.floor(viewH * viewH / contentH))
        -- taken by the mouse: the knob dragged, a click on the track brings it there
        local drag = self.barDrag
        if drag and not isMouseButtonDown(0) then
            drag = nil
            self.barDrag = nil
        end
        if drag then
            local f = (my - drag.grab - top) / math.max(1, viewH - barH)
            self.bodyScroll = math.max(0, math.min(self.bodyMax, f * self.bodyMax))
        end
        local barY = top + math.floor(self.bodyScroll / self.bodyMax * (viewH - barH))
        self.bar = {track = {W - 18, top, 18, viewH}, knobY = barY, knobH = barH}
        local hot = drag or (over and T.inRect(mx, my, self.bar.track))
        local c = p.frameColor or (hot and T.color.accent or T.color.tileEdge)
        if hot and p.frameColor then c = {r = c.r + (1 - c.r) * 0.35, g = c.g + (1 - c.g) * 0.35, b = c.b + (1 - c.b) * 0.35} end
        self:drawRect(W - (hot and 8 or 6), barY, hot and 5 or 3, barH, 1, c.r, c.g, c.b)
    end
end

function KnoxNews:onMouseDown(x, y)
    for _, bl in ipairs(self.blocks or {}) do
        if bl.kind == "open" and bl.shown and T.inRect(x, y, bl.rect) then
            if bl.what == "settings" and KnoxSettings and not KnoxSettings.instance then KnoxSettings.open() end
            getSoundManager():playUISound("UIActivateButton")
            return true
        end
    end
    local b = self.bar
    if b and T.inRect(x, y, b.track) then
        local onKnob = y >= b.knobY and y < b.knobY + b.knobH
        self.barDrag = {grab = onKnob and (y - b.knobY) or math.floor(b.knobH / 2)}
        return true
    end
    for _, c in ipairs(self.cards or {}) do
        if T.inRect(x, y, c.rect) and y >= (self.m and self.m.headH or 0) then
            self:select(c.post)
            return true
        end
    end
    return true
end

function KnoxNews:onMouseWheel(del)
    local m = self.m
    if not m then return true end
    local step = T.cell
    if self:getMouseX() < m.readX - T.pad then
        self.listScroll = math.max(0, self.listScroll + del * (m.cardH + m.cardGap))
    else
        self.bodyScroll = math.max(0, math.min(self.bodyMax or 0, self.bodyScroll + del * step))
    end
    return true
end

function KnoxNews:onRightMouseUp(x, y) return true end

return KnoxNews
