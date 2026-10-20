"""
Generates the level up and kaiju team cues into assets/sounds/combat/, with
the same building blocks as tools/make_combat_sounds.py:

    level_up.mp3         a miner levels up: a low struck plate, then a
                         rising fifth-and-octave chord of soft bells that
                         swells and rings out, a shimmer over the top
    kaiju_level_up.mp3   a kaiju levels up: the same rise, brighter and
                         shorter, a growl of a sub under it
    call_back.mp3        a kaiju called back into its Gemsoul: a glassy
                         tone falling, folding into a click
    deploy.mp3           a kaiju deployed: the click, then a glassy tone
                         rising and opening out

    pip install numpy scipy soundfile
    python tools/make_levelup_sounds.py

Upload them like the combat set (tools/upload_audio.py fills in the
LevelUp, KaijuLevelUp, CallBack and Deploy ids in
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
    PLATE,
    SR,
    click,
    filt,
    finish,
    fm,
    mix,
    modal,
    n_of,
    noise,
    osc,
    room,
    sweep,
    t_of,
)

RNG = np.random.default_rng(41)


def bell(freq, seconds, decay):
    """A soft struck bell: a sine and its octave, an FM sheen that dies fast."""
    t = t_of(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2.0 * t)
    sheen = fm(freq * 2, 3.5, 1.4, seconds, index_decay=0.08) * 0.25
    shape = (1 - np.exp(-t / 0.004)) * np.exp(-t / decay)
    return (tone + sheen) * shape


def swell(freq, seconds, rise):
    """A pad tone that swells up over `rise` and fades: the chord's body."""
    t = t_of(seconds)
    tone = osc("tri", freq, seconds) * 0.6 + np.sin(2 * np.pi * freq * 1.002 * t) * 0.4
    shape = np.minimum(1, t / rise) * np.exp(-np.maximum(0, t - rise) / (seconds * 0.35))
    return filt(tone, "low", 2600) * shape


def shimmer(seconds, lo, hi):
    """Air over the top: filtered noise with a fast flutter."""
    x = filt(noise(seconds), "band", (lo, hi))
    t = t_of(seconds)
    flutter = 0.6 + 0.4 * np.sin(2 * np.pi * 17 * t)
    shape = np.minimum(1, t / 0.15) * np.exp(-t / (seconds * 0.4))
    return x * flutter * shape


def level_up():
    root = 220.0  # A3: a fifth and octaves over it
    notes = [root, root * 1.5, root * 2, root * 3, root * 4]
    parts = [(0.0, modal(root / 2, PLATE, (0.5, 0.35, 0.25, 0.18, 0.12, 0.08), (1, 0.6, 0.4, 0.3, 0.2, 0.12), 1.2) * 0.7)]
    for i, f in enumerate(notes):
        parts.append((0.06 + i * 0.075, bell(f, 1.6, 0.55 - i * 0.05) * (0.8 - i * 0.08)))
    parts.append((0.05, swell(root * 2, 1.5, 0.35) * 0.35))
    parts.append((0.05, swell(root * 3, 1.5, 0.35) * 0.22))
    parts.append((0.2, shimmer(1.2, 5000, 11000) * 0.12))
    return room(mix(*parts), 0.45, 0.32)


def kaiju_level_up():
    root = 293.66  # D4: brighter than a miner's
    notes = [root, root * 1.5, root * 2, root * 3]
    parts = [(0.0, osc("sine", sweep(90, 55, 0.5), 0.5) * np.exp(-t_of(0.5) / 0.18) * 0.7)]
    for i, f in enumerate(notes):
        parts.append((0.04 + i * 0.06, bell(f, 1.1, 0.4 - i * 0.04) * (0.75 - i * 0.08)))
    parts.append((0.15, shimmer(0.9, 6000, 12000) * 0.1))
    return room(mix(*parts), 0.35, 0.28)


def glass(f0, f1, seconds):
    """A glassy tone gliding from f0 to f1."""
    freq = sweep(f0, f1, seconds)
    t = t_of(seconds)
    tone = np.sin(2 * np.pi * np.cumsum(freq) / SR) + 0.3 * np.sin(2 * np.pi * 2.01 * np.cumsum(freq) / SR)
    shape = np.minimum(1, t / 0.02) * np.exp(-t / (seconds * 0.5))
    return tone * shape


def call_back():
    parts = [(0.0, glass(1400, 380, 0.42) * 0.6), (0.38, click(0.014, 2200) * 0.5)]
    parts.append((0.0, shimmer(0.4, 3000, 8000) * 0.12))
    return room(mix(*parts), 0.25, 0.25)


def deploy():
    parts = [(0.0, click(0.014, 2200) * 0.5), (0.03, glass(380, 1500, 0.5) * 0.6)]
    parts.append((0.08, shimmer(0.5, 3000, 9000) * 0.12))
    return room(mix(*parts), 0.3, 0.28)


SOUNDS = {
    "level_up": (level_up, 0.8),
    "kaiju_level_up": (kaiju_level_up, 0.76),
    "call_back": (call_back, 0.66),
    "deploy": (deploy, 0.68),
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
        print(f"{name:16s} {len(x) / SR * 1000:5.0f} ms")


if __name__ == "__main__":
    sys.exit(main())
