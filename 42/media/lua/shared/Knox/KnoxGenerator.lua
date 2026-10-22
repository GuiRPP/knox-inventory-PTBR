-- The generator's rules that are Knox's, not the game's (shared: alone they run here,
-- in a game with others on the server).
--
-- A worn generator doesn't always start (the author, 2026-10-22, with the generator
-- window - mockup 17): the chance it fails is (0.6 - condition) / 0.6, at most 80 %
-- (30 % condition: half the pulls). From 60 % up it starts every time. The same rule
-- for every start - the Knox window's cord and the game's own menu (the author: "ок"
-- to one rule): the game's own was a coin flip at 50 % condition and below.
--
-- Working the generator from its window (the author, 2026-10-22, after the first
-- runs: each of the game's actions took the character so long that the window and the
-- character never matched): while the window is open the character crouches at the
-- generator in one endless action (KnoxGeneratorUse - the game's own "Loot" crouch, as
-- its generator actions have), and what is done in the window is done at once:
--   start  the cord's pull (the chance above)      stop   the switch to OFF
--   plug   the HOUSE lever (to plug in: Electricity 3 or the generator magazine read,
--          as the game's menu asks)
--   fuel   a can poured a little at a time (the window sends a portion every 250 ms)
-- Closing the window ends the action; walking off or any other action ends it and
-- closes the window. With others the window sends the command to the server, which
-- checks it, does it and answers ("result"); the generator's own sync tells everyone.

require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISActivateGenerator"

KnoxGenerator = KnoxGenerator or {}
local G = KnoxGenerator
G.MODULE = "KnoxGen"
G.POUR = 0.3        -- litres a portion (1.2 L a second: a full can in a few seconds)
G.REACH = 4         -- squares: farther, the server doesn't take the command

--- The chance a start fails, 0..0.8, for a condition of 0..100 (the game's).
function G.failChance(condition)
    local c = (tonumber(condition) or 0) / 100
    return math.max(0, math.min(0.8, (0.6 - c) / 0.6))
end

--- May the character plug a generator into a house? (the game's menu: Electricity 3,
--- or the generator magazine read)
function G.canPlug(player)
    return player:getPerkLevel(Perks.Electricity) >= 3 or player:isRecipeActuallyKnown("Generator")
end

local complete = ISActivateGenerator.complete
function ISActivateGenerator:complete()
    local gen = self.generator
    if not gen or not self.activate then return complete(self) end
    if ZombRandFloat(0, 1) < G.failChance(gen:getCondition()) then
        gen:failToStart()
        self.knoxFailed = true
    else
        gen:setActivated(true)
    end
    gen:sync()
    return true
end

-- The window's commands ---------------------------------------------------------------

local function petrolIn(item)
    local fc = item and item:getFluidContainer()
    return fc ~= nil and fc:contains(Fluid.Petrol) and fc or nil
end

--- Do `cmd` to `gen` for `player`, where the world is kept. Returns what came of it:
--- {ok = true} or {ok = false, why = "..."}, for the start its chance, for the fuel what
--- is left in the can and whether the tank is full.
function G.apply(player, gen, cmd, args)
    if not gen or gen:getObjectIndex() == -1 then return {ok = false, why = "gone"} end
    args = args or {}
    if cmd == "start" then
        if gen:isActivated() then return {ok = false, why = "running"} end
        if gen:getFuel() <= 0 or gen:getCondition() <= 0 or not gen:isConnected() then return {ok = false, why = "cant"} end
        local chance = G.failChance(gen:getCondition())
        if ZombRandFloat(0, 1) < chance then
            gen:failToStart()
            gen:sync()
            return {ok = false, why = "fail", chance = chance}
        end
        gen:setActivated(true)
        gen:sync()
        return {ok = true}
    elseif cmd == "stop" then
        if gen:isActivated() then
            gen:setActivated(false)
            gen:sync()
        end
        return {ok = true}
    elseif cmd == "plug" then
        local plug = args.plug == true
        if gen:isActivated() then return {ok = false, why = "running"} end
        if plug and not G.canPlug(player) then return {ok = false, why = "skill"} end
        gen:setConnected(plug)
        gen:sync()
        return {ok = true}
    elseif cmd == "fuel" then
        local item = player:getInventory():getItemWithIDRecursiv(tonumber(args.id) or -1)
        local fc = petrolIn(item)
        if not fc then return {ok = false, why = "nopetrol"} end
        local room = gen:getMaxFuel() - gen:getFuel()
        if room <= 0.001 then return {ok = false, why = "full"} end
        local take = math.min(tonumber(args.amount) or G.POUR, fc:getAmount(), room)
        if take <= 0 then return {ok = false, why = "empty"} end
        fc:adjustAmount(fc:getAmount() - take)
        item:syncItemFields()
        gen:setFuel(gen:getFuel() + take)
        gen:sync()
        return {ok = true, left = fc:getAmount(), full = gen:getFuel() >= gen:getMaxFuel() - 0.001}
    end
    return {ok = false, why = "unknown"}
end

--- From the window: alone, done here and its outcome returned; with others, sent to
--- the server (nil returned - the answer comes as "result", G.onServerCommand).
function G.act(player, gen, cmd, args)
    if isClient() then
        args = args or {}
        local sq = gen:getSquare()
        if not sq then return nil end
        args.x, args.y, args.z = sq:getX(), sq:getY(), sq:getZ()
        sendClientCommand(player, G.MODULE, cmd, args)
        return nil
    end
    return G.apply(player, gen, cmd, args)
end

function G.onClientCommand(module, command, player, args)
    if module ~= G.MODULE or not player or not isServer() or type(args) ~= "table" then return end
    local sq = getCell():getGridSquare(tonumber(args.x) or 0, tonumber(args.y) or 0, tonumber(args.z) or 0)
    local gen = sq and sq:getGenerator()
    if not gen or player:DistTo(sq:getX(), sq:getY()) > G.REACH then return end
    local res = G.apply(player, gen, command, args)
    res.cmd = command
    sendServerCommand(player, G.MODULE, "result", res)
end

function G.onServerCommand(module, command, args)
    if module ~= G.MODULE or command ~= "result" or type(args) ~= "table" then return end
    local w = KnoxGeneratorWindow and KnoxGeneratorWindow.instance
    if w and w.onResult then w:onResult(args.cmd, args) end
end

if Events then
    if Events.OnClientCommand then Events.OnClientCommand.Add(G.onClientCommand) end
    if Events.OnServerCommand then Events.OnServerCommand.Add(G.onServerCommand) end
end

-- At the generator: one endless action while its window is open --------------------------

KnoxGeneratorUse = ISBaseTimedAction:derive("KnoxGeneratorUse")
local U = KnoxGeneratorUse

--- The Knox window open on this generator (client side; nil on the server).
local function windowOf(gen)
    local w = KnoxGeneratorWindow and KnoxGeneratorWindow.instance
    if w and w.gen == gen and not w.foldMs then return w end
    return nil
end

function U:isValid()
    return self.generator ~= nil and self.generator:getObjectIndex() ~= -1
end

function U:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function U:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

--- Pouring a can (the window's): the game's own refuelling - its animation, the can in
--- the hands, as ISAddFuel shows it (the author, 2026-10-22: "as it was before"); nil:
--- back to the crouch, with what the hands hold.
function U:pouring(item)
    if item then
        self:setActionAnim("refuelgascan")
        self:setOverrideHandModels(item:getStaticModel(), nil)
    else
        self:setActionAnim("Loot")
        self.character:SetVariable("LootPosition", "Low")
        self:setOverrideHandModels(self.character:getPrimaryHandItem(), self.character:getSecondaryHandItem())
    end
end

function U:update()
    self.character:faceThisObject(self.generator)
    if isServer() then return end
    -- the window closed, or another action waits behind this one: done
    local q = ISTimedActionQueue.getTimedActionQueue(self.character)
    if not windowOf(self.generator) or (q and q.queue and #q.queue > 1) then self:forceComplete() end
end

--- Over in any way: the window goes with it.
local function closeWindow(self)
    local w = windowOf(self.generator)
    if w then w:close() end
end

function U:stop()
    closeWindow(self)
    ISBaseTimedAction.stop(self)
end

function U:perform()
    closeWindow(self)
    ISBaseTimedAction.perform(self)
end

function U:new(character, generator)
    local o = ISBaseTimedAction.new(self, character)
    o.generator = generator
    o.maxTime = -1
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

return KnoxGenerator
