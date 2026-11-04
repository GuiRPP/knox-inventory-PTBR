# The narrator's arms bent offline (the author 2026-11-03: the jacket narrowed at the elbow, with
# holes; the shoulders cut off, with holes): the body and the jacket as written, skinned the game's
# way (each point by its bones' blend, each bone by its own offset in the mesh), the arms raised and
# bent, the left forearm turned about itself as when he looks at it, the elbows' helpers posed as
# KnoxBite.elbows has them. Drawn from where the camera is and from three sides of the elbow: the
# cloth burgundy, the skin light, any face seen from behind (the game draws it not: a hole) magenta;
# and how narrow the sleeve gets about the elbow, of its width straight. A check of the shapes only -
# not the game.
#   python elbow_check.py out.png [body.x jacket.x]   (other files: the old ones, to compare)
import os
import sys
import numpy as np
from PIL import Image
from xmesh import XMesh
import slim_arms
import drawing

HERE = os.path.dirname(os.path.abspath(__file__))
BODY = slim_arms.BODY_OUT
JACKET = os.path.join(HERE, "..", "..", "42", "media", "models_X", "Skinned", "Clothes", "Knox_JacketRolled.x")
K = 1.5                                   # the skeleton's units to the scene's (KnoxBite.K)
EYE = np.array([0.0, 1.40, -0.32]) / K    # the camera (KnoxBite.EYE_Y, EYE_Z), his space -> the mesh's
FRONT = np.array([0.0, 0.0, -1.0])        # his front in the mesh (his feet point there)
EYE[2] = -EYE[2]
# the arms (the look's, roughly): the upper arm down from straight out to his side and forwards,
# the elbow bent, the forearm turned about itself (degrees)
POSE = {"L": (70, 35, 125, 160), "R": (75, 20, 60, -30)}


def rod(ax, a):
    ax = np.asarray(ax, float) / np.linalg.norm(ax)
    Km = np.array([[0, -ax[2], ax[1]], [ax[2], 0, -ax[0]], [-ax[1], ax[0], 0]])
    return np.eye(3) + np.sin(a) * Km + (1 - np.cos(a)) * Km @ Km


ARM = ("UpperArm", "Forearm", "Hand", "Finger0", "Finger1")
SWING = True     # the elbow opened as KnoxBite.openElbow has it


def his(v):
    return np.array([v[0], v[1], -v[2]]) / K


# the look's own, when asked (--look): KnoxBite.LOOK and POLE_LOOK, the right one parked (PARK_R, POLE_R)
REACH = {}
LOOK = {"L": (his([-0.07, 1.23, 0.27]), his([0.7, -0.7, 0.0])), "R": (his([-0.12, 0.92, 0.15]), his([-0.8, -0.6, -0.1]))}


def arc(a, b):
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    ax = np.cross(a, b)
    if np.linalg.norm(ax) < 1e-9:
        return np.eye(3)
    return rod(ax, np.arctan2(np.linalg.norm(ax), a @ b))


def reach(S, E0, H0, T, pole):
    """Two bones: the upper arm's turn and the forearm's after it, the wrist at T (or towards it)."""
    A, B = np.linalg.norm(E0 - S), np.linalg.norm(H0 - E0)
    v = T - S
    d = min(np.linalg.norm(v), A + B - 1e-4)
    v = v / np.linalg.norm(v)
    x = (A * A - B * B + d * d) / (2 * d)
    h = np.sqrt(max(A * A - x * x, 0.0))
    p = pole - v * (pole @ v)
    p /= np.linalg.norm(p)
    E = S + v * x + p * h
    Rup = arc(E0 - S, E - S)
    Rb = arc(Rup @ (H0 - E0), S + v * d - E)
    return Rup, Rb


