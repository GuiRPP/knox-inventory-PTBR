import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.imageio.ImageIO;

/**
 * The health tab's 3D skeleton (Knox Inventory): a skinned model in the game's own
 * body format, built on the body's own joints (the Bip01 bones of the bind pose)
 * and its flesh (the torso's sections), so every bone sits where it belongs: the
 * skull is the head's own shape drawn in, with sockets, a nose and teeth; a spine
 * of vertebrae near the back; twelve pairs of ribs sloping to a breastbone, their
 * cartilage; collarbones; a pelvis of two wings, the sacrum and the pubic and
 * ischial arches; the long bones joint to joint with their heads, necks,
 * condyles and knobs; the wrist, palm and fingers; the heel, arch and toes. Each
 * piece is moved by its part's Bip01 bone, so it follows the model's every pose.
 * Two of each part's set: whole and broken. Which ones show is the skeleton
 * texture's alpha, written by Java at run time (KnoxHealthPaint): each part and
 * state has its own block of the texture (bone colour, a dark row for sockets and
 * cracks, a cartilage row).
 *
 * The first version (2026-10-19) was built from each part's cloud of vertices: the
 * skull a ball bigger than the head, the neck up to the mouth, the forearm's bones
 * apart - the author: not human. This one is built on the joints.
 *
 * The output .x is the body's own file with only its mesh replaced: the same
 * frames, bind pose, bone offsets and animation sets.
 *
 *   java SkeletonGen.java <Body.x> <masksDir> <m|f> <out.x> <outTexture.png> [previewDir]
 */
public class SkeletonGen {
    static final int TS = 256;               // the skeleton texture
    static final int BLOCK = 32;             // a part's block in it, 8 x 8 blocks
    static final String[] PART = {"Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R", "UpperArm_L", "UpperArm_R",
        "Torso_Upper", "Torso_Lower", "Head", "Neck", "Groin", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R",
        "Foot_L", "Foot_R"};
    static final int HAND = 0, FOREARM = 2, UPPERARM = 4, CHEST = 6, BELLY = 7, HEAD = 8, NECK = 9, GROIN = 10,
        THIGH = 11, SHIN = 13, FOOT = 15;
    // piece colours: rows of a block (Java colours the same rows)
    static final int BONE = 0, DARK = 1, CART = 2;

    // ------------------------------------------------------------------ the body

    static String src;
    static float[] pos, nrm, uv;
    static int[] faces, nfaces;
    static int meshStart, meshEnd;
    static final LinkedHashMap<String, String> MATRIX = new LinkedHashMap<>();
    static int[] partOf;

    // ------------------------------------------------------------------ the skeleton being made

    static final class Piece {
        final ArrayList<float[]> v = new ArrayList<>(), n = new ArrayList<>(), t = new ArrayList<>();
        final ArrayList<int[]> tri = new ArrayList<>();
        String bone;
        int block, kind;
        int part;
        boolean broken, shared;
    }

    static final ArrayList<Piece> pieces = new ArrayList<>();
    static String curBone;
    static int curBlock;

    public static void main(String[] a) throws Exception {
        src = Files.readString(new File(a[0]).toPath(), StandardCharsets.ISO_8859_1);
        parse();
        String g = a[2];
        int nv = pos.length / 3;
        partOf = new int[nv];
        float[][] masks = new float[PART.length][];
        for (int p = 0; p < PART.length; p++) masks[p] = alpha(new File(a[1], "hl_" + g + "_" + PART[p] + ".png"));
        for (int i = 0; i < nv; i++) {
            int x = clampi((int) (uv[i * 2] * TS), 0, TS - 1), y = clampi((int) (uv[i * 2 + 1] * TS), 0, TS - 1);
            int best = -1;
            float bv = 0.2f;
            for (int p = 0; p < PART.length; p++) {
                float m = masks[p][y * TS + x];
                if (m > bv) { bv = m; best = p; }
            }
            partOf[i] = best;
        }
        for (int br = 0; br < 2; br++) {
            boolean broken = br == 1;
            spine(broken);
            chest(broken);
            pelvis(broken);
            skull(broken);
            for (int s = -1; s <= 1; s += 2) {
                arm(s, broken);
                leg(s, broken);
            }
        }
        share();
        writeX(new File(a[3]));
        writeTexture(new File(a[4]));
        if (a.length > 5) previews(new File(a[5]), g);
    }

    /**
     * What a part's whole and broken sets have alike is kept once, in the part's
     * shared block (shown either way): block part*3; what only the whole set has,
     * part*3+1; only the broken one, part*3+2. (Both sets whole were twice the
     * geometry.)
     */
    static void share() {
        Map<String, Piece> whole = new LinkedHashMap<>();
        for (Piece pc : pieces) if (!pc.broken) whole.put(sig(pc), pc);
        ArrayList<Piece> keep = new ArrayList<>();
        for (Piece pc : pieces) {
            if (pc.broken) {
                Piece twin = whole.get(sig(pc));
                if (twin != null && !twin.shared) { twin.shared = true; continue; }
            }
            keep.add(pc);
        }
        pieces.clear();
        pieces.addAll(keep);
        int shared = 0;
        for (Piece pc : pieces) {
            pc.block = pc.part * 3 + (pc.shared ? 0 : (pc.broken ? 2 : 1));
            if (pc.shared) shared++;
        }
        System.out.printf("pieces: %d (%d shared by the whole and the broken)%n", pieces.size(), shared);
        int[] per = new int[PART.length];
        for (Piece pc : pieces) per[pc.part] += pc.tri.size();
        StringBuilder sb = new StringBuilder("triangles by part:");
        for (int p = 0; p < PART.length; p++) sb.append(" ").append(PART[p]).append("=").append(per[p]);
        System.out.println(sb);
    }

    static String sig(Piece pc) {
        StringBuilder sb = new StringBuilder(pc.part + ":" + pc.bone + ":" + pc.kind + ":" + pc.v.size() + ":" + pc.tri.size());
        for (int i = 0; i < pc.v.size(); i += Math.max(1, pc.v.size() / 12)) {
            float[] p = pc.v.get(i);
            sb.append(String.format(Locale.ROOT, ":%.5f,%.5f,%.5f", p[0], p[1], p[2]));
        }
        return sb.toString();
    }
    static void use(int part, boolean broken, String bone) {
        curBlock = part * 2 + (broken ? 1 : 0);
        curBone = bone;
    }

    static int side(int part, int s) { return part + (s > 0 ? 0 : 1); }   // _L is +x

    static String sideName(int s) { return s > 0 ? "L" : "R"; }

    // ------------------------------------------------------------------ the flesh

    /** The torso's section at a height: {front z, back z, half width} of its vertices within |x| < xMax. */
    static float[] section(float y, float band, float xMax) {
        float zf = Float.MAX_VALUE, zb = -Float.MAX_VALUE, hw = 0;
        for (int i = 0; i < pos.length / 3; i++) {
            float x = pos[i * 3], yy = pos[i * 3 + 1], z = pos[i * 3 + 2];
            if (Math.abs(yy - y) > band || Math.abs(x) > xMax) continue;
            int p = partOf[i];
            if (p != CHEST && p != BELLY && p != GROIN && p != NECK && p != HEAD) continue;
            zf = Math.min(zf, z); zb = Math.max(zb, z); hw = Math.max(hw, Math.abs(x));
        }
        return new float[] {zf, zb, hw};
    }

