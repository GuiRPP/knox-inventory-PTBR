# The narrator's arms made slimmer (the author 2026-11-03: "руки менее громоздкие, а в особенности -
# кисти"): the game's body has arms near as thick as they are long (the forearm 0.08 across, 0.137
# long), and this near the eye they fill the view. Done on the meshes at bind, not on the bones -
# narrowed bones went odd at the elbows (2026-11-02): each point of an arm drawn in towards the arm's
# own line, the shoulder and the hand left as they are (the hands are made smaller by their bones in
# KnoxBite). The body (Knox_NarratorBody, worn by the narrator only - KnoxBite.knoxBiteDress) and the
# jacket over it (roll_sleeve.py) the same way; the jacket's sleeves then laid evenly over the arm: never
# nearer it than the cloth's thickness, no narrower towards the shoulder than further down it (the
# author 2026-11-03: "сужается посередине руки"), a little of the game's folds kept.
#   python slim_arms.py            (writes the body)
import os
import numpy as np
from xmesh import XMesh
import smooth_mesh

GAME = r"C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media/models_X/Skinned/"
HERE = os.path.dirname(os.path.abspath(__file__))
BODY_OUT = os.path.join(HERE, "..", "..", "42", "media", "models_X", "Skinned", "Knox_NarratorBody.x")

SLIM = 0.74          # the arm's width at most, of the game's
MARGIN = 0.004       # the sleeve over the skin at least (skeleton units: the cloth)
FOLDS = 0.45         # of the sleeve's own width over that, kept


def smoothstep(a, b, x):
    k = np.clip((x - a) / (b - a), 0.0, 1.0)
    return k * k * (3 - 2 * k)


def chain(m, side):
    return [m.bind("Bip01_%s_%s" % (side, b))[:3, 3] for b in ("UpperArm", "Forearm", "Hand")]


def place(p, U, E, W):
    """Points along the arm: t (shoulder 0, elbow 1, wrist 2), the point on its line, the way out, r."""
    out_t = np.zeros(len(p))
    foot = np.zeros_like(p)
    for k, (a, b, t0) in enumerate(((U, E, 0.0), (E, W, 1.0))):
        ax = b - a
        L = np.linalg.norm(ax)
        s = np.clip((p - a) @ ax / L / L, -0.3 if k == 0 else 0.0, 1.0 if k == 0 else 1.3)
        f = a + np.outer(s, ax)
        d = np.linalg.norm(p - f, axis=1)
        if k == 0:
            best, out_t, foot = d, t0 + s, f
        else:
            take = d < best
            # (past the elbow along the forearm's line, before it along the upper arm's)
            take |= (p - E) @ (W - E) > 0
            take &= (p - E) @ (W - E) > -0.02
            out_t = np.where(take, t0 + s, out_t)
            foot = np.where(take[:, None], f, foot)
    rad = p - foot
    r = np.linalg.norm(rad, axis=1)
    return out_t, foot, rad / (r[:, None] + 1e-12), r


def angle(m, side, t, rad):
    """The way out round the arm as an angle (about the segment's own line, from straight up)."""
    U, E, W = chain(m, side)
    up = np.array([0.0, 1.0, 0.0])
    th = np.zeros(len(t))
    for a, b, sel in ((U, E, t < 1.0), (E, W, t >= 1.0)):
        u = (b - a) / np.linalg.norm(b - a)
        x = up - u * (up @ u)
        x /= np.linalg.norm(x)
        y = np.cross(u, x)
        th[sel] = np.arctan2(rad[sel] @ y, rad[sel] @ x)
    return th


def slim_factor(t):
    """How much of its width a point keeps: all at the shoulder and on the hand."""
    return 1 - (1 - SLIM) * smoothstep(0.12, 0.45, t) * (1 - smoothstep(1.96, 2.06, t))


def arm_points(m, side, least=0.3):
    # (the elbow's helpers too, once they are the elbow's - bend_weights; the game's body has its dress on them)
    on = ["Bip01_%s_%s" % (side, b) for b in ("UpperArm", "Forearm", "Hand")]
    w = sum(m.weights(b) for b in on + (list(HELPERS[side]) if getattr(m, "elbows", False) else []))
    return np.nonzero(w >= least)[0]


