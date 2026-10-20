--[[
	The Outpost's frontier (pure, for the server, the client and tests): how
	far out you are, what grows out there, and the rifts that tear open
	around you. See docs/frontier.md.

	The quarry is three bands round its middle:
	  Core    the outpost, the landing pad and the field round them (inside
	          Core studs): safe, no rifts, the plainest rocks
	  Fringe  out to EdgeFrom: rifts start tearing open round you, and the
	          rocks run richer (Bands.Fringe.Luck on every gem they pay)
	  Edge    out to the walls: rifts open often and more critters come
	          through at once; the richest rocks

	Outcrops: past the field round the outpost, rocks grow in natural
	seams of two to five along a grain (Outcrop), thicker on rich ground (a
	smooth noise field), bigger further out, with a few lone rocks between
	and some leading out of the core like stepping stones. Their crystals
	warm from cyan to gold to rose the further out they grow, and glowing
	cracks in the ground round each make them sparkle from afar. What pulls
	you outward is what you see, not a road.

	Rift Veins: three of six rich violet rocks each, by the walls, far apart
	(Veins), each round a dormant rift with a beam of light over it you can
	see from the outpost. A vein moves somewhere new once it's mined out, and
	every ten minutes or so anyway (the Outpost checks a ring of sites for
	room when it's built: Frontier.veinSites, veinAt). One of the three is
	guarded (Veins.Guarded: its rocks luckier still, Bands.Guarded, its
	beam red): a wild kaiju sleeps in front of it and wakes on the third
	swing there (Guardian), going for the miners too. Beat it or tame it
	and the vein is yours until it moves on; its guardian goes with it.

	Rifts: every critter comes through a rift of its own, a ragged tear in
	the air (never the same shape twice). It opens and crackles for a
	moment first (Rift.Hop: the warning), the critter hops out at whoever
	drew it, the tear lingers (Rift.Linger) and seals (Rift.Close). Rifts
	come two ways, only round players out past the core:
	  Mining noise   every swing out there makes noise (Noise.Swing: more at
	                 the edge), and a little more trickles in each second
	                 you're out there (Noise.Idle). Full, an encounter:
	                 critters tear through near you (Frontier.incursion),
	                 one at a time, each out of a tear of its own, the
	                 tears well apart (Rift.Apart) and opening a second or
	                 two after one another (Swarm, Frontier.trickle).
	  Wandering      every so often the frontier tears open by itself
	                 (Wander), 35 to 70 studs from someone out there: a few
	                 critters climb out of it one by one and roam that patch
	                 for about a minute, going for whoever comes close. Go
	                 round it, or bring your kaiju.
	Stirred up: the longer you mine out there, the harder the frontier
	pushes back (Disturbance): every swing stirs it, and it settles again
	once you stop or head back to the core. Stirred up, your swings draw
	encounters sooner, more critters come through at once and more may be
	about you, and they come higher-levelled.
	A critter's level comes from where it came through (Levels: the edge's
	are a real step up), and so do its EXP and coins (Frontier.critterExp,
	Coins). Clearing a wandering rift leaves everyone who helped Rift
	Charged (Charged: luckier gems for a while). A pickaxe can bonk a
	critter (Bonk) so a miner without a kaiju isn't helpless.

	Gem raids (Raid): your whole team knocked out while you're out past
	the core, the critters smell your gems. More come through for you at
	once (raidSize), and every critter out for you turns gem snatcher: it
	winds up a TRIP at your legs (on its cast bar: step away or bonk it)
	and, landing it, knocks you down. Down (tripped, or beaten down), the
	snatchers run in and each grabs one of the gems you mined this trip
	out (your haul: the newest first, never one on your gear; at most
	Snatch.Max a knock-down), holds it over its head, giggling, and runs
	for a rift that tears open a little way off (escapeSpot), waiting
	there for it (Carry.Wait). Bonk it or knock it out before it hops in
	and the gem's yours again; let it hop in and it's gone. Back in the
	core your haul is safe (it starts again on your next trip out).

	  Frontier.distance(position, center) -> studs across the ground
	  Frontier.band(distance) -> "Core" | "Fringe" | "Edge"
	  Frontier.zoneOf(distance, vein?) -> a Shared.Outpost.Zones id
	  Frontier.field(rng) -> (offset) -> 0..1   how rich the ground is
	  Frontier.outcrops(rng) -> { outcrop }, { Vector3 }   the outcrops and the lone rocks
	  Frontier.veinSites(rng) -> { angle }   where veins may surface, round the walls
	  Frontier.veinAt(angle, rng) -> { Vector3 }, Vector3   a vein's rocks there, and its scar
	  Frontier.apart(a, b) -> radians between two angles round the middle
	  Frontier.pickSite(sites, taken, others, rng) -> index?   where a vein goes next
	  Frontier.compass(angle) -> "north-east" ...   a direction from the middle
	  Frontier.noise(noise, band, swings, seconds, roll?, stir?) -> noise   (an encounter at 1)
	  Frontier.stir(stir, band, swings) -> stir   (0..1: how stirred up)
	  Frontier.settle(stir, band, seconds, quiet) -> stir   `quiet` seconds since a swing
	  Frontier.stage(stir) -> index, { At, Name, Extra, Cap }
	  Frontier.incursion(band, roll, stir?) -> critters at once
	  Frontier.capFor(band, stir?) -> critters allowed round one player
	  Frontier.share(cap, playersOut) -> critters at once round one player
	  Frontier.critterLevel(band, rng, stir?) -> level
	  Frontier.critterExp(level, band, today) -> EXP for a kaiju that fought it
	  Frontier.riftSpot(position, facing, center, rng, others?, past?, usable?) -> Vector3?   where a rift opens
	  Frontier.trickle(count, rng?) -> { seconds }   when each of an encounter's tears opens
	  Frontier.raidSize(stir?) -> critters through for a gem raid
	  Frontier.haulPick(haul, loose, max) -> { gem id }   what snatchers can take, newest first
	  Frontier.escapeSpot(from, player, center, rng) -> Vector3   where a snatcher's rift opens
	  Frontier.wanderSpot(position, center, rng) -> Vector3   where a wandering rift opens
	  Frontier.timeline(at, linger?) -> { OpenAt, HopAt, CloseAt, EndAt }
	  Frontier.openness(timeline, now) -> 0..1   how wide a tear is
	  Frontier.tear(seed, height) -> shape   a tear's ragged outline
]]
local Frontier = {}

