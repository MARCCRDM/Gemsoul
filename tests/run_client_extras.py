"""Boots the lobby's newer client extras with Roblox's real instances (needs lune): a wrong property type, or any error, fails it here instead of stopping the lobby in the game."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_client_extras needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/client_extras_boot.luau'), str(ROOT)], check=True, timeout=300)
