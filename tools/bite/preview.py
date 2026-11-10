# The rolled sleeve offline (roll_sleeve.py --preview): the body and the jacket at bind, the sleeve rolled
# by 0, a half and all of it, from three sides. A check of the shape only - flat colours, not the game.
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "barframe"))
import sheet as body_sheet   # noqa: E402
import drawing               # noqa: E402


def shade(p, faces, base):
    fn = np.cross(p[faces[:, 1]] - p[faces[:, 0]], p[faces[:, 2]] - p[faces[:, 0]])
    fn /= np.linalg.norm(fn, axis=1)[:, None] + 1e-9
    light = np.array([0.3, 0.8, 0.5]) / np.linalg.norm([0.3, 0.8, 0.5])
    return (0.35 + 0.65 * np.abs(fn @ light))[:, None] * np.array(base)


def sheet(m, rolled, out, skin=None):
    body = body_sheet.Body()
    if skin is not None:
        # (the narrator's own body: slim_arms.py)
        body.verts, body.faces = skin.verts, skin.faces
    E = m.bind("Bip01_L_Forearm")[:3, 3]
    W = m.bind("Bip01_L_Hand")[:3, 3]
    c = (E + W) / 2
    rows = []
    for k in (0.0, 0.5, 1.0):
        jacket = rolled(m, k)
        pts = np.vstack([body.verts, jacket])
        nb = len(body.verts)
        faces = np.vstack([body.faces, m.faces + nb])
        cols = np.vstack([shade(pts, body.faces, drawing.SKIN), shade(pts, m.faces + nb, (70, 90, 120))])
        row = []
        for d in ([0, 0.3, 1], [0, 1, 0.15], [0.2, -0.4, 1]):
            d = np.array(d, float) / np.linalg.norm(d)
            eye = c + d * 0.45
            r, u, f = drawing.basis(eye, c)
            row.append(drawing.raster(Image.new("RGB", (360, 260), (30, 30, 34)), pts, faces, cols, eye, r, u, f, 600))
        rows.append(row)
    img = Image.new("RGB", (360 * 3, 260 * 3))
    for j, row in enumerate(rows):
        for i, im in enumerate(row):
            img.paste(im, (i * 360, j * 260))
    img.save(out)
    print("preview ->", out)
