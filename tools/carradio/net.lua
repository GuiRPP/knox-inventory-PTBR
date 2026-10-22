-- tools\carradio\net.lua: KnoxMusicNet.lua (own music heard by the others) on the game's
-- own Lua, outside the game: a server and two clients in one Lua, each with a copy of
-- the module of its own (loaded three times), the network a queue between them that
-- keeps to the game's rules (TableNetworkUtils' types, a string's 32767 bytes,
-- MaxPacketsPerSecond of a client), the Java part stubbed (files, parts, slots).
-- Run by test.ps1 as: LuaRun net.lua MN_PATH=<KnoxMusicNet.lua>.

local SRC = readfile(MN_PATH)
assert(SRC, "no " .. tostring(MN_PATH))
local G = _G
assert(G, "no _G")

local pass, fail = 0, 0
local function check(what, ok)
    if ok then pass = pass + 1 else fail = fail + 1; print("FAIL " .. what) end
end

local clock = 5000000
local NET_ERRORS = {}

-- the world: cars and players, the same objects on every side -------------------------

local function car(id, key, x)
    local dd = {on = true, power = true}
    function dd:getIsTurnedOn() return self.on end
    function dd:canBePoweredHere() return self.power end
    function dd:getBaseVolumeRange() return 20 end
    local part = {}
    function part:getInventoryItem() return true end
    function part:getDeviceData() return dd end
    local v = {id = id, key = key, x = x, y = 0, open = 0, dd = dd}
    function v:getId() return self.id end
    function v:getKeyId() return self.key end
    function v:getPartById() return part end
    function v:getX() return self.x end
    function v:getY() return self.y end
    function v:getZ() return 0 end
    return v
end
local CAR1, CAR2 = car(7, 1111, 0), car(9, 2222, 40)

local function player(oid, role, x)
    local p = {oid = oid, role = role, x = x, y = 0, veh = nil}
    function p:getOnlineID() return self.oid end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return 0 end
    function p:getVehicle() return self.veh end
    return p
end

-- the network ---------------------------------------------------------------------------

