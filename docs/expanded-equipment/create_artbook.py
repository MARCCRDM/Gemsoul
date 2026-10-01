from pathlib import Path
import json
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.utils import ImageReader
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph,Table,TableStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from PIL import Image
from xml.sax.saxutils import escape
from zipfile import ZipFile,ZIP_DEFLATED
root=Path('C:/Users/clapr/OneDrive/Documents/GitHub/Gemsoul/docs/expanded-equipment')
out=Path('C:/Users/clapr/OneDrive/Documents/GemSoul Concept Art');out.mkdir(exist_ok=True)
pdfmetrics.registerFont(TTFont('Segoe','C:/Windows/Fonts/segoeui.ttf'));pdfmetrics.registerFont(TTFont('SegoeBold','C:/Windows/Fonts/segoeuib.ttf'))
pdf=out/'GemSoul Expanded Equipment Artbook.pdf';c=canvas.Canvas(str(pdf),pagesize=(792,612));c.setTitle('GemSoul Expanded Equipment Artbook');c.setAuthor('GemSoul')
style=ParagraphStyle('Body',fontName='Segoe',fontSize=11,leading=16,textColor=colors.HexColor('#d5e1ed'))
cell=ParagraphStyle('Cell',parent=style,fontSize=10,leading=14)
page=0
def begin(title,subtitle=''):
 global page
 page+=1;c.setFillColor(colors.HexColor('#0c1421'));c.rect(0,0,792,612,fill=1,stroke=0)
 c.setFillColor(colors.HexColor('#71d6de'));c.setFont('SegoeBold',9);c.drawString(36,585,'GEMSOUL  /  EXPANDED EQUIPMENT ARCHIVE')
 c.setFont('SegoeBold',23);c.setFillColor(colors.white);c.drawString(36,550,title)
 if subtitle:c.setFont('Segoe',10);c.setFillColor(colors.HexColor('#a7b9cb'));c.drawString(36,530,subtitle)
 c.setFont('Segoe',8);c.setFillColor(colors.HexColor('#a7b9cb'));c.drawString(36,20,'Concept direction  /  September 30 2026');c.drawRightString(756,20,str(page))
def para(text,y,width=720):
 p=Paragraph(escape(text),style);w,h=p.wrap(width,500);p.drawOn(c,36,y-h);return y-h-14
begin('GemSoul Expanded Equipment Artbook','Original science fantasy armor and randomized starting equipment')
y=495
for text in [
'This artbook interprets the supplied Expanded Item Traits and Buffs Matrix as a coherent cast of human space warrior miners. Seven concept sheets cover 60 equipment designs and ten visor treatments.',
'The artwork uses sculpted human proportions, believable hard surface engineering and crafted fantasy detail. Utility gear is worn and practical. Higher rarity designs carry more distinctive materials, silhouettes and reactor structures.',
'The new-player equipment pool is implemented in the repository. Each slot rolls independently, then saves the result. Existing accounts retain their equipment. Mining recovery, trade and gem attunement remain the progression loop.',
'These are concept images, not exported game meshes. New matrix identities currently map to existing Roblox procedural models. Sculpted 3D replacements still need modeling, rigging and asset import.',
'The matrix tables preserve the proposed effects from your PDF. Seven equipment signatures are supported or adapted by current mechanics; other signatures are explicitly planned. Visor effects are not active: visor appearance is cosmetic in this version.']:
 y=para(text,y)
c.showPage()
boards=[('01-armor-families.png','Armor families','Ten full body character designs'),('02-helmet-designs.png','Helmet designs','Ten independent headgear identities'),('03-pistol-designs.png','Pistol designs','Ten kinetic and energy sidearms'),('04-shield-designs.png','Shield designs','Ten defensive equipment identities'),('05-glove-designs.png','Glove designs','Ten gauntlet and bracer concepts'),('06-boot-designs.png','Boot designs','Ten armored traversal concepts'),('07-visor-treatments.png','Visor treatments','Ten material and color directions on a consistent helmet')]
for filename,title,subtitle in boards:
 begin(title,subtitle)
 im=Image.open(root/filename);w,h=im.size;scale=min(720/w,476/h);dw,dh=w*scale,h*scale
 c.drawImage(str(root/filename),36+(720-dw)/2,42+(476-dh)/2,width=dw,height=dh)
 c.showPage()
