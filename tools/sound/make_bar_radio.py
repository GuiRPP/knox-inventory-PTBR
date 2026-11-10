# The winter bar's broken radio: its interference (the author, 2026-11-01: more of it, and not
# one noise over and over). Six kinds (the crackle went, the author 2026-11-01) of fault, several takes of each, every take made on its
# own; KnoxBarRadio.java picks them. Made by Knox, nothing recorded: run again to make them anew.
#   python tools/sound/make_bar_radio.py
# Into 42/media/sound/knox_radio/bar_<kind>_<n>.wav: 22050 Hz, mono, 16 bit, as air.wav.
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "42", "media", "sound", "knox_radio")


def write(name, s, peak):
    top = max(1e-6, max(abs(v) for v in s))
    # (no click at either end)
    edge = min(len(s) // 4, int(RATE * 0.006))
    for i in range(edge):
        k = i / edge
        s[i] *= k
        s[-1 - i] *= k
    frames = b"".join(struct.pack("<h", int(max(-1, min(1, v / top * peak)) * 32767)) for v in s)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f"{name}: {len(s) / RATE:.2f} s")


class Band:
    """A resonant band-pass; its frequency may change as it runs."""

    def __init__(self, q):
        self.q, self.a, self.b = q, 0.0, 0.0

    def run(self, x, hz):
        f = 2 * math.sin(math.pi * min(hz, RATE / 6) / RATE)
        self.b += f * self.a
        high = x - self.b - self.a / self.q
        self.a += f * high
        return self.a


def crackle(r):
    """Dust on a bad joint: ticks in clusters, thicker and thinner as it goes."""
    n = int(RATE * r.uniform(1.2, 3.0))
    s = [0.0] * n
    wave_at = r.uniform(0.6, 2.2)
    for i in range(n):
        density = 0.0015 + 0.012 * max(0.0, math.sin(i / RATE * wave_at * 6.28 + 1)) ** 3
        if r.random() < density:
            hz, amp = r.uniform(900, 5000), r.uniform(0.15, 1.0)
            decay = r.uniform(0.82, 0.97)
            for k in range(min(160, n - i)):
                s[i + k] += amp * decay ** k * math.sin(k * 6.283 * hz / RATE)
    return s


def buzz(r):
    """The mains getting in through a loose earth: a hum full of edges, coming and going."""
    n = int(RATE * r.uniform(0.9, 2.6))
    hz = r.choice([50, 60, 100, 120]) * r.uniform(0.99, 1.01)
    phase, gate, s = 0.0, 0.0, []
    change = 0
    want = 1.0
    for i in range(n):
        if i >= change:
            change = i + int(RATE * r.uniform(0.02, 0.3))
            want = r.choice([0.0, 0.25, 0.6, 1.0, 1.0])
        gate += (want - gate) * 0.01
        phase = (phase + hz / RATE) % 1
        saw = 2 * phase - 1
        s.append(gate * (saw * 0.6 + (1 if phase < 0.1 else 0) + r.uniform(-0.05, 0.05)))
    return s


def whistle(r):
    """Another station beating with this one: a thin tone that slides, each take its own way."""
    n = int(RATE * r.uniform(0.8, 2.8))
    a, b = r.uniform(500, 2400), r.uniform(500, 2400)
    bend = r.uniform(0.5, 2.5)
    wobble, wobble_hz = r.uniform(5, 40), r.uniform(3, 9)
    phase, s = 0.0, []
    for i in range(n):
        t = i / n
        hz = a + (b - a) * t ** bend + wobble * math.sin(i / RATE * 6.283 * wobble_hz)
        phase += 6.283 * hz / RATE
        s.append(math.sin(phase) * math.sin(math.pi * t) ** 0.6 + r.uniform(-0.04, 0.04))
    return s


def sputter(r):
    """The amplifier motorboating: low pulses that speed up or give up."""
    n = int(RATE * r.uniform(0.7, 2.2))
    hz0, hz1 = r.uniform(4, 16), r.uniform(4, 22)
    low = Band(2.0)
    phase, s = 0.0, []
    for i in range(n):
        t = i / n
        phase = (phase + (hz0 + (hz1 - hz0) * t) / RATE) % 1
        pulse = math.exp(-phase * 9)
        s.append(low.run(r.uniform(-1, 1) * pulse + pulse * 0.6, 170 + 200 * pulse))
    return s


def surge(r):
    """The air rising through the band: noise with a slow sweep in it."""
    n = int(RATE * r.uniform(1.0, 3.6))
    a, b = r.uniform(400, 1300), r.uniform(900, 3200)
    band = Band(r.uniform(2.5, 7))
    s = []
    flick = r.uniform(5, 15)
    for i in range(n):
        t = i / n
        level = math.sin(math.pi * t) ** 1.4 * (0.75 + 0.25 * math.sin(i / RATE * 6.283 * flick))
        s.append(level * band.run(r.uniform(-1, 1), a + (b - a) * t))
    return s


def pop(r):
    """A contact closing: one knock of the cone, a tail or none."""
    n = int(RATE * r.uniform(0.08, 0.35))
    hz, decay = r.uniform(70, 260), r.uniform(0.9985, 0.9996) ** 3
    s = []
    for i in range(n):
        s.append(decay ** i * (math.sin(i * 6.283 * hz / RATE) + r.uniform(-1, 1) * 0.5 * 0.994 ** i))
    return s


def ghost(r):
    """Some other station, far off: a voice's rhythm and vowels, no words."""
    n = int(RATE * r.uniform(1.6, 3.8))
    f1, f2 = Band(5), Band(7)
    phase, s = 0.0, []
    pitch = r.uniform(90, 190)
    syllable_end, vowel, on = 0, (500, 1400), 1.0
    level = 0.0
    fading = r.uniform(0.7, 2.0)
    for i in range(n):
        if i >= syllable_end:
            syllable_end = i + int(RATE * r.uniform(0.07, 0.3))
            vowel = (r.uniform(300, 850), r.uniform(900, 2300))
            on = 0.0 if r.random() < 0.25 else 1.0
            pitch *= r.uniform(0.94, 1.06)
        level += (on - level) * 0.004
        phase = (phase + pitch / RATE) % 1
        source = (1.0 if phase < 0.12 else -0.12) + r.uniform(-0.1, 0.1)
        far = 0.55 + 0.45 * math.sin(i / RATE * 6.283 * fading)
        s.append(level * far * (f1.run(source, vowel[0]) + 0.7 * f2.run(source, vowel[1])))
    return s


# kind: how made, takes, its peak (how loud this kind is against the others)
KINDS = {
    "crackle": (crackle, 4, 0.7),
    "buzz": (buzz, 3, 0.4),
    "whistle": (whistle, 4, 0.3),
    "sputter": (sputter, 3, 0.65),
    "surge": (surge, 3, 0.55),
    "pop": (pop, 4, 0.8),
    "ghost": (ghost, 3, 0.4),
}

if __name__ == "__main__":
    # (a fixed seed: the same files each time this is run, unless it is changed)
    rnd = random.Random(20261101)
    for kind, (make, takes, peak) in KINDS.items():
        for take in range(1, takes + 1):
            take_made = make(rnd)
            # (the crackle is still made, unwritten: the others come out as the author heard them)
            if kind != "crackle":
                write(f"bar_{kind}_{take}", take_made, peak)
