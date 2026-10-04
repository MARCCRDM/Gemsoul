"""Check chest/pelvis geometry ownership and joint clearance using the real armor builder."""
from pathlib import Path
import re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
def read(p):return (ROOT/p).read_text(encoding="utf-8")
def module(name,p):
 s=re.sub(r'^local \w+ = require\([^\n]+\)\n','',read(p),flags=re.M)
 return 'local '+name+'=(function()\n'+s+'\nend)()\n'
s=read('tests/roblox_primitives.luau')
for name,path in [('EquipmentBalance','src/shared/EquipmentBalance.luau'),('ExpeditionEconomy','src/shared/ExpeditionEconomy.luau'),('CrowdControl','src/shared/CrowdControl.luau'),('GemConfig','src/shared/GemConfig.luau'),('ArmorFamilies','src/shared/ArmorFamilies.luau'),('ArmorKits','src/server/Systems/ArmorKits.luau')]:s+=module(name,path)
equipment=read('tests/equipment_cases.luau')
s+=equipment[equipment.index('local function rig(r15)'):equipment.index('local builds = 0')]
s+=read('tests/armor_articulation_cases.luau')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'articulation.luau';p.write_text(s,encoding='utf-8')
 subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(p)],check=True)
