--[[
	Health shown on the body, not over it. The Outpost's creatures (your
	kaiju and other players', wild kaiju, a rift's critters) carry no bar or
	name over their heads: in a fight those piled up over the action. Each
	one's body tells how it's doing instead:

	  hurt      its colours sink toward a scorched red-black as its health
	            drops (none at full health, Dark of the way at none); a heal
	            brings them back
	  struck    a white flash on every blow that lands
	  in danger below Low it smokes, a dark wisp off its back, till it's
	            healed or gone

	Glowing parts (Neon: eyes, element glows) keep their light, so a kaiju
	still reads as its element. Only what's on this screen changes: the
	server's colours are never touched.

	  BodyHealth.watch(model)        start showing it (once: KaijuHud's scan
	                                 hands it each creature it finds)
	  BodyHealth.tint(share) -> 0..Dark   how far its colours sink (pure)
	  BodyHealth.smokes(share) -> boolean (pure)
	  BodyHealth.Wound, Dark, Low, Flash
]]
local BodyHealth = {}

BodyHealth.Wound = Color3.fromRGB(62, 18, 16) -- what a body sinks toward
BodyHealth.Dark = 0.6 -- how far, at no health left
BodyHealth.Low = 0.3 -- smoking below this share
BodyHealth.Flash = { Color = Color3.new(1, 1, 1), Amount = 0.7, Seconds = 0.08 }

-- How far its colours sink at `share` of its health: the first blows show
-- (a curve, not a line), the last ones most.
function BodyHealth.tint(share: number): number
	return BodyHealth.Dark * (1 - math.clamp(share, 0, 1)) ^ 0.75
end

function BodyHealth.smokes(share: number): boolean
	return share > 0 and share < BodyHealth.Low
end

type Entry = {
	Model: Model,
	Humanoid: Humanoid,
	Base: { [BasePart]: Color3 },
	Share: number,
	Flash: number, -- (which flash is the latest, so an old one doesn't end a new one)
	Smoke: ParticleEmitter?,
	Connections: { RBXScriptConnection },
}
local entries: { [Model]: Entry } = {}
-- (Glows keep their light: eyes, element glows, see-through shells.)
local function glows(part: BasePart): boolean
	local material = part.Material
	return material == Enum.Material.Neon or material == Enum.Material.ForceField or material == Enum.Material.Glass
end

local function shareOf(humanoid: Humanoid): number
	return if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 1
end

local function paint(entry: Entry, flash: number?)
	local amount = BodyHealth.tint(entry.Share)
	for part, base in entry.Base do
		local color = if amount > 0 then base:Lerp(BodyHealth.Wound, amount) else base
		if flash then
			color = color:Lerp(BodyHealth.Flash.Color, flash)
		end
		if part.Color ~= color then
			part.Color = color
		end
	end
end

local function learn(entry: Entry, part: Instance)
	if not part:IsA("BasePart") or entry.Base[part] or part.Name == "HumanoidRootPart" then
		return
	end
	if part.Transparency >= 0.95 or glows(part) then
		return
	end
	entry.Base[part] = part.Color
	local amount = BodyHealth.tint(entry.Share)
	if amount > 0 then
		part.Color = part.Color:Lerp(BodyHealth.Wound, amount)
	end
end

-- A dark wisp off its back, sized to it.
local function smoke(entry: Entry): ParticleEmitter?
	local root = entry.Model.PrimaryPart or entry.Model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local size = math.clamp(root.Size.Magnitude * 0.35, 0.8, 6)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BodyHealthSmoke"
	attachment.Position = Vector3.new(0, root.Size.Y * 0.5, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(70, 36, 32), Color3.fromRGB(28, 24, 26))
	emitter.LightEmission = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.9, 1.4)
	emitter.Rate = 7
	emitter.Speed = NumberRange.new(size * 0.8, size * 1.4)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Acceleration = Vector3.new(0, size * 0.6, 0)
	emitter.Enabled = false
	emitter.Parent = attachment
	return emitter
end

local function changed(entry: Entry)
	local share = shareOf(entry.Humanoid)
	local struck = share < entry.Share - 1e-3
	entry.Share = share
	if struck then
		entry.Flash += 1
		local this = entry.Flash
		paint(entry, BodyHealth.Flash.Amount)
		task.delay(BodyHealth.Flash.Seconds, function()
			if entries[entry.Model] == entry and entry.Flash == this then
				paint(entry)
			end
		end)
	else
		paint(entry)
	end
	local want = BodyHealth.smokes(share)
	if want and not entry.Smoke then
		entry.Smoke = smoke(entry)
	end
	if entry.Smoke and entry.Smoke.Enabled ~= want then
		entry.Smoke.Enabled = want
	end
end

local function forget(model: Model)
	local entry = entries[model]
	if not entry then
		return
	end
	entries[model] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	-- (Its own colours back, should it come back.)
	for part, base in entry.Base do
		part.Color = base
	end
	if entry.Smoke and entry.Smoke.Parent then
		entry.Smoke.Parent:Destroy()
	end
end

function BodyHealth.watch(model: Model)
	if entries[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local entry: Entry = {
		Model = model,
		Humanoid = humanoid,
		Base = {},
		Share = shareOf(humanoid),
		Flash = 0,
		Smoke = nil,
		Connections = {},
	}
	entries[model] = entry
	for _, part in model:GetDescendants() do
		learn(entry, part)
	end
	table.insert(entry.Connections, model.DescendantAdded:Connect(function(part)
		learn(entry, part) -- (streaming brings the rest of a body in)
	end))
	table.insert(entry.Connections, humanoid.HealthChanged:Connect(function()
		changed(entry)
	end))
	table.insert(entry.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			forget(model)
		end
	end))
	changed(entry)
end

return BodyHealth