def slim(m, side, idx=None):
    """m's arm drawn in (in place). Returns the points' t."""
    U, E, W = chain(m, side)
    idx = arm_points(m, side) if idx is None else idx
    t, foot, rad, r = place(m.verts[idx], U, E, W)
    keep = t < 2.06
    idx, t, foot, rad, r = idx[keep], t[keep], foot[keep], rad[keep], r[keep]
    m.verts[idx] = foot + rad * (r * slim_factor(t))[:, None]
    return idx


def envelope(body, side):
    """The skin's reach round the arm, (t, angle) -> r: the widest of the skin near there and anywhere
    further down the arm (so a sleeve over it never narrows towards the shoulder)."""
    U, E, W = chain(body, side)
    idx = arm_points(body, side, 0.05)
    t, foot, rad, r = place(body.verts[idx], U, E, W)
    th = angle(body, side, t, rad)
    T = np.arange(0.0, 2.1, 0.05)
    A = np.radians(np.arange(-180, 180, 15))
    grid = np.zeros((len(T), len(A)))
    for i, t0 in enumerate(T):
        near_t = np.abs(t - t0) < 0.09
        for j, a0 in enumerate(A):
            da = np.abs((th - a0 + np.pi) % (2 * np.pi) - np.pi)
            k = near_t & (da < np.radians(50))
            grid[i, j] = r[k].max() if k.any() else 0.0
    # (round the arm: a gap filled from its sides)
    for i in range(len(T)):
        row = grid[i]
        if (row == 0).any() and (row > 0).any():
            row[row == 0] = row[row > 0].min()
    # down the arm (to the wrist, not the hand): the widest further on
    stop = np.searchsorted(T, 1.97)
    for i in range(stop - 1, -1, -1):
        grid[i] = np.maximum(grid[i], grid[i + 1])
    return T, A, grid


def env_at(env, t, th):
    T, A, grid = env
    ti = np.clip(np.interp(t, T, np.arange(len(T))), 0, len(T) - 1)
    aa = (th + np.pi) / (2 * np.pi) * len(A) - 0.5
    i0 = np.floor(ti).astype(int)
    i1 = np.minimum(i0 + 1, len(T) - 1)
    ft = ti - i0
    a0 = np.floor(aa).astype(int)
    fa = aa - a0
    a0 %= len(A)
    a1 = (a0 + 1) % len(A)
    g = lambda i, a: grid[i, a]
    return ((g(i0, a0) * (1 - fa) + g(i0, a1) * fa) * (1 - ft) + (g(i1, a0) * (1 - fa) + g(i1, a1) * fa) * ft)


# His chest, neck and head are drawn at a hundredth of their size (KnoxBite.HIDDEN: the camera is
# where his head was): Bip01_Spine1 and all on it but the collarbones, put back where they were.
HIDDEN = ("Bip01_Spine1", "Bip01_Neck", "Bip01_Head", "Bip01_BackPack")


def cut_chest(m, shoulders=True):
    """
    What goes to the hidden chest taken off (in place): a point shared with a collarbone or an arm
    rides that alone; the faces with a point still on the chest are dropped - drawn, they ran from
    the shoulder to the chest's speck, long light wedges at the bottom of the view (the T-shirt's and
    the jacket's: the author 2026-11-03, "странная текстура"). `shoulders` False: the shared points
    go too (the body under the jacket: its shoulders' rim never out past the jacket's).
    """
    bones = [s["bone"] for s in m.skin]
    W = np.stack([m.weights(b) for b in bones], axis=1)
    hid = np.array([b in HIDDEN for b in bones])
    x = m.verts[:, 0]
    for side, sign in ((("L", 1), ("R", -1)) if shoulders else ()):
        mine = np.array([b.startswith("Bip01_%s_" % side) and ("Clavicle" in b or "Arm" in b) for b in bones])
        clav = bones.index("Bip01_%s_Clavicle" % side) if "Bip01_%s_Clavicle" % side in bones else None
        if clav is None:
            continue
        on = (W[:, mine].sum(1) > 0) & (W[:, hid].sum(1) > 0) & (np.sign(x) == sign)
        W[on, clav] += W[on][:, hid].sum(1)
        W[np.ix_(on, hid)] = 0
    for k, b in enumerate(bones):
        m.set_weights(b, W[:, k])
    gone = W[:, hid].sum(1) > 1e-6
    keep = ~gone[m.faces].any(1)
    m.faces = m.faces[keep]
    return int((~keep).sum())


