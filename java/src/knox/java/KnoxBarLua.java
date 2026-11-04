package knox.java;

import java.io.File;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.core.SpriteRenderer;
import zombie.core.opengl.RenderThread;
import zombie.core.skinnedmodel.advancedanimation.AnimatedModel;
import zombie.core.skinnedmodel.animation.AnimationPlayer;
import zombie.core.skinnedmodel.model.SkinningData;
import zombie.core.textures.Texture;
import zombie.core.textures.TextureDraw;
import zombie.core.textures.TextureFBO;
import zombie.iso.IsoGridSquare;
import zombie.ui.UI3DModel;
import zombie.vehicles.UI3DScene;

/**
 * The winter bar's frame (KnoxBarFrame), for the menu's Lua (KnoxMenuSceneBar): the room's
 * list and the files on the main thread; begin and end of the frame queued to the render
 * thread among the menu's drawing, the heroes of UI3DScene between them.
 */
public final class KnoxBarLua {
    private static KnoxBarFrame frame;
    private static volatile boolean high = true;
    private static final long START = System.nanoTime();

    // (the frame's own: they go with it. The camera goes with each frame as Lua had it: the heroes
    // are drawn with that one. More of these than the game can have queued)
    private static Begin begin;
    private static Rest rest;
    private static End[] ends;
    private static int nextEnd;

    // The heroes as the frame has them (stage 4 of the plan, 2026-10-31), set from Lua each
    // frame on the main thread and copied into each End: capsules along their bones (their
    // shadows), the ember of the smoker's cigarette.
    private static final int HEROES = KnoxBarFrame.HEROES, CAPSULES = KnoxBarFrame.CAPSULES, CAPSULE = KnoxBarFrame.CAPSULE;
    private static final float[] CAPS = new float[HEROES * CAPSULES * CAPSULE];
    private static final int[] COUNT = new int[HEROES];
    // (stage 5) where each breathes from and which way: x y z, then the way; 0 0 0: not there
    private static final float[] MOUTHS = new float[HEROES * 6];
    private static float emberX, emberY, emberZ, emberGlow = -1, emberShown;

    // While the frame is open the game may bake a hero's clothes (AnimatedModel.DoRender:
    // ModelInstanceTextureCreator, into its own FBO): its endDrawing() binds back
    // TextureFBO.lastID - the menu's target, not ours - and the heroes after it went past
    // the frame. So ours is lastID while the frame is open (render thread only).
    private static int lastIdBefore;
    private static boolean lastIdOurs;
    private static int photoLastId;
    private static boolean photoLastIdOurs;

    private static File find(String relative) {
        File f = new File(ZomboidFileSystem.instance.getString(relative));
        return f.isFile() ? f : packFile(packRoots, relative);
    }

    // The furniture pack (media/knox/bar_vp.txt): media/voxel-studio/<model>/<its revision>/<file>. The
    // revision's folder is renamed by every update of the pack, the file sometimes too (model.obj,
    // i0-model.obj), and then the bar went to the camp for everybody, without a word (the author, 2026-11-04:
    // look for it at the start). Found through the mod's own folder, so it is read wherever it is installed,
    // whether it is on in the mod list or not. No `require` (its versionMin = versionMax): ROADMAP.
    private static final String PACK_ID = "PZVoxelStudioViewpoint", PACK_MEDIA = "media/voxel-studio/";
    private static volatile File[] packRoots = new File[0];
    private static boolean packAsked, packMoved;

    /** Where the pack's models are. The main thread (the game's list of mods), once: the read ahead has its own. */
    private static void findPack() {
        if (packAsked) return;
        packAsked = true;
        try {
            zombie.gameStates.ChooseGameInfo.Mod mod = zombie.gameStates.ChooseGameInfo.getModDetails(PACK_ID);
            if (mod == null) {
                System.out.println("[Knox] bar: the furniture pack " + PACK_ID + " isn't installed");
                return;
            }
            java.util.ArrayList<File> roots = new java.util.ArrayList<>();
            for (String dir : new String[] {mod.getVersionDir(), mod.getCommonDir(), mod.getDir()}) {
                if (dir == null) continue;
                File root = new File(dir, PACK_MEDIA);
                if (root.isDirectory()) roots.add(root);
            }
            packRoots = roots.toArray(new File[0]);
        } catch (RuntimeException | LinkageError e) {
            System.out.println("[Knox] bar: the furniture pack not looked for: " + e);
        }
    }

