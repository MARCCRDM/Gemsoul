"""Check Shared.MechPilot: who pilots what, and how a mech moves (needs lune)."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_mech_pilot needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/mech_pilot_cases.luau'), str(ROOT)], check=True)
