# The mod list's pictures (the author, 2026-11-08), called by make_modlist_art.ps1:
#   42\poster.png  256x256 - the winter preview's still: the bar in the blizzard under the
#                  ice-skin poster, a bag carried into the grid, WITHOUT the "Winter is
#                  coming" plate (the author: "убери оттуда плашку")
#   42\icon.png    64x64   - the ice badge (tools\art\knox_logo_avatar_winter.png)
#   tools\art\poster_modlist_ice_1024.png - the poster at full size
# Usage: python make_modlist_art.py <root> <overlay ov_NNN.png> <video frame 1024x700 png>
import sys
from PIL import Image

root, ov_path, vid_path = sys.argv[1], sys.argv[2], sys.argv[3]
S = 1024
ov = Image.open(ov_path).convert('RGBA')
if ov.size != (S, S):
    sys.exit('the overlay is not 1024x1024: ' + ov_path)
px = ov.load()

# The plate (make_poster2.ps1 DrawWinterAt, x 164..858, y 490..539 of 1024) is drawn
# opaque over the bar's fade: each of its rows gets the fade's pixel from the same row
# left of the panel (x 120), so the bar shows through as it does around the plate.
X0, X1, Y0, Y1 = 160, 864, 486, 544
REF_X = 120
for y in range(Y0, Y1):
    ref = px[REF_X, y]
    for x in range(X0, X1):
        p = px[x, y]
        if p[3] > 200 and (y < 541 or not (p[0] < 20 and p[1] < 20)):
            px[x, y] = ref

base = Image.new('RGBA', (S, S), (9, 12, 15, 255))   # the ice skin's screen (#090c0f)
base.paste(Image.open(vid_path).convert('RGBA'), (0, 0))
out = Image.alpha_composite(base, ov).convert('RGB')
out.save(root + r'\tools\art\poster_modlist_ice_1024.png')
out.resize((256, 256), Image.LANCZOS).save(root + r'\42\poster.png')

icon = Image.open(root + r'\tools\art\knox_logo_avatar_winter.png').convert('RGBA')
icon.resize((64, 64), Image.LANCZOS).save(root + r'\42\icon.png')
print('42\\poster.png, 42\\icon.png, tools\\art\\poster_modlist_ice_1024.png written')
