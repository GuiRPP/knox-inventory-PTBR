-- The mod's settings window.
--   Modules   the parts of the mod a player can switch off, each leaving the
--             game's own screens in its place (see KnoxTheme.MODULES). A switch
--             works from the next load of the Lua: in the main menu the game
--             reloads it at once, in a game it waits for the exit to the menu.
--   Controls  which mouse gesture or key does what in the inventory (see
--             KnoxControls). A plate is clicked, then the gesture is made; it
--             works at once.
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

local DOUBLE_MS = 400   -- two clicks this close are a double click

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
    L.w = math.floor(c * 13)
    L.headerH = T.sectionH + 8
    L.box = math.floor(c * 0.5)
    L.textX = pad * 2 + L.box + pad
    L.textW = L.w - L.textX - pad * 2
    -- three pages under a row of tabs; the window is as tall as the tallest of them
    L.tabH = T.sectionH + 12
    local top = L.headerH + L.tabH + pad * 2
    local y = top
    -- modules
    L.modTitleY = y
    y = y + fc + pad
    -- in two groups: the parts in a game, the parts outside it (each a small caption)
    L.rows, L.groups = {}, {}
    for gi, g in ipairs(T.MODULE_GROUPS) do
        if gi > 1 then y = y + pad end
        table.insert(L.groups, {id = g.id, y = y})
        y = y + ft + 4
        for _, name in ipairs(g.list) do
            local lines = T.wrap(getText("IGUI_Knox_Module_" .. name .. "_Info"), T.fontText, L.textW)
            local h = math.floor(pad * 0.6) + fc + 2 + #lines * (ft + 2) + math.floor(pad * 0.6)
            table.insert(L.rows, {name = name, y = y, h = h, lines = lines})
            y = y + h
        end
    end
    L.noteY = y + math.floor(pad / 2)
    L.note = T.wrap(getText(getPlayer() and "IGUI_Knox_Modules_NoteGame" or "IGUI_Knox_Modules_NoteMenu"), T.fontText, L.w - pad * 4)
    local bottom = L.noteY + #L.note * (ft + 2)
    -- the camp: put back as it was (the keepsakes taken away: KnoxMenuKeep)
    L.campY = bottom + pad * 2
    L.campInfo = T.wrap(getText("IGUI_Knox_Camp_Reset_Info"), T.fontText, L.w - pad * 4)
    L.campBtnY = L.campY + fc + 4 + #L.campInfo * (ft + 2) + 6
    bottom = L.campBtnY + math.floor(c * 0.7)
    -- look: how solid the inventory's parts are (sliders, then its switches);
    -- game: how the inventory plays (its switches first, then their sliders).
    -- Both are made of T.LOOK's sliders and T.SWITCHES, each on the page it names.
    L.lookTitleY = top
    L.sliderH = math.floor(c * 0.5)
    L.sliderX = pad * 2 + math.floor(c * 5.2)
    L.sliderW = L.w - pad * 2 - L.sliderX - math.floor(c * 1.3)
    L.sliders, L.switches, L.choices = {}, {}, {}
    L.choiceH = math.floor(c * 0.6)
    for _, page in ipairs({"look", "game", "order"}) do
        y = top + fc + pad
        local function sliders()
            for _, s in ipairs(T.LOOK) do
                if (s.page or "look") == page then
                    table.insert(L.sliders, {spec = s, y = y, page = page})
                    y = y + L.sliderH + pad
                end
            end
        end
        local function switches()
            for _, s in ipairs(T.SWITCHES) do
                if (s.page or "look") == page then
                    local lines = T.wrap(getText("IGUI_Knox_Switch_" .. s.key .. "_Info"), T.fontText, L.textW)
                    table.insert(L.switches, {key = s.key, y = y, lines = lines, new = s.new, page = page})
                    y = y + math.max(L.box, ft + 2 + #lines * (ft + 2)) + pad
                end
            end
        end
        -- a choice: its name, what it does, then a row of buttons, one per value (T.CHOICES)
        local function choices()
            for _, ch in ipairs(T.CHOICES) do
                if (ch.page or "look") == page then
                    local nm = string.gsub(ch.key, "%.", "_")
                    local lines = T.wrap(getText("IGUI_Knox_Choice_" .. nm .. "_Info"), T.fontText, L.w - pad * 4)
                    local by = y + ft + 2 + #lines * (ft + 2) + 4
                    table.insert(L.choices, {spec = ch, name = nm, y = y, lines = lines, by = by, page = page})
                    y = by + L.choiceH + pad
                end
            end
        end
        if page == "game" then
            switches()
            choices()
            sliders()
        elseif page == "order" then
            -- Sort's rule, where new things go, then the categories' order (KnoxOrder)
            choices()
            L.catTitleY = y
            L.catHelp = T.wrap(getText("IGUI_Knox_Order_Cats_Info"), T.fontText, L.w - pad * 4)
            y = y + ft + 2 + #L.catHelp * (ft + 2) + 4
            L.catRowH = math.floor(c * 0.55)
            L.catY = y
            y = y + #KnoxOrder.CATS * (L.catRowH + 2) + pad
        else
            -- the skin (beta): its name with a BETA plate, a line on it, a button
            -- per skin (four a row), the custom skin's three sliders
            L.skinTitleY = y
            L.skinInfo = T.wrap(getText("IGUI_Knox_Skin_Info"), T.fontText, L.w - pad * 4)
            y = y + ft + 4 + #L.skinInfo * (ft + 2) + 6
            L.skinBtnH = math.floor(c * 0.6)
            L.skinY = y
            y = y + math.ceil(#T.SKINS / 4) * (L.skinBtnH + 6) + math.floor(pad / 2)
            for _, s in ipairs(T.LOOK) do
                if s.page == "skin" then
                    table.insert(L.sliders, {spec = s, y = y, page = page})
                    y = y + L.sliderH + pad
                end
            end
            L.skinEndY = y
            y = y + pad
            sliders()
            y = y + math.floor(pad / 2)
            switches()
        end
        bottom = math.max(bottom, y)
    end
    -- controls
    y = top
    L.ctlTitleY = y
    y = y + fc + pad
    L.bindH = math.floor(c * 0.72)
    L.plateW = math.floor(c * 4.6)
    L.binds = {}
    for _, a in ipairs(C.ACTIONS) do
        table.insert(L.binds, {id = a.id, kind = a.kind, y = y})
        y = y + L.bindH + 4
    end
    L.helpY = y + math.floor(pad / 2)
    L.help = T.wrap(getText("IGUI_Knox_Controls_Help"), T.fontText, L.w - pad * 4)
    bottom = math.max(bottom, L.helpY + #L.help * (ft + 2))
    L.footY = bottom + pad * 2
    L.footH = math.floor(c * 0.7)
    L.h = L.footY + L.footH + pad * 2
    return L
end

function KnoxSettings:createChildren()
    self.L = self:layout()
    self:setWidth(self.L.w)
    self:setHeight(self.L.h)
end

function KnoxSettings:rects()
    local L, pad = self.L, T.pad
    local apply, close, reset = getText("IGUI_Knox_Apply"), getText("IGUI_Knox_Close"), getText("IGUI_Knox_Controls_Reset")
    local bw = math.floor(T.cell * 2.6)
    local aw = math.max(T.buttonW(apply) + pad * 2, bw)
    local cw = math.max(T.buttonW(close) + pad * 2, bw)
    local rw = T.buttonW(reset) + pad * 2
    local fc = T.fontH(T.fontCaps)
    -- (asked once more before it is done: the second press does it)
    local sure = self.campSureAt and getTimestampMs() - self.campSureAt < 4000
    local camp = getText(sure and "IGUI_Knox_Camp_Reset_Sure" or "IGUI_Knox_Camp_Reset")
    local kw = math.max(T.buttonW(getText("IGUI_Knox_Camp_Reset")), T.buttonW(getText("IGUI_Knox_Camp_Reset_Sure"))) + pad * 2
    return {
        apply = {L.w - pad * 2 - aw, L.footY, aw, L.footH, apply},
        close = {L.w - pad * 3 - aw - cw, L.footY, cw, L.footH, close},
        reset = {L.w - pad * 2 - rw, L.ctlTitleY - 4, rw, fc + 8, reset},
        camp = {pad * 2, L.campBtnY, kw, L.footH, camp, sure},
    }
end

KnoxSettings.PAGES = {"modules", "look", "game", "order", "controls"}

--- The skins' buttons, four a row: {x, y, w, h, id}.
function KnoxSettings:skinRects()
    local L, pad = self.L, T.pad
    local gap, n = 6, 4
    local bw = math.floor((L.w - pad * 4 - gap * (n - 1)) / n)
    local out = {}
    for i, sk in ipairs(T.SKINS) do
        local col, row = (i - 1) % n, math.floor((i - 1) / n)
        table.insert(out, {pad * 2 + col * (bw + gap), L.skinY + row * (L.skinBtnH + gap), bw, L.skinBtnH, sk.id})
    end
    return out
end

--- The colours a skin's button shows: its window and its main colour.
local function skinSwatch(sk)
    if sk.id == "custom" then return T.color.window, T.customAccent() end
    local function hx(s, base)
        if not s then return base end
        return {r = tonumber(s:sub(2, 3), 16) / 255, g = tonumber(s:sub(4, 5), 16) / 255, b = tonumber(s:sub(6, 7), 16) / 255}
    end
    return hx(sk.window, {r = 0.07, g = 0.078, b = 0.078}), hx(sk.accent, {r = 0.831, g = 0.765, b = 0.541})
end

--- A row of the categories' order: its plate, and its two arrow buttons on the
--- left (up, down). The plate is taken by the mouse and dragged to its place.
function KnoxSettings:catRects(i)
    local L, pad = self.L, T.pad
    local y = L.catY + (i - 1) * (L.catRowH + 2)
    local bw = L.catRowH
    local px = pad * 2 + bw * 2 + 8
    return {px, y, L.w - pad * 2 - px, L.catRowH},
        {pad * 2, y, bw, L.catRowH},
        {pad * 2 + bw + 4, y, bw, L.catRowH}
end

--- The row the mouse is at while a category is dragged (1..n).
function KnoxSettings:catRowAt(my, n)
    local L = self.L
    return math.max(1, math.min(n, math.floor((my - L.catY) / (L.catRowH + 2)) + 1))
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

--- The tabs under the header: {x, y, w, h, page}.
function KnoxSettings:tabRects()
    local L, pad = self.L, T.pad
    local list, x = {}, pad * 2
    for _, page in ipairs(KnoxSettings.PAGES) do
        local w = T.measure(T.fontCaps, T.upper(getText("IGUI_Knox_Page_" .. page))) + pad * 4
        table.insert(list, {x, L.headerH, w, L.tabH, page})
        x = x + w
    end
    return list
end

function KnoxSettings:plateRect(b)
    local L, pad = self.L, T.pad
    return {L.w - pad * 2 - L.plateW, b.y, L.plateW, L.bindH}
end

--- A slider's value under the mouse on its track, in the slider's own steps.
function KnoxSettings:sliderValue(s, mx)
    local L, spec = self.L, s.spec
    local f = math.max(0, math.min(1, (mx - L.sliderX) / math.max(1, L.sliderW)))
    local steps = (spec.max - spec.min) / spec.step
    return spec.min + math.floor(f * steps + 0.5) * spec.step
end

function KnoxSettings:sliderRect(s)
    local L = self.L
    return {L.sliderX - L.sliderH, s.y, L.sliderW + L.sliderH * 2, L.sliderH}
end

--- A switch on the look page: its square and its text.
function KnoxSettings:switchRect(s)
    local L, pad = self.L, T.pad
    local ft = T.fontH(T.fontText)
    return {pad * 2, s.y, L.w - pad * 4, math.max(L.box, ft + 2 + #s.lines * (ft + 2))}
end

--- A choice's buttons, side by side across the window: {x, y, w, h, value}.
function KnoxSettings:choiceRects(ch)
    local L, pad = self.L, T.pad
    local n, gap = #ch.spec.values, 4
    local bw = math.floor((L.w - pad * 4 - gap * (n - 1)) / n)
    local out = {}
    for i, v in ipairs(ch.spec.values) do
        table.insert(out, {pad * 2 + (i - 1) * (bw + gap), ch.by, bw, L.choiceH, v})
    end
    return out
end

function KnoxSettings:closeRect()
    local s = self.L.headerH - 8
    return self:getWidth() - s - 4, 4, s
end

-- Controls: catching a gesture ---------------------------------------------------

function KnoxSettings:assign(gesture)
    local cap = self.capture
    if not cap then return end
    C.set(cap.id, gesture)
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

function KnoxSettings:prerender()
    local L, pad = self.L, T.pad
    local w, h = self:getWidth(), self:getHeight()
    local ft, fc = T.fontH(T.fontText), T.fontH(T.fontCaps)
    local mx, my = self:getMouseX(), self:getMouseY()
    local now = getTimestampMs()

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

    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, L.headerH, T.color.header)
    T.rect(self, 0, L.headerH, w, 1, T.color.border)
    T.tileFrame(self, 0, 0, w, h, T.color.accent)

    local cx, cy, cw = self:closeRect()
    T.caps(self, getText("IGUI_Knox_Settings"), pad * 2, math.floor((L.headerH - fc) / 2), T.color.bright)
    T.closeButton(self, cx, cy, cw, inRect(mx, my, {cx, cy, cw, cw}))

    -- tabs
    T.rect(self, 2, L.headerH + L.tabH, w - 4, 1, T.color.border)
    for _, tr in ipairs(self:tabRects()) do
        local on = tr[5] == self.page
        local hot = not cap and not on and inRect(mx, my, tr)
        T.textCentre(self, T.upper(getText("IGUI_Knox_Page_" .. tr[5])), tr[1] + math.floor(tr[3] / 2),
            tr[2] + math.floor((tr[4] - fc) / 2), on and T.color.bright or (hot and T.color.text or T.color.dim), T.fontCaps)
        if on then T.rect(self, tr[1], tr[2] + tr[4] - 2, tr[3], 3, T.color.accent) end
    end

    local y
    if self.page == "modules" then
    -- modules
    T.caps(self, getText("IGUI_Knox_Modules_Title"), pad * 2, L.modTitleY, T.color.accent)
    for _, g in ipairs(L.groups) do
        T.text(self, T.upper(getText("IGUI_Knox_Modules_Group_" .. g.id)), pad * 2, g.y, T.color.dim, T.fontText)
    end
    local rp = math.floor(pad * 0.6)
    for i, row in ipairs(L.rows) do
        local on = self.want[row.name]
        local hover = not cap and inRect(mx, my, {0, row.y, w, row.h})
        if hover then self:drawRect(2, row.y, w - 4, row.h, 0.05, 1, 1, 1) end
        T.rect(self, pad * 2, row.y, w - pad * 4, 1, T.color.line)
        -- the switch: a square, filled with sand while the part is on
        local bx, by = pad * 2, row.y + rp
        T.rect(self, bx, by, L.box, L.box, T.color.cell)
        T.border(self, bx, by, L.box, L.box, (hover or on) and T.color.accent or T.color.tileEdge)
        if on then T.rect(self, bx + 4, by + 4, L.box - 8, L.box - 8, T.color.accent) end
        T.caps(self, getText("IGUI_Knox_Module_" .. row.name), L.textX, row.y + rp, on and T.color.bright or T.color.dim)
        -- (a switch that is not what runs now: marked until the Lua reloads)
        if on ~= (T.modules[row.name] == true) then
            local mark = T.upper(getText("IGUI_Knox_Modules_Pending"))
            T.textRight(self, mark, w - pad * 2, row.y + rp, T.color.accent, T.fontCaps)
        end
        local y = row.y + rp + fc + 2
        for _, line in ipairs(row.lines) do
            T.text(self, line, L.textX, y, on and T.color.text or T.color.dim, T.fontText)
            y = y + ft + 2
        end
    end
    y = L.noteY
    for _, line in ipairs(L.note) do
        T.text(self, line, pad * 2, y, T.color.dim, T.fontText)
        y = y + ft + 2
    end
    -- the camp
    T.rect(self, pad * 2, L.campY - pad, w - pad * 4, 1, T.color.line)
    T.caps(self, getText("IGUI_Knox_Camp_Title"), pad * 2, L.campY, T.color.accent)
    y = L.campY + fc + 4
    for _, line in ipairs(L.campInfo) do
        T.text(self, line, pad * 2, y, T.color.text, T.fontText)
        y = y + ft + 2
    end
    local CR = self:rects().camp
    local none = not KnoxMenuKeep or #KnoxMenuKeep.load() == 0
    T.button(self, CR, CR[5], {hover = not cap and inRect(mx, my, CR), primary = CR[6], disabled = none, font = T.fontTile})

    end
    if self.page == "look" or self.page == "game" or self.page == "order" then
    -- look: opacities and the grid's lines, set by sliders; seen at once on the screen behind
    -- (and the game and order pages, made of the same parts)
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
    local titles = {game = "IGUI_Knox_Game_Title", order = "IGUI_Knox_Order_Title"}
    T.caps(self, getText(titles[self.page] or "IGUI_Knox_Look_Title"), pad * 2, L.lookTitleY, T.color.accent)
    -- the skin (beta): name, a BETA plate, what it is, a button per skin
    if self.page == "look" and L.skinY then
        local name = getText("IGUI_Knox_Skin")
        T.text(self, name, pad * 2, L.skinTitleY, T.color.bright, T.fontText)
        local mark = T.upper(getText("IGUI_Knox_Beta"))
        local mw = T.measure(T.fontTile, mark) + 10
        local nx = pad * 2 + T.measure(T.fontText, name) + pad
        local nh = T.fontTileH + 4
        local ny = L.skinTitleY + math.floor((ft - nh) / 2)
        T.rect(self, nx, ny, mw, nh, T.color.warn)
        T.textCentre(self, mark, nx + math.floor(mw / 2), ny + 2, T.color.ink, T.fontTile)
        local ly = L.skinTitleY + ft + 4
        for _, line in ipairs(L.skinInfo) do
            T.text(self, line, pad * 2, ly, T.color.dim, T.fontText)
            ly = ly + ft + 2
        end
        local cur = T.skin()
        for i, r in ipairs(self:skinRects()) do
            local sk = T.SKINS[i]
            local on = r[5] == cur
            local hot = not cap and not self.sliding and inRect(mx, my, r)
            T.rect(self, r[1], r[2], r[3], r[4], T.color.buttonBg)
            if on then T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.accent)
            elseif hot then T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.tileHover)
            else T.border(self, r[1], r[2], r[3], r[4], T.color.tileEdge) end
            -- the swatch: the skin's window with its main colour on it
            local win, acc = skinSwatch(sk)
            local s = r[4] - 12
            T.rect(self, r[1] + 6, r[2] + 6, s, s, win)
            T.rect(self, r[1] + 6 + math.floor(s / 4), r[2] + 6 + math.floor(s / 4), math.ceil(s / 2), math.ceil(s / 2), acc)
            T.border(self, r[1] + 6, r[2] + 6, s, s, T.color.tileEdge)
            T.text(self, T.fit(getText("IGUI_Knox_Skin_" .. sk.id), T.fontText, r[3] - s - 24), r[1] + s + 16,
                r[2] + math.floor((r[4] - ft) / 2), on and T.color.bright or T.color.text, T.fontText)
        end
    end
    -- the categories' order: a plate of each category's tile color, its name, up and down
    if self.page == "order" then
        T.text(self, getText("IGUI_Knox_Order_Cats"), pad * 2, L.catTitleY, T.color.bright, T.fontText)
        local hy = L.catTitleY + ft + 2
        for _, line in ipairs(L.catHelp) do
            T.text(self, line, pad * 2, hy, T.color.dim, T.fontText)
            hy = hy + ft + 2
        end
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
            local row, up, down = self:catRects(i)
            local held = drag and i == drag.to
            local hot = not cap and not drag and inRect(mx, my, row)
            T.rect(self, row[1], row[2], row[3], row[4], T.category[cat])
            if hot then self:drawRect(row[1], row[2], row[3], row[4], 0.06, 1, 1, 1) end
            T.tileFrame(self, row[1], row[2], row[3], row[4], held and T.color.accent or (hot and T.color.tileHover or T.color.tileFrame))
            T.text(self, i .. ".  " .. getText("IGUI_Knox_Cat_" .. cat), row[1] + pad,
                row[2] + math.floor((row[4] - ft) / 2), held and T.color.accent or T.color.bright, T.fontText)
            arrowButton(self, up, true, not cap and not drag and inRect(mx, my, up), i == 1)
            arrowButton(self, down, false, not cap and not drag and inRect(mx, my, down), i == #order)
        end
    end
    local sh = L.sliderH
    for _, s in ipairs(L.sliders) do
        if s.page == self.page then
        local spec, sy = s.spec, s.y
        local name = string.gsub(spec.key, "%.", "_")
        T.text(self, getText("IGUI_Knox_" .. name), pad * 2, sy + math.floor((sh - ft) / 2), T.color.text, T.fontText)
        local fixed = serverValue(spec)
        local v = fixed or T.look(spec.key)
        local mid = sy + math.floor(sh / 2)
        T.rect(self, L.sliderX, mid - 1, L.sliderW, 3, T.color.line)
        local fill = math.floor(L.sliderW * (v - spec.min) / (spec.max - spec.min))
        T.rect(self, L.sliderX, mid - 1, fill, 3, fixed and T.color.tileEdge or T.color.accent)
        if fixed then
            -- (the server's: no knob, a plate saying so in the middle of the track)
            local text = T.upper(getText("IGUI_Knox_SetByServer"))
            local pw = T.plateW(text, T.fontTile)
            T.plate(self, {L.sliderX + math.floor((L.sliderW - pw) / 2), sy, pw, sh}, text,
                {fill = T.color.window, edge = T.color.tileEdge, color = T.color.dim, font = T.fontTile})
        else
            local kx = L.sliderX + fill - math.floor(sh / 2)
            local hot = self.sliding == s or (not self.sliding and not cap and inRect(mx, my, self:sliderRect(s)))
            T.rect(self, kx, sy, sh, sh, T.color.accent)
            if hot then T.border(self, kx - 1, sy - 1, sh + 2, sh + 2, T.color.bright) end
        end
        T.textRight(self, tostring(v) .. spec.unit, w - pad * 2, sy + math.floor((sh - ft) / 2), T.color.bright, T.fontText)
        end
    end
    -- the switches: a square like the modules', filled with sand while on; its name and what it does
    for _, s in ipairs(L.switches) do
        if s.page == self.page then
        local ar = self:switchRect(s)
        local aon = T.switch(s.key)
        local ahot = not cap and not self.sliding and inRect(mx, my, ar)
        T.rect(self, ar[1], ar[2], L.box, L.box, T.color.cell)
        T.border(self, ar[1], ar[2], L.box, L.box, (ahot or aon) and T.color.accent or T.color.tileEdge)
        if aon then T.rect(self, ar[1] + 4, ar[2] + 4, L.box - 8, L.box - 8, T.color.accent) end
        local name = getText("IGUI_Knox_Switch_" .. s.key)
        T.text(self, name, L.textX, s.y, aon and T.color.bright or T.color.text, T.fontText)
        -- a new one: a small sand plate with "NEW" after its name
        if s.new then
            local mark = T.upper(getText("IGUI_Knox_New"))
            local mw = T.measure(T.fontTile, mark) + 10
            local nx = L.textX + T.measure(T.fontText, name) + pad
            local nh = T.fontTileH + 4
            local ny = s.y + math.floor((ft - nh) / 2)
            T.rect(self, nx, ny, mw, nh, T.color.accent)
            T.textCentre(self, mark, nx + math.floor(mw / 2), ny + 2, T.color.ink, T.fontTile)
        end
        local ly = s.y + ft + 2
        for _, line in ipairs(s.lines) do
            T.text(self, line, L.textX, ly, T.color.dim, T.fontText)
            ly = ly + ft + 2
        end
        end
    end
    -- the choices: name, what it does, a row of buttons with the chosen one lit
    for _, ch in ipairs(L.choices) do
        if ch.page == self.page then
        local name = getText("IGUI_Knox_Choice_" .. ch.name)
        T.text(self, name, pad * 2, ch.y, T.color.bright, T.fontText)
        if ch.spec.new then
            local mark = T.upper(getText("IGUI_Knox_New"))
            local mw = T.measure(T.fontTile, mark) + 10
            local nx = pad * 2 + T.measure(T.fontText, name) + pad
            local nh = T.fontTileH + 4
            local ny = ch.y + math.floor((ft - nh) / 2)
            T.rect(self, nx, ny, mw, nh, T.color.accent)
            T.textCentre(self, mark, nx + math.floor(mw / 2), ny + 2, T.color.ink, T.fontTile)
        end
        local ly = ch.y + ft + 2
        for _, line in ipairs(ch.lines) do
            T.text(self, line, pad * 2, ly, T.color.dim, T.fontText)
            ly = ly + ft + 2
        end
        local cur = T.choice(ch.spec.key)
        for _, r in ipairs(self:choiceRects(ch)) do
            T.button(self, r, getText("IGUI_Knox_Choice_" .. ch.name .. "_" .. r[5]),
                {hover = not cap and not self.sliding and inRect(mx, my, r), primary = cur == r[5], font = T.fontTile})
        end
        end
    end

    end
    local R = self:rects()
    if self.page == "controls" then
    -- controls
    T.caps(self, getText("IGUI_Knox_Controls_Title"), pad * 2, L.ctlTitleY, T.color.accent)
    T.button(self, R.reset, R.reset[5], {hover = not cap and inRect(mx, my, R.reset), disabled = C.isDefault(), font = T.fontTile})
    for _, b in ipairs(L.binds) do
        local r = self:plateRect(b)
        local catching = cap and cap.id == b.id
        local gesture = C.get(b.id)
        T.text(self, C.name(b.id), pad * 2, b.y + math.floor((L.bindH - ft) / 2), T.color.text, T.fontText)
        local hover = not cap and inRect(mx, my, r)
        T.rect(self, r[1], r[2], r[3], r[4], catching and T.color.accent or T.color.cell, catching and 0.18 or 1)
        T.border(self, r[1], r[2], r[3], r[4], (catching or hover) and T.color.accent or T.color.tileEdge)
        local text, color = C.label(gesture), gesture == "" and T.color.dim or T.color.bright
        if catching then
            local key = b.kind ~= "mouse" and "IGUI_Knox_Controls_PressKey" or "IGUI_Knox_Controls_Click"
            if cap.mouse then key = "IGUI_Knox_Controls_PressKeyOrMouse" end
            if cap.plain and now - cap.plain < 2500 then key = "IGUI_Knox_Controls_NotPlain" end
            text, color = getText(key), T.color.accent
        end
        T.textCentre(self, T.upper(text), r[1] + math.floor(r[3] / 2), r[2] + math.floor((r[4] - fc) / 2), color, T.fontCaps)
    end
    y = L.helpY
    for _, line in ipairs(L.help) do
        T.text(self, line, pad * 2, y, T.color.dim, T.fontText)
        y = y + ft + 2
    end

    end

    T.button(self, R.close, R.close[5], {hover = not cap and inRect(mx, my, R.close)})
    local can = self:changed() or pending()
    T.button(self, R.apply, R.apply[5], {hover = not cap and inRect(mx, my, R.apply), primary = can, disabled = not can})
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
    local cx, cy, cw = self:closeRect()
    if inRect(x, y, {cx, cy, cw, cw}) then self.pressed = "close" return true end
    local R = self:rects()
    if inRect(x, y, R.close) then self.pressed = "close" return true end
    if inRect(x, y, R.apply) then self.pressed = "apply" return true end
    for _, tr in ipairs(self:tabRects()) do
        if inRect(x, y, tr) then
            self.page = tr[5]
            KnoxSettings.lastPage = tr[5]
            return true
        end
    end
    if self.page == "controls" and inRect(x, y, R.reset) then self.pressed = "reset" return true end
    if self.page == "modules" and inRect(x, y, R.camp) then self.pressed = "camp" return true end
    if self.page == "look" and self.L.skinY then
        for _, r in ipairs(self:skinRects()) do
            if inRect(x, y, r) then
                T.settings["skin"] = r[5]
                T.saveSettings()
                T.applySkin()
                getSoundManager():playUISound("UIActivateButton")
                return true
            end
        end
    end
    for _, s in ipairs(self.L.sliders) do
        if self.page == s.page and inRect(x, y, self:sliderRect(s)) and not serverValue(s.spec) then
            self.sliding = s
            T.settings[s.spec.key] = tostring(self:sliderValue(s, x))
            if string.sub(s.spec.key, 1, 5) == "skin." then
                T.settings["skin"] = "custom"
                T.applySkin()
            end
            return true
        end
    end
    for _, s in ipairs(self.L.switches) do
        if self.page == s.page and inRect(x, y, self:switchRect(s)) then
            T.settings[s.key] = T.switch(s.key) and "0" or "1"
            T.saveSettings()
            getSoundManager():playUISound("UIActivateButton")
            return true
        end
    end
    for _, ch in ipairs(self.L.choices) do
        if self.page == ch.page then
            for _, r in ipairs(self:choiceRects(ch)) do
                if inRect(x, y, r) then
                    T.settings[ch.spec.key] = r[5]
                    T.saveSettings()
                    if KnoxLootPanel then KnoxLootPanel.dirty = true end   -- (the Surroundings list follows at once)
                    getSoundManager():playUISound("UIActivateButton")
                    return true
                end
            end
        end
    end
    for _, b in ipairs(self.L.binds) do
        if self.page == "controls" and inRect(x, y, self:plateRect(b)) then self.pressed = "bind:" .. b.id return true end
    end
    if self.page == "order" then
        local order = KnoxOrder.catOrder()
        for i = 1, #order do
            local row, up, down = self:catRects(i)
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
    end
    for _, row in ipairs(self.L.rows) do
        if self.page == "modules" and inRect(x, y, {0, row.y, self:getWidth(), row.h}) then
            self.want[row.name] = not self.want[row.name]
            return true
        end
    end
    KnoxWindowDrag.begin(self, x, y, self.L.headerH)
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
        self.capture = {id = id, kind = C.action(id).kind, mouse = C.action(id).mouse}
    end
    return true
end

function KnoxSettings:onMouseUpOutside(x, y)
    KnoxWindowDrag.stop(self)
    self.pressed = nil
    self.catDrag = nil
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

function KnoxSettingsTab:place()
    T.ensure()
    local pad = T.pad
    local font = T.fontCaps
    local gap = math.floor(T.measure(font, "  "))
    self.knox, self.inv = "KNOX", "INVENTORY"
    self.label = T.upper(getText("IGUI_Knox_Modules_Button"))
    self.wKnox, self.wInv, self.wLabel = T.measure(font, self.knox), T.measure(font, self.inv), T.measure(font, self.label)
    self.gap = gap
    local w = pad * 3 + self.wKnox + gap + self.wInv + pad * 2 + 1 + pad * 2 + self.wLabel + pad * 3
    local h = T.fontH(font) + pad * 2
    self:setWidth(w)
    self:setHeight(h)
    self:setX(math.floor((getCore():getScreenWidth() - w) / 2))
    self:setY(pad)   -- a little off the screen's edge: the frame is whole
    self.placedFor = tostring(T.cell) .. "/" .. tostring(T.javaFonts) .. "/" .. getCore():getScreenWidth()
end

function KnoxSettingsTab:prerender()
    if self.placedFor ~= tostring(T.cell) .. "/" .. tostring(T.javaFonts) .. "/" .. getCore():getScreenWidth() then self:place() end
    local w, h, pad = self:getWidth(), self:getHeight(), T.pad
    local hover = self:isMouseOver() or (KnoxSettings.instance ~= nil)
    local a = hover and 1 or 0.55
    T.rect(self, 0, 0, w, h, T.color.header, hover and 0.96 or 0.7)
    -- a sand frame all round, as every Knox plate in the menu has
    T.tileFrame(self, 0, 0, w, h, T.color.accent, a)
    local font = T.fontCaps
    local y = math.floor((h - T.fontH(font)) / 2)
    local x = pad * 3
    T.text(self, self.knox, x, y, T.color.bright, font, a)
    x = x + self.wKnox + self.gap
    T.text(self, self.inv, x, y, T.color.accent, font, a)
    x = x + self.wInv + pad * 2
    T.rect(self, x, y, 1, T.fontH(font), T.color.tileEdge, a)
    x = x + 1 + pad * 2
    T.text(self, self.label, x, y, hover and T.color.bright or T.color.text, font, a)
end

function KnoxSettingsTab:onMouseDown(x, y)
    self.pressed = true
    return true
end

-- (on release, as the window's own buttons: see KnoxSettings.onMouseUp)
function KnoxSettingsTab:onMouseUp(x, y)
    if self.pressed then KnoxSettings.open() end
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