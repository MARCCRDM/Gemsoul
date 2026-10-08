local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
local function near(a,b) return math.abs(a-b)<1e-6 end
local rng = { NextInteger = function(_,a,b) return b end }
local perfect = { Element = "Fire", Size = 10, Clarity = 10, Cut = 10 }
local count = 0
for id, def in ArmorSignatures.Definitions do
 count += 1
 local roll = { Signature = id, SignatureVersion = 1, Rarity = 5, Affixes = {} }
 check(near(ArmorSignatures.resolve(roll, perfect).Value,def.Max), "Perfect gem cap "..id)
 check(ArmorSignatures.resolve(roll,nil).Value>0, "Empty socket identity "..id)
 check(near(ArmorSignatures.resolve(roll,perfect,true).Value,ArmorSignatures.resolve({Signature=id,Rarity=1},nil,true).Value), "Ranked normalization "..id)
end
check(count==8,"Launch roster must contain eight buffs")
for slot,pool in ArmorSignatures.Pools do
 local roll={Rarity=3,Stats={Health=80},Affixes={{Id="kept",Bonus=.1}},Finish=3,Serial=7}
 ArmorSignatures.ensure(roll,slot,rng)
 local first=roll.Signature
 ArmorSignatures.ensure(roll,slot,{NextInteger=function() error("migration rerolled") end})
 check(roll.Signature==first and roll.Stats.Health==80 and roll.Affixes[1].Id=="kept" and roll.Serial==7,"Migration changed saved data")
 check(ArmorSignatures.Definitions[first].Slot==slot,"Cross-slot signature")
end
local affinityId
for id,def in GemConfig.AffixById do if def.Element=="Fire" then affinityId=id;break end end
local roll={Signature="Barrier",Rarity=3,Affixes={{Id=affinityId,Bonus=.1}}}
local middle={Element="Fire",Size=5,Clarity=5,Cut=5}
local boosted=ArmorSignatures.resolve(roll,middle).Value
middle.Element="Frost"
check(boosted>ArmorSignatures.resolve(roll,middle).Value,"Matching affinity did not improve enchantment")
roll.Affixes[2]={Id=affinityId,Bonus=.1};middle.Element="Fire"
check(near(boosted,ArmorSignatures.resolve(roll,middle).Value),"Affinity duplicate multiplied")
local perks={}
for id in ArmorSignatures.Definitions do perks[id]=ArmorSignatures.resolve({Signature=id,Rarity=1},perfect) end
local st={}
check(ArmorSignatures.timedBlock(st,perks,10)==10,"Countercharge")
check(ArmorSignatures.timedBlock(st,perks,10.1)==0,"Cooldown bypass")
check(near(ArmorSignatures.attackMultiplier(st,10.2),1.25),"Riposte not primed")
check(ArmorSignatures.attackMultiplier(st,10.3)==1,"Riposte repeated")
check(ArmorSignatures.absorb(st,20,11)==5,"Barrier did not absorb")
check(ArmorSignatures.absorb(st,20,11.1)==20,"Barrier duplicated")
check(near(ArmorSignatures.dodged(st,perks,12,15,12),4.5),"Refund must use actual dodge cost")
check(ArmorSignatures.dodged(st,perks,16,15,12)==0,"Same dodge refunded twice")
check(ArmorSignatures.budget(st,"Charge",25,30,20)==25,"Charge budget")
check(ArmorSignatures.budget(st,"Charge",20,30,21)==5,"Charge cap")
check(ArmorSignatures.budget(st,"Charge",20,30,29.9)==0,"Window reset early")
check(ArmorSignatures.budget(st,"Charge",20,30,30)==20,"Sliding expiry")
local charge,heal=ArmorSignatures.hit({},perks,30,0,true)
check(charge==0 and heal==0,"Absorbed hit proc")
local charge,heal=ArmorSignatures.hit(st,perks,40,1,true)
check(near(heal,.05),"Overkill life steal")
check(near(ArmorSignatures.speed(st,40),1.18) and ArmorSignatures.speed(st,42)==1,"Pursuit expiry")
check(near(ArmorSignatures.guardMultiplier(perks),.65),"Guard cost reduction")
-- Run actual server strikes with migrated gear, not only isolated formulas.
local a,ha,ra,la=makePlayer(901,arena+Vector3.new(20,0,10),nil)
local b,hb,rb,lb=makePlayer(902,arena+Vector3.new(20,0,6),nil)
la.Armor="ArmorProspectorArmor3"
la.Helmet="ArmorProspectorHelmet3"
la.GearRolls={Armors={[la.Armor]={Signature="LifeSteal",SignatureVersion=1,Rarity=1}},Helmets={[la.Helmet]={Signature="ChargeGain",SignatureVersion=1,Rarity=1}}}
la.ArmorGem=perfect;la.HelmetGem=perfect
la.Surge1Gem={Surge="IonSpark",Element="Shock",Tier="Common",Size=1,Clarity=1,Cut=1}
now+=30;CombatServer.reset(a);CombatServer.reset(b);ha.Health=500;hb.Health=1
CombatServer._attack(a,rb.Position,false)
check(near(ha.Health,500.05),"Server overkill life steal")
check(CombatServer._state(a).Resources.Charge>=3,"Server bonus Charge")
check(CombatServer.kitFor(la,{}).Defense.Shield==0,"Legacy armor effects still active")
check(ElementMatchup.profile(la).Main==nil,"Migrated gems retain old resistance")
now+=10;CombatServer.reset(a);CombatServer.reset(b);ha.Health=500;hb.Health=1000
local bs=CombatServer._state(b);bs.Shield=10000;bs.ShieldUntil=now+10
CombatServer._attack(a,rb.Position,false)
check(ha.Health==500,"Absorption generated healing")
now+=10;CombatServer.reset(a);CombatServer.reset(b);ha.Health=500;hb.Health=1
CrowdControl.applyHealCut(CombatServer._state(a).CC,"MortalStrike",now)
local mult=CrowdControl.healingMultiplier(CombatServer._state(a).CC,now)
CombatServer._attack(a,rb.Position,false)
check(near(ha.Health,500+.05*mult),"Armor healing bypassed anti-heal")
a:SetAttribute("PvPEnabled",false);b:SetAttribute("PvPEnabled",false)
print("PASS: "..checks.." armor signatures: rolls, migration, caps, affinities, server strikes and anti-heal")
