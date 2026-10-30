-- Viewpoint's crosshair panel rows by KnoxContextMenu.worldLook (tools/menu/test.ps1;
-- the author, 2026-10-29: rows without the icons Knox has): the whole name; a sub
-- menu's option glued to the sub menu's name - by the option, then the sub menu; a
-- name with a thing in it by its start; the function behind it.
local K = KnoxContextMenu
local P = ISInventoryPaneContextMenu
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else
        fail = fail + 1
        print("FAIL " .. name .. " : " .. tostring(detail))
    end
end
local function iconPath(name, fn)
    local t = K.worldLook(name, fn)
    return t and t.path
end
local function icon(name) return "media/ui/knoxicons/menu_" .. name .. ".png" end
check("the whole name", iconPath("~ContextMenu_Drink") == icon("drink"), iconPath("~ContextMenu_Drink"))
check("a sub menu's option by its own", iconPath("~ContextMenu_Wash: ~ContextMenu_Yourself") == icon("wash_self"),
    iconPath("~ContextMenu_Wash: ~ContextMenu_Yourself"))
check("a thing in a sub menu by the sub menu", iconPath("~ContextMenu_Wash: Fingerless Gloves") == icon("wash"),
    iconPath("~ContextMenu_Wash: Fingerless Gloves"))
check("by the function behind it", iconPath("Something", P.onEatItems) == icon("eat"), iconPath("Something", P.onEatItems))
check("unknown - none", iconPath("Chicken Coop Info", function() end) == nil)
local _, g = K.worldLook("Smash Rear Window")
check("a name with a thing in it: its group as before", g == "danger", g)
print("worldlook: DONE pass=" .. pass .. " fail=" .. fail)
