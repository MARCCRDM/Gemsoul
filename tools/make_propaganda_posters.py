"""Brainrot Crusaders propaganda posters (assets/images/propaganda). Run from that folder: python3 ../../../tools/make_propaganda_posters.py; then render each SVG to PNG (800x1200)."""
import math
W,H=800,1200
def rays(cx,cy,n,c1,c2,r=1600):
    s=[]
    for i in range(n):
        a0=2*math.pi*i/n; a1=2*math.pi*(i+0.5)/n
        s.append(f'<path d="M{cx},{cy} L{cx+r*math.cos(a0):.0f},{cy+r*math.sin(a0):.0f} L{cx+r*math.cos(a1):.0f},{cy+r*math.sin(a1):.0f}Z" fill="{c2}"/>')
    return f'<rect width="{W}" height="{H}" fill="{c1}"/>'+''.join(s)
F='font-family="Impact, Anton, \'Arial Black\', \'DejaVu Sans\', sans-serif" font-weight="900"'
def frame(c): return f'<rect x="18" y="18" width="{W-36}" height="{H-36}" fill="none" stroke="{c}" stroke-width="10"/><rect x="34" y="34" width="{W-68}" height="{H-68}" fill="none" stroke="{c}" stroke-width="3"/>'
def grain(): return '<filter id="g"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.18 0"/></filter><rect width="800" height="1200" filter="url(#g)"/>'
def crusader(x,y,s,body,trim,visor,point=False):
    # stylised armored crusader: helmet with visor, pauldrons, shield, sword
    arm = (f'<path d="M{x+60},{y+170} L{x+230},{y+60} L{x+255},{y+85} L{x+90},{y+215}Z" fill="{body}"/>'
           f'<path d="M{x+228},{y+50} l40,-14 l10,30 l-38,18Z" fill="{trim}"/>') if point else \
          (f'<rect x="{x+150}" y="{y-120}" width="16" height="300" fill="{trim}" transform="rotate(14 {x+158} {y+40})"/>'
           f'<rect x="{x+128}" y="{y+150}" width="62" height="14" fill="{body}" transform="rotate(14 {x+158} {y+40})"/>')
    return (f'<g transform="scale({s})" >'
      f'<path d="M{x-150},{y+520} L{x-130},{y+170} Q{x},{y+110} {x+130},{y+170} L{x+150},{y+520}Z" fill="{body}"/>'
      f'<path d="M{x-175},{y+230} Q{x-170},{y+150} {x-90},{y+150} L{x-80},{y+260}Z" fill="{trim}"/>'
      f'<path d="M{x+175},{y+230} Q{x+170},{y+150} {x+90},{y+150} L{x+80},{y+260}Z" fill="{trim}"/>'
      f'<path d="M{x-20},{y+180} L{x+20},{y+180} L{x+10},{y+330} L{x-10},{y+330}Z" fill="{trim}"/>'
      f'<path d="M{x-85},{y+120} Q{x-90},{y-20} {x},{y-30} Q{x+90},{y-20} {x+85},{y+120} L{x+55},{y+165} L{x-55},{y+165}Z" fill="{body}"/>'
      f'<path d="M{x-6},{y-60} L{x+6},{y-60} L{x+4},{y-20} L{x-4},{y-20}Z" fill="{trim}"/>'
      f'<path d="M{x-70},{y+40} L{x+70},{y+40} L{x+60},{y+70} L{x-60},{y+70}Z" fill="{visor}"/>'
      f'<path d="M{x-215},{y+230} L{x-95},{y+230} L{x-95},{y+380} Q{x-155},{y+450} {x-215},{y+380}Z" fill="{trim}" stroke="{body}" stroke-width="10"/>'
      f'<path d="M{x-155},{y+255} l0,150 M{x-200},{y+310} l90,0" stroke="{body}" stroke-width="14"/>'
      + arm + '</g>')
