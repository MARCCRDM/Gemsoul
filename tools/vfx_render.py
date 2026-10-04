# Renders tools/vfx_sim.luau snapshots: a contact sheet per scenario (rows =
# elements, columns = moments), with neon glow, particles and lights.
#   python3 tools/vfx_render.py <dir> [scenario...]
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

W, H = 360, 240
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
SMALL = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
SUN = np.array([0.4, 0.8, -0.45]); SUN /= np.linalg.norm(SUN)
CAMERAS = {
    "Bolt": ((17, 7, -3), (0, 3.5, -9), 55),
    "Blast": ((19, 13, 0), (0, 1.5, -13), 58),
    "Aura": ((8, 5, 8), (0, 3, 0), 52),
    "Hit": ((8, 5.5, -8), (0, 3.4, -15.5), 50),
    "Death": ((15, 9, -3), (0, 2.5, -16), 60),
}

def shape_mesh(shape, sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    if shape == "Cylinder":
        n = 18; v = []
        for x in (-hx, hx):
            for k in range(n):
                a = 2 * math.pi * k / n; v.append((x, hy * math.cos(a), hz * math.sin(a)))
        f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
    elif shape == "Ball":
        r = min(sx, sy, sz) / 2; v = []; f = []; st, sl = 6, 10
        for i in range(st + 1):
            th = math.pi * i / st
            for j in range(sl):
                ph = 2 * math.pi * j / sl
                v.append((r * math.sin(th) * math.cos(ph), r * math.cos(th), r * math.sin(th) * math.sin(ph)))
        for i in range(st):
            for j in range(sl):
                a = i * sl + j; b = i * sl + (j + 1) % sl; c = (i + 1) * sl + (j + 1) % sl; d = (i + 1) * sl + j
                f.append((a, d, c, b))
    else:
        v = [(x, y, z) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return np.array(v, float), f

class Cam:
    def __init__(self, eye, target, fov):
        self.eye = np.array(eye, float)
        f = np.array(target, float) - self.eye; self.f = f / np.linalg.norm(f)
        r = np.cross(self.f, [0, 1, 0]); self.r = r / np.linalg.norm(r)
        self.u = np.cross(self.r, self.f)
        self.focal = (H / 2) / math.tan(math.radians(fov) / 2)
    def project(self, p):
        d = np.asarray(p, float) - self.eye
        x, y, z = d @ self.r, d @ self.u, d @ self.f
        return x, y, z
    def screen(self, x, y, z):
        return W / 2 + x / z * self.focal, H / 2 - y / z * self.focal

def render(shot, cam):
    base = Image.new("RGB", (W, H))
    px = base.load()
    for y in range(H):
        t = y / H
        c = (int(26 + 14 * t), int(30 + 12 * t), int(44 + 6 * t))
        for x in range(W):
            px[x, y] = c
    main = base  # RGB: an "RGBA" draw on an RGB image blends
    draw = ImageDraw.Draw(main, "RGBA")
    glow = Image.new("RGB", (W, H))
    gdraw = ImageDraw.Draw(glow, "RGBA")
    smoke = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(smoke, "RGBA")
    # Ground: a big quad and a grid.
    def ground_point(x, z):
        X, Y, Z = cam.project((x, 0, z))
        return cam.screen(X, Y, Z) if Z > 0.2 else None
    quad = [ground_point(x, z) for x, z in ((-60, -60), (60, -60), (60, 60), (-60, 60))]
    # Clip crudely: draw grid tiles instead.
    for gx in range(-40, 40, 4):
        for gz in range(-50, 30, 4):
            pts = [ground_point(gx, gz), ground_point(gx + 4, gz), ground_point(gx + 4, gz + 4), ground_point(gx, gz + 4)]
            if None in pts:
                continue
            shade = 52 if (gx // 4 + gz // 4) % 2 == 0 else 46
            draw.polygon(pts, fill=(shade, shade + 2, shade + 6, 255))
    items = []
    for p in shot["Parts"]:
        pos = np.array(p[0:3]); R = np.array(p[3:6]); U = np.array(p[6:9]); L = np.array(p[9:12])
        verts, faces = shape_mesh(p[18], p[12], p[13], p[14])
        world = pos + verts[:, 0:1] * R + verts[:, 1:2] * U - verts[:, 2:3] * L
        color = np.array(p[15:18]); transparency = p[19]; material = p[20]
        neon = material == "Neon"
        alpha = 1 - transparency
        if material in ("Glass", "Ice"):
            alpha *= 0.75
        cam_pts = [cam.project(w) for w in world]
        for face in faces:
            zs = [cam_pts[i][2] for i in face]
            if min(zs) < 0.15:
                continue
            a, b, c = world[face[0]], world[face[1]], world[face[2]]
            n = np.cross(b - a, c - a)
            nl = np.linalg.norm(n)
            if nl < 1e-9:
                continue
            n /= nl
            centre = world[list(face)].mean(axis=0)
            facing = n @ (cam.eye - centre)
            if alpha > 0.95 and facing < 0:
                continue
            if neon:
                col = color
            else:
                lam = max(0.0, abs(n @ SUN) if alpha < 0.95 else n @ SUN)
                col = color * (0.35 + 0.65 * lam)
                if material in ("Glass", "Ice"):
                    col = col * 0.7 + 0.3
            scr = [cam.screen(*cam_pts[i]) for i in face]
            items.append((np.mean(zs), "poly", scr, col, alpha, neon))
    for q in shot["Particles"]:
        X, Y, Z = cam.project(q[0:3])
        if Z < 0.3 or q[7] <= 0.01:
            continue
        sx, sy = cam.screen(X, Y, Z)
        r = max(0.6, q[3] / 2 / Z * cam.focal)
        items.append((Z, "dot", (sx, sy, r), np.array(q[4:7]), q[7], q[8] > 0.3))
    for t in shot.get("Trails", []):
        pts = [t[0:3], t[3:6], t[6:9], t[9:12]]
        cp = [cam.project(q) for q in pts]
        if min(c[2] for c in cp) < 0.2 or t[15] <= 0.01:
            continue
        scr = [cam.screen(*c) for c in cp]
        items.append((np.mean([c[2] for c in cp]), "poly", scr, np.array(t[12:15]), t[15], t[16] > 0.3))
    items.sort(key=lambda it: -it[0])
    for z, kind, geo, col, alpha, emissive in items:
        rgb = tuple(int(max(0, min(1, c)) * 255) for c in col)
        a = int(max(0, min(1, alpha)) * 255)
        if kind == "poly":
            draw.polygon(geo, fill=rgb + (a,))
            if emissive:
                # See-through neon glows less (closer to Roblox's bloom).
                gdraw.polygon(geo, fill=rgb + (int(a * alpha * 0.8),))
        else:
            sx, sy, r = geo
            box = (sx - r, sy - r, sx + r, sy + r)
            if emissive:
                gdraw.ellipse(box, fill=rgb + (a,))
                draw.ellipse((sx - r * 0.5, sy - r * 0.5, sx + r * 0.5, sy + r * 0.5), fill=rgb + (int(a * 0.8),))
            else:
                sdraw.ellipse(box, fill=rgb + (int(a * 0.45),))
    # Lights: a soft pool of light.
    for l in shot["Lights"]:
        X, Y, Z = cam.project(l[0:3])
        if Z < 0.3:
            continue
        sx, sy = cam.screen(X, Y, Z)
        r = l[7] * 0.35 / Z * cam.focal
        k = min(1.0, l[6] / 12)
        rgb = tuple(int(c * 255 * k) for c in l[3:6])
        gdraw.ellipse((sx - r, sy - r, sx + r, sy + r), fill=rgb + (int(90 * k),))
    main = Image.alpha_composite(main.convert("RGBA"), smoke.filter(ImageFilter.GaussianBlur(3)))
    out = main.convert("RGB")
    bloom = glow.filter(ImageFilter.GaussianBlur(7))
    bloom2 = glow.filter(ImageFilter.GaussianBlur(2))
    out = ImageChops.add(out, bloom)
    out = ImageChops.add(out, Image.eval(bloom2, lambda v: v // 2))
    return out

def sheet(path):
    data = json.load(open(path))
    name = data["Name"]
    cam = Cam(*CAMERAS[name])
    rows = data["Rows"]; frames = data["Frames"]
    pad, label = 4, 70
    img = Image.new("RGB", (label + len(frames) * (W + pad), 22 + len(rows) * (H + pad)), (14, 16, 22))
    d = ImageDraw.Draw(img)
    d.text((6, 4), name, font=FONT, fill=(240, 240, 240))
    for j, t in enumerate(frames):
        d.text((label + j * (W + pad) + 4, 5), f"t = {t:.2f}s", font=SMALL, fill=(200, 200, 210))
    for i, row in enumerate(rows):
        d.text((6, 22 + i * (H + pad) + H // 2), row["Label"], font=FONT, fill=(240, 240, 240))
        for j, shot in enumerate(row["Shots"]):
            img.paste(render(shot, cam), (label + j * (W + pad), 22 + i * (H + pad)))
    out = path.replace(".json", ".png")
    img.save(out)
    print(out)

if __name__ == "__main__":
    folder = sys.argv[1]
    names = sys.argv[2:] or [n[:-5] for n in os.listdir(folder) if n.endswith(".json")]
    for n in names:
        sheet(os.path.join(folder, n + ".json"))
