"""The Shelter's life (ShelterLife): the hologram on the stage, the gallery's gems and odds, the garden, the drones (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_shelter_life needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/shelter_life_cases.luau'), str(ROOT)], check=True)
