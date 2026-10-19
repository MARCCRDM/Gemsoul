"""The trailer's soundtrack: the game's theme song cut to the edit, and the
game's own sound effects on the hits. Writes audio.wav (48 kHz stereo)."""
import os, subprocess, sys
import numpy as np
import imageio_ffmpeg

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..') + '/'
FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 48000
BAR = 240 / 144.94
BEAT = BAR / 4
FPS = 30
BOUNDS = [round(b * BAR * FPS) for b in [0, 2, 4, 5, 7, 9, 11, 13, 15, 17, 19, 21]]
END = BOUNDS[-1] + 129
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
put(cut(fight, 0, 16 * BAR), 5 * BAR, 0, fade_in=XF)                           # the final drop, 16 bars
tail = cut(sting, BAR, BAR + 4.4)                                              # the drop's first hit again, ringing out
env = np.ones(len(tail)); k0 = int(0.5 * SR); env[k0:] = np.exp(-np.arange(len(tail) - k0) / (SR * 0.9))
put(tail * env[:, None].astype(np.float32), 21 * BAR, -1.0, fade_in=XF, fade_out=0.3)

# Effects (shot start + offset) -----------------------------------------------------------------
S = {name: BOUNDS[i] / FPS for i, name in enumerate(['s1', 's2', 's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10', 's11'])}
S['s12'] = BOUNDS[-1] / FPS
DROP = 5 * BAR
fx = [
    # S1: the sky tears
    ('lottery/attune.mp3', S['s1'] + 0.4, -9, 0.8),
    ('combat/nova_warn.mp3', S['s1'] + 1.6, -10, 0.6),
    # S2: a tear splits open, critters hop through
    ('lottery/seal_break.mp3', S['s2'] + 0.15, -6, 1.0),
    ('combat/zap.mp3', S['s2'] + 0.85, -9, 1.0),
    ('combat/hop_1.mp3', S['s2'] + 1.2, -2, 0.9),
    ('combat/hop_2.mp3', S['s2'] + 1.9, -2, 1.1),
    # S3: Sahur winds up into the drop
    ('combat/heavy_swing_1.mp3', DROP - 0.5, -4, 0.8),
    # S4: the drop
    ('combat/blast.mp3', DROP, -2, 1.0),
    ('combat/guard_break.mp3', DROP, -7, 0.8),
    # S5: three swings, a Legendary
    ('combat/hit_1.mp3', S['s5'] + BEAT, -3, 0.9),
    ('combat/hit_2.mp3', S['s5'] + BEAT * 3, -3, 0.95),
    ('combat/crit_1.mp3', S['s5'] + BEAT * 5, -3, 1.0),
    ('lottery/reveal_5.mp3', S['s5'] + BEAT * 5 + 0.05, -4, 1.0),
    # S6: the tame
    ('combat/cast_frost.mp3', S['s6'] + 0.05, -6, 1.0),
    ('combat/freeze.mp3', S['s6'] + 0.9, -10, 1.0),
    ('combat/roar_razorback.mp3', S['s6'] + BAR, -1, 1.0),
    ('combat/impact_frost.mp3', S['s6'] + BAR, -6, 1.0),
    # S7: the team runs in
    ('combat/roar_bulwark.mp3', S['s7'] + 1.0, -9, 1.1),
    # S8: the fight
    ('combat/impact_fire.mp3', S['s8'] + BEAT, -3, 1.0),
    ('combat/hurt_1.mp3', S['s8'] + BEAT + 0.04, -10, 1.0),
    ('combat/heavy_hit_1.mp3', S['s8'] + BAR, -1, 1.0),
    ('combat/impact_shock.mp3', S['s8'] + BAR, -4, 1.0),
    ('combat/impact_fire.mp3', S['s8'] + BEAT * 5, -4, 1.05),
    ('combat/bolt.mp3', S['s8'] + BEAT * 6 - 0.2, -6, 1.0),
    ('combat/impact_frost.mp3', S['s8'] + BEAT * 6, -4, 1.0),
    # S9: the mech
    ('combat/block_1.mp3', S['s9'] + 0.45, -9, 0.55),
    ('combat/block_2.mp3', S['s9'] + 1.0, -9, 0.55),
    ('combat/block_1.mp3', S['s9'] + 1.5, -10, 0.55),
    ('combat/heavy_swing_2.mp3', S['s9'] + BEAT * 5 - 0.3, -5, 0.7),
    ('combat/heavy_hit_2.mp3', S['s9'] + BEAT * 5, -1, 0.7),
    ('combat/blast.mp3', S['s9'] + BEAT * 5, -5, 0.9),
    # S10: the starter roll
    ('lottery/spin_hum.ogg', S['s10'], -8, 1.0),
    ('lottery/lock.mp3', S['s10'] + BEAT * 3, -3, 1.0),
    ('lottery/reveal_4.mp3', S['s10'] + BEAT * 3, -6, 1.0),
    # S11: the team holds the line
    ('combat/roar_carapace.mp3', S['s11'] + 0.5, -10, 0.95),
    # End: the logo
    ('combat/blast.mp3', S['s12'], -3, 0.85),
    ('lottery/reveal_5.mp3', S['s12'] + 0.05, -6, 1.0),
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
