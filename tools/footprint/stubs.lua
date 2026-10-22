-- What the mod's shared Lua expects from the game when it is loaded outside of it
-- (tools/footprint/gen.ps1, test.ps1): only what is touched at load time.
require = function() end