def loops(m):
    """The mesh's open rims: lists of vertices (one of each welded place), in the faces' order."""
    g, ng = smooth_mesh.weld(m.verts)
    F = g[m.faces]
    count, nxt = {}, {}
    for a, b, c in F:
        for u, v in ((a, b), (b, c), (c, a)):
            k = (min(u, v), max(u, v))
            count[k] = count.get(k, 0) + 1
    for a, b, c in F:
        for u, v in ((a, b), (b, c), (c, a)):
            if count[(min(u, v), max(u, v))] == 1:
                nxt[u] = v
    rep = {}
    for i, k in enumerate(g):
        rep.setdefault(k, i)
    seen, out = set(), []
    for s in nxt:
        if s in seen:
            continue
        ring, c = [s], nxt[s]
        seen.add(s)
        while c != s and c in nxt and c not in seen:
            ring.append(c)
            seen.add(c)
            c = nxt[c]
        out.append([rep[x] for x in ring])
    return out


DOME = 0.35          # how far a shoulder's cap rises to the middle of him, of its rim's radius


def cap_shoulders(m):
    """
    The jacket's shoulders closed (in place; before smooth_mesh.refine rounds them): cut from the
    chest, each sleeve's top was an open ring - the camera, over where his chest was, looked into it
    and through the sleeve's inside, drawn from one side only, at the bar behind (the author's
    screenshots 2026-11-03: "плечи обрезаны, имеют какие-то дыры"). A low dome of cloth over each
    ring, rising towards his middle; skinned as the ring is, of one place in the texture (the
    cloth's plain colour).
    """
    bones = [s["bone"] for s in m.skin]
    W = np.stack([m.weights(b) for b in bones], axis=1)
    V, N, UV, F = list(m.verts), list(m.normals), list(m.uvs), [tuple(f) for f in m.faces]
    done = 0
    for ring in loops(m):
        p = m.verts[ring]
        c = p.mean(0)
        if abs(c[0]) >= 0.03 and c[1] >= 0.65:
            inward = np.array([-np.sign(c[0]), 0.0, 0.0])
        elif abs(c[0]) < 0.03 and 0.45 < c[1] < 0.65:
            # (its waist's top too: bending to the arm, the camera looked down into it)
            inward = np.array([0.0, 1.0, 0.0])
        else:
            continue          # (the hem, the cuffs: open as the game's)
        r = np.linalg.norm(p - c, axis=1).mean()
        uv = m.uvs[ring[0]]
        w = W[ring].mean(0)
        base = len(V)
        n = len(ring)
        # the rim again (its own copies: the cap's place in the texture), a ring halfway in, the top
        for q in p:
            V.append(q)
        for q in p:
            V.append(c + 0.6 * (q - c) + inward * DOME * r * 0.7)
        V.append(c + inward * DOME * r)
        for _ in range(2 * n + 1):
            N.append(inward)
            UV.append(uv)
        # (the rim's copies skinned each as its own point - else, bent, the cap came off the sleeve)
        W = np.vstack([W, W[ring], np.repeat(w[None], n + 1, 0)])
        top = base + 2 * n
        for i in range(n):
            j = (i + 1) % n
            # (the rim's edges the other way round from the sleeve's own faces: the cap faces out)
            a0, a1, b0, b1 = base + i, base + j, base + n + i, base + n + j
            F += [(a1, a0, b0), (a1, b0, b1), (b1, b0, top)]
        done += 1
    m.verts, m.normals, m.uvs, m.faces = np.array(V), np.array(N), np.array(UV), np.array(F)
    for k, s in enumerate(m.skin):
        idx = np.nonzero(W[:, k] > 1e-6)[0]
        s["idx"], s["w"] = [int(i) for i in idx], [float(x) for x in W[idx, k]]
    return done


