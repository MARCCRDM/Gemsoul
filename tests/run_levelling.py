"""How you level up (Shared.Levelling): rocks falling off, wins by the foe's level, and every source wired to it (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_levelling needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/levelling_cases.luau'), str(ROOT)], check=True)
