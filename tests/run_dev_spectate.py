"""DEV > WATCH's JOIN (Server DevSpectate): into the dungeon of the one you watch (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_dev_spectate needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/dev_spectate_cases.luau'), str(ROOT)], check=True)