    /** A file of the pack (`relative`: as bar_vp.txt has it): where it says, or its model's newest revision. */
    static File packFile(File[] roots, String relative) {
        if (!relative.startsWith(PACK_MEDIA)) return null;
        String rest = relative.substring(PACK_MEDIA.length());
        int a = rest.indexOf('/'), b = rest.lastIndexOf('/');
        if (a <= 0 || b <= a) return null;
        String model = rest.substring(0, a), name = rest.substring(b + 1);
        int dot = name.lastIndexOf('.');
        String kind = dot < 0 ? name : name.substring(dot);
        for (File root : roots) {
            File same = new File(root, rest);
            if (same.isFile()) return same;
            File[] revisions = new File(root, model).listFiles(File::isDirectory);
            if (revisions == null || revisions.length == 0) continue;
            java.util.Arrays.sort(revisions, (x, y) -> Long.compare(y.lastModified(), x.lastModified()));
            for (File revision : revisions) {
                File there = new File(revision, name);
                if (!there.isFile()) {
                    // (of the same kind, the shortest name, then by name: the model before its
                    // variants, model.obj before model-vp2s.obj; i0- before i1- - QA, 2026-11-04)
                    File[] others = revision.listFiles(f -> f.isFile() && f.getName().endsWith(kind));
                    if (others == null || others.length == 0) continue;
                    java.util.Arrays.sort(others, (x, y) -> {
                        int d = x.getName().length() - y.getName().length();
                        return d != 0 ? d : x.getName().compareTo(y.getName());
                    });
                    there = others[0];
                }
                if (!packMoved) {
                    packMoved = true;
                    System.out.println("[Knox] bar: the furniture pack's files aren't where bar_vp.txt says, " + relative + " -> " + there);
                }
                return there;
            }
        }
        return null;
    }

    /** The bar's sounds, every frame (KnoxBarSound; stage 6, the author 2026-10-31). */
    @LuaMethod(name = "knoxBarSounds", global = true)
    public static void knoxBarSounds() {
        KnoxBarFrame f = frame;
        if (f != null) KnoxBarSound.tick(f);
    }

    /**
     * One of the dead out in the storm (the author, 2026-11-01: real zombies, not mannequins;
     * always random, always in winter clothes): scene character `id`, a body and clothes of its
     * own each time this is called. Item by item, not one of the game's outfits: those
     * leave their jackets to chance, and this one mustn't.
     */
    @LuaMethod(name = "knoxBarDead", global = true)
    public static boolean knoxBarDead(UI3DScene scene, String id) {
        AnimatedModel model = KnoxMenu.modelOf(scene, id);
        if (model == null) return false;
        try {
            java.util.concurrent.ThreadLocalRandom r = java.util.concurrent.ThreadLocalRandom.current();
            KnoxMenu.Owner o = new KnoxMenu.Owner();
            o.female = r.nextBoolean();
            o.zombie = true;
            o.visual.zombieRotStage = 1 + r.nextInt(3);
            String[] hair = o.female ? HAIR_F : HAIR;
            o.visual.setHairModel(hair[r.nextInt(hair.length)]);
            for (String[] row : WINTER) {
                String type = row[r.nextInt(row.length)];
                zombie.scripting.objects.Item script = type.isEmpty() ? null : zombie.scripting.ScriptManager.instance.getItem(type);
                zombie.core.skinnedmodel.population.ClothingItem ci = script == null ? null : script.getClothingItemAsset();
                if (ci == null) continue;
                zombie.core.skinnedmodel.visual.ItemVisual iv = new zombie.core.skinnedmodel.visual.ItemVisual();
                iv.setItemType(type);
                iv.setClothingItemName(ci.mame);
                iv.pickUninitializedValues(ci);
                o.items.add(iv);
            }
            o.visual.randomBlood();
            o.visual.randomDirt();
            model.setAnimSetName(KnoxMenu.ANIM_SET);
            model.setAnimate(true);
            model.setAlpha(1f);
            model.setOutfitName(null, o.female, true);
            KnoxMenu.setLook(model, o);
            return true;
        } catch (RuntimeException | LinkageError e) {
            return false;
        }
    }

    // ------------------------------------------------------------------- the wall of the missing

    /**
     * Where a photo goes: on sheet `slot` of the wall of the missing, in the sheet's own frame (metres
     * down from its pin, right of its middle), so it moves with it in the wind (2026-11-02). Before
     * knoxBarLoad's frame is drawn (the author, 2026-11-01: the dead heroes' portraits on the sheets).
     */
    @LuaMethod(name = "knoxBarPhotoPlace", global = true)
    public static void knoxBarPhotoPlace(double slot, double down, double across, double width, double height, double shade) {
        if (frame != null) frame.photoPlace((int) slot, (float) down, (float) across, (float) width, (float) height, (float) shade);
    }

    /**
     * One more take of a photo, into sheet `slot`'s own picture: `ui` is drawn there instead of on
     * the screen (never a child of the menu: only this draws it). `keep`: this take stays and goes
     * on the wall. False: its model isn't ready to be drawn yet.
     */
    @LuaMethod(name = "knoxBarPhotoTake", global = true)
    public static boolean knoxBarPhotoTake(UI3DModel ui, double slot, boolean keep) {
        KnoxBarFrame f = frame;
        AnimatedModel model = ui == null ? null : KnoxAvatar.modelOf(ui);
        if (f == null || model == null) return false;
        int s = (int) slot;
        // (the game's drawer: its viewport's y is Core.height - y - height; here 0)
        int size = KnoxBarFrame.PHOTO_SIZE;
        ui.setX(0);
        ui.setY(Core.height - size);
        ui.setWidth(size);
        ui.setHeight(size);
        ui.setVisible(true);
        SpriteRenderer.instance.drawGeneric(new PhotoBegin(f, s));
        try {
            ui.render();
        } catch (RuntimeException | LinkageError e) {
            SpriteRenderer.instance.drawGeneric(new PhotoEnd(f, s, false));
            return false;
        }
        boolean ready = model.isReadyToRender();
        SpriteRenderer.instance.drawGeneric(new PhotoEnd(f, s, keep && ready));
        return ready;
    }

