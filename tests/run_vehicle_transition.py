"""Run production driving lifecycle with UI/physics service doubles."""
from pathlib import Path
import subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT/'src/client/Modules/VehicleDrive.luau').read_text()
# Omit only presentation construction and service imports.
logic = source[source.index('local function blocked()'):source.index('-- The driving card.')]
logic += source[source.index('local function finish()'):source.index('return VehicleDrive')]
fixture = (ROOT/'tests/vehicle_transition_cases.luau').read_text()
prefix, cases = fixture.split('-- DRIVE HERE')
with tempfile.TemporaryDirectory(prefix='gemsoul-drive-') as directory:
    script = Path(directory)/'drive.luau'
    script.write_text(prefix + logic + cases)
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'), str(script)], check=True)

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
