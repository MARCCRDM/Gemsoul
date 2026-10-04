"""
Turns the SAGA MINERS logo video into GUI art the game draws itself, so the
title screen looks like the video without uploading a video (or any image).

    pip install numpy pillow imageio-ffmpeg
    python tools/make_splash_art.py path/to/logo.mp4

It takes the steady picture behind the video's animation (the median of its
frames) and cuts it into two layers of flat-coloured rectangles:
  - the nebula background, on a coarse pixel grid,
  - the logo, on the art's own 3-pixel grid, with everything that isn't
    logo left out;
plus the twinkling stars it finds in the sky. Neighbouring pixels of one
colour merge into one rectangle, so it's a few thousand Frames in all.
The animation (the shine sweeping across the letters, the sparkles and the
shooting star) is played by src/client/Splash.client.luau.

Writes src/client/Modules/SplashArt.luau.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "src", "client", "Modules", "SplashArt.luau")
SIZE = 618  # the video's square
BG_GRID, BG_COLOURS = 9, 14
LOGO_GRID, LOGO_COLOURS = 3, 30
LOGO_BOX = (0, 180, 618, 440)  # where the logo sits in the frame (x0, y0, x1, y1)


def ffmpeg() -> str:
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


def steady_picture(video: str) -> np.ndarray:
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", video, os.path.join(tmp, "%03d.png")], check=True)
        frames = [np.asarray(Image.open(os.path.join(tmp, n)).convert("RGB"), np.float32) for n in sorted(os.listdir(tmp))]
    return np.median(np.stack(frames), 0)


def components(mask: np.ndarray) -> list[np.ndarray]:
    """Connected regions of a boolean mask (4-neighbour flood fill)."""
    seen = np.zeros_like(mask)
    h, w = mask.shape
    found = []
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0, x0] or seen[y0, x0]:
                continue
            stack, pixels = [(y0, x0)], []
            seen[y0, x0] = True
            while stack:
                y, x = stack.pop()
                pixels.append((y, x))
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            found.append(np.array(pixels))
    return found


def logo_mask(picture: np.ndarray) -> np.ndarray:
    a = picture.astype(int)
    hi, lo = a.max(2), a.min(2)
    core = ((hi > 120) & (hi - lo > 55)) | ((a[..., 2] > 110) & (a[..., 0] > 60) & (hi - lo > 40))
    keep = np.zeros_like(core)
    x0, y0, x1, y1 = LOGO_BOX
    keep[y0:y1, x0:x1] = core[y0:y1, x0:x1]
    # Only the big shapes (letters and wings), not stars.
    mask = np.zeros_like(keep)
    for region in components(keep):
        if len(region) > 400:
            mask[region[:, 0], region[:, 1]] = True
    grown = Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))
    return np.asarray(grown) > 0


def rectangles(indices: np.ndarray, skip: int | None = None) -> list[tuple[int, int, int, int, int]]:
    h, w = indices.shape
    used = np.zeros_like(indices, bool)
    out = []
    for y in range(h):
        x = 0
        while x < w:
            c = indices[y, x]
            if used[y, x] or c == skip:
                x += 1
                continue
            x2 = x
            while x2 + 1 < w and indices[y, x2 + 1] == c and not used[y, x2 + 1]:
                x2 += 1
            y2 = y
            while y2 + 1 < h and (indices[y2 + 1, x : x2 + 1] == c).all() and not used[y2 + 1, x : x2 + 1].any():
                y2 += 1
            used[y : y2 + 1, x : x2 + 1] = True
            out.append((x, y, x2 - x + 1, y2 - y + 1, int(c)))
            x = x2 + 1
    return out


def kmeans_palette(pixels: np.ndarray, colours: int) -> np.ndarray:
    """A palette that fits these pixels (k-means, seeded from spread-out picks)."""
    rng = np.random.default_rng(1)
    pixels = pixels.astype(np.float32)
    sample = pixels[rng.choice(len(pixels), min(len(pixels), 20000), replace=False)]
    centres = [sample[0]]
    for _ in range(colours - 1):
        d = np.min([((sample - c) ** 2).sum(1) for c in centres], 0)
        centres.append(sample[int(np.argmax(d))])
    centres = np.array(centres)
    for _ in range(25):
        label = np.argmin(((sample[:, None] - centres[None]) ** 2).sum(2), 1)
        for k in range(colours):
            if (label == k).any():
                centres[k] = sample[label == k].mean(0)
    return centres


def quantize(image: Image.Image, colours: int, mask: np.ndarray | None = None):
    """Palette indices for an image, the palette fitted to the (masked) pixels only."""
    a = np.asarray(image.convert("RGB"), np.float32)
    pixels = a[mask] if mask is not None else a.reshape(-1, 3)
    centres = kmeans_palette(pixels, colours)
    flat = a.reshape(-1, 3)
    index = np.argmin(((flat[:, None] - centres[None]) ** 2).sum(2), 1).reshape(a.shape[:2])
    return index.astype(np.int32), [tuple(int(v) for v in c) for c in centres]


def grid_phase(picture: np.ndarray, grid: int, box) -> tuple[int, int]:
    """Where the art's pixel grid lines fall: the offset whose cells are most uniform."""
    x0, y0, x1, y1 = box
    region = picture[y0:y1, x0:x1].astype(np.float32)
    best, phase = None, (0, 0)
    for oy in range(grid):
        for ox in range(grid):
            r = region[oy:, ox:]
            h, w = (r.shape[0] // grid) * grid, (r.shape[1] // grid) * grid
            cells = r[:h, :w].reshape(h // grid, grid, w // grid, grid, 3)
            spread = cells.std(axis=(1, 3)).mean()
            if best is None or spread < best:
                best, phase = spread, (ox, oy)
    return phase


def encode(rects) -> str:
    # Five bytes per rectangle, as hex: x, y, width, height, colour.
    return "".join("%02x%02x%02x%02x%02x" % r for r in rects)


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: python tools/make_splash_art.py path/to/logo.mp4")
    picture = steady_picture(sys.argv[1])
    mask = logo_mask(picture)

    # The sky: fill the logo's place from its surroundings, then a coarse grid.
    sky = Image.fromarray(picture.astype(np.uint8))
    blurred = np.asarray(sky.filter(ImageFilter.GaussianBlur(14)), np.float32)
    filled = np.where(mask[..., None], blurred, picture)
    cells = SIZE // BG_GRID
    small = Image.fromarray(filled.astype(np.uint8)).resize((cells, cells), Image.BOX)
    bg_indices, bg_palette = quantize(small, BG_COLOURS)
    bg_rects = rectangles(bg_indices)

    # The logo on its pixel grid; anything outside the mask is left out.
    ox, oy = grid_phase(picture, LOGO_GRID, LOGO_BOX)
    x0, y0, x1, y1 = LOGO_BOX
    x0, y0 = x0 + ox, y0 + oy
    w, h = (x1 - x0) // LOGO_GRID, (y1 - y0) // LOGO_GRID
    x1, y1 = x0 + w * LOGO_GRID, y0 + h * LOGO_GRID
    crop = Image.fromarray(picture[y0:y1, x0:x1].astype(np.uint8))
    small_logo = crop.resize((w, h), Image.BOX)
    small_mask = np.asarray(Image.fromarray(mask[y0:y1, x0:x1].astype(np.uint8) * 255).resize((w, h), Image.BOX)) > 110
    logo_indices, logo_palette = quantize(small_logo, LOGO_COLOURS, small_mask)
    logo_indices[~small_mask] = 255
    logo_rects = rectangles(logo_indices, skip=255)

    # Stars: small bright points in the sky.
    a = picture.astype(int)
    bright = (a.max(2) > 110) & ~mask
    stars = []
    for region in components(bright):
        if 1 <= len(region) <= 40:
            cy, cx = region.mean(0)
            colour = picture[int(cy), int(cx)]
            stars.append((round(cx / SIZE, 4), round(cy / SIZE, 4), max(2, int(np.sqrt(len(region)))), "%02x%02x%02x" % tuple(int(c) for c in colour)))

    def palette_lua(palette):
        return "{ " + ", ".join('"%02x%02x%02x"' % c for c in palette) + " }"

    lines = [
        "-- Generated by tools/make_splash_art.py from the SAGA MINERS logo video: don't edit by hand.",
        "-- Rectangles are 10 hex digits each: x, y, width, height (in grid cells) and palette index.",
        "return {",
        f"\tSize = {SIZE},",
        "\tBackground = {",
        f"\t\tGrid = {BG_GRID},",
        f"\t\tCells = {cells},",
        f"\t\tPalette = {palette_lua(bg_palette)},",
        f'\t\tRects = "{encode(bg_rects)}",',
        "\t},",
        "\tLogo = {",
        f"\t\tGrid = {LOGO_GRID},",
        f"\t\tOrigin = {{ {x0}, {y0} }},",
        f"\t\tCells = {{ {w}, {h} }},",
        f"\t\tPalette = {palette_lua(logo_palette)},",
        f'\t\tRects = "{encode(logo_rects)}",',
        "\t},",
        "\tStars = {",
    ]
    for star in stars:
        lines.append('\t\t{ %s, %s, %d, "%s" },' % star)
    lines += ["\t},", "}", ""]
    with open(OUT, "w") as f:
        f.write("\n".join(lines))
    print(f"background {len(bg_rects)} rects, logo {len(logo_rects)} rects, {len(stars)} stars -> {OUT}")

    # A preview drawn from the rectangles, to compare with the video.
    preview = Image.new("RGB", (SIZE, SIZE))
    px = preview.load()
    for x, y, rw, rh, c in bg_rects:
        for yy in range(y * BG_GRID, (y + rh) * BG_GRID):
            for xx in range(x * BG_GRID, (x + rw) * BG_GRID):
                px[xx, yy] = bg_palette[c]
    for x, y, rw, rh, c in logo_rects:
        for yy in range(y0 + y * LOGO_GRID, y0 + (y + rh) * LOGO_GRID):
            for xx in range(x0 + x * LOGO_GRID, x0 + (x + rw) * LOGO_GRID):
                px[xx, yy] = logo_palette[c]
    for sx, sy, size, colour in stars:
        for d in range(-(size // 2), size - size // 2):
            for e in range(-(size // 2), size - size // 2):
                xx, yy = int(sx * SIZE) + d, int(sy * SIZE) + e
                if 0 <= xx < SIZE and 0 <= yy < SIZE:
                    px[xx, yy] = tuple(int(colour[i : i + 2], 16) for i in (0, 2, 4))
    if len(sys.argv) > 2:
        preview.save(sys.argv[2])


if __name__ == "__main__":
    main()
