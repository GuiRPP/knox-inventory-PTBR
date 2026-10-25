-- Knox's crosshair panel: what is looked at in Viewpoint's first or third
-- person view (a cupboard, the ground, a body, a door) and what can be done
-- with it, drawn in Knox's style in place of Viewpoint's own panel (the author,
-- 2026-10-24..25: the mockup .claude/mockups/vp_panel_v1.html, approved).
--
-- Viewpoint still picks what is looked at, rolls its loot, gathers its actions
-- and reads its keys - the player's own, set in its options (take, take all,
-- open the window; the wheel chooses). Knox keeps the rows and the choice and
-- draws (the Java part: KnoxViewpoint, knoxVpPanel*):
--   * a header as the world menu's: the picture, the name, what is in it;
--   * the things, a row per kind; the chosen row grows whole; a thing being
--     taken fills its row from the left, a sand line on the fill's edge, and
--     the row folds away once it is gone;
--   * Knox's search inside the panel: "Searching..." while a thing is looked
--     for, the things found open into the list one by one (it starts by itself:
--     the author, 2026-10-25);
--   * a bag looked into right in the list: a short press of the take key opens
--     or folds it, a held one takes the bag (the author, 2026-10-25);
--   * the actions under the things, the dangerous ones red at the bottom;
--   * the keys at the foot, as the player has bound them.
-- It unfolds out of the crosshair and folds back into it (T.unfold's 170 / 130 ms).
-- A switch in the settings (T.switch("vp.panel")); off - or anything amiss, one
-- line in console.txt - Viewpoint's own panel is back.

require "Knox/KnoxTheme"
require "Knox/KnoxSearch"

KnoxCrosshair = KnoxCrosshair or {}
local P = KnoxCrosshair
local T = KnoxTheme

local EDGE = {r = 0x4a / 255, g = 0x4f / 255, b = 0x4f / 255}    -- the plate's frame (as the menus')
local HOVER = {r = 0x23 / 255, g = 0x27 / 255, b = 0x2a / 255}   -- under the chosen row
local RED = {r = 0xd9 / 255, g = 0x8a / 255, b = 0x7c / 255}     -- a dangerous action, "Locked"
local BLACK = {r = 0, g = 0, b = 0}
local TIMES = string.char(215)   -- (the game reads Lua as single bytes)

local UNFOLD_MS, FOLD_MS, SHOW_MS = 170, 130, 110
local ENTER_MS, LEAVE_MS, BAG_MS, HINT_MS = 220, 220, 200, 200
local HOLD_MS, RETRACT_MS = 180, 120

-- Sizes at 1080p (a cell of 48), scaled with the cell -------------------------------

