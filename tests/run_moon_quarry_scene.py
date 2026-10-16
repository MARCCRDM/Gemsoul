"""Exercise the restored quarry, real vehicle builders and lighting transitions.

Offline Roblox primitives verify geometry/contracts, not in-engine physics/rendering.
"""
from pathlib import Path
import subprocess
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
env = {"__file__": str(ROOT / "tests/run_meadow_scene.py")}
exec((ROOT / "tests/run_meadow_scene.py").read_text().split("for name, path in")[0], env)
source = env["source"]
source = source.replace('if key == "Color" then', 'if key == "Color" and className ~= "ParticleEmitter" then')
source += r'''
local oldVectorIndex=vmt.__index
vmt.__index=function(a,k)
 if k=="Lerp" then return function(x,y,t) return x+(y-x)*t end end
 return oldVectorIndex(a,k)
end
local oldFrameIndex=cmt.__index
cmt.__index=function(a,k)
 if k=="LookVector" then return Vector3.new(-a.r[3],-a.r[6],-a.r[9]) end
 if k=="ToOrientation" then return function(x) return 0,math.atan2(x.r[3],x.r[9]),0 end end
 return oldFrameIndex(a,k)
end
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
UDim2.fromScale=UDim2.new
local NumberRange={new=function(...) return {...} end}
local NumberSequence=NumberRange
local ColorSequence=NumberRange
local PhysicalProperties=NumberRange
local instances={}
local newInstance=Instance.new
Instance.new=function(kind)
 local object=newInstance(kind)
 table.insert(instances,object)
 return object
end
'''
for name, path in [
    ("Rules", "src/shared/Outpost.luau"),
    ("World", "src/server/World/OutpostWorld.luau"),
    ("Machines", "src/server/World/OutpostMachines.luau"),
    ("Motion", "src/shared/MechMotion.luau"),
]:
    source += f"local {name}=(function()\n{(ROOT / path).read_text(encoding='utf-8')}\nend)()\n"
