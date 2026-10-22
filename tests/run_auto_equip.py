"""AUTO EQUIP: the Inventory's one-tap build (Shared.AutoEquip). Needs lune."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("run_auto_equip needs lune (https://github.com/lune-org/lune) on PATH")
subprocess.run([lune, "run", str(ROOT / "tests" / "auto_equip_cases.luau"), str(ROOT)], check=True)
