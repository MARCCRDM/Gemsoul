"""
Generates the combat sound effects into assets/sounds/combat/: a hard,
cyberpunk set (sub-bass punches, saturated energy blades, FM lasers,
bit-crushed grit, crystalline shields).

    pip install numpy scipy soundfile
    python tools/make_combat_sounds.py

Roblox plays uploaded audio only: run tools/upload_audio.py to upload them
and fill in the ids in src/client/Modules/CombatSound.luau (or upload by
hand in Creator Hub, Audio, and paste each id there). Until then built-in
Roblox sounds stand in.
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds", "combat")
RNG = np.random.default_rng(7)


# Building blocks ---------------------------------------------------------------------

def n_of(seconds):
    return int(SR * seconds)


def t_of(seconds):
    return np.arange(n_of(seconds)) / SR


def sweep(f0, f1, seconds, curve="exp"):
    """A frequency track from f0 to f1."""
    t = np.linspace(0, 1, n_of(seconds))
    return f0 * (f1 / f0) ** t if curve == "exp" else f0 + (f1 - f0) * t


def phase(freq):
    freq = np.broadcast_to(freq, freq.shape if np.ndim(freq) else (1,))
    return 2 * np.pi * np.cumsum(freq) / SR


def osc(kind, freq, seconds=None):
    if np.isscalar(freq):
        freq = np.full(n_of(seconds), float(freq))
    p = phase(freq)
    if kind == "sine":
        return np.sin(p)
    frac = (p / (2 * np.pi)) % 1.0
    if kind == "saw":
        return 2 * frac - 1
    if kind == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(frac - 0.5) - 1
    raise ValueError(kind)


def fm(carrier, ratio, index, seconds, index_decay=None):
    """FM tone: metallic, glassy, laser-like."""
    car = np.full(n_of(seconds), float(carrier)) if np.isscalar(carrier) else carrier
    idx = index * (np.exp(-t_of(seconds) / index_decay) if index_decay else 1.0)
    mod = np.sin(phase(car * ratio)) * idx
    return np.sin(phase(car) + mod)


def noise(seconds):
    return RNG.standard_normal(n_of(seconds))


def env(seconds, attack=0.002, decay=0.1, hold=0.0):
    t = t_of(seconds)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    d = np.where(t < attack + hold, 1.0, np.exp(-(t - attack - hold) / decay))
    return a * d


def filt(x, kind, cutoff, order=2):
    """Butterworth low/high/band pass (cutoff in Hz, a pair for band)."""
    wn = np.array(cutoff, dtype=float) / (SR / 2)
    wn = np.clip(wn, 1e-4, 0.999)
    sos = signal.butter(order, wn, btype=kind, output="sos")
    return signal.sosfilt(sos, x)


def swept_filter(x, kind, cut0, cut1, block=256):
    """A filter whose cutoff glides from cut0 to cut1 over the sound."""
    out = np.zeros_like(x)
    n = len(x)
    zi = None
    blocks = max(1, n // block)
    for b in range(blocks + 1):
        i, j = b * block, min(n, (b + 1) * block)
        if i >= n:
            break
        f = cut0 * (cut1 / cut0) ** (i / max(1, n))
        sos = signal.butter(2, min(0.99, f / (SR / 2)), btype=kind, output="sos")
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0
        out[i:j], zi = signal.sosfilt(sos, x[i:j], zi=zi)
    return out


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def crush(x, bits=6, hold=4):
    """Bit-crush and sample-hold: digital grit."""
    steps = 2 ** bits
    y = np.round(x * steps) / steps
    return np.repeat(y[::hold], hold)[: len(x)]


def mix(*parts):
    """(start_seconds, samples) parts into one buffer."""
    end = max(n_of(s) + len(p) for s, p in parts)
    out = np.zeros(end)
    for s, p in parts:
        i = n_of(s)
        out[i : i + len(p)] += p
    return out


def room(x, size=0.25, wet=0.25):
    """A small dark space: decaying, filtered echoes."""
    tail = n_of(size * 2)
    out = np.concatenate([x, np.zeros(tail)])
    for delay, gain in ((0.017, 0.6), (0.029, 0.45), (0.043, 0.35), (0.061, 0.25), (0.089, 0.18)):
        d = n_of(delay * size / 0.25)
        echo = np.zeros_like(out)
        echo[d : d + len(x)] = x * gain
        out += wet * filt(echo, "low", 3500)
    return out


def finish(x, peak):
    x = filt(x, "high", 25)  # no DC or sub-rumble below hearing
    fade_in, fade_out = n_of(0.002), n_of(0.015)
    x[:fade_in] *= np.linspace(0, 1, fade_in)
    x[-fade_out:] *= np.linspace(1, 0, fade_out)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


# Pieces reused across sounds.

def sub_punch(f0=150, f1=42, seconds=0.25, decay=0.09, amount=2.5):
    return drive(osc("sine", sweep(f0, f1, seconds)) * env(seconds, 0.001, decay), amount)


def crack(seconds=0.05, low=1500, decay=0.012):
    return filt(noise(seconds), "high", low) * env(seconds, 0.0005, decay)


def blade(seconds, f0, f1, peak_at=0.4):
    """An energy-blade whoosh: swept band noise over a saturated saw hum."""
    n = n_of(seconds)
    shape = np.minimum(np.linspace(0, 1, n) / peak_at, (1 - np.linspace(0, 1, n)) / (1 - peak_at)).clip(0, 1) ** 1.4
    air = swept_filter(noise(seconds), "band" if False else "low", f0 * 4, f1 * 4) - swept_filter(noise(seconds), "low", f0, f1) * 0.3
    hum = drive(osc("saw", sweep(f0 / 8, f0 / 12, seconds)), 1.5)
    hum = filt(hum, "low", 1200)
    zing = fm(sweep(f1, f0, seconds), 2.01, 3, seconds) * 0.25
    return (0.8 * air + 0.35 * hum + zing) * shape


# Real-world building blocks: struck metal rings at inharmonic modes (a bar
# or a plate, not a musical note), air moves as filtered noise, bodies thump.

def modal(f0, ratios, decays, amps, seconds, detune=0.004):
    """Struck metal/wood: decaying inharmonic modes, each a slightly detuned
    pair so it beats and shimmers like a real blade."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for r, d, a in zip(ratios, decays, amps):
        f = f0 * r
        for spread in (-detune, detune):
            out += a * np.sin(2 * np.pi * f * (1 + spread) * t + RNG.uniform(0, 6.28)) * np.exp(-t / d)
    return out * env(seconds, 0.0008, 10)


