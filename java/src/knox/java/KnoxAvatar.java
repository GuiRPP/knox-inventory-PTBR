package knox.java;

import java.lang.reflect.Field;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

import me.zed_0xff.zombie_buddy.Patch;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.characters.CharacterTimedActions.BaseAction;
import zombie.characters.IsoGameCharacter;
import zombie.characters.animals.IsoAnimal;
import zombie.core.skinnedmodel.advancedanimation.AnimatedModel;
import zombie.core.skinnedmodel.animation.AnimationPlayer;
import zombie.core.skinnedmodel.model.ModelInstance;
import zombie.core.skinnedmodel.visual.BaseVisual;
import zombie.core.skinnedmodel.visual.ItemVisual;
import zombie.core.skinnedmodel.visual.ItemVisuals;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.HandWeapon;
import zombie.scripting.objects.ItemReplacement;
import zombie.ui.UI3DModel;

/**
 * The character model in the Knox screen repeats everything the character
 * does in the world: walking, aiming, eating, bandaging, any action.
 *
 * The game's AnimationPlayer can copy its pose from a parent player every
 * update (parentPlayer, used for attached models). The screen's model gets
 * the character's own player as its parent, so it shows the same pose, while
 * keeping its own facing (towards the camera). Its own "player-avatar" idle
 * keeps running underneath, only its bones are replaced.
 *
 * What the character holds is picked the way ModelManager does it for the
 * world model (weapon, an action's props such as a rag or a book), and put in
 * the model's hands by name.
 */
public class KnoxAvatar {

    private static Field animatedModelField;
    private static Field modelInstanceField;

    /** Hand models of the screen's models (others are left alone). */
    public static final Map<AnimatedModel, String[]> HANDS = Collections.synchronizedMap(new WeakHashMap<>());

    static AnimatedModel modelOf(UI3DModel ui) {
        try {
            if (animatedModelField == null) {
                animatedModelField = UI3DModel.class.getDeclaredField("animatedModel");
                animatedModelField.setAccessible(true);
            }
            return (AnimatedModel) animatedModelField.get(ui);
        } catch (ReflectiveOperationException | RuntimeException e) {
            return null;
        }
    }

    /**
     * Copy (on) or stop copying (off) the character's pose. Call every frame:
     * either player can be replaced when models change. Returns true while
     * the pose is copied.
     */
    @LuaMethod(name = "knoxAvatarMirror", global = true)
    public static boolean knoxAvatarMirror(UI3DModel ui, IsoGameCharacter chr, boolean on) {
        AnimatedModel model = ui == null ? null : modelOf(ui);
        if (model == null || !model.hasAnimationPlayer()) return false;
        AnimationPlayer own = model.getAnimationPlayer();
        AnimationPlayer src = (on && chr != null) ? chr.getAnimationPlayer() : null;
        // same skeleton only: the copy walks both bone arrays
        if (src != null && (src == own || !src.isReady() || !own.isReady()
                || src.boneTransforms == null || own.boneTransforms == null
                || src.boneTransforms.length != own.boneTransforms.length
                || src.isBoneTransformsNeedFirstFrame())) {
            src = null;
        }
        if (own.parentPlayer != src) own.parentPlayer = src;
        return src != null;
    }

    static String staticModel(InventoryItem item, boolean overrideHandModels) {
        if (item == null) return "";
        if (item instanceof HandWeapon && item.getClothingItem() == null) {
            String s = ((HandWeapon) item).getStaticModel();
            return s == null ? "" : s;
        }
        if (overrideHandModels && item.getStaticModel() != null) return item.getStaticModel();
        return "";
    }

    /** Models in the character's hands right now, "primary|secondary" ("" = none). */
    @LuaMethod(name = "knoxAvatarHands", global = true)
    public static String knoxAvatarHands(IsoGameCharacter chr) {
        if (chr == null) return "|";
        InventoryItem primary = chr.getPrimaryHandItem();
        InventoryItem secondary = chr.getSecondaryHandItem();
        if (chr.isHideWeaponModel()) {
            primary = null;
            secondary = null;
        }
        if (chr.isHideEquippedHandL()) secondary = null;
        if (chr.isHideEquippedHandR()) primary = null;
        String p = null, s = null;
        boolean override = false;
        BaseAction action = chr.getCharacterActions().isEmpty() ? null : chr.getCharacterActions().get(0);
        if (action != null && action.overrideHandModels) {
            override = true;
            primary = action.getPrimaryHandItem();
            if (primary == null && action.getPrimaryHandMdl() != null) p = action.getPrimaryHandMdl();
            secondary = action.getSecondaryHandItem();
            if (secondary == null && action.getSecondaryHandMdl() != null) s = action.getSecondaryHandMdl();
        }
        if (chr.overridePrimaryHandModel != null && !chr.overridePrimaryHandModel.isEmpty()) {
            override = true;
            p = chr.overridePrimaryHandModel;
        }
        if (chr.overrideSecondaryHandModel != null && !chr.overrideSecondaryHandModel.isEmpty()) {
            override = true;
            s = chr.overrideSecondaryHandModel;
        }
        if (p == null) p = staticModel(primary, override);
        if (s == null) s = secondary == primary ? "" : staticModel(secondary, override);
        return p + "|" + s;
    }

