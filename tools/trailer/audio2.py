"""The trailer's soundtrack: the game's theme song cut to the edit, and the
game's own sound effects on the hits. Writes audio.wav (48 kHz stereo)."""
import subprocess, sys
import numpy as np
import imageio_ffmpeg

ROOT = '/home/user/gemsoul/'
FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 48000
BAR = 240 / 144.94
BEAT = BAR / 4
FPS = 30
BOUNDS = [round(b * BAR * FPS) for b in [0, 2, 4, 5, 7, 9, 11, 15, 17.6]]
END = BOUNDS[-1]
LENGTH = END / FPS + 0.2


def load(path, rate=1.0):
    raw = subprocess.run([FF, '-v', 'quiet', '-i', ROOT + path, '-f', 'f32le', '-ac', '2', '-ar', str(int(SR / rate)), '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


out = np.zeros((int(LENGTH * SR), 2), np.float32)


def put(x, at, gain_db=0.0, fade_in=0.0, fade_out=0.0):
    x = x.copy() * (10 ** (gain_db / 20))
    n = len(x)
    if fade_in > 0:
        k = min(n, int(fade_in * SR)); x[:k] *= np.linspace(0, 1, k)[:, None]
    if fade_out > 0:
        k = min(n, int(fade_out * SR)); x[n - k:] *= np.linspace(1, 0, k)[:, None]
    i = int(round(at * SR))
    if i < 0:
        x = x[-i:]; i = 0
    j = min(len(out), i + len(x))
    out[i:j] += x[:j - i]


def cut(x, a, b):
    return x[int(round(a * SR)):int(round(b * SR))]


# Music -----------------------------------------------------------------------------------------
menu, sting, fight = load('assets/music/menu_theme.ogg'), load('assets/music/intro_sting.ogg'), load('assets/music/fight_theme.ogg')
XF = 0.04
put(cut(menu, 0, 4 * BAR + XF), 0, -1.5, fade_in=1.2, fade_out=XF)            # the breakdown: the rift opens
put(cut(sting, 0, BAR + XF), 4 * BAR, 0, fade_in=XF, fade_out=XF)              # the lead-in bar to the drop
put(cut(fight, 0, 10 * BAR), 5 * BAR, 0, fade_in=XF)                           # the final drop, 16 bars
tail = cut(sting, BAR, BAR + 4.4)                                              # the drop's first hit again, ringing out
env = np.ones(len(tail)); k0 = int(0.5 * SR); env[k0:] = np.exp(-np.arange(len(tail) - k0) / (SR * 0.9))
put(tail * env[:, None].astype(np.float32), 15 * BAR, -1.0, fade_in=XF, fade_out=0.3)

# Effects (shot start + offset) -----------------------------------------------------------------
DROP = 5 * BAR
fx = [
    ('lottery/attune.mp3', 0.4, -9, 0.8),
    ('lottery/seal_break.mp3', 2*BAR + 0.85, -4, 0.9),
    ('combat/nova_warn.mp3', 4*BAR, -8, 0.7),
    ('combat/heavy_swing_1.mp3', DROP - 0.5, -4, 0.8),
    ('combat/blast.mp3', DROP, -2, 1.0),
    ('combat/crit_2.mp3', DROP + BAR, -5, 1.0),
    ('combat/hit_1.mp3', 7*BAR, -2, 0.9), ('combat/hit_2.mp3', 7*BAR + BEAT*2, -3, 0.95),
    ('combat/hit_3.mp3', 8*BAR, -3, 0.9), ('combat/crit_1.mp3', 8*BAR + BEAT*2, -3, 1.0),
    ('combat/blast.mp3', 9*BAR, -3, 0.8), ('combat/heavy_hit_1.mp3', 10*BAR, -1, 0.8),
    ('lottery/spin_hum.ogg', 11*BAR, -6, 1.0), ('lottery/spin_hum.ogg', 11*BAR + 2.0, -6, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.00, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.09, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.18, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.27, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.36, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.45, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.54, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.63, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.72, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.81, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.90, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 0.99, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.08, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.17, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.26, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.35, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.44, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.53, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.62, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.71, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.80, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.89, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 1.98, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.07, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.16, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.25, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.34, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.43, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.52, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.61, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.70, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.79, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.88, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 2.97, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 3.06, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 3.15, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 3.24, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 3.33, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 3.42, -10, 1.0),
    ('lottery/tick.mp3', 11*BAR + 3.51, -10, 1.0),
    ('lottery/lock.mp3', 11*BAR + BEAT*8, -5, 1.0), ('lottery/lock.mp3', 11*BAR + BEAT*9, -5, 1.0),
    ('lottery/lock.mp3', 11*BAR + BEAT*10, -5, 1.0), ('lottery/lock.mp3', 11*BAR + BEAT*11, -5, 1.0),
    ('lottery/reveal_5.mp3', 11*BAR + BEAT*12, -2, 1.0), ('combat/blast.mp3', 11*BAR + BEAT*12, -6, 1.1),
    ('combat/blast.mp3', 15*BAR, -3, 0.85),
]
for path, at, gain, rate in fx:
    put(load('assets/sounds/' + path, rate), at, gain)

# Master: gentle limiter, peak at -1 dBFS ---------------------------------------------------------
peak = float(np.abs(out).max())
drive = 1.4
mastered = np.tanh(out * drive / max(peak, 1e-6)) / np.tanh(drive)
mastered *= 10 ** (-1 / 20)
pcm = (np.clip(mastered, -1, 1) * 32767).astype(np.int16)
import wave
with wave.open(sys.argv[1] if len(sys.argv) > 1 else 'audio.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
rms = float(np.sqrt(np.mean(mastered ** 2)))
print(f'{len(out) / SR:.2f}s  rms {20 * np.log10(rms):.1f} dBFS  (input peak {peak:.2f})')
