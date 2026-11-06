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
        return "147";   // 147: a new jar hash on purpose. A Discord player had a stored ZombieBuddy denial of the v146 jar: its window never came back, and reinstalling the game or the mods does not clear it (the author 2026-11-06)
                        // 146: knoxOpenUrl also opens Knox's Discord invite (the news plate's second button, the author 2026-11-05)
                        // 145: a new jar hash on purpose. Update 13's signed jar was force-denied by ZombieBuddy; whoever had "Save decisions to disk" on keeps a stored denial of that hash, silently, with no row in its window (linlin, 2026-11-05)
                        // 144: the bar's frame no longer prints its build times (the author's decision before a release, 2026-11-04)
    }
}
