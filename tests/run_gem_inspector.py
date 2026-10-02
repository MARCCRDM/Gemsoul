"""Exercise the real gem inspector controls, camera fitting and metric rows."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
art = (ROOT / "src/client/Modules/GemArt.luau").read_text(encoding="utf-8")
ui = (ROOT / "src/client/Modules/CharacterUI.luau").read_text(encoding="utf-8")
source = (ROOT / "tests/roblox_primitives.luau").read_text(encoding="utf-8")
source += r'''
local CAMERA_FOV = 34
local UDim2={fromScale=function(...) return {...} end}
CFrame.lookAt = function(position, target) return {Position=position, Target=target} end
local latestModel, latestCamera, latestViewport
local Instance = {new=function(class)
 local object = {ClassName=class, AbsoluteSize={X=156,Y=166}}
 function object:GetPropertyChangedSignal(_property)
  return {Connect=function(_,callback) self.Resize=callback end}
 end
 if class == "ViewportFrame" then latestViewport=object end
 return object
end}
local GemArt = {}
function GemArt.model(_gem, detailed)
 assert(detailed, "Inspector must use detailed facets")
 latestModel={PivotTo=function(self, pose) self.Pose=pose end}
 return latestModel, 1.5
end
function GemArt.setupViewport(_view) latestCamera={}; return latestCamera end
function GemArt.pose(_gem, spin) return CFrame.new(spin,0,0) end
'''
source += art[art.index("function GemArt.inspectorViewport"):art.rindex("return GemArt")]
source += r'''
local angles={Spin=0.6,Tilt=0}
local viewport, controls = GemArt.inspectorViewport({}, {Cut=6}, angles)
assert(latestModel.Parent==viewport and latestModel.Pose, "Inspector geometry missing")
local angle = math.rad(17)
for _,size in {{X=156,Y=166},{X=100,Y=300},{X=300,Y=100},{X=0,Y=0}} do
 viewport.AbsoluteSize=size
 viewport.Resize()
 local distance=latestCamera.CFrame.Position.Z
 assert(distance==distance and distance<math.huge and distance>1.5, "Invalid camera distance")
 local aspect=if size.Y>0 then math.max(size.X/size.Y,0.1) else 1
 local limit=math.min(angle,math.atan(math.tan(angle)*aspect))
 assert(distance*math.sin(limit)>=1.5, "Gem clips at the inspector's aspect ratio")
end
controls.Rotate(math.pi/6)
assert(math.abs(angles.Spin-0.6-math.pi/6)<1e-6, "Right rotation ignored")
controls.Rotate(-math.pi/6)
assert(math.abs(angles.Spin-0.6)<1e-6, "Left rotation ignored")
controls.Tilt(); assert(angles.Tilt==-35)
controls.Tilt(); assert(angles.Tilt==25)
controls.Tilt(); assert(angles.Tilt==0)
controls.Rotate(20); controls.Tilt(); controls.Reset()
assert(angles.Spin==0.6 and angles.Tilt==0, "Reset does not restore the default view")
print("PASS: detailed gem preview; camera fits portrait/landscape; left/right, three tilts and reset")

local made={}
local function new(class, properties, parent)
 properties.ClassName=class; properties.Parent=parent
 table.insert(made,properties)
 return properties
end
local function text(parent,value,_size,color,_font)
 return new("TextLabel",{Text=value,TextColor3=color},parent)
end
local UDim2={new=function(...) return {...} end,fromOffset=function(...) return {...} end}
local UiKit={round=function() end}
local P={Dim="Dim",Slot="Empty"}
local BOLD="Bold"
'''
source += ui[ui.index("local function gemMetric"):ui.index("local function gemLines")]
source += r'''
for _,grade in {1,3,8,10} do
 table.clear(made)
 gemMetric({},"CLARITY",grade,"Filled",0)
 local cells,filled,label=0,0,nil
 for _,object in made do
  if object.BackgroundColor3 then
   cells+=1
   if object.BackgroundColor3=="Filled" then filled+=1 end
  end
  if object.Text==tostring(grade).." / 10" then label=object end
 end
 assert(cells==10 and filled==grade and label, "Metric bar disagrees with its numeric grade")
end
table.clear(made)
gemMetric({},"CUT",nil,"Filled",0)
local rough=false
for _,object in made do
 assert(object.BackgroundColor3~="Filled", "Rough gem displays a fabricated Cut grade")
 if object.Text=="ROUGH" then rough=true end
end
assert(rough, "Rough state not labeled")
print("PASS: ten-segment metric bars agree with grades; rough Cut stays ungraded")
'''
with tempfile.TemporaryDirectory(prefix="gemsoul-inspector-") as directory:
    script = Path(directory) / "inspector.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
