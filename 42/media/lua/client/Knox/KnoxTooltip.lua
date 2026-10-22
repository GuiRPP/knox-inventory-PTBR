-- One item tooltip for the whole screen. Elements ask for it while they draw
-- (KnoxTooltip.want); the drag layer, drawn last, shows or hides it once a frame.

require "ISUI/ISToolTipInv"
require "Knox/KnoxTheme"

KnoxTooltip = KnoxTooltip or {}
local K = KnoxTooltip

K.wanted = nil
K.tip = nil
K.playerNum = 0

function K.want(item, playerNum)
    K.wanted = item
    K.playerNum = playerNum or 0
end

--- Out of the way: no size, at the mouse. A tooltip shown again kept its old
--- place and size for its first frame, and that stale plate was "under the
--- mouse" - over the next tile, which then let the tooltip go: it never came
--- back there (the hammer after the bat), or blinked on and off.
local function shrink(tip)
    tip:setWidth(0)
    tip:setHeight(0)
    tip:setX(getMouseX() + 24)
    tip:setY(getMouseY() + 24)
end

function K.hide()
    if K.tip and K.tip.knoxShown then
        K.tip.knoxShown = false
        K.tip:setVisible(false)
        K.tip:removeFromUIManager()
        shrink(K.tip)
    end
end

-- The tooltip turning into the item's menu (the author's wish, 2026-10-18): the
-- menu opens as wide as the tooltip, its header right over the tooltip's; in
-- one smooth motion the plate takes the menu's height, the menu's plate comes
-- up over the tooltip's lines and its options after it (KnoxContextMenu).
-- (The first try folded the tooltip up to its header, then unfolded the menu:
-- a back-and-forth of a few frames each, ragged - the author.)
K.MORPH_MS = 180

--- 0..1 eased (fast at first, slowing down to rest).
function K.ease(t)
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

--- Start turning the shown tooltip of `item` into a menu; its place, or nil when
--- it isn't showing that item.
function K.startFold(item)
    local tip = K.tip
    if not (tip and tip.knoxShown and tip.item == item and tip.knoxHeadH) then return nil end
    if KnoxTheme.animOn and not KnoxTheme.animOn() then return nil end
    K.fold ={ms = getTimestampMs(), x = tip:getX(), y = tip:getY(), w = tip:getWidth(), h = tip:getHeight(),
              headH = tip.knoxHeadH, item = item}
    return K.fold
end

--- The fold going on, or nil.
local function folding()
    local f = K.fold
    if f and getTimestampMs() - f.ms < K.MORPH_MS then return f end
    K.fold = nil
    return nil
end

--- Called once a frame by the drag layer.
function K.apply()
    local item = K.wanted
    K.wanted = nil
    K.lastHover = item   -- read next frame by the equipment slots (where it would be worn)
    if folding() then return end   -- (it stays up while it folds, under the menu)
    local menu = getPlayerContextMenu(K.playerNum)
    if KnoxDrag and KnoxDrag.isActive() then item = nil end
    if KnoxSplitDialog and KnoxSplitDialog.instance then item = nil end
    if menu and menu:isAnyVisible() then item = nil end
    if not item then
        K.hide()
        return
    end
    local tip = K.tip
    if not tip then
        tip = ISToolTipInv:new(item)
        tip:initialise()
        tip:setCharacter(getSpecificPlayer(K.playerNum))
        K.tip = tip
    end
    -- (a new element counts as visible before it is on screen: whether it was
    -- put there is kept here - the first item hovered after opening the
    -- screen showed no tooltip)
    if tip.item ~= item or not tip.knoxShown then
        tip:setItem(item)
        if not tip.knoxShown then
            shrink(tip)
            tip:addToUIManager()
        end
        tip:setVisible(true)
        tip.knoxShown = true
    end
    tip.followMouse = true
    tip:bringToTop()
end

function K.reset()
    K.hide()
    K.tip = nil
    K.wanted = nil
end

-- Look of every item tooltip ---------------------------------------------------
-- The game builds the contents in Java (item:DoTooltip); with Knox Inventory:
-- Java its text, colors and bars switch to Knox's while knoxTooltipBegin is on
-- (see KnoxTooltipStyle.java). Knox adds its own parts around it:
--   header: the item's icon, its name, "category · size · weight", in a frame
--           of the item's category color (tiles show no names, this does);
--   body:   the game's lines (its own name line left out);
--   footer: key hints.

