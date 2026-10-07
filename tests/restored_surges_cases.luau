local count=0
local function check(ok,msg) count+=1; assert(ok,msg) end
local ids={}
for _, pool in GemRoller.Pools do for _,id in pool do ids[id]=true end end
for _,id in GemRoller.NeutralPool do ids[id]=true end
local total=0
for id in ids do
	total+=1
	local base=Tech.Catalog[id]
	local common=Tech.surgeStats({Surge=id,Tier="Common",Element=base.Element or "Fire",Size=1,Clarity=1,Cut=1})
	for _,rarity in GemRoller.Rarities do
		local gem={Surge=id,Tier=rarity.Name,Element=base.Element or "Fire",Size=10,Clarity=10,Cut=10,SurgeRank=3,SurgeTier=4}
		local stats=Tech.surgeStats(gem)
		check(stats.Id==id,"Ability identity changed")
		check(Atlas.Index[Icons.idOf(stats)]~=nil,"Missing painted icon")
		for _,key in {"Q","E","R"} do check(Tech.canSocket(gem,key,{}),"Flexible socket rejected") end
		check(not Tech.canSocket(gem,"E",{Surge1Gem=gem}),"Duplicate accepted")
		for _,field in {"Range","Radius","Windup","Duration","Cooldown","Recovery","Stun","SlowTime","ShredTime","BlindTime","Execute","Shred"} do
			check(stats[field]==common[field],id.." altered "..field)
		end
		local normalized=Tech.surgeStats(gem,nil,true)
		check(normalized.Damage==common.Damage and normalized.Absorb==common.Absorb and normalized.Cost==common.Cost,"Ranked rarity advantage")
		local low=table.clone(gem); low.Size,low.Clarity,low.Cut,low.SurgeRank,low.SurgeTier=1,1,1,1,1
		local lowStats=Tech.surgeStats(low)
		check(lowStats.Damage==stats.Damage and lowStats.Cost==stats.Cost and lowStats.Crit==stats.Crit,"Legacy metrics still scale Surge")
		local factor=Tech.RarityScale[rarity.Name]
		if common.Absorb then check(math.abs(stats.Absorb-common.Absorb*factor)<.0001,"Barrier rarity")
		elseif common.Damage then check(math.abs(stats.Damage-common.Damage*factor)<.0001,"Damage rarity")
		else check(math.abs(stats.Cost-common.Cost*(1-(factor-1)*.5))<.0001,"Utility rarity") end
	end
end
check(total==36,"Expected original 36 Surges")
check(Tech.surgeGem({},"R")==nil,"Empty slot granted prototype Shift")
for old,new in GemRoller.RestoredIds do
	local gem={Surge=old,Element="Fire",Tier="Common"}
	check(Tech.surgeOf(gem)==new and gem.Surge==old,"Prototype save mapping")
end
-- Seeded draws prove every original ability is reachable at every rarity.
local seed=101
local rng={}
function rng:NextNumber() seed=(seed*48271)%2147483647; return seed/2147483647 end
function rng:NextInteger(a,b) return a+math.floor(self:NextNumber()*(b-a+1)) end
local seen={}
for _=1,60000 do
	local gem=GemRoller.roll(rng)
	check(ids[gem.Surge],"Non-original ability rolled")
	check(table.find(GemRoller.Pools[gem.Element],gem.Surge) or table.find(GemRoller.NeutralPool,gem.Surge),"Wrong element ability")
	seen[gem.Tier..gem.Surge]=true
end
for id in ids do for _,rarity in GemRoller.Rarities do check(seen[rarity.Name..id],"Ability rarity gated: "..id) end end
for _,style in Lottery.Styles do for _,element in GemRoller.Elements do
	local profile={Intro={},Character={},Gems={}}
	local kit=Lottery.prepareChoice(profile,style,element,function(e) return {Id=e,Element=e} end)
	check(#kit.Gems==3 and kit.Version==3,"Starter roster")
	for index,entry in kit.Gems do check(entry.Gem.Surge==GemRoller.StarterSurges[element][index] and entry.Gem.Tier=="Common","Starter identity") end
end end
print("PASS: "..count.." restored Surge checks across all 36 abilities and five rarities")
