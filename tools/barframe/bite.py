# The bar's camera is someone's eyes (the author, 2026-11-02): now and then, very rarely, the view
# dips, he raises his left forearm, the right hand rolls the jacket's sleeve up it, he turns the arm
# over - a bite (or, sometimes, nothing: a breath out) - and the sleeve is yanked back down, the view
# comes back up. Stage 1 of the plan: the animatic, without the game. The game's male body on
# these very bones (the clip of stage 3 is made from the same curves), the jacket's sleeve and the
# bite drawn over it, on the bar's real frame from the camera as it moves (KnoxBarFrame through
# Harness, one run a frame). Run from this folder:
#   python bite.py <out dir> bite|none [fps] [width height]
import math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw

import poses
from poses import Pose, clip_to_scene, scene_to_clip, curve, path, window, vec, norm, cross, dot, axis_turn
from clips import Clip
import sheet

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(os.path.dirname(HERE))
U = 1 / 1.22
JDK = r"C:\Users\pielo\Zomboid\tools\jdk-25\bin"
GAME_JAR = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar"

# the menu's camera (KnoxBarFrame.camera), scene units
EYE = np.array([-3.4 * U, 1.95 * U, 3.9 * U])
AT = np.array([-1.0 * U, 1.25 * U, -5.0 * U])
FOV = 32.0
_d = AT - EYE
YAW_F = np.array([_d[0], 0.0, _d[2]]) / math.hypot(_d[0], _d[2])      # forward, level
PITCH0 = math.degrees(math.atan2(_d[1], math.hypot(_d[0], _d[2])))      # -4.3: the menu's

# his eyes in his own space (x his left, y up, z his front; scene units): before the head bone
HERO_EYE = np.array([0.0, 1.31, 0.055])

# --- where the arms go, his own space. The left wrist up before the face, the forearm across
# to it from a low elbow; at rest as the idle's, hanging.
REST_L = ([0.221, 0.712, -0.07], [0.30, 0.85, -0.10])
REST_R = ([-0.225, 0.712, -0.07], [-0.30, 0.85, -0.10])
UP_L = ([-0.02, 1.20, 0.25], [0.14, 0.98, 0.16])           # (wrist, where the elbow goes)
CLOSE_L = ([-0.018, 1.205, 0.245], [0.14, 0.99, 0.155])        # brought in, looking hard
FREE_R = ([-0.17, 1.02, 0.20], [-0.36, 0.88, 0.0])          # the right hand let go, low, out of the way
PALM_DOWN = [0.3, 0.0, 1.0]                                # (the back of the forearm to the eyes)
PALM_UP = [0.1, 0.45, -0.88]                                # the inside of the forearm to the eyes
SLEEVE_ROLLED = 0.75                                        # the cuff, of the way from the wrist to the elbow
BITE_AT = 0.3                                              # the bite, of the way from the wrist


