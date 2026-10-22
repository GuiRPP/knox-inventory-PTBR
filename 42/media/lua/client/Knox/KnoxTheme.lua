-- Look of the whole mod in one place: colors, sizes, fonts.
-- Colors match the approved mockup (dark Tarkov palette, sand accent).

KnoxTheme = KnoxTheme or {}
local T = KnoxTheme

-- Which of Knox's mods this is: the released one ("KnoxInventory") or the beta
-- shipped next to it in the same Workshop item ("KnoxInventoryBeta", 2026-10-20).
-- The beta's build writes shared/Knox/KnoxModId.lua (tools/prepare_workshop.ps1);
-- the mod's own files (news) are read under this id. Both ids count as Knox in a
-- save's mods (KnoxSaveGuard); the two can't be on together (mod.info incompatible).
T.MOD_IDS = {"KnoxInventory", "KnoxInventoryBeta"}
T.MOD_ID = KnoxModId or "KnoxInventory"

-- Knox Inventory runs on its Java part (KnoxInventoryJava.jar, loaded by
-- ZombieBuddy): Knox's fonts, tooltips, model framing, the live character.
-- Without it (ZombieBuddy missing or not started, or an older jar) nothing of
-- the game is replaced - the player gets the game's own UI and a message.
-- (raised with every change of the jar: Lua of one release with the jar of
-- another, both "22", failed on calls the older jar lacked - 0.9.5, 14.10.2026)
T.JAVA_NEEDED = 57
T.javaVersion = knoxJavaVersion and tonumber(knoxJavaVersion()) or nil
T.active = T.javaVersion ~= nil and T.javaVersion >= T.JAVA_NEEDED

-- Settings: Zomboid/Lua/knox_settings.txt, "key=value" lines. Read once, when
-- the Lua loads (much of the mod decides what to replace right then).
local SETTINGS_FILE = "knox_settings.txt"
T.settings = {}
do
    local r = getFileReader(SETTINGS_FILE, false)
    if r then
        local line = r:readLine()
        while line do
            local k, v = string.match(line, "^%s*([%w_%.]+)%s*=%s*(.-)%s*$")
            if k then T.settings[k] = v end
            line = r:readLine()
        end
        r:close()
    end
end

function T.saveSettings()
    local w = getFileWriter(SETTINGS_FILE, true, false)
    if not w then return end
    local keys = {}
    for k in pairs(T.settings) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do w:write(k .. "=" .. tostring(T.settings[k]) .. "\r\n") end
    w:close()
end

-- Modules: the parts of the mod a player can switch off, each leaving the
-- game's own screens in its place - each on its own, so that the game's (or
-- another mod's) inventory can go with Knox's windows and the other way round.
-- In a game:
--   inventory  the Knox screen on the inventory key (bag windows, inspect, search; the
--              world's clicks on containers, Viewpoint's loot key and Grab go to it)
--   hotbar     the quick slots bar in the world in Knox's look, with the hands
--              (off: the game's bar - or another mod's, Clean UI and the like)
--   devices    the TV and radio windows
--   stove      the stove / oven / microwave window
--   fluids     the window for pouring fluids
--   tooltips   item tooltips in Knox's look
--   menus      right-click menus and the game's question boxes in Knox's look
--   dashboard  the car's dashboard and its radio with the player's music (KnoxDashboard)
--   health     the inventory screen's Health tab and the health key (KnoxHealthPanel;
--              off: the game's health window - and with the inventory module off)
-- Outside a game:
--   menu       the main menu's camp, its items and the news cards
--   newgame    game mode, spawn, sandbox, character creation, the loading screen, Load / Options / Mods
-- A switch works from the next load of the Lua (T.setModule only writes it down).
-- (health: put off until 2.0 by the author, 2026-10-19 - not in the list, off for
-- players; on only where the settings file has dev.health=1, the developer's bench)
T.MODULE_GROUPS = {
    {id = "game", list = {"inventory", "hotbar", "devices", "stove", "fluids", "tooltips", "menus", "dashboard"}},
    {id = "out", list = {"menu", "newgame"}},
}
T.MODULES = {}
for _, g in ipairs(T.MODULE_GROUPS) do
    for _, name in ipairs(g.list) do table.insert(T.MODULES, name) end
end
-- (up to 0.9.8: one "ingame" switch for all the parts in a game - a player who had
-- it off has each of them off, until they are set one by one)
if T.settings["module.ingame"] == "0" then
    for _, name in ipairs(T.MODULE_GROUPS[1].list) do
        if T.settings["module." .. name] == nil then T.settings["module." .. name] = "0" end
    end
end
T.settings["module.ingame"] = nil
T.modules = {}
for _, name in ipairs(T.MODULES) do T.modules[name] = T.settings["module." .. name] ~= "0" end
T.modules.health = T.settings["dev.health"] == "1"

--- Does this part of the mod replace the game's? (Never without the Java part.)
function T.on(name)
    return T.active and T.modules[name] == true
end

--- Is the switch as the player left it (which may differ from what runs until the Lua reloads)?
function T.moduleSaved(name)
    return T.settings["module." .. name] ~= "0"
end

function T.setModule(name, on)
    T.settings["module." .. name] = on and "1" or "0"
end

-- Look of the inventory screen, the player's to set (the settings window's sliders):
--   look.all    the master: 0..100 %, multiplies every opacity below (0 = nothing but the
--               tiles, frames and text is left)
--   look.bg     how solid the background is: the veil over the world, the columns' panels,
--               the top and bottom bars, the lists and section headers
--   look.grid   how solid the grids are: the cells' own background, and with it how strong
--               the grid's lines are (they never go below a third)
--   look.line   how thick the grid's lines are, 1..4 px
--   look.slot   how solid the slots are: equipment, hands, back, quick slots
--   look.model  how solid the box behind the 3D character is
-- All at 100 % and 1 px is the look as designed. Tiles, frames and text stay as they are.
T.LOOK = {
    {key = "look.all", min = 0, max = 100, step = 5, default = 100, unit = "%"},
    {key = "look.bg", min = 0, max = 100, step = 5, default = 100, unit = "%"},
    {key = "look.grid", min = 0, max = 100, step = 5, default = 100, unit = "%"},
    {key = "look.line", min = 1, max = 4, step = 1, default = 1, unit = " px"},
    {key = "look.slot", min = 0, max = 100, step = 5, default = 100, unit = "%"},
    {key = "look.model", min = 0, max = 100, step = 5, default = 100, unit = "%"},
    -- not a look: how long the search of a container takes, of the time it was made
    -- with (KnoxSearch) - asked for by a player, 2026-10-13
    {key = "search.time", min = 25, max = 400, step = 25, default = 100, unit = "%", page = "game"},
    -- how loud the search is: the hands in the container, each thing found (KnoxSearchSound; 0 = silent)
    {key = "search.sound", min = 0, max = 200, step = 10, default = 100, unit = "%", page = "game"},
    -- how loud handling things is: lifted, put down, turned, a bag's window (KnoxUISound; 0 = silent)
    {key = "ui.sound", min = 0, max = 200, step = 10, default = 100, unit = "%", page = "game"},
    -- how many cells bags and pockets have, of Knox's own (KnoxFootprint.gridScale; the
    -- third most common complaint, "too little room" - 2026-10-19)
    {key = "grid.scale", min = 50, max = 200, step = 10, default = 100, unit = "%", page = "game"},
    -- how loud the other players' own music is, heard from their cars (KnoxMusicNet)
    {key = "music.others", min = 0, max = 200, step = 10, default = 70, unit = "%", page = "game"},
    -- the custom skin's main colour (KnoxTheme skins; drawn in the settings' skin block)
    {key = "skin.hue", min = 0, max = 355, step = 5, default = 45, unit = "", page = "skin"},
    {key = "skin.sat", min = 0, max = 100, step = 5, default = 45, unit = "%", page = "skin"},
    {key = "skin.val", min = 30, max = 100, step = 5, default = 85, unit = "%", page = "skin"},
}

