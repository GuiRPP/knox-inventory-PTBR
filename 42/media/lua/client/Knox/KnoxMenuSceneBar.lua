-- The main menu's winter scene (the author, 2026-10-31): a bar in a blizzard, the last
-- ones leaving (the mockup's variant B, .claude/mockups/bar_final.html). No light in the
-- room but the storm's, cold, through the three openings in the back wall - a boarded
-- window, a smashed one, the door torn open - and, later, the ember of a cigarette.
-- At the counter a hero of the latest save sits with a bottle of whiskey, the head down;
-- at a table the second smokes; the third stands at the door with a pack, about to go.
-- A glass is poured at an empty stool, a note under it for whoever comes next (a new
-- game); the music comes out of a broken radio on the counter. A dead man lies under a
-- blanket near the smoker, the days cut into the wall over him; a cold fire on a sheet
-- of iron, the map of the way north on the other table. Shown from November to February,
-- or when Tab chose it (KnoxMenuPlace).
--
-- It is the camp's scene (KnoxMenuScene) in another place: what the camp does with its
-- heroes (their cards, a save loaded, the right-click menu) the bar does the same way;
-- what is the camp's alone (the fire, the forest, the night sky, its sounds) the bar has
-- its own of. Laid out in metres as the mockup is: U turns them into scene units. The
-- room's models are generated (MenuGen.java, "bar"); the tables and chairs are another
-- mod's (media/knox/bar_vp.txt: PZVoxelStudioViewpoint - read where it is installed;
-- without it the menu stays in the camp: not a require in mod.info, the pack is tied to
-- one game version - ROADMAP, for the author to settle at the release).
--
-- The room isn't the game's to draw: it has its own frame (KnoxBarFrame.java, the plan the
-- author approved, 2026-10-31): the storm's light with real shadows, shafts of light in
-- the air, the glow, the snow. Here is what stands where; the light is all there.

require "Knox/KnoxMenuScene"

KnoxMenuBar = KnoxMenuScene:derive("KnoxMenuBar")
local B = KnoxMenuBar
local T = KnoxTheme

local U = 1 / 1.22   -- scene units per metre (a standing character is 1.47 units)