Frontier.Core = 150 -- studs from the middle: inside, no rifts
Frontier.EdgeFrom = 300
Frontier.Rim = 428 -- the furthest out a rock or a rift goes (the walls start at 440)
Frontier.Safe = 12 -- critters give up on prey this far inside the core

local CYAN = Color3.fromRGB(110, 220, 255)
local GOLD = Color3.fromRGB(255, 200, 90)
local ROSE = Color3.fromRGB(255, 120, 190)
local RIFT = Color3.fromRGB(215, 90, 255)
local GUARD = Color3.fromRGB(255, 86, 96)

-- Each band's name, its crystals' colour, and the luck its rocks add (on
-- every gem: the rocks are the same mix everywhere, so this is what pays
-- for going out).
Frontier.Bands = {
	Core = { Name = "Outpost Core", Color = CYAN, Luck = 0 },
	Fringe = { Name = "The Fringe", Color = GOLD, Luck = 0.2 },
	Edge = { Name = "The Edge", Color = ROSE, Luck = 0.4 },
	Vein = { Name = "Rift Vein", Color = RIFT, Luck = 0.75 },
	Guarded = { Name = "Guarded", Color = GUARD, Luck = 1.1 }, -- (a short name: it fits a rock's label)
}
Frontier.BandOrder = { "Core", "Fringe", "Edge" }
Frontier.RiftColor = RIFT

-- The Loop: four biomes round the core, a quarter of the quarry each,
-- between the four Spokes (the Crossroads: haul roads due north, east, south
-- and west out of the core; the ring road at 260 runs round through all
-- four). Going round clockwise from the north-east (Angle: each one's
-- middle), each is weak to the one before it (Shared.ElementMatchup:
-- Thermal beats Cryo, Cryo beats Ion, Ion beats Corrosive, Corrosive beats
-- Thermal), so what you find in one does well in the next. Out there a
-- mined gem is of its biome's element Biome.Bias of the time (the other
-- three share the rest), and so are its wild kaiju; its critters lean the
-- same way (Biome.Critter). The core is the Hub: all four alike.
--   Label    its ground's name on the crossroads signs
--   Ground   the regolith's tint out there, and its Material (Enum.Material's name)
--   Stone    its rocks' basalt
--   Glow     its colour (signs, banners, its props' glow)
--   Tint     the screen's grade there, Ambient the outdoor light and Fog
--            its haze's colour
--   Line     the banner's line as you cross into it
--   Terrain  its ground in Roblox terrain (Frontier.ground): Main, with
--            patches of Second (where the patch noise is under Share), and
--            its lie of the land (Relief, up to Height studs, away from
--            anything standing: OutpostWorld)
local NORTH = -math.pi / 2
Frontier.Spokes = { NORTH, 0, math.pi / 2, math.pi }
Frontier.Biomes = {
	{
		Id = "Ashfall",
		Name = "Ashfall",
		Label = "Thermal ground",
		Element = "Fire",
		Angle = -math.pi / 4,
		Ground = Color3.fromRGB(70, 58, 58),
		Material = "CrackedLava",
		Stone = Color3.fromRGB(96, 62, 54),
		Glow = Color3.fromRGB(255, 122, 58),
		Tint = Color3.fromRGB(255, 232, 214),
		Ambient = Color3.fromRGB(184, 146, 132),
		Fog = Color3.fromRGB(112, 78, 64),
		Line = "Thermal ground  ·  Thermal gems, critters and kaiju",
		Terrain = { Main = "CrackedLava", Second = "Basalt", Share = 0.42, Relief = "Cones", Height = 6 },
	},
	{
		Id = "Rimefrost",
		Name = "Rimefrost",
		Label = "Cryo ground",
		Element = "Frost",
		Angle = math.pi / 4,
		Ground = Color3.fromRGB(196, 212, 230),
		Material = "Snow",
		Stone = Color3.fromRGB(112, 132, 166),
		Glow = Color3.fromRGB(130, 214, 255),
		Tint = Color3.fromRGB(228, 242, 255),
		Ambient = Color3.fromRGB(150, 176, 210),
		Fog = Color3.fromRGB(160, 182, 210),
		Line = "Cryo ground  ·  Cryo gems, critters and kaiju",
		Terrain = { Main = "Snow", Second = "Glacier", Share = 0.38, Relief = "Drifts", Height = 4.5 },
	},
	{
		Id = "Stormglass",
		Name = "Stormglass",
		Label = "Ion ground",
		Element = "Shock",
		Angle = 3 * math.pi / 4,
		Ground = Color3.fromRGB(96, 90, 122),
		Material = "Salt",
		Stone = Color3.fromRGB(100, 92, 136),
		Glow = Color3.fromRGB(255, 222, 84),
		Tint = Color3.fromRGB(250, 246, 228),
		Ambient = Color3.fromRGB(164, 154, 190),
		Fog = Color3.fromRGB(112, 102, 150),
		Line = "Ion ground  ·  Ion gems, critters and kaiju",
		Terrain = { Main = "Salt", Second = "Limestone", Share = 0.4, Relief = "Ridges", Height = 4 },
	},
	{
		Id = "Blightwood",
		Name = "Blightwood",
		Label = "Corrosive ground",
		Element = "Poison",
		Angle = 5 * math.pi / 4,
		Ground = Color3.fromRGB(74, 90, 62),
		Material = "Mud",
		Stone = Color3.fromRGB(70, 90, 66),
		Glow = Color3.fromRGB(140, 232, 92),
		Tint = Color3.fromRGB(234, 255, 228),
		Ambient = Color3.fromRGB(140, 166, 132),
		Fog = Color3.fromRGB(96, 116, 78),
		Line = "Corrosive ground  ·  Corrosive gems, critters and kaiju",
		Terrain = { Main = "Mud", Second = "LeafyGrass", Share = 0.45, Relief = "Hummocks", Height = 3.5 },
	},
}
-- Bias: a biome's share of its own element (gems, wild kaiju); Critter: the
-- share of an encounter's critters that are its own kind (when that kind
-- fights up close: an Ion biome's own, the ranged one, comes in more often
-- at the back instead); Blend: studs either side of the core's edge over
-- which its look comes in.
Frontier.Biome = { Bias = 0.6, Critter = 0.6, Blend = 60 }
local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }

