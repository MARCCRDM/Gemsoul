"""Run equipment regressions with the local Luau CLI; no Studio automation needed."""
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
source += "local Config = {MaxGems=2,MarketSellRate=0.45}\n"
source += module("EquipmentBalance", "src/shared/EquipmentBalance.luau")
source += module("ExpeditionEconomy", "src/shared/ExpeditionEconomy.luau")
source += module("CrowdControl", "src/shared/CrowdControl.luau")
source += module("GemConfig", "src/shared/GemConfig.luau")
source += module("ArmorFamilies", "src/shared/ArmorFamilies.luau")
source += module("ExpandedTraits", "src/shared/ExpandedItemTraits.luau")
source += module("Slots", "src/shared/EquipmentSlots.luau")
source += module("Crafting", "src/shared/Crafting.luau")
source += module("GearRolls", "src/shared/GearRolls.luau")
source += module("Classes", "src/shared/Classes.luau")
source += module("FrontierAssets", "src/server/Systems/FrontierAssets.luau")
source += module("ArmorKits", "src/server/Systems/ArmorKits.luau")
source += "local profiles = {}\nlocal PlayerData = {}\nlocal characterChanged = {Fire=function() end}\nlocal function sync() end\n"
source += "function PlayerData.findGem(player,id) for _,gem in profiles[player].Gems do if gem.Id==id then return gem end end end\n"
source += "function PlayerData.removeGem(player,id) for i,gem in profiles[player].Gems do if gem.Id==id then table.remove(profiles[player].Gems,i); return gem end end end\n"
data = read("src/server/Systems/PlayerData.luau")
source += data[data.index("local SOCKET_KEYS"):data.index("-- The three abilities")]
source += data[data.index("local GEAR_KEYS"):data.index("-- Records a first")]
source += read("tests/equipment_cases.luau")
source += read("tests/expanded_traits_cases.luau")
source += read("tests/armor_family_cases.luau")
source += read("tests/gem_metric_cases.luau")
with tempfile.TemporaryDirectory(prefix="gemsoul-equipment-") as directory:
    script = Path(directory) / "tests.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
