-- Local cosmetic pods: no replicated part tweens compete with helmet movement.
local Motion = require(game:GetService("ReplicatedStorage").Shared.InsertionMotion)
local Pod = {}
function Pod.new(marker)
	local model = Instance.new("Model")
	model.Name = "InsertionPresentation"
	local pieces = {}
	local compact = game:GetService("UserInputService").TouchEnabled
	local smokeNodes = {}
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
			{
				Part = p,
				Offset = offset,
				Hatch = string.find(name, "Hatch") ~= nil and name ~= "HatchHeader",
				Fixed = name == "ArmoredBase" or name == "LandingSkid",
				Side = if math.abs(offset.Position.X) > 1 then (if offset.Position.X > 0 then 1 else -1) else 0,
			}
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
	-- The impact cloud spreads across the floor, independent of shell debris.
	-- Fixed burst counts bound particle work, including multi-fighter matches.
	for i = 1, (if compact then 6 else 8) do
		local node = Instance.new("Part")
		node.Name, node.Size, node.Transparency = "ImpactSmoke", Vector3.new(0.2, 0.2, 0.2), 1
		node.Anchored, node.CanCollide, node.CanTouch, node.CanQuery = true, false, false, false
		node.CFrame = CFrame.new(0, -10000, 0)
		node.Parent = model
		local smoke = emitter:Clone()
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 4),
			NumberSequenceKeypoint.new(0.25, 14),
			NumberSequenceKeypoint.new(1, 22),
		})
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.38),
			NumberSequenceKeypoint.new(0.45, 0.50),
			NumberSequenceKeypoint.new(0.8, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.LockedToPart = true
		smoke.Speed, smoke.Drag = NumberRange.new(0.3, 1.1), 0.8
		smoke.Rotation, smoke.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-12, 12)
		smoke.Parent = node
		table.insert(
			smokeNodes,
			{ Part = node, Emitter = smoke, Angle = (i - 1) * math.pi * 2 / (if compact then 6 else 8) }
		)
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 235, 160), Color3.fromRGB(255, 105, 25))
	sparks.LightEmission, sparks.Rate = 1, 0
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.Speed, sparks.Lifetime = NumberRange.new(14, 25), NumberRange.new(0.35, 0.7)
	sparks.SpreadAngle, sparks.Acceleration = Vector2.new(150, 150), Vector3.new(0, -35, 0)
	sparks.Parent = pieces[1].Part
	local flame = Instance.new("ParticleEmitter")
	flame.Texture = "rbxasset://textures/particles/fire_main.dds"
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 205, 95), Color3.fromRGB(235, 65, 15))
	flame.LightEmission, flame.Rate = 1, 0
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(0.3, 7),
		NumberSequenceKeypoint.new(1, 10),
	})
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	flame.Speed, flame.Lifetime, flame.SpreadAngle =
		NumberRange.new(4, 8), NumberRange.new(0.18, 0.32), Vector2.new(130, 130)
	flame.Parent = pieces[1].Part
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 180, 80), 28, 0
	light.Parent = pieces[1].Part
	local impact = Instance.new("Sound")
	impact.SoundId, impact.Volume, impact.PlaybackSpeed = "rbxasset://sounds/action_jump_land.mp3", 0.8, 0.55
	impact.RollOffMaxDistance, impact.Parent = 130, pieces[1].Part
	local hatchSound = Instance.new("Sound")
	hatchSound.SoundId, hatchSound.Volume, hatchSound.PlaybackSpeed = "rbxasset://sounds/collide.wav", 0.7, 0.6
	hatchSound.RollOffMaxDistance, hatchSound.Parent = 90, door
    local descent=Instance.new("Sound")
    descent.Name,descent.SoundId="DescentAir","rbxasset://sounds/action_falling.mp3"
    descent.Looped,descent.Volume,descent.RollOffMaxDistance=true,0,160
    descent.Parent=pieces[1].Part
    local rumble=descent:Clone()
    rumble.Name,rumble.PlaybackSpeed,rumble.Parent="InsertionRumble",.28,pieces[1].Part
    local bass=Instance.new("EqualizerSoundEffect")
    bass.LowGain,bass.MidGain,bass.HighGain=6,-10,-24
    bass.Parent=rumble
    local rupture=Instance.new("Sound")
    rupture.Name,rupture.SoundId="ShellRupture","rbxasset://sounds/action_jump_land.mp3"
    rupture.Volume,rupture.PlaybackSpeed,rupture.RollOffMaxDistance=.85,.42,130
    rupture.Parent=pieces[1].Part
    local group=game:GetService("SoundService"):FindFirstChild("CombatSounds")
    for _,sound in {impact,hatchSound,descent,rumble,rupture} do sound.SoundGroup=group end
	for _, entry in pieces do
		entry.Transparency = entry.Part.Transparency
	end
	model.Parent = workspace
	local cabin = Instance.new("PointLight")
	cabin.Color, cabin.Range, cabin.Brightness = color, 9, 0.85
	cabin.Parent = pieces[1].Part
	local landed, opened, ruptured, audioStarted, audioStopped = false, false, false, false, false
	local lastSmokeFade = -1
	local result = {}
	function result.update(now)
		local start, origin = marker:GetAttribute("Start"), marker:GetAttribute("Origin")
		if type(start) ~= "number" or typeof(origin) ~= "CFrame" then
			return
		end
		local t = now - start
		local ends = marker:GetAttribute("Ends") or now
		local fadeAfterFight = Motion.smooth((now - ends) / Motion.SmokeAfter)
		-- Absolute fade also handles viewers who stream in after the impact.
		-- Quantize updates so changing transparency sequences does not allocate every frame.
		local smokeFade = math.floor(fadeAfterFight * 20) / 20
		if smokeFade ~= lastSmokeFade then
			lastSmokeFade = smokeFade
			local function fadeSequence(a, b, c)
				return NumberSequence.new({
					NumberSequenceKeypoint.new(0, a + (1 - a) * smokeFade),
					NumberSequenceKeypoint.new(0.55, b + (1 - b) * smokeFade),
					NumberSequenceKeypoint.new(0.8, c + (1 - c) * smokeFade),
					NumberSequenceKeypoint.new(1, 1),
				})
			end
			emitter.Transparency = fadeSequence(0.28, 0.45, 0.78)
			local broad = fadeSequence(0.38, 0.5, 0.82)
			for _, node in smokeNodes do
				node.Emitter.Transparency = broad
			end
		end
		local actor = marker:FindFirstChild("Actor")
		local outline = actor and actor.Value and actor.Value:FindFirstChild("InsertionSilhouette")
		if outline then
			outline.FillTransparency = 0.55 + 0.45 * fadeAfterFight
			outline.OutlineTransparency = 0.05 + 0.95 * fadeAfterFight
		end
		local pose = Motion.sample(t)
		local blast = Motion.blast(t)
        local audio=Motion.audio(t)
        if t>=0 and t<Motion.Landing+.65 and not audioStarted then
            audioStarted=true
            descent:Play(); rumble:Play()
        end
        descent.Volume,descent.PlaybackSpeed=audio.Air*.38,audio.Pitch
        rumble.Volume=audio.Rumble*.55
        if t>=Motion.Landing+.65 and not audioStopped then
            audioStopped=true
            descent:Stop(); rumble:Stop()
        end
		cabin.Brightness = 0.85 * (1 - Motion.smooth((t - Motion.Exit) / 0.8))
		local floor = origin * CFrame.new(0, -3, 0)
		local frame = floor + Vector3.new(0, pose.Height - pose.Impact * 0.14, 0)
		for _, node in smokeNodes do
			local radius = Motion.smokeSpread(t)
			node.Part.CFrame = floor * CFrame.new(math.cos(node.Angle) * radius, 1.6, math.sin(node.Angle) * radius)
		end
		-- The whole shell uses the same absolute sample as the camera.
		local fade = Motion.smooth((t - Motion.Ready - 1) / 0.8)
		for _, entry in pieces do
			local offset = entry.Offset
			if entry.Hatch then
				local h = pose.Hatch
				offset = CFrame.new(0, h * 1.6, -h * 6.5) * CFrame.Angles(-h * 1.1, 0, h * 0.16) * offset
			elseif not entry.Fixed and t >= Motion.ShellBurst then
				-- Side armor separates away from the fighter; the roof and spine arc backward.
				local x = entry.Side * blast.Travel * 11
				local z = if entry.Side ~= 0 then blast.Travel * 2 else blast.Travel * 9
				local y = math.max(0.15 - entry.Offset.Position.Y, blast.Lift)
				offset = CFrame.new(x, y, z)
					* entry.Offset
					* CFrame.Angles(blast.Spin * 0.9, entry.Side * blast.Spin, entry.Side * blast.Spin * 1.3)
			end
			entry.Part.CFrame = frame * offset
			local f = if entry.Hatch then math.max(fade, Motion.smooth((t - Motion.Hatch - 0.35) / 0.7)) else fade
			if not entry.Fixed and not entry.Hatch then
				f = math.max(f, blast.Fade)
			end
			entry.Part.Transparency = entry.Transparency + (1 - entry.Transparency) * f
		end
		light.Brightness = (if t >= Motion.Landing then 4 * math.exp(-(t - Motion.Landing) * 9) else 0.2)
			+ blast.Flash * 6
		if not landed and t >= Motion.Landing then
			landed = true
			-- One impact burst. Its lifespan reaches beyond combat unlock even for pod one.
			local life = math.max(0.1, ends + Motion.SmokeAfter - now)
			emitter.Lifetime = NumberRange.new(life * 0.9, life)
			if now < ends + Motion.SmokeAfter then
				emitter:Emit(if compact then 48 else 88)
				for _, node in smokeNodes do
					node.Emitter.Lifetime = NumberRange.new(life * 0.95, life)
					node.Emitter:Emit(if compact then 6 else 11)
				end
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
        -- Door has already cleared forward before the rest of the shell detonates.
        if not ruptured and t>=Motion.ShellBurst then
            ruptured=true
            if t<Motion.ShellBurst+.35 then
                sparks:Emit(if compact then 18 else 30)
                flame:Emit(if compact then 5 else 8)
                emitter.Lifetime=NumberRange.new(math.max(.1,ends+Motion.SmokeAfter-now))
                emitter:Emit(if compact then 14 else 24)
                rupture:Play()
            end
        end
        result.Ready=true
	end
	function result.destroy()
		model:Destroy()
	end
	return result
end
return Pod
