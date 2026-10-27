"""COUNTER between Ranked rounds (Shared.CounterGear). Needs lune."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("run_counter_gear needs lune (https://github.com/lune-org/lune) on PATH")
subprocess.run([lune, "run", str(ROOT / "tests" / "counter_gear_cases.luau"), str(ROOT)], check=True)
