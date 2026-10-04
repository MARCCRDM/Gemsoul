from pathlib import Path
import subprocess,math,json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1]
base=(root/'.tools/render_equipment_details.py').read_text(encoding='utf-8').split("for name, path in")[0]
ctx={'__file__':str(root/'.tools/render_equipment_details.py')};exec(base,ctx);source=ctx['source']
source=source.replace('return setmetatable({t={x or 0,y or 0,z or 0}', 'if type(x)=="table" then x,y,z=x.X,x.Y,x.Z end\n return setmetatable({t={x or 0,y or 0,z or 0}')
source+='\nvmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end\nVector3.zero=Vector3.new(0,0,0)\n'
source+='local Skins=(function()\n'+(root/'src/server/Systems/BrainrotSkins.luau').read_text(encoding='utf-8')+'\nend)()\n'
source+='local Rules=(function()\n'+(root/'src/shared/DungeonRules.luau').read_text(encoding='utf-8')+'\nend)()\n'
duel=(root/'src/server/Systems/Duelist.luau').read_text(encoding='utf-8');source+=duel[duel.index('local BODY ='):duel.index('local JOINTS =')]
source+='''
local colors={Fire=Color3.fromRGB(238,62,54),Frost=Color3.fromRGB(64,150,255),Poison=Color3.fromRGB(70,205,90),Shock=Color3.fromRGB(255,212,40)}
for _,spec in Rules.Roster do
 table.clear(builtParts)
 local rig={}
 for _,b in BODY do
  local p=Instance.new("Part");p.Name=b[1];p.Size=b[2];p.CFrame=CFrame.new(b[3]);p.Material="SmoothPlastic";p.Color=Color3.new(1,1,1);p.Parent=rig
  p.IsA=function(_,kind) return kind=="BasePart" end
  rig[b[1]]=p
 end
 rig.GetChildren=function() local list={} for _,b in BODY do table.insert(list,rig[b[1]]) end return list end
 rig.SetAttribute=function() end
 rig.ScaleTo=function(_,scale) for _,p in builtParts do p.Size=p.Size*scale;for i=1,3 do p.CFrame.t[i]*=scale end end end
 Skins.apply(rig,spec,colors[spec.Element],true)
 print("MODEL|"..spec.Name.."|"..spec.Element.."|"..spec.Weakness)
 for _,p in builtParts do
  if p.Transparency==1 then continue end
  local row={if p.ClassName=="WedgePart" then "Wedge" else p.Shape or "Block",p.Material,tostring(p.Size.X),tostring(p.Size.Y),tostring(p.Size.Z),tostring(p.Color.R),tostring(p.Color.G),tostring(p.Color.B)}
  for _,n in p.CFrame.t do table.insert(row,tostring(n)) end
  for _,n in p.CFrame.r do table.insert(row,tostring(n)) end
  print(table.concat(row,"|"))
 end
end
'''
bundle=root/'.tools/boss-preview.luau';bundle.write_text(source,encoding='utf-8')
raw=subprocess.check_output([str(root/'.tools/luau/luau.exe'),str(bundle)],text=True)
models=[]
for line in raw.splitlines():
 v=line.split('|')
 if v[0]=='MODEL': models.append((v[1:],[]))
 elif len(v)==20: models[-1][1].append((v[:2],np.array(list(map(float,v[2:])))))