    /** Where on the body's surface a spot of its skin's layout is (u, v), or null. */
    static float[] onSkin(float u, float v) {
        for (int f = 0; f < faces.length / 3; f++) {
            int a = faces[f * 3], b = faces[f * 3 + 1], c = faces[f * 3 + 2];
            float x0 = uv[a * 2], y0 = uv[a * 2 + 1], x1 = uv[b * 2], y1 = uv[b * 2 + 1], x2 = uv[c * 2], y2 = uv[c * 2 + 1];
            float den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2);
            if (Math.abs(den) < 1e-12) continue;
            float w0 = ((y1 - y2) * (u - x2) + (x2 - x1) * (v - y2)) / den;
            float w1 = ((y2 - y0) * (u - x2) + (x0 - x2) * (v - y2)) / den;
            float w2 = 1 - w0 - w1;
            if (w0 < 0 || w1 < 0 || w2 < 0) continue;
            float[] p = new float[3];
            for (int k = 0; k < 3; k++) p[k] = w0 * pos[a * 3 + k] + w1 * pos[b * 3 + k] + w2 * pos[c * 3 + k];
            // (the front of the face: the triangle that looks to the camera)
            float[] n = v3(nrm, nfaces[f * 3]);
            if (n[2] < 0) return p;
        }
        return null;
    }

    // ------------------------------------------------------------------ the spine

    static float[] spinePoint(float y) {
        // near the back: about two thirds of the body's depth from the front
        float[] s = section(y, 0.012f, y > 0.78f ? 0.035f : 0.08f);
        float z = s[0] + (s[1] - s[0]) * (y > 0.78f ? 0.58f : 0.62f);
        return v(0, y, z);
    }

    /** A vertebra at a height: its body, its side processes, its spine to the back. */
    static void vertebra(float y, float h, float rb, float tp, boolean shifted) {
        float[] c = spinePoint(y);
        if (shifted) c = add(c, v(rb * 0.7f, -h * 0.15f, 0));
        float[] lo = add(c, v(0, -h * 0.36f, 0)), hi = add(c, v(0, h * 0.36f, 0));
        lathe(lo, hi, t -> rb * (0.92f + 0.08f * (float) Math.cos((t - 0.5f) * Math.PI * 2)), 8, 3, X, 1.25f, 1f, BONE, null);
        // the transverse processes, a little back
        for (int s = -1; s <= 1; s += 2) {
            float[] a = add(c, v(s * rb * 0.6f, 0, rb * 0.6f)), b = add(c, v(s * (rb + tp), h * 0.05f, rb * 1.1f));
            lathe(a, b, t -> rb * 0.3f * (1 - 0.35f * t), 4, 2, Y, 1, 1, BONE, null);
        }
        // the spinous process, back and down
        lathe(add(c, v(0, 0, rb * 0.8f)), add(c, v(0, -h * 0.45f, rb * 1.6f)), t -> rb * 0.28f * (1 - 0.4f * t), 4, 2, Y, 1.4f, 0.7f, BONE, null);
    }

    static void spine(boolean broken) {
        float pelvisY = joint("Bip01_Pelvis")[1], neckY = joint("Bip01_Neck")[1], headY = joint("Bip01_Head")[1];
        float[] bounds = partBounds(CHEST);
        float chestLow = bounds[0];
        // lumbar: from just above the sacrum to the chest's lowest point
        float l0 = pelvisY + 0.03f, l1 = chestLow;
        use(BELLY, broken, "Bip01_Spine");
        for (int i = 0; i < 5; i++) {
            float y = l0 + (l1 - l0) * (i + 0.5f) / 5;
            vertebra(y, (l1 - l0) / 5, 0.0125f, 0.016f, broken && i == 2);
        }
        if (broken) crack(spinePoint(l0 + (l1 - l0) * 0.5f), 0.016f);
        // thoracic: the chest's height to the base of the neck
        float t0 = l1, t1 = neckY - 0.008f;
        use(CHEST, broken, "Bip01_Spine1");
        for (int i = 0; i < 12; i++) {
            float y = t0 + (t1 - t0) * (i + 0.5f) / 12;
            float k = i / 11f;
            vertebra(y, (t1 - t0) / 12, 0.0105f - 0.003f * k, 0.011f, false);
        }
        // cervical: the neck to the skull's base
        use(NECK, broken, "Bip01_Neck");
        float c0 = t1, c1 = headY + 0.012f;
        for (int i = 0; i < 4; i++) {
            float y = c0 + (c1 - c0) * (i + 0.5f) / 4;
            vertebra(y, (c1 - c0) / 4, 0.0068f, 0.006f, broken && i == 1);
        }
    }

    // ------------------------------------------------------------------ the chest

    static void chest(boolean broken) {
        float neckY = joint("Bip01_Neck")[1];
        float[] bounds = partBounds(CHEST);
        float t0 = bounds[0], t1 = neckY - 0.008f;
        float[] mid = section(0.70f, 0.02f, 0.095f);
        float zc = (mid[0] + mid[1]) / 2 + 0.004f, dz = (mid[1] - mid[0]) / 2 * 0.8f;
        float wc = mid[2] * 0.84f;
        use(CHEST, broken, "Bip01_Spine1");
        // the breastbone: from the notch between the collarbones down
        float sTop = t1 - 0.012f, sBot = t0 + (t1 - t0) * 0.32f;
        float zFront = section((sTop + sBot) / 2, 0.02f, 0.03f)[0] + 0.009f;
        lathe(v(0, sBot, zFront + 0.002f), v(0, sTop, zFront), t -> 0.0062f * (t > 0.78f ? 1.45f : (t < 0.1f ? 0.5f + 5 * t : 1f)), 8, 8, X, 1.7f, 0.45f, BONE, null);
        int ribs = 12;
        for (int i = 0; i < ribs; i++) {
            float yv = t1 - (t1 - t0) * (i + 0.5f) / 12;
            float grow = (float) Math.sin(Math.min(1, (i + 0.8f) / 6.5f) * Math.PI / 2);
            float wx = wc * (0.45f + 0.55f * grow) * (i > 8 ? 0.97f : 1f);
            float dzi = dz * (0.6f + 0.4f * grow);
            float drop = 0.012f + 0.03f * Math.min(1, i / 7f);
            boolean floating = i >= 10;
            float phiEnd = i < 7 ? (float) Math.PI - 0.5f : (floating ? 1.75f : 2.45f - 0.08f * (i - 7));
            for (int s = -1; s <= 1; s += 2) {
                ArrayList<float[]> path = new ArrayList<>();
                int steps = 8;
                for (int k = 0; k <= steps; k++) {
                    float phi = 0.3f + (phiEnd - 0.3f) * k / steps;
                    float ease = (1 - (float) Math.cos(phi)) / 2;
                    path.add(v(s * wx * (float) Math.sin(phi), yv - drop * ease, zc + dzi * (float) Math.cos(phi)));
                }
                boolean snap = broken && i == 5 && s > 0;
                if (snap) {
                    tube(path.subList(0, 5), t -> 0.0036f, 4, BONE, Y, 1.5f);
                    ArrayList<float[]> rest = new ArrayList<>();
                    for (float[] p : path.subList(5, path.size())) rest.add(add(p, v(0.002f, -0.004f, 0)));
                    tube(rest, t -> 0.0036f, 4, BONE, Y, 1.5f);
                    crack(path.get(5), 0.006f);
                } else {
                    tube(path, t -> 0.0036f, 4, BONE, Y, 1.5f);
                }
                if (!floating) {
                    // the cartilage to the breastbone (the false ribs' to the one above)
                    float[] end = path.get(path.size() - 1);
                    float ys = i < 7 ? sTop - (sTop - sBot) * (i + 0.6f) / 7.5f : sBot + 0.004f;
                    float[] st = v(s * 0.007f, ys, zFront + 0.001f);
                    float[] midp = lerp(end, st, 0.5f);
                    midp[1] = Math.min(end[1], ys) - 0.004f;
                    ArrayList<float[]> cp = new ArrayList<>(List.of(end, lerp(end, midp, 0.5f), midp, lerp(midp, st, 0.5f), st));
                    tube(cp, t -> 0.003f, 4, CART, Y, 1.3f);
                }
            }
        }
        // the collarbones: from the notch to the shoulder, bowed forward (their own bones)
        for (int s = -1; s <= 1; s += 2) {
            use(CHEST, broken, "Bip01_" + sideName(s) + "_Clavicle");
            float[] sh = joint("Bip01_" + sideName(s) + "_UpperArm");
            float[] a0 = v(s * 0.009f, sTop + 0.003f, zFront - 0.001f);
            float[] a1 = v(sh[0] * 0.92f, sh[1] + 0.012f, sh[2] - 0.004f);
            ArrayList<float[]> path = new ArrayList<>();
            for (int k = 0; k <= 10; k++) {
                float q = k / 10f;
                float[] p = lerp(a0, a1, q);
                p[2] -= 0.008f * (float) Math.sin(q * Math.PI * 1.4f);
                p[1] += 0.003f * (float) Math.sin(q * Math.PI);
                path.add(p);
            }
            tube(path, t -> 0.0042f * (t < 0.15f || t > 0.85f ? 1.25f : 1f), 6, BONE, Y, 1.2f);
            // the shoulder blade at the back, behind the ribs
            float[] sb = v(s * wc * 0.62f, t1 - (t1 - t0) * 0.32f, mid[1] - 0.012f);
            ellipsoid(sb, v(s * 0.024f, 0, 0.006f), v(0.006f * s, 0.032f, 0), v(-0.002f * s, 0, 0.0045f), 10, 6, BONE);
        }
    }

    // ------------------------------------------------------------------ the pelvis

    static void pelvis(boolean broken) {
        use(GROIN, broken, "Bip01_Pelvis");
        float[] hipL = joint("Bip01_L_Thigh"), hipR = joint("Bip01_R_Thigh");
        float hy = hipL[1], hz = hipL[2];
        float hx = hipL[0];
        float[] sec = section(hy + 0.04f, 0.015f, 0.12f);
        float zf = sec[0], zb = sec[1];
        for (int s = -1; s <= 1; s += 2) {
            float[] hip = s > 0 ? hipL : hipR;
            // the wing (ilium): a bowl from above the hip socket, flaring up and out to
            // its crest, which runs from the front point round to the sacrum at the back
            int cols = 10, rows = 6;
            float[][][] grid = new float[rows + 1][cols + 1][];
            float[] inward = normalize(v(-s, 0, -0.35f));
            for (int k = 0; k <= cols; k++) {
                float q = k / (float) cols;   // front to back
                float ang = (float) (Math.PI * (0.12 + 0.72 * q));
                float[] cr = v(s * (0.02f + (hx * 1.5f - 0.02f) * (float) Math.sin(ang)),
                    hy + 0.058f + 0.012f * (float) Math.sin(q * Math.PI) - 0.01f * q,
                    (zf + 0.014f) + ((zb - 0.022f) - (zf + 0.014f)) * q);
                float[] bs = v(s * (hx * 0.86f - 0.012f * q), hy + 0.014f + 0.01f * q, hz - 0.012f + 0.03f * q);
                for (int r = 0; r <= rows; r++) {
                    float w = r / (float) rows;
                    float[] p = lerp(bs, cr, w);
                    // (hollow on the inside: the bowl)
                    p = add(p, scale(inward, -0.007f * (float) Math.sin(w * Math.PI) * (float) Math.sin(q * Math.PI)));
                    grid[r][k] = p;
                }
            }
            surface(grid, 0.0035f, BONE);
            ArrayList<float[]> crest = new ArrayList<>();
            for (int k = 0; k <= cols; k++) crest.add(grid[rows][k]);
            tube(crest, t -> 0.0038f, 5, BONE, Y, 1f);
            // the hip socket: a cup round the femur's head, joining the wing above
            ellipsoid(add(hip, v(-s * 0.004f, 0.004f, 0)), v(0.012f, 0, 0), v(0, 0.016f, 0), v(0, 0, 0.016f), 10, 6, BONE);
            // the pubic and ischial arches round the hole below the socket
            float[] pub = v(s * 0.008f, hy - 0.026f, zf + 0.012f);
            float[] isch = v(s * hx * 0.75f, hy - 0.036f, hz + 0.012f);
            ArrayList<float[]> ring = new ArrayList<>(List.of(
                add(hip, v(-s * 0.010f, -0.004f, -0.010f)), lerp(add(hip, v(-s * 0.01f, 0, -0.01f)), pub, 0.5f), pub,
                lerp(pub, isch, 0.5f), isch, add(hip, v(-s * 0.002f, -0.014f, 0.01f))));
            tube(ring, t -> 0.0055f, 6, BONE, Y, 1.2f);
            if (broken && s > 0) crack(crest.get(4), 0.012f);
        }
        // the sacrum: a wedge between the wings' backs, narrowing down
        lathe(v(0, hy + 0.05f, zb - 0.024f), v(0, hy + 0.0f, zb - 0.014f), t -> 0.018f * (1 - 0.68f * t), 10, 5, X, 1f, 0.32f, BONE, null);
        lathe(v(0, hy - 0.002f, zb - 0.012f), v(0, hy - 0.016f, zb - 0.018f), t -> 0.0035f * (1 - 0.6f * t), 6, 2, X, 1, 1, BONE, null);
        // the pubic symphysis joint
        lathe(v(-0.008f, hy - 0.026f, zf + 0.012f), v(0.008f, hy - 0.026f, zf + 0.012f), t -> 0.004f, 6, 2, Y, 1, 1, CART, null);
    }

    // ------------------------------------------------------------------ the skull

    static void skull(boolean broken) {
        use(HEAD, broken, "Bip01_Head");
        // the head's own surface drawn in: the skull fills the head as the head shows it
        float[] c = new float[3];
        int n = 0;
        for (int i = 0; i < pos.length / 3; i++) if (partOf[i] == HEAD) { for (int k = 0; k < 3; k++) c[k] += pos[i * 3 + k]; n++; }
        for (int k = 0; k < 3; k++) c[k] /= n;
        float headY = joint("Bip01_Head")[1];
        Piece pc = piece(BONE);
        int[] map = new int[pos.length / 3];
        Arrays.fill(map, -1);
        for (int f = 0; f < faces.length / 3; f++) {
            int[] vv = {faces[f * 3], faces[f * 3 + 1], faces[f * 3 + 2]};
            boolean all = true;
            for (int q : vv) if (partOf[q] != HEAD || pos[q * 3 + 1] < headY - 0.004f) all = false;
            if (!all) continue;
            int[] tri = new int[3];
            for (int j = 0; j < 3; j++) {
                int q = vv[j];
                if (map[q] < 0) {
                    float[] p = v3(pos, q), nn = v3(nrm, nfaces[f * 3 + j]);
                    // in toward the middle and under the skin
                    float[] d = sub(p, c);
                    float[] sp = add(c, scale(d, 0.9f));
                    sp = add(sp, scale(normalize(nn), -0.003f));
                    map[q] = pc.v.size();
                    pc.v.add(sp);
                    pc.n.add(normalize(nn.clone()));
                    pc.t.add(new float[] {uv[q * 2], 0.3f + 0.4f * uv[q * 2 + 1]});
                }
                tri[j] = map[q];
            }
            pc.tri.add(tri);
        }
        // the face's features, dark, on the skull's front: eye sockets, the nose, the teeth's line
        float[] eyeL = onSkin(0.527f, 0.130f), eyeR = onSkin(0.475f, 0.130f), nose = onSkin(0.501f, 0.168f), mouth = onSkin(0.501f, 0.196f);
        if (eyeL == null || eyeR == null || nose == null || mouth == null) throw new RuntimeException("face not found on the skin's layout");
        for (float[] e : new float[][] {eyeL, eyeR}) {
            float[] ec = add(scale(add(c, scale(sub(e, c), 0.9f)), 1), v(0, 0, 0.0035f));
            ellipsoid(ec, v(0.0105f, 0, 0), v(0, 0.0095f, 0), v(0, 0, 0.004f), 10, 6, DARK);
        }
        float[] nc = add(c, scale(sub(nose, c), 0.9f));
        nc = add(nc, v(0, -0.002f, 0.003f));
        ellipsoid(nc, v(0.0045f, 0, 0), v(0, 0.0075f, 0), v(0, 0, 0.003f), 8, 5, DARK);
        float[] mc = add(c, scale(sub(mouth, c), 0.9f));
        mc = add(mc, v(0, 0, 0.0015f));
        ellipsoid(mc, v(0.0135f, 0, 0), v(0, 0.0055f, 0), v(0, 0, 0.0028f), 10, 5, DARK);
        // the teeth: two rows across the dark line
        for (int row = -1; row <= 1; row += 2) {
            for (int k = 0; k < 8; k++) {
                float x = -0.0105f + 0.003f * k;
                float bow = 0.0018f * (x / 0.0105f) * (x / 0.0105f);
                float[] tc = add(mc, v(x, row * 0.0023f, bow - 0.0008f));
                ellipsoid(tc, v(0.0012f, 0, 0), v(0, 0.002f, 0), v(0, 0, 0.0018f), 4, 3, BONE);
            }
        }
        if (broken) {
            // a crack over the brow to the temple
            ArrayList<float[]> crack = new ArrayList<>();
            float[] top = onSkin(0.56f, 0.07f);
            if (top == null) top = add(eyeL, v(0.005f, 0.03f, 0));
            for (int k = 0; k <= 6; k++) {
                float[] p = add(c, scale(sub(add(top, v(0.004f * k, -0.003f * k + ((k % 2) * 0.002f), 0.002f * k)), c), 0.905f));
                crack.add(p);
            }
            tube(crack, t -> 0.0012f, 4, DARK, Y, 1f);
        }
    }

    // ------------------------------------------------------------------ the arm

    static void arm(int s, boolean broken) {
        String sd = sideName(s);
        float[] sh = joint("Bip01_" + sd + "_UpperArm"), el = joint("Bip01_" + sd + "_Forearm"), wr = joint("Bip01_" + sd + "_Hand");
        float[] f1 = joint("Bip01_" + sd + "_Finger1"), f0 = joint("Bip01_" + sd + "_Finger0");
        // the humerus: a ball in the shoulder, the shaft, the elbow's two knobs
        use(side(UPPERARM, s), broken, "Bip01_" + sd + "_UpperArm");
        float[] axis = normalize(sub(el, sh));
        ellipsoid(add(sh, scale(axis, 0.006f)), v(0.011f, 0, 0), v(0, 0.011f, 0), v(0, 0, 0.011f), 10, 7, BONE);
        float[] h0 = add(sh, scale(axis, 0.012f)), h1 = add(el, scale(axis, -0.008f));
        longBone(h0, h1, 0.0058f, 0.35f, 0.55f, Y, broken);
        ellipsoid(add(el, v(-s * 0.004f, 0, 0.001f)), v(0.0055f, 0, 0), v(0, 0.0115f, 0), v(0, 0, 0.0065f), 10, 6, BONE);
        // the forearm: the ulna (back, big at the elbow) and the radius (front, big at the wrist), close together
        use(side(FOREARM, s), broken, "Bip01_" + sd + "_Forearm");
        float[] fa = normalize(sub(wr, el));
        float[] back = v(0, 0, 1);
        float[] up = v(0, 1, 0);
        float[] u0 = add(el, add(scale(fa, -0.004f), add(scale(back, 0.003f), scale(up, -0.0042f)))), u1 = add(wr, add(scale(fa, -0.006f), add(scale(back, 0.0025f), scale(up, -0.0032f))));
        float[] r0 = add(el, add(scale(fa, 0.006f), add(scale(back, -0.002f), scale(up, 0.0038f)))), r1 = add(wr, add(scale(fa, -0.004f), add(scale(back, -0.003f), scale(up, 0.0042f))));
        lathe(u0, u1, t -> 0.0042f * (t < 0.12f ? 1.6f - 5 * t : 1f) * (1 - 0.35f * t), 8, 10, Y, 1, 1, BONE,
            broken ? new float[] {0.5f} : null);
        lathe(r0, r1, t -> 0.0036f * (t > 0.82f ? 1 + (t - 0.82f) * 4.5f : 1f) * (0.8f + 0.2f * t), 8, 10, Y, 1, 1, BONE,
            broken ? new float[] {0.42f} : null);
        // (the olecranon: the elbow's point behind)
        ellipsoid(add(el, v(s * 0.004f, 0, 0.007f)), v(0.006f, 0, 0), v(0, 0.005f, 0), v(0, 0, 0.004f), 8, 5, BONE);
        // the hand: the wrist's small bones, the palm's five, the fingers'
        use(side(HAND, s), broken, "Bip01_" + sd + "_Hand");
        float[] ha = normalize(sub(f1, wr));
        float handLen = 0;
        for (int i = 0; i < pos.length / 3; i++) if (partOf[i] == side(HAND, s)) handLen = Math.max(handLen, dot(sub(v3(pos, i), wr), ha));
        float[] carp = add(wr, scale(ha, 0.009f));
        for (int k = 0; k < 6; k++) {
            float[] o = v(0, (k % 2 == 0 ? 0.0025f : -0.0025f), -0.009f + 0.0036f * k);
            ellipsoid(add(add(carp, o), scale(ha, (k / 3) * 0.004f)), v(0.003f, 0, 0), v(0, 0.0025f, 0), v(0, 0, 0.0028f), 5, 3, BONE);
        }
        float[] down = v(0, -1, 0);
        for (int fgr = 0; fgr < 4; fgr++) {
            float zoff = -0.01f + 0.0068f * fgr;   // index (front) to little finger (back)
            float[] mb = add(carp, add(scale(ha, 0.008f), v(0, 0, zoff * 0.55f)));
            float[] kn = add(f1, v(0, 0.001f, zoff));
            boolean snap = broken && fgr == 1;
            lathe(mb, kn, t -> 0.0019f * (t < 0.1f || t > 0.88f ? 1.35f : 1f), 5, 3, Y, 1, 1, BONE, snap ? new float[] {0.5f} : null);
            float tip = Math.max(0.03f, handLen - dot(sub(kn, wr), ha) - 0.004f);
            float[] dir = normalize(add(ha, scale(down, 0.18f)));
            float[] p = add(kn, scale(dir, 0.0025f));
            float[] lens = {0.45f, 0.3f, 0.25f};
            for (int ph = 0; ph < 3; ph++) {
                float len = tip * lens[ph] * (fgr == 3 ? 0.82f : 1f);
                float[] q = add(p, scale(dir, len - 0.0015f));
                final float pr = 0.0015f * (1 - 0.25f * ph);
                lathe(p, q, t -> pr * (t < 0.15f || t > 0.85f ? 1.3f : 1f), 4, 2, Y, 1, 1, BONE, null);
                p = add(q, scale(dir, 0.0015f));
                dir = normalize(add(dir, scale(down, 0.12f)));
            }
        }
        // the thumb: its palm bone to its base joint, two bones beyond
        float[] tb = add(carp, v(0, -0.001f, -0.011f));
        lathe(tb, f0, t -> 0.0022f * (t < 0.12f || t > 0.88f ? 1.3f : 1f), 6, 4, Y, 1, 1, BONE, null);
        float[] td = normalize(sub(f0, tb));
        float[] tp = add(f0, scale(td, 0.0025f));
        for (int ph = 0; ph < 2; ph++) {
            float[] q = add(tp, scale(td, 0.011f - 0.002f * ph));
            final float pr = 0.0019f * (1 - 0.2f * ph);
            lathe(tp, q, t -> pr, 4, 2, Y, 1, 1, BONE, null);
            tp = add(q, scale(td, 0.0018f));
        }
    }

    // ------------------------------------------------------------------ the leg

    static void leg(int s, boolean broken) {
        String sd = sideName(s);
        float[] hip = joint("Bip01_" + sd + "_Thigh"), knee = joint("Bip01_" + sd + "_Calf"), ank = joint("Bip01_" + sd + "_Foot");
        // the femur: the head in the socket, the neck out to the big knob, the shaft in to the knee, its two knobs and the kneecap
        use(side(THIGH, s), broken, "Bip01_" + sd + "_Thigh");
        ellipsoid(hip, v(0.0125f, 0, 0), v(0, 0.0125f, 0), v(0, 0, 0.0125f), 10, 7, BONE);
        float[] troch = add(hip, v(s * 0.032f, -0.018f, 0.003f));
        lathe(add(hip, v(s * 0.006f, -0.003f, 0)), troch, t -> 0.0075f, 8, 3, Y, 1, 1, BONE, null);
        ellipsoid(add(troch, v(s * 0.002f, 0.004f, 0.002f)), v(0.0085f, 0, 0), v(0, 0.011f, 0), v(0, 0, 0.0085f), 8, 6, BONE);
        float[] fTop = add(troch, v(-s * 0.004f, -0.008f, 0)), fBot = add(knee, v(0, 0.016f, 0.002f));
        longBone(fTop, fBot, 0.0075f, 0.0f, 0.7f, X, broken);
        for (int k = -1; k <= 1; k += 2) ellipsoid(add(knee, v(k * 0.0095f, 0.008f, 0.004f)), v(0.0085f, 0, 0), v(0, 0.009f, 0), v(0, 0, 0.012f), 8, 6, BONE);
        float[] shinFront = section2(knee[1] + 0.01f, knee[0], 0.04f);
        ellipsoid(v(knee[0], knee[1] + 0.012f, Math.min(knee[2] - 0.016f, shinFront[0] + 0.006f)), v(0.0095f, 0, 0), v(0, 0.011f, 0), v(0, 0, 0.0045f), 8, 6, BONE);
        // the shin: the tibia (in front and to the middle: its plateau, its shaft, the inner ankle knob) and the thin fibula outside
        use(side(SHIN, s), broken, "Bip01_" + sd + "_Calf");
        float[] tTop = add(knee, v(-s * 0.002f, -0.008f, -0.002f)), tBot = add(ank, v(-s * 0.004f, 0.012f, -0.003f));
        ellipsoid(add(knee, v(-s * 0.002f, -0.005f, 0.002f)), v(0.0165f, 0, 0), v(0, 0.007f, 0), v(0, 0, 0.0135f), 10, 6, BONE);
        longBone(tTop, tBot, 0.0072f, 0.55f, 0.45f, X, broken);
        ellipsoid(add(ank, v(-s * 0.009f, 0.004f, -0.002f)), v(0.005f, 0, 0), v(0, 0.008f, 0), v(0, 0, 0.007f), 8, 5, BONE);
        float[] fbTop = add(knee, v(s * 0.0135f, -0.016f, 0.008f)), fbBot = add(ank, v(s * 0.0105f, 0.0f, 0.004f));
        lathe(fbTop, fbBot, t -> 0.0028f * (t < 0.08f || t > 0.9f ? 1.7f : 1f), 6, 8, X, 1, 1, BONE, broken ? new float[] {0.58f} : null);
        // the foot: heel and ankle bones, the arch's five, the toes
        use(side(FOOT, s), broken, "Bip01_" + sd + "_Foot");
        float toeZ = Float.MAX_VALUE, heelZ = -Float.MAX_VALUE, floor = Float.MAX_VALUE;
        for (int i = 0; i < pos.length / 3; i++) {
            if (partOf[i] != side(FOOT, s)) continue;
            toeZ = Math.min(toeZ, pos[i * 3 + 2]); heelZ = Math.max(heelZ, pos[i * 3 + 2]); floor = Math.min(floor, pos[i * 3 + 1]);
        }
        float len = heelZ - toeZ;
        ellipsoid(v(ank[0], ank[1] - 0.009f, ank[2] - 0.002f), v(0.0095f, 0, 0), v(0, 0.008f, 0), v(0, 0, 0.012f), 8, 6, BONE);
        ellipsoid(v(ank[0] + s * 0.002f, floor + 0.016f, heelZ - 0.016f), v(0.0095f, 0, 0), v(0, 0.013f, 0), v(0, 0, 0.017f), 8, 6, BONE);
        float midZ = ank[2] - len * 0.22f, ballZ = toeZ + len * 0.27f;
        for (int k = 0; k < 3; k++) {
            ellipsoid(v(ank[0] - s * (0.008f - 0.008f * k), floor + 0.022f, midZ + 0.006f), v(0.0045f, 0, 0), v(0, 0.005f, 0), v(0, 0, 0.007f), 6, 4, BONE);
        }
        for (int t = 0; t < 5; t++) {
            float x = ank[0] - s * 0.017f + s * 0.0085f * t;   // the big toe on the inside
            float r = t == 0 ? 0.0032f : 0.0022f;
            float[] a0 = v(x * 0.97f + ank[0] * 0.03f, floor + 0.02f - 0.002f * t, midZ - 0.002f);
            float[] a1 = v(x + s * 0.001f * t, floor + 0.0075f, ballZ + 0.002f * t);
            lathe(a0, a1, q -> r * (q < 0.1f || q > 0.86f ? 1.35f : 1f), 5, 3, Y, 1, 1, BONE, broken && t == 2 ? new float[] {0.5f} : null);
            float[] dir = normalize(v(0, -0.12f, -1));
            float[] p = add(a1, scale(dir, 0.0025f));
            int segs = t == 0 ? 2 : 3;
            float rest = (ballZ - toeZ - 0.004f) * (t == 0 ? 1f : 0.9f - 0.06f * t);
            for (int ph = 0; ph < segs; ph++) {
                float l = rest / segs - 0.0012f;
                float[] q2 = add(p, scale(dir, l));
                final float pr = r * 0.8f * (1 - 0.15f * ph);
                lathe(p, q2, q -> pr, 4, 2, Y, 1, 1, BONE, null);
                p = add(q2, scale(dir, 0.0012f));
            }
        }
    }

    /** A leg's section at a height near x: {front z, back z}. */
    static float[] section2(float y, float x, float rx) {
        float zf = Float.MAX_VALUE, zb = -Float.MAX_VALUE;
        for (int i = 0; i < pos.length / 3; i++) {
            if (Math.abs(pos[i * 3 + 1] - y) > 0.015f || Math.abs(pos[i * 3] - x) > rx) continue;
            zf = Math.min(zf, pos[i * 3 + 2]); zb = Math.max(zb, pos[i * 3 + 2]);
        }
        return new float[] {zf, zb};
    }

    /** A long bone's shaft between two points: thin in the middle, knobs at the ends; broken in the middle if asked. */
    static void longBone(float[] a, float[] b, float r, float knobA, float knobB, float[] ref, boolean broken) {
        Profile p = t -> {
            float w = r;
            if (t < 0.18f) { float k = 1 - t / 0.18f; w *= 1 + knobA * k * k; }
            if (t > 0.82f) { float k = (t - 0.82f) / 0.18f; w *= 1 + knobB * k * k; }
            return w;
        };
        lathe(a, b, p, 8, 10, ref, 1.1f, 1f, BONE, broken ? new float[] {0.5f} : null);
    }

    static void crack(float[] at, float size) {
        ArrayList<float[]> path = new ArrayList<>();
        for (int k = 0; k <= 4; k++) path.add(add(at, v(-size / 2 + size * k / 4, (k % 2 == 0 ? 1 : -1) * size * 0.15f, -0.0015f)));
        tube(path, t -> 0.0011f, 4, DARK, Y, 1f);
    }

    // ------------------------------------------------------------------ shapes

    interface Profile { float r(float t); }

    static final float[] X = {1, 0, 0}, Y = {0, 1, 0}, Z = {0, 0, 1};

    static Piece piece(int kind) {
        Piece pc = new Piece();
        pc.bone = curBone;
        pc.block = curBlock;
        pc.part = curBlock / 2;
        pc.broken = curBlock % 2 == 1;
        pc.kind = kind;
        pieces.add(pc);
        return pc;
    }

    /**
     * A surface of revolution from a to b, radius by profile (0..1 along), elliptic
     * (ew along ref, ed across). breakAt: a share where it is broken - two pieces with
     * a jagged gap, the far one a little aside.
     */
    static void lathe(float[] a, float[] b, Profile prof, int seg, int rings, float[] ref, float ew, float ed, int kind, float[] breakAt) {
        if (breakAt != null) {
            float m = breakAt[0];
            float[] d = sub(b, a);
            float[] gapA = add(a, scale(d, m - 0.025f)), gapB = add(a, scale(d, m + 0.025f));
            float[] off = scale(normalize(ortho(ref, normalize(d))), len(d) * 0.04f);
            latheRaw(a, gapA, t -> prof.r(t * (m - 0.025f)), seg, Math.max(2, (int) (rings * m)), ref, ew, ed, kind, false, true);
            latheRaw(add(gapB, off), add(b, off), t -> prof.r(m + 0.025f + t * (1 - m - 0.025f)), seg,
                Math.max(2, (int) (rings * (1 - m))), ref, ew, ed, kind, true, false);
            // (a dark line where it broke)
            float[] mid = add(a, scale(d, m));
            ArrayList<float[]> line = new ArrayList<>();
            float[] across = normalize(ortho(ref, normalize(d)));
            float rr = prof.r(m) * 1.05f;
            for (int k = 0; k <= 4; k++) line.add(add(mid, add(scale(across, -rr + 2 * rr * k / 4), scale(normalize(d), (k % 2 == 0 ? 1 : -1) * len(d) * 0.015f))));
            Piece save = null;
            tube(line, t -> rr * 0.25f, 4, DARK, ref, 1f);
            return;
        }
        latheRaw(a, b, prof, seg, rings, ref, ew, ed, kind, false, false);
    }

    static void latheRaw(float[] a, float[] b, Profile prof, int seg, int rings, float[] ref, float ew, float ed, int kind,
                         boolean jagStart, boolean jagEnd) {
        Piece pc = piece(kind);
        float[] d = sub(b, a);
        float L = len(d);
        float[] ax = normalize(d.clone());
        float[] e1 = normalize(ortho(ref, ax));
        float[] e2 = normalize(cross(ax, e1));
        int base = 0;
        for (int i = 0; i <= rings; i++) {
            float t = i / (float) rings;
            float r = prof.r(t);
            for (int j = 0; j < seg; j++) {
                float th = (float) (2 * Math.PI * j / seg);
                float cs = (float) Math.cos(th), sn = (float) Math.sin(th);
                float tt = t;
                if ((i == 0 && jagStart) || (i == rings && jagEnd)) tt += (j % 2 == 0 ? 1 : -1) * 0.02f * (i == 0 ? 1 : -1) * 0.5f / Math.max(0.05f, L) * 0.02f;
                float[] p = add(add(a, scale(ax, tt * L)), add(scale(e1, cs * r * ew), scale(e2, sn * r * ed)));
                if ((i == 0 && jagStart) || (i == rings && jagEnd)) p = add(p, scale(ax, (j % 2 == 0 ? 1 : -1) * r * 0.6f));
                pc.v.add(p);
                pc.n.add(normalize(add(scale(e1, cs / ew), scale(e2, sn / ed))));
                pc.t.add(new float[] {j / (float) seg, t});
            }
        }
        for (int i = 0; i < rings; i++) {
            for (int j = 0; j < seg; j++) {
                int a0 = base + i * seg + j, a1 = base + i * seg + (j + 1) % seg;
                pc.tri.add(new int[] {a0, a0 + seg, a1});
                pc.tri.add(new int[] {a1, a0 + seg, a1 + seg});
            }
        }
        for (int end = 0; end < 2; end++) {
            int ring = end == 0 ? 0 : rings;
            float[] cp = end == 0 ? a : b;
            int ci = pc.v.size();
            pc.v.add(cp);
            pc.n.add(scale(ax, end == 0 ? -1 : 1));
            pc.t.add(new float[] {0.5f, end});
            for (int j = 0; j < seg; j++) {
                int a0 = base + ring * seg + j, a1 = base + ring * seg + (j + 1) % seg;
                if (end == 0) pc.tri.add(new int[] {ci, a0, a1});
                else pc.tri.add(new int[] {ci, a1, a0});
            }
        }
    }

    /** A tube along a path, radius by the share along it, flattened along ref by flat. */
    static void tube(List<float[]> path, Profile prof, int seg, int kind, float[] ref, float flat) {
        Piece pc = piece(kind);
        int m = path.size();
        for (int i = 0; i < m; i++) {
            float[] tg = normalize(sub(path.get(Math.min(m - 1, i + 1)), path.get(Math.max(0, i - 1))));
            float[] e1 = normalize(ortho(ref, tg));
            float[] e2 = normalize(cross(tg, e1));
            float r = prof.r(i / (float) (m - 1));
            for (int j = 0; j < seg; j++) {
                float th = (float) (2 * Math.PI * j / seg);
                float cs = (float) Math.cos(th), sn = (float) Math.sin(th);
                float[] n = add(scale(e1, cs / flat), scale(e2, sn));
                pc.v.add(add(path.get(i), add(scale(e1, cs * r * flat), scale(e2, sn * r))));
                pc.n.add(normalize(n));
                pc.t.add(new float[] {j / (float) seg, i / (float) (m - 1)});
            }
        }
        for (int i = 0; i < m - 1; i++) {
            for (int j = 0; j < seg; j++) {
                int a0 = i * seg + j, a1 = i * seg + (j + 1) % seg;
                pc.tri.add(new int[] {a0, a0 + seg, a1});
                pc.tri.add(new int[] {a1, a0 + seg, a1 + seg});
            }
        }
        // the ends closed
        for (int end = 0; end < 2; end++) {
            int ring = end == 0 ? 0 : m - 1;
            int ci = pc.v.size();
            pc.v.add(path.get(ring));
            pc.n.add(normalize(sub(path.get(ring), path.get(end == 0 ? 1 : m - 2))));
            pc.t.add(new float[] {0.5f, end});
            for (int j = 0; j < seg; j++) {
                int a0 = ring * seg + j, a1 = ring * seg + (j + 1) % seg;
                if (end == 0) pc.tri.add(new int[] {ci, a0, a1});
                else pc.tri.add(new int[] {ci, a1, a0});
            }
        }
    }

    /** An ellipsoid at c with three half-axes. */
    static void ellipsoid(float[] c, float[] ax1, float[] ax2, float[] ax3, int seg, int rings, int kind) {
        Piece pc = piece(kind);
        float l1 = len(ax1), l2 = len(ax2), l3 = len(ax3);
        float[] u1 = normalize(ax1.clone()), u2 = normalize(ax2.clone()), u3 = normalize(ax3.clone());
        for (int i = 0; i <= rings; i++) {
            float ph = (float) (Math.PI * i / rings) - (float) Math.PI / 2;
            for (int j = 0; j < seg; j++) {
                float th = (float) (2 * Math.PI * j / seg);
                float cx = (float) (Math.cos(ph) * Math.cos(th)), cy = (float) Math.sin(ph), cz = (float) (Math.cos(ph) * Math.sin(th));
                pc.v.add(add(c, add(add(scale(ax1, cx), scale(ax2, cy)), scale(ax3, cz))));
                pc.n.add(normalize(add(add(scale(u1, cx / l1), scale(u2, cy / l2)), scale(u3, cz / l3))));
                pc.t.add(new float[] {j / (float) seg, i / (float) rings});
            }
        }
        for (int i = 0; i < rings; i++) {
            for (int j = 0; j < seg; j++) {
                int a0 = i * seg + j, a1 = i * seg + (j + 1) % seg;
                pc.tri.add(new int[] {a0, a1, a0 + seg});
                pc.tri.add(new int[] {a1, a1 + seg, a0 + seg});
            }
        }
    }

    /** A thin double-sided surface over a grid of points [row][col] (a pelvis's wing). */
    static void surface(float[][][] g, float thick, int kind) {
        Piece pc = piece(kind);
        int rows = g.length - 1, cols = g[0].length - 1;
        for (int side = 0; side < 2; side++) {
            int base = pc.v.size();
            for (int r = 0; r <= rows; r++) {
                for (int c = 0; c <= cols; c++) {
                    float[] du = sub(g[r][Math.min(cols, c + 1)], g[r][Math.max(0, c - 1)]);
                    float[] dv = sub(g[Math.min(rows, r + 1)][c], g[Math.max(0, r - 1)][c]);
                    float[] n = normalize(cross(du, dv));
                    if (side == 1) n = scale(n, -1);
                    pc.v.add(add(g[r][c], scale(n, thick / 2)));
                    pc.n.add(n);
                    pc.t.add(new float[] {c / (float) cols, r / (float) rows});
                }
            }
            for (int r = 0; r < rows; r++) {
                for (int c = 0; c < cols; c++) {
                    int a0 = base + r * (cols + 1) + c, a1 = a0 + 1, b0 = a0 + cols + 1, b1 = b0 + 1;
                    pc.tri.add(new int[] {a0, b0, a1});
                    pc.tri.add(new int[] {a1, b0, b1});
                }
            }
        }
    }

    /** A thin double-sided sheet between two rows of points (a pelvis's wing). */
    static void sheet(List<float[]> top, List<float[]> bot, float thick, int kind) {
        Piece pc = piece(kind);
        int m = top.size(), rows = 4;
        for (int side = 0; side < 2; side++) {
            int base = pc.v.size();
            for (int r = 0; r <= rows; r++) {
                for (int i = 0; i < m; i++) {
                    float[] p = lerp(bot.get(i), top.get(i), r / (float) rows);
                    float[] du = sub(top.get(Math.min(m - 1, i + 1)), top.get(Math.max(0, i - 1)));
                    float[] dv = sub(top.get(i), bot.get(i));
                    float[] n = normalize(cross(du, dv));
                    if (side == 1) n = scale(n, -1);
                    pc.v.add(add(p, scale(n, thick / 2)));
                    pc.n.add(n);
                    pc.t.add(new float[] {i / (float) (m - 1), r / (float) rows});
                }
            }
            for (int r = 0; r < rows; r++) {
                for (int i = 0; i < m - 1; i++) {
                    int a0 = base + r * m + i, a1 = a0 + 1, b0 = a0 + m, b1 = b0 + 1;
                    pc.tri.add(new int[] {a0, b0, a1});
                    pc.tri.add(new int[] {a1, b0, b1});
                }
            }
        }
    }

    // ------------------------------------------------------------------ output

    /** Where a piece's spot (0..1 round, 0..1 along) is on the texture: its block, its colour's rows. */
    static float[] blockUV(int block, int kind, float bu, float bv) {
        int bx = (block % 8) * BLOCK, by = (block / 8) * BLOCK;
        float row;
        if (kind == DARK) row = 24;
        else if (kind == CART) row = 29;
        else row = 2 + bv * 18;
        return new float[] {(bx + 3 + bu * (BLOCK - 6)) / TS, (by + row + 0.5f) / TS};
    }

    static String f6(float x) { return String.format(Locale.ROOT, "%.6f", x); }

    static void writeX(File out) throws Exception {
        int same = 0, other = 0;
        for (int i = 0; i < faces.length / 3; i++) {
            float[] p0 = v3(pos, faces[i * 3]), p1 = v3(pos, faces[i * 3 + 1]), p2 = v3(pos, faces[i * 3 + 2]);
            if (dot(cross(sub(p1, p0), sub(p2, p0)), v3(nrm, nfaces[i * 3])) > 0) same++; else other++;
        }
        boolean wantCcw = same >= other;
        StringBuilder sb = new StringBuilder();
        ArrayList<float[]> V = new ArrayList<>(), N = new ArrayList<>(), T = new ArrayList<>();
        ArrayList<int[]> F = new ArrayList<>();
        ArrayList<String> vb = new ArrayList<>();
        for (Piece pc : pieces) {
            int base = V.size();
            V.addAll(pc.v);
            N.addAll(pc.n);
            for (float[] t : pc.t) T.add(blockUV(pc.block, pc.kind, t[0], t[1]));
            for (int i = 0; i < pc.v.size(); i++) vb.add(pc.bone);
            for (int[] t : pc.tri) {
                float[] p0 = V.get(base + t[0]), p1 = V.get(base + t[1]), p2 = V.get(base + t[2]);
                float[] nn = add(add(N.get(base + t[0]), N.get(base + t[1])), N.get(base + t[2]));
                boolean ccw = dot(cross(sub(p1, p0), sub(p2, p0)), nn) > 0;
                if (ccw == wantCcw) F.add(new int[] {base + t[0], base + t[1], base + t[2]});
                else F.add(new int[] {base + t[0], base + t[2], base + t[1]});
            }
        }
        sb.append(" Mesh Body {\n  ").append(V.size()).append(";\n");
        for (int i = 0; i < V.size(); i++) {
            float[] p = V.get(i);
            sb.append("  ").append(f6(p[0])).append(';').append(f6(p[1])).append(';').append(f6(p[2])).append(';').append(i == V.size() - 1 ? ";\n" : ",\n");
        }
        sb.append("  ").append(F.size()).append(";\n");
        for (int i = 0; i < F.size(); i++) {
            int[] f = F.get(i);
            sb.append("  3;").append(f[0]).append(',').append(f[1]).append(',').append(f[2]).append(';').append(i == F.size() - 1 ? ";\n" : ",\n");
        }
        sb.append("\n  MeshNormals {\n   ").append(N.size()).append(";\n");
        for (int i = 0; i < N.size(); i++) {
            float[] n = normalize(N.get(i).clone());
            sb.append("   ").append(f6(n[0])).append(';').append(f6(n[1])).append(';').append(f6(n[2])).append(';').append(i == N.size() - 1 ? ";\n" : ",\n");
        }
        sb.append("   ").append(F.size()).append(";\n");
        for (int i = 0; i < F.size(); i++) {
            int[] f = F.get(i);
            sb.append("   3;").append(f[0]).append(',').append(f[1]).append(',').append(f[2]).append(';').append(i == F.size() - 1 ? ";\n" : ",\n");
        }
        sb.append("  }\n\n  MeshMaterialList {\n   1;\n   ").append(F.size()).append(";\n");
        for (int i = 0; i < F.size(); i++) sb.append("   0").append(i == F.size() - 1 ? ";\n" : ",\n");
        sb.append("   { ").append(material()).append(" }\n  }\n\n  MeshTextureCoords c1 {\n   ").append(T.size()).append(";\n");
        for (int i = 0; i < T.size(); i++) {
            float[] t = T.get(i);
            sb.append("   ").append(f6(t[0])).append(';').append(f6(t[1])).append(';').append(i == T.size() - 1 ? ";\n" : ",\n");
        }
        sb.append("  }\n\n");
        LinkedHashMap<String, ArrayList<Integer>> byBone = new LinkedHashMap<>();
        for (int i = 0; i < vb.size(); i++) byBone.computeIfAbsent(vb.get(i), k -> new ArrayList<>()).add(i);
        sb.append("  XSkinMeshHeader {\n   1;\n   3;\n   ").append(byBone.size()).append(";\n  }\n");
        for (Map.Entry<String, ArrayList<Integer>> e : byBone.entrySet()) {
            String m = MATRIX.get(e.getKey());
            if (m == null) throw new RuntimeException("the body has no offset for " + e.getKey());
            ArrayList<Integer> ids = e.getValue();
            sb.append("\n  SkinWeights {\n   \"").append(e.getKey()).append("\";\n   ").append(ids.size()).append(";\n");
            for (int i = 0; i < ids.size(); i++) sb.append("   ").append(ids.get(i)).append(i == ids.size() - 1 ? ";\n" : ",\n");
            for (int i = 0; i < ids.size(); i++) sb.append("   1.000000").append(i == ids.size() - 1 ? ";\n" : ",\n");
            sb.append("   ").append(m).append(";;\n  }\n");
        }
        sb.append(" }\n");
        Files.writeString(out.toPath(), src.substring(0, meshStart) + sb + src.substring(meshEnd), StandardCharsets.ISO_8859_1);
        System.out.printf("%s: %d vertices, %d triangles, %d pieces, %d bones%n", out.getName(), V.size(), F.size(), pieces.size(), byBone.size());
    }

    static String material() {
        Matcher m = Pattern.compile("\\{\\s*([A-Za-z0-9_\\-]+)\\s*\\}").matcher(src);
        if (m.find(src.indexOf("MeshMaterialList", meshStart))) return m.group(1);
        throw new RuntimeException("no material reference");
    }

    /** The texture: every texel all but transparent (Java shows the blocks, colouring them itself). */
    static void writeTexture(File out) throws Exception {
        BufferedImage img = new BufferedImage(TS, TS, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < TS; y++) for (int x = 0; x < TS; x++) img.setRGB(x, y, (1 << 24) | 0xECE4D0);
        ImageIO.write(img, "png", out);
    }

    // ------------------------------------------------------------------ previews

    static final int[] COLOUR = {0xECE4D0, 0x2A2420, 0xB8C4CC};

    /** Front views of each part's broken bones under see-through skin, and the whole skeleton front and side. */
    static void previews(File dir, String g) throws Exception {
        dir.mkdirs();
        // the whole: every whole bone, front and side
        render(new File(dir, g + "_all_front.png"), -1, false, 0, 0.05f, 0.95f, 900);
        render(new File(dir, g + "_all_side.png"), -1, false, 1, 0.05f, 0.95f, 900);
        String[] names = {"hand", "forearm", "upperarm", "chest", "belly", "head", "neck", "pelvis", "thigh", "shin", "foot"};
        int[] parts = {HAND, FOREARM, UPPERARM, CHEST, BELLY, HEAD, NECK, GROIN, THIGH, SHIN, FOOT};
        for (int k = 0; k < parts.length; k++) render(new File(dir, g + "_" + names[k] + ".png"), parts[k], true, 0, 0, 0, 520);
    }

    /**
     * Renders: the body (see-through where the part is, else opaque), the part's
     * bones (broken or whole; all whole bones if part < 0); view 0 front, 1 side.
     * A part's view is framed on the part.
     */
    static void render(File out, int part, boolean broken, int view, float y0, float y1, int size) throws Exception {
        // the frame: the part's bounds (both of its points if a side part)
        float[] lo = {Float.MAX_VALUE, Float.MAX_VALUE}, hi = {-Float.MAX_VALUE, -Float.MAX_VALUE};
        for (int i = 0; i < pos.length / 3; i++) {
            boolean in = part < 0 ? pos[i * 3 + 1] >= y0 && pos[i * 3 + 1] <= y1 : partOf[i] == part;
            if (!in) continue;
            float sx = view == 0 ? pos[i * 3] : -pos[i * 3 + 2], sy = pos[i * 3 + 1];
            lo[0] = Math.min(lo[0], sx); lo[1] = Math.min(lo[1], sy); hi[0] = Math.max(hi[0], sx); hi[1] = Math.max(hi[1], sy);
        }
        float pad = 0.25f * Math.max(hi[0] - lo[0], hi[1] - lo[1]);
        lo[0] -= pad; lo[1] -= pad; hi[0] += pad; hi[1] += pad;
        float sc = size / Math.max(hi[0] - lo[0], hi[1] - lo[1]);
        int W = (int) ((hi[0] - lo[0]) * sc) + 1, H = (int) ((hi[1] - lo[1]) * sc) + 1;
        int[] rgb = new int[W * H];
        float[] zb = new float[W * H];
        Arrays.fill(rgb, 0x15171A);
        Arrays.fill(zb, Float.MAX_VALUE);
        // the bones first, as the game draws them before the skin goes over (back faces culled)
        for (Piece pc : pieces) {
            int p = pc.part;
            boolean br = pc.broken;
            boolean mine = pc.shared || br == broken;
            boolean show = part < 0 ? (pc.shared || !br) : (mine && (p == part || p == part + 1 && isPaired(part)));
            if (!show) continue;
            for (int[] t : pc.tri) {
                float[] n = normalize(add(add(pc.n.get(t[0]), pc.n.get(t[1])), pc.n.get(t[2])));
                float[] lv = view == 0 ? v(-0.3f, 0.5f, -0.8f) : v(-0.8f, 0.5f, -0.3f);
                float l = 0.35f + 0.65f * Math.max(0, dot(n, normalize(lv)));
                tri(rgb, zb, W, H, pc.v.get(t[0]), pc.v.get(t[1]), pc.v.get(t[2]), n, view, lo, hi, sc, shade(COLOUR[pc.kind], l), 1f, true);
            }
        }
        // the body: see-through where the part is (as the game's skin under the mouse), opaque elsewhere
        for (int f = 0; f < faces.length / 3; f++) {
            int a = faces[f * 3], b = faces[f * 3 + 1], c = faces[f * 3 + 2];
            if (partOf[a] < 0 || partOf[b] < 0 || partOf[c] < 0) continue;   // (the skirt, hidden by the skin's alpha)
            float[] n = v3(nrm, nfaces[f * 3]);
            boolean see = part < 0 || partOf[a] == part || (isPaired(part) && partOf[a] == part + 1);
            float l = 0.35f + 0.65f * Math.max(0, view == 0 ? -n[2] : -n[0]);
            tri(rgb, zb, W, H, v3(pos, a), v3(pos, b), v3(pos, c), n, view, lo, hi, sc, shade(0xC89A72, l), see ? 0.28f : 1f, true);
        }
        BufferedImage img = new BufferedImage(W, H, BufferedImage.TYPE_INT_RGB);
        img.setRGB(0, 0, W, H, rgb, 0, W);
        ImageIO.write(img, "png", out);
    }

    static boolean isPaired(int part) { return part == HAND || part == FOREARM || part == UPPERARM || part == THIGH || part == SHIN || part == FOOT; }

    static int shade(int c, float l) {
        int r = Math.min(255, (int) (((c >> 16) & 255) * l)), g = Math.min(255, (int) (((c >> 8) & 255) * l)), b = Math.min(255, (int) ((c & 255) * l));
        return (r << 16) | (g << 8) | b;
    }

    static void tri(int[] rgb, float[] zb, int W, int H, float[] p0, float[] p1, float[] p2, float[] n, int view,
                    float[] lo, float[] hi, float sc, int col, float alpha, boolean cull) {
        // (seen from the front, -z; from the side, -x: the character's left... its right side to us)
        if (cull && (view == 0 ? n[2] > 0.05f : n[0] > 0.05f)) return;
        float[][] P = {p0, p1, p2};
        float[] xs = new float[3], ys = new float[3], zs = new float[3];
        for (int k = 0; k < 3; k++) {
            float sx = view == 0 ? P[k][0] : -P[k][2];
            xs[k] = (sx - lo[0]) * sc;
            ys[k] = (hi[1] - P[k][1]) * sc;
            zs[k] = view == 0 ? P[k][2] : P[k][0];
        }
        float den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2]);
        if (Math.abs(den) < 1e-6) return;
        int xa = Math.max(0, (int) Math.floor(Math.min(xs[0], Math.min(xs[1], xs[2])))), xb = Math.min(W - 1, (int) Math.ceil(Math.max(xs[0], Math.max(xs[1], xs[2]))));
        int ya = Math.max(0, (int) Math.floor(Math.min(ys[0], Math.min(ys[1], ys[2])))), yb = Math.min(H - 1, (int) Math.ceil(Math.max(ys[0], Math.max(ys[1], ys[2]))));
        for (int y = ya; y <= yb; y++) {
            for (int x = xa; x <= xb; x++) {
                float px = x + 0.5f, py = y + 0.5f;
                float w0 = ((ys[1] - ys[2]) * (px - xs[2]) + (xs[2] - xs[1]) * (py - ys[2])) / den;
                float w1 = ((ys[2] - ys[0]) * (px - xs[2]) + (xs[0] - xs[2]) * (py - ys[2])) / den;
                float w2 = 1 - w0 - w1;
                if (w0 < 0 || w1 < 0 || w2 < 0) continue;
                float z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2];
                int i = y * W + x;
                if (z >= zb[i]) continue;
                if (alpha >= 1f) zb[i] = z;
                int d = rgb[i];
                int r = (int) (((col >> 16) & 255) * alpha + ((d >> 16) & 255) * (1 - alpha));
                int g = (int) (((col >> 8) & 255) * alpha + ((d >> 8) & 255) * (1 - alpha));
                int b = (int) ((col & 255) * alpha + (d & 255) * (1 - alpha));
                rgb[i] = (r << 16) | (g << 8) | b;
            }
        }
    }

    // ------------------------------------------------------------------ parsing the body

    static int at;
    static final Pattern NUM = Pattern.compile("-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?");

    static double next() {
        Matcher m = NUM.matcher(src);
        if (!m.find(at)) throw new RuntimeException("no number after " + at);
        at = m.end();
        return Double.parseDouble(m.group());
    }

    static void seek(String key) {
        int i = src.indexOf(key, at);
        if (i < 0) throw new RuntimeException("no " + key);
        at = src.indexOf('{', i) + 1;
    }

    static void parse() {
        meshStart = src.indexOf(" Mesh Body {");
        if (meshStart < 0) throw new RuntimeException("no Mesh Body");
        int depth = 0, i = src.indexOf('{', meshStart);
        for (; i < src.length(); i++) {
            char ch = src.charAt(i);
            if (ch == '{') depth++;
            else if (ch == '}' && --depth == 0) break;
        }
        meshEnd = i + 1;
        while (meshEnd < src.length() && src.charAt(meshEnd) != '\n') meshEnd++;
        meshEnd++;
        at = meshStart;
        seek("Mesh Body");
        int nv = (int) next();
        pos = new float[nv * 3];
        for (int k = 0; k < nv * 3; k++) pos[k] = (float) next();
        int nf = (int) next();
        faces = new int[nf * 3];
        for (int k = 0; k < nf; k++) {
            next();
            for (int j = 0; j < 3; j++) faces[k * 3 + j] = (int) next();
        }
        seek("MeshNormals");
        int nn = (int) next();
        nrm = new float[nn * 3];
        for (int k = 0; k < nn * 3; k++) nrm[k] = (float) next();
        int nfn = (int) next();
        nfaces = new int[nfn * 3];
        for (int k = 0; k < nfn; k++) {
            next();
            for (int j = 0; j < 3; j++) nfaces[k * 3 + j] = (int) next();
        }
        seek("MeshTextureCoords");
        int nt = (int) next();
        uv = new float[nt * 2];
        for (int k = 0; k < nt * 2; k++) uv[k] = (float) next();
        Matcher sw = Pattern.compile("SkinWeights \\{\\s*\"([^\"]+)\";").matcher(src);
        int from = meshStart;
        while (sw.find(from) && sw.start() < meshEnd) {
            String bone = sw.group(1);
            int end = src.indexOf('}', sw.end());
            String block = src.substring(sw.end(), end);
            int mEnd = block.lastIndexOf(";;");
            int mStart = block.lastIndexOf(';', mEnd - 1);
            MATRIX.put(bone, block.substring(mStart + 1, mEnd).trim());
            from = end;
        }
    }

    /** A part's lowest and highest point: {min y, max y}. */
    static float[] partBounds(int part) {
        float lo = Float.MAX_VALUE, hi = -Float.MAX_VALUE;
        for (int i = 0; i < pos.length / 3; i++) if (partOf[i] == part) { lo = Math.min(lo, pos[i * 3 + 1]); hi = Math.max(hi, pos[i * 3 + 1]); }
        return new float[] {lo, hi};
    }

    /** Where a bone stands in the bind pose: the translation of its offset matrix's inverse (.x rows: v' = v M). */
    static float[] joint(String bone) {
        String m = MATRIX.get(bone);
        if (m == null) throw new RuntimeException("no offset for " + bone);
        String[] s = m.split(",");
        double[] a = new double[16];
        for (int i = 0; i < 16; i++) a[i] = Double.parseDouble(s[i].trim());
        double[] inv = invert(a);
        return new float[] {(float) inv[12], (float) inv[13], (float) inv[14]};
    }

    static double[] invert(double[] m) {
        double[] inv = new double[16];
        inv[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10];
        inv[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10];
        inv[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9];
        inv[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9];
        inv[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10];
        inv[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10];
        inv[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9];
        inv[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9];
        inv[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6];
        inv[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6];
        inv[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5];
        inv[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5];
        inv[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6];
        inv[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6];
        inv[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5];
        inv[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5];
        double det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];
        for (int i = 0; i < 16; i++) inv[i] /= det;
        return inv;
    }

    // ------------------------------------------------------------------ small maths

    static float[] alpha(File f) throws Exception {
        BufferedImage img = ImageIO.read(f);
        float[] a = new float[TS * TS];
        for (int y = 0; y < TS; y++) for (int x = 0; x < TS; x++)
            a[y * TS + x] = ((img.getRGB(x * img.getWidth() / TS, y * img.getHeight() / TS) >>> 24) & 255) / 255f;
        return a;
    }

    static int clampi(int x, int lo, int hi) { return Math.max(lo, Math.min(hi, x)); }
    static float[] v(float x, float y, float z) { return new float[] {x, y, z}; }
    static float[] v3(float[] a, int i) { return new float[] {a[i * 3], a[i * 3 + 1], a[i * 3 + 2]}; }
    static float[] add(float[] p, float[] q) { return new float[] {p[0] + q[0], p[1] + q[1], p[2] + q[2]}; }
    static float[] sub(float[] p, float[] q) { return new float[] {p[0] - q[0], p[1] - q[1], p[2] - q[2]}; }
    static float[] scale(float[] p, float k) { return new float[] {p[0] * k, p[1] * k, p[2] * k}; }
    static float[] lerp(float[] p, float[] q, float t) { return new float[] {p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t}; }
    static float dot(float[] p, float[] q) { return p[0] * q[0] + p[1] * q[1] + p[2] * q[2]; }
    static float len(float[] p) { return (float) Math.sqrt(dot(p, p)); }
    static float[] cross(float[] p, float[] q) { return new float[] {p[1] * q[2] - p[2] * q[1], p[2] * q[0] - p[0] * q[2], p[0] * q[1] - p[1] * q[0]}; }
    static float[] normalize(float[] v) {
        float l = len(v);
        return l > 0 ? new float[] {v[0] / l, v[1] / l, v[2] / l} : new float[] {0, 1, 0};
    }
    /** ref with its share along ax taken out (another axis if they are near parallel). */
    static float[] ortho(float[] ref, float[] ax) {
        float[] r = sub(ref, scale(ax, dot(ref, ax)));
        if (len(r) < 1e-3) { float[] alt = Math.abs(ax[1]) < 0.9f ? Y : X; r = sub(alt, scale(ax, dot(alt, ax))); }
        return r;
    }
}
