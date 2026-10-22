package knox.java;

import me.zed_0xff.zombie_buddy.Patch;

import se.krka.kahlua.integration.annotations.LuaMethod;

/**
 * While the Knox screen is open the game counts the mouse as over its
 * inventory (UIManager.isMouseOverInventory), as with its own inventory
 * windows: the character input then ignores Ctrl and the mouse buttons
 * (CharacterInputKeyBinding.isMouseOrControlKeyOverInventory), so Ctrl+click
 * selecting tiles no longer makes the character aim, and clicks don't swing.
 */
public class KnoxInput {

    /** Set by Lua when the Knox screen opens and closes. */
    public static volatile boolean screenOpen;

    @LuaMethod(name = "knoxSetScreenOpen", global = true)
    public static void knoxSetScreenOpen(boolean open) {
        screenOpen = open;
    }

    @Patch(className = "zombie.ui.UIManager", methodName = "isMouseOverInventory")
    public static class OverInventory {
        @Patch.OnExit
        public static void exit(@Patch.Return(readOnly = false) boolean result) {
            if (KnoxInput.screenOpen) result = true;
        }
    }
}
