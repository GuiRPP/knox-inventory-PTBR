-- Keepsakes at the camp (the author's idea, 2026-10-16): things taken out of a
-- hero's bag at the fire (KnoxMenuBag's card) and put down in the camp. Only
-- their likeness: the thing itself stays in the hero's bag, the save is never
-- touched ("the things set out in the menu must not go from the player's bag").
-- So the camp fills with the things of the player's stories - the axe of a
-- hero long dead, a flask, a radio - each with the name of whose it was.
--
-- Kept in Zomboid/Lua/knox_camp_keepsakes.txt (getFileWriter's own folder):
--   KK1
--   type <tab> x <tab> z <tab> yaw <tab> hero <tab> save <tab> name
-- The scene puts them down and lets them be moved, turned and taken away
-- (KnoxMenuScene: "Keepsakes").

KnoxMenuKeep = {}
local K = KnoxMenuKeep

K.FILE = "knox_camp_keepsakes.txt"
K.MAX = 30          -- things in the camp at most (each is a model the scene draws)

K.list = nil        -- {type, x, z, yaw, hero, save, name}
K.drag = nil        -- a thing on its way from a bag's card to the ground

local function clean(s)
    return (string.gsub(tostring(s or ""), "[\t\r\n]", " "))
end

local function split(line)
    local f, at = {}, 1
    while true do
        local i = string.find(line, "\t", at, true)
        if not i then
            table.insert(f, string.sub(line, at))
            return f
        end
        table.insert(f, string.sub(line, at, i - 1))
        at = i + 1
    end
end

--- The keepsakes, read once.
function K.load()
    if K.list then return K.list end
    K.list = {}
    local r = getFileReader(K.FILE, false)
    if not r then return K.list end
    local first = r:readLine()
    if first == "KK1" then
        while true do
            local line = r:readLine()
            if not line then break end
            local f = split(line)
            if f[1] and f[1] ~= "" and #K.list < K.MAX then
                table.insert(K.list, {type = f[1], x = tonumber(f[2]) or 0, z = tonumber(f[3]) or 0,
                    yaw = tonumber(f[4]) or 0, hero = f[5] or "", save = f[6] or "", name = f[7] or f[1]})
            end
        end
    end
    r:close()
    return K.list
end

function K.save()
    local w = getFileWriter(K.FILE, true, false)
    if not w then return end
    w:writeln("KK1")
    for _, k in ipairs(K.list or {}) do
        w:writeln(table.concat({clean(k.type), string.format("%.3f", k.x), string.format("%.3f", k.z),
            string.format("%.1f", k.yaw), clean(k.hero), clean(k.save), clean(k.name)}, "\t"))
    end
    w:close()
end

local function first(list)
    if list and list:size() > 0 then return list:get(0) end
    return nil
end

--- The model a thing lies on the ground as (the game's own), or nil; and
--- true when it is a weapon's (held models: the scene turns them to lie down).
--- A weapon has no model "on the ground" of its own - its WeaponSprite is the
--- one held and lying (a bat, a hammer: missing at first, the author 2026-10-16),
--- as the hero's weapon at the fire.
function K.modelOf(itemType)
    local sm = getScriptManager()
    local script = itemType and sm:getItem(itemType)
    if not script then return nil end
    local tries = {
        {script:getWorldStaticModel(), false}, {first(script:getWorldStaticModelsByIndex()), false},
        {script:getStaticModel(), false}, {first(script:getStaticModelsByIndex()), false},
        {script:getWeaponSprite(), true}, {first(script:getWeaponSpritesByIndex()), true},
    }
    for _, t in ipairs(tries) do
        local name = t[1]
        if name and name ~= "" then
            local ms = sm:getModelScript(name) or sm:getModelScript("Base." .. name)
            if ms then return ms:getFullType(), t[2] end
        end
    end
    return nil
end

--- The camp as it was: every keepsake taken away (Knox's settings, the Modules
--- page). The things themselves were never taken from the heroes' bags.
function K.reset()
    local scene = KnoxMenuScene and KnoxMenuScene.instance
    if scene and scene.removeKeepModel then
        for _, k in ipairs(K.load()) do scene:removeKeepModel(k) end
    end
    K.list = {}
    K.drag = nil
    K.save()
end

--- Is the camp full?
function K.full()
    return #K.load() >= K.MAX
end

--- A thing taken from a bag's card: it follows the mouse until let go (the scene).
function K.beginDrag(it, hero, save)
    if K.full() or not K.modelOf(it.type) then return false end
    K.drag = {type = it.type, name = it.name or it.type, hero = hero or "", save = save or "",
              yaw = ZombRand(360), fresh = true}
    return true
end
