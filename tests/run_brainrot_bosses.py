"""The dungeons' ten bosses: the list, that boss rooms and camps use it, their bodies and how they move."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the boss tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "brainrot_boss_cases.luau"), str(ROOT)], check=True)