BAR = (1.0, 2.756, 5.404, 8.933, 13.34)  # a free bar (a blade)
PLATE = (1.0, 1.594, 2.136, 2.653, 3.156, 3.652)  # a struck plate (a shield)


def clang(f0=760, seconds=0.9, bright=1.0):
    return modal(f0, BAR, (0.5, 0.32, 0.18, 0.1, 0.06), (1, 0.6 * bright, 0.4 * bright, 0.25 * bright, 0.15 * bright), seconds)


def plate(f0=210, seconds=0.5):
    return modal(f0, PLATE, (0.22, 0.16, 0.12, 0.09, 0.07, 0.05), (1, 0.7, 0.55, 0.4, 0.3, 0.2), seconds, 0.01)


def whoosh(seconds, lo, hi, peak_at=0.45, q=1.6):
    """Air cut by a blade: band noise whose centre rises then falls with the
    swing's speed, louder at the fastest point."""
    n = n_of(seconds)
    x = np.linspace(0, 1, n)
    bell = np.exp(-((x - peak_at) ** 2) / (2 * 0.16 ** 2))
    out = np.zeros(n)
    src = noise(seconds)
    block = 256
    zi = None
    for b in range(0, n, block):
        j = min(n, b + block)
        centre = lo + (hi - lo) * bell[b]
        bw = centre / q
        band = (max(40, centre - bw / 2), min(SR / 2 - 100, centre + bw / 2))
        sos = signal.butter(2, np.array(band) / (SR / 2), btype="band", output="sos")
        if zi is None or zi.shape[0] != sos.shape[0]:
            zi = np.zeros((sos.shape[0], 2))
        out[b:j], zi = signal.sosfilt(sos, src[b:j], zi=zi)
    return out * bell ** 1.2


