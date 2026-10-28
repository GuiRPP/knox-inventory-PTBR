# The drop reason plate's pictures (42/media/ui/knoxreason/*.png) and their
# measures (42/media/lua/client/Knox/KnoxReasonIcons.lua), from icons.html: the
# approved mockup's drawing (style "Чертёж", the author 2026-10-28). Edge draws
# the sheet white on black; the light becomes the alpha of a white picture
# (tinted in the game: the base in the text's colour, the mark in red).
# Each picture is cut to the ink of both its layers; "top" and "bottom" are the
# rows of the base layer's ink (the picture is centred by them, the red piece
# sticking out of "no room" left out - the critic, icons round 3).
#
# Usage: python -I tools/reason_icons/make.py
import os, subprocess, sys, time
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "42", "media", "ui", "knoxreason")
LUA = os.path.join(ROOT, "42", "media", "lua", "client", "Knox", "KnoxReasonIcons.lua")
SIZES = [20, 22, 24, 26, 28, 30, 32, 36, 40, 44, 48, 56, 64]   # as in icons.html
NAMES = ["far", "full", "grow"]
CELL = 72
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

sheet = os.path.join(os.environ.get("TEMP", HERE), "knox_reason_sheet.png")
if os.path.exists(sheet):
    os.remove(sheet)
prof = os.path.join(os.environ.get("TEMP", HERE), "knox_reason_edge")
subprocess.run([EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                "--user-data-dir=" + prof, "--virtual-time-budget=3000",
                "--window-size=%d,%d" % (CELL * 6, CELL * len(SIZES)), "--screenshot=" + sheet,
                "file:///" + os.path.join(HERE, "icons.html").replace("\\", "/")],
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
for _ in range(60):
    if os.path.exists(sheet):
        break
    time.sleep(0.5)
time.sleep(0.5)
im = Image.open(sheet).convert("L")

def cell(i, j):
    return im.crop((i * CELL, j * CELL, (i + 1) * CELL, (j + 1) * CELL))

def white(alpha):
    out = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out

os.makedirs(OUT, exist_ok=True)
lines = []
for n, name in enumerate(NAMES):
    lines.append("    %s = {" % name)
    for j, s in enumerate(SIZES):
        base, mark = cell(n * 2, j), cell(n * 2 + 1, j)
        # (cut to the union of the two layers' ink)
        bb, mb = base.getbbox(), mark.getbbox()
        box = (min(bb[0], mb[0]), min(bb[1], mb[1]), max(bb[2], mb[2]), max(bb[3], mb[3]))
        white(base.crop(box)).save(os.path.join(OUT, "%s_%d_base.png" % (name, s)))
        white(mark.crop(box)).save(os.path.join(OUT, "%s_%d_mark.png" % (name, s)))
        w, h = box[2] - box[0], box[3] - box[1]
        lines.append("        [%d] = {w = %d, h = %d, top = %d, bottom = %d}," % (s, w, h, bb[1] - box[1], bb[3] - 1 - box[1]))
    lines.append("    },")

with open(LUA, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- Made by tools/reason_icons/make.py - do not edit by hand.\n")
    f.write("-- The drop reason plate's pictures (media/ui/knoxreason/<name>_<size>_base|mark.png):\n")
    f.write("-- each cut to its ink; w, h its size, top..bottom the rows of its base layer's ink.\n")
    f.write("KnoxReasonIcons = {\n")
    f.write("    sizes = {%s},\n" % ", ".join(str(s) for s in SIZES))
    f.write("\n".join(lines) + "\n}\n")
print("made %d pictures, %s" % (len(NAMES) * len(SIZES) * 2, os.path.relpath(LUA, ROOT)))
