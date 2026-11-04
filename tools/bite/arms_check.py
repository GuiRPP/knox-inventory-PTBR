# The narrator's arms offline (KnoxBite, the author's video 2026-11-02: the right hand bent down hard
# on the sleeve, went through the left arm going down and came back across it as a cross). The arms'
# key poses with KnoxBite's own numbers and its two-bone reach - the shoulders, the bones' lengths, the
# elbows' poles - drawn as tubes from the camera, and the clearances measured: the right forearm and
# hand against the left forearm, the right wrist's bend. A check of the shapes only - not the game.
#   python arms_check.py <out.png>
import math
import sys
import numpy as np
from PIL import Image, ImageDraw

# his space: x his left, y up, z his front (scene units) - KnoxBite
SH_L, SH_R = np.array([0.151, 1.107, -0.05]), np.array([-0.151, 1.107, -0.05])
A, B = 0.205, 0.207                       # upper arm, forearm
EYE = np.array([0.0, 1.40, -0.32])        # the camera (EYE_Y, EYE_Z)
FOV = 32.0
PALM_FROM_WRIST, GRIP_OFF = 0.055, 0.062
R_SLEEVE, R_SKIN, R_HAND = 0.048, 0.03, 0.022


def unit(v):
    v = np.asarray(v, float)
    return v / (np.linalg.norm(v) + 1e-12)


def reach(s, t, pole):
    """KnoxBite.reach: the elbow towards the pole, the wrist at t (or as near as it gets)."""
    v = t - s
    to = np.linalg.norm(v)
    v = v / to
    dd = max(abs(A - B) + 0.02 * (A + B), min((A + B) * 0.97, to))
    c = (A * A + dd * dd - B * B) / (2 * A * dd)
    sn = math.sqrt(max(0.0, 1 - c * c))
    g = np.asarray(pole, float) - v * np.dot(pole, v)
    g = unit(g)
    e = s + v * A * c + g * A * sn
    w = s + v * dd
    return e, w


def seg_dist(p1, q1, p2, q2):
    """The least distance between two segments (sampled; plenty for a check)."""
    best = 1e9
    for a in np.linspace(0, 1, 41):
        x = p1 + (q1 - p1) * a
        d = q2 - p2
        k = np.clip(np.dot(x - p2, d) / np.dot(d, d), 0, 1)
        best = min(best, np.linalg.norm(x - (p2 + d * k)))
    return best


def grip_frame(el, wl, gs, mode):
    """Where the right hand is put on the left forearm: its palm, fingers, wrist (his space)."""
    f1 = unit(wl - el)                      # elbow to wrist
    up = np.array([0.0, 1.0, 0.0])
    g = unit(up - f1 * np.dot(up, f1))      # the forearm's top
    x = np.cross(f1, g)
    if x[2] < 0:                            # (his front: + z here)
        x = -x
    if mode == "old":
        side = g
        fingers = unit(x * 0.8 - g * 0.6)
    else:
        # (KnoxBite.arms: the near top side, the fingers along to the elbow and over)
        side = unit(g * 0.5 - x * 0.9)
        fingers = unit(-f1 * 0.6 + g * 0.6 + x * 0.3)
        fingers = unit(fingers - side * np.dot(fingers, side) * 0.5)
    on = wl + (el - wl) * gs + side * GRIP_OFF
    wrist = on - fingers * PALM_FROM_WRIST
    return on, fingers, wrist


def pose(wristL, poleL, gs=None, mode="new", wristR=None, poleR=(-0.8, -0.6, -0.1)):
    el, wl = reach(SH_L, np.array(wristL), np.array(poleL, float))
    out = {"L": (SH_L, el, wl)}
    hand_l = wl + unit(wl - el) * 0.09
    out["Lh"] = (wl, hand_l)
    if gs is not None:
        on, fingers, wr_goal = grip_frame(el, wl, gs, mode)
        er, wr = reach(SH_R, wr_goal, np.array(poleR, float))
        out["R"] = (SH_R, er, wr)
        out["Rh"] = (wr, wr + fingers * 0.09)
        bend = math.degrees(math.acos(np.clip(np.dot(unit(wr - er), fingers), -1, 1)))
        out["bend"] = bend
        out["miss"] = np.linalg.norm(wr - wr_goal)
    elif wristR is not None:
        er, wr = reach(SH_R, np.array(wristR), np.array(poleR, float))
        out["R"] = (SH_R, er, wr)
        out["Rh"] = (wr, wr + unit(wr - er) * 0.09)
    return out