# The elbows (the author 2026-11-03: "куртка до сих пор сужается в районе локтя, плюс имеет дыры"):
# the left forearm turns about itself up to 170 degrees as he looks at it, and the game blends a point
# at the elbow between the upper arm and the forearm - two turns that far apart, the blend drew the
# elbow in to near nothing, and the skin and the cloth, blended each its own way, went through each
# other. The left arm: four bones more between the upper arm and the forearm (the dress's bones,
# nothing of his wears them; KnoxBite.elbows poses them), each a step further - the elbow's bend over
# the first three, by the elbow, the forearm's turn about itself over all of them, down to the middle
# of the forearm, as a forearm turns (all at the elbow, the cloth went round it in sharp twists). The
# right one hardly turns: as the game's, but the skin and the jacket blended alike. Both by the place
# along the arm alone, the same for the skin and the jacket: they go as one.
HELPERS = {"L": ("Bip01_DressFront", "Bip01_DressFront02", "Bip01_DressBack", "Bip01_DressBack02"), "R": ()}
SWING_SHARE = (1 / 3, 2 / 3, 1.0, 1.0)     # of the bend from the upper arm (KnoxBite.SWING_SHARE)
TWIST_SHARE = (0.2, 0.4, 0.6, 0.8)         # of the forearm's turn about itself (KnoxBite.TWIST_SHARE)
ELBOW = {"L": (0.80, 1.50), "R": (0.82, 1.18)}   # t: all the upper arm's .. all the forearm's
ELBOW_FADE = 0.14                          # the arm's own blend kept, going over to that, before and after


def rot_pow(R, k):
    """R (a turn) by k of its angle about its own axis."""
    c = np.clip((np.trace(R) - 1) / 2, -1.0, 1.0)
    ang = np.arccos(c)
    if ang < 1e-7:
        return np.eye(3)
    ax = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]]) / (2 * np.sin(ang))
    ax /= np.linalg.norm(ax)
    a = k * ang
    K = np.array([[0, -ax[2], ax[1]], [ax[2], 0, -ax[0]], [-ax[1], ax[0], 0]])
    return np.eye(3) + np.sin(a) * K + (1 - np.cos(a)) * K @ K


def helper_bind(m, side, k):
    """Where the elbow's k-th helper is at bind: the forearm's place, its share of the forearm's turn
    from the upper arm's (both as the mesh has them; at bind nothing is turned about itself)."""
    U = m.bind("Bip01_%s_UpperArm" % side)
    F = m.bind("Bip01_%s_Forearm" % side)
    B = np.eye(4)
    B[:3, :3] = U[:3, :3] @ rot_pow(U[:3, :3].T @ F[:3, :3], SWING_SHARE[k])
    B[:3, 3] = F[:3, 3]
    return B


def off_of(B):
    """A bone's skin offset (as the .X has it) from its place at bind."""
    return [float(x) for x in np.linalg.inv(B).T.flatten()]


def bend_weights(m):
    """The elbows' points put on the upper arm, the helpers and the forearm by their place along the
    arm alone (in place) - the same for the body and the jacket."""
    names = [s["bone"] for s in m.skin]
    pelvis = m.weights("Bip01_Pelvis")
    for side, hs in HELPERS.items():
        for k, h in enumerate(hs):
            off = off_of(helper_bind(m, side, k))
            if h in names:
                # (the body's own dress weights, by its hips, to the pelvis: the bones are the elbow's now)
                pelvis += m.weights(h)
                m.set_weights(h, np.zeros(len(m.verts)))
                next(s for s in m.skin if s["bone"] == h)["off"] = off
            else:
                m.skin.append({"bone": h, "idx": [], "w": [], "off": off, "span": None})
    if pelvis.any():
        m.set_weights("Bip01_Pelvis", pelvis)
    m.elbows = True
    bones = [s["bone"] for s in m.skin]
    W = np.stack([m.weights(b) for b in bones], axis=1)
    for side, hs in HELPERS.items():
        U, E, Wr = chain(m, side)
        idx = arm_points(m, side, 0.05)
        idx = idx[np.sign(m.verts[idx, 0]) == (1 if side == "L" else -1)]
        t, _, _, _ = place(m.verts[idx], U, E, Wr)
        on = ("Bip01_%s_UpperArm" % side,) + hs + ("Bip01_%s_Forearm" % side,)
        a, b = ELBOW[side]
        at = np.linspace(a, b, len(on))
        new = np.zeros((len(idx), len(on)))
        for k in range(len(on)):
            # (each bone all its own at its place, none at its neighbours')
            xs = [at[k - 1] if k else at[k] - 1, at[k], at[k + 1] if k + 1 < len(on) else at[k] + 1]
            new[:, k] = np.interp(t, xs, [0 if k else 1, 1, 0 if k + 1 < len(on) else 1])
        s = np.interp(t, [a - ELBOW_FADE, a, b, b + ELBOW_FADE], [0, 1, 1, 0])[:, None]
        cols = [bones.index(n) for n in on]
        Wn = W[idx] * (1 - s)
        Wn[:, cols] += new * s
        W[idx] = Wn
    W = smooth_mesh.prune(W)
    for k, sk in enumerate(m.skin):
        nz = np.nonzero(W[:, k] > 1e-6)[0]
        sk["idx"], sk["w"] = [int(i) for i in nz], [float(W[i, k]) for i in nz]


