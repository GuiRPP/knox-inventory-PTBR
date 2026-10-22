-- KnoxNet outside the game (tools/net/test.ps1): a server and two clients on stand-ins.
-- The "network" copies tables as the game's does; the server's syncItemModData wipes
-- and fills the modData of the same thing on the clients, as SyncItemModDataPacket does.

local N = KnoxNet
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else fail = fail + 1; print("FAIL " .. name .. (detail ~= nil and (" : " .. tostring(detail)) or "")) end
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

-- stand-ins: things, containers, squares, players ------------------------------------
local function list(t)
    local l = {t = t}
    function l:size() return #self.t end
    function l:get(i) return self.t[i + 1] end
    return l
end

-- one world per side (the server's and each client's), the same ids
local function world()
    local w = {items = {}, squares = {}}
    function w:container(kind, sq)
        local c = {items = {}, kind = kind, sq = sq}
        function c:getItems() return list(self.items) end
        function c:getType() return self.kind end
        function c:getContainingItem() return self.holder end
        function c:getOutermostContainer()
            local cc = self
            while cc.holder and cc.holder.container do cc = cc.holder.container end
            return cc
        end
        function c:getSourceGrid() return self.sq end
        function c:getParent() return nil end
        function c:getVehiclePart() return nil end
        function c:getItemWithIDRecursiv(id)
            for _, it in ipairs(self.items) do
                if it.id == id then return it end
                if it.inv then
                    local x = it.inv:getItemWithIDRecursiv(id)
                    if x then return x end
                end
            end
            return nil
        end
        function c:add(it) table.insert(self.items, it) it.container = self return it end
        return c
    end
    function w:item(id, bag)
        local it = {id = id, md = {}}
        function it:getID() return self.id end
        function it:getModData() return self.md end
        function it:getContainer() return self.container end
        function it:getWorldItem() return nil end
        if bag then
            it.inv = w:container("bag", nil)
            it.inv.holder = it
            function it:getInventory() return self.inv end
        end
        w.items[id] = it
        return it
    end
    function w:square(x, y, z)
        local sq = {x = x, y = y, z = z, objects = {}}
        function sq:getX() return self.x end
        function sq:getY() return self.y end
        function sq:getZ() return self.z end
        function sq:getObjects() return list(self.objects) end
        function sq:getDeadBodys() return list({}) end
        function sq:getWorldObjects() return list({}) end
        function sq:getVehicleContainer() return nil end
        w.squares[x .. "," .. y .. "," .. z] = sq
        return sq
    end
    function w:shelf(sq)
        local c = w:container("shelves", sq)
        local obj = {c = c}
        function obj:getContainerCount() return 1 end
        function obj:getContainerByIndex(i) return self.c end
        table.insert(sq.objects, obj)
        return c
    end
    function w:player(name, x, y)
        local p = {name = name, x = x, y = y, z = 0, inv = w:container("none", nil)}
        function p:getInventory() return self.inv end
        function p:getX() return self.x end
        function p:getY() return self.y end
        function p:getZ() return self.z end
        function p:getUsername() return self.name end
        function p:getDescriptor()
            return {getForename = function() return "Jo" end, getSurname = function() return self.name end}
        end
        return p
    end
    return w
end

-- the same world built three times: the server's and two clients'
local function build()
    local w = world()
    local sq = w:square(10, 10, 0)
    local shelf = w:shelf(sq)
    for id = 1, 5 do shelf:add(w:item(id)) end
    local bag = shelf:add(w:item(50, true))
    bag.inv:add(w:item(51))
    local a, b = w:player("anna", 11, 10), w:player("boris", 12, 11)
    a.inv:add(w:item(100))
    return w, a, b, shelf
end

local S, sA, sB = build()           -- the server's
local A, aA = build()               -- client A (anna)
local B, _, bB = build()            -- client B (boris)

-- the game's functions, per side --------------------------------------------------------
local side = "server"
local sent = {}          -- client -> server commands waiting
local toClient = {}      -- server -> client commands waiting: {who, module, command, args}