def clear(o):
    """The right forearm and hand to the left forearm (surface to surface; < 0 - through it)."""
    if "R" not in o:
        return None
    _, el, wl = o["L"]
    _, er, wr = o["R"]
    a = seg_dist(er, wr, el, wl) - R_SLEEVE - R_SLEEVE
    b = seg_dist(o["Rh"][0], o["Rh"][1], el, wl) - R_HAND - R_SLEEVE
    return min(a, b)


def project(p, eye, at, w, h):
    f = unit(at - eye)
    r = unit(np.cross([0, 1, 0], f))       # (his left on screen's left: x is his left)
    u = np.cross(f, r)
    d = p - eye
    z = np.dot(d, f)
    foc = (h / 2) / math.tan(math.radians(FOV / 2))
    return np.array([w / 2 - np.dot(d, r) / z * foc, h / 2 - np.dot(d, u) / z * foc]), z


def draw(o, title, w=480, h=270):
    img = Image.new("RGB", (w, h), (40, 38, 36))
    dr = ImageDraw.Draw(img)
    _, el, wl = o["L"]
    at = el + (wl - el) * 0.6
    tubes = [(o["L"][1], o["L"][2], R_SLEEVE, (90, 110, 140)), (o["Lh"][0], o["Lh"][1], R_HAND, (220, 190, 160))]
    if "R" in o:
        tubes += [(o["R"][1], o["R"][2], R_SLEEVE, (70, 90, 120)), (o["Rh"][0], o["Rh"][1], R_HAND, (240, 210, 180))]
    foc = (h / 2) / math.tan(math.radians(FOV / 2))
    order = sorted(tubes, key=lambda t: -np.dot((t[0] + t[1]) / 2 - EYE, unit(at - EYE)))
    for a, b, r, col in order:
        pa, za = project(a, EYE, at, w, h)
        pb, zb = project(b, EYE, at, w, h)
        if za <= 0.05 or zb <= 0.05:
            continue
        rad = r * foc / ((za + zb) / 2)
        dr.line([tuple(pa), tuple(pb)], fill=col, width=max(1, int(rad * 2)))
        for p in (pa, pb):
            dr.ellipse([p[0] - rad, p[1] - rad, p[0] + rad, p[1] + rad], fill=col)
    dr.text((6, 4), title, fill=(255, 255, 0))
    return img


def main(out):
    # (KnoxBite's numbers before the video: the left wrist's places and poles; the right's)
    ROLL, POLE_L = [-0.05, 1.20, 0.28], [0.6, -0.8, 0.05]
    OLD_POLE_R = (-0.6, -0.8, 0.05)
    LOOK, POLE_LOOK = [-0.07, 1.23, 0.27], [0.7, -0.7, 0.0]
    PARK_R, VIA_R = [-0.12, 0.92, 0.15], [-0.14, 1.0, 0.20]
    cases = [
        ("old: grip 0.03", pose(ROLL, POLE_L, 0.03, "old", poleR=OLD_POLE_R)),
        ("old: grip 0.62", pose(ROLL, POLE_L, 0.62, "old", poleR=OLD_POLE_R)),
        ("old: parked", pose(ROLL, POLE_L, wristR=PARK_R, poleR=OLD_POLE_R)),
        ("old: look, VIA_R", pose(LOOK, POLE_LOOK, wristR=VIA_R, poleR=OLD_POLE_R)),
    ]
    for name, w, p in (("new", NEW_ROLL, NEW_POLE),):
        for gs in (0.0, 0.3, 0.62):
            cases.append(("%s: grip %.2f" % (name, gs), pose(w, p, gs, "new")))
        cases.append(("new: parked", pose(w, p, wristR=PARK_R)))
    cases.append(("new: look, parked", pose(LOOK, POLE_LOOK, wristR=PARK_R)))
    tiles = []
    for name, o in cases:
        c = clear(o)
        extra = "" if c is None else "  clear %.3f" % c
        if "bend" in o:
            extra += "  bend %.0f  miss %.3f" % (o["bend"], o["miss"])
        print(name + extra)
        tiles.append(draw(o, name + extra))
    cols = 3
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (480 * cols, 270 * rows))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 480, (i // cols) * 270))
    sheet.save(out)


# KnoxBite's numbers now (jar 120): ROLL, POLE_L
NEW_ROLL, NEW_POLE = [-0.03, 1.08, 0.23], [0.85, -0.5, 0.1]

if __name__ == "__main__":
    main(sys.argv[1])
