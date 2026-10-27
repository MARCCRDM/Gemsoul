"""A gem's whole list (Shared.GemFacts, the Market's listing). Needs lune."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("run_gem_facts needs lune (https://github.com/lune-org/lune) on PATH")
subprocess.run([lune, "run", str(ROOT / "tests" / "gem_facts_cases.luau"), str(ROOT)], check=True)
