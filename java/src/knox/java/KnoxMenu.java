package knox.java;

import java.io.File;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.WeakHashMap;

import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;

import org.joml.Matrix4f;
import org.lwjgl.opengl.GL11;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

import zombie.core.Core;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.HandWeapon;
import zombie.core.SpriteRenderer;
import zombie.core.opengl.GLStateRenderThread;
import zombie.core.skinnedmodel.shader.Shader;
import zombie.core.textures.TextureDraw;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import se.krka.kahlua.vm.KahluaTable;
import zombie.GameWindow;
import zombie.ZomboidFileSystem;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.core.skinnedmodel.ModelManager;
import zombie.core.skinnedmodel.advancedanimation.AdvancedAnimator;
import zombie.core.skinnedmodel.advancedanimation.AnimatedModel;
import zombie.core.skinnedmodel.advancedanimation.AnimationSet;
import zombie.core.skinnedmodel.animation.AnimationClip;
import zombie.core.skinnedmodel.animation.AnimationPlayer;
import zombie.core.skinnedmodel.model.SkinningData;
import zombie.core.skinnedmodel.visual.HumanVisual;
import zombie.core.skinnedmodel.visual.IHumanVisual;
import zombie.core.skinnedmodel.visual.ItemVisuals;
import zombie.core.textures.ColorInfo;
import zombie.gameStates.GameStateMachine;
import zombie.gameStates.MainScreenState;
import zombie.input.Mouse;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;
import zombie.network.GameClient;
import zombie.ui.UI3DModel;
import zombie.ui.UIElement;
import zombie.ui.UIElementInterface;
import zombie.ui.UIManager;
import zombie.vehicles.UI3DScene;

/**
 * The campfire scene of the main menu: the heroes of the player's last saves
 * sit around a fire, looking exactly as they did when the save was left.
 *
 * A save's character can't be read without loading its world (the items are
 * tied to the world's dictionary), so while a save is played Lua asks for a
 * small snapshot now and then (knoxMenuSnapshot): name, time survived, health
 * and the visuals the game itself would save. It is kept in the save's folder
 * (knox_menu.bin) and read back in the menu.
 *
 * The menu scene is a UI3DScene; its characters are private to the class, so
 * their AnimatedModel is reached by reflection to dress, animate and light it.
 * The sitting and walking states are extra states of the game's "player-avatar"
 * anim set (media/AnimSets/player-avatar/knoxmenu_*), which has an action group
 * of its own; the model stays in that group's idle state and only the
 * animator's state is switched here.
 */
public class KnoxMenu {

    public static final String FILE = "knox_menu.bin";
    public static final String ANIM_SET = "player-avatar";
    static final int MAGIC = 0x4B4D4E55;   // "KMNU"
    static final int VERSION = 4;   // 2: the hero's weapon, 3: a line of extras for the hover card, 4: the real worn items behind the looks

    /** Who a loaded visual belongs to: HumanVisual asks its owner for sex and state. */
    public static class Owner implements IHumanVisual {
        public boolean female;
        public boolean zombie;
        public final HumanVisual visual = new HumanVisual(this);
        public final ItemVisuals items = new ItemVisuals();

        @Override public HumanVisual getHumanVisual() { return visual; }
        @Override public void getItemVisuals(ItemVisuals out) { out.clear(); out.addAll(items); }
        @Override public boolean isFemale() { return female; }
        @Override public boolean isZombie() { return zombie; }
        @Override public boolean isSkeleton() { return false; }
    }

    public static class Snapshot {
        public String name = "";
        public double hours;
        public float health;
        public boolean dead;
        public int kills;
        public String weapon = "";   // model of what the hero held or carried, shown lying next to them
        public String extra = "";    // "key=value|..." written and read by Lua: profession, town, how the hero feels
        // per item of owner.items: the type of the worn item behind it when the
        // look is another item's ("" when it is its own) - see substitute()
        public String[] real = new String[0];
        public final Owner owner = new Owner();
    }

    // ---------------------------------------------------------------- snapshot

