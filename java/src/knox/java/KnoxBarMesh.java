package knox.java;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;

import org.lwjgl.BufferUtils;
import org.lwjgl.stb.STBImage;

/**
 * What the winter bar's own frame draws, read from its files (the author, 2026-10-31): our
 * generated .x models, another mod's OBJ, the pictures. Nothing of the game in it - the frame
 * runs without the game too (tools\barframe).
 */
public final class KnoxBarMesh {
    // faces meeting at less than this are one smooth surface, where a file has no normals
    private static final float SMOOTH_COS = 0.766f;

    /** x y z, normal, u v of each vertex */
    public final float[] vertices;
    public final int[] indices;

    KnoxBarMesh(float[] vertices, int[] indices) {
        this.vertices = vertices;
        this.indices = indices;
    }

    /** A picture's RGBA, top row first; freed once uploaded. */
    public static final class Picture {
        public final int width;
        public final int height;
        public ByteBuffer pixels;

        Picture(int width, int height, ByteBuffer pixels) {
            this.width = width;
            this.height = height;
            this.pixels = pixels;
        }

        void free() {
            if (pixels != null) STBImage.stbi_image_free(pixels);
            pixels = null;
        }
    }

    public static Picture picture(File file) throws IOException {
        byte[] bytes = Files.readAllBytes(file.toPath());
        ByteBuffer in = BufferUtils.createByteBuffer(bytes.length);
        in.put(bytes).flip();
        int[] w = new int[1], h = new int[1], c = new int[1];
        ByteBuffer pixels = STBImage.stbi_load_from_memory(in, w, h, c, 4);
        if (pixels == null) throw new IOException(file + ": " + STBImage.stbi_failure_reason());
        return new Picture(w[0], h[0], pixels);
    }

    /** A .x file as MenuGen writes it: one mesh, a normal and a uv for each of its vertices. */
    public static KnoxBarMesh readX(File file) throws IOException {
        String[] lines = new String(Files.readAllBytes(file.toPath()), StandardCharsets.US_ASCII).split("\n");
        int at = 0;
        while (at < lines.length && !lines[at].startsWith(" Mesh ")) at++;
        at++;
        int count = parseCount(lines[at++]);
        float[] out = new float[count * 8];
        for (int i = 0; i < count; i++) triple(lines[at++], out, i * 8);
        int faces = parseCount(lines[at++]);
        int[] indices = new int[faces * 3];
        for (int i = 0; i < faces; i++) {
            String l = lines[at++].trim();
            int first = l.indexOf(';');
            String[] ids = l.substring(first + 1, l.indexOf(';', first + 1)).split(",");
            for (int k = 0; k < 3; k++) indices[i * 3 + k] = Integer.parseInt(ids[k].trim());
        }
        while (!lines[at].contains("MeshNormals")) at++;
        at++;
        int normals = parseCount(lines[at++]);
        if (normals != count) throw new IOException(file + ": " + normals + " normals for " + count + " vertices");
        for (int i = 0; i < count; i++) triple(lines[at++], out, i * 8 + 3);
        while (!lines[at].contains("MeshTextureCoords")) at++;
        at += 2;
        for (int i = 0; i < count; i++) {
            String[] p = lines[at++].trim().split(";");
            out[i * 8 + 6] = Float.parseFloat(p[0]);
            out[i * 8 + 7] = Float.parseFloat(p[1]);
        }
        return new KnoxBarMesh(out, indices);
    }

