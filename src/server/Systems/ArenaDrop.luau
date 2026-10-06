-- Sequential orbital insertion. Server owns staging and combat protection.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Drop = {}
local active = setmetatable({}, { __mode = "k" })
-- Onboarding and repeat Arena rivals use the same insertion sequence.
-- Dungeon and raid encounters retain their own spawning flow.
function Drop.forRival(session, raid, encounter)
	return (session == "PvP" or session == "Training") and not raid and not encounter
end
function Drop.duration(count)
	return 1 + count * 2.6
end
local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Color, p.Material = color, material or Enum.Material.Metal
	p.Parent = parent
	return p
end
local function colorOf(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
			return p.Color
		end
	end
	return Color3.fromRGB(70, 220, 255)
end
function Drop.cancel(model)
	local finish = active[model]
	if finish then
		finish()
	end
end
function Drop.begin(models, viewers, dropModels)
	local TweenService = game:GetService("TweenService")
	local order = table.clone(dropModels or models)
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	local duration = Drop.duration(#order)
	local ends = workspace:GetServerTimeNow() + duration
	local middle = Vector3.zero
	local count = 0
	for _, model in models do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			middle += root.Position
			count += 1
		end
	end
	if count == 0 then
		return 0
	end
	middle /= count
	for _, viewer in viewers do
		viewer:SetAttribute("ArenaDropFocus", middle)
		viewer:SetAttribute("ArenaDropUntil", ends)
	end
	local cleanups, states = {}, {}
	for _, model in models do
		Drop.cancel(model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local anchored = root.Anchored
		root.Anchored = true
		model:SetAttribute("ActionKind", nil)
		model:SetAttribute("GuardUntil", 0)
		root.AssemblyLinearVelocity = Vector3.zero
		model:SetAttribute("ArenaDropUntil", ends)
		local saved, effects = {}, {}
		local slot = table.find(order, model)
		local dropping = slot ~= nil
		model:SetAttribute("ArenaDropStart", if slot then ends - duration + 0.25 + (slot - 1) * 2.6 else nil)
		if dropping then
			for _, object in model:GetDescendants() do
				if object:IsA("BasePart") or object:IsA("Decal") then
					saved[object] = object.Transparency
					object.Transparency = 1
				elseif object:IsA("ParticleEmitter") or object:IsA("Trail") then
					effects[object] = object.Enabled
					object.Enabled = false
				end
			end
		end
		local function reveal()
			for object, value in saved do
				if object.Parent then
					object.Transparency = value
				end
			end
			for object, value in effects do
				if object.Parent then
					object.Enabled = value
				end
			end
		end
		local finished = false
		local connections = {}
		local resources, movements = {}, {}
		local cleanup
		cleanup = function()
			if finished then
				return
			end
			finished = true
			for _, tween in movements do
				tween:Cancel()
			end
			for _, object in resources do
				object:Destroy()
			end
			for _, connection in connections do
				connection:Disconnect()
			end
			reveal()
			if root.Parent then
				root.Anchored = anchored
			end
			model:SetAttribute("ArenaDropUntil", nil)
			model:SetAttribute("ArenaDropStart", nil)
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
			Movements = movements,
			Reveal = reveal,
			Valid = function()
				return not finished and model.Parent ~= nil
			end,
		}
		table.insert(cleanups, cleanup)
	end
	for index, model in order do
		local state = states[model]
		if not state then
			continue
		end
		task.delay(0.25 + (index - 1) * 2.6, function()
			if not state.Valid() then
				return
			end
			local color = colorOf(model)
			local pod = Instance.new("Model")
			pod.Name = "OrbitalInsertionPod"
			pod.Parent = workspace
			table.insert(state.Resources, pod)
			Debris:AddItem(pod, 9)
			local floor = state.Root.CFrame * CFrame.new(0, -3, 0)
			local pieces = {}
			local function panel(name, size, offset, tint, mat)
				local target = floor * offset
				local p = part(pod, name, size, target + Vector3.new(0, 100, 0), tint, mat)
				table.insert(pieces, { p, target })
				return p
			end
			local steel = Color3.fromRGB(37, 45, 55)
			panel("ArmoredBase", Vector3.new(5.6, 0.7, 5), CFrame.new(0, 0, 0), steel)
			panel("RearArmor", Vector3.new(5, 7.5, 0.65), CFrame.new(0, 4, 2), steel)
			for _, side in { -1, 1 } do
				panel(
					"FlaredSide",
					Vector3.new(0.8, 7.6, 4.5),
					CFrame.new(side * 2.4, 4, 0) * CFrame.Angles(0, 0, side * -0.08),
					steel
				)
				panel(
					"EntryLight",
					Vector3.new(0.12, 5.8, 0.14),
					CFrame.new(side * 1.9, 4, -2.25),
					color,
					Enum.Material.Neon
				)
			end
			panel("Roof", Vector3.new(4.5, 0.7, 4.6), CFrame.new(0, 8, 0), steel)
			-- Reinforced spine, tapered shoulder armor, recessed vents and landing skids.
			for _, side in { -1, 1 } do
				panel(
					"LandingSkid",
					Vector3.new(0.8, 0.55, 6),
					CFrame.new(side * 2.65, -0.15, 0.2),
					Color3.fromRGB(22, 27, 33)
				)
				panel(
					"ShoulderArmor",
					Vector3.new(0.7, 2.3, 4.2),
					CFrame.new(side * 2.05, 7.5, 0) * CFrame.Angles(0, 0, side * 0.32),
					steel
				)
				panel(
					"HeatShieldRib",
					Vector3.new(0.35, 6.7, 0.7),
					CFrame.new(side * 2.65, 3.7, 1.6),
					Color3.fromRGB(65, 72, 82)
				)
				for vent = 1, 4 do
					panel(
						"RecessedVent",
						Vector3.new(0.15, 0.16, 1.1),
						CFrame.new(side * 2.87, 2.4 + vent * 0.43, 0.5),
						Color3.fromRGB(9, 14, 20)
					)
				end
			end
			panel("ArmoredSpine", Vector3.new(1.1, 8, 0.85), CFrame.new(0, 4, 2.6), Color3.fromRGB(25, 31, 39))
			panel("HatchHeader", Vector3.new(4.2, 0.45, 0.75), CFrame.new(0, 7.65, -2.3), Color3.fromRGB(110, 120, 130))
			local door =
				panel("ExplosiveHatch", Vector3.new(4.2, 7, 0.5), CFrame.new(0, 4, -2.3), Color3.fromRGB(65, 73, 80))
			for _, entry in pieces do
				TweenService:Create(
					entry[1],
					TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ CFrame = entry[2] }
				):Play()
			end
			task.wait(0.72)
			if not state.Valid() then
				pod:Destroy()
				return
			end
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Color = ColorSequence.new(Color3.fromRGB(85, 95, 110), Color3.fromRGB(35, 42, 52))
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 11) })
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime, emitter.Speed = NumberRange.new(1.8, 3), NumberRange.new(8, 15)
			emitter.SpreadAngle, emitter.Rate = Vector2.new(160, 70), 0
			emitter.Parent = pieces[1][1]
			emitter:Emit(45)
			local flash = Instance.new("PointLight")
			flash.Color, flash.Brightness, flash.Range = Color3.fromRGB(255, 170, 65), 5, 22
			flash.Parent = pieces[1][1]
			TweenService:Create(flash, TweenInfo.new(0.3), { Brightness = 0 }):Play()
			local dust = part(
				pod,
				"ImpactDust",
				Vector3.new(0.12, 3, 3),
				floor * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(110, 115, 125),
				Enum.Material.SmoothPlastic
			)
			dust.Shape, dust.Transparency = Enum.PartType.Cylinder, 0.6
			TweenService:Create(
				dust,
				TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(0.08, 22, 22), Transparency = 1 }
			):Play()
			local impact = Instance.new("Sound")
			impact.SoundId, impact.Volume, impact.PlaybackSpeed = "rbxasset://sounds/action_jump_land.mp3", 1, 0.55
			impact.RollOffMaxDistance = 150
			impact.Parent = pieces[1][1]
			impact:Play()
			task.wait(0.38)
			if not state.Valid() then
				pod:Destroy()
				return
			end
			TweenService:Create(
				door,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = door.CFrame * CFrame.new(0, 1, -7) * CFrame.Angles(-1.4, 0, 0.3), Transparency = 1 }
			):Play()
			emitter:Emit(20)
			state.Reveal()
			model:SetAttribute("ActionKind", "Deploy")
			model:SetAttribute("ActionStart", workspace:GetServerTimeNow())
			model:SetAttribute("ActionAt", workspace:GetServerTimeNow() + 0.35)
			local outline = Instance.new("Highlight")
			outline.Name, outline.Adornee = "InsertionSilhouette", model
			outline.FillColor, outline.OutlineColor = color, color
			outline.FillTransparency, outline.OutlineTransparency = 0.82, 0
			outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			outline.Parent = model
			table.insert(state.Resources, outline)
			Debris:AddItem(outline, math.max(0.1, ends - workspace:GetServerTimeNow()) + 0.25)
			-- Step through the cleared hatch. Anchoring makes the entrance deterministic.
			local step = TweenService:Create(
				state.Root,
				TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ CFrame = state.Root.CFrame * CFrame.new(0, 0, -3) }
			)
			table.insert(state.Movements, step)
			step:Play()
			task.delay(2.5, function()
				if not pod.Parent then
					return
				end
				for _, entry in pieces do
					TweenService:Create(entry[1], TweenInfo.new(0.7), { Transparency = 1 }):Play()
				end
			end)
		end)
	end
	task.delay(duration, function()
		for _, cleanup in cleanups do
			cleanup()
		end
		for _, viewer in viewers do
			if viewer:GetAttribute("ArenaDropUntil") == ends then
				viewer:SetAttribute("ArenaDropUntil", nil)
			end
		end
	end)
	return duration
end
return Drop
