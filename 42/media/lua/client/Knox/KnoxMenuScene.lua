-- The main menu as a place: a camp at night, a fire, and around it the heroes
-- of the player's three latest saves still alive, dressed as they were left.
-- Hovering one shows who it is; clicking makes them get up and walk off, the
-- screen goes dark and their save loads. A hero who died is not at the fire:
-- the latest ones stand in the dark beyond the fence, older ones have crosses.
--
-- The scene is a UI3DScene under the whole menu (the Java part gives it a
-- perspective camera, dresses and lights the characters: KnoxMenu.java). The
-- models and textures are generated (Knox Inventory Java/tools/menugen). A
-- save's hero is known from a snapshot written while the save is played, at
-- the end of this file.

require "ISUI/ISUIElement"
require "ISUI/ISUI3DModel"
require "Vehicles/ISUI/ISUI3DScene"
require "Knox/KnoxTheme"

KnoxMenuScene = ISUIElement:derive("KnoxMenuScene")
local M = KnoxMenuScene
local T = KnoxTheme

-- Layout ----------------------------------------------------------------------
-- Scene units, Y up, the fire at the origin, the camera looking down -Z.
-- A standing character is 1.47 units tall.

local CFG = {
    fov = 22,                     -- vertical, degrees
    eye = {0, 1.6, 7.6},
    target = {0, 0.80, -0.6},
    -- a character's rotation for a facing angle (0 = towards the camera,
    -- 90 = towards +X): rotY = yawOffset + yawSign * facing (seen in game:
    -- rotY 180 shows the back, 242 looks towards +X and away)
    yawOffset = 0,
    yawSign = -1,
    clearDepth = false,           -- true: every character is drawn over what came before it
    walkSpeed = 0.95,             -- units per second
    zombieWalkSpeed = 0.27,       -- units per second of the dead shambling along the fence (0.33: feet slid)
    sitHeight = 0.95,             -- of a sitting character, for hover
    standHeight = 1.5,
}

-- where the heroes sit: 1 = the latest save (behind the fire), 2 = left, 3 = right
local SEATS = {
    {x = 0.0, z = -1.9, face = 0, leave = {0.55, 1.0}},
    {x = -1.55, z = -0.25, face = 62, leave = {-1.0, 0.15}},
    {x = 1.55, z = -0.25, face = -62, leave = {1.0, 0.15}},
}
-- where the dead stand, beyond the fence: the heroes of the latest saves who
-- died (not only of the three seats), newest first
-- They must be seen from the fire: the pickup (x -5.2 .. -0.6 at z -9.6) hides
-- everything left of x = -0.5 out there, and the tent on the right everything
-- beyond about 3.2 - so they stand in the gap between the two, over the crosses.
-- (Before 2026-10-13 two of the first three stood behind the car and the tent.)
local GRAVES = {
    {x = 0.3, z = -15.4, face = -4},
    {x = 2.9, z = -15.6, face = -16},
    {x = 1.6, z = -15.1, face = -10},
    {x = 2.2, z = -15.8, face = -12},
    {x = 0.9, z = -15.7, face = -6},
    {x = -0.2, z = -15.2, face = 0},
}
-- and where their crosses stand, this side of it
-- how many of the dead walk there; the ones who died before them have crosses
local RISEN = 3
-- They don't sway as one (the author, 2026-10-16: all of them in the same clip
-- at the same moment): each has its own speed of the idle and its own gait
-- (media/AnimSets/player-avatar/knoxmenu_zombie*, knoxmenu_zwalk*), and now
-- and then turns or shambles a few steps along the fence - within the gap
-- between the pickup and the tent, where they are seen from the fire.
local ZOMBIE_IDLES = {"knoxmenu_zombie", "knoxmenu_zombie2", "knoxmenu_zombie3"}
local ZOMBIE_WALKS = {"knoxmenu_zwalk", "knoxmenu_zwalk2", "knoxmenu_zwalk3"}
-- each gait's clip and how much it is sped up (m_SpeedScale of knoxmenu_zwalk*);
-- the speed it goes at comes from the clip itself (M:zombieSpeed)
local ZOMBIE_WALK_SCALE = {0.55, 0.50, 0.60}
local ZOMBIE_WALK_K = {1, 0.5 / 0.55, 0.6 / 0.55}
local ZOMBIE_AREA = {x0 = -0.3, x1 = 3.0, z0 = -15.9, z1 = -15.0}
local GRAVE_LIGHT = {x = 1.35, z = -10.7}
local CROSSES = {{0.5, -12.4}, {1.2, -12.55}, {1.9, -12.35}, {0.85, -11.45}, {1.55, -11.6}, {2.2, -11.4}}

-- a vehicle's origin is its body: lifted so that the wheels stand on the ground
local CAR_Y = 0.41

local NIGHT = {0.075, 0.095, 0.15}
local FIRE = {2.2, 1.15, 0.38}

