"""The Outpost's edge for now (client Modules/EdgeDome): a dome over the walls that shows as you come near."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the edge dome tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "edge_dome_cases.luau"), str(ROOT)], check=True)
