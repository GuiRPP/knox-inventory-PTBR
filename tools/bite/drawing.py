# Faces drawn over a picture with a depth buffer, flat colours: what the arms' checks here look through.
# (From the first sketch of the moment, tools/barframe/bite.py, gone in the overhaul's cleanup, 2026-11-04.)
import numpy as np
from PIL import Image

SKIN = (176, 146, 128)
LIGHT = np.array([0.5, 0.7, 0.5]) / np.linalg.norm([0.5, 0.7, 0.5])


def basis(eye, target):
    f = np.asarray(target, float) - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


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
