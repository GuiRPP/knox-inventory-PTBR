-- Every context menu of the game in Knox's look (the mockup's "Context menu"):
-- dark plate with a frame and a shadow, rows with a dark highlight and a sand
-- strip on the left, icons in their own column, chevrons for sub menus.
--
-- Knox's own menu (the author's task for 1.0, 2026-10-18, mockup v1): an item's
-- menu says what it is about on top, its options stand in groups under caps
-- labels, what throws or pours away stands at the bottom in red; a short sub
-- menu (eat all / half / quarter) is chips on its own row; the click or key
-- that does the same on the tile stands at the right; an option that can't be
-- chosen says why under its name.
--
-- The options stay the game's list in the game's order - the game, other mods
-- and the mouse and gamepad code find them by name and index - and the sub menu
-- logic stays the game's; only where each option is drawn changes: a layout of
-- rows maps the list onto the plate. `self.font` stays a game UIFont (other
-- code may measure with it); Knox's font is `knoxFont`.

require "ISUI/ISContextMenu"
require "Knox/KnoxTheme"

KnoxContextMenu = {}
local K = KnoxContextMenu
local T = KnoxTheme

local RED = {r = 0xd9 / 255, g = 0x8a / 255, b = 0x7c / 255}     -- "Выбросить" in the mockup
local HOVER = {r = 0x23 / 255, g = 0x27 / 255, b = 0x2a / 255}
local EDGE = {r = 0x4a / 255, g = 0x4f / 255, b = 0x4f / 255}    -- window frame

-- the game reads Lua files as single bytes: characters beyond ASCII go through string.char
local TIMES = string.char(215)   -- ×

-- the game's "context menu font" option scales the menu
local function sizeScale()
    local f = getCore():getOptionContextMenuFont()
    if f == "Large" then return 1.15 elseif f == "Small" then return 0.9 end
    return 1
end

--- Sizes and font of a menu, from the cell size.
function K.apply(menu)
    T.ensure()
    local c, s = T.cell, sizeScale()
    if T.javaFonts then
        menu.knoxFont = T.makeFont("body", c * 0.31 * s)
    else
        menu.knoxFont = menu.font or UIFont.Medium
    end
    menu.fontHgt = T.fontH(menu.knoxFont)
    menu.itemHgt = math.max(menu.fontHgt + 8, math.floor(c * 0.67 * s + 0.5))
    menu.padTopBottom = math.max(3, math.floor(c / 12))
    menu.knoxPadX = math.floor(c * 0.25 + 0.5)
    menu.knoxIcon = math.floor(c * 0.36 * s + 0.5)
    menu.knoxGap = math.floor(c * 0.21 + 0.5)
    menu.knoxArrow = math.max(3, math.floor(menu.fontHgt / 5))
    menu.scrollIndicatorHgt = math.max(14, math.floor(c * 0.3))
    menu.knoxCell = c
end

local function ensure(menu)
    if not menu.knoxFont or menu.knoxCell ~= T.cell then
        K.apply(menu)
        menu:calcHeight()
    end
end

local function hasIcon(option)
    return option.knoxIcon ~= nil or option.iconTexture ~= nil or option.itemForTexture ~= nil or option.color ~= nil or option.checkMark
end

--- x of the option names: after the icon column when any option has one.
local function textX(menu)
    for _, k in ipairs(menu.options) do
        if hasIcon(k) then return menu.knoxPadX + menu.knoxIcon + menu.knoxGap end
    end
    return menu.knoxPadX
end

-- Chevron of two 2px lines; dir: 1 right, -1 left, 2 up, -2 down. (x, y) is
-- the tip's base corner, s the half size.
local function chevron(ui, x, y, s, dir, c, a)
    for i = 0, s do
        if dir == 1 then
            ui:drawRect(x + i, y - s + i, 2, 2, a or 1, c.r, c.g, c.b)
            ui:drawRect(x + i, y + s - i, 2, 2, a or 1, c.r, c.g, c.b)
        elseif dir == -1 then
            ui:drawRect(x + s - i, y - s + i, 2, 2, a or 1, c.r, c.g, c.b)
            ui:drawRect(x + s - i, y + s - i, 2, 2, a or 1, c.r, c.g, c.b)
        elseif dir == 2 then
            ui:drawRect(x - i, y + i, 2, 2, a or 1, c.r, c.g, c.b)
            ui:drawRect(x + i, y + i, 2, 2, a or 1, c.r, c.g, c.b)
        else
            ui:drawRect(x - i, y + s - i, 2, 2, a or 1, c.r, c.g, c.b)
            ui:drawRect(x + i, y + s - i, 2, 2, a or 1, c.r, c.g, c.b)
        end
    end
end

-- Target of the open menu ---------------------------------------------------------
-- Knox's tiles and slots that open a menu name its items here; while the menu
-- is up they draw a sand highlight, so it's clear what the menu is about. The
-- menu opened right after takes them for its header (see ISContextMenu:clear).

K.target = nil   -- {items = {item = true}, list = {item...}, playerNum, ms, pending}

function K.setTarget(items, playerNum)
    local set = {}
    for _, it in ipairs(items or {}) do set[it] = true end
    K.target = {items = set, list = items or {}, playerNum = playerNum or 0, ms = getTimestampMs(), pending = true}
end

function K.isTarget(item)
    local t = K.target
    if not t or not item or not t.items[item] then return false end
    local menu = getPlayerContextMenu(t.playerNum)
    if menu and menu:isAnyVisible() then return true end
    K.target = nil   -- the menu is closed
    return false
end

--- Highlight of a menu's item: sand frame 2 px and a light sand tint.
function K.drawTarget(ui, x, y, w, h)
    local c = T.color.accent
    ui:drawRect(x, y, w, h, 0.14, c.r, c.g, c.b)
    T.border(ui, x, y, w, h, c)
    T.border(ui, x + 1, y + 1, w - 2, h - 2, c)
end

-- A titled menu ----------------------------------------------------------------------
-- A menu about something that is not an item (the health tab's body part): the
-- next menu of this player made within a second gets this header - the world
-- menu's plate, its icon in a cell, the title and a line under it - and the sand
-- frame; its options stay as they came. color: the title's (the part's state).
K.titled = nil   -- {playerNum, title, sub, icon (a Knox icon name) | tex, color, ms, pending}

function K.setTitle(playerNum, title, sub, icon, color, tex)
    K.titled = {playerNum = playerNum or 0, title = title, sub = sub, icon = icon, tex = tex, color = color,
                ms = getTimestampMs(), pending = true}
end

--- The option under the mouse in any open menu (last frame), and its menu.
function K.hoveredOption()
    local h = K.hover
    if not h or getTimestampMs() - h.ms > 150 or not h.menu:isVisible() then return nil end
    return h.option, h.menu
end

-- without the Java part the game's menus stay as they are (see KnoxTheme.active)
if not T.on("menus") then return KnoxContextMenu end

-- The world's menu: made by ISWorldObjectContextMenu.createMenu (a right click on
-- the world); the menu made right after is about that square (see ISContextMenu:clear).
require "ISUI/ISWorldObjectContextMenu"
K.world = nil   -- {playerNum, square, ground (things lying there), ms, pending}
if ISWorldObjectContextMenu and ISWorldObjectContextMenu.createMenu and not ISWorldObjectContextMenu.knoxMarked then
    ISWorldObjectContextMenu.knoxMarked = true
    local createMenu = ISWorldObjectContextMenu.createMenu
    ISWorldObjectContextMenu.createMenu = function(player, worldobjects, x, y, test, ...)
        if not test and type(player) == "number" then
            local sq, ground = nil, 0
            pcall(function()
                for _, o in ipairs(worldobjects or {}) do
                    if o and o.getSquare and o:getSquare() then
                        sq = o:getSquare()
                        break
                    end
                end
                if sq then ground = sq:getWorldObjects():size() end
            end)
            K.world = {playerNum = player, square = sq, ground = ground, ms = getTimestampMs(), pending = true}
        end
        local a, b, c = createMenu(player, worldobjects, x, y, test, ...)
        -- (not taken by the time it is built: no world menu was made - no other
        -- menu opened soon after may take it)
        if K.world then K.world.pending = false end
        return a, b, c
    end
end

-- Groups ----------------------------------------------------------------------------
-- The game's item actions by group, known by their functions (any language;
-- a name without a table is ISInventoryPaneContextMenu's). An option that only
-- opens a sub menu (Eat, Move to) is known by its name, or else by the first
-- known option of its sub menu. Everything else - recipes, other mods' options,
-- Knox's "Inspect" - is "other", in the game's order.

local GROUPS = {"use", "equip", "move", "craft", "other", "danger"}
local GROUP_TITLE = {use = "IGUI_Knox_MenuUse", equip = "IGUI_Knox_MenuEquip", move = "IGUI_Knox_MenuMove",
                     craft = "IGUI_Knox_MenuCraft", other = "IGUI_Knox_MenuOther"}

local BY_FN = {
    use = {"onEatItems", "onDrinkFluid", "onDrinkForThirst", "onLiteratureItems", "onMediaText", "onCheckMap",
           "onInsertMagazine", "onEjectMagazine", "onUnloadBulletsFromMagazine", "onSetAlarm", "onStopAlarm",
           "onMakeUp", "onDyeHair", "onDryMyself", "onWringClothing", "takePill", "onPillsItems", "onConsolidateAll",
           "ISFluidContainerMenu.showInfo", "ISFluidContainerMenu.transferFluids", "AutoDrinkOn", "AutoDrinkOff"},
    equip = {"OnPrimaryWeapon", "OnSecondWeapon", "OnTwoHandsEquip", "onWearItems", "onUnEquip",
             "equipHeavyItem", "grabCorpseItem", "ISHotbar.removeItem", "ISHotbar.attachItem"},
    move = {"onGrabItems", "onGrabOneItems", "onGrabHalfItems", "onMoveItemsTo", "onPutItems",
            "onPlaceItemOnGround", "ISInventoryPage.transferAll", "ISInventoryPage.lootAll"},
    craft = {"OnCraft", "onResearchRecipe"},
    danger = {"onDropItems", "onDumpContents", "ISFluidContainerMenu.emptyFluidContainer"},
}
local BY_TEXT = {
    use = {"ContextMenu_Eat", "ContextMenu_OpenAndEat", "ContextMenu_Drink", "ContextMenu_OpenAndDrink"},
    equip = {"ContextMenu_Wear", "ContextMenu_Attach"},
    move = {"ContextMenu_Move_To", "ContextMenu_PlaceItemOnGround"},
    craft = {"ContextMenu_ShowCraftRecipesUsed"},
}

