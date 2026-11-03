"""The fight's drama (Client FightDrama): the announcer, K.O.s, low health and rivals' words (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_fight_drama needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/fight_drama_cases.luau'), str(ROOT)], check=True)
