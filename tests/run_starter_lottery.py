from pathlib import Path
import subprocess
import tempfile
import re
ROOT=Path(__file__).resolve().parents[1]
def module(name, path):
    text = (ROOT/path).read_text(encoding="utf-8")
    text = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', text, flags=re.M)
    return f'local {name}=(function()\n{text}\nend)()\n'
source=(ROOT/'tests/roblox_primitives.luau').read_text(encoding='utf-8')
source+=module('GemRoller','src/shared/GemRoller.luau')
source+=module('Tech','src/shared/CombatTechnology.luau')
source+=module('Lottery','src/shared/StarterLottery.luau')
source+=(ROOT/"tests/starter_lottery_cases.luau").read_text(encoding="utf-8")
data=(ROOT/"src/server/Systems/PlayerData.luau").read_text(encoding="utf-8")
start=data.index("function PlayerData.socketGem(")
end=data.index("-- The three rig maneuvers",start)
source += "\ndo\n"+(ROOT/"tests/starter_socket_setup.luau").read_text(encoding="utf-8")+"\n"+data[start:end]+"\n"+(ROOT/"tests/starter_socket_cases.luau").read_text(encoding="utf-8")+"\nend\n"
with tempfile.TemporaryDirectory(prefix="gemsoul-launch-") as directory:
    path=Path(directory)/"starter.luau"
    path.write_text(source,encoding="utf-8")
    subprocess.run([str(ROOT/".tools/luau/luau.exe"),str(path)],check=True)