-- On top of an item's menu, without a title, what is used most (the author,
-- 2026-10-18: "the most used ones up"): "Inspect", the item's main action - what
-- a double click on its tile does (eat, wear, read, take in hand); a weapon's:
-- "Attach to" - then the item's own actions (its recipes: "Rip", "Interact").
-- (taking into a hand is not one: "main hand" on top and "off hand" in the group
-- below stood apart - the author, 2026-10-18; both stay together in their group)
local MAIN_FN = {"onEatItems", "onDrinkFluid", "onDrinkForThirst", "onLiteratureItems", "onPillsItems", "onWearItems", "onUnEquip",
                 "ISHotbar.removeItem"}
local MAIN_TEXT = {"ContextMenu_Eat", "ContextMenu_OpenAndEat", "ContextMenu_Drink", "ContextMenu_OpenAndDrink",
                   "ContextMenu_Read", "ContextMenu_Wear", "ContextMenu_Take_pills"}

-- "Put in the container" is gone from Knox's menus (the author, 2026-10-18):
-- Shift / the drag do it
local HIDDEN_FN = {"onPutItems"}

-- The world's menu (the author, 2026-10-18: "the same as the inventory's"; the
-- mockup's choices: objects on top, groups with titles, the dangerous in red at
-- the bottom, a header for the place - and the objects' sub menus the same, under
-- the object's header). Known by the options' names (the world's menu builds
-- them in many files); "%1" in a name is matched by what comes before it. An
-- option opening a sub menu that holds any of these is one of the place's objects
-- (the sink, the curtains); a sub menu holding none of them (another mod's) is "Other".
local WORLD_GROUPS = {"act", "use", "move", "build", "other", "danger"}
local OBJECT_GROUPS = {"use", "act", "move", "build", "other", "danger"}
local WORLD_TITLE = {act = "IGUI_Knox_MenuActions", use = "IGUI_Knox_MenuUse", move = "IGUI_Knox_MenuMove",
                     build = "IGUI_Knox_MenuBuild", other = "IGUI_Knox_MenuOther"}
local WORLD_TEXT = {
    act = {"ContextMenu_Walk_to", "ContextMenu_SitGround", "ContextMenu_SleepOnGround", "ContextMenu_Sleep",
           "ContextMenu_Rest", "ContextMenu_Climb_over"},
    use = {"Fluid_Show_Info", "Fluid_Transfer_Fluids", "ContextMenu_Drink", "ContextMenu_Fill", "ContextMenu_FillOne",
           "ContextMenu_FillAll", "ContextMenu_RefillContainer", "ContextMenu_Wash", "ContextMenu_Turn_On", "ContextMenu_Turn_Off",
           "ContextMenu_StoveSetting",
           -- (a generator's own, the author 2026-10-22: in the main list, not under "Other")
           "ContextMenu_GeneratorInfo", "ContextMenu_GeneratorPlug", "ContextMenu_GeneratorUnplug", "ContextMenu_GeneratorAddFuel",
           "ContextMenu_GeneratorFix",
           "ContextMenu_Open_window", "ContextMenu_Close_window", "ContextMenu_Open_curtains", "ContextMenu_Close_curtains", "ContextMenu_Remove_curtains",
           "ContextMenu_Open_door", "ContextMenu_Close_door", "ContextMenu_LockDoor", "ContextMenu_UnlockDoor",
           "ContextMenu_Lock_Doors", "ContextMenu_Unlock_Doors", "ContextMenu_OpenLid", "ContextMenu_CloseLid",
           "ContextMenu_Light_fire", "ContextMenu_Put_out_fire", "ContextMenu_ExtinguishFire", "ContextMenu_StopAlarm",
           "ContextMenu_Inspect", "ContextMenu_InspectTrack", "ContextMenu_RemoveDirt", "ContextMenu_RemoveBlood",
           "ContextMenu_Vehicle_Openwindow", "ContextMenu_Vehicle_Closewindow"},
    move = {"ContextMenu_Grab", "ContextMenu_Grab_one", "ContextMenu_Grab_half", "ContextMenu_Grab_all", "ContextMenu_Grab_Corpse",
            "ContextMenu_GeneratorTake", "ContextMenu_Take_Bottle", "ContextMenu_TakeBricks", "ContextMenu_TakeHay",
            "ContextMenu_TakeLogs", "ContextMenu_PickupBrokenGlass"},
    build = {"ContextMenu_Dismantle", "ContextMenu_Disassemble", "ContextMenu_Remove", "ContextMenu_Remove_escape_rope",
             "ContextMenu_Remove_Bait", "ContextMenu_Remove_Trap", "ContextMenu_RemoveCharcoal", "ContextMenu_Remove_Logs",
             "ContextMenu_Clear_Ashes", "ContextMenu_Pickup_Branch", "ContextMenu_Pickup_Stone", "ContextMenu_Pickup_Stones",
             "ContextMenu_Pickup_Twigs", "ContextMenu_Pickup_Log", "ContextMenu_Remove_GroundItem"},
    danger = {"ContextMenu_Destroy", "ContextMenu_DestroyFloor", "ContextMenu_Smash_window", "ContextMenu_Vehicle_Smashwindow"},
}

-- a recipe's icon by what it does (the game's internal names are CamelCase: a
-- capital marks a word - "Rip" is not in "Strips"), else by its category
local RECIPE_ICON = {
    {"Rip", "rip"}, {"Tear", "rip"}, {"Rope", "rope"}, {"Bag", "bag"}, {"Sack", "bag"}, {"Satchel", "bag"},
    {"Backpack", "bag"}, {"Open", "open"}, {"Dismantle", "dismantle"}, {"Disassemble", "dismantle"},
    {"Salvage", "dismantle"}, {"Scrap", "dismantle"}, {"Sharpen", "repair"}, {"Repair", "repair"}, {"Fix", "repair"},
    {"Sew", "sew"}, {"Patch", "sew"}, {"Stitch", "sew"}, {"Cook", "cook"}, {"Bake", "cook"}, {"Fry", "cook"},
    {"Boil", "cook"}, {"Roast", "cook"}, {"Bandage", "bandage"}, {"Pour", "pour"}, {"Fill", "drink"},
}
local RECIPE_CAT = {Cooking = "cook", Tailoring = "sew", Medical = "bandage", Packing = "bag"}

-- a sub menu made of these becomes chips on its row (the first one is the row's own click)
-- each is drawn as a sand square filled that far (the author, 2026-10-18: "a
-- part of a cube, half a cube, a whole cube" - text chips stood out)
local CHIP_TEXT = {ContextMenu_Eat_All = 1, ContextMenu_Eat_Half = 0.5, ContextMenu_Eat_Quarter = 0.25,
                   ContextMenu_PlaceAll = 1, ContextMenu_PlaceHalf = 0.5, ContextMenu_PlaceOne = 0.25}

-- Knox's own icons for the game's options (media/ui/knoxicons/menu_<name>.png,
-- tools/make_menu_icons.ps1): white lines tinted as the row (2026-10-18, the
-- author: one style for every option). By the option's name first (the same
-- function opens "Unpack" and "Move to"), then its function, then a sub menu's
-- first known option. Options Knox doesn't know keep their own pictures.
local ICON_TEXT = {
    ContextMenu_Eat = "eat", ContextMenu_OpenAndEat = "eat", ContextMenu_Drink = "drink", ContextMenu_OpenAndDrink = "drink",
    ContextMenu_Wear = "wear", ContextMenu_Smoke = "smoke", ContextMenu_Read = "read", ContextMenu_ReRead = "read", ContextMenu_CheckMap = "map",
    ContextMenu_Apply_Bandage = "bandage", ContextMenu_Bandage = "bandage",
    ContextMenu_InsertBulletsInMagazine = "magazine", ContextMenu_InsertBullets = "magazine",
    ContextMenu_UnloadRounds = "magazine", ContextMenu_EjectMagazine = "magazine", ContextMenu_InsertMagazine = "magazine",
    IGUI_DeviceOptions = "device", ContextMenu_Attach = "attach",
    ContextMenu_Grab = "grab", ContextMenu_Grab_one = "grab", ContextMenu_Grab_half = "grab", ContextMenu_Grab_all = "grab",
    ContextMenu_Move_To = "move", ContextMenu_Unpack = "unpack", ContextMenu_PlaceItemOnGround = "place",
    IGUI_invpage_Transfer_all = "all", IGUI_invpage_Loot_all = "all",
    Fluid_Show_Info = "fluid_info", Fluid_Transfer_Fluids = "fluid_move",
    IGUI_Knox_Inspect = "inspect", IGUI_invpanel_Inspect = "inspect", ContextMenu_Inspect = "inspect",
    ContextMenu_More = "more", ContextMenu_RenameBag = "rename", IGUI_CraftUI_Favorite = "star", ContextMenu_Unfavorite = "star",
    ContextMenu_ShowCraftRecipesUsed = "recipes", ContextMenu_Repair = "repair",
    ContextMenu_Patch = "sew", ContextMenu_PatchHole = "sew", ContextMenu_AddPadding = "sew", ContextMenu_RemovePatch = "sew",
    IGUI_Knox_Order_Sort = "sort",
    -- a watch's wrists: the hotbar's hands
    -- (the outline hands, as the other icons - the hotbar's are filled: the author, 2026-10-18)
    ContextMenu_LeftWrist = "hand_off", ContextMenu_RightWrist = "hand_main",
    -- Neat Crafting, Neat Building
    IGUI_NC_SearchForCraft = "craft_search", IGUI_NB_BuildingSearch = "build_search",
    -- the world's menu: a sink's washing, the ground (2026-10-18, the author: no icons)
    ContextMenu_Wash = "wash", ContextMenu_Yourself = "wash_self", ContextMenu_WashAllClothing = "wash_clothes",
    ContextMenu_WashAllContainer = "wash_containers", ContextMenu_WashAllWeapon = "wash_weapons",
    ContextMenu_SleepOnGround = "sleep", ContextMenu_Sleep = "sleep", ContextMenu_SitGround = "sit",
    ContextMenu_Walk_to = "walk", ContextMenu_PickupBrokenGlass = "glass",
    ContextMenu_Fill = "fill", ContextMenu_FillOne = "fill", ContextMenu_FillAll = "fill", ContextMenu_RefillContainer = "fill",
    ContextMenu_Rest = "rest", ContextMenu_Open_window = "window", ContextMenu_Close_window = "window",
    ContextMenu_Open_curtains = "curtains", ContextMenu_Close_curtains = "curtains", ContextMenu_Remove_curtains = "curtains_off",
    ContextMenu_Open_door = "door", ContextMenu_Close_door = "door",
    ContextMenu_LockDoor = "lock", ContextMenu_UnlockDoor = "lock", ContextMenu_Lock_Doors = "lock", ContextMenu_Unlock_Doors = "lock",
    ContextMenu_Smash_window = "smash", ContextMenu_Destroy = "smash", ContextMenu_DestroyFloor = "smash",
    ContextMenu_Turn_On = "light", ContextMenu_Turn_Off = "light",
    -- (the author, 2026-10-22: a lamp's bulb, a stove's settings and a grid's header menu had none)
    ContextMenu_RemoveLightbulb = "bulb_out", ContextMenu_AddLightbulb = "bulb_in", ContextMenu_StoveSetting = "device",
    -- (the author, 2026-10-22: a generator's options had none)
    ContextMenu_GeneratorInfo = "device", ContextMenu_GeneratorPlug = "plug_in", ContextMenu_GeneratorUnplug = "plug_out",
    ContextMenu_GeneratorAddFuel = "fill", ContextMenu_GeneratorFix = "repair", ContextMenu_GeneratorTake = "grab",
    -- (the author, 2026-10-22: the ground's gardening and an item's "unwanted" had none)
    ContextMenu_Gardening = "garden", ContextMenu_Unwanted = "unwanted",
    IGUI_Knox_Order_Rule = "sort_rule", IGUI_Knox_Order_SaveLayout = "layout_save", IGUI_Knox_Order_ForgetLayout = "layout_forget",
    IGUI_Knox_MoveTop = "move_top", IGUI_Knox_MoveUp = "move_up", IGUI_Knox_MoveDown = "move_down",
}
local ICON_FN = {
    onEatItems = "eat", onDrinkFluid = "drink", onDrinkForThirst = "drink", onLiteratureItems = "read", onMediaText = "read",
    onCheckMap = "map", onInsertMagazine = "magazine", onEjectMagazine = "magazine", onUnloadBulletsFromMagazine = "magazine",
    onSetAlarm = "clock", onStopAlarm = "clock", onDryMyself = "dry", onWringClothing = "dry", takePill = "pill", onPillsItems = "pill",
    onConsolidateAll = "merge",
    OnPrimaryWeapon = "hand_main", OnSecondWeapon = "hand_off", OnTwoHandsEquip = "hands",
    -- (the ways to wear a thing - a belt bag in front or behind, a cap's peak:
    -- "Wear"'s sub menu had no icons, the author 2026-10-18)
    onWearItems = "wear", onClothingItemExtra = "wear", onUnEquip = "unequip", equipHeavyItem = "grab", grabCorpseItem = "grab",
    onGrabItems = "grab", onGrabOneItems = "grab", onGrabHalfItems = "grab", onMoveItemsTo = "move", onPutItems = "put",
    onPlaceItemOnGround = "place", ["ISInventoryPage.transferAll"] = "all", ["ISInventoryPage.lootAll"] = "all",
    onDropItems = "drop", onDumpContents = "pour", ["ISFluidContainerMenu.emptyFluidContainer"] = "pour",
    ["ISFluidContainerMenu.showInfo"] = "fluid_info", ["ISFluidContainerMenu.transferFluids"] = "fluid_move",
    onInspectClothing = "inspect", onRenameBag = "rename", onRenameFood = "rename", onRenameMap = "rename",
    onFavorite = "star", OnCraft = "craft", OnNewCraft = "craft", onResearchRecipe = "recipes",
    onAddItemInEvoRecipe = "cook", removePatch = "sew", removeAllPatches = "sew",
    ["ISHotbar.removeItem"] = "unequip", ["ISHotbar.attachItem"] = "attach",
    AutoDrinkOn = "autodrink", AutoDrinkOff = "autodrink",
}

local function fnOf(path)
    local tbl, name = string.match(path, "^([%w_]+)%.([%w_]+)$")
    local t
    if tbl == "ISInventoryPage" then t = ISInventoryPage
    elseif tbl == "ISFluidContainerMenu" then t = ISFluidContainerMenu
    elseif tbl == "ISHotbar" then t = ISHotbar
    else t, name = ISInventoryPaneContextMenu, path end
    return t and t[name]
end

-- built at the first menu: by then every file (and Knox's own patches of them) is loaded
local known
local function knownTables()
    if known then return known end
    known = {group = {}, text = {}, chip = {}, mainFn = {}, mainText = {}, hidden = {}}
    for g, list in pairs(BY_FN) do
        for _, path in ipairs(list) do
            local f = fnOf(path)
            if f then known.group[f] = g end
        end
    end
    for g, list in pairs(BY_TEXT) do
        for _, key in ipairs(list) do known.text[getText(key)] = g end
    end
    for n, path in ipairs(MAIN_FN) do
        local f = fnOf(path)
        if f then known.mainFn[f] = n end
    end
    for _, key in ipairs(MAIN_TEXT) do known.mainText[getText(key)] = true end
    for _, path in ipairs(HIDDEN_FN) do
        local f = fnOf(path)
        if f then known.hidden[f] = true end
    end
    known.craft = fnOf("OnNewCraft")
    known.unhook = fnOf("ISHotbar.removeItem")
    known.unequipText = getText("ContextMenu_Unequip")
    known.attach = getText("ContextMenu_Attach")
    for key, frac in pairs(CHIP_TEXT) do known.chip[getText(key)] = frac end
    known.inspect = getText("IGUI_Knox_Inspect")
    known.take = getText("ContextMenu_GeneratorTake")
    known.iconText, known.iconFn, known.tex = {}, {}, {}
    for key, icon in pairs(ICON_TEXT) do
        local text = getText(key)
        if text ~= key then known.iconText[text] = icon end
    end
    for path, icon in pairs(ICON_FN) do
        local f = fnOf(path)
        if f then known.iconFn[f] = icon end
    end
    -- the world's: by the name, or by what comes before its "%1"
    known.worldText, known.worldPrefix = {}, {}
    for g, list in pairs(WORLD_TEXT) do
        for _, key in ipairs(list) do
            local text = getText(key)
            if text ~= key then
                local pre = string.match(text, "^(.-)%%1")
                if pre then
                    pre = string.gsub(pre, "%s+$", "")
                    if pre ~= "" then table.insert(known.worldPrefix, {pre, g}) end
                else
                    known.worldText[text] = g
                end
            end
        end
    end
    return known
end

local function texOf(icon)
    local kt = knownTables()
    if kt.tex[icon] == nil then
        local path = string.find(icon, "/", 1, true) and icon or ("media/ui/knoxicons/menu_" .. icon .. ".png")
        kt.tex[icon] = getTexture(path) or false
    end
    return kt.tex[icon] or nil
end

--- A recipe option's icon name by its recipe (OnNewCraft's first parameter).
local function recipeIcon(o)
    local recipe = o.param1
    if not recipe then return "craft" end
    local ok, name = pcall(function() return recipe:getName() end)
    name = ok and tostring(name or "") or ""
    for _, kw in ipairs(RECIPE_ICON) do
        if string.find(name, kw[1], 1, true) then return kw[2] end
    end
    local ok2, cat = pcall(function() return recipe:getCategory() end)
    if ok2 and cat and RECIPE_CAT[tostring(cat)] then return RECIPE_CAT[tostring(cat)] end
    return "craft"
end

--- Knox's icon of an option (a texture), or nil.
local function iconOf(menu, o, depth)
    -- (a colour box - the game's white square tinted - or "back")
    if (o.color ~= nil and o.iconTexture == Texture.getWhite()) or o.isDefaultOption then return nil end
    -- (an option that names its own Knox icon: the health tab's treatments)
    if o.knoxIconKey then return texOf(o.knoxIconKey) end
    local kt = knownTables()
    if o.knoxInteract then return texOf("craft") end
    if o.onSelect and o.onSelect == kt.craft then return texOf(recipeIcon(o)) end
    local icon = kt.iconText[o.name] or (o.onSelect and kt.iconFn[o.onSelect])
    if not icon and o.subOption and depth < 2 then
        local sub = menu:getSubMenu(o.subOption)
        for _, so in ipairs(sub and sub.options or {}) do
            if not so.isDefaultOption then
                local t = iconOf(sub, so, depth + 1)
                if t then return t end
            end
        end
    end
    return icon and texOf(icon) or nil
end

local function groupOf(menu, o, depth)
    local kt = knownTables()
    local g = (o.onSelect and kt.group[o.onSelect]) or kt.text[o.name]
    if g then return g end
    if o.subOption and depth < 2 then
        local sub = menu:getSubMenu(o.subOption)
        for _, so in ipairs(sub and sub.options or {}) do
            if not so.isDefaultOption then
                local sg = groupOf(sub, so, depth + 1)
                if sg ~= "other" then return sg end
            end
        end
    end
    return "other"
end

-- The world's menu -----------------------------------------------------------------

--- A world option's group (WORLD_TEXT; the item tables' functions too); one
--- opening a sub menu goes by what is in it - on the place's own menu (`root`)
--- such a sub menu with anything known in it is one of the place's "object"s.
local function worldGroupOf(menu, o, depth, root)
    local kt = knownTables()
    local name = o.name or ""
    local g = kt.worldText[name]
    if not g then
        for _, p in ipairs(kt.worldPrefix) do
            if string.sub(name, 1, #p[1]) == p[1] then
                g = p[2]
                break
            end
        end
    end
    if not g and o.onSelect then
        local ig = kt.group[o.onSelect]
        if ig == "danger" or ig == "move" then g = ig elseif ig then g = "use" end
    end
    if g then return g end
    if o.subOption and depth < 2 then
        local sub = menu:getSubMenu(o.subOption)
        for _, so in ipairs(sub and sub.options or {}) do
            if not so.isDefaultOption then
                local sg = worldGroupOf(sub, so, depth + 1, false)
                if sg ~= "other" then return root and "object" or sg end
            end
        end
    end
    return "other"
end

--- Knox's icon (a texture or nil) and world group ("danger"...) of an option
--- of the world's menu by its name: Viewpoint's crosshair actions are those
--- options (KnoxCrosshair; the author, 2026-10-25).
function K.worldLook(name)
    local kt = knownTables()
    local g = kt.worldText[name]
    if not g then
        for _, p in ipairs(kt.worldPrefix) do
            if string.sub(name, 1, #p[1]) == p[1] then
                g = p[2]
                break
            end
        end
    end
    local icon = kt.iconText[name]
    return icon and texOf(icon) or nil, g
end

--- The world's menu this one belongs to (it, or the menu it hangs from) and how deep it is.
local function worldOf(menu)
    local m, n = menu, 0
    while m.parent and n < 8 do m, n = m.parent, n + 1 end
    return m.knoxWorld or m.knoxTitled, n
end

--- The option of the parent menu that opens this sub menu, and the parent.
local function parentOption(menu)
    local p = menu.parent
    if not p then return nil end
    for _, o in ipairs(p.options) do
        if o.subOption and p:getSubMenu(o.subOption) == menu then return o, p end
    end
    return nil
end

--- The header of a world menu: the place (the root: its room, or indoors /
--- outdoors) or one of its objects (a sub menu opened from it); nil otherwise.
local function worldHeadOf(menu)
    local w, depth = worldOf(menu)
    if not w or not T.javaFonts then return nil end
    if w.title then
        -- a titled menu (K.setTitle): its header on the root only
        if depth > 0 then return nil end
        return {kind = "title", title = w.title, sub = w.sub, icon = w.icon and texOf(w.icon) or nil,
                tex = w.tex, color = w.color}
    end
    if depth == 0 then
        local sq = w.square
        local room = sq and sq:getRoom()
        local title
        if room then
            local rn = room:getName()
            title = (rn and getTextOrNull("IGUI_Knox_Room_" .. rn)) or getText("IGUI_Knox_PlaceInside")
        else
            title = getText("IGUI_Knox_PlaceOutside")
        end
        return {kind = "place", title = title, icon = texOf("here"), ground = w.ground}
    elseif depth == 1 then
        local o, p = parentOption(menu)
        if not o or worldGroupOf(p, o, 0, true) ~= "object" then return nil end
        -- (no Knox icon for it: the game's own picture of the option - never an
        -- empty cell, the author 2026-10-18)
        local icon = o.knoxIcon or iconOf(p, o, 0)
        return {kind = "object", title = o.name, icon = icon, tex = (not icon) and o.iconTexture or nil}
    end
    return nil
end

--- The options of a short sub menu as chips: {label, option}, smallest first; nil
--- when it isn't one (mouse only: on a gamepad the sub menu stays).
local function chipsOf(menu, o)
    if not o.subOption or o.onSelect or o.notAvailable or o.isDisabled then return nil end
    if JoypadState.players[menu.player + 1] then return nil end
    local sub = menu:getSubMenu(o.subOption)
    if not sub then return nil end
    local kt = knownTables()
    local list = {}
    for _, so in ipairs(sub.options) do
        if not so.isDefaultOption then
            local frac = kt.chip[so.name]
            if not frac or not so.onSelect or so.subOption or so.notAvailable or so.isDisabled then return nil end
            table.insert(list, 1, {frac = frac, option = so})
        end
    end
    if #list == 0 or #list > 4 then return nil end
    return list
end

--- Why an option can't be chosen: the first line of its tooltip, without the markup, or nil.
local function reasonOf(o)
    if not (o.notAvailable or o.isDisabled) then return nil end
    local d = o.toolTip and o.toolTip.description
    if type(d) ~= "string" then return nil end
    -- (a recipe's tooltip lists what it needs line by line: the first one says enough)
    d = string.gsub(d, "<%s*LINE%s*>", "\n")
    d = string.gsub(d, "<%s*BR%s*>", "\n")
    for line in string.gmatch(d, "[^\n]+") do
        if string.find(string.gsub(line, "<[^>]*>", ""), "%S") then
            d = line
            break
        end
    end
    d = string.gsub(d, "<[^>]*>", " ")
    d = string.gsub(d, "%s+", " ")
    d = string.match(d, "^%s*(.-)%s*$")
    if d == "" then return nil end
    return d
end

-- Layout -----------------------------------------------------------------------------

--- What the menu is about: its first item, the name to show (and how many);
--- nil for a menu not opened on Knox's items (and sub menus). The header itself
--- is the item tooltip's (KnoxTooltip.header): the tooltip turns into the menu.
local function headOf(menu)
    local t = menu.knoxTarget
    local list = t and t.list
    local item = list and list[1]
    if menu.parent or not item or not instanceof(item, "InventoryItem") then return nil end
    if not (T.javaFonts and KnoxTooltip and KnoxTooltip.header) then return nil end
    local same = true
    for _, it in ipairs(list) do
        if it:getFullType() ~= item:getFullType() then same = false end
    end
    local player = getSpecificPlayer(menu.player or 0)
    local name = (player and item:getName(player)) or item:getName() or ""
    local plain = name
    if #list > 1 then name = same and (name .. "  " .. TIMES .. #list) or (name .. "  +" .. (#list - 1)) end
    return {item = item, name = name, plainName = plain, same = same}
end

--- An option's own function, or (an option that opens a sub menu) its first one's.
local function firstFn(menu, o)
    if o.onSelect then return o.onSelect end
    local sub = o.subOption and menu:getSubMenu(o.subOption)
    for _, so in ipairs(sub and sub.options or {}) do
        if not so.isDefaultOption and so.onSelect then return so.onSelect end
    end
    return nil
end

--- The index of the item's main action in its menu (see MAIN_FN), or nil.
local function mainOf(menu, head, from)
    local kt = knownTables()
    local item = head.item
    local weapon = instanceof(item, "HandWeapon")
    local best, bestN = nil, 1000
    for i = from, #menu.options do
        local o = menu.options[i]
        local n
        if weapon and o.name == kt.attach then
            n = 0                                       -- a weapon: "Attach to"
        elseif kt.mainText[o.name] then
            n = 1
        else
            local f = firstFn(menu, o)
            n = f and kt.mainFn[f]
        end
        if n and not o.notAvailable and n < bestN then best, bestN = i, n end
    end
    return best
end

--- The item's sub menu of recipes, named as the item: "Interact" (the author, 2026-10-18).
local function isInteract(menu, head, o)
    if not (head and o.subOption) or o.onSelect then return false end
    local kt = knownTables()
    if o.name ~= head.item:getDisplayName() and o.name ~= head.plainName then return false end
    return firstFn(menu, o) == kt.craft
end

local function chipSide() return T.fontH(T.fontTile) end
local function chipW() return chipSide() + 10 end
local function nameOf(o) return o.knoxName or o.name end

--- Is this one of Knox's item menus (it, or the menu it hangs from, is about Knox's items)?
local function itemMenuOf(menu)
    local m, n = menu, 0
    while m.parent and n < 8 do m, n = m.parent, n + 1 end
    return m.knoxTarget ~= nil
end

--- What else a recipe takes, besides the item itself: the things its tooltip
--- listed (the game's recipe tooltip, on hover, in its own look - the author,
--- 2026-10-18), now under the option's name. Kept on the tooltip, made once.
local function needsOf(o)
    local tip = o.toolTip
    if not (tip and tip.logic) then return nil end
    if tip.knoxNeeds then return tip.knoxNeeds end
    local out, seen = {}, {}
    local own = o.target and o.target.getFullType and o.target:getFullType()
    local ok, items = pcall(function() return tip.logic:getRecipeData():getAllInputItems() end)
    if ok and items then
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local ft = it and it:getFullType()
            if ft and ft ~= own and not seen[ft] then
                seen[ft] = true
                table.insert(out, it)
            end
        end
    end
    tip.knoxNeeds = out
    return out
end

--- How wide the rows want the menu (the header takes the width it is given).
local function rowsWidth(menu, L)
    local tx, gap = textX(menu), menu.knoxGap
    local maxW = 0
    for _, r in ipairs(L.rows) do
        local w = 0
        if r.kind == "opt" then
            local o = menu.options[r.i]
            w = tx + T.measure(menu.knoxFont, nameOf(o)) + gap * 2 + menu.knoxArrow + menu.knoxPadX
            w = w + #(r.chips or {}) * chipW()
        elseif r.kind == "label" then
            w = menu.knoxPadX * 2 + T.measure(T.fontTile, T.upper(r.text)) + menu.knoxGap * 3 + menu.knoxArrow
        end
        if w > maxW then maxW = w end
    end
    return maxW
end

--- The menu's width; with a header, at least the tooltip's, and the header at
--- that width (a book's long name wraps instead of widening the menu).
local function finish(menu, L)
    local W = math.max(rowsWidth(menu, L), T.cell * 3)
    local r = L.rows[1]
    if r and r.kind == "head" then
        local gap = KnoxTooltip.GAP or 8
        W = math.max(W, KnoxTooltip.baseWidth())
        -- (coming from the tooltip: as wide as it, the header the same to the pixel)
        -- (kept while the menu is up: once the motion ended it fell back to its
        -- own width, and the header wrapped anew - the author, 2026-10-18)
        -- (and opened the other way - no tooltip up, another menu just before - the
        -- tooltip's width all the same, measured: the header was another size, 2026-10-18)
        if menu.knoxHeadW == nil then
            menu.knoxHeadW = menu.knoxFromW or (KnoxTooltip.widthFor and KnoxTooltip.widthFor(r.head.item, menu.player)) or false
        end
        if menu.knoxHeadW then W = math.max(W, menu.knoxHeadW) end
        r.gap = gap
        -- (the plate's own padding is above it already: the header as far from
        -- the plate's top edge as in the tooltip, GAP - not padding + GAP)
        r.top = math.max(0, gap - menu.padTopBottom)
        r.hd = KnoxTooltip.header(r.head.item, r.head.name, W - gap * 2)
        r.h = r.top + r.hd.h + math.floor(gap / 2)
        for n = 2, #L.rows do L.rows[n].y = L.rows[n].y + r.h end
        L.h = L.h + r.h
    elseif r and r.kind == "whead" then
        -- the world's header: a plate as an item's, its icon in a cell, the
        -- name and (the place's) what is in it under it; a long line slides
        local gap = (KnoxTooltip and KnoxTooltip.GAP) or 8
        local hH, sH = T.fontH(T.fontHeader), T.fontH(T.fontTile)
        local hasSub = r.wh.sub ~= nil and r.wh.sub ~= ""
        local m = math.max(4, math.floor(T.pad * 0.6))
        local ph = m * 2 + hH + (hasSub and (sH + 2) or 0)
        local cell = ph - m * 2
        local text = math.max(T.measure(T.fontHeader, r.wh.title or ""), hasSub and math.min(T.measure(T.fontTile, r.wh.sub), T.cell * 4) or 0)
        W = math.max(W, gap * 2 + m * 3 + cell + text)
        r.gap, r.m, r.ph, r.cell, r.hasSub = gap, m, ph, cell, hasSub
        r.top = math.max(0, gap - menu.padTopBottom)
        r.h = r.top + ph + math.floor(gap / 2)
        for n = 2, #L.rows do L.rows[n].y = L.rows[n].y + r.h end
        L.h = L.h + r.h
    end
    L.w = W
    return L
end

--- The rows of a menu, top down: {kind = "head" | "label" | "sep" | "opt", y, h, ...};
--- `byIndex[i]` is the row of option i. Rebuilt whenever asked (a few dozen options).
local function buildLayout(menu)
    ensure(menu)
    local L = {rows = {}, byIndex = {}, h = 0}
    local ih = menu.itemHgt
    local tileH = T.fontH(T.fontTile)
    local function add(r)
        r.y = L.h
        L.h = L.h + r.h
        table.insert(L.rows, r)
        if r.i then L.byIndex[r.i] = r end
        return r
    end
    local head = headOf(menu)
    -- (its height comes with the menu's width, once the options are measured: finish)
    if head then add({kind = "head", h = 0, head = head}) end
    -- the world's menu: the place's header, or the object's in its sub menu
    local wh = (not head) and worldHeadOf(menu) or nil
    if wh then add({kind = "whead", h = 0, wh = wh}) end
    local kt = knownTables()
    local foldK = menu.knoxOtherK or 0   -- how far "Other" is open (0 folded, 1 open)
    local function addOption(i, danger, fold)
        local o = menu.options[i]
        o.knoxInteract = isInteract(menu, head, o) or nil
        o.knoxName = o.knoxInteract and getText("IGUI_Knox_MenuInteract") or nil
        -- "Take Baseball bat off Back": the menu is about the bat already - "Take off"
        if o.onSelect and o.onSelect == kt.unhook then o.knoxName = kt.unequipText end
        o.knoxIcon = iconOf(menu, o, 0)
        local r = {kind = "opt", i = i, h = ih, danger = danger}
        r.chips = chipsOf(menu, o)
        r.reason = reasonOf(o)
        if not r.reason and o.onSelect and o.onSelect == kt.craft then
            local needs = needsOf(o)
            if needs and #needs > 0 then r.needs = needs end
        end
        if r.reason or r.needs then r.h = ih + tileH - 4 end
        if fold then
            -- folded under "Other": as tall as it is open
            r.fold, r.fullH = true, r.h
            r.h = math.floor(r.h * foldK + 0.5)
        end
        add(r)
    end
    -- the "back" options of the single menu mode stay on top as they are
    local first = 1
    while menu.options[first] and menu.options[first].isDefaultOption do
        addOption(first)
        first = first + 1
    end
    -- what stays out of Knox's menus; "Inspect" (the 3D look) always first; "Take the
    -- generator", when it can be done, before everything (the author, 2026-10-22)
    local rest, inspect, take = {}, nil, nil
    for i = first, #menu.options do
        local o = menu.options[i]
        if o.onSelect and kt.hidden[o.onSelect] then
            -- (left out)
        elseif o.name == kt.take and not take and not o.notAvailable then
            take = i
        elseif o.name == kt.inspect and not inspect then
            inspect = i
        else
            table.insert(rest, i)
        end
    end
    if take then addOption(take) end
    local labelH = T.fontH(T.fontTile) + math.floor(ih * 0.55)
    if wh and wh.kind ~= "title" then
        -- the world's menu: the place's objects on top (the sink, the curtains),
        -- then the groups; an object's sub menu: its own groups
        local order = (wh.kind == "place") and WORLD_GROUPS or OBJECT_GROUPS
        local groups, objs, present = {}, {}, 0
        local list = {}
        if inspect then table.insert(list, inspect) end
        for _, i in ipairs(rest) do table.insert(list, i) end
        for _, i in ipairs(list) do
            local g = worldGroupOf(menu, menu.options[i], 0, wh.kind == "place")
            if g == "object" then
                table.insert(objs, i)
            else
                if not groups[g] then
                    groups[g] = {}
                    if g ~= "danger" then present = present + 1 end
                end
                table.insert(groups[g], i)
            end
        end
        if wh.kind == "place" then
            -- under the place's name: what is in it
            local names = {}
            for _, i in ipairs(objs) do table.insert(names, menu.options[i].name) end
            if (wh.ground or 0) > 0 then table.insert(names, getText("IGUI_Knox_PlaceGround", wh.ground)) end
            wh.sub = table.concat(names, "  " .. string.char(183) .. "  ")
        end
        L.grouped = true
        for _, i in ipairs(objs) do addOption(i) end
        local labelled = present >= 2 or (#objs > 0 and present >= 1)
        for _, g in ipairs(order) do
            local glist = groups[g]
            if glist then
                local fold = g == "other" and labelled
                if g == "danger" then
                    if #L.rows > 1 then add({kind = "sep", h = math.floor(ih * 0.35)}) end
                elseif labelled then
                    add({kind = "label", h = labelH, text = getText(WORLD_TITLE[g]), toggle = fold})
                end
                for _, i in ipairs(glist) do addOption(i, g == "danger", fold) end
            end
        end
        return finish(menu, L)
    end
    if not head then
        -- any other menu: as it came, "Inspect" first
        if inspect then addOption(inspect) end
        for _, i in ipairs(rest) do addOption(i) end
        L.grouped = false
        return finish(menu, L)
    end
    -- an item's menu: on top what is used most, then the groups
    local top, taken = {}, {}
    if inspect then table.insert(top, inspect) end
    local main = mainOf(menu, head, first)
    if main and main ~= inspect then
        table.insert(top, main)
        taken[main] = true
    end
    -- "Attach to" (a quick slot) is on top for anything that has it, not only weapons
    -- (the author, 2026-10-19: a canteen's was down in the group)
    for _, i in ipairs(rest) do
        local o = menu.options[i]
        if not taken[i] and o.name == kt.attach and not o.notAvailable then
            table.insert(top, i)
            taken[i] = true
        end
    end
    for _, i in ipairs(rest) do
        local o = menu.options[i]
        if not taken[i] and ((o.onSelect and o.onSelect == kt.craft) or isInteract(menu, head, o)) then
            table.insert(top, i)
            taken[i] = true
        end
    end
    local groups, present = {}, 0
    for _, i in ipairs(rest) do
        if not taken[i] then
            local g = groupOf(menu, menu.options[i], 0)
            if not groups[g] then
                groups[g] = {}
                if g ~= "danger" then present = present + 1 end
            end
            table.insert(groups[g], i)
        end
    end
    L.grouped = true
    for _, i in ipairs(top) do addOption(i) end
    -- a group's title is a divider, not an option: small dim caps and a line,
    -- room above it, little below - it holds on to its options (the author, 2026-10-18)
    local labelled = present >= 2 or (#top > 0 and present >= 1)
    for _, g in ipairs(GROUPS) do
        local list = groups[g]
        if list then
            local fold = g == "other" and labelled
            if g == "danger" then
                if #L.rows > 0 then add({kind = "sep", h = math.floor(ih * 0.35)}) end
            elseif labelled then
                -- "Other" folded until the mouse comes on its title (the author, 2026-10-18)
                add({kind = "label", h = labelH, text = getText(GROUP_TITLE[g]), toggle = fold})
            end
            for _, i in ipairs(list) do addOption(i, g == "danger", fold) end
        end
    end
    return finish(menu, L)
end

-- (the menu asks for its layout every frame - the header alone is some sixty
-- calls into the game: it is made anew only when something it reads changed:
-- the options, their sub menus, "Other" opening, the sizes, the gamepad)
local function signOf(menu, L)
    local s = {n = #menu.options, k = menu.knoxOtherK or 0, cell = T.cell, font = menu.knoxFont, tile = T.fontTile,
               target = menu.knoxTarget, headW = menu.knoxHeadW, pad = JoypadState.players[(menu.player or 0) + 1] ~= nil,
               up = menu.parent and menu.parent.knoxLayoutN}
    for i, o in ipairs(menu.options) do
        local sub = o.subOption and menu:getSubMenu(o.subOption)
        s[i] = {o = o, name = o.name, fn = o.onSelect, sub = sub, subN = sub and #sub.options or 0,
                na = o.notAvailable, dis = o.isDisabled, tip = o.toolTip, desc = o.toolTip and o.toolTip.description,
                icon = o.iconTexture, forTex = o.itemForTexture, color = o.color, check = o.checkMark,
                key = o.knoxIconKey, def = o.isDefaultOption, p1 = o.param1}
    end
    L.sig = s
end

--- (what an option was laid out with: its icon set after addOption widens the menu)
local function sameOption(e, o)
    return e.o == o and e.name == o.name and e.fn == o.onSelect and e.na == o.notAvailable and e.dis == o.isDisabled
        and e.tip == o.toolTip and e.desc == (o.toolTip and o.toolTip.description) and e.icon == o.iconTexture
        and e.forTex == o.itemForTexture and e.color == o.color and e.check == o.checkMark and e.key == o.knoxIconKey
        and e.def == o.isDefaultOption and e.p1 == o.param1
end

local function sameLayout(menu, L)
    local s = L and L.sig
    if not s or s.n ~= #menu.options or s.k ~= (menu.knoxOtherK or 0) or s.cell ~= T.cell or s.font ~= menu.knoxFont
        or s.tile ~= T.fontTile or s.target ~= menu.knoxTarget or s.headW ~= menu.knoxHeadW
        or s.pad ~= (JoypadState.players[(menu.player or 0) + 1] ~= nil) or s.up ~= (menu.parent and menu.parent.knoxLayoutN) then
        return false
    end
    for i, o in ipairs(menu.options) do
        local e = s[i]
        if not sameOption(e, o) then return false end
        local sub = o.subOption and menu:getSubMenu(o.subOption)
        if e.sub ~= sub or e.subN ~= (sub and #sub.options or 0) then return false end
    end
    return true
end

local function layout(menu)
    local L = buildLayout(menu)
    signOf(menu, L)
    -- (a sub menu's header comes from its option here: it looks again after this one)
    menu.knoxLayoutN = (menu.knoxLayoutN or 0) + 1
    return L
end

local function layoutOf(menu)
    if not menu.knoxL then menu.knoxL = layout(menu) end
    return menu.knoxL
end

local function scrollDY(menu)
    return (menu:getScrollHeight() > menu:getScrollAreaHeight()) and menu.scrollIndicatorHgt or 0
end

-- Sizes ------------------------------------------------------------------------

local vanillaSetFont = ISContextMenu.setFont

function ISContextMenu:setFont(font)
    vanillaSetFont(self, font)
    K.apply(self)
end

local vanillaClear = ISContextMenu.clear

--- A menu made anew: it fades in, and the first one after K.setTarget is about those items.
function ISContextMenu:clear()
    vanillaClear(self)
    self.knoxOpenMs = getTimestampMs()
    self.knoxTarget = nil
    self.knoxFrom, self.knoxPlaced, self.knoxFromW = nil, nil, nil
    self.knoxOtherWant, self.knoxOtherLin, self.knoxOtherK, self.knoxHB = nil, nil, nil, nil
    self.knoxOnFold, self.knoxFoldRect, self.knoxHeadW = nil, nil, nil
    self.knoxL = nil
    self.knoxWorld, self.knoxTitleSt, self.knoxSubSt, self.knoxTitled = nil, nil, nil, nil
    -- a titled menu (K.setTitle): the next root menu of that player
    local tt = K.titled
    if tt and tt.pending and getTimestampMs() - tt.ms < 1000 and self == getPlayerContextMenu(tt.playerNum) then
        tt.pending = false
        self.knoxTitled = tt
    end
    -- the world's menu being made (ISWorldObjectContextMenu.createMenu, below):
    -- its root is this player's menu
    local wt = K.world
    if wt and wt.pending and getTimestampMs() - wt.ms < 1000 and self == getPlayerContextMenu(wt.playerNum) then
        wt.pending = false
        self.knoxWorld = wt
    end
    local t = K.target
    -- (the same menu made anew at once is still about them: a quick slot's menu
    -- is got twice by the game - ISHotbar.doMenu, then createMenu - and came out
    -- without its header and groups, 2026-10-18)
    if t and (t.pending or t.claimedBy == self) and getTimestampMs() - t.ms < 1000 then
        t.pending = false
        t.claimedBy = self
        self.knoxTarget = t
        -- the item's tooltip is up: it folds into its header, and this menu
        -- opens from there (see KnoxTooltip.startFold)
        if KnoxTooltip and KnoxTooltip.startFold and t.list and t.list[1] then
            self.knoxFrom = KnoxTooltip.startFold(t.list[1])
            self.knoxFromW = self.knoxFrom and self.knoxFrom.w or nil
        end
    end
end

--- A menu turning from a tooltip: its plate's height now (from the tooltip's to
--- its own), the plate's alpha (it comes up over the tooltip) and the options'
--- (after it); nil when done (or opened the plain way).
local function morphOf(menu)
    local from = menu.knoxFrom
    if not from then return nil end
    local t = (getTimestampMs() - from.ms) / KnoxTooltip.MORPH_MS
    if t >= 1 then
        menu.knoxFrom = nil
        return nil
    end
    local ease = KnoxTooltip.ease
    local h = math.floor(from.h + (menu.height - from.h) * ease(t) + 0.5)
    return h, ease(t / 0.6), ease((t - 0.3) / 0.7)
end

function ISContextMenu:calcHeight()
    -- (asked by every addOption, and by prerender after it laid the menu out anew)
    if not sameLayout(self, self.knoxL) then self.knoxL = layout(self) end
    local itemsHgt = self.knoxL.h
    local screenHgt = getCore():getScreenHeight()
    if itemsHgt + self.padTopBottom * 2 > screenHgt then
        self.scrollAreaHeight = screenHgt - self.padTopBottom * 2 - self.scrollIndicatorHgt * 2
        self:setHeight(self.scrollAreaHeight + self.padTopBottom * 2 + self.scrollIndicatorHgt * 2)
    else
        self.scrollAreaHeight = itemsHgt
        self:setHeight(itemsHgt + self.padTopBottom * 2)
    end
    self:setScrollHeight(itemsHgt)
end

function ISContextMenu:calcWidth()
    ensure(self)
    return layoutOf(self).w
end

-- Rows and the mouse -------------------------------------------------------------
-- (the game finds the option under the mouse, a sub menu's place and the
-- scroll by "index x row height": with rows of their own heights they ask the layout)

function ISContextMenu:getIndexAt(x, y)
    if x < 0 or x >= self:getWidth() then return -1 end
    local cy = y - self.padTopBottom - scrollDY(self)
    for _, r in ipairs(layoutOf(self).rows) do
        if r.kind == "opt" and cy >= r.y and cy < r.y + r.h then return r.i end
    end
    return -1
end

local vanillaItemY = ISContextMenu.getItemY

function ISContextMenu:getItemY(index)
    local L = layoutOf(self)
    local r = L.byIndex[index]
    if not r then
        if index == #self.options + 1 then return self.y + self.padTopBottom + scrollDY(self) + L.h + self:getYScroll() end
        return vanillaItemY(self, index)
    end
    return self.y + self.padTopBottom + scrollDY(self) + r.y + self:getYScroll()
end

function ISContextMenu:ensureVisible()
    if not self.mouseOver then return end
    if self:getScrollHeight() <= self:getScrollAreaHeight() then return end
    local r = layoutOf(self).byIndex[self.mouseOver]
    if not r then return end
    local area, top = self:getScrollAreaHeight(), -self:getYScroll()
    if r.y < top then
        self:setYScroll(-r.y)
    elseif r.y + r.h > top + area then
        self:setYScroll(-(r.y + r.h - area))
    end
end

--- The gamepad steps through the options as they stand, not as they were added.
local function stepPad(menu, dir)
    if menu.subMenu then
        menu.subMenu:hideAndChildren()
        menu.subMenu = nil
    end
    local order = {}
    for _, r in ipairs(layoutOf(menu).rows) do
        if r.kind == "opt" then table.insert(order, r.i) end
    end
    if #order == 0 then return end
    local at = 0
    for n, i in ipairs(order) do
        if i == menu.mouseOver then at = n end
    end
    at = at + dir
    if at < 1 then at = #order elseif at > #order then at = 1 end
    menu.mouseOver = order[at]
    menu:checkHighlightedOption(nil)
    menu:hideToolTip()
    menu.mouseOut = false
    menu:ensureVisible()
end

function ISContextMenu:onJoypadDirUp() stepPad(self, -1) end
function ISContextMenu:onJoypadDirDown() stepPad(self, 1) end

local function choose(menu, o)
    ISContextMenu.globalPlayerContext = menu.player
    menu:closeAll()
    o.onSelect(o.target, o.param1, o.param2, o.param3, o.param4, o.param5, o.param6, o.param7, o.param8, o.param9, o.param10)
end

local vanillaMouseUp = ISContextMenu.onMouseUp

--- A row of chips: a chip does its option, the rest of the row the first of them.
--- "Other"'s title: a click folds it or opens it.
function ISContextMenu:onMouseUp(x, y)
    local fr = self.knoxFoldRect
    if fr and y >= fr[1] and y < fr[2] and x >= 0 and x < self.width then
        self.knoxOtherWant = not ((self.knoxOtherK or 0) > 0.5)
        getSoundManager():playUISound("UIActivateButton")
        return
    end
    local r = self.mouseOver and self.mouseOver ~= -1 and layoutOf(self).byIndex[self.mouseOver]
    if r and r.chips and self:getIsVisible() then
        local cy = y - self.padTopBottom - scrollDY(self)
        if cy >= r.y and cy < r.y + r.h then
            local pick = r.chips[#r.chips].option
            for _, c in ipairs(r.chips) do
                if c.rect and x >= c.rect[1] and x < c.rect[1] + c.rect[3] then pick = c.option end
            end
            choose(self, pick)
            return
        end
    end
    vanillaMouseUp(self, x, y)
end

local vanillaPrerender = ISContextMenu.prerender

local function ease(t)
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local FOLD_MS = 170   -- "Other" opening

function ISContextMenu:prerender()
    vanillaPrerender(self)
    if self:isEmpty() then return end
    -- "Other" opens (or closes) over a moment: its rows grow, those under it move down
    local now = getTimestampMs()
    local want = self.knoxOtherWant and 1 or 0
    local lin = self.knoxOtherLin or 0
    if lin ~= want then
        local step = (T.animOn and not T.animOn()) and 1 or math.min(100, now - (self.knoxOtherMs or now)) / FOLD_MS
        lin = want > lin and math.min(want, lin + step) or math.max(want, lin - step)
        self.knoxOtherLin = lin
    end
    self.knoxOtherMs = now
    self.knoxOtherK = ease(lin)
    -- (an option's reason or sub menu comes after addOption measured it: lay out anew)
    local L = self.knoxL
    if not sameLayout(self, L) then
        L = layout(self)
        self.knoxL = L
    end
    if L.h ~= self:getScrollHeight() then self:calcHeight() end
    -- opening from a tooltip: its header right over the tooltip's (on the screen)
    local from = self.knoxFrom
    if from and not self.knoxPlaced and L.rows[1] and L.rows[1].kind == "head" then
        self.knoxPlaced = true
        local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
        self:setX(math.max(0, math.min(from.x, sw - self.width - 1)))
        -- (padding + r.top = GAP: the plates' top edges and the headers on each other)
        local head = L.rows[1]
        self:setY(math.max(0, math.min(from.y + (KnoxTooltip.GAP or 8) - self.padTopBottom - head.top, sh - self.height - 1)))
    end
    if from then from.toH = self.height end   -- (the tooltip under it is cut to the plate's height)
end

-- Drawing ------------------------------------------------------------------------

local function blinkAlpha(menu)
    if not menu.blinkAlpha then
        menu.blinkAlpha = 1
        menu.blinkAlphaIncrease = false
    end
    local step = 0.1 * (UIManager.getMillisSinceLastRender() / 33.3)
    if not menu.blinkAlphaIncrease then
        menu.blinkAlpha = menu.blinkAlpha - step
        if menu.blinkAlpha < 0 then menu.blinkAlpha, menu.blinkAlphaIncrease = 0, true end
    else
        menu.blinkAlpha = menu.blinkAlpha + step
        if menu.blinkAlpha > 1 then menu.blinkAlpha, menu.blinkAlphaIncrease = 1, false end
    end
    return menu.blinkAlpha
end

local function drawIcon(ui, o, x, y, s, a, tint)
    if o.knoxIcon then
        -- Knox's own: in the row's colour
        ui:drawTextureScaledAspect(o.knoxIcon, x, y, s, s, a, tint.r, tint.g, tint.b)
    elseif o.color ~= nil then
        ui:drawTextureScaledAspect(o.iconTexture, x, y, s, s, a, o.color.r, o.color.g, o.color.b)
    elseif o.iconTexture ~= nil then
        ui:drawTextureScaledAspect(o.iconTexture, x, y, s, s, a, 1, 1, 1)
    elseif o.itemForTexture ~= nil then
        ISInventoryItem.renderItemIcon(ui, o.itemForTexture, x, y, a, s, s)
    end
end

--- The item tooltip's header, as far from the plate's edges as there.
local function drawHead(menu, r, y, w, a)
    KnoxTooltip.drawHeader(menu, r.hd, r.gap, y + r.top, w - r.gap * 2, a)
end

--- The world menu's header (see finish): the place or the object.
local function drawWorldHead(menu, r, y, w, a)
    local C = T.color
    local x0, y0, pw = r.gap, y + r.top, w - r.gap * 2
    T.rect(menu, x0, y0, pw, r.ph, C.header, a)
    T.tileFrame(menu, x0, y0, pw, r.ph, C.tileFrame, a)
    local cx, cy, cell = x0 + r.m, y0 + r.m, r.cell
    T.rect(menu, cx, cy, cell, cell, C.cell, a)
    if r.wh.icon then
        local is = math.floor(cell * 0.68 + 0.5)
        local c = C.accent
        menu:drawTextureScaledAspect(r.wh.icon, cx + math.floor((cell - is) / 2), cy + math.floor((cell - is) / 2), is, is, a, c.r, c.g, c.b)
    elseif r.wh.tex then
        local is = math.floor(cell * 0.8 + 0.5)
        menu:drawTextureScaledAspect(r.wh.tex, cx + math.floor((cell - is) / 2), cy + math.floor((cell - is) / 2), is, is, a, 1, 1, 1)
    end
    local tx = cx + cell + r.m
    local tw = x0 + pw - r.m - tx
    local hH = T.fontH(T.fontHeader)
    menu.knoxTitleSt = menu.knoxTitleSt or {}
    local ty = r.hasSub and cy or (cy + math.floor((cell - hH) / 2))
    T.marquee(menu, menu.knoxTitleSt, r.wh.title or "", tx, ty, tw, r.wh.color or C.bright, T.fontHeader, a)
    if r.hasSub then
        menu.knoxSubSt = menu.knoxSubSt or {}
        T.marquee(menu, menu.knoxSubSt, r.wh.sub, tx, cy + hH + 2, tw, C.dim, T.fontTile, a)
    end
end

--- The chips at the right of an option row; returns where they begin.
local function drawRight(menu, r, y, w, hover, mx, a)
    local ih = menu.itemHgt
    local kh = T.fontH(T.fontTile) + 4
    local ky = y + math.floor((ih - kh) / 2)
    local x = w - menu.knoxPadX
    if menu.options[r.i].subOption and not r.chips then x = x - menu.knoxArrow - menu.knoxGap end
    if r.chips then
        -- one strip of chips side by side, no gaps between them: the mouse going
        -- from one to the next never leaves the strip (with gaps, "all" lit up
        -- on the way - the author, 2026-10-18). Off the strip the row is "all".
        local right = x
        for n = #r.chips, 1, -1 do
            local c = r.chips[n]
            local cw = chipW()
            x = x - cw
            c.rect = {x, ky, cw, kh}
        end
        -- each a sand square filled as far as it goes: a quarter (its lower left
        -- corner), a half (its lower half), all of it; dim at rest, bright with a
        -- sand frame for the one to be done (the author, 2026-10-18)
        local onStrip = hover and mx >= x and mx < right
        local s = chipSide()
        local sand = T.color.accent
        for n, c in ipairs(r.chips) do
            local rc = c.rect
            local lit = hover and ((onStrip and mx >= rc[1] and mx < rc[1] + rc[3]) or (not onStrip and n == #r.chips))
            local qx = rc[1] + math.floor((rc[3] - s) / 2)
            local qy = rc[2] + math.floor((rc[4] - s) / 2)
            T.rect(menu, qx, qy, s, s, T.color.cell, a)
            local fa = (lit and 0.95 or (hover and 0.5 or 0.35)) * a
            local half = math.floor(s / 2)
            if c.frac >= 1 then
                T.rect(menu, qx, qy, s, s, sand, fa)
            elseif c.frac >= 0.5 then
                T.rect(menu, qx, qy + s - half, s, half, sand, fa)
            else
                T.rect(menu, qx, qy + s - half, half, half, sand, fa)
            end
            -- (a 2 px frame, as a tile's: 1 px was lost against the plate - 2026-10-18)
            T.tileFrame(menu, qx, qy, s, s, lit and sand or T.color.tileFrame, a)
        end
    end
    return x
end

local function renderMenu(self, visH, plateA, rowsA)
    local L = layoutOf(self)

    -- a new menu fades in (one coming from a tooltip turns from it instead)
    local a0 = 1
    if not visH and self.knoxOpenMs and (not T.animOn or T.animOn()) then
        a0 = math.min(1, math.max(0, (getTimestampMs() - self.knoxOpenMs) / 110))
    end
    local aP = plateA or a0   -- the plate, its frame and the header
    if rowsA then a0 = rowsA end

    local ys = self:getYScroll()
    local w, h = self.width, visH or self.height
    local dy = scrollDY(self)
    local top = self.padTopBottom + dy
    local ih = self.itemHgt
    local padX, icon = self.knoxPadX, self.knoxIcon
    local tx = textX(self)
    local textDY = math.floor((ih - self.fontHgt) / 2)
    local iconDY = math.floor((ih - icon) / 2)
    local arrow = self.knoxArrow
    local mx = self:getMouseX()
    local areaBottom = self.scrollIndicatorHgt + self.padTopBottom + self:getScrollAreaHeight()

    -- shadow, plate and frame stay put while the list scrolls
    -- (from a tooltip: the tooltip's own shadow and frame are under it, so only its plate comes up)
    local fromTip = plateA and self.knoxFrom
    if not fromTip then self:drawRect(3, 5 - ys, w, h, 0.45 * aP, 0, 0, 0) end
    T.rect(self, 0, -ys, w, h, T.color.window, 0.97 * aP)
    -- (the world's menus too, the same look: the author, 2026-10-18)
    local framed = itemMenuOf(self) or worldOf(self) ~= nil
    if framed then
        -- an item's menu, and its sub menus: the same sand frame as its tile (the author, 2026-10-18)
        local c = T.color.accent
        self:drawRectBorderStatic(0, 0, w, h, fromTip and 1 or aP, c.r, c.g, c.b)
        self:drawRectBorderStatic(1, 1, w - 2, h - 2, fromTip and 1 or aP, c.r, c.g, c.b)
    else
        self:drawRectBorderStatic(0, 0, w, h, fromTip and 1 or aP, EDGE.r, EDGE.g, EDGE.b)
    end

    -- the highlight of the option under the mouse glides from row to row
    -- (and fades out off them) instead of jumping (the author, 2026-10-18)
    local now = getTimestampMs()
    local tr = self.mouseOver and self.mouseOver ~= -1 and L.byIndex[self.mouseOver] or nil
    if tr and tr.h < 1 then tr = nil end
    local hb = self.knoxHB or {y = 0, h = ih, a = 0, ms = now}
    self.knoxHB = hb
    local s = (T.animOn and not T.animOn()) and 1 or (1 - math.exp(-math.min(100, now - hb.ms) / 38))
    hb.ms = now
    if tr then
        if hb.a < 0.05 then hb.y, hb.h = tr.y, tr.h end
        hb.y, hb.h = hb.y + (tr.y - hb.y) * s, hb.h + (tr.h - hb.h) * s
        hb.a = hb.a + (1 - hb.a) * s
    else
        hb.a = hb.a * (1 - s)
    end
    -- (inside the frame: over the sand frame's 2 px it ran onto it - 2026-10-18)
    local inset = framed and 2 or 1
    if hb.a > 0.02 then
        local by, bh = top + math.floor(hb.y + 0.5), math.floor(hb.h + 0.5)
        T.rect(self, inset, by, w - inset * 2, bh, HOVER, hb.a * a0)
        local to = tr and self.options[tr.i]
        if to and not (to.isDisabled or to.notAvailable) then T.rect(self, inset, by, 2, bh, T.color.accent, hb.a * a0) end
    end
    local my = self:getMouseY()
    local mouseIn = self:isMouseOver()
    self.knoxFoldRect = nil

    self.currentOptionRect = {x = self.x, y = self.y + top + ys, width = 100, height = ih}
    local sizeMap = {}
    local offTop, offBottom = false, false
    local showTooltip = false
    local highlightedOption = nil

    for _, r in ipairs(L.rows) do
        local y = top + r.y
        local k = r.i and self.options[r.i]
        if k and k.disable then return end
        if y + ys < 0 then
            offTop = true
        elseif y + ys + math.min(r.h, ih) > areaBottom then
            offBottom = true
        elseif r.kind == "head" then
            drawHead(self, r, y, w, aP)
        elseif r.kind == "whead" then
            drawWorldHead(self, r, y, w, aP)
        elseif r.kind == "label" then
            local f = T.fontTile
            local capH = T.fontH(f)
            local text = T.upper(r.text)
            local ty = y + r.h - capH - math.floor(ih * 0.1)
            T.text(self, text, padX, ty, T.color.dim, f, 0.8 * a0)
            -- the line on from the title to the plate's edge
            local lx = padX + T.measure(f, text) + self.knoxGap
            local rx = w - padX
            if r.toggle then
                -- "Other": a chevron at the end of its line, down while folded;
                -- the mouse on the title opens it
                local open = (self.knoxOtherK or 0) > 0.5
                local hot = mouseIn and my >= y and my < y + r.h
                -- the mouse coming onto the title opens it (staying there doesn't
                -- undo a click that folded it); gone up above it, it folds again;
                -- a click on it does either (onMouseUp, by knoxFoldRect)
                if hot and not self.knoxOnFold then self.knoxOtherWant = true end
                self.knoxOnFold = hot
                if mouseIn and my < y then self.knoxOtherWant = false end
                self.knoxFoldRect = {y, y + r.h}
                rx = rx - arrow * 2 - self.knoxGap
                chevron(self, w - padX - arrow, ty + math.floor(capH / 2) - (open and math.floor(arrow / 2) or 0),
                    arrow, open and 2 or -2, hot and T.color.accent or T.color.dim, a0)
            end
            if lx < rx then
                T.rect(self, lx, ty + math.floor(capH / 2), rx - lx, 1, T.color.border, a0)
            end
        elseif r.kind == "opt" and r.h < 1 then
            -- (folded under "Other")
        elseif r.kind == "sep" then
            T.rect(self, padX, y + math.floor(r.h / 2), w - padX * 2, 1, T.color.border, a0)
        else
            local hover = self.mouseOver == r.i
            local off = k.isDisabled or k.notAvailable
            -- a row of "Other" still opening: cut to its height so far, coming up
            local partial = r.fold and r.h < r.fullH
            local a0 = a0
            if partial then
                a0 = a0 * r.h / r.fullH
                if not visH then self:setStencilRect(0, y, w, r.h) end
            end
            local col, a
            if off then
                col, a = T.color.dim, 0.75
            elseif k.badColor or r.danger then
                col, a = RED, 1
            elseif k.goodColor then
                col, a = T.color.good, 1
            else
                col, a = hover and T.color.bright or T.color.text, 1
            end

            if not hover and self.blinkOption == k.name then
                T.rect(self, inset, y, w - inset * 2, r.h, T.color.accent, 0.35 * blinkAlpha(self) * a0)
            end

            -- (a row with a reason: the name a little up, the reason under it; a plain
            -- row: the name in its middle by the letters' pixels, as the layout kit
            -- puts it - by the font's line height capitals sat high, plain to see in a
            -- one-row menu: «Бутылка (пустое)», the author 2026-10-21)
            local nameY
            if r.reason or r.needs then
                nameY = y + textDY - (r.reason and 2 or 0)
            else
                local _, iy = T.inkOrigin(nameOf(k), tx, y, 0, ih, self.knoxFont)
                nameY = iy
            end
            -- (Knox's icon: dim at rest, sand under the mouse, red for the dangerous, faint when off)
            local tint = (off and T.color.dim) or ((k.badColor or r.danger) and RED) or (hover and T.color.accent) or T.color.dim
            drawIcon(self, k, padX, y + iconDY, icon, (off and 0.5 or 1) * a0, tint)
            -- (a colour box's frame; not round Knox's own icons - a recipe's tinted item had one)
            if k.color ~= nil and not k.knoxIcon then T.border(self, padX, y + iconDY, icon, icon, T.color.tileEdge, a0) end
            if k.checkMark then
                self:drawTextureScaledAspect(self.tickTexture, padX, y + iconDY, icon, icon, a0,
                    T.color.accent.r, T.color.accent.g, T.color.accent.b)
            end
            local right = drawRight(self, r, y, w, hover, mx, a0)
            T.drawText(self, nameOf(k), tx, nameY, col.r, col.g, col.b, a * a0, self.knoxFont)
            if r.reason then
                T.text(self, T.fit(r.reason, T.fontTile, right - tx), tx, nameY + self.fontHgt, T.color.dim, T.fontTile, 0.9 * a0)
            elseif r.needs then
                -- what else it takes: one toolbox icon of Knox's (not the things'
                -- coloured pictures - the author, 2026-10-18), then their names
                -- (the icon and the names centred on one band by the letters' own
                -- pixels, a gap between: it stood tight and off the text's middle)
                local ny = nameY + self.fontHgt
                local fh = T.fontH(T.fontTile)
                local s = math.floor(fh * 0.85)
                local gap = math.max(6, math.floor(self.knoxGap * 0.6))
                local tex = texOf("needs")
                if tex then
                    local d = T.color.dim
                    self:drawTextureScaledAspect(tex, tx, ny + math.floor((fh - s) / 2), s, s, 0.9 * a0, d.r, d.g, d.b)
                end
                local names = {}
                for _, it in ipairs(r.needs) do table.insert(names, it:getName() or "") end
                T.inkLeft(self, T.fit(table.concat(names, ", "), T.fontTile, right - tx - s - gap), tx + s + gap, ny, fh,
                    T.color.dim, T.fontTile, 0.9 * a0)
            end
            if k.isDefaultOption then
                -- "back" in the single-menu mode
                chevron(self, math.max(2, math.floor(padX / 2) - math.floor(arrow / 2)), y + math.floor(ih / 2), arrow, -1, T.color.dim, a0)
            end
            if k.subOption ~= nil and not r.chips then
                chevron(self, w - padX - arrow, y + math.floor(ih / 2) - 1, arrow, 1,
                    (hover and not k.isDisabled) and T.color.accent or T.color.dim, a * a0)
            end

            if hover then
                local isMouseOut = self:isMouseOut()
                if JoypadState.players[self.player + 1] and not self.joyfocus then isMouseOut = true end
                if not isMouseOut then
                    highlightedOption = k
                    K.hover = {option = k, menu = self, ms = getTimestampMs()}
                end
                -- (an item's menu shows no option tooltips: what they said - why it
                -- can't, what a recipe takes - is under the option's name; "Replace:
                -- Hammer" and the like only repeated the option, the author 2026-10-18)
                if k.toolTip and not isMouseOut and not framed then
                    self:showTooltip(k)
                    showTooltip = true
                end
                -- (chips stand for their sub menu: it doesn't open)
                if k.subOption ~= nil and not r.chips and not self:isOptionSingleMenu() and self.forceVisible then
                    self.subMenu = self:getSubMenu(k.subOption)
                    self.subMenu:setVisible(true)
                    -- next to the option, its first row level with it
                    local sdy = (self.subMenu:getScrollHeight() > self.subMenu:getScrollAreaHeight()) and self.scrollIndicatorHgt or 0
                    self.subMenu:setY(y - self.subMenu.padTopBottom + self.y + ys - sdy)
                    table.insert(sizeMap, self.subMenu)
                end
                self.currentOptionRect = {x = self.x, y = self.y + y + ys, width = 100, height = r.h}
            end
            if k.isDefaultOption and self.options[r.i + 1] and not self.options[r.i + 1].isDefaultOption then
                T.rect(self, padX, y + r.h - 1, w - padX * 2, 1, T.color.border, a0)
            end
            if partial and not visH then self:clearStencilRect() end
        end
    end

    -- scroll indicators
    if offTop then
        T.rect(self, 1, 1 - ys, w - 2, dy - 1, T.color.header, a0)
        chevron(self, math.floor(w / 2), math.floor(dy / 2) - math.floor(arrow / 2) - ys, arrow, 2, T.color.text, a0)
    end
    if offBottom then
        local by = h - dy - ys
        T.rect(self, 1, by, w - 2, dy - 1, T.color.header, a0)
        chevron(self, math.floor(w / 2), by + math.floor(dy / 2) - math.floor(arrow / 2), arrow, -2, T.color.text, a0)
    end

    if self.toolTip then
        self.toolTip:setContextMenu(self)
        self.toolTip:setVisible(true)
    end

    local ww = self:calcWidth()
    self:setWidth(ww)
    self.currentOptionRect.width = ww

    -- sub menus next to this one, on the left when there is no room on the right
    for _, subMenu in ipairs(sizeMap) do
        local subW = subMenu:calcWidth()
        if self.parent ~= nil and self.x < self.parent.x then
            subMenu:setX(self.x - subW - 1)
        elseif self.x + ww + 1 + subW > getCore():getScreenWidth() then
            subMenu:setX(self.x - subW - 1)
        else
            subMenu:setX(self.x + ww + 1)
        end
    end

    self:checkHighlightedOption(highlightedOption)
    if not showTooltip and self.player == 0 then self:hideToolTip() end
end

local SUB_MS = 140

--- A sub menu just shown (no frame drawn of it a moment ago): its height so
--- far, its plate's and its options' alpha; nil when out.
local function subOpenOf(menu)
    if T.animOn and not T.animOn() then return nil end
    local now = getTimestampMs()
    if not menu.knoxSubLast or now - menu.knoxSubLast > 120 then menu.knoxSubMs = now end
    menu.knoxSubLast = now
    local t = (now - menu.knoxSubMs) / SUB_MS
    if t >= 1 then return nil end
    local e = ease(t)
    return math.max(1, math.floor(menu.height * (0.3 + 0.7 * e) + 0.5)), e, ease((t - 0.25) / 0.75)
end

function ISContextMenu:render()
    self.visibleCheck = true
    if self:isEmpty() then return end
    ensure(self)
    -- turning from a tooltip: cut to the plate's height as it goes from the tooltip's to its own;
    -- a sub menu coming out: it unfolds down and fades in
    local visH, plateA, rowsA = morphOf(self)
    if not visH and self.parent then visH, plateA, rowsA = subOpenOf(self) end
    if visH then self:setStencilRect(0, 0, self.width + 8, visH) end
    renderMenu(self, visH, plateA, rowsA)
    if visH then self:clearStencilRect() end
end
