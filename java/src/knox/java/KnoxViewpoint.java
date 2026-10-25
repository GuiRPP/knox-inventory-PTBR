package knox.java;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.Lua.LuaManager;
import zombie.core.Translator;
import zombie.core.textures.Texture;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.iso.IsoGridSquare;

/**
 * Viewpoint (first person, Workshop 3809306528) keeps the mouse for looking
 * around unless its "cursor mode" is on (the middle button toggles it). While
 * a Knox screen or window is open the cursor is wanted, all the time: Knox
 * turns the mode on, keeps it on (the middle button is the inspect gesture in
 * Knox, and Viewpoint toggled the cursor away on the same press), and on
 * closing puts back what was there - or the looking, when the screen came from
 * Viewpoint's own loot key.
 *
 * The mode is a private static of viewpoint.FP with no Lua access; ZombieBuddy
 * puts mod jars on the system class path, so it is found from here. Without
 * Viewpoint nothing happens.
 */
public class KnoxViewpoint {

    private static boolean looked;
    private static Field cursorMode;   // viewpoint.FP.cursorMode
    private static Field captured;     // viewpoint.input.Look.captured: the view holds the mouse
    private static Field wantCapture;  // viewpoint.input.Look.wantCapture: worked out each frame from the mode
    private static Field viewEnabled;  // viewpoint.core.View.enabled: Viewpoint's own view is on
    private static boolean held;
    private static boolean before;

    private static Field find(ClassLoader cl, String cls, String name) {
        try {
            Field f = Class.forName(cls, false, cl).getDeclaredField(name);
            f.setAccessible(true);
            return f;
        } catch (Throwable t) {
            return null;   // no Viewpoint, or a version without it
        }
    }

    static Field field() {
        if (!looked) {
            looked = true;
            ClassLoader cl = ClassLoader.getSystemClassLoader();
            cursorMode = find(cl, "viewpoint.FP", "cursorMode");
            captured = find(cl, "viewpoint.input.Look", "captured");
            wantCapture = find(cl, "viewpoint.input.Look", "wantCapture");
            viewEnabled = find(cl, "viewpoint.core.View", "enabled");
        }
        return cursorMode;
    }

    private static boolean get(Field f, boolean otherwise) {
        try {
            return f == null ? otherwise : f.getBoolean(null);
        } catch (Throwable t) {
            return otherwise;
        }
    }

    private static void set(Field f, boolean v) {
        try {
            if (f != null) f.setBoolean(null, v);
        } catch (Throwable t) {
            // left as it is
        }
    }

    /** Is Viewpoint's own view on (first or third person)? Off: the game's camera, nothing to do. */
    static boolean viewOn() {
        return get(viewEnabled, true);
    }

