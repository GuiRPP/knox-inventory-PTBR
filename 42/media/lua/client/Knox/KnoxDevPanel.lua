-- Developer panel (game started with -debug only): a searchable list of
-- the radio things (TVs, radios and what goes into them) and every bag and
-- container item in the game; a click puts one in the character's main
-- inventory. For testing grids, bag windows and moves, the TV and radio windows.

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISInventoryItem"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxSelfTest"
require "Knox/KnoxMeasure"

KnoxDevPanel = ISPanel:derive("KnoxDevPanel")

local T = KnoxTheme
local ROWS_VISIBLE = 12

local function lower(s)
    return string.lower(s or "")
end

-- For testing the TV and radio windows: the sets (TVs and ham radios are
-- placed in the world from the inventory), what goes into them, a remote.
local RADIO_ITEMS = {
    "Base.RadioBlack", "Base.RadioRed", "Base.RadioMakeShift", "Base.CDplayer",
    "Base.HamRadio1", "Base.HamRadio2", "Base.HamRadioMakeShift",
    "Base.WalkieTalkie1", "Base.WalkieTalkie5",
    "Base.TvBlack", "Base.TvWideScreen", "Base.TvAntique",
    "Base.Battery", "Base.Headphones", "Base.Earbuds",
    "Base.Disc_Retail", "Base.VHS_Retail", "Base.VHS_Home", "Base.Remote",
    -- the alarm window (KnoxAlarmWindow): a desk clock, wristwatches, a pocket watch
    "Base.AlarmClock2", "Base.WristWatch_Left_DigitalBlack", "Base.WristWatch_Left_DigitalRed",
    "Base.WristWatch_Left_ClassicBlack", "Base.Pocketwatch",
}

--- The radio things first, then all container item scripts, sorted by name (built once).
local cache
local function allBags()
    if cache then return cache end
    cache = {}
    for _, ft in ipairs(RADIO_ITEMS) do
        local s = getScriptManager():FindItem(ft)
        if s then table.insert(cache, {script = s, name = s:getDisplayName(), fullType = s:getFullName()}) end
    end
    local bags = {}
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local s = scripts:get(i)
        if s:isItemType(ItemType.CONTAINER) and not s:getObsolete() and not s:isHidden() then
            table.insert(bags, {script = s, name = s:getDisplayName(), fullType = s:getFullName()})
        end
    end
    table.sort(bags, function(a, b) return a.name < b.name end)
    for _, b in ipairs(bags) do table.insert(cache, b) end
    return cache
end

function KnoxDevPanel:new(host, playerNum)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.host = host
    o.playerNum = playerNum
    o.background = false
    o.moveWithMouse = false
    o.scroll = 0
    o.filter = nil
    o.list = {}
    return o
end

function KnoxDevPanel:createChildren()
    local ft = T.fontH(T.fontText)
    self.headerH = T.sectionH + 4
    self.rowH = math.max(ft * 2 + 6, math.floor(T.cell * 0.9))
    local w = T.cell * 10
    -- the game's text box draws with a game font
    local boxFont = T.gameFont(T.fontText)
    self.searchY = self.headerH + T.pad
    self.searchH = T.fontH(boxFont) + 8
    self.listY = self.searchY + self.searchH + T.pad
    self:setWidth(w)
    self:setHeight(self.listY + self.rowH * ROWS_VISIBLE + T.pad)

    self.search = ISTextEntryBox:new("", T.pad, self.searchY, w - T.pad * 2, self.searchH)
    self.search.font = boxFont
    self.search:initialise()
    self.search:instantiate()
    self:addChild(self.search)
    self:applyFilter("")
end

function KnoxDevPanel:applyFilter(text)
    self.filter = text
    self.scroll = 0
    local f = lower(text)
    self.list = {}
    for _, b in ipairs(allBags()) do
        if f == "" or string.find(lower(b.name), f, 1, true) or string.find(lower(b.fullType), f, 1, true) then
            table.insert(self.list, b)
        end
    end
end

