-- The ready lists' Lua side (KnoxTheme T.listDraw / T.listEnd, the inventory's FPS
-- stage 1, 2026-10-28) on the game's Lua with tools/settings/stubs.lua and a made-up
-- Java part: a part is written the first time and when its key, its window or the
-- theme changes; played back otherwise; drawn by Lua alone with the lists switched
-- off, the settings window open or an older jar; a list Java can't play back three
-- times running is given up, and one that plays back right again counts afresh.
local T = KnoxTheme
local pass, fail = 0, 0
local function check(name, ok, info)
    if ok then pass = pass + 1 else fail = fail + 1 print("FAIL " .. name .. (info and (": " .. tostring(info)) or "")) end
end

-- the Java part: what was begun, ended, played; what a playing back answers
local J = {begun = 0, ended = 0, played = 0, answer = 2, okEnd = true}
local function java()
    knoxListBegin = function(jo, id) J.begun = J.begun + 1 J.id, J.jo = id, jo end
    knoxListEnd = function() J.ended = J.ended + 1 return J.okEnd end
    knoxListDraw = function(jo, id) J.played = J.played + 1 J.playedJo = jo return J.answer end
end
java()
local function reset() J.begun, J.ended, J.played = 0, 0, 0 end

local ui1 = {javaObject = {name = "one"}}
local ui2 = {javaObject = {name = "two"}}

-- one frame of a part: true when it came from the list
local function frame(ui, L, ...)
    if T.listDraw(ui, L, ...) then return true end
    T.listEnd(L)
    return false
end

-- written, then played back while the key stays
do
    local L = T.newList()
    reset()
    check("first frame drawn by Lua", frame(ui1, L, 1, "a") == false)
    check("first frame written", J.begun == 1 and J.ended == 1 and J.id == L.id and J.jo == ui1.javaObject)
    check("written list ok", L.ok == true)
    check("second frame played", frame(ui1, L, 1, "a") == true and J.played == 1 and J.begun == 1)
    check("played into the right window", J.playedJo == ui1.javaObject)
    check("third frame played", frame(ui1, L, 1, "a") == true and J.played == 2)
    reset()
    check("a key changes: written anew", frame(ui1, L, 2, "a") == false and J.begun == 1 and J.played == 0)
    check("then played", frame(ui1, L, 2, "a") == true)
    reset()
    check("the fifth key counts", frame(ui1, L, 2, "a", nil, nil, true) == false and J.begun == 1)
    check("nil and false differ", frame(ui1, L, 2, "a", nil, nil, false) == false and J.begun == 2)
    -- (up to eight: an equipment slot's)
    local item = {}
    frame(ui1, L, 2, "a", nil, nil, false, 1, 2, item)
    reset()
    check("all eight: played", frame(ui1, L, 2, "a", nil, nil, false, 1, 2, item) == true and J.begun == 0)
    check("the eighth counts", frame(ui1, L, 2, "a", nil, nil, false, 1, 2, {}) == false and J.begun == 1)
    check("the sixth counts", frame(ui1, L, 2, "a", nil, nil, false, 9, 2, item) == false and J.begun == 2)
end

-- another window (a screen opened anew): written anew, no failure counted
do
    local L = T.newList()
    frame(ui1, L, 1)
    reset()
    check("new window: written", frame(ui2, L, 1) == false and J.begun == 1 and J.played == 0)
    check("new window: no failure", L.fails == 0)
    check("new window: played after", frame(ui2, L, 1) == true and J.playedJo == ui2.javaObject)
end

-- the theme refreshed (sizes, fonts, colours): written anew
do
    local L = T.newList()
    frame(ui1, L, 1)
    T.listEpoch = T.listEpoch + 1
    reset()
    check("new epoch: written", frame(ui1, L, 1) == false and J.begun == 1)
    T.applySkin()
    reset()
    check("new skin: written", frame(ui1, L, 1) == false and J.begun == 1)
    check("after the skin: played", frame(ui1, L, 1) == true)
end

-- Java could not write it (a draw it doesn't know): not played, written again next frame
do
    local L = T.newList()
    J.okEnd = false
    reset()
    frame(ui1, L, 1)
    check("not ok when Java says no", L.ok == false)
    check("written again next frame", frame(ui1, L, 1) == false and J.begun == 2 and J.played == 0)
    J.okEnd = true
    frame(ui1, L, 1)
    check("ok once Java can", frame(ui1, L, 1) == true)
end

-- played back wrong (Java answers 0): written again; three times running - given up
do
    local L = T.newList()
    frame(ui1, L, 1)
    J.answer = 0
    reset()
    check("bad playing back: drawn by Lua", frame(ui1, L, 1) == false and J.played == 1 and J.begun == 1)
    check("one failure", L.fails == 1)
    frame(ui1, L, 1)
    check("two failures", L.fails == 2 and not L.dead)
    -- (a good check in between counts afresh)
    J.answer = 2
    check("good again: played", frame(ui1, L, 1) == true)
    check("failures forgotten", L.fails == 0)
    J.answer = 0
    frame(ui1, L, 1)
    frame(ui1, L, 1)
    frame(ui1, L, 1)
    check("three running: dead", L.dead == true)
    J.answer = 2
    reset()
    check("dead: Lua draws, nothing written or played", frame(ui1, L, 1) == false and J.begun == 0 and J.played == 0 and J.ended == 0)
    -- (a plain 1 - drawn, not checked now - neither counts nor forgives)
    local M = T.newList()
    frame(ui1, M, 1)
    J.answer = 0
    frame(ui1, M, 1)
    J.answer = 1
    check("1: played", frame(ui1, M, 1) == true and M.fails == 1)
    J.answer = 2
end

-- switched off for the measure, the settings window open, an older jar: Lua alone
do
    local L = T.newList()
    frame(ui1, L, 1)
    T.listsOff = true
    reset()
    check("off: Lua draws", frame(ui1, L, 1) == false and J.begun == 0 and J.played == 0 and J.ended == 0)
    T.listsOff = nil
    reset()
    check("on again: written first", frame(ui1, L, 1) == false and J.begun == 1)
    check("on again: then played", frame(ui1, L, 1) == true)
    KnoxSettings = {instance = {}}
    reset()
    check("settings open: Lua draws", frame(ui1, L, 1) == false and J.begun == 0 and J.played == 0)
    KnoxSettings = nil
    reset()
    check("settings closed: written anew", frame(ui1, L, 1) == false and J.begun == 1)
    local draw = knoxListDraw
    knoxListDraw = nil
    reset()
    check("older jar: Lua draws", frame(ui1, L, 1) == false and J.begun == 0)
    knoxListDraw = draw
end

-- an end with no beginning does nothing; the lists are numbered apart
do
    local L = T.newList()
    reset()
    T.listEnd(L)
    check("end alone: nothing", J.ended == 0)
    local M = T.newList()
    check("ids apart", L.id ~= M.id)
end

print("lists: " .. pass .. " pass, " .. fail .. " fail")