    /** Write the player's snapshot into the save being played. */
    @LuaMethod(name = "knoxMenuSnapshot", global = true)
    public static boolean knoxMenuSnapshot(IsoPlayer player, String extra) {
        if (player == null || GameClient.client) return false;
        try {
            played = IsoWorld.instance.getGameMode() + File.separator + IsoWorld.instance.getWorld();
            ByteBuffer bb = ByteBuffer.allocate(1 << 17);
            bb.putInt(MAGIC);
            bb.putInt(VERSION);
            bb.putInt(IsoWorld.getWorldVersion());
            SurvivorDesc desc = player.getDescriptor();
            String name = desc == null ? "" : (nz(desc.getForename()) + " " + nz(desc.getSurname())).trim();
            GameWindow.WriteString(bb, name);
            bb.putDouble(player.getHoursSurvived());
            boolean dead = player.isDead();
            bb.putFloat(dead ? 0f : player.getBodyDamage().getOverallBodyHealth());
            bb.put((byte) (dead ? 1 : 0));
            bb.put((byte) (player.isFemale() ? 1 : 0));
            bb.putInt(player.getZombieKills());
            // A dead player has already lost the clothes (they went to the
            // corpse): the look stays the one of the last snapshot alive.
            File target = new File(ZomboidFileSystem.instance.getFileNameInCurrentSave(FILE));
            Snapshot old = dead ? readFile(target) : null;
            String[] real;
            if (old != null) {
                old.owner.visual.save(bb);
                old.owner.items.save(bb);
                GameWindow.WriteString(bb, old.weapon);
                real = old.real;
            } else {
                player.getHumanVisual().save(bb);
                ItemVisuals items = new ItemVisuals();
                player.getItemVisuals(items);
                items.save(bb);
                GameWindow.WriteString(bb, weaponModel(player));
                real = realTypes(player, items);
            }
            GameWindow.WriteString(bb, nz(extra));
            bb.putInt(real.length);
            for (String r : real) GameWindow.WriteString(bb, nz(r));

            byte[] data = new byte[bb.position()];
            bb.flip();
            bb.get(data);
            File tmp = new File(target.getPath() + ".tmp");
            Files.write(tmp.toPath(), data);
            Files.move(tmp.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
            return true;
        } catch (Exception | LinkageError e) {
            tell("writing the snapshot", e);
            return false;
        }
    }

    /** Model script name of the hero's weapon: in hand, else the first one carried on the body. */
    static String weaponModel(IsoPlayer player) {
        try {
            InventoryItem item = player.getPrimaryHandItem();
            if (!(item instanceof HandWeapon)) item = player.getSecondaryHandItem();
            if (!(item instanceof HandWeapon) && player.getAttachedItems() != null) {
                item = null;
                for (int i = 0; i < player.getAttachedItems().size(); i++) {
                    InventoryItem attached = player.getAttachedItems().getItemByIndex(i);
                    if (attached instanceof HandWeapon) {
                        item = attached;
                        break;
                    }
                }
            }
            if (!(item instanceof HandWeapon)) return "";
            String model = ((HandWeapon) item).getWeaponSprite();
            if (model == null || model.isEmpty()) model = item.getStaticModel();
            return nz(model);
        } catch (RuntimeException e) {
            return "";
        }
    }

    /** the save being played ("Sandbox\name"); survives the reload of Lua on the way to the menu */
    private static volatile String played;

    /**
     * Asked once by the menu scene: the save the player has just left for the
     * main menu (its hero walks back to the fire), or nil when the game was
     * started fresh.
     */
    @LuaMethod(name = "knoxMenuReturned", global = true)
    public static String knoxMenuReturned() {
        String save = played;
        played = null;
        return save;
    }

    static String nz(String s) {
        return s == null ? "" : s;
    }

    private static final java.util.HashSet<String> told = new java.util.HashSet<>();

    /**
     * A hero that could not be written, read or dressed used to be a dark
     * figure without a word (a report: female heroes with a body mod). What
     * failed is now in console.txt, once per place and cause.
     */
    static void tell(String where, Throwable e) {
        String key = where + "|" + e;
        synchronized (told) {
            if (!told.add(key) || told.size() > 40) return;
        }
        StackTraceElement[] st = e.getStackTrace();
        StringBuilder sb = new StringBuilder("[Knox] menu hero: ").append(where).append(" failed: ").append(e);
        for (int i = 0; i < st.length && i < 6; i++) sb.append("\n[Knox]     at ").append(st[i]);
        System.out.println(sb);
    }

    /** Snapshot of a save ("Sandbox\name", as getFullSaveDirectoryTable gives it), or null. */
    static Snapshot read(String save) {
        if (save == null || save.contains("..")) return null;
        Snapshot s = readFile(new File(ZomboidFileSystem.instance.getSaveDir() + File.separator + save, FILE));
        if (s != null && SUBSTITUTED.contains(save)) substitute(s);
        if (s != null) takeOff(s, save);
        return s;
    }

    /**
     * The type of the worn item behind each look, where the look is another
     * item's. A mod that changes how clothes look (Transmog: a player's hero
     * came to the fire naked, 2026-10-16) gives the worn things the looks of its
     * own items - "TransmogItem_1264" - which it fills in while a game runs; in
     * the menu they are empty for good.
     */
    static String[] realTypes(IsoPlayer player, ItemVisuals items) {
        String[] out = new String[items.size()];
        zombie.characters.WornItems.WornItems worn = player.getWornItems();
        for (int i = 0; i < items.size(); i++) {
            out[i] = "";
            zombie.core.skinnedmodel.visual.ItemVisual iv = items.get(i);
            for (int j = 0; worn != null && j < worn.size(); j++) {
                InventoryItem item = worn.getItemByIndex(j);
                if (item == null || item.getVisual() != iv) continue;
                String type = item.getFullType();
                if (type != null && !type.equals(iv.getItemType())) out[i] = type;
                break;
            }
        }
        return out;
    }

    // ------------------------------------------------------------ what they carry

    /**
     * The hero's bag at the fire (the author's idea, 2026-10-16): what the hero
     * carries - pockets and bags as Knox's grids show them - written by Lua while
     * a game runs (KnoxMenuBag.lua: a few lines of text) into the save's folder,
     * and read back in the menu.
     */
    public static final String BAG_FILE = "knox_bag.txt";

    @LuaMethod(name = "knoxMenuSaveBag", global = true)
    public static boolean knoxMenuSaveBag(String text) {
        if (text == null || GameClient.client) return false;
        try {
            File target = new File(ZomboidFileSystem.instance.getFileNameInCurrentSave(BAG_FILE));
            File tmp = new File(target.getPath() + ".tmp");
            Files.write(tmp.toPath(), text.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            Files.move(tmp.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
            return true;
        } catch (Exception | LinkageError e) {
            tell("writing what the hero carries", e);
            return false;
        }
    }

    @LuaMethod(name = "knoxMenuBag", global = true)
    public static String knoxMenuBag(String save) {
        if (save == null || save.contains("..")) return null;
        try {
            File f = new File(ZomboidFileSystem.instance.getSaveDir() + File.separator + save, BAG_FILE);
            if (!f.isFile() || f.length() > (1 << 20)) return null;
            return new String(Files.readAllBytes(f.toPath()), java.nio.charset.StandardCharsets.UTF_8);
        } catch (Exception | LinkageError e) {
            tell("reading what the hero carries", e);
            return null;
        }
    }

    /**
     * The point of the camp's ground (height `groundY`) under a point of the
     * screen: {x, z}, or nil when the view doesn't meet the ground there. For
     * keepsakes put down in the camp (KnoxMenuKeep): the scene's own unproject
     * (its camera is Knox's perspective one), a ray from the near to the far
     * plane, met with the ground.
     */
    @LuaMethod(name = "knoxMenuGround", global = true)
    public static KahluaTable knoxMenuGround(UI3DScene scene, double uiX, double uiY, double groundY) {
        if (scene == null) return null;
        try {
            org.joml.Vector3f a = scene.uiToScene((org.joml.Matrix4f) null, (float) uiX, (float) uiY, 0f, new org.joml.Vector3f());
            org.joml.Vector3f b = scene.uiToScene((org.joml.Matrix4f) null, (float) uiX, (float) uiY, 1f, new org.joml.Vector3f());
            float dy = b.y - a.y;
            if (Math.abs(dy) < 1.0e-6f) return null;
            float t = ((float) groundY - a.y) / dy;
            if (t < 0f || t > 1f) return null;
            KahluaTable out = LuaManager.platform.newTable();
            out.rawset("x", Double.valueOf(a.x + (b.x - a.x) * t));
            out.rawset("z", Double.valueOf(a.z + (b.z - a.z) * t));
            return out;
        } catch (Exception | LinkageError e) {
            tell("finding the ground under the mouse", e);
            return null;
        }
    }

    /** item types the heroes have taken off at the fire, by save: not drawn on them (the bag lies beside them) */
    static final java.util.Map<String, String> TAKEN_OFF = Collections.synchronizedMap(new java.util.HashMap<>());

    @LuaMethod(name = "knoxMenuTakeOff", global = true)
    public static void knoxMenuTakeOff(String save, String type) {
        if (save == null) return;
        if (type == null || type.isEmpty()) TAKEN_OFF.remove(save);
        else TAKEN_OFF.put(save, type);
    }

    /**
     * The bag lying beside a hero gets its own colours: the game's models of
     * clothes on the ground have no texture of their own - the game puts on the
     * one of the thing's look as it draws it - and in the scene the bag came out
     * see-through (the author, 2026-10-16). The texture is the one the hero's
     * bag had (its look in the snapshot, before it was taken off).
     */
    @LuaMethod(name = "knoxMenuBagSkin", global = true)
    public static boolean knoxMenuBagSkin(UI3DScene scene, String id, String save, String type) {
        if (scene == null || id == null || save == null || type == null || save.contains("..")) return false;
        try {
            Snapshot s = readFile(new File(ZomboidFileSystem.instance.getSaveDir() + File.separator + save, FILE));
            if (s == null) return false;
            zombie.core.skinnedmodel.visual.ItemVisual found = null;
            for (int i = 0; i < s.owner.items.size(); i++) {
                zombie.core.skinnedmodel.visual.ItemVisual iv = s.owner.items.get(i);
                String own = i < s.real.length && s.real[i] != null && !s.real[i].isEmpty() ? s.real[i] : (iv == null ? null : iv.getItemType());
                if (type.equals(own)) {
                    found = iv;
                    break;
                }
            }
            zombie.scripting.objects.Item script = zombie.scripting.ScriptManager.instance.getItem(type);
            zombie.core.skinnedmodel.population.ClothingItem ci = script == null ? null : script.getClothingItemAsset();
            if (ci == null) return false;
            // (after a start the game is still reading its clothing items: the
            // bag's has no textures yet and it stayed see-through - Lua asks again)
            if (!ci.isReady()) {
                if (ci.isEmpty() && CLOTHES_ASKED.add(ci)) ci.getAssetManager().load(ci);
                return false;
            }
            String tex = null;
            if (found != null) {
                tex = found.getTextureChoice(ci);
                if (tex == null || tex.isEmpty()) tex = found.getBaseTexture(ci);
            }
            if (tex == null || tex.isEmpty()) tex = ci.GetATexture();
            if (tex == null || tex.isEmpty()) return false;
            zombie.core.textures.Texture t = zombie.core.textures.Texture.getSharedTexture(
                tex.contains("media/") ? tex : "media/textures/" + tex + ".png");
            if (t == null) return false;
            if (sceneObjects == null) sceneObjects = find(UI3DScene.class, "objects");
            ArrayList<?> objects = (ArrayList<?>) sceneObjects.get(scene);
            for (int i = 0; i < objects.size(); i++) {
                Object o = objects.get(i);
                Field idF = find(o.getClass(), "id");
                if (idF == null || !id.equalsIgnoreCase((String) idF.get(o))) continue;
                Field texF = find(o.getClass(), "texture");
                if (texF == null || !zombie.core.textures.Texture.class.isAssignableFrom(texF.getType())) return false;
                texF.set(o, t);
                return true;
            }
            return false;
        } catch (Exception | LinkageError e) {
            tell("colouring the hero's bag", e);
            return false;
        }
    }

    static void takeOff(Snapshot s, String save) {
        String type = TAKEN_OFF.get(save);
        if (type == null) return;
        for (int i = s.owner.items.size() - 1; i >= 0; i--) {
            zombie.core.skinnedmodel.visual.ItemVisual iv = s.owner.items.get(i);
            String own = i < s.real.length && s.real[i] != null && !s.real[i].isEmpty() ? s.real[i] : (iv == null ? null : iv.getItemType());
            if (!type.equals(own)) continue;
            s.owner.items.remove(i);
            if (i < s.real.length) {
                String[] r = new String[s.real.length - 1];
                System.arraycopy(s.real, 0, r, 0, i);
                System.arraycopy(s.real, i + 1, r, i, s.real.length - i - 1);
                s.real = r;
            }
            return;
        }
    }

    /** saves whose heroes wear their real things where a look never came (kept for the session) */
    static final Set<String> SUBSTITUTED = Collections.synchronizedSet(new java.util.HashSet<>());

    /**
     * Each look that is not there (not loaded) and has a real worn item behind
     * it is swapped for that item, as the game draws it without the mod (its
     * blood, dirt and holes kept). Returns how many.
     */
    static int substitute(Snapshot s) {
        int n = 0;
        for (int i = 0; i < s.owner.items.size() && i < s.real.length; i++) {
            String type = s.real[i];
            if (type == null || type.isEmpty()) continue;
            zombie.core.skinnedmodel.visual.ItemVisual iv = s.owner.items.get(i);
            zombie.core.skinnedmodel.population.ClothingItem ci = iv == null ? null : iv.getClothingItem();
            if (ci != null && ci.isReady()) continue;
            zombie.scripting.objects.Item script = zombie.scripting.ScriptManager.instance.getItem(type);
            if (script == null || script.getClothingItemAsset() == null) continue;
            zombie.core.skinnedmodel.visual.ItemVisual r = new zombie.core.skinnedmodel.visual.ItemVisual();
            r.setItemType(type);
            r.setClothingItemName(script.getClothingItemAsset().mame);
            if (iv != null) {
                r.copyBlood(iv);
                r.copyDirt(iv);
                r.copyHoles(iv);
                r.copyPatches(iv);
            }
            s.owner.items.set(i, r);
            n++;
        }
        return n;
    }

    /**
     * The hero's looks have been waited for and some never came: from now on
     * (this session) the hero wears the real things behind them. Returns how
     * many looks are swapped; 0 = nothing to do (Lua then shows the hero as it is).
     */
    @LuaMethod(name = "knoxMenuClothesSubstitute", global = true)
    public static int knoxMenuClothesSubstitute(String save) {
        try {
            if (save == null || SUBSTITUTED.contains(save)) return 0;
            Snapshot s = read(save);
            if (s == null) return 0;
            int n = substitute(s);
            if (n > 0) {
                SUBSTITUTED.add(save);
                System.out.println("[Knox] menu hero: " + n + " looks that never came swapped for the real worn items (" + save + ")");
            }
            return n;
        } catch (Exception | LinkageError e) {
            tell("swapping the looks", e);
            return 0;
        }
    }

    /**
     * The snapshot files' bytes, by path, while their time and size stay the
     * same: the menu asks for a hero's snapshot many times a second while its
     * clothes load (knoxMenuClothesReady) and every half second while a bag is
     * coloured - read from the disk each time before (a performance pass, 2026-10-16).
     */
    static final java.util.HashMap<String, Object[]> FILE_CACHE = new java.util.HashMap<>();

    static byte[] bytesOf(File file) throws java.io.IOException {
        String key = file.getPath();
        long time = file.lastModified(), size = file.length();
        synchronized (FILE_CACHE) {
            Object[] c = FILE_CACHE.get(key);
            if (c != null && (Long) c[0] == time && (Long) c[1] == size) return (byte[]) c[2];
        }
        byte[] b = Files.readAllBytes(file.toPath());
        synchronized (FILE_CACHE) {
            if (FILE_CACHE.size() > 64) FILE_CACHE.clear();
            FILE_CACHE.put(key, new Object[] {time, size, b});
        }
        return b;
    }

    static Snapshot readFile(File file) {
        try {
            if (!file.isFile()) return null;
            ByteBuffer bb = ByteBuffer.wrap(bytesOf(file));
            if (bb.getInt() != MAGIC) return null;
            int version = bb.getInt();
            if (version < 1 || version > VERSION) return null;
            int worldVersion = bb.getInt();
            Snapshot s = new Snapshot();
            s.name = GameWindow.ReadString(bb);
            s.hours = bb.getDouble();
            s.health = bb.getFloat();
            s.dead = bb.get() != 0;
            s.owner.female = bb.get() != 0;
            s.kills = bb.getInt();
            s.owner.visual.load(bb, worldVersion);
            s.owner.items.load(bb, worldVersion);
            if (version >= 2) s.weapon = nz(GameWindow.ReadString(bb));
            if (version >= 3) s.extra = nz(GameWindow.ReadString(bb));
            if (version >= 4) {
                int n = bb.getInt();
                if (n < 0 || n > 1000) n = 0;
                s.real = new String[n];
                for (int i = 0; i < n; i++) s.real[i] = nz(GameWindow.ReadString(bb));
            }
            return s;
        } catch (Exception | LinkageError e) {
            tell("reading " + file.getParentFile().getName() + "'s snapshot", e);
            return null;
        }
    }

    /** {name, hours, health, dead, female, kills} of a save's snapshot, or nil without one. */
    @LuaMethod(name = "knoxMenuInfo", global = true)
    public static KahluaTable knoxMenuInfo(String save) {
        Snapshot s = read(save);
        if (s == null) return null;
        KahluaTable t = LuaManager.platform.newTable();
        t.rawset("name", s.name);
        t.rawset("hours", Double.valueOf(s.hours));
        t.rawset("health", Double.valueOf(s.health));
        t.rawset("dead", Boolean.valueOf(s.dead));
        t.rawset("female", Boolean.valueOf(s.owner.female));
        t.rawset("kills", Double.valueOf(s.kills));
        t.rawset("weapon", s.weapon);
        t.rawset("extra", s.extra);
        return t;
    }

    // ------------------------------------------------------------------- scene

    private static Field sceneObjects;
    private static Field objectId;
    private static Field characterModel;

    static Field find(Class<?> c, String name) {
        while (c != null) {
            try {
                Field f = c.getDeclaredField(name);
                f.setAccessible(true);
                return f;
            } catch (NoSuchFieldException e) {
                c = c.getSuperclass();
            }
        }
        return null;
    }

    /** AnimatedModel of a scene character (UI3DScene's "createCharacter"), or null. */
    static AnimatedModel modelOf(UI3DScene scene, String id) {
        if (scene == null || id == null) return null;
        try {
            if (sceneObjects == null) sceneObjects = find(UI3DScene.class, "objects");
            ArrayList<?> objects = (ArrayList<?>) sceneObjects.get(scene);
            for (int i = 0; i < objects.size(); i++) {
                Object o = objects.get(i);
                if (objectId == null) objectId = find(o.getClass(), "id");
                if (!id.equalsIgnoreCase((String) objectId.get(o))) continue;
                Field f = characterModel;
                if (f == null || !f.getDeclaringClass().isInstance(o)) f = find(o.getClass(), "animatedModel");
                if (f == null) return null;
                characterModel = f;
                return (AnimatedModel) f.get(o);
            }
        } catch (ReflectiveOperationException | RuntimeException e) {
            // not a character, or the class changed
        }
        return null;
    }

    /**
     * Before the scene is built: the model manager (the menu doesn't start it
     * until a character is shown) and the anim set with Knox's states. Returns
     * false when the states are missing (the mod's AnimSets were not read).
     */
    @LuaMethod(name = "knoxMenuInit", global = true)
    public static boolean knoxMenuInit() {
        UNKNOWN_SINCE.clear();   // (each visit to the menu waits for them anew)
        try {
            ModelManager.instance.create();
            AnimationSet set = AnimationSet.GetAnimationSet(ANIM_SET, false);
            if (!set.containsState("knoxmenu_sit")) set = AnimationSet.GetAnimationSet(ANIM_SET, true);
            return set.containsState("knoxmenu_sit");
        } catch (Exception | LinkageError e) {
            return false;
        }
    }

    static void dress(AnimatedModel model, Snapshot s, boolean zombie) {
        model.setAnimSetName(ANIM_SET);
        model.setAnimate(true);
        model.setAlpha(1f);
        if (s == null) return;   // stays in the scene's default look (a bare body)
        Owner o = s.owner;
        o.zombie = zombie;
        if (zombie) {
            o.visual.randomBlood();
            o.visual.randomDirt();
        }
        model.setOutfitName(null, o.female, zombie);   // drops the scene's pending "Naked" outfit
        setLook(model, o);
    }

    /**
     * The hero's body and clothes onto a model. Should the clothes not go on
     * (something a mod gave the hero that the menu can't build), the hero is
     * shown without them rather than as nobody: the right body, in the light.
     */
    static void setLook(AnimatedModel model, Owner o) {
        try {
            model.setModelData(o.visual, o.items);
        } catch (Exception | LinkageError e) {
            tell("dressing (clothes left out)", e);
            model.setModelData(o.visual, new ItemVisuals());
        }
    }

    /**
     * Dress a scene character as the save's hero (as a zombie: the same body
     * and clothes, risen). Without a snapshot the character is only made ready
     * to animate and false is returned.
     */
    @LuaMethod(name = "knoxMenuDress", global = true)
    public static boolean knoxMenuDress(UI3DScene scene, String id, String save, boolean zombie) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null) return false;
        try {
            Snapshot s = read(save);
            dress(model, s, zombie);
            return s != null;
        } catch (Exception | LinkageError e) {
            tell("dressing", e);
            return false;
        }
    }

    /** The same for a UI3DModel (the portrait in the hover panel). */
    @LuaMethod(name = "knoxMenuDressUI", global = true)
    public static boolean knoxMenuDressUI(UI3DModel ui, String save, boolean zombie) {
        AnimatedModel model = ui == null ? null : KnoxAvatar.modelOf(ui);
        if (model == null) return false;
        try {
            Snapshot s = read(save);
            if (s == null) return false;
            Owner o = s.owner;
            o.zombie = zombie;
            model.setOutfitName(null, o.female, zombie);
            setLook(model, o);
            return true;
        } catch (Exception | LinkageError e) {
            tell("dressing the portrait", e);
            return false;
        }
    }

    /** Switch a scene character to one of the anim set's states (blended by the animator). */
    @LuaMethod(name = "knoxMenuAnim", global = true)
    public static boolean knoxMenuAnim(UI3DScene scene, String id, String state) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null || state == null) return false;
        try {
            model.setState(state);
            AdvancedAnimator animator = model.getAdvancedAnimator();
            if (animator == null || !animator.containsState(state)) return false;
            // true once the animator is seen in the state: a new model's action
            // context puts it back to "idle" on its first update, so Lua asks
            // again until this confirms
            if (state.equalsIgnoreCase(animator.getCurrentStateName())) return true;
            // The animator can believe it is in the state while it plays the
            // set's idle (asked before the model was ready): setState then
            // returns at once and the hero stands. Going through another state
            // makes it a real change.
            animator.setState(state.equalsIgnoreCase("knoxmenu_stand") ? "knoxmenu_sit" : "knoxmenu_stand");
            animator.setState(state);
            return false;
        } catch (RuntimeException e) {
            return false;   // the state is applied with the next setModelData
        }
    }

    /**
     * Is the character really in its pose - playing `clip` at (nearly) full
     * weight?
     *   0  not yet: the model or the clip is still being loaded (after a fresh
     *      start the game reads its ~2000 animations in the background, and a
     *      character meanwhile stands in the set's idle);
     *   1  the clip is loaded but the character is not playing it: the animator
     *      entered the state before the clip was there and never looked again
     *      (seen 2026-10-13: a hero stood until its next change of pose, a
     *      zombie for good) - Lua then asks to enter the state anew;
     *   2  it is.
     */
    @LuaMethod(name = "knoxMenuPosed", global = true)
    public static int knoxMenuPosed(UI3DScene scene, String id, String clip) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null || clip == null) return 0;
        try {
            if (!model.hasAnimationPlayer() || !model.isReadyToRender()) return 0;
            AnimationPlayer player = model.getAnimationPlayer();
            if (player == null || !player.isReady()) return 0;
            SkinningData data = player.getSkinningData();
            if (data == null || data.animationClips == null || data.animationClips.get(clip) == null) return 0;
            if (player.getMultiTrack() == null) return 1;
            for (zombie.core.skinnedmodel.animation.AnimationTrack track : player.getMultiTrack().getTracks()) {
                if (track == null) continue;
                AnimationClip c = track.getClip();
                boolean same = (c != null && clip.equalsIgnoreCase(c.name)) || clip.equalsIgnoreCase(track.getName());
                // (present and well in the blend is enough: Lua gives the blend its time,
                // and a weight read from a blend curve need not reach 1)
                if (same && track.getBlendWeight() >= 0.3f) return 2;
            }
            return 1;
        } catch (RuntimeException e) {
            return 0;
        }
    }

    /** Enter a state anew (through another one, so that it is a real change): see knoxMenuPosed. */
    @LuaMethod(name = "knoxMenuReenter", global = true)
    public static void knoxMenuReenter(UI3DScene scene, String id, String state) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null || state == null) return;
        try {
            AdvancedAnimator animator = model.getAdvancedAnimator();
            if (animator == null || !animator.containsState(state)) return;
            animator.setState(state.equalsIgnoreCase("knoxmenu_stand") ? "knoxmenu_sit" : "knoxmenu_stand");
            animator.setState(state);
            model.setState(state);
        } catch (RuntimeException e) {
            // the next ask tries again
        }
    }

    /**
     * Are the clothes of a save's hero ready to be put on - is every clothing
     * item of the snapshot loaded?
     *
     * The game loads its clothing items in the background after it starts, and
     * a character's texture is built from the ones that are ready at that
     * moment (ModelInstanceTextureCreator.init leaves the others out). Nothing
     * builds it again when they arrive: a hero dressed too early sat at the
     * fire naked, or in trousers only, differently on every start, while the
     * portrait in the card - built later - was dressed (seen 2026-10-13, once
     * the mod that cached the game's loading was gone). Lua waits for this and
     * then has the character dressed anew (knoxMenuRefreshClothes).
     */
    @LuaMethod(name = "knoxMenuClothesReady", global = true)
    public static boolean knoxMenuClothesReady(String save) {
        // Only the hero's own items are waited for. (It used to wait for the
        // game's whole wardrobe as well - OutfitManager.isLoadingClothingItems,
        // thousands of files read one by one after a start - and the camp stayed
        // dark for seconds over clothes nobody at the fire wears.) An item that
        // failed to load is no longer waited for: it never will be ready.
        try {
            return clothesMissing(save, true).isEmpty();
        } catch (Exception | LinkageError e) {
            tell("asking for the clothes", e);
            return true;   // nothing to wait for that we can tell
        }
    }

    /**
     * The menu's own animations to the front of the game's loading queue.
     *
     * After a start the game reads its ~2200 animations in the background, in
     * the order of its folders, 16 files at a time (FileSystemImpl: `pending`,
     * sorted by FileTask.priority when added; the game itself puts Bob_Idle,
     * Bob_Walk and Bob_Run first). Without a mod that caches them, the few the
     * camp needs came after seconds (7 s in a test of 2026-10-14) and the
     * heroes waited for them. Here the files whose names end with one of
     * `clips` (comma separated) get a higher priority, and those already
     * waiting are moved to the head of the line - nothing is loaded twice,
     * dropped or loaded differently; the game's own tasks just go in another
     * order. Returns how many were moved (0 if nothing waits or the game's
     * fields are not what this expects: then it does nothing at all).
     */
    @LuaMethod(name = "knoxMenuHurryClips", global = true)
    public static int knoxMenuHurryClips(String clips) {
        if (clips == null || clips.isEmpty()) return 0;
        try {
            Object fs = GameWindow.fileSystem;
            if (fs == null) return 0;
            Field pendingF = find(fs.getClass(), "pending");
            Field addedF = find(fs.getClass(), "added");
            Field lockF = find(fs.getClass(), "lock");
            if (pendingF == null || addedF == null || lockF == null) return 0;
            Object lockO = lockF.get(fs);
            if (!(lockO instanceof java.util.concurrent.atomic.AtomicBoolean)) return 0;
            java.util.concurrent.atomic.AtomicBoolean lock = (java.util.concurrent.atomic.AtomicBoolean) lockO;
            String[] want = clips.toLowerCase(java.util.Locale.ROOT).split(",");
            int moved = 0;
            // the same lock the game takes for these lists (a short wait at most)
            long until = System.nanoTime() + 50_000_000L;
            while (!lock.compareAndSet(false, true)) {
                if (System.nanoTime() > until) return 0;
                Thread.onSpinWait();
            }
            try {
                // waiting to be sorted in: a high priority sorts them first
                for (Object item : (ArrayList<?>) addedF.get(fs)) {
                    zombie.fileSystem.FileTask task = taskOf(item);
                    if (isWanted(task, want)) task.setPriority(9);
                }
                // already in line: to its head, in their own order
                @SuppressWarnings("unchecked")
                ArrayList<Object> pending = (ArrayList<Object>) pendingF.get(fs);
                ArrayList<Object> front = new ArrayList<>();
                for (int i = 0; i < pending.size(); i++) {
                    zombie.fileSystem.FileTask task = taskOf(pending.get(i));
                    if (isWanted(task, want)) {
                        task.setPriority(9);
                        front.add(pending.remove(i--));
                    }
                }
                pending.addAll(0, front);
                moved = front.size();
            } finally {
                lock.set(false);
            }
            return moved;
        } catch (Exception | LinkageError e) {
            tell("hurrying the menu's animations", e);
            return 0;
        }
    }

    static Field asyncItemTask;

    static zombie.fileSystem.FileTask taskOf(Object asyncItem) throws ReflectiveOperationException {
        if (asyncItem == null) return null;
        if (asyncItemTask == null || !asyncItemTask.getDeclaringClass().isInstance(asyncItem)) {
            asyncItemTask = find(asyncItem.getClass(), "task");
            if (asyncItemTask == null) return null;
        }
        Object t = asyncItemTask.get(asyncItem);
        return t instanceof zombie.fileSystem.FileTask ? (zombie.fileSystem.FileTask) t : null;
    }

    static boolean isWanted(zombie.fileSystem.FileTask task, String[] want) {
        if (!(task instanceof zombie.core.skinnedmodel.model.FileTask_LoadAnimation)) return false;
        String name = ((zombie.core.skinnedmodel.model.FileTask_LoadAnimation) task).getRawFileName();
        if (name == null) return false;
        name = name.toLowerCase(java.util.Locale.ROOT);
        int dot = name.lastIndexOf('.');
        if (dot > name.lastIndexOf('/')) name = name.substring(0, dot);
        for (String w : want) {
            w = w.trim();
            if (!w.isEmpty() && (name.equals(w) || name.endsWith("/" + w))) return true;
        }
        return false;
    }

    /** clothing items whose loading Knox has asked for itself (once each) */
    static final Set<Object> CLOTHES_ASKED = Collections.newSetFromMap(new WeakHashMap<>());

    /**
     * The hero's clothing items not loaded yet, by name. With `kick`, one that
     * nothing is loading (left empty by the game - its outfits are rebuilt when
     * a game is left for the menu) is asked for.
     */
    /**
     * When each save's hero was first found with clothes the game could not
     * name yet. A player's hero came to the fire in underwear (vanilla clothes,
     * only the backpack on; 2026-10-16): an item whose script or clothing item
     * the game has not set up again after leaving a game gives no ClothingItem
     * at all, and such an item was taken as "nothing to wait for" - the hero
     * was built without it for good. They are waited for now, but only a few
     * seconds: a thing from a mod that is off in the menu never shows up.
     */
    static final java.util.HashMap<String, Long> UNKNOWN_SINCE = new java.util.HashMap<>();
    static final long UNKNOWN_WAIT_MS = 4000;

    static List<String> clothesMissing(String save, boolean kick) {
        List<String> out = new ArrayList<>();
        Snapshot s = read(save);
        if (s == null) return out;
        boolean unknownWait = true;
        for (int i = 0; i < s.owner.items.size(); i++) {
            zombie.core.skinnedmodel.visual.ItemVisual iv = s.owner.items.get(i);
            zombie.core.skinnedmodel.population.ClothingItem ci = iv == null ? null : iv.getClothingItem();
            if (ci == null) {
                String type = iv == null ? null : iv.getItemType();
                if (type == null || type.isEmpty()) continue;
                if (unknownWait) {
                    long now = System.currentTimeMillis();
                    Long since = UNKNOWN_SINCE.putIfAbsent(save, now);
                    unknownWait = since == null || now - since < UNKNOWN_WAIT_MS;
                }
                if (unknownWait) out.add("?" + type);
                continue;
            }
            if (!ci.isEmpty()) continue;
            out.add(ci.mame != null ? ci.mame : String.valueOf(ci.getPath()));
            if (kick && CLOTHES_ASKED.add(ci)) {
                try {
                    ci.getAssetManager().load(ci);
                } catch (RuntimeException e) {
                    tell("loading a clothing item", e);
                }
            }
        }
        return out;
    }

    /**
     * The hero's clothes as the menu sees them, for the log: how many the
     * snapshot holds, and those the game can't name or hasn't loaded.
     */
    @LuaMethod(name = "knoxMenuClothesNote", global = true)
    public static String knoxMenuClothesNote(String save) {
        try {
            Snapshot s = read(save);
            if (s == null) return "no snapshot";
            StringBuilder unknown = new StringBuilder(), loading = new StringBuilder();
            for (int i = 0; i < s.owner.items.size(); i++) {
                zombie.core.skinnedmodel.visual.ItemVisual iv = s.owner.items.get(i);
                if (iv == null) continue;
                zombie.core.skinnedmodel.population.ClothingItem ci = iv.getClothingItem();
                if (ci == null) unknown.append(' ').append(iv.getItemType());
                else if (!ci.isReady()) loading.append(' ').append(ci.mame);
            }
            return s.owner.items.size() + " in the snapshot, unknown [" + unknown.toString().trim()
                + "], not ready [" + loading.toString().trim() + "]";
        } catch (Exception | LinkageError e) {
            return "? " + e;
        }
    }

    /**
     * Why a scene character is not shown yet, in a line for the log: the
     * model, its animation, the clip of its pose, the clothes.
     */
    @LuaMethod(name = "knoxMenuWhy", global = true)
    public static String knoxMenuWhy(UI3DScene scene, String id, String clip, String save) {
        StringBuilder b = new StringBuilder();
        try {
            AnimatedModel model = modelOf(scene, id);
            if (model == null) return "no model";
            b.append("player ").append(model.hasAnimationPlayer());
            AnimationPlayer player = model.hasAnimationPlayer() ? model.getAnimationPlayer() : null;
            b.append(", player ready ").append(player != null && player.isReady());
            b.append(", models ready ").append(model.isReadyToRender());
            b.append(", drawn ").append(model.isRendered());
            b.append(", baked ").append(texturesBaked(model));
            SkinningData data = player == null ? null : player.getSkinningData();
            int clips = data == null || data.animationClips == null ? -1 : data.animationClips.size();
            b.append(", clips ").append(clips);
            b.append(", clip ").append(clip).append(' ')
                .append(data != null && data.animationClips != null && clip != null && data.animationClips.get(clip) != null);
            AdvancedAnimator animator = model.getAdvancedAnimator();
            b.append(", state ").append(animator == null ? "-" : animator.getCurrentStateName());
            if (player != null && player.getMultiTrack() != null) {
                b.append(", tracks");
                for (zombie.core.skinnedmodel.animation.AnimationTrack track : player.getMultiTrack().getTracks()) {
                    if (track == null) continue;
                    b.append(' ').append(track.getName()).append('=').append(String.format("%.2f", track.getBlendWeight()));
                }
            }
            b.append(", anims loading ").append(ModelManager.instance.isLoadingAnimations());
            zombie.core.skinnedmodel.population.OutfitManager om = zombie.core.skinnedmodel.population.OutfitManager.instance;
            b.append(", wardrobe loading ").append(om != null && om.isLoadingClothingItems());
            if (save != null) b.append(", clothes missing ").append(clothesMissing(save, false));
        } catch (Exception | LinkageError e) {
            b.append(" / ").append(e);
        }
        return b.toString();
    }

    /** Have a scene character built anew from its visuals (the game's own "a clothing item changed"). */
    @LuaMethod(name = "knoxMenuRefreshClothes", global = true)
    public static void knoxMenuRefreshClothes(UI3DScene scene, String id) {
        AnimatedModel model = modelOf(scene, id);
        if (model != null) model.clothingItemChanged("");
    }

    /** The same for a UI3DModel (the portrait in the hover card). */
    @LuaMethod(name = "knoxMenuRefreshClothesUI", global = true)
    public static void knoxMenuRefreshClothesUI(UI3DModel ui) {
        AnimatedModel model = ui == null ? null : KnoxAvatar.modelOf(ui);
        if (model != null) model.clothingItemChanged("");
    }

    /** How solid a scene character is drawn, 0..1 (the game's own "Alpha" of a character): for fading it in. */
    @LuaMethod(name = "knoxMenuAlpha", global = true)
    public static void knoxMenuAlpha(UI3DScene scene, String id, double alpha) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null) return;
        model.setAlpha((float) Math.max(0, Math.min(1, alpha)));
    }

    /**
     * Where a scene character is in a clip it plays, 0..1 of the clip (-1: not
     * playing it): the walking hero's steps are played as his feet come down.
     */
    @LuaMethod(name = "knoxMenuTrackFraction", global = true)
    public static double knoxMenuTrackFraction(UI3DScene scene, String id, String clip) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null || clip == null) return -1;
        try {
            AnimationPlayer player = model.getAnimationPlayer();
            if (player == null || !player.isReady() || player.getMultiTrack() == null) return -1;
            for (zombie.core.skinnedmodel.animation.AnimationTrack track : player.getMultiTrack().getTracks()) {
                if (track == null) continue;
                AnimationClip c = track.getClip();
                boolean same = (c != null && clip.equalsIgnoreCase(c.name)) || clip.equalsIgnoreCase(track.getName());
                if (same && track.getBlendWeight() >= 0.3f) return track.getCurrentTimeFraction();
            }
            return -1;
        } catch (RuntimeException e) {
            return -1;
        }
    }

    /** Length of an animation clip in seconds (-1 if unknown yet). */
    @LuaMethod(name = "knoxMenuClipSeconds", global = true)
    public static double knoxMenuClipSeconds(UI3DScene scene, String id, String clip) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null || clip == null) return -1;
        try {
            AnimationPlayer player = model.getAnimationPlayer();
            if (player == null || !player.isReady()) return -1;
            SkinningData data = player.getSkinningData();
            AnimationClip c = data == null || data.animationClips == null ? null : data.animationClips.get(clip);
            return c == null ? -1 : c.getDuration();
        } catch (RuntimeException e) {
            return -1;
        }
    }

    /** per scene character: the last foot positions (model space) and the speed measured so far */
    static final java.util.HashMap<String, double[]> FEET = new java.util.HashMap<>();

    /**
     * How fast a walking scene character must move so its feet don't slide,
     * scene units a second, measured on the live pose: the foot on the ground
     * (the lower one) goes back under the body exactly as fast as the body
     * should go forward. The clips' own movement can't tell: the game cuts it
     * out of them when they load (Bip01 and the root motion read 0 - 2026-10-16,
     * the dead "floated" along the fence). Call every frame while it walks;
     * -1 until a few steps have been measured. `reset` starts over.
     */
    @LuaMethod(name = "knoxMenuFootSpeed", global = true)
    public static double knoxMenuFootSpeed(UI3DScene scene, String id, boolean reset) {
        if (reset) {
            FEET.remove(id);
            return -1;
        }
        AnimatedModel model = modelOf(scene, id);
        if (model == null) return -1;
        try {
            AnimationPlayer player = model.getAnimationPlayer();
            if (player == null || !player.isReady()) return -1;
            SkinningData data = player.getSkinningData();
            if (data == null || data.boneIndices == null) return -1;
            Integer li = data.boneIndices.get("Bip01_L_Foot"), ri = data.boneIndices.get("Bip01_R_Foot");
            if (li == null || ri == null || li >= player.getModelTransformsCount() || ri >= player.getModelTransformsCount()) return -1;
            org.lwjgl.util.vector.Matrix4f l = player.getModelTransformAt(li), r = player.getModelTransformAt(ri);
            long now = System.nanoTime();
            // {time, lx, lz, rx, rz, speed sum, samples}
            double[] s = FEET.get(id);
            double lx = l.m30, ly = l.m31, lz = l.m32, rx = r.m30, ry = r.m31, rz = r.m32;
            if (s != null && lx == s[1] && lz == s[2] && rx == s[3] && rz == s[4]) {
                // (the pose not updated since the last call: nothing to measure yet)
                return s[6] < 20 ? -1 : s[5] / s[6] * 1.5;
            }
            if (s != null) {
                double dt = (now - s[0]) / 1e9;
                if (dt > 0.005 && dt < 0.2) {
                    boolean leftDown = ly <= ry;
                    double dx = leftDown ? lx - s[1] : rx - s[3];
                    double dz = leftDown ? lz - s[2] : rz - s[4];
                    double v = Math.sqrt(dx * dx + dz * dz) / dt;
                    // (a foot switching from swinging to planted jumps: those frames are left out)
                    if (v < 5) {
                        s[5] += v;
                        s[6] += 1;
                    }
                }
            } else {
                s = new double[7];
                FEET.put(id, s);
            }
            s[0] = now;
            s[1] = lx; s[2] = lz; s[3] = rx; s[4] = rz;
            if (s[6] < 20) return -1;
            return s[5] / s[6] * 1.5;   // (model units: a body 0.98 tall; the scene draws it 1.47)
        } catch (RuntimeException e) {
            return -1;
        }
    }

    /**
     * How far a bone goes from a clip's first key to its last, on the ground
     * (either way the clips may hold their up axis), or 0. By the bone's index:
     * the game's getTranslationLength looks keys up by name, and the loaded
     * clips' keys carry only the index - it read 0 for every bone.
     */
    static double travel(AnimationClip c, int idx) {
        try {
            zombie.core.skinnedmodel.animation.Keyframe[] k = c.getKeyframesForBone(idx, null);
            if (k == null || k.length < 2 || k[0].position == null || k[k.length - 1].position == null) return 0;
            org.lwjgl.util.vector.Vector3f a = k[0].position, b = k[k.length - 1].position;
            double dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
            return Math.max(Math.sqrt(dx * dx + dz * dz), Math.sqrt(dx * dx + dy * dy));
        } catch (RuntimeException e) {
            return 0;
        }
    }
    /** What the foot measure sees, for the log: the bones, their places, the samples. */
    @LuaMethod(name = "knoxMenuFootWhy", global = true)
    public static String knoxMenuFootWhy(UI3DScene scene, String id) {
        StringBuilder b = new StringBuilder();
        try {
            AnimatedModel model = modelOf(scene, id);
            if (model == null) return "no model";
            AnimationPlayer player = model.getAnimationPlayer();
            if (player == null) return "no player";
            SkinningData data = player.getSkinningData();
            b.append("ready ").append(player.isReady()).append(", transforms ").append(player.getModelTransformsCount());
            if (data != null && data.boneIndices != null) {
                b.append(", bones ").append(data.boneIndices.size()).append(", feet:");
                for (java.util.Map.Entry<String, Integer> e : data.boneIndices.entrySet()) {
                    String n = e.getKey();
                    if (n == null || !n.toLowerCase(java.util.Locale.ROOT).contains("foot")) continue;
                    b.append(' ').append(n).append('=').append(e.getValue());
                    if (e.getValue() < player.getModelTransformsCount()) {
                        org.lwjgl.util.vector.Matrix4f m = player.getModelTransformAt(e.getValue());
                        b.append(String.format(java.util.Locale.ROOT, "(%.3f %.3f %.3f)", m.m30, m.m31, m.m32));
                    }
                }
            }
            // the bones that travel furthest in the walk being played (its clip's first to last key)
            if (player.getMultiTrack() != null && data != null && data.boneIndices != null) {
                for (zombie.core.skinnedmodel.animation.AnimationTrack t : player.getMultiTrack().getTracks()) {
                    AnimationClip c = t == null ? null : t.getClip();
                    if (c == null || c.name == null || !c.name.contains("Walk")) continue;
                    b.append(", ").append(c.name).append(String.format(java.util.Locale.ROOT, " %.2fs moves:", c.getDuration()));
                    java.util.ArrayList<String> moves = new java.util.ArrayList<>();
                    for (java.util.Map.Entry<String, Integer> e : data.boneIndices.entrySet()) {
                        double best = travel(c, e.getValue());
                        if (best > 0.01) moves.add(String.format(java.util.Locale.ROOT, "%s=%.3f", e.getKey(), best));
                    }
                    b.append(' ').append(moves.isEmpty() ? "none" : String.join(" ", moves));
                    b.append(", root motion frames ").append(c.getRootMotionFrameCount());
                    break;
                }
            }
            double[] s = FEET.get(id);
            if (s != null) b.append(", samples ").append((int) s[6]).append(String.format(java.util.Locale.ROOT, " avg %.4f", s[6] > 0 ? s[5] / s[6] : 0));
            if (player.getMultiTrack() != null) {
                b.append(", tracks");
                for (zombie.core.skinnedmodel.animation.AnimationTrack t : player.getMultiTrack().getTracks()) {
                    if (t != null) b.append(' ').append(t.getName()).append(String.format(java.util.Locale.ROOT, "@%.2f w%.2f", t.getCurrentTimeValue(), t.getBlendWeight()));
                }
            }
        } catch (Exception | LinkageError e) {
            b.append(" / ").append(e);
        }
        return b.toString();
    }

    /**
     * How far a walk clip carries the body in one cycle, in the clip's own
     * units (its root motion: what the game moves its characters by), or -1.
     * The scene moves its walkers itself; their speed is set from this so the
     * feet don't slide (the dead "floated" along the fence, 2026-10-16).
     */
    @LuaMethod(name = "knoxMenuClipStride", global = true)
    public static double knoxMenuClipStride(UI3DScene scene, String id, String clip) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null || clip == null) return -1;
        try {
            AnimationPlayer player = model.getAnimationPlayer();
            if (player == null || !player.isReady()) return -1;
            SkinningData data = player.getSkinningData();
            AnimationClip c = data == null || data.animationClips == null ? null : data.animationClips.get(clip);
            if (c == null) return -1;
            // the game takes a walker's movement from its Bip01 bone (the anim
            // sets' m_DeferredBoneName), as AnimationClip.getTranslationLength
            // measures it; bone 0 (Dummy01) stays put - 0 the first time
            double best = 0;
            if (data.boneIndices != null) {
                for (String bone : new String[] {"Translation_Data", "Bip01"}) {
                    Integer idx = data.boneIndices.get(bone);
                    if (idx != null) best = Math.max(best, travel(c, idx));
                }
            }
            if (best > 0) return best;
            zombie.core.skinnedmodel.animation.Keyframe a = null, b = null;
            int n = c.getRootMotionFrameCount();
            if (n > 1) {
                a = c.getRootMotionFrameAt(0);
                b = c.getRootMotionFrameAt(n - 1);
            } else {
                zombie.core.skinnedmodel.animation.Keyframe[] root = c.getKeyframesForBone(0, null);
                if (root != null && root.length > 1) {
                    a = root[0];
                    b = root[root.length - 1];
                }
            }
            if (a == null || b == null || a.position == null || b.position == null) return -1;
            float dx = b.position.x - a.position.x, dy = b.position.y - a.position.y, dz = b.position.z - a.position.z;
            return Math.sqrt(dx * dx + dy * dy + dz * dz);
        } catch (RuntimeException e) {
            return -1;
        }
    }

    /**
     * True when the character is really on the screen: its models, textures
     * and animations are loaded AND a frame with it has been drawn. Loaded is
     * not enough - seen 2026-10-13: "ready to render" for many seconds while
     * the game was still baking the clothes' texture and nothing was drawn.
     * (The drawn flag belongs to the render thread's state and is cleared for
     * every frame: Lua asks every frame and keeps the first yes.)
     */
    @LuaMethod(name = "knoxMenuReady", global = true)
    public static boolean knoxMenuReady(UI3DScene scene, String id) {
        AnimatedModel model = modelOf(scene, id);
        try {
            if (model == null || !model.hasAnimationPlayer() || !model.isReadyToRender()) return false;
            // The drawn flag alone was not to be trusted: it belongs to one of
            // the renderer's three states and is cleared each time that state is
            // filled again, so a look at it from Lua mostly found it cleared -
            // after leaving a game, for good: heroes ready in every way waited
            // out the ten seconds (log 2026-10-14). What it stood for is kept by
            // the model itself: its clothes' texture has been baked (which the
            // render thread does as it draws the model).
            Boolean baked = texturesBaked(model);
            return baked != null ? baked : model.isRendered();
        } catch (RuntimeException e) {
            return false;
        }
    }

    static Field modelTextureCreator, modelUpdateTextures;

    /**
     * Has the model's texture (body and clothes) been baked, with no new bake
     * waiting? null when that can't be told (the game's fields changed).
     */
    static Boolean texturesBaked(AnimatedModel model) {
        try {
            if (modelTextureCreator == null) modelTextureCreator = find(AnimatedModel.class, "textureCreator");
            if (modelUpdateTextures == null) modelUpdateTextures = find(AnimatedModel.class, "updateTextures");
            if (modelTextureCreator == null || modelUpdateTextures == null) return null;
            if (modelUpdateTextures.getBoolean(model)) return false;   // a bake asked for, not begun
            Object tc = modelTextureCreator.get(model);
            return tc == null || ((zombie.core.skinnedmodel.model.ModelInstanceTextureCreator) tc).isRendered();
        } catch (ReflectiveOperationException | RuntimeException | LinkageError e) {
            return null;
        }
    }

    // ------------------------------------------------------------------ camera

    /** scene -> {fov (degrees), eye xyz, target xyz}: scenes drawn in perspective */
    public static final Map<UI3DScene, float[]> CAMERAS = Collections.synchronizedMap(new WeakHashMap<>());

    /**
     * UI3DScene draws orthographically (an editor view). The menu scene gets a
     * real camera: a field of view, a position and a point it looks at. Depth
     * then works as in any 3D scene, distant things are small.
     */
    @LuaMethod(name = "knoxMenuCamera", global = true)
    public static void knoxMenuCamera(UI3DScene scene, double fov, double ex, double ey, double ez,
                                      double tx, double ty, double tz) {
        if (scene == null) return;
        // (set every frame since the camera sways and follows the mouse: the array is reused)
        float[] c = CAMERAS.get(scene);
        if (c == null) {
            c = new float[7];
            CAMERAS.put(scene, c);
        }
        c[0] = (float) fov; c[1] = (float) ex; c[2] = (float) ey; c[3] = (float) ez;
        c[4] = (float) tx; c[5] = (float) ty; c[6] = (float) tz;
    }

    /**
     * The game's main menu plays an ambience of its own under the music (a TV's
     * hum, rain, thunder - its old menu room), heard even with the music off
     * (Machotoast08's report, 2026-10-14). It goes through the FMOD bus
     * "bus:/MenuAmbience": muted while the Knox camp is up (it has its own sounds).
     */
    // (the bus's place in the mixer is not known for sure - the strings bank lists
    // "MenuAmbience" among the buses but not under which group: every candidate
    // that exists is muted, and the answer says which ones did)
    private static final String[] MENU_AMBIENCE_BUSES = {
        "bus:/MenuAmbience", "bus:/Music/MenuAmbience", "bus:/Game/MenuAmbience",
        "bus:/InGame/MenuAmbience", "bus:/UI/MenuAmbience", "bus:/Ambience/MenuAmbience",
    };

    @LuaMethod(name = "knoxMenuMuteAmbience", global = true)
    public static String knoxMenuMuteAmbience(boolean mute) {
        StringBuilder sb = new StringBuilder();
        for (String path : MENU_AMBIENCE_BUSES) {
            try {
                long bus = fmod.javafmod.FMOD_Studio_System_GetBus(path);
                if (bus == 0L) continue;
                int r1 = fmod.javafmod.FMOD_Studio_Bus_SetMute(bus, mute);
                int r2 = fmod.javafmod.FMOD_Studio_Bus_SetVolume(bus, mute ? 0f : 1f);
                if (sb.length() > 0) sb.append(", ");
                sb.append(path).append(" mute=").append(r1).append(" volume=").append(r2);
            } catch (Throwable t) {
                // not there
            }
        }
        return sb.length() == 0 ? "no menu ambience bus found" : sb.toString();
    }

    @LuaMethod(name = "knoxMenuCameraOff", global = true)
    public static void knoxMenuCameraOff(UI3DScene scene) {
        if (scene != null) CAMERAS.remove(scene);
    }

    /** Replace the matrices UI3DScene has just calculated (advice code: public things only). */
    public static void applyCamera(UI3DScene scene, Matrix4f projection, Matrix4f modelView) {
        float[] c = CAMERAS.get(scene);
        if (c == null) return;
        float w = scene.getWidth().floatValue();
        float h = scene.getHeight().floatValue();
        if (w < 1f || h < 1f) return;
        projection.setPerspective((float) Math.toRadians(c[0]), w / h, 0.5f, 200f);
        modelView.setLookAt(c[1], c[2], c[3], c[4], c[5], c[6], 0f, 1f, 0f);
    }

    @Patch(className = "zombie.vehicles.UI3DScene", methodName = "calcMatrices")
    public static class Camera {
        @Patch.OnExit
        public static void exit(@Patch.This UI3DScene self, @Patch.Argument(0) Matrix4f projection,
                                @Patch.Argument(1) Matrix4f modelView) {
            if (!CAMERAS.isEmpty()) applyCamera(self, projection, modelView);
        }
    }

    // -------------------------------------------------------------- menu state

    /** True while the game is in the main menu state (not loading, not in game). */
    @LuaMethod(name = "knoxMenuInMenu", global = true)
    public static boolean knoxMenuInMenu() {
        try {
            GameStateMachine states = GameWindow.states;
            return states != null && states.current instanceof MainScreenState && states.forceNext == null;
        } catch (RuntimeException | LinkageError e) {
            return true;
        }
    }

    /**
     * The scene lies under the whole menu, so it gets no mouse events and looks
     * at the mouse itself. This tells if anything is in the way: a visible
     * child of the main screen (the menu's labels, an open sub-screen) or any
     * other window (a dialog, a popup).
     */
    @LuaMethod(name = "knoxMenuMouseFree", global = true)
    public static boolean knoxMenuMouseFree(UIElement own, UIElement main) {
        try {
            double mx = Mouse.getXA();
            double my = Mouse.getYA();
            ArrayList<UIElementInterface> all = UIManager.getUI();
            for (int i = 0; i < all.size(); i++) {
                UIElementInterface el = all.get(i);
                // (the scene itself lies under everything as the back-most element: never in the way)
                if (el == own || el == main || !el.isVisible() || el.isBackMost()) continue;
                if (el.isPointOver(mx, my)) return false;
            }
            if (main != null) {
                if (!main.isVisible()) return false;
                ArrayList<UIElement> children = main.getControls();
                for (int i = 0; i < children.size(); i++) {
                    UIElement c = children.get(i);
                    if (c.isVisible() && c.isPointOver(mx, my)) return false;
                }
            }
            return true;
        } catch (RuntimeException | LinkageError e) {
            return false;
        }
    }

    /** Diagnostics: the top-level UI elements in drawing order ("*" = the scene, "M" = the main screen). */
    @LuaMethod(name = "knoxMenuUiOrder", global = true)
    public static String knoxMenuUiOrder(UIElement own, UIElement main) {
        StringBuilder sb = new StringBuilder();
        try {
            ArrayList<UIElementInterface> all = UIManager.getUI();
            for (int i = 0; i < all.size(); i++) {
                UIElementInterface el = all.get(i);
                Object type = null;
                if (el instanceof UIElement && ((UIElement) el).getTable() != null) {
                    type = ((UIElement) el).getTable().rawget("Type");
                }
                sb.append(i).append(el == own ? "*" : el == main ? "M" : "").append(':')
                  .append(type != null ? type : el.getClass().getSimpleName())
                  .append(el.isVisible() ? "" : "(hidden)").append(' ');
            }
        } catch (RuntimeException | LinkageError e) {
            sb.append(e);
        }
        return sb.toString();
    }

    /**
     * Diagnostics: a picture of the frame as drawn so far. Queued with the
     * frame's own draw commands, so it shows exactly what was on the back
     * buffer at that point (Core.TakeFullScreenshot reads the front buffer,
     * which gave stale frames). GL state of the moment goes to the log.
     */
    public static class Shot extends TextureDraw.GenericDrawer {
        public final String file;

        public Shot(String file) {
            this.file = file;
        }

        @Override
        public void render() {
            try {
                int w = Core.getInstance().getScreenWidth();
                int h = Core.getInstance().getScreenHeight();
                ByteBuffer px = ByteBuffer.allocateDirect(w * h * 4);
                GL11.glPixelStorei(GL11.GL_PACK_ALIGNMENT, 1);
                GL11.glReadBuffer(GL11.GL_BACK);
                GL11.glReadPixels(0, 0, w, h, GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, px);
                BufferedImage img = new BufferedImage(w / 2, h / 2, BufferedImage.TYPE_INT_RGB);
                for (int y = 0; y < h / 2; y++) {
                    for (int x = 0; x < w / 2; x++) {
                        int i = ((h - 1 - y * 2) * w + x * 2) * 4;
                        img.setRGB(x, y, ((px.get(i) & 255) << 16) | ((px.get(i + 1) & 255) << 8) | (px.get(i + 2) & 255));
                    }
                }
                ImageIO.write(img, "png", new File(ZomboidFileSystem.instance.getScreenshotDir(), file));
                int[] vp = new int[4];
                GL11.glGetIntegerv(GL11.GL_VIEWPORT, vp);
                int[] sc = new int[4];
                GL11.glGetIntegerv(GL11.GL_SCISSOR_BOX, sc);
                System.out.println("[Knox] shot " + file + ": depthTest=" + GL11.glIsEnabled(GL11.GL_DEPTH_TEST)
                    + " depthFunc=" + GL11.glGetInteger(GL11.GL_DEPTH_FUNC) + " depthMask=" + GL11.glGetBoolean(GL11.GL_DEPTH_WRITEMASK)
                    + " blend=" + GL11.glIsEnabled(GL11.GL_BLEND) + " src=" + GL11.glGetInteger(GL11.GL_BLEND_SRC)
                    + " dst=" + GL11.glGetInteger(GL11.GL_BLEND_DST) + " alphaTest=" + GL11.glIsEnabled(GL11.GL_ALPHA_TEST)
                    + " stencil=" + GL11.glIsEnabled(GL11.GL_STENCIL_TEST) + " scissor=" + GL11.glIsEnabled(GL11.GL_SCISSOR_TEST)
                    + " cull=" + GL11.glIsEnabled(GL11.GL_CULL_FACE) + " colorMask=" + GL11.glGetBoolean(GL11.GL_COLOR_WRITEMASK)
                    + " viewport=" + vp[0] + "," + vp[1] + "," + vp[2] + "," + vp[3]
                    + " scissorBox=" + sc[0] + "," + sc[1] + "," + sc[2] + "," + sc[3]
                    + " program=" + GL11.glGetInteger(0x8B8D) + " fbo=" + GL11.glGetInteger(0x8CA6)
                    + " projStack=" + stackInfo(Core.getInstance().projectionMatrixStack)
                    + " mvStack=" + stackInfo(Core.getInstance().modelViewMatrixStack));
            } catch (Throwable t) {
                System.out.println("[Knox] shot " + file + " failed: " + t);
            }
        }
    }

    /**
     * After the scene's 3D drawing the color mask is left off with the stencil
     * and alpha tests on (seen in the captured GL state), so every sprite drawn
     * later in the frame - the menu - was invisible. Put back what the UI
     * expects, in the frame's own order of commands.
     */
    public static class ResetGL extends TextureDraw.GenericDrawer {
        @Override
        public void render() {
            // through the game's own record of the state (GLStateRenderThread):
            // at the first main menu it holds "color mask off, stencil on" left
            // from start-up, and its restore() after every character put that
            // back, so the heroes were drawn without color until a game was
            // loaded once
            try {
                GLStateRenderThread.ColorMask.set(true, true, true, true);
                GLStateRenderThread.StencilTest.set(false);
                GLStateRenderThread.StencilFunc.set(GL11.GL_ALWAYS, 255, 255);
                GLStateRenderThread.StencilOp.set(GL11.GL_KEEP, GL11.GL_KEEP, GL11.GL_KEEP);
                GLStateRenderThread.AlphaTest.set(false);
                GLStateRenderThread.DepthTest.set(false);
                GLStateRenderThread.DepthFunc.set(GL11.GL_ALWAYS);
            } catch (Throwable t) {
                // the raw calls below still clean up after the scene
            }
            GL11.glColorMask(true, true, true, true);
            GL11.glDisable(GL11.GL_STENCIL_TEST);
            GL11.glStencilFunc(GL11.GL_ALWAYS, 255, 255);
            GL11.glStencilOp(GL11.GL_KEEP, GL11.GL_KEEP, GL11.GL_KEEP);
            GL11.glDisable(GL11.GL_ALPHA_TEST);
            GL11.glDisable(GL11.GL_DEPTH_TEST);
            GL11.glDepthFunc(GL11.GL_ALWAYS);
            GL11.glDisable(GL11.GL_CULL_FACE);
            GL11.glEnable(GL11.GL_BLEND);
            GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);
        }
    }

    // ------------------------------------------------------------------- tints

    /** position of a scene model (mm) -> {r, g, b}: its light, see TintByPlace */
    public static final ConcurrentHashMap<Long, float[]> PLACE_TINTS = new ConcurrentHashMap<>();

    public static long placeKey(double x, double y, double z) {
        long kx = Math.round(x * 1000) + 500000, ky = Math.round(y * 1000) + 500000, kz = Math.round(z * 1000) + 500000;
        return (kx << 42) | (ky << 21) | kz;
    }

    /**
     * Light of a static model of the scene, by where it stands (UI3DScene
     * draws them all white). KnoxTint does this by scene object id from a
     * patch of UI3DScene$ModelDrawer, which was not applied in the menu; this
     * one hangs on Shader.setTransformMatrix, the last thing set before a
     * model is drawn, and knows the model by the translation of its matrix.
     * A negative r forgets the place.
     */
    @LuaMethod(name = "knoxMenuTintAt", global = true)
    public static void knoxMenuTintAt(double x, double y, double z, double r, double g, double b) {
        long key = placeKey(x, y, z);
        if (r < 0) PLACE_TINTS.remove(key);
        else PLACE_TINTS.put(key, new float[] {(float) r, (float) g, (float) b});
    }

    /** {x, y, z, radius, r, g, b}: lights of the game's own world models, found by nearness */
    public static final CopyOnWriteArrayList<float[]> NEAR_TINTS = new CopyOnWriteArrayList<>();

    /**
     * The same for one of the game's world models (a kettle, a lantern): the
     * scene shifts those by their "world" attachment, so their matrix is not
     * exactly where they were put; any model drawn within the radius of the
     * place takes the light. A negative r forgets the place.
     */
    @LuaMethod(name = "knoxMenuTintNear", global = true)
    public static void knoxMenuTintNear(double x, double y, double z, double radius, double r, double g, double b) {
        for (float[] t : NEAR_TINTS) {
            if (Math.abs(t[0] - x) < 0.001 && Math.abs(t[1] - y) < 0.001 && Math.abs(t[2] - z) < 0.001) NEAR_TINTS.remove(t);
        }
        if (r >= 0) {
            NEAR_TINTS.add(new float[] {(float) x, (float) y, (float) z, (float) radius, (float) r, (float) g, (float) b});
        }
    }

    @LuaMethod(name = "knoxMenuTintClear", global = true)
    public static void knoxMenuTintClear() {
        PLACE_TINTS.clear();
        NEAR_TINTS.clear();
        vehicleAmbient = -1f;
        sceneLights = null;
    }

    /** light of the scene's vehicles (the vehicle shader's ambient), or -1: left alone */
    public static volatile float vehicleAmbient = -1f;

    /**
     * UI3DScene draws vehicles at full light as well, and their shader takes
     * no tint that could be used: its ambient is replaced while the menu scene
     * has a car in it. A negative value switches this off.
     */
    @LuaMethod(name = "knoxMenuVehicleLight", global = true)
    public static void knoxMenuVehicleLight(double ambient) {
        vehicleAmbient = (float) ambient;
    }

    /**
     * True while the main menu is the game's state - the only time the scene's
     * lights may touch a shader. They are Java statics and outlive the Lua that
     * set them: joining a server resets Lua on the way, the old scene's destroy
     * never runs, and the menu car's dim ambient stayed on every vehicle of the
     * server (blue-green cars, Steam report 2026-10-14).
     */
    public static boolean sceneLive() {
        try {
            GameStateMachine states = GameWindow.states;
            return states != null && states.current instanceof MainScreenState;
        } catch (RuntimeException | LinkageError e) {
            return false;
        }
    }

    @Patch(className = "zombie.core.skinnedmodel.shader.Shader", methodName = "setAmbient")
    public static class VehicleAmbient {
        @Patch.OnEnter
        public static void enter(@Patch.This Shader self, @Patch.Argument(value = 0, readOnly = false) float amb) {
            if (vehicleAmbient >= 0f && self.isVehicleShader() && sceneLive()) amb = vehicleAmbient;
        }
    }

    // ----------------------------------------------------------------- shading

    /**
     * The scene's lamps, for models that are shaded (knoxMenuShadeAt) instead
     * of tinted flat: night rgb; fire x y z, r g b, reach; lamp x y z, r g b,
     * reach; moon direction x y z, r g b. The model shader has an ambient
     * color and five directional lights, which UI3DScene switches off; for a
     * shaded model they are set from these, each as a direction from where the
     * model stands. Its faces turned to the fire are lit by it, the others
     * keep the night.
     */
    public static volatile float[] sceneLights;
    /** the fire's flicker (around 1), set every frame */
    public static volatile float fireFlicker = 1f;

    @LuaMethod(name = "knoxMenuSceneLights", global = true)
    public static void knoxMenuSceneLights(KahluaTable t) {
        if (t == null) {
            sceneLights = null;
            return;
        }
        // 23 values, or 30 with a third lamp after them (x y z, r g b, reach): the light by the graves
        float[] v = new float[t.rawget(Double.valueOf(30)) != null ? 30 : 23];
        for (int i = 0; i < v.length; i++) {
            Object o = t.rawget(Double.valueOf(i + 1));
            v[i] = o instanceof Double ? ((Double) o).floatValue() : 0f;
        }
        sceneLights = v;
    }

    @LuaMethod(name = "knoxMenuFireFlicker", global = true)
    public static void knoxMenuFireFlicker(double flicker) {
        fireFlicker = (float) flicker;
    }

    /** A model that is shaded: `scale` darkens it as a whole, `fire` is how much of the fire it takes. */
    @LuaMethod(name = "knoxMenuShadeAt", global = true)
    public static void knoxMenuShadeAt(double x, double y, double z, double scale, double fire) {
        PLACE_TINTS.put(placeKey(x, y, z), new float[] {(float) scale, (float) fire, 0f, 1f});
    }

    /** The same for one of the game's world models, found by nearness (see knoxMenuTintNear). */
    @LuaMethod(name = "knoxMenuShadeNear", global = true)
    public static void knoxMenuShadeNear(double x, double y, double z, double radius, double scale, double fire) {
        knoxMenuTintNear(x, y, z, radius, -1, 0, 0);
        NEAR_TINTS.add(new float[] {(float) x, (float) y, (float) z, (float) radius, (float) scale, (float) fire, 0f, 1f});
    }

    /** One of the shader's lights as a direction (towards the light) in the scene's space. */
    public static void directional(Shader shader, int index, float dx, float dy, float dz, float r, float g, float b) {
        // Shader.setLight turns what it is given into (-x, z, y)
        shader.setLight(index, -dx, dz, dy, r, g, b, 1.0e6f, Float.NaN, 0f, 0f, 0f, null);
    }

    public static void pointLight(Shader shader, int index, float[] l, int at, float px, float py, float pz, float k) {
        float dx = l[at] - px, dy = l[at + 1] - py, dz = l[at + 2] - pz;
        float d = (float) Math.sqrt(dx * dx + dy * dy + dz * dz);
        if (d < 0.05f) {
            dx = 0f; dy = 1f; dz = 0f; d = 1f;
        } else {
            dx /= d; dy /= d; dz /= d;
        }
        float reach = l[at + 6];
        float p = k / (1f + (d / reach) * (d / reach));
        directional(shader, index, dx, dy, dz, l[at + 3] * p, l[at + 4] * p, l[at + 5] * p);
    }

    public static void shade(Shader shader, float px, float py, float pz, float scale, float fire) {
        float[] l = sceneLights;
        if (l == null) {
            shader.setTint(scale, scale, scale);
            return;
        }
        shader.setTint(scale, scale, scale);
        shader.setAmbient(l[0], l[1], l[2]);
        // lit as if from a little above the ground the thing stands on
        pointLight(shader, 0, l, 3, px, py + 0.3f, pz, fire * fireFlicker);
        pointLight(shader, 1, l, 10, px, py + 0.3f, pz, 1f);
        directional(shader, 2, l[17], l[18], l[19], l[20], l[21], l[22]);
        if (l.length >= 30) pointLight(shader, 3, l, 23, px, py + 0.3f, pz, 1f);
    }

    public static void tintByPlace(Shader shader, Matrix4f m) {
        if (shader.isVehicleShader()) return;   // drawn with an identity matrix: not a place
        float[] t = PLACE_TINTS.get(placeKey(m.m30(), m.m31(), m.m32()));
        if (t != null) {
            if (t.length > 3 && t[3] > 0f) shade(shader, m.m30(), m.m31(), m.m32(), t[0], t[1]);
            else shader.setTint(t[0], t[1], t[2]);
            return;
        }
        for (float[] n : NEAR_TINTS) {
            float dx = m.m30() - n[0], dy = m.m31() - n[1], dz = m.m32() - n[2];
            if (dx * dx + dy * dy + dz * dz <= n[3] * n[3]) {
                if (n.length > 7 && n[7] > 0f) shade(shader, n[0], n[1], n[2], n[4], n[5]);
                else shader.setTint(n[4], n[5], n[6]);
                return;
            }
        }
    }

    @Patch(className = "zombie.core.skinnedmodel.shader.Shader", methodName = "setTransformMatrix")
    public static class TintByPlace {
        @Patch.OnExit
        public static void exit(@Patch.This Shader self, @Patch.Argument(0) Matrix4f matrix,
                                @Patch.Argument(1) boolean transpose) {
            if ((!PLACE_TINTS.isEmpty() || !NEAR_TINTS.isEmpty()) && sceneLive()) tintByPlace(self, matrix);
        }
    }

    private static final ResetGL RESET = new ResetGL();

    @LuaMethod(name = "knoxMenuResetGL", global = true)
    public static void knoxMenuResetGL() {
        SpriteRenderer.instance.drawGeneric(RESET);
    }

    static String stackInfo(Object stack) {
        try {
            Object empty = stack.getClass().getMethod("isEmpty").invoke(stack);
            if (Boolean.TRUE.equals(empty)) return "empty";
            Object top = stack.getClass().getMethod("peek").invoke(stack);
            if (top instanceof Matrix4f) {
                Matrix4f m = (Matrix4f) top;
                return String.format(java.util.Locale.ROOT, "[%.3f %.3f %.3f %.3f]", m.m00(), m.m11(), m.m22(), m.m23());
            }
            return String.valueOf(top);
        } catch (Throwable t) {
            return "?";
        }
    }

    @LuaMethod(name = "knoxMenuShot", global = true)
    public static void knoxMenuShot(String file) {
        if (file == null || file.contains("..") || file.contains("/") || file.contains("\\")) return;
        SpriteRenderer.instance.drawGeneric(new Shot(file));
    }

    // ------------------------------------------------------------------- light

    private static final IsoGridSquare.ResultLight[] LIGHTS = new IsoGridSquare.ResultLight[5];

    /**
     * The fire's light on a scene character, as a direction in the model's own
     * space (x to its side, y up, z to its front) and a color. Shader.setLight
     * takes world-style coordinates and turns them into (-x, z, y), so they are
     * given the other way round here.
     */
    @LuaMethod(name = "knoxMenuFireLight", global = true)
    public static void knoxMenuFireLight(UI3DScene scene, String id, double mx, double my, double mz,
                                         double r, double g, double b) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null) return;
        synchronized (LIGHTS) {
            for (int i = 0; i < LIGHTS.length; i++) {
                if (LIGHTS[i] == null) LIGHTS[i] = new IsoGridSquare.ResultLight();
                LIGHTS[i].radius = 0;
            }
            IsoGridSquare.ResultLight l = LIGHTS[0];
            l.x = (int) Math.round(-mx * 100);
            l.y = (int) Math.round(mz * 100);
            l.z = (int) Math.round(my * 100);
            l.r = (float) r;
            l.g = (float) g;
            l.b = (float) b;
            l.radius = 100000;   // no falloff: the color is the strength
            model.setLights(LIGHTS, 0.5f, 0.5f, 0.5f);
        }
    }

    /** Diagnostics: what a scene character's model is made of right now. */
    @LuaMethod(name = "knoxMenuCharInfo", global = true)
    public static String knoxMenuCharInfo(UI3DScene scene, String id) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null) return "no model";
        StringBuilder sb = new StringBuilder();
        try {
            sb.append("set=").append(model.GetAnimSetName()).append(" state=").append(model.getState())
              .append(" animate=").append(model.isAnimate()).append(" female=").append(model.isFemale())
              .append(" zombie=").append(model.isZombie()).append(" ready=").append(model.isReadyToRender());
            Field f = find(AnimatedModel.class, "alpha");
            sb.append(" alpha=").append(f.get(model));
            f = find(AnimatedModel.class, "modelInstance");
            zombie.core.skinnedmodel.model.ModelInstance mi = (zombie.core.skinnedmodel.model.ModelInstance) f.get(model);
            if (mi == null) {
                sb.append(" instance=null");
            } else {
                sb.append(" model=").append(mi.model == null ? "null" : mi.model.name)
                  .append(" tex=").append(mi.tex == null ? "null" : mi.tex.getName())
                  .append(" modelTex=").append(mi.model == null || mi.model.tex == null ? "null" : mi.model.tex.getName())
                  .append(" effect=").append(mi.model == null || mi.model.effect == null ? "null" : mi.model.effect.getClass().getSimpleName()
                      + (mi.model.effect.isInstanced() ? "(instanced)" : "(single)"))
                  .append(" subs=").append(mi.sub == null ? 0 : mi.sub.size());
            }
            AnimationPlayer player = model.getAnimationPlayer();
            if (player != null && player.isReady()) {
                sb.append(" tracks=").append(player.getMultiTrack().getTrackCount())
                  .append(" angle=").append(player.getRenderedAngle());
                if (player.getMultiTrack().getTrackCount() > 0) {
                    sb.append(" clip=").append(player.getMultiTrack().getTracks().get(0).getName());
                }
            }
            AdvancedAnimator animator = model.getAdvancedAnimator();
            sb.append(" animatorState=").append(animator == null ? "null" : animator.getCurrentStateName());
        } catch (Throwable t) {
            sb.append(" !").append(t);
        }
        return sb.toString();
    }

    private static final ColorInfo AMBIENT = new ColorInfo();

    /**
     * Light of a scene character: ambient color (the night plus the fire's
     * fill, already flickering) and a tint on top (hover highlight, a dark
     * silhouette). The shader shows texture * tint * min(1, ambient + lights);
     * the game multiplies the ambient by 0.45 on the way, undone here.
     */
    @LuaMethod(name = "knoxMenuLight", global = true)
    public static void knoxMenuLight(UI3DScene scene, String id, double ar, double ag, double ab,
                                     double tr, double tg, double tb) {
        AnimatedModel model = modelOf(scene, id);
        if (model == null) return;
        AMBIENT.set((float) (ar / 0.45), (float) (ag / 0.45), (float) (ab / 0.45), 1f);
        model.setAmbient(AMBIENT, false, false);   // no "outside" fill lights: the fire is the only lamp
        model.setTint((float) tr, (float) tg, (float) tb);
    }
}
