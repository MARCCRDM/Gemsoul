"""Build real kits with the real Equipment: stones, element looks, suit trim, previews, first-person grip (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_gear_look needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/gear_look_cases.luau'), str(ROOT)], check=True)
