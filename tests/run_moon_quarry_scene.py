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
 if k=="RightVector" then return Vector3.new(a.r[1],a.r[4],a.r[7]) end
 if k=="UpVector" then return Vector3.new(a.r[2],a.r[5],a.r[8]) end
 if k=="VectorToWorldSpace" then
  return function(x,v) return Vector3.new(x.r[1]*v.X+x.r[2]*v.Y+x.r[3]*v.Z,x.r[4]*v.X+x.r[5]*v.Y+x.r[6]*v.Z,x.r[7]*v.X+x.r[8]*v.Y+x.r[9]*v.Z) end
 end
 if k=="ToOrientation" then return function(x) return 0,math.atan2(x.r[3],x.r[9]),0 end end
 return oldFrameIndex(a,k)
end
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
Vector3.yAxis=Vector3.new(0,1,0)
Vector3.zAxis=Vector3.new(0,0,1)
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
    ("Frontier", "src/shared/Frontier.luau"),
    ("World", "src/server/World/OutpostWorld.luau"),
    ("Machines", "src/server/World/OutpostMachines.luau"),
    ("Motion", "src/shared/MechMotion.luau"),
]:
    source += f"local {name}=(function()\n{(ROOT / path).read_text(encoding='utf-8')}\nend)()\n"
