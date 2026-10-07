"""
Renders the starter-kit picker's armor-style art (the intro's three cards):
one fighter per family in its own armor, posed by the game's RivalPose and
lit in the family's colour, in the same look as the lobby key art
(tools/make_lobby_cards.py).

    pip install numpy pillow
    for each family:  CARD_LOOK=<look> CARD_FAMILY=<family> CARD_ACCENT=r,g,b \\
        lune run tools/card_poses.luau <dir>/key_<family>.json 0 player Sword stance
        with CARD_RARITY=5 and CARD_GEM = CARD_ACCENT (legendary armor, one
        gem colour): Prospector UtilityMiner 70,205,90 · Skirmisher
        FrontierRanger 255,212,40 · Juggernaut HeavyVanguard 238,62,54
    python tools/make_style_cards.py <dir>

Writes assets/images/intro/style_<family>.png and preview.png. Upload the
three and put their ids in Intro.client's STYLE_ART.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_lobby_cards import Scene, forward_blade, pose  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "images", "intro")
W, H = 240, 196  # the card's art area (about its shape); rendered at 2x

# Each family in its legendary armor with its own gem (ArmorFamilies Gem):
# Prospector Corrosive, Skirmisher Ion, Juggernaut Thermal. One colour each.
AMBER = np.array((70, 205, 90), np.float32) / 255  # Corrosive green
TEAL = np.array((255, 212, 40), np.float32) / 255  # Ion yellow
STEEL = np.array((238, 62, 54), np.float32) / 255  # Thermal red


def hero(frames, w, h, name, yaw, accent, seed, back, spark=None, planet=None, blade=False, wash=0.45):
    """One fighter, close and a little below eye level, facing the viewer."""
    s = Scene(w, h, eye=(0.8, 2.0, 8.6), target=(0, 3.5, 0), fov=40, accent=accent, seed=seed)
    parts = forward_blade(frames, name) if blade else pose(frames, name)
    s.fighters([(parts, (0, 0), yaw)])
    s.backdrop((0.01, 0.015, 0.03), back, planet=planet, shafts=((0.5, 0.09, 0.42),))
    s.glow(w * 0.5, h * 0.45, w * 0.5, accent + 0.1, wash)
    if spark:
        x, y = w * spark[0], h * spark[1]
        s.glow(x, y, w * 0.18, accent + 0.3, 1.0)
        s.sparks(x, y, w * 0.3, 55, accent + 0.15)
    s.embers(34, accent, (0, 1, 0.1, 0.85))
    return s.finish()


def prospector(frames, w, h):
    # Casting: arms raised, an amber surge gathering overhead, a rune ring
    # burning at his feet.
    s = Scene(w, h, eye=(0.6, 1.6, 10.6), target=(0, 3.6, 0), fov=44, accent=AMBER, seed=21)
    s.fighters([(pose(frames, "Ground blast · arms up"), (0, 0), 180)])
    s.backdrop((0.03, 0.02, 0.02), (0.04, 0.16, 0.07), planet=(w * 0.84, h * 0.12, w * 0.09, (0.7, 0.9, 0.7)), shafts=((0.5, 0.12, 0.5),))
    ox, oy = s.project(np.array([[0.0, 7.3, 0.0]], np.float32))[0][:2]
    s.glow(ox, oy, w * 0.2, AMBER + 0.35, 1.4)
    s.glow(ox, oy, w * 0.06, np.array((1, 1, 0.9), np.float32), 1.5)
    s.sparks(ox, oy, w * 0.28, 60, AMBER + 0.1)
    fx, fy = s.project(np.array([[0.0, 0.05, 0.0]], np.float32))[0][:2]
    edge = s.project(np.array([[2.4, 0.05, 0.0]], np.float32))[0][0]
    rx = abs(edge - fx)
    s.ring(fx, fy, rx, rx * 0.28, AMBER + 0.2, max(3, w / 180))
    s.embers(60, AMBER, (0.2, 0.8, 0.1, 0.95))
    return s.finish()


def skirmisher(frames, w, h):
    # Mobile and quick: the blade flashing overhead.
    return hero(frames, w, h, "Bolt cast · release", 160, TEAL, 22, (0.07, 0.06, 0.01), spark=(0.2, 0.08), blade=True, wash=0.12)


def juggernaut(frames, w, h):
    # Defensive: a blow breaking on the raised shield.
    return hero(frames, w, h, "Block jolt · blow lands", 200, STEEL, 23, (0.18, 0.04, 0.04), spark=(0.68, 0.38), planet=(w * 0.16, h * 0.13, w * 0.09, (1.0, 0.7, 0.6)))


STYLES = {"Prospector": prospector, "Skirmisher": skirmisher, "Juggernaut": juggernaut}


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(OUT, exist_ok=True)
    images = []
    for family, paint in STYLES.items():
        with open(os.path.join(folder, f"key_{family}.json")) as f:
            frames = json.load(f)
        image = paint(frames, W * 2, H * 2)
        image.save(os.path.join(OUT, f"style_{family}.png"), optimize=True)
        images.append(image)
        print(f"style_{family}.png  {image.width}x{image.height}")
    sheet = Image.new("RGB", (W * 3 + 40, H + 20), (12, 14, 20))
    for i, image in enumerate(images):
        sheet.paste(image.resize((W, H), Image.LANCZOS), (10 + i * (W + 10), 10))
    sheet.save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
