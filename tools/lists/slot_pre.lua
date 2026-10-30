-- What KnoxEquipment.lua needs to load outside the game, over tools/settings/stubs.lua
-- (tools/lists/slot.lua): its slot is a plain element, body locations named plainly.
ISUIElement = ISPanel
KnoxFootprint = {norm = function(s) return string.lower(tostring(s)) end}
function instanceof() return false end
KnoxTheme.refresh()
