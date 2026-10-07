-- Sequential orbital insertion. Server owns staging and combat protection.
local Players = game:GetService("Players")
local Motion = require(game:GetService("ReplicatedStorage").Shared.InsertionMotion)
local Drop = {}
local active = setmetatable({}, { __mode = "k" })
-- Onboarding and repeat Arena rivals use the same insertion sequence.
-- Cooperative encounters batch their actors through encounter() below.
function Drop.forRival(session, raid, encounter)
	return (session == "PvP" or session == "Training") and not raid and not encounter
end
function Drop.duration(count)
	return Motion.duration(count)
end
local function colorOf(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
			return p.Color
		end
	end
	return Color3.fromRGB(70, 220, 255)
end
-- What a hidden part goes back to. Its InsertionTransparency attribute is the
-- record: other systems that show or hide gear while it's staged (the Outpost
-- brings the weapon back out for a fight) update that, not Transparency, so
-- the reveal never restores a stale value (a duel from the Outpost used to
-- leave both fighters' swords invisible).
local function restored(object, saved)
	local value = object:GetAttribute("InsertionTransparency")
	return if type(value) == "number" then value else saved
end
function Drop.cancel(model)
	local finish = active[model]
	if finish then
		finish()
	end
end
-- Names/health bars are presentation too: geometry transparency does not hide them.
local function concealLabels(model)
	local saved = {}
	local function hide(object)
		if object:IsA("BillboardGui") then
			saved[object] = object.Enabled
			object.Enabled = false
		end
	end
	for _, object in model:GetDescendants() do
		hide(object)
	end
	local connection = model.DescendantAdded:Connect(hide)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local nameDistance = humanoid and humanoid.NameDisplayDistance
	local healthDistance = humanoid and humanoid.HealthDisplayDistance
	if humanoid then
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
	end
	return function()
		connection:Disconnect()
		for object, value in saved do
			if object.Parent then
				object.Enabled = value
			end
		end
		if humanoid and humanoid.Parent then
			if nameDistance ~= nil then
				humanoid.NameDisplayDistance = nameDistance
			end
			if healthDistance ~= nil then
				humanoid.HealthDisplayDistance = healthDistance
			end
		end
	end
end
-- Cover and hide before a teleport or asynchronous rival build, not after it.
function Drop.prepare(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	Drop.cancel(model)
	local restoreLabels = concealLabels(model)
	local anchored = root.Anchored
	root.Anchored = true
	local saved, effects, connections = {}, {}, {}
	local deadline = workspace:GetServerTimeNow() + 15
	player:SetAttribute("ArenaDropPreparing", deadline)
	player:SetAttribute("ArenaDropUntil", deadline)
	model:SetAttribute("ArenaDropUntil", deadline)
	local function hide(object)
		if object:IsA("BasePart") or object:IsA("Decal") then
			saved[object] = object.Transparency
			object:SetAttribute("InsertionTransparency", object.Transparency)
			object.Transparency = 1
		elseif object:IsA("ParticleEmitter") or object:IsA("Trail") then
			effects[object] = object.Enabled
			object:SetAttribute("InsertionEnabled", object.Enabled)
			object.Enabled = false
		end
	end
	for _, object in model:GetDescendants() do
		hide(object)
	end
	table.insert(connections, model.DescendantAdded:Connect(hide))
	local finished = false
	local function cleanup()
		if finished then
			return
		end
		finished = true
		restoreLabels()
		for _, connection in connections do
			connection:Disconnect()
		end
		for object, value in saved do
			if object.Parent then
				object.Transparency = restored(object, value)
				object:SetAttribute("InsertionTransparency", nil)
			end
		end
		for object, value in effects do
			if object.Parent then
				object.Enabled = value
				object:SetAttribute("InsertionEnabled", nil)
			end
		end
		if root.Parent then
			root.Anchored = anchored
		end
		model:SetAttribute("ArenaDropUntil", nil)
		if player:GetAttribute("ArenaDropPreparing") == deadline then
			player:SetAttribute("ArenaDropPreparing", nil)
		end
		if player:GetAttribute("ArenaDropUntil") == deadline then
			player:SetAttribute("ArenaDropUntil", nil)
		end
		active[model] = nil
	end
	active[model] = cleanup
	table.insert(
		connections,
		model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				cleanup()
			end
		end)
	)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(connections, humanoid.Died:Connect(cleanup))
	end
	task.delay(15, cleanup)
end
function Drop.begin(models, viewers, dropModels, sides)
	local RunService = game:GetService("RunService")
	local order = table.clone(dropModels or models)
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	local duration = Drop.duration(#order)
	local began = workspace:GetServerTimeNow()
	local ends = began + duration
	local positions = {}
	local middle = Vector3.zero
	local count = 0
	for _, model in models do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			positions[model] = root.Position
			middle += root.Position
			count += 1
		end
	end
	if count == 0 then
		return 0
	end
	middle /= count
	for _, model in models do
		Drop.cancel(model)
	end
	local cleanups, states = {}, {}
	for _, model in models do
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		-- Aim at opposing fighters, not the arena center or a stale spawn rotation.
		local owner = Players:GetPlayerFromCharacter(model)
		local team = if sides then sides[model] else owner and owner:GetAttribute("MatchTeam")
		local target, targets = Vector3.zero, 0
		for _, other in models do
			local otherRoot = other:FindFirstChild("HumanoidRootPart")
			local otherOwner = Players:GetPlayerFromCharacter(other)
			local otherTeam = if sides then sides[other] else otherOwner and otherOwner:GetAttribute("MatchTeam")
			local sameTeam = team ~= nil and otherTeam == team
			if other ~= model and otherRoot and not sameTeam then
				target += positions[other]
				targets += 1
			end
		end
		if targets > 0 then
			target /= targets
			target = Vector3.new(target.X, root.Position.Y, target.Z)
			if (target - root.Position).Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, target)
			end
		end
		local restoreLabels = concealLabels(model)
		local anchored = root.Anchored
		root.Anchored = true
		model:SetAttribute("ActionKind", nil)
		model:SetAttribute("GuardUntil", 0)
		root.AssemblyLinearVelocity = Vector3.zero
		model:SetAttribute("ArenaDropUntil", ends)
		local saved, effects = {}, {}
		local slot = table.find(order, model)
		local dropping = slot ~= nil
		local destination = root.CFrame
		local landing = if dropping then destination * CFrame.new(0, 0, Motion.ExitDistance) else destination
		model:SetAttribute("ArenaDropOrigin", landing)
		model:SetAttribute("ArenaDropReleaseDelay", if slot then Motion.releaseDelay(slot, #order) else 0)
		if dropping then
			root.CFrame = landing
		end
		model:SetAttribute("ArenaDropStart", if slot then began + Motion.Lead + (slot - 1) * Motion.Spacing else nil)
		if dropping then
			for _, object in model:GetDescendants() do
				if object:IsA("BasePart") or object:IsA("Decal") then
					saved[object] = object.Transparency
					object:SetAttribute("InsertionTransparency", object.Transparency)
					object.Transparency = 1
				elseif object:IsA("ParticleEmitter") or object:IsA("Trail") then
					effects[object] = object.Enabled
					object:SetAttribute("InsertionEnabled", object.Enabled)
					object.Enabled = false
				end
			end
		end
		local function reveal()
			for object, value in saved do
				if object.Parent then
					object.Transparency = restored(object, value)
					object:SetAttribute("InsertionTransparency", nil)
				end
			end
			for object, value in effects do
				if object.Parent then
					object.Enabled = value
					object:SetAttribute("InsertionEnabled", nil)
				end
			end
			-- Once: the clean-up reveals again, and by then the record is gone.
			table.clear(saved)
			table.clear(effects)
		end
		local finished = false
		local connections = {}
		local resources = {}
		local cleanup
		cleanup = function(normalFinish)
			if finished then
				return
			end
			finished = true
			restoreLabels()
			for _, object in resources do
				if normalFinish == true and object:GetAttribute("InsertionResidual") then
					task.delay(Motion.SmokeAfter, function()
						object:Destroy()
					end)
				else
					object:Destroy()
				end
			end
			for _, connection in connections do
				connection:Disconnect()
			end
			reveal()
			if root.Parent then
				root.CFrame = destination
				root.Anchored = anchored
			end
			model:SetAttribute("ArenaDropUntil", nil)
			model:SetAttribute("ArenaDropStart", nil)
			model:SetAttribute("ArenaDropOrigin", nil)
			model:SetAttribute("ArenaDropReleaseDelay", nil)
			active[model] = nil
			local owner = Players:GetPlayerFromCharacter(model)
			if owner and owner:GetAttribute("ArenaDropUntil") == ends then
				owner:SetAttribute("ArenaDropUntil", nil)
			end
		end
		active[model] = cleanup
		table.insert(
			connections,
			model.AncestryChanged:Connect(function(_, parent)
				if not parent then
					cleanup()
				end
			end)
		)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(connections, humanoid.Died:Connect(cleanup))
		end
		local owner = Players:GetPlayerFromCharacter(model)
		if owner then
			local session = owner:GetAttribute("CombatSession")
			table.insert(
				connections,
				owner:GetAttributeChangedSignal("CombatSession"):Connect(function()
					if owner:GetAttribute("CombatSession") ~= session then
						cleanup()
					end
				end)
			)
		end
		states[model] = {
			Root = root,
			Resources = resources,
			Connections = connections,
			Reveal = reveal,
			Valid = function()
				return not finished and model.Parent ~= nil
			end,
		}
		table.insert(cleanups, cleanup)
	end

	for _, model in order do
		local state = states[model]
		if not state then
			continue
		end
		local start = model:GetAttribute("ArenaDropStart")
		local origin = model:GetAttribute("ArenaDropOrigin")
		local releaseDelay = model:GetAttribute("ArenaDropReleaseDelay") or 0
		local marker = Instance.new("Folder")
		marker.Name = "OrbitalInsertion"
		marker:SetAttribute("Start", start)
		marker:SetAttribute("Origin", origin)
		marker:SetAttribute("ReleaseDelay", releaseDelay)
		marker:SetAttribute("Tint", colorOf(model))
		marker:SetAttribute("Scale", math.clamp(model:GetScale(), 0.5, 3))
		marker:SetAttribute("Ends", ends)
		marker:SetAttribute("InsertionResidual", true)
		local actor = Instance.new("ObjectValue")
		actor.Name, actor.Value, actor.Parent = "Actor", model, marker
		marker.Parent = workspace
		table.insert(state.Resources, marker)
		local revealed = false
		-- Only authoritative staging moves on the server. All visual motion is local.
		table.insert(
			state.Connections,
			RunService.Heartbeat:Connect(function()
				if not state.Valid() then
					return
				end
				local now = workspace:GetServerTimeNow()
				local t = now - start
				if t >= Motion.Exit + releaseDelay then
					state.Root.CFrame = origin * CFrame.new(0, 0, -Motion.sample(t, releaseDelay).Step)
					if not revealed then
						revealed = true
						state.Reveal()
						model:SetAttribute("ActionKind", "Deploy")
						model:SetAttribute("ActionStart", start + Motion.Exit + releaseDelay)
						model:SetAttribute("ActionAt", start + Motion.Exit + releaseDelay + 0.35)
						local outline = Instance.new("Highlight")
						outline.Name, outline.Adornee = "InsertionSilhouette", model
						outline.FillColor, outline.OutlineColor = colorOf(model), colorOf(model)
						outline.FillTransparency, outline.OutlineTransparency = 0.55, 0.05
						outline.DepthMode = Enum.HighlightDepthMode.Occluded
						outline:SetAttribute("InsertionResidual", true)
						outline.Parent = model
						table.insert(state.Resources, outline)
					end
				end
			end)
		)
	end

	-- Publish the camera trigger after actor metadata and pod markers exist.
	for _, viewer in viewers do
		viewer:SetAttribute("ArenaDropFocus", middle)
		viewer:SetAttribute("ArenaDropUntil", ends)
	end

	task.delay(duration, function()
		for _, cleanup in cleanups do
			cleanup(true)
		end
		for _, viewer in viewers do
			if viewer:GetAttribute("ArenaDropUntil") == ends then
				viewer:SetAttribute("ArenaDropUntil", nil)
			end
		end
	end)
	return duration
end
-- One shared timeline per encounter. Survivors watch the next wave from the
-- ground; ambient open-world arrivals never seize the squad's camera/input.
function Drop.encounter(members, foes, includeParty, background, groundedFoes)
	local actors, viewers, drops, sides = {}, {}, {}, {}
	if not background then
		for _, member in members do
			local model = member.Character
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			if member.Parent and model and model.Parent and humanoid and humanoid.Health > 0 then
				table.insert(actors, model)
				table.insert(viewers, member)
				sides[model] = 1
				if includeParty then
					table.insert(drops, model)
				end
			end
		end
	end
	for _, model in foes do
		if model.Parent and model:FindFirstChild("HumanoidRootPart") then
			table.insert(actors, model)
			-- Dungeon defenders are already present. Pause their AI during the
			-- squad's arrival, without hiding them or giving them a pod.
			if not groundedFoes then
				table.insert(drops, model)
			end
			sides[model] = 2
		end
	end
	if #drops == 0 then
		return 0
	end
	return Drop.begin(actors, viewers, drops, sides)
end
return Drop
