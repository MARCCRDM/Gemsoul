"""Drive the windowless chat feed: lines and fades, / to type, sending, where it shows (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_chat_feed needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/chat_feed_cases.luau'), str(ROOT)], check=True)
