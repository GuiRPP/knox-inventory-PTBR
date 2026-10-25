-- The full-screen Knox screen from the mockup: tabs and weight on top, three
-- columns (equipment, inventory, surroundings), quick slots at the bottom.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxDrag"
require "Knox/KnoxTooltip"
require "Knox/KnoxGridView"
require "Knox/KnoxInventoryPanel"
require "Knox/KnoxEquipment"
require "Knox/KnoxSelect"
require "Knox/KnoxActions"
require "Knox/KnoxSplitDialog"
require "Knox/KnoxLootPanel"
require "Knox/KnoxContainerWindow"
require "Knox/KnoxDevPanel"
require "Knox/KnoxInspectWindow"
require "Knox/KnoxSlotPicker"
require "Knox/KnoxNews"
require "Knox/KnoxPinned"
require "Knox/KnoxControls"
require "Knox/KnoxHealthPanel"

local T = KnoxTheme
local DRAG_START_PX = 5

-- Quick slot (one hotbar slot) -------------------------------------------------

KnoxQuickSlot = ISUIElement:derive("KnoxQuickSlot")

--- `defName`: show the hotbar slot with this definition name (e.g. "Back"),
--- found again every frame (slots come and go with belts and holsters);
--- `label`: caption instead of the slot number.
function KnoxQuickSlot:new(screen, index, label, defName)
    local o = ISUIElement:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.screen = screen
    o.index = index
    o.label = label
    o.defName = defName
    return o
end

--- Index of the hotbar slot with definition name `name`, or nil.
function KnoxQuickSlot.indexOf(hb, name)
    for i, slot in ipairs(hb and hb.availableSlot or {}) do
        if slot.def and slot.def.name == name then return i end
    end
    return nil
end

function KnoxQuickSlot:hotbar()
    return getPlayerHotbar(self.screen.playerNum)
end

function KnoxQuickSlot:slot()
    local hb = self:hotbar()
    return hb and hb.availableSlot[self.index]
end

function KnoxQuickSlot:item()
    local hb = self:hotbar()
    return hb and hb.attachedItems and hb.attachedItems[self.index]
end

function KnoxQuickSlot:accepts(item)
    local hb, slot = self:hotbar(), self:slot()
    if not hb or not slot then return false end
    -- from the body only out of a hand (the game's attach takes it out of the
    -- hand first); worn things and other hotbar slots stay where they are
    local e = KnoxDrag.entity
    if e.fromBody and e.slotId ~= "hand1" and e.slotId ~= "hand2" then return false end
    return item ~= self:item() and hb:canBeAttached(slot, item)
end

