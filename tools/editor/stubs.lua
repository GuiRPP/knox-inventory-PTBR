-- What KnoxEditor.lua touches, outside the game (tools/editor/test.ps1), on top of
-- tools/settings/stubs.lua (fonts, ISPanel, the screen, the mouse): files kept in
-- memory (Zomboid/Lua and the mod's folder), the game's scripts of a few items and
-- things made of them, the text box, the clipboard, the Java part's file list.

-- files: name -> text ("\r\n" between lines)
FILES, MODFILES = {}, {}
local function reader(store, name)
    local s = store[name]
    if not s then return nil end
    local lines = {}
    for l in string.gmatch(s, "([^\r\n]*)\r?\n") do table.insert(lines, l) end
    local i = 0
    return {readLine = function() i = i + 1 return lines[i] end, close = function() end}
end
local function writer(store, name, append)
    local buf = append and (store[name] or "") or ""
    store[name] = store[name] or ""
    return {write = function(_, s) buf = buf .. s end, close = function() store[name] = buf end}
end
function getFileReader(name) return reader(FILES, name) end
function getFileWriter(name, _, append) return writer(FILES, name, append) end
function getModFileReader(_, name) return reader(MODFILES, name) end
function getModFileWriter(_, name, _, append) return writer(MODFILES, name, append) end
function knoxPresetFiles()
    local out = {}
    for name, s in pairs(FILES) do
        local f = string.match(name, "^knox_presets/([^/]+%.txt)$")
        if f and s ~= "" then table.insert(out, f .. "\t25.10\n") end
    end
    table.sort(out)
    return table.concat(out)
end
function knoxPresetDelete(name)
    if not FILES["knox_presets/" .. name] then return false end
    FILES["knox_presets/" .. name] = nil
    return true
end
-- (the player's own lines before the presets: moved into "My preset" at load)
FILES["knox_overrides.txt"] = "# notes\r\nshow_ids = no\r\nBase.Axe = 1x3\r\n"

CLIP = ""
Clipboard = {getClipboard = function() return CLIP end, setClipboard = function(s) CLIP = s end}
CTRL = false
function isCtrlKeyDown() return CTRL end
function getModInfoByID(id) return {getName = function() return "Mod " .. id end} end
function instanceof(obj, class)
    return type(obj) == "table" and obj.classes ~= nil and obj.classes[class] == true
end
Keyboard.KEY_Z = 44

-- the game's items: {ft, name, mod, cat (display category), kind, worn, cap}
ItemType = {CONTAINER = "CONTAINER", CLOTHING = "CLOTHING", WEAPON = "WEAPON", FOOD = "FOOD", LITERATURE = "LITERATURE", KEY = "KEY"}
SCRIPTS = SCRIPTS or {   -- (the offline shots bring a longer list of their own)
    {ft = "Base.Bag_Schoolbag", name = "School Bag", kind = "CONTAINER", equip = "Back", cap = 15},
    {ft = "Base.Bag_ALICEpack", name = "Large Backpack", kind = "CONTAINER", equip = "Back", cap = 28},
    {ft = "Base.Bag_FannyPackFront", name = "Fanny Pack", kind = "CONTAINER", equip = "FannyPackFront", cap = 1},
    {ft = "Base.Toolbox", name = "Toolbox", kind = "CONTAINER", cap = 10},
    {ft = "Base.Jacket_Padded", name = "Padded Jacket", kind = "CLOTHING", worn = "Jacket"},
    {ft = "Base.Jacket_Black", name = "Black Jacket", kind = "CLOTHING", worn = "Jacket"},
    {ft = "Base.Tshirt_White", name = "T-Shirt", kind = "CLOTHING", worn = "Tshirt"},
    {ft = "Base.Trousers_Denim", name = "Jeans", kind = "CLOTHING", worn = "Pants"},
    {ft = "Base.Axe", name = "Axe", kind = "WEAPON", cat = "Weapon", weapon = true},
    {ft = "Base.Pistol", name = "Pistol", kind = "WEAPON", cat = "Weapon", weapon = true},
    {ft = "Base.Bullets9mm", name = "9mm Rounds", cat = "Ammo"},
    {ft = "Base.Nails", name = "Nails", cat = "Material"},
    {ft = "Base.TinnedBeans", name = "Beans", kind = "FOOD", cat = "Food", food = true},
    {ft = "Base.Bandage", name = "Bandage", cat = "FirstAid"},
    {ft = "Base.Hammer", name = "Hammer", cat = "Tool", weapon = true},
    {ft = "Base.Book", name = "Book", kind = "LITERATURE", cat = "Literature"},
    {ft = "Base.Pen", name = "Pen"},
    {ft = "Base.Hidden", name = "Hidden", hidden = true},
    {ft = "TG.TacticalPack", name = "Tactical Pack", mod = "TacticalGear", kind = "CONTAINER", equip = "Back", cap = 22},
    {ft = "TG.Vest", name = "Tactical Vest", mod = "TacticalGear", kind = "CLOTHING", worn = "TorsoExtraVest"},
    {ft = "TG.Knife", name = "Tactical Knife", mod = "TacticalGear", kind = "WEAPON", cat = "Weapon", weapon = true},
}
local byFt = {}
local function script(d)
    local sc = {d = d}
    function sc:getFullName() return self.d.ft end
    function sc:getDisplayName() return self.d.name end
    function sc:getModID() return self.d.mod or "pz-vanilla" end
    function sc:isHidden() return self.d.hidden == true end
    function sc:getObsolete() return false end
    function sc:getDisplayCategory() return self.d.cat end
    function sc:isItemType(t) return self.d.kind == t end
    function sc:getCanBeEquipped() return self.d.equip end
    function sc:getBodyLocation() return self.d.worn end
    function sc:getNormalTexture() return {tex = self.d.ft} end
    return sc
end
for _, d in ipairs(SCRIPTS) do byFt[d.ft] = script(d) end
local function jlist(t)
    return {size = function() return #t end, get = function(_, i) return t[i + 1] end}
end
ScriptManager = {instance = {
    getAllItems = function()
        local t = {}
        for _, d in ipairs(SCRIPTS) do table.insert(t, byFt[d.ft]) end
        return jlist(t)
    end,
    getItem = function(_, ft) return byFt[ft] end,
}}
function getScriptManager() return {getModelScript = function() return nil end} end
function knoxMeasureModel() return nil end

local thingMeta = {__index = function() return function() return nil end end}
MADE = 0
function instanceItem(ft)
    local sc = byFt[ft]
    if not sc then return nil end
    MADE = MADE + 1
    local d = sc.d
    local it = setmetatable({classes = {InventoryItem = true}}, thingMeta)
    if d.kind == "CONTAINER" then it.classes.InventoryContainer = true end
    if d.kind == "CLOTHING" then it.classes.Clothing = true end
    if d.weapon then it.classes.HandWeapon = true end
    if d.food then it.classes.Food = true end
    if d.kind == "LITERATURE" then it.classes.Literature = true end
    function it.getFullType() return ft end
    function it.getType() return string.gsub(ft, "^.*%.", "") end
    function it.getDisplayName() return d.name end
    function it.getDisplayCategory() return d.cat end
    function it.getBodyLocation() return d.worn end
    function it.canBeEquipped() return d.equip end
    function it.getConditionMax() return 0 end
    function it.getCondition() return 0 end
    function it.getWeight() return 0.5 end
    function it.getActualWeight() return 0.5 end
    function it.getUnequippedWeight() return 0.5 end
    function it.getModData() return {} end
    function it.hasModData() return false end
    function it.getAttachedSlot() return -1 end
    function it.getMaxAmmo() return 0 end
    function it.getCurrentAmmoCount() return 0 end
    function it.isTwoHandWeapon() return false end
    function it.isRanged() return false end
    function it.isRoundChambered() return false end
    function it.getAllWeaponParts() return jlist({}) end
    function it.getDirtyness() return 0 end
    function it.getBloodlevel() return 0 end
    function it.getWetness() return 0 end
    function it.getHolesNumber() return 0 end
    function it.hasTag() return false end
    function it.getPoisonPower() return 0 end
    function it.isFresh() return true end
    function it.isRotten() return false end
    function it.isCooked() return false end
    function it.isBurnt() return false end
    if d.cap then
        local inv = {getCapacity = function() return d.cap end, getItems = function() return jlist({}) end,
                     isEmpty = function() return true end, getCapacityWeight = function() return 0 end}
        function it.getInventory() return inv end
    end
    return it
end

-- the game's text box: as far as the editor uses it
ISTextEntryBox = {}
ISTextEntryBox.__index = ISTextEntryBox
function ISTextEntryBox:new(text)
    local o = setmetatable({text = text or "", visible = true, focused = false, javaObject = {
        setFont = function() end, setCentreVertically = function() end}}, self)
    return o
end
for _, k in ipairs({"initialise", "instantiate", "setClearButton", "setTextRGBA", "setPlaceholderText", "setPlaceholderTextRGBA"}) do
    ISTextEntryBox[k] = function() end
end
function ISTextEntryBox:setText(s) self.text = s end
function ISTextEntryBox:getText() return self.text end
function ISTextEntryBox:focus() self.focused = true end
function ISTextEntryBox:unfocus() self.focused = false end
function ISTextEntryBox:isFocused() return self.focused end
function ISTextEntryBox:setVisible(v) self.visible = v end
function ISTextEntryBox:getIsVisible() return self.visible end
function ISTextEntryBox:setX(x) self.x = x end
function ISTextEntryBox:setY(y) self.y = y end
function ISTextEntryBox:setWidth(w) self.w = w end
function ISTextEntryBox:setHeight(h) self.h = h end
function ISPanel:drawTextureScaledAspect() DRAWN = DRAWN + 1 end
-- (the item's menu: the editor's option caught)
Events.OnFillInventoryObjectContextMenu = {Add = function(f) MENU_FN = f end, Remove = function() end}
