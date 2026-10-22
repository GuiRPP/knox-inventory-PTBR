-- The thread from an item's tile or slot to a window about it (bag window,
-- inspect window): right-angled segments, a small square at each end. It
-- leaves the tile from the side facing the window (any of the four), so it
-- never crosses the tile's icon. A window draws it first thing in its
-- prerender, so the window covers its own end of it.

require "Knox/KnoxTheme"

KnoxThread = KnoxThread or {}
local T = KnoxTheme

local function absRect(el)
    return el:getAbsoluteX(), el:getAbsoluteY(), el:getWidth(), el:getHeight()
end

--- Where an item is shown on screen, as an absolute rect: a grid tile, an
--- equipment slot or a quick slot. nil when not shown. `skipView` = a grid
--- view not to look in (a bag window's own grid).
function KnoxThread.sourceRect(item, skipView)
    for _, v in ipairs(KnoxActions.allViews()) do
        if v ~= skipView and v:getIsVisible() and v.layout then
            for _, e in ipairs(v.layout.placed) do
                if e.item == item and not e.reserved then
                    -- (a bag with compartments puts the tile where its compartment is)
                    local tx, ty, tw, th = v:tileRect(e)
                    if tx then return v:getAbsoluteX() + tx - 1, v:getAbsoluteY() + ty - 1, tw + 1, th + 1 end
                end
            end
        end
    end
    local s = KnoxScreen and KnoxScreen.instance
    if not s then return nil end
    if s.equipment then
        for _, sl in ipairs(s.equipment.slots or {}) do
            if sl:getIsVisible() then
                for _, it in ipairs(sl:items()) do
                    if it == item then return absRect(sl) end
                end
            end
        end
    end
    local back = s.equipment and s.equipment.backSlot
    if back and back:getIsVisible() and back:item() == item then return absRect(back) end
    for _, q in ipairs(s.quickSlots or {}) do
        if q:item() == item then return absRect(q) end
    end
    return nil
end

--- Draw the thread from the source rect to window `win` (local coordinates
--- of `win`). `active`: bright, else softer.
function KnoxThread.draw(win, sx, sy, sw, sh, headerH, active)
    if not sx then return end
    local ax, ay = win:getAbsoluteX(), win:getAbsoluteY()
    local w, h = win:getWidth(), win:getHeight()
    local inset = 10

    -- gaps between the tile and the window on each axis (negative = overlap)
    local gapRight = ax - (sx + sw)
    local gapLeft = sx - (ax + w)
    local gapBelow = ay - (sy + sh)
    local gapAbove = sy - (ay + h)
    local gapX = math.max(gapRight, gapLeft)
    local gapY = math.max(gapBelow, gapAbove)
    if gapX <= 0 and gapY <= 0 then return end   -- the window covers the tile

    local x1, y1, x2, y2, horizontal
    if gapX >= gapY then
        horizontal = true
        x1 = gapRight > 0 and (sx + sw) or sx
        y1 = sy + math.floor(sh / 2)
        x2 = gapRight > 0 and ax or (ax + w)
        y2 = ay + math.floor(headerH / 2)
    else
        horizontal = false
        x1 = sx + math.floor(sw / 2)
        y1 = gapBelow > 0 and (sy + sh) or sy
        x2 = math.max(ax + inset, math.min(ax + w - inset, x1))
        y2 = gapBelow > 0 and ay or (ay + h)
    end
    x1, y1, x2, y2 = x1 - ax, y1 - ay, x2 - ax, y2 - ay

    local c, a, t = T.color.accent, active and 0.9 or 0.35, 2
    local function hline(xa, xb, y)
        if xb < xa then xa, xb = xb, xa end
        win:drawRect(xa, y - 1, xb - xa + t, t, a, c.r, c.g, c.b)
    end
    local function vline(x, ya, yb)
        if yb < ya then ya, yb = yb, ya end
        win:drawRect(x - 1, ya, t, yb - ya + t, a, c.r, c.g, c.b)
    end
    if horizontal then
        local mid = math.floor((x1 + x2) / 2)
        hline(x1, mid, y1)
        vline(mid, y1, y2)
        hline(mid, x2, y2)
    else
        local mid = math.floor((y1 + y2) / 2)
        vline(x1, y1, mid)
        hline(x1, x2, mid)
        vline(x2, mid, y2)
    end
    local p = 6
    local pa = active and 1 or 0.5
    win:drawRect(x1 - p / 2, y1 - p / 2, p, p, pa, c.r, c.g, c.b)
    win:drawRect(x2 - p / 2, y2 - p / 2, p, p, pa, c.r, c.g, c.b)
end

return KnoxThread
