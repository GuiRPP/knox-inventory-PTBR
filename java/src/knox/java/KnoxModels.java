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
        return "70";   // 70: Knox's crosshair panel takes the take key only with a row chosen (knoxVpPanelWants: else F held at a fence climbs it; the author, 2026-10-29), 69: Viewpoint's cursor mode asked (knoxViewpointCursorOn: turned off in the car, the radio's card folds away; the author, 2026-10-29), 68: Knox's crosshair panel follows what is done - Viewpoint's count of its gatherings of the actions (knoxVpPanelActionsVersion: "Turn on" became "Turn off"), anything the character finished makes it gather them anew (KnoxViewpoint.PanelActionsDone; the author, 2026-10-29), 67: a held item with a hand pose of its own (an anim mask: Tactical Flashlight Animation's flashlight) shows in the screen model's hand, as in the world (KnoxAvatar.staticModel; the author, 2026-10-29), 66: a ready list writes an item's icon whole (KnoxDrawList.ItemIcon: UIElement.DrawItemIcon, played back it reads the item again; the equipment slots, the author's FPS task 2026-10-29), 65: the ready lists reach Lua (KnoxDrawList had no public constructor without arguments - ZombieBuddy could not hand knoxList* to Lua, the author's run 2026-10-28), 64: ready lists - a part of a window drawn once from Lua, then again from Java while it looks the same (KnoxDrawList: knoxListBegin, knoxListEnd, knoxListDraw; the inventory's FPS, the author 2026-10-28), 63: Knox's Boosty page opened in the browser (KnoxLink: knoxOpenUrl - the game's openUrl drops any site but its own; the author, 2026-10-25), 62: the item editor's presets - their folder listed, a file taken away (KnoxPresetFiles: knoxPresetFiles, knoxPresetDelete; the author, 2026-10-25), 61: Knox's own crosshair panel in place of Viewpoint's (KnoxViewpoint.PanelDraw/PanelWheel/PanelKeys/PanelTake, knoxVpPanel*; the author, 2026-10-25), 60: KnoxDraw (v59: the dashboard drawn in one call) taken out again - measured in the game, it was no faster (the author, 2026-10-24), 58: Knox's own performance counter (KnoxPerf: knoxPerfNow, knoxPerfStats, knoxPerfHandlers - asked only while dev.perf=1), 57: fonts by style and size in arrays (KnoxFonts.font: no atlas name built per draw); the unused knoxMenuAct and knoxCampGameSound gone, 56: the car's muffle by how open the car is (knoxMusicMuffle(dark, open)), 55: own music heard from outside the car it plays in (knoxMusicMuffle, KnoxCarMuffle); the radio's air quiet while the track is paused, 54: Viewpoint - one look-up of its parts for KnoxCompat (knoxViewpointParts), the container of its loot panel's chosen row (knoxViewpointChosen), OldPoint's overhead camera (knoxViewpointTopDown) and its rotation key not held while a Knox window is open (KnoxViewpoint.OldPointRotation); the unused knoxViewpointPresent gone, 53: the volume patch's fields public (52 crashed the game at start: IllegalAccessError), 52: mods' menu music muted where the emitter takes its volume (KnoxMusic.ForeignVolume), 51: a hero's action layered over the sitting pose at the fire (knoxMenuAct), 50: the loading screen's letters set by the font's step (KnoxLoading.advance), 49: the health model's 3D skeleton - a broken part under the mouse see-through, its bone shown (KnoxHealthPaint), 48: the health model's skin painted on the GPU every frame (knoxHealthPaint, KnoxHealthPaint), 47: a bag's tooltip shows only what the search has found in it (knoxTooltipKnownOnly), 46: performance - tint hooks on a flag (KnoxTint.ARMED), Viewpoint panel rebuilt fast only while something is hidden, its fields looked up once, 45: performance - the look hook idle unless the menu looks (KnoxLook.ON, knoxMenuLookClear), snapshot files cached, 44: mods' own menu music under the radio (knoxMusicForeign), 43: keepsakes put down in the camp (knoxMenuGround), 42: cloth bags rustle (knoxCampSoundCut), a bag coloured once its clothing item is read, 41: a bag's sound through the game's own preview (GameSounds.previewSound), 40: the game's own sounds played in the menu (knoxCampGameSound: a bag's OpenSound / CloseSound), 39: heroes look up at the mouse (KnoxLook, patch of AnimationPlayer.applyBoneReParenting), 38: the bag at the fire gets its texture (knoxMenuBagSkin), 37: the hero's bag at the fire (knoxMenuSaveBag, knoxMenuBag, knoxMenuTakeOff), 36: clip stride by bone index, knoxMenuFootWhy, 35: walk speed measured on the feet (knoxMenuFootSpeed), 34: walk stride read from Bip01, 33: the dead walk at their clip's own stride (knoxMenuClipStride), their steps the hero's boots, 32: the dead quieter, their steps on grass, 31: the risen heroes' moans and steps (knoxCampMoan, knoxCampZombieStep), 30: snapshot v4 keeps the real worn items behind looks a mod fills in (Transmog), knoxMenuClothesSubstitute, 29: the menu waits for clothes the game cannot name yet, knoxMenuClothesNote, 28: the game's menu ambience muted under the camp (knoxMenuMuteAmbience), 27: Viewpoint's loot panel shows only what the search has found (KnoxViewpoint.PanelSeenOnly, knoxViewpointSearch), 26: the skin's palette for the tooltips and the loading screen (knoxSetPalette), 25: the quiet tiles of a grid drawn in one call (knoxDrawTiles: a floor of 270 things cost 1.5 ms a frame from Lua), 24: the menu scene's lights only while the main menu is up (sceneLive: blue-green vehicles on servers), 23: the menu's readiness and clip calls (knoxMenuHurryClips, knoxMenuWhy, knoxMenuReady...) and the jar of 0.9.6 - shipped with 22 by mistake, so new Lua took the jar of the morning's 0.9.5 for good and failed on the missing calls; raise this with EVERY change of the jar, 22: Viewpoint's cursor mode while a Knox window is open (knoxViewpointCursor), 2: fonts and item tooltips, 3: model mirrors the character, 4: tooltip header, 5: held bags on the model, 6: cursor, 7: font coverage, 8: screen counts as inventory, 9: device text (TV subtitles), 10: hide the open TV's text in the world, 11: radio text (items, cars), channel and time per line, 12: main menu scene (KnoxMenu), 13: the dead keep their clothes in the menu, game font while an atlas loads, 14: a Knox font for the game's text boxes (knoxFieldFont), 15: that font is an atlas of its own (the game destroys its table's fonts on reload), 16: the loading screen (KnoxLoading), 20: the inspect window's item color through UI3DScene.stateDataRender (knoxSceneTint), 21: knoxTextInk (where a text's pixels are, for centring)
    }
}
