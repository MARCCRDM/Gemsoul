"""The Owners' in-game ANALYTICS window's numbers (Shared.AnalyticsReport, Server.AnalyticsPanel, Server.Telemetry's rows since the server started): needs lune."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_analytics needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/analytics_panel_cases.luau'), str(ROOT)], check=True, timeout=300)
