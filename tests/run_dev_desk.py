"""Server.DevDesk: the Shelter's DEV desk, lit while one of the game's Owners is in the server."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the DEV desk tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "dev_desk_cases.luau"), str(ROOT)], check=True)