local queue = {}
local sent = {}   -- client -> list of send times (the game's packet limit is per second)
local maxRate = 0

local function copy(v, depth)
    local t = type(v)
    if t == "string" then
        if #v > 32767 then table.insert(NET_ERRORS, "string of " .. #v .. " bytes") end
        return v
    elseif t == "number" or t == "boolean" then
        return v
    elseif t == "table" then
        if depth > 8 then table.insert(NET_ERRORS, "too deep") return nil end
        local out = {}
        for k, x in pairs(v) do
            if type(k) ~= "string" and type(k) ~= "number" then table.insert(NET_ERRORS, "key " .. type(k)) end
            out[k] = copy(x, depth + 1)
        end
        return out
    end
    table.insert(NET_ERRORS, "value " .. t)
    return nil
end

local ROLES = {}
local NAMES = {"isClient", "isServer", "getSpecificPlayer", "getOnlinePlayers", "sendClientCommand", "sendServerCommand",
    "getVehicleById", "getCore", "KnoxTheme", "KnoxCarRadio", "KnoxMenuMusic", "KnoxNet", "Events", "KnoxMusicNet",
    "knoxNetHash", "knoxNetChunk", "knoxNetHave", "knoxNetRecvBegin", "knoxNetRecv", "knoxNetRecvState", "knoxNetRecvNext",
    "knoxNetRecvCancel", "knoxNetForget", "knoxNetPlay", "knoxNetVolume", "knoxNetMuffle", "knoxNetLowPass", "knoxNetPause",
    "knoxNetSeek", "knoxNetPosition", "knoxNetPlaying", "knoxNetStop", "knoxNetStopAll",
    "knoxMusicPosition", "knoxMusicLength", "knoxMusicParkedPosition", "knoxMusicParkedLength"}

local function as(role, f, ...)
    for _, k in ipairs(NAMES) do G[k] = role.G[k] end
    return f(...)
end

function getTimestampMs() return clock end

-- the server's settings (knox_server.txt)
local SCFG

-- the fake files: a "base64" part is its right length, the first one a head of its kind,
-- the rest filled with the part's own letter (so a part in the wrong place shows)
local CHUNK = 16384
local function b64len(sz, i) return 4 * math.ceil(math.min(CHUNK, sz - i * CHUNK) / 3) end
local function encode(file, i)
    local n = b64len(file.sz, i)
    local fill = string.rep(string.char(65 + i % 26), n)
    if i == 0 then return file.head .. string.sub(fill, #file.head + 1) end
    return fill
end
local function hexOf(c) return string.rep(c, 64) end

local FILES = {
    a = {h = hexOf("a"), sz = 5 * CHUNK + 100, ext = "mp3", head = "SUQz", len = 180000},
    b = {h = hexOf("b"), sz = 6 * CHUNK + 7, ext = "ogg", head = "T2dnUw", len = 200000},
    big = {h = hexOf("c"), sz = 20 * 1048576, ext = "mp3", head = "SUQz", len = 300000},
    fake = {h = hexOf("d"), sz = 3 * CHUNK, ext = "mp3", head = "TVpQ", len = 100000},   -- "MZ..." said to be an mp3
}

-- a client's Java part ------------------------------------------------------------------

local function javaOf(X)
    local J = {}
    X.own, X.cache, X.recv, X.slots = {}, {}, {}, {}
    function J.knoxNetHash(name)
        local f = X.files[name]
        if not f then return nil end
        if (X.pending[name] or 0) > 0 then X.pending[name] = X.pending[name] - 1 return "" end
        X.own[f.h] = f
        return f.h .. "|" .. f.sz .. "|" .. f.ext
    end
    function J.knoxNetChunk(h, i)
        local f = X.own[h]
        if not f or i < 0 or i * CHUNK >= f.sz then return nil end
        X.chunksRead = (X.chunksRead or 0) + 1
        return encode(f, i)
    end
    local function find(h)
        for _, f in pairs(FILES) do if f.h == h then return f end end
        return nil
    end
    function J.knoxNetHave(h, sz, ext)
        if #h ~= 64 then return -2 end
        if X.cache[h] then return 1 end
        for _, f in pairs(X.files) do if f.h == h then return 1 end end
        if X.recv[h] and X.recv[h].state == 2 then return -1 end
        return 0
    end
    function J.knoxNetRecvBegin(h, sz, ext)
        if X.recv[h] and X.recv[h].state > 0 then return true end
        X.recv[h] = {sz = sz, ext = ext, n = math.ceil(sz / CHUNK), got = {}, count = 0, state = 1}
        X.begins = (X.begins or 0) + 1
        return true
    end
    function J.knoxNetRecv(h, i, d)
        local r = X.recv[h]
        if not r or r.state == -1 then return -1 end
        if r.state ~= 1 then return 0 end
        local f = find(h)
        local want = f and encode(f, i)
        if d ~= want then r.state = -1 return -1 end
        if not r.got[i] then r.got[i] = true r.count = r.count + 1 end
        if r.count < r.n then return 0 end
        r.state, r.doneAt = 2, clock + 100
        return 2
    end
    function J.knoxNetRecvState(h)
        local r = X.recv[h]
        if not r then return 0 end
        if r.state == 2 and clock >= r.doneAt then r.state = 3 X.cache[h] = true end
        if r.state == 3 or r.state == -1 then X.recv[h] = nil end
        return r.state
    end
    function J.knoxNetRecvNext(h)
        local r = X.recv[h]
        if not r or r.state ~= 1 then return -1 end
        for i = 0, r.n - 1 do if not r.got[i] then return i end end
        return -1
    end
    function J.knoxNetRecvCancel(h) X.recv[h] = nil end
    function J.knoxNetForget(h) X.cache[h] = nil end
    local function pos(s) return s.pos + ((s.paused) and 0 or (clock - s.since)) end
    function J.knoxNetPlay(slot, h, p, vol, paused)
        if not (X.cache[h] or J.knoxNetHave(h, 1, "mp3") == 1) then return false end
        local f = find(h)
        X.slots[slot] = {h = h, pos = p, since = clock, vol = vol, paused = paused, dark = nil, len = f and f.len or 1e9}
        return true
    end
    function J.knoxNetVolume(slot, v) if X.slots[slot] then X.slots[slot].vol = v end end
    function J.knoxNetMuffle(slot, d, o) if X.slots[slot] then X.slots[slot].dark, X.slots[slot].open = d, o end end
    function J.knoxNetLowPass(slot, g) if X.slots[slot] then X.slots[slot].lp = g end end
    function J.knoxNetPause(slot, b)
        local s = X.slots[slot]
        if not s then return end
        s.pos, s.since, s.paused = pos(s), clock, b
    end
    function J.knoxNetSeek(slot, ms)
        local s = X.slots[slot]
        if s then s.pos, s.since = ms, clock X.seeks = (X.seeks or 0) + 1 end
    end
    function J.knoxNetPosition(slot) return X.slots[slot] and pos(X.slots[slot]) or 0 end
    function J.knoxNetPlaying(slot) local s = X.slots[slot] return s ~= nil and pos(s) < s.len end
    function J.knoxNetStop(slot) X.slots[slot] = nil end
    function J.knoxNetStopAll() X.slots = {} end
    -- the owner's own tracks (KnoxMusic)
    function J.knoxMusicPosition() return X.main and (X.main.pos + (X.main.paused and 0 or clock - X.main.since)) or 0 end
    function J.knoxMusicLength() return X.main and X.main.len or 0 end
    function J.knoxMusicParkedPosition() return X.park and (X.park.pos + (clock - X.park.since)) or 0 end
    function J.knoxMusicParkedLength() return X.park and X.park.len or 0 end
    return J
end

--- The slot of client X playing hash h, or nil.
local function slotOf(X, h)
    for s, v in pairs(X.slots) do if v.h == h then return v, s end end
    return nil
end
local function slotCount(X)
    local n = 0
    for _ in pairs(X.slots) do n = n + 1 end
    return n
end

-- the sides ------------------------------------------------------------------------------

local SERVER, A, B
local PA, PB

local function events(role)
    role.handlers = {OnClientCommand = {}, OnServerCommand = {}, OnTick = {}, OnGameStart = {}}
    local E = {}
    for name, list in pairs(role.handlers) do E[name] = {Add = function(f) table.insert(list, f) end} end
    return E
end

local function onlineList()
    local list = {}
    for _, p in ipairs({PA, PB}) do if not p.gone then table.insert(list, p) end end
    return {size = function() return #list end, get = function(_, i) return list[i + 1] end}
end

local function makeClient(name, p, files)
    local X = {name = name, p = p, files = files, pending = {}, switches = {musicShare = true, musicHear = true}, others = 70}
    X.G = {}
    local J = javaOf(X)
    for k, f in pairs(J) do X.G[k] = f end
    X.G.isClient = function() return true end
    X.G.isServer = function() return false end
    X.G.getSpecificPlayer = function() return p end
    X.G.sendClientCommand = function(pl, module, cmd, args)
        local t = sent[name] or {}
        sent[name] = t
        table.insert(t, clock)
        local n = 0
        for _, at in ipairs(t) do if clock - at < 1000 then n = n + 1 end end
        if n > maxRate then maxRate = n end
        if n > 300 then table.insert(NET_ERRORS, name .. ": over MaxPacketsPerSecond") return end
        table.insert(queue, {to = SERVER, from = pl, module = module, cmd = cmd, args = copy(args, 0), at = clock})
    end
    X.vehicles = {[CAR1.id] = CAR1, [CAR2.id] = CAR2}
    X.G.getVehicleById = function(id) return X.vehicles[id] end
    X.G.getCore = function() return {getOptionSoundVolume = function() return 8 end} end
    X.G.KnoxTheme = {
        switch = function(k) return X.switches[k] == true end,
        look = function(k) return k == "music.others" and X.others or 100 end,
    }
    -- the owner's player (KnoxCarRadio, KnoxMenuMusic), as far as KnoxMusicNet reads it
    local R = {vehicle = nil, parked = nil}
    function R.data() return R.vehicle and R.vehicle.dd or nil end
    function R.openness(v) return v.open end
    local MM = {ctx = "car", active = true, playing = nil, paused = false, hold = false}
    function MM.theme() return "mine" end
    function MM.carAllowed() return R.vehicle ~= nil and R.vehicle.dd.on and R.vehicle.dd.power end
    function MM.vol() return 0.8 end
    function MM.radioOn() return X.fx == true end
    X.R, X.MM = R, MM
    X.G.KnoxCarRadio, X.G.KnoxMenuMusic = R, MM
    X.G.Events = events(X)
    return X
end

local function makeServer()
    local S = {name = "server", G = {}}
    S.G.isClient = function() return false end
    S.G.isServer = function() return true end
    S.G.getOnlinePlayers = onlineList
    S.G.sendServerCommand = function(pl, module, cmd, args)
        local to = pl.role == "A" and A or B
        if pl.gone then return end
        table.insert(queue, {to = to, module = module, cmd = cmd, args = copy(args, 0), at = clock})
    end
    S.G.getVehicleById = function(id)
        if id == CAR1.id then return CAR1 elseif id == CAR2.id then return CAR2 end
        return nil
    end
    S.G.KnoxNet = {serverMusic = function()
        local m = {}
        for k, v in pairs(SCFG) do m[k] = v end
        return m
    end}
    S.G.Events = events(S)
    return S
end

local function load(role)
    role.G.KnoxMusicNet = nil
    as(role, function()
        KnoxMusicNet = nil
        local f = loadstring(SRC, "KnoxMusicNet.lua")
        f()
        role.MN = KnoxMusicNet
    end)
    role.G.KnoxMusicNet = role.MN
end

--- A new game: the server, A (the owner) and B (the listener), as given.
local function game(cfg, filesA, filesB)
    SCFG = {share = 1, files = 1, max_mb = 15, rate_kb = 128, total_kb = 512, cache_mb = 64}
    for k, v in pairs(cfg or {}) do SCFG[k] = v end
    queue, sent = {}, {}
    PA, PB = player(1, "A", 2), player(2, "B", 5)
    CAR1.dd.on, CAR1.dd.power, CAR1.open, CAR2.dd.on = true, true, 0, true
    SERVER = makeServer()
    A = makeClient("A", PA, filesA or {["a.mp3"] = FILES.a, ["b.mp3"] = FILES.b, ["big.mp3"] = FILES.big, ["fake.mp3"] = FILES.fake})
    B = makeClient("B", PB, filesB or {["mine.mp3"] = FILES.a})
    load(SERVER)
    load(A)
    load(B)
end

local function deliver()
    local q = queue
    queue = {}
    for _, m in ipairs(q) do
        if m.to == SERVER then
            as(SERVER, function()
                for _, f in ipairs(SERVER.handlers.OnClientCommand) do f(m.module, m.cmd, m.from, m.args) end
            end)
        else
            as(m.to, function()
                for _, f in ipairs(m.to.handlers.OnServerCommand) do f(m.module, m.cmd, m.args) end
            end)
        end
    end
end

--- ms of the game: 50 ms ticks, each side's OnTick, then what was sent arrives.
local function run(ms)
    local steps = math.max(1, math.floor(ms / 50))
    for _ = 1, steps do
        clock = clock + 50
        for _, role in ipairs({SERVER, A, B}) do
            as(role, function()
                for _, f in ipairs(role.handlers.OnTick) do f() end
            end)
        end
        deliver()
    end
end

--- The owner plays a file in its car (KnoxMenuMusic's state as it is then).
local function ownerPlays(X, name, at)
    X.R.vehicle = X.R.vehicle or CAR1
    X.MM.playing = {kind = "file", name = name}
    X.MM.paused = false
    local f = X.files[name]
    X.main = {pos = at or 0, since = clock, paused = false, len = f.len}
end

local function any(t) for _ in pairs(t) do return true end return false end
local function near(a, b, tol) return math.abs(a - b) <= tol end

-- 1. both have the file: heard at once, in time, from outside ------------------------------
game()
run(1000)
check("A has the server's settings", A.MN.C.cfg ~= nil and A.MN.C.cfg.share == true)
check("B has them too", B.MN.C.cfg ~= nil and B.MN.C.cfg.files == true)
PA.veh = CAR1
ownerPlays(A, "a.mp3", 30000)
run(600)
local s = slotOf(B, FILES.a.h)
check("B plays A's track (its own copy)", s ~= nil)
check("B: no download for a file it has", B.begins == nil)
check("B: in time with A (1 s)", s and near(B.G.knoxNetPosition(0), A.G.knoxMusicPosition(), 1000))
check("B: from outside the car, muffled", s and s.dark ~= nil and s.dark >= 0 and s.vol > 0)
local volNear = s and s.vol or 0
check("server keeps one stream", any(SERVER.MN.S.streams))

-- 2. the owner's pause, wind, volume -----------------------------------------------------------
A.MM.paused = true
A.main.pos, A.main.since, A.main.paused = A.G.knoxMusicPosition(), clock, true
run(700)
s = slotOf(B, FILES.a.h)
check("pause: B paused within a second", s and s.paused == true)
A.MM.paused = false
A.main.since, A.main.paused = clock, false
run(700)
s = slotOf(B, FILES.a.h)
check("resume: B plays", s and s.paused == false)
A.main.pos, A.main.since = 120000, clock
run(700)
check("seek: B at A's place (1 s)", near(B.G.knoxNetPosition(0), A.G.knoxMusicPosition(), 1000))

-- 3. distance, doors, passenger -----------------------------------------------------------------
PB.x = 15
run(400)
s = slotOf(B, FILES.a.h)
check("farther: quieter, darker", s and s.vol < volNear and s.dark > 0.5)
local shutVol = s and s.vol or 0
CAR1.open = 1
run(400)
s = slotOf(B, FILES.a.h)
check("a door open: louder", s and s.vol > shutVol and s.open == 1)
CAR1.open = 0
PB.x = 60
run(1500)
check("out of range: B stops, the server says off", slotCount(B) == 0 and not any(B.MN.C.heard))
PB.x = 5
run(1500)
check("back near: B plays again, in time", slotOf(B, FILES.a.h) ~= nil and near(B.G.knoxNetPosition(0), A.G.knoxMusicPosition(), 1000))
PB.veh = CAR1
run(400)
s = slotOf(B, FILES.a.h)
check("passenger: as from inside", s and s.dark == -1 and s.lp == 1)
A.fx = true
run(700)
s = slotOf(B, FILES.a.h)
check("passenger, the radio's sound on: highs cut", s and s.lp < 1)
A.fx = false
PB.veh = nil

-- 4. a stale state after a newer one is dropped ------------------------------------------------
local rec = B.MN.C.heard["1|1"]
local nWas = rec and rec.n
as(B, function() B.MN.onState({o = 1, slot = 1, veh = 7, key = 1111, h = FILES.a.h, sz = FILES.a.sz, ext = "mp3", pos = 1, len = 180000, pl = true, vol = 0.8, rng = 21, n = 1}) end)
check("older state dropped", rec and rec.n == nWas and rec.pos ~= 1)

-- 5. the next track B lacks: through the server, in parts ---------------------------------------
ownerPlays(A, "b.mp3", 0)
run(3000)
check("B fetched b in parts", B.cache[FILES.b.h] == true)
check("A read each part once (the server keeps them)", A.chunksRead == 7)
check("B plays b, in time", slotOf(B, FILES.b.h) ~= nil and near(B.G.knoxNetPosition(select(2, slotOf(B, FILES.b.h))), A.G.knoxMusicPosition(), 1000))
check("the server keeps b", SERVER.MN.S.files[FILES.b.h] and SERVER.MN.S.files[FILES.b.h].got == 7)
check("no string over 32767 bytes, nothing the game can't send", #NET_ERRORS == 0)
check("packets per second well under the limit", maxRate < 60)

-- 6. the set off, no power ---------------------------------------------------------------------
CAR1.dd.on = false
run(250)
check("set off: B quiet at once", slotCount(B) == 0)
run(800)
check("set off: the owner said off", not any(SERVER.MN.S.streams) and not any(B.MN.C.heard))
CAR1.dd.on = true
run(1500)
check("set on again: B hears again", slotOf(B, FILES.b.h) ~= nil)
CAR1.dd.power = false
run(1200)
check("no power: off for all", slotCount(B) == 0 and not any(SERVER.MN.S.streams))
CAR1.dd.power = true
run(1000)

-- 7. the parked car: both heard ------------------------------------------------------------------
A.R.parked = {vehicle = CAR2, playing = true, list = {{name = "a.mp3", kind = "file"}}, at = 1, range = 25, hold = false}
A.park = {pos = 5000, since = clock, len = 180000}
PB.x = 20
run(1500)
check("parked and main both heard", slotOf(B, FILES.a.h) ~= nil and slotOf(B, FILES.b.h) ~= nil)
check("two streams on the server", SERVER.MN.S.streams["1|1"] ~= nil and SERVER.MN.S.streams["1|2"] ~= nil)
A.R.parked = nil
A.park = nil
run(1000)
check("parked stopped: off for B", slotOf(B, FILES.a.h) == nil and SERVER.MN.S.streams["1|2"] == nil)
PB.x = 5

-- 8. a car id given anew (another car under that id for B) ----------------------------------
B.vehicles[7] = car(7, 9999, 0)
run(600)
check("another car under the id: quiet", slotCount(B) == 0)
B.vehicles[7] = CAR1
run(600)
check("the right car back: heard", slotOf(B, FILES.b.h) ~= nil)

-- 9. a file over the limit: not fetched; a fake head: not kept ---------------------------------------
ownerPlays(A, "big.mp3", 0)
run(1500)
check("over max_mb: B fetches nothing, plays nothing", B.recv[FILES.big.h] == nil and slotCount(B) == 0)
check("over max_mb: the server keeps nothing", SERVER.MN.S.files[FILES.big.h] == nil)
ownerPlays(A, "fake.mp3", 0)
run(2000)
check("not what it says: the server drops it", SERVER.MN.S.files[FILES.fake.h] == nil and not B.cache[FILES.fake.h])
check("not what it says: B plays nothing", slotCount(B) == 0)
-- a part nobody asked for, from someone else: not taken
as(SERVER, function() SERVER.MN.onClientCommand("KnoxMusic", "up", PB, {h = FILES.b.h, i = 0, d = "SUQz"}) end)
check("an up from a non-owner: nothing", SERVER.MN.S.files[FILES.b.h] and SERVER.MN.S.files[FILES.b.h].parts[0] == encode(FILES.b, 0))
-- a get for a file not played near the player: not served
as(SERVER, function() SERVER.MN.onClientCommand("KnoxMusic", "get", PB, {h = FILES.big.h, from = 0}) end)
check("a get for a file not near: nothing", SERVER.MN.S.wants[2] == nil or SERVER.MN.S.wants[2][FILES.big.h] == nil)
-- junk states from a client: nothing
as(SERVER, function()
    SERVER.MN.onClientCommand("KnoxMusic", "st", PA, {slot = 5, veh = "x", h = "../../etc"})
    SERVER.MN.onClientCommand("KnoxMusic", "st", PA, "junk")
    SERVER.MN.onClientCommand("KnoxMusic", "need", PA, {})
end)
check("junk: no stream", SERVER.MN.S.streams["1|5"] == nil)

-- 10. the owner gone: quiet after a while -----------------------------------------------------------
ownerPlays(A, "a.mp3", 0)
run(1000)
check("before: heard", slotOf(B, FILES.a.h) ~= nil)
PA.gone = true
run(1500)
check("owner gone: the server stops it", not any(SERVER.MN.S.streams) and slotCount(B) == 0)

-- 11. the switches -------------------------------------------------------------------------------------
game()
run(1000)
PA.veh = CAR1
ownerPlays(A, "a.mp3", 0)
run(1000)
check("new game: heard", slotOf(B, FILES.a.h) ~= nil)
B.switches.musicHear = false
run(400)
check("hear off: B quiet at once", slotCount(B) == 0)
run(1500)
check("hear off: the server sends B nothing", not SERVER.MN.S.streams["1|1"].heard[2])
B.switches.musicHear = true
run(1500)
check("hear on again: heard", slotOf(B, FILES.a.h) ~= nil)
A.switches.musicShare = false
run(700)
check("share off: off for all", not any(SERVER.MN.S.streams) and slotCount(B) == 0)
A.switches.musicShare = true
run(700)
check("share on again: heard", slotOf(B, FILES.a.h) ~= nil)

-- 12. the server's music.share = 0: everyone alone, as before -------------------------------------
game({share = 0})
run(1000)
PA.veh = CAR1
ownerPlays(A, "a.mp3", 0)
run(1500)
check("share=0: nothing sent, nothing heard", not any(SERVER.MN.S.streams) and slotCount(B) == 0 and A.MN.C.own[1] == nil)

-- 13. music.files = 0: only those who have it -------------------------------------------------------
game({files = 0})
run(1000)
PA.veh = CAR1
ownerPlays(A, "b.mp3", 0)
run(2000)
check("files=0: B lacks b, nothing fetched", B.begins == nil and slotCount(B) == 0)
ownerPlays(A, "a.mp3", 0)
run(1000)
check("files=0: B has a, heard", slotOf(B, FILES.a.h) ~= nil)

-- 14. the hash takes a moment: the state waits for it ------------------------------------------------
game()
run(1000)
PA.veh = CAR1
A.pending["a.mp3"] = 5
ownerPlays(A, "a.mp3", 0)
run(150)
check("hash not ready: nothing sent yet", A.MN.C.own[1] ~= nil and not A.MN.C.own[1].sent)
run(1500)
check("hash ready: heard", slotOf(B, FILES.a.h) ~= nil)

-- 15. a client without the Java part: no errors, it asks for nothing ------------------------------
game()
for _, k in ipairs(NAMES) do
    if string.sub(k, 1, 7) == "knoxNet" then B.G[k] = nil end
end
B.G.Events = events(B)   -- (B's Lua loaded anew: the first copy's handlers gone)
load(B)
run(1000)
PA.veh = CAR1
ownerPlays(A, "a.mp3", 0)
run(1500)
check("no Java: B told nothing (it said so)", SERVER.MN.S.streams["1|1"] and not SERVER.MN.S.streams["1|1"].heard[2])

-- 16. a slow link: parts asked again ---------------------------------------------------------------------
game(nil, nil, {})
run(1000)
PA.veh = CAR1
local dropped = 0
local realSend = A.G.sendClientCommand
A.G.sendClientCommand = function(pl, module, cmd, args)
    -- (the first two parts lost on the way)
    if cmd == "up" and dropped < 2 then dropped = dropped + 1 return end
    realSend(pl, module, cmd, args)
end
ownerPlays(A, "a.mp3", 0)
run(15000)
check("parts lost: asked again, B has the file", B.cache[FILES.a.h] == true and slotOf(B, FILES.a.h) ~= nil)

print("DONE pass=" .. pass .. " fail=" .. fail)
