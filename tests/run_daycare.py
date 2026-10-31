"""The Kaiju Daycare: STORE or TRAIN, its fee, its pen, boarding and collecting (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_daycare needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/daycare_cases.luau'), str(ROOT)], check=True)
