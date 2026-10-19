"""The names and bars over creatures (client Modules/Nameplates): yours unnamed, wild ones closer and smaller on a phone."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the nameplate tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "nameplate_cases.luau"), str(ROOT)], check=True)