    /** Put models in the screen model's hands (applied by its next setCharacter). */
    @LuaMethod(name = "knoxAvatarSetHands", global = true)
    public static void knoxAvatarSetHands(UI3DModel ui, String primary, String secondary) {
        AnimatedModel model = ui == null ? null : modelOf(ui);
        if (model == null) return;
        String p = primary == null || primary.isEmpty() ? null : primary;
        String s = secondary == null || secondary.isEmpty() ? null : secondary;
        HANDS.put(model, new String[] {p, s});
        model.setPrimaryHandModelName(p);
        model.setSecondaryHandModelName(s);
    }

    /**
     * The world model applies a hand item's model script scale
     * (ModelManager.addStaticForcedTex -> applyModelScriptScale); AnimatedModel
     * doesn't, so items with a scaled script (bacon, a sheet...) came out huge.
     * Applied here to the props just added to one of our models.
     */
    public static void scaleHands(AnimatedModel model) {
        String[] h = HANDS.get(model);
        if (h == null) return;
        try {
            if (modelInstanceField == null) {
                modelInstanceField = AnimatedModel.class.getDeclaredField("modelInstance");
                modelInstanceField.setAccessible(true);
            }
            ModelInstance root = (ModelInstance) modelInstanceField.get(model);
            if (root == null || root.sub == null) return;
            for (ModelInstance mi : root.sub) {
                if (h[0] != null && "Bip01_Prop1".equals(mi.parentBoneName)) mi.applyModelScriptScale(h[0]);
                if (h[1] != null && "Bip01_Prop2".equals(mi.parentBoneName)) mi.applyModelScriptScale(h[1]);
            }
        } catch (ReflectiveOperationException | RuntimeException e) {
            // keep the unscaled props
        }
    }

    @Patch(className = "zombie.core.skinnedmodel.advancedanimation.AnimatedModel", methodName = "DoCharacterModelEquipped")
    public static class EquippedScale {
        @Patch.OnExit
        public static void exit(@Patch.This AnimatedModel self) {
            if (!HANDS.isEmpty()) scaleHands(self);
        }
    }

    /**
     * A bag held in a hand (a briefcase, a duffel carried by its handle) is no
     * prop: the world model shows it as a clothing item of its own
     * (ReplaceInPrimaryHand / ReplaceInSecondHand, ModelManager.addMaskingModel).
     * The character's item visuals hold worn things only, so the screen's model
     * showed empty hands. Its visuals get those held items too, the way the
     * game itself names them (ItemVisual alternate model "RightHand" / "LeftHand").
     */
    public static void addHeldVisuals(AnimatedModel model, ItemVisuals visuals) {
        IsoGameCharacter chr = model.getCharacter();
        if (chr == null || visuals == null) return;
        InventoryItem primary = chr.getPrimaryHandItem();
        InventoryItem secondary = chr.getSecondaryHandItem();
        if (chr.isHideWeaponModel()) {
            primary = null;
            secondary = null;
        }
        if (chr.isHideEquippedHandL()) secondary = null;
        if (chr.isHideEquippedHandR()) primary = null;
        BaseAction action = chr.getCharacterActions().isEmpty() ? null : chr.getCharacterActions().get(0);
        if (action != null && action.overrideHandModels) return;   // the action's props instead
        addHeld(visuals, primary, primary == null ? null : primary.getItemReplacementPrimaryHand(), "RightHand");
        if (secondary != primary) {
            addHeld(visuals, secondary, secondary == null ? null : secondary.getItemReplacementSecondHand(), "LeftHand");
        }
    }

    static void addHeld(ItemVisuals visuals, InventoryItem item, ItemReplacement replacement, String hand) {
        if (item == null || replacement == null || replacement.clothingItem == null) return;
        for (int i = 0; i < visuals.size(); i++) {
            ItemVisual v = visuals.get(i);
            if (v.getInventoryItem() == item && hand.equals(v.getAlternateModelName())) return;   // there already
        }
        ItemVisual v = item.getVisual() != null ? new ItemVisual(item.getVisual()) : new ItemVisual();
        if (v.getItemType() == null) v.setItemType(item.getFullType());
        v.setAlternateModelName(hand);
        v.setInventoryItem(item);
        visuals.add(v);
    }

    @Patch(className = "zombie.core.skinnedmodel.advancedanimation.AnimatedModel", methodName = "setModelData")
    public static class HeldBags {
        @Patch.OnEnter
        public static void enter(@Patch.This AnimatedModel self, @Patch.Argument(0) BaseVisual baseVisual,
                                 @Patch.Argument(1) ItemVisuals itemVisuals, @Patch.Argument(2) IsoAnimal animal) {
            if (HANDS.containsKey(self)) addHeldVisuals(self, itemVisuals);
        }
    }
}
