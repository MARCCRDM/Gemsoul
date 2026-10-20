"""Health on the body, not over it (client Modules/BodyHealth): colours sink as health drops, a flash on each blow, smoke when low."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the body health tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "body_health_cases.luau"), str(ROOT)], check=True)
