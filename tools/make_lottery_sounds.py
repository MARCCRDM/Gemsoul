"""
Generates the launch-lottery sounds into assets/sounds/lottery/: a sci-fi
vault opening, not a slot machine. The capsule's seal hisses open, a reactor
hums while the reels run, soft data blips tick past, each reel locks with a
hydraulic clamp, and every reveal rings out as crystal resonance that grows
with its rarity, up to a cinematic hit for a Legendary. The last step
attunes the loadout with a resonant chord instead of a fanfare.

    pip install numpy scipy soundfile
    python tools/make_lottery_sounds.py

Upload with tools/upload_audio.py (it fills in src/client/Modules/LotterySound.luau).
"""
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import make_combat_sounds as k  # noqa: E402  (the shared synth building blocks)

SR = k.SR
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds", "lottery")

# The key: D, bright and heroic over the dark cyberpunk score.
D5, FS5, A5, D6, E6, FS6, A6, D7 = 587.3, 740.0, 880.0, 1174.7, 1318.5, 1480.0, 1760.0, 2349.3
D3 = 146.8


def crystal(f, seconds=1.2, bright=1.0):
    """A struck crystal: glassy inharmonic modes with a long, pure ring."""
    return k.modal(f, (1.0, 2.32, 4.25, 6.63), (0.9, 0.45, 0.22, 0.12), (1, 0.35 * bright, 0.18 * bright, 0.08 * bright), seconds, 0.0015)


def pad(freqs, seconds, cutoff=2400):
    """A soft synth pad (detuned saws, filtered), swelling in and out."""
    x = sum(k.osc("saw", f, seconds) + k.osc("saw", f * 1.004, seconds) for f in freqs) / len(freqs)
    x = k.filt(x, "low", cutoff)
    t = np.linspace(0, 1, k.n_of(seconds))
    return x * np.minimum(t / 0.25, 1) * np.minimum((1 - t) / 0.5, 1).clip(0, 1)


def shimmer(seconds, low=6000):
    return k.filt(k.noise(seconds), "high", low) * k.env(seconds, 0.05, seconds * 0.4) * 0.18


def rise(seconds, f0=200, f1=2400):
    """A swell rushing up into a hit."""
    x = k.swept_filter(k.noise(seconds) * 0.6 + k.osc("saw", k.sweep(f0 / 4, f1 / 4, seconds)) * 0.4, "low", f0, f1)
    return x * np.linspace(0, 1, k.n_of(seconds)) ** 2.2


SOUNDS = {}


def sound(name, peak=0.75):
    def wrap(fn):
        SOUNDS[name] = (fn, peak)
        return fn

    return wrap


@sound("seal_break", 0.8)
def seal_break():
    """The capsule unlocks: clamps release, air hisses out, energy swells."""
    clamps = k.mix((0, 0.8 * k.thump(160, 60, 0.15, 0.04, 2)), (0.12, 0.6 * k.thump(140, 55, 0.15, 0.04, 2)))
    clank = 0.3 * k.plate(240, 0.4)
    hiss = k.filt(k.noise(1.0), "band", (1500, 8000)) * k.env(1.0, 0.01, 0.35) * 0.7
    swell = 0.5 * rise(1.1, 150, 3000)
    tone = 0.25 * pad((D3 * 2, D3 * 3), 1.4, 1600)
    return k.room(k.mix((0, clamps), (0, clank), (0.05, hiss), (0.25, swell), (0.4, tone)), 0.5, 0.35)


@sound("spin_hum", 0.5)
def spin_hum():
    """The reactor while the reels run: a low throb that loops seamlessly
    (whole cycles of everything in exactly two seconds)."""
    loop, seconds = 2.0, 6.0  # render three loops and keep the middle one, so the filters have settled
    t = k.t_of(seconds)
    base = 55.0  # 110 whole cycles in 2 s
    x = k.osc("saw", base, seconds) + k.osc("saw", base * 1.5, seconds) * 0.5 + np.sin(2 * np.pi * base * 2 * t) * 0.4
    x = k.filt(x, "low", 600)
    throb = 0.75 + 0.25 * np.sin(2 * np.pi * 4 * t)  # 8 throbs per loop
    data = np.sin(2 * np.pi * 2200 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 16 * t))) * 0.04
    out = x * throb + data
    return out[k.n_of(loop) : k.n_of(loop * 2)]


@sound("tick", 0.4)
def tick():
    """A soft data blip as a reel steps (pitched up in-game as it slows)."""
    blip = np.sin(2 * np.pi * 1900 * k.t_of(0.05)) * k.env(0.05, 0.001, 0.012)
    return k.mix((0, blip), (0, 0.3 * k.click(0.008, 4000)))


@sound("lock", 0.75)
def lock():
    """A reel locks: a hydraulic clamp, a clank, a short release of air."""
    clamp = k.thump(170, 70, 0.14, 0.035, 2.5)
    clank = 0.4 * k.plate(320, 0.3)
    hiss = k.filt(k.noise(0.25), "band", (2000, 7000)) * k.env(0.25, 0.005, 0.07) * 0.35
    return k.room(k.mix((0, k.click(0.01, 2500)), (0, clamp), (0.003, clank), (0.03, hiss)), 0.2, 0.2)


