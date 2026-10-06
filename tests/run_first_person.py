"""Run the real first-person module's enter/render/exit lifecycle with service mocks."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
setup = r'''
local Enum = { CameraMode = {LockFirstPerson="First"}, MouseBehavior={Default="Free",LockCenter="Locked"}, RenderPriority={Camera={Value=200}} }
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
local camera = {Parent=true,FieldOfView=62}
local workspace = {CurrentCamera=camera, GetServerTimeNow=function() return os.clock() end}
local input = {MouseEnabled=true, MouseBehavior="Free", MouseIconEnabled=true}
local run = {
 BindToRenderStep=function(_, name, priority, fn) assert(name=="SagaFirstPerson" and priority==203); bound=fn; bindCount+=1 end,
 UnbindFromRenderStep=function() bound=nil end,
}
local services = {Players={LocalPlayer=player},RunService=run,UserInputService=input,ReplicatedStorage={Shared={InsertionMotion="InsertionMotion"}}}
local game = {GetService=function(_, name) return services[name] end}
'''
# The module's shared requires, resolved to their real sources.
setup += "local InsertionMotion=(function()\n" + (ROOT / "src/shared/InsertionMotion.luau").read_text(encoding="utf-8") + "\nend)()\n"
setup += "local require=function(name) if name==\"InsertionMotion\" then return InsertionMotion end return require(name) end\n"
source = setup + "\nlocal View=(function()\n" + (ROOT / "src/client/Modules/FirstPersonCombat.luau").read_text(encoding="utf-8") + "\nend)()\n" + (ROOT / "tests/first_person_cases.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="gemsoul-first-person-") as directory:
    script = Path(directory) / "camera.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
