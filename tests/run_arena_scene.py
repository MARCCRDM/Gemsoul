"""Run the actual arena/Builder geometry with offline Roblox primitives.

Checks both standalone and town layouts. This is not a Studio lighting or gameplay test.
Pass --dump to export the standalone geometry for an offline visual inspection.
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'tests/roblox_primitives.luau').read_text(encoding='utf-8')
start, end = source.index('local cmt ='), source.index('local enumMt =')
source = source[:start] + r'''
vmt.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
local cmt, CFrame = {}, {}
function CFrame.new(x,y,z)
 if type(x)=="table" then x,y,z=x.X,x.Y,x.Z end
 return setmetatable({t={x or 0,y or 0,z or 0},r={1,0,0,0,1,0,0,0,1}},cmt)
end
function CFrame.Angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local a=CFrame.new()
 a.r={cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy}
 return a
end
cmt.__index=function(a,k) if k=="Position" then return Vector3.new(unpack(a.t)) end end
cmt.__mul=function(a,b)
 local c=CFrame.new()
 for i=1,3 do
  c.t[i]=a.t[i]
  for k=1,3 do c.t[i]+=a.r[(i-1)*3+k]*b.t[k] end
  for j=1,3 do
   local v=0
   for k=1,3 do v+=a.r[(i-1)*3+k]*b.r[(k-1)*3+j] end
   c.r[(i-1)*3+j]=v
  end
 end
 return c
end
CFrame.identity=CFrame.new()
''' + source[end:]
source = source.replace('return self\n', 'return setmetatable({R=self.R*(1-_amount)+_other.R*_amount,G=self.G*(1-_amount)+_other.G*_amount,B=self.B*(1-_amount)+_other.B*_amount,kind="Color3"},getmetatable(self))\n')
source = source.replace('local Instance = {', 'local builtLights = {}\nlocal Instance = {')
source = source.replace('local values = { ClassName = className }', '''local values = { ClassName = className }
 values.SetAttribute = function(_,k,v) values[k]=v end
 if className=="PointLight" then table.insert(builtLights,values) end''')
source = source.replace('className == "WedgePart")', 'className == "WedgePart" or className == "CornerWedgePart")')
source += '''
local landmarks, vendors, screens = {}, {}, {}
local ReplicatedStorage = {}
local CollectionService = {AddTag=function() end}
local Vendors = {Arena={}}
local Config = {MenuOnly=true}
'''
builder = (ROOT / 'src/server/World/Builder.luau').read_text(encoding='utf-8')
builder = builder[builder.index('local Builder = {}'):builder.index('-- Battlements')]
source += 'local Builder=(function()\n' + builder + '\nreturn Builder\nend)()\n'
source += '''
Builder.landmark=function(name,value) landmarks[name]=value end
Builder.sign=function() end
Builder.screen=function(_,_,_,_,spec) table.insert(screens,spec) end
Builder.vendor=function(_,frame,id) vendors[id]=frame end
'''
arena = (ROOT / 'src/server/World/Zones/Arena.luau').read_text(encoding='utf-8-sig')
arena = arena[arena.index('local OUTER_RADIUS'):]
source += 'local Arena=(function()\n' + arena + '\nend)()\n'
source += r'''
local function near(a,b) assert(math.abs(a-b)<0.0001, tostring(a).." != "..tostring(b)) end
for _, standalone in {true,false} do
 Config.MenuOnly=standalone
 table.clear(builtParts); table.clear(builtLights); table.clear(screens)
 local root=Instance.new("Folder")
 Arena.build(root,CFrame.new(600,0,0),Color3.fromRGB(190,65,80))
 near(landmarks.ArenaFloor.X,600); near(landmarks.ArenaFloor.Y,0.7); near(landmarks.ArenaFloor.Z,44)
 assert(landmarks.ArenaRadius==30 and Arena.Radius==42)
 assert(#screens==2 and vendors.Arena, "Queue/vendor missing")
 assert(#builtLights==4, "Arena light budget changed")
 assert(#builtParts<800, "Arena geometry exceeds part budget")
 local floor, artCount, skylineCount = nil, 0, 0
 for _,p in builtParts do
  if p.Name=="CombatFloor" then floor=p end
  local parent=p.Parent
  local scenery=false
  while parent do
   if parent.Name=="CrystalArt" or parent.Name=="SapphireSkyline" then scenery=true end
   if parent.Name=="SapphireSkyline" then skylineCount+=1 end
   parent=parent.Parent
  end
  if scenery then
   artCount+=1
   assert(p.CanCollide==false and p.CanQuery==false and p.CanTouch==false,"Interactive scenery: "..p.Name)
  end
  -- Exact closest point on each rotated horizontal collision rectangle.
  -- Every obstacle must be outside the existing 30-stud fight floor.
  if p.CanCollide and p.Name~="CombatFloor" and p.Name~="ArenaGrounds" then
   local x,z=p.CFrame.t[1]-600,p.CFrame.t[3]-44
   local r=p.CFrame.r
   local lx,lz=x*r[1]+z*r[7],x*r[3]+z*r[9]
   local dx,dz=math.max(0,math.abs(lx)-p.Size.X/2),math.max(0,math.abs(lz)-p.Size.Z/2)
   local nearest=math.sqrt(dx*dx+dz*dz)
   assert(nearest>30,"Collision inside combat floor: "..p.Name.." "..nearest)
  end
 end
 assert(floor and floor.Transparency==0 and floor.CanCollide)
 near(floor.CFrame.t[2]+floor.Size.X/2,0.7)
 assert(artCount>100)
 assert((skylineCount>0)==standalone,"Standalone scenery leaked into town")
 print("PASS|"..tostring(standalone).."|parts="..#builtParts.."|lights="..#builtLights)
 if standalone then
  for _,p in builtParts do
   local row={p.Name,p.ClassName,p.Shape or "Block",p.Material,tostring(p.Transparency or 0)}
   for _,v in {p.Size.X,p.Size.Y,p.Size.Z,p.Color.R,p.Color.G,p.Color.B} do table.insert(row,tostring(v)) end
   for _,v in p.CFrame.t do table.insert(row,tostring(v)) end
   for _,v in p.CFrame.r do table.insert(row,tostring(v)) end
   print("PART|"..table.concat(row,"|"))
  end
 end
end
'''
script = ROOT / '.tools/arena-geometry-test.luau'
try:
    script.write_text(source, encoding='utf-8')
    result = subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(script)], text=True, capture_output=True)
    for line in result.stdout.splitlines():
        if not line.startswith('PART|'):
            print(line)
    if result.returncode:
        print(result.stderr)
        raise SystemExit(result.returncode)
    if '--dump' in sys.argv:
        parts = [line.split('|')[1:] for line in result.stdout.splitlines() if line.startswith('PART|')]
        output = ROOT / '.tools/arena-scene-geometry.json'
        output.write_text(json.dumps(parts), encoding='utf-8')
        print(output)

finally:
    script.unlink(missing_ok=True)
