# Knox's font atlases as a Lua table (FONTS) for the offline snaps: widths, offsets and
# each glyph's inked box (alpha >= 96), as KnoxTheme's knoxTextWidth / knoxTextInk give them.
import sys, os, re
from PIL import Image
mod, out = sys.argv[1], sys.argv[2]
fdir = os.path.join(mod, "42", "media", "fonts", "knox")

def parse_fnt(path):
    d = {"chars": {}}
    for line in open(path, encoding="utf-8"):
        kind = line.split(" ", 1)[0]
        kv = dict(re.findall(r'(\w+)=("[^"]*"|\S+)', line))
        if kind == "common":
            d["lh"], d["base"] = int(kv["lineHeight"]), int(kv["base"])
        elif kind == "char":
            d["chars"][int(kv["id"])] = {k: int(kv[k]) for k in ("x", "y", "width", "height", "xoffset", "yoffset", "xadvance")}
    return d

L = ["FONTS = {}"]
for style in ("body", "head", "title"):
    for size in range(10, 21):
        key = f"{style}_{size}"
        p = os.path.join(fdir, key + ".fnt")
        if not os.path.exists(p):
            continue
        f = parse_fnt(p)
        img = Image.open(os.path.join(fdir, key + "_0.png")).convert("RGBA")
        a = img.split()[3].load()
        rows = []
        for cid, c in f["chars"].items():
            t = (-1, -1, -1, -1)
            if c["width"] > 0 and c["height"] > 0:
                l, tp, r, b = 10**9, 10**9, -1, -1
                for yy in range(c["height"]):
                    for xx in range(c["width"]):
                        px, py = c["x"] + xx, c["y"] + yy
                        if px < img.width and py < img.height and a[px, py] >= 96:
                            l, r, tp, b = min(l, xx), max(r, xx), min(tp, yy), max(b, yy)
                if r >= 0:
                    t = (l, tp, r, b)
            rows.append("[%d]={%d,%d,%d,%d,%d,%d,%d,%d,%d}" % (cid, c["xadvance"], c["xoffset"], c["yoffset"], c["width"], c["height"], *t))
        L.append('FONTS["%s"] = {lh=%d, ch={%s}}' % (key, f["lh"], ",".join(rows)))
open(os.path.join(out, "fonts.lua"), "w", encoding="utf-8").write("\n".join(L) + "\n")

print("fonts ok")
