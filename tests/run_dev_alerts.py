"""The Owners' join alert (Server.DevAlerts, Client.DevAlerts): who's new, who's told, what's said (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_dev_alerts needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/dev_alerts_cases.luau'), str(ROOT)], check=True)