    private static final class PhotoBegin extends TextureDraw.GenericDrawer {
        private final KnoxBarFrame frame;
        private final int slot;

        PhotoBegin(KnoxBarFrame frame, int slot) {
            this.frame = frame;
            this.slot = slot;
        }

        @Override
        public void render() {
            // (the photo's picture was bound by hand: the game's record of what is bound may be wrong -
            // the next of its sprites binds its own again; overhaul, 2026-11-04)
            Texture.lastTextureID = -1;
            if (frame.photoBegin(slot)) {
                // (a hero's clothes baked now bind back lastID: as for the frame's heroes)
                photoLastId = TextureFBO.lastID;
                photoLastIdOurs = true;
                TextureFBO.lastID = frame.photoTarget(slot);
            }
        }
    }

    private static final class PhotoEnd extends TextureDraw.GenericDrawer {
        private final KnoxBarFrame frame;
        private final int slot;
        private final boolean keep;

        PhotoEnd(KnoxBarFrame frame, int slot, boolean keep) {
            this.frame = frame;
            this.slot = slot;
            this.keep = keep;
        }

        @Override
        public void render() {
            if (photoLastIdOurs) {
                photoLastIdOurs = false;
                TextureFBO.lastID = photoLastId;
            }
            frame.photoEnd(slot, keep);
            Texture.lastTextureID = -1;
        }
    }

    // What the dead out in the storm can have on (the author, 2026-11-01): one of each row; "": nothing
    // there. An item the game hasn't got is left out. The rows in the order of the game's body
    // locations (BodyLocations.lua), as worn items come: each one's mask cuts the others, and out of
    // order parts of them were see-through (the author, 2026-11-01). Hoods down only: a hood up
    // can't go with a hat in the game, the hat stuck out through it.
    private static final String[][] WINTER = {
        {"Base.Hat_WinterHat", "Base.Hat_WoolyHat", "Base.Hat_WinterHat_SheepSkin", "Base.Hat_FurryEars"},
        {"Base.Gloves_LeatherGloves", "Base.Gloves_LeatherGlovesBlack", "Base.Gloves_HuntingCamo", ""},
        {"Base.Shoes_WorkBoots", "Base.Shoes_HikingBoots", "Base.Shoes_ArmyBoots", "Base.Shoes_BlackBoots"},
        {"Base.Trousers_Padded", "Base.Trousers_Padded_HuntingCamo", "Base.Trousers_SheepSkin"},
        {"Base.Jumper_RoundNeck", "Base.Jumper_PoloNeck"},
        {"Base.Jacket_PaddedDOWN", "Base.Jacket_Padded_HuntingCamoDOWN", "Base.Jacket_SheepSkin", "Base.JacketLong_SheepSkin"},
        {"Base.Scarf_White", "Base.Scarf_StripeBlackWhite", "Base.Scarf_StripeBlueWhite", "Base.Scarf_StripeRedWhite", "", ""},
    };
    private static final String[] HAIR = {"Bald", "CrewCut", "Short", "Messy", "Mullet", "Recede"};
    private static final String[] HAIR_F = {"Bob", "Long", "PonyTail", "Kate", "Rachel"};

    /** The game's wardrobe read? A character dressed before it stays half naked. */
    @LuaMethod(name = "knoxBarClothesLoaded", global = true)
    public static boolean knoxBarClothesLoaded() {
        zombie.core.skinnedmodel.population.OutfitManager om = zombie.core.skinnedmodel.population.OutfitManager.instance;
        return om != null && !om.isLoadingClothingItems();
    }

    /** A new frame for the room to be listed into; the one before goes. */
    @LuaMethod(name = "knoxBarStart", global = true)
    public static void knoxBarStart() {
        knoxBarStop();
        findPack();
        frame = new KnoxBarFrame(KnoxBarLua::find);
        frame.quality(high);
        // (the dead out in the storm are the game's own models now: knoxBarDead)
        frame.standInWalkers = false;
        begin = new Begin(frame);
        rest = new Rest(frame);
        ends = new End[] {new End(frame), new End(frame), new End(frame), new End(frame), new End(frame), new End(frame)};
        nextEnd = 0;
        // (nobody in the room yet)
        java.util.Arrays.fill(COUNT, 0);
        java.util.Arrays.fill(MOUTHS, 0f);
        emberGlow = -1;
    }

