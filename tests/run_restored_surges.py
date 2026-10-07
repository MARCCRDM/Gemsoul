"""Original roster, all-rarity access, one-property scaling, and save compatibility."""
from pathlib import Path
import json, re, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
def module(name, path):
    text = (ROOT/path).read_text(encoding='utf-8')
    text = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', text, flags=re.M)
    text = re.sub(r'^local ReplicatedStorage = .*\n', '', text, flags=re.M)
    return f'local {name}=(function()\n{text}\nend)()\n'
source=(ROOT/'tests/roblox_primitives.luau').read_text(encoding='utf-8')
for name,path in [('GemRoller','src/shared/GemRoller.luau'),('Tech','src/shared/CombatTechnology.luau'),('Atlas','src/client/Modules/AbilityIconAtlas.luau'),('Icons','src/client/Modules/SurgeIcons.luau'),('Lottery','src/shared/StarterLottery.luau')]:
    source+=module(name,path)
archive=json.loads((ROOT/'docs/surge-archive/legacy-surges.json').read_text(encoding='utf-8'))
for entry in archive['Abilities']:
    source+=f'assert(Tech.Catalog[{json.dumps(entry["Id"])}].Name == {json.dumps(entry["Name"])}, "Archive identity changed")\n'
source+=(ROOT/'tests/restored_surges_cases.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='gemsoul-restored-surges-') as directory:
    script=Path(directory)/'restored.luau'; script.write_text(source,encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(script)],check=True)
