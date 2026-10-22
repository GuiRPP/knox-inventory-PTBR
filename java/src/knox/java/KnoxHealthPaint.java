package knox.java;

import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;

import javax.imageio.ImageIO;

import me.zed_0xff.zombie_buddy.Patch;

import org.lwjgl.opengl.GL11;
import org.lwjgl.opengl.GL30;
import org.lwjglx.BufferUtils;

import se.krka.kahlua.integration.annotations.LuaMethod;
import se.krka.kahlua.vm.KahluaTable;
import zombie.ZomboidFileSystem;
import zombie.core.SpriteRenderer;
import zombie.core.skinnedmodel.advancedanimation.AnimatedModel;
import zombie.core.skinnedmodel.model.ModelInstance;
import zombie.core.textures.SmartTexture;
import zombie.core.textures.Texture;
import zombie.core.textures.TextureDraw;
import zombie.ui.UI3DModel;

/**
 * The health tab's 3D character, painted every frame: the colour of each body
 * part, the light of the part under the mouse, the X-ray of a broken bone - laid
 * over the character's own baked skin, without rebuilding the model.
 *
 * Grid Character Hub (and the tab at first) dressed the model in hidden clothing
 * items whose texture is a part's mask: the game bakes a clothing item's tint into
 * the skin, so every colour change meant a new SurvivorDesc - the model rebuilt,
 * its animation started over, a pulse could only step.
 *
 * Here Lua hands over a list of layers each frame (knoxHealthPaint): a mask in
 * the skin's UV space (the mask clothing's own pictures, the bones of
 * tools/make_health_bones.ps1) and a colour with its strength. On the render
 * thread, before the model is drawn, the skin's GL texture - this UI model's own
 * bake, nothing else draws with it - is read once (a clean copy), and each frame
 * the clean copy with the layers over it is written back into it (glTexSubImage2D).
 * The mixing is done here on the CPU: 256x256 texels, a fraction of a millisecond.
 *
 * (Three tries on the GPU before, 2026-10-19: the game's TextureCombiner with a
 * shader of ours gave a skin without a trace of the layers - knox_health_paint.png
 * showed it - and swapping the texture handed to the model was not needed at all.
 * The skin's GL texture is in the same layout as the masks, row for row.)
 */
public class KnoxHealthPaint {

    /** A mask in texels (alpha 0..1, row 0 = the picture's top = the texture's row 0). */
    public static final class Mask {
        public final int w, h;
        public final float[] a;
        public int x0, y0, x1, y1;   // where it is not empty

        Mask(int w, int h, float[] a) {
            this.w = w;
            this.h = h;
            this.a = a;
            bounds();
        }

