"""A new miner's first steps card (Shared.FirstSteps): what it coaches, in order, and for whom (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_first_steps needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/first_steps_cases.luau'), str(ROOT)], check=True)