    private static boolean has(ClassLoader cl, String cls) {
        try {
            Class.forName(cls, false, cl);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    /**
     * What of Viewpoint (and of OldPoint over it) is here, for KnoxCompat: ""
     * without Viewpoint, else the parts found, "|", the parts missing (a Viewpoint
     * whose insides changed). Each part of Knox's integration works only with its
     * own: a missing one switches off that part alone.
     *   cursor  FP.cursorMode - the cursor while a Knox window is open
     *   look    Look.captured / wantCapture - the cursor at once, not a frame later
     *   view    View.enabled - is Viewpoint's view on (the Surroundings' "auto")
     *   rows    LootRows' rows and Row's fields - "not searched yet" in its loot panel
     *   menu    LootMenu.rows, LootRows.selected, Row.items - the container of the row chosen
     *   panel   LootMenu's target, keys and state, InteractActions - Knox's own crosshair panel
     *   oldpoint, topdown  OldPoint's Bridge: its overhead camera, its rotation key
     */
    @LuaMethod(name = "knoxViewpointParts", global = true)
    public static String knoxViewpointParts() {
        // (looked up again each time Lua asks - once a load of the Lua: a mod enabled
        // only in a save has its jar loaded with that save, after the main menu asked)
        looked = false;
        menuLooked = false;
        topDownLooked = false;
        // (and a window left open by quitting to the menu is not held over into the next game)
        held = false;
        windowOpen = false;
        panelOwned = false;   // (Knox's panel asks again once its Lua runs)
        ClassLoader cl = ClassLoader.getSystemClassLoader();
        if (!has(cl, "viewpoint.FP")) return "";
        field();
        StringBuilder found = new StringBuilder(), missing = new StringBuilder();
        part(cursorMode != null, "cursor", found, missing);
        part(captured != null && wantCapture != null, "look", found, missing);
        part(viewEnabled != null, "view", found, missing);
        boolean rows;
        try {
            lookUp(Class.forName("viewpoint.interact.LootRows", false, cl));
            rows = true;
        } catch (Throwable t) {
            rows = false;
        }
        part(rows, "rows", found, missing);
        part(rows && menu(), "menu", found, missing);
        part(panelParts(), "panel", found, missing);
        if (has(cl, "oldpoint.viewpoint.Bridge")) {
            part(topDownMethod() != null, "topdown", found, missing);
            boolean key;
            try {
                Class.forName("oldpoint.viewpoint.Bridge", false, cl).getDeclaredMethod("rotationHeld");
                key = true;
            } catch (Throwable t) {
                key = false;
            }
            part(key, "oldpoint", found, missing);
        }
        return found + "|" + missing;
    }

    private static void part(boolean ok, String name, StringBuilder found, StringBuilder missing) {
        StringBuilder to = ok ? found : missing;
        if (to.length() > 0) to.append(' ');
        to.append(name);
    }

    /** Is Viewpoint's own view on right now? (false without Viewpoint) - the Surroundings setting's "auto". */
    @LuaMethod(name = "knoxViewpointViewOn", global = true)
    public static boolean knoxViewpointViewOn() {
        field();
        return viewEnabled != null && get(viewEnabled, false);
    }

    /** Cursor on, and the view told at once that it doesn't hold the mouse (no capture for a frame). */
    private static void free() {
        set(cursorMode, true);
        set(wantCapture, false);
    }

    private static void hold(Field f) {
        // the cursor was out before if the view didn't hold the mouse (Project
        // Viewpoint QOL may already have turned the mode on for the same key press)
        before = captured != null ? !get(captured, false) : get(f, false);
        held = true;
        free();
    }

    /**
     * want: a Knox screen or window is open. lookAfter: on closing go back to
     * looking around, whatever the mode was before.
     */
    @LuaMethod(name = "knoxViewpointCursor", global = true)
    public static void knoxViewpointCursor(boolean want, boolean lookAfter) {
        windowOpen = want;
        Field f = field();
        if (f == null) return;
        if (want && !held && viewOn()) {
            hold(f);
        } else if (!want && held) {
            set(f, lookAfter ? false : before);
            held = false;
        }
    }

    /**
     * Every frame while a Knox window is open: the cursor stays (a press of
     * Viewpoint's cursor key, another mod's lock, or the view turned on only now).
     */
    @LuaMethod(name = "knoxViewpointKeep", global = true)
    public static void knoxViewpointKeep() {
        Field f = field();
        if (f == null || !viewOn()) return;
        if (!held) {
            // (the view was turned on with the window open - it was opened in the
            // game's camera: closed, the view looks around, as a view just turned on does)
            hold(f);
            before = false;
        } else if (!get(f, true)) {
            free();
        }
    }

    // OldPoint (Workshop 3815999052, an overhead camera over Viewpoint) holds the
    // mouse for turning the camera while its key is held - the middle button,
    // Knox's inspect gesture: in a Knox window the cursor went and the camera
    // turned behind it. While a Knox window is open its key is not held for it.

    /** A Knox window is open (knoxViewpointCursor). Public: read by the patch inside OldPoint. */
    public static volatile boolean windowOpen;

    public static boolean rotationHeld(boolean held) {
        return held && !windowOpen;
    }

    @Patch(className = "oldpoint.viewpoint.Bridge", methodName = "rotationHeld")
    public static class OldPointRotation {
        @Patch.OnExit
        public static void exit(@Patch.Return(readOnly = false) boolean result) {
            result = KnoxViewpoint.rotationHeld(result);
        }
    }

    private static boolean topDownLooked;
    private static Method topDown;   // oldpoint.viewpoint.Bridge.topDownActive()

    private static Method topDownMethod() {
        if (!topDownLooked) {
            topDownLooked = true;
            try {
                topDown = Class.forName("oldpoint.viewpoint.Bridge", false, ClassLoader.getSystemClassLoader())
                        .getMethod("topDownActive");
            } catch (Throwable t) {
                topDown = null;
            }
        }
        return topDown;
    }

    /** Is OldPoint's overhead camera on? (false without it) - it sees all around, as the game's camera. */
    @LuaMethod(name = "knoxViewpointTopDown", global = true)
    public static boolean knoxViewpointTopDown() {
        Method m = topDownMethod();
        try {
            return m != null && Boolean.TRUE.equals(m.invoke(null));
        } catch (Throwable t) {
            return false;
        }
    }

    // The container of the row chosen in Viewpoint's loot panel (its wheel moves
    // the choice): its loot key opens the game's window on the first container of
    // what is looked at - a fridge's, never its freezer; a car's first part within
    // reach. Knox opens the one whose row is chosen.

    private static boolean menuLooked;
    private static Field menuRows, selectedF, itemsF;   // LootMenu.rows, LootRows.selected, LootRows$Row.items

    private static boolean menu() {
        if (!menuLooked) {
            menuLooked = true;
            try {
                ClassLoader cl = ClassLoader.getSystemClassLoader();
                Field r = Class.forName("viewpoint.interact.LootMenu", false, cl).getDeclaredField("rows");
                Field s = Class.forName("viewpoint.interact.LootRows", false, cl).getDeclaredField("selected");
                Field i = Class.forName("viewpoint.interact.LootRows$Row", false, cl).getDeclaredField("items");
                r.setAccessible(true);
                s.setAccessible(true);
                i.setAccessible(true);
                menuRows = r;
                selectedF = s;
                itemsF = i;
            } catch (Throwable t) {
                menuRows = null;
            }
        }
        return menuRows != null;
    }

    /** The container of the chosen row's things, or nil (a heading, an action, the ground, no Viewpoint). */
    @LuaMethod(name = "knoxViewpointChosen", global = true)
    public static ItemContainer knoxViewpointChosen() {
        if (!menu()) return null;
        try {
            Object rowsObj = menuRows.get(null);
            if (rowsObj == null) return null;
            lookUp(rowsObj.getClass());
            List<?> rows = (List<?>) rowsF.get(rowsObj);
            int sel = selectedF.getInt(rowsObj);
            if (rows == null || sel < 0 || sel >= rows.size()) return null;
            List<?> items = (List<?>) itemsF.get(rows.get(sel));
            if (items == null || items.isEmpty() || !(items.get(0) instanceof InventoryItem item)) return null;
            return item.getContainer();
        } catch (Throwable t) {
            return null;
        }
    }

    // Viewpoint's loot panel: what the container looked at holds, a row per kind,
    // built by viewpoint.interact.LootRows.group from the container's list. It
    // showed everything, searched or not, and its Grab took from it (pascal's
    // report, 2026-10-15). With Knox's container search on, the list it gets is
    // only what the character has found (Lua: KnoxViewpointUnseen), and a row
    // "not searched yet" stands for the rest. The panel is rebuilt only when the
    // things in it change, so while the search is on it is also rebuilt a few
    // times a second: a thing found shows up.

    private static boolean searchOn;
    private static int hiddenLast;   // things left out of the last list given to group
    private static Texture lens;

    /** Every frame from Lua: is the container search on? */
    @LuaMethod(name = "knoxViewpointSearch", global = true)
    public static void knoxViewpointSearch(boolean on) {
        searchOn = on;
    }

    /** something was left out of the last list: a search is still going on in it */
    private static volatile boolean hadHidden;

    /**
     * The panel's signature: while a thing in the container looked at is still
     * to be found, it changes a few times a second (a thing found shows up).
     * Once nothing is hidden there, the panel is rebuilt only when its things
     * change, as Viewpoint does - each rebuild asks Lua about every thing (a
     * performance pass, 2026-10-16: a big shelf was asked 2.5 times a second
     * for as long as the search setting was on).
     */
    public static long refreshed(long signature) {
        // (Knox's own panel shown: Viewpoint's rows are not seen - no need to rebuild them)
        if (panelOwned) return signature;
        return (searchOn && hadHidden) ? signature * 31L + System.currentTimeMillis() / 400L : signature;
    }

    /** The things of `list` the character has found (the list itself when that is all of them). */
    public static List<InventoryItem> seenOnly(List<InventoryItem> list) {
        hiddenLast = 0;
        hadHidden = false;
        // (Knox's own panel shown: it asks the search itself - not each thing over again here)
        if (panelOwned || !searchOn || list == null || list.isEmpty()) return list;
        Object fn = LuaManager.getFunctionObject("KnoxViewpointUnseen");
        if (fn == null) return list;
        ArrayList<InventoryItem> out = null;
        for (int i = 0; i < list.size(); i++) {
            InventoryItem item = list.get(i);
            boolean unseen = false;
            if (item != null) {
                try {
                    unseen = Boolean.TRUE.equals(LuaManager.caller.protectedCallBoolean(LuaManager.thread, fn, item));
                } catch (Throwable t) {
                    unseen = false;
                }
            }
            if (unseen) {
                if (out == null) {
                    out = new ArrayList<>(list.size());
                    for (int k = 0; k < i; k++) out.add(list.get(k));
                }
                hiddenLast++;
                hadHidden = true;
            } else if (out != null) {
                out.add(item);
            }
        }
        return out == null ? list : out;
    }

    // Viewpoint's insides, looked up once (they were looked up on every rebuild)
    private static Class<?> rowsCls;
    private static Field rowsF, emptyF, nameF, enabledF, iconF, headingF;
    private static Method makeRow;

    private static void lookUp(Class<?> cls) throws ReflectiveOperationException {
        if (rowsCls == cls) return;
        rowsF = cls.getDeclaredField("rows");
        rowsF.setAccessible(true);
        emptyF = cls.getDeclaredField("empty");
        emptyF.setAccessible(true);
        Class<?> rowCls = Class.forName("viewpoint.interact.LootRows$Row", false, cls.getClassLoader());
        nameF = rowCls.getDeclaredField("name");
        enabledF = rowCls.getDeclaredField("enabled");
        iconF = rowCls.getDeclaredField("icon");
        headingF = rowCls.getDeclaredField("heading");
        nameF.setAccessible(true);
        enabledF.setAccessible(true);
        iconF.setAccessible(true);
        headingF.setAccessible(true);
        makeRow = cls.getDeclaredMethod("row");
        makeRow.setAccessible(true);
        rowsCls = cls;
    }

    /** After group: a row "not searched yet" for what was left out (in place of the game's "Empty"). */
    public static void markUnsearched(Object rowsObj) {
        if (hiddenLast == 0 || rowsObj == null) return;
        hiddenLast = 0;
        try {
            Class<?> cls = rowsObj.getClass();
            lookUp(cls);
            List<?> rows = (List<?>) rowsF.get(rowsObj);
            Object empty = emptyF.get(null);
            Object row = rows.isEmpty() ? null : rows.get(rows.size() - 1);
            Field name = nameF, enabled = enabledF, icon = iconF, heading = headingF;
            boolean placeholder = row != null && heading.get(row) == null && empty != null
                    && empty.equals(name.get(row)) && !enabled.getBoolean(row);
            if (!placeholder) {
                row = makeRow.invoke(rowsObj);
                @SuppressWarnings("unchecked")
                List<Object> list = (List<Object>) rows;
                list.add(row);
            }
            name.set(row, Translator.getText("IGUI_Knox_VPUnsearched"));
            enabled.setBoolean(row, false);
            if (lens == null) lens = Texture.getSharedTexture("media/ui/knox_lens.png");
            icon.set(row, lens);
        } catch (Throwable t) {
            // a Viewpoint version with other insides: its rows stay as they are
        }
    }

    @Patch(className = "viewpoint.interact.LootRows", methodName = "group")
    public static class PanelSeenOnly {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(value = 1, readOnly = false) List<InventoryItem> list) {
            list = KnoxViewpoint.seenOnly(list);
        }

        @Patch.OnExit
        public static void exit(@Patch.This Object self) {
            KnoxViewpoint.markUnsearched(self);
        }
    }

    @Patch(className = "viewpoint.interact.LootRows", methodName = "signature")
    public static class PanelRefresh {
        @Patch.OnExit
        public static void exit(@Patch.Return(readOnly = false) long result) {
            result = KnoxViewpoint.refreshed(result);
        }
    }

    // Knox's own crosshair panel in place of Viewpoint's (the author, 2026-10-25:
    // the mockup .claude/mockups/vp_panel_v1.html brought into the game).
    // Viewpoint still picks what is looked at, rolls its loot, gathers its
    // actions and reads its keys - the player's own, from its settings; Knox
    // draws the panel and keeps its rows and the choice (KnoxCrosshair.lua):
    //   LootPanel.render  not drawn: Knox's panel is drawn instead
    //   LootRows.move     the wheel (and a pad's up / down) moves Knox's choice
    //   LootMenu.asks     the take key is the panel's, whatever Viewpoint's own rows hold
    //   LootMenu.take     take and take all go to Knox; the open-window key stays Viewpoint's
    // Lua asks each frame what is looked at and what was pressed (knoxVpPanel*).
    // A part of this not found (another Viewpoint) leaves Viewpoint's own panel.

    /** Knox draws the panel (Lua: knoxVpPanelOwn). Public: read by the patches inside Viewpoint. */
    public static volatile boolean panelOwned;
    private static int wheelAcc, pressed, takeKey = -1;

    private static boolean panelLooked;
    private static Field lmShown, lmLoot, lmPending, lmTarget, lmHeld;   // LootMenu's
    private static Field tKind, tSquare, tObject, tLocked, tContainers;   // LootTargets$Target's
    private static Field shoulderF;                                       // View.shoulder: <0 the camera over the left
    private static Method iaCount, iaLabel, iaEnabled, iaProgress, iaTitle, iaRun;   // InteractActions'
    private static Method kiSlot, kiMenu, title, groundTitle;
    private static Object bindTake, bindAll;                              // Keys.LOOT_TAKE, Keys.LOOT_TAKE_ALL

    private static Field declared(Class<?> c, String name) throws ReflectiveOperationException {
        Field f = c.getDeclaredField(name);
        f.setAccessible(true);
        return f;
    }

    private static Method method(Class<?> c, String name, Class<?>... args) throws ReflectiveOperationException {
        Method m = c.getDeclaredMethod(name, args);
        m.setAccessible(true);
        return m;
    }

    private static boolean panel() {
        if (!panelLooked) {
            panelLooked = true;
            try {
                ClassLoader cl = ClassLoader.getSystemClassLoader();
                Class<?> lm = Class.forName("viewpoint.interact.LootMenu", false, cl);
                Class<?> tg = Class.forName("viewpoint.interact.LootTargets$Target", false, cl);
                Class<?> ia = Class.forName("viewpoint.interact.InteractActions", false, cl);
                Class<?> ki = Class.forName("viewpoint.platform.KeyInput", false, cl);
                Class<?> keys = Class.forName("viewpoint.platform.Keys", false, cl);
                Class<?> rows = Class.forName("viewpoint.interact.LootRows", false, cl);
                lmShown = declared(lm, "shown");
                lmLoot = declared(lm, "loot");
                lmPending = declared(lm, "pending");
                lmHeld = declared(lm, "held");
                tKind = declared(tg, "kind");
                tSquare = declared(tg, "square");
                tObject = declared(tg, "object");
                tLocked = declared(tg, "locked");
                tContainers = declared(tg, "containers");
                shoulderF = declared(Class.forName("viewpoint.core.View", false, cl), "shoulder");
                iaCount = method(ia, "count");
                iaLabel = method(ia, "label", int.class);
                iaEnabled = method(ia, "enabled", int.class);
                iaProgress = method(ia, "progress", int.class);
                iaTitle = method(ia, "title");
                iaRun = method(ia, "run", IsoPlayer.class, int.class);
                kiSlot = method(ki, "slot", int.class);
                kiMenu = method(ki, "menu", int.class);
                title = method(rows, "title", ItemContainer.class);
                groundTitle = method(rows, "groundTitle");
                bindTake = declared(keys, "LOOT_TAKE").get(null);
                bindAll = declared(keys, "LOOT_TAKE_ALL").get(null);
                // (the target last: it is what says the parts are all here)
                lmTarget = declared(lm, "target");
            } catch (Throwable t) {
                lmTarget = null;
            }
        }
        return lmTarget != null;
    }

    /** Does this Viewpoint have what Knox's panel needs? (KnoxCompat: the part "panel") */
    static boolean panelParts() {
        panelLooked = false;
        return panel();
    }

    /** Knox draws the panel (true) or Viewpoint does. Returns whether Knox does. */
    @LuaMethod(name = "knoxVpPanelOwn", global = true)
    public static boolean knoxVpPanelOwn(boolean on) {
        boolean own = on && panel();
        if (own != panelOwned) {
            panelOwned = own;
            wheelAcc = 0;
            pressed = 0;
        }
        return own;
    }

    private static Object target() throws IllegalAccessException {
        return lmTarget.get(null);
    }

    /** Is Viewpoint's panel up right now (something within reach looked at)? */
    @LuaMethod(name = "knoxVpPanelShown", global = true)
    public static boolean knoxVpPanelShown() {
        if (!panel()) return false;
        try {
            return lmShown.getBoolean(null);
        } catch (Throwable t) {
            return false;
        }
    }

    /** What is looked at: 0 the ground, 3 a car, 5 / 6 a body or a character, others furniture. */
    @LuaMethod(name = "knoxVpPanelKind", global = true)
    public static int knoxVpPanelKind() {
        try {
            return panel() ? tKind.getInt(target()) : -1;
        } catch (Throwable t) {
            return -1;
        }
    }

    @LuaMethod(name = "knoxVpPanelLocked", global = true)
    public static boolean knoxVpPanelLocked() {
        try {
            return panel() && tLocked.getBoolean(target());
        } catch (Throwable t) {
            return false;
        }
    }

    /** Has it things to show (a container, the ground) - or only actions? */
    @LuaMethod(name = "knoxVpPanelLoot", global = true)
    public static boolean knoxVpPanelLoot() {
        try {
            return panel() && lmLoot.getBoolean(null);
        } catch (Throwable t) {
            return false;
        }
    }

    @LuaMethod(name = "knoxVpPanelSquare", global = true)
    public static IsoGridSquare knoxVpPanelSquare() {
        try {
            return panel() ? (IsoGridSquare) tSquare.get(target()) : null;
        } catch (Throwable t) {
            return null;
        }
    }

    @LuaMethod(name = "knoxVpPanelObject", global = true)
    public static Object knoxVpPanelObject() {
        try {
            return panel() ? tObject.get(target()) : null;
        } catch (Throwable t) {
            return null;
        }
    }

    /** The containers of what is looked at (Viewpoint's own list: read, never changed). */
    @LuaMethod(name = "knoxVpPanelContainers", global = true)
    public static List<?> knoxVpPanelContainers() {
        try {
            return panel() ? (List<?>) tContainers.get(target()) : null;
        } catch (Throwable t) {
            return null;
        }
    }

    /** A container's name as Viewpoint gives it (a car's part, a named bag...); nil: the ground's. */
    @LuaMethod(name = "knoxVpPanelTitle", global = true)
    public static String knoxVpPanelTitle(ItemContainer c) {
        try {
            if (!panel()) return null;
            return (String) (c == null ? groundTitle.invoke(null) : title.invoke(null, c));
        } catch (Throwable t) {
            return null;
        }
    }

    @LuaMethod(name = "knoxVpPanelActions", global = true)
    public static int knoxVpPanelActions() {
        try {
            return panel() ? (Integer) iaCount.invoke(null) : 0;
        } catch (Throwable t) {
            return 0;
        }
    }

    @LuaMethod(name = "knoxVpPanelActionLabel", global = true)
    public static String knoxVpPanelActionLabel(int i) {
        try {
            return panel() ? (String) iaLabel.invoke(null, i) : null;
        } catch (Throwable t) {
            return null;
        }
    }

    @LuaMethod(name = "knoxVpPanelActionOn", global = true)
    public static boolean knoxVpPanelActionOn(int i) {
        try {
            return panel() && Boolean.TRUE.equals(iaEnabled.invoke(null, i));
        } catch (Throwable t) {
            return false;
        }
    }

    /** How far the action is done (0..1): its bar fills the row as a take's does. */
    @LuaMethod(name = "knoxVpPanelActionProgress", global = true)
    public static float knoxVpPanelActionProgress(int i) {
        try {
            return panel() ? (Float) iaProgress.invoke(null, i) : 0f;
        } catch (Throwable t) {
            return 0f;
        }
    }

    /** The actions' heading Viewpoint gives (a door's name...), or nil. */
    @LuaMethod(name = "knoxVpPanelActionsTitle", global = true)
    public static String knoxVpPanelActionsTitle() {
        try {
            return panel() ? (String) iaTitle.invoke(null) : null;
        } catch (Throwable t) {
            return null;
        }
    }

    @LuaMethod(name = "knoxVpPanelRun", global = true)
    public static void knoxVpPanelRun(int i) {
        try {
            if (panel() && IsoPlayer.players[0] != null) iaRun.invoke(null, IsoPlayer.players[0], i);
        } catch (Throwable t) {
            // (another Viewpoint: nothing happens)
        }
    }

    /** The wheel's notches since asked (down: +). */
    @LuaMethod(name = "knoxVpPanelWheel", global = true)
    public static int knoxVpPanelWheel() {
        int n = wheelAcc;
        wheelAcc = 0;
        return n;
    }

    /** A key pressed since asked: 1 take, 2 take all, 0 none. */
    @LuaMethod(name = "knoxVpPanelPressed", global = true)
    public static int knoxVpPanelPressed() {
        int n = pressed;
        pressed = 0;
        return n;
    }

    /** Is the take key (pressed last) still held? A pad's press: false (no hold). */
    @LuaMethod(name = "knoxVpPanelHeld", global = true)
    public static boolean knoxVpPanelHeld() {
        try {
            if (!panel() || takeKey < 0) return false;
            int slot = (Integer) kiSlot.invoke(null, takeKey);
            boolean[] held = (boolean[]) lmHeld.get(null);
            return slot >= 0 && slot < held.length && held[slot];
        } catch (Throwable t) {
            return false;
        }
    }

    /** The camera over the left shoulder: the panel goes left of the crosshair, as Viewpoint's. */
    @LuaMethod(name = "knoxVpPanelLeft", global = true)
    public static boolean knoxVpPanelLeft() {
        try {
            return panel() && shoulderF.getInt(null) < 0;
        } catch (Throwable t) {
            return false;
        }
    }

    /** LootRows.move: while Knox draws the panel the wheel moves Knox's choice (true: skip). */
    public static boolean wheel(int n) {
        if (!panelOwned) return false;
        wheelAcc += n;
        return true;
    }

    /**
     * LootMenu.asks: Viewpoint takes its take key only when its own chosen row
     * holds something - with Knox's panel its rows are not the ones shown.
     */
    public static int asks(int key, int result) {
        if (!panelOwned) return result;
        try {
            if (!lmShown.getBoolean(null)) return result;
            Object bind = kiMenu.invoke(null, key);
            if (bind == null) return result;
            if (bind == bindTake) {
                takeKey = key;
                return 1;
            }
            if (bind == bindAll) return lmLoot.getBoolean(null) ? 2 : result;
        } catch (Throwable t) {
            // (as Viewpoint said)
        }
        return result;
    }

    /** LootMenu.take: take / take all go to Knox (true: skip); the window key stays Viewpoint's. */
    public static boolean take() {
        if (!panelOwned) return false;
        try {
            int p = lmPending.getInt(null);
            if (p != 1 && p != 2) return false;
            pressed = p;
            lmPending.setInt(null, 0);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    @Patch(className = "viewpoint.interact.LootPanel", methodName = "render")
    public static class PanelDraw {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter() {
            return KnoxViewpoint.panelOwned;
        }
    }

    @Patch(className = "viewpoint.interact.LootRows", methodName = "move")
    public static class PanelWheel {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) int n) {
            return KnoxViewpoint.wheel(n);
        }
    }

    @Patch(className = "viewpoint.interact.LootMenu", methodName = "asks")
    public static class PanelKeys {
        @Patch.OnExit
        public static void exit(@Patch.Argument(0) int key, @Patch.Return(readOnly = false) int result) {
            result = KnoxViewpoint.asks(key, result);
        }
    }

    @Patch(className = "viewpoint.interact.LootMenu", methodName = "take")
    public static class PanelTake {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter() {
            return KnoxViewpoint.take();
        }
    }
}
