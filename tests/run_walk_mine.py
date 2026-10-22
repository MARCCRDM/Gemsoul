"""Walking into a rock mines it (Shared.WalkMine): the rule, and the Outpost, mechs, the Rift and expeditions using it (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_walk_mine needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/walk_mine_cases.luau'), str(ROOT)], check=True)