@sound("reveal_1", 0.6)
def reveal_1():
    """Common: a single crystal note."""
    return k.room(crystal(D6, 0.9, 0.8), 0.4, 0.3)


@sound("reveal_2", 0.65)
def reveal_2():
    """Uncommon: two crystals, a fifth apart, and a breath of shimmer."""
    return k.room(k.mix((0, crystal(D6, 1.1)), (0.07, 0.8 * crystal(A6, 1.0)), (0.02, shimmer(0.8))), 0.5, 0.35)


@sound("reveal_3", 0.72)
def reveal_3():
    """Rare: a rising crystal arpeggio over a soft pad, with a little weight."""
    notes = k.mix(*[(i * 0.07, crystal(f, 1.3) * (1 - i * 0.1)) for i, f in enumerate((D6, FS6, A6))])
    body = 0.35 * pad((D5, A5), 1.4)
    sub = 0.4 * k.thump(110, 50, 0.4, 0.15, 1.5)
    return k.room(k.mix((0, sub), (0, notes), (0.05, body), (0.05, shimmer(1.2))), 0.6, 0.4)


@sound("reveal_4", 0.85)
def reveal_4():
    """Ultra Rare: a swell rushes up into a bright chord with a deep boom."""
    swell = 0.6 * rise(0.3, 300, 4000)
    boom = k.thump(100, 32, 0.8, 0.28, 2.5)
    chord = k.mix(*[(0, crystal(f, 1.8) * a) for f, a in ((D6, 1), (FS6, 0.8), (A6, 0.8), (D7, 0.5))])
    body = 0.45 * pad((D3 * 2, D5, FS5, A5), 2.0, 3000)
    return k.room(k.limit(k.mix((0, swell), (0.3, boom), (0.3, chord), (0.32, body), (0.32, shimmer(1.6))), 1.3), 0.8, 0.45)


@sound("reveal_5", 0.95)
def reveal_5():
    """Legendary: a long rise, a cinematic impact, a choir-like chord ringing
    out over a deep boom and a cascade of crystal."""
    swell = 0.7 * rise(0.55, 150, 5000)
    impact = k.mix((0, k.thump(90, 26, 1.4, 0.45, 3.2)), (0, 0.5 * k.crunch(0.15, 1800, 0.05)), (0, 0.2 * k.plate(160, 1.2)))
    chord = k.mix(*[(0, crystal(f, 2.6) * a) for f, a in ((D6, 1), (E6, 0.5), (FS6, 0.8), (A6, 0.8), (D7, 0.6))])
    choir = 0.5 * pad((D3, D3 * 2, D5, FS5, A5, E6 / 2), 3.0, 2200)
    cascade = k.mix(*[(0.1 + i * 0.09, 0.45 * crystal(f, 1.0)) for i, f in enumerate((D7, A6, FS6, D6, A5, FS5))])
    return k.room(
        k.limit(k.mix((0, swell), (0.55, impact), (0.55, chord), (0.6, choir), (0.65, cascade), (0.6, shimmer(2.4))), 1.3),
        1.0,
        0.5,
    )


@sound("attune", 0.8)
def attune():
    """The loadout attunes: gem resonance swells into a held chord and settles."""
    seconds = 2.4
    hum = pad((D3, D3 * 1.5, D3 * 2, FS5 / 2), seconds, 1800)
    swell = 0.5 * rise(0.6, 200, 3000)
    ring = k.mix(*[(0.55 + i * 0.05, 0.6 * crystal(f, 1.8)) for i, f in enumerate((D6, FS6, A6, D7))])
    sub = 0.6 * k.thump(120, 36, 0.9, 0.3, 2)
    return k.room(k.limit(k.mix((0, swell), (0.2, hum), (0.55, sub), (0, ring), (0.6, shimmer(1.6))), 1.3), 0.9, 0.45)


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, (fn, peak) in SOUNDS.items():
        x = np.asarray(fn(), dtype=np.float64)
        if name == "spin_hum":
            x = x / (np.max(np.abs(x)) + 1e-9) * peak * 0.88  # a loop: no fades, no trim
        else:
            x = k.finish(x, peak * 0.88)
            loud = np.nonzero(np.abs(x) > peak * 0.002)[0]
            x = x[: min(len(x), (loud[-1] if len(loud) else len(x)) + k.n_of(0.02))]
            tail = min(len(x), k.n_of(0.04))
            x[-tail:] *= np.linspace(1, 0, tail)
        x = x.astype(np.float32)
        rendered[name] = x
        if name == "spin_hum":
            # MP3 pads the start with silence, which clicks on every loop; OGG loops cleanly.
            sf.write(os.path.join(OUT, name + ".ogg"), x, SR, format="OGG", subtype="VORBIS")
        else:
            sf.write(os.path.join(OUT, name + ".mp3"), x, SR, format="MP3")
        print(f"{name:12s} {len(x) / SR * 1000:5.0f} ms")
    gap = np.zeros(k.n_of(0.5), dtype=np.float32)
    preview = np.concatenate([np.concatenate([x, gap]) for x in rendered.values()])
    sf.write(os.path.join(OUT, "_preview_all.mp3"), preview, SR, format="MP3")


if __name__ == "__main__":
    sys.exit(main())
