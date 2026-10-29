"""
Generates the critter coin cues into assets/sounds/combat/, with the same
building blocks as tools/make_combat_sounds.py:

    coin_pop.mp3       a critter bursts into coins: a soft pop, then a
                       spray of little coins ringing as they fly out
    coin_clink_1.mp3   a coin landing: a small struck disc, its ring short
    coin_clink_2.mp3   (higher, a bounce in it)
    coin_clink_3.mp3   (lower, duller)
    coin_collect.mp3   a coin reaching you: a bright two-note "bling"
                       (CritterCoinFx plays each coin a step higher)
    coin_cash_in.mp3   the last one in: a sparkling run of bells over a
                       shake of coins, the "cha-ching"

    pip install numpy scipy soundfile
    python tools/make_coin_sounds.py

Upload them like the combat set (tools/upload_audio.py fills in the
CoinPop, CoinClink1-3, CoinCollect and CoinCashIn ids in
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

RNG = np.random.default_rng(57)

# A thin metal disc's modes (a coin), not a bar's or a plate's.
COIN = (1.0, 1.47, 2.09, 2.65, 3.6)


def coin(f0, seconds=0.32, decay=0.09, bright=1.0):
    """One coin struck: inharmonic modes ringing out fast, a tick on top."""
    ring = modal(f0, COIN, (decay, decay * 0.7, decay * 0.5, decay * 0.35, decay * 0.25), (1, 0.7 * bright, 0.5 * bright, 0.35 * bright, 0.2 * bright), seconds, 0.006)
    return mix((0.0, ring), (0.0, click(0.006, 5000) * 0.35))


def bell(freq, seconds, decay):
    """A small struck bell: a sine and its octave, an FM sheen that dies fast."""
    t = t_of(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2.0 * t)
    sheen = fm(freq * 2, 3.5, 1.2, seconds, index_decay=0.05) * 0.2
    shape = (1 - np.exp(-t / 0.002)) * np.exp(-t / decay)
    return (tone + sheen) * shape


def shimmer(seconds, lo, hi):
    """Air over the top: filtered noise with a fast flutter."""
    x = filt(noise(seconds), "band", (lo, hi))
    t = t_of(seconds)
    flutter = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * t)
    shape = np.minimum(1, t / 0.03) * np.exp(-t / (seconds * 0.35))
    return x * flutter * shape


def coin_pop():
    t = t_of(0.12)
    pop = osc("sine", sweep(420, 140, 0.12), 0.12) * np.exp(-t / 0.035) * 0.6
    parts = [(0.0, pop), (0.0, click(0.01, 1800) * 0.4)]
    for i in range(7):
        f = RNG.uniform(2300, 3900)
        parts.append((0.025 + i * RNG.uniform(0.018, 0.034), coin(f, 0.3, RNG.uniform(0.05, 0.09)) * RNG.uniform(0.25, 0.45)))
    parts.append((0.02, shimmer(0.35, 6000, 12000) * 0.08))
    return room(mix(*parts), 0.2, 0.2)


def coin_clink(f0, bounce):
    parts = [(0.0, coin(f0, 0.35, 0.1) * 0.8)]
    if bounce:
        parts.append((0.085, coin(f0 * 1.01, 0.25, 0.06) * 0.35))
    return room(mix(*parts), 0.15, 0.15)


def coin_collect():
    # B5 then E6, the old pickup "bling", on soft bells over a coin's ring.
    parts = [
        (0.0, coin(3100, 0.25, 0.05) * 0.35),
        (0.0, bell(987.77, 0.22, 0.05) * 0.55),
        (0.055, bell(1318.51, 0.5, 0.16) * 0.7),
        (0.05, shimmer(0.3, 7000, 13000) * 0.06),
    ]
    return room(mix(*parts), 0.2, 0.2)


def coin_cash_in():
    root = 1046.5  # C6: a major run up two octaves
    steps = (1, 1.25, 1.5, 2, 2.5, 3, 4)
    parts = []
    for i, r in enumerate(steps):
        parts.append((i * 0.038, bell(root * r / 2, 0.9, 0.3 - i * 0.02) * (0.6 - i * 0.04)))
    for i in range(10):
        parts.append((0.02 + i * RNG.uniform(0.02, 0.04), coin(RNG.uniform(2600, 4200), 0.3, 0.06) * RNG.uniform(0.15, 0.3)))
    parts.append((0.0, click(0.012, 1500) * 0.4))
    parts.append((0.1, shimmer(0.8, 6000, 13000) * 0.12))
    return room(mix(*parts), 0.35, 0.28)


SOUNDS = {
    "coin_pop": (coin_pop, 0.7),
    "coin_clink_1": (lambda: coin_clink(2900, False), 0.55),
    "coin_clink_2": (lambda: coin_clink(3400, True), 0.55),
    "coin_clink_3": (lambda: coin_clink(2500, False), 0.5),
    "coin_collect": (coin_collect, 0.7),
    "coin_cash_in": (coin_cash_in, 0.78),
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
