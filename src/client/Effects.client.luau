-- Animates tagged world pieces on each client: spinning crystals, bobbing
-- lanterns, floating containment fields, pulsing runes, flickering flames
-- and lasers. Purely visual; the server never sees these changes.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

-- Tracks every part with `tag`, remembering where the server placed it.
local function track(tag: string): { [BasePart]: CFrame }
	local parts = {}
	local function add(instance: Instance)
		if instance:IsA("BasePart") then
			parts[instance] = instance.CFrame
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		parts[instance] = nil
	end)
	return parts
end

local spinning = track(Tags.Spin)
local bobbing = track(Tags.Bob)
local fields = track(Tags.ContainmentField)
local runes = track(Tags.ArcaneRune)
local flames = track(Tags.Flicker)
local lasers = track(Tags.Laser)

-- A stable per-part offset so neighbours don't move in lockstep.
local function phaseOf(base: CFrame): number
	return base.Position.X * 0.37 + base.Position.Z * 0.21
end

-- Only animate what's near the camera; distant pieces stay still.
local ANIMATE_DISTANCE = 220

local camera = workspace.CurrentCamera

local function near(base: CFrame, from: Vector3): boolean
	return (base.Position - from).Magnitude < ANIMATE_DISTANCE
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local eye = camera.CFrame.Position

	for part, base in spinning do
		if not near(base, eye) then
			continue
		end
		part.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, t * 1.2, 0) * base.Rotation
	end

	for part, base in bobbing do
		if not near(base, eye) then
			continue
		end
		part.CFrame = base + Vector3.new(0, math.sin(t * 2 + phaseOf(base)) * 0.6, 0)
	end

	for part, base in fields do
		if not near(base, eye) then
			continue
		end
		local lift = math.sin(t * 1.5 + phaseOf(base)) * 0.8
		part.CFrame = CFrame.new(base.Position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, t * 0.8, 0) * base.Rotation
	end

	for part, base in runes do
		if not near(base, eye) then
			continue
		end
		local phase = part:GetAttribute("Phase") or 0
		part.Transparency = 0.1 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 + phase * 0.8))
	end

	for part, base in flames do
		if not near(base, eye) then
			continue
		end
		local n = math.noise(t * 3, phaseOf(base))
		part.Transparency = math.clamp(n * 0.4, 0, 0.35)
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 2 + n * 1.5
		end
	end

	for part, base in lasers do
		if not near(base, eye) then
			continue
		end
		part.Transparency = if (t * 7) % 1 < 0.15 then 0.7 else 0
	end
end)