-- drawn in this order (far to near); characters go in at "chars"
local PROPS = {
    {id = "km_ground_far", model = "KnoxMenu.GroundFar", tint = {0.15, 0.19, 0.30}, reveal = 9},
    {id = "km_ground_near", model = "KnoxMenu.GroundNear", y = 0.002, tint = {0.667, 0.667, 0.667}, pulse = 0.10, dim = 0.36},
    -- soft shadows under what lies around the fire, shaped like the thing
    -- itself: {x, z, size along it, size across, its yaw}
    {shadows = {{0.0, -2.78, 2.3, 0.8, 5}, {-2.48, -0.72, 1.9, 0.75, 68}, {2.48, -0.67, 1.9, 0.75, -64},
        {-0.94, -0.88, 0.75, 0.7, 0}, {0.99, 0.21, 0.6, 0.55, 0}, {-3.7, -3.25, 2.0, 1.5, 0},
        {0.57, 1.34, 0.85, 0.6, 25}, {-0.75, -5.72, 0.9, 0.85, 0}}},
    -- (far things are lit by the night and the moon only; `shade` sets how dark they are as a whole)
    {id = "km_tower", model = "KnoxMenu.Tower", x = -3.7, z = -18.0, yaw = 24, s = 0.63, shade = 1.3},
    {trees = true},
    {zombies = true},
    {id = "km_fence", model = "KnoxMenu.Fence", z = -14.0, s = 0.78, shade = 1.4},
    {memorials = true},
    -- the camp between the fire and the fence. By the fence: washing, water
    {id = "km_clothesline", model = "KnoxMenu.Clothesline", x = -1.7, z = -11.0, yaw = 6},
    {id = "km_barrel2", model = "KnoxMenu.Barrel", x = 1.7, z = -10.3, sx = 0.55, sy = 0.82, sz = 0.55},
    -- left: the car, firewood and the block it is split on
    {car = true, script = "Base.PickUpVan", x = -2.9, y = CAR_Y, z = -9.6, yaw = 100},
    {id = "km_woodpile", model = "KnoxMenu.WoodPile", x = -1.9, z = -6.8, yaw = 70},
    {id = "km_stump", model = "KnoxMenu.Stump", x = -0.75, z = -5.7, sx = 0.5, sy = 0.42, sz = 0.5},
    {id = "km_axe", model = "KnoxMenu.Axe", x = -0.75, y = 0.42, z = -5.7, yaw = 35},
    -- right: the tent, beds and packs under a lantern on a post (the camp's second light)
    {id = "km_lamp_pool", model = "KnoxMenu.LightPool", x = 2.6, y = 0.004, z = -6.2, s = 7.0, tint = {1.0, 1.0, 1.0}, pulse = 0.04},
    {id = "km_tent", model = "KnoxMenu.Tent", x = 3.4, z = -8.6, yaw = -24},
    {id = "km_lamp_post", model = "KnoxMenu.LampPost", x = 2.18, z = -6.2},
    {id = "km_lamp", model = "KnoxMenu.Lantern", x = 2.6, y = 1.44, z = -6.2, yaw = 30, tint = {1.0, 1.0, 1.0}, pulse = 0.05},
    {id = "km_mat1", model = "KnoxMenu.Mat", x = 1.9, z = -4.9, yaw = 18, sx = 0.62, sy = 0.04, sz = 1.6},
    {id = "km_mat2", model = "KnoxMenu.Mat", x = 0.7, z = -7.4, yaw = -32, sx = 0.62, sy = 0.04, sz = 1.6},
    {id = "km_bedroll1", model = "KnoxMenu.Bedroll", x = 2.95, z = -4.5, yaw = 40, sx = 0.62, sy = 0.2, sz = 0.2},
    {id = "km_bedroll2", model = "KnoxMenu.Bedroll", x = 0.45, z = -8.05, yaw = -30, sx = 0.62, sy = 0.2, sz = 0.2},
    {id = "km_pack_a", model = "KnoxInspect.ALICE_Pack_Ground__Bag_ALICEpack_0", world = true, x = 1.75, z = -6.4, yaw = 30},
    {id = "km_pack_b", model = "KnoxInspect.BigHikingBag_Ground__Bag_BigHikingBag_0", world = true, x = 3.2, z = -5.5, yaw = -50},
    {id = "km_pack_c", model = "KnoxInspect.DuffelBag_Ground__Bag_BaseballBag_0", world = true, x = 1.2, z = -5.4, yaw = 75},
    -- far right, past the tent (seen on wide screens): a smaller tent and the
    -- camp's stores by the fence. No light of their own: the night, the moon
    -- and what reaches them from the lamp on the post.
    {id = "km_store_barrel", model = "KnoxMenu.Barrel", x = 4.9, z = -11.3, sx = 0.55, sy = 0.82, sz = 0.55, shade = 1.3},
    {id = "km_store_crate1", model = "KnoxMenu.Crate", x = 5.5, z = -10.7, yaw = -14, s = 0.62, shade = 1.3},
    {id = "km_store_crate2", model = "KnoxMenu.Crate", x = 5.52, y = 0.62, z = -10.7, yaw = 28, s = 0.42, shade = 1.3},
    {id = "km_store_crate3", model = "KnoxMenu.Crate", x = 6.2, z = -10.4, yaw = 22, s = 0.5, shade = 1.3},
    {id = "km_tent2", model = "KnoxMenu.Tent", x = 6.7, z = -7.6, yaw = -52, s = 0.85, shade = 1.2},
    {id = "km_store_mat", model = "KnoxMenu.Mat", x = 5.7, z = -6.2, yaw = -40, sx = 0.62, sy = 0.04, sz = 1.6, shade = 1.2},
    {id = "km_store_bedroll", model = "KnoxMenu.Bedroll", x = 6.3, z = -5.6, yaw = -30, sx = 0.62, sy = 0.2, sz = 0.2, shade = 1.2},
    {id = "km_store_pack", model = "KnoxInspect.BigHikingBag_Ground__Bag_BigHikingBag_0", world = true, x = 5.2, z = -7.0, yaw = 110},
    {id = "km_barrel", model = "KnoxMenu.Barrel", x = -4.7, z = -2.7, sx = 0.55, sy = 0.82, sz = 0.55},
    {id = "km_crate1", model = "KnoxMenu.Crate", x = -3.9, z = -3.3, yaw = 12, s = 0.62},
    {id = "km_crate2", model = "KnoxMenu.Crate", x = -3.2, z = -3.0, yaw = -20, s = 0.5},
    {id = "km_crate3", model = "KnoxMenu.Crate", x = -3.86, y = 0.62, z = -3.3, yaw = 40, s = 0.45},
    {id = "km_log1", model = "KnoxMenu.Log", x = 0.0, z = -2.65, yaw = 5, sx = 1.9, sy = 0.34, sz = 0.34},
    {id = "km_log2", model = "KnoxMenu.Log", x = -2.35, z = -0.7, yaw = 68, sx = 1.5, sy = 0.30, sz = 0.30},
    {id = "km_log3", model = "KnoxMenu.Log", x = 2.35, z = -0.65, yaw = -64, sx = 1.5, sy = 0.30, sz = 0.30},
    {chars = true},
    -- the fire: `own` = lit from the first frame, while the camp around it is still in the dark
    {id = "km_embers", model = "KnoxMenu.FireEmbers", y = 0.004, tint = {1.0, 1.0, 1.0}, pulse = 0.30, own = true},
    -- The wood of the fire, laid out for the one place it is looked at from: the
    -- camera stands in front (+Z), a little above. From there the ring's front
    -- stones hide whatever lies on the pit's floor, and a log pointing at the
    -- camera shows nothing but its round cut end. So: three charred logs lying
    -- ACROSS the view, crossed over one another and raised onto each other so
    -- that they show over the stones, their ends out to the left and right of
    -- the flames, which rise from them. None points at the camera.
    -- (Before, all seen in game 2026-10-13: sticks leaning over the middle stuck
    -- out of the flames at any size; logs laid flat like spokes were hidden but
    -- for one cut end staring at the camera.)
    -- The log model lies along X: sx = length, sy / sz = thickness; rz tips one end up.
    -- (a fifth smaller, 0.05 lower and darker - tint 0.62 - than at first: asked 2026-10-13)
    {id = "km_firelog1", model = "KnoxMenu.LogCharred", x = -0.03, y = 0.04, z = 0.05, yaw = 13, rz = 5,
        sx = 0.64, sy = 0.092, sz = 0.092, tint = {0.62, 0.62, 0.62}, pulse = 0.25, own = true},
    {id = "km_firelog2", model = "KnoxMenu.LogCharred", x = 0.04, y = 0.08, z = -0.03, yaw = -19, rz = -7,
        sx = 0.58, sy = 0.08, sz = 0.08, tint = {0.62, 0.62, 0.62}, pulse = 0.25, own = true},
    {id = "km_firelog3", model = "KnoxMenu.LogCharred", x = -0.06, y = 0.03, z = -0.15, yaw = 31, rz = 3,
        sx = 0.50, sy = 0.076, sz = 0.076, tint = {0.62, 0.62, 0.62}, pulse = 0.25, own = true},
    {id = "km_fire_stones", model = "KnoxMenu.FireStones", y = 0.008, lit = 0.45, own = true},
    {flames = true},
    -- the game's own things (world models: mirrored and scaled by the scene)
    {id = "km_kettle", item = "KettleGround", x = 0.95, z = 0.2, yaw = 30, lit = 0.35},
    -- what a camp leaves around its fire
    {id = "km_can1", item = "TinCanEmpty", x = -0.95, z = 0.95, yaw = 40, lit = 0.4, near = 0.3},
    {id = "km_can2", item = "TinCanEmpty", x = -1.2, z = 0.72, yaw = 200, lit = 0.4, near = 0.3},
    {id = "km_can3", item = "TinCanEmpty", x = 1.35, z = -1.05, yaw = 120, lit = 0.4, near = 0.3},
    -- (the pot by the fire gave its place to the radio - the author, 2026-10-15)
    {id = "km_mug1", item = "MugWhite", x = 1.2, z = 0.8, yaw = 60, lit = 0.35, near = 0.3},
    {id = "km_mug2", item = "MugWhite", x = 0.6, z = -1.3, yaw = 200, lit = 0.35, near = 0.3},
    {id = "km_bottle1", item = "WaterBottleFull", x = -2.05, z = 0.5, yaw = 80, lit = 0.4, near = 0.3},
    {id = "km_bottle2", item = "WaterBottleFull", x = 2.15, z = 0.6, yaw = 300, lit = 0.4, near = 0.3},
    {id = "km_firewood", item = "FirewoodBundle", x = 0.55, z = 1.3, yaw = 25, lit = 0.4, near = 0.4},
    -- a radio on the ground: the menu's music can come from it (KnoxMenuMusic, its dial lit: drawFx)
    -- (by the fire where the pot stood, its front to the camera - the author, 2026-10-15;
    -- at first on the ground at the front, turned aside: yaw 160 left of it looked
    -- turned a little, the camera is almost straight ahead of this place)
    {id = "km_radio", item = "RadioRed_Ground", x = -0.9, z = -0.85, yaw = 180, lit = 0.42, near = 0.35},
    -- by the radio, as if it was just mended: a screwdriver in front of it, a
    -- spare battery at its side (the author asked for the screwdriver and one
    -- more thing that belongs there, 2026-10-16)
    {id = "km_screwdriver", item = "Screwdriver_Red", weapon = true, x = -0.78, z = -0.55, yaw = 75, lit = 0.4, near = 0.3},
    {id = "km_battery", model = "KnoxMenu.Battery", world = true, x = -1.26, z = -0.98, yaw = 35, lit = 0.4, near = 0.3},
}
-- where the radio is (its dial glows, its card comes up), in the scene's own units
local RADIO_DIAL = {x = -0.9, y = 0.1, z = -0.85}
-- its dial window (the lamp that shows it is on), from its middle: right and up
-- on the screen (the light sat on the speaker's grille - the author, 2026-10-15)
local RADIO_LAMP = {right = 0.082, up = 0.021}   -- (0.15 / 0.045 put it beside the radio)
-- the lantern on the post: the camp's second light
local LAMP = {x = 2.6, y = 1.58, z = -6.2, light = {1.5, 1.05, 0.55}}
-- where a hero's weapon lies, by seat
local WEAPON_AT = {{0.78, -1.7, 70}, {-1.95, 0.5, 20}, {1.95, 0.5, 160}}
-- where a hero's backpack lies, taken off at the fire (KnoxMenuBag), by seat:
-- on the hero's other side from the weapon, a little behind
-- (the middle one's first place, left of the hero, ran into the radio - the author, 2026-10-16)
-- (then 1.05: too far from him; the side ones lay under the menu and the news
-- cards - hard to click: the left one now behind the radio between the logs,
-- the right one at that hero's right hand, where a tin can stood: BAG_MOVES)
-- (-1.25, -1.65: too close to the radio; behind it, between the logs: still
-- awkward to click - now by the two tin cans in front of that hero)
local BAG_AT = {{0.72, -2.3, 30}, {-0.55, 0.9, 15}, {1.35, -1.05, -40}}
-- what gives its place to a hero's bag, by seat
local BAG_MOVES = {[3] = "km_can3"}

local function pool(d)
    return 1 / (1 + (d / 1.25) * (d / 1.25))
end

local function distances(o)
    local x, z = o.x or 0, o.z or 0
    o.dist = math.sqrt(x * x + z * z)
    o.lampDist = math.sqrt((x - LAMP.x) * (x - LAMP.x) + (z - LAMP.z) * (z - LAMP.z))
end

-- Saves -----------------------------------------------------------------------

--- The player's latest saves, newest first: {rel, mode, name, snap, dead, hero}.
local function recentSaves(count)
    local out = {}
    local ok, dirs = pcall(getFullSaveDirectoryTable)
    if not ok or not dirs then return out end
    for _, rel in ipairs(dirs) do
        local okInfo, info = pcall(getSaveInfo, rel)
        if okInfo and info and info.saveName and info.gameMode
                and info.gameMode ~= "LastStand" and info.gameMode ~= "Tutorial" and info.gameMode ~= "Multiplayer" then
            local snap = knoxMenuInfo(rel)
            local dead = not info.playerAlive
            local hero = nil
            if snap then
                dead = snap.dead == true
                hero = snap.name
            elseif info.players and info.players[1] then
                hero = info.players[1].name
            end
            table.insert(out, {rel = rel, mode = info.gameMode, name = info.saveName, snap = snap, dead = dead, hero = hero,
                played = info.lastPlayed})
            if #out >= count then break end
        end
    end
    return out
end

--- A portrait of a save's hero for the hover card (nil without a snapshot).
function M:makePortrait(save, zombie)
    if not save.snap then return nil end
    local portrait = ISUI3DModel:new(0, 0, 64, 64)
    portrait:initialise()
    portrait:instantiate()
    portrait:setVisible(false)
    portrait.animateWhilePaused = true
    self:addChild(portrait)
    local pj = portrait.javaObject
    if not knoxMenuDressUI(pj, save.rel, zombie == true) then
        self:removeChild(portrait)
        return nil
    end
    pj:setIsometric(false)
    pj:setDirection(IsoDirections.S)
    pj:setState("idle")
    pj:setZoom(17.3)
    pj:setYOffset(-0.89)
    return portrait
end

--- The game's own car, parked in the camp (the scene can show vehicles).
function M:addCar(p)
    local j = self.scene.javaObject
    local ok = pcall(function()
        j:fromLua1("createVehicle", p.id or "km_car")
        j:fromLua2("setVehicleScript", p.id or "km_car", p.script)
    end)
    if not ok then
        print("[Knox] menu scene: no vehicle " .. tostring(p.script))
        return
    end
    local o = {id = p.id or "km_car", x = p.x, y = p.y, z = p.z, yaw = p.yaw, vehicle = true}
    self:place(o)
    distances(o)
    table.insert(self.objects, o)
    knoxMenuVehicleLight(0.2)
end

--- Crosses by the fence: one for every hero of the latest saves who died.
function M:addMemorials(saves)
    self.memorials = {}
    local n = 0
    for _, save in ipairs(saves) do
        if save.dead and n < 6 then
            n = n + 1
            local x, z = CROSSES[n][1], CROSSES[n][2]
            -- pale boards, a little lighter than the fence behind them
            local o = {id = "km_cross" .. n, model = "KnoxMenu.Cross", x = x, z = z, yaw = (n * 37) % 25 - 12,
                s = 0.92 + ((n * 13) % 10) / 80, shade = 1.0}
            if self:addModel(o) then
                table.insert(self.memorials, {x = x, z = z, height = 1.05, save = save, memorial = true})
            end
        end
    end
    -- A small lantern left burning by the graves: its warm light is what
    -- tells the crosses from the fence behind them (white boards stood out
    -- of the picture, plain ones were lost in it).
    if n > 0 then
        local l = self.lights
        l[24], l[25], l[26], l[27], l[28], l[29], l[30] = GRAVE_LIGHT.x, 0.25, GRAVE_LIGHT.z, 1.5, 0.85, 0.32, 1.0
        knoxMenuSceneLights(l)
        self:addModel({id = "km_grave_pool", model = "KnoxMenu.LightPool", x = GRAVE_LIGHT.x, y = 0.0045, z = GRAVE_LIGHT.z - 0.2,
            s = 3.2, tint = {0.8, 0.7, 0.6}, pulse = 0.04})
        self:addModel({id = "km_grave_lamp", model = "KnoxMenu.Lantern", x = GRAVE_LIGHT.x, z = GRAVE_LIGHT.z, yaw = 50, s = 0.6,
            tint = {1.0, 1.0, 1.0}, pulse = 0.05})
        self.graveLight = true
    end
end


-- Scene objects ---------------------------------------------------------------

function M:place(o)
    local j = self.scene.javaObject
    local x = o.x or 0
    if o.world then x = -x end   -- world models are mirrored in X by the scene
    j:fromLua1("getObjectTranslation", o.id):set(x, o.y or 0, o.z or 0)
    j:fromLua1("getObjectRotation", o.id):set(o.rx or 0, o.yaw or 0, o.rz or 0)
    local s = o.s or 1
    j:fromLua1("getObjectScale", o.id):set((o.sx or 1) * s, (o.sy or 1) * s, (o.sz or 1) * s)
    -- a model's light is kept by its place (knoxMenuTintAt): it moves with it
    if o.tinted and (o.px ~= x or o.py ~= (o.y or 0) or o.pz ~= (o.z or 0)) then
        if o.world then knoxMenuTintNear(-o.px, o.py, o.pz, 0, -1, 0, 0) else knoxMenuTintAt(o.px, o.py, o.pz, -1, 0, 0) end
        o.px, o.py, o.pz = x, o.y or 0, o.z or 0
        distances(o)
        self:tint(o, self.flick or 1)
    else
        o.px, o.py, o.pz = x, o.y or 0, o.z or 0
    end
end

function M:addModel(o)
    local j = self.scene.javaObject
    local script = o.model
    if o.item then
        local ms = getScriptManager():getModelScript(o.item)
        if not ms then return false end
        script = ms:getFullType()
        o.world = true
    end
    -- (the scene reports a model it can't make - "model script Base.null not
    -- found", a mod's weapon - to the log and goes on without the object, so
    -- it is looked for after the call: Steam report 2026-10-14)
    local ok = script ~= nil and not string.find(tostring(script), "%.null$") and pcall(function()
        j:fromLua2("createModel", o.id, script)
        if not j:fromLua1("getObjectTranslation", o.id) then error("no object") end
        if o.world then j:fromLua2("setModelUseWorldAttachment", o.id, true) end
        if o.weapon then j:fromLua2("setModelWeaponRotationHack", o.id, true) end
    end)
    if not ok then
        print("[Knox] menu scene: no model " .. tostring(script))
        return false
    end
    self:place(o)
    distances(o)
    table.insert(self.objects, o)
    self:tint(o, 1)
    return true
end

function M:tint(o, flick)
    o.tinted = true
    if not o.tint then
        -- shaded: the Java part lights it face by face from the fire, the lamp
        -- and the moon (knoxMenuSceneLights); `shade` darkens it as a whole,
        -- `lit` is how much of the fire it takes
        local rk = self:revealK(o)
        if o.world then
            knoxMenuShadeNear(-o.px, o.py, o.pz, o.near or 0.5, (o.shade or 1) * rk, o.lit or 1)
        else
            knoxMenuShadeAt(o.px, o.py, o.pz, (o.shade or 1) * rk, o.lit or 1)
        end
        return
    end
    -- flat: things that glow themselves, the ground (its light is baked), decals
    local k = (1 + (o.pulse or 0) * (flick - 1) * 4) * self:revealK(o)
    local r, g, b = o.tint[1] * k, o.tint[2] * k, o.tint[3] * k
    if o.world then
        -- the game's own models: not exactly where they were put (see knoxMenuTintNear)
        -- (the scene mirrors their X back: on screen they stand at -px)
        knoxMenuTintNear(-o.px, o.py, o.pz, o.near or 0.5, r, g, b)
    else
        knoxMenuTintAt(o.px, o.py, o.pz, r, g, b)
    end
end

function M:yawOf(face)
    return CFG.yawOffset + CFG.yawSign * face
end

function M:addCharacter(c)
    local j = self.scene.javaObject
    local ok = pcall(function()
        j:fromLua1("createCharacter", c.id)
        j:fromLua2("setCharacterClearDepthBuffer", c.id, CFG.clearDepth)
    end)
    if not ok then return false end
    c.anim = c.anim or (c.zombie and "knoxmenu_zombie" or "knoxmenu_warm")   -- at the fire from the first frame
    knoxMenuAnim(j, c.id, c.anim)                               -- before dressing: applied with the model
    -- (were the hero's clothes loaded before the hero was dressed? If not, it is
    -- dressed anew once they are: see M:watchPose)
    if knoxMenuClothesReady and knoxMenuClothesReady(c.save.rel) then c.clothesOk = true else c.clothesLate = true end
    c.dressed = knoxMenuDress(j, c.id, c.save.rel, c.zombie == true)
    c.yaw = self:yawOf(c.face)
    self:place(c)
    c.dist = math.sqrt(c.x * c.x + c.z * c.z)
    table.insert(self.objects, c)
    table.insert(self.chars, c)
    return true
end

--- What a hero carries (KnoxMenuBag): read for the card; the backpack, if one
--- is on the back, is taken off (not drawn on the hero - call before dressing)
--- and put down beside the seat as the game's own model of it lying on the ground.
function M:addBag(c, slot)
    if not (KnoxMenuBag and knoxMenuTakeOff and c.save) then return end
    local rel = c.save.rel
    knoxMenuTakeOff(rel, "")
    local ok, bag = pcall(KnoxMenuBag.read, rel)
    if not ok or not bag then return end
    c.bag = bag
    local at, back = BAG_AT[slot], bag.back
    if not (at and back) then return end
    local sm = getScriptManager()
    local script = sm:getItem(back.type)
    if not script then return end
    local wm = script:getWorldStaticModel()
    if not wm or wm == "" then wm = script:getStaticModel() end
    if not wm or wm == "" then return end
    local ms = sm:getModelScript(wm) or sm:getModelScript("Base." .. wm)
    if not ms then return end
    if self:addModel({id = "km_bag" .. slot, model = ms:getFullType(), world = true,
            x = at[1], z = at[2], yaw = at[3], lit = 0.6, near = 0.45}) then
        knoxMenuTakeOff(rel, back.type)
        c.bagAt = {x = at[1], z = at[2]}
        -- its own colours (a model of clothes on the ground has no texture of
        -- its own) - asked again until they are there (M:skinBags)
        c.bagType = back.type
        -- (a bag with no clothing look of its own has its model's texture: nothing to wait for)
        local ci = script:getClothingItem()
        c.bagSkinned = (not ci or ci == "") or (knoxMenuBagSkin ~= nil and knoxMenuBagSkin(self.scene.javaObject, "km_bag" .. slot, rel, back.type) == true)
    end
end

-- Keepsakes ---------------------------------------------------------------------
-- Things taken out of a hero's bag (its card: KnoxMenuBag) and put down in the
-- camp - their likeness only, the save is never touched (KnoxMenuKeep). Pressed
-- on, one is picked up and moved; R turns the one being carried; a right click
-- takes one away. The mouse on one names it and whose it was.
local KEEP_AREA = {x0 = -4.6, x1 = 4.6, z0 = -8.5, z1 = 3.2}
local KEEP_HIT = 0.32      -- units round a keepsake that the mouse finds it in
local keepSeq = 0

--- Put a keepsake's model in the scene; false when it can't be made.
function M:addKeep(k)
    local model, weapon = KnoxMenuKeep.modelOf(k.type)
    if not model then return false end
    keepSeq = keepSeq + 1
    -- (a weapon's model is turned by the scene to lie down and its point moves off
    -- where it was put: its light is looked for further round, as for the hero's
    -- weapon at the fire - with 0.32 a bat was lit oddly, the author 2026-10-16)
    local o = {id = "km_keep" .. keepSeq, model = model, world = true, weapon = weapon, x = k.x, z = k.z, yaw = k.yaw,
               lit = weapon and 0.6 or 0.45, near = weapon and 0.45 or 0.32, keep = k}
    if not self:addModel(o) then return false end
    k.obj = o
    self:skinKeep(k)
    return true
end

--- A thing of cloth lying on the ground gets its texture (as a hero's bag: knoxMenuBagSkin).
function M:skinKeep(k)
    if k.skinned or not k.obj then return end
    local script = getScriptManager():getItem(k.type)
    local ci = script and script:getClothingItem()
    if not ci or ci == "" or not knoxMenuBagSkin then
        k.skinned = true
        return
    end
    k.skinned = knoxMenuBagSkin(self.scene.javaObject, k.obj.id, k.save or "", k.type) == true
end

function M:removeKeepModel(k)
    if not k.obj then return end
    pcall(function() self.scene.javaObject:fromLua1("removeModel", k.obj.id) end)
    for i = #self.objects, 1, -1 do
        if self.objects[i] == k.obj then table.remove(self.objects, i) end
    end
    k.obj = nil
end

function M:addKeeps()
    if not KnoxMenuKeep then return end
    for _, k in ipairs(KnoxMenuKeep.load()) do
        k.obj, k.skinned = nil, nil
        self:addKeep(k)
    end
end

--- The ground under the mouse inside the camp, or nil.
function M:groundAtMouse()
    if not knoxMenuGround then return nil end
    local p = knoxMenuGround(self.scene.javaObject, getMouseX(), getMouseY(), 0)
    if not p then return nil end
    local A = KEEP_AREA
    if p.x < A.x0 or p.x > A.x1 or p.z < A.z0 or p.z > A.z1 then return nil end
    return p
end

--- The keepsake under the mouse, or nil.
function M:keepAtMouse()
    if not KnoxMenuKeep or not KnoxMenuKeep.list then return nil end
    local mx, my = getMouseX(), getMouseY()
    local best, bestD = nil, nil
    for _, k in ipairs(KnoxMenuKeep.list) do
        if k.obj then
            local cx, cy = self:toScreen(k.x, 0.05, k.z)
            local _, ty = self:toScreen(k.x, 0.05 + KEEP_HIT, k.z)
            local r = math.max(8, math.abs(cy - ty))
            local d = (mx - cx) * (mx - cx) + (my - cy) * (my - cy)
            if d <= r * r and (not bestD or d < bestD) then best, bestD = k, d end
        end
    end
    return best
end

--- Every frame: a thing being carried follows the ground under the mouse and is
--- put down where the button is let go; the mouse on one names it; a press
--- picks one up, a right click takes it away. True when the mouse was theirs.
function M:updateKeeps(down, clicked, rclicked)
    local KM = KnoxMenuKeep
    if not KM then return false end
    local j = self.scene.javaObject
    local d = KM.drag
    self.keepHover = nil
    if d then
        if self.mode ~= "idle" then
            self:dropKeep(nil)
            return true
        end
        -- R turns it, a quarter at a time
        local r = isKeyDown(Keyboard.KEY_R)
        if r and not self.keepRWas then d.yaw = (d.yaw + 45) % 360 end
        self.keepRWas = r
        -- (over the bag's card the thing is still in hand: no likeness on the ground)
        local onCard = KnoxBagCard and KnoxBagCard.isMouseOn()
        -- over a hero's bag: let go, it goes back into it (the author, 2026-10-16) -
        -- a keepsake taken away from the camp, a new one not put down
        self.keepToBag = nil
        if not onCard then
            local mx, my = getMouseX(), getMouseY()
            for _, c in ipairs(self.chars) do
                if c.bagAt and c.shownAt and T.inRect(mx, my, self:bagRect(c)) then self.keepToBag = c end
            end
        end
        local p = not onCard and not self.keepToBag and self:groundAtMouse() or nil
        d.onGround = p ~= nil
        if p then
            if not d.ghost then
                local model, weapon = KM.modelOf(d.type)
                d.ghost = {id = "km_keep_ghost", model = model, world = true, weapon = weapon, x = p.x, z = p.z, yaw = d.yaw,
                           lit = 0.6, near = weapon and 0.45 or 0.32}
                if not (model and self:addModel(d.ghost)) then d.ghost = nil end
                if d.ghost and knoxMenuBagSkin then
                    knoxMenuBagSkin(j, d.ghost.id, d.save or "", d.type)
                end
            end
            if d.ghost then
                d.ghost.x, d.ghost.z, d.ghost.yaw = p.x, p.z, d.yaw
                d.ghost.s = 1
                self:place(d.ghost)
            end
        elseif d.ghost then
            d.ghost.s = 0.001   -- (off the ground: out of sight)
            self:place(d.ghost)
        end
        self.keepAt = p
        self.keepOnCard = onCard
        if not down then
            local bag = self.keepToBag
            if bag then
                -- back into the bag: off the ground for good
                d.from, p = nil, nil
                for i = #KM.list, 1, -1 do
                    if KM.list[i] == d.from0 then table.remove(KM.list, i) end
                end
                KM.save()
                if KnoxMenuBag and KnoxMenuBag.sound then KnoxMenuBag.sound(bag.bag, false) end
            end
            self.keepToBag = nil
            self:dropKeep(p)
        end
        return true
    end
    if self.mode ~= "idle" or self.ctxMenu or (KnoxBagCard and KnoxBagCard.isUp()) or not self:menuIdle() then return false end
    local k = self:keepAtMouse()
    if not k then return false end
    self.keepHover = k
    if clicked then
        -- picked up: carried as a new one, put back where it was if let go off the ground
        KM.drag = {type = k.type, name = k.name, hero = k.hero, save = k.save, yaw = k.yaw, from = k, from0 = k}
        self:removeKeepModel(k)
        self.keepHover = nil
        return true
    elseif rclicked then
        self:removeKeepModel(k)
        for i = #KM.list, 1, -1 do
            if KM.list[i] == k then table.remove(KM.list, i) end
        end
        KM.save()
        getSoundManager():playUISound("UIActivateMainMenuItem")
        return true
    end
    return false
end

--- A plate by the mouse: the keepsake's name and whose it was; while one is
--- carried, how to turn it (or that it can't lie there).
function M:drawKeepHint(el)
    local KM = KnoxMenuKeep
    if not KM then return end
    local d, k = KM.drag, self.keepHover
    if not d and not k then return end
    if d and self.keepOnCard then return end   -- (still over the card: the tile in hand says enough)
    local it = d or k
    local lines = {it.name or it.type}
    if it.hero and it.hero ~= "" then table.insert(lines, getText("IGUI_Knox_Keep_Whose", it.hero)) end
    if d then
        table.insert(lines, getText(self.keepToBag and "IGUI_Knox_Keep_ToBag"
            or (self.keepAt and "IGUI_Knox_Keep_Turn" or "IGUI_Knox_Keep_NoRoom")))
    else
        table.insert(lines, getText("IGUI_Knox_Keep_Hint"))
    end
    T.ensure()
    local font = T.fontText
    local fh = T.fontH(font)
    local pad = math.floor(T.pad / 2)
    local w = 0
    for _, s in ipairs(lines) do w = math.max(w, T.measure(font, s)) end
    local bw, bh = w + pad * 2, #lines * fh + pad * 2
    local x, y = getMouseX() + 18, getMouseY() + 22
    if x + bw > el.width then x = getMouseX() - bw - 8 end
    if y + bh > el.height then y = getMouseY() - bh - 8 end
    T.rect(el, x, y, bw, bh, T.color.header, 0.95)
    T.border(el, x, y, bw, bh, T.color.accent, 1)
    for i, s in ipairs(lines) do
        local c = (i == 1) and T.color.bright or ((i == #lines) and T.color.dim or T.color.text)
        if d and i == #lines and not self.keepAt then c = self.keepToBag and T.color.accent or T.color.bad end
        T.text(el, s, x + pad, y + pad + (i - 1) * fh, c, font, 1)
    end
end

--- The thing carried is let go: put down at p (a ground point), or - off the
--- ground - back where it came from (a keepsake moved) or nowhere (a new one).
function M:dropKeep(p)
    local KM = KnoxMenuKeep
    local d = KM.drag
    KM.drag = nil
    if not d then return end
    if d.ghost then
        pcall(function() self.scene.javaObject:fromLua1("removeModel", d.ghost.id) end)
        for i = #self.objects, 1, -1 do
            if self.objects[i] == d.ghost then table.remove(self.objects, i) end
        end
    end
    local list = KM.load()
    if p then
        local k = d.from or {type = d.type, name = d.name, hero = d.hero, save = d.save}
        k.x, k.z, k.yaw = p.x, p.z, d.yaw
        k.skinned = nil
        if not d.from then table.insert(list, k) end
        self:addKeep(k)
        KM.save()
        getSoundManager():playUISound("KnoxKeepPut")   -- (put down on the grass: knox_menu_sounds.txt)
    elseif d.from then
        local k = d.from
        k.skinned = nil
        self:addKeep(k)
    end
end

--- The bags not coloured yet (after a start the game is still reading its
--- clothes - they lay see-through until a save was played): asked again twice
--- a second, for a minute at most.
function M:skinBags()
    if not knoxMenuBagSkin or (self.skinAt or 0) > self.clock or self.clock > 60 then return end
    self.skinAt = self.clock + 0.5
    for _, c in ipairs(self.chars) do
        if c.bagAt and c.bagType and not c.bagSkinned then
            c.bagSkinned = knoxMenuBagSkin(self.scene.javaObject, "km_bag" .. c.slot, c.save.rel, c.bagType) == true
            if c.bagSkinned then print("[Knox] menu scene: km_bag" .. c.slot .. " coloured after " .. string.format("%.1f", self.clock) .. " s") end
        end
    end
    for _, k in ipairs(KnoxMenuKeep and KnoxMenuKeep.list or {}) do
        if not k.skinned then self:skinKeep(k) end
    end
end

--- A hero's bag on the screen: {x, y, w, h}, about the bag itself (0.64 x 0.52
--- units reached too far round it - the author, 2026-10-16).
function M:bagRect(c)
    local p = c.bagAt
    local bx, by = self:toScreen(p.x, 0, p.z)
    local _, ty = self:toScreen(p.x, 0.3, p.z)
    local ppu = math.abs(by - ty) / 0.3
    return {bx - 0.22 * ppu, by - 0.3 * ppu, 0.44 * ppu, 0.34 * ppu}
end

function M:setAnim(c, state)
    if c.anim == state then return end
    c.anim = state
    c.animSeen = knoxMenuAnim(self.scene.javaObject, c.id, state)
end

--- Light of a character: the night, the fire's fill, and the fire as a lamp in front of it.
-- The camp comes out of the dark; each hero comes in once in place -------------
-- The menu opens on the fire burning in the dark (its flames, logs, stones and
-- a glow on the ground under it); a moment later its light spreads over the
-- camp. The dark is made of light, not of a black sheet over the picture:
-- every object's own light is scaled (M:revealK).
-- The people are another matter. After a fresh start the game loads models,
-- bakes the clothes' textures and reads its ~2000 animations in the
-- background: for a while a hero stands in the anim set's idle, half dressed,
-- before it sits down. So each of them is kept too small to see until it is
-- really playing its pose (the Java part looks at the animation tracks:
-- knoxMenuPosed) with its own clothes on, and then fades in where it sits.
-- (Until 0.9.4 the whole camp waited in the dark for the last of them, and for
-- the game's whole wardrobe: up to half a minute after leaving a game, seen
-- 2026-10-14. Nobody waits for anybody now.)

-- the clip each resting state plays (media/AnimSets/player-avatar/knoxmenu_*)
local CLIP = {
    knoxmenu_warm = "Bob_SitGround_WarmHands", knoxmenu_sit = "Bob_SitGround_Idle",
    knoxmenu_zombie = "Zombie_Idle", knoxmenu_walk = "Bob_Walk", knoxmenu_stand = "Bob_Idle",
    knoxmenu_zombie2 = "Zombie_Idle", knoxmenu_zombie3 = "Zombie_Idle",
    knoxmenu_zwalk = "Zombie_Walk2", knoxmenu_zwalk2 = "Zombie_Walk3", knoxmenu_zwalk3 = "Zombie_Walk4",
}
-- every clip the scene plays: asked to be loaded before the game's others (knoxMenuHurryClips)
local MENU_CLIPS = "Bob_SitGround_WarmHands,Bob_SitGround_Idle,Bob_SitGround_RubHands,Bob_SitGround_In,"
    .. "Bob_SitGround_Out,Bob_Walk,Bob_Idle,Zombie_Idle,Zombie_Walk2,Zombie_Walk3,Zombie_Walk4"
local REVEAL_AT = 0.35      -- s the fire burns alone before its light spreads (the first frames are uneven)
local REVEAL_FADE = 1.8      -- s the fire's light takes to reach the far end of the camp
local REVEAL_REACH = 24      -- units: what lies further is lit together with this
local REVEAL_SOFT = 6        -- units over which the light's edge fades
local HERO_SETTLE = 0.25     -- s a hero has been in its pose before it comes in (the pose blends in)
local HERO_GIVE_UP_LOADED = 4   -- s with its clip loaded after which a hero comes in in whatever state it is in
local HERO_GIVE_UP = 60      -- s after which it comes in anyway
local CLOTHES_GIVE_UP = 10   -- s its clothes are waited for at most
local HERO_WHY_AT = {3, 8, 20}   -- s at which a hero still not in says why, in the log

--- How much of its light a thing has, 0..1. In the dark only the fire burns
--- (and the ground under it glows a little); then the light spreads from the
--- fire outwards, reaching things by their distance from it. `o`: a scene
--- object (or nil), `d`: the distance to use instead of its own.
function M:revealK(o, d)
    if o and o.own then return 1 end
    if self.revealDone then return 1 end
    -- In the dark the fire still lights what is near it, weaker with the
    -- distance: things by the fire keep their look, dimmed like the ground
    -- under them, and fade out further off. (Pure black they looked like
    -- cut-outs that had lost their textures - seen in game 2026-10-13.)
    -- Not the people: they are not there until the camp is shown.
    local dim = o and o.dim
    if not dim then
        dim = 0
        local dd = o and not o.height and (o.reveal or o.dist)
        if dd then
            local f = math.max(0, math.min(1, (dd - 4.5) / 4.5))
            dim = 0.36 * (1 - f * f * (3 - 2 * f))
        end
    end
    if not self.revealAt then return dim end
    local tt = (self.clock - self.revealAt) / REVEAL_FADE
    if tt >= 1 then return 1 end
    d = math.min(REVEAL_REACH, d or (o and (o.reveal or o.dist)) or 0)
    local front = (REVEAL_REACH + REVEAL_SOFT) * tt * tt * (3 - 2 * tt)
    local k = math.max(0, math.min(1, (front - d) / REVEAL_SOFT))
    k = k * k * (3 - 2 * k)
    return dim + (1 - dim) * k
end

-- The fire, in 3D ---------------------------------------------------------------
-- Faceted tongues of flame (one low-poly model, see MenuGen.flameArt) in three
-- layers as the camera sees them: deep orange at the back and tallest, orange
-- before it, yellow in front and lowest. Each lives on its own: it stretches
-- and narrows, sways and turns slowly, so that its facets catch the eye in turn.
-- {layer, x, z, height, width, phase, turn (degrees a second)}
local FLAME_Y = 0.06     -- the lowest a tongue starts (the logs lie under it); each has its own height over that (the 8th number)
local FLAME_MESH_W = 0.66    -- the model's width at its widest (it is 1 high)
-- (sizes: the first try was 2.4 times this and hid the hero sitting behind the
-- fire - seen in game 2026-10-13. At its tallest moment the middle tongue is
-- about 0.6 high: it must stay under the face of whoever sits on seat 1.)
local FLAME_TOP = 0.62       -- no tongue stretches higher: the face of whoever sits behind the fire stays clear
-- uneven on purpose: no two alike, the tallest off the middle (three even
-- peaks looked like a drawn icon, not a fire - seen in game 2026-10-13)
local FLAMES = {
    -- (the tongues start at different heights and are pointed at the foot: all
    -- from one level, flat-footed, the fire had a ruled bottom edge)
    -- (slimmer than at first: at 0.30 wide the big ones were fat cones - seen in game 2026-10-13)
    {"Out", -0.04, -0.06, 0.46, 0.215, 0.0, 34, 0.08},
    {"Out", -0.16, -0.04, 0.32, 0.18, 1.7, -41, 0.03},
    {"Out", 0.14, -0.05, 0.38, 0.185, 3.1, 38, 0.06},
    {"Out", 0.23, -0.02, 0.23, 0.14, 5.2, -29, 0.02},
    {"Mid", -0.08, 0.02, 0.34, 0.155, 0.9, -52, 0.08},
    {"Mid", 0.06, 0.03, 0.29, 0.15, 2.4, 47, 0.05},
    {"Mid", -0.20, 0.05, 0.20, 0.12, 4.0, 55, 0.02},
    {"Mid", 0.18, 0.06, 0.18, 0.11, 5.9, -44, 0.03},
    {"Core", 0.00, 0.08, 0.24, 0.115, 1.3, -63, 0.06},
    {"Core", -0.10, 0.10, 0.17, 0.09, 3.6, 70, 0.03},
    {"Core", 0.09, 0.11, 0.15, 0.08, 4.7, -58, 0.04},
    {"Core", -0.02, 0.14, 0.11, 0.07, 2.9, 61, 0.02},
}
-- small flames that tear off the fire, rise and go out
local LICKS = 4

local function frand()
    return ZombRand(1000) / 1000
end

function M:addFlames()
    self.flames, self.licks = {}, {}
    for i, f in ipairs(FLAMES) do
        -- (each at a height of its own: a model's light is kept by its place)
        local o = {id = "km_flame" .. i, model = "KnoxMenu.Flame" .. f[1], x = f[2], y = FLAME_Y + (f[8] or 0) + i * 0.0009, z = f[3],
            sx = f[5] / FLAME_MESH_W, sy = f[4], sz = f[5] / FLAME_MESH_W, tint = {1.0, 1.0, 1.0}, pulse = 0.18,
            own = true, flame = f}
        if self:addModel(o) then table.insert(self.flames, o) end
    end
    for i = 1, LICKS do
        local o = {id = "km_lick" .. i, model = "KnoxMenu.Flame" .. ((i % 2 == 0) and "Mid" or "Core"), x = 0,
            y = 0.3 + i * 0.0011, z = 0.02 + i * 0.013, sx = 0.001, sy = 0.001, sz = 0.001, tint = {1.0, 1.0, 1.0},
            pulse = 0.2, own = true, lick = i}
        if self:addModel(o) then table.insert(self.licks, o) end
    end
end
function M:updateFlames(t, flick)
    local j = self.scene.javaObject
    local dt = self.dt or 0.016
    -- the fire flares up in the menu's first second
    local grow = math.max(0, math.min(1, (t - 0.3) / 1.1))
    grow = grow * grow * (3 - 2 * grow)
    -- a slow wind leans the whole fire one way and the other
    local wind = 6 * math.sin(t * 0.83) + 3.5 * math.sin(t * 2.1 + 1.3)
    for _, o in ipairs(self.flames or {}) do
        local f = o.flame
        -- Gusts: every fraction of a second a tongue is given a new height to
        -- go to - mostly near its own, now and then a leap - a new lean and a
        -- kick to its turning. No two tongues do it together: that is what
        -- keeps the fire from pulsing like one piece.
        if t >= (o.gustAt or 0) then
            o.gust = (frand() > 0.86) and (1.2 + frand() * 0.25) or (0.6 + frand() * 0.7)
            o.gustAt = t + 0.10 + frand() * 0.32
            o.jerk = (frand() - 0.5) * 90
            o.side = (frand() - 0.5) * 14
        end
        o.g = (o.g or 1) + (o.gust - (o.g or 1)) * math.min(1, dt * 11)
        o.spin = (o.spin or 0) + (f[7] + o.jerk) * dt
        o.lean = (o.lean or 0) + (o.side - (o.lean or 0)) * math.min(1, dt * 6)
        local p = f[6]
        local h = math.min(FLAME_TOP, f[4] * o.g * (1 + 0.08 * math.sin(t * 17 + p)))
            * (0.6 + 0.4 * flick) * (0.15 + 0.85 * grow)
        -- (a tongue that shoots up gets thinner, one that sinks spreads)
        local w = f[5] / FLAME_MESH_W * (1.13 - 0.22 * (o.g - 0.6)) * (0.4 + 0.6 * grow)
        j:fromLua1("getObjectScale", o.id):set(w, h, w)
        j:fromLua1("getObjectRotation", o.id):set(o.lean * 0.6 + 3 * math.sin(t * 3.1 + p), o.spin % 360, wind + o.lean)
    end
    -- Licks: born somewhere in the fire, they rise, drift and shrink to nothing.
    -- (They move, and a model's light is kept by its place: M:place takes it along.)
    for _, o in ipairs(self.licks or {}) do
        if not o.dieAt or t >= o.dieAt then
            o.bornAt = t + frand() * 0.6
            o.dieAt = o.bornAt + 0.45 + frand() * 0.5
            o.x0 = (frand() - 0.5) * 0.34
            o.y0 = 0.23 + frand() * 0.18
            o.rise = 0.18 + frand() * 0.16
            o.drift = (frand() - 0.5) * 0.12
            o.w = 0.07 + frand() * 0.07
            o.h = 0.12 + frand() * 0.12
        end
        local u = (t - o.bornAt) / (o.dieAt - o.bornAt)
        if u >= 0 and grow >= 1 then
            local s = (u < 0.2) and (u / 0.2) or ((1 - u) / 0.8)
            o.x = o.x0 + (o.drift + wind * 0.006) * u
            o.y = o.y0 + o.rise * u + o.lick * 0.0011
            o.sx = math.max(0.001, o.w / FLAME_MESH_W * s)
            o.sy = math.max(0.001, o.h * s * (1 + 0.6 * u))
            o.sz = o.sx
            o.yaw = ((o.yaw or 0) + 220 * dt) % 360
            self:place(o)
        elseif o.sx ~= 0.001 then
            o.sx, o.sy, o.sz = 0.001, 0.001, 0.001
            self:place(o)
        end
    end
end
--- Look after a character's pose: note when it is really in it, and enter the
--- state anew when its clip has come but the animator is not playing it.
function M:watchPose(o, t)
    if not knoxMenuPosed then
        o.posedAt = o.posedAt or t
        return
    end
    local clip = CLIP[o.anim]
    if not clip then return end                     -- a one-shot (getting up, sitting down): left alone
    if (o.poseAsked or 0) > t then return end
    o.poseAsked = t + (o.shownAt and 0.5 or 0.05)
    local j = self.scene.javaObject
    -- The clothes first. The game is still loading its clothing items after a
    -- start, and a character is built from the ones ready at that moment - too
    -- early, and the hero sits naked or half dressed for good (see
    -- knoxMenuClothesReady). So: wait for the hero's own items, have the
    -- character (and the portrait) built anew, and only then look at the pose.
    if o.dressed and not o.clothesOk and knoxMenuClothesReady then
        o.clothesAsked = o.clothesAsked or t
        if not knoxMenuClothesReady(o.save.rel) then
            if t - o.clothesAsked < CLOTHES_GIVE_UP then
                o.clothesLate = true
                return
            end
            -- given up: looks a mod fills in only in a game (Transmog) are
            -- swapped for the real things worn, and those are waited for
            if not o.swapped and knoxMenuClothesSubstitute and knoxMenuClothesSubstitute(o.save.rel) > 0 then
                o.swapped = true
                knoxMenuAnim(j, o.id, o.anim)
                knoxMenuDress(j, o.id, o.save.rel, o.zombie == true)
                if o.portrait then knoxMenuDressUI(o.portrait.javaObject, o.save.rel, o.zombie == true) end
                o.clothesAsked = t
                o.clothesLate = true
                return
            end
        end
        o.clothesOk = true
        o.clothesAt = t
        if o.clothesLate then
            knoxMenuRefreshClothes(j, o.id)
            if o.portrait then knoxMenuRefreshClothesUI(o.portrait.javaObject) end
            o.posedAt = nil
            o.holdUntil = t + 0.8   -- built anew in the frames to come: its old self doesn't count
        end
    end
    if o.holdUntil then
        if t < o.holdUntil then return end
        o.holdUntil = nil
    end
    local st = knoxMenuPosed(j, o.id, clip)
    -- (since when its clip is there: the give-up in M:watchHero counts from then)
    if st >= 1 then o.clipAt = o.clipAt or t end
    if st == 2 then
        o.unposedAt = nil
        -- (and a frame with it has been drawn: its textures are baked)
        if not o.posedAt and (not knoxMenuReady or knoxMenuReady(j, o.id)) then o.posedAt = t end
    elseif st == 1 then
        o.unposedAt = o.unposedAt or t
        if t - o.unposedAt > 0.7 then
            o.unposedAt = t
            -- (a few tries, then it is taken as it is: a pose that never reads as
            -- played must not be restarted for ever, nor keep the camp in the dark)
            o.reenters = (o.reenters or 0) + 1
            if o.reenters <= 6 then
                knoxMenuReenter(j, o.id, o.anim)
            else
                o.posedAt = o.posedAt or t
            end
        end
    end
end

--- Is the camp out of the dark (so that its people can be pointed at)?
function M:campShown()
    return self.revealAt ~= nil and self.clock - self.revealAt > REVEAL_FADE * 0.5 + 0.8
end

local CHAR_FADE = 0.8   -- s a hero takes to come in

--- A character coming in once it is in place: see M:watchHero.
function M:fadeIn(c, t)
    if not c.fadeAt then return end
    local k = math.max(0, math.min(1, (t - c.fadeAt) / CHAR_FADE))
    local a = k * k * (3 - 2 * k)
    local j = self.scene.javaObject
    if knoxMenuAlpha then knoxMenuAlpha(j, c.id, a) end
    local s = c.shadow
    if k >= 1 then
        c.fadeAt = nil
        if s then self:place(s) end
    elseif s then
        j:fromLua1("getObjectScale", s.id):set(math.max(0.001, (s.sx or 1) * a), 1, math.max(0.001, (s.sz or 1) * a))
    end
end

function M:watchReveal(t)
    self:hurryClips(t)
    if self.revealAt or t < REVEAL_AT then return end
    self.revealAt = t
end

--- While a hero waits for its clip (the game still reading its animations
--- after a start), the scene's clips are put at the head of the game's loading
--- queue - a few times, as the game may still be adding to that queue.
function M:hurryClips(t)
    if not knoxMenuHurryClips or t > 15 or (self.hurryAt or 0) > t then return end
    self.hurryAt = t + 0.5
    local waiting = false
    for _, c in ipairs(self.chars) do
        if not c.clipAt and not c.shownAt then waiting = true end
    end
    if not waiting then
        self.hurryAt = 99
        return
    end
    local n = knoxMenuHurryClips(MENU_CLIPS)
    if n and n > 0 then print("[Knox] menu scene: " .. n .. " of its animations moved ahead in the game's loading at " .. string.format("%.1f", t) .. " s") end
end

--- A hero not in yet: kept too small to see until it is in its pose with its
--- clothes on, then it takes its place and comes in - from see-through to
--- solid (the game's own alpha of a character), its shadow growing under it.
--- Never before the fire's light has reached it.
function M:watchHero(c, t)
    local j = self.scene.javaObject
    local ready = self.revealAt and c.posedAt and t - c.posedAt >= HERO_SETTLE
    -- Given up on only once its pose's clip has been there a while: without a
    -- mod that caches them the game may read its animations for half a minute
    -- after a start, and a hero shown before its clip came would stand.
    local late = (c.clipAt and t - c.clipAt >= HERO_GIVE_UP_LOADED) or t >= HERO_GIVE_UP
    if not (ready or late) then
        j:fromLua1("getObjectScale", c.id):set(0.001, 0.001, 0.001)
        if c.shadow then j:fromLua1("getObjectScale", c.shadow.id):set(0.001, 0.001, 0.001) end
        -- still not in after a few seconds: why, in the log
        c.whyDone = c.whyDone or 0
        local at = HERO_WHY_AT[c.whyDone + 1]
        if at and t >= at then
            c.whyDone = c.whyDone + 1
            print("[Knox] menu scene: " .. c.id .. " not in after " .. at .. " s: clothes "
                .. (c.clothesOk and "ok" or "waiting") .. ", pose " .. (c.posedAt and "ok" or "waiting")
                .. ", reenters " .. (c.reenters or 0) .. " | "
                .. tostring(knoxMenuWhy and knoxMenuWhy(j, c.id, CLIP[c.anim] or "", c.save and c.save.rel or nil)))
        end
        return
    end
    c.shownAt = t
    -- (from the fire outwards, as its light goes)
    local lit = (self.revealAt or t) + REVEAL_FADE * math.min(1, (c.dist or 0) / 8)
    c.fadeAt = math.max(t, lit)
    self:place(c)
    if knoxMenuAlpha then knoxMenuAlpha(j, c.id, 0) end
    if c.shadow then j:fromLua1("getObjectScale", c.shadow.id):set(0.001, 0.001, 0.001) end
    local function s(v) return v and string.format("%.1f", v) or "-" end
    print("[Knox] menu scene: " .. c.id .. " in after " .. s(t) .. " s (" .. s((getTimestampMs() - self.startMs) / 1000)
        .. " s real; clothes " .. s(c.clothesAt) .. ", pose " .. s(c.posedAt) .. ")"
        .. (ready and "" or " - not in place, shown as it is"))
    -- (what the hero is made of: a dark hero with a body mod was reported, and
    -- this tells a missing snapshot from a body that the menu draws dark)
    print("[Knox] menu scene: " .. c.id .. " " .. (c.dressed and "dressed" or (c.save and c.save.snap and "NOT dressed" or "no snapshot"))
        .. " | " .. tostring(knoxMenuCharInfo and knoxMenuCharInfo(j, c.id)))
    -- (and its clothes: a hero came in underwear on a player's PC, 2026-10-16)
    if knoxMenuClothesNote and c.save and c.dressed then
        print("[Knox] menu scene: " .. c.id .. " clothes: " .. tostring(knoxMenuClothesNote(c.save.rel)))
    end
end
function M:lightCharacter(c, flick)
    local j = self.scene.javaObject
    local rk = self:revealK(c)
    local boost = ((self.hover == c) and 1.4 or 1) * rk
    if not c.dressed then
        -- no snapshot of this save yet: a dark figure
        knoxMenuLight(j, c.id, NIGHT[1], NIGHT[2], NIGHT[3], 0.25 * boost, 0.25 * boost, 0.3 * boost)
        return
    end
    if c.zombie then
        -- out in the dark beyond the fence: shapes more than figures (pale
        -- skin shows far more than anything else there)
        local k = ((self.hover == c) and 1.0 or 0.55) * rk
        knoxMenuLight(j, c.id, NIGHT[1] * 0.9, NIGHT[2] * 0.9, NIGHT[3] * 0.9, k, k, k)
        return
    end
    local p = pool(c.dist) * flick
    knoxMenuLight(j, c.id, NIGHT[1] * 1.2 + FIRE[1] * p * 0.45, NIGHT[2] * 1.2 + FIRE[2] * p * 0.45,
        NIGHT[3] * 1.2 + FIRE[3] * p * 0.45, boost, boost, boost)
    -- direction to the fire in the model's own space (x side, y up, z front)
    local dx, dy, dz = -c.x, 0.45 - 0.7, -c.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 0.01 then return end
    dx, dy, dz = dx / len, dy / len, dz / len
    local a = math.rad(c.faceNow or c.face)
    local fx, fz = math.sin(a), math.cos(a)
    knoxMenuFireLight(j, c.id, dx * fz - dz * fx, dy, dx * fx + dz * fz,
        FIRE[1] * p * 0.8, FIRE[2] * p * 0.8, FIRE[3] * p * 0.8)
end

-- The forest around the camp: rows of firs behind the fence, wider and taller
-- with distance (the camera's view is a narrow fan; trees of real height this
-- close would hide the sky).
local TREE_ROWS = {
    {z = -16.5, low = 2.5, high = 3.5, tint = {0.20, 0.25, 0.34}},
    {z = -20.5, low = 3.0, high = 4.1, tint = {0.18, 0.22, 0.31}},
    {z = -26.0, low = 3.5, high = 4.8, tint = {0.16, 0.20, 0.28}},
    {z = -33.0, low = 4.2, high = 5.6, tint = {0.14, 0.18, 0.25}},
    {z = -42.0, low = 5.0, high = 6.6, tint = {0.12, 0.15, 0.22}},
}

function M:addTrees()
    local seed = 20261
    local function rnd()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end
    local aspect = self.width / math.max(1, self.height)
    local n = 0
    -- far rows first (sheets of mist between the rows were tried and taken
    -- out: they washed out the sky and the moon)
    for r = #TREE_ROWS, 1, -1 do
        local row = TREE_ROWS[r]
        local depth = CFG.eye[3] - row.z
        local half = depth * 0.5 + 2
        local x = -half + rnd() * 1.5
        while x < half do
            local z = row.z + (rnd() - 0.5) * 2.4
            local h = row.low + (row.high - row.low) * rnd()
            -- lower where the moon hangs, and none on the tower
            local ndc = (x + self.camShift) / (depth * 0.1944 * aspect)
            if ndc > 0.42 and ndc < 0.78 then h = h * 0.72 end
            local onTower = row.z > -19 and x > -5.4 and x < -2.0
            if not onTower then
                n = n + 1
                local k = 0.85 + 0.3 * rnd()
                local wide = 0.85 + 0.4 * rnd()
                local tree = {id = "km_tree" .. n, model = "KnoxMenu.Tree", x = x, z = z, yaw = rnd() * 360,
                    sx = h * wide, sy = h, sz = h * wide, shade = row.tint[2] * 5 * k}
                if self:addModel(tree) then
                    -- (each sways with a phase and a stiffness of its own: M:swayTrees)
                    tree.phase = rnd() * 6.28
                    tree.give = 0.7 + 0.6 * rnd()
                    self.trees = self.trees or {}
                    table.insert(self.trees, tree)
                end
            end
            x = x + 1.5 + rnd() * 1.5
        end
    end
end

-- The firs sway in the wind (the author's wish, 2026-10-15): a slow lean each
-- with its own phase and stiffness, and gusts that roll through the forest from
-- one side to the other. A turn about the tree's foot only (a model's light is
-- keyed by where it stands: it must not move).
local SWAY_DEG = 1.4          -- the lean of an average fir in a gust, degrees

function M:swayTrees(t)
    if not self.trees or (T.animOn and not T.animOn()) then return end
    local j = self.scene.javaObject
    -- the wind: a slow swell, and gusts every ten seconds or so
    local swell = 0.55 + 0.25 * math.sin(t * 0.13) + 0.2 * math.sin(t * 0.31 + 1.1)
    for _, o in ipairs(self.trees) do
        -- (a gust reaches a tree later the further right it stands: it rolls through)
        local g = math.sin(t * 0.55 - o.x * 0.08 + 0.7)
        local gp = math.max(0, g)
        local gust = gp * gp * gp
        local lean = SWAY_DEG * o.give * (0.35 * math.sin(t * 0.9 + o.phase) * swell + gust * 0.9 + 0.25 * swell)
        local twist = 0.4 * SWAY_DEG * o.give * math.sin(t * 0.7 + o.phase * 1.7) * swell
        j:fromLua1("getObjectRotation", o.id):set(twist, o.yaw or 0, lean)
    end
end

--- A soft shadow on the ground under something at x, z. Kept just over the
--- ground (a sheet any higher cuts the feet off what stands on it).
function M:addShadow(id, x, z, length, width, yaw)
    local o = {id = id, model = "KnoxMenu.Shadow", x = x, y = 0.005, z = z, yaw = yaw or 0,
        sx = length, sy = 1, sz = width, tint = {1.0, 1.0, 1.0}}
    if self:addModel(o) then return o end
    return nil
end

--- A hero's shadow goes where the hero goes.
function M:moveShadow(c)
    local o = c.shadow
    if not o then return end
    o.x, o.z = c.x, c.z
    self:place(o)
end

-- Building --------------------------------------------------------------------

function M:build()
    local j = self.scene.javaObject
    j:fromLua1("setDrawGrid", false)
    j:fromLua1("setDrawGridAxes", false)
    j:fromLua1("setDrawGridPlane", false)
    j:fromLua1("setGizmoVisible", "none")
    self:aimCamera()

    -- the lamps models are shaded by: night; fire (place, color, reach); the
    -- lamp on the post; the moon (direction towards it, color)
    self.lights = {NIGHT[1] * 1.2, NIGHT[2] * 1.2, NIGHT[3] * 1.2,
        0, 0.45, 0, FIRE[1], FIRE[2], FIRE[3], 1.25,
        LAMP.x, LAMP.y, LAMP.z, LAMP.light[1], LAMP.light[2], LAMP.light[3], 1.8,
        0.45, 0.62, -0.64, 0.17, 0.21, 0.31}
    knoxMenuSceneLights(self.lights)
    knoxMenuFireFlicker(1)

    self.objects = {}
    self.chars = {}
    self.revealAt, self.revealDone = nil, nil   -- a camp built anew starts in the dark again
    self.memorials = {}
    self.empties = {}
    -- The latest saves. The three latest heroes still alive sit at the fire (a
    -- death does not push anyone from it). The dead: the latest few walk
    -- beyond the fence, those before them lie under the crosses - never both.
    local all = recentSaves(12)
    local returned = knoxMenuReturned and knoxMenuReturned() or nil
    local saves, risen, buried = {}, {}, {}
    for _, save in ipairs(all) do
        if not save.dead then
            if #saves < #SEATS then table.insert(saves, save) end
        elseif #risen < RISEN then
            table.insert(risen, save)
        else
            table.insert(buried, save)
        end
    end
    for _, p in ipairs(PROPS) do
        if p.trees then
            self:addTrees()
        elseif p.memorials then
            self:addMemorials(buried)
        elseif p.car then
            self:addCar(p)
        elseif p.shadows then
            for i, s in ipairs(p.shadows) do
                self:addShadow("km_shadow" .. i, s[1], s[2], s[3], s[4], s[5])
            end
        elseif p.flames then
            self:addFlames()
        elseif p.zombies then
            for n, save in ipairs(risen) do
                local g = GRAVES[n]
                -- each its own sway and gait (see M:zombieIdle)
                local k = (n - 1) % #ZOMBIE_IDLES + 1
                self:addCharacter({id = "km_dead" .. n, slot = n, save = save, zombie = true,
                    x = g.x, y = 0, z = g.z, face = g.face, height = CFG.standHeight,
                    anim = ZOMBIE_IDLES[k], idleAnim = ZOMBIE_IDLES[k], walkAnim = ZOMBIE_WALKS[k], walkK = ZOMBIE_WALK_K[k], walkScale = ZOMBIE_WALK_SCALE[k],
                    nextAt = 4 + n * 3 + ZombRand(50) / 10})
            end
        elseif p.chars then
            for slot, save in ipairs(saves) do
                local seat = SEATS[slot]
                do
                    local c = {id = "km_hero" .. slot, slot = slot, save = save, seat = seat,
                        x = seat.x, y = 0, z = seat.z, face = seat.face, height = CFG.sitHeight,
                        nextAt = 7 + ZombRand(120) / 10}
                    if returned and returned == save.rel then
                        -- just left for the menu: walks in from where heroes walk off, and sits down
                        local dir = seat.leave
                        local len = math.sqrt(dir[1] * dir[1] + dir[2] * dir[2])
                        c.dirX, c.dirZ = dir[1] / len, dir[2] / len
                        c.x, c.z = seat.x + c.dirX * 4.3, seat.z + c.dirZ * 4.3
                        c.face = math.deg(math.atan2(-c.dirX, -c.dirZ))
                        c.anim = "knoxmenu_walk"
                        c.height = CFG.standHeight
                        c.entering = "walk"
                        c.clock = 0
                    end
                    -- what the hero carries: the backpack is taken off and put
                    -- down beside them (before dressing: not drawn on the back)
                    self:addBag(c, slot)
                    self:addCharacter(c)
                    c.shadow = self:addShadow("km_hshadow" .. slot, c.x, c.z, 1.25, 1.25)
                    -- what the hero carried lies within reach
                    local weapon = save.snap and save.snap.weapon
                    if weapon and weapon ~= "" then
                        local sm = getScriptManager()
                        local ms = sm:getModelScript(weapon) or sm:getModelScript("Base." .. weapon)
                        local at = WEAPON_AT[slot]
                        if ms and at and ms:getName() then
                            self:addModel({id = "km_weapon" .. slot, model = ms:getFullType(), world = true, weapon = true,
                                x = at[1], z = at[2], yaw = at[3], lit = 0.6, near = 0.45})
                        end
                    end
                end
            end
        else
            local o = {}
            for k, v in pairs(p) do o[k] = v end
            self:addModel(o)
        end
    end

    -- a thing lying where a hero's bag is put down makes room for it
    for _, c in ipairs(self.chars) do
        local id = c.bagAt and BAG_MOVES[c.slot]
        if id then
            for _, o in ipairs(self.objects) do
                if o.id == id then
                    o.s = 0.001
                    self:place(o)
                end
            end
        end
    end

    -- the keepsakes put down in the camp (KnoxMenuKeep)
    self:addKeeps()

    -- The tent is where a survivor to come will wake up: a click on it starts
    -- a new game. It is told from the camp's other things by its light, which
    -- slowly breathes, and it lights up under the mouse. (Tried before and
    -- dropped: a mat on a free seat, a see-through figure, a backpack with a
    -- sand "plus" floating over it.)
    for _, o in ipairs(self.objects) do
        if o.id == "km_tent" then
            table.insert(self.empties, {empty = true, x = o.x, z = o.z, height = 1.3, halfWidth = 0.95, mat = o})
        end
    end

    -- a portrait per hero with a snapshot, shown in the hover card (the
    -- dead are remembered as they were)
    for _, c in ipairs(self.chars) do
        if c.dressed then c.portrait = self:makePortrait(c.save, c.zombie) end
    end
    for _, m in ipairs(self.memorials) do
        m.portrait = self:makePortrait(m.save, false)
    end
end

function M:aimCamera()
    local aspect = self.width / math.max(1, self.height)
    -- the menu's labels are on the left: the camp sits a little to the right
    local shift = (aspect >= 2.1) and 0.3 or 0.6
    self.camShift = shift
    knoxMenuCamera(self.scene.javaObject, CFG.fov, CFG.eye[1] - shift, CFG.eye[2], CFG.eye[3],
        CFG.target[1] - shift, CFG.target[2], CFG.target[3])
end

-- The camera breathes and looks after the mouse (the author's wish, 2026-10-15):
-- a slow sway of a few centimetres, as if held, and a small turn towards where
-- the mouse is, eased - as many games' menus do. Over the game's own screens, the
-- news reader, a hero walking off: back to rest. The sky and the moon, drawn flat
-- behind the scene, move with the turn (M:drawBackdrop: skyDX / skyDY).
local SWAY_X, SWAY_Y = 0.05, 0.03     -- scene units
local LOOK_X, LOOK_Y = 0.34, 0.16     -- the look point at the screen's edge (about 2.3 and 1.1 degrees)
local LOOK_EYE = 0.12                 -- the eye a little the other way: some depth to the turn
local LOOK_EASE = 2.4                 -- how fast the turn catches up with the mouse (1/s)

function M:updateCamera(t, dt)
    if not self.camShift or not self.scene or not self.scene.javaObject then return end
    local still = T.animOn ~= nil and not T.animOn()
    local wantX, wantY = 0, 0
    local main = MainScreen.instance
    local free = self.mode == "idle" and main ~= nil and main.bottomPanel ~= nil and main.bottomPanel:getIsVisible()
        and not (KnoxMenuNewsReader and KnoxMenuNewsReader.instance)
    if free and not still and not self.tuning then
        local w, h = math.max(1, self.width), math.max(1, self.height)
        wantX = math.max(-1, math.min(1, (getMouseX() - w / 2) / (w / 2)))
        wantY = math.max(-1, math.min(1, (getMouseY() - h / 2) / (h / 2)))
    end
    local k = 1 - math.exp(-dt * LOOK_EASE)
    self.lookX = (self.lookX or 0) + (wantX - (self.lookX or 0)) * k
    self.lookY = (self.lookY or 0) + (wantY - (self.lookY or 0)) * k
    local sx, sy = 0, 0
    if not still then
        sx = SWAY_X * (math.sin(t * 0.37) + 0.4 * math.sin(t * 0.83 + 1.7))
        sy = SWAY_Y * (math.sin(t * 0.51 + 0.6) + 0.3 * math.sin(t * 1.13 + 2.2))
    end
    local shift = self.camShift
    local ex = CFG.eye[1] - shift + sx - self.lookX * LOOK_EYE
    local ey = CFG.eye[2] + sy + self.lookY * LOOK_EYE * 0.5
    local tx = CFG.target[1] - shift + sx * 0.5 + self.lookX * LOOK_X
    local ty = CFG.target[2] + sy * 0.5 - self.lookY * LOOK_Y
    knoxMenuCamera(self.scene.javaObject, CFG.fov, ex, ey, CFG.eye[3], tx, ty, CFG.target[3])
    self.eyeX, self.eyeY, self.eyeZ = ex, ey, CFG.eye[3]   -- (where the heroes look up to: M:updateLooks)
    -- how far the view has turned, in pixels at the sky (far away: rotation only)
    local dist = math.max(1, CFG.eye[3] - CFG.target[3])
    local ax = ((tx - ex) - (CFG.target[1] - CFG.eye[1])) / dist
    local ay = ((ty - ey) - (CFG.target[2] - CFG.eye[2])) / dist
    local ppr = self.height / math.rad(CFG.fov)
    self.skyDX, self.skyDY = -ax * ppr, ay * ppr
end

-- Sounds of the camp. The fire, the night forest, the wind and a cricket go on
-- and on: the Java part plays them (KnoxCamp - they outlive the menu, dying out
-- over the loading screen). An owl and a wolf far off are the scene's own
-- (media/scripts/knox_menu_sounds.txt); the risen heroes' moans and steps are
-- each their own (M:zombieSounds, played by KnoxCamp). The game's menu ambience under the
-- music (a TV, rain, thunder) is muted while the camp is up
-- (knoxMenuMuteAmbience).
local NOW_AND_THEN = {
    {name = "KnoxCampOwl", min = 18, max = 50},
    {name = "KnoxCampWolf", min = 60, max = 150},
}

function M:hasRisen()
    for _, c in ipairs(self.chars or {}) do
        if c.zombie then return true end
    end
    return false
end

function M:updateSounds(t)
    if not self.ambienceMuted then
        self.ambienceMuted = true
        if knoxMenuMuteAmbience then
            print("[Knox] menu scene: the game's menu ambience muted: " .. tostring(knoxMenuMuteAmbience(true)))
        end
    end
    -- a hero has gone and the game is loading: the camp and his steps are the
    -- Java part's now (KnoxCamp: they go on over the loading screen)
    if self.mode == "launched" then
        knoxCampTick()
        return
    end
    -- once the camp is lit
    if self.revealAt == nil then
        if self.campSounds then self:stopSounds() end
        return
    end
    self.campSounds = true
    -- (every frame: the cricket's song comes and goes softly)
    knoxCampLoops(true)
    local sm = getSoundManager()
    self.soundNext = self.soundNext or {}
    for _, s in ipairs(NOW_AND_THEN) do
        if not s.risen or self:hasRisen() then
            local at = self.soundNext[s.name]
            if at and t >= at then sm:playUISound(s.name) end
            if not at or t >= at then self.soundNext[s.name] = t + s.min + ZombRandFloat(0, s.max - s.min) end
        end
    end
end

function M:stopSounds()
    knoxCampLoops(false)   -- (not while a hero is on his way)
    self.campSounds = nil
    self.soundNext = nil
end
-- Screen ----------------------------------------------------------------------

--- The radio on the screen: {x, y, w, h} (a little bigger than the set itself:
--- easy to find with the mouse).
function M:radioRect()
    local bx, by = self:toScreen(RADIO_DIAL.x, 0, RADIO_DIAL.z)
    local _, ty = self:toScreen(RADIO_DIAL.x, 0.3, RADIO_DIAL.z)
    local ppu = math.abs(by - ty) / 0.3
    return {bx - 0.3 * ppu, by - 0.36 * ppu, 0.6 * ppu, 0.44 * ppu}
end

function M:toScreen(x, y, z)
    local j = self.scene.javaObject
    return j:sceneToUIX(x, y, z), j:sceneToUIY(x, y, z)
end

--- Screen rectangle of a character: {x, y, w, h}, and pixels per unit there.
function M:rectOf(c)
    local bx, by = self:toScreen(c.x, 0, c.z)
    local _, ty = self:toScreen(c.x, c.height, c.z)
    local ppu = math.abs(by - ty) / c.height
    local hw = (c.halfWidth or 0.42) * ppu
    return {bx - hw, ty - 0.08 * ppu, hw * 2, (by - ty) + 0.12 * ppu}, ppu
end

--- Is the mouse on the thing itself? Tighter than rectOf (which is the room
--- its card is placed by): a sitting or standing body is an oval, not a box -
--- the corners of its box are air, and the card came up well away from the
--- hero. The tent and the crosses keep a box, a narrow one for a cross.
function M:hit(c, mx, my)
    local r, ppu = self:rectOf(c)
    if c.empty then return T.inRect(mx, my, r) end
    local cx = r[1] + r[3] / 2
    if c.memorial then
        local hw = 0.24 * ppu
        return mx >= cx - hw and mx < cx + hw and my >= r[2] and my < r[2] + r[4]
    end
    -- a hero by the fire sits wide and low; a walking or risen one stands narrow
    local standing = c.zombie or c.height > CFG.sitHeight + 0.01
    local rx = (standing and 0.26 or 0.36) * ppu
    local top, bottom = r[2] + 0.06 * ppu, r[2] + r[4] - 0.1 * ppu
    local ry = (bottom - top) / 2
    if rx <= 0 or ry <= 0 then return false end
    local dx, dy = (mx - cx) / rx, (my - (top + ry)) / ry
    return dx * dx + dy * dy <= 1
end

function M:menuIdle()
    local main = MainScreen.instance
    if not main or main.inGame or not main.javaObject or not main.bottomPanel then return false end
    if not main:getIsVisible() or not main.bottomPanel:getIsVisible() then return false end
    return knoxMenuMouseFree(self.javaObject, main.javaObject) == true
end

-- Behaviour -------------------------------------------------------------------

--- A hero at the fire: warms the hands, rubs them now and then, rests a little.
function M:idle(c, dt)
    c.nextAt = c.nextAt - dt
    if c.nextAt > 0 then return end
    if c.anim == "knoxmenu_sit" then
        self:setAnim(c, "knoxmenu_warm")
        c.nextAt = 9 + ZombRand(120) / 10
    elseif c.anim == "knoxmenu_warm" then
        if ZombRand(2) == 0 then
            self:setAnim(c, "knoxmenu_rub")
            local len = knoxMenuClipSeconds(self.scene.javaObject, c.id, "Bob_SitGround_RubHands")
            c.nextAt = (len > 0 and len or 2.4) / 0.8
        else
            self:setAnim(c, "knoxmenu_sit")
            c.nextAt = 3 + ZombRand(40) / 10
        end
    else
        self:setAnim(c, "knoxmenu_warm")
        c.nextAt = 5 + ZombRand(60) / 10
    end
end

-- A hero looks up at you (the author's wish, 2026-10-16): the mouse on a hero,
-- and their head turns to the camera (the Java part turns the neck and the
-- head: KnoxLook); the mouse gone, it goes back to the fire. The others go on
-- warming their hands.
local LOOK_IN, LOOK_OUT = 2.6, 1.6        -- of the way a second, turning to you and back
local LOOK_MAX_YAW, LOOK_MAX_PITCH = 65, 30
local LOOK_HEAD = 0.82                    -- height of a sitting hero's head
local LOOK_YAW_SIGN = -1                  -- (1: the heroes at the sides turned away - the author, 2026-10-16)

function M:updateLooks(dt)
    if not knoxMenuLook or not self.eyeX then return end
    local j = self.scene.javaObject
    for _, c in ipairs(self.chars) do
        if not c.zombie then
            local want = (self.hover == c and self.mode == "idle" and not c.entering and c.anim ~= "knoxmenu_walk") and 1 or 0
            local w = c.lookW or 0
            if want > w then w = math.min(1, w + dt * LOOK_IN) else w = math.max(0, w - dt * LOOK_OUT) end
            if w > 0 or (c.lookW or 0) > 0 then
                local k = w * w * (3 - 2 * w)
                local dx, dy, dz = self.eyeX - c.x, self.eyeY - LOOK_HEAD, self.eyeZ - c.z
                local face = math.rad(c.faceNow or c.face or 0)
                local yaw = math.deg(math.atan2(dx, dz) - face)
                yaw = T.mod(yaw + 180, 360) - 180   -- (not %: negative in the game's Lua)
                yaw = math.max(-LOOK_MAX_YAW, math.min(LOOK_MAX_YAW, yaw)) * LOOK_YAW_SIGN
                local pitch = math.deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz)))
                pitch = math.max(-LOOK_MAX_PITCH, math.min(LOOK_MAX_PITCH, pitch))
                knoxMenuLook(j, c.id, yaw, pitch, k)
            end
            c.lookW = w
        end
    end
end

--- Is a spot beyond the fence free of the other dead (where they stand or go)?
function M:zombieRoom(c, x, z)
    for _, o in ipairs(self.chars) do
        if o ~= c and o.zombie then
            for _, p in ipairs({{o.x, o.z}, {o.walkX, o.walkZ}}) do
                if p[1] and math.abs(p[1] - x) < 0.5 and math.abs(p[2] - z) < 0.45 then return false end
            end
        end
    end
    return true
end

--- How fast a risen one walks, units a second: as far as its walk clip carries
--- the body in a cycle, over the cycle's time - measured against the hero's
--- walk, whose speed is set by hand (CFG.walkSpeed, feet seen right), so the
--- clips' units need no guess. (A guessed speed "floated" them, 2026-10-16.)
function M:zombieSpeed(c)
    local j = self.scene.javaObject
    local clip = CLIP[c.walkAnim]
    -- 1. from the clips: as far as the walk carries the body (its movement
    -- bone, read by index), against the hero's walk
    if c.zData == nil and knoxMenuClipStride then
        local zs, zd = knoxMenuClipStride(j, c.id, clip), knoxMenuClipSeconds(j, c.id, clip)
        local bs, bd = knoxMenuClipStride(j, c.id, "Bob_Walk"), knoxMenuClipSeconds(j, c.id, "Bob_Walk")
        if zs > 0 and zd > 0 and bs > 0 and bd > 0 then
            local hero = bs * 0.8 / bd   -- (knoxmenu_walk's m_SpeedScale: WALK_SPEED_SCALE below)
            c.zData = CFG.walkSpeed * (zs * (c.walkScale or 0.55) / zd) / hero
            print(string.format("[Knox] menu scene: %s walks at %.3f units/s (%s: %.3f per %.2f s; hero's %.3f per %.2f s)",
                c.id, c.zData, clip, zs, zd, bs, bd))
        else
            c.zData = false
            print("[Knox] menu scene: " .. c.id .. " walk speed not in the clips (" .. tostring(clip) .. " stride "
                .. tostring(zs) .. " / " .. tostring(zd) .. " s, hero's " .. tostring(bs) .. " / " .. tostring(bd) .. " s)")
        end
    end
    if c.zData then return c.zData end
    -- 2. measured on its feet while it walks (knoxMenuFootSpeed)
    if knoxMenuFootSpeed then
        local m = knoxMenuFootSpeed(j, c.id, false)
        if m and m > 0.02 and m < 2 then
            if not c.footLogged then
                c.footLogged = true
                print(string.format("[Knox] menu scene: %s walks at %.3f units/s, measured on its feet (%s)", c.id, m, tostring(clip)))
            end
            return m
        end
    end
    -- 3. a guess
    return CFG.zombieWalkSpeed * (c.walkK or 1)
end
--- Turn a risen one towards `face` over `secs` (the short way round).
function M:zombieTurn(c, face, secs)
    c.faceFrom = c.face
    c.faceTo = c.faceFrom + (T.mod(face - c.faceFrom + 180, 360) - 180)   -- (not %: negative in the game's Lua)
    c.turnT, c.turnLen = 0, secs
end

--- A risen hero beyond the fence: sways where it stands, now and then turns
--- its head and body a little, or shambles a few steps along the fence and
--- turns back towards the fire.
function M:zombieIdle(c, dt)
    if not c.shownAt or c.fadeAt then return end   -- not come in yet
    local moved = false
    if c.turnT then
        c.turnT = c.turnT + dt
        local k = math.min(1, c.turnT / c.turnLen)
        k = k * k * (3 - 2 * k)
        c.face = c.faceFrom + (c.faceTo - c.faceFrom) * k
        c.yaw = self:yawOf(c.face)
        if c.turnT >= c.turnLen then c.turnT = nil end
        moved = true
    end
    if c.walkX then
        local dx, dz = c.walkX - c.x, c.walkZ - c.z
        local d = math.sqrt(dx * dx + dz * dz)
        local step = self:zombieSpeed(c) * dt
        if d <= step then
            c.x, c.z = c.walkX, c.walkZ
            c.walkX, c.walkZ = nil, nil
            self:setAnim(c, c.idleAnim)
            -- and back towards the fire
            self:zombieTurn(c, math.deg(math.atan2(-c.x, -c.z)) + ZombRand(-12, 13), 1.4)
            c.nextAt = 6 + ZombRand(100) / 10
        elseif not c.turnT then   -- (it sets off once it has turned)
            c.x, c.z = c.x + dx / d * step, c.z + dz / d * step
        end
        c.dist = math.sqrt(c.x * c.x + c.z * c.z)
        moved = true
    else
        c.nextAt = (c.nextAt or 5) - dt
        if c.nextAt <= 0 then
            local r = ZombRand(10)
            if r < 4 then
                -- a few steps along the fence, to a free spot in sight
                local A = ZOMBIE_AREA
                for _ = 1, 6 do
                    local dist = (ZombRand(2) == 0 and -1 or 1) * (0.6 + ZombRand(90) / 100)
                    local x = math.max(A.x0, math.min(A.x1, c.x + dist))
                    local z = A.z0 + ZombRand(math.floor((A.z1 - A.z0) * 100)) / 100
                    if math.abs(x - c.x) > 0.3 and self:zombieRoom(c, x, z) then
                        c.walkX, c.walkZ = x, z
                        break
                    end
                end
                if c.walkX then
                    self:setAnim(c, c.walkAnim)
                    self:zombieTurn(c, math.deg(math.atan2(c.walkX - c.x, c.walkZ - c.z)), 0.9)
                else
                    c.nextAt = 3
                end
            elseif r < 8 then
                -- looks somewhere else for a while: mostly the fire's way
                self:zombieTurn(c, math.deg(math.atan2(-c.x, -c.z)) + ZombRand(-40, 41), 1.6 + ZombRand(10) / 10)
                c.nextAt = 5 + ZombRand(80) / 10
            else
                c.nextAt = 4 + ZombRand(60) / 10
            end
        end
    end
    if moved then self:place(c) end
    self:zombieSounds(c, dt)
end

-- (the zombie walks' footsteps at 0.15 and 0.6 of the clip - the game's
-- AnimSets/zombie/walktoward/walktoward2..4.xml)
local ZOMBIE_FOOT = {0.15, 0.6}

--- A risen hero's own sounds: a moan now and then (a man's or a woman's
--- voice, each on its own clock), and its feet shuffling as it walks.
function M:zombieSounds(c, dt)
    if not knoxCampMoan then return end
    c.moanAt = (c.moanAt or (8 + c.slot * 9 + ZombRand(150) / 10)) - dt
    if c.moanAt <= 0 then
        c.moanAt = 30 + ZombRand(500) / 10
        -- (a plain true / false: a dead hero with no snapshot gave nil here, and
        -- the Java call failed on it - lawlessheaven's report, 2026-10-16)
        local snap = c.save and c.save.snap
        knoxCampMoan(snap ~= nil and snap.female == true, 1)
    end
    if not c.walkX or c.turnT then
        c.zStepFrac, c.zWalkClock = nil, nil
        return
    end
    local clip = CLIP[c.walkAnim]
    local j = self.scene.javaObject
    local f = knoxMenuTrackFraction and clip and knoxMenuTrackFraction(j, c.id, clip) or -1
    c.zWalkClock = (c.zWalkClock or 0) + dt
    -- (once, well into its first walk: what its bones say, in the log)
    if not c.footWhy and c.zWalkClock > 1.5 and knoxMenuFootWhy then
        c.footWhy = true
        print("[Knox] menu scene: " .. c.id .. " walking | " .. tostring(knoxMenuFootWhy(j, c.id)))
    end
    if f < 0 then
        -- (the clip's place can't be read: by the clock, from the walk's start)
        local len = knoxMenuClipSeconds(j, c.id, clip)
        f = (c.zWalkClock / ((len > 0 and len or 1.6) / (c.walkScale or 0.55))) % 1
    end
    local last = c.zStepFrac
    c.zStepFrac = f
    if not last then return end
    for _, at in ipairs(ZOMBIE_FOOT) do
        local crossed
        if f >= last then crossed = at > last and at <= f
        else crossed = at > last or at <= f end   -- (the clip went round)
        if crossed then knoxCampZombieStep(1) end
    end
end

--- Back from the game: the hero walks in to the fire, turns and sits down.
function M:updateEntering(c, dt)
    if not c.shownAt or self.clock - c.shownAt < 0.3 then return end   -- not come in yet
    c.clock = c.clock + dt
    if c.entering == "walk" then
        local dx, dz = c.seat.x - c.x, c.seat.z - c.z
        local d = math.sqrt(dx * dx + dz * dz)
        local step = CFG.walkSpeed * dt
        if d <= step then
            c.x, c.z = c.seat.x, c.seat.z
            c.entering = "sit"
            c.clock = 0
            c.faceFrom = c.face
            self:setAnim(c, "knoxmenu_sitdown")
            local len = knoxMenuClipSeconds(self.scene.javaObject, c.id, "Bob_SitGround_In")
            c.phaseEnd = (len > 0 and len or 1.8)
        else
            c.x, c.z = c.x + dx / d * step, c.z + dz / d * step
            self:steps(c)
        end
        c.dist = math.sqrt(c.x * c.x + c.z * c.z)
        self:place(c)
        self:moveShadow(c)
    else
        -- the short way round to face the fire
        local diff = T.mod(c.seat.face - c.faceFrom + 180, 360) - 180   -- (not %: negative in the game's Lua)
        c.faceNow = c.faceFrom + diff * math.min(1, c.clock / 0.5)
        c.yaw = self:yawOf(c.faceNow)
        self:place(c)
        if c.clock >= c.phaseEnd then
            c.face, c.faceNow = c.seat.face, nil
            c.yaw = self:yawOf(c.face)
            self:place(c)
            c.height = CFG.sitHeight
            c.entering = nil
            self:setAnim(c, "knoxmenu_warm")
            c.nextAt = 8 + ZombRand(100) / 10
        end
    end
end

-- Footsteps (the author's wish, 2026-10-15): a step on the grass as a walking
-- hero's foot comes down - where the game's own walk puts its footsteps, at 0.2
-- and 0.65 of the clip (AnimSets/player/movement/defaultWalk.xml). Played by the
-- Java part (KnoxCamp, the steps Kenney's CC0 ones): a few more die away in the
-- dark once the screen is black.
local FOOT = {0.2, 0.65}
local WALK_SPEED_SCALE = 0.8   -- (knoxmenu_walk's m_SpeedScale)

--- A walk cycle as the scene plays it, in seconds.
function M:walkCycle(c)
    local len = knoxMenuClipSeconds(self.scene.javaObject, c.id, "Bob_Walk")
    return (len > 0 and len or 1.2) / WALK_SPEED_SCALE
end

function M:steps(c)
    if not knoxCampStep then return end
    local f = knoxMenuTrackFraction and knoxMenuTrackFraction(self.scene.javaObject, c.id, "Bob_Walk") or -1
    if f < 0 then
        -- (the clip not playing yet: by the clock, from the walk's start)
        local cyc = self:walkCycle(c)
        f = (c.clock / cyc) % 1
    end
    local last = c.stepFrac
    c.stepFrac = f
    if not last then return end
    for i, at in ipairs(FOOT) do
        local crossed
        if f >= last then crossed = at > last and at <= f
        else crossed = at > last or at <= f end   -- (the clip went round)
        if crossed then knoxCampStep(i - 1) end
    end
end

--- The hero's save was picked: get up, walk out of the picture, then load it.
function M:leave(c)
    self.mode = "leaving"
    self.leaving = c
    self.hover = nil
    c.phase = "getup"
    c.clock = 0
    if c.zombie then
        c.phase = "fade"
    else
        self:setAnim(c, "knoxmenu_getup")
        local len = knoxMenuClipSeconds(self.scene.javaObject, c.id, "Bob_SitGround_Out")
        c.phaseEnd = (len > 0 and len or 2.3) - 0.15
    end
    self:showFader()
    getSoundManager():playUISound("UIActivateMainMenuItem")
    -- the music steps back so his steps are heard (the author, 2026-10-15: lost under it)
    if knoxMusicDuck then knoxMusicDuck(0.4, 1500) end
end

function M:updateLeaving(dt)
    local c = self.leaving
    c.clock = c.clock + dt
    if c.phase == "getup" then
        if c.clock >= c.phaseEnd then
            c.phase = "walk"
            c.clock = 0
            c.stepFrac = nil
            self:setAnim(c, "knoxmenu_walk")
            local dir = c.seat.leave
            local len = math.sqrt(dir[1] * dir[1] + dir[2] * dir[2])
            c.dirX, c.dirZ = dir[1] / len, dir[2] / len
            c.faceFrom = c.face
            c.faceTo = math.deg(math.atan2(c.dirX, c.dirZ))
        end
    elseif c.phase == "walk" then
        local turn = math.min(1, c.clock / 0.4)
        c.faceNow = c.faceFrom + (c.faceTo - c.faceFrom) * turn
        c.yaw = self:yawOf(c.faceNow)
        local speed = CFG.walkSpeed * math.min(1, c.clock / 0.3)
        self:steps(c)
        c.x = c.x + c.dirX * speed * dt
        c.z = c.z + c.dirZ * speed * dt
        c.dist = math.sqrt(c.x * c.x + c.z * c.z)
        self:place(c)
        self:moveShadow(c)
        if c.clock >= 1.0 then self.fader.target = 1 end
        if c.clock >= 1.6 and self.fader.alpha >= 0.99 then self:launch(c) end
    elseif c.phase == "fade" then
        self.fader.target = 1
        if self.fader.alpha >= 0.99 then self:launch(c) end
    end
end

function M:launch(c)
    self.mode = "launched"
    self.launchClock = 0
    -- his steps and the camp go on without the scene (KnoxCamp)
    -- (a risen one fades: no steps, the camp dies out all the same)
    if knoxCampDepart then knoxCampDepart(c.phase == "walk" and self:walkCycle(c) or 0) end
    local ok, err = pcall(MainScreen.continueLatestSave, c.save.mode, c.save.name)
    if not ok then print("[Knox] menu scene: load failed: " .. tostring(err)) end
end

--- Loading didn't start (a dialog, or a new character is being made): back to the fire.
function M:comeBack()
    local c = self.leaving
    self.leaving = nil
    self.mode = "idle"
    if knoxCampEnd then knoxCampEnd(false) end
    if knoxMusicDuck then knoxMusicDuck(1, 1000) end
    if c and c.seat then
        c.x, c.z, c.face, c.faceNow = c.seat.x, c.seat.z, c.seat.face, nil
        c.yaw = self:yawOf(c.face)
        c.dist = math.sqrt(c.x * c.x + c.z * c.z)
        self:place(c)
        self:moveShadow(c)
        self:setAnim(c, "knoxmenu_sit")
        c.nextAt = 4
    end
    if self.fader then self.fader.target = 0 end
end

-- The black curtain over everything, the menu too.
function M:showFader()
    if self.fader then return end
    local f = ISUIElement:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    f:initialise()
    f:instantiate()
    f.alpha = 0
    f.target = 0
    f.prerender = function(el)
        -- (the curtain itself is never faded with the menu)
        if knoxMenuUiSkip then knoxMenuUiSkip(true) end
        el:drawRect(0, 0, el.width, el.height, el.alpha, 0, 0, 0)
        if knoxMenuUiSkip then knoxMenuUiSkip(false) end
    end
    f:addToUIManager()
    f:setAlwaysOnTop(true)
    self.fader = f
end

function M:updateFader(dt)
    local f = self.fader
    if not f then return end
    local step = dt / 0.9
    if f.alpha < f.target then f.alpha = math.min(f.target, f.alpha + step)
    elseif f.alpha > f.target then f.alpha = math.max(f.target, f.alpha - step) end
    if self.mode == "idle" and f.alpha <= 0 then
        f:removeFromUIManager()
        self.fader = nil
    end
end

-- Diagnostics (temporary) -----------------------------------------------------
-- Pictures of the frame at 3, 8 and 14 seconds (Zomboid/Screenshots,
-- knox_diag4_N_*.png): "_fx" right after the 3D scene, "_end" after the whole
-- UI; the GL state of both moments goes to console.txt.

local DIAG = false
KnoxMenuScene.DIAG = DIAG
local DIAG_AT = {3, 8, 14}

function M:diagFrame()
    self.diagDone = self.diagDone or 0
    local at = DIAG_AT[self.diagDone + 1]
    if at and self.clock >= at then
        self.diagDone = self.diagDone + 1
        local ready = ""
        for _, o in ipairs(self.objects) do
            if o.height then
                local sx, sy = self:toScreen(o.x, 0, o.z)
                print("[Knox] menu char " .. o.id .. " at " .. math.floor(sx) .. "," .. math.floor(sy) .. " dressed "
                    .. tostring(o.dressed) .. ": " .. tostring(knoxMenuCharInfo(self.scene.javaObject, o.id)))
            end
        end
        local main = MainScreen.instance
        print("[Knox] menu diag4 " .. self.diagDone .. ": frames " .. self.frames .. " order "
            .. knoxMenuUiOrder(self.javaObject, main and main.javaObject) .. "|" .. ready)
        self.diagRun = self.diagRun or tostring(math.floor(getTimestampMs() / 1000) % 100000)
        self.diagShotName = "knox_diag5_" .. self.diagRun .. "_" .. self.diagDone
    end
end

Events.OnPostUIDraw.Add(function()
    local self = KnoxMenuScene.instance
    if DIAG and self and self.diagShotName then
        knoxMenuShot(self.diagShotName .. "_end.png")
        self.diagShotName = nil
    end
end)

-- Frame -----------------------------------------------------------------------

function M:prerender()
    -- (the camp is never faded with the menu over it: KnoxUiFade, till M:render)
    if knoxMenuUiSkip then knoxMenuUiSkip(true) end
    local ok, err = pcall(self.frame, self)
    if not ok and self.frameError ~= tostring(err) then
        self.frameError = tostring(err)
        print("[Knox] menu scene frame error: " .. tostring(err))
    end
end

function M:render()
    if knoxMenuUiSkip then knoxMenuUiSkip(false) end
end

--- The menu over the camp fades away with the music while a hero gets up and
--- walks off (the author's wish, 2026-10-15), and comes back if he comes back.
function M:updateMenuFade(dt)
    if not knoxMenuUiAlpha then return end
    local want = (self.mode == "leaving" or self.mode == "launched") and 0 or 1
    local k = self.menuK or 1
    if k > want then k = math.max(want, k - dt / 1.5)
    elseif k < want then k = math.min(want, k + dt / 0.6) end
    self.menuK = k
    if k < 1 or self.menuFaded then
        knoxMenuUiAlpha(k * k * (3 - 2 * k))   -- (eased)
        self.menuFaded = k < 1
    end
end

function M:frame()
    local now = getTimestampMs()
    local dt = math.min(0.1, math.max(0, (now - (self.lastMs or now)) / 1000))
    self.lastMs = now
    self.clock = self.clock + dt
    self.frames = self.frames + 1
    local t = self.clock
    local flick = 1 + 0.07 * math.sin(t * 11.3) + 0.045 * math.sin(t * 23.7 + 1.3) + 0.04 * math.sin(t * 5.1 + 0.4)
    self.flick = flick
    knoxMenuFireFlicker(flick)

    self.dt = dt
    self:updateCamera(t, dt)
    self:updateSounds(t)
    self:updateMenuFade(dt)

    if self.mode == "launched" then
        if not knoxMenuInMenu() then
            -- the game is loading: stay dark (the scene goes with OnGameStart)
            self.launchClock = 0
            return
        end
        self.launchClock = self.launchClock + dt
        if self.launchClock > 0.6 then self:comeBack() end
    end

    -- light
    for _, o in ipairs(self.objects) do
        if o.height then
            -- a new model starts in the anim set's idle (standing): ask until it sits
            -- Checked all the time, a few times a second: the model is rebuilt
            -- while its clothes load, and every rebuild drops it back to idle.
            if (o.animAsked or 0) <= t then
                o.animAsked = t + 0.2
                knoxMenuAnim(self.scene.javaObject, o.id, o.anim)
            end
            self:watchPose(o, t)
            self:lightCharacter(o, flick)
            -- until it is in its pose a hero is there (loading, sitting down)
            -- but too small to see; M:watchHero puts it in its place
            if not o.shownAt then
                self:watchHero(o, t)
            else
                self:fadeIn(o, t)
            end
        elseif o.pulse or (o.tinted and not self.revealDone) then
            self:tint(o, flick)
        elseif o.vehicle and not self.revealDone then
            knoxMenuVehicleLight(0.2 * self:revealK(o))
        end
    end
    self:updateFlames(t, flick)
    self:swayTrees(t)
    -- (the pass above was the last one with the light still spreading)
    if self.revealAt and not self.revealDone and t - self.revealAt > REVEAL_FADE + 0.05 then self.revealDone = true end

    self:watchReveal(t)
    if DIAG then self:diagFrame() end

    -- mouse (nobody to point at while the camp is in the dark)
    local hover = nil
    if self.mode == "idle" and self.frames > 3 and not self.tuning and self:campShown() and self:menuIdle() then
        local mx, my = getMouseX(), getMouseY()
        for _, c in ipairs(self.chars) do
            -- (only someone who has come in)
            if c.shownAt and not c.fadeAt and not c.entering and self:hit(c, mx, my) then hover = c end
        end
        if not hover then
            for _, m in ipairs(self.memorials) do
                if self:hit(m, mx, my) then hover = m end
            end
        end
        if not hover then
            for _, e in ipairs(self.empties) do
                if self:hit(e, mx, my) then hover = e end
            end
        end
    end
    -- The radio by the fire is the menu's music player (the author's idea,
    -- 2026-10-15): the mouse on it brings up its card (KnoxRadioCard), as a
    -- hero's passport comes up. The card is a window over the menu: on it the
    -- mouse is not "free", the card keeps itself up meanwhile.
    self.radioHover = false
    if KnoxRadioCard and self.revealAt then
        local r = self:radioRect()
        local idle = self.mode == "idle" and self.frames > 3 and not self.tuning and self:campShown()
        -- (a keepsake being carried: the radio keeps quiet, it must not get in the way)
        local carrying = KnoxMenuKeep ~= nil and KnoxMenuKeep.drag ~= nil
        if idle and not carrying and not hover and self:menuIdle() and T.inRect(getMouseX(), getMouseY(), r) then self.radioHover = true end
        if idle and not carrying then KnoxRadioCard.track(r, self.radioHover, self.width) else KnoxRadioCard.hide() end
    end
    -- A hero's bag beside them: lit under the mouse, a click brings up what the
    -- hero carries (KnoxBagCard; the author, 2026-10-16: on a click, not on the
    -- mouse alone as the radio's card). See the clicks below.
    self.bagHover = nil
    local bagIdle = KnoxBagCard ~= nil and self.revealAt ~= nil and self.mode == "idle" and self.frames > 3
        and not self.tuning and self:campShown()
    if bagIdle and not hover and not self.radioHover and self:menuIdle() and not (KnoxMenuKeep and KnoxMenuKeep.drag) then
        local mx, my = getMouseX(), getMouseY()
        for _, c in ipairs(self.chars) do
            if c.bagAt and c.bag and c.shownAt and not c.fadeAt and T.inRect(mx, my, self:bagRect(c)) then self.bagHover = c end
        end
    end
    if KnoxBagCard then
        if not bagIdle then
            KnoxBagCard.hide()
            self.bagShown = nil
        elseif self.bagShown and KnoxBagCard.isUp() then
            KnoxBagCard.follow(self:bagRect(self.bagShown), self.width)   -- (the camera breathes)
        end
    end
    -- The news lie over the scene and are polled like it: a click on a card,
    -- or the one that closes an opened post, is not a click on a hero.
    local cards, reader = KnoxMenuNewsCards and KnoxMenuNewsCards.instance, KnoxMenuNewsReader and KnoxMenuNewsReader.instance
    if reader then self.newsHold = true end
    if cards and cards:getIsVisible() and T.inRect(getMouseX(), getMouseY(),
            {cards:getAbsoluteX(), cards:getAbsoluteY(), cards:getWidth(), cards:getHeight()}) then
        hover = nil
    end
    if self.newsHold then
        hover = nil
        if not reader and not isMouseButtonDown(0) then self.newsHold = false end
    end
    if self.tuning then self.mouseFree = self:menuIdle() end
    local down, rdown = isMouseButtonDown(0), isMouseButtonDown(1)
    local clicked, rclicked = down and not self.wasDown, rdown and not self.wasRDown
    self.wasDown, self.wasRDown = down, rdown
    -- keepsakes: carried, picked up, taken away - their clicks are their own
    if self:updateKeeps(down, clicked, rclicked) or (KnoxMenuKeep and KnoxMenuKeep.drag) then
        clicked, rclicked, hover = false, false, nil
    elseif self.keepHover then
        hover = nil
    end
    -- the bag's card: a click on a bag opens it (on the same bag again: closes);
    -- a click anywhere else but on the card closes it - and does nothing more
    -- (not a hero's save loaded by a click meant to close the card)
    local cardUp = KnoxBagCard and KnoxBagCard.isUp()
    if (clicked or rclicked) and (cardUp or self.bagHover) and not self.ctxMenu then
        local onCard = cardUp and KnoxBagCard.isMouseOn()
        if not onCard then
            local was = cardUp and self.bagShown or nil
            if cardUp then KnoxBagCard.close() end
            self.bagShown = nil
            local c = self.bagHover
            if clicked and c and c ~= was then
                local snap = c.save and c.save.snap
                local name = (snap and snap.name ~= "" and snap.name) or (c.save and c.save.name) or ""
                KnoxBagCard.open(self:bagRect(c), self.width, c.bag, name, c.save and c.save.rel)
                self.bagShown = c
            end
        end
        clicked, rclicked = false, false
    end
    if self.ctxMenu then
        -- a hero's menu is open (right click): the clicks are its own
        if self.mode ~= "idle" or self.newsHold or not self:menuIdle() then
            self:closeCtx()
        elseif clicked or rclicked then
            local item = clicked and self:ctxHit(getMouseX(), getMouseY()) or nil
            if item then self:ctxRun(item) else self:closeCtx() end
        end
    elseif rclicked and hover and hover.save and not hover.empty then
        self:openCtx(hover)
    elseif clicked and hover then
        if hover.empty then
            self:newGame()
        elseif self:canLoad(hover) then
            self:leave(hover)
        end
    end
    self.hover = (self.mode == "idle" and not self.ctxMenu) and hover or nil
    self:updateLooks(dt)
    self:skinBags()
    -- the tent (a new game): its light breathes, and it lights up under the mouse
    for _, e in ipairs(self.empties) do
        local shade = (self.hover == e) and 2.6 or (1.55 + 0.5 * math.sin(t * 2.3))
        if e.mat.tinted and math.abs((e.mat.shade or 1) - shade) > 0.01 then
            e.mat.shade = shade
            self:tint(e.mat, flick)
        end
    end

    for _, c in ipairs(self.chars) do
        if c.entering then self:updateEntering(c, dt) end
    end
    if self.mode == "idle" then
        for _, c in ipairs(self.chars) do
            if c.zombie then self:zombieIdle(c, dt)
            elseif not c.entering then self:idle(c, dt) end
        end
    elseif self.mode == "leaving" then
        self:updateLeaving(dt)
    end
    self:updateFader(dt)
    self:updateCard()
    self:updateTuner()
    self:drawBackdrop()
end

--- A free place at the fire was clicked: the game's own "Solo" item.
function M:newGame()
    local main = MainScreen.instance
    if not main or not main.soloScreen then return end
    getSoundManager():playUISound("UIActivateMainMenuItem")
    local ok, err = pcall(function()
        ActiveMods.getById("currentGame"):copyFrom(ActiveMods.getById("default"))
        main.bottomPanel:setVisible(false)
        main.soloScreen:setVisible(true)
        main.soloScreen:onItemClick(main.soloScreen.panels[1], 0, 0)
    end)
    if not ok then print("[Knox] menu scene: new game failed: " .. tostring(err)) end
end

-- A hero's menu (right click): load, the save's folder, delete the save.
-- Drawn and clicked by the scene itself, like everything of it.

function M:showCtx(menu, x, y)
    T.ensure()
    local pad = T.pad
    local w = T.measure(T.fontCaps, T.upper(menu.title or ""))
    for _, it in ipairs(menu.items) do w = math.max(w, T.measure(T.fontText, it.text)) end
    menu.w = w + pad * 3 + 4
    menu.headH = T.fontH(T.fontCaps) + pad + 4
    menu.rowH = T.fontH(T.fontText) + pad
    menu.h = menu.headH + #menu.items * menu.rowH + 2
    menu.x = math.floor(math.max(pad, math.min(self.width - menu.w - pad, x)))
    menu.y = math.floor(math.max(pad, math.min(self.height - menu.h - pad, y)))
    self.ctxMenu = menu
    local el = self.ctx
    el:setX(menu.x)
    el:setY(menu.y)
    el:setWidth(menu.w)
    el:setHeight(menu.h)
    el:setVisible(true)
end

function M:closeCtx()
    self.ctxMenu = nil
    if self.ctx then self.ctx:setVisible(false) end
end

function M:openCtx(c)
    local save = c.save
    local items = {}
    if self:canLoad(c) then
        table.insert(items, {id = "load", text = getText(save.dead and "IGUI_Knox_Menu_CtxNew" or "IGUI_Knox_Menu_CtxLoad")})
    end
    table.insert(items, {id = "folder", text = getText("IGUI_Knox_Menu_CtxFolder")})
    table.insert(items, {id = "delete", text = getText("IGUI_Knox_Menu_CtxDelete"), bad = true})
    self:showCtx({target = c, title = save.hero or save.name or "?", items = items}, getMouseX(), getMouseY())
    getSoundManager():playUISound("UIActivateButton")
end

function M:ctxHit(mx, my)
    local m = self.ctxMenu
    if mx < m.x or mx >= m.x + m.w or my < m.y + m.headH then return nil end
    return m.items[math.floor((my - m.y - m.headH) / m.rowH) + 1]
end

function M:ctxRun(item)
    local m = self.ctxMenu
    local c = m.target
    local save = c.save
    if item.id == "load" then
        self:closeCtx()
        self:leave(c)
    elseif item.id == "folder" then
        self:closeCtx()
        pcall(function() showFolderInDesktop(getAbsoluteSaveFolderName(save.rel)) end)
    elseif item.id == "delete" then
        -- asked once more, in the same place
        self:showCtx({target = c, title = getText("IGUI_Knox_Menu_CtxDeleteAsk", save.name or "?"), items = {
            {id = "confirm", text = getText("IGUI_Knox_Menu_CtxDeleteYes"), bad = true},
            {id = "cancel", text = getText("IGUI_Knox_Menu_CtxCancel")}}}, m.x, m.y)
    elseif item.id == "confirm" then
        self:closeCtx()
        self:deleteSave(save)
    else
        self:closeCtx()
    end
end

function M:deleteSave(save)
    local ok = pcall(deleteSave, save.rel)
    print("[Knox] menu scene: save " .. tostring(save.rel) .. (ok and " deleted" or " NOT deleted"))
    -- the menu's own "Continue" and "Load" follow what is left
    pcall(function()
        local main = MainScreen.instance
        main:getLatestSave()
        if #getFullSaveDirectoryTable() == 0 then
            if main.loadOption then main.loadOption:setVisible(false) end
            if main.latestSaveOption then main.latestSaveOption:setVisible(false) end
        end
    end)
    -- the camp is built again, outside this element's own drawing
    local again
    again = function()
        Events.OnPreUIDraw.Remove(again)
        KnoxMenuScene.create()
    end
    Events.OnPreUIDraw.Add(again)
end

local function drawCtx(el)
    local m = el.owner and el.owner.ctxMenu
    if not m then return end
    local pad = T.pad
    T.rect(el, 0, 0, m.w, m.h, T.color.window, 0.97)
    T.tileFrame(el, 0, 0, m.w, m.h, T.color.accent)
    T.rect(el, 0, 0, 4, m.h, T.color.accent)
    -- (2 px lower than the middle: capitals have no descenders and look lifted otherwise)
    T.text(el, T.upper(m.title or ""), 4 + pad, math.floor((m.headH - T.fontH(T.fontCaps)) / 2) + 2, T.color.dim, T.fontCaps)
    T.rect(el, 4, m.headH - 1, m.w - 6, 1, T.color.border)
    local mx, my = getMouseX() - m.x, getMouseY() - m.y
    for i, it in ipairs(m.items) do
        local y = m.headH + (i - 1) * m.rowH
        local hot = mx >= 0 and mx < m.w and my >= y and my < y + m.rowH
        if hot then T.rect(el, 4, y, m.w - 6, m.rowH, T.color.accent) end
        local c = hot and T.color.ink or (it.bad and T.color.bad or T.color.text)
        T.text(el, it.text, 4 + pad, y + math.floor((m.rowH - T.fontH(T.fontText)) / 2), c, T.fontText)
    end
end
KnoxMenuScene.drawCtx = drawCtx

--- Hardcore saves end with their hero (the game's own Continue is off for them too).
function M:canLoad(c)
    if c.memorial or c.empty then return false end   -- a cross is only remembered
    return not (c.save.dead and c.save.mode == "A Really CD DA")
end

function M:drawBackdrop()
    local w, h = self.width, self.height
    knoxMenuResetGL()
    self:drawRect(0, 0, w, h, 1, 0.01, 0.014, 0.025)
    -- the sky keeps its shape (2 : 1) across the width; the moon is a sprite
    -- of its own with a halo, round and sharp on any screen
    -- (a little wider than the screen: it moves as the camera turns, M:updateCamera)
    local dx, dy = self.skyDX or 0, self.skyDY or 0
    local over = math.floor(w * 0.04)
    self:drawTextureScaled(self.tex.sky, -over + dx, -over * 0.5 + dy, w + over * 2, (w + over * 2) / 2, 1, 1, 1, 1)
    local mx, my, ms = w * 0.80 + dx, h * 0.17 + dy, h * 0.085
    self:drawTextureScaled(self.tex.glow, mx - ms * 3.2, my - ms * 3.2, ms * 6.4, ms * 6.4, 0.20, 0.75, 0.85, 1.0)
    self:drawTextureScaled(self.tex.glow, mx - ms * 1.1, my - ms * 1.1, ms * 2.2, ms * 2.2, 0.30, 0.85, 0.92, 1.0)
    if self.tex.moon then self:drawTextureScaled(self.tex.moon, mx - ms / 2, my - ms / 2, ms, ms, 1, 1, 1, 1) end
    if self.frames < 3 then
        self:drawRect(0, 0, w, h, 1, 0, 0, 0)
        return   -- the camera exists after the first frame
    end
    -- the forest stands where the ground ends
    local _, yFar = self:toScreen(-self.camShift, 0, -70)
    local th = h * 0.27
    local tw = th * 4
    local x = -math.floor(tw * 0.37) + math.floor(dx) - tw
    while x < w do
        self:drawTextureScaled(self.tex.trees, x, yFar - th + h * 0.02, tw, th, 1, 1, 1, 1)
        x = x + tw
    end
    -- mist along the horizon, so the fence and whoever stands behind it show against it
    self:drawTextureScaled(self.tex.mist, -over, yFar - h * 0.11, w + over * 2, h * 0.2, 0.9, 1, 1, 1)
    local night = 1 - self:revealK(nil, 20)
    if night > 0 then self:drawRect(0, 0, w, h, night, 0, 0, 0) end
end

--- Drawn over the 3D scene: the fire and what it does to the air, the dark at the edges.
function M:drawFx(el)
    if DIAG and self.diagShotName then knoxMenuShot(self.diagShotName .. "_fx.png") end
    -- the 3D drawing leaves the color mask off and the stencil test on:
    -- nothing 2D drawn after it (the menu itself) would show
    knoxMenuResetGL()
    if self.frames < 3 then
        el:drawRect(0, 0, el.width, el.height, 1, 0, 0, 0)
        return
    end
    local t, flick = self.clock, self.flick
    local bx, by = self:toScreen(0, 0.06, 0)
    local _, uy = self:toScreen(0, 1.06, 0)
    local ppu = math.abs(by - uy)

    -- (the camp's dark is made of light, see M:revealK: nothing black is drawn
    -- here, and the lanterns' glows come with the light that reaches them)
    local lit = self:revealK(nil, 6.7)

    -- glow
    local g = ppu * 6.5
    el:drawTextureScaled(self.tex.glow, bx - g / 2, by - ppu * 0.5 - g / 2, g, g, 0.16 * flick, 1.0, 0.52, 0.16)
    g = ppu * 2.6
    el:drawTextureScaled(self.tex.glow, bx - g / 2, by - ppu * 0.45 - g / 2, g, g, 0.30 * flick, 1.0, 0.62, 0.22)

    -- (the flames themselves are 3D models in the scene: M:updateFlames)

    -- sparks
    local sparks = self.sparks
    if #sparks < 26 and ZombRand(100) < 22 then
        table.insert(sparks, {x = (ZombRand(100) - 50) / 260, y = 0.5 + ZombRand(40) / 100, age = 0,
            life = 1.3 + ZombRand(140) / 100, vx = (ZombRand(100) - 50) / 420, vy = 0.55 + ZombRand(70) / 100,
            phase = ZombRand(628) / 100})
    end
    local dt = self.dt or 0
    for i = #sparks, 1, -1 do
        local s = sparks[i]
        s.age = s.age + dt
        if s.age >= s.life then
            table.remove(sparks, i)
        else
            s.y = s.y + s.vy * dt
            s.x = s.x + (s.vx + 0.12 * math.sin(t * 2.3 + s.phase)) * dt
            local sx, sy = self:toScreen(s.x, s.y, 0)
            local k = 1 - s.age / s.life
            local size = math.max(2, math.floor(ppu * 0.016 + 0.5))
            el:drawRect(sx, sy, size, size, k * 0.9, 1.0, 0.55 + 0.3 * k, 0.15)
        end
    end

    -- the lanterns' own small lights: by the fire, and on the post in the camp
    local lx, ly = self:toScreen(LAMP.x, LAMP.y, LAMP.z)
    local _, ly2 = self:toScreen(LAMP.x, LAMP.y + 1, LAMP.z)
    local lp = math.abs(ly - ly2) * 2.6
    el:drawTextureScaled(self.tex.glow, lx - lp / 2, ly - lp / 2, lp, lp, 0.34 * (0.9 + 0.1 * flick) * lit, 1.0, 0.8, 0.45)
    if self.graveLight then
        lx, ly = self:toScreen(GRAVE_LIGHT.x, 0.12, GRAVE_LIGHT.z)
        _, ly2 = self:toScreen(GRAVE_LIGHT.x, 1.12, GRAVE_LIGHT.z)
        lp = math.abs(ly - ly2) * 1.5
        el:drawTextureScaled(self.tex.glow, lx - lp / 2, ly - lp / 2, lp, lp, 0.30 * (0.9 + 0.1 * flick) * self:revealK(nil, 10.8), 1.0, 0.75, 0.4)
    end

    -- the radio under the mouse: a soft sand light round it (it is the player)
    if self.radioHover or (KnoxRadioCard and KnoxRadioCard.instance and KnoxRadioCard.instance:getIsVisible()) then
        local r = self:radioRect()
        local gs = r[3] * 1.6
        el:drawTextureScaled(self.tex.glow, r[1] + r[3] / 2 - gs / 2, r[2] + r[4] / 2 - gs / 2, gs, gs, 0.22 * lit, 1.0, 0.85, 0.55)
    end
    -- a keepsake under the mouse, or one being carried: what it is, whose it was
    self:drawKeepHint(el)
    -- a hero's bag under the mouse (or its card up): the same light round it
    local bagLit = self.keepToBag or self.bagHover or (KnoxBagCard and KnoxBagCard.isUp() and self.bagShown) or nil
    if bagLit and bagLit.bagAt then
        local r = self:bagRect(bagLit)
        local gs = r[3] * 1.6
        el:drawTextureScaled(self.tex.glow, r[1] + r[3] / 2 - gs / 2, r[2] + r[4] / 2 - gs / 2, gs, gs, 0.22 * lit, 1.0, 0.85, 0.55)
    end
    -- the radio's dial, lit while the music plays from it: a small warm green light
    if KnoxMenuMusic and KnoxMenuMusic.radioPlaying and KnoxMenuMusic.radioPlaying() then
        -- (the scene's X runs either way on the screen: the side that is right)
        local cx = self:toScreen(RADIO_DIAL.x, RADIO_DIAL.y, RADIO_DIAL.z)
        local px = self:toScreen(RADIO_DIAL.x + 0.1, RADIO_DIAL.y, RADIO_DIAL.z)
        local lx = RADIO_DIAL.x + (px >= cx and 1 or -1) * RADIO_LAMP.right
        local ly = RADIO_DIAL.y + RADIO_LAMP.up
        local rx, ry = self:toScreen(lx, ly, RADIO_DIAL.z)
        local _, ry2 = self:toScreen(lx, ly + 1, RADIO_DIAL.z)
        -- (small: a dial lamp, not a light of the camp - the first one was a green
        -- cloud beside the radio)
        local rp = math.abs(ry - ry2) * 0.16
        local beat = 0.85 + 0.15 * math.sin(t * 2.3)
        el:drawTextureScaled(self.tex.glow, rx - rp / 2, ry - rp / 2, rp, rp, 0.35 * beat * lit, 0.6, 1.0, 0.5)
        el:drawTextureScaled(self.tex.glow, rx - rp / 6, ry - rp / 6, rp / 3, rp / 3, 0.6 * beat * lit, 0.85, 1.0, 0.65)
    end

    el:drawTextureScaled(self.tex.vignette, 0, 0, el.width, el.height, 1, 1, 1, 1)

    -- waking up: the fire itself out of the dark in the first seconds
    local wake = 1 - math.min(1, math.max(0, (t - 0.4) / 1.6))
    if wake > 0 then el:drawRect(0, 0, el.width, el.height, wake, 0, 0, 0) end
end

-- Hover card ------------------------------------------------------------------
-- The hero's passport: a portrait, the name with the profession under it, the
-- game mode and the town; three figures (days, zombies, health); how the hero
-- feels in words; when the save was last played.

--- "key=value|key=value" of a snapshot's extra line as a table.
local function parseExtra(s)
    local t = {}
    for pair in string.gmatch((s or "") .. "|", "([^|]*)|") do
        local k, v = string.match(pair, "^(%w+)=(.*)$")
        if k then t[k] = v end
    end
    return t
end

local function stateText(states)
    local words = {}
    for key in string.gmatch((states or "") .. ",", "([^,]*),") do
        if key ~= "" and #words < 3 then
            local w = getTextOrNull("IGUI_Knox_Menu_State_" .. key)
            if w then table.insert(words, w) end
        end
    end
    if #words == 0 then return nil end
    local text = table.concat(words, ", ")
    return T.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)   -- "Thirsty, tired"
end

-- The card comes up from the hero over a moment, fading in, and fades out when
-- the mouse leaves. The portrait is a 3D picture of its own, drawn over the
-- card: it can't fade, so it is shown once the card is in its place.
local CARD_IN_MS, CARD_OUT_MS = 170, 120

function M:updateCard()
    local c = self.hover
    local card = self.card
    local now = getTimestampMs()
    if c ~= self.cardFor then
        if c then
            self.cardMs = now
        elseif self.cardFor then
            self.cardGoneMs, self.cardGoneK = now, card.k or 1
        end
        self.cardFor = c
    end
    local k = 1
    if c then
        self.cardGoneMs = nil
        local t = math.max(0, math.min(1, T.anim((now - (self.cardMs or 0)) / CARD_IN_MS)))
        k = 1 - (1 - t) * (1 - t)
    end
    local settled = c ~= nil and k >= 1
    for _, o in ipairs(self.chars) do
        if o.portrait then o.portrait:setVisible(o == c and settled) end
    end
    for _, o in ipairs(self.memorials) do
        if o.portrait then o.portrait:setVisible(o == c and settled) end
    end
    if not c then
        -- going: the card as it was, fainter and sinking back to where it came from
        local t = self.cardGoneMs and T.anim((now - self.cardGoneMs) / CARD_OUT_MS) or 1
        if t >= 1 or not card.data then
            self.cardGoneMs = nil
            card:setVisible(false)
            return
        end
        card.k = (self.cardGoneK or 1) * (1 - t)
        card.portraitIn = false
        if card.restY then card:setY(card.restY + math.floor((card.rise or 0) * t * 0.6 + 0.5)) end
        card:setVisible(true)
        return
    end
    card:setVisible(true)
    card.k = k
    card.portraitIn = settled
    T.ensure()
    local pad, cell = T.pad, T.cell
    if c.empty then
        local d = {simple = true, title = getText("IGUI_Knox_Menu_FreePlace"), hint = getText("IGUI_Knox_Menu_NewSurvivor")}
        local w = math.max(T.measure(T.fontHeader, d.title), T.measure(T.fontTile, d.hint)) + pad * 2 + 4
        local h = pad + T.fontH(T.fontHeader) + 2 + T.fontH(T.fontTile) + pad
        local r = self:rectOf(c)
        local y = math.floor(r[2] - h - pad)
        card:setX(math.max(pad, math.min(self.width - w - pad, math.floor(r[1] + r[3] / 2 - w / 2))))
        local below = y < pad
        card.rise = math.floor(cell * 0.28) * (below and -1 or 1)
        card.restY = below and math.floor(r[2] + r[4] + pad) or y
        card:setY(card.restY + math.floor(card.rise * (1 - k) + 0.5))
        card:setWidth(w)
        card:setHeight(h)
        card.data = d
        return
    end
    local save = c.save
    local snap = save.snap
    local extra = save.extra
    if not extra then
        extra = parseExtra(snap and snap.extra)
        save.extra = extra
    end
    local d = {}
    d.name = save.hero or "?"
    d.profession = extra.profession
    local place = getTextOrNull("IGUI_Gametime_" .. save.mode) or save.mode
    local town = extra.town and getTextOrNull("IGUI_Knox_Menu_Town_" .. extra.town)
    if town then place = place .. ", " .. town end
    d.place = place
    d.dead = save.dead
    if snap then
        d.days = tostring(math.floor(snap.hours / 24))
        d.kills = tostring(math.floor(snap.kills or 0))
        if save.dead then
            d.health, d.healthColor, d.bar = "0%", T.color.bad, 0
            d.state, d.stateColor = getText("IGUI_Knox_Menu_Dead"), T.color.bad
        else
            local h = math.max(0, math.min(1, snap.health / 100))
            d.bar = h
            d.health = tostring(math.floor(h * 100 + 0.5)) .. "%"
            d.healthColor = (h > 0.6) and T.color.good or ((h > 0.3) and T.color.warn or T.color.bad)
            local words = stateText(extra.states)
            d.state = words or getText("IGUI_Knox_Menu_StateOk")
            d.stateColor = words and T.color.warn or T.color.dim
        end
    else
        d.days, d.kills, d.health, d.healthColor = "?", "?", "?", T.color.dim
        if save.dead then d.state, d.stateColor = getText("IGUI_Knox_Menu_Dead"), T.color.bad end
    end
    if save.played and save.played ~= "" then d.played = getText("IGUI_Knox_Menu_Played", save.played) end
    if not snap and not save.dead then d.hint = getText("IGUI_Knox_Menu_Unknown") end
    if save.dead and self:canLoad(c) then d.hint = getText("IGUI_Knox_Menu_NewHero") end

    -- sizes: the head (portrait, name, profession, place), the three figures, the foot
    local ps = math.floor(cell * 1.9)
    local nameH, smallH, bigH = T.fontH(T.fontHeader), T.fontH(T.fontTile), T.fontH(T.fontHeader)
    local headW = math.max(T.measure(T.fontHeader, d.name), T.measure(T.fontTile, d.profession or ""),
        T.measure(T.fontTile, d.place))
    local footW = math.max(T.measure(T.fontTile, d.state or ""), T.measure(T.fontTile, d.played or ""),
        T.measure(T.fontTile, d.hint or ""))
    local w = math.max(pad + ps + pad + headW + pad, footW + pad * 2, math.floor(cell * 5.2)) + 3
    local headH = pad + ps + pad
    local statsH = bigH + smallH + pad
    local footLines = (d.state and 1 or 0) + (d.played and 1 or 0) + (d.hint and 1 or 0)
    local footH = footLines > 0 and (footLines * (smallH + 2) + pad) or 0
    local h = headH + statsH + 3 + footH
    d.ps, d.headH, d.statsH = ps, headH, statsH

    local r = self:rectOf(c)
    local x = math.floor(r[1] + r[3] / 2 - w / 2)
    local y = math.floor(r[2] - h - pad)
    -- no room over the figure (a zombie far behind the fence stands high on the
    -- screen, and the "Knox Inventory | Settings" plate is up there): the card
    -- goes beside it, not over the plate and not over the figure itself
    local top = pad
    local tab = MainScreen.instance and MainScreen.instance.knoxSettingsTab
    if tab and tab:getIsVisible() then top = tab:getY() + tab:getHeight() + pad end
    local below = false
    if y < top then
        y = math.max(top, math.floor(r[2]))
        x = math.floor(r[1] + r[3] + pad)
        if x + w > self.width - pad then x = math.floor(r[1] - w - pad) end
    end
    x = math.max(pad, math.min(self.width - w - pad, x))
    -- (it rises to its place from the hero's side)
    card.rise = math.floor(cell * 0.28) * (below and -1 or 1)
    card.restY = y
    card:setX(x)
    card:setY(y + math.floor(card.rise * (1 - k) + 0.5))
    card:setWidth(w)
    card:setHeight(h)
    card.data = d
    d.hasPortrait = c.portrait ~= nil
    if c.portrait then
        c.portrait:setX(x + 3 + pad)
        c.portrait:setY(y + pad)
        c.portrait:setWidth(ps)
        c.portrait:setHeight(ps)
    end
end

local function drawCard(card)
    local d = card.data
    if not d then return end
    local pad = T.pad
    local w, h = card.width, card.height
    local a = card.k or 1   -- coming in or going out: everything at this alpha
    T.rect(card, 0, 0, w, h, T.color.window, 0.95 * a)
    -- sand all round, 4 px on every side as on the left (as the news cards)
    local t = 4
    T.rect(card, 0, 0, w, t, T.color.accent, a)
    T.rect(card, 0, h - t, w, t, T.color.accent, a)
    T.rect(card, 0, t, t, h - t * 2, T.color.accent, a)
    T.rect(card, w - t, t, t, h - t * 2, T.color.accent, a)
    if d.simple then
        T.text(card, d.title, 4 + pad, pad, T.color.bright, T.fontHeader, a)
        T.text(card, d.hint, 4 + pad, pad + T.fontH(T.fontHeader) + 2, T.color.accent, T.fontTile, a)
        return
    end

    -- head
    local ps = d.ps
    local px, py = 3 + pad, pad
    T.rect(card, px, py, ps, ps, T.color.cell, a)
    T.tileFrame(card, px - 3, py - 3, ps + 6, ps + 6, T.color.tileFrame, a)   -- around the portrait, which covers its own square
    T.border(card, px - 1, py - 1, ps + 2, ps + 2, T.color.tileFrame, a)
    if not d.hasPortrait then
        T.textCentre(card, "?", px + ps / 2, py + (ps - T.fontH(T.fontHeader)) / 2, T.color.dim, T.fontHeader, a)
    end
    local tx, ty = px + ps + pad, pad
    T.text(card, d.name, tx, ty, T.color.bright, T.fontHeader, a)
    ty = ty + T.fontH(T.fontHeader) + 2
    if d.profession and d.profession ~= "" then
        T.text(card, d.profession, tx, ty, T.color.accent, T.fontTile, a)
        ty = ty + T.fontH(T.fontTile) + 2
    end
    T.text(card, d.place, tx, ty + math.floor(pad / 2), T.color.dim, T.fontTile, a)

    -- three figures
    local sy = d.headH
    -- (inside the frame: four pixels of sand on every side)
    local inL, inW = 4, w - 8
    T.rect(card, inL, sy, inW, 1, T.color.border, a)
    local colW = math.floor(inW / 3)
    local figures = {
        {d.days, getText("IGUI_Knox_Menu_DaysCap"), T.color.bright},
        {d.kills, getText("IGUI_Knox_Menu_KillsCap"), T.color.bright},
        {d.health, getText("IGUI_Knox_Menu_Health"), d.healthColor},
    }
    for i, f in ipairs(figures) do
        local cx = inL + (i - 1) * colW
        if i > 1 then T.rect(card, cx, sy, 1, d.statsH, T.color.border, a) end
        T.text(card, f[1], cx + pad, sy + math.floor(pad / 2), f[3], T.fontHeader, a)
        T.text(card, T.upper(f[2]), cx + pad, sy + math.floor(pad / 2) + T.fontH(T.fontHeader), T.color.dim, T.fontTile, a)
    end
    sy = sy + d.statsH
    T.rect(card, inL, sy, inW, 3, T.color.cell, a)
    if d.bar and d.bar > 0 then
        local c = (d.bar > 0.6) and T.color.ok or ((d.bar > 0.3) and T.color.warn or T.color.bad)
        -- (the health bar grows as the card comes in)
        T.rect(card, inL, sy, math.floor(inW * d.bar * math.min(1, a)), 3, c, a)
    end

    -- foot: how the hero feels, when the save was played, what a click does
    local fy = sy + 3 + math.floor(pad / 2)
    local step = T.fontH(T.fontTile) + 2
    if d.state then
        T.text(card, d.state, 3 + pad, fy, d.stateColor, T.fontTile, a)
        fy = fy + step
    end
    if d.played then
        T.text(card, d.played, 3 + pad, fy, T.color.dim, T.fontTile, a)
        fy = fy + step
    end
    if d.hint then T.text(card, d.hint, 3 + pad, fy, T.color.accent, T.fontTile, a) end
end

-- Tuning (F9) -----------------------------------------------------------------
-- The scene is laid out blind; this moves things in the running game.
-- F9 on/off, [ ] pick an object, arrows = X and Z, PageUp/PageDown = Y,
-- Q E = turn, - = scale, Shift = faster, F10 = write everything to
-- Zomboid/Lua/knox_menu_layout.txt.

local function held(key)
    return key ~= nil and isKeyDown(key) == true
end

local function pressed(self, key)
    if key == nil then return false end
    local down = isKeyDown(key) == true
    local was = self.keys[key]
    self.keys[key] = down
    return down and not was
end

function M:updateTuner()
    -- (a tool for laying the scene out: with the game's -debug only)
    if not isDebugEnabled() then return end
    if pressed(self, Keyboard.KEY_F9) then
        self.tuning = not self.tuning
        self.tuneIndex = self.tuneIndex or 1
    end
    if not self.tuning then return end
    local n = #self.objects
    if pressed(self, Keyboard.KEY_RBRACKET) then self.tuneIndex = self.tuneIndex % n + 1 end
    if pressed(self, Keyboard.KEY_LBRACKET) then self.tuneIndex = T.mod(self.tuneIndex - 2, n) + 1 end
    local o = self.objects[self.tuneIndex]
    if not o then return end
    local fast = held(Keyboard.KEY_LSHIFT)
    local step = fast and 0.05 or 0.01
    local turn = fast and 3 or 0.5
    local moved = false
    local function nudge(key, field, d)
        if held(key) then
            o[field] = (o[field] or (field == "s" and 1 or 0)) + d
            moved = true
        end
    end
    nudge(Keyboard.KEY_LEFT, "x", -step)
    nudge(Keyboard.KEY_RIGHT, "x", step)
    nudge(Keyboard.KEY_UP, "z", -step)
    nudge(Keyboard.KEY_DOWN, "z", step)
    nudge(Keyboard.KEY_PRIOR, "y", step)
    nudge(Keyboard.KEY_NEXT, "y", -step)
    nudge(Keyboard.KEY_Q, "yaw", -turn)
    nudge(Keyboard.KEY_E, "yaw", turn)
    nudge(Keyboard.KEY_EQUALS, "s", step)
    nudge(Keyboard.KEY_MINUS, "s", -step)
    if moved then self:place(o) end
    if pressed(self, Keyboard.KEY_F10) then self:writeLayout() end
end

local function fmt(v)
    return string.format("%.2f", v or 0)
end

function M:writeLayout()
    local w = getFileWriter("knox_menu_layout.txt", true, false)
    if not w then return end
    for _, o in ipairs(self.objects) do
        w:write(o.id .. " x=" .. fmt(o.x) .. " y=" .. fmt(o.y) .. " z=" .. fmt(o.z) .. " yaw=" .. fmt(o.yaw)
            .. " s=" .. fmt(o.s or 1) .. "\r\n")
    end
    w:close()
    self.tuneSaved = self.clock
end

function M:drawTuner(el)
    if not self.tuning then return end
    local o = self.objects[self.tuneIndex]
    if not o then return end
    local text = "F9 tuning  [" .. self.tuneIndex .. "/" .. #self.objects .. "] " .. o.id .. "   x " .. fmt(o.x)
        .. "  y " .. fmt(o.y) .. "  z " .. fmt(o.z) .. "  yaw " .. fmt(o.yaw) .. "  s " .. fmt(o.s or 1)
    text = text .. "   mouse " .. (self.mouseFree and "free" or "blocked")
    if self.tuneSaved and self.clock - self.tuneSaved < 2 then text = text .. "   saved" end
    local tw = getTextManager():MeasureStringX(UIFont.Small, text)
    local x = math.floor((el.width - tw) / 2)
    el:drawRect(x - 8, 8, tw + 16, getTextManager():getFontHeight(UIFont.Small) + 8, 0.8, 0, 0, 0)
    el:drawText(text, x, 12, 1, 0.9, 0.6, 1, UIFont.Small)
    local sx, sy = self:toScreen(o.x or 0, o.y or 0, o.z or 0)
    el:drawRectBorder(sx - 6, sy - 6, 12, 12, 1, 1, 0.9, 0.3)
end

-- Life of the scene -----------------------------------------------------------

function M:new()
    local w, h = getCore():getScreenWidth(), getCore():getScreenHeight()
    local o = ISUIElement.new(self, 0, 0, w, h)
    o.clock = 0
    o.startMs = getTimestampMs()
    o.frames = 0
    o.mode = "idle"
    o.sparks = {}
    o.keys = {}
    o.wasDown = true   -- a click that brought the menu up is not a click on a hero
    return o
end

-- (not "createChildren": ISUIElement:instantiate calls that name itself, and
-- the whole scene was built twice)
function M:buildScene()
    self.tex = {
        sky = getTexture("media/ui/knoxmenu/sky.png"),
        trees = getTexture("media/ui/knoxmenu/treeline.png"),
        mist = getTexture("media/ui/knoxmenu/mist.png"),
        glow = getTexture("media/ui/knoxmenu/glow.png"),
        vignette = getTexture("media/ui/knoxmenu/vignette.png"),
        moon = getTexture("media/ui/knoxmenu/moon.png"),
        flames = {},
    }
    for i = 0, 23 do
        local tex = getTexture(string.format("media/ui/knoxmenu/flame_%02d.png", i))
        if tex then table.insert(self.tex.flames, tex) end
    end

    local scene = ISUI3DScene:new(0, 0, self.width, self.height)
    scene.background = false
    scene.onMouseWheel = function() return false end
    scene.onMouseMove = function() end
    scene:initialise()
    scene:instantiate()
    self:addChild(scene)
    self.scene = scene

    local owner = self
    local fx = ISUIElement:new(0, 0, self.width, self.height)
    fx:initialise()
    fx:instantiate()
    fx.prerender = function(el)
        owner:drawFx(el)
        owner:drawTuner(el)
    end
    self:addChild(fx)
    self.fx = fx

    local card = ISUIElement:new(0, 0, 10, 10)
    card:initialise()
    card:instantiate()
    card.prerender = drawCard
    card:setVisible(false)
    self:addChild(card)
    self.card = card

    self:build()   -- portraits are added after the card: drawn over it

    local ctx = ISUIElement:new(0, 0, 10, 10)
    ctx:initialise()
    ctx:instantiate()
    ctx.owner = self
    ctx.prerender = KnoxMenuScene.drawCtx
    ctx:setVisible(false)
    self:addChild(ctx)
    self.ctx = ctx
end

-- the camp's last sounds dying out in the game (KnoxCamp), a tick at a time
local campTickEvent = Events.OnTickEvenPaused or Events.OnTick
local function campTick()
    if knoxCampTick and knoxCampTick() then return end
    campTickEvent.Remove(campTick)
end

function KnoxMenuScene.destroy(intoGame)
    -- (the menu never left faded)
    if knoxMenuUiAlpha then knoxMenuUiAlpha(1) end
    if knoxMenuUiSkip then knoxMenuUiSkip(false) end
    -- the lights live in Java and outlive a Lua reset (joining a server): clear
    -- them even with no scene of this Lua's own
    if knoxMenuTintClear then knoxMenuTintClear() end
    -- (the game's menu ambience back, as it was before the camp)
    if knoxMenuMuteAmbience then knoxMenuMuteAmbience(false) end
    -- (a hero's way into the game ends with it: the steps stop, the camp's last
    -- sounds die out in the game - they were cut, the author, 2026-10-15)
    if knoxCampEnd then
        knoxCampEnd(intoGame == true)
        if intoGame == true then
            campTickEvent.Remove(campTick)
            campTickEvent.Add(campTick)
        end
    end
    local self = KnoxMenuScene.instance
    if not self then return end
    KnoxMenuScene.instance = nil
    self:stopSounds()
    if KnoxRadioCard then KnoxRadioCard.hide() end
    if KnoxBagCard then KnoxBagCard.hide() end
    if knoxMenuLookClear then knoxMenuLookClear() end   -- (the look hook idle again in the game)
    if self.fader then self.fader:removeFromUIManager() end
    if self.scene and self.scene.javaObject then knoxMenuCameraOff(self.scene.javaObject) end
    knoxMenuTintClear()
    self:removeFromUIManager()
end

function KnoxMenuScene.create()
    KnoxMenuScene.destroy()
    if not T.on("menu") or not knoxMenuInit then return end
    local main = MainScreen.instance
    if not main or main.inGame then return end
    if not knoxMenuInit() then
        print("[Knox] menu scene: Knox's states are missing from the player-avatar anim set, scene off")
        return
    end
    -- the game's menu ambience off at once (it was heard while the menu came up:
    -- the scene's first frame was too late - the author's test, 2026-10-15)
    if knoxMenuMuteAmbience then knoxMenuMuteAmbience(true) end
    T.ensure()
    local scene = KnoxMenuScene:new()
    scene:initialise()
    scene:instantiate()
    KnoxMenuScene.instance = scene
    local builtMs = getTimestampMs()
    local ok, err = pcall(scene.buildScene, scene)
    builtMs = getTimestampMs() - builtMs
    if not ok or not scene.tex or #scene.tex.flames == 0 or not scene.tex.sky then
        print("[Knox] menu scene: not built: " .. tostring(err))
        KnoxMenuScene.destroy()
        return
    end
    scene:addToUIManager()
    scene:backMost()
    print("[Knox] menu scene: " .. #scene.chars .. " of the last saves' heroes, " .. #scene.objects .. " objects, built in "
        .. builtMs .. " ms")
    scene.startMs = getTimestampMs()
end

Events.OnMainMenuEnter.Add(KnoxMenuScene.create)
Events.OnGameStart.Add(function() KnoxMenuScene.destroy(true) end)
-- (and before the menu is entered at all: the game starts its menu ambience
-- with the menu music, while its logos are still on)
if T.on("menu") and knoxMenuMuteAmbience and not (MainScreen.instance and MainScreen.instance.inGame) then
    pcall(knoxMenuMuteAmbience, true)
end
Events.OnResolutionChange.Add(function()
    if KnoxMenuScene.instance and KnoxMenuScene.instance.mode == "idle" then KnoxMenuScene.create() end
end)

-- A save deleted in the game's Load screen: its hero leaves the fire at once (D,
-- 2026-10-19: the hero stayed, and a click on him tried to load what was gone).
-- The camp is built anew outside of drawing, as after a delete from the hero's menu.
require "OptionScreens/LoadGameScreen"
if LoadGameScreen and LoadGameScreen.onDeleteModalClick and not LoadGameScreen.knoxCampHooked then
    LoadGameScreen.knoxCampHooked = true
    local onDelete = LoadGameScreen.onDeleteModalClick
    LoadGameScreen.onDeleteModalClick = function(self, button, ...)
        local r = onDelete(self, button, ...)
        if button and button.internal == "YES" and KnoxMenuScene.instance then
            local again
            again = function()
                Events.OnPreUIDraw.Remove(again)
                KnoxMenuScene.create()
            end
            Events.OnPreUIDraw.Add(again)
        end
        return r
    end
end

-- Snapshots -------------------------------------------------------------------
-- While a save is played: who the hero is and what they look like, for the
-- menu (the Java part writes knox_menu.bin into the save's folder).

-- Towns of Knox County by their middles (the spawn points of the game's maps;
-- Louisville has no map folder of its own): the nearest one within reach is
-- where the hero is.
local TOWNS = {
    {"Muldraugh", 10785, 9925}, {"WestPoint", 11578, 6862}, {"Riverside", 6357, 5430}, {"Rosewood", 8171, 11687},
    {"MarchRidge", 9883, 12812}, {"ValleyStation", 12595, 5330}, {"Brandenburg", 2152, 6089},
    {"Irvington", 1912, 14381}, {"Ekron", 411, 9761}, {"EchoCreek", 3573, 10899}, {"FallasLake", 7213, 8288},
    {"Louisville", 13200, 2600, 3200},
}

local function townAt(x, y)
    local best, bestD = nil, nil
    for _, t in ipairs(TOWNS) do
        local dx, dy = x - t[2], y - t[3]
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= (t[4] or 1400) and (not bestD or d < bestD) then best, bestD = t[1], d end
    end
    return best
end

local function moodle(player, name)
    local ok, level = pcall(function() return player:getMoodles():getMoodleLevel(MoodleType[name]) end)
    return (ok and tonumber(level)) or 0
end

--- How the hero feels, as keys of IGUI_Knox_Menu_State_*, the worst first.
local function statesOf(player)
    local out = {}
    if moodle(player, "BLEEDING") > 0 then table.insert(out, "bleeding") end
    local okBite, bitten = pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            if parts:get(i):bitten() then return true end
        end
        return false
    end)
    if okBite and bitten then table.insert(out, "bitten") end
    if moodle(player, "INJURED") >= 2 or moodle(player, "PAIN") >= 2 then table.insert(out, "injured") end
    if moodle(player, "SICK") > 0 then table.insert(out, "sick") end
    if moodle(player, "HAS_A_COLD") > 0 then table.insert(out, "cold") end
    if moodle(player, "HUNGRY") >= 2 then table.insert(out, "hungry") end
    if moodle(player, "THIRST") >= 2 then table.insert(out, "thirsty") end
    if moodle(player, "TIRED") >= 2 then table.insert(out, "tired") end
    return table.concat(out, ",")
end

--- What the snapshot keeps besides the look, for the hover card: "key=value|...".
local function extraOf(player)
    local parts = {}
    pcall(function()
        local desc = player:getDescriptor()
        local def = desc and CharacterProfessionDefinition.getCharacterProfessionDefinition(desc:getCharacterProfession())
        local name = def and def:getUIName()
        if name and name ~= "" then table.insert(parts, "profession=" .. string.gsub(name, "[|=]", " ")) end
    end)
    local town = townAt(player:getX(), player:getY())
    if town then table.insert(parts, "town=" .. town) end
    if not player:isDead() then table.insert(parts, "states=" .. statesOf(player)) end
    return table.concat(parts, "|")
end

local snapshotTold = false
local lastSnapMs = 0
local function snapshotOf(player)
    if not T.active or not knoxMenuSnapshot or not player then return end
    -- (a game with others: the camp shows no such save - nothing to write, every minute)
    if isClient() then return end
    lastSnapMs = getTimestampMs()
    local ok, extra = pcall(extraOf, player)
    local written = knoxMenuSnapshot(player, ok and extra or "")
    -- and what the hero carries: the bag beside them at the fire (KnoxMenuBag)
    if KnoxMenuBag then KnoxMenuBag.write(player) end
    -- once a game: was the hero written for the menu (no: a dark figure there)
    if not snapshotTold then
        snapshotTold = true
        print("[Knox] menu snapshot: " .. (written and "written" or "NOT written"))
    end
end

local function snapshot()
    snapshotOf(getSpecificPlayer(0))
end

Events.OnGameStart.Add(snapshot)
-- and once more a few seconds into the game: a new character gets its clothes
-- and starting bag around the start, and one taken out to the menu at once had
-- only the snapshot of that first moment (a player's report, 2026-10-16)
local againAt = nil
Events.OnGameStart.Add(function() againAt = getTimestampMs() + 3000 end)
Events.OnTick.Add(function()
    if againAt and getTimestampMs() >= againAt then
        againAt = nil
        local player = getSpecificPlayer(0)
        if player and not player:isDead() then snapshotOf(player) end
    end
end)
-- Now and then as the game goes on - but not more than once a minute of real
-- time: fast forward or sleep pass ten game minutes in a fraction of a second,
-- and each snapshot lays out every bag of the hero and writes two files (a
-- performance pass, 2026-10-16). Saving, clothes and death write at once.
local SNAP_EVERY_MS = 60000
Events.EveryTenMinutes.Add(function()
    if getTimestampMs() - lastSnapMs >= SNAP_EVERY_MS then snapshot() end
end)
Events.OnSave.Add(snapshot)
-- Clothes put on or taken off: the look is written again a moment later (once
-- for a burst of changes), so the hero at the fire wears what the player left
-- them in even when the game was quit between two of the snapshots above.
local lookDirtyAt = nil
if Events.OnClothingUpdated then
    Events.OnClothingUpdated.Add(function(player)
        if player and player == getSpecificPlayer(0) then lookDirtyAt = getTimestampMs() + 1500 end
    end)
    Events.OnTick.Add(function()
        if lookDirtyAt and getTimestampMs() >= lookDirtyAt then
            lookDirtyAt = nil
            local player = getSpecificPlayer(0)
            if player and not player:isDead() then snapshotOf(player) end
        end
    end)
end
Events.OnPlayerDeath.Add(function(player)
    if player and player == getSpecificPlayer(0) then snapshotOf(player) end
end)
