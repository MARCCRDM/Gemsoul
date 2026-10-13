"""The fast start: who sees the picker, the kit each choice gives, and the first fight's hints (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_fast_start needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/fast_start_cases.luau'), str(ROOT)], check=True)
