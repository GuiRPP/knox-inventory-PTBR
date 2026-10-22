-- Own music of the car radio heard by the other players (the author, 2026-10-21:
-- "the others near the car hear it as the owner does from outside - by the
-- distance, through the body, the doors open or shut, in time with the track";
-- the passengers as from inside). Research and the decisions: MUSIC_NET_RESEARCH.md.
--
-- The server has no Java of Knox (ZombieBuddy skips media/java/client on a
-- server, the host's server is started without it): it is this file's server
-- part, in Lua - it passes the state on to the players near the car, and the
-- files they lack, in parts, from the owner, keeping them in memory a while.
-- The clients' Java (KnoxMusicNet.java) hashes the files, reads and writes the
-- parts, keeps the cache and plays the others' tracks (four at most, the nearest).
--
-- Who tells whom what (module "KnoxMusic", sendClientCommand / sendServerCommand):
--   client -> server  hello  {java, hear}            at the start, when a switch changes
--   server -> client  cfg    {share, files, max_mb}   the answer
--   owner  -> server  st     {slot, veh, key, h, sz, ext, pos, len, pl, vol, rng, fx, n}
--                            at once on a change (2 a second at most), a pulse every 5 s
--   owner  -> server  off    {slot}                   the music stopped, the set off, no power
--   server -> near    st/off  the same, with o (the owner's online id): the players by the
--                            car (its range and a margin) and its passengers
--   near   -> server  get    {h, from} / cancel {h}   a file not here
--   server -> owner   need   {h, from, to}            the parts the server lacks (4 at most on the way)
--   owner  -> server  up     {h, i, d}                one part, base64 (16 KB of the file)
--   server -> near    dl     {h, i, d}                the parts, as fast as the server's limits let
-- slot: 1 the owner's car, 2 the one left playing (KnoxCarRadio's parked).
-- The owner's side looks at what plays (KnoxCarRadio, KnoxMenuMusic) a few times a
-- second and says what changed - every way a track stops, pauses or is wound is
-- caught so, with no call in the player's own code.
-- A car by its id and its keyId (an id is given anew once a car is unloaded).
-- Nothing of a file's name goes out: its SHA-256, its size and its kind.
-- Alone (no server) none of this runs.

KnoxMusicNet = KnoxMusicNet or {}
local MN = KnoxMusicNet

MN.MODULE = "KnoxMusic"
MN.CHUNK = 16384          -- bytes of a file in one part (KnoxMusicNet.java's CHUNK)
MN.PULSE_MS = 5000        -- the owner's state again, unchanged
MN.EVENT_MS = 500         -- two states of one track no closer (a change waits for it)
MN.LOST_MS = 12000        -- no word of a track this long: it has stopped
MN.MARGIN = 15            -- squares past the music's range a player still gets its state
MN.HEARD = 4              -- the others' tracks heard at once (the nearest)
MN.WINDOW = 4             -- parts asked of the owner and not come yet
MN.ASK_AGAIN_MS = 10000   -- a part asked for and not come: asked again
MN.STALL_MS = 20000       -- no part came this long: the listener asks again
MN.DRIFT_MS = 800         -- the track this far from the owner's: wound to it
MN.CAR_GAIN = 1.8         -- KnoxMenuMusic's CAR_GAIN (the car's music over the engine and the road)
MN.FX_VOLUME = 0.85       -- KnoxMenuMusic's RADIO_VOLUME
MN.FX_LOWPASS = 0.5       -- KnoxMenuMusic's RADIO_LOWPASS
MN.OUTSIDE_VOL = 0.85     -- KnoxCarRadio's OUTSIDE_VOL
MN.DAY_MS = 86400000

local KINDS = {ogg = "T2dnUw", flac = "ZkxhQw", wav = "UklGR", mp3 = true}   -- (base64 of their heads)

function MN.client() return isClient ~= nil and isClient() == true end
function MN.server() return isServer ~= nil and isServer() == true end

local function now() return getTimestampMs() end

-- Values ------------------------------------------------------------------------

local function int(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    v = math.floor(v)
    if v < lo or v > hi then return nil end
    return v
end

local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return math.max(lo, math.min(hi, v))
end

local function hex(v)
    if type(v) ~= "string" or #v ~= 64 or string.find(v, "[^0-9a-f]") then return nil end
    return v
end

local function kind(v)
    if type(v) ~= "string" or not KINDS[v] then return nil end
    return v
end

MN.int, MN.hex, MN.kind = int, hex, kind

--- Has a table anything in it? (The game's Lua has no `next`.)
function MN.any(t)
    for _ in pairs(t) do return true end
    return false
end

--- How many parts a file of `sz` bytes is, and how long part i is as base64.
function MN.parts(sz) return math.ceil(sz / MN.CHUNK) end
function MN.b64len(sz, i)
    local raw = math.min(MN.CHUNK, sz - i * MN.CHUNK)
    return 4 * math.ceil(raw / 3)
end

--- Does the first part (base64) start as a file of this kind does?
function MN.headOk(ext, d)
    if type(d) ~= "string" then return false end
    if ext == "mp3" then
        return string.sub(d, 1, 4) == "SUQz" or string.sub(d, 1, 2) == "//" or string.sub(d, 1, 2) == "/+"
    end
    if ext == "flac" and string.sub(d, 1, 4) == "SUQz" then return true end
    local head = KINDS[ext]
    return type(head) == "string" and string.sub(d, 1, #head) == head
end

--- An owner's state as it comes, checked; nil for a broken one.
function MN.readState(a, maxBytes)
    if type(a) ~= "table" then return nil end
    local s = {
        slot = int(a.slot, 1, 2), veh = int(a.veh, 0, 32767), key = int(a.key, -2147483648, 2147483647),
        h = hex(a.h), sz = int(a.sz, 1, maxBytes or 67108864), ext = kind(a.ext),
        pos = int(a.pos, 0, MN.DAY_MS), len = int(a.len, 0, MN.DAY_MS) or 0,
        pl = a.pl == true, vol = num(a.vol, 0, 1), rng = num(a.rng, 1, 200), fx = a.fx == true,
        n = tonumber(a.n) or 0,
    }
    if not (s.slot and s.veh and s.key and s.h and s.sz and s.ext and s.pos and s.vol and s.rng) then return nil end
    return s
end

local function copyState(s, o, pos)
    return {slot = s.slot, veh = s.veh, key = s.key, h = s.h, sz = s.sz, ext = s.ext, pos = pos or s.pos,
        len = s.len, pl = s.pl, vol = s.vol, rng = s.rng, fx = s.fx, n = s.n, o = o}
end

-- Server ----------------------------------------------------------------------------

MN.S = {streams = {}, files = {}, bytes = 0, prefs = {}, wants = {}, credit = {}, tickAt = nil, lookAt = 0, cfg = nil}

local function cfg()
    local S = MN.S
    if not S.cfg then
        S.cfg = (KnoxNet and KnoxNet.serverMusic) and KnoxNet.serverMusic() or
            {share = 1, files = 1, max_mb = 15, rate_kb = 128, total_kb = 512, cache_mb = 64}
    end
    return S.cfg
end
MN.serverCfg = cfg

local function oidOf(p)
    local ok, id = pcall(function() return p:getOnlineID() end)
    return ok and id or nil
end

local function sendTo(p, cmd, args)
    if p and sendServerCommand then sendServerCommand(p, MN.MODULE, cmd, args) end
end

--- The players online by their online id (asked once a second).
local function online()
    local S = MN.S
    local t = now()
    if S.online and t - (S.onlineAt or 0) < 1000 then return S.online end
    local m = {}
    local list = getOnlinePlayers and getOnlinePlayers()
    for i = 0, (list and list:size() or 0) - 1 do
        local p = list:get(i)
        local id = p and oidOf(p)
        if id then m[id] = p end
    end
    S.online, S.onlineAt = m, t
    return m
end

--- The car of a stream, if it is the same car (its key) and the server has it.
local function carOf(s)
    local v = getVehicleById and getVehicleById(s.veh)
    if not v then return nil end
    local ok, key = pcall(function() return v:getKeyId() end)
    if ok and key ~= s.key then return nil end
    return v
end

--- Is a player to hear this stream (or rather, to be told of it)?
local function near(p, v, s)
    if p:getVehicle() == v then return true end
    local dx, dy = p:getX() - v:getX(), p:getY() - v:getY()
    local r = s.rng + MN.MARGIN
    return dx * dx + dy * dy <= r * r and math.abs(p:getZ() - v:getZ()) <= 3
end

--- The stream's state to the players near (all of them, or only the newly near);
--- "off" to those no longer near.
local function spread(key, s, all)
    local S = MN.S
    local players = online()
    local v = carOf(s)
    local t = now()
    local pos = s.pl and math.min(s.pos + (t - s.at), MN.DAY_MS) or s.pos
    local msg
    for id, p in pairs(players) do
        if id ~= s.owner then
            local pf = S.prefs[id]
            local want = v ~= nil and pf ~= nil and pf.java and pf.hear and near(p, v, s)
            if want and (all or not s.heard[id]) then
                msg = msg or copyState(s, s.owner, math.floor(pos))
                sendTo(p, "st", msg)
                s.heard[id] = true
            elseif not want and s.heard[id] then
                sendTo(p, "off", {o = s.owner, slot = s.slot})
                s.heard[id] = nil
            end
        end
    end
    -- (gone players: forgotten)
    for id in pairs(s.heard) do
        if not players[id] then s.heard[id] = nil end
    end
end

local function stop(key)
    local S = MN.S
    local s = S.streams[key]
    if not s then return end
    S.streams[key] = nil
    local players = online()
    for id in pairs(s.heard) do sendTo(players[id], "off", {o = s.owner, slot = s.slot}) end
end
MN.serverStop = stop

function MN.serverHello(player, args)
    local id = oidOf(player)
    if not id or type(args) ~= "table" then return end
    local S = MN.S
    -- (knox_server.txt read again, as KnoxNet does when a player comes in - but not
    -- more often than every 10 s, whoever says hello how often)
    local t = now()
    if t - (S.cfgAt or 0) > 10000 then S.cfg, S.cfgAt = nil, t end
    local c = cfg()
    S.prefs[id] = {java = args.java == true, hear = args.hear == true}
    if not S.prefs[id].hear then S.wants[id] = nil end
    sendTo(player, "cfg", {share = c.share == 1, files = c.files == 1, max_mb = c.max_mb})
end

function MN.serverState(player, args)
    local c = cfg()
    local id = oidOf(player)
    if not id or c.share ~= 1 then return end
    local s = MN.readState(args)
    if not s then return end
    local key = id .. "|" .. s.slot
    local S = MN.S
    local was = S.streams[key]
    local t = now()
    -- (a flood: four states a second of a track at most)
    if was and t - (was.at or 0) < 250 and was.h == s.h then return end
    -- (a car the server does not have, or another car than its id says: no music)
    if not carOf(s) then
        stop(key)
        return
    end
    s.owner, s.at, s.player = id, t, player
    s.heard = was and was.heard or {}
    S.streams[key] = s
    spread(key, s, true)
end

function MN.serverOff(player, args)
    local id = oidOf(player)
    local slot = type(args) == "table" and int(args.slot, 1, 2)
    if id and slot then stop(id .. "|" .. slot) end
end

--- The file of a hash as the server keeps it (made when a player first asks for it).
local function fileEntry(h, sz, ext)
    local S = MN.S
    local f = S.files[h]
    if not f then
        f = {h = h, sz = sz, ext = ext, n = MN.parts(sz), parts = {}, got = 0, asked = {}, bytes = 0, usedAt = now(), credit = 0}
        S.files[h] = f
    end
    return f
end

--- A stream of this hash the player is told of (only such files may be asked for).
local function streamOf(id, h)
    for _, s in pairs(MN.S.streams) do
        if s.h == h and s.heard[id] then return s end
    end
    return nil
end

--- Is a stream of this owner playing this hash?
local function ownerPlays(owner, h)
    for _, s in pairs(MN.S.streams) do
        if s.owner == owner and s.h == h then return true end
    end
    return false
end

local function wanted(h)
    for _, w in pairs(MN.S.wants) do
        if w[h] then return true end
    end
    return false
end

function MN.serverGet(player, args)
    local c = cfg()
    local id = oidOf(player)
    if not id or c.files ~= 1 or type(args) ~= "table" then return end
    local h = hex(args.h)
    local s = h and streamOf(id, h)
    if not s or s.sz > c.max_mb * 1048576 then return end
    local f = fileEntry(h, s.sz, s.ext)
    local S = MN.S
    S.wants[id] = S.wants[id] or {}
    -- (two files coming to one player at most)
    local n = 0
    for k in pairs(S.wants[id]) do if k ~= h then n = n + 1 end end
    if n >= 2 then return end
    S.wants[id][h] = int(args.from, 0, f.n - 1) or 0
    f.usedAt = now()
end

function MN.serverCancel(player, args)
    local id = oidOf(player)
    local h = type(args) == "table" and hex(args.h)
    local w = id and MN.S.wants[id]
    if w and h then w[h] = nil end
end

--- Files no one is getting, the oldest first, out of memory past the server's limit.
local function evict(keep)
    local S = MN.S
    local cap = cfg().cache_mb * 1048576
    while S.bytes > cap do
        local oldest
        for h, f in pairs(S.files) do
            if h ~= keep and not wanted(h) and (not oldest or f.usedAt < oldest.usedAt) then oldest = f end
        end
        if not oldest then return end
        S.bytes = S.bytes - oldest.bytes
        S.files[oldest.h] = nil
    end
end

function MN.serverUp(player, args)
    local id = oidOf(player)
    if not id or type(args) ~= "table" then return end
    local h = hex(args.h)
    local f = h and MN.S.files[h]
    if not f or f.from ~= id then return end
    local i = int(args.i, 0, f.n - 1)
    local d = args.d
    -- (only a part asked for, of the length it must be; the first one a head of its kind)
    if not i or not f.asked[i] or f.parts[i] or type(d) ~= "string" or #d ~= MN.b64len(f.sz, i) then return end
    if i == 0 and not MN.headOk(f.ext, d) then
        -- (not what it says it is: given up, and the file no one's)
        MN.S.files[h] = nil
        MN.S.bytes = MN.S.bytes - f.bytes
        for _, w in pairs(MN.S.wants) do w[h] = nil end
        return
    end
    f.asked[i] = nil
    f.parts[i] = d
    f.got = f.got + 1
    f.bytes = f.bytes + #d
    MN.S.bytes = MN.S.bytes + #d
    f.usedAt = now()
    evict(h)
end

--- Each tick of the server: the streams looked at, the parts asked for and sent on.
function MN.serverTick()
    local S = MN.S
    local t = now()
    local dt = S.tickAt and math.min(1000, t - S.tickAt) or 0
    if S.tickAt and dt < 100 then return end
    S.tickAt = t
    local c = cfg()
    local players = online()
    -- once a second: streams gone quiet, their cars gone, the players near
    if t >= S.lookAt then
        S.lookAt = t + 1000
        for key, s in pairs(S.streams) do
            if not players[s.owner] or t - s.at > MN.LOST_MS or not carOf(s) then
                stop(key)
            else
                spread(key, s, false)
            end
        end
        for id in pairs(S.wants) do
            if not players[id] then S.wants[id] = nil end
        end
        for id in pairs(S.prefs) do
            if not players[id] then S.prefs[id] = nil end
        end
        -- (a file asked for and given up before a part of it came: forgotten)
        for h, f in pairs(S.files) do
            if f.got == 0 and not wanted(h) and t - f.usedAt > 60000 then S.files[h] = nil end
        end
    end
    if c.files ~= 1 then return end
    local rate, total = c.rate_kb * 1024, c.total_kb * 1024
    -- the parts the server lacks, asked of the file's owner at the owner's pace
    for h, f in pairs(S.files) do
        if f.got < f.n and wanted(h) then
            local from = f.from and players[f.from]
            if not from or not ownerPlays(f.from, h) then
                -- (its owner gone: another player playing it)
                f.from, from = nil, nil
                for _, s in pairs(S.streams) do
                    if s.h == h and players[s.owner] then f.from, from = s.owner, players[s.owner] end
                end
            end
            if from then
                f.credit = math.min(f.credit + rate * dt / 1000, MN.CHUNK * MN.WINDOW)
                local out = 0
                for i, at in pairs(f.asked) do
                    if t - at > MN.ASK_AGAIN_MS then f.asked[i] = nil else out = out + 1 end
                end
                -- (from the first part still missing)
                while f.parts[f.low or 0] do f.low = (f.low or 0) + 1 end
                local lo, hi
                local i = f.low or 0
                while i < f.n and out < MN.WINDOW and f.credit >= MN.CHUNK do
                    if not f.parts[i] and not f.asked[i] then
                        if lo and i ~= hi + 1 then break end
                        lo = lo or i
                        hi = i
                        f.asked[i] = t
                        out = out + 1
                        f.credit = f.credit - MN.CHUNK
                    end
                    i = i + 1
                end
                if lo then sendTo(from, "need", {h = h, from = lo, to = hi}) end
            end
        end
    end
    -- the parts on to the players waiting, in order, within each one's and the server's limits
    S.credit.all = math.min((S.credit.all or 0) + total * dt / 1000, MN.CHUNK * 4)
    for id, w in pairs(S.wants) do
        local p = players[id]
        S.credit[id] = math.min((S.credit[id] or 0) + rate * dt / 1000, MN.CHUNK * 2)
        for h, i in pairs(w) do
            local f = S.files[h]
            if not f then
                w[h] = nil
            else
                while p and f.parts[i] and S.credit[id] >= MN.CHUNK and S.credit.all >= MN.CHUNK do
                    sendTo(p, "dl", {h = h, i = i, d = f.parts[i]})
                    S.credit[id] = S.credit[id] - MN.CHUNK
                    S.credit.all = S.credit.all - MN.CHUNK
                    i = i + 1
                end
                f.usedAt = t
                if i >= f.n then w[h] = nil else w[h] = i end
            end
        end
    end
end

function MN.onClientCommand(module, command, player, args)
    if module ~= MN.MODULE or not player or not MN.server() then return end
    if command == "st" then MN.serverState(player, args)
    elseif command == "off" then MN.serverOff(player, args)
    elseif command == "get" then MN.serverGet(player, args)
    elseif command == "cancel" then MN.serverCancel(player, args)
    elseif command == "up" then MN.serverUp(player, args)
    elseif command == "hello" then MN.serverHello(player, args) end
end

-- Client --------------------------------------------------------------------------

MN.C = {cfg = nil, helloAt = nil, helloTries = 0, said = nil, own = {}, heard = {}, dls = {}, bad = {}, slots = {}, lookAt = 0}

local function java() return knoxNetHash ~= nil and knoxNetPlay ~= nil end

local function theme() return KnoxTheme end

function MN.shareOn()
    local T = theme()
    return T ~= nil and T.switch("musicShare")
end

function MN.hearOn()
    local T = theme()
    return T ~= nil and T.switch("musicHear")
end

--- The others' music's own volume, 0..2 (the settings' slider, 70 % by default).
function MN.othersVolume()
    local T = theme()
    return T and T.look("music.others") / 100 or 0.7
end

local function me() return getSpecificPlayer and getSpecificPlayer(0) or nil end

local function tell(cmd, args)
    local p = me()
    if p and sendClientCommand then sendClientCommand(p, MN.MODULE, cmd, args) end
end

--- Hello to the server: what this client can and wants (again when a switch changes,
--- and until the server answers).
local function hello()
    local C = MN.C
    local said = (java() and "j" or "-") .. (MN.hearOn() and "h" or "-")
    local t = now()
    if said ~= C.said then C.said, C.answered, C.helloTries, C.helloAt = said, false, 0, nil end
    if C.answered or C.helloTries >= 6 then return end
    if C.helloAt and t - C.helloAt < 10000 then return end
    if not me() then return end
    C.helloTries, C.helloAt = C.helloTries + 1, t
    tell("hello", {java = java(), hear = MN.hearOn()})
end

-- The owner's side ---------------------------------------------------------------

--- What the owner's slot plays now (a reused table), or nil: the car, the file, where it is.
local function ownWant(slot, w)
    local R, MM = KnoxCarRadio, KnoxMenuMusic
    if not R or not MM then return nil end
    if slot == 1 then
        local v = R.vehicle
        if not v or MM.ctx ~= "car" or not MM.active or not MM.playing or MM.playing.kind ~= "file"
            or MM.theme() ~= "mine" or not (MM.carAllowed and MM.carAllowed()) then return nil end
        local d = R.data and R.data()
        w.v, w.name = v, MM.playing.name
        w.pos = knoxMusicPosition and knoxMusicPosition() or 0
        w.len = knoxMusicLength and knoxMusicLength() or 0
        w.pl = not MM.paused and not MM.hold
        w.rng = 5 + (d and d:getBaseVolumeRange() or 0) * MM.vol()
    else
        local P = R.parked
        local tr = P and P.playing and P.list[P.at]
        if not tr or tr.kind ~= "file" then return nil end
        w.v, w.name = P.vehicle, tr.name
        w.pos = knoxMusicParkedPosition and knoxMusicParkedPosition() or 0
        w.len = knoxMusicParkedLength and knoxMusicParkedLength() or 0
        w.pl = not P.hold
        w.rng = P.range or 5
    end
    w.vol = MM.vol()
    w.fx = MM.radioOn and MM.radioOn() or false
    return w
end

local function ownOff(slot)
    local o = MN.C.own[slot]
    if o and o.sent then tell("off", {slot = slot}) end
    MN.C.own[slot] = nil
end

--- The owner's two slots, looked at a few times a second: a change told at once
--- (no closer than EVENT_MS), the state again every PULSE_MS.
local function ownTick(t)
    local C = MN.C
    local can = C.cfg and C.cfg.share and MN.shareOn() and java()
    C.wbuf = C.wbuf or {{}, {}}
    for slot = 1, 2 do
        local w = can and ownWant(slot, C.wbuf[slot]) or nil
        local o = C.own[slot]
        if not w then
            if o then ownOff(slot) end
        else
            if not o or o.name ~= w.name or o.v ~= w.v then
                if o then ownOff(slot) end
                o = {name = w.name, v = w.v}
                C.own[slot] = o
            end
            -- the file's hash (worked out by the Java part off the game's thread)
            if not o.h and not o.never then
                local r = knoxNetHash(w.name)
                if r == nil or r == "-" then
                    o.never = true
                elseif r ~= "" then
                    local h, sz, ext = string.match(r, "^(%x+)|(%d+)|(%w+)$")
                    o.h, o.sz, o.ext = hex(h), tonumber(sz), kind(ext)
                    if not (o.h and o.sz and o.ext) then o.never = true end
                end
            end
            if o.h then
                local pos = math.floor(w.pos)
                -- a change: playing / paused, wound (the track's place not where it would be), the volume, the sound
                local expect = o.pos and (o.pl and o.pos + (t - o.at) or o.pos)
                local changed = not o.sent or o.pl ~= w.pl or math.abs((o.vol or 0) - w.vol) > 0.02 or o.fx ~= w.fx
                    or (expect and math.abs(pos - expect) > 1500)
                local due = not o.sentAt or t - o.sentAt >= MN.PULSE_MS
                if (changed and (not o.sentAt or t - o.sentAt >= MN.EVENT_MS)) or due then
                    local key = 0
                    pcall(function() key = w.v:getKeyId() end)
                    tell("st", {slot = slot, veh = w.v:getId(), key = key, h = o.h, sz = o.sz, ext = o.ext,
                        pos = pos, len = math.floor(w.len), pl = w.pl, vol = w.vol, rng = w.rng, fx = w.fx, n = t})
                    o.sent, o.sentAt = true, t
                    o.vol, o.fx = w.vol, w.fx
                end
                o.pos, o.pl, o.at = pos, w.pl, t
            end
        end
    end
end

--- The server asks for parts of one's own file (only one announced: the Java part checks).
function MN.onNeed(args)
    local h = hex(args.h)
    local lo, hi = int(args.from, 0, 4095), int(args.to, 0, 4095)
    if not h or not lo or not hi or hi < lo or hi - lo >= MN.WINDOW or not knoxNetChunk then return end
    for i = lo, hi do
        local d = knoxNetChunk(h, i)
        if d then tell("up", {h = h, i = i, d = d}) end
    end
end

-- The listener's side ------------------------------------------------------------

--- How open a car is (KnoxCarRadio's openness: doors and windows), 0..1.
local function openness(v)
    local R = KnoxCarRadio
    return R and R.openness and R.openness(v) or 0
end

--- Is the car's set on, with power (the game sends its state to all: a set switched
--- off or out of power is quiet here at once, before the owner's word comes)?
local function setOn(v)
    local ok, on = pcall(function()
        local p = v:getPartById("Radio")
        local d = p and p:getInventoryItem() and p:getDeviceData()
        return d ~= nil and d:getIsTurnedOn() and d:canBePoweredHere()
    end)
    return ok and on == true
end

local function freeSlot(rec)
    local C = MN.C
    if rec.slot0 ~= nil then
        knoxNetStop(rec.slot0)
        C.slots[rec.slot0] = nil
        rec.slot0 = nil
    end
end

local function forget(key)
    local C = MN.C
    local rec = C.heard[key]
    if not rec then return end
    freeSlot(rec)
    C.heard[key] = nil
end

function MN.onState(args)
    local C = MN.C
    local s = MN.readState(args)
    local o = type(args) == "table" and int(args.o, 0, 65535)
    local p = me()
    if not s or not o or not MN.hearOn() or (p and o == p:getOnlineID()) then return end
    local key = o .. "|" .. s.slot
    local rec = C.heard[key]
    -- (the network keeps no order: an older state after a newer one is dropped)
    if rec and s.n < rec.n then return end
    if rec and (rec.h ~= s.h or rec.veh ~= s.veh) then
        forget(key)
        rec = nil
    end
    if not rec then
        rec = {o = o, have = nil}
        C.heard[key] = rec
    end
    -- (a track ended here, the owner's wound back or playing it again: from the start)
    if rec.ended and s.pos + 1000 < (rec.pos or 0) + (now() - (rec.at or 0)) then rec.ended = false end
    for k, v in pairs(s) do rec[k] = v end
    rec.at, rec.synced = now(), false
end

function MN.onOff(args)
    local o = type(args) == "table" and int(args.o, 0, 65535)
    local slot = type(args) == "table" and int(args.slot, 1, 2)
    if o and slot then forget(o .. "|" .. slot) end
end

--- Parts of a file coming (the listener's download).
function MN.onPart(args)
    local C = MN.C
    local h = hex(args.h)
    local i = int(args.i, 0, 4095)
    local dl = h and C.dls[h]
    -- (a part sent twice may come while the whole is checked: nothing to do)
    if not dl or dl.checking or not i or type(args.d) ~= "string" then return end
    dl.at = now()
    local r = knoxNetRecv(h, i, args.d)
    if r < 0 then
        C.bad[h] = true
        C.dls[h] = nil
        tell("cancel", {h = h})
    elseif r == 2 then
        dl.checking = true
    end
end

--- Ask for a file not here (two at once at most).
local function fetch(rec, t)
    local C = MN.C
    local n = 0
    for _ in pairs(C.dls) do n = n + 1 end
    if n >= 2 or not C.cfg or not C.cfg.files or rec.sz > (C.cfg.max_mb or 15) * 1048576 then return end
    if not knoxNetRecvBegin(rec.h, rec.sz, rec.ext) then
        C.bad[rec.h] = true
        return
    end
    C.dls[rec.h] = {at = t}
    tell("get", {h = rec.h, from = math.max(0, knoxNetRecvNext(rec.h))})
end

local function dlTick(t)
    local C = MN.C
    for h, dl in pairs(C.dls) do
        local st = knoxNetRecvState(h)
        if st == 3 then
            C.dls[h] = nil
            for _, rec in pairs(C.heard) do if rec.h == h then rec.have = 1 end end
        elseif st == -1 or st == 0 then
            C.dls[h] = nil
            if st == -1 then C.bad[h] = true end
        elseif not dl.checking and t - dl.at > MN.STALL_MS then
            -- (nothing for a while: asked again from the first part missing)
            dl.at = t
            local from = knoxNetRecvNext(h)
            if from >= 0 then tell("get", {h = h, from = from}) end
        end
        -- (no one near plays it any more: given up)
        local used = false
        for _, rec in pairs(C.heard) do if rec.h == h then used = true end end
        if not used and C.dls[h] then
            knoxNetRecvCancel(h)
            tell("cancel", {h = h})
            C.dls[h] = nil
        end
    end
end

--- Where the owner's track is now, by the last word of it.
local function expected(rec, t)
    if not rec.pl then return rec.pos end
    return rec.pos + (t - rec.at)
end

--- The others' tracks: the nearest that can play get the four slots, each by its
--- distance and its car (from inside for its passengers), in time with its owner.
local function hearTick(t)
    local C = MN.C
    local p = me()
    if not p then return end
    local soundOpt = math.max(0, math.min(1, ((getCore and getCore():getOptionSoundVolume()) or 8) / 10))
    local others = MN.othersVolume()
    local list = C.list or {}
    C.list = list
    for i = #list, 1, -1 do list[i] = nil end
    for key, rec in pairs(C.heard) do
        local v
        if t - rec.at > MN.LOST_MS then
            forget(key)
        else
            v = getVehicleById and getVehicleById(rec.veh)
            if v then
                local ok, k = pcall(function() return v:getKeyId() end)
                if ok and k ~= rec.key then v = nil end
            end
        end
        rec.car = v
        if v and not C.bad[rec.h] then
            -- here, or to be fetched
            -- (looked at again each second; the Java part hashes one's own files of that size meanwhile)
            if rec.have ~= 1 and t >= (rec.haveAt or 0) then
                rec.haveAt = t + 1000
                local have = knoxNetHave(rec.h, rec.sz, rec.ext)
                if have == 1 then rec.have = 1
                elseif have == -2 then C.bad[rec.h] = true
                elseif have == 0 and not C.dls[rec.h] then fetch(rec, t) end
            end
            local inside = p:getVehicle() == v
            local dx, dy = p:getX() - v:getX(), p:getY() - v:getY()
            local dist = math.sqrt(dx * dx + dy * dy) + math.abs(p:getZ() - v:getZ()) * 3
            local gain = inside and 1 or math.max(0, 1 - dist / math.max(1, rec.rng))
            rec.inside, rec.gain, rec.dist = inside, gain, inside and -1 or dist
            if rec.have == 1 and not rec.ended and setOn(v) and gain > 0 and expected(rec, t) < (rec.len > 0 and rec.len or MN.DAY_MS) then
                table.insert(list, rec)
            end
        end
    end
    -- the nearest four
    table.sort(list, function(a, b) return a.dist < b.dist end)
    for _, rec in pairs(C.heard) do rec.keep = false end
    for i = 1, math.min(#list, MN.HEARD) do list[i].keep = true end
    for _, rec in pairs(C.heard) do
        if not rec.keep and rec.slot0 ~= nil then freeSlot(rec) end
    end
    for i = 1, math.min(#list, MN.HEARD) do
        local rec = list[i]
        local base = soundOpt * rec.vol * MN.CAR_GAIN * (rec.fx and MN.FX_VOLUME or 1) * others
        local vol, dark, open = base, -1, 0
        if not rec.inside then
            open = openness(rec.car)
            vol = base * rec.gain * (0.55 + 0.45 * open) * MN.OUTSIDE_VOL
            dark = 1 - rec.gain
        end
        if rec.slot0 == nil then
            for s = 0, MN.HEARD - 1 do
                if not C.slots[s] then
                    if knoxNetPlay(s, rec.h, expected(rec, t), vol, not rec.pl) then
                        C.slots[s], rec.slot0, rec.syncAt, rec.paused = rec, s, t + 1000, not rec.pl
                    else
                        -- (FMOD can't play it: not played again)
                        C.bad[rec.h] = true
                        knoxNetForget(rec.h)
                    end
                    break
                end
            end
        end
        local s = rec.slot0
        if s ~= nil then
            if rec.paused ~= not rec.pl then
                rec.paused = not rec.pl
                knoxNetPause(s, rec.paused)
                rec.synced = false
            end
            knoxNetVolume(s, vol)
            knoxNetMuffle(s, dark, open)
            knoxNetLowPass(s, (rec.inside and rec.fx) and MN.FX_LOWPASS or 1)
            if not knoxNetPlaying(s) then
                -- (ended here: quiet until the owner's next track or a wind back)
                rec.ended = true
                freeSlot(rec)
            elseif not rec.synced or t >= (rec.syncAt or 0) then
                -- in time with the owner: wound when it is more than DRIFT_MS off
                rec.synced, rec.syncAt = true, t + 1000
                local want = expected(rec, t)
                if math.abs(knoxNetPosition(s) - want) > MN.DRIFT_MS then knoxNetSeek(s, want) end
            end
        end
    end
end

--- All the others' music off (the switch off, the game left).
function MN.silence()
    local C = MN.C
    for key in pairs(C.heard) do forget(key) end
    for h in pairs(C.dls) do
        if knoxNetRecvCancel then knoxNetRecvCancel(h) end
        tell("cancel", {h = h})
    end
    C.dls = {}
end

function MN.clientTick()
    if not MN.client() then return end
    local C = MN.C
    local t = now()
    hello()
    if t < C.lookAt then return end
    C.lookAt = t + 200
    if not java() then return end
    ownTick(t)
    if MN.hearOn() and C.cfg and C.cfg.share then
        dlTick(t)
        hearTick(t)
    elseif MN.any(C.heard) or MN.any(C.dls) then
        MN.silence()
    end
end

function MN.onServerCommand(module, command, args)
    if module ~= MN.MODULE or type(args) ~= "table" or not MN.client() then return end
    if command == "st" then MN.onState(args)
    elseif command == "off" then MN.onOff(args)
    elseif command == "dl" then MN.onPart(args)
    elseif command == "need" then MN.onNeed(args)
    elseif command == "cfg" then
        MN.C.cfg = {share = args.share == true, files = args.files == true, max_mb = int(args.max_mb, 1, 50) or 15}
        MN.C.answered = true
    end
end

--- What is going on, for the test bench: a line.
function MN.status()
    local C = MN.C
    local heard, playing, dls = 0, 0, 0
    for _, rec in pairs(C.heard) do
        heard = heard + 1
        if rec.slot0 ~= nil then playing = playing + 1 end
    end
    for _ in pairs(C.dls) do dls = dls + 1 end
    local own = (C.own[1] and C.own[1].sent and 1 or 0) + (C.own[2] and C.own[2].sent and 1 or 0)
    return C.cfg ~= nil, C.cfg and C.cfg.share, own, heard, playing, dls
end

-- Events ---------------------------------------------------------------------------

local function startOver()
    if knoxNetStopAll then knoxNetStopAll() end
    MN.C = {cfg = nil, helloAt = nil, helloTries = 0, said = nil, own = {}, heard = {}, dls = {}, bad = {}, slots = {}, lookAt = 0}
end

if Events then
    if Events.OnClientCommand then Events.OnClientCommand.Add(MN.onClientCommand) end
    if Events.OnServerCommand then Events.OnServerCommand.Add(MN.onServerCommand) end
    if Events.OnTick then
        Events.OnTick.Add(function()
            if MN.server() then MN.serverTick() else MN.clientTick() end
        end)
    end
    if Events.OnGameStart then Events.OnGameStart.Add(function() if MN.client() then startOver() end end) end
end

-- (Lua loaded anew: the others' tracks the old Lua left in the Java part have no one to step them)
if knoxNetStopAll and not (isServer and isServer()) then knoxNetStopAll() end

return KnoxMusicNet
