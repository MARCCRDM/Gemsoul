"""Exercise the real duel queue, challenges and matches (Duels.luau) with deterministic doubles."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
def module(name, path):
    source = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', read(path), flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'

source = read('tests/duels_services.luau')
source += module('PvPRules', 'src/shared/PvPRules.luau')
source += module('Matchmaking', 'src/shared/Matchmaking.luau')
source += module('Season', 'src/shared/Season.luau')
source += 'Duels=(function()\n' + re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', read('src/server/Systems/Duels.luau'), flags=re.M) + '\nend)()\n'
source += read('tests/duels_cases.luau')
source += 'local Raids=(function()\n' + re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', read('src/server/Systems/Raids.luau'), flags=re.M) + '\nend)()\n'
source += read('tests/raids_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if os.name == 'nt' and luau.exists() else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-duels-') as directory:
    script = Path(directory) / 'duels.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
