# A skinned .X mesh of the game (text), read and written back with its vertices and weights
# changed (tools/bite/roll_sleeve.py; the bar's narrator, 2026-11-02).
import re
import numpy as np

NUM = r"-?\d+(?:\.\d+)?(?:e-?\d+)?"


class XMesh:
    def __init__(self, path):
        self.text = open(path, encoding="latin-1").read()
        self.crlf = b"\r\n" in open(path, "rb").read(4096)
        t = self.text
        m = re.search(r"\n( *)Mesh (\w+) \{\s*\n", t)
        self.mesh_at = m.end()
        n = int(re.match(r"\s*(\d+);", t[self.mesh_at:]).group(1))
        # the vertex lines: "x;y;z;," each
        lines_at = t.index("\n", self.mesh_at) + 1
        self.v_span = (lines_at, lines_at)
        rows, pos = [], lines_at
        for _ in range(n):
            e = t.index("\n", pos)
            rows.append([float(x) for x in re.findall(NUM, t[pos:e])[:3]])
            pos = e + 1
        self.v_span = (lines_at, pos)
        self.verts = np.array(rows)
        # the normals likewise
        nm = t.index("MeshNormals {", pos)
        nl = t.index("\n", t.index("\n", nm) + 1) + 1
        rows, p2 = [], nl
        for _ in range(n):
            e = t.index("\n", p2)
            rows.append([float(x) for x in re.findall(NUM, t[p2:e])[:3]])
            p2 = e + 1
        self.n_span = (nl, p2)
        self.normals = np.array(rows)
        # faces (for checks)
        fs = re.findall(r"3;(\d+),(\d+),(\d+);", t[pos:nm])
        self.faces = np.array([[int(a), int(b), int(c)] for a, b, c in fs])
        # skin weights
        self.skin = []
        for m in re.finditer(r'SkinWeights \{\s*"(\w+)";\s*(\d+);(.*?)\}', t, re.S):
            c = int(m.group(2))
            v = re.findall(NUM, m.group(3))
            idx = [int(x) for x in v[:c]]
            w = [float(x) for x in v[c:2 * c]]
            o = [float(x) for x in v[2 * c:2 * c + 16]]
            self.skin.append({"bone": m.group(1), "idx": idx, "w": w, "off": o, "span": (m.start(), m.end())})

    def bind(self, bone):
        """The bone's place and axes in the mesh's space at bind (its offset is the inverse)."""
        s = next(s for s in self.skin if s["bone"] == bone)
        o = s["off"]
        off = np.array([[o[j * 4 + i] for j in range(4)] for i in range(4)])   # column vectors
        return np.linalg.inv(off)

    def weights(self, bone):
        s = next((s for s in self.skin if s["bone"] == bone), None)
        out = np.zeros(len(self.verts))
        if s:
            out[s["idx"]] = s["w"]
        return out

    def set_weights(self, bone, w):
        s = next(s for s in self.skin if s["bone"] == bone)
        keep = [i for i in range(len(w)) if w[i] > 1e-6]
        s["idx"], s["w"] = keep, [float(w[i]) for i in keep]

    def write(self, path, name=None):
        t = self.text
        parts, last = [], 0
        def block(rows, fmt):
            out = []
            for i, r in enumerate(rows):
                end = ";;\n" if i == len(rows) - 1 else ";,\n"
                out.append("   " + ";".join(fmt % x for x in r) + end)
            return "".join(out)
        edits = [(self.v_span, block(self.verts, "%.6f")), (self.n_span, block(self.normals, "%.6f"))]
        # (new bones' blocks after the last old one; a bone left with no weights dropped)
        tail = max(s["span"][1] for s in self.skin if s["span"])
        kept = [s for s in self.skin if s["idx"]]
        for s in self.skin:
            if not s["idx"]:
                edits.append((s["span"], ""))
                continue
            body = ['SkinWeights {\n   "%s";\n   %d;\n' % (s["bone"], len(s["idx"]))]
            body.append("".join("   %d%s\n" % (i, ";" if k == len(s["idx"]) - 1 else ",") for k, i in enumerate(s["idx"])))
            body.append("".join("   %.6f%s\n" % (w, ";" if k == len(s["w"]) - 1 else ",") for k, w in enumerate(s["w"])))
            body.append("   " + ",".join("%.6f" % x for x in s["off"]) + ";;\n  }")
            if s["span"]:
                edits.append((s["span"], "".join(body)))
            else:
                edits.append(((tail, tail), "\n\n  " + "".join(body)))
        # the header's count of bones
        h = re.search(r"XSkinMeshHeader \{\s*(\d+);\s*(\d+);\s*(\d+);", t)
        edits.append(((h.start(3), h.end(3)), str(len(kept))))
        edits.sort(key=lambda e: e[0])
        for (a, b), new in edits:
            parts.append(t[last:a])
            parts.append(new)
            last = b
        parts.append(t[last:])
        out = "".join(parts)
        if name:
            out = re.sub(r"(Frame |Mesh )Bob_JacketPaddedDOWN", r"\g<1>" + name, out)
        # (the game's files end their lines the Windows way; kept)
        open(path, "w", encoding="latin-1", newline="\r\n" if self.crlf else "\n").write(out)
