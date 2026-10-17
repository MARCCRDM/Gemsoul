"""The Outpost's frontier: bands, candy trails, Rift Veins, pressure, rifts and their tears (Shared.Frontier, RiftTear, FrontierHud)."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the frontier tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "frontier_cases.luau"), str(ROOT)], check=True)
