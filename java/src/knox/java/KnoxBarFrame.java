package knox.java;

import static org.lwjgl.opengl.GL33.*;

import java.io.File;
import java.io.IOException;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.joml.Matrix3f;
import org.joml.Matrix4f;
import org.joml.Vector3f;
import org.lwjgl.BufferUtils;
import org.lwjgl.opengl.GL;
import org.lwjgl.opengl.GL11;

/**
 * The winter bar's own frame (the author, 2026-10-31: "максимально круто и правильно
 * освещена"; stages 2-5 of the plan). The game's shaders can't do what it asks, so the room
 * is drawn here: real shadows from the blizzard's light through the three openings, shafts
 * of light in the air by the same shadows, AO, glow, the mockup's picture. The heroes the
 * game draws go into this same frame, between begin() and end().
 *
 * Nothing of the game in here: tools\barframe runs this very code on the video card without
 * the game, takes the time and the picture. The game's side is KnoxBarLua.
 */
public final class KnoxBarFrame {
    /** Where the files are: in the game, through its file system. */
    public interface Source {
        /** The file, or null if there is none. */
        File file(String relative);
    }

    public static final float U = 1f / 1.22f;   // scene units in a metre

    // what moves on its own
    public static final int STILL = 0, DOOR = 1, LAMP = 2, PAPER = 3, NEEDLE = 4, PAGE = 5, GARLAND = 6, SWITCH = 7, PENCIL = 8, PINNED = 9, BOTTLE = 10, SWAG = 11;
    // how far the radio's needle goes along its dial (MenuGen: bar_radio_needle)
    private static final float NEEDLE_SPAN = 0.1667f * U;

    // --- the light, the mockup's (bar_final): one direction, three openings
    private static final Vector3f DIR = new Vector3f(0.17f, -0.42f, 1f).normalize();
    private static final float WALL_Z = -8f * U;
    private static final float SPLIT_A = -0.25f * U, SPLIT_B = 2.85f * U;
    private static final float[] SKY = {0x87 / 255f, 0xa9 / 255f, 0xbb / 255f};
    private static final float[] OPEN_POWER = {2.4f, 3.3f, 4.2f};
    private static final float[] AIR_POWER = {0.42f * 1.4f, 0.26f * 1.4f, 0.3f * 1.4f};
    private static final float[] AIR_COLOR = {0x9c / 255f, 0xbc / 255f, 0xcc / 255f};
    private static final float[] MOTE_COLOR = {0xcf / 255f * 0.35f, 0xe2 / 255f * 0.35f, 0xea / 255f * 0.35f};
    private static final float[] HEMI_SKY = {0x46 / 255f * 0.22f, 0x60 / 255f * 0.22f, 0x6e / 255f * 0.22f};
    private static final float[] HEMI_GROUND = {0x07 / 255f * 0.22f, 0x09 / 255f * 0.22f, 0x0a / 255f * 0.22f};
    // the light off the lit floor, in metres: x y z, strength, reach
    private static final float[][] FILLS = {
        {-1.2f, 0.25f, -5.4f, 0.55f, 4.5f}, {1.7f, 0.25f, -4.4f, 0.7f, 5f}, {3.9f, 0.25f, -6f, 0.9f, 5f},
        {0.3f, 0.35f, -2f, 0.4f, 4.5f}, {-1.6f, 2.6f, -1.4f, 0.35f, 5.5f}, {-1.9f, 1.9f, 1.9f, 0.28f, 3.6f},
        {-3.1f, 1.4f, -6f, 0.5f, 3f},
        // (the storm's light over what lies knocked over on the left: the author, 2026-11-02)
        {-4.1f, 1.7f, -0.7f, 0.5f, 3.2f},
    };
    private static final int DOOR_FILL = 2;
    private static final float[] FILL_COLOR = {0x6f / 255f, 0x98 / 255f, 0xad / 255f};
    // what shines back at the sky (room.frag), the model's name's: 0 for most
    private static final Map<String, Float> GLOSS = new HashMap<>();
    static {
        GLOSS.put("KnoxMenuBar.CounterTop", 0.45f);
        GLOSS.put("KnoxMenuBar.Whiskey", 0.8f);
        GLOSS.put("KnoxMenuBar.CounterThings", 0.5f);
        GLOSS.put("KnoxMenuBar.SmokerThings", 0.5f);
        GLOSS.put("KnoxMenuBar.Jukebox", 0.5f);
        GLOSS.put("KnoxMenuBar.Stove", 0.3f);
        GLOSS.put("KnoxMenuBar.Lamp", 0.35f);
        GLOSS.put("KnoxMenuBar.Radio", 0.25f);
        GLOSS.put("KnoxMenuBar.Floor", 0.12f);
        GLOSS.put("KnoxMenuBar.Trash", 0.05f);
    }

    // the game's, for the heroes' depth (knoxBarEnd gives the scene this near plane); near the eye for
    // the narrator's arm before it (KnoxBite; 0.5 was the game's - the author, 2026-11-02)
    static final float NEAR = 0.1f;
    private static final float FAR = 200f;
    private static final int STRIDE = 12;
    private static final int POINT_SPRITE = 0x8861;
    private static final int MOTES = 3200;

    private static final class Prop {
        String model;
        float x, y, z, rx, ry, rz, sx, sy, sz, r, g, b;
        int moves;
    }

    private static final class ModelFile {
        String mesh, texture;
        boolean glass;
    }

    private static final class Part {
        String texture;
        boolean glass;
        int moves;
        final Matrix4f base = new Matrix4f();
        final Matrix4f now = new Matrix4f();
        final Matrix3f normalNow = new Matrix3f();
        float seed;
        // a loose sheet (PAPER): its length along x, how high the draft lifts it now, the ripple's phase
        float length, lift, phase;
        // a journal's page (PAGE): since when it turns (-1: it lies, not drawn), its angle, the free edge's lag
        float pageFrom = -1f, pageAngle, pageLag;
        float[] data;
        int size;
        int[] indices;
        int indexCount;
        int vao, vbo, ibo;
        int textureId;

        void grow(int more) {
            if (data == null) data = new float[Math.max(4096, more)];
            else if (size + more > data.length) data = Arrays.copyOf(data, Math.max(data.length * 2, size + more));
        }

        void growIndex(int more) {
            if (indices == null) indices = new int[Math.max(4096, more)];
            else if (indexCount + more > indices.length) indices = Arrays.copyOf(indices, Math.max(indices.length * 2, indexCount + more));
        }
    }

    private static final class Program {
        final int id;
        final HashMap<String, Integer> uniforms = new HashMap<>();

        Program(int id) {
            this.id = id;
        }

        int u(String name) {
            Integer at = uniforms.get(name);
            if (at == null) {
                at = glGetUniformLocation(id, name);
                uniforms.put(name, at);
            }
            return at;
        }
    }

    private final Source source;
    private final ArrayList<Prop> props = new ArrayList<>();
    private final ArrayList<Part> still = new ArrayList<>();
    private final ArrayList<Part> moving = new ArrayList<>();
    private final HashMap<String, KnoxBarMesh.Picture> pictures = new HashMap<>();
    private final HashMap<String, Integer> textures = new HashMap<>();
    private final HashMap<String, String> shaderText = new HashMap<>();
    private final ArrayList<Integer> allBuffers = new ArrayList<>();

    private float[] camera = {32, -3.4f * U, 1.95f * U, 3.9f * U, -1f * U, 1.25f * U, -5f * U};
    // (where the menu looks from and how: the depth of the dead outside is as from there, tone.frag)
    private static final Vector3f HOME_EYE = new Vector3f(-3.4f * U, 1.95f * U, 3.9f * U);
    private static final Vector3f HOME_DIR = new Vector3f(2.4f, -0.7f, -8.9f).normalize();
    private volatile boolean high = true;
    private volatile float needleTarget = (float) Math.random();
    private float needleNow = needleTarget, needleTime;
    private volatile String failure;

    private boolean glReady, released;
    private int width, height, builtQuality = -1;
    private Program pRoom, pGlass, pShadow, pSky, pAo, pBlur, pAir, pTone, pMotes, pBloomDown, pBloomUp, pFinal, pWalker, pEmber, pBulb, pSnow, pPuff, pFocus, pDof;
    private int noMeshVao;
    // the shadow map: the still room once, each frame that and what moves
    private int shadowW, shadowH, shadowStatic, shadowNow, shadowStaticFbo, shadowNowFbo;
    private boolean shadowBuilt;
    private final Matrix4f lightMatrix = new Matrix4f();
    private float shadowDepthRange, shadowUvX, shadowUvY;
    // the frame
    private int samples;
    private int hdrFbo, hdrColor, hdrDepth;
    private int depthFbo, depthTex;
    private int pictureFbo, pictureTex;
    private int aoFbo, aoTex, aoFbo2, aoTex2;
    private int airFbo, airTex, airFbo2, airTex2;
    // the depth of field: the picture made soft off the focus; where the focus is (1/distance, one
    // pixel, this frame's and the last's)
    private int dofFbo, dofTex;
    private final int[] focusFbo = new int[2], focusTex = new int[2];
    private int focusNow;
    private boolean focusFresh = true;
    private volatile float focusU = 0.5f, focusV = 0.5f, focusPower, focusTol = 0.12f, focusDepth;
    private int white1, black1;
    private static final int BLOOM_STEPS = 5;
    private final int[] bloomFbo = new int[BLOOM_STEPS];
    private final int[] bloomTex = new int[BLOOM_STEPS];
    private final int[] bloomW = new int[BLOOM_STEPS];
    private final int[] bloomH = new int[BLOOM_STEPS];

    // what was before us, to give it back
    private int savedDraw, savedRead;
    private final int[] savedViewport = new int[4];
    private final FloatBuffer savedClear = BufferUtils.createFloatBuffer(4);
    private final java.nio.ByteBuffer savedMask = BufferUtils.createByteBuffer(4);
    private boolean began;

    private final FloatBuffer mat4 = BufferUtils.createFloatBuffer(16);
    private final FloatBuffer mat3 = BufferUtils.createFloatBuffer(9);
    private final FloatBuffer lampPos = BufferUtils.createFloatBuffer(24 * 4);
    private final FloatBuffer lampCol = BufferUtils.createFloatBuffer(24 * 3);
    private final Matrix4f proj = new Matrix4f(), view = new Matrix4f(), viewProj = new Matrix4f();
    private final Matrix4f invViewProj = new Matrix4f(), invProj = new Matrix4f();
    private final Matrix4f identity = new Matrix4f();
    private final Matrix3f identity3 = new Matrix3f();
    private final Vector3f eye = new Vector3f(), target = new Vector3f(), up = new Vector3f(0, 1, 0);

    // --- the figures (stage 4, the author 2026-10-31). The heroes are the game's own, drawn into
    // this frame by UI3DScene: here they are only their shadows in the sky's light, capsules laid
    // along their bones each frame (KnoxBarLua.knoxBarHero). The dead walking out in the whiteout
    // are the frame's: the game's walk clip as capsules (tools\barframe\poses.py), grey shapes
    // in the snow seen through the openings.
    public static final int HEROES = 3, CAPSULES = 12, CAPSULE = 7;
    private final float[] heroCaps = new float[HEROES * CAPSULES * CAPSULE];
    private final int[] heroCount = new int[HEROES];
    private boolean standInsShown;
    private final HashMap<String, ArrayList<float[]>> poses = new HashMap<>();
    private final HashMap<String, float[]> cycles = new HashMap<>();
    private ArrayList<float[]>[] walkFrames;
    private float[] walkCycle;
    // z, x to start from (metres), which way along x, the clip's pace, which clip
    private static final float[][] WALKERS = {
        {-11.4f, 0.5f, 1, 0.42f, 0}, {-12.8f, 6.5f, -1, 0.37f, 1}, {-14.6f, -2.5f, 1, 0.34f, 1}, {-16.5f, 9f, -1, 0.4f, 0},
    };
    // (off in the game: the dead are real models there; tools\\barframe has no game to draw them)
    boolean standInWalkers = true;
    private static final float WALK_FROM = -6f, WALK_TO = 10f;
    private static final float[] WALKER_COLOR = {0.42f * 0.36f, 0.46f * 0.36f, 0.49f * 0.36f};
    private Part cylinder, sphere;
    private final Matrix4f capsule = new Matrix4f(), figure = new Matrix4f();
    private final Matrix3f capsuleNormal = new Matrix3f();
    private final Vector3f capA = new Vector3f(), capB = new Vector3f(), capD = new Vector3f();
    private final org.joml.Quaternionf capTurn = new org.joml.Quaternionf();
    // the cigarette's ember: where, and how it glows (-1: none); the door: 0 as the wind has it, 1 open
    private float emberX, emberY, emberZ, emberGlow = -1, emberShown = 1;
    private float doorOpen;
    private static final float[] EMBER_COLOR = {0xff / 255f, 0x7a / 255f, 0x30 / 255f};

    // --- what lives (stage 5, the author 2026-10-31): the door, the snow blown in, the smoke, the
    // breath are KnoxBarLife's; the snow driven past the openings is the shader's. The wind's clocks:
    // how far it has carried things, so a gust speeds them up instead of throwing them about.
    private final KnoxBarLife life = new KnoxBarLife();
    private final float[] mouths = new float[HEROES * 6];
    private final float[] emberNow = new float[4];
    private float stepTime = -1, windIn, windOut;
    private int puffVao, puffVbo;
    private static final int SNOW = 7000;
    private static final float[] SNOW_COLOR = {0.24f, 0.29f, 0.33f}, SNOW_PALE = {1.1f, 1.16f, 1.2f};
    // by kind (a flake, smoke, breath), onto the picture: in the sky's light, in the room's dark
    private static final float[] PUFF_LIT = {0.75f, 0.85f, 0.92f, 0.42f, 0.47f, 0.52f, 0.42f, 0.47f, 0.52f};
    private static final float[] PUFF_DARK = {0.09f, 0.11f, 0.13f, 0.17f, 0.19f, 0.21f, 0.13f, 0.15f, 0.17f};

    // for tools\barframe: how long each pass takes on the card
    public boolean profile;
    private final int[] queries = new int[32];
    private final String[] queryNames = new String[32];
    private int queryCount;

    public KnoxBarFrame(Source source) {
        this.source = source;
    }

    // ------------------------------------------------------------- the main thread

    /** One thing of the room: a model's name in the bar's list; degrees, scene units. */
    public void prop(String model, float x, float y, float z, float rx, float ry, float rz,
                     float sx, float sy, float sz, float r, float g, float b, int moves) {
        Prop p = new Prop();
        p.model = model;
        p.x = x;
        p.y = y;
        p.z = z;
        p.rx = rx;
        p.ry = ry;
        p.rz = rz;
        p.sx = sx;
        p.sy = sy;
        p.sz = sz;
        p.r = r;
        p.g = g;
        p.b = b;
        p.moves = moves;
        props.add(p);
    }

    /** fov (vertical, degrees), eye x y z, target x y z; on the render thread, kept by reference. */
    public void camera(float[] sevenValues) {
        camera = sevenValues;
    }

    /** High: 4 samples a pixel, the air and the AO. Low: none of them, a smaller shadow map. */
    public void quality(boolean high) {
        this.high = high;
    }

    public String failure() {
        return failure;
    }

