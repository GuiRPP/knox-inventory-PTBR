package knox.java;

import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.HashSet;

import org.lwjgl.opengl.GL11;
import org.lwjglx.BufferUtils;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.core.opengl.RenderThread;
import zombie.core.textures.Texture;
import zombie.core.textures.TextureID;

/**
 * Pictures the game can't draw by tinting (the author, 2026-11-05):
 *
 * A broken thing's icon in grey: a tint only multiplies, it darkens a colour but never
 * takes it away. The icon's pixels are read once from its page, made grey and kept as a
 * picture of its own, with the same size and offsets, so it lands where the icon does.
 *
 * A magazine not checked yet: diagonal stripes, one picture per size of a tile, drawn 1:1
 * in the category's colour. A single picture, so a ready list writes it down as any other
 * (KnoxDrawList; a tiled or cut drawing is not written down).
 *
 * Both are asked for from Lua while it draws, and made there and then on the render
 * context: it costs a moment once for each icon or size, nothing after that. What fails
 * is told once and returns nil: Lua then draws a plain dimmed icon or an even colour.
 */
public class KnoxIconFx {

    /** The largest page read: a bigger one is not an icons' page. */
    private static final int MAX_PAGE = 8192;
    /** A page's pixels are kept for a moment: several broken things read the same one. */
    private static final long PAGE_KEEP_MS = 3000;
    private static final int STRIPE_PERIOD = 8, STRIPE_WIDTH = 4;
    private static final int MAX_HATCH = 2048;

    private static final HashMap<Texture, Texture> GREY = new HashMap<>();
    private static final HashSet<Texture> GREY_FAILED = new HashSet<>();
    private static final HashMap<Long, Texture> HATCH = new HashMap<>();
    private static boolean hatchFailed;

    private static ByteBuffer page;
    private static int pageId = -1;
    private static long pageMs;

    /** A picture of our own: its size and place on the texture set here, not by the game. */
    private static final class Made extends Texture {
        Made(TextureID id, int w, int h, int hwW, int hwH, Texture like) {
            super(id, null);
            this.width = w;
            this.height = h;
            this.widthOrig = like != null ? like.getWidthOrig() : w;
            this.heightOrig = like != null ? like.getHeightOrig() : h;
            this.offsetX = like != null ? like.offsetX : 0;
            this.offsetY = like != null ? like.offsetY : 0;
            this.xStart = 0;
            this.yStart = 0;
            this.xEnd = (float) w / hwW;
            this.yEnd = (float) h / hwH;
            this.solid = false;
        }
    }

    private static int powerOfTwo(int v) {
        int p = 1;
        while (p < v) p <<= 1;
        return p;
    }