    /** Degrees and scene units; moves: KnoxBarFrame.STILL, DOOR, LAMP, PAPER, NEEDLE, PAGE, GARLAND, SWITCH, PENCIL, PINNED, BOTTLE, SWAG. */
    @LuaMethod(name = "knoxBarProp", global = true)
    public static void knoxBarProp(String model, double x, double y, double z, double rx, double ry, double rz,
                                   double sx, double sy, double sz, double r, double g, double b, double moves) {
        if (frame == null) return;
        frame.prop(model, (float) x, (float) y, (float) z, (float) rx, (float) ry, (float) rz,
            (float) sx, (float) sy, (float) sz, (float) r, (float) g, (float) b, (int) moves);
    }

    /** All its files read. False: something's not there (another mod's model): the menu has its camp. */
    @LuaMethod(name = "knoxBarLoad", global = true)
    public static boolean knoxBarLoad() {
        if (frame == null) return false;
        try {
            frame.load();
            return true;
        } catch (Throwable t) {
            System.out.println("[Knox] the bar's frame: " + t);
            return false;
        }
    }

    /** High: 4 samples a pixel, the shafts in the air, the AO. Low: without, a smaller shadow map. */
    @LuaMethod(name = "knoxBarQuality", global = true)
    public static void knoxBarQuality(boolean value) {
        high = value;
        if (frame != null) frame.quality(value);
    }

    /** The video card couldn't do it (see the console): back to the camp. */
    @LuaMethod(name = "knoxBarFailed", global = true)
    public static boolean knoxBarFailed() {
        return frame != null && frame.failure() != null;
    }

    @LuaMethod(name = "knoxBarBegin", global = true)
    public static void knoxBarBegin() {
        if (frame != null) SpriteRenderer.instance.drawGeneric(begin);
    }

    @LuaMethod(name = "knoxBarEnd", global = true)
    public static void knoxBarEnd(UI3DScene scene, boolean animated) {
        if (frame == null) return;
        // (always queued, a begun frame must end; without the camera it keeps the one before)
        float[] c = scene == null ? null : KnoxMenu.CAMERAS.get(scene);
        End e = ends[nextEnd];
        nextEnd = (nextEnd + 1) % ends.length;
        e.hasCamera = c != null;
        if (c != null) {
            System.arraycopy(c, 0, e.camera, 0, 7);
            System.arraycopy(c, 8, e.camera, 7, 3);
        }
        // (the heroes' depth must be the frame's: their near plane is its)
        if (c != null && c.length > 7) c[7] = KnoxBarFrame.NEAR;
        e.animated = animated;
        System.arraycopy(CAPS, 0, e.caps, 0, CAPS.length);
        System.arraycopy(COUNT, 0, e.count, 0, HEROES);
        System.arraycopy(MOUTHS, 0, e.mouths, 0, MOUTHS.length);
        e.ember[0] = emberX;
        e.ember[1] = emberY;
        e.ember[2] = emberZ;
        e.ember[3] = emberGlow;
        e.ember[4] = emberShown;
        System.arraycopy(FOCUS, 0, e.focus, 0, 5);
        SpriteRenderer.instance.drawGeneric(e);
    }

    // ------------------------------------------------------------------- the heroes

    // the capsules along a hero's bones, as tools\barframe\poses.py lays them (CHAINS): from,
    // to, radius in scene units; then the head on top of its neck
    private static final String[] BONES = {
        "Bip01_Pelvis", "Bip01_Neck", "Bip01_Neck", "Bip01_Head",
        "Bip01_L_UpperArm", "Bip01_L_Forearm", "Bip01_L_Forearm", "Bip01_L_Hand",
        "Bip01_R_UpperArm", "Bip01_R_Forearm", "Bip01_R_Forearm", "Bip01_R_Hand",
        "Bip01_L_Thigh", "Bip01_L_Calf", "Bip01_L_Calf", "Bip01_L_Foot",
        "Bip01_R_Thigh", "Bip01_R_Calf", "Bip01_R_Calf", "Bip01_R_Foot"};
    private static final float[] RADII = {0.135f, 0.06f, 0.05f, 0.042f, 0.05f, 0.042f, 0.075f, 0.055f, 0.075f, 0.055f};
    private static final float HEAD_UP = 0.1f, HEAD_RADIUS = 0.095f;   // (skeleton units, scene units)
    // the pack on the back of the one about to go, from the hero's place (poses.py's last line)
    private static final float[] PACK = {0f, 0.75f, -0.14f, 0f, 1.1f, -0.15f, 0.14f};
    // The lit end of the cigarette in the hand's prop bone (Bip01_Prop2): the game's
    // Cigarette_Lit sits 0.05 down it (models_items.txt), the mesh 0.07 long along it, the
    // lit end away from the fingers. Measured on the smoking clip (poses.py's Knox_BarSmoke):
    // 0.21-0.24 scene units from the head bone at the drag, 0.50 at rest.
    private static final float[] TIP = {0f, -0.085f, 0.01f};
    private static final float DRAG_FAR = 0.40f, DRAG_SPAN = 0.15f;
    // The mouth in the head bone's space (its z is the face's way, its x up: Bob_Idle, poses.py),
    // skeleton units: a little ahead of the bone; and a point further on, for the way it faces.
    private static final float[] MOUTH = {0f, 0f, 0.055f}, MOUTH_AHEAD = {0f, 0f, 0.155f};

