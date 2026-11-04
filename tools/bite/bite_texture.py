# The narrator's bite (KnoxBite; the author's video 2026-11-02: no bite to be seen). The game's own
# (BodyDmg/MaleBody01_bites_lower_left_arm) is on the back of the forearm, halfway up - under the rolled
# cuff, and turned away while the inside of the forearm is to the eyes. The same pixels moved to the
# inside of the forearm (the palm's side: the body's faces 100-103), a third of the way up from the
# wrist, clear of the cuff. Run from this folder:
#   python bite_texture.py [--preview <out.png>]
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(os.path.dirname(HERE))
GAME = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
SRC = os.path.join(GAME, "media", "textures", "BodyDmg", "MaleBody01_bites_lower_left_arm.png")
OUT = os.path.join(MOD, "42", "media", "textures", "knoxmenu", "bite_lower_left_arm.png")
# the game's bite (its centre about 227.5 94.5 of 256) to the inside of the forearm: that side's strip
# is u 233-244, v 95 (0.62 of the way from the elbow) to 116 (the wrist); its centre then 238.5 104.5
MOVE = (11, 10)
# the inside's quad on the skin (MaleBody.X's UVs), for the preview
INSIDE = [(233.9, 94.3), (244.2, 97.6), (243.0, 116.7), (232.1, 115.6)]


def main():
    src = Image.open(SRC).convert("RGBA")
    a = np.array(src)
    out = np.zeros_like(a)
    dx, dy = MOVE
    h, w = a.shape[:2]
    out[dy:, dx:] = a[:h - dy, :w - dx]
    Image.fromarray(out).save(OUT)
    print("written", OUT, "bbox", Image.fromarray(out).getbbox())
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        body = Image.open(os.path.join(GAME, "media", "textures", "Body", "MaleBody01.png")).convert("RGBA")
        skin = Image.alpha_composite(body, Image.fromarray(out)).resize((1024, 1024), Image.NEAREST)
        d = ImageDraw.Draw(skin)
        d.polygon([(u * 4, v * 4) for u, v in INSIDE], outline=(0, 160, 255))
        skin.crop((840, 300, 1024, 500)).resize((552, 600), Image.NEAREST).save(sys.argv[2])


if __name__ == "__main__":
    main()