local Z = {}
local function sizes()
    local c = T.cell
    if Z.cell == c and Z.java == T.javaFonts then return end
    local s = c / 48
    local function px(n) return math.max(1, math.floor(n * s + 0.5)) end
    Z.cell, Z.java = c, T.javaFonts
    Z.GAP, Z.M, Z.ROW, Z.LABEL, Z.SEP = px(8), px(7), px(32), px(32), px(11)
    Z.L = Z.GAP + Z.M
    Z.CELL, Z.IC, Z.AIC = px(26), px(22), px(17)
    Z.TX = Z.L + Z.CELL + px(10)
    Z.MINW, Z.MAXW, Z.MAXV, Z.STRIP = px(260), px(340), 8, px(14)
    Z.KH, Z.HINT_GAP = px(20), px(16)
    Z.GROW_H, Z.GROW_CELL = px(6), px(4)
    Z.IND, Z.CHEV = px(20), px(26)
    Z.AWAY, Z.SRC = px(48), px(18)        -- from the crosshair (as Viewpoint's); the square it unfolds from
    Z.PH_SUB, Z.PH = px(7) * 2 + px(43), px(7) * 2 + px(26)   -- the header with a line under the name, without
    Z.P5, Z.P10, Z.P16, Z.P40 = px(5), px(10), px(16), px(40)   -- a few of the mockup's small gaps
    -- (the chosen row's name a size up: 15 -> 17)
    Z.big = T.javaFonts and T.makeFont("body", c * 0.31 + 2 * s) or T.fontText
end

-- Strings, once a game --------------------------------------------------------------

local STR
local function strings()
    if STR then return STR end
    STR = {
        take = getText("IGUI_Knox_VPTake"), all = getText("IGUI_Knox_VPTakeAll"), open = getText("IGUI_Knox_VPOpen"),
        use = getText("IGUI_Knox_VPUse"), peek = getText("IGUI_Knox_VPPeek"), fold = getText("IGUI_Knox_VPFold"),
        searching = getText("IGUI_Knox_VPSearching"), unsearched = getText("IGUI_Knox_VPUnsearched"),
        empty = getText("IGUI_Knox_VPEmpty"), locked = getText("IGUI_Knox_VPLocked"),
        inside = getText("IGUI_Knox_VPInside"), actions = getText("IGUI_Knox_MenuActions"),
        kg = getText("IGUI_Knox_Kg"), plural = getText("IGUI_Knox_VPPlural"),
        thing1 = getText("IGUI_Knox_VPThing1"), thing2 = getText("IGUI_Knox_VPThing2"), thing5 = getText("IGUI_Knox_VPThing5"),
        dot = "  " .. string.char(183) .. "  ",
    }
    return STR
end

local function thingsWord(n)
    local s = strings()
    if s.plural == "ru" then
        local a, b = n % 10, n % 100
        if a == 1 and b ~= 11 then return s.thing1 end
        if a >= 2 and a <= 4 and (b < 12 or b > 14) then return s.thing2 end
        return s.thing5
    end
    return n == 1 and s.thing1 or s.thing5
end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end
local function kgText(w) return round2(w) .. " " .. strings().kg end

-- The keys, as the player has bound them in Viewpoint's options (asked now and
-- then: they may be changed with the game running)
local KEYS = {take = "F", all = "R", open = "Tab"}
local keysMs = -1e9
local function keyName(id, fallback)
    local k = Viewpoint and Viewpoint.Keys
    if not k or not k.get or not k.display then return fallback end
    local ok, s = pcall(function() return k.display(k.get(id)) end)
    if not ok or type(s) ~= "string" or s == "" or s == "NONE" then return fallback end
    -- (the game's names are in capitals: "TAB" as "Tab", as the mockup has it)
    if #s > 1 and string.find(s, "^%u+$") then s = string.sub(s, 1, 1) .. string.lower(string.sub(s, 2)) end
    return s
end
local function keys(now)
    if now - keysMs < 1000 then return end
    keysMs = now
    KEYS.take = keyName("keys.lootTake", "F")
    KEYS.all = keyName("keys.lootTakeAll", "R")
    KEYS.open = keyName("keys.lootWindow", "Tab")
end

local function ease(k)
    if k < 0.5 then return 2 * k * k end
    local v = -2 * k + 2
    return 1 - v * v / 2
end

-- Where its world comes from ---------------------------------------------------------
--
-- Everything the panel asks of the world goes through P.src: LIVE below - Viewpoint
-- (the Java part's knoxVpPanel*), the game's things, Knox's search and transfers - or
-- a news post's pretend cupboard (KnoxCrosshairDemo: the panel live in the news, the
-- author 2026-10-25: "an interactive window, as the posts before").

local LIVE = {}
P.LIVE = LIVE
P.src = LIVE

function LIVE.kind() return knoxVpPanelKind() end
function LIVE.containers() return knoxVpPanelContainers() end
function LIVE.loot() return knoxVpPanelLoot() end
function LIVE.locked() return knoxVpPanelLocked() end
function LIVE.square() return knoxVpPanelSquare() end
function LIVE.title(c) return knoxVpPanelTitle(c) end
function LIVE.actions() return knoxVpPanelActions() end
function LIVE.actionLabel(i) return knoxVpPanelActionLabel(i) end
function LIVE.actionOn(i) return knoxVpPanelActionOn(i) end
function LIVE.actionsTitle() return knoxVpPanelActionsTitle() end
function LIVE.actionProgress(i) return knoxVpPanelActionProgress(i) end
function LIVE.run(i) return knoxVpPanelRun(i) end
function LIVE.wheel() return knoxVpPanelWheel() end
function LIVE.pressed() return knoxVpPanelPressed() end
function LIVE.held() return knoxVpPanelHeld() end

function LIVE.isBag(it) return instanceof(it, "InventoryContainer") and it:getInventory() ~= nil end
function LIVE.weight(it) return KnoxGrid.weightOf(it) end
function LIVE.category(it) return T.categoryOf(it) end
function LIVE.icon(ui, it, x, y, a, s) ISInventoryItem.renderItemIcon(ui, it, x, y, a, s, s) end

function LIVE.containerIcon(c)
    if not c then return ContainerButtonIcons and ContainerButtonIcons.floor or nil end
    local t = ContainerButtonIcons and ContainerButtonIcons[c:getType()]
    return t or getTexture("media/ui/Container_Shelf.png")
end

function LIVE.groundItems(sq)
    local list = ArrayList.new()
    local objs = sq and sq:getWorldObjects()
    for i = 0, (objs and objs:size() or 0) - 1 do
        local it = objs:get(i):getItem()
        if it then list:add(it) end
    end
    return list
end

--- (the ground's things, counted for the signature: cheap)
function LIVE.groundCount(sq)
    local objs = sq and sq:getWorldObjects()
    return objs and objs:size() or 0
end

-- Knox's search (KnoxSearch): not seen yet, being searched, waiting its turn
function LIVE.unseen(it) return KnoxSearch ~= nil and T.on("inventory") and KnoxSearch.unseen(it) == true end
function LIVE.busy(c) return KnoxSearch ~= nil and T.on("inventory") and KnoxSearch.busy(c) end
function LIVE.needs(c) return KnoxSearch ~= nil and T.on("inventory") and KnoxSearch.needs(c) end
--- How far the thing being looked for in c is found (0..1).
function LIVE.searchFrac(c)
    local q = KnoxSearch.queue[1]
    return (q and KnoxSearch.busy(c)) and math.min(1, KnoxSearch.spent / q.ms) or 1
end
function LIVE.searchSig()
    return KnoxSearch and (KnoxSearch.done + (KnoxSearch.container and 17 or 0)) or 0
end

local searchLayout, searchFor = nil, nil

--- One container at a time, as Knox's: a bag looked into first, then what is
--- looked at, its containers in turn. Left (looked away), it waits, and goes
--- on from there (KnoxSearch keeps what it found).
function LIVE.search(player)
    if not KnoxSearch or not T.on("inventory") or not KnoxSearch.on() then return end
    local want = nil
    for bag, st in pairs(P.bags) do
        if st.to and bag:getInventory() and KnoxSearch.needs(bag:getInventory()) then want = bag:getInventory() break end
    end
    if not want then
        for _, c in ipairs(P.containers) do
            if KnoxSearch.needs(c) then want = c break end
        end
    end
    if not want then return end
    if want ~= KnoxSearch.container or searchFor ~= want then
        -- (its grid, for the order things are found in: built once, when it starts)
        searchLayout, searchFor = KnoxGrid.build(want, player), want
    end
    KnoxSearch.tick(want, searchLayout)
end

-- Knox's transfers: a thing on its way (0..1), taken, stopped
function LIVE.pending(it)
    local _, p = KnoxGrid.pendingOf(it)
    return p
end

function LIVE.grab(player, items)
    if Knox and Knox.viewpointGrab then
        Knox.viewpointGrab(player, items)
    elseif ViewpointLoot and ViewpointLoot.take then
        for _, it in ipairs(items) do ViewpointLoot.take(player, it) end
    end
end

--- Stop a held take let go early: its transfer comes off the queue.
function LIVE.cancel(player, item)
    local rec = KnoxGrid.pending[item]
    if not rec then return end
    local q = ISTimedActionQueue.getTimedActionQueue(player)
    for _, step in ipairs(rec.steps) do
        local a = step.action
        if q and q.queue and q.queue[1] == a then
            pcall(a.forceStop, a)
        elseif q and q.removeFromQueue then
            pcall(q.removeFromQueue, q, a)
        end
    end
end

-- What is looked at -----------------------------------------------------------------

-- (the panel's state; made anew for each thing looked at)
P.rows = {}      -- the rows, top down (see build)
P.pick = {}      -- the rows the wheel can stop on
P.sel = 0        -- index into P.pick
P.grow = {}      -- row key -> 0..1: how far it has grown as the chosen one
P.bags = {}      -- a bag (its item) -> {to = open or not, k = 0..1}
P.seen = {}      -- row key -> true: in the list before (a key new to it enters)
P.L = {}         -- the layout of this frame (heights, the list's window, the plate)

local function selectable(r)
    if r.kind == "item" then return not r.leave and not r.closing end
    return r.kind == "act" and r.on
end

local function catColor(item) return T.category[P.src.category(item)] or T.category.misc end
local frameOf = {}   -- a category's tile frame: its colour, lighter (as a tile's in the mockup)
local function tileEdge(cat)
    local f = frameOf[cat]
    if not f then
        f = T.mix(cat, {r = 1, g = 1, b = 1}, 0.3)
        frameOf[cat] = f
    end
    return f
end

local function unseen(item)
    return P.src.unseen(item) == true
end

--- The things of a list, a row per kind (by name, as Viewpoint's), a bag a row
--- of its own; sorted by name. `parent`: the bag they lie in (depth 1) or nil.
local function itemRows(out, items, container, depth, parent, player)
    local byName, list = {}, {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and not it:isHidden() and not unseen(it) then
            local bag = depth == 0 and P.src.isBag(it)
            local name = it:getName(player) or "?"
            local r = (not bag) and byName[name] or nil
            if not r then
                r = {kind = "item", name = name, items = {}, n = 0, w = 0, item = it, depth = depth,
                     container = container, parent = parent, region = "list", lower = string.lower(name)}
                -- (the key a row is known by while things come and go)
                r.key = bag and it or ((parent and tostring(parent:getID()) or "") .. "|" .. tostring(container) .. "|" .. name)
                if bag then r.bag = it else byName[name] = r end
                table.insert(list, r)
            end
            table.insert(r.items, it)
            r.n = r.n + 1
            r.w = r.w + P.src.weight(it)
        end
    end
    table.sort(list, function(a, b) return a.lower < b.lower end)
    for _, r in ipairs(list) do
        r.cat = catColor(r.item)
        r.wtext = kgText(r.w)
        r.ntext = r.n > 1 and (TIMES .. r.n) or nil
        table.insert(out, r)
        if r.bag then
            local st = P.bags[r.bag]
            if st and st.k > 0 then
                local inv = r.bag:getInventory()
                local mark = #out
                itemRows(out, inv:getItems(), inv, 1, r.bag, player)
                -- (a bag closing: its things fold with it and can't be chosen)
                for j = mark + 1, #out do
                    if not st.to then out[j].closing = true end
                end
                P.searchRows(out, inv, 1, r.bag, #out == mark)
            end
        end
    end
end

--- The search's row of a list: being searched (the thing looked for), waiting
--- its turn (not searched yet) - or "empty" when there is nothing at all.
function P.searchRows(out, container, depth, parent, none)
    local key = "search|" .. tostring(container)
    if container and P.src.busy(container) then
        table.insert(out, {kind = "searching", key = key, depth = depth, parent = parent, container = container, region = "list"})
    elseif container and P.src.needs(container) then
        table.insert(out, {kind = "unsearched", key = key .. "|w", depth = depth, parent = parent, region = "list"})
    elseif none then
        table.insert(out, {kind = "empty", key = "empty|" .. tostring(container), depth = depth, parent = parent, region = "list"})
    end
end

-- (a world action's icon and group, by its name: kept - its label is asked each build)
local actLook = {}
local function lookOf(label)
    local v = actLook[label]
    if not v then
        local icon, g = nil, nil
        if KnoxContextMenu and KnoxContextMenu.worldLook then icon, g = KnoxContextMenu.worldLook(label) end
        v = {icon = icon or false, danger = g == "danger"}
        actLook[label] = v
    end
    return v
end

local lockTex, lensTex
local function texOf(name)
    return getTexture("media/ui/knoxicons/menu_" .. name .. ".png")
end

--- The rows of what is looked at (made anew when what it holds changes - not
--- every frame: P.signature). The rows of the last build that are gone stay,
--- folding away, where they were.
function P.build(player)
    sizes()
    local s = strings()
    local old = P.rows
    local rows = {}
    local kind = P.src.kind()
    local cs = P.src.containers()
    local n = cs and cs:size() or 0
    local loot = P.src.loot()
    local many = (kind == 0 and 1 or 0) + n > 1
    P.locked = P.src.locked()
    P.loot = loot
    P.containers = {}
    -- the things: the ground's, then each container's (a fridge and its freezer under titles)
    if loot and not P.locked then
        if kind == 0 then
            local sq = P.src.square()
            if many then table.insert(rows, {kind = "label", text = P.src.title(nil) or "", key = "label|ground", region = "list"}) end
            local mark = #rows
            itemRows(rows, P.src.groundItems(sq), nil, 0, nil, player)
            if #rows == mark then table.insert(rows, {kind = "empty", key = "empty|ground", depth = 0, region = "list"}) end
        end
        for i = 0, n - 1 do
            local c = cs:get(i)
            table.insert(P.containers, c)
            if many then table.insert(rows, {kind = "label", text = P.src.title(c) or "", key = "label|" .. tostring(c), region = "list"}) end
            local mark = #rows
            itemRows(rows, c:getItems(), c, 0, nil, player)
            P.searchRows(rows, c, 0, nil, #rows == mark)
        end
    end
    -- the actions: what can be done to it (Viewpoint's, as the world menu has them);
    -- the dangerous ones red at the bottom, under a line
    local na = P.src.actions()
    if na > 0 then
        local bad = {}
        local firstAct = #rows + 1
        if loot and #rows > 0 then table.insert(rows, {kind = "label", text = s.actions, key = "label|acts", region = "acts"}) end
        for i = 0, na - 1 do
            local label = P.src.actionLabel(i) or ""
            local look = lookOf(label)
            local r = {kind = "act", name = label, index = i, on = P.src.actionOn(i), icon = look.icon or nil,
                       danger = look.danger, key = "act|" .. i .. "|" .. label, region = "acts"}
            if r.danger then table.insert(bad, r) else table.insert(rows, r) end
        end
        if #bad > 0 then
            if #rows >= firstAct then table.insert(rows, {kind = "sep", key = "sep", region = "acts"}) end
            for _, r in ipairs(bad) do table.insert(rows, r) end
        end
    end
    -- what was in the list and is gone folds away where it was (a thing taken)
    local keep = {}
    for _, r in ipairs(rows) do keep[r.key] = true end
    if P.target == P.builtFor then
        for i, r in ipairs(old) do
            -- (a bag's things folded with it are gone already: not folded once more)
            if not keep[r.key] and r.region == "list" and r.kind ~= "label" and not r.closing then
                if not r.leaveMs then r.leaveMs = getTimestampMs() end
                if getTimestampMs() - r.leaveMs < LEAVE_MS then
                    -- (after the row it followed, or first)
                    local at = 1
                    for j = i - 1, 1, -1 do
                        local pk = old[j].key
                        local found = nil
                        for m, q in ipairs(rows) do if q.key == pk then found = m break end end
                        if found then at = found + 1 break end
                    end
                    table.insert(rows, at, r)
                    keep[r.key] = true
                end
            elseif keep[r.key] then
                -- (still there: what was being shown of it stays - its growth, its entering)
                for _, q in ipairs(rows) do
                    if q.key == r.key then q.enterMs = r.enterMs break end
                end
            end
        end
        -- a thing found (or put there) opens into the list
        for _, r in ipairs(rows) do
            if r.kind == "item" and not P.seen[r.key] and not r.leaveMs then r.enterMs = getTimestampMs() end
        end
    end
    for _, r in ipairs(rows) do P.seen[r.key] = true end
    P.builtFor = P.target
    P.rows = rows
    -- the rows the wheel stops on; the choice stays on its row, or where it was
    local key = P.pick[P.sel] and P.pick[P.sel].key
    P.pick = {}
    local at = 0
    for _, r in ipairs(rows) do
        if selectable(r) then
            table.insert(P.pick, r)
            if r.key == key then at = #P.pick end
        end
    end
    if at == 0 then at = math.min(math.max(P.sel, 1), #P.pick) end
    P.sel = at
end

--- The plate's width: the widest of its rows, header and hints (worked out once a build).
function P.measureNeed()
    local s = strings()
    local need = Z.MINW
    local ph = P.hasSub() and Z.PH_SUB or Z.PH
    local cell = ph - 2 * Z.M
    need = math.max(need, Z.GAP * 2 + Z.M * 2 + Z.P10 + cell + T.measure(T.fontHeader, P.title or ""))
    local hasItem, hasBag, hasAct = false, false, false
    for _, r in ipairs(P.rows) do
        if r.kind == "item" and not r.leaveMs then
            hasItem = true
            if r.bag then hasBag = true end
            local tail = (r.ntext and (Z.P5 + T.measure(T.fontText, r.ntext)) or 0) + Z.P16 + T.measure(T.fontText, r.wtext)
                + (r.bag and Z.CHEV or 0)
            r.tail = math.ceil(tail)
            need = math.max(need, Z.TX + (r.depth > 0 and Z.IND or 0) + math.ceil(T.measure(Z.big, r.name)) + r.tail + Z.L + 1)
            -- (a bag's things count whether it is open or not: the plate doesn't widen as it opens)
            if r.bag and r.depth == 0 then
                local items = r.bag:getInventory():getItems()
                for i = 0, items:size() - 1 do
                    local it = items:get(i)
                    need = math.max(need, Z.TX + Z.IND + math.ceil(T.measure(Z.big, it:getName() or "")) + Z.P16
                        + math.ceil(T.measure(T.fontText, kgText(P.src.weight(it)))) + Z.L + 1)
                end
            end
        elseif r.kind == "act" then
            hasAct = true
            need = math.max(need, Z.TX + T.measure(T.fontText, r.name) + Z.L)
        elseif r.kind == "label" then
            need = math.max(need, Z.L + T.measure(T.fontTile, T.upper(r.text)) + Z.P40 + Z.L)
        elseif r.kind == "searching" or r.kind == "unsearched" or r.kind == "empty" then
            need = math.max(need, Z.TX + T.measure(T.fontText, s[r.kind]) + Z.L)
        end
    end
    if P.sub then need = math.max(need, Z.GAP * 2 + Z.M * 2 + Z.P10 + cell + T.measure(T.fontTile, P.sub)) end
    -- (as wide as the widest hints it can show: the chosen row changes them)
    local win = P.canOpen() and (Z.HINT_GAP + P.hintW(KEYS.open, s.open)) or 0
    if hasItem then
        need = math.max(need, Z.L + P.hintW(KEYS.take, s.take) + Z.HINT_GAP + P.hintW(KEYS.all, s.all) + win + Z.L)
        if hasBag then
            for _, l in ipairs({s.peek, s.fold}) do
                need = math.max(need, Z.L + P.hintW(KEYS.take, l) + Z.HINT_GAP + P.hintW(KEYS.all, s.all) + win + Z.L)
            end
        end
    end
    if hasAct then need = math.max(need, Z.L + P.hintW(KEYS.take, s.use) + win + Z.L) end
    P.needW = math.min(Z.MAXW, math.max(Z.MINW, math.ceil(need)))
end

function P.hintW(key, label)
    return T.measure(T.fontTile, key) + 10 + 6 + math.ceil(T.measure(T.fontText, label))
end

function P.hasSub()
    return P.sub ~= nil
end

function P.canOpen()
    return P.loot and not P.locked
end

-- The header: the picture, the name, what is in it ("12 things · 4.3 kg")
function P.head()
    local s = strings()
    local kind = P.src.kind()
    local c1 = P.containers[1]
    P.tex, P.icon = nil, nil
    if P.loot then
        if kind == 0 and not c1 then
            P.title = P.src.title(nil) or ""
            P.tex = P.src.containerIcon(nil)
        elseif #P.containers == 1 and kind ~= 0 then
            P.title = P.src.title(c1) or ""
            P.tex = P.src.containerIcon(c1)
        else
            P.title = P.src.title(c1) or P.src.title(nil) or ""
            P.tex = P.src.containerIcon(c1)
        end
    else
        P.title = P.src.actionsTitle() or getText("IGUI_Controller_Interact")
        local first = nil
        for _, r in ipairs(P.rows) do if r.kind == "act" then first = r break end end
        P.icon = (first and first.icon) or texOf("here")
    end
    P.sub = nil
    if P.locked then
        P.sub = s.locked
    elseif P.loot then
        P.sub = "0"   -- (made each frame from the count: P.drawHead)
    end
end

-- Input --------------------------------------------------------------------------------

P.hold = nil      -- {ms, row, started}: the take key held on a bag
P.retract = nil   -- {key, p0, ms}: a held take let go early, its fill running back

local function chosen()
    return P.pick[P.sel]
end

local function grab(player, items) P.src.grab(player, items) end
local function pendingP(item) return P.src.pending(item) end

--- One thing of the row (not one already on its way).
local function takeOne(player, r)
    for _, it in ipairs(r.items) do
        if not pendingP(it) then
            grab(player, {it})
            return
        end
    end
end

--- Everything of the list the chosen row is in: the container's things, or the bag's.
local function takeAll(player)
    local r = chosen()
    local depth, parent = 0, nil
    if r and r.kind == "item" then depth, parent = r.depth, r.parent end
    local list = {}
    for _, q in ipairs(P.rows) do
        if q.kind == "item" and not q.leaveMs and not q.closing and q.depth == depth and q.parent == parent then
            for _, it in ipairs(q.items) do
                if not pendingP(it) then table.insert(list, it) end
            end
        end
    end
    if #list > 0 then grab(player, list) end
end

local function toggleBag(r)
    local st = P.bags[r.bag]
    if not st then
        st = {to = false, k = 0}
        P.bags[r.bag] = st
    end
    st.to = not st.to
    P.dirty = true
end

local function cancel(player, item) P.src.cancel(player, item) end

local function input(player, now)
    local wheel = P.src.wheel()
    local pressed = P.src.pressed()
    if wheel ~= 0 and not P.hold and #P.pick > 0 then
        P.sel = math.max(1, math.min(#P.pick, P.sel + wheel))
    end
    -- the take key held on a bag: past HOLD_MS the bag is taken; let go sooner,
    -- the bag opens (or folds)
    local h = P.hold
    if h then
        if not P.src.held() then
            P.hold = nil
            if not h.started then
                toggleBag(h.row)
            elseif pendingP(h.row.bag) then
                P.retract = {key = h.row.key, p0 = pendingP(h.row.bag) or 0, ms = now}
                cancel(player, h.row.bag)
            end
        elseif not h.started and now - h.ms >= HOLD_MS then
            h.started = true
            P.hints = nil   -- ("Look in" turns to "Take")
            grab(player, {h.row.bag})
        end
    end
    if pressed == 0 or P.locked then return end
    local r = chosen()
    if pressed == 2 then
        if P.loot then takeAll(player) end
        return
    end
    if not r then return end
    if r.kind == "act" then
        P.src.run(r.index)
    elseif r.kind == "item" then
        if r.bag and r.depth == 0 then
            if not P.hold then P.hold = {ms = now, row = r} end
        else
            takeOne(player, r)
        end
    end
end

--- The container of the chosen row, for Viewpoint's open-window key (KnoxMain):
--- a fridge's freezer when its row is chosen; a bag's thing - the container the bag is in.
function P.chosen()
    if not P.visible then return nil end
    local r = chosen()
    if not r or r.kind ~= "item" then return P.containers[1] end
    if r.depth > 0 then
        for _, q in ipairs(P.rows) do
            if q.bag == r.parent then return q.container end
        end
    end
    return r.container
end

-- Each frame: heights, growth, the list's window -----------------------------------------

local function bagK(r)
    if r.depth == 0 or not r.parent then return 1 end
    local st = P.bags[r.parent]
    return st and st.k or 0
end

local function rowFull(r)
    if r.kind == "item" then return Z.ROW + Z.GROW_H * (P.grow[r.key] or 0) end
    if r.kind == "label" then return Z.LABEL end
    if r.kind == "sep" then return Z.SEP end
    return Z.ROW
end

local function layout(now, dt)
    local L = P.L
    local rows = P.rows
    -- heights: a row entering opens to its height, one leaving folds, a bag's
    -- things open and close with it; whole pixels by the running sum (rounded
    -- each on its own, the rows summed to a pixel more or less and the plate
    -- shook - the author's video, 2026-10-25)
    local acc, listH, baseH, labels = 0, 0, 0, false
    for _, r in ipairs(rows) do
        if r.region == "list" then
            local full = rowFull(r)
            local k = ease(bagK(r))
            local hf = full
            if r.leaveMs then
                r.leave = math.min(1, (now - r.leaveMs) / LEAVE_MS)
                hf = full * (1 - ease(r.leave))
            elseif r.enterMs then
                r.enter = math.min(1, (now - r.enterMs) / ENTER_MS)
                if r.enter >= 1 then r.enter, r.enterMs = nil, nil else hf = full * ease(r.enter) end
            end
            hf = hf * k
            r.full = full
            local a = math.floor(acc + 0.5)
            acc = acc + hf
            r.h = math.floor(acc + 0.5) - a
            r.y = a
            listH = listH + r.h
            if r.kind == "label" then labels = true end
            -- (where the rows are going, for the scroll's decision: a row growing,
            -- a bag opening or closing must not flip it)
            if r.closing then
            elseif r.leave then baseH = baseH + math.min(r.h, Z.ROW)
            elseif r.kind == "label" or r.kind == "sep" then baseH = baseH + r.h
            else baseH = baseH + Z.ROW end
        end
    end
    -- scrolled or not; u runs between them so the list opens out smoothly
    local maxList = Z.MAXV * Z.ROW + (labels and Z.LABEL or 0)
    local limit = L.wasClip and ((Z.MAXV - 1) * Z.ROW + 2 * Z.STRIP) or maxList
    local wantClip = baseH > limit
    L.wasClip = wantClip
    local to = wantClip and 0 or 1
    L.u = L.u == nil and to or (L.u + (to - L.u) * (1 - math.exp(-dt / 70)))
    if math.abs(L.u - to) < 0.01 then L.u = to end
    local u = L.u
    local clipped = u < 1
    local strip = math.floor(Z.STRIP * (1 - u) + 0.5)
    local ph = P.hasSub() and Z.PH_SUB or Z.PH
    local first = rows[1]
    local y = Z.GAP + ph + ((first and first.kind == "label") and math.floor(3 * u + Z.GAP * (1 - u) + 0.5) or Z.GAP)
    if not first then y = Z.GAP + ph end
    local CAPR = (Z.MAXV - 1) * Z.ROW + Z.GROW_H + 2 * Z.STRIP
    local goal = baseH + Z.GROW_H
    local regionH
    if not clipped then regionH = listH
    elseif wantClip then regionH = math.min(listH, CAPR)
    else regionH = math.min(listH, math.floor(CAPR + math.max(0, math.min(listH, goal) - CAPR) * u + 0.5)) end
    L.ph, L.cell = ph, ph - 2 * Z.M
    L.clipped, L.strip, L.listH = clipped, strip, listH
    L.regionY, L.regionH = y, regionH
    L.viewY = clipped and (y + strip) or y
    L.viewH = clipped and (regionH - 2 * strip) or listH
    -- (scrolled: whole rows in the window)
    local maxScroll = 0
    if clipped then
        for _, r in ipairs(rows) do
            if r.region == "list" and r.y >= listH - L.viewH then maxScroll = r.y break end
        end
    end
    L.maxScroll = maxScroll
    y = y + regionH
    for _, r in ipairs(rows) do
        if r.region == "acts" then
            r.h = rowFull(r)
            r.y = y
            y = y + r.h
        end
    end
    L.hasFoot = P.hintCount > 0
    L.footY = L.hasFoot and (y + Z.GAP) or nil
    if L.hasFoot then L.H = L.footY + 1 + Z.GAP + Z.KH + Z.GAP
    elseif #rows > 0 then L.H = y + Z.GAP
    else L.H = Z.GAP + ph + Z.GAP end
end

--- The scroll that shows the chosen row (about the middle, on a whole row).
local function scrollFor(r, scroll)
    local L = P.L
    if not r or r.region ~= "list" or not L.clipped then return 0 end
    -- (aimed at the row as it will settle, grown: aimed at rows still growing,
    -- the target jumped and the list jerked back when scrolled fast - 2026-10-25)
    local h = Z.ROW + Z.GROW_H
    local want = r.y - (L.viewH - h) / 2
    local sc = 0
    for _, q in ipairs(P.rows) do
        if q.region == "list" and q.y <= want then sc = q.y end
    end
    sc = math.min(sc, L.maxScroll)
    if r.y + h > sc + L.viewH then
        for _, q in ipairs(P.rows) do
            if q.region == "list" and q.y >= r.y + h - L.viewH then sc = q.y break end
        end
    end
    if r.y < sc then sc = r.y end
    return sc
end

local function animate(now, dt)
    local L = P.L
    -- bags open and close in BAG_MS
    for bag, st in pairs(P.bags) do
        local to = st.to and 1 or 0
        if st.k ~= to then
            local step = T.animOn() and dt / BAG_MS or 1
            st.k = st.k + math.max(-step, math.min(step, to - st.k))
            if st.k == 0 then P.dirty = true end   -- (closed: its things leave the list)
        end
    end
    -- the chosen row grows, the one it left shrinks back (exp, 60 ms); the growth
    -- shared out so it sums to one row's: the list keeps its height
    local kg = T.animOn() and (1 - math.exp(-dt / 60)) or 1
    local r0 = chosen()
    local sum = 0
    for _, r in ipairs(P.rows) do
        if r.kind == "item" then
            local g0 = P.grow[r.key] or 0
            local to = (r == r0 and not r.leaveMs) and 1 or 0
            local g = g0 + (to - g0) * kg
            P.grow[r.key] = g
            sum = sum + g
        end
    end
    if r0 and r0.kind == "item" and sum > 0 then
        for _, r in ipairs(P.rows) do
            if r.kind == "item" then P.grow[r.key] = P.grow[r.key] / sum end
        end
    end
    -- the plate's width eases to the new one (exp, 70 ms)
    local kw = T.animOn() and (1 - math.exp(-dt / 70)) or 1
    P.w = P.w == nil and P.needW or (P.w + (P.needW - P.w) * kw)
    if math.abs(P.w - P.needW) < 0.3 then P.w = P.needW end
    -- the weight in the header runs to the new one
    P.shownW = P.shownW == nil and P.sumW or (P.shownW + (P.sumW - P.shownW) * kw)
    if math.abs(P.shownW - P.sumW) < 0.005 then P.shownW = P.sumW end
end

-- Drawing ---------------------------------------------------------------------------------

local band = {0, 0, 0, 0}
local labelOpts = {}
local function label(ui, s, x, y, w, h, c, font, a, align)
    band[1], band[2], band[3], band[4] = x, y, w, h
    labelOpts.font, labelOpts.a, labelOpts.align = font, a, align
    return T.label(ui, s, band, c, labelOpts)
end

-- (stencils one inside another: the list's window, a row opening in it. The game's
-- clips nest - each a level of the stencil inside the last, a clear takes one level
-- off and leaves its box a hole in the one outside: that box is painted back to the
-- outer level (repaintStencilRect, as KnoxDashboard's unclip). Set again instead, a
-- level was left on every frame and all after the list was cut away - the keys at
-- the foot, the first container's name: the author's screenshots, 2026-10-25)
local stencil = {}
local function pushClip(ui, x, y, w, h)
    local n = #stencil
    if n > 0 then
        local p = stencil[n]
        local x2, y2 = math.min(x + w, p[1] + p[3]), math.min(y + h, p[2] + p[4])
        x, y = math.max(x, p[1]), math.max(y, p[2])
        w, h = math.max(0, x2 - x), math.max(0, y2 - y)
    end
    local e = stencil[n + 1] or {}
    e[1], e[2], e[3], e[4] = x, y, w, h
    stencil[n + 1] = e
    ui:setStencilRect(x, y, w, h)
end
local function popClip(ui)
    local n = #stencil
    local e = stencil[n]
    stencil[n] = nil
    ui:clearStencilRect()
    if n > 1 then ui:repaintStencilRect(e[1], e[2], e[3], e[4]) end
end

--- T.marquee clips to its line and takes that off: inside the list's window the
--- line's box is painted back to the window's level (cut to the window - painted
--- past it, the window would grow).
local function marqueeBack(ui, x, y, w, h)
    local n = #stencil
    if n == 0 then return end
    local p = stencil[n]
    local x2, y2 = math.min(x + w, p[1] + p[3]), math.min(y + h, p[2] + p[4])
    x, y = math.max(x, p[1]), math.max(y, p[2])
    if x2 > x and y2 > y then ui:repaintStencilRect(x, y, x2 - x, y2 - y) end
end

-- Chevron of 2 px dots; dir 1 right, 2 up, -2 down. (x, y): the tip's base corner, s the half size.
local function chevron(ui, x, y, s, dir, c, a)
    for i = 0, s do
        if dir == 1 then
            ui:drawRect(x + i, y - s + i, 2, 2, a, c.r, c.g, c.b)
            ui:drawRect(x + i, y + s - i, 2, 2, a, c.r, c.g, c.b)
        elseif dir == 2 then
            ui:drawRect(x - i, y + i, 2, 2, a, c.r, c.g, c.b)
            ui:drawRect(x + i, y + i, 2, 2, a, c.r, c.g, c.b)
        else
            ui:drawRect(x - i, y + s - i, 2, 2, a, c.r, c.g, c.b)
            ui:drawRect(x + i, y + s - i, 2, 2, a, c.r, c.g, c.b)
        end
    end
end

--- One row at x0, y (its own top); W its width; sel chosen; taking 0..1 or nil.
--- `inset`: how far in the row is drawn (a bag's things) - its fill still starts
--- at the plate's edge (the author, 2026-10-25).
local function drawRow(ui, r, x0, y, W, sel, taking, a, inset)
    local C = T.color
    local s = strings()
    local RH = r.kind == "item" and r.full or Z.ROW
    if r.kind == "label" then
        local cap = T.upper(r.text)
        local w = label(ui, cap, x0 + Z.L, y + Z.P10, W, Z.LABEL - Z.P10 * 2 + 2, C.dim, T.fontTile, 0.8 * a)
        local lx = x0 + Z.L + math.floor(w + Z.P10 + 0.5)
        T.rect(ui, lx, y + math.floor(Z.LABEL * 0.69 + 0.5), x0 + W - Z.L - lx, 1, C.border, a)
    elseif r.kind == "sep" then
        T.rect(ui, x0 + Z.L, y + math.floor(Z.SEP / 2), W - 2 * Z.L, 1, C.border, a)
    elseif r.kind == "item" then
        if taking then
            local fw = math.floor((W + inset - 2) * taking + 0.5)
            ui:drawRect(x0 + 1 - inset, y, fw, RH, 0.16 * a, C.accent.r, C.accent.g, C.accent.b)
            ui:drawRect(x0 + math.max(1, fw - 1) - inset, y, 2, RH, 0.9 * a, C.accent.r, C.accent.g, C.accent.b)
        end
        -- the chosen row stands out whole: taller, its tile and picture bigger
        -- about the tile's middle, the name a size up
        local g = P.grow[r.key] or 0
        local cs = math.floor(Z.CELL + Z.GROW_CELL * g + 0.5)
        local is = math.floor(Z.IC + Z.GROW_CELL * g + 0.5)
        local ccx, ccy = x0 + Z.L + Z.CELL / 2, y + RH / 2
        local fx, fy = math.floor(ccx - cs / 2 + 0.5), math.floor(ccy - cs / 2 + 0.5)
        T.rect(ui, fx, fy, cs, cs, r.cat, a)
        P.src.icon(ui, r.item, math.floor(ccx - is / 2 + 0.5), math.floor(ccy - is / 2 + 0.5), a, is)
        -- (the frame over the picture; sand while it is being taken)
        T.border(ui, fx, fy, cs, cs, taking and C.accent or tileEdge(r.cat), a)
        local right = x0 + W - Z.L - (r.bag and Z.CHEV or 0)
        if r.bag then
            -- a bag: a chevron at the right, pointing on, turning down as it is looked into
            local st = P.bags[r.bag]
            local open = st and st.k >= 0.5
            local ch = math.max(3, math.floor(Z.P10 * 0.45))
            local cx, cy = x0 + W - Z.L - math.floor(Z.CHEV / 2), math.floor(y + RH / 2)
            if open then chevron(ui, cx - 1, cy - math.floor(ch / 2) - 1, ch, -2, C.dim, a)
            else chevron(ui, cx - math.floor(ch / 2) - 1, cy - 1, ch, 1, C.dim, a) end
        end
        label(ui, r.wtext, x0, y, right - x0, RH, C.dim, T.fontText, a, "right")
        local nf = (g >= 0.5) and Z.big or T.fontText
        local room = W - Z.L - Z.TX - (r.tail or 0)
        local nameW = math.min(T.measure(nf, r.name), room)
        if sel and T.measure(nf, r.name) > room then
            local _, ty = T.inkOrigin(r.name, x0 + Z.TX, y, room, RH, nf)
            T.marquee(ui, P.marquee, r.name, x0 + Z.TX, ty, room, C.bright, nf, a)
            marqueeBack(ui, x0 + Z.TX, ty - 2, room, T.fontH(nf) + 4)   -- (T.marquee's own box)
        else
            label(ui, sel and r.name or T.fit(r.name, nf, room), x0 + Z.TX, y, room, RH, sel and C.bright or C.text, nf, a)
        end
        if r.ntext then label(ui, r.ntext, x0 + Z.TX + math.floor(nameW + Z.P5 + 0.5), y, 0, RH, C.dim, T.fontText, a) end
    elseif r.kind == "act" then
        local tint = (not r.on and C.dim) or (r.danger and RED) or (sel and C.accent) or C.dim
        local ia = r.on and a or a * 0.5
        if r.icon then
            ui:drawTextureScaledAspect(r.icon, x0 + Z.L + math.floor((Z.CELL - Z.AIC) / 2), y + math.floor((Z.ROW - Z.AIC) / 2),
                Z.AIC, Z.AIC, ia, tint.r, tint.g, tint.b)
        end
        local col = (not r.on and C.dim) or (r.danger and RED) or (sel and C.bright) or C.text
        if taking then
            local fw = math.floor((W - 2) * taking + 0.5)
            ui:drawRect(x0 + 1, y, fw, Z.ROW, 0.16 * a, C.accent.r, C.accent.g, C.accent.b)
        end
        label(ui, T.fit(r.name, T.fontText, W - Z.L - Z.TX), x0 + Z.TX, y, W - Z.L - Z.TX, Z.ROW, col, T.fontText,
            r.on and a or a * 0.75)
    elseif r.kind == "searching" then
        -- the thing being looked for: a plate filling with sand from the bottom in a
        -- breathing frame, as on Knox's grid
        local frac = P.src.searchFrac(r.container)
        KnoxSearch.drawCurrent(ui, x0 + Z.L, y + math.floor((Z.ROW - Z.CELL) / 2), Z.CELL, Z.CELL, frac, a)
        label(ui, s.searching, x0 + Z.TX, y, W, Z.ROW, C.dim, T.fontText, a)
    else
        if r.kind == "unsearched" then
            if lensTex == nil then lensTex = getTexture("media/ui/knox_lens.png") or false end
            if lensTex then
                ui:drawTextureScaledAspect(lensTex, x0 + Z.L + math.floor((Z.CELL - Z.AIC) / 2), y + math.floor((Z.ROW - Z.AIC) / 2),
                    Z.AIC, Z.AIC, a, C.dim.r, C.dim.g, C.dim.b)
            end
        end
        label(ui, s[r.kind], x0 + Z.TX, y, W, Z.ROW, C.dim, T.fontText, a)
    end
end

--- How far the row is being taken (its things on their way), or an action done; nil: neither.
local function takingOf(r)
    if r.kind == "act" then
        local p = P.src.actionProgress(r.index)
        return p > 0 and p or nil
    end
    if r.kind ~= "item" then return nil end
    if r.leaveMs then return 1 end
    local best = nil
    for _, it in ipairs(r.items) do
        local p = pendingP(it)
        if p and (not best or p > best) then best = p end
    end
    if not best and P.retract and P.retract.key == r.key then
        local p = P.retract.p0 * (1 - (getTimestampMs() - P.retract.ms) / RETRACT_MS)
        if p > 0 then best = p else P.retract = nil end
    end
    return best
end

-- the hints at the foot: {key, label} pairs of this frame (filled in, not made anew)
local hintKeys, hintLabels = {}, {}
P.hintCount, P.prevCount = 0, 0

local function addHint(n, k, l)
    hintKeys[n + 1], hintLabels[n + 1] = k, l
    return n + 1
end

local function hints()
    local s = strings()
    local r = chosen()
    local n = 0
    if not P.locked and r and r.kind == "item" then
        if r.bag and r.depth == 0 then
            local st = P.bags[r.bag]
            n = addHint(n, KEYS.take, (P.hold and P.hold.started) and s.take or (st and st.to) and s.fold or s.peek)
        else
            n = addHint(n, KEYS.take, s.take)
        end
        n = addHint(n, KEYS.all, s.all)
    elseif r and r.kind == "act" then
        n = addHint(n, KEYS.take, s.use)
    end
    if P.canOpen() then n = addHint(n, KEYS.open, s.open) end
    -- (changed: the old ones fade out, the new come up into place)
    local same = n == P.hintCount
    for i = 1, n do
        if hintKeys[i] ~= P.shownKeys[i] or hintLabels[i] ~= P.shownLabels[i] then same = false end
    end
    if not same then
        if P.hintCount > 0 or P.hintsMs then
            for i = 1, P.hintCount do P.prevKeys[i], P.prevLabels[i] = P.shownKeys[i], P.shownLabels[i] end
            P.prevCount = P.hintCount
            P.hintsMs = getTimestampMs()
        end
        for i = 1, n do P.shownKeys[i], P.shownLabels[i] = hintKeys[i], hintLabels[i] end
        for i = n + 1, #P.shownKeys do P.shownKeys[i], P.shownLabels[i] = nil, nil end
        P.hintCount = n
    end
end
P.shownKeys, P.shownLabels, P.prevKeys, P.prevLabels = {}, {}, {}, {}
P.hintAt = {}   -- where each shown key's plate and label are: x, x2 a pair (a news demo's clicks)

local function drawHints(ui, x, y, ks, ls, n, a)
    local at = ks == P.shownKeys and P.hintAt or nil
    for i = 1, n do
        local x2 = T.keyHint(ui, x, y, ks[i], ls[i], Z.KH, a)
        if at then at[i * 2 - 1], at[i * 2] = x, x2 end
        x = x2 + Z.HINT_GAP
    end
end

local subText, subW = nil, nil

local function drawHead(ui, ox, oy, W, a)
    local C = T.color
    local L = P.L
    local hx, hy, hw = ox + Z.GAP, oy + Z.GAP, W - 2 * Z.GAP
    T.rect(ui, hx, hy, hw, L.ph, C.header, a)
    T.tileFrame(ui, hx, hy, hw, L.ph, C.tileFrame, a)
    local cx, cy, cell = hx + Z.M, hy + Z.M, L.cell
    T.rect(ui, cx, cy, cell, cell, C.cell, a)
    if P.tex then
        local is = math.floor(cell * 0.8 + 0.5)
        ui:drawTextureScaledAspect(P.tex, cx + math.floor((cell - is) / 2), cy + math.floor((cell - is) / 2), is, is, a, 1, 1, 1)
    elseif P.icon then
        local is = math.floor(cell * 0.68 + 0.5)
        local c = C.accent
        ui:drawTextureScaledAspect(P.icon, cx + math.floor((cell - is) / 2), cy + math.floor((cell - is) / 2), is, is, a, c.r, c.g, c.b)
    end
    -- (the picture on a framed plate of its own, as a container's row in the inventory)
    T.tileFrame(ui, cx, cy, cell, cell, C.tileEdge, a)
    local tx = cx + cell + Z.P10
    local tw = hx + hw - Z.M - tx
    if not P.sub then
        label(ui, T.fit(P.title, T.fontHeader, tw), tx, cy, tw, cell, C.bright, T.fontHeader, a)
        return
    end
    -- the name above, what is in it under it, the two about the picture's middle
    local mid = cy + cell / 2
    local bh = math.floor(Z.KH)
    local ty = math.floor(mid - Z.P10 - bh / 2 + 0.5)
    local sy = math.floor(mid + Z.P10 * 1.27 - bh / 2 + 0.5)
    label(ui, T.fit(P.title, T.fontHeader, tw), tx, ty, tw, bh, C.bright, T.fontHeader, a)
    if P.locked then
        if lockTex == nil then lockTex = texOf("lock") or false end
        local ls = math.floor(Z.P10 * 1.2 + 0.5)
        if lockTex then ui:drawTextureScaledAspect(lockTex, tx - 2, sy + math.floor((bh - ls) / 2), ls, ls, a, RED.r, RED.g, RED.b) end
        label(ui, P.sub, tx + ls + 2, sy, tw, bh, RED, T.fontTile, a)
        return
    end
    -- the count: only the digits that change roll, as on a drum counter; sand while
    -- the container itself is being searched
    local busy = false
    for _, c in ipairs(P.containers) do
        if KnoxSearch and KnoxSearch.busy(c) then busy = true end
    end
    local col = busy and C.accent or C.dim
    local ns = P.countText
    local nw = T.measure(T.fontTile, ns)
    T.rollNumber(ui, P.roll, ns, tx, sy, nw, bh, col.r, col.g, col.b, a, T.fontTile)
    -- (the rest made anew only when the shown weight changes)
    local w2 = round2(P.shownW or 0)
    if subW ~= w2 or P.subN ~= P.count then
        subW, P.subN = w2, P.count
        subText = " " .. thingsWord(P.count) .. strings().dot .. w2 .. " " .. strings().kg
    end
    label(ui, subText, tx + nw, sy, tw - nw, bh, C.dim, T.fontTile, a)
end

-- (as Knox's menu: a strip in the header's colour, a chevron where there is more)
local function scrollStrip(ui, ox, y, W, up, on, a, fa)
    local L = P.L
    local ar = 4
    T.rect(ui, ox + 1, y, W - 2, L.strip, T.color.header, a)
    if L.strip >= 8 then
        chevron(ui, ox + math.floor(W / 2) - 1, y + math.floor(L.strip / 2) - 1 - math.floor(ar / 2), ar,
            up and 2 or -2, T.color.text, (on and 1 or 0.3) * fa)
    end
end

local function draw(ui, ox, oy, now)
    local C = T.color
    local L = P.L
    local W = math.floor(P.w + 0.5)
    local H = L.H
    -- the plate as Knox's item tooltip: a shadow, the window, a 1 px frame. The plate
    -- itself is there at once - the unfolded one goes over into it (see P.frame); only
    -- what is in it comes up (faded in from nothing, the plate was gone a moment
    -- after it unfolded: the author, 2026-10-25)
    local a = P.alpha
    T.rect(ui, ox + 4, oy + 6, W, H, BLACK, 0.45)
    T.rect(ui, ox, oy, W, H, C.window, 0.97)
    T.border(ui, ox, oy, W, H, EDGE, 1)
    drawHead(ui, ox, oy, W, a)
    -- the highlight under the chosen row (it glides; under the rows)
    local r0 = chosen()
    if r0 and P.hiA > 0.02 then
        local by, bh = math.floor(P.hiY + 0.5), math.floor(P.hiH + 0.5)
        local inList = r0.region == "list"
        if inList then pushClip(ui, ox, oy + L.viewY, W, L.viewH) end
        T.rect(ui, ox + 1, oy + by, W - 2, bh, HOVER, P.hiA * a)
        T.rect(ui, ox + 1, oy + by, 2, bh, C.accent, P.hiA * a)
        if inList then popClip(ui) end
    end
    -- the list, in its window, scrolled to keep the chosen row in sight
    pushClip(ui, ox, oy + L.viewY, W, L.viewH)
    local ly = oy + L.viewY - math.floor(P.scroll + 0.5)
    -- a bag looked into: a thin line down from its tile, a short one to each of its things
    for j, r in ipairs(P.rows) do
        if r.kind == "item" and r.depth == 0 and r.bag and P.bags[r.bag] and P.bags[r.bag].k > 0 then
            local last = nil
            for m = j + 1, #P.rows do
                local q = P.rows[m]
                if q.region ~= "list" or q.depth == 0 then break end
                if q.h > 2 then last = q end
            end
            if last then
                local ka = ease(P.bags[r.bag].k) * a
                local gx = ox + Z.L + math.floor(Z.CELL / 2) - 1
                local top = ly + math.floor(r.y + r.h / 2 + (Z.CELL + Z.GROW_CELL * (P.grow[r.key] or 0)) / 2 + 0.5) + 3
                local bot = ly + math.floor(last.y + last.h / 2 + 0.5)
                T.rect(ui, gx, top, 1, math.max(0, bot - top + 1), C.tileEdge, ka)
                for m = j + 1, #P.rows do
                    local q = P.rows[m]
                    if q.region ~= "list" or q.depth == 0 then break end
                    if q.h > 2 then
                        local qy = ly + math.floor(q.y + q.h / 2 + 0.5)
                        local qx = ox + Z.L + Z.IND - math.floor(Z.GROW_CELL * (P.grow[q.key] or 0) / 2 + 0.5) - 3
                        T.rect(ui, gx, qy, qx - gx, 1, C.tileEdge, ka)
                    end
                end
            end
        end
    end
    for _, r in ipairs(P.rows) do
        if r.region == "list" and r.h > 0 and ly + r.y + r.h > oy + L.viewY and ly + r.y < oy + L.viewY + L.viewH then
            local inset = r.depth and r.depth > 0 and Z.IND or 0
            local tk = takingOf(r)
            local cut = r.enter or r.leave or (r.depth and r.depth > 0 and bagK(r) < 1)
            if cut then
                -- (opening or folding: cut to its height, fading)
                local fa = r.leave and math.max(0, 1 - r.leave * 1.6) or r.enter and math.max(0, r.enter * 1.6 - 0.6)
                    or math.max(0, bagK(r) * 1.6 - 0.6)
                pushClip(ui, ox, ly + r.y, W, r.h)
                drawRow(ui, r, ox + inset, ly + r.y - math.floor((r.full - r.h) / 2), W - inset, false, tk, fa * a, inset)
                popClip(ui)
            else
                drawRow(ui, r, ox + inset, ly + r.y, W - inset, r == r0, tk, a, inset)
            end
        end
    end
    popClip(ui)
    if L.clipped and L.strip > 0 then
        local fa = (1 - L.u) * a
        scrollStrip(ui, ox, oy + L.regionY, W, true, P.scroll > 1, a, fa)
        scrollStrip(ui, ox, oy + L.regionY + L.regionH - L.strip, W, false, P.scroll < L.maxScroll - 1, a, fa)
    end
    for _, r in ipairs(P.rows) do
        if r.region == "acts" then drawRow(ui, r, ox, oy + r.y, W, r == r0, takingOf(r), a, 0) end
    end
    -- the foot: the keys under a thin line
    if L.hasFoot then
        T.rect(ui, ox + Z.L, oy + L.footY, W - 2 * Z.L, 1, C.border, a)
        local ky = oy + L.footY + 1 + Z.GAP
        local hk = P.hintsMs and math.min(1, (now - P.hintsMs) / HINT_MS) or 1
        if not T.animOn() then hk = 1 end
        if hk < 1 then
            pushClip(ui, ox, ky - 2, W, Z.KH + 4)
            if hk < 0.5 then
                local e = ease(hk * 2)
                drawHints(ui, ox + Z.L, ky - math.floor(e * 3 + 0.5), P.prevKeys, P.prevLabels, P.prevCount, (1 - e) * a)
            else
                local e = ease(hk * 2 - 1)
                drawHints(ui, ox + Z.L, ky + math.floor((1 - e) * 4 + 0.5), P.shownKeys, P.shownLabels, P.hintCount, e * a)
            end
            popClip(ui)
        else
            drawHints(ui, ox + Z.L, ky, P.shownKeys, P.shownLabels, P.hintCount, a)
        end
    end
end

-- The plate unfolding out of the crosshair, folding back into it (T.unfold's);
-- m (1 if not given): how much of it shows - unfolded, it fades over the plate
local function foldPlate(ui, b, k, m)
    local C = T.color
    local sw = Z.SRC
    local sx, sy = b.cx - sw / 2, b.cy - sw / 2
    local x = math.floor(sx + (b.x - sx) * k)
    local y = math.floor(sy + (b.y - sy) * k)
    local fw, fh = math.floor(sw + (b.W - sw) * k), math.floor(sw + (b.H - sw) * k)
    local a = (0.15 + 0.8 * k) * (m or 1)
    T.rect(ui, x, y, fw, fh, C.window, a)
    T.rect(ui, x, y, fw, math.min(fh, math.floor((Z.GAP + b.ph + Z.GAP) * k + 0.5)), C.header, a)
    T.border(ui, x, y, fw, fh, C.accent, a)
end

--- (for a news demo: its clips are a level inside its view's)
P.pushClip, P.popClip = function(ui, x, y, w, h) pushClip(ui, x, y, w, h) end, function(ui) popClip(ui) end
--- (after an error: every level it had on taken off)
function P.clearClips(ui)
    for _ = 1, math.max(1, #stencil) do pcall(ui.clearStencilRect, ui) end
    stencil = {}
end
P.sizes, P.Z, P.keys = sizes, Z, KEYS
P.chosenRow = function() return chosen() end

-- The frame -------------------------------------------------------------------------------

P.roll, P.marquee = {}, {}
P.visible = false
P.ghost = nil    -- {x, y, W, H, ph, cx, cy, ms}: a plate left, folding away
P.box = nil

-- (all a plate's own state: a news demo's plate swaps its own in for its frame - P.swap)
P.STATE = {"rows", "pick", "sel", "grow", "bags", "seen", "L", "w", "shownW", "hold", "retract", "hintsMs",
    "hintCount", "prevCount", "shownKeys", "shownLabels", "prevKeys", "prevLabels", "hintAt", "roll", "marquee",
    "scroll", "hiY", "hiH", "hiA", "openMs", "sigMs", "dirty", "visible", "ghost", "box", "tobj", "tsq", "tkind",
    "target", "builtFor", "locked", "loot", "containers", "tex", "icon", "title", "sub", "count", "sumW",
    "countText", "needW", "alpha", "sig", "ms", "subN", "hints", "src"}

--- Swap the panel's state with `st`'s (twice: back as it was).
function P.swap(st)
    for _, k in ipairs(P.STATE) do
        P[k], st[k] = st[k], P[k]
    end
end

local function reset(now)
    P.rows, P.pick, P.sel, P.grow, P.bags, P.seen = {}, {}, 1, {}, {}, {}
    P.L = {}
    P.w, P.shownW, P.hold, P.retract, P.hintsMs = nil, nil, nil, nil, nil
    P.hintCount, P.prevCount = 0, 0
    P.shownKeys, P.shownLabels, P.prevKeys, P.prevLabels, P.hintAt = {}, {}, {}, {}, {}
    P.roll, P.marquee = {}, {}
    P.scroll, P.hiY, P.hiH, P.hiA = 0, 0, 0, 0
    P.openMs = now
    P.sigMs = 0
    P.dirty = true
end

--- A number that changes when what the panel shows does: the things in its
--- containers and open bags, the search, the actions. (Cheap: sizes and ids.)
local function signature()
    local src = P.src
    local sig = src.actions() * 7 + (src.locked() and 3 or 0)
    local cs = src.containers()
    for i = 0, (cs and cs:size() or 0) - 1 do
        local items = cs:get(i):getItems()
        local n = items:size()
        sig = sig * 31 + n
        if n > 0 then sig = sig * 31 + items:get(0):getID() + items:get(n - 1):getID() * 3 end
        sig = sig % 1000000007
    end
    if src.kind() == 0 then sig = sig * 31 + src.groundCount(src.square()) end
    for bag, st in pairs(P.bags) do
        if st.k > 0 and bag:getInventory() then sig = (sig * 31 + bag:getInventory():getItems():size()) % 1000000007 end
    end
    sig = (sig * 31 + src.searchSig()) % 1000000007
    return sig
end

local function sumUp()
    local n, w = 0, 0
    for _, r in ipairs(P.rows) do
        if r.kind == "item" and r.depth == 0 and not r.leaveMs then
            n, w = n + r.n, w + r.w
        end
    end
    P.count, P.sumW = n, w
    P.countText = tostring(n)
end

P.failed = false
P.owned = false

local function want()
    return not P.failed and KnoxCompat.vpHas("panel") and T.on("inventory") and T.switch("vp.panel")
end

P.reset = function(now) reset(now) end

--- The plate left behind folds back into the crosshair.
function P.drawGhost(ui, now)
    if not P.ghost then return end
    local t = T.anim((now - P.ghost.ms) / FOLD_MS)
    local k = (1 - t) * (1 - t)
    if t < 1 and k > 0.01 then foldPlate(ui, P.ghost, k) else P.ghost = nil end
end

function P.frame(ui)
    local now = getTimestampMs()
    local dt = math.min(100, now - (P.ms or now))
    P.ms = now
    sizes()
    keys(now)
    local player = getSpecificPlayer(0)
    local own = want()
    if own ~= P.owned then P.owned = knoxVpPanelOwn(own) == true end
    local shown = P.owned and player ~= nil and not player:isDead() and knoxVpPanelShown() and not KnoxCompat.windowOpen()
    if shown then
        local obj, sq, kind = knoxVpPanelObject(), P.src.square(), P.src.kind()
        if not P.visible or obj ~= P.tobj or sq ~= P.tsq or kind ~= P.tkind then
            -- (looked from one thing to another: the old plate folds away as the new one unfolds)
            if P.visible and P.box then P.ghost = P.box P.ghost.ms = now end
            P.tobj, P.tsq, P.tkind = obj, sq, kind
            P.target = {}
            reset(now)
            P.visible = true
        end
    elseif P.visible then
        if P.box then P.ghost = P.box P.ghost.ms = now end
        P.visible, P.box, P.hold = false, nil, nil
    end
    P.drawGhost(ui, now)
    if not P.visible then
        -- (nothing pressed waits for the next thing looked at)
        if P.owned then
            P.src.wheel()
            P.src.pressed()
        end
        return
    end
    P.step(player, now, dt)
    -- where: beside the crosshair, as Viewpoint's (left of it with the camera over
    -- the left shoulder); held about it as if the chosen row were grown, so the
    -- header stays put when the choice moves to the actions
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local cx, cy = math.floor(sw / 2), math.floor(sh / 2)
    local W = math.floor(P.w + 0.5)
    local Hc = P.heldH()
    local ox = knoxVpPanelLeft() and math.max(0, cx - Z.AWAY - W) or math.min(cx + Z.AWAY, sw - W)
    local oy = math.max(0, math.floor(cy - Hc / 2 + 0.5))
    P.paint(ui, ox, oy, cx, cy, now)
end

--- What a frame works out before drawing: the keys, the search, the rows when what
--- they show changed, the growth, the hints, the heights, the scroll, the highlight.
function P.step(player, now, dt)
    input(player, now)
    local opened = T.anim((now - P.openMs) / UNFOLD_MS) >= 1
    if opened then P.src.search(player) end
    if P.dirty or now - P.sigMs > 100 then
        P.sigMs = now
        local sig = signature()
        -- (rows still folding away: built again once they are gone)
        local leaving = false
        for _, r in ipairs(P.rows) do
            if r.leaveMs and now - r.leaveMs >= LEAVE_MS then leaving = true end
        end
        if P.dirty or sig ~= P.sig or leaving then
            P.dirty, P.sig = false, sig
            P.build(player)
            P.head()
            P.measureNeed()
            sumUp()
        end
    end
    if P.sel > #P.pick then P.sel = #P.pick end
    if P.sel < 1 and #P.pick > 0 then P.sel = 1 end
    animate(now, dt)
    hints()
    layout(now, dt)
    -- the scroll aims at the chosen row as it will settle; the highlight follows the row
    local k = T.animOn() and (1 - math.exp(-dt / 38)) or 1
    local r0 = chosen()
    local L = P.L
    if r0 then
        local target = scrollFor(r0, P.scroll)
        P.scroll = P.scroll + (target - P.scroll) * k
        local ty = r0.region == "list" and (L.viewY + r0.y - P.scroll) or r0.y
        if P.hiA < 0.05 then P.hiY, P.hiH = ty, r0.h end
        P.hiY = P.hiY + (ty - P.hiY) * k
        P.hiH = P.hiH + (r0.h - P.hiH) * k
        P.hiA = P.hiA + (1 - P.hiA) * k
    else
        P.hiA = P.hiA * (1 - k)
    end
end

--- The plate's height as if the chosen row were grown (what it is held about).
function P.heldH()
    local L = P.L
    local extra = 0
    local anyItem = false
    for _, r in ipairs(P.rows) do
        if r.kind == "item" and r.region == "list" then
            anyItem = true
            extra = extra + math.max(0, r.h - Z.ROW)
        end
    end
    return (anyItem and not L.clipped) and (L.H - extra + Z.GROW_H) or L.H
end

--- The plate at ox, oy, unfolding out of cx, cy (the crosshair) at first.
function P.paint(ui, ox, oy, cx, cy, now)
    local L = P.L
    local W = math.floor(P.w + 0.5)
    P.box = P.box or {}
    local b = P.box
    b.x, b.y, b.W, b.H, b.ph, b.cx, b.cy = ox, oy, W, L.H, L.ph, cx, cy
    -- opening: the empty plate unfolds out of the crosshair, then what is in it shows
    local ut = T.anim((now - P.openMs) / UNFOLD_MS)
    if ut < 1 then
        foldPlate(ui, b, 1 - (1 - ut) * (1 - ut))
        return
    end
    P.alpha = T.animOn() and math.min(1, (now - P.openMs - UNFOLD_MS) / SHOW_MS) or 1
    draw(ui, ox, oy, now)
    if P.alpha < 1 then foldPlate(ui, b, 1, 1 - P.alpha) end
end

-- The element it is drawn on: 0 x 0 at the screen's corner - never takes a click
KnoxCrosshairLayer = ISUIElement:derive("KnoxCrosshairLayer")

function KnoxCrosshairLayer:new()
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    return o
end

function KnoxCrosshairLayer:render()
    if P.failed then return end
    local ok, err = pcall(P.frame, self)
    if not ok then
        -- (anything amiss: Viewpoint's own panel is back, said once)
        P.failed = true
        P.clearClips(self)
        if knoxVpPanelOwn then knoxVpPanelOwn(false) end
        P.owned = false
        print("[Knox] crosshair panel off after an error, Viewpoint's own panel is back: " .. tostring(err))
    end
end

Events.OnGameStart.Add(function()
    if not KnoxTheme.active or not KnoxCompat.vpHas("panel") or not knoxVpPanelOwn then return end
    if P.layer then return end
    P.layer = KnoxCrosshairLayer:new()
    P.layer:initialise()
    P.layer:addToUIManager()
    P.layer:setAlwaysOnTop(true)
end)

return KnoxCrosshair
