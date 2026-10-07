"""Every archived surge and maneuver still resolves (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_legacy_surges needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/legacy_surges_cases.luau'), str(ROOT)], check=True)
