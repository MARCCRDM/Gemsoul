--[[
	The brainrot creatures' own moves, as dungeon and Rift fighters
	(Server.Duelist) use them: each room fighter has its signature move
	beside two rig maneuvers, and each boss three of its own, one of them a
	big telegraphed attack. DungeonRules lists them by id, as it lists rig
	maneuvers (CombatTechnology.Catalog), and a fighter uses them the same
	way, on its 1, 2 and 3.

	Each is a Shape:
	  Strike  a blow in reach; Hits blows Gap apart, the last one Heavy if
	          HeavyLast (it breaks a raised guard). Reach: a longer reach
	          (a tongue, a lash) in studs
	  Slam    brought down round its own feet (Radius); the closer to it,
	          the harder, with a stun at the core and a stagger in the
	          middle (CombatActions.blastFalloff)
	  Roar    round its own feet (Radius): a little damage, and its Riders
	          land through a raised guard
	  Blast   under its foe: a ring where they stood as it starts (Radius)
	  Bombs   Count rings round its foe, the first where they stood and the
	          rest within Spread, each Radius wide and hitting once
	  Leap    a jump onto where its foe stood as it starts (up to Leap
	          studs off), landing as a Slam (Radius)
	  Dash    a charge straight through its foe, up to Length studs,
	          hitting within Width of its path
	A ring shows where every Slam, Roar, Blast, Bombs and Leap lands for its
	whole Windup: step out of it.

	Damage is a share of its hit (as a maneuver's is). Riders: what a blow
	that lands leaves on you (and a guarded one doesn't, but a Roar's does):
	  Burn, Poison    a share of its hit every second, for BurnTime /
	                  PoisonTime seconds (Poison also cuts your healing)
	  Slow            moves you Slow slower, for SlowTime seconds
	  Stun            stunned that many seconds (StunKind: how it shows,
	                  "Frozen" for frost)
	  Blind           a Blind share of your blows miss, for BlindTime
	  Sunder          your armor shredded by Sunder, for SunderTime
	CC: a Slam's core stun shows as this ("Frozen", "Shocked"). Cloud: the
	ground it leaves stays harmful (CombatTechnology's Cloud: every Every
	seconds for Duration, Damage a share of its hit).

	Big: its one big attack, announced and with a long wind-up. Range and
	Min: from how far (studs) it reaches for it. Pose: its body's action
	(RivalPose).

	CreatureMoves.get(id) -> the move, or nil (a rig maneuver)
]]
local Moves = {}

Moves.Catalog = {
	-- The room fighters' signature moves (as Shared.Kaiju.BugMoves has them
	-- for the Outpost's critters).
	BatSlam = {
		Name = "Bat Slam",
		Shape = "Slam",
		Pose = "Heavy",
		Windup = 0.9,
		Radius = 7,
		Damage = 2.2,
		Heavy = true,
		Riders = { Burn = 0.15, BurnTime = 3 },
		Range = 6,
		Cooldown = 7,
	},
	SharkDash = {
		Name = "Shark Dash",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.5,
		Length = 18,
		Width = 3.5,
		Damage = 1.8,
		Riders = { Slow = 0.35, SlowTime = 2 },
		Min = 5,
		Range = 18,
		Cooldown = 6,
	},
	SporeBurst = {
		Name = "Spore Burst",
		Shape = "Roar",
		Pose = "Nova",
		Windup = 0.8,
		Radius = 8,
		Damage = 1.3,
		Riders = { Poison = 0.12, PoisonTime = 4 },
		Cloud = { Every = 1, Duration = 3, Damage = 0.25 },
		Range = 7,
		Cooldown = 8,
	},
	CarpetBomb = {
		Name = "Carpet Bomb",
		Shape = "Bombs",
		Pose = "Bolt",
		Windup = 1,
		Count = 3,
		Spread = 6,
		Radius = 4,
		Damage = 1.2,
		Riders = { Stun = 0.6 },
		Min = 6,
		Range = 26,
		Cooldown = 9,
	},

	-- Tung Tung Tung Sahur: three log heads and a nail-studded bat.
	TungTungTung = {
		Name = "Tung Tung Tung",
		Shape = "Strike",
		Pose = "Heavy",
		Windup = 0.35,
		Hits = 3,
		Gap = 0.35,
		HeavyLast = true,
		Damage = 1.1,
		Riders = { Burn = 0.12, BurnTime = 3 },
		Range = 7,
		Cooldown = 7,
	},
	ThreeHeadRoar = {
		Name = "Three-Head Roar",
		Shape = "Roar",
		Pose = "Nova",
		Windup = 0.6,
		Radius = 13,
		Damage = 0.4,
		Riders = { Blind = 0.35, BlindTime = 3, Slow = 0.3, SlowTime = 2.5 },
		Range = 11,
		Cooldown = 13,
	},
	EmberQuake = {
		Name = "Ember Quake",
		Shape = "Slam",
		Pose = "Heavy",
		Big = true,
		Windup = 1.6,
		Radius = 14,
		Damage = 4,
		Heavy = true,
		Riders = { Burn = 0.2, BurnTime = 4 },
		Range = 10,
		Cooldown = 15,
	},

	-- Gattini Gemellini: twin cats, quick and crackling.
	TwinPounce = {
		Name = "Twin Pounce",
		Shape = "Leap",
		Pose = "Leap",
		Windup = 0.8,
		Leap = 26,
		Radius = 7,
		Damage = 2,
		Riders = { Stun = 0.6, StunKind = "Shocked" },
		Min = 7,
		Range = 26,
		Cooldown = 7,
	},
	ClawFrenzy = {
		Name = "Claw Frenzy",
		Shape = "Strike",
		Pose = "Slash",
		Windup = 0.25,
		Hits = 4,
		Gap = 0.18,
		Damage = 0.6,
		Riders = { Sunder = 0.15, SunderTime = 4 },
		Range = 7,
		Cooldown = 6,
	},
	StaticStorm = {
		Name = "Static Storm",
		Shape = "Bombs",
		Pose = "Nova",
		Big = true,
		Windup = 1.5,
		Count = 5,
		Spread = 9,
		Radius = 5,
		Damage = 2.2,
		Riders = { Stun = 0.8, StunKind = "Shocked" },
		Range = 30,
		Cooldown = 15,
	},

	-- Bombardiro Drago: a dragon croc with bombs under its wings.
	FlameBreath = {
		Name = "Flame Breath",
		Shape = "Blast",
		Pose = "Bolt",
		Windup = 0.8,
		Radius = 6,
		Damage = 1.6,
		Riders = { Burn = 0.18, BurnTime = 3 },
		Min = 4,
		Range = 20,
		Cooldown = 7,
	},
	TailSweep = {
		Name = "Tail Sweep",
		Shape = "Slam",
		Pose = "Spin",
		Windup = 0.5,
		Radius = 9,
		Damage = 1.6,
		Riders = { Slow = 0.3, SlowTime = 2 },
		Range = 8,
		Cooldown = 8,
	},
	FirebombDive = {
		Name = "Firebomb Dive",
		Shape = "Leap",
		Pose = "Leap",
		Big = true,
		Windup = 1.5,
		Leap = 32,
		Radius = 13,
		Damage = 3.6,
		Heavy = true,
		Riders = { Burn = 0.22, BurnTime = 4 },
		Range = 32,
		Cooldown = 15,
	},

	-- Paperotti Gemelli: twin ducks with a beak of ice.
	IcePeck = {
		Name = "Ice Peck",
		Shape = "Strike",
		Pose = "Slash",
		Windup = 0.3,
		Hits = 2,
		Gap = 0.25,
		Damage = 1.2,
		Riders = { Slow = 0.3, SlowTime = 2 },
		Range = 7,
		Cooldown = 5,
	},
	HailVolley = {
		Name = "Hail Volley",
		Shape = "Bombs",
		Pose = "Bolt",
		Windup = 1,
		Count = 4,
		Spread = 7,
		Radius = 4,
		Damage = 1.4,
		Riders = { Slow = 0.35, SlowTime = 2 },
		Min = 6,
		Range = 26,
		Cooldown = 9,
	},
	QuackSquall = {
		Name = "Quack Squall",
		Shape = "Slam",
		Pose = "Nova",
		Big = true,
		Windup = 1.5,
		Radius = 14,
		Damage = 3.2,
		CC = "Frozen",
		Riders = { Slow = 0.5, SlowTime = 3 },
		Range = 10,
		Cooldown = 15,
	},

	-- Ranocchio Avocadino: a frog in an avocado, its pit a bomb.
	TongueLash = {
		Name = "Tongue Lash",
		Shape = "Strike",
		Pose = "Lunge",
		Windup = 0.45,
		Reach = 15,
		Damage = 1.5,
		Riders = { Slow = 0.4, SlowTime = 1.5 },
		Range = 14,
		Cooldown = 6,
	},
	ToxicPits = {
		Name = "Toxic Pits",
		Shape = "Bombs",
		Pose = "Bolt",
		Windup = 1.1,
		Count = 3,
		Spread = 6,
		Radius = 4.5,
		Damage = 1.2,
		Riders = { Poison = 0.12, PoisonTime = 4 },
		Cloud = { Every = 1, Duration = 3, Damage = 0.2 },
		Min = 5,
		Range = 24,
		Cooldown = 10,
	},
	BogLeap = {
		Name = "Bog Leap",
		Shape = "Leap",
		Pose = "Leap",
		Big = true,
		Windup = 1.4,
		Leap = 30,
		Radius = 13,
		Damage = 3.4,
		Heavy = true,
		Riders = { Poison = 0.18, PoisonTime = 5 },
		Range = 30,
		Cooldown = 15,
	},

	-- Chimpanzini Bananini: a chimp in a banana.
	PeelToss = {
		Name = "Peel Toss",
		Shape = "Bombs",
		Pose = "Bolt",
		Windup = 0.9,
		Count = 2,
		Spread = 5,
		Radius = 4,
		Damage = 1.3,
		Riders = { Slow = 0.5, SlowTime = 1.5 },
		Min = 6,
		Range = 26,
		Cooldown = 8,
	},
	JungleRush = {
		Name = "Jungle Rush",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.5,
		Length = 24,
		Width = 6,
		Damage = 2,
		Riders = { Stun = 0.5, StunKind = "Shocked" },
		Min = 6,
		Range = 24,
		Cooldown = 8,
	},
	BananaSmash = {
		Name = "Banana Smash",
		Shape = "Slam",
		Pose = "Heavy",
		Big = true,
		Windup = 1.5,
		Radius = 14,
		Damage = 3.8,
		Heavy = true,
		CC = "Shocked",
		Range = 10,
		Cooldown = 15,
	},

	-- Tralalero Tralala: a two-headed shark in sneakers.
	TwinSharkDash = {
		Name = "Twin Shark Dash",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.6,
		Length = 28,
		Width = 7,
		Damage = 2,
		Riders = { Slow = 0.35, SlowTime = 2 },
		Min = 6,
		Range = 28,
		Cooldown = 7,
	},
	JawSnap = {
		Name = "Jaw Snap",
		Shape = "Strike",
		Pose = "Slash",
		Windup = 0.35,
		Hits = 2,
		Gap = 0.3,
		HeavyLast = true,
		Damage = 1.3,
		Riders = { Sunder = 0.2, SunderTime = 4 },
		Range = 7,
		Cooldown = 6,
	},
	TidalCrash = {
		Name = "Tidal Crash",
		Shape = "Slam",
		Pose = "Heavy",
		Big = true,
		Windup = 1.6,
		Radius = 14,
		Damage = 3.6,
		Heavy = true,
		CC = "Frozen",
		Riders = { Slow = 0.45, SlowTime = 3 },
		Range = 10,
		Cooldown = 15,
	},

	-- Brr Brr Patapim: an old treant, mossy and rotting.
	BranchSweep = {
		Name = "Branch Sweep",
		Shape = "Slam",
		Pose = "Spin",
		Windup = 0.6,
		Radius = 9,
		Damage = 1.8,
		Heavy = true,
		Range = 8,
		Cooldown = 7,
	},
	RootSnare = {
		Name = "Root Snare",
		Shape = "Blast",
		Pose = "Nova",
		Windup = 0.9,
		Radius = 5,
		Damage = 1.2,
		Riders = { Slow = 0.7, SlowTime = 2, Poison = 0.1, PoisonTime = 3 },
		Min = 4,
		Range = 24,
		Cooldown = 9,
	},
	SporeStorm = {
		Name = "Spore Storm",
		Shape = "Slam",
		Pose = "Nova",
		Big = true,
		Windup = 1.6,
		Radius = 15,
		Damage = 3,
		Riders = { Poison = 0.18, PoisonTime = 5 },
		Cloud = { Every = 1, Duration = 4, Damage = 0.3 },
		Range = 11,
		Cooldown = 15,
	},

	-- Frigo Camelo: a fridge on camel legs.
	IceSpit = {
		Name = "Ice Spit",
		Shape = "Blast",
		Pose = "Bolt",
		Windup = 0.7,
		Radius = 4.5,
		Damage = 1.6,
		Riders = { Slow = 0.4, SlowTime = 2 },
		Min = 5,
		Range = 28,
		Cooldown = 6,
	},
	DoorSlam = {
		Name = "Door Slam",
		Shape = "Strike",
		Pose = "Heavy",
		Windup = 0.6,
		Damage = 2.4,
		Heavy = true,
		Riders = { Stun = 0.6, StunKind = "Frozen" },
		Range = 7,
		Cooldown = 8,
	},
	FreezerBlast = {
		Name = "Freezer Blast",
		Shape = "Slam",
		Pose = "Nova",
		Big = true,
		Windup = 1.5,
		Radius = 14,
		Damage = 3.4,
		CC = "Frozen",
		Riders = { Slow = 0.5, SlowTime = 3 },
		Range = 10,
		Cooldown = 15,
	},

	-- Cappuccino Assassino: a cracked cup with two katanas and kunai.
	KnifeFlurry = {
		Name = "Knife Flurry",
		Shape = "Strike",
		Pose = "Slash",
		Windup = 0.25,
		Hits = 5,
		Gap = 0.15,
		Damage = 0.5,
		Riders = { Sunder = 0.15, SunderTime = 4 },
		Range = 7,
		Cooldown = 6,
	},
	ShadowStep = {
		Name = "Shadow Step",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.35,
		Length = 24,
		Width = 6,
		Damage = 1.8,
		Riders = { Blind = 0.3, BlindTime = 2 },
		Min = 5,
		Range = 24,
		Cooldown = 7,
	},
	KunaiStorm = {
		Name = "Kunai Storm",
		Shape = "Bombs",
		Pose = "Spin",
		Big = true,
		Windup = 1.4,
		Count = 6,
		Spread = 10,
		Radius = 4,
		Damage = 2,
		Riders = { Stun = 0.5, StunKind = "Shocked" },
		Range = 30,
		Cooldown = 15,
	},
}

Moves.Shapes = { Strike = true, Slam = true, Roar = true, Blast = true, Bombs = true, Leap = true, Dash = true }

function Moves.get(id: string?)
	return Moves.Catalog[id or ""]
end

return Moves
