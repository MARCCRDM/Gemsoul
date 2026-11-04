"""Wren's sales window (Client KennelSale), built with real instances: needs lune."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_kennel_sale needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/kennel_sale_cases.luau'), str(ROOT)], check=True, timeout=300)
