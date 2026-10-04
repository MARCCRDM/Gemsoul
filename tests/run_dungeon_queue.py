from pathlib import Path
import re,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
def read(p): return (root/p).read_text(encoding='utf-8')
def module(name,p):
 s=re.sub(r'^local \w+\s*=\s*(?:require\([^\n]+\)|game:GetService\([^\n]+\))\n','',read(p),flags=re.M)
 return 'local '+name+'=(function()\n'+s+'\nend)()\n'
s=read('tests/duels_services.luau')
s+='''
local checks=0
local function check(v,m) checks+=1;assert(v,m) end
Remotes.Party={FireClient=function() end}
PlayerData.character=function() return nil end
local Classes={}
local launches={}
local Dungeon={queueParty=function(p) table.insert(launches,p);return {Ok=true} end}
local Raids={busy=function(p) return p:GetAttribute("CombatSession") end}
'''
s+=module('Party','src/server/Systems/Party.luau')
s+=module('Queue','src/server/Systems/DungeonQueue.luau')
s+=read('tests/dungeon_queue_cases.luau')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'queue.luau';p.write_text(s,encoding='utf-8')
 subprocess.run([str(root/'.tools/luau/luau.exe'),str(p)],check=True)