    /**
     * Normals smooth over shallow edges for a mesh whose faces come apart (the drifts, the
     * blanket: facets of a generated surface are not what's meant; sharp edges stay sharp).
     */
    public static KnoxBarMesh smoothed(KnoxBarMesh mesh) {
        float[] v = mesh.vertices;
        int count = v.length / 8;
        int tris = mesh.indices.length / 3;
        float[][] faces = new float[tris][];
        HashMap<Long, ArrayList<Integer>> around = new HashMap<>();
        int[] owner = new int[count];
        Arrays.fill(owner, -1);
        for (int t = 0; t < tris; t++) {
            int a = mesh.indices[t * 3], b = mesh.indices[t * 3 + 1], c = mesh.indices[t * 3 + 2];
            faces[t] = faceNormal(new float[] {v[a * 8], v[a * 8 + 1], v[a * 8 + 2]},
                new float[] {v[b * 8], v[b * 8 + 1], v[b * 8 + 2]}, new float[] {v[c * 8], v[c * 8 + 1], v[c * 8 + 2]});
            for (int k = 0; k < 3; k++) {
                int i = mesh.indices[t * 3 + k];
                around.computeIfAbsent(place(v, i), key -> new ArrayList<>()).add(t);
                owner[i] = t;
            }
        }
        float[] out = v.clone();
        for (int i = 0; i < count; i++) {
            if (owner[i] < 0) continue;
            float[] own = faces[owner[i]];
            float x = 0, y = 0, z = 0;
            for (int other : around.get(place(v, i))) {
                float[] f = faces[other];
                if (f[0] * own[0] + f[1] * own[1] + f[2] * own[2] < SMOOTH_COS) continue;
                x += f[0];
                y += f[1];
                z += f[2];
            }
            float l = (float) Math.sqrt(x * x + y * y + z * z);
            if (l <= 0) continue;
            out[i * 8 + 3] = x / l;
            out[i * 8 + 4] = y / l;
            out[i * 8 + 5] = z / l;
        }
        return new KnoxBarMesh(out, mesh.indices);
    }

    private static long place(float[] v, int i) {
        long x = Math.round(v[i * 8] * 2000f) & 0x1FFFFF, y = Math.round(v[i * 8 + 1] * 2000f) & 0x1FFFFF, z = Math.round(v[i * 8 + 2] * 2000f) & 0x1FFFFF;
        return x << 42 | y << 21 | z;
    }

    private static int parseCount(String line) {
        return Integer.parseInt(line.trim().replace(";", ""));
    }

    private static void triple(String line, float[] out, int at) {
        String[] p = line.trim().split(";");
        out[at] = Float.parseFloat(p[0]);
        out[at + 1] = Float.parseFloat(p[1]);
        out[at + 2] = Float.parseFloat(p[2]);
    }

    /**
     * An OBJ of another mod. Its coordinates are the voxel studio's: y and z change places for
     * the scene's, and the faces their order (KnoxObj had it so, seen in the preview of the
     * game's frame). Files without normals get smooth ones over shallow edges.
     */
    public static KnoxBarMesh readObj(File file) throws IOException {
        ArrayList<float[]> vs = new ArrayList<>();
        ArrayList<float[]> vts = new ArrayList<>();
        ArrayList<float[]> vns = new ArrayList<>();
        ArrayList<int[]> corners = new ArrayList<>();   // v, vt, vn of a triangle's three corners
        try (BufferedReader in = Files.newBufferedReader(file.toPath(), StandardCharsets.ISO_8859_1)) {
            String line;
            while ((line = in.readLine()) != null) {
                if (line.startsWith("v ")) vs.add(floats(line, 3));
                else if (line.startsWith("vt ")) vts.add(floats(line, 2));
                else if (line.startsWith("vn ")) vns.add(floats(line, 3));
                else if (line.startsWith("f ")) face(line, vs.size(), vts.size(), vns.size(), corners);
            }
        }
        if (corners.isEmpty()) throw new IOException(file + ": no faces");
        float[][] smooth = smoothNormals(vs, corners);
        int count = corners.size() * 3;
        float[] out = new float[count * 8];
        int[] indices = new int[count];
        int n = 0;
        for (int t = 0; t < corners.size(); t++) {
            int[] c = corners.get(t);
            for (int k = 2; k >= 0; k--) {
                float[] v = vs.get(c[k * 3]);
                float[] o = c[k * 3 + 2] >= 0 ? vns.get(c[k * 3 + 2]) : smooth[t * 3 + k];
                float[] uv = c[k * 3 + 1] >= 0 ? vts.get(c[k * 3 + 1]) : null;
                int at = n * 8;
                out[at] = v[0];
                out[at + 1] = v[2];
                out[at + 2] = v[1];
                out[at + 3] = o[0];
                out[at + 4] = o[2];
                out[at + 5] = o[1];
                // (OBJ counts v from the picture's bottom)
                out[at + 6] = uv != null ? uv[0] : 0;
                out[at + 7] = uv != null ? 1 - uv[1] : 0;
                indices[n] = n;
                n++;
            }
        }
        return new KnoxBarMesh(out, indices);
    }

