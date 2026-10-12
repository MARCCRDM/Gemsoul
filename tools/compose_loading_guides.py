from pathlib import Path
import sys,subprocess,math,json,zipfile
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/images/loading-guides';OUT.mkdir(parents=True,exist_ok=True)
ART=OUT/'illustrations';ART.mkdir(exist_ok=True)
W,H=1920,1080
FONT='C:/Windows/Fonts/'
def font(n,b=False):return ImageFont.truetype(FONT+('segoeuib.ttf' if b else 'segoeui.ttf'),n)
WHITE=(236,243,247);MUTED=(150,173,188);GOLD=(255,209,105);CYAN=(72,206,230)
def txt(im,p,t,n=26,c=WHITE,b=False):ImageDraw.Draw(im).text(p,t,font=font(n,b),fill=c)
def fit(im,size):
 scale=min(size[0]/im.width,size[1]/im.height);return im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
# Facets exported by the project's GemShapes renderer, not newly designed artwork.
data=subprocess.check_output([str(ROOT/'.tools/luau/luau.exe'),str(ROOT/'.tools/site-gems.luau')],text=True)
gems={}
for line in data.splitlines():
 if line.startswith('GEM|'):key=line.split('|')[1];gems[key]=[]
 else:
  v=list(map(float,line.split('|')));gems[key].append((np.array(v[:9]).reshape(3,3),tuple(int(x*255) for x in v[9:])))
def gem(key,size=600):
 im=Image.new('RGBA',(size,size));d=ImageDraw.Draw(im)
 a=-.55;b=.4
 rx=np.array([[1,0,0],[0,math.cos(a),-math.sin(a)],[0,math.sin(a),math.cos(a)]])
 ry=np.array([[math.cos(b),0,math.sin(b)],[0,1,0],[-math.sin(b),0,math.cos(b)]])
 faces=[(v@ry.T@rx.T,c) for v,c in gems[key]]
 for v,c in sorted(faces,key=lambda t:t[0][:,2].mean()):
  normal=np.cross(v[1]-v[0],v[2]-v[0]);normal/=max(np.linalg.norm(normal),1e-8)
  lighting=.52+.48*abs(np.dot(normal,np.array([-.35,.65,.67])))
  shaded=tuple(int(min(255,x*lighting)) for x in c)
  d.polygon([(size/2+x*size*.35,size/2-y*size*.35) for x,y,z in v],fill=shaded)
 return im
for e in gems:gem(e).save(ART/f'gem-{e}.png')
def gear(name):
 im=Image.open(ROOT/f'docs/armor-review/{name}.png').convert('RGBA').crop((8,8,332,295))
 ar=np.array(im); bg=np.array([20,35,51]); dist=np.max(np.abs(ar[:,:,:3].astype(int)-bg),axis=2)
 # Review renders use a flat navy background; retain original model colors.
 ar[:,:,3]=np.where(dist<5,0,255)
 im=Image.fromarray(ar);box=im.getbbox();return im.crop(box) if box else im