def thump(f0=130, f1=48, seconds=0.2, decay=0.06, amount=2.5):
    return sub_punch(f0, f1, seconds, decay, amount)


def click(seconds=0.012, low=2500):
    return filt(noise(seconds), "high", low) * env(seconds, 0.0002, 0.003)


def crunch(seconds=0.08, cutoff=2200, decay=0.02):
    return drive(filt(noise(seconds), "low", cutoff) * env(seconds, 0.0005, decay), 2.2)


def crackles(count, seconds, low=1500, spread=1.0):
    return mix(*[(RNG.uniform(0, seconds), crack(0.008, low, 0.0018) * RNG.uniform(0.3, 1) * spread) for _ in range(count)])


def limit(x, amount=1.6):
    """Glue and punch: soft-clip then re-normalise (a quick limiter)."""
    return drive(x / (np.max(np.abs(x)) + 1e-9), amount)


SOUNDS = {}


def sound(name, peak=0.8, variants=1):
    """Register a sound; with variants, name_1, name_2... each rendered with
    fresh randomness (fn gets the variant index)."""

    def wrap(fn):
        if variants == 1:
            SOUNDS[name] = (lambda: fn(0), peak)
        else:
            for v in range(variants):
                SOUNDS[f"{name}_{v + 1}"] = ((lambda v=v: fn(v)), peak)
        return fn

    return wrap


# Swords ------------------------------------------------------------------------------

@sound("swing", 0.7, variants=3)
def swing(v):
    secs = (0.26, 0.23, 0.29)[v]
    air = whoosh(secs, 500 + 120 * v, 3400 + 400 * v, 0.42 + 0.05 * v)
    edge = 0.06 * clang(1500 + 180 * v, secs, 0.6) * np.linspace(0, 1, n_of(secs)) ** 3  # the blade sings faintly
    return room(limit(air + edge, 1.3), 0.12, 0.12)


@sound("heavy_swing", 0.85, variants=2)
def heavy_swing(v):
    secs = 0.46 + 0.05 * v
    air = whoosh(secs, 260, 2200 + 300 * v, 0.55, q=1.2)
    weight = 0.55 * thump(85, 38, secs, 0.22, 1.6) * np.linspace(0.2, 1, n_of(secs)) ** 2
    grunt = filt(noise(secs), "low", 400) * whoosh(secs, 100, 300, 0.55) * 0.4
    return room(limit(mix((0, air), (0, weight), (0, grunt)), 1.4), 0.2, 0.18)


@sound("hit", 0.95, variants=3)
def hit(v):
    """A sword landing on armour: a sharp click, a body thump, a crunch and a
    short metal clank."""
    tick = click(0.012, 3000)
    body = thump(150 - 15 * v, 45, 0.22, 0.06, 3)
    grit = crunch(0.09, 2000 + 400 * v, 0.022)
    metal = 0.32 * modal(380 + 90 * v, PLATE, (0.09, 0.07, 0.05, 0.04, 0.03, 0.02), (1, 0.7, 0.5, 0.35, 0.25, 0.15), 0.2, 0.02)
    return room(limit(mix((0, tick), (0, body), (0.002, 0.8 * grit), (0.001, metal)), 1.8), 0.14, 0.14)


