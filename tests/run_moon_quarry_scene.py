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
local Region3={new=function(a,b) return {Min=a,Max=b} end}
-- (The terrain the Loop's ground is laid in: what's written to it.)
local terrainWrites,terrainColors={},{}
local TerrainStub={
 SetMaterialColor=function(_,material,color) terrainColors[material]=color end,
 WriteVoxels=function(_,region,resolution,materials,occupancies)
  table.insert(terrainWrites,{Region=region,Resolution=resolution,Materials=materials,Occupancies=occupancies})
 end,
}
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
World.Rules=Rules
World.Terrain=TerrainStub
local site=World.build(origin,{})
assert(site.Model.Landscape=="Moon Quarry" and site.Model.SkySetting=="MoonBase")
assert(#site.Secrets==0 and #site.FieldSpots==0,"Retired extras returned")
-- The Shelter in the middle: players arrive in its garage lane, facing
-- bay 04's Mole drill; its stations and services are all under its roof.
local box=site.Shelter.Box
local function inShelter(p) return math.abs(p.X)<box.X and math.abs(p.Z)<box.Y end
local bay4=site.Parking[4].CFrame.Position
assert(site.Spawn.Position.X==bay4.X and site.Spawn.Position.Z==7000-24 and site.Spawn.Position.Y==3.5+Rules.ShelterLift,"Spawn isn't in the garage lane, on its floor")
assert(site.Parking[4].Kind=="Mole" and bay4.Z<site.Spawn.Position.Z,"No Mole drill in front of the spawn")
assert(site.Spawn.LookVector.Z<-.99,"Spawn doesn't face the Mole drill")
assert(#site.ArrivalSpots==8,"Welcome mining field missing")
-- (beside the ramp down from the door, or past its foot, off the lane out)
local front=site.Shelter.Ramps[1]
local frontMid=front.Middle-origin.Position
for _,index in site.ArrivalSpots do
 local p=site.Spots[index].Position-origin.Position
 local beside=math.abs(p.X)>=front.SlopeHalf+6 and p.Z<frontMid.Z+front.Half.Y
 local past=p.Z>=frontMid.Z+front.Half.Y+8 and math.abs(p.X)>=14
 assert(p.Z>box.Y and math.abs(p.X)<=30 and (beside or past),"Welcome nodes aren't outside the door, or block the ramp or the lane out")
end
-- (PROBE-7 and the duels are crew now: no station or gate to hand out.)
assert(site.Probe==nil and site.Gate==nil and site.Board.Name=="BoardFace","Missing lobby services, or a station or gate is back")
for _,service in {site.Board,site.Stations.Store,site.Stations.Market} do
 assert(inShelter(service.CFrame.Position-origin.Position),"A service outside the Shelter: "..service.Name)
end
assert(site.Stations.Store.CanCollide and site.Stations.Market.CanCollide,"The Store and Market counters aren't solid")
assert(Rules.Radius==550 and Rules.Edge==584 and Rules.NodeCount==330 and Rules.FieldNodeCount==0,"Lobby bounds/population mismatch")
-- Every spot holds a rock: the field round the middle, the outcrops out
-- to the walls (Shared.Frontier) and the three Rift Veins.
local population=math.min(Rules.NodeCount,#site.Spots)
assert(#site.Spots>=240 and #site.Spots<=330 and population==#site.Spots,"Expanded mining sites missing or beyond cap: "..#site.Spots)
local outerMining,outerQuadrants=0,{}
for _,index in site.OutcropSpots do
 local p=site.Spots[index].Position-origin.Position
 if Vector3.new(p.X,0,p.Z).Magnitude>440 then
  outerMining+=1
  outerQuadrants[(if p.X>=0 then "E" else "W")..(if p.Z>=0 then "S" else "N")]=true
 end
end
assert(outerMining>=30,"The new outer ground needs mining clusters")
assert(outerQuadrants.ES and outerQuadrants.EN and outerQuadrants.WS and outerQuadrants.WN,"Outer mining missing from a quadrant")
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
  assert(Vector3.new(p.X,0,p.Z).Magnitude<Frontier.Rim and not inShelter(p),"A vein site in the walls or the Shelter")
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
 if name=="Shelter" then motor+=1 end
 if name=="Outpost" then base+=1 end
 if p.CanCollide and p.Size.Y==(Rules.Radius+80)*2 and p.Size.Z==(Rules.Radius+80)*2 then floor=p end
 assert(p.Name~="GrassSurface" and p.Name~="MeadowCloudBank" and p.Name~="Secret","Old lobby/retired secrets leaked")
end
assert(floor and math.abs(floor.CFrame.t[2]+floor.Size.X/2)<.001,"Quarry floor missing or wrong height")
assert(floor.Transparency==1,"The quarry floor shows through the Loop's ground")
assert(roads>80 and ramps==4 and sky>=260 and motor>200 and base>200,"Quarry landmarks or the Shelter missing")
-- The Loop: each biome's ground and landmarks in its own quarter, past the
-- core, and no signs naming them (the ground says where you are).
local biomeParts,signs,glows={},0,{}
for _,p in builtParts do
 local folderName=p.Parent and p.Parent.Name
 for _,biome in Frontier.Biomes do
  if folderName==biome.Id then
   biomeParts[biome.Id]=(biomeParts[biome.Id] or 0)+1
   local q=p.CFrame.Position-origin.Position
   local flatQ=Vector3.new(q.X,0,q.Z)
   assert(flatQ.Magnitude>=Frontier.Core,"A biome's landmark in the core: "..biome.Id)
   assert(Frontier.biomeAt(flatQ)==biome,"A biome's landmark out of its own ground: "..biome.Id)
   if p.Material==Enum.Material.Neon then glows[biome.Id]=true end
  end
 end
 if folderName=="Crossroads" and p.Name=="Sign" then signs+=1 end
end
for _,biome in Frontier.Biomes do
 assert((biomeParts[biome.Id] or 0)>=15,"Too few landmarks in "..biome.Id..": "..tostring(biomeParts[biome.Id]))
 assert(biome.Id=="Rimefrost" or glows[biome.Id],"No glow among "..biome.Id.."'s landmarks")
end
assert(signs==0,"Signs naming the biomes are back at the spokes: "..signs)
-- The Loop's ground, in terrain: laid once, on terrain's grid, out under the
-- walls; flush with the floor (0) wherever anything stands, and rising
-- only out in the open; each biome's own materials, the core's regolith.
assert(#terrainWrites==1,"The Loop's ground wasn't laid (once): "..#terrainWrites)
local write=terrainWrites[1]
local cell=Frontier.Ground.Cell
assert(write.Resolution==cell,"Terrain at the wrong resolution")
local rmin=write.Region.Min
for _,v in {rmin.X,rmin.Y,rmin.Z} do assert(v%cell==0,"Terrain off its grid") end
local mats,occs=write.Materials,write.Occupancies
local nx,ny,nz=#mats,#mats[1],#mats[1][1]
local function columnAt(x,z) -- (studs from the quarry's middle)
 local i=math.floor((x+origin.Position.X-rmin.X)/cell)+1
 local k=math.floor((z+origin.Position.Z-rmin.Z)/cell)+1
 return i,k
end
local function height(i,k)
 local top=rmin.Y
 for y=1,ny do top+=occs[i][y][k]*cell end
 return top-origin.Position.Y
end
local function surface(i,k)
 local m="Air"
 for y=1,ny do if occs[i][y][k]>0 then m=mats[i][y][k] end end
 return m
end
local reach=Frontier.Ground.Reach
assert(nx*cell>=reach*2 and nz*cell>=reach*2 and ny*cell>=Frontier.Ground.Depth,"Terrain doesn't reach the walls")
local counts,tallest,laidCols={},0,0
for i=1,nx do
 for k=1,nz do
  local x,z=rmin.X+(i-.5)*cell-origin.Position.X,rmin.Z+(k-.5)*cell-origin.Position.Z
  if x*x+z*z<=reach*reach then
   laidCols+=1
   local h=height(i,k)
   assert(h>=-1e-6,"A hole in the Loop's ground")
   tallest=math.max(tallest,h)
   local m=surface(i,k)
   assert(m~="Air","No ground at a column")
   counts[m]=(counts[m] or 0)+1
   local want=Frontier.ground(x,z)
   assert(m==want,"A column of the wrong ground")
  end
 end
end
assert(tallest>2 and tallest<=6+1e-6,"The land doesn't rise, or rises too far: "..tallest)
for _,biome in Frontier.Biomes do
 assert((counts[biome.Terrain.Main] or 0)>1000 and (counts[biome.Terrain.Second] or 0)>300,"Too little of "..biome.Id.."'s ground")
 assert(terrainColors[biome.Terrain.Main] and terrainColors[biome.Terrain.Second],"No colour for "..biome.Id.."'s ground")
end
local ci,ck=columnAt(0,0)
assert(surface(ci,ck)==Frontier.Ground.Hub.Main or surface(ci,ck)==Frontier.Ground.Hub.Second,"The core isn't regolith")
-- Flat wherever anything stands: every rock spot, every road, its signs.
for _,spot in site.Spots do
 local q=spot.Position-origin.Position
 local i,k=columnAt(q.X,q.Z)
 assert(math.abs(height(i,k))<1e-6,"The land rises under a rock spot")
end
for _,a in Frontier.Spokes do
 for out=110,420,8 do
  local i,k=columnAt(math.cos(a)*out,math.sin(a)*out)
  assert(math.abs(height(i,k))<1e-6,"The land rises on a road")
 end
end
for t=0,71 do
 local a=t/72*math.pi*2
 local i,k=columnAt(math.cos(a)*260,math.sin(a)*260)
 assert(math.abs(height(i,k))<1e-6,"The land rises on the ring road")
end
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
-- The Shelter up on its legs: three solid ramps (the rules' slope, from its
-- floor's height down to the quarry floor: a mech climbs it), and every
-- one of its eight feet on the ground.
assert(site.Shelter.Lift==Rules.ShelterLift and #site.Shelter.Ramps==3 and #site.Shelter.Feet==8,"The Shelter's lift, ramps or legs")
local slopes={}
for _,p in builtParts do
 if p.Parent and p.Parent.Name=="Shelter" and p.ClassName=="WedgePart" and p.CanCollide and math.abs(p.Size.Z-Rules.ShelterRamp)<.001 then
  assert(math.abs(p.Size.Y-(Rules.ShelterLift+.8))<.001 and math.abs(p.CFrame.Position.Y-p.Size.Y/2-origin.Position.Y)<.001,"A ramp that doesn't run from the floor to the ground")
  table.insert(slopes,p)
 end
end
assert(#slopes==3,"The Shelter's ramps aren't all there: "..#slopes)
for _,foot in site.Shelter.Feet do assert(math.abs(foot.Y-origin.Position.Y)<.001,"A leg doesn't reach the ground") end
-- (no rock on a ramp: every spot 2 studs clear of each slope)
local function onSlope(q)
 for _,w in slopes do
  local d=q-w.CFrame.Position
  local x=d.X*w.CFrame.r[1]+d.Z*w.CFrame.r[7]
  local z=d.X*w.CFrame.r[3]+d.Z*w.CFrame.r[9]
  if math.abs(x)<w.Size.X/2+2 and math.abs(z)<w.Size.Z/2+2 then return true end
 end
 return false
end
for _,spot in site.Spots do assert(not onSlope(spot.Position),"A rock on the Shelter's ramp") end
local veins={}
for v,vein in site.Veins do for _,index in vein.Spots do veins[index]=v end end
for i,spot in site.Spots do
 local p=spot.Position-origin.Position
 -- Its zone is its band's (richer outward), or a Rift Vein's (the guarded one's own).
 local zone=Frontier.zoneOf(Vector3.new(p.X,0,p.Z).Magnitude,veins[i]~=nil)
 if veins[i]==Frontier.Veins.Guarded then zone="Guarded" end
 assert(site.Zones[i]==zone and math.abs(p.Y)<.001 and p.Magnitude<Rules.Radius,"Unsafe mining position/zone")
 assert(not inShelter(p),"Rock in the Shelter")
 assert((p-Vector3.new(72,0,118)).Magnitude>=40,"Rock on the landing pad")
 for j=i+1,#site.Spots do
  assert((spot.Position-site.Spots[j].Position).Magnitude>=12,"Mining nodes overlap")
 end
 -- All radial haul roads and the ring road stay clear for machines.
 local radius=Vector3.new(p.X,0,p.Z).Magnitude
 assert(math.abs(radius-260)>12,"Mining body on ring road")
 for _,a in Frontier.Spokes do
  local direction=Vector3.new(math.cos(a),0,math.sin(a))
  local closest=direction*math.clamp(p:Dot(direction),104,420)
  assert((p-closest).Magnitude>=14,"Mining body on haul road")
 end
end
for i=0,10000 do
 local size=Rules.rollSize(i/10001,"Common")
 assert(size=="Pebble" or size=="Boulder","Rare mining object returned")
end
print("PASS: quarry "..#builtParts.." scenery parts; "..#site.Spots.." clear mining sites; 4 spokes and their ramps; the Loop's ground in terrain (flat under every rock and road), the biomes' landmarks and no signs; services and safe sky; the crater rim and sky always load")
local counts={Hauler=0,Mole=0,Digger=0,Skipper=0}
assert(#site.Parking==8,"The garage has missing bays")
for _,bay in site.Parking do
 counts[bay.Kind]+=1
 -- In the garage, facing the lane (south), in a row along the north wall.
 local p=bay.CFrame.Position-origin.Position
 assert(inShelter(p) and p.Z<-40 and p.Z>-56 and bay.CFrame.LookVector.Z>.99,"A bay outside the garage, or not facing its lane")
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
 -- (Heights over the quarry floor's, less the Shelter's lift: the garage is up on its legs.)
 local floorY=origin.Position.Y+Rules.ShelterLift
 assert(seat.Position.Y-floorY>8 and seat.Position.Y-floorY<14,"Cockpit outside frame")
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
 assert(bottom>=floorY+.8,"Vehicle spawned in Motor Pool floor")
 assert((bay.CFrame.Position-origin.Position).Magnitude<Rules.Radius,"Vehicle outside recovery boundary")
end
assert(counts.Mole==8 and counts.Hauler==0 and counts.Digger==0 and counts.Skipper==0,"Not a Mole drill in every bay")
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
local freeSpots,fieldSpots,nodes,healingSpots={},{},{},{}
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
-- The finish is made on a fresh entry (menu-only mode's server lighting has no grade).
local finish=Scenes.OutpostFinish
local bloom,grade=Lighting:FindFirstChildOfClass("BloomEffect"),Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
assert(bloom and bloom.Intensity==finish.Bloom.Intensity and bloom.Threshold==finish.Bloom.Threshold,"No soft bloom on the Outpost")
assert(grade and grade.Brightness==0 and grade.Contrast==finish.Grade.Contrast and grade.Saturation==finish.Grade.Saturation,"No grade on the Outpost")
assert(finish.Bloom.Intensity<=0.5 and finish.Grade.Contrast<=0.15 and finish.Grade.Saturation<=0.15,"The finish is overdone")
assert(finish.Specular<=0.2 and Lighting.EnvironmentSpecularScale==finish.Specular,"The Outpost's metal shines")
-- (A daytime visit's effects in their place.)
for _,kind in {"Atmosphere","ColorCorrectionEffect","SunRaysEffect","BloomEffect"} do
 for i=#Lighting.Children,1,-1 do if Lighting.Children[i].ClassName==kind then table.remove(Lighting.Children,i) end end
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
local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
assert(atmosphere.Density==Scenes.OutpostFinish.Fog.Density and atmosphere.Density>0 and atmosphere.Density<=0.35,"Quarry fog not slight")
assert(atmosphere.Haze==0 and atmosphere.Glare==0,"Atmosphere hides space")
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
