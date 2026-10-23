"""Who a boss is on, on the real Duelist raidTarget cut out of its source (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_boss_targets needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/boss_targets_cases.luau'), str(ROOT)], check=True)