function KnoxQuickSlot:render()
    if self.defName then
        self.index = KnoxQuickSlot.indexOf(self:hotbar(), self.defName) or 0
    end
    local w, h = self:getWidth(), self:getHeight()
    local item = self:liveItem()
    local over = self:isMouseOver()
    -- an item leaving this slot stays here faded until its move ends
    local alpha = 1
    local leaving, progress = KnoxGrid.leavingSlot(self.screen.pendingNow or {}, "quick:" .. self.index)
    if leaving then item, alpha = leaving, 0.4 end
    T.rect(self, 0, 0, w, h, T.color.cell, T.slotAlpha())
    if item then
        T.rect(self, 0, 0, w, h, T.category[T.categoryOf(item)], alpha)
        local side = math.floor(math.min(w, h) * 0.66)
        local dy, da = T.settleIn(self, (not leaving) and item or nil)   -- just hung here: it settles in
        ISInventoryItem.renderItemIcon(self, item, math.floor((w - side) / 2), math.floor((h - side) / 2) + dy, alpha * da, side, side)
    end
    if self.label then
        T.text(self, T.fit(T.upper(self.label), T.fontTile, w - 8), 5, 2, T.color.dim, T.fontTile, item and 1 or 0.8)
    else
        T.text(self, tostring(self.pos or self.index), 4, 1, T.color.dim, T.fontTile)
    end
    local edge = item and T.color.tileFrame or T.color.tileEdge
    if KnoxDrag.isActive() and over then
        local c = self:accepts(KnoxDrag.entity.item) and T.color.ok or T.color.bad
        self:drawRect(0, 0, w, h, 0.22, c.r, c.g, c.b)
        edge = c
    elseif over then
        edge = item and T.color.tileHover or T.color.hoverEdge
    end
    if item and not leaving and ((KnoxInspectWindow and KnoxInspectWindow.isOpen(item))
            or (KnoxFluidWindow and KnoxFluidWindow.isOpen(item))) then
        edge = T.color.accent   -- being inspected, or in the pouring window
    end
    if item and not leaving then T.tileFrame(self, 0, 0, w, h, edge) else T.border(self, 0, 0, w, h, edge) end
    if item and not leaving and KnoxEquip.isReplaced({item}) then T.replaceMark(self, 0, 0, w, h) end
    if item and not leaving and KnoxContextMenu and KnoxContextMenu.isTarget(item) then
        KnoxContextMenu.drawTarget(self, 0, 0, w, h)   -- its context menu is open
    end
    if progress then T.progress(self, 0, 0, w, h, progress) end
    local use = item and not leaving and KnoxGrid.useNow[item]
    if use then T.inUse(self, 0, 0, w, h, use) end
    local id = "quick:" .. self.index
    if KnoxGrid.arrivingSlot(self.screen.pendingNow or {}, id) or KnoxEquip.isHinted(id) then
        T.target(self, 0, 0, w, h)
    end

    if over and not KnoxDrag.isActive() then
        if item and not leaving then
            KnoxTooltip.want(item, self.screen.playerNum)
        else
            -- how many carried items can hang here; when some can, the quick pick
            -- panel opens: under the back slot, above the hotbar row
            local slot = self:slot()
            local name = slot and (getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name) or ""
            local cands = self:candidates()
            KnoxEquip.drawAvailable(self, w, h, #cands, self.label == nil)
            if #cands > 0 then
                T.target(self, 0, 0, w, h)
                KnoxSlotPicker.want(self, self.label or name, cands, self:pickFn(), self.label and "below" or "above")
            elseif not self.label then
                -- nothing to offer: just the slot's name above it (the back has its own caption)
                T.text(self, name, 0, -T.fontTileH - 2, T.color.text, T.fontTile)
            end
        end
    elseif not over and not item and KnoxSlotPicker.isOpenFor(self) then
        T.target(self, 0, 0, w, h)   -- its quick pick panel is open (the mouse is on it)
    end
end

--- Carried items that can be attached to this (empty) slot.
function KnoxQuickSlot:candidates()
    local hb, slot = self:hotbar(), self:slot()
    if not hb or not slot then return {} end
    return KnoxEquip.candidates(self, self.screen:player(), function(it)
        return it:getAttachmentType() ~= nil and hb:canBeAttached(slot, it)
    end)
end

--- What choosing an item in the quick pick panel does: attach it here.
function KnoxQuickSlot:pickFn()
    local hb, slot, index, player = self:hotbar(), self:slot(), self.index, self.screen:player()
    return function(it)
        KnoxGrid.track(player, {it}, KnoxEquip.gridSourceOf(it, player), {kind = "slot", id = "quick:" .. index}, function()
            hb:attachItem(it, slot.def.attachments[it:getAttachmentType()], index, slot.def, true)
        end)
    end
end

--- The attached item, unless it is in a move (then it shows only as a faded copy).
function KnoxQuickSlot:liveItem()
    local item = self:item()
    if item and KnoxGrid.pendingOf(item) then return nil end
    return item
end

function KnoxQuickSlot:onMouseDown(x, y)
    self.press = {item = self:liveItem(), x = getMouseX(), y = getMouseY()}
    return true
end

function KnoxQuickSlot:onMouseMove(dx, dy)
    local p = self.press
    if p and p.item and not KnoxDrag.isActive() and isMouseButtonDown(0) then
        if math.abs(getMouseX() - p.x) + math.abs(getMouseY() - p.y) >= DRAG_START_PX then
            KnoxDrag.startFromBody(p.item, "quick:" .. self.index)
            self.press = nil
        end
    end
end

function KnoxQuickSlot:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function KnoxQuickSlot:onMouseUpOutside(x, y)
    self.press = nil
end

function KnoxQuickSlot:onMouseUp(x, y)
    local hb, slot = self:hotbar(), self:slot()
    if KnoxDrag.isActive() then
        local item = KnoxDrag.entity.item
        local ok = self:accepts(item)
        local source = KnoxDrag.sourceInfo()
        KnoxDrag.cancel()
        if ok then
            local index = self.index
            KnoxGrid.track(self.screen:player(), {item}, source, {kind = "slot", id = "quick:" .. index}, function()
                hb:attachItem(item, slot.def.attachments[item:getAttachmentType()], index, slot.def, true)
            end)
        end
        return true
    end
    local p = self.press
    self.press = nil
    if p and not p.item then return true end   -- empty: the quick pick panel does the choosing
    if p and hb and hb:isAllowedToActivateSlot() then
        -- taking it in hand is a move like any other: faded here until done
        local index = self.index
        KnoxGrid.track(self.screen:player(), {p.item}, {kind = "slot", id = "quick:" .. index},
            {kind = "slot", id = "hand1"}, function() hb:activateSlot(index) end)
    end
    return true
end

function KnoxQuickSlot:onRightMouseUp(x, y)
    if KnoxDrag.isActive() then return true end   -- (an item is held: the button may turn it, see KnoxDragLayer)

    local hb = self:hotbar()
    if hb and self:item() then
        if KnoxContextMenu then KnoxContextMenu.setTarget({self:item()}, self.screen.playerNum) end
        hb:doMenu(self.index)
    end
    return true
end

-- Screen ------------------------------------------------------------------------

KnoxScreen = ISPanel:derive("KnoxScreen")

KnoxScreen.TABS = {"Equipment", "Health", "Skills", "Crafting", "Map"}
-- The stage of the UI overhaul each tab is (ROADMAP.md), on a small plate under
-- it - the one being made now in sand. The map has none (the user, 2026-10-14);
-- the journal tab is gone.
-- (the health tab came into stage 1 with 1.0: the author, 2026-10-18)
-- (Health back to stage 2: its tab is put off until 2.0 - the author, 2026-10-19)
KnoxScreen.TAB_STAGE = {Equipment = 1, Health = 2, Skills = 3, Crafting = 4}
KnoxScreen.STAGE_NOW = 1

function KnoxScreen:new(playerNum)
    local o = ISPanel:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.quickSlots = {}
    o.quickCount = -1
    o.tab = "Equipment"
    return o
end

function KnoxScreen:player()
    return getSpecificPlayer(self.playerNum)
end

function KnoxScreen:createChildren()
    local c = T.cell
    self.topH = math.floor(c * 1.17 + 0.5)
    self.botH = math.floor(c * 1.6 + 0.5)
    self.margin = math.floor(c * 0.42 + 0.5)
    local m = self.margin
    -- the tabs' stage plates: a row of their own under the top bar, a pad from it
    -- and a margin above the columns (squeezed into the margin they touched both)
    self.stageGap = T.pad
    self.stagePlateH = T.fontTileH + 8
    local colY = self.topH + self.stageGap + self.stagePlateH + m
    -- (down to a margin above the bottom bar: counted from colY, which the stage
    -- plates push down - from the top bar it ran under the bottom bar by their height)
    local colH = self:getHeight() - colY - self.botH - m

    local eqW = KnoxEquipmentPanel.columnWidth()
    local invW = KnoxInventoryPanel.columnWidth() + 6
    local lootW = math.max(0, self:getWidth() - m * 4 - eqW - invW)
    self.columns = {
        {x = m, w = eqW},
        {x = m * 2 + eqW, w = invW},
        {x = m * 3 + eqW + invW, w = lootW},
    }
    self.colY, self.colH = colY, colH

    self.equipment = KnoxEquipmentPanel:new(m, colY, eqW, colH, self.playerNum)
    self.equipment.screen = self
    self.equipment:initialise()
    self:addChild(self.equipment)

    -- inventory column: a title row, then the scrolling grids
    -- the title sits a pad down, level with the equipment column's, and the first
    -- grid's header starts level with that column's top slots (its title, then its gap)
    local titleH = T.fontH(T.fontHeader) + KnoxEquipmentPanel.metrics().gm
    -- (a pad above the column's bottom edge: the grids scroll out of sight before it)
    self.inventory = KnoxInventoryPanel:new(self.columns[2].x, colY + titleH, invW, colH - titleH - T.pad, self.playerNum)
    self.inventory:initialise()
    self:addChild(self.inventory)
    self.invTitleH = titleH

    self:buildSearch()

    local loot = self.columns[3]
    if loot.w > T.cell * 8 then
        -- (its first row level with the first grid's header in the inventory column, which starts a pad down)
        self.loot = KnoxLootPanel:new(loot.x + T.pad, colY + titleH + T.pad, loot.w - T.pad * 2, colH - titleH - T.pad * 2, self.playerNum)
        self.loot:initialise()
        self:addChild(self.loot)
    end
end

function KnoxScreen:markAllDirty()
    if self.inventory then self.inventory:markAllDirty() end
    if self.loot and self.loot.view then self.loot.view:markDirty() end
end

function KnoxScreen:rebuildQuickSlots()
    for _, q in ipairs(self.quickSlots) do self:removeChild(q) end
    self.quickSlots = {}
    local hb = getPlayerHotbar(self.playerNum)
    local n = hb and #hb.availableSlot or 0
    self.quickCount = n
    self.quickStamp = KnoxHotbarOrder and KnoxHotbarOrder.stamp or 0
    local size = math.floor(T.cell * 1.17 + 0.5)
    local gap = math.max(4, math.floor(T.cell / 6))
    local labelW = T.measure(T.fontCaps, T.upper(getText("IGUI_Knox_QuickSlots"))) + T.pad
    local x = self.margin + labelW
    local y = self:getHeight() - self.botH + math.floor((self.botH - size) / 2)
    -- in the order the bar shows them (KnoxHotbarOrder, with Knox's bar)
    local order = {}
    for i = 1, n do order[i] = i end
    if hb and n > 0 and KnoxHotbarOrder and T.on("hotbar") then order = KnoxHotbarOrder.order(hb) end
    for pos, i in ipairs(order) do
        local q = KnoxQuickSlot:new(self, i)
        q.pos = pos
        q:initialise()
        q:setX(x + (pos - 1) * (size + gap))
        q:setY(y)
        q:setWidth(size)
        q:setHeight(size)
        self:addChild(q)
        table.insert(self.quickSlots, q)
    end
end

local function drawPanel(ui, x, y, w, h)
    T.rect(ui, x, y, w, h, T.color.window, T.bgAlpha())
    T.border(ui, x, y, w, h, T.color.border)
end

-- Search by name: one field in the top bar, after the tabs. What it holds is
-- looked for in every grid at once (KnoxGridView.query): matches get a sand
-- frame, the rest dims, and the containers say how many matches they hold - the
-- character's bags always, the surroundings only once looked into. The game's
-- text box does the typing; its plate, the magnifier and the clear cross are
-- Knox's. Esc empties it first, then closes the screen.
KnoxScreen.search = nil

--- The field's plate on the top bar: {x, y, w, h}.
function KnoxScreen:searchRect()
    local tabs = self:tabRects()
    local x = tabs[#tabs].x + tabs[#tabs].w + T.pad * 2
    local h = math.floor(T.cell * 0.62 + 0.5)
    return {x, math.floor((self.topH - h) / 2), T.cell * 5, h}
end

--- The "Found N" button right of the field (shown while something is searched;
--- it opens KnoxFoundWindow), or nil. Its number is counted a few times a second.
function KnoxScreen:foundRect()
    if not KnoxGridView.query() then return nil end
    local now = getTimestampMs()
    if not self.foundCountMs or now - self.foundCountMs > 300 or self.foundQuery ~= KnoxGridView.query() then
        self.foundCount = KnoxFoundWindow and KnoxFoundWindow.count(self) or 0
        self.foundCountMs, self.foundQuery = now, KnoxGridView.query()
    end
    local r = self:searchRect()
    local text = T.upper(getText("IGUI_Knox_Found"))
    local num = tostring(self.foundCount or 0)
    -- [pad] caption [pad] plate [margin]: the plate keeps the button's margin
    -- above, below and to its right (T.barMargin)
    local w = T.pad + T.measure(T.fontCaps, text) + T.pad + T.countPlateW(num, r[4]) + T.barMargin(r[4])
    return {r[1] + r[3] + T.pad, r[2], w, r[4]}, text, num
end

function KnoxScreen:drawFoundButton()
    local r, text, num = self:foundRect()
    if not r then return end
    local hot = self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), r)
    local open = KnoxFoundWindow and KnoxFoundWindow.instance ~= nil
    local some = num ~= "0"
    T.button(self, r, "", {hover = hot, active = open})
    -- (a sand frame is 2 px, as the surroundings' and the bags' are)
    if hot or open then T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.accent) end
    T.inkLeft(self, text, r[1] + T.pad, r[2], r[4], (hot or open) and T.color.accent or (some and T.color.text or T.color.dim))
    self.foundPlate = self.foundPlate or {}
    T.countPlate(self, self.foundPlate, num, r[1] + r[3] - T.barMargin(r[4]), r[2], r[4], some)
end

--- The clear cross at the field's right end.
function KnoxScreen:searchClearRect()
    local r = self:searchRect()
    return {r[1] + r[3] - r[4], r[2], r[4], r[4]}
end

function KnoxScreen:buildSearch()
    local r = self:searchRect()
    local box = ISTextEntryBox:new("", r[1] + r[4], r[2], r[3] - r[4] * 2, r[4])
    -- Knox's own body font (the Java part lends it to the game's text box as a
    -- UIFont), else a game font of the same height
    local font = T.javaFonts and knoxFieldFont and type(T.fontText) == "table" and knoxFieldFont("body", T.fontText.size) or nil
    box.font = font or T.gameFont(T.fontText)
    box:initialise()
    box:instantiate()
    pcall(function()
        if font then box.javaObject:setFont(font) end
        box.javaObject:setCentreVertically(true)   -- the text in the middle of the plate's height
        box:setClearButton(false)                  -- (the cross is Knox's)
    end)
    box.prerender = function() end   -- (its plate is drawn by the screen)
    local c, d = T.color.bright, T.color.dim
    box:setTextRGBA(c.r, c.g, c.b, 1)
    box:setPlaceholderText(getText("IGUI_Knox_SearchItems"))
    box:setPlaceholderTextRGBA(d.r, d.g, d.b, 1)
    self:addChild(box)
    self.searchBox = box
    KnoxScreen.search = nil
end

--- Is the search field being typed in?
function KnoxScreen:searchFocused()
    local box = self.searchBox
    return box ~= nil and box:isFocused() == true
end

--- Empty the field (and stop typing in it).
function KnoxScreen:clearSearch()
    local box = self.searchBox
    if not box then return end
    box:setText("")
    if box:isFocused() then box:unfocus() end
    KnoxScreen.search = nil
end

-- The magnifier: Knox's own smooth picture (tools/make_lens.ps1), tinted. (Of
-- rectangles, then pixel by pixel, it came out crooked, then jagged - seen in
-- game 2026-10-14.)
local function drawLens(ui, x, y, s, c)
    if KnoxScreen.lensTex == nil then KnoxScreen.lensTex = getTexture("media/ui/knox_lens.png") or false end
    if KnoxScreen.lensTex then ui:drawTextureScaledAspect(KnoxScreen.lensTex, x, y, s, s, 1, c.r, c.g, c.b) end
end
function KnoxScreen:drawSearch()
    local box = self.searchBox
    if not box or not box:getIsVisible() then return end   -- (the grids' tab only)
    -- what is searched for: the text, trimmed, in lower case
    local text = box:getText() or ""
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    KnoxScreen.search = text ~= "" and T.lower(text) or nil
    local r = self:searchRect()
    local focused = box:isFocused()
    -- a click anywhere else ends the typing (the text stays)
    if focused and isMouseButtonDown(0) and not (self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), r)) then
        box:unfocus()
        focused = false
    end
    local hot = self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), r)
    local on = KnoxScreen.search ~= nil
    T.rect(self, r[1], r[2], r[3], r[4], T.color.cell)
    -- (a sand frame is 2 px, as the surroundings' and the bags' are)
    if focused or on then
        T.tileFrame(self, r[1], r[2], r[3], r[4], T.color.accent)
    else
        T.border(self, r[1], r[2], r[3], r[4], hot and T.color.text or T.color.tileEdge)
    end
    local lc = (focused or on) and T.color.accent or T.color.dim
    local ls = math.floor(r[4] * 0.56)
    drawLens(self, r[1] + math.floor((r[4] - ls) / 2), r[2] + math.floor((r[4] - ls) / 2), ls, lc)
    if (box:getText() or "") ~= "" then
        -- the cross that empties it
        local cr = self:searchClearRect()
        local xHot = self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), cr)
        local xc = xHot and T.color.accent or T.color.dim
        local p = math.floor(cr[3] * 0.32)
        for i = 0, cr[3] - p * 2 - 2 do
            self:drawRect(cr[1] + p + i, cr[2] + p + i, 2, 2, 1, xc.r, xc.g, xc.b)
            self:drawRect(cr[1] + cr[3] - p - 2 - i, cr[2] + p + i, 2, 2, 1, xc.r, xc.g, xc.b)
        end
    end