-- (by key: T.look is asked many times a frame - every grid, panel and slot's alpha)
local LOOK_BY_KEY = {}
for _, s in ipairs(T.LOOK) do LOOK_BY_KEY[s.key] = s end

function T.look(key)
    local s = LOOK_BY_KEY[key]
    if not s then return 0 end
    local v = tonumber(T.settings[key])
    if not v then return s.default end
    return math.max(s.min, math.min(s.max, math.floor(v + 0.5)))
end

-- Animations of the inventory (tiles settling, grids unrolling, bars and hints
-- easing): on unless the player switched them off in the settings. Every one
-- of them passes its progress (0..1, or its easing step) through T.anim: with
-- the animations off it is done at once.
function T.animOn() return T.settings["anim"] ~= "0" end

function T.anim(t)
    if T.settings["anim"] == "0" then return 1 end
    return t
end

--- Where a scrolled panel's grids go on past its edge, they fade into the column
--- instead of being cut off: a soft band at the bottom while there is more below,
--- at the top while there is more above; each comes and goes smoothly. `ui` keeps
--- its state (fadeTop, fadeBottom); `contentH` its content's height; x0, w the
--- band's left and width; `dt` ms since the last frame. Drawn in its render, over
--- what it holds. (The inventory column's, then the Surroundings' grid too - the
--- author, 2026-10-22.)
function T.edgeFades(ui, contentH, x0, w, dt)
    local h = ui:getHeight()
    local ys = ui:getYScroll()
    local below = contentH + ys - h > 1
    local above = ys < -1
    local step = T.anim(math.min(1, dt / 120))
    ui.fadeBottom = (ui.fadeBottom or 0) + ((below and 1 or 0) - (ui.fadeBottom or 0)) * step
    ui.fadeTop = (ui.fadeTop or 0) + ((above and 1 or 0) - (ui.fadeTop or 0)) * step
    if ui.fadeBottom <= 0.01 and ui.fadeTop <= 0.01 then return end
    local band = math.floor(T.cell * 1.3)
    local c = T.color.window
    local strip = 2
    for i = 0, band - 1, strip do
        -- (eased: nearly clear where it starts, nearly the column's own colour at the edge)
        local f = 1 - i / band
        local a = f * f * 0.95
        if ui.fadeBottom > 0.01 then
            ui:drawRect(x0, h - i - strip - ys, w, strip, a * ui.fadeBottom, c.r, c.g, c.b)
        end
        if ui.fadeTop > 0.01 then
            ui:drawRect(x0, i - ys, w, strip, a * ui.fadeTop, c.r, c.g, c.b)
        end
    end
end

-- Switches of the inventory in the settings (they work at once). `page`: the
-- settings' page a switch or a slider of T.LOOK is on - "look" unless said, or
-- "game" for what changes how the inventory plays, not how it looks:
--   anim    the animations above
--   search  containers not looked into yet are searched, thing by thing (KnoxSearch)
--   news    the news cards in the main menu's corner (Bazusa and others, 2026-10-19:
--           "they cover the third hero"); the news page in the screen stays
T.SWITCHES = {
    {key = "anim", default = true},
    {key = "news", default = true},
    {key = "search", default = false, new = true, page = "game"},   -- (new: marked so in the settings)
    -- scatter  things found in furniture, cars and bodies lie at random places, not
    --          packed in rows (KnoxGrid.build; the author, 2026-10-19)
    {key = "scatter", default = true, new = true, page = "game"},
    -- musicShare  one's own music in the car heard by the players near it, in a game
    --             with others (KnoxMusicNet: only its hash, size and kind go out)
    -- musicHear   the others' own music heard here (and fetched when not here)
    {key = "musicShare", default = true, new = true, page = "game"},
    {key = "musicHear", default = true, new = true, page = "game"},
}

-- Choices of the inventory in the settings: one of a few values, shown as a row
-- of buttons (they work at once).
--   loot.scope  which containers the Surroundings column lists: "all" around the
--               character; "opened" - only the one opened (clicked in the world,
--               Viewpoint's loot key) and the floor; "auto" - "opened" while
--               Viewpoint's own view is on, else "all" (asked for by players, 2026-10-14);
--               OldPoint's overhead camera counts as "all": it sees all around and a
--               body can't be opened with a click (FL, RAGE: "can't open the zombie's
--               inventory", "containers don't open", 2026-10-20)
--               Default "all" since 0.9.7: with "auto" Viewpoint players took the
--               containers gone from the column for a bug (two reports in an hour)
--   order.rule  how Sort lays a grid out (KnoxOrder): by category zones, tight
--               by size, by name, by weight
--   order.auto  where a thing that comes without a place goes: to its place in
--               the bag's layout (else next to its category), next to its
--               category, or the first free cell as before 0.9.8
T.CHOICES = {
    {key = "loot.scope", values = {"auto", "opened", "all"}, default = "all", new = true, page = "game"},
    {key = "order.rule", values = {"zones", "dense", "name", "weight"}, default = "zones", page = "order"},
    {key = "order.auto", values = {"layout", "zones", "off"}, default = "layout", page = "order"},
}

-- (by key: the search's switch is asked for every tile every frame)
local CHOICE_BY_KEY, SWITCH_BY_KEY = {}, {}
for _, c in ipairs(T.CHOICES) do CHOICE_BY_KEY[c.key] = c end
for _, s in ipairs(T.SWITCHES) do SWITCH_BY_KEY[s.key] = s end

function T.choice(key)
    local c = CHOICE_BY_KEY[key]
    if not c then return nil end
    local v = T.settings[key]
    for _, ok in ipairs(c.values) do
        if v == ok then return v end
    end
    return c.default
end

function T.switch(key)
    local v = T.settings[key]
    if v == "0" then return false end
    if v == "1" then return true end
    local s = SWITCH_BY_KEY[key]
    if s then return s.default end
    return false
end

local function part(key) return T.look("look.all") * T.look(key) / 10000 end
function T.bgAlpha() return part("look.bg") end
function T.gridAlpha() return part("look.grid") end
function T.gridLineAlpha() return 0.34 + 0.66 * T.gridAlpha() end
function T.gridLine() return T.look("look.line") end
function T.slotAlpha() return part("look.slot") end
function T.modelAlpha() return part("look.model") end

local function hex(s)
    return {
        r = tonumber(s:sub(2, 3), 16) / 255,
        g = tonumber(s:sub(4, 5), 16) / 255,
        b = tonumber(s:sub(6, 7), 16) / 255,
    }
end

T.color = {
    window   = hex("#121414"),
    header   = hex("#1a1d1d"),
    border   = hex("#2a2e2e"),
    cell     = hex("#0e1010"),
    line     = hex("#242828"),
    tileEdge = hex("#3c4141"),
    hoverEdge = hex("#6a6f6a"),
    tileFrame = hex("#5b615c"),   -- 2 px frame of an item tile, lighter than the grid lines
    tileHover = hex("#8e938a"),
    liquid   = hex("#6fa3d8"),   -- liquid in a container (tile meter)
    text     = hex("#d9d6c8"),
    bright   = hex("#ece8d8"),
    dim      = hex("#8f9289"),
    accent   = hex("#d4c38a"),
    ok       = hex("#6ca050"),
    bad      = hex("#be463c"),
    good     = hex("#9fb36a"),
    warn     = hex("#c9a24a"),
    buttonBg = hex("#1f2323"),
    ink      = hex("#141414"),   -- text on sand
    screen   = hex("#0b0c0c"),   -- the backdrop under the whole Knox screen
}

-- Skins (beta, 2026-10-15: the author's wish) --------------------------------------
-- A skin repaints the palette above in place: the main colour (sand by default)
-- and the dark tones of windows, grids and text. The categories' colours, the
-- liquid, good / bad / warn stay - they say what a thing is or how it is. Every
-- part of the mod reads T.color as it draws, so a skin shows at once.
--   skin       one of T.SKINS' ids, or "custom"
--   skin.hue / skin.sat / skin.val   the main colour of "custom" (0..359, %, %)

local BASE = {}
for k, c in pairs(T.color) do BASE[k] = {r = c.r, g = c.g, b = c.b} end

T.SKINS = {
    {id = "sand"},
    {id = "blood", accent = "#d8705f", window = "#151111", header = "#1d1616", border = "#2e2424", cell = "#100c0c",
     line = "#2a2020", tileEdge = "#443838", hoverEdge = "#745e5e", tileFrame = "#634f4f", tileHover = "#9a8380",
     text = "#ddd2cc", bright = "#f0e6e2", dim = "#978986", buttonBg = "#221a1a", screen = "#0d0909"},
    {id = "pine", accent = "#b5c278", window = "#111411", header = "#181d18", border = "#273027", cell = "#0c100c",
     line = "#212821", tileEdge = "#384238", hoverEdge = "#657063", tileFrame = "#566255", tileHover = "#889483",
     text = "#d3d9c8", bright = "#e7ecdc", dim = "#899282", buttonBg = "#1b221b", screen = "#0a0d0a"},
    {id = "ice", accent = "#8ec5e0", window = "#101317", header = "#171c21", border = "#262e36", cell = "#0b0f12",
     line = "#20272e", tileEdge = "#37414a", hoverEdge = "#627080", tileFrame = "#535e69", tileHover = "#8794a1",
     text = "#d0d8de", bright = "#e6edf2", dim = "#87929b", buttonBg = "#1a2026", screen = "#090c0f"},
    {id = "night", accent = "#86f07e", window = "#070d07", header = "#0c150c", border = "#173017", cell = "#050a05",
     line = "#122412", tileEdge = "#1f4a1f", hoverEdge = "#3f8a3f", tileFrame = "#2f6a2f", tileHover = "#5fb35f",
     text = "#a8f0a0", bright = "#d0ffc8", dim = "#5f9f5a", buttonBg = "#0d1a0d", screen = "#040804"},
    {id = "coal", accent = "#cfcfcf", window = "#121212", header = "#1a1a1a", border = "#2b2b2b", cell = "#0d0d0d",
     line = "#242424", tileEdge = "#3e3e3e", hoverEdge = "#6c6c6c", tileFrame = "#5c5c5c", tileHover = "#8f8f8f",
     text = "#d8d8d8", bright = "#ededed", dim = "#8f8f8f", buttonBg = "#202020", screen = "#0a0a0a"},
    -- a survival-horror mansion: brass on dark olive (asked for as a Resident Evil
    -- look by SmokeGod420; the game's name is not ours to use)
    {id = "mansion", accent = "#d0a24c", window = "#121310", header = "#1a1c17", border = "#2c2f27", cell = "#0d0e0b",
     line = "#25271f", tileEdge = "#3f4236", hoverEdge = "#6d7160", tileFrame = "#5d6151", tileHover = "#8f937f",
     text = "#d8d5c2", bright = "#ece8d2", dim = "#8e8f7e", buttonBg = "#1f211b", screen = "#0a0b08"},
    {id = "custom"},
}

--- The skin chosen (an id of T.SKINS).
function T.skin()
    local s = T.settings["skin"]
    for _, sk in ipairs(T.SKINS) do
        if sk.id == s then return s end
    end
    return "sand"
end

--- A colour from hue (0..359), saturation and value (0..1).
local function hsv(h, s, v)
    h = (h % 360) / 60
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    local r, g, b
    if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
    return {r = r, g = g, b = b}
end
T.hsv = hsv

--- The main colour of the custom skin, from its three sliders.
function T.customAccent()
    return hsv(T.look("skin.hue"), T.look("skin.sat") / 100, T.look("skin.val") / 100)
end

--- Repaint the palette as the chosen skin says (in place: everything holding a
--- colour table sees the change). Also handed to the Java part (tooltips, the
--- loading screen), when it has the call.
function T.applySkin()
    local id = T.skin()
    local over = {}
    for _, sk in ipairs(T.SKINS) do
        if sk.id == id then over = sk end
    end
    for k, base in pairs(BASE) do
        local c = T.color[k]
        local v = over[k]
        local src = (type(v) == "string") and hex(v) or base
        c.r, c.g, c.b = src.r, src.g, src.b
    end
    if id == "custom" then
        local a = T.customAccent()
        T.color.accent.r, T.color.accent.g, T.color.accent.b = a.r, a.g, a.b
    end
    -- the text on a main-colour plate: dark on a light colour, light on a dark one
    local a = T.color.accent
    local lum = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
    local ink = lum > 0.45 and BASE.ink or BASE.bright
    T.color.ink.r, T.color.ink.g, T.color.ink.b = ink.r, ink.g, ink.b
    if knoxSetPalette then pcall(knoxSetPalette, T.color) end
    -- the mouse cursor in the skin's main colour (the Java part repaints the arrow)
    if knoxCursorTint then pcall(knoxCursorTint, a.r, a.g, a.b, id) end
end

T.category = {
    wpn  = hex("#2a2f22"),
    med  = hex("#3b2427"),
    food = hex("#24331f"),
    ammo = hex("#3a321c"),
    tool = hex("#1f2d38"),
    clo  = hex("#2b2a33"),
    info = hex("#302640"),
    mat  = hex("#2f2a24"),
    misc = hex("#262929"),
}

local CATEGORY_BY_DISPLAY = {
    Ammo = "ammo", WeaponPart = "ammo",
    FirstAid = "med",
    Food = "food", Water = "food", WaterContainer = "food", Cooking = "food",
    Tool = "tool", Electronics = "tool", Communications = "tool", LightSource = "tool",
    VehicleMaintenance = "tool", Gardening = "tool", Fishing = "tool", Trapping = "tool",
    Clothing = "clo", Container = "clo", Bag = "clo", Accessory = "clo",
    Literature = "info", SkillBook = "info", Key = "info", Security = "info",
    Cartography = "info", Memento = "info",
    Material = "mat", Camping = "mat",
    Weapon = "wpn", WeaponCrafted = "wpn", Explosives = "wpn",
}

local function categoryOfType(item, ft)
    -- the player's own (knox_overrides.txt: "Base.Bleach = category mat")
    local o = KnoxFootprint and KnoxFootprint.overrides[ft]
    if o and o.cat then return o.cat end
    local c = CATEGORY_BY_DISPLAY[item:getDisplayCategory() or ""]
    if c then return c end
    if instanceof(item, "HandWeapon") then return "wpn" end
    if instanceof(item, "Food") then return "food" end
    if instanceof(item, "Clothing") or instanceof(item, "InventoryContainer") then return "clo" end
    if instanceof(item, "Literature") or instanceof(item, "Key") then return "info" end
    return "misc"
end

-- (kept by type: every tile, slot and quick slot asks it every frame, two to six
-- calls into the game each, and a type's category is the same for all its things;
-- made anew when the player's own sizes are read anew - a server's, KnoxFootprint.useOverrides)
local catCache, catFor = {}, nil

function T.categoryOf(item)
    local ft = item:getFullType()
    local overrides = KnoxFootprint and KnoxFootprint.overrides
    if catFor ~= overrides then catCache, catFor = {}, overrides end
    local c = catCache[ft]
    if c then return c end
    c = categoryOfType(item, ft)
    catCache[ft] = c
    return c
end

-- Fonts -----------------------------------------------------------------------
-- A font is a handle: one of Knox's own Fira Sans Extra Condensed atlases
-- {knox = true, style, size, key}, or one of the game's UIFont values (a
-- language Knox's atlases can't write). Draw and measure text only through
-- the helpers below, they handle both.
--   styles: "title" (bold), "body" (medium), "head" (semibold, letter-spaced,
--   for labels in capitals: tabs, buttons, section titles, tile names)

local function knoxFont(style, size)
    size = math.max(10, math.min(44, math.floor(size + 0.5)))
    return {knox = true, style = style, size = size, key = style .. "_" .. size}
end
T.makeFont = knoxFont   -- only valid when T.javaFonts

--- Biggest game font (with Cyrillic) not taller than `limit`, for the fallback.
local function gameFontUpTo(limit)
    local tm = getTextManager()
    local best, bestH, smallest, smallestH
    for _, name in ipairs({"Small", "NewSmall", "Medium", "NewMedium"}) do
        local f = UIFont[name]
        if f then
            local h = tm:getFontHeight(f)
            if h <= limit and (not bestH or h > bestH) then best, bestH = f, h end
            if not smallestH or h < smallestH then smallest, smallestH = f, h end
        end
    end
    return best or smallest
end
T.gameFontUpTo = gameFontUpTo

--- Can Knox's atlases write the game's language? Checked on a few of the
--- game's own strings (Knox's are in English for most languages); Chinese,
--- Japanese, Korean, Thai, Arabic... are not in them.
local LANGUAGE_PROBES = {"ContextMenu_Drop", "ContextMenu_Wear", "ContextMenu_Equip_Primary",
                         "Tooltip_item_Weight", "Tooltip_weapon_Condition"}
local function languageCovered()
    if not T.active then return false end
    local parts = {}
    for _, key in ipairs(LANGUAGE_PROBES) do
        local s = getTextOrNull(key)
        if s then table.insert(parts, s) end
    end
    return knoxFontCovers(table.concat(parts, " ")) == true
end

--- Sizes follow the screen: 48 px cells at 1080p, 64 px at 1440p, 96 px at
--- 2160p; narrow screens (5:4, 4:3) go by width instead, so the three columns
--- (about 34 cells side by side) still fit. Font sizes follow the cell (at
--- 48 px: the mockup's 20 / 17 / 15 / 14 / 12 px).
--- 1280x720: 32, 1366x768: 34, 1280x1024: 37, 1920x1080: 48, 3440x1440: 64.
function T.refresh()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local byHeight = sh * 48 / 1080
    local byWidth = (sw - 8) / 34
    T.cell = math.max(30, math.floor(math.min(byHeight, byWidth) + 0.5))
    T.pad = math.floor(T.cell / 4)
    T.gap = math.floor(T.cell / 4)

    local c = T.cell
    -- the Java part draws Knox's own atlases; if they lack the language's
    -- letters (or are still loading), the game's fonts are used
    T.languageOk = languageCovered()
    T.javaFonts = T.active and T.languageOk and knoxFontReady("body", c * 0.31) == true
    if T.javaFonts then
        T.fontHeader = knoxFont("title", c * 0.42)   -- column and window titles
        T.fontTab = knoxFont("head", c * 0.36)       -- top bar tabs
        T.fontText = knoxFont("body", c * 0.31)      -- body text, values
        T.fontCaps = knoxFont("head", c * 0.29)      -- section titles, buttons, labels
        T.fontTile = knoxFont("head", c * 0.25)      -- tile names, small labels
    else
        T.fontHeader = UIFont.Medium
        T.fontTab = UIFont.Medium
        T.fontText = UIFont.Small
        T.fontCaps = UIFont.Small
        T.fontTile = gameFontUpTo(c * 0.32)
    end
    T.fontTileH = T.fontH(T.fontTile)
    T.headerH = T.fontH(T.fontHeader) + T.pad
    T.sectionH = T.fontH(T.fontCaps) + math.floor(T.pad / 2)
end

--- Sizes and fonts ready for drawing outside the Knox screen (hotbar, menus,
--- tooltips). Knox's font atlases load in the background: drawn before they
--- were ready, the game's fonts were kept until the Knox screen opened, so
--- this looks again now and then until they are.
local nextFontCheck = 0
function T.ensure()
    if not T.cell then T.refresh() return end
    if T.javaFonts or not T.languageOk or not T.active then return end
    local now = getTimestampMs()
    if now < nextFontCheck then return end
    nextFontCheck = now + 500
    if knoxFontReady("body", T.cell * 0.31) == true then T.refresh() end
end

-- Knox's atlases' heights and widths, kept by atlas: a caption is measured several
-- times a frame (its band, its plate, its row), each a call into the Java part, and
-- an atlas's metrics never change once it is read (AngelCodeFont parses its .fnt
-- when it is made; only its picture loads later). The game's own fonts are asked
-- each time (the player may change their size).
local heightOf = {}
local widthOf, widthN = {}, {}
local WIDTHS_MAX = 3000   -- texts kept per atlas (item names come and go): let go of beyond

function T.fontH(font)
    if type(font) == "table" then
        local h = heightOf[font.key]
        if not h then
            h = knoxFontHeight(font.style, font.size)
            heightOf[font.key] = h
        end
        return h
    end
    return getTextManager():getFontHeight(font)
end

function T.measure(font, s)
    if s == nil or s == "" then return 0 end
    if type(font) == "table" then
        local key = font.key
        local c = widthOf[key]
        local w = c and c[s]
        if w then return w end
        w = knoxTextWidth(font.style, font.size, s)
        if not c or widthN[key] >= WIDTHS_MAX then
            c = {}
            widthOf[key], widthN[key] = c, 0
        end
        c[s] = w
        widthN[key] = widthN[key] + 1
        return w
    end
    return getTextManager():MeasureStringX(font, s)
end

--- Draw dark text in the very middle of a plate x, y, w, h: by where its
--- pixels are (the Java part's knoxTextInk), not by the font's width and line
--- height, which count the spacing after the last letter and the room for
--- accents and tails - a digit centred by those sits off the middle.
-- (kept by font and text: every caption asks twice a frame - its own box and a
-- capital's - each a call into Java and a pattern match; emptied when it grows)
local inkCache, inkCount = {}, 0

local function inkBox(font, s)
    if type(font) == "table" and knoxTextInk then
        local key = font.key .. "|" .. s
        local box = inkCache[key]
        if box then return box[1], box[2], box[3], box[4] end
        local ink = knoxTextInk(font.style, font.size, s)
        local l, t, r, b = string.match(ink or "", "^(-?%d+),(-?%d+),(-?%d+),(-?%d+)$")
        if l then
            box = {tonumber(l), tonumber(t), tonumber(r), tonumber(b)}
            inkCount = inkCount + 1
            if inkCount > 4000 then inkCache, inkCount = {}, 1 end
            inkCache[key] = box
            return box[1], box[2], box[3], box[4]
        end
    end
    return 0, 0, T.measure(font, s), T.fontH(font)
end

function T.inkCentre(ui, s, x, y, w, h, r, g, b, a, font)
    font = font or T.fontCaps
    local left, _, right = inkBox(font, s)
    -- Up and down by a plain capital's height, whatever the text: letters with a
    -- tail (Д, Щ, Ц) or a mark (Ё, Й) moved a caption off the line, and a number
    -- next to it then sat on another level ("НАЙДЕНО 4" - seen 2026-10-14). So
    -- every caption and number in a bar of the same height stands on one line.
    local _, top, _, bottom = inkBox(font, "H")
    local tx = x + math.floor((w - (right - left)) / 2 + 0.5) - left
    local ty = y + math.floor((h - (bottom - top)) / 2 + 0.5) - top
    -- (a number starting with "1": by its pixels it looks pushed right - the eye
    -- takes its stem, not its flag, for its middle; a pixel back, as type is set)
    if string.sub(s, 1, 1) == "1" and string.find(s, "^%d+$") then tx = tx - 1 end
    if ui == nil then return tx, ty end   -- (asked only where the text would start: T.inkOrigin)
    T.drawText(ui, s, tx, ty, r, g, b, a, font)
    if T.layoutDebug() and s ~= "" then T.debugInk(ui, {x, y, w, h}, tx, ty, s, font, true) end
end

--- Text from x, in the middle of the height h from y by its pixels (a caption
--- on a bar or a button: by the font's line height capitals sit too high).
function T.inkLeft(ui, s, x, y, h, c, font, a)
    font = font or T.fontCaps
    local tx, ty = T.inkOrigin(s, x, y, T.measure(font, s), h, font)
    local w = T.measure(font, s)
    -- (horizontally the text starts at x as usual; only the height is by the ink)
    T.drawText(ui, s, x, ty, c.r, c.g, c.b, a or 1, font)
    return w, tx
end

-- The layout kit -----------------------------------------------------------------
--
-- Every caption, number and small framed button goes through these. They put
-- text in its band by its pixels (the rule of T.inkCentre) and draw the framed
-- square buttons one way, so a new piece stands right by construction and no
-- text is centred by hand (the author, 2026-10-20: every new thing needed
-- checking whether its text sat in the middle and its margins matched).
--   T.label(ui, s, r, c, opts)       text in a band r = {x, y, w, h}
--   T.plate(ui, r, s, opts)          a plate with its text in the middle
--   T.iconButton(ui, r, glyph, hot)  the framed square of a header (fold, close...)
-- tools/uilint flags centring by hand in new code. The "Layout" overlay
-- (DEV panel, or dev.layout=1 in knox_settings.txt) shows each band and where
-- its letters are, red where they are off the middle.

--- Is the "Layout" overlay on?
function T.layoutDebug()
    return T.settings["dev.layout"] == "1"
end

function T.setLayoutDebug(on)
    T.settings["dev.layout"] = on and "1" or nil
    T.saveSettings()
end

--- (the overlay over one piece of text: its band in blue, its letters' box in
--- violet - red when centred and more than a pixel off the band's middle)
function T.debugInk(ui, r, tx, ty, s, font, centred)
    local left, top, right, bottom = inkBox(font, s)
    local _, capTop, _, capBottom = inkBox(font, "H")
    local ix, iy, iw = tx + left, ty + capTop, right - left
    local ih = capBottom - capTop
    local off = math.abs((iy + ih / 2) - (r[2] + r[4] / 2)) > 1
    if centred then off = off or math.abs((ix + iw / 2) - (r[1] + r[3] / 2)) > 1 end
    ui:drawRectBorder(r[1], r[2], r[3], r[4], 0.8, 0.2, 0.7, 1)
    if off then
        ui:drawRectBorder(ix, iy, iw, ih, 1, 1, 0.15, 0.15)
    else
        ui:drawRectBorder(ix, iy, iw, ih, 0.8, 0.85, 0.3, 0.9)
    end
end

--- Text in the band r = {x, y, w, h}: up and down by a capital's pixels;
--- opts.align "left" (default: starts at x), "right" (ends at x + w) or
--- "centre" (by its pixels). opts.font (T.fontCaps), opts.a. Returns its width.
function T.label(ui, s, r, c, opts)
    opts = opts or {}
    local font = opts.font or T.fontCaps
    local align = opts.align or "left"
    s = s or ""
    local w = T.measure(font, s)
    local tx, ty
    if align == "centre" then
        tx, ty = T.inkOrigin(s, r[1], r[2], r[3], r[4], font)
    else
        local _, oy = T.inkOrigin(s, r[1], r[2], w, r[4], font)
        tx, ty = align == "right" and (r[1] + r[3] - w) or r[1], oy
    end
    T.drawText(ui, s, tx, ty, c.r, c.g, c.b, opts.a or 1, font)
    if T.layoutDebug() and s ~= "" then T.debugInk(ui, r, tx, ty, s, font, align == "centre") end
    return w
end

-- (the options handed on to T.label by the kit's own pieces: filled in, not made
-- anew - they are drawn every frame, and T.label only reads them)
local plateOpts = {align = "centre"}
local buttonOpts = {align = "centre"}
local hintPlate, hintPlateOpts = {0, 0, 0, 0}, {}
local hintBand, hintBandOpts = {0, 0, 0, 0}, {}

--- A plate r with `s` in its middle. opts: fill (a color; none: not filled),
--- edge (a color for a 1 px frame), thick (true: the frame 2 px), color (the
--- text's: T.color.text), font, a.
function T.plate(ui, r, s, opts)
    opts = opts or {}
    local a = opts.a or 1
    if opts.fill then T.rect(ui, r[1], r[2], r[3], r[4], opts.fill, a) end
    if opts.edge then
        if opts.thick then T.tileFrame(ui, r[1], r[2], r[3], r[4], opts.edge, a) else T.border(ui, r[1], r[2], r[3], r[4], opts.edge, a) end
    end
    if s and s ~= "" then
        plateOpts.font, plateOpts.a = opts.font, a
        T.label(ui, s, r, opts.color or T.color.text, plateOpts)
    end
end

--- Width of a plate for `s`: its text and a pad and a half each side.
function T.plateW(s, font)
    return T.measure(font or T.fontCaps, s or "") + math.floor(T.pad * 1.5) * 2
end

--- The framed square button of a header r = {x, y, s, s}: grey frame, sand
--- under the mouse (`hot`); glyph "down", "up", "right", "left" (an angle of
--- 2 px dots) or "close" (the cross). opts.off: dimmed.
function T.iconButton(ui, r, glyph, hot, opts)
    local off = opts and opts.off
    if glyph == "close" then return T.closeButton(ui, r[1], r[2], r[3], hot and not off) end
    local on = hot and not off
    T.border(ui, r[1], r[2], r[3], r[4], on and T.color.accent or T.color.tileEdge)
    local c = off and T.color.dim or (on and T.color.accent or T.color.text)
    local cs = math.max(2, math.floor(r[3] / 5))
    local cx, cy = r[1] + math.floor(r[3] / 2), r[2] + math.floor(r[4] / 2)
    local h = math.floor(cs / 2)
    for i = 0, cs do
        if glyph == "down" then
            ui:drawRect(cx - cs + i, cy - h + i, 2, 2, 1, c.r, c.g, c.b)
            ui:drawRect(cx + cs - i, cy - h + i, 2, 2, 1, c.r, c.g, c.b)
        elseif glyph == "up" then
            ui:drawRect(cx - cs + i, cy + h - i, 2, 2, 1, c.r, c.g, c.b)
            ui:drawRect(cx + cs - i, cy + h - i, 2, 2, 1, c.r, c.g, c.b)
        elseif glyph == "right" then
            ui:drawRect(cx - h + i, cy - cs + i, 2, 2, 1, c.r, c.g, c.b)
            ui:drawRect(cx - h + i, cy + cs - i, 2, 2, 1, c.r, c.g, c.b)
        else   -- left
            ui:drawRect(cx + h - i, cy - cs + i, 2, 2, 1, c.r, c.g, c.b)
            ui:drawRect(cx + h - i, cy + cs - i, 2, 2, 1, c.r, c.g, c.b)
        end
    end
end

--- The margin of the things in a bar of height h (plates, buttons, the close
--- cross): the same above, below, at the right end and between them. A fifth
--- of the bar (4 px flat looked cramped - seen in game 2026-10-14).
function T.barMargin(h)
    return math.max(5, math.floor(h * 0.2 + 0.5))
end

--- Width of a count plate for `text` in a bar of height h.
function T.countPlateW(text, h)
    local bh = h - T.barMargin(h) * 2
    return math.max(bh, T.measure(T.fontCaps, text) + math.floor(bh * 0.6))
end

--- A count on a small plate in a bar (a header, a button): sand with a dark
--- number when `on`, grey with a dim one when not. The bar's margin above and
--- below it (T.barMargin), its right edge at `right` (the caller leaves the
--- margin to the next thing). `st`: a table kept with the plate (the number
--- rolls when it changes). `inset`: so many pixels less above and below (next
--- to framed buttons of the bar's height a solid plate looks taller). Returns
--- the plate's left x.
function T.countPlate(ui, st, text, right, y, h, on, inset, a)
    local f = T.fontCaps
    a = a or 1
    local m = T.barMargin(h) + (inset or 0)
    local bh = h - m * 2
    local bw = math.max(bh, T.countPlateW(text, h) - (inset or 0) * 2)
    local bx, by = right - bw, y + m
    T.rect(ui, bx, by, bw, bh, on and T.color.accent or T.color.tileEdge, a)
    if on then
        T.rollNumber(ui, st, text, bx, by, bw, bh, 0.08, 0.08, 0.08, a, f)
    else
        st.text = text
        local c = T.color.dim
        T.inkCentre(ui, text, bx, by, bw, bh, c.r, c.g, c.b, a, f)
    end
    return bx
end
--- Where T.inkCentre would start drawing `s` in the box: x, y.
function T.inkOrigin(s, x, y, w, h, font)
    return T.inkCentre(nil, s, x, y, w, h, 0, 0, 0, 1, font)
end

--- A number on a plate that rolls when it changes, as the clock's digits do:
--- a digit that changed goes up and out, the new one comes up from under it,
--- the rest stand still (a number of another length rolls whole). `st`: a table
--- kept with the plate - it remembers the number shown before.
function T.rollNumber(ui, st, s, x, y, w, h, r, g, b, a, font)
    font = font or T.fontCaps
    local now = getTimestampMs()
    if st.text ~= s then
        st.old, st.rollMs = st.text, now
        st.text = s
    end
    local old = st.old
    local t = (old and old ~= "") and T.anim((now - (st.rollMs or 0)) / 180) or 1
    if t >= 1 or s == "" then
        if s ~= "" then T.inkCentre(ui, s, x, y, w, h, r, g, b, a, font) end
        return
    end
    local k = 1 - (1 - t) * (1 - t)
    local rise = math.floor(h * 0.42)
    local up, down = -math.floor(rise * k + 0.5), math.floor(rise * (1 - k) + 0.5)
    if #old ~= #s then
        T.inkCentre(ui, old, x, y + up, w, h, r, g, b, a * (1 - k), font)
        T.inkCentre(ui, s, x, y + down, w, h, r, g, b, a * k, font)
        return
    end
    local tx, ty = T.inkOrigin(s, x, y, w, h, font)
    for i = 1, #s do
        local ch, was = string.sub(s, i, i), string.sub(old, i, i)
        local cx = tx + T.measure(font, string.sub(s, 1, i - 1))
        if ch == was then
            T.drawText(ui, ch, cx, ty, r, g, b, a, font)
        else
            T.drawText(ui, was, cx, ty + up, r, g, b, a * (1 - k), font)
            T.drawText(ui, ch, cx, ty + down, r, g, b, a * k, font)
        end
    end
end
--- Draw text at x,y of element `ui` (same arguments as ISUIElement:drawText).
function T.drawText(ui, s, x, y, r, g, b, a, font)
    if s == nil or not ui.javaObject then return end
    font = font or T.fontText
    if type(font) == "table" then
        knoxDrawText(font.style, font.size, s, ui:getAbsoluteX() + x + ui:getXScroll(),
            ui:getAbsoluteY() + y + ui:getYScroll(), r, g, b, a)
    else
        ui:drawText(s, x, y, r, g, b, a, font)
    end
end

function T.drawTextRight(ui, s, x, y, r, g, b, a, font)
    T.drawText(ui, s, x - T.measure(font or T.fontText, s), y, r, g, b, a, font)
end

function T.drawTextCentre(ui, s, x, y, r, g, b, a, font)   -- uilint: ok (old code; new: T.label)
    T.drawText(ui, s, x - math.floor(T.measure(font or T.fontText, s) / 2), y, r, g, b, a, font)
end

-- Upper case, Cyrillic included. Labels in capitals: tabs, buttons, section
-- titles, tile names. Kahlua strings are Java strings (one character per
-- string.byte code); Cyrillic is shifted by hand in case string.upper leaves it.
-- (the text caches below are emptied when they grow large: item names, widths)
local CACHE_MAX = 4000
local upperCache, upperCount = {}, 0

function T.upper(s)
    if s == nil then return s end
    local hit = upperCache[s]
    if hit then return hit end
    upperCount = upperCount + 1
    if upperCount > CACHE_MAX then upperCache, upperCount = {}, 1 end
    local src = string.upper(s)
    local parts = {}
    for i = 1, string.len(src) do
        local b = string.byte(src, i)
        if b >= 1072 and b <= 1103 then b = b - 32          -- а..я
        elseif b >= 1104 and b <= 1119 then b = b - 80 end  -- ѐ..џ (ё, є, і, ї, ў)
        parts[i] = string.char(b)
    end
    local out = table.concat(parts)
    upperCache[s] = out
    return out
end

-- Lower case, Cyrillic included (searching item names: "Бинт" is found by "бинт").
local lowerCache, lowerCount = {}, 0

function T.lower(s)
    if s == nil then return s end
    local hit = lowerCache[s]
    if hit then return hit end
    lowerCount = lowerCount + 1
    if lowerCount > CACHE_MAX then lowerCache, lowerCount = {}, 1 end
    local src = string.lower(s)
    local parts = {}
    for i = 1, string.len(src) do
        local b = string.byte(src, i)
        if b >= 1040 and b <= 1071 then b = b + 32          -- А..Я
        elseif b >= 1024 and b <= 1039 then b = b + 80 end  -- Ѐ..Џ (Ё, Є, І, Ї, Ў)
        parts[i] = string.char(b)
    end
    local out = table.concat(parts)
    lowerCache[s] = out
    return out
end
-- Drawing helpers -----------------------------------------------------------

function T.rect(ui, x, y, w, h, c, a)
    ui:drawRect(x, y, w, h, a or 1, c.r, c.g, c.b)
end

function T.border(ui, x, y, w, h, c, a)
    ui:drawRectBorder(x, y, w, h, a or 1, c.r, c.g, c.b)
end

--- Frame of an item tile or a filled slot: 2 px, `c` (default T.color.tileFrame).
--- (four 2 px bands, the same pixels as two 1 px frames: half the draws - it
--- is drawn for every tile every frame)
function T.tileFrame(ui, x, y, w, h, c, a)
    c = c or T.color.tileFrame
    a = a or 1
    ui:drawRect(x, y, w, 2, a, c.r, c.g, c.b)
    ui:drawRect(x, y + h - 2, w, 2, a, c.r, c.g, c.b)
    ui:drawRect(x, y + 2, 2, h - 4, a, c.r, c.g, c.b)
    ui:drawRect(x + w - 2, y + 2, 2, h - 4, a, c.r, c.g, c.b)
end

function T.inRect(x, y, r)
    return x >= r[1] and y >= r[2] and x < r[1] + r[3] and y < r[2] + r[4]
end

--- Close button of a window header: a frame with a cross, sand on hover. Its
--- frame is a button's: 1 px grey at rest, 2 px sand under the mouse (as every
--- sand frame - a 1 px sand one beside a button's 2 px looked of another kind,
--- 2026-10-14).
function T.closeButton(ui, x, y, s, hover)
    local c = hover and T.color.accent or T.color.text
    if hover then T.tileFrame(ui, x, y, s, s, T.color.accent) else T.border(ui, x, y, s, s, T.color.tileEdge) end
    -- two diagonals of 2 px dots over the same square [m, s - m) both ways
    local m = math.floor(s / 3)
    local n = s - 2 * m - 2
    for i = 0, n do
        ui:drawRect(x + m + i, y + m + i, 2, 2, 1, c.r, c.g, c.b)
        ui:drawRect(x + s - m - 2 - i, y + m + i, 2, 2, 1, c.r, c.g, c.b)
    end
end

--- A game UIFont about as tall as ont, for the game's own widgets (text
--- boxes) that can't take Knox's fonts.
function T.gameFont(font)
    if type(font) ~= "table" then return font end
    return gameFontUpTo(T.fontH(font) + 2)
end

-- (the "Layout" overlay: text placed by hand, not through the kit, gets an
-- orange box round its letters - what is still to be moved onto the kit)
function T.text(ui, s, x, y, c, font, a)
    if T.layoutDebug() and s and s ~= "" and ui.javaObject then
        local l, t, r, b = inkBox(font or T.fontText, s)
        ui:drawRectBorder(x + l, y + t, r - l, b - t, 0.9, 1, 0.55, 0.1)
    end
    T.drawText(ui, s, x, y, c.r, c.g, c.b, a or 1, font or T.fontText)
end

function T.textRight(ui, s, x, y, c, font, a)
    T.drawTextRight(ui, s, x, y, c.r, c.g, c.b, a or 1, font or T.fontText)
end

function T.textCentre(ui, s, x, y, c, font, a)   -- uilint: ok (old code; new: T.label)
    T.drawTextCentre(ui, s, x, y, c.r, c.g, c.b, a or 1, font or T.fontText)   -- uilint: ok
end

--- A label in capitals (section titles, small labels), as in the mockup.
function T.caps(ui, s, x, y, c, font, a)
    T.text(ui, T.upper(s), x, y, c, font or T.fontCaps, a)
end

--- Button as in the mockup: dark plate, grey frame, caption in capitals;
--- sand frame on hover; `primary` = sand plate with dark caption.
--- r = {x, y, w, h}; opts = {hover, primary, disabled, active, font}
function T.button(ui, r, text, opts)
    opts = opts or {}
    local font = opts.font or T.fontCaps
    local primary, hover, disabled = opts.primary, opts.hover and not opts.disabled, opts.disabled
    T.rect(ui, r[1], r[2], r[3], r[4], primary and T.color.accent or T.color.buttonBg)
    local edge = (hover or opts.active) and T.color.accent or T.color.tileEdge
    if primary then edge = T.color.accent end
    if primary and hover then
        -- the sand plate lights up, with a bright frame inside
        ui:drawRect(r[1], r[2], r[3], r[4], 0.28, 1, 1, 1)
        edge = T.color.bright
        T.border(ui, r[1] + 1, r[2] + 1, r[3] - 2, r[4] - 2, edge)
    end
    T.border(ui, r[1], r[2], r[3], r[4], edge)
    if hover and not primary then ui:drawRect(r[1], r[2], r[3], r[4], 0.05, 1, 1, 1) end
    local c = primary and T.color.ink or (opts.color or T.color.text)
    buttonOpts.font, buttonOpts.a = font, disabled and 0.3 or 1
    T.label(ui, T.upper(text), r, c, buttonOpts)
end

--- Width a button needs for its caption.
function T.buttonW(text, font)
    return T.measure(font or T.fontCaps, T.upper(text)) + T.pad * 2
end

--- A key in a small frame ("[R]") followed by its label, for hint rows;
--- returns the x after it.
function T.keyHint(ui, x, y, key, label, h)
    local font = T.fontTile
    local kw = T.measure(font, key) + 10
    local kh = h or (T.fontH(font) + 4)
    hintPlate[1], hintPlate[2], hintPlate[3], hintPlate[4] = x, y, kw, kh
    hintPlateOpts.fill, hintPlateOpts.edge, hintPlateOpts.font = T.color.header, T.color.tileEdge, font
    T.plate(ui, hintPlate, key, hintPlateOpts)
    x = x + kw + 6
    hintBand[1], hintBand[2], hintBand[3], hintBand[4] = x, y, 0, kh
    hintBandOpts.font = T.fontText
    return x + T.label(ui, label, hintBand, T.color.dim, hintBandOpts)
end

--- Progress of a move: the faded tile fills up from the bottom with a light
--- tint, a sand line on the fill's edge as thick as the tile's 2 px frame (the
--- author's wish, 2026-10-15; the condition bar stays visible).
function T.progress(ui, x, y, w, h, frac)
    frac = math.max(0, math.min(1, frac))
    local fh = math.floor(h * frac)
    if fh <= 0 then return end
    local c = T.color.accent
    ui:drawRect(x, y + h - fh, w, fh, 0.16, c.r, c.g, c.b)
    ui:drawRect(x, y + h - fh, w, math.min(2, fh), 0.9, c.r, c.g, c.b)
end

--- Text with a 1 px dark outline (readable over any icon), right-aligned at x.
local OUTLINE = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}   -- (made once: a stack's count is drawn every frame)

function T.outlinedRight(ui, text, x, y, color, font, a)
    a = a or 1
    font = font or T.fontTile
    local lx = x - T.measure(font, text)
    for _, o in ipairs(OUTLINE) do
        T.drawText(ui, text, lx + o[1], y + o[2], 0, 0, 0, 0.9 * a, font)
    end
    T.drawText(ui, text, lx, y, color.r, color.g, color.b, a, font)
end

--- A thin meter along the bottom of a tile or slot (condition, uses left,
--- liquid), inside its 2 px frame: the frame's color on top, then a 3 px
--- dark track with the fill in `color`, resting on the frame's bottom edge.
--- `level` 1 stacks it above a level 0 meter (a pan: condition and water).
function T.tileMeter(ui, x, y, w, h, frac, color, a, level)
    a = a or 1
    frac = math.max(0, math.min(1, frac or 0))
    local mx, mw = x + 2, w - 4
    local fy = y + h - 2 - 3 - (level or 0) * 4
    T.rect(ui, mx, fy - 1, mw, 1, T.color.tileFrame, a)   -- line over the meter
    T.rect(ui, mx, fy, mw, 3, T.color.line, a)
    local fw = math.floor(mw * frac)
    if fw > 0 then T.rect(ui, mx, fy, fw, 3, color, a) end
end

--- A worn item that the move being considered would take off: red tint and
--- a 2 px red frame.
function T.replaceMark(ui, x, y, w, h)
    local c = T.color.bad
    ui:drawRect(x, y, w, h, 0.18, c.r, c.g, c.b)
    T.border(ui, x, y, w, h, c)
    T.border(ui, x + 1, y + 1, w - 2, h - 2, c)
end

--- An item the character is using right now (eating, drinking, bandaging...):
--- a 2 px sand frame, like a selected tile, and the fill of the action's progress.
function T.inUse(ui, x, y, w, h, frac)
    T.border(ui, x, y, w, h, T.color.accent)
    T.border(ui, x + 1, y + 1, w - 2, h - 2, T.color.accent)
    T.progress(ui, x, y, w, h, frac)
end

--- Turn of a move among several (on its faded copy): a sand square with the
--- number in dark ink, in the tile's top-left corner.
function T.turnBadge(ui, x, y, n)
    local text = tostring(n)
    local h = T.fontTileH + 4
    local w = math.max(h, T.measure(T.fontTile, text) + 8)
    T.rect(ui, x + 2, y + 2, w, h, T.color.accent)
    T.textCentre(ui, text, x + 2 + math.floor(w / 2), y + 4, T.color.ink, T.fontTile)
end

--- Where a moving item will land: a thin frame and faint tint that slowly
--- breathe, so it doesn't read as the drop highlight or as the item itself.
function T.target(ui, x, y, w, h, c)
    local t = getTimestampMs() / 1000
    local p = 0.5 + 0.5 * math.sin(t * math.pi * 1.6)
    c = c or T.color.accent
    ui:drawRect(x, y, w, h, 0.04 + 0.06 * p, c.r, c.g, c.b)
    ui:drawRectBorder(x, y, w, h, 0.35 + 0.5 * p, c.r, c.g, c.b)
end

--- Text split into lines no wider than `width`, at spaces (line breaks in the
--- text are joined). A word wider than a line on its own is cut between
--- characters: languages written without spaces (Chinese, Japanese) wrap too.
function T.wrap(text, font, width)
    text = string.gsub(text or "", "%s*\n%s*", " ")
    local lines, line = {}, ""
    local function push(word)
        local try = line == "" and word or (line .. " " .. word)
        if line == "" or T.measure(font, try) <= width then
            line = try
        else
            table.insert(lines, line)
            line = word
        end
    end
    for word in string.gmatch(text, "%S+") do
        if T.measure(font, word) <= width then
            push(word)
        else
            -- too long for any line: as many characters per line as fit
            if line ~= "" then table.insert(lines, line) line = "" end
            local piece = ""
            for i = 1, string.len(word) do
                local ch = string.sub(word, i, i)
                if piece ~= "" and T.measure(font, piece .. ch) > width then
                    table.insert(lines, piece)
                    piece = ch
                else
                    piece = piece .. ch
                end
            end
            line = piece
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

local fitCache, fitCount = {}, 0

--- Text cut to fit `width`, with a trailing dot when shortened.
function T.fit(s, font, width)
    local fkey = type(font) == "table" and font.key or tostring(font)
    local key = s .. "|" .. fkey .. "|" .. width
    local hit = fitCache[key]
    if hit then return hit end
    fitCount = fitCount + 1
    if fitCount > CACHE_MAX then fitCache, fitCount = {}, 1 end
    local out = s
    if T.measure(font, s) > width then
        out = ""
        for n = string.len(s) - 1, 1, -1 do
            local cut = string.sub(s, 1, n) .. "."
            if T.measure(font, cut) <= width then out = cut break end
        end
    end
    fitCache[key] = out
    return out
end

--- One line of text in w px from x: a longer one is not cut but slides, smoothly,
--- to show its end, waits, and slides back (the radio card's way, KnoxMenuMusic;
--- the author, 2026-10-18: no "..." on long names). `st`: a table kept with the
--- line - when its text changes the slide starts over.
local MARQUEE_HOLD, MARQUEE_SPEED = 1300, 45   -- ms at each end, px a second
function T.marquee(ui, st, s, x, y, w, c, font, a)
    a = a or 1
    local over = T.measure(font, s) - w
    if over <= 0 then
        T.text(ui, s, x, y, c, font, a)
        return
    end
    local now = getTimestampMs()
    if st.text ~= s then st.text, st.since = s, now end
    local move = over / MARQUEE_SPEED * 1000
    local t = (now - st.since) % (2 * (MARQUEE_HOLD + move))
    local p
    if not T.animOn() then p = 0
    elseif t < MARQUEE_HOLD then p = 0
    elseif t < MARQUEE_HOLD + move then p = (t - MARQUEE_HOLD) / move
    elseif t < 2 * MARQUEE_HOLD + move then p = 1
    else p = 1 - (t - 2 * MARQUEE_HOLD - move) / move end
    p = (1 - math.cos(math.pi * p)) / 2               -- (eased at both ends)
    ui:setStencilRect(x, y - 2, w, T.fontH(font) + 4)
    T.text(ui, s, x - math.floor(over * p + 0.5), y, c, font, a)
    ui:clearStencilRect()
end

-- How far food is frozen or cooked, shown on its tile and on its tooltip's
-- plate as a bar filling from the bottom, like the bar of a move:
--   frozen - a blue bar, sinking as it thaws;
--   on the heat - a sand tint with an orange bar rising; full: done;
--   left on - orange with a red bar rising; full: burnt.
local COOK_BLUE = {r = 0.29, g = 0.56, b = 0.82}
local COOK_ORANGE = {r = 0.88, g = 0.54, b = 0.17}
T.COOK_BLUE = COOK_BLUE
-- a frozen tile's frame: the ice's own blue, lighter - the grey-green frame of
-- other tiles read as a yellowish edge on the blue (the author, 2026-10-18)
T.FROZEN_FRAME = {r = 0.50, g = 0.69, b = 0.87}
T.FROZEN_HOVER = {r = 0.70, g = 0.82, b = 0.93}

--- a modulo n, always 0 <= result < n. (The game's Lua takes "%" as Java's
--- remainder: -2 % 10 is -2 there, not 8 - found 2026-10-15, "back" from the
--- first track of the menu's player gave an index of -1.)
function T.mod(a, n)
    return a - math.floor(a / n) * n
end

function T.mix(a, b, k)
    return T.mixInto({}, a, b, k)
end

--- T.mix into a table kept by the caller (a colour worked out every frame: no new table).
function T.mixInto(out, a, b, k)
    k = math.max(0, math.min(1, k))
    out.r, out.g, out.b = a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k
    return out
end

--- @return table|nil base (a tint under the bar), table|nil bar color, number bar 0..1
function T.cookState(item)
    if not instanceof(item, "Food") then return nil end
    if item:isBurnt() then return nil, T.color.bad, 1 end
    local frozen = item:getFreezingTime() or 0          -- 0..100
    if frozen > 0 then return nil, COOK_BLUE, math.min(1, frozen / 100) end
    if not item:isCookable() then return nil end
    local t, cook, burn = item:getCookingTime() or 0, item:getMinutesToCook() or 0, item:getMinutesToBurn() or 0
    if item:isCooked() then
        local k = (burn > cook) and (t - cook) / (burn - cook) or 0
        return COOK_ORANGE, T.color.bad, math.max(0, math.min(1, k))
    end
    if t > 0 and cook > 0 then return T.color.accent, COOK_ORANGE, math.min(1, t / cook) end
    return nil
end

-- How hot or cold a thing is, as the game's own inventory shows it: its row
-- tinted red when the thing is hot, blue when cold, stronger the further from
-- room temperature (ISInventoryPane: getItemHeat, getInvHeat). On Extinction
-- the game hides whether water is tainted, and players boil it "until it's red
-- hot" by that tint - a pot on a Knox tile showed nothing (a player's report,
-- 2026-10-15). Food keeps its own cooking colours (T.cookState).
local HEAT_RED = {r = 0.85, g = 0.18, b = 0.12}

--- @return table|nil colour, number strength 0..1
function T.heatState(item)
    if instanceof(item, "Food") then return nil, 0 end
    local h = item:getItemHeat() or 1
    if h == 1 then return nil, 0 end
    local k = math.min(1, math.abs(item:getInvHeat() or 0))
    if k < 0.02 then return nil, 0 end
    return h > 1 and HEAT_RED or COOK_BLUE, k
end

--- Draw that over a plate x, y, w, h (nothing for food that is neither).
function T.cookBar(ui, x, y, w, h, item, alpha)
    local base, bar, frac = T.cookState(item)
    alpha = alpha or 1
    if base then ui:drawRect(x, y, w, h, 0.22 * alpha, base.r, base.g, base.b) end
    if not bar then return end
    local fh = math.floor(h * frac + 0.5)
    if fh <= 0 then return end
    ui:drawRect(x, y + h - fh, w, fh, 0.5 * alpha, bar.r, bar.g, bar.b)
    ui:drawRect(x, y + h - fh, w, math.min(2, fh), 0.95 * alpha, bar.r, bar.g, bar.b)
end
-- A thing that has just come into a slot (put on, taken in hand, hung on the
-- belt) settles into it as a tile settles into its cells: it drops in from a
-- little above, fading in. `holder`: any table that lasts as long as the slot
-- (the slot itself); the first item it is asked about is taken as already there.
-- @return number dy to draw it at, number alpha factor
function T.settleIn(holder, item)
    local now = getTimestampMs()
    local s = holder.knoxSettle
    if not s then
        s = {item = item, ms = 0}
        holder.knoxSettle = s
    elseif s.item ~= item then
        s.item = item
        s.ms = item and now or 0
    end
    if not item then return 0, 1 end
    local t = T.anim((now - s.ms) / 160)
    if t >= 1 then return 0, 1 end
    local k = (1 - t) * (1 - t)
    return -math.floor(T.cell * 0.22 * k + 0.5), 0.35 + 0.65 * t
end

-- A window unfolding as it opens and folding as it closes: for a moment only
-- its plate is drawn, small and faint at the thing it belongs to (a tile, a
-- slot; else its own middle), growing into its place - then the window with
-- all in it; and the same backwards when it is closed. Its children are hidden
-- meanwhile.
--   T.unfold(win, sx, sy, sw, sh)  first thing in the window's prerender, with
--       the source's rect on the screen if there is one; true = still folding
--       or unfolding, draw nothing else this frame. Opening starts at
--       win.openedMs, or at the first call.
--   T.fold(win, finish)  in the window's close(), in place of taking it off
--       the screen: `finish(win)` does that once it has folded away (outside of
--       drawing: elements may not be removed while the UI draws). What the
--       window stood for - its place in lists, "the open window" - is to be
--       cleared by close() at once, not in `finish`.
local UNFOLD_MS, FOLD_MS = 170, 130
T.folding = {}

local function foldPlate(win, k, sx, sy, sw, sh)
    local w, h = win:getWidth(), win:getHeight()
    if sx then
        sx, sy = sx - win:getAbsoluteX(), sy - win:getAbsoluteY()
    else
        sw, sh = w * 0.3, h * 0.3
        sx, sy = (w - sw) / 2, (h - sh) / 2
    end
    local x, y = math.floor(sx * (1 - k)), math.floor(sy * (1 - k))
    local fw, fh = math.floor(sw + (w - sw) * k), math.floor(sh + (h - sh) * k)
    local a = 0.15 + 0.8 * k
    T.rect(win, x, y, fw, fh, T.color.window, a)
    T.rect(win, x, y, fw, math.min(fh, math.floor((T.sectionH + 4) * k + 0.5)), T.color.header, a)
    T.border(win, x, y, fw, fh, T.color.accent, a)
end

function T.unfold(win, sx, sy, sw, sh)
    local now = getTimestampMs()
    if win.foldMs then
        -- closing: the plate shrinks back to where it came from
        local t = math.min(1, T.anim((now - win.foldMs) / FOLD_MS))
        local k = (1 - t) * (1 - t)
        if k > 0.01 then foldPlate(win, k, sx, sy, sw, sh) end
        return true
    end
    if not win.openedMs then win.openedMs = now end
    local t = T.anim((now - win.openedMs) / UNFOLD_MS)
    if t >= 1 then
        if win.unfoldHid then
            for _, child in ipairs(win.unfoldHid) do child:setVisible(true) end
            win.unfoldHid = nil
        end
        return false
    end
    if not win.unfoldHid then
        win.unfoldHid = {}
        for _, child in pairs(win.children or {}) do
            if child:getIsVisible() then
                child:setVisible(false)
                table.insert(win.unfoldHid, child)
            end
        end
    end
    foldPlate(win, 1 - (1 - t) * (1 - t), sx, sy, sw, sh)
    return true
end

function T.fold(win, finish)
    if win.foldMs then return end
    win.foldMs = getTimestampMs()
    win.foldFinish = finish
    win.unfoldHid = nil
    for _, child in pairs(win.children or {}) do
        if child:getIsVisible() then child:setVisible(false) end
    end
    table.insert(T.folding, win)
end

Events.OnPreUIDraw.Add(function()
    if #T.folding == 0 then return end
    local now = getTimestampMs()
    local keep = {}
    for _, win in ipairs(T.folding) do
        if T.anim((now - win.foldMs) / FOLD_MS) >= 1 then
            local finish = win.foldFinish
            win.foldFinish = nil
            if finish then finish(win) end
        else
            table.insert(keep, win)
        end
    end
    T.folding = keep
end)

-- the skin the player chose, from the first frame on
T.applySkin()

return KnoxTheme
