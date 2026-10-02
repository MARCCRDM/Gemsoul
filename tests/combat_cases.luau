local checks=0
local function check(ok,message) checks+=1; assert(ok,message) end
local function close(a,b) return math.abs(a-b)<0.00001 end
local base=Actions.resolve({},"Sword",0)
check(base.BasicCooldown==0.65 and base.HeavyDamage==1.8 and base.HeavyPvPDamage==1.5,"Universal sword/heavy defaults")
check(Actions.resolve({},"Pistol",0).BasicCooldown==0.45,"Pistol default")
local prospector=Actions.resolve({Prospector=2},"Sword",0)
local scout=Actions.resolve({Skirmisher=2},"Pistol",0)
local tank=Actions.resolve({Juggernaut=2},"Sword",0)
check(close(prospector.DodgeCooldown,2.55) and close(prospector.BlockArc,144) and close(prospector.Knockback,13.8),"Prospector enhancements")
check(close(scout.BasicCooldown,0.45/1.15) and scout.HeavyCrit==0.2 and scout.DodgeDistance==18.75 and scout.Deflect,"Scout enhancements")
check(tank.DodgeDistance==12 and tank.Invincible==0.75 and tank.PvPInvincible==0.3 and tank.HeavyDamage==2.25,"Tank enhancements")
local hybrid=Actions.resolve({Prospector=3,Skirmisher=2},"Sword",0.05)
check(close(hybrid.BasicCooldown,0.65/1.15) and hybrid.Deflect and close(hybrid.DodgeCooldown,2.55*0.95),"Hybrid enhancements")
check(Actions.resolve({Juggernaut=1},"Sword",0).DodgeDistance==15,"One piece unlocked enhancement")
check(Actions.blockMultiplier(base,false,1,false,false)==0.5,"PvE block")
check(Actions.blockMultiplier(base,true,1,false,false)==0.6,"PvP block")
check(Actions.blockMultiplier(tank,false,1,false,false)==0.35 and Actions.blockMultiplier(tank,true,1,false,false)==0.5,"Tank block values")
check(Actions.blockMultiplier(scout,true,1,true,false)==0,"Scout deflection")
check(Actions.blockMultiplier(scout,true,1,true,true)==1,"Heavy must break deflection")
check(Actions.blockMultiplier(base,true,-1,false,false)==1,"Back attacks bypass block")
check(Actions.invulnerable(100,100.29,tank,true) and not Actions.invulnerable(100,100.31,tank,true),"PvP immunity boundary")
check(Actions.invulnerable(100,100.74,tank,false) and not Actions.invulnerable(100,100.76,tank,false),"PvE tank immunity boundary")
check(not Actions.finiteVector(Vector3.new(0/0,0,0)) and not Actions.finiteVector(Vector3.new(math.huge,0,0)),"Nonfinite aim accepted")
check(Actions.charge(0.1).Stage=="QUICK" and not Actions.charge(0.1).Heavy,"Quick timing")
check(Actions.charge(0.6).Heavy and not Actions.charge(0.6).Perfect,"Charged timing")
check(Actions.charge(0.75).Perfect,"Perfect timing window")
check(not Actions.charge(0.64).Perfect and not Actions.charge(0.86).Perfect,"Perfect window bounds")
check(Actions.charge(1.15).Scale==0.65 and not Actions.charge(1.15).Heavy,"Overcharge penalty")
check(Actions.combo("Left",1,10,"Right",11)==2,"Alternating combo")
check(Actions.combo("Left",3,10,"Right",11)==3,"Combo cap")
check(Actions.combo("Left",3,10,"Left",11)==1,"Repeated side reset")
check(Actions.combo("Left",3,10,"Right",12)==1,"Expired combo reset")
check(Actions.side("spoofed")=="Right","Invalid side validation")
local a,ha,ra,la=makePlayer(1,arena,nil)
local b,hb,rb,lb=makePlayer(2,arena+Vector3.new(0,0,-5),nil)
local damage=Classes.weapon("Warrior",la.Weapon).Attack.Damage*Combat.powerMult(Classes.ratings(la).Power.Base)*Combat.defenseMult(Classes.ratings(lb).Defense.Base)
check(CombatServer._canPvP(a,b),"Eligible pair refused")
b:SetAttribute("PvPEnabled",false)
check(not CombatServer._canPvP(a,b),"Training visitor attacked")
b:SetAttribute("PvPEnabled",true)
rb.Position=Vector3.zero
check(not CombatServer._canPvP(a,b),"Town target attacked")
rb.Position=arena+Vector3.new(0,0,-5)
a.Team,b.Team,a.Neutral,b.Neutral="Blue","Blue",false,false
check(not CombatServer._canPvP(a,b),"Teammate attacked")
a.Neutral,b.Neutral=true,true
CombatServer.start()
check(registered.SetRigManeuvers(a,{}).Ok==false and Classes.rigManeuver("Warrior","Charge")==nil,"Retired abilities callable")
CombatServer._input(a,"Ability",1,rb.Position)
check(hb.Health==1000,"Retired Ability packet hit")
CombatServer._input(a,"ReleaseAttack",rb.Position)
check(hb.Health==1000,"Uncharged release hit")
local function feedbackCount(kind,recipient)
 local count=0
 for _,message in messages do if message[1]==kind and message.Player==recipient then count+=1 end end
 return count
