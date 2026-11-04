package knox.java;

import java.util.Locale;

import org.joml.Matrix4f;
import org.joml.Vector3f;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.asset.AssetPath;
import zombie.core.skinnedmodel.ModelManager;
import zombie.core.skinnedmodel.model.MeshAssetManager;
import zombie.core.skinnedmodel.model.Model;
import zombie.core.skinnedmodel.model.ModelMesh;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.ModelScript;

/**
 * Exact bounds of item models for the Knox inspect window.
 *
 * The game's UI3DScene draws a model with
 *   objectTransform * transpose(mesh.transform) * scale(modelScript.scale)
 * (UI3DScene.ModelRenderData.initModel, without the world attachment), so the
 * mesh's own bounds (ModelMesh.minXyz / maxXyz) pushed through the last two
 * give the model's box in the scene object's space - what the window needs to
 * center it and fit it to the view.
 */
public class KnoxModels {

    /**
     * Box of a model script's model in scene object space, as
     * "minX,minY,minZ,maxX,maxY,maxZ"; nil while the model is still loading
     * (call again next frame) or when it is unknown.
     */
    @LuaMethod(name = "knoxModelBounds", global = true)
    public static String knoxModelBounds(String modelScriptName) {
        if (modelScriptName == null) return null;
        ModelScript script = ScriptManager.instance.getModelScript(modelScriptName);
        if (script == null) return null;
        Model model = ModelManager.instance.getLoadedModel(modelScriptName);
        if (model == null || !model.isReady()) return null;
        ModelMesh mesh = model.mesh;
        if (mesh == null || !mesh.isReady()) return null;
        Vector3f lo = mesh.minXyz;
        Vector3f hi = mesh.maxXyz;
        if (lo.equals(hi)) return null;

        Matrix4f m = new Matrix4f();
        if (mesh.transform != null) {
            m.set(mesh.transform);
            m.transpose();
        }
        if (script.scale != 1.0f) m.scale(script.scale);

        float[] min = {Float.MAX_VALUE, Float.MAX_VALUE, Float.MAX_VALUE};
        float[] max = {-Float.MAX_VALUE, -Float.MAX_VALUE, -Float.MAX_VALUE};
        Vector3f p = new Vector3f();
        for (int i = 0; i < 8; i++) {
            p.set((i & 1) == 0 ? lo.x : hi.x, (i & 2) == 0 ? lo.y : hi.y, (i & 4) == 0 ? lo.z : hi.z);
            m.transformPosition(p);
            min[0] = Math.min(min[0], p.x); max[0] = Math.max(max[0], p.x);
            min[1] = Math.min(min[1], p.y); max[1] = Math.max(max[1], p.y);
            min[2] = Math.min(min[2], p.z); max[2] = Math.max(max[2], p.z);
        }
        return String.format(Locale.ROOT, "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f",
            min[0], min[1], min[2], max[0], max[1], max[2]);
    }

