"""The Q / E / R triad: 60 moves, trait rolls, sockets, stats and casting (needs lune).
The live fight checks run inside run_combat.py (tests/triad_live_cases.luau)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_triad needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/triad_cases.luau'), str(ROOT)], check=True)
