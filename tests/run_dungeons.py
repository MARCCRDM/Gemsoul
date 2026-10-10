"""Exercise actual dungeon rules and lifecycle with deterministic service doubles."""
from pathlib import Path
import re,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
def read(p): return (root/p).read_text(encoding='utf-8')
def module(name,p):
 s=re.sub(r'^local \w+\s*=\s*(?:require\([^\n]+\)|game:GetService\([^\n]+\))\n','',read(p),flags=re.M)
 return 'local '+name+'=(function()\n'+s+'\nend)()\n'
s=read('tests/duels_services.luau').replace('Changed = {}','Changed = {}, CharacterRemoving = signal(), CharacterAdded = signal()').replace('p.Humanoid, p.Root = humanoid, root', 'p.Character.WaitForChild = function(_, key) return if key == "Humanoid" then humanoid elseif key == "HumanoidRootPart" then root else nil end\n p.Humanoid, p.Root = humanoid, root')
s+=module('Slots','src/shared/EquipmentSlots.luau')
s+=module('MinerRoster','src/shared/MinerRoster.luau')
s+=module('ElementMatchup','src/shared/ElementMatchup.luau')
s+=module('Rules','src/shared/DungeonRules.luau')
s+=module('GemRoller','src/shared/GemRoller.luau')
s+='local dungeonLethal\n'
s+=read('tests/dungeon_services.luau')
s+='CombatServer.onDungeonLethal=function(hook) dungeonLethal=hook end\nPlayerData.selectMiner=function(p,index) return MinerRoster.switch(profiles[p],index) end\n'
s+=module('Dungeon','src/server/Systems/Dungeons.luau')
s+=read('tests/dungeon_cases.luau')
s+=read('tests/miner_dungeon_cases.luau')
s+=module('Ambient','src/server/Systems/ExpeditionAmbient.luau')
s+=read('tests/expedition_ambient_cases.luau')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'dungeons.luau';p.write_text(s,encoding='utf-8')
 subprocess.run([str(root/'.tools/luau/luau.exe'),str(p)],check=True)
