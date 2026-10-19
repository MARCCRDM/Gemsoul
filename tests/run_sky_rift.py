"""Run the rift in the Outpost's sky (SkyRift) through its cases: placement, the tear, sparks, shards, surge, cracks."""
from pathlib import Path
import os, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
# (Plain Luau has no Color3; the timing and placement need none of Roblox.)
source = 'local Color3={fromRGB=function(r,g,b) return {r,g,b} end}\n'
source += 'local SkyRift=(function()\n' + read('src/client/Modules/SkyRift.luau') + '\nend)()\n'
world = read('src/server/World/OutpostWorld.luau')
assert ']==]' not in world
source += 'local WorldSource=[==[' + world + ']==]\n'
source += read('tests/sky_rift_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-sky-rift-') as directory:
    script = Path(directory) / 'sky_rift.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
