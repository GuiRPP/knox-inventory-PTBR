-- The winter bar's build (the QA of its stage 1, 2026-10-31; since stage 2 the room goes to
-- its own frame, KnoxBarFrame.java): every model of the room is in the frame's lists and has
-- its files, every shader the frame loads is there, a room with a file missing is not
-- "built" - the menu has its camp then - and a frame failing later brings the camp back.
local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else fail = fail + 1; print("FAIL " .. name .. (detail and (" : " .. tostring(detail)) or "")) end
end

local b = KnoxMenuBar:new()
b:loadTextures()
b:build()
check("builtOk after build", b:builtOk())
check("returned told", calls.returned == true)
check("no scene models of its own", #b.objects == 0, #b.objects)
check("the room listed", #calls.created >= 49, #calls.created)

-- the lists, and the files of our own models
local lists = {}
for _, f in ipairs({"bar_models.txt", "bar_vp.txt"}) do
    local text = readfile(MOD .. "/42/media/knox/" .. f)
    check("list read " .. f, text ~= nil)
    local module = string.match(text, "module%s+([%w_]+)")
    for name in string.gmatch(text, "\n%s*model%s+([%w_]+)") do lists[module .. "." .. name] = true end
    for mesh in string.gmatch(text, "mesh = knoxmenu/([%w_]+)") do
        check("mesh file " .. mesh, readfile(MOD .. "/42/media/models_X/knoxmenu/" .. mesh .. ".x") ~= nil)
    end
end
local used = {}
for i, c in ipairs(calls.created) do
    used[c.model] = true
    check("model in a list: #" .. i .. " " .. c.model, lists[c.model] == true)
    check("scale above 0: #" .. i, c.sx > 0 and c.sy > 0 and c.sz > 0)
    check("what moves is known: #" .. i, c.moves == 0 or c.moves == 1 or c.moves == 2 or (c.moves >= 3 and c.moves <= 11), c.moves)
end
for s in pairs(lists) do
    check("list model used: " .. s, used[s] == true)
end
local doors, lamps, sheets = 0, 0, 0
for _, c in ipairs(calls.created) do
    if c.moves == 1 then doors = doors + 1 elseif c.moves == 2 then lamps = lamps + 1 elseif c.moves == 3 then
        sheets = sheets + 1
        -- (QA, 2026-10-31: below the floor's height half of a sheet was under it)
        if c.rx == 0 then check("a sheet not under the floor: " .. c.model, c.y >= 0.004, c.y) end
    end
end
check("one door moves", doors == 1, doors)
check("three loose sheets", sheets == 3, sheets)
check("three lamps move", lamps == 3, lamps)

-- the frame's shaders, as its Java asks for them
local java = readfile(MOD .. "/java/src/knox/java/KnoxBarFrame.java")
check("frame source read", java ~= nil)
local shaders = 0
for name in string.gmatch(java, "\"([%w_]+%.[vf][er][ra][tg])\"") do
    shaders = shaders + 1
    check("shader file " .. name, readfile(MOD .. "/42/media/shaders/knoxbar/" .. name) ~= nil)
end
check("shaders found", shaders >= 16, shaders)

check("scene lights: 23 values", calls.sceneLights and #calls.sceneLights == 23, calls.sceneLights and #calls.sceneLights)

-- the frame opens and closes in pairs, only once the camera is there
b.width, b.height, b.frames, b.clock, b.dt = 1920, 1080, 1, 5, 0.016
local el = {width = 1920, height = 1080, drawRect = function() end}
b:drawBackdrop()
b:drawFx(el)
check("no frame before the camera", calls.begun == 0 and calls.ended == 0)
b.frames = 10
b:drawBackdrop()
b:drawFx(el)
check("frame opened", calls.begun == 1)
check("frame closed", calls.ended == 1)
check("closed with the scene's camera", calls.endScene == b.scene.javaObject)
b:drawFx(el)
check("not closed twice", calls.ended == 1)

-- out of the menu (Continue, in any mode): the frame goes on through the fade, the targets go
-- at its end, once; back in the menu all of it is there again
local clock = 1000
local keepClock = getTimestampMs
getTimestampMs = function() return clock end
local inMenu = knoxMenuInMenu
knoxMenuInMenu = function() return false end
local begun = calls.begun
b:drawBackdrop()
b:drawFx(el)
clock = 1200
b:drawBackdrop()
b:drawFx(el)
check("fade: still drawn", calls.begun == begun + 2 and calls.rested == nil)
clock = 1300
b:drawBackdrop()
b:drawFx(el)
clock = 1400
b:drawBackdrop()
b:drawFx(el)
check("fade over: rests once", calls.rested == 1, calls.rested)
check("fade over: frame no more", calls.begun == begun + 2, calls.begun - begun)
check("fade over: closed as it opened", calls.ended == calls.begun, calls.ended)
check("fade over: heroes hidden", b.scene.visible == false)
knoxMenuInMenu = inMenu
getTimestampMs = keepClock
b:drawBackdrop()
b:drawFx(el)
check("back: frame again", calls.begun == begun + 3)
check("back: heroes shown", b.scene.visible == true)
b:restWhileLoading()
check("back: can rest again", calls.rested == 2, calls.rested)

-- the heroes (stage 4, 2026-10-31): the three latest alive at their places, a dead one not
-- among them; their bags; the empty stool's glass
local U = 1 / 1.22
testSaves = {
    {rel = "a", dead = false, bag = {back = {type = "Base.Bag_ALICEpack"}}},
    {rel = "dead", dead = true},
    {rel = "b", dead = false, bag = {back = {type = "Base.Bag_Schoolbag"}}},
    {rel = "c", dead = false, bag = {back = {type = "Base.Bag_BigHikingBag"}}},
    {rel = "d", dead = false},
}
calls.heroes = {}
local h = KnoxMenuBar:new()
h:loadTextures()
h:build()
check("heroes: three", #h.chars == 3, #h.chars)
check("heroes: not the dead", h.chars[2].save.rel == "b")
local function near(a, b) return math.abs(a - b) < 1e-4 end
local h1, h2, h3 = h.chars[1], h.chars[2], h.chars[3]
check("hero 1 on the stool", h1.anim == "knoxbar_stool" and near(h1.y, 0.2) and near(h1.x, -1.75 * U) and near(h1.z, 0.05 * U))
check("hero 2 smokes", h2.anim == "knoxbar_smoke" and h2.hand == "Base.Cigarette_Lit" and h2.face == 90)
check("hero 3 stands at the door", h3.anim == "knoxmenu_stand" and near(h3.x, 2.7 * U) and h3.face == 131)
check("hero 1's bag on the counter", h1.bagAt and near(h1.bagAt.y, 1.1 * U) and near(h1.bagAt.x, -1.3 * U))
check("hero 2's bag on the floor", h2.bagAt and h2.bagAt.y == 0)
check("hero 3 keeps the pack on", h3.bagAt == nil and h3.pack == true)
check("hero 1 has no pack drawn", h1.pack == false)
check("the poses' clips known", h.clips.knoxbar_stool == "Knox_BarStool" and h.clips.knoxbar_smoke == "Knox_BarSmoke")
check("the glass is a new game", #h.empties == 1 and h.empties[1].empty and h.empties[1].mat.tinted == nil)

-- before they come in: no shadows, no light; then by light, alpha 1 at once
h.width, h.height, h.frames, h.clock, h.dt = 1920, 1080, 10, 5, 0.016
h:updateHeroes()
check("hidden: no shadows", calls.hero[1] == false and calls.hero[2] == false and calls.hero[3] == false)
check("hidden: no ember asked", calls.ember == nil)
h:lightCharacter(h1, 1)
check("hidden: dark", calls.light[h1.id][4] == 0)
for _, c in ipairs(h.chars) do h:watchHero(c, 1) end
check("shown: alpha 1", calls.alpha[h1.id] == 1 and calls.alpha[h3.id] == 1)
h:fadeIn(h1, 1 + 0.6)
check("coming in by light", h1.lightK > 0 and h1.lightK < 1, h1.lightK)
for _, c in ipairs(h.chars) do h:fadeIn(c, 10) end
check("all in", h1.lightK == 1 and h1.fadeAt == nil)
h:updateHeroes()
check("shadows: each its own", calls.hero[1].id == h1.id and calls.hero[3].id == h3.id)
check("shadows: from the stool's height", near(calls.hero[1].y, 0.2))
check("shadows: the pack", calls.hero[3].pack == true and calls.hero[1].pack == false)
check("ember: the smoker's", calls.ember == h2.id and h2.emberGlow == 0.5)
check("ember: as far as the smoker is shown", calls.emberShown == h2.lightK)
check("door: as the wind has it", calls.door == 0)
h:lightCharacter(h3, 1)
local l3 = calls.lights[h3.id]
check("hero 3: the storm's light", l3 and l3[4] > 0.2 and l3[12] == 0)
h:lightCharacter(h2, 1)
local l2 = calls.lights[h2.id]
check("hero 2: the ember on the face", l2 and l2[10] > 0 and l2[10] > l2[12])
h:lightCharacter(h1, 1)
local l1 = calls.lights[h1.id]
check("hero 1: the storm's light, no candle by him", l1 and l1[4] > 0 and l1[10] == 0, l1 and l1[10])
h.hover = h1
h:lightCharacter(h1, 1)
check("hover: brighter", near(calls.light[h1.id][4], 1.4))
h.hover = nil
-- (QA, 2026-10-31) no snapshot of the save: a dark figure, as in the camp
h1.dressed = false
h:lightCharacter(h1, 1)
check("no snapshot: dark", near(calls.light[h1.id][4], 0.25), calls.light[h1.id][4])
h1.dressed = true

-- where they look
h.eyeX, h.eyeY, h.eyeZ = -3.4 * U, 1.95 * U, 3.9 * U
h.mode = "idle"
for i = 1, 60 do h:updateLooks(0.05) end
check("hero 1: its own head (the clip's)", calls.look[h1.id] == nil)
check("hero 3: looks back", calls.look[h3.id] and math.abs(calls.look[h3.id][1]) > 30 and calls.look[h3.id][3] == 1)
check("hero 2: its own head", calls.look[h2.id] == nil)
h.hover = h1
for i = 1, 60 do h:updateLooks(0.05) end
check("hover: hero 1 still, its own head (the author, 2026-11-01)", calls.look[h1.id] == nil)
h.hover = h3
for i = 1, 60 do h:updateLooks(0.05) end
check("hover: hero 3 still looks at the camera", calls.look[h3.id] and calls.look[h3.id][3] == 1)
h.hover = nil

-- one is picked: no walk out any more (the author, 2026-11-01) - black where they are, the save
for _, c in ipairs({h1, h3}) do
    calls.launched = nil
    h.fader = nil
    local x, z = c.x, c.z
    h:leave(c)
    check("leave: black asked at once, " .. c.id, h.fader.target == 1 and c.phase == "fade")
    h.fader.alpha = 0.5
    for i = 1, 20 do h:updateLeaving(0.05) end
    check("leave: not launched before black, " .. c.id, calls.launched == nil)
    check("leave: stays where it is, " .. c.id, c.x == x and c.z == z and c.anim == c.seat.s.anim)
    for i = 1, 60 do h:updateLooks(0.05) end
    check("leave: its own head, " .. c.id, calls.look[c.id] == nil or calls.look[c.id][3] == 0)
    h.fader.alpha = 1
    h:updateLeaving(0.05)
    check("leave: launched, " .. c.id, calls.launched == c.id)
    h:comeBack()
    check("back: at its place, " .. c.id, c.x == x and c.z == z and c.anim == c.seat.s.anim)
    check("back: door as the wind has it, " .. c.id, h.doorOpen == 0)
end
h1.y = h1.seat.y
check("back: on the stool again", near(h1.y, 0.2) and h1.anim == "knoxbar_stool" and near(h1.x, -1.75 * U))
h.doorOpen = 1
h:updateHeroes()
check("door: told to the frame", calls.door > 0.9)
h.doorOpen = 0

-- a file missing: not built, the game not told
barLoads = false
calls.returned = nil
local failing = KnoxMenuBar:new()
failing:loadTextures()
failing:build()
check("no mod: not built", not failing:builtOk())
check("no mod: return not told", calls.returned == nil)
barLoads = true
failing:build()
check("built again with the mod", failing:builtOk())

-- the frame failing on the video card: the camp, for good, built anew outside of drawing
barFails = true
local rebuilt = 0
KnoxMenuScene.instance = b
KnoxMenuScene.create = function() rebuilt = rebuilt + 1 end
b:drawBackdrop()
check("failed: camp for good", KnoxMenuScene.barFailed == true)
check("failed: not rebuilt while drawing", rebuilt == 0)
check("failed: one rebuild queued", #Events.OnPreUIDraw.list == 1, #Events.OnPreUIDraw.list)
b:drawBackdrop()
check("failed: queued once", #Events.OnPreUIDraw.list == 1, #Events.OnPreUIDraw.list)
Events.OnPreUIDraw.list[1]()
check("failed: rebuilt", rebuilt == 1)
check("failed: queue empty", #Events.OnPreUIDraw.list == 0)

-- the sounds (stage 6, 2026-10-31)
do
    local s = KnoxMenuBar:new()
    s.frames, s.mode = 1, "idle"
    calls.sounds, calls.campTick, calls.moans = 0, 0, 0
    s:updateSounds(0)
    check("sounds: not before the frame is up", calls.sounds == 0)
    s.frames = 3
    s:updateSounds(1)
    check("sounds: every frame", calls.sounds == 1)
    check("sounds: no moan at once", calls.moans == 0)
    s:updateSounds(1 + 80)
    check("sounds: a moan now and then", calls.moans == 1, calls.moans)
    s:updateSounds(1 + 81)
    check("sounds: not one each frame", calls.moans == 1, calls.moans)
    s.mode = "launched"
    local before = calls.sounds
    s:updateSounds(90)
    check("sounds: once gone the camp's end ticks", calls.campTick == 1 and calls.sounds == before)
end

-- the radio's card: where the broken radio is (the camera's own projection, on a stub: a metre
-- is 100 pixels), and the same table each frame
do
    local s = KnoxMenuBar:new()
    s.toScreen = function(_, x, y, z) return x * 100, 500 - y * 100 end
    local r = s:radioRect()
    check("radio: over its place", r[1] < -2.315 * 100 / 1.22 and r[1] + r[3] > -2.315 * 100 / 1.22, r[1])
    check("radio: above the counter", r[2] + r[4] > 500 - 1.1 * 100 / 1.22 - 1, r[2])
    check("radio: the same table", s:radioRect() == r)
    check("radio: wins over the hero behind it", s:hit({}, r[1] + r[3] / 2, r[2] + r[4] / 2) == false)
    check("radio: a hero elsewhere still", s:hit({}, r[1] - 50, r[2]) == true)

    -- the glass: only round itself (QA, 2026-10-31: the stool's whole place took in the smoker's table)
    local g = s:glassRect()
    local gx, gy = -2.86 * 100 / 1.22, 500 - 1.1 * 100 / 1.22
    check("glass: over the glass", g[1] < gx and g[1] + g[3] > gx and g[2] < gy and g[2] + g[4] > gy)
    check("glass: hit on it", s:hit({empty = true}, gx, gy - 5) == true)
    check("glass: not a metre off", s:hit({empty = true}, gx - 100, gy - 5) == false)
    check("glass: not over the radio", g[1] + g[3] < r[1])
    check("glass: its card over it", s:rectOf({empty = true}) == g)

    -- what can be pointed at has a soft cold light under the mouse (stage 7), nothing else has;
    -- the light's middle on the thing
    local drawn, lx, ly = 0
    local e = {drawTextureScaled = function(_, _, x, y, w, h) drawn = drawn + 1; lx, ly = x + w / 2, y + h / 2 end}
    s.tex = {glow = {}}
    s:drawPointed(e)
    check("pointed: nothing under the mouse, no light", drawn == 0)
    s.hover = {empty = true}
    s:drawPointed(e)
    check("pointed: the glass", drawn == 1 and math.abs(lx - (g[1] + g[3] / 2)) < 1 and math.abs(ly - (g[2] + g[4] / 2)) < 1, lx)
    s.hover = {save = {}}
    s:drawPointed(e)
    check("pointed: not a hero (his own light)", drawn == 1)
    s.hover, s.radioHover = nil, true
    s:drawPointed(e)
    check("pointed: the radio", drawn == 2 and math.abs(lx - (r[1] + r[3] * 0.653)) < 1 and math.abs(ly - (r[2] + r[4] / 2)) < 1, lx)
    s.radioHover = false
    KnoxRadioCard = {instance = {getIsVisible = function() return true end}}
    s:drawPointed(e)
    check("pointed: the radio while its card is up", drawn == 3)
    KnoxRadioCard = nil
    -- a hero's bag: under the mouse, and while its card is up (the camp's has its light too)
    s.bagRect = function() return {300, 400, 40, 30} end
    s.bagHover = {bagAt = {}}
    s:drawPointed(e)
    check("pointed: the bag", drawn == 4 and math.abs(lx - 320) < 1 and math.abs(ly - 415) < 1, lx)
    s.bagHover, s.bagShown = nil, {bagAt = {}}
    KnoxBagCard = {isUp = function() return true end}
    s:drawPointed(e)
    check("pointed: the bag while its card is up", drawn == 5)
    KnoxBagCard = nil
    s:drawPointed(e)
    check("pointed: the card down, no light", drawn == 5)
end

-- the dead out in the storm (the author, 2026-11-01): dressed once the wardrobe is read, in their
-- walk, on along the wall and round again; nobody points at them
do
    local s = KnoxMenuBar:new()
    s.clock, s.dt, s.chars = 0, 0.5, {}
    local placed = {}
    local jo = {
        fromLua1 = function(_, what, id)
            if what == "getObjectTranslation" then
                return {set = function(_, x, y, z) placed[id] = {x, y, z} end}
            end
        end,
        fromLua2 = function() end,
    }
    s.scene.javaObject = jo
    s.cfg = {clearDepth = false}
    local dressed, lit, posed = {}, {}, false
    local wardrobe = false
    knoxBarDead = function(_, id) dressed[id] = true; return true end
    knoxBarClothesLoaded = function() return wardrobe end
    knoxMenuAnim = function() return true end
    local light = knoxMenuLight
    knoxMenuLight = function(_, id, ar, ag, ab, k) lit[id] = k end
    local watch = s.watchPose
    s.watchPose = function(_, c, t) if posed then c.posedAt = t end end
    s.zombieSpeed = function() return 0.3 end
    s:addDead()
    check("dead: three, none among the heroes", #s.dead == 3 and #s.chars == 0)
    check("dead: too small to see at first", s.dead[1].s == 0.001 and s.dead[1].placed == 1)
    s:updateDead()
    check("dead: not dressed before the wardrobe", dressed.kb_dead1 == nil)
    wardrobe = true
    s:updateDead()
    check("dead: dressed", dressed.kb_dead1 and dressed.kb_dead2)
    s:updateDead()
    check("dead: not shown before their walk", s.dead[1].shownAt == nil)
    posed = true
    s.clock = 1
    s:updateDead()
    check("dead: shown in their walk", s.dead[1].shownAt == 1 and s.dead[1].s == 1)
    local x1, x2 = s.dead[1].x, s.dead[2].x
    s.clock = 2
    s:updateDead()
    check("dead: each its way", s.dead[1].x > x1 and s.dead[2].x < x2 and placed.kb_dead1[1] == s.dead[1].x)
    check("dead: lit, as they come", lit.kb_dead1 and lit.kb_dead1 > 0.7, lit.kb_dead1)
    s.dead[1].x = 10
    s.dead[2].x = -6
    s:updateDead()
    s.dt = 2
    s:updateDead()
    check("dead: round again out of sight", s.dead[1].x < 0 and s.dead[2].x > 0, s.dead[1].x)
    -- (a giving up: never in its pose, on after a while)
    local c = s.dead[3]
    c.shownAt, c.s = nil, 0.001
    posed = false
    s.clock = c.cladAt + 31
    s:updateDead()
    check("dead: given up on, shown as it is", c.shownAt ~= nil and c.s == 1)
    knoxBarDead, knoxBarClothesLoaded, s.watchPose = nil, nil, watch
    knoxMenuLight = light
end

print(string.format("bar: %d pass, %d fail", pass, fail))
