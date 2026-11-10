# The jacket whose left sleeve can be rolled up: the game's own model (Bob_Jacket.x)
# with the sleeve's last rings put on two bones of their own that nothing else is worn on (the props'),
# bound as the forearm is. Unrolled they ride the forearm as before; KnoxBite.java slides them up it -
# the cuff to the middle of the forearm, the sleeve bunched into a roll above - while the right hand
# pulls (the author 2026-11-01: "look at the arm", the game's jacket rather than our own; the game skins
# each mesh by its own offsets - AnimationPlayer.getSkinTransforms - so a prop bound as the forearm is
# the forearm until moved).
#   python tools/bite/roll_sleeve.py [--preview out.png]
import os
import sys
import numpy as np
from xmesh import XMesh
import smooth_mesh
import slim_arms

# (the plain jacket, tinted: the padded one was bulky, its quilting odd stretched - the author 2026-11-03:
# "менее громоздкой и бордовый цвет", "странная текстура")
GAME = r"C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media/models_X/Skinned/Clothes/Bob_Jacket.x"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "42", "media", "models_X", "Skinned", "Clothes", "Knox_JacketRolled.x")

# the sleeve's rings past the elbow, by their place along it (elbow 0, wrist 1) -> the bone they go on
# (KnoxBite.ROLL_A / ROLL_B have where each one takes them)
RINGS = [  # (from, to, bone)
    (0.55, 0.70, "Bip01_Prop1"),
    (0.90, 1.10, "Bip01_Prop2"),
]
# rolled all the way (k 1): the ring around s0 to s1, s spread by b about it, its width times c
# (the same numbers as KnoxBite.ROLL_A / ROLL_B)
# (a little narrower with the plain jacket on the slimmer arm: the author 2026-11-03, less bulky)
ROLL = {"Bip01_Prop1": (0.62, 0.40, 0.5, 1.32), "Bip01_Prop2": (0.95, 0.47, 1.4, 1.42)}


def axis(m):
    E = m.bind("Bip01_L_Forearm")[:3, 3]
    W = m.bind("Bip01_L_Hand")[:3, 3]
    return E, W - E


def rolled(m, k):
    """The vertices as KnoxBite has them rolled by k (in the mesh's bind space; the check)."""
    E, ax = axis(m)
    L = np.linalg.norm(ax)
    u = ax / L
    p = m.verts.copy()
    out = p.copy()
    for bone, (s0, s1, b, c) in ROLL.items():
        w = m.weights(bone)
        # (by the share of the bone, as the game's skinning blends them)
        for i in np.nonzero(w > 1e-6)[0]:
            d = p[i] - E
            s = d @ u
            side = d - s * u
            s2 = s + k * ((s1 * L + b * (s - s0 * L)) - s)
            out[i] += w[i] * (E + u * s2 + side * (1 + k * (c - 1)) - p[i])
    return out


def build(m):
    E, ax = axis(m)
    L = np.linalg.norm(ax)
    u = ax / L
    fore = m.weights("Bip01_L_Forearm")
    hand = m.weights("Bip01_L_Hand")
    upper = m.weights("Bip01_L_UpperArm")
    off = next(s for s in m.skin if s["bone"] == "Bip01_L_Forearm")["off"]
    new = {}
    for i in np.nonzero(fore + hand > 0.05)[0]:
        if upper[i] > 0.05:
            continue
        s = (m.verts[i] - E) @ u / L
        for lo, hi, bone in RINGS:
            if lo <= s < hi:
                new.setdefault(bone, []).append(i)
    moved = [i for v in new.values() for i in v]
    # off every other bone; the hand keeps a trace (an empty weights block might trip the game's reader)
    for s in m.skin:
        w = m.weights(s["bone"])
        w[moved] = 0
        if s["bone"] == "Bip01_L_Hand":
            w[moved] = 0.001
        m.set_weights(s["bone"], w)
    for bone, idx in new.items():
        m.skin.append({"bone": bone, "idx": sorted(idx), "w": [0.999] * len(idx), "off": list(off), "span": None})
    return moved


