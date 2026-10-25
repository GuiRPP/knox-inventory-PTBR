-- The pinned post (Boosty and the roadmap, the author 2026-10-25) on the game's Lua with
-- tools/pinned/stubs.lua: the news file puts it first with its roadmap, every card opens
-- an update of the file, the panels draw over the opening's whole run without a clip left
-- on or nested, the drag scrolls, a click opens the update's own post, no card left out
-- while the mouse goes from card to card, the button and the coin open Boosty, a second opening runs twice as fast.
local N, M, P, B = KnoxNews, KnoxRoadmap, KnoxPinned, KnoxNewsBack
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end
local function run(name, f)
    local ok, err = pcall(f)
    check(name, ok, err)
end

local W, H = 1920, 1080
local px, top, pw, ph = 40, 120, 1100, 860
local function frame(st, post, scroll)
    local h = P.drawLeft(UI, post, st, px, top, pw, ph, scroll or 0)
    P.drawRight(UI, px + pw + 20, top, 700, ph)
    P.cardShine(UI, 60, 140, 300, 180)
    B.drawStrip(UI, "road", px + 2, top + 2, pw - 4, ph - 4, N.PINNED_COLOR, 0, top + 300, 40, 1)
    if STENCIL.level ~= 0 then STENCIL.left = STENCIL.left + 1 STENCIL.level = 0 UI.knoxClip = nil end
    return h
end
local function frames(st, post, n, ms)
    local h
    for _ = 1, n do
        clock = clock + (ms or 16)
        h = frame(st, post)
    end
    return h
end

