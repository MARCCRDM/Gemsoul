from pathlib import Path
import subprocess,re,tempfile
root=Path.cwd()
setup='''
local now=0
local os={clock=function() return now end}
local pending, made={},{}
local task={delay=function(_, fn) table.insert(pending,fn) end}
local function signal()
 local callbacks={}
 return {Once=function(_,fn) table.insert(callbacks,fn) end, Fire=function() local old=callbacks; callbacks={}; for _,fn in old do fn() end end}
end
local Instance={new=function(kind)
 local v={Kind=kind,Ended=signal(),Destroying=signal(),Play=function(self) self.Played=true end}
 function v:Destroy() if self.Dead then return end; self.Dead=true; self.Destroying.Fire(); self.Parent=nil end
 table.insert(made,v); return v
end}
local SoundService={}
local Debris={AddItem=function() end}
local GemConfig={ElementColors={}}
local workspace={Terrain={}}
local Enum={RollOffMode={InverseTapered=1}}
local game={GetService=function(_,name) return ({SoundService=SoundService,Debris=Debris,ReplicatedStorage={}})[name] end}
'''
def module(path,name):
 s=(root/path).read_text(encoding='utf-8');s=re.sub(r'^local GemConfig = require[^\n]+\n','',s,flags=re.M)
 return '\nlocal '+name+'=(function()\n'+s+'\nend)()\n'
code=setup+module('src/client/Modules/CombatSound.luau','CombatSound')+module('src/client/Modules/LotterySound.luau','LotterySound')+'''
local function sounds() local t={} for _,v in made do if v.Kind=="Sound" then table.insert(t,v) end end return t end
for i=1,11 do now+=1; CombatSound.play("Hit") end
assert(#sounds()==22,"ordinary voice budget")
now+=1; CombatSound.play("Hit"); assert(#sounds()==22,"ordinary budget overflow")
CombatSound.play("Parry"); assert(#sounds()==24,"critical cue reservation")
local first=sounds()[1]; first.Ended.Fire(); sounds()[2].Ended.Fire(); sounds()[3].Ended.Fire()
now+=1; CombatSound.play("Swing"); assert(#sounds()==25,"ended voice not released")
first:Destroy(); now+=1; CombatSound.play("Swing"); assert(#sounds()==25,"voice released twice")
local start=#sounds(); LotterySound.play("Reveal5"); assert(#sounds()>start,"reveal missing")
LotterySound.stop()
for i=start+1,#sounds() do assert(sounds()[i].Dead,"lottery voice leaked") end
for _,fn in pending do fn() end
for i=start+1,#sounds() do assert(not sounds()[i].Played or sounds()[i].Dead,"delayed layer escaped cancellation") end
LotterySound.play("Attune"); assert(not sounds()[#sounds()].Dead,"new cue cancelled by old session")
print("PASS: audio voice budget, priority reserve, completion cleanup, duplicate cleanup, lottery stop and restart")
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'audio.luau';p.write_text(code,encoding='utf-8');subprocess.run([str(root/'.tools/luau/luau.exe'),str(p)],check=True)
