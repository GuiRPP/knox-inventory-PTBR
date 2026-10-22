-- What the character holds while drinking, for containers the game gives no
-- model for the hand.
--
-- The game shows a bottle in the hand by the item's StaticModel. Some two
-- dozen things that hold a liquid have none (a hair dye bottle washed out and
-- filled with water, perfume, cologne, disinfectant, the crafted bottle, a hot
-- water bottle, a trophy cup...): the character drank from an empty hand, in
-- the world and on the Knox screen alike. For those the model the item lies on
-- the ground with is put in the hand instead.

require "TimedActions/ISDrinkFluidAction"
require "Knox/KnoxTheme"

local start = ISDrinkFluidAction.start

function ISDrinkFluidAction:start()
    start(self)
    if not (KnoxTheme and KnoxTheme.on("inventory")) then return end
    local item = self.item
    if not item then return end
    local own = item:getStaticModel()
    if own and own ~= "" then return end                 -- the game has shown it itself
    local world = item:getWorldStaticModel()
    if not world or world == "" then return end
    local eat = item:getEatType()
    if eat == "Pot" or eat == "PotForged" then
        self:setOverrideHandModelsString(world, nil)     -- (pots are drunk from with the right hand)
    else
        self:setOverrideHandModelsString(nil, world)
    end
end
