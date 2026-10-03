--[[
	Combat visual effects (client only, nothing replicates):

	  burst(position, color, kind, scale)  a spray of particles: "Sparks" for
	      hits and blocks, "Embers" for fire, "Smoke" for dust, "Frost",
	      "Drips" for acid, "Shards" for deaths, plus a quick light flash
	  flash(position, color, brightness, range, seconds)  a light pulse
	  shake(strength, seconds)  shakes the camera (strength in radians)
	  auras(now)  every frame: elemental auras on anyone with status effects
	      (flames when Burning, frost mist and an ice tint when Frozen,
	      sparks when Shocked, acid drips, a glowing outline when Shielded),
	      with the sound of each effect as it lands
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local CombatSound = require(script.Parent.CombatSound)

local CombatFx = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "CombatFx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function anchor(position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "Fx"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.new(position)
	part.Parent = fxFolder()
	return part
end

local function sequence(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- Emitter settings per kind.
local KINDS = {
	Sparks = {
		Texture = SPARKLE,
		Count = 18,
		Speed = NumberRange.new(14, 30),
		Life = NumberRange.new(0.18, 0.4),
		Size = { 0.45, 0 },
		Drag = 6,
		Light = 0.6,
		Spread = 180,
	},
	Embers = {
		Texture = FIRE,
		Count = 22,
		Speed = NumberRange.new(6, 16),
		Life = NumberRange.new(0.3, 0.7),
		Size = { 1.2, 0.1 },
		Drag = 3,
		Light = 0.8,
		Rise = 12,
		Spread = 180,
	},
	Smoke = {
		Texture = SMOKE,
		Count = 10,
		Speed = NumberRange.new(3, 8),
		Life = NumberRange.new(0.4, 0.8),
		Size = { 1.2, 3 },
		Drag = 4,
		Transparency = { 0.55, 1 },
		Spread = 180,
	},
	Frost = {
		Texture = SPARKLE,
		Count = 24,
		Speed = NumberRange.new(8, 20),
		Life = NumberRange.new(0.3, 0.6),
		Size = { 0.6, 0 },
		Drag = 5,
		Light = 0.6,
		Spread = 180,
	},
	Drips = {
		Texture = SPARKLE,
		Count = 14,
		Speed = NumberRange.new(4, 10),
		Life = NumberRange.new(0.4, 0.8),
		Size = { 0.4, 0.1 },
		Fall = 40,
		Spread = 120,
	},
	Shards = {
		Texture = SPARKLE,
		Count = 40,
		Speed = NumberRange.new(16, 40),
		Life = NumberRange.new(0.4, 0.9),
		Size = { 0.8, 0 },
		Drag = 3,
		Fall = 30,
		Light = 1,
		Spread = 180,
	},
}

function CombatFx.flash(position: Vector3, color: Color3, brightness: number?, range: number?, seconds: number?)
	local part = anchor(position)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness or 3
	light.Range = range or 12
	light.Shadows = false
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(seconds or 0.25, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(part, (seconds or 0.25) + 0.1)
end

function CombatFx.burst(position: Vector3, color: Color3, kind: string?, scale: number?)
	local spec = KINDS[kind or "Sparks"] or KINDS.Sparks
	scale = scale or 1
	local part = anchor(position)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.Texture
	emitter.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	emitter.LightEmission = spec.Light or 0
	emitter.Size = sequence(spec.Size[1] * scale, spec.Size[2] * scale)
	emitter.Transparency = sequence(spec.Transparency and spec.Transparency[1] or 0, 1)
	emitter.Speed = NumberRange.new(spec.Speed.Min * scale, spec.Speed.Max * scale)
	emitter.Lifetime = spec.Life
	emitter.Drag = spec.Drag or 0
	emitter.SpreadAngle = Vector2.new(spec.Spread, spec.Spread)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Acceleration = Vector3.new(0, (spec.Rise or 0) - (spec.Fall or 0), 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(math.floor(spec.Count * math.clamp(scale, 0.5, 2.5)))
	if spec.Light then
		CombatFx.flash(position, color, 2 + 2 * scale, 8 + 6 * scale, 0.22)
	end
	Debris:AddItem(part, spec.Life.Max + 0.2)
end

-- Camera shake ---------------------------------------------------------------------------

local shakeUntil, shakeTotal, shakeStrength = 0, 1, 0
local shaking = false
function CombatFx.shake(strength: number, seconds: number)
	local now = os.clock()
	-- The stronger of what's running and what's asked for.
	local current = if now < shakeUntil then shakeStrength * (shakeUntil - now) / shakeTotal else 0
	if strength < current then
		return
	end
	shakeStrength, shakeTotal, shakeUntil = strength, seconds, now + seconds
	if not shaking then
		shaking = true
		RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 1, function()
			local left = shakeUntil - os.clock()
			if left <= 0 then
				return
			end
			local k = shakeStrength * (left / shakeTotal)
			local camera = workspace.CurrentCamera
			camera.CFrame = camera.CFrame
				* CFrame.Angles((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k * 0.6)
		end)
	end
end

-- How close is this spot to the local player (for shakes)?
function CombatFx.nearMe(position: Vector3, within: number): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - position).Magnitude <= within
end

-- Status auras ---------------------------------------------------------------------------

-- What each status looks like on a fighter, and the sound when it lands.
local AURAS = {
	Burning = {
		Texture = FIRE,
		Rate = 28,
		Size = { 1.4, 0.2 },
		Speed = { 2, 5 },
		Life = { 0.4, 0.8 },
		Rise = 9,
		Light = 1,
		Glow = true,
		Sound = "Burn",
	},
	Bleeding = {
		Texture = SPARKLE,
		Rate = 10,
		Size = { 0.35, 0.1 },
		Speed = { 1, 3 },
		Life = { 0.4, 0.7 },
		Fall = 30,
		Sound = "Hit",
	},
	Slowed = {
		Texture = SMOKE,
		Rate = 8,
		Size = { 1.6, 3 },
		Speed = { 0.5, 1.5 },
		Life = { 0.8, 1.4 },
		Transparency = 0.7,
		Sound = "Freeze",
	},
	Frozen = {
		Texture = SPARKLE,
		Rate = 16,
		Size = { 0.5, 0 },
		Speed = { 1, 3 },
		Life = { 0.4, 0.8 },
		Light = 0.8,
		Tint = true,
		Sound = "Freeze",
	},
	Shocked = {
		Texture = SPARKLE,
		Rate = 45,
		Size = { 0.5, 0 },
		Speed = { 6, 14 },
		Life = { 0.08, 0.2 },
		Light = 1,
		Glow = true,
		Sound = "Zap",
	},
	ArmorShred = {
		Texture = SPARKLE,
		Rate = 10,
		Size = { 0.45, 0.15 },
		Speed = { 1, 3 },
		Life = { 0.5, 0.9 },
		Fall = 25,
		Light = 0.4,
		Sound = "Corrode",
	},
	Vulnerable = {
		Texture = SPARKLE,
		Rate = 6,
		Size = { 0.6, 0 },
		Speed = { 0.5, 1.5 },
		Life = { 0.6, 1 },
		Light = 0.6,
		Sound = "Corrode",
	},
	Stunned = {
		Texture = SPARKLE,
		Rate = 8,
		Size = { 0.6, 0 },
		Speed = { 1, 2 },
		Life = { 0.4, 0.7 },
		Light = 0.8,
		Above = true,
	},
	Shielded = { Outline = true, Sound = "Shield" },
	CryoShield = { Outline = true, Tint = true, Sound = "Shield" },
	EnergySiphon = { Outline = true, Sound = "Shield" },
	ResonanceEcho = {
		Texture = SPARKLE,
		Rate = 10,
		Size = { 0.4, 0 },
		Speed = { 2, 4 },
		Life = { 0.3, 0.6 },
		Light = 1,
		Sound = "Cast",
	},
}

-- [owner] = { Model, Root, Attachment, Emitters = { [id] = emitter }, Highlight, Light, Active = { [id] = true } }
local tracked: { [Instance]: any } = {}

local function rootOf(owner: Instance): (Model?, BasePart?)
	local model = if owner:IsA("Player") then owner.Character else owner
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if model and root and root:IsA("BasePart") then
		return model :: Model, root
	end
	return nil, nil
end

local function emitterFor(entry, id: string, spec)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = id
	emitter.Texture = spec.Texture
	local effect = StatusEffects.Catalog[id]
	local color = if effect then effect.Color else Color3.new(1, 1, 1)
	emitter.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color)
	emitter.LightEmission = spec.Light or 0
	emitter.Size = sequence(spec.Size[1], spec.Size[2])
	emitter.Transparency = sequence(spec.Transparency or 0.1, 1)
	emitter.Speed = NumberRange.new(spec.Speed[1], spec.Speed[2])
	emitter.Lifetime = NumberRange.new(spec.Life[1], spec.Life[2])
	emitter.Rate = spec.Rate
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Acceleration = Vector3.new(0, (spec.Rise or 0) - (spec.Fall or 0), 0)
	-- Spread the particles over the body (above the head for a stun).
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = if spec.Above then entry.Head else entry.Body
	return emitter
end

local function forget(owner: Instance)
	local entry = tracked[owner]
	if entry then
		for _, object in { entry.Body, entry.Head, entry.Highlight, entry.Light } do
			if object then
				object:Destroy()
			end
		end
		tracked[owner] = nil
	end
end

local function entryFor(owner: Instance, model: Model, root: BasePart)
	local entry = tracked[owner]
	if entry and entry.Root == root and entry.Body.Parent then
		return entry
	end
	forget(owner)
	-- Emitters live on invisible boxes welded to the body, sized like it.
	local function box(offset: Vector3, size: Vector3, name: string)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Transparency = 1
		part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, true
		part.Anchored = false
		part.CFrame = root.CFrame * CFrame.new(offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, part
		weld.Parent = part
		part.Parent = fxFolder()
		return part
	end
	entry = {
		Model = model,
		Root = root,
		Body = box(Vector3.zero, Vector3.new(2.2, 4.5, 1.4), "StatusAura"),
		Head = box(Vector3.new(0, 3.2, 0), Vector3.new(1.6, 0.3, 1.6), "StatusHalo"),
		Emitters = {},
		Active = {},
	}
	tracked[owner] = entry
	return entry
end

local function refreshExtras(entry)
	-- One outline/tint for the strongest look, and a glow for fire or sparks.
	local tint, outline, glow
	for id in entry.Active do
		local spec = AURAS[id]
		local effect = StatusEffects.Catalog[id]
		if spec and effect then
			if spec.Tint and (not tint or id == "Frozen") then
				tint = effect.Color
			end
			if spec.Outline and not outline then
				outline = effect.Color
			end
			if spec.Glow and not glow then
				glow = effect.Color
			end
		end
	end
	if tint or outline then
		if not entry.Highlight then
			entry.Highlight = Instance.new("Highlight")
			entry.Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			entry.Highlight.Parent = entry.Model
		end
		entry.Highlight.FillColor = tint or outline
		entry.Highlight.FillTransparency = if tint then 0.55 else 0.9
		entry.Highlight.OutlineColor = outline or Color3.new(1, 1, 1)
		entry.Highlight.OutlineTransparency = if outline then 0.1 else 0.6
	elseif entry.Highlight then
		entry.Highlight:Destroy()
		entry.Highlight = nil
	end
	if glow then
		if not entry.Light then
			entry.Light = Instance.new("PointLight")
			entry.Light.Range = 10
			entry.Light.Shadows = false
			entry.Light.Parent = entry.Body
		end
		entry.Light.Color = glow
	elseif entry.Light then
		entry.Light:Destroy()
		entry.Light = nil
	end
end

local nextScan, owners = 0, {}
-- Call every frame with server time.
function CombatFx.auras(now: number)
	local clock = os.clock()
	if clock >= nextScan then
		nextScan = clock + 0.25
		table.clear(owners)
		local enemies = workspace:FindFirstChild("Enemies")
		for _, model in if enemies then enemies:GetChildren() else {} do
			table.insert(owners, model)
		end
		for _, other in Players:GetPlayers() do
			table.insert(owners, other)
		end
		for owner in tracked do
			if not owner.Parent then
				forget(owner)
			end
		end
	end
	for _, owner in owners do
		local text = owner.Parent and owner:GetAttribute("Statuses")
		local model, root = rootOf(owner)
		if not text or not model or not root then
			if tracked[owner] then
				forget(owner)
			end
			continue
		end
		local entry = entryFor(owner, model, root)
		local active = {}
		for _, status in StatusEffects.decode(text) do
			if status.Ends > now and AURAS[status.Id] then
				active[status.Id] = true
			end
		end
		local changed = false
		for id in active do
			if not entry.Active[id] then
				changed = true
				local spec = AURAS[id]
				if spec.Texture then
					entry.Emitters[id] = emitterFor(entry, id, spec)
				end
				if spec.Sound then
					CombatSound.play(spec.Sound, root.Position, { Volume = 0.8 })
				end
			end
		end
		for id in entry.Active do
			if not active[id] then
				changed = true
				if entry.Emitters[id] then
					entry.Emitters[id].Enabled = false
					Debris:AddItem(entry.Emitters[id], 1)
					entry.Emitters[id] = nil
				end
			end
		end
		entry.Active = active
		if changed then
			refreshExtras(entry)
		end
		if entry.Light then
			entry.Light.Brightness = 1.2 + math.sin(clock * 23) * 0.4 + math.sin(clock * 37) * 0.3
		end
	end
end

return CombatFx
