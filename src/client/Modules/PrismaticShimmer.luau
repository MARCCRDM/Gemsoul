--[[
	Prismatic gear (a 1-in-100 roll, see Shared.GearRolls): its coloured plates
	(tagged Prismatic by the server, with their own colour in PrismaticBase)
	shimmer through every hue, each a little behind the one next to it, at the
	brightness they were made with. Purely local.

	  PrismaticShimmer.hue(t, offset)  pure: the hue (0-1) at time t
	  PrismaticShimmer.start()
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local PrismaticShimmer = {}

PrismaticShimmer.Speed = 0.12 -- full turns of the colour wheel per second

function PrismaticShimmer.hue(t: number, offset: number): number
	return (t * PrismaticShimmer.Speed + offset) % 1
end

-- Only plates near the camera shimmer (too small to see further off), and
-- each plate's base colour is read once, not every frame.
PrismaticShimmer.Range = 150

function PrismaticShimmer.start()
	type Plate = { Offset: number, Saturation: number, Value: number }
	local parts: { [BasePart]: Plate } = {}
	local function read(part: BasePart)
		local entry = parts[part]
		local base = part:GetAttribute("PrismaticBase")
		if entry and typeof(base) == "Color3" then
			local _, s, v = base:ToHSV()
			entry.Saturation, entry.Value = math.max(s, 0.6), math.max(v, 0.7)
		elseif entry then
			entry.Saturation = -1 -- (no base colour: left alone)
		end
	end
	local function add(instance: Instance)
		if instance:IsA("BasePart") then
			-- Neighbouring plates are offset by where they sit, so the colour flows.
			local p = instance.Position
			parts[instance] = { Offset = (p.X * 0.07 + p.Y * 0.11 + p.Z * 0.05) % 1, Saturation = -1, Value = 1 }
			read(instance)
			instance:GetAttributeChangedSignal("PrismaticBase"):Connect(function()
				read(instance)
			end)
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.Prismatic) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Prismatic):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.Prismatic):Connect(function(instance)
		parts[instance :: BasePart] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		for part, plate in parts do
			if plate.Saturation >= 0 and (not eye or (part.Position - eye).Magnitude < PrismaticShimmer.Range) then
				part.Color = Color3.fromHSV(PrismaticShimmer.hue(t, plate.Offset), plate.Saturation, plate.Value)
			end
		end
	end)
end

return PrismaticShimmer