function KnoxDevPanel:player()
    return getSpecificPlayer(self.playerNum)
end

function KnoxDevPanel:closeRect()
    local s = self.headerH - 8
    return self:getWidth() - s - 4, 4, s, s
end

--- "Self-test" button in the header, left of the item count.
function KnoxDevPanel:testRect()
    local cx, cy, _, ch = self:closeRect()
    local text = getText("IGUI_Knox_DevSelfTest")
    local countW = T.measure(T.fontText, #allBags() .. " / " .. #allBags())
    local w = T.buttonW(text)
    return {cx - 16 - countW - 8 - w, cy, w, ch}, text
end

--- "Measure" button left of it: writes every item's real size down (KnoxMeasure.lua).
function KnoxDevPanel:measureRect()
    local tr = self:testRect()
    local p = KnoxMeasure.progress()
    local text = p and ("Measure " .. p .. "%") or (KnoxMeasure.last and "Measure: done" or "Measure")
    local w = T.buttonW("Measure 100%")
    return {tr[1] - 8 - w, tr[2], w, tr[4]}, text
end

--- "Layout" left of it: the layout kit's overlay (KnoxTheme: each text's band and
--- letters, red off the middle, orange placed by hand), in game and in the menus.
function KnoxDevPanel:layoutRect()
    local mr = self:measureRect()
    local text = T.layoutDebug() and "Layout: on" or "Layout"
    local w = T.buttonW("Layout: on")
    return {mr[1] - 8 - w, mr[2], w, mr[4]}, text
end

function KnoxDevPanel:rowAt(x, y)
    if x < T.pad or x >= self:getWidth() - T.pad or y < self.listY then return nil end
    local i = math.floor((y - self.listY) / self.rowH)
    if i >= ROWS_VISIBLE then return nil end
    return self.list[self.scroll + i + 1]
end

