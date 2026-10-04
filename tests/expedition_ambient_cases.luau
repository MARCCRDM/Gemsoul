
CFrame.lookAt=function(at,target) return {Position=at,Target=target} end
local party=squad(3)
for _,p in party do p:SetAttribute("DungeonId","ambient");p.Root.Position=Vector3.new(100,0,0) end
local attrs={}
local model={GetAttribute=function(_,k) return attrs[k] end,SetAttribute=function(_,k,v) attrs[k]=v end}
local enemy={Root={Position=Vector3.new(0,0,0)},Humanoid={Health=50,MaxHealth=100,MoveTo=function(self,goal) self.Goal=goal end},Model=model,DungeonId="ambient",LastHit=0,Threat={},ThreatAt={},Aggro={}}
local duel={Enemy=enemy,Raid={Members=party},Dungeon={Spot=Vector3.new(0,0,0),Center=Vector3.new(0,0,-9),Bandit=true},Speed=18,MiningParts={},WeaponParts={}}
party[1].Root.Position=Vector3.new(8,0,0)
check(Ambient.step(duel,10) and attrs.AmbientState=="Watching" and not duel.Provoked,"Neutral bandit attacked nearby player")
party[1].Root.Position=Vector3.new(20,0,0)
duel.AmbientNext=100;duel.AmbientGoal=enemy.Root.Position;duel.AmbientMining=true
check(Ambient.step(duel,12) and attrs.AmbientState=="Mining" and attrs.ActionKind=="Mine","Bandit failed to resume mining")
enemy.LastHit=13
check(not Ambient.step(duel,13) and duel.Provoked,"Bandit did not retaliate")
party[1].Root.Position=Vector3.new(100,0,0)
check(Ambient.step(duel,14) and not duel.Provoked and enemy.Humanoid.Health==100,"Leash failed to reset combat")
duel.Dungeon.Bandit=false;party[1].Root.Position=Vector3.new(20,0,0)
check(not Ambient.step(duel,15),"Monster failed proximity aggression")
party[1].Root.Position=Vector3.new(100,0,0);Ambient.step(duel,16)
duel.AmbientNext=100;duel.AmbientGoal=enemy.Root.Position;duel.AmbientMining=true
check(Ambient.step(duel,17) and attrs.AmbientState=="Feeding" and attrs.ActionKind=="Feed","Monster feeding animation missing")
duel.Dungeon.Boss=true;duel.Dungeon.MinPlayers=3
party[2].Humanoid.Health=0;party[1].Root.Position=Vector3.new(20,0,0)
check(Ambient.step(duel,18) and attrs.AmbientState=="Waiting for squad","Boss activated below squad minimum")
party[2].Humanoid.Health=100
check(not Ambient.step(duel,19),"Boss did not activate for living trio")
print("PASS: neutral watching, return to mining, retaliation, leash reset, hostile proximity, feeding poses and boss squad minimum")
