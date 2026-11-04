-- Stubs for KnoxMenuSceneBar.lua build() outside the game (the QA of the bar's stage 1,
-- 2026-10-31): records every model and its place, as the frame gets them
require = function() end
KnoxTheme = {animOn = function() return true end, switch = function() return true end}
calls = {sceneLights = nil, created = {}, begun = 0, ended = 0, stopped = 0}
barLoads, barFails = true, false
function getTexture(p) return {path = p} end
function ZombRand(n) return math.floor(n / 2) end
function ZombRandFloat(a, b) return (a + b) / 2 end
function knoxMenuSceneLights(t) local c = {} for i, v in ipairs(t) do c[i] = v end calls.sceneLights = c end
function knoxMenuFireFlicker() end
function getTimestampMs() return 0 end
function knoxBarStart() calls.created = {} end
function knoxBarProp(model, x, y, z, rx, ry, rz, sx, sy, sz, r, g, b, moves)
    table.insert(calls.created, {model = model, x = x, y = y, z = z, rx = rx, ry = ry, rz = rz, sx = sx, sy = sy, sz = sz, r = r, g = g, b = b, moves = moves})
end
function knoxBarLoad() return barLoads end
function getCore() return {getOptionSoundVolume = function() return 10 end} end
function knoxBarFailed() return barFails end
function knoxBarQuality() end
function knoxBarBegin() calls.begun = calls.begun + 1 end
function knoxBarEnd(scene) calls.ended = calls.ended + 1; calls.endScene = scene end
function knoxBarRest() calls.rested = (calls.rested or 0) + 1 end
function knoxBarStop() calls.stopped = calls.stopped + 1 end
function knoxMenuInMenu() return true end
Events = {OnPreUIDraw = {list = {}}}
function Events.OnPreUIDraw.Add(f) table.insert(Events.OnPreUIDraw.list, f) end
function Events.OnPreUIDraw.Remove(f)
    for i, g in ipairs(Events.OnPreUIDraw.list) do if g == f then table.remove(Events.OnPreUIDraw.list, i) return end end
end
function knoxMenuReturned() calls.returned = true end
function knoxMenuMuteAmbience() end
function knoxMenuResetGL() end
KnoxMenuKeep = nil

KnoxMenuScene = {}
KnoxMenuScene.__index = KnoxMenuScene
function KnoxMenuScene:derive(name)
    local d = {}
    d.__index = d
    setmetatable(d, {__index = self})
    d.Type = name
    return d
end
function KnoxMenuScene.new(cls)
    local o = setmetatable({}, cls)
    local jo = {fromLua1 = function() end}
    o.scene = {javaObject = jo, setVisible = function(s, v) s.visible = v end}
    return o
end
function KnoxMenuScene:aimCamera() end
function KnoxMenuScene:drawRect() end
function KnoxMenuScene:drawSwitch() end

-- the heroes (stage 4, 2026-10-31): the camp's own part of it, as far as the bar leans on it
KnoxTheme.mod = function(a, b) return a - math.floor(a / b) * b end
calls.hero, calls.heroes, calls.light, calls.lights, calls.look, calls.alpha = {}, {}, {}, {}, {}, {}
testSaves = nil
function KnoxMenuScene.recentSaves() return testSaves or {} end
function KnoxMenuScene:yawOf(face) return -face end
function KnoxMenuScene:place(o) o.placed = (o.placed or 0) + 1 end
function KnoxMenuScene:steps(c) calls.steps = (calls.steps or 0) + 1 end
function KnoxMenuScene:hit(c, mx, my) return true end
function KnoxMenuScene:rectOf(c) return {0, 0, 1, 1}, 1 end
KnoxTheme.inRect = function(x, y, r) return x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4] end
function KnoxMenuScene:addBag(c, slot)
    c.bag = c.save.bag
    local at = (self.bagPlaces or {})[slot]
    if at and c.bag and c.bag.back then c.bagAt = {x = at[1], y = at[4] or 0, z = at[2]} end
end
function KnoxMenuScene:addCharacter(c)
    c.anim = c.anim or "knoxmenu_warm"
    table.insert(calls.heroes, {id = c.id, anim = c.anim, hand = c.hand})
    c.dressed = true
    c.yaw = self:yawOf(c.face)
    table.insert(self.objects, c)
    table.insert(self.chars, c)
    return true
end
function KnoxMenuScene:makePortrait() return {} end
function KnoxMenuScene:setAnim(c, state) c.anim = state end
function KnoxMenuScene:showFader() self.fader = self.fader or {alpha = 0, target = 0} end
function KnoxMenuScene:launch(c) self.mode = "launched"; calls.launched = c.id end
function KnoxMenuScene:comeBack()
    local c = self.leaving
    self.leaving = nil
    self.mode = "idle"
    if c and c.seat then
        c.x, c.z, c.face, c.faceNow = c.seat.x, c.seat.z, c.seat.face, nil
        self:setAnim(c, "knoxmenu_sit")
    end
end
function KnoxMenuScene:watchHero(c, t) c.shownAt = t; c.fadeAt = t end
function knoxMenuClipSeconds() return 1.0 end
function getSoundManager() return {playUISound = function() end} end
function knoxBarHero(scene, id, slot, x, y, z, face, pack)
    calls.hero[slot + 1] = id and {id = id, x = x, y = y, z = z, face = face, pack = pack} or false
end
function knoxBarEmber(scene, id, x, y, z, face, shown) calls.ember = id; calls.emberShown = shown; return 0.5 end
function knoxBarDoor(v) calls.door = v end
function knoxBarCandle() return 0.8 end
function knoxBarSounds() calls.sounds = (calls.sounds or 0) + 1 end
function knoxBarDoorOpens() calls.doorOpens = (calls.doorOpens or 0) + 1 end
function knoxCampTick() calls.campTick = (calls.campTick or 0) + 1; return true end
function knoxCampMoan() calls.moans = (calls.moans or 0) + 1 end
function knoxCampStep() calls.steps = (calls.steps or 0) + 1 end
function knoxMenuLight(j, id, ar, ag, ab, tr) calls.light[id] = {ar, ag, ab, tr} end
function knoxBarHeroLights(j, id, ...) calls.lights[id] = {...} end
function knoxMenuLook(j, id, yaw, pitch, w) calls.look[id] = {yaw, pitch, w} end
function knoxMenuAlpha(j, id, a) calls.alpha[id] = a end
