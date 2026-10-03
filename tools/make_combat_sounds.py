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


SOUNDS = {}


def sound(name, peak=0.8):
    def wrap(fn):
        SOUNDS[name] = (fn, peak)
        return fn

    return wrap


@sound("swing", 0.7)
def swing():
    return room(blade(0.24, 700, 3600, 0.35), 0.15, 0.15)


@sound("heavy_swing", 0.85)
def heavy_swing():
    body = blade(0.42, 400, 2400, 0.55)
    sub = 0.6 * sub_punch(90, 40, 0.42, 0.2, 2) * np.linspace(0.3, 1, n_of(0.42))
    return room(mix((0, body), (0, sub)), 0.2, 0.2)


@sound("shot", 0.75)
def shot():
    laser = fm(sweep(3200, 260, 0.2), 1.5, 4, 0.2, 0.05) * env(0.2, 0.001, 0.07)
    snap = crack(0.03, 2500, 0.006)
    thump = 0.5 * sub_punch(180, 60, 0.12, 0.04)
    return room(crush(mix((0, laser), (0, snap), (0, thump)), 8, 2), 0.18, 0.2)


@sound("hit", 0.95)
def hit():
    punch = sub_punch(170, 45, 0.22, 0.07, 3)
    grit = crush(crack(0.07, 900, 0.018), 5, 3)
    clank = 0.25 * fm(310, 2.7, 2, 0.12, 0.03) * env(0.12, 0.001, 0.03)
    return room(drive(mix((0, punch), (0, 0.8 * grit), (0, clank)), 1.6), 0.15, 0.15)


@sound("crit", 0.95)
def crit():
    base = hit()
    shine = fm(1760, 3.5, 2.5, 0.6, 0.2) * env(0.6, 0.002, 0.18) * 0.45
    sparkle = crush(filt(noise(0.4), "high", 6000) * env(0.4, 0.002, 0.12), 6, 3) * 0.3
    return room(mix((0, base), (0.01, shine), (0.02, sparkle)), 0.3, 0.25)


@sound("block", 0.85)
def block():
    ping = fm(880, 1.414, 3, 0.5, 0.08) * env(0.5, 0.001, 0.14)
    buzz = filt(osc("square", 140, 0.18), "band", (300, 2400)) * env(0.18, 0.001, 0.05) * 0.35
    thud = 0.6 * sub_punch(140, 70, 0.15, 0.04)
    return room(mix((0, ping), (0, buzz), (0, thud), (0, 0.5 * crack(0.03))), 0.3, 0.3)


@sound("guard_break", 0.95)
def guard_break():
    crash = drive(filt(noise(0.5), "high", 600) * env(0.5, 0.001, 0.12), 2)
    fall = drive(osc("saw", sweep(900, 80, 0.5)), 2) * env(0.5, 0.005, 0.2) * 0.5
    glitch = crush(fm(sweep(1200, 300, 0.3), 2.2, 5, 0.3), 3, 9) * env(0.3, 0.001, 0.1) * 0.4
    sub = sub_punch(120, 35, 0.5, 0.18, 3)
    return room(mix((0, crash), (0, fall), (0.03, glitch), (0, sub)), 0.4, 0.3)


@sound("parry", 0.85)
def parry():
    shing = fm(sweep(1400, 2600, 0.6), 2.0, 2, 0.6, 0.25) * env(0.6, 0.001, 0.22)
    clash = fm(1100, 2.76, 4, 0.2, 0.04) * env(0.2, 0.0005, 0.05)
    return room(mix((0, clash), (0.01, 0.7 * shing), (0, 0.5 * crack(0.03, 3000))), 0.4, 0.35)


@sound("hop", 0.55)
def hop():
    servo = filt(osc("saw", sweep(300, 900, 0.12)), "band", (400, 3000)) * env(0.12, 0.002, 0.05) * 0.4
    air = blade(0.16, 900, 2400, 0.3) * 0.7
    return mix((0, servo), (0, air))


@sound("roll", 0.7)
def roll():
    air = blade(0.32, 500, 1900, 0.35)
    land = 0.7 * mix((0, sub_punch(130, 55, 0.12, 0.04)), (0, filt(noise(0.1), "low", 1500) * env(0.1, 0.001, 0.03)))
    servo = filt(osc("saw", sweep(500, 200, 0.2)), "band", (300, 2000)) * env(0.2, 0.002, 0.08) * 0.3
    return mix((0, air), (0, servo), (0.26, land))


