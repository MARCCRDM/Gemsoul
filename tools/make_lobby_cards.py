"""
Paints the key art for the lobby's PLAY menu cards: a lunar night scene per
mode with blocky miner silhouettes rim-lit in the card's colour.

    pip install numpy pillow
    python tools/make_lobby_cards.py

Writes assets/images/lobby/<card>.png (2x the card size) and a preview
sheet. Upload the five PNGs (Studio: Asset Manager, Bulk Import) and put
their ids in LobbyUI.Art.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "images", "lobby")

GOLD = (255, 202, 91)
TEAL = (58, 203, 233)
AMETHYST = (170, 90, 240)
EMERALD = (34, 207, 157)
RED = (232, 72, 72)


# ---------------------------------------------------------------- helpers
def blank(w, h):
    return Image.new("L", (w, h), 0)


def arr(m):
    return np.asarray(m, np.float32)[..., None] / 255


def lerp(a, b, t):
    return np.array(a, np.float32) * (1 - t) + np.array(b, np.float32) * t


def rot(points, degrees, centre):
    a = math.radians(degrees)
    ca, sa = math.cos(a), math.sin(a)
    cx, cy = centre
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in points]


def box(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


class Canvas:
    def __init__(self, w, h, seed):
        self.w, self.h = w, h
        self.rng = random.Random(seed)
        self.yy, self.xx = np.mgrid[0:h, 0:w].astype(np.float32)
        self.img = np.zeros((h, w, 3), np.float32)

    def sky(self, top, bottom, horizon):
        t = np.clip(self.yy / (self.h * horizon), 0, 1)[..., None]
        self.img = lerp(top, bottom, t)
        stars = blank(self.w, self.h)
        d = ImageDraw.Draw(stars)
        for _ in range(int(self.w * self.h / 2500)):
            x, y = self.rng.uniform(0, self.w), self.rng.uniform(0, self.h * horizon * 0.9)
            r = self.rng.choice((0.6, 0.8, 1.0, 1.4, 2.0))
            d.ellipse((x - r, y - r, x + r, y + r), fill=self.rng.randint(110, 255))
        self.img += arr(stars) * 230

    def glow(self, cx, cy, radius, color, strength=1.0):
        r = np.sqrt((self.xx - cx) ** 2 + (self.yy - cy) ** 2) / radius
        self.img += np.exp(-(r**2) * 2.2)[..., None] * np.array(color, np.float32) * strength

    def planet(self, cx, cy, r, color, light=(1, -1)):
        m = blank(self.w, self.h)
        ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
        a = arr(m.filter(ImageFilter.GaussianBlur(1.2)))
        nx, ny = (self.xx - cx) / r, (self.yy - cy) / r
        shade = np.clip(0.35 + 0.65 * (-(nx * light[0] + ny * light[1]) * 0.6 + 0.5), 0.15, 1)[..., None]
        body = np.array(color, np.float32) * shade
        self.img = self.img * (1 - a) + body * a
        self.glow(cx, cy, r * 1.6, color, 0.18)

    def ridge(self, base, height, color, roughness, seed):
        rng = random.Random(seed)
        pts = [(0, self.h)]
        y = base
        for x in np.linspace(0, self.w, 40):
            y = base - abs(math.sin(x / self.w * math.pi * rng.uniform(1.5, 3))) * height * rng.uniform(0.6, 1)
            y += rng.uniform(-roughness, roughness)
            pts.append((x, y))
        pts.append((self.w, self.h))
        m = blank(self.w, self.h)
        ImageDraw.Draw(m).polygon(pts, fill=255)
        a = arr(m.filter(ImageFilter.GaussianBlur(1.5)))
        self.img = self.img * (1 - a) + np.array(color, np.float32) * a

    def floor(self, top_y, color_near, color_far, grid=None, vanish=None):
        t = np.clip((self.yy - top_y) / max(self.h - top_y, 1), 0, 1)[..., None]
        a = (self.yy >= top_y)[..., None].astype(np.float32)
        ground = lerp(color_far, color_near, t)
        self.img = self.img * (1 - a) + ground * a
        if grid:
            lines = blank(self.w, self.h)
            d = ImageDraw.Draw(lines)
            vx, vy = vanish or (self.w / 2, top_y - self.h * 0.15)
            for k in range(-14, 15):
                x = self.w / 2 + k * self.w * 0.16
                d.line([(vx + (x - vx) * 0.0, vy), (x, self.h)], fill=150, width=2)
            for k in range(1, 12):
                y = top_y + (self.h - top_y) * (k / 12) ** 1.8
                d.line([(0, y), (self.w, y)], fill=150, width=2)
            g = arr(lines) * a
            self.img += g * np.array(grid, np.float32) * 0.45

    def silhouette(self, mask, rim, rim_side=1, fill=(10, 12, 20)):
        a = arr(mask.filter(ImageFilter.GaussianBlur(0.8)))
        shifted = ImageChops.offset(mask, -rim_side * 5, 3)
        edge = arr(ImageChops.subtract(mask, shifted).filter(ImageFilter.GaussianBlur(1.6)))
        halo = arr(mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(14)))
        self.img += halo * np.array(rim, np.float32) * 0.5
        self.img = self.img * (1 - a) + np.array(fill, np.float32) * a
        self.img += edge * np.array(rim, np.float32) * 1.6

    def sparks(self, cx, cy, spread, count, color, size=3):
        m = blank(self.w, self.h)
        d = ImageDraw.Draw(m)
        for _ in range(count):
            ang = self.rng.uniform(0, math.tau)
            r = self.rng.uniform(0.1, 1) * spread
            x, y = cx + math.cos(ang) * r, cy + math.sin(ang) * r
            length = self.rng.uniform(4, 16)
            d.line([(x, y), (x + math.cos(ang) * length, y + math.sin(ang) * length)], fill=255, width=max(1, int(size * self.rng.uniform(0.5, 1))))
        self.img += arr(m.filter(ImageFilter.GaussianBlur(4))) * np.array(color, np.float32) * 1.4
        self.img += arr(m) * 255 * 0.8

    def beam(self, pts, width, color):
        m = blank(self.w, self.h)
        ImageDraw.Draw(m).line(pts, fill=255, width=width, joint="curve")
        self.img += arr(m.filter(ImageFilter.GaussianBlur(width * 1.5))) * np.array(color, np.float32) * 1.3
        self.img += arr(m.filter(ImageFilter.GaussianBlur(1))) * 255 * 0.7

    def finish(self, text_fade=0.45):
        # Fog near the floor, a vignette, and darkness at the bottom for the text.
        r = np.sqrt(((self.xx - self.w / 2) / self.w) ** 2 + ((self.yy - self.h * 0.45) / self.h) ** 2)
        self.img *= np.clip(1.15 - r * 1.1, 0.35, 1)[..., None]
        fade = np.clip((self.yy / self.h - (1 - text_fade)) / text_fade, 0, 1)[..., None] ** 1.3
        self.img = self.img * (1 - fade * 0.82) + np.array((6, 8, 14), np.float32) * fade * 0.82
        grain = np.random.default_rng(3).normal(0, 2.2, self.img.shape).astype(np.float32)
        return Image.fromarray(np.clip(self.img + grain, 0, 255).astype(np.uint8), "RGB")


def miner(d, x, ground, h, facing=1, stance=0.18, weapon="sword", raise_arm=0.0, crown=False):
    """A blocky Saga miner: helmet with visor, pauldrons, armour plates, a weapon."""
    u = h / 10
    hip = ground - u * 4.6
    shoulder = hip - u * 3.4
    # Legs (a fighting stance).
    for side in (-1, 1):
        fx = x + side * u * (1.0 + stance * 6)
        d.polygon([(x + side * u * 0.3, hip), (x + side * u * 1.3, hip), (fx + side * u * 0.55, ground), (fx - side * u * 0.65, ground)], fill=255)
        toe = fx + facing * u * 0.95
        d.rectangle((min(fx, toe) - u * 0.6, ground - u * 0.55, max(fx, toe) + u * 0.3, ground), fill=255)
    # Torso, belt and chest plate.
    d.polygon([(x - u * 1.6, shoulder), (x + u * 1.6, shoulder), (x + u * 1.25, hip), (x - u * 1.25, hip)], fill=255)
    d.rectangle((x - u * 1.45, hip - u * 0.5, x + u * 1.45, hip + u * 0.2), fill=255)
    # Pauldrons.
    for side in (-1, 1):
        px = x + side * u * 1.75
        d.ellipse((px - u * 0.95, shoulder - u * 0.55, px + u * 0.95, shoulder + u * 0.75), fill=255)
    # Helmet and visor ridge.
    d.rounded_rectangle((x - u * 1.0, shoulder - u * 2.3, x + u * 1.0, shoulder - u * 0.15), radius=u * 0.35, fill=255)
    d.rectangle((x - u * 1.15, shoulder - u * 1.45, x + u * 1.15, shoulder - u * 1.05), fill=255)
    d.polygon([(x - u * 0.2, shoulder - u * 2.3), (x + u * 0.2, shoulder - u * 2.3), (x, shoulder - u * 2.9)], fill=255)
    if crown:
        for k in range(-2, 3):
            cx = x + k * u * 0.42
            d.polygon([(cx - u * 0.22, shoulder - u * 2.35), (cx + u * 0.22, shoulder - u * 2.35), (cx, shoulder - u * 3.2)], fill=255)
    # Arms: the back arm down, the weapon arm forward (or raised).
    back = x - facing * u * 1.9
    d.polygon([(back - u * 0.45, shoulder + u * 0.2), (back + u * 0.45, shoulder + u * 0.2), (back + u * 0.2 - facing * u * 0.3, hip + u * 0.6), (back - u * 0.6 - facing * u * 0.3, hip + u * 0.6)], fill=255)
    sx, sy = x + facing * u * 1.9, shoulder + u * 0.3
    # Arm angle: 0 = straight ahead, 90 = straight up (screen y points down).
    arm = math.radians(-45 + raise_arm * 135)
    hand = (sx + facing * u * 2.6 * math.cos(arm), sy - u * 2.6 * math.sin(arm))
    d.line([(sx, sy), hand], fill=255, width=int(u * 0.95))
    d.ellipse((hand[0] - u * 0.55, hand[1] - u * 0.55, hand[0] + u * 0.55, hand[1] + u * 0.55), fill=255)
    if weapon == "sword":
        blade = arm + math.radians(70 * (1 - raise_arm))
        tip = (hand[0] + facing * u * 6.2 * math.cos(blade), hand[1] - u * 6.2 * math.sin(blade))
        d.line([hand, tip], fill=255, width=int(u * 0.55))
        gx, gy = math.sin(blade) * u * 0.9, math.cos(blade) * u * 0.9 * facing
        d.line([(hand[0] - gx * facing, hand[1] - gy * facing), (hand[0] + gx * facing, hand[1] + gy * facing)], fill=255, width=int(u * 0.45))
        return tip
    if weapon == "hammer":
        top = (hand[0] + facing * u * 0.6, hand[1] - u * 5.2)
        d.line([(hand[0], hand[1] + u * 1.0), top], fill=255, width=int(u * 0.5))
        d.rectangle((top[0] - u * 1.4, top[1] - u * 1.0, top[0] + u * 1.4, top[1] + u * 0.7), fill=255)
        return top
    if weapon == "shield":
        d.rounded_rectangle((hand[0] - u * 1.3, hand[1] - u * 2.0, hand[0] + u * 1.3, hand[1] + u * 1.6), radius=u * 0.5, fill=255)
        return hand
    return hand


def figures(c, specs, rim, rim_side=1):
    m = blank(c.w, c.h)
    d = ImageDraw.Draw(m)
    tips = []
    for spec in specs:
        tips.append(miner(d, **spec))
    c.silhouette(m, rim, rim_side)
    return tips


# ------------------------------------------------------------------ cards
def duel(w, h):
    c = Canvas(w, h, 11)
    c.sky((10, 12, 28), (52, 40, 30), 0.62)
    c.planet(w * 0.78, h * 0.16, w * 0.13, (210, 180, 140))
    c.glow(w * 0.5, h * 0.5, w * 0.7, GOLD, 0.35)
    c.ridge(h * 0.6, h * 0.08, (24, 22, 30), 6, 3)
    c.floor(h * 0.6, (40, 34, 30), (26, 24, 30), grid=GOLD)
    c.glow(w * 0.5, h * 0.66, w * 0.45, GOLD, 0.45)
    tips = figures(
        c,
        [
            dict(x=w * 0.2, ground=h * 0.8, h=h * 0.4, facing=1, raise_arm=0.3, stance=0.24),
            dict(x=w * 0.8, ground=h * 0.79, h=h * 0.39, facing=-1, raise_arm=0.3, stance=0.24),
        ],
        GOLD,
    )
    mid = ((tips[0][0] + tips[1][0]) / 2, (tips[0][1] + tips[1][1]) / 2)
    c.glow(mid[0], mid[1], w * 0.12, (255, 230, 170), 1.1)
    c.sparks(mid[0], mid[1], w * 0.2, 46, GOLD)
    return c.finish()


def clash(w, h):
    c = Canvas(w, h, 12)
    c.sky((6, 14, 26), (20, 50, 66), 0.6)
    c.planet(w * 0.5, h * 0.2, h * 0.14, (120, 200, 230))
    c.ridge(h * 0.58, h * 0.12, (12, 26, 36), 5, 4)
    c.floor(h * 0.58, (20, 44, 54), (14, 28, 38), grid=TEAL)
    c.glow(w * 0.5, h * 0.6, w * 0.32, TEAL, 0.55)
    figures(
        c,
        [
            dict(x=w * 0.12, ground=h * 0.98, h=h * 0.72, facing=1, raise_arm=0.3),
            dict(x=w * 0.3, ground=h * 0.92, h=h * 0.62, facing=1, weapon="shield"),
            dict(x=w * 0.7, ground=h * 0.92, h=h * 0.62, facing=-1, weapon="hammer", raise_arm=0.5),
            dict(x=w * 0.88, ground=h * 0.98, h=h * 0.72, facing=-1, raise_arm=0.3),
        ],
        TEAL,
    )
    c.beam([(w * 0.42, h * 0.45), (w * 0.5, h * 0.36), (w * 0.47, h * 0.5), (w * 0.58, h * 0.42)], 4, TEAL)
    c.sparks(w * 0.5, h * 0.45, h * 0.3, 30, TEAL)
    return c.finish(0.25)


def dungeon(w, h):
    c = Canvas(w, h, 13)
    c.sky((8, 6, 18), (30, 14, 44), 0.7)
    c.ridge(h * 0.7, h * 0.35, (20, 12, 30), 8, 5)
    # The gate: a stone arch with a glowing portal.
    gx, gw = w * 0.62, w * 0.2
    c.glow(gx, h * 0.48, gw * 1.3, AMETHYST, 0.9)
    m = blank(w, h)
    d = ImageDraw.Draw(m)
    d.rectangle((gx - gw * 0.75, h * 0.18, gx + gw * 0.75, h * 0.9), fill=255)
    hole = blank(w, h)
    ImageDraw.Draw(hole).rounded_rectangle((gx - gw * 0.45, h * 0.3, gx + gw * 0.45, h * 0.9), radius=gw * 0.45, fill=255)
    stone = ImageChops.subtract(m, hole)
    c.silhouette(stone, AMETHYST, -1, fill=(22, 16, 30))
    portal = arr(hole.filter(ImageFilter.GaussianBlur(2)))
    swirl = (0.5 + 0.5 * np.sin((c.xx - gx) * 0.05 + (c.yy) * 0.04))[..., None]
    c.img = c.img * (1 - portal) + portal * lerp((60, 20, 110), (230, 170, 255), swirl * 0.7)
    c.floor(h * 0.9, (26, 18, 36), (20, 14, 30))
    figures(
        c,
        [
            dict(x=w * 0.16, ground=h * 1.02, h=h * 0.72, facing=1, weapon="hammer"),
            dict(x=w * 0.28, ground=h * 0.98, h=h * 0.64, facing=1),
            dict(x=w * 0.39, ground=h * 1.0, h=h * 0.68, facing=1, weapon="shield"),
        ],
        AMETHYST,
    )
    c.sparks(gx, h * 0.6, gw, 26, AMETHYST, 2)
    return c.finish(0.25)


def custom(w, h):
    c = Canvas(w, h, 14)
    c.sky((6, 16, 18), (18, 52, 44), 0.6)
    c.planet(w * 0.85, h * 0.25, h * 0.12, (160, 230, 200))
    c.ridge(h * 0.62, h * 0.1, (12, 30, 28), 5, 6)
    c.floor(h * 0.62, (22, 46, 40), (14, 30, 28))
    # The Outpost's beacon, everyone gathered round.
    c.glow(w * 0.5, h * 0.55, w * 0.22, EMERALD, 1.0)
    m = blank(w, h)
    ImageDraw.Draw(m).polygon([(w * 0.49, h * 0.2), (w * 0.51, h * 0.2), (w * 0.53, h * 0.72), (w * 0.47, h * 0.72)], fill=255)
    c.silhouette(m, EMERALD, 1)
    c.beam([(w * 0.5, 0), (w * 0.5, h * 0.22)], 3, EMERALD)
    figures(
        c,
        [
            dict(x=w * 0.22, ground=h * 0.96, h=h * 0.62, facing=1, weapon="none"),
            dict(x=w * 0.36, ground=h * 0.9, h=h * 0.52, facing=1, weapon="none"),
            dict(x=w * 0.64, ground=h * 0.9, h=h * 0.52, facing=-1, weapon="none"),
            dict(x=w * 0.78, ground=h * 0.96, h=h * 0.62, facing=-1, weapon="hammer"),
        ],
        EMERALD,
    )
    return c.finish(0.25)


def ranked(w, h):
    c = Canvas(w, h, 15)
    c.sky((16, 6, 10), (60, 16, 20), 0.6)
    c.planet(w * 0.25, h * 0.14, w * 0.1, (240, 140, 120))
    # Spotlights from above.
    for x0, x1 in ((0.2, 0.45), (0.8, 0.55)):
        m = blank(w, h)
        ImageDraw.Draw(m).polygon([(w * x0 - 20, 0), (w * x0 + 20, 0), (w * x1 + w * 0.12, h * 0.72), (w * x1 - w * 0.12, h * 0.72)], fill=90)
        c.img += arr(m.filter(ImageFilter.GaussianBlur(18))) * np.array(RED, np.float32) * 0.9
    c.floor(h * 0.62, (40, 16, 18), (26, 10, 12), grid=RED)
    # Banners.
    for bx in (0.12, 0.88):
        m = blank(w, h)
        d = ImageDraw.Draw(m)
        d.rectangle((w * bx - 3, h * 0.12, w * bx + 3, h * 0.62), fill=255)
        d.polygon([(w * bx, h * 0.14), (w * bx + w * 0.1 * (1 if bx < 0.5 else -1), h * 0.16), (w * bx + w * 0.1 * (1 if bx < 0.5 else -1), h * 0.4), (w * bx, h * 0.36)], fill=255)
        c.silhouette(m, RED, 1 if bx < 0.5 else -1, fill=(110, 24, 28))
    # The podium and its champion.
    m = blank(w, h)
    ImageDraw.Draw(m).polygon([(w * 0.28, h * 0.7), (w * 0.72, h * 0.7), (w * 0.78, h * 0.8), (w * 0.22, h * 0.8)], fill=255)
    c.silhouette(m, RED, 1, fill=(30, 16, 18))
    c.glow(w * 0.5, h * 0.45, w * 0.4, RED, 0.6)
    tip = figures(c, [dict(x=w * 0.5, ground=h * 0.7, h=h * 0.42, facing=1, raise_arm=1.0, crown=True)], (255, 120, 110))[0]
    c.glow(tip[0], tip[1], w * 0.08, (255, 210, 190), 1.0)
    c.sparks(tip[0], tip[1], w * 0.1, 24, RED)
    return c.finish()


CARDS = {
    "duel": (duel, 340, 500),
    "clash": (clash, 420, 156),
    "dungeon": (dungeon, 420, 156),
    "custom": (custom, 420, 156),
    "ranked": (ranked, 290, 500),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    rendered = {}
    for name, (paint, w, h) in CARDS.items():
        image = paint(w * 2, h * 2)
        image.save(os.path.join(OUT, f"{name}.png"), optimize=True)
        rendered[name] = image
        print(f"{name}.png  {image.width}x{image.height}")
    sheet = Image.new("RGB", (1120, 560), (12, 14, 20))
    layout = {"duel": (0, 0), "clash": (362, 0), "dungeon": (362, 172), "custom": (362, 344), "ranked": (830, 0)}
    for name, (x, y) in layout.items():
        _, w, h = CARDS[name]
        sheet.paste(rendered[name].resize((w, h), Image.LANCZOS), (x, y))
    sheet.save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
