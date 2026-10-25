-- Other mods Knox works alongside, found in one place.
--
-- Viewpoint (first and third person, Workshop 3809306528), OldPoint over it (an
-- overhead camera, 3815999052) and Project Viewpoint QOL (3811256204):
-- KnoxCompat.viewpoint() says whether they are here, their versions and which
-- of Viewpoint's insides Knox found. Each part of Knox's integration works only
-- when its own insides are there; a part whose insides are gone (a Viewpoint
-- version that changed them) is off, said in one line of console.txt - never an
-- error, and the other parts go on working.

KnoxCompat = KnoxCompat or {}
local C = KnoxCompat

local function modVersion(id)
    local ok, v = pcall(function()
        local info = getModInfoByID and getModInfoByID(id)
        return info and info:getModVersion()
    end)
    return ok and v or nil
end

local function words(s)
    local out = {}
    for w in string.gmatch(s or "", "%S+") do out[w] = true end
    return out
end

local vp = nil

--- What there is of Viewpoint: {present, version, oldpoint, oldpointVersion,
--- has = {part = true}, missing = "..."}. The Java parts (KnoxViewpoint.knoxViewpointParts):
--- cursor, look, view, rows, menu, panel, topdown, oldpoint. Looked up once (the jars
--- are loaded before any Lua runs).
function C.viewpoint()
    if vp then return vp end
    vp = {present = false, has = {}, missing = ""}
    if knoxViewpointParts then
        local s = knoxViewpointParts() or ""
        if s ~= "" then
            local found, missing = string.match(s, "^(.-)|(.*)$")
            vp.present = true
            vp.has = words(found)
            vp.missing = missing or ""
        end
    elseif knoxViewpointCursor then
        -- (a Java part older than v54: what it had worked without a look-up)
        vp.present = true
        vp.has = {cursor = true, look = true, view = true, rows = true}
    end
    if vp.present then
        vp.version = modVersion("Viewpoint")
        vp.oldpoint = vp.has.topdown == true or vp.has.oldpoint == true
        vp.oldpointVersion = vp.oldpoint and modVersion("OldPoint") or nil
    end
    return vp
end

--- Is this part of the integration on? (Viewpoint here and the part's insides found.)
function C.vpHas(part)
    local v = C.viewpoint()
    return v.present and v.has[part] == true
end

--- Is OldPoint's overhead camera on right now? It shows all around, as the game's camera does.
function C.topDown()
    return C.vpHas("topdown") and knoxViewpointTopDown ~= nil and knoxViewpointTopDown() == true
end

--- Is Viewpoint's first- or third-person view on right now (not its overhead one)?
function C.viewpointLooking()
    if not C.vpHas("view") or not knoxViewpointViewOn or knoxViewpointViewOn() ~= true then return false end
    return not C.topDown()
end

-- Lua parts, named for the log: a function of Viewpoint's that Knox wraps and is not there.
C.luaMissing = {}

--- The table's functions, all there? The names of those missing go to the log line.
function C.luaHas(tableName, t, names)
    if type(t) ~= "table" then
        table.insert(C.luaMissing, tableName)
        return false
    end
    local ok = true
    for _, n in ipairs(names) do
        if type(t[n]) ~= "function" then
            table.insert(C.luaMissing, tableName .. "." .. n)
            ok = false
        end
    end
    return ok
end

--- One line in console.txt when a game starts: what was found, what is off.
function C.report()
    local v = C.viewpoint()
    if not v.present then return end
    local on = {}
    for _, n in ipairs({"cursor", "look", "view", "rows", "menu", "panel", "topdown", "oldpoint"}) do
        if v.has[n] then table.insert(on, n) end
    end
    local off = v.missing
    if #C.luaMissing > 0 then off = (off ~= "" and off .. " " or "") .. table.concat(C.luaMissing, " ") end
    print("[Knox] Viewpoint " .. tostring(v.version or "?")
        .. (v.oldpoint and (", OldPoint " .. tostring(v.oldpointVersion or "?")) or "")
        .. (ViewpointQOL ~= nil and ", Project Viewpoint QOL" or "")
        .. ": " .. table.concat(on, " ")
        .. (off ~= "" and ("; off (not in this version): " .. off) or ""))
end

-- Knox's windows that want the mouse: with any of them open Viewpoint gives the
-- cursor (KnoxMain). By the name of their table; `instance` or a `list`.
local WINDOWS = {"KnoxTVWindow", "KnoxRadioWindow", "KnoxFluidWindow", "KnoxFluidInfo", "KnoxStoveWindow",
                 "KnoxSettings", "KnoxSplitDialog", "KnoxAlarmWindow", "KnoxFoundWindow", "KnoxSlotPicker",
                 "KnoxDevPanel", "KnoxTestBench", "KnoxStudio"}
local LISTS = {"KnoxInspectWindow", "KnoxContainerWindow"}

--- Is anything of Knox open that is worked with the mouse? (and which, for the log)
function C.windowOpen()
    if KnoxScreen and KnoxScreen.instance then return true, "KnoxScreen" end
    for _, name in ipairs(WINDOWS) do
        local w = _G[name]
        if w and w.instance then return true, name end
    end
    for _, name in ipairs(LISTS) do
        local w = _G[name]
        if w and w.list and #w.list > 0 then return true, name end
    end
    return false, nil
end

return C