    private static void filter(TextureID id, int min, int mag) {
        int prev = GL11.glGetInteger(GL11.GL_TEXTURE_BINDING_2D);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, id.getID());
        GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MIN_FILTER, min);
        GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MAG_FILTER, mag);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, prev);
        Texture.lastTextureID = -1;
    }

    /** The icon in grey, nil if it can't be had (not loaded yet, or it failed). */
    @LuaMethod(name = "knoxGreyIcon", global = true)
    public static Texture knoxGreyIcon(Texture icon) {
        if (icon == null) return null;
        Texture grey = GREY.get(icon);
        if (grey == null) {
            if (GREY_FAILED.contains(icon) || !icon.isReady()) return null;
            try {
                grey = makeGrey(icon);
                GREY.put(icon, grey);
            } catch (Throwable t) {
                GREY_FAILED.add(icon);
                System.out.println("[Knox] a grey icon: " + t);
                return null;
            }
        }
        if (page != null && System.currentTimeMillis() - pageMs > PAGE_KEEP_MS) {
            page = null;
            pageId = -1;
        }
        return grey;
    }

    private static Texture makeGrey(Texture icon) throws Exception {
        final int hwW = icon.getWidthHW(), hwH = icon.getHeightHW();
        if (hwW <= 0 || hwH <= 0 || hwW > MAX_PAGE || hwH > MAX_PAGE) throw new IllegalStateException("page " + hwW + "x" + hwH);
        final int w = icon.getWidth(), h = icon.getHeight();
        final int x0 = Math.round(icon.getXStart() * hwW), y0 = Math.round(icon.getYStart() * hwH);
        if (w <= 0 || h <= 0 || x0 < 0 || y0 < 0 || x0 + w > hwW || y0 + h > hwH) throw new IllegalStateException("place " + x0 + "," + y0 + " " + w + "x" + h);
        final int outW = powerOfTwo(w), outH = powerOfTwo(h);
        final ByteBuffer out = BufferUtils.createByteBuffer(outW * outH * 4);
        final int[] filters = new int[2];
        RenderThread.invokeOnRenderContext(() -> {
            if (pageId != icon.getID() || page == null || page.capacity() != hwW * hwH * 4) {
                page = BufferUtils.createByteBuffer(hwW * hwH * 4);
                pageId = icon.getID();
                KnoxHealthPaint.read(icon, page);
            }
            int prev = GL11.glGetInteger(GL11.GL_TEXTURE_BINDING_2D);
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, icon.getID());
            filters[0] = GL11.glGetTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MIN_FILTER);
            filters[1] = GL11.glGetTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MAG_FILTER);
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, prev);
            Texture.lastTextureID = -1;
        });
        pageMs = System.currentTimeMillis();
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int from = ((y0 + y) * hwW + x0 + x) * 4, to = (y * outW + x) * 4;
                int r = page.get(from) & 255, g = page.get(from + 1) & 255, b = page.get(from + 2) & 255;
                byte lum = (byte) Math.round(0.299f * r + 0.587f * g + 0.114f * b);
                out.put(to, lum);
                out.put(to + 1, lum);
                out.put(to + 2, lum);
                out.put(to + 3, page.get(from + 3));
            }
        }
        final TextureID id = new TextureID(outW, outH, out);
        // (a mipmapped filter would look for levels this picture hasn't got)
        final int min = filters[0] == GL11.GL_NEAREST ? GL11.GL_NEAREST : GL11.GL_LINEAR;
        final int mag = filters[1] == GL11.GL_NEAREST ? GL11.GL_NEAREST : GL11.GL_LINEAR;
        RenderThread.invokeOnRenderContext(() -> filter(id, min, mag));
        return new Made(id, w, h, outW, outH, icon);
    }

    /** White stripes of this size, to be tinted: nil if they can't be had. */
    @LuaMethod(name = "knoxHatch", global = true)
    public static Texture knoxHatch(double width, double height) {
        final int w = (int) width, h = (int) height;
        if (hatchFailed || w <= 0 || h <= 0 || w > MAX_HATCH || h > MAX_HATCH) return null;
        long key = ((long) w << 32) | h;
        Texture t = HATCH.get(key);
        if (t != null) return t;
        try {
            final int outW = powerOfTwo(w), outH = powerOfTwo(h);
            ByteBuffer out = BufferUtils.createByteBuffer(outW * outH * 4);
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    int to = (y * outW + x) * 4;
                    out.put(to, (byte) 255);
                    out.put(to + 1, (byte) 255);
                    out.put(to + 2, (byte) 255);
                    out.put(to + 3, (byte) (stripe(x, y) ? 255 : 0));
                }
            }
            final TextureID id = new TextureID(outW, outH, out);
            RenderThread.invokeOnRenderContext(() -> filter(id, GL11.GL_NEAREST, GL11.GL_NEAREST));
            t = new Made(id, w, h, outW, outH, null);
            HATCH.put(key, t);
            return t;
        } catch (Throwable e) {
            hatchFailed = true;
            System.out.println("[Knox] a magazine's stripes: " + e);
            return null;
        }
    }

    /** Is this pixel on a stripe? (going up to the right, as the approved mockup) */
    static boolean stripe(int x, int y) {
        return (x + y) % STRIPE_PERIOD < STRIPE_WIDTH;
    }
}
