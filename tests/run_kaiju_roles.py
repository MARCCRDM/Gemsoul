"""Kaiju battles as an auto battler (KaijuRoles, KaijuBattleBrain): roles and kits, who a kaiju picks and where it stands, and whole battles played out with the real brain and moves: no standing about, onto the next foe after a kill, 3 on 1, the shooter at the back, the tank's roar, the assassin's leap, inside the court (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_kaiju_roles needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/kaiju_roles_cases.luau'), str(ROOT)], check=True)