@sound("heavy_hit", 1.0, variants=2)
def heavy_hit(v):
    base = hit(v)
    boom = thump(110, 32, 0.45, 0.14, 3.2)
    debris = crackles(10, 0.2, 1200, 0.5)
    ring = 0.2 * plate(170 + 30 * v, 0.6)
    return room(limit(mix((0, base), (0, boom), (0.02, debris), (0.005, ring)), 1.6), 0.25, 0.2)


@sound("crit", 0.95, variants=2)
def crit(v):
    base = hit(v)
    shine = 0.45 * clang(1180 + 160 * v, 0.9, 1.3)
    glint = filt(noise(0.35), "high", 7000) * env(0.35, 0.003, 0.09) * 0.25
    boom = 0.6 * thump(140, 35, 0.3, 0.1, 3)
    return room(limit(mix((0, base), (0, boom), (0.008, shine), (0.012, glint)), 1.5), 0.3, 0.22)


@sound("block", 0.88, variants=2)
def block(v):
    """A blade on a shield: a plate's dull ring, the thud behind it, a clank."""
    ring = plate(190 + 40 * v, 0.55)
    thud = 0.8 * thump(150, 70, 0.14, 0.035, 2.5)
    clank = 0.35 * clang(900 + 120 * v, 0.35, 0.8)
    return room(limit(mix((0, click(0.01, 2000)), (0, ring), (0, thud), (0.003, clank)), 1.7), 0.25, 0.25)


@sound("guard_break", 0.97)
def guard_break(v):
    crash = drive(filt(noise(0.6), "high", 500) * env(0.6, 0.001, 0.12), 2)
    splinter = crackles(30, 0.35, 900, 0.8)
    fall = 0.4 * modal(320, PLATE, (0.5, 0.35, 0.25, 0.2, 0.15, 0.1), (1, 0.8, 0.6, 0.5, 0.4, 0.3), 0.9, 0.02)
    sub = thump(120, 30, 0.55, 0.18, 3)
    wobble = fall * (1 + 0.5 * np.sin(2 * np.pi * 9 * t_of(0.9)))
    return room(limit(mix((0, crash), (0.01, splinter), (0, wobble), (0, sub)), 1.6), 0.4, 0.3)


@sound("parry", 0.9)
def parry(v):
    """Steel meets steel and slides: a bright clash, then the long ring."""
    clash = clang(1240, 1.4, 1.4)
    second = 0.6 * clang(1610, 1.2, 1.1)
    scrape = whoosh(0.35, 3000, 7000, 0.3, q=3) * 0.5
    return room(limit(mix((0, click(0.01, 4000)), (0, clash), (0.006, second), (0.01, scrape)), 1.4), 0.45, 0.32)


# Movement ----------------------------------------------------------------------------

@sound("hop", 0.55, variants=2)
def hop(v):
    air = whoosh(0.2, 600, 2200 + 300 * v, 0.35) * 0.8
    gear = 0.25 * modal(620 + 80 * v, PLATE, (0.05,) * 6, (1, 0.6, 0.4, 0.3, 0.2, 0.1), 0.1, 0.03)
    land = 0.6 * mix((0, thump(150, 70, 0.1, 0.03, 2)), (0, crunch(0.05, 1500, 0.012)))
    return mix((0, air), (0, gear), (0.17, land))


@sound("roll", 0.7)
def roll(v):
    air = whoosh(0.36, 400, 1800, 0.4)
    tumble = mix(*[(0.06 + 0.07 * i, 0.4 * crunch(0.06, 1200, 0.018)) for i in range(4)])
    land = 0.7 * thump(130, 55, 0.14, 0.04, 2.5)
    return mix((0, air), (0, tumble), (0.3, land))


# Surges (element casts and impacts) --------------------------------------------------

def fire_body(seconds):
    roar = swept_filter(noise(seconds), "low", 300, 3000) * env(seconds, 0.02, seconds * 0.4)
    return mix((0, drive(roar, 2.2)), (0, 0.5 * crackles(18, seconds * 0.8, 1500)))


