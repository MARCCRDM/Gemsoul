"""Mini kaiju: the rules, the models, and the server (KaijuAbilities, KaijuServer, KaijuWilds)."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the kaiju tests")
for case in ("kaiju_cases", "kaiju_models_cases", "kaiju_server_cases"):
    subprocess.run([lune, "run", str(ROOT / "tests" / f"{case}.luau"), str(ROOT)], check=True)
