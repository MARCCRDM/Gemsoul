"""
Generates the UI sound effects for Brainrot Crusaders into assets/sounds/.

    pip install numpy soundfile
    python tools/make_sounds.py

Every sound is synthesised (no samples), short, and quiet enough to sit under
the game. Roblox plays uploaded audio only: upload the .mp3 files in
Creator Hub (Audio), then paste each id into src/client/Modules/UiSound.luau.
Edit the recipes below and run again to change a sound.
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def ts(seconds):
    return np.arange(int(SR * seconds)) / SR


def decay(n, tau, attack=0.002):
    t = np.arange(n) / SR
    return (1 - np.exp(-t / attack)) * np.exp(-t / tau)


def tone(freq, seconds, tau, harmonics=((1, 1.0),), glide_to=None, vibrato=0.0):
    """A pitched tone with an exponential decay. `harmonics` = (ratio, level)."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    f = np.full(n, float(freq))
    if glide_to is not None:
        f = freq * (glide_to / freq) ** (t / seconds)
    if vibrato:
        f = f * (1 + 0.012 * np.sin(2 * np.pi * vibrato * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros(n)
    for ratio, level in harmonics:
        out += level * np.sin(phase * ratio)
    return out * decay(n, tau)


def bell(freq, seconds, tau):
    """A bright, glassy ping: inharmonic partials that die at different speeds."""
    out = np.zeros(int(SR * seconds))
    for ratio, level, speed in ((1, 1.0, 1.0), (2.0, 0.45, 1.6), (3.01, 0.22, 2.4), (4.2, 0.1, 3.2)):
        out += level * tone(freq * ratio, seconds, tau / speed)
    return out


def noise(seconds, tau, lowpass=None, highpass=None, seed=1):
    rng = np.random.default_rng(seed)
    n = int(SR * seconds)
    x = rng.standard_normal(n)
    if lowpass:
        a = 1 - np.exp(-2 * np.pi * lowpass / SR)
        y = np.zeros(n)
        for i in range(1, n):
            y[i] = y[i - 1] + a * (x[i] - y[i - 1])
        x = y
    if highpass:
        a = 1 - np.exp(-2 * np.pi * highpass / SR)
        y = np.zeros(n)
        for i in range(1, n):
            y[i] = y[i - 1] + a * (x[i] - y[i - 1])
        x = x - y
    return x * decay(n, tau, 0.0008)


def place(parts, total):
    """Mix (start_seconds, samples) parts into one buffer of `total` seconds."""
    out = np.zeros(int(SR * total))
    for start, samples in parts:
        i = int(SR * start)
        j = min(len(out), i + len(samples))
        out[i:j] += samples[: j - i]
    return out


def reverb(x, amount=0.25, tail=0.18):
    """A small, soft room: a few decaying, darkened echoes."""
    out = np.concatenate([x, np.zeros(int(SR * (tail + 0.08)))])
    for delay, gain in ((0.021, 0.5), (0.037, 0.36), (0.053, 0.25), (0.079, 0.16)):
        d = int(SR * delay)
        echo = np.zeros_like(out)
        echo[d : d + len(x)] = x * gain * amount * 2
        # darken the echo a little
        a = 0.35
        for i in range(1, len(echo)):
            echo[i] = echo[i - 1] + a * (echo[i] - echo[i - 1])
        out += echo
    return out


def finish(x, peak):
    x = x - np.mean(x)
    fade_in, fade_out = int(SR * 0.002), int(SR * 0.012)
    x[:fade_in] *= np.linspace(0, 1, fade_in)
    x[-fade_out:] *= np.linspace(1, 0, fade_out)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


# The sounds -----------------------------------------------------------------------------

SOUNDS = {}


def sound(name, peak=0.6):
    def wrap(fn):
        SOUNDS[name] = (fn, peak)
        return fn

    return wrap


@sound("hover", 0.22)
def hover():
    # a tiny, airy tick: two quick high partials
    return place([(0, tone(2400, 0.05, 0.012)), (0.0, 0.5 * tone(3600, 0.05, 0.008))], 0.06)


@sound("click", 0.55)
def click():
    # a soft, solid press: a short thud, a snap of noise and a small high blip
    thud = tone(260, 0.09, 0.025, glide_to=140)
    snap = noise(0.02, 0.004, highpass=2500, seed=3)
    blip = 0.5 * tone(1500, 0.06, 0.012)
    return reverb(place([(0, thud), (0, 0.8 * snap), (0.004, blip)], 0.1), 0.1, 0.05)


@sound("tab", 0.4)
def tab():
    return reverb(place([(0, tone(980, 0.06, 0.014)), (0.0, 0.5 * tone(1470, 0.06, 0.01))], 0.07), 0.1, 0.04)


@sound("confirm", 0.6)
def confirm():
    return reverb(place([(0, bell(659.3, 0.35, 0.12)), (0.07, bell(987.8, 0.45, 0.18))], 0.55), 0.3, 0.2)


@sound("back", 0.45)
def back():
    return reverb(place([(0, tone(620, 0.12, 0.04, glide_to=330)), (0, 0.4 * tone(1240, 0.12, 0.025, glide_to=660))], 0.13), 0.12, 0.06)


@sound("open", 0.5)
def open_():
    sweep = tone(220, 0.28, 0.2, harmonics=((1, 1.0), (2, 0.35)), glide_to=880)
    shimmer = noise(0.3, 0.12, highpass=3000, seed=5) * np.linspace(0.2, 0.7, int(SR * 0.3))
    ping = bell(1318.5, 0.3, 0.1)
    return reverb(place([(0, sweep), (0, 0.18 * shimmer), (0.2, 0.7 * ping)], 0.5), 0.3, 0.2)


@sound("close", 0.4)
def close():
    sweep = tone(900, 0.18, 0.1, harmonics=((1, 1.0), (2, 0.3)), glide_to=260)
    return reverb(place([(0, sweep), (0, 0.4 * noise(0.1, 0.03, highpass=2500, seed=6))], 0.2), 0.2, 0.08)


@sound("notify", 0.5)
def notify():
    return reverb(place([(0, bell(880, 0.5, 0.18)), (0.0, 0.3 * tone(1760, 0.3, 0.08))], 0.5), 0.3, 0.2)


@sound("error", 0.55)
def error():
    def buzz(f):
        saw = sum(np.sin(2 * np.pi * f * k * ts(0.14)) / k for k in range(1, 7))
        return saw * decay(len(saw), 0.07)

    x = place([(0, buzz(150)), (0.11, 0.9 * buzz(118))], 0.28)
    a = 0.22
    for i in range(1, len(x)):
        x[i] = x[i - 1] + a * (x[i] - x[i - 1])
    return reverb(x, 0.1, 0.06)


@sound("coin", 0.55)
def coin():
    return reverb(
        place([(0, bell(1568, 0.22, 0.07)), (0.065, bell(2093, 0.45, 0.16)), (0.065, 0.2 * tone(4186, 0.25, 0.05))], 0.5),
        0.25,
        0.15,
    )


@sound("reward", 0.65)
def reward():
    notes = (523.3, 659.3, 784.0, 1046.5, 1318.5)
    parts = [(i * 0.085, bell(f, 0.7, 0.28)) for i, f in enumerate(notes)]
    parts.append((0.3, 0.12 * noise(0.7, 0.3, highpass=4500, seed=8)))
    return reverb(place(parts, 1.1), 0.4, 0.4)


@sound("craft", 0.65)
def craft():
    # a metal strike, then a bright chime
    strike = noise(0.04, 0.008, lowpass=6000, seed=2)
    metal = sum(tone(f, 0.3, 0.09 / s) * l for f, l, s in ((520, 1.0, 1.0), (1330, 0.6, 1.5), (2140, 0.4, 2.2), (3010, 0.25, 3.0)))
    chime = bell(659.3, 0.4, 0.15) + 0.8 * bell(987.8, 0.4, 0.15)
    return reverb(place([(0, 0.9 * strike), (0, 0.8 * metal), (0.13, 0.7 * chime)], 0.6), 0.3, 0.25)


@sound("enchant", 0.6)
def enchant():
    rise = tone(420, 0.5, 0.3, harmonics=((1, 1.0), (2, 0.4), (3, 0.15)), glide_to=1680, vibrato=7)
    spark = noise(0.6, 0.25, highpass=4000, seed=9) * np.linspace(0.3, 1.0, int(SR * 0.6))
    top = bell(2093, 0.6, 0.25) + 0.6 * bell(3136, 0.6, 0.2)
    return reverb(place([(0, 0.7 * rise), (0, 0.16 * spark), (0.4, 0.55 * top)], 1.0), 0.45, 0.35)


@sound("equip", 0.5)
def equip():
    def clank(f):
        return place([(0, noise(0.03, 0.006, lowpass=5000, seed=4) * 0.8), (0, tone(f, 0.12, 0.03) * 0.6)], 0.12)

    return reverb(place([(0, clank(700)), (0.07, clank(1100))], 0.22), 0.15, 0.1)


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, (fn, peak) in SOUNDS.items():
        x = finish(fn().astype(np.float64), peak).astype(np.float32)
        rendered[name] = x
        sf.write(os.path.join(OUT, name + ".mp3"), x, SR, format="MP3")
        print(f"{name:8s} {len(x) / SR * 1000:5.0f} ms  peak {np.max(np.abs(x)):.2f}")
    # One file with every sound in turn, to listen to them all.
    gap = np.zeros(int(SR * 0.45), dtype=np.float32)
    preview = np.concatenate([np.concatenate([x, gap]) for x in rendered.values()])
    sf.write(os.path.join(OUT, "_preview_all.mp3"), preview, SR, format="MP3")
    print("order:", ", ".join(rendered))


if __name__ == "__main__":
    sys.exit(main())