local T = KnoxTheme
local EDGE = {r = 0x4a / 255, g = 0x4f / 255, b = 0x4f / 255}

local function fontSize()
    T.ensure()
    local opt = getCore():getOptionTooltipFont()
    local s = (opt == "Large" and 1.15) or (opt == "Medium" and 1.05) or 1
    return T.cell * 0.31 * s
end

local function itemName(tip)
    -- the game titles the tooltip with the name as this player knows it
    local chr = tip.tooltip:getCharacter()
    if chr and instanceof(chr, "IsoPlayer") then return tip.item:getName(chr) end
    return tip.item:getName()
end

local function lighten(c, k)
    return {r = c.r + (1 - c.r) * k, g = c.g + (1 - c.g) * k, b = c.b + (1 - c.b) * k}
end

--- The game also shows tooltips of things that are no items with this class
--- (a fluid container's bar, an energy bar): those keep the game's contents.
local function isItem(x)
    return x ~= nil and instanceof(x, "InventoryItem")
end

--- Knox's header and footer need the Java part (v4: the game's name line can be left out).
local function withHeader(item)
    return T.javaFonts and isItem(item)
end

--- One pass of the game's tooltip code (measure or draw), in Knox's style when
--- available; `noTitle`: leave the game's name line out.
--- The item's description (its prose, not its stats), or nil.
local function descriptionOf(item)
    local key = item.getTooltip and item:getTooltip()
    local text = key and key ~= "" and getTextOrNull(key)
    if not text or text == "" then return nil end
    return text
end

local function doTooltip(tip, noTitle, wrapWidth)
    if not tip.item then return false end
    local styled = false
    if T.javaFonts and isItem(tip.item) then
        styled = knoxTooltipBegin("body", "title", fontSize(), itemName(tip))
        if styled and noTitle then
            knoxTooltipHideTitle(true)
            -- a bag not looked into: its tooltip's icons show only what the
            -- character knows is in it (hovering it gave its contents away - the
            -- author, 2026-10-18; the Java part, v47)
            local inv = instanceof(tip.item, "InventoryContainer") and tip.item:getInventory()
            if inv and knoxTooltipKnownOnly and KnoxSearch and KnoxSearch.needs(inv) then knoxTooltipKnownOnly(true) end
            -- the description gets its own block under the stats (drawn here)
            local desc = descriptionOf(tip.item)
            if desc then knoxTooltipDropLine(desc) end
        end
        if styled and wrapWidth then knoxTooltipWrapWidth(wrapWidth) end
    end
    local ok, err = pcall(function() tip.item:DoTooltip(tip.tooltip) end)
    if styled then
        tip.knoxLine = knoxTooltipLine()
        tip.knoxPadY = knoxTooltipPadY()
        knoxTooltipEnd()
    end
    -- (drawn every frame: the same error once, not sixty times a second)
    if not ok and tostring(err) ~= K.lastError then
        K.lastError = tostring(err)
        print("[Knox] tooltip: " .. K.lastError)
    end
    return styled
end

-- the game reads Lua files as single bytes: characters beyond ASCII go through string.char
local TIMES, DOT = string.char(215), string.char(183)   -- × and ·

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