-- The ground under the Loop, in Roblox terrain (OutpostWorld lays it):
--   Cell    studs a side of one column of it (terrain's voxel)
--   Reach   studs out from the middle it's laid to (under the quarry walls)
--   Depth   studs of it under the quarry floor
--   Sway    radians each border between two biomes swings off its spoke,
--           far out (two waves, Waves radians of each per stud out, each
--           border its own: they don't mirror each other); Calm studs past
--           the core's edge it starts swaying, and from Calm[2] on fully,
--           so at a spoke's mouth (its signs) it's on the road
--   Seam    studs either side of a border over which the two grounds mix,
--           swelling and narrowing along it
--   Edge    the core's regolith gives way to a biome's ground over Edge[1]
--           studs round Frontier.Core, its rim ragged by Edge[2]
--   Patch   studs across a ground's patches of its second material
--   Hub     the core's own ground (as a biome's Terrain)
--   Colors  each material's colour (Terrain:SetMaterialColor)
Frontier.Ground = {
	Cell = 4,
	Reach = 452,
	Depth = 8,
	Sway = { 0.24, 0.12 },
	Waves = { 1 / 70, 1 / 31 },
	Calm = { 20, 170 },
	Seam = { 14, 40 },
	Edge = { 24, 12 },
	Patch = 26,
	Seed = 2718,
	Hub = { Main = "Slate", Second = "Concrete", Share = 0.38, Height = 0 },
	Colors = {
		Slate = Color3.fromRGB(122, 124, 132),
		Concrete = Color3.fromRGB(98, 100, 110),
		CrackedLava = Color3.fromRGB(78, 56, 50),
		Basalt = Color3.fromRGB(58, 46, 46),
		Snow = Color3.fromRGB(206, 220, 236),
		Glacier = Color3.fromRGB(150, 192, 228),
		Salt = Color3.fromRGB(112, 104, 146),
		Limestone = Color3.fromRGB(146, 134, 180),
		Mud = Color3.fromRGB(70, 86, 56),
		LeafyGrass = Color3.fromRGB(84, 116, 54),
	},
}

-- Outcrops (angles round the middle are radians: 0 east, a quarter turn
-- south): Count of them From to To studs out, Apart studs between their
-- middles, Step studs between their rocks; Lone of the frontier's rocks
-- set alone, Stones of those at the spokes' mouths (Spokes), leading out of
-- the core.
Frontier.Outcrop = {
	From = 100,
	To = 412,
	Count = 46,
	Apart = 36,
	Step = 13.5,
	Lone = 0.15,
	Stones = 8,
}
-- Rift Veins: Count at once, Rocks each, moving every Every seconds (give
-- or take Wobble) if not mined out first; at least Apart radians from each
-- other round the middle; Sites places round the walls to choose from;
-- the one (by index) a guardian sleeps at.
Frontier.Veins = { Count = 3, Rocks = 6, Every = 600, Wobble = 60, Apart = math.rad(70), Sites = 12, Guarded = 1 }
-- The guarded vein's wild kaiju (KaijuWilds): its level (one loses narrowly
-- to a level-25 kaiju or two level-10s), the swing at its vein it wakes on,
-- and where it sleeps: Home studs in from its dormant rift.
Frontier.Guardian = { Levels = { 16, 20 }, Wake = 3, Home = 30 }