    // the place of the hero being read: scene units, its facing (the scene's rotY is -face)
    private static float placeX, placeY, placeZ, placeSin, placeCos;
    private static final float[] P = new float[3], Q = new float[3];

    /**
     * A bone of the hero's model in the scene, into `out`: the game's own reading
     * (UI3DScene.SceneCharacter: translate, rotateY(face), scale 1.5, the skeleton's z
     * turned round - rotateY(pi) and scale(-1, 1, 1)). `along`: a point in the bone's own
     * space, or null for the bone itself. False: no such bone yet.
     */
    private static boolean bone(AnimationPlayer player, SkinningData data, String name, float[] along, float[] out) {
        Integer i = data.boneIndices.get(name);
        if (i == null || i >= player.getModelTransformsCount()) return false;
        // (kept transposed by the game: the position is m03, m13, m23 - SceneCharacter.hitTestBone)
        org.lwjgl.util.vector.Matrix4f m = player.getModelTransformAt(i);
        float x = m.m03, y = m.m13, z = m.m23;
        if (along != null) {
            x += m.m00 * along[0] + m.m01 * along[1] + m.m02 * along[2];
            y += m.m10 * along[0] + m.m11 * along[1] + m.m12 * along[2];
            z += m.m20 * along[0] + m.m21 * along[1] + m.m22 * along[2];
        }
        x *= 1.5f;
        y *= 1.5f;
        z *= -1.5f;
        out[0] = placeX + x * placeCos + z * placeSin;
        out[1] = placeY + y;
        out[2] = placeZ - x * placeSin + z * placeCos;
        return true;
    }

    private static AnimationPlayer playerOf(AnimatedModel model) {
        if (model == null || !model.hasAnimationPlayer()) return null;
        AnimationPlayer player = model.getAnimationPlayer();
        if (player == null || !player.isReady() || player.getModelTransformsCount() == 0) return null;
        SkinningData data = player.getSkinningData();
        return data == null || data.boneIndices == null ? null : player;
    }

    private static void place(double x, double y, double z, double face) {
        placeX = (float) x;
        placeY = (float) y;
        placeZ = (float) z;
        placeSin = (float) Math.sin(Math.toRadians(face));
        placeCos = (float) Math.cos(Math.toRadians(face));
    }

    private static void capsule(int at, float[] a, float[] b, float r) {
        CAPS[at] = a[0];
        CAPS[at + 1] = a[1];
        CAPS[at + 2] = a[2];
        CAPS[at + 3] = b[0];
        CAPS[at + 4] = b[1];
        CAPS[at + 5] = b[2];
        CAPS[at + 6] = r;
    }

    /**
     * A hero's shadow for the frame: capsules along the bones of scene character `id` as it
     * stands now (scene units; face in degrees, 0 towards the camera). `pack`: the backpack
     * on its back. id null, or no model yet: that slot casts none. Main thread, each frame.
     */
    @LuaMethod(name = "knoxBarHero", global = true)
    public static boolean knoxBarHero(UI3DScene scene, String id, double slot, double x, double y, double z,
                                      double face, boolean pack) {
        int h = (int) slot;
        if (h < 0 || h >= HEROES) return false;
        COUNT[h] = 0;
        int mouth = h * 6;
        MOUTHS[mouth + 3] = MOUTHS[mouth + 4] = MOUTHS[mouth + 5] = 0f;
        AnimationPlayer player = id == null ? null : playerOf(KnoxMenu.modelOf(scene, id));
        if (player == null) return false;
        try {
            SkinningData data = player.getSkinningData();
            place(x, y, z, face);
            int at = h * CAPSULES * CAPSULE, n = 0;
            for (int i = 0; i < RADII.length; i++) {
                if (!bone(player, data, BONES[i * 2], null, P) || !bone(player, data, BONES[i * 2 + 1], null, Q)) return false;
                capsule(at + n++ * CAPSULE, P, Q, RADII[i]);
            }
            // (the head: from its bone on, the way the neck goes)
            if (!bone(player, data, "Bip01_Neck", null, P) || !bone(player, data, "Bip01_Head", null, Q)) return false;
            float dx = Q[0] - P[0], dy = Q[1] - P[1], dz = Q[2] - P[2];
            float len = (float) Math.sqrt(dx * dx + dy * dy + dz * dz);
            if (len < 1e-4f) return false;
            float up = HEAD_UP * 1.5f / len;
            P[0] = Q[0] + dx * up;
            P[1] = Q[1] + dy * up;
            P[2] = Q[2] + dz * up;
            capsule(at + n++ * CAPSULE, Q, P, HEAD_RADIUS);
            if (pack) {
                for (int k = 0; k < 2; k++) {
                    float px = PACK[k * 3], pz = PACK[k * 3 + 2];
                    float[] o = k == 0 ? P : Q;
                    o[0] = placeX + px * placeCos + pz * placeSin;
                    o[1] = placeY + PACK[k * 3 + 1];
                    o[2] = placeZ - px * placeSin + pz * placeCos;
                }
                capsule(at + n++ * CAPSULE, P, Q, PACK[6]);
            }
            COUNT[h] = n;
            if (bone(player, data, "Bip01_Head", MOUTH, P) && bone(player, data, "Bip01_Head", MOUTH_AHEAD, Q)) {
                MOUTHS[mouth] = P[0];
                MOUTHS[mouth + 1] = P[1];
                MOUTHS[mouth + 2] = P[2];
                MOUTHS[mouth + 3] = Q[0] - P[0];
                MOUTHS[mouth + 4] = Q[1] - P[1];
                MOUTHS[mouth + 5] = Q[2] - P[2];
            }
            return true;
        } catch (RuntimeException e) {
            COUNT[h] = 0;
            return false;
        }
    }

