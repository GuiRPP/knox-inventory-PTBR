# A skinned .X mesh of the game made round (the narrator's jacket - the author 2026-11-02: "strange,
# angular, very bulky"). Each triangle split in four, the new points on the edges bowed out as the
# surface curves there (PN triangles: the edge's cubic from the two ends' normals), twice; the old
# points stay where they were, and a new one is never drawn in - in a hollow it stays on the old
# face: the surface only rounds out, never sinks into the body under it. UVs and skin weights between the ends; the seams' twins (the same place, other UVs) get the
# same place, so nothing cracks. Then the whole Mesh block written anew (XMesh.write edits it in place).
import re
import numpy as np

NUM = r"-?\d+(?:\.\d+)?(?:e-?\d+)?"
MAX_BONES = 4   # a vertex's bones at most (the game's skinning)


def read_uvs(m):
    t = m.text
    i = t.index("MeshTextureCoords", m.mesh_at)
    j = t.index("\n", i) + 1
    n = int(re.match(r"\s*(\d+);", t[j:]).group(1))
    p = t.index("\n", j) + 1
    rows = []
    for _ in range(n):
        e = t.index("\n", p)
        rows.append([float(x) for x in re.findall(NUM, t[p:e])[:2]])
        p = e + 1
    return np.array(rows)


def weld(p):
    keys = {}
    g = np.zeros(len(p), int)
    for i, v in enumerate(np.round(p, 5)):
        g[i] = keys.setdefault(tuple(v), len(keys))
    return g, len(keys)


def smooth_normals(p, faces, g, ng):
    fn = np.cross(p[faces[:, 1]] - p[faces[:, 0]], p[faces[:, 2]] - p[faces[:, 0]])   # (area-weighted)
    acc = np.zeros((ng, 3))
    for k in range(3):
        np.add.at(acc, g[faces[:, k]], fn)
    acc /= np.linalg.norm(acc, axis=1)[:, None] + 1e-12
    return acc


def split(p, uv, w, faces, flat=False):
    g, ng = weld(p)
    nrm = smooth_normals(p, faces, g, ng)
    mids = {}
    P, UV, Wt = list(p), list(uv), list(w)

    def mid(a, b):
        key = (a, b) if a < b else (b, a)
        if key in mids:
            return mids[key]
        pa, pb = p[a], p[b]
        na, nb = nrm[g[a]], nrm[g[b]]
        bow = -(np.dot(pb - pa, na) * na + np.dot(pa - pb, nb) * nb) / 8
        # (outwards only: in a hollow it stays on the old face - never into the body under it)
        if flat or np.dot(bow, na + nb) < 0:
            bow = 0 * bow
        q = (pa + pb) / 2 + bow
        P.append(q)
        UV.append((uv[a] + uv[b]) / 2)
        Wt.append((w[a] + w[b]) / 2)
        mids[key] = len(P) - 1
        return mids[key]

    out = []
    for a, b, c in faces:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        out += [(a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)]
    return np.array(P), np.array(UV), np.array(Wt), np.array(out)


def prune(w):
    """At most MAX_BONES bones a vertex, the rest given to them."""
    for i in range(len(w)):
        nz = np.nonzero(w[i] > 0)[0]
        if len(nz) > MAX_BONES:
            keep = nz[np.argsort(-w[i, nz])[:MAX_BONES]]
            s = w[i].sum()
            row = np.zeros_like(w[i])
            row[keep] = w[i, keep]
            w[i] = row * (s / row.sum())
    return w


