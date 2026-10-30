-- The mod's settings window. On the left a column of its pages, on the right
-- the page chosen, in a view of its own that scrolls; one height for every page,
-- no more than 15 cells of content and never over the screen (the author,
-- 2026-10-25: "too bulky, doesn't fit some screens, there is no scroll" - remade
-- after the approved mockup .claude/mockups/settings/settings_v1.html).
--   Modules   the parts of the mod a player can switch off, each leaving the
--             game's own screens in its place (see KnoxTheme.MODULES). A switch
--             works from the next load of the Lua: in the main menu the game
--             reloads it at once, in a game it waits for the exit to the menu.
--   Controls  which mouse gesture or key does what in the inventory (see
--             KnoxControls). A plate is clicked, then the gesture is made; it
--             works at once.
-- The rest - the look, loot and bags, the order, the sound, the main menu - are
-- T.LOOK's sliders, T.SWITCHES and T.CHOICES; they work at once.
-- Opened by the tab at the top of the main menu (always there, so a switched
-- off part can be switched back on) and by the button in the Knox screen's top bar.

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "OptionScreens/MainScreen"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxControls"
require "Knox/KnoxOrder"

KnoxSettings = ISPanel:derive("KnoxSettings")

local T = KnoxTheme
local C = KnoxControls
local inRect = T.inRect

--- A slider the server sets in a game with others (the size of bags and pockets:
--- the same for every player, KnoxNet): its value, or nil when it is the player's.
local function serverValue(spec)
    if spec.key == "grid.scale" and KnoxNet and KnoxNet.mp() and KnoxNet.scale then return KnoxNet.scale end
    return nil
end

local DOUBLE_MS = 400              -- two clicks this close are a double click
local SCROLL_MS, FADE_MS = 70, 120 -- the page glides to where the wheel sent it; its edges' fades come and go

KnoxSettings.PAGES = {"modules", "look", "game", "order", "sound", "controls", "menu"}

-- What a page holds, top down: {kind, key, mark}. The sliders, switches and
-- choices are T.LOOK's, T.SWITCHES' and T.CHOICES'; one not listed here goes to
-- the end of the page it names (see pageItems). The modules and the controls
-- are made from T.MODULE_GROUPS and KnoxControls.ACTIONS.
local PAGE_ITEMS = {
    look = {{"sec", "Skin", "beta"}, {"skins"}, {"slider", "skin.hue"}, {"slider", "skin.sat"}, {"slider", "skin.val"},
            {"sec", "Sec_look_screen"}, {"slider", "look.all"}, {"slider", "look.bg"}, {"slider", "look.grid"},
            {"slider", "look.line"}, {"slider", "look.slot"}, {"slider", "look.model"}, {"switch", "anim"}},
    game = {{"sec", "Sec_game_search"}, {"switch", "search"}, {"slider", "search.time"}, {"switch", "scatter"},
            {"choice", "loot.scope"}, {"switch", "vp.panel"}, {"sec", "Sec_game_bags"}, {"slider", "grid.scale"}},
    order = {{"sec", "Order_Title"}, {"choice", "order.rule"}, {"choice", "order.auto"}, {"sec", "Order_Cats"},
             {"cathelp"}, {"cats"}},
    sound = {{"sec", "Sec_sound_ui"}, {"slider", "search.sound"}, {"slider", "ui.sound"},
             {"sec", "Sec_sound_music"}, {"switch", "musicShare"}, {"switch", "musicHear"}, {"slider", "music.others"}},
    menu = {{"sec", "Sec_menu_news"}, {"switch", "news"}, {"sec", "Camp_Title"}, {"camp"}},
}

local function specOf(list, key)
    for _, s in ipairs(list) do
        if s.key == key then return s end
    end
    return nil
end

--- A switch shown here (only = "viewpoint": only where Viewpoint has the part it needs - 2026-10-25).
local function listed(s)
    return s.only ~= "viewpoint" or (KnoxCompat ~= nil and KnoxCompat.vpHas("panel") == true)
end

--- The items of a page, in order.
local function pageItems(page)
    local out = {}
    if page == "modules" then
        for _, g in ipairs(T.MODULE_GROUPS) do
            table.insert(out, {"sec", "Modules_Group_" .. g.id})
            for _, name in ipairs(g.list) do table.insert(out, {"mod", name}) end
        end
        table.insert(out, {"note"})
        return out
    end
    if page == "controls" then
        table.insert(out, {"sec", "Controls_Title", "reset"})
        for _, a in ipairs(C.ACTIONS) do table.insert(out, {"bind", a.id}) end
        table.insert(out, {"help"})
        -- Viewpoint's crosshair panel keys, where it is (the author, 2026-10-29)
        if KnoxCompat and KnoxCompat.vpHas("panel") == true and C.vpKeys() then
            table.insert(out, {"sec", "Controls_VP", "vpreset"})
            for _, a in ipairs(C.VP_ACTIONS) do table.insert(out, {"bind", a.id}) end
            table.insert(out, {"help", "vp"})
        end
        return out
    end
    local seen = {}
    for _, items in pairs(PAGE_ITEMS) do
        for _, it in ipairs(items) do
            if it[2] then seen[it[1] .. ":" .. it[2]] = true end
        end
    end
    for _, it in ipairs(PAGE_ITEMS[page]) do table.insert(out, it) end
    -- (one added to the theme later and not placed above: at the end of its page)
    local function rest(kind, list)
        for _, s in ipairs(list) do
            local p = s.page or "look"
            if p == "skin" then p = "look" end
            if p == page and not seen[kind .. ":" .. s.key] then table.insert(out, {kind, s.key}) end
        end
    end
    rest("slider", T.LOOK)
    rest("switch", T.SWITCHES)
    rest("choice", T.CHOICES)
    return out
end

function KnoxSettings:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false   -- moved by its header, see KnoxWindowDrag
    o.want = {}
    for _, name in ipairs(T.MODULES) do o.want[name] = T.moduleSaved(name) end
    -- the page it was left on; the first time: the modules in the menu, the look in a game
    o.page = KnoxSettings.lastPage or (getPlayer() and "look" or "modules")
    o.scroll, o.target, o.fadeTop, o.fadeBottom = 0, 0, 0, 0
    return o
end

--- Has the player changed a module's switch in this window (from what is saved)?
function KnoxSettings:changed()
    for _, name in ipairs(T.MODULES) do
        if self.want[name] ~= T.moduleSaved(name) then return true end
    end
    return false
end

--- Does what is saved differ from what runs (waiting for the Lua to reload)?
local function pending()
    for _, name in ipairs(T.MODULES) do
        if T.moduleSaved(name) ~= (T.modules[name] == true) then return true end
    end
    return false
end

