"""Offline combat previs using current Luau geometry/poses; not captured Roblox gameplay."""
from pathlib import Path
import sys, subprocess, re, math, json, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.tools/video_deps'))
import imageio_ffmpeg
FF=imageio_ffmpeg.get_ffmpeg_exe()
OUT=ROOT/'docs/combat-reel'; OUT.mkdir(parents=True,exist_ok=True)
base=(ROOT/'.tools/render_equipment_details.py').read_text(encoding='utf-8').split('for name, path in')[0]
ctx={'__file__':str(ROOT/'.tools/render_equipment_details.py')};exec(base,ctx);source=ctx['source']
source=source.replace('return setmetatable({t={x or 0,y or 0,z or 0}', 'if type(x)=="table" then x,y,z=x.X,x.Y,x.Z end\n return setmetatable({t={x or 0,y or 0,z or 0}')
source+='\nvmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end\nVector3.zero=Vector3.new(0,0,0)\nlocal ArmorFamilies={ById={}}\n'
for name,path in [('ArmorKits','src/server/Systems/ArmorKits.luau'),('Assets','src/server/Systems/FrontierAssets.luau'),('Skins','src/server/Systems/BrainrotSkins.luau'),('RivalPose','src/shared/RivalPose.luau')]:
 s=(ROOT/path).read_text(encoding='utf-8');s=re.sub(r'^local \w+ = require\([^\n]+\)\n','',s,flags=re.M)
 s=s.replace('part.CFrame = seg.Part.CFrame * seg.Offset * cframe','part.PoseBone=seg.Part.Name; part.LocalFrame=seg.Offset*cframe; part.CFrame = seg.Part.CFrame * seg.Offset * cframe')
 s=s.replace('p.CFrame = anchor.CFrame * mount * at','p.PoseBone=anchor.Name;p.LocalFrame=mount*at;p.CFrame = anchor.CFrame * mount * at')
 s=s.replace('p.CFrame = bone.CFrame * CFrame.new(pos) * (rotation or CFrame.identity)','p.PoseBone=bone.Name;p.LocalFrame=CFrame.new(pos)*(rotation or CFrame.identity);p.CFrame = bone.CFrame * p.LocalFrame')
 source+='local '+name+'=(function()\n'+s+'\nend)()\n'
