-- Pure account-persistent training objectives. No client supplies completion or payouts.
local Training = {}
Training.Objectives = {
 {Id="FirstRock",Category="Mining",Event="Mine",Goal=1,Coins=25,Name="First discovery",Hint="Break a rock in the Outpost. Click, tap or press E for each swing."},
 {Id="ThreeRocks",Category="Mining",Event="Mine",Goal=3,Coins=35,Name="Keep digging",Hint="Break three Outpost rocks. Every discovery can improve your build."},
 {Id="Enchant",Category="Equipment",Event="Enchant",Goal=1,Coins=25,Name="Power up your gear",Hint="Drag a gem onto an equipment socket in Inventory."},
 {Id="ThreeSlots",Category="Equipment",Event="Slot",Goal=3,Coins=50,Name="Build your loadout",Hint="Enchant three different equipment slots. Repeating one slot does not count."},
 {Id="EquipSurge",Category="Equipment",Event="EquipSurge",Goal=1,Coins=20,Name="Ready a Surge",Hint="Move a gem into Q, E or R in Inventory. It can occupy only one slot."},
 {Id="Attack",Category="Combat",Event="Hit",Goal=1,Coins=20,Name="Make contact",Hint="Land a light or heavy weapon attack on an enemy."},
 {Id="Guard",Category="Combat",Event="Block",Goal=1,Coins=35,Name="Stand your ground",Hint="Face an enemy and hold Guard to absorb an incoming hit."},
 {Id="Cast",Category="Combat",Event="Surge",Goal=1,Coins=30,Name="Unleash your gem",Hint="Build Charge in combat, then successfully cast an equipped Surge."},
 {Id="Rival",Category="Combat",Event="RivalWin",Goal=1,Coins=50,Name="First Rival victory",Hint="Defeat a Rival in practice or the Arena. No player opponent required."},
 {Id="GemFind",Category="Mining",Event="MineGem",Goal=1,Coins=25,Name="Something inside",Hint="Mine a rock that drops a gem. Check its element and ability in Inventory."},
 {Id="RareFind",Category="Mining",Event="RareGem",Goal=1,Coins=60,Name="A rare discovery",Hint="Mine a Rare or better gem. Starter gifts and purchases do not count."},
 {Id="LegendFind",Category="Mining",Event="LegendGem",Goal=1,Coins=150,Name="Struck legendary",Hint="Discover a Legendary gem while mining. This is an optional long-term milestone."},
 {Id="TimedGuard",Category="Combat",Event="TimedBlock",Goal=1,Coins=40,Name="Perfect timing",Hint="Raise your shield just before a hit to perform a timed block."},
 {Id="PvPPlayed",Category="PvP",Event="PvPPlayed",Goal=1,Coins=40,Name="Enter the arena",Hint="Finish a player-versus-player 1v1 match. Winning is optional."},
 {Id="PvPWin",Category="PvP",Event="PvPWin",Goal=1,Coins=100,Name="First challenger defeated",Hint="Win a player-versus-player 1v1 match."},
 {Id="Boss",Category="PvE",Event="Boss",Goal=1,Coins=125,Name="Bring down a boss",Hint="Be alive with your party when a dungeon boss falls. Developer test runs do not count."},
 {Id="DungeonComplete",Category="PvE",Event="DungeonComplete",Goal=1,Coins=100,Name="Extraction complete",Hint="Finish a real dungeon run alive and collect your completion reward."},
 {Id="MarketBuy",Category="Market",Event="MarketBuy",Goal=1,Coins=35,Name="Find your upgrade",Hint="Complete a purchase from another player on the Market."},
 {Id="MarketSale",Category="Market",Event="MarketSale",Goal=1,Coins=75,Name="Open for business",Hint="Sell an item to another player. Earn this when the sale payment arrives."},
}
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
