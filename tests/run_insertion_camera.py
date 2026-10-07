"""Exercise the real insertion client callbacks with minimal Roblox doubles."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
fixture = (ROOT / 'tests/insertion_camera.luau').read_text(encoding='utf-8')
prefix, cases = fixture.split('-- MODULES HERE')
motion = (ROOT / 'src/shared/InsertionMotion.luau').read_text(encoding='utf-8')
client = (ROOT / 'src/client/ArenaDrop.client.luau').read_text(encoding='utf-8')
client = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', client, flags=re.M)
client = client.replace('require(script.Parent.Modules.LobbyUI)', 'LobbyUI')
source = prefix + '\nlocal Motion = (function()\n' + motion + '\nend)()\ndo\n' + client + '\nend\n' + cases
with tempfile.TemporaryDirectory(prefix='gemsoul-camera-') as directory:
    script = Path(directory) / 'camera.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(script)], check=True)
