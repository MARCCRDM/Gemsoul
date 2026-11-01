"""Dev and test accounts left out of every number (Server.DevAccounts, with Analytics, Funnel, Telemetry and Shared.AnalyticsReport): needs lune."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_dev_accounts needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/dev_accounts_cases.luau'), str(ROOT)], check=True, timeout=120)
