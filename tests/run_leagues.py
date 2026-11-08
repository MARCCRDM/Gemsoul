"""Ranked leagues (Shared.Leagues): ranges, the saved league, its safety and track (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_leagues needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/leagues_cases.luau'), str(ROOT)], check=True)
