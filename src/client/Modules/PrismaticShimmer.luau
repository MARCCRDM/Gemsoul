--[[
	Prismatic gear (a 1-in-100 roll, see Shared.GearRolls): its coloured plates
	(tagged Prismatic by the server, with their own colour in PrismaticBase)
	shimmer through every hue, each a little behind the one next to it, at the
	brightness they were made with. Purely local.

	Copies shimmer too (your first-person sword, the Inventory's and the
	Shop's previews, gear art): found by PrismaticBase (LiveLooks), since a
	clone can't be counted on to keep its tag. A preview's plates shimmer
	while it's on screen, wherever the world's camera is.

	  PrismaticShimmer.hue(t, offset)  pure: the hue (0-1) at time t
	  PrismaticShimmer.start()
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)
local LiveLooks = require(script.Parent.LiveLooks)

local PrismaticShimmer = {}

PrismaticShimmer.Speed = 0.12 -- full turns of the colour wheel per second

function PrismaticShimmer.hue(t: number, offset: number): number
	return (t * PrismaticShimmer.Speed + offset) % 1
end

-- Only plates near the camera shimmer (too small to see further off), or in
-- a preview on screen, and each plate's base colour is read once, not every
-- frame.
PrismaticShimmer.Range = 150

function PrismaticShimmer.start()
	-- Place: where the plate is drawn (LiveLooks.place), read as it's added
	-- and again whenever it moves; View: its preview, if it's in one.
	type Plate = { Offset: number, Saturation: number, Value: number, Place: string, View: Instance? }
	local parts: { [BasePart]: Plate } = {}
	local links: { [BasePart]: { RBXScriptConnection } } = {}
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
	local function locate(part: BasePart)
		local entry = parts[part]
		if entry then
			entry.Place = LiveLooks.place(part)
			entry.View = if entry.Place == "View" then LiveLooks.viewOf(part) else nil
		end
	end
	local function remove(part: BasePart)
		parts[part] = nil
		for _, link in links[part] or {} do
			link:Disconnect()
		end
		links[part] = nil
	end
	local function add(instance: Instance)
		if instance:IsA("BasePart") and not parts[instance] then
			-- Neighbouring plates are offset by where they sit, so the colour flows.
			local p = instance.Position
			parts[instance] = {
				Offset = (p.X * 0.07 + p.Y * 0.11 + p.Z * 0.05) % 1,
				Saturation = -1,
				Value = 1,
				Place = "Away",
				View = nil,
			}
			read(instance)
			locate(instance)
			links[instance] = {
				instance:GetAttributeChangedSignal("PrismaticBase"):Connect(function()
					read(instance)
				end),
				-- (An untagged copy is forgotten as it leaves the game.)
				LiveLooks.follow(instance, function()
					locate(instance)
				end, function()
					remove(instance)
				end),
			}
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.Prismatic) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Prismatic):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.Prismatic):Connect(function(instance)
		remove(instance :: BasePart)
	end)
	LiveLooks.track("PrismaticBase", add)
	local live: { [Instance]: boolean } = {} -- each preview: on screen this frame?
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		table.clear(live)
		for part, plate in parts do
			local place = plate.Place
			local shows = plate.Saturation >= 0
			if not shows or place == "Away" then
				continue
			elseif place == "View" then
				local view = plate.View :: Instance
				local on = live[view]
				if on == nil then
					on = LiveLooks.onScreen(view)
					live[view] = on
				end
				shows = on
			elseif place == "World" then
				shows = not eye or (part.Position - eye).Magnitude < PrismaticShimmer.Range
			end
			if shows then
				part.Color = Color3.fromHSV(PrismaticShimmer.hue(t, plate.Offset), plate.Saturation, plate.Value)
			end
		end
	end)
end

return PrismaticShimmer
