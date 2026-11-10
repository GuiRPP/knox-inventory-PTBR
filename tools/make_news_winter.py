# The pictures of the news post "Winter is coming" (update 11, the author 2026-11-05):
# the card's banner from the bar in the blizzard, the logo for the Boosty plate and the face of
# the coin on the right (the author, the same day: the coin and "thank you" there, in the Ice style).
#   tools\art\screen_bar_menu.png            -> 42\media\knox\news\u11_bar_banner.png
#   tools\art\knox_logo_avatar_clean_winter  -> 42\media\ui\knoxmenu\pinned\logo_clean_128_winter.png
#   tools\art\knox_logo_avatar_winter        -> 42\media\ui\knoxmenu\pinned\logo_winter.png
#   python tools\make_news_winter.py
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
ART = os.path.join(HERE, "art")
NEWS = os.path.join(MOD, "42", "media", "knox", "news")
PINNED = os.path.join(MOD, "42", "media", "ui", "knoxmenu", "pinned")

BANNER_W, BANNER_H = 912, 204   # (a card's banner)


def main():
    shot = Image.open(os.path.join(ART, "screen_bar_menu.png")).convert("RGB")

    # the banner: a band through the middle of the scene, dark under the card's text on the left
    k = BANNER_W / shot.width
    wide = shot.resize((BANNER_W, round(shot.height * k)), Image.LANCZOS)
    top = max(0, round((wide.height - BANNER_H) * 0.45))
    band = wide.crop((0, top, BANNER_W, top + BANNER_H))
    px = band.load()
    for x in range(BANNER_W):
        f = x / BANNER_W
        d = 0.16 + 0.84 * min(1, max(0, (f - 0.05) / 0.75)) ** 1.4
        for y in range(BANNER_H):
            r, g, b = px[x, y]
            px[x, y] = (round(r * d + 8 * (1 - d)), round(g * d + 11 * (1 - d)), round(b * d + 14 * (1 - d)))
    band.save(os.path.join(NEWS, "u11_bar_banner.png"), optimize=True)

    # the logo
    logo = Image.open(os.path.join(ART, "knox_logo_avatar_clean_winter.png")).convert("RGBA")
    logo.resize((128, 128), Image.LANCZOS).save(os.path.join(PINNED, "logo_clean_128_winter.png"), optimize=True)

    # the coin's face, whole, as the gold coin's (tools\make_pinned_art.py)
    Image.open(os.path.join(ART, "knox_logo_avatar_winter.png")).convert("RGBA").save(os.path.join(PINNED, "logo_winter.png"), optimize=True)
    print("ok")


main()
