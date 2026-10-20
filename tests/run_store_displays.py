"""The Store's displays (StoreDisplays): the stands round the Saga Shelter's Store, what each shows and when, each preview on its stand facing the hall, clear of the walls, the counter and the crew (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_store_displays needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/store_displays_cases.luau'), str(ROOT)], check=True)