duel=(ROOT/'src/server/Systems/Duelist.luau').read_text(encoding='utf-8');source+=duel[duel.index('local BODY ='):duel.index('local function buildBody')]
source+='''
for _,b in BODY do print("BONE|"..b[1].."|"..b[3].X.."|"..b[3].Y.."|"..b[3].Z) end
for _,j in JOINTS do print("JOINT|"..j[1].."|"..j[2].."|"..j[3].."|"..j[4].X.."|"..j[4].Y.."|"..j[4].Z) end
for model=1,5 do
 table.clear(builtParts)
 local rig={}
 for _,b in BODY do
  local p=Instance.new("Part");p.Name=b[1];p.Size=b[2];p.CFrame=CFrame.new(b[3]);p.Material="SmoothPlastic";p.Color=Color3.new(1,1,1);p.Parent=rig
  p.IsA=function(_,k) return k=="BasePart" end
  p.FindFirstChild=function() return nil end;p.FindFirstChildOfClass=function() return nil end;p.GetChildren=function() return {} end
  rig[b[1]]=p
 end
 rig.GetChildren=function() local t={} for _,b in BODY do table.insert(t,rig[b[1]]) end return t end
 rig.FindFirstChild=function(_,name) return rig[name] end
 rig.SetAttribute=function() end
 if model<=3 then
  local look=if model==2 then "UtilityMiner" elseif model==3 then "FrontierRanger" else "HeavyVanguard"
  ArmorKits.build(rig,rig,look,Color3.fromRGB(75,210,223),1,{Rarity=4,FinishColor=Color3.fromRGB(115,126,145)})
  Assets.sword(rig,rig.RightHand,CFrame.Angles(math.rad(-120),0,0),4,Color3.fromRGB(80,215,235),Color3.fromRGB(125,140,160))
  for _,b in BODY do rig[b[1]].Transparency=1 end
 else
  local spec=if model==4 then {Id="Sahur",Shape="Wood",Element="Fire"} else {Id="Tralalero",Shape="Shark",Element="Frost"}
  Skins.apply(rig,spec,if model==4 then Color3.fromRGB(240,80,50) else Color3.fromRGB(70,170,250),false,5,true)
 end
 print("MODEL|"..model)
 for _,p in builtParts do
  if p.Transparency==1 or not p.PoseBone then continue end
  local row={p.PoseBone,if p.ClassName=="WedgePart" then "Wedge" else p.Shape or "Block",p.Material,tostring(p.Size.X),tostring(p.Size.Y),tostring(p.Size.Z),tostring(p.Color.R),tostring(p.Color.G),tostring(p.Color.B)}
  for _,v in p.LocalFrame.t do table.insert(row,tostring(v)) end
  for _,v in p.LocalFrame.r do table.insert(row,tostring(v)) end
  print(table.concat(row,"|"))
 end
end
for role=1,2 do
 for frame=0,95 do
  local t=frame/24
  local a={}
  if role==1 then
   if t<1.15 then a={ActionKind="Slash",ActionStart=.25,ActionAt=.65}
   else a={ActionKind="Cross",ActionStart=1.85,ActionAt=2.95} end
  else
   if t<2.95 then a={ActionKind="Heavy",ActionStart=.05,ActionAt=.8}
   else a={ActionKind="Stagger",ActionStart=2.95,ActionAt=2.95} end
  end
  local pose=RivalPose.pose(a,t)
  for name,angles in pose do print("POSE|"..role.."|"..frame.."|"..name.."|"..angles[1].."|"..angles[2].."|"..angles[3]) end
 end
end
'''
bundle=OUT/'scene-export.luau';bundle.write_text(source,encoding='utf-8')
raw=subprocess.check_output([str(ROOT/'.tools/luau/luau.exe'),str(bundle)],text=True)
models={};bones={"HumanoidRootPart":np.zeros(3)};joints=[];poses={}
for line in raw.splitlines():
 v=line.split('|')
 if v[0]=='MODEL':current=int(v[1]);models[current]=[]
 elif v[0]=='BONE':bones[v[1]]=np.array(list(map(float,v[2:])))
 elif v[0]=='JOINT':joints.append((v[1],v[2],v[3],np.array(list(map(float,v[4:])))))
 elif v[0]=='POSE':poses.setdefault((int(v[1]),int(v[2])),{})[v[3]]=list(map(float,v[4:]))
 elif len(v)==21:models[current].append((v[0],v[1],v[2],np.array(list(map(float,v[3:])))))
def rot(x=0,y=0,z=0):
 cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 return np.array([[cy*cz,-cy*sz,sy],[cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy],[sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy]])
box=np.array([[x,y,z] for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])
boxfaces=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
meshes={}
for model,parts in models.items():
 meshes[model]=[]
 for bone,shape,mat,data in parts:
  size,col,pos,R=data[:3],data[3:6],data[6:9],data[9:].reshape(3,3)
  verts=box*size;faces=boxfaces
  if shape=='Wedge':verts=verts.copy();verts[verts[:,2]<0,1]=-size[1]/2
  elif shape=='Ball':
   verts=np.array([[math.cos(lat)*math.cos(lon)*size[0]/2,math.sin(lat)*size[1]/2,math.cos(lat)*math.sin(lon)*size[2]/2] for lat in np.linspace(-math.pi/2,math.pi/2,7) for lon in np.linspace(0,2*math.pi,12,endpoint=False)])
   faces=[[j*12+i,j*12+(i+1)%12,(j+1)*12+(i+1)%12,(j+1)*12+i] for j in range(6) for i in range(12)]
  elif shape=='Cylinder':
   verts=np.array([[side*size[0]/2,math.cos(a)*size[1]/2,math.sin(a)*size[2]/2] for side in (-1,1) for a in np.linspace(0,2*math.pi,16,endpoint=False)])
   faces=[list(range(16)),list(range(16,32))]+[[i,(i+1)%16,(i+1)%16+16,i+16] for i in range(16)]
  verts=verts@R.T+pos
  normals=[]
  for face in faces:
   pts=verts[face];n=np.cross(pts[1]-pts[0],pts[2]-pts[0]);ln=np.linalg.norm(n);normals.append(n/max(ln,1e-7))
  meshes[model].append((bone,verts,faces,col,mat,np.array(normals)))
