from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
s=(root/'.tools/render_equipment_details.py').read_text()
s=s.replace("for name, path in [('ArmorKits'", "for name, path in [('ArmorFamilies','src/shared/ArmorFamilies.luau'),('ArmorKits'")
s=s.replace("(root/path).read_text()", "re.sub(r'^local \\w+ = require\\([^\\n]+\\)\\n', '', (root/path).read_text(), flags=re.M)")
s=s.replace('import subprocess, math','import subprocess, math, re')
a=s.index('local traits={Rarity=5'); b=s.index("'''",a)
s=s[:a]+'''for _,family in ArmorFamilies.Order do
 for _,slot in ArmorFamilies.Slots do
  for rarity=1,5 do
   local item=ArmorFamilies.ById["Armor"..family..slot..rarity]
   local traits={Rarity=rarity,Helmet=1,VisorColor=Color3.fromRGB(72,207,226),FinishColor=Color3.fromRGB(90,100,120)}
   if slot=="Shield" then
    Assets.shield({},anchor,CFrame.identity,rarity,Color3.fromRGB(72,207,226),traits.FinishColor,family)
   else
    local target=if slot=="Helmet" then "Head" elseif slot=="Armor" then "Torso" elseif slot=="Gloves" then "RightLowerArm" else "RightFoot"
    local rig={GetChildren=function() return {} end,FindFirstChild=function(_,name) if name==target or name=="UpperTorso" then return anchor end return nil end}
    ArmorKits.build({},rig,item.Look,Color3.fromRGB(72,207,226),1,traits,slot,item.Id)
   end
   dump(family.." / "..slot.." / "..rarity)
  end
 end
end
'''+s[b:]
s=s.replace("bundle=root/'.tools/details-preview.luau'", "bundle=root/'.tools/armor-review-preview.luau'")
s=s.replace('W,H=1800,1220','W,H=1800,5700')
s=s.replace('GEMSOUL  /  ENHANCED LOADOUT DETAILS','SAGA MINERS / ALL 75 ARMOR ASSETS')
s=s.replace('Legendary examples rendered from the current Luau builders','Common → Uncommon → Rare → Ultra Rare → Legendary · Current Luau builders')
s=s.replace('left=30+(index%3)*590; top=126+(index//3)*535','left=20+(index%5)*355; top=126+(index//5)*370')
s=s.replace('left+570,top+515','left+340,top+355')
s=s.replace('430/(high[0]-low[0]),365/(high[1]-low[1])','260/(high[0]-low[0]),260/(high[1]-low[1])')
s=s.replace('left+285','left+170').replace('top+213','top+157')
s=s.replace("draw.text((left+22,top+433),labels[name][0],font=bold(25),fill='#edc77f')", "draw.text((left+14,top+294),name.rsplit(' / ',1)[0],font=bold(17),fill='#edc77f')")
s=s.replace("draw.text((left+22,top+477),labels[name][1],font=font(16),fill='#b5c6d7')", "draw.text((left+14,top+325),['Common','Uncommon','Rare','Ultra Rare','Legendary'][int(name[-1])-1],font=font(16),fill='#b5c6d7')")
out=root/'docs/armor-review'; out.mkdir(parents=True,exist_ok=True)
s=s.replace("Path('C:/Users/clapr/OneDrive/Documents/temp/Gemsoul-enhanced-details.png')", repr(str(out/'all-75-armor.png')))
s=s.replace('im.save(out)','im.save(out)')
s=s.replace('out=\''+str(out/'all-75-armor.png')+'\'', 'out=Path('+repr(str(out/'all-75-armor.png'))+')')
exec(compile(s,'armor_renderer','exec'))
out=root/'docs/armor-review'
from PIL import Image
im=Image.open(out/'all-75-armor.png')
rarities=['Common','Uncommon','Rare','Ultra Rare','Legendary']
body=['<!doctype html><meta charset="utf-8"><title>Saga Miners Armor Review</title><style>body{background:#0b1420;color:#eaf0f8;font:16px Arial;margin:32px}h2{color:#edc77f}.grid{display:grid;grid-template-columns:repeat(5,1fr);gap:12px}article{background:#142131;padding:12px;border:1px solid #2b4559;border-radius:12px}img{width:100%}small{color:#b5c6d7}@media print{body{background:white;color:black}h2{break-before:page}.grid{gap:5px}article{background:white;color:black}}</style><h1>Saga Miners · Armor Asset Review</h1><p>All 75 new armor assets. Geometry renders from the game builders; final lighting must be reviewed in Roblox Studio.</p><p>Each family has five slots × five rarities. Matching weapons count as piece six. Existing legacy gear stays compatible and is excluded from the new drop pool.</p>']
for row in range(15):
 family=['Prospector','Skirmisher','Juggernaut'][row//5]; slot=['Helmet','Chest','Gloves','Boots','Shield'][row%5]
 body.append(f'<h2>{family} · {slot}</h2><div class="grid">')
 for col in range(5):
  left=20+col*355; top=126+row*370; filename=f'{family}-{slot}-{col+1}.png'
  im.crop((left,top,left+340,top+355)).save(out/filename)
  body.append(f'<article><img src="{filename}"><b>{rarities[col]}</b><p>{[10,15,22,30,40][col]} stat points · {[0,0,1,2,3][col]} modifiers</p></article>')
 body.append('</div>')
(out/'index.html').write_text('\n'.join(body),encoding='utf-8')
print(out/'index.html')