box=np.array([[x,y,z] for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])
boxfaces=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
a=.65;t=.16
view=np.array([[math.cos(a),0,math.sin(a)],[math.sin(a)*math.sin(t),math.cos(t),-math.cos(a)*math.sin(t)],[-math.sin(a)*math.cos(t),math.sin(t),math.cos(a)*math.cos(t)]])
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
bold=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',n)
colors={'Fire':'#ee3e36','Frost':'#4096ff','Poison':'#46cd5a','Shock':'#ffd428'}
labels={'Fire':'THERMAL','Frost':'CRYO','Poison':'CORROSIVE','Shock':'ION'}
out=root/'docs/boss-previews';out.mkdir(exist_ok=True)
sheet=Image.new('RGB',(1600,1640),'#0b121a');sd=ImageDraw.Draw(sheet)
sd.text((40,22),'BRAINROT DUNGEON / FOUR COLOSSUS BOSSES',font=bold(34),fill='#ecf1f7')
sd.text((40,72),'Current code geometry · neutral pose · simplified lighting · not Roblox Studio screenshots',font=font(20),fill='#a3b5c7')
for idx,(meta,parts) in enumerate(models):
 name,element,weak=meta
 a=1.0 if element in ('Frost','Shock') else .3
 t=.19
 view=np.array([[math.cos(a),0,math.sin(a)],[math.sin(a)*math.sin(t),math.cos(t),-math.cos(a)*math.sin(t)],[-math.sin(a)*math.cos(t),math.sin(t),math.cos(a)*math.cos(t)]])
 im=Image.new('RGB',(760,720),'#14212d');draw=ImageDraw.Draw(im)
 draw.rectangle((0,0,760,5),fill=colors[element]);draw.text((28,23),name,font=bold(28),fill='#f0f3f7')
 draw.text((28,68),labels[element]+'  /  WEAK TO '+labels[weak],font=bold(17),fill=colors[element])
 polys=[];allv=[]
 for (shape,mat),data in parts:
  size,col,pos,rot=data[:3],data[3:6],data[6:9],data[9:].reshape(3,3)
  verts=box*size;faces=boxfaces
  if shape=='Wedge':
   verts=verts.copy()
   verts[verts[:,2]<0,1]=-size[1]/2
  if shape=='Ball':
   verts=np.array([[math.cos(lat)*math.cos(lon)*size[0]/2,math.sin(lat)*size[1]/2,math.cos(lat)*math.sin(lon)*size[2]/2] for lat in np.linspace(-math.pi/2,math.pi/2,17) for lon in np.linspace(0,2*math.pi,32,endpoint=False)])
   faces=[[j*32+i,j*32+(i+1)%32,(j+1)*32+(i+1)%32,(j+1)*32+i] for j in range(16) for i in range(32)]
  elif shape=='Cylinder':
   verts=np.array([[side*size[0]/2,math.cos(ang)*size[1]/2,math.sin(ang)*size[2]/2] for side in (-1,1) for ang in np.linspace(0,2*math.pi,32,endpoint=False)])
   faces=[list(range(32)),list(range(32,64))]+[[i,(i+1)%32,(i+1)%32+32,i+32] for i in range(32)]
  verts=(verts@rot.T+pos)@view.T;allv.extend(verts)
  for face in faces:
   pts=verts[face];n=np.cross(pts[1]-pts[0],pts[2]-pts[0]);length=np.linalg.norm(n)
   if length<1e-8: continue
   shade=1.1 if mat=='Neon' else .5+.5*abs(np.dot(n/length,[-.3,.7,-.64]))
   polys.append((pts[:,2].mean(),pts,tuple(np.clip(col*shade*255,0,255).astype(int))))
 allv=np.array(allv);lo=allv.min(axis=0);hi=allv.max(axis=0);scale=min(600/(hi[0]-lo[0]),505/(hi[1]-lo[1]));center=(lo+hi)/2
 draw.ellipse((200,613,560,652),fill='#0b141e')
 for _,pts,color in sorted(polys,key=lambda f:f[0],reverse=True): draw.polygon([(380+(p[0]-center[0])*scale,375-(p[1]-center[1])*scale) for p in pts],fill=color)
 draw.text((28,671),'BOSS SCALE 1.8×  /  EXISTING R15 COMBAT RIG',font=font(17),fill='#9eb0c1')
 im.save(out/(str(idx+1)+'-'+element+'.png'))
 sheet.paste(im,(30+(idx%2)*790,120+(idx//2)*755))
sheet.save(out/'all-bosses.png');print(out/'all-bosses.png')

