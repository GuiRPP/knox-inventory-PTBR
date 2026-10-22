-- The inventory's controls: which mouse gesture or key does what, as the player
-- has set it in the settings window (KnoxSettings.lua). Kept in the mod's
-- settings file as "bind.<action>=<gesture>" (see KnoxTheme.settings); a change
-- works at once.
--
-- A gesture is written as its modifiers in the order ctrl, shift, alt, then
--   lmb      a click of the left button on a tile
--   lmb2     a double click of it
--   rmb      a click of the right button
--   mmb      a click of the middle button (the wheel)
--   key:<n>  a key of the keyboard (its Keyboard.KEY_ number)
-- e.g. "shift+lmb", "ctrl+alt+rmb", "lmb2", "key:19", "ctrl+key:31". "" = not bound.
-- A plain "lmb" is not offered: it picks a tile up and starts a drag.

require "Knox/KnoxTheme"

KnoxControls = {}
local C = KnoxControls
local T = KnoxTheme

-- kind: "mouse" = a gesture on a tile, "key" = a key while the screen is open,
-- "hold" = a key held down while the mouse does something (a modifier works too).
-- `global`: the key works with the screen closed as well (it opens it).
-- `hint = false`: not in the hint row at the screen's bottom.
C.ACTIONS = {
    -- Knox's own inventory key (players were told Tab, the game's own key is I
    -- in B42: "Tab does nothing" - eleven of them by 2026-10-19). The game's
    -- inventory key opens the screen too; Esc closes it.
    {id = "toggle",    kind = "key",   default = "key:" .. tostring(Keyboard.KEY_TAB), global = true, hint = false},
    {id = "quickMove", kind = "mouse", default = "shift+lmb"},
    {id = "select",    kind = "mouse", default = "ctrl+lmb"},
    {id = "alt",       kind = "mouse", default = "alt+lmb"},     -- split a stack / wear or equip
    {id = "open",      kind = "mouse", default = "lmb2"},        -- open a bag, use an item
    {id = "menu",      kind = "mouse", default = "rmb"},
    {id = "inspect",   kind = "mouse", default = "mmb"},         -- the inspect window
    -- (rotate may also go on the right or middle button: it works only while an
    -- item is held, so it shares the button with the tile actions)
    {id = "rotate",    kind = "key",   default = "key:" .. tostring(Keyboard.KEY_R), mouse = true},
    {id = "lock",      kind = "key",   default = "key:" .. tostring(Keyboard.KEY_T)},   -- lock the tile under the mouse
    {id = "sort",      kind = "key",   default = "ctrl+key:" .. tostring(Keyboard.KEY_S)},   -- Sort the grid under the mouse
    -- held while a quick slot of the bar is dragged to another place (KnoxHotbar)
    {id = "hotbarMove", kind = "hold", default = "key:" .. tostring(Keyboard.KEY_LMENU), hint = false},
}

local byId = {}
for _, a in ipairs(C.ACTIONS) do byId[a.id] = a end

function C.action(id)
    return byId[id]
end

--- The gesture an action is bound to ("" = none).
function C.get(id)
    local a = byId[id]
    if not a then return "" end
    local v = T.settings["bind." .. id]
    if v == nil then return a.default end
    return v
end

