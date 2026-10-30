-- tools/menu/worldlook.lua: the game's words told apart from their keys (the menu
-- looks up only the keys that have a text).
function getText(key)
    if key == "ContextMenu_Vehicle_Smashwindow" then return "Smash %1" end
    return "~" .. key
end
