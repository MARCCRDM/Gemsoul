"""Pose the three kinds of player body (R15, upgraded joints, R6) with the real RivalPose (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_rig_pose needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/rig_pose_cases.luau'), str(ROOT)], check=True)
