"""
Generates the legendary find's window cue into assets/sounds/combat/, with
the same building blocks as tools/make_combat_sounds.py:

    legendary_window.mp3   a Legendary mined: a deep boom as the light
                           shoots up, a rising "shwing" as the window
                           snaps open, then a bright major chord of bells
                           and brass-ish saws that rings out under a
                           sparkling tail

    pip install numpy scipy soundfile
    python tools/make_legendary_sounds.py

LegendaryWindow plays it (CombatSound's LegendaryWindow). Upload it like
the combat set (tools/upload_audio.py fills in its id in
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
    filt,
    finish,
    fm,
    mix,
    n_of,
    noise,
    osc,
    room,
    sweep,
    t_of,
    thump,
)


def bell(freq, seconds, decay):
    t = t_of(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2.0 * t)
    sheen = fm(freq * 2, 3.5, 1.3, seconds, index_decay=0.06) * 0.22
    return (tone + sheen) * (1 - np.exp(-t / 0.002)) * np.exp(-t / decay)


def brass(freq, seconds):
    """A bright stab: detuned saws through a filter that opens then closes."""
    t = t_of(seconds)
    saw = sum(osc("saw", freq * d, seconds) for d in (0.996, 1.0, 1.004)) / 3
    bright = filt(saw, "low", 4200) * np.exp(-t / 0.18) + filt(saw, "low", 1400) * (1 - np.exp(-t / 0.18))
    return bright * np.minimum(1, t / 0.012) * np.exp(-t / (seconds * 0.4))


def shwing(seconds):
    """Air rushing up into the opening: band noise and a tone gliding up."""
    t = t_of(seconds)
    x = filt(noise(seconds), "band", (1500, 7000))
    rise = osc("sine", sweep(600, 2400, seconds), seconds) * 0.35
    shape = (t / seconds) ** 2
    return (x * 0.7 + rise) * shape


def sparkle(seconds, count, rng):
    parts = []
    for _ in range(count):
        f = rng.uniform(2400, 6000)
        parts.append((rng.uniform(0, seconds * 0.7), bell(f, 0.35, 0.07) * rng.uniform(0.08, 0.2)))
    return mix(*parts)


def legendary_window():
    rng = np.random.default_rng(77)
    root = 523.25  # C5: a major chord, an octave and a fifth over it
    chord = [root, root * 1.25, root * 1.5, root * 2, root * 3]
    parts = [
        (0.0, thump(110, 34, 0.6, 0.18, 2.8) * 0.9),
        (0.0, shwing(0.32) * 0.55),
    ]
    for i, f in enumerate(chord):
        parts.append((0.3 + i * 0.012, bell(f, 1.8, 0.7 - i * 0.08) * (0.5 - i * 0.05)))
    for f in (root / 2, root * 0.75, root):
        parts.append((0.3, brass(f, 0.9) * 0.22))
    parts.append((0.34, sparkle(1.6, 22, rng)))
    return room(mix(*parts), 0.5, 0.32)


SOUNDS = {"legendary_window": (legendary_window, 0.82)}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (fn, peak) in SOUNDS.items():
        x = finish(np.asarray(fn(), dtype=np.float64), peak * 0.88)
        loud = np.nonzero(np.abs(x) > peak * 0.002)[0]
        end = min(len(x), (loud[-1] if len(loud) else len(x)) + n_of(0.02))
        x = x[:end]
        tail = min(len(x), n_of(0.05))
        x[-tail:] *= np.linspace(1, 0, tail)
        sf.write(os.path.join(OUT, name + ".mp3"), x.astype(np.float32), SR, format="MP3")
        print(f"{name:18s} {len(x) / SR * 1000:5.0f} ms")


if __name__ == "__main__":
    main()
