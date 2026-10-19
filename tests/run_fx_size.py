"""How big an effect is drawn (client Modules/FxSize): a creature's size held, kept and never lent."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the effect size tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "fx_size_cases.luau"), str(ROOT)], check=True)