    /**
     * The ember of the cigarette in scene character `id`'s hand (its place as for knoxBarHero),
     * glowing for the frame; how much it draws now, 0..1 (the hand at the mouth: a drag), is
     * returned for its light on the face. id null: no ember (-1). shown 0..1: as far as the smoker
     * has come out of the dark.
     */
    @LuaMethod(name = "knoxBarEmber", global = true)
    public static double knoxBarEmber(UI3DScene scene, String id, double x, double y, double z, double face, double shown) {
        emberGlow = -1;
        AnimationPlayer player = id == null ? null : playerOf(KnoxMenu.modelOf(scene, id));
        if (player == null) return -1;
        try {
            SkinningData data = player.getSkinningData();
            place(x, y, z, face);
            if (!bone(player, data, "Bip01_Prop2", TIP, P) || !bone(player, data, "Bip01_Head", null, Q)) return -1;
            float dx = P[0] - Q[0], dy = P[1] - Q[1], dz = P[2] - Q[2];
            float d = (float) Math.sqrt(dx * dx + dy * dy + dz * dz);
            float glow = Math.max(0f, Math.min(1f, (DRAG_FAR - d) / DRAG_SPAN));
            emberX = P[0];
            emberY = P[1];
            emberZ = P[2];
            emberGlow = glow;
            emberShown = (float) shown;
            return glow;
        } catch (RuntimeException e) {
            return -1;
        }
    }

    /** What scene character `id` holds in its other hand (Bip01_Prop2): set before it is dressed. */
    @LuaMethod(name = "knoxBarHand", global = true)
    public static boolean knoxBarHand(UI3DScene scene, String id, String model) {
        AnimatedModel m = KnoxMenu.modelOf(scene, id);
        if (m == null) return false;
        // (its script's scale with it, as the screen's model has: the cigarette came out twice its
        // size - the author, 2026-11-01)
        KnoxAvatar.HANDS.put(m, new String[] {null, model});
        m.setSecondaryHandModelName(model);
        return true;
    }

    private static final IsoGridSquare.ResultLight[] LIGHTS = new IsoGridSquare.ResultLight[5];
    private static final float[] GARLAND = new float[6];

    // the depth of field as Lua has it now: the picture's u, v (from its bottom left), power, band, depth
    private static final float[] FOCUS = {0.5f, 0.5f, 0f, 0.12f, 0f};

    /**
     * The depth of field (the author, 2026-11-03; KnoxBarFrame.focus): the eye focused at (u, v) of
     * the picture, 0..1 from its bottom left; `power` 0..1 (0: all sharp); `band` how far off the
     * focus stays sharp; `depth` how far ahead the thing is, scene units along the view (0: the
     * depth at the point). Main thread, before knoxBarEnd.
     */
    @LuaMethod(name = "knoxBarFocus", global = true)
    public static void knoxBarFocus(double u, double v, double power, double band, double depth) {
        FOCUS[0] = (float) Math.max(0, Math.min(1, u));
        FOCUS[1] = (float) Math.max(0, Math.min(1, v));
        FOCUS[2] = (float) Math.max(0, Math.min(1, power));
        FOCUS[3] = (float) Math.max(0, band);
        FOCUS[4] = (float) Math.max(0, depth);
    }

    /** The mouse on the garland's switch. */
    @LuaMethod(name = "knoxBarSwitchLit", global = true)
    public static void knoxBarSwitchLit(boolean lit) {
        if (frame != null) frame.switchLit(lit);
    }

    /** The one asleep at the counter swats his bottle off it (KnoxBarFrame.bottleKnock; the author, 2026-11-02). */
    @LuaMethod(name = "knoxBarBottleKnock", global = true)
    public static void knoxBarBottleKnock() {
        if (frame != null) frame.bottleKnock();
    }

