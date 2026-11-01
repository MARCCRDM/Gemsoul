"""The game's own event log (Server.Telemetry) and its tools (tools/telemetry): needs lune and Python 3."""
from pathlib import Path
import shutil, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_telemetry needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/telemetry_cases.luau'), str(ROOT)], check=True)
report_test = ROOT / 'tools/telemetry/test_report.py'
if report_test.exists():
    subprocess.run([sys.executable, str(report_test)], check=True)
