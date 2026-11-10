-- The menu order editor (the author, 2026-11-10: "an editor to change the default order of the
-- context menu's options right in the game"; "only for me - what I change is the mod's default
-- for every player"; "a reset for one option and for the whole menu - needed"; no mockup).
--
-- DEV mode only: right-click an item > "Menu order". The window shows that item's menu as Knox
-- lays it out - the top without a title, the groups, the red ones at the bottom - and its
-- options and groups are dragged with the mouse. Every change is written at once into the
-- mod (KnoxContextMenu.saveOrder: media/knox/menu_order.txt) and is in force at once.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxContextMenu"
require "Knox/KnoxWindowDrag"

KnoxMenuOrder = ISPanel:derive("KnoxMenuOrder")
local O = KnoxMenuOrder
local T = KnoxTheme
local K = KnoxContextMenu
local W = KnoxWindowDrag

O.RESET_SURE_MS = 3000   -- "Reset all": a second press within this asks no more

local function devOn()
    return KnoxTestBench ~= nil and KnoxTestBench.devOn ~= nil and KnoxTestBench.devOn()
end

-- (drawn every frame: the band and the label options are filled in, not made anew)
local band = {0, 0, 0, 0}
local tileOpts = {font = nil}
local textOpts = {font = nil, a = 1}
local rowBtn, allBtn = {hover = false}, {hover = false}
local function setBand(x, y, w, h)
    band[1], band[2], band[3], band[4] = x, y, w, h
    return band
end

local function titleOf(key)
    if key == "top" then return getText("IGUI_Knox_MO_Top") end
    if key == "danger" then return getText("IGUI_Knox_MO_Danger") end
    return getText(K.GROUP_TITLE[key] or key)
end

-- Opening ---------------------------------------------------------------------------

function O:new(snap, playerNum)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.moveWithMouse = false
    o.headName = snap.head.name
    o.headItem = snap.head.item
    -- where each option stands in the game's own order (for "As it was" and the marks)
    o.gameSec, o.gameIdx = {}, {}
    for _, sec in ipairs(snap.game) do
        for n, row in ipairs(sec.rows) do
            o.gameSec[row.id], o.gameIdx[row.id] = sec.key, n
        end
    end
    o.secs = snap.now
    o.scroll = 0
    return o
end

function O.open(menu, playerNum)
    local snap = K.orderSnapshot(menu)
    if not snap then return end
    -- (its own option is not one of the menu's)
    local own = "text:" .. getText("IGUI_Knox_MO_Open")
    for _, list in ipairs({snap.now, snap.game}) do
        for _, sec in ipairs(list) do
            for n = #sec.rows, 1, -1 do
                if sec.rows[n].id == own then table.remove(sec.rows, n) end
            end
        end
    end
    if O.instance then O.instance:close() end
    local w = O:new(snap, playerNum)
    w:initialise()
    w:addToUIManager()
    w:setAlwaysOnTop(true)
    O.instance = w
end

function O:createChildren()
    local c, pad = T.cell, T.pad
    self.headerH = T.sectionH + 4
    self.rowH = math.floor(c * 0.5)
    self.secH = T.fontH(T.fontTile) + pad
    local w = math.floor(c * 7)
    self:setWidth(w)
    self.hint = T.wrap(getText("IGUI_Knox_MO_Hint"), T.fontText, w - pad * 2)
    self.footH = (T.fontH(T.fontText) + 2) * #self.hint + T.fontH(T.fontTile) + pad * 3 + self.headerH
    self:relayout()
    local h = math.min(getCore():getScreenHeight() - 40, self.headerH + pad + self.contentH + pad + self.footH)
    self:setHeight(h)
    self:setX(math.floor((getCore():getScreenWidth() - w) / 2))
    self:setY(math.floor((getCore():getScreenHeight() - h) / 2))
end

-- Layout (made when something changes, not every frame) --------------------------------

--- Is the option out of its place in the game's order: in another section, or before or
--- after one of the game's own options of its section the other way round than the game has it.
function O:changed(sec, id)
    if self.gameSec[id] ~= sec.key then return true end
    local mine = self.gameIdx[id]
    local seen = false
    for _, row in ipairs(sec.rows) do
        if row.id == id then
            seen = true
        elseif self.gameSec[row.id] == sec.key then
            local was = self.gameIdx[row.id]
            if (not seen and was > mine) or (seen and was < mine) then return true end
        end
    end
    return false
end

function O:relayout()
    local pad = T.pad
    local L = {}
    local y = 0
    for si, sec in ipairs(self.secs) do
        local movable = sec.key ~= "top" and sec.key ~= "danger"
        table.insert(L, {kind = "sec", si = si, y = y, h = self.secH, key = sec.key, movable = movable,
                         title = T.upper(titleOf(sec.key))})
        y = y + self.secH
        if #sec.rows == 0 then
            table.insert(L, {kind = "empty", si = si, idx = 1, y = y, h = self.rowH})
            y = y + self.rowH
        end
        for n, row in ipairs(sec.rows) do
            table.insert(L, {kind = "row", si = si, idx = n, y = y, h = self.rowH, row = row,
                             changed = self:changed(sec, row.id)})
            y = y + self.rowH
        end
        y = y + math.floor(pad / 2)
    end
    self.L = L
    self.contentH = y
    self.resetW = T.buttonW(getText("IGUI_Knox_MO_Reset"), T.fontTile)
end

-- Changes ---------------------------------------------------------------------------

--- Write what the window shows into the author's order: this menu's options in their
--- sections and places, the options of other menus already listed kept after them.
function O:save()
    local mine = {}
    for _, sec in ipairs(self.secs) do
        for _, row in ipairs(sec.rows) do mine[row.id] = true end
    end
    local lists, groups = {}, {}
    for _, sec in ipairs(self.secs) do
        local list = {}
        for _, row in ipairs(sec.rows) do table.insert(list, row.id) end
        for _, id in ipairs(K.order.lists[sec.key] or {}) do
            if not mine[id] then table.insert(list, id) end
        end
        lists[sec.key] = list
        if sec.key ~= "top" and sec.key ~= "danger" then table.insert(groups, sec.key) end
    end
    K.order = {groups = groups, lists = lists}
    self.saveFailed = not K.saveOrder()
    self:relayout()
end

function O:moveRow(fromSi, fromIdx, toSi, toIdx)
    local row = table.remove(self.secs[fromSi].rows, fromIdx)
    if not row then return end
    if fromSi == toSi and toIdx > fromIdx then toIdx = toIdx - 1 end
    local rows = self.secs[toSi].rows
    toIdx = math.max(1, math.min(#rows + 1, toIdx))
    table.insert(rows, toIdx, row)
    self:save()
end

function O:moveGroup(fromSi, toSi)
    if fromSi == toSi then return end
    local sec = table.remove(self.secs, fromSi)
    if toSi > fromSi then toSi = toSi - 1 end
    -- (between the top and the red ones only)
    toSi = math.max(2, math.min(#self.secs, toSi))
    table.insert(self.secs, toSi, sec)
    self:save()
end

--- "As it was" for one option: back to its section of the game's order, among the game's
--- own options there at its place.
function O:resetRow(si, idx)
    local row = table.remove(self.secs[si].rows, idx)
    if not row then return end
    local key = self.gameSec[row.id]
    local dest = nil
    for _, sec in ipairs(self.secs) do
        if sec.key == key then dest = sec end
    end
    dest = dest or self.secs[si]
    local at = #dest.rows + 1
    for n, r in ipairs(dest.rows) do
        if self.gameSec[r.id] == key and self.gameIdx[r.id] > self.gameIdx[row.id] then
            at = n
            break
        end
    end
    table.insert(dest.rows, at, row)
    self:save()
end

--- "Reset all": the author's order gone - every menu as the game's own again.
function O:resetAll()
    K.order = {groups = nil, lists = {}}
    self.saveFailed = not K.saveOrder()
    local byKey = {}
    for _, sec in ipairs(self.secs) do
        for _, row in ipairs(sec.rows) do byKey[row.id] = row end
    end
    local secs = {}
    for _, key in ipairs(K.SECTIONS) do
        local sec = {key = key, rows = {}}
        for id, row in pairs(byKey) do
            if self.gameSec[id] == key then table.insert(sec.rows, row) end
        end
        table.sort(sec.rows, function(a, b) return self.gameIdx[a.id] < self.gameIdx[b.id] end)
        table.insert(secs, sec)
    end
    self.secs = secs
    self:relayout()
end

-- Places on the window -----------------------------------------------------------------

function O:listTop() return self.headerH + T.pad end
function O:listBottom() return self:getHeight() - self.footH end

function O:closeRect()
    local s = self.headerH - 8
    return {self:getWidth() - s - 4, 4, s, s}
end

local allRect, rowRect = {0, 0, 0, 0}, {0, 0, 0, 0}   -- (filled in: asked every frame)

function O:resetAllRect()
    local text = getText(self.sureUntil and getTimestampMs() < self.sureUntil and "IGUI_Knox_MO_ResetAllSure" or "IGUI_Knox_MO_ResetAll")
    local bw = T.buttonW(text)
    allRect[1], allRect[2], allRect[3], allRect[4] = self:getWidth() - T.pad - bw, self:getHeight() - T.pad - self.headerH, bw, self.headerH
    return allRect, text
end

--- (screen y of a layout entry)
function O:yOf(e) return self:listTop() + e.y - self.scroll end

function O:shown(e)
    local y = self:yOf(e)
    return y >= self:listTop() - 1 and y + e.h <= self:listBottom() + 1
end

function O:rowResetRect(e)
    rowRect[1], rowRect[2], rowRect[3], rowRect[4] = self:getWidth() - T.pad - self.resetW, self:yOf(e) + 3, self.resetW, e.h - 6
    return rowRect
end

--- Where a dragged option would go for the mouse at y: section and place, and the line's y.
function O:dropAt(y)
    local best = nil
    for _, e in ipairs(self.L) do
        local ey = self:yOf(e)
        if y >= ey and y < ey + e.h then best = e end
    end
    if not best then
        local last = self.L[#self.L]
        if last and y >= self:yOf(last) then best = last end
        if not best then best = self.L[1] end
    end
    if not best then return nil end
    local ey = self:yOf(best)
    if best.kind == "sec" or best.kind == "empty" then
        return best.si, 1, ey + best.h
    end
    if y < ey + best.h / 2 then return best.si, best.idx, ey end
    return best.si, best.idx + 1, ey + best.h
end

--- Where a dragged group would go: before the movable group under the mouse (or after the last).
function O:groupDropAt(y)
    local target, lineY = nil, nil
    for _, e in ipairs(self.L) do
        if e.kind == "sec" and (e.movable or e.key == "danger") then
            local ey = self:yOf(e)
            if not target or y >= ey - self.rowH / 2 then target, lineY = e.si, ey end
        end
    end
    return target, lineY
end

-- Drawing ---------------------------------------------------------------------------

function O:prerender()
    local w, h, pad = self:getWidth(), self:getHeight(), T.pad
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local fc = T.fontH(T.fontCaps)
    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, self.headerH, T.color.header)
    T.tileFrame(self, 0, 0, w, h, T.color.accent)
    T.caps(self, T.fit(getText("IGUI_Knox_MO_Title") .. "  " .. tostring(self.headName), T.fontCaps, w - self.headerH - 16),
        8, math.floor((self.headerH - fc) / 2), T.color.bright)
    local cr = self:closeRect()
    T.closeButton(self, cr[1], cr[2], cr[3], over and T.inRect(mx, my, cr))

    local top, bottom = self:listTop(), self:listBottom()
    self:setStencilRect(0, top, w, bottom - top)
    local drag = self.drag
    for _, e in ipairs(self.L) do
        if self:shown(e) then
            local y = self:yOf(e)
            if e.kind == "sec" then
                local hot = e.movable and over and not drag and my >= y and my < y + e.h
                local c = (drag and drag.kind == "group" and drag.si == e.si) and T.color.dim
                    or (hot and T.color.accent or T.color.dim)
                tileOpts.font = T.fontTile
                local tw = T.label(self, e.title, setBand(pad, y, w - pad * 2, e.h - 2), c, tileOpts)
                T.rect(self, pad + tw + 6, y + e.h - 3, w - pad * 2 - tw - 6, 1, T.color.tileEdge)
            elseif e.kind == "empty" then
                tileOpts.font = T.fontTile
                T.label(self, getText("IGUI_Knox_MO_Empty"), setBand(pad + 8, y, w - pad * 2, e.h), T.color.dim, tileOpts)
            else
                local lifted = drag and drag.kind == "row" and drag.si == e.si and drag.idx == e.idx
                local hot = over and not drag and my >= y and my < y + e.h
                T.rect(self, pad, y + 1, w - pad * 2, e.h - 2, hot and T.color.header or T.color.cell, lifted and 0.4 or 1)
                local s = e.h - 8
                if e.row.icon then
                    local tint = e.changed and T.color.accent or T.color.text
                    self:drawTextureScaledAspect(e.row.icon, pad + 6, y + 4, s, s, lifted and 0.4 or 1, tint.r, tint.g, tint.b)
                end
                local nameW = w - pad * 2 - s - 18 - (e.changed and self.resetW + 6 or 0)
                local danger = self.secs[e.si].key == "danger"
                local c = danger and T.color.bad or (e.changed and T.color.accent or T.color.text)
                textOpts.font, textOpts.a = T.fontText, lifted and 0.4 or 1
                T.label(self, T.fit(e.row.name, T.fontText, nameW), setBand(pad + s + 14, y, nameW, e.h), c, textOpts)
                if e.changed then
                    local rr = self:rowResetRect(e)
                    rowBtn.hover, rowBtn.font = hot and T.inRect(mx, my, rr), T.fontTile
                    T.button(self, rr, getText("IGUI_Knox_MO_Reset"), rowBtn)
                end
            end
        end
    end
    -- where the dragged one would go: a sand line
    if drag and drag.lineY then
        T.rect(self, pad, drag.lineY - 1, w - pad * 2, 2, T.color.accent)
    end
    self:clearStencilRect()

    -- the foot: what to do, and "Reset all"
    local fy = bottom + pad
    for _, l in ipairs(self.hint) do
        T.text(self, l, pad, fy, T.color.dim, T.fontText)
        fy = fy + T.fontH(T.fontText) + 2
    end
    if self.saveFailed then T.text(self, getText("IGUI_Knox_MO_NoFile"), pad, fy, T.color.bad, T.fontTile) end
    local rr, text = self:resetAllRect()
    allBtn.hover = over and T.inRect(mx, my, rr)
    T.button(self, rr, text, allBtn)
end

-- Mouse ------------------------------------------------------------------------------

function O:onMouseDown(x, y)
    if T.inRect(x, y, self:closeRect()) then
        self:close()
        return true
    end
    local rr = self:resetAllRect()
    if T.inRect(x, y, rr) then
        if self.sureUntil and getTimestampMs() < self.sureUntil then
            self.sureUntil = nil
            self:resetAll()
        else
            self.sureUntil = getTimestampMs() + O.RESET_SURE_MS
        end
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    if y >= self:listTop() and y < self:listBottom() then
        for _, e in ipairs(self.L) do
            local ey = self:yOf(e)
            if self:shown(e) and y >= ey and y < ey + e.h then
                if e.kind == "row" then
                    if e.changed and T.inRect(x, y, self:rowResetRect(e)) then
                        self:resetRow(e.si, e.idx)
                        getSoundManager():playUISound("UIActivateButton")
                        return true
                    end
                    self.drag = {kind = "row", si = e.si, idx = e.idx}
                    return true
                elseif e.kind == "sec" and e.movable then
                    self.drag = {kind = "group", si = e.si}
                    return true
                end
            end
        end
    end
    W.begin(self, x, y, self.headerH)
    return true
end

function O:trackDrag()
    local d = self.drag
    if not d then return end
    local y = self:getMouseY()
    -- (near the edges the list scrolls)
    local top, bottom = self:listTop(), self:listBottom()
    if y < top + 10 then self:scrollBy(-self.rowH / 2) elseif y > bottom - 10 then self:scrollBy(self.rowH / 2) end
    if d.kind == "row" then
        d.toSi, d.toIdx, d.lineY = self:dropAt(y)
    else
        d.toSi, d.lineY = self:groupDropAt(y)
    end
end

function O:onMouseMove(dx, dy)
    W.update(self)
    self:trackDrag()
    return true
end

function O:onMouseMoveOutside(dx, dy)
    W.update(self)
    self:trackDrag()
    return true
end

function O:finishDrag()
    local d = self.drag
    self.drag = nil
    if not d or not d.toSi then return end
    if d.kind == "row" then
        if not (d.toSi == d.si and (d.toIdx == d.idx or d.toIdx == d.idx + 1)) then
            self:moveRow(d.si, d.idx, d.toSi, d.toIdx)
            getSoundManager():playUISound("UIActivateButton")
        end
    else
        self:moveGroup(d.si, d.toSi)
        getSoundManager():playUISound("UIActivateButton")
    end
end

function O:onMouseUp(x, y)
    W.stop(self)
    self:finishDrag()
    return true
end

function O:onMouseUpOutside(x, y)
    W.stop(self)
    self:finishDrag()
    return true
end

function O:scrollBy(d)
    local most = math.max(0, self.contentH - (self:listBottom() - self:listTop()))
    self.scroll = math.max(0, math.min(most, math.floor(self.scroll + d)))
end

function O:onMouseWheel(del)
    self:scrollBy(del * self.rowH)
    return true
end

function O:onRightMouseUp(x, y) return true end

function O:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if O.instance == self then O.instance = nil end
end

-- The option in item menus ---------------------------------------------------------------

local function onFillMenu(playerNum, context, items)
    if not devOn() then return end
    local opt = context:addOption(getText("IGUI_Knox_MO_Open"), context, function(menu) O.open(menu, playerNum) end)
    opt.knoxIconKey = "sort"
end

Events.OnFillInventoryObjectContextMenu.Add(onFillMenu)

return O
