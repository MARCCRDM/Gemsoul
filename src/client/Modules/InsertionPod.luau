-- Local cosmetic pods: no replicated part tweens compete with helmet movement.
local Motion = require(game:GetService("ReplicatedStorage").Shared.InsertionMotion)
local Pod = {}
function Pod.new(marker)
	local model = Instance.new("Model")
	model.Name = "InsertionPresentation"
	local pieces = {}
	local color = marker:GetAttribute("Tint") or Color3.fromRGB(70, 220, 255)
	local function panel(name, size, offset, tint, material)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, tint
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Material = material or Enum.Material.Metal
		p.CFrame = CFrame.new(0, -10000, 0)
		p.Parent = model
		table.insert(
			pieces,
			{ Part = p, Offset = offset, Hatch = string.find(name, "Hatch") ~= nil and name ~= "HatchHeader" }
		)
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
		panel("EntryLight", Vector3.new(0.12, 5.8, 0.14), CFrame.new(side * 1.9, 4, -2.25), color, Enum.Material.Neon)
	end
	panel("Roof", Vector3.new(4.5, 0.7, 4.6), CFrame.new(0, 8, 0), steel)
	-- Reinforced spine, tapered shoulder armor, recessed vents and landing skids.
	for _, side in { -1, 1 } do
		panel("LandingSkid", Vector3.new(0.8, 0.55, 6), CFrame.new(side * 2.65, -0.15, 0.2), Color3.fromRGB(22, 27, 33))
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
		panel("ExplosiveHatch", Vector3.new(4.2, 3.6, 0.5), CFrame.new(0, 2.3, -2.3), Color3.fromRGB(65, 73, 80))
	panel("HatchCrown", Vector3.new(4.2, 2.4, 0.5), CFrame.new(0, 6, -2.3), steel)
	panel("HatchLeft", Vector3.new(0.5, 0.7, 0.5), CFrame.new(-1.85, 4.45, -2.3), steel)
	panel("HatchRight", Vector3.new(0.5, 0.7, 0.5), CFrame.new(1.85, 4.45, -2.3), steel)
	local glass =
		panel("HatchWindow", Vector3.new(3.2, 0.7, 0.12), CFrame.new(0, 4.45, -2.3), color, Enum.Material.Glass)
	glass.Transparency = 0.72
	for _, side in { -1, 1 } do
		panel(
			"HatchLock",
			Vector3.new(0.45, 0.5, 0.18),
			CFrame.new(side * 1.3, 3.7, -2.65),
			Color3.fromRGB(255, 178, 65),
			Enum.Material.Neon
		)
		panel(
			"InteriorRail",
			Vector3.new(0.13, 3, 0.16),
			CFrame.new(side * 1.55, 3.6, -1.85),
			Color3.fromRGB(110, 125, 140)
		)
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(95, 110, 125), Color3.fromRGB(40, 49, 60))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(0.4, 9),
		NumberSequenceKeypoint.new(1, 14),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(0.55, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime, emitter.Speed = NumberRange.new(5, 6), NumberRange.new(2, 4)
	emitter.SpreadAngle, emitter.Rate = Vector2.new(150, 65), 0
	emitter.Drag = 1.4
	emitter.Parent = pieces[1].Part
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 180, 80), 18, 0
	light.Parent = pieces[1].Part
	local impact = Instance.new("Sound")
	impact.SoundId, impact.Volume, impact.PlaybackSpeed = "rbxasset://sounds/action_jump_land.mp3", 0.8, 0.55
	impact.RollOffMaxDistance, impact.Parent = 130, pieces[1].Part
	local hatchSound = Instance.new("Sound")
	hatchSound.SoundId, hatchSound.Volume, hatchSound.PlaybackSpeed = "rbxasset://sounds/collide.wav", 0.45, 0.8
	hatchSound.RollOffMaxDistance, hatchSound.Parent = 90, door
	for _, entry in pieces do
		entry.Transparency = entry.Part.Transparency
	end
	model.Parent = workspace
	local cabin = Instance.new("PointLight")
	cabin.Color, cabin.Range, cabin.Brightness = color, 9, 0.85
	cabin.Parent = pieces[1].Part
	local landed, opened = false, false
	local result = {}
	function result.update(now)
		local start, origin = marker:GetAttribute("Start"), marker:GetAttribute("Origin")
		if type(start) ~= "number" or typeof(origin) ~= "CFrame" then
			return
		end
		local t = now - start
		local ends = marker:GetAttribute("Ends") or now
		local fadeAfterFight = Motion.smooth((now - ends) / Motion.SmokeAfter)
		local actor = marker:FindFirstChild("Actor")
		local outline = actor and actor.Value and actor.Value:FindFirstChild("InsertionSilhouette")
		if outline then
			outline.FillTransparency = 0.72 + 0.28 * fadeAfterFight
			outline.OutlineTransparency = 0.05 + 0.95 * fadeAfterFight
		end
		local pose = Motion.sample(t)
		cabin.Brightness = 0.85 * (1 - Motion.smooth((t - Motion.Exit) / 0.8))
		local floor = origin * CFrame.new(0, -3, 0)
		local frame = floor + Vector3.new(0, pose.Height - pose.Impact * 0.14, 0)
		-- The whole shell uses the same absolute sample as the camera.
		local fade = Motion.smooth((t - Motion.Ready - 1) / 0.8)
		for _, entry in pieces do
			local offset = entry.Offset
			if entry.Hatch then
				local h = pose.Hatch
				offset = CFrame.new(0, h * 1.6, -h * 6.5) * CFrame.Angles(-h * 1.1, 0, h * 0.16) * offset
			end
			entry.Part.CFrame = frame * offset
			local f = if entry.Hatch then math.max(fade, Motion.smooth((t - Motion.Hatch - 0.35) / 0.7)) else fade
			entry.Part.Transparency = entry.Transparency + (1 - entry.Transparency) * f
		end
		light.Brightness = if t >= Motion.Landing then 4 * math.exp(-(t - Motion.Landing) * 9) else 0.2
		if not landed and t >= Motion.Landing then
			landed = true
			-- One impact burst. Its lifespan reaches beyond combat unlock even for pod one.
			local life = math.max(0.1, ends + Motion.SmokeAfter - now)
			emitter.Lifetime = NumberRange.new(life * 0.9, life)
			if now < ends + Motion.SmokeAfter then
				emitter:Emit(42)
			end
			if t < Motion.Landing + 0.45 then
				impact:Play()
			end
		end
		if not opened and t >= Motion.Hatch then
			opened = true
			if t < Motion.Hatch + 0.4 then
				hatchSound:Play()
			end
		end
	end
	function result.destroy()
		model:Destroy()
	end
	return result
end
return Pod
