# The journal's page in the bar (the author, 2026-11-02): Artlist recordings the author picked
# (42/CREDITS.txt), cut to one page each and set to the loudness the game's rustle had there.
# Each file's middle (its sound's weight in time) is printed for KnoxBarSound.PAGE_PEAK: it starts
# the file so that moment meets the page standing up (KnoxBarFrame.movePage, half its 0.8 s).
# The scrunched sheet is a long crinkle: two pages cut from it.
#   the sources: tools\step_samples\pages (not in git, as the licence asks)
#   python tools\sfx\bar_pages.py   ->  42\media\sound\knox_page\page_1..4.ogg, pencil_floor.ogg
import os
import subprocess
import wave

import numpy as np

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "step_samples", "pages")
OUT = os.path.join(HERE, "..", "..", "42", "media", "sound", "knox_page")
# (the loudest 0.1 s of the game's PZ_CloseBag.wav, rms: the bar played it at 0.1-0.15)
LOUD = 0.121
# (file, from, to; seconds in the recording)
SCRUNCH = "SpillAudio - Crumples - Scrunching Piece of Paper.wav"
CUTS = [
    ("Mechanical Wave - Paper - Newspaper Turning Page.wav", 0.15, 1.05),
    ("SpillAudio - Crumples - Book Page Flipping Back and Forth.wav", 0.20, 0.98),
    (SCRUNCH, 0.10, 0.72),
    (SCRUNCH, 0.74, 1.27),
]


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def loudest(x):
    w = int(0.1 * RATE)
    p = np.convolve(x * x, np.ones(w) / w, mode="valid")
    return float(np.sqrt(p.max()))


os.makedirs(OUT, exist_ok=True)
middles = []
for i, (name, a, b) in enumerate(CUTS, 1):
    x = load(os.path.join(SRC, name))[int(a * RATE):int(b * RATE)].copy()
    x *= LOUD / loudest(x)
    fin, fout = int(0.015 * RATE), int(0.12 * RATE)
    x[:fin] *= np.linspace(0, 1, fin)
    x[-fout:] *= np.linspace(1, 0, fout) ** 2
    x = np.clip(x, -1, 1)
    tmp = os.path.join(OUT, "page_%d.wav" % i)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6",
                    os.path.join(OUT, "page_%d.ogg" % i)], check=True)
    os.remove(tmp)
    e = x * x
    middle = float(np.sum(e * np.arange(len(x))) / np.sum(e)) / RATE
    middles.append("%.2ff" % middle)
    print("page_%d.ogg  %.2f s, its middle at %.2f s" % (i, b - a, middle))
print("PAGE_PEAK = {%s}" % ", ".join(middles))

# The pencil on the floor (the author, 2026-11-02): "Pencil Falling on Wood" from after its first
# knock (the author: not the first one), its bounce taken as the knock on the floor, PENCIL_HIT into
# the file; as loud as the floor's knock of the old made-up sound (0.177, the loudest 20 ms, rms)
PENCIL_SRC, PENCIL_FROM, PENCIL_HIT = "Matching Sound Effects - Stationery - Pencil Falling on Wood.wav", 0.3707, 0.01
x = load(os.path.join(SRC, PENCIL_SRC))[int((PENCIL_FROM - PENCIL_HIT) * RATE):].copy()
w = int(0.02 * RATE)
x *= 0.177 / float(np.sqrt(np.convolve(x * x, np.ones(w) / w, mode="valid").max()))
fout = int(0.15 * RATE)
x[-fout:] *= np.linspace(1, 0, fout) ** 2
x = np.clip(x, -1, 1)
tmp = os.path.join(OUT, "pencil_floor.wav")
with wave.open(tmp, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((x * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6",
                os.path.join(OUT, "pencil_floor.ogg")], check=True)
os.remove(tmp)
print("pencil_floor.ogg  %.2f s, the knock at %.2f s" % (len(x) / RATE, PENCIL_HIT))
