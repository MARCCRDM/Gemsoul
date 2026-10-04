"""
Paints the ability icons: one square, full-bleed painted icon per Rig
Maneuver and Gem Surge, packed into a single sprite sheet.

    pip install numpy pillow
    python tools/make_ability_icons.py

Writes:
  assets/images/ability_icons.png          the sheet (8 columns of 128 px)
  assets/images/ability_icons_preview.png  a labelled contact sheet
  src/client/Modules/AbilityIconAtlas.luau where each ability sits on it

Upload ability_icons.png once (Creator Hub, Decals/Images) and put its id in
SurgeIcons.ImageId. Each icon is painted at 512 px and scaled down: an
element-coloured backdrop, a bevelled, outlined symbol with a soft glow, and
a vignette, with the symbol kept inside the middle so round sockets don't
clip it.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
S = 512
CELL = 128
COLUMNS = 8
C = S / 2

# Backdrop (centre, edge), symbol gradient (light, dark), glow, energy core.
PALETTES = {
    "Rig": dict(bg=((150, 104, 52), (26, 16, 8)), sym=((255, 226, 150), (214, 120, 40)), glow=(255, 176, 80)),
    "Earth": dict(bg=((140, 96, 54), (30, 18, 8)), sym=((255, 214, 140), (200, 120, 50)), glow=(255, 170, 70)),
    "Fire": dict(bg=((206, 74, 22), (44, 8, 4)), sym=((255, 246, 196), (255, 112, 24)), glow=(255, 136, 36)),
    "Frost": dict(bg=((36, 116, 188), (4, 16, 40)), sym=((246, 254, 255), (104, 194, 255)), glow=(130, 222, 255)),
    "Poison": dict(bg=((58, 136, 38), (6, 24, 6)), sym=((226, 255, 150), (76, 196, 44)), glow=(150, 255, 90)),
    "Shock": dict(bg=((84, 66, 186), (10, 8, 42)), sym=((255, 255, 214), (255, 206, 40)), glow=(255, 228, 96)),
    "Charge": dict(bg=((30, 140, 150), (4, 22, 28)), sym=((220, 255, 255), (60, 210, 220)), glow=(110, 250, 255)),
    "Resonance": dict(bg=((134, 52, 176), (24, 6, 36)), sym=((255, 232, 255), (214, 118, 255)), glow=(226, 140, 255)),
}
MATERIALS = {
    "metal": ((240, 244, 250), (92, 102, 122)),
    "steel": ((200, 208, 222), (60, 66, 82)),
    "gold": ((255, 238, 160), (170, 104, 26)),
    "wood": ((164, 108, 62), (66, 36, 18)),
    "rock": ((128, 112, 102), (44, 36, 32)),
    "darkrock": ((84, 72, 70), (22, 18, 18)),
    "dark": ((76, 76, 88), (18, 18, 24)),
    "bone": ((255, 250, 232), (176, 164, 136)),
    "glass": ((236, 250, 255), (150, 190, 210)),
    "heal": ((214, 255, 226), (60, 220, 130)),
    "blood": ((255, 150, 160), (196, 28, 52)),
    "ice": ((250, 255, 255), (120, 200, 250)),
    "icedeep": ((180, 236, 255), (40, 120, 210)),
    "lava": ((255, 250, 180), (255, 96, 10)),
    "acid": ((236, 255, 160), (70, 200, 40)),
    "violet": ((240, 210, 255), (150, 70, 220)),
}
OUTLINE = (10, 6, 8)


# ---------------------------------------------------------------- geometry
def mask():
    return Image.new("L", (S, S), 0)


def rot(points, degrees, centre=(C, C)):
    a = math.radians(degrees)
    ca, sa = math.cos(a), math.sin(a)
    cx, cy = centre
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in points]


def move(points, dx, dy):
    return [(x + dx, y + dy) for x, y in points]


def poly(points):
    m = mask()
    ImageDraw.Draw(m).polygon([(float(x), float(y)) for x, y in points], fill=255)
    return m


def circle(cx, cy, r):
    m = mask()
    ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    return m


def ellipse(cx, cy, rx, ry):
    m = mask()
    ImageDraw.Draw(m).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    return m


def ring(cx, cy, r, w):
    return sub(circle(cx, cy, r + w / 2), circle(cx, cy, r - w / 2))


def line(points, w):
    m = mask()
    d = ImageDraw.Draw(m)
    points = [(float(x), float(y)) for x, y in points]
    d.line(points, fill=255, width=int(w), joint="curve")
    for x, y in (points[0], points[-1]):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=255)
    return m


def arc(cx, cy, r, a0, a1, w):
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in np.linspace(a0, a1, 64)]
    return line(pts, w)


def band(cx, cy, r, a0, a1, w0, w1):
    """A curved band that tapers from width w0 to w1."""
    outer, inner = [], []
    for i, a in enumerate(np.linspace(a0, a1, 72)):
        t = i / 71
        w = w0 + (w1 - w0) * t
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        outer.append((cx + (r + w / 2) * ca, cy + (r + w / 2) * sa))
        inner.append((cx + (r - w / 2) * ca, cy + (r - w / 2) * sa))
    return poly(outer + inner[::-1])


def rrect(x0, y0, x1, y1, r):
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for a in np.linspace(a0, a0 + 90, 8):
            pts.append((cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))))
    return pts


def star(cx, cy, n, r1, r2, spin=0.0, jitter=0.0, seed=1):
    rng = random.Random(seed)
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        r *= 1 + rng.uniform(-jitter, jitter)
        a = math.radians(spin + i * 180 / n - 90)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def bezier(p0, p1, p2, steps=24):
    return [
        ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
        for t in np.linspace(0, 1, steps)
    ]


def flame(cx, base, w, h, lean=0.0, wave=0.0):
    """A flame tongue standing on (cx, base), its tip h above."""
    left, right = [], []
    for i in range(41):
        s = i / 40
        half = w / 2 * math.sin(math.pi * min(1.0, 0.55 + s * 0.45)) ** 0.6 * (1 - s) ** 0.85
        x = cx + lean * h * s * s + wave * w * math.sin(s * 7.5) * s
        y = base - s * h
        left.append((x - half, y))
        right.append((x + half, y))
    bottom = [(cx + w / 2 * math.cos(math.radians(a)), base + w / 2 * 0.55 * math.sin(math.radians(a))) for a in np.linspace(180, 0, 12)]
    return right + left[::-1] + bottom


def drop(cx, cy, r, up=True):
    """A droplet with its point up (falling) or down."""
    pts = []
    for a in np.linspace(0, 360, 60, endpoint=False):
        t = math.radians(a)
        x = r * math.sin(t) * (1 - 0.0)
        y = -r * math.cos(t)
        pinch = (1 + math.cos(t)) / 2  # 1 at the top
        x *= 1 - 0.75 * pinch**2
        y -= r * 0.9 * pinch**3
        pts.append((cx + x, cy + (y if up else -y)))
    return pts


def bolt(points, w0, w1):
    """A zigzag lightning bolt along points, tapering from w0 to w1."""
    left, right = [], []
    n = len(points)
    for i, (x, y) in enumerate(points):
        a = points[min(i + 1, n - 1)]
        b = points[max(i - 1, 0)]
        dx, dy = a[0] - b[0], a[1] - b[1]
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return poly(left + right[::-1])


def zigzag(a, b, segments, amp, seed):
    rng = random.Random(seed)
    pts = [a]
    for i in range(1, segments):
        t = i / segments
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        nx, ny = -dy / length, dx / length
        o = amp * (1 if i % 2 else -1) * rng.uniform(0.5, 1.0)
        pts.append((x + nx * o, y + ny * o))
    pts.append(b)
    return pts


def sub(a, b):
    return ImageChops.subtract(a, b)


def union(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.lighter(out, m)
    return out


def inter(a, b):
    return ImageChops.multiply(a, b)


# --------------------------------------------------------------- painting
YY, XX = np.mgrid[0:S, 0:S].astype(np.float32)


def arr(m):
    return np.asarray(m, np.float32) / 255


def gradient(m, c1, c2, angle):
    box = m.getbbox() or (0, 0, S, S)
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    corners = [(x, y) for x in (box[0], box[2]) for y in (box[1], box[3])]
    proj = [x * ux + y * uy for x, y in corners]
    lo, hi = min(proj), max(proj)
    t = np.clip((XX * ux + YY * uy - lo) / max(hi - lo, 1), 0, 1)[..., None]
    return np.array(c1, np.float32) * (1 - t) + np.array(c2, np.float32) * t


def bevel(m, radius, strength):
    h = arr(m.filter(ImageFilter.GaussianBlur(radius)))
    gy, gx = np.gradient(h)
    return np.clip((gx + gy) * radius * 2.2 * strength, -1, 1)[..., None]


class Icon:
    def __init__(self, element, seed=1, rays=False):
        self.p = PALETTES[element]
        self.items = []
        self.seed = seed
        self.rays = rays

    def colors(self, fill):
        if fill == "sym":
            return self.p["sym"]
        if isinstance(fill, str):
            return MATERIALS[fill]
        return fill

    def add(self, m, fill="sym", angle=110, shade=0.55, outline=7, glow=True, alpha=1.0):
        self.items.append(("solid", m, self.colors(fill), angle, shade, outline, glow, alpha))
        return m

    def energy(self, m, color=None, core=(255, 255, 255), blur=14, strength=1.0, core_strength=1.0):
        """Additive light: a coloured haze plus a hot core."""
        self.items.append(("energy", m, color or self.p["glow"], core, blur, strength, core_strength))
        return m

    def dark(self, m, alpha=0.75, color=OUTLINE):
        """A flat dark detail (cracks, grooves, sockets)."""
        self.items.append(("dark", m, color, alpha))
        return m

    def background(self):
        centre, edge = (np.array(c, np.float32) for c in self.p["bg"])
        r = np.sqrt((XX - C) ** 2 + (YY - S * 0.44) ** 2) / (S * 0.72)
        t = np.clip(r, 0, 1)[..., None] ** 1.25
        img = centre * (1 - t) + edge * t
        rng = np.random.default_rng(self.seed)
        cloud = Image.fromarray((rng.random((S // 16, S // 16)) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
        cloud = arr(cloud.filter(ImageFilter.GaussianBlur(10)))[..., None] - 0.5
        grain = rng.normal(0, 1, (S, S, 1)).astype(np.float32)
        img = img * (1 + cloud * 0.35) + grain * 3
        if self.rays:
            angle = np.arctan2(YY - C, XX - C)
            streak = (0.5 + 0.5 * np.cos(angle * 14)) ** 6 * np.clip(1 - r, 0, 1)
            img += streak[..., None] * np.array(self.p["glow"], np.float32) * 0.22
        return img

    def render(self):
        img = self.background()
        glow_mask = mask()
        for item in self.items:
            if item[0] == "solid" and item[6]:
                glow_mask = union(glow_mask, item[1])
        halo = arr(glow_mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(26)))[..., None]
        img = img + halo * np.array(self.p["glow"], np.float32) * 0.85
        for item in self.items:
            kind, m = item[0], item[1]
            if kind == "solid":
                _, m, (c1, c2), angle, shade, outline, _, alpha = item
                a = arr(m)[..., None] * alpha
                if outline:
                    size = outline if outline % 2 else outline + 1
                    o = arr(m.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.GaussianBlur(1.2)))[..., None] * alpha
                    img = img * (1 - o * 0.92) + np.array(OUTLINE, np.float32) * o * 0.92
                fill = gradient(m, c1, c2, angle)
                if shade:
                    b = bevel(m, 9, shade)
                    fill = fill * (1 + b * 0.35) + np.clip(b, 0, 1) * 70
                img = img * (1 - a) + fill * a
            elif kind == "energy":
                _, m, color, core, blur, strength, core_strength = item
                haze = arr(m.filter(ImageFilter.GaussianBlur(blur)))[..., None]
                hot = arr(m.filter(ImageFilter.GaussianBlur(1.5)))[..., None]
                img = img + haze * np.array(color, np.float32) * 1.2 * strength
                img = img * (1 - hot * core_strength) + np.array(core, np.float32) * hot * core_strength
            elif kind == "dark":
                _, m, color, alpha = item
                a = arr(m.filter(ImageFilter.GaussianBlur(1)))[..., None] * alpha
                img = img * (1 - a) + np.array(color, np.float32) * a
        # Vignette and a thin dark rim, so icons sit well in any socket.
        r = np.sqrt((XX - C) ** 2 + (YY - C) ** 2) / (S * 0.5)
        img *= (1 - np.clip(r - 0.78, 0, 1) * 0.9)[..., None]
        edge = np.minimum(np.minimum(XX, YY), np.minimum(S - 1 - XX, S - 1 - YY))
        img *= np.clip(edge / 10, 0.35, 1)[..., None]
        img = np.clip(img, 0, 255).astype(np.uint8)
        return Image.fromarray(img, "RGB")


# Shared parts ----------------------------------------------------------------
def sword(icon, cx, cy, length, angle, blade="metal", guard="gold", width=34):
    """A sword pointing up (angle 0) with its centre near (cx, cy)."""
    top = cy - length * 0.55
    gy = cy + length * 0.22
    blade_pts = [(cx - width / 2, gy), (cx - width / 2, top + width), (cx, top), (cx + width / 2, top + width), (cx + width / 2, gy)]
    guard_pts = rrect(cx - width * 1.9, gy, cx + width * 1.9, gy + width * 0.62, 8)
    grip_pts = rrect(cx - width * 0.32, gy + width * 0.6, cx + width * 0.32, cy + length * 0.42, 6)
    icon.add(poly(rot(grip_pts, angle, (cx, cy))), "wood", angle=0)
    icon.add(poly(rot(blade_pts, angle, (cx, cy))), blade, angle=angle + 180)
    icon.dark(line(rot([(cx, gy - 6), (cx, top + width * 1.3)], angle, (cx, cy)), 4), 0.35)
    icon.add(poly(rot(guard_pts, angle, (cx, cy))), guard, angle=90)
    p = rot([(cx, cy + length * 0.45)], angle, (cx, cy))[0]
    icon.add(circle(p[0], p[1], width * 0.42), guard)


def fist_side(icon, x, y, scale=1.0, fill="metal", alpha=1.0, outline=7):
    """A gauntleted fist, side view, punching right; (x, y) is its centre."""
    s = scale
    cuff = rrect(x - 150 * s, y - 52 * s, x - 50 * s, y + 52 * s, 10 * s)
    hand = rrect(x - 66 * s, y - 70 * s, x + 74 * s, y + 66 * s, 34 * s)
    thumb = rrect(x - 50 * s, y + 6 * s, x + 46 * s, y + 46 * s, 20 * s)
    icon.add(poly(cuff), "steel", angle=90, alpha=alpha, outline=outline)
    icon.add(poly(hand), fill, angle=100, alpha=alpha, outline=outline)
    for i in range(3):
        icon.dark(line([(x + 10 * s, y - 40 * s + i * 30 * s), (x + 66 * s, y - 40 * s + i * 30 * s)], 4 * s), 0.45 * alpha)
    icon.add(poly(thumb), fill, angle=100, alpha=alpha, outline=outline)
    for i in range(2):
        icon.dark(line([(x - 130 * s + i * 40 * s, y - 40 * s), (x - 130 * s + i * 40 * s, y + 40 * s)], 5 * s), 0.4 * alpha)


def shield_pts(cx, top, w, h):
    left = bezier((cx - w / 2, top + h * 0.45), (cx - w / 2, top + h * 0.85), (cx, top + h))
    right = bezier((cx, top + h), (cx + w / 2, top + h * 0.85), (cx + w / 2, top + h * 0.45))
    return [(cx - w / 2, top)] + left + right + [(cx + w / 2, top)]


def sparks(icon, cx, cy, spread, count, size, seed, color=None):
    rng = random.Random(seed)
    m = mask()
    d = ImageDraw.Draw(m)
    for _ in range(count):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.3, 1) * spread
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        s = rng.uniform(0.4, 1) * size
        d.ellipse((x - s, y - s, x + s, y + s), fill=255)
    icon.energy(m, color, blur=6)


def speed_lines(icon, lines, w=6, color=None):
    m = mask()
    for a, b in lines:
        m = union(m, line([a, b], w))
    icon.energy(m, color, blur=8, core_strength=0.8)


def snowflake(cx, cy, r, w, branches=True, spin=0):
    m = mask()
    for k in range(6):
        a = math.radians(spin + k * 60)
        tip = (cx + r * math.cos(a), cy + r * math.sin(a))
        m = union(m, line([(cx, cy), tip], w))
        if branches:
            for f, bl in ((0.45, 0.32), (0.72, 0.24)):
                bx, by = cx + r * f * math.cos(a), cy + r * f * math.sin(a)
                for side in (-1, 1):
                    b = a + side * math.radians(48)
                    m = union(m, line([(bx, by), (bx + r * bl * math.cos(b), by + r * bl * math.sin(b))], w * 0.75))
    return m


def shard(cx, cy, length, width, angle):
    pts = [(cx, cy - length / 2), (cx + width / 2, cy - length * 0.1), (cx + width * 0.3, cy + length / 2), (cx - width * 0.3, cy + length / 2), (cx - width / 2, cy - length * 0.1)]
    return rot(pts, angle, (cx, cy))


def faceted(icon, pts, light="ice", deep="icedeep", angle=100):
    """A crystal: the polygon plus a darker facet down one side."""
    icon.add(poly(pts), light, angle=angle)
    cx = sum(x for x, _ in pts) / len(pts)
    cy = sum(y for _, y in pts) / len(pts)
    half = [pts[0]] + [p for p in pts[1:] if p[0] >= cx - 1] + [(cx, cy)]
    if len(half) >= 3:
        icon.add(poly(half), deep, angle=angle, outline=0, glow=False, shade=0.2, alpha=0.75)


# ------------------------------------------------------------------ icons
def HydraulicSlam():
    i = Icon("Rig", 11, rays=True)
    i.energy(union(arc(C, 470, 190, 200, 340, 12), arc(C, 470, 130, 210, 330, 9)), blur=12)
    i.add(poly(rrect(222, 32, 290, 168, 10)), "steel", angle=0)
    i.dark(line([(222, 80), (290, 80)], 6), 0.6)
    i.dark(line([(222, 120), (290, 120)], 6), 0.6)
    i.add(poly(rrect(150, 150, 362, 320, 44)), "metal", angle=100)
    for k, x in enumerate((184, 232, 280, 328)):
        i.add(circle(x, 330, 32), "metal", angle=110)
    i.add(poly(rrect(118, 190, 172, 300, 24)), "metal", angle=100)
    i.dark(line([(170, 214), (342, 214)], 5), 0.4)
    m = mask()
    d = ImageDraw.Draw(m)
    for pts in ([(256, 372), (232, 408), (244, 440)], [(200, 372), (164, 404)], [(312, 372), (352, 410), (360, 444)]):
        d.line(pts, fill=255, width=8, joint="curve")
    i.energy(m, blur=8)
    sparks(i, C, 390, 150, 26, 6, 3)
    return i


def ServoFlurry():
    i = Icon("Rig", 12)
    speed_lines(i, [((40, 150), (170, 150)), ((60, 186), (150, 186)), ((40, 300), (200, 300)), ((70, 340), (210, 340)), ((50, 380), (180, 380))])
    fist_side(i, 238, 170, 0.8, alpha=0.55, outline=5)
    fist_side(i, 300, 334, 1.0)
    burst = poly(star(416, 334, 8, 74, 26, spin=10, jitter=0.2, seed=4))
    i.energy(burst, blur=16)
    burst2 = poly(star(356, 168, 7, 52, 18, spin=5, jitter=0.2, seed=5))
    i.energy(burst2, blur=12, strength=0.7)
    return i


def KineticRam():
    i = Icon("Rig", 13)
    for r, w in ((170, 16), (214, 12), (258, 8)):
        i.energy(arc(206, 256, r, -42, 42, w), blur=12)
    pts = shield_pts(206, 92, 220, 320)
    i.add(poly(pts), "steel", angle=110)
    inner = shield_pts(206, 116, 172, 270)
    i.add(poly(inner), "metal", angle=120, outline=4)
    i.add(circle(206, 230, 40), "gold", angle=120)
    i.energy(circle(206, 230, 14), blur=12)
    return i


def StimDodge():
    i = Icon("Rig", 14)

    def syringe(dx, dy, alpha, outline):
        body = rrect(150, 222, 330, 290, 12)
        plunger = [(70, 238), (150, 238), (150, 274), (70, 274)]
        cap = rrect(52, 214, 82, 298, 8)
        tip = [(330, 240), (366, 248), (366, 264), (330, 272)]
        needle = [(366, 252), (468, 256), (366, 260)]
        for pts, mat in ((plunger, "steel"), (cap, "metal"), (tip, "steel"), (needle, "metal"), (body, "glass")):
            i.add(poly(rot(move(pts, dx, dy), -40)), mat, angle=90, alpha=alpha, outline=outline)
        if alpha >= 1:
            liquid = rrect(176, 232, 318, 280, 8)
            i.add(poly(rot(liquid, -40)), "heal", angle=90, outline=0, glow=False)
            for x in (200, 236, 272):
                i.dark(line(rot([(x, 224), (x, 240)], -40), 4), 0.6)
            i.energy(poly(rot(rrect(184, 238, 310, 248, 5), -40)), (120, 255, 170), blur=6, core_strength=0.6)

    syringe(-70, 70, 0.28, 0)
    syringe(-36, 36, 0.45, 0)
    syringe(0, 0, 1.0, 7)
    sparks(i, 360, 140, 40, 8, 6, 9, (120, 255, 170))
    return i


def BreachHammer():
    i = Icon("Rig", 15, rays=True)
    i.energy(poly(star(318, 176, 10, 170, 60, spin=8, jitter=0.25, seed=2)), blur=22, strength=0.8, core_strength=0.15)
    handle = rrect(244, 170, 276, 470, 10)
    i.add(poly(rot(handle, 40, (256, 256))), "wood", angle=0)
    for y in (360, 396, 432):
        i.dark(line(rot([(244, y), (276, y)], 40, (256, 256)), 6), 0.6)
    head = rrect(150, 108, 330, 196, 12)
    spike = [(330, 122), (392, 152), (330, 182)]
    pts_c = (256, 256)
    i.add(poly(rot(spike, 40, pts_c)), "steel", angle=90)
    i.add(poly(rot(head, 40, pts_c)), "metal", angle=100)
    i.add(poly(rot(rrect(132, 100, 170, 204, 8), 40, pts_c)), "gold", angle=100)
    i.dark(line(rot([(206, 112), (206, 192)], 40, pts_c), 6), 0.5)
    i.dark(line(rot([(270, 112), (270, 192)], 40, pts_c), 6), 0.5)
    return i


def ArmorPiercer():
    i = Icon("Rig", 16)
    plate = rrect(118, 118, 394, 394, 46)
    i.add(poly(rot(plate, 12)), "steel", angle=110)
    i.add(poly(rot(rrect(150, 150, 362, 362, 30), 12)), "metal", angle=120, outline=4)
    for (x, y) in ((176, 176), (336, 176), (176, 336), (336, 336)):
        p = rot([(x, y)], 12)[0]
        i.add(circle(p[0], p[1], 10), "gold", outline=4, glow=False)
    m = mask()
    d = ImageDraw.Draw(m)
    for a in range(0, 360, 51):
        r = 110 + (a % 3) * 18
        d.line([(276, 236), (276 + r * math.cos(math.radians(a)), 236 + r * math.sin(math.radians(a)))], fill=255, width=5)
    i.dark(m, 0.7)
    i.dark(circle(276, 236, 30), 0.9)
    beam = poly([(30, 470), (60, 486), (300, 230), (276, 214)])
    i.energy(beam, (255, 170, 80), blur=12)
    tip = poly([(256, 250), (318, 170), (296, 244)])
    i.energy(union(beam, tip), (255, 200, 120), blur=20, strength=0.6)
    i.energy(poly(star(290, 224, 6, 60, 14, spin=20, seed=7)), blur=10)
    return i


def PneumaticJab():
    i = Icon("Rig", 17)
    speed_lines(i, [((24, 230), (100, 230)), ((34, 280), (110, 280)), ((24, 330), (90, 330))])
    fist_side(i, 236, 280, 0.95)
    i.energy(poly(star(372, 276, 8, 56, 16, spin=14, jitter=0.3, seed=11)), blur=12)
    i.add(ring(372, 160, 62, 18), ((255, 120, 100), (210, 40, 40)), outline=6)
    i.add(poly(rot(rrect(366, 92, 378, 228, 5), 45, (372, 160))), ((255, 120, 100), (210, 40, 40)), outline=6)
    return i


def ThrusterLeap():
    i = Icon("Rig", 18)
    path = bezier((128, 290), (250, -60), (380, 300), 48)
    m = mask()
    d = ImageDraw.Draw(m)
    for k in range(0, len(path) - 3, 6):
        m = union(m, line(path[k : k + 4], 12))
    i.energy(m, blur=8, core_strength=0.9)
    (x0, y0), (x1, y1) = path[-3], path[-1]
    a = math.atan2(y1 - y0, x1 - x0)
    tip = (x1 + 30 * math.cos(a), y1 + 30 * math.sin(a))
    back = lambda side: (x1 - 26 * math.cos(a) + side * 30 * math.sin(a), y1 - 26 * math.sin(a) - side * 30 * math.cos(a))
    i.add(poly([tip, back(1), back(-1)]), "metal", angle=90)
    i.energy(union(arc(400, 470, 100, 200, 340, 12), arc(400, 470, 60, 210, 330, 9)), blur=10)
    sparks(i, 400, 420, 80, 12, 5, 18)
    # The thruster pack, firing as it takes off.
    for x in (100, 156):
        i.energy(poly(flame(x, 430, 40, -110, wave=0.15)), (255, 150, 50), blur=16)
        i.add(poly(flame(x, 436, 24, -70, wave=0.1)), "lava", outline=0, glow=False, shade=0)
    i.add(poly(rrect(70, 300, 186, 418, 22)), "metal", angle=100)
    i.add(poly(rrect(92, 324, 164, 390, 10)), "steel", angle=100, outline=4)
    for x in (100, 156):
        i.add(poly([(x - 22, 410), (x + 22, 410), (x + 16, 446), (x - 16, 446)]), "steel", angle=90)
    i.add(circle(128, 356, 16), "gold", outline=4)
    return i


def RiposteStance():
    i = Icon("Rig", 19, rays=True)
    sword(i, C, 262, 330, -38)
    sword(i, C, 262, 330, 38)
    i.energy(band(C, 300, 196, 200, 340, 6, 22), blur=14)
    i.energy(poly(star(C, 196, 8, 46, 12, spin=0, jitter=0.2, seed=19)), blur=12)
    return i


def ThermalBurst():
    i = Icon("Fire", 21, rays=True)
    i.add(poly(star(C, C, 14, 210, 120, jitter=0.18, seed=21)), "lava", angle=90, shade=0.3)
    i.add(poly(star(C, C, 12, 150, 88, spin=12, jitter=0.2, seed=22)), ((255, 236, 150), (255, 150, 40)), outline=0, shade=0.2)
    i.energy(circle(C, C, 62), (255, 210, 120), blur=30)
    i.energy(circle(C, C, 38), blur=12)
    sparks(i, C, C, 230, 20, 7, 23)
    return i


def EmberLance():
    i = Icon("Fire", 22)
    # A comet of fire trailing behind the spearhead.
    for off, w, h, wave in ((-46, 70, 230, 0.35), (46, 70, 250, -0.35), (0, 120, 360, 0.22)):
        x, y = 330 + off * 0.707, 182 + off * 0.707
        i.add(poly(rot(flame(x, y, w, h, wave=wave), 225, (x, y))), ((255, 200, 80), (200, 40, 10)), angle=45, shade=0.3, outline=5)
    i.add(poly(rot(flame(330, 182, 64, 230, wave=0.25), 225, (330, 182))), ((255, 252, 220), (255, 180, 50)), angle=45, outline=0, glow=False, shade=0.2)
    head = [(312, 200), (296, 150), (446, 66), (362, 216)]
    i.add(poly(head), ((255, 255, 236), (255, 196, 70)), angle=135)
    i.add(poly([(312, 200), (446, 66), (362, 216)]), ((255, 210, 120), (230, 110, 20)), angle=135, outline=0, glow=False, alpha=0.7)
    i.add(poly(rot(rrect(286, 186, 350, 214, 8), -45, (318, 200))), "gold", angle=90)
    i.energy(poly([(330, 182), (446, 66), (340, 194)]), blur=12, core_strength=0.5)
    sparks(i, 170, 340, 140, 22, 6, 24)
    return i


def SolarFlare():
    i = Icon("Fire", 23, rays=True)
    i.add(poly(star(C, C, 12, 220, 104, spin=15)), ((255, 220, 120), (255, 120, 20)), angle=90, shade=0.3)
    i.add(poly(star(C, C, 12, 170, 104, spin=0)), ((255, 240, 170), (255, 160, 40)), angle=90, shade=0.3, outline=5)
    i.add(circle(C, C, 98), ((255, 255, 220), (255, 190, 50)), angle=110)
    i.energy(ellipse(C, C, 240, 10), blur=14)
    i.energy(ellipse(C, C, 10, 160), blur=12, strength=0.6)
    i.energy(circle(C, C, 44), blur=30)
    i.energy(ring(360, 350, 26, 5), blur=6, core_strength=0.6)
    return i


def Supernova():
    i = Icon("Fire", 24, rays=True)
    for k in range(10):
        a = k * 36
        x, y = C + 196 * math.cos(math.radians(a)), C + 196 * math.sin(math.radians(a))
        i.add(poly(rot(flame(x, y + 20, 46, 86), a + 90, (x, y))), "lava", outline=5, shade=0.3)
    i.add(poly(star(C, C, 16, 170, 120, jitter=0.15, seed=25)), ((255, 220, 120), (230, 70, 20)), shade=0.3)
    i.add(circle(C, C, 98), ((255, 255, 236), (255, 170, 40)), angle=120)
    i.energy(sub(ellipse(C, C, 220, 70), ellipse(C, C, 200, 52)).rotate(-20, center=(C, C)), blur=12)
    i.energy(circle(C, C, 50), blur=36)
    return i


def CinderDrill():
    i = Icon("Fire", 25)
    i.energy(poly([(400, 240), (512, 250), (512, 270), (400, 280)]), blur=14)
    cone = [(104, 160), (104, 360), (420, 262), (420, 258)]
    i.add(poly(rrect(52, 196, 112, 324, 10)), "steel", angle=90)
    i.add(poly(cone), ((255, 236, 170), (220, 70, 20)), angle=0)
    m = mask()
    d = ImageDraw.Draw(m)
    for x in (130, 190, 250, 310, 370):
        h = 100 * (420 - x) / 316
        d.line([(x, 260 - h), (x + 40, 260 + h * 0.75)], fill=255, width=8)
    i.dark(inter(m, poly(cone)), 0.6)
    i.energy(poly([(330, 236), (430, 260), (330, 284)]), blur=16)
    sparks(i, 440, 260, 70, 22, 6, 26)
    return i


def FurnaceCrescent():
    i = Icon("Fire", 26, rays=True)
    crescent = sub(circle(C, C, 196), circle(C + 64, C - 40, 176))
    for k in range(7):
        a = 110 + k * 22
        x, y = C + 186 * math.cos(math.radians(a)), C + 186 * math.sin(math.radians(a))
        i.add(poly(rot(flame(x, y + 10, 40, 92 - abs(k - 3) * 10, wave=0.1), a + 90, (x, y))), "lava", outline=5, shade=0.3)
    i.add(crescent, ((255, 250, 200), (255, 96, 10)), angle=135)
    i.energy(sub(circle(C, C, 160), circle(C + 50, C - 30, 160)), blur=10, strength=0.6, core_strength=0.25)
    sparks(i, 340, 330, 110, 16, 6, 27)
    return i


def MagmaFault():
    i = Icon("Fire", 27)
    left = [(40, 300), (230, 270), (210, 330), (250, 380), (200, 470), (40, 470)]
    right = [(270, 260), (472, 290), (472, 470), (240, 470), (290, 380), (250, 330)]
    crack = poly([(230, 270), (270, 260), (250, 330), (290, 380), (240, 470), (200, 470), (250, 380), (210, 330)])
    i.energy(crack, (255, 140, 30), blur=22)
    i.add(crack, "lava", angle=90, outline=0, shade=0.2)
    i.add(poly(left), "darkrock", angle=100)
    i.add(poly(right), "darkrock", angle=80)
    i.dark(line([(80, 360), (150, 340), (170, 400)], 5), 0.5)
    i.dark(line([(350, 330), (420, 360), (400, 420)], 5), 0.5)
    for (x, h, w) in ((250, 230, 90), (200, 150, 52), (306, 170, 56)):
        i.add(poly(flame(x, 300, w, h, wave=0.12)), "lava", outline=5, shade=0.3)
    for (x, y, r) in ((150, 120, 18), (360, 100, 14), (400, 190, 12), (120, 210, 10)):
        i.add(circle(x, y, r), "lava", outline=4)
    return i


def SolarExecution():
    i = Icon("Fire", 28, rays=True)
    i.add(poly(star(C, 220, 12, 200, 130, spin=15)), ((255, 220, 120), (255, 110, 20)), angle=90, shade=0.3)
    i.add(circle(C, 220, 128), ((255, 250, 200), (255, 150, 30)), angle=100)
    i.energy(circle(C, 220, 70), blur=30, core_strength=0.2)
    # The executioner's lance, point down.
    blade = [(226, 120), (286, 120), (286, 360), (C, 470), (226, 360)]
    i.add(poly(blade), ((255, 255, 236), (255, 200, 80)), angle=0)
    i.dark(line([(C, 130), (C, 400)], 5), 0.35)
    i.add(poly(rrect(176, 86, 336, 124, 10)), "gold", angle=90)
    i.add(poly(rrect(238, 24, 274, 90, 8)), "wood", angle=0)
    i.energy(ellipse(C, 470, 120, 14), blur=14)
    return i


def CryoLance():
    i = Icon("Frost", 31)
    shaft = poly([(100, 432), (122, 452), (330, 220), (310, 200)])
    i.add(shaft, "icedeep", angle=135)
    head = [(300, 210), (300, 156), (440, 72), (356, 212)]
    i.add(poly(head), "ice", angle=135)
    i.add(poly([(300, 210), (440, 72), (356, 212)]), "icedeep", outline=0, glow=False, alpha=0.6)
    for (x, y) in ((150, 380), (206, 318), (262, 256)):
        i.add(poly(shard(x, y, 70, 30, -45)), "ice", outline=5)
    i.energy(snowflake(420, 380, 44, 8, branches=False), blur=8)
    sparks(i, 380, 120, 80, 14, 5, 31)
    return i


def CryoStream():
    i = Icon("Frost", 32)
    m = mask()
    for k, off in enumerate((-50, 0, 50)):
        pts = [(150 + t * 340, 256 + off * (0.4 + t) + 22 * math.sin(t * 12 + k)) for t in np.linspace(0, 1, 40)]
        m = union(m, line(pts, 14 - k * 2 if k != 1 else 18))
    i.energy(m, blur=16)
    i.add(poly(rrect(36, 196, 150, 316, 20)), "steel", angle=90)
    i.add(poly([(140, 214), (196, 232), (196, 280), (140, 298)]), "metal", angle=90)
    i.add(circle(92, 256, 26), "icedeep")
    for (x, y, r) in ((300, 160, 30), (400, 330, 36), (440, 170, 24)):
        i.energy(snowflake(x, y, r, 6, branches=False), blur=6)
    return i


def CryoShield():
    i = Icon("Frost", 33, rays=True)
    hexa = [(C + 196 * math.cos(math.radians(a)), C + 196 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    i.add(poly(hexa), "icedeep", angle=110)
    for k in range(6):
        a, b = hexa[k], hexa[(k + 1) % 6]
        tri = [(C, C), a, b]
        fill = "ice" if k % 2 == 0 else "icedeep"
        i.add(poly(tri), fill, angle=60 * k, outline=3, glow=False, shade=0.3)
    i.add(circle(C, C, 52), "ice", angle=110)
    i.energy(snowflake(C, C, 40, 6, branches=False), blur=6, core_strength=0.8)
    i.dark(line([(330, 200), (380, 240), (372, 290)], 4), 0.5)
    return i


def AbsoluteZero():
    i = Icon("Frost", 34, rays=True)
    i.energy(ring(C, C, 200, 10), blur=14, strength=0.7)
    i.add(snowflake(C, C, 200, 26), "ice", angle=110)
    hexa = [(C + 56 * math.cos(math.radians(a)), C + 56 * math.sin(math.radians(a))) for a in range(0, 360, 60)]
    i.add(poly(hexa), "icedeep")
    i.energy(circle(C, C, 22), blur=18)
    return i


def FrostNeedle():
    i = Icon("Frost", 35)
    for k, (x, y) in enumerate(((300, 150), (340, 270), (250, 370))):
        i.energy(line([(x - 230, y + 170), (x - 60, y + 40)], 6), blur=10, strength=0.7, core_strength=0.5)
        needle = [(x + 110, y - 80), (x - 70, y + 66), (x - 84, y + 48)]
        i.add(poly(needle), "ice", angle=140, outline=6)
        i.add(poly([(x + 110, y - 80), (x - 6, y + 20), (x + 6, y + 6)]), "icedeep", outline=0, glow=False)
    sparks(i, 380, 140, 60, 10, 5, 35)
    return i


def GlacierFan():
    i = Icon("Frost", 36)
    for k, a in enumerate((-62, -31, 0, 31, 62)):
        L = 300 - abs(k - 2) * 30
        x = C + (L / 2 + 30) * math.sin(math.radians(a))
        y = 430 - (L / 2 + 30) * math.cos(math.radians(a))
        faceted(i, shard(x, y, L, 64, a), angle=a + 90)
    i.add(band(C, 430, 70, 200, 340, 34, 34), "icedeep", angle=90)
    i.energy(ellipse(C, 448, 140, 16), blur=16)
    return i


def PermafrostSpire():
    i = Icon("Frost", 37, rays=True)
    i.energy(ellipse(C, 420, 210, 40), blur=24)
    for (x, L, w, a) in ((160, 190, 70, -16), (352, 210, 74, 14), (110, 110, 46, -30), (402, 120, 46, 28)):
        faceted(i, shard(x, 420 - L / 2, L, w, a), angle=a + 90)
    faceted(i, [(C, 36), (316, 200), (300, 430), (212, 430), (196, 200)])
    i.add(poly([(40, 420), (472, 420), (440, 478), (72, 478)]), "icedeep", angle=90)
    sparks(i, C, 200, 160, 16, 5, 37)
    return i


def ShatterCrown():
    i = Icon("Frost", 38, rays=True)
    for k, (x, L) in enumerate(((128, 150), (192, 200), (256, 250), (320, 200), (384, 150))):
        faceted(i, shard(x, 330 - L / 2, L, 64, (k - 2) * 9), angle=100)
    i.add(poly(rrect(100, 300, 412, 370, 18)), "icedeep", angle=90)
    i.add(poly([(C, 312), (C + 26, 336), (C, 360), (C - 26, 336)]), ((255, 200, 255), (160, 80, 220)))
    for (x, y, a) in ((96, 140, 30), (420, 120, -20), (430, 430, 50), (80, 430, -40)):
        i.add(poly(shard(x, y, 50, 24, a)), "ice", outline=5)
    return i


def AcidSpray():
    i = Icon("Poison", 41)
    rng = random.Random(41)
    for _ in range(26):
        t = rng.uniform(0.15, 1)
        a = math.radians(-45 + rng.uniform(-24, 24) * t)
        x, y = 150 + 330 * t * math.cos(a), 360 + 330 * t * math.sin(a)
        r = 8 + 20 * t * rng.uniform(0.6, 1)
        if 30 < x < 482 and 30 < y < 482:
            i.add(poly(rot(drop(x, y, r), 45 + 90, (x, y))), "acid", outline=4, shade=0.4)
    i.energy(poly([(150, 360), (420, 120), (470, 240)]), blur=40, strength=0.35, core_strength=0)
    body = rrect(40, 330, 180, 450, 30)
    i.add(poly(rot(body, -45, (110, 390))), "steel", angle=90)
    i.add(poly(rot(rrect(160, 366, 214, 414, 8), -45, (110, 390))), "metal", angle=90)
    i.add(circle(110, 390, 26), "acid")
    return i


def ArmorMelt():
    i = Icon("Poison", 42)
    top = 80
    pts = [(120, top), (392, top), (392, 290)]
    for k, x in enumerate(np.linspace(392, 120, 9)):
        y = 300 + (60 if k % 2 else 0) + (40 if k in (3, 6) else 0)
        pts.append((x, y))
    pts.append((120, 290))
    i.add(poly(pts), "steel", angle=100)
    i.add(poly(rrect(150, 110, 362, 250, 20)), "metal", angle=110, outline=4)
    i.add(poly([(120, 220), (392, 200), (392, 310), (120, 330)]), "acid", angle=100, outline=0, glow=False, alpha=0.75)
    for (x, y, r) in ((170, 420, 22), (290, 446, 26), (360, 392, 16), (230, 380, 14)):
        i.add(poly(drop(x, y, r)), "acid", outline=5)
    i.add(poly(drop(220, 120, 30)), "acid", outline=5)
    i.energy(ellipse(C, 470, 170, 16), blur=14)
    return i


def ToxicCloud():
    i = Icon("Poison", 43)
    i.add(ellipse(C, 420, 200, 44), "acid", angle=90)
    for (x, y, r) in ((180, 410, 12), (300, 420, 16), (360, 404, 9)):
        i.add(circle(x, y, r), ((255, 255, 210), (150, 230, 90)), outline=3, glow=False)
    cloud = union(circle(170, 220, 80), circle(256, 170, 104), circle(350, 220, 84), ellipse(C, 270, 200, 64))
    i.add(cloud, ((200, 240, 140), (60, 120, 40)), angle=100)
    for x in (190, 256, 322):
        i.energy(line([(x, 330), (x - 16, 370)], 8), blur=8, core_strength=0.6)
    i.dark(union(circle(214, 210, 18), circle(298, 210, 18)), 0.75)
    i.dark(line([(222, 268), (256, 252), (290, 268)], 8), 0.6)
    i.energy(poly(drop(420, 120, 22)), (255, 120, 140), blur=10, core_strength=0.6)
    return i


def BioCorrosion():
    i = Icon("Poison", 44, rays=True)
    m = mask()
    for k in range(3):
        a = math.radians(-90 + k * 120)
        cx, cy = C + 92 * math.cos(a), C + 92 * math.sin(a)
        outer = circle(cx, cy, 96)
        inner = circle(C + 120 * math.cos(a), C + 120 * math.sin(a), 70)
        m = union(m, sub(outer, inner))
    m = sub(m, circle(C, C, 40))
    m = union(m, ring(C, C, 116, 22))
    m = sub(m, ring(C, C, 116, 0))
    i.add(m, "acid", angle=110)
    i.add(ring(C, C, 30, 18), "acid")
    for (x, y, r) in ((70, 120, 18), (440, 110, 14), (448, 420, 20), (66, 410, 14), (C, 470, 12)):
        i.add(circle(x, y, r), "acid", outline=4)
    return i


def CausticDart():
    i = Icon("Poison", 45)
    speed_lines(i, [((40, 360), (150, 300)), ((70, 430), (190, 350))])
    body = rrect(150, 236, 340, 276, 18)
    i.add(poly(rot(body, -34)), "steel", angle=90)
    for dy in (-1, 1):
        fin = [(150, 256), (96, 256 + dy * 70), (196, 256 + dy * 6)]
        i.add(poly(rot(fin, -34)), ((240, 140, 160), (170, 40, 70)), angle=90)
    i.add(poly(rot([(336, 240), (470, 256), (336, 272)], -34)), "acid", angle=90)
    i.add(poly(rot(rrect(214, 240, 300, 272, 12), -34)), "acid", angle=90, outline=3, glow=False)
    tip = rot([(470, 256)], -34)[0]
    i.add(poly(drop(tip[0] + 10, tip[1] + 70, 18)), "acid", outline=5)
    i.energy(circle(tip[0], tip[1], 10), blur=12)
    return i


def VitriolSweep():
    i = Icon("Poison", 46)
    i.energy(band(240, 330, 200, 200, 300, 4, 44), blur=16, strength=0.8, core_strength=0.35)
    outer = bezier((196, 360), (440, 330), (428, 70), 30)
    inner = bezier((428, 70), (360, 280), (172, 320), 30)
    i.add(poly(outer + inner), "acid", angle=135)
    i.add(poly(bezier((206, 352), (400, 320), (420, 100), 20) + bezier((420, 100), (380, 300), (200, 336), 20)), ((250, 255, 220), (180, 240, 120)), outline=0, glow=False, alpha=0.6)
    i.add(poly(rot(rrect(150, 318, 196, 378, 10), 0, (173, 348))), "gold", angle=90)
    i.add(poly(rot(rrect(166, 360, 190, 470, 8), 35, (178, 365))), "wood", angle=0)
    i.add(poly(rot(rrect(140, 340, 230, 362, 8), 35, (185, 351))), "gold", angle=90)
    for (x, y, r) in ((330, 400, 18), (400, 360, 14), (280, 450, 12), (450, 260, 11)):
        i.add(poly(drop(x, y, r)), "acid", outline=4)
    return i


def LeechBloom():
    i = Icon("Poison", 47, rays=True)
    for k in range(6):
        a = k * 60
        petal = [(C, C), (C - 54, C - 120), (C, C - 200), (C + 54, C - 120)]
        i.add(poly(rot(petal, a)), ((210, 255, 150), (40, 130, 40)), angle=90 + a)
    for k in range(6):
        a = k * 60 + 30
        petal = [(C, C), (C - 36, C - 90), (C, C - 150), (C + 36, C - 90)]
        i.add(poly(rot(petal, a)), ((255, 170, 200), (150, 30, 90)), angle=90 + a, outline=5)
    i.add(circle(C, C, 56), ((120, 30, 50), (40, 6, 14)))
    m = mask()
    for k in range(8):
        a = k * 45
        m = union(m, poly(rot([(C - 9, C - 52), (C + 9, C - 52), (C, C - 24)], a)))
    i.add(m, "bone", outline=3, glow=False, shade=0.2)
    i.energy(poly(drop(C, C + 2, 14, up=False)), (255, 90, 110), blur=10, core_strength=0.7)
    return i


def Dissolution():
    i = Icon("Poison", 48)
    i.energy(poly([(220, 0), (292, 0), (276, 140), (236, 140)]), blur=18)
    skull = union(circle(C, 250, 120), poly(rrect(176, 290, 336, 400, 30)))
    i.add(skull, "bone", angle=100)
    i.dark(union(ellipse(210, 260, 34, 40), ellipse(302, 260, 34, 40)), 0.92)
    i.dark(poly([(C, 300), (C + 16, 336), (C - 16, 336)]), 0.9)
    for x in (214, 242, 270, 298):
        i.dark(line([(x, 362), (x, 398)], 6), 0.7)
    i.add(poly([(140, 150), (372, 150), (372, 210), (140, 230)]), "acid", angle=90, outline=0, glow=False, alpha=0.8)
    for (x, y, r) in ((180, 450, 18), (C, 470, 22), (330, 446, 16), (380, 330, 14), (132, 330, 14)):
        i.add(poly(drop(x, y, r)), "acid", outline=5)
    i.energy(ellipse(C, 150, 120, 18), blur=12)
    return i


def IonSpark():
    i = Icon("Shock", 51, rays=True)
    main = bolt([(300, 40), (196, 236), (290, 236), (180, 470)], 70, 10)
    i.add(main, "sym", angle=100)
    i.energy(bolt(zigzag((300, 260), (450, 320), 5, 16, 2), 12, 4), blur=12)
    i.add(circle(450, 320, 24), "sym", outline=5)
    sparks(i, 200, 450, 60, 12, 5, 51)
    return i


def StaticField():
    i = Icon("Shock", 52, rays=True)
    i.add(ring(C, C, 176, 20), ((220, 210, 255), (110, 90, 220)), angle=100)
    i.add(circle(C, C, 92), ((255, 255, 230), (255, 190, 40)), angle=110)
    i.energy(circle(C, C, 50), blur=26)
    for k in range(6):
        a0 = k * 60 + 10
        pts = [(C + (120 + 22 * ((j % 2) * 2 - 1)) * math.cos(math.radians(a0 + j * 8)), C + (120 + 22 * ((j % 2) * 2 - 1)) * math.sin(math.radians(a0 + j * 8))) for j in range(6)]
        i.energy(line(pts, 6), blur=10)
    return i


def ChainLightning():
    i = Icon("Shock", 53)
    nodes = [(110, 120), (390, 190), (140, 360), (400, 430)]
    for a, b, s in ((nodes[0], nodes[1], 1), (nodes[1], nodes[2], 2), (nodes[2], nodes[3], 3)):
        pts = zigzag(a, b, 7, 26, s)
        i.add(bolt(pts, 26, 14), "sym", angle=100, outline=6)
        i.energy(line(pts, 6), blur=14, core_strength=0.5)
    for (x, y) in nodes:
        i.add(circle(x, y, 34), ((230, 220, 255), (120, 90, 220)))
        i.energy(circle(x, y, 14), blur=12)
    return i


def Overload():
    i = Icon("Shock", 54, rays=True)
    i.energy(poly(star(C, 270, 12, 230, 130, jitter=0.3, seed=54)), blur=26, strength=0.6, core_strength=0.1)
    i.add(poly(rrect(150, 110, 362, 440, 30)), "steel", angle=90)
    i.add(poly(rrect(214, 70, 298, 116, 10)), "metal", angle=90)
    i.add(poly(rrect(178, 140, 334, 410, 18)), ((255, 250, 210), (255, 170, 30)), angle=90, outline=4)
    i.add(bolt([(280, 160), (220, 286), (290, 286), (230, 392)], 46, 10), ((255, 255, 255), (230, 220, 255)), outline=5)
    m = mask()
    d = ImageDraw.Draw(m)
    d.line([(150, 210), (186, 240), (170, 280)], fill=255, width=7)
    d.line([(362, 300), (330, 330), (346, 380)], fill=255, width=7)
    i.energy(m, blur=10)
    return i


def ArcNeedle():
    i = Icon("Shock", 55)
    needle = [(70, 420), (90, 440), (450, 80)]
    i.add(poly(needle), "metal", angle=135)
    i.add(poly(rot(rrect(60, 420, 120, 450, 8), -45, (90, 435))), "gold")
    path = []
    for t in np.linspace(0, 1, 60):
        x, y = 90 + 340 * t, 430 - 340 * t
        w = 40 * math.sin(t * 22)
        path.append((x + w * 0.7, y + w * 0.7))
    i.energy(line(path, 6), blur=12)
    i.add(ring(380, 360, 56, 14), ((255, 120, 100), (210, 40, 40)), outline=5)
    i.add(poly(rot(rrect(374, 300, 386, 420, 5), 45, (380, 360))), ((255, 120, 100), (210, 40, 40)), outline=5)
    return i


def CircuitCleave():
    i = Icon("Shock", 56)
    i.energy(band(C, C, 200, 190, 320, 4, 40), blur=16, strength=0.8, core_strength=0.4)
    blade = [(150, 400), (110, 360), (360, 80), (430, 70), (420, 140)]
    i.add(poly(blade), ((210, 220, 250), (70, 70, 120)), angle=135)
    m = mask()
    d = ImageDraw.Draw(m)
    for pts in ([(170, 350), (240, 280), (240, 230), (290, 180)], [(210, 340), (280, 270), (330, 270), (380, 140)]):
        d.line(pts, fill=255, width=6)
        for p in pts[1:]:
            d.ellipse((p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8), fill=255)
    i.energy(inter(m, poly(blade)), blur=8)
    i.add(poly(rot(rrect(60, 380, 200, 412, 8), -45, (130, 396))), "gold", angle=90)
    i.add(poly(rot(rrect(70, 410, 104, 480, 8), -45, (87, 430))), "dark", angle=0)
    return i


def ThunderPylon():
    i = Icon("Shock", 57, rays=True)
    i.energy(ellipse(C, 450, 200, 30), blur=20)
    for side in (-1, 1):
        i.energy(bolt(zigzag((C, 110), (C + side * 200, 440), 6, 24, 57 + side), 18, 4), blur=12)
    i.add(poly([(206, 470), (C, 120), (306, 470)]), "steel", angle=90)
    m = mask()
    d = ImageDraw.Draw(m)
    for y in (220, 300, 380, 450):
        hw = (y - 120) * 50 / 350
        d.line([(C - hw, y), (C + hw, y)], fill=255, width=6)
        d.line([(C - hw, y), (C + hw * 0.6, y - 60)], fill=255, width=5)
    i.dark(inter(m, poly([(206, 470), (C, 120), (306, 470)])), 0.6)
    i.add(circle(C, 110, 44), ((255, 255, 230), (255, 190, 40)))
    i.energy(circle(C, 110, 30), blur=24)
    return i


def Railstorm():
    i = Icon("Shock", 58)
    cloud = union(circle(130, 120, 64), circle(200, 92, 76), circle(270, 124, 60), ellipse(196, 150, 140, 44))
    i.add(cloud, ((150, 140, 200), (50, 40, 90)), angle=90)
    i.add(bolt([(170, 180), (140, 250), (184, 250), (150, 320)], 26, 6), "sym", outline=5)
    beam = poly([(150, 470), (190, 470), (480, 180), (480, 140)])
    i.energy(beam, blur=20)
    for off in (-40, 40):
        rail = poly([(130 + off, 452 + off), (156 + off, 476 + off), (466 + off, 166 + off), (440 + off, 140 + off)])
        i.add(rail, "steel", angle=135)
    for t in np.linspace(0.15, 0.85, 5):
        x, y = 150 + 320 * t, 460 - 300 * t
        i.add(circle(x - 40, y - 40, 10), "gold", outline=3, glow=False)
        i.add(circle(x + 40, y + 40, 10), "gold", outline=3, glow=False)
    return i


def EnergySiphon():
    i = Icon("Charge", 61, rays=True)
    for k in range(3):
        pts = []
        for t in np.linspace(0, 1, 60):
            a = math.radians(k * 120 + t * 300)
            r = 210 - t * 150
            pts.append((C + r * math.cos(a), C + r * math.sin(a)))
        i.energy(line(pts, 14 - k * 2), blur=12)
    i.add(circle(C, C, 70), ((230, 255, 255), (40, 180, 200)), angle=110)
    i.add(bolt([(270, 200), (236, 262), (276, 262), (240, 320)], 32, 8), ((255, 255, 255), (200, 250, 255)), outline=5)
    for k in range(5):
        a = math.radians(k * 72 + 20)
        x, y = C + 210 * math.cos(a), C + 210 * math.sin(a)
        tip = (C + 150 * math.cos(a), C + 150 * math.sin(a))
        i.add(poly([tip, (x - 26 * math.sin(a), y + 26 * math.cos(a)), (x + 26 * math.sin(a), y - 26 * math.cos(a))]), "sym", outline=5)
    return i


def ResonanceEcho():
    i = Icon("Charge", 62)
    for r, w in ((120, 10), (170, 8), (220, 6)):
        i.energy(ring(C, C, r, w), blur=10, strength=0.6, core_strength=0.4)
    for dx, alpha in ((-70, 0.3), (-35, 0.55)):
        blade = [(C - 20 + dx, 420), (C - 20 + dx, 120), (C + dx, 70), (C + 20 + dx, 120), (C + 20 + dx, 420)]
        i.add(poly(blade), "sym", alpha=alpha, outline=0, glow=False)
    sword(i, C + 30, 262, 360, 0, blade="metal")
    return i


def SeismicBreaker():
    i = Icon("Earth", 63, rays=True)
    crack = poly([(250, 300), (282, 300), (300, 380), (270, 420), (300, 500), (220, 500), (250, 420), (226, 380)])
    i.add(poly([(20, 320), (250, 300), (226, 380), (250, 420), (220, 500), (20, 500)]), "rock", angle=100)
    i.add(poly([(282, 300), (492, 330), (492, 500), (300, 500), (270, 420), (300, 380)]), "rock", angle=80)
    i.energy(crack, blur=14)
    for (x, y, r) in ((180, 260, 22), (340, 250, 18), (130, 210, 14), (390, 200, 12)):
        i.add(poly(star(x, y, 4, r, r * 0.7, spin=x, jitter=0.2, seed=x)), "rock", outline=5)
    handle = rrect(250, 40, 280, 300, 10)
    i.add(poly(rot(handle, 35, (265, 260))), "wood", angle=0)
    head = bezier((120, 140), (240, 30), (380, 110), 30)
    under = bezier((380, 110), (240, 70), (120, 140), 30)
    i.add(poly(rot(head + under, 35, (265, 260))), "metal", angle=100)
    return i


def TremorSlam():
    i = Icon("Earth", 64)
    for r, w in ((90, 12), (150, 10), (210, 8)):
        i.energy(sub(ellipse(C, 380, r * 1.1 + w, r * 0.32 + w), ellipse(C, 380, r * 1.1, r * 0.32)), blur=10)
    i.add(poly([(70, 380), (442, 380), (472, 470), (40, 470)]), "rock", angle=90)
    i.add(poly(rrect(150, 236, 362, 380, 34)), "metal", angle=100)
    for x in (184, 232, 280, 328):
        i.add(circle(x, 384, 30), "metal")
    for k in range(3):
        a = math.radians(-90 + (k - 1) * 46)
        x, y = C + 150 * math.cos(a) * 1.3, 190 + 70 * math.sin(a)
        i.add(poly(star(x, y - 40, 5, 34, 14, spin=k * 20)), ((255, 250, 180), (255, 190, 40)), outline=5)
    return i


def ResonantReaver():
    i = Icon("Resonance", 65, rays=True)
    i.energy(band(C, C, 190, 200, 350, 4, 34), blur=16, strength=0.8, core_strength=0.35)
    i.add(poly(rot(rrect(236, 60, 268, 480, 10), 20, (252, 270))), "wood", angle=0)
    blade = sub(circle(250, 190, 170), circle(250, 240, 172))
    blade = inter(blade, poly([(40, 0), (262, 0), (262, 260), (40, 260)]))
    i.add(blade.rotate(-20, center=(252, 270)), "violet", angle=135)
    heart = union(circle(366, 360, 34), circle(414, 360, 34), poly([(336, 376), (444, 376), (390, 440)]))
    i.add(heart, "blood", angle=100)
    i.energy(line([(390, 330), (360, 260), (300, 230)], 8), (255, 120, 170), blur=10, core_strength=0.6)
    return i


def NullPrism():
    i = Icon("Resonance", 66, rays=True)
    i.energy(poly([(0, 300), (0, 316), (210, 268), (206, 252)]), (255, 255, 255), blur=10)
    for k, color in enumerate(((255, 90, 90), (255, 200, 60), (90, 255, 120), (80, 180, 255), (200, 90, 255))):
        y = 200 + k * 44
        i.energy(poly([(300, 250 + k * 6), (512, y - 10), (512, y + 12), (300, 258 + k * 6)]), color, blur=10, core_strength=0.5)
    tri = [(C, 74), (412, 370), (100, 370)]
    i.add(poly(tri), ((255, 240, 255), (170, 100, 240)), angle=100)
    i.add(poly([(C, 74), (C, 370), (100, 370)]), "violet", outline=0, glow=False, alpha=0.55)
    i.add(ring(C, 452, 40, 12), "violet", outline=4)
    i.add(poly(rot(rrect(250, 404, 262, 500, 4), 45, (C, 452))), "violet", outline=4)
    return i


ORDER = [
    "HydraulicSlam", "ServoFlurry", "KineticRam", "StimDodge", "BreachHammer", "ArmorPiercer", "PneumaticJab", "ThrusterLeap",
    "RiposteStance", "ThermalBurst", "EmberLance", "SolarFlare", "Supernova", "EnergySiphon", "ResonanceEcho", "CryoLance",
    "CryoStream", "CryoShield", "SeismicBreaker", "TremorSlam", "AcidSpray", "ArmorMelt", "ToxicCloud", "BioCorrosion",
    "IonSpark", "StaticField", "ChainLightning", "Overload", "AbsoluteZero", "CinderDrill", "FurnaceCrescent", "MagmaFault",
    "SolarExecution", "FrostNeedle", "GlacierFan", "PermafrostSpire", "ShatterCrown", "CausticDart", "VitriolSweep", "LeechBloom",
    "Dissolution", "ArcNeedle", "CircuitCleave", "ThunderPylon", "Railstorm", "ResonantReaver", "NullPrism",
]


def main():
    rows = math.ceil(len(ORDER) / COLUMNS)
    sheet = Image.new("RGB", (COLUMNS * CELL, rows * CELL), (0, 0, 0))
    big = 192
    preview = Image.new("RGB", (COLUMNS * (big + 12) + 12, rows * (big + 40) + 12), (24, 26, 32))
    draw = ImageDraw.Draw(preview)
    for n, name in enumerate(ORDER):
        art = globals()[name]().render()
        x, y = n % COLUMNS, n // COLUMNS
        sheet.paste(art.resize((CELL, CELL), Image.LANCZOS), (x * CELL, y * CELL))
        preview.paste(art.resize((big, big), Image.LANCZOS), (12 + x * (big + 12), 12 + y * (big + 40)))
        draw.text((12 + x * (big + 12), 12 + y * (big + 40) + big + 6), name, fill=(220, 220, 220))
    images = os.path.join(ROOT, "assets", "images")
    sheet.save(os.path.join(images, "ability_icons.png"), optimize=True)
    preview.save(os.path.join(images, "ability_icons_preview.png"), optimize=True)
    lines = [
        "-- Generated by tools/make_ability_icons.py: where each ability's icon sits",
        "-- on assets/images/ability_icons.png. Don't edit by hand.",
        "return {",
        f"\tCell = {CELL},",
        f"\tColumns = {COLUMNS},",
        "\tIndex = {",
    ]
    lines += [f"\t\t{name} = {n}," for n, name in enumerate(ORDER)]
    lines += ["\t},", "}", ""]
    with open(os.path.join(ROOT, "src", "client", "Modules", "AbilityIconAtlas.luau"), "w", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"{len(ORDER)} icons -> ability_icons.png ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
