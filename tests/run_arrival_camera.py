"""Run the actual lobby camera handoff with delayed teleport and camera owners."""
from pathlib import Path
import subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
fixture = (ROOT/'tests/arrival_camera_cases.luau').read_text(encoding='utf-8')
setup, cases = fixture.split('-- MODULE HERE')
module = (ROOT/'src/client/Modules/ThirdPerson.luau').read_text(encoding='utf-8')
source = setup+'\nlocal ThirdPerson=(function()\n'+module+'\nend)()\n'+cases
with tempfile.TemporaryDirectory(prefix='gemsoul-arrival-camera-') as directory:
    path = Path(directory)/'camera.luau'
    path.write_text(source,encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(path)],check=True)
