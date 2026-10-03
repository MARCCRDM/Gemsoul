local profiles={}
local PlayerData={character=function(player) return profiles[player] and profiles[player].Character end,get=function(player) return profiles[player] end}
local function makePlayer(id,position,family)
	local player={UserId=id,Neutral=true,Attributes={},CharacterAdded=signal()}
	function player:GetAttribute(key) return self.Attributes[key] end
	function player:SetAttribute(key,value) self.Attributes[key]=value end
	function player:RequestStreamAroundAsync() end
	local root={Position=position,Size=Vector3.new(2,2,1),Parent=true,AssemblyLinearVelocity=Vector3.zero,AssemblyMass=1,CFrame={LookVector=Vector3.new(0,0,-1),RightVector=Vector3.new(1,0,0)}}
	function root:ApplyImpulse(impulse) self.Impulse=impulse end
	function root:SetNetworkOwner(owner) self.ServerOwned=owner==nil end
	function root:SetNetworkOwnershipAuto() self.ServerOwned=false end
	local humanoid={Health=1000,MaxHealth=1000,WalkSpeed=16}
	function humanoid:TakeDamage(damage) self.Health=math.max(0,self.Health-damage) end
	player.Character={HumanoidRootPart=root,FindFirstChild=function(_,key) return if key=="HumanoidRootPart" then root else nil end,FindFirstChildOfClass=function(_,key) return if key=="Humanoid" then humanoid elseif key=="ForceField" and player.Protected then {} else nil end}
	function player.Character:PivotTo(target) root.Position=target.Position or Vector3.new(0,6,0) end
	player.Character.Attributes={}
	function player.Character:GetAttribute(key) return self.Attributes[key] end
	function player.Character:SetAttribute(key,value) self.Attributes[key]=value end
	local loadout={Class="Warrior",Weapon="MatrixSwords1",Armor="MinerBulk",GearRolls={}}
	if family then
		for _,slot in ArmorFamilies.Slots do loadout[slot]="Armor"..family..slot.."1" end
		for _,weapon in ExpandedTraits.Catalog.Weapons do if weapon.ArmorFamily==family then loadout.Weapon=weapon.Id; break end end
	end
	profiles[player]={Character=loadout}
	player:SetAttribute("PvPEnabled",true)
	table.insert(playerList,player)
	return player,humanoid,root,loadout
end