def timeline(kind):
    """Curves of t for one take. Returns a dict and the take's length."""
    bite = kind == "bite"
    k = {}
    if bite:
        L = 7.4
        # the view: down and wider as the arm comes up; back after the sleeve's down
        k["look"] = curve([(0, 0), (0.25, 0), (1.25, 1), (5.9, 1), (7.0, 0), (L, 0)])
        k["raise"] = curve([(0, 0), (0.2, 0), (1.25, 1), (5.65, 1), (6.55, 0), (L, 0)])
        k["close"] = curve([(0, 0), (3.0, 0), (3.75, 1), (3.88, 0.6), (5.0, 0.6), (5.25, 0), (L, 0)])
        # the forearm turned: 0 palm down, 1 the inside up to the eyes
        k["turn"] = curve([(0, 0), (2.95, 0), (3.75, 1), (5.0, 1), (5.22, 0), (L, 0)])
        # the right hand on the cuff (0 its free place / rest), and how far up the forearm the cuff is
        k["grip"] = curve([(0, 0), (0.85, 0), (1.55, 1), (2.55, 1), (2.95, 0), (4.95, 0), (5.25, 1), (5.62, 1), (5.9, 0), (L, 0)])
        k["cuff"] = curve([(0, 0), (1.6, 0), (1.98, 0.45), (2.1, 0.47), (2.5, SLEEVE_ROLLED), (5.3, SLEEVE_ROLLED), (5.6, 0), (L, 0)])
        # the right arm: from rest up (0 rest .. 1 its free place or the cuff), back down at the end
        k["r_up"] = curve([(0, 0), (0.6, 0), (1.45, 1), (5.75, 1), (6.6, 0), (L, 0)])
        # the shock: a flinch back at 3.8, then the hands shake and the breath goes fast
        k["shake"] = curve([(0, 0), (3.8, 0), (3.95, 1), (5.6, 1), (6.4, 0), (L, 0)])
        k["flinch"] = curve([(0, 0), (3.78, 0), (3.88, 1), (4.2, 0.3), (L, 0)])
        k["seen"] = 3.8
    else:
        L = 8.4
        k["look"] = curve([(0, 0), (0.25, 0), (1.25, 1), (6.9, 1), (8.0, 0), (L, 0)])
        k["raise"] = curve([(0, 0), (0.2, 0), (1.25, 1), (6.75, 1), (7.6, 0), (L, 0)])
        k["close"] = curve([(0, 0), (3.0, 0), (3.75, 1), (4.9, 1), (5.4, 0), (L, 0)])
        # turned up, a look, a little further and back again: nothing
        k["turn"] = curve([(0, 0), (2.95, 0), (3.75, 1), (4.2, 1.12), (4.6, 0.92), (5.0, 1), (5.5, 1), (6.0, 0), (L, 0)])
        k["grip"] = curve([(0, 0), (0.85, 0), (1.55, 1), (2.55, 1), (2.95, 0), (5.7, 0), (6.05, 1), (6.75, 1), (7.0, 0), (L, 0)])
        k["cuff"] = curve([(0, 0), (1.6, 0), (1.98, 0.45), (2.1, 0.47), (2.5, SLEEVE_ROLLED), (6.1, SLEEVE_ROLLED), (6.7, 0), (L, 0)])
        k["r_up"] = curve([(0, 0), (0.6, 0), (1.45, 1), (6.85, 1), (7.65, 0), (L, 0)])
        k["shake"] = curve([(0, 0), (L, 0)])
        k["flinch"] = curve([(0, 0), (L, 0)])
        # the breath out: the view lifts a little, then sinks, the shoulders with it
        k["relief"] = curve([(0, 0), (5.0, 0), (5.35, 1), (6.2, -0.6), (6.9, 0), (L, 0)])
        k["seen"] = -1
    k.setdefault("relief", curve([(0, 0), (L, 0)]))
    return k, L


def lerp(a, b, s):
    return [a[i] + (b[i] - a[i]) * s for i in range(3)]


def roll_palm(pose, side, want):
    """Turns the forearm (the hand with it) about its own length so the palm faces `want`
    (his space) as near as it can."""
    fore = "Bip01_%s_Forearm" % side
    e, h = pose.at(fore), pose.at("Bip01_%s_Hand" % side)
    a = norm(vec(e, h))
    w = scene_to_clip(want)
    for _ in range(2):
        m = pose.world("Bip01_%s_Hand" % side)
        p = [m[i][2] for i in range(3)]
        pp = norm([p[i] - dot(p, a) * a[i] for i in range(3)])
        wp = norm([w[i] - dot(w, a) * a[i] for i in range(3)])
        ang = math.degrees(math.atan2(dot(cross(pp, wp), a), dot(pp, wp)))
        pose.turn_world(fore, axis_turn(a, ang))
        m = pose.world("Bip01_%s_Hand" % side)
        p2 = [m[i][2] for i in range(3)]
        if dot(norm(p2), wp) < dot(pp, wp):          # (turned the wrong way round: back, and the other way)
            pose.turn_world(fore, axis_turn(a, -2 * ang))


def arm(pose, side, wrist, elbow, palm, fingers=None):
    s = pose.at("Bip01_%s_UpperArm" % side)
    pose.reach("Bip01_%s_UpperArm" % side, "Bip01_%s_Forearm" % side, "Bip01_%s_Hand" % side,
               scene_to_clip(wrist), vec(s, scene_to_clip(elbow)))
    if palm is not None:
        roll_palm(pose, side, palm)
        # (the wrist straight: the fingers on along the forearm, the palm the way wanted)
        e, h = pose.at("Bip01_%s_Forearm" % side), pose.at("Bip01_%s_Hand" % side)
        poses.orient_hand(pose, side, fingers or clip_to_scene(vec(e, h)), palm)


