-- KnoxCompat.routeViewpointScreen on the game's Lua. JAVA below is Viewpoint 0.1.7's
-- viewpoint.interact.InventoryScreen and LootMenu's window keys, line for line, as far as
-- they talk to Lua: the key, the sidebar's ask, the frame.
local C = KnoxCompat
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info ~= nil and (": " .. tostring(info)) or "")) end
end

-- Viewpoint's Lua, as its files have it: its own screen, never to be shown here
local vp = {opened = {}, closed = 0, released = 0, selected = {}}
ViewpointInventory = {
    open = function(how) table.insert(vp.opened, how) return true end,
    close = function() vp.closed = vp.closed + 1 end,
    release = function() vp.released = vp.released + 1 end,
    up = function() return false end,
}
ViewpointLoot = {select = function(_, c) table.insert(vp.selected, c) end}
local asked = {}
Viewpoint = {Loot = {openScreen = function(tab) table.insert(asked, tab) return true end}}

-- Knox, as far as the route asks
local FLOOR, FRIDGE, FREEZER = {name = "floor"}, {name = "fridge"}, {name = "freezer"}
local forPlayer, builds, breaks = true, 0, false
local function closeScreen()
    KnoxScreen.instance = nil
end
KnoxScreen = {instance = nil}
Knox = {
    viewpointLookAfter = false,
    forPlayer = function() return forPlayer end,
    open = function(_, container)
        if breaks then return false end
        if not KnoxScreen.instance then
            builds = builds + 1
            KnoxScreen.instance = {close = closeScreen, on = nil}
        end
        if container then KnoxScreen.instance.on = container end
        return true
    end,
}
ISInventoryPage = {GetFloorContainer = function() return FLOOR end}
function knoxViewpointParts() return "menu|" end
function getModInfoByID() return nil end
function knoxViewpointChosen() return vp.chosen end
local PLAYER = {getPlayerNum = function() return 0 end}

local JAVA = {open = false, toggle = false, cursorLook = false, cursorFree = false}
local function javaOpen()
    if ViewpointInventory.open("screen") == true then
        JAVA.open = true
        JAVA.cursorFree = true
    end
end
local function javaClose()
    if not JAVA.open then return end
    JAVA.open = false
    JAVA.cursorLook = true
    ViewpointInventory.close()
end
local function javaLetGo()
    JAVA.open = false
    JAVA.cursorLook = true
    ViewpointInventory.release()
end
local function frame()
    local toggle = JAVA.toggle
    JAVA.toggle = false
    if JAVA.open and ViewpointInventory.up() ~= true then
        javaLetGo()
    elseif JAVA.open and toggle then
        javaClose()
    elseif toggle then
        javaOpen()
    end
end
local function tab() JAVA.toggle = true frame() frame() end
-- LootMenu.take for its window key: open, then the container looked at
local function lootKey(container)
    javaOpen()
    ViewpointLoot.select(PLAYER, container)
    frame()
end

check("a route with this Viewpoint", C.routeViewpointScreen() == true)
check("nothing missing", #C.luaMissing == 0, C.luaMissing[1])

-- Tab
tab()
check("Tab: Knox's screen", KnoxScreen.instance ~= nil)
check("Tab: not Viewpoint's", #vp.opened == 0)
check("Tab: Viewpoint frees the cursor", JAVA.open and JAVA.cursorFree)
check("Tab: back to looking after", Knox.viewpointLookAfter == true)
frame()
check("stays up", JAVA.open and KnoxScreen.instance ~= nil)
tab()
check("Tab again: closed", KnoxScreen.instance == nil and not JAVA.open and JAVA.cursorLook)
check("Tab again: Viewpoint's not asked", vp.closed == 0)

-- Esc: Knox closes it by itself
Knox.viewpointLookAfter = false
JAVA.cursorLook = false
tab()
KnoxScreen.instance:close()
frame()
check("Esc: Viewpoint lets go", not JAVA.open and JAVA.cursorLook)
check("Esc: the next Tab opens", (function() tab() return KnoxScreen.instance ~= nil and JAVA.open end)())
tab()

-- opened by a click in the world: the key still closes it, Viewpoint isn't told one is up
Knox.open(0, FRIDGE)
JAVA.toggle = true
frame()
check("a screen opened otherwise closes", KnoxScreen.instance == nil)
check("and Viewpoint's isn't up", JAVA.open == false)
local n = builds
JAVA.toggle = true
frame()
check("the next press opens", builds == n + 1 and JAVA.open)
tab()

-- Viewpoint's view switched off with the screen open: it lets go, the screen stays
tab()
javaLetGo()
check("view off: the screen stays", KnoxScreen.instance ~= nil and vp.released == 0)
KnoxScreen.instance:close()

-- the loot key: on what is looked at, the row chosen in the panel
n = builds
lootKey(FRIDGE)
check("loot key: one screen built", builds == n + 1, builds - n)
check("loot key: on the container", KnoxScreen.instance.on == FRIDGE)
check("loot key: not Viewpoint's", #vp.selected == 0)
javaClose()
vp.chosen = FREEZER
lootKey(FRIDGE)
check("the row chosen in Viewpoint's panel", KnoxScreen.instance.on == FREEZER)
javaClose()
KnoxCrosshair = {owned = true, chosen = function() return FRIDGE end}
lootKey(FREEZER)
check("the row chosen in Knox's panel", KnoxScreen.instance.on == FRIDGE)
javaClose()
KnoxCrosshair, vp.chosen = nil, nil
lootKey(nil)
check("the ground: the floor", KnoxScreen.instance.on == FLOOR)
javaClose()

-- the sidebar: the game's own click
check("bag: the game's click", Viewpoint.Loot.openScreen("character") == false and #asked == 0)
check("heart: the game's click", Viewpoint.Loot.openScreen("health") == false and #asked == 0)

-- Knox could not build its screen: Viewpoint's own, not nothing
breaks = true
tab()
check("failed: Viewpoint's own", #vp.opened == 1 and Knox.viewpointLookAfter == false, #vp.opened)
JAVA.open = false
breaks = false
vp.opened = {}

-- a controller, the tutorial: all Viewpoint's
forPlayer = false
ViewpointInventory.open("pad")
ViewpointLoot.select(PLAYER, FRIDGE)
check("not Knox's player: Viewpoint's", #vp.opened == 1 and vp.selected[1] == FRIDGE and KnoxScreen.instance == nil)
check("not Knox's player: its sidebar", Viewpoint.Loot.openScreen("health") == true and asked[1] == "health")
forPlayer = true

-- a Viewpoint before 0.1.7: the old route stays
ViewpointInventory = nil
check("no such screen: the old route", C.routeViewpointScreen() == false)
-- a Viewpoint with part of it gone: Viewpoint's own, said in the log
ViewpointInventory = {open = function() end}
C.luaMissing = {}
check("part of it gone: left alone", C.routeViewpointScreen() == true and #C.luaMissing == 3, #C.luaMissing)

print("DONE pass=" .. pass .. " fail=" .. fail)
