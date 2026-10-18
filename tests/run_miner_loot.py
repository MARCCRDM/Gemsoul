"""Drive the miner's own loot card: roll, landing, stats, fast stacking, phone fit, above a mech's driving card, cleanup."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
source = read('tests/roblox_primitives.luau').split('local built = 0')[0]
source += read('tests/miner_loot_services.luau')
for name, path in [('ExpeditionEconomy', 'src/shared/ExpeditionEconomy.luau'), ('GemConfig', 'src/shared/GemConfig.luau'),
                   ('GemTraits', 'src/shared/GemTraits.luau'), ('GemRoller', 'src/shared/GemRoller.luau'),
                   ('LootStack', 'src/client/Modules/LootStack.luau'),
                   ('MobileLayout', 'src/client/Modules/MobileLayout.luau'), ('Loot', 'src/client/Modules/MinerLoot.luau')]:
    code = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', read(path), flags=re.M)
    source += f'\nlocal {name} = (function()\n{code}\nend)()\n'
source += read('tests/miner_loot_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-miner-loot-') as directory:
    script = Path(directory) / 'miner_loot.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