        void bounds() {
            x0 = w; y0 = h; x1 = -1; y1 = -1;
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    if (a[y * w + x] > 0.002f) {
                        if (x < x0) x0 = x;
                        if (x > x1) x1 = x;
                        if (y < y0) y0 = y;
                        if (y > y1) y1 = y;
                    }
                }
            }
        }
    }

    /** One layer of a frame's paint. */
    public static final class Layer {
        public Mask mask;
        public float r, g, b, a;
        public boolean light;   // light on the skin (towards white by rgb * a), not a colour over it
        public boolean see;     // the skin see-through by a (its alpha down, the colour premultiplied)
    }

    /** A painted model (render thread): its skin and the skin's clean texels. */
    public static final class State {
        public Texture skin;
        public int texId;
        public int w, h;
        public byte[] clean;
        public byte[] work;
        public ByteBuffer upload;
        public long lastSig;
        public boolean painted;
        // the skeleton's texture: its clean texels and what is shown on it
        public int boneTex;
        public byte[] boneClean, boneWork;
        public ByteBuffer boneUpload;
        public long boneSig = -1;
    }

    public static final Map<AnimatedModel, State> STATES = Collections.synchronizedMap(new WeakHashMap<>());
    /** A GL step failed: Lua goes back to the old way (mask clothing). */
    public static volatile boolean FAILED = false;

    private static final Map<String, Mask> MASKS = new HashMap<>();
    private static boolean told, dumped;

    // ------------------------------------------------------------------ masks

    /** A mask picture by its game path, its edge spread outward by `soft` texels (game thread, cached). */
    public static Mask mask(String path, float soft) {
        int sk = Math.round(soft * 2);
        String key = path + "#" + sk;
        if (MASKS.containsKey(key)) return MASKS.get(key);
        Mask m = null;
        try {
            Mask base = sk == 0 ? null : MASKS.get(path + "#0");
            if (base == null) {
                base = load(find(path));
                MASKS.put(path + "#0", base);
            }
            m = sk == 0 ? base : soften(base, sk / 2f);
        } catch (Throwable t) {
            System.out.println("[Knox] health paint: no mask " + path + ": " + t);
        }
        MASKS.put(key, m);
        return m;
    }

    /**
     * A game path's file: the game's own lookup (mods first), else beside this jar
     * (Knox Inventory/42/media/java/client/ - the mod's 42 folder three up).
     */
    static File find(String path) throws Exception {
        String s = ZomboidFileSystem.instance.getString(path);
        File f = s == null ? null : new File(s);
        if (f != null && f.isFile()) return f;
        File jar = new File(KnoxHealthPaint.class.getProtectionDomain().getCodeSource().getLocation().toURI());
        File mod = jar.getParentFile().getParentFile().getParentFile().getParentFile();
        File g = new File(mod, path.replace('/', File.separatorChar));
        if (g.isFile()) return g;
        throw new Exception("not found (" + s + ", " + g + ")");
    }

    public static Mask load(File f) throws Exception {
        BufferedImage img = ImageIO.read(f);
        if (img == null) throw new Exception("not a picture");
        int w = img.getWidth(), h = img.getHeight();
        float[] a = new float[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) a[y * w + x] = ((img.getRGB(x, y) >>> 24) & 255) / 255f;
        }
        return new Mask(w, h, a);
    }

    /**
     * A soft edge: the mask grown by the radius, then blurred by it (three box
     * passes, near a gaussian) - full inside the part, falling smoothly to nothing
     * over about twice the radius outside it, no step at the part's edge (the first
     * version kept the mask whole and blurred outside it: a step from 1 to a half
     * showed as a hard line - author, 2026-10-19). Inside the part it stays whole,
     * so no seam of the skin's layout shows there.
     */
    public static Mask soften(Mask m, float radius) {
        int r = Math.max(1, Math.round(radius));
        float[] b = grow(grow(m.a, m.w, m.h, r, true), m.w, m.h, r, false);
        for (int pass = 0; pass < 3; pass++) {
            b = boxBlur(b, m.w, m.h, r, true);
            b = boxBlur(b, m.w, m.h, r, false);
        }
        float[] out = new float[b.length];
        for (int i = 0; i < out.length; i++) out[i] = Math.max(m.a[i], Math.min(1f, b[i]));
        return new Mask(m.w, m.h, out);
    }

    /** The largest value within r along a row or a column. */
    static float[] grow(float[] src, int w, int h, int r, boolean horizontal) {
        float[] dst = new float[src.length];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                float v = 0;
                for (int k = -r; k <= r; k++) {
                    int xx = horizontal ? x + k : x, yy = horizontal ? y : y + k;
                    if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
                    float s = src[yy * w + xx];
                    if (s > v) v = s;
                }
                dst[y * w + x] = v;
            }
        }
        return dst;
    }

    static float[] boxBlur(float[] src, int w, int h, int r, boolean horizontal) {
        float[] dst = new float[src.length];
        float n = 2 * r + 1;
        if (horizontal) {
            for (int y = 0; y < h; y++) {
                float s = 0;
                for (int k = -r; k <= r; k++) s += src[y * w + Math.max(0, Math.min(w - 1, k))];
                for (int x = 0; x < w; x++) {
                    dst[y * w + x] = s / n;
                    s += src[y * w + Math.min(w - 1, x + r + 1)] - src[y * w + Math.max(0, x - r)];
                }
            }
        } else {
            for (int x = 0; x < w; x++) {
                float s = 0;
                for (int k = -r; k <= r; k++) s += src[Math.max(0, Math.min(h - 1, k)) * w + x];
                for (int y = 0; y < h; y++) {
                    dst[y * w + x] = s / n;
                    s += src[Math.min(h - 1, y + r + 1) * w + x] - src[Math.max(0, y - r) * w + x];
                }
            }
        }
        return dst;
    }

    // ------------------------------------------------------------------ mixing

    /**
     * The clean skin (RGBA, w x h, row 0 first) with the layers over it into `out`.
     * A colour: skin towards it by a * mask; light: skin times 1 + rgb * a * mask.
     * The skin's alpha stays.
     */
    public static void paint(byte[] clean, byte[] out, int w, int h, List<Layer> layers) {
        System.arraycopy(clean, 0, out, 0, clean.length);
        for (Layer l : layers) {
            Mask m = l.mask;
            if (m == null || m.x1 < 0) continue;
            // (a mask of another size: its texels scaled onto the skin's)
            int sx0 = m.x0 * w / m.w, sx1 = Math.min(w - 1, (m.x1 + 1) * w / m.w);
            int sy0 = m.y0 * h / m.h, sy1 = Math.min(h - 1, (m.y1 + 1) * h / m.h);
            for (int y = sy0; y <= sy1; y++) {
                int my = y * m.h / h;
                for (int x = sx0; x <= sx1; x++) {
                    float k = m.a[my * m.w + x * m.w / w] * l.a;
                    if (k <= 0.002f) continue;
                    if (k > 1f) k = 1f;
                    int i = (y * w + x) * 4;
                    float r = out[i] & 255, g = out[i + 1] & 255, b = out[i + 2] & 255;
                    if (l.see) {
                        // the model shader blends premultiplied (its colour is not times the
                        // texture's alpha): what goes see-through is darkened by as much
                        float keep = 1f - Math.min(0.92f, k);
                        out[i] = (byte) Math.round(r * keep);
                        out[i + 1] = (byte) Math.round(g * keep);
                        out[i + 2] = (byte) Math.round(b * keep);
                        out[i + 3] = (byte) Math.round((out[i + 3] & 255) * keep);
                        continue;
                    }
                    if (l.light) {
                        // screen: towards white by the light's colour - lighter, the skin's
                        // shading kept, never clipped into another hue (a multiply did:
                        // the face went yellow-green - author, 2026-10-19)
                        r += (255f - r) * l.r * k;
                        g += (255f - g) * l.g * k;
                        b += (255f - b) * l.b * k;
                    } else {
                        r += (l.r * 255f - r) * k;
                        g += (l.g * 255f - g) * k;
                        b += (l.b * 255f - b) * k;
                    }
                    out[i] = (byte) Math.min(255, Math.round(r));
                    out[i + 1] = (byte) Math.min(255, Math.round(g));
                    out[i + 2] = (byte) Math.min(255, Math.round(b));
                }
            }
        }
    }

    // ------------------------------------------------------------------ Lua

    static float num(KahluaTable t, int i) {
        Object o = t.rawget(Double.valueOf(i));
        return o instanceof Double ? ((Double) o).floatValue() : 0f;
    }

    /**
     * This frame's paint of a model: {path, r, g, b, a, soft, mode, path, ...}
     * (soft: how far the edge spreads, in texels; mode 0: a colour over the skin,
     * 1: light on it, 2: the skin see-through by a), and the skeleton's bones
     * shown: {block, alpha, ...} (block: part index * 3 - the bones the whole and the broken share, + 1 only the whole's, + 2 only the broken's). An empty
     * list: the clean skin. False: no paint here (no model yet, or it failed) -
     * Lua then paints the old way.
     */
    @LuaMethod(name = "knoxHealthPaint", global = true)
    public static boolean knoxHealthPaint(UI3DModel ui, KahluaTable layers, KahluaTable bones) {
        if (FAILED || ui == null) return false;
        AnimatedModel model = KnoxAvatar.modelOf(ui);
        ModelInstance root = model == null ? null : model.getModelInstance();
        if (root == null) return false;
        ArrayList<Layer> list = new ArrayList<>();
        long sig = 17;
        int n = layers == null ? 0 : layers.len();
        for (int i = 1; i + 6 <= n; i += 7) {
            Object p = layers.rawget(Double.valueOf(i));
            if (!(p instanceof String)) continue;
            Layer l = new Layer();
            l.mask = mask((String) p, num(layers, i + 5));
            if (l.mask == null) continue;
            l.r = num(layers, i + 1);
            l.g = num(layers, i + 2);
            l.b = num(layers, i + 3);
            l.a = num(layers, i + 4);
            float mode = num(layers, i + 6);
            l.light = mode > 0.5f && mode < 1.5f;
            l.see = mode > 1.5f;
            if (l.a <= 0.003f) continue;
            list.add(l);
            sig = sig * 31 + System.identityHashCode(l.mask);
            sig = sig * 31 + Math.round(l.r * 255) * 65536L + Math.round(l.g * 255) * 256L + Math.round(l.b * 255);
            sig = sig * 31 + Math.round(l.a * 400) + Math.round(mode) * 1000;
        }
        float[] show = new float[BLOCKS];
        long boneSig = 7;
        int nb = bones == null ? 0 : bones.len();
        for (int i = 1; i + 1 <= nb; i += 2) {
            int b = Math.round(num(bones, i));
            float al = Math.max(0f, Math.min(1f, num(bones, i + 1)));
            if (b >= 0 && b < BLOCKS && al > 0.003f) {
                show[b] = al;
                boneSig = boneSig * 31 + b * 1000L + Math.round(al * 255);
            }
        }
        State st = STATES.get(model);
        if (st == null) {
            st = new State();
            STATES.put(model, st);
        }
        SpriteRenderer.instance.drawGeneric(new Compose(st, root, list, sig, show, boneSig));
        return true;
    }

    // ------------------------------------------------------------------ the skeleton

    /** The skeleton texture's blocks (tools/healthpaint/SkeletonGen.java): 8 x 8 of 32 texels. */
    public static final int BLOCKS = 64, BLOCK = 32;

    /** The skeleton models of painted models: drawn near the camera (DrawCharSingular below). */
    public static final java.util.Set<ModelInstance> SKELETONS =
        Collections.synchronizedSet(Collections.newSetFromMap(new WeakHashMap<>()));
    public static volatile boolean SKEL_ANY = false;

    public static boolean isSkeleton(ModelInstance mi) {
        return mi != null && SKELETONS.contains(mi);
    }

    /** The skeleton among a model's parts (its model's name), or null. */
    static ModelInstance skeletonOf(ModelInstance root) {
        if (root == null || root.sub == null) return null;
        for (int i = 0; i < root.sub.size(); i++) {
            ModelInstance mi = root.sub.get(i);
            String nm = mi == null || mi.model == null ? null : mi.model.name;
            if (nm != null && nm.toLowerCase().contains("knoxskeleton")) return mi;
        }
        return null;
    }

    /** The skeleton texture's blocks shown by alpha (render thread): colour premultiplied, as the shader blends. */
    static void showBones(State st, ModelInstance root, float[] show, long boneSig) {
        ModelInstance sk = skeletonOf(root);
        if (sk == null) return;
        if (!SKELETONS.contains(sk)) {
            SKELETONS.add(sk);
            SKEL_ANY = true;
            System.out.println("[Knox] health paint: the skeleton is on the model");
        }
        Texture t = sk.tex;
        if (t == null || !t.isReady()) return;
        Texture gl = glTexture(t);
        if (gl == null || gl.getID() <= 0) return;
        int w = gl.getWidthHW(), h = gl.getHeightHW();
        if (w <= 0 || h <= 0) return;
        if (st.boneTex != gl.getID() || st.boneClean == null || st.boneClean.length != w * h * 4) {
            // the bones' colour made here, not read from the file (a picture all but
            // transparent may load without its colour): old ivory, a little darker
            // towards a piece's ends - the rows of its block run along it
            st.boneTex = gl.getID();
            st.boneClean = new byte[w * h * 4];
            st.boneWork = new byte[w * h * 4];
            st.boneUpload = BufferUtils.createByteBuffer(w * h * 4);
            // rows of a block (tools/healthpaint/SkeletonGen.java blockUV): 2..21 bone, a
            // little darker towards a piece's ends; 22..26 dark (sockets, cracks); 27.. cartilage
            int bh = BLOCK * h / 256;
            for (int y = 0; y < h; y++) {
                float row = (y % bh) * (float) BLOCK / bh;
                int r, g, b;
                if (row >= 27) { r = 184; g = 196; b = 204; }
                else if (row >= 22) { r = 42; g = 36; b = 32; }
                else {
                    float bv = (row - 2f) / 18f;
                    float shade = 0.82f + 0.18f * (float) Math.sin(Math.max(0, Math.min(1, bv)) * Math.PI);
                    r = Math.round(240 * shade); g = Math.round(232 * shade); b = Math.round(212 * shade);
                }
                for (int x = 0; x < w; x++) {
                    int i = (y * w + x) * 4;
                    st.boneClean[i] = (byte) r;
                    st.boneClean[i + 1] = (byte) g;
                    st.boneClean[i + 2] = (byte) b;
                }
            }
            st.boneSig = -1;
        }
        if (boneSig == st.boneSig) return;
        byte[] px = st.boneWork;
        java.util.Arrays.fill(px, (byte) 0);
        int bw = BLOCK * w / 256, bh = BLOCK * h / 256;
        for (int b = 0; b < BLOCKS; b++) {
            float al = show[b];
            if (al <= 0) continue;
            int x0 = (b % 8) * bw, y0 = (b / 8) * bh;
            for (int y = y0; y < y0 + bh && y < h; y++) {
                for (int x = x0; x < x0 + bw && x < w; x++) {
                    int i = (y * w + x) * 4;
                    px[i] = (byte) Math.round((st.boneClean[i] & 255) * al);
                    px[i + 1] = (byte) Math.round((st.boneClean[i + 1] & 255) * al);
                    px[i + 2] = (byte) Math.round((st.boneClean[i + 2] & 255) * al);
                    px[i + 3] = (byte) Math.round(255 * al);
                }
            }
        }
        st.boneUpload.clear();
        st.boneUpload.put(px);
        st.boneUpload.flip();
        write(gl, st.boneUpload, w, h);
        st.boneUpload.clear();
        st.boneSig = boneSig;
    }

    /**
     * The skeleton is drawn near the camera (its depth squeezed to the front of the
     * range): its bones show through the see-through skin they lie in. Only the
     * bones Java has made visible are there to see (the rest has alpha 0, which the
     * model shader discards).
     */
    @Patch(className = "zombie.core.skinnedmodel.advancedanimation.AnimatedModel", methodName = "DrawCharSingular")
    public static class SkeletonDepth {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) AnimatedModel.AnimatedModelInstanceRenderData data) {
            if (KnoxHealthPaint.SKEL_ANY && data != null && KnoxHealthPaint.isSkeleton(data.modelInstance)) {
                GL11.glDepthRange(0.0, 0.02);
            }
        }

        @Patch.OnExit
        public static void exit(@Patch.Argument(0) AnimatedModel.AnimatedModelInstanceRenderData data) {
            if (KnoxHealthPaint.SKEL_ANY && data != null && KnoxHealthPaint.isSkeleton(data.modelInstance)) {
                GL11.glDepthRange(0.0, 1.0);
            }
        }
    }

    @LuaMethod(name = "knoxHealthPaintFailed", global = true)
    public static boolean knoxHealthPaintFailed() {
        return FAILED;
    }

    /** The GL texture a skin is drawn with (a baked skin is a SmartTexture holding its result). */
    static Texture glTexture(Texture t) {
        if (t instanceof SmartTexture) {
            Texture r = ((SmartTexture) t).result;
            if (r != null) return r;
        }
        return t;
    }

    // ------------------------------------------------------------------ render thread

    /** Writes a frame's paint into the model's skin (render thread, before the model). */
    public static final class Compose extends TextureDraw.GenericDrawer {
        final State st;
        final ModelInstance root;
        final ArrayList<Layer> layers;
        final long sig;
        final float[] show;
        final long boneSig;

        Compose(State st, ModelInstance root, ArrayList<Layer> layers, long sig, float[] show, long boneSig) {
            this.st = st;
            this.root = root;
            this.layers = layers;
            this.sig = sig;
            this.show = show;
            this.boneSig = boneSig;
        }

        @Override
        public void render() {
            try {
                compose();
                showBones(st, root, show, boneSig);
            } catch (Throwable t) {
                FAILED = true;
                System.out.println("[Knox] health paint failed, back to mask clothing: " + t);
                t.printStackTrace(System.out);
            }
        }

        void compose() {
            Texture skin = root.tex;
            if (skin == null || !skin.isReady()) return;   // the skin is still being baked
            Texture gl = glTexture(skin);
            if (gl == null || gl.getID() <= 0) return;
            int w = gl.getWidthHW(), h = gl.getHeightHW();
            if (w <= 0 || h <= 0) return;
            if (st.skin != skin || st.texId != gl.getID() || st.w != w || st.h != h || st.clean == null) {
                // a skin not seen yet (the look refreshed, the game baked it anew): its clean texels
                st.skin = skin;
                st.texId = gl.getID();
                st.w = w;
                st.h = h;
                st.clean = new byte[w * h * 4];
                st.work = new byte[w * h * 4];
                st.upload = BufferUtils.createByteBuffer(w * h * 4);
                read(gl, st.upload);
                st.upload.get(st.clean);
                st.upload.clear();
                st.painted = false;
                st.lastSig = 0;
            }
            if (layers.isEmpty() && !st.painted) return;   // clean and staying clean
            if (sig == st.lastSig && st.painted == !layers.isEmpty()) return;   // the same as on it
            paint(st.clean, st.work, w, h, layers);
            st.upload.clear();
            st.upload.put(st.work);
            st.upload.flip();
            write(gl, st.upload, w, h);
            st.upload.clear();
            st.lastSig = sig;
            st.painted = !layers.isEmpty();
            if (!told) {
                told = true;
                System.out.println("[Knox] health paint: the model's skin is painted (" + w + "x" + h + ", " + layers.size() + " layers)");
            }
            if (!dumped && !layers.isEmpty()) {
                dumped = true;
                dump(st.work, w, h);
            }
        }
    }

    static void read(Texture t, ByteBuffer buf) {
        int prev = GL11.glGetInteger(GL11.GL_TEXTURE_BINDING_2D);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, t.getID());
        GL11.glPixelStorei(GL11.GL_PACK_ALIGNMENT, 4);
        GL11.glGetTexImage(GL11.GL_TEXTURE_2D, 0, GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, buf);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, prev);
        Texture.lastTextureID = -1;
    }

    static void write(Texture t, ByteBuffer buf, int w, int h) {
        int prev = GL11.glGetInteger(GL11.GL_TEXTURE_BINDING_2D);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, t.getID());
        GL11.glPixelStorei(GL11.GL_UNPACK_ALIGNMENT, 4);
        GL11.glTexSubImage2D(GL11.GL_TEXTURE_2D, 0, 0, 0, w, h, GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, buf);
        // the smaller levels too, if the skin has them (the model in the box can be drawn small)
        int minFilter = GL11.glGetTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MIN_FILTER);
        if (minFilter != GL11.GL_LINEAR && minFilter != GL11.GL_NEAREST) GL30.glGenerateMipmap(GL11.GL_TEXTURE_2D);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, prev);
        Texture.lastTextureID = -1;
    }

    /** Once: the painted skin to Zomboid/knox_health_paint.png (row 0 at the top, as the masks). */
    static void dump(byte[] px, int w, int h) {
        try {
            BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    int i = (y * w + x) * 4;
                    img.setRGB(x, y, ((px[i + 3] & 255) << 24) | ((px[i] & 255) << 16) | ((px[i + 1] & 255) << 8) | (px[i + 2] & 255));
                }
            }
            File f = new File(ZomboidFileSystem.instance.getCacheDir(), "knox_health_paint.png");
            ImageIO.write(img, "png", f);
            System.out.println("[Knox] health paint: the painted skin in " + f.getAbsolutePath());
        } catch (Throwable e) {
            System.out.println("[Knox] health paint: dump failed: " + e);
        }
    }
}
