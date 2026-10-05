"""Exercise the Market board (escrow, sales, trades, races, no dupes) with the real MarketBoard (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_market needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/market_cases.luau'), str(ROOT)], check=True)
