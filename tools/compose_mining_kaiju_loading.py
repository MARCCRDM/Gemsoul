from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/images/loading-guides/mining-kaiju'
OUT.mkdir(exist_ok=True)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',n)
for mobile,w,h in [(False,1920,1080),(True,1600,900)]:
 im=Image.new('RGB',(w,h),'#081321');d=ImageDraw.Draw(im)
 margin=round(w*.04);gap=round(w*.025);cw=(w-2*margin-gap)//2
 d.text((margin,round(h*.03)),'SAGA MINERS',font=font(round(h*.032)),fill='#eaf5ff')
 mode='TOUCH CONTROLS' if mobile else 'MOUSE CONTROLS'
 f=font(round(h*.022));d.text((w-margin-d.textlength(mode,font=f),round(h*.035)),mode,font=f,fill='#8da7be')
 y=round(h*.105);bottom=round(h*.91)
 for i,(label,col) in enumerate([('MINE','#64dcf2'),('KAIJU AUTO-BATTLE','#bc9cff')]):
  x=margin+i*(cw+gap)
  d.rounded_rectangle((x,y,x+cw,bottom),radius=20,fill='#112236',outline='#294057',width=2)
  art=Image.open(ROOT/'assets/images/ad-thumbnails'/('art-v2-1.png' if i==0 else 'art-v2-3.png')).convert('RGB')
  ah=round(h*.60);art=art.resize((cw-4,ah),Image.Resampling.LANCZOS)
  im.paste(art,(x+2,y+2))
  d.line((x+25,y+ah,x+cw-25,y+ah),fill=col,width=4)
  if mobile:
   title='Tap to MINE' if i==0 else 'KAIJU AUTO-BATTLE'
   sub='Mine rocks. Discover gems.' if i==0 else 'Deploy your team. They fight for you.'
  else:
   title='Click to MINE' if i==0 else 'KAIJU AUTO-BATTLE'
   sub='Mine rocks. Discover gems.' if i==0 else 'Deploy your team. They fight for you.'
  f=font(round(h*(.05 if i==0 else .038)));tw=d.textlength(title,font=f)
  d.text((x+(cw-tw)/2,y+ah+round(h*.024)),title,font=f,fill=col)
  f=font(round(h*.024));tw=d.textlength(sub,font=f)
  d.text((x+(cw-tw)/2,y+ah+round(h*.092)),sub,font=f,fill='#e8f0f8')
 f=font(round(h*.02));d.text((margin,round(h*.952)),'MINE. BUILD YOUR TEAM. BATTLE.',font=f,fill='#8da7be')
 text='LOADING';d.text((w-margin-d.textlength(text,font=f),round(h*.952)),text,font=f,fill='#8da7be')
 name='mining-kaiju-mobile.png' if mobile else 'mining-kaiju-desktop.png'
 im.save(OUT/name)
 print(name,w,h)
