"""
Generates the combat sound effects into assets/sounds/combat/.

    pip install numpy soundfile
    python tools/make_combat_sounds.py

Synthesised like the menu sounds (tools/make_sounds.py, whose building blocks
this reuses). Roblox plays uploaded audio only: upload each .mp3 in Creator
Hub (Audio), then paste its id into src/client/Modules/CombatSound.luau.
Until then a built-in Roblox sound stands in for each.
"""
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
from make_sounds import SR, bell, decay, finish, noise, place, reverb, tone, ts  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds", "combat")


def lowpass(x, cutoff):
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    for i in range(1, len(x)):
        y[i] = y[i - 1] + a * (x[i] - y[i - 1])
    return y


def mix(*parts):
    """Add sounds of different lengths together, all starting at once."""
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[: len(p)] += p
    return out


def swell(n, peak_at=0.4):
    """Rise then fall, peaking `peak_at` of the way through."""
    t = np.linspace(0, 1, n)
    rise = np.clip(t / peak_at, 0, 1)
    fall = np.clip((1 - t) / (1 - peak_at), 0, 1)
    return np.minimum(rise, fall) ** 1.5


def whoosh(seconds, low, high, seed=1, peak_at=0.45):
    """Air moving past: noise swept through a band, swelling and fading."""
    rng = np.random.default_rng(seed)
    n = int(SR * seconds)
    x = rng.standard_normal(n)
    env = swell(n, peak_at)
    coeff = 1 - np.exp(-2 * np.pi * (low + (high - low) * env) / SR)
    out = np.zeros(n)
    y1 = y2 = 0.0
    for i in range(n):
        a = coeff[i]
        y1 += a * (x[i] - y1)
        y2 += a * 0.5 * (y1 - y2)
        out[i] = y1 - y2
    return out * env


def crackle(seconds, rate, seed=2, tau=0.0015):
    """Random sharp clicks: fire, electricity."""
    rng = np.random.default_rng(seed)
    n = int(SR * seconds)
    out = np.zeros(n)
    clicks = rng.random(n) < rate / SR
    click = rng.standard_normal(int(SR * 0.006)) * decay(int(SR * 0.006), tau, 0.0002)
    for i in np.nonzero(clicks)[0]:
        j = min(n, i + len(click))
        out[i:j] += click[: j - i] * rng.uniform(0.3, 1.0)
    return out


def thump(f0, f1, seconds, tau):
    return tone(f0, seconds, tau, harmonics=((1, 1.0), (2, 0.25)), glide_to=f1)


def metal(f, seconds, tau, seed=4):
    partials = ((1.0, 1.0, 1.0), (2.76, 0.6, 1.6), (5.4, 0.35, 2.4), (8.93, 0.2, 3.3))
    ring_ = sum(level * tone(f * ratio, seconds, tau / speed) for ratio, level, speed in partials)
    hit = noise(0.02, 0.004, highpass=2000, seed=seed)
    return place([(0, ring_), (0, 0.8 * hit)], seconds)


SOUNDS = {}


def sound(name, peak=0.7):
    def wrap(fn):
        SOUNDS[name] = (fn, peak)
        return fn

    return wrap


@sound("swing", 0.6)
def swing():
    return whoosh(0.22, 700, 3800, seed=11, peak_at=0.4)


@sound("heavy_swing", 0.75)
def heavy_swing():
    air = whoosh(0.38, 300, 2200, seed=12, peak_at=0.55)
    body = 0.5 * thump(110, 70, 0.38, 0.15) * swell(int(SR * 0.38), 0.55)
    return place([(0, air), (0, body)], 0.4)


@sound("shot", 0.6)
def shot():
    pew = tone(2400, 0.16, 0.05, harmonics=((1, 1.0), (1.5, 0.3)), glide_to=420)
    snap = noise(0.02, 0.003, highpass=3000, seed=13)
    return reverb(place([(0, pew), (0, 0.7 * snap)], 0.18), 0.12, 0.08)


@sound("hit", 0.85)
def hit():
    body = thump(170, 60, 0.18, 0.06)
    smack = lowpass(noise(0.06, 0.012, seed=14), 3500)
    return reverb(place([(0, body), (0, 1.2 * smack)], 0.2), 0.12, 0.06)


