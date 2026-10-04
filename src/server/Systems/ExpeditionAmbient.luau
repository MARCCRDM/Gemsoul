-- Ambient behavior runs before the existing rival combat brain.
local Rules = require(game:GetService("ReplicatedStorage").Shared.DungeonRules)
local Ambient = {}
local function setState(duel, value)
	local model = duel.Enemy.Model
	if model:GetAttribute("AmbientState") == value then
		return
	end
	model:SetAttribute("AmbientState", value)
	if not duel.Dungeon.Bandit then
		return
	end
	local mining = value == "Mining"
	if mining and not duel.MiningParts then
		duel.MiningParts = {}
		duel.WeaponParts = {}
		local gear = model:FindFirstChild("GemsoulGear")
		local weapon = gear and gear:FindFirstChild("Weapon")
		if weapon then
			for _, p in weapon:GetDescendants() do
				if p:IsA("BasePart") then
					duel.WeaponParts[p] = p.Transparency
				end
			end
		end
		local hand = model:FindFirstChild("RightHand")
		if hand then
			for _, spec in
				{
					{ Vector3.new(0.16, 2.1, 0.16), CFrame.new(0, -0.6, 0), Color3.fromRGB(62, 66, 74) },
					{ Vector3.new(1.5, 0.2, 0.26), CFrame.new(0, 0.45, 0), Color3.fromRGB(230, 88, 68) },
				}
			do
				local part = Instance.new("Part")
				part.Name = "BanditMiningPick"
				part.Size = spec[1]
				part.Color = spec[3]
				part.Material = Enum.Material.Metal
				part.Massless = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.CFrame = hand.CFrame * spec[2]
				part.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hand
				weld.Part1 = part
				weld.Parent = part
				table.insert(duel.MiningParts, part)
			end
		end
	end
	for _, p in duel.MiningParts or {} do
		p.Transparency = if mining then 0 else 1
	end
	for p, alpha in duel.WeaponParts or {} do
		if p.Parent then
			p.Transparency = if mining then 1 else alpha
		end
	end
end
function Ambient.step(duel, now)
	local encounter, enemy = duel.Dungeon, duel.Enemy
	local root, h = enemy.Root, enemy.Humanoid
	local home = encounter.Spot
	local nearest, distance = nil, math.huge
	local nearestRoot = nil
	local living = 0
	for _, player in duel.Raid.Members do
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local humanoid = c and c:FindFirstChildOfClass("Humanoid")
		if
			player.Parent
			and player:GetAttribute("DungeonId") == enemy.DungeonId
			and r
			and humanoid
			and humanoid.Health > 0
		then
			living += 1
			local d = (r.Position - root.Position).Magnitude
			if d < distance then
				nearest, distance = player, d
				nearestRoot = r
			end
		end
	end
	if encounter.Boss and living < (encounter.MinPlayers or 3) then
		duel.Provoked = false
		duel.Action = nil
		duel.Channel = nil
		setState(duel, "Waiting for squad")
		h:MoveTo(home)
		return true
	end
	local attacked = (enemy.LastHit or 0) > (duel.AmbientHit or 0)
	duel.AmbientHit = enemy.LastHit or 0
	if attacked or (not encounter.Bandit and distance < Rules.AggroRadius) then
		duel.Provoked = true
	end
	if (root.Position - home).Magnitude > Rules.LeashRadius or (duel.Provoked and distance > Rules.LeashRadius) then
		if duel.Provoked then
			h.Health = h.MaxHealth
		end
		duel.Provoked = false
		duel.Action = nil
		duel.Channel = nil
		duel.Zones = {}
		enemy.Model:SetAttribute("ActionKind", nil)
		enemy.Threat = {}
		enemy.ThreatAt = {}
		enemy.Aggro.Target = nil
	end
	if duel.Provoked and nearest then
		setState(duel, "Combat")
		h.WalkSpeed = duel.Speed
		return false
	end
	duel.Action = nil
	enemy.GuardUntil = 0
	enemy.Model:SetAttribute("GuardUntil", 0)
	if nearest and encounter.Bandit and distance <= Rules.WatchRadius then
		h:MoveTo(root.Position)
		local target = nearestRoot.Position
		if (target - root.Position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
		end
		setState(duel, "Watching")
		enemy.Model:SetAttribute("ActionKind", nil)
		duel.AmbientNext = now + 1
		return true
	end
	if (root.Position - home).Magnitude > Rules.LeashRadius * 0.75 then
		h.WalkSpeed = duel.Speed
		h:MoveTo(home)
		setState(duel, "Returning")
		return true
	end
	h.WalkSpeed = 8
	if now >= (duel.AmbientNext or 0) then
		duel.AmbientNext = now + math.random(4, 8)
		duel.AmbientMining = math.random() < 0.6
		local center = encounter.Center
		local angle = math.random() * math.pi * 2
		duel.AmbientGoal = if duel.AmbientMining
			then center + Vector3.new(math.cos(angle) * 9, 3, math.sin(angle) * 9)
			else home + Vector3.new(math.cos(angle) * 18, 0, math.sin(angle) * 18)
		h:MoveTo(duel.AmbientGoal)
	end
	local goal = duel.AmbientGoal or home
	local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
	if flat.Magnitude > 3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		setState(duel, "Roaming")
	else
		setState(duel, if duel.AmbientMining then (if encounter.Bandit then "Mining" else "Feeding") else "Idle")
		if duel.AmbientMining and now >= (duel.AmbientPoseAt or 0) then
			duel.AmbientPoseAt = now + 1.3
			local at = workspace:GetServerTimeNow()
			enemy.Model:SetAttribute("ActionKind", if encounter.Bandit then "Mine" else "Feed")
			enemy.Model:SetAttribute("ActionStart", at)
			enemy.Model:SetAttribute("ActionAt", at + 0.65)
			root.CFrame =
				CFrame.lookAt(root.Position, Vector3.new(encounter.Center.X, root.Position.Y, encounter.Center.Z))
		end
	end
	return true
end
return Ambient
