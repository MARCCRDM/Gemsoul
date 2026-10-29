"""
Generates a kaiju's jump cues into assets/sounds/combat/, with the same
building blocks as tools/make_combat_sounds.py:

    kaiju_jump_1.mp3   springing up after you: a punchy "bwip" rising out
                       of a crouch, air rushing past, a short "hup" grunt
    kaiju_jump_2.mp3   (higher and quicker, a chirp in the grunt)
    kaiju_jump_3.mp3   (lower and heavier)
    kaiju_land_1.mp3   coming down: a deep thud, a crunch of ground and a
                       spatter of grit
    kaiju_land_2.mp3   (softer, a skid in it)

    pip install numpy scipy soundfile
    python tools/make_kaiju_jump_sounds.py

CreatureAnimation plays them at each kaiju's take-off and landing, sized to
it (FxSize: a knee-high kaiju's higher and lighter, a big one's deeper).
Upload them like the combat set (tools/upload_audio.py fills in the
KaijuJump1-3 and KaijuLand1-2 ids in src/client/Modules/CombatSound.luau);
until then built-in Roblox sounds stand in.
"""
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_combat_sounds import (  # noqa: E402
    OUT,
    SR,
    crackles,
    crunch,
    filt,
    finish,
    mix,
    n_of,
    noise,
    osc,
    room,
    sweep,
    t_of,
    thump,
    whoosh,
)


def bwip(f0, f1, seconds):
    """The spring: a sine shooting up in pitch, a fifth riding on it."""
    t = t_of(seconds)
    body = osc("sine", sweep(f0, f1, seconds), seconds) + 0.3 * osc("sine", sweep(f0 * 1.5, f1 * 1.5, seconds), seconds)
    return body * (1 - np.exp(-t / 0.004)) * np.exp(-t / (seconds * 0.35))


def hup(pitch, seconds, lo, hi):
    """A small creature's effort grunt: a buzzy throat through two formants."""
    t = t_of(seconds)
    throat = osc("saw", sweep(pitch, pitch * 1.25, seconds), seconds)
    voiced = filt(throat, "band", (lo, lo * 1.6)) + 0.6 * filt(throat, "band", (hi, hi * 1.4))
    return voiced * np.minimum(1, t / 0.01) * np.exp(-t / (seconds * 0.4))


def jump(v):
    low, high, grunt, f_lo, f_hi = [
        (150, 620, 150, 480, 1500),
        (220, 900, 210, 620, 1900),
        (110, 430, 110, 380, 1200),
    ][v]
    parts = [
        (0.0, thump(120, 60, 0.12, 0.03, 1.8) * 0.35),  # (pushing off)
        (0.0, crunch(0.04, 1600, 0.01) * 0.25),
        (0.01, bwip(low, high, 0.22) * 0.6),
        (0.0, whoosh(0.32, 500, 2600 + 400 * v, 0.3) * 0.9),
        (0.02, hup(grunt, 0.14, f_lo, f_hi) * 0.4),
    ]
    return room(mix(*parts), 0.2, 0.18)


def land(v):
    parts = [
        (0.0, thump(140, 42, 0.3, 0.07, 2.6) * 0.95),
        (0.0, crunch(0.09, 1800, 0.025) * 0.5),
        (0.01, crackles(7 if v == 0 else 4, 0.12, 1800, 0.35)),
        (0.0, filt(noise(0.25), "band", (300, 1400)) * np.exp(-t_of(0.25) / 0.06) * 0.25),  # (dust)
    ]
    if v == 1:
        parts.append((0.03, whoosh(0.18, 300, 900, 0.3) * 0.35))  # (a skid)
    return room(mix(*parts), 0.25, 0.2)


SOUNDS = {
    "kaiju_jump_1": (lambda: jump(0), 0.7),
    "kaiju_jump_2": (lambda: jump(1), 0.7),
    "kaiju_jump_3": (lambda: jump(2), 0.72),
    "kaiju_land_1": (lambda: land(0), 0.8),
    "kaiju_land_2": (lambda: land(1), 0.75),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (fn, peak) in SOUNDS.items():
        x = finish(np.asarray(fn(), dtype=np.float64), peak * 0.88)
        loud = np.nonzero(np.abs(x) > peak * 0.002)[0]
        end = min(len(x), (loud[-1] if len(loud) else len(x)) + n_of(0.02))
        x = x[:end]
        tail = min(len(x), n_of(0.03))
        x[-tail:] *= np.linspace(1, 0, tail)
        sf.write(os.path.join(OUT, name + ".mp3"), x.astype(np.float32), SR, format="MP3")
        print(f"{name:14s} {len(x) / SR * 1000:5.0f} ms")


if __name__ == "__main__":
    main()