isClient = function() return side ~= "server" end
isServer = function() return side == "server" end
getSpecificPlayer = function() return side == "A" and aA or bB end
sendClientCommand = function(player, module, command, args)
    table.insert(sent, {who = side, module = module, command = command, args = copy(args)})
end
sendServerCommand = function(player, module, command, args)
    table.insert(toClient, {who = player == sA and "A" or "B", module = module, command = command, args = copy(args)})
end
getCell = function()
    return {getGridSquare = function(_, x, y, z) return S.squares[x .. "," .. y .. "," .. z] end}
end
local synced = {}
syncItemModData = function(player, item)
    table.insert(synced, item.id)
    -- the players near: both clients get the thing's modData as the server has it
    for _, w in ipairs({A, B}) do
        local it = w.items[item.id]
        if it then
            for k in pairs(it.md) do it.md[k] = nil end      -- (the packet wipes first)
            for k, v in pairs(copy(item.md)) do it.md[k] = v end
        end
    end
end
local stores = {}
ModData = {getOrCreate = function(name) stores[name] = stores[name] or {} return stores[name] end}
local files = {}
getFileReader = function(name)
    local text = files[name]
    if not text then return nil end
    local lines, i = {}, 0
    for l in string.gmatch(text, "[^\n]+") do table.insert(lines, l) end
    return {readLine = function() i = i + 1 return lines[i] end, close = function() end}
end
getFileWriter = function(name)
    local buf = {}
    return {write = function(_, s) table.insert(buf, s) end, close = function() files[name] = table.concat(buf) end}
end