local posts, pin
run("the news file", function()
    posts = N.load()
    pin = posts[1]
    check("posts", #posts > 5, #posts)
    check("pinned first", N.isPinned(pin), pin and pin.tag)
    local only = 0
    for _, p in ipairs(posts) do if N.isPinned(p) then only = only + 1 end end
    check("one pinned", only == 1, only)
    local rows = N.road(pin)
    check("14 stages", #rows == 14, #rows)
    local now, nowI = N.roadNow(pin)
    check("now", now ~= nil and nowI == 11, nowI)
    check("id by the last stage", pin.id == "pinned|" .. now.date .. "|" .. now.version, pin.id)
    for i, r in ipairs(rows) do
        if r.future then
            check("future without a date " .. i, r.date == "", r.date)
        else
            check("a date " .. i, string.match(r.date, "^%d%d%.%d%d$") ~= nil, r.date)
        end
        if r.link ~= "" then check("link " .. i .. " opens a post", N.byTitle(r.link) ~= nil, r.link) end
    end
    for _, b in ipairs(pin.body) do
        if string.match(b, "^%s*@boosty") then pin.hasBoosty = true end
    end
    check("Boosty in the post", pin.hasBoosty)
end)

local st
run("the opening, in full", function()
    T = KnoxTheme
    T.settings["news.roadSeen"] = nil
    st = {}
    MOUSE.x, MOUSE.y, MOUSE.down = -1, -1, false
    local h = frames(st, pin, 1)
    check("drawn", DRAWN.label > 0 and DRAWN.rect > 0)
    check("body height", type(h) == "number" and h > 400, h)
    check("first opening: full speed", st.road.K == 1, st.road.K)
    check("seen kept", T.settings["news.roadSeen"] ~= nil and SAVED == 1, SAVED)
    check("view set", UI.view and UI.view[4] > 0)
    check("the lane placed", st.road.rect and st.road.rect[3] > 0)
    -- the head runs for its time, then it is free
    frames(st, pin, 600, 16)
    check("run ended", st.road.free == true)
    check("want at the end", st.road.want == st.road.final, tostring(st.road.want) .. " " .. tostring(st.road.final))
end)

run("hover, a click on a card: its own post", function()
    local r = st.road
    -- the mouse over each card in turn until one is hovered
    local hit
    local lane = r.rect
    for x = lane[1] + 10, lane[1] + lane[3] - 10, 20 do
        for y = lane[2] + 10, lane[2] + lane[4] - 10, 20 do
            MOUSE.x, MOUSE.y = x, y
            frames(st, pin, 1)
            if r.hover then hit = {x, y} break end
        end
        if hit then break end
    end
    check("a card hovered", hit ~= nil)
    if not hit then return end
    -- (the reader's: the card's post kept, opened the next frame)
    local opened
    r.onOpen = function(row) opened = row st.openPost = N.byTitle(row.src.link) end
    check("press taken", M.onMouseDown(r, hit[1], hit[2]))
    MOUSE.down = true
    frames(st, pin, 2)
    MOUSE.down = false
    frames(st, pin, 1)
    check("opened", opened ~= nil)
    check("a card with its post", opened and opened.src.link ~= "")
    check("its real post", st.openPost ~= nil and st.openPost.title == opened.src.link and not N.isPinned(st.openPost))
    st.openPost = nil
end)

run("the mouse from card to card: every card drawn every frame", function()
    local r = st.road
    local lane = r.rect
    -- cards drawn = previews drawn (every past card has one)
    local pv = 0
    local orig = UI.drawTextureScaled
    UI.drawTextureScaled = function(self, tex, ...)
        if tex and tex.path and string.find(tex.path, "news/road/", 1, true) then pv = pv + 1 end
        return orig(self, tex, ...)
    end
    MOUSE.x, MOUSE.y = -1, -1
    frames(st, pin, 40)
    pv = 0
    frames(st, pin, 1)
    local base = pv
    check("previews seen", base > 0, base)
    local low, hovered = base, {}
    for x = lane[1] + 20, lane[1] + lane[3] - 20, 9 do
        for _, y in ipairs({lane[2] + 60, lane[2] + 330}) do
            MOUSE.x, MOUSE.y = x, y
            for _ = 1, 2 do
                pv = 0
                frames(st, pin, 1)
                if pv < low then low = pv end
                if r.hover then hovered[r.hover] = true end
            end
        end
    end
    UI.drawTextureScaled = orig
    local n = 0
    for _ in pairs(hovered) do n = n + 1 end
    check("several cards hovered", n >= 2, n)
    check("no card left out", low >= base, low .. " of " .. base)
    MOUSE.x, MOUSE.y = -1, -1
    frames(st, pin, 40)
end)

run("drag and wheel", function()
    local r = st.road
    local lane = r.rect
    r.want = r.maxS / 2
    local w0 = r.want
    local x, y = lane[1] + lane[3] / 2, lane[2] + 3
    MOUSE.x, MOUSE.y = x, y
    check("press", M.onMouseDown(r, x, y))
    MOUSE.down = true
    MOUSE.x = x - 200
    frames(st, pin, 2)
    check("dragged", r.want > w0, tostring(r.want) .. " vs " .. tostring(w0))
    MOUSE.down = false
    frames(st, pin, 1)
    check("not a click", st.subOpen ~= true)
    local w1 = r.want
    check("wheel", M.onMouseWheel(r, x, y, -1))
    check("wheel moved", r.want < w1)
    check("wheel outside", not M.onMouseWheel(r, -50, -50, 1))
    frames(st, pin, 60)
end)

run("the button and the coin open Boosty", function()
    MOUSE.x, MOUSE.y = -1, -1
    frames(st, pin, 1)
    check("button placed", st.btn and st.btn[3] > 0)
    local n = #OPENED
    P.openBoosty()
    check("opened", #OPENED == n + 1 and OPENED[#OPENED] == "https://boosty.to/knoxinventory/donate", OPENED[#OPENED])
end)

run("scrolled: the lane leaves the view cleanly", function()
    for sc = 0, 1200, 37 do
        clock = clock + 16
        frame(st, pin, sc)
    end
end)

run("a second opening: twice as fast", function()
    local st2 = {}
    frames(st2, pin, 1)
    check("K", st2.road.K == 0.5, st2.road.K)
    check("not saved again", SAVED == 1, SAVED)
end)

run("small screen", function()
    KnoxTheme.cell = 32
    local st3 = {}
    for _ = 1, 200 do clock = clock + 33 P.drawLeft(UI, pin, st3, 10, 60, 600, 500, 0) P.drawRight(UI, 620, 60, 300, 500) end
    if STENCIL.level ~= 0 then STENCIL.left = STENCIL.left + 1 STENCIL.level = 0 UI.knoxClip = nil end
    KnoxTheme.cell = 48
end)

run("the night road alone", function()
    for _ = 1, 100 do clock = clock + 16 B.draw(UI, "road", 0, 0, 1000, 800, N.PINNED_COLOR, 0) end
end)

run("the reader: a card's post, back to the roadmap as it was, without a cut", function()
    local R = KnoxMenuNewsReader
    -- (the end of a frame: what R:render does after the post is drawn)
    local function endFrames(n)
        for _ = 1, n do clock = clock + 16 local o = R.instance if o then o:render() end end
    end
    R.open(pin)
    local o = R.instance
    check("pinned open", o ~= nil and o.pin ~= nil and o.back == nil)
    local road = o.pin.road
    road.want, o.scroll = 300, 120
    o.panel, o.artRect = {40, 120, 1100, 860}, {1160, 120, 700, 860}
    local p = N.byTitle(N.road(pin)[3].link)
    check("a real post", p ~= nil and not N.isPinned(p))
    -- (what prerender does with a clicked card)
    o:switch(p, {post = pin, pin = o.pin, scroll = o.scroll})
    local d0 = DRAWN.rect
    endFrames(1)
    check("still the pinned one, sinking", R.instance == o and DRAWN.rect > d0)
    check("no clicks on its way out", o:onMouseDown(500, 500) == true and R.instance == o)
    endFrames(10)
    local o2 = R.instance
    check("its post open", o2 ~= o and o2.post == p and o2.pin == nil and o2.back ~= nil)
    check("the pinned one gone", UIM[o] == nil and UIM[o2] == true)
    check("coming up", o2.fadeInAt ~= nil)
    o2.panel, o2.artRect = o.panel, o.artRect
    endFrames(15)
    check("up", o2.fadeInAt == nil)
    R.leave()
    check("going back, not cut", R.instance == o2 and o2.switchTo ~= nil)
    endFrames(10)
    local o3 = R.instance
    check("back on the pinned post", o3 ~= nil and o3 ~= o2 and o3.post == pin)
    check("its roadmap as left", o3.pin and o3.pin.road == road and road.want == 300, road.want)
    check("scrolled as left", o3.scroll == 120, o3.scroll)
    check("no way back from it", o3.back == nil)
    R.leave()
    check("closed", R.instance == nil)
    -- a post opened from the list closes at once
    R.open(p)
    R.leave()
    check("from the list: closed", R.instance == nil)
end)

run("pictures not read yet: none drawn (no red-white squares)", function()
    READY = false
    local st4 = {}
    local tex0 = DRAWN.tex
    for _ = 1, 60 do
        clock = clock + 16
        P.drawLeft(UI, pin, st4, px, top, pw, ph, 0)
        P.drawRight(UI, px + pw + 20, top, 700, ph)
        P.cardShine(UI, 60, 140, 300, 180)
    end
    if STENCIL.level ~= 0 then STENCIL.left = STENCIL.left + 1 STENCIL.level = 0 UI.knoxClip = nil end
    local what = {}
    for k, n in pairs(UNREAD) do table.insert(what, k .. " x" .. n) end
    check("nothing drawn from a picture", DRAWN.tex == tex0, table.concat(what, ", "))
    READY = true
end)

run("at the start every picture asked for", function()
    local asked = {}
    local orig = getTexture
    getTexture = function(path) asked[path] = true return orig(path) end
    P.preload()
    getTexture = orig
    check("banner", asked["media/ui/knoxmenu/pinned/banner.png"])
    check("glints", asked["media/ui/knoxmenu/pinned/glint_00.png"] and asked["media/ui/knoxmenu/pinned/glint_31.png"])
    check("stage digits", asked["media/ui/knoxmenu/pinned/stage_9.png"])
    check("disc", asked["media/ui/knoxdash/disc.png"])
    local pv = 0
    for _, r in ipairs(N.road(pin)) do
        if r.preview ~= "" then
            pv = pv + 1
            check("preview " .. r.preview, asked[M.previewPath(r.preview)])
        end
    end
    check("previews", pv >= 10, pv)
end)

-- (the menu's fps, the author 2026-10-25: a fade strip draws only its rows of the road's
-- pictures, not each whole picture under a stencil - and the same ones the road drew)
run("a fade strip: its rows of the road's pictures", function()
    local full, parts, scaled = {}, {}, 0
    local oS, oP = UI.drawTextureScaled, UI.javaObject.DrawSubTextureRGBA
    UI.drawTextureScaled = function(self, t, x, y, w, h, ...)
        scaled = scaled + 1
        table.insert(full, {math.floor(x), math.floor(y), math.floor(w), math.floor(h)})
        return oS(self, t, x, y, w, h, ...)
    end
    UI.javaObject.DrawSubTextureRGBA = function(self, t, sx, sy, sw, sh, x, y, w, h, ...)
        table.insert(parts, {x, y, w, h})
        return oP(self, t, sx, sy, sw, sh, x, y, w, h, ...)
    end
    clock = clock + 16
    B.draw(UI, "road", px + 2, top + 2, pw - 4, ph - 4, N.PINNED_COLOR, 0)
    for _, sy in ipairs({top + 2, top + 61, top + 400, top + ph - 5}) do
        scaled = 0
        for i = #parts, 1, -1 do parts[i] = nil end
        B.drawStrip(UI, "road", px, top, pw, ph, N.PINNED_COLOR, 0, sy, 3, 0.5)
        local want = 0
        for _, r in ipairs(full) do
            if r[2] < sy + 3 and r[2] + r[4] > sy and r[1] < px + pw - 2 and r[1] + r[3] > px + 2 then want = want + 1 end
        end
        local inside = true
        for _, r in ipairs(parts) do
            if r[2] < sy or r[2] + r[4] > sy + 3 or r[1] < px + 2 or r[1] + r[3] > px + pw - 2 then inside = false end
        end
        check("no whole picture in strip " .. sy, scaled == 0, scaled)
        check("every picture's part in strip " .. sy, #parts == want and want > 0, #parts .. " of " .. want)
        check("parts inside strip " .. sy, inside)
    end
    UI.drawTextureScaled, UI.javaObject.DrawSubTextureRGBA = oS, oP
end)

run("all along: clips", function()
    check("left on", STENCIL.left == 0, STENCIL.left)
    check("nested", STENCIL.nested == 0, STENCIL.nested)
end)

print("DONE pass=" .. pass .. " fail=" .. fail)
