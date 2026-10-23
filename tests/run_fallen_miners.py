"""The fallen miners: real miners in random gear and looks, laid down as props (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_fallen_miners needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/fallen_miner_cases.luau'), str(ROOT)], check=True)