@sound("cast", 0.7)
def cast():
    seconds = 0.7
    rise = swept_filter(drive(osc("saw", sweep(110, 440, seconds)), 1.5), "low", 300, 6000)
    blips = mix(*[
        (i * 0.09, fm(440 * 2 ** (k / 12), 2, 1.5, 0.08, 0.03) * env(0.08, 0.001, 0.03))
        for i, k in enumerate((0, 3, 7, 12, 15, 19, 24))
    ])
    shape = np.linspace(0.2, 1, n_of(seconds)) ** 1.5
    return room(mix((0, rise * shape * 0.6), (0, 0.5 * blips)), 0.3, 0.3)


@sound("bolt", 0.8)
def bolt():
    growl = filt(drive(osc("saw", sweep(110, 60, 0.5)) + osc("saw", sweep(113, 61, 0.5)), 3), "low", 1500)
    growl *= env(0.5, 0.01, 0.2)
    whoosh = blade(0.4, 400, 2200, 0.2)
    sizzle = filt(noise(0.5), "high", 5000) * env(0.5, 0.01, 0.2) * 0.25
    return room(mix((0, 0.6 * growl), (0, whoosh), (0, sizzle)), 0.3, 0.25)


@sound("nova_warn", 0.6)
def nova_warn():
    seconds = 0.9
    t = t_of(seconds)
    pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (5 + 14 * t) * t))
    tone = drive(osc("saw", sweep(70, 280, seconds)), 2) * pulse
    tone = swept_filter(tone, "low", 300, 4000)
    return tone * np.linspace(0.3, 1, n_of(seconds))


@sound("blast", 1.0)
def blast():
    boom = sub_punch(110, 28, 1.2, 0.4, 3)
    roar = drive(filt(noise(1.2), "low", 1200) * env(1.2, 0.002, 0.35), 2.5)
    debris = crush(filt(noise(1.0), "high", 2500) * env(1.0, 0.01, 0.3), 5, 4) * 0.35
    return room(mix((0, 1.2 * boom), (0, roar), (0.04, debris)), 0.6, 0.35)


@sound("zap", 0.8)
def zap():
    seconds = 0.35
    arcs = mix(*[
        (RNG.uniform(0, 0.25), fm(RNG.uniform(900, 3000), RNG.uniform(1.3, 3.7), 6, 0.05, 0.02) * env(0.05, 0.0005, 0.015))
        for _ in range(14)
    ])
    buzz = filt(osc("square", 120, seconds) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 30 * t_of(seconds)))), "band", (200, 3000))
    return room(crush(mix((0, arcs), (0, 0.3 * buzz * env(seconds, 0.002, 0.12))), 6, 2), 0.2, 0.2)


@sound("burn", 0.75)
def burn():
    roar = swept_filter(noise(0.7), "low", 400, 2500) * env(0.7, 0.04, 0.3)
    hiss = filt(noise(0.7), "high", 4000) * env(0.7, 0.01, 0.2) * 0.3
    pops = mix(*[(RNG.uniform(0, 0.6), crack(0.01, 1500, 0.002) * RNG.uniform(0.3, 1)) for _ in range(20)])
    ignite = blade(0.25, 300, 1500, 0.3)
    return mix((0, ignite), (0.05, drive(roar, 1.8)), (0.05, hiss), (0.05, 0.6 * pops))


@sound("freeze", 0.75)
def freeze():
    chimes = mix(*[
        (i * 0.04, fm(f, 3.01, 1.5, 0.8, 0.3) * env(0.8, 0.001, 0.3) * 0.4)
        for i, f in enumerate((2093, 2637, 3136, 4186))
    ])
    crackle = mix(*[(RNG.uniform(0, 0.2), crack(0.006, 4000, 0.0015)) for _ in range(25)])
    frost = filt(noise(0.6), "high", 6000) * env(0.6, 0.05, 0.2) * 0.25
    return room(mix((0, crackle), (0.02, chimes), (0, frost)), 0.5, 0.4)


