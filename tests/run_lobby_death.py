"""Killed in the lobby: a creature's blow kills you (robbed past the core, home after), the screen and report say so, in Spanish (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_lobby_death needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/lobby_death_cases.luau'), str(ROOT)], check=True)