    private static float[] floats(String line, int count) {
        String[] parts = line.trim().split("\\s+");
        float[] out = new float[count];
        for (int i = 0; i < count; i++) out[i] = Float.parseFloat(parts[i + 1]);
        return out;
    }

    /** A face as triangles, a fan from its first corner; indices from 0, -1 for none. */
    private static void face(String line, int vs, int vts, int vns, ArrayList<int[]> corners) {
        String[] parts = line.trim().split("\\s+");
        int[] first = corner(parts[1], vs, vts, vns);
        int[] last = corner(parts[2], vs, vts, vns);
        for (int i = 3; i < parts.length; i++) {
            int[] next = corner(parts[i], vs, vts, vns);
            corners.add(new int[] {first[0], first[1], first[2], last[0], last[1], last[2], next[0], next[1], next[2]});
            last = next;
        }
    }

    private static int[] corner(String part, int vs, int vts, int vns) {
        String[] ids = part.split("/", -1);
        return new int[] {index(ids[0], vs),
            ids.length > 1 ? index(ids[1], vts) : -1,
            ids.length > 2 ? index(ids[2], vns) : -1};
    }

    private static int index(String id, int size) {
        if (id.isEmpty()) return -1;
        int i = Integer.parseInt(id);
        return i < 0 ? size + i : i - 1;
    }

    private static float[][] smoothNormals(ArrayList<float[]> vs, ArrayList<int[]> corners) {
        int tris = corners.size();
        float[][] faces = new float[tris][];
        ArrayList<ArrayList<Integer>> around = new ArrayList<>(vs.size());
        for (int i = 0; i < vs.size(); i++) around.add(new ArrayList<>());
        boolean needed = false;
        for (int t = 0; t < tris; t++) {
            int[] c = corners.get(t);
            faces[t] = faceNormal(vs.get(c[0]), vs.get(c[3]), vs.get(c[6]));
            for (int k = 0; k < 3; k++) {
                around.get(c[k * 3]).add(t);
                if (c[k * 3 + 2] < 0) needed = true;
            }
        }
        float[][] out = new float[tris * 3][];
        if (!needed) return out;
        for (int t = 0; t < tris; t++) {
            int[] c = corners.get(t);
            float[] own = faces[t];
            for (int k = 0; k < 3; k++) {
                float x = 0, y = 0, z = 0;
                for (int other : around.get(c[k * 3])) {
                    float[] f = faces[other];
                    if (f[0] * own[0] + f[1] * own[1] + f[2] * own[2] < SMOOTH_COS) continue;
                    x += f[0];
                    y += f[1];
                    z += f[2];
                }
                float l = (float) Math.sqrt(x * x + y * y + z * z);
                out[t * 3 + k] = l > 0 ? new float[] {x / l, y / l, z / l} : own;
            }
        }
        return out;
    }

    private static float[] faceNormal(float[] a, float[] b, float[] c) {
        float ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
        float vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
        float x = uy * vz - uz * vy, y = uz * vx - ux * vz, z = ux * vy - uy * vx;
        float l = (float) Math.sqrt(x * x + y * y + z * z);
        return l > 0 ? new float[] {x / l, y / l, z / l} : new float[] {0, 0, 1};
    }
}
