# The preview's overlays with the skin changing softly (the author, 2026-11-05: the sand skin while
# the string of lights burns, the ice one while it is off, "smoother"): called by make_poster_gif.ps1
# -SandFrames. Mixes gif_frames (ice) with gif_frames_sand frame by frame, back into gif_frames.
#   python tools\mix_skin_frames.py <tools\art> <first sand frame> <last sand frame> <frames of the change>
import glob
import os
import sys
from PIL import Image

art, first, last, fade = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])


def ease(v):
    v = max(0.0, min(1.0, v))
    return v * v * (3 - 2 * v)


for path in sorted(glob.glob(os.path.join(art, "gif_frames", "ov_*.png"))):
    name = os.path.basename(path)
    f = int(name[3:6])
    if f <= last:
        k = ease((f - first + 1) / fade)     # (comes in from the moment the lights do)
    else:
        k = 1 - ease((f - last) / fade)      # (goes from the moment they are off)
    if k <= 0:
        continue
    ice = Image.open(path).convert("RGBA")
    sand = Image.open(os.path.join(art, "gif_frames_sand", name)).convert("RGBA")
    Image.blend(ice, sand, k).save(path)
