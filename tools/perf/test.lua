-- KnoxPerf outside the game (tools/perf/test.ps1, run twice: perf=1 and perf=0).
-- On: Knox's handlers are timed, the others are not; Add / Remove stay paired (the
-- game's list doesn't grow over many adds and removes); results pass unchanged;
-- Knox's drawing is wrapped once a game starts; the 10 s block is written.
-- Off: nothing of the game's is touched.

local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (detail and (" : " .. tostring(detail)) or "")) end
end

local P = KnoxPerf
local knox = function(fn, line) return knoxFile(fn, "client/Knox/KnoxMain.lua", line) end

if perf ~= "1" then
    check("off: the counter is off", P ~= nil and P.on == false)
    check("off: Events.OnTick.Add is the game's own", Events.OnTick.Add == ORIGINAL_ADD)
    local h = knox(function() end, 10)
    Events.OnTick.Add(h)
    check("off: a Knox handler goes to the game as it is", LISTS.OnTick[1] == h)
    check("off: nothing written", FILES["knox_perf.txt"] == nil)
    P.mark("x")
    check("off: a mark writes nothing", FILES["knox_perf.txt"] == nil)
    print("perf off: " .. pass .. " pass, " .. fail .. " fail")
    return
end

check("on: the counter is on", P.on == true)
check("on: events taken over", Events.OnTick.Add ~= ORIGINAL_ADD)
check("on: the file has its header", string.find(FILES["knox_perf.txt"] or "", "=== KnoxPerf on", 1, true) ~= nil)
local own = #LISTS.OnPreUIDraw
check("on: the counter's own frame handler is there, not wrapped as Knox's", own == 1 and P.knoxHandlers == 0, own)

-- Knox's handler wrapped, a foreign one passed through
local calls = 0
local h1 = knox(function(a, b) calls = calls + 1 return a + b, nil, "x" end, 169)
local f1 = foreignFile(function() end)
Events.OnTick.Add(h1)
Events.OnTick.Add(f1)
local list = LISTS.OnTick
check("Knox's handler: the game gets a wrapper", #list == 2 and list[1] ~= h1 and type(list[1]) == "function")
check("foreign handler: the game gets it as it is", list[2] == f1)
check("one Knox handler counted", P.knoxHandlers == 1, P.knoxHandlers)
local r1, r2, r3 = list[1](2, 3)
local n = select("#", list[1](2, 3))
check("results pass unchanged (nil in the middle too)", r1 == 5 and r2 == nil and r3 == "x" and n == 3, tostring(r1) .. " " .. tostring(n))
check("the handler ran", calls == 2, calls)
local rec = P.recs["KnoxMain.lua:169 OnTick"]
check("its record: name, calls, time", rec ~= nil and rec.calls == 2 and rec.us > 0, rec and rec.calls)

-- an error inside passes on as without the counter
local bad = knox(function() error("boom") end, 200)
Events.OnTick.Add(bad)
local ok, err = pcall(LISTS.OnTick[#LISTS.OnTick])
check("an error in a Knox handler passes on", not ok and string.find(tostring(err), "boom", 1, true) ~= nil, err)
Events.OnTick.Remove(bad)

-- the same handler twice (the game keeps both), removed one at a time
local h2 = knox(function() end, 300)
Events.OnTick.Add(h2)
Events.OnTick.Add(h2)
check("the same handler twice: two entries, one wrapper", #list == 4 and list[3] == list[4], #list)
Events.OnTick.Remove(h2)
check("removed once: one left", #list == 3, #list)
Events.OnTick.Remove(h2)
check("removed twice: none left", #list == 2, #list)
Events.OnTick.Remove(h2)
check("removed once more: nothing else goes", #list == 2 and list[1] ~= nil and list[2] == f1, #list)

-- Remove then Add, many times (KnoxSearchSound, KnoxSaveGuard, KnoxMenuScene do so): no pile-up
local w = knox(function() end, 400)
for _ = 1, 500 do
    Events.OnTick.Remove(w)
    Events.OnTick.Add(w)
end
check("Remove + Add x500: the handler is there once", #list == 3, #list)
for _ = 1, 500 do
    Events.OnTick.Add(w)
    Events.OnTick.Remove(w)
end
check("Add + Remove x500: still once", #list == 3, #list)
Events.OnTick.Remove(w)
check("and gone after its Remove", #list == 2, #list)
check("Knox's registrations back to one", P.knoxHandlers == 1, P.knoxHandlers)
local names = 0
for _ in pairs(P.recs) do names = names + 1 end
check("records: one per handler, not per add", names == 4, names)

-- a handler that takes itself off (KnoxSearch markKit, KnoxMenuMusic intoGameTick)
local selfOff
selfOff = knox(function() Events.OnTick.Remove(selfOff) end, 500)
Events.OnTick.Add(selfOff)
fire("OnTick", 1, 1)
check("a handler that removes itself is gone", #list == 2, #list)

-- drawing: wrapped once a game has started - Knox's own functions only, not inherited ones
local base = {render = foreignFile(function() return "base" end)}
KnoxScreen = setmetatable({prerender = knox(function() return "knox" end, 703)}, {__index = base})
ISHotbar = {render = foreignFile(function() return "game" end)}
local before, hotbarBefore = KnoxScreen.prerender, ISHotbar.render
fire("OnGameStart")
fire("OnPreUIDraw")
check("Knox's prerender wrapped", KnoxScreen.prerender ~= before and KnoxScreen.prerender() == "knox")
check("an inherited render not wrapped into Knox's table", rawget(KnoxScreen, "render") == nil)
check("the game's own hotbar render not wrapped", ISHotbar.render == hotbarBefore)
check("wrapped once", P.wrapped == 1, P.wrapped)
fire("OnGameStart")
fire("OnPreUIDraw")
check("a second game start wraps nothing again", P.wrapped == 1, P.wrapped)

-- the 10 s block
FILES["knox_perf.txt"] = ""
list[1](1, 1)
NOW_MS = NOW_MS + 11000
fire("OnPreUIDraw")
local out = FILES["knox_perf.txt"] or ""
check("block: frames line", string.find(out, "\nT\t", 1, true) ~= nil or string.sub(out, 1, 2) == "T\t", out)
check("block: the handler's line", string.find(out, "KnoxMain.lua:169 OnTick", 1, true) ~= nil, out)
check("block: the prerender's line", string.find(out, "KnoxScreen.prerender", 1, true) ~= nil, out)
check("block: sizes line", string.find(out, "C\t", 1, true) ~= nil, out)
check("block: handlers per event", string.find(out, "E\tOnTick=1/3", 1, true) ~= nil, out)
check("block: window counters start again", P.recs["KnoxMain.lua:169 OnTick"].calls == 0)
P.mark("reload 1")
check("a mark is written", string.find(FILES["knox_perf.txt"], "M\t", 1, true) ~= nil)

print("perf on: " .. pass .. " pass, " .. fail .. " fail")
