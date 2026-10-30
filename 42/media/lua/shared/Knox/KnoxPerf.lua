-- Knox's own performance counter (the author's task, 2026-10-24: players wrote
-- that Knox "kills ms and FPS, the longer you play the worse"). It is there
-- to measure, not to change anything Knox does.
--
-- Off unless knox_settings.txt has dev.perf=1 (the test bench switches it;
-- it is read when the Lua loads - back to the menu and into the game again).
-- Off, this file does nothing at all: no wrapper sits on any of Knox's paths.
--
-- On:
--   * every event handler written in Knox's files is timed: while the Lua
--     loads, Events.X.Add / Remove are taken over and hand the game a timed
--     wrapper for Knox's closures (the others pass as they are). This file
--     is required first by the shared files that add handlers as they load.
--   * once a game has started, Knox's drawing (prerender / render of its
--     windows and of the game's elements it draws: hotbar, tooltips, menus)
--     and a few busy functions are timed the same way.
--   * every 10 s a block goes to Zomboid/Lua/knox_perf.txt: frames, the
--     slowest frame, Java heap and GC, UI elements; per handler and function
--     its calls, time and longest call (microseconds, inclusive of what it
--     calls); the sizes of Knox's caches; how many handlers each event holds
--     and how many of them are Knox's (Java: knoxPerfHandlers).
-- The clock is the Java part's (knoxPerfNow, microseconds): the game's Lua
-- clocks count whole milliseconds, Knox's handlers take microseconds.
-- (PeePee, the profiler players use, wraps the same handlers: with both on,
-- it sees Knox's handlers as this file's - one of them at a time.)

KnoxPerf = KnoxPerf or {}
local P = KnoxPerf
if P.loaded then return P end
P.loaded = true
P.on = false

local FILE = "knox_perf.txt"
local DUMP_MS = 10000
local SLOW_US, FREEZE_US = 33334, 100000   -- a frame slower than 30 FPS, a visible hitch
local HALF_US, BUSY_US = 16667, 8000        -- (the UI or Knox alone: slower than 60 FPS; most of a 120 FPS frame)

