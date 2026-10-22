-- The hero's bag at the fire (the author's idea, 2026-10-16): a hero at the
-- camp of the main menu has taken the backpack off and put it down beside
-- them; the mouse on it brings up a card with what the hero carries - the
-- pockets and every bag worn, as Knox's grids show them in the game, each
-- thing where the player left it.
--
-- While a game runs, every time the hero is written for the menu (see
-- KnoxMenuScene: snapshotOf), the grids of the inventory column are written
-- too - a few lines of text in the save's folder (knox_bag.txt, through the
-- Java part: knoxMenuSaveBag). The menu reads them back (knoxMenuBag): no
-- item of the save is made, only their pictures, names and places are shown.
--
--   KB1
--   S <tab> title <tab> bag type <tab> - <tab> cols <tab> rows <tab> limit <tab> info <tab> slot <tab> rows with overflow
--   I <tab> type <tab> name <tab> icon <tab> x <tab> y <tab> r <tab> w <tab> h <tab> count <tab> category
--     <tab> condition <tab> meter <tab> meter kind <tab> broken <tab> overflow <tab> kg
--
-- (condition and meter: 0..1, -1 when the thing has none; meter kind: u = uses
-- left, f = liquid)

require "ISUI/ISPanel"
require "Knox/KnoxTheme"

local T = KnoxTheme

KnoxMenuBag = {}
local B = KnoxMenuBag

-- Writing (in the game) ---------------------------------------------------------

local function clean(s)
    return (string.gsub(tostring(s or ""), "[\t\r\n]", " "))
end

local function round1(v)
    return math.floor((v or 0) * 10 + 0.5) / 10
end

local function texName(item)
    local tex = item and item:getTex()
    return tex and tex:getName() or ""
end

--- The pockets and every bag worn, in the order the player put them in Knox's
--- inventory when there is one (KnoxInventoryPanel.collectContainers' rule, but
--- only reading: nothing is written on the hero).
local function carried(player)
    local inv = player:getInventory()
    local list = {{container = inv, title = getText("IGUI_Knox_Pockets"), pockets = true}}
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if instanceof(item, "InventoryContainer") and KnoxGrid.isEquippedNow(item, player) and item:getInventory() then
            table.insert(list, {container = item:getInventory(), title = item:getDisplayName(), bag = item})
        end
    end
    local order = player:getModData().knoxOrder
    local rank = {}
    if type(order) == "table" then
        for i, key in ipairs(order) do rank[key] = i end
    end
    for i, c in ipairs(list) do c.rank = rank[KnoxGrid.containerKey(c.container, player)] or (1000 + i) end
    table.sort(list, function(a, b) return a.rank < b.rank end)
    return list
end

