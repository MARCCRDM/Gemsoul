"""Run the real lobby board and live feed (Modules/LobbyBoard, LobbyFeed) against GUI doubles."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
def module(name, path):
    source = re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', read(path), flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'
source = read('tests/lobby_services.luau')
source += module('Config', 'src/shared/Config.luau')
source += module('Daily', 'src/shared/DailyChallenges.luau')
source += module('Training', 'src/shared/TrainingRewards.luau')
source += module('LobbyBoard', 'src/client/Modules/LobbyBoard.luau')
source += module('Season', 'src/shared/Season.luau')
source += module('MobileLayout', 'src/client/Modules/MobileLayout.luau')
source += module('LobbyFeed', 'src/client/Modules/LobbyFeed.luau')
source += read('tests/lobby_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-lobby-') as directory:
    script = Path(directory) / 'lobby.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
