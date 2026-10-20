"""The quarry's life (QuarryLife): the road lights in their frontier bands' colours, the searchlights, the meteor showers, the cargo lifter clear of everything, the dust devils, the vents and the conveyor's ore (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_quarry_life needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/quarry_life_cases.luau'), str(ROOT)], check=True)