def poses(m, pose=POSE):
    """Each bone's place now (4x4, the mesh's space)."""
    binds = {s["bone"]: np.linalg.inv(np.array(s["off"]).reshape(4, 4).T) for s in m.skin}
    out = dict(binds)
    for side, (down, fwd, bend, twist) in pose.items():
        down, fwd, bend, twist = np.radians([down, fwd, bend, twist])
        sg = 1 if side == "L" else -1
        Ub = binds["Bip01_%s_UpperArm" % side]
        Fb = binds["Bip01_%s_Forearm" % side]
        Hb = binds["Bip01_%s_Hand" % side]
        S = Ub[:3, 3]
        if side in REACH:
            # (KnoxBite's own: the wrist there, the elbow towards the pole - his space)
            Rup, Rb = reach(S, Fb[:3, 3], Hb[:3, 3], *REACH[side])
        else:
            # the upper arm: down about his front, then forwards about up; the forearm bent up and forwards
            Rup = rod([0, 1, 0], sg * fwd) @ rod(FRONT, sg * down)
            a = Rup @ (Hb[:3, 3] - Fb[:3, 3])
            Rb = rod(np.cross(a, np.array([0, 1, 0]) + 0.7 * FRONT), bend)
        E = S + Rup @ (Fb[:3, 3] - S)
        F1 = Rb @ Rup @ (Hb[:3, 3] - Fb[:3, 3])
        R = rod(F1, twist) @ Rb

        def moved(B, R1, at):
            P = np.eye(4)
            P[:3, :3] = R1 @ B[:3, :3]
            P[:3, 3] = at + R1 @ (B[:3, 3] - at) if at is not None else B[:3, 3]
            return P

        on = ["Bip01_%s_%s" % (side, b) for b in ARM]
        if side == "L":
            on += ["Bip01_Prop1", "Bip01_Prop2"]
        for b in on:
            if b not in binds:
                continue
            P = moved(binds[b], Rup, S)
            if b != "Bip01_%s_UpperArm" % side:
                P = moved(P, R, E)
            out[b] = P
        # KnoxBite.elbows: k of the way from the upper arm's turn to the forearm's without its twist,
        # k of the twist after
        RU = Rup @ Ub[:3, :3]
        if side in REACH and SWING:
            # (KnoxBite.openElbow: the upper arm about the elbow, the elbow open to 150 degrees at least)
            a0 = out["Bip01_%s_UpperArm" % side][:3, 3] - E
            f = F1
            ang = np.arctan2(np.linalg.norm(np.cross(a0, f)), a0 @ f)
            Q = rod(np.cross(a0, f), ang - np.radians(150)) if ang < np.radians(150) else np.eye(3)
            P = np.eye(4)
            P[:3, :3] = Q @ RU
            P[:3, 3] = E + Q @ a0
            out["Bip01_%s_UpperArm" % side] = P
            RU = Q @ RU
        D = (Rb @ Rup @ Fb[:3, :3]) @ RU.T
        for k, b in enumerate(slim_arms.HELPERS[side]):
            P = np.eye(4)
            P[:3, :3] = rod(F1, twist * slim_arms.TWIST_SHARE[k]) @ slim_arms.rot_pow(D, slim_arms.SWING_SHARE[k]) @ RU
            P[:3, 3] = E
            out[b] = P
    return out


def skinned(m, P):
    v = np.c_[m.verts, np.ones(len(m.verts))]
    acc = np.zeros((len(m.verts), 3))
    for s in m.skin:
        if not s["idx"]:
            continue
        off = np.array(s["off"]).reshape(4, 4).T
        S = P[s["bone"]] @ off
        idx = np.array(s["idx"])
        acc[idx] += np.array(s["w"])[:, None] * (v[idx] @ S.T)[:, :3]
    return acc


def tile(pts, faces, n_body, eye, at, w, h, focal):
    r, u, f = drawing.basis(eye, at)
    fn = np.cross(pts[faces[:, 1]] - pts[faces[:, 0]], pts[faces[:, 2]] - pts[faces[:, 0]])
    fn /= np.linalg.norm(fn, axis=1)[:, None] + 1e-12
    back = ((pts[faces].mean(1) - eye) * fn).sum(1) > 0
    lit = 0.35 + 0.65 * np.abs(fn @ drawing.LIGHT)
    base = np.vstack([np.tile([200, 160, 135], (n_body, 1)), np.tile([128, 26, 36], (len(faces) - n_body, 1))])
    cols = lit[:, None] * base
    cols[back] = (255, 0, 255)
    return drawing.raster(Image.new("RGB", (w, h), (30, 30, 34)), pts, faces, cols, eye, r, u, f, focal)