def build_round(m, rows):
    """
    The rings on the jacket made round (smooth_mesh.refine). Its new rows between the game's have
    no ring of their own: each is given the share of the rings' moves that lays it, rolled, between
    its neighbours as rolled - the game's rows' (`rows`, elbow 0 .. wrist 1) placed as before, the ones
    between in step. Halves of each ring blended at random turned the cloth inside out at the fold
    (the author's screenshot, 2026-11-02: holes in the jacket).
    """
    E, ax = axis(m)
    L = np.linalg.norm(ax)
    u = ax / L
    def rolled_s(bone, s):
        """Where a ring takes a point of the sleeve, all the way rolled (elbow 0 .. wrist 1)."""
        s0, s1, b, _ = ROLL[bone]
        return s1 + b * (s - s0)

    ma = lambda s: rolled_s("Bip01_Prop1", s)
    mb = lambda s: rolled_s("Bip01_Prop2", s)
    # the game's rows: the last one left (by the elbow), ring A's, ring B's
    lo = max(s for s in rows if s < RINGS[0][0])
    a_lo = min(s for s in rows if RINGS[0][0] <= s < RINGS[0][1])
    a_hi = max(s for s in rows if RINGS[0][0] <= s < RINGS[0][1])
    b_lo = min(s for s in rows if RINGS[1][0] <= s < RINGS[1][1])
    fore = m.weights("Bip01_L_Forearm")
    hand = m.weights("Bip01_L_Hand")
    upper = m.weights("Bip01_L_UpperArm")
    off = next(s for s in m.skin if s["bone"] == "Bip01_L_Forearm")["off"]
    bones = [s["bone"] for s in m.skin]
    W = np.stack([m.weights(b) for b in bones], axis=1)
    A = np.zeros(len(m.verts))
    B = np.zeros(len(m.verts))
    keep = np.ones(len(m.verts))       # the share of the vertex's own weights kept
    # (by the place on the sleeve: past the row left, a trace of the upper arm the new points took
    # from the elbow's doesn't keep them back - they'd stay as their neighbours go)
    for i in np.nonzero(fore + hand > 0.05)[0]:
        s = (m.verts[i] - E) @ u / L
        if s <= lo or s <= 0.5 and upper[i] > fore[i] + hand[i]:
            continue
        if s < a_lo:
            # between the row left and ring A: as far back as the line between them, rolled, says
            want = lo + (s - lo) / (a_lo - lo) * (ma(a_lo) - lo)
            w = (s - want) / (s - ma(s))
            A[i], keep[i] = w, 1 - w
        elif s <= a_hi:
            A[i], keep[i] = 1, 0
        elif s < b_lo:
            want = ma(a_hi) + (s - a_hi) / (b_lo - a_hi) * (mb(b_lo) - ma(a_hi))
            w = (ma(s) - want) / (ma(s) - mb(s))
            A[i], B[i], keep[i] = 1 - w, w, 0
        else:
            B[i], keep[i] = 1, 0
    W *= keep[:, None]
    moved = np.nonzero(keep < 1)[0]
    full = moved[keep[moved] == 0]
    # (the hand keeps a trace on the ones all on the rings: an empty weights block might trip the reader)
    W[full, bones.index("Bip01_L_Hand")] = 0.001
    A[full] *= 0.999
    B[full] *= 0.999
    W = smooth_mesh.prune(np.hstack([W, A[:, None], B[:, None]]))
    for k, b in enumerate(bones):
        m.set_weights(b, W[:, k])
    for k, bone in enumerate(("Bip01_Prop1", "Bip01_Prop2")):
        w = W[:, len(bones) + k]
        idx = np.nonzero(w > 1e-6)[0]
        m.skin.append({"bone": bone, "idx": [int(i) for i in idx], "w": [float(w[i]) for i in idx],
                       "off": list(off), "span": None})
    return moved