    /**
     * Size of a static model script's model, for measuring every item of the game
     * (the DEV panel's "Measure items": item footprints are worked out from real
     * sizes). Only the mesh is asked for - no texture, no shader - with the very
     * parameters the game loads a static model's mesh with, so the cached mesh is
     * the one the game would have made itself.
     *
     * "dx,dy,dz,scale": the box's sides after the mesh's own transform and the
     * script's scale; "loading": asked for, not read yet (call again);
     * nil: no such script, not a static model, or the mesh failed to load.
     */
    @LuaMethod(name = "knoxMeasureModel", global = true)
    public static String knoxMeasureModel(String modelScriptName) {
        if (modelScriptName == null) return null;
        try {
            ModelScript script = ScriptManager.instance.getModelScript(modelScriptName);
            if (script == null || !script.isStatic) return null;
            String meshName = script.getMeshName();
            if (meshName == null || meshName.isEmpty()) return null;
            ModelMesh.MeshAssetParams params = new ModelMesh.MeshAssetParams();
            params.isStatic = true;
            params.animationsMesh = null;
            params.postProcess = script.postProcess;
            ModelMesh mesh = (ModelMesh) MeshAssetManager.instance.load(new AssetPath(meshName), params);
            if (mesh == null || mesh.isFailure()) return null;
            if (!mesh.isReady()) return "loading";
            Vector3f lo = mesh.minXyz;
            Vector3f hi = mesh.maxXyz;
            if (lo.equals(hi)) return null;
            Matrix4f m = new Matrix4f();
            if (mesh.transform != null) {
                m.set(mesh.transform);
                m.transpose();
            }
            float[] min = {Float.MAX_VALUE, Float.MAX_VALUE, Float.MAX_VALUE};
            float[] max = {-Float.MAX_VALUE, -Float.MAX_VALUE, -Float.MAX_VALUE};
            Vector3f p = new Vector3f();
            for (int i = 0; i < 8; i++) {
                p.set((i & 1) == 0 ? lo.x : hi.x, (i & 2) == 0 ? lo.y : hi.y, (i & 4) == 0 ? lo.z : hi.z);
                m.transformPosition(p);
                min[0] = Math.min(min[0], p.x); max[0] = Math.max(max[0], p.x);
                min[1] = Math.min(min[1], p.y); max[1] = Math.max(max[1], p.y);
                min[2] = Math.min(min[2], p.z); max[2] = Math.max(max[2], p.z);
            }
            float s = script.scale;
            return String.format(Locale.ROOT, "%.5f,%.5f,%.5f,%.4f",
                (max[0] - min[0]) * s, (max[1] - min[1]) * s, (max[2] - min[2]) * s, s);
        } catch (RuntimeException | LinkageError e) {
            return null;
        }
    }

