"""The base's signs: one word a sign, the HUD's words; no taglines, invented names, biome signs or zone title cards (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_signage needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/signage_cases.luau'), str(ROOT)], check=True)
