local checks=0
local function check(ok,message) checks+=1; assert(ok,message) end
local miner={UserId=99,DisplayName="Another miner"}
local at=Vector3.new(5,2,3)
local function reward(tier)
	return {Name="Crystal Boulder",Gem={Id="gem-"..tier,Tier=tier,Element="Frost",Size=8,Clarity=7,Cut=6,PrivateField="excluded"},Coins=4}
end
Reveal.start(); Reveal.start() -- idempotent listener registration
for rank,tier in GemConfig.TierOrder do
	local loot=reward(tier)
	MiningRolls.publish(miner,at,loot)
	local packet=packets[#packets]
	check(packet.MinerId==99 and packet.MinerName==miner.DisplayName,"Discovery credited to wrong miner")
	check(packet.Position==at and packet.StartedAt==now,"Discovery lost rock location/server clock")
	check(packet.Gem~=loot.Gem and packet.Gem.PrivateField==nil,"Broadcast exposed saved fields/shared mutable reward")
	check(#live("RollAnchor")==1,"Observer did not receive exactly one roll")
	check(#liveClass("ScreenGui")==0 and #liveClass("BillboardGui")==2,"World roll became a private screen window")
	check(textContains(miner.DisplayName) and textContains("ROLLING"),"Public roll missing miner/animation label")
	check(#live("AwardedGem")==0,"Award shown before lottery completed")
	local a,b=Roll.sequence(packet),Roll.sequence(packet)
	for i=-1,Roll.Target+2 do check(a[i]==b[i],"Observers see different reel sequence") end
	check(a[Roll.Target]==tier,"Sequence did not end on awarded rarity")
	for _=1,10 do step(.25) end
	check(#live("AwardedGem")==0,"Roll ended early")
	step(.31)
	check(#live("AwardedGem")==1 and live("AwardedGem")[1].Gem==packet.Gem,"Showcase not actual awarded gem")
	check(textContains("SIZE 8/10") and textContains("CLARITY 7/10") and textContains("CUT 6/10"),"Rolled metrics missing")
	check(textContains(string.upper(GemConfig.TierLabels[tier])) and textContains("+4 coins"),"Result lost rarity/rewards")
	check(#live("RarityBeacon")==(if rank>=3 then 1 else 0),"Rare discovery beacon wrong")
	check(liveClass("ParticleEmitter")[1].Emitted==8+rank*10,"Rarity did not increase celebration")
	for _,p in liveClass("Part") do check(not p.CanQuery and not p.CanCollide and not p.CanTouch,"Cosmetic obstructs mining/players") end
	Reveal.receive(packet)
	check(#live("AwardedGem")==1,"Duplicate event duplicated discovery")
	step(Roll.lifetime(packet))
	check(#liveClass("BillboardGui")==0 and #liveClass("Model")==0,"Roll/templates leaked after expiry")
end
-- No gem (including full pouch) must never invent a reward.
for _,full in {false,true} do
	MiningRolls.publish(miner,at,{Name="Boulder",Coins=2,Full=full})
	step(Roll.Duration+.1)
	check(#live("AwardedGem")==0,"Empty reward manufactured a gem")
	check(textContains(if full then "STONE POUCH FULL" else "No stone this time"),"No-gem outcome not explained")
	Reveal.close()
end
local before=#packets
MiningRolls.publish(miner,at,{Tutorial=true,Gem=reward("Rare").Gem})
check(#packets==before,"Tutorial broadcast twice")
MiningRolls.publish(miner,Vector3.new(10000,0,0),reward("Rare"))
check(#live("RollAnchor")==0,"Distant lottery rendered")
-- A late packet catches up to the same result instead of starting over.
local old=table.clone(packets[#packets]); old.Id=100000; old.Position=at; old.StartedAt=now-Roll.Duration-1
Reveal.receive(old)
check(#live("AwardedGem")==1 and #liveClass("ParticleEmitter")==0,"Late delivery replayed old celebration")
Reveal.close()
old.Id+=1; old.StartedAt=now-30
Reveal.receive(old)
check(#live("RollAnchor")==0,"Expired result replayed")
-- Simultaneous mines use separate positions and a bounded number of reels.
for i=1,Roll.MaxActive+5 do MiningRolls.publish(miner,Vector3.new(i,0,0),reward("Rare")) end
check(#live("RollAnchor")==Roll.MaxActive,"Concurrent reels exceeded visual budget")
check(#liveClass("Model")<=Roll.MaxActive*4+5,"Reel geometry allocation unbounded")
step(Roll.Duration+.1)
check(#live("AwardedGem")==Roll.MaxActive,"Concurrent finds overwrote winners")
player:SetAttribute("CombatSession","Rival")
check(#live("RollAnchor")==0 and #liveClass("Model")==0,"Arena transition kept lobby effects")
MiningRolls.publish(miner,at,reward("Rare"))
check(#live("RollAnchor")==0,"Combat spectator received lobby roll")
player:SetAttribute("CombatSession",nil)
MiningRolls.publish(miner,at,reward("Rare"))
root.Position=Vector3.new(10000,0,0); step(.1)
check(#live("RollAnchor")==0,"Out-of-range effects stayed alive")
root.Position=Vector3.zero
MiningRolls.publish(miner,at,reward("Rare"))
workspace.CurrentCamera=nil; step(.1)
check(#live("RollAnchor")==1,"Missing camera broke roll")
player:SetAttribute("Outpost",false)
check(#liveClass("BillboardGui")==0,"Leaving lobby leaked result labels")
print("PASS: "..checks.." shared world mining lottery checks")
