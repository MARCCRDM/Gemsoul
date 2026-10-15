"""Drive the actual Arena Cache roll: every reel at once, landings in turn, exact outcomes, skip, previews wait, cleanup."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")
source = read("tests/roblox_primitives.luau").split("local built = 0")[0]
source += read("tests/mining_reveal_services.luau")
source += read("tests/cache_lottery_services.luau")
for name, path in [
    ("ExpeditionEconomy", "src/shared/ExpeditionEconomy.luau"),
    ("GemConfig", "src/shared/GemConfig.luau"),
    ("GemTraits", "src/shared/GemTraits.luau"),
    ("GemRoller", "src/shared/GemRoller.luau"),
    ("ArenaStreak", "src/shared/ArenaStreak.luau"),
    ("Slots", "src/shared/EquipmentSlots.luau"),
    ("CacheLottery", "src/client/Modules/CacheLottery.luau"),
]:
    code = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", read(path), flags=re.M)
    source += f"\nlocal {name} = (function()\n{code}\nend)()\n"
source += read("tests/cache_lottery_cases.luau")
script = ROOT / ".tools/cache-lottery-test.luau"
try:
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
finally:
    script.unlink(missing_ok=True)