end
check(feedbackCount("HitConfirm",a)==0 and feedbackCount("IncomingDamage",b)==0,"Rejected attack produced hit feedback")
CombatServer._input(a,"BeginAttack")
now+=0.1
CombatServer._input(a,"ReleaseAttack",rb.Position)
check(close(hb.Health,1000-damage),"Basic damage mismatch")
check(feedbackCount("HitConfirm",a)==1,"Accepted hit did not confirm to attacker")
check(feedbackCount("HitConfirm",b)==0,"Victim received attack confirmation")
check(feedbackCount("IncomingDamage",b)==1,"Victim missing directional feedback")
check(feedbackCount("IncomingDamage",a)==0,"Attacker received victim feedback")
for _,message in messages do
 if message[1]=="IncomingDamage" and message.Player==b then check(message[2]==ra.Position,"Incoming indicator lost authoritative origin") end
end
CombatServer._input(a,"Attack",rb.Position)
check(close(hb.Health,1000-damage),"Attack cooldown bypass")
check(feedbackCount("HitConfirm",a)==1 and feedbackCount("IncomingDamage",b)==1,"Cooldown rejection produced hit feedback")
now+=1
CombatServer._block(b,true,ra.Position)
local before=hb.Health
CombatServer._input(a,"Attack",rb.Position)
check(close(before-hb.Health,damage*0.35),"Live timed high block")
check(not CombatServer._attack(b,ra.Position,false),"Attacked while blocking")
check(CombatServer._state(a).StunUntil>now,"High block failed to stagger attacker")
local raisedAt=CombatServer._state(b).BlockRaisedAt
now+=0.4
CombatServer._block(b,true,ra.Position)
check(CombatServer._state(b).BlockRaisedAt==raisedAt,"Guard refresh restarted high block window")
now+=1
CombatServer._block(b,true,ra.Position)
CombatServer._input(a,"BeginAttack")
now+=0.3
CombatServer._block(b,true,ra.Position)
now+=0.3
before=hb.Health
CombatServer._input(a,"ReleaseAttack",rb.Position)
check(close(before-hb.Health,damage*1.5),"Heavy multiplier/guard break")
check(b:GetAttribute("Blocking")==false and not CombatServer._block(b,true,ra.Position),"Broken guard immediately raised")
now+=2
check(CombatServer._dodge(b,Vector3.new(0,0,-1)),"Dodge rejected")
check(rb.ServerOwned and close(CombatServer._state(b).DodgeMove.Speed,60),"Dodge not controlled by server")
before=hb.Health
CombatServer._input(a,"Attack",rb.Position)
check(hb.Health==before,"Dodge immunity failed")
now+=0.31
CombatServer._tick(0.31)
check(not rb.ServerOwned and not CombatServer._dodge(b,Vector3.new(0,0,-1)),"Dodge cooldown/ownership restoration failed")
now+=1
CombatServer._input(a,"Attack",rb.Position)
check(hb.Health<before,"Immunity failed to expire")
now+=4
wallDistance=3
check(CombatServer._dodge(b,Vector3.new(0,0,-1)),"Wall-limited dodge refused")
check(close(CombatServer._state(b).DodgeMove.Speed,2.8/0.25),"Dodge tunneled through wall")
wallDistance=nil
now+=1
CombatServer._tick(1)
wallBlocks=true
before=hb.Health
CombatServer._input(a,"Attack",rb.Position)
check(hb.Health==before,"Attack went through wall")
wallBlocks=false
now+=1
CombatServer._block(b,true,ra.Position)
now+=0.7
CombatServer._tick(0.7)
check(not b:GetAttribute("Blocking"),"Lost block-release packet locked guard")
la.Weapon="MatrixWeapons1"
now+=1
before=hb.Health
CombatServer._input(a,"Attack",rb.Position+Vector3.new(0,1.5,0))
check(hb.Health<before,"Pistol did not hit player")
local gem={Element="Fire",Tier="Common",Size=4,Clarity=4,Cut=4}
la.WeaponGem=gem
now+=1
CombatServer._input(a,"Attack",rb.Position+Vector3.new(0,1.5,0))
check(CombatServer._state(b).Dots[a]~=nil,"Thermal burn missing")
before=hb.Health
b:SetAttribute("PvPEnabled",false)
now+=1
CombatServer._tick(1)
check(hb.Health==before and CombatServer._state(b).Dots[a]==nil,"Burn persisted after PvP exit")
b:SetAttribute("PvPEnabled",true)
lb.ShieldGem={Element="Frost",Tier="Common",Size=4,Clarity=4,Cut=4}
now+=4
CombatServer._block(b,true,ra.Position)
local shield=CombatServer._state(b).Shield
check(shield>0,"Cryo block shield missing")
CombatServer._block(b,false)
CombatServer._block(b,true,ra.Position)
check(CombatServer._state(b).Shield==shield,"Block toggling farmed shields")
CombatServer._block(b,false)
lb.ShieldGem={Element="Poison",Tier="Common",Size=4,Clarity=4,Cut=4}
CombatServer._state(b).SlowUntil=now+5
now+=4
CombatServer._block(b,true,ra.Position)
check(CombatServer._state(b).SlowUntil==0,"Corrosive cleanse missing")
for _,element in {"Fire","Frost","Poison","Shock"} do
	gem.Element=element
	check(next(GemConfig.actionValues(gem,"Block"))~=nil,"Defensive gem action missing")
