--[[
	The Outpost's frontier on the server (Shared.Frontier has the rules; see
	docs/frontier.md): rifts tearing open round players out past the core,
	and moon bugs hopping out of them (KaijuWilds.spawnBug).

	  Mining noise   OutpostServer tells this of every swing (swing: on foot
	                 or from a mech's cockpit), and anyone out past the core
	                 makes a little noise each half second besides
	                 (Frontier.noise). Full, an encounter: a rift or two open
	                 near where they look, a moment apart, crackling a
	                 moment first, and a critter hops out of each at them.
	  Wandering      every Wander.Every seconds or so the frontier tears
	                 open by itself, Wander.Near to Far studs from someone
	                 out there, and a few critters roam round it for a
	                 minute, going for whoever comes close. Cleared (every
	                 one killed), everyone who helped is Rift Charged
	                 (RiftCharged: the server time it runs out; mined gems
	                 come luckier till then, OutpostServer).

	Nobody gets more critters than their band's cap or a fair share of the
	Outpost's (Frontier.share); critters still on their way through count.
	Nobody gets one in the core, in a fight elsewhere, in a spar, or down.
	A critter's level comes from where it came through (Frontier.Levels).

	Rifts are anchors in workspace.Rifts, drawn by each player's client
	(RiftTear): an invisible part where the tear hangs, facing whoever drew
	it, with OpenAt, HopAt, CloseAt, EndAt (server time), Seed, Height,
	Critter (the roster id of what's coming through) and Prey (the UserId it
	comes for); the dormant ones at the Rift Veins (site.Scars) carry
	Dormant instead of a timeline, and stay. Each player carries
	FrontierBand (Core, Fringe or Edge) and FrontierNoise (0..1, in
	twentieths) for their HUD.

	  FrontierServer.start(site)
	  FrontierServer.swing(player, swings)   a swing out there (OutpostServer)
	  FrontierServer.open(at, facing, opts?) -> anchor, timeline   a rift on the ground at `at`
	  FrontierServer.scar(at) -> anchor   a dormant rift (a vein's)
	  FrontierServer.moveScar(index, at)  vein `index`'s dormant rift moves with it
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Outpost = require(ReplicatedStorage.Shared.Outpost)
local Spar = require(ReplicatedStorage.Shared.Spar)
local KaijuServer = require(script.Parent.KaijuServer)
local KaijuWilds = require(script.Parent.KaijuWilds)
local Remotes = require(script.Parent.Remotes)

local FrontierServer = {}

local folder: Folder
local rng = Random.new()
local nextSeed = 0
-- [player] = { Noise, LastEncounter (os.clock), Shown (the FrontierNoise last set) }
local states: { [Player]: any } = {}
-- [player] = { enemy }: the critters out for them (encounters and wandering rifts)
local critters: { [Player]: { any } } = {}
-- [player] = critters still on their way through for them
local pending: { [Player]: number } = {}
-- Wandering rifts with critters out (or about to be): { Player, Critters,
-- Pending, Helpers = { [Player]: true }, Killed, Lost }
local wanders = {}
local groupOf = setmetatable({}, { __mode = "k" }) -- [enemy] = its wandering rift
local playersOut = 0 -- those out past the core, last step (for a fair share)
local scars: { [number]: BasePart } = {} -- each vein's dormant rift
local nextWander = 0

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

-- Can rifts open round `player` now? In the Outpost, alive, not down, not
-- in a spar with someone or a fight elsewhere. (Hunting is fine, and so is
-- a mech's cockpit: its swings make noise too.)
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
	return humanoid ~= nil and humanoid.Health > 0 and humanoid.SeatPart == nil and rootOf(player) ~= nil
end
FrontierServer._eligible = eligible

local function stateOf(player: Player)
	local state = states[player]
	if not state then
		state = { Noise = rng:NextNumber(0, Frontier.Noise.Restart), LastEncounter = -math.huge, Shown = nil }
		states[player] = state
	end
	return state
end

-- Their noise for the HUD's ring, in twentieths (not every swing's share).
local function show(player: Player, state)
	local shown = if player:GetAttribute("Outpost") == true
		then math.floor(math.clamp(state.Noise, 0, 1) * 20 + 0.5) / 20
		else nil
	if shown ~= state.Shown then
		state.Shown = shown
		player:SetAttribute("FrontierNoise", shown)
	end
end

-- A rift on the ground at `at`, facing `facing`: its anchor (for the
-- clients) and its timeline. Gone once it's sealed. `opts` = { Linger,
-- Critter (roster id), Prey (a Player) }.
function FrontierServer.open(at: Vector3, facing: Vector3, opts: any?)
	opts = opts or {}
	nextSeed += 1
	local seed = rng:NextInteger(1, 2 ^ 30) + nextSeed
	local height = rng:NextNumber(Frontier.Rift.Height[1], Frontier.Rift.Height[2])
	local life = Frontier.timeline(serverNow(), opts.Linger)
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
	if opts.Critter then
		anchor:SetAttribute("Critter", opts.Critter)
	end
	if opts.Prey then
		anchor:SetAttribute("Prey", opts.Prey.UserId)
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

-- Critters out and on their way, in the whole Outpost.
local function total(): number
	local count = 0
	for player in critters do
		if player.Parent then
			count += living(player)
		else
			critters[player] = nil
		end
	end
	for player, n in pending do
		if player.Parent then
			count += n
		else
			pending[player] = nil
		end
	end
	return count
end

-- How many more critters may come for `player` out in `band`.
local function roomFor(player: Player, band: string): number
	local cap = Frontier.share(Frontier.Caps[band] or 0, math.max(1, playersOut))
	local mine = living(player) + (pending[player] or 0)
	return math.max(0, math.min(cap - mine, Frontier.Caps.Server - total()))
end

local function keep(player: Player, enemy)
	critters[player] = critters[player] or {}
	table.insert(critters[player], enemy)
end

local function arrived(player: Player)
	local left = (pending[player] or 0) - 1
	pending[player] = if left > 0 then left else nil
end

-- `count` rifts open near `player`, a moment apart, a critter out of each
-- at them (once it has crackled its warning).
local function incursion(player: Player, band: string, count: number)
	pending[player] = (pending[player] or 0) + count
	for i = 1, count do
		task.delay((i - 1) * 0.35, function()
			local root = rootOf(player)
			if not root or not eligible(player) then
				arrived(player)
				return
			end
			local spot = Frontier.riftSpot(root.Position, root.CFrame.LookVector, center(), rng)
			local floor = KaijuServer.ground(spot)
			local critter = KaijuWilds.pickCritter(rng)
			local _, life = FrontierServer.open(floor, root.Position, { Critter = critter, Prey = player })
			task.delay(life.HopAt - serverNow(), function()
				arrived(player)
				local target = rootOf(player)
				if not target or not eligible(player) then
					return -- (gone, or safe: the tear seals empty)
				end
				local toward = flat(target.Position - floor)
				toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
				local enemy = KaijuWilds.spawnBug(floor, {
					Prey = player,
					Band = band,
					Critter = critter,
					Level = Frontier.critterLevel(band, rng),
					Facing = target.Position,
					Hop = toward * 24 + Vector3.new(0, 26, 0),
				})
				if enemy then
					keep(player, enemy)
				end
			end)
		end)
	end
end

-- Their noise is full: an encounter, if they have room (else it waits, full).
local function consider(player: Player, state, band: string)
	local now = os.clock()
	if band == "Core" or state.Noise < 1 or now - state.LastEncounter < Frontier.Noise.Gap then
		return
	end
	local room = roomFor(player, band)
	if room <= 0 then
		state.Noise = 1
		return
	end
	state.Noise = rng:NextNumber(0, Frontier.Noise.Restart)
	state.LastEncounter = now
	incursion(player, band, math.min(room, Frontier.incursion(band, rng:NextNumber())))
end

-- A swing (or a mech's strike of `swings` swings) by `player`: noise, out
-- past the core.
function FrontierServer.swing(player: Player, swings: number?)
	local root = rootOf(player)
	if not root or not eligible(player) then
		return
	end
	local band = Frontier.band(Frontier.distance(root.Position, center()))
	if band == "Core" then
		return
	end
	local state = stateOf(player)
	state.Noise = Frontier.noise(state.Noise, band, swings or 1, 0, rng:NextNumber())
	consider(player, state, band)
	show(player, state)
end

-- Wandering rifts --------------------------------------------------------------------------------------

local function wandering(): number
	local count = 0
	for _, group in wanders do
		count += group.Pending
		for _, enemy in group.Critters do
			if enemy.Alive then
				count += 1
			end
		end
	end
	return count
end

local function closeGroup(group)
	local at = table.find(wanders, group)
	if not at then
		return
	end
	table.remove(wanders, at)
	if group.Lost or group.Killed == 0 then
		return
	end
	-- Cleared: everyone who helped is Rift Charged.
	local ends = serverNow() + Frontier.Charged.Seconds
	for player in group.Helpers do
		if player.Parent then
			player:SetAttribute("RiftCharged", ends)
			Remotes.Notify:FireClient(
				player,
				string.format(
					"Rift cleared! Rift Charged: gems %d%% luckier for %d s.",
					math.floor(Frontier.Charged.Luck * 100 + 0.5),
					Frontier.Charged.Seconds
				)
			)
		end
	end
end

-- A critter is done (KaijuWilds: killed, or slipped back through a rift).
local function critterDone(enemy, killed: boolean, totals)
	local group = groupOf[enemy]
	if not group then
		return
	end
	groupOf[enemy] = nil
	if killed then
		group.Killed += 1
		for player, amount in totals or {} do
			if amount > 0 then
				group.Helpers[player] = true
			end
		end
	else
		group.Lost = true
	end
	if group.Pending > 0 then
		return
	end
	for _, other in group.Critters do
		if other.Alive and groupOf[other] then
			return
		end
	end
	closeGroup(group)
end

-- The frontier tears open by itself near someone out there with room.
local function wander(candidates: { any })
	local free = Frontier.Wander.Max - wandering()
	if free <= 0 or #candidates == 0 then
		return
	end
	local pick = candidates[rng:NextInteger(1, #candidates)]
	local player, root = pick.Player, pick.Root
	local spot = Frontier.wanderSpot(root.Position, center(), rng)
	local band = Frontier.band(Frontier.distance(spot, center()))
	local count = math.min(free, roomFor(player, band), math.max(2, Frontier.incursion(band, rng:NextNumber())))
	if count <= 0 then
		return
	end
	local floor = KaijuServer.ground(spot)
	local critter = KaijuWilds.pickCritter(rng)
	local _, life = FrontierServer.open(floor, root.Position, { Critter = critter, Prey = player, Linger = 4 })
	local group = { Player = player, Critters = {}, Pending = count, Helpers = {}, Killed = 0, Lost = false }
	table.insert(wanders, group)
	pending[player] = (pending[player] or 0) + count
	task.delay(life.HopAt - serverNow(), function()
		for _ = 1, count do
			arrived(player)
		end
		group.Pending = 0
		local target = rootOf(player)
		if not target or not eligible(player) or flat(target.Position - floor).Magnitude > Frontier.Wander.Seal then
			group.Lost = true -- (nobody near: it seals empty)
			closeGroup(group)
			return
		end
		for i = 1, count do
			local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local enemy = KaijuWilds.spawnBug(floor + out * 1.5, {
				Prey = player,
				Band = band,
				Critter = critter,
				Level = Frontier.critterLevel(band, rng),
				Facing = floor + out * 10,
				Hop = out * 14 + Vector3.new(0, 22, 0),
				Wander = { Home = floor, Roam = Frontier.Wander.Roam, Notice = Frontier.Wander.Notice },
				Life = Frontier.Wander.Life,
			})
			if enemy then
				keep(player, enemy)
				groupOf[enemy] = group
				table.insert(group.Critters, enemy)
			end
		end
		if #group.Critters == 0 then
			group.Lost = true
			closeGroup(group)
		end
	end)
end

-- Every half second ------------------------------------------------------------------------------------

local function step(dt: number)
	local out = {}
	for _, player in Players:GetPlayers() do
		local state = stateOf(player)
		local root = rootOf(player)
		if not root or not eligible(player) then
			if player:GetAttribute("Outpost") ~= true and player:GetAttribute("FrontierBand") ~= nil then
				player:SetAttribute("FrontierBand", nil)
			end
			continue
		end
		local band = Frontier.band(Frontier.distance(root.Position, center()))
		if player:GetAttribute("FrontierBand") ~= band then
			player:SetAttribute("FrontierBand", band)
		end
		if band == "Core" then
			-- (Back in the core it quiets down again, over a minute or so.)
			state.Noise = math.max(0, state.Noise - dt / 60)
		else
			table.insert(out, { Player = player, Root = root, Band = band })
			state.Noise = Frontier.noise(state.Noise, band, 0, dt)
		end
	end
	playersOut = #out
	for _, entry in out do
		consider(entry.Player, stateOf(entry.Player), entry.Band)
	end
	for _, player in Players:GetPlayers() do
		show(player, stateOf(player))
	end
	local now = os.clock()
	if now >= nextWander then
		local every = Frontier.Wander.Every
		nextWander = now + rng:NextNumber(every[1], every[2])
		local candidates = {}
		for _, entry in out do
			if roomFor(entry.Player, entry.Band) > 0 then
				table.insert(candidates, entry)
			end
		end
		wander(candidates)
	end
end

-- Vein `index`'s dormant rift, now at `at` (it surfaced somewhere new).
function FrontierServer.moveScar(index: number, at: CFrame)
	if scars[index] then
		scars[index]:Destroy()
	end
	scars[index] = FrontierServer.scar(at)
end

-- A dormant rift at `at` (a vein's scar, facing in): returns its anchor.
function FrontierServer.scar(at: CFrame): BasePart
	nextSeed += 1
	local anchor = Instance.new("Part")
	anchor.Name = "RiftScar"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = at * CFrame.new(0, 5.4, 0)
	anchor:SetAttribute("Seed", 7000 + nextSeed)
	anchor:SetAttribute("Height", 9)
	anchor:SetAttribute("Dormant", true)
	anchor.Parent = folder
	return anchor
end

function FrontierServer.start(site)
	folder = Instance.new("Folder")
	folder.Name = "Rifts"
	folder.Parent = workspace
	-- The dormant rift at each vein: it stays, quietly churning.
	for index, scar in (site and site.Scars) or {} do
		scars[index] = FrontierServer.scar(scar)
	end
	-- A critter slipping back goes through a rift of its own.
	KaijuWilds.rift = function(at: Vector3, facing: Vector3)
		local _, life = FrontierServer.open(KaijuServer.ground(at), facing)
		return life
	end
	KaijuWilds.done = critterDone
	Players.PlayerRemoving:Connect(function(player)
		states[player], critters[player], pending[player] = nil, nil, nil
	end)
	nextWander = os.clock() + rng:NextNumber(Frontier.Wander.Every[1], Frontier.Wander.Every[2])
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
FrontierServer._pending, FrontierServer._wanders, FrontierServer._wander = pending, wanders, wander
FrontierServer._critterDone = critterDone
FrontierServer._setWanderAt = function(at: number)
	nextWander = at
end

return FrontierServer
