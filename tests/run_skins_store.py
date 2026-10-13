"""Skins and selling: catalog, Robux receipts, season premium, starter pack, promo codes."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path('/home/user/gemsoul')
lune = shutil.which("lune") or str(ROOT / ".tools/lune/lune.exe")
subprocess.run([lune, "run", str(ROOT / "tests/skins_store_cases.luau"), str(ROOT)], check=True)