BASE = Clip("Bob_Idle")


def slerp_dir(a, b, s):
    a, b = np.array(norm(a)), np.array(norm(b))
    d = float(np.clip(a @ b, -1, 1))
    th = math.acos(d)
    if th < 1e-4:
        return list(a)
    return list((math.sin((1 - s) * th) * a + math.sin(s * th) * b) / math.sin(th))


def pose_at(k, t):
    p = Pose(BASE)
    r = k["raise"](t)
    c = k["close"](t)
    tr = k["turn"](t)
    sh = k["shake"](t)
    fl = k["flinch"](t)
    # (the shaking: small and quick, never the same twice)
    q = [sh * 0.004 * (math.sin(t * 57) + 0.6 * math.sin(t * 83 + 1.3)), sh * 0.003 * math.sin(t * 71 + 0.4), 0.0]
    w_up = lerp(UP_L[0], CLOSE_L[0], c)
    e_up = lerp(UP_L[1], CLOSE_L[1], c)
    w = lerp(REST_L[0], w_up, r)
    w = [w[0] + q[0], w[1] + q[1] - 0.012 * fl, w[2] - 0.035 * fl]
    e = lerp(REST_L[1], e_up, r)
    # (hanging, the palm in to the thigh; up, down - then turned up)
    palm = slerp_dir([-1, 0, 0], slerp_dir(PALM_DOWN, PALM_UP, min(1.0, tr)), min(1.0, r * 1.4)) if r > 0.01 else None
    if palm is not None and tr > 1.0:
        palm = slerp_dir(PALM_UP, [0.6, 0.55, -0.55], (tr - 1.0) / 0.12 * 0.5)
    arm(p, "L", w, e, palm)
    # the right hand: on the left forearm at the cuff, palm down over it, fingers round it
    lw, le = clip_to_scene(p.at("Bip01_L_Hand")), clip_to_scene(p.at("Bip01_L_Forearm"))
    cuff = k["cuff"](t)
    on = lerp(lw, le, cuff)
    # (from his right side of the forearm, not between it and his eyes)
    ax = np.array(norm(vec(lw, le)))
    mh = p.world("Bip01_L_Hand")
    lpalm = np.array(norm(clip_to_scene([mh[i][2] for i in range(3)])))
    sv = np.cross(ax, lpalm)
    sv /= np.linalg.norm(sv)
    if sv[0] > 0:
        sv = -sv
    grip_w = list(np.array(on) + sv * 0.06 - lpalm * 0.012)
    grip_e = [grip_w[0] - 0.22, grip_w[1] - 0.2, grip_w[2] - 0.05]
    rfingers = list(np.cross(ax, sv) * (1 if np.cross(ax, sv)[2] > 0 else -1) * 0.6 + ax * 0.4)
    g = k["grip"](t)
    up_w = lerp(FREE_R[0], grip_w, g)
    up_e = lerp(FREE_R[1], grip_e, g)
    ru = k["r_up"](t)
    rw = lerp(REST_R[0], up_w, ru)
    rw = [rw[0] + q[1], rw[1] + q[0], rw[2]]
    re_ = lerp(REST_R[1], up_e, ru)
    rpalm = slerp_dir([1, 0, 0], slerp_dir([0.6, 0.2, 0.3], list(-sv), g), min(1.0, ru * 1.4)) if ru > 0.01 else None
    arm(p, "R", rw, re_, rpalm, rfingers if g > 0.5 else None)
    # the breath out: the shoulders drop
    rl = k["relief"](t)
    if rl:
        for b, s in (("Bip01_L_Clavicle", 1), ("Bip01_R_Clavicle", -1)):
            p.turn_world(b, axis_turn(poses.clip_forward(), -2.5 * rl * s))
    return p


