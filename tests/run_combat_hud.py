"""Execute FoeBars with UI mocks to verify one nameplate and scaled world offsets."""
from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/'tests/roblox_primitives.luau').read_text(encoding='utf-8')
src+=r'''
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2={new=function(a,b,c,d) return {X=UDim.new(a,b),Y=UDim.new(c,d)} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Enum=setmetatable({},{__index=function(_,k) return setmetatable({},{__index=function(_,v) return v end}) end})
local objects={}
local Instance={new=function(kind)
 local obj={ClassName=kind,Enabled=true,Activated={Connect=function() end}}
 function obj:IsA(k) return self.ClassName==k end
 function obj:Destroy() self.Parent=nil;self.Destroyed=true end
 function obj:SetAttribute() end
 function obj:FindFirstChildOfClass(k) for _,o in objects do if o.Parent==self and o.ClassName==k then return o end end end
 table.insert(objects,obj);return obj
end}
local playerGui={}
local player={FindFirstChildOfClass=function() return playerGui end}
local Players={LocalPlayer=player,GetPlayerFromCharacter=function() return nil end}
local now=1
local workspace={GetServerTimeNow=function() return now end}
local os={clock=function() return now end}
local render
local RunService={RenderStepped={Connect=function(_,fn) render=fn end}}
local UserInputService={TouchEnabled=true,KeyboardEnabled=false}
local GemConfig={ElementColors={}}
local UiKit={gui=function() return {} end}
local head={Name="Head",Size=Vector3.new(2,8,2),IsA=function(_,k) return k=="BasePart" end}
local hum={Health=100,MaxHealth=100}
local legacy=Instance.new("BillboardGui");legacy.Name="HealthBar";legacy.Parent=head;legacy.Enabled=false
local descendants={legacy}
local model={Name="Boss",Parent=true}
local drop=0
function model:GetAttribute(k) return if k=="ArenaDropUntil" then drop elseif k=="RivalName" then "Tung Tung" else nil end
function model:FindFirstChild(k) return if k=="Head" then head else nil end
function model:FindFirstChildOfClass() return hum end
function model:GetDescendants() return descendants end
local foes={model}
local TargetLock={foes=function() return foes end,target=function() return model end,select=function() end}
'''
code=(ROOT/'src/client/Modules/FoeBars.luau').read_text(encoding='utf-8')
code=re.sub(r'^local \w+ = (?:require\([^\n]+\)|game:GetService\([^\n]+\))\n','',code,flags=re.M)
src+='local FoeBars=(function()\n'+code+'\nend)()\n'
src+=r'''
render(.1)
local board
for _,o in objects do if o.Name=="FoeHealth" and not o.Destroyed then assert(not board,"duplicate health bars");board=o end end
assert(board and not legacy.Enabled,"Legacy bar remained visible")
assert(board.Adornee==head and board.StudsOffsetWorldSpace.Y>head.Size.Y/2,"Nameplate not above boss head")
assert(hum.HealthDisplayType=="AlwaysOff" and hum.DisplayDistanceType=="None","Default overhead duplicated")
head.Size=Vector3.new(2,12,2);now+=.2;render(.1)
assert(board.StudsOffsetWorldSpace.Y>6,"Scaled boss offset stale")
legacy.Enabled=true;now+=.2;render(.1)
assert(not legacy.Enabled,"Server update restored duplicate bar")
local late=Instance.new("BillboardGui");late.Name="HealthBar";late.Parent=head
 table.insert(descendants,late);now+=.2;render(.1)
assert(not late.Enabled,"Late legacy bar remained visible")
foes={};now+=.2;render(.1)
assert(board.Destroyed and not legacy.Enabled,"Nameplate cleanup failed")
print("PASS: single enemy bar, head-relative world placement, scaled bosses and cleanup")
'''
with tempfile.TemporaryDirectory(prefix='gemsoul-hud-') as d:
 path=Path(d)/'hud.luau';path.write_text(src,encoding='utf-8')
 subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(path)],check=True)
