"""Combat loading layouts rendered from exported ArmorKits / RivalPose geometry."""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from make_lobby_cards import Scene,pose
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/images/loading-guides/combat'
frames=json.loads((OUT/'miner-poses.json').read_text(encoding='utf-8'))
colors=[(255,173,104),(92,210,239),(186,153,255)]
class GuideScene(Scene):
 def shade(self,base,normal,centre,neon,dim=1):
  if neon:return self.accent*1.4,self.accent*1.6
  key=max(0.,float(normal @ np.array([-.35,.55,.76])))
  fill=max(0.,float(normal @ np.array([.8,.2,-.4])))
  lit=base*(.48+key*.95)+self.accent*fill*.28
  return lit*dim,None

poses=['Slash · strike','Guard (blocking) · held','Beam (held) · pouring']
arts=[]
for i,name in enumerate(poses):
 path=OUT/f'pose-action-{i+1}.png'
 color=np.array(colors[i],np.float32)/255
 scene=GuideScene(1100,900,eye=(0,3.8,12),target=(0,3.25,0),fov=42,accent=color,seed=30+i)
 frame=next(f for f in frames if f['Name']==name)
 parts=frame['Parts']
 # Casting is shown with an empty casting hand, using the real arm pose.
 if i==2:parts=[p for p in parts if not p[20]]
 yaw=[240,145,120][i]
 scene.fighters([(parts,(0,0),yaw)])
 scene.backdrop((.014,.024,.043),(.045,.065,.10),shafts=((.5,.08,.35),))
 feet=min(p[1] for p in parts)-.05
 rad=np.deg2rad(yaw);c,sn=np.cos(rad),np.sin(rad)
 rot=np.array([[c,0,sn],[0,1,0],[-sn,0,c]])
 def screen(v):return scene.project((np.asarray(v)-[0,feet,0]) @ rot.T)[...,:2]
 grip=screen([frame['Grip']])[0]
 if i==2:
  x,y=grip
  scene.glow(x,y,115,color,1.25)
  scene.ring(x,y,60,60,color,4)
  scene.sparks(x,y,105,24,color)
  for t in np.linspace(0,1,16):
   scene.glow(x-180*t,y-35*t,32*(1-t)+10,color,.35)
 elif i==0:
  weapons=np.array([p[:3] for p in parts if p[20]])
  tip=screen(weapons)[np.argmax(np.linalg.norm(weapons-frame['Grip'],axis=1))]
  x,y=tip
  # A swept light trail terminating at the actual sword tip.
  for t in np.linspace(0,1,48):
   scene.glow(x+170*np.sin(t*1.5),y+170*t,7+13*t,color,.30*(1-t)+.08)
  scene.sparks(x,y,48,10,color)
 else:
  scene.glow(475,355,100,color,.35)
  scene.sparks(475,355,70,15,color)
 scene.finish().save(path)
 arts.append(Image.open(path))

def font(n,b=False):return ImageFont.truetype('C:/Windows/Fonts/'+('segoeuib.ttf' if b else 'segoeui.ttf'),n)
def draw(mobile=False):
 w,h=(1600,900) if mobile else (1920,1080)
 im=Image.new('RGB',(w,h),'#091322');d=ImageDraw.Draw(im)
 margin=64 if mobile else 80;gap=24;cw=(w-2*margin-2*gap)//3
 d.text((margin,34),'SAGA MINERS   /   COMBAT FIELD GUIDE',font=font(20 if mobile else 24,True),fill='#9fb6ca')
 d.text((margin,77),'STRIKE. GUARD. UNLEASH.',font=font(46 if mobile else 62,True),fill='#f1f6fb')
 d.text((margin,145 if mobile else 164),'TOUCH CONTROLS' if mobile else 'MOUSE + KEYBOARD',font=font(19 if mobile else 22,True),fill='#ffd277')
 y=206 if mobile else 232;bottom=h-130
 titles=['ATTACK','BLOCK','ABILITIES']
 controls=['TAP ATTACK','HOLD GUARD','TAP AN ABILITY'] if mobile else ['LEFT CLICK','HOLD RIGHT CLICK','Q   /   E   /   R']
 notes=['Swing your weapon.','Keep holding to block.','Use your equipped moves.']
 for i in range(3):
  x=margin+i*(cw+gap);col=colors[i]
  d.rounded_rectangle((x,y,x+cw,bottom),radius=18,fill='#101f31',outline='#2c4058',width=2)
  ah=int(cw*.80);art=arts[i].resize((cw-4,ah),Image.Resampling.LANCZOS);im.paste(art,(x+2,y+2))
  d.line((x+20,y+ah+4,x+cw-20,y+ah+4),fill=col,width=3)
  d.text((x+24,y+ah+21),f'0{i+1}  {titles[i]}',font=font(20 if mobile else 24,True),fill=col)
  d.text((x+24,y+ah+58),controls[i],font=font(27 if mobile else 34,True),fill='#f4f8ff')
  d.text((x+24,y+ah+108),notes[i],font=font(22 if mobile else 25),fill='#b6c7da')
 d.text((margin,h-91),'Watch your stamina. Time your guard. Use abilities when ready.',font=font(22 if mobile else 26),fill='#b6c7da')
 d.line((margin,h-38,w-margin-140,h-38),fill='#30445b',width=3)
 d.text((w-margin-112,h-54),'LOADING',font=font(20,True),fill='#ffd277')
 im.save(OUT/('combat-mobile.png' if mobile else 'combat-desktop.png'))
draw();draw(True)
(OUT/'README.md').write_text('''# Combat loading screens

- Desktop: 1920 x 1080, left click / hold right click / Q E R.
- Mobile landscape: 1600 x 900, tap ATTACK / hold GUARD / tap ability.
- Art rendered from actual ArmorKits, FrontierAssets and RivalPose geometry exported by tools/card_poses.luau. No generated character art.
- These are ready-to-upload artwork files, not installed Roblox image IDs. Loading progress is deliberately not baked into the images; overlay the real progress at runtime.
- Rebuild with tools/render_combat_loading.py. This regenerates the action poses and both layouts.
''',encoding='utf-8')
print(OUT)
