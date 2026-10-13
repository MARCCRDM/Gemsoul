"""Exercise the actual meadow/world builders; optionally dump native geometry.

This verifies placement and floor construction offline, not Roblox rendering.
"""
from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
# Reuse the tested matrix/Instance setup, without running the arena suite.
env = {'__file__': str(ROOT / 'tests/run_arena_scene.py')}
exec((ROOT / 'tests/run_arena_scene.py').read_text().split("source += '''\nlocal landmarks")[0], env)
source = env['source']
source = source.replace('if key == "Size" then', 'if key == "Size" and (className=="Part" or className=="WedgePart" or className=="CornerWedgePart") then')
source = source.replace('__index = values,', '''__index = function(_,key)
 if key=="Position" then return values.CFrame.Position end
 return values[key]
end,''')
source += r'''
vmt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
vmt.__unm=function(a) return a*-1 end
vmt.__index=function(a,k)
 if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if k=="Unit" then return a/a.Magnitude end
 if k=="Dot" then return function(x,y) return x.X*y.X+x.Y*y.Y+x.Z*y.Z end end
 if k=="Cross" then return function(x,y) return Vector3.new(x.Y*y.Z-x.Z*y.Y,x.Z*y.X-x.X*y.Z,x.X*y.Y-x.Y*y.X) end end
end
Vector3.zero=Vector3.new(0,0,0)
Vector3.one=Vector3.new(1,1,1)
function CFrame.fromMatrix(p,x,y,z)
 z=z or x:Cross(y)
 local c=CFrame.new(p)
 c.r={x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z}
 return c
end
function CFrame.lookAt(p,q)
 local back=(p-q).Unit
 local up=Vector3.new(0,1,0)
 if math.abs(up:Dot(back))>.999 then up=Vector3.new(1,0,0) end
 local right=up:Cross(back).Unit
 return CFrame.fromMatrix(p,right,back:Cross(right),back)
end
local UDim2={new=function() return {} end,fromOffset=function() return {} end}
'''
for name, path in [('Rules', 'src/shared/Outpost.luau'), ('Meadow', 'src/server/World/OutpostMeadow.luau'), ('World', 'src/server/World/OutpostWorld.luau')]:
    code = (ROOT / path).read_text(encoding='utf-8')
    code = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', code, flags=re.M)
    source += f'local {name}=(function()\n{code}\nend)()\n'
