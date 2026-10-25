"""How a blow you land feels: hit stop, the jar of your view, guards, sparks, sounds, rumble and the hit flash (SwordFeel, HitFlash)."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the sword feel tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "sword_feel_cases.luau"), str(ROOT)], check=True)
