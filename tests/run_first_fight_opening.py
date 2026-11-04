"""Round 1's opening (Client FirstFight): the welcome, then the controls' line with arrows on Q/E/R and ATTACK/BLOCK/DODGE."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the first fight opening test")
subprocess.run([lune, "run", str(ROOT / "tests/first_fight_opening_cases.luau"), str(ROOT)], check=True)
