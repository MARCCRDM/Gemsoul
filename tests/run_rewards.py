"""Swing restores and reward coupons: the arena tournament's shares, coupons per invited friend, spending them (CouponServer) and the kaiju revive product."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the reward tests")
subprocess.run([lune, "run", str(ROOT / "tests" / "rewards_cases.luau"), str(ROOT)], check=True)
