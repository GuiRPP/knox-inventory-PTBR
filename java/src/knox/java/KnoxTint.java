package knox.java;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.skinnedmodel.model.Model;
import zombie.vehicles.UI3DScene;

/**
 * Item colors for models in the Knox inspect window.
 *
 * UI3DScene draws every model untinted (ModelDrawer.render calls
 * effect.setTint(1, 1, 1) and setHueShift(0)), so clothes show the plain
 * texture instead of the item's random tint. Lua registers a color per inspect
 * scene (knoxSceneTint; such a scene holds one model); while that scene's model
 * is being drawn, the white tint and zero hue are swapped for it. Nothing else
 * in the game is touched.
 *
 * How "being drawn" is known: ModelDrawer.render begins with
 * scene.stateDataRender(). (ModelDrawer itself can't be patched - ZombieBuddy
 * never transformed that package-private nested class, the patch on its render
 * was silently not applied and models stayed white. UI3DScene can.) The call
 * arms the color when it comes from a ModelDrawer whose model is ready to draw;
 * the Shader.setTint that follows uses it and disarms.
 *
 * Advice code is inlined into the game classes, so everything it uses here is public.
 */
public class KnoxTint {

    /** inspect scene -> {r, g, b, hue} */
    public static final Map<UI3DScene, float[]> TINTS = Collections.synchronizedMap(new WeakHashMap<>());

    /** color of the model being drawn right now (render thread), or null */
    public static final ThreadLocal<float[]> CURRENT = new ThreadLocal<>();
    /**
     * Is a color armed at all? Shader.setTint / setHueShift run for every model
     * the game draws - every zombie, every frame: without a color waiting they
     * leave on this one read instead of a ThreadLocal lookup each (a performance
     * pass, 2026-10-16).
     */
    public static volatile boolean ARMED = false;

    private static final StackWalker WALKER = StackWalker.getInstance();
    private static Field objectsField;
    private static Field sceneModelModel;
    private static boolean told;

    @LuaMethod(name = "knoxSceneTint", global = true)
    public static void knoxSceneTint(UI3DScene scene, double r, double g, double b, double hue) {
        if (scene == null) return;
        TINTS.put(scene, new float[] {(float) r, (float) g, (float) b, (float) hue});
    }

    @LuaMethod(name = "knoxSceneTintClear", global = true)
    public static void knoxSceneTintClear(UI3DScene scene) {
        if (scene != null) TINTS.remove(scene);
    }

    /** Is the caller of stateDataRender a model's drawer (not the grid's, the overlays'...)? */
    public static boolean fromModelDrawer() {
        return WALKER.walk(frames -> frames.limit(6).anyMatch(f -> f.getClassName().endsWith("$ModelDrawer")));
    }

    /**
     * Will the scene's model go on to its shader calls? ModelDrawer.render leaves
     * before them while the model has no shader or its mesh is still loading - an
     * armed color would then fall on whatever is drawn next.
     */
    public static boolean modelReady(UI3DScene scene) {
        try {
            if (objectsField == null) {
                objectsField = UI3DScene.class.getDeclaredField("objects");
                objectsField.setAccessible(true);
            }
            ArrayList<?> objects = (ArrayList<?>) objectsField.get(scene);
            boolean any = false;
            for (int i = 0; i < objects.size(); i++) {
                Object o = objects.get(i);
                if (o == null || !o.getClass().getName().endsWith("$SceneModel")) continue;
                if (sceneModelModel == null) {
                    sceneModelModel = o.getClass().getDeclaredField("model");
                    sceneModelModel.setAccessible(true);
                }
                Model m = (Model) sceneModelModel.get(o);
                if (m == null || m.effect == null || m.mesh == null || !m.mesh.isReady()) return false;
                any = true;
            }
            return any;
        } catch (ReflectiveOperationException | RuntimeException e) {
            return false;
        }
    }

    /** Called at the start of every drawer of every 3D scene while any color is registered. */
    public static void arm(UI3DScene scene) {
        float[] t = TINTS.get(scene);
        if (t == null || !fromModelDrawer() || !modelReady(scene)) {
            CURRENT.remove();
            return;
        }
        if (!told) {
            told = true;
            System.out.println("[Knox] inspect window: item color hook is working");
        }
        CURRENT.set(t);
        ARMED = true;
    }

    @Patch(className = "zombie.vehicles.UI3DScene", methodName = "stateDataRender")
    public static class SceneRender {
        @Patch.OnEnter
        public static void enter(@Patch.This UI3DScene self) {
            if (!TINTS.isEmpty()) arm(self);
        }
    }

    @Patch(className = "zombie.core.skinnedmodel.shader.Shader", methodName = "setHueShift")
    public static class ShaderHue {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(value = 0, readOnly = false) float hue) {
            if (!KnoxTint.ARMED) return;
            float[] t = CURRENT.get();
            if (t != null && hue == 0f) hue = t[3];
        }
    }

    // (ModelDrawer.render sets the hue, then the tint: the tint ends the color's turn)
    @Patch(className = "zombie.core.skinnedmodel.shader.Shader", methodName = "setTint")
    public static class ShaderTint {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(value = 0, readOnly = false) float r,
                                 @Patch.Argument(value = 1, readOnly = false) float g,
                                 @Patch.Argument(value = 2, readOnly = false) float b) {
            if (!KnoxTint.ARMED) return;
            float[] t = CURRENT.get();
            if (t != null) {
                CURRENT.remove();
                KnoxTint.ARMED = false;
                if (r == 1f && g == 1f && b == 1f) {
                    r = t[0];
                    g = t[1];
                    b = t[2];
                }
            }
        }
    }
}