# The shoulders (the author's video 2026-11-04: "плечи ... не двигаются вместе с руками"): with the chest
# gone nothing ties a sleeve's top to him, and on the collarbone it stayed behind in a lump as the arm
# swung out of it, creased (and folded in at the armpit, through the skin: a hole, 2026-11-03). The
# whole sleeve's top, its cap too, goes with the upper arm; the collarbone moves it (KnoxBite.shoulder).


def shoulder_weights(m):
    """The shoulders' points (only the collarbone's and the upper arm's) all put on the upper arm (in place)."""
    bones = [s["bone"] for s in m.skin]
    W = np.stack([m.weights(b) for b in bones], axis=1)
    for side in ("L", "R"):
        c, u = bones.index("Bip01_%s_Clavicle" % side), bones.index("Bip01_%s_UpperArm" % side)
        on = W[:, c] + W[:, u]
        idx = np.nonzero((on >= 0.99) & (W[:, c] > 0))[0]
        W[idx] = 0
        W[idx, u] = 1
    for k, sk in enumerate(m.skin):
        nz = np.nonzero(W[:, k] > 1e-6)[0]
        sk["idx"], sk["w"] = [int(i) for i in nz], [float(W[i, k]) for i in nz]


# No shoulders in the picture at all (the author 2026-11-04: "вообще не нравятся как выглядят плечи ...
# чтобы их было не видно"): the sleeve's top drawn out past the joint as a plain tube, no wider than the
# arm below it, the upper arm itself swung about the elbow out of the view (KnoxBite.openElbow).
TUBE_FROM = 0.45     # t: the sleeve as it is below this
TUBE_END = -1.3      # t: where its top (s = -0.3 of it) goes


def shoulder_tube(m):
    """The sleeves' tops, caps too, drawn out along the upper arm and in to its width (in place)."""
    for side, sign in (("L", 1), ("R", -1)):
        U, E, Wr = chain(m, side)
        L = np.linalg.norm(E - U)
        u = (E - U) / L
        on = m.weights("Bip01_%s_UpperArm" % side) + m.weights("Bip01_%s_Clavicle" % side)
        mine = (on >= 0.99) & (np.sign(m.verts[:, 0]) == sign)
        d0 = m.verts - U
        s0 = d0 @ u / L
        # (the sleeve's width just below, whichever way round)
        q = mine & (np.abs(s0 - TUBE_FROM) < 0.2)
        most = np.linalg.norm(d0[q] - np.outer(d0[q] @ u, u), axis=1).max()
        idx = np.nonzero(mine & (s0 < TUBE_FROM))[0]
        d, s = d0[idx], s0[idx]
        rad = d - np.outer(d @ u, u)
        r = np.linalg.norm(rad, axis=1)
        k = smoothstep(TUBE_FROM, TUBE_FROM - 0.35, s)
        r2 = r * (1 - k) + np.minimum(r, most) * k
        s2 = TUBE_FROM - (TUBE_FROM - s) * (TUBE_FROM - TUBE_END) / (TUBE_FROM + 0.3)
        m.verts[idx] = U + np.outer(s2 * L, u) + rad * (r2 / (r + 1e-9))[:, None]


UNDER_SLEEVE = 0.5    # t: the body's upper arm cut away above this - always under the sleeve


def cut_upper_arms(m):
    """
    The body's upper arms taken off from the shoulder down to their middle (in place): never seen,
    always under the jacket's sleeve - and with the arm down before him the cloth folds in at the
    armpit, and the skin there came out through it (the author's screenshot 2026-11-03: a hole by the
    left elbow).
    """
    drop = np.zeros(len(m.verts), bool)
    for side, sign in (("L", 1), ("R", -1)):
        U, E, W = chain(m, side)
        arm = sum(m.weights("Bip01_%s_%s" % (side, b)) for b in ("Clavicle", "UpperArm"))
        t, _, _, _ = place(m.verts, U, E, W)
        drop |= (np.sign(m.verts[:, 0]) == sign) & (arm >= 0.5) & (t < UNDER_SLEEVE)
    keep = ~drop[m.faces].any(1)
    m.faces = m.faces[keep]
    return int((~keep).sum())


