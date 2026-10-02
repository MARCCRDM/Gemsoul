"""Exercise the actual Augment Tree UI with typed GUI and event doubles."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding="utf-8")
def module(name, path):
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", read(path), flags=re.M)
    return f"local {name}=(function()\n{source}\nend)()\n"
source = read("tests/roblox_primitives.luau")
source += module("Tech", "src/shared/CombatTechnology.luau")
source += module("Tree", "src/shared/AugmentTree.luau")
source += read("tests/augment_ui_services.luau")
source += module("UI", "src/client/Modules/AugmentTreeUI.luau")
source += read("tests/augment_ui_cases.luau")
with tempfile.TemporaryDirectory(prefix="gemsoul-augment-ui-") as directory:
    script = Path(directory) / "tree.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
