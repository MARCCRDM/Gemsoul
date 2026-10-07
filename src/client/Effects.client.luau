-- Animates tagged world pieces on each client: spinning crystals, bobbing
-- lanterns, floating containment fields, pulsing runes, flickering flames,
-- lasers, and shopkeepers turning to face you. Purely visual; the server
-- never sees these changes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)
-- Gem outlines on gear: only the nearest stay on, under Roblox's limit.
require(script.Parent.Modules.OutlineBudget).start()
-- Every player's body acts out their fighting (posed here, for everyone).
require(script.Parent.Modules.BodyPoses).start()
-- Your body keeps clear of everyone else's, and doesn't jump in a fight.
require(script.Parent.Modules.FighterSpacing).start()
-- Prismatic gear shimmers through every colour.
require(script.Parent.Modules.PrismaticShimmer).start()
-- Swing trails on every blade.
require(script.Parent.Modules.BladeTrails).start()
-- Night falls in the Arena: the fight and the gear light it.
require(script.Parent.Modules.ArenaNight).start()
-- A player killed by an element bursts apart in it (fire, shock, acid, ice).
require(script.Parent.Modules.ElementalDeath).start()

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

-- Shopkeepers turn to face a nearby player, then back to the street.
local VENDOR_NOTICE_DISTANCE = 20
local vendors: { [Model]: { Base: CFrame, Yaw: number, Rest: number } } = {}
local function addVendor(instance: Instance)
	-- Use the spot the server recorded, never the model's current pivot:
	-- a partly streamed-in model reports the wrong one.
	local home = instance:GetAttribute("Home")
	if instance:IsA("Model") and typeof(home) == "CFrame" then
		local rest = math.atan2(-home.LookVector.X, -home.LookVector.Z)
		vendors[instance] = { Base = home, Yaw = rest, Rest = rest }
	end
end
for _, instance in CollectionService:GetTagged(Tags.Vendor) do
	addVendor(instance)
end
CollectionService:GetInstanceAddedSignal(Tags.Vendor):Connect(addVendor)
CollectionService:GetInstanceRemovedSignal(Tags.Vendor):Connect(function(instance)
	vendors[instance] = nil
end)

local function turnVendors(dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for model, state in vendors do
		local target = state.Rest
		if root then
			local offset = root.Position - state.Base.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < VENDOR_NOTICE_DISTANCE then
				target = math.atan2(-offset.X, -offset.Z)
			end
		end
		local diff = (target - state.Yaw + math.pi) % (2 * math.pi) - math.pi
		if math.abs(diff) > 0.01 and model.PrimaryPart then
			state.Yaw += diff * math.min(1, dt * 6)
			model:PivotTo(CFrame.new(state.Base.Position) * CFrame.Angles(0, state.Yaw, 0))
		end
	end
end

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

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local eye = camera.CFrame.Position
	turnVendors(dt)

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
