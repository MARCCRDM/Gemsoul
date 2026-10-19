"""Trailer 3 soundtrack: theme song cut to the edit, game SFX, and the narration
(Kokoro TTS voice am_onyx, pitched down with bass and a short reverb)."""
import subprocess, sys
import numpy as np
import imageio_ffmpeg

ROOT = '/home/user/gemsoul/'
TTS = '/tmp/claude-0/tts/'
FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 48000
BAR = 240 / 144.94
BEAT = BAR / 4
LENGTH = round(19.6 * BAR * 30) / 30 + 0.2


def ff(path, af=None, rate=1.0):
    cmd = [FF, '-v', 'quiet', '-i', path] + (['-af', af] if af else []) + ['-f', 'f32le', '-ac', '2', '-ar', str(int(SR / rate)), '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def load(p, rate=1.0): return ff(ROOT + p, rate=rate)


out = np.zeros((int(LENGTH * SR), 2), np.float32)
vox = np.zeros_like(out)


def put(x, at, gain_db=0.0, fade_in=0.0, fade_out=0.0, buf=None):
    buf = out if buf is None else buf
    x = x.copy() * (10 ** (gain_db / 20)); n = len(x)
    if fade_in > 0: k = min(n, int(fade_in * SR)); x[:k] *= np.linspace(0, 1, k)[:, None]
    if fade_out > 0: k = min(n, int(fade_out * SR)); x[n - k:] *= np.linspace(1, 0, k)[:, None]
    i = int(round(at * SR))
    if i < 0: x = x[-i:]; i = 0
    j = min(len(buf), i + len(x)); buf[i:j] += x[:j - i]


def cut(x, a, b): return x[int(round(a * SR)):int(round(b * SR))]


# Music
menu, sting, fight = load('assets/music/menu_theme.ogg'), load('assets/music/intro_sting.ogg'), load('assets/music/fight_theme.ogg')
XF = 0.04
put(cut(menu, 0, 6 * BAR + XF), 0, -3, fade_in=1.5, fade_out=XF)
put(cut(sting, 0, BAR + XF), 6 * BAR, -1, fade_in=XF, fade_out=XF)
put(cut(fight, 0, 6 * BAR + 0.6), 7 * BAR, -1, fade_in=XF, fade_out=0.6)
# Face-off: a low drone that swells, then the lead-in bar and the drop on the logo.
t = np.arange(int(4 * BAR * SR)) / SR
sw = np.clip(t / (4 * BAR), 0, 1) ** 1.5
drone = (0.5 * np.sin(2 * np.pi * 41.2 * t) + 0.3 * np.sin(2 * np.pi * 61.7 * t + 0.4) + 0.15 * np.sin(2 * np.pi * 82.4 * t)) * (0.35 + 0.65 * sw)
noise = np.convolve(np.random.default_rng(3).standard_normal(len(t)), np.ones(400) / 400, 'same') * 2.5 * sw
put(np.stack([drone + noise, drone - noise], 1).astype(np.float32) * 0.35, 13 * BAR, 0, fade_in=0.3, fade_out=0.2)
put(cut(sting, 0, BAR + XF), 16 * BAR, -2, fade_in=0.3, fade_out=XF)
tail = cut(sting, BAR, BAR + 4.4)
env = np.ones(len(tail)); k0 = int(0.5 * SR); env[k0:] = np.exp(-np.arange(len(tail) - k0) / (SR * 0.9))
put(tail * env[:, None].astype(np.float32), 17 * BAR, 0, fade_in=XF, fade_out=0.3)

# Effects
fx = [('lottery/seal_break.mp3', 3 * BAR + 0.3, -4, 0.8), ('combat/nova_warn.mp3', 0.2, -12, 0.6),
      ('combat/roar_razorback.mp3', 3 * BAR + 0.6, -8, 0.8)]
for b in range(7):  # the duel: a clash every beat
    fx.append((['combat/hit_1.mp3', 'combat/hit_2.mp3', 'combat/parry.mp3', 'combat/hit_3.mp3'][b % 4], 7 * BAR + (b + 1) * BEAT, -5, 1.0))
fx += [('combat/crit_1.mp3', 8 * BAR + BEAT * 2, -4, 1.0)]
for b in range(4):  # mining
    fx.append(('combat/heavy_hit_1.mp3', 9 * BAR + b * BAR / 2 + 0.1, -7, 1.2))
fx += [('combat/blast.mp3', 11 * BAR, -3, 0.8), ('combat/heavy_hit_2.mp3', 12 * BAR, -3, 0.8), ('combat/crit_2.mp3', 12 * BAR + BEAT * 2, -4, 1.0)]
for s in [0.5, 1.4, 2.3, 3.2, 4.0]:  # Tung Tung's footsteps
    fx.append(('combat/heavy_hit_2.mp3', 13 * BAR + s, -5, 0.45))
for h in [1.1, 3.6]:  # thunder
    fx.append(('combat/blast.mp3', 13 * BAR + h, -6, 0.35))
fx.append(('combat/heavy_swing_1.mp3', 17 * BAR - 0.4, -5, 0.7))
for p, at, g, r in fx: put(load('assets/sounds/' + p, r), at, g, fade_out=0.05)

# Narration
AF = 'asetrate=24000*0.8909,aresample=24000,atempo=1.1225,bass=g=6:f=110,highpass=f=60,acompressor=threshold=0.1:ratio=4:makeup=2,aecho=0.8:0.5:70|140:0.22|0.12'
lines = [0.6, 3 * BAR + 0.2, 5 * BAR + 0.2, 7 * BAR + 0.1, 9 * BAR, 11 * BAR]
for n, at in enumerate(lines):
    v = ff(TTS + f'am_onyx_{n}.wav', AF)
    v /= max(1e-6, np.abs(v).max()); put(v, at, -2.5, fade_out=0.15, buf=vox)
# Duck the music under the voice.
lvl = np.convolve(np.abs(vox[:, 0]), np.ones(2400) / 2400, 'same')
duck = 1 - 0.45 * np.clip(lvl / 0.05, 0, 1)
duck = np.convolve(duck, np.ones(4800) / 4800, 'same')
mix = out * duck[:, None] + vox
mix /= max(1.0, np.abs(mix).max() / 0.95)
mix = np.clip(mix, -1, 1)
pcm = (mix * 32767).astype('<i2').tobytes()
subprocess.run([FF, '-v', 'error', '-y', '-f', 's16le', '-ac', '2', '-ar', str(SR), '-i', '-', sys.argv[1]], input=pcm, check=True)
print('wrote', sys.argv[1], len(mix) / SR)
