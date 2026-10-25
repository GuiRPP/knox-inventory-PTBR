# Road-card previews made for the frame (206 x 86 at 1080p; drawn 2x: 412 x 172).
# Each is the update's key element cut from its own news picture, set whole in the
# middle with air round it, its edges eased into Knox's dark with the sand grid -
# not a picture cropped to fill. A photo (the camp) fills the frame instead.
# (from the mockup's make_previews.py; the author's crops, 2026-10-25. The _en pictures
# lie as the _ru ones, so the same boxes serve both.)
#   python tools/make_road_previews.py   -> 42/media/knox/news/road/road_<name>_<lang>.png
import sys, os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
SRC = os.path.join(MOD, '42', 'media', 'knox', 'news')
OUT = os.path.join(SRC, 'road')
CAMP = os.path.join(HERE, 'art', 'screen_camp_three.png')
os.makedirs(OUT, exist_ok=True)
W, H = 412, 172
CELL = (14, 16, 16)
SAND = (212, 195, 138)

# name: (source, crop box x0,y0,x1,y1, mode)
P = {
    'u060': ('u060_split_ru.png', (40, 82, 830, 386), 'fit'),
    'u070': ('u070_tv_ru.png', (50, 140, 700, 505), 'fit'),
    'u080': ('screen_camp_three.png', None, 'photo'),
    'u090': ('u090_sizes_ru.png', (40, 78, 1124, 498), 'fit'),
    'u098': ('u098_sort_ru.png', (40, 85, 925, 470), 'fit'),
    'u0987': ('u0987_sound_ru.png', (40, 85, 1102, 533), 'fit'),
    'r10': ('r10_rigs_ru.png', (66, 88, 790, 520), 'fit'),
    'b3': ('b3_art_ru.png', (62, 178, 598, 344), 'fit'),  # the dashboard as it is now (beta 3): the sedan's gauges and key
    'g1': ('g1_banner_ru.png', (480, 0, 880, 204), 'fit'),
    'x1': ('x1_banner_ru.png', (425, 0, 881, 204), 'fit'),
    'e1': ('e1_bags_ru.png', (36, 88, 789, 444), 'fit'),
}

def backdrop():
    im = Image.new('RGB', (W, H), CELL)
    d = ImageDraw.Draw(im, 'RGBA')
    for x in range(0, W, 24):
        d.line([(x, 0), (x, H)], fill=SAND + (12,))
    for y in range(4, H, 24):
        d.line([(0, y), (W, y)], fill=SAND + (12,))
    return im

def feather(size, r):
    # an alpha mask: solid in the middle, eased to nothing over r px at every edge
    w, h = size
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rectangle([r, r, w - 1 - r, h - 1 - r], fill=255)
    return m.filter(ImageFilter.GaussianBlur(r / 2))

def vignette(im, strength):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).ellipse([-W * 0.25, -H * 0.6, W * 1.25, H * 1.6], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(40))
    dark = Image.new('RGB', (W, H), CELL)
    return Image.composite(im, Image.blend(im, dark, strength), m)

for lang in ('ru', 'en'):
    for name, (src, box, mode) in P.items():
        src = src.replace('_ru.', '_' + lang + '.')
        im = Image.open(CAMP if mode == 'photo' else os.path.join(SRC, src)).convert('RGB')
        if mode == 'photo':
            # fills the frame: the heroes round the fire
            tw = im.width * 0.66
            th = tw * H / W
            cx, cy = 760, 360
            part = im.crop((int(cx - tw / 2), int(cy - th / 2), int(cx + tw / 2), int(cy + th / 2))).resize((W, H), Image.LANCZOS)
            out = vignette(part, 0.55)
        else:
            part = im.crop(box)
            pad = 12
            k = min((W - pad * 2) / part.width, (H - pad * 2) / part.height)
            part = part.resize((max(1, round(part.width * k)), max(1, round(part.height * k))), Image.LANCZOS)
            out = backdrop()
            x, y = (W - part.width) // 2, (H - part.height) // 2
            out.paste(part, (x, y), feather(part.size, 5))
            out = vignette(out, 0.35)
        out.save(os.path.join(OUT, 'road_%s_%s.png' % (name, lang)))
        print(name, lang, part.size)
