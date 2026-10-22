-- The main menu's music player (the author's wish, 2026-10-15), played from the
-- radio by the fire: its card (KnoxRadioCard, below). Themes:
--   game  - the game's own menu music (as without the mod; when a mod has
--           silenced it, Knox plays the game's event itself: KnoxGameMenuMusic)
--   mine  - the player's own files in Zomboid/knox_music (KnoxMusic.java); each
--           folder in it is a playlist of its own ("mine:<folder>"), "mine" is all
-- Kept in knox_settings.txt: menu.music (theme), menu.music.vol (0..100, the
-- player's own; times the game's music slider), menu.music.shuffle, menu.radio.
-- While another theme plays, the game's music is muted (bus:/Music) - and given
-- back, at full volume, when a game starts.

require "ISUI/ISPanel"
require "Knox/KnoxTheme"

local T = KnoxTheme

KnoxMenuMusic = KnoxMenuMusic or {}
local MM = KnoxMenuMusic

-- (Knox's own CC0 music and a "camp only" theme were tried and taken out: the
-- author, 2026-10-15 - pause or the volume give the camp alone)
MM.THEMES = {"game", "mine"}

local GAP_S = 3      -- quiet between two tracks

MM.list = {}         -- the tracks of the theme on: {name, title, kind}
MM.at = 0            -- the one playing (index in list)
MM.paused = false
MM.playing = nil     -- what plays now: {kind = "file" | "sound", name, handle}
MM.nextAt = 0

local function now() return getTimestampMs() / 1000 end

-- Where it plays (2026-10-18, the author: the car's radio "with the same things
-- as the main menu's"): "menu" - the camp's radio; "car" - the radio of the car
-- the character sits in (KnoxCarRadio). In the car the theme "game" is the car
-- radio's broadcast (the game's own radio, its window), "mine" the player's
-- music from its speaker; the volume, shuffle, repeat and the radio's sound are
-- the same settings. The car's theme is kept apart (car.music).
MM.ctx = "menu"
local function themeKey() return MM.ctx == "car" and "car.music" or "menu.music" end
local function volKey() return MM.ctx == "car" and "car.music.vol" or "menu.music.vol" end
-- The car's side (KnoxCarRadio fills these in): MM.carAllowed() - a radio set
-- in, with power, switched on; MM.carOn(); MM.carGetVolume() / carSetVolume(v) -
-- the set's own volume; MM.carChannel() / carTune(f); MM.carStations();
-- MM.carBroadcastToggle(); MM.carTitle(); MM.carOpenWindow().
local function car(name, ...)
    local f = MM[name]
    if f then return f(...) end
    return nil
end
local function carBlocked() return MM.ctx == "car" and not car("carAllowed") end
MM.carBlocked = carBlocked
--- In the car, the broadcast chosen: the list is the set's stations.
function MM.stations() return MM.ctx == "car" and MM.theme() == "game" end

-- Settings ---------------------------------------------------------------------

--- The theme ("game", "mine") and, for "mine", the folder or nil. The game's
--- music when nothing (or a theme no longer there) is chosen.
function MM.theme()
    local v = T.settings[themeKey()] or ""
    local base, folder = string.match(v, "^(mine):(.+)$")
    if base then return base, folder end
    if v == "mine" then return "mine", nil end
    return "game", nil
end

function MM.vol()
    -- (the car's broadcast: the set's own knob)
    if MM.stations() and MM.carGetVolume then return MM.carGetVolume() end
    local v = tonumber(T.settings[volKey()] or "") or 80
    return math.max(0, math.min(100, v)) / 100
end

function MM.shuffleOn()
    return T.settings["menu.music.shuffle"] ~= "0"
end

