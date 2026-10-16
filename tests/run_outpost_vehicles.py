"""Check the Outpost machines on the server: boarding, the physics hand-over and server-side driving (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_outpost_vehicles needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/outpost_vehicles_cases.luau'), str(ROOT)], check=True)
