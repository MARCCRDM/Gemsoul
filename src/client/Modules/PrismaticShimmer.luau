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

function PrismaticShimmer.start()
	local parts: { [BasePart]: number } = {}
	local function add(instance: Instance)
		if instance:IsA("BasePart") then
			-- Neighbouring plates are offset by where they sit, so the colour flows.
			local p = instance.Position
			parts[instance] = (p.X * 0.07 + p.Y * 0.11 + p.Z * 0.05) % 1
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
		for part, offset in parts do
			local base = part:GetAttribute("PrismaticBase")
			if typeof(base) == "Color3" then
				local _, s, v = base:ToHSV()
				part.Color = Color3.fromHSV(PrismaticShimmer.hue(t, offset), math.max(s, 0.6), math.max(v, 0.7))
			end
		end
	end)
end

return PrismaticShimmer
