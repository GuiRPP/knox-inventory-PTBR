# Draws the recorded calls of the real KnoxEditor (snap.ps1) with Knox's own font atlases,
# the lens picture and the game's item icons (drawn sharp, as news pictures draw them).
import sys, os, re, glob
from PIL import Image
mod, rdir, outdir, icondir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
fdir = os.path.join(mod, "42", "media", "fonts", "knox")
M = 12   # margin around the window
BG = (38, 41, 38)

fonts = {}
def font(key):
    if key not in fonts:
        chars = {}
        for line in open(os.path.join(fdir, key + ".fnt"), encoding="utf-8"):
            if line.startswith("char "):
                kv = dict(re.findall(r'(\w+)=(\S+)', line))
                chars[int(kv["id"])] = {k: int(kv[k]) for k in ("x", "y", "width", "height", "xoffset", "yoffset", "xadvance")}
        atlas = Image.open(os.path.join(fdir, key + "_0.png")).convert("RGBA").split()[3]
        fonts[key] = (chars, atlas)
    return fonts[key]

def clipbox(box, clip):
    x0, y0, x1, y1 = box
    if clip:
        x0, y0, x1, y1 = max(x0, clip[0]), max(y0, clip[1]), min(x1, clip[2]), min(y1, clip[3])
    return (x0, y0, x1, y1) if x1 > x0 and y1 > y0 else None

def fill(img, box, rgb, a, clip):
    b = clipbox(box, clip)
    if not b or a <= 0:
        return
    b = tuple(int(round(v)) for v in b)
    if b[2] <= b[0] or b[3] <= b[1]:
        return
    mask = Image.new("L", (b[2] - b[0], b[3] - b[1]), int(max(0, min(1, a)) * 255))
    img.paste(rgb, b, mask)

for path in sorted(glob.glob(os.path.join(rdir, "*.txt"))):
    lines = open(path, encoding="utf-8").read().splitlines()
    W = H = 0
    for l in lines:
        p = l.split(" ")
        if p[0] in ("R", "B"):
            W, H = max(W, float(p[1]) + float(p[3])), max(H, float(p[2]) + float(p[4]))
    img = Image.new("RGB", (int(W) + M * 2, int(H) + M * 2), BG)
    clip = None
    for l in lines:
        p = l.split(" ")
        k = p[0]
        if k == "S":
            x, y, w, h = map(float, p[1:5])
            clip = (x + M, y + M, x + w + M, y + h + M)
        elif k == "s":
            clip = None
        elif k in ("R", "B"):
            x, y, w, h, r, g, b, a = map(float, p[1:9])
            x, y = x + M, y + M
            rgb = (int(r * 255 + .5), int(g * 255 + .5), int(b * 255 + .5))
            if k == "R":
                fill(img, (x, y, x + w, y + h), rgb, a, clip)
            else:
                fill(img, (x, y, x + w, y + 1), rgb, a, clip)
                fill(img, (x, y + h - 1, x + w, y + h), rgb, a, clip)
                fill(img, (x, y + 1, x + 1, y + h - 1), rgb, a, clip)
                fill(img, (x + w - 1, y + 1, x + w, y + h - 1), rgb, a, clip)
        elif k == "L":
            x, y, w, h, r, g, b = map(float, p[1:8])
            lens = Image.open(os.path.join(mod, "42", "media", "ui", "knox_lens.png")).convert("RGBA").resize((int(w), int(h)), Image.LANCZOS)
            img.paste((int(r * 255 + .5), int(g * 255 + .5), int(b * 255 + .5)), (int(x) + M, int(y) + M, int(x) + M + lens.size[0], int(y) + M + lens.size[1]), lens.split()[3])
        elif k == "G":
            x, y, w, h = map(float, p[2:6])
            ic = Image.open(os.path.join(icondir, p[1] + ".png")).convert("RGBA")
            side = int(min(w, h))
            ic = ic.resize((side, side), Image.NEAREST)
            ox, oy = int(x + (w - side) / 2) + M, int(y + (h - side) / 2) + M
            if clip:
                c0 = (max(0, int(clip[0]) - ox), max(0, int(clip[1]) - oy), min(side, int(clip[2]) - ox), min(side, int(clip[3]) - oy))
                if c0[2] <= c0[0] or c0[3] <= c0[1]:
                    continue
                ic, ox, oy = ic.crop(c0), ox + c0[0], oy + c0[1]
            img.paste(ic.convert("RGB"), (ox, oy), ic.split()[3])
        elif k == "I":
            pass   # (the game's item pictures are in its packs: not drawn here)
        elif k == "T":
            key = p[1]
            x, y, r, g, b, a = map(float, p[2:8])
            text = [int(c) for c in p[8].split(",")] if len(p) > 8 and p[8] else []
            chars, atlas = font(key)
            rgb = (int(r * 255 + .5), int(g * 255 + .5), int(b * 255 + .5))
            pen = int(round(x)) + M
            ty = int(round(y)) + M
            for c in text:
                d = chars.get(c)
                if not d:
                    continue
                if d["width"] > 0 and d["height"] > 0:
                    gx, gy = pen + d["xoffset"], ty + d["yoffset"]
                    box = clipbox((gx, gy, gx + d["width"], gy + d["height"]), clip)
                    if box:
                        bx0, by0, bx1, by1 = (int(v) for v in box)
                        m = atlas.crop((d["x"] + bx0 - gx, d["y"] + by0 - gy, d["x"] + bx1 - gx, d["y"] + by1 - gy))
                        if a < 1:
                            m = m.point(lambda v: int(v * a))
                        img.paste(rgb, (bx0, by0, bx1, by1), m)
                pen += d["xadvance"]
    name = os.path.splitext(os.path.basename(path))[0]
    img.save(os.path.join(outdir, name + ".png"))
    print(name, img.size)
