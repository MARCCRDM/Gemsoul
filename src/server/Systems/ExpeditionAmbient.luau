-- Ambient behavior runs before the existing rival combat brain.
local Rules = require(game:GetService("ReplicatedStorage").Shared.DungeonRules)
local Ambient = {}
function Ambient.step(duel, now)
 local encounter,enemy=duel.Dungeon,duel.Enemy
 local root,h=enemy.Root,enemy.Humanoid
 local home=encounter.Spot
 local nearest,distance=nil,math.huge
 for _,player in duel.Raid.Members do
  local c=player.Character
  local r=c and c:FindFirstChild("HumanoidRootPart")
  local humanoid=c and c:FindFirstChildOfClass("Humanoid")
  if player.Parent and player:GetAttribute("DungeonId")==enemy.DungeonId and r and humanoid and humanoid.Health>0 then
   local d=(r.Position-root.Position).Magnitude
   if d<distance then nearest,distance=player,d end
  end
 end
 local attacked=(enemy.LastHit or 0) > (duel.AmbientHit or 0)
 duel.AmbientHit=enemy.LastHit or 0
 if attacked or (not encounter.Bandit and distance<Rules.AggroRadius) then duel.Provoked=true end
 if (root.Position-home).Magnitude>Rules.LeashRadius or distance>Rules.LeashRadius then
  duel.Provoked=false
  duel.Action=nil
  duel.Channel=nil
  duel.Zones={}
  enemy.Model:SetAttribute("ActionKind",nil)
  enemy.Threat={}; enemy.ThreatAt={}; enemy.Aggro.Target=nil
 end
 if duel.Provoked and nearest then
  enemy.Model:SetAttribute("AmbientState","Combat")
  h.WalkSpeed=duel.Speed
  return false
 end
 duel.Action=nil
 enemy.GuardUntil=0
 enemy.Model:SetAttribute("GuardUntil",0)
 if nearest and encounter.Bandit and distance<=Rules.WatchRadius then
  h:MoveTo(root.Position)
  local target=nearest.Character.HumanoidRootPart.Position
  if (target-root.Position).Magnitude>.1 then root.CFrame=CFrame.lookAt(root.Position,Vector3.new(target.X,root.Position.Y,target.Z)) end
  enemy.Model:SetAttribute("AmbientState","Watching")
  enemy.Model:SetAttribute("ActionKind",nil)
  duel.AmbientNext=now+1
  return true
 end
 if (root.Position-home).Magnitude>Rules.LeashRadius*.75 then
  h.WalkSpeed=duel.Speed
  h:MoveTo(home)
  enemy.Model:SetAttribute("AmbientState","Returning")
  return true
 end
 h.WalkSpeed=8
 if now>=(duel.AmbientNext or 0) then
  duel.AmbientNext=now+math.random(4,8)
  duel.AmbientMining=math.random()<.6
  local center=encounter.Center
  local angle=math.random()*math.pi*2
  duel.AmbientGoal=if duel.AmbientMining then center+Vector3.new(math.cos(angle)*9,3,math.sin(angle)*9) else home+Vector3.new(math.cos(angle)*18,0,math.sin(angle)*18)
  h:MoveTo(duel.AmbientGoal)
 end
 local goal=duel.AmbientGoal or home
 local flat=Vector3.new(goal.X-root.Position.X,0,goal.Z-root.Position.Z)
 if flat.Magnitude>3 then
  root.CFrame=CFrame.lookAt(root.Position,root.Position+flat)
  enemy.Model:SetAttribute("AmbientState","Roaming")
 else
  enemy.Model:SetAttribute("AmbientState",if duel.AmbientMining then (if encounter.Bandit then "Mining" else "Feeding") else "Idle")
  if duel.AmbientMining and now>=(duel.AmbientPoseAt or 0) then
   duel.AmbientPoseAt=now+1.3
   local at=workspace:GetServerTimeNow()
   enemy.Model:SetAttribute("ActionKind",if encounter.Bandit then "Mine" else "Feed")
   enemy.Model:SetAttribute("ActionStart",at)
   enemy.Model:SetAttribute("ActionAt",at+.65)
   root.CFrame=CFrame.lookAt(root.Position,Vector3.new(encounter.Center.X,root.Position.Y,encounter.Center.Z))
  end
 end
 return true
end
return Ambient
