"""A gem raid's stones (CritterFx): the stolen gem itself over a snatcher's head, read off its model and placed; the server puts the gem on it, not a made-up stone (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_critter_fx needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/critter_fx_cases.luau'), str(ROOT)], check=True)
