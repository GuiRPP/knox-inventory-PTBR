-- The filming mode (the author's wish, 2026-10-15): the 1.0 video's scenes, one
-- after another, in the game itself. Each scene says what to film and what the
-- voice says, and has buttons that set it up (a messy backpack, a generator in
-- the hands, a pot of water, two bodies...). A row of tools makes the shot clean:
-- midday, clear weather, no zombies around, no damage, the game's own windows
-- for a while (to compare). While the mode is on there is no DEV button.
--
-- Home shows and hides the panel (hidden, nothing of it is in the shot); its
-- cross ends the mode. Only where Zomboid/Lua/knox_dev.txt is, or with -debug.
-- The scenes are in 42/media/knox/studio_ru.txt (see its header); "filmed" marks
-- go to Zomboid/Lua/knox_studio.txt. Things it makes are the test bench's
-- (KnoxTestBench: "Clean up" takes them away).

require "ISUI/ISPanel"
require "Knox/KnoxTheme"
require "Knox/KnoxWindowDrag"
require "Knox/KnoxTestBench"

KnoxStudio = ISPanel:derive("KnoxStudio")
local S = KnoxStudio
local T = KnoxTheme
local B = KnoxTestBench
local MOD_ID = T.MOD_ID
local MARKS = "knox_studio.txt"

S.active = false     -- the mode is on (the panel shown or hidden)
S.done = S.done or {}
S.god = false

-- The scenes ---------------------------------------------------------------------

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

--- {chapter = {n, title}, title, actions = {ids}, shot, voice, id} for each scene.
function S.load()
    local r = getModFileReader(MOD_ID, "media/knox/studio_ru.txt", false)
    local scenes, chapter, cur, field = {}, nil, nil, nil
    local count = {}
    if r then
        local line = r:readLine()
        while line do
            line = string.gsub(line, "\r", "")
            local c1 = string.sub(line, 1, 1)
            if c1 == ";" then
                -- a comment
            elseif c1 == "=" then
                local n, title = string.match(line, "^=%s*(%d+)%s*|%s*(.-)%s*$")
                chapter = {n = tonumber(n) or 0, title = title or ""}
                field = nil
            elseif c1 == "#" then
                local ch = chapter or {n = 0, title = ""}
                count[ch.n] = (count[ch.n] or 0) + 1
                cur = {chapter = ch, title = trim(string.sub(line, 2)), actions = {}, shot = "", voice = "",
                       id = ch.n .. "." .. count[ch.n]}
                table.insert(scenes, cur)
                field = nil
            elseif cur and c1 == "@" then
                for a in string.gmatch(string.sub(line, 2), "[%w_]+") do table.insert(cur.actions, a) end
            elseif cur and c1 == ">" then
                field = "shot"
                cur.shot = trim(string.sub(line, 2))
            elseif cur and c1 == "~" then
                field = "voice"
                cur.voice = trim(string.sub(line, 2))
            elseif cur and field and trim(line) ~= "" then
                cur[field] = cur[field] .. " " .. trim(line)
            end
            line = r:readLine()
        end
        r:close()
    end
    S.scenes = scenes
end

local function loadMarks()
    S.done = {}
    local r = getFileReader(MARKS, false)
    if not r then return end
    local line = r:readLine()
    while line do
        local id = string.match(line, "^([%d%.]+)|1")
        if id then S.done[id] = true end
        line = r:readLine()
    end
    r:close()
end

local function saveMarks()
    local w = getFileWriter(MARKS, true, false)
    if not w then return end
    for _, sc in ipairs(S.scenes or {}) do
        if S.done[sc.id] then w:write(sc.id .. "|1\r\n") end
    end
    w:close()
end

-- What the buttons do ------------------------------------------------------------

local function exists(ft) return ft and getScriptManager():FindItem(ft) ~= nil end
local function first(list)
    for _, ft in ipairs(list) do if exists(ft) then return ft end end
    return nil
end
local function tag(item)
    if item then item:getModData().knoxBench = true end
    return item
end
local function give(player, list)
    local ft = type(list) == "table" and first(list) or (exists(list) and list or nil)
    return ft and tag(player:getInventory():AddItem(ft)) or nil
end
local function dirty()
    if KnoxScreen and KnoxScreen.instance then KnoxScreen.instance:markAllDirty() end
    if KnoxLootPanel then KnoxLootPanel.dirty = true end
end
--- Something lying on the floor by the character (the bench's "Clean up" takes it away).
local function onFloor(player, ft)
    local sq = player:getCurrentSquare()
    if not sq or not exists(ft) then return nil end
    local it = sq:AddWorldInventoryItem(ft, ZombRandFloat(0.3, 0.7), ZombRandFloat(0.3, 0.7), 0)
    if it then table.insert(B.dumped, tag(it)) end
    return it
end
local function settingsPage(page)
    if not KnoxSettings then return end
    KnoxSettings.lastPage = page
    if KnoxSettings.instance then KnoxSettings.instance:close() end
    KnoxSettings.open()
end
local function fluidOf(item)
    return item and item.getFluidContainer and item:getFluidContainer() or nil
end

S.ACTIONS = {
    -- the clean shot
    Day = function() getGameTime():setTimeOfDay(12.0) end,
    Clear = function() pcall(function() getClimateManager():stopWeatherAndThunder() end) end,
    NoZombies = function(p)
        local list = getCell():getZombieList()
        for i = list:size() - 1, 0, -1 do
            local z = list:get(i)
            if z and math.abs(z:getX() - p:getX()) < 70 and math.abs(z:getY() - p:getY()) < 70 then
                z:removeFromWorld()
                z:removeFromSquare()
            end
        end
    end,
    God = function(p)
        S.god = not S.god
        p:setGodMod(S.god)
    end,
    Vanilla = function()
        Knox.vanillaShot = not Knox.vanillaShot
        if Knox.vanillaShot and KnoxScreen.instance then KnoxScreen.instance:close() end
    end,
    Cleanup = function(p)
        B.cleanup(p)
        B.removeBodies()
    end,
    -- the bench's scenes
    Prepare = function(p, n) B.prepare(p, n) end,
    Shuffle = function(p) B.shuffle(p) end,
    Take3 = function(p) B.take3(p) end,
    Back3 = function(p) B.back3(p) end,
    Bandages = function(p) B.bandages(p) end,
    Generator = function(p) B.generator(p) end,
    WaterPot = function(p) B.waterPot(p) end,
    TwoBodies = function(p) B.twoBodies(p) end,
    Hammer = function(p) B.addHammer(p) end,
    Tent = function(p, n) B.tent(p, n) end,
    -- the filming's own
    HotPot = function(p)
        local it = give(p, "Base.Pot")
        local fc = fluidOf(it)
        if fc then pcall(function() fc:addFluid(FluidType.Water, fc:getCapacity()) end) end
        if it then it:setItemHeat(2.6) end
    end,
    ColdBottle = function(p)
        local it = give(p, "Base.WaterBottle")
        local fc = fluidOf(it)
        if fc and fc:isEmpty() then pcall(function() fc:addFluid(FluidType.Water, fc:getCapacity()) end) end
        if it then it:setItemHeat(0.25) end
    end,
    Jacket = function(p)
        local it = give(p, {"Base.Jacket_Padded", "Base.Jacket_WhiteTINT", "Base.JacketLong_Random", "Base.Jacket_Black"})
        if it and KnoxEquip then KnoxEquip.wearItem(p, it, nil) end
    end,
    FullBag = function(p)
        local bag = onFloor(p, first({"Base.Bag_Schoolbag", "Base.Bag_Schoolbag_Kids", "Base.Bag_Satchel"}))
        local inv = bag and bag.getInventory and bag:getInventory()
        if inv then
            for _, ft in ipairs({"Base.Apple", "Base.Pencil", "Base.Book"}) do
                if exists(ft) then tag(inv:AddItem(ft)) end
            end
        end
    end,
    Keys = function(p)
        for _ = 1, 4 do
            local k = give(p, "Base.Key1")
            if k then k:setKeyId(ZombRand(100000)) end
        end
    end,
    Weapon = function(p)
        local it = give(p, {"Base.BaseballBat", "Base.Bat"})
        if it then p:setPrimaryHandItem(it) end
    end,
    Steak = function(p)
        give(p, "Base.Steak")
        give(p, {"Base.Pan", "Base.GridlePan"})
    end,
    Radio = function(p) give(p, {"Base.WalkieTalkie2", "Base.WalkieTalkie3", "Base.RadioRed", "Base.RadioBlack"}) end,
    Bottles = function(p)
        local full = give(p, "Base.WaterBottle")
        local fc = fluidOf(full)
        if fc and fc:isEmpty() then pcall(function() fc:addFluid(FluidType.Water, fc:getCapacity()) end) end
        local empty = give(p, "Base.WaterBottle")
        local ec = fluidOf(empty)
        if ec then pcall(function() ec:Empty() end) end
    end,
    SearchOn = function()
        T.settings["search"] = "1"
        T.saveSettings()
    end,
    SearchOff = function()
        T.settings["search"] = "0"
        T.saveSettings()
    end,
    -- the containers around as never looked into: the search shows again
    Research = function(p, n)
        local screen = KnoxScreen and KnoxScreen.instance
        if screen and screen.loot then
            for _, c in ipairs(screen.loot.containers or {}) do
                local cont = c.container
                if cont and cont:getType() ~= "floor" then
                    KnoxLootPanel.unmarkSeen(cont)
                    local items = cont:getItems()
                    for i = 0, items:size() - 1 do
                        local it = items:get(i)
                        if KnoxSearch then KnoxSearch.known[it] = nil end
                        if it:hasModData() then it:getModData().knoxK = nil end
                    end
                end
            end
            screen:close()
        end
        Knox.open(n or 0)
    end,
    SetModules = function() settingsPage("modules") end,
    SetLook = function() settingsPage("look") end,
    SetGame = function() settingsPage("game") end,
    SetOrder = function() settingsPage("order") end,
    SetControls = function() settingsPage("controls") end,
}

-- the clean shot's tools, always in the toolbar
S.TOOLS = {"Day", "Clear", "NoZombies", "God", "Vanilla", "Cleanup"}

local function actionLabel(id)
    local text = getTextOrNull("IGUI_KnoxST_A_" .. id) or id
    if id == "God" then text = text .. (S.god and ": +" or ": -") end
    if id == "Vanilla" then text = text .. (Knox.vanillaShot and ": +" or ": -") end
    return text
end

-- The panel ----------------------------------------------------------------------

function S:new(playerNum)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.moveWithMouse = false
    o.sel = 1
    o.scroll = 0
    return o
end

function S:player() return getSpecificPlayer(self.playerNum) end

function S:createChildren()
    T.ensure()
    local c = T.cell
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    self:setWidth(math.min(sw - c, math.floor(c * 12.5)))
    self:setHeight(math.min(sh - c, math.floor(c * 13)))
    self.headerH = T.sectionH + 4
    self.listW = math.floor(c * 3.8)
    self.rowH = math.floor(c * 0.46)
    self.btnH = math.floor(c * 0.56)
    self.wrapCache = {}
    -- (where the list starts depends on the tools' rows: known before the first frame)
    self.tools, self.toolsBottom = self:flow(S.TOOLS, T.pad, self.headerH + T.pad, self:getWidth() - T.pad * 2)
end

function S:scene() return S.scenes[self.sel] end

function S:closeRect()
    local s = self.headerH - 8
    return {self:getWidth() - s - 4, 4, s, s}
end

--- Buttons laid out left to right from x, y within width w, wrapping: {x, y, w, h, label, id}.
function S:flow(ids, x, y, w)
    local out, bx, by = {}, x, y
    for _, id in ipairs(ids) do
        local label = actionLabel(id)
        local bw = T.buttonW(label, T.fontTile) + T.pad
        if bx > x and bx + bw > x + w then
            bx = x
            by = by + self.btnH + 6
        end
        table.insert(out, {bx, by, bw, self.btnH, label, id = id})
        bx = bx + bw + 6
    end
    local bottom = (#out > 0) and (by + self.btnH) or y
    return out, bottom
end

--- The list: one row a chapter heading or a scene. {kind, chapter | scene index}.
function S:rows()
    if self.rowsCache then return self.rowsCache end
    local out, last = {}, nil
    for i, sc in ipairs(S.scenes) do
        if sc.chapter ~= last then
            table.insert(out, {kind = "chapter", chapter = sc.chapter})
            last = sc.chapter
        end
        table.insert(out, {kind = "scene", i = i})
    end
    self.rowsCache = out
    return out
end

function S:listTop() return self.toolsBottom + T.pad end

function S:rowRect(k)
    return {T.pad, self:listTop() + (k - 1 - self.scroll) * (self.rowH + 2), self.listW, self.rowH}
end

function S:wrapped(key, text, font, w)
    local ck = key .. "|" .. w
    local v = self.wrapCache[ck]
    if not v then
        v = T.wrap(text, font, w)
        self.wrapCache[ck] = v
    end
    return v
end

function S:prerender()
    local w, h, pad = self:getWidth(), self:getHeight(), T.pad
    local ft, fc = T.fontH(T.fontText), T.fontH(T.fontCaps)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()

    self:drawRect(4, 6, w, h, 0.45, 0, 0, 0)
    T.rect(self, 0, 0, w, h, T.color.window)
    T.rect(self, 0, 0, w, self.headerH, T.color.header)
    T.tileFrame(self, 0, 0, w, h, T.color.accent)
    T.caps(self, getText("IGUI_KnoxST_Title"), 8, math.floor((self.headerH - fc) / 2), T.color.bright)
    local cr = self:closeRect()
    local hint = getText("IGUI_KnoxST_Hide")
    T.text(self, hint, cr[1] - pad - T.measure(T.fontTile, hint), math.floor((self.headerH - T.fontTileH) / 2), T.color.dim, T.fontTile)
    T.closeButton(self, cr[1], cr[2], cr[3], over and T.inRect(mx, my, cr))

    -- the clean shot's tools
    self.tools, self.toolsBottom = self:flow(S.TOOLS, pad, self.headerH + pad, w - pad * 2)
    for _, b in ipairs(self.tools) do
        local on = (b.id == "God" and S.god) or (b.id == "Vanilla" and Knox.vanillaShot)
        T.button(self, b, b[5], {hover = over and T.inRect(mx, my, b), primary = on, font = T.fontTile})
    end

    -- the list, scrolled by the wheel; the scene on show framed in sand
    local rows = self:rows()
    local listBottom = h - pad
    self:setStencilRect(0, self:listTop(), self.listW + pad * 2, listBottom - self:listTop())
    for k, row in ipairs(rows) do
        local r = self:rowRect(k)
        if r[2] + r[4] > self:listTop() and r[2] < listBottom then
            if row.kind == "chapter" then
                local text = row.chapter.n .. ". " .. row.chapter.title
                T.text(self, T.fit(T.upper(text), T.fontTile, r[3]), r[1], r[2] + r[4] - T.fontTileH - 2, T.color.accent, T.fontTile)
            else
                local sc = S.scenes[row.i]
                local on = row.i == self.sel
                T.rect(self, r[1], r[2], r[3], r[4], on and T.color.header or T.color.cell)
                if over and T.inRect(mx, my, r) and not on then self:drawRect(r[1], r[2], r[3], r[4], 0.05, 1, 1, 1) end
                T.border(self, r[1], r[2], r[3], r[4], on and T.color.accent or T.color.border)
                local d = math.floor(r[4] * 0.34)
                T.rect(self, r[1] + 6, r[2] + math.floor((r[4] - d) / 2), d, d, S.done[sc.id] and T.color.ok or T.color.tileEdge)
                T.text(self, T.fit(sc.title, T.fontText, r[3] - d - 18), r[1] + d + 12, r[2] + math.floor((r[4] - ft) / 2),
                    on and T.color.bright or T.color.text, T.fontText)
            end
        end
    end
    self:clearStencilRect()

    -- the scene
    local sc = self:scene()
    if not sc then return end
    local x, y = self.listW + pad * 2, self:listTop()
    local pw = w - x - pad
    local filmed = 0
    for _, s in ipairs(S.scenes) do if S.done[s.id] then filmed = filmed + 1 end end
    T.text(self, T.upper(getText("IGUI_KnoxST_Chapter", sc.chapter.n, sc.chapter.title)) .. "   " .. filmed .. " / " .. #S.scenes,
        x, y, T.color.dim, T.fontTile)
    y = y + T.fontTileH + 6
    for _, l in ipairs(self:wrapped(sc.id .. "t", T.upper(sc.title), T.fontCaps, pw)) do
        T.text(self, l, x, y, T.color.accent, T.fontCaps)
        y = y + fc + 2
    end
    y = y + pad
    local function block(label, key, text, color)
        if text == "" then return end
        T.text(self, T.upper(getText(label)), x, y, T.color.dim, T.fontTile)
        y = y + T.fontTileH + 4
        for _, l in ipairs(self:wrapped(sc.id .. key, text, T.fontText, pw)) do
            T.text(self, l, x, y, color, T.fontText)
            y = y + ft + 2
        end
        y = y + pad
    end
    block("IGUI_KnoxST_Shot", "s", sc.shot, T.color.text)
    -- the voice: on a darker plate, a sand line on the left (the text to read)
    if sc.voice ~= "" then
        local lines = self:wrapped(sc.id .. "v", sc.voice, T.fontText, pw - pad * 2)
        T.text(self, T.upper(getText("IGUI_KnoxST_Voice")), x, y, T.color.dim, T.fontTile)
        y = y + T.fontTileH + 4
        local vh = #lines * (ft + 2) + pad
        T.rect(self, x, y, pw, vh, T.color.cell)
        T.rect(self, x, y, 3, vh, T.color.accent)
        local vy = y + math.floor(pad / 2)
        for _, l in ipairs(lines) do
            T.text(self, l, x + pad, vy, T.color.bright, T.fontText)
            vy = vy + ft + 2
        end
        y = y + vh + pad
    end
    -- its set-up buttons
    self.btns, y = self:flow(sc.actions, x, y, pw)
    for _, b in ipairs(self.btns) do
        T.button(self, b, b[5], {hover = over and T.inRect(mx, my, b), font = T.fontTile})
    end
    -- back, filmed, next - at the bottom
    local by = h - pad - self.btnH
    local third = math.floor((pw - 12) / 3)
    self.nav = {
        {x, by, third, self.btnH, getText("IGUI_KnoxST_Prev"), id = "prev"},
        {x + third + 6, by, third, self.btnH, getText(S.done[sc.id] and "IGUI_KnoxST_Filmed" or "IGUI_KnoxST_MarkFilmed"), id = "done"},
        {x + (third + 6) * 2, by, third, self.btnH, getText("IGUI_KnoxST_Next"), id = "next"},
    }
    for _, b in ipairs(self.nav) do
        T.button(self, b, b[5], {hover = over and T.inRect(mx, my, b), primary = b.id == "done" and S.done[sc.id], font = T.fontTile})
    end
end

function S:go(i)
    self.sel = math.max(1, math.min(#S.scenes, i))
    -- the chosen scene's row in view
    local rows = self:rows()
    for k, row in ipairs(rows) do
        if row.kind == "scene" and row.i == self.sel then
            local visible = math.floor((self:getHeight() - T.pad - self:listTop()) / (self.rowH + 2))
            if k - 1 < self.scroll + 1 then self.scroll = math.max(0, k - 2) end
            if k > self.scroll + visible then self.scroll = k - visible end
        end
    end
end

function S:run(id)
    local fn = S.ACTIONS[id]
    if not fn then return end
    local ok, err = pcall(fn, self:player(), self.playerNum)
    if not ok then print("[Knox] filming mode: " .. id .. " failed: " .. tostring(err)) end
    dirty()
end

function S:onMouseDown(x, y)
    if T.inRect(x, y, self:closeRect()) then
        S.stop()
        return true
    end
    for _, list in ipairs({self.tools or {}, self.btns or {}}) do
        for _, b in ipairs(list) do
            if T.inRect(x, y, b) then
                getSoundManager():playUISound("UIActivateButton")
                self:run(b.id)
                return true
            end
        end
    end
    for _, b in ipairs(self.nav or {}) do
        if T.inRect(x, y, b) then
            getSoundManager():playUISound("UIActivateButton")
            local sc = self:scene()
            if b.id == "prev" then self:go(self.sel - 1)
            elseif b.id == "next" then self:go(self.sel + 1)
            elseif sc then
                S.done[sc.id] = not S.done[sc.id] or nil
                saveMarks()
                if S.done[sc.id] then self:go(self.sel + 1) end
            end
            return true
        end
    end
    if x < self.listW + T.pad * 2 and y > self:listTop() then
        for k, row in ipairs(self:rows()) do
            if row.kind == "scene" and T.inRect(x, y, self:rowRect(k)) then
                self.sel = row.i
                getSoundManager():playUISound("UIActivateButton")
                return true
            end
        end
    end
    KnoxWindowDrag.begin(self, x, y, self.headerH)
    return true
end

KnoxWindowDrag.install(S)

function S:onRightMouseUp(x, y) return true end
function S:onMouseWheel(del)
    local rows = #self:rows()
    local visible = math.floor((self:getHeight() - T.pad - self:listTop()) / (self.rowH + 2))
    self.scroll = math.max(0, math.min(math.max(0, rows - visible), self.scroll + (del > 0 and 3 or -3)))
    return true
end

-- On and off ---------------------------------------------------------------------

function S.start(playerNum)
    S.load()
    loadMarks()
    local p = S:new(playerNum or 0)
    p:initialise()
    p:instantiate()
    p:setX(getCore():getScreenWidth() - p:getWidth() - T.cell)
    p:setY(math.floor((getCore():getScreenHeight() - p:getHeight()) / 2))
    p:addToUIManager()
    p:setAlwaysOnTop(true)
    S.instance = p
    S.active = true
    -- the first scene not filmed yet
    for i, sc in ipairs(S.scenes) do
        if not S.done[sc.id] then p:go(i) break end
    end
end

function S.stop()
    local p = S.instance
    if p then
        p:setVisible(false)
        p:removeFromUIManager()
    end
    S.instance = nil
    S.active = false
    Knox.vanillaShot = false
    if S.god then
        S.god = false
        local pl = getSpecificPlayer(0)
        if pl then pl:setGodMod(false) end
    end
end

Events.OnKeyPressed.Add(function(key)
    if key ~= Keyboard.KEY_HOME or not getSpecificPlayer(0) then return end
    if not (isDebugEnabled() or (B.devAllowed and B.devAllowed())) then return end
    if not S.instance then
        S.start(0)
    else
        -- hidden for the shot, or back
        S.instance:setVisible(not S.instance:getIsVisible())
        if S.instance:getIsVisible() then S.instance:bringToTop() end
    end
end)

return KnoxStudio
