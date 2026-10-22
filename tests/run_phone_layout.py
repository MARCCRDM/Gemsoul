"""A phone is a phone either way up (UiKit.short), and the Store's phone layout fills it (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_phone_layout needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/phone_layout_cases.luau'), str(ROOT)], check=True)
