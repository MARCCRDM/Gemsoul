"""Render Sahur's real joint hierarchy at representative combat timestamps."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
script=(root/'tools/render_boss_previews.py').read_text(encoding='utf-8')
script=script.replace("source+='local Rules=", "source+='local RivalPose=(function()\\n'+(root/'src/shared/RivalPose.luau').read_text(encoding='utf-8')+'\\nend)()\\n'\nsource+='local Rules=")
needle="source+='''\nlocal colors="
inject="""
source=source.replace('p.CFrame = bone.CFrame * CFrame.new(pos) * (rotation or CFrame.identity)', 'p.PoseBone=bone.Name; p.LocalFrame=CFrame.new(pos)*(rotation or CFrame.identity); p.CFrame=bone.CFrame*p.LocalFrame')
source+=duel[duel.index('local JOINTS ='):duel.index('local function buildBody')]
source+='''
Rules.Roster={
 {Id="Sahur",Shape="Wood",Name="01 / Combat ready",Element="Fire",Weakness="Frost",Time=102},
 {Id="Sahur",Shape="Wood",Name="02 / Heavy wind-up",Element="Fire",Weakness="Frost",Time=100.6},
 {Id="Sahur",Shape="Wood",Name="03 / Heavy impact",Element="Fire",Weakness="Frost",Time=100.82},
 {Id="Sahur",Shape="Wood",Name="04 / Bat guard",Element="Fire",Weakness="Frost",Time=103},
}
'''
"""
script=script.replace(needle,inject+needle)
script=script.replace('Skins.apply(rig,spec,colors[spec.Element],true)', '''Skins.apply(rig,spec,colors[spec.Element],false)
 local attrs={CombatPoseProfile="SahurBat",ActionKind="Heavy",ActionStart=100,ActionAt=100.75}
 if spec.Time==103 then attrs={CombatPoseProfile="SahurBat",GuardUntil=104} end
 local pose=RivalPose.pose(attrs,spec.Time)
 local centers={HumanoidRootPart=Vector3.zero}
 local frames={HumanoidRootPart=CFrame.identity}
 for _,b in BODY do centers[b[1]]=b[3] end
 for _,j in JOINTS do
  local parent,child,at=centers[j[2]],centers[j[3]],j[4]
  local a=pose[j[1]] or {0,0,0}
  frames[j[3]]=frames[j[2]]*CFrame.new(at.X-parent.X,at.Y-parent.Y,at.Z-parent.Z)*CFrame.Angles(a[1],a[2],a[3])*CFrame.new(child.X-at.X,child.Y-at.Y,child.Z-at.Z)
 end
 for _,p in builtParts do
  if p.PoseBone then p.CFrame=frames[p.PoseBone]*p.LocalFrame end
 end''')
script=script.replace("'docs/boss-previews'", "'docs/sahur-animation'")
script=script.replace("'BRAINROT DUNGEON / FOUR COLOSSUS BOSSES'", "'TUNG TUNG / COMBAT ANIMATION POSES'")
script=script.replace('Current code geometry · neutral pose · simplified lighting · not Roblox Studio screenshots','Actual joint hierarchy + RivalPose frames · geometry renders, not Studio screenshots')
script=script.replace("labels[element]+'  /  WEAK TO '+labels[weak]", "'SHARED COMBAT TIMELINE / BAT FIST GRIP'")
script=script.replace('BOSS SCALE 1.8×  /  EXISTING R15 COMBAT RIG','R15 JOINTS / EXISTING COMBAT POSES')
script=script.replace("out.mkdir(exist_ok=True)","out.mkdir(exist_ok=True)")
script=script.replace("a=1.0 if element in ('Frost','Shock') else .3", "a=.65")
script=script.replace("root/'.tools/boss-preview.luau'", "root/'.tools/sahur-pose-preview.luau'")
exec(compile(script,str(root/'tools/render_boss_previews.py'),'exec'),{'__file__':str(root/'tools/render_boss_previews.py')})

