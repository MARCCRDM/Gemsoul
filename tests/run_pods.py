"""Exercise the personal pods (Shared.Pods, Server.PodServer) on Roblox instances (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_pods needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/pods_cases.luau'), str(ROOT)], check=True)
