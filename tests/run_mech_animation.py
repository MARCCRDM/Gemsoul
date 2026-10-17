"""Run the real client mech animator against streaming and spectator scenarios."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
env = {"__file__": str(ROOT / "tests/run_meadow_scene.py")}
exec((ROOT / "tests/run_meadow_scene.py").read_text().split("for name, path in")[0], env)
source = env["source"] + r'''
local oldIndex=cmt.__index
cmt.__index=function(a,k)
 if k=="LookVector" then return Vector3.new(-a.r[3],-a.r[6],-a.r[9]) end
 if k=="Inverse" then return function() return CFrame.identity end end -- test rigs have identity rests
 return oldIndex(a,k)
end
local function signal()
 local s={Listeners={}}
 function s:Connect(fn)
  local c={Connected=true,Fn=fn}
  function c:Disconnect() self.Connected=false end
  table.insert(self.Listeners,c)
  return c
 end
 function s:Fire(...)
  for _,c in self.Listeners do if c.Connected then c.Fn(...) end end
 end
 return s
end
local deferred={}
local task={defer=function(fn) table.insert(deferred,fn) end}
local function flush() for _,fn in deferred do fn() end;table.clear(deferred) end
local workspace={CurrentCamera={CFrame=CFrame.identity},GetServerTimeNow=function() return 100 end}
local added,removed=signal(),signal()
local tick=signal()
local function mech(x,partial)
 local m={Tagged=true,InWorld=true,DescendantAdded=signal(),Joints={}}
 function m:IsA(kind) return kind=="Model" end
 function m:IsDescendantOf() return self.InWorld end
 function m:GetAttribute(name) return if name=="MechScale" then 1 else nil end
 function m:GetDescendants() return self.Joints end
 function m:FindFirstChild(name) return self[name] end
 function m:Load()
  self.Chassis={Position=Vector3.new(x,0,0),CFrame=CFrame.new(x,0,0),AssemblyLinearVelocity=Vector3.new(0,0,-24),AssemblyAngularVelocity=Vector3.zero}
  function self.Chassis:IsDescendantOf() return m.InWorld end
  self.Seat={Occupant={},GetAttribute=function() return "Hauler" end,FindFirstChild=function() return nil end}
  for _,name in {"Waist","LeftHip","LeftKnee","LeftAnkle","RightHip","RightKnee","RightAnkle","LeftShoulder","LeftElbow","RightShoulder","RightElbow"} do
   local j={Name=name,Transform=nil}
   function j:IsA(kind) return kind=="Motor6D" end
   function j:GetAttribute() return CFrame.identity end
   table.insert(self.Joints,j)
  end
 end
 if not partial then m:Load() end
 return m
end
local remote,far,partial=mech(10,false),mech(400,false),mech(20,true)
local CollectionService={
 GetTagged=function() return {remote,far,partial} end,
 GetInstanceAddedSignal=function() return added end,
 GetInstanceRemovedSignal=function() return removed end,
 HasTag=function(_,m) return m.Tagged end,
}
local services={CollectionService=CollectionService,ReplicatedStorage={},RunService={PreSimulation=tick}}
local game={GetService=function(_,name) return services[name] end}
'''
source += "local Motion=(function()\n" + (ROOT / "src/shared/MechMotion.luau").read_text() + "\nend)()\n"
source += "local Seating=(function()\n" + (ROOT / "src/shared/Seating.luau").read_text() + "\nend)()\n"
code = (ROOT / "src/client/Modules/MechAnimation.luau").read_text()
code = re.sub(r'^local (Motion|Seating) = require\([^\n]+\)\n', '', code, flags=re.M)
source += "local Animator=(function()\n" + code + "\nend)()\n"
source += r'''
for i=1,60 do tick:Fire(1/60) end
assert(remote.Joints[1].Transform,"Spectator mech never animated")
assert(math.abs(remote.Joints[3].Transform.r[5]-1)>.01,"Walking knee remains rigid")
assert(far.Joints[1].Transform==nil,"Distant rig still animated")
partial:Load();partial.DescendantAdded:Fire();flush();tick:Fire(1/60)
assert(partial.Joints[1].Transform,"Streamed-in rig was never discovered")
remote.Seat.Occupant=nil
for i=1,240 do tick:Fire(1/60) end
assert(math.abs(remote.Joints[1].Transform.Position.Y)<.001,"Empty mech keeps bobbing")
remote.Tagged=false;removed:Fire(remote)
remote.Joints[1].Transform=nil;tick:Fire(1/60)
assert(remote.Joints[1].Transform==nil,"Removed rig still animated")
remote.Tagged=true;added:Fire(remote);tick:Fire(1/60)
assert(remote.Joints[1].Transform,"Re-entering rig wasn't restored")
partial.InWorld=false;tick:Fire(1/60)
partial.Joints[1].Transform=nil;tick:Fire(1/60)
assert(partial.Joints[1].Transform==nil,"Streamed-out rig still animated")
local late=mech(20,true)
added:Fire(late);late:Load();late.DescendantAdded:Fire()
late.Tagged=false;removed:Fire(late);flush();tick:Fire(1/60)
assert(late.Joints[1].Transform==nil,"Deferred registration resurrected removed rig")
print("PASS: spectator walking, distance culling, streamed limbs, idle return, removal, re-entry and deferred cleanup")
'''
script = ROOT / '.tools/mech-animation-test.luau'
try:
    script.write_text(source, encoding='utf-8')
    subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(script)], check=True)
finally:
    script.unlink(missing_ok=True)