local CFG = {
    fov = 32,                                   -- vertical, degrees (the mockup's)
    eye = {-3.4 * U, 1.95 * U, 3.9 * U},
    target = {-1.0 * U, 1.25 * U, -5.0 * U},
    -- laid out with the menu on the left already: not moved for it
    shiftWide = 0,
    shiftNarrow = 0,
    -- the rest as the camp's (KnoxMenuScene: CFG)
    yawOffset = 0,
    yawSign = -1,
    clearDepth = false,
    walkSpeed = 0.95,
    zombieWalkSpeed = 0.27,
    sitHeight = 0.95,
    standHeight = 1.5,
}

-- The cold fire: where its soot is baked into the floor (MenuGen.java: BAR_FIRE_X, _Z)
local FIRE_X, FIRE_Z = -0.3, -5.55

-- The room and what is in it, as the mockup of the last ones leaving has it, with the
-- author's changes (2026-10-31): the radio broken, no candle by the cans, a bottle for
-- the hero at the counter, the dead lying out from the wall near the smoker, the fire a
-- little left and nearer, no empty bed, the table in the smashed window one that reads
-- as a table. x and z in metres; y in units, ym in metres. A tint darkens what is dead
-- (the jukebox, the garland, the lamps); s is a scale. moves: what the wind moves
-- (KnoxBarFrame: 1 the door, 2 a lamp, 3 a loose sheet, 4 the radio's needle, 5 a journal's page, 6 the garland's bulbs, 7 its switch, 8 the pencil, 9 a sheet on its pin, 10 the whiskey bottle swatted off, 11 the garland's wire in the draught).
local PROPS = {
    {id = "kb_wall_back", model = "KnoxMenuBar.WallBack", y = 0.001, tint = {0.6, 0.6, 0.6}},
    {id = "kb_wall_left", model = "KnoxMenuBar.WallLeft", y = 0.002, tint = {0.6, 0.6, 0.6}},
    {id = "kb_wall_right", model = "KnoxMenuBar.WallRight", y = 0.003, tint = {0.6, 0.6, 0.6}},
    {id = "kb_floor", model = "KnoxMenuBar.Floor", y = 0.004, tint = {1, 1, 1}},
    -- (the ceiling on the walls: seen from under it, the sky came through a gap above them - 2026-11-04)
    {id = "kb_ceiling", model = "KnoxMenuBar.Ceiling", tint = {1.6, 1.6, 1.6}},
    {id = "kb_trim", model = "KnoxMenuBar.Trim", y = 0.006, tint = {0.95, 0.9, 0.85}},
    -- the room closed behind the menu's camera, for the walk about it (a draft: MenuGen's barRear)
    {id = "kb_rear_floor", model = "KnoxMenuBar.RearFloor", y = 0.004, tint = {1, 1, 1}},
    {id = "kb_rear_ceiling", model = "KnoxMenuBar.RearCeiling", tint = {1.6, 1.6, 1.6}},
    {id = "kb_rear_left", model = "KnoxMenuBar.RearLeft", y = 0.002, tint = {0.6, 0.6, 0.6}},
    {id = "kb_rear_right", model = "KnoxMenuBar.RearRight", y = 0.003, tint = {0.6, 0.6, 0.6}},
    {id = "kb_rear_wall", model = "KnoxMenuBar.RearWall", y = 0.001, tint = {0.6, 0.6, 0.6}},
    {id = "kb_rear_trim", model = "KnoxMenuBar.RearTrim", y = 0.006, tint = {0.95, 0.9, 0.85}},
    {id = "kb_boards", model = "KnoxMenuBar.Boards", y = 0.007, tint = {0.75, 0.72, 0.72}},
    -- (the litter lies on the floor's own height: a millimetre aside keeps its place
    -- apart from the floor's)
    {id = "kb_trash", model = "KnoxMenuBar.Trash", x = 0.001, y = 0.004},

    -- the counter, the hero's stool (unseen behind it; the others gone, the author, 2026-11-02), what stands on it
    {id = "kb_counter", model = "KnoxMenuBar.Counter", x = 0.2, z = 0.83, tint = {0.3, 0.3, 0.3}},
    {id = "kb_counter_top", model = "KnoxMenuBar.CounterTop", x = 0.2, y = 0.002, z = 0.83, tint = {0.35, 0.35, 0.35}},
    {id = "kb_counter_panels", model = "KnoxMenuBar.CounterPanels", x = 0.2, y = 0.003, z = 1.08, tint = {0.3, 0.3, 0.3}},
    {id = "kb_stool_hero", model = "KnoxMenuBar.Stool", x = -1.75, z = 0.05, yaw = 8, tint = {0.4, 0.4, 0.4}},
    -- (turned to whoever sat on this side of the counter and wrote it, not to the camera: the author, 2026-11-02)
    {id = "kb_journal", model = "KnoxMenuBar.Journal", x = -2.86, ym = 1.1, z = 0.68, yaw = 180, tint = {0.6, 0.6, 0.6}},
    -- (its pages, a strong gust turning them: as many as can be in the air at once - the author, 2026-11-02)
    -- (by it, parallel to its near edge: a strong gust rolls it off the counter - the author, 2026-11-02)
    {id = "kb_pencil", model = "KnoxMenuBar.Pencil", x = -2.72, ym = 1.1055, z = 0.9, yaw = 6, tint = {0.6, 0.6, 0.6}, moves = 8},
    {id = "kb_journal_page1", model = "KnoxMenuBar.JournalPage", x = -2.86, ym = 1.1, z = 0.68, yaw = 190, tint = {0.6, 0.6, 0.6}, moves = 5},
    {id = "kb_journal_page2", model = "KnoxMenuBar.JournalPage", x = -2.86, ym = 1.1, z = 0.68, yaw = 190, tint = {0.6, 0.6, 0.6}, moves = 5},
    {id = "kb_journal_page3", model = "KnoxMenuBar.JournalPage", x = -2.86, ym = 1.1, z = 0.68, yaw = 190, tint = {0.6, 0.6, 0.6}, moves = 5},
    {id = "kb_radio", model = "KnoxMenuBar.Radio", x = -2.315, ym = 1.1, z = 0.82, yaw = -11.5, tint = {0.4, 0.4, 0.4}},
    -- (its needle, moved along the dial: KnoxBarFrame.NEEDLE - the author, 2026-11-01)
    {id = "kb_radio_needle", model = "KnoxMenuBar.RadioNeedle", x = -2.315, ym = 1.1, z = 0.82, yaw = -11.5, tint = {0.4, 0.4, 0.4}, moves = 4},
    {id = "kb_counter_things", model = "KnoxMenuBar.CounterThings", ym = 1.1, z = 0.83, tint = {0.4, 0.4, 0.4}},
    -- (in the first hero's right hand, its palm against the bottle's side: SEATS, poses.py
    -- prints the place; more to the right than before - the author, 2026-11-01)
    {id = "kb_whiskey", model = "KnoxMenuBar.Whiskey", x = -1.795, ym = 1.1, z = 0.825, tint = {0.4, 0.4, 0.4}, moves = 10},

    -- the smoker's table: hero 2 sits on the chair at its left, facing it; the third
    -- chair knocked over behind it. (The table 1.05 m off him, its edge 0.48: his hand with the
    -- cigarette hangs 0.27 m before him, under its top's height, the ember 0.43 - at 0.7 they went
    -- through it, the author, 2026-11-01.)
    {id = "kb_table_smoker", model = "KnoxMenuBarVp.RoundTable", x = -1.25, z = -5.0},
    {id = "kb_table_smoker_leg", model = "KnoxMenuBar.TableLeg", x = -1.25, z = -5.0},
    {id = "kb_smoker_things", model = "KnoxMenuBar.SmokerThings", x = -1.25, y = 0.001, z = -5.0},
    {id = "kb_chair_smoker", model = "KnoxMenuBarVp.ChairA", x = -2.3, z = -5.0, yaw = 90, s = 0.9},
    {id = "kb_chair_3", model = "KnoxMenuBarVp.ChairC", x = -1.15, z = -4.35, yaw = 171, s = 0.9},
    -- (on its back, the legs to the room: rx -90 lays it down, rz then turns it about the
    -- floor's up; y lifts its back onto the floor)
    {id = "kb_chair_down", model = "KnoxMenuBarVp.ChairB", x = -1.25, y = 0.267, z = -6.25, rx = -90, rz = 17.2, s = 0.9},

    -- the other table: the map of the way north
    {id = "kb_table_map", model = "KnoxMenuBarVp.RoundTable", x = 2.25, z = -4.3},
    {id = "kb_table_map_leg", model = "KnoxMenuBar.TableLeg", x = 2.25, z = -4.3},
    {id = "kb_map_things", model = "KnoxMenuBar.MapThings", x = 2.25, y = 0.001, z = -4.3},
    {id = "kb_chair_map1", model = "KnoxMenuBarVp.ChairA", x = 2.95, z = -4.0, yaw = -108.9, s = 0.9},
    {id = "kb_chair_map2", model = "KnoxMenuBarVp.ChairB", x = 1.6, z = -4.7, yaw = 137.5, s = 0.9},

    -- the tally of days near the smoker (the dead man under his blanket that lay here went - the
    -- author, 2026-11-01); the stockpile by the flag, for the bucket (the author, 2026-11-02)
    {id = "kb_tally", model = "KnoxMenuBar.Tally", x = -2.85, ym = 1.35, z = -7.995, tint = {0.9, 0.9, 0.9}},
    {id = "kb_supplies", model = "KnoxMenuBar.Supplies", x = -4.5, z = -7.0},

    -- by the counter, where the eyes go when he looks at his arm (the author, 2026-11-04): what he set
    -- out to take it off, on sterile gauze so that it stays clean. There in both endings: he was ready.
    {id = "kb_saw_set", model = "KnoxMenuBar.SawSet", x = -2.61, y = 0.007, z = 1.555},

    -- the cold fire
    {id = "kb_fire", model = "KnoxMenuBar.Fire", x = FIRE_X, z = FIRE_Z, yaw = 8},

    -- the door torn open, swung out into the storm; the boards torn off it, the hammer
    {id = "kb_door", model = "KnoxMenuBar.Door", x = 4.4, z = -7.98, yaw = -71.6, tint = {0.55, 0.55, 0.55}, moves = 1},
    {id = "kb_door_things", model = "KnoxMenuBar.DoorThings", x = 2.7, z = -6.45},

    -- the windows: the boards' nails, the smashed one's sash, its glass and icicles, the
    -- snow blown in; the table shoved over in it (kb_table_window, below)
    {id = "kb_window_bits", model = "KnoxMenuBar.WindowBits", y = 0.001, z = -8.0},
    {id = "kb_window_glass", model = "KnoxMenuBar.WindowGlass", y = 0.002, z = -8.0, tint = {0.62, 0.68, 0.74}},
    {id = "kb_drift_door", model = "KnoxMenuBar.Drift", x = 3.85, ym = 0.006, z = -7.75, sx = 1.3, sy = 0.42, sz = 1.0, tint = {1.24, 1.16, 0.99}},
    {id = "kb_drift_in", model = "KnoxMenuBar.Drift", x = 3.55, ym = 0.007, z = -6.9, sx = 0.9, sy = 0.12, sz = 1.1, tint = {1.24, 1.16, 0.99}},
    {id = "kb_drift_window", model = "KnoxMenuBar.Drift", x = 1.5, ym = 0.006, z = -7.7, sx = 0.9, sy = 0.16, sz = 0.55, tint = {1.24, 1.16, 0.99}},

    -- on the walls, dead: the lamps, the jukebox, the antlers, the clock stopped, the
    -- garland, the wall of the missing; the stove gone cold
    {id = "kb_lamp1", model = "KnoxMenuBar.Lamp", x = -1.25, ym = 3.2, z = -5.0, tint = {0.33, 0.33, 0.33}, moves = 2},
    {id = "kb_lamp2", model = "KnoxMenuBar.Lamp", x = 1.7, ym = 3.2, z = -4.3, rz = 12.6, tint = {0.33, 0.33, 0.33}, moves = 2},
    {id = "kb_lamp3", model = "KnoxMenuBar.Lamp", x = -1.75, ym = 3.2, z = 0.2, tint = {0.33, 0.33, 0.33}, moves = 2},
    {id = "kb_jukebox", model = "KnoxMenuBar.Jukebox", x = -0.05, z = -7.62, tint = {0.6, 0.6, 0.6}},
    -- (knocked over in the empty left of the room, forced, what it held on the floor: the author, 2026-11-02)
    {id = "kb_cig_machine", model = "KnoxMenuBar.CigMachine", x = -4.2, z = -1.15, yaw = -97, tint = {0.9, 0.9, 0.9}},
    {id = "kb_antlers", model = "KnoxMenuBar.Antlers", x = -0.05, ym = 2.2, z = -7.99, tint = {0.6, 0.6, 0.6}},
    {id = "kb_clock", model = "KnoxMenuBar.Clock", x = 2.85, ym = 2.3, z = -7.98, tint = {0.53, 0.53, 0.53}},
    {id = "kb_garland", model = "KnoxMenuBar.Garland", z = -7.92, tint = {0.24, 0.24, 0.24}, moves = 11},
    {id = "kb_garland_bulbs", model = "KnoxMenuBar.GarlandBulbs", z = -7.92, tint = {0.24, 0.24, 0.24}, moves = 6},
    -- (hanging from the torn end: B:pressSwitch - the author, 2026-11-02)
    {id = "kb_garland_switch", model = "KnoxMenuBar.GarlandSwitch", x = 2.4, ym = 1.85, z = -7.9, tint = {0.5, 0.5, 0.5}, moves = 7},
    -- (darker: the sheets read too light - the author, 2026-11-02)
    {id = "kb_missing", model = "KnoxMenuBar.Missing", x = 5.3, ym = 1.65, z = -7.98, tint = {0.42, 0.42, 0.42}},
    -- its sheets, each on its pin, trembling in the still air and flapping in a strong gust (the
    -- author, 2026-11-02): SHEETS' (below), at its top edge, in its number's order - the n-th of them
    -- is photo slot n - 1 (KnoxBarFrame.drawPhotos); half a mm nearer the room for each
    {id = "kb_wall_sheet1", model = "KnoxMenuBar.SheetMissing", x = 4.9049, ym = 1.3219, z = -7.9810, rx = 90, yaw = -80.38, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet2", model = "KnoxMenuBar.SheetMissing", x = 5.1790, ym = 1.3388, z = -7.9805, rx = 90, yaw = -83.70, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet3", model = "KnoxMenuBar.SheetMissing", x = 5.4638, ym = 1.3116, z = -7.9800, rx = 90, yaw = -90.89, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet4", model = "KnoxMenuBar.SheetMissing", x = 5.7087, ym = 1.3247, z = -7.9795, rx = 90, yaw = -86.54, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet5", model = "KnoxMenuBar.SheetMissing", x = 4.9086, ym = 1.6309, z = -7.9790, rx = 90, yaw = -97.34, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet6", model = "KnoxMenuBar.SheetMissing", x = 5.1710, ym = 1.6399, z = -7.9785, rx = 90, yaw = -83.27, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet7", model = "KnoxMenuBar.SheetMissing", x = 5.4437, ym = 1.6187, z = -7.9780, rx = 90, yaw = -97.83, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet8", model = "KnoxMenuBar.SheetMissing", x = 5.7289, ym = 1.6456, z = -7.9775, rx = 90, yaw = -98.90, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet9", model = "KnoxMenuBar.SheetMissing", x = 4.8792, ym = 1.9054, z = -7.9770, rx = 90, yaw = -85.89, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet10", model = "KnoxMenuBar.SheetMissing", x = 5.1744, ym = 1.9067, z = -7.9765, rx = 90, yaw = -93.88, tint = {0.42, 0.42, 0.42}, moves = 9},
    {id = "kb_wall_sheet11", model = "KnoxMenuBar.SheetMissing", x = 5.4460, ym = 1.9418, z = -7.9760, rx = 90, yaw = -88.19, tint = {0.42, 0.42, 0.42}, moves = 9},
    -- (the stove went for what a bar hangs on its wall: the author, 2026-11-02)
    {id = "kb_wall_things", model = "KnoxMenuBar.WallThings", z = -7.97, tint = {0.8, 0.8, 0.8}},

    -- (stage 5, 2026-10-31) what the draft lifts: spread newspapers on the floor in the light from
    -- the door and the window, where the camera sees the floor (QA: behind the heroes and the
    -- chairs they were a few pixels; the critic: the right one under the news cards, the left one
    -- under the chair, the boards by the door on the right one), held at the edge towards the
    -- camera, the wind getting under
    -- the edge towards the wall (its face to the camera as it rises: from below a sheet is dark,
    -- its normal turned away); on the floor's own height. One of the missing hanging by its top pin (rx and
    -- yaw stand the sheet on the wall, its free edge down)
    {id = "kb_sheet_map_r", model = "KnoxMenuBar.SheetNews", x = 2.25, y = 0.004, z = -5.4, yaw = 90, s = 1.25, moves = 3},
    {id = "kb_sheet_map_l", model = "KnoxMenuBar.SheetNews", x = 1.4, y = 0.004, z = -4.95, yaw = 90, s = 1.25, moves = 3},
    {id = "kb_sheet_missing", model = "KnoxMenuBar.SheetMissing", x = 4.82, ym = 1.42, z = -7.97, rx = 90, yaw = -90, tint = {0.42, 0.42, 0.42}, moves = 3},

    -- The table shoved over in the smashed window (the author, 2026-10-31: on the mockup
    -- it did not read as a table): thrown upside down on the sill, half out in the snow,
    -- its four legs up against the whiteout (of the poses tried in the preview of the
    -- game's frame, the one that reads at once). rx 180 turns it over, yaw and rz throw
    -- it a little askew; y puts its top (0.68 tiles) on the sill's snow. One front leg
    -- hides the broken sash's upright, or it reads as a fifth leg.
    {id = "kb_table_window", model = "KnoxMenuBarVp.LongTable", x = 1.29, y = 1.40, z = -8.12, rx = 180, yaw = -14, rz = -4},
    -- (a solid bottom for it: the author, 2026-11-01, saw the snow through the table's own)
    {id = "kb_table_under", model = "KnoxMenuBar.TableUnder", x = 1.29, y = 1.40, z = -8.12, rx = 180, yaw = -14, rz = -4},
}

-- The lamps the game's own shaded models are lit by (KnoxMenu.java: knoxMenuSceneLights; the
-- heroes' bags): the room's cold dark, no fire, no lamp; the storm's cold from the openings.
local DARK = {0.06, 0.07, 0.09}
local COLD = {dir = {-0.155, 0.384, -0.91}, light = {0.25, 0.32, 0.38}}

-- The heroes (stage 4 of the plan, 2026-10-31): the three latest saves still alive, as the
-- mockup has them. 1: at the counter on a stool, slumped, a hand round the bottle, the head
-- down; 2: at the table, smoking (the ember the only warm light in the room); 3: at the door
-- with the pack on, about to go, looking back. Their clips are the mod's own
-- (tools\barframe\poses.py: Knox_BarStool, Knox_BarSmoke). x, z in metres; y in units (the
-- hips lifted onto the stool); face as the camp's (0 to the camera); height and head over
-- the floor, units (the mouse, the look); amb, sky: how much of the room's dark and of the
-- storm's light reaches the place (as the frame lights a grey stand-in there:
-- tools\barframe); look: where the head is held (yaw, pitch; the first's own is the clip's - its
-- -28 threw the head back in the game, the author 2026-11-01); lookBack: at the camera; still: no head turned to the mouse over it
-- (the first, asleep over its bottle - the author, 2026-11-01); hoverLook: where the head goes
-- with the mouse over it, x y z in metres, instead of to the camera (the third, to the way out:
-- the middle of the door's opening, MenuGen's BAR_BACK_HOLES - the author, 2026-11-01); hitFrom:
-- the height, units, the mouse finds it from (the first is behind the counter: its place went down
-- to the floor, past the bottom of the screen - the author's screenshot, 2026-11-01).
local SEATS = {
    {x = -1.75, z = 0.05, y = 0.20, face = 0, anim = "knoxbar_stool", height = 1.3, head = 0.95, amb = 0.11, sky = 0.7,
        still = true, hitFrom = 0.85},
    {x = -2.3, z = -5.0, y = 0, face = 90, anim = "knoxbar_smoke", hand = "Base.Cigarette_Lit", height = 1.1, head = 0.95,
        amb = 0.085, sky = 0.55},
    {x = 2.7, z = -6.95, y = 0, face = 131, anim = "knoxmenu_stand", height = 1.5, head = 1.24, amb = 0.13, sky = 0.95,
        lookBack = true, pack = true, hoverLook = {3.85, 1.5, -8}},
}
-- where a hero's bag is put down, by seat (x, z metres, yaw, y units): the first one's on the
-- counter close by him (the author, 2026-11-02), the smoker's on the floor by the chair; the third keeps the pack on. (The smoker's
-- by the chair's back, to the room: QA, 2026-11-01 - by the dead man's mattress it was under the
-- game's menu at 2560x1440, by the chair's side behind the cans on the counter.)
local BAGS = {{-1.3, 0.78, 20, 1.1 * U}, {-2.55, -4.25, 30, 0}}
-- the journal open on the counter at the empty place, its next page clean: a click on it is a new game
local NEW_GAME = {x = -2.75, z = -0.12, height = 1.35, halfWidth = 0.4}
-- what each pose plays (KnoxMenuScene: watchPose), and the clips to be loaded first
local CLIPS = {knoxbar_stool = "Knox_BarStool", knoxbar_smoke = "Knox_BarSmoke", knoxmenu_stand = "Bob_Idle",
    knoxbar_stool_b = "Knox_BarStoolB", knoxbar_stool_e = "Knox_BarStoolE", knoxbar_stool_eb = "Knox_BarStoolEB"}
local MENU_CLIPS = "Knox_BarStool,Knox_BarSmoke,Bob_Idle,Zombie_Idle,Zombie_Walk2,Zombie_Walk3,Zombie_Walk4,"
    .. "Knox_BarStoolB,Knox_BarStoolE,Knox_BarStoolEB,Knox_BarWakeA,Knox_BarWakeB,Knox_BarWakeE,Knox_BarWakeEB,"
    .. "Knox_BarShiftA,Knox_BarShiftB,Knox_BarShiftE,Knox_BarShiftEB,Knox_BarSwatA,Knox_BarSwatB"
-- Their light (KnoxMenu.java: knoxMenuLight, knoxBarHeroLights): the room's cold dark; the
-- storm's from the openings, as much as reaches each place; the ember's on the smoker's face,
-- from in front and below, stronger on a drag. Matched to the frame's light on a grey
-- stand-in at each place (tools\barframe, 2026-10-31: 0.10-0.19 in the shade, 0.24-0.34 on
-- the lit side, bluish), not seen in the game yet.
local HERO_DARK = {0.8, 1.0, 1.2}   -- (times the place's amb)
local EMBER = {1.0, 0.48, 0.19}
-- The dead out in the storm, beyond the back wall (the author, 2026-11-01: real zombies, the
-- mannequins of the frame went): the game's models in its outfits, the camp's walks, going along
-- the wall and round again out of sight. z, x to start from in metres, which way along x.
-- Who they are is chance, in winter clothes, anew each time round (knoxBarDead; the author, 2026-11-01).
local DEAD = {
    {z = -11.4, x = 0.5, dir = 1, anim = "knoxmenu_zwalk"},
    {z = -12.8, x = 6.5, dir = -1, anim = "knoxmenu_zwalk2"},
    {z = -14.6, x = -2.5, dir = 1, anim = "knoxmenu_zwalk3"},
}
-- The wall of the missing (kb_missing; the author, 2026-11-01): the dead heroes on its sheets, a
-- photo on each and the card under the mouse, as a cross's in the camp. Its sheets as MenuGen lays
-- them (Random 441): x, y from the wall's middle in metres, tilt, its number there. The sheets
-- nearest the room first.
local WALL_X, WALL_Y, WALL_Z = 5.3, 1.65, -7.98
local SHEET_W, SHEET_H = 0.19, 0.25
local SHEETS = {
    {-0.1341, 0.1320, -3.88, 10}, {-0.1144, -0.1342, 6.73, 6}, {-0.1073, -0.4354, 6.30, 2},
    {-0.4118, 0.1307, 4.11, 9}, {-0.4074, -0.1431, -7.34, 5}, {-0.3742, -0.4513, 9.62, 1},
    {0.1499, 0.1669, 1.81, 11}, {0.1267, -0.1551, -7.83, 7}, {0.1619, -0.4634, -0.89, 3},
    {0.4096, -0.1279, -8.90, 8}, {0.4162, -0.4501, 3.46, 4},
}
-- the photo on a sheet: its dark frame in the sheet's picture (MenuGen: P_SHEET, 76 x 74 of 96 x 128,
-- its middle 0.033 m over the sheet's)
local PHOTO_W, PHOTO_H, PHOTO_UP = 0.1504, 0.1445, 0.0332
local WALL_SAVES = 24        -- how far back the dead are looked for
local PHOTO_FOR = 1.0        -- s a photo is taken over, once its model can be drawn (its clothes built)
local PHOTO_GIVE_UP = 8      -- s: the sheet keeps its drawn picture
local DEAD_FROM, DEAD_TO = -6 * U, 10 * U
-- (the snow's light on them: their clothes have to read, the author, 2026-11-01)
local DEAD_AMB = {0.42, 0.46, 0.5}
local DEAD_GIVE_UP = 30      -- s the wardrobe and then the pose are waited for
-- (too many went by the windows, the author 2026-11-02: each waits out of sight between its walks, s)
local DEAD_REST_MIN, DEAD_REST_MAX = 25, 70
-- Now and then one of them stops at a window, turns to look into the bar, stands a little, goes on
-- (the author, 2026-11-02). The windows' middles, x (MenuGen's BAR_BACK_HOLES); s before the first, between
-- them; how long it stands; its turn from walking, degrees (the head does the rest of the way to the room).
local PEEK_WINDOWS = {-1.45 * U, 1.5 * U}
local PEEK_FIRST, PEEK_EVERY_MIN, PEEK_EVERY_MAX = 12, 35, 80
local PEEK_MIN, PEEK_MAX = 2.5, 5
local PEEK_TURN, PEEK_HEAD = 40, 45
local HERO_FADE = 1.2        -- s a hero takes to come out of the dark (by light: KnoxBarFrame
                             -- tells a hero's pixels by their alpha, so it is 1 at once)

function B:new()
    local o = KnoxMenuScene.new(self)
    o.cfg = CFG
    return o
end

function B:loadTextures()
    self.tex = {flames = {}, glow = getTexture("media/ui/knoxmenu/glow.png")}
end

--- Built whole: every file of the room read (one not there: another mod's model is not
--- installed - then the menu has its camp).
function B:builtOk()
    return self.frameLoaded == true
end

-- The garland as it was left, off the first time (the author, 2026-11-02): Zomboid/Lua/knox_bar_garland.txt
local GARLAND_FILE = "knox_bar_garland.txt"
local garlandOn

function B.garlandSaved()
    if garlandOn == nil then
        garlandOn = false
        local r = getFileReader and getFileReader(GARLAND_FILE, false)
        if r then
            garlandOn = r:readLine() == "on"
            r:close()
        end
    end
    return garlandOn
end

function B:build()
    if T.barLook then T.barLook(true) end
    local j = self.scene.javaObject
    j:fromLua1("setDrawGrid", false)
    j:fromLua1("setDrawGridAxes", false)
    j:fromLua1("setDrawGridPlane", false)
    j:fromLua1("setGizmoVisible", "none")
    self:aimCamera()

    -- (no fire and no lamp alive: theirs are dark)
    self.lights = {DARK[1], DARK[2], DARK[3],
        0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 1,
        COLD.dir[1], COLD.dir[2], COLD.dir[3], COLD.light[1], COLD.light[2], COLD.light[3]}
    knoxMenuSceneLights(self.lights)
    knoxMenuFireFlicker(1)

    self.objects = {}
    self.chars = {}
    self.flames, self.licks = {}, {}
    self.revealAt, self.revealDone = nil, nil
    self.memorials = {}
    self.empties = {}
    -- (the keepsakes lie in the camp: none of them is here to be pointed at)
    if KnoxMenuKeep and KnoxMenuKeep.list then
        for _, k in ipairs(KnoxMenuKeep.list) do k.obj, k.skinned = nil, nil end
    end
    knoxBarStart()
    if knoxBarGarland then knoxBarGarland(B.garlandSaved(), true) end
    for _, p in ipairs(PROPS) do
        local s = p.s or 1
        local tint = p.tint
        knoxBarProp(p.model, (p.x or 0) * U, (p.y or 0) + (p.ym or 0) * U, (p.z or 0) * U,
            p.rx or 0, p.yaw or 0, p.rz or 0, (p.sx or 1) * s, (p.sy or 1) * s, (p.sz or 1) * s,
            tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1, p.moves or 0)
    end
    local readFrom = getTimestampMs()
    self.frameLoaded = knoxBarLoad()
    -- (what a switch to the bar waits for: the author, 2026-11-02)
    print("[Knox] menu scene (bar): the room's files read in " .. (getTimestampMs() - readFrom) .. " ms")
    -- (just back from the game: told here, or a later Tab would have the camp's
    -- hero walk in as if back this moment; a bar that failed leaves it to the camp)
    if knoxMenuReturned and self:builtOk() then knoxMenuReturned() end
    if self:builtOk() then
        self:addHeroes()
        self:addDead()
        self:addMissing()
        self:addEyes()
    end
end

--- The dead heroes of the latest saves on the wall of the missing, the latest first.
function B:addMissing()
    self.photoQueue = {}
    if not knoxBarPhotoPlace then return end
    local n = 0
    for _, save in ipairs(KnoxMenuScene.recentSaves(WALL_SAVES)) do
        if save.dead and n < #SHEETS then
            n = n + 1
            local s = SHEETS[n]
            local m = {memorial = true, sheet = true, save = save, height = 1,
                wx = WALL_X + s[1], wy = WALL_Y + s[2], wz = WALL_Z,
                x = (WALL_X + s[1]) * U, z = WALL_Z * U}
            m.portrait = self:makePortrait(save, false)
            -- (on its sheet, in the sheet's own frame: down from the pin, as the sheet moves in the wind)
            knoxBarPhotoPlace(s[4] - 1, SHEET_H / 2 - PHOTO_UP, 0, PHOTO_W, PHOTO_H, 0.6)
            table.insert(self.memorials, m)
            if save.snap then table.insert(self.photoQueue, {slot = s[4] - 1, save = save}) end
        end
    end
end

--- One photo at a time, a frame's take of it each frame, the last one kept: a model drawn only
--- once its clothes are built and it stands in its pose. Before the frame opens (it has a target of its own).
function B:updatePhotos()
    local q = self.photoQueue
    local p = q and q[1]
    if not p or not knoxBarPhotoTake then return end
    local now = self.clock
    if not p.camera then
        if not knoxMenuClothesReady(p.save.rel) and not p.waited then
            p.waitFrom = p.waitFrom or now
            if now - p.waitFrom < PHOTO_GIVE_UP then return end
            p.waited = true
        end
        local camera = self:makePortrait(p.save, false)
        if not camera then
            table.remove(q, 1)
            return
        end
        -- (not the menu's to draw: only the take does)
        self:removeChild(camera)
        p.camera = camera
        p.since = now
        self.photoMs = getTimestampMs()
    end
    local j = p.camera.javaObject
    local last = p.readyAt and now - p.readyAt >= PHOTO_FOR
    if knoxBarPhotoTake(j, p.slot, last == true) then
        p.readyAt = p.readyAt or now
    end
    if last or now - p.since > PHOTO_GIVE_UP then
        table.remove(q, 1)
        self.photoTakenMs = getTimestampMs()
    end
end

--- The dead: too small to see until dressed and in their walk (B:updateDead). Not among
--- self.chars: nobody points at them.
function B:addDead()
    self.dead = {}
    if not knoxBarDead then return end
    local j = self.scene.javaObject
    for i, d in ipairs(DEAD) do
        local c = {id = "kb_dead" .. i, x = d.x * U, y = 0, z = d.z * U, face = d.dir > 0 and 90 or -90, s = 0.001,
            anim = d.anim, walkAnim = d.anim, dir = d.dir, outfit = d.outfit, female = d.female == true}
        c.yaw = self:yawOf(c.face)
        local ok = pcall(function()
            j:fromLua1("createCharacter", c.id)
            j:fromLua2("setCharacterClearDepthBuffer", c.id, self.cfg.clearDepth)
        end)
        if ok then
            knoxMenuAnim(j, c.id, c.anim)
            self:place(c)
            table.insert(self.dead, c)
        end
    end
end

--- Is it at a window, and is this the time for someone to stop? Only one at a time.
local function peekHere(self, c, t)
    if self.peeker or t < (self.peekNext or PEEK_FIRST) then return false end
    for i = 1, #PEEK_WINDOWS do
        local d = (PEEK_WINDOWS[i] - c.x) * c.dir
        if d >= 0 and d < 0.25 * U then return true end
    end
    return false
end

--- The one who stopped: its body turning to the room, then its head; back to the walk when it's had enough.
local function updatePeek(self, j, c, t, dt)
    local going = t >= c.peekUntil
    if going and c.anim ~= c.walkAnim then
        c.anim = c.walkAnim
        c.poseAsked = nil
        knoxMenuAnim(j, c.id, c.anim)
    end
    local face = c.dir > 0 and 90 or -90
    local to = going and face or face - c.dir * PEEK_TURN
    local ease = 1 - math.exp(-dt * 2.2)
    c.faceNow = (c.faceNow or face) + (to - (c.faceNow or face)) * ease
    c.yaw = self:yawOf(c.faceNow)
    self:place(c)
    c.peekW = math.max(0, math.min(1, (c.peekW or 0) + dt * (going and -1.4 or 0.8)))
    if knoxMenuLook then
        local k = c.peekW * c.peekW * (3 - 2 * c.peekW)
        -- (to the bar's side: as M:updateLooks' sign)
        knoxMenuLook(j, c.id, c.dir * PEEK_HEAD, -4, k)
    end
    if going and c.peekW <= 0 then
        c.peekUntil, c.peekW, c.faceNow = nil, nil, nil
        c.yaw = self:yawOf(face)
        self:place(c)
        self.peeker = nil
    end
end

--- Dressed once the game's wardrobe is read, shown once in their walk; on along the wall.
function B:updateDead()
    local list = self.dead
    if not list then return end
    local j = self.scene.javaObject
    local t, dt = self.clock, self.dt or 0
    for i = 1, #list do
        local c = list[i]
        if c.restUntil and t < c.restUntil then
            -- (out of sight, till its next walk)
        elseif not c.clad then
            if knoxBarClothesLoaded() or t > DEAD_GIVE_UP then
                c.clad = true
                knoxBarDead(j, c.id)
                self.dressMs, self.dressId = getTimestampMs(), c.id
                c.holdUntil = t + 0.8   -- (built anew in the frames to come)
                c.cladAt = t
            end
        elseif not c.shownAt then
            self:watchPose(c, t)
            if c.posedAt or t - c.cladAt > DEAD_GIVE_UP then
                c.shownAt = t
                self.shownMs = getTimestampMs()
                c.s = 1
                self:place(c)
            end
        elseif not c.peekUntil and peekHere(self, c, t) then
            self.peeker = c
            self.peekNext = t + PEEK_EVERY_MIN + ZombRandFloat(0, PEEK_EVERY_MAX - PEEK_EVERY_MIN)
            c.peekUntil = t + PEEK_MIN + ZombRandFloat(0, PEEK_MAX - PEEK_MIN)
            c.anim = "knoxmenu_zombie"
            knoxMenuAnim(j, c.id, c.anim)
        elseif c.peekUntil then
            updatePeek(self, j, c, t, dt)
        else
            c.x = c.x + c.dir * self:zombieSpeed(c) * dt
            if c.x > DEAD_TO or c.x < DEAD_FROM then
                -- round again out of sight, as somebody else: dressed anew, shown once ready
                c.x = c.x > DEAD_TO and DEAD_FROM or DEAD_TO
                c.clad, c.shownAt, c.posedAt, c.poseAsked = nil, nil, nil, nil
                c.restUntil = t + DEAD_REST_MIN + ZombRandFloat(0, DEAD_REST_MAX - DEAD_REST_MIN)
                c.s = 0.001
                self:place(c)
                return
            end
            j:fromLua1("getObjectTranslation", c.id):set(c.x, 0, c.z)
            local k = math.min(1, (t - c.shownAt) / HERO_FADE)
            knoxMenuLight(j, c.id, DEAD_AMB[1], DEAD_AMB[2], DEAD_AMB[3], k, k, k)
        end
    end
end

--- The heroes at their places, each with its bag; the empty stool's glass for a new game.
function B:addHeroes()
    self.clips = CLIPS
    self.menuClips = MENU_CLIPS
    self.bagPlaces = {}
    for i, b in ipairs(BAGS) do self.bagPlaces[i] = {b[1] * U, b[2] * U, b[3], b[4]} end
    self.heroAt = {}
    self.doorOpen = 0
    local saves = {}
    for _, save in ipairs(KnoxMenuScene.recentSaves(12)) do
        if not save.dead and #saves < #SEATS then table.insert(saves, save) end
    end
    for slot, save in ipairs(saves) do
        local s = SEATS[slot]
        local seat = {x = s.x * U, z = s.z * U, y = s.y, face = s.face, s = s}
        local c = {id = "kb_hero" .. slot, slot = slot, save = save, seat = seat, anim = s.anim, hand = s.hand,
            x = seat.x, y = s.y, z = seat.z, face = s.face, height = s.height, nextAt = 0, lightK = 0}
        -- (the bag off the back before dressing, put down at its place)
        self:addBag(c, slot)
        c.pack = s.pack == true and c.bag ~= nil and c.bag.back ~= nil
        if self:addCharacter(c) then self.heroAt[slot] = c end
    end
    table.insert(self.empties, {empty = true, x = NEW_GAME.x * U, z = NEW_GAME.z * U, height = NEW_GAME.height,
        halfWidth = NEW_GAME.halfWidth, mat = {}})
    for _, c in ipairs(self.chars) do
        if c.dressed then c.portrait = self:makePortrait(c.save, c.zombie) end
    end
end

-- The one asleep at the counter stirs as the mouse comes onto him (the author, 2026-11-02): wakes
-- for a moment and hiccups, or his breath catches and his head rolls to its other side, or he
-- swats at nothing and the whiskey bottle goes off the counter and breaks (once: it is back with
-- the room built anew). One at a time, never the same twice running, SLEEP_AGAIN s apart. His
-- rest: the head on side "a" or "b", the hand round the bottle or empty (tools\barframe\poses.py:
-- the clips, timed as below - s from the start: its line "times"; redone after the author's video
-- the same day, 2026-11-02). His voice: the hiccup, the snore catching, the lips smacked - files
-- of their own (the game's voices are FMOD events it keeps silent in the menu: the author heard
-- none); a sound with no files is left out.
local SLEEP_AGAIN = 4
local STIR = {wake = {len = 3.7, voice = {{1.6, "hic"}}}, shift = {len = 2.5, voice = {{0.45, "snore"}, {0.84, "smack"}}},
    swat = {len = 1.9, knock = 1.06}}
local SLEEP_VOICE = {male = {hic = {}, snore = {}, smack = {}}, female = {hic = {}, snore = {}, smack = {}}}
local SLEEP_VOICE_VOL = 0.5
local BOTTLE_SMASH_VOL = 0.16   -- (0.45 was very loud: the author, 2026-11-02)

local function sleepCode(c)
    return (c.sleepEmpty and "e" or "") .. (c.sleepSide == "b" and "b" or (c.sleepEmpty and "" or "a"))
end

local function restState(c)
    local code = sleepCode(c)
    return code == "a" and "knoxbar_stool" or ("knoxbar_stool_" .. code)
end

--- One of the hero's sex's recordings of a sound ("hic", "snore", "smack"), played straight.
local function heroVoice(c, what)
    local snap = c.save and c.save.snap
    local set = SLEEP_VOICE[snap and snap.female == true and "female" or "male"][what]
    if #set > 0 and knoxCampSoundCut then knoxCampSoundCut(set[ZombRand(#set) + 1], SLEEP_VOICE_VOL, 0) end
end

function B:stir(c, t)
    local kinds = {"wake", "shift"}
    if not c.sleepEmpty and knoxBarBottleKnock then table.insert(kinds, "swat") end
    for i = #kinds, 1, -1 do
        if kinds[i] == c.lastStir and #kinds > 1 then table.remove(kinds, i) end
    end
    local kind = kinds[ZombRand(#kinds) + 1]
    c.lastStir = kind
    c.stir = {kind = kind, at = t}
    local state = kind == "swat" and ("knoxbar_swat_" .. (c.sleepSide == "b" and "b" or "a"))
        or ("knoxbar_" .. kind .. "_" .. sleepCode(c))
    self:setAnim(c, state)
end

function B:updateSleeper(c)
    local t = self.clock
    local hovered = self.hover == c
    local st = c.stir
    if st then
        local e, how = t - st.at, STIR[st.kind]
        local v = how.voice and how.voice[(st.voiced or 0) + 1]
        if v and e >= v[1] then
            st.voiced = (st.voiced or 0) + 1
            heroVoice(c, v[2])
        end
        if how.knock and not st.knocked and e >= how.knock then
            st.knocked = true
            c.bottleBreaksWas = knoxBarBottleBreaks and knoxBarBottleBreaks() or 0
            c.bottleOff = true
            knoxBarBottleKnock()
        end
        if e >= how.len then
            c.stir = nil
            c.stirReady = t + SLEEP_AGAIN
            if st.kind == "shift" then c.sleepSide = c.sleepSide == "b" and "a" or "b" end
            if st.kind == "swat" then c.sleepEmpty = true end
            self:setAnim(c, restState(c))
        end
    elseif hovered and not c.wasHovered and t >= (c.stirReady or 0) then
        self:stir(c, t)
    end
    c.wasHovered = hovered
    -- (the glass on the floor: when the frame says it got there. The game's own file, played
    -- straight: its FMOD events are kept silent in the menu - the author heard none, 2026-11-02)
    if c.bottleOff and not c.bottleHeard and knoxBarBottleBreaks and knoxBarBottleBreaks() > c.bottleBreaksWas then
        c.bottleHeard = true
        if knoxCampSoundCut then knoxCampSoundCut("media/sound/bottlesmash.ogg", BOTTLE_SMASH_VOL, 0) end
    end
end

--- They hold their poses (the camp's warm their hands now and then); the first one, asleep, stirs.
function B:idle(c, dt)
    if c.slot == 1 and c.shownAt then self:updateSleeper(c) end
end

--- Each comes out of the dark once in its pose (KnoxMenuScene: watchHero): by its light, not
--- by its alpha (see HERO_FADE).
function B:watchHero(c, t)
    local was = c.shownAt
    KnoxMenuScene.watchHero(self, c, t)
    if c.shownAt and not was then
        -- (swiped in: lit at once, KnoxMenuScene.watchHero)
        c.lightK = self.swiped and 1 or 0
        if knoxMenuAlpha then knoxMenuAlpha(self.scene.javaObject, c.id, 1) end
    end
end

function B:fadeIn(c, t)
    if not c.fadeAt then return end
    local k = math.max(0, math.min(1, (t - c.fadeAt) / HERO_FADE))
    c.lightK = k * k * (3 - 2 * k)
    if k >= 1 then c.fadeAt = nil end
end

function B:lightCharacter(c, flick)
    local j = self.scene.javaObject
    local k = (c.lightK or 0) * ((self.hover == c) and 1.4 or 1)
    -- (no snapshot of this save: a dark figure, as the camp's - QA, 2026-10-31)
    if not c.dressed then k = k * 0.25 end
    local s = c.seat and c.seat.s
    local amb = s and s.amb or 0.1
    knoxMenuLight(j, c.id, HERO_DARK[1] * amb, HERO_DARK[2] * amb, HERO_DARK[3] * amb, k, k, k)
    if not knoxBarHeroLights then return end
    -- the storm's, towards the openings, in the model's own space (x side, y up, z front)
    local d = COLD.dir
    local a = math.rad(c.faceNow or c.face)
    local fx, fz = math.sin(a), math.cos(a)
    local sky = (s and s.sky or 0.5) * k
    -- (the frame's ember lamp: 40% of it between drags; brighter - the author, 2026-11-01)
    local e = (c.emberGlow or -1) >= 0 and (0.13 + 0.5 * c.emberGlow) * k or 0
    knoxBarHeroLights(j, c.id, d[1] * fz - d[3] * fx, d[2], d[1] * fx + d[3] * fz,
        COLD.light[1] * sky, COLD.light[2] * sky, COLD.light[3] * sky,
        0, -0.35, 0.94, EMBER[1] * e, EMBER[2] * e, EMBER[3] * e,
        c.x, (c.y or 0) + (s and s.head or 1) * 0.85, c.z, fx, fz)
end

-- Where they look (KnoxLook): the first with the head down, the third back over the shoulder
-- at the room; the mouse on one, and the head comes up to the camera. Walking off: the walk's
-- own head.
local LOOK_IN, LOOK_OUT = 2.6, 1.6        -- of the way a second, as the camp's
local LOOK_EASE = 3                       -- 1/s, the head going from one look to the other
local LOOK_MAX_YAW, LOOK_MAX_PITCH = 65, 30
local LOOK_YAW_SIGN = -1                  -- (as the camp's)

local function lookAtPoint(c, px, py, pz)
    local dx, dy, dz = px - c.x, py - ((c.y or 0) + c.seat.s.head), pz - c.z
    local yaw = math.deg(math.atan2(dx, dz) - math.rad(c.faceNow or c.face or 0))
    yaw = T.mod(yaw + 180, 360) - 180   -- (not %: negative in the game's Lua)
    yaw = math.max(-LOOK_MAX_YAW, math.min(LOOK_MAX_YAW, yaw)) * LOOK_YAW_SIGN
    local pitch = math.deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz)))
    return yaw, math.max(-LOOK_MAX_PITCH, math.min(LOOK_MAX_PITCH, pitch))
end

local function lookAtEye(self, c)
    return lookAtPoint(c, self.eyeX, self.eyeY, self.eyeZ)
end

function B:updateLooks(dt)
    if not knoxMenuLook or not self.eyeX then return end
    local j = self.scene.javaObject
    local ease = 1 - math.exp(-dt * LOOK_EASE)
    for _, c in ipairs(self.chars) do
        local s = c.seat and c.seat.s
        if s then
            local ty, tp
            if self.leaving == c then
                -- (its own head)
            elseif self.hover == c and self.mode == "idle" and not s.still then
                local at = s.hoverLook
                if at then
                    ty, tp = lookAtPoint(c, at[1] * U, at[2] * U, at[3] * U)
                else
                    ty, tp = lookAtEye(self, c)
                end
            elseif s.look then
                ty, tp = s.look[1], s.look[2]
            elseif s.lookBack then
                ty, tp = lookAtEye(self, c)
            end
            local w = c.lookW or 0
            if ty then
                w = math.min(1, w + dt * LOOK_IN)
                -- (from the look it had: the head doesn't jump from one to the other)
                if not c.lookYaw then c.lookYaw, c.lookPitch = ty, tp end
                c.lookYaw = c.lookYaw + (ty - c.lookYaw) * ease
                c.lookPitch = c.lookPitch + (tp - c.lookPitch) * ease
            else
                w = math.max(0, w - dt * LOOK_OUT)
            end
            if w > 0 or (c.lookW or 0) > 0 then
                local k = w * w * (3 - 2 * w)
                -- (a thing in the hand: the arm stays with it, KnoxLook)
                if s.hand and knoxMenuLookHoldArms then knoxMenuLookHoldArms(j, c.id) end
                knoxMenuLook(j, c.id, c.lookYaw or 0, c.lookPitch or 0, k)
            end
            c.lookW = w
        end
    end
end

--- The hero's save was picked: the screen goes black where they are and the save loads
--- (KnoxMenuScene: launch). (No getting up and walking out through the door any more: the
--- author, 2026-11-01.)
function B:leave(c)
    self.mode = "leaving"
    self.leaving = c
    self.hover = nil
    c.clock = 0
    c.phase = "fade"
    self:showFader()
    self.fader.target = 1
    getSoundManager():playUISound("UIActivateMainMenuItem")
    if knoxMusicDuck then knoxMusicDuck(0.4, 1500) end
end

function B:updateLeaving(dt)
    local c = self.leaving
    c.clock = c.clock + dt
    self.fader.target = 1
    if self.fader.alpha >= 0.99 then self:launch(c) end
end

--- Loading didn't start: back to the place, as it was.
function B:comeBack()
    local c = self.leaving
    KnoxMenuScene.comeBack(self)
    self.doorOpen = 0
    if c and c.seat then
        c.y = c.seat.y
        self:place(c)
        self:setAnim(c, c.seat.s.anim)
    end
end

-- The camera is the eyes of the one in the room (the author's idea, 2026-11-02): now and then he
-- looks down at his left forearm, rolls the warm jacket's sleeve up, turns the arm - a bite - and
-- yanks the sleeve down; or nothing there, and he lets it down slowly. The Java part has the moment
-- and his arms (KnoxBite); here he is stood where the camera is, and the view turns with his head.
-- It comes of itself, rarely: the bar left alone a while, the mouse still. B starts it too for now,
-- the bite and the quiet one by turns (the author: "on B, even without the developer mode; we'll take
-- it away later"). A click or a key cuts it short. He is dressed for the next one in advance - with
-- the bite under the sleeve or without - so the room isn't dressed anew in sight.
local EYES_UP, EYES_AHEAD = 1.40, -0.32   -- the camera in his body, units: behind him (KnoxBite.EYE_Y, EYE_Z)
local EYES_SEAT = {amb = 0.12, sky = 0.8, head = 1.37}
local EYES_EVERY_MIN, EYES_EVERY_MAX = 240, 480   -- s between the looks
local EYES_STILL = 15                    -- s the mouse has been still
local EYES_BITE = 65                     -- % of them a bite

function B:addEyes()
    self.eyes = nil
    self.lookHeld = false
    if not (knoxBiteStart and knoxBiteDress and knoxBiteHold) then return end
    knoxBiteStop()
    local j = self.scene.javaObject
    local c = {id = "kb_eyes", x = 0, y = 0, z = 0, face = 0, s = 0.001, anim = "knoxmenu_stand", lightK = 1,
        clothesOk = true, seat = {s = EYES_SEAT}}
    c.yaw = self:yawOf(c.face)
    local ok = pcall(function()
        j:fromLua1("createCharacter", c.id)
        j:fromLua2("setCharacterClearDepthBuffer", c.id, self.cfg.clearDepth)
    end)
    if not ok then return end
    knoxMenuAnim(j, c.id, c.anim)
    self:place(c)
    self.eyes = c
end

-- The walk about the room in the first person (the author, 2026-11-04): W, A, S or D in the menu,
-- no hint anywhere, Esc back. The body, the mouse and the camera are the Java part's (KnoxBarWalk).
-- [ ] choose one of its numbers, - = change it: a plate says which, the numbers are kept.
local WALK_ON = false               -- parked by the author 2026-11-04, W A S D do nothing; true brings it back
local WALK_FILE = "knox_bar_walk.txt"
local WALK_PLATE_FOR = 6            -- seconds it stays after the last key
local walkPlateR = {0, 0, 0, 0}
local walkPlateOpts = {}

local function walkLoad()
    local r = getFileReader(WALK_FILE, false)
    if not r then return end
    local line = r:readLine()
    while line do
        local i, v = string.match(line, "^(%d+)=(.+)$")
        if i and tonumber(v) then knoxBarWalkTuneSet(tonumber(i), tonumber(v)) end
        line = r:readLine()
    end
    r:close()
end

local function walkSave()
    local w = getFileWriter(WALK_FILE, true, false)
    if not w then return end
    for i = 0, knoxBarWalkTunes() - 1 do w:write(i .. "=" .. knoxBarWalkTune(i) .. "\r\n") end
    w:close()
end

--- Nothing in the way of it: as for H (and no typing, no card, no look at the arm, no dialog).
function B:walkFree()
    if self.mode ~= "idle" or self.frames <= 3 or self.ctxMenu or self.tuning or self.switchK or self.swipeIn then return false end
    if not self:campShown() or (self.eyes and self.eyes.busy) or UIManager.isModalVisible() then return false end
    if isKeyDown(Keyboard.KEY_LMENU) or isKeyDown(Keyboard.KEY_RMENU) or isKeyDown(Keyboard.KEY_LSHIFT)
        or isKeyDown(Keyboard.KEY_RSHIFT) or isKeyDown(Keyboard.KEY_LCONTROL) or isKeyDown(Keyboard.KEY_RCONTROL) then return false end
    if (KnoxMenuKeep and KnoxMenuKeep.drag) or (KnoxBagCard and KnoxBagCard.isUp()) then return false end
    if KnoxMenuNewsReader and KnoxMenuNewsReader.instance then return false end
    if (KnoxSettings and KnoxSettings.instance) or (KnoxEditor and KnoxEditor.instance) then return false end
    if KnoxMenuScene.uiHidden then return true end
    local main = MainScreen.instance
    return main ~= nil and not main.inGame and main.bottomPanel ~= nil and main:getIsVisible() and main.bottomPanel:getIsVisible()
end

--- Over, or cut short: the menu as it was before.
function B:walkOff()
    if not self.walking then return end
    self.walking = false
    self.viewFov = nil
    self.walkPlate = nil
    KnoxMenuScene.uiHidden = self.walkHidWas
    if self.scene and self.scene.javaObject then knoxBarWalkStop(self.scene.javaObject) end
end

--- [ ] and - = while walking: the numbers tuned on the spot.
function B:walkTuneKeys()
    local l, r, m, p = isKeyDown(Keyboard.KEY_LBRACKET) == true, isKeyDown(Keyboard.KEY_RBRACKET) == true,
        isKeyDown(Keyboard.KEY_MINUS) == true, isKeyDown(Keyboard.KEY_EQUALS) == true
    local move = (l and not self.walkL) and -1 or (r and not self.walkR) and 1 or 0
    local by = (m and not self.walkM) and -1 or (p and not self.walkP) and 1 or 0
    self.walkL, self.walkR, self.walkM, self.walkP = l, r, m, p
    if move == 0 and by == 0 then return end
    self.walkTuned = ((self.walkTuned or 0) + move) % knoxBarWalkTunes()
    if by ~= 0 then
        knoxBarWalkTuneBy(self.walkTuned, by)
        walkSave()
    end
    local v = math.floor(knoxBarWalkTune(self.walkTuned) * 10000 + 0.5) / 10000
    self.walkPlate = knoxBarWalkTuneName(self.walkTuned) .. "  " .. v
    self.walkPlateUntil = self.clock + WALK_PLATE_FOR
    walkPlateR[3] = T.plateW(self.walkPlate)
    walkPlateR[4] = T.fontH(T.fontCaps) + 8
end

--- The menu's view as it is now; true while the walk has the camera (then knoxBarWalkView has it).
function B:updateWalk(ex, ey, ez, tx, ty, tz)
    if not WALK_ON then return false end
    if not self.walking then
        local down = isKeyDown(Keyboard.KEY_W) == true or isKeyDown(Keyboard.KEY_A) == true
            or isKeyDown(Keyboard.KEY_S) == true or isKeyDown(Keyboard.KEY_D) == true
        local press = down and not self.walkKeyWas
        self.walkKeyWas = down
        if not press or not self:walkFree() then return false end
        walkLoad()
        knoxBarWalkStart(ex, ey, ez, tx, ty, tz)
        self.walking = true
        self.walkHidWas = KnoxMenuScene.uiHidden
        KnoxMenuScene.uiHidden = true
    end
    local esc = isKeyDown(Keyboard.KEY_ESCAPE) == true
    if esc and not self.walkEscWas then knoxBarWalkLeave() end
    self.walkEscWas = esc
    self:walkTuneKeys()
    if knoxBarWalkStep(self.scene.javaObject, self.cfg.fov, ex, ey, ez, tx, ty, tz, not T.animOn()) then
        self.viewFov = knoxBarWalkView(9)
        return true
    end
    self:walkOff()
    return false
end

function B:updateEyes(t)
    local c = self.eyes
    if not c then return end
    local j = self.scene.javaObject
    if not c.dressed then
        -- (the game's wardrobe read first, as the dead's)
        if knoxBarClothesLoaded() or t > DEAD_GIVE_UP then
            c.nextBite = ZombRand(100) < EYES_BITE
            c.dressed = knoxBiteDress(j, c.id, c.nextBite)
            c.holdUntil = t + 0.8
            c.nextAt = t + EYES_EVERY_MIN + ZombRandFloat(0, EYES_EVERY_MAX - EYES_EVERY_MIN)
        end
        return
    end
    if not c.posedAt then self:watchPose(c, t) end
    if c.posedAt and not c.held then c.held = knoxBiteHold(j, c.id) end
    if c.wasBusy and not c.busy then
        -- (over: dressed for the next one while he can't be seen)
        c.nextBite = c.byKey and not c.bitten or not c.byKey and ZombRand(100) < EYES_BITE
        knoxBiteDress(j, c.id, c.nextBite)
        knoxMenuAnim(j, c.id, c.anim)
        c.held = false
        c.nextAt = t + EYES_EVERY_MIN + ZombRandFloat(0, EYES_EVERY_MAX - EYES_EVERY_MIN)
    end
    c.wasBusy = c.busy
    local mx, my = getMouseX(), getMouseY()
    if mx ~= c.mouseX or my ~= c.mouseY then
        c.mouseX, c.mouseY, c.stillSince = mx, my, t
    end
    local down = isKeyDown(Keyboard.KEY_B) == true
    local press = down and not c.bWas
    c.bWas = down
    local free = c.posedAt and self.mode == "idle" and not self.ctxMenu and not self.tuning and not self.switchK and not self.walking
    if c.busy then
        if not c.hurried and (not free or isMouseButtonDown(0) or isMouseButtonDown(1) or isKeyDown(Keyboard.KEY_TAB)
            or isKeyDown(Keyboard.KEY_ESCAPE)) then
            c.hurried = true
            knoxBiteHurry()
        end
    elseif free and (press or not self.hover and t >= c.nextAt and t - (c.stillSince or t) >= EYES_STILL) then
        c.byKey = press
        c.bitten = c.nextBite == true
        c.hurried = false
        c.busy = knoxBiteStart(j, c.id, c.bitten) == true
        c.wasBusy = c.busy
    end
    self.lookHeld = c.busy == true
end

--- The view as his head has it (M:updateCamera): he stands with his eyes at the camera, facing its
--- way; his head bows and turns from there, the eye going round his neck.
function B:viewOffset(ex, ey, ez, tx, ty, tz, dt)
    if self:updateWalk(ex, ey, ez, tx, ty, tz) then
        return knoxBarWalkView(0), knoxBarWalkView(1), knoxBarWalkView(2), knoxBarWalkView(3), knoxBarWalkView(4), knoxBarWalkView(5)
    end
    local c = self.eyes
    if not (c and c.busy) then return ex, ey, ez, tx, ty, tz end
    local dx, dy, dz = tx - ex, ty - ey, tz - ez
    local face = math.atan2(dx, dz)
    local rest = math.deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz)))
    local pitch = knoxBiteFrame(dt, rest)
    local yaw = knoxBiteYaw()
    local up, ahead, left = knoxBiteEyeUp(), knoxBiteEyeAhead(), knoxBiteEyeLeft()
    c.busy = knoxBiteBusy()
    -- (his front is (sin, cos) of his face, his left (cos, -sin): KnoxBarLua.bone)
    local sf, cf = math.sin(face), math.cos(face)
    c.x, c.y, c.z = ex - EYES_AHEAD * sf, ey - EYES_UP, ez - EYES_AHEAD * cf
    c.faceNow = math.deg(face)
    c.yaw = self:yawOf(c.faceNow)
    c.s = c.busy and 1 or 0.001
    self:place(c)
    self:lightCharacter(c, 1)
    if not c.busy then return ex, ey, ez, tx, ty, tz end
    local nx, ny, nz = ex + ahead * sf + left * cf, ey + up, ez + ahead * cf - left * sf
    local p, a = math.rad(rest + pitch), face + math.rad(yaw)
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    local cp = math.cos(p)
    return nx, ny, nz, nx + cp * math.sin(a) * dist, ny + math.sin(p) * dist, nz + cp * math.cos(a) * dist
end

--- For the frame, each frame: the heroes' shadows from their bones, the ember in the smoker's
--- hand (and how hard it draws: its light on the face), the door.
function B:updateHeroes()
    self:updateDead()
    self:updateEyes(self.clock)
    local j = self.scene.javaObject
    for slot = 1, #SEATS do
        local c = self.heroAt and self.heroAt[slot]
        if c and c.shownAt then
            local face = c.faceNow or c.face
            knoxBarHero(j, c.id, slot - 1, c.x, c.y or 0, c.z, face, c.pack)
            if c.hand then c.emberGlow = knoxBarEmber(j, c.id, c.x, c.y or 0, c.z, face, c.lightK or 0) end
        else
            knoxBarHero(j, nil, slot - 1, 0, 0, 0, 0, false)
        end
    end
    knoxBarDoor(self.doorOpen or 0)
end

-- The bar's sounds (stage 6, the author 2026-10-31): the storm and the door are the Java part's
-- (KnoxBarSound), going with the frame; once a hero has gone they die out over the loading screen
-- (KnoxCamp, as the camp's). The dead out in the storm moan now and then, muffled. The game's
-- own menu ambience is kept quiet, as under the camp.
local MOAN_MIN, MOAN_MAX = 25, 70

function B:updateSounds(t)
    if not self.ambienceMuted then
        self.ambienceMuted = true
        if knoxMenuMuteAmbience then knoxMenuMuteAmbience(true) end
    end
    if self.mode == "launched" then
        knoxCampTick()
        return
    end
    -- (as the frame comes up out of the dark: B:drawFx)
    if self.frames < 3 then return end
    knoxBarSounds()
    local at = self.moanAt
    if at and t >= at then knoxCampMoan(ZombRand(2) == 0, 1) end
    if not at or t >= at then self.moanAt = t + MOAN_MIN + ZombRandFloat(0, MOAN_MAX - MOAN_MIN) end
end

-- The radio's card comes up over the broken radio (kb_radio: what is left of its case stands to
-- the right of its place, the smashed half and the speaker torn out to the left).
local RADIO_X, RADIO_Y, RADIO_Z = -2.315 * U, 1.1 * U, 0.82 * U
local METRE_UP = 0.3 * U
function B:radioRect()
    local r = self.radioBox
    -- (asked for each hero under the mouse: once a frame)
    if r and self.radioAt == self.frames then return r end
    local bx, by = self:toScreen(RADIO_X, RADIO_Y, RADIO_Z)
    local _, ty = self:toScreen(RADIO_X, RADIO_Y + METRE_UP, RADIO_Z)
    local m = math.abs(by - ty) / 0.3
    if not r then
        r = {0, 0, 0, 0}
        self.radioBox = r
    end
    r[1], r[2], r[3], r[4] = bx - 0.175 * m, by - 0.24 * m, 0.375 * m, 0.30 * m
    self.radioAt = self.frames
    return r
end

-- The garland's switch, where it hangs (the prop kb_garland_switch; its case under the lead): a place
-- for the mouse bigger than it, it's far off. Never smaller than a mouse's aim.
local SWITCH_X, SWITCH_Y, SWITCH_Z = 2.4 * U, 1.85 * U, -7.9 * U
function B:switchRect()
    local r = self.switchBox
    if r and self.switchAt == self.frames then return r end
    local bx, by = self:toScreen(SWITCH_X, SWITCH_Y - 0.32 * U, SWITCH_Z)
    local _, ty = self:toScreen(SWITCH_X, SWITCH_Y - 0.32 * U + METRE_UP, SWITCH_Z)
    local m = math.abs(by - ty) / 0.3
    if not r then
        r = {0, 0, 0, 0}
        self.switchBox = r
    end
    local w, h = math.max(22, 0.2 * m), math.max(28, 0.3 * m)
    r[1], r[2], r[3], r[4] = bx - w / 2, by - h / 2, w, h
    self.switchAt = self.frames
    return r
end

--- The mouse on the switch, and a click on it? (KnoxMenuScene's clicks, a hero's are after it.)
function B:pressSwitch(clicked)
    local was = self.switchHover
    self.switchHover = false
    if self.mode ~= "idle" or self.frames <= 3 or self.tuning or not self.revealAt or not self:campShown()
        or not self:menuIdle() or self.ctxMenu or (KnoxMenuKeep and KnoxMenuKeep.drag) then
        if was and knoxBarSwitchLit then knoxBarSwitchLit(false) end
        return false
    end
    self.switchHover = T.inRect(getMouseX(), getMouseY(), self:switchRect())
    if self.switchHover ~= (was or false) and knoxBarSwitchLit then knoxBarSwitchLit(self.switchHover) end
    if not self.switchHover or not clicked then return false end
    garlandOn = not B.garlandSaved()
    if knoxBarGarland then knoxBarGarland(garlandOn, false) end
    getSoundManager():playUISound("KnoxGarlandSwitch")
    local w = getFileWriter(GARLAND_FILE, true, false)
    if w then
        w:write(garlandOn and "on" or "off")
        w:close()
    end
    return true
end

-- The journal for a new game on the counter (kb_journal): its own small place
-- for the mouse (QA, 2026-10-31: the camp's place of a hero at the stool took in the smoker's
-- table and the boarded window, and the glass lit up there).
local PINT_X, PINT_Y, PINT_Z = -2.86 * U, 1.1 * U, 0.68 * U
function B:glassRect()
    local r = self.glassBox
    if r and self.glassAt == self.frames then return r end
    local bx, by = self:toScreen(PINT_X, PINT_Y, PINT_Z)
    local _, ty = self:toScreen(PINT_X, PINT_Y + METRE_UP, PINT_Z)
    local m = math.abs(by - ty) / 0.3
    if not r then
        r = {0, 0, 0, 0}
        self.glassBox = r
    end
    r[1], r[2], r[3], r[4] = bx - 0.26 * m, by - 0.13 * m, 0.52 * m, 0.24 * m
    self.glassAt = self.frames
    return r
end

--- The empty stool's place on the screen is its glass: its card comes up over the glass, not
--- over a hero's height at the stool (QA, 2026-10-31: it hung over the smoker's head).
function B:rectOf(c)
    if c.empty then
        local r = self:glassRect()
        return r, r[3] / 0.26 / U
    end
    if c.sheet then
        -- (a sheet of the missing: asked for each under the mouse, once a frame)
        local r = c.box
        if r and c.boxAt == self.frames then return r, c.boxPpu end
        local bx, by = self:toScreen(c.wx * U, c.wy * U, c.wz * U)
        local _, ty = self:toScreen(c.wx * U, (c.wy * U) + METRE_UP, c.wz * U)
        local m = math.abs(by - ty) / 0.3
        if not r then
            r = {0, 0, 0, 0}
            c.box = r
        end
        r[1], r[2], r[3], r[4] = bx - SHEET_W / 2 * m, by - SHEET_H / 2 * m, SHEET_W * m, SHEET_H * m
        c.boxAt, c.boxPpu = self.frames, m / U
        return r, c.boxPpu
    end
    local from = c.seat and c.seat.s.hitFrom
    if from then
        local bx, by = self:toScreen(c.x, from, c.z)
        local _, ty = self:toScreen(c.x, c.height, c.z)
        local ppu = math.abs(by - ty) / (c.height - from)
        local hw = (c.halfWidth or 0.42) * ppu
        return {bx - hw, ty - 0.08 * ppu, hw * 2, (by - ty) + 0.12 * ppu}, ppu
    end
    return KnoxMenuScene.rectOf(self, c)
end

--- The hero on the stool stands behind the radio from here (QA, 2026-10-31: 96% of it under his
--- shape, and a hero under the mouse keeps the radio's card down): where the radio is, it's the radio.
function B:hit(c, mx, my)
    if T.inRect(mx, my, self:radioRect()) or T.inRect(mx, my, self:switchRect()) then return false end
    if c.empty then return T.inRect(mx, my, self:glassRect()) end
    if c.sheet then return T.inRect(mx, my, (self:rectOf(c))) end
    return KnoxMenuScene.hit(self, c, mx, my)
end

-- (stage 7, 2026-10-31) The glass, the radio and a hero's bag under the mouse: a soft light, cold
-- as the room (the camp's is sand, by its fire; here only the ember is warm). A hero's is his own:
-- lightCharacter. (The bag's as the camp's drawFx has it, which the bar's own drawFx stands in
-- for - QA, 2026-11-01.)
local POINTED = {0.55, 0.72, 0.85}
local POINTED_ALPHA = 0.16

function B:drawPointed(el)
    local cx, cy, size
    local h = self.hover
    if h and h.empty then
        local r = self:glassRect()
        cx, cy, size = r[1] + r[3] / 2, r[2] + r[4] / 2, r[3] * 2.7
    elseif h and h.sheet then
        local r = self:rectOf(h)
        cx, cy, size = r[1] + r[3] / 2, r[2] + r[4] / 2, r[4] * 2
    elseif self.radioHover or (KnoxRadioCard and KnoxRadioCard.instance and KnoxRadioCard.instance:getIsVisible()) then
        -- (over the middle of what is left of its case, the right of its place: the author, 2026-11-01)
        local r = self:radioRect()
        cx, cy, size = r[1] + r[3] * 0.653, r[2] + r[4] / 2, r[3] * 1.4
    end
    if cx then
        el:drawTextureScaled(self.tex.glow, cx - size / 2, cy - size / 2, size, size, POINTED_ALPHA, POINTED[1], POINTED[2], POINTED[3])
    end
    -- (far off and small: its own, stronger and warm, or nobody sees it - the author's screenshot, 2026-11-02)
    if self.switchHover then
        local r = self:switchRect()
        size = r[4] * 3.4
        el:drawTextureScaled(self.tex.glow, r[1] + r[3] / 2 - size / 2, r[2] + r[4] / 2 - size / 2, size, size, 0.55, 1.0, 0.72, 0.42)
    end
    local bag = self.keepToBag or self.bagHover or (KnoxBagCard and KnoxBagCard.isUp() and self.bagShown) or nil
    if bag and bag.bagAt then
        local r = self:bagRect(bag)
        size = r[3] * 1.6
        el:drawTextureScaled(self.tex.glow, r[1] + r[3] / 2 - size / 2, r[2] + r[4] / 2 - size / 2, size, size,
            POINTED_ALPHA, POINTED[1], POINTED[2], POINTED[3])
    end
end

-- The bar stalls now and then for a second (the author, 2026-11-02): no Lua and no UI in those
-- frames (knox_perf.txt), so something the game loads. A frame longer than STALL_MS says in
-- console.txt what the bar did before it, to find which of its doings it is.
local STALL_MS = 250

local function ago(now, at)
    return at and string.format("%.1f s ago", (now - at) / 1000) or "not yet"
end

function B:watchStall()
    local now = getTimestampMs()
    local last = self.stallLast
    self.stallLast = now
    if not last or now - last <= STALL_MS then return end
    print(string.format("[Knox] menu scene (bar): a frame of %d ms at %.0f s; before it: one of the dead dressed %s (%s), shown %s; a photo begun %s, taken %s",
        now - last, self.clock or 0, ago(now, self.dressMs), tostring(self.dressId), ago(now, self.shownMs),
        ago(now, self.photoMs), ago(now, self.photoTakenMs)))
end

--- The frame opens: the heroes the scene draws next land in it. The room, the sky and all
--- the rest are the frame's (KnoxBarFrame). A video card that can't do it: back to the camp,
--- for good (till the game is restarted), built anew outside of drawing.
function B:drawBackdrop()
    knoxMenuResetGL()
    if knoxBarFailed() and not self.goingBack then
        self.goingBack = true
        KnoxMenuScene.barFailed = true
        print("[Knox] menu scene (bar): its frame failed, back to the camp")
        local again
        again = function()
            Events.OnPreUIDraw.Remove(again)
            if KnoxMenuScene.instance == self and knoxMenuInMenu() then KnoxMenuScene.create() end
        end
        Events.OnPreUIDraw.Add(again)
    end
    -- Continue, Load, a new game (QA, 2026-10-31): the game fades the menu out over at least
    -- 250 ms (MainScreenState.exit), then no more frames till the save is in. So the targets go
    -- near the end of the fade, about 12% of the picture left, by the clock: a long frame's dt
    -- is clamped. The heroes go with them, or they'd stand on black.
    if not knoxMenuInMenu() then
        local now = getTimestampMs()
        self.stallLast = nil
        self.outSince = self.outSince or now
        if now - self.outSince > 220 then
            self:restWhileLoading()
            if not self.sceneHidden then
                self.sceneHidden = true
                self.scene:setVisible(false)
            end
            self:drawRect(0, 0, self.width, self.height, 1, 0, 0, 0)
            return
        end
    elseif self.outSince then
        self.outSince = nil
        if self.sceneHidden then
            self.sceneHidden = false
            self.scene:setVisible(true)
        end
    end
    if self.frames < 3 then
        self:drawRect(0, 0, self.width, self.height, 1, 0, 0, 0)
        return   -- the camera exists after the first frame
    end
    self.resting = false
    self.frameOpen = true
    self:watchStall()
    self:updateHeroes()
    self:updatePhotos()
    knoxBarQuality(T.switch("barHigh"))
    knoxBarBegin()
end

--- The frame's big targets are not kept through the save's loading (QA, 2026-10-31: ~600 MB
--- at 4K, just when the game loads its own); the next frame builds them anew.
function B:restWhileLoading()
    self:walkOff()
    if self.resting then return end
    self.resting = true
    knoxBarRest()
end

-- The depth of field (the author, 2026-11-03: "при наведении на персонажей ... и к сцене в
-- принципе, там, где это логично"): a hero under the mouse in focus, the room before and behind
-- him soft - so too the glass, the radio, the garland's switch, a bag; the narrator's arm before
-- his eyes while he looks at it (the frame focuses on what is at the middle of the view, as an
-- eye would). Eased in and out; the frame eases the focus itself (KnoxBarFrame.focus).
local FOCUS_IN, FOCUS_OUT = 3.0, 2.2          -- 1/s
local FOCUS_BAND, FOCUS_BAND_ARM = 0.12, 0.35 -- how far off the focus stays sharp: a hero's own depth; an arm's

--- What the eye is on: a place in the scene (scene units) and the sharp band; "arm": the narrator's
--- own arm (the frame finds it at the middle of the view); nil: nothing to focus on. Its place, not
--- its point on the screen: that may fall past it, on the far wall (the author, 2026-11-03: the one
--- asleep at the counter stayed soft).
function B:focusPoint()
    local eyes = self.eyes
    if eyes and eyes.busy then return "arm" end
    if self.mode ~= "idle" or self.ctxMenu or self.tuning then return nil end
    local c = self.hover
    if c and c.empty then return PINT_X, PINT_Y, PINT_Z end
    if c and c.sheet then return c.wx * U, c.wy * U, c.wz * U end
    if c then
        -- a hero: his chest and face, not the floor between his feet
        local from = c.seat and c.seat.s.hitFrom or 0
        return c.x, from + (c.height - from) * 0.7, c.z
    end
    if self.radioHover then return RADIO_X, RADIO_Y, RADIO_Z end
    if self.switchHover then return SWITCH_X, SWITCH_Y - 0.32 * U, SWITCH_Z end
    local bag = self.bagHover
    if bag and bag.bagAt then return bag.bagAt.x, bag.bagAt.y + 0.12, bag.bagAt.z end
    return nil
end

function B:updateFocus()
    if not knoxBarFocus then return end
    local now = self.clock or 0
    local dt = math.max(0, math.min(0.1, now - (self.focusAt or now)))
    self.focusAt = now
    local x, y, z = self:focusPoint()
    local want = x and 1 or 0
    if x == "arm" then
        self.focusU, self.focusV, self.focusDepth, self.focusBand = 0.5, 0.5, 0, FOCUS_BAND_ARM
    elseif x and self.camEX then
        -- how far ahead along the view (the frame's depth is that, not the straight distance)
        local fx, fy, fz = self.camTX - self.camEX, self.camTY - self.camEY, self.camTZ - self.camEZ
        local len = math.sqrt(fx * fx + fy * fy + fz * fz)
        if len > 0 then
            self.focusDepth = math.max(0.05, ((x - self.camEX) * fx + (y - self.camEY) * fy + (z - self.camEZ) * fz) / len)
            self.focusU, self.focusV, self.focusBand = 0.5, 0.5, FOCUS_BAND
        end
    end
    local p = self.focusPower or 0
    if not T.animOn() then
        p = want
    elseif want > p then
        p = math.min(want, p + dt * FOCUS_IN)
    else
        p = math.max(want, p - dt * FOCUS_OUT)
    end
    self.focusPower = p
    -- (going out, it stays where it was)
    knoxBarFocus(self.focusU or 0.5, self.focusV or 0.5, p * p * (3 - 2 * p), self.focusBand or FOCUS_BAND, self.focusDepth or 0)
end

--- The frame closes and goes on the screen; over it the waking out of the dark in the first
--- seconds, as the camp does, and the switch to the camp.
function B:drawFx(el)
    if self.frameOpen then
        self.frameOpen = false
        self:updateFocus()
        -- (animations off: the snow and the wind stand)
        knoxBarEnd(self.scene.javaObject, T.animOn())
    end
    knoxMenuResetGL()
    if self.frames < 3 then
        el:drawRect(0, 0, el.width, el.height, 1, 0, 0, 0)
        self:drawSwitch(el)
        return
    end
    self:drawPointed(el)
    local wake = 1 - math.min(1, math.max(0, (self.clock - 0.4) / 1.6))
    if wake > 0 and not self.swiped then el:drawRect(0, 0, el.width, el.height, wake, 0, 0, 0) end
    if self.walking then
        -- (a long way back to the menu's place: through the dark, not through the counter)
        local dark = knoxBarWalkDark()
        if dark > 0 then el:drawRect(0, 0, el.width, el.height, dark, 0, 0, 0) end
        if self.walkPlate and self.clock < self.walkPlateUntil then
            walkPlateR[1], walkPlateR[2] = math.floor((el.width - walkPlateR[3]) / 2), math.floor(el.height * 0.08)
            walkPlateOpts.fill, walkPlateOpts.edge = T.color.screen, T.color.tileEdge
            T.plate(el, walkPlateR, self.walkPlate, walkPlateOpts)
        end
    end
    self:drawSwitch(el)
end
