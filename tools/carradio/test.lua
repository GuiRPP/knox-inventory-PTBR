-- tools\carradio\test.lua: KnoxCarRadio.lua on the game's own Lua, outside the game -
-- own music left in one car while the driver drives another (both play), and back.
-- Run by test.ps1 as: this file's stubs part, KnoxCarRadio.lua, then this file again
-- with arg "run" (LuaRun runs the files in order; the global STAGE tells which).

if not STAGE then
    STAGE = "stubs"
    require = function() end
    local clock = 0
    function getTimestampMs() return clock end
    function ADVANCE(ms) clock = clock + ms end
    GAME_SPEED = 1
    function getGameSpeed() return GAME_SPEED end
    function getText(k) return k end
    SOUNDS = 0
    function addSound() SOUNDS = SOUNDS + 1 end
    TICKS = {}
    Events = {OnTickEvenPaused = {Add = function(f) table.insert(TICKS, f) end}}
    KnoxTheme = {active = true, settings = {}, saveSettings = function() end}

    -- the Java part: the player's track and the parked one
    JM = {main = nil, parked = nil, parkedEnded = false, swaps = 0, pVol = nil, pDark = nil}
    function knoxMusicSwapParked() JM.main, JM.parked = JM.parked, JM.main; JM.swaps = JM.swaps + 1 end
    function knoxMusicParkedPlay(name) JM.parked, JM.parkedEnded = name, false return true end
    function knoxMusicParkedPlaying() return JM.parked ~= nil and not JM.parkedEnded end
    function knoxMusicParkedVolume(v) JM.pVol = v end
    function knoxMusicParkedMuffle(d) JM.pDark = d end
    function knoxMusicParkedPause(p) JM.pPaused = p end
    function knoxMusicParkedStop() JM.parked = nil end
    function knoxMusicPause() end
    function knoxMusicMuffle(d) JM.mainDark = d end

    -- the player's music (KnoxMenuMusic, as far as KnoxCarRadio uses it)
    KnoxMenuMusic = {list = {}, at = 0}
    local MM = KnoxMenuMusic
    function MM.theme() return "mine" end
    function MM.vol() return 0.8 end
    function MM.carTrackVolume() return 1.2 end
    function MM.repeatMode() return "all" end
    function MM.stopTrack() JM.main = nil; MM.playing = nil end
    function MM.apply()
        MM.stopTrack()
        MM.list = {{name = "a.mp3", kind = "file"}, {name = "b.mp3", kind = "file"}, {name = "c.mp3", kind = "file"}}
        MM.at, MM.paused, MM.ended = 0, false, false
    end
    function MM.play(i)
        MM.stopTrack()
        MM.at = i
        MM.playing = {kind = "file", name = MM.list[i].name}
        JM.main = MM.list[i].name
    end
    function MM.applyRadio() end
    function MM.applyVolume() end
    function MM.stopHiss() end

    -- cars and the player
    local function car(name, x)
        local dd = {on = true, power = true, vol = 0.6}
        function dd:getIsTurnedOn() return self.on end
        function dd:canBePoweredHere() return self.power end
        function dd:getDeviceVolume() return self.vol end
        function dd:setDeviceVolume(v) self.vol = v end
        function dd:getBaseVolumeRange() return 20 end
        function dd:getEmitter() return nil end
        local md = {}
        local part = {}
        function part:getInventoryItem() return true end
        function part:getDeviceData() return dd end
        function part:getModData() return md end
        local v = {name = name, x = x, dd = dd, md = md}
        function v:getPartById() return part end
        function v:getPartCount() return 0 end
        function v:getX() return self.x end
        function v:getY() return 0 end
        function v:getZ() return 0 end
        return v
    end
    CAR1, CAR2, CAR3 = car("car1", 0), car("car2", 3), car("car3", 6)
    PL = {x = 0, veh = nil, dead = false}
    function PL:getVehicle() return self.veh end
    function PL:isDead() return self.dead end
    function PL:getX() return self.x end
    function PL:getY() return 0 end
    function PL:getZ() return 0 end
    return
end

local R, MM = KnoxCarRadio, KnoxMenuMusic
local pass, fail = 0, 0
local function check(what, ok)
    if ok then pass = pass + 1 else fail = fail + 1; print("FAIL " .. what) end
end
local function tick(n)
    for _ = 1, n or 1 do
        ADVANCE(50)
        for _, f in ipairs(TICKS) do f() end
    end