    /** How many times the bottle has broken on the floor since the room was built (for its sound). */
    @LuaMethod(name = "knoxBarBottleBreaks", global = true)
    public static double knoxBarBottleBreaks() {
        return frame != null ? frame.bottleBreaks() : 0;
    }

    /** The garland's switch (KnoxBarFrame.garland). */
    @LuaMethod(name = "knoxBarGarland", global = true)
    public static void knoxBarGarland(boolean on, boolean atOnce) {
        if (frame != null) frame.garland(on, atOnce);
    }

    /**
     * The bar's two lamps on a scene character: a and b, each a direction towards it in the
     * model's own space (x its side, y up, z its front) and a color; as knoxMenuFireLight
     * gives the fire's (Shader.setLight turns them into -x, z, y).
     */
    @LuaMethod(name = "knoxBarHeroLights", global = true)
    public static void knoxBarHeroLights(UI3DScene scene, String id, double ax, double ay, double az,
                                         double ar, double ag, double ab, double bx, double by, double bz,
                                         double br, double bg, double bb, double hx, double hy, double hz, double fx, double fz) {
        AnimatedModel model = KnoxMenu.modelOf(scene, id);
        if (model == null) return;
        synchronized (LIGHTS) {
            for (int i = 0; i < LIGHTS.length; i++) {
                if (LIGHTS[i] == null) LIGHTS[i] = new IsoGridSquare.ResultLight();
                LIGHTS[i].radius = 0;
            }
            light(LIGHTS[0], ax, ay, az, ar, ag, ab);
            light(LIGHTS[1], bx, by, bz, br, bg, bb);
            // (the garland's, if on and it reaches him, as one light: x y z of the room, in his own space)
            KnoxBarFrame f = frame;
            if (f != null) {
                f.garlandLight((float) hx, (float) hy, (float) hz, GARLAND);
                float gx = GARLAND[0], gy = GARLAND[1], gz = GARLAND[2];
                light(LIGHTS[2], gx * fz - gz * fx, gy, gx * fx + gz * fz, GARLAND[3], GARLAND[4], GARLAND[5]);
            }
            model.setLights(LIGHTS, 0.5f, 0.5f, 0.5f);
        }
    }

    private static void light(IsoGridSquare.ResultLight l, double mx, double my, double mz, double r, double g, double b) {
        if (r <= 0 && g <= 0 && b <= 0) return;
        l.x = (int) Math.round(-mx * 100);
        l.y = (int) Math.round(mz * 100);
        l.z = (int) Math.round(my * 100);
        l.r = (float) r;
        l.g = (float) g;
        l.b = (float) b;
        l.radius = 100000;   // no falloff: the color is the strength
    }

    /** Back to the game's own: the frame is closed (render thread). */
    private static void giveBackLastId() {
        if (!lastIdOurs) return;
        lastIdOurs = false;
        TextureFBO.lastID = lastIdBefore;
    }

    /** A save is loading: the frame's big targets go till the menu is back (the next begin rebuilds them). */
    @LuaMethod(name = "knoxBarRest", global = true)
    public static void knoxBarRest() {
        if (frame != null) SpriteRenderer.instance.drawGeneric(rest);
    }

    // ---- the menu's scenes change by a swipe (the author, 2026-11-02): KnoxMenuSwipe, among the menu's drawing

    private static final class Swipe extends TextureDraw.GenericDrawer {
        float k, blur;
        int dir;
        boolean coming;

        @Override
        public void render() {
            if (dir == 0) KnoxMenuSwipe.take(coming);
            else KnoxMenuSwipe.draw(k, dir, coming, blur);
        }
    }

    // What has to reach the video card whatever happens (QA, 2026-11-04). A drawer queued between two
    // frames - the game starting, a new resolution, a Lua reset - goes out with the state the next frame
    // clears, never drawn: the bar's ~40 MB of pictures, buffers and programs stayed on the card for the
    // rest of the game. Such a state calls postRender on the main thread though, drawn or not.
    private abstract static class Sure extends TextureDraw.GenericDrawer {
        private volatile boolean done;

        abstract void job();

        @Override
        public void render() {
            done = true;
            job();
        }

        @Override
        public void postRender() {
            if (done) return;
            done = true;
            RenderThread.queueInvokeOnRenderContext(() -> {
                try {
                    job();
                } catch (Throwable t) {
                    System.out.println("[Knox] the bar's frame: " + t);
                }
            });
        }
    }

    // (the states the game's renderer has queued, as End's; two a frame)
    private static final Swipe[] SWIPES = new Swipe[12];
    static {
        for (int i = 0; i < SWIPES.length; i++) SWIPES[i] = new Swipe();
    }
    private static int nextSwipe;

    /** What's been drawn so far this frame is the first of the two scenes: kept. */
    @LuaMethod(name = "knoxMenuSwipeTake", global = true)
    public static void knoxMenuSwipeTake(boolean coming) {
        knoxMenuSwipeDraw(0, 0, coming, 0);
    }