helmet=gear('Prospector-Helmet-1');chest=gear('Prospector-Chest-1');shield=gear('Prospector-Shield-1')
for name,im in [('helmet',helmet),('chest',chest),('shield',shield)]:im.save(ART/f'{name}.png')
atlas=Image.open(ROOT/'assets/images/ability_icons.png').convert('RGBA')
def icon(index):
 x=(index%8)*128;y=(index//8)*128;return atlas.crop((x,y,x+128,y+128))
for n,i in [('EmberLance',10),('CryoShield',17),('IonSpark',24)]:icon(i).save(ART/f'{n}.png')
def paste(im,art,box):
 x,y,w,h=box;art=fit(art,(w,h));im.alpha_composite(art,(int(x+(w-art.width)/2),int(y+(h-art.height)/2)))
def glow(im,x,y,r,col):
 layer=Image.new('RGBA',im.size);d=ImageDraw.Draw(layer);d.ellipse((x-r,y-r,x+r,y+r),fill=(*col,45));im.alpha_composite(layer.filter(ImageFilter.GaussianBlur(r*.6)))
def base(num,tag,title,tip):
 yy,xx=np.mgrid[0:H,0:W];v=np.clip(1-np.sqrt(((xx-1200)/1800)**2+((yy-400)/1000)**2),0,1)
 a=np.zeros((H,W,4),dtype=np.uint8)
 for j,(lo,hi) in enumerate([(7,16),(13,31),(21,43)]):a[:,:,j]=lo+v*(hi-lo)
 a[:,:,3]=255;im=Image.fromarray(a);d=ImageDraw.Draw(im)
 for x in range(64,W,96):d.line((x,130,x,825),fill=(22,37,49),width=1)
 for y in range(150,830,96):d.line((65,y,1855,y),fill=(22,37,49),width=1)
 txt(im,(72,46),'SAGA MINERS  /  FIELD GUIDE',22,MUTED,True)
 txt(im,(72,91),tag.upper(),28,GOLD,True)
 txt(im,(1730,55),f'{num:02d} / 05',25,MUTED)
 d.line((72,149,1848,149),fill=(49,67,79),width=1)
 txt(im,(72,866),title,56,WHITE,True);txt(im,(76,947),tip,28,MUTED)
 d.line((76,1030,1640,1030),fill=(56,73,85),width=3)
 # Static concept label, progress supplied at runtime, no fake percentage.
 txt(im,(1692,1010),'LOADING',20,GOLD,True)
 return im

def panel(im,box,label,sub=None):
 x,y,w,h=box;d=ImageDraw.Draw(im);d.rounded_rectangle((x,y,x+w,y+h),radius=24,fill=(13,24,34),outline=(46,65,80),width=2)
 txt(im,(x+26,y+h-74),label,25,WHITE,True)
 if sub:txt(im,(x+26,y+h-38),sub,18,MUTED)

def arrow(im,x,y,left=False):
 d=ImageDraw.Draw(im);d.line((x-30,y,x+30,y),fill=GOLD,width=4);s=-1 if left else 1;d.line((x+s*10,y-17,x+s*30,y,x+s*10,y+17),fill=GOLD,width=4)

def save(im,name):
 im.convert('RGB').save(OUT/f'{name}.png')
 im.crop((0,150,W,840)).save(ART/f'{name}-scene.png')

im=base(1,'Mining','Every discovery starts with a swing.','Click, tap, or press E for each swing. Break rocks to discover gems.')
# Existing posed miner artwork made from ArmorKits + RivalPose.
hero=Image.open(ROOT/'assets/images/intro/style_Prospector.png').convert('RGBA')
panel(im,(72,195,680,620),'YOUR MINER','Explore the Outpost and mine its rocks.')
paste(im,hero,(92,215,640,495))
txt(im,(830,219),'DISCOVER YOUR NEXT UPGRADE',25,GOLD,True)
for e,x,y,s in [('Frost',1370,250,370),('Shock',1225,430,380),('Fire',855,280,560)]:
 glow(im,x+s/2,y+s/2,s*.3,{'Fire':(232,80,65),'Frost':(60,160,245),'Shock':(230,195,54)}[e]);paste(im,gem(e),(x,y,s,s))
txt(im,(850,754),'MINE  /  DISCOVER  /  BUILD',27,WHITE,True)
save(im,'01-mining')

im=base(2,'Gem uses','One gem. Two ways to build.','Enchant equipment or equip a Surge. Each gem occupies one place at a time.')
panel(im,(75,240,475,530),'ENCHANT YOUR EQUIPMENT','Strengthen the way your gear works.')
paste(im,chest,(145,280,330,360))
glow(im,955,485,250,(225,75,55));paste(im,gem('Fire'),(660,230,580,520))
txt(im,(800,745),'CHOOSE ITS ROLE',25,GOLD,True)
panel(im,(1370,240,475,530),'EQUIP AN ACTIVE SURGE','Put an ability on your hotbar.')
paste(im,icon(10),(1450,290,310,310));arrow(im,1268,505);arrow(im,610,505,True)
save(im,'02-gem-uses')

im=base(3,'Enchanting','Give your gear an edge.','Select a gear slot, choose a gem, then read the effect on your equipment.')
for x,l,s in [(76,'01  SELECT YOUR GEAR','Open its equipment slot.'),(713,'02  CHOOSE A GEM','Use a gem from your inventory.'),(1350,'03  READ THE EFFECT','Build around the resulting perk.')]:panel(im,(x,220,495,565),l,s)
paste(im,helmet,(155,270,340,330));paste(im,gem('Frost'),(730,245,460,385));paste(im,helmet,(1450,263,280,280));paste(im,gem('Frost'),(1665,445,130,130))
arrow(im,640,490);arrow(im,1276,490)
txt(im,(1385,591),'GEAR + GEM',28,GOLD,True)
save(im,'03-enchanting')

im=base(4,'Surges','Equip it. Charge it. Unleash it.','Equip Surges in Q, E, or R. On mobile, tap their ability buttons.')
for x,key,n,idx,e,c in [(76,'Q','EMBER LANCE',10,'Fire',(239,101,72)),(713,'E','CRYO SHIELD',17,'Frost',(76,172,245)),(1350,'R','ION SPARK',24,'Shock',(244,211,70))]:
 panel(im,(x,218,495,568),n,'Example loadout · choose your own Surges')
 glow(im,x+248,456,200,c);paste(im,icon(idx),(x+110,280,275,275));paste(im,gem(e),(x+306,500,160,150))
 ImageDraw.Draw(im).rounded_rectangle((x+26,244,x+92,310),radius=12,fill=c);txt(im,(x+45,249),key,36,(10,19,28),True)
 txt(im,(x+28,620),'ABILITY ICON + GEM',20,c,True)
save(im,'04-surges')

im=base(5,'Charge','Earn your power. Then spend it.','Start at zero Charge. Land attacks to build it, then spend it on Surges.')
scene=Image.open(ROOT/'docs/combat-reel/scene-1.png').convert('RGBA').crop((250,205,940,662))
panel(im,(76,225,600,550),'01  LAND YOUR ATTACKS','Hits build Charge.')
paste(im,scene,(96,252,560,370))
panel(im,(726,225,530,550),'02  BUILD CHARGE','Compare costs before spending it.')
txt(im,(771,344),'CHARGE',23,CYAN,True)
for i in range(8):ImageDraw.Draw(im).rounded_rectangle((772+i*55,407,814+i*55,507),radius=5,fill=GOLD if i<5 else (37,54,67))
txt(im,(771,554),'STRIKE  →  FILL  →  CAST',24,WHITE,True)
panel(im,(1306,225,538,550),'03  UNLEASH A SURGE','Your equipped ability spends Charge.')
paste(im,icon(24),(1420,284,300,300));save(im,'05-charge')

names=['01-mining','02-gem-uses','03-enchanting','04-surges','05-charge']
sheet=Image.new('RGB',(1440,3*430),(7,13,21));dd=ImageDraw.Draw(sheet)
for i,n in enumerate(names):
 thumb=Image.open(OUT/f'{n}.png').resize((704,396),Image.Resampling.LANCZOS);x=8+(i%2)*720;y=8+(i//2)*430;sheet.paste(thumb,(x,y));dd.text((x+5,y+398),n,font=font(18),fill=WHITE)
sheet.save(OUT/'preview.jpg',quality=94)
manifest={'format':'1920x1080 PNG','type':'Static loading-screen compositions; progress should be drawn live in game','sources':['docs/armor-review/Prospector-*-1.png','assets/images/intro/style_Prospector.png','assets/images/ability_icons.png','docs/combat-reel/scene-1.png','.tools/site-gems.luau (GemShapes geometry)'],'screens':names,'note':'Composited existing renders and exported game geometry; not Roblox runtime screenshots. No AI-generated imagery.'}
(OUT/'sources.json').write_text(json.dumps(manifest,indent=2))
with zipfile.ZipFile(OUT/'loading-guides.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in OUT.rglob('*'):
  if p.is_file() and p.suffix!='.zip':z.write(p,p.relative_to(OUT))
print(OUT)