@sound("corrode", 0.7)
def corrode():
    bubbles = mix(*[
        (RNG.uniform(0, 0.45), fm(sweep(RNG.uniform(300, 600), RNG.uniform(900, 1600), 0.07), 1.5, 2, 0.07) * env(0.07, 0.002, 0.025))
        for _ in range(16)
    ])
    hiss = filt(noise(0.6), "band", (2500, 9000)) * env(0.6, 0.02, 0.25) * 0.45
    return room(mix((0, bubbles), (0, hiss)), 0.25, 0.2)


@sound("heal", 0.65)
def heal():
    notes = (523.3, 659.3, 784.0, 1046.5, 1318.5)
    arp = mix(*[
        (i * 0.06, (osc("tri", f, 0.5) + 0.3 * osc("sine", f * 2.005, 0.5)) * env(0.5, 0.004, 0.2))
        for i, f in enumerate(notes)
    ])
    shimmer = filt(noise(0.8), "high", 7000) * env(0.8, 0.1, 0.3) * 0.15
    return room(mix((0, arp), (0.05, shimmer)), 0.6, 0.45)


@sound("shield", 0.7)
def shield():
    seconds = 0.6
    sweep_up = swept_filter(drive(osc("saw", sweep(80, 320, seconds)) + osc("saw", sweep(81, 324, seconds)), 1.5), "low", 200, 5000)
    hum = osc("sine", 160, seconds) * 0.3
    ping = fm(1318.5, 2, 1.5, 0.5, 0.15) * env(0.5, 0.002, 0.15) * 0.5
    shape = np.minimum(np.linspace(0, 3, n_of(seconds)), 1)
    return room(mix((0, (sweep_up * 0.5 + hum) * shape * env(seconds, 0.05, 0.3, 0.2)), (0.4, ping)), 0.4, 0.3)


@sound("hurt", 0.9)
def hurt():
    thud = sub_punch(120, 45, 0.25, 0.08, 3)
    grit = crush(filt(noise(0.12), "low", 2000) * env(0.12, 0.001, 0.03), 4, 6)
    return mix((0, thud), (0, 0.8 * grit))


@sound("death", 0.9)
def death():
    seconds = 1.2
    shutdown = crush(drive(osc("saw", sweep(600, 40, seconds)), 2) * env(seconds, 0.005, 0.5), 5, 5) * 0.6
    burst = drive(filt(noise(0.4), "high", 800) * env(0.4, 0.001, 0.1), 2)
    sub = sub_punch(140, 30, 0.8, 0.3, 3)
    return room(mix((0, shutdown), (0, burst), (0, sub)), 0.5, 0.35)


@sound("warn", 0.55)
def warn():
    def beep(f):
        return filt(osc("square", f, 0.07), "low", 5000) * env(0.07, 0.002, 0.05, 0.03)

    return mix((0, beep(1480)), (0.09, beep(1975)))


@sound("kill", 0.7)
def kill():
    chord = (220.0, 261.6, 329.6, 440.0, 523.3)
    stab = sum(
        (osc("saw", f, 1.4) + osc("saw", f * 1.006, 1.4)) * 0.2 for f in chord
    )
    stab = swept_filter(stab, "low", 6000, 600) * env(1.4, 0.004, 0.5)
    hit_ = sub_punch(160, 45, 0.4, 0.12, 3)
    return room(mix((0, hit_), (0, stab)), 0.7, 0.4)


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, (fn, peak) in SOUNDS.items():
        # A little headroom: MP3 encoding overshoots peaks slightly.
        x = finish(np.asarray(fn(), dtype=np.float64), peak * 0.88).astype(np.float32)
        rendered[name] = x
        sf.write(os.path.join(OUT, name + ".mp3"), x, SR, format="MP3")
        print(f"{name:12s} {len(x) / SR * 1000:5.0f} ms")
    gap = np.zeros(n_of(0.45), dtype=np.float32)
    preview = np.concatenate([np.concatenate([x, gap]) for x in rendered.values()])
    sf.write(os.path.join(OUT, "_preview_all.mp3"), preview, SR, format="MP3")
    print("order:", ", ".join(rendered))


if __name__ == "__main__":
    sys.exit(main())