    /** The second of them: both up, the one coming k of the way in; dir 1: from the right; blur: of the screen's width. */
    @LuaMethod(name = "knoxMenuSwipeDraw", global = true)
    public static void knoxMenuSwipeDraw(double k, double dir, boolean coming, double blur) {
        Swipe s = SWIPES[nextSwipe];
        nextSwipe = (nextSwipe + 1) % SWIPES.length;
        s.k = (float) k;
        s.dir = (int) dir;
        s.coming = coming;
        s.blur = (float) blur;
        SpriteRenderer.instance.drawGeneric(s);
    }

    @LuaMethod(name = "knoxMenuSwipeFree", global = true)
    public static void knoxMenuSwipeFree() {
        // (a new one each time: a Sure is good for one job)
        SpriteRenderer.instance.drawGeneric(new Sure() {
            @Override
            void job() {
                KnoxMenuSwipe.free();
            }
        });
    }

    private static final class Lights extends TextureDraw.GenericDrawer {
        float[] lights;
        float flicker;

        @Override
        public void render() {
            KnoxMenu.sceneLights = lights;
            KnoxMenu.fireFlicker = flicker;
        }
    }

    /** Two scenes are drawn in a swipe, one set of lights in the game's shader: this one's from here on in the drawing. */
    @LuaMethod(name = "knoxMenuLightsQueued", global = true)
    public static void knoxMenuLightsQueued(se.krka.kahlua.vm.KahluaTable t, double flicker) {
        if (t == null) return;
        float[] v = new float[t.rawget(Double.valueOf(30)) != null ? 30 : 23];
        for (int i = 0; i < v.length; i++) {
            Object o = t.rawget(Double.valueOf(i + 1));
            v[i] = o instanceof Double ? ((Double) o).floatValue() : 0f;
        }
        Lights l = new Lights();
        l.lights = v;
        l.flicker = (float) flicker;
        SpriteRenderer.instance.drawGeneric(l);
    }

    /** The bar's files read in the background, for the next switch to it (the author, 2026-11-02). */
    @LuaMethod(name = "knoxBarPrepare", global = true)
    public static void knoxBarPrepare() {
        findPack();
        KnoxBarFrame.prepare(KnoxBarLua::find);
    }

    /** Into the game: what was read off the memory. */
    @LuaMethod(name = "knoxBarForget", global = true)
    public static void knoxBarForget() {
        KnoxBarFrame.forget();
    }

    /** The video card refused it: the old dark instead. */
    @LuaMethod(name = "knoxMenuSwipeFailed", global = true)
    public static boolean knoxMenuSwipeFailed() {
        return KnoxMenuSwipe.failed();
    }

    /** Everything the frame holds, off the video card: the menu is gone. */
    @LuaMethod(name = "knoxBarStop", global = true)
    public static void knoxBarStop() {
        KnoxBarWalkLua.knoxBarWalkStop(null);
        if (frame == null) return;
        SpriteRenderer.instance.drawGeneric(new Release(frame));
        frame = null;
        begin = null;
        rest = null;
        ends = null;
    }

    private static final class Begin extends TextureDraw.GenericDrawer {
        private final KnoxBarFrame frame;

        Begin(KnoxBarFrame frame) {
            this.frame = frame;
        }

        @Override
        public void render() {
            frame.begin();
            if (frame.begun() && !lastIdOurs) {
                lastIdBefore = TextureFBO.lastID;
                lastIdOurs = true;
                TextureFBO.lastID = frame.target();
            }
        }
    }

    private static final class Rest extends TextureDraw.GenericDrawer {
        private final KnoxBarFrame frame;

        Rest(KnoxBarFrame frame) {
            this.frame = frame;
        }

        @Override
        public void render() {
            giveBackLastId();
            frame.rest();
        }
    }

    private static final class End extends TextureDraw.GenericDrawer {
        private final KnoxBarFrame frame;
        final float[] camera = new float[10];
        boolean hasCamera, animated;
        final float[] caps = new float[CAPS.length], ember = new float[5];
        final int[] count = new int[HEROES];
        final float[] mouths = new float[MOUTHS.length];
        final float[] focus = new float[5];

        End(KnoxBarFrame frame) {
            this.frame = frame;
        }

        @Override
        public void render() {
            giveBackLastId();
            if (hasCamera) frame.camera(camera);
            frame.heroes(caps, count);
            frame.mouths(mouths);
            frame.ember(ember[0], ember[1], ember[2], ember[3], ember[4]);
            frame.focus(focus[0], focus[1], focus[2], focus[3], focus[4]);
            frame.end(animated ? (System.nanoTime() - START) / 1e9f : 12f);
        }
    }

    private static final class Release extends Sure {
        private final KnoxBarFrame frame;

        Release(KnoxBarFrame frame) {
            this.frame = frame;
        }

        @Override
        void job() {
            giveBackLastId();
            frame.release();
        }
    }
}