    /** Everything from the disk, into memory. Throws what's missing: then the menu stays in the camp. */
    // What's been read, for every next frame, and what the background has read ahead (prepare). The
    // pictures are given up to the video card and freed: one each, read again for the next.
    private static final java.util.concurrent.ConcurrentHashMap<String, String> TEXTS = new java.util.concurrent.ConcurrentHashMap<>();
    private static final java.util.concurrent.ConcurrentHashMap<String, KnoxBarMesh> MESHES = new java.util.concurrent.ConcurrentHashMap<>();
    private static final java.util.concurrent.ConcurrentHashMap<String, KnoxBarMesh.Picture> READY = new java.util.concurrent.ConcurrentHashMap<>();
    private static final java.util.concurrent.atomic.AtomicBoolean PREPARING = new java.util.concurrent.atomic.AtomicBoolean();
    // (how many times it was all forgotten: a read ahead still going then stops, and what it read goes too)
    private static final java.util.concurrent.atomic.AtomicInteger FORGOTTEN = new java.util.concurrent.atomic.AtomicInteger();
    private static final String[] SHADERS = {"room.vert", "room.frag", "glass.frag", "shadow.vert", "shadow.frag", "quad.vert",
        "sky.frag", "ao.frag", "blur.frag", "air.frag", "tone.frag", "motes.vert", "motes.frag",
        "bloom_down.frag", "bloom_up.frag", "final.frag", "walker.frag", "ember.vert", "ember.frag", "bulb.vert", "bulb.frag", 
        "snow.vert", "snow.frag", "puff.vert", "puff.frag", "focus.frag", "dof.frag"};

    private static String textOf(Source source, String relative) throws IOException {
        String t = TEXTS.get(relative);
        if (t != null) return t;
        File f = source.file(relative);
        if (f == null || !f.isFile()) throw new IOException("no file " + relative);
        t = new String(Files.readAllBytes(f.toPath()), StandardCharsets.UTF_8);
        TEXTS.put(relative, t);
        return t;
    }

    private static KnoxBarMesh meshOf(File file, String path, boolean drift) throws IOException {
        KnoxBarMesh mesh = MESHES.get(path);
        if (mesh != null) return mesh;
        mesh = path.endsWith(".obj") ? KnoxBarMesh.readObj(file) : KnoxBarMesh.readX(file);
        if (drift) mesh = KnoxBarMesh.smoothed(mesh);
        MESHES.put(path, mesh);
        return mesh;
    }

    /** All the bar's files read ahead, off the main thread; whatever is missing, load() will say. */
    public static void prepare(Source source) {
        if (!PREPARING.compareAndSet(false, true)) return;
        final int gen = FORGOTTEN.get();
        Thread t = new Thread(() -> {
            try {
                for (String name : SHADERS) {
                    if (FORGOTTEN.get() != gen) return;
                    textOf(source, "media/shaders/knoxbar/" + name);
                }
                textOf(source, "media/knox/bar_poses.txt");
                for (String list : new String[] {"media/knox/bar_models.txt", "media/knox/bar_vp.txt"}) {
                    Matcher m = MODEL.matcher(textOf(source, list));
                    while (m.find()) {
                        if (FORGOTTEN.get() != gen) return;
                        String mesh = m.group(2), texture = m.group(3);
                        mesh = mesh.startsWith("media/") ? mesh : "media/models_X/" + mesh + ".x";
                        texture = texture.startsWith("media/") ? texture : "media/textures/" + texture + ".png";
                        File meshFile = source.file(mesh), textureFile = source.file(texture);
                        if (meshFile != null && meshFile.isFile()) meshOf(meshFile, mesh, "Drift".equals(m.group(1)));
                        if (textureFile != null && textureFile.isFile() && !READY.containsKey(texture)) {
                            KnoxBarMesh.Picture p = KnoxBarMesh.picture(textureFile);
                            if (READY.putIfAbsent(texture, p) != null) p.free();
                        }
                    }
                }
            } catch (Throwable e) {
                System.out.println("[Knox] the bar's files ahead: " + e);
            } finally {
                PREPARING.set(false);
                // (the game came in while it read: what it put in after forget() would stay to the game's
                // end - overhaul, 2026-11-04)
                if (FORGOTTEN.get() != gen) clearRead();
            }
        }, "Knox bar files");
        t.setDaemon(true);
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
    }

    /** Into the game: what was read ahead off the memory. */
    public static void forget() {
        FORGOTTEN.incrementAndGet();
        clearRead();
    }

    private static void clearRead() {
        for (String key : new ArrayList<>(READY.keySet())) {
            KnoxBarMesh.Picture p = READY.remove(key);
            if (p != null) p.free();
        }
        MESHES.clear();
        TEXTS.clear();
    }

    public void load() throws IOException {
        Map<String, ModelFile> list = new HashMap<>();
        readModelList("media/knox/bar_models.txt", "KnoxMenuBar.", list);
        readModelList("media/knox/bar_vp.txt", "KnoxMenuBarVp.", list);
        for (String name : SHADERS) {
            shaderText.put(name, text("media/shaders/knoxbar/" + name));
        }
        readPoses(text("media/knox/bar_poses.txt"));
        Map<String, KnoxBarMesh> meshes = new HashMap<>();
        Map<String, Part> byTexture = new LinkedHashMap<>();
        Matrix4f m = new Matrix4f();
        Matrix3f n = new Matrix3f();
        Vector3f v = new Vector3f();
        for (Prop p : props) {
            ModelFile f = list.get(p.model);
            if (f == null) throw new IOException("no model " + p.model);
            KnoxBarMesh mesh = meshes.get(p.model);
            if (mesh == null) {
                mesh = meshOf(need(f.mesh), f.mesh, p.model.endsWith(".Drift"));
                meshes.put(p.model, mesh);
            }
            if (!pictures.containsKey(f.texture)) {
                KnoxBarMesh.Picture ahead = READY.remove(f.texture);
                pictures.put(f.texture, ahead != null ? ahead : KnoxBarMesh.picture(need(f.texture)));
            }
            matrixOf(p, m);
            Part part;
            if (p.moves != STILL) {
                part = new Part();
                part.texture = f.texture;
                part.glass = f.glass;
                part.moves = p.moves;
                part.base.set(m);
                part.seed = p.x * 3.1f + p.z * 1.7f;
                moving.add(part);
                m.identity();
            } else {
                String key = f.texture + (f.glass ? "#" : "");
                part = byTexture.get(key);
                if (part == null) {
                    part = new Part();
                    part.texture = f.texture;
                    part.glass = f.glass;
                    byTexture.put(key, part);
                    still.add(part);
                }
            }
            m.normal(n);
            float gloss = GLOSS.getOrDefault(p.model, 0f);
            int first = part.size / STRIDE;
            int count = mesh.vertices.length / 8;
            part.grow(count * STRIDE);
            for (int i = 0; i < count; i++) {
                int at = i * 8;
                v.set(mesh.vertices[at], mesh.vertices[at + 1], mesh.vertices[at + 2]);
                m.transformPosition(v);
                part.data[part.size++] = v.x;
                part.data[part.size++] = v.y;
                part.data[part.size++] = v.z;
                v.set(mesh.vertices[at + 3], mesh.vertices[at + 4], mesh.vertices[at + 5]);
                n.transform(v);
                part.data[part.size++] = v.x;
                part.data[part.size++] = v.y;
                part.data[part.size++] = v.z;
                part.data[part.size++] = mesh.vertices[at + 6];
                part.data[part.size++] = mesh.vertices[at + 7];
                part.data[part.size++] = p.r;
                part.data[part.size++] = p.g;
                part.data[part.size++] = p.b;
                part.data[part.size++] = gloss;
                if (p.moves == PAPER || p.moves == PAGE || p.moves == PINNED) part.length = Math.max(part.length, mesh.vertices[at]);
            }
            part.growIndex(mesh.indices.length);
            for (int index : mesh.indices) part.indices[part.indexCount++] = first + index;
        }
    }

    private static void matrixOf(Prop p, Matrix4f m) {
        m.identity().translate(p.x, p.y, p.z)
            .rotateXYZ((float) Math.toRadians(p.rx), (float) Math.toRadians(p.ry), (float) Math.toRadians(p.rz))
            .scale(p.sx, p.sy, p.sz);
    }

    private File need(String relative) throws IOException {
        File f = source.file(relative);
        if (f == null || !f.isFile()) throw new IOException("no file " + relative);
        return f;
    }

    private String text(String relative) throws IOException {
        return textOf(source, relative);
    }

    private static final Pattern MODEL = Pattern.compile("model\\s+(\\w+)\\s*\\{\\s*mesh\\s*=\\s*([^,\\s]+),\\s*texture\\s*=\\s*([^,\\s]+),\\s*shader\\s*=\\s*(\\w+),");

    /** The poses as capsules (tools\barframe\poses.py): a pose's name again is its clip's next frame. */
    @SuppressWarnings("unchecked")
    private void readPoses(String text) throws IOException {
        ArrayList<float[]> caps = null;
        HashMap<String, ArrayList<ArrayList<float[]>>> read = new HashMap<>();
        for (String line : text.split("\n")) {
            line = line.trim();
            if (line.isEmpty() || line.startsWith("#")) continue;
            String[] w = line.split("\\s+");
            if (w[0].equals("pose")) {
                caps = new ArrayList<>();
                read.computeIfAbsent(w[1], k -> new ArrayList<>()).add(caps);
            } else if (w[0].equals("cycle")) {
                cycles.put(w[1], new float[] {Float.parseFloat(w[2]), Float.parseFloat(w[3])});
            } else if (caps != null && w.length == CAPSULE) {
                float[] c = new float[CAPSULE];
                for (int i = 0; i < CAPSULE; i++) c[i] = Float.parseFloat(w[i]);
                caps.add(c);
            }
        }
        for (Map.Entry<String, ArrayList<ArrayList<float[]>>> e : read.entrySet()) {
            ArrayList<float[]> frames = new ArrayList<>();
            for (ArrayList<float[]> f : e.getValue()) {
                float[] flat = new float[f.size() * CAPSULE];
                for (int i = 0; i < f.size(); i++) System.arraycopy(f.get(i), 0, flat, i * CAPSULE, CAPSULE);
                frames.add(flat);
            }
            poses.put(e.getKey(), frames);
        }
        String[] clips = {"zwalk2", "zwalk3"};
        walkFrames = new ArrayList[clips.length];
        walkCycle = new float[clips.length * 2];
        for (int i = 0; i < clips.length; i++) {
            walkFrames[i] = poses.get(clips[i]);
            float[] c = cycles.get(clips[i]);
            if (walkFrames[i] == null || walkFrames[i].isEmpty() || c == null) throw new IOException("no pose " + clips[i]);
            walkCycle[i * 2] = c[0];
            walkCycle[i * 2 + 1] = c[1];
        }
    }

    /** One of the poses (tools\barframe: the harness's stand-ins), its first frame; null if there's none. */
    public float[] pose(String name) {
        ArrayList<float[]> f = poses.get(name);
        return f == null || f.isEmpty() ? null : f.get(0);
    }

    private void readModelList(String relative, String prefix, Map<String, ModelFile> into) throws IOException {
        Matcher m = MODEL.matcher(text(relative));
        while (m.find()) {
            ModelFile f = new ModelFile();
            String mesh = m.group(2), texture = m.group(3);
            f.mesh = mesh.startsWith("media/") ? mesh : "media/models_X/" + mesh + ".x";
            f.texture = texture.startsWith("media/") ? texture : "media/textures/" + texture + ".png";
            f.glass = "knoxBarGlow".equals(m.group(4));
            into.put(prefix + m.group(1), f);
        }
    }

    // ------------------------------------------------------------- the render thread

    /** Into our frame, cleared. The heroes the game draws next land in it. */
    public void begin() {
        if (failure != null || released) return;
        // (an end() that never came, the game's drawing threw in between: we are still bound,
        // what was saved before stands - QA, 2026-10-31)
        if (!began) {
            savedDraw = glGetInteger(GL_DRAW_FRAMEBUFFER_BINDING);
            savedRead = glGetInteger(GL_READ_FRAMEBUFFER_BINDING);
            glGetIntegerv(GL_VIEWPORT, savedViewport);
        }
        int w = savedViewport[2], h = savedViewport[3];
        if (w <= 0 || h <= 0) return;   // (the window minimised: nothing to draw into, nothing wrong)
        try {
            // (what a switch to the bar waits for, measured in the console: the author, 2026-11-02)
            long startedAt = System.nanoTime();
            boolean gl = !glReady;
            int quality = high ? 1 : 0;
            boolean targets = w != width || h != height || quality != builtQuality;
            if (gl || targets) forgetCardErrors();
            if (gl) buildGL();
            long glAt = System.nanoTime();
            if (targets) buildTargets(w, h, quality);
            if (gl || targets) {
                System.out.println("[Knox] the bar's frame: video card " + (glAt - startedAt) / 1000000 + " ms, targets "
                    + (System.nanoTime() - glAt) / 1000000 + " ms");
                cardOk("the build");
                watchFrames = WATCH_FRAMES;
            }
            glBindFramebuffer(GL_FRAMEBUFFER, hdrFbo);
            boolean scissor = glIsEnabled(GL_SCISSOR_TEST);
            boolean depthMask = glGetBoolean(GL_DEPTH_WRITEMASK);
            float clearDepth = glGetFloat(GL_DEPTH_CLEAR_VALUE);
            glGetFloatv(GL_COLOR_CLEAR_VALUE, savedClear);
            glGetBooleanv(GL_COLOR_WRITEMASK, savedMask);
            if (scissor) glDisable(GL_SCISSOR_TEST);
            glDepthMask(true);
            glColorMask(true, true, true, true);
            glClearColor(0, 0, 0, 0);
            glClearDepth(1);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            glClearColor(savedClear.get(0), savedClear.get(1), savedClear.get(2), savedClear.get(3));
            glClearDepth(clearDepth);
            giveBackColorMask();
            glDepthMask(depthMask);
            if (scissor) glEnable(GL_SCISSOR_TEST);
            began = true;
        } catch (Throwable t) {
            fail(t);
            giveBackFramebuffer();
        }
    }

    // ---- the photos on the wall of the missing (the author, 2026-11-01): each a dead hero's
    // portrait, taken once into a picture of its own (KnoxBarLua.knoxBarPhotoTake), then drawn with
    // the room, in its light.

    public static final int PHOTOS = 11, PHOTO_SIZE = 256;
    // (the empty frame's colour on the sheet's picture, as the bytes it is stored in)
    private static final float[] PHOTO_BACK = {52 / 255f, 46 / 255f, 42 / 255f};
    private final Part[] photoQuad = new Part[PHOTOS];
    private final int[] photoTex = new int[PHOTOS], photoDepth = new int[PHOTOS], photoFbo = new int[PHOTOS];
    private final boolean[] photoKept = new boolean[PHOTOS];
    private final int[] photoView = new int[4];
    private final java.nio.ByteBuffer photoMask = BufferUtils.createByteBuffer(16);
    private final FloatBuffer photoClear = BufferUtils.createFloatBuffer(16);
    private int photoDraw, photoRead;
    private boolean photoScissor, photoSrgb, photoDepthMask, photoOpen;
    private boolean photoFailed;   // the video card wouldn't make one: no more tries, the sheets keep their drawn ones

    // (strips across the photo, as the sheet's own: it bends with it)
    private static final int PHOTO_STRIPS = 6;

