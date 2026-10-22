package knox.java;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

import me.zed_0xff.zombie_buddy.Patch;
import org.lwjgl.util.vector.Matrix4f;
import org.lwjgl.util.vector.Quaternion;
import org.lwjgl.util.vector.Vector3f;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.skinnedmodel.HelperFunctions;
import zombie.core.skinnedmodel.advancedanimation.AnimatedModel;
import zombie.core.skinnedmodel.animation.AnimationPlayer;
import zombie.core.skinnedmodel.model.SkinningBone;
import zombie.core.skinnedmodel.model.SkinningData;
import zombie.vehicles.UI3DScene;

/**
 * A hero at the camp's fire looks up at you (the author's wish, 2026-10-16):
 * the mouse on a hero, and their neck and head turn towards the camera while
 * the body goes on with its animation.
 *
 * Done as the game turns its characters' upper body towards where they aim
 * (AnimationPlayer.applyTwistBone): once the clip has set the bones and before
 * the pose is put together, a bone's place in the model is turned about its
 * own point and made local again. Here the neck takes a third of the way, the
 * head the rest. Hooked on applyBoneReParenting - the step the game runs right
 * between the two (updateAnimation_StandardAnimation); only for the scene
 * characters Lua names (knoxMenuLook), everything else is left alone.
 */
public class KnoxLook {

    /** per animation player: {yaw, pitch (radians, from the body's front), weight 0..1} */
    public static final Map<AnimationPlayer, float[]> LOOK = Collections.synchronizedMap(new WeakHashMap<>());
    /**
     * Anyone looking at all? The hook runs for every character's animation in
     * the game - every zombie, every frame - so it must cost nothing when not:
     * one plain read of this flag (a performance pass, 2026-10-16; it used to
     * ask the synchronized map, and entries left by the menu kept it asking in
     * the game). Cleared when the menu goes (knoxMenuLookClear).
     */
    public static volatile boolean ON = false;

    /** The menu is gone: nobody looks any more. */
    @LuaMethod(name = "knoxMenuLookClear", global = true)
    public static void knoxMenuLookClear() {
        ON = false;
        LOOK.clear();
    }

    static final float NECK_SHARE = 0.35f;

    /**
     * Where a scene character looks, from its body's front: `yawDeg` to its
     * side, `pitchDeg` up; `weight` 0 (its animation's own head) .. 1.
     */
    @LuaMethod(name = "knoxMenuLook", global = true)
    public static void knoxMenuLook(UI3DScene scene, String id, double yawDeg, double pitchDeg, double weight) {
        AnimatedModel model = KnoxMenu.modelOf(scene, id);
        if (model == null) return;
        try {
            AnimationPlayer player = model.getAnimationPlayer();
            if (player == null) return;
            if (weight <= 0.001) {
                LOOK.remove(player);
                ON = !LOOK.isEmpty();
                return;
            }
            LOOK.put(player, new float[] {(float) Math.toRadians(yawDeg), (float) Math.toRadians(pitchDeg), (float) Math.min(1.0, weight)});
            ON = true;
        } catch (RuntimeException e) {
            // not ready
        }
    }

    /** From the hook: turn the neck and head of a looking character. */
    public static void apply(AnimationPlayer p) {
        if (!ON) return;
        float[] v = LOOK.get(p);
        if (v == null) return;
        try {
            SkinningData d = p.getSkinningData();
            if (d == null || d.boneIndices == null || p.boneTransforms == null) return;
            Integer neck = d.boneIndices.get("Bip01_Neck"), head = d.boneIndices.get("Bip01_Head");
            if (neck == null || head == null) return;
            // the way to look, in the model's space (+Z its front, +Y up)
            float cp = (float) Math.cos(v[1]);
            Vector3f want = new Vector3f(cp * (float) Math.sin(v[0]), (float) Math.sin(v[1]), cp * (float) Math.cos(v[0]));
            turn(p, d, neck, want, NECK_SHARE * v[2]);
            turn(p, d, head, want, v[2]);
        } catch (RuntimeException e) {
            // a skeleton not as expected: its own pose
        }
    }

    /** Turn a bone `share` of the way from where it faces to `want` (as AnimationPlayer.applyTwistBone does). */
    static void turn(AnimationPlayer p, SkinningData d, int idx, Vector3f want, float share) {
        SkinningBone bone = d.getBoneAt(idx);
        if (bone == null || bone.parent == null || idx >= p.boneTransforms.length) return;
        Matrix4f parent = p.getBoneModelTransform(bone.parent.index, new Matrix4f());
        Matrix4f parentInv = Matrix4f.invert(parent, new Matrix4f());
        if (parentInv == null) return;
        Matrix4f m = p.getBoneModelTransform(idx, new Matrix4f());
        Vector3f pos = HelperFunctions.getPosition(m, new Vector3f());
        // where it faces now (the game's own front of a bone: its -Z)
        Vector3f now = HelperFunctions.transformVector(m, new Vector3f(0f, 0f, -1f), new Vector3f());
        if (now.lengthSquared() < 1.0e-6f) return;
        now.normalise();
        Vector3f axis = Vector3f.cross(want, now, new Vector3f());
        if (axis.lengthSquared() < 1.0e-8f) return;
        axis.normalise();
        float dot = Math.max(-1f, Math.min(1f, Vector3f.dot(want, now)));
        float angle = (float) Math.acos(dot) * share;
        Quaternion q = HelperFunctions.setFromAxisAngle(axis.x, axis.y, axis.z, -angle, new Quaternion());
        Matrix4f turned = new Matrix4f();
        turned.load(m);
        HelperFunctions.setPosition(turned, 0f, 0f, 0f);
        Matrix4f adj = HelperFunctions.CreateFromQuaternion(q, new Matrix4f());
        Matrix4f.mul(turned, adj, turned);
        HelperFunctions.setPosition(turned, pos);
        p.boneTransforms[idx].mul(turned, parentInv);
    }

    @Patch(className = "zombie.core.skinnedmodel.animation.AnimationPlayer", methodName = "applyBoneReParenting")
    public static class Hook {
        @Patch.OnEnter
        public static void enter(@Patch.This AnimationPlayer self) {
            if (KnoxLook.ON) KnoxLook.apply(self);
        }
    }
}