def game_rows(m):
    """The sleeve's rows of the game's model, elbow 0 .. wrist 1."""
    E, ax = axis(m)
    L = np.linalg.norm(ax)
    fore = m.weights("Bip01_L_Forearm")
    hand = m.weights("Bip01_L_Hand")
    upper = m.weights("Bip01_L_UpperArm")
    k = (fore + hand > 0.05) & (upper <= 0.05)
    return sorted(set(np.round((m.verts[k] - E) @ (ax / L) / L, 3)))


def jacket():
    """The jacket as written: its sleeves laid over the narrower arms (slim_arms.py), made round (the
    author 2026-11-02: "strange, angular, very bulky"; smooth_mesh.py), its rings set after."""
    m = XMesh(GAME)
    rows = game_rows(m)
    slim_arms.lay_sleeves(m, slim_arms.body(fine=False))
    skin = slim_arms.body()
    slim_arms.cut_chest(m)
    # (the shoulders closed, the elbows on their helpers: the author 2026-11-03, holes at both)
    m.uvs = smooth_mesh.read_uvs(m)
    slim_arms.cap_shoulders(m)
    slim_arms.shoulder_tube(m)
    smooth_mesh.refine(m)
    slim_arms.bend_weights(m)
    slim_arms.shoulder_weights(m)
    moved = build_round(m, rows)
    return m, moved, skin



def grip_table(m, skin):
    """
    How thick the sleeve is where the right hand takes it (KnoxBite.SLEEVE_R): rolled k 0, 1/4 .. 1
    by place on the forearm, wrist 0 .. elbow 1 by tenths - the widest of it, skeleton units, a
    palm's length about that place; the skin's where the sleeve is gone. The hand is put over
    that (the author 2026-11-03: the fingers, then the hand through the sleeve).
    """
    E, ax = axis(m)
    L = np.linalg.norm(ax)
    u = ax / L
    w = sum(m.weights(b) for b in ("Bip01_L_Forearm", "Bip01_L_Hand", "Bip01_Prop1", "Bip01_Prop2", "Bip01_L_UpperArm") + slim_arms.HELPERS["L"])
    sel = w > 0.3
    ds = skin.verts - E
    ss = ds @ u / L
    rsk = np.linalg.norm(ds - np.outer(ds @ u, u), axis=1)
    sk = (skin.verts[:, 0] > 0) & (rsk < 0.09) & (ss < 1.0)
    out = []
    for k in (0, 0.25, 0.5, 0.75, 1.0):
        p = rolled(m, k)
        d = p - E
        s = d @ u / L
        r = np.linalg.norm(d - np.outer(d @ u, u), axis=1)
        row = []
        for gs in np.arange(0, 1.01, 0.1):
            q = sel & (abs(s - (1 - gs)) < 0.12) & (r < 0.09)
            if q.any():
                row.append(r[q].max())
            else:
                q = sk & (abs(ss - (1 - gs)) < 0.12)
                row.append(rsk[q].max())
        out.append(row)
    return out

if __name__ == "__main__":
    m, moved, skin = jacket()
    smooth_mesh.write(m, OUT, "Knox_JacketRolled")
    print("moved", len(moved), "faces", len(m.faces), "->", os.path.normpath(OUT))
    smooth_mesh.write(skin, slim_arms.BODY_OUT, "Knox_NarratorBody")
    print("body ->", os.path.normpath(slim_arms.BODY_OUT))
    # (the rolled check and the table by the game's own points of the skin: its finer ones, between them,
    # find the rolled cuff's very edge sunk in it - as it always was)
    coarse = slim_arms.body(fine=False)
    for side in "LR":
        print("the skin under the cloth by at least", "%.4f" % -slim_arms.poke(m.verts, m.faces, skin, side), side)
    print("the skin under the rolled cloth by at least", "%.4f" % -slim_arms.poke(rolled(m, 1.0), m.faces, coarse, "L", 0.45, 1.5))
    print("KnoxBite.SLEEVE_R = {" + ",\n    ".join(", ".join("%.4ff" % x for x in row) for row in grip_table(m, coarse)) + "};")
    if "--preview" in sys.argv:
        import preview
        preview.sheet(m, rolled, sys.argv[sys.argv.index("--preview") + 1], skin)