source += r'''
local origin=CFrame.new(0,0,7000)
-- (Its outcrops and Rift Veins come from Shared.Frontier, handed in as the server finds it.)
World.Frontier=Frontier
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
assert(Rules.Radius==440 and Rules.NodeCount==210 and Rules.FieldNodeCount==0,"Lobby bounds/population mismatch")
-- Every spot holds a rock: the field round the middle, the outcrops out
-- to the walls (Shared.Frontier) and the three Rift Veins.
local population=math.min(Rules.NodeCount,#site.Spots)
assert(#site.Spots>=170 and #site.Spots<=210 and population==#site.Spots,"Not about the old number of mining sites, or more than the cap: "..#site.Spots)
assert(#site.OutcropSpots>=90 and #site.Veins==Frontier.Veins.Count and #site.Scars==Frontier.Veins.Count,"The outcrops or veins are missing")
assert(#site.VeinSites>=8,"Too few places for a vein to move to: "..#site.VeinSites)
for v,vein in site.Veins do
 assert(#vein.Spots==Frontier.Veins.Rocks and site.VeinSites[vein.Site],"A vein without its six rocks")
 for k,index in vein.Spots do
  assert((site.Spots[index].Position-site.VeinSites[vein.Site].Rocks[k].Position).Magnitude<1e-6,"A vein's rock off its site")
 end
 for w=v+1,#site.Veins do
  assert(Frontier.apart(site.VeinSites[vein.Site].Angle,site.VeinSites[site.Veins[w].Site].Angle)>=Frontier.Veins.Apart,"Two veins together")
 end
end
-- Every vein site has room: none of its rocks on another spot, a road or a building.
for _,siteInfo in site.VeinSites do
 for _,cf in siteInfo.Rocks do
  local p=cf.Position-origin.Position
  assert(Vector3.new(p.X,0,p.Z).Magnitude<Frontier.Rim and (p-Vector3.new(0,0,150)).Magnitude>=84,"A vein site in the walls or the motor pool")
  for i,spot in site.Spots do
   local mine=false
   for _,vein in site.Veins do
    if site.VeinSites[vein.Site]==siteInfo and table.find(vein.Spots,i) then mine=true end
   end
   assert(mine or (spot.Position-cf.Position).Magnitude>=12,"A vein site with no room")
  end
 end
end
-- The field round the middle: rocks close by, inside the core, none on the
-- lane from the pad (overlaps are checked with every spot below).
assert(#site.NearSpots>=48,"The field round the middle is too thin: "..#site.NearSpots)
for _,index in site.NearSpots do
 local p=site.Spots[index].Position-origin.Position
 local r=Vector3.new(p.X,0,p.Z).Magnitude
 assert(r>=36 and r<=Frontier.Core,"A near rock out of the middle")
 assert(not (math.abs(p.X)<10 and p.Z>-60),"A near rock blocks the lane from the pad")
 assert(not table.find(site.ArrivalSpots,index),"A spot counted twice")
end
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
-- The crater rim and the sky are sent whole: far off, streaming would never
-- send them (the rim's far side is 900-1,200 studs from most of the quarry).
local rim,skyModel=0,nil
for _,p in builtParts do
 local model=p.Parent
 if model and model.Name=="NaturalCraterRim" then
  rim+=1
  assert(model.ModelStreamingMode=="Persistent","The crater rim streams: its far side never loads")
 elseif model and model.Name=="Sky" then
  skyModel=model
 end
end
assert(rim>1000 and skyModel and skyModel.ModelStreamingMode=="Persistent","Crater rim or sky missing or streamed")
assert(#builtParts<4000,"Quarry scenery budget exceeded")
local veins={}
for v,vein in site.Veins do for _,index in vein.Spots do veins[index]=v end end
for i,spot in site.Spots do
 local p=spot.Position-origin.Position
 -- Its zone is its band's (richer outward), or a Rift Vein's (the guarded one's own).
 local zone=Frontier.zoneOf(Vector3.new(p.X,0,p.Z).Magnitude,veins[i]~=nil)
 if veins[i]==Frontier.Veins.Guarded then zone="Guarded" end
 assert(site.Zones[i]==zone and math.abs(p.Y)<.001 and p.Magnitude<Rules.Radius,"Unsafe mining position/zone")
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
print("PASS: quarry "..#builtParts.." scenery parts; "..#site.Spots.." clear mining sites; 5 ramps; services and safe sky; the crater rim and sky always load")
local counts={Hauler=0,Mole=0,Digger=0,Skipper=0}
assert(#site.Parking==8,"Motor Pool has missing bays")
for _,bay in site.Parking do
 counts[bay.Kind]+=1
 local vehicle=Machines.build(bay.Kind,bay.CFrame)
 assert(vehicle.PrimaryPart.Name=="Chassis" and not vehicle.PrimaryPart.Massless,"Vehicle has no chassis at its root")
 -- It collides through a ball underneath (rides up steps) and a box above the
 -- step height (walls), not the flat-bottomed chassis box (catches on kerbs).
 local hull,foot=nil,nil
 for _,part in builtParts do
  if part.Parent==vehicle and part.Name=="Hull" then hull=part end
  if part.Parent==vehicle and part.Name=="Foot" then foot=part end
 end
 assert(not vehicle.PrimaryPart.CanCollide and hull and hull.CanCollide and foot and foot.CanCollide,"Mech colliders missing")
 local base=vehicle.PrimaryPart.Position.Y-vehicle.PrimaryPart.Size.Y/2
 assert(math.abs(foot.CFrame.Position.Y-foot.Size.Y/2-base)<.01,"The ball doesn't reach the ground")
 assert(hull.CFrame.Position.Y-hull.Size.Y/2>=base+1,"The box still drags along the ground")
 local seat,drive,steer,drill=nil,nil,nil,nil
 local joints={}
 for _,object in instances do
  if object.Parent==vehicle and object.Name=="Cockpit" then seat=object end
  if object.Parent==vehicle.PrimaryPart and object.Name=="Drive" then drive=object end
  if object.Parent==vehicle.PrimaryPart and object.Name=="Steer" then steer=object end
  if object.ClassName=="Motor6D" and object.Parent and object.Parent.Parent==vehicle then
   joints[object.Name]=object
   assert(object.Part0 and object.Part1 and object.Part1.Parent==vehicle,"Broken mech joint")
   if object.Name=="ToolRotor" then drill=object end
  end
 end
 assert(seat and vehicle.MechKind==bay.Kind,"Cockpit or mech kind missing")
 assert(not drive and not steer,"Mech still has drive constraints (the server moves it)")
 if bay.Kind=="Mole" then assert(drill,"Mole drill motor missing") end
 assert(vehicle.Mech and vehicle.CameraFit>=20,"Mech identity/camera fit missing")
 for _,name in {"Waist","LeftHip","LeftKnee","LeftAnkle","RightHip","RightKnee","RightAnkle","LeftShoulder","LeftElbow","RightShoulder","RightElbow"} do
  assert(joints[name],"Missing animated joint: "..name)
 end
 assert(seat.Position.Y>8 and seat.Position.Y<14,"Cockpit outside frame")
 local total=0
 for _,part in builtParts do
  if part.Parent==vehicle then
   total+=1
   if part.Name=="Hull" or part.Name=="Foot" then assert(part.Massless,"A collider adds weight")
   elseif part.Name~="Chassis" then assert(not part.CanCollide and part.Massless,"Cosmetic body obstructs walking") end
  end
 end
 assert(total>120 and total<240,"Mech detail budget changed: "..total)
 local bottom=vehicle.PrimaryPart.Position.Y-vehicle.PrimaryPart.Size.Y/2
 assert(bottom>=.8,"Vehicle spawned in Motor Pool floor")
 assert((bay.CFrame.Position-origin.Position).Magnitude<Rules.Radius,"Vehicle outside recovery boundary")
end
assert(counts.Hauler==2 and counts.Mole==2 and counts.Digger==1 and counts.Skipper==3,"Original vehicle mix changed")
for _,size in {"Pebble","Boulder"} do
 for seed=1,40 do
  local partsBefore,lightsBefore=#builtParts,#builtLights
  local rock=World.rock(size,site.Spots[1],Random.new(seed))
  local body=rock.PrimaryPart
  assert(body.Name=="Body" and body.CanCollide and body.CanQuery,"Mining collision body lost")
  assert(#builtLights==lightsBefore+1 and builtLights[#builtLights].Parent==body,"Rock lost its glow light")
  local parts,crystals,first=0,0,nil
  for i=partsBefore+1,#builtParts do
   local child=builtParts[i]
   assert(child.Parent==rock,"Rock part built outside its model")
   parts+=1
   assert(child.Name=="Body" or not child.CanCollide,"Rock decoration blocks walking")
   if child.Name=="Crystal" then crystals+=1; first=first or child end
  end
  -- The hit chips and flash take the first crystal's colour.
  local glow=Color3.fromRGB(110,220,255)
  assert(crystals>=4 and math.abs(first.Color.R-glow.R)+math.abs(first.Color.G-glow.G)+math.abs(first.Color.B-glow.B)<.01,"Rock lost its crystals: "..crystals)
  assert(parts<=(if size=="Boulder" then 32 else 22),"Rock detail budget: "..parts)
 end
end
print("PASS: all 8 mech rigs, cockpits, walking joints, tool motors, detail budget and floor clearance; basic rock builders")
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
local lightsBefore=#builtLights
for i=1,population do spawnNode() end
assert(nextId==population,"Welcome nodes changed total population")
-- The rocks' glow on the floor round the middle (36-200 studs out, every 4
-- studs; falloff taken as (1 - d/Range)^2). Wide lights overlapped there and
-- washed the floor and everyone on it cyan-white.
local glows={}
for i=lightsBefore+1,#builtLights do
 local l=builtLights[i]
 local at=l.Parent.Position
 table.insert(glows,{at.X,at.Y,at.Z,l.Range,l.Brightness})
end
assert(#glows==population,"One glow per rock: "..#glows)
local middle=origin.Position
local samples,lit,peak=0,0,0
for x=-200,200,4 do
 for z=-200,200,4 do
  local r=math.sqrt(x*x+z*z)
  if r>=36 and r<=200 then
   samples+=1
   local px,py,pz=middle.X+x,middle.Y,middle.Z+z
   local sum,reached=0,false
   for _,g in glows do
    local dx,dy,dz=g[1]-px,g[2]-py,g[3]-pz
    local d=math.sqrt(dx*dx+dy*dy+dz*dz)
    if d<g[4] then
     reached=true
     sum+=g[5]*(1-d/g[4])^2
    end
   end
   if reached then lit+=1 end
   peak=math.max(peak,sum)
  end
 end
end
-- (The old lights reached 35% of it and stacked to 1.13.)
assert(lit/samples<=0.15,string.format("Rock lights reach %.0f%% of the floor round the middle",lit/samples*100))
assert(peak<=0.6,string.format("Rock lights stack to %.2f on the floor",peak))
print(string.format("PASS: rock glows reach %.0f%% of the floor round the middle, %.2f at most",lit/samples*100,peak))
for _,i in site.ArrivalSpots do assert(not freeSpots[i],"Random population left welcome field empty") end
for _,i in site.NearSpots do assert(not freeSpots[i],"The field round the middle wasn't filled first") end
-- A rock popped in the middle grows back in the middle, not out at the walls.
local nearIndex=site.NearSpots[1]
for id,node in nodes do if node.Spot==nearIndex then nodes[id]=nil end end
freeSpots[nearIndex]=true
spawnNode()
assert(nodes[nextId].Spot==nearIndex,"A rock in the middle grew back out in the quarry")
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
-- A rock grows back where it was (an outcrop stays where it is), wherever it is.
local outcropIndex=site.OutcropSpots[#site.OutcropSpots]
for id,node in nodes do if node.Spot==outcropIndex then nodes[id]=nil end end
freeSpots[outcropIndex]=true
spawnNode(false,outcropIndex)
assert(nodes[nextId].Spot==outcropIndex and nodes[nextId].Zone==site.Zones[outcropIndex],"An outcrop rock grew back elsewhere")
print("PASS: actual server node population, 8 welcome rocks, the field round the middle first, "..population.." rocks (every spot), outcrop rocks regrow in place, veins with room to move, replenishment and zone isolation")
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
