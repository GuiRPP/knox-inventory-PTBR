# The pinned post's pictures (the Boosty post with the roadmap; the author's mockup
# .claude/mockups/boosty/boosty_v1.html, 2026-10-25) -> 42/media/ui/knoxmenu/pinned/.
# Everything the mockup draws with CSS gradients, masks and 3D that Knox draws in PZ
# with textures: the card's banner (the camp under its dark gradient, baked), the logos,
# the coin's glint as frames (it must stay inside the round face: PZ has no masks),
# soft light, a fade, the shimmer's band, the contour map, the bottom bar's coin, the pin.
#   python tools\make_pinned_art.py
import os, re, math
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
ART = os.path.join(HERE, 'art')
MOCK = os.path.join(MOD, '.claude', 'mockups', 'boosty')
OUT = os.path.join(MOD, '42', 'media', 'ui', 'knoxmenu', 'pinned')
os.makedirs(OUT, exist_ok=True)

def save(im, name):
    im.save(os.path.join(OUT, name), optimize=True)
    print(name, im.size)

# the card's banner: as the mockup's .card.pin .ban - the camp 440 px wide at 60, -70 of a
# 365 x 98 card, under the dark gradient from the left; drawn 2.5x (the card fills it whole)
K = 2.5
CW, CH = round(365 * K), round(98 * K)
camp = Image.open(os.path.join(ART, 'screen_camp_three.png')).convert('RGB')
bw = round(440 * K)
bh = round(camp.height * bw / camp.width)
camp = camp.resize((bw, bh), Image.LANCZOS)
card = Image.new('RGB', (CW, CH), (18, 20, 20))
card.paste(camp, (round(60 * K), round(-70 * K)))
stops = [(0, .96), (.5, .88), (.78, .3), (1, .05)]
grad = Image.new('L', (CW, 1))
for x in range(CW):
    f = x / (CW - 1)
    for (a, va), (b, vb) in zip(stops, stops[1:]):
        if a <= f <= b:
            grad.putpixel((x, 0), round(255 * (va + (vb - va) * (f - a) / (b - a))))
            break
dark = Image.new('RGB', (CW, CH), (18, 20, 20))
card = Image.composite(dark, card, grad.resize((CW, CH)))
save(card, 'banner.png')

# the logos: the coin's face (knox_logo_avatar, the existing one - no new one drawn) whole,
# and smaller copies for the support block (64 px) and the bottom bar's tooltip (30 px):
# PZ scales a texture down without mipmaps, a 640 px one at 30 px is all jaggies
logo = Image.open(os.path.join(ART, 'knox_logo_avatar.png')).convert('RGBA')
save(logo, 'logo.png')
clean = Image.open(os.path.join(ART, 'knox_logo_avatar_clean.png')).convert('RGBA')
save(clean.resize((128, 128), Image.LANCZOS), 'logo_clean_128.png')
save(clean.resize((64, 64), Image.LANCZOS), 'logo_clean_64.png')

# the coin's glint: .coin3d .glint - linear-gradient(115deg, 0 at 38%, .38 at 49%, .08 at 53%,
# 0 at 62%), background-size 300%, at background-position p (0..1); white, alpha = its light,
# inside the face's circle. GLINT frames from p = 0 to 1.
GLINT, GS = 32, 256
gstops = [(0, 0), (.38, 0), (.49, .38), (.53, .08), (.62, 0), (1, 0)]
def gval(f):
    for (a, va), (b, vb) in zip(gstops, gstops[1:]):
        if a <= f <= b:
            return va + (vb - va) * (f - a) / max(1e-9, b - a)
    return 0
mask = Image.new('L', (GS * 4, GS * 4), 0)
ImageDraw.Draw(mask).ellipse([4, 4, GS * 4 - 5, GS * 4 - 5], fill=255)
mask = mask.resize((GS, GS), Image.LANCZOS)
ang = math.radians(115)
dx, dy = math.sin(ang), -math.cos(ang)      # CSS: 0deg points up, 90deg right
half = (abs(dx) * 3 * GS + abs(dy) * GS) / 2  # the gradient line's half length over the 300% box
for i in range(GLINT):
    p = i / (GLINT - 1)
    ox = -(3 * GS - GS) * p                   # the 300% box's left in the face's px
    im = Image.new('LA', (GS, GS), (255, 0))
    px = im.load()
    for y in range(GS):
        for x in range(GS):
            bx, by = x - ox - 1.5 * GS, y - GS / 2   # from the box's middle
            f = ((bx * dx + by * dy) + half) / (2 * half)
            px[x, y] = (255, round(255 * gval(f)))
    a = Image.composite(im.getchannel('A'), Image.new('L', (GS, GS), 0), mask)
    out = Image.new('RGBA', (GS, GS), (255, 255, 255, 0))
    out.putalpha(a)
    save(out, 'glint_%02d.png' % i)

# soft light: radial, 1 in the middle, .3 at 55 %, nothing from 80 % (the head's fire, the
# bands of the road's cards, the warmth from below, the glow behind the coin; tinted in Lua)
G = 256
glow = Image.new('L', (G, G))
for y in range(G):
    for x in range(G):
        r = math.hypot(x - G / 2 + .5, y - G / 2 + .5) / (G / 2)
        v = 1 - r / .55 * .7 if r < .55 else (.3 * (1 - (r - .55) / .25) if r < .8 else 0)
        glow.putpixel((x, y), round(255 * max(0, v)))