# --- the view
def camera_at(k, t):
    """fov, eye, target (scene units) at t."""
    lk = k["look"](t)
    sh = k["shake"](t)
    rl = k["relief"](t)
    fl = k["flinch"](t)
    pitch = PITCH0 + (-28.0 + 1.6 * rl) * lk - 1.2 * fl
    # (a fast breath after the bite: the view rises and falls with it)
    pitch += sh * 0.55 * math.sin(t * 2 * math.pi * 1.6)
    yaw_wobble = sh * 0.25 * math.sin(t * 2 * math.pi * 0.9 + 1.0)
    fov = FOV + (62.0 - FOV) * lk
    f = YAW_F * math.cos(math.radians(pitch)) + np.array([0, math.sin(math.radians(pitch)), 0])
    left = np.cross([0, 1, 0], YAW_F)
    f = f + left * math.radians(yaw_wobble)
    eye = EYE + np.array([0, -0.004 * U * fl, 0])
    return fov, eye, eye + f * 5.0


def hero_to_world(pts):
    """His own space (x left, y up, z front) to the bar's, his eyes at the camera's."""
    left = np.cross([0, 1, 0], YAW_F)
    rel = np.asarray(pts, float) - HERO_EYE
    return EYE + rel[..., 0:1] * left + rel[..., 1:2] * np.array([0, 1, 0]) + rel[..., 2:3] * YAW_F


# --- drawing him over the bar's frame
def basis(eye, target):
    f = np.asarray(target, float) - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def tube(a, b, ra, rb, n=10):
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = b - a
    d /= np.linalg.norm(d)
    x = np.cross(d, [0.3, 1, 0.2])
    x /= np.linalg.norm(x)
    y = np.cross(d, x)
    out = []
    for i in range(n):
        t0, t1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        c0, c1 = math.cos(t0) * x + math.sin(t0) * y, math.cos(t1) * x + math.sin(t1) * y
        out.append([a + c0 * ra, a + c1 * ra, b + c1 * rb, b + c0 * rb])
    return out


def disc(c, nrm, r, n=9):
    c, nrm = np.asarray(c, float), np.asarray(nrm, float)
    x = np.cross(nrm, [0.2, 1, 0.3])
    x /= np.linalg.norm(x)
    y = np.cross(nrm, x)
    return [[c, c + (math.cos(2 * math.pi * i / n) * x + math.sin(2 * math.pi * i / n) * y) * r,
             c + (math.cos(2 * math.pi * (i + 1) / n) * x + math.sin(2 * math.pi * (i + 1) / n) * y) * r] for i in range(n)]


SKIN, SLEEVE, ROLL, BITE, BITE_IN = (176, 146, 128), (58, 64, 52), (72, 79, 64), (96, 22, 20), (52, 8, 8)
LIGHT = np.array([0.5, 0.7, 0.5]) / np.linalg.norm([0.5, 0.7, 0.5])


JACKET = ("Bip01_Pelvis", "Bip01_Spine", "Bip01_Spine1", "Bip01_Spine2", "Bip01_L_Clavicle", "Bip01_R_Clavicle",
          "Bip01_L_UpperArm", "Bip01_R_UpperArm", "Bip01_L_Forearm", "Bip01_R_Forearm")


def raster(img, pts, faces, colours, eye, r, u, f, focal, ss=2):
    """Faces (world points) with flat colours over the picture, with a depth buffer."""
    w, h = img.size
    W, H = w * ss, h * ss
    v = pts - eye
    x, y, z = v @ r, v @ u, v @ f
    fz = z[faces]
    ok = (fz > 0.03).all(axis=1)
    sx = W / 2 + x / np.maximum(z, 1e-4) * focal * ss
    sy = H / 2 - y / np.maximum(z, 1e-4) * focal * ss
    depth = np.full((H, W), np.inf)
    col = np.zeros((H, W, 3))
    for fi in np.nonzero(ok)[0]:
        a, b, c = faces[fi]
        xs, ys, zs = sx[[a, b, c]], sy[[a, b, c]], z[[a, b, c]]
        x0, x1 = max(int(xs.min()), 0), min(int(xs.max()) + 1, W)
        y0, y1 = max(int(ys.min()), 0), min(int(ys.max()) + 1, H)
        if x0 >= x1 or y0 >= y1:
            continue
        den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(den) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        l0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / den
        l1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
        if not inside.any():
            continue
        zz = 1 / (l0 / zs[0] + l1 / zs[1] + l2 / zs[2])
        d = depth[y0:y1, x0:x1]
        win = inside & (zz < d)
        d[win] = zz[win]
        col[y0:y1, x0:x1][win] = colours[fi]
    alpha = np.isfinite(depth).astype(np.uint8) * 255
    over = Image.fromarray(np.dstack([col.clip(0, 255).astype(np.uint8), alpha]), "RGBA").resize((w, h), Image.LANCZOS)
    out = img.convert("RGBA")
    out.alpha_composite(over)
    return out.convert("RGB")


