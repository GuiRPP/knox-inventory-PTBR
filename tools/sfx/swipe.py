# The menu's swipe sound (the author, 2026-11-02: not sharp, not drawing the ear): air going past, made
# here, nobody's recording. Filtered noise, its pitch and strength rising to the swipe's fastest moment
# (0.37 s, KnoxMenuScene's swipeWay), a long way down; it crosses the stereo the way the scene goes.
#   python tools\sfx\swipe.py   ->  42\media\sound\knox_swipe_ltr.wav, knox_swipe_rtl.wav
import math
import os
import wave

import numpy as np

RATE, LENGTH, PEAK_AT = 44100, 1.3, 0.37
LEVEL = 0.22   # of full scale, at its loudest (the volume in the game: KnoxCamp.SWIPE_VOL)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "42", "media", "sound")

n = int(RATE * LENGTH)
t = np.arange(n) / RATE
noise = np.random.default_rng(1102).standard_normal(n)


def rise_fall(rise, fall):
    # smooth up to the peak, a long smooth way down, nothing at the ends
    up = np.clip(t / PEAK_AT, 0, 1)
    down = np.clip((t - PEAK_AT) / (LENGTH - PEAK_AT), 0, 1)
    return np.where(t < PEAK_AT, up ** rise, (0.5 + 0.5 * np.cos(np.pi * down)) ** fall)


# a band-pass following the swipe, two poles, run over the noise (a state-variable filter)
shape = rise_fall(1.6, 1.3)
freq = 170.0 + 620.0 * shape
low = band = 0.0
out = np.zeros(n)
for i in range(n):
    f = 2.0 * math.sin(math.pi * freq[i] / RATE)
    low += f * band
    high = noise[i] - low - 0.9 * band
    band += f * high
    out[i] = band + 0.35 * low
out *= rise_fall(2.0, 1.6)
# nothing of the very low left to thump
out -= np.convolve(out, np.ones(1100) / 1100, mode="same")
# no click at either end
edge = int(0.02 * RATE)
out[:edge] *= np.linspace(0, 1, edge)
out[-edge:] *= np.linspace(1, 0, edge)
out *= LEVEL / np.max(np.abs(out))

# from one side to the other by the swipe's way, not hard to either: a sound of the room, not of an ear
way = np.clip(t / (2 * PEAK_AT), 0, 1)
way = way * way * (3 - 2 * way)
pan = (0.2 + 0.6 * way) * np.pi / 2


def write(name, left, right):
    data = np.empty(2 * n, dtype=np.int16)
    data[0::2] = (left * 32767).astype(np.int16)
    data[1::2] = (right * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


write("knox_swipe_ltr.wav", out * np.cos(pan), out * np.sin(pan))
write("knox_swipe_rtl.wav", out * np.sin(pan), out * np.cos(pan))
rms = np.sqrt(np.mean(out ** 2)) * 32767
print("peak %.0f, rms %.0f, loudest 50 ms at %.2f s" % (np.max(np.abs(out)) * 32767, rms,
    np.argmax(np.convolve(out ** 2, np.ones(2205), mode="same")) / RATE))
