-- What KnoxSlotPicker.lua needs to load outside the game, over tools/settings/stubs.lua
-- (tools/lists/picker.lua).
KnoxTooltip = {want = function() end}
KnoxControls = {mods = function() return "" end}
ISInventoryItem = {renderItemIcon = function(ui) ui:drawRect() end}
function ISPanel:drawTextureScaledAspect() end
KnoxTheme.refresh()
