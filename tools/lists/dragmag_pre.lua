-- What KnoxDrag.lua needs of the game as it loads (for tools/lists/dragmag.lua).
ISUIElement = ISUIElement or {}
function ISUIElement:derive() local c = {} c.__index = c setmetatable(c, {__index = self}) return c end
KnoxGrid = KnoxGrid or {}
