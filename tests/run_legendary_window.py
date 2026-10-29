"""A Legendary mined (LegendaryWindow): the window's timeline, played for your find and another's, its sound (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_legendary_window needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/legendary_window_cases.luau'), str(ROOT)], check=True)
