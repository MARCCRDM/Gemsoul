"""Ranked win streaks: milestones, Arena Caches, claiming two, the Arena Vault."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune") or str(ROOT / ".tools/lune/lune.exe")
subprocess.run([lune, "run", str(ROOT / "tests/arena_streak_cases.luau"), str(ROOT)], check=True)