source += r'''
local origin=CFrame.new(0,0,7000)
local site=World.build(origin,{})
assert(site.Model.LandscapeVersion==2,"Old landscape built")
assert(#site.Parking==0 and #site.Secrets==0,"Retired world extras returned")
assert(site.Spawn.Position.X==0 and site.Spawn.Position.Z==7074,"Arrival moved")
assert(site.Probe and site.Board and site.Gate,"Missing lobby services")
local common, field, grass, triangles = 0,0,0,{}
for i,spot in site.Spots do
 local p=spot.Position-origin.Position
 assert(math.abs(p.Y)<.001,"Mining node isn't seated on the grass")
 assert(Meadow.clear(p),"Rock overlaps a path, service, tree or cliff")
 assert(p.Magnitude<Rules.Radius,"Recovery radius excludes valid ground")
 if site.Zones[i]=="Common" then common+=1 else field+=1; assert(site.Zones[i]=="Field") end
 for j=i+1,#site.Spots do assert((spot.Position-site.Spots[j].Position).Magnitude>8.5,"Mining bodies overlap") end
end
assert(common>=Rules.NodeCount,"Too few starter positions: "..common)
assert(field>=Rules.FieldNodeCount,"Too few meadow positions: "..field)
assert(#site.FieldSpots==field)
local active={}
for _,index in site.FieldSpots do assert(not active[index] and site.Zones[index]=="Field");active[index]=true end
for _,zone in Rules.ZoneOrder do
 for i=0,10000 do
  local id=Rules.rollSize(i/10001,zone)
  assert(id=="Pebble" or id=="Boulder","Rare lobby node in "..zone)
 end
end
local outline=Meadow.outline()
local minimum,maximum=math.huge,0
for _,p in outline do minimum=math.min(minimum,p.Magnitude);maximum=math.max(maximum,p.Magnitude) end
assert(maximum-minimum>25,"Shoreline still circular")
for _,tree in Meadow.Trees do assert(Meadow.contains(Vector3.new(tree[1],0,tree[2]),5),"Tree outside meadow") end
for _,p in builtParts do
 assert(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,"Degenerate world geometry")
 if p.Name=="GrassSurface" and p.CanCollide then
  grass+=1
  assert((p.Transparency or 0)==0,"See-through walking surface")
  assert(math.abs(math.abs(p.CFrame.r[4])-1)<.001,"Sloped grass triangle")
  assert(math.abs(p.CFrame.t[2]+p.Size.X/2)<.001,"Floor seam height mismatch")
  -- The three unique points on the horizontal triangular face.
  local verts={}
  for _,v in {Vector3.new(0,-p.Size.Y/2,-p.Size.Z/2),Vector3.new(0,-p.Size.Y/2,p.Size.Z/2),Vector3.new(0,p.Size.Y/2,p.Size.Z/2)} do
   local c=p.CFrame*CFrame.new(v)
   table.insert(verts,Vector3.new(c.t[1],0,c.t[3]-7000))
  end
  table.insert(triangles,verts)
 elseif p.Name=="Wildflower" or p.Name=="GrassTuft" or p.Name=="TreeCrown" then
  assert(not p.CanCollide and not p.CanQuery and not p.CanTouch,"Decoration blocks mining/movement")
 end
end
assert(grass==64,"Missing floor triangle")
local function cross(a,b) return a.X*b.Z-a.Z*b.X end
local function covered(p)
 for _,t in triangles do
  local a,b,c=cross(t[2]-t[1],p-t[1]),cross(t[3]-t[2],p-t[2]),cross(t[1]-t[3],p-t[3])
  if (a>=-.001 and b>=-.001 and c>=-.001) or (a<=.001 and b<=.001 and c<=.001) then return true end
 end
 return false
end
local sampled=0
for x=-195,195,5 do for z=-175,175,5 do
 local p=Vector3.new(x,0,z)
 if Meadow.contains(p,1) then assert(covered(p),"Gap in walkable meadow");sampled+=1 end
end end
assert(#builtParts<2800,"Lobby scenery part budget exceeded: "..#builtParts)
print("PASS: meadow scenery="..#builtParts.." parts; starter spots="..common.."; field spots="..field.."; covered floor samples="..sampled)
print("PASS: 20,002 basic-node rolls; shoreline/paths/service clearance; opaque level ground; safe nature geometry")
for _,p in builtParts do
 local row={p.Name or p.ClassName,p.ClassName,p.Shape or "Block",p.Material,tostring(p.Transparency or 0)}
 for _,v in {p.Size.X,p.Size.Y,p.Size.Z,p.Color.R,p.Color.G,p.Color.B} do table.insert(row,tostring(v)) end
 for _,v in p.CFrame.t do table.insert(row,tostring(v)) end
 for _,v in p.CFrame.r do table.insert(row,tostring(v)) end
 print("PART|"..table.concat(row,"|"))
end
for i,p in site.Spots do print("SPOT|"..p.Position.X.."|"..p.Position.Z.."|"..site.Zones[i]) end
'''
script = ROOT / '.tools/meadow-scene-test.luau'
try:
    script.write_text(source, encoding='utf-8')
    result = subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(script)], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if not line.startswith(('PART|','SPOT|')):
            print(line)
    if result.returncode:
        print(result.stderr)
        raise SystemExit(result.returncode)
    if '--dump' in sys.argv:
        data = {kind.lower(): [line.split('|')[1:] for line in result.stdout.splitlines() if line.startswith(kind+'|')] for kind in ('PART','SPOT')}
        target=ROOT/'.tools/meadow-scene-geometry.json'
        target.write_text(json.dumps(data),encoding='utf-8')
        print(target)
finally:
    script.unlink(missing_ok=True)
