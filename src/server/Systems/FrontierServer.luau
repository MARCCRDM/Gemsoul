--[[
	The Outpost's frontier on the server (Shared.Frontier has the rules; see
	docs/frontier.md): rifts tearing open round players out past the core,
	and moon bugs hopping out of them (KaijuWilds.spawnBug).

	  Mining noise   OutpostServer tells this of every swing (swing: on foot
	                 or from a mech's cockpit), and anyone out past the core
	                 makes a little noise each half second besides
	                 (Frontier.noise). Full, an encounter: a swarm that
	                 trickles in. Its rifts open near where they look, one
	                 after another a second or two apart (Frontier.trickle),
	                 each well clear of the tears still open (Rift.Apart),
	                 crackling a moment first, and a critter hops out of
	                 each at them (Swarm.PerRift); a ranged one (Crocodilo)
	                 only ever at the back of a swarm, last (Frontier.Swarm,
	                 Kaiju.wave).
	  Wandering      every Wander.Every seconds or so the frontier tears
	                 open by itself, Wander.Near to Far studs from someone
	                 out there, and a few critters climb out of it one at a
	                 time (Swarm.Out apart) and roam round it for a
	                 minute, going for whoever comes close. Cleared (every
	                 one killed), everyone who helped is Rift Charged
	                 (RiftCharged: the server time it runs out; mined gems
	                 come luckier till then, OutpostServer).

	Stirred up      every swing out there stirs the frontier up too
	                 (Frontier.stir); it settles once they stop or head
	                 back in (Frontier.settle). Stirred up, their swings
	                 make more noise, more critters come through at once and
	                 more may be about them (Frontier.capFor), higher-
	                 levelled (Frontier.Disturbance).

	Gem raids      your whole team knocked out while you're out past the
	                 core (KaijuServer.onTeamDown), no sooner than Raid.Gap
	                 after the last: the critters out for you turn snatchers
	                 (KaijuWilds.raid) and more come through for you at once
	                 (Frontier.raidSize, past your band's cap), snatchers
	                 all. They trip you and grab from your haul: the gems
	                 you mined this trip out (OutpostServer.onGemMined: out
	                 past the core, the newest Raid.Haul.Keep; back in the
	                 core it's safe and starts again). A snatcher's rift
	                 waits for it (Raid.Carry.Wait); bonk or knock it out
	                 first and the gem's back in your pouch.

	Killed         your health run out in the Outpost, by a critter or a
	                 wild kaiju (SparServer.onKnockedOut; not in a spar with
	                 someone, nor in the Rift, which has its own): you lie
	                 dead (Killed), then you're back at base. In the core
	                 that's all (Spar.DeadSeconds; your gems are safe
	                 there). Out past it you're robbed first, as below.
	Robbed         killed out past the core, the critters rob you (Server.Robbery,
	                 Frontier.Rob): those near come for you, and if too few
	                 are, more tear through round you (Frontier.robSpots),
	                 robbers all. Each grabs one gem of your haul and runs
	                 for a tear with it. Then you're back at base (the
	                 Outpost's spawn), whole, your pick out (the kit put
	                 away: FrontierServer.kitAway), and shown what they
	                 took.

	Nobody gets more critters than their band's cap or a fair share of the
	Outpost's (Frontier.share); critters still on their way through count.
	Nobody gets one in the core, in a fight elsewhere, in a spar, or down.
	A critter's level comes from where it came through (Frontier.Levels), and
	rises with the kaiju its player has out (Frontier.teamScale).

	Rifts are anchors in workspace.Rifts, drawn by each player's client
	(RiftTear): an invisible part where the tear hangs, facing whoever drew
	it, with OpenAt, HopAt, CloseAt, EndAt (server time), Seed, Height,
	Critter (the roster id of what's coming through) and Prey (the UserId it
	comes for); the dormant ones at the Rift Veins (site.Scars) carry
	Dormant instead of a timeline, and stay. Each player carries
	FrontierBand (Core, Fringe or Edge), FrontierBiome (the biome they're
	in, Shared.Frontier.Biomes: nil in the core), FrontierNoise and
	FrontierStir (how stirred up: both 0..1, in twentieths) for their HUD,
	and FrontierAlone (true out past the core with no kaiju of theirs out:
	the frontier comes for them harder, Frontier.Alone) and FrontierEngaged
	(true out there in a fight with a wild kaiju, or taming one:
	KaijuWilds.engagedWith; it holds back, Frontier.Engaged: quieter, longer
	between encounters, no wandering rift by them). Anyone in the
	Outpost carries AtBase (back in the Shelter, or the hall under it:
	Frontier.atBase), the only place they heal out of a fight
	(HealthRegen).
	What comes through leans to the biome it comes through in (its own
	kind of critter: KaijuWilds.pickWave).

	  FrontierServer.start(site)
	  FrontierServer.swing(player, swings)   a swing out there (OutpostServer)
	  FrontierServer.mined(player, gem)      a gem mined (OutpostServer): this trip's haul
	  FrontierServer.raid(player) -> boolean   a gem raid on them (their team's all down)
	  FrontierServer.knockedOut(player) -> robbery?   killed: robbed out there, then home
	  FrontierServer.kitAway(player)      back home: the kit away (Main: SparServer.unpair)
	  FrontierServer.open(at, facing, opts?) -> anchor, timeline   a rift on the ground at `at`
	      (opts: Critter, Prey, Linger, Hop; Height its size; Hell, burning
	      the critters' world's colours: the Rift's own)
	  FrontierServer.scar(at) -> anchor   a dormant rift (a vein's)
	  FrontierServer.moveScar(index, at)  vein `index`'s dormant rift moves with it
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local Frontier = require(ReplicatedStorage.Shared.Frontier)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local Outpost = require(ReplicatedStorage.Shared.Outpost)
local Spar = require(ReplicatedStorage.Shared.Spar)
local KaijuServer = require(script.Parent.KaijuServer)
local KaijuWilds = require(script.Parent.KaijuWilds)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Robbery = require(script.Parent.Robbery)

local FrontierServer = {}

local folder: Folder
local base = nil -- the Outpost's site (its Spawn: back at base)
local rng = Random.new()
local nextSeed = 0
-- [player] = { Noise, LastEncounter (os.clock), Shown (the FrontierNoise last
-- set), Stir, LastSwing (os.clock), ShownStir (the FrontierStir last set),
-- Told (the stage they were last told of), ToldAlone (when they were last
-- told they're out alone, os.clock), Wave (this run of waves' last, 0 none:
-- Frontier.Adapt) }
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
-- [player] = this trip out's gems ({ Id }, oldest first): what snatchers take
local hauls: { [Player]: { any } } = {}
-- [player] = when they last had a gem raid (os.clock)
local raids: { [Player]: number } = {}
-- [player] = till when a raid's on for them (os.clock): whatever comes
-- through for them till then is a snatcher too
local raiding: { [Player]: number } = {}
local RAID_FOR = 60

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

-- Out past the core with no kaiju of theirs out (FrontierAlone, set each
-- step): critters come sooner, more of them, higher and harder.
local function alone(player: Player): boolean
	return player:GetAttribute("FrontierAlone") == true
end

-- The kaiju `player` has out, for critters that keep up with them
-- (Frontier.teamScale): their average level and how many there are.
local function teamOf(player: Player)
	local pets = KaijuServer.team(player)
	local sum = 0
	for _, pet in pets do
		sum += pet.Record and pet.Record.Level or 1
	end
	return { Average = if #pets > 0 then sum / #pets else 0, Count = #pets }
end
local function scaleFor(player: Player, band: string)
	return Frontier.teamScale(band, teamOf(player))
end

-- In a fight with a wild kaiju, or taming one (FrontierEngaged, set each
-- step): the frontier holds back (Frontier.Engaged).
local function engaged(player: Player): boolean
	return player:GetAttribute("FrontierEngaged") == true
end

-- The Shelter's footprint (half sizes, x and z), as the site built it.
local function shelterBox(): Vector2
	local shelter = base and base.Shelter
	return if shelter and shelter.Box then shelter.Box else Vector2.new(88, 64)
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
		or player:GetAttribute("RiftRun") ~= nil -- (away in the Rift: its own critters there)
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
		state = {
			Noise = rng:NextNumber(0, Frontier.Noise.Restart),
			LastEncounter = -math.huge,
			Shown = nil,
			Stir = 0,
			LastSwing = -math.huge,
			ShownStir = nil,
			Told = 1,
			Wave = 0,
		}
		states[player] = state
	end
	return state
end

-- Their noise for the HUD's ring and how stirred up it is, in twentieths
-- (not every swing's share).
local function show(player: Player, state)
	local here = player:GetAttribute("Outpost") == true
	local shown = if here then math.floor(math.clamp(state.Noise, 0, 1) * 20 + 0.5) / 20 else nil
	if shown ~= state.Shown then
		state.Shown = shown
		player:SetAttribute("FrontierNoise", shown)
	end
	local stir = if here then math.floor(math.clamp(state.Stir, 0, 1) * 20 + 0.5) / 20 else nil
	if stir ~= state.ShownStir then
		state.ShownStir = stir
		player:SetAttribute("FrontierStir", stir)
	end
end

-- A rift on the ground at `at`, facing `facing`: its anchor (for the
-- clients) and its timeline. Gone once it's sealed. `opts` = { Linger,
-- Critter (roster id), Prey (a Player), Hop (seconds open before the hop:
-- a snatcher's waits for it) }.
function FrontierServer.open(at: Vector3, facing: Vector3, opts: any?)
	opts = opts or {}
	nextSeed += 1
	local seed = rng:NextInteger(1, 2 ^ 30) + nextSeed
	local height = opts.Height or rng:NextNumber(Frontier.Rift.Height[1], Frontier.Rift.Height[2])
	local life = Frontier.timeline(serverNow(), opts.Linger, opts.Hop)
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
	if opts.Hell then
		anchor:SetAttribute("Hell", true) -- (in the critters' own world: RiftTear burns its colours)
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

-- How many more critters may come for `player` out in `band` (more the
-- more stirred up they have it, and more alone).
local function roomFor(player: Player, band: string): number
	local cap = Frontier.share(Frontier.capFor(band, stateOf(player).Stir, alone(player)) + scaleFor(player, band).Extra, math.max(1, playersOut))
	local mine = living(player) + (pending[player] or 0)
	return math.max(0, math.min(cap - mine, Frontier.Caps.Server - total()))
end

local function keep(player: Player, enemy)
	critters[player] = critters[player] or {}
	table.insert(critters[player], enemy)
	-- (Through while a raid's on for them: a snatcher too.)
	if (raiding[player] or 0) > os.clock() then
		KaijuWilds.raid(enemy)
	end
end

local function arrived(player: Player)
	local left = (pending[player] or 0) - 1
	pending[player] = if left > 0 then left else nil
end

-- The ground a rift opens on: a spot from `pick` (tried a few times) whose
-- floor is level with the player's, so a critter doesn't come out on top of
-- a boulder or a container stack.
local function openGround(root: BasePart, pick: () -> Vector3): Vector3
	local level = KaijuServer.ground(root.Position).Y
	local floor
	for _ = 1, 6 do
		floor = KaijuServer.ground(pick())
		if math.abs(floor.Y - level) <= 3 then
			break
		end
	end
	return floor
end

-- Where the tears still open are (to keep a new one clear of them).
local function openTears(): { Vector3 }
	local spots = {}
	for _, anchor in folder:GetChildren() do
		if anchor:IsA("BasePart") and anchor:GetAttribute("Dormant") == nil then
			table.insert(spots, anchor.Position)
		end
	end
	return spots
end

-- The element of the biome round `position` (nil in the core).
local function homeAt(position: Vector3): string?
	local biome = Frontier.biomeAt(position - center())
	return biome and biome.Element
end

-- A swarm of `count` comes for `player`, trickling in: its rifts open near
-- them one after another (Frontier.trickle), each well clear of the tears
-- still open (Rift.Apart), Frontier.Swarm.PerRift critters out of each once
-- it has crackled its warning, any ranged ones last (KaijuWilds.pickWave:
-- mostly the kind of the biome they're in).
-- The kind of critter that counters `player`'s side best (Frontier.read,
-- Frontier.counter): what they and their kaiju hit with, what they're weak to.
local function readSide(player: Player): string?
	local loadout = PlayerData.character(player)
	local weapon = loadout and loadout.WeaponGem and loadout.WeaponGem.Element
	local kaiju = {}
	local profile = PlayerData.get(player)
	if profile then
		for _, record in Kaiju.team(Kaiju.roster(profile)) do
			if not record.Down then
				table.insert(kaiju, record.Element)
			end
		end
	end
	return KaijuWilds.critterKind(Frontier.counter(Frontier.read(weapon, ElementMatchup.profile(loadout), kaiju)))
end
local function counterOf(player: Player): string?
	-- (A side that can't be read, the wave comes as it is.)
	local ok, kind = pcall(readSide, player)
	return if ok then kind else nil
end

-- A swarm of `count` comes for `player`, trickling in (see above). Wave
-- `wave` of their run (Frontier.Adapt): from the second on, more of it is the
-- kind that counters them, and higher-levelled.
local function incursion(player: Player, band: string, count: number, raider: boolean?, waveNumber: number?)
	pending[player] = (pending[player] or 0) + count
	local here = rootOf(player)
	local wave = KaijuWilds.pickWave(count, rng, if here then homeAt(here.Position) else nil)
	local n = waveNumber or 1
	local up = scaleFor(player, band).Levels -- (critters that keep up with their team)
	if n > 1 then
		local kind = counterOf(player)
		wave = Frontier.adapt(wave, n, kind, rng, Kaiju.isRanged)
		-- (Told once a run, as it starts to answer them.)
		if kind and n == 2 then
			local spec = KaijuWilds.critterSpec and KaijuWilds.critterSpec(kind)
			Remotes.Notify:FireClient(
				player,
				string.format("The frontier is learning your team: %s critters are coming for you.", GemConfig.elementName(spec and spec.Element or ""))
			)
		end
	end
	local swarm = Frontier.Swarm
	local tears = math.ceil(#wave / swarm.PerRift)
	local times = Frontier.trickle(tears, rng)
	local spots = {} -- (this swarm's tears so far: the next keeps clear of them too)
	for r = 1, tears do
		local batch = table.move(wave, (r - 1) * swarm.PerRift + 1, math.min(#wave, r * swarm.PerRift), 1, {})
		task.delay(times[r], function()
			local root = rootOf(player)
			if not root or not eligible(player) then
				for _ = 1, #batch do
					arrived(player)
				end
				return
			end
			-- (Open ground level with them first, then clear of the other
			-- tears; nowhere like that, any open ground round about.)
			local level = KaijuServer.ground(root.Position).Y
			local look = root.CFrame.LookVector
			local function level3(at: Vector3): boolean
				return math.abs(KaijuServer.ground(at).Y - level) <= 3
			end
			-- (Round the base: close by, never in the Shelter; out there: the
			-- frontier's tears.)
			local spot = if band == "Core"
				then Frontier.coreSpot(root.Position, look, center(), shelterBox(), rng, level3)
				else Frontier.riftSpot(root.Position, look, center(), rng, openTears(), spots, level3)
			local floor = if spot
				then KaijuServer.ground(spot)
				else openGround(root, function()
					return if band == "Core"
						then Frontier.coreSpot(root.Position, look, center(), shelterBox(), rng)
							or root.Position + look * Frontier.CoreCritters.Near
						else Frontier.riftSpot(root.Position, look, center(), rng) :: Vector3
				end)
			table.insert(spots, floor)
			local _, life = FrontierServer.open(floor, root.Position, {
				Critter = batch[1],
				Prey = player,
				Linger = Frontier.Rift.Linger
					+ (#batch - 1) * swarm.Stagger
					+ (if Kaiju.isRanged(batch[#batch]) then swarm.Last else 0),
			})
			for i, critter in batch do
				local wait = life.HopAt - serverNow() + (i - 1) * swarm.Stagger
				if Kaiju.isRanged(critter) then
					wait += swarm.Last -- (at the back of the swarm)
				end
				task.delay(math.max(0, wait), function()
					arrived(player)
					local target = rootOf(player)
					if not target or not eligible(player) then
						return -- (gone, or safe: the tear seals empty)
					end
					local toward = flat(target.Position - floor)
					toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
					local side = Vector3.new(-toward.Z, 0, toward.X) * ((i - 1) % 3 - 1) * 6
					local enemy = KaijuWilds.spawnBug(floor, {
						Prey = player,
						Band = band,
						Critter = critter,
						Level = Frontier.critterLevel(band, rng, stateOf(player).Stir, alone(player)) + Frontier.adaptLevels(n) + up,
						Facing = target.Position,
						Hop = toward * (if Kaiju.isRanged(critter) then 10 else 24) + side + Vector3.new(0, 26, 0),
						Raider = raider,
					})
					if enemy then
						keep(player, enemy)
					end
				end)
			end
		end)
	end
end

-- Their noise is full: an encounter, if they have room (else it waits, full).
local function consider(player: Player, state, band: string)
	local now = os.clock()
	if band == "Core" or state.Noise < 1 or now - state.LastEncounter < Frontier.gap(alone(player), engaged(player)) then
		return
	end
	local room = roomFor(player, band)
	if room <= 0 then
		state.Noise = 1
		return
	end
	state.Noise = rng:NextNumber(0, Frontier.Noise.Restart)
	-- (The next wave of their run, or a first again after a long quiet.)
	state.Wave = if now - state.LastEncounter > Frontier.Adapt.Reset then 1 else state.Wave + 1
	state.LastEncounter = now
	local size = Frontier.incursion(band, rng:NextNumber(), state.Stir, alone(player))
		+ Frontier.adaptExtra(state.Wave)
		+ scaleFor(player, band).Extra
	incursion(player, band, math.min(room, size), nil, state.Wave)
end

-- A swing at the rocks round the base: now and then a light critter or two
-- (Frontier.CoreCritters), more often for a newcomer, their first on their
-- first few swings. Never from inside the Shelter.
local function coreSwing(player: Player, swings: number)
	if player:GetAttribute("AtBase") == true then
		return
	end
	local state = stateOf(player)
	local rules = Frontier.CoreCritters
	state.CoreSwings = (state.CoreSwings or 0) + swings
	local now = os.clock()
	if now - (state.CoreAt or -math.huge) < rules.Gap or living(player) > 0 or total() >= Frontier.Caps.Server then
		return
	end
	local profile = PlayerData.get(player)
	local stats = profile and (profile :: any).Stats
	local met = stats and tonumber(stats.CoreCritters) or 0
	if rng:NextNumber() >= Frontier.coreChance(met, state.CoreSwings) then
		return
	end
	state.CoreAt, state.CoreSwings = now, 0
	PlayerData.count(player, "CoreCritters")
	incursion(player, "Core", Frontier.coreSize(met, rng), nil, 1)
	if met <= 0 then
		Remotes.Notify:FireClient(player, "Critters! They come for miners. Swing back, or let your kaiju handle them.")
	end
end
FrontierServer._coreSwing = coreSwing

-- A swing (or a mech's strike of `swings` swings) by `player`: noise, out
-- past the core, louder the more stirred up it is, and it stirs it up more.
-- Round the base: the light critters (coreSwing).
function FrontierServer.swing(player: Player, swings: number?)
	local root = rootOf(player)
	if not root or not eligible(player) then
		return
	end
	local band = Frontier.band(Frontier.distance(root.Position, center()))
	if band == "Core" then
		coreSwing(player, swings or 1)
		return
	end
	local state = stateOf(player)
	state.Noise = Frontier.noise(state.Noise, band, swings or 1, 0, rng:NextNumber(), state.Stir, alone(player), engaged(player))
	state.Stir = Frontier.stir(state.Stir, band, swings or 1)
	state.LastSwing = os.clock()
	-- (Told as it gets to each stage, once till it's well settled again.)
	local stage = Frontier.stage(state.Stir)
	if stage > state.Told then
		state.Told = stage
		local note = Frontier.Disturbance.Notes[stage]
		if note then
			Remotes.Notify:FireClient(player, note)
		end
	end
	consider(player, state, band)
	show(player, state)
end

-- Gem raids --------------------------------------------------------------------------------------------

-- A gem `player` mined: out past the core, it joins this trip's haul.
function FrontierServer.mined(player: Player, gem)
	local root = rootOf(player)
	if not root or type(gem) ~= "table" or not gem.Id then
		return
	end
	if Frontier.band(Frontier.distance(root.Position, center())) == "Core" then
		return
	end
	local haul = hauls[player] or {}
	hauls[player] = haul
	table.insert(haul, { Id = gem.Id })
	while #haul > Frontier.Raid.Haul.Keep do
		table.remove(haul, 1)
	end
end

-- Their whole team's down out there: a gem raid. The critters out for
-- them turn snatchers, and more come through, snatchers all.
function FrontierServer.raid(player: Player): boolean
	local root = rootOf(player)
	if not root or not eligible(player) or KaijuServer.battling(player) then
		return false
	end
	local band = Frontier.band(Frontier.distance(root.Position, center()))
	local now = os.clock()
	if band == "Core" or now - (raids[player] or -math.huge) < Frontier.Raid.Gap then
		return false
	end
	raids[player] = now
	raiding[player] = now + RAID_FOR
	for _, enemy in critters[player] or {} do
		KaijuWilds.raid(enemy)
	end
	local count = math.min(Frontier.raidSize(stateOf(player).Stir), math.max(0, Frontier.Caps.Server - total()))
	if count > 0 then
		incursion(player, band, count, true)
	end
	Remotes.Notify:FireClient(
		player,
		"Your kaiju are down... the critters smell your gems! Fight them off or run for the core."
	)
	Remotes.CombatFx:FireAllClients("CritterGiggle", root.Position + Vector3.new(0, 3, 0), "Cackle")
	return true
end

-- A snatcher's grab: the newest loose gem of their haul, out of their pouch.
local function steal(player: Player)
	local haul, profile = hauls[player], PlayerData.get(player)
	if not haul or not profile then
		return nil
	end
	local loose = {}
	for _, gem in GemInventory.available(profile) do
		loose[gem.Id] = true
	end
	local id = Frontier.haulPick(haul, loose, 1)[1]
	local gem = id and PlayerData.removeGem(player, id)
	if not gem then
		return nil
	end
	for i = #haul, 1, -1 do
		if haul[i].Id == id then
			table.remove(haul, i)
		end
	end
	Remotes.Notify:FireClient(
		player,
		string.format("A critter snatched your %s! Bonk it before it hops into its rift.", GemConfig.displayName(gem))
	)
	return gem
end

-- A snatcher dropped it (bonked, or knocked out): back in their pouch,
-- and back in their haul.
local function recover(player: Player?, gem, at: Vector3)
	if not player or not player.Parent or type(gem) ~= "table" then
		return
	end
	PlayerData.returnGem(player, gem)
	local haul = hauls[player] or {}
	hauls[player] = haul
	table.insert(haul, { Id = gem.Id })
	local root = rootOf(player)
	-- (The stone itself flies back: its look goes with it, CritterFx.)
	Remotes.CombatFx:FireAllClients(
		"GemRecovered",
		at,
		if root then root.Position else at,
		GemConfig.ElementColors[gem.Element] or GemConfig.TierColors[gem.Tier],
		{ Id = gem.Id, Element = gem.Element, Tier = gem.Tier, Size = gem.Size, Clarity = gem.Clarity, Cut = gem.Cut }
	)
	Remotes.Notify:FireClient(
		player,
		string.format("Recovered. Your %s is back in your pouch.", GemConfig.displayName(gem))
	)
end

-- A snatcher got through its rift with it: gone.
local function lost(player: Player?, gem)
	if player and player.Parent and type(gem) == "table" then
		Remotes.Notify:FireClient(
			player,
			string.format(
				"A critter got away with your %s! Back in the core, your haul is safe.",
				GemConfig.displayName(gem)
			)
		)
	end
end

-- Robbed while down -------------------------------------------------------------------------------------

-- How many gems of `player`'s haul there are to take (Frontier.Rob.Max at most).
local function takeable(player: Player): number
	local haul, profile = hauls[player], PlayerData.get(player)
	if not haul or not profile then
		return 0
	end
	local loose = {}
	for _, gem in GemInventory.available(profile) do
		loose[gem.Id] = true
	end
	return #Frontier.haulPick(haul, loose, Frontier.Rob.Max)
end

-- Robbers through for a knocked-out `player` (`count`, to `robbery`): tears
-- round them a moment apart, each a critter that hops out at them.
local function robbers(player: Player, count: number, robbery)
	local root = rootOf(player)
	if not root then
		return
	end
	local here = root.Position
	local level = KaijuServer.ground(here).Y
	local band = Frontier.band(Frontier.distance(here, center()))
	local home = homeAt(here)
	for i, spot in Frontier.robSpots(here, count, rng) do
		task.delay((i - 1) * Frontier.Rob.Every, function()
			if robbery.Over or not player.Parent then
				return
			end
			local floor = KaijuServer.ground(spot)
			if math.abs(floor.Y - level) > 3 then
				-- (On top of something: somewhere else round them.)
				floor = openGround(root, function()
					return Frontier.robSpots(here, 1, rng)[1]
				end)
			end
			local critter = KaijuWilds.pickCritter(rng, home)
			local _, life = FrontierServer.open(floor, here, { Critter = critter, Prey = player })
			task.delay(math.max(0, life.HopAt - serverNow()), function()
				if robbery.Over or not player.Parent then
					return -- (it's over: the tear seals empty)
				end
				local target = rootOf(player)
				local at = if target then target.Position else here
				local toward = flat(at - floor)
				toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
				local enemy = KaijuWilds.spawnBug(floor, {
					Prey = player,
					Band = band,
					Critter = critter,
					Level = Frontier.critterLevel(band, rng, stateOf(player).Stir),
					Facing = at,
					Hop = toward * 18 + Vector3.new(0, 24, 0),
					Robbery = robbery,
				})
				if enemy then
					keep(player, enemy)
				end
			end)
		end)
	end
end

-- Puts their combat kit away, their pick out: what you're back at base
-- with (Main sets it to SparServer.unpair, which ends a spar too).
function FrontierServer.kitAway(player: Player)
	player:SetAttribute("Hunt", nil)
	player:SetAttribute("Spar", nil)
end

-- Back at base after you were killed (and robbed, out past the core): on
-- your feet at the Outpost's spawn, whole, your pick out (miner mode, the
-- kit away), with a moment's guard (and this trip's haul is over).
local function sentHome(player: Player)
	FrontierServer.kitAway(player)
	player:SetAttribute("Killed", nil)
	player:SetAttribute("SparDown", nil)
	hauls[player], raiding[player] = nil, nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.Health = humanoid.MaxHealth
	if base and base.Spawn then
		character:PivotTo(base.Spawn)
		local root = rootOf(player)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	local guard = Instance.new("ForceField")
	guard.Name = "SparGuard"
	guard.Visible = false
	guard.Parent = character
	Debris:AddItem(guard, Spar.GuardSeconds)
end

-- Killed in the Outpost by a creature (SparServer.onKnockedOut): they lie
-- dead (Killed), and then they're back at base. Out past the core the
-- critters rob them first; in the core, where their gems are safe, they
-- lie there Spar.DeadSeconds. Not away in the Rift (it has its own:
-- RiftServer), nor in a fight elsewhere. Returns the robbery, if one.
function FrontierServer.knockedOut(player: Player)
	local root = rootOf(player)
	if not root or player:GetAttribute("Outpost") ~= true or player:GetAttribute("RiftRun") ~= nil then
		return nil
	end
	for _, name in { "CombatSession", "MatchId", "DungeonId", "Expedition", "SparWith", "KaijuBattle" } do
		if player:GetAttribute(name) ~= nil then
			return nil
		end
	end
	player:SetAttribute("Killed", true)
	stateOf(player).Wave = 0
	if Frontier.band(Frontier.distance(root.Position, center())) == "Core" then
		player:SetAttribute("SparDown", serverNow() + Spar.DeadSeconds)
		local character = player.Character
		task.delay(Spar.DeadSeconds, function()
			if player.Parent and player.Character == character and player:GetAttribute("Killed") ~= nil then
				sentHome(player)
			end
		end)
		return nil
	end
	Remotes.Notify:FireClient(player, "You were killed... the critters are coming for your gems!")
	Remotes.CombatFx:FireAllClients("CritterGiggle", root.Position + Vector3.new(0, 3, 0), "Cackle")
	return Robbery.start(player, {
		Where = "Outpost",
		Steal = steal,
		Takeable = takeable(player),
		Recover = recover,
		Spawn = function(count, robbery)
			robbers(player, count, robbery)
		end,
		Done = sentHome,
	})
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
	local stir = stateOf(player).Stir
	local lone = alone(player)
	local scale = scaleFor(player, band)
	local count = math.min(free, roomFor(player, band), math.max(2, Frontier.incursion(band, rng:NextNumber(), stir, lone) + scale.Extra))
	if count <= 0 then
		return
	end
	local floor = KaijuServer.ground(spot)
	if math.abs(floor.Y - KaijuServer.ground(root.Position).Y) > 3 then
		-- (On top of something: somewhere else round about.)
		floor = openGround(root, function()
			return Frontier.wanderSpot(root.Position, center(), rng)
		end)
	end
	local wave = KaijuWilds.pickWave(count, rng, homeAt(floor))
	local apart = Frontier.Swarm.Out
	local _, life = FrontierServer.open(
		floor,
		root.Position,
		{ Critter = wave[1], Prey = player, Linger = 4 + (count - 1) * apart } -- (open till the last is out)
	)
	local group = { Player = player, Critters = {}, Pending = count, Helpers = {}, Killed = 0, Lost = false }
	table.insert(wanders, group)
	pending[player] = (pending[player] or 0) + count
	task.delay(life.HopAt - serverNow(), function()
		local target = rootOf(player)
		if not target or not eligible(player) or flat(target.Position - floor).Magnitude > Frontier.Wander.Seal then
			for _ = 1, count do
				arrived(player)
			end
			group.Pending = 0
			group.Lost = true -- (nobody near: it seals empty)
			closeGroup(group)
			return
		end
		local function hop(i: number, critter: string)
			local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local enemy = KaijuWilds.spawnBug(floor + out * 1.5, {
				Prey = player,
				Band = band,
				Critter = critter,
				Level = Frontier.critterLevel(band, rng, stir, lone) + scale.Levels,
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
		-- (Once the last is out: if none is left about, it's over.)
		local function settle()
			for _, enemy in group.Critters do
				if enemy.Alive and groupOf[enemy] then
					return
				end
			end
			group.Lost = group.Lost or group.Killed == 0
			closeGroup(group)
		end
		-- One at a time (Swarm.Out apart): the fighters first, its ranged
		-- ones at the back.
		local order = {}
		for i, critter in wave do
			if not Kaiju.isRanged(critter) then
				table.insert(order, i)
			end
		end
		for i, critter in wave do
			if Kaiju.isRanged(critter) then
				table.insert(order, i)
			end
		end
		for n, i in order do
			task.delay((n - 1) * apart, function()
				arrived(player)
				group.Pending -= 1
				if player.Parent then
					hop(i, wave[i])
				end
				if group.Pending == 0 then
					settle()
				end
			end)
		end
	end)
end

-- Every half second ------------------------------------------------------------------------------------

local function step(dt: number)
	local out = {}
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local state = stateOf(player)
		local root = rootOf(player)
		-- (Back at base or not, for anyone in the Outpost: healing needs it.)
		local here = root and player:GetAttribute("Outpost") == true and player:GetAttribute("RiftRun") == nil
		local atBase = if here then Frontier.atBase(root.Position - center(), shelterBox()) else nil
		if player:GetAttribute("AtBase") ~= atBase then
			player:SetAttribute("AtBase", atBase)
		end
		if not root or not eligible(player) then
			if player:GetAttribute("FrontierAlone") ~= nil then
				player:SetAttribute("FrontierAlone", nil)
			end
			if player:GetAttribute("FrontierEngaged") ~= nil then
				player:SetAttribute("FrontierEngaged", nil)
			end
			-- (Away in the Rift counts as gone from the Outpost.)
			local away = player:GetAttribute("Outpost") ~= true or player:GetAttribute("RiftRun") ~= nil
			if away and player:GetAttribute("FrontierBand") ~= nil then
				player:SetAttribute("FrontierBand", nil)
				player:SetAttribute("FrontierBiome", nil)
			end
			if away then
				hauls[player], raiding[player] = nil, nil -- (gone from the Outpost: the trip's over)
			end
			-- (Down, in a spar or a fight, it settles as if they'd stopped;
			-- gone from the Outpost, as fast as in the core.)
			state.Stir = Frontier.settle(state.Stir, if away then "Core" else "Fringe", dt, now - state.LastSwing)
			state.Told = math.min(state.Told, (Frontier.stage(state.Stir + 0.1)))
			continue
		end
		local band = Frontier.band(Frontier.distance(root.Position, center()))
		if player:GetAttribute("FrontierBand") ~= band then
			player:SetAttribute("FrontierBand", band)
		end
		local biome = Frontier.biomeAt(root.Position - center())
		local biomeId = biome and biome.Id
		if player:GetAttribute("FrontierBiome") ~= biomeId then
			player:SetAttribute("FrontierBiome", biomeId)
		end
		-- Alone out there: no kaiju of theirs out (down, called back, or none
		-- yet). Told when they go out alone, not more than once a minute.
		local lone = if band ~= "Core" and #KaijuServer.team(player) == 0 then true else nil
		if player:GetAttribute("FrontierAlone") ~= lone then
			player:SetAttribute("FrontierAlone", lone)
			if lone and now - (state.ToldAlone or -math.huge) >= 60 then
				state.ToldAlone = now
				Remotes.Notify:FireClient(player, Frontier.Alone.Note)
			end
		end
		-- In a fight with a wild kaiju: the frontier holds back.
		local fighting = if band ~= "Core" and KaijuWilds.engagedWith(player, Frontier.Engaged.For) then true else nil
		if player:GetAttribute("FrontierEngaged") ~= fighting then
			player:SetAttribute("FrontierEngaged", fighting)
		end
		state.Stir = Frontier.settle(state.Stir, band, dt, now - state.LastSwing)
		state.Told = math.min(state.Told, (Frontier.stage(state.Stir + 0.1)))
		if band == "Core" then
			-- (Back in the core it quiets down again, over a minute or so,
			-- and the trip's haul is safe.)
			state.Noise = math.max(0, state.Noise - dt / 60)
			hauls[player], raiding[player] = nil, nil
			state.Wave = 0 -- (home: the next run of waves starts afresh)
		else
			table.insert(out, { Player = player, Root = root, Band = band })
			state.Noise = Frontier.noise(state.Noise, band, 0, dt, nil, nil, lone, fighting)
		end
	end
	playersOut = #out
	for _, entry in out do
		consider(entry.Player, stateOf(entry.Player), entry.Band)
	end
	for _, player in Players:GetPlayers() do
		show(player, stateOf(player))
	end
	if now >= nextWander then
		local every = Frontier.Wander.Every
		nextWander = now + rng:NextNumber(every[1], every[2])
		local candidates = {}
		for _, entry in out do
			-- (Nor by anyone in a fight with a wild kaiju.)
			if roomFor(entry.Player, entry.Band) > 0 and not engaged(entry.Player) then
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
	-- (A vein's is its Rift Gate: it burns the critters' world's colours, RiftTear.)
	anchor:SetAttribute("Hell", true)
	anchor.Parent = folder
	return anchor
end

function FrontierServer.start(site)
	base = site
	folder = Instance.new("Folder")
	folder.Name = "Rifts"
	folder.Parent = workspace
	-- The dormant rift at each vein: it stays, quietly churning.
	for index, scar in (site and site.Scars) or {} do
		scars[index] = FrontierServer.scar(scar)
	end
	-- A critter slipping back goes through a rift of its own.
	KaijuWilds.rift = function(at: Vector3, facing: Vector3, opts: any?)
		local _, life = FrontierServer.open(KaijuServer.ground(at), facing, opts)
		return life
	end
	KaijuWilds.done = critterDone
	-- Gem raids: the team down starts one; snatchers take from the haul,
	-- drop it back, or get away with it through a rift that waits for them.
	KaijuServer.onTeamDown = FrontierServer.raid
	KaijuWilds.steal, KaijuWilds.recover, KaijuWilds.lost = steal, recover, lost
	KaijuWilds.escape = function(at: Vector3, facing: Vector3, wait: number, hell: boolean?)
		local _, life = FrontierServer.open(KaijuServer.ground(at), facing, { Hop = wait, Linger = 1.5, Hell = hell })
		return life
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player], critters[player], pending[player] = nil, nil, nil
		hauls[player], raids[player], raiding[player] = nil, nil, nil
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
FrontierServer._hauls, FrontierServer._raids = hauls, raids
FrontierServer._steal, FrontierServer._recover, FrontierServer._lost = steal, recover, lost
FrontierServer._takeable, FrontierServer._sentHome = takeable, sentHome
FrontierServer._setWanderAt = function(at: number)
	nextWander = at
end

return FrontierServer
