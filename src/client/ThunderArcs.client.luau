--[[
	The Thunderclap pickaxe crackles (Shared PickaxeLooks tags its storm core
	and its tip ThunderArc): every so often a small arc of current jumps off
	the core, to the tip or into the air round the head, on everyone's
	screen near it. When one comes out in someone's hand, a bolt of
	lightning cracks down onto it (once a minute at most, per pick).
	The Stormcaller Wings crackle too (Server Equipment tags their storm
	core "WingCore" and their spark tips "Wing"), and worn with the pick,
	current jumps from it to the wings.
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
local WING_EVERY = { 0.5, 1.4 } -- seconds between the Stormcaller Wings' arcs
local SET_ARC = 0.35 -- with the wings on too: how often a pick's arc goes to them
local SET_REACH = 9 -- studs: the furthest a pick-to-wing arc jumps

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

-- Whose it is: the character it's on (a model with a Humanoid), if any.
local function wearer(part: Instance): Instance?
	local at = part.Parent
	while at and at ~= workspace do
		if at:IsA("Model") and at:FindFirstChildOfClass("Humanoid") then
			return at
		end
		at = at.Parent
	end
	return nil
end

-- The same wearer's parts with `role` (ThunderArc "Wing": the Stormcaller
-- Wings' spark tips).
local function partsOf(owner: Instance?, role: string): { BasePart }
	local list = {}
	if owner then
		for _, other in CollectionService:GetTagged(Tags.ThunderArc) do
			if other:IsA("BasePart") and other:GetAttribute("ThunderArc") == role and other:IsDescendantOf(owner) and shows(other) then
				table.insert(list, other)
			end
		end
	end
	return list
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
					local wings = if rng:NextNumber() < SET_ARC then partsOf(wearer(part), "Wing") else {}
					if #wings > 0 then
						-- The Thunderclap with the Stormcaller Wings: current jumps
						-- from the pick to a wingtip (the set).
						local wing = wings[rng:NextInteger(1, #wings)]
						if (wing.Position - from).Magnitude <= SET_REACH then
							pcall(CombatVfx.arc, from, wing.Position, VOLT, 0.06)
						end
					else
						local to = if tip and rng:NextNumber() < 0.5
							then tip.Position
							else from + rng:NextUnitVector() * rng:NextNumber(1.2, 2.6)
						pcall(CombatVfx.arc, from, to, VOLT, 0.045)
					end
				end
			elseif part:IsA("BasePart") and part:GetAttribute("ThunderArc") == "WingCore" and shows(part) and near(part, NEAR) then
				-- The Stormcaller Wings: an arc from the storm core out to a
				-- wingtip, or off a wingtip into the air.
				local due = nextArc[part]
				if not due then
					nextArc[part] = now + rng:NextNumber(WING_EVERY[1], WING_EVERY[2])
				elseif now >= due then
					nextArc[part] = now + rng:NextNumber(WING_EVERY[1], WING_EVERY[2])
					local wings = partsOf(wearer(part), "Wing")
					if #wings > 0 then
						local wing = wings[rng:NextInteger(1, #wings)]
						if rng:NextNumber() < 0.4 then
							pcall(CombatVfx.arc, part.Position, wing.Position, VOLT, 0.05)
						else
							local off = wing.Position + rng:NextUnitVector() * rng:NextNumber(1, 2.2)
							pcall(CombatVfx.arc, wing.Position, off, VOLT, 0.04)
						end
					end
				end
			end
		end
	end
end)
