"""Bring a friend: the shared rules and the server flow with a fake DataStore."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune") or str(ROOT / ".tools/lune/lune.exe")
subprocess.run([lune, "run", str(ROOT / "tests/referrals_cases.luau"), str(ROOT)], check=True)
