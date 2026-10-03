"""
Generates the Arena battle music: "Neon Arena", a cyberpunk / synthwave loop
(112 BPM, A minor, 32 bars, about 69 seconds) into assets/music/.

    pip install numpy scipy soundfile
    python tools/make_music.py

Four-on-the-floor drums, a sidechain-pumped saw bass, detuned pad chords,
a delayed square arpeggio, a lead line in the second half and a riser into
it. The end flows straight back into the start (reverb and delay tails are
wrapped around), so it loops seamlessly. Upload it with
tools/upload_audio.py (or by hand) and its id goes in
src/client/Modules/Music.luau.
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
BPM = 112
BEAT = 60 / BPM
STEP = BEAT / 4  # a 16th note
BAR = BEAT * 4
BARS = 32
LENGTH = BAR * BARS
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")
RNG = np.random.default_rng(11)

# A minor: i - VI - III - VII, twice through each 16 bars (second half lifts).
CHORDS = [
    ("A", (57, 60, 64)),  # Am
    ("F", (53, 57, 60)),  # F
    ("C", (48, 52, 55)),  # C
    ("G", (55, 59, 62)),  # G
]


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def n_of(seconds):
    return int(round(seconds * SR))


def t_of(seconds):
    return np.arange(n_of(seconds)) / SR


def env(seconds, attack, decay, sustain=0.0, release=None):
    t = t_of(seconds)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    d = sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / decay)
    out = a * d
    if release:
        r = n_of(release)
        if r < len(out):
            out[-r:] *= np.linspace(1, 0, r)
    return out


def saw(freq, seconds, detune=0.0):
    t = t_of(seconds)
    return 2 * ((t * freq * (1 + detune)) % 1.0) - 1


def square(freq, seconds, width=0.5):
    t = t_of(seconds)
    return np.where((t * freq) % 1.0 < width, 1.0, -1.0)


def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, min(0.99, cutoff / (SR / 2)), "low", output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, min(0.99, cutoff / (SR / 2)), "high", output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi):
    sos = signal.butter(2, [lo / (SR / 2), min(0.99, hi / (SR / 2))], "band", output="sos")
    return signal.sosfilt(sos, x)


class Track:
    """A stereo buffer with a tail, for placing notes."""

    def __init__(self, seconds):
        self.L = np.zeros(n_of(seconds))
        self.R = np.zeros(n_of(seconds))

    def add(self, at, x, pan=0.0, gain=1.0):
        i = n_of(at)
        j = min(len(self.L), i + len(x))
        if j <= i:
            return
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.L[i:j] += x[: j - i] * gain * left * 1.414
        self.R[i:j] += x[: j - i] * gain * right * 1.414


TOTAL = LENGTH + BAR * 2  # room for tails, wrapped to the start later


def chord_at(bar):
    return CHORDS[bar % 4]


# Drums -----------------------------------------------------------------------------------

def kick():
    seconds = 0.35
    f = 160 * (42 / 160) ** np.clip(t_of(seconds) / 0.09, 0, 1)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(seconds, 0.001, 0.16)
    click = highpass(RNG.standard_normal(n_of(0.01)), 2000) * env(0.01, 0.0005, 0.003) * 0.4
    body[: len(click)] += click
    return np.tanh(body * 2.2) / np.tanh(2.2)


def clap():
    seconds = 0.35
    n = RNG.standard_normal(n_of(seconds))
    hits = np.zeros(n_of(seconds))
    for k, d in enumerate((0, 0.011, 0.022)):
        e = env(seconds - d, 0.0005, 0.012 if k < 2 else 0.13)
        hits[n_of(d) : n_of(d) + len(e)] += e
    tone = np.sin(2 * np.pi * 190 * t_of(seconds)) * env(seconds, 0.001, 0.05) * 0.4
    return bandpass(n * hits, 900, 6000) + tone


def hat(open_=False):
    seconds = 0.25 if open_ else 0.05
    n = highpass(RNG.standard_normal(n_of(seconds)), 7000)
    return n * env(seconds, 0.0005, 0.09 if open_ else 0.012)


def crash():
    seconds = 2.2
    n = highpass(RNG.standard_normal(n_of(seconds)), 3500)
    return n * env(seconds, 0.001, 0.7) * 0.5


# Instruments -----------------------------------------------------------------------------

def bass_note(note, seconds, cutoff):
    f = midi(note)
    x = saw(f, seconds) + saw(f, seconds, 0.006) + 0.5 * square(f / 2, seconds)
    x = lowpass(x * env(seconds, 0.003, 0.09, 0.35, 0.02), cutoff, 4)
    return np.tanh(x * 1.6)


def pad_chord(notes, seconds, cutoff, detune):
    x = np.zeros(n_of(seconds))
    for n in notes + (notes[0] + 12,):
        f = midi(n)
        for d in (-detune, 0, detune):
            x += saw(f, seconds, d)
    x = lowpass(x, cutoff, 2) * env(seconds, 0.35, 10, 1.0, 0.25) * 0.12
    return x


def arp_note(note, seconds, cutoff):
    f = midi(note)
    x = square(f, seconds, 0.3) * env(seconds, 0.002, 0.07)
    return lowpass(x, cutoff, 2)


def lead_note(note, seconds):
    f = midi(note)
    t = t_of(seconds)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.25, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = (2 * ((ph / (2 * np.pi)) % 1.0) - 1) + 0.6 * np.sin(ph * 2.0)
    x = lowpass(x, 3200, 2) * env(seconds, 0.01, 0.4, 0.6, 0.06)
    return np.tanh(x * 1.3) * 0.5


def delay(L, R, time, feedback=0.4, mix=0.3, ping_pong=True):
    d = n_of(time)
    outL, outR = L.copy(), R.copy()
    echoL, echoR = L.copy(), R.copy()
    for _ in range(6):
        echoL, echoR = np.concatenate([np.zeros(d), echoL[:-d]]), np.concatenate([np.zeros(d), echoR[:-d]])
        if ping_pong:
            echoL, echoR = echoR * feedback, echoL * feedback
        else:
            echoL, echoR = echoL * feedback, echoR * feedback
        outL += lowpass(echoL, 4000) * mix
        outR += lowpass(echoR, 4000) * mix
    return outL, outR


def reverb(L, R, wet=0.18):
    taps = ((0.031, 0.5), (0.047, 0.42), (0.061, 0.36), (0.083, 0.3), (0.113, 0.24), (0.149, 0.18), (0.197, 0.12))
    outL, outR = L.copy(), R.copy()
    for k, (t, g) in enumerate(taps):
        d = n_of(t)
        src = L if k % 2 == 0 else R
        e = lowpass(np.concatenate([np.zeros(d), src[:-d]]), 3000) * g * wet
        if k % 2 == 0:
            outR += e
        else:
            outL += e
    return outL, outR


def pump(length):
    """Sidechain: dips right after every kick, back up by the next beat."""
    t = np.arange(length) / SR
    since = t % BEAT
    return 1 - 0.65 * np.exp(-since / 0.11)


# The song -------------------------------------------------------------------------------

def render():
    drums, bass, pad, arp, lead, fx = (Track(TOTAL) for _ in range(6))
    K, C, H, O = kick(), clap(), hat(), hat(True)
    for bar in range(BARS):
        start = bar * BAR
        intro = bar < 2
        root_name, notes = chord_at(bar)
        lifted = bar >= 16
        # Drums: four on the floor, claps on 2 and 4, 16th hats, open hats on the off-beats.
        for beat in range(4):
            at = start + beat * BEAT
            if not intro or beat == 0:
                drums.add(at, K, 0, 0.75)
            if beat in (1, 3) and not intro:
                drums.add(at, C, 0.05, 0.55)
            if not intro:
                drums.add(at + BEAT / 2, O, 0.25, 0.22)
        for step in range(16):
            accent = 1.0 if step % 4 == 2 else 0.55
            drums.add(start + step * STEP, H, -0.3, 0.24 * accent)
        if bar in (0, 16):
            fx.add(start, crash(), 0.2, 0.7)
        # Bass: pumping 16ths on the root, octave jumps on the off-beats.
        root = notes[0] - 24 if notes[0] - 24 >= 28 else notes[0] - 12
        for step in range(16):
            note = root + (12 if step % 4 == 2 else 0)
            cutoff = 500 + 400 * (step % 4 == 2) + (300 if lifted else 0)
            bass.add(start + step * STEP, bass_note(note, STEP * 0.95, cutoff), 0, 0.32)
        # Pad: the bar's chord, wide.
        cutoff = 1200 + 900 * (bar % 8) / 8 + (600 if lifted else 0)
        chord = pad_chord(notes, BAR, cutoff, 0.007)
        pad.add(start, chord, -0.5, 1.3)
        pad.add(start, pad_chord(notes, BAR, cutoff * 0.9, 0.011), 0.5, 1.3)
        # Arp: from bar 5, chord tones up and down two octaves.
        if bar >= 4:
            tones = [n + 12 for n in notes] + [n + 24 for n in notes]
            order = tones + tones[::-1][1:-1]
            arp_cut = 1500 + 3500 * min(1, (bar - 4) / 12)
            for step in range(16):
                note = order[step % len(order)]
                arp.add(start + step * STEP, arp_note(note, STEP * 0.9, arp_cut), 0.35 if step % 2 else -0.35, 0.4)
        # Lead: a motif over the second half.
        if lifted:
            motif = {
                "A": (69, 72, 76, 74, 72, 71),
                "F": (69, 72, 77, 76, 72, 69),
                "C": (67, 72, 76, 79, 76, 74),
                "G": (71, 74, 79, 78, 74, 71),
            }[root_name]
            rhythm = (0, 3, 6, 8, 11, 14)
            for k, step in enumerate(rhythm):
                length = ((rhythm[k + 1] if k + 1 < len(rhythm) else 16) - step) * STEP
                lead.add(start + step * STEP, lead_note(motif[k], length), 0.1, 0.85)
        # A riser into the second half.
        if bar == 15:
            seconds = BAR
            rise = highpass(RNG.standard_normal(n_of(seconds)), 1500) * np.linspace(0, 1, n_of(seconds)) ** 2
            fx.add(start, rise * 0.25, 0, 1)
    # Mix: sidechain the bass and pad, delay on the arp and lead, a little room on all.
    sc = pump(len(bass.L))
    for tr in (bass, pad):
        tr.L *= sc
        tr.R *= sc
    arp.L, arp.R = delay(arp.L, arp.R, STEP * 3, 0.45, 0.35)
    lead.L, lead.R = delay(lead.L, lead.R, STEP * 3, 0.35, 0.3)
    L = drums.L * 0.9 + bass.L + pad.L + arp.L + lead.L + fx.L
    R = drums.R * 0.9 + bass.R + pad.R + arp.R + lead.R + fx.R
    L, R = reverb(L, R, 0.16)
    # Wrap the tails past the loop point back onto the start: seamless loop.
    cut = n_of(LENGTH)
    L[: len(L) - cut] += L[cut:]
    R[: len(R) - cut] += R[cut:]
    L, R = L[:cut], R[:cut]
    # Master: tame lows, soft clip, normalise to -1 dB.
    L, R = highpass(L, 38), highpass(R, 38)
    peak = max(np.max(np.abs(L)), np.max(np.abs(R)))
    L, R = np.tanh(L / peak * 1.4), np.tanh(R / peak * 1.4)
    peak = max(np.max(np.abs(L)), np.max(np.abs(R)))
    gain = 10 ** (-1 / 20) / peak
    return np.stack([L * gain, R * gain], axis=1).astype(np.float32)


def main():
    os.makedirs(OUT, exist_ok=True)
    audio = render()
    path = os.path.join(OUT, "arena_loop.mp3")
    sf.write(path, audio, SR, format="MP3")
    print(f"arena_loop.mp3  {len(audio) / SR:.1f} s  {os.path.getsize(path) / 1024:.0f} KB")


if __name__ == "__main__":
    sys.exit(main())