end

--- The key on the Close button: Knox's own key as the player has bound it (it
--- said "Tab" whatever the key was); none bound - Esc, which always closes.
function KnoxScreen:closeKey()
    if self.closeKeyText and self.closeKeyStamp == KnoxControls.stamp then return self.closeKeyText end
    local g = KnoxControls.get("toggle")
    local text = "Tab"
    if g == "" then text = "Esc" elseif g ~= KnoxControls.action("toggle").default then text = KnoxControls.label(g) end
    self.closeKeyText, self.closeKeyStamp = text, KnoxControls.stamp
    return text
end

--- Close button as in the mockup: a key box ("Tab"), then the caption.
function KnoxScreen:closeRect()
    -- (asked a few times a frame - the settings and DEV buttons stand left of it)
    local key = self:closeKey()
    local c = self.closeFor
    if not (c and c.key == key and c.tile == T.fontTile and c.caps == T.fontCaps and c.cell == T.cell) then
        local text = getText("IGUI_Knox_Close")
        local keyW = T.measure(T.fontTile, key) + 10
        c = {key = key, tile = T.fontTile, caps = T.fontCaps, cell = T.cell, text = text, keyW = keyW,
             w = keyW + 8 + T.buttonW(text), h = math.floor(T.cell * 0.62 + 0.5)}
        self.closeFor = c
    end
    return self:getWidth() - self.margin - c.w, math.floor((self.topH - c.h) / 2), c.w, c.h, c.text, c.keyW
end

--- The settings button: a square with a cog left of Close (the mod's settings
--- window: modules, look, controls).
function KnoxScreen:settingsRect()
    local cx, cy, _, ch = self:closeRect()
    return cx - T.pad - ch, cy, ch, ch, getText("IGUI_Knox_Settings_Button")
end
--- "DEV" button left of it: the test bench (game started with -debug, or DEV
--- mode switched on with Insert - see KnoxTestBench; the bench is left out of
--- the Workshop build, so there players never get the button).
function KnoxScreen:devRect()
    if not (KnoxTestBench and KnoxTestBench.devOn()) then return nil end
    local sx, cy, _, ch = self:settingsRect()
    local text = "DEV"
    local w = T.buttonW(text)
    return sx - T.pad - w, cy, w, ch, text
end

--- Tab rectangles along the top bar: {x, w, id, label}.
--- (asked several times a frame - the tabs, the search field after them, the
--- clock, the clicks: laid out once for the font, cell and margin there are)
function KnoxScreen:tabRects()
    local c = self.tabsFor
    if c and c.font == T.fontTab and c.cell == T.cell and c.margin == self.margin then return c.list end
    local list, x = {}, math.floor(self.margin / 2)
    local padX = math.floor(T.cell * 0.37 + 0.5)
    for _, id in ipairs(KnoxScreen.TABS) do
        local label = T.upper(getText("IGUI_Knox_Tab_" .. id))
        local w = T.measure(T.fontTab, label) + padX * 2
        table.insert(list, {x = x, w = w, id = id, label = label})
        x = x + w
    end
    self.tabsFor = {font = T.fontTab, cell = T.cell, margin = self.margin, list = list}
    return list
end

--- The tab's stage on a plate in the gap under the top bar: "STAGE 1 · NOW" in
--- sand for the stage being made, the later ones dark in a grey frame.
function KnoxScreen:drawTabStage(tr)
    local n = KnoxScreen.TAB_STAGE[tr.id]
    if not n then return end
    local now = n == KnoxScreen.STAGE_NOW
    -- (just "STAGE 1": the sand says it is the one now - "· NOW" dropped, the author 2026-10-18)
    local text = T.upper(getText("IGUI_Knox_TabStage", tostring(n)))
    local f = T.fontTile
    local h = self.stagePlateH
    local w = T.measure(f, text) + math.floor(T.pad * 0.75) * 2
    -- in the middle under its tab (they stood at the tabs' left edges and so
    -- looked off their tabs: the author, 2026-10-20)
    local x = tr.x + math.floor((tr.w - w) / 2)
    local y = self.topH + self.stageGap
    if now then
        T.rect(self, x, y, w, h, T.color.accent)
    else
        T.rect(self, x, y, w, h, T.color.header, T.bgAlpha())
        T.border(self, x, y, w, h, T.color.tileEdge)
    end
    -- (centred by the letters' own pixels, both ways: by the font's box it sat left and low)
    local c = now and T.color.ink or T.color.dim
    T.inkCentre(self, text, x, y, w, h, c.r, c.g, c.b, 1, f)
end

