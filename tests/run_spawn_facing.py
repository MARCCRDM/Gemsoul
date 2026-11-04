"""Into every dungeon facing the right way: the character, and the camera behind it (Server.SpawnFacing, Client SpawnFacing)."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the spawn facing test")
subprocess.run([lune, "run", str(ROOT / "tests/spawn_facing_cases.luau"), str(ROOT)], check=True)
