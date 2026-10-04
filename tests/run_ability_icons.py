"""Every ability has a painted icon on the sheet, and the sheet matches its atlas."""
import os
import re
import struct

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


tech = read("src", "shared", "CombatTechnology.luau")
catalog = tech[tech.index("Tech.Catalog = {") :]
ids = set(re.findall(r"\n\t([A-Za-z]+) = \{\n\t\tName = ", catalog))
atlas = read("src", "client", "Modules", "AbilityIconAtlas.luau")
index = dict((name, int(n)) for name, n in re.findall(r"\t\t([A-Za-z]+) = (\d+),", atlas))
cell = int(re.search(r"Cell = (\d+)", atlas).group(1))
columns = int(re.search(r"Columns = (\d+)", atlas).group(1))

missing = sorted(ids - set(index))
assert not missing, f"abilities with no icon: {missing}"
assert len(set(index.values())) == len(index), "two abilities share an icon cell"
with open(os.path.join(ROOT, "assets", "images", "ability_icons.png"), "rb") as f:
    head = f.read(24)
width, height = struct.unpack(">II", head[16:24])
assert width == columns * cell, "sheet width does not match the atlas"
assert max(index.values()) // columns < height // cell, "atlas points past the sheet"
assert not re.search(r'\n\t\tIcon = "', catalog), "a text glyph is still on an ability"
print(f"PASS: {len(ids)} abilities, each with its own painted icon on a {width}x{height} sheet")
