--[[
	The Outpost's frontier on the server (Shared.Frontier has the rules; see
	docs/frontier.md): rifts tearing open round players out past the core,
	and a critter hopping out of each.

	Every half second, for everyone in the Outpost on their feet (not
	driving a machine, not sparring, not in a fight elsewhere): their band,
	whether they're heading outward, and their pressure
	(Frontier.pressure). When it's full and they haven't too many critters
	on them already (Frontier.Caps), an incursion: Frontier.incursion(band)
	rifts open ahead of them, a moment apart, and a moon bug hops out of
	each, at them (KaijuWilds.spawnBug). Back in the core the pressure
	drains, and the critters give up on them and slip back through rifts of
	their own (KaijuWilds).

	Rifts are anchors in workspace.Rifts, drawn by each player's client
	(RiftTear): an invisible part where the tear hangs, facing whoever drew
	it, with OpenAt, HopAt, CloseAt, EndAt (server time), Seed and Height;
	the dormant ones at the trails' ends (site.Scars) carry Dormant instead
	of a timeline, and stay. Each player carries FrontierBand (Core, Fringe
	or Edge) for their HUD.

	  FrontierServer.start(site)
	  FrontierServer.open(at, facing) -> anchor, timeline   a rift on the ground at `at`
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Outpost = require(ReplicatedStorage.Shared.Outpost)
local Spar = require(ReplicatedStorage.Shared.Spar)
local KaijuServer = require(script.Parent.KaijuServer)
local KaijuWilds = require(script.Parent.KaijuWilds)

local FrontierServer = {}

local folder: Folder
local rng = Random.new()
local nextSeed = 0
-- [player] = { Heat, Last (position), Distance, Band }
local states: { [Player]: any } = {}
-- [player] = { enemy }: the critters their rifts let through
local critters: { [Player]: { any } } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function center(): Vector3
	return Outpost.Location.Position
end

-- Can rifts open round `player` now? In the Outpost, on their feet and not
-- in a machine, a spar or a fight elsewhere. (Hunting is fine.)
local function eligible(player: Player): boolean
	if
		player:GetAttribute("Outpost") ~= true
		or Spar.isDown(player)
		or player:GetAttribute("SparWith") ~= nil
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("DungeonId") ~= nil
		or player:GetAttribute("Expedition") ~= nil
	then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and humanoid.SeatPart == nil
		and player:GetAttribute("MechPilot") == nil -- (in a mech)
		and rootOf(player) ~= nil
end
FrontierServer._eligible = eligible

-- A rift on the ground at `at`, facing `facing`: its anchor (for the
-- clients) and its timeline. Gone once it's sealed.
function FrontierServer.open(at: Vector3, facing: Vector3)
	nextSeed += 1
	local seed = rng:NextInteger(1, 2 ^ 30) + nextSeed
	local height = rng:NextNumber(Frontier.Rift.Height[1], Frontier.Rift.Height[2])
	local life = Frontier.timeline(serverNow())
	local anchor = Instance.new("Part")
	anchor.Name = "Rift"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	local middle = at + Vector3.new(0, height / 2 + 0.4, 0)
	local look = Vector3.new(facing.X, middle.Y, facing.Z)
	anchor.CFrame = if flat(look - middle).Magnitude > 0.1 then CFrame.lookAt(middle, look) else CFrame.new(middle)
	anchor:SetAttribute("Seed", seed)
	anchor:SetAttribute("Height", height)
	for key, value in life do
		anchor:SetAttribute(key, value)
	end
	anchor.Parent = folder
	task.delay(life.EndAt - serverNow() + 0.2, function()
		anchor:Destroy()
	end)
	return anchor, life
end

-- How many of `player`'s critters are still about (and forgets the rest).
local function living(player: Player): number
	local list = critters[player]
	if not list then
		return 0
	end
	for i = #list, 1, -1 do
		if not list[i].Alive then
			table.remove(list, i)
		end
	end
	return #list
end

-- `count` rifts open ahead of `player`, a moment apart, a critter out of each.
local function incursion(player: Player, band: string, count: number, heading: Vector3)
	for i = 1, count do
		task.delay((i - 1) * 0.35, function()
			local root = rootOf(player)
			if not root or not eligible(player) then
				return
			end
			local spot = Frontier.riftSpot(root.Position, heading, center(), rng)
			local floor = KaijuServer.ground(spot)
			local _, life = FrontierServer.open(floor, root.Position)
			task.delay(life.HopAt - serverNow(), function()
				local target = rootOf(player)
				if not target or not eligible(player) then
					return -- (gone, or safe: the tear seals empty)
				end
				local toward = flat(target.Position - floor)
				toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
				local enemy = KaijuWilds.spawnBug(floor, {
					Prey = player,
					Band = band,
					Facing = target.Position,
					Hop = toward * 24 + Vector3.new(0, 26, 0),
				})
				if enemy then
					critters[player] = critters[player] or {}
					table.insert(critters[player], enemy)
				end
			end)
		end)
	end
end

local function step(dt: number)
	local total = 0
	for player in critters do
		if player.Parent then
			total += living(player)
		else
			critters[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local state = states[player]
		if not state then
			state = { Heat = rng:NextNumber(0, 3) }
			states[player] = state
		end
		local root = rootOf(player)
		if not root or not eligible(player) then
			state.Heat = Frontier.pressure(state.Heat, "Core", false, dt)
			state.Last, state.Distance = nil, nil
			if player:GetAttribute("Outpost") ~= true and player:GetAttribute("FrontierBand") ~= nil then
				player:SetAttribute("FrontierBand", nil)
			end
			continue
		end
		local distance = Frontier.distance(root.Position, center())
		local band = Frontier.band(distance)
		local heading = if state.Last then flat(root.Position - state.Last) else Vector3.zero
		local outward = state.Distance ~= nil and distance - state.Distance > 0.4
		state.Last, state.Distance = root.Position, distance
		if player:GetAttribute("FrontierBand") ~= band then
			player:SetAttribute("FrontierBand", band)
		end
		state.Heat = Frontier.pressure(state.Heat, band, outward, dt)
		if band ~= "Core" and state.Heat >= Frontier.Pressure.Threshold then
			-- (It starts again from a little, so incursions don't come like clockwork.)
			state.Heat = rng:NextNumber(0, 3)
			local room = math.min(Frontier.Caps[band] - living(player), Frontier.Caps.Server - total)
			if room > 0 then
				local count = math.min(room, Frontier.incursion(band, rng:NextNumber()))
				total += count
				incursion(player, band, count, heading)
			end
		end
	end
end

function FrontierServer.start(site)
	folder = Instance.new("Folder")
	folder.Name = "Rifts"
	folder.Parent = workspace
	-- The dormant rift at each trail's end: it stays, quietly churning.
	for _, scar in (site and site.Scars) or {} do
		nextSeed += 1
		local anchor = Instance.new("Part")
		anchor.Name = "RiftScar"
		anchor.Anchored = true
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = scar * CFrame.new(0, 5.4, 0)
		anchor:SetAttribute("Seed", 7000 + nextSeed)
		anchor:SetAttribute("Height", 9)
		anchor:SetAttribute("Dormant", true)
		anchor.Parent = folder
	end
	-- A critter slipping back goes through a rift of its own.
	KaijuWilds.rift = function(at: Vector3, facing: Vector3)
		local _, life = FrontierServer.open(KaijuServer.ground(at), facing)
		return life
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player], critters[player] = nil, nil
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer >= 0.5 then
			local elapsed = timer
			timer = 0
			local ok, err = pcall(step, elapsed)
			if not ok then
				warn("[Frontier]", err)
			end
		end
	end)
end

-- For tests.
FrontierServer._step, FrontierServer._states, FrontierServer._critters = step, states, critters

return FrontierServer
