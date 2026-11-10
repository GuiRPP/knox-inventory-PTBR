# The heroes' clips as pictures without the game (2026-11-02, the sleeper's stirs redone after
# the author's video): the game's male body skinned to a clip's bones (Knox_Bar*.x, written by
# poses.py), the counter and the whiskey bottle as boxes, seen from the menu's camera and
# from his side. Not the game: no clothes, hair or the room's light - for the body's motion
# only (the arm's path, the hand against the bottle, the head on the counter). Run:
#   python sheet.py out.png|out.gif Knox_BarWakeA [fps] [cols] [view]   (view: game|side|front)
import math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw

import clips
from clips import Clip

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(os.path.dirname(HERE))
BODY = os.path.join(os.path.dirname(os.path.dirname(clips.GAME)), "models_X", "Skinned", "MaleBody.x")
SCALE = 1.5
U = 1 / 1.22
HERO_Y = 0.20
TOP = 1.1 * U - HERO_Y
# the menu's camera (KnoxBarFrame.camera) from the first hero's place (KnoxMenuSceneBar.lua SEATS)
HERO = [-1.75 * U, HERO_Y, 0.05 * U]
EYE = [-3.4 * U, 1.95 * U, 3.9 * U]
AT = [-1.0 * U, 1.25 * U, -5.0 * U]


