"""
Generates the wild kaiju's roars into assets/sounds/combat/ (one per kind),
with the same building blocks as tools/make_combat_sounds.py:

    roar_bulwark.mp3     a deep, chesty bellow that swells and falls
    roar_razorback.mp3   a raspy, rattling snarl, higher and quicker
    roar_carapace.mp3    a low rumble under a rising hiss, clicking
    roar_scythe.mp3      a thin chittering screech, mandibles clicking fast

    pip install numpy scipy soundfile
    python tools/make_kaiju_sounds.py [roar_scythe ...]   (default: all)

Upload them like the combat set (tools/upload_audio.py fills in the
RoarBulwark, RoarRazorback, RoarCarapace and RoarScythe ids in
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

RNG = np.random.default_rng(11)


def contour(seconds, points):
    """A pitch track through (time share, Hz) points."""
    t = np.linspace(0, 1, n_of(seconds))
    xs, ys = zip(*points)
    return np.interp(t, xs, ys)


def swell(seconds, attack, release):
    """Up over `attack` seconds, held, down over the last `release`."""
    t = t_of(seconds)
    up = np.clip(t / attack, 0, 1) ** 1.5
    down = np.clip((seconds - t) / release, 0, 1) ** 1.2
    return up * down


def voice(f0, seconds, rasp=0.0, breath=0.2):
    """A throat: a buzzing source (two detuned saws), a rattle of `rasp`
    (vocal fry, amplitude wobbling at 28-40 Hz), and breath noise."""
    jitter = 1 + 0.012 * filt(RNG.standard_normal(len(f0)), "low", 8)
    buzz = osc("saw", f0 * jitter) + 0.7 * osc("saw", f0 * 1.013 * jitter) + 0.35 * osc("square", f0 * 0.5)
    if rasp > 0:
        rattle = 0.5 + 0.5 * np.sin(phase(np.full(len(f0), 34.0) + 6 * filt(RNG.standard_normal(len(f0)), "low", 4)))
        buzz *= (1 - rasp) + rasp * rattle
    air = filt(noise(seconds), "band", (300, 4500)) * breath
    return buzz + air


def formants(x, peaks):
    """A mouth: band passes at (low, high, gain) resonances."""
    return sum(filt(x, "band", (lo, hi)) * gain for lo, hi, gain in peaks)


def roar_bulwark():
    secs = 1.6
    f0 = contour(secs, [(0, 62), (0.18, 96), (0.45, 104), (0.8, 78), (1, 52)])
    throat = voice(f0, secs, rasp=0.25, breath=0.25)
    mouth = formants(throat, [(260, 520, 1.0), (620, 1100, 0.7), (1700, 2600, 0.2)])
    body = drive(mouth * 1.4, 2.2) * swell(secs, 0.18, 0.55)
    chest = osc("sine", f0 * 0.5) * swell(secs, 0.25, 0.6) * 0.6
    return room(mix((0, body), (0, chest)), 0.55, 0.35)


def roar_razorback():
    secs = 1.05
    f0 = contour(secs, [(0, 150), (0.12, 250), (0.4, 270), (0.75, 210), (1, 140)])
    throat = voice(f0, secs, rasp=0.65, breath=0.2)
    mouth = formants(throat, [(500, 1100, 1.0), (1200, 2200, 0.6), (2800, 3800, 0.12)])
    snarl = filt(drive(mouth * 1.8, 3.0), "low", 4000) * swell(secs, 0.06, 0.35)
    hiss = filt(noise(secs), "band", (3000, 6000)) * swell(secs, 0.05, 0.3) * 0.04
    return room(mix((0, snarl), (0, hiss)), 0.35, 0.25)


def roar_carapace():
    secs = 1.35
    f0 = contour(secs, [(0, 46), (0.3, 58), (0.7, 54), (1, 40)])
    rumble = drive(formants(voice(f0, secs, rasp=0.4, breath=0.1), [(80, 260, 1.0), (300, 600, 0.5)]) * 1.6, 2.5)
    rumble = filt(rumble, "low", 1200) * swell(secs, 0.3, 0.5)
    hiss = filt(noise(secs), "band", (2500, 6000)) * swell(secs, 0.5, 0.35) * 0.12
    clicks = np.zeros(n_of(secs))
    for start in np.sort(RNG.uniform(0.15, secs - 0.2, 7)):
        i = n_of(start)
        tick = filt(noise(0.012), "high", 1800) * np.exp(-t_of(0.012) / 0.003)
        clicks[i : i + len(tick)] += tick * 0.3
    return room(mix((0, rumble), (0, hiss), (0, clicks)), 0.45, 0.3)


def roar_scythe():
    secs = 0.95
    f0 = contour(secs, [(0, 380), (0.1, 620), (0.35, 700), (0.7, 560), (1, 420)])
    throat = voice(f0, secs, rasp=0.85, breath=0.15)
    mouth = formants(throat, [(900, 1900, 1.0), (2200, 3600, 0.5), (4200, 6000, 0.12)])
    screech = filt(drive(mouth * 1.6, 2.6), "low", 7000) * swell(secs, 0.04, 0.3)
    clicks = np.zeros(n_of(secs))
    starts = np.arange(0.03, secs - 0.05, 0.045)
    for start in starts + RNG.uniform(-0.008, 0.008, len(starts)):
        i = n_of(start)
        tick = filt(noise(0.008), "high", 2500) * np.exp(-t_of(0.008) / 0.002)
        clicks[i : i + len(tick)] += tick * 0.22
    return room(mix((0, screech * 0.8), (0, clicks)), 0.3, 0.2)


ROARS = {
    "roar_bulwark": (roar_bulwark, 0.8),
    "roar_razorback": (roar_razorback, 0.78),
    "roar_carapace": (roar_carapace, 0.8),
    "roar_scythe": (roar_scythe, 0.76),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    wanted = set(sys.argv[1:]) or set(ROARS)
    for name, (fn, peak) in ROARS.items():
        if name not in wanted:
            continue
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
