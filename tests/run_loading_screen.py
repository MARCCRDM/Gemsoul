"""The loading screen: covers held, timed and taken down once the scene behind is ready (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_loading_screen needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/loading_screen_cases.luau'), str(ROOT)], check=True)
