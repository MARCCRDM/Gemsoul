"""Server.PrivateArenas: a Training session's own copy of the Arena (one each, far apart, scenery only, reused)."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the private arena tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "private_arenas_cases.luau"), str(ROOT)], check=True)
