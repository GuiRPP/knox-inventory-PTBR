-- What KnoxSlotPicker.lua and KnoxLoad.lua need to load outside the game, over
-- tools/settings/stubs.lua (tools/lists/load.lua): a few of the game's guns,
-- magazines, rounds, boxes and parts as its scripts have them, containers, and
-- the game's actions written down instead of run.
KnoxTooltip = {want = function() end}
HELD = false   -- the quick items' key (Shift)
KnoxControls = {mods = function() return "" end, isHeld = function(id) return id == "quickItems" and HELD end}
ISInventoryItem = {renderItemIcon = function(ui) ui:drawRect() end}
function ISPanel:drawTextureScaledAspect() end
KnoxTheme.refresh()
KnoxGrid = {useNow = {}}

function instanceof(o, cls)
    if type(o) ~= "table" then return false end
    if cls == "InventoryItem" then return o.ft ~= nil end
    return o.cls == cls
end

local function list(t)
    return {size = function() return #t end, get = function(_, i) return t[i + 1] end}
end
JList = list

-- the game's scripts: type -> what an item of it is
SCRIPTS = {
    ["Base.Pistol"] = {cls = "HandWeapon", ranged = true, ammo = "Base.Bullets9mm", mag = "Base.9mmClip", box = "Base.Bullets9mmBox", max = 15, cat = "Weapon"},
    ["Base.Shotgun"] = {cls = "HandWeapon", ranged = true, ammo = "Base.ShotgunShells", box = "Base.ShotgunShellsBox", max = 6, cat = "Weapon"},
    ["Base.Axe"] = {cls = "HandWeapon", cat = "Weapon"},
    ["Base.9mmClip"] = {ammo = "Base.Bullets9mm", max = 15, cat = "Ammo", scriptAmmo = true},
    ["Base.Bullets9mm"] = {cat = "Ammo"},
    ["Base.Bullets9mmBox"] = {cat = "Ammo"},
    ["Base.ShotgunShells"] = {cat = "Ammo"},
    ["Base.ShotgunShellsBox"] = {cat = "Ammo"},
    ["Base.308Bullets"] = {cat = "Ammo"},
    ["Base.Laser"] = {cls = "WeaponPart", part = "Laser", on = {"Base.Pistol"}, cat = "WeaponPart"},
    ["Base.Sling"] = {cls = "WeaponPart", part = "Sling", on = {}, cat = "WeaponPart"},
    ["Base.Beans"] = {cat = "Food"},
}

local Item = {}
Item.__index = Item
local nextId = 1
function Item:getFullType() return self.ft end
function Item:getID() return self.id end
function Item:getContainer() return self.container end
function Item:getDisplayCategory() return SCRIPTS[self.ft].cat end
function Item:getAmmoType()
    local key = SCRIPTS[self.ft].ammo
    return key and {getItemKey = function() return key end} or nil
end
function Item:getMaxAmmo() return SCRIPTS[self.ft].max or 0 end
function Item:getCurrentAmmoCount() return self.n or 0 end
function Item:getMagazineType() return SCRIPTS[self.ft].mag end
function Item:getAmmoBox() return SCRIPTS[self.ft].box end
function Item:isContainsClip() return self.clip == true end
function Item:isJammed() return self.jam == true end
function Item:haveChamber() return SCRIPTS[self.ft].chamber ~= false end   -- (the game: true unless a script says not)
function Item:isRoundChambered() return self.chambered == true end
function Item:getWeaponPart(t) return self.parts and self.parts[t] or nil end
function Item:isBroken() return self.broken == true end
function Item:getMountOn() return list(SCRIPTS[self.ft].on or {}) end
function Item:getPartType() return SCRIPTS[self.ft].part end
function Item:getGunType() return list({}) end

--- A new item of type `ft` (fields: n rounds, clip, jam...), in container `c`.
function newItem(ft, c, fields)
    local it = setmetatable({ft = ft, cls = SCRIPTS[ft].cls, id = nextId}, Item)
    nextId = nextId + 1
    for k, v in pairs(fields or {}) do it[k] = v end
    if c then c:add(it) end
    return it
end
INSTANCED = 0
function instanceItem(ft)
    INSTANCED = INSTANCED + 1
    return newItem(ft)
end

local Container = {}
Container.__index = Container
function Container:add(it)
    if it.container then it.container:remove(it) end
    table.insert(self.items, it)
    it.container = self
end
function Container:remove(it)
    for i, x in ipairs(self.items) do
        if x == it then table.remove(self.items, i) return end
    end
end
function Container:getAllTypeRecurse(t)
    local out = {}
    local function walk(c)
        for _, it in ipairs(c.items) do
            if it.ft == t then table.insert(out, it) end
            if it.inner then walk(it.inner) end
        end
    end
    walk(self)
    return list(out)
end
function Container:getCountType(t)
    local n = 0
    for _, it in ipairs(self.items) do if it.ft == t then n = n + 1 end end
    return n
end
function Container:isInCharacterInventory(player)
    local c = self
    for _ = 1, 8 do
        if c == player.inv then return true end
        local holder = c.holder
        if not holder then return false end
        c = holder.container
    end
    return false
end
function newContainer(name) return setmetatable({items = {}, name = name}, Container) end

INV = newContainer("main")
BAG = newContainer("bag")
local bagItem = newItem("Base.Beans", INV)   -- (a bag: an item holding a container)
bagItem.inner, BAG.holder = BAG, bagItem
FLOOR = newContainer("floor")
PLAYER.inv = INV
function PLAYER:getInventory() return INV end

local function script(ft)
    local s = SCRIPTS[ft]
    return {getFullName = function() return ft end, isRanged = function() return s.ranged == true end,
            getItemType = function() return s.cls == "WeaponPart" and "base:weaponpart" or "base:normal" end,
            getAmmoType = function()
                if not s.scriptAmmo and not s.ranged then return nil end
                return s.ammo and {getItemKey = function() return s.ammo end} or nil
            end}
end
local scripts = {}
for ft in pairs(SCRIPTS) do table.insert(scripts, script(ft)) end
table.sort(scripts, function(a, b) return a.getFullName() < b.getFullName() end)

RECIPES = {OpenBoxOfBullets50 = {"Base.Bullets9mmBox"}, OpenBoxOfShotgunShells = {"Base.ShotgunShellsBox"}}
function getScriptManager()
    return {getAllItems = function() return list(scripts) end,
            getCraftRecipe = function(_, name)
                local takes = RECIPES[name]
                if not takes then return nil end
                return {name = name, getInputs = function()
                    return list({{canUseItem = function(_, it)
                        for _, t in ipairs(takes) do if it.ft == t then return true end end
                        return false
                    end}})
                end}
            end}
end

-- the game's actions: written down
DONE = {}
local function did(...) table.insert(DONE, {...}) end
ISTimedActionQueue = {add = function(a) did("queue", a.name, a) end}
ISInventoryTransferUtil = {newInventoryTransferAction = function(_, it, from, to)
    return {name = "move", item = it, from = from, to = to}
end}
local function action(name)
    return {new = function(_, player, a, b) return {name = name, a = a, b = b} end}
end
ISLoadBulletsInMagazine = action("loadMag")
ISUnloadBulletsFromMagazine = action("unloadMag")
ISEjectMagazine = action("eject")
ISInsertMagazine = action("insert")
ISInventoryPaneContextMenu = {
    equipWeapon = function(gun) did("equip", gun) end,
    onEjectMagazine = function(_, gun) did("ejectMenu", gun) end,
    onRackGun = function(_, gun) did("rack", gun) end,
    onLoadBulletsIntoFirearm = function(_, gun) did("loadGun", gun) end,
    onUnloadBulletsFromFirearm = function(_, gun) did("unloadGun", gun) end,
    OnNewCraft = function(it, recipe) did("craft", it, recipe.name) end,
}

-- the grids on the screen: one view per container
VIEWS = {}
function viewOf(c)
    local v = {layout = {placed = {}}, markDirty = function() end, container = c}
    table.insert(VIEWS, v)
    return v
end
--- The grid's tiles again from the containers' items (each item a tile of its own,
--- rounds of one type in one container one stack).
function layoutAll()
    for _, v in ipairs(VIEWS) do
        local placed, stacks = {}, {}
        for _, it in ipairs(v.container.items) do
            local e = stacks[it.ft]
            if e and SCRIPTS[it.ft].cat == "Ammo" and not SCRIPTS[it.ft].max then
                table.insert(e.items, it)
            else
                e = {item = it, items = {it}}
                stacks[it.ft] = e
                table.insert(placed, e)
            end
        end
        v.layout.placed = placed
    end
end
KnoxActions = {allViews = function() return VIEWS end}
KnoxScreen = {instance = {playerNum = 0, loot = {containers = {{container = FLOOR}}}}}
