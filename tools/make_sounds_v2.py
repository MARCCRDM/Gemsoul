"""
The game's sound effects, second set: physical, not synthetic. Swords cut
the air (filtered-noise whooshes that sweep like a real blade), steel rings
(inharmonic struck-bar and plate modes), blows land with weight (pitched-down
body thumps under a crunch), gems sing like glass and bells, and each element
sounds like itself (fire's roar and crackle, frost's glassy shards, shock's
arcs and buzz, poison's bubbles). Every sound gets a little room (a short
synthetic reverb) and is mastered to its own level (UI quiet, blows loud).

    python tools/make_sounds_v2.py                 # into assets/sounds (the game's)
    python tools/make_sounds_v2.py --out DIR        # somewhere else (a preview)
    python tools/make_sounds_v2.py --only combat    # one group: combat | ui | lottery

Same file names as the first set, so tools/upload_audio.py uploads them and
fills the ids in (CombatSound, UiSound, LotterySound). A _preview_all.mp3 in
each folder plays the group back to back.

Needs numpy, scipy, soundfile and ffmpeg (for mp3 and ogg).
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


# Building blocks -----------------------------------------------------------------------------------------

def n_of(seconds):
    return max(1, int(SR * seconds))


def t_of(seconds):
    return np.arange(n_of(seconds)) / SR


def silence(seconds):
    return np.zeros(n_of(seconds))


def pad(x, n):
    """`x` lengthened (or cut) to n samples."""
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x))])


def mix(*layers):
    """Layers summed: (sound, gain, delay seconds) or a bare sound."""
    parts = []
    for layer in layers:
        if isinstance(layer, tuple):
            x, gain, *rest = layer
            at = rest[0] if rest else 0.0
        else:
            x, gain, at = layer, 1.0, 0.0
        parts.append((x, gain, n_of(at) if at > 0 else 0))
    n = max(len(x) + d for x, _, d in parts)
    out = np.zeros(n)
    for x, g, d in parts:
        out[d:d + len(x)] += x * g
    return out


def env_exp(seconds, decay, attack=0.002):
    """A fast attack, then an exponential fall (`decay`: seconds to 1/e)."""
    t = t_of(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def env_bell(seconds, peak=0.4, sharp=2.0):
    """Up and down, its top at `peak` (0..1 of the length)."""
    t = np.linspace(0, 1, n_of(seconds))
    up = np.clip(t / peak, 0, 1) ** sharp
    down = np.clip((1 - t) / (1 - peak), 0, 1) ** sharp
    return np.minimum(up, down)


def noise(seconds, rng):
    return rng.standard_normal(n_of(seconds))


def sos_filter(x, kind, freq, order=2):
    nyq = SR / 2
    if kind == "band":
        lo, hi = max(20, freq[0]), min(nyq * 0.98, freq[1])
        sos = signal.butter(order, [lo / nyq, hi / nyq], btype="band", output="sos")
    else:
        sos = signal.butter(order, min(freq, nyq * 0.98) / nyq, btype=kind, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=2):
    return sos_filter(x, "low", f, order)


def highpass(x, f, order=2):
    return sos_filter(x, "high", f, order)


def bandpass(x, lo, hi, order=2):
    return sos_filter(x, "band", (lo, hi), order)


def swept_band(x, centers, q=1.6, block=128):
    """`x` through a band-pass whose centre follows `centers` (a value per
    sample): a blade's whoosh, the air it cuts rising and falling."""
    out = np.zeros_like(x)
    zi = np.zeros((1, 2))
    for i in range(0, len(x), block):
        c = float(np.clip(centers[min(i, len(centers) - 1)], 40, SR * 0.45))
        bw = c / q
        lo, hi = max(20.0, c - bw / 2), min(SR * 0.49, c + bw / 2)
        b, a = signal.butter(1, [lo / (SR / 2), hi / (SR / 2)], btype="band")
        sos = signal.tf2sos(b, a)
        seg, zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
        out[i:i + block] = seg
    return out


def glide(f0, f1, seconds, curve=1.0):
    """A pitch track from f0 to f1 (exponential, `curve` bends it)."""
    t = np.linspace(0, 1, n_of(seconds)) ** curve
    return f0 * (f1 / f0) ** t


def tone(freq, seconds=None, kind="sine", phase0=0.0):
    if np.isscalar(freq):
        freq = np.full(n_of(seconds), float(freq))
    p = 2 * np.pi * np.cumsum(freq) / SR + phase0
    if kind == "sine":
        return np.sin(p)
    frac = (p / (2 * np.pi)) % 1.0
    if kind == "saw":
        return 2 * frac - 1
    if kind == "square":
        return np.tanh(6 * np.sin(p))
    if kind == "tri":
        return 4 * np.abs(frac - 0.5) - 1
    raise ValueError(kind)


