"""
Generates the rift critters' evil giggles into assets/sounds/combat/, with
the same building blocks as tools/make_combat_sounds.py and the kaiju roars
(tools/make_kaiju_sounds.py):

    critter_giggle_1.mp3   a quick, squeaky "hee-hee-hee", falling
    critter_giggle_2.mp3   a snicker: "hih-hih-hih-hee", higher, tighter
    critter_giggle_3.mp3   a gleeful run of "hee"s that speeds up
    critter_cackle.mp3     a nasty "nyeh-heh-heh-heh", lower and rattling

    pip install numpy scipy soundfile
    python tools/make_critter_sounds.py

Upload them like the combat set (tools/upload_audio.py fills in the
Giggle1, Giggle2, Giggle3 and Cackle ids in
src/client/Modules/CombatSound.luau); until then built-in Roblox sounds
stand in.
"""
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_combat_sounds import (  # noqa: E402
    OUT,
    SR,
    drive,
    filt,
    finish,
    mix,
    n_of,
    noise,
    osc,
    phase,
    room,
    t_of,
)

RNG = np.random.default_rng(23)


def contour(seconds, points):
    """A pitch track through (time share, Hz) points."""
    t = np.linspace(0, 1, n_of(seconds))
    xs, ys = zip(*points)
    return np.interp(t, xs, ys)


def formants(x, peaks):
    """A mouth: band passes at (low, high, gain) resonances."""
    return sum(filt(x, "band", (lo, hi)) * gain for lo, hi, gain in peaks)


# A tiny throat's vowels: "ee" (hee), "ih" (hih) and "eh" (heh, nyeh).
VOWELS = {
    "ee": [(240, 420, 1.0), (2100, 2700, 0.85), (2900, 3600, 0.35)],
    "ih": [(360, 560, 1.0), (1800, 2400, 0.7), (2600, 3300, 0.3)],
    "eh": [(480, 720, 1.0), (1600, 2100, 0.65), (2400, 3000, 0.25)],
}


def syllable(f_start, f_end, seconds, vowel="ee", aspirate=0.35, rasp=0.0, nasal=False):
    """One laugh syllable: a breathy "h" onset into a buzzing vowel whose
    pitch falls (a giggle's lilt), with a little vibrato and rattle."""
    f0 = contour(seconds, [(0, f_start), (0.25, f_start * 1.04), (1, f_end)])
    vibrato = 1 + 0.025 * np.sin(phase(np.full(len(f0), 11.0)))
    buzz = osc("saw", f0 * vibrato) + 0.55 * osc("saw", f0 * 1.009 * vibrato) + 0.25 * osc("square", f0 * 2)
    if rasp > 0:
        rattle = 0.5 + 0.5 * np.sin(phase(np.full(len(f0), 42.0)))
        buzz *= (1 - rasp) + rasp * rattle
    voiced = formants(buzz, VOWELS[vowel])
    if nasal:
        # "nyeh": a nasal hum at the front of the syllable.
        hum = filt(buzz, "band", (220, 420)) * np.clip(1 - t_of(seconds) / (seconds * 0.35), 0, 1)
        voiced = voiced + hum * 0.8
    t = t_of(seconds)
    shape = np.clip(t / 0.012, 0, 1) * np.clip((seconds - t) / (seconds * 0.45), 0, 1) ** 1.3
    breath = filt(noise(seconds), "band", (1500, 7000)) * np.exp(-t / 0.025) * aspirate
    return (voiced * shape + breath) * 0.6


def laugh(steps, gap, fall=0.86, start=0.0, **kw):
    """A run of syllables: steps = [(f_start, f_end, seconds, vowel)], each
    the last's pitch times `fall`, `gap` seconds of breath between."""
    parts, at = [], start
    for f_start, f_end, seconds, vowel in steps:
        parts.append((at, syllable(f_start, f_end, seconds, vowel, **kw)))
        at += seconds + gap * RNG.uniform(0.85, 1.15)
    return mix(*parts)


def giggle_1():
    base = 880
    steps = []
    for i in range(5):
        f = base * (0.9**i)
        steps.append((f, f * 0.78, 0.085, "ee"))
    x = laugh(steps, 0.045)
    return room(drive(x * 1.2, 1.6), 0.18, 0.18)


def giggle_2():
    steps = []
    for i in range(3):
        f = 980 * (0.95**i)
        steps.append((f, f * 0.85, 0.06, "ih"))
    steps.append((1060, 700, 0.16, "ee"))  # ...and a squeal to finish
    x = laugh(steps, 0.035, aspirate=0.45)
    return room(drive(x * 1.3, 1.8), 0.16, 0.16)


def giggle_3():
    steps, gaps, at = [], [], 0.0
    parts = []
    for i in range(7):
        f = 760 + 60 * np.sin(i * 1.3) + 25 * i
        seconds = 0.095 - i * 0.006
        parts.append((at, syllable(f, f * 0.8, seconds, "ee")))
        at += seconds + max(0.022, 0.06 - i * 0.006)  # (it speeds up)
    x = mix(*parts)
    return room(drive(x * 1.2, 1.6), 0.2, 0.2)


def cackle():
    parts = [(0.0, syllable(560, 470, 0.17, "eh", aspirate=0.15, rasp=0.35, nasal=True))]
    at = 0.21
    for i in range(5):
        f = 600 * (0.93**i)
        seconds = 0.075
        parts.append((at, syllable(f, f * 0.8, seconds, "eh", aspirate=0.5, rasp=0.45)))
        at += seconds + 0.04
    x = mix(*parts)
    # A gritty throat under it: nasty, not cute.
    x = drive(filt(x, "high", 180) * 1.5, 2.4)
    return room(x, 0.28, 0.24)


SOUNDS = {
    "critter_giggle_1": (giggle_1, 0.72),
    "critter_giggle_2": (giggle_2, 0.7),
    "critter_giggle_3": (giggle_3, 0.72),
    "critter_cackle": (cackle, 0.78),
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
        print(f"{name:18s} {len(x) / SR * 1000:5.0f} ms")


if __name__ == "__main__":
    sys.exit(main())