def frost_body(seconds):
    shards = mix(*[(RNG.uniform(0, seconds * 0.5), 0.35 * modal(RNG.uniform(2000, 5200), (1, 2.3, 3.9), (0.12, 0.07, 0.04), (1, 0.5, 0.3), 0.3, 0.002)) for _ in range(14)])
    mist = filt(noise(seconds), "high", 6000) * env(seconds, 0.03, seconds * 0.4) * 0.3
    return mix((0, shards), (0, mist))


def shock_body(seconds):
    arcs = mix(*[(RNG.uniform(0, seconds * 0.7), fm(RNG.uniform(800, 3200), RNG.uniform(1.3, 3.7), 7, 0.05, 0.02) * env(0.05, 0.0005, 0.012)) for _ in range(22)])
    hum = filt(osc("saw", 100, seconds) + osc("saw", 150.5, seconds), "band", (150, 3000)) * env(seconds, 0.003, seconds * 0.35) * 0.35
    return crush(mix((0, arcs), (0, hum)), 7, 2)


def poison_body(seconds):
    bubbles = mix(*[(RNG.uniform(0, seconds * 0.8), fm(sweep(RNG.uniform(250, 500), RNG.uniform(800, 1500), 0.08), 1.5, 2, 0.08) * env(0.08, 0.003, 0.03)) for _ in range(20)])
    hiss = filt(noise(seconds), "band", (2500, 9000)) * env(seconds, 0.02, seconds * 0.4) * 0.5
    gurgle = filt(noise(seconds), "low", 500) * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * t_of(seconds))) * env(seconds, 0.02, seconds * 0.4) * 0.6
    return mix((0, bubbles), (0, hiss), (0, gurgle))


BODIES = {"fire": fire_body, "frost": frost_body, "shock": shock_body, "poison": poison_body}


def element_cast(name):
    """Releasing a surge: a charge rushing up, then the element bursting out."""
    def build(v):
        rise = swept_filter(drive(osc("saw", sweep(90, 360, 0.35)) + osc("saw", sweep(91, 364, 0.35)), 1.5), "low", 300, 5000)
        rise *= np.linspace(0.1, 1, n_of(0.35)) ** 2 * 0.45
        release = BODIES[name](0.6)
        punch = 0.6 * thump(170, 60, 0.15, 0.04, 2)
        return room(limit(mix((0, rise), (0.3, punch), (0.3, release)), 1.4), 0.35, 0.28)
    return build


def element_impact(name):
    """A surge or enchanted blade striking: the hit plus the element."""
    def build(v):
        body = BODIES[name](0.45)
        punch = thump(160, 50, 0.2, 0.05, 2.5)
        return room(limit(mix((0, click(0.01, 2500)), (0, punch), (0, body)), 1.5), 0.25, 0.2)
    return build


for _element in ("fire", "frost", "shock", "poison"):
    sound("cast_" + _element, 0.78)(element_cast(_element))
    sound("impact_" + _element, 0.85)(element_impact(_element))


@sound("cast", 0.7)
def cast(v):
    seconds = 0.7
    rise = swept_filter(drive(osc("saw", sweep(110, 440, seconds)), 1.5), "low", 300, 6000)
    shape = np.linspace(0.2, 1, n_of(seconds)) ** 1.5
    shimmer = 0.3 * clang(1760, seconds, 0.6)
    return room(mix((0, rise * shape * 0.6), (0, shimmer)), 0.3, 0.3)


@sound("bolt", 0.82)
def bolt(v):
    growl = filt(drive(osc("saw", sweep(110, 60, 0.5)) + osc("saw", sweep(113, 61, 0.5)), 3), "low", 1500) * env(0.5, 0.01, 0.2)
    air = whoosh(0.45, 400, 2600, 0.3)
    return room(limit(mix((0, 0.6 * growl), (0, air), (0, 0.4 * fire_body(0.45))), 1.4), 0.3, 0.25)