def read_body():
    text = open(BODY, encoding="latin-1").read()
    body = text[text.index("Mesh Body {"):]
    nums = iter(re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", body[:body.index("MeshNormals")]))
    n = int(next(nums))
    verts = np.array([[float(next(nums)) for _ in range(3)] for _ in range(n)])
    faces = []
    for _ in range(int(next(nums))):
        k = int(next(nums))
        f = [int(next(nums)) for _ in range(k)]
        for i in range(1, k - 1):
            faces.append((f[0], f[i], f[i + 1]))
    skin = []
    for m in re.finditer(r'SkinWeights \{\s*"(\w+)";\s*(\d+);(.*?)\}', body, re.S):
        c = int(m.group(2))
        v = re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", m.group(3))
        idx = [int(x) for x in v[:c]]
        w = [float(x) for x in v[c:2 * c]]
        o = [float(x) for x in v[2 * c:2 * c + 16]]
        off = np.array([[o[j * 4 + i] for j in range(4)] for i in range(4)])
        skin.append((m.group(1), np.array(idx, dtype=int), np.array(w), off))
    return verts, np.array(faces), skin


class Body:
    def __init__(self):
        self.verts, self.faces, self.skin = read_body()
        self.h = np.hstack([self.verts, np.ones((len(self.verts), 1))])

    def skinned(self, world):
        """world(bone) -> 4x4 in the skeleton's space; the vertices in the hero's scene space."""
        out = np.zeros((len(self.verts), 3))
        for bone, idx, w, off in self.skin:
            m = np.array(world(bone)) @ off
            out[idx] += (self.h[idx] @ m.T)[:, :3] * w[:, None]
        out *= SCALE
        out[:, 2] *= -1
        return out


def look(eye, at):
    f = np.array(at, float) - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return np.array(eye, float), r, u, f


def views(name):
    hero = np.array(HERO)
    if name == "game":
        # (from the menu's camera, looking at him: his part of the frame, closer than its fov 32)
        eye, r, u, f = look(np.array(EYE) - hero, np.array([0.0, TOP + 0.05, 0.45]))
        return eye, r, u, f, 2.0 / math.tan(math.radians(7))
    if name == "side":
        return look(np.array([-1.3, TOP + 0.35, 0.45]), np.array([0.0, TOP + 0.05, 0.42])) + (2.0 / math.tan(math.radians(17)),)
    return look(np.array([-0.35, TOP + 0.55, 1.6]), np.array([0.0, TOP + 0.08, 0.4])) + (2.0 / math.tan(math.radians(14)),)


def box(x0, x1, y0, y1, z0, z1):
    p = [[x, y, z] for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    q = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return [[p[i] for i in f] for f in q]


def cylinder(c, r, h, tip_deg=0.0, tip_x=0.0, roll_z=0.0):
    # the whiskey bottle: upright at c, tipped over its foot's +x edge, rolled on along z
    n = 10
    out = []
    a = math.radians(tip_deg)

    def place(p):
        x, y, z = p[0] - r, p[1], p[2]
        x, y = x * math.cos(-a) - y * math.sin(-a), x * math.sin(-a) + y * math.cos(-a)
        return [c[0] + x + r, c[1] + y, c[2] + z + roll_z]
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        for y0, y1, rr0, rr1 in ((0, h * 0.62, r, r), (h * 0.62, h * 0.78, r, r * 0.38), (h * 0.78, h, r * 0.38, r * 0.38)):
            out.append([place([rr0 * math.cos(a0), y0, rr0 * math.sin(a0)]), place([rr0 * math.cos(a1), y0, rr0 * math.sin(a1)]),
                        place([rr1 * math.cos(a1), y1, rr1 * math.sin(a1)]), place([rr1 * math.cos(a0), y1, rr1 * math.sin(a0)])])
    return out


LIGHT = np.array([0.4, 0.8, 0.45]) / np.linalg.norm([0.4, 0.8, 0.45])


def render(body_pts, faces, extra, view, size=(360, 300)):
    eye, r, u, f, focal = view
    w, h = size
    ss = 2
    img = Image.new("RGB", (w * ss, h * ss), (38, 42, 48))
    d = ImageDraw.Draw(img)
    polys = []

    def proj(p):
        v = np.asarray(p, float) - eye
        z = v @ f
        return (w * ss / 2 + (v @ r) / z * focal * h * ss / 4, h * ss / 2 - (v @ u) / z * focal * h * ss / 4), z

    tri = body_pts[faces]
    nrm = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    nrm /= np.linalg.norm(nrm, axis=1)[:, None] + 1e-9
    for t, n in zip(tri, nrm):
        pts, zs = zip(*(proj(p) for p in t))
        lit = 0.35 + 0.65 * abs(float(n @ LIGHT))
        polys.append((sum(zs) / 3, pts, tuple(int(c * lit) for c in (205, 180, 160))))
    for quads, colour in extra:
        for q in quads:
            q = np.array(q, float)
            n = np.cross(q[1] - q[0], q[2] - q[0])
            n /= np.linalg.norm(n) + 1e-9
            pts, zs = zip(*(proj(p) for p in q))
            lit = 0.45 + 0.55 * abs(float(n @ LIGHT))
            polys.append((sum(zs) / len(zs), pts, tuple(int(c * lit) for c in colour)))
    polys.sort(key=lambda x: -x[0])
    for _, pts, col in polys:
        d.polygon(pts, fill=col)
    return img.resize((w, h), Image.LANCZOS)


def counter():
    # (its near edge 0.43 m before the hero, 0.7 m deep, from his right well past his left; in
    # small boxes, for the painter's order against the arms on it)
    out = []
    xs, zs = np.linspace(-0.75, 0.7, 13), np.linspace(0.43 * U, 1.13 * U, 7)
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            out += box(xs[i], xs[i + 1], TOP - 0.06, TOP, zs[j], zs[j + 1])
    return out


def main():
    out, name = sys.argv[1], sys.argv[2]
    fps = float(sys.argv[3]) if len(sys.argv) > 3 else 10
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 8
    vname = sys.argv[5] if len(sys.argv) > 5 else "game"
    # bottle: x,z (scene, the hero's space) and knock time s, or none (-Dbottle in poses' print)
    bottle = [float(x) for x in os.environ.get("SHEET_BOTTLE", "%f,%f" % ((-1.795 + 1.75) * U, (0.825 - 0.05) * U)).split(",") if x] or None
    knock = float(os.environ.get("SHEET_KNOCK", "-1"))
    clips.GAME = os.path.join(MOD, "42", "media", "anims_X", "Bob")
    clip = Clip(name)
    body = Body()
    view = views(vname)
    seconds = clip.ticks / 4800
    n = int(seconds * fps) + 1
    frames = []
    for i in range(n):
        t = min(clip.ticks, i * 4800 / fps)
        pts = body.skinned(lambda b: clip.world(b, t) if b in clip.parent else np.eye(4))
        extra = [(counter(), (120, 82, 52))]
        if bottle:
            s = i / fps - knock if knock >= 0 else -1
            k = min(1.0, s / 0.3)
            tip = 0 if s < 0 else 90 * (0.4 * k + 0.6 * k * k)
            roll = 0 if s < 0.3 else 0.55 * U * (s - 0.3)
            if roll < 0.335 * U:
                extra.append((cylinder([bottle[0], TOP, bottle[1]], 0.042 * U, 0.318 * U, tip, 0, roll), (60, 90, 60)))
        img = render(pts, body.faces, extra, view)
        ImageDraw.Draw(img).text((6, 4), "%.1f s" % (i / fps), fill=(230, 230, 230))
        frames.append(img)
    if out.endswith(".gif"):
        # (moving, at the clip's own speed, a still second of the rest before it)
        frames = [frames[0]] * int(fps) + frames + [frames[-1]] * int(fps)
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0)
        print(out, len(frames), "frames", "%.2f s" % seconds)
        return
    w, h = frames[0].size
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (0, 0, 0))
    for i, im in enumerate(frames):
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    sheet.save(out)
    print(out, len(frames), "frames", "%.2f s" % seconds)


if __name__ == "__main__":
    main()