-- Repeat (the author's wish, 2026-10-15): "all" - the list goes round (as it did),
-- "one" - the track plays again and again, "off" - the list plays once and stops.
MM.REPEATS = {"all", "one", "off"}

function MM.repeatMode()
    local v = T.settings["menu.music.repeat"]
    if v == "one" or v == "off" then return v end
    return "all"
end

function MM.cycleRepeat()
    local cur = MM.repeatMode()
    local nextMode = (cur == "all") and "one" or ((cur == "one") and "off" or "all")
    T.settings["menu.music.repeat"] = nextMode
    T.saveSettings()
    MM.ended = false
end

-- The player's own files --------------------------------------------------------

--- {all = {paths}, folders = {{name, paths}}} of Zomboid/knox_music.
function MM.mine()
    local all, byName, folders = {}, {}, {}
    if knoxMusicList then
        for path in string.gmatch(knoxMusicList() or "", "[^\n]+") do
            table.insert(all, path)
            local folder = string.match(path, "^([^/]+)/")
            if folder then
                if not byName[folder] then
                    byName[folder] = {name = folder, paths = {}}
                    table.insert(folders, byName[folder])
                end
                table.insert(byName[folder].paths, path)
            end
        end
    end
    return {all = all, folders = folders}
end

--- Can this theme play here?
function MM.available(id)
    if id == "mine" then
        return knoxMusicList ~= nil and (knoxMusicList() or "") ~= ""
    end
    return true
end

--- A file's name for the plate: "Album/NightRoad.ogg" -> "Night Road".
local function titleOf(name)
    local s = string.gsub(name, "^.*/", "")
    s = string.gsub(s, "%.%w+$", "")
    s = string.gsub(s, "[_]+", " ")
    s = string.gsub(s, "(%l)(%u)", "%1 %2")
    return s
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = ZombRand(i) + 1
        t[i], t[j] = t[j], t[i]
    end
    return t
end

--- Has a mod silenced the game's music? (A soundtrack mod may put the game's
--- MusicCombined at volume 0 - the game's menu music was gone, 2026-10-15.)
function MM.gameSilenced()
    local ok, silent = pcall(function()
        local s = GameSounds.getSound("MusicCombined")
        local clip = s and s:getRandomClip()
        return clip ~= nil and clip:getVolume() <= 0
    end)
    return ok and silent == true
end

function MM.buildList()
    local id, folder = MM.theme()
    local list = {}
    if id == "game" and MM.ctx == "car" then
        -- the car's broadcast: the game's radio plays it; the list is the set's
        -- stations (a click tunes in, back / next step through them)
        for _, st in ipairs(car("carStations") or {}) do
            table.insert(list, {name = tostring(st.freq), title = st.title, kind = "station", freq = st.freq})
        end
    elseif id == "game" and MM.gameSilenced() and GameSounds.isKnownSound("KnoxGameMenuMusic") then
        -- the game's event, played by Knox itself
        list = {{name = "KnoxGameMenuMusic", title = getText("IGUI_KnoxMusic_GameNow"), kind = "sound"}}
    elseif id == "mine" then
        local mine = MM.mine()
        local paths = mine.all
        if folder then
            paths = {}
            for _, f in ipairs(mine.folders) do
                if f.name == folder then paths = f.paths end
            end
        end
        for _, p in ipairs(paths) do table.insert(list, {name = p, title = titleOf(p), kind = "file"}) end
        if MM.shuffleOn() then shuffle(list) end
    end
    MM.list = list
    MM.at = 0
end

-- Volume and the radio -------------------------------------------------------------

-- The radio by the fire (the author's wish, 2026-10-15): the music as if from
-- its speaker - the highs cut (knoxMusicRadio), quieter, a hiss with crackles
-- under it (KnoxRadioStatic), its dial lit in the scene. For the themes Knox
-- plays as streams (own music): the game's music is an FMOD
-- event that can't be filtered from here.
-- (first try 0.16 / 0.6 and the hiss at 0.22: "as if in the next room", the
-- music drowned in the hiss - the author, 2026-10-15)
local RADIO_LOWPASS = 0.5
local RADIO_VOLUME = 0.85

function MM.radioCan()
    local id = MM.theme()
    return knoxMusicRadio ~= nil and id == "mine"
end

function MM.radioOn()
    return T.settings["menu.radio"] == "1" and MM.radioCan()
end

--- Is the music coming from the radio right now (its dial glows)?
function MM.radioPlaying()
    return MM.active and MM.radioOn() and not MM.paused and MM.playing ~= nil
end

--- A stream's volume: the game's music slider, the player's own, the radio.
-- In the car the music is a sound of the world, over the engine and the road:
-- by the game's sound slider (its music is muted there), and louder - at the
-- menu's level it was hardly heard (the author, 2026-10-18; an FMOD channel
-- takes a gain over 1).
local CAR_GAIN = 1.8

--- The car's track's volume by the car (its distance not counted).
function MM.carTrackVolume()
    local v = math.max(0, math.min(1, (getCore():getOptionSoundVolume() or 8) / 10)) * MM.vol() * CAR_GAIN
    if MM.radioOn() then v = v * RADIO_VOLUME end
    return v
end

local function volume()
    if MM.ctx == "car" then
        -- (the driver out, the music going on in the car: by the distance - KnoxCarRadio)
        return MM.carTrackVolume() * (MM.carFar or 1)
    end
    local v = math.max(0, math.min(1, (getCore():getOptionMusicVolume() or 7) / 10)) * MM.vol()
    if MM.radioOn() then v = v * RADIO_VOLUME end
    return v * 0.8
end

function MM.applyVolume()
    if knoxMusicVolume and MM.playing and MM.playing.kind ~= "sound" then knoxMusicVolume(volume()) end
    -- the game's music (its own, or its event played by Knox): the bus; in the
    -- car the broadcast's volume is the radio set's own (MM.setVol)
    if MM.ctx == "car" then return end
    if knoxMusicGameVolume and MM.theme() == "game" then knoxMusicGameVolume(MM.vol()) end
end

function MM.setVol(v)
    v = math.floor(math.max(0, math.min(1, v)) * 100 + 0.5)
    if MM.stations() then
        car("carSetVolume", v / 100)
        return
    end
    if tostring(v) == T.settings[volKey()] then return end
    T.settings[volKey()] = tostring(v)
    MM.applyVolume()
end

-- The hiss is stopped by its name on the UI emitter, not only by its handle: Lua is
-- reloaded in the menu when a new game's or a save's mods differ from the menu's,
-- the new Lua never knew the old handle, and the hiss went on into the game (the
-- author, 2026-10-17, a new character).
local function stopHiss()
    local sm = getSoundManager()
    if MM.static then pcall(function() sm:stopUISound(MM.static) end) end
    MM.static = nil
    pcall(function() sm:getUIEmitter():stopSoundByName("KnoxRadioStatic") end)
end
MM.stopHiss = stopHiss

--- Is a track on: playing, or between two of a list going on (the hiss stays
--- through the gap, not through a stop, a pause or the end - the author,
--- 2026-10-21: it hissed with the track off).
function MM.trackOn()
    if MM.paused then return false end
    if MM.playing ~= nil then return true end
    return (MM.at or 0) > 0 and not MM.ended and #MM.list > 0 and now() <= (MM.nextAt or 0) + 1
end

function MM.applyRadio()
    -- (in the car only while its music may play: no hiss from a radio switched off)
    local on = MM.active and MM.radioOn() and not carBlocked()
    if knoxMusicRadio then knoxMusicRadio(on and RADIO_LOWPASS or 1) end
    local sm = getSoundManager()
    -- (no hiss from a car the driver has left: it would be heard at any distance)
    local hiss = on and MM.trackOn() and not MM.carOutside
    if hiss and not MM.static then
        stopHiss()   -- (one left by a Lua before this one: not two at once)
        MM.static = sm:playUISound("KnoxRadioStatic")
    elseif not hiss and MM.static then
        stopHiss()
    end
    MM.applyVolume()
end

function MM.toggleRadio()
    if not MM.radioCan() then return end
    T.settings["menu.radio"] = (T.settings["menu.radio"] == "1") and "0" or "1"
    T.saveSettings()
    MM.applyRadio()
    -- (its switch heard: a snap, the station tuned in or the speaker going off -
    -- the author, 2026-10-16)
    if knoxMusicRadioSwitch then knoxMusicRadioSwitch(MM.radioOn()) end
end

--- Shuffle on / off: the order is made again, the track playing goes on.
function MM.toggleShuffle()
    T.settings["menu.music.shuffle"] = MM.shuffleOn() and "0" or "1"
    T.saveSettings()
    local cur = MM.list[MM.at]
    MM.buildList()
    if cur then
        for i, tr in ipairs(MM.list) do
            if tr.name == cur.name then MM.at = i end
        end
    end
end

-- Playing ---------------------------------------------------------------------------

function MM.stopTrack()
    local p = MM.playing
    if p then
        if p.kind == "file" and knoxMusicStop then knoxMusicStop() end
        if p.kind == "sound" then
            if p.handle and p.handle ~= 0 then pcall(function() getSoundManager():stopUISound(p.handle) end) end
            pcall(function() getSoundManager():getUIEmitter():stopSoundByName(p.name) end)   -- (see stopHiss)
        end
    end
    MM.playing = nil
end

function MM.play(i)
    MM.stopTrack()
    local n = #MM.list
    if n == 0 then return end
    -- (wrapped by hand: the game's Lua gives a negative remainder for a negative
    -- number - "back" from the first track was index -1, an error)
    while i < 1 do i = i + n end
    while i > n do i = i - n end
    MM.at = i
    MM.ended = false
    local tr = MM.list[i]
    if tr.kind == "station" then
        -- (the car's set tunes in; nothing of Knox's plays)
        car("carTune", tr.freq)
        return
    end
    if tr.kind == "file" then
        if knoxMusicPlay and knoxMusicPlay(tr.name, volume()) then MM.playing = {kind = "file", name = tr.name} end
    else
        -- (a sound of the game or a mod, as they play it; one left playing by a
        -- Lua before this one is stopped first - see stopHiss)
        pcall(function() getSoundManager():getUIEmitter():stopSoundByName(tr.name) end)
        MM.playing = {kind = "sound", name = tr.name, handle = getSoundManager():playUISound(tr.name), since = now()}
    end
    MM.paused = false
    MM.applyRadio()   -- (its volume, and the hiss with it)
end

local function isPlaying()
    local p = MM.playing
    if not p then return false end
    if p.kind == "file" then return knoxMusicPlaying and knoxMusicPlaying() == true end
    -- (a sound takes a moment to start)
    return now() - (p.since or 0) < 1 or getSoundManager():isPlayingUISound(p.name)
end

--- The theme as chosen: the game's music muted or not, the list, the first track.
function MM.apply()
    MM.stopTrack()
    local id = MM.theme()
    -- (in the car the game's music is muted only while a track plays: MM.update)
    if MM.ctx ~= "car" then
        if knoxMusicMuteGame then knoxMusicMuteGame(id ~= "game") end
        if knoxMusicGameVolume then knoxMusicGameVolume(id == "game" and MM.vol() or 1) end
    end
    MM.buildList()
    MM.nextAt = now() + 0.5
    MM.paused = false
    MM.applyRadio()
end

function MM.choose(value)
    local was = MM.theme()
    local cur = MM.playing
    T.settings[themeKey()] = value
    T.saveSettings()
    if was == "mine" and MM.theme() == "mine" and cur and cur.kind == "file" then
        -- one's own folder to another (or to all of one's music): the track playing
        -- goes on, the new folder's list after it (the author, 2026-10-21: switching
        -- folders in the radio's card changed the track)
        MM.buildList()
        MM.at = 0
        for i, tr in ipairs(MM.list) do
            if tr.name == cur.name then MM.at = i end
        end
        MM.ended = false
    else
        MM.apply()
    end
    if MM.ctx == "car" and MM.carChosen then MM.carChosen(MM.theme()) end
end

function MM.next()
    if #MM.list > 0 then MM.play(MM.at + 1) end
end

function MM.prev()
    if #MM.list > 0 then MM.play(MM.at - 1) end
end

function MM.togglePause()
    local id = MM.theme()
    -- the car's broadcast: play / pause is its radio set on / off
    if MM.ctx == "car" and id == "game" then
        if MM.carBroadcastToggle then MM.carBroadcastToggle() end
        return
    end
    MM.paused = not MM.paused
    if id == "game" then
        if knoxMusicMuteGame then knoxMusicMuteGame(MM.paused) end
    elseif MM.playing and MM.playing.kind == "file" then
        if knoxMusicPause then knoxMusicPause(MM.paused) end
    elseif MM.paused then
        MM.stopTrack()
    else
        MM.play(math.max(1, MM.at))
    end
    MM.applyRadio()   -- (no hiss while paused)
end

-- Mods' own menu music (the author, 2026-10-16: The Walking Dead's soundtrack
-- played whatever the radio was set to). A mod that plays a playlist of its own
-- in the menu, through the game's UI emitter, is under the radio too: with the
-- game's music chosen it is that music (Knox doesn't play the game's on top of
-- it) at the radio's volume; with the player's own music, on pause or stopped it
-- is muted (knoxMusicForeign - by what the sounds are, music, not by the mod).
function MM.foreignTick()
    if not knoxMusicForeign then return end
    local gain = 0
    if MM.theme() == "game" and not MM.paused then gain = MM.vol() end
    MM.foreign = knoxMusicForeign(gain)