end
check(GemConfig.actionValues(gem,"Basic").Arc~=nil,"Ion attack chain missing")
gem.Element="Poison"
check(GemConfig.actionValues(gem,"Heavy").Sunder~=nil,"Corrosive armor shred missing")
-- Crowd-control history survives a cleanse; healing cuts use the real healing entry point.
local victim=CombatServer._state(b)
victim.CC.Count,victim.CC.Last=3,now
victim.NextCleanse=0
CombatServer._block(b,false)
CombatServer._block(b,true,ra.Position)
check(victim.CC.Count==3 and victim.CC.Last==now,"Cleanse reset diminishing returns")
hb.Health=500
CrowdControl.applyHealCut(victim.CC,"GrievousWounds",now)
CrowdControl.applyHealCut(victim.CC,"MortalStrike",now)
check(close(CombatServer.heal(b,100),50),"Anti-heal cap not applied to real healing")
a.Protected=true
check(not CombatServer._canPvP(a,b),"Protected spawn could attack a player")
a.Protected=false
-- Six-piece damage-after-dodge uses the universal Dodge action without an ability pick.
local c,hc,rc,lc=makePlayer(3,arena,"Skirmisher")
CombatServer.reset(b)
lb.ShieldGem=nil
now+=10
local expected=Classes.weapon("Warrior",lc.Weapon).Attack.Damage*Combat.powerMult(Classes.ratings(lc).Power.Base)*Combat.defenseMult(Classes.ratings(lb).Defense.Base)
check(CombatServer._dodge(c,Vector3.new(1,0,0)),"Universal full-set dodge refused")
check(not CombatServer._attack(c,rb.Position,false),"Attacked during dodge motion")
now+=0.3
CombatServer._tick(0.3)
before=hb.Health
CombatServer._attack(c,rb.Position+Vector3.new(0,1.5,0),false)
check(close(before-hb.Health,expected*1.1),"Six-piece after-dodge capstone missing")
-- PvE heavy remains 180%, with no PvP multiplier leaking into dummy hits.
local enemy={Alive=true,Root={Position=arena+Vector3.new(0,0,-4),AssemblyMass=1,ApplyImpulse=function() end},Humanoid={Health=1000,MaxHealth=1000},Kind={Dummy=true}}
table.insert(enemyList,enemy)
la.Weapon,la.WeaponGem="MatrixSwords1",nil
now+=2
CombatServer._attack(a,enemy.Root.Position,true)
local pveDamage=Classes.weapon("Warrior",la.Weapon).Attack.Damage*Combat.powerMult(Classes.ratings(la).Power.Base)*1.8
check(close(1000-enemy.Humanoid.Health,pveDamage),"PvE heavy multiplier changed")
enemyList={}
c:SetAttribute("PvPEnabled",false)
CombatServer.reset(a)
CombatServer.reset(b)
la.WeaponGem=nil
for _,slot in {"Helmet", "Chest", "Gloves", "Boots", "Shield"} do lb[slot.."Gem"]=nil end
hb.Health=1000
now+=20
local function releaseSide(side,seconds)
 CombatServer._input(a,"BeginAttack",side)
 now+=seconds
 CombatServer._input(a,"ReleaseAttack",rb.Position)
