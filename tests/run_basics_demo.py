"""The combat basics' live demo (Client BasicsDemo): two fighters acting out attack, block and abilities."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the basics demo test")
subprocess.run([lune, "run", str(ROOT / "tests/basics_demo_cases.luau"), str(ROOT)], check=True)
