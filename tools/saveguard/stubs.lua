-- What KnoxSaveGuard.lua touches while it loads (tools/saveguard/test.ps1).
require = function() end
KnoxTheme = {active = true, MOD_ID = "KnoxInventory", MOD_IDS = {"KnoxInventory", "KnoxInventoryBeta"}}
Events = {OnMainMenuEnter = {Add = function() end}, OnTick = {Add = function() end, Remove = function() end}}
