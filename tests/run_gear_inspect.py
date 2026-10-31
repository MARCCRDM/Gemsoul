"""Another player's gear: what they wear, from GEAR on the card beside them (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_gear_inspect needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/gear_inspect_cases.luau'), str(ROOT)], check=True)
