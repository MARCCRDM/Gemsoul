"""Render actual miner armor builders for art review (not Roblox screenshots)."""
from pathlib import Path
import math
import re
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
# Reuse the existing equipment renderer's Roblox math/Instance harness.
context = {'__file__': str(ROOT / '.tools/render_equipment_details.py')}
base = (ROOT / '.tools/render_equipment_details.py').read_text(encoding='utf-8').split('for name, path in')[0]
exec(base, context)
source = context['source'].replace('return setmetatable({t={x or 0,y or 0,z or 0}',
    'if type(x)=="table" then x,y,z=x.X,x.Y,x.Z end\n return setmetatable({t={x or 0,y or 0,z or 0}')
source += '\nvmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end\nlocal GemConfig={Affixes={}}\n'
for name, path in [('ArmorFamilies','src/shared/ArmorFamilies.luau'),('ArmorKits','src/server/Systems/ArmorKits.luau'),('Assets','src/server/Systems/FrontierAssets.luau')]:
    text = (ROOT / path).read_text(encoding='utf-8')
    text = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', text, flags=re.M)
    source += f'local {name}=(function()\n{text}\nend)()\n'
duel = (ROOT / 'src/server/Systems/Duelist.luau').read_text(encoding='utf-8')
source += duel[duel.index('local BODY ='):duel.index('local JOINTS =')]
source += r'''
local rig, parts = {}, {}
for _,b in BODY do
 local p={Name=b[1],Size=b[2],CFrame=CFrame.new(b[3])}
 p.FindFirstChild=function() return nil end
 p.FindFirstChildOfClass=function() return nil end
 p.GetChildren=function() return {} end
 p.IsA=function(_,k) return k=="BasePart" end
 parts[b[1]]=p
end
rig.FindFirstChild=function(_,name) return parts[name] end
rig.GetChildren=function() local t={} for _,p in parts do table.insert(t,p) end return t end
for _,family in ArmorFamilies.Order do
 for _,rarity in {1,5} do
  for _,slot in {"Full","Boots","Shield"} do
   table.clear(builtParts)
   local palette=ArmorKits.Looks[ArmorFamilies.Families[family].Look]
   local traits={Rarity=rarity,Helmet=1,FinishColor=palette.Metal,VisorColor=Color3.fromRGB(97,215,231)}
   if slot=="Shield" then
    Assets.shield({},parts.UpperTorso,CFrame.identity,rarity,Color3.fromRGB(97,215,231),palette.Metal,family)
   else
    for _,piece in if slot=="Full" then {"Helmet","Armor","Gloves","Boots"} else {"Boots"} do
     ArmorKits.build({},rig,ArmorFamilies.Families[family].Look,Color3.fromRGB(97,215,231),1,traits,piece,"Armor"..family..piece..rarity)
    end
   end
   print("MODEL|"..family.."|"..rarity.."|"..slot)
   for _,p in builtParts do
    local row={p.ClassName,p.Shape or "Block",p.Material,tostring(p.Size.X),tostring(p.Size.Y),tostring(p.Size.Z),tostring(p.Color.R),tostring(p.Color.G),tostring(p.Color.B)}
    for _,v in p.CFrame.t do table.insert(row,tostring(v)) end
    for _,v in p.CFrame.r do table.insert(row,tostring(v)) end
    print(table.concat(row,"|"))
   end
  end
 end
end
'''
script = ROOT / '.tools/armor-families-preview.luau'
try:
    script.write_text(source, encoding='utf-8')
    output = subprocess.check_output([str(ROOT / '.tools/luau/luau.exe'), str(script)], text=True)
finally:
    script.unlink(missing_ok=True)
models = {}
for line in output.splitlines():
    values = line.split('|')
    if values[0] == 'MODEL':
        key = tuple(values[1:]); models[key] = []
    elif len(values) == 21:
        models[key].append((values[:3], np.array(list(map(float, values[3:])))))

