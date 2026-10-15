"""Exercise the actual shared lottery timeline, server publisher and world renderer."""
from pathlib import Path
import re, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding='utf-8')
def module(name,path):
    source=re.sub(r'^local \w+ = require\([^\n]+\)\n','',read(path),flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'
source=read('tests/roblox_primitives.luau').split('local built = 0')[0]
source+=read('tests/world_mining_services.luau')
for name,path in [('ExpeditionEconomy','src/shared/ExpeditionEconomy.luau'),('GemConfig','src/shared/GemConfig.luau'),
                  ('GemTraits','src/shared/GemTraits.luau'),('GemRoller','src/shared/GemRoller.luau'),
                  ('Roll','src/shared/MiningRoll.luau'),('MiningRolls','src/server/Systems/MiningRolls.luau'),
                  ('Reveal','src/client/Modules/MiningWorldReveal.luau')]:
    source+=module(name,path)
source+=read('tests/world_mining_cases.luau')
with tempfile.TemporaryDirectory(prefix='gemsoul-world-mining-') as directory:
    path=Path(directory)/'world.luau'
    path.write_text(source,encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(path)],check=True)