def modal(base, ratios, decays, amps, seconds, rng, detune=0.004):
    """A struck object: decaying partials at `ratios` of `base` (steel, glass,
    a bell), each a touch detuned so it shimmers."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for r, d, a in zip(ratios, decays, amps):
        f = base * r * (1 + rng.uniform(-detune, detune))
        if f >= SR * 0.45:
            continue
        beat = 1 + 0.15 * np.sin(2 * np.pi * rng.uniform(0.5, 3) * t)  # (a slow shimmer)
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / d) * beat
    return out


# Struck-object partials.
STEEL_BAR = ([1, 2.76, 5.40, 8.93, 13.34], [0.30, 0.18, 0.11, 0.07, 0.04], [1, 0.6, 0.4, 0.25, 0.15])
PLATE = ([1, 1.59, 2.14, 2.65, 3.16, 3.60, 4.15], [0.7, 0.55, 0.45, 0.35, 0.3, 0.25, 0.2], [1, 0.8, 0.6, 0.55, 0.4, 0.35, 0.25])
BELL = ([0.5, 1, 1.19, 1.56, 2, 2.51, 3.01, 4.1], [1.6, 1.2, 0.9, 0.7, 0.55, 0.4, 0.3, 0.2], [0.35, 1, 0.5, 0.45, 0.4, 0.3, 0.25, 0.15])
GLASS = ([1, 2.32, 4.25, 6.63, 9.38], [0.45, 0.3, 0.2, 0.14, 0.09], [1, 0.5, 0.35, 0.22, 0.12])
COIN = ([1, 1.83, 2.95, 4.16, 5.6], [0.22, 0.15, 0.1, 0.07, 0.05], [1, 0.7, 0.5, 0.3, 0.2])


def steel(base, seconds, rng, scale=1.0):
    r, d, a = STEEL_BAR
    return modal(base, r, [x * scale for x in d], a, seconds, rng)


def plate(base, seconds, rng, scale=1.0):
    r, d, a = PLATE
    return modal(base, r, [x * scale for x in d], a, seconds, rng)


def bell(base, seconds, rng, scale=1.0):
    r, d, a = BELL
    return modal(base, r, [x * scale for x in d], a, seconds, rng, detune=0.002)


def glass(base, seconds, rng, scale=1.0):
    r, d, a = GLASS
    return modal(base, r, [x * scale for x in d], a, seconds, rng)


def coin(base, seconds, rng):
    r, d, a = COIN
    return modal(base, r, d, a, seconds, rng)


def thump(f0, f1, seconds, decay=None):
    """A body blow: a sine falling in pitch, gone fast (felt, a kick drum)."""
    decay = decay or seconds / 4
    return tone(glide(f0, f1, seconds, 0.4)) * env_exp(seconds, decay, 0.001)


def click(rng, seconds=0.004, hp=2500):
    """The very first instant of a contact: a short bright tick."""
    return highpass(noise(seconds, rng), hp) * np.linspace(1, 0, n_of(seconds)) ** 2


def crunch(seconds, rng, lo=700, hi=4000, decay=0.05):
    return bandpass(noise(seconds, rng), lo, hi) * env_exp(seconds, decay, 0.001)


def crackle(seconds, rng, density=60, lo=1500, hi=7000, decay=0.006):
    """Fire's pops and ice's clicks: sparse tiny bursts."""
    out = np.zeros(n_of(seconds))
    count = int(density * seconds)
    for _ in range(count):
        at = rng.integers(0, max(1, len(out) - n_of(0.02)))
        burst = noise(0.02, rng) * env_exp(0.02, decay * rng.uniform(0.5, 1.5), 0.0003)
        out[at:at + len(burst)] += burst * rng.uniform(0.3, 1.0)
    return bandpass(out, lo, hi)


def whoosh(seconds, rng, f_lo=400, f_hi=2600, peak=0.45, q=1.4, body=0.0):
    """A blade through the air: noise through a band sweeping up to f_hi at
    the swing's fastest and back down."""
    n = n_of(seconds)
    t = np.linspace(0, 1, n)
    shape = np.where(t < peak, (t / peak) ** 1.5, ((1 - t) / (1 - peak)) ** 0.8)
    centers = f_lo * (f_hi / f_lo) ** shape
    x = swept_band(noise(seconds, rng), centers, q)
    x *= env_bell(seconds, peak, 1.6)
    if body > 0:
        x += body * lowpass(noise(seconds, rng), 300) * env_bell(seconds, peak, 2.0)
    return x


