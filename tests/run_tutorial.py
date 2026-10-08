"""Run the first-time tutorial checks (Shared.Tutorial, Systems/Intro) with Lune."""
from pathlib import Path
import shutil
import subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("Install Lune (https://lune-org.github.io) to run these checks.")
subprocess.run([lune, "run", str(ROOT / "tests/tutorial_cases.luau"), str(ROOT)], check=True)