-- Tabs Knox doesn't draw yet (later stages) open the game's own window for
-- now, in place of the screen. (Health: Knox's own tab, KnoxHealthPanel - the
-- game's window only with the "health" module off.)
local GAME_TABS = {
    Health = function(playerNum) getPlayerInfoPanel(playerNum):toggleView(xpSystemText.health) end,
    Skills = function(playerNum) getPlayerInfoPanel(playerNum):toggleView(xpSystemText.skills) end,
    Crafting = function(playerNum) ISEntityUI.OpenHandcraftWindow(getSpecificPlayer(playerNum), nil) end,
    Map = function(playerNum) ISWorldMap.ShowWorldMap(playerNum) end,
}

--- Can the tab be used? (the world map can be off in the sandbox options)
function KnoxScreen.tabAvailable(id)
    if id == "Map" then return ISWorldMap ~= nil and ISWorldMap.IsAllowed() end
    return true
end

function KnoxScreen:setTab(id)
    if id == self.tab or not KnoxScreen.tabAvailable(id) then return end
    local open = GAME_TABS[id]
    if id == "Health" and T.on("health") and KnoxHealthPanel then open = nil end
    if open then
        local playerNum = self.playerNum
        self:close()
        open(playerNum)
        return
    end
    self.tab = id
    local main = id == "Equipment"
    for _, child in ipairs({self.equipment, self.inventory, self.loot, self.searchBox}) do
        if child then child:setVisible(main) end
    end
    if not main then
        self:clearSearch()
        if KnoxFoundWindow and KnoxFoundWindow.instance then KnoxFoundWindow.instance:close() end
    end
    -- the news page (a click on the mod's name in the top bar) takes the columns' place
    if id == "News" and not self.news then
        self.news = KnoxNews:new(self.margin, self.colY, self:getWidth() - self.margin * 2, self.colH)
        self.news:initialise()
        self:addChild(self.news)
    elseif self.news then
        if id == "News" then self.news:reload() end
        self.news:setVisible(id == "News")
    end
    -- the health tab (KnoxHealthPanel) takes the columns' place, made the first time
    if id == "Health" and not self.health then
        self.health = KnoxHealthPanel:new(self.margin, self.colY, self:getWidth() - self.margin * 2, self.colH, self.playerNum, self)
        self.health:initialise()
        self:addChild(self.health)
        self.health:shown()
    elseif self.health then
        if id == "Health" then self.health:shown() end
        self.health:setVisible(id == "Health")
    end
    if not main then
        KnoxDrag.cancel()
        KnoxSelect.clear()
        if KnoxSplitDialog.instance then KnoxSplitDialog.instance:close() end
        KnoxContainerWindow.closeAll()
        KnoxInspectWindow.closeAll()
    end
end

local function over(ui, x, y, w, h)
    return ui:isMouseOver() and T.inRect(ui:getMouseX(), ui:getMouseY(), {x, y, w, h})
end

--- A car's dashboard puts itself on top of everything when the character gets
--- in - over this screen too, if it was open. It is hidden while the screen is
--- open and shown again when it closes.
function KnoxScreen:hideDashboard()
    local dash = getPlayerVehicleDashboard and getPlayerVehicleDashboard(self.playerNum)
    if dash and dash:getIsVisible() then
        dash:setVisible(false)
        self.dashHidden = dash
    end
    -- (Knox's own dashboard, in place of the game's: KnoxDashboard)
    local kd = KnoxDashboard and KnoxDashboard.instance
    if kd and kd:getIsVisible() then
        kd:setVisible(false)
        self.knoxDashHidden = kd
    end
end

function KnoxScreen:showDashboard()
    local dash = self.dashHidden
    self.dashHidden = nil
    -- (out of the car meanwhile: the game has taken it off the screen itself)
    if dash and dash.vehicle and self:player() and self:player():getVehicle() then dash:setVisible(true) end
    -- (got in while the screen was open: Knox's dashboard came up hidden on its own,
    -- KnoxDashboard.show - not by this screen, so not in knoxDashHidden; the author,
    -- 2026-10-21: it stayed away until getting in again)
    local kd = self.knoxDashHidden or (KnoxDashboard and KnoxDashboard.instance)
    self.knoxDashHidden = nil
    if kd and kd.shownAt and self:player() and self:player():getVehicle() then kd:setVisible(true) end
end

--- What the screen hid while open, shown again (closing, or the screen failing:
--- KnoxMain screenFailed). Each on its own: one failing doesn't keep the other hidden.
function KnoxScreen:restoreHidden()
    pcall(self.showDashboard, self)
    local hb = self.hidHotbar
    self.hidHotbar = nil
    if hb then pcall(hb.setVisible, hb, true) end
end

--- A bar's fill on its way to `target` (0..1): it grows and shrinks over a
--- moment instead of jumping. One memory per bar (`key`) on the screen.
local function eased(screen, key, target)
    local now = getTimestampMs()
    local s = screen.bars and screen.bars[key]
    if not s then
        screen.bars = screen.bars or {}
        s = {v = target, ms = now}
        screen.bars[key] = s
    end
    local dt = math.min(100, now - s.ms)
    s.ms = now
    s.v = s.v + (target - s.v) * T.anim(math.min(1, dt / 90))
    if math.abs(target - s.v) < 0.002 then s.v = target end
    return s.v
end

function KnoxScreen:prerender()
    self:hideDashboard()
    local hb = getPlayerHotbar(self.playerNum)
    if (hb and #hb.availableSlot or 0) ~= self.quickCount
            or (KnoxHotbarOrder and KnoxHotbarOrder.stamp ~= self.quickStamp) then
        self:rebuildQuickSlots()
    end
    self.pendingNow = KnoxGrid.pendingList()   -- read by the quick slots while they draw
    KnoxGrid.updateUse(self:player())          -- items the current action works with
    KnoxEquip.updateHints(self:player())       -- slots to light up
    KnoxSlotPicker.sync(self)                -- quick pick panel of an empty slot
    KnoxContainerWindow.updateAll()
    KnoxInspectWindow.updateAll()
    -- (the search is ticked by the surroundings column; a screen too narrow for
    -- one still searches its bag windows and bags)
    if not self.loot and self.tab == "Equipment" and KnoxSearch then KnoxSearch.tick(nil, nil) end

    local W, H = self:getWidth(), self:getHeight()
    local fh = T.fontH(T.fontHeader)
    T.rect(self, 0, 0, W, H, T.color.screen, 0.93 * T.bgAlpha())

    -- top bar: tabs in capitals, the active one bright with a sand underline
    T.rect(self, 0, 0, W, self.topH, T.color.header, T.bgAlpha())
    T.rect(self, 0, self.topH - 1, W, 1, T.color.border)
    local tabH = T.fontH(T.fontTab)
    for _, tr in ipairs(self:tabRects()) do
        local active = tr.id == self.tab
        local usable = KnoxScreen.tabAvailable(tr.id)
        local hover = usable and not active and over(self, tr.x, 0, tr.w, self.topH)
        local c = active and T.color.bright or (hover and T.color.text or T.color.dim)
        T.textCentre(self, tr.label, tr.x + math.floor(tr.w / 2),
            math.floor((self.topH - tabH) / 2), c, T.fontTab, usable and 1 or 0.35)
        if active then T.rect(self, tr.x, self.topH - 2, tr.w, 2, T.color.accent) end
        self:drawTabStage(tr)
    end
    self:drawSearch()
    if self.searchBox and self.searchBox:getIsVisible() then self:drawFoundButton() end

    local cx, cy, cw, ch, closeText, keyW = self:closeRect()
    local capH = T.fontH(T.fontCaps)
    -- close button: [Tab] ЗАКРЫТЬ
    local closeOver = over(self, cx, cy, cw, ch)
    T.button(self, {cx, cy, cw, ch}, "", {hover = closeOver})
    local kh = T.fontH(T.fontTile) + 4
    local kx, ky = cx + T.pad, cy + math.floor((ch - kh) / 2)
    T.rect(self, kx, ky, keyW, kh, T.color.header)
    T.border(self, kx, ky, keyW, kh, T.color.tileEdge)
    T.text(self, self:closeKey(), kx + 5, ky + 2, T.color.text, T.fontTile)
    T.caps(self, closeText, kx + keyW + 8, cy + math.floor((ch - capH) / 2),
        closeOver and T.color.accent or T.color.text)

    -- settings button
    local sx, sy, sw0, sh0, setText = self:settingsRect()
    local setHot = over(self, sx, sy, sw0, sh0)
    local setOpen = KnoxSettings ~= nil and KnoxSettings.instance ~= nil
    T.button(self, {sx, sy, sw0, sh0}, "", {hover = setHot, active = setOpen})
    do
        -- a cog: Knox's own smooth picture (tools/make_gear.ps1), tinted
        if KnoxScreen.gearTex == nil then KnoxScreen.gearTex = getTexture("media/ui/knox_gear.png") or false end
        local c = (setHot or setOpen) and T.color.accent or T.color.text
        local side = math.floor(sw0 * 0.64)
        if KnoxScreen.gearTex then
            self:drawTextureScaledAspect(KnoxScreen.gearTex, sx + math.floor((sw0 - side) / 2), sy + math.floor((sh0 - side) / 2),
                side, side, 1, c.r, c.g, c.b)
        end
    end
    -- developer button
    local dx, dy, dw, dh, devText = self:devRect()
    if dx then
        local on = KnoxDevPanel.instance ~= nil
        T.button(self, {dx, dy, dw, dh}, devText, {hover = over(self, dx, dy, dw, dh), active = on, color = T.color.warn})
    end

    -- the clock and the game's speed: at the right of the top bar, before the buttons
    -- (right of the search field, and of its Found button while it is there)
    local sr = self:foundRect() or self:searchRect()
    self:drawTime(sr[1] + sr[3] + T.pad * 2, (dx or sx) - T.pad * 2)
    if self.tab == "Equipment" then
        -- columns
        for _, col in ipairs(self.columns) do
            if col.w > 0 then drawPanel(self, col.x, self.colY, col.w, self.colH) end
        end
        local inv = self.columns[2]
        local titleY = self.colY + T.pad   -- as KnoxEquipmentPanel draws its own title
        T.caps(self, getText("IGUI_Knox_Inventory"), inv.x + T.pad, titleY, T.color.bright, T.fontHeader)
        -- what the character carries, at the right end of the column's title:
        -- "4.5 / 8 kg" and a thin bar under it
        do
            local player = self:player()
            local wNow, wMax = player:getInventoryWeight(), player:getMaxWeight()
            local heavy = wNow > wMax
            local right = inv.x + T.pad + KnoxInventoryPanel.headerW()   -- the right edge of the grids' headers under it
            local valH = T.fontH(T.fontText)
            local wy = titleY + math.floor((fh - valH) / 2)
            local maxText = " / " .. KnoxInventoryPanel.round1(wMax) .. " " .. T.upper(getText("IGUI_Knox_Kg"))
            local maxW = T.measure(T.fontText, maxText)
            local nowText = KnoxInventoryPanel.round1(wNow)
            T.textRight(self, maxText, right, wy, T.color.dim, T.fontText)
            T.textRight(self, nowText, right - maxW, wy, heavy and T.color.bad or T.color.bright, T.fontText)
            -- the bar: left of the figures, on the middle of the title's line
            local barW = T.cell * 2
            local bx = right - maxW - T.measure(T.fontText, nowText) - T.pad - barW
            local by = titleY + math.floor(fh / 2) - 1
            T.rect(self, bx, by, barW, 3, T.color.line)
            local frac = eased(self, "inventory", math.min(1, wNow / math.max(0.1, wMax)))
            T.rect(self, bx, by, math.floor(barW * frac), 3, heavy and T.color.bad or T.color.accent)
            -- an item being dragged: what the drop under the mouse would do to
            -- the weight - red "+" for a thing coming onto the character, green
            -- "-" for one of the character's own leaving
            self:drawWeightDelta("inventory", self:dragWeightDelta(player), bx, by, barW, frac, wMax, wy)
        end
        local loot = self.columns[3]
        if loot.w > 0 then
            T.caps(self, getText("IGUI_Knox_Tab_Surroundings"), loot.x + T.pad, titleY, T.color.bright, T.fontHeader)
            -- what the chosen container holds, as the inventory column shows the
            -- character's load: a bar and "12.3 / 50 kg", ending where its grid does
            local chosen = self.loot and self.loot.selected
            local head = self.loot and self.loot.header
            if chosen and head then
                local player = self:player()
                local wNow = chosen:getCapacityWeight() or 0
                local wMax = chosen:getType() ~= "floor" and (chosen:getEffectiveCapacity(player) or 0) or 0
                local valH = T.fontH(T.fontText)
                local wy = titleY + math.floor((fh - valH) / 2)
                local right = self.loot:getX() + self.loot.m.gridX + head.w
                local kg = T.upper(getText("IGUI_Knox_Kg"))
                -- (the floor has no limit: the weight alone)
                local maxText = wMax > 0 and (" / " .. KnoxInventoryPanel.round1(wMax) .. " " .. kg) or (" " .. kg)
                local maxW = T.measure(T.fontText, maxText)
                local nowText = KnoxInventoryPanel.round1(wNow)
                local full = wMax > 0 and wNow >= wMax * 0.95
                T.textRight(self, maxText, right, wy, T.color.dim, T.fontText)
                T.textRight(self, nowText, right - maxW, wy, full and T.color.bad or T.color.bright, T.fontText)
                if wMax > 0 then
                    local barW = T.cell * 2
                    local bx = right - maxW - T.measure(T.fontText, nowText) - T.pad - barW
                    local by = titleY + math.floor(fh / 2) - 1
                    T.rect(self, bx, by, barW, 3, T.color.line)
                    local lfrac = eased(self, "loot", math.min(1, wNow / wMax))
                    T.rect(self, bx, by, math.floor(barW * lfrac), 3, full and T.color.bad or T.color.accent)
                    self:drawWeightDelta("loot", self:lootWeightDelta(chosen, player), bx, by, barW, lfrac, wMax, wy)
                end
            end
        end
    elseif self.tab ~= "News" and self.tab ~= "Health" then
        local x0, x1 = self.margin, W - self.margin
        drawPanel(self, x0, self.colY, x1 - x0, self.colH)
        T.textCentre(self, getText("IGUI_Knox_TabSoon"), math.floor(W / 2), self.colY + math.floor(self.colH / 2) - fh,
            T.color.dim, T.fontHeader)
    end

    -- bottom bar: "БЫСТРЫЕ СЛОТЫ", the slots, key hints on the right
    local botY = H - self.botH
    T.rect(self, 0, botY, W, self.botH, T.color.header, T.bgAlpha())
    T.rect(self, 0, botY, W, 1, T.color.border)
    T.caps(self, getText("IGUI_Knox_QuickSlots"), self.margin, botY + math.floor((self.botH - capH) / 2), T.color.dim)
    -- the mod's name and stage in the bottom right corner: KNOX INVENTORY [STAGE 1].
    -- It opens the news page: lit on hover, underlined while open, a breathing
    -- sand dot on the stage plate while there are unread posts
    -- (the beta says so here: on a player's screenshot it is the first thing seen)
    local stage = T.MOD_ID == "KnoxInventoryBeta" and "1.0 BETA" or T.upper(getText("IGUI_Knox_Stage"))
    local sf, bf = T.fontTile, T.fontCaps
    local sh = T.fontH(sf) + 6
    local sw = T.measure(sf, stage) + 14
    local knox, inv = "KNOX", "INVENTORY"
    local kw, iw = T.measure(bf, knox), T.measure(bf, inv)
    local space = T.measure(bf, " ")
    -- (the right edge of the columns above; its lit plate and its line under it
    -- stop there too - they stood out past it by a pad, the author 2026-10-18)
    local last = self.columns and self.columns[#self.columns]
    local right = (last and last.w > 0) and (last.x + last.w) or (W - self.margin)
    local left = right - sw - T.pad - iw - space - kw
    local r = {left - T.pad, botY + 1, right - left + T.pad, self.botH - 1}
    self.brandRect = r
    local open = self.tab == "News"
    local hot = over(self, r[1], r[2], r[3], r[4])
    local ty = botY + math.floor((self.botH - T.fontH(bf)) / 2)
    T.text(self, knox, left, ty, T.color.bright, bf)
    T.text(self, inv, left + kw + space, ty, T.color.accent, bf)
    -- under the mouse only the stage plate lights up - sand, dark letters - not
    -- the whole corner (the author, 2026-10-20); while the news is open it is tinted
    local px, py = right - sw, botY + math.floor((self.botH - sh) / 2)
    if hot then
        T.rect(self, px, py, sw, sh, T.color.accent)
    elseif open then
        T.rect(self, px, py, sw, sh, T.color.accent, 0.18)
    end
    T.border(self, px, py, sw, sh, T.color.accent)
    local sc = hot and T.color.ink or T.color.accent
    T.inkCentre(self, stage, px, py, sw, sh, sc.r, sc.g, sc.b, 1, sf)
    if open then T.rect(self, r[1], botY + 1, r[3], 2, T.color.accent) end
    if KnoxNews.hasUnread() then
        local d = math.max(6, math.floor(T.cell / 7))
        local c = T.color.accent
        local a = 0.55 + 0.45 * math.sin(getTimestampMs() / 1000 * math.pi * 1.6)
        self:drawRect(px + sw - math.floor(d / 2) - 1, py - math.floor(d / 2) + 1, d, d, a, c.r, c.g, c.b)
    end
    -- the coin: Boosty, 12 px left of KNOX (the author's mockup boosty_v1, 2026-10-25) - dim and
    -- still at rest, sand with Knox's tooltip under the mouse; a click opens Boosty in the browser
    local s = T.cell / 48
    local cs = math.floor(22 * s + 0.5)
    local coin = self.coinRect or {0, 0, 0, 0}
    self.coinRect = coin
    coin[1], coin[2], coin[3], coin[4] = left - math.floor(12 * s + 0.5) - cs, botY + math.floor((self.botH - cs) / 2), cs, cs
    self.coinHot = self:isMouseOver() and T.inRect(self:getMouseX(), self:getMouseY(), coin)
    self:drawCoin(coin, self.coinHot)
    -- the key hints: 24 px left of the coin
    self:drawHints(coin[1] - math.floor(24 * s + 0.5), botY + math.floor(self.botH / 2))
end

-- The bottom bar's coin (two coins, lines only; the front one filled with the bar's colour)
local COIN_REST = {r = 0x6f / 255, g = 0x74 / 255, b = 0x6d / 255}
local COIN_FILL = {r = 0x1a / 255, g = 0x1d / 255, b = 0x1d / 255}
local COIN_FILL_HOT = {r = 0x25 / 255, g = 0x25 / 255, b = 0x1f / 255}
local TIP_EDGE = {r = 0x4a / 255, g = 0x4f / 255, b = 0x4f / 255}   -- (the item tooltip header's frame)
-- (only once read: KnoxRoadmap's pinned pictures, T.readyTex)
local function coinTexture(name)
    return KnoxRoadmap and KnoxRoadmap.tex(name) or nil
end

function KnoxScreen:drawCoin(r, hot)
    local fill, lines = coinTexture("coin_fill"), coinTexture("coin_lines")
    local fc = hot and COIN_FILL_HOT or COIN_FILL
    local lc = hot and T.color.accent or COIN_REST
    if fill then self:drawTextureScaled(fill, r[1], r[2], r[3], r[4], 1, fc.r, fc.g, fc.b) end
    if lines then self:drawTextureScaled(lines, r[1], r[2], r[3], r[4], 1, lc.r, lc.g, lc.b) end
end

local tipBand, tipOpts = {0, 0, 0, 0}, {}

--- The coin's tooltip, Knox's: a header in a double frame with the logo, "Support Knox" /
--- "Boosty and the mod's roadmap", a line, "[LMB] open". Over the columns, right-aligned with
--- the corner's name, above the bar.
function KnoxScreen:drawCoinTip()
    if not self.coinHot or not self.brandRect then return end
    local s = T.cell / 48
    local pad = math.floor(8 * s + 0.5)
    local w = math.floor(250 * s + 0.5)
    local titleF = T.fontTab
    local subF = T.javaFonts and T.makeFont("body", T.cell * 0.25) or T.fontTile
    local logo = math.floor(30 * s + 0.5)
    local hh = pad * 2 + math.max(logo, T.fontH(titleF) + T.fontH(subF))
    local kh = T.fontH(T.fontTile) + 4
    local h = pad + hh + pad + 1 + pad + kh + pad
    local b = self.brandRect
    local x = b[1] + b[3] - w
    local y = self:getHeight() - self.botH - math.floor(17 * s + 0.5) - h
    T.rect(self, x, y, w, h, T.color.window)
    T.border(self, x, y, w, h, T.color.tileEdge)
    local hx, hy, hw = x + pad, y + pad, w - pad * 2
    T.rect(self, hx, hy, hw, hh, T.color.header)
    T.border(self, hx, hy, hw, hh, TIP_EDGE)
    T.border(self, hx + 1, hy + 1, hw - 2, hh - 2, TIP_EDGE)
    local lt = coinTexture("logo_clean_64")
    if lt then self:drawTextureScaled(lt, hx + pad, hy + math.floor((hh - logo) / 2), logo, logo, 1, 1, 1, 1) end
    local tx = hx + pad + logo + math.floor(10 * s + 0.5)
    local ty = hy + math.floor((hh - T.fontH(titleF) - T.fontH(subF)) / 2)
    tipBand[1], tipBand[2], tipBand[3], tipBand[4] = tx, ty, hx + hw - pad - tx, T.fontH(titleF)
    tipOpts.font = titleF
    T.label(self, getText("IGUI_Knox_CoinTitle"), tipBand, T.color.bright, tipOpts)
    tipBand[2], tipBand[4] = ty + T.fontH(titleF), T.fontH(subF)
    tipOpts.font = subF
    T.label(self, getText("IGUI_Knox_CoinSub"), tipBand, T.color.dim, tipOpts)
    local ly = hy + hh + pad
    T.rect(self, hx, ly, hw, 1, T.color.border)
    T.keyHint(self, hx, ly + 1 + pad, getText("IGUI_Knox_LMB"), getText("IGUI_Knox_CoinOpen"), kh)
end

function KnoxScreen:render()
    if ISPanel.render then ISPanel.render(self) end
    self:drawCoinTip()
end

--- Key hints right-aligned at `right`, centred on `midY`: [R] повернуть ...
function KnoxScreen:drawHints(right, midY)
    -- (written from the controls as they are bound now)
    if not self.hints or self.hintsStamp ~= KnoxControls.stamp then
        self.hints = KnoxControls.hints()
        self.hintsStamp = KnoxControls.stamp
    end
    local gap = math.floor(T.cell * 0.45)
    local kh = T.fontH(T.fontTile) + 4
    local total = 0
    for i, h in ipairs(self.hints) do
        h.w = T.measure(T.fontTile, h.key) + 10 + 6 + T.measure(T.fontText, h.label)
        total = total + h.w + (i > 1 and gap or 0)
    end
    -- leave room for the quick slots on the left
    local left = self.quickSlots[#self.quickSlots]
    local minX = left and (left:getX() + left:getWidth() + T.pad * 2) or 0
    local x = right - total
    local first = 1
    while x < minX and first <= #self.hints do
        x = x + self.hints[first].w + gap
        first = first + 1
    end
    for i = first, #self.hints do
        local h = self.hints[i]
        T.keyHint(self, x, midY - math.floor(kh / 2), h.key, h.label, kh)
        x = x + h.w + gap
    end
end

-- Weight of a drag ----------------------------------------------------------------------

--- What an item adds to the carried weight lying in `container` (nil: on the
--- body): its weight with what is in it, less what a worn or held bag takes off.
local function carriedWeight(item, container, player)
    local w = KnoxGrid.weightOf(item)
    local bag = container and container:getContainingItem()
    if bag and KnoxGrid.isEquippedNow(bag, player) then
        w = w * (1 - (bag:getWeightReduction() or 0) / 100)
    end
    return w
end

--- The change of the carried weight if the dragged tiles were dropped where the
--- mouse is: positive over the character's own grids for things from outside,
--- negative over the surroundings for the character's own things; nil otherwise.
--- The character's container the mouse is on right now - a grid of the
--- inventory column or its header - or nil over the empty room beside them:
--- a drop there goes nowhere, so nothing is promised about the weight.
function KnoxScreen:ownContainerUnderMouse()
    local inv = self.inventory
    if not inv or not inv:isMouseOver() then return nil end
    for _, s in ipairs(inv.sections) do
        if s.view:getIsVisible() and s.view:isMouseOver() then return s.view.container end
    end
    local s = inv:sectionAtHeader(inv:getMouseX(), inv:getMouseY())
    return s and s.view.container or nil
end

--- Is the mouse on the chosen container of the surroundings: its grid, its header or a row of the list?
function KnoxScreen:lootUnderMouse()
    local loot = self.loot
    if not loot or not loot:isMouseOver() then return false end
    if loot.view and loot.view:isMouseOver() then return true end
    local mx, my = loot:getMouseX(), loot:getMouseY()
    local H = loot.header
    if H and my >= 0 and my < H.h and mx >= loot.m.gridX and mx < loot.m.gridX + H.w then return true end
    -- (its own row only: a drop on another row goes into that other container)
    for _, rr in ipairs(loot.rowRects or {}) do
        local r = rr.rect
        if rr.entry.container == loot.selected and mx >= r[1] and mx < r[1] + r[3] and my >= r[2] and my < r[2] + r[4] then
            return true
        end
    end
    return false
end

--- The same for the chosen container of the surroundings: what a drop under
--- the mouse would add to it (things from elsewhere, held over the
--- surroundings) or take from it (its own things, held over the character's side).
function KnoxScreen:lootWeightDelta(container, player)
    if not KnoxDrag.isActive() or not container then return nil end
    local tiles = {{entity = KnoxDrag.entity}}
    for _, ex in ipairs(KnoxDrag.extras) do table.insert(tiles, ex) end
    local sign
    if self:lootUnderMouse() then
        sign = 1
    elseif self:ownContainerUnderMouse() then
        sign = -1
    else
        return nil
    end
    local sum = 0
    for _, tile in ipairs(tiles) do
        for _, it in ipairs(tile.entity.items) do
            local inside = it:getContainer() == container
            if (sign > 0 and not inside) or (sign < 0 and inside) then sum = sum + carriedWeight(it, nil, player) end
        end
    end
    return sign * sum
end

--- The hint itself beside a weight bar: "+1.5" in red or "-1.5" in green left
--- of the bar, and that much of the bar in the same color. It comes and goes
--- over a moment and its figure and stretch of the bar follow smoothly as the
--- drag moves from one place to another. `key`: one memory per bar.
function KnoxScreen:drawWeightDelta(key, delta, bx, by, barW, frac, wMax, wy)
    if delta and math.abs(delta) < 0.005 then delta = nil end
    local now = getTimestampMs()
    self.deltas = self.deltas or {}
    local s = self.deltas[key]
    if not s then
        s = {v = 0, a = 0, ms = now}
        self.deltas[key] = s
    end
    local step = T.anim(math.min(1, math.min(100, now - s.ms) / 80))
    s.ms = now
    s.a = s.a + ((delta and 1 or 0) - s.a) * step
    if delta then
        if s.a < 0.05 then s.v = delta end          -- (just come: no slide from the last drag's figure)
        s.v = s.v + (delta - s.v) * step
    end
    if s.a < 0.02 then
        if not delta then s.a = 0 end
        return
    end
    local shown = s.v
    if delta and math.abs(delta - shown) < 0.05 then shown = delta end
    local c = shown > 0 and T.color.bad or T.color.ok
    local text = (shown > 0 and "+" or "-") .. KnoxInventoryPanel.round1(math.abs(shown))
    T.textRight(self, text, bx - T.pad, wy, c, T.fontText, s.a)
    local cur = math.floor(barW * frac)
    local seg = math.max(2, math.floor(barW * math.min(1, math.abs(shown) / math.max(0.1, wMax)) + 0.5))
    if shown > 0 then
        seg = math.min(seg, barW - cur)
        if seg > 0 then
            self:drawRect(bx + cur, by, seg, 3, s.a, c.r, c.g, c.b)
        else
            self:drawRect(bx + barW - 2, by - 1, 2, 5, s.a, c.r, c.g, c.b)
        end
    else
        seg = math.min(seg, cur)
        self:drawRect(bx + cur - seg, by, seg, 3, s.a, c.r, c.g, c.b)
    end
end

function KnoxScreen:dragWeightDelta(player)
    if not KnoxDrag.isActive() then return nil end
    local tiles = {{entity = KnoxDrag.entity}}
    for _, ex in ipairs(KnoxDrag.extras) do table.insert(tiles, ex) end
    local inv = player:getInventory()
    local function own(item)
        local c = item:getContainer()
        return c ~= nil and (c == inv or c:isInCharacterInventory(player))
    end
    -- (only over a container itself: the empty room around the grids changes nothing)
    local target = self:ownContainerUnderMouse()
    if target then
        -- a worn bag lightens what goes into it
        local sum = 0
        for _, tile in ipairs(tiles) do
            for _, it in ipairs(tile.entity.items) do
                if not own(it) then sum = sum + carriedWeight(it, target, player) end
            end
        end
        return sum
    end
    if self:lootUnderMouse() then
        local sum = 0
        for _, tile in ipairs(tiles) do
            for _, it in ipairs(tile.entity.items) do
                if own(it) then sum = sum - carriedWeight(it, it:getContainer(), player) end
            end
        end
        return sum
    end
    return nil
end
-- Time ------------------------------------------------------------------------------
-- The clock (as the game shows it: only with a watch or a clock on the
-- character, the date only with a digital one) and the game's speed - pause,
-- play, fast, faster - so time can be let run while the screen is open.
-- Single player only: on a server the speed is not the player's to set.

local SPEEDS = {0, 1, 2, 3}

local function speedControls()
    return UIManager.getSpeedControls and UIManager.getSpeedControls() or nil
end

local function clockText()
    local clock = UIManager.getClock and UIManager.getClock() or nil
    if clock and not clock:isVisible() then return "--:--", nil end
    local gt = getGameTime()
    local h, m = gt:getHour(), gt:getMinutes()
    local text
    if getCore():getOptionClock24Hour() then
        text = string.format("%02d:%02d", h, m)
    else
        local h12 = h % 12
        if h12 == 0 then h12 = 12 end
        text = string.format("%d:%02d %s", h12, m, h < 12 and "AM" or "PM")
    end
    local date = nil
    if not clock or clock:isDateVisible() then
        local d, mo = gt:getDay() + 1, gt:getMonth() + 1
        if getCore():getOptionClockFormat() == 1 then date = string.format("%02d/%02d", mo, d)
        else date = string.format("%02d/%02d", d, mo) end
    end
    return text, date
end

--- Pause bars and play triangles of plain rectangles in rect r.
local function drawSpeedIcon(ui, r, speed, c)
    local s = r[3]
    local p = math.floor(s * 0.28 + 0.5)
    local h = s - p * 2
    local y0 = r[2] + p
    local function box(x, y, w, hh) ui:drawRect(x, y, w, hh, 1, c.r, c.g, c.b) end
    if speed == 0 then
        local bw = math.max(2, math.floor(h / 3.5))
        local cx = r[1] + math.floor(s / 2)
        box(cx - bw - math.floor(bw / 2), y0, bw, h)
        box(cx + math.floor(bw / 2), y0, bw, h)
        return
    end
    -- `speed` triangles pointing right, side by side
    local half = math.floor(h / 2)
    local tw = half + 1
    local x = r[1] + math.floor((s - tw * speed) / 2)
    for n = 1, speed do
        for i = 0, half do box(x + i, y0 + i, 1, h - i * 2) end
        x = x + tw
    end
end

--- Lay the clock and the four speed buttons out in the top bar between x0 and x1; draw them.
function KnoxScreen:drawTime(x0, x1)
    self.speedRects = nil
    local sc = speedControls()
    local s = math.floor(T.cell * 0.62 + 0.5)
    local gap = 4
    local text, date = clockText()
    local tf, df = T.fontTab, T.fontTile
    local textW = T.measure(tf, text)
    local dateW = date and (T.measure(df, date) + T.pad) or 0
    local buttons = (sc and not isClient()) and #SPEEDS or 0
    local need = textW + dateW + (buttons > 0 and (T.pad * 2 + buttons * s + (buttons - 1) * gap) or 0)
    if x1 - x0 < need then return end
    local x = x1 - need
    local known = text ~= "--:--"
    -- the digits that change roll: the old one goes up and out, the new one
    -- comes up from under it; the rest stand still
    local now = getTimestampMs()
    if self.clockText ~= text then
        self.clockOld, self.clockMs = self.clockText, now
        self.clockText = text
    end
    local roll = self.clockOld and T.anim((now - (self.clockMs or 0)) / 180) or 1
    local cy = math.floor((self.topH - T.fontH(tf)) / 2)
    local cc = known and T.color.bright or T.color.dim
    if roll >= 1 or #self.clockOld ~= #text then
        T.text(self, text, x, cy, cc, tf)
    else
        local k = 1 - (1 - roll) * (1 - roll)
        local rise = math.floor(T.fontH(tf) * 0.45)
        for i = 1, #text do
            local ch, was = string.sub(text, i, i), string.sub(self.clockOld, i, i)
            local chx = x + T.measure(tf, string.sub(text, 1, i - 1))
            if ch == was then
                T.text(self, ch, chx, cy, cc, tf)
            else
                T.text(self, was, chx, cy - math.floor(rise * k + 0.5), cc, tf, 1 - k)
                T.text(self, ch, chx, cy + math.floor(rise * (1 - k) + 0.5), cc, tf, k)
            end
        end
    end
    x = x + textW
    if date then
        T.text(self, date, x + T.pad, math.floor((self.topH - T.fontH(df)) / 2) + 1, T.color.dim, df)
        x = x + dateW
    end
    if buttons == 0 then return end
    x = x + T.pad * 2
    local now = sc:getCurrentGameSpeed()
    if now > 3 then now = 3 end
    local y = math.floor((self.topH - s) / 2)
    local mx, my = self:getMouseX(), self:getMouseY()
    self.speedRects = {}
    for _, sp in ipairs(SPEEDS) do
        local r = {x, y, s, s, sp}
        local hot = T.inRect(mx, my, r)
        local lit = now == sp
        T.button(self, r, "", {hover = hot})
        if lit then T.rect(self, r[1], r[2], r[3], r[4], T.color.accent) end
        drawSpeedIcon(self, r, sp, lit and {r = 0.08, g = 0.08, b = 0.08} or (hot and T.color.accent or T.color.text))
        table.insert(self.speedRects, r)
        x = x + s + gap
    end
end

function KnoxScreen:onMouseDown(x, y)
    for _, r in ipairs(self.speedRects or {}) do
        if T.inRect(x, y, r) then
            local sc = speedControls()
            if sc then
                -- the game's own buttons, by their names: they set the time multiplier
                -- and the sound with the speed ("Pause" pressed twice would unpause)
                local names = {[1] = "Play", [2] = "Fast Forward x 1", [3] = "Fast Forward x 2"}
                if r[5] == 0 then
                    if sc:getCurrentGameSpeed() ~= 0 then sc:ButtonClicked("Pause") end
                else
                    if sc:getCurrentGameSpeed() == 0 then sc:ButtonClicked("Play") end
                    if r[5] > 1 or sc:getCurrentGameSpeed() ~= 1 then sc:ButtonClicked(names[r[5]]) end
                end
                getSoundManager():playUISound("UIActivateButton")
            end
            return true
        end
    end
    local cx, cy, cw, ch = self:closeRect()
    if x >= cx and x < cx + cw and y >= cy and y < cy + ch then
        self:close()
        return true
    end
    -- the Found button: the window of all that is found
    local fr = self.searchBox and self.searchBox:getIsVisible() and self:foundRect()
    if fr and T.inRect(x, y, fr) then
        KnoxFoundWindow.toggle(self)
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    -- the search field's cross; the field itself takes its clicks (the game's text box)
    if self.searchBox and (self.searchBox:getText() or "") ~= "" and T.inRect(x, y, self:searchClearRect()) then
        self:clearSearch()
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    if T.inRect(x, y, self:searchRect()) and self.searchBox then
        self.searchBox:focus()
        return true
    end
    -- the coin: Boosty in the browser (the author, 2026-10-25)
    if self.coinRect and T.inRect(x, y, self.coinRect) then
        if KnoxPinned then KnoxPinned.openBoosty() end
        return true
    end
    local b = self.brandRect
    if b and T.inRect(x, y, b) then
        self:setTab(self.tab == "News" and "Equipment" or "News")
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    if y < self.topH then
        for _, tr in ipairs(self:tabRects()) do
            if x >= tr.x and x < tr.x + tr.w then
                self:setTab(tr.id)
                return true
            end
        end
    end
    local dx, dy, dw, dh = self:devRect()
    if dx and x >= dx and x < dx + dw and y >= dy and y < dy + dh then
        KnoxTestBench.toggle(self, self.playerNum)
        return true
    end
    local sx, sy, sw0, sh0 = self:settingsRect()
    if x >= sx and x < sx + sw0 and y >= sy and y < sy + sh0 then
        self.settingsPressed = true   -- opened on release (see onMouseUp)
        return true
    end
    KnoxSelect.clear()
    return true
end

function KnoxScreen:onMouseUp(x, y)
    if self.settingsPressed then
        self.settingsPressed = nil
        if KnoxSettings then KnoxSettings.open() end
    end
    return true
end

function KnoxScreen:onMouseUpOutside(x, y)
    self.settingsPressed = nil
end

function KnoxScreen:onRightMouseUp(x, y)
    return true
end

function KnoxScreen:onMouseWheel(del)
    return true
end

-- Esc closes the screen (an open context menu or the split dialog first)
-- instead of bringing up the pause menu; with the screen closed Esc is the game's again.
--
-- Keys the screen keeps from the game while it is open (the game sees no
-- press, no release): R turns the dragged tile instead of reloading the
-- weapon in hand, and the reload / sharpen / sit-on-ground keys do nothing.
-- (Ctrl and the mouse are kept from aiming by the Java part: the game counts
-- the screen as its inventory - KnoxInput.java.)
local KEPT_BINDS = {"RELOAD_WEAPON", "SHARPEN_WEAPON", "SIT_ON_GROUND"}

function KnoxScreen:isKeyConsumed(key)
    if key == Keyboard.KEY_ESCAPE or KnoxControls.isBoundKey(key) then return true end
    for _, name in ipairs(KEPT_BINDS) do
        local id = KeybindId[name]
        if id and getCore():isKey(id, key) then return true end
    end
    return false
end

function KnoxScreen:onKeyPress(key)
    if KnoxSettings and KnoxSettings.instance then return end   -- its keys are the settings window's
    if self:searchFocused() then return end   -- letters typed into the search field
    local act = KnoxControls.keyAction(key)
    -- Knox's own inventory key closes the screen (it is kept from the game while
    -- the screen is open, so the game's key handler doesn't see it)
    if act == "toggle" then
        if getTimestampMs() - (KnoxScreen.openedAt or 0) >= 350 then self:close() end
        return
    end
    if act == "sort" and not KnoxDrag.isActive() then
        -- the grid under the mouse, laid out by the player's rule (as its Sort button)
        for _, v in ipairs(KnoxActions.allViews()) do
            if v:getIsVisible() and v:isMouseOver() and v.layout then
                KnoxActions.sort(v)
                v:markDirty()
                getSoundManager():playUISound("UIActivateButton")
                break
            end
        end
        return
    end
    if act == "rotate" and KnoxDrag.isActive() then KnoxDrag.turn() end
    if act == "lock" and not KnoxDrag.isActive() then
        -- the tile under the mouse, in whichever grid
        for _, v in ipairs(KnoxActions.allViews()) do
            local e = v:getIsVisible() and v:entityUnderMouse()
            if e then
                KnoxActions.toggleLock(e)
                v:markDirty()
                break
            end
        end
    end
end

function KnoxScreen:onKeyRelease(key)
    -- the settings window over the screen: a key being bound there, or Esc closing it, is its own
    if KnoxSettings and KnoxSettings.instance and KnoxSettings.instance:keyReleased(key) then return end
    if key ~= Keyboard.KEY_ESCAPE or KnoxScreen.instance ~= self then return end
    -- the topmost thing goes first: an open context menu, the split dialog, then the screen
    local menu = getPlayerContextMenu(self.playerNum)
    if menu and menu:isAnyVisible() then
        menu:closeAll()
        return
    end
    if KnoxSplitDialog.instance then
        KnoxSplitDialog.instance:close()
        return
    end
    -- then the search: Esc empties the field (being typed in or not); the next one closes
    if self.searchBox and (self:searchFocused() or (self.searchBox:getText() or "") ~= "") then
        self:clearSearch()
        return
    end
    self:close()
end

--- Every item the character carries, bags within bags (a few levels deep).
local function carried(player)
    local out = {}
    local function walk(inv, depth)
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            table.insert(out, it)
            if depth < 4 and instanceof(it, "InventoryContainer") and it:getInventory() then walk(it:getInventory(), depth + 1) end
        end
    end
    walk(player:getInventory(), 1)
    return out
end

-- What the character carried when the screen was last closed (item ids): the
-- things that have come since light up for a few seconds when it opens again.
KnoxScreen.known = KnoxScreen.known or nil

function KnoxScreen:close()
    -- the car's dashboard and the game's hotbar, hidden while the screen is open,
    -- come back first: anything below failing left them gone for the rest of the
    -- game (Aygrol1, 2026-10-20: "my hotbar and car dash are gone")
    self:restoreHidden()
    KnoxScreen.search = nil   -- (a search is for this look into the bags; the next opens clean)
    if KnoxFoundWindow then KnoxFoundWindow.instance = nil end   -- (it goes with the screen)
    -- (no character any more - gone with the game: nothing to remember, the rest still closes)
    local player = self:player()
    if player then
        local known = {}
        for _, it in ipairs(carried(player)) do known[it:getID()] = true end
        KnoxScreen.known = known
    end
    -- an item still held with the mouse goes on being dragged as the game's own
    -- drag, so it can be dropped into another window (a TV's cassette slot...)
    if KnoxDrag.isActive() and isMouseButtonDown(0) then KnoxDrag.handOff() end
    KnoxDrag.cancel()
    KnoxSelect.clear()
    KnoxTooltip.reset()
    if KnoxSplitDialog.instance then KnoxSplitDialog.instance:close() end
    KnoxContainerWindow.closeAll()
    if KnoxDevPanel.instance then KnoxDevPanel.instance:close() end
    KnoxInspectWindow.closeAll()
    KnoxSlotPicker.close()
    if KnoxSettings and KnoxSettings.instance then KnoxSettings.instance:close() end
    -- a right-click menu opened in the screen goes with it (it stayed over the
    -- world, and with Viewpoint the mouse went back to the view under it)
    local menu = getPlayerContextMenu(self.playerNum)
    if menu and menu:isAnyVisible() then menu:hideAndChildren() end
    if KnoxContextMenu then KnoxContextMenu.target = nil end
    self:setVisible(false)
    self:removeFromUIManager()
    if self.dragLayer then self.dragLayer:removeFromUIManager() end
    KnoxScreen.instance = nil
    KnoxScreen.closedAt = getTimestampMs()
    knoxSetScreenOpen(false)
end

--- Open the screen (if closed) on a given surroundings container.
function KnoxScreen.openWith(playerNum, container)
    if not KnoxScreen.instance then KnoxScreen.toggle(playerNum) end
    local s = KnoxScreen.instance
    if s and s.loot and container then
        s:setTab("Equipment")
        s.loot:focus(container)
    end
end

function KnoxScreen.toggle(playerNum)
    playerNum = playerNum or 0
    if KnoxScreen.instance then
        KnoxScreen.instance:close()
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    T.refresh()
    local s = KnoxScreen:new(playerNum)
    KnoxScreen.building = s   -- (taken down again if building it fails: Knox.open)
    s:initialise()
    s:instantiate()
    s:setWantKeyEvents(true)   -- Esc, R (see isKeyConsumed)
    s:addToUIManager()
    knoxSetScreenOpen(true)   -- the game counts it as its inventory: Ctrl and clicks don't aim
    s.dragLayer = KnoxDragLayer:new()
    s.dragLayer:initialise()
    s.dragLayer:addToUIManager()
    -- the game's (or another mod's) hotbar, when Knox doesn't draw it: out of the
    -- way while the screen is open (it has its own quick slots), back when it closes
    if not T.on("hotbar") then
        local hb = getPlayerHotbar(playerNum)
        if hb and hb:getIsVisible() then
            hb:setVisible(false)
            s.hidHotbar = hb
        end
    end
    KnoxScreen.instance = s
    KnoxScreen.building = nil
    KnoxScreen.openedAt = getTimestampMs()
    if KnoxScreen.known then
        local fresh = {}
        local still = {}
        for _, it in ipairs(carried(player)) do
            if not KnoxScreen.known[it:getID()] then table.insert(fresh, it) end
            if KnoxGridView.fresh[it] then still[it] = true end
        end
        -- (a mark of a thing no longer carried - eaten, dropped - goes: the table
        -- held on to every such thing for the rest of the game)
        KnoxGridView.fresh = still
        if #fresh > 0 and #fresh <= 60 then
            KnoxGridView.flashItems(fresh)
            for _, it in ipairs(fresh) do KnoxGridView.fresh[it] = true end
        end
    end
end
