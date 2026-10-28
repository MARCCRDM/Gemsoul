"""The Kaiju Kennel (Shared.KaijuKennel, Client.KennelLife): today's residents and the Kaiju of the Day, where they walk, the pen, its keeper (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_kaiju_kennel needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/kaiju_kennel_cases.luau'), str(ROOT)], check=True)