--- Bind an action; whatever else of its kind had the gesture loses it (one
--- gesture, one action; a held item's turn on the right button leaves the
--- tile's menu on it).
function C.set(id, gesture)
    gesture = gesture or ""
    local kind = byId[id] and byId[id].kind
    if gesture ~= "" then
        for _, a in ipairs(C.ACTIONS) do
            if a.id ~= id and a.kind == kind and C.get(a.id) == gesture then T.settings["bind." .. a.id] = "" end
        end
    end
    T.settings["bind." .. id] = gesture
    C.changed()
end

function C.reset()
    for _, a in ipairs(C.ACTIONS) do T.settings["bind." .. a.id] = nil end
    C.changed()
end

--- Something was rebound: the hint rows are written anew.
function C.changed()
    C.stamp = (C.stamp or 0) + 1
end
C.stamp = 0

function C.isDefault()
    for _, a in ipairs(C.ACTIONS) do
        if C.get(a.id) ~= a.default then return false end
    end
    return true
end

-- Gestures ---------------------------------------------------------------------

local function down(a, b) return isKeyDown(a) or isKeyDown(b) end

--- The modifiers held right now, as a gesture's prefix: "", "shift+", "ctrl+alt+"...
function C.mods()
    local s = ""
    if down(Keyboard.KEY_LCONTROL, Keyboard.KEY_RCONTROL) then s = s .. "ctrl+" end
    if down(Keyboard.KEY_LSHIFT, Keyboard.KEY_RSHIFT) then s = s .. "shift+" end
    if down(Keyboard.KEY_LMENU, Keyboard.KEY_RMENU) then s = s .. "alt+" end
    return s
end

local MOD_KEYS = {}
for _, name in ipairs({"KEY_LCONTROL", "KEY_RCONTROL", "KEY_LSHIFT", "KEY_RSHIFT", "KEY_LMENU", "KEY_RMENU"}) do
    if Keyboard[name] then MOD_KEYS[Keyboard[name]] = true end
end

function C.isModifierKey(key)
    return MOD_KEYS[key] == true
end

--- The action of a kind bound to this gesture, or nil.
function C.actionFor(kind, gesture)
    if gesture == "" then return nil end
    for _, a in ipairs(C.ACTIONS) do
        if a.kind == kind and C.get(a.id) == gesture then return a.id end
    end
    return nil
end

--- Is the held item to be turned by this mouse button ("rmb", "mmb") with the
--- modifiers held now?
function C.isRotateButton(button)
    return C.get("rotate") == C.mods() .. button
end

--- The key action of a pressed key with the modifiers held now, or nil.
function C.keyAction(key)
    return C.actionFor("key", C.mods() .. "key:" .. tostring(key))
end

--- Is the key of a key action pressed now (with its modifiers)?
function C.isKey(id, key)
    local g = C.get(id)
    return g ~= "" and g == C.mods() .. "key:" .. tostring(key)
end

-- A held key and its twin on the other side of the keyboard (left Alt = right Alt).
local TWIN = {}
for _, pair in ipairs({{"KEY_LCONTROL", "KEY_RCONTROL"}, {"KEY_LSHIFT", "KEY_RSHIFT"}, {"KEY_LMENU", "KEY_RMENU"}}) do
    local a, b = Keyboard[pair[1]], Keyboard[pair[2]]
    if a and b then TWIN[a], TWIN[b] = b, a end
end

--- Is the key of a "hold" action held down right now?
function C.isHeld(id)
    local key = tonumber(string.match(C.get(id), "^key:(%d+)$"))
    if not key then return false end
    return isKeyDown(key) or (TWIN[key] ~= nil and isKeyDown(TWIN[key]))
end

--- Is the key bound to something of the screen's (with any modifiers)? The
--- screen keeps such a key from the game while it is open.
function C.isBoundKey(key)
    -- (a key bound with modifiers is kept only with them held: Ctrl+S sorts,
    -- S alone still walks)
    local tail = "key:" .. tostring(key)
    local now = C.mods() .. tail
    for _, a in ipairs(C.ACTIONS) do
        if a.kind == "key" then
            local g = C.get(a.id)
            if g == tail or g == now then return true end
        end
    end
    return false
end

-- Names ------------------------------------------------------------------------

local MOD_NAMES = {ctrl = "Ctrl", shift = "Shift", alt = "Alt"}

--- A gesture as the player reads it: "Shift+LMB", "2xLMB", "Ctrl+R".
function C.label(gesture)
    if not gesture or gesture == "" then return "-" end
    local parts = {}
    local base = gesture
    for mod in string.gmatch(gesture, "([a-z]+)%+") do
        table.insert(parts, MOD_NAMES[mod] or mod)
    end
    base = string.match(gesture, "([^+]+)$") or gesture
    local name
    if base == "lmb" then
        name = getText("IGUI_Knox_LMB")
    elseif base == "lmb2" then
        name = "2x" .. getText("IGUI_Knox_LMB")
    elseif base == "rmb" then
        name = getText("IGUI_Knox_RMB")
    elseif base == "mmb" then
        name = getText("IGUI_Knox_MMB")
    else
        local key = tonumber(string.match(base, "^key:(%d+)$"))
        name = key and getKeyName(key) or base
    end
    table.insert(parts, name)
    return table.concat(parts, "+")
end

function C.name(id)
    return getText("IGUI_Knox_Act_" .. id)
end

--- Hint rows {key, label} of the bound actions, in the actions' order.
function C.hints(ids)
    local list = {}
    for _, a in ipairs(C.ACTIONS) do
        local g = C.get(a.id)
        if g ~= "" and a.hint ~= false and (not ids or ids[a.id]) then
            table.insert(list, {key = C.label(g), label = getText("IGUI_Knox_Hint_" .. a.id)})
        end
    end
    return list
end

return KnoxControls
