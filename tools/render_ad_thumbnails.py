from pathlib import Path
import json,sys,subprocess,math,zipfile
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
sys.path.insert(0,str(Path(__file__).resolve().parent))
from make_lobby_cards import Scene,pose
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/images/ad-thumbnails';OUT.mkdir(exist_ok=True)
DATA=Path('C:/Users/clapr/OneDrive/Documents/output/Kaiju-concept-rebuild')
F=json.loads((ROOT/'assets/images/loading-guides/combat/miner-poses.json').read_text(encoding='utf8'))
class Render(Scene):
 def shade(self,base,normal,centre,neon,dim=1):
  if neon:return base*1.7,base*1.2
  k=max(0.,float(normal @ np.array([-.35,.55,.76])))
  f=max(0.,float(normal @ np.array([.8,.2,-.4])))
  return (base*(.48+k*.95)+self.accent*f*.22)*dim,None

def convert(p,r,s,c,shape,neon=False):
 r=np.array(r).reshape(3,3)
 return list(p)+list(r[:,0])+list(r[:,1])+list(-r[:,2])+list(s)+list(c)+[shape,neon,False]
def pet(n,e,scale=1):
 rows=json.loads((DATA/f'{n}-{e}.json').read_text())
 return [convert(np.array(p['p'])*scale,p['r'],np.array(p['s'])*scale,p['c'],'Wedge' if p['shape']=='WedgePart' else 'Block',p['neon']) for p in rows]
def sized(parts,scale):
 return [[v*scale for v in p[:3]]+p[3:12]+[v*scale for v in p[12:15]]+p[15:] for p in parts]
raw=subprocess.check_output([str(ROOT/'.tools/luau/luau.exe'),str(ROOT/'.tools/sahur-pose-preview.luau')],text=True)
boss=[]
for line in raw.splitlines():
 v=line.split('|')
 if v[0]=='MODEL':
  if boss:break
 elif len(v)==20:
  a=list(map(float,v[2:]));boss.append(convert(a[6:9],a[9:],a[:3],a[3:6],v[0],v[1]=='Neon'))
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',n)
colors=[(83,224,255),(255,179,78),(171,143,255),(122,244,151),(255,208,96)]
names=['01-mine-enchant','02-arena-pvp','03-kaiju-team','04-stop-the-rot','05-mine-build-battle']
headlines=[['MINE THE','RAREST','GEMS'],['ENTER','THE','ARENA'],['BUILD YOUR','KAIJU','TEAM'],['FIGHT THE','INVASION','STOP THE ROT'],['MINE.','BUILD.','BATTLE.']]
subs=['ENCHANT ARMOR + WEAPONS','COMPETITIVE ARENA PvP','CATCH. LEVEL UP. AUTO-BATTLE.','FIGHT BACK AGAINST THE ROT','GEMS. GEAR. KAIJUS.']
for i in range(5):
 color=np.array(colors[i])/255
 path=OUT/f'art-v2-{i+1}.png'
 if not path.exists():
  s=Render(1100,900,eye=(0,4.3,15.5),target=(0,3.7,0),fov=44,accent=color,seed=40+i)
  if i==0:specs=[(pose(json.loads((OUT/'mining-poses.json').read_text(encoding='utf8')),'Heavy',1),(-1.2,0),230)]
  elif i==1:specs=[(pose(F,'Slash',1),(-2.2,0),245),(pose(F,'Guard (blocking)',1),(2.4,-.5),120)]
  elif i==2:specs=[(pet('Emberjaw','Fire',1.12),(-2.6,1),145),(pet('Brightsteel','Frost',1.1),(1.9,1),205),(pet('Stormwing','Shock',1.25),(0,-1),180)]
  elif i==3:specs=[(sized(boss,1.2),(2,-1),190),(pose(F,'Slash',1),(-2.5,1),55)]
  else:specs=[(pet('Emberjaw','Fire',.60),(-2.9,.6),160),(pose(F,'Stance'),(0,-.2),195),(pet('Brightsteel','Frost',.7),(3,0),210)]
  s.fighters(specs)
  s.backdrop((.012,.019,.04),(.055,.09,.13),planet=(920,150,110,(.2,.35,.5)),shafts=((.55,.1,.45),))
  if i==1:s.glow(555,350,100,color,.7);s.sparks(555,350,95,26,color)
  if i==3:
   s.ring(610,115,255,85,color,7);s.glow(610,115,240,color,.7);s.embers(30,color)
  s.finish().save(path)
 art=Image.open(path).convert('RGBA')
 im=Image.new('RGBA',(1600,900),(8,15,27,255));im.alpha_composite(art,(500,0))
 # Fade the art into the headline field, leaving characters unobscured.
 fade=Image.new('RGBA',(1600,900));arr=np.zeros((900,1600,4),dtype=np.uint8);arr[:,:,:3]=[8,15,27]
 arr[:,:,3]=np.clip((820-np.arange(1600))/300*255,0,255).astype(np.uint8)
 im=Image.alpha_composite(im,Image.fromarray(arr))
 if i==0 or i==4:
  gem=Image.open(ROOT/'assets/images/loading-guides/illustrations/gem-Frost.png').convert('RGBA')
  gem.thumbnail((310,260));im.alpha_composite(gem,(1240,575 if i==0 else 90))
  if i==0:
   for typ,x,y,sz in [('Fire',1070,660,160),('Shock',1380,420,140)]:
    g=Image.open(ROOT/f'assets/images/loading-guides/illustrations/gem-{typ}.png').convert('RGBA');g.thumbnail((sz,sz));im.alpha_composite(g,(x,y))
 d=ImageDraw.Draw(im)
 d.rounded_rectangle((64,55,346,111),radius=14,fill=tuple(colors[i])+(255,))
 d.text((83,65),'SAGA MINERS',font=font(30),fill='#08121e')
 for j,line in enumerate(headlines[i]):
  size=100 if len(line)<11 else 74
  if i==3 and j==2:size=61
  d.text((64,235+j*111),line,font=font(size),fill=tuple(colors[i]) if j==len(headlines[i])-1 else '#f5f8ff',stroke_width=2,stroke_fill='#08121e')
 d.line((67,625,385,625),fill=tuple(colors[i]),width=6)
 # Minimal two-line support for easy reading in small placements.
 sub=subs[i];f=font(29)
 d.text((67,657),sub,font=f,fill='#d9e6f2')
 d.text((67,812),'DISCOVER YOUR NEXT UPGRADE' if i==0 else 'SAGA MINERS',font=font(20),fill='#8da6bf')
 im.convert('RGB').save(OUT/(names[i]+'.png'))
 print(names[i],flush=True)
thumbs=Image.new('RGB',(1200,1050),'#080f1b')
for i,n in enumerate(names):
 im=Image.open(OUT/(n+'.png'));im.thumbnail((580,326));thumbs.paste(im,((i%2)*600,(i//2)*350))
thumbs.save(OUT/'preview.jpg',quality=95)
with zipfile.ZipFile(OUT/'saga-miners-thumbnails.zip','w',zipfile.ZIP_DEFLATED) as z:
 for n in names:z.write(OUT/(n+'.png'),n+'.png')
