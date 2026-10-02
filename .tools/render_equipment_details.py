from pathlib import Path
import subprocess, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
source = (root/'tests/roblox_primitives.luau').read_text()
start, end = source.index('local cmt ='), source.index('local enumMt =')
source = source[:start] + r'''
local cmt = {}
local CFrame = {}
function CFrame.new(x,y,z)
 return setmetatable({t={x or 0,y or 0,z or 0},r={1,0,0,0,1,0,0,0,1}},cmt)
end
function CFrame.Angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local a=CFrame.new(); a.r={cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy}; return a
end
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
source = source.replace('return self\n', 'return Color3.new(self.R * (1-_amount)+_other.R*_amount,self.G * (1-_amount)+_other.G*_amount,self.B * (1-_amount)+_other.B*_amount)\n') if False else source
# Replace the test double with real color interpolation.
source = source.replace('Lerp = function(self, _other, _amount)\n\t\treturn self\n\tend,', 'Lerp = function(self, other, amount)\n return setmetatable({R=self.R*(1-amount)+other.R*amount,G=self.G*(1-amount)+other.G*amount,B=self.B*(1-amount)+other.B*amount,kind="Color3"},getmetatable(self))\n end,')
for name, path in [('ArmorKits','src/server/Systems/ArmorKits.luau'),('Assets','src/server/Systems/FrontierAssets.luau')]:
 source += '\nlocal '+name+'=(function()\n'+(root/path).read_text()+'\nend)()\n'
source += r'''
local anchor={Size=Vector3.new(1,1,1),CFrame=CFrame.identity,FindFirstChildOfClass=function() return nil end}
local function dump(label)
 print("MODEL|"..label)
 for _,p in builtParts do
  local row={p.ClassName,p.Shape or "Block",p.Material,tostring(p.Size.X),tostring(p.Size.Y),tostring(p.Size.Z),tostring(p.Color.R),tostring(p.Color.G),tostring(p.Color.B)}
  for _,n in p.CFrame.t do table.insert(row,tostring(n)) end
  for _,n in p.CFrame.r do table.insert(row,tostring(n)) end
  print(table.concat(row,"|"))
 end
 table.clear(builtParts)
end
local traits={Rarity=5,Helmet=1,VisorColor=Color3.fromRGB(168,99,246),FinishColor=Color3.fromRGB(211,176,84)}
for _,slot in {"Helmet","Armor","Gloves","Boots"} do
 local target=if slot=="Helmet" then "Head" elseif slot=="Armor" then "Torso" elseif slot=="Gloves" then "RightLowerArm" else "RightFoot"
 local rig={GetChildren=function() return {} end,FindFirstChild=function(_,name) if name==target or name=="UpperTorso" then return anchor end return nil end}
 ArmorKits.build({},rig,"HeavyVanguard",Color3.fromRGB(72,207,226),1,traits,slot,"MatrixHelmets10")
 dump(slot)
end
Assets.sidearm({},anchor,CFrame.identity,5,Color3.fromRGB(72,207,226),Color3.fromRGB(82,108,139)); dump("Pistol")
Assets.shield({},anchor,CFrame.identity,5,Color3.fromRGB(72,207,226),Color3.fromRGB(82,108,139)); dump("Shield")
'''
bundle=root/'.tools/details-preview.luau'; bundle.write_text(source)
data=subprocess.check_output([str(root/'.tools/luau/luau.exe'),str(bundle)],text=True)
models={}; current=None
for line in data.splitlines():
 values=line.split('|')
 if values[0]=='MODEL': current=values[1]; models[current]=[]
 elif len(values)==21: models[current].append((values[:3],np.array([float(v) for v in values[3:]])))

W,H=1800,1220; im=Image.new('RGB',(W,H),'#0b1420'); draw=ImageDraw.Draw(im)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
bold=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',n)
draw.text((42,26),'GEMSOUL  /  ENHANCED LOADOUT DETAILS',font=bold(32),fill='#ecf3fa')
draw.text((44,76),'Legendary examples rendered from the current Luau builders · geometry preview, not a Studio screenshot',font=font(21),fill='#a4b5c7')
labels={'Helmet':('Metron helmet','Neural crown, visor lattice, temple vents, gold jaw trim'),'Armor':('Chest & life support','Panel fasteners, rear vents, illuminated fittings'),'Gloves':('Gauntlet','Layered forearm ribs, wrist display, alloy edging'),'Boots':('Boot','Reinforced toe, sole treads, gold ankle plate'),'Pistol':('Sidearm','Inset muzzle, grip ribs, barrel vents, energy insets'),'Shield':('Shield','Fasteners, recessed socket housing, layered perimeter')}
corners=np.array([[x,y,z] for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])
faces=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
angle=.42; tilt=.18
view=np.array([[math.cos(angle),0,math.sin(angle)],[math.sin(angle)*math.sin(tilt),math.cos(tilt),-math.cos(angle)*math.sin(tilt)],[-math.sin(angle)*math.cos(tilt),math.sin(tilt),math.cos(angle)*math.cos(tilt)]])
for index,(name,parts) in enumerate(models.items()):
 left=30+(index%3)*590; top=126+(index//3)*535
 draw.rounded_rectangle((left,top,left+570,top+515),radius=14,fill='#142131',outline='#2b4559',width=2)
 all_faces=[]; extents=[]
 for (kind,shape,mat),v in parts:
  size=v[:3]; color=v[3:6]; pos=v[6:9]; rot=v[9:].reshape(3,3)
  verts=corners*size
  if kind=='WedgePart':
   verts=verts.copy()
   for j in range(len(verts)):
    if verts[j,2]<0: verts[j,1]=-size[1]/2
  face_list=faces
  if shape=='Cylinder':
   verts=np.array([[side*size[0]/2,math.cos(a)*size[1]/2,math.sin(a)*size[2]/2] for side in (-1,1) for a in np.linspace(0,2*math.pi,16,endpoint=False)])
   face_list=[list(range(16)),list(range(16,32))]+[[i,(i+1)%16,(i+1)%16+16,i+16] for i in range(16)]
  verts=(verts@rot.T+pos)@view.T; extents.extend(verts[:,:2])
  for face in face_list:
   pts=verts[face]; normal=np.cross(pts[1]-pts[0],pts[2]-pts[0]); length=np.linalg.norm(normal)
   if np.dot(normal,pts.mean(axis=0)-verts.mean(axis=0))<0: normal=-normal
   if normal[2]>=0: continue
   shade=1 if mat=='Neon' else .52+.43*(abs(np.dot(normal/length,np.array([-.3,.7,-.65]))) if length else 0)
   fill=tuple(int(np.clip(c*shade*255,0,255)) for c in color)
   all_faces.append((pts[:,2].mean(),pts,fill))
 extent=np.array(extents); low=extent.min(axis=0); high=extent.max(axis=0); scale=min(430/(high[0]-low[0]),365/(high[1]-low[1])); center=(low+high)/2
 for _,pts,fill in sorted(all_faces,key=lambda f:f[0],reverse=True):
  xy=[(left+285+(p[0]-center[0])*scale,top+213-(p[1]-center[1])*scale) for p in pts]
  draw.polygon(xy,fill=fill)
 draw.text((left+22,top+433),labels[name][0],font=bold(25),fill='#edc77f')
 draw.text((left+22,top+477),labels[name][1],font=font(16),fill='#b5c6d7')
out=Path('C:/Users/clapr/OneDrive/Documents/temp/Gemsoul-enhanced-details.png'); im.save(out)
print(out)
