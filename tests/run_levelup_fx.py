"""Levelling up on screen (LevelUpFx): the column of light, the rings, the sparks, the flash and the plate, a kaiju's at its size, following its body, gone after its time; sent by the server and drawn by the client (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_levelup_fx needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/levelup_fx_cases.luau'), str(ROOT)], check=True)
