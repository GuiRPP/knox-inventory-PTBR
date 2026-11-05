package knox.java;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.network.DesktopBrowser;

/**
 * Knox's Boosty page and Discord server in the player's browser (the post's support plate and
 * the coin in the top bar; the author, 2026-10-25, Discord 2026-11-05). The game's openUrl opens
 * only its own sites (Steam, projectzomboid.com, theindiestone.com, pzwiki.net) and drops any
 * other link without a word - so the button did nothing. Only Knox's own pages are opened here.
 */
public class KnoxLink {

    static final String BOOSTY = "https://boosty.to/knoxinventory";
    static final String DISCORD = "https://discord.gg/HKpREqdDqD";

    /** Open `url` (Knox's Boosty page or Discord invite only) in the browser; false: not opened. */
    @LuaMethod(name = "knoxOpenUrl", global = true)
    public static boolean knoxOpenUrl(String url) {
        if (url == null || !(url.equals(DISCORD) || url.equals(BOOSTY) || url.startsWith(BOOSTY + "/"))) return false;
        try {
            return DesktopBrowser.openURL(url);
        } catch (RuntimeException | LinkageError e) {
            return false;
        }
    }
}
