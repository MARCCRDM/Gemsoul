"""
Cuts the game's theme song into seamless music loops in assets/music/.

    pip install numpy scipy imageio-ffmpeg
    python tools/cut_song.py path/to/song.m4a

The song runs at about 145 BPM and moves in 16-bar phrases (about 26.5 s).
Each loop is one phrase, cut exactly on the bar lines, and its last moment
crossfades into the music that follows the phrase, so the end runs straight
back into the start with no gap. Every loop is levelled to the same
loudness, then encoded as .ogg (Roblox loops Ogg Vorbis without the small
gap MP3 leaves).

  menu_theme     the breakdown (bars 41-57): menus and the dashboard
  outpost_theme  the first verse (bars 9-25): exploring the Outpost
  dungeon_theme  the second drop (bars 65-81): squad dungeons
  fight_theme    the final drop (bars 81-97): Arena fights, duels and raids

Bars count from the first downbeat (BAR0 seconds in). Change PIECES to pick
other phrases. Upload the results with tools/upload_audio.py; their ids go
in src/client/Modules/Music.luau.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
import scipy.io.wavfile as wavfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "music")
BPM = 144.94
BAR0 = 0.711  # seconds to the first downbeat
BAR = 4 * 60 / BPM
SEAM = 0.12  # seconds of crossfade where each loop wraps around
LOUDNESS_DB = -16  # RMS level every loop is set to
PIECES = {
    "menu_theme": (41, 57),
    "outpost_theme": (9, 25),
    "dungeon_theme": (65, 81),
    "fight_theme": (81, 97),
}


def ffmpeg() -> str:
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: python tools/cut_song.py path/to/song")
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "song.wav")
        subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", sys.argv[1], "-ac", "2", "-ar", "44100", wav], check=True)
        rate, data = wavfile.read(wav)
        audio = data.astype(np.float32) / 32768
        seam = int(SEAM * rate)
        for name, (first, last) in PIECES.items():
            start = int(round((BAR0 + first * BAR) * rate))
            end = int(round((BAR0 + last * BAR) * rate))
            length = end - start
            piece = audio[start : end + seam]
            if len(piece) < length + seam:
                raise SystemExit(f"{name}: the song ends before bar {last}")
            loop = piece[:length].copy()
            fade = np.linspace(0, 1, seam)[:, None]
            # What follows the phrase fades into its start, so the wrap is seamless.
            loop[:seam] = piece[length : length + seam] * (1 - fade) + piece[:seam] * fade
            gain = 10 ** (LOUDNESS_DB / 20) / np.sqrt((loop**2).mean())
            gain = min(gain, 0.89 / (np.abs(loop).max() + 1e-9))
            loop *= gain
            out_wav = os.path.join(tmp, name + ".wav")
            wavfile.write(out_wav, rate, (loop * 32767).astype(np.int16))
            path = os.path.join(OUT, name + ".ogg")
            subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", out_wav, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
            print(f"{name}.ogg  bars {first}-{last}  {length / rate:.1f} s  {os.path.getsize(path) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