def refine(m, levels=2, flat=False):
    """m (an XMesh) made round in place: verts, normals, faces, uvs, skin weights. `flat`: only
    finer, its shape as it was (the narrator's body: its points as many as the jacket's over it, so the
    two bend alike - slim_arms.bend_weights)."""
    # (its own uvs when it has them: points added - slim_arms.cap_shoulders)
    uv = m.uvs if getattr(m, "uvs", None) is not None else read_uvs(m)
    bones = [s["bone"] for s in m.skin]
    w = np.stack([m.weights(b) for b in bones], axis=1)
    p, f = m.verts, m.faces
    for _ in range(levels):
        p, uv, w, f = split(p, uv, w, f, flat)
    w = prune(w)
    g, ng = weld(p)
    m.verts, m.faces, m.uvs = p, f, uv
    m.normals = smooth_normals(p, f, g, ng)[g]
    for k, s in enumerate(m.skin):
        idx = np.nonzero(w[:, k] > 1e-6)[0]
        s["idx"], s["w"] = [int(i) for i in idx], [float(x) for x in w[idx, k]]
    return m


def write(m, path, name):
    """The mesh written whole: its Mesh block made anew, the rest of the file as the game's."""
    t = m.text
    start = t.rindex("\n", 0, m.mesh_at - 1) + 1          # the "Mesh <name> {" line
    old_name = re.match(r"\s*Mesh (\w+)", t[start:]).group(1)
    last = list(re.finditer(r'SkinWeights \{\s*"\w+";', t))[-1]
    end = t.index("\n }", t.index("}", last.end())) + 3   # past the Mesh block's own "}"
    material = re.search(r"MeshMaterialList \{.*?(\{ [^}]+ \})", t[start:end], re.S).group(1)

    def rows(vals, fmt, ind="  "):
        return "".join(ind + fmt(v) + (";;\n" if i == len(vals) - 1 else ";,\n") for i, v in enumerate(vals))

    v3 = lambda v: "%.6f;%.6f;%.6f" % tuple(v)
    fc = lambda f: "3;%d,%d,%d" % tuple(f)
    o = [" Mesh %s {\n" % name, "  %d;\n" % len(m.verts), rows(m.verts, v3), "  %d;\n" % len(m.faces), rows(m.faces, fc)]
    o += ["\n  MeshNormals {\n", "   %d;\n" % len(m.normals), rows(m.normals, v3, "   "),
          "   %d;\n" % len(m.faces), rows(m.faces, fc, "   "), "  }\n"]
    o += ["\n  MeshMaterialList {\n   1;\n   %d;\n" % len(m.faces)]
    o += ["   0%s\n" % (";" if i == len(m.faces) - 1 else ",") for i in range(len(m.faces))]
    o += ["   %s\n  }\n" % material]
    o += ["\n  MeshTextureCoords c1 {\n", "   %d;\n" % len(m.uvs), rows(m.uvs, lambda v: "%.6f;%.6f" % tuple(v), "   "), "  }\n"]
    kept = [s for s in m.skin if s["idx"]]
    per_vertex = np.zeros(len(m.verts), int)
    owner = [set() for _ in range(len(m.verts))]
    for k, s in enumerate(kept):
        per_vertex[s["idx"]] += 1
        for i in s["idx"]:
            owner[i].add(k)
    per_face = max(len(owner[a] | owner[b] | owner[c]) for a, b, c in m.faces)
    o += ["\n  XSkinMeshHeader {\n   %d;\n   %d;\n   %d;\n  }\n" % (per_vertex.max(), per_face, len(kept))]
    for s in kept:
        n = len(s["idx"])
        o.append('\n  SkinWeights {\n   "%s";\n   %d;\n' % (s["bone"], n))
        o += ["   %d%s\n" % (i, ";" if k == n - 1 else ",") for k, i in enumerate(s["idx"])]
        o += ["   %.6f%s\n" % (x, ";" if k == n - 1 else ",") for k, x in enumerate(s["w"])]
        o.append("   " + ",".join("%.6f" % x for x in s["off"]) + ";;\n  }\n")
    o.append(" }")
    out = t[:start] + "".join(o) + t[end:]
    out = re.sub(r"(Frame |Mesh )" + old_name + r"\b", r"\g<1>" + name, out)
    open(path, "w", encoding="latin-1", newline="\r\n" if m.crlf else "\n").write(out)
