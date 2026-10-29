local checks=0
local function check(ok,message) checks+=1; assert(ok,message) end
local miner={UserId=99,DisplayName="Another miner"}
local at=Vector3.new(5,2,3)
local minerCharacter=new("Model"); minerCharacter.Parent=workspace
local minerHead=new("Part"); minerHead.Name="Head"; minerHead.Position=Vector3.new(10,5,7); minerHead.Size=Vector3.new(2,2,2); minerHead.Parent=minerCharacter
local minerRoot=new("Part"); minerRoot.Name="HumanoidRootPart"; minerRoot.Position=Vector3.new(10,3,7); minerRoot.Parent=minerCharacter
local humanoid=new("Humanoid"); humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.Viewer; humanoid.Parent=minerCharacter
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
	check(live("RollAnchor")[1].Position.Y==minerHead.Position.Y+2.1,"Box is not above miner head")
	check(humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.None,"Native name overlaps roll")
	check(live("Discovery")[1].SizeOffset.Y==0.5 and live("Discovery")[1].AlwaysOnTop,"Box does not sit fully above head")
	check(textContains(miner.DisplayName) and textContains("ROLLING"),"Public roll missing miner/animation label")
	check(#live("AwardedGem")==0,"Award shown before lottery completed")
	local a,b=Roll.sequence(packet),Roll.sequence(packet)
	for i=-1,Roll.Target+2 do check(a[i]==b[i],"Observers see different reel sequence") end
	check(a[Roll.Target]==tier,"Sequence did not end on awarded rarity")
	local ea,eb=Roll.elements(packet),Roll.elements(packet)
	for i=-1,Roll.Target+2 do check(ea[i]==eb[i],"Observers see different reel elements") end
	check(ea[Roll.Target]==packet.Gem.Element,"Reel did not end on the awarded gem's element")
	local kinds={}
	for seed=1,40 do
		local e=Roll.elements({Seed=seed,Gem=packet.Gem})
		for i=-1,Roll.Target-1 do kinds[e[i]]=true end
	end
	check(kinds.Fire and kinds.Frost and kinds.Shock and kinds.Poison,"Reel gems aren't any of the four elements")
	for _=1,10 do step(.25) end
	check(#live("AwardedGem")==0,"Roll ended early")
	step(.31)
	check(#live("AwardedGem")==1 and live("AwardedGem")[1].Gem==packet.Gem,"Showcase not actual awarded gem")
	check(live("AwardedGem")[1].Parent==live("GemReel")[1],"Winning gem escaped box")
	-- Onlookers get a small tag: rarity, the gem's name and its worth; its
	-- size, clarity and cut are the miner's own loot card's.
	check(not textContains("SIZE 8/10") and not textContains("CLARITY 7/10"),"The public tag lists every metric again")
	check(textContains(GemConfig.shade(packet.Gem).Name),"The tag doesn't name the gem")
	check(textContains(string.upper(GemConfig.TierLabels[tier])) and textContains("≈"),"Result lost rarity/worth")
	-- Rocks pay gems only: stray coins or gear never reach the broadcast or the box.
	check(packet.Coins==nil and packet.Gear==nil and not textContains("+4 coins"),"A gem find advertised coins")
	check(#live("DiscoveryRing")==0 and #live("RarityBeacon")==0,"World geometry cuts through reward card")
	check(live("WinningSlot")[1].Visible==false,"Reel selection remains on final gem")
	check(live("Discovery")[1].Size[2]==Roll.Tag.Width and live("Discovery")[1].Size[4]==math.floor(Roll.Tag.Width*Roll.Tag.Ratio),"Nearby roll isn't the small tag's full size")
	check(liveClass("ParticleEmitter")[1].Emitted==8+rank*10,"Rarity did not increase celebration")
	for _,p in liveClass("Part") do if p.Parent~=minerCharacter then check(not p.CanQuery and not p.CanCollide and not p.CanTouch,"Cosmetic obstructs mining/players") end end
	Reveal.receive(packet)
	check(#live("AwardedGem")==1,"Duplicate event duplicated discovery")
	step(Roll.lifetime(packet))
	check(#liveClass("BillboardGui")==0 and #liveClass("Model")==1,"Roll/templates leaked after expiry")
	check(humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.Viewer,"Name not restored after roll")
end
-- No gem (a full pouch) must never invent a reward.
for _,full in {false,true} do
	MiningRolls.publish(miner,at,{Name="Boulder",Coins=2,Full=full})
	step(Roll.Duration+.1)
	check(#live("AwardedGem")==0,"Empty reward manufactured a gem")
	check(textContains("ROCK MINED") and (textContains("GEM POUCH FULL")==full),"No-gem outcome not explained")
	check(live("ReelWindow")[1].Visible==false and live("WinningSlot")[1].Visible==false,"Empty reward leaves blank reel on screen")
	check(live("Discovery")[1].Size[4]<110,"No-gem result did not collapse")
	check(not textContains("+2 coins") and #liveClass("ParticleEmitter")==0,"Coins shown or empty find celebrated as a gem")
	Reveal.close()
end
-- Your own find is your loot card (MinerLoot), never a box over your own head;
-- everyone else still sees it.
remotePlayers[player.UserId]=player
for _,tier in {"Common","Legendary"} do
	MiningRolls.publish(player,at,reward(tier))
	check(packets[#packets].MinerId==player.UserId,"Own find not broadcast for other players")
	check(#live("RollAnchor")==0 and #liveClass("BillboardGui")==0,"Miner sees their own roll over their head")
	step(Roll.Duration+.1)
	check(#live("AwardedGem")==0,"Miner's own result shown in the world")
end
MiningRolls.publish(miner,at,reward("Rare"))
check(#live("RollAnchor")==1,"Skipping own finds hid another player's roll")
Reveal.close()
remotePlayers[player.UserId]=nil
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
-- (the reels' cells, plus one template a rarity in each element: every element shows at every rarity)
check(#liveClass("Model")<=Roll.MaxActive*4+6+#GemConfig.TierOrder*(#GemConfig.Elements-1),"Reel geometry allocation unbounded")
step(Roll.Duration+.1)
check(#live("AwardedGem")==Roll.MaxActive,"Concurrent finds overwrote winners")
player:SetAttribute("CombatSession","Rival")
check(#live("RollAnchor")==0 and #liveClass("Model")==1,"Arena transition kept lobby effects")
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
check(anchor.Position.X==21 and anchor.Position.Y==11.1 and anchor.Position.Z==11,"Box does not follow miner movement")
local last=anchor.Position
miner.Character=nil; step(.1)
check(anchor.Position==last,"Temporarily streamed-out miner moved box back to rock")
minerHead.Parent=nil; miner.Character=minerCharacter; step(.1)
check(anchor.Position.Y==minerRoot.Position.Y+3.6,"Missing head did not fall back to character root")
minerHead.Parent=minerCharacter
miner.Character=minerCharacter
local windows=#legendaries
MiningRolls.publish(miner,at,reward("Legendary"))
check(#live("MiningRollBox")==1 and #live("RollAnchor")==1,"Rapid mining stacked boxes over the same player")
check(#legendaries==windows,"The Legendary window opened before the reel landed")
step(Roll.Duration+.1)
-- Someone else's Legendary: its window over them, their box stepping aside.
local shown=legendaries[#legendaries]
check(#legendaries==windows+1 and shown.Gem.Tier=="Legendary" and shown.Finder==miner.DisplayName and shown.Character==minerCharacter,"Someone else's Legendary opened no window over them")
check(liveClass("BillboardGui")[1].Enabled==false,"Their box didn't step aside for the Legendary window")
minerHead.Position=Vector3.new(30,5,8); step(.1)
check(live("RollAnchor")[1].Position.X==30,"Result did not follow miner")
check(live("MiningRollBox")[1].BackgroundTransparency<0.2 and live("GemReel")[1].ImageTransparency==0,"Box unexpectedly transparent before fade")
player:SetAttribute("Outpost",false)
check(#liveClass("BillboardGui")==0,"Leaving lobby leaked result labels")
-- Cosmetic and party names disappear only while this observer sees a roll.
player:SetAttribute("Outpost",true)
local title=new("BillboardGui"); title.Name="CosmeticTitle"; title.Enabled=true; title.Parent=minerHead
local party=new("BillboardGui"); party.Name="PartyMarker"; party.Enabled=false; party.Parent=minerHead
MiningRolls.publish(miner,at,reward("Rare"))
check(not title.Enabled and not party.Enabled,"Duplicate overhead titles still cover the reel")
local lateTitle=new("BillboardGui"); lateTitle.Name="Nameplate"; lateTitle.Enabled=true; lateTitle.Parent=minerHead
check(not lateTitle.Enabled,"Newly streamed/equipped name overlaps active roll")
MiningRolls.publish(miner,at,reward("Legendary"))
check(not title.Enabled and humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.None,"Fast replacement restored duplicate names too early")
Reveal.close()
check(title.Enabled and lateTitle.Enabled and not party.Enabled,"Cleanup failed to restore original enabled states")
check(humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.Viewer,"Native name remained hidden after cleanup")
-- Someone else's find is a small tag: readable, but never much of the screen
-- (desktop or phone, near or far).
for _,screen in {Vector2.new(1280,720),Vector2.new(667,339),Vector2.new(812,317),Vector2.new(390,844)} do
	for _,touch in {false,true} do
		for _,distance in {5,35,80,180} do
			local w,h=Roll.displaySize(screen,distance,touch,false)
			check(w>=130 and h>=54,"Public roll shrank below readable size")
			check(w<=210 and w<=screen.X*.4 and h<=screen.Y*.25,"Public roll covers too much of the screen")
			local _,notice=Roll.displaySize(screen,distance,touch,true)
			check(notice<h,"Full-pouch notice kept the large reel footprint")
		end
	end
end
services.UserInputService.TouchEnabled=true
workspace.CurrentCamera={CFrame=CFrame.new(0,0,100),ViewportSize=Vector2.new(812,317)}
MiningRolls.publish(miner,at,reward("Rare"))
local board=live("Discovery")[1]
check(board.Size[2]>=140 and board.Size[2]<=176 and board.Size[4]<=74,"Mobile tag isn't small and readable")
workspace.CurrentCamera.ViewportSize=Vector2.new(390,844); step(.1)
check(board.Size[2]<=156,"Portrait rotation did not resize the public tag")
player:SetAttribute("CombatSession","Rival")
check(title.Enabled and lateTitle.Enabled and not party.Enabled,"Arena transition failed to restore overhead titles")
print("PASS: "..checks.." shared world mining lottery checks")
