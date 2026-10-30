-- Knox's crosshair panel live in a news post ("@vp", "@vp fridge", "@art vp"; the author,
-- 2026-10-25: "a news post in the same style as before - a fitting backdrop, an interactive
-- window"). The panel itself (KnoxCrosshair: its rows, growth, search, bag, transfers,
-- keys at the foot) on a pretend world: a kitchen cupboard with a backpack in it, or a
-- fridge and its freezer. Nothing of the game is touched - no player, no things, no
-- Viewpoint: the pretend world answers what the panel asks (P.src).
--   the wheel over the plate      chooses a row (as Viewpoint's wheel)
--   a click on a row               chooses it; on the chosen row - the take key:
--                                  a thing goes; on a bag, short - looks into it,
--                                  held - takes the bag
--   a click on a key at the foot   that key (take, take all; the window's - only a click)
--   a click on the crosshair       looks away (the plate folds into it) and back
-- Things are found one by one when it opens (Knox's search), taken things fold away;
-- emptied, the cupboard fills again a moment later. Placed by the news reader each
-- frame (hostAt) as the generator's and the dashboard's demos are; an error is a line
-- in console.txt and the demo hides - never the game's error window over the news.

require "ISUI/ISUIElement"
require "Knox/KnoxTheme"
require "Knox/KnoxCrosshair"

KnoxCrosshairDemo = ISUIElement:derive("KnoxCrosshairDemo")
local D = KnoxCrosshairDemo
local P = KnoxCrosshair
local T = KnoxTheme

local SEARCH_MS = 420      -- a thing found every
local TAKE_MS = 380        -- a thing on its way
local REFILL_MS = 2200     -- emptied: filled again after
local HIDE_MS = 150        -- not placed for this long: hidden (the reader moved on)

-- The pretend world ------------------------------------------------------------------------

-- (a list as the game's Java ones: size, get from 0)
local LIST = {}
LIST.__index = LIST
local function list(t) return setmetatable({t = t or {}}, LIST) end
function LIST:size() return #self.t end
function LIST:get(i) return self.t[i + 1] end

local ITEM = {}
ITEM.__index = ITEM
function ITEM:getName() return self.name end
function ITEM:isHidden() return false end
function ITEM:getID() return self.id end
function ITEM:getInventory() return self.inv end

local BOX = {}
BOX.__index = BOX
function BOX:getItems() return self.items end
function BOX:getType() return self.type end

-- What each pretend place holds: {name, icon, category, kg[, the bag's things]} (the
-- names are the mod's own strings: no item scripts in the main menu)
local PLACES = {
    cupboard = {
        {type = "counter", tex = "media/ui/Container_Counter.png", title = "Cupboard", things = {
            {"Backpack", "Item_Backpack_Teal", "clo", 0.6, {
                {"Torch", "Item_Flashlight", "tool", 0.5}, {"Battery", "Item_Battery", "tool", 0.1},
                {"Battery", "Item_Battery", "tool", 0.1}, {"Bandage", "Item_Bandage", "med", 0.1},
                {"Pills", "Item_PillsPainkiller", "med", 0.2}}},
            {"Apple", "Item_Apple", "food", 0.2}, {"Apple", "Item_Apple", "food", 0.2},
            {"Beans", "Item_Beans", "food", 0.6}, {"Knife", "Item_KnifeChopping", "wpn", 0.8},
            {"Magazine", "Item_Magazine", "info", 0.1}, {"Water", "Item_WaterBottle", "food", 0.6}}},
    },
    fridge = {
        {type = "fridge", tex = "media/ui/Container_Fridge.png", title = "Fridge", things = {
            {"Sausage", "Item_Sausage", "food", 0.2}, {"Steak", "Item_Steak", "food", 0.3},
            {"Steak", "Item_Steak", "food", 0.3}, {"Cucumber", "Item_Cucumber", "food", 0.2},
            {"Dinner", "Item_TVDinner", "food", 0.4}, {"Water", "Item_WaterBottle", "food", 0.6}}},
        {type = "freezer", tex = "media/ui/Container_Freezer.png", title = "Freezer", things = {
            {"Steak", "Item_Steak", "food", 0.3}, {"Beans", "Item_Beans", "food", 0.6}}},
    },
}

local nextId = 1
local texOf = {}
local function icon(name)
    local t = texOf[name]
    if t == nil then
        t = getTexture(name) or false
        texOf[name] = t
    end
    return t or nil
end

local function thing(d, owner)
    nextId = nextId + 1
    local it = setmetatable({name = getText("IGUI_Knox_VPDemo_" .. d[1]), tex = d[2], cat = d[3], kg = d[4],
                             id = nextId, owner = owner}, ITEM)
    if d[5] then
        it.inv = setmetatable({type = "bag", items = list()}, BOX)
        for _, q in ipairs(d[5]) do table.insert(it.inv.items.t, thing(q, it.inv)) end
    end
    return it
end

--- The place filled as it was (nothing searched yet).
local function fill(w)
    w.boxes = {}
    for _, b in ipairs(PLACES[w.which] or PLACES.cupboard) do
        local box = setmetatable({type = b.type, tex = b.tex, title = getText("IGUI_Knox_VPDemo_" .. b.title),
                                  items = list()}, BOX)
        for _, d in ipairs(b.things) do table.insert(box.items.t, thing(d, box)) end
        table.insert(w.boxes, box)
    end
    w.list = list(w.boxes)
    w.seen, w.found = {}, 0
    w.queue = {}
    w.cur, w.since = nil, 0
    w.emptyMs = nil
end

local function removeFrom(box, it)
    local t = box.items.t
    for i = #t, 1, -1 do
        if t[i] == it then table.remove(t, i) return end
    end
end

-- The source the panel asks (as KnoxCrosshair's LIVE, on the pretend world) -----------------

local function makeSrc(w, demo)
    local src = {}
    local function needs(c)
        if not c then return false end
        for _, it in ipairs(c.items.t) do
            if not w.seen[it] then return true end
        end
        return false
    end
    function src.kind() return 3 end
    function src.containers() return w.list end
    function src.loot() return true end
    function src.locked() return false end
    function src.square() return nil end
    function src.title(c) return c and c.title or nil end
    function src.actions() return 0 end
    function src.actionLabel() return "" end
    function src.actionOn() return false end
    function src.actionsTitle() return "" end
    function src.actionsVersion() return 0 end
    function src.actionFn() return nil end
    function src.actionItem() return nil end
    function src.actionFirst() return false end
    function src.actionGroup() return nil end
    function src.actionProgress() return 0 end
    function src.run() end
    function src.wheel()
        local n = demo.wheelN or 0
        demo.wheelN = 0
        return n
    end
    function src.pressed()
        local n = demo.press or 0
        demo.press = 0
        return n
    end
    function src.held() return demo.pressing == true and isMouseButtonDown(0) end
    function src.isBag(it) return it.inv ~= nil end
    function src.weight(it) return it.kg end
    function src.category(it) return it.cat end
    function src.icon(ui, it, x, y, a, s)
        local t = icon(it.tex)
        if t then ui:drawTextureScaledAspect(t, x, y, s, s, a, 1, 1, 1) end
    end
    function src.containerIcon(c) return c and icon(c.tex) or nil end
    function src.groundItems() return list() end
    function src.groundCount() return 0 end
    function src.unseen(it) return not w.seen[it] end
    function src.busy(c) return c ~= nil and w.cur == c and needs(c) end
    src.needs = needs
    function src.searchFrac(c)
        if w.cur ~= c then return 1 end
        return math.min(1, (getTimestampMs() - w.since) / SEARCH_MS)
    end
    function src.searchSig() return w.found end
    -- a bag looked into first, then the place's containers in turn; a thing found every SEARCH_MS
    function src.search()
        local want = nil
        for bag, st in pairs(P.bags) do
            if st.to and bag.inv and needs(bag.inv) then want = bag.inv break end
        end
        if not want then
            for _, c in ipairs(w.boxes) do
                if needs(c) then want = c break end
            end
        end
        local now = getTimestampMs()
        if want ~= w.cur then w.cur, w.since = want, now end
        if not want or now - w.since < SEARCH_MS then return end
        for _, it in ipairs(want.items.t) do
            if not w.seen[it] then
                w.seen[it], w.found = true, w.found + 1
                break
            end
        end
        w.since = now
    end
    function src.pending(it) return it.p end
    function src.grab(player, items)
        for _, it in ipairs(items) do
            if not it.p then
                it.p = 0
                table.insert(w.queue, it)
            end
        end
    end
    function src.cancel(player, it)
        it.p, it.start = nil, nil
        for i = #w.queue, 1, -1 do
            if w.queue[i] == it then table.remove(w.queue, i) end
        end
    end
    return src
end

--- The world's own time: things on their way arrive (one after another), an emptied place fills again.
local function tick(w, now)
    local it = w.queue[1]
    if it then
        it.start = it.start or now
        it.p = math.min(1, (now - it.start) / TAKE_MS)
        if it.p >= 1 then
            table.remove(w.queue, 1)
            removeFrom(it.owner, it)
            it.p = nil
        end
    end
    local empty = #w.queue == 0
    for _, b in ipairs(w.boxes) do
        if #b.items.t > 0 then empty = false end
    end
    if not empty then
        w.emptyMs = nil
    elseif not w.emptyMs then
        w.emptyMs = now
    elseif now - w.emptyMs >= REFILL_MS then
        fill(w)
        return true
    end
    return false
end

-- The demo -----------------------------------------------------------------------------------

function D:new(which)
    local o = ISUIElement:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.world = {which = which}
    fill(o.world)
    o.st = {}
    o.clip = {0, 0, 0, 0}
    return o
end

--- The state the panel starts a plate with (P.reset's, kept in o.st while not drawn).
function D:fresh(now)
    P.swap(self.st)
    P.src = makeSrc(self.world, self)
    P.reset(now)
    P.target, P.visible = {}, true
    P.swap(self.st)
end

--- The demo of a post's "@vp [place]" line (or the art's) in a window that shows news:
--- made once per window and line (`key`), kept for its later frames.
function P.newsDemo(host, key, which)
    host.knoxVpDemos = host.knoxVpDemos or {}
    local d = host.knoxVpDemos[key]
    if not d then
        d = D:new(which == "fridge" and "fridge" or "cupboard")
        d:initialise()
        d:instantiate()
        host.knoxVpDemos[key] = d
    end
    return d
end

--- How big: the crosshair, the plate's way from it and the widest plate; as tall as the
--- plate can get (its list scrolled at its most, the keys under it) - the post's text
--- doesn't move as the plate grows and shrinks.
function D:demoSize(maxW)
    P.sizes()
    local Z = P.Z
    self.cx = Z.SRC
    self.ox = self.cx + Z.AWAY
    local labels = #self.world.boxes > 1 and Z.LABEL or 0
    local h = Z.GAP + Z.PH_SUB + Z.GAP + Z.MAXV * Z.ROW + labels + Z.GROW_H + Z.GAP + 1 + Z.GAP + Z.KH + Z.GAP
    self.w, self.h = self.ox + Z.MAXW, h
    self:setWidth(self.w)
    self:setHeight(self.h)
    return self.w, self.h
end

--- Each frame of the window it stands in: at x, y of `host`, shown in its view {x, y, w, h}.
function D:hostAt(host, x, y, view)
    if self.host ~= host then
        host:addChild(self)
        self.host = host
    end
    if self.broken then
        self:setVisible(false)
        return
    end
    self:setX(x)
    self:setY(y)
    local c = self.clip
    local x0, y0 = math.max(view[1], x), math.max(view[2], y)
    local x1, y1 = math.min(view[1] + view[3], x + self.w), math.min(view[2] + view[4], y + self.h)
    c[1], c[2], c[3], c[4] = x0 - x, y0 - y, math.max(0, x1 - x0), math.max(0, y1 - y0)
    self.placedAt = getTimestampMs()
    self:setVisible(c[3] > 0 and c[4] > 0)
end

--- Is something going on in it (things being found or taken): the post's backdrop
--- lights with it (KnoxNewsBack "aim").
function D:busy()
    local w = self.world
    if #w.queue > 0 then return true end
    for _, b in ipairs(w.boxes) do
        for _, it in ipairs(b.items.t) do
            if not w.seen[it] then return self.st.visible == true end
        end
    end
    return false
end

-- The crosshair it unfolds out of: four short strokes round a dot, as a sight's
local function crosshair(ui, x, y, s, a)
    local c = T.color.bright
    local g, l = math.max(2, math.floor(s * 0.25)), math.max(3, math.floor(s * 0.5))
    ui:drawRect(x - 1, y - 1, 2, 2, a, c.r, c.g, c.b)
    ui:drawRect(x - g - l, y - 1, l, 2, a, c.r, c.g, c.b)
    ui:drawRect(x + g, y - 1, l, 2, a, c.r, c.g, c.b)
    ui:drawRect(x - 1, y - g - l, 2, l, a, c.r, c.g, c.b)
    ui:drawRect(x - 1, y + g, 2, l, a, c.r, c.g, c.b)
end

function D:frame(now)
    local w = self.world
    P.sizes()
    local Z = P.Z
    local dt = math.min(100, now - (P.ms or now))
    P.ms = now
    if tick(w, now) then P.dirty, P.seen = true, {} end   -- (filled again: its things enter anew)
    local cy = math.floor(Z.GAP + Z.PH_SUB / 2 + 0.5) + Z.ROW
    local c = self.clip
    P.pushClip(self, c[1], c[2], c[3], c[4])
    crosshair(self, self.cx, cy, Z.SRC, self.away and 0.5 or 0.85)
    if self.away then
        -- looked away: the plate folds back into the crosshair
        P.drawGhost(self, now)
        P.popClip(self)
        return
    end
    P.step(nil, now, dt)
    P.paint(self, self.ox, 0, self.cx, cy, now)
    P.popClip(self)
end

function D:render()
    local now = getTimestampMs()
    if self.broken or now - (self.placedAt or 0) > HIDE_MS then
        self:setVisible(false)
        self.goneMs = self.goneMs or now
        return
    end
    -- (back after a while away - scrolled out of the post, the post closed: it unfolds again)
    if not self.st.src or (self.goneMs and now - self.goneMs > 1000) then self:fresh(now) end
    self.goneMs = nil
    P.swap(self.st)
    local ok, err = pcall(self.frame, self, now)
    if not ok then P.clearClips(self) end
    P.swap(self.st)
    if not ok then
        print("[Knox] the news' crosshair panel stopped: " .. tostring(err))
        self.broken = true
        self:setVisible(false)
    end
end

-- Input --------------------------------------------------------------------------------------

function D:inClip(x, y)
    local c = self.clip
    return x >= c[1] and y >= c[2] and x < c[1] + c[3] and y < c[2] + c[4]
end

--- Is (x, y) on the plate (as last drawn)?
function D:onPlate(x, y)
    local b = self.st.box
    return not self.away and b ~= nil and self:inClip(x, y) and x >= b.x and y >= b.y and x < b.x + b.W and y < b.y + b.H
end

--- A press off its shown part goes to the window it stands in (the news).
function D:toHost(fn, x, y)
    local h = self.host
    if not (h and h[fn]) then return false end
    h[fn](h, x + self:getX(), y + self:getY())
    return true
end

--- The row of the plate at (x, y): its index among the rows the wheel stops on, or nil.
function D:rowAt(x, y)
    local st = self.st
    local L, b = st.L, st.box
    if not L or not b or not L.viewY then return nil end
    for i, r in ipairs(st.pick) do
        local ry = r.region == "list" and (b.y + L.viewY + r.y - math.floor(st.scroll + 0.5)) or (b.y + r.y)
        local inView = r.region ~= "list" or (y >= b.y + L.viewY and y < b.y + L.viewY + L.viewH)
        if inView and y >= ry and y < ry + (r.h or 0) then return i end
    end
    return nil
end

--- The key at the foot under (x, y): its name as shown, or nil.
function D:keyAt(x, y)
    local st = self.st
    local L, b = st.L, st.box
    if not L or not L.hasFoot or not b then return nil end
    local ky = b.y + L.footY + 1 + P.Z.GAP
    if y < ky - 2 or y >= ky + P.Z.KH + 2 then return nil end
    for i = 1, st.hintCount or 0 do
        local x0, x1 = st.hintAt[i * 2 - 1], st.hintAt[i * 2]
        if x0 and x >= x0 and x < x1 then return st.shownKeys[i] end
    end
    return nil
end

function D:onMouseWheel(del)
    if self:onPlate(self:getMouseX(), self:getMouseY()) then
        self.wheelN = (self.wheelN or 0) + (del > 0 and 1 or -1)
        return true
    end
    if self.host and self.host.onMouseWheel then return self.host:onMouseWheel(del) end
    return false
end

function D:onMouseDown(x, y)
    if not self:inClip(x, y) then return self:toHost("onMouseDown", x, y) end
    local Z = P.Z
    local cy = math.floor(Z.GAP + Z.PH_SUB / 2 + 0.5) + Z.ROW
    if math.abs(x - self.cx) <= Z.SRC and math.abs(y - cy) <= Z.SRC then
        -- the crosshair: look away, and back
        self.away = not self.away
        if self.away then
            local st = self.st
            if st.box then st.ghost = st.box st.ghost.ms = getTimestampMs() end
        else
            self:fresh(getTimestampMs())
        end
        getSoundManager():playUISound("UIActivateButton")
        return true
    end
    if not self:onPlate(x, y) then return self:toHost("onMouseDown", x, y) end
    local key = self:keyAt(x, y)
    if key then
        if key == P.keys.take then self.press, self.pressing = 1, true
        elseif key == P.keys.all then self.press = 2
        else getSoundManager():playUISound("UIActivateButton") end
        return true
    end
    local i = self:rowAt(x, y)
    if i then
        if i == self.st.sel then
            self.press, self.pressing = 1, true
        else
            self.st.sel = i
        end
    end
    return true
end

function D:onMouseUp(x, y)
    self.pressing = false
    return true
end

function D:onMouseUpOutside(x, y)
    self.pressing = false
    return true
end

return KnoxCrosshairDemo
