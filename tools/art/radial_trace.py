"""The game's own emote pictures, drawn in Knox's «Чертёж» style (the author, 2026-10-23: our
hand-drawn hands and heads were not right - take the game's real silhouettes instead).

For every picture: its shape from the alpha, smoothed by drawing it big; filled dark, outlined light;
the lines inside it from the picture's own shading; red and yellow parts (crosses, marks) keep their
meaning in Knox's red / the skin's colour. Writes a sheet to look at: the game's picture, then ours
at 92 px and 40 px on a slice's colour.

  python tools/art/radial_trace.py <icons dir> <out.png> name [name ...]
"""
import sys, colorsys
from PIL import Image, ImageFilter, ImageChops, ImageDraw, ImageFont

SRC, OUT, NAMES = sys.argv[1], sys.argv[2], sys.argv[3:]
BIG = 512                      # working size
FILL = (0x2a, 0x2e, 0x2e)
LINE = (0xc4, 0xca, 0xc2)
INNER = (0x8f, 0x92, 0x89)
ACC = (0xd4, 0xc3, 0x8a)
BAD = (0xd6, 0x5f, 0x52)
SLICE = (0x1a, 0x1d, 0x1d)


def kind(rgb):
    r, g, b = [v / 255 for v in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s > 0.45 and v > 0.35:
        if h < 0.04 or h > 0.93:
            return 'red'
        if 0.09 < h < 0.18:
            return 'yellow'
    return 'body'


def trace(path):
    im = Image.open(path).convert('RGBA')
    # trim to the visible part, square, with a margin
    bb = im.getchannel('A').point(lambda a: 255 if a > 40 else 0).getbbox()
    im = im.crop(bb)
    side = max(im.size)
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    k = (BIG * 0.86) / side
    up = sq.resize((round(side * k), round(side * k)), Image.LANCZOS)
    canvas = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    canvas.paste(up, ((BIG - up.width) // 2, (BIG - up.height) // 2), up)
    a = canvas.getchannel('A').filter(ImageFilter.GaussianBlur(3)).point(lambda v: 255 if v > 120 else 0)
    # the parts by colour, from the small picture (nearest, so colours are not mixed)
    near = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    nup = sq.resize(up.size, Image.NEAREST)
    near.paste(nup, ((BIG - up.width) // 2, (BIG - up.height) // 2), nup)
    red = Image.new('L', (BIG, BIG), 0); yel = Image.new('L', (BIG, BIG), 0)
    sm = sq.convert('RGBA'); cls = {}
    px = near.load(); rp = red.load(); yp = yel.load()
    for y in range(BIG):
        for x in range(BIG):
            c = px[x, y]
            if c[3] < 40:
                continue
            key = c[:3]
            kd = cls.get(key) or cls.setdefault(key, kind(key))
            if kd == 'red':
                rp[x, y] = 255
            elif kd == 'yellow':
                yp[x, y] = 255
    red = red.filter(ImageFilter.GaussianBlur(3)).point(lambda v: 255 if v > 120 else 0)
    yel = yel.filter(ImageFilter.GaussianBlur(3)).point(lambda v: 255 if v > 120 else 0)
    body = ImageChops.subtract(ImageChops.subtract(a, red), yel)
    out = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    w = 14                                         # outline width at BIG (~1.1 px at 40)
    er = body.filter(ImageFilter.MinFilter(w * 2 + 1))
    out.paste(LINE + (255,), (0, 0), body)
    out.paste(FILL + (255,), (0, 0), er)
    # lines inside: where the game's shading changes sharply (its own drawn edges), inside the body
    g = canvas.convert('L').filter(ImageFilter.GaussianBlur(2.2))
    edges = g.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 26 else 0)
    edges = ImageChops.multiply(edges, er.filter(ImageFilter.MinFilter(9)))
    edges = edges.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: 255 if v > 110 else 0)
    out.paste(INNER + (255,), (0, 0), edges)
    out.paste(BAD + (255,), (0, 0), red)
    out.paste(ACC + (255,), (0, 0), yel)
    return out


def tile(img, px):
    t = Image.new('RGBA', (px + 8, px + 8), SLICE + (255,))
    s = img.resize((px, px), Image.LANCZOS)
    t.paste(s, (4, 4), s)
    return t


cells = []
for n in NAMES:
    src = Image.open(f'{SRC}/{n}.png').convert('RGBA')
    ours = trace(f'{SRC}/{n}.png')
    c = Image.new('RGBA', (330, 140), (0x12, 0x14, 0x14, 255))
    o = Image.new('RGBA', (100, 100), SLICE + (255,)); sr = src.resize((92, 92), Image.NEAREST); o.paste(sr, (4, 4), sr)
    c.paste(o, (8, 8)); c.paste(tile(ours, 92), (122, 8)); c.paste(tile(ours, 40), (236, 34))
    ImageDraw.Draw(c).text((8, 116), n + '   (игра -> «Чертёж» 92 / 40)', fill=(0x8f, 0x92, 0x89, 255))
    cells.append(c)
cols = 3
rows = (len(cells) + cols - 1) // cols
sheet = Image.new('RGBA', (cols * 338, rows * 148), (0x0b, 0x0c, 0x0c, 255))
for i, c in enumerate(cells):
    sheet.paste(c, ((i % cols) * 338, (i // cols) * 148))
sheet.save(OUT)
print('ok', OUT)
