"""Mechs over the Outpost's terrain (Shared.MechPilot.move on the biomes' ground): never stuck, every mech, every way, a slow phone; walls and rocks still stop it (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_mech_terrain needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/mech_terrain_cases.luau'), str(ROOT)], check=True)