@sound("beam", 0.75)
def beam(v):
    seconds = 0.5
    t = t_of(seconds)
    tone = fm(sweep(520, 380, seconds), 1.5, 3, seconds) * (0.7 + 0.3 * np.sin(2 * np.pi * 31 * t))
    sizzle = filt(noise(seconds), "high", 4000) * 0.3
    return room(limit((tone * 0.6 + sizzle) * env(seconds, 0.005, 0.2), 1.4), 0.25, 0.2)


@sound("nova_warn", 0.62)
def nova_warn(v):
    seconds = 1.0
    t = t_of(seconds)
    pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (4 + 16 * t) * t))
    tone = swept_filter(drive(osc("saw", sweep(60, 260, seconds)), 2) * pulse, "low", 300, 4000)
    rumble = filt(noise(seconds), "low", 200) * np.linspace(0.2, 1, n_of(seconds)) * 0.8
    return (tone + rumble) * np.linspace(0.3, 1, n_of(seconds))


@sound("blast", 1.0)
def blast(v):
    boom = thump(100, 26, 1.4, 0.45, 3.2)
    roar = drive(filt(noise(1.3), "low", 1400) * env(1.3, 0.002, 0.4), 2.5)
    debris = mix((0, crackles(40, 0.8, 1000, 0.6)), (0, crush(filt(noise(1.0), "high", 2500) * env(1.0, 0.01, 0.3), 5, 4) * 0.3))
    ring = 0.15 * plate(140, 1.2)
    return room(limit(mix((0, 1.2 * boom), (0, roar), (0.03, debris), (0.01, ring)), 1.5), 0.7, 0.4)


@sound("zap", 0.8)
def zap(v):
    return room(shock_body(0.35), 0.2, 0.2)


@sound("burn", 0.75)
def burn(v):
    return mix((0, whoosh(0.25, 300, 1500, 0.3)), (0.05, fire_body(0.7)))


@sound("freeze", 0.75)
def freeze(v):
    return room(frost_body(0.7), 0.5, 0.4)


@sound("corrode", 0.7)
def corrode(v):
    return room(poison_body(0.6), 0.25, 0.2)


@sound("heal", 0.65)
def heal(v):
    notes = (523.3, 659.3, 784.0, 1046.5, 1318.5)
    arp = mix(*[(i * 0.06, (osc("tri", f, 0.6) + 0.3 * osc("sine", f * 2.005, 0.6)) * env(0.6, 0.004, 0.22)) for i, f in enumerate(notes)])
    shimmer = filt(noise(0.9), "high", 7000) * env(0.9, 0.1, 0.3) * 0.15
    return room(mix((0, arp), (0.05, shimmer)), 0.6, 0.45)


@sound("shield", 0.72)
def shield(v):
    seconds = 0.7
    up = swept_filter(drive(osc("saw", sweep(80, 320, seconds)) + osc("saw", sweep(81, 324, seconds)), 1.5), "low", 200, 5000)
    ring = 0.5 * clang(1318, 0.8, 0.8)
    shape = np.minimum(np.linspace(0, 3, n_of(seconds)), 1) * env(seconds, 0.05, 0.3, 0.2)
    return room(mix((0, up * shape * 0.5), (0.35, ring)), 0.45, 0.32)


# Being hit, stunned and winded ---------------------------------------------------------

@sound("hurt", 0.9, variants=2)
def hurt(v):
    body = thump(120 - 10 * v, 42, 0.26, 0.08, 3)
    grit = crunch(0.1, 1600 + 400 * v, 0.025)
    breath = filt(noise(0.18), "band", (500, 1800)) * env(0.18, 0.005, 0.06) * 0.35  # a grunt of air
    return mix((0, body), (0, 0.8 * grit), (0.01, breath))