W,H=1280,720;FPS=24
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
bold=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',n)
f14,f18,f24,f38=font(14),font(18),bold(24),bold(38)
scenes=[('THERMAL','SOLAR EXECUTION','AI MINER / UTILITY RIG',2,(255,104,51),'cast_fire','impact_fire'),('CRYO','SHATTER CROWN','AI MINER / RANGER RIG',3,(92,205,255),'cast_frost','impact_frost'),('CORROSIVE','DISSOLUTION','COLOSSUS / TUNG TUNG',4,(108,245,130),'cast_poison','impact_poison'),('ION','RAILSTORM','COLOSSUS / TRALALERO',5,(255,217,78),'cast_shock','impact_shock')]
view=rot(.14,.15,0)
def project(p,scale=53):
 q=np.asarray(p)@view.T
 return np.column_stack((640+q[:,0]*scale,450-q[:,1]*scale))
def model_polys(model,role,frame,t,scene):
 pose=poses.get((role,frame),{})
 frames={'HumanoidRootPart':(np.eye(3),np.zeros(3))}
 for joint,parent,child,at in joints:
  pr,pp=frames[parent];jr=pr@rot(*pose.get(joint,[0,0,0]));jp=pp+pr@(at-bones[parent])+jr@(bones[child]-at)
  frames[child]=(jr,jp)
 scale=1.45 if model>=4 else 1
 origin=np.array([-3.4,0,0]) if role==1 else np.array([3.,0,0])
 facing=rot(0,-1.25 if role==1 else .75,0)
 if role==2:
  origin[0]-=.45*math.sin(min(t,1.2)*math.pi/1.2)
  death=max(0,min(1,(t-3)/.75))
  facing=rot(0,.75,-death*1.38)
  origin[1]-=death*.7
 else:origin[0]-=.35*math.sin(min(t,1.7)*math.pi/1.7)
 result=[]
 for bone,verts,faces,col,mat,normals in meshes[model]:
  br,bp=frames.get(bone,(np.eye(3),bones.get(bone,np.zeros(3))))
  world=(verts@br.T+bp)*scale
  if role==2 and t>=3:
   pivot=np.array([0,-3*scale,0]);world=(world-pivot)@facing.T+pivot+origin
  else:world=world@facing.T+origin
  v=world@view.T
  ns=normals@br.T@facing.T@view.T
  shades=np.full(len(faces),1.15) if mat=='Neon' else .56+.44*np.abs(ns@np.array([-.3,.7,-.64]))
  hit=max(0,1-abs(t-3.04)/.16) if role==2 else 0
  colors=np.clip(shades[:,None]*col[None,:]*(1-hit)*255+np.array(scenes[scene][4])*hit,0,255).astype(int)
  projected=np.column_stack((640+v[:,0]*53,450-v[:,1]*53))
  for i,face in enumerate(faces):
   result.append((float(sum(v[k,2] for k in face)/len(face)),projected[face],tuple(colors[i])))
 return result
# Static scene background: stylized expedition canyon, not a recreation of Studio lighting.
bg=Image.new('RGB',(W,H),'#121e30');d=ImageDraw.Draw(bg)
for y in range(H):
 c=int(19+y*.027);d.line((0,y,W,y),fill=(c, c+10,c+20))