g = Image.new('RGBA', (G, G), (255, 255, 255, 0)); g.putalpha(glow)
save(g, 'glow.png')

# a fade: transparent on the left, white on the right (lines fading out, gradients)
fade = Image.new('RGBA', (256, 4), (255, 255, 255, 0))
for x in range(256):
    for y in range(4):
        fade.putpixel((x, y), (255, 255, 255, round(255 * x / 255)))
save(fade, 'fade.png')

# the shimmer's band across: .shine's 38..62 % of its gradient - .22 at 47, .34 at 50, .22 at 53
bstops = [(0, 0), (.0833, 0), (.375, .22 / .34), (.5, 1), (.625, .22 / .34), (.9167, 0), (1, 0)]
band = Image.new('RGBA', (128, 4), (255, 255, 255, 0))
for x in range(128):
    f = x / 127
    for (a, va), (b, vb) in zip(bstops, bstops[1:]):
        if a <= f <= b:
            v = va + (vb - va) * (f - a) / max(1e-9, b - a)
            break
    for y in range(4):
        band.putpixel((x, y), (255, 255, 255, round(255 * v)))
save(band, 'band.png')

# the contour map (topo.svg of the mockup: lines only), drawn at 1.5x, white (tinted in Lua)
svg = open(os.path.join(MOCK, 'topo.svg'), encoding='utf-8').read()
S = 1.5
SS = 3
TW, TH = round(1048 * S), round(860 * S)
big = Image.new('L', (TW * SS, TH * SS), 0)
d = ImageDraw.Draw(big)
for m in re.finditer(r'<path d="([^"]*)"[^>]*?stroke-width="([\d.]+)"', svg):
    w = max(1, round(float(m.group(2)) * S * SS))
    cur = None
    for cmd, x, y in re.findall(r'([ML])([\d.\-]+) ([\d.\-]+)', m.group(1)):
        pt = (float(x) * S * SS, float(y) * S * SS)
        if cmd == 'L' and cur:
            d.line([cur, pt], fill=255, width=w)
        cur = pt
topo = Image.new('RGBA', (TW, TH), (255, 255, 255, 0))
topo.putalpha(big.resize((TW, TH), Image.LANCZOS))
save(topo, 'topo.png')

# the bottom bar's coin (#coinSmall of the mockup, 22 px at 1080p): two coins, lines only;
# the front one filled with the bar's colour to hide the back one. Two layers drawn 4x,
# each tinted in Lua: the fill and the lines.
C, Q = 88, 4
def coin_layers():
    big_l = Image.new('L', (C * Q, C * Q), 0)
    big_f = Image.new('L', (C * Q, C * Q), 0)
    k = C * Q / 22
    dl, df = ImageDraw.Draw(big_l), ImageDraw.Draw(big_f)
    def ring(dr, cx, cy, r, w):
        dr.ellipse([(cx - r - w / 2) * k, (cy - r - w / 2) * k, (cx + r + w / 2) * k, (cy + r + w / 2) * k], fill=255)
        dr.ellipse([(cx - r + w / 2) * k, (cy - r + w / 2) * k, (cx + r - w / 2) * k, (cy + r - w / 2) * k], fill=0)
    ring(dl, 13.6, 8.6, 6.4, 1.5)
    # the front coin hides the back one under it
    dl.ellipse([(8.8 - 6.9) * k, (13.2 - 6.9) * k, (8.8 + 6.9) * k, (13.2 + 6.9) * k], fill=0)
    df.ellipse([(8.8 - 6.9) * k, (13.2 - 6.9) * k, (8.8 + 6.9) * k, (13.2 + 6.9) * k], fill=255)
    ring(dl, 8.8, 13.2, 6.9, 1.5)
    inner = Image.new('L', (C * Q, C * Q), 0)
    ring(ImageDraw.Draw(inner), 8.8, 13.2, 4.3, 1.0)
    lines = big_l.copy()
    lines.paste(Image.eval(inner, lambda v: round(v * .6)), (0, 0), inner)
    return lines.resize((C, C), Image.LANCZOS), big_f.resize((C, C), Image.LANCZOS)
lines, fill = coin_layers()
for name, a in (('coin_lines.png', lines), ('coin_fill.png', fill)):
    im = Image.new('RGBA', (C, C), (255, 255, 255, 0)); im.putalpha(a)
    save(im, name)

# the pin of the PINNED plate (the mockup's #pin, 9 x 11, turned 45 degrees), 4x, white
PW = 9 * 4
pin = Image.new('L', (PW * 4, PW * 4), 0)
pts = [(2, 0), (7, 0), (7, 1.2), (6.2, 1.7), (6.2, 4.7), (8, 6.3), (8, 7.3), (5.1, 7.3), (5.1, 11), (3.9, 11),
       (3.9, 7.3), (1, 7.3), (1, 6.3), (2.8, 4.7), (2.8, 1.7), (2, 1.2)]
k = PW * 4 / 11
cx, cy = 4.5, 5.5
a = math.radians(45)
poly = []
for x, y in pts:
    x, y = x - cx, y - cy
    poly.append(((x * math.cos(a) - y * math.sin(a)) * k * .78 + PW * 2, (x * math.sin(a) + y * math.cos(a)) * k * .78 + PW * 2))
ImageDraw.Draw(pin).polygon(poly, fill=255)
p = Image.new('RGBA', (PW, PW), (255, 255, 255, 0)); p.putalpha(pin.resize((PW, PW), Image.LANCZOS))
save(p, 'pin.png')
