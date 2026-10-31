"""The Meteor Golem: who it comes for, its blows, its cinematic (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_meteor_golem needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/meteor_golem_cases.luau'), str(ROOT)], check=True)