-- Rifts: seconds it takes to open, until the critter hops out (it
-- crackles all that while: the warning), then lingers and seals; how tall
-- (studs); and where round a player it opens (studs away, and how far
-- either side of where they face), at least Apart studs from any other
-- tear still open (the best of Tries spots, if it's crowded).
Frontier.Rift = {
	Open = 0.55,
	Hop = 1.5,
	Linger = 1.8,
	Close = 0.45,
	Height = { 4.5, 7.5 },
	Near = 16,
	Far = 30,
	Spread = math.rad(110),
	Apart = 16,
	Tries = 32,
}
-- Mining noise: what a swing out in a band adds (an encounter at 1: about
-- 1 in 35 swings in the fringe, 1 in 17 at the edge, each swing's share
-- anywhere from 60% to 140% so they don't come like clockwork), and what a
-- second out there adds, mining or not (about one every 7 minutes in the
-- fringe, 3 at the edge). After an encounter it starts again from a little
-- (Restart), and the next can't come for Gap seconds.
Frontier.Noise = {
	Swing = { Fringe = 1 / 35, Edge = 1 / 17 },
	Idle = { Fringe = 1 / 420, Edge = 1 / 180 },
	Spread = { 0.6, 1.4 },
	Restart = 0.12,
	Gap = 8,
}
-- Critters at once round one player (more stay away), and in the whole
-- Outpost, shared fairly between those out there. They come as swarms
-- (each one weak: Shared.Kaiju.Bug), but each is a whole brainrot body:
-- the Outpost's cap keeps them from lagging it.
Frontier.Caps = { Fringe = 5, Edge = 7, Server = 22 }
-- A swarm trickles in, never all at once: PerRift critters out of each
-- tear (Stagger seconds apart), the tears opening one after another, Every
-- seconds apart (somewhere in that range), each well clear of the others
-- (Rift.Apart); its ranged ones (Shared.Kaiju.wave) come last, Last seconds
-- after the rest of their tear. A wandering rift's critters climb out of
-- its one tear one at a time, Out seconds apart.
Frontier.Swarm = { PerRift = 1, Stagger = 0.3, Every = { 1.1, 1.8 }, Last = 1.2, Out = 0.6 }
-- Stirring the frontier up: the longer you mine out there, the harder it
-- pushes back. Every swing past the core stirs it (PerSwing: full after
-- about 400 swings in the fringe, 250 at the edge, six or four minutes of
-- steady mining); it holds while you keep at it and settles once you stop
-- (after Rest seconds without a swing, Fade a second: two minutes from
-- full; in the core, CoreFade: half a minute). Stirred up, your swings make
-- more noise (each swing's noise times 1 + Noise x the stir: twice as many
-- encounters, full), and critters come Levels levels higher (full; a share
-- of it on the way). Each Stage adds Extra critters to every encounter and
-- lets Cap more about you at once (still within the Outpost's cap); Notes
-- are what you're told as it gets to each.
Frontier.Disturbance = {
	PerSwing = { Fringe = 1 / 400, Edge = 1 / 250 },
	Rest = 20,
	Fade = 1 / 120,
	CoreFade = 1 / 30,
	Noise = 1,
	Levels = 4,
	Stages = {
		{ At = 0, Name = "Calm", Extra = 0, Cap = 0 },
		{ At = 0.25, Name = "Restless", Extra = 0, Cap = 0 },
		{ At = 0.5, Name = "Stirred up", Extra = 2, Cap = 2 },
		{ At = 0.8, Name = "Swarming", Extra = 3, Cap = 4 },
	},
	Notes = {
		[2] = "The frontier is restless: critters come sooner.",
		[3] = "The frontier is stirred up: more critters, and tougher.",
		[4] = "The frontier is swarming! Head back to the core to let it settle.",
	},
}
-- A critter with no one to fight this long slips back through a rift; none
-- stays longer than Life seconds.
Frontier.Leave, Frontier.Life = 4, 90
-- Its level by where it came through: the edge's are for a kaiju of about
-- level 8 and up.
Frontier.Levels = { Fringe = { 1, 4 }, Edge = { 9, 13 } }
-- Critters from the edge are tougher, and worth more.
Frontier.Boost = { Fringe = { Health = 1, Damage = 1, Exp = 1 }, Edge = { Health = 1.25, Damage = 1.2, Exp = 1.5 } }
-- EXP for each kaiju that fought one: Base + PerLevel x its level (times
-- its band's Boost.Exp); a quarter after Daily critters a day.
Frontier.Exp = { Base = 1.6, PerLevel = 0.5, Daily = 150, After = 0.25 }
-- Coins to whoever did the most to one, by band (a day's cap: Shared.Kaiju.Bug.DailyCoins).
Frontier.Coins = { Fringe = 1, Edge = 2, Guardian = 40 }
-- Wandering rifts: one every Every seconds or so somewhere out there, at
-- most Max critters out of them at once (of the Server cap), Near to Far
-- studs from whoever it's tied to. Its critters roam Roam studs round it
-- for Life seconds, going for anyone who comes within Notice; it seals
-- empty if its player is further than Seal studs off when they'd hop out.
Frontier.Wander = { Every = { 40, 80 }, Max = 6, Near = 35, Far = 70, Roam = 26, Notice = 30, Life = 60, Seal = 110 }
-- Clearing a wandering rift: everyone who helped is Rift Charged, gems
-- this much luckier for Seconds.
Frontier.Charged = { Luck = 0.1, Seconds = 60 }
-- The pickaxe on a critter: Share of its health, every Cooldown seconds,
-- knocked Knock studs back; from Reach studs (the client offers it at
-- Offer). It costs no swings.
Frontier.Bonk = { Share = 0.12, Cooldown = 0.6, Knock = 10, Reach = 8, Offer = 6 }
-- Gem raids: your team all knocked out out there. Size critters through
-- (StirBonus more, stirred right up), no sooner than Gap seconds after the
-- last. Trip: from Range studs, a Windup on its cast bar, then you're down
-- for Down seconds (Damage: a share of its bite); each critter every Every
-- seconds, and Gap seconds at least between two trips on you. Snatch:
-- Max gems a knock-down, grabbed from Reach studs after Windup. Haul: the
-- last Keep gems you mined this trip out. Carry: a snatcher runs at Speed
-- for a rift Away studs off, which waits Wait seconds for it, giggling
-- every Giggle seconds.
Frontier.Raid = {
	Size = 4,
	StirBonus = 2,
	Gap = 75,
	Trip = { Range = 6.5, Windup = 0.75, Every = { 5, 8 }, Gap = 3, Down = 4, Damage = 0.4 },
	Snatch = { Max = 3, Reach = 5, Windup = 0.5, Rush = 45 },
	Haul = { Keep = 12 },
	Carry = { Speed = 13, Away = { 26, 38 }, Wait = 6, Giggle = { 1.3, 2.4 } },
}

function Frontier.distance(position: Vector3, center: Vector3): number
	return Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude
end

function Frontier.band(distance: number): string
	if distance < Frontier.Core then
		return "Core"
	elseif distance < Frontier.EdgeFrom then
		return "Fringe"
	end
	return "Edge"
end

-- The rock mix and luck for a spot (Shared.Outpost.Zones ids).
function Frontier.zoneOf(distance: number, vein: boolean?): string
	if vein then
		return "Vein"
	end
	local band = Frontier.band(distance)
	return if band == "Core" then "Common" else band
end

-- The biome whose quarter `angle` (radians round the middle) is in (on a
-- spoke, the one clockwise of it).
function Frontier.biomeOf(angle: number)
	local turn = (angle - NORTH) % (math.pi * 2)
	return Frontier.Biomes[math.floor(turn / (math.pi / 2)) % #Frontier.Biomes + 1]
end

-- The ground's own noise: a lattice of values (0..1) from a hash, the same
-- on every machine, and smooth noise over it (`size` studs a cell).
local function mul32(a: number, b: number): number
	-- (a * b mod 2^32, exactly: every partial product stays under 2^53.)
	local aLo, aHi = a % 65536, a // 65536
	local bLo, bHi = b % 65536, b // 65536
	return (aLo * bLo + ((aHi * bLo + aLo * bHi) % 65536) * 65536) % 4294967296
end
local function lattice(ix: number, iz: number, salt: number): number
	local h =
		bit32.bxor(mul32(ix % 4294967296, 0x8DA6B343), mul32(iz % 4294967296, 0xD8163841), mul32(salt, 0xCB1AB31F))
	-- (murmur3's finish: every bit of the input stirs every bit out.)
	h = mul32(bit32.bxor(h, bit32.rshift(h, 16)), 0x85EBCA6B)
	h = mul32(bit32.bxor(h, bit32.rshift(h, 13)), 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 16)) / 4294967296
end
local function noise(x: number, z: number, size: number, salt: number): number
	local fx, fz = x / size, z / size
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
	local a, b = lattice(ix, iz, salt), lattice(ix + 1, iz, salt)
	local c, d = lattice(ix, iz + 1, salt), lattice(ix + 1, iz + 1, salt)
	local near = a + (b - a) * tx
	return near + (c + (d - c) * tx - near) * tz
end
-- (Two octaves: patches with ragged edges.)
local function patchy(x: number, z: number, size: number, salt: number): number
	return noise(x, z, size, salt) * 0.68 + noise(x, z, size / 2.3, salt + 101) * 0.32
end
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function wrap(angle: number): number
	return (angle + math.pi) % (math.pi * 2) - math.pi
end

-- Each border's own waves (its strength in each, their phases), from Seed.
local borderWaves = {}
do
	local state = Frontier.Ground.Seed
	local function nextValue(): number
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	for k = 1, #Frontier.Spokes do
		borderWaves[k] = {
			0.7 + nextValue() * 0.6,
			0.7 + nextValue() * 0.6,
			nextValue() * math.pi * 2,
			nextValue() * math.pi * 2,
			nextValue() * math.pi * 2,
		}
	end
end

-- Where border `k` runs (an angle round the middle) `r` studs out: on
-- Spokes[k] at the core's edge, swaying off it further out. Biomes[k] lies
-- clockwise of it, the one before counterclockwise.
function Frontier.border(k: number, r: number): number
	local ground, w = Frontier.Ground, borderWaves[k]
	local calm = smooth((r - Frontier.Core - ground.Calm[1]) / (ground.Calm[2] - ground.Calm[1]))
	local sway = ground.Sway[1] * w[1] * math.sin(r * ground.Waves[1] + w[3])
		+ ground.Sway[2] * w[2] * math.sin(r * ground.Waves[2] + w[4])
	return Frontier.Spokes[k] + calm * sway
end

-- How wide the seam along border `k` is `r` studs out (studs either side).
local function seamWidth(k: number, r: number): number
	local seam = Frontier.Ground.Seam
	return seam[1] + (seam[2] - seam[1]) * (0.5 + 0.5 * math.sin(r / 23 + borderWaves[k][5]))
end

-- The biome whose ground `x`, `z` (studs from the middle) is on, past its
-- borders (index into Frontier.Biomes), and how its ground mixes there with
-- its neighbour's across the nearer border: { [index] = weight }, adding up
-- to 1 (half and half on a border).
local function mixAt(x: number, z: number): (number, { [number]: number })
	local n = #Frontier.Biomes
	local r = math.sqrt(x * x + z * z)
	local angle = math.atan2(z, x)
	local off = {} -- (how far round from each border, radians)
	for k = 1, n do
		off[k] = wrap(angle - Frontier.border(k, r))
	end
	local home = 1
	for i = 1, n do
		if off[i] >= 0 and off[i % n + 1] < 0 then
			home = i
		end
	end
	local into = off[home] * r -- (studs in from its start border)
	local before = -off[home % n + 1] * r -- (studs to its end border)
	local weights = {}
	if into <= before then
		local t = smooth(0.5 + 0.5 * into / seamWidth(home, r))
		weights[home], weights[(home - 2) % n + 1] = t, 1 - t
	else
		local next = home % n + 1
		local t = smooth(0.5 + 0.5 * before / seamWidth(next, r))
		weights[home], weights[next] = t, 1 - t
	end
	return home, weights
end

-- The biome at `offset` from the middle (across the ground), past its
-- swaying borders: nil in the core, the Hub.
function Frontier.biomeAt(offset: Vector3)
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < Frontier.Core then
		return nil
	end
	local home = mixAt(offset.X, offset.Z)
	return Frontier.Biomes[home]
end

-- How much each biome's look counts at `offset`: a weight for each, in
-- Frontier.Biomes' order, adding up to 1 (half and half on a border, its
-- own deep in it), and how far in that look has come (0 well inside the
-- core, 1 once Biome.Blend studs further out).
function Frontier.biomeMix(offset: Vector3): ({ number }, number)
	local _, mix = mixAt(offset.X, offset.Z)
	local weights = {}
	for i in Frontier.Biomes do
		weights[i] = mix[i] or 0
	end
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local blend = Frontier.Biome.Blend
	return weights, math.clamp((distance - (Frontier.Core - blend / 2)) / blend, 0, 1)
end

-- Each ground's lie of the land (0..1 of its Height) at `x`, `z`.
local RELIEF = {
	-- Ashfall: cinder cones, here and there.
	Cones = function(x: number, z: number): number
		return smooth((noise(x, z, 46, 11) - 0.6) / 0.22)
	end,
	-- Rimefrost: long drifts, blown one way.
	Drifts = function(x: number, z: number): number
		local u, v = x * 0.8 + z * 0.6, -x * 0.6 + z * 0.8
		return smooth((noise(u * 0.45, v * 1.6, 30, 12) - 0.52) / 0.26)
	end,
	-- Stormglass: thin ridges of salt.
	Ridges = function(x: number, z: number): number
		local ridge = 1 - math.abs(noise(x, z, 58, 13) * 2 - 1)
		return smooth((ridge - 0.72) / 0.22)
	end,
	-- Blightwood: soft hummocks, close together.
	Hummocks = function(x: number, z: number): number
		return smooth((noise(x, z, 20, 14) - 0.55) / 0.25)
	end,
}

-- The ground `x`, `z` studs from the middle is (Roblox terrain): its
-- material's name; whose ground it is (0 the core's, else an index into
-- Frontier.Biomes: across a seam, either neighbour's, mixed in blotches);
-- and how high the land would rise there (studs, before OutpostWorld keeps
-- it flat round anything standing).
function Frontier.ground(x: number, z: number): (string, number, number)
	local ground = Frontier.Ground
	local r = math.sqrt(x * x + z * z)
	local angle = math.atan2(z, x)
	local rim = Frontier.Core + ground.Edge[2] * (0.6 * math.sin(angle * 5 + 1.3) + 0.4 * math.sin(angle * 12 + 4.1))
	local out = smooth((r - rim) / ground.Edge[1] + 0.5) -- (0 in the core, 1 out in a biome)
	local home, weights = mixAt(x, z)
	local height = 0
	for i, weight in weights do
		local spec = Frontier.Biomes[i].Terrain
		height += weight * spec.Height * RELIEF[spec.Relief](x, z)
	end
	-- (The land only rises well out of the core.)
	height *= smooth((r - Frontier.Core - 20) / 40)
	local whose = 0
	if patchy(x, z, 18, 21) < out then
		whose = home
		for i, weight in weights do
			if i ~= home and patchy(x, z, 16, 22) < weight then
				whose = i
			end
		end
	end
	local spec = if whose == 0 then ground.Hub else Frontier.Biomes[whose].Terrain
	local material = if patchy(x, z, ground.Patch, 30 + whose) < spec.Share then spec.Second else spec.Main
	return material, whose, height
end

-- An element for a wild kaiju born where `home` (a biome's element) holds:
-- `home` Biome.Bias of the time, else one of the other three alike; no
-- home (the core), any of the four alike.
function Frontier.pickElement(home: string?, rng): string
	if home and rng:NextNumber() < Frontier.Biome.Bias then
		return home
	end
	local others = {}
	for _, element in ELEMENTS do
		if element ~= home then
			table.insert(others, element)
		end
	end
	return others[rng:NextInteger(1, #others)]
end

-- How rich the ground is (0..1) at an offset from the middle: three soft
-- waves across the quarry, their directions and phases from `rng`.
function Frontier.field(rng): (Vector3) -> number
	local waves = {}
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(waves, {
			Dir = Vector3.new(math.cos(a), 0, math.sin(a)),
			Freq = rng:NextNumber(1 / 150, 1 / 80) * math.pi * 2,
			Phase = rng:NextNumber(0, math.pi * 2),
		})
	end
	return function(offset: Vector3): number
		local sum = 0
		for _, w in waves do
			sum += math.sin(offset:Dot(w.Dir) * w.Freq + w.Phase)
		end
		return (sum / #waves + 1) / 2
	end
end

-- The outcrops past the core: { { Middle, Grain (radians), Length (studs),
-- Rocks = { Vector3 } } }, and the lone rocks between them ({ Vector3 }),
-- all offsets from the middle (Y 0). Thicker on rich ground; an outcrop of
-- two or three near the core, up to five out at the edge.
function Frontier.outcrops(rng): ({ any }, { Vector3 })
	local o = Frontier.Outcrop
	local rich = Frontier.field(rng)
	local crops, rocks = {}, {}
	local tries = 0
	while #crops < o.Count and tries < 8000 do
		tries += 1
		-- (Spread by area, so the wide outer ring isn't sparse.)
		local r = math.sqrt(rng:NextNumber(o.From ^ 2, (o.To - 10) ^ 2))
		local a = rng:NextNumber(0, math.pi * 2)
		local middle = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local roomy = true
		for _, other in crops do
			if (other.Middle - middle).Magnitude < o.Apart then
				roomy = false
				break
			end
		end
		if roomy and rng:NextNumber() < 0.2 + 0.8 * rich(middle) then
			local out = (r - o.From) / (o.To - o.From)
			local count = math.clamp(2 + math.floor(rng:NextNumber() * (0.6 + 3.4 * out) + 0.1), 2, 5)
			local grain = rng:NextNumber(0, math.pi * 2)
			local along = Vector3.new(math.cos(grain), 0, math.sin(grain))
			local across = Vector3.new(-along.Z, 0, along.X)
			-- (Each a step or a little more on from the last, centred on its middle.)
			local steps = { 0 }
			for k = 2, count do
				steps[k] = steps[k - 1] + o.Step * rng:NextNumber(0.95, 1.12)
			end
			local list = {}
			for k = 1, count do
				local t = steps[k] - steps[count] / 2
				local p = middle + along * t + across * rng:NextNumber(-2.5, 2.5)
				-- (None past the frontier's edge: that end is cut short.)
				if p.Magnitude <= o.To then
					table.insert(list, p)
				end
			end
			if #list >= 2 then
				for _, p in list do
					table.insert(rocks, p)
				end
				table.insert(crops, { Middle = middle, Grain = grain, Length = count * o.Step, Rocks = list })
			end
		end
	end
	-- Lone rocks between them, a few leading out of the core first.
	local wanted = math.floor(#rocks * o.Lone / (1 - o.Lone) + 0.5)
	local lone = {}
	local function free(p: Vector3): boolean
		for _, q in rocks do
			if (q - p).Magnitude < 16 then
				return false
			end
		end
		for _, q in lone do
			if (q - p).Magnitude < 16 then
				return false
			end
		end
		return true
	end
	tries = 0
	while #lone < wanted and tries < 4000 do
		tries += 1
		local p
		if #lone < o.Stones then
			-- (At the spokes' mouths, either side of the road, just out of
			-- the core: the first rock of each biome.)
			local spokes = Frontier.Spokes
			local out = Vector3.new(math.cos(spokes[#lone % #spokes + 1]), 0, math.sin(spokes[#lone % #spokes + 1]))
			local side = Vector3.new(-out.Z, 0, out.X) * (if (#lone // #spokes) % 2 == 0 then 1 else -1)
			p = out * rng:NextNumber(Frontier.Core + 5, Frontier.Core + 30) + side * rng:NextNumber(20, 30)
		else
			local r = rng:NextNumber(Frontier.Core, o.To)
			local a = rng:NextNumber(0, math.pi * 2)
			p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		if free(p) then
			table.insert(lone, p)
		end
	end
	return crops, lone
end

-- The angles round the walls a vein may surface at: Veins.Sites of them,
-- evenly round with a little give (the Outpost keeps those with room).
function Frontier.veinSites(rng): { number }
	local sites = {}
	local n = Frontier.Veins.Sites
	for i = 1, n do
		table.insert(sites, (i - 1) / n * math.pi * 2 + rng:NextNumber(-0.12, 0.12))
	end
	return sites
end

-- A vein at `angle` round the middle: its six rocks in two staggered rows
-- fanned in front of its dormant rift by the walls, and the rift's spot
-- (offsets from the middle, Y 0).
function Frontier.veinAt(angle: number, rng): ({ Vector3 }, Vector3)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local side = Vector3.new(-out.Z, 0, out.X)
	local n = Frontier.Veins.Rocks
	local rocks = {}
	for i = 1, n do
		local t = (i - (n + 1) / 2) / n
		local row = if i % 2 == 0 then 9 else 0
		local p = out * (Frontier.Rim - 8 - row - math.abs(t) * 10 + rng:NextNumber(-1, 1)) + side * (t * 66)
		table.insert(rocks, p)
	end
	return rocks, out * (Frontier.Rim + 2)
end

-- Radians between two angles round the middle (0..pi).
function Frontier.apart(a: number, b: number): number
	local d = (a - b) % (math.pi * 2)
	return math.min(d, math.pi * 2 - d)
end

-- Where a vein goes next: a site (by index into `sites`, angles) nobody has
-- (`taken[index]`), at least Veins.Apart from the `others` (angles), at
-- random; nil if there's none.
function Frontier.pickSite(sites: { number }, taken: { [number]: boolean }, others: { number }, rng): number?
	local choices = {}
	for index, angle in sites do
		if not taken[index] then
			local ok = true
			for _, other in others do
				if Frontier.apart(angle, other) < Frontier.Veins.Apart then
					ok = false
					break
				end
			end
			if ok then
				table.insert(choices, index)
			end
		end
	end
	if #choices == 0 then
		return nil
	end
	return choices[rng:NextInteger(1, #choices)]
end

-- Which way an angle round the middle is, as a compass point (north is
-- toward the outpost: Shared.Outpost faces it that way).
local COMPASS = { "east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east" }
function Frontier.compass(angle: number): string
	local i = math.floor(((angle % (math.pi * 2)) / (math.pi * 2)) * 8 + 0.5) % 8
	return COMPASS[i + 1]
end

-- A player's mining noise after `swings` swings and `seconds` seconds out
-- in `band` (the core adds nothing). `roll` (0..1) sets each swing's share
-- within Noise.Spread; `stir` (0..1) makes each swing louder.
function Frontier.noise(
	noise: number,
	band: string,
	swings: number,
	seconds: number,
	roll: number?,
	stir: number?
): number
	local swing, idle = Frontier.Noise.Swing[band], Frontier.Noise.Idle[band]
	if not swing then
		return noise
	end
	local spread = Frontier.Noise.Spread
	local share = spread[1] + (spread[2] - spread[1]) * (roll or 0.5)
	local louder = 1 + Frontier.Disturbance.Noise * math.clamp(stir or 0, 0, 1)
	return noise + swing * swings * share * louder + idle * seconds
end

-- How stirred up the frontier is after `swings` more swings in `band` (the
-- core stirs nothing).
function Frontier.stir(stir: number, band: string, swings: number): number
	local per = Frontier.Disturbance.PerSwing[band]
	if not per then
		return stir
	end
	return math.clamp(stir + per * swings, 0, 1)
end

-- How stirred up it is `seconds` later in `band`, `quiet` seconds since
-- the last swing: it holds while you keep mining, settles after Rest
-- seconds without a swing, and faster in the core.
function Frontier.settle(stir: number, band: string, seconds: number, quiet: number): number
	local d = Frontier.Disturbance
	if band == "Core" then
		return math.max(0, stir - d.CoreFade * seconds)
	end
	-- (Only the part of these seconds past the rest settles it.)
	local resting = math.min(seconds, quiet - d.Rest)
	if resting <= 0 then
		return stir
	end
	return math.max(0, stir - d.Fade * resting)
end

-- Its stage at `stir`: index, { At, Name, Extra, Cap }.
function Frontier.stage(stir: number?)
	local stages = Frontier.Disturbance.Stages
	local at = 1
	for i, stage in stages do
		if (stir or 0) >= stage.At then
			at = i
		end
	end
	return at, stages[at]
end

-- Critters allowed round one player out in `band` (before the fair
-- share): the band's cap and its stage's more.
function Frontier.capFor(band: string, stir: number?): number
	local cap = Frontier.Caps[band] or 0
	if cap <= 0 then
		return 0
	end
	local _, stage = Frontier.stage(stir)
	return cap + stage.Cap
end

-- Critters at once round one player: their band's cap, or a fair share of
-- the Outpost's when many are out there (never less than one).
function Frontier.share(cap: number, playersOut: number): number
	return math.min(cap, math.max(1, math.floor(Frontier.Caps.Server / math.max(1, playersOut))))
end

-- A critter's level, by where it came through, higher the more stirred up
-- (`stir`) it is.
function Frontier.critterLevel(band: string, rng, stir: number?): number
	local range = Frontier.Levels[band] or Frontier.Levels.Fringe
	local level = if rng then rng:NextInteger(range[1], range[2]) else range[1]
	return level + math.floor(Frontier.Disturbance.Levels * math.clamp(stir or 0, 0, 1) + 1e-9)
end

-- EXP for a kaiju that fought a critter of `level` from `band`, its owner
-- having had `today` critters' EXP already today.
function Frontier.critterExp(level: number, band: string?, today: number?): number
	local e = Frontier.Exp
	local boost = Frontier.Boost[band or ""] or Frontier.Boost.Fringe
	local exp = (e.Base + e.PerLevel * math.max(1, level)) * boost.Exp
	if (today or 0) >= e.Daily then
		exp *= e.After
	end
	return math.max(1, math.floor(exp + 0.5))
end

-- How many critters come through at once (`roll` in [0, 1)), more the
-- more stirred up (`stir`) it is.
function Frontier.incursion(band: string, roll: number, stir: number?): number
	local _, stage = Frontier.stage(stir)
	if band == "Edge" then
		return (if roll < 0.6 then 5 else 6) + stage.Extra
	elseif band == "Fringe" then
		return (if roll < 0.6 then 3 else 4) + stage.Extra
	end
	return 0
end

local function gapTo(spot: Vector3, points: { Vector3 }?): number
	local gap = math.huge
	for _, point in points or {} do
		gap = math.min(gap, Vector3.new(spot.X - point.X, 0, spot.Z - point.Z).Magnitude)
	end
	return gap
end

-- Where a rift opens round a player at `position` facing `facing` (a flat
-- direction, or zero: then outward): near where they look, inside the walls
-- and outside the core, at least Rift.Apart studs from the tears still open
-- (`others`, points) and, where it can, from its swarm's tears already
-- sealed (`past`), so a swarm's tears spread out and don't open where one
-- just shut. Only spots `usable` takes (the server's: open ground, level
-- with the player), if given. Of Rift.Tries spots, the first clear of both;
-- else the one furthest from the open tears, then from the sealed ones.
-- Returns a point at their height (nil if `usable` took none).
function Frontier.riftSpot(
	position: Vector3,
	facing: Vector3,
	center: Vector3,
	rng,
	others: { Vector3 }?,
	past: { Vector3 }?,
	usable: ((Vector3) -> boolean)?
): Vector3?
	local rift = Frontier.Rift
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	end
	local ahead = if flat.Magnitude > 0.01 then math.atan2(flat.Z, flat.X) else rng:NextNumber(0, math.pi * 2)
	local choosy = usable ~= nil or (others ~= nil and #others > 0) or (past ~= nil and #past > 0)
	local best, bestScore = nil, -1
	for _ = 1, if choosy then rift.Tries else 1 do
		local angle = ahead + rng:NextNumber(-rift.Spread, rift.Spread)
		local reach = rng:NextNumber(rift.Near, rift.Far)
		local spot =
			Frontier.inFrontier(position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach, center, position.Y)
		if usable and not usable(spot) then
			continue
		end
		local open, sealed = gapTo(spot, others), gapTo(spot, past)
		if open >= rift.Apart and sealed >= rift.Apart then
			return spot
		end
		-- (clear of the open ones first; of the sealed ones only after that)
		local score = 100 * math.min(open, rift.Apart) + math.min(sealed, rift.Apart)
		if score > bestScore then
			best, bestScore = spot, score
		end
	end
	return best
end

-- Seconds after an encounter starts that each of its `count` tears opens
-- (`rng` spaces them Swarm.Every apart): one after another, never at once.
function Frontier.trickle(count: number, rng): { number }
	local every, at, times = Frontier.Swarm.Every, 0, {}
	for i = 1, count do
		times[i] = at
		at += if rng then rng:NextNumber(every[1], every[2]) else every[1]
	end
	return times
end

-- A point brought inside the frontier (out of the core, inside the walls), at height `y`.
function Frontier.inFrontier(spot: Vector3, center: Vector3, y: number): Vector3
	local offset = Vector3.new(spot.X - center.X, 0, spot.Z - center.Z)
	local r = math.clamp(offset.Magnitude, Frontier.Core, Frontier.Rim)
	offset = if offset.Magnitude > 0.01 then offset.Unit * r else Vector3.new(r, 0, 0)
	return Vector3.new(center.X + offset.X, y, center.Z + offset.Z)
end

-- Where a wandering rift opens: Wander.Near to Far studs from someone out
-- there at `position`, any way round, inside the frontier.
function Frontier.wanderSpot(position: Vector3, center: Vector3, rng): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local reach = rng:NextNumber(Frontier.Wander.Near, Frontier.Wander.Far)
	return Frontier.inFrontier(position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach, center, position.Y)
end

-- A rift opening at `at` (server time): when it's open, the critter hops,
-- it starts to seal, and it's gone. `linger`: seconds it stays open after
-- the hop (Rift.Linger unless given); `hop`: seconds from opening to the
-- hop (Rift.Hop unless given: a snatcher's waits longer for it).
function Frontier.timeline(at: number, linger: number?, hop: number?)
	local rift = Frontier.Rift
	local stay = linger or rift.Linger
	local wait = hop or rift.Hop
	return {
		OpenAt = at,
		HopAt = at + wait,
		CloseAt = at + wait + stay,
		EndAt = at + wait + stay + rift.Close,
	}
end

-- Gem raids --------------------------------------------------------------------------------------------

-- Critters through for a gem raid (more, stirred up).
function Frontier.raidSize(stir: number?): number
	return Frontier.Raid.Size + math.floor(math.clamp(stir or 0, 0, 1) * Frontier.Raid.StirBonus + 0.5)
end

-- What snatchers can take from `haul` (the gems mined this trip out:
-- { { Id } }, oldest first): those still loose in the pouch (`loose`: a
-- set of ids), newest first, `max` at most.
function Frontier.haulPick(haul: { any }, loose: { [string]: boolean }, max: number): { string }
	local picked = {}
	for i = #haul, 1, -1 do
		if #picked >= max then
			break
		end
		local id = haul[i].Id
		if loose[id] and not table.find(picked, id) then
			table.insert(picked, id)
		end
	end
	return picked
end

-- Where a snatcher's rift tears open: Carry.Away studs on from `from`,
-- away from the player it robbed (at `player`) and a little outward,
-- inside the frontier.
function Frontier.escapeSpot(from: Vector3, player: Vector3, center: Vector3, rng): Vector3
	local away = Vector3.new(from.X - player.X, 0, from.Z - player.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
	local out = Vector3.new(from.X - center.X, 0, from.Z - center.Z)
	out = if out.Magnitude > 0.1 then out.Unit else away
	local turn = rng:NextNumber(-0.5, 0.5)
	local dir = (away * 0.7 + out * 0.3)
	dir =
		Vector3.new(dir.X * math.cos(turn) - dir.Z * math.sin(turn), 0, dir.X * math.sin(turn) + dir.Z * math.cos(turn))
	dir = if dir.Magnitude > 0.01 then dir.Unit else away
	local reach = rng:NextNumber(Frontier.Raid.Carry.Away[1], Frontier.Raid.Carry.Away[2])
	return Frontier.inFrontier(from + dir * reach, center, from.Y)
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end

-- How wide the tear is at `now`: 0 shut, 1 wide open.
function Frontier.openness(timeline, now: number): number
	if now < timeline.OpenAt or now >= timeline.EndAt then
		return 0
	elseif now < timeline.OpenAt + Frontier.Rift.Open then
		return ease((now - timeline.OpenAt) / Frontier.Rift.Open)
	elseif now < timeline.CloseAt then
		return 1
	end
	return 1 - ease((now - timeline.CloseAt) / math.max(timeline.EndAt - timeline.CloseAt, 0.01))
end

-- A tear's ragged outline, from its seed: in its own plane (X across, Y up,
-- studs, centred on 0), never symmetrical. Returns {
--   Spine = { Vector2 }   the crack it opens along, top to bottom
--   Left, Right = { Vector2 }   its two lips, wide open (pointed at both ends)
--   Branches = { { Vector2, Vector2, Row, Left } }   hairline cracks running
--              off its lips (from a lip's point in that row, on that side)
--   Tilt   radians it leans, Height }
function Frontier.tear(seed: number, height: number)
	local rng = Random.new(seed)
	local rows = 8
	local spine, left, right = {}, {}, {}
	local x = 0
	local widest = height * rng:NextNumber(0.45, 0.62)
	for i = 0, rows - 1 do
		local t = i / (rows - 1)
		local y = height / 2 - t * height + (if i > 0 and i < rows - 1 then rng:NextNumber(-0.06, 0.06) * height else 0)
		if i > 0 then
			x += rng:NextNumber(-0.42, 0.42) * height / rows
		end
		table.insert(spine, Vector2.new(x, y))
		-- Wide in the middle, pointed at the ends, and lopsided: each lip
		-- takes its own share of the width, row by row.
		local width = if i == 0 or i == rows - 1
			then 0
			else widest * math.sin(t * math.pi) ^ 0.8 * rng:NextNumber(0.55, 1.25)
		local share = rng:NextNumber(0.25, 0.75)
		table.insert(left, Vector2.new(x - width * share, y + rng:NextNumber(-0.04, 0.04) * height))
		table.insert(right, Vector2.new(x + width * (1 - share), y + rng:NextNumber(-0.04, 0.04) * height))
	end
	local branches = {}
	for _ = 1, rng:NextInteger(2, 4) do
		local row = rng:NextInteger(2, rows - 1)
		local onLeft = rng:NextNumber() < 0.5
		local from = if onLeft then left[row] else right[row]
		local angle = (if onLeft then math.pi else 0) + rng:NextNumber(-0.9, 0.9)
		local length = height * rng:NextNumber(0.12, 0.3)
		table.insert(
			branches,
			{ from, from + Vector2.new(math.cos(angle), math.sin(angle)) * length, Row = row, Left = onLeft }
		)
	end
	return {
		Spine = spine,
		Left = left,
		Right = right,
		Branches = branches,
		Tilt = rng:NextNumber(-0.35, 0.35),
		Height = height,
	}
end

return Frontier
