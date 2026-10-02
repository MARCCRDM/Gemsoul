"""Exercise real Luau generation, migration, mine loot and trade handlers with service mocks."""
from pathlib import Path
import re
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding="utf-8")
def module(name, path):
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", read(path), flags=re.M)
    return f"local {name} = (function()\n{source}\nend)()\n"
source = read("tests/roblox_primitives.luau")
source += read("tests/expedition_services.luau")
for name, path in [
    ("EquipmentBalance", "src/shared/EquipmentBalance.luau"),
    ("ArmorFamilies", "src/shared/ArmorFamilies.luau"),
    ("ExpandedTraits", "src/shared/ExpandedItemTraits.luau"),
    ("Slots", "src/shared/EquipmentSlots.luau"),
    ("GemConfig", "src/shared/GemConfig.luau"),
    ("Crafting", "src/shared/Crafting.luau"),
    ("GearRolls", "src/shared/GearRolls.luau"),
    ("Classes", "src/shared/Classes.luau"),
    ("Economy", "src/shared/ExpeditionEconomy.luau"),
    ("GemGenerator", "src/server/Systems/GemGenerator.luau"),
    ("Logic", "src/shared/EquipmentTrade.luau"),
    ("Store", "src/shared/Store.luau"),
    ("Season", "src/shared/Season.luau"),
    ("Mine", "src/shared/Mine.luau"),
]: source += module(name, path)
source += read("tests/expedition_profiles.luau")
source += module("Journal", "src/server/Systems/TradeJournal.luau")
source += module("Trading", "src/server/Systems/Trading.luau")
source += module("Forge", "src/server/Systems/Forge.luau")
source += module("RequestRouter", "src/server/Systems/Shop.luau")
wall = read("src/server/Systems/MineWall.luau")
source += wall[wall.index("local function recoverGear"):wall.index("local function mineState")]
source += read("tests/expedition_cases.luau")
with tempfile.TemporaryDirectory(prefix="gemsoul-expedition-") as directory:
    script = Path(directory) / "tests.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
