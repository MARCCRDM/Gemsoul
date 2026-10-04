"""
Builds the splash intro: the animated SAGA MINERS logo set to the best part
of the theme song (the build into its final drop).

    pip install numpy scipy pillow imageio-ffmpeg
    python tools/make_intro.py path/to/song.m4a path/to/logo.mp4

Writes:
  assets/video/saga_intro.mp4   1920x1080, 30 fps, with the music: a shareable
                                trailer/preview. (The game doesn't need it: the
                                title screen draws the logo itself, from
                                tools/make_splash_art.py.)
  assets/music/intro_sting.ogg  the music alone, for the fallback splash
                                (tools/upload_audio.py fills Music.Ids.Intro)

The timeline, about ten seconds (six bars at 145 BPM):
  bar 1     the logo fades up out of the dark as the build rises
  bar 2     the drop hits: a white flash and the logo's shine starts
  bars 2-6  the logo animation loops (pixels kept sharp)
  last 0.5s the logo settles, clean, and holds: the title screen pauses the
            video on that frame while the song carries on from bar 86
            (fight_theme.ogg from 5 bars in) under "CLICK TO ENTER"
The logo's square clip sits in the middle of a 16:9 frame, its edges
feathered into the background colour so the join doesn't show.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
import scipy.io.wavfile as wavfile
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BPM = 144.94
BAR0 = 0.711  # seconds to the song's first downbeat
BAR = 4 * 60 / BPM
FIRST_BAR = 80  # one bar of build, then the final drop at bar 81
BARS = 6
WIDTH, HEIGHT, FPS = 1920, 1080, 30
BACKGROUND = np.array([10, 8, 25], np.float32)  # the clip's own deep-space colour
FEATHER = 170  # pixels of blend at the square's left and right edges
HOLD = 0.5  # seconds of the clean logo at the end, for the title screen to hold


def ffmpeg() -> str:
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


def run(*args):
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", *args], check=True)


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def music(song: str, tmp: str) -> tuple[str, float]:
    wav = os.path.join(tmp, "song.wav")
    run("-i", song, "-ac", "2", "-ar", "44100", wav)
    rate, data = wavfile.read(wav)
    audio = data.astype(np.float32) / 32768
    start = int(round((BAR0 + FIRST_BAR * BAR) * rate))
    length = int(round(BARS * BAR * rate))
    clip = audio[start : start + length].copy()
    t = np.arange(length) / rate
    # No fade-out: the title screen's loop picks the song up right where this ends.
    envelope = np.clip(t / 0.15, 0, 1) * np.clip((length / rate - t) / 0.01, 0, 1)
    clip *= envelope[:, None]
    loud = clip[int(BAR * rate) :]
    gain = 10 ** (-14 / 20) / np.sqrt((loud**2).mean())
    gain = min(gain, 0.9 / (np.abs(clip).max() + 1e-9))
    clip *= gain
    out = os.path.join(tmp, "intro.wav")
    wavfile.write(out, rate, (clip * 32767).astype(np.int16))
    return out, length / rate


def frames(logo: str, tmp: str) -> tuple[list[np.ndarray], float]:
    folder = os.path.join(tmp, "logo")
    os.makedirs(folder)
    run("-i", logo, os.path.join(folder, "%04d.png"))
    names = sorted(os.listdir(folder))
    side = HEIGHT
    images = []
    for name in names:
        image = Image.open(os.path.join(folder, name)).convert("RGB").resize((side, side), Image.NEAREST)
        images.append(np.asarray(image, np.float32))
    probe = subprocess.run([ffmpeg(), "-i", logo], capture_output=True, text=True).stderr
    fps = 14.29
    for part in probe.split(","):
        if part.strip().endswith(" fps"):
            fps = float(part.strip().split()[0])
    return images, fps


def compose(square: np.ndarray, brightness: float, flash: float) -> np.ndarray:
    frame = np.empty((HEIGHT, WIDTH, 3), np.float32)
    frame[:] = BACKGROUND
    left = (WIDTH - HEIGHT) // 2
    frame[:, left : left + HEIGHT] = square
    # Feather the square's sides into the background.
    ramp = np.linspace(0, 1, FEATHER, dtype=np.float32)[None, :, None]
    frame[:, left : left + FEATHER] = BACKGROUND * (1 - ramp) + frame[:, left : left + FEATHER] * ramp
    right = left + HEIGHT
    frame[:, right - FEATHER : right] = frame[:, right - FEATHER : right] * ramp[:, ::-1] + BACKGROUND * (1 - ramp[:, ::-1])
    frame = BACKGROUND + (frame - BACKGROUND) * brightness
    if flash > 0:
        frame = frame * (1 - flash) + 255 * flash
    return np.clip(frame, 0, 255).astype(np.uint8)


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: python tools/make_intro.py path/to/song path/to/logo.mp4")
    song, logo = sys.argv[1], sys.argv[2]
    video_dir = os.path.join(ROOT, "assets", "video")
    music_dir = os.path.join(ROOT, "assets", "music")
    os.makedirs(video_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav, duration = music(song, tmp)
        run("-i", wav, "-c:a", "libvorbis", "-q:a", "6", os.path.join(music_dir, "intro_sting.ogg"))
        images, fps = frames(logo, tmp)
        clip_length = len(images) / fps
        out_dir = os.path.join(tmp, "out")
        os.makedirs(out_dir)
        count = int(round(duration * FPS))
        for i in range(count):
            t = i / FPS
            if t < BAR:
                # The build: the first frame rises out of the dark.
                square = images[0]
                brightness = smooth(t / (BAR * 0.85))
            elif t >= duration - HOLD:
                square = images[0]
                brightness = 1.0
            else:
                k = int(((t - BAR) % clip_length) * fps) % len(images)
                square = images[k]
                brightness = 1.0
            flash = max(0.0, 0.65 * (1 - (t - BAR) / 0.35)) if t >= BAR else 0.0
            Image.fromarray(compose(square, brightness, flash)).save(os.path.join(out_dir, f"{i:04d}.png"))
        path = os.path.join(video_dir, "saga_intro.mp4")
        run(
            "-framerate", str(FPS), "-i", os.path.join(out_dir, "%04d.png"), "-i", wav,
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow",
            "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", path,
        )
        print(f"saga_intro.mp4  {duration:.1f} s  {os.path.getsize(path) / 1024:.0f} KB")
        print(f"intro_sting.ogg {os.path.getsize(os.path.join(music_dir, 'intro_sting.ogg')) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
