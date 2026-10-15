"""Settle bodies after a fight, yours and other players', with the real BodyPoses (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_body_poses needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/body_poses_cases.luau'), str(ROOT)], check=True)