function KnoxDevPanel:prerender()
    local text = self.search:getText() or ""
    if text ~= self.filter then self:applyFilter(text) end

    local w, h = self:getWidth(), self:getHeight()
    local ft = T.fontH(T.fontText)
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.border(self, 0, 0, w, h, T.color.hoverEdge)
    if self.knoxMove then
        local ac = T.color.accent
        self:drawRectBorder(0, 0, w, h, 1, ac.r, ac.g, ac.b)
    end
    T.rect(self, 0, 0, w, self.headerH, T.color.header)
    local ty = math.floor((self.headerH - ft) / 2)
    T.caps(self, getText("IGUI_Knox_DevSpawnBags"), 8, math.floor((self.headerH - T.fontH(T.fontCaps)) / 2), T.color.text)
    local cx, cy, cw, ch = self:closeRect()
    T.textRight(self, #self.list .. " / " .. #allBags(), cx - 8, ty, T.color.dim, T.fontText)

    local over = self:isMouseOver()
    local mx, my = self:getMouseX(), self:getMouseY()
    T.closeButton(self, cx, cy, cw, over and T.inRect(mx, my, {cx, cy, cw, ch}))
    local tr, testText = self:testRect()
    local running = KnoxSelfTest and KnoxSelfTest.isRunning()
    T.button(self, tr, testText, {hover = over and T.inRect(mx, my, tr), disabled = running, primary = not running})
    local mr, measureText = self:measureRect()
    local measuring = KnoxMeasure.isRunning()
    T.button(self, mr, measureText, {hover = over and T.inRect(mx, my, mr), disabled = measuring, active = measuring})
    local lr, layoutText = self:layoutRect()
    T.button(self, lr, layoutText, {hover = over and T.inRect(mx, my, lr), active = T.layoutDebug()})


    -- rows
    local hovered = over and self:rowAt(mx, my)
    local rw = w - T.pad * 2
    local now = getTimestampMs()
    for i = 0, ROWS_VISIBLE - 1 do
        local b = self.list[self.scroll + i + 1]
        if not b then break end
        local y = self.listY + i * self.rowH
        T.rect(self, T.pad, y, rw, self.rowH - 2, T.color.cell)
        if b == hovered then self:drawRect(T.pad, y, rw, self.rowH - 2, 0.06, 1, 1, 1) end
        if self.flash == b and now - self.flashMs < 400 then
            local ac = T.color.accent
            self:drawRect(T.pad, y, rw, self.rowH - 2, 0.25, ac.r, ac.g, ac.b)
        end
        T.border(self, T.pad, y, rw, self.rowH - 2, b == hovered and T.color.hoverEdge or T.color.border)
        local icon = self.rowH - 8
        ISInventoryItem.renderScriptItemIcon(self, b.script, T.pad + 4, y + 3, 1, icon, icon)
        local tx = T.pad + icon + 12
        T.text(self, T.fit(b.name, T.fontText, rw - icon - 20), tx, y + 2, T.color.text, T.fontText)
        T.text(self, T.fit(b.fullType, T.fontTile, rw - icon - 20), tx, y + 2 + ft, T.color.dim, T.fontTile)
    end

    -- scroll bar
    local n = #self.list
    if n > ROWS_VISIBLE then
        local trackH = ROWS_VISIBLE * self.rowH
        local barH = math.max(T.cell / 2, math.floor(trackH * ROWS_VISIBLE / n))
        local barY = self.listY + math.floor((trackH - barH) * self.scroll / (n - ROWS_VISIBLE))
        local tc = T.color.tileEdge
        self:drawRect(w - 5, barY, 3, barH, 1, tc.r, tc.g, tc.b)
    end
end

function KnoxDevPanel:spawn(b)
    local player = self:player()
    if not player then return end
    local item = player:getInventory():AddItem(b.fullType)
    if item then
        self.flash, self.flashMs = b, getTimestampMs()
        if HaloTextHelper and HaloTextHelper.addGoodText then
            HaloTextHelper.addGoodText(player, getText("IGUI_Knox_DevSpawned", item:getDisplayName()))
        end
        if KnoxScreen and KnoxScreen.instance then KnoxScreen.instance:markAllDirty() end
    end
end

function KnoxDevPanel:onMouseDown(x, y)
    local cx, cy, cw, ch = self:closeRect()
    if x >= cx and x < cx + cw and y >= cy and y < cy + ch then
        self:close()
        return true
    end
    if T.inRect(x, y, (self:layoutRect())) then
        T.setLayoutDebug(not T.layoutDebug())
        return true
    end
    if T.inRect(x, y, (self:measureRect())) then
        if not KnoxMeasure.isRunning() then KnoxMeasure.run() end
        return true
    end
    if T.inRect(x, y, (self:testRect())) then
        if KnoxSelfTest and not KnoxSelfTest.isRunning() then KnoxSelfTest.run(self.playerNum) end
        return true
    end
    local b = self:rowAt(x, y)
    if b then
        self:spawn(b)
        return true
    end
    KnoxWindowDrag.begin(self, x, y, self.headerH)
    return true
end

KnoxWindowDrag.install(KnoxDevPanel)

function KnoxDevPanel:onMouseWheel(del)
    local maxScroll = math.max(0, #self.list - ROWS_VISIBLE)
    self.scroll = math.max(0, math.min(maxScroll, self.scroll + del * 3))
    return true
end

function KnoxDevPanel:onRightMouseUp(x, y)
    return true
end

function KnoxDevPanel:close()
    self:setVisible(false)
    self.host:removeChild(self)
    if KnoxDevPanel.instance == self then KnoxDevPanel.instance = nil end
end

function KnoxDevPanel.toggle(host, playerNum)
    if KnoxDevPanel.instance then
        KnoxDevPanel.instance:close()
        return
    end
    local p = KnoxDevPanel:new(host, playerNum)
    p:initialise()
    p:instantiate()
    p:setX(math.floor((host:getWidth() - p:getWidth()) / 2))
    p:setY(math.floor((host:getHeight() - p:getHeight()) / 2))
    host:addChild(p)
    KnoxDevPanel.instance = p
end