--- What the hero carries, as text (nil when Knox's grids aren't there). The
--- grids are worked out as Knox's inventory would lay them out, but nothing is
--- written on the things: a player with the game's own inventory (the in-game
--- module off) has a bag at the fire too (LBBz, 2026-10-16) and their things
--- stay as they were.
function B.capture(player)
    if not (KnoxGrid and KnoxFootprint) then return nil end
    local list = carried(player)
    local back = player:getClothingItem_Back()
    local out = {"KB1"}
    for _, c in ipairs(list) do
        local L = KnoxGrid.build(c.container, player, true)
        local info = KnoxGrid.sizeText(L)
        if not c.pockets then
            info = info .. "  " .. round1(c.container:getCapacityWeight()) .. "/" .. round1(c.container:getEffectiveCapacity(player))
        end
        local slot = (c.bag ~= nil and c.bag == back) and "back" or ""
        -- (field 11: a bag's compartments, KnoxBagShapes - the camp draws them as the inventory does)
        table.insert(out, table.concat({"S", clean(c.title), c.bag and c.bag:getFullType() or "", "-",
            L.cols, L.baseRows or L.rows, L.limit or 0, clean(info), slot, L.rows,
            L.shape and L.shape.spec or ""}, "\t"))
        for _, e in ipairs(L.placed) do
            if not e.ghost and not e.reserved and e.item then
                local it = e.item
                local cond, meter, kind = -1, -1, ""
                if instanceof(it, "HandWeapon") or (instanceof(it, "Clothing") and it:getConditionMax() > 0) then
                    cond = it:getCondition() / math.max(1, it:getConditionMax())
                end
                local broken = it:isBroken()
                if it:IsDrainable() and not broken then
                    local sum = 0
                    for _, x in ipairs(e.items) do sum = sum + x:getCurrentUsesFloat() end
                    meter, kind = sum / math.max(1, #e.items), "u"
                else
                    local fluid = it:getFluidContainer()
                    if fluid and fluid:getCapacity() > 0 then meter, kind = fluid:getAmount() / fluid:getCapacity(), "f" end
                end
                local kg = 0
                for _, x in ipairs(e.items) do kg = kg + KnoxGrid.weightOf(x) end
                table.insert(out, table.concat({"I", it:getFullType(), clean(it:getDisplayName()), texName(it),
                    e.x, e.y, e.r or 0, e.w, e.h, #e.items, T.categoryOf(it),
                    string.format("%.3f", cond), string.format("%.3f", meter), kind,
                    broken and 1 or 0, e.overflow and 1 or 0, string.format("%.2f", kg)}, "\t"))
            end
        end
    end
    return table.concat(out, "\n")
end

--- Written with the hero's snapshot (KnoxMenuScene: snapshotOf) - whether the
--- inventory is Knox's or the game's own (the camp is the menu module's).
function B.write(player)
    if not knoxMenuSaveBag or not player or player:isDead() then return end
    if not T.on("menu") then return end
    local ok, text = pcall(B.capture, player)
    if ok and text then
        knoxMenuSaveBag(text)
    elseif not ok then
        print("[Knox] menu bag: not written: " .. tostring(text))
    end
end

-- Reading (in the menu) ---------------------------------------------------------

local function split(line)
    local f, at = {}, 1
    while true do
        local i = string.find(line, "\t", at, true)
        if not i then
            table.insert(f, string.sub(line, at))
            return f
        end
        table.insert(f, string.sub(line, at, i - 1))
        at = i + 1
    end
end

--- What a save's hero carries: {sections = {...}, back = the section of the
--- bag on the back or nil}, or nil when nothing was written.
function B.read(save)
    local text = knoxMenuBag and knoxMenuBag(save)
    if not text or string.sub(text, 1, 3) ~= "KB1" then return nil end
    local bag = {sections = {}}
    local sec = nil
    for line in string.gmatch(text, "[^\n]+") do
        local f = split(line)
        if f[1] == "S" then
            sec = {title = f[2], type = f[3], cols = tonumber(f[5]) or 1, rows = tonumber(f[6]) or 1,
                   limit = tonumber(f[7]) or 0, info = f[8] or "", slot = f[9] or "", items = {}}
            sec.allRows = math.max(sec.rows, tonumber(f[10]) or sec.rows)
            if sec.limit <= 0 then sec.limit = nil end
            -- (a bag written before compartments: none, one grid as then)
            sec.shape = KnoxBagShapes and KnoxBagShapes.fromSpec(f[11]) or nil
            if sec.shape and (sec.shape.cols ~= sec.cols or sec.shape.rows ~= sec.rows) then sec.shape = nil end
            table.insert(bag.sections, sec)
            if sec.slot == "back" and sec.type ~= "" then bag.back = sec end
        elseif f[1] == "I" and sec then
            table.insert(sec.items, {type = f[2], name = f[3], tex = f[4],
                x = tonumber(f[5]) or 0, y = tonumber(f[6]) or 0, r = tonumber(f[7]) or 0,
                w = tonumber(f[8]) or 1, h = tonumber(f[9]) or 1, n = tonumber(f[10]) or 1, cat = f[11],
                cond = tonumber(f[12]) or -1, meter = tonumber(f[13]) or -1, kind = f[14],
                broken = f[15] == "1", overflow = f[16] == "1", kg = tonumber(f[17]) or 1})
        end
    end
    if #bag.sections == 0 then return nil end
    return bag
end

-- The card ----------------------------------------------------------------------

local CARD_IN_MS, CARD_OUT_MS = 170, 120

local texCache = {}
local function iconOf(name)
    if not name or name == "" then return nil end
    if texCache[name] == nil then texCache[name] = getTexture(name) or false end
    return texCache[name] or nil
end

local function condColor(f)
    if f > 0.6 then return T.color.good end
    if f > 0.25 then return T.color.warn end
    return T.color.bad
end

-- The bag's sound, by what it is made of (the author, 2026-10-16: one zip
-- didn't suit a bag made of a sheet). What it is made of is read from the
-- sound the game gives that bag (the item's OpenSound: OpenBag, OpenSheetSlingBag,
-- OpenLeatherBag, OpenSack...). The game's own sounds can't be heard in the menu
-- - FMOD events its mixer keeps silent there, tried through its own Options
-- preview too - so they are told apart by name and played from the game's
-- files: a zip (PZ_OpenBag / PZ_CloseBag, media/scripts/knox_menu_sounds.txt),
-- or a rustle of cloth (PZ_PutInBag, the Java part: knoxCampSoundCut).
local CLOTH = {"Sheet", "Sack", "Tote", "Fabric", "Satchel", "Hide", "Leather", "Paper", "Plastic", "ToolRoll"}

local function isCloth(name)
    for _, w in ipairs(CLOTH) do
        if string.find(name, w, 1, true) then return true end
    end
    return false
end

local function bagSound(bag, open)
    local back = bag and bag.back
    local script = back and getScriptManager():getItem(back.type)
    local name = script and script:getOpenSound() or ""
    if name ~= "" and isCloth(name) and knoxCampSoundCut then
        -- open: the first rustle, cut short; close: the whole of it, the bag set down
        if knoxCampSoundCut("", open and 0.35 or 0.3, open and 450 or 0) then return end
    end
    getSoundManager():playUISound(open and "KnoxBagOpen" or "KnoxBagClose")
end
B.sound = bagSound   -- (a keepsake put back into a bag: KnoxMenuScene)

KnoxBagCard = ISPanel:derive("KnoxBagCard")
local BC = KnoxBagCard

function BC:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.k = 0
    return o
end

-- A tile under the mouse lifts as in Knox's inventory (KnoxGridView: up or
-- down in LIFT_MS, a small hop over the rise in HOP_MS, cell * 0.05 high).
local LIFT_MS, HOP_MS = 110, 200

function BC:updateLift()
    local now = getTimestampMs()
    self.lifts = self.lifts or {}
    local hov = (not T.animOn or T.animOn()) and self.hovered or nil
    if hov then
        local st = self.lifts[hov]
        if not st then
            st = {k = 0, ms = now}
            self.lifts[hov] = st
        end
        if st.want ~= 1 then st.want, st.hop = 1, now end
    end
    for it, st in pairs(self.lifts) do
        if it ~= hov then st.want = 0 end
        local step = math.min(100, now - st.ms) / LIFT_MS
        st.ms = now
        if st.k < st.want then st.k = math.min(st.want, st.k + step) else st.k = math.max(st.want, st.k - step) end
        if st.k <= 0 and st.want == 0 then self.lifts[it] = nil end
    end
end

function BC:liftPx(it, cs)
    local st = self.lifts and self.lifts[it]
    if not st then return 0 end
    local k = st.k * st.k * (3 - 2 * st.k)
    local hop = 0
    if st.want == 1 and st.hop then
        local t = (getTimestampMs() - st.hop) / HOP_MS
        if t < 1 then hop = 0.7 * math.sin(math.pi * t) end
    end
    return math.floor(math.max(2, cs * 0.05) * (k + hop) + 0.5)
end

--- Lays the card out for the bag shown: the head, then the sections flowing
--- down in columns. Cells smaller than the inventory's (a look, not a place
--- to work: at Knox's own size the card was too big - the author, 2026-10-16),
--- smaller still when it doesn't fit on the screen.
function BC:layout()
    T.ensure()
    local bag = self.bag
    local pad = T.pad
    local sw = self.sceneW or getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local f = 4
    local headH = T.fontH(T.fontHeader) + T.fontTileH + 4
    local maxH = math.floor(sh * 0.78) - headH - pad * 3 - f * 2
    local maxW = math.floor(sw * 0.8)
    local L
    -- (1: too big, 0.6: too small - the author, 2026-10-16; the middle)
    for _, k in ipairs({0.8, 0.7, 0.6, 0.52, 0.45, 0.4}) do
        local cs = math.max(16, math.floor(T.cell * k))
        local cols, colX, colY, colW = {}, f + pad, 0, 0
        local blocks = {}
        local x, y, w = f + pad, f + pad + headH + pad, 0
        local top = y
        local bottomMax = y
        for _, s in ipairs(bag.sections) do
            local bw = math.max(s.cols * cs, cs * 3)
            local bh = T.sectionH + s.allRows * cs
            if s.shape then
                local g = KnoxBagShapes.geometry(s.shape, cs)
                bw = math.max(g.w, s.shape.ovCols * cs, cs * 3)
                bh = T.sectionH + (s.allRows > s.rows and (g.ovY + (s.allRows - s.rows) * cs) or g.h)
            end
            if y > top and y + bh > top + maxH then
                x = x + w + pad
                y, w = top, 0
            end
            table.insert(blocks, {s = s, x = x, y = y, w = bw, h = bh})
            y = y + bh + pad
            w = math.max(w, bw)
            bottomMax = math.max(bottomMax, y)
        end
        local totalW = x + w + pad + f
        L = {cs = cs, frame = f, blocks = blocks, w = totalW, h = bottomMax + f, headH = headH}
        if totalW <= maxW and bottomMax - top <= maxH + pad then break end
    end
    L.w = math.max(L.w, math.floor(T.cell * 4.3))
    self.L = L
    return L
end

--- Open for the bag at screen rect r (a click on it: KnoxMenuScene).
function BC.open(r, sceneW, bag, hero, save)
    local card = BC.instance
    if not card then
        card = BC:new()
        card:initialise()
        card:instantiate()
        card:addToUIManager()
        card:setAlwaysOnTop(true)
        card:setVisible(false)
        BC.instance = card
    end
    card.bagRect, card.sceneW, card.hero, card.save = r, sceneW, hero, save
    card.bag = bag
    card.L = nil
    card.shownAt, card.goneAt = getTimestampMs(), nil
    card:setVisible(true)
    card:bringToTop()
    bagSound(bag, true)
end

--- Where the bag is now (the camera breathes): the card stays by it.
function BC.follow(r, sceneW)
    local card = BC.instance
    if card then card.bagRect, card.sceneW = r, sceneW end
end

--- Goes, fading.
function BC.close()
    local card = BC.instance
    if not card or not card.shownAt then return end
    card.shownAt = nil
    card.goneAt, card.goneK = getTimestampMs(), card.k
    bagSound(card.bag, false)
end

--- Is the card up (the scene keeps the bag lit meanwhile)?
function BC.isUp()
    local card = BC.instance
    return card ~= nil and card:getIsVisible() and card.shownAt ~= nil
end

--- Is the mouse on the card?
function BC.isMouseOn()
    local card = BC.instance
    return card ~= nil and card:getIsVisible() and card:isMouseOver()
end

function BC.hide()
    local card = BC.instance
    if not card then return end
    card.shownAt, card.goneAt = nil, nil
    card:setVisible(false)
end

function BC.destroy()
    local card = BC.instance
    if card then card:removeFromUIManager() end
    BC.instance = nil
end

function BC:place()
    local L = self.L or self:layout()
    local r = self.bagRect
    if not r then return end
    local pad = T.pad
    local sw = self.sceneW or getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local x = math.floor(r[1] + r[3] / 2 - L.w / 2)
    x = math.max(pad, math.min(sw - L.w - pad, x))
    local y = math.floor(r[2] - L.h - pad)
    if y < pad then y = math.floor(r[2] + r[4] + pad) end
    y = math.max(pad, math.min(sh - L.h - pad, y))
    self:setX(x)
    self:setWidth(L.w)
    self:setHeight(L.h)
    self:setY(y + math.floor(math.floor(T.cell * 0.28) * (1 - self.k) + 0.5))
end

--- One section: its header strip and its grid, the things in it.
function BC:drawSection(b, a, mx, my)
    local s, cs = b.s, self.L.cs
    local x, y, w = b.x, b.y, b.w
    local gw = s.shape and math.max(KnoxBagShapes.geometry(s.shape, cs).w, cs * 3) or s.cols * cs
    T.rect(self, x, y, gw, T.sectionH, T.color.header, a)
    local ft = T.fontH(T.fontText)
    local ty = y + math.floor((T.sectionH - ft) / 2)
    T.textRight(self, s.info, x + gw - 6, ty, T.color.dim, T.fontText, a)
    local infoW = T.measure(T.fontText, s.info)
    T.text(self, T.fit(T.upper(s.title), T.fontCaps, gw - infoW - 18), x + 8,
        y + math.floor((T.sectionH - T.fontH(T.fontCaps)) / 2), T.color.text, T.fontCaps, a)

    -- the grid: cells, lines; a last row not whole (the pockets) as Knox draws it
    local gy = y + T.sectionH
    local line = T.color.line
    local la = T.gridLineAlpha() * a
    local base = s.rows
    local sg = s.shape and KnoxBagShapes.geometry(s.shape, cs)
    if sg then
        -- a bag with compartments, as the inventory draws it (KnoxGridView.drawShape)
        KnoxGridView.drawShape(self, x, gy, s.shape, cs, nil, a, a)
        if s.allRows > base then
            local ox, ow, oh = x + sg.ovX, sg.ovW, (s.allRows - base) * cs
            T.rect(self, ox, gy + sg.ovY, ow, oh, T.color.cell, a)
            for i = 0, s.shape.ovCols do self:drawRect(ox + i * cs, gy + sg.ovY, 1, oh + 1, la, line.r, line.g, line.b) end
            for j = 0, s.allRows - base do self:drawRect(ox, gy + sg.ovY + j * cs, ow + 1, 1, la, line.r, line.g, line.b) end
            KnoxGridView.drawOverflow(self, ox, gy + sg.ovY, ow, oh, a)
        end
    elseif not s.limit then
        T.rect(self, x, gy, gw, base * cs, T.color.cell, a)
        for i = 0, s.cols do self:drawRect(x + i * cs, gy, 1, base * cs + 1, la, line.r, line.g, line.b) end
        for j = 0, base do self:drawRect(x, gy + j * cs, gw + 1, 1, la, line.r, line.g, line.b) end
    else
        local whole = math.floor(s.limit / s.cols)
        local part = s.limit - whole * s.cols
        T.rect(self, x, gy, gw, whole * cs, T.color.cell, a)
        if part > 0 then T.rect(self, x, gy + whole * cs, part * cs, cs, T.color.cell, a) end
        for i = 0, s.cols do
            self:drawRect(x + i * cs, gy, 1, (i <= part and part > 0) and (whole + 1) * cs + 1 or whole * cs + 1, la, line.r, line.g, line.b)
        end
        for j = 0, whole do self:drawRect(x, gy + j * cs, gw + 1, 1, la, line.r, line.g, line.b) end
        if part > 0 then self:drawRect(x, gy + (whole + 1) * cs, part * cs + 1, 1, la, line.r, line.g, line.b) end
    end
    if s.allRows > base and not sg then
        T.rect(self, x, gy + base * cs, gw, (s.allRows - base) * cs, T.color.cell, a)
        KnoxGridView.drawOverflow(self, x, gy + base * cs, gw, (s.allRows - base) * cs, a)
    end

    -- the things
    local hovered = nil
    local f, fh = T.fontTile, T.fontTileH
    local held = KnoxMenuKeep and KnoxMenuKeep.drag
    for _, it in ipairs(s.items) do
        local w2, h2 = it.w, it.h
        if it.r == 1 then w2, h2 = it.h, it.w end
        local tx, ty2 = x + it.x * cs + 1, gy + it.y * cs + 1
        if sg then
            -- (in its compartment; one written in a cell that is no cell of the bag
            -- any more - an old save - goes where the rows of what doesn't fit are)
            local cx, cy = KnoxBagShapes.cellPx(s.shape, cs, it.x, it.y, base)
            if not cx then cx, cy = KnoxBagShapes.cellPx(s.shape, cs, 0, base, base) end
            tx, ty2 = x + cx + 1, gy + cy + 1
        end
        local pw, ph = w2 * cs - 1, h2 * cs - 1
        local over = not held and mx >= tx and mx < tx + pw and my >= ty2 and my < ty2 + ph
        if over then hovered = it end
        -- can it be put down in the camp (a model of it on the ground)? If not, dimmed
        if it.model == nil then it.model = (KnoxMenuKeep and KnoxMenuKeep.modelOf(it.type)) or false end
        local ia = it.model and a or a * 0.45
        local taken = held and held.tile == it
        local ta = taken and a * 0.4 or a
        -- lifted under the mouse as in the inventory (KnoxGridView.liftPx): a
        -- soft shadow where it lies, the tile above it
        local lp = self:liftPx(it, cs)
        if lp > 0 then
            self:drawRect(tx + 2, ty2 + 3, pw - 2, ph - 2, 0.35 * a, 0, 0, 0)
            ty2 = ty2 - lp
        end
        T.rect(self, tx, ty2, pw, ph, T.category[it.cat] or T.category.misc, ta)
        if over then self:drawRect(tx, ty2, pw, ph, 0.06 * a, 1, 1, 1) end
        if taken then
            -- taken out (its likeness on its way to the camp): a sand frame, as a thing being moved
            T.tileFrame(self, tx, ty2, pw, ph, T.color.accent, 0.9 * a)
            ia = ia * 0.4
        else
            T.tileFrame(self, tx, ty2, pw, ph, it.overflow and T.color.bad or (over and T.color.tileHover or T.color.tileFrame), a)
        end
        it.rect = {tx, ty2 + lp, pw, ph}
        local tex = iconOf(it.tex)
        if tex then
            local side = math.floor(math.min(pw, ph) * 0.85)
            self:drawTextureScaledAspect(tex, tx + math.floor((pw - side) / 2), ty2 + math.floor((ph - side) / 2), side, side, ia, 1, 1, 1)
        end
        local level = 0
        if it.cond >= 0 then
            T.tileMeter(self, tx, ty2, pw, ph, it.cond, condColor(it.cond), ta, 0)
            level = 1
        end
        if it.meter >= 0 then
            T.tileMeter(self, tx, ty2, pw, ph, it.meter, it.kind == "f" and T.color.liquid or T.color.accent, ta, level)
        end
        if it.broken then
            T.outlinedRight(self, "0%", tx + pw - 4, ty2 + ph - fh - 3, T.color.bad, f, ta)
        elseif it.n > 1 then
            T.outlinedRight(self, tostring(it.n), tx + pw - 4, ty2 + ph - fh - 3, T.color.bright, f, ta)
        end
    end
    return hovered
end

function BC:prerender()
    local now = getTimestampMs()
    if self.shownAt then
        local t = math.max(0, math.min(1, T.anim((now - self.shownAt) / CARD_IN_MS)))
        self.k = 1 - (1 - t) * (1 - t)
    elseif self.goneAt then
        local t = math.min(1, T.anim((now - self.goneAt) / CARD_OUT_MS))
        self.k = (self.goneK or 1) * (1 - t)
        if t >= 1 then
            self.goneAt = nil
            self:setVisible(false)
            return
        end
    end
    if not self.bag then return end
    if not self.L then self:layout() end
    self:place()
    local L = self.L
    local a = self.k
    local w, h, pad, f = L.w, L.h, T.pad, L.frame
    local mx, my = self:getMouseX(), self:getMouseY()
    if not self:isMouseOver() then mx, my = -1, -1 end

    -- the window and its sand frame, as the radio's card and a hero's
    T.rect(self, 0, 0, w, h, T.color.window, 0.96 * a)
    T.rect(self, 0, 0, w, f, T.color.accent, a)
    T.rect(self, 0, h - f, w, f, T.color.accent, a)
    T.rect(self, 0, f, f, h - f * 2, T.color.accent, a)
    T.rect(self, w - f, f, f, h - f * 2, T.color.accent, a)

    -- head: what this is, whose
    local hy = f + pad
    T.text(self, T.upper(getText("IGUI_Knox_MenuBag")), f + pad, hy, T.color.accent, T.fontCaps, a)
    T.text(self, T.fit(self.hero or "", T.fontHeader, w - (f + pad) * 2), f + pad, hy + T.fontTileH + 4, T.color.bright, T.fontHeader, a)

    self:updateLift()
    local hovered = nil
    for _, b in ipairs(L.blocks) do
        local hv = self:drawSection(b, a, mx, my)
        if hv then hovered = hv end
    end
    self.hovered = hovered
    -- a thing taken out and carried off the card: the card steps aside for the camp
    local d = KnoxMenuKeep and KnoxMenuKeep.drag
    if d and d.tile and self.shownAt and not self:isMouseOver() then BC.close() end
end

--- The name of the thing under the mouse, on a plate by it (drawn last, over the grids),
--- and what dragging it does.
function BC:render()
    local it = self.hovered
    if not it or self.k < 0.5 then return end
    local s = it.name .. (it.n > 1 and ("  x" .. it.n) or "")
    if KnoxMenuKeep then
        local hint = not it.model and "IGUI_Knox_Keep_NoModel"
            or (KnoxMenuKeep.full() and "IGUI_Knox_Keep_Full" or "IGUI_Knox_Keep_Drag")
        s = s .. "  " .. string.char(183) .. "  " .. getText(hint)
    end
    local font = T.fontText
    local tw, th = T.measure(font, s), T.fontH(font)
    local pad = math.floor(T.pad / 2)
    local x = self:getMouseX() + 14
    local y = self:getMouseY() + 18
    local bw, bh = tw + pad * 2, th + pad * 2
    if x + bw > self:getWidth() then x = self:getMouseX() - bw - 6 end
    if y + bh > self:getHeight() then y = self:getMouseY() - bh - 6 end
    T.rect(self, x, y, bw, bh, T.color.header, 0.97)
    T.border(self, x, y, bw, bh, T.color.accent, 1)
    T.text(self, s, x + pad, y + pad, T.color.bright, font, 1)
end

-- the card stays where it is under the mouse: the scene's clicks go elsewhere.
-- A thing pressed on is taken out to be put down in the camp - its likeness:
-- the thing itself stays in the bag (KnoxMenuKeep); the card steps aside.
function BC:onMouseDown(x, y)
    local it = self.hovered
    if it and it.model and it.rect and KnoxMenuKeep and KnoxMenuKeep.beginDrag(it, self.hero, self.save) then
        -- held where it was taken, as in the inventory (KnoxDrag: grab point)
        local d = KnoxMenuKeep.drag
        local r = it.rect
        d.tile, d.tex, d.cat, d.kg = it, it.tex, it.cat, it.kg or 1
        d.pw, d.ph = r[3], r[4]
        d.grabX, d.grabY = x - r[1], y - r[2]
        KnoxKeepDragLayer.ensure()
    end
    return true
end

-- The tile in hand -----------------------------------------------------------------
-- While carried over the card (or where it can't lie), the tile follows the
-- mouse as in Knox's inventory: a weight on a spring, a heavy thing lagging and
-- swaying (KnoxDragLayer:follow). Over the camp's ground its 3D likeness lies
-- there instead (KnoxMenuScene: updateKeeps) and the tile fades.

KnoxKeepDragLayer = ISUIElement:derive("KnoxKeepDragLayer")
local DL = KnoxKeepDragLayer

function DL.ensure()
    if DL.instance then return end
    local o = ISUIElement:new(0, 0, 1, 1)
    setmetatable(o, DL)
    DL.__index = DL
    o:initialise()
    o:instantiate()
    o:addToUIManager()
    o:setAlwaysOnTop(true)
    DL.instance = o
end

function DL:prerender()
    self:bringToTop()
end

function DL:follow(d)
    local mx, my = getMouseX(), getMouseY()
    if T.animOn and not T.animOn() then return mx, my end
    local now = getTimestampMs()
    local st = self.inertia
    if not st or st.d ~= d then
        -- (the inventory's spring: a bandage close behind, an axe lagging, a pack swinging)
        local omega = math.max(7, math.min(32, 32 / math.sqrt(1 + (d.kg or 1) * 0.7)))
        st = {d = d, px = mx, py = my, vx = 0, vy = 0, ms = now, omega = omega, zeta = 0.56, k = 1}
        self.inertia = st
    end
    local dt = math.min(0.05, (now - st.ms) / 1000)
    st.ms = now
    local steps = math.max(1, math.ceil(dt / 0.008))
    local h = dt / steps
    local om, z = st.omega, st.zeta
    for _ = 1, steps do
        st.vx = st.vx + (om * om * (mx - st.px) - 2 * z * om * st.vx) * h
        st.vy = st.vy + (om * om * (my - st.py) - 2 * z * om * st.vy) * h
        st.px = st.px + st.vx * h
        st.py = st.py + st.vy * h
    end
    -- fades while its likeness lies on the ground, comes back off it
    local want = d.onGround and 0 or 1
    st.k = st.k + (want - st.k) * math.min(1, dt * 14)
    return math.floor(st.px + 0.5), math.floor(st.py + 0.5), st.k
end

function DL:render()
    local d = KnoxMenuKeep and KnoxMenuKeep.drag
    if not d or not d.tile then
        self.inertia = nil
        return
    end
    local fx, fy, k = self:follow(d)
    if k < 0.02 then return end
    local x, y = fx - (d.grabX or 0), fy - (d.grabY or 0)
    local pw, ph = d.pw or 32, d.ph or 32
    T.rect(self, x, y, pw, ph, T.category[d.cat] or T.category.misc, 0.85 * k)
    T.border(self, x, y, pw, ph, T.color.accent, k)
    local tex = iconOf(d.tex)
    if tex then
        local side = math.floor(math.min(pw, ph) * 0.72)
        self:drawTextureScaledAspect(tex, x + math.floor((pw - side) / 2), y + math.floor((ph - side) / 2), side, side, 0.9 * k, 1, 1, 1)
    end
end
function BC:onMouseUp(x, y) return true end
function BC:onRightMouseDown(x, y) return true end
function BC:onRightMouseUp(x, y) return true end
