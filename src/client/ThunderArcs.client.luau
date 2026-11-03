--[[
	The Thunderclap pickaxe crackles (Shared PickaxeLooks tags its storm core
	and its tip ThunderArc): every so often a small arc of current jumps off
	the core, to the tip or into the air round the head, on everyone's
	screen near it. When one comes out in someone's hand, a bolt of
	lightning cracks down onto it (once a minute at most, per pick).
	The Stormcaller Wings crackle too (Server Equipment tags their storm
	core "WingCore" and their spark tips "Wing"), and worn with the pick,
	current jumps from it to the wings.
	A Thunder Aura (Server Equipment's shell round the body, "Aura"): thick
	arcs jump off its wearer's limbs and across the body several times a
	second, its light flickering with them; every few seconds lightning
	strikes the ground beside them; and they land from a jump in a strike
	of lightning with current running out along the ground.
	Purely local: nothing replicates.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local CombatVfx = require(script.Parent.Modules.CombatVfx)

local VOLT = Color3.fromRGB(80, 200, 255)
local BRIGHT = Color3.fromRGB(225, 245, 255)
local NEAR = 120 -- studs from the camera: further off, no arcs
local EVERY = { 0.35, 1.1 } -- seconds between one pick's arcs
local STRIKE_AGAIN = 60 -- seconds before a pick's arrival strikes again
local WING_EVERY = { 0.5, 1.4 } -- seconds between the Stormcaller Wings' arcs
local AURA_EVERY = { 0.07, 0.2 } -- seconds between a Thunder Aura's arcs round its wearer
local AURA_STRIKE = { 5, 9 } -- seconds between the lightning that strikes beside its wearer
local nextStrike: { [BasePart]: number } = {}
local LAND_AGAIN = 1.2 -- seconds: a Thunder Aura's landing strike at most this often
local LAND_FALL = 18 -- studs/s falling (or more) for a landing to strike
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

-- A wearer's body parts on screen (none in first person: your own limbs
-- are hidden then).
local function bodyOf(owner: Instance?): { BasePart }
	local list = {}
	if owner then
		for _, child in owner:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 1 and child.LocalTransparencyModifier < 1 then
				table.insert(list, child)
			end
		end
	end
	return list
end

-- A Thunder Aura's wearer lands from a jump or a fall: lightning cracks
-- down where they land, and current runs out along the ground.
local landed: { [Instance]: number } = {}
local watching: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watchLandings(shell: BasePart)
	local owner = wearer(shell)
	local humanoid = owner and owner:FindFirstChildOfClass("Humanoid")
	-- (One watch per shell: rebuilt gear brings a new shell, and the old
	-- watch lets go at its next state change.)
	if not owner or not humanoid or watching[shell] then
		return
	end
	watching[shell] = true
	local falling = 0
	local connection
	connection = humanoid.StateChanged:Connect(function(_, state)
		if not shell.Parent or not shell:IsDescendantOf(owner) then
			watching[shell] = nil
			connection:Disconnect()
			return
		end
		local root = owner:FindFirstChild("HumanoidRootPart") :: BasePart?
		if state == Enum.HumanoidStateType.Freefall then
			falling = 0
		elseif state == Enum.HumanoidStateType.Landed and root and near(root, NEAR) then
			local now = os.clock()
			local speed = math.max(falling, -root.AssemblyLinearVelocity.Y)
			if speed >= LAND_FALL and now - (landed[owner] or 0) >= LAND_AGAIN then
				landed[owner] = now
				local feet = root.Position - Vector3.new(0, 2.8, 0)
				pcall(CombatVfx.lightning, feet + Vector3.new(rng:NextNumber(-2, 2), 22, rng:NextNumber(-2, 2)), feet, VOLT)
				for i = 1, 4 do
					local angle = (i + rng:NextNumber(-0.3, 0.3)) * math.pi / 2
					local out = feet + Vector3.new(math.cos(angle), 0.1, math.sin(angle)) * rng:NextNumber(2.5, 4)
					pcall(CombatVfx.arc, feet + Vector3.new(0, 0.1, 0), out, VOLT, 0.05)
				end
			end
		end
	end)
	-- (How fast they were falling, read while they fall: by the time they've
	-- landed it's gone.)
	task.spawn(function()
		while connection.Connected do
			local root = owner:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				falling = math.max(falling, -root.AssemblyLinearVelocity.Y)
			end
			task.wait(0.05)
		end
	end)
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
local function auraArrived(part: Instance)
	if part:IsA("BasePart") and part:GetAttribute("ThunderArc") == "Aura" then
		task.defer(watchLandings, part)
	end
end
CollectionService:GetInstanceAddedSignal(Tags.ThunderArc):Connect(auraArrived)
for _, part in CollectionService:GetTagged(Tags.ThunderArc) do
	auraArrived(part)
end
CollectionService:GetInstanceRemovedSignal(Tags.ThunderArc):Connect(function(part)
	nextArc[part :: BasePart] = nil
	nextStrike[part :: BasePart] = nil
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
			elseif part:IsA("BasePart") and part:GetAttribute("ThunderArc") == "Aura" and part:IsDescendantOf(workspace) and near(part, NEAR) then
				-- A Thunder Aura: thick arcs of current off its wearer's limbs,
				-- now and then right across the body, its light flickering
				-- with them; and every few seconds lightning strikes beside them.
				local due = nextArc[part]
				if not due then
					nextArc[part] = now + rng:NextNumber(AURA_EVERY[1], AURA_EVERY[2])
					nextStrike[part] = now + rng:NextNumber(1, 3)
				elseif now >= due then
					nextArc[part] = now + rng:NextNumber(AURA_EVERY[1], AURA_EVERY[2])
					local owner = wearer(part)
					local limbs = bodyOf(owner)
					if #limbs > 0 then
						for _ = 1, rng:NextInteger(1, 2) do
							local limb = limbs[rng:NextInteger(1, #limbs)]
							local from = limb.Position + rng:NextUnitVector() * 0.5
							if rng:NextNumber() < 0.3 and #limbs > 1 then
								local other = limbs[rng:NextInteger(1, #limbs)]
								pcall(CombatVfx.arc, from, other.Position + rng:NextUnitVector() * 0.5, BRIGHT, 0.12)
							else
								local to = from + rng:NextUnitVector() * rng:NextNumber(1.6, 3.4)
								pcall(CombatVfx.arc, from, to, VOLT, rng:NextNumber(0.08, 0.15))
							end
						end
					end
					local light = part:FindFirstChild("AuraLight")
					if light and light:IsA("PointLight") then
						light.Brightness = rng:NextNumber(1.2, 4)
					end
					if now >= (nextStrike[part] or math.huge) then
						nextStrike[part] = now + rng:NextNumber(AURA_STRIKE[1], AURA_STRIKE[2])
						local root = owner and owner:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and near(root, 90) then
							local side = rng:NextUnitVector() * Vector3.new(1, 0, 1)
							side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(1, 0, 0)
							local ground = root.Position - Vector3.new(0, 2.8, 0) + side * rng:NextNumber(3.5, 6)
							pcall(CombatVfx.lightning, ground + Vector3.new(rng:NextNumber(-2, 2), 24, rng:NextNumber(-2, 2)), ground, VOLT)
							for _ = 1, 3 do
								local out = ground + (rng:NextUnitVector() * Vector3.new(1, 0, 1)) * rng:NextNumber(2, 3.5)
								pcall(CombatVfx.arc, ground + Vector3.new(0, 0.1, 0), out + Vector3.new(0, 0.1, 0), VOLT, 0.08)
							end
						end
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
