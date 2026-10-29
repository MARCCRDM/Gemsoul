"""Pointing the way to the rocks (Client MineCue): the glow, the label, on foot and in a mech (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_mine_cue needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/mine_cue_cases.luau'), str(ROOT)], check=True)