--- Deliver what is waiting, as the network would (the server runs the clients' commands).
local function deliver()
    local s = sent
    sent = {}
    side = "server"
    for _, c in ipairs(s) do
        local player = c.who == "A" and sA or sB
        N.onClientCommand(c.module, c.command, player, c.args)
    end
    local t = toClient
    toClient = {}
    for _, c in ipairs(t) do
        side = c.who
        N.onServerCommand(c.module, c.command, c.args)
    end
end

-- 1. a place the player picks goes to the server and to the other player -------------------
side = "A"
local itA = A.items[3]
itA.md.knox = {k = "w10,10,0,shelves", x = 4, y = 1, r = 0}
N.itemChanged(itA, "knox")
N.flush()
deliver()
check("place: on the server", S.items[3].md.knox and S.items[3].md.knox.x == 4, S.items[3].md.knox and S.items[3].md.knox.x)
check("place: at the other player", B.items[3].md.knox and B.items[3].md.knox.x == 4)
check("place: one sync for one thing", #synced == 1 and synced[1] == 3, #synced)

-- 2. the place a thing is dropped at is on the server before it is moved -------------------
synced = {}
side = "A"
local own = A.items[100]
own.md.knoxP = {k = "w10,10,0,shelves", x = 0, y = 2, r = 1}
N.itemChanged(own, "knoxP")         -- (sent at once: no flush called)
check("pending: sent without waiting for the tick", #sent == 1, #sent)
deliver()
check("pending: on the server's thing in the pockets", S.items[100].md.knoxP and S.items[100].md.knoxP.r == 1)

-- 3. a place found by the grid: the first look of anyone wins ---------------------------------
synced = {}
-- (both clients share one KnoxNet here: each sends its own queue before the other writes)
side = "A"
A.items[1].md.knox = {k = "w10,10,0,shelves", x = 0, y = 0, r = 0}
N.itemChanged(A.items[1], "knox", true)
N.flush()
side = "B"
B.items[1].md.knox = {k = "w10,10,0,shelves", x = 6, y = 3, r = 0}
N.itemChanged(B.items[1], "knox", true)
N.flush()
deliver()
check("auto: the first one kept", S.items[1].md.knox.x == 0, S.items[1].md.knox.x)
check("auto: the second client gets the first one's", B.items[1].md.knox.x == 0, B.items[1].md.knox.x)
-- ...but a place the player picks always goes
side = "B"
B.items[1].md.knox = {k = "w10,10,0,shelves", x = 7, y = 3, r = 0}
N.itemChanged(B.items[1], "knox")
N.flush()
deliver()
check("auto: the player's own place over it", S.items[1].md.knox.x == 7 and A.items[1].md.knox.x == 7, S.items[1].md.knox.x)
-- the player's place and then the grid's for the same thing in one tick: the player's goes as the player's
side = "A"
A.items[2].md.knox = {k = "w10,10,0,shelves", x = 1, y = 1, r = 0}
N.itemChanged(A.items[2], "knox")
N.itemChanged(A.items[2], "knox", true)
check("auto: a pick stays a pick in the queue", N.out["2|knox"] and N.out["2|knox"].a == nil)
N.flush()
deliver()

-- 4. what the server refuses -----------------------------------------------------------------
side = "server"
local before = S.items[4].md.knox
N.serverItems(sA, {list = {
    {id = 4, k = "knox", v = {k = "w", x = 9999, y = 0}, x = 10, y = 10, z = 0},       -- off any grid
    {id = 4, k = "knoxLock", v = true, x = 10, y = 10, z = 0},                          -- not a field it takes
    {id = 5, k = "knox", v = "garbage", x = 10, y = 10, z = 0},
}})
check("refused: a place off any grid", S.items[4].md.knox == before)
check("refused: a field it doesn't take", S.items[4].md.knoxLock == nil)
check("refused: not a place", S.items[5].md.knox == nil)
-- too far away: boris standing 40 squares off
sB.x = 52
N.serverItems(sB, {list = {{id = 5, k = "knoxS", v = "far", x = 10, y = 10, z = 0}}})
check("refused: out of reach", S.items[5].md.knoxS == nil)
sB.x = 12
-- another player's pockets are not "p"
N.serverItems(sB, {list = {{id = 100, k = "knoxS", v = "theirs", p = 1}}})
check("refused: another player's thing as one's own", S.items[100].md.knoxS == nil)
-- taken away
N.serverItems(sA, {list = {{id = 3, k = "knox", v = "-", x = 10, y = 10, z = 0}}})
check("taken away: '-'", S.items[3].md.knox == nil)

-- 5. a thing in a bag on the shelf -----------------------------------------------------------
side = "A"
A.items[51].md.knoxS = "s1"
N.itemChanged(A.items[51], "knoxS")
N.flush()
deliver()
check("in a bag on the shelf: found by the server", S.items[51].md.knoxS == "s1")
check("in a bag on the shelf: sent by the shelf's square", true)
-- a bag's layout
side = "A"
A.items[50].md.knoxT = {main = {cols = 4, e = {{t = "Base.Nails", x = 0, y = 0, r = 0, w = 1, h = 1, c = "mat"}}}}
N.itemChanged(A.items[50], "knoxT")
N.flush()
deliver()
local tpl = S.items[50].md.knoxT
check("layout: kept by the server", tpl and tpl.main and tpl.main.cols == 4 and #tpl.main.e == 1)

-- 6. the character's own data ---------------------------------------------------------------
side = "A"
N.ready = false
for id = 1, 4500 do N.me.known[id] = nil end
local fake = {}
for id = 1, 4500 do
    fake.id = id
    N.setKnown({getID = function() return id end})
end
N.ready = true
N.setSeen("w10,10,0,shelves", true)
N.setLocked(A.items[2], true)
N.flushMe()
check("own: sent in parts", #sent == 3, #sent)
deliver()
local s = N.storeOf(sA)
local n = 0
for _ in pairs(s.known) do n = n + 1 end
check("own: the server knows what the character knows", n == 4500, n)
check("own: searched kept", s.seen["w10,10,0,shelves"] == true)
check("own: lock kept", s.locks[2] == true)
check("own: per character", N.storeOf(sB).locks[2] == nil)
-- a new game on that server: the data comes back in parts, then it is ready
N.me = {known = {}, seen = {}, locks = {}}
N.ready = false
side = "A"
sendClientCommand(aA, "Knox", "hello", {})
deliver()
local back = 0
for _ in pairs(N.me.known) do back = back + 1 end
check("hello: everything back", back == 4500 and N.me.seen["w10,10,0,shelves"] and N.me.locks[2], back)
check("hello: ready after the last part", N.ready == true)
check("hello: the server's sizes by default", N.scale == 100, N.scale)
-- unlock, unsee
N.setLocked(A.items[2], false)
N.setSeen("w10,10,0,shelves", false)
N.flushMe()
deliver()
check("own: unlocked", N.storeOf(sA).locks[2] == nil)
check("own: unsearched", N.storeOf(sA).seen["w10,10,0,shelves"] == nil)

-- 7. the server's sizes --------------------------------------------------------------------
files["knox_server.txt"] = "# x\ngrid.scale = 150\n"
files["knox_overrides.txt"] = "# notes\nshow_ids = yes\nBase.Katana = 1x5\n"
local got
KnoxFootprint = {useOverrides = function(lines) got = lines end}
side = "B"
sendClientCommand(bB, "Knox", "hello", {})
deliver()
check("config: the server's scale", N.scale == 150, N.scale)
check("config: its overrides, without comments or show_ids", got and #got == 1 and got[1] == "Base.Katana = 1x5", got and #got)
files["knox_server.txt"] = nil
side = "server"
N.serverConfig()
check("config: a template written for the server's admin", files["knox_server.txt"] ~= nil)
check("config: the template has the music lines", files["knox_server.txt"] and string.find(files["knox_server.txt"], "music.max_mb = 15", 1, true) ~= nil)
local m = N.serverMusic()
check("music: the template's values", m.share == 1 and m.files == 1 and m.max_mb == 15 and m.rate_kb == 128 and m.total_kb == 512 and m.cache_mb == 64)
files["knox_server.txt"] = "grid.scale = 100\nmusic.share = 0\nmusic.max_mb = 999\nmusic.rate_kb = 64\nmusic.cache_mb = 8\n"
m = N.serverMusic()
check("music: set, out of bounds kept at the default", m.share == 0 and m.max_mb == 15 and m.rate_kb == 64, m.max_mb)
check("music: the cache holds a file of the largest", m.cache_mb >= 21, m.cache_mb)
files["knox_server.txt"] = nil
check("music: no file, the defaults", N.serverMusic().share == 1)

-- 7b. a stack id tried and put back in one tick (KnoxActions.grab's dry run): the server
-- gets the one put back, not the one tried ----------------------------------------------------
side = "server"
S.items[5].md.knoxS = "s1"
A.items[5].md.knoxS = "s1"
side = "A"
sent = {}
N.out, N.outOrder = {}, {}
A.items[5].md.knoxS = "s9"
N.itemChanged(A.items[5], "knoxS", true)    -- (placeIn: joined a stack on a grid of its own)
A.items[5].md.knoxS = "s1"
N.itemChanged(A.items[5], "knoxS", true)    -- (put back, and told)
check("stack put back: one entry waiting", #N.outOrder == 1, #N.outOrder)
N.flush()
deliver()
check("stack put back: the server keeps the old one", S.items[5].md.knoxS == "s1", S.items[5].md.knoxS)
check("stack put back: the other player too", B.items[5].md.knoxS ~= "s9", B.items[5].md.knoxS)
-- none before the try: none after
side = "A"
A.items[4].md.knoxS = "s9"
N.itemChanged(A.items[4], "knoxS", true)
A.items[4].md.knoxS = nil
N.itemChanged(A.items[4], "knoxS", true)
N.flush()
deliver()
check("stack put back to none: none on the server", S.items[4].md.knoxS == nil, S.items[4].md.knoxS)

-- 8. alone nothing goes out -----------------------------------------------------------------
side = "server"   -- isClient() false: a game alone looks so too
sent = {}
N.out, N.outOrder = {}, {}
local alone = A.items[4]
alone.md.knox = {k = "x", x = 1, y = 1, r = 0}
N.itemChanged(alone, "knox")
N.flush()
check("alone: nothing sent", #sent == 0 and #N.outOrder == 0, #sent)

print(string.format("DONE pass=%d fail=%d", pass, fail))
