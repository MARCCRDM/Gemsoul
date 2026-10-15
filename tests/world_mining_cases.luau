local checks=0
local function check(ok,message) checks+=1; assert(ok,message) end
local miner={UserId=99,DisplayName="Another miner"}
local at=Vector3.new(5,2,3)
local minerHead={Position=Vector3.new(10,5,7),Size=Vector3.new(2,2,2)}
local minerRoot={Position=Vector3.new(10,3,7)}
local minerCharacter={FindFirstChild=function(_,name) return if name=="Head" then minerHead else minerRoot end}
miner.Character=minerCharacter
remotePlayers[miner.UserId]=miner
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
	check(packet.MinerPosition==minerHead.Position,"Missing authoritative miner location for streaming fallback")
	check(packet.Gem~=loot.Gem and packet.Gem.PrivateField==nil,"Broadcast exposed saved fields/shared mutable reward")
	check(#live("RollAnchor")==1,"Observer did not receive exactly one roll")
	check(#liveClass("ScreenGui")==0 and #liveClass("BillboardGui")==1,"World roll became a private screen window")
	check(#live("MiningRollBox")==1 and #liveClass("ViewportFrame")==1 and live("ReelWindow")[1].ClipsDescendants,"Roll is not enclosed in one clipped box")
	check(live("Discovery")[1].Parent==playerGui and live("Discovery")[1].Adornee==live("RollAnchor")[1],"Box lost world anchor")
	check(live("RollAnchor")[1].Position.Y==minerHead.Position.Y+4,"Box is not above miner head")
	check(textContains(miner.DisplayName) and textContains("ROLLING"),"Public roll missing miner/animation label")
	check(#live("AwardedGem")==0,"Award shown before lottery completed")
	local a,b=Roll.sequence(packet),Roll.sequence(packet)
	for i=-1,Roll.Target+2 do check(a[i]==b[i],"Observers see different reel sequence") end
	check(a[Roll.Target]==tier,"Sequence did not end on awarded rarity")
	for _=1,10 do step(.25) end
	check(#live("AwardedGem")==0,"Roll ended early")
	step(.31)
	check(#live("AwardedGem")==1 and live("AwardedGem")[1].Gem==packet.Gem,"Showcase not actual awarded gem")
	check(live("AwardedGem")[1].Parent==live("GemReel")[1],"Winning gem escaped box")
	check(textContains("SIZE 8/10") and textContains("CLARITY 7/10") and textContains("CUT 6/10"),"Rolled metrics missing")
	check(textContains(string.upper(GemConfig.TierLabels[tier])) and textContains("+4 coins"),"Result lost rarity/rewards")
	check(#live("DiscoveryRing")==0 and #live("RarityBeacon")==0,"World geometry cuts through reward card")
	check(live("WinningSlot")[1].Visible==false,"Reel selection remains on final gem")
	check(liveClass("UISizeConstraint")[1].MaxSize.X==260 and liveClass("UISizeConstraint")[1].MaxSize.Y==162,"Close camera can inflate reward card")
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
	check(live("ReelWindow")[1].Visible==false and live("WinningSlot")[1].Visible==false,"Empty reward leaves blank reel on screen")
	check(liveClass("UISizeConstraint")[1].MaxSize.Y==74 and live("Discovery")[1].Size[3]==1.65,"No-gem result did not collapse")
	check(textContains("+2 coins") and #liveClass("ParticleEmitter")==0,"Coins missing or empty find celebrated as a gem")
	Reveal.close()
end
local before=#packets
MiningRolls.publish(miner,at,{Tutorial=true,Gem=reward("Rare").Gem})
check(#packets==before,"Tutorial broadcast twice")
MiningRolls.publish(miner,Vector3.new(10000,0,0),reward("Rare"))
check(#live("RollAnchor")==1,"Nearby miner incorrectly culled by distant rock position")
Reveal.close()
minerHead.Position=Vector3.new(10000,5,0)
MiningRolls.publish(miner,at,reward("Rare"))
check(#live("RollAnchor")==0,"Distant miner lottery rendered")
minerHead.Position=Vector3.new(10,5,7)
-- A late packet catches up to the same result instead of starting over.
local old=table.clone(packets[#packets]); old.Id=100000; old.Position=at; old.StartedAt=now-Roll.Duration-1
Reveal.receive(old)
check(#live("AwardedGem")==1 and #liveClass("ParticleEmitter")==0,"Late delivery replayed old celebration")
Reveal.close()
old.Id+=1; old.StartedAt=now-30
Reveal.receive(old)
check(#live("RollAnchor")==0,"Expired result replayed")
-- Multiple nearby miners get separate boxes, with a bounded number of reels.
for i=1,Roll.MaxActive+5 do MiningRolls.publish({UserId=1000+i,DisplayName="Miner "..i},Vector3.new(i,0,0),reward("Rare")) end
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
minerHead.Position=Vector3.new(21,9,11); step(.1)
local anchor=live("RollAnchor")[1]
check(anchor.Position.X==21 and anchor.Position.Y==13 and anchor.Position.Z==11,"Box does not follow miner movement")
local last=anchor.Position
miner.Character=nil; step(.1)
check(anchor.Position==last,"Temporarily streamed-out miner moved box back to rock")
miner.Character={FindFirstChild=function(_,name) return if name=="HumanoidRootPart" then minerRoot else nil end}; step(.1)
check(anchor.Position.Y==minerRoot.Position.Y+5.5,"Missing head did not fall back to character root")
miner.Character=minerCharacter
MiningRolls.publish(miner,at,reward("Legendary"))
check(#live("MiningRollBox")==1 and #live("RollAnchor")==1,"Rapid mining stacked boxes over the same player")
step(Roll.Duration+.1)
minerHead.Position=Vector3.new(30,5,8); step(.1)
check(live("RollAnchor")[1].Position.X==30,"Result did not follow miner")
check(live("MiningRollBox")[1].BackgroundTransparency<0.2 and live("GemReel")[1].ImageTransparency==0,"Box unexpectedly transparent before fade")
player:SetAttribute("Outpost",false)
check(#liveClass("BillboardGui")==0,"Leaving lobby leaked result labels")
print("PASS: "..checks.." shared world mining lottery checks")
