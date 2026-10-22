"""A wild kaiju's plate over its head (client Modules/WildBars): name, level, a health bar; the nearest few shown."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the wild kaiju plate tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "wild_bars_cases.luau"), str(ROOT)], check=True)