    /**
     * A photo's place on its sheet (the slot-th pinned one), metres in the sheet's own frame: how far
     * down from its pin the middle is, how far right of the sheet's middle; its size; the shade (main
     * thread, before load's frame). It rides the sheet in the wind (the author, 2026-11-02).
     */
    public void photoPlace(int slot, float down, float across, float w, float h, float shade) {
        if (slot < 0 || slot >= PHOTOS) return;
        Part p = new Part();
        p.grow((PHOTO_STRIPS + 1) * 2 * STRIDE);
        p.growIndex(PHOTO_STRIPS * 6);
        // (MenuGen's barLooseSheet: x runs down from the pin, face up y; the picture's left at +z.
        // u along the sheet; v from the picture's bottom, as a target's is)
        for (int i = 0; i <= PHOTO_STRIPS; i++) {
            float x = (down - h / 2 + h * i / PHOTO_STRIPS) * U, v = 1f - (float) i / PHOTO_STRIPS;
            for (int side = 0; side < 2; side++) {
                p.data[p.size++] = x;
                p.data[p.size++] = 0.0034f * U;
                p.data[p.size++] = (-across + (side == 0 ? w / 2 : -w / 2)) * U;
                p.data[p.size++] = 0;
                p.data[p.size++] = 1;
                p.data[p.size++] = 0;
                p.data[p.size++] = side;
                p.data[p.size++] = v;
                p.data[p.size++] = shade;
                p.data[p.size++] = shade;
                p.data[p.size++] = shade;
                p.data[p.size++] = 0;
            }
        }
        for (int i = 0; i < PHOTO_STRIPS; i++) {
            int a = i * 2;
            int[] order = {a, a + 1, a + 3, a, a + 3, a + 2};
            for (int k : order) p.indices[p.indexCount++] = k;
        }
        photoQuad[slot] = p;
    }

    public int photoTarget(int slot) {
        return photoFbo[slot];
    }