def text(t,y,size,fill,stroke=None,ls=4,anchor="middle",x=400):
    st=f' stroke="{stroke}" stroke-width="6" paint-order="stroke"' if stroke else ''
    est=len(t)*size*0.68+ls*len(t)
    fit=f' textLength="{min(690,est):.0f}" lengthAdjust="spacingAndGlyphs"' if est>690 else ''
    return f'<text x="{x}" y="{y}" {F} font-size="{size}" fill="{fill}" text-anchor="{anchor}" letter-spacing="{ls}"{st}{fit}>{t}</text>'
def banner(y,h,c,t,tc,size):
    return f'<rect x="0" y="{y}" width="{W}" height="{h}" fill="{c}"/>'+text(t,y+h/2+size*0.36,size,tc,ls=6)
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>'
INK="#14110f"; CREAM="#f3e6c8"; RED="#c8282d"; GOLD="#f2b33d"; TEAL="#3acbe9"; NAVY="#16213a"
posters={}
# 1 THE OUTPOST NEEDS YOU
posters["outpost_needs_you"]=svg(rays(400,520,28,"#e9b13a","#f6cf6a")+
  crusader(400,330,1,INK,RED,TEAL,point=True)+
  banner(70,150,RED,"THE OUTPOST",CREAM,96)+text("NEEDS",300,120,INK,CREAM,10)+
  banner(880,170,INK,"YOU!",GOLD,150)+
  text("ENLIST TODAY  ·  DEFEND THE MOTHERSHIP",1100,30,INK,None,3)+
  text("BRAINROT CRUSADERS",1145,26,RED,None,8)+frame(INK)+grain())
# 2 MINE FOR THE MOTHERSHIP
gem='<g transform="translate(400 560)"><path d="M-150,-40 L-90,-130 L90,-130 L150,-40 L0,170Z" fill="#7a3df0"/><path d="M-150,-40 L150,-40 L0,170Z" fill="#5a22c8"/><path d="M-90,-130 L-40,-40 L40,-40 L90,-130Z" fill="#b48cff"/><path d="M-40,-40 L0,170 L40,-40Z" fill="#9b6bff"/><path d="M-60,-110 L-20,-110 L-50,-60Z" fill="#fff" opacity=".8"/></g>'
pick='<g transform="translate(400 560) rotate(-35)"><rect x="-12" y="-330" width="24" height="330" fill="'+INK+'"/><path d="M-150,-330 Q0,-410 150,-330 L140,-305 Q0,-370 -140,-305Z" fill="'+CREAM+'" stroke="'+INK+'" stroke-width="8"/></g>'
posters["mine_for_the_mothership"]=svg(rays(400,560,32,NAVY,"#1f2e52")+
  '<circle cx="400" cy="560" r="230" fill="none" stroke="'+GOLD+'" stroke-width="10"/>'+pick+gem+
  text("MINE",170,150,GOLD,INK,12)+text("FOR THE MOTHERSHIP",260,62,CREAM,INK,5)+
  banner(860,120,GOLD,"EVERY GEM COUNTS",INK,72)+
  text("SWING HARD. DIG DEEP. CUT CLEAN.",1050,32,CREAM,None,3)+
  text("BRAINROT CRUSADERS",1130,26,GOLD,None,8)+frame(GOLD)+grain())
# 3 HOLD THE LINE
wall=''.join(crusader(170+i*230,560,1,INK if i!=1 else "#2a1d1a",RED,"#ff5a3c") for i in range(3))
posters["hold_the_line"]=svg(rays(400,1250,30,RED,"#a51d22")+
  '<g transform="translate(-35 -40) scale(1.08)">'+wall+'</g>'+
  banner(60,170,INK,"HOLD THE",CREAM,120)+text("LINE",380,170,CREAM,INK,14)+
  banner(900,110,CREAM,"FIRST TO TWO. NO RETREAT.",RED,52)+
  text("RANKED DUELS  ·  GLORY AWAITS THE WORTHY",1075,30,CREAM,None,3)+
  text("BRAINROT CRUSADERS",1135,26,GOLD,None,8)+frame(CREAM)+grain())
import sys
for k,v in posters.items(): open(f"{k}.svg","w").write(v)
print("ok")
