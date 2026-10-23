"""Every armor stat on a phone: the Inventory's stats sheet and piece card (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_inventory_stats needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/inventory_stats_cases.luau'), str(ROOT)], check=True)