d.polygon([(0,210),(160,152),(295,227),(470,169),(630,224),(800,148),(975,193),(1140,132),(1280,210),(1280,720),(0,720)],fill='#334252')
d.polygon([(0,327),(1280,308),(1280,720),(0,720)],fill='#48505a')
for z in range(-12,18,3):
 pts=project([[-16,-3.15,z],[16,-3.15,z]]);d.line([tuple(p) for p in pts],fill='#555f68',width=1)
for x in range(-18,19,3):
 pts=project([[x,-3.15,-12],[x,-3.15,18]]);d.line([tuple(p) for p in pts],fill='#555f68',width=1)
for x,y,r in [(80,315,60),(1150,325,85),(210,370,30),(1030,362,38)]:
 d.polygon([(x-r,y),(x-r*.4,y-r*1.7),(x+r*.3,y-r*1.4),(x+r,y),(x+r*.5,y+25)],fill='#273747')
proc=subprocess.Popen([FF,'-y','-f','rawvideo','-vcodec','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','ultrafast','-crf','19','-pix_fmt','yuv420p',str(OUT/'silent-v2.mp4')],stdin=subprocess.PIPE,stderr=(OUT/'encode-v2.log').open('w'))
thumbs=[]
for scene,info in enumerate(scenes):
 element,spell,target,model,color,*_=info
 for frame in range(96):
  t=frame/FPS;im=bg.copy();draw=ImageDraw.Draw(im)
  draw.ellipse((390,580,560,615),fill='#2e3540');draw.ellipse((705,585,965,630),fill='#2e3540')
  polys=model_polys(1,1,frame,t,scene)+model_polys(model,2,frame,t,scene)
  for _,xy,col in sorted(polys,key=lambda p:p[0],reverse=True):draw.polygon([tuple(p) for p in xy],fill=col)
  fx=Image.new('RGBA',(W,H));fd=ImageDraw.Draw(fx)
  start=np.array([515,350]);end=np.array([805,340 if model<4 else 300])
  charge=max(0,min(1,(t-1.85)/1.1));impact=max(0,min(1,(t-2.95)/.45))
  if 1.85<t<3.04:
   r=14+charge*30
   fd.ellipse((start[0]-r,start[1]-r,start[0]+r,start[1]+r),outline=(*color,210),width=3)
   for n in range(8):
    a=n*math.pi/4+t*4;p=start+np.array([math.cos(a),math.sin(a)])*r
    fd.line((tuple(p),tuple(start+(p-start)*.7)),fill=(*color,230),width=3)
  if 2.95<=t<3.65:
   opacity=int(255*max(0,1-(t-3.1)/.6))
   if scene in (0,2,3):
    for n in range(3):
     points=[tuple(start+(end-start)*p+np.array([0,math.sin(p*16+t*35+n)* (12 if scene==3 else 4)])) for p in np.linspace(0,1,20)]
     fd.line(points,fill=(*color,opacity),width=9-n*3)
   if scene==1:
    for n in range(9):
     x=end[0]+(n-4)*24;y=end[1]+135;h=50+60*math.sin((n+1)*1.7)**2
     fd.polygon([(x-10,y),(x,y-h*impact),(x+11,y)],fill=(*color,opacity))
   rr=25+impact*100
   fd.ellipse((end[0]-rr,end[1]-rr*.6,end[0]+rr,end[1]+rr*.6),outline=(*color,opacity),width=5)
   rng=random.Random(scene*100)
   for n in range(38):
    a=rng.random()*math.tau;speed=rng.uniform(35,165);p=end+np.array([math.cos(a),math.sin(a)])*speed*impact
    fd.line((tuple(p),tuple(p+np.array([math.cos(a),math.sin(a)])*8)),fill=(*color,opacity),width=3)
  im=Image.alpha_composite(im.convert('RGBA'),fx.filter(ImageFilter.GaussianBlur(9)))
  im=Image.alpha_composite(im,fx).convert('RGB');draw=ImageDraw.Draw(im)
  draw.rectangle((0,0,W,125),fill='#101925');draw.rectangle((0,0,7,125),fill=color)
  draw.text((30,19),f'0{scene+1} / {element}',font=f18,fill=color)
  draw.text((28,47),spell,font=f38,fill='#f2f5fa')
  draw.text((W-26,26),'COMBAT PREVIS / SIMULATION',font=f18,fill='#aebdce',anchor='ra')
  draw.text((W-26,61),'CURRENT MODELS + COMBAT POSES',font=f14,fill='#8796a8',anchor='ra')
  draw.text((640,151),target,font=f24,fill='#eef2f7',anchor='mt')
  draw.rounded_rectangle((437,187,843,205),6,fill='#14212b')
  health=.28 if t<2.95 else max(0,.28*(1-(t-2.95)/.14))
  if health>0:draw.rounded_rectangle((440,190,440+400*health,202),4,fill=color)
  if t>3.12:draw.text((640,238),'ELIMINATED',font=f38,fill=color,anchor='mt')
  draw.rectangle((0,662,W,720),fill='#101925')
  label='FINAL ENGAGEMENT' if t<1.85 else ('SURGE CHARGING' if t<2.95 else 'FINISHING HIT')
  draw.text((30,681),label,font=f18,fill=color)
  draw.text((W-28,683),'SAGA MINERS  /  GAME MUSIC + ELEMENTAL SFX',font=f14,fill='#aebdce',anchor='ra')
  draw.rectangle((0,716,int(W*(frame+1)/96),720),fill=color)
  if frame==0: im.save(OUT/f'first-{scene+1}.png')
  if frame==74:
   im.save(OUT/f'scene-{scene+1}.png');thumbs.append(im.resize((640,360)))
  proc.stdin.write(im.tobytes())
 print('Rendered scene',scene+1,spell,flush=True)
