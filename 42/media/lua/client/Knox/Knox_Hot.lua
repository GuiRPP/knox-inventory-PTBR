-- The DEV reloader (the author 2026-11-10: "not restart the game all the time, see the changes
-- live"; "no restart at all, even when you change something in Java"). Only on the author's
-- computer - where Zomboid/Lua/knox_dev.txt is (dev.hot=0 in knox_settings.txt switches it
-- off): for players this file returns on its first lines, nothing is watched and no frame
-- pays anything.
--
--  * A Knox Lua file saved: it runs again in the game that is going (Java's KnoxHotEngine:
--    its event handlers replaced, not doubled; the game's functions it wraps wrapped once;
--    its tables kept, so the other files and the open windows see the new code). Knox's
--    sizes and fonts are worked out again, its open windows open again, and a note in the
--    corner says what was updated - or the error and its line.
--  * A translation (IG_UI.json) saved: the game reads its texts again.
--  * java\hot.ps1 run (Knox's classes built into java/build/hot): they are swapped in -
--    bodies of methods on plain Java, whole classes on JetBrains Runtime (tools\hot\run_jbr.ps1);
--    ZombieBuddy's patches written into the game's classes again. What can't be swapped says so.
--  * The remote: Lua written to Zomboid/Lua/knox_remote_in.lua (tools\hot\remote.ps1) runs
--    in the game; what it printed and returned goes to knox_remote_out.txt (to look at the
--    game's state from outside).
-- Named to load first of Knox's client files: what the game's tables hold before Knox's
-- files wrap any of their functions is taken here (KnoxHotEngine.baseline).

if isServer and isServer() then return end
if not getFileReader or not knoxHotStart then return end

local function devFile()
    local r = getFileReader("knox_dev.txt", false)
    if not r then return false end
    r:close()
    return true
end
if not devFile() then return end

--- dev.hot=0 in knox_settings.txt: off (the same file and format as KnoxTheme's)
local function wanted()
    local r = getFileReader("knox_settings.txt", false)
    if not r then return true end
    local on = true
    local line = r:readLine()
    while line do
        local k, v = string.match(line, "^%s*([%w_%.]+)%s*=%s*(.-)%s*$")
        if k == "dev.hot" then on = v ~= "0" end
        line = r:readLine()
    end
    r:close()
    return on
end
if not wanted() then return end

KnoxHot = KnoxHot or {}
local H = KnoxHot
H.history = H.history or {}   -- the last reloads, newest last: {time, file, ok, text}

-- (once a Lua: the game's tables as they are before Knox's client files)
if not H.based then
    H.based = true
    local ok, n = pcall(knoxHotBaseline)
    H.baselineTables = ok and n or 0
end

local function norm(p) return (string.gsub(tostring(p or ""), "\\", "/")) end
local selfFile = norm(getFilenameOfClosure(devFile))
local root = string.match(selfFile, "^(.*/media/lua/)")
if not root then
    print("[Knox] DEV reloader: can't tell Knox's Lua folder from " .. selfFile .. " - off")
    return
end
H.root = root
H.on = knoxHotStart(root)
if not H.on then
    -- (Java checks it too: Knox's Lua folder must be the one the jar lies in)
    print("[Knox] DEV reloader off: Java did not take " .. root .. " (not the folder Knox's jar is in?)")
    return
end
print("[Knox] DEV reloader on (" .. H.on .. "): " .. root)

local function shortName(p) return string.match(norm(p), "([^/]+)$") or tostring(p) end
local function clock()
    local ok, s = pcall(os.date, "%H:%M:%S")
    return ok and tostring(s) or tostring(getTimestampMs())
end

local function remember(file, ok, text)
    table.insert(H.history, {time = clock(), file = file, ok = ok, text = text})
    while #H.history > 30 do table.remove(H.history, 1) end
end

-- The note in the corner ---------------------------------------------------------------

local NOTE_MS, NOTE_BAD_MS = 4000, 15000

KnoxHotNote = ISUIElement:derive("KnoxHotNote")

function KnoxHotNote:new()
    local o = ISUIElement:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.lines = {}
    o.band, o.opts = {0, 0, 0, 0}, {}
    o.untilMs = 0
    o.anchorLeft, o.anchorTop = true, false
    return o
end

--- lines: {{text, kind}} - kind "ok", "bad", "warn" or nil (plain).
function KnoxHotNote:show(lines, bad)
    self.lines = lines
    self.untilMs = getTimestampMs() + (bad and NOTE_BAD_MS or NOTE_MS)
    self:setVisible(true)
    self:bringToTop()
end

--- (drawn only while it shows: hidden, the game does not call it)
function KnoxHotNote:drawNote()
    local T = KnoxTheme
    T.ensure()
    local font = T.fontTile
    local lh = T.fontH(font) + 6
    local pad = 8
    local w = 0
    for _, l in ipairs(self.lines) do w = math.max(w, T.measure(font, l[1])) end
    w = w + pad * 2
    local h = #self.lines * lh + pad * 2 - 6
    self:setX(16)
    self:setY(getCore():getScreenHeight() - h - 16)
    self:setWidth(w)
    self:setHeight(h)
    T.rect(self, 0, 0, w, h, T.color.window, 0.92)
    T.border(self, 0, 0, w, h, T.color.tileEdge)
    local band, opts = self.band, self.opts
    band[1], band[2], band[3], band[4] = pad, pad, w - pad * 2, lh - 6
    opts.font = font
    for _, l in ipairs(self.lines) do
        local c = T.color.text
        if l[2] == "ok" then c = T.color.good
        elseif l[2] == "bad" then c = T.color.badText
        elseif l[2] == "warn" then c = T.color.warn end
        T.label(self, l[1], band, c, opts)
        band[2] = band[2] + lh
    end
end

function KnoxHotNote:prerender()
    if getTimestampMs() > self.untilMs then
        self:setVisible(false)
        return
    end
    local T = KnoxTheme
    if not (T and T.label and T.color) then return end
    if not pcall(self.drawNote, self) then self.untilMs = 0 end
end

-- (a click puts it away)
function KnoxHotNote:onMouseDown()
    self.untilMs = 0
    return true
end

local function note(lines, bad)
    for _, l in ipairs(lines) do print("[Knox] DEV reloader: " .. l[1]) end
    if not ISUIElement then return end
    local n = H.noteEl
    if not n then
        n = KnoxHotNote:new()
        n:initialise()
        n:instantiate()
        n:addToUIManager()
        n:setAlwaysOnTop(true)
        H.noteEl = n
    end
    n:show(lines, bad)
end
H.note = note

local function txt(key, a)
    local s = getTextOrNull and getTextOrNull(key)
    if not s then return nil end
    if a then s = string.gsub(s, "%%1", (string.gsub(a, "%%", "%%%%"))) end
    return s
end

-- Windows open again -------------------------------------------------------------------------

--- Knox's open windows, closed and opened again (what they set up when they open is set up
--- anew). The main menu's scene is built again when one of the menu's files changed.
local function reopen(files)
    local menuFile = false
    for _, f in ipairs(files) do
        if string.find(shortName(f), "^KnoxMenu") then menuFile = true end
    end
    -- the main menu's scene
    local MS = KnoxMenuScene
    if menuFile and MS and MS.instance and MS.create then
        local ok, err = pcall(MS.create)
        if not ok then return "menu scene: " .. tostring(err) end
    end
    -- the Knox screen (and the DEV panel and the bench over it)
    local S = KnoxScreen
    local B = KnoxTestBench
    local benchOpen = B and B.instance
    local benchPn, sel, scroll = benchOpen and B.instance.playerNum or 0, benchOpen and B.instance.sel, benchOpen and B.instance.scroll
    if S and S.instance and Knox and Knox.open then
        local s = S.instance
        local pn, tab = s.playerNum, s.tab
        local dev = KnoxDevPanel and KnoxDevPanel.instance ~= nil
        local ok, err = pcall(function()
            s:close()
            -- (Knox.open catches its own error and turns Knox off till a restart - Knox.failed;
            -- said here as the reload's error, and the next reload turns it on again)
            if not Knox.open(pn) then error(tostring(Knox.failed), 0) end
            local n = S.instance
            if n and tab and n.tab ~= tab and n.setTab then n:setTab(tab) end
            if n and dev and KnoxDevPanel and not KnoxDevPanel.instance and KnoxDevPanel.toggle then KnoxDevPanel.toggle(n, pn) end
        end)
        if not ok then return "Knox screen: " .. tostring(err) end
    end
    if benchOpen and B.toggle then
        local ok, err = pcall(function()
            if B.instance then B.instance:close() end
            B.toggle(benchPn)
            if B.instance then
                B.instance.sel, B.instance.scroll = sel, scroll
                if B.instance.showNote then B.instance:showNote() end
            end
        end)
        if not ok then return "bench: " .. tostring(err) end
    end
end

--- What a module wants done after its file ran again (stage 5 of the plan: what Knox builds
--- once - set up anew): M.knoxHotReload, a function written in that very file.
local function moduleHooks(files)
    local want = {}
    for _, f in ipairs(files) do want[string.lower(norm(f))] = true end
    for name, t in pairs(_G) do
        if type(name) == "string" and string.sub(name, 1, 4) == "Knox" and type(t) == "table" then
            local fn = rawget(t, "knoxHotReload")
            if type(fn) == "function" then
                local okF, file = pcall(getFilenameOfClosure, fn)
                if okF and file and want[string.lower(norm(file))] then
                    local ok, err = pcall(fn)
                    if not ok then print("[Knox] DEV reloader: " .. name .. ".knoxHotReload: " .. tostring(err)) end
                end
            end
        end
    end
end

-- The remote ---------------------------------------------------------------------------------

local function dump(v, depth, seen)
    local tv = type(v)
    if tv == "string" then return string.format("%q", v) end
    if tv ~= "table" then return tostring(v) end
    seen = seen or {}
    if seen[v] then return "<seen>" end
    if (depth or 0) >= 2 then return "{...}" end
    seen[v] = true
    local parts, n = {}, 0
    for k, val in pairs(v) do
        n = n + 1
        if n > 40 then table.insert(parts, "...") break end
        table.insert(parts, tostring(k) .. " = " .. dump(val, (depth or 0) + 1, seen))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end
H.dump = dump

local function remote()
    local r = getFileReader("knox_remote_in.lua", false)
    if not r then return end
    local lines = {}
    local line = r:readLine()
    while line do
        table.insert(lines, line)
        line = r:readLine()
    end
    r:close()
    local id = lines[1] and string.match(lines[1], "^%-%-%s*knox remote%s+(%S+)") or "?"
    if id ~= "?" and id == H.lastRemote then return end   -- (written without remote.ps1's id: run every time it changes)
    H.lastRemote = id
    local code = table.concat(lines, "\n")
    local out = {}
    local realPrint = print
    local results
    local fn, cerr = loadstring(code, "remote")
    if not fn then
        results = {false, cerr}
    else
        print = function(...)
            local t = {}
            for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
            table.insert(out, table.concat(t, "\t"))
        end
        results = {pcall(fn)}
        print = realPrint
    end
    local w = getFileWriter("knox_remote_out.txt", true, false)
    if not w then return end
    w:write("id " .. id .. "\r\n")
    w:write((results[1] and "ok" or "error") .. "\r\n")
    for _, l in ipairs(out) do w:write(l .. "\r\n") end
    if results[1] then
        for i = 2, #results do w:write("return " .. dump(results[i]) .. "\r\n") end
    else
        w:write(tostring(results[2]) .. "\r\n")
    end
    w:close()
end

--- What is going on, for the remote: KnoxHot.state()
function H.state()
    local s = {}
    s.where = (getPlayer and getPlayer()) and "game" or "menu"
    s.on = H.on
    local open = {}
    for name, t in pairs(_G) do
        if type(name) == "string" and string.sub(name, 1, 4) == "Knox" and type(t) == "table" then
            local inst = rawget(t, "instance")
            if type(inst) == "table" and inst.isVisible and inst:isVisible() then table.insert(open, name) end
        end
    end
    table.sort(open)
    s.open = table.concat(open, ", ")
    local last = H.history[#H.history]
    s.last = last and (last.time .. " " .. last.file .. " " .. (last.ok and "ok" or "error") .. " " .. tostring(last.text)) or "-"
    return s
end

-- The work -----------------------------------------------------------------------------------

local function luaOrder(a, b)
    local sa, sb = string.find(a, "/shared/", 1, true) ~= nil, string.find(b, "/shared/", 1, true) ~= nil
    if sa ~= sb then return sa end
    return string.lower(a) < string.lower(b)
end

local function firstLine(s)
    return string.match(tostring(s or ""), "^([^\n]*)") or ""
end

--- quiet: the check at the start (a build newer than the jar) - nothing to say when nothing changed
local function handle(s, quiet)
    local luas, lang, cmd, java = {}, false, false, false
    for line in string.gmatch(s, "[^\n]+") do
        local kind, path = string.match(line, "^(%w+)\t?(.*)$")
        if kind == "lua" then table.insert(luas, path)
        elseif kind == "lang" then lang = true
        elseif kind == "cmd" then cmd = true
        elseif kind == "java" then java = true end
    end
    local lines, bad = {}, false
    local javaDone, langDone = false, false

    if java then
        local res = knoxHotJava() or "none"
        local okN, errN = 0, {}
        -- (one line a reason - the whole build waits for one class, every class says the same)
        local restartBy, restartOrder = {}, {}
        for l in string.gmatch(res, "[^\n]+") do
            local st, cls, what = string.match(l, "^(%w+)\t([^\t]*)\t?(.*)$")
            local short = cls and (string.match(cls, "([^%.]+)$") or cls) or ""
            if st == "ok" then okN = okN + 1
            elseif st == "restart" then
                -- (Java says why by a word: shape, patch, package - after the class's name, for a patch)
                what = what or ""
                local key = string.find(what, "shape:", 1, true) and "IGUI_KnoxHot_Shape"
                    or string.find(what, "patch:", 1, true) and "IGUI_KnoxHot_Patch"
                    or string.find(what, "package:", 1, true) and "IGUI_KnoxHot_Package" or "?"
                if not restartBy[key] then
                    restartBy[key] = {}
                    table.insert(restartOrder, key)
                end
                table.insert(restartBy[key], short)
                print("[Knox] DEV reloader: " .. tostring(cls) .. ": " .. what)
            elseif st == "error" then table.insert(errN, short .. ": " .. tostring(what))
            elseif l == "none" then
                -- (built, nothing different from what the game has)
            elseif st == "off" or string.sub(l, 1, 3) == "off" then table.insert(errN, string.sub(l, 5)) end
        end
        javaDone = okN > 0
        if okN > 0 then table.insert(lines, {txt("IGUI_KnoxHot_Java", tostring(okN)) or ("Java: " .. okN), "ok"}) end
        for _, key in ipairs(restartOrder) do
            local names = table.concat(restartBy[key], ", ")
            local r = key ~= "?" and txt(key, names) or names
            table.insert(lines, {(txt("IGUI_KnoxHot_Restart", r) or ("Restart needed: " .. r)), "warn"})
            bad = true
        end
        for _, e in ipairs(errN) do
            table.insert(lines, {"Java: " .. e, "bad"})
            bad = true
        end
        remember("Java", #errN == 0 and #restartOrder == 0, res)
        if okN == 0 and #restartOrder == 0 and #errN == 0 and not quiet then table.insert(lines, {txt("IGUI_KnoxHot_JavaSame") or "Java: nothing new", nil}) end
    end

    if lang then
        local res = knoxHotLang()
        local ok = res == "ok"
        langDone = ok
        remember("translations", ok, res)
        table.insert(lines, {ok and (txt("IGUI_KnoxHot_Lang") or "Texts read again") or ("Texts: " .. tostring(res)), ok and "ok" or "bad"})
        if not ok then bad = true end
    end

    local done = {}
    if #luas > 0 then
        table.sort(luas, luaOrder)
        for _, path in ipairs(luas) do
            local res = knoxHotRun(path) or "error\t?"
            local status, rest = string.match(res, "^(%w+)\t(.*)$")
            local name = shortName(path)
            if status == "ok" then
                table.insert(done, path)
                remember(name, true, firstLine(rest))
                table.insert(lines, {txt("IGUI_KnoxHot_Updated", name .. "  " .. clock()) or ("Updated: " .. name), "ok"})
            else
                bad = true
                remember(name, false, rest)
                -- (the game's error text: "KnoxFoo.lua:123: attempt to..." - the first line is what to show)
                table.insert(lines, {(txt("IGUI_KnoxHot_Error", name) or ("Error: " .. name)), "bad"})
                table.insert(lines, {firstLine(rest), "bad"})
                print("[Knox] DEV reloader: " .. name .. ":\n" .. tostring(rest))
            end
            for w in string.gmatch(rest or "", "\nwarning\t([^\n]+)") do
                table.insert(lines, {name .. ": " .. w, "warn"})
            end
        end
    end

    if #done > 0 or langDone or javaDone then
        -- the Knox screen failed to open earlier (Knox.failed: the game's inventory till a
        -- restart) - the change may be the fix: Knox's screen is tried again
        if Knox and Knox.failed then
            Knox.failed = nil
            table.insert(lines, {txt("IGUI_KnoxHot_Retry") or "Knox screen: on again", "warn"})
        end
        -- Knox's sizes and fonts worked out again (KnoxTheme's own refresh), what a module
        -- sets up once set up anew, its windows open again
        local T = KnoxTheme
        if T and T.refresh and T.cell then pcall(T.refresh) end
        moduleHooks(done)
        local err = reopen(done)
        if err then
            table.insert(lines, {err, "bad"})
            bad = true
        end
    end

    if cmd then remote() end
    if #lines > 0 then note(lines, bad) end
end

-- (the game's thread: in the game every tick, paused too; in the main menu its own tick)
local nextPoll = 0
local function tick()
    local now = getTimestampMs()
    if now < nextPoll then return end
    nextPoll = now + 250
    local s = knoxHotPoll()
    if not s then return end
    local ok, err = pcall(handle, s)
    if not ok then print("[Knox] DEV reloader: " .. tostring(err)) end
end
-- (not timed by KnoxPerf, dev.perf=1: the reloader is the author's alone - Knox's numbers are
-- what players get)
local function addUntimed(name, fn)
    local P = KnoxPerf
    local add = P and P.origAdd and P.origAdd[name]
    if add then add(fn) else Events[name].Add(fn) end
end
addUntimed("OnTickEvenPaused", tick)
addUntimed("OnFETick", tick)

-- (the fast Java build newer than the jar the game started with: swapped in at once - the
-- author changed Java and started the game without building the jar again)
if not H.javaChecked and string.find(H.on, "java", 1, true) and knoxHotJavaNewer and knoxHotJavaNewer() then
    H.javaChecked = true
    local ok, err = pcall(handle, "java", true)
    if not ok then print("[Knox] DEV reloader: " .. tostring(err)) end
end
H.javaChecked = true

return H