end
before=hb.Health
releaseSide("Left",0.75)
check(close(before-hb.Health,damage*1.5*Combat.CritMult),"Server perfect release damage")
now+=1.3
before=hb.Health
releaseSide("Right",0.1)
check(close(before-hb.Health,damage*1.1),"Server alternating combo damage")
now+=1
before=hb.Health
releaseSide("Right",1.2)
check(close(before-hb.Health,damage*0.65),"Server overcharge damage")
now+=1
CombatServer._input(a,"BeginAttack","Left")
CombatServer._input(a,"CancelAttack")
before=hb.Health
CombatServer._input(a,"ReleaseAttack",rb.Position)
check(hb.Health==before,"Cancelled charge released")
CombatServer.reset(a)
now+=1
before=hb.Health
releaseSide("Left",0.1)
now+=0.8
rb.Position=arena+Vector3.new(0,0,-80)
releaseSide("Right",0.1)
check(CombatServer._state(a).ComboCount==0,"Miss retained combo")
rb.Position=arena+Vector3.new(0,0,-5)
now+=0.8
CombatServer._block(b,true,ra.Position)
releaseSide("Left",0.1)
check(CombatServer._state(a).ComboCount==0,"Guard retained combo")
ArenaSessions.start()
a:SetAttribute("Expedition",true)
check(not registered.ArenaPvP(a).Ok,"Mining expedition joined Arena")
a:SetAttribute("Expedition",nil)
check(registered.ArenaTraining(a).Ok and not a:GetAttribute("PvPEnabled") and a:GetAttribute("CombatSession")=="Training","Training entry flags")
check(not registered.ArenaPvP(a).Ok,"Switched sessions without leaving")
check(registered.ArenaLeave(a).Ok and a:GetAttribute("CombatSession")==nil,"Arena leave failed")
check(registered.ArenaPvP(a).Ok and a:GetAttribute("PvPEnabled") and a:GetAttribute("CombatSession")=="PvP","PvP entry flags")
Players.PlayerAdded.Fire(c)
Players.PlayerAdded.Fire(b)
b.CharacterAdded.Fire()
check(b:GetAttribute("CombatSession")==nil and not b:GetAttribute("PvPEnabled"),"Respawn retained PvP participation")
Players.PlayerRemoving.Fire(a)
check(CombatServer._state(b).Dots[a]==nil,"Disconnected attacker kept burning victim")
print("PASS: "..checks.." universal-action and live combat checks (PvP gates, charge, block, dodge, LOS, gems and cleanup)")

assert(not Actions.validInput("Unknown", nil, nil))
assert(not Actions.validInput("RigManeuver", {}, Vector3.new(0,0,0)))
assert(not Actions.validInput("Attack", Vector3.new(0/0,0,0)))
assert(not Actions.validInput("Block", true, "bad"))
assert(Actions.validInput("Block", false))
assert(Actions.validInput("CancelAttack"))
assert(Actions.validInput("Surge", "Q", Vector3.new(0,0,1)))
print("PASS: 7 combat payload validation checks")