data=json.loads((root/'matrix.json').read_text())
active={'Intableed Visored Helm','Metron Meshed Helm','Jutaim Heavy Vanguard','Cryo-Pistol Sub-Zero','Radiation Corrupter','Standard Sidearm','Pulse-Laser Repeater'}
for category in ['Suit Type','Helmet Style','Left Hand Pistol','Right Hand Shield','Gloves','Boots','Visor Color']:
 begin(category+' traits','Source proposals preserved below  /  Rare starting weight adjusted from 15 to 20 percent')
 rows=[[Paragraph(x,cell) for x in ['Item','Rarity','Proposed signature and runtime status']]]
 for e in data:
  if e["category"] != category: continue
  status='Supported' if e['name'] in active else 'Planned'
  if e['name']=='Radiation Corrupter':status='Adapted as damage vulnerability, not literal armor reduction'
  if category=='Visor Color':status='Cosmetic only; proposed buff is planned'
  rows.append([Paragraph(escape(e['name']),cell),Paragraph(e['rarity'],cell),Paragraph(escape(e['description'])+'<br/><font color="#71d6de">'+status+'</font>',cell)])
 table=Table(rows,colWidths=[194,81,445]);table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('BACKGROUND',(0,0),(-1,0),colors.HexColor('#253a50')),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.HexColor('#122032'),colors.HexColor('#17273a')]),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),('LEFTPADDING',(0,0),(-1,-1),9)]))
 w,h=table.wrap(720,480)
 if h>475:raise ValueError(f'Table too tall {category}: {h}')
 table.drawOn(c,36,510-h);c.showPage()
begin('Starting loadout and balance direction','Implemented rules and recommendations for the next pass')
y=497
for text in [
'Implemented draws: 40% Common, 25% Uncommon, 20% Rare, 10% Ultra Rare, 5% Legendary. After rarity is selected, either of its two items is equally likely. All six slots receive a usable Standard-quality item with stored rarity-specific bonus stats and cosmetic traits. All ten visor treatments are reachable.',
'Implementation: critical chance, cooldown reduction, damage reduction, pistol slowing and vulnerability use available mechanics. Standard Sidearm and Pulse-Laser Repeater use executable attack profiles. Other proposed effects are visibly marked as planned. Radiation vulnerability stacks +15% per hit up to +45% for five seconds.',
'Recommended identity: allow mixed families without a mandatory set bonus. Keep visor color cosmetic and elemental affinity on gems. Reveal each starting item with a brief skippable sequence that explains its real active bonus, rarity and socket.',
'Recommended balance: budget total starting power before PvP. Suggested gear caps are +10% critical chance, 20% cooldown reduction and 20% combined damage reduction. These caps are not implemented. Replace broad hazard immunity with resistance and put cooldowns on reflection, decoys and first-hit negation.',
'Recommended economy: simulate mining yield bonuses before enabling them. Keep account starts persistent and avoid paid rarity rerolls. Cosmetics, armor paints and presentation upgrades fit monetization without undermining the trading loop.',
'Validation: 60,000 weighted equipment draws and 10,000 visor draws verify complete pool coverage. Equipment and expedition regressions, lint and project build checks pass. A live Studio playtest and sculpted mesh integration remain outstanding.']:
 y=para(text,y)
if y<40:raise ValueError('Rules page overflow')
c.showPage();c.save()
with ZipFile(out/'GemSoul Concept Art Pack.zip','w',ZIP_DEFLATED) as z:
 for p in root.glob('*.png'):z.write(p,p.name)
 for name in ['README.md','Art direction prompts.md','matrix.json','source-matrix.txt']:z.write(root/name,name)
 z.write(pdf,pdf.name)
print(f'Created {page}-page artbook and full concept art ZIP')
