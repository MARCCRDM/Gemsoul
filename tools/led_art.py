"""Turn the game's art into LED pixel art for the Outpost's LED screens.

Each picture is cropped to what's drawn (its alpha), fitted into a square of
SIZE x SIZE LEDs, and cut down to a few colours (an LED has one colour or is
off). The result is written to src/shared/LedArt.luau, which the screens draw
(Shared.Led.art):

    LedArt.<Name> = { W, H, Palette = { {r, g, b}, ... }, Rows = { "..01..", ... } }

a row's character is the pixel's palette index (0-9, then a-e), "." off.

Run it again after changing PICTURES (needs Pillow):

    python3 tools/led_art.py
"""
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/images/loading-guides/illustrations"
SIZE = 26  # LEDs across and down (the screens are 72 x 30)
COLOURS = 8  # per picture
ALPHA = 110  # under this, the LED is off
DIGITS = "0123456789abcde"

LED = ROOT / "assets/images/led"  # the kaiju and bosses, rendered from their models

# name: the picture, or (the picture, LEDs across and down)
PICTURES = {
    "FireGem": ART / "gem-Fire.png",
    "FrostGem": ART / "gem-Frost.png",
    "ShockGem": ART / "gem-Shock.png",
    "PoisonGem": ART / "gem-Poison.png",
    "Chest": ART / "chest.png",
    "Helmet": ART / "helmet.png",
    "Shield": ART / "shield.png",
    "SmallFire": (ART / "gem-Fire.png", 9),
    "SmallFrost": (ART / "gem-Frost.png", 9),
    "SmallShock": (ART / "gem-Shock.png", 9),
    "SmallPoison": (ART / "gem-Poison.png", 9),
}
# (every kaiju and boss picture there, as Kaiju<Name> and Boss<Id>)
for _picture in sorted(LED.glob("*.png")):
    _kind, _name = _picture.stem.split("_", 1)
    PICTURES[("Kaiju" if _kind == "k" else "Boss") + _name] = (_picture, 28)


def convert(path: Path, size: int = SIZE):
    image = Image.open(path).convert("RGBA")
    box = image.getchannel("A").point(lambda a: 255 if a >= ALPHA else 0).getbbox()
    if box:
        image = image.crop(box)
    # fit inside size x size, keeping its shape
    scale = size / max(image.size)
    w, h = max(1, round(image.width * scale)), max(1, round(image.height * scale))
    small = image.resize((w, h), Image.LANCZOS)
    alpha = small.getchannel("A")
    # (a few colours, brightened a touch: LEDs read better saturated)
    rgb = Image.new("RGB", small.size, (0, 0, 0))
    rgb.paste(small.convert("RGB"), mask=alpha)
    # (LEDs glow: punchier colour and contrast than a picture on a page)
    rgb = ImageEnhance.Color(rgb).enhance(1.8)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.35)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.35)
    quant = rgb.quantize(colors=COLOURS, method=Image.MEDIANCUT)
    palette = quant.getpalette()[: COLOURS * 3]
    rows, used = [], {}
    for y in range(h):
        row = []
        for x in range(w):
            if alpha.getpixel((x, y)) < ALPHA:
                row.append(".")
                continue
            index = quant.getpixel((x, y))
            r, g, b = palette[index * 3 : index * 3 + 3]
            if r + g + b < 40:  # (black reads as an LED that's off)
                row.append(".")
                continue
            if index not in used:
                used[index] = len(used)
            row.append(DIGITS[used[index]])
        rows.append("".join(row))
    colours = [None] * len(used)
    for index, slot in used.items():
        r, g, b = palette[index * 3 : index * 3 + 3]
        lift = 1.0
        colours[slot] = tuple(min(255, int(c * lift)) for c in (r, g, b))
    return w, h, colours, rows


def luau() -> str:
    out = [
        "--[[",
        "\tLED pixel art for the Outpost's LED screens (Shared.Led.art), made from",
        "\tthe game's pictures by tools/led_art.py: don't edit by hand, run that.",
        "",
        '\t  LedArt.<Name> = { W, H, Palette = { { r, g, b } }, Rows = { "..01.." } }',
        '\t  a row\'s characters: the palette index (0-9, a-e), "." off',
        "]]",
        "local LedArt = {}",
        "",
    ]
    for name, spec in PICTURES.items():
        path, size = spec if isinstance(spec, tuple) else (spec, SIZE)
        w, h, colours, rows = convert(path, size)
        palette = ", ".join("{ %d, %d, %d }" % c for c in colours)
        out.append(f"LedArt.{name} = {{")
        out.append(f"\tW = {w},")
        out.append(f"\tH = {h},")
        out.append(f"\tPalette = {{ {palette} }},")
        out.append("\tRows = {")
        for row in rows:
            out.append(f'\t\t"{row}",')
        out.append("\t},")
        out.append("}")
    out.append("")
    out.append("return LedArt")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    target = ROOT / "src/shared/LedArt.luau"
    target.write_text(luau(), encoding="utf-8")
    print(f"wrote {target.relative_to(ROOT)} ({len(PICTURES)} pictures, {SIZE} LEDs across)")