def saturate(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def reverb(x, seconds=0.6, mix_level=0.18, damp=5000, rng=None):
    """A little room: an exponentially decaying noise burst as its impulse
    response (early reflections at its start), darkened by `damp`."""
    rng = rng or np.random.default_rng(1)
    t = t_of(seconds)
    ir = rng.standard_normal(len(t)) * np.exp(-t / (seconds / 5))
    ir = lowpass(ir, damp)
    for delay, gain in ((0.011, 0.6), (0.019, 0.45), (0.029, 0.35), (0.041, 0.25)):
        k = n_of(delay)
        if k < len(ir):
            ir[k] += gain * 6
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = signal.fftconvolve(x, ir)[: len(x) + len(ir) - 1]
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry + mix_level * wet


def master(x, peak_db=-1.0, fade=0.02, hp=35, tail=True):
    """Ready to ship: rumble cut, the silence trimmed, a fade out, a gentle
    limiter and peak level `peak_db`."""
    x = highpass(x, hp, 2)
    if tail:
        # (trim what's under -60 dB at the end)
        level = np.abs(x)
        top = level.max() + 1e-9
        idx = np.where(level > top * 0.001)[0]
        if len(idx):
            x = x[: min(len(x), idx[-1] + n_of(0.05))]
    k = min(len(x), n_of(fade))
    if k > 1:
        x[-k:] *= np.linspace(1, 0, k) ** 2
    x = x / (np.abs(x).max() + 1e-9)
    x = np.tanh(x * 1.4) / np.tanh(1.4)  # (soft limit: more body, no clipping)
    return x / (np.abs(x).max() + 1e-9) * 10 ** (peak_db / 20)


def note(name):
    """'C5' -> its frequency."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        semis -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440 * 2 ** ((semis + (octave - 4) * 12) / 12)


def chime(names, step, rng, seconds=1.2, kind="bell", scale=1.0, gain=1.0):
    """Notes one after another, `step` seconds apart, as bells or glass."""
    make = bell if kind == "bell" else glass
    layers = [(make(note(n), seconds, rng, scale), gain * (0.9 ** i), i * step) for i, n in enumerate(names)]
    return mix(*layers)


def sparkle(seconds, rng, count=14, lo=2500, hi=7000):
    """Tiny glints scattered over `seconds`."""
    layers = []
    for _ in range(count):
        f = rng.uniform(lo, hi)
        layers.append((glass(f, 0.25, rng, 0.4), rng.uniform(0.15, 0.5), rng.uniform(0, seconds)))
    return mix(*layers)


# The sounds ------------------------------------------------------------------------------------------------
# Each takes a seeded rng (takes of one sound differ) and returns samples.

def swing(rng):
    x = whoosh(rng.uniform(0.24, 0.3), rng, rng.uniform(380, 480), rng.uniform(2300, 3000), rng.uniform(0.38, 0.5))
    # (the blade's faint ring as it passes)
    ring = tone(glide(rng.uniform(3200, 3800), rng.uniform(2600, 3000), 0.25)) * env_bell(0.25, 0.4) * 0.05
    return reverb(mix(x, (ring, 1.0, 0.02)), 0.4, 0.1, rng=rng)


def heavy_swing(rng):
    x = whoosh(rng.uniform(0.42, 0.5), rng, 180, rng.uniform(1300, 1700), 0.5, q=1.1, body=0.35)
    return reverb(x, 0.5, 0.12, rng=rng)


def hit(rng):
    base = rng.uniform(820, 1050)
    x = mix(
        (click(rng), 0.9),
        (thump(rng.uniform(150, 175), 55, 0.2), 1.0),
        (crunch(0.12, rng, 700, 3800, 0.035), 0.55),
        (steel(base, 0.35, rng, 0.6), 0.16),
    )
    return reverb(saturate(x, 1.8), 0.45, 0.14, rng=rng)


def heavy_hit(rng):
    x = mix(
        (click(rng, 0.006, 1800), 1.0),
        (thump(rng.uniform(115, 130), 38, 0.42, 0.1), 1.2),
        (crunch(0.22, rng, 400, 3000, 0.07), 0.7),
        (steel(rng.uniform(520, 640), 0.6, rng, 0.9), 0.2),
        (lowpass(noise(0.4, rng), 160) * env_exp(0.4, 0.12), 0.5),
    )
    return reverb(saturate(x, 2.2), 0.7, 0.18, rng=rng)


def crit(rng):
    x = mix(
        (hit(rng), 1.0),
        (glass(rng.uniform(1900, 2300), 0.9, rng, 1.4), 0.32, 0.01),
        (sparkle(0.45, rng, 10), 0.35, 0.03),
    )
    return reverb(x, 0.8, 0.16, rng=rng)


def contact(rng):
    # (your own blade landing: felt more than heard)
    x = mix(
        (click(rng, 0.003, 3500), 0.5),
        (thump(rng.uniform(170, 200), 70, 0.12), 1.0),
        (crunch(0.06, rng, 900, 3500, 0.02), 0.35),
    )
    return saturate(x, 1.5)


def heavy_contact(rng):
    x = mix(
        (click(rng, 0.005, 2500), 0.6),
        (thump(rng.uniform(120, 140), 48, 0.26, 0.07), 1.0),
        (crunch(0.12, rng, 500, 3000, 0.04), 0.45),
    )
    return saturate(x, 1.8)


def deflect(rng):
    scrape = swept_band(noise(0.3, rng), glide(rng.uniform(3500, 4200), 1400, 0.3), 3) * env_exp(0.3, 0.09)
    x = mix(
        (click(rng, 0.003, 4000), 0.7),
        (scrape, 0.7),
        (steel(rng.uniform(1400, 1700), 0.5, rng, 0.8), 0.35),
    )
    return reverb(x, 0.5, 0.15, rng=rng)


def block(rng):
    x = mix(
        (click(rng, 0.005, 2000), 0.8),
        (thump(rng.uniform(140, 160), 60, 0.22), 0.9),
        (plate(rng.uniform(300, 360), 1.0, rng, 0.8), 0.45),
        (crunch(0.08, rng, 1000, 5000, 0.025), 0.4),
    )
    return reverb(saturate(x, 1.6), 0.6, 0.16, rng=rng)


def guard_break(rng):
    clatter = mix(*[(steel(rng.uniform(600, 1600), 0.3, rng, 0.5), rng.uniform(0.2, 0.4), rng.uniform(0.04, 0.4)) for _ in range(6)])
    x = mix(
        (saturate(highpass(noise(0.06, rng), 900) * env_exp(0.06, 0.015), 3), 1.0),
        (thump(110, 32, 0.6, 0.15), 1.1),
        (plate(260, 1.2, rng, 0.9), 0.4),
        (clatter, 0.8),
        (whoosh(0.35, rng, 1500, 300, 0.2), 0.3, 0.02),
    )
    return reverb(saturate(x, 2), 0.9, 0.2, rng=rng)


def parry(rng):
    x = mix(
        (click(rng, 0.003, 4500), 0.8),
        (steel(1250, 1.0, rng, 2.2), 0.55),
        (steel(1870, 1.0, rng, 2.0), 0.45, 0.01),
        (glass(3100, 0.8, rng, 1.2), 0.2, 0.02),
        (sparkle(0.5, rng, 8, 3500, 8000), 0.25, 0.04),
    )
    return reverb(x, 1.1, 0.24, rng=rng)


def hop(rng):
    x = mix(
        (whoosh(0.22, rng, 300, 1400, 0.35, 1.2), 0.8),
        (lowpass(noise(0.08, rng), 900) * env_exp(0.08, 0.02), 0.4),
    )
    return x


def roll_sound(rng):
    n = 0.5
    t = t_of(n)
    tumble = lowpass(noise(n, rng), 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * env_bell(n, 0.3, 1.2)
    grit = crackle(n, rng, 50, 1200, 5000, 0.004) * env_bell(n, 0.4)
    return mix((tumble, 1.0), (grit, 0.35), (whoosh(0.4, rng, 250, 900, 0.4), 0.5))


def magic_swell(seconds, rng, f_lo=300, f_hi=4000, chord=("C5", "G5", "E6")):
    """Gathering power: filtered noise rising, a shimmering chord under it."""
    t = t_of(seconds)
    air = swept_band(noise(seconds, rng), glide(f_lo, f_hi, seconds, 0.7), 2.0) * env_bell(seconds, 0.85, 1.4)
    pad_ = sum(tone(note(n) * (1 + 0.003 * np.sin(2 * np.pi * 5 * t))) for n in chord) / len(chord)
    pad_ *= env_bell(seconds, 0.85, 2.0) * (0.7 + 0.3 * np.sin(2 * np.pi * 7 * t))
    return mix((air, 0.8), (pad_, 0.35))


def cast(rng):
    return reverb(magic_swell(0.6, rng), 0.7, 0.2, rng=rng)


def fire_roar(seconds, rng):
    roar = lowpass(noise(seconds, rng), 900) * env_bell(seconds, 0.3, 1.3)
    roar = saturate(roar * 1.5, 1.5)
    return mix((roar, 1.0), (crackle(seconds, rng, 70, 1800, 7000, 0.005), 0.6))


def cast_fire(rng):
    ignite = swept_band(noise(0.55, rng), glide(250, 1800, 0.55, 0.6), 1.3) * env_bell(0.55, 0.7)
    return reverb(mix((ignite, 0.8), (fire_roar(0.6, rng), 0.7)), 0.6, 0.15, rng=rng)


def frost_shards(seconds, rng, count=10):
    return mix(*[(glass(rng.uniform(2200, 5200), 0.4, rng, 0.8), rng.uniform(0.2, 0.6), rng.uniform(0, seconds)) for _ in range(count)])


def cast_frost(rng):
    air = highpass(noise(0.6, rng), 3000) * env_bell(0.6, 0.7) * 0.4
    return reverb(mix((frost_shards(0.5, rng, 12), 0.8), (air, 0.6), (crackle(0.5, rng, 40, 4000, 9000, 0.003), 0.4)), 0.9, 0.25, rng=rng)


def arcs(seconds, rng, count=8):
    """Electric arcs: harsh high bursts, flickering."""
    layers = []
    for _ in range(count):
        d = rng.uniform(0.02, 0.07)
        burst = highpass(noise(d, rng), 2500) * (rng.random(n_of(d)) > 0.35) * env_exp(d, d / 2, 0.0005)
        layers.append((burst, rng.uniform(0.4, 1.0), rng.uniform(0, seconds)))
    return mix(*layers)


def buzz(seconds, rng, f=95):
    jitter = f * (1 + 0.04 * rng.standard_normal(n_of(seconds)).cumsum() / 80)
    b = bandpass(tone(jitter, kind="saw"), 200, 3000)
    return b * (0.6 + 0.4 * (rng.random(n_of(seconds)) > 0.15))


def cast_shock(rng):
    x = mix((buzz(0.55, rng) * env_bell(0.55, 0.6), 0.5), (arcs(0.5, rng, 9), 0.8))
    return reverb(saturate(x, 1.6), 0.5, 0.12, rng=rng)


def bubbles(seconds, rng, count=14, lo=250, hi=700):
    layers = []
    for _ in range(count):
        d = rng.uniform(0.04, 0.09)
        f0 = rng.uniform(lo, hi)
        blip = tone(glide(f0, f0 * rng.uniform(1.6, 2.4), d)) * env_bell(d, 0.3)
        layers.append((blip, rng.uniform(0.3, 0.8), rng.uniform(0, seconds)))
    return mix(*layers)


def cast_poison(rng):
    gurgle = lowpass(noise(0.6, rng), 500) * env_bell(0.6, 0.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t_of(0.6)))
    return reverb(mix((bubbles(0.55, rng), 0.8), (gurgle, 0.6)), 0.6, 0.18, rng=rng)


def boom(seconds, rng, f0=90, f1=28, body=0.8):
    return mix(
        (thump(f0, f1, seconds, seconds / 3), 1.2),
        (lowpass(noise(seconds, rng), 400) * env_exp(seconds, seconds / 4), body),
    )


def impact_fire(rng):
    return reverb(saturate(mix((boom(0.5, rng, 100, 35), 0.9), (fire_roar(0.7, rng), 0.7, 0.02)), 1.8), 0.8, 0.18, rng=rng)


def impact_frost(rng):
    shatter = mix((highpass(noise(0.08, rng), 2500) * env_exp(0.08, 0.02), 0.8), (frost_shards(0.35, rng, 16), 0.9))
    return reverb(mix((thump(150, 60, 0.2), 0.6), (shatter, 1.0)), 0.9, 0.22, rng=rng)


def impact_shock(rng):
    snap = saturate(highpass(noise(0.03, rng), 1500) * env_exp(0.03, 0.006), 3)
    return reverb(mix((snap, 1.0), (thump(160, 60, 0.18), 0.6), (arcs(0.35, rng, 6), 0.7, 0.02), (buzz(0.35, rng, 120) * env_exp(0.35, 0.1), 0.4)), 0.5, 0.12, rng=rng)


def impact_poison(rng):
    splat = lowpass(noise(0.15, rng), 1200) * env_exp(0.15, 0.04)
    return reverb(mix((thump(130, 55, 0.2), 0.6), (splat, 0.9), (bubbles(0.45, rng, 10), 0.6, 0.03)), 0.6, 0.18, rng=rng)


def bolt(rng):
    zip_ = tone(glide(1800, 300, 0.25), kind="saw") * env_exp(0.25, 0.08)
    return reverb(mix((whoosh(0.25, rng, 800, 3500, 0.3), 0.7), (bandpass(zip_, 300, 4000), 0.35)), 0.5, 0.14, rng=rng)


def beam(rng):
    s = 1.2
    t = t_of(s)
    hum = sum(tone(f * (1 + 0.002 * np.sin(2 * np.pi * 6 * t))) / (i + 1) for i, f in enumerate((110, 220, 330, 440)))
    hum *= (0.75 + 0.25 * np.sin(2 * np.pi * 13 * t))
    fizz = highpass(noise(s, rng), 4000) * 0.25
    x = mix((hum, 0.6), (fizz, 0.6)) * env_bell(s, 0.1, 0.8)
    return reverb(x, 0.6, 0.15, rng=rng)


def nova_warn(rng):
    s = 1.0
    t = t_of(s)
    rise = tone(glide(180, 900, s, 1.6)) * (0.6 + 0.4 * np.sin(2 * np.pi * glide(4, 16, s) * t))
    air = swept_band(noise(s, rng), glide(300, 5000, s, 1.4), 2) * np.linspace(0, 1, n_of(s)) ** 2
    return reverb(mix((rise * np.linspace(0.2, 1, n_of(s)), 0.5), (air, 0.6)), 0.6, 0.15, rng=rng)


def blast(rng):
    debris = mix(*[(crunch(0.1, rng, 600, 4000, 0.03), rng.uniform(0.2, 0.5), rng.uniform(0.05, 0.6)) for _ in range(10)])
    x = mix((saturate(highpass(noise(0.05, rng), 800) * env_exp(0.05, 0.01), 3), 0.9), (boom(1.1, rng, 85, 24, 1.0), 1.2), (debris, 0.6))
    return reverb(saturate(x, 2.2), 1.2, 0.2, rng=rng)


def zap(rng):
    snap = saturate(highpass(noise(0.03, rng), 2000) * env_exp(0.03, 0.006), 3)
    return mix((snap, 1.0), (buzz(0.18, rng, 140) * env_exp(0.18, 0.05), 0.6))


def burn(rng):
    return mix((crackle(0.3, rng, 60, 1500, 6000, 0.004), 0.9), (lowpass(noise(0.3, rng), 700) * env_bell(0.3, 0.2), 0.4))


def freeze(rng):
    return reverb(mix((crackle(0.35, rng, 80, 3500, 9000, 0.002), 0.8), (glass(2600, 0.6, rng, 0.8), 0.4, 0.15)), 0.7, 0.2, rng=rng)


def corrode(rng):
    fizz = highpass(noise(0.5, rng), 3500) * (0.5 + 0.5 * (rng.random(n_of(0.5)) > 0.6)) * env_bell(0.5, 0.2)
    return mix((fizz, 0.6), (bubbles(0.4, rng, 8, 400, 900), 0.5))


def heal(rng):
    return reverb(mix((chime(("C5", "E5", "G5", "C6"), 0.07, rng, 1.0, "bell", 0.8, 0.6), 1.0), (magic_swell(0.6, rng, 400, 3000), 0.4)), 1.0, 0.25, rng=rng)


def shield_up(rng):
    t = t_of(0.7)
    hum = (tone(220, 0.7) + 0.5 * tone(330, 0.7)) * env_bell(0.7, 0.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 8 * t))
    return reverb(mix((hum, 0.5), (glass(1760, 0.9, rng, 1.0), 0.4, 0.05), (whoosh(0.4, rng, 300, 2000, 0.7), 0.4)), 0.8, 0.2, rng=rng)


def hurt(rng):
    x = mix(
        (thump(rng.uniform(110, 130), 45, 0.25, 0.06), 1.0),
        (bandpass(noise(0.12, rng), 350, 900) * env_exp(0.12, 0.04), 0.6),
        (click(rng, 0.004, 1500), 0.4),
    )
    return saturate(lowpass(x, 3000), 2.0)


def stun(rng):
    layers = []
    for i in range(3):
        d = 0.32
        t = t_of(d)
        f = glide(1700 - i * 150, 1000 - i * 120, d) * (1 + 0.03 * np.sin(2 * np.pi * 9 * t))
        layers.append((tone(f) * env_exp(d, 0.12), 0.5, i * 0.14))
    return reverb(mix(*layers), 0.6, 0.2, rng=rng)


def winded(rng):
    s = 0.7
    breath = bandpass(noise(s, rng), 500, 1600) * env_bell(s, 0.35, 1.5)
    return mix((breath, 0.8), (thump(90, 45, 0.25), 0.5))


def combo(rng):
    layers = [(tone(glide(note(n), note(n) * 1.01, 0.15), kind="tri") * env_exp(0.15, 0.05), 0.5, i * 0.06) for i, n in enumerate(("E5", "A5", "E6"))]
    return reverb(mix(*layers, (click(rng, 0.003), 0.3)), 0.4, 0.12, rng=rng)


def death(rng):
    fall = tone(glide(220, 60, 0.9)) * env_exp(0.9, 0.3)
    return reverb(saturate(mix((boom(1.0, rng, 90, 25), 1.0), (fall, 0.4, 0.05), (crunch(0.3, rng, 300, 2500, 0.1), 0.4)), 1.8), 1.0, 0.2, rng=rng)


def warn(rng):
    beep = lambda: tone(880, 0.09, "square") * env_bell(0.09, 0.1, 0.5)
    return lowpass(mix((beep(), 0.4), (beep(), 0.4, 0.14)), 3500)


def kill(rng):
    return reverb(mix((heavy_hit(rng), 0.9), (bell(note("E5"), 1.4, rng), 0.3, 0.03), (sparkle(0.5, rng, 10), 0.25, 0.05)), 1.0, 0.2, rng=rng)


def charge(rng):
    s = 0.8
    t = t_of(s)
    whine = tone(glide(200, 1400, s, 1.3)) * (0.7 + 0.3 * np.sin(2 * np.pi * glide(5, 22, s) * t))
    return reverb(mix((whine * np.linspace(0.2, 1, n_of(s)), 0.5), (swept_band(noise(s, rng), glide(300, 4000, s), 2) * np.linspace(0, 1, n_of(s)), 0.5)), 0.5, 0.12, rng=rng)


def level_up(rng, low=False):
    notes = ("C4", "E4", "G4", "C5") if low else ("C5", "E5", "G5", "C6")
    x = mix((chime(notes, 0.09, rng, 1.6, "bell", 1.0, 0.7), 1.0), (boom(0.6, rng, 110, 40, 0.3), 0.4), (sparkle(1.0, rng, 18), 0.3, 0.3))
    return reverb(x, 1.4, 0.25, rng=rng)


def call_back(rng):
    return reverb(mix((tone(glide(1500, 700, 0.35)) * env_exp(0.35, 0.15), 0.5), (whoosh(0.3, rng, 1500, 400, 0.2), 0.4)), 0.5, 0.15, rng=rng)


def deploy(rng):
    poof = lowpass(noise(0.2, rng), 1500) * env_exp(0.2, 0.05)
    return reverb(mix((whoosh(0.3, rng, 300, 2500, 0.8), 0.6), (poof, 0.7, 0.25), (bell(note("G5"), 0.8, rng, 0.6), 0.35, 0.27)), 0.6, 0.18, rng=rng)


def coin_clink(rng):
    return reverb(mix((click(rng, 0.002, 5000), 0.4), (coin(rng.uniform(2300, 2900), 0.45, rng), 0.9)), 0.4, 0.12, rng=rng)


def coin_pop(rng):
    return reverb(mix((coin(2600, 0.5, rng), 0.8), (tone(glide(900, 1800, 0.08)) * env_exp(0.08, 0.03), 0.3)), 0.4, 0.12, rng=rng)


def coin_collect(rng):
    return reverb(mix(*[(coin(rng.uniform(2200, 3200), 0.4, rng), 0.6, i * 0.055) for i in range(6)]), 0.5, 0.15, rng=rng)


def coin_cash_in(rng):
    return reverb(mix((coin_collect(rng), 0.8), (bell(note("E6"), 1.2, rng, 0.7), 0.4, 0.3)), 0.7, 0.18, rng=rng)


def legendary_window(rng):
    s = 2.6
    t = t_of(s)
    chord = sum(tone(note(n) * (1 + d), s) for n in ("C3", "G3", "C4", "E4", "G4") for d in (-0.004, 0.004))
    pad_ = lowpass(chord / 10, 2200) * env_bell(s, 0.35, 1.2) * (0.85 + 0.15 * np.sin(2 * np.pi * 0.7 * t))
    x = mix((boom(1.2, rng, 70, 25, 0.6), 0.9), (pad_, 0.8, 0.1), (chime(("C5", "E5", "G5", "C6", "E6"), 0.12, rng, 2.0), 0.5, 0.4), (sparkle(2.0, rng, 30), 0.35, 0.5))
    return reverb(x, 1.8, 0.3, rng=rng)


# UI ---------------------------------------------------------------------------------------------------------

def ui_hover(rng):
    return mix((click(rng, 0.003, 4000), 0.4), (glass(3400, 0.08, rng, 0.2), 0.2))


def ui_click(rng):
    return reverb(mix((click(rng, 0.003, 2500), 0.6), (modal(1250, [1, 2.4, 4.1], [0.04, 0.025, 0.015], [1, 0.4, 0.2], 0.12, rng), 0.6)), 0.25, 0.06, rng=rng)


def ui_tab(rng):
    return reverb(mix((click(rng, 0.002, 3000), 0.3), (modal(880, [1, 2, 3.01], [0.08, 0.05, 0.03], [1, 0.4, 0.2], 0.2, rng), 0.6)), 0.3, 0.08, rng=rng)


def ui_confirm(rng):
    return reverb(chime(("E5", "B5"), 0.07, rng, 0.7, "bell", 0.5), 0.6, 0.2, rng=rng)


def ui_back(rng):
    return reverb(chime(("B4", "E4"), 0.07, rng, 0.5, "bell", 0.4, 0.8), 0.5, 0.15, rng=rng)


def ui_open(rng):
    return reverb(mix((whoosh(0.22, rng, 500, 3000, 0.75, 1.6), 0.5), (glass(note("A5"), 0.5, rng, 0.6), 0.3, 0.12)), 0.5, 0.15, rng=rng)


def ui_close(rng):
    return reverb(mix((whoosh(0.18, rng, 2500, 400, 0.25, 1.6), 0.5), (thump(220, 120, 0.08), 0.3, 0.1)), 0.4, 0.12, rng=rng)


def ui_notify(rng):
    return reverb(mix((bell(note("G5"), 1.0, rng, 0.6), 0.6), (bell(note("D6"), 0.9, rng, 0.5), 0.35, 0.08)), 0.7, 0.2, rng=rng)


def ui_error(rng):
    bonk = lambda: lowpass(tone(190, 0.1, "square"), 900) * env_exp(0.1, 0.035)
    return mix((bonk(), 0.6), (bonk(), 0.5, 0.12))


def ui_reward(rng):
    return reverb(mix((chime(("C6", "E6", "G6", "C7"), 0.06, rng, 1.0, "glass", 0.8), 0.8), (sparkle(0.6, rng, 12), 0.3, 0.1)), 0.9, 0.22, rng=rng)


def ui_craft(rng):
    strike = lambda: mix((click(rng, 0.004, 1500), 0.6), (thump(180, 90, 0.1), 0.6), (steel(1050, 0.5, rng, 0.8), 0.45))
    return reverb(mix((strike(), 0.8), (strike(), 0.9, 0.22)), 0.6, 0.15, rng=rng)


def ui_enchant(rng):
    return reverb(mix((magic_swell(0.7, rng, 600, 6000, ("E5", "B5", "G#6")), 0.7), (sparkle(0.7, rng, 16), 0.4), (glass(note("E6"), 0.9, rng), 0.3, 0.6)), 1.0, 0.25, rng=rng)


def ui_equip(rng):
    rustle = bandpass(noise(0.15, rng), 1500, 6000) * env_bell(0.15, 0.3)
    return reverb(mix((rustle, 0.4), (steel(2100, 0.25, rng, 0.5), 0.45, 0.08), (click(rng, 0.003, 3000), 0.4, 0.08)), 0.3, 0.1, rng=rng)


# The roll ---------------------------------------------------------------------------------------------------

def roll_tick(rng):
    return mix((click(rng, 0.002, 3000), 0.6), (modal(1800, [1, 2.7], [0.02, 0.012], [1, 0.4], 0.06, rng), 0.6))


def spin_hum(rng, seconds=2.0):
    """A loop: a low turning drone (every partial whole cycles in the loop)."""
    t = t_of(seconds)
    drone = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((55, 1), (110, 0.6), (165, 0.25), (220, 0.15)))
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * 2 * t)  # (turning: 2 Hz, whole in the loop)
    whir = bandpass(noise(seconds, rng), 600, 2500)
    k = n_of(0.25)
    whir[:k] = whir[:k] * np.linspace(0, 1, k) + whir[-k:] * np.linspace(1, 0, k)  # (seamless)
    whir = whir[: len(t)]
    return drone * 0.6 + whir * 0.15 * (0.7 + 0.3 * np.sin(2 * np.pi * 4 * t))


def roll_lock(rng):
    return reverb(saturate(mix((click(rng, 0.006, 1200), 0.8), (thump(130, 50, 0.25, 0.06), 1.0), (steel(420, 0.5, rng, 0.6), 0.4)), 1.8), 0.5, 0.15, rng=rng)


def reveal(rng, level):
    """Common (1) to Legendary (5): bigger and brighter the rarer."""
    notes = [("C5",), ("C5", "G5"), ("C5", "E5", "G5"), ("C5", "E5", "G5", "C6"), ("C5", "E5", "G5", "C6", "E6")][level - 1]
    layers = [(chime(notes, 0.075, rng, 0.8 + 0.3 * level, "bell", 0.6 + 0.2 * level), 0.8)]
    if level >= 3:
        layers.append((sparkle(0.4 + 0.2 * level, rng, 6 * level), 0.25 + 0.05 * level, 0.1))
    if level >= 4:
        layers.append((boom(0.8, rng, 100, 32, 0.4), 0.5))
    if level >= 5:
        layers.append((magic_swell(0.5, rng, 300, 6000), 0.5))
        layers.append((legendary_window(rng), 0.35, 0.2))
    return reverb(mix(*layers), 0.8 + 0.25 * level, 0.15 + 0.03 * level, rng=rng)


def seal_break(rng):
    return reverb(mix((saturate(highpass(noise(0.05, rng), 1200) * env_exp(0.05, 0.012), 3), 0.9), (frost_shards(0.3, rng, 14), 0.8, 0.01), (thump(140, 50, 0.25), 0.6), (whoosh(0.35, rng, 2500, 500, 0.15), 0.4, 0.03)), 0.8, 0.2, rng=rng)


def attune(rng):
    return reverb(mix((magic_swell(1.0, rng, 300, 5000, ("A4", "E5", "C#6")), 0.8), (chime(("A5", "E6"), 0.1, rng, 1.2), 0.4, 0.85)), 1.2, 0.25, rng=rng)


# The list ---------------------------------------------------------------------------------------------------
# file name -> (maker, seed, peak dB)
COMBAT = {
    "swing_1.mp3": (swing, 11, -2), "swing_2.mp3": (swing, 12, -2), "swing_3.mp3": (swing, 13, -2), "swing_4.mp3": (swing, 14, -2),
    "heavy_swing_1.mp3": (heavy_swing, 21, -1), "heavy_swing_2.mp3": (heavy_swing, 22, -1), "heavy_swing_3.mp3": (heavy_swing, 23, -1),
    "hit_1.mp3": (hit, 31, -1), "hit_2.mp3": (hit, 32, -1), "hit_3.mp3": (hit, 33, -1),
    "heavy_hit_1.mp3": (heavy_hit, 41, -0.5), "heavy_hit_2.mp3": (heavy_hit, 42, -0.5),
    "crit_1.mp3": (crit, 51, -0.5), "crit_2.mp3": (crit, 52, -0.5),
    "contact_1.mp3": (contact, 61, -6), "contact_2.mp3": (contact, 62, -6), "contact_3.mp3": (contact, 63, -6), "contact_4.mp3": (contact, 64, -6),
    "heavy_contact_1.mp3": (heavy_contact, 71, -4), "heavy_contact_2.mp3": (heavy_contact, 72, -4),
    "deflect_1.mp3": (deflect, 81, -2), "deflect_2.mp3": (deflect, 82, -2),
    "block_1.mp3": (block, 91, -1), "block_2.mp3": (block, 92, -1),
    "guard_break.mp3": (guard_break, 101, -0.5), "parry.mp3": (parry, 111, -1),
    "hop_1.mp3": (hop, 121, -6), "hop_2.mp3": (hop, 122, -6), "roll.mp3": (roll_sound, 131, -5),
    "cast_fire.mp3": (cast_fire, 141, -2), "cast_frost.mp3": (cast_frost, 142, -2), "cast_shock.mp3": (cast_shock, 143, -2), "cast_poison.mp3": (cast_poison, 144, -2),
    "impact_fire.mp3": (impact_fire, 151, -1), "impact_frost.mp3": (impact_frost, 152, -1), "impact_shock.mp3": (impact_shock, 153, -1), "impact_poison.mp3": (impact_poison, 154, -1),
    "cast.mp3": (cast, 161, -3), "bolt.mp3": (bolt, 162, -2), "beam.mp3": (beam, 163, -3), "nova_warn.mp3": (nova_warn, 164, -3), "blast.mp3": (blast, 165, -0.5),
    "zap.mp3": (zap, 171, -3), "burn.mp3": (burn, 172, -6), "freeze.mp3": (freeze, 173, -4), "corrode.mp3": (corrode, 174, -6),
    "heal.mp3": (heal, 181, -4), "shield.mp3": (shield_up, 182, -3),
    "hurt_1.mp3": (hurt, 191, -3), "hurt_2.mp3": (hurt, 192, -3), "stun.mp3": (stun, 193, -5), "winded.mp3": (winded, 194, -6),
    "combo.mp3": (combo, 201, -6), "death.mp3": (death, 202, -1), "warn.mp3": (warn, 203, -8), "kill.mp3": (kill, 204, -0.5),
    "charge.mp3": (charge, 211, -4), "level_up.mp3": (level_up, 212, -2), "kaiju_level_up.mp3": (lambda r: level_up(r, True), 213, -2),
    "call_back.mp3": (call_back, 214, -6), "deploy.mp3": (deploy, 215, -4),
    "coin_pop.mp3": (coin_pop, 221, -6), "coin_clink_1.mp3": (coin_clink, 222, -7), "coin_clink_2.mp3": (coin_clink, 223, -7), "coin_clink_3.mp3": (coin_clink, 224, -7),
    "coin_collect.mp3": (coin_collect, 225, -5), "coin_cash_in.mp3": (coin_cash_in, 226, -4),
    "legendary_window.mp3": (legendary_window, 231, -1),
}
UI = {
    "hover.mp3": (ui_hover, 301, -18), "click.mp3": (ui_click, 302, -10), "tab.mp3": (ui_tab, 303, -11), "confirm.mp3": (ui_confirm, 304, -8),
    "back.mp3": (ui_back, 305, -10), "open.mp3": (ui_open, 306, -10), "close.mp3": (ui_close, 307, -11), "notify.mp3": (ui_notify, 308, -8),
    "error.mp3": (ui_error, 309, -9), "coin.mp3": (coin_clink, 310, -8), "reward.mp3": (ui_reward, 311, -5), "craft.mp3": (ui_craft, 312, -5),
    "enchant.mp3": (ui_enchant, 313, -5), "equip.mp3": (ui_equip, 314, -8),
}
LOTTERY = {
    "tick.mp3": (roll_tick, 401, -10), "lock.mp3": (roll_lock, 402, -3),
    "reveal_1.mp3": (lambda r: reveal(r, 1), 403, -6), "reveal_2.mp3": (lambda r: reveal(r, 2), 404, -5), "reveal_3.mp3": (lambda r: reveal(r, 3), 405, -4),
    "reveal_4.mp3": (lambda r: reveal(r, 4), 406, -2), "reveal_5.mp3": (lambda r: reveal(r, 5), 407, -1),
    "seal_break.mp3": (seal_break, 408, -2), "attune.mp3": (attune, 409, -4), "spin_hum.ogg": (spin_hum, 410, -12),
}
GROUPS = {
    "combat": (COMBAT, os.path.join("assets", "sounds", "combat")),
    "ui": (UI, os.path.join("assets", "sounds")),
    "lottery": (LOTTERY, os.path.join("assets", "sounds", "lottery")),
}


def encode(samples, path):
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "x.wav")
        sf.write(wav, samples.astype(np.float32), SR, subtype="PCM_16")
        codec = ["-c:a", "libvorbis", "-q:a", "5"] if path.endswith(".ogg") else ["-c:a", "libmp3lame", "-q:a", "2"]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, *codec, path], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", help="a folder to write the groups into (default: the game's assets/sounds)")
    parser.add_argument("--only", choices=list(GROUPS), action="append")
    args = parser.parse_args()
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg is needed (for mp3 and ogg)")
    for group in args.only or list(GROUPS):
        table, home = GROUPS[group]
        out = os.path.join(args.out, group) if args.out else os.path.join(ROOT, home)
        os.makedirs(out, exist_ok=True)
        reel = []
        for name, (make, seed, peak) in table.items():
            rng = np.random.default_rng(seed)
            x = make(rng)
            loop = name.endswith(".ogg")
            x = master(x, peak, 0.0 if loop else 0.02, tail=not loop)
            encode(x, os.path.join(out, name))
            reel += [x, silence(0.35)]
            print(f"{group}/{name}  {len(x) / SR:.2f}s")
        encode(np.concatenate(reel), os.path.join(out, "_preview_all.mp3"))


if __name__ == "__main__":
    main()