@sound("crit", 0.9)
def crit():
    body = thump(190, 55, 0.22, 0.07)
    smack = noise(0.05, 0.01, highpass=1500, seed=15)
    shine = mix(bell(1760, 0.45, 0.12), 0.5 * bell(2637, 0.4, 0.1))
    return reverb(place([(0, body), (0, smack), (0.01, 0.45 * shine)], 0.5), 0.25, 0.2)


@sound("block", 0.75)
def block():
    return reverb(metal(620, 0.4, 0.12, seed=16), 0.25, 0.15)


@sound("guard_break", 0.85)
def guard_break():
    crack = mix(noise(0.12, 0.04, highpass=900, seed=17), crackle(0.25, 600, seed=18))
    fall = metal(520, 0.5, 0.15, seed=19) * np.linspace(1, 0.3, int(SR * 0.5))
    low = thump(120, 45, 0.4, 0.15)
    return reverb(place([(0, crack), (0, 0.7 * fall), (0, 0.8 * low)], 0.55), 0.3, 0.2)


@sound("parry", 0.75)
def parry():
    shing = tone(1200, 0.5, 0.18, harmonics=((1, 1.0), (2.01, 0.5), (3.02, 0.2)), glide_to=2000)
    clash = metal(900, 0.3, 0.08, seed=20)
    return reverb(place([(0, clash), (0.02, 0.6 * shing)], 0.55), 0.35, 0.25)


@sound("hop", 0.45)
def hop():
    air = whoosh(0.16, 900, 2600, seed=21, peak_at=0.3)
    tick = 0.3 * noise(0.015, 0.003, highpass=2500, seed=22)
    return place([(0, tick), (0, air)], 0.18)


@sound("roll", 0.6)
def roll():
    air = whoosh(0.32, 500, 2000, seed=23, peak_at=0.35)
    land = 0.5 * place([(0, thump(140, 70, 0.1, 0.03)), (0, lowpass(noise(0.08, 0.02, seed=24), 1800))], 0.1)
    return place([(0, air), (0.26, land)], 0.4)


@sound("cast", 0.55)
def cast():
    rise = tone(300, 0.6, 0.5, harmonics=((1, 1.0), (2, 0.4), (3, 0.2)), glide_to=1200, vibrato=9)
    shimmer = noise(0.6, 0.4, highpass=5000, seed=25) * np.linspace(0.1, 1, int(SR * 0.6))
    return reverb(place([(0, 0.8 * rise * swell(int(SR * 0.6), 0.85)), (0, 0.2 * shimmer)], 0.62), 0.3, 0.2)


@sound("bolt", 0.7)
def bolt():
    roar = whoosh(0.35, 400, 1800, seed=26, peak_at=0.2)
    zip_ = tone(1600, 0.25, 0.1, glide_to=300)
    return reverb(place([(0, roar), (0, 0.35 * zip_)], 0.4), 0.2, 0.12)


@sound("nova_warn", 0.5)
def nova_warn():
    n = int(SR * 0.9)
    t = ts(0.9)
    hum = np.sin(2 * np.pi * 90 * t) + 0.5 * np.sin(2 * np.pi * 180 * t)
    pulse = 0.55 + 0.45 * np.sin(2 * np.pi * (4 + 8 * t) * t)
    rise = tone(200, 0.9, 2.0, glide_to=800) * np.linspace(0, 0.6, n)
    return (hum * pulse + rise) * swell(n, 0.9)


@sound("blast", 0.95)
def blast():
    boom = thump(90, 30, 0.9, 0.35)
    body = lowpass(noise(0.9, 0.3, seed=27), 900)
    debris = crackle(0.7, 160, seed=28) * np.linspace(1, 0, int(SR * 0.7))
    return reverb(place([(0, 1.2 * boom), (0, 1.4 * body), (0.05, 0.5 * debris)], 1.0), 0.35, 0.35)


@sound("zap", 0.7)
def zap():
    buzz = np.sign(np.sin(2 * np.pi * 120 * ts(0.3))) * decay(int(SR * 0.3), 0.1)
    sparks = crackle(0.3, 900, seed=29)
    return reverb(place([(0, 0.35 * lowpass(buzz, 2500)), (0, sparks)], 0.32), 0.15, 0.1)