source += r'''
local origin=CFrame.new(0,0,7000)
local site=World.build(origin,{})
assert(site.Model.Landscape=="Moon Quarry" and site.Model.SkySetting=="MoonBase")
assert(#site.Secrets==0 and #site.FieldSpots==0,"Retired extras returned")
assert(site.Spawn.Position.X==0 and site.Spawn.Position.Z==7058 and site.Spawn.Position.Y==3.5,"Spawn must face the field from the front of the pad")
assert(#site.ArrivalSpots==8,"Welcome mining field missing")
for _,index in site.ArrivalSpots do
 local p=site.Spots[index].Position-origin.Position
 assert(p.Z<30 and math.abs(p.X)>=12 and math.abs(p.X)<=26,"Welcome nodes block the central path")
end
assert(site.Probe.Name=="ProbeScreen" and site.Board.Name=="BoardFace" and site.Gate.Name=="GatePad","Missing lobby services")
assert(Rules.Radius==440 and Rules.NodeCount==110 and Rules.FieldNodeCount==0,"Lobby bounds/population mismatch")
assert(#site.Spots>=Rules.NodeCount,"Too few mining sites")
local roads,sky,ramps,floor,motor,base=0,0,0,nil,0,0
for _,p in builtParts do
 assert(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,"Invalid geometry")
 assert(math.max(p.Size.X,p.Size.Y,p.Size.Z)<=2048,"Roblox size limit exceeded")
 local name=p.Parent and p.Parent.Name
 if name=="Sky" then
  sky+=1
  assert(not p.CanCollide and not p.CanTouch and not p.CanQuery,"Sky blocks gameplay")
 end
 if name=="Roads" then
  roads+=1
  if p.ClassName=="WedgePart" and p.CanCollide then ramps+=1 end
 end
 if name=="MotorPool" then motor+=1 end
 if name=="Outpost" then base+=1 end
 if p.CanCollide and p.Size.Y==1040 and p.Size.Z==1040 then floor=p end
 assert(p.Name~="GrassSurface" and p.Name~="MeadowCloudBank" and p.Name~="Secret","Old lobby/retired secrets leaked")
end
assert(floor and math.abs(floor.CFrame.t[2]+floor.Size.X/2)<.001,"Quarry floor missing or wrong height")
assert(roads>100 and ramps==5 and sky>=260 and motor>20 and base>200,"Original quarry landmarks missing")
assert(#builtParts<4000,"Quarry scenery budget exceeded")
for i,spot in site.Spots do
 local p=spot.Position-origin.Position
 assert(site.Zones[i]=="Common" and math.abs(p.Y)<.001 and p.Magnitude<Rules.Radius,"Unsafe mining position/zone")
 assert((p-Vector3.new(0,0,150)).Magnitude>=84,"Rock in Motor Pool")
 assert((p-Vector3.new(0,0,70)).Magnitude>=40,"Rock in arrival area")
 for j=i+1,#site.Spots do
  assert((spot.Position-site.Spots[j].Position).Magnitude>=12,"Mining nodes overlap")
 end
 -- All radial haul roads and the ring road stay clear for machines.
 local radius=Vector3.new(p.X,0,p.Z).Magnitude
 assert(math.abs(radius-260)>12,"Mining body on ring road")
 for spoke=0,5 do
  local a=spoke/6*math.pi*2+math.rad(30)
  local direction=Vector3.new(math.cos(a),0,math.sin(a))
  local closest=direction*math.clamp(p:Dot(direction),60,420)
  assert((p-closest).Magnitude>=14,"Mining body on haul road")
 end
end
for i=0,10000 do
 local size=Rules.rollSize(i/10001,"Common")
 assert(size=="Pebble" or size=="Boulder","Rare mining object returned")
end
print("PASS: quarry "..#builtParts.." scenery parts; "..#site.Spots.." clear mining sites; 5 ramps; services and safe sky")
local counts={Hauler=0,Mole=0,Digger=0,Skipper=0}
assert(#site.Parking==8,"Motor Pool has missing bays")
for _,bay in site.Parking do
 counts[bay.Kind]+=1
 local vehicle=Machines.build(bay.Kind,bay.CFrame)
 assert(vehicle.PrimaryPart.Name=="Chassis" and vehicle.PrimaryPart.CanCollide,"Vehicle has no physics chassis")
 local seat,drive,steer,drill=nil,nil,nil,nil
 local joints={}
 for _,object in instances do
  if object.Parent==vehicle and object.Name=="Seat" then seat=object end
  if object.Parent==vehicle.PrimaryPart and object.Name=="Drive" then drive=object end
  if object.Parent==vehicle.PrimaryPart and object.Name=="Steer" then steer=object end
  if object.ClassName=="Motor6D" and object.Parent and object.Parent.Parent==vehicle then
   joints[object.Name]=object
   assert(object.Part0 and object.Part1 and object.Part1.Parent==vehicle,"Broken mech joint")
   if object.Name=="ToolRotor" then drill=object end
  end
 end
 assert(seat and seat.OutpostMachine==bay.Kind,"Driver seat identity missing")
 assert(drive and steer and drive.VelocityConstraintMode=="Plane","Driving constraints missing")
 if bay.Kind=="Mole" then assert(drill,"Mole drill motor missing") end
 assert(vehicle.Mech and vehicle.CameraFit>=20,"Mech identity/camera fit missing")
 for _,name in {"Waist","LeftHip","LeftKnee","LeftAnkle","RightHip","RightKnee","RightAnkle","LeftShoulder","LeftElbow","RightShoulder","RightElbow"} do
  assert(joints[name],"Missing animated joint: "..name)
 end
 assert(seat.Position.Y>8 and seat.Position.Y<14,"Cockpit seat outside frame")
 local total=0
 for _,part in builtParts do
  if part.Parent==vehicle then
   total+=1
   if part.Name~="Chassis" then assert(not part.CanCollide and part.Massless,"Cosmetic body obstructs walking") end
  end
 end
 assert(total>120 and total<240,"Mech detail budget changed: "..total)
 local bottom=vehicle.PrimaryPart.Position.Y-vehicle.PrimaryPart.Size.Y/2
 assert(bottom>=.8,"Vehicle spawned in Motor Pool floor")
 assert((bay.CFrame.Position-origin.Position).Magnitude<Rules.Radius,"Vehicle outside recovery boundary")
end
assert(counts.Hauler==2 and counts.Mole==2 and counts.Digger==1 and counts.Skipper==3,"Original vehicle mix changed")
for _,size in {"Pebble","Boulder"} do
 local rock=World.rock(size,site.Spots[1],Random.new(55))
 assert(rock.PrimaryPart.Name=="Body" and rock.PrimaryPart.CanCollide,"Mining collision body lost")
end
print("PASS: all 8 mech rigs, cockpit seats, walking joints, tool motors, detail budget and floor clearance; basic rock builders")
for _,kind in Rules.MachineOrder do
 local spec=Rules.Machines[kind]
 local speed,yaw=0,0
 for i=1,600 do speed,yaw=Rules.drive(spec,speed,yaw,1,0,1/60) end
 assert(math.abs(speed-spec.MaxSpeed)<.001 and yaw==0,"Mech acceleration/top speed")
 local _,turn=Rules.drive(spec,0,0,0,1,.1)
 assert(turn<0,"Mech cannot pivot in place")
 for i=1,600 do speed=Rules.drive(spec,speed,0,-1,0,1/60) end
 assert(math.abs(speed+spec.MaxSpeed*Rules.ReverseShare)<.001,"Mech reverse limit")
end
local state=Motion.new()
for i=1,120 do Motion.step(state,1/60,24,0,true) end
assert(state.Weight>.99,"Walk never blends in")
local phase=state.Phase
Motion.step(state,.01,-10,0,true)
assert(state.Phase<phase or phase<.1,"Reverse gait has wrong direction")
for _,weight in {0,.2,.6,1} do
 for sample=0,100 do
  local poses=Motion.pose({Phase=sample/100*math.pi*2,Weight=weight},1,sample,true)
  for _,side in {"Left","Right"} do
   local hip=poses[side.."Hip"]
   local foot=hip*CFrame.new(0,-3.6,0)*poses[side.."Knee"]*CFrame.new(0,-3.6,0)*poses[side.."Ankle"]
   assert(foot.Position.Y>=-6.801,"Foot penetrates floor during walk")
   assert(math.abs(foot.r[5]-1)<.001,"Boot does not stay level")
   assert(math.abs(foot.Position.Z)<=2.101,"Foot leaves stride bounds")
  end
 end
end
for i=1,180 do Motion.step(state,1/60,0,0,false) end
assert(state.Weight<.001,"Empty mech keeps walking")
print("PASS: all mech drive profiles and 808 IK foot samples; level boots, reverse gait and idle blend")
-- Actual builder geometry for the optional preview, one of each frame at origin.
for _,kind in Rules.MachineOrder do
 local vehicle=Machines.build(kind,CFrame.identity)
 for _,p in builtParts do
  if p.Parent==vehicle and (p.Transparency or 0)<.95 then
   local row={kind,p.Name,p.ClassName,p.Shape or "Block",p.Material,tostring(p.Transparency or 0)}
   for _,v in {p.Size.X,p.Size.Y,p.Size.Z,p.Color.R,p.Color.G,p.Color.B} do table.insert(row,tostring(v)) end
   for _,v in p.CFrame.t do table.insert(row,tostring(v)) end
   for _,v in p.CFrame.r do table.insert(row,tostring(v)) end
   print("MECH|"..table.concat(row,"|"))
  end
 end
end
'''
server = (ROOT / "src/server/Systems/OutpostServer.luau").read_text(encoding="utf-8")
spawn_node = server[server.index("local function spawnNode("):server.index("-- A rock popped:")]
source += r'''
do
local freeSpots,fieldSpots,nodes={},{},{}
local nodesFolder={}
local nextId=0
local rng=Random.new(45)
local OutpostWorld=World
local OutpostServer={Tag="MineNode"}
local CollectionService={AddTag=function() end}
for i in site.Spots do freeSpots[i]=true end
''' + spawn_node + r'''
for i=1,Rules.NodeCount do spawnNode() end
assert(nextId==110,"Welcome nodes changed total population")
for _,i in site.ArrivalSpots do assert(not freeSpots[i],"Random population left welcome field empty") end
local arrivalIndex=site.ArrivalSpots[1]
for id,node in nodes do if node.Spot==arrivalIndex then nodes[id]=nil end end
freeSpots[arrivalIndex]=true
spawnNode()
assert(nodes[nextId].Spot==arrivalIndex,"Welcome rock did not replenish")
local occupied={}
for _,node in nodes do
 assert(not occupied[node.Spot],"Mining nodes share a site")
 occupied[node.Spot]=true
end
-- A field-only request must not consume common welcome positions.
freeSpots[arrivalIndex]=true
local before=nextId
spawnNode(true)
assert(nextId==before and freeSpots[arrivalIndex],"Zone filter bypassed by arrival priority")
print("PASS: actual server node population, 8 welcome rocks, 110-node cap, replenishment and zone isolation")
end
'''
lighting = (ROOT / "src/client/Modules/Scenes.luau").read_text(encoding="utf-8")
lighting = lighting[lighting.index("function Scenes.spaceLighting()"):lighting.rindex("return Scenes")]
source += r'''
do
local function holder()
 local h={Children={}}
 function h:FindFirstChildOfClass(kind)
  for _,child in self.Children do if child.ClassName==kind then return child end end
 end
 return h
end
local Lighting,terrain=holder(),holder()
local workspace={FindFirstChildOfClass=function() return terrain end}
local Instance={new=function(kind)
 local values={ClassName=kind}
 return setmetatable({}, {__index=values,__newindex=function(o,k,v)
  if k=="Parent" and v and v~=values.Parent then table.insert(v.Children,o) end
  values[k]=v
 end})
end}
local Scenes={}
''' + lighting + r'''
Scenes.outpostLighting()
assert(Lighting.ClockTime==0 and not Lighting:FindFirstChildOfClass("Sky").CelestialBodiesShown,"Fresh moon lighting not applied")
for _,kind in {"Atmosphere","ColorCorrectionEffect","SunRaysEffect","BloomEffect"} do
 local effect=Instance.new(kind)
 effect.Parent=Lighting
 effect.Density,effect.Haze,effect.Glare,effect.Intensity,effect.Brightness=1,10,10,1,1
end
local clouds=Instance.new("Clouds")
clouds.Parent=terrain
clouds.Enabled=true
Lighting.ClockTime=14.2
Lighting.ExposureCompensation=.5
Lighting:FindFirstChildOfClass("Sky").SkyboxUp="custom-day-sky"
Scenes.outpostLighting()
assert(Lighting.ClockTime==0 and Lighting.ExposureCompensation==0 and not clouds.Enabled,"Daylight leaked into quarry")
assert(Lighting:FindFirstChildOfClass("Atmosphere").Density==0,"Atmosphere hides space")
assert(Lighting:FindFirstChildOfClass("ColorCorrectionEffect").Brightness==0,"Daytime grade retained")
assert(Lighting:FindFirstChildOfClass("SunRaysEffect").Intensity==0,"Sun rays retained")
local sky=Lighting:FindFirstChildOfClass("Sky")
assert(sky.StarCount==5000 and not sky.CelestialBodiesShown and sky.SkyboxUp=="rbxasset://textures/sky/sky512_up.tex","Sky not restored")
local count=#Lighting.Children
Scenes.outpostLighting()
assert(#Lighting.Children==count and #terrain.Children==1,"Re-entry duplicated effects")
print("PASS: fresh entry, daylight-to-moon lighting reset and repeated entry")
end
'''
script = ROOT / ".tools/moon-quarry-test.luau"
try:
    script.write_text(source, encoding="utf-8")
    result = subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if not line.startswith("MECH|"):
            print(line)
    if result.returncode:
        print(result.stderr)
        raise SystemExit(result.returncode)
    if '--dump-mechs' in sys.argv:
        target = ROOT / '.tools/mech-geometry.json'
        target.write_text(json.dumps([line.split('|')[1:] for line in result.stdout.splitlines() if line.startswith('MECH|')]))
        print(target)
finally:
    script.unlink(missing_ok=True)