--- Header: icon, name, "category · size · weight"; the name wrapped at
--- `nameW` px (nil: one line).
local function headerFor(item, name, nameW)
    local h = {name = name, nameF = T.fontHeader, subF = T.fontText}
    local cat = item:getDisplayCategory() or ""
    local catName = getTextOrNull("IGUI_ItemCat_" .. cat) or cat
    local fw, fh = KnoxFootprint.get(item)
    local parts = {}
    if catName ~= "" then table.insert(parts, catName) end
    table.insert(parts, fw .. TIMES .. fh)
    -- small things share a tile: how many of this one
    local stack = KnoxGrid.isStackable(item) and KnoxGrid.stackLimit(item) or 1
    if stack > 1 then table.insert(parts, getText("IGUI_Knox_StackOf", stack)) end
    table.insert(parts, round2(KnoxGrid.weightOf(item)) .. " " .. getText("IGUI_Knox_Kg"))
    -- the item's ID, to write in knox_overrides.txt (show_ids = yes there)
    if KnoxFootprint.showIds then table.insert(parts, item:getFullType()) end
    h.sub = table.concat(parts, "  " .. DOT .. "  ")
    h.nameH, h.subH = T.fontH(h.nameF), T.fontH(h.subF)
    h.icon = h.nameH + h.subH
    h.inner = 8
    -- a long name (books, tapes) goes on several lines, at words
    local maxW = nameW or 100000
    h.lines = {}
    local line = ""
    for word in string.gmatch(h.name, "%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if line ~= "" and T.measure(h.nameF, try) > maxW then
            table.insert(h.lines, line)
            line = word
        else
            line = try
        end
    end
    if line ~= "" then table.insert(h.lines, line) end
    local nameW = 0
    for _, l in ipairs(h.lines) do nameW = math.max(nameW, T.measure(h.nameF, l)) end
    h.w = h.inner * 2 + h.icon + 10 + math.max(nameW, T.measure(h.subF, h.sub))
    h.h = math.max(h.icon, #h.lines * h.nameH + h.subH) + h.inner * 2
    h.color = T.category[T.categoryOf(item)]
    -- food: frozen, cooking, done, burning - the plate takes that color, as its tile does
    h.item = item
    return h
end

-- (the tooltip's header is asked two to four times a frame - at the plate's width
-- and to measure it - and holds some thirty calls into the game: kept a moment for
-- the same thing, name and width; its weight or stack text follows within that)
local HEADER_MS = 300
local headers, headersFor, headersMs = {}, nil, 0

local function headerOf(tip, nameW)
    local item, name = tip.item, itemName(tip)
    local now = getTimestampMs()
    if headersFor ~= item or now - headersMs > HEADER_MS or headers.font ~= T.fontHeader or headers.sub ~= T.fontText then
        headers = {font = T.fontHeader, sub = T.fontText}
        headersFor, headersMs = item, now
    end
    local byName = headers[name]
    if not byName then
        byName = {}
        headers[name] = byName
    end
    local key = nameW or false
    local hd = byName[key]
    if not hd then
        hd = headerFor(item, name, nameW)
        byName[key] = hd
    end
    return hd
end

--- The header drawn at bx, by, bw wide (its height: hd.h).
local function drawHeader(ui, hd, bx, by, bw, alpha)
    alpha = alpha or 1
    local bh = hd.h
    local edge = lighten(hd.color, 0.3)
    T.rect(ui, bx, by, bw, bh, hd.color, alpha)
    if hd.item then T.cookBar(ui, bx, by, bw, bh, hd.item, 0.8 * alpha) end
    T.border(ui, bx, by, bw, bh, edge, alpha)
    T.border(ui, bx + 1, by + 1, bw - 2, bh - 2, edge, alpha)
    local ix, iy = bx + hd.inner, by + hd.inner
    ISInventoryItem.renderItemIcon(ui, hd.item, ix, iy, alpha, hd.icon, hd.icon)
    local tx = ix + hd.icon + 10
    local ty = iy
    for _, l in ipairs(hd.lines) do
        T.text(ui, l, tx, ty, T.color.bright, hd.nameF, alpha)
        ty = ty + hd.nameH
    end
    T.text(ui, T.fit(hd.sub, hd.subF, bx + bw - hd.inner - tx), tx, ty, T.color.dim, hd.subF, alpha)
end

-- The same header on other plates: Knox's item menu shows it on top, so the
-- tooltip seems to turn into the menu (the author's wish, 2026-10-18).

--- The header of `item` for a frame `bw` px wide: the name wrapped to fill it,
--- 3 lines at most (the last one cut).
function K.header(item, name, bw)
    local probe = headerFor(item, name, nil)
    local fixed = probe.inner * 2 + probe.icon + 10
    local hd = headerFor(item, name, math.max(40, bw - fixed))
    if #hd.lines > 3 then
        local rest = table.concat(hd.lines, " ", 3)
        hd.lines = {hd.lines[1], hd.lines[2], T.fit(rest, hd.nameF, math.max(40, bw - fixed))}
        hd.h = math.max(hd.icon, 3 * hd.nameH + hd.subH) + hd.inner * 2
    end
    return hd
end

function K.drawHeader(ui, hd, bx, by, bw, alpha)
    drawHeader(ui, hd, bx, by, bw, alpha)
end

--- The plate's width with nothing wide in it, and the space around its parts.
function K.baseWidth()
    local m = math.max(8, math.floor(fontSize() * 0.9 + 0.5))
    return math.floor(fontSize() * 15) + m * 2
end

local hintCache, hintStamp
local function hints()
    -- (the two gestures a tile answers to, as they are bound now: see KnoxControls)
    local stamp = KnoxControls and KnoxControls.stamp or 0
    if not hintCache or hintStamp ~= stamp then
        hintCache, hintStamp = {}, stamp
        local list = {}
        if KnoxControls then
            for _, id in ipairs({"menu", "open"}) do
                local g = KnoxControls.get(id)
                if g ~= "" then table.insert(list, {key = KnoxControls.label(g), label = getText("IGUI_Knox_TipHint_" .. id)}) end
            end
        end
        for _, h in ipairs(list) do
            h.w = T.measure(T.fontTile, h.key) + 10 + 6 + T.measure(T.fontText, h.label)
            table.insert(hintCache, h)
        end
    end
    return hintCache
end

local HINT_GAP = 16

local GAP = 8   -- the same space between the parts: header, lines, line over the hints, hints, bottom
K.GAP = GAP

-- (the notes and the description are wrapped every frame the tooltip is up: kept
-- by text and width; only read, never changed)
local wrapped, wrappedN = {}, 0
local function wrapText(text, font, width)
    local key = (type(font) == "table" and font.key or tostring(font)) .. "|" .. width .. "|" .. text
    local lines = wrapped[key]
    if lines then return lines end
    lines = T.wrap(text, font, width)
    wrappedN = wrappedN + 1
    if wrappedN > 200 then wrapped, wrappedN = {}, 1 end
    wrapped[key] = lines
    return lines
end

local function footerSize()
    local w = 0
    for i, h in ipairs(hints()) do w = w + h.w + (i > 1 and HINT_GAP or 0) end
    return w, GAP + 1 + GAP + T.fontTileH + 4 + GAP
end

--- How wide the item's tooltip is, measured the way it measures itself, without
--- showing it: Knox's item menu takes this width, so its header is the tooltip's
--- however the menu was opened (with the tooltip up or not - they differed, the
--- author 2026-10-18). nil without Knox's header.
local measurer
function K.widthFor(item, playerNum)
    if not withHeader(item) then return nil end
    if not measurer then
        measurer = ISToolTipInv:new(item)
        measurer:initialise()
    end
    local self = measurer
    self:setItem(item)
    self:setCharacter(getSpecificPlayer(playerNum or 0))
    -- (the same steps as the tooltip's render: see ISToolTipInv:render below)
    local m = math.max(8, math.floor(fontSize() * 0.9 + 0.5))
    local footW = footerSize()
    local baseW = math.max(footW + m * 2, math.floor(fontSize() * 15) + m * 2)
    local probe = headerOf(self, nil)
    local fixed = probe.w - math.max(T.measure(probe.nameF, probe.name), T.measure(probe.subF, probe.sub))
    local hd = headerOf(self, baseW - GAP * 2 - fixed)
    if #hd.lines > 3 then hd = headerOf(self, math.floor(fontSize() * 17)) end
    baseW = math.max(baseW, hd.w + GAP * 2)
    self.tooltip:setX(0)
    self.tooltip:setY(0)
    self.tooltip:setWidth(50)
    self.tooltip:setMeasureOnly(true)
    local styled = doTooltip(self, true, baseW - m * 2)
    self.tooltip:setMeasureOnly(false)
    if not styled then return nil end
    return math.max(self.tooltip:getWidth(), baseW)
end

-- Meter rows other mods add under the game's lines ---------------------------
-- Some mods draw a row of their own under the tooltip after it is drawn: on
-- Knox's plate it hung below the frame in the game's look. Knox draws such
-- rows itself, inside the plate, as its own meters, and turns the mod's off.

local LABEL = {r = 0xb9 / 255, g = 0xb6 / 255, b = 0xa8 / 255}   -- the Java part's label color
local METER_FRAME = {r = 0x3c / 255, g = 0x41 / 255, b = 0x41 / 255}
local METER_TRACK = {r = 0x26 / 255, g = 0x2a / 255, b = 0x2a / 255}
local METER_BAD = {r = 0xd9 / 255, g = 0x8a / 255, b = 0x7c / 255}

--- Casualties Undead: a bandage or a rag is a roll, its tooltip shows what is left.
local function cuRows(item, rows)
    local CU = CasualtiesUndead
    local D = CU and CU.Dressing
    if not (D and D.isDressing and D.remaining) then return end
    local ok, dressing = pcall(D.isDressing, item)
    if not ok or not dressing then return end
    local ok2, left = pcall(D.remaining, item)
    if not ok2 or type(left) ~= "number" then return end
    table.insert(rows, {label = getText("Tooltip_CU_DressingLeft"), frac = left})
    -- its own row under the tooltip: off while Knox draws the tooltips
    local tip = CU.DressingTooltip
    if tip and tip.draw and not tip.knoxOff then
        tip.knoxOff = true
        tip.draw = function() end
    end
end

local function extraRows(item)
    local rows = {}
    if isItem(item) then cuRows(item, rows) end
    return rows
end

local function meterColor(f)
    if f >= 0.5 then return T.color.good end
    if f >= 0.25 then return T.color.warn end
    return METER_BAD
end

--- A label and a Knox meter on one line of the plate (like the Java part's bars).
local function drawMeterRow(ui, row, x, y, w)
    local fh = T.fontH(T.fontText)
    local label = row.label or ""
    T.text(ui, label, x, y, LABEL, T.fontText)
    local bx = x + T.measure(T.fontText, label) + 12
    local bw = x + w - bx
    if bw < 20 then return end
    local f = math.max(0, math.min(1, row.frac or 0))
    local bh = math.max(6, math.floor(fh / 3))
    local by = y + math.floor((fh - bh) / 2)
    T.rect(ui, bx, by, bw, bh, METER_FRAME)
    T.rect(ui, bx + 1, by + 1, bw - 2, bh - 2, METER_TRACK)
    local done = math.floor((bw - 2) * f)
    if done > 0 then T.rect(ui, bx + 1, by + 1, done, bh - 2, meterColor(f)) end
end

-- without the Java part the game's tooltips stay as they are (see KnoxTheme.active)
if not T.on("tooltips") then return KnoxTooltip end

local function renderTip(self, fold)
    -- like the game's: no item tooltip while a context menu is up (but while it folds into the menu)
    if not fold and ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return end
    if not self.item then return end

    local mx, my = getMouseX() + 24, getMouseY() + 24
    if not self.followMouse then
        mx, my = self:getX(), self:getY()
        if self.anchorBottomLeft then mx, my = self.anchorBottomLeft.x, self.anchorBottomLeft.y end
    end
    local maxX, maxY = getCore():getScreenWidth(), getCore():getScreenHeight()

    -- width: the key hints or a minimum; the name fills the header at that
    -- width (more lines rather than a wider tooltip, up to 3); the game's lines
    -- and the description are wrapped to fill it too
    local header = withHeader(self.item)
    local m = math.max(8, math.floor(fontSize() * 0.9 + 0.5))   -- the game part's side padding
    local footW, footH = footerSize()
    local baseW = math.max(footW + m * 2, math.floor(fontSize() * 15) + m * 2)
    -- the header at a plate width: the name wrapped to fill its frame (more
    -- lines rather than a wider tooltip, but no more than 3)
    local function headerAt(plateW)
        local probe = headerOf(self, nil)
        local fixed = probe.w - math.max(T.measure(probe.nameF, probe.name), T.measure(probe.subF, probe.sub))
        local h = headerOf(self, plateW - GAP * 2 - fixed)
        if #h.lines > 3 then h = headerOf(self, math.floor(fontSize() * 17)) end
        return h
    end
    local hd
    if header then
        hd = headerAt(baseW)
        baseW = math.max(baseW, hd.w + GAP * 2)
    end
    local wrapW = hd and (baseW - m * 2) or nil
    self.tooltip:setX(0)
    self.tooltip:setY(0)
    self.tooltip:setWidth(50)
    self.tooltip:setMeasureOnly(true)
    local styled = doTooltip(self, header, wrapW)
    self.tooltip:setMeasureOnly(false)
    header = header and styled
    local tw, th = self.tooltip:getWidth(), self.tooltip:getHeight()

    -- plate size: header + the game's lines without their name line and its
    -- bottom padding + footer, the same GAP between all parts
    local W, H, cut, bodyH, desc, descH = tw, th, 0, 0, nil, 0
    local descLineH = T.fontH(T.fontText) + 3
    local rows, rowsH = nil, 0
    if header then
        cut = self.knoxPadY + self.knoxLine + 5                 -- where its lines start under its name
        -- the game's last line ends with its line spacing below the text; cut
        -- it too, so the space under the last line is GAP like everywhere else
        local leading = self.knoxLine - knoxFontHeight("body", fontSize())
        bodyH = math.max(0, th - cut - self.knoxPadY - math.max(0, leading))
        if bodyH < self.knoxLine / 2 then bodyH = 0 end         -- nothing left but the name
        W = math.max(tw, baseW)
        -- a stats line wider than planned widened the plate: refill the header at that width
        if W > baseW then hd = headerAt(W) end
        -- meter rows of other mods, right under the game's lines
        rows = extraRows(self.item)
        if #rows > 0 then
            local leading = descLineH - T.fontH(T.fontText)
            rowsH = #rows * descLineH - leading
            if bodyH > 0 then rowsH = rowsH + leading end
        else
            rows = nil
        end
        -- prose block: the game's notes ("less effective one-handed"...), each
        -- with a sand marker; then, under a thin line of its own, the description
        -- (a marker on its first line too)
        desc = {}
        local leading = descLineH - T.fontH(T.fontText)
        local bullet = math.max(10, math.floor(T.fontH(T.fontText) * 0.6))   -- marker column
        local notesN = 0
        local function addLines(text, color, indent, marker)
            for i, line in ipairs(wrapText(text, T.fontText, W - m * 2 - indent)) do
                table.insert(desc, {text = line, color = color, indent = indent, marker = marker and i == 1})
            end
        end
        local notes = knoxTooltipNotes() or ""
        for note in string.gmatch(notes, "[^\n]+") do
            local r, g, b, text = string.match(note, "^([^;]+);([^;]+);([^;]+);(.*)$")
            if text then
                local c = {r = tonumber(r), g = tonumber(g), b = tonumber(b)}
                -- the game's plain label color reads as our text color
                if math.abs(c.r - 0.725) < 0.03 and math.abs(c.b - 0.659) < 0.03 then c = T.color.text end
                if notesN > 0 then table.insert(desc, {gap = true}) end
                notesN = notesN + 1
                addLines(text, c, bullet, true)
            end
        end
        local text = descriptionOf(self.item)
        if text then
            -- one block (its line breaks fall mid-sentence), the same sand
            -- marker as the notes on its first line
            if notesN > 0 then table.insert(desc, {sep = true}) end
            addLines(text, T.color.text, bullet, true)
        end
        if #desc > 0 then
            for _, l in ipairs(desc) do
                if l.gap then descH = descH + math.floor(descLineH / 2)
                elseif l.sep then descH = descH + GAP - leading + 1 + GAP
                else descH = descH + descLineH end
            end
            descH = descH - leading   -- no line spacing under the last line
            if bodyH + rowsH > 0 then descH = descH + GAP + 1 + GAP end
        else
            desc = nil
        end
        H = GAP + hd.h + GAP + bodyH + rowsH + descH + footH
    end

    -- where: next to the cursor / the menu option, on screen, never under the cursor
    local x, y = mx, my
    if not self.followMouse and self.anchorBottomLeft then y = my - H end
    if self.contextMenu and self.contextMenu.joyfocus then
        local playerNum = self.contextMenu.player
        x, y = getPlayerScreenLeft(playerNum) + 60, getPlayerScreenTop(playerNum) + 60
    elseif self.contextMenu and self.contextMenu.currentOptionRect then
        local r = self.contextMenu.currentOptionRect
        x, y = r.x + r.width + 8, r.y
        if x + W > maxX then x = r.x - W - 8 end
    end
    x = math.max(0, math.min(x, maxX - W - 1))
    y = math.max(0, math.min(y, maxY - H - 1))
    -- a top-level element under the cursor takes the mouse from the tile below
    -- (the game's isMouseOver): the tile dropped the tooltip, the next frame
    -- wanted it again - it flickered and never showed
    local cx, cy = getMouseX(), getMouseY()
    if cx >= x - 4 and cx < x + W + 4 and cy >= y - 4 and cy < y + H + 4 then
        if cx - W - 16 >= 0 then
            x = cx - W - 16
        elseif cy - H - 16 >= 0 then
            y = cy - H - 16
        else
            y = math.min(maxY - H - 1, cy + 24)
        end
    end
    if fold then x, y = fold.x, fold.y end   -- (folding: where it was, the menu lies over it)
    self:setX(x)
    self:setY(y)
    self:setWidth(W)
    self:setHeight(H)

    -- plate: shadow, window color, frame
    self:drawRect(4, 6, W, H, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, W, H, T.color.window, 0.97)
    self:drawRectBorder(0, 0, W, H, 1, EDGE.r, EDGE.g, EDGE.b)

    if not header then
        self.knoxHeadH = nil
        self.tooltip:setX(x)
        self.tooltip:setY(y)
        doTooltip(self, false)
        return
    end
    self.knoxHeadH = GAP + hd.h + GAP   -- (what is left of it when it folds into a menu)

    -- header in the item's category color
    -- (the frame GAP from the plate's edges; its contents line up with the lines below)
    drawHeader(self, hd, GAP, GAP, W - GAP * 2)

    -- the game's lines under it
    self.tooltip:setX(x)
    self.tooltip:setY(y + GAP + hd.h + GAP - cut)
    if bodyH > 0 then doTooltip(self, true, wrapW) end

    -- other mods' meter rows under them
    if rows then
        local ry = GAP + hd.h + GAP + bodyH
        if bodyH > 0 then ry = ry + descLineH - T.fontH(T.fontText) end
        for _, row in ipairs(rows) do
            drawMeterRow(self, row, m, ry, W - m * 2)
            ry = ry + descLineH
        end
    end

    -- the description: its own block, under a thin line when stats come before it
    if desc then
        local dy = GAP + hd.h + GAP + bodyH + rowsH
        if bodyH + rowsH > 0 then
            T.rect(self, GAP, dy + GAP, W - GAP * 2, 1, T.color.border)
            dy = dy + GAP + 1 + GAP
        end
        local leading = descLineH - T.fontH(T.fontText)
        local fh = T.fontH(T.fontText)
        for _, l in ipairs(desc) do
            if l.gap then
                dy = dy + math.floor(descLineH / 2)   -- between notes
            elseif l.sep then
                -- notes above, the description below
                dy = dy + GAP - leading
                T.rect(self, GAP, dy, W - GAP * 2, 1, T.color.border)
                dy = dy + 1 + GAP
            else
                if l.marker then
                    local s = math.max(4, math.floor(fh / 4))
                    T.rect(self, m, dy + math.floor((fh - s) / 2), s, s, T.color.accent)
                end
                T.text(self, l.text, m + (l.indent or 0), dy, l.color, T.fontText)
                dy = dy + descLineH
            end
        end
    end

    -- footer: key hints under a thin line
    local fy = H - footH
    T.rect(self, GAP, fy + GAP, W - GAP * 2, 1, T.color.border)
    local hx = m
    local kh = T.fontTileH + 4
    for _, h in ipairs(hints()) do
        T.keyHint(self, hx, fy + GAP + 1 + GAP, h.key, h.label, kh)
        hx = hx + h.w + HINT_GAP
    end
end

function ISToolTipInv:render()
    local fold = (self == K.tip) and folding() or nil
    if not fold then return renderTip(self, nil) end
    -- turning into the menu: under the menu's plate, cut to the plate's height
    -- as it goes to the menu's (fold.toH, set by the menu)
    local k = K.ease((getTimestampMs() - fold.ms) / K.MORPH_MS)
    local visH = math.floor(fold.h + ((fold.toH or fold.h) - fold.h) * k + 0.5)
    if visH >= fold.h then return renderTip(self, fold) end
    self:setStencilRect(0, 0, fold.w + 8, visH)
    renderTip(self, fold)
    self:drawRect(0, visH - 1, self:getWidth(), 1, 1, EDGE.r, EDGE.g, EDGE.b)
    self:clearStencilRect()
end

return KnoxTooltip