"""The kaiju starter roll's screen (Modules/KaijuRoll), driven frame by frame: the gem roll's reel, in turn, the cards, START."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the kaiju roll test")
subprocess.run([lune, "run", str(ROOT / "tests/kaiju_roll_cases.luau"), str(ROOT)], check=True)
