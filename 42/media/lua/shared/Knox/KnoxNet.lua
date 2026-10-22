-- Knox in a game with others (B42 multiplayer, a dedicated server or a host).
--
-- What the game does there (its own code, 42.21): things are moved by the server
-- (item transactions); a thing that has moved comes to the client as a new object
-- with the server's modData, wiping the client's (AddInventoryItemToContainer,
-- SyncItemModData). A client can't give the server the modData of a thing in a
-- cupboard, a car or on a body; only the server can send a thing's modData out
-- (syncItemModData). So whatever Knox wrote on a thing on the client - its place,
-- the place it was dropped at, its stack - was this client's alone, gone at the
-- next look, and a thing dropped into another container lay at the first free cell.
--
-- Here (decided by the author, 2026-10-20):
--   * what belongs to the world goes through the server: a thing's place in its
--     grid (knox, knoxP), its stack (knoxS), a bag's layout (knoxT). The client
--     writes at once (the grid answers at once), then tells the server, which
--     finds the thing itself, writes it and sends it to the players near. The
--     grid's room is the client's to check, as alone; the server only keeps.
--     A place the grid found by itself is kept only if the thing had none in that
--     container yet (the first look of anyone lays a cupboard out for all).
--   * what is the player's own is kept by the server per character: the things
--     the character knows, the containers it has searched, its locks, the order
--     of its sections, the layout of its pockets (KnoxNet.me).
--   * the sizes are the server's: its "Size of bags and pockets" and its own
--     knox_overrides.txt (Zomboid/Lua/knox_server.txt, knox_overrides.txt on the
--     server), sent to each player as they come in.
-- Alone (no server) none of this runs: the things' modData as before.

KnoxNet = KnoxNet or {}
local N = KnoxNet

N.MODULE = "Knox"
N.MAX_ITEMS = 400         -- entries in one command (the server takes no more of them)
N.REACH = 8               -- how far from the player a thing may be for the server to take its place
N.KNOWN_MAX = 30000       -- things a character knows, kept by the server (then they are let go of)
N.CHUNK = 2000            -- ids in one message of the character's own data