proc.stdin.close();assert proc.wait()==0
sheet=Image.new('RGB',(1280,720))
for i,im in enumerate(thumbs):sheet.paste(im,((i%2)*640,(i//2)*360))
sheet.save(OUT/'contact-sheet.jpg')
args=[FF,'-y','-i',str(OUT/'silent-v2.mp4'),'-i',str(ROOT/'assets/music/fight_theme.ogg')]
filters=['[1:a]atrim=0:16,asetpts=PTS-STARTPTS,volume=0.55,afade=t=out:st=15.4:d=0.6[music]'];mix=['[music]'];idx=2
for scene,info in enumerate(scenes):
 for name,when,vol in [(info[5],1.85,.7),(info[6],2.95,.9),('death',3.18,.6)]:
  args+=['-i',str(ROOT/f'assets/sounds/combat/{name}.mp3')]
  delay=int((scene*4+when)*1000);tag=f'a{idx}'
  filters.append(f'[{idx}:a]volume={vol},adelay={delay}|{delay}[{tag}]');mix.append(f'[{tag}]');idx+=1
filters.append(''.join(mix)+f'amix=inputs={len(mix)}:duration=first:normalize=0,alimiter=limit=0.92[audio]')
args+=['-filter_complex',';'.join(filters),'-map','0:v','-map','[audio]','-c:v','copy','-c:a','aac','-b:a','192k','-t','16','-movflags','+faststart',str(OUT/'Saga-Miners-Elemental-Finishers.mp4')]
subprocess.run(args,check=True,stdout=subprocess.DEVNULL,stderr=(OUT/'audio.log').open('w'))
(OUT/'README.md').write_text('Four 4-second simulated combat finishers. Each kill lands at 2.95s within its scene. Current ArmorKits, FrontierAssets, BrainrotSkins and RivalPose geometry/poses; offline lighting, scripted damage/death and illustrative VFX. Not Roblox gameplay capture. Audio: assets/music/fight_theme.ogg plus the matching elemental cast/impact and death SFX. No game files or combat mechanics were changed.\n',encoding='utf-8')
print(OUT/'Saga-Miners-Elemental-Finishers.mp4',flush=True)

