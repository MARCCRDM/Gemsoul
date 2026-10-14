"""Render the actual Luau mech geometry dumped by run_moon_quarry_scene.py."""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[1]
rows=json.loads((root/'.tools/mech-geometry.json').read_text())
W,H=2200,1240
image=Image.new('RGB',(W,H),'#101a23')
draw=ImageDraw.Draw(image,'RGBA')
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
bold=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',n)
draw.text((54,35),'QUARRY EXOSUITS',font=bold(38),fill='#edf4f4')
draw.text((56,90),'Built from the in-game geometry  /  offline preview, not a Studio screenshot',font=font(22),fill='#9aabb6')
corners=np.array([[x,y,z] for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])
faces=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
angle,tilt=.45,.12
view=np.array([[math.cos(angle),0,math.sin(angle)],[math.sin(angle)*math.sin(tilt),math.cos(tilt),-math.cos(angle)*math.sin(tilt)],[-math.sin(angle)*math.cos(tilt),math.sin(tilt),math.cos(angle)*math.cos(tilt)]])
labels=[('Hauler','ATLAS','Heavy cargo frame','#d9b361'),('Mole','MOLE','Drilling exosuit','#69d8e6'),('Digger','FORGE','Utility & manipulation','#e2a56d'),('Skipper','SCOUT','Light exploration frame','#7be5bb')]
for index,(kind,name,description,accent) in enumerate(labels):
 left=35+index*540
 draw.rounded_rectangle((left,150,left+520,1185),radius=18,fill='#172731',outline='#2b414c',width=2)
 draw.line((left+24,184,left+130,184),fill=accent,width=4)
 draw.text((left+25,210),name,font=bold(32),fill='#e9f0f1')
 draw.text((left+25,256),description,font=font(21),fill='#9fb1ba')
 draw.ellipse((left+70,1050,left+465,1120),fill=(0,0,0,80))
 allfaces=[]
 for row in rows:
  if row[0]!=kind:continue
  _,part,cls,shape,material,alpha,*values=row
  v=np.array([float(x) for x in values]); size,color,pos,rot=v[:3],v[3:6],v[6:9],v[9:].reshape(3,3)
  verts=corners*size; face_list=faces
  if cls=='WedgePart':
   verts=verts.copy()
   for i in range(len(verts)):
    if verts[i,2]<0:verts[i,1]=-size[1]/2
  if shape=='Cylinder':
   verts=np.array([[side*size[0]/2,math.cos(a)*size[1]/2,math.sin(a)*size[2]/2] for side in (-1,1) for a in np.linspace(0,2*math.pi,16,endpoint=False)])
   face_list=[list(range(16)),list(range(16,32))]+[[i,(i+1)%16,(i+1)%16+16,i+16] for i in range(16)]
  verts=(verts@rot.T+pos)@view.T
  for face in face_list:
   points=verts[face]; normal=np.cross(points[1]-points[0],points[2]-points[0]); length=np.linalg.norm(normal)
   if length<1e-8:continue
   if np.dot(normal,points.mean(axis=0)-verts.mean(axis=0))<0:normal=-normal
   if normal[2]>=0:continue
   shade=1 if material=='Neon' else .5+.5*max(0,np.dot(normal/length,np.array([-.35,.6,-.72])))
   rgb=tuple(int(np.clip(x*shade*255,0,255)) for x in color)
   allfaces.append((points[:,2].mean(),points,(*rgb,int((1-float(alpha))*255))))
 for _,points,color in sorted(allfaces,key=lambda x:x[0],reverse=True):
  xy=[(left+260+p[0]*34,1090-p[1]*34) for p in points]
  draw.polygon(xy,fill=color)
 draw.text((left+25,1140),'PILOT  /  WALK  /  EXPLORE',font=font(18),fill=accent)
target=root/'docs/mechs/mech-lineup.png'
target.parent.mkdir(exist_ok=True,parents=True)
image.save(target)
print(target)