def vertex_normals(p, faces):
    n = np.zeros_like(p)
    fn = np.cross(p[faces[:, 1]] - p[faces[:, 0]], p[faces[:, 2]] - p[faces[:, 0]])
    for i in range(3):
        np.add.at(n, faces[:, i], fn)
    return n / (np.linalg.norm(n, axis=1)[:, None] + 1e-9)


def draw(img, body, pose, k, t, cam):
    fov, eye, target = cam
    r, u, f = basis(eye, target)
    focal = (img.size[1] / 2) / math.tan(math.radians(fov / 2))
    sk = body.skinned(lambda b: pose.world(b) if b in pose.clip.parent else np.eye(4))   # his space
    sc = lambda b: np.array(clip_to_scene(pose.at(b)))
    lw, le = sc("Bip01_L_Hand"), sc("Bip01_L_Forearm")
    axis = le - lw
    s = ((sk - lw) @ axis) / (axis @ axis)              # of the way from the left wrist to the elbow
    cuff = k["cuff"](t)
    jacket = np.isin(body.bone, [body.names.index(b) for b in JACKET if b in body.names])
    on_left_fore = body.bone == body.names.index("Bip01_L_Forearm")
    bare = on_left_fore & (s < cuff)
    cloth = jacket & ~bare
    # (the jacket stands off the body; rolled up, a thick band of it at the cuff)
    nrm = vertex_normals(sk, body.faces)
    band = on_left_fore & (s >= cuff) & (s < cuff + 0.14) & (cuff > 0.05)
    puff = np.where(cloth, 0.012, 0.0) + np.where(band, 0.018, 0.0)
    pts = sk + nrm * puff[:, None]
    # the bite: on the inside of the left forearm, BITE_AT of the way up
    m = pose.world("Bip01_L_Forearm")
    inner = np.array(norm(clip_to_scene([-m[i][1] * 0.9 + m[i][2] * 0.45 for i in range(3)])))
    a1 = axis / np.linalg.norm(axis)
    inner = inner - a1 * (inner @ a1)
    inner /= np.linalg.norm(inner)
    c = lw + axis * BITE_AT
    ring = on_left_fore & (np.abs(s - BITE_AT) < 0.08)
    centre = c + inner * float(np.max((sk[ring] - c) @ inner))
    face_c = sk[body.faces].mean(axis=1)
    dist = np.linalg.norm(face_c - centre, axis=1)
    face_cloth = cloth[body.faces].sum(axis=1) >= 2
    world = hero_to_world(pts)
    fn = np.cross(world[body.faces[:, 1]] - world[body.faces[:, 0]], world[body.faces[:, 2]] - world[body.faces[:, 0]])
    fn /= np.linalg.norm(fn, axis=1)[:, None] + 1e-9
    lit = 0.35 + 0.65 * np.abs(fn @ LIGHT)
    base = np.where(face_cloth[:, None], np.array(SLEEVE if cuff < 0.05 else ROLL, float), np.array(SKIN, float))
    colours = base * lit[:, None] * 0.8
    keep = body.keep
    out = raster(img, world, body.faces[keep], colours[keep], eye, r, u, f, focal)
    if k["seen"] >= 0 and cuff > BITE_AT + 0.06:
        bite_mark(out, centre, a1, inner, eye, r, u, f, focal)
    return out