--- Is dev.perf=1 in knox_settings.txt? (the same file and format as KnoxTheme's)
local function wanted()
    if isServer and isServer() then return false end
    if not getFileReader then return false end
    local r = getFileReader("knox_settings.txt", false)
    if not r then return false end
    local on = false
    local line = r:readLine()
    while line do
        local k, v = string.match(line, "^%s*([%w_%.]+)%s*=%s*(.-)%s*$")
        if k == "dev.perf" then on = v == "1" end
        line = r:readLine()
    end
    r:close()
    return on
end

--- Write lines to knox_perf.txt (appended).
local function write(text)
    local w = getFileWriter(FILE, true, true)
    if not w then return end
    w:write(text .. "\r\n")
    w:close()
end

local function clock()
    local ok, s = pcall(os.date, "%Y-%m-%d %H:%M:%S")
    return ok and tostring(s) or tostring(getTimestampMs())
end

--- A line in the file, for the bench's steps ("reload 2", "car: own music"...).
function P.mark(text)
    if not P.on then return end
    write("M\t" .. clock() .. "\t" .. tostring(text))
end

if not wanted() then return P end
if not knoxPerfNow then
    print("[Knox] perf: dev.perf=1, but the Java part has no knoxPerfNow (older than v58): the counter stays off")
    return P
end
P.on = true

local now = knoxPerfNow

local function norm(path)
    return (string.gsub(tostring(path or ""), "\\", "/"))
end

local function fileOf(fn)
    if type(fn) ~= "function" or not string.match(tostring(fn), "^closure") then return nil end
    local ok, path = pcall(getFilenameOfClosure, fn)
    if not ok or not path then return nil end
    return norm(path)
end

-- Knox's own files: the folder this file lies in (its media/lua), Knox/ under it
local selfFile = fileOf(wanted) or ""
local root = string.match(selfFile, "^(.*/media/lua/)") or ""

local function isKnox(fn)
    local f = fileOf(fn)
    if not f or f == selfFile then return false end
    if root ~= "" then return string.sub(f, 1, #root) == root and string.find(f, "/Knox/", #root, true) ~= nil end
    return string.find(f, "/Knox/Knox", 1, true) ~= nil
end

local function shortName(fn)
    local f = fileOf(fn) or "?"
    local name = string.match(f, "([^/]+)$") or f
    local ok, line = pcall(getFirstLineOfClosure, fn)
    return name .. ":" .. tostring(ok and line or "?")
end

-- Records ------------------------------------------------------------------------------

P.recs = {}       -- name -> {name, calls, us, max} for the window now
local recList = {}

local function recordFor(name)
    local r = P.recs[name]
    if not r then
        r = {name = name, calls = 0, us = 0, max = 0, draws = 0, n = 0, allCalls = 0, allUs = 0, allMax = 0}
        P.recs[name] = r
        table.insert(recList, r)
    end
    return r
end

-- Knox's own time in a frame (the author, 2026-10-28: "no frame over 33 ms because of
-- Knox" - the frame's length alone doesn't tell whose it was): the outermost timed
-- calls summed, what they call is inside them. And the drawing calls made inside
-- Knox's timed calls (counted in the detailed mode only, P.setDetail).
-- (a call that fails leaves `depth` up: it is set back every frame)
local depth, knoxFrameUs, draws = 0, 0, 0

-- (no table and no string per call: the results go through as they are)
local function done(r, t0, d0, ...)
    local dt = now() - t0
    r.calls = r.calls + 1
    r.us = r.us + dt
    if dt > r.max then r.max = dt end
    r.draws = r.draws + (draws - d0)
    depth = depth - 1
    if depth <= 0 then
        depth = 0
        knoxFrameUs = knoxFrameUs + dt
    end
    return ...
end

local function timed(fn, r)
    return function(...)
        depth = depth + 1
        return done(r, now(), draws, fn(...))
    end
end

-- The game's own functions Knox calls: timed only when Knox calls them (inside one of
-- its timed calls) - the game's own calls are the game's
local function doneGame(r, t0, ...)
    local dt = now() - t0
    r.calls = r.calls + 1
    r.us = r.us + dt
    if dt > r.max then r.max = dt end
    return ...
end

local function timedGame(fn, r)
    return function(...)
        if depth == 0 then return fn(...) end
        return doneGame(r, now(), fn(...))
    end
end

-- Events --------------------------------------------------------------------------------

P.origAdd, P.origRemove = {}, {}
P.knoxHandlers = 0   -- Knox's registrations now (Add minus Remove)

local function takeOver()
    local n = 0
    for name, ev in pairs(Events) do
        if type(name) == "string" and type(ev) == "table" and type(ev.Add) == "function" and type(ev.Remove) == "function" then
            local add, remove = ev.Add, ev.Remove
            local wrapOf, refs = {}, {}
            P.origAdd[name], P.origRemove[name] = add, remove
            ev.Add = function(fn, ...)
                if not isKnox(fn) then return add(fn, ...) end
                local w = wrapOf[fn]
                if not w then
                    w = timed(fn, recordFor(shortName(fn) .. " " .. name))
                    wrapOf[fn] = w
                end
                refs[fn] = (refs[fn] or 0) + 1
                P.knoxHandlers = P.knoxHandlers + 1
                return add(w, ...)
            end
            ev.Remove = function(fn, ...)
                local w = wrapOf[fn]
                if not w then return remove(fn, ...) end
                local left = (refs[fn] or 1) - 1
                if left <= 0 then wrapOf[fn], refs[fn] = nil, nil else refs[fn] = left end
                P.knoxHandlers = math.max(0, P.knoxHandlers - 1)
                return remove(w, ...)
            end
            n = n + 1
        end
    end
    return n
end

-- Drawing and busy functions (wrapped once a game has started) ---------------------------

-- {global table, key}: only a function of that table itself (not one it inherits) and
-- only one written in Knox's files - what the game draws itself is not Knox's time
P.METHODS = {
    {"KnoxScreen", "prerender"}, {"KnoxScreen", "render"}, {"KnoxQuickSlot", "render"},
    {"KnoxGridView", "prerender"}, {"KnoxGridView", "render"}, {"KnoxDragLayer", "prerender"}, {"KnoxDragLayer", "render"},
    {"KnoxLootPanel", "prerender"}, {"KnoxLootPanel", "render"}, {"KnoxLootGridArea", "prerender"}, {"KnoxLootGridArea", "render"},
    {"KnoxInventoryPanel", "prerender"}, {"KnoxInventoryPanel", "render"},
    {"KnoxEquipmentPanel", "prerender"}, {"KnoxEquipSlot", "render"}, {"KnoxSlotPicker", "prerender"},
    {"KnoxContainerWindow", "prerender"}, {"KnoxInspectWindow", "prerender"}, {"KnoxFoundWindow", "prerender"},
    {"KnoxSplitDialog", "prerender"}, {"KnoxSettings", "prerender"},
    {"KnoxTVWindow", "prerender"}, {"KnoxRadioWindow", "prerender"}, {"KnoxFluidWindow", "prerender"},
    {"KnoxFluidInfo", "prerender"}, {"KnoxStoveWindow", "prerender"}, {"KnoxGeneratorWindow", "prerender"},
    {"KnoxAlarmWindow", "prerender"}, {"KnoxDashboard", "prerender"},
    -- (not ISButton / ISScrollBar / ISToolTip: Knox draws only its own of those and hands
    -- every other one to the game - their time would be the game's)
    {"ISHotbar", "render"}, {"ISToolTipInv", "render"}, {"ISContextMenu", "prerender"}, {"ISContextMenu", "render"},
    {"Knox", "forPlayer"}, {"Knox", "open"}, {"KnoxGrid", "build"}, {"KnoxTooltip", "apply"},
    {"KnoxSlotPicker", "sync"}, {"KnoxMenuBag", "write"}, {"KnoxMenuMusic", "update"},
    -- what KnoxGrid.build asks of every item (500 bullets moved: up to 7 ms a build,
    -- 20-37 builds a second - the author, 2026-10-28); called elsewhere too
    {"KnoxGrid", "isStackable"}, {"KnoxGrid", "stackKey"}, {"KnoxGrid", "stackLimit"},
    {"KnoxGrid", "pendingOf"}, {"KnoxGrid", "isEquippedNow"}, {"KnoxGrid", "pendingList"},
    {"KnoxGrid", "writePlace"}, {"KnoxGrid", "placeNew"}, {"KnoxFootprint", "get"},
    -- inside the open screen (the author, 2026-10-28: the screen open with nothing done
    -- costs ~3.2 ms a frame - what of it is what): called up to a few dozen times a frame
    {"KnoxScreen", "hideDashboard"}, {"KnoxScreen", "rebuildQuickSlots"}, {"KnoxScreen", "drawSearch"},
    {"KnoxScreen", "drawFoundButton"}, {"KnoxScreen", "drawTabStage"}, {"KnoxScreen", "drawTime"},
    {"KnoxScreen", "drawHints"}, {"KnoxScreen", "drawCoin"}, {"KnoxScreen", "drawCoinTip"},
    {"KnoxScreen", "drawWeightDelta"}, {"KnoxScreen", "dragWeightDelta"}, {"KnoxScreen", "lootWeightDelta"},
    {"KnoxNews", "hasUnread"}, {"KnoxSearch", "tick"},
    {"KnoxContainerWindow", "updateAll"}, {"KnoxInspectWindow", "updateAll"},
    {"KnoxGrid", "updateUse"}, {"KnoxGrid", "usedCells"}, {"KnoxGrid", "cellsOf"}, {"KnoxGrid", "leavingSlot"}, {"KnoxGrid", "arrivingSlot"},
    {"KnoxEquip", "updateHints"}, {"KnoxEquip", "collect"}, {"KnoxEquip", "isReplaced"}, {"KnoxEquip", "isHinted"},
    {"KnoxEquip", "drawAvailable"}, {"KnoxEquipSlot", "contents"}, {"KnoxEquipSlot", "candidates"},
    {"KnoxEquipmentPanel", "updateModel"},
    {"KnoxInventoryPanel", "relayout"}, {"KnoxInventoryPanel", "rebuildSections"}, {"KnoxInventoryPanel", "collectContainers"},
    {"KnoxGridView", "rebuild"}, {"KnoxGridView", "updateTooltip"}, {"KnoxGridView", "offerKinds"},
    {"KnoxGridView", "offerBattery"}, {"KnoxGridView", "updateLift"}, {"KnoxGridView", "drawStackHints"},
    {"KnoxGridView", "drawBand"}, {"KnoxGridView", "visibleRows"}, {"KnoxGridView", "entityUnderMouse"},
    {"KnoxGridView", "probe"}, {"KnoxLootPanel", "refresh"}, {"KnoxLootPanel", "drawIcon"},
    {"KnoxOrder", "drawEye"}, {"KnoxTooltip", "want"}, {"KnoxSlotPicker", "isOpenFor"},
}
-- the Java part's calls Lua makes often (looked up by name when called: a wrapper in _G is seen)
P.JAVA = {"knoxMusicForeign", "knoxMusicMuteGame", "knoxMenuSnapshot", "knoxMenuSaveBag", "knoxDrawTiles"}
-- the game's functions Knox calls every frame or every few (the surroundings' search
-- for containers; the icon of an item in a slot)
P.GAME = {{"ISInventoryPage", "refreshBackpacks"}, {"ISInventoryItem", "renderItemIcon"}}

P.wrapped = 0
local methodsDone = false
local function wrapMethods()
    methodsDone = true
    for _, m in ipairs(P.METHODS) do
        local t = _G[m[1]]
        local f = type(t) == "table" and rawget(t, m[2]) or nil
        if type(f) == "function" and isKnox(f) then
            rawset(t, m[2], timed(f, recordFor(m[1] .. "." .. m[2] .. " (" .. shortName(f) .. ")")))
            P.wrapped = P.wrapped + 1
        end
    end
    for _, name in ipairs(P.JAVA) do
        local f = rawget(_G, name)
        if type(f) == "function" then
            rawset(_G, name, timed(f, recordFor(name .. " (Java)")))
            P.wrapped = P.wrapped + 1
        end
    end
    for _, m in ipairs(P.GAME) do
        local t = _G[m[1]]
        local f = type(t) == "table" and rawget(t, m[2]) or nil
        if type(f) == "function" then
            rawset(t, m[2], timedGame(f, recordFor(m[1] .. "." .. m[2] .. " (game, from Knox)")))
            P.wrapped = P.wrapped + 1
        end
    end
end

-- The detailed mode (the bench's "Detail", 2026-10-28: what the open screen's cost is
-- made of): the small helpers called hundreds of times a frame are timed too, and the
-- drawing calls made inside Knox's timed calls are counted by kind. Its wrappers cost
-- about a microsecond a call, so the times of what they are in grow with them: the
-- counts are what it is for - times are compared with it off. Switched while playing.
P.DETAIL = {
    {"KnoxGridView", "isQuiet"}, {"KnoxGridView", "drawTile"}, {"KnoxGridView", "tileInfo"},
    {"KnoxGridView", "query"}, {"KnoxGridView", "searchFx"}, {"KnoxGridView", "liftPx"}, {"KnoxGridView", "isDragged"},
    {"KnoxGrid", "useOf"},
    {"KnoxTheme", "drawText"}, {"KnoxTheme", "measure"}, {"KnoxTheme", "upper"}, {"KnoxTheme", "fit"},
    {"KnoxTheme", "label"}, {"KnoxTheme", "plate"}, {"KnoxTheme", "inkCentre"}, {"KnoxTheme", "inkOrigin"},
    {"KnoxTheme", "outlinedRight"}, {"KnoxTheme", "tileFrame"}, {"KnoxTheme", "tileMeter"}, {"KnoxTheme", "categoryOf"},
    {"KnoxTheme", "settleIn"}, {"KnoxTheme", "marquee"}, {"KnoxTheme", "iconButton"}, {"KnoxTheme", "button"},
}
P.DETAIL_GAME = {"getText"}   -- (the game's, by name: Knox looks it up when it calls it)
-- drawing calls by kind: ISUIElement's (every element's, Knox's counted only), the Java
-- part's text, the game's item icon (its own pictures are counted too), Knox's tiles
P.DRAWS = {
    rect = {"drawRect", "drawRectStatic"},
    border = {"drawRectBorder", "drawRectBorderStatic"},
    tex = {"drawTexture", "drawTextureScaled", "drawTextureScaledAspect", "drawTextureScaledAspect2",
           "drawTextureScaledAspect3", "drawTextureScaledUniform", "drawSubTexture", "drawTextureAllPoint",
           "drawTextureTiled", "drawTextureTiledX", "drawTextureTiledY", "drawTextureTiledYOffset",
           "drawTextureScaledStatic", "drawTextureStatic", "drawItemIcon", "drawScriptItemIcon",
           "drawPolygon", "drawLine", "drawLine2", "drawLineAbsolute"},
    text = {"drawText", "drawTextCentre", "drawTextRight", "drawTextZoomed", "drawTextUntrimmed",
            "drawTextStatic", "drawTextCentreStatic", "drawTextRightStatic"},
}
P.DRAW_KINDS = {"rect", "border", "tex", "text", "icon", "tiles"}

P.detail = false
local detailSaved = {}            -- {t, key, orig, wrap}: put back as it was when switched off
local drawN = {rect = 0, border = 0, tex = 0, text = 0, icon = 0, tiles = 0}

local function counted(fn, kind)
    return function(...)
        if depth > 0 then
            draws = draws + 1
            drawN[kind] = drawN[kind] + 1
        end
        return fn(...)
    end
end

local function swap(t, key, wrap)
    local f = rawget(t, key)
    local w = wrap(f)
    rawset(t, key, w)
    table.insert(detailSaved, {t = t, key = key, orig = f, wrap = w})
end

--- Detailed mode on or off (the bench); a mark in the file says when. Returns it.
function P.setDetail(on)
    on = on == true
    if not P.on or not methodsDone or on == P.detail then return P.detail end
    P.detail = on
    if on then
        for _, m in ipairs(P.DETAIL) do
            local t = _G[m[1]]
            local f = type(t) == "table" and rawget(t, m[2]) or nil
            if type(f) == "function" and isKnox(f) then
                swap(t, m[2], function(fn) return timed(fn, recordFor(m[1] .. "." .. m[2] .. " (" .. shortName(fn) .. ")")) end)
            end
        end
        for _, name in ipairs(P.DETAIL_GAME) do
            if type(rawget(_G, name)) == "function" then
                swap(_G, name, function(fn) return timedGame(fn, recordFor(name .. " (game, from Knox)")) end)
            end
        end
        local ui = _G.ISUIElement
        for kind, names in pairs(P.DRAWS) do
            for _, name in ipairs(names) do
                if type(ui) == "table" and type(rawget(ui, name)) == "function" then
                    swap(ui, name, function(fn) return counted(fn, kind) end)
                end
            end
        end
        if type(rawget(_G, "knoxDrawText")) == "function" then swap(_G, "knoxDrawText", function(fn) return counted(fn, "text") end) end
        if type(rawget(_G, "knoxDrawTiles")) == "function" then swap(_G, "knoxDrawTiles", function(fn) return counted(fn, "tiles") end) end
        local ii = _G.ISInventoryItem
        if type(ii) == "table" and type(rawget(ii, "renderItemIcon")) == "function" then
            swap(ii, "renderItemIcon", function(fn) return counted(fn, "icon") end)
        end
    else
        -- (backwards: a function wrapped twice gets its first wrapper back, then its own;
        -- one somebody else has replaced meanwhile is left as it is now)
        for i = #detailSaved, 1, -1 do
            local s = detailSaved[i]
            if rawget(s.t, s.key) == s.wrap then rawset(s.t, s.key, s.orig) end
        end
        detailSaved = {}
    end
    write("M\t" .. clock() .. "\tdetail " .. (on and "on" or "off"))
    return on
end

-- Parts of a slow function, in the detailed mode (the grids' long builds - 500 bullets
-- moved, a floor of 300 things: up to 6-7 ms a build, the author's bench 2026-10-29;
-- what of a build is what). The function asks `KnoxPerf.detail and KnoxPerf.now()`
-- once and goes on only when it got a clock: off, no part costs anything.
P.now = now

--- `us` more for the part `name` (a literal: no string made), `n` - what it went over
--- (things, tiles: shown as n= a call). Not Knox's frame time: it is inside a timed call.
function P.addPart(name, us, n)
    local r = P.recs[name] or recordFor(name)
    r.calls = r.calls + 1
    r.us = r.us + us
    if us > r.max then r.max = us end
    if n then r.n = r.n + n end
end

--- The part `name` began at `t0` (P.now()) and ends now; returns the clock for the next
--- part (read after the counting: the counter's own time is in no part).
function P.part(name, t0, n)
    P.addPart(name, now() - t0, n)
    return now()
end

-- Sizes of Knox's caches and lists (counted every 10 s: a table that keeps growing shows here)
local function count(t)
    if type(t) ~= "table" then return -1 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function field(tname, key)
    local t = _G[tname]
    return type(t) == "table" and t[key] or nil
end

P.SIZES = {
    {"picker.dying", function() return count(field("KnoxSlotPicker", "dying")) end},
    {"picker.offered", function() return count(field("KnoxSlotPicker", "offered")) end},
    {"theme.folding", function() return count(field("KnoxTheme", "folding")) end},
    {"radio.halos", function() return count(field("KnoxRadioWindow", "halos")) end},
    {"grid.lastClicks", function() return count(field("KnoxGridView", "lastClicks")) end},
    {"grid.settle", function() return count(field("KnoxGridView", "settle")) end},
    {"grid.fresh", function() return count(field("KnoxGridView", "fresh")) end},
    {"grid.flash", function() return count(field("KnoxGridView", "flash")) end},
    {"grid.pending", function() return count(field("KnoxGrid", "pending")) end},
    {"search.known", function() return count(field("KnoxSearch", "known")) end},
    {"select.items", function() return count(field("KnoxSelect", "items")) end},
    {"windows.container", function() return count(field("KnoxContainerWindow", "list")) end},
    {"windows.inspect", function() return count(field("KnoxInspectWindow", "list")) end},
    {"screen.open", function() return field("KnoxScreen", "instance") and 1 or 0 end},
    {"knoxHandlers.lua", function() return P.knoxHandlers end},
}

-- Frames and the dump ------------------------------------------------------------------------

local startMs = getTimestampMs()
local nextDump = startMs + DUMP_MS
local frames, lastFrame, maxGap, slow, freeze = 0, nil, 0, 0, 0
-- A frame in three parts (the author, 2026-10-28: 500 bullets moved with the screen
-- open took 120 FPS to 45, Knox's own functions showed only ~3.5 ms of a 22 ms
-- frame): the game's tick to the UI (its update, the world sent to be drawn), the
-- whole UI (the game's and Knox's), the UI to the next tick (waiting for the drawing).
local tickAt, uiAt, postAt = nil, nil, nil
local logicUs, uiUs, restUs = 0, 0, 0
-- the longest UI part of a frame and the frames whose UI took over 16 / 33 ms; Knox's
-- longest frame (its own time in it) and its frames over 8 / 16 ms
local uiMax, uiSlow16, uiSlow33 = 0, 0, 0
local knoxMax, knoxSlow8, knoxSlow16 = 0, 0, 0
local lastGc, lastGcMs = nil, nil
local wantWrap = false

local function f1(v) return string.format("%.1f", v) end

local function dump()
    local nowMs = getTimestampMs()
    local secs = (nowMs - startMs) / 1000
    local out = {}
    local stats = knoxPerfStats and knoxPerfStats() or ""
    local used, committed, maxMb, gcN, gcMs, fps, ui, tv = string.match(stats,
        "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
    gcN, gcMs = tonumber(gcN), tonumber(gcMs)
    local gcLine = "?"
    if gcN and gcN >= 0 then
        gcLine = tostring(lastGc and (gcN - lastGc) or 0) .. " (" .. tostring(lastGcMs and (gcMs - lastGcMs) or 0) .. " ms)"
        lastGc, lastGcMs = gcN, gcMs
    end
    local hours = "-"
    pcall(function() hours = string.format("%.2f", getGameTime():getWorldAgeHours()) end)
    table.insert(out, "T\t" .. clock() .. "\tt=" .. string.format("%.0f", secs) .. "s\tgame_h=" .. hours
        .. "\tframes=" .. frames .. "\tfps=" .. tostring(fps or "?") .. "\tframe_max_ms=" .. f1(maxGap / 1000)
        .. "\tslow33=" .. slow .. "\tfreeze100=" .. freeze
        .. "\theap_mb=" .. tostring(used or "?") .. "/" .. tostring(committed or "?") .. "/" .. tostring(maxMb or "?")
        .. "\tgc=" .. gcLine .. "\tui=" .. tostring(ui or "?") .. "\ttv_lines=" .. tostring(tv or "?")
        .. "\tframe_us=tick>ui " .. string.format("%.0f", logicUs / math.max(1, frames))
        .. " ui " .. string.format("%.0f", uiUs / math.max(1, frames))
        .. " ui>tick " .. string.format("%.0f", restUs / math.max(1, frames))
        .. "\tui_max_ms=" .. f1(uiMax / 1000) .. "\tui_slow16=" .. uiSlow16 .. "\tui_slow33=" .. uiSlow33
        .. "\tknox_max_ms=" .. f1(knoxMax / 1000) .. "\tknox_slow8=" .. knoxSlow8 .. "\tknox_slow16=" .. knoxSlow16
        .. (P.detail and "\tdetail=on" or ""))
    -- the window's handlers and functions, the most time first
    table.sort(recList, function(a, b) return a.us > b.us end)
    local perFrame = math.max(1, frames)
    for _, r in ipairs(recList) do
        if r.calls > 0 then
            table.insert(out, "H\t" .. string.format("%.2f", r.us / perFrame) .. "\t" .. r.calls .. "\t" .. string.format("%.0f", r.us)
                .. "\t" .. string.format("%.0f", r.max) .. "\t" .. r.name
                .. (r.draws > 0 and ("\td=" .. f1(r.draws / perFrame)) or "")
                .. (r.n > 0 and ("\tn=" .. f1(r.n / r.calls)) or ""))
            r.allCalls, r.allUs = r.allCalls + r.calls, r.allUs + r.us
            if r.max > r.allMax then r.allMax = r.max end
            r.calls, r.us, r.max, r.draws, r.n = 0, 0, 0, 0, 0
        end
    end
    -- the drawing calls made inside Knox, per frame (the detailed mode)
    local drawAll = drawN.rect + drawN.border + drawN.tex + drawN.text + drawN.tiles
    if drawAll > 0 or drawN.icon > 0 then
        local parts = {}
        for _, k in ipairs(P.DRAW_KINDS) do
            table.insert(parts, k .. "=" .. f1(drawN[k] / perFrame))
            drawN[k] = 0
        end
        table.insert(out, "D\t" .. table.concat(parts, " ") .. " all=" .. f1(drawAll / perFrame))
    end
    local sizes = {}
    for _, s in ipairs(P.SIZES) do
        local ok, n = pcall(s[2])
        table.insert(sizes, s[1] .. "=" .. tostring(ok and n or "err"))
    end
    table.insert(out, "C\t" .. table.concat(sizes, " "))
    if knoxPerfHandlers then table.insert(out, "E\t" .. tostring(knoxPerfHandlers())) end
    write(table.concat(out, "\r\n"))
    frames, maxGap, slow, freeze = 0, 0, 0, 0
    logicUs, uiUs, restUs = 0, 0, 0
    uiMax, uiSlow16, uiSlow33 = 0, 0, 0
    knoxMax, knoxSlow8, knoxSlow16 = 0, 0, 0
end

local function tickStart()
    local t = now()
    if postAt then
        restUs = restUs + (t - postAt)
        postAt = nil
    end
    if not tickAt then tickAt = t end
end

local function uiEnd()
    local t = now()
    if uiAt then
        local dt = t - uiAt
        uiUs = uiUs + dt
        if dt > uiMax then uiMax = dt end
        if dt > HALF_US then uiSlow16 = uiSlow16 + 1 end
        if dt > SLOW_US then uiSlow33 = uiSlow33 + 1 end
        uiAt = nil
    end
    postAt = t
end

local function frame()
    local t = now()
    if tickAt then
        logicUs = logicUs + (t - tickAt)
        tickAt = nil
    end
    uiAt = t
    if lastFrame then
        local gap = t - lastFrame
        if gap > maxGap then maxGap = gap end
        if gap > SLOW_US then slow = slow + 1 end
        if gap > FREEZE_US then freeze = freeze + 1 end
    end
    lastFrame = t
    frames = frames + 1
    -- Knox's time since the last frame began: the last UI's and this tick's handlers'
    if knoxFrameUs > knoxMax then knoxMax = knoxFrameUs end
    if knoxFrameUs > BUSY_US then knoxSlow8 = knoxSlow8 + 1 end
    if knoxFrameUs > HALF_US then knoxSlow16 = knoxSlow16 + 1 end
    knoxFrameUs, depth = 0, 0
    if wantWrap and not methodsDone then wrapMethods() end
    local ms = getTimestampMs()
    if ms >= nextDump then
        nextDump = ms + DUMP_MS
        dump()
        uiAt = now()   -- (writing the block is the counter's own time, not the UI's)
    end
end

-- Start -------------------------------------------------------------------------------------

--- What the counter itself adds to one timed call (us): a wrapper around an empty function.
local function overhead()
    local r = {calls = 0, us = 0, max = 0, draws = 0}
    local w = timed(function() end, r)
    local N = 2000
    local t0 = now()
    for _ = 1, N do w() end
    local us = (now() - t0) / N
    knoxFrameUs = 0   -- (not Knox's time)
    return us
end

local events = takeOver()
write("=== KnoxPerf on\t" .. clock() .. "\tLua loaded; events taken over: " .. events
    .. "\tcounter cost per timed call: " .. string.format("%.2f", overhead()) .. " us"
    .. (PerformanceProfiler and "\tPeePee is on too: its numbers for Knox count this file" or "")
    .. "\r\n# T: window of 10 s; ui_max_ms: the longest UI part of a frame, ui_slowN: frames whose UI took over N ms;"
    .. " knox_max_ms: Knox's own time in its longest frame, knox_slowN: frames with over N ms of it."
    .. " H: us/frame, calls, total us, longest us, name (time includes what it calls), d=drawing calls a frame (detailed mode),"
    .. " n=what a part went over a call (detailed mode: parts of a slow function, \"part: ...\")."
    .. " D (detailed mode): Knox's drawing calls a frame by kind. C: sizes of Knox's lists. E: event=Knox's handlers/all handlers (Java).")
print("[Knox] perf: the counter is on (dev.perf=1), writing Zomboid/Lua/" .. FILE)

-- (the counter's own handlers go straight to the game: not counted)
local function addOwn(name, fn)
    local add = P.origAdd[name]
    if add then add(fn) end
end
addOwn("OnPreUIDraw", frame)
addOwn("OnTick", tickStart)
addOwn("OnPostUIDraw", uiEnd)
addOwn("OnGameStart", function()
    wantWrap = true
    write("M\t" .. clock() .. "\tgame start")
end)
addOwn("OnMainMenuEnter", function() write("M\t" .. clock() .. "\tmain menu") end)
addOwn("OnPlayerDeath", function() write("M\t" .. clock() .. "\tplayer death") end)
addOwn("OnCreatePlayer", function(n) write("M\t" .. clock() .. "\tplayer created " .. tostring(n)) end)

return P
