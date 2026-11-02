--[[
	The Thunderclap pickaxe crackles (Shared PickaxeLooks tags its storm core
	and its tip ThunderArc): every so often a small arc of current jumps off
	the core, to the tip or into the air round the head, on everyone's
	screen near it. When one comes out in someone's hand, a bolt of
	lightning cracks down onto it (once a minute at most, per pick).
	Purely local: nothing replicates.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local CombatVfx = require(script.Parent.Modules.CombatVfx)

local VOLT = Color3.fromRGB(80, 200, 255)
local NEAR = 120 -- studs from the camera: further off, no arcs
local EVERY = { 0.35, 1.1 } -- seconds between one pick's arcs
local STRIKE_AGAIN = 60 -- seconds before a pick's arrival strikes again

local nextArc: { [BasePart]: number } = {}
local struck: { [Instance]: number } = {}
local rng = Random.new()

local function shows(part: BasePart): boolean
	return part:IsDescendantOf(workspace) and part.Transparency < 1 and part.LocalTransparencyModifier < 1
end

local function near(part: BasePart, range: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - part.Position).Magnitude <= range
end

-- The tip beside a core (the same pick: the same parent).
local function tipOf(core: BasePart): BasePart?
	for _, other in CollectionService:GetTagged(Tags.ThunderArc) do
		if other ~= core and other.Parent == core.Parent and other:GetAttribute("ThunderArc") == "Tip" then
			return other :: BasePart
		end
	end
	return nil
end

local function arrived(part: Instance)
	if not part:IsA("BasePart") or part:GetAttribute("ThunderArc") ~= "Tip" then
		return
	end
	task.defer(function()
		local tip = part :: BasePart
		if not tip.Parent or not shows(tip) or not near(tip, 80) then
			return
		end
		local holder = tip.Parent
		local now = os.clock()
		if holder and struck[holder] and now - struck[holder] < STRIKE_AGAIN then
			return
		end
		if holder then
			struck[holder] = now
		end
		local sky = tip.Position + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(18, 26), rng:NextNumber(-4, 4))
		pcall(CombatVfx.lightning, sky, tip.Position, VOLT)
	end)
end

CollectionService:GetInstanceAddedSignal(Tags.ThunderArc):Connect(arrived)
CollectionService:GetInstanceRemovedSignal(Tags.ThunderArc):Connect(function(part)
	nextArc[part :: BasePart] = nil
end)

task.spawn(function()
	while true do
		task.wait(0.12)
		local now = os.clock()
		for _, part in CollectionService:GetTagged(Tags.ThunderArc) do
			if part:IsA("BasePart") and part:GetAttribute("ThunderArc") == "Core" and shows(part) and near(part, NEAR) then
				local due = nextArc[part]
				if not due then
					nextArc[part] = now + rng:NextNumber(EVERY[1], EVERY[2])
				elseif now >= due then
					nextArc[part] = now + rng:NextNumber(EVERY[1], EVERY[2])
					local from = part.Position
					local tip = tipOf(part)
					local to = if tip and rng:NextNumber() < 0.5
						then tip.Position
						else from + rng:NextUnitVector() * rng:NextNumber(1.2, 2.6)
					pcall(CombatVfx.arc, from, to, VOLT, 0.045)
				end
			end
		end
	end
end)