def bite_mark(img, centre, along, inner, eye, r, u, f, focal):
    """The bite on the skin, as the game's would be a picture on it: a bruise, two arcs of teeth
    marks, torn skin between them (his space in, the picture out)."""
    w, h = img.size
    side = np.cross(inner, along)
    if (hero_to_world(centre + inner * 0.05) - hero_to_world(centre)) @ (eye - hero_to_world(centre)) <= 0:
        return                                             # (turned away)

    def P(a, b):
        v = hero_to_world(centre + along * a + side * b) - eye
        z = v @ f
        return (w / 2 + (v @ r) / z * focal, h / 2 - (v @ u) / z * focal)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ring = lambda ra, rb, n=24: [P(ra * math.cos(2 * math.pi * i / n), rb * math.sin(2 * math.pi * i / n)) for i in range(n)]
    d.polygon(ring(0.034, 0.026), fill=(70, 40, 60, 90))          # the bruise
    d.polygon(ring(0.024, 0.018), fill=(90, 30, 35, 120))
    for sgn in (1, -1):                                             # the two rows of teeth
        for i in range(7):
            a = math.radians(-60 + i * 20)
            x, y = 0.017 * math.sin(a), sgn * 0.012 * math.cos(a)
            d.polygon([P(x + 0.0025, y), P(x, y + 0.002), P(x - 0.0025, y), P(x, y - 0.002)], fill=(60, 6, 8, 235))
    d.polygon(ring(0.007, 0.004, 10), fill=(110, 12, 10, 230))     # torn skin, wet
    img.paste(Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"))


class Him(sheet.Body):
    def __init__(self):
        super().__init__()
        heads = set()
        fore = set()
        for bone, idx, wts, off in self.skin:
            if bone in ("Bip01_Head", "Bip01_Neck"):
                heads.update(int(i) for i, x in zip(idx, wts) if x > 0.05)
            if bone == "Bip01_L_Forearm":
                fore.update(int(i) for i, x in zip(idx, wts) if x > 0.5)
        # (inside his head: the head and neck never drawn; the torso far below the view)
        self.keep = np.array([not any(int(v) in heads for v in f) for f in self.faces])
        # each vertex's bone: the one that moves it most
        self.names = [b for b, _, _, _ in self.skin]
        most = np.zeros(len(self.verts))
        self.bone = np.full(len(self.verts), -1)
        for j, (bone, idx, wts, off) in enumerate(self.skin):
            better = wts > most[idx]
            self.bone[idx[better]] = j
            most[idx[better]] = wts[better]



def build_harness(cls):
    os.makedirs(cls, exist_ok=True)
    src = [os.path.join(MOD, "java", "src", "knox", "java", n) for n in ("KnoxBarMesh.java", "KnoxBarLife.java", "KnoxBarFrame.java", "KnoxMenuSwipe.java")]
    subprocess.check_call([os.path.join(JDK, "javac.exe"), "--release", "17", "-encoding", "UTF-8", "-nowarn", "-cp", GAME_JAR, "-d", cls] + src + [os.path.join(HERE, "Harness.java")])


def background(cls, out, w, h, cam, time):
    fov, eye, target = cam
    c = ",".join("%.5f" % v for v in [fov] + list(eye / U) + list(target / U))
    subprocess.check_call([os.path.join(JDK, "java.exe"), "-Dknox.mod=" + MOD, "-Dbar.cam=" + c, "-cp", cls + ";" + GAME_JAR,
                           "Harness", out, str(w), str(h), "%.3f" % time, "high", "6"], stdout=subprocess.DEVNULL)


def main():
    out, kind = sys.argv[1], sys.argv[2]
    fps = float(sys.argv[3]) if len(sys.argv) > 3 else 15
    w, h = (int(sys.argv[4]), int(sys.argv[5])) if len(sys.argv) > 5 else (960, 540)
    os.makedirs(out, exist_ok=True)
    cls = os.path.join(out, "cls")
    build_harness(cls)
    k, L = timeline(kind)
    body = Him()
    n = int(L * fps) + 1
    # (BITE_TIMES=1.0,3.9: only those moments, for a look)
    only = [float(x) for x in os.environ.get("BITE_TIMES", "").split(",") if x]
    times = only or [i / fps for i in range(n)]
    n = len(times)
    for i, t in enumerate(times):
        cam = camera_at(k, t)
        bg = os.path.join(out, "bg_%03d.png" % i)
        background(cls, bg, w, h, cam, 30.0 + t)
        img = draw(Image.open(bg), body, pose_at(k, t), k, t, cam)
        ImageDraw.Draw(img).text((8, 6), "%.1f s" % t, fill=(220, 220, 220))
        img.save(os.path.join(out, "f_%03d.png" % i))
        os.remove(bg)
        print("frame", i, "of", n, flush=True)
    print("done", n, "frames,", L, "s")


if __name__ == "__main__":
    main()
