"""Intro rounds (Shared.IntroRounds, Server.IntroRoundsServer): the ladder, its rewards and who gets it (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_intro_rounds needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/intro_rounds_cases.luau'), str(ROOT)], check=True)
subprocess.run([lune, 'run', str(ROOT / 'tests/intro_rounds_server.luau'), str(ROOT)], check=True)
subprocess.run([lune, 'run', str(ROOT / 'tests/rival_surges_cases.luau'), str(ROOT)], check=True)
