-- What KnoxHotbar.lua needs to load outside the game, over tools/settings/stubs.lua
-- (tools/lists/hotbar.lua): the game's ISHotbar as far as it goes, and the module on.
local T = KnoxTheme
T.on = function() return true end
T.refresh()

function instanceof(o, kind) return o.kind == kind end
ISMouseDrag = {}
JoypadState = {players = {}}
Knox = {forPlayer = function() return true end}
KnoxSlotPicker = {isOpenFor = function(owner) return KnoxSlotPicker.instance ~= nil and KnoxSlotPicker.instance.owner == owner end, want = function() end}
KnoxTooltip = {want = function() end}
KnoxEquip = {candidates = function() return {} end}
ISEquippedItem = {}
function getPlayerScreenLeft() return 0 end
function getPlayerScreenWidth() return 1920 end
function getTextOrNull() return nil end

ISHotbar = ISPanel:derive("ISHotbar")
function ISHotbar:setSizeAndPosition() end
function ISHotbar:getSlotForKey() return -1 end
function ISHotbar:update() end
function ISHotbar:attachItem() end
function ISHotbar:removeItem() end
function ISHotbar:refresh() end
function ISHotbar:render() end
-- (the game's own)
function ISHotbar:getSlotIndexAt(x, y)
    if x >= 0 and x < self.width and y >= 0 and y < self.height then
        local index = math.floor((x - self.margins) / (self.slotWidth + self.slotPad)) + 1
        index = math.max(index, 1)
        return math.min(index, #self.availableSlot)
    end
    return -1
end
function getMouseX() return 0 end
function getMouseY() return 0 end