@sound("burn", 0.6)
def burn():
    roar = lowpass(noise(0.6, 0.3, seed=30), 1400) * swell(int(SR * 0.6), 0.25)
    pops = crackle(0.6, 70, seed=31)
    ignite = whoosh(0.25, 300, 1500, seed=32, peak_at=0.3)
    return place([(0, ignite), (0.05, roar), (0.05, 0.5 * pops)], 0.66)


@sound("freeze", 0.65)
def freeze():
    chimes = sum(0.5 * bell(f, 0.6, 0.18) for f in (2093, 2637, 3136))
    frost = noise(0.5, 0.2, highpass=4500, seed=33)
    crack = 0.6 * crackle(0.15, 1200, seed=34)
    return reverb(place([(0, crack), (0.02, chimes), (0, 0.4 * frost)], 0.7), 0.45, 0.35)


@sound("corrode", 0.55)
def corrode():
    rng = np.random.default_rng(35)
    parts = [(rng.uniform(0, 0.35), 0.6 * tone(rng.uniform(350, 700), 0.08, 0.02, glide_to=rng.uniform(900, 1400))) for _ in range(9)]
    hiss = noise(0.5, 0.25, highpass=3500, seed=36)
    return reverb(place(parts + [(0, 0.35 * hiss)], 0.5), 0.2, 0.12)


@sound("heal", 0.55)
def heal():
    notes = (523.3, 784.0, 1046.5, 1568.0)
    parts = [(i * 0.07, 0.8 * bell(f, 0.6, 0.25)) for i, f in enumerate(notes)]
    sparkle = noise(0.6, 0.3, highpass=6000, seed=37)
    return reverb(place(parts + [(0.1, 0.12 * sparkle)], 0.9), 0.45, 0.35)


@sound("shield", 0.55)
def shield():
    sweep = tone(180, 0.45, 0.4, harmonics=((1, 1.0), (2, 0.5), (3, 0.25)), glide_to=520)
    shimmer = noise(0.45, 0.25, highpass=5000, seed=38)
    ping = bell(1318.5, 0.4, 0.15)
    return reverb(place([(0, sweep), (0, 0.15 * shimmer), (0.3, 0.5 * ping)], 0.7), 0.35, 0.25)


@sound("hurt", 0.8)
def hurt():
    body = thump(110, 50, 0.22, 0.08)
    grit = lowpass(noise(0.1, 0.03, seed=39), 1800)
    return place([(0, body), (0, 0.9 * grit)], 0.24)


@sound("death", 0.85)
def death():
    rng = np.random.default_rng(40)
    shards = [(rng.uniform(0, 0.4), 0.4 * bell(rng.uniform(1500, 4200), 0.3, 0.06)) for _ in range(14)]
    burst = noise(0.3, 0.1, highpass=1200, seed=41)
    low = thump(150, 40, 0.6, 0.25)
    return reverb(place(shards + [(0, burst), (0, 0.8 * low)], 0.9), 0.35, 0.3)


@sound("warn", 0.5)
def warn():
    beep = lambda f: tone(f, 0.08, 0.05, harmonics=((1, 1.0), (3, 0.3)))  # noqa: E731
    return place([(0, beep(1320)), (0.1, beep(1760))], 0.2)


@sound("kill", 0.6)
def kill():
    notes = (392.0, 523.3, 659.3, 784.0)
    parts = [(i * 0.09, bell(f, 0.8, 0.3)) for i, f in enumerate(notes)]
    hit_ = thump(160, 60, 0.3, 0.1)
    return reverb(place([(0, 0.7 * hit_)] + parts, 1.2), 0.45, 0.4)


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, (fn, peak) in SOUNDS.items():
        x = finish(fn().astype(np.float64), peak).astype(np.float32)
        rendered[name] = x
        sf.write(os.path.join(OUT, name + ".mp3"), x, SR, format="MP3")
        print(f"{name:12s} {len(x) / SR * 1000:5.0f} ms  peak {np.max(np.abs(x)):.2f}")
    gap = np.zeros(int(SR * 0.45), dtype=np.float32)
    preview = np.concatenate([np.concatenate([x, gap]) for x in rendered.values()])
    sf.write(os.path.join(OUT, "_preview_all.mp3"), preview, SR, format="MP3")
    print("order:", ", ".join(rendered))


if __name__ == "__main__":
    sys.exit(main())
