"""Kaiju battles: the rules (Shared.KaijuBattle). The server's battles are in run_kaiju.py (kaiju_server_cases)."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the kaiju battle tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "kaiju_battle_cases.luau"), str(ROOT)], check=True)
