"""No body left frozen part-way through a move: the real BodyPoses and RivalPose on FighterRig bodies (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_pose_recovery needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/pose_recovery_cases.luau'), str(ROOT)], check=True)
