"""
Renders the key art for the lobby's PLAY menu cards from the game's own
fighters: Frontier-armoured Saga miners posed by RivalPose (exported by
tools/card_poses.luau as JSON), rasterised in
3D with a coloured backlight, rim light, glowing trims, bloom and a glossy
arena floor that reflects them.

    pip install numpy pillow
    python tools/make_lobby_cards.py <poses-dir>

<poses-dir> holds key_Sword.json (animshots.luau with the Sword and the
"stance" option: a planted lunge for every pose). Writes assets/images/lobby/<card>.png (2x the card) and
preview.png. Upload the five PNGs and put their ids in LobbyUI.Art.
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "images", "lobby")

GOLD = np.array((255, 190, 80), np.float32) / 255
TEAL = np.array((60, 210, 240), np.float32) / 255
AMETHYST = np.array((180, 95, 255), np.float32) / 255
EMERALD = np.array((40, 230, 160), np.float32) / 255
RED = np.array((255, 70, 70), np.float32) / 255


def unit(v):
    v = np.asarray(v, np.float32)
    return v / (np.linalg.norm(v) + 1e-9)


# ------------------------------------------------------------------ geometry
CUBE = np.array([[x, y, z] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)], np.float32)
CUBE_TRIS = [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]
WEDGE = np.array([(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5)], np.float32)
WEDGE_TRIS = [(0, 1, 2), (0, 2, 3), (3, 2, 5), (3, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5), (0, 5, 1)]


def sphere(stacks=7, slices=12):
    verts, tris = [], []
    for i in range(stacks + 1):
        phi = math.pi * i / stacks
        for j in range(slices):
            th = 2 * math.pi * j / slices
            verts.append((0.5 * math.sin(phi) * math.cos(th), 0.5 * math.cos(phi), 0.5 * math.sin(phi) * math.sin(th)))
    for i in range(stacks):
        for j in range(slices):
            a, b = i * slices + j, i * slices + (j + 1) % slices
            c, d = a + slices, b + slices
            tris += [(a, c, b), (b, c, d)]
    return np.array(verts, np.float32), tris


def cylinder(n=14):
    verts = [(x, 0.5 * math.cos(2 * math.pi * k / n), 0.5 * math.sin(2 * math.pi * k / n)) for x in (-0.5, 0.5) for k in range(n)]
    tris = []
    for k in range(n):
        a, b = k, (k + 1) % n
        tris += [(a, b, n + b), (a, n + b, n + a)]
        if 0 < k < n - 1:
            tris += [(0, k + 1, k), (n, n + k, n + k + 1)]
    return np.array(verts, np.float32), tris


SPHERE = sphere()
CYLINDER = cylinder()


def part_mesh(p):
    pos = np.array(p[0:3], np.float32)
    right, up, look = np.array(p[3:6]), np.array(p[6:9]), np.array(p[9:12])
    size = np.array(p[12:15], np.float32)
    shape = p[18]
    if shape == "Wedge":
        local, tris = WEDGE, WEDGE_TRIS
    elif shape == "Ball":
        local, tris = SPHERE
    elif shape == "Cylinder":
        local, tris = CYLINDER
    else:
        local, tris = CUBE, CUBE_TRIS
    scaled = local * size
    # Roblox: local +Z is -LookVector.
    world = pos + scaled[:, :1] * right + scaled[:, 1:2] * up - scaled[:, 2:3] * look
    return world, tris, pos


# --------------------------------------------------------------- the scene
class Scene:
    def __init__(self, w, h, eye, target, fov, accent, seed=1):
        self.w, self.h = w, h
        self.eye = np.array(eye, np.float32)
        self.forward = unit(np.array(target, np.float32) - self.eye)
        self.right = unit(np.cross(self.forward, (0, 1, 0)))
        self.up = np.cross(self.right, self.forward)
        self.focal = (h / 2) / math.tan(math.radians(fov) / 2)
        self.accent = accent
        self.color = np.zeros((h, w, 3), np.float32)
        self.depth = np.full((h, w), np.inf, np.float32)
        self.emit = np.zeros((h, w, 3), np.float32)
        self.rng = random.Random(seed)
        self.key = unit((0.2, 0.55, -1.0))  # a backlight, from behind the fighters
        self.fill = unit((-0.5, 0.35, 0.8))  # a soft light from the camera side
        self.reflect = None

    def project(self, pts):
        rel = pts - self.eye
        z = rel @ self.forward
        x = rel @ self.right
        y = rel @ self.up
        sx = self.w / 2 + x / np.maximum(z, 0.05) * self.focal
        sy = self.h / 2 - y / np.maximum(z, 0.05) * self.focal
        return np.stack([sx, sy, z], 1)

    def shade(self, base, normal, centre, neon, dim=1.0):
        if neon:
            return self.accent * 1.4, self.accent * 1.6
        view = unit(self.eye - centre)
        n = normal
        diffuse_fill = max(0.0, float(n @ self.fill)) * 0.38
        diffuse_key = max(0.0, float(n @ self.key))
        rim = (1 - max(0.0, float(n @ view))) ** 2.5 * (0.35 + 0.65 * max(0.0, float(n @ self.key) + 0.3))
        half = unit(self.key + view)
        spec = max(0.0, float(n @ half)) ** 24 * 0.9
        lit = base * (0.1 + diffuse_fill * np.array((0.75, 0.82, 1.0))) + base * diffuse_key * self.accent * 1.1
        lit = lit + self.accent * (rim * 1.25 + spec * 0.6) + np.array((1, 1, 1)) * spec * 0.25
        return lit * dim, None

    def triangle(self, p, color, emit, buffer_color, buffer_depth, buffer_emit):
        (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = p
        if min(z0, z1, z2) <= 0.05:
            return
        minx, maxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(self.w - 1, math.ceil(max(x0, x1, x2))))
        miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(self.h - 1, math.ceil(max(y0, y1, y2))))
        if minx > maxx or miny > maxy:
            return
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-6:
            return
        ys, xs = np.mgrid[miny : maxy + 1, minx : maxx + 1].astype(np.float32) + 0.5
        w0 = ((x1 - xs) * (y2 - ys) - (x2 - xs) * (y1 - ys)) / area
        w1 = ((x2 - xs) * (y0 - ys) - (x0 - xs) * (y2 - ys)) / area
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not inside.any():
            return
        z = w0 * z0 + w1 * z1 + w2 * z2
        region = buffer_depth[miny : maxy + 1, minx : maxx + 1]
        win = inside & (z < region)
        region[win] = z[win]
        buffer_color[miny : maxy + 1, minx : maxx + 1][win] = color
        if buffer_emit is not None:
            buffer_emit[miny : maxy + 1, minx : maxx + 1][win] = emit if emit is not None else 0

    def figure(self, parts, at, yaw, scale=1.0, mirror=False):
        feet = min(p[1] for p in parts) - 0.05
        c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        rotation = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], np.float32)
        offset = np.array((at[0], 0, at[1]), np.float32)
        for p in parts:
            world, tris, centre = part_mesh(p)
            world = (world - (0, feet, 0)) * scale @ rotation.T + offset
            centre = (centre - (0, feet, 0)) * scale @ rotation.T + offset
            if mirror:
                world = world * (1, -1, 1)
                centre = centre * (1, -1, 1)
            base = np.array(p[15:18], np.float32)
            neon = bool(p[19])
            # The kit's accent takes the card's colour.
            if not neon and base.max() - base.min() > 0.35 and base[2] > base[0]:
                base = self.accent * 0.75
            screen = self.project(world)
            for a, b, cidx in tris:
                n = np.cross(world[b] - world[a], world[cidx] - world[a])
                ln = np.linalg.norm(n)
                if ln < 1e-8:
                    continue
                n = n / ln
                tri_centre = (world[a] + world[b] + world[cidx]) / 3
                if np.dot(n, tri_centre - centre) < 0:
                    n = -n
                if np.dot(n, self.eye - tri_centre) <= 0:
                    continue  # back face
                col, emit = self.shade(base, n, tri_centre, neon, 0.45 if mirror else 1.0)
                if mirror:
                    self.triangle(screen[[a, b, cidx]], col, None, self.reflect[0], self.reflect[1], None)
                else:
                    self.triangle(screen[[a, b, cidx]], col, emit, self.color, self.depth, self.emit)

    def fighters(self, specs):
        """Each spec: (parts, (x, z), yaw). Reflections first, then the fighters."""
        self.reflect = (np.zeros_like(self.color), np.full_like(self.depth, np.inf))
        for parts, at, yaw in specs:
            self.figure(parts, at, yaw, mirror=True)
        for parts, at, yaw in specs:
            self.figure(parts, at, yaw)

    def block(self, centre, size, color, neon=False):
        part = list(centre) + [1, 0, 0, 0, 1, 0, 0, 0, -1] + list(size) + list(color) + ["Block", neon]
        world, tris, c = part_mesh(part)
        screen = self.project(world)
        for a, b, cidx in tris:
            n = unit(np.cross(world[b] - world[a], world[cidx] - world[a]))
            centre_t = (world[a] + world[b] + world[cidx]) / 3
            if np.dot(n, centre_t - c) < 0:
                n = -n
            if np.dot(n, self.eye - centre_t) <= 0:
                continue
            col, emit = self.shade(np.array(color, np.float32), n, centre_t, neon)
            self.triangle(screen[[a, b, cidx]], col, emit, self.color, self.depth, self.emit)

    # ------------------------------------------------------------ backdrop
    def backdrop(self, top, horizon_color, planet=None, shafts=()):
        h, w = self.h, self.w
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        # Rays through each pixel: the floor where they hit y = 0, the sky above.
        dirs = (
            self.forward[None, None, :] * self.focal
            + self.right[None, None, :] * (xx - w / 2)[..., None]
            - self.up[None, None, :] * (yy - h / 2)[..., None]
        )
        dirs /= np.linalg.norm(dirs, axis=2, keepdims=True)
        t = -self.eye[1] / np.where(dirs[..., 1] < -1e-4, dirs[..., 1], -1e-4)
        ground = dirs[..., 1] < -1e-4
        hit = self.eye[None, None, :] + dirs * t[..., None]
        sky_t = np.clip(dirs[..., 1] * 3 + 0.15, 0, 1)[..., None]
        sky = np.array(horizon_color, np.float32) * (1 - sky_t) + np.array(top, np.float32) * sky_t
        stars = np.zeros((h, w), np.float32)
        img = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(img)
        for _ in range(w * h // 1800):
            x, y = self.rng.uniform(0, w), self.rng.uniform(0, h * 0.75)
            r = self.rng.choice((0.6, 0.8, 1.0, 1.5))
            d.ellipse((x - r, y - r, x + r, y + r), fill=self.rng.randint(90, 255))
        stars = np.asarray(img, np.float32)[..., None] / 255 * (1 - ground[..., None])
        sky = sky + stars * 0.9
        if planet:
            px, py, pr, pc = planet
            r = np.sqrt((xx - px) ** 2 + (yy - py) ** 2)
            disc = np.clip(pr - r, 0, 1)[..., None]
            lightside = np.clip(0.3 + ((xx - px) * -0.6 + (yy - py) * -0.8) / pr * 0.7, 0.12, 1)[..., None]
            sky = sky * (1 - disc) + np.array(pc, np.float32) * lightside * disc
            sky += np.exp(-((r / (pr * 1.7)) ** 2))[..., None] * np.array(pc, np.float32) * 0.18
        for sx, width, strength in shafts:
            x0 = w * sx
            beam = np.exp(-(((xx - x0 - (yy * 0.12)) / (w * width)) ** 2)) * np.clip(1 - yy / (h * 0.9), 0, 1)
            sky += beam[..., None] * self.accent * strength
        # The floor: polished obsidian with a glowing grid, fading into haze.
        gx, gz = hit[..., 0], hit[..., 2]
        dist = np.sqrt((gx - self.eye[0]) ** 2 + (gz - self.eye[2]) ** 2)
        line = np.maximum(np.exp(-((np.abs((gx / 3) - np.round(gx / 3)) * 3 / 0.05) ** 2)), np.exp(-((np.abs((gz / 3) - np.round(gz / 3)) * 3 / 0.05) ** 2)))
        line *= np.clip(1 - dist / 60, 0, 1)
        floor = np.array((0.035, 0.04, 0.06), np.float32) + line[..., None] * self.accent * 0.55
        pool = np.exp(-((gx / 9) ** 2 + (gz / 7) ** 2))[..., None]
        floor = floor + pool * self.accent * 0.22
        fog = np.clip(dist / 55, 0, 1)[..., None] ** 1.4
        floor = floor * (1 - fog) + np.array(horizon_color, np.float32) * fog
        backdrop = np.where(ground[..., None], floor, sky)
        # The fighters' reflections in the polished floor.
        if self.reflect is not None:
            rc, rd = self.reflect
            mask = np.isfinite(rd)[..., None] & ground[..., None]
            blurred = np.asarray(Image.fromarray(np.clip(rc * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2)), np.float32) / 255
            backdrop = np.where(mask, backdrop * 0.55 + blurred * 0.6, backdrop)
        empty = ~np.isfinite(self.depth)
        self.color = np.where(empty[..., None], backdrop, self.color)
        # Haze on the fighters with distance.
        haze = np.clip((np.where(empty, 0, self.depth) - 14) / 60, 0, 0.6)[..., None]
        self.color = self.color * (1 - haze) + np.array(horizon_color, np.float32) * haze

    # ------------------------------------------------------------- effects
    def glow(self, x, y, radius, color, strength=1.0):
        yy, xx = np.mgrid[0 : self.h, 0 : self.w].astype(np.float32)
        r2 = ((xx - x) ** 2 + (yy - y) ** 2) / radius**2
        self.color += np.exp(-r2 * 2.5)[..., None] * np.array(color, np.float32) * strength

    def sparks(self, x, y, spread, count, color):
        img = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(img)
        for _ in range(count):
            a = self.rng.uniform(0, math.tau)
            r = self.rng.uniform(0.05, 1) ** 0.7 * spread
            sx, sy = x + math.cos(a) * r, y + math.sin(a) * r * 0.8
            length = self.rng.uniform(6, 26) * (self.w / 700)
            d.line([(sx, sy), (sx + math.cos(a) * length, sy + math.sin(a) * length)], fill=255, width=max(1, int(self.w / 400)))
        m = np.asarray(img, np.float32)[..., None] / 255
        soft = np.asarray(img.filter(ImageFilter.GaussianBlur(self.w / 160)), np.float32)[..., None] / 255
        self.color += soft * np.array(color, np.float32) * 2.2 + m * 0.9

    def embers(self, count, color, region=(0, 1, 0, 1)):
        for _ in range(count):
            x = self.w * self.rng.uniform(region[0], region[1])
            y = self.h * self.rng.uniform(region[2], region[3])
            self.glow(x, y, self.w * self.rng.uniform(0.003, 0.008), color, self.rng.uniform(0.6, 1.4))

    def ring(self, x, y, rx, ry, color, width):
        img = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(img).ellipse((x - rx, y - ry, x + rx, y + ry), outline=255, width=int(width))
        m = np.asarray(img, np.float32)[..., None] / 255
        soft = np.asarray(img.filter(ImageFilter.GaussianBlur(width * 2.5)), np.float32)[..., None] / 255
        self.emit += soft * np.array(color, np.float32) * 1.5
        self.color += m * np.array(color, np.float32) * 0.6 + soft * np.array(color, np.float32)

    def finish(self):
        img = self.color.copy()
        # Bloom from the glowing trims and anything bright.
        bright = np.clip(img - 0.75, 0, None) + self.emit * 0.6
        bloom = np.zeros_like(img)
        for radius, weight in ((self.w / 220, 0.6), (self.w / 70, 0.5), (self.w / 25, 0.35)):
            layer = Image.fromarray(np.clip(bright * 160, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
            bloom += np.asarray(layer, np.float32) / 160 * weight
        img = img + bloom
        # Filmic tone and a vignette.
        img = 1 - np.exp(-img * 1.35)
        yy, xx = np.mgrid[0 : self.h, 0 : self.w].astype(np.float32)
        r = np.sqrt(((xx - self.w / 2) / self.w) ** 2 + ((yy - self.h * 0.45) / self.h) ** 2)
        img *= np.clip(1.12 - r * 0.95, 0.4, 1)[..., None]
        grain = np.random.default_rng(7).normal(0, 0.008, img.shape).astype(np.float32)
        return Image.fromarray(np.clip((img + grain) * 255, 0, 255).astype(np.uint8), "RGB")


# --------------------------------------------------------------------- cards
def pose(frames, name, index=0):
    matches = [f for f in frames if f["Name"].startswith(name)]
    return matches[min(index, len(matches) - 1)]["Parts"]


def forward_blade(frames, name, index=0):
    """The pose with its sword turned through the grip, so a thrust points the
    blade ahead instead of back along the forearm."""
    matches = [f for f in frames if f["Name"].startswith(name)]
    frame = matches[min(index, len(matches) - 1)]
    grip = frame.get("Grip")
    if not grip:
        return frame["Parts"]
    g = np.array(grip, np.float32)
    out = []
    for p in frame["Parts"]:
        if len(p) > 20 and p[20]:
            q = list(p)
            pos = 2 * g - np.array(p[0:3], np.float32)
            q[0:3] = [float(v) for v in pos]
            # Turn the part half round (about its own up axis) to match.
            q[3:6] = [-v for v in p[3:6]]
            q[6:9] = [-v for v in p[6:9]]
            out.append(q)
        else:
            out.append(p)
    return out


def duel(poses, w, h):
    s = Scene(w, h, eye=(2.2, 2.2, 16.5), target=(0, 3.4, 0), fov=36, accent=GOLD, seed=11)
    # A thrust: the blade pointing straight at the defender.
    a = forward_blade(poses["Sword"], "Bolt cast · release")
    b = pose(poses["Sword"], "Guard (blocking) · held")
    s.fighters([(a, (-2.5, 0.6), -90), (b, (3.0, -0.6), 90)])
    s.backdrop((0.02, 0.02, 0.06), (0.16, 0.1, 0.06), planet=(w * 0.76, h * 0.17, w * 0.13, (0.9, 0.75, 0.55)), shafts=((0.5, 0.07, 0.35), (0.3, 0.04, 0.2)))
    cx, cy = s.project(np.array([[0.0, 4.2, 0.0]], np.float32))[0][:2]
    s.glow(cx, cy, w * 0.16, GOLD * 1.2 + 0.2, 0.9)
    s.sparks(cx, cy, w * 0.22, 70, GOLD)
    s.embers(40, GOLD, (0, 1, 0.1, 0.8))
    return s.finish()


def clash(poses, w, h):
    s = Scene(w, h, eye=(0, 2.8, 12.5), target=(0, 3.0, 0), fov=32, accent=TEAL, seed=12)
    specs = [
        (forward_blade(poses["Sword"], "Bolt cast · release"), (-2.4, 0.6), -90),
        (pose(poses["Sword"], "Heavy · wind-up"), (-6.2, -1.4), -75),
        (pose(poses["Sword"], "Guard (blocking) · held"), (2.4, -0.6), 90),
        (pose(poses["Sword"], "Charging a heavy · held"), (6.2, 1.2), 100),
    ]
    s.fighters(specs)
    s.backdrop((0.01, 0.03, 0.06), (0.05, 0.14, 0.18), planet=(w * 0.52, h * 0.2, h * 0.16, (0.55, 0.85, 0.95)), shafts=((0.5, 0.05, 0.3),))
    cx, cy = s.project(np.array([[0.0, 4.0, 0.0]], np.float32))[0][:2]
    s.glow(cx, cy, h * 0.3, TEAL + 0.2, 0.8)
    s.sparks(cx, cy, h * 0.35, 50, TEAL)
    s.embers(30, TEAL)
    return s.finish()


def dungeon(poses, w, h):
    s = Scene(w, h, eye=(0, 3.4, 9), target=(0, 3.4, -10), fov=34, accent=AMETHYST, seed=13)
    specs = [
        (pose(poses["Sword"], "Stance"), (-2.8, -0.4), 8),
        (pose(poses["Sword"], "Charging a heavy · held"), (0.2, -1.8), -4),
        (pose(poses["Sword"], "Stance", 1), (3.0, -0.2), -10),
    ]
    # The dungeon gate: two dark pillars and a lintel round a portal.
    s.block((-5.2, 6, -16), (2.2, 12, 2.2), (0.12, 0.08, 0.16))
    s.block((5.2, 6, -16), (2.2, 12, 2.2), (0.12, 0.08, 0.16))
    s.block((0, 12.6, -16), (12.6, 2.0, 2.4), (0.12, 0.08, 0.16))
    s.fighters(specs)
    s.backdrop((0.01, 0.0, 0.03), (0.1, 0.04, 0.16), shafts=((0.5, 0.08, 0.25),))
    cx, cy = s.project(np.array([[0.0, 5.6, -16.5]], np.float32))[0][:2]
    edge = s.project(np.array([[4.0, 5.6, -16.5]], np.float32))[0][0]
    rx = abs(edge - cx)
    s.glow(cx, cy, rx * 1.4, AMETHYST, 1.3)
    s.ring(cx, cy, rx, rx * 1.35, AMETHYST + 0.2, max(3, w / 220))
    s.embers(40, AMETHYST)
    return s.finish()


def custom(poses, w, h):
    s = Scene(w, h, eye=(0, 3.2, 13), target=(0, 3.4, 0), fov=32, accent=EMERALD, seed=14)
    # The Outpost beacon in the middle.
    s.block((0, 4.5, -1.5), (0.8, 9, 0.8), (0.1, 0.12, 0.12))
    s.block((0, 9.2, -1.5), (1.2, 0.6, 1.2), (0.2, 0.9, 0.6), neon=True)
    specs = [
        (pose(poses["Sword"], "Stance"), (-3.0, 0.6), -140),
        (pose(poses["Sword"], "Buff · arms wide"), (-6.6, -1.2), -120),
        (pose(poses["Sword"], "Stance", 2), (3.0, 0.4), 140),
        (pose(poses["Sword"], "Stance", 1), (6.6, -1.4), 120),
    ]
    s.fighters(specs)
    s.backdrop((0.01, 0.03, 0.03), (0.04, 0.14, 0.11), planet=(w * 0.86, h * 0.22, h * 0.14, (0.7, 0.95, 0.85)))
    bx, by = s.project(np.array([[0.0, 9.2, -1.5]], np.float32))[0][:2]
    s.glow(bx, by, h * 0.3, EMERALD + 0.2, 1.2)
    top = s.project(np.array([[0.0, 30.0, -1.5]], np.float32))[0][:2]
    beam = Image.new("L", (w, h), 0)
    ImageDraw.Draw(beam).line([(bx, by), (top[0], top[1])], fill=255, width=int(w / 120))
    s.emit += np.asarray(beam.filter(ImageFilter.GaussianBlur(w / 80)), np.float32)[..., None] / 255 * EMERALD * 2
    s.embers(30, EMERALD)
    return s.finish()


def ranked(poses, w, h):
    s = Scene(w, h, eye=(1.0, 2.0, 15.5), target=(0, 4.4, 0), fov=38, accent=RED, seed=15)
    # The podium.
    s.block((0, 0.5, 0), (5.0, 1.0, 5.0), (0.12, 0.06, 0.07))
    s.block((0, 1.05, 0), (5.2, 0.12, 5.2), (1.0, 0.3, 0.3), neon=True)
    champion = pose(poses["Sword"], "Ground blast · arms up")
    parts = [p[:1] + [p[1] + 1.1] + p[2:] for p in champion]
    s.fighters([(parts, (0, 0), 195)])
    s.backdrop((0.03, 0.0, 0.01), (0.2, 0.04, 0.05), shafts=((0.32, 0.05, 0.5), (0.68, 0.05, 0.5), (0.5, 0.08, 0.35)))
    s.embers(60, RED, (0, 1, 0.05, 0.85))
    hx, hy = s.project(np.array([[0.0, 9.5, 0.0]], np.float32))[0][:2]
    s.glow(hx, hy, w * 0.22, RED + 0.25, 0.7)
    return s.finish()


CARDS = {
    "duel": (duel, 340, 500),
    "clash": (clash, 420, 156),
    "dungeon": (dungeon, 420, 156),
    "custom": (custom, 420, 156),
    "ranked": (ranked, 290, 500),
}


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "."
    poses = {}
    for weapon in ("Sword",):
        with open(os.path.join(folder, f"key_{weapon}.json")) as f:
            poses[weapon] = json.load(f)
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[2:] or list(CARDS)
    rendered = {}
    for name in only:
        paint, w, h = CARDS[name]
        image = paint(poses, w * 2, h * 2)
        image.save(os.path.join(OUT, f"{name}.png"), optimize=True)
        rendered[name] = image
        print(f"{name}.png  {image.width}x{image.height}")
    sheet = Image.new("RGB", (1120, 560), (12, 14, 20))
    layout = {"duel": (0, 0), "clash": (362, 0), "dungeon": (362, 172), "custom": (362, 344), "ranked": (830, 0)}
    for name, (x, y) in layout.items():
        path = os.path.join(OUT, f"{name}.png")
        if os.path.exists(path):
            _, w, h = CARDS[name]
            sheet.paste(Image.open(path).resize((w, h), Image.LANCZOS), (x, y))
    sheet.save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