@sound("stun", 0.7)
def stun(v):
    """Your ears ring: a high whine that wobbles, under a muffled thud."""
    seconds = 1.3
    t = t_of(seconds)
    whine = np.sin(2 * np.pi * 3100 * t + 3 * np.sin(2 * np.pi * 6 * t)) * env(seconds, 0.02, 0.6) * 0.35
    birds = mix(*[(0.15 + i * 0.22, 0.25 * clang(2400 + 300 * (i % 3), 0.25, 0.4)) for i in range(4)])
    thud = filt(thump(110, 40, 0.4, 0.12, 2.5), "low", 600)
    return room(mix((0, thud), (0.02, whine), (0.05, birds)), 0.4, 0.3)


@sound("winded", 0.6)
def winded(v):
    """Out of breath: two heavy exhales."""
    def exhale(seconds):
        x = filt(noise(seconds), "band", (350, 2200)) * env(seconds, 0.04, seconds * 0.45)
        return x * (1 + 0.3 * np.sin(2 * np.pi * 7 * t_of(seconds)))

    return mix((0, exhale(0.45)), (0.5, 0.8 * exhale(0.4)))


@sound("combo", 0.55)
def combo(v):
    return mix((0, 0.6 * clang(1980, 0.35, 0.5)), (0, click(0.01, 5000)))


@sound("death", 0.92)
def death(v):
    seconds = 1.4
    shutdown = crush(drive(osc("saw", sweep(600, 40, seconds)), 2) * env(seconds, 0.005, 0.5), 5, 5) * 0.5
    burst = drive(filt(noise(0.4), "high", 800) * env(0.4, 0.001, 0.1), 2)
    sub = thump(140, 28, 0.9, 0.3, 3)
    clatter = mix(*[(0.25 + 0.12 * i, 0.3 * plate(260 + 60 * i, 0.3)) for i in range(3)])  # armour hitting the floor
    return room(limit(mix((0, shutdown), (0, burst), (0, sub), (0, clatter)), 1.4), 0.5, 0.35)


@sound("warn", 0.55)
def warn(v):
    def beep(f):
        return filt(osc("square", f, 0.07), "low", 5000) * env(0.07, 0.002, 0.05, 0.03)

    return mix((0, beep(1480)), (0.09, beep(1975)))


@sound("kill", 0.72)
def kill(v):
    chord = (220.0, 261.6, 329.6, 440.0, 523.3)
    stab = sum((osc("saw", f, 1.4) + osc("saw", f * 1.006, 1.4)) * 0.2 for f in chord)
    stab = swept_filter(stab, "low", 6000, 600) * env(1.4, 0.004, 0.5)
    ring = 0.3 * clang(880, 1.4, 1.0)
    return room(mix((0, thump(160, 45, 0.4, 0.12, 3)), (0, stab), (0, ring)), 0.7, 0.4)


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, (fn, peak) in SOUNDS.items():
        # A little headroom: MP3 encoding overshoots peaks slightly.
        x = finish(np.asarray(fn(), dtype=np.float64), peak * 0.88)
        # Trim the inaudible tail (below -54 dB), then fade what's left out.
        loud = np.nonzero(np.abs(x) > peak * 0.002)[0]
        end = min(len(x), (loud[-1] if len(loud) else len(x)) + n_of(0.02))
        x = x[:end]
        tail = min(len(x), n_of(0.03))
        x[-tail:] *= np.linspace(1, 0, tail)
        x = x.astype(np.float32)
        rendered[name] = x
        sf.write(os.path.join(OUT, name + ".mp3"), x, SR, format="MP3")
        print(f"{name:12s} {len(x) / SR * 1000:5.0f} ms")
    gap = np.zeros(n_of(0.45), dtype=np.float32)
    preview = np.concatenate([np.concatenate([x, gap]) for x in rendered.values()])
    sf.write(os.path.join(OUT, "_preview_all.mp3"), preview, SR, format="MP3")
    print("order:", ", ".join(rendered))


if __name__ == "__main__":
    sys.exit(main())
