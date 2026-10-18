"""Run the pilot's screen (Client VehicleDrive) and the arena/lobby control handoff.

The driving needs lune (https://github.com/lune-org/lune) on PATH.
"""
from pathlib import Path
import shutil, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_vehicle_transition needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/vehicle_drive_cases.luau'), str(ROOT)], check=True)

# Exercise the actual scene handoff that owns Roblox's movement/vehicle inputs.
import re
arena = (ROOT/'src/client/Modules/ArenaScene.luau').read_text()
arena = re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', arena, flags=re.M)
arena = arena.replace('return ArenaScene', '')
fixture = (ROOT/'tests/arena_controls_cases.luau').read_text()
prefix, cases = fixture.split('-- ARENA HERE')
with tempfile.TemporaryDirectory(prefix='gemsoul-arena-controls-') as directory:
    script = Path(directory)/'controls.luau'
    script.write_text(prefix + arena + cases)
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'), str(script)], check=True)