end

-- in car 1, own music on
PL.veh = CAR1
R.enter(PL, CAR1)
MM.play(1)
tick(2)
check("car 1 plays its track", JM.main == "a.mp3" and R.musicPlaying())
check("car 1's broadcast down under it", CAR1.dd.vol == 0 and CAR1.md.knoxVol == 0.6)

-- out of car 1: it goes on from the car
PL.veh = nil
R.leave()
tick(2)
check("out of car 1: heard from outside", R.outside and JM.main == "a.mp3")

-- far off: still on, silent
PL.x = 500
tick(5)
check("far off: not stopped", R.vehicle == CAR1 and JM.main == "a.mp3" and MM.carFar == 0)
PL.x = 2

-- the gap between two tracks outside: the next one, not the broadcast
MM.playing = nil
MM.nextAt = getTimestampMs() / 1000 + 3
tick(3)
check("gap outside: music still on", R.vehicle == CAR1 and R.outside and CAR1.dd.vol == 0)
MM.play(2)

-- a passenger in car 2: car 1's music still on from outside
PL.veh = CAR2
tick(3)
check("passenger of car 2: car 1 on", R.vehicle == CAR1 and R.outside and JM.main == "b.mp3")

-- at car 2's wheel: car 1's track parked, playing on; car 2's own player
R.enter(PL, CAR2)
tick(2)
check("car 1 parked", R.parked ~= nil and R.parked.vehicle == CAR1 and JM.parked == "b.mp3")
check("player's track free for car 2", JM.main == nil and R.vehicle == CAR2 and not R.outside)
check("car 1's broadcast stays down", CAR1.dd.vol == 0)
check("parked track heard by the distance", JM.pVol ~= nil and JM.pVol > 0 and JM.pDark ~= nil)
MM.play(3)
check("both play", JM.main == "c.mp3" and JM.parked == "b.mp3")

-- car 1's track ends: its next one, in car 1
JM.parkedEnded = true
tick(1)
check("parked: gap after its track", JM.parked == "b.mp3" and R.parked.playing == false)
tick(70)
check("parked: its next track", JM.parked == "c.mp3" and R.parked.playing)

-- driven far off: parked goes on silent
PL.x = 900
tick(6)
check("parked far off: on, silent", R.parked ~= nil and JM.pVol == 0)
PL.x = 2

-- out of car 2 (its music on: outside), back at car 1's wheel: they change places
PL.veh = nil
R.leave()
tick(2)
check("car 2 heard from outside", R.outside and R.vehicle == CAR2)
PL.veh = CAR1
R.enter(PL, CAR1)
tick(2)
check("back in car 1: its track is the player's", JM.main == "c.mp3" and MM.playing and MM.playing.name == "c.mp3" and MM.at == 3)
check("car 2 parked now", R.parked ~= nil and R.parked.vehicle == CAR2 and JM.parked == "c.mp3")
check("car 1 inside again", not R.outside and JM.mainDark == -1)

-- out of car 1, into car 3: car 2's (the older) stops, car 1's is parked
PL.veh = nil
R.leave()
tick(1)
PL.veh = CAR3
R.enter(PL, CAR3)
tick(2)
check("car 3: car 1 parked, car 2 off", R.parked and R.parked.vehicle == CAR1 and CAR2.dd.vol == 0.6 and CAR2.md.knoxVol == nil)

-- car 1's set switched off: its music off, its knob back
CAR1.dd.on = false
tick(1)
check("parked set off: stopped", R.parked == nil and JM.parked == nil and CAR1.dd.vol == 0.6)

-- the game paused: the parked track waits
CAR2.dd.on = true
PL.veh = nil
R.leave()
MM.play(1)
R.leave(true)
PL.veh = CAR1
CAR1.dd.on = true
R.enter(PL, CAR1)
MM.play(1)
PL.veh = nil
R.leave()
tick(1)
PL.veh = CAR2
R.enter(PL, CAR2)
GAME_SPEED = 0
tick(1)
check("paused: parked waits", JM.pPaused == true and R.parked ~= nil)
GAME_SPEED = 1
tick(1)
check("unpaused: parked on", JM.pPaused == false)

-- the player dead: off
PL.dead = true
tick(1)
check("dead: parked off", R.parked == nil and JM.parked == nil)

print("DONE pass=" .. pass .. " fail=" .. fail)