function KnoxSettings:layout()
    T.ensure()
    local pad, c = T.pad, T.cell
    local ft, fc = T.fontH(T.fontText), T.fontH(T.fontCaps)
    local L = {}
    L.headerH = T.sectionH + 8
    -- the pages on the left: a column as wide as the longest name needs
    local sw = math.floor(c * 3.2)
    L.pageNames = {}
    for _, p in ipairs(KnoxSettings.PAGES) do
        local s = T.upper(getText("IGUI_Knox_Page_" .. p))
        L.pageNames[p] = s
        sw = math.max(sw, math.ceil(T.measure(T.fontCaps, s)) + pad * 4)
    end
    L.sideW = sw
    L.w = sw + 1 + math.floor(c * 13)   -- the page: the old window's width, its parts keep their sizes
    L.x0 = sw + 1 + pad * 2             -- the page's left
    L.x1 = L.w - pad * 2                -- and right
    local wide = L.x1 - L.x0
    L.box = math.floor(c * 0.5)
    L.textX = L.x0 + L.box + pad
    L.textW = L.x1 - L.textX
    L.sliderH = math.floor(c * 0.5)
    L.sliderX = L.x0 + math.floor(c * 5.2)
    L.sliderW = L.x1 - L.sliderX - math.floor(c * 1.3)
    L.choiceH = math.floor(c * 0.6)
    L.skinBtnH = math.floor(c * 0.6)
    L.catRowH = math.floor(c * 0.55)
    L.bindH = math.floor(c * 0.72)
    L.plateW = math.floor(c * 4.6)
    L.itemH = math.max(math.floor(c * 0.8), fc + pad)
    L.footH = math.floor(c * 0.7)
    -- (a text line keeps a little under its letters: a hard edge - a slider, a row of
    -- buttons - gets as much after it, so every gap between two items looks the same)
    local _, _, _, hb = T.inkBox(T.fontText, "H")
    L.tail = math.max(0, ft + 2 - hb)
    local rp = math.floor(pad * 0.6)
    L.pages = {}
    local tallest = 0
    for _, p in ipairs(KnoxSettings.PAGES) do
        local y = pad * 2   -- (in the page's own coordinates; drawn moved by the scroll)
        local items = {}
        for idx, it in ipairs(pageItems(p)) do
            local kind, key = it[1], it[2]
            local e = {kind = kind, key = key, y = y}
            local keep = true
            if kind == "sec" then
                -- (a line over a section, but not over the modules' groups: their rows have lines of their own)
                if idx > 1 then
                    y = y + pad * 2
                    e.y, e.line = y, p ~= "modules"
                end
                e.text = T.upper(getText("IGUI_Knox_" .. key))
                e.beta, e.reset, e.vp = it[3] == "beta", it[3] == "reset" or it[3] == "vpreset", it[3] == "vpreset"
                y = y + fc + pad
            elseif kind == "mod" then
                e.name = T.upper(getText("IGUI_Knox_Module_" .. key))
                e.lines = T.wrap(getText("IGUI_Knox_Module_" .. key .. "_Info"), T.fontText, L.textW)
                e.h = rp + math.max(L.box, fc) + 2 + #e.lines * (ft + 2) + rp
                y = y + e.h
            elseif kind == "note" then
                y = y + math.floor(pad / 2)
                e.y = y
                e.lines = T.wrap(getText(getPlayer() and "IGUI_Knox_Modules_NoteGame" or "IGUI_Knox_Modules_NoteMenu"), T.fontText, wide)
                y = y + #e.lines * (ft + 2)
            elseif kind == "slider" then
                e.spec = specOf(T.LOOK, key)
                keep = e.spec ~= nil
                if keep then
                    e.name = getText("IGUI_Knox_" .. (string.gsub(key, "%.", "_")))
                    y = y + L.sliderH + pad + L.tail
                end
            elseif kind == "switch" then
                e.spec = specOf(T.SWITCHES, key)
                keep = e.spec ~= nil and listed(e.spec)
                if keep then
                    e.name, e.new = getText("IGUI_Knox_Switch_" .. key), e.spec.new
                    e.lines = T.wrap(getText("IGUI_Knox_Switch_" .. key .. "_Info"), T.fontText, L.textW)
                    e.h = math.max(L.box, ft) + 2 + #e.lines * (ft + 2)
                    y = y + e.h + pad
                end
            elseif kind == "choice" then
                e.spec = specOf(T.CHOICES, key)
                keep = e.spec ~= nil
                if keep then
                    local nm = (string.gsub(key, "%.", "_"))
                    e.name, e.new = getText("IGUI_Knox_Choice_" .. nm), e.spec.new
                    e.lines = T.wrap(getText("IGUI_Knox_Choice_" .. nm .. "_Info"), T.fontText, wide)
                    e.labels = {}
                    for i, v in ipairs(e.spec.values) do e.labels[i] = getText("IGUI_Knox_Choice_" .. nm .. "_" .. v) end
                    e.by = y + ft + 2 + #e.lines * (ft + 2) + 4
                    y = e.by + L.choiceH + pad + L.tail
                end
            elseif kind == "skins" then
                e.lines = T.wrap(getText("IGUI_Knox_Skin_Info"), T.fontText, wide)
                e.labels = {}
                for i, sk in ipairs(T.SKINS) do e.labels[i] = getText("IGUI_Knox_Skin_" .. sk.id) end
                e.sy = y + #e.lines * (ft + 2) + 6
                y = e.sy + math.ceil(#T.SKINS / 4) * (L.skinBtnH + 6) - 6 + pad + L.tail
            elseif kind == "cathelp" then
                e.lines = T.wrap(getText("IGUI_Knox_Order_Cats_Info"), T.fontText, wide)
                y = y + #e.lines * (ft + 2) + 4
            elseif kind == "cats" then
                L.cats = e
                y = y + #KnoxOrder.CATS * (L.catRowH + 2) + pad
            elseif kind == "bind" then
                -- (a long name goes on two lines rather than under its plate)
                e.lines = T.wrap(C.name(key), T.fontText, wide - L.plateW - pad)
                e.h = math.max(L.bindH, #e.lines * (ft + 2) + 4)
                y = y + e.h + 4
            elseif kind == "help" then
                y = y + math.floor(pad / 2)
                e.y = y
                e.lines = T.wrap(key == "vp" and getText("IGUI_Knox_Controls_VPHelp")
                    or (getText("IGUI_Knox_Controls_Help") .. " " .. getText("IGUI_Knox_Controls_HelpMore")), T.fontText, wide)
                y = y + #e.lines * (ft + 2)
            elseif kind == "camp" then
                e.lines = T.wrap(getText("IGUI_Knox_Camp_Reset_Info"), T.fontText, wide)
                e.by = y + #e.lines * (ft + 2) + 6
                y = e.by + L.footH
            end
            if keep then table.insert(items, e) end
        end
        y = y + pad * 2
        L.pages[p] = {items = items, h = y}
        tallest = math.max(tallest, y)
    end
    -- the foot: a line, then the buttons; the page scrolls between the header and it
    L.footZone = pad * 2 + L.footH + pad * 2
    local content = math.max(#KnoxSettings.PAGES * L.itemH + pad * 2, math.min(tallest, c * 15))
    L.h = math.min(L.headerH + 1 + content + L.footZone, getCore():getScreenHeight() - c * 2)
    L.viewY = L.headerH + 1
    L.viewH = L.h - L.footZone - L.viewY
    L.footY = L.h - pad * 2 - L.footH
    -- the strings and buttons of the frame (made once)
    L.title = T.upper(getText("IGUI_Knox_Settings"))
    L.newMark, L.betaMark = T.upper(getText("IGUI_Knox_New")), T.upper(getText("IGUI_Knox_Beta"))
    L.pendingMark, L.serverMark = T.upper(getText("IGUI_Knox_Modules_Pending")), T.upper(getText("IGUI_Knox_SetByServer"))
    L.applyText, L.closeText, L.resetText = getText("IGUI_Knox_Apply"), getText("IGUI_Knox_Close"), getText("IGUI_Knox_Controls_Reset")
    L.campText, L.campSure = getText("IGUI_Knox_Camp_Reset"), getText("IGUI_Knox_Camp_Reset_Sure")
    local bw = math.floor(c * 2.6)
    local aw = math.max(T.buttonW(L.applyText) + pad * 2, bw)
    local cw = math.max(T.buttonW(L.closeText) + pad * 2, bw)
    L.applyR = {L.w - pad * 2 - aw, L.footY, aw, L.footH}
    L.closeR = {L.w - pad * 3 - aw - cw, L.footY, cw, L.footH}
    L.closeAloneR = {L.w - pad * 2 - cw, L.footY, cw, L.footH}   -- (no Apply on the page: Close at the right)
    L.resetW = T.buttonW(L.resetText, T.fontTile) + pad * 2
    L.campW = math.max(T.buttonW(L.campText, T.fontTile), T.buttonW(L.campSure, T.fontTile)) + pad * 2
    return L
end

function KnoxSettings:createChildren()
    self.L = self:layout()
    if not self.L.pages[self.page] then self.page = "modules" end   -- (a page that is no more)
    self:setWidth(self.L.w)
    self:setHeight(self.L.h)
end

-- Rects, filled in, not made anew (the window is drawn every frame) --------------------

local R1, R2, R3 = {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}
local function set(r, x, y, w, h)
    r[1], r[2], r[3], r[4] = x, y, w, h
    return r
end

--- Is Apply on the page: the modules' page, or a module changed (or waiting for a reload).
function KnoxSettings:hasApply()
    return self.page == "modules" or self:changed() or pending()
end

function KnoxSettings:closeButtonRect()
    return self:hasApply() and self.L.closeR or self.L.closeAloneR
end

--- The page's column on the left: the i-th page's row (the first page's name on the
--- line of the page's first heading).
function KnoxSettings:sideRect(i, r)
    local L, pad = self.L, T.pad
    local y0 = L.viewY + pad * 2 + math.floor(T.fontH(T.fontCaps) / 2) - math.floor(L.itemH / 2)
    return set(r or R1, 0, y0 + (i - 1) * L.itemH, L.sideW, L.itemH)
end

--- The page's top on the screen (in the window), moved by the scroll.
function KnoxSettings:pageTop()
    return self.L.viewY - math.floor(self.scroll + 0.5)
end

function KnoxSettings:maxScroll()
    return math.max(0, self.L.pages[self.page].h - self.L.viewH)
end

--- Is (x, y) in the page's view (not in the column, the header or the foot)?
function KnoxSettings:inView(x, y)
    local L = self.L
    return x > L.sideW and x < L.w and y >= L.viewY and y < L.viewY + L.viewH
end

--- The scroll bar: x, its track's top and length, the thumb's length and top (nil: all fits).
function KnoxSettings:bar()
    local L, pad = self.L, T.pad
    local ch = L.pages[self.page].h
    if ch <= L.viewH then return nil end
    local top, track = L.viewY + pad * 2, L.viewH - pad * 4
    local box = math.max(8, math.floor(track * L.viewH / ch + 0.5))
    local pos = self.scroll / math.max(1, self:maxScroll())
    return L.w - pad, top, track, box, top + math.floor((track - box) * pos + 0.5)
end

--- A slider's value under the mouse on its track, in the slider's own steps.
function KnoxSettings:sliderValue(e, mx)
    local L, spec = self.L, e.spec
    local f = math.max(0, math.min(1, (mx - L.sliderX) / math.max(1, L.sliderW)))
    local steps = (spec.max - spec.min) / spec.step
    return spec.min + math.floor(f * steps + 0.5) * spec.step
end

function KnoxSettings:sliderRect(e, oy)
    local L = self.L
    return set(R1, L.sliderX - L.sliderH, oy + e.y, L.sliderW + L.sliderH * 2, L.sliderH)
end

--- A choice's i-th button: side by side across the page, the last one to its edge.
function KnoxSettings:choiceRect(e, i, oy)
    local L = self.L
    local n, gap = #e.spec.values, 4
    local bw = math.floor((L.x1 - L.x0 - gap * (n - 1)) / n)
    local x = L.x0 + (i - 1) * (bw + gap)
    return set(R1, x, oy + e.by, i == n and (L.x1 - x) or bw, L.choiceH)
end

--- The skins' i-th button, four a row (the last of a row to the page's edge).
function KnoxSettings:skinRect(e, i, oy)
    local L = self.L
    local gap, n = 6, 4
    local bw = math.floor((L.x1 - L.x0 - gap * (n - 1)) / n)
    local col, row = (i - 1) % n, math.floor((i - 1) / n)
    local x = L.x0 + col * (bw + gap)
    return set(R1, x, oy + e.sy + row * (L.skinBtnH + gap), col == n - 1 and (L.x1 - x) or bw, L.skinBtnH)
end

--- A row of the categories' order: its plate, and its two arrow buttons on the
--- left (up, down). The plate is taken by the mouse and dragged to its place.
function KnoxSettings:catRects(i, oy)
    local L = self.L
    local y = oy + L.cats.y + (i - 1) * (L.catRowH + 2)
    local bw = L.catRowH
    local px = L.x0 + bw * 2 + 8
    return set(R1, px, y, L.x1 - px, L.catRowH), set(R2, L.x0, y, bw, L.catRowH), set(R3, L.x0 + bw + 4, y, bw, L.catRowH)
end

--- The row the mouse is at while a category is dragged (1..n).
function KnoxSettings:catRowAt(my, n)
    local L = self.L
    return math.max(1, math.min(n, math.floor((my - self:pageTop() - L.cats.y) / (L.catRowH + 2)) + 1))
end

function KnoxSettings:plateRect(e, oy)
    local L = self.L
    return set(R1, L.x1 - L.plateW, oy + e.y + math.floor((e.h - L.bindH) / 2), L.plateW, L.bindH)
end

function KnoxSettings:campRect(e, oy)
    local L = self.L
    return set(R1, L.x0, oy + e.by, L.campW, L.footH)
end

function KnoxSettings:resetRect(e, oy)
    local L = self.L
    local fc = T.fontH(T.fontCaps)
    return set(R1, L.x1 - L.resetW, oy + e.y - 4, L.resetW, fc + 8)
end

function KnoxSettings:closeRect()
    local s = self.L.headerH - 8
    return self:getWidth() - s - 4, 4, s
end

--- The colours a skin's button shows: its window and its main colour (kept: drawn each frame).
local swatches = {}
local function skinSwatch(sk)
    if sk.id == "custom" then return T.color.window, T.customAccent() end
    local sw = swatches[sk.id]
    if not sw then
        local function hx(s, base)
            if not s then return base end
            return {r = tonumber(s:sub(2, 3), 16) / 255, g = tonumber(s:sub(4, 5), 16) / 255, b = tonumber(s:sub(6, 7), 16) / 255}
        end
        sw = {hx(sk.window, {r = 0.07, g = 0.078, b = 0.078}), hx(sk.accent, {r = 0.831, g = 0.765, b = 0.541})}
        swatches[sk.id] = sw
    end
    return sw[1], sw[2]
end

--- An arrow button: a frame and a triangle pointing up or down.
local function arrowButton(ui, r, up, hover, disabled)
    local c = disabled and T.color.tileEdge or (hover and T.color.accent or T.color.text)
    T.rect(ui, r[1], r[2], r[3], r[4], T.color.buttonBg)
    if hover and not disabled then T.tileFrame(ui, r[1], r[2], r[3], r[4], T.color.accent)
    else T.border(ui, r[1], r[2], r[3], r[4], T.color.tileEdge) end
    local n = math.max(3, math.floor(r[3] / 5))          -- rows of the triangle
    local cx = r[1] + math.floor(r[3] / 2)
    local top = r[2] + math.floor((r[4] - n) / 2)
    for i = 0, n - 1 do
        local half = up and i or (n - 1 - i)
        ui:drawRect(cx - half, top + i, half * 2 + 1, 1, 1, c.r, c.g, c.b)
    end
end

-- Drawing helpers (the kit's, with their options filled in, not made anew) -------------

local band, labelOpts = {0, 0, 0, 0}, {}
local function label(ui, s, x, y, w, h, c, font, align)
    band[1], band[2], band[3], band[4] = x, y, w, h
    labelOpts.font, labelOpts.align = font, align
    return T.label(ui, s, band, c, labelOpts)
end

local markRect, markOpts = {0, 0, 0, 0}, {}
--- The small NEW / BETA plate after a name; y its top.
local function plateMark(ui, s, x, y, col)
    local mw = T.measure(T.fontTile, s) + 10
    markOpts.fill, markOpts.color, markOpts.font = col, T.color.ink, T.fontTile
    T.plate(ui, set(markRect, x, y, mw, T.fontTileH + 4), s, markOpts)
end

local buttonOpts = {}
local function button(ui, r, s, hover, primary, disabled, font)
    buttonOpts.hover, buttonOpts.primary, buttonOpts.disabled, buttonOpts.font = hover, primary, disabled, font
    T.button(ui, r, s, buttonOpts)
end

local serverOpts = {}
--- Lines of text one under another from y.
local function lines(ui, list, x, y, c)
    local ft = T.fontH(T.fontText)
    for _, line in ipairs(list) do
        T.text(ui, line, x, y, c, T.fontText)
        y = y + ft + 2
    end
end

--- A category's row text, "3.  Food" (made once for each place and category).
local catLabels = {}
local function catLabel(i, cat)
    local row = catLabels[i]
    if not row then row = {} catLabels[i] = row end
    local s = row[cat]
    if not s then s = i .. ".  " .. getText("IGUI_Knox_Cat_" .. cat) row[cat] = s end
    return s
end

-- Controls: catching a gesture ---------------------------------------------------

function KnoxSettings:assign(gesture)
    local cap = self.capture
    if not cap then return end
    if C.vp(cap.id) then C.vpSet(cap.id, gesture) else C.set(cap.id, gesture) end
    T.saveSettings()
    self.capture = nil
    getSoundManager():playUISound("UIActivateButton")
end

--- A key was released while the window is up: true = it was the window's.
--- (Called by the window's own key event and by the Knox screen's, which gets
--- the keys first when the window is opened over it.)
function KnoxSettings:keyReleased(key)
    local now = getTimestampMs()
    if self.keyStamp and self.keyKey == key and now - self.keyStamp < 80 then return true end   -- the same key, told twice
    local cap = self.capture
    if not cap then
        if key ~= Keyboard.KEY_ESCAPE then return false end
        self.keyStamp, self.keyKey = now, key
        self:close()
        return true
    end
    self.keyStamp, self.keyKey = now, key
    if key == Keyboard.KEY_ESCAPE then
        self.capture = nil
    elseif key == Keyboard.KEY_DELETE or key == Keyboard.KEY_BACK then
        self:assign("")
    elseif cap.kind == "key" and not C.isModifierKey(key) then
        self:assign(C.mods() .. "key:" .. tostring(key))
    elseif cap.kind == "hold" then
        -- a key held down: Alt, Ctrl or Shift alone is one too
        self:assign("key:" .. tostring(key))
    end
    return true
end

function KnoxSettings:isKeyConsumed(key)
    return self.capture ~= nil or key == Keyboard.KEY_ESCAPE
end

function KnoxSettings:onKeyRelease(key)
    self:keyReleased(key)
end

-- Drawing -------------------------------------------------------------------------------

--- One item of the page; oy the page's top on the window, hot: the mouse may light things.
function KnoxSettings:drawItem(e, oy, mx, my, hot, now)
    local L, pad = self.L, T.pad
    local ft, fc = T.fontH(T.fontText), T.fontH(T.fontCaps)
    local y = oy + e.y
    local kind = e.kind
    local cap = self.capture
    if kind == "sec" then
        if e.line then T.rect(self, L.x0, y - pad, L.x1 - L.x0, 1, T.color.line) end
        local w = label(self, e.text, L.x0, y, 0, fc, T.color.accent, T.fontCaps)
        -- the skin (beta): a BETA plate after its name
        if e.beta then plateMark(self, L.betaMark, L.x0 + math.floor(w + 0.5) + pad, y + math.floor((fc - T.fontTileH - 4) / 2), T.color.warn) end
        if e.reset then
            local r = self:resetRect(e, oy)
            local same = (e.vp and C.vpIsDefault()) or (not e.vp and C.isDefault())
            button(self, r, L.resetText, hot and inRect(mx, my, r), false, same, T.fontTile)
        end
    elseif kind == "mod" then
        local on = self.want[e.key]
        local rp = math.floor(pad * 0.6)
        local hover = hot and inRect(mx, my, set(R1, L.sideW + 1, y, L.w, e.h))
        if hover then self:drawRect(L.sideW + 3, y, L.x1 + math.floor(pad / 2) - L.sideW - 3, e.h, 0.05, 1, 1, 1) end
        T.rect(self, L.x0, y, L.x1 - L.x0, 1, T.color.line)
        -- the switch: a square, filled with sand while the part is on; the name on its axis
        local by = y + rp
        T.rect(self, L.x0, by, L.box, L.box, T.color.cell)
        T.border(self, L.x0, by, L.box, L.box, (hover or on) and T.color.accent or T.color.tileEdge)
        if on then T.rect(self, L.x0 + 4, by + 4, L.box - 8, L.box - 8, T.color.accent) end
        label(self, e.name, L.textX, by, 0, L.box, on and T.color.bright or T.color.dim, T.fontCaps)
        -- (a switch that is not what runs now: marked until the Lua reloads)
        if on ~= (T.modules[e.key] == true) then
            label(self, L.pendingMark, L.x0, by, L.x1 - L.x0, L.box, T.color.accent, T.fontCaps, "right")
        end
        lines(self, e.lines, L.textX, by + math.max(L.box, fc) + 2, on and T.color.text or T.color.dim)
    elseif kind == "note" or kind == "help" or kind == "cathelp" then
        lines(self, e.lines, L.x0, y, T.color.dim)
    elseif kind == "slider" then
        local spec, sh = e.spec, L.sliderH
        label(self, e.name, L.x0, y, 0, sh, T.color.text, T.fontText)
        local fixed = serverValue(spec)
        local v = fixed or T.look(spec.key)
        local mid = y + math.floor(sh / 2)
        T.rect(self, L.sliderX, mid - 1, L.sliderW, 3, T.color.line)
        local fill = math.floor(L.sliderW * (v - spec.min) / (spec.max - spec.min))
        T.rect(self, L.sliderX, mid - 1, fill, 3, fixed and T.color.tileEdge or T.color.accent)
        if fixed then
            -- (the server's: no knob, a plate saying so in the middle of the track)
            local pw = T.plateW(L.serverMark, T.fontTile)
            serverOpts.fill, serverOpts.edge, serverOpts.color, serverOpts.font = T.color.window, T.color.tileEdge, T.color.dim, T.fontTile
            T.plate(self, set(R1, L.sliderX + math.floor((L.sliderW - pw) / 2), y, pw, sh), L.serverMark, serverOpts)
        else
            local kx = L.sliderX + fill - math.floor(sh / 2)
            local lit = self.sliding == e or (hot and not self.sliding and inRect(mx, my, self:sliderRect(e, oy)))
            T.rect(self, kx, y, sh, sh, T.color.accent)
            if lit then T.border(self, kx - 1, y - 1, sh + 2, sh + 2, T.color.bright) end
        end
        -- (its value's text made again only when the value changes)
        if e.vWas ~= v then e.vWas, e.vText = v, tostring(v) .. spec.unit end
        label(self, e.vText, L.x0, y, L.x1 - L.x0, sh, fixed and T.color.dim or T.color.bright, T.fontText, "right")
    elseif kind == "switch" then
        local on = T.switch(e.key)
        local lit = hot and not self.sliding and inRect(mx, my, set(R1, L.x0, y, L.x1 - L.x0, e.h))
        T.rect(self, L.x0, y, L.box, L.box, T.color.cell)
        T.border(self, L.x0, y, L.box, L.box, (lit or on) and T.color.accent or T.color.tileEdge)
        if on then T.rect(self, L.x0 + 4, y + 4, L.box - 8, L.box - 8, T.color.accent) end
        -- its name on the square's axis; a new one: a small sand plate with "NEW" after it
        local w = label(self, e.name, L.textX, y, 0, L.box, on and T.color.bright or T.color.text, T.fontText)
        if e.new then plateMark(self, L.newMark, L.textX + math.floor(w + 0.5) + pad, y + math.floor((L.box - T.fontTileH - 4) / 2), T.color.accent) end
        lines(self, e.lines, L.textX, y + math.max(L.box, ft) + 2, T.color.dim)
    elseif kind == "choice" then
        -- name, what it does, a row of buttons with the chosen one lit
        T.text(self, e.name, L.x0, y, T.color.bright, T.fontText)
        if e.new then plateMark(self, L.newMark, L.x0 + T.measure(T.fontText, e.name) + pad, y + math.floor((ft - T.fontTileH - 4) / 2), T.color.accent) end
        lines(self, e.lines, L.x0, y + ft + 2, T.color.dim)
        local cur = T.choice(e.spec.key)
        for i, v in ipairs(e.spec.values) do
            local r = self:choiceRect(e, i, oy)
            button(self, r, e.labels[i], hot and not self.sliding and inRect(mx, my, r), cur == v, false, T.fontTile)
        end
    elseif kind == "skins" then
        lines(self, e.lines, L.x0, y, T.color.dim)
        local cur = T.skin()
        for i, sk in ipairs(T.SKINS) do
            local r = self:skinRect(e, i, oy)
            local on = sk.id == cur
            local lit = hot and not self.sliding and inRect(mx, my, r)
            T.rect(self, r[1], r[2], r[3], r[4], T.color.buttonBg)
            if on then T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.accent)
            elseif lit then T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.tileHover)
            else T.border(self, r[1], r[2], r[3], r[4], T.color.tileEdge) end
            -- the swatch: the skin's window with its main colour on it
            local win, acc = skinSwatch(sk)
            local s = r[4] - 12
            T.rect(self, r[1] + 6, r[2] + 6, s, s, win)
            T.rect(self, r[1] + 6 + math.floor(s / 4), r[2] + 6 + math.floor(s / 4), math.ceil(s / 2), math.ceil(s / 2), acc)
            T.border(self, r[1] + 6, r[2] + 6, s, s, T.color.tileEdge)
            label(self, T.fit(e.labels[i], T.fontText, r[3] - s - 24), r[1] + s + 16, r[2], 0, r[4],
                on and T.color.bright or T.color.text, T.fontText)
        end
    elseif kind == "cats" then
        -- the categories' order: a plate of each category's tile color, its name, up and down
        local order = KnoxOrder.catOrder()
        -- a row being dragged: the others make room for it where it would go
        local drag = self.catDrag
        if drag and not isMouseButtonDown(0) then drag = nil end
        if drag then
            local cat = table.remove(order, drag.i)
            drag.to = self:catRowAt(my, #order + 1)
            table.insert(order, drag.to, cat)
        end
        for i, cat in ipairs(order) do
            local row, up, down = self:catRects(i, oy)
            local held = drag and i == drag.to
            local lit = hot and not drag and inRect(mx, my, row)
            T.rect(self, row[1], row[2], row[3], row[4], T.category[cat])
            if lit then self:drawRect(row[1], row[2], row[3], row[4], 0.06, 1, 1, 1) end
            T.tileFrame(self, row[1], row[2], row[3], row[4], held and T.color.accent or (lit and T.color.tileHover or T.color.tileFrame))
            label(self, catLabel(i, cat), row[1] + pad, row[2], 0, row[4],
                held and T.color.accent or T.color.bright, T.fontText)
            arrowButton(self, up, true, hot and not drag and inRect(mx, my, up), i == 1)
            arrowButton(self, down, false, hot and not drag and inRect(mx, my, down), i == #order)
        end
    elseif kind == "bind" then
        local r = self:plateRect(e, oy)
        -- the name about the plate's middle (on two lines: the two about it)
        if #e.lines == 1 then
            label(self, e.lines[1], L.x0, r[2], 0, r[4], T.color.text, T.fontText)
        else
            lines(self, e.lines, L.x0, r[2] + math.floor((r[4] - (#e.lines * (ft + 2) - 2)) / 2), T.color.text)
        end
        local catching = cap and cap.id == e.key
        local hover = not cap and hot and inRect(mx, my, r)
        T.rect(self, r[1], r[2], r[3], r[4], catching and T.color.accent or T.color.cell, catching and 0.18 or 1)
        T.border(self, r[1], r[2], r[3], r[4], (catching or hover) and T.color.accent or T.color.tileEdge)
        -- (Viewpoint's keys: as Viewpoint writes and shows them)
        local vp = C.vp(e.key)
        local gesture = vp and C.vpGet(e.key) or C.get(e.key)
        if e.gWas ~= gesture then e.gWas, e.gText = gesture, T.upper(vp and C.vpLabel(gesture) or C.label(gesture)) end
        local text, color = e.gText, gesture == "" and T.color.dim or T.color.bright
        if catching then
            local key = cap.kind ~= "mouse" and "IGUI_Knox_Controls_PressKey" or "IGUI_Knox_Controls_Click"
            if cap.mouse then key = "IGUI_Knox_Controls_PressKeyOrMouse" end
            if cap.plain and now - cap.plain < 2500 then key = "IGUI_Knox_Controls_NotPlain" end
            text, color = T.upper(getText(key)), T.color.accent
        end
        label(self, text, r[1], r[2], r[3], r[4], color, T.fontCaps, "centre")
    elseif kind == "camp" then
        -- the camp: put back as it was (the keepsakes taken away: KnoxMenuKeep)
        lines(self, e.lines, L.x0, y, T.color.text)
        local r = self:campRect(e, oy)
        local sure = self.campSureAt and now - self.campSureAt < 4000
        local none = not KnoxMenuKeep or #KnoxMenuKeep.load() == 0
        button(self, r, sure and L.campSure or L.campText, hot and inRect(mx, my, r), sure, none, T.fontTile)
    end
end

function KnoxSettings:prerender()
    local L, pad = self.L, T.pad
    local w, h = self:getWidth(), self:getHeight()
    local mx, my = self:getMouseX(), self:getMouseY()
    local now = getTimestampMs()
    local dt = math.min(100, now - (self.frameMs or now))
    self.frameMs = now

    -- a single click being caught: once no second click can follow, it is the gesture
    -- (a plain click is not one: it picks a tile up)
    local cap = self.capture
    -- (the middle button has no event of its own: its press is looked for)
    local mmb = isMouseButtonDown(2)
    if cap and (cap.kind == "mouse" or cap.mouse) and mmb and not self.mmbWas then
        self:assign(C.mods() .. "mmb")
        cap = self.capture
    end
    self.mmbWas = mmb
    if cap and cap.first and now - cap.first.t >= DOUBLE_MS then
        if cap.first.mods ~= "" then
            self:assign(cap.first.mods .. "lmb")
        else
            cap.first = nil
            cap.plain = now
        end
        cap = self.capture
    end

    -- a slider being moved: seen at once on the screen behind
    if self.sliding then
        if isMouseButtonDown(0) then
            local key = self.sliding.spec.key
            local was = T.settings[key]
            T.settings[key] = tostring(self:sliderValue(self.sliding, mx))
            -- the grids behind follow the size of bags and pockets at once
            if key == "grid.scale" and was ~= T.settings[key] and KnoxScreen and KnoxScreen.instance then
                KnoxScreen.instance:markAllDirty()
            end
            -- (the custom skin's colour: moving it picks that skin, and it shows at once)
            if string.sub(key, 1, 5) == "skin." then
                T.settings["skin"] = "custom"
                T.applySkin()
            end
        else
            self.sliding = nil
            T.saveSettings()
        end
    end

    -- the scroll: the thumb dragged, or gliding to where the wheel sent it
    local maxS = self:maxScroll()
    if self.thumbDrag then
        local bx, _, track, box = self:bar()
        if isMouseButtonDown(0) and bx then
            local room = math.max(1, track - box)
            self.target = math.max(0, math.min(maxS, self.thumbDrag.s + (my - self.thumbDrag.y) / room * maxS))
            self.scroll = self.target
        else
            self.thumbDrag = nil
        end
    end
    self.target = math.max(0, math.min(maxS, self.target))
    self.scroll = self.scroll + (self.target - self.scroll) * T.anim(math.min(1, dt / SCROLL_MS))
    if math.abs(self.target - self.scroll) < 0.5 then self.scroll = self.target end

    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, L.headerH, T.color.header)
    T.rect(self, 0, L.headerH, w, 1, T.color.border)

    local cx, cy, cw = self:closeRect()
    label(self, L.title, pad * 2, 0, w, L.headerH, T.color.bright, T.fontCaps)
    T.closeButton(self, cx, cy, cw, inRect(mx, my, set(R1, cx, cy, cw, cw)))

    -- the pages: a column on the left, the chosen one lit with a sand bar
    T.rect(self, L.sideW, L.viewY, 1, h - L.viewY - L.footZone, T.color.border)
    for i, p in ipairs(KnoxSettings.PAGES) do
        local r = self:sideRect(i)
        local on = p == self.page
        local lit = not cap and not on and inRect(mx, my, r)
        if on then
            T.rect(self, r[1] + 2, r[2], r[3] - 2, r[4], T.color.header)
            T.rect(self, r[1] + 2, r[2], 3, r[4], T.color.accent)
        end
        label(self, L.pageNames[p], pad * 2, r[2], r[3] - pad * 3, r[4], on and T.color.bright or (lit and T.color.text or T.color.dim), T.fontCaps)
    end

    -- the page: in its view, moved by the scroll
    local oy = self:pageTop()
    local hot = not cap and self:inView(mx, my)
    self:setStencilRect(L.sideW + 1, L.viewY, w - L.sideW - 1, L.viewH)
    local items = L.pages[self.page].items
    for i, e in ipairs(items) do
        -- (only what is in the view: from its top to the next one's)
        local nextY = items[i + 1] and items[i + 1].y or L.pages[self.page].h
        if oy + nextY >= L.viewY - pad and oy + e.y < L.viewY + L.viewH + pad then
            self:drawItem(e, oy, mx, my, hot, now)
        end
    end
    -- the fades at the edges while there is more above / below (as T.edgeFades)
    local ys = math.floor(self.scroll + 0.5)
    local step = T.anim(math.min(1, dt / FADE_MS))
    self.fadeBottom = self.fadeBottom + (((L.pages[self.page].h - ys - L.viewH) > 1 and 1 or 0) - self.fadeBottom) * step
    self.fadeTop = self.fadeTop + ((ys > 1 and 1 or 0) - self.fadeTop) * step
    if self.fadeBottom > 0.01 or self.fadeTop > 0.01 then
        local fb = math.floor(T.cell * 1.3)
        local c = T.color.window
        for i = 0, fb - 1, 2 do
            local f = 1 - i / fb
            local a = f * f * 0.95
            if self.fadeBottom > 0.01 then self:drawRect(L.sideW + 1, L.viewY + L.viewH - i - 2, w - L.sideW - 1, 2, a * self.fadeBottom, c.r, c.g, c.b) end
            if self.fadeTop > 0.01 then self:drawRect(L.sideW + 1, L.viewY + i, w - L.sideW - 1, 2, a * self.fadeTop, c.r, c.g, c.b) end
        end
    end
    self:clearStencilRect()

    -- the scroll bar: a thin track, a sand thumb (as KnoxMenuSkin's)
    local bx, btop, btrack, bbox, by = self:bar()
    if bx then
        local lit = self.thumbDrag ~= nil or (not cap and inRect(mx, my, set(R1, bx - 5, by, 10, bbox)))
        T.rect(self, bx - 1, btop, 2, btrack, T.color.border)
        T.rect(self, bx - 2, by, 4, bbox, lit and T.color.bright or T.color.accent)
    end

    -- the foot: Close; Apply only where it means something (the modules' page, a module changed)
    T.rect(self, 0, h - L.footZone, w, 1, T.color.border)
    local RC = self:closeButtonRect()
    button(self, RC, L.closeText, not cap and inRect(mx, my, RC), false, false, nil)
    if self:hasApply() then
        local can = self:changed() or pending()
        button(self, L.applyR, L.applyText, not cap and inRect(mx, my, L.applyR), can, not can, nil)
    end
    T.tileFrame(self, 0, 0, w, h, T.color.accent)
end

-- Mouse ---------------------------------------------------------------------------------

--- The wheel over the page: three lines of text a notch, gliding there (as Knox's lists).
function KnoxSettings:onMouseWheel(del)
    if not self:inView(self:getMouseX(), self:getMouseY()) then return true end
    local ft = T.fontH(T.fontText)
    self.target = math.max(0, math.min(self:maxScroll(), self.target + del * (ft + 2) * 3))
    return true
end

--- A click on the page's item e (oy: the page's top): true when it took it.
function KnoxSettings:clickItem(e, x, y, oy)
    local L = self.L
    local kind = e.kind
    local ey = oy + e.y
    if kind == "sec" and e.reset and inRect(x, y, self:resetRect(e, oy)) then
        self.pressed = e.vp and "vpreset" or "reset"
        return true
    elseif kind == "mod" and inRect(x, y, set(R1, L.sideW + 1, ey, L.w, e.h)) then
        self.want[e.key] = not self.want[e.key]
        return true
    elseif kind == "switch" and inRect(x, y, set(R1, L.x0, ey, L.x1 - L.x0, e.h)) then
        T.settings[e.key] = T.switch(e.key) and "0" or "1"
        T.saveSettings()
        getSoundManager():playUISound("UIActivateButton")
        return true
    elseif kind == "slider" and inRect(x, y, self:sliderRect(e, oy)) and not serverValue(e.spec) then
        self.sliding = e
        T.settings[e.spec.key] = tostring(self:sliderValue(e, x))
        if string.sub(e.spec.key, 1, 5) == "skin." then
            T.settings["skin"] = "custom"
            T.applySkin()
        end
        return true
    elseif kind == "choice" then
        for i, v in ipairs(e.spec.values) do
            if inRect(x, y, self:choiceRect(e, i, oy)) then
                T.settings[e.spec.key] = v
                T.saveSettings()
                if KnoxLootPanel then KnoxLootPanel.dirty = true end   -- (the Surroundings list follows at once)
                getSoundManager():playUISound("UIActivateButton")
                return true
            end
        end
    elseif kind == "skins" then
        for i, sk in ipairs(T.SKINS) do
            if inRect(x, y, self:skinRect(e, i, oy)) then
                T.settings["skin"] = sk.id
                T.saveSettings()
                T.applySkin()
                getSoundManager():playUISound("UIActivateButton")
                return true
            end
        end
    elseif kind == "cats" then
        local order = KnoxOrder.catOrder()
        for i = 1, #order do
            local row, up, down = self:catRects(i, oy)
            local j = (inRect(x, y, up) and i > 1 and i - 1) or (inRect(x, y, down) and i < #order and i + 1) or nil
            if j then
                order[i], order[j] = order[j], order[i]
                KnoxOrder.setCatOrder(order)
                getSoundManager():playUISound("UIActivateButton")
                return true
            end
            -- the plate itself: taken by the mouse (let go: it stays where it is shown)
            if inRect(x, y, row) then
                self.catDrag = {i = i, to = i}
                return true
            end
        end
    elseif kind == "bind" and inRect(x, y, self:plateRect(e, oy)) then
        self.pressed = "bind:" .. e.key
        return true
    elseif kind == "camp" and inRect(x, y, self:campRect(e, oy)) then
        self.pressed = "camp"
        return true
    end
    return false
end

function KnoxSettings:onMouseDown(x, y)
    local cap = self.capture
    if cap then
        -- a gesture is being caught: every click in the window is a part of it
        if cap.kind == "mouse" then
            local now = getTimestampMs()
            if cap.first and now - cap.first.t < DOUBLE_MS then
                self:assign(cap.first.mods .. "lmb2")
            else
                cap.first = {t = now, mods = C.mods()}
            end
        end
        return true
    end
    local L = self.L
    local cx, cy, cw = self:closeRect()
    if inRect(x, y, set(R1, cx, cy, cw, cw)) then self.pressed = "close" return true end
    if inRect(x, y, self:closeButtonRect()) then self.pressed = "close" return true end
    if self:hasApply() and inRect(x, y, L.applyR) then self.pressed = "apply" return true end
    for i, p in ipairs(KnoxSettings.PAGES) do
        if inRect(x, y, self:sideRect(i)) then
            if self.page ~= p then
                self.page = p
                self.scroll, self.target, self.fadeTop, self.fadeBottom = 0, 0, 0, 0
            end
            KnoxSettings.lastPage = p
            return true
        end
    end
    -- the scroll bar: the thumb taken, or a page up / down by a click on its track
    local bx, btop, btrack, bbox, by = self:bar()
    if bx and inRect(x, y, set(R1, bx - 6, btop, 12, btrack)) then
        if y >= by and y < by + bbox then
            self.thumbDrag = {y = y, s = self.scroll}
        else
            self.target = math.max(0, math.min(self:maxScroll(), self.target + (y < by and -L.viewH or L.viewH) * 0.9))
        end
        return true
    end
    if self:inView(x, y) then
        local oy = self:pageTop()
        for _, e in ipairs(L.pages[self.page].items) do
            if self:clickItem(e, x, y, oy) then return true end
        end
        return true
    end
    KnoxWindowDrag.begin(self, x, y, L.headerH)
    return true
end

function KnoxSettings:onRightMouseUp(x, y)
    local cap = self.capture
    if cap and (cap.kind == "mouse" or cap.mouse) then self:assign(C.mods() .. "rmb") end
    return true
end

-- (buttons work on release: the camp under the main menu looks at the mouse
-- itself and would take a press that outlives this window for a click of its own)
KnoxWindowDrag.install(KnoxSettings)

function KnoxSettings:onMouseUp(x, y)
    KnoxWindowDrag.stop(self)
    self.thumbDrag = nil
    local drag = self.catDrag
    if drag then
        -- a category let go: put where it was shown
        self.catDrag = nil
        local order = KnoxOrder.catOrder()
        local to = self:catRowAt(y, #order)
        if to ~= drag.i then
            local cat = table.remove(order, drag.i)
            table.insert(order, to, cat)
            KnoxOrder.setCatOrder(order)
            getSoundManager():playUISound("UIActivateButton")
        end
        return true
    end
    local pressed = self.pressed
    self.pressed = nil
    if not pressed then return true end
    if pressed == "close" then
        self:close()
    elseif pressed == "apply" and (self:changed() or pending()) then
        self:apply()
    elseif pressed == "reset" then
        C.reset()
        T.saveSettings()
    elseif pressed == "vpreset" then
        C.vpReset()
    elseif pressed == "camp" and KnoxMenuKeep and #KnoxMenuKeep.load() > 0 then
        if self.campSureAt and getTimestampMs() - self.campSureAt < 4000 then
            self.campSureAt = nil
            KnoxMenuKeep.reset()
        else
            self.campSureAt = getTimestampMs()
        end
        getSoundManager():playUISound("UIActivateButton")
    elseif string.sub(pressed, 1, 5) == "bind:" then
        -- the plate is armed on release, so this click is not taken for the gesture
        local id = string.sub(pressed, 6)
        local a = C.action(id) or C.vp(id)
        self.capture = {id = id, kind = a.kind, mouse = a.mouse}
    end
    return true
end

function KnoxSettings:onMouseUpOutside(x, y)
    KnoxWindowDrag.stop(self)
    self.pressed = nil
    self.catDrag = nil
    self.thumbDrag = nil
    return true
end

function KnoxSettings:apply()
    for _, name in ipairs(T.MODULES) do T.setModule(name, self.want[name]) end
    T.saveSettings()
    self:close()
    -- in the main menu the game can reload its Lua right away (as it does for
    -- its own options); in a game the switch waits for the exit to the menu
    if not getPlayer() and pending() then
        getCore():DelayResetLua("default", "knoxModules")
    end
end

function KnoxSettings:close()
    self.capture = nil
    self:setVisible(false)
    self:removeFromUIManager()
    if KnoxSettings.instance == self then KnoxSettings.instance = nil end
end

function KnoxSettings.open()
    if KnoxSettings.instance then KnoxSettings.instance:close() return end
    T.ensure()
    local d = KnoxSettings:new()
    d:initialise()
    d:instantiate()
    d:setWantKeyEvents(true)   -- a key being bound, Esc
    d:setX(math.floor((getCore():getScreenWidth() - d:getWidth()) / 2))
    d:setY(math.floor((getCore():getScreenHeight() - d:getHeight()) / 2))
    d:addToUIManager()
    d:setAlwaysOnTop(true)   -- the main screen comes to the top on a click
    KnoxSettings.instance = d
end
-- The tab at the top of the main menu, in the middle: "KNOX INVENTORY · MODULES".
-- It opens the window, and it is there whichever parts of the mod are on (so a
-- switched off part can be switched back on). Drawn by itself, in Knox's look
-- even over the game's own menu, in a sand frame all round; quiet until the mouse is on it.
KnoxSettingsTab = ISPanel:derive("KnoxSettingsTab")

function KnoxSettingsTab:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    return o
end

local function devShown()
    return KnoxTestBench ~= nil and KnoxTestBench.devOn() == true
end
-- (what the plate is laid out for: placed again when it changes)
local function placeKey()
    return tostring(T.cell) .. "/" .. tostring(T.javaFonts) .. "/" .. getCore():getScreenWidth() .. "/" .. tostring(devShown())
end

function KnoxSettingsTab:place()
    T.ensure()
    local pad = T.pad
    local font = T.fontCaps
    local gap = math.floor(T.measure(font, "  "))
    self.knox, self.inv = "KNOX", "INVENTORY"
    self.label = T.upper(getText("IGUI_Knox_Modules_Button"))
    self.wKnox, self.wInv, self.wLabel = T.measure(font, self.knox), T.measure(font, self.inv), T.measure(font, self.label)
    self.gap = gap
    -- the item editor's part after the settings' (2026-10-25, the author: "the editor's
    -- button in the game's main menu too, to set all up before going into the game")
    self.edLabel = KnoxEditor and T.upper(getText("IGUI_KnoxEd_Title")) or nil
    self.wEd = self.edLabel and T.measure(font, self.edLabel) or 0
    self.line1 = pad * 3 + self.wKnox + gap + self.wInv + pad * 2
    self.line2 = self.edLabel and (self.line1 + 1 + pad * 2 + self.wLabel + pad * 2) or nil
    local w = self.line1 + 1 + pad * 2 + self.wLabel + pad * 3
    if self.line2 then w = self.line2 + 1 + pad * 2 + self.wEd + pad * 3 end
    -- the test bench's part last, only in DEV mode (the author 2026-10-28: "the bench
    -- in the game's main menu too"; players never get it, as the DEV button in the game)
    self.devLabel = devShown() and "DEV" or nil
    self.wDev = self.devLabel and T.measure(font, self.devLabel) or 0
    self.line3 = self.devLabel and (w - pad) or nil
    if self.line3 then w = self.line3 + 1 + pad * 2 + self.wDev + pad * 3 end
    local h = T.fontH(font) + pad * 2
    self:setWidth(w)
    self:setHeight(h)
    self:setX(math.floor((getCore():getScreenWidth() - w) / 2))
    self:setY(pad)   -- a little off the screen's edge: the frame is whole
    self.placedFor = placeKey()
end

function KnoxSettingsTab:prerender()
    if self.placedFor ~= placeKey() then self:place() end
    local w, h, pad = self:getWidth(), self:getHeight(), T.pad
    local over = self:isMouseOver()
    local edOpen = KnoxEditor ~= nil and KnoxEditor.instance ~= nil
    local hover = over or (KnoxSettings.instance ~= nil) or edOpen
    local a = hover and 1 or 0.55
    T.rect(self, 0, 0, w, h, T.color.header, hover and 0.96 or 0.7)
    -- the part under the mouse: a faint sand band over it (only with the editor's part there)
    local mxs = self:getMouseX()
    local onDev = over and self.line3 ~= nil and mxs >= self.line3
    local onEd = over and not onDev and self.line2 ~= nil and mxs >= self.line2
    if over and self.line2 then
        if onDev then T.rect(self, self.line3 + 1, 1, w - self.line3 - 2, h - 2, T.color.accent, 0.14)
        elseif onEd then T.rect(self, self.line2 + 1, 1, (self.line3 or w - 1) - self.line2 - 1, h - 2, T.color.accent, 0.14)
        else T.rect(self, self.line1 + 1, 1, self.line2 - self.line1 - 1, h - 2, T.color.accent, 0.14) end
    end
    -- a sand frame all round, as every Knox plate in the menu has
    T.tileFrame(self, 0, 0, w, h, T.color.accent, a)
    local font = T.fontCaps
    local y = math.floor((h - T.fontH(font)) / 2)
    local x = pad * 3
    T.text(self, self.knox, x, y, T.color.bright, font, a)
    x = x + self.wKnox + self.gap
    T.text(self, self.inv, x, y, T.color.accent, font, a)
    x = self.line1
    T.rect(self, x, y, 1, T.fontH(font), T.color.tileEdge, a)
    x = x + 1 + pad * 2
    local onSet = (over and not onEd and not onDev) or KnoxSettings.instance ~= nil
    if not self.line2 then onSet = hover end
    T.text(self, self.label, x, y, onSet and T.color.bright or T.color.text, font, a)
    if self.line2 then
        x = self.line2
        T.rect(self, x, y, 1, T.fontH(font), T.color.tileEdge, a)
        T.text(self, self.edLabel, x + 1 + pad * 2, y, (onEd or edOpen) and T.color.bright or T.color.text, font, a)
    end
    if self.line3 then
        x = self.line3
        T.rect(self, x, y, 1, T.fontH(font), T.color.tileEdge, a)
        T.text(self, self.devLabel, x + 1 + pad * 2, y, (onDev or KnoxTestBench.instance ~= nil) and T.color.bright or T.color.text, font, a)
    end
end

function KnoxSettingsTab:onMouseDown(x, y)
    self.pressed = true
    return true
end

-- (on release, as the window's own buttons: see KnoxSettings.onMouseUp)
function KnoxSettingsTab:onMouseUp(x, y)
    if self.pressed then
        if self.line3 and x >= self.line3 then KnoxTestBench.toggle(0)
        elseif self.line2 and x >= self.line2 then KnoxEditor.open() else KnoxSettings.open() end
    end
    self.pressed = nil
    return true
end

function KnoxSettingsTab:onMouseUpOutside(x, y)
    self.pressed = nil
end

local nextLook = 0
local function look()
    if not T.active then return end
    local now = getTimestampMs()
    if now < nextLook then return end
    nextLook = now + 300
    local main = MainScreen.instance
    if not main or main.inGame or not main.javaObject then return end
    local tab = main.knoxSettingsTab
    if not tab then
        tab = KnoxSettingsTab:new()
        tab:initialise()
        tab:instantiate()
        tab:place()
        main:addChild(tab)
        main.knoxSettingsTab = tab
    end
    -- with the menu's items: gone while one of the menu's screens is open
    local panel = main.bottomPanel
    tab:setVisible(panel == nil or panel:getIsVisible())
end

Events.OnPreUIDraw.Add(look)