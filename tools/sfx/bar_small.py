# The bar's small sounds (the author, 2026-11-02), made here, nobody's recording:
#   knox_pencil_roll.wav  the pencil rolling to the counter's edge, 0.76 s (KnoxBarFrame's movePencil:
#                         its roll, then 1.1 m of falling: on the floor at 1.23 s, an Artlist recording
#                         the author picked, tools\sfx\bar_pages.py)
#   python tools\sfx\bar_small.py   ->  42\media\sound
import os
import wave

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "42", "media", "sound")
rng = np.random.default_rng(1102)


def band(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], btype="band", fs=RATE, output="sos"), x)


def write(name, x, level):
    x = x * level / np.max(np.abs(x))
    edge = int(0.004 * RATE)
    x[:edge] *= np.linspace(0, 1, edge)
    x[-edge:] *= np.linspace(1, 0, edge)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(name, "%.2f s, rms %.4f" % (len(x) / RATE, np.sqrt(np.mean(x ** 2))))


def tap(n, at, strength, pitch):
    """A pencil's end on boards: a dry knock of a few short tones."""
    t = np.arange(n) / RATE - at
    x = np.zeros(n)
    live = t >= 0
    for f, decay, a in ((1250, 0.018, 1.0), (2850, 0.009, 0.7), (5200, 0.005, 0.4), (420, 0.012, 0.5)):
        x[live] += a * np.sin(2 * np.pi * f * pitch * t[live]) * np.exp(-t[live] / decay)
    return x * strength


def pencil():
    n = int(0.9 * RATE)
    t = np.arange(n) / RATE
    # rolling: a tick for each of its six sides, faster and faster (half of 0.9 m/s2, 11 mm a turn... a side)
    x = np.zeros(n)
    roll = 0.76
    z = 0.45 * t * t
    sides = np.floor(z / 0.0058)
    ticks = np.zeros(n)
    ticks[1:] = (np.diff(sides) > 0) * (t[1:] < roll)
    x += band(ticks * (0.55 + 0.45 * rng.random(n)), 900, 4200) * 2.2 * np.clip(t / 0.3, 0.25, 1)
    return x


# (as loud as the roll was in the old knox_pencil_fall.wav, its floor at 0.55)
write("knox_pencil_roll.wav", pencil(), 0.1265)
