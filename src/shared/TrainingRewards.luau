-- Pure account-persistent training objectives. No client supplies completion or payouts.
local Training = {}
Training.Objectives = {
 {Id="FirstRock",Event="Mine",Goal=1,Coins=25,Name="First discovery",Hint="Break a rock in the Outpost. Click, tap or press E for each swing."},
 {Id="ThreeRocks",Event="Mine",Goal=3,Coins=35,Name="Keep digging",Hint="Break three Outpost rocks. Every discovery can improve your build."},
 {Id="Enchant",Event="Enchant",Goal=1,Coins=25,Name="Power up your gear",Hint="Drag a gem onto an equipment socket in Inventory."},
 {Id="ThreeSlots",Event="Slot",Goal=3,Coins=50,Name="Build your loadout",Hint="Enchant three different equipment slots. Repeating one slot does not count."},
 {Id="EquipSurge",Event="EquipSurge",Goal=1,Coins=20,Name="Ready a Surge",Hint="Move a gem into Q, E or R in Inventory. It can occupy only one slot."},
 {Id="Attack",Event="Hit",Goal=1,Coins=20,Name="Make contact",Hint="Land a light or heavy weapon attack on an enemy."},
 {Id="Guard",Event="Block",Goal=1,Coins=35,Name="Stand your ground",Hint="Face an enemy and hold Guard to absorb an incoming hit."},
 {Id="Cast",Event="Surge",Goal=1,Coins=30,Name="Unleash your gem",Hint="Build Charge in combat, then successfully cast an equipped Surge."},
 {Id="Rival",Event="RivalWin",Goal=1,Coins=50,Name="First Rival victory",Hint="Defeat a Rival in practice or the Arena. No player opponent required."},
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