    /** Version of the Java part, for the Lua side to check it is loaded. */
    @LuaMethod(name = "knoxJavaVersion", global = true)
    public static String knoxJavaVersion() {
        return "130";   // 130: the walk about the bar in the first person (KnoxBarWalk, KnoxBarWalkLua: knoxBarWalk*; the camera's up; the author, 2026-11-04); 129: the narrator's sleeve tops kept out of the view while the arms hang (KnoxBite.tuck), his right forearm turns the hand to the sleeve (the wrist was wrung; the author's screenshots, 2026-11-04); 128: the narrator's elbows opened to 150 degrees at least by the upper arms alone, in the arm's own bend (KnoxBite.openElbow, the author's pick from pictures, 2026-11-04); 127: the upper arms swung to a fixed place out of the view (the elbow bent the wrong way); 126: the joints below the view (gone: the forearms went another way); 125: the narrator's shoulders went with his arms (the collarbones turned; the jacket's tops all on the upper arms - the author's video, 2026-11-04); 124: the narrator after the author's video (2026-11-03, jar 123) - his shoulders closed (the jacket's cut tops and waist capped, the body's waist below it: holes), the left elbow on four helpers (the dress's bones: KnoxBite.elbows, tools/bite/slim_arms.py bend_weights - it narrowed and the skin came through as the forearm turned), the skin as fine as the jacket so they bend as one; the bar's depth of field a half as strong, its focus on what the mouse is over by its distance (knoxBarFocus with depth; the sleeper was not in focus), the camera after the look back to where it was (the look's eased target held); 123: the narrator after the author's video (2026-11-03) - his own body with slimmer arms, the chest cut away (KnoxBite.body: Knox_NarratorBody, tools/bite/slim_arms.py), the skin always the lightest, the plain jacket burgundy and laid evenly over the arm (Knox_JacketRolled), the hands smaller still, the right hand over the sleeve as thick as it is there (KnoxBite.SLEEVE_R); the bar's depth of field (KnoxBarFrame.focus: focus.frag, dof.frag; knoxBarFocus); 122: the narrator's arms no longer narrowed (odd at the joints), his hands smaller instead (KnoxBite.HANDS; the author, 2026-11-02: giant palms), the round jacket's sleeve rolls without turning inside out (tools/bite/roll_sleeve.py build_round; the author's screenshots: holes); 121: the narrator's right hand lets go of the sleeve towards him and down, its shape kept a while (it stood up on end - the author's video, 2026-11-02); his arms narrowed across (KnoxBite.slim), his jacket made round (tools/bite/smooth_mesh.py: the author, "strange, angular, very bulky"); 120: the narrator's arms after the author's video (2026-11-02) - the left forearm low and near level for the sleeve, the right hand onto it from below, along it, the wrist near straight (no cross, no hand bent down), off the sleeve before it goes down and the left arm down before it comes again (never through the arm); the bite his own wound on the inside of the forearm near the wrist (Knox_BiteLForearm: the game's was under the rolled cuff, on the side turned away); 119: the narrator's sleeve rolls up and down with the hand (the game's padded jacket, its last rings on the props' bones: KnoxBite.sleeve; tools/bite/roll_sleeve.py), the bite the game's wound on the skin, the rustle and his breath, a look now and then of itself, cut short by a click (knoxBiteHold, knoxBiteHurry, knoxBiteDress with the bite; the author, 2026-11-02: "do the rest"); 118: the bar's narrator stands ahead of the camera, his chest, neck and head hidden, the arms kept (the author, 2026-11-02: the arms were very close); 117: the bar's camera is the eyes of the one in the room - he looks at his left forearm, rolls the sleeve, turns the arm (KnoxBite: knoxBiteDress, knoxBiteStart, knoxBiteFrame...; his arms in KnoxLook.Hook), the bar's near plane 0.1 (KnoxBarFrame.NEAR, the scene's by knoxBarEnd; the author, 2026-11-02); 116: the bar's garland sways in the draught - its swags out from the wall, the torn end and its switch, the halos and the light with them (SWAG; room.vert, shadow.vert: uSwag, uTail; the author, 2026-11-02); 115: the whiskey bottle knocked over already going (the sleeper's swat redone after the author's video, 2026-11-02); 114: the one asleep at the counter stirs with the mouse over him, swats the whiskey bottle off (BOTTLE, knoxBarBottleKnock, knoxBarBottleBreaks); the journal's pages half as loud (the author, 2026-11-02); 113: the pencil on the floor an Artlist recording, timed to it; 112: the wall of the missing - its sheets each on a pin in the wind (PINNED), the photos on them, the heading by hand (the author, 2026-11-02); 111: four page sounds, a shuffled round; 110: the journal's pages turn towards the right again, their sound two Artlist recordings timed to the page; 109: they turned the other way; 108: the light over the cigarette machine moved near the counter; 107: 106: the cigarette machine and its light; 105: the journal's page a real rustle, the pencil quieter; 104: the sounds of a journal's page and of the falling pencil; 103: warmer garland, its halos and shine, a pencil to fall, the seam a dissolve again; 102: the bar's garland and its switch; 101: the seam in shadow, no candles in the bar, the journal's pages turned by the wind; 100: the sound of a swipe, the places' sounds crossfaded, a wider seam; 99: the swipe's motion blur; 98: the swipe whichever scene the game draws first; 97: the swipe's seam narrow; 96: both scenes alive through a swipe, the bar's files read ahead; 95: the swipe's seam soft; 94: the menu's scenes change by a swipe, KnoxMenuSwipe (the author, 2026-11-02); 93: the bar: the open journal in place of the knife (the author, 2026-11-02); 92: the bar's hunting knife in place of the axe (the author, 2026-11-01); 91: the bar's axe is the game's fire axe (the author, 2026-11-01); 90: the bar: the axe in place of the beer, a whole new jukebox (the author, 2026-11-01); 89: the round tables' leg shade gone, a leg of the mod's own instead (MenuGen; the author, 2026-11-01); 88: the ember's light in the room a little less (the author, 2026-11-01); 87: the bar: the smoker's arms stay with his cigarette as the head turns, the radio's needle moves, the ember and its light (the author, 2026-11-01); 86: the dead outside: clothes in the game's order, no hoods up; the bar's radio: the crackle gone, the sputter back (the author, 2026-11-01); 85: the bar's radio: its faults rarer, the sputter gone (the author, 2026-11-01); 84: the bar's broken radio, a sound of its own (KnoxBarRadio; the author, 2026-11-01); 83: the bar: dead heroes' photos on the wall of the missing, the dead outside always random in winter clothes (the author, 2026-11-01); 82: ZombieBuddy's line and icon hidden with the menu by H (knoxMenuWatermark); the dead man's mesh gone from the bar (the author, 2026-11-01); 81: the winter bar - the game's zombies out in the storm (knoxBarDead, knoxBarClothesLoaded), a richer storm (KnoxBarSound: howl, creaks, the game's winter ambience), loops that cannot outlive a switch of scene (KnoxCamp.LOOPS_ON; the author, 2026-11-01); 80: the winter bar - the cigarette at its script's size, a candle by the hero at the counter (knoxBarCandle; the author, 2026-11-01); 79: the winter bar's sounds - the wind with the gusts, the door, steps on boards, the radio cutting out (KnoxBarSound: knoxBarSounds, knoxBarDoorOpens; the author, 2026-10-31); 78: the winter bar lives - the door in the wind, the driven snow, smoke, breath, loose sheets (KnoxBarLife; the author, 2026-10-31); 77: the winter bar's people (knoxBarHero, knoxBarEmber, knoxBarDoor, knoxBarHand, knoxBarHeroLights); 76: the winter bar in its own frame (KnoxBarFrame): real shadows, the air, the picture; 75: the winter bar lit for each pixel by its own shader (KnoxBarLight: knoxBarLights; the author, 2026-10-31), 74: the winter bar takes models of other mods, the game has no reader for their OBJ files (KnoxObj: knoxObjPrepare; the author, 2026-10-31), 73: the menu on R - the mouse held and the cursor hidden while it is open (knoxSetRMenuOpen), where a picture's pixels are (knoxTexInkX/Y); the hidden rounds - no count of rounds in a gun's or magazine's tooltip, the game's look or Knox's (knoxHideRounds, KnoxTooltipStyle.TipItem; the author, 2026-10-31), 72: a grid's quiet tile: its state is the category colour's height, no meters (condition_v3, the author, 2026-10-31), 71: the item tooltip fades in - its lines, bars and badges drawn in Java take knoxTooltipFade (the author, 2026-10-30), 70: Knox's crosshair panel takes the take key only with a row chosen (knoxVpPanelWants: else F held at a fence climbs it; the author, 2026-10-29), 69: Viewpoint's cursor mode asked (knoxViewpointCursorOn: turned off in the car, the radio's card folds away; the author, 2026-10-29), 68: Knox's crosshair panel follows what is done - Viewpoint's count of its gatherings of the actions (knoxVpPanelActionsVersion: "Turn on" became "Turn off"), anything the character finished makes it gather them anew (KnoxViewpoint.PanelActionsDone; the author, 2026-10-29), 67: a held item with a hand pose of its own (an anim mask: Tactical Flashlight Animation's flashlight) shows in the screen model's hand, as in the world (KnoxAvatar.staticModel; the author, 2026-10-29), 66: a ready list writes an item's icon whole (KnoxDrawList.ItemIcon: UIElement.DrawItemIcon, played back it reads the item again; the equipment slots, the author's FPS task 2026-10-29), 65: the ready lists reach Lua (KnoxDrawList had no public constructor without arguments - ZombieBuddy could not hand knoxList* to Lua, the author's run 2026-10-28), 64: ready lists - a part of a window drawn once from Lua, then again from Java while it looks the same (KnoxDrawList: knoxListBegin, knoxListEnd, knoxListDraw; the inventory's FPS, the author 2026-10-28), 63: Knox's Boosty page opened in the browser (KnoxLink: knoxOpenUrl - the game's openUrl drops any site but its own; the author, 2026-10-25), 62: the item editor's presets - their folder listed, a file taken away (KnoxPresetFiles: knoxPresetFiles, knoxPresetDelete; the author, 2026-10-25), 61: Knox's own crosshair panel in place of Viewpoint's (KnoxViewpoint.PanelDraw/PanelWheel/PanelKeys/PanelTake, knoxVpPanel*; the author, 2026-10-25), 60: KnoxDraw (v59: the dashboard drawn in one call) taken out again - measured in the game, it was no faster (the author, 2026-10-24), 58: Knox's own performance counter (KnoxPerf: knoxPerfNow, knoxPerfStats, knoxPerfHandlers - asked only while dev.perf=1), 57: fonts by style and size in arrays (KnoxFonts.font: no atlas name built per draw); the unused knoxMenuAct and knoxCampGameSound gone, 56: the car's muffle by how open the car is (knoxMusicMuffle(dark, open)), 55: own music heard from outside the car it plays in (knoxMusicMuffle, KnoxCarMuffle); the radio's air quiet while the track is paused, 54: Viewpoint - one look-up of its parts for KnoxCompat (knoxViewpointParts), the container of its loot panel's chosen row (knoxViewpointChosen), OldPoint's overhead camera (knoxViewpointTopDown) and its rotation key not held while a Knox window is open (KnoxViewpoint.OldPointRotation); the unused knoxViewpointPresent gone, 53: the volume patch's fields public (52 crashed the game at start: IllegalAccessError), 52: mods' menu music muted where the emitter takes its volume (KnoxMusic.ForeignVolume), 51: a hero's action layered over the sitting pose at the fire (knoxMenuAct), 50: the loading screen's letters set by the font's step (KnoxLoading.advance), 49: the health model's 3D skeleton - a broken part under the mouse see-through, its bone shown (KnoxHealthPaint), 48: the health model's skin painted on the GPU every frame (knoxHealthPaint, KnoxHealthPaint), 47: a bag's tooltip shows only what the search has found in it (knoxTooltipKnownOnly), 46: performance - tint hooks on a flag (KnoxTint.ARMED), Viewpoint panel rebuilt fast only while something is hidden, its fields looked up once, 45: performance - the look hook idle unless the menu looks (KnoxLook.ON, knoxMenuLookClear), snapshot files cached, 44: mods' own menu music under the radio (knoxMusicForeign), 43: keepsakes put down in the camp (knoxMenuGround), 42: cloth bags rustle (knoxCampSoundCut), a bag coloured once its clothing item is read, 41: a bag's sound through the game's own preview (GameSounds.previewSound), 40: the game's own sounds played in the menu (knoxCampGameSound: a bag's OpenSound / CloseSound), 39: heroes look up at the mouse (KnoxLook, patch of AnimationPlayer.applyBoneReParenting), 38: the bag at the fire gets its texture (knoxMenuBagSkin), 37: the hero's bag at the fire (knoxMenuSaveBag, knoxMenuBag, knoxMenuTakeOff), 36: clip stride by bone index, knoxMenuFootWhy, 35: walk speed measured on the feet (knoxMenuFootSpeed), 34: walk stride read from Bip01, 33: the dead walk at their clip's own stride (knoxMenuClipStride), their steps the hero's boots, 32: the dead quieter, their steps on grass, 31: the risen heroes' moans and steps (knoxCampMoan, knoxCampZombieStep), 30: snapshot v4 keeps the real worn items behind looks a mod fills in (Transmog), knoxMenuClothesSubstitute, 29: the menu waits for clothes the game cannot name yet, knoxMenuClothesNote, 28: the game's menu ambience muted under the camp (knoxMenuMuteAmbience), 27: Viewpoint's loot panel shows only what the search has found (KnoxViewpoint.PanelSeenOnly, knoxViewpointSearch), 26: the skin's palette for the tooltips and the loading screen (knoxSetPalette), 25: the quiet tiles of a grid drawn in one call (knoxDrawTiles: a floor of 270 things cost 1.5 ms a frame from Lua), 24: the menu scene's lights only while the main menu is up (sceneLive: blue-green vehicles on servers), 23: the menu's readiness and clip calls (knoxMenuHurryClips, knoxMenuWhy, knoxMenuReady...) and the jar of 0.9.6 - shipped with 22 by mistake, so new Lua took the jar of the morning's 0.9.5 for good and failed on the missing calls; raise this with EVERY change of the jar, 22: Viewpoint's cursor mode while a Knox window is open (knoxViewpointCursor), 2: fonts and item tooltips, 3: model mirrors the character, 4: tooltip header, 5: held bags on the model, 6: cursor, 7: font coverage, 8: screen counts as inventory, 9: device text (TV subtitles), 10: hide the open TV's text in the world, 11: radio text (items, cars), channel and time per line, 12: main menu scene (KnoxMenu), 13: the dead keep their clothes in the menu, game font while an atlas loads, 14: a Knox font for the game's text boxes (knoxFieldFont), 15: that font is an atlas of its own (the game destroys its table's fonts on reload), 16: the loading screen (KnoxLoading), 20: the inspect window's item color through UI3DScene.stateDataRender (knoxSceneTint), 21: knoxTextInk (where a text's pixels are, for centring)
    }
}
