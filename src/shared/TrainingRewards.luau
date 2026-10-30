-- Pure account-persistent training objectives. No client supplies completion or payouts.
local Training = {}
-- The learning path: chapters (Category) in the order a new player meets
-- them, the steps inside each in order. Step: what the card says to do,
-- one short line; Hint: the how. Go: where its GO button takes you (the
-- Tasks window: Mine, Inventory, Play, Market, Kennel, Guide:<section>). Needs: a
-- Config.Features switch it waits on (off: it's left out).
Training.Objectives = {
 -- Basics: dig in.
 {Id="FirstRock",Category="Basics",Event="Mine",Goal=1,Coins=125,Go="Mine",Name="Break your first rock",Hint="Walk up to a glowing rock in the Outpost and swing: click, tap or press E."},
 {Id="GemFind",Category="Basics",Event="MineGem",Goal=1,Coins=125,Go="Mine",Name="Find a gem",Hint="Every rock holds a gem. It flies into your bag the moment the rock breaks."},
 {Id="ThreeRocks",Category="Basics",Event="Mine",Goal=3,Coins=175,Go="Mine",Name="Keep digging",Hint="Break three rocks. More gems, more choices for your build."},
 -- Gear: gems make you stronger.
 {Id="Enchant",Category="Gear",Event="Enchant",Goal=1,Coins=125,Go="Inventory",Name="Socket a gem",Hint="Open Inventory and drag a gem onto a piece of your gear."},
 {Id="EquipSurge",Category="Gear",Event="EquipSurge",Goal=1,Coins=100,Go="Inventory",Name="Ready a Surge",Hint="In Inventory, put a gem in Q, E or R. That's a power you can cast in fights."},
 {Id="ThreeSlots",Category="Gear",Event="Slot",Goal=3,Coins=250,Go="Inventory",Name="Build your loadout",Hint="Socket gems into three different pieces of gear."},
 -- Fight: the basics of a duel.
 {Id="Attack",Category="Fight",Event="Hit",Goal=1,Coins=100,Go="Play",Name="Land a hit",Hint="Click or tap to swing your sword at an enemy. PLAY, then Practice, is a safe place to try."},
 {Id="Guard",Category="Fight",Event="Block",Goal=1,Coins=175,Go="Play",Name="Block a hit",Hint="Hold right click (or the shield button) as a blow comes in."},
 {Id="Cast",Category="Fight",Event="Surge",Goal=1,Coins=150,Go="Play",Name="Cast a Surge",Hint="Fighting fills your Charge. When it's ready, press Q, E or R (the gem buttons on a phone)."},
 {Id="TimedGuard",Category="Fight",Event="TimedBlock",Goal=1,Coins=200,Go="Play",Name="Perfect block",Hint="Raise your shield just before the hit lands, not long before."},
 {Id="Rival",Category="Fight",Event="RivalWin",Goal=1,Coins=250,Go="Play",Name="Beat a Rival",Hint="PLAY, then 1v1 Practice: win against a computer miner."},
 -- Kaiju: your team (the first from Wren, at the Kennel: not in the intro).
 {Id="KaijuStarter",Category="Kaiju",Event="KaijuStarter",Goal=1,Coins=150,Go="Kennel",Needs="Kaiju",Name="Meet Wren",Hint="Talk to Wren at the Kaiju Kennel and roll your free team of kaiju."},
 {Id="KaijuCatch",Category="Kaiju",Event="KaijuCatch",Goal=1,Coins=300,Go="Guide:Kaiju",Needs="Kaiju",Name="Catch a kaiju",Hint="Wear a wild kaiju down until it glows gold and its plate says CATCH, then catch it."},
 {Id="Hyperbeam",Category="Kaiju",Event="Hyperbeam",Goal=1,Coins=200,Go="Guide:Kaiju",Needs="Kaiju",Name="Fire a HYPERBEAM",Hint="Your kaiju charge it as they fight. When it's full, press Z (the beam button on a phone)."},
 {Id="KaijuBattle",Category="Kaiju",Event="KaijuBattle",Goal=1,Coins=250,Go="Guide:Kaiju",Needs="Kaiju",Name="Kaiju Arena",Hint="Downstairs in the Shelter: step on a pad, place your kaiju, and watch them battle."},
 -- Explore: the Outpost and beyond.
 {Id="Mech",Category="Explore",Event="Mech",Goal=1,Coins=150,Go="Guide:Outpost",Needs="Mechs",Name="Pilot a mech",Hint="Find the garage in the Shelter and climb into a mech."},
 {Id="RiftBoss",Category="Explore",Event="RiftBoss",Goal=1,Coins=500,Go="Guide:Rift",Needs="Kaiju",Name="Beat a Rift boss",Hint="Mine out to the Rift Vein, step through the gate and take down the boss at the end."},
 -- PvP: real players.
 {Id="PvPPlayed",Category="PvP",Event="PvPPlayed",Goal=1,Coins=200,Go="Play",Name="Enter the arena",Hint="Finish a 1v1 against a real player. Winning is optional."},
 {Id="PvPWin",Category="PvP",Event="PvPWin",Goal=1,Coins=500,Go="Play",Name="First challenger defeated",Hint="Win a 1v1 against a real player."},
 -- PvE: dungeons with a party.
 {Id="Boss",Category="PvE",Event="Boss",Goal=1,Coins=625,Go="Play",Name="Bring down a boss",Hint="Be alive with your party when a dungeon boss falls. Developer test runs do not count."},
 {Id="DungeonComplete",Category="PvE",Event="DungeonComplete",Goal=1,Coins=500,Go="Play",Name="Extraction complete",Hint="Finish a real dungeon run alive and collect your completion reward."},
 -- Market: trade with players.
 {Id="MarketBuy",Category="Market",Event="MarketBuy",Goal=1,Coins=175,Go="Market",Name="Find your upgrade",Hint="Buy something another player listed on the Market."},
 {Id="MarketSale",Category="Market",Event="MarketSale",Goal=1,Coins=375,Go="Market",Name="Open for business",Hint="Sell an item to another player. It counts when the payment arrives."},
 -- Discoveries: long-term, never in the way.
 {Id="RareFind",Category="Discoveries",Event="RareGem",Goal=1,Coins=300,Go="Mine",Name="A rare discovery",Hint="Mine a Rare or better gem. Starter gifts and purchases do not count."},
 {Id="LegendFind",Category="Discoveries",Event="LegendGem",Goal=1,Coins=750,Go="Mine",Name="Struck legendary",Hint="Discover a Legendary gem while mining. A long-term goal: no rush."},
}
-- The chapters, in order (the window opens on the first with steps left).
Training.Pages={"Basics","Gear","Fight","Kaiju","Explore","PvP","PvE","Market","Discoveries"}
-- What each chapter teaches, one line (the Tasks window's chapter header).
Training.Blurbs={
 Basics="Mine rocks, find gems.",
 Gear="Gems in your gear make you stronger.",
 Fight="Swing, block and cast: the duel basics.",
 Kaiju="Catch kaiju and fight as a team.",
 Explore="Mechs, the Rift and its bosses.",
 PvP="Test yourself against real players.",
 PvE="Dungeons with a party.",
 Market="Buy and sell with other players.",
 Discoveries="Rare finds. Long-term goals, no rush.",
}
-- Chapters for activities that are switched off (Config.Features), e.g.
-- Closed.PvE while dungeons are closed, and single steps waiting on a
-- switch (Needs, Off): they're left out of the list and the count, and
-- never the chapter the window opens on. Filled in from Config.Features
-- by closeFor.
Training.Closed={}
Training.Off={}
function Training.closeFor(features)
 Training.Closed.PvE=features.Dungeons==false
 Training.Closed.Market=features.Market==false
 Training.Off.Kaiju=features.Kaiju==false
 Training.Off.Mechs=features.Mechs==false
end
function Training.pageOf(objective)
 if objective.Id=="RareFind" or objective.Id=="LegendFind" then return "Discoveries" end
 return objective.Category
end
function Training.listed(objective)
 return not Training.Closed[Training.pageOf(objective)] and not (objective.Needs and Training.Off[objective.Needs])
end
function Training.currentPage(paid)
 for index,name in Training.Pages do
  if Training.Closed[name] then continue end
  local total,done=0,0
  for _,o in Training.Objectives do
   if Training.pageOf(o)==name and Training.listed(o) then total+=1;if paid[o.Id] then done+=1 end end
  end
  if done<total then return name,index,done,total end
 end
 return nil,#Training.Pages,0,0
end
-- The one task to point a player at (the lobby's tracker, the window's NEXT
-- STEP): the first one left on the current chapter, or nil when every
-- listed task is done.
function Training.nextTask(paid)
 local page=Training.currentPage(paid)
 if not page then return nil end
 for _,o in Training.Objectives do
  if Training.pageOf(o)==page and Training.listed(o) and not paid[o.Id] then return o end
 end
 return nil
end
function Training.state(profile)
 profile.TrainingRewards = profile.TrainingRewards or {Counts={},Paid={},Slots={}}
 local s=profile.TrainingRewards
 s.Counts=s.Counts or {};s.Paid=s.Paid or {};s.Slots=s.Slots or {}
 return s
end
function Training.record(profile,event,detail)
 local s=Training.state(profile)
 if event=="Heavy" then event="Hit" end
 local allowed=false
 for _,o in Training.Objectives do if o.Event==event then allowed=true end end
 if not allowed then return {} end
 if event=="Slot" then
  if not ({Helmet=true,Armor=true,Weapon=true,Shield=true,Gloves=true,Boots=true})[detail] then return {} end
  if s.Slots[detail] then return {},false end
  s.Slots[detail]=true
  local n=0;for _ in s.Slots do n+=1 end;s.Counts.Slot=n
 else
  local cap=1;for _,o in Training.Objectives do if o.Event==event then cap=math.max(cap,o.Goal) end end
  if (s.Counts[event] or 0)>=cap then return {},false end
  s.Counts[event]=math.min(cap,(s.Counts[event] or 0)+1)
 end
 local earned={}
 for _,o in Training.Objectives do
  if (s.Counts[o.Event] or 0)>=o.Goal and not s.Paid[o.Id] then
   s.Paid[o.Id]=true
   profile.Coins=(profile.Coins or 0)+o.Coins
   table.insert(earned,o)
  end
 end
 return earned,true
end
return Training