WAIST_TOP = 0.515    # the body's waist kept below the jacket's (cut at 0.527), under its cap


def cut_waist(m):
    """The body's waist cut below the jacket's top (in place): it stood a little out of it, open."""
    arm = sum(m.weights(b) for b in ("Bip01_L_Clavicle", "Bip01_R_Clavicle", "Bip01_L_UpperArm", "Bip01_R_UpperArm"))
    high = (m.verts[:, 1] > WAIST_TOP) & (arm < 0.5)
    keep = ~(high[m.faces].any(1) & (m.verts[m.faces][:, :, 1].mean(1) < 0.65))
    m.faces = m.faces[keep]
    return int((~keep).sum())


def body(fine=True):
    """The narrator's body. `fine`: as written - its faces split as the jacket's are (its shape as it
    was) and its elbows on their helpers; not: the game's points, for the sleeves to be laid over."""
    m = XMesh(GAME + "MaleBody.x")
    for side in ("L", "R"):
        slim(m, side)
    m.uvs = smooth_mesh.read_uvs(m)
    cut_chest(m, False)
    if fine:
        cut_waist(m)
        cut_upper_arms(m)
        smooth_mesh.refine(m, flat=True)
        bend_weights(m)
        shoulder_weights(m)
    return m


def lay_sleeves(m, skin):
    """The jacket m's sleeves drawn in and laid evenly over the slimmed skin (in place)."""
    for side in ("L", "R"):
        U, E, W = chain(m, side)
        env = envelope(skin, side)
        idx = arm_points(m, side, 0.05)
        t, foot, rad, r = place(m.verts[idx], U, E, W)
        keep = (t > 0.1) & (t < 2.06)
        idx, t, foot, rad, r = idx[keep], t[keep], foot[keep], rad[keep], r[keep]
        th = angle(m, side, t, rad)
        r_slim = r * slim_factor(t)
        base = env_at(env, t, th) + MARGIN
        r_new = base + FOLDS * np.maximum(0.0, r_slim - base)
        # (the shoulder as the game's, into it gradually)
        k = smoothstep(0.12, 0.45, t)
        r_new = r * (1 - k) + r_new * k
        m.verts[idx] = foot + rad * r_new[:, None]


def clearance(m, skin, side, verts=None):
    """The sleeve's points' least height over the skin (the envelope, unclamped)."""
    U, E, W = chain(m, side)
    env = envelope(skin, side)
    p = m.verts if verts is None else verts
    idx = arm_points(m, side, 0.05)
    t, foot, rad, r = place(p[idx], U, E, W)
    keep = (t > 0.45) & (t < 1.95)
    th = angle(m, side, t[keep], rad[keep])
    return (r[keep] - env_at(env, t[keep], th)).min()


if __name__ == "__main__":
    m = body()
    smooth_mesh.write(m, BODY_OUT, "Knox_NarratorBody")
    print("body ->", os.path.normpath(BODY_OUT))


def poke(jacket_verts, faces, skin, side, t_from=0.45, t_to=1.95):
    """The skin's points out through the sleeve: from the arm's line out through each skin point,
    how far past the sleeve's surface it is (the most; below 0: under the cloth by that much)."""
    U, E, W = chain(skin, side)
    idx = arm_points(skin, side, 0.3)
    t, foot, rad, r = place(skin.verts[idx], U, E, W)
    keep = (t > t_from) & (t < t_to)
    foot, rad, r = foot[keep], rad[keep], r[keep]
    a, b, c = (jacket_verts[faces[:, k]] for k in range(3))
    e1, e2 = b - a, c - a
    worst = -1.0
    for o, d, rr in zip(foot, rad, r):
        # Moller-Trumbore against every face, the nearest hit outwards
        h = np.cross(d, e2)
        det = (e1 * h).sum(1)
        ok = np.abs(det) > 1e-12
        inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
        s = o - a
        uu = (s * h).sum(1) * inv
        q = np.cross(s, e1)
        vv = (q @ d) * inv
        tt = (e2 * q).sum(1) * inv
        hit = ok & (uu >= 0) & (vv >= 0) & (uu + vv <= 1) & (tt > 1e-6)
        if not hit.any():
            continue
        worst = max(worst, rr - tt[hit].min())
    return worst
