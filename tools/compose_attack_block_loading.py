from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/images/loading-guides/combat'
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',n)
for mobile,w,h in [(False,1920,1080),(True,1600,900)]:
 im=Image.new('RGB',(w,h),'#081321');d=ImageDraw.Draw(im)
 margin=round(w*.04);gap=round(w*.025);cw=(w-2*margin-gap)//2
 d.text((margin,round(h*.03)),'SAGA MINERS',font=font(round(h*.032)),fill='#eaf5ff')
 mode='TOUCH CONTROLS' if mobile else 'MOUSE CONTROLS'
 f=font(round(h*.022));d.text((w-margin-d.textlength(mode,font=f),round(h*.035)),mode,font=f,fill='#8da7be')
 y=round(h*.105);bottom=round(h*.91)
 for i,(label,col) in enumerate([('ATTACK','#ffb66c'),('BLOCK','#64dcf2')]):
  x=margin+i*(cw+gap)
  d.rounded_rectangle((x,y,x+cw,bottom),radius=20,fill='#112236',outline='#294057',width=2)
  art=Image.open(OUT/f'pose-action-{i+1}.png').convert('RGB')
  ah=round(h*.60);art=art.resize((cw-4,ah),Image.Resampling.LANCZOS)
  im.paste(art,(x+2,y+2))
  d.line((x+25,y+ah,x+cw-25,y+ah),fill=col,width=4)
  if mobile:
   title='Tap ATTACK' if i==0 else 'Hold GUARD'
   sub='to attack' if i==0 else 'to block'
  else:
   title='Click M1' if i==0 else 'Hold M2'
   sub='to attack · Left mouse button' if i==0 else 'to block · Right mouse button'
  f=font(round(h*.05));tw=d.textlength(title,font=f)
  d.text((x+(cw-tw)/2,y+ah+round(h*.024)),title,font=f,fill=col)
  f=font(round(h*.028));tw=d.textlength(sub,font=f)
  d.text((x+(cw-tw)/2,y+ah+round(h*.092)),sub,font=f,fill='#e8f0f8')
 f=font(round(h*.02));d.text((margin,round(h*.952)),'COMBAT BASICS',font=f,fill='#8da7be')
 text='LOADING';d.text((w-margin-d.textlength(text,font=f),round(h*.952)),text,font=f,fill='#8da7be')
 name='attack-block-mobile.png' if mobile else 'attack-block-desktop.png'
 im.save(OUT/name)
 print(name,w,h)
