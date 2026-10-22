-- Moving a window that is a child of the Knox screen by its header.
-- (ISPanel's own moveWithMouse moves the parent of a child panel - here it
-- would drag the whole screen.)

KnoxWindowDrag = KnoxWindowDrag or {}
local W = KnoxWindowDrag

--- Start moving `win` if the press at local x,y is on its header.
function W.begin(win, x, y, headerH)
    if y < 0 or y >= headerH then return false end
    win.knoxMove = {mx = getMouseX(), my = getMouseY(), x = win:getX(), y = win:getY()}
    return true
end

--- Follow the mouse (call from onMouseMove and onMouseMoveOutside).
function W.update(win)
    local m = win.knoxMove
    if not m then return end
    if not isMouseButtonDown(0) then
        win.knoxMove = nil
        return
    end
    local parent = win.parent
    local pw = parent and parent:getWidth() or getCore():getScreenWidth()
    local ph = parent and parent:getHeight() or getCore():getScreenHeight()
    local nx = m.x + getMouseX() - m.mx
    local ny = m.y + getMouseY() - m.my
    -- keep at least the header on screen
    nx = math.max(-win:getWidth() + 40, math.min(pw - 40, nx))
    ny = math.max(0, math.min(ph - 20, ny))
    win:setX(nx)
    win:setY(ny)
end

function W.stop(win)
    win.knoxMove = nil
end

--- Give a window class header dragging.
function W.install(class)
    class.onMouseMove = function(self, dx, dy) W.update(self) return true end
    class.onMouseMoveOutside = function(self, dx, dy) W.update(self) return true end
    class.onMouseUp = function(self, x, y) W.stop(self) return true end
    class.onMouseUpOutside = function(self, x, y) W.stop(self) return true end
end

return KnoxWindowDrag