end

--- Every frame in the menu: the next track when one ends, the volume as the slider.
function MM.update()
    if not MM.active then return end
    -- (the game paused under the car's music: everything waits - KnoxCarRadio)
    if MM.hold then return end
    -- the hiss with the track: on as one starts, off when it stops or ends
    local hissWant = MM.radioOn() and MM.trackOn() and not carBlocked() and not MM.carOutside
    if hissWant ~= (MM.static ~= nil) then MM.applyRadio() end
    if MM.ctx == "car" then
        local t0 = now()
        -- the broadcast: the stations' list kept as the set's presets are, the
        -- one tuned in marked
        if MM.stations() then
            if (MM.stationsAt or 0) <= t0 then
                MM.stationsAt = t0 + 2
                MM.buildList()
            end
            local f = car("carChannel")
            MM.at = 0
            for i, tr in ipairs(MM.list) do
                if tr.freq == f then MM.at = i end
            end
        end
        -- the radio off, no power, the music not chosen: the track stops (and
        -- starts again from where it was when it may play again)
        if carBlocked() or MM.theme() ~= "mine" then
            if MM.playing then
                MM.stopTrack()
                MM.resumeAt = MM.at
            end
            if MM.static then MM.applyRadio() end
            MM.nextAt = t0 + 0.4
        elseif MM.radioOn() and not MM.static and not MM.paused then
            MM.applyRadio()   -- (the hiss back with the power)
        end
        -- the game's own music muted only while a track of ours plays
        -- (said again now and then: the game's music given back as a game starts
        -- may come after the track did)
        -- (and while the car's set is on at all, its broadcast too: the radio is
        -- the music in the car - the author, 2026-10-18)
        local want = (MM.playing ~= nil and not MM.paused) or car("carOn") == true
        -- (out of the car and out of its earshot: the game's music back)
        if MM.carOutside and (MM.carFar or 0) < 0.05 then want = false end
        -- (every frame while it should be muted: the game's own music system may
        -- take its bus back between two of ours)
        if want or want ~= (MM.carMuted == true) then
            MM.carMuted = want
            if knoxMusicMuteGame then knoxMusicMuteGame(want) end
        end
        -- mods' own soundtracks (The Walking Dead's plays on the UI emitter, past
        -- the game's music bus, and sets its track's volume itself each frame -
        -- the author, 2026-10-18: it went on over the car's radio): muted the same
        -- way as in the menu, every frame; given back once the radio is off
        if knoxMusicForeign then
            if want then
                knoxMusicForeign(0)
                MM.carForeign = true
            elseif MM.carForeign then
                knoxMusicForeign(1)
                MM.carForeign = false
            end
        end
        if carBlocked() or MM.theme() ~= "mine" then return end
    else
        MM.foreignTick()
    end
    if MM.paused then return end
    -- the game's music chosen and a mod plays its own: that is the game's music now
    if MM.theme() == "game" and (MM.foreign or 0) > 0 then
        if MM.playing then MM.stopTrack() end
        MM.nextAt = now() + 1
        return
    end
    if knoxMusicTick then knoxMusicTick() end   -- (a duck on its way: KnoxMenuScene's hero walking off)
    -- (a theme with tracks of Knox's to play: own music, the
    -- game's music when a mod has silenced it)
    if #MM.list == 0 then return end
    local t = now()
    -- (the hiss goes on: started again should its loop end)
    if MM.radioOn() and (MM.staticAt or 0) <= t then
        MM.staticAt = t + 1
        if MM.static and not getSoundManager():isPlayingUISound("KnoxRadioStatic") then
            MM.static = nil
            MM.applyRadio()
        end
    end
    if MM.playing and not isPlaying() then
        MM.playing = nil
        MM.nextAt = t + GAP_S
        -- the last track of a list played once: the end
        if MM.repeatMode() == "off" and MM.at >= #MM.list then MM.ended = true end
    end
    if not MM.playing and not MM.ended and t >= MM.nextAt then
        if MM.resumeAt and MM.resumeAt > 0 then
            local i = MM.resumeAt
            MM.resumeAt = nil
            MM.play(i)
        elseif MM.repeatMode() == "one" and MM.at > 0 then MM.play(MM.at) else MM.play(MM.at + 1) end
    end
    -- (the game's music slider may move meanwhile)
    if MM.playing and (MM.volAt or 0) <= t then
        MM.volAt = t + 1
        MM.applyVolume()
    end
end

function MM.start()
    if not T.on("menu") then return end
    MM.active = true
    if knoxMusicDuck then knoxMusicDuck(1, 0) end
    MM.apply()
end

function MM.stop()
    MM.active = false
    MM.stopTrack()
    if knoxMusicForeign then knoxMusicForeign(1) end   -- (mods' music given back as it was)
    MM.applyRadio()   -- (the hiss off, the filter off)
    if knoxMusicMuteGame then knoxMusicMuteGame(false) end
    if knoxMusicGameVolume then knoxMusicGameVolume(1) end
    T.saveSettings()  -- (the volume, set by dragging, is written here)
end

-- The radio's card ---------------------------------------------------------------
-- (the author's idea, 2026-10-15: no plate at the top right - the radio lying by
-- the fire is the player.) The mouse on the radio brings up a card as a hero's
-- passport comes up: the same window, sand frame and fonts, rising into place.
-- It stays while the mouse is on the radio or on the card, and goes a moment
-- after it has left both. Top to bottom:
--   head    - the radio in its square, the track's title, the theme, which of how many
--   seek    - the line (click or drag to wind), the times under it
--   buttons - repeat, shuffle, back, play / pause, next, the radio's sound
--   volume  - the speaker (mute), the line, the per cent
--   tracks  - the list of the theme's tracks (a click plays one; the wheel scrolls)
--   themes  - chips: Game, Mine and the player's folders; the folder
--             button opens Zomboid/knox_music
-- What a control does is said on a small plate under the card while the mouse
-- is on it (the first layout kept a line for it at the foot: empty most of the
-- time - the author, 2026-10-15). The scene says where the radio is on the
-- screen and whether the mouse is on it (KnoxMenuScene: KnoxRadioCard.track).

local CARD_IN_MS, CARD_OUT_MS, CARD_STAY_MS = 170, 120, 350
local LIST_ROWS = 6      -- tracks shown at once; more scroll

-- The icons: smooth white pictures (tools\make_music_icons.ps1 draws them big,
-- anti-aliased), tinted as drawn. (Drawn of 1 px rectangles they were jagged -
-- the author, 2026-10-15.)
local iconTex = {}
local function drawIcon(ui, name, x, y, s, c, a)
    if iconTex[name] == nil then iconTex[name] = getTexture("media/ui/knox_music_" .. name .. ".png") or false end
    local tex = iconTex[name]
    if tex then ui:drawTextureScaledAspect(tex, x, y, s, s, a, c.r, c.g, c.b) end
end

--- One line of text in w px from x; a longer one slides left to show its end,
--- waits, and slides back, smoothly (the author, 2026-10-15: a cut hint hid its
--- end). t: ms since the text came.
local MARQUEE_HOLD, MARQUEE_SPEED = 1300, 50   -- ms at each end, px a second
local function marquee(ui, s, x, y, w, c, font, a, t)
    local over = T.measure(font, s) - w
    if over <= 0 then
        T.text(ui, s, x, y, c, font, a)
        return
    end
    local move = over / MARQUEE_SPEED * 1000
    t = t % (2 * (MARQUEE_HOLD + move))
    local p
    if t < MARQUEE_HOLD then p = 0
    elseif t < MARQUEE_HOLD + move then p = (t - MARQUEE_HOLD) / move
    elseif t < 2 * MARQUEE_HOLD + move then p = 1
    else p = 1 - (t - 2 * MARQUEE_HOLD - move) / move end
    p = (1 - math.cos(math.pi * p)) / 2               -- (eased at both ends)
    ui:setStencilRect(x, y - 2, w, T.fontH(font) + 4)
    T.text(ui, s, x - math.floor(over * p + 0.5), y, c, font, a)
    ui:clearStencilRect()
end
--- "3:07" of ms.
local function clock(ms)
    local s = math.floor((ms or 0) / 1000)
    local m = math.floor(s / 60)
    s = s - m * 60
    return m .. ":" .. (s < 10 and "0" or "") .. s
end

--- Can the track be wound (one of Knox's streams, its length known)?
local function seekable()
    return MM.playing ~= nil and MM.playing.kind ~= "sound" and knoxMusicLength ~= nil and knoxMusicLength() > 0
end

KnoxRadioCard = ISPanel:derive("KnoxRadioCard")
local RC = KnoxRadioCard

function RC:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.k = 0
    o.listTop = 0
    return o
end

--- The themes as chips: {value, label, ok}.
local function chipList()
    local out = {}
    local mine = MM.mine()
    for _, id in ipairs(MM.THEMES) do
        local ok = MM.available(id) or id == "mine"
        -- (in the car the game's theme is the set's broadcast)
        local label = getText("IGUI_KnoxMusic_Chip_" .. ((MM.ctx == "car" and id == "game") and "car" or id))
        table.insert(out, {value = id, label = label, ok = ok, empty = id == "mine" and not MM.available("mine")})
        if id == "mine" then
            for _, f in ipairs(mine.folders) do
                table.insert(out, {value = "mine:" .. f.name, label = f.name, ok = true, folder = true})
            end
        end
    end
    return out
end

--- Lays the card out: every rectangle, on whole pixels, rows of their own height.
function RC:layout()
    T.ensure()
    local pad, cell = T.pad, T.cell
    local half = math.floor(pad / 2)
    local fh, fn, ft = T.fontH(T.fontHeader), T.fontH(T.fontText), T.fontTileH
    local L = {}
    L.frame = 4
    L.w = math.floor(cell * 6.6)
    local f = L.frame
    local inX, inW = f + pad, L.w - (f + pad) * 2      -- the content's left edge and width
    L.inX, L.inW = inX, inW
    local y = f + pad

    -- head
    L.ps = math.floor(cell * 1.25)
    L.head = {inX, y, L.ps, L.ps}
    L.tx = inX + L.ps + pad
    L.headH = L.ps
    y = y + L.ps + pad

    -- seek: the line, the times under it
    L.seekBar = {inX, y + 6, inW, 6}
    L.seekHit = {inX, y, inW, 18}
    L.timesY = y + 18 + 2
    y = L.timesY + ft + pad
    -- buttons, spread over the width
    L.btn = math.floor(cell * 0.7)
    local names = {"loop", "shuffle", "prev", "play", "next", "radio"}
    local gap = (inW - L.btn * #names) / (#names - 1)
    L.buttons = {}
    for i, n in ipairs(names) do
        L.buttons[n] = {math.floor(inX + (i - 1) * (L.btn + gap) + 0.5), y, L.btn, L.btn}
    end
    y = y + L.btn + pad
    -- volume: the speaker as big as the buttons' icons, right under the first
    -- button's; the line from the second button to the per cent (the author,
    -- 2026-10-15: the speaker looked smaller than the rest)
    L.icon = math.floor(L.btn * 0.56)
    local vh = math.max(L.icon, 16)
    local first, second = L.buttons.loop, L.buttons.shuffle
    L.volIcon = {first[1], y, first[3], vh}
    local numW = T.measure(T.fontTile, "100%")
    L.volNum = {inX + inW - numW, y, numW, vh}
    L.vol = {second[1], y, inX + inW - numW - pad - second[1], vh}
    y = y + vh + pad

    -- tracks
    L.rowH = fn + half + 2
    local n = #MM.list
    L.listRows = math.min(LIST_ROWS, n)
    if n > 0 then
        L.list = {inX, y, inW, L.listRows * L.rowH}
        y = y + L.listRows * L.rowH + pad
    else
        L.list = nil
    end

    -- themes: chips as tall as the buttons above, on their columns (two or more,
    -- as the caption needs); the folder button as one of those buttons, under the
    -- radio's. (Smaller chips and a smaller folder button with thin frames looked
    -- like another card's - the author, 2026-10-15.)
    L.chips = {}
    local cols = {}
    for i, n in ipairs(names) do cols[i] = L.buttons[n][1] end
    local nc = #names
    local function spanW(c1, k) return cols[c1 + k - 1] + L.btn - cols[c1] end
    local col, cy, last = 1, y, nc - 1      -- (the first row leaves the last column to the folder)
    for _, c in ipairs(chipList()) do
        local need = T.measure(T.fontTile, T.upper(c.label)) + pad * 2
        local k = 2
        while k < nc and spanW(1, k) < need do k = k + 1 end
        if col > 1 and col + k - 1 > last then
            col, cy, last = 1, cy + L.btn + pad, nc
        end
        k = math.min(k, last - col + 1)
        table.insert(L.chips, {cols[col], cy, spanW(col, k), L.btn, c = c})
        col = col + k
    end
    L.folder = {cols[nc], y, L.btn, L.btn}
    y = cy + L.btn + pad
    L.h = y + f
    self.L = L
    return L
end

--- Show for the radio at screen rect r (x, y, w, h); `over`: the mouse is on it.
function RC.track(r, over, sceneW)
    local card = RC.instance
    if not card then
        card = RC:new()
        card:initialise()
        card:instantiate()
        card:addToUIManager()
        card:setAlwaysOnTop(true)
        card:setVisible(false)
        RC.instance = card
    end
    card.radioRect = r
    card.sceneW = sceneW
    local now = getTimestampMs()
    local wanted = over or (card:getIsVisible() and (card:isMouseOver() or card.drag ~= nil))
    if wanted then
        card.lastWanted = now
        if not card.shownAt then card.shownAt, card.goneAt = now, nil end
        if not card:getIsVisible() then
            card:setVisible(true)
            card:bringToTop()
        end
    elseif card.shownAt and now - (card.lastWanted or 0) > CARD_STAY_MS then
        card.shownAt = nil
        card.goneAt, card.goneK = now, card.k
    end
end

--- Off at once (the menu's screens, a hero leaving, the scene gone).
function RC.hide()
    local card = RC.instance
    if not card then return end
    card.shownAt, card.goneAt, card.drag = nil, nil, nil
    card:setVisible(false)
end

function RC.destroy()
    local card = RC.instance
    if card then card:removeFromUIManager() end
    RC.instance = nil
end

function RC:place()
    local L = self:layout()
    local r = self.radioRect
    if not r then return end
    local pad = T.pad
    local sw = self.sceneW or getCore():getScreenWidth()
    local x = math.floor(r[1] + r[3] / 2 - L.w / 2)
    x = math.max(pad, math.min(sw - L.w - pad, x))
    local y = math.floor(r[2] - L.h - pad)
    if y < pad then y = math.floor(r[2] + r[4] + pad) end
    self:setX(x)
    self:setWidth(L.w)
    self:setHeight(L.h)
    self:setY(y + math.floor(math.floor(T.cell * 0.28) * (1 - self.k) + 0.5))
end

--- Text from x, in the middle of a row's height by its pixels (by the font's
--- line height capitals sit too high: the captions looked off - the author,
--- 2026-10-15; the same as Knox's bars and buttons, T.inkLeft).
local function textMid(ui, s, x, y, h, c, font, a)
    T.inkLeft(ui, s, x, y, h, c, font, a)
end

function RC:prerender()
    -- coming in, going out
    local now = getTimestampMs()
    if self.shownAt then
        local t = math.max(0, math.min(1, T.anim((now - self.shownAt) / CARD_IN_MS)))
        self.k = 1 - (1 - t) * (1 - t)
    elseif self.goneAt then
        local t = math.min(1, T.anim((now - self.goneAt) / CARD_OUT_MS))
        self.k = (self.goneK or 1) * (1 - t)
        if t >= 1 then
            self.goneAt = nil
            self:setVisible(false)
            return
        end
    end
    self:place()
    local L = self.L
    local a = self.k
    local w, h, pad, f = L.w, L.h, T.pad, L.frame
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local id, folder = MM.theme()
    local tip = nil

    -- the window and its sand frame, as a hero's card
    T.rect(self, 0, 0, w, h, T.color.window, 0.96 * a)
    T.rect(self, 0, 0, w, f, T.color.accent, a)
    T.rect(self, 0, h - f, w, f, T.color.accent, a)
    T.rect(self, 0, f, f, h - f * 2, T.color.accent, a)
    T.rect(self, w - f, f, f, h - f * 2, T.color.accent, a)

    -- head: the radio in its square (lit while it plays); the title, the theme,
    -- which of how many - the lines together in the middle of the square's height
    local hr = L.head
    local inCar = MM.ctx == "car"
    -- (in the car the square is the set itself: a click opens its window)
    local hotHead = inCar and over and T.inRect(mx, my, hr)
    T.rect(self, hr[1], hr[2], hr[3], hr[4], T.color.cell, a)
    T.tileFrame(self, hr[1], hr[2], hr[3], hr[4], hotHead and T.color.accent or T.color.tileFrame, a)
    local playing = MM.playing ~= nil and not MM.paused
    if MM.stations() then playing = car("carOn") == true end
    local is = math.floor(hr[3] * 0.62)
    drawIcon(self, "radio", hr[1] + math.floor((hr[3] - is) / 2), hr[2] + math.floor((hr[4] - is) / 2), is,
        (playing or hotHead) and T.color.accent or T.color.dim, a)
    if hotHead then tip = getText("IGUI_KnoxMusic_CarWindow") end
    local tr = MM.playing and MM.list[MM.at]
    -- (the car's set says first: not there, off, a station, a disc)
    local title = inCar and car("carTitle", id) or nil
    if title then
    elseif MM.paused then title = getText("IGUI_KnoxMusic_Paused")
    elseif tr then title = tr.title
    elseif MM.ended then title = getText("IGUI_KnoxMusic_Ended")
    elseif id == "game" then title = getText("IGUI_KnoxMusic_GameNow")
    elseif #MM.list == 0 then title = getText("IGUI_KnoxMusic_Empty")
    else title = "..." end
    local tw = L.inX + L.inW - L.tx
    local fh = T.fontH(T.fontHeader)
    local lines = T.wrap(title, T.fontHeader, tw)
    local nl = math.min(2, #lines)
    local themeName = getText("IGUI_KnoxMusic_" .. ((inCar and id == "game") and "car" or id)) .. (folder and (": " .. folder) or "")
    if #MM.list > 1 and MM.at > 0 then themeName = themeName .. "   " .. MM.at .. " / " .. #MM.list end
    local blockH = nl * fh + 2 + T.fontTileH
    local ty = hr[2] + math.floor((hr[4] - blockH) / 2)
    for i = 1, nl do
        T.text(self, lines[i], L.tx, ty, T.color.bright, T.fontHeader, a)
        ty = ty + fh
    end
    -- (the theme's line is drawn at the end: while the mouse is on a control it
    -- says what that does instead)
    local themeY = ty + 2

    -- seek: the line with its knob, the times under its ends
    local sb = L.seekBar
    local canSeek = seekable()
    local pos, len = 0, 0
    if canSeek then
        len = knoxMusicLength()
        pos = (self.drag == "seek" and self.seekTo) or knoxMusicPosition()
    end
    local frac = len > 0 and math.max(0, math.min(1, pos / len)) or 0
    local hotSeek = canSeek and over and (T.inRect(mx, my, L.seekHit) or self.drag == "seek")
    T.rect(self, sb[1], sb[2], sb[3], sb[4], T.color.cell, a)
    if canSeek then
        T.rect(self, sb[1], sb[2], math.floor(sb[3] * frac), sb[4], T.color.accent, (hotSeek and 1 or 0.85) * a)
        local kx = sb[1] + math.floor(sb[3] * frac)
        T.rect(self, math.max(sb[1], math.min(sb[1] + sb[3] - 6, kx - 3)), sb[2] - 4, 6, sb[4] + 8,
            hotSeek and T.color.bright or T.color.accent, a)
        if hotSeek then tip = getText("IGUI_KnoxMusic_Seek") end
    end
    local left = canSeek and clock(pos) or "-:--"
    local right = canSeek and clock(len) or "-:--"
    textMid(self, left, sb[1], L.timesY, T.fontTileH, T.color.dim, T.fontTile, a)
    textMid(self, right, sb[1] + sb[3] - T.measure(T.fontTile, right), L.timesY, T.fontTileH, T.color.dim, T.fontTile, a)

    -- the buttons
    local stations = MM.stations()
    local carOn = car("carOn") == true
    for name, b in pairs(L.buttons) do
        local hot = over and T.inRect(mx, my, b)
        local off, active, icon = false, false, name
        if name == "loop" then
            off = #MM.list == 0 or stations
            active = MM.repeatMode() ~= "off" and not off
            icon = MM.repeatMode() == "one" and "repeat_one" or "repeat"
            if hot then tip = getText("IGUI_KnoxMusic_Repeat_" .. MM.repeatMode()) end
        elseif name == "shuffle" then
            off = id ~= "mine"
            active = MM.shuffleOn() and not off
            if hot then tip = getText(off and "IGUI_KnoxMusic_ShuffleCant" or (active and "IGUI_KnoxMusic_ShuffleOff" or "IGUI_KnoxMusic_ShuffleOn")) end
        elseif name == "radio" then
            off = not MM.radioCan()
            active = MM.radioOn()
            if hot then
                tip = getText((off and "IGUI_KnoxMusic_RadioCant" or (active and "IGUI_KnoxMusic_RadioOff" or "IGUI_KnoxMusic_RadioOn"))
                    .. (inCar and "_car" or ""))
            end
        elseif name == "play" then
            if stations then
                -- the car's broadcast: the set on / off
                off = car("carHas") ~= true
                icon = carOn and "pause" or "play"
                if hot and not off then tip = getText(carOn and "IGUI_KnoxMusic_CarOff" or "IGUI_KnoxMusic_CarOn") end
            elseif inCar and carBlocked() then
                -- own music with the set off: the play button switches it on
                off = car("carHas") ~= true
                icon = "play"
                if hot and not off then tip = getText("IGUI_KnoxMusic_CarOn") end
            else
                if id == "game" then icon = MM.paused and "play" or "pause"
                else icon = (MM.paused or not MM.playing) and "play" or "pause" end
                if hot and not off then tip = getText(icon == "play" and "IGUI_KnoxMusic_Play" or "IGUI_KnoxMusic_Pause") end
            end
        elseif stations then
            -- back / next: the set's stations
            off = #MM.list == 0 or not carOn
            if hot and not off then tip = getText(name == "next" and "IGUI_KnoxMusic_NextStation" or "IGUI_KnoxMusic_PrevStation") end
        else
            off = id == "game" or #MM.list == 0
            if hot and not off then tip = getText(name == "next" and "IGUI_KnoxMusic_Next" or "IGUI_KnoxMusic_Prev") end
        end
        T.rect(self, b[1], b[2], b[3], b[4], active and T.color.accent or T.color.cell, a)
        T.tileFrame(self, b[1], b[2], b[3], b[4], (hot and not off) and T.color.accent or T.color.tileFrame, a)
        local c = off and T.color.tileEdge or (active and T.color.ink or (hot and T.color.accent or T.color.text))
        local s = L.icon
        drawIcon(self, icon, b[1] + math.floor((b[3] - s) / 2), b[2] + math.floor((b[4] - s) / 2), s, c, a)
    end

    -- the volume
    local v = MM.vol()
    local waves = v <= 0 and 0 or (v < 0.34 and 1 or (v < 0.67 and 2 or 3))
    local vi = L.volIcon
    local hotIcon = over and T.inRect(mx, my, vi)
    -- (as big as the buttons' icons, in the middle of the first button's column)
    drawIcon(self, "vol" .. waves, vi[1] + math.floor((vi[3] - L.icon) / 2), vi[2] + math.floor((vi[4] - L.icon) / 2), L.icon,
        hotIcon and T.color.accent or T.color.text, a)
    if hotIcon then tip = getText(v > 0 and "IGUI_KnoxMusic_Mute" or "IGUI_KnoxMusic_Unmute") end
    local vr = L.vol
    local hotVol = over and (T.inRect(mx, my, vr) or self.drag == "vol")
    local vy = vr[2] + math.floor((vr[4] - 6) / 2)
    T.rect(self, vr[1], vy, vr[3], 6, T.color.cell, a)
    T.rect(self, vr[1], vy, math.floor(vr[3] * v), 6, T.color.accent, (hotVol and 1 or 0.85) * a)
    local kx = vr[1] + math.floor(vr[3] * v)
    T.rect(self, math.max(vr[1], math.min(vr[1] + vr[3] - 6, kx - 3)), vy - 4, 6, 14, hotVol and T.color.bright or T.color.accent, a)
    local num = math.floor(v * 100 + 0.5) .. "%"
    textMid(self, num, L.volNum[1] + L.volNum[3] - T.measure(T.fontTile, num), vr[2], vr[4], T.color.dim, T.fontTile, a)
    if hotVol then tip = getText("IGUI_KnoxMusic_Volume") end

    -- the tracks
    if L.list then
        local lr = L.list
        local n = #MM.list
        -- the one playing kept in view (unless the list was just scrolled by hand)
        if MM.at > 0 and now - (self.scrolledAt or 0) > 4000 then
            if MM.at - 1 < self.listTop then self.listTop = MM.at - 1 end
            if MM.at > self.listTop + L.listRows then self.listTop = MM.at - L.listRows end
        end
        self.listTop = math.max(0, math.min(n - L.listRows, self.listTop))
        -- (the number and the title from one left edge, the same room between them)
        local half = math.floor(pad / 2)
        local numW = T.measure(T.fontTile, "00") + half
        for row = 1, L.listRows do
            local i = self.listTop + row
            local trk = MM.list[i]
            if trk then
                local ry = lr[2] + (row - 1) * L.rowH
                local rr = {lr[1], ry, lr[3] - (n > L.listRows and 8 or 0), L.rowH - 2}
                local cur = i == MM.at and (MM.playing ~= nil or (stations and carOn))
                -- (lit under the mouse with the car's set off too: a click switches it
                -- on and tunes in - the author, 2026-10-18: rows didn't light up)
                local hot = over and T.inRect(mx, my, rr)
                T.rect(self, rr[1], rr[2], rr[3], rr[4], (cur or hot) and T.color.header or T.color.cell, a)
                if cur then T.rect(self, rr[1], rr[2], 3, rr[4], T.color.accent, a) end
                if hot then T.border(self, rr[1], rr[2], rr[3], rr[4], T.color.accent, a) end
                local nm = (i < 10 and "0" or "") .. i
                local x0 = rr[1] + 3 + half
                textMid(self, nm, x0, rr[2], rr[4], cur and T.color.accent or T.color.dim, T.fontTile, a)
                textMid(self, T.fit(trk.title, T.fontText, rr[1] + rr[3] - half - (x0 + numW)), x0 + numW, rr[2], rr[4],
                    cur and T.color.bright or (hot and T.color.accent or T.color.text), T.fontText, a)
                if hot then tip = getText(stations and "IGUI_KnoxMusic_TuneThis" or "IGUI_KnoxMusic_PlayThis") end
            end
        end
        -- a thin scroll bar when there are more than fit
        if n > L.listRows then
            local bx = lr[1] + lr[3] - 4
            T.rect(self, bx, lr[2], 4, lr[4], T.color.cell, a)
            local bh = math.max(12, math.floor(lr[4] * L.listRows / n))
            local by = lr[2] + math.floor((lr[4] - bh) * self.listTop / math.max(1, n - L.listRows))
            T.rect(self, bx, by, 4, bh, T.color.tileFrame, a)
        end
    end

    -- the themes and the folder button
    local current = folder and ("mine:" .. folder) or id
    for _, cr in ipairs(L.chips) do
        local c = cr.c
        local on = c.value == current
        local hot = over and T.inRect(mx, my, cr)
        -- (framed as the buttons above)
        T.rect(self, cr[1], cr[2], cr[3], cr[4], on and T.color.accent or T.color.cell, a)
        T.tileFrame(self, cr[1], cr[2], cr[3], cr[4], (on or hot) and T.color.accent or T.color.tileFrame, a)
        local col = on and T.color.ink or (c.ok and (hot and T.color.accent or (c.folder and T.color.dim or T.color.text)) or T.color.tileEdge)
        -- (in the middle of the chip by its pixels, both ways)
        T.inkCentre(self, T.fit(T.upper(c.label), T.fontTile, cr[3] - pad * 2), cr[1], cr[2], cr[3], cr[4], col.r, col.g, col.b, a, T.fontTile)
        if hot then
            if c.empty then tip = getText("IGUI_KnoxMusic_Need_mine")
            else
                local key = c.folder and "mine" or c.value
                if inCar and key == "game" then key = "car" end
                tip = getText("IGUI_KnoxMusic_" .. key) .. (c.folder and (": " .. c.label) or "")
            end
        end
    end
    local fb = L.folder
    local hotFolder = over and T.inRect(mx, my, fb)
    T.rect(self, fb[1], fb[2], fb[3], fb[4], T.color.cell, a)
    T.tileFrame(self, fb[1], fb[2], fb[3], fb[4], hotFolder and T.color.accent or T.color.tileFrame, a)
    drawIcon(self, "folder", fb[1] + math.floor((fb[3] - L.icon) / 2), fb[2] + math.floor((fb[4] - L.icon) / 2), L.icon,
        hotFolder and T.color.accent or T.color.text, a)
    if hotFolder then tip = getText("IGUI_KnoxMusic_OpenFolder") end

    -- the line under the title: the theme, or what the thing under the mouse
    -- does (the folder's place after a click on the folder button, for a while).
    -- A plate under the card was tried: its text never looked level - the author,
    -- 2026-10-15. One line; a longer one slides to its end and back (marquee).
    if self.hintAt and now - self.hintAt > 9000 then self.hint, self.hintAt = nil, nil end
    tip = tip or self.hint
    local line = (tip and tip ~= "") and tip or themeName
    if line ~= self.lineText then self.lineText, self.lineSince = line, now end
    marquee(self, line, L.tx, themeY, tw, T.color.accent, T.fontTile, a, now - self.lineSince)
end

function RC:seekAt(x)
    local sb = self.L.seekBar
    local len = knoxMusicLength and knoxMusicLength() or 0
    self.seekTo = math.max(0, math.min(1, (x - sb[1]) / math.max(1, sb[3]))) * len
end

function RC:volAt(x)
    local vr = self.L.vol
    MM.setVol((x - vr[1]) / math.max(1, vr[3]))
end

function RC.openFolder(self)
    -- (opened, the window is in front of the player: no path to read; not opened,
    -- the path)
    if knoxMusicOpenFolder and knoxMusicOpenFolder() then
        self.hint = getText("IGUI_KnoxMusic_Folder")
    else
        self.hint = getText("IGUI_KnoxMusic_FolderAt", knoxMusicFolder and knoxMusicFolder() or "Zomboid/knox_music")
    end
    self.hintAt = getTimestampMs()
end

function RC:onMouseDown(x, y)
    local L = self.L
    if not L or self.k < 0.5 then return true end
    local id = MM.theme()
    -- (the radio's own push buttons, a different click each time - the author,
    -- 2026-10-16; the game's UI click where the Java part lacks them)
    local click = function()
        if knoxMusicRadioButton then knoxMusicRadioButton() else getSoundManager():playUISound("UIActivateButton") end
    end
    self.hint = nil
    -- the car's set: its square opens its window (as a click on the radio's lamp)
    if MM.ctx == "car" and T.inRect(x, y, L.head) then
        click()
        car("carOpenWindow")
        return true
    end
    if seekable() and T.inRect(x, y, L.seekHit) then
        self.drag = "seek"
        self:seekAt(x)
        return true
    end
    if T.inRect(x, y, L.volIcon) then
        if MM.vol() > 0 then self.volBefore = MM.vol() MM.setVol(0) else MM.setVol(self.volBefore or 0.8) end
        T.saveSettings()
        click()
        return true
    end
    if T.inRect(x, y, L.vol) then
        self.drag = "vol"
        self:volAt(x)
        return true
    end
    local b = L.buttons
    local stations = MM.stations()
    local carOn = car("carOn") == true
    -- (stepping is for tracks, or for the stations of a set switched on)
    local canStep = (id ~= "game") or (stations and carOn)
    if T.inRect(x, y, b.loop) then if #MM.list > 0 and not stations then MM.cycleRepeat() click() end return true end
    if T.inRect(x, y, b.shuffle) then if id == "mine" then MM.toggleShuffle() click() end return true end
    if T.inRect(x, y, b.radio) then if MM.radioCan() then MM.toggleRadio() if not knoxMusicRadioSwitch then click() end end return true end
    if T.inRect(x, y, b.play) then
        if MM.ctx == "car" and (stations or carBlocked()) then
            -- the set on / off (own music starts with it)
            if car("carHas") then car("carBroadcastToggle") end
        elseif not MM.playing and not MM.paused and #MM.list > 0 then MM.play(math.max(1, MM.at)) else MM.togglePause() end
        click()
        return true
    end
    if T.inRect(x, y, b.next) then if canStep then MM.next() click() end return true end
    if T.inRect(x, y, b.prev) then if canStep then MM.prev() click() end return true end
    -- a track of the list
    if L.list and T.inRect(x, y, L.list) then
        local i = self.listTop + math.floor((y - L.list[2]) / L.rowH) + 1
        if MM.list[i] and stations and not carOn and car("carHas") then
            -- the car's set off: on, and tuned to the station clicked
            car("carBroadcastToggle")
            MM.play(i)
            click()
        elseif MM.list[i] and canStep then
            MM.play(i)
            click()
        end
        return true
    end
    if T.inRect(x, y, L.folder) then
        click()
        RC.openFolder(self)
        return true
    end
    for _, cr in ipairs(L.chips) do
        if T.inRect(x, y, cr) then
            click()
            local c = cr.c
            if c.empty then
                RC.openFolder(self)
            elseif c.ok then
                MM.choose(c.value)
                self.listTop = 0
            end
            return true
        end
    end
    return true
end

local function dragTo(self)
    if self.drag == "seek" then self:seekAt(self:getMouseX())
    elseif self.drag == "vol" then self:volAt(self:getMouseX()) end
end

local function dragEnd(self)
    if self.drag == "seek" and self.seekTo and knoxMusicSeek then knoxMusicSeek(self.seekTo) end
    if self.drag == "vol" then T.saveSettings() end
    self.drag, self.seekTo = nil, nil
end

function RC:onMouseMove(dx, dy) dragTo(self) return true end
function RC:onMouseMoveOutside(dx, dy) dragTo(self) return true end
function RC:onMouseUp(x, y) dragEnd(self) return true end
function RC:onMouseUpOutside(x, y) dragEnd(self) return true end
function RC:onRightMouseDown(x, y) return true end
function RC:onRightMouseUp(x, y) return true end

--- The wheel: over the list it scrolls the list, elsewhere it is the volume.
function RC:onMouseWheel(del)
    local L = self.L
    if L and L.list and T.inRect(self:getMouseX(), self:getMouseY(), L.list) then
        self.listTop = math.max(0, math.min(#MM.list - L.listRows, self.listTop + (del > 0 and 1 or -1)))
        self.scrolledAt = getTimestampMs()
        return true
    end
    MM.setVol(MM.vol() - del * 0.05)
    T.saveSettings()
    return true
end

-- In the menu: the player runs while the camp is up (the scene shows the card).
local function look()
    if not T.active then return end
    MM.update()
    local main = MainScreen.instance
    if not main or main.inGame or not main.javaObject then return end
    if not T.on("menu") then return end
    if not MM.active then MM.start() end
    -- (the menu's own screens over the camp, or no camp: no card)
    local panel = main.bottomPanel
    if (panel ~= nil and not panel:getIsVisible()) or not (KnoxMenuScene and KnoxMenuScene.instance) then RC.hide() end
end

Events.OnPreUIDraw.Add(look)

-- Into a game (the author, 2026-10-15). The loading screen: the camp is gone, so
-- is the radio's hiss; the track goes on (Lua sleeps there), over "Click to
-- start" too, and fades after the click, in the game; the game's music, muted under it, comes
-- back only once it is gone - never the two together - and comes in softly
-- (it burst in at full: the author, 2026-10-15).
Events.OnPreMapLoad.Add(stopHiss)

local GAME_MUSIC_IN_MS = 6000
local gameInAt = nil
-- (ticks while the game is paused too: it may start paused)
local tickEvent = Events.OnTickEvenPaused or Events.OnTick

local function intoGameTick()
    -- our track's fade first
    if knoxMusicFadeStep and knoxMusicFadeStep() then return end
    if not gameInAt then
        gameInAt = getTimestampMs()
        if knoxMusicGameVolume then knoxMusicGameVolume(0) end
        if knoxMusicMuteGame then knoxMusicMuteGame(false) end
    end
    local p = (getTimestampMs() - gameInAt) / GAME_MUSIC_IN_MS
    if p >= 1 then
        if knoxMusicGameVolume then knoxMusicGameVolume(1) end
        tickEvent.Remove(intoGameTick)
        gameInAt = nil
        return
    end
    if knoxMusicGameVolume then knoxMusicGameVolume(p * p) end   -- (eased in)
end

Events.OnGameStart.Add(function()
    -- was the game's music muted under the menu's (a theme of Knox's, or paused)?
    local muted = MM.active and (MM.theme() ~= "game" or MM.paused)
    local p = MM.playing
    -- A track of the Java part's still playing is faded whoever started it: a
    -- save with other mods resets the Lua on the way in, and this Lua then had
    -- no track of its own to fade - the menu's music played on in the game for
    -- good (the author and the author's friend, 2026-10-20).
    local fading = (p == nil or p.kind ~= "sound") and knoxMusicFadeOut ~= nil and knoxMusicPlaying ~= nil
        and knoxMusicPlaying() and knoxMusicFadeOut(5000)   -- (after the click: slow, into the game - the author, 2026-10-16)
    if fading then MM.playing = nil end   -- (left to the fade: not cut by MM.stop)
    MM.stop()
    stopHiss()   -- (whatever Lua started it; the game's menu music played by Knox too)
    pcall(function() getSoundManager():getUIEmitter():stopSoundByName("KnoxGameMenuMusic") end)
    if (muted or fading) and knoxMusicMuteGame and knoxMusicGameVolume then
        knoxMusicMuteGame(true)
        gameInAt = nil
        tickEvent.Add(intoGameTick)
    end
    RC.destroy()
end)

return KnoxMenuMusic