def draw(body, jacket, out):
    Pb, Pj = poses(body), poses(jacket)
    pb, pj = skinned(body, Pb), skinned(jacket, Pj)
    pts = np.vstack([pb, pj])
    faces = np.vstack([body.faces, jacket.faces + len(pb)])
    E = Pb["Bip01_L_Forearm"][:3, 3]
    W = Pb["Bip01_L_Hand"][:3, 3]
    # from the camera: the forearm's middle (the bar's 32 degrees FOV), and a wider one
    eye = EYE
    tiles = [tile(pts, faces, len(body.faces), eye, (E + W) / 2, 480, 360, 360 / 2 / np.tan(np.radians(16))),
             tile(pts, faces, len(body.faces), eye, (E + W) / 2 + np.array([0, -0.15, 0]), 480, 360, 360 / 2 / np.tan(np.radians(40)))]
    row2 = []
    for d in ([0, 0.3, 1], [1, 0.3, 0.2], [0, 1, 0.1], [-0.4, 0.5, -1]):
        d = np.array(d, float) / np.linalg.norm(d)
        row2.append(tile(pts, faces, len(body.faces), E + d * 0.25, E, 240, 200, 420))
    img = Image.new("RGB", (960, 560), (30, 30, 34))
    img.paste(tiles[0], (0, 0))
    img.paste(tiles[1], (480, 0))
    for i, t in enumerate(row2):
        img.paste(t, (i * 240, 360))
    img.save(out)


def narrowest(jacket, bend, twist):
    """The left sleeve's girth by the elbow (the mean distance of the cloth from the elbow in the
    plane halving the bend), bent and turned, of that straight."""
    def girth(pose):
        P = poses(jacket, pose)
        p = skinned(jacket, P)
        E = P["Bip01_L_Forearm"][:3, 3]
        U = P["Bip01_L_UpperArm"][:3, 3]
        H = P["Bip01_L_Hand"][:3, 3]
        n = (E - U) / np.linalg.norm(E - U) + (H - E) / np.linalg.norm(H - E)
        n /= np.linalg.norm(n)
        near = (np.abs((p - E) @ n) < 0.006) & (np.linalg.norm(p - E, axis=1) < 0.08)
        q = p[near] - E
        q -= np.outer(q @ n, n)
        return np.sqrt((q ** 2).sum(1)).mean()
    pose = dict(POSE)
    straight = dict(pose, L=(pose["L"][0], pose["L"][1], 0, 0))
    pose["L"] = (pose["L"][0], pose["L"][1], bend, twist)
    return girth(pose) / girth(straight)


if __name__ == "__main__":
    out = sys.argv[1]
    if "--look" in sys.argv:
        sys.argv.remove("--look")
        REACH.update(LOOK)
    roll = 0.0
    if "--roll" in sys.argv:
        # (the sleeve rolled up by that much: its rings slid up the forearm as KnoxBite has them)
        i = sys.argv.index("--roll")
        roll = float(sys.argv[i + 1])
        del sys.argv[i:i + 2]
    body = XMesh(sys.argv[2] if len(sys.argv) > 2 else BODY)
    jacket = XMesh(sys.argv[3] if len(sys.argv) > 3 else JACKET)
    if roll:
        import roll_sleeve
        jacket.verts = roll_sleeve.rolled(jacket, roll)
    draw(body, jacket, out)
    print("picture ->", out)
    for bend, twist in ((90, 0), (125, 0), (125, 90), (125, 160), (60, 160), (30, 170)):
        print("bent %3d, turned %3d: the sleeve by the elbow %.2f of its girth straight" % (
            bend, twist, narrowest(jacket, bend, twist)))