def draw_model(draw, parts, bounds, angle=0.38, tilt=0.08):
    left,top,width,height=bounds
    view=np.array([[math.cos(angle),0,math.sin(angle)],[math.sin(angle)*math.sin(tilt),math.cos(tilt),-math.cos(angle)*math.sin(tilt)],[-math.sin(angle)*math.cos(tilt),math.sin(tilt),math.cos(angle)*math.cos(tilt)]])
    faces=[];extents=[]
    for (kind,shape,material),v in parts:
        size,color,pos,rotation=v[:3],v[3:6],v[6:9],v[9:].reshape(3,3)
        verts=np.array([[x,y,z] for x in (-.5,.5) for y in (-.5,.5) for z in (-.5,.5)])*size
        indices=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
        if kind=='WedgePart':
            verts[verts[:,2]<0,1]=-size[1]/2
        if shape=='Cylinder':
            n=16
            verts=np.array([[side*size[0]/2,math.cos(a)*size[1]/2,math.sin(a)*size[2]/2] for side in (-1,1) for a in np.linspace(0,2*math.pi,n,endpoint=False)])
            indices=[list(range(n)),list(range(n,2*n))]+[[i,(i+1)%n,(i+1)%n+n,i+n] for i in range(n)]
        verts=(verts@rotation.T+pos)@view.T;extents.extend(verts[:,:2])
        for face in indices:
            points=verts[face];normal=np.cross(points[1]-points[0],points[2]-points[0]);length=np.linalg.norm(normal)
            if length<1e-8:continue
            if np.dot(normal,points.mean(0)-verts.mean(0))<0:normal=-normal
            if normal[2]>=0:continue
            shade=1 if material=='Neon' else .62+.38*max(0,np.dot(normal/length,[-.35,.5,-.75]))
            faces.append((points[:,2].mean(),points,tuple(int(np.clip(c*shade*255,0,255)) for c in color)))
    extent=np.array(extents);low=extent.min(0);high=extent.max(0);center=(low+high)/2
    scale=min(width/(high[0]-low[0]),height/(high[1]-low[1]))
    for _,points,fill in sorted(faces,key=lambda f:f[0],reverse=True):
        draw.polygon([(left+width/2+(p[0]-center[0])*scale,top+height/2-(p[1]-center[1])*scale) for p in points],fill=fill)

im=Image.new('RGB',(1800,1660),'#0b1420');draw=ImageDraw.Draw(im)
bold=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',n)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
draw.text((35,20),'SAGA MINERS  /  ARMOR FAMILIES',font=bold(30),fill='#edf5ff')
draw.text((35,65),'Actual game geometry · Common and Legendary · Offline materials preview; verify motion in Studio.',font=font(20),fill='#9cb2c9')
for col,family in enumerate(['Prospector','Skirmisher','Juggernaut']):
    x=25+col*590
    draw.rounded_rectangle((x,115,x+575,1635),radius=16,fill='#142332',outline='#31475e',width=2)
    draw.text((x+22,132),family.upper(),font=bold(26),fill=['#e6b267','#8ce4d7','#c2d4ec'][col])
    for rarity,offset,label in [('1',0,'COMMON'),('5',285,'LEGENDARY')]:
        draw.text((x+26+offset,182),label,font=bold(15),fill='#9eb4c9')
        draw_model(draw,models[(family,rarity,'Full')],(x+15+offset,218,265,630))
    draw.text((x+24,885),'BOOT / GREAVE DETAIL',font=bold(19),fill='#e8f1ff')
    for rarity,offset in [('1',0),('5',285)]:
        draw_model(draw,models[(family,rarity,'Boots')],(x+24+offset,936,245,325),tilt=.3)
        draw_model(draw,models[(family,rarity,'Shield')],(x+50+offset,1325,200,230),tilt=.12)
    draw.text((x+24,1590),'Common                               Legendary',font=font(18),fill='#9eb4c9')
target=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT.parents[1]/'Saga-Miners-Armor-Preview.png'
im.save(target)
print(target)
for family in ['Prospector','Skirmisher','Juggernaut']:
    print(family, 'full armor parts common / legendary:',len(models[(family,'1','Full')]),len(models[(family,'5','Full')]))
