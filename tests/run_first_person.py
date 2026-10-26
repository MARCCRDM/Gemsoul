"""Run the real first-person module's enter/render/exit lifecycle with service mocks."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
setup = r'''
local Enum = { CameraMode = {LockFirstPerson="First", Classic="Classic"}, CameraType={Custom="Custom", Scriptable="Scriptable"}, MouseBehavior={Default="Free",LockCenter="Locked"}, RenderPriority={Camera={Value=200}} }
local disconnected, bound, bindCount = false, nil, 0
local removalCallback, removalDisconnected
local part = { Parent=true, LocalTransparencyModifier=0.25, IsA=function(_, kind) return kind=="BasePart" end }
local character = {
 GetDescendants=function() return {part} end,
 FindFirstChild=function() return nil end,
 FindFirstChildOfClass=function() return nil end,
 GetAttribute=function() return nil end,
 DescendantRemoving={Connect=function(_, fn) removalCallback=fn; removalDisconnected=false; return {Disconnect=function() removalDisconnected=true end} end},
 DescendantAdded={Connect=function() disconnected=false; return {Disconnect=function() disconnected=true end} end},
}
local player = {Character=character, CameraMode="Classic", CameraMinZoomDistance=1, CameraMaxZoomDistance=80, GetAttribute=function() return nil end}
local camera = {Parent=true,FieldOfView=62,CameraType="Custom"}
local workspace = {CurrentCamera=camera, GetServerTimeNow=function() return os.clock() end}
local input = {MouseEnabled=true, MouseBehavior="Free", MouseIconEnabled=true}
local backOutStep
local run = {
 BindToRenderStep=function(_, name, priority, fn)
  if name=="SagaThirdPersonReturn" then assert(priority==202); backOutStep=fn; return end
  assert(name=="SagaFirstPerson" and priority==203); bound=fn; bindCount+=1
 end,
 UnbindFromRenderStep=function(_, name) if name=="SagaThirdPersonReturn" then backOutStep=nil else bound=nil end end,
}
-- Just enough vector maths for the camera's way back out.
local vmt = {}
local Vector3 = {new=function(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vmt) end}
vmt.__add = function(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
vmt.__sub = function(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
vmt.__mul = function(a, b) return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
vmt.__index = function(a, key)
 if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if key=="Unit" then return a*(1/a.Magnitude) end
end
local CFrame = {lookAt=function(eye, focus) return {Position=eye, LookVector=(focus-eye).Unit} end}
-- The mining worlds' camera (its own range and how far back it starts), while it's on.
local tpRange, tpHome = {}, nil
local ThirdPerson = {range=function() return tpRange[1], tpRange[2] end, home=function() return tpHome end}
local services = {Players={LocalPlayer=player},RunService=run,UserInputService=input,ReplicatedStorage={Shared={InsertionMotion="InsertionMotion",CombatActions="CombatActions"}}}
local game = {GetService=function(_, name) return services[name] end}
'''
# The module's requires (shared and sibling), resolved to their real sources.
setup += "local InsertionMotion=(function()\n" + (ROOT / "src/shared/InsertionMotion.luau").read_text(encoding="utf-8") + "\nend)()\n"
setup += "local ViewGrip=(function()\n" + (ROOT / "src/client/Modules/ViewGrip.luau").read_text(encoding="utf-8") + "\nend)()\n"
setup += "local LiveLooks=(function()\n" + (ROOT / "src/client/Modules/LiveLooks.luau").read_text(encoding="utf-8") + "\nend)()\n"
setup += "local script={Parent={ViewGrip=\"ViewGrip\",LiveLooks=\"LiveLooks\",ThirdPerson=\"ThirdPerson\"}}\n"
setup += "local CombatActions={Base={Heavy={Charge=0.45}},PerfectAt=0.75,OverchargeAt=1.15}\nlocal require=function(name) if name==\"InsertionMotion\" then return InsertionMotion end if name==\"CombatActions\" then return CombatActions end if name==\"ViewGrip\" then return ViewGrip end if name==\"LiveLooks\" then return LiveLooks end if name==\"ThirdPerson\" then return ThirdPerson end return require(name) end\n"
source = setup + "\nlocal View=(function()\n" + (ROOT / "src/client/Modules/FirstPersonCombat.luau").read_text(encoding="utf-8") + "\nend)()\n" + (ROOT / "tests/first_person_cases.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="gemsoul-first-person-") as directory:
    script = Path(directory) / "camera.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
