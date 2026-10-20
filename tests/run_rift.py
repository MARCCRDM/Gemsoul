"""The Rift: its rules (Shared.RiftRun: packs, levels, the bosses and their moves, falling, RESTORE, rewards) and its world (Server.RiftWorld: islands, causeways, walls of fire, ways home, lava) (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_rift needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/rift_cases.luau'), str(ROOT)], check=True)