    /** Render thread: what follows lands in the photo's picture. False: it can't, nothing changed. */
    public boolean photoBegin(int slot) {
        if (failure != null || released || began || !glReady || photoOpen || photoFailed || slot < 0 || slot >= PHOTOS) return false;
        try {
            photoDraw = glGetInteger(GL_DRAW_FRAMEBUFFER_BINDING);
            photoRead = glGetInteger(GL_READ_FRAMEBUFFER_BINDING);
            glGetIntegerv(GL_VIEWPORT, photoView);
            photoScissor = glIsEnabled(GL_SCISSOR_TEST);
            photoSrgb = glIsEnabled(GL_FRAMEBUFFER_SRGB);
            photoDepthMask = glGetBoolean(GL_DEPTH_WRITEMASK);
            glGetBooleanv(GL_COLOR_WRITEMASK, photoMask);
            glGetFloatv(GL_COLOR_CLEAR_VALUE, photoClear);
            if (photoFbo[slot] == 0) {
                // (the texture bound here is put back: the game's own is bound on this unit - overhaul, 2026-11-04)
                int was = glGetInteger(GL_TEXTURE_BINDING_2D);
                photoTex[slot] = glGenTextures();
                glBindTexture(GL_TEXTURE_2D, photoTex[slot]);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_SRGB8_ALPHA8, PHOTO_SIZE, PHOTO_SIZE, 0, GL_RGBA, GL_UNSIGNED_BYTE, (java.nio.ByteBuffer) null);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glGenerateMipmap(GL_TEXTURE_2D);
                glBindTexture(GL_TEXTURE_2D, was);
                photoDepth[slot] = glGenRenderbuffers();
                glBindRenderbuffer(GL_RENDERBUFFER, photoDepth[slot]);
                glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, PHOTO_SIZE, PHOTO_SIZE);
                glBindRenderbuffer(GL_RENDERBUFFER, 0);
                photoFbo[slot] = glGenFramebuffers();
                glBindFramebuffer(GL_FRAMEBUFFER, photoFbo[slot]);
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, photoTex[slot], 0);
                glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, photoDepth[slot]);
                try {
                    check("photo");
                } catch (IllegalStateException e) {
                    // (not kept half made: the next try drew into it - overhaul, 2026-11-04)
                    photoFailed = true;
                    freePhoto(slot);
                    throw e;
                }
            }
            glBindFramebuffer(GL_FRAMEBUFFER, photoFbo[slot]);
            glViewport(0, 0, PHOTO_SIZE, PHOTO_SIZE);
            // (the game's colours as they are: the room reads the picture as sRGB)
            glDisable(GL_FRAMEBUFFER_SRGB);
            glDisable(GL_SCISSOR_TEST);
            glDepthMask(true);
            glColorMask(true, true, true, true);
            glClearColor(PHOTO_BACK[0], PHOTO_BACK[1], PHOTO_BACK[2], 1f);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            photoOpen = true;
            return true;
        } catch (Throwable t) {
            // (a photo isn't worth the frame: the sheet keeps its drawn one)
            System.out.println("[Knox] the bar's photo: " + t);
            photoGiveBack();
            return false;
        }
    }

    /** Render thread: the take is over; kept, it goes on the wall. */
    public void photoEnd(int slot, boolean keep) {
        if (!photoOpen) return;
        photoOpen = false;
        if (keep) {
            // (the room's shader throws away what its alpha says isn't there: all of it is)
            glColorMask(false, false, false, true);
            glClearColor(0f, 0f, 0f, 1f);
            glDisable(GL_SCISSOR_TEST);
            glClear(GL_COLOR_BUFFER_BIT);
            int was = glGetInteger(GL_TEXTURE_BINDING_2D);
            glBindTexture(GL_TEXTURE_2D, photoTex[slot]);
            glGenerateMipmap(GL_TEXTURE_2D);
            glBindTexture(GL_TEXTURE_2D, was);
            photoKept[slot] = true;
        }
        photoGiveBack();
    }

    private void photoGiveBack() {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, photoDraw);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, photoRead);
        glViewport(photoView[0], photoView[1], photoView[2], photoView[3]);
        glClearColor(photoClear.get(0), photoClear.get(1), photoClear.get(2), photoClear.get(3));
        glColorMask(photoMask.get(0) != 0, photoMask.get(1) != 0, photoMask.get(2) != 0, photoMask.get(3) != 0);
        glDepthMask(photoDepthMask);
        set(GL_SCISSOR_TEST, photoScissor);
        set(GL_FRAMEBUFFER_SRGB, photoSrgb);
    }

    /** The photos kept so far, on their sheets. The room's program is in use. */
    private void drawPhotos(Program p) {
        // (a hair over the sheet: at this distance the depth can't tell them apart otherwise. Given back
        // as it was: the game never sets it, Viewpoint may - overhaul, 2026-11-04)
        boolean any = false;
        for (int i = 0; i < PHOTOS && !any; i++) any = photoKept[i];
        if (!any) return;
        boolean offsetWas = glIsEnabled(GL_POLYGON_OFFSET_FILL);
        float factorWas = glGetFloat(GL_POLYGON_OFFSET_FACTOR), unitsWas = glGetFloat(GL_POLYGON_OFFSET_UNITS);
        glEnable(GL_POLYGON_OFFSET_FILL);
        glPolygonOffset(-1f, -1f);
        int slot = 0;
        for (int i = 0; i < moving.size() && slot < PHOTOS; i++) {
            Part sheet = moving.get(i);
            if (sheet.moves != PINNED) continue;
            Part q = photoQuad[slot];
            if (photoKept[slot] && q != null) {
                if (q.vao == 0) buildPart(q);
                uniform(p.u("uModel"), sheet.now);
                uniform3(p.u("uNormalMat"), sheet.normalNow);
                glUniform3f(p.u("uFlutter"), sheet.lift, sheet.phase, sheet.length);
                bindTexture(12, photoTex[slot]);
                glBindVertexArray(q.vao);
                glDrawElements(GL_TRIANGLES, q.indexCount, GL_UNSIGNED_INT, 0);
            }
            slot++;
        }
        glUniform3f(p.u("uFlutter"), 0f, 0f, 0f);
        glPolygonOffset(factorWas, unitsWas);
        set(GL_POLYGON_OFFSET_FILL, offsetWas);
    }

    private void freePhoto(int i) {
        if (photoFbo[i] != 0) glDeleteFramebuffers(photoFbo[i]);
        if (photoDepth[i] != 0) glDeleteRenderbuffers(photoDepth[i]);
        if (photoTex[i] != 0) glDeleteTextures(photoTex[i]);
        photoFbo[i] = photoDepth[i] = photoTex[i] = 0;
        photoKept[i] = false;
    }

    private void freePhotos() {
        for (int i = 0; i < PHOTOS; i++) {
            freePhoto(i);
            if (photoQuad[i] != null && photoQuad[i].vao != 0) glDeleteVertexArrays(photoQuad[i].vao);
            photoQuad[i] = null;
        }
        photoFailed = false;
    }

    /** Begun and still open: the heroes the game draws go into target(). */
    public boolean begun() {
        return began;
    }

    public int target() {
        return hdrFbo;
    }

    /**
     * The heroes' capsules, world scene units, {@link #CAPSULE} floats each: CAPSULES at most a
     * hero, `count` of them for each (0: no hero there). Copied.
     */
    public void heroes(float[] capsules, int[] count) {
        System.arraycopy(capsules, 0, heroCaps, 0, heroCaps.length);
        System.arraycopy(count, 0, heroCount, 0, HEROES);
    }

    /** The cigarette's ember, world scene units; glow 0..1 (a drag), below 0: none; shown 0..1: its smoker out of the dark. */
    public void ember(float x, float y, float z, float glow, float shown) {
        emberX = x;
        emberY = y;
        emberZ = z;
        emberGlow = glow;
        emberShown = shown;
    }

    /**
     * Where each hero breathes from: HEROES of x y z, then which way (world scene units; none: 0 0 0).
     * Copied.
     */
    public void mouths(float[] sixEach) {
        System.arraycopy(sixEach, 0, mouths, 0, mouths.length);
    }

    /** How many times the door has slammed so far, and how hard the last time, 0..1 (for its sound). */
    public int doorBangs() {
        return life.bangs();
    }

    public float doorBangPower() {
        return life.bangPower();
    }

    /** The gust now, 0..1 (for the sound, on the main thread). */
    public float gustNow() {
        return gustAt(lastTime);
    }

    /** How far the door lets the storm in now, 0..1 (for the sound, on the main thread). */
    public float doorLetsIn() {
        float time = lastTime;
        return Math.max(doorOpen, life.doorLetsIn(time, gustAt(time)));
    }

    /** 0: the door as the wind has it; 1: open wide (a hero going out). */
    public void door(float open) {
        doorOpen = open;
    }

    /** tools\barframe: the heroes' stand-ins drawn too, as grey figures in the room's light. */
    public void showStandIns(boolean shown) {
        standInsShown = shown;
    }

    // The first frames of anything new on the card are watched: each pass asks it whether it took that
    // pass, and the last frame looks at the picture itself. A card that compiles every shader and then
    // draws nothing gave a black menu with no word said (QA, 2026-11-04: none of the GLSL has been on
    // AMD, Intel or Mesa). What's wrong goes through fail(), and Lua takes the player to the camp. Only
    // the first frames: asking the card makes the driver wait.
    private static final int WATCH_FRAMES = 8;
    // (linear, before the glow; the room at its darkest stands far above it: tools/barframe, both
    // qualities, 2026-11-04)
    private static final float ALIVE = 0.02f;
    private int watchFrames, watchFbo;
    private boolean dofWatched;
    private FloatBuffer watchRow;

    private static void forgetCardErrors() {
        // (bounded: a lost context can answer for ever)
        for (int i = 0; i < 16 && glGetError() != GL_NO_ERROR; i++) { }
    }

    private static void cardOk(String what) {
        int e = glGetError();
        if (e != GL_NO_ERROR) throw new IllegalStateException("the video card refused " + what + ": 0x" + Integer.toHexString(e));
    }

    /** The last watched frame: a look along three rows of what goes to the screen. */
    private void lookAtPicture() {
        int pack = glGetInteger(GL_PIXEL_PACK_BUFFER_BINDING);
        glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, watchFbo);
        int need = width * 4;
        if (watchRow == null || watchRow.capacity() < need) watchRow = BufferUtils.createFloatBuffer(need);
        boolean alive = false;
        for (int r = 1; r <= 3 && !alive; r++) {
            watchRow.clear();
            glReadPixels(0, height * r / 4, width, 1, GL_RGBA, GL_FLOAT, watchRow);
            for (int x = 0; x < width && !alive; x += 4) {
                alive = watchRow.get(x * 4) + watchRow.get(x * 4 + 1) + watchRow.get(x * 4 + 2) > ALIVE;
            }
        }
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pack);
        cardOk("the look at the picture");
        if (!alive) throw new IllegalStateException("the picture stayed black");
    }

    /** The room around the heroes, the air, the picture: onto whatever was the target at begin(). */
    public void end(float time) {
        if (!began) return;
        began = false;
        // everything we're about to touch, to hand it back as it was
        int program = glGetInteger(GL_CURRENT_PROGRAM);
        int vao = glGetInteger(GL_VERTEX_ARRAY_BINDING);
        int arrayBuffer = glGetInteger(GL_ARRAY_BUFFER_BINDING);
        int active = glGetInteger(GL_ACTIVE_TEXTURE);
        boolean blend = glIsEnabled(GL_BLEND), depth = glIsEnabled(GL_DEPTH_TEST), cull = glIsEnabled(GL_CULL_FACE);
        boolean scissor = glIsEnabled(GL_SCISSOR_TEST), stencil = glIsEnabled(GL_STENCIL_TEST);
        boolean alpha = glIsEnabled(GL11.GL_ALPHA_TEST), multi = glIsEnabled(GL_MULTISAMPLE);
        boolean pointSize = glIsEnabled(GL_PROGRAM_POINT_SIZE), srgb = glIsEnabled(GL_FRAMEBUFFER_SRGB);
        boolean depthMask = glGetBoolean(GL_DEPTH_WRITEMASK);
        int depthFunc = glGetInteger(GL_DEPTH_FUNC);
        int srcRgb = glGetInteger(GL_BLEND_SRC_RGB), dstRgb = glGetInteger(GL_BLEND_DST_RGB);
        int srcA = glGetInteger(GL_BLEND_SRC_ALPHA), dstA = glGetInteger(GL_BLEND_DST_ALPHA);
        int blendEq = glGetInteger(GL_BLEND_EQUATION_RGB);
        glGetBooleanv(GL_COLOR_WRITEMASK, savedMask);
        try {
            // (what the game's own drawing left behind isn't ours to answer for)
            if (watchFrames > 0) forgetCardErrors();
            glDisable(GL_BLEND);
            glDisable(GL_CULL_FACE);
            glDisable(GL_SCISSOR_TEST);
            glDisable(GL_STENCIL_TEST);
            glDisable(GL11.GL_ALPHA_TEST);
            glDisable(GL_FRAMEBUFFER_SRGB);
            glEnable(GL_MULTISAMPLE);
            glEnable(GL_PROGRAM_POINT_SIZE);
            glColorMask(true, true, true, true);
            glBlendEquation(GL_FUNC_ADD);
            render(time);
            if (watchFrames > 0) {
                cardOk("the frame");
                if (--watchFrames == 0) lookAtPicture();
            }
        } catch (Throwable t) {
            fail(t);
        }
        // back as it was
        for (int unit = 8; unit <= 13; unit++) {
            glActiveTexture(GL_TEXTURE0 + unit);
            glBindTexture(GL_TEXTURE_2D, 0);
            glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
        }
        glActiveTexture(active);
        glUseProgram(program);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, arrayBuffer);
        set(GL_BLEND, blend);
        set(GL_DEPTH_TEST, depth);
        set(GL_CULL_FACE, cull);
        set(GL_SCISSOR_TEST, scissor);
        set(GL_STENCIL_TEST, stencil);
        set(GL11.GL_ALPHA_TEST, alpha);
        set(GL_MULTISAMPLE, multi);
        set(GL_PROGRAM_POINT_SIZE, pointSize);
        set(GL_FRAMEBUFFER_SRGB, srgb);
        glDepthMask(depthMask);
        glDepthFunc(depthFunc);
        glDepthRange(0, 1);
        glBlendFuncSeparate(srcRgb, dstRgb, srcA, dstA);
        glBlendEquation(blendEq);
        giveBackColorMask();
        giveBackFramebuffer();
    }

    /** The menu is loading a save: the frame's targets off the video card till it's back (begin() builds them anew). */
    public void rest() {
        // (queued only when no frame was begun: still begun means its end() was lost - QA, 2026-10-31)
        if (began) {
            began = false;
            giveBackColorMask();
            giveBackFramebuffer();
        }
        freeTargets();
    }

    private void giveBackColorMask() {
        glColorMask(savedMask.get(0) != 0, savedMask.get(1) != 0, savedMask.get(2) != 0, savedMask.get(3) != 0);
    }

    private void giveBackFramebuffer() {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, savedDraw);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, savedRead);
        glViewport(savedViewport[0], savedViewport[1], savedViewport[2], savedViewport[3]);
    }

    private static void set(int what, boolean on) {
        if (on) glEnable(what);
        else glDisable(what);
    }

    private void fail(Throwable t) {
        failure = String.valueOf(t);
        began = false;
        System.out.println("KnoxBarFrame: " + failure);
        t.printStackTrace(System.out);
    }

    static float gustAt(float t) {
        float s = (float) (Math.sin(t * 0.31) + 0.6 * Math.sin(t * 0.73 + 1.3) + 0.35 * Math.sin(t * 1.7 + 0.4));
        float g = Math.max(0f, Math.min(1f, (s - 0.2f) / 1.3f));
        return g * g * (3f - 2f * g);
    }

    // (volatile: the sound asks on the main thread)
    private volatile float lastTime;

    private void render(float time) {
        lastTime = time;
        // (not "high": the main thread may have changed it since begin(), and the targets are begin()'s)
        boolean best = builtQuality == 1;
        float[] c = camera;
        eye.set(c[1], c[2], c[3]);
        target.set(c[4], c[5], c[6]);
        // (the head's roll on the walk about the bar: KnoxBarWalkLua)
        if (c.length > 9) up.set(c[7], c[8], c[9]);
        proj.setPerspective((float) Math.toRadians(c[0]), width / (float) height, NEAR, FAR);
        view.setLookAt(eye, target, up);
        proj.mul(view, viewProj);
        viewProj.invert(invViewProj);
        proj.invert(invProj);
        float gust = gustAt(time);
        queryCount = 0;

        // (animations off: the time stands, and all with it. A long frame doesn't fling anything)
        float dt = stepTime < 0 ? 0f : Math.max(0f, Math.min(0.1f, time - stepTime));
        stepTime = time;
        windIn += dt * (1f + 1.5f * gust);
        windOut += dt * (0.6f + 1.6f * gust);
        emberNow[0] = emberX;
        emberNow[1] = emberY;
        emberNow[2] = emberZ;
        emberNow[3] = emberShown > 0 ? emberGlow : -1;
        life.step(dt, time, emberNow, mouths, doorOpen);

        moveThings(time, gust);
        mark("start");

        updateShadow();
        mark("shadow");

        // the room over what the heroes left
        glBindFramebuffer(GL_FRAMEBUFFER, hdrFbo);
        glViewport(0, 0, width, height);
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LEQUAL);
        glDepthMask(true);
        useRoom(pRoom);
        bindTexture(9, shadowNow);
        glUniform1i(pRoom.u("uShadow"), 9);
        uniform(pRoom.u("uLightViewProj"), lightMatrix);
        glUniform3f(pRoom.u("uLightDir"), DIR.x, DIR.y, DIR.z);
        float breath = 1f + 0.26f * gust;
        glUniform3f(pRoom.u("uSky"), SKY[0] * breath, SKY[1] * breath, SKY[2] * breath);
        glUniform2f(pRoom.u("uSplit"), SPLIT_A, SPLIT_B);
        glUniform3f(pRoom.u("uOpenPower"), OPEN_POWER[0], OPEN_POWER[1], OPEN_POWER[2]);
        glUniform1f(pRoom.u("uWallZ"), WALL_Z);
        glUniform3f(pRoom.u("uShadowScale"), shadowUvX, shadowUvY, shadowDepthRange);
        glUniform3f(pRoom.u("uEye"), eye.x, eye.y, eye.z);
        glUniform3f(pRoom.u("uHemiSky"), HEMI_SKY[0], HEMI_SKY[1], HEMI_SKY[2]);
        glUniform3f(pRoom.u("uHemiGround"), HEMI_GROUND[0], HEMI_GROUND[1], HEMI_GROUND[2]);
        lampPos.clear();
        lampCol.clear();
        int lamps = FILLS.length;
        // (the door shut: the floor before it has no light to give back; QA, 2026-10-31)
        float doorFill = 0.15f + 0.85f * Math.max(doorOpen, life.doorLetsIn(lastTime, gust));
        for (float[] f : FILLS) {
            lampPos.put(f[0] * U).put(f[1] * U).put(f[2] * U).put(f[4] * U);
            float k = f[3] * (1f + 0.14f * gust);
            if (f == FILLS[DOOR_FILL]) k *= doorFill;
            lampCol.put(FILL_COLOR[0] * k).put(FILL_COLOR[1] * k).put(FILL_COLOR[2] * k);
        }
        if (emberGlow >= 0) {
            // (the mockup's: 2.2 to 1.2 m; a drag makes it more)
            float k = 2.6f * (0.4f + 0.6f * emberGlow) * emberShown;   // (3.2 was too much: the author, 2026-11-01)
            lampPos.put(emberX).put(emberY).put(emberZ).put((1.2f + 0.4f * emberGlow) * U);
            lampCol.put(EMBER_COLOR[0] * k).put(EMBER_COLOR[1] * k).put(EMBER_COLOR[2] * k);
            lamps++;
        }
        if (garlandNow > 0f) {
            for (int i = 0; i < GARLAND_LAMPS.length; i++) {
                float[] g = GARLAND_LAMPS[i];
                float k = g[7] * garlandNow;
                lampPos.put(lampsAt[i * 3]).put(lampsAt[i * 3 + 1]).put(lampsAt[i * 3 + 2]).put(g[6] * U);
                lampCol.put(g[3] * k).put(g[4] * k).put(g[5] * k);
                lamps++;
            }
        }
        glUniform1i(pRoom.u("uLampsShining"), garlandNow > 0f ? GARLAND_LAMPS.length : 0);
        lampPos.flip();
        lampCol.flip();
        glUniform4fv(pRoom.u("uLampPos"), lampPos);
        glUniform3fv(pRoom.u("uLampCol"), lampCol);
        glUniform1i(pRoom.u("uLamps"), lamps);
        glUniform1i(pRoom.u("uSearch"), best ? 10 : 6);
        glUniform1i(pRoom.u("uSoften"), best ? 20 : 8);
        drawParts(pRoom, false);
        drawPhotos(pRoom);
        if (standInsShown) {
            bindTexture(12, white1);
            for (int h = 0; h < HEROES; h++) drawCapsules(pRoom, heroCaps, h * CAPSULES * CAPSULE, heroCount[h], null, true);
        }
        mark("room");

        // the whiteout, where nothing stands (from the far end of depth: alpha 0 too)
        glDepthMask(false);
        glDepthRange(1, 1);
        glUseProgram(pSky.id);
        uniform(pSky.u("uInvViewProj"), invViewProj);
        glUniform3f(pSky.u("uEye"), eye.x, eye.y, eye.z);
        glUniform1f(pSky.u("uTime"), time);
        glUniform1f(pSky.u("uGust"), gust);
        glBindVertexArray(noMeshVao);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glDepthRange(0, 1);
        mark("sky");

        // the dead out in the whiteout: shapes in the snow over the sky (its alpha 0 stays: no fog
        // of the room on them, nor a depth of theirs)
        glEnable(GL_BLEND);
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
        glUseProgram(pWalker.id);
        uniform(pWalker.u("uViewProj"), viewProj);
        glUniform3f(pWalker.u("uColor"), WALKER_COLOR[0], WALKER_COLOR[1], WALKER_COLOR[2]);
        glUniform1f(pWalker.u("uGust"), gust);
        drawWalkers(pWalker, true);
        glDisable(GL_BLEND);
        mark("walkers");

        // the snow driven past the openings: over the sky and the dead, behind the room
        glEnable(GL_BLEND);
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
        glUseProgram(pSnow.id);
        uniform(pSnow.u("uViewProj"), viewProj);
        glUniform1f(pSnow.u("uWind"), windOut);
        glUniform1f(pSnow.u("uWindNow"), 0.6f + 1.6f * gust);
        glUniform1f(pSnow.u("uPixel"), height / 1080f);
        glUniform2f(pSnow.u("uScreen"), width, height);
        glUniform1f(pSnow.u("uAlpha"), 0.8f);
        glUniform1f(pSnow.u("uProjY"), proj.m11());
        glUniform3f(pSnow.u("uColor"), SNOW_COLOR[0], SNOW_COLOR[1], SNOW_COLOR[2]);
        glUniform3f(pSnow.u("uPale"), SNOW_PALE[0], SNOW_PALE[1], SNOW_PALE[2]);
        glBindVertexArray(noMeshVao);
        glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, SNOW);
        glDisable(GL_BLEND);
        mark("snow");

        // the panes, over the whiteout
        glEnable(GL_BLEND);
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
        useRoom(pGlass);
        drawParts(pGlass, true);
        glDisable(GL_BLEND);
        glDisable(GL_DEPTH_TEST);
        mark("glass");

        // one depth without the samples: the AO, the air, the motes read it
        glBindFramebuffer(GL_READ_FRAMEBUFFER, hdrFbo);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, depthFbo);
        glBlitFramebuffer(0, 0, width, height, 0, 0, width, height, GL_DEPTH_BUFFER_BIT, GL_NEAREST);
        mark("depth");

        int halfW = Math.max(1, width / 2), halfH = Math.max(1, height / 2);
        int ao = white1, air = black1;
        if (best) {
            glBindFramebuffer(GL_FRAMEBUFFER, aoFbo);
            glViewport(0, 0, halfW, halfH);
            glUseProgram(pAo.id);
            bindTexture(8, depthTex);
            glUniform1i(pAo.u("uDepth"), 8);
            uniform(pAo.u("uProj"), proj);
            uniform(pAo.u("uInvProj"), invProj);
            glUniform2f(pAo.u("uTexel"), 1f / halfW, 1f / halfH);
            glBindVertexArray(noMeshVao);
            glDrawArrays(GL_TRIANGLES, 0, 3);
            blur(aoTex, aoFbo2, 1f / halfW, 0f);
            blur(aoTex2, aoFbo, 0f, 1f / halfH);
            ao = aoTex;
            mark("ao");

            glBindFramebuffer(GL_FRAMEBUFFER, airFbo);
            glViewport(0, 0, halfW, halfH);
            glUseProgram(pAir.id);
            bindTexture(8, depthTex);
            bindTexture(9, shadowNow);
            glUniform1i(pAir.u("uDepth"), 8);
            glUniform1i(pAir.u("uShadow"), 9);
            uniform(pAir.u("uInvViewProj"), invViewProj);
            uniform(pAir.u("uLightViewProj"), lightMatrix);
            glUniform3f(pAir.u("uEye"), eye.x, eye.y, eye.z);
            glUniform3f(pAir.u("uLightDir"), DIR.x, DIR.y, DIR.z);
            glUniform2f(pAir.u("uSplit"), SPLIT_A, SPLIT_B);
            glUniform3f(pAir.u("uAirPower"), AIR_POWER[0], AIR_POWER[1], AIR_POWER[2]);
            glUniform1f(pAir.u("uWallZ"), WALL_Z);
            glUniform1f(pAir.u("uTime"), time);
            glUniform1f(pAir.u("uGust"), gust);
            glUniform3f(pAir.u("uAirColor"), AIR_COLOR[0], AIR_COLOR[1], AIR_COLOR[2]);
            glUniform1i(pAir.u("uSteps"), 32);
            glBindVertexArray(noMeshVao);
            glDrawArrays(GL_TRIANGLES, 0, 3);
            blur(airTex, airFbo2, 1f / halfW, 0f);
            blur(airTex2, airFbo, 0f, 1f / halfH);
            air = airTex;
            mark("air");
        }

        // light into the picture, sample by sample
        glBindFramebuffer(GL_FRAMEBUFFER, pictureFbo);
        glViewport(0, 0, width, height);
        glUseProgram(pTone.id);
        bindMultisample(8, hdrColor);
        bindMultisample(9, hdrDepth);
        bindTexture(10, ao);
        bindTexture(11, air);
        glUniform1i(pTone.u("uHdr"), 8);
        glUniform1i(pTone.u("uDepth"), 9);
        glUniform1i(pTone.u("uAo"), 10);
        glUniform1i(pTone.u("uAir"), 11);
        glUniform1i(pTone.u("uSamples"), samples);
        glUniform1f(pTone.u("uNear"), NEAR);
        glUniform1f(pTone.u("uFar"), FAR);
        uniform(pTone.u("uInvViewProj"), invViewProj);
        glUniform3f(pTone.u("uHomeEye"), HOME_EYE.x, HOME_EYE.y, HOME_EYE.z);
        glUniform3f(pTone.u("uHomeDir"), HOME_DIR.x, HOME_DIR.y, HOME_DIR.z);
        glBindVertexArray(noMeshVao);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        unbindMultisample(8);
        unbindMultisample(9);
        mark("tone");

        // the motes: to the picture, behind what stands in front of them
        if (best) {
            glEnable(GL_DEPTH_TEST);
            glDepthFunc(GL_LEQUAL);
            glDepthMask(false);
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE);
            glUseProgram(pMotes.id);
            uniform(pMotes.u("uViewProj"), viewProj);
            uniform(pMotes.u("uLightViewProj"), lightMatrix);
            bindTexture(9, shadowNow);
            glUniform1i(pMotes.u("uShadow"), 9);
            glUniform3f(pMotes.u("uBoxMin"), -2.4f * U, 0.02f * U, -8f * U);
            glUniform3f(pMotes.u("uBoxSize"), 8.5f * U, 2.6f * U, 6.5f * U);
            glUniform1f(pMotes.u("uTime"), time);
            glUniform1f(pMotes.u("uWind"), windIn);
            glUniform1f(pMotes.u("uGust"), gust);
            glUniform1f(pMotes.u("uPixel"), height / 1080f);
            glUniform3f(pMotes.u("uColor"), MOTE_COLOR[0], MOTE_COLOR[1], MOTE_COLOR[2]);
            glBindVertexArray(noMeshVao);
            glEnable(POINT_SPRITE);   // (the game's context is the compatibility one: no gl_PointCoord without)
            glDrawArrays(GL_POINTS, 0, MOTES);
            glDisable(POINT_SPRITE);
            glDisable(GL_BLEND);
            glDisable(GL_DEPTH_TEST);
            mark("motes");
        }

        // what drifts in the room: light the air scatters, behind what stands before it
        if (life.shown() > 0) {
            glEnable(GL_DEPTH_TEST);
            glDepthFunc(GL_LEQUAL);
            glDepthMask(false);
            glEnable(GL_BLEND);
            glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ZERO, GL_ONE);
            glUseProgram(pPuff.id);
            uniform(pPuff.u("uViewProj"), viewProj);
            uniform(pPuff.u("uLightViewProj"), lightMatrix);
            bindTexture(9, shadowNow);
            glUniform1i(pPuff.u("uShadow"), 9);
            glUniform3f(pPuff.u("uRight"), view.m00(), view.m10(), view.m20());
            glUniform3f(pPuff.u("uUp"), view.m01(), view.m11(), view.m21());
            glUniform2f(pPuff.u("uScreen"), width, height);
            glUniform1f(pPuff.u("uPixel"), height / 1080f);
            glUniform1f(pPuff.u("uProjY"), proj.m11());
            glUniform3fv(pPuff.u("uLit"), PUFF_LIT);
            glUniform3fv(pPuff.u("uDark"), PUFF_DARK);
            glUniform4f(pPuff.u("uEmber"), emberX, emberY, emberZ, emberNow[3]);
            glBindVertexArray(puffVao);
            glBindBuffer(GL_ARRAY_BUFFER, puffVbo);
            // (a new store each frame: the card may still be reading the last one)
            glBufferData(GL_ARRAY_BUFFER, KnoxBarLife.MAX * KnoxBarLife.LOOK * 4L, GL_STREAM_DRAW);
            glBufferSubData(GL_ARRAY_BUFFER, 0, life.look);
            glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, life.shown());
            glDisable(GL_BLEND);
            glDisable(GL_DEPTH_TEST);
            mark("puffs");
        }

        // the ember: a spark the bloom makes a glow of, behind what stands before it
        if (emberGlow >= 0) {
            glEnable(GL_DEPTH_TEST);
            glDepthFunc(GL_LEQUAL);
            glDepthMask(false);
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE);
            glUseProgram(pEmber.id);
            uniform(pEmber.u("uViewProj"), viewProj);
            glUniform3f(pEmber.u("uPos"), emberX, emberY, emberZ);
            glUniform3f(pEmber.u("uEye"), eye.x, eye.y, eye.z);
            glUniform1f(pEmber.u("uPixel"), height / 1080f);
            glUniform1f(pEmber.u("uGlow"), emberGlow);
            glUniform1f(pEmber.u("uShown"), emberShown);
            glUniform1f(pEmber.u("uTime"), time);
            glBindVertexArray(noMeshVao);
            glEnable(POINT_SPRITE);
            glDrawArrays(GL_POINTS, 0, 1);
            glDisable(POINT_SPRITE);
            glDisable(GL_BLEND);
            glDisable(GL_DEPTH_TEST);
            mark("ember");
        }

        if (garlandNow > 0f) {
            glEnable(GL_DEPTH_TEST);
            glDepthFunc(GL_LEQUAL);
            glDepthMask(false);
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE);
            glUseProgram(pBulb.id);
            uniform(pBulb.u("uViewProj"), viewProj);
            glUniform3fv(pBulb.u("uBulb"), bulbsNow);
            glUniform3fv(pBulb.u("uBulbCol"), BULB_COLS);
            glUniform1f(pBulb.u("uPixel"), height / 1080f);
            glUniform1f(pBulb.u("uShown"), garlandNow);
            glBindVertexArray(noMeshVao);
            glEnable(POINT_SPRITE);
            glDrawArrays(GL_POINTS, 0, bulbCount);
            glDisable(POINT_SPRITE);
            glDisable(GL_BLEND);
            glDisable(GL_DEPTH_TEST);
            mark("bulbs");
        }

        int shown = depthOfField(dt);
        watchFbo = shown == dofTex ? dofFbo : pictureFbo;

        // the glow
        glUseProgram(pBloomDown.id);
        glUniform1i(pBloomDown.u("uPicture"), 8);
        for (int i = 0; i < BLOOM_STEPS; i++) {
            glBindFramebuffer(GL_FRAMEBUFFER, bloomFbo[i]);
            glViewport(0, 0, bloomW[i], bloomH[i]);
            bindTexture(8, i == 0 ? shown : bloomTex[i - 1]);
            glUniform2f(pBloomDown.u("uTexel"), 1f / (i == 0 ? width : bloomW[i - 1]), 1f / (i == 0 ? height : bloomH[i - 1]));
            glUniform1f(pBloomDown.u("uThreshold"), i == 0 ? 0.86f : 0f);
            glDrawArrays(GL_TRIANGLES, 0, 3);
        }
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE);
        glUseProgram(pBloomUp.id);
        glUniform1i(pBloomUp.u("uPicture"), 8);
        glUniform1f(pBloomUp.u("uStrength"), 0.8f);
        for (int i = BLOOM_STEPS - 1; i > 0; i--) {
            glBindFramebuffer(GL_FRAMEBUFFER, bloomFbo[i - 1]);
            glViewport(0, 0, bloomW[i - 1], bloomH[i - 1]);
            bindTexture(8, bloomTex[i]);
            glUniform2f(pBloomUp.u("uTexel"), 1f / bloomW[i], 1f / bloomH[i]);
            glDrawArrays(GL_TRIANGLES, 0, 3);
        }
        glDisable(GL_BLEND);
        mark("bloom");

        // onto the screen
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, savedDraw);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, savedDraw);
        glViewport(savedViewport[0], savedViewport[1], savedViewport[2], savedViewport[3]);
        glUseProgram(pFinal.id);
        bindTexture(8, shown);
        bindTexture(9, bloomTex[0]);
        glUniform1i(pFinal.u("uPicture"), 8);
        glUniform1i(pFinal.u("uBloom"), 9);
        glUniform1f(pFinal.u("uBloomPower"), 0.42f * 0.5f);
        glUniform2f(pFinal.u("uSize"), width, height);
        glUniform1f(pFinal.u("uTime"), time);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        mark("final");
    }

    /**
     * The depth of field (the author, 2026-11-03): the eye focused at the point (u, v) of the
     * picture (0..1, from its bottom left) - a hero under the mouse, the narrator's arm before his
     * eyes; `power` 0..1, 0 all sharp (and nothing of it drawn); `band` how far off the focus
     * (|1 - focus / distance|) stays sharp; `depth` how far ahead the thing is when it is known (scene
     * units along the view; 0: the depth at the point - the author, 2026-11-03: the one asleep at the
     * counter, the point over his back fell on the far wall). Main thread, at the frame's end; the
     * frame eases the focus itself.
     */
    public void focus(float u, float v, float power, float band, float depth) {
        focusU = u;
        focusV = v;
        focusPower = power;
        focusTol = band;
        focusDepth = depth;
    }

    /** The picture made soft off the focus, or the picture as it is: the one the glow and the screen take. */
    private int depthOfField(float dt) {
        float power = focusPower;
        if (power < 0.002f) {
            focusFresh = true;
            return pictureTex;
        }
        // (it starts with the first hover over a hero, a glass, a sheet, the radio, the switch or a bag, or
        // with the narrator's look - mostly after the first frames' watch: its own two. What the game or
        // our unwatched passes left on the card meanwhile isn't its to answer for: the released game never
        // asks the card itself, one wrong call anywhere waits for whoever asks first - QA, 2026-11-04)
        if (!dofWatched) {
            dofWatched = true;
            if (watchFrames == 0) forgetCardErrors();
            watchFrames = Math.max(watchFrames, 2);
        }
        glBindVertexArray(noMeshVao);
        // where the eye is focused: the depth there, eased from the last (an eye takes ~0.3 s)
        int next = 1 - focusNow;
        glBindFramebuffer(GL_FRAMEBUFFER, focusFbo[next]);
        glViewport(0, 0, 1, 1);
        glUseProgram(pFocus.id);
        bindTexture(8, depthTex);
        bindTexture(9, focusTex[focusNow]);
        glUniform1i(pFocus.u("uDepth"), 8);
        glUniform1i(pFocus.u("uLast"), 9);
        glUniform2f(pFocus.u("uAt"), focusU, focusV);
        glUniform2f(pFocus.u("uSpread"), 0.006f * height / Math.max(1, width), 0.006f);
        glUniform1f(pFocus.u("uWant"), focusDepth);
        glUniform1f(pFocus.u("uBlend"), focusFresh || dt <= 0f ? 1f : 1f - (float) Math.exp(-dt * 7f));
        glUniform1f(pFocus.u("uNear"), NEAR);
        glUniform1f(pFocus.u("uFar"), FAR);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        focusNow = next;
        focusFresh = false;

        glBindFramebuffer(GL_FRAMEBUFFER, dofFbo);
        glViewport(0, 0, width, height);
        glUseProgram(pDof.id);
        bindTexture(8, pictureTex);
        bindTexture(9, depthTex);
        bindTexture(10, focusTex[focusNow]);
        glUniform1i(pDof.u("uPicture"), 8);
        glUniform1i(pDof.u("uDepth"), 9);
        glUniform1i(pDof.u("uFocus"), 10);
        glUniform2f(pDof.u("uTexel"), 1f / width, 1f / height);
        glUniform1f(pDof.u("uNear"), NEAR);
        glUniform1f(pDof.u("uFar"), FAR);
        glUniform1f(pDof.u("uPower"), Math.min(1f, power));
        // (pixels at 1080 lines, as the rest of the frame's)
        glUniform1f(pDof.u("uAperture"), DOF_APERTURE * height / 1080f);
        glUniform1f(pDof.u("uMaxBlur"), DOF_MAX * height / 1080f);
        glUniform1f(pDof.u("uTol"), focusTol);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        mark("dof");
        return dofTex;
    }

    // how soft: pixels (at 1080 lines) at |1 - focus / distance| of 1 past the sharp band, and at most
    // (half the first's: the author, 2026-11-03 - too strong)
    private static final float DOF_APERTURE = 6.5f, DOF_MAX = 4.5f;

    /** The radio's needle goes to `where` on its dial, 0..1 (a new track: the author, 2026-11-01). */
    public void needleTo(float where) {
        needleTarget = where;
    }

    public float needleWhere() {
        return needleTarget;
    }

    private void moveThings(float time, float gust) {
        // (a hand on the dial: quick, then settling. Animations off, the time stands: at once)
        float needleDt = time - needleTime;
        needleTime = time;
        if (needleDt <= 0f) needleNow = needleTarget;
        else needleNow += (needleTarget - needleNow) * (1f - (float) Math.exp(-Math.min(0.1f, needleDt) * 3.5f));
        moveGarland(time, needleDt, gust);
        if (switchKick > 0f) {
            switchKickAt = time;
            switchKick = 0f;
        }
        for (int i = 0; i < moving.size(); i++) {
            Part p = moving.get(i);
            p.now.set(p.base);
            if (p.moves == PENCIL) {
                if (!pencilGone) movePencil(p, time, gust);
            } else if (p.moves == BOTTLE) {
                if (!bottleGone) moveBottle(p, time);
            } else if (p.moves == SWITCH) {
                // (on its lead, in the draught; a click sets it going. Its lead on the garland's torn end)
                p.now.set(tail).mul(p.base);
                float swing = (0.4f + 1.6f * gust) * (float) Math.sin(time * 1.9f + p.seed);
                float since = time - switchKickAt;
                if (switchKickAt >= 0f && since >= 0f && since < 3f) swing += 7f * (float) (Math.exp(-since * 1.6f) * Math.sin(since * 6.5f));
                p.now.rotateX((float) Math.toRadians(swing));
                p.now.rotateZ((float) Math.toRadians(0.6f * swing));
            } else if (p.moves == LAMP) {
                float swing = (0.6f + 2.6f * gust) * (float) Math.sin(time * 1.15f + p.seed);
                p.now.rotateZ((float) Math.toRadians(swing));
                p.now.rotateX((float) Math.toRadians(0.5f * swing * Math.sin(time * 0.7f + p.seed)));
            } else if (p.moves == PAPER) {
                // (a gust lifts it, the wind's clock ripples it: nothing jumps when the gust changes)
                float flap = 0.75f + 0.25f * (float) (Math.sin(time * 9f + p.seed) * Math.sin(time * 5.3f + p.seed * 2f));
                p.lift = p.length * (0.04f + 0.45f * gust * gust) * flap;
                p.phase = windIn * 6f + p.seed;
            } else if (p.moves == PINNED) {
                movePinned(p, time, gust);
            } else if (p.moves == NEEDLE) {
                p.now.translate(needleNow * NEEDLE_SPAN, 0f, 0f);
            } else if (p.moves == PAGE) {
                movePage(p, time, gust);
            } else if (p.moves == DOOR) {
                p.now.rotateY((float) Math.toRadians(life.doorAngle(time, gust) * (1 - doorOpen) - OPEN_WIDE * doorOpen));
            }
            p.now.normal(p.normalNow);
        }
    }

    // The sheets on the wall of the missing, each on its pin (the author, 2026-11-02): in the still air
    // their free edge trembles, a strong gust (from PINNED_GUST, all of it by PINNED_FULL) lifts it off
    // the wall and flaps it. Lifted as a loose sheet is (room.vert: uFlutter), the wall behind its face.
    private static final float PINNED_GUST = 0.5f, PINNED_FULL = 0.85f;

    private void movePinned(Part p, float time, float gust) {
        // (the seed from x and z: the sheets one over another would go together, so their heights too)
        float seed = p.seed + p.base.m31() * 5.3f;
        float tremble = (float) (Math.sin(time * 6.3f + seed) * Math.sin(time * 3.7f + seed * 1.3f));
        float k = Math.min(1f, Math.max(0f, (gust - PINNED_GUST) / (PINNED_FULL - PINNED_GUST)));
        k = k * k * (3f - 2f * k);
        float flap = 0.7f + 0.3f * (float) (Math.sin(time * 10f + seed) * Math.sin(time * 6.1f + seed * 2f));
        p.lift = p.length * (0.012f + 0.008f * tremble + 0.45f * k * flap);
        p.phase = windIn * 6f + seed;
    }

    // A strong gust turns the journal's pages over (the author, 2026-11-02): the gust from which it can
    // (about four a minute are past it, for some seconds each), how long a page takes (s). The stronger,
    // the sooner the next. Harness: -Dbar.page=0..1 holds one on its way.
    private static final float PAGE_GUST = 0.6f, PAGE_TIME = 0.8f;
    public static float pageHeld = -1f;
    private float pageNext;

    private void movePage(Part p, float time, float gust) {
        if (pageHeld >= 0f && p == firstPage()) {
            p.pageFrom = time - pageHeld * PAGE_TIME;
        } else if (p.pageFrom < 0f && gust >= PAGE_GUST && time >= pageNext) {
            p.pageFrom = time;
            pagesTurned++;
            pageNext = time + 0.25f + (float) Math.random() * (1.6f - 1.2f * gust);
        }
        if (p.pageFrom < 0f) return;
        float k = (time - p.pageFrom) / PAGE_TIME;
        if (k < 0f || k >= 1f) {
            p.pageFrom = -1f;
            return;
        }
        // (towards the right as the camera sees it: the author, 2026-11-02, back from jar 109's other way)
        p.pageAngle = (float) Math.PI * k * k * (3f - 2f * k);
        p.pageLag = 0.9f * (float) Math.sin(Math.PI * k);
    }

    private Part firstPage() {
        for (int i = 0; i < moving.size(); i++) {
            if (moving.get(i).moves == PAGE) return moving.get(i);
        }
        return null;
    }

    // The garland on the back wall, its switch on the torn end (the author, 2026-11-02): one bulb of about
    // two gives its colour to the room (MenuGen's bar_garland), an old set's warm colours whatever the glass;
    // two broad lamps are what the wall and the ceiling give back, a warmth over the room. No shadows of
    // its own, as the room's other lamps. {x, y, z in metres, the colour, reach, strength}.
    // Lit: it stutters first, an old set catching. The halos: every live bulb (bulb.vert).
    private static final float GARLAND_EMIT = 7f;
    private static final float[][] GARLAND_LAMPS = new float[13][];
    private static final FloatBuffer BULB_COLS = BufferUtils.createFloatBuffer(30 * 3);
    // the live bulbs' halos where they hang still, metres (sway: where the draught has them)
    private static final float[] BULB_REST = new float[30 * 3];
    private static int bulbCount;
    private static float bulbX(int n) {
        return n >= 24 ? 2.2f + (n - 24) * 0.04f : -5.8f + (n / 6) * 2f + (n % 6) / 6f * 2f;
    }
    private static float bulbY(int n) {
        return n >= 24 ? 2.95f - (n - 24) * 0.22f : 2.95f - 0.28f * (float) Math.sin((n % 6) / 6f * Math.PI);
    }
    static {
        float[][] colours = {{1f, 0.14f, 0.04f}, {0.3f, 0.72f, 0.1f}, {1f, 0.52f, 0.1f}, {0.3f, 0.3f, 0.42f}};
        float[][] glass = {{1f, 0.12f, 0.05f}, {0.15f, 0.8f, 0.2f}, {1f, 0.6f, 0.12f}, {0.2f, 0.35f, 1f}};
        int[] lit = {0, 2, 5, 7, 10, 12, 15, 17, 20, 22, 24};
        for (int i = 0; i < lit.length; i++) {
            int n = lit[i];
            float[] c = colours[n % 4];
            GARLAND_LAMPS[i] = new float[] {bulbX(n), bulbY(n) - 0.04f, -7.8f, c[0], c[1], c[2], 4f, 2.2f};
        }
        GARLAND_LAMPS[11] = new float[] {-3.2f, 1.9f, -5.8f, 1f, 0.58f, 0.26f, 6f, 0.3f};
        GARLAND_LAMPS[12] = new float[] {0.4f, 1.9f, -5.8f, 1f, 0.58f, 0.26f, 6.5f, 0.34f};
        for (int n = 0; n < 30; n++) {
            if (n % 5 == 3) continue;   // (every fifth is dead: MenuGen)
            float[] c = glass[n % 4];
            BULB_REST[bulbCount * 3] = bulbX(n);
            BULB_REST[bulbCount * 3 + 1] = bulbY(n) - 0.035f;
            BULB_REST[bulbCount * 3 + 2] = -7.9f;
            BULB_COLS.put(c[0]).put(c[1]).put(c[2]);
            bulbCount++;
        }
        BULB_COLS.flip();
    }

    // The pencil by the journal (the author, 2026-11-02): one strong gust, some time in, rolls it off
    // the counter's edge towards the camera, and it falls. Back with the scene built anew. In metres.
    private static final float PENCIL_GUST = 0.8f, PENCIL_EDGE = 0.26f, PENCIL_ROLL = 0.9f, PENCIL_RADIUS = 0.0055f;
    public static float pencilHeld = -1f;
    private float pencilFrom = -1f, pencilAfter = -1f;
    private boolean pencilGone;

    private void movePencil(Part p, float time, float gust) {
        if (pencilHeld >= 0f) {
            pencilFrom = time - pencilHeld;
        } else if (pencilFrom < 0f) {
            if (pencilAfter < 0f || time < pencilAfter - 200f) pencilAfter = time + 25f + (float) Math.random() * 45f;
            if (time < pencilAfter || gust < PENCIL_GUST) return;
            pencilFrom = time;
            pencilFalls++;
        }
        float t = time - pencilFrom;
        float toEdge = (float) Math.sqrt(2f * PENCIL_EDGE / PENCIL_ROLL);
        float fall = Math.max(0f, t - toEdge);
        float z = fall <= 0f ? 0.5f * PENCIL_ROLL * t * t : PENCIL_EDGE + PENCIL_ROLL * toEdge * fall;
        float y = -4.9f * fall * fall;
        if (y < -1.3f) {
            pencilGone = true;
            return;
        }
        p.now.translateLocal(0f, y * U, z * U);
        p.now.rotateZ(fall * 7f);
        p.now.rotateX(z / PENCIL_RADIUS);
    }

    // The whiskey bottle the one asleep at the counter swats off it (the author, 2026-11-02): it tips
    // over away from his hand (towards +x, his left) in BOTTLE_TIP s - knocked: already going at the
    // start, faster as it goes (it set off slowly as if on its own, the swat redone the same day) -, rolls towards the camera on its
    // side and over the counter's edge BOTTLE_EDGE m on, falls the counter's height and breaks: gone
    // till the room is built anew. In metres. Harness: -Dbar.bottle=seconds holds it on its way.
    private static final float BOTTLE_R = 0.0432f, BOTTLE_TIP = 0.3f, BOTTLE_ROLL = 0.55f, BOTTLE_EDGE = 0.335f, COUNTER_TOP = 1.1f;
    public static float bottleHeld = -1f;
    private float bottleFrom = -1f;
    private volatile boolean bottleAsked;
    private boolean bottleGone;
    private volatile int bottleBreaks;

    /** The hand goes through the bottle (main thread): over it goes, on the next frame. */
    public void bottleKnock() {
        bottleAsked = true;
    }

    public int bottleBreaks() {
        return bottleBreaks;
    }

    private void moveBottle(Part p, float time) {
        if (bottleHeld >= 0f) {
            bottleFrom = time - bottleHeld;
        } else if (bottleFrom < 0f) {
            if (!bottleAsked) return;
            bottleAsked = false;
            bottleFrom = time;
        }
        float t = time - bottleFrom, r = BOTTLE_R * U;
        if (t < BOTTLE_TIP) {
            // (over its foot's edge on the far side from the hand)
            float k = t / BOTTLE_TIP;
            p.now.translate(r, 0f, 0f).rotateZ((float) Math.toRadians(-90f * (0.4f * k + 0.6f * k * k))).translate(-r, 0f, 0f);
            return;
        }
        float s = t - BOTTLE_TIP, toEdge = BOTTLE_EDGE / BOTTLE_ROLL;
        float fall = Math.max(0f, s - toEdge);
        float z = BOTTLE_ROLL * s;
        float y = -4.9f * fall * fall;
        if (y < -(COUNTER_TOP - BOTTLE_R)) {
            bottleGone = true;
            bottleBreaks++;
            return;
        }
        // (lying along x at its radius' height: rolling on it towards the camera, tumbling as it falls)
        float spin = z / BOTTLE_R + fall * 5f;
        p.now.translate(0f, y * U, z * U)
            .translate(0f, r, 0f).rotateX(spin).translate(0f, -r, 0f)
            .translate(r, 0f, 0f).rotateZ((float) Math.toRadians(-90f)).translate(-r, 0f, 0f);
    }

    // (how many pages have begun to turn, pencils to roll: for the sound, on the main thread)
    private volatile int pagesTurned, pencilFalls;

    public int pagesTurned() {
        return pagesTurned;
    }

    public int pencilFalls() {
        return pencilFalls;
    }

    private volatile boolean switchLit;

    /** The mouse on the garland's switch: its case stands out of the dark. */
    public void switchLit(boolean lit) {
        switchLit = lit;
    }

    private volatile boolean garlandOn;
    private float garlandK, garlandNow, garlandSince;
    private volatile float switchKick;
    private float switchKickAt = -1f;

    /** The garland's switch: on or off; `at once`, as the scene is built, no click in it. */
    public void garland(boolean on, boolean atOnce) {
        garlandOn = on;
        if (atOnce) {
            garlandK = on ? 1f : 0f;
            garlandNow = garlandK;
            garlandSince = -10f;
        } else {
            switchKick = 1f;
        }
    }

    private void moveGarland(float time, float dt, float gust) {
        if (dt <= 0f) {
            garlandK = garlandOn ? 1f : 0f;
        } else {
            float to = garlandOn ? 1f : 0f;
            if (garlandK != to) {
                if (garlandK == 0f) garlandSince = time;
                garlandK = to > garlandK ? Math.min(to, garlandK + dt / 0.14f) : Math.max(to, garlandK - dt / 0.1f);
            }
        }
        float age = time - garlandSince;
        float stutter = garlandOn && age >= 0f && age < 0.3f && Math.sin(age * 70f) < 0f ? 0.4f : 1f;
        // (a draught on the old wire: hardly more than a breath)
        garlandNow = garlandK * stutter * (1f - 0.05f * gust * (0.5f + 0.5f * (float) Math.sin(time * 23f)));

        // (the swags out from the wall, never into it: a breath in the still air, a gust pushes them out
        // and they swing; each its own beat. Seen from the front that is hardly anything, so their middles
        // go along the wall too. Along the wall the end swings little - the switch on it keeps in the
        // mouse's place for it, B:switchRect)
        for (int k = 0; k < 4; k++) {
            float w = time * (1.25f + 0.17f * k) + k * 2.1f;
            float swing = 0.8f * (float) Math.sin(w) + 0.2f * (float) Math.sin(w * 2.7f + 1.3f);
            swag[k] = (float) Math.toRadians((2f + 10f * gust) + (2f + 6f * gust) * swing);
            swagSide[k] = (0.015f + 0.06f * gust) * (float) Math.sin(time * (0.95f + 0.13f * k) + k * 1.7f + 0.6f);
        }
        tailOut = (float) Math.toRadians((0.8f + 6f * gust) + (1.2f + 4f * gust) * (float) Math.sin(time * 1.4f + 1.7f));
        tailSide = (float) Math.toRadians((0.6f + 2.4f * gust) * (float) Math.sin(time * 1.05f + 0.4f));
        tail.identity().translate(TAIL_X * U, HOOK_Y * U, GARLAND_Z * U).rotateZ(tailSide).rotateX(-tailOut)
            .translate(-TAIL_X * U, -HOOK_Y * U, -GARLAND_Z * U);
        if (garlandNow > 0f) garlandAt();
    }

    /** Its lights and halos where the draught has them (at rest before the first frame). */
    private void garlandAt() {
        for (int i = 0; i < 11; i++) {
            float[] g = GARLAND_LAMPS[i];
            sway(g[0], g[1], g[2], lampsAt, i * 3);
        }
        for (int i = 11; i < GARLAND_LAMPS.length; i++) {
            float[] g = GARLAND_LAMPS[i];
            lampsAt[i * 3] = g[0] * U;
            lampsAt[i * 3 + 1] = g[1] * U;
            lampsAt[i * 3 + 2] = g[2] * U;
        }
        bulbsNow.clear();
        for (int i = 0; i < bulbCount; i++) {
            sway(BULB_REST[i * 3], BULB_REST[i * 3 + 1], BULB_REST[i * 3 + 2], swayed, 0);
            bulbsNow.put(swayed[0]).put(swayed[1]).put(swayed[2]);
        }
        bulbsNow.flip();
    }

    // The garland in the draught (the author, 2026-11-02: «покачивание гирлянд на ветру»): room.vert's sway,
    // for what is drawn of it apart - its halos and its light. Its hooks' line, the prop's z (kb_garland), metres.
    private static final float HOOK_Y = 2.95f, TAIL_X = 2.2f, GARLAND_Z = -7.92f;
    private final float[] swag = new float[4], swagSide = new float[4];
    private float tailOut, tailSide;
    private final Matrix4f tail = new Matrix4f();
    private final float[] lampsAt = new float[13 * 3];
    private final float[] swayed = new float[3];
    private final FloatBuffer bulbsNow = BufferUtils.createFloatBuffer(30 * 3);
    {
        garlandAt();
    }

    /** A point of the garland where it hangs still (metres, the room's z) where the draught has it now, scene units into out at o. */
    private void sway(float x, float y, float z, float[] out, int o) {
        float a, b = 0f;
        if (x > TAIL_X || (x > 2.165f && y < 2.92f)) {
            float r = (float) Math.hypot(x - TAIL_X, y - HOOK_Y);
            float k = Math.min(1f, r / 0.15f);
            k = k * k * (3f - 2f * k);
            a = tailOut * k;
            b = tailSide * k;
        } else {
            float t = Math.max(0f, Math.min(3.999f, (x + 5.8f) / 2f));
            int i = (int) t;
            float m = (float) Math.sin((t - i) * Math.PI);
            a = swag[i] * m;
            x += swagSide[i] * m;
        }
        float c = (float) Math.cos(a), s = (float) Math.sin(a);
        float dy = y - HOOK_Y, dz = z - GARLAND_Z;
        float nx = x, ny = HOOK_Y + dy * c + dz * s, nz = -dy * s + dz * c;
        if (b != 0f) {
            c = (float) Math.cos(b);
            s = (float) Math.sin(b);
            float ex = x - TAIL_X, ey = ny - HOOK_Y;
            nx = TAIL_X + ex * c - ey * s;
            ny = HOOK_Y + ex * s + ey * c;
        }
        out[o] = nx * U;
        out[o + 1] = ny * U;
        out[o + 2] = (nz + GARLAND_Z) * U;
    }

    /** room.vert / shadow.vert: the garland's sway for this part, or none. */
    private void swayOn(Program p, Part part) {
        if (part.moves != GARLAND && part.moves != SWAG) return;
        glUniform4f(p.u("uSwag"), swag[0], swag[1], swag[2], swag[3]);
        glUniform4f(p.u("uSwagSide"), swagSide[0], swagSide[1], swagSide[2], swagSide[3]);
        glUniform3f(p.u("uTail"), tailOut, tailSide, 1f);
    }

    private void swayOff(Program p, Part part) {
        if (part.moves == GARLAND || part.moves == SWAG) glUniform3f(p.u("uTail"), 0f, 0f, 0f);
    }

    /**
     * What the garland gives a hero at x y z (units): the sum of its lamps as one, into `out`:
     * direction towards it (not normal), colour. Zero: nothing reaches there.
     */
    public void garlandLight(float x, float y, float z, float[] out) {
        for (int i = 0; i < 6; i++) out[i] = 0f;
        if (garlandNow <= 0f) return;
        for (int i = 0; i < GARLAND_LAMPS.length; i++) {
            float[] g = GARLAND_LAMPS[i];
            float dx = lampsAt[i * 3] - x, dy = lampsAt[i * 3 + 1] - y, dz = lampsAt[i * 3 + 2] - z;
            float d = (float) Math.sqrt(dx * dx + dy * dy + dz * dz);
            float fall = 1f - d / (g[6] * U);
            if (fall <= 0f) continue;
            float w = fall * fall * g[7] * garlandNow;
            float at = w / Math.max(0.001f, d);
            out[0] += dx * at;
            out[1] += dy * at;
            out[2] += dz * at;
            out[3] += g[3] * w;
            out[4] += g[4] * w;
            out[5] += g[5] * w;
        }
    }

    // (it stands at 71.6 degrees in: 90 leaves 1 m to go out by - ROADMAP, the bar's animation)
    private static final float OPEN_WIDE = 90f - 71.6f;

    private void updateShadow() {
        glDisable(GL_BLEND);
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LESS);
        glDepthMask(true);
        glColorMask(false, false, false, false);
        glViewport(0, 0, shadowW, shadowH);
        glUseProgram(pShadow.id);
        uniform(pShadow.u("uLightViewProj"), lightMatrix);
        glUniform1i(pShadow.u("uTexture"), 8);
        if (!shadowBuilt) {
            glBindFramebuffer(GL_FRAMEBUFFER, shadowStaticFbo);
            float clearDepth = glGetFloat(GL_DEPTH_CLEAR_VALUE);
            glClearDepth(1);
            glClear(GL_DEPTH_BUFFER_BIT);
            glClearDepth(clearDepth);
            uniform(pShadow.u("uModel"), identity);
            for (int i = 0; i < still.size(); i++) {
                Part p = still.get(i);
                if (p.glass) continue;
                bindTexture(8, p.textureId);
                glBindVertexArray(p.vao);
                glDrawElements(GL_TRIANGLES, p.indexCount, GL_UNSIGNED_INT, 0);
            }
            shadowBuilt = true;
        }
        glBindFramebuffer(GL_READ_FRAMEBUFFER, shadowStaticFbo);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, shadowNowFbo);
        glBlitFramebuffer(0, 0, shadowW, shadowH, 0, 0, shadowW, shadowH, GL_DEPTH_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_FRAMEBUFFER, shadowNowFbo);
        for (int i = 0; i < moving.size(); i++) {
            Part p = moving.get(i);
            if (p.glass || (p.moves == PAGE && p.pageFrom < 0f) || (p.moves == PENCIL && pencilGone) || (p.moves == BOTTLE && bottleGone)) continue;
            uniform(pShadow.u("uModel"), p.now);
            bindTexture(8, p.textureId);
            glBindVertexArray(p.vao);
            if (p.moves == PAPER || p.moves == PINNED) glUniform3f(pShadow.u("uFlutter"), p.lift, p.phase, p.length);
            if (p.moves == PAGE) glUniform3f(pShadow.u("uPage"), p.pageAngle, p.pageLag, p.length);
            swayOn(pShadow, p);
            glDrawElements(GL_TRIANGLES, p.indexCount, GL_UNSIGNED_INT, 0);
            swayOff(pShadow, p);
            if (p.moves == PAPER || p.moves == PINNED) glUniform3f(pShadow.u("uFlutter"), 0f, 0f, 0f);
            if (p.moves == PAGE) glUniform3f(pShadow.u("uPage"), 0f, 0f, 0f);
        }
        bindTexture(8, white1);
        for (int h = 0; h < HEROES; h++) drawCapsules(pShadow, heroCaps, h * CAPSULES * CAPSULE, heroCount[h], null, false);
        glColorMask(true, true, true, true);
        glDisable(GL_DEPTH_TEST);
    }

    private void useRoom(Program p) {
        glUseProgram(p.id);
        uniform(p.u("uViewProj"), viewProj);
        glUniform1i(p.u("uTexture"), 12);
    }

    private void drawParts(Program p, boolean glass) {
        uniform(p.u("uModel"), identity);
        uniform3(p.u("uNormalMat"), identity3);
        for (int i = 0; i < still.size(); i++) {
            Part part = still.get(i);
            if (part.glass != glass) continue;
            bindTexture(12, part.textureId);
            glBindVertexArray(part.vao);
            glDrawElements(GL_TRIANGLES, part.indexCount, GL_UNSIGNED_INT, 0);
        }
        for (int i = 0; i < moving.size(); i++) {
            Part part = moving.get(i);
            if (part.glass != glass || (part.moves == PAGE && part.pageFrom < 0f) || (part.moves == PENCIL && pencilGone) || (part.moves == BOTTLE && bottleGone)) continue;
            uniform(p.u("uModel"), part.now);
            uniform3(p.u("uNormalMat"), part.normalNow);
            bindTexture(12, part.textureId);
            glBindVertexArray(part.vao);
            if (part.moves == PAPER || part.moves == PINNED) glUniform3f(p.u("uFlutter"), part.lift, part.phase, part.length);
            if (part.moves == PAGE) glUniform3f(p.u("uPage"), part.pageAngle, part.pageLag, part.length);
            if (part.moves == GARLAND) glUniform1f(p.u("uEmit"), GARLAND_EMIT * garlandNow);
            if (part.moves == SWITCH && switchLit) glUniform1f(p.u("uEmit"), 1.6f);
            swayOn(p, part);
            glDrawElements(GL_TRIANGLES, part.indexCount, GL_UNSIGNED_INT, 0);
            swayOff(p, part);
            if (part.moves == GARLAND || part.moves == SWITCH) glUniform1f(p.u("uEmit"), 0f);
            if (part.moves == PAPER || part.moves == PINNED) glUniform3f(p.u("uFlutter"), 0f, 0f, 0f);
            if (part.moves == PAGE) glUniform3f(p.u("uPage"), 0f, 0f, 0f);
        }
    }

    /**
     * Capsules from `caps` (from `at`, `count` of them), each a cylinder and its two round ends; through
     * `place` first if there is one. Lit (the room's program) needs the normals' matrix too.
     */
    private void drawCapsules(Program p, float[] caps, int at, int count, Matrix4f place, boolean lit) {
        int model = p.u("uModel"), normals = lit ? p.u("uNormalMat") : -1;
        for (int i = 0; i < count; i++) {
            int c = at + i * CAPSULE;
            capA.set(caps[c], caps[c + 1], caps[c + 2]);
            capB.set(caps[c + 3], caps[c + 4], caps[c + 5]);
            float r = caps[c + 6];
            if (place != null) {
                place.transformPosition(capA);
                place.transformPosition(capB);
            }
            capB.sub(capA, capD);
            float length = capD.length();
            if (length > 1e-4f) {
                capTurn.rotationTo(0, 1, 0, capD.x / length, capD.y / length, capD.z / length);
                capsule.translation(capA).rotate(capTurn).scale(r, length, r);
                drawUnit(cylinder, model, normals);
            }
            capsule.translation(capA).scale(r);
            drawUnit(sphere, model, normals);
            capsule.translation(capB).scale(r);
            drawUnit(sphere, model, normals);
        }
    }

    private void drawUnit(Part mesh, int model, int normals) {
        uniform(model, capsule);
        if (normals >= 0) {
            capsule.normal(capsuleNormal);
            uniform3(normals, capsuleNormal);
        }
        glBindVertexArray(mesh.vao);
        glDrawElements(GL_TRIANGLES, mesh.indexCount, GL_UNSIGNED_INT, 0);
    }

    /** The dead out in the snow: each its own way along, its clip's frame by the ground it covered. */
    private void drawWalkers(Program p, boolean seen) {
        if (!standInWalkers) return;
        int alpha = seen ? p.u("uAlpha") : -1;
        for (float[] w : WALKERS) {
            int clip = (int) w[4];
            float cycle = walkCycle[clip * 2], speed = walkCycle[clip * 2 + 1] * w[3];
            float span = WALK_TO - WALK_FROM;
            float along = ((w[1] - WALK_FROM) + w[2] * speed / U * lastTime) % span;
            if (along < 0) along += span;
            float x = WALK_FROM + along;
            ArrayList<float[]> frames = walkFrames[clip];
            float phase = (lastTime * w[3] / cycle + w[1] * 0.37f) % 1f;
            if (phase < 0) phase += 1f;   // (a start left of 0, early on the clock: QA, 2026-10-31)
            float[] caps = frames.get(Math.min(frames.size() - 1, (int) (phase * frames.size())));
            figure.translation(x * U, 0, w[0] * U).rotateY((float) Math.toRadians(w[2] > 0 ? 90 : -90));
            if (seen) {
                // (further out, fainter in the snow)
                float k = (float) Math.exp(-(WALL_Z / U - w[0] - 3f) / 7f);
                glUniform1f(alpha, Math.min(0.62f, 0.62f * k));
            }
            drawCapsules(p, caps, 0, caps.length / CAPSULE, figure, seen);
        }
    }

    private Part unitCylinder() {
        Part p = new Part();
        int n = 12;
        for (int i = 0; i <= n; i++) {
            double a = 2 * Math.PI * i / n;
            float x = (float) Math.cos(a), z = (float) Math.sin(a);
            vertex(p, x, 0, z, x, 0, z);
            vertex(p, x, 1, z, x, 0, z);
        }
        for (int i = 0; i < n; i++) {
            int a = i * 2;
            index(p, a, a + 1, a + 3);
            index(p, a, a + 3, a + 2);
        }
        return p;
    }

    private Part unitSphere() {
        Part p = new Part();
        int rings = 6, n = 12;
        for (int r = 0; r <= rings; r++) {
            double v = Math.PI * r / rings;
            for (int i = 0; i <= n; i++) {
                double a = 2 * Math.PI * i / n;
                float x = (float) (Math.sin(v) * Math.cos(a)), y = (float) Math.cos(v), z = (float) (Math.sin(v) * Math.sin(a));
                vertex(p, x, y, z, x, y, z);
            }
        }
        for (int r = 0; r < rings; r++) {
            for (int i = 0; i < n; i++) {
                int a = r * (n + 1) + i, b = a + n + 1;
                index(p, a, b, b + 1);
                index(p, a, b + 1, a + 1);
            }
        }
        return p;
    }

    private static void vertex(Part p, float x, float y, float z, float nx, float ny, float nz) {
        p.grow(STRIDE);
        float[] d = p.data;
        int at = p.size;
        d[at] = x;
        d[at + 1] = y;
        d[at + 2] = z;
        d[at + 3] = nx;
        d[at + 4] = ny;
        d[at + 5] = nz;
        d[at + 6] = 0.5f;
        d[at + 7] = 0.5f;
        d[at + 8] = 0.45f;   // (the stand-ins' grey: the harness only shows them)
        d[at + 9] = 0.45f;
        d[at + 10] = 0.45f;
        d[at + 11] = 0f;
        p.size += STRIDE;
    }

    private static void index(Part p, int a, int b, int c) {
        p.growIndex(3);
        p.indices[p.indexCount++] = a;
        p.indices[p.indexCount++] = b;
        p.indices[p.indexCount++] = c;
    }

    private void blur(int from, int toFbo, float stepX, float stepY) {
        glBindFramebuffer(GL_FRAMEBUFFER, toFbo);
        glUseProgram(pBlur.id);
        bindTexture(8, from);
        bindTexture(9, depthTex);
        glUniform1i(pBlur.u("uPicture"), 8);
        glUniform1i(pBlur.u("uDepth"), 9);
        glUniform2f(pBlur.u("uStep"), stepX, stepY);
        glUniform1f(pBlur.u("uNear"), NEAR);
        glUniform1f(pBlur.u("uFar"), FAR);
        glBindVertexArray(noMeshVao);
        glDrawArrays(GL_TRIANGLES, 0, 3);
    }

    private static void bindTexture(int unit, int id) {
        glActiveTexture(GL_TEXTURE0 + unit);
        glBindTexture(GL_TEXTURE_2D, id);
    }

    private static void bindMultisample(int unit, int id) {
        glActiveTexture(GL_TEXTURE0 + unit);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, id);
    }

    private static void unbindMultisample(int unit) {
        glActiveTexture(GL_TEXTURE0 + unit);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
    }

    private void uniform(int at, Matrix4f m) {
        mat4.clear();
        m.get(mat4);
        glUniformMatrix4fv(at, false, mat4);
    }

    private void uniform3(int at, Matrix3f m) {
        mat3.clear();
        m.get(mat3);
        glUniformMatrix3fv(at, false, mat3);
    }

    private void mark(String name) {
        if (watchFrames > 0) cardOk(name);
        if (!profile || queryCount >= queries.length) return;
        if (queries[queryCount] == 0) queries[queryCount] = glGenQueries();
        glQueryCounter(queries[queryCount], GL_TIMESTAMP);
        queryNames[queryCount++] = name;
    }

    /** What each pass took in the last frame, for tools\barframe (after glFinish). */
    public String profileReport() {
        StringBuilder s = new StringBuilder();
        long last = 0;
        for (int i = 0; i < queryCount; i++) {
            long t = glGetQueryObjecti64(queries[i], GL_QUERY_RESULT);
            if (i > 0) s.append(String.format(java.util.Locale.ROOT, "%s %.2f  ", queryNames[i], (t - last) / 1e6));
            last = t;
        }
        return s.toString();
    }

    // ------------------------------------------------------------- building

    private void buildGL() {
        if (!GL.getCapabilities().OpenGL33) throw new IllegalStateException("OpenGL 3.3 is not there");
        int active = glGetInteger(GL_ACTIVE_TEXTURE);
        int alignment = glGetInteger(GL_UNPACK_ALIGNMENT), rowLength = glGetInteger(GL_UNPACK_ROW_LENGTH);
        int vao = glGetInteger(GL_VERTEX_ARRAY_BINDING);
        int arrayBuffer = glGetInteger(GL_ARRAY_BUFFER_BINDING);
        try {
            pRoom = program("room.vert", "room.frag");
            pGlass = program("room.vert", "glass.frag");
            pShadow = program("shadow.vert", "shadow.frag");
            pSky = program("quad.vert", "sky.frag");
            pAo = program("quad.vert", "ao.frag");
            pBlur = program("quad.vert", "blur.frag");
            pAir = program("quad.vert", "air.frag");
            pTone = program("quad.vert", "tone.frag");
            pMotes = program("motes.vert", "motes.frag");
            pBloomDown = program("quad.vert", "bloom_down.frag");
            pBloomUp = program("quad.vert", "bloom_up.frag");
            pFinal = program("quad.vert", "final.frag");
            pWalker = program("room.vert", "walker.frag");
            pEmber = program("ember.vert", "ember.frag");
            pBulb = program("bulb.vert", "bulb.frag");
            pSnow = program("snow.vert", "snow.frag");
            pPuff = program("puff.vert", "puff.frag");
            pFocus = program("quad.vert", "focus.frag");
            pDof = program("quad.vert", "dof.frag");
            shaderText.clear();
            // The whole-screen passes and the motes make their points from gl_VertexID, yet the
            // game's context is the compatibility one: with no array enabled a draw may draw
            // nothing and say nothing, on AMD and Intel under Mesa (QA, 2026-10-31). The array is
            // there to be enabled, no shader reads it.
            noMeshVao = glGenVertexArrays();
            glBindVertexArray(noMeshVao);
            int points = glGenBuffers();
            allBuffers.add(points);
            glBindBuffer(GL_ARRAY_BUFFER, points);
            glBufferData(GL_ARRAY_BUFFER, MOTES * 4L, GL_STATIC_DRAW);
            glEnableVertexAttribArray(0);
            glVertexAttribPointer(0, 1, GL_FLOAT, false, 0, 0);
            buildPuffs();
            glActiveTexture(GL_TEXTURE0 + 13);
            for (Map.Entry<String, KnoxBarMesh.Picture> e : pictures.entrySet()) {
                textures.put(e.getKey(), upload(e.getValue()));
                e.getValue().free();
            }
            pictures.clear();
            white1 = solid(255);
            black1 = solid(0);
            glBindTexture(GL_TEXTURE_2D, 0);
            for (Part p : still) buildPart(p);
            for (Part p : moving) buildPart(p);
            cylinder = unitCylinder();
            sphere = unitSphere();
            buildPart(cylinder);
            buildPart(sphere);
            glReady = true;
        } finally {
            glActiveTexture(active);
            glPixelStorei(GL_UNPACK_ALIGNMENT, alignment);
            glPixelStorei(GL_UNPACK_ROW_LENGTH, rowLength);
            glBindVertexArray(vao);
            glBindBuffer(GL_ARRAY_BUFFER, arrayBuffer);
        }
    }

    /** A square's corners, and the store each particle's place and look go to, one per square. */
    private void buildPuffs() {
        puffVao = glGenVertexArrays();
        glBindVertexArray(puffVao);
        int corners = glGenBuffers();
        allBuffers.add(corners);
        glBindBuffer(GL_ARRAY_BUFFER, corners);
        glBufferData(GL_ARRAY_BUFFER, new float[] {-1, -1, 1, -1, -1, 1, 1, 1}, GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, 0);
        puffVbo = glGenBuffers();
        allBuffers.add(puffVbo);
        glBindBuffer(GL_ARRAY_BUFFER, puffVbo);
        glBufferData(GL_ARRAY_BUFFER, KnoxBarLife.MAX * KnoxBarLife.LOOK * 4L, GL_STREAM_DRAW);
        int stride = KnoxBarLife.LOOK * 4;
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 4, GL_FLOAT, false, stride, 0);
        glVertexAttribDivisor(1, 1);
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 4, GL_FLOAT, false, stride, 4 * 4);
        glVertexAttribDivisor(2, 1);
    }

    private void buildPart(Part p) {
        Integer texture = p.texture == null ? null : textures.get(p.texture);
        p.textureId = texture == null ? 0 : texture;   // (a capsule's mesh has no picture of its own)
        FloatBuffer vertices = BufferUtils.createFloatBuffer(p.size);
        vertices.put(p.data, 0, p.size).flip();
        IntBuffer indices = BufferUtils.createIntBuffer(p.indexCount);
        indices.put(p.indices, 0, p.indexCount).flip();
        p.vao = glGenVertexArrays();
        glBindVertexArray(p.vao);
        p.vbo = glGenBuffers();
        p.ibo = glGenBuffers();
        allBuffers.add(p.vbo);
        allBuffers.add(p.ibo);
        glBindBuffer(GL_ARRAY_BUFFER, p.vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, p.ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices, GL_STATIC_DRAW);
        int stride = STRIDE * 4;
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, false, stride, 0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, false, stride, 3 * 4);
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, false, stride, 6 * 4);
        glEnableVertexAttribArray(3);
        glVertexAttribPointer(3, 4, GL_FLOAT, false, stride, 8 * 4);
        glBindVertexArray(0);
        p.data = null;
        p.indices = null;
    }

    private static int upload(KnoxBarMesh.Picture pic) {
        int id = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, id);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
        glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_SRGB8_ALPHA8, pic.width, pic.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pic.pixels);
        glGenerateMipmap(GL_TEXTURE_2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        if (GL.getCapabilities().GL_EXT_texture_filter_anisotropic) glTexParameterf(GL_TEXTURE_2D, 0x84FE, 8f);
        return id;
    }

    private static int solid(int value) {
        int id = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, id);
        IntBuffer one = BufferUtils.createIntBuffer(1);
        one.put(value | value << 8 | value << 16 | 255 << 24).flip();
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, one);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        return id;
    }

    private Program program(String vert, String frag) {
        int v = shader(GL_VERTEX_SHADER, vert), f;
        try {
            f = shader(GL_FRAGMENT_SHADER, frag);
        } catch (RuntimeException e) {
            glDeleteShader(v);
            throw e;
        }
        int id = glCreateProgram();
        glAttachShader(id, v);
        glAttachShader(id, f);
        glLinkProgram(id);
        glDeleteShader(v);
        glDeleteShader(f);
        if (glGetProgrami(id, GL_LINK_STATUS) == GL_FALSE) {
            String log = glGetProgramInfoLog(id);
            glDeleteProgram(id);
            throw new IllegalStateException(vert + " + " + frag + ": " + log);
        }
        return new Program(id);
    }

    private int shader(int type, String name) {
        int id = glCreateShader(type);
        glShaderSource(id, shaderText.get(name));
        glCompileShader(id);
        if (glGetShaderi(id, GL_COMPILE_STATUS) == GL_FALSE) {
            String log = glGetShaderInfoLog(id);
            glDeleteShader(id);
            throw new IllegalStateException(name + ": " + log);
        }
        return id;
    }

    private void buildTargets(int w, int h, int quality) {
        int active = glGetInteger(GL_ACTIVE_TEXTURE);
        try {
            freeTargets();
            width = w;
            height = h;
            builtQuality = quality;
            // (a card may give fewer for a depth picture than for colours: only 1 is promised - overhaul, 2026-11-04)
            samples = quality == 1 ? Math.max(1, Math.min(4, Math.min(glGetInteger(GL_MAX_COLOR_TEXTURE_SAMPLES),
                glGetInteger(GL_MAX_DEPTH_TEXTURE_SAMPLES)))) : 1;
            glActiveTexture(GL_TEXTURE0 + 13);
            buildTargetsOn(w, h, quality);
            glBindTexture(GL_TEXTURE_2D, 0);
        } finally {
            glActiveTexture(active);
        }
    }

    private void buildTargetsOn(int w, int h, int quality) {
        hdrColor = glGenTextures();
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, hdrColor);
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, samples, GL_RGBA16F, w, h, true);
        hdrDepth = glGenTextures();
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, hdrDepth);
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, samples, GL_DEPTH_COMPONENT32F, w, h, true);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
        hdrFbo = glGenFramebuffers();
        glBindFramebuffer(GL_FRAMEBUFFER, hdrFbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D_MULTISAMPLE, hdrColor, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D_MULTISAMPLE, hdrDepth, 0);
        check("frame");

        depthTex = target(GL_DEPTH_COMPONENT32F, w, h, GL_DEPTH_COMPONENT, GL_FLOAT, GL_NEAREST);
        depthFbo = glGenFramebuffers();
        glBindFramebuffer(GL_FRAMEBUFFER, depthFbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depthTex, 0);
        glDrawBuffer(GL_NONE);
        glReadBuffer(GL_NONE);
        check("depth");

        pictureTex = target(GL_RGBA16F, w, h, GL_RGBA, GL_FLOAT, GL_LINEAR);
        pictureFbo = colorFbo(pictureTex);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depthTex, 0);
        check("picture");

        dofTex = target(GL_RGBA16F, w, h, GL_RGBA, GL_FLOAT, GL_LINEAR);
        dofFbo = colorFbo(dofTex);
        for (int i = 0; i < 2; i++) {
            focusTex[i] = target(GL_R32F, 1, 1, GL_RED, GL_FLOAT, GL_NEAREST);
            focusFbo[i] = colorFbo(focusTex[i]);
        }
        focusFresh = true;

        int hw = Math.max(1, w / 2), hh = Math.max(1, h / 2);
        if (quality == 1) {
            aoTex = target(GL_R8, hw, hh, GL_RED, GL_UNSIGNED_BYTE, GL_LINEAR);
            aoFbo = colorFbo(aoTex);
            aoTex2 = target(GL_R8, hw, hh, GL_RED, GL_UNSIGNED_BYTE, GL_LINEAR);
            aoFbo2 = colorFbo(aoTex2);
            airTex = target(GL_RGBA16F, hw, hh, GL_RGBA, GL_FLOAT, GL_LINEAR);
            airFbo = colorFbo(airTex);
            airTex2 = target(GL_RGBA16F, hw, hh, GL_RGBA, GL_FLOAT, GL_LINEAR);
            airFbo2 = colorFbo(airTex2);
        }
        int bw = w, bh = h;
        for (int i = 0; i < BLOOM_STEPS; i++) {
            bw = Math.max(1, bw / 2);
            bh = Math.max(1, bh / 2);
            bloomW[i] = bw;
            bloomH[i] = bh;
            bloomTex[i] = target(GL_R11F_G11F_B10F, bw, bh, GL_RGB, GL_FLOAT, GL_LINEAR);
            bloomFbo[i] = colorFbo(bloomTex[i]);
        }
        buildShadow(quality == 1 ? 4096 : 2048);
    }

    private void buildShadow(int w) {
        // the light's own axes
        Vector3f x = new Vector3f(1, 0, 0).sub(new Vector3f(DIR).mul(DIR.x)).normalize();
        Vector3f y = new Vector3f(x).cross(DIR).normalize();
        if (y.y < 0) y.negate();
        // the openings' corners seen from the light: nothing else can get light
        float[][] corners = {{-2.2f, 0f}, {-2.2f, 2.5f}, {4.4f, 0f}, {4.4f, 2.5f}};
        float minX = Float.MAX_VALUE, maxX = -Float.MAX_VALUE, minY = Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
        float minD = Float.MAX_VALUE, maxD = -Float.MAX_VALUE;
        Vector3f c = new Vector3f();
        for (float[] k : corners) {
            c.set(k[0] * U, k[1] * U, WALL_Z);
            minX = Math.min(minX, c.dot(x));
            maxX = Math.max(maxX, c.dot(x));
            minY = Math.min(minY, c.dot(y));
            maxY = Math.max(maxY, c.dot(y));
            minD = Math.min(minD, c.dot(DIR));
            maxD = Math.max(maxD, c.dot(DIR));
        }
        float margin = 0.35f;
        minX -= margin;
        maxX += margin;
        minY -= margin;
        maxY += margin;
        // what stands out in the snow casts too; down to the floor where the highest ray lands
        minD -= 1.6f;
        maxD += 2.8f * U / -DIR.y;
        float sizeX = maxX - minX, sizeY = maxY - minY;
        shadowDepthRange = maxD - minD;
        shadowUvX = 1f / sizeX;
        shadowUvY = 1f / sizeY;
        shadowW = w;
        shadowH = Math.max(256, Math.round(w * sizeY / sizeX));
        // world to the map's -1..1
        lightMatrix.set(
            x.x * 2 / sizeX, y.x * 2 / sizeY, DIR.x * 2 / shadowDepthRange, 0,
            x.y * 2 / sizeX, y.y * 2 / sizeY, DIR.y * 2 / shadowDepthRange, 0,
            x.z * 2 / sizeX, y.z * 2 / sizeY, DIR.z * 2 / shadowDepthRange, 0,
            -(minX + maxX) / sizeX, -(minY + maxY) / sizeY, -(minD + maxD) / shadowDepthRange, 1);
        shadowStatic = target(GL_DEPTH_COMPONENT32F, shadowW, shadowH, GL_DEPTH_COMPONENT, GL_FLOAT, GL_NEAREST);
        shadowNow = target(GL_DEPTH_COMPONENT32F, shadowW, shadowH, GL_DEPTH_COMPONENT, GL_FLOAT, GL_NEAREST);
        shadowStaticFbo = depthOnlyFbo(shadowStatic);
        shadowNowFbo = depthOnlyFbo(shadowNow);
        shadowBuilt = false;
    }

    private static int target(int format, int w, int h, int pixelFormat, int pixelType, int filter) {
        int id = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, id);
        glTexImage2D(GL_TEXTURE_2D, 0, format, w, h, 0, pixelFormat, pixelType, (java.nio.ByteBuffer) null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        return id;
    }

    private static int colorFbo(int texture) {
        int fbo = glGenFramebuffers();
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
        check("colour");
        return fbo;
    }

    private static int depthOnlyFbo(int texture) {
        int fbo = glGenFramebuffers();
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, texture, 0);
        glDrawBuffer(GL_NONE);
        glReadBuffer(GL_NONE);
        check("shadow");
        return fbo;
    }

    private static void check(String what) {
        int status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE) throw new IllegalStateException(what + " framebuffer: " + status);
    }

    private void freeTargets() {
        int[] fbos = {hdrFbo, depthFbo, pictureFbo, aoFbo, aoFbo2, airFbo, airFbo2, shadowStaticFbo, shadowNowFbo, dofFbo,
            focusFbo[0], focusFbo[1]};
        for (int f : fbos) if (f != 0) glDeleteFramebuffers(f);
        int[] texs = {hdrColor, hdrDepth, depthTex, pictureTex, aoTex, aoTex2, airTex, airTex2, shadowStatic, shadowNow, dofTex,
            focusTex[0], focusTex[1]};
        for (int t : texs) if (t != 0) glDeleteTextures(t);
        hdrFbo = depthFbo = pictureFbo = aoFbo = aoFbo2 = airFbo = airFbo2 = shadowStaticFbo = shadowNowFbo = dofFbo = 0;
        hdrColor = hdrDepth = depthTex = pictureTex = aoTex = aoTex2 = airTex = airTex2 = shadowStatic = shadowNow = dofTex = 0;
        focusFbo[0] = focusFbo[1] = focusTex[0] = focusTex[1] = 0;
        for (int i = 0; i < BLOOM_STEPS; i++) {
            if (bloomFbo[i] != 0) glDeleteFramebuffers(bloomFbo[i]);
            if (bloomTex[i] != 0) glDeleteTextures(bloomTex[i]);
            bloomFbo[i] = bloomTex[i] = 0;
        }
        width = height = 0;
    }

    /** Everything from the card (render thread). The menu is gone: 4K at 4 samples is a lot. */
    public void release() {
        if (released) return;
        released = true;
        if (began) {
            began = false;
            giveBackColorMask();
            giveBackFramebuffer();
        }
        for (KnoxBarMesh.Picture p : pictures.values()) p.free();
        pictures.clear();
        shaderText.clear();
        glReady = false;
        freeTargets();
        freePhotos();
        Program[] all = {pRoom, pGlass, pShadow, pSky, pAo, pBlur, pAir, pTone, pMotes, pBloomDown, pBloomUp, pFinal, pWalker, pEmber, pBulb, pSnow, pPuff, pFocus, pDof};
        for (Program p : all) if (p != null) glDeleteProgram(p.id);
        for (int id : textures.values()) glDeleteTextures(id);
        textures.clear();
        for (int id : allBuffers) glDeleteBuffers(id);
        allBuffers.clear();
        for (Part p : still) glDeleteVertexArrays(p.vao);
        for (Part p : moving) glDeleteVertexArrays(p.vao);
        for (Part p : new Part[] {cylinder, sphere}) if (p != null && p.vao != 0) glDeleteVertexArrays(p.vao);
        cylinder = sphere = null;
        if (noMeshVao != 0) glDeleteVertexArrays(noMeshVao);
        if (puffVao != 0) glDeleteVertexArrays(puffVao);
        puffVao = puffVbo = 0;
        if (white1 != 0) glDeleteTextures(white1);
        if (black1 != 0) glDeleteTextures(black1);
        noMeshVao = white1 = black1 = 0;
    }
}