--- A client of a server (the host's own game is one too)?
function N.mp()
    return isClient ~= nil and isClient() == true
end

--- The server of such a game?
function N.server()
    return isServer ~= nil and isServer() == true
end

-- Values ---------------------------------------------------------------------------
-- Only these fields of a thing go through the server, each checked for what it may
-- hold (a client is not trusted with anything else of a thing's modData).

local function int(v, lo, hi)
    v = tonumber(v)
    if not v then return nil end
    v = math.floor(v)
    if v < lo or v > hi then return nil end
    return v
end

local function str(v, max)
    if type(v) ~= "string" or #v > max then return nil end
    return v
end

local function place(v)
    if type(v) ~= "table" then return nil end
    local k, x, y = str(v.k, 120), int(v.x, 0, 200), int(v.y, 0, 400)
    if not (k and x and y) then return nil end
    return {k = k, x = x, y = y, r = (tonumber(v.r) == 1) and 1 or 0}
end

local function stackId(v)
    return str(v, 40)
end

--- A layout of a bag (KnoxOrder): {sub = {cols, e = {{t, x, y, r, w, h, tex, c}...}}}.
local function layouts(v)
    if type(v) ~= "table" then return nil end
    local out, n = {}, 0
    for sub, tpl in pairs(v) do
        n = n + 1
        if n > 4 then break end
        local s = str(sub, 20)
        if s and type(tpl) == "table" and type(tpl.e) == "table" then
            local t = {cols = int(tpl.cols, 1, 40) or 1, e = {}}
            for _, en in ipairs(tpl.e) do
                if #t.e >= 400 then break end
                if type(en) == "table" then
                    local e = {t = str(en.t, 120), x = int(en.x, 0, 200), y = int(en.y, 0, 400), r = (tonumber(en.r) == 1) and 1 or 0,
                               w = int(en.w, 1, 20), h = int(en.h, 1, 20), tex = str(en.tex, 240), c = str(en.c, 8)}
                    if e.t and e.x and e.y and e.w and e.h then table.insert(t.e, e) end
                end
            end
            out[s] = t
        end
    end
    return out
end

N.FIELDS = {knox = place, knoxP = place, knoxS = stackId, knoxT = layouts}

--- A thing's field as it goes over the network: a copy; "-" for none.
local function wire(key, v)
    if v == nil then return "-" end
    local check = N.FIELDS[key]
    return check and check(v) or "-"
end

--- A thing's field as the server takes it: checked; nil - taken away; false - refused.
function N.accept(key, v)
    local check = N.FIELDS[key]
    if not check then return false end
    if v == "-" or v == nil then return nil end
    local ok = check(v)
    if ok == nil then return false end
    return ok
end

-- Client: a thing's fields to the server --------------------------------------------

N.out, N.outOrder = {}, {}

--- Where a thing lies, for the server to find it: {p = true} - on the player (any
--- depth), or {x, y, z} - the square of the container it is in (or of the bag
--- lying on the ground it is in). nil - nowhere the server could look: lying on
--- the ground itself (the floor is no container on the server - its places stay
--- the client's own).
function N.refOf(item, player)
    local c = item:getContainer()
    if not c or not player then return nil end
    local outer = c:getOutermostContainer() or c
    if outer == player:getInventory() then return {p = true} end
    local sq
    if outer:getType() == "floor" then
        -- in a bag lying on the ground: by that bag
        local bag, cc = nil, c
        for _ = 1, 16 do
            local holder = cc and cc:getContainingItem()
            if not holder then break end
            bag = holder
            cc = holder:getContainer()
            if cc == outer then break end
        end
        if not bag or bag == item then return nil end
        local wi = bag:getWorldItem()
        sq = wi and wi:getSquare()
    else
        sq = outer:getSourceGrid()
        if not sq then
            local parent = outer:getParent()
            sq = parent and parent.getSquare and parent:getSquare()
        end
        if not sq and outer.getVehiclePart then
            local part = outer:getVehiclePart()
            local v = part and part:getVehicle()
            sq = v and v:getSquare()
        end
    end
    if not sq then return nil end
    return {x = sq:getX(), y = sq:getY(), z = sq:getZ()}
end

--- The thing's field `key` has just been written here: tell the server (in a game
--- with others; alone nothing). `auto`: the grid found the place by itself.
function N.itemChanged(item, key, auto)
    if not N.mp() or not N.FIELDS[key] then return end
    local player = getSpecificPlayer(0)
    local ref = player and N.refOf(item, player)
    if not ref then return end
    local id = item:getID()
    local slot = id .. "|" .. key
    local e = N.out[slot]
    if not e then
        e = {}
        N.out[slot] = e
        table.insert(N.outOrder, slot)
    end
    e.id, e.k, e.p, e.x, e.y, e.z = id, key, ref.p, ref.x, ref.y, ref.z
    e.v = wire(key, item:getModData()[key])
    -- (a place the player picked, waiting with one the grid found: the player's goes)
    if not auto then e.manual = true end
    e.a = (auto and not e.manual) and 1 or nil
    -- the place a thing is dropped at must be on the server before the thing is
    -- moved there: at once, not with the next tick
    if key == "knoxP" then N.flush() end
end

--- Send what is waiting (in parts of N.MAX_ITEMS).
function N.flush()
    if #N.outOrder == 0 then return end
    local player = getSpecificPlayer(0)
    if not player or not sendClientCommand then
        N.out, N.outOrder = {}, {}
        return
    end
    local batch = {}
    for _, slot in ipairs(N.outOrder) do
        local e = N.out[slot]
        if e then
            table.insert(batch, {id = e.id, k = e.k, v = e.v, p = e.p and 1 or nil, x = e.x, y = e.y, z = e.z, a = e.a})
            if #batch >= N.MAX_ITEMS then
                sendClientCommand(player, N.MODULE, "items", {list = batch})
                batch = {}
            end
        end
    end
    if #batch > 0 then sendClientCommand(player, N.MODULE, "items", {list = batch}) end
    N.out, N.outOrder = {}, {}
end

-- Client: the character's own data ----------------------------------------------------
-- Kept by the server; here a copy, filled when the game starts (N.ready), and the
-- changes sent with the next tick.

N.me = {known = {}, seen = {}, locks = {}, order = nil, layout = nil}
N.ready = false
N.delta = nil

local function delta()
    N.delta = N.delta or {known = {}, seen = {}, unseen = {}, lock = {}, unlock = {}}
    return N.delta
end

function N.isKnown(item)
    return N.me.known[item:getID()] == true
end

function N.setKnown(item)
    local id = item:getID()
    if N.me.known[id] then return end
    N.me.known[id] = true
    table.insert(delta().known, id)
end

--- Has the character searched the container under this key (KnoxGrid.containerKey)?
function N.isSeen(key)
    return key ~= nil and N.me.seen[key] == true
end

function N.setSeen(key, on)
    -- (before the character's data has come: not marked, not to be lost when it comes)
    if not key or not N.ready then return end
    on = on and true or nil
    if N.me.seen[key] == on then return end
    N.me.seen[key] = on
    table.insert(on and delta().seen or delta().unseen, key)
end

function N.isLocked(item)
    return N.me.locks[item:getID()] == true
end

function N.setLocked(item, on)
    local id = item:getID()
    on = on and true or nil
    if N.me.locks[id] == on then return end
    N.me.locks[id] = on
    table.insert(on and delta().lock or delta().unlock, id)
end

--- The order of the inventory column's sections (a list of container keys).
function N.order()
    N.me.order = N.me.order or {}
    return N.me.order
end

function N.orderChanged()
    delta().order = N.order()
end

--- The layout of the character's pockets (KnoxOrder), or nil.
function N.pocketsLayout()
    return N.me.layout
end

function N.setPocketsLayout(tpl)
    N.me.layout = tpl
    delta().layout = tpl or "-"
end

--- Send the changes of the character's own data.
function N.flushMe()
    local d = N.delta
    if not d then return end
    N.delta = nil
    local player = getSpecificPlayer(0)
    if not player or not sendClientCommand then return end
    -- (in parts: a first look at a shop knows hundreds of things)
    local function part(list)
        local out = {}
        for i = 1, math.min(#list, N.CHUNK) do out[i] = list[i] end
        return out, #list > N.CHUNK
    end
    while true do
        local msg, more, any = {}, false, false
        for _, k in ipairs({"known", "seen", "unseen", "lock", "unlock"}) do
            local list = d[k]
            if #list > 0 then
                local p, m = part(list)
                msg[k] = p
                any = true
                if m then
                    local rest = {}
                    for i = N.CHUNK + 1, #list do table.insert(rest, list[i]) end
                    d[k] = rest
                    more = true
                else
                    d[k] = {}
                end
            end
        end
        if d.order then msg.order, d.order, any = d.order, nil, true end
        if d.layout then msg.layout, d.layout, any = d.layout, nil, true end
        if not any then break end
        sendClientCommand(player, N.MODULE, "me", msg)
        if not more then break end
    end
end

-- Client: what the server sends ----------------------------------------------------------

--- The server's sizes: its "Size of bags and pockets" (KnoxFootprint.gridScale)
--- and its knox_overrides.txt lines over the player's own.
N.scale = nil

function N.applyConfig(args)
    N.scale = int(args.scale, 50, 200)
    if KnoxFootprint and KnoxFootprint.useOverrides then
        local lines = {}
        if type(args.overrides) == "table" then
            for _, l in ipairs(args.overrides) do
                if type(l) == "string" then table.insert(lines, l) end
            end
        end
        KnoxFootprint.useOverrides(lines)
    end
    if N.onChanged then N.onChanged() end
end

function N.applyMe(args)
    -- (added to what is here: marks made since the game started are on their way to the server too)
    for _, id in ipairs(type(args.known) == "table" and args.known or {}) do N.me.known[tonumber(id)] = true end
    for _, k in ipairs(type(args.seen) == "table" and args.seen or {}) do N.me.seen[k] = true end
    for _, id in ipairs(type(args.locks) == "table" and args.locks or {}) do N.me.locks[tonumber(id)] = true end
    if type(args.order) == "table" then
        local o = {}
        for _, k in ipairs(args.order) do if type(k) == "string" then table.insert(o, k) end end
        N.me.order = o
    end
    if type(args.layout) == "table" then N.me.layout = args.layout end
    if args.last then
        N.ready = true
        if N.onChanged then N.onChanged() end
    end
end

function N.onServerCommand(module, command, args)
    if module ~= N.MODULE or type(args) ~= "table" then return end
    if command == "config" then N.applyConfig(args)
    elseif command == "me" then N.applyMe(args) end
end

-- Server ---------------------------------------------------------------------------

--- The thing with this id in a container of the square (furniture, a body, a car,
--- a bag lying there; any depth), or nil.
local function inSquare(sq, id)
    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local o = objects:get(i)
        if o.getContainerCount then
            for j = 0, o:getContainerCount() - 1 do
                local c = o:getContainerByIndex(j)
                local it = c and c:getItemWithIDRecursiv(id)
                if it then return it end
            end
        end
    end
    local bodies = sq:getDeadBodys()
    for i = 0, (bodies and bodies:size() or 0) - 1 do
        local c = bodies:get(i):getContainer()
        local it = c and c:getItemWithIDRecursiv(id)
        if it then return it end
    end
    local wobs = sq:getWorldObjects()
    for i = 0, (wobs and wobs:size() or 0) - 1 do
        local item = wobs:get(i):getItem()
        local inv = item and item.getInventory and item:getInventory()
        local it = inv and inv:getItemWithIDRecursiv(id)
        if it then return it end
    end
    local v = sq:getVehicleContainer()
    if v then
        for i = 0, v:getPartCount() - 1 do
            local c = v:getPartByIndex(i):getItemContainer()
            local it = c and c:getItemWithIDRecursiv(id)
            if it then return it end
        end
    end
    return nil
end

--- The thing an entry is about, if the player can reach it.
function N.findItem(player, e)
    local id = int(e.id, -2147483648, 2147483647)
    if not id then return nil end
    if e.p then return player:getInventory():getItemWithIDRecursiv(id) end
    local x, y, z = int(e.x, 0, 100000), int(e.y, 0, 100000), int(e.z, -32, 64)
    if not (x and y and z) then return nil end
    if math.abs(player:getX() - x) > N.REACH or math.abs(player:getY() - y) > N.REACH or math.abs(player:getZ() - z) > 2 then
        return nil
    end
    local cell = getCell()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(x + dx, y + dy, z)
            local it = sq and inSquare(sq, id)
            if it then return it end
        end
    end
    return nil
end

--- A player's entries: written on the things, sent to the players near.
function N.serverItems(player, args)
    local list = type(args) == "table" and args.list
    if type(list) ~= "table" then return 0 end
    local touched, done = {}, 0
    for i, e in ipairs(list) do
        if i > N.MAX_ITEMS then break end
        if type(e) == "table" then
            local item = N.findItem(player, e)
            local v = item and N.accept(e.k, e.v)
            if item and v ~= false then
                local md = item:getModData()
                local cur = md[e.k]
                -- a place found by the grid: only where the thing had none in that container
                local keep = e.a and e.k == "knox" and type(cur) == "table" and v and cur.k == v.k
                if not keep then
                    md[e.k] = v
                    touched[item] = true
                    done = done + 1
                end
            end
        end
    end
    if syncItemModData then
        for item in pairs(touched) do syncItemModData(player, item) end
    end
    return done
end

--- Where the server keeps a character's own data (the world's global ModData, by
--- the account and the character's name: a new character after a death starts anew).
function N.storeOf(player)
    if not ModData or not player then return nil end
    local name = player:getUsername()
    if not name or name == "" then return nil end
    local desc = player:getDescriptor()
    local who = name .. "|" .. tostring(desc and desc:getForename() or "") .. " " .. tostring(desc and desc:getSurname() or "")
    local all = ModData.getOrCreate("KnoxPersonal")
    local s = all[who]
    if type(s) ~= "table" then
        s = {known = {}, seen = {}, locks = {}, n = 0}
        all[who] = s
    end
    return s
end

function N.serverMe(player, args)
    local s = N.storeOf(player)
    if not s or type(args) ~= "table" then return end
    local function ids(list, f)
        if type(list) ~= "table" then return end
        for i, id in ipairs(list) do
            if i > N.CHUNK then break end
            id = int(id, -2147483648, 2147483647)
            if id then f(id) end
        end
    end
    local function keys(list, f)
        if type(list) ~= "table" then return end
        for i, k in ipairs(list) do
            if i > N.CHUNK then break end
            k = str(k, 120)
            if k then f(k) end
        end
    end
    ids(args.known, function(id)
        if not s.known[id] then
            s.known[id] = true
            s.n = (s.n or 0) + 1
        end
    end)
    -- (a character that has seen a town: let go of, as the client's cache does)
    if (s.n or 0) > N.KNOWN_MAX then s.known, s.n = {}, 0 end
    keys(args.seen, function(k) s.seen[k] = true end)
    keys(args.unseen, function(k) s.seen[k] = nil end)
    ids(args.lock, function(id) s.locks[id] = true end)
    ids(args.unlock, function(id) s.locks[id] = nil end)
    if type(args.order) == "table" then
        local o = {}
        keys(args.order, function(k) if #o < 64 then table.insert(o, k) end end)
        s.order = o
    end
    if args.layout == "-" then
        s.layout = nil
    elseif type(args.layout) == "table" then
        local l = layouts({pockets = args.layout})
        s.layout = l and l.pockets or nil
    end
end

--- The server's sizes: Zomboid/Lua/knox_server.txt ("grid.scale = 100") and its
--- knox_overrides.txt (as a player's, read again when a player comes in).
local SERVER_FILE = "knox_server.txt"

local function readLines(name)
    local out = {}
    local r = getFileReader and getFileReader(name, false)
    if not r then return nil end
    local line = r:readLine()
    while line do
        table.insert(out, line)
        line = r:readLine()
    end
    r:close()
    return out
end

function N.serverConfig()
    local scale = 100
    local lines = readLines(SERVER_FILE)
    if not lines then
        local w = getFileWriter and getFileWriter(SERVER_FILE, true, false)
        if w then
            w:write("# Knox Inventory on this server. The same for every player:\r\n")
            w:write("#   grid.scale  the size of bags and pockets, 50..200 (% of Knox's own; players' own setting is not used here)\r\n")
            w:write("# Item sizes of the server's own: knox_overrides.txt next to this file (as a player's).\r\n")
            w:write("grid.scale = 100\r\n")
            w:write("# Own music of the car radio, heard by the players near the car (KnoxMusicNet):\r\n")
            w:write("#   music.share     1 on, 0 off (each player's music for themselves only)\r\n")
            w:write("#   music.files     1: a file another player lacks is sent through the server; 0: heard only by those who have it\r\n")
            w:write("#   music.max_mb    the largest file sent, MB\r\n")
            w:write("#   music.rate_kb   the speed of one file going to one player, KB/s\r\n")
            w:write("#   music.total_kb  all the music the server sends at once, KB/s\r\n")
            w:write("#   music.cache_mb  the files the server keeps in memory, MB\r\n")
            w:write("# Every part of a file is a line of the server's cmd log; ClientCommandFilter -KnoxMusic.up leaves them out.\r\n")
            w:write("music.share = 1\r\nmusic.files = 1\r\nmusic.max_mb = 15\r\nmusic.rate_kb = 128\r\nmusic.total_kb = 512\r\nmusic.cache_mb = 64\r\n")
            w:close()
        end
    else
        for _, l in ipairs(lines) do
            local v = string.match(l, "^%s*grid%.scale%s*=%s*(%d+)")
            if v then scale = int(v, 50, 200) or 100 end
        end
    end
    local overrides = {}
    for _, l in ipairs(readLines("knox_overrides.txt") or {}) do
        -- (comments and the display switch stay home)
        if not string.find(l, "^%s*#") and not string.find(l, "^%s*$") and not string.find(l, "^%s*show_ids") then
            table.insert(overrides, l)
            if #overrides >= 2000 then break end
        end
    end
    return {scale = scale, overrides = overrides}
end

--- The server's own music settings (knox_server.txt, music.*; KnoxMusicNet), each
--- kept in its bounds, the defaults for a line not there.
N.MUSIC = {share = 1, files = 1, max_mb = 15, rate_kb = 128, total_kb = 512, cache_mb = 64}
local MUSIC_BOUNDS = {share = {0, 1}, files = {0, 1}, max_mb = {1, 50}, rate_kb = {8, 2048}, total_kb = {16, 8192}, cache_mb = {8, 1024}}

function N.serverMusic()
    local m = {}
    for k, v in pairs(N.MUSIC) do m[k] = v end
    for _, l in ipairs(readLines(SERVER_FILE) or {}) do
        local k, v = string.match(l, "^%s*music%.([%a_]+)%s*=%s*(%d+)")
        local b = k and MUSIC_BOUNDS[k]
        if b then m[k] = int(v, b[1], b[2]) or m[k] end
    end
    -- (the cache holds at least one file of the largest, as base64)
    m.cache_mb = math.max(m.cache_mb, math.ceil(m.max_mb * 1.4))
    return m
end

--- A player has come in: the sizes, then the character's own data, in parts.
function N.serverHello(player)
    if not sendServerCommand then return end
    sendServerCommand(player, N.MODULE, "config", N.serverConfig())
    local s = N.storeOf(player) or {known = {}, seen = {}, locks = {}}
    local known, seen, locks = {}, {}, {}
    for id in pairs(s.known or {}) do table.insert(known, id) end
    for k in pairs(s.seen or {}) do table.insert(seen, k) end
    for id in pairs(s.locks or {}) do table.insert(locks, id) end
    local part, i, j, l = 1, 1, 1, 1
    repeat
        local msg = {part = part, known = {}, seen = {}, locks = {}}
        while i <= #known and #msg.known < N.CHUNK do table.insert(msg.known, known[i]) i = i + 1 end
        while j <= #seen and #msg.seen < N.CHUNK do table.insert(msg.seen, seen[j]) j = j + 1 end
        while l <= #locks and #msg.locks < N.CHUNK do table.insert(msg.locks, locks[l]) l = l + 1 end
        if part == 1 then msg.order, msg.layout = s.order, s.layout end
        local last = i > #known and j > #seen and l > #locks
        msg.last = last or nil
        sendServerCommand(player, N.MODULE, "me", msg)
        part = part + 1
    until last
end

function N.onClientCommand(module, command, player, args)
    if module ~= N.MODULE or not player then return end
    if command == "items" then N.serverItems(player, args)
    elseif command == "me" then N.serverMe(player, args)
    elseif command == "hello" then N.serverHello(player) end
end

-- Events ---------------------------------------------------------------------------

-- The character's data is asked for once the character is there (a new one is made
-- after the game has started), again if no answer comes, and anew for a character
-- made after a death (another character, other data).
local helloAt, helloTries = nil, 0
local HELLO_AGAIN_MS, HELLO_TRIES = 10000, 6

local function startOver()
    N.me = {known = {}, seen = {}, locks = {}, order = nil, layout = nil}
    N.ready, N.delta = false, nil
    helloAt, helloTries = nil, 0
end

local function hello()
    if N.ready or helloTries >= HELLO_TRIES then return end
    local now = getTimestampMs()
    if helloAt and now - helloAt < HELLO_AGAIN_MS then return end
    local player = getSpecificPlayer(0)
    if not player or not sendClientCommand then return end
    helloAt, helloTries = now, helloTries + 1
    sendClientCommand(player, N.MODULE, "hello", {})
end

if Events then
    if Events.OnClientCommand then Events.OnClientCommand.Add(N.onClientCommand) end
    if Events.OnServerCommand then Events.OnServerCommand.Add(N.onServerCommand) end
    if Events.OnTick then
        Events.OnTick.Add(function()
            if not N.mp() then return end
            hello()
            N.flush()
            N.flushMe()
        end)
    end
    if Events.OnGameStart then
        Events.OnGameStart.Add(function()
            if N.mp() then startOver() end
        end)
    end
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(function(playerNum)
            if N.mp() and playerNum == 0 then startOver() end
        end)
    end
end

return KnoxNet
