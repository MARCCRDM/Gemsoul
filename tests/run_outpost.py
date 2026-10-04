"""Exercise the Saga Outpost rules and the real OutpostServer on Roblox instances (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_outpost needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/outpost_cases.luau'), str(ROOT)], check=True)
