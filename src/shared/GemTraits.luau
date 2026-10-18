--[[
	The Q / E / R triad. Every gem carries three traits, one per key, and the
	socket a gem sits in decides which of them you use:

	  key  lane     socket          pays with   job
	  Q    Offense  the sword       Charge      the sword's special move
	  E    Ability  the chest       Charge      your elemental surge (Strike,
	                                            Shift or Aura)
	  R    Defense  the shield      Stamina     survive pressure

	The gear's own gem sockets are the surge sockets: enchant the sword, the
	chest and the shield and you have Q, E and R. (With a two-handed weapon,
	no shield: the weapon's gem gives R too.)

	Each element has five moves per lane (60 in all). A gem rolls one of each
	from its element; signature moves roll at half the odds. Rarity sets how
	strong all three are (Common 60% ... Legendary 100%, plus a Flourish);
	Size adds potency, Clarity duration and Cut shortens the cooldown.

	A kaiju's Gemsoul is one stone for all three of its moves: E from the
	start, Q and R as it levels (Shared.Kaiju). In your gear it's a gem like
	any other.

	Nothing is deleted: the three old surge sockets are kept in the save (a
	gem left on the old core socket, Surge2, moves onto the chest), every
	retired surge id still resolves, and the Arena rival keeps its own surge
	list (it reads its Surge1-3 gems directly). Set Enabled = false to go
	back to the classic surge array.

	Pure data and logic, shared by the server and every client.
]]
local GemTraits = {}

GemTraits.Enabled = true
GemTraits.Keys = { "Q", "E", "R" }
GemTraits.Lanes = { Q = "Offense", E = "Ability", R = "Defense" }
GemTraits.KeyOfLane = { Offense = "Q", Ability = "E", Defense = "R" }
-- The saved socket each key reads its gem from: the sword's, the chest's
-- (the Armor slot) and the shield's.
GemTraits.Sockets = { Q = "Weapon", E = "Armor", R = "Shield" }
-- The key a piece of gear's gem gives.
GemTraits.KeyOfSocket = { Weapon = "Q", Armor = "E", Shield = "R" }
-- The surge sockets the triad retires (kept in the save).
GemTraits.ArchivedSockets = { "Surge1", "Surge2", "Surge3" }
-- Where a retired socket's gem goes now: the old core socket's onto the
-- chest (the old Q and R sockets' to the pouch).
GemTraits.Moved = { Surge2 = "Armor" }
GemTraits.LaneNames = { Offense = "Offense", Ability = "Ability", Defense = "Defense" }
GemTraits.SocketNames = { Q = "Sword", E = "Chest", R = "Shield" }

-- Rarity sets output: damage, absorb, healing, burns, steals and drains.
-- Cost, cooldown, reach and control timing are the same at every rarity.
GemTraits.Output = { Common = 0.6, Uncommon = 0.7, Rare = 0.8, UltraRare = 0.9, Legendary = 1 }
-- Ranked fights level everyone's traits to this.
GemTraits.NormalizedOutput = 0.8
GemTraits.SizePotency = 0.10 -- Size 10: +10% potency
GemTraits.ClarityDuration = 0.15 -- Clarity 10: +15% duration
GemTraits.CutCooldown = 0.15 -- Cut 10: -15% cooldown

-- Signature moves roll at this share of the others' odds.
GemTraits.SignatureWeight = 0.5

-- Steals and drains (Ion steals Charge, Corrosive drains Stamina): caps per
-- victim over a rolling 10 seconds, the Stamina floor, and the PvP share.
GemTraits.Caps = { Charge = 20, Stamina = 30, StaminaFloor = 15, PvP = 0.6, Window = 10 }

--[[ Each element's five moves per lane, in matrix order. ]]
GemTraits.Matrix = {
	Fire = {
		Offense = { "Q_CinderCleave", "Q_FurnaceCrescent", "Q_SolarExecution", "Q_CinderDrill", "Q_MagmaFault", "Q_MeteorLeap" },
		Ability = { "E_EmberLance", "E_Supernova", "E_SolarFlare", "E_HeatHaze", "E_ThermalBurst", "E_FlameTornado" },
		Defense = { "R_HeatShield", "R_EmberGuard", "R_FireWall", "R_Cauterize", "R_PhoenixMantle", "R_RingOfFire" },
	},
	Frost = {
		Offense = { "Q_FrostNeedle", "Q_GlacierFan", "Q_ShatterCrown", "Q_PermafrostSpire", "Q_CryoEdge", "Q_FrostChakram" },
		Ability = { "E_CryoLance", "E_CryoStream", "E_AbsoluteZero", "E_GlacierRetreat", "E_WintersHold", "E_Hailstorm" },
		Defense = { "R_FrozenWall", "R_IceArmor", "R_ColdResolve", "R_GlacialBulwark", "R_FrostRiposte", "R_IcePillar" },
	},
	Shock = {
		Offense = { "Q_ArcNeedle", "Q_CircuitCleave", "Q_Railstorm", "Q_StaticBrand", "Q_OverchargeStrike", "Q_ThunderDash", "Q_Skybreaker" },
		Ability = { "E_IonSpark", "E_ChainLightning", "E_ThunderPylon", "E_VectorDash", "E_Overload", "E_StormCall", "E_IonCannon" },
		Defense = { "R_IonShield", "R_StaticCatch", "R_Capacitor", "R_DeflectorField", "R_Grounding", "R_TeslaFence", "R_HoloDecoy" },
	},
	Poison = {
		Offense = { "Q_BreachCut", "Q_CausticDart", "Q_VitriolSweep", "Q_Dissolution", "Q_SappingEdge", "Q_ViperLash", "Q_ToxicFlask" },
		Ability = { "E_AcidSpray", "E_ToxicCloud", "E_ArmorMelt", "E_LeechBloom", "E_SeepStep", "E_ToxicTide", "E_Maneater" },
		Defense = { "R_RadShield", "R_PurgeShell", "R_CorrosionAura", "R_BioRegrowth", "R_ToxicMantle", "R_SporeWall", "R_AcidSlick" },
	},
}

-- A kaiju's Gemsoul rolls its three moves from these: the ones a kaiju can
-- cast (Shared.Kaiju.AbilityPlans plans how each lands), a strike for Q,
-- a surge you can see land for E and a shell, a mend or a ring for R. In
-- your gear a Gemsoul works like any gem, these moves on its keys.
GemTraits.SoulMoves = {
	Fire = {
		Offense = { "Q_FurnaceCrescent", "Q_MagmaFault", "Q_MeteorLeap" },
		Ability = { "E_EmberLance", "E_Supernova", "E_SolarFlare", "E_FlameTornado" },
		Defense = { "R_HeatShield", "R_Cauterize", "R_RingOfFire" },
	},
	Frost = {
		Offense = { "Q_GlacierFan", "Q_PermafrostSpire", "Q_FrostChakram" },
		Ability = { "E_CryoLance", "E_AbsoluteZero", "E_Hailstorm" },
		Defense = { "R_IceArmor", "R_GlacialBulwark", "R_IcePillar" },
	},
	Shock = {
		Offense = { "Q_CircuitCleave", "Q_ThunderDash", "Q_Skybreaker" },
		Ability = { "E_IonSpark", "E_ChainLightning", "E_ThunderPylon", "E_StormCall", "E_IonCannon" },
		Defense = { "R_IonShield", "R_Capacitor", "R_TeslaFence" },
	},
	Poison = {
		Offense = { "Q_CausticDart", "Q_VitriolSweep", "Q_ToxicFlask" },
		Ability = { "E_AcidSpray", "E_ToxicCloud", "E_ArmorMelt", "E_ToxicTide", "E_Maneater" },
		Defense = { "R_RadShield", "R_BioRegrowth", "R_ToxicMantle" },
	},
}

-- An old surge that is now a trait keeps its place on migrated gems.
GemTraits.FromSurge = {
	FurnaceCrescent = "Q_FurnaceCrescent", SolarExecution = "Q_SolarExecution", CinderDrill = "Q_CinderDrill",
	MagmaFault = "Q_MagmaFault", FrostNeedle = "Q_FrostNeedle", GlacierFan = "Q_GlacierFan",
	ShatterCrown = "Q_ShatterCrown", PermafrostSpire = "Q_PermafrostSpire", ArcNeedle = "Q_ArcNeedle",
	CircuitCleave = "Q_CircuitCleave", Railstorm = "Q_Railstorm", CausticDart = "Q_CausticDart",
	VitriolSweep = "Q_VitriolSweep", Dissolution = "Q_Dissolution",
	EmberLance = "E_EmberLance", Supernova = "E_Supernova", SolarFlare = "E_SolarFlare", ThermalBurst = "E_ThermalBurst",
	CryoLance = "E_CryoLance", CryoStream = "E_CryoStream", AbsoluteZero = "E_AbsoluteZero",
	IonSpark = "E_IonSpark", ChainLightning = "E_ChainLightning", ThunderPylon = "E_ThunderPylon", Overload = "E_Overload",
	AcidSpray = "E_AcidSpray", ToxicCloud = "E_ToxicCloud", ArmorMelt = "E_ArmorMelt", LeechBloom = "E_LeechBloom",
	EnergySiphon = "R_Capacitor", CryoShield = "R_GlacialBulwark", StaticField = "R_StaticCatch",
	BioCorrosion = "R_PurgeShell",
	-- The archived prototype's moves.
	CinderCleave = "Q_CinderCleave", HeatReversal = "R_EmberGuard", FurnaceRush = "E_HeatHaze",
	CryoAegis = "R_GlacialBulwark", GlacierRetreat = "E_GlacierRetreat", ArcThrust = "Q_ArcNeedle",
	StaticCatch = "R_StaticCatch", VectorDash = "E_VectorDash", BreachCut = "Q_BreachCut",
	PurgeShell = "R_PurgeShell", SeepStep = "E_SeepStep",
}

--[[
	The moves. Numbers are at Legendary (100%); a gem scales them by its
	rarity's Output. Damage is a share of your weapon's damage, as every
	surge's is. Fields beyond the surge catalog's own (see CombatTechnology):

	  Lane / Type     Offense, Ability (Strike, Shift or Aura) or Defense
	  Rare            a signature move: rolls at half the odds
	  Hits/Interval   that many blows, this far apart
	  Burn/Poison     { Power (x weapon damage a second), Time }
	  Chill           slow stacks on each target; three freeze it for 1s
	  Root            seconds held in place (a full slow)
	  StunChance      the chance its Stun lands
	  Vulnerable      { Amount, Time }: takes more damage from everything
	  LowHealth       { Below, Bonus }: more damage to a wounded target
	  VsChilled       more damage to a slowed or frozen target
	  BurstPoison     bursts every poison on the target at once (x its rest)
	  ConsumeCharge   spends all your Charge: +this damage per point
	  StealCharge / StealStamina / DrainCharge   per target hit
	  Mark            { Time, Arc, Steal }: your hits on it arc and steal
	  ArcExtra        { Count, Share, Range }: jumps on from the first hit
	  Dash            { Dir = Forward | Back | Side | Aim, Distance, MoveTime }
	  Trail           a burning or icy strip left along the path
	  Untargetable    seconds nothing can touch you
	  Empower         { Kind = Burn | Chill | Sap, Swings, Time, ... }
	  Absorb/Duration a shield; Ward = burn attackers
	  Guard           { Kind = Reflect, Share, Time }: a held guard
	  Wall            { Kind, Time, Width, Distance } (Fire, Ice, Tesla, Spore)
	  Pillar          { Height, Time, Radius, Slow, SlowTime }: lifted out of reach
	  Ring            { Radius, Time, Burn, Push }: a ring of fire around you
	  Decoy           { Time, Trigger, Radius, Stun, Damage }: a hologram that bursts
	  Slick           { Radius, Time, Slow, Shred }: an acid puddle around you
	  Showcase        a move made to be seen: walls, rings, pillars, decoys
	  Show            the move's own look (TriadVfx.show) instead of the
	                  generic bolt, blast and slash
	  Pounce          { Distance, Time, Lift }: leap at the aim; the payload
	                  lands with you
	  Push / Pull     throw hit targets away from the blow / yank them to
	                  this many studs in front of you
	  Width           a line's width (bolts and beams; 2 by default)
	  Lob             seconds a thrown payload flies before it lands
	  Crater/Puddle   { Radius, Time, Burn | Poison, Slow }: left where it lands
	  Vortex          { Distance, Time, Radius, Every, Pull, End }: a moving
	                  storm that drags foes along, then bursts (End x Damage)
	  Disc            { Distance, Time, Radius }: thrown out and back, hits
	                  each foe once each way
	  Hail            { Time, Every, Chill }: Damage to all inside, each tick
	  Storm           { Strikes, Every, Delay, Radius, Stun }: bolts that
	                  each seek the nearest foe in the area, warned first
	  Wave            { Distance, Time, Width, Push }: a wall of acid rolling
	                  out, hitting each foe once and carrying it along
	  Cleanse         All | Dots | One
	  Heal            { Share (of max health), Time, BreakOnHeavy }
	  Phoenix         { Below, Heal, Time }: cheat death once a round
	  DamageCut / ResistAll / DamageBoost   { Amount, Time }
	  Aura            what it gives while E is ready (AttackSpeed, Damage,
	                  SlowLonger, ChargeGain, PoisonLonger)
	  Flourish        what a Legendary gem adds (fields merged in) + Text
]]
local M = {}
local Q, E, R = "Offense", "Ability", "Defense"

-- THERMAL · burn and burst ---------------------------------------------------
M.Q_CinderCleave = {
	Name = "Cinder Cleave", Element = "Fire", Lane = Q, Cost = 20, Cooldown = 8,
	Empower = { Kind = "Burn", Swings = 3, Power = 0.14, Time = 3, Duration = 8 },
	Animation = "Empower", IconSource = "ThermalBurst",
	Description = "Your next 3 swings ignite: each burns for 3s.",
	Flourish = { Text = "Ignited swings also hit 10% harder.", Empower = { Kind = "Burn", Swings = 3, Power = 0.14, Time = 3, Duration = 8, Bonus = 0.1 } },
}
M.Q_FurnaceCrescent = {
	Name = "Furnace Crescent", Element = "Fire", Lane = Q, Cost = 26, Cooldown = 8,
	Damage = 1.5, Cone = 150, Range = 10, Burn = { Power = 0.12, Time = 3 },
	Animation = "Sweep", Signature = "Crescent", IconSource = "FurnaceCrescent",
	Description = "A wide arc at 150% damage that sets everything it cuts burning.",
	Flourish = { Text = "The arc reaches 3 studs further.", Range = 13 },
}
M.Q_SolarExecution = {
	Name = "Solar Execution", Element = "Fire", Lane = Q, Cost = 30, Cooldown = 10,
	Damage = 1.6, Cone = 40, Range = 10, Windup = 0.5, LowHealth = { Below = 0.4, Bonus = 0.5 },
	Animation = "Lunge", Signature = "Helix", IconSource = "SolarExecution",
	Description = "A heavy thrust at 160%; +50% damage to targets under 40% health.",
	Flourish = { Text = "Finishes a target left under 10% health.", Execute = 0.1 },
}
M.Q_CinderDrill = {
	Name = "Cinder Drill", Element = "Fire", Lane = Q, Cost = 24, Cooldown = 7,
	Damage = 0.4, Hits = 4, Interval = 0.11, Cone = 40, Range = 9, LastBurn = { Power = 0.2, Time = 3 },
	Animation = "Drill", Signature = "Rail", IconSource = "CinderDrill",
	Description = "4 quick stabs at 40% each; the last one sets the target burning.",
	Flourish = { Text = "Every stab burns, not just the last.", Burn = { Power = 0.08, Time = 3 } },
}
M.Q_MagmaFault = {
	Name = "Magma Fault", Element = "Fire", Lane = Q, Cost = 30, Cooldown = 10, Show = "MagmaFault",
	Damage = 1.2, Piercing = true, Range = 14, Trail = { Time = 3, Width = 3, Burn = { Power = 0.1, Time = 2 } },
	Animation = "Erupt", Signature = "Spikes", IconSource = "MagmaFault",
	Description = "A ground slash: 120% damage in a line, leaving burning ground for 3s.",
	Flourish = { Text = "The burning ground lasts 5s.", Trail = { Time = 5, Width = 3, Burn = { Power = 0.1, Time = 2 } } },
}
M.E_EmberLance = {
	Name = "Ember Lance", Element = "Fire", Lane = E, Type = "Strike", Cost = 28, Cooldown = 10,
	Damage = 1.5, Range = 45, Burn = { Power = 0.15, Time = 4 },
	IconSource = "EmberLance",
	Description = "A fire bolt at 150% damage that sets its target burning for 4s.",
	Flourish = { Text = "The bolt pierces through everyone in its line.", Piercing = true },
}
M.E_Supernova = {
	Name = "Supernova", Element = "Fire", Lane = E, Type = "Strike", Cost = 45, Cooldown = 16, Show = "Supernova",
	Damage = 2.2, Radius = 10, Range = 30, Windup = 1, Burn = { Power = 0.1, Time = 3 },
	IconSource = "Supernova",
	Description = "A 1-second fuse, then a 220% blast across 10 studs.",
	Flourish = { Text = "Leaves a Burning Ward on you for 4s.", Ward = { Kind = "Burn", Shield = 15, Duration = 4, Power = 0.1 } },
}
M.E_SolarFlare = {
	Name = "Solar Flare", Element = "Fire", Lane = E, Type = "Strike", Cost = 32, Cooldown = 13,
	Damage = 0.5, Radius = 8, Self = true, Range = 0, Blind = 1, BlindTime = 1.5, BlindOnce = true,
	IconSource = "SolarFlare",
	Description = "A blinding nova: enemies within 8 studs miss their next swing.",
	Flourish = { Text = "Blinded enemies also burn for 3s.", Burn = { Power = 0.1, Time = 3 } },
}
M.E_HeatHaze = {
	Name = "Heat Haze", Element = "Fire", Lane = E, Type = "Aura", Cost = 25, Cooldown = 12,
	Aura = { AttackSpeed = 0.10 },
	Dash = { Dir = "Aim", Distance = 8, MoveTime = 0.22 }, Damage = 0.6, PathHit = true,
	Trail = { Time = 3, Width = 3, Burn = { Power = 0.1, Time = 2 } },
	Animation = "Lunge", IconSource = "CinderDrill",
	Description = "+10% attack speed while ready. Press: dash 8 studs through enemies, leaving fire.",
	Flourish = { Text = "+15% attack speed while ready.", Aura = { AttackSpeed = 0.15 } },
}
M.E_ThermalBurst = {
	Name = "Thermal Burst", Element = "Fire", Lane = E, Type = "Aura", Cost = 30, Cooldown = 15,
	Aura = { Damage = 0.08 }, DamageBoost = { Amount = 0.2, Time = 5 },
	Animation = "Buff", IconSource = "ThermalBurst",
	Description = "+8% damage while ready. Press: +20% damage for 5s.",
	Flourish = { Text = "The boost lasts 7s.", DamageBoost = { Amount = 0.2, Time = 7 } },
}
M.R_HeatShield = {
	Name = "Heat Shield", Element = "Fire", Lane = R, Cost = 20, Cooldown = 12,
	Absorb = 40, Duration = 4, Ward = { Kind = "Burn", Shield = 0, Duration = 4, Power = 0.12 },
	Animation = "Brace", IconSource = "Supernova",
	Description = "Absorb 40 damage for 4s; anyone who hits you burns.",
	Flourish = { Text = "When it ends, it bursts for 50% damage around you.", EndBurst = { Damage = 0.5, Radius = 7 } },
}
M.R_EmberGuard = {
	Name = "Ember Guard", Element = "Fire", Lane = R, Cost = 18, Cooldown = 10,
	Guard = { Kind = "Reflect", Share = 0.2, Time = 2 },
	Animation = "Brace", IconSource = "RiposteStance",
	Description = "2s of raised guard that reflects 20% of each blocked hit as fire.",
	Flourish = { Text = "Reflects 35% instead.", Guard = { Kind = "Reflect", Share = 0.35, Time = 2 } },
}
M.R_FireWall = {
	Name = "Fire Wall", Element = "Fire", Lane = R, Cost = 24, Cooldown = 14,
	Wall = { Kind = "Fire", Time = 3, Width = 10, Distance = 5, Burn = { Power = 0.15, Time = 3 } },
	Animation = "Wall", IconSource = "ThermalBurst",
	Description = "A 3s wall of fire in front: it stops bolts and burns whoever crosses it.",
	Flourish = { Text = "The wall stands for 4.5s.", Wall = { Kind = "Fire", Time = 4.5, Width = 10, Distance = 5, Burn = { Power = 0.15, Time = 3 } } },
}
M.R_Cauterize = {
	Name = "Cauterize", Element = "Fire", Lane = R, Cost = 22, Cooldown = 14,
	Cleanse = "Dots", Heal = { Share = 0.15, Time = 3 },
	Animation = "Buff", IconSource = "StimDodge",
	Description = "Cleanse burns and poisons, then heal 15% over 3s.",
	Flourish = { Text = "Also clears slows and armor shred.", Cleanse = "All" },
}
M.R_PhoenixMantle = {
	Name = "Phoenix Mantle", Element = "Fire", Lane = R, Rare = true, Cost = 30, Cooldown = 16,
	Phoenix = { Below = 0.2, Heal = 0.25, Time = 6 },
	Animation = "Buff", IconSource = "SolarFlare",
	Description = "For 6s, dropping under 20% health heals you 25% instead (once a round).",
	Flourish = { Text = "The rebirth blasts enemies around you.", EndBurst = { Damage = 0.8, Radius = 8 } },
}

-- CRYO · control and endurance ------------------------------------------------
M.Q_FrostNeedle = {
	Name = "Frost Needle", Element = "Frost", Lane = Q, Cost = 20, Cooldown = 6,
	Damage = 1.1, Cone = 25, Range = 11, Slow = 0.3, SlowTime = 2,
	Animation = "Lunge", Signature = "Rail", IconSource = "FrostNeedle",
	Description = "A piercing thrust at 110% that slows 30% for 2s.",
	Flourish = { Text = "Adds a Chill stack.", Chill = 1 },
}
M.Q_GlacierFan = {
	Name = "Glacier Fan", Element = "Frost", Lane = Q, Cost = 26, Cooldown = 8,
	Damage = 0.6, Hits = 3, Interval = 0.08, Cone = 70, Range = 14, Slow = 0.25, SlowTime = 2,
	Animation = "Sweep", Signature = "Crescent", IconSource = "GlacierFan",
	Description = "A cone of 3 ice shards at 60% each, slowing.",
	Flourish = { Text = "The fan widens to 100 degrees.", Cone = 100 },
}
M.Q_ShatterCrown = {
	Name = "Shatter Crown", Element = "Frost", Lane = Q, Cost = 32, Cooldown = 10,
	Damage = 1.3, Cone = 60, Range = 9, Windup = 0.6, VsChilled = 0.6,
	Animation = "Heavy", Signature = "Helix", IconSource = "ShatterCrown",
	Description = "A heavy blow at 130%: +60% damage to slowed or frozen targets.",
	Flourish = { Text = "Shatters a freeze for a 1s stun instead.", Stun = 0.6, StunKind = "Frozen", StunIfChilled = true },
}
M.Q_PermafrostSpire = {
	Name = "Permafrost Spire", Element = "Frost", Lane = Q, Cost = 26, Cooldown = 9, Show = "PermafrostSpire",
	Damage = 0.9, Radius = 3, Range = 20, Root = 0.8,
	Animation = "Erupt", Signature = "Spikes", IconSource = "PermafrostSpire",
	Description = "An ice spike under the target: 90% damage and rooted for 0.8s.",
	Flourish = { Text = "Roots for 1.2s.", Root = 1.2 },
}
M.Q_CryoEdge = {
	Name = "Cryo Edge", Element = "Frost", Lane = Q, Cost = 22, Cooldown = 8,
	Empower = { Kind = "Chill", Swings = 3, Duration = 8 },
	Animation = "Empower", IconSource = "CryoLance",
	Description = "Your next 3 swings each add a Chill stack; at 3 the target freezes for 1s.",
	Flourish = { Text = "Empowers 4 swings.", Empower = { Kind = "Chill", Swings = 4, Duration = 8 } },
}
M.E_CryoLance = {
	Name = "Cryo Lance", Element = "Frost", Lane = E, Type = "Strike", Cost = 26, Cooldown = 10,
	Damage = 1.2, Range = 45, Slow = 0.4, SlowTime = 2,
	IconSource = "CryoLance",
	Description = "An ice bolt at 120% damage that slows 40% for 2s.",
	Flourish = { Text = "Adds 2 Chill stacks.", Chill = 2 },
}
M.E_CryoStream = {
	Name = "Cryo Stream", Element = "Frost", Lane = E, Type = "Strike", Cost = 34, Cooldown = 12,
	Damage = 1.6, PerSecond = true, Prepaid = true, ChannelDuration = 2, Range = 24, Slow = 0.3, SlowTime = 1, Chill = 0.5,
	IconSource = "CryoStream",
	Description = "Hold for a 2s beam that slows and builds to a 1s freeze.",
	Flourish = { Text = "The beam lasts 3s.", ChannelDuration = 3 },
}
M.E_AbsoluteZero = {
	Name = "Absolute Zero", Element = "Frost", Lane = E, Type = "Strike", Rare = true, Cost = 48, Cooldown = 18, Show = "AbsoluteZero",
	Damage = 1.5, Radius = 10, Range = 30, Windup = 1, Stun = 1.5, StunKind = "Frozen",
	IconSource = "AbsoluteZero",
	Description = "A field that freezes everyone inside for 1.5s after a 1s fuse.",
	Flourish = { Text = "Frozen targets are slowed 40% for 3s after.", Slow = 0.4, SlowTime = 3 },
}
M.E_GlacierRetreat = {
	Name = "Glacier Retreat", Element = "Frost", Lane = E, Type = "Shift", Cost = 25, Cooldown = 11,
	Dash = { Dir = "Back", Distance = 10, MoveTime = 0.3 },
	IceField = { Radius = 6, Slow = 0.4, Time = 3 },
	Animation = "Leap", IconSource = "GlacierFan",
	Description = "Leap back 10 studs, leaving ice that slows 40%.",
	Flourish = { Text = "The ice also Chills whoever stands on it.", IceField = { Radius = 6, Slow = 0.4, Time = 3, Chill = true } },
}
M.E_WintersHold = {
	Name = "Winter's Hold", Element = "Frost", Lane = E, Type = "Aura", Cost = 30, Cooldown = 14,
	Aura = { SlowLonger = 0.5 },
	Damage = 0.4, Radius = 12, Self = true, Range = 0, RefreshSlows = { Slow = 0.4, Time = 3 },
	IconSource = "CryoShield",
	Description = "Your slows last 50% longer while ready. Press: refresh every slow near you.",
	Flourish = { Text = "Refreshed targets also take a Chill stack.", Chill = 1 },
}
M.R_FrozenWall = {
	Name = "Frozen Wall", Element = "Frost", Lane = R, Cost = 26, Cooldown = 14,
	Wall = { Kind = "Ice", Time = 2.5, Width = 8, Distance = 3.5, Front = true, NoSwing = true },
	Animation = "Wall", IconSource = "ShatterCrown",
	Description = "A wall of ice in front: blocks every frontal hit for 2.5s. You can't swing while it stands.",
	Flourish = { Text = "Whoever hits the wall is slowed 30%.", Wall = { Kind = "Ice", Time = 2.5, Width = 8, Distance = 3.5, Front = true, NoSwing = true, Slow = 0.3 } },
}
M.R_IceArmor = {
	Name = "Ice Armor", Element = "Frost", Lane = R, Cost = 22, Cooldown = 13,
	DamageCut = { Amount = 0.25, Time = 5, SelfSlow = 0.1 },
	Animation = "Brace", IconSource = "CryoShield",
	Description = "Take 25% less damage for 5s; you move 10% slower.",
	Flourish = { Text = "No slow on you.", DamageCut = { Amount = 0.25, Time = 5, SelfSlow = 0 } },
}
M.R_ColdResolve = {
	Name = "Cold Resolve", Element = "Frost", Lane = R, Cost = 20, Cooldown = 14,
	ResistAll = { Amount = 0.15, Time = 6 },
	Animation = "Brace", IconSource = "AbsoluteZero",
	Description = "+15% resistance to all elements for 6s.",
	Flourish = { Text = "+20% instead.", ResistAll = { Amount = 0.2, Time = 6 } },
}
M.R_GlacialBulwark = {
	Name = "Glacial Bulwark", Element = "Frost", Lane = R, Cost = 26, Cooldown = 15,
	Absorb = 60, Duration = 5, BreakSlow = { Radius = 8, Slow = 0.5, Time = 2 },
	Animation = "Brace", IconSource = "CryoShield",
	Description = "Absorb 60; when it breaks, everyone near you is slowed 50%.",
	Flourish = { Text = "The break also freezes them for 0.5s.", BreakSlow = { Radius = 8, Slow = 0.5, Time = 2, Freeze = 0.5 } },
}
M.R_FrostRiposte = {
	Name = "Frost Riposte", Element = "Frost", Lane = R, Cost = 16, Cooldown = 10,
	FrostRiposte = { Time = 6, Freeze = 1 },
	Animation = "Brace", IconSource = "RiposteStance",
	Description = "For 6s, a timed block freezes the attacker for 1s.",
	Flourish = { Text = "The timed-block window is 50% wider.", FrostRiposte = { Time = 6, Freeze = 1, Window = 1.5 } },
}

-- ION · speed and tempo -------------------------------------------------------
M.Q_ArcNeedle = {
	Name = "Arc Needle", Element = "Shock", Lane = Q, Cost = 20, Cooldown = 6,
	Dash = { Dir = "Aim", Distance = 6, MoveTime = 0.16 }, Damage = 1.2, Cone = 50, Range = 7,
	Animation = "Lunge", Signature = "Rail", IconSource = "ArcNeedle",
	Description = "Lunge 6 studs and strike at 120%.",
	Flourish = { Text = "The lunge interrupts a surge being cast.", Interrupt = 1 },
}
M.Q_CircuitCleave = {
	Name = "Circuit Cleave", Element = "Shock", Lane = Q, Cost = 26, Cooldown = 8,
	Damage = 1, Cone = 360, Range = 8, ArcExtra = { Count = 2, Share = 0.5, Range = 12 },
	Animation = "Spin", Signature = "Crescent", IconSource = "CircuitCleave",
	Description = "A spin at 100% that arcs on to 2 more enemies.",
	Flourish = { Text = "Arcs to 4 enemies.", ArcExtra = { Count = 4, Share = 0.5, Range = 12 } },
}
M.Q_Railstorm = {
	Name = "Railstorm", Element = "Shock", Lane = Q, Cost = 28, Cooldown = 9,
	Damage = 0.5, Hits = 3, Interval = 0.1, Cone = 35, Range = 10, Stun = 0.4, StunChance = 0.25, StunKind = "Shocked",
	Animation = "Drill", Signature = "Rail", IconSource = "Railstorm",
	Description = "3 rapid thrusts at 50% each, each with a 25% chance to stun.",
	Flourish = { Text = "40% stun chance.", StunChance = 0.4 },
}
M.Q_StaticBrand = {
	Name = "Static Brand", Element = "Shock", Lane = Q, Cost = 22, Cooldown = 9,
	Damage = 0.4, Range = 30, Mark = { Time = 6, Arc = 0.4, Steal = 3 },
	Animation = "Bolt", IconSource = "StaticField",
	Description = "Brands the target for 6s: your hits on it arc for 40% and steal 3 Charge.",
	Flourish = { Text = "The brand lasts 9s.", Mark = { Time = 9, Arc = 0.4, Steal = 3 } },
}
M.Q_OverchargeStrike = {
	Name = "Overcharge Strike", Element = "Shock", Lane = Q, Rare = true, Cost = 20, Cooldown = 10,
	Damage = 1, Cone = 60, Range = 9, Windup = 0.5, ConsumeCharge = 0.02,
	Animation = "Heavy", Signature = "Helix", IconSource = "Overload",
	Description = "A heavy blow that spends all your Charge: +2% damage per point.",
	Flourish = { Text = "Refunds 20 Charge if it kills.", KillRefund = 20 },
}
M.E_IonSpark = {
	Name = "Ion Spark", Element = "Shock", Lane = E, Type = "Strike", Cost = 25, Cooldown = 10,
	Damage = 1.1, Range = 45, Windup = 0.35, Stun = 0.5, StunChance = 0.2, StunKind = "Shocked",
	IconSource = "IonSpark",
	Description = "The fastest bolt: 110% damage with a 20% chance to stun.",
	Flourish = { Text = "Arcs to one more enemy.", Chain = 1, ChainRange = 12 },
}
M.E_ChainLightning = {
	Name = "Chain Lightning", Element = "Shock", Lane = E, Type = "Strike", Cost = 34, Cooldown = 13,
	Damage = 1, Range = 40, Chain = 3, ChainRange = 14,
	IconSource = "ChainLightning",
	Description = "A bolt that bounces between 3 more targets.",
	Flourish = { Text = "Bounces don't weaken.", ChainKeep = true },
}
M.E_ThunderPylon = {
	Name = "Thunder Pylon", Element = "Shock", Lane = E, Type = "Strike", Cost = 38, Cooldown = 15,
	Damage = 0.3, Radius = 3, Range = 25, Pylon = { Every = 0.5, Time = 4, Reach = 12, Damage = 0.3 },
	Animation = "Erupt", Signature = "Spikes", IconSource = "ThunderPylon",
	Description = "A pylon that zaps the nearest enemy every 0.5s for 4s.",
	Flourish = { Text = "Each zap has a 15% chance to stun.", Pylon = { Every = 0.5, Time = 4, Reach = 12, Damage = 0.3, Stun = 0.15 } },
}
M.E_VectorDash = {
	Name = "Vector Dash", Element = "Shock", Lane = E, Type = "Shift", Cost = 25, Cooldown = 10,
	Dash = { Dir = "Aim", Distance = 10, MoveTime = 0.2 }, NextCrit = 4,
	Animation = "Leap", IconSource = "CircuitCleave",
	Description = "Blink 10 studs; your next hit within 4s is a critical.",
	Flourish = { Text = "The blink leaves a shocking afterimage.", Trail = { Time = 2, Width = 3, Stun = 0.3 } },
}
M.E_Overload = {
	Name = "Overload", Element = "Shock", Lane = E, Type = "Aura", Cost = 30, Cooldown = 15,
	Aura = { ChargeGain = 0.15 },
	Damage = 0.3, Radius = 8, Self = true, Range = 0, DrainCharge = 20,
	IconSource = "Overload",
	Description = "+15% Charge from hits while ready. Press: drain 20 Charge from enemies within 8 studs.",
	Flourish = { Text = "+25% Charge from hits while ready.", Aura = { ChargeGain = 0.25 } },
}
M.R_IonShield = {
	Name = "Ion Shield", Element = "Shock", Lane = R, Cost = 22, Cooldown = 14,
	Absorb = 30, Duration = 8, Refill = 3,
	Animation = "Brace", IconSource = "StaticField",
	Description = "Absorb 30 for 8s; it refills to full after 3s without being hit.",
	Flourish = { Text = "Refills after 2s.", Refill = 2 },
}
M.R_StaticCatch = {
	Name = "Static Catch", Element = "Shock", Lane = R, Cost = 16, Cooldown = 10,
	Catch = { Time = 2, Window = 2, Stun = 0.6, Steal = 10 },
	Animation = "Brace", IconSource = "KineticRam",
	Description = "For 2s the timed-block window doubles; a parry stuns 0.6s and steals 10 Charge.",
	Flourish = { Text = "Lasts 3s.", Catch = { Time = 3, Window = 2, Stun = 0.6, Steal = 10 } },
}
M.R_Capacitor = {
	Name = "Capacitor", Element = "Shock", Lane = R, Cost = 22, Cooldown = 12,
	Absorb = 35, Duration = 4, Siphon = 0.5,
	Animation = "Brace", IconSource = "EnergySiphon",
	Description = "For 4s, absorb 35 damage and turn half of it into Charge.",
	Flourish = { Text = "Turns all of it into Charge.", Siphon = 1 },
}
M.R_DeflectorField = {
	Name = "Deflector Field", Element = "Shock", Lane = R, Cost = 22, Cooldown = 13,
	Deflect = { Time = 3, Share = 1 },
	Animation = "Brace", IconSource = "NullPrism",
	Description = "For 3s, bolts and projectiles bounce back at whoever threw them.",
	Flourish = { Text = "Lasts 4s.", Deflect = { Time = 4, Share = 1 } },
}
M.R_Grounding = {
	Name = "Grounding", Element = "Shock", Lane = R, Cost = 24, Cooldown = 15,
	Grounding = { Time = 3 }, Cleanse = "Control",
	Animation = "Brace", IconSource = "TremorSlam",
	Description = "Immune to stun, slow and freeze for 3s, and cleanses them.",
	Flourish = { Text = "Lasts 4s.", Grounding = { Time = 4 } },
}

-- CORROSIVE · attrition -------------------------------------------------------
M.Q_BreachCut = {
	Name = "Breach Cut", Element = "Poison", Lane = Q, Cost = 22, Cooldown = 7,
	Damage = 1.1, Cone = 70, Range = 9, Shred = 0.15, ShredTime = 5,
	Animation = "Sweep", Signature = "Crescent", IconSource = "ArmorPiercer",
	Description = "A cut at 110% that shreds 15% of the target's defense for 5s.",
	Flourish = { Text = "Shreds 25%.", Shred = 0.25 },
}
M.Q_CausticDart = {
	Name = "Caustic Dart", Element = "Poison", Lane = Q, Cost = 22, Cooldown = 7,
	Damage = 0.8, Range = 30, Poison = { Power = 0.15, Time = 4 },
	Animation = "Bolt", Signature = "Rail", IconSource = "CausticDart",
	Description = "A thrown blade: 80% damage and poison, at range.",
	Flourish = { Text = "The poison lasts 6s.", Poison = { Power = 0.15, Time = 6 } },
}
M.Q_VitriolSweep = {
	Name = "Vitriol Sweep", Element = "Poison", Lane = Q, Cost = 26, Cooldown = 8,
	Damage = 1, Cone = 120, Range = 9, Vulnerable = { Amount = 0.2, Time = 4 },
	Animation = "Sweep", Signature = "Crescent", IconSource = "VitriolSweep",
	Description = "A low sweep at 100%: hit targets take 20% more damage for 4s.",
	Flourish = { Text = "Also poisons.", Poison = { Power = 0.1, Time = 4 } },
}
M.Q_Dissolution = {
	Name = "Dissolution", Element = "Poison", Lane = Q, Rare = true, Cost = 30, Cooldown = 10,
	Damage = 1, Cone = 50, Range = 9, Windup = 0.5, BurstPoison = 1.5,
	Animation = "Heavy", Signature = "Helix", IconSource = "Dissolution",
	Description = "A heavy blow that bursts every poison on the target at once, at 150%.",
	Flourish = { Text = "Bursts at 200%.", BurstPoison = 2 },
}
M.Q_SappingEdge = {
	Name = "Sapping Edge", Element = "Poison", Lane = Q, Cost = 20, Cooldown = 8,
	Empower = { Kind = "Sap", Swings = 3, Steal = 8, Duration = 8 },
	Animation = "Empower", IconSource = "BioCorrosion",
	Description = "Your next 3 hits each steal 8 Stamina from the target.",
	Flourish = { Text = "Each sapped hit also poisons.", Empower = { Kind = "Sap", Swings = 3, Steal = 8, Duration = 8, Poison = { Power = 0.08, Time = 3 } } },
}
M.E_AcidSpray = {
	Name = "Acid Spray", Element = "Poison", Lane = E, Type = "Strike", Cost = 26, Cooldown = 10,
	Damage = 0.9, Cone = 70, Range = 12, Poison = { Power = 0.15, Time = 4 },
	IconSource = "AcidSpray",
	Description = "A cone of acid at 90% that poisons everything it touches.",
	Flourish = { Text = "Also shreds 10% defense.", Shred = 0.1, ShredTime = 4 },
}
M.E_ToxicCloud = {
	Name = "Toxic Cloud", Element = "Poison", Lane = E, Type = "Strike", Cost = 36, Cooldown = 14,
	Damage = 0.3, Radius = 9, Range = 30, Cloud = { Duration = 5, Every = 1, Damage = 0.25 }, Duration = 5,
	Poison = { Power = 0.1, Time = 2 },
	IconSource = "ToxicCloud",
	Description = "A 5s cloud that poisons whoever stands in it.",
	Flourish = { Text = "The cloud lasts 7s.", Cloud = { Duration = 7, Every = 1, Damage = 0.25 }, Duration = 7 },
}
M.E_ArmorMelt = {
	Name = "Armor Melt", Element = "Poison", Lane = E, Type = "Strike", Cost = 30, Cooldown = 13,
	Damage = 0.8, Range = 40, Vulnerable = { Amount = 0.15, Time = 6 },
	IconSource = "ArmorMelt",
	Description = "A corrosive bolt: the target takes 15% more damage from everything for 6s.",
	Flourish = { Text = "Also slows 30% for 2s.", Slow = 0.3, SlowTime = 2 },
}
M.E_LeechBloom = {
	Name = "Leech Bloom", Element = "Poison", Lane = E, Type = "Strike", Cost = 36, Cooldown = 15,
	Damage = 0.25, Radius = 7, Range = 30, Cloud = { Duration = 4, Every = 1, Damage = 0.2 }, Duration = 4,
	HealPerEnemy = 0.03,
	IconSource = "LeechBloom",
	Description = "A 4s bloom that heals you 3% a second for each enemy inside.",
	Flourish = { Text = "Heals 4% per enemy.", HealPerEnemy = 0.04 },
}
M.E_SeepStep = {
	Name = "Seep Step", Element = "Poison", Lane = E, Type = "Aura", Cost = 25, Cooldown = 12,
	Aura = { PoisonLonger = 0.3 },
	Dash = { Dir = "Side", Distance = 8, MoveTime = 0.24 }, Untargetable = 1,
	Animation = "Leap", IconSource = "VitriolSweep",
	Description = "Your poisons last 30% longer while ready. Press: slip 8 studs and become untargetable for 1s.",
	Flourish = { Text = "Leaves a poison cloud where you stood.", Trail = { Time = 3, Width = 4, Poison = { Power = 0.1, Time = 2 } } },
}
M.R_RadShield = {
	Name = "Rad Shield", Element = "Poison", Lane = R, Cost = 18, Cooldown = 11,
	Absorb = 35, Duration = 4, Cleanse = "One",
	Animation = "Brace", IconSource = "ToxicCloud",
	Description = "Absorb 35 damage and cleanse one debuff.",
	Flourish = { Text = "Cleanses every debuff.", Cleanse = "All" },
}
M.R_PurgeShell = {
	Name = "Purge Shell", Element = "Poison", Lane = R, Cost = 22, Cooldown = 13,
	Cleanse = "All", Immune = 2,
	Animation = "Buff", IconSource = "BioCorrosion",
	Description = "Cleanse every debuff and ignore new ones for 2s.",
	Flourish = { Text = "Ignores new debuffs for 3s.", Immune = 3 },
}
M.R_CorrosionAura = {
	Name = "Corrosion Aura", Element = "Poison", Lane = R, Cost = 24, Cooldown = 14,
	CorrosionAura = { Radius = 6, Stamina = 5, Shred = 0.1, Time = 5 },
	Animation = "Buff", IconSource = "ToxicCloud",
	Description = "For 5s, enemies within 6 studs lose 5 Stamina a second and 10% defense.",
	Flourish = { Text = "Reaches 9 studs.", CorrosionAura = { Radius = 9, Stamina = 5, Shred = 0.1, Time = 5 } },
}
M.R_BioRegrowth = {
	Name = "Bio Regrowth", Element = "Poison", Lane = R, Cost = 22, Cooldown = 15,
	Heal = { Share = 0.3, Time = 6, BreakOnHeavy = true },
	Animation = "Buff", IconSource = "LeechBloom",
	Description = "Heal 30% over 6s; a heavy hit on you stops it.",
	Flourish = { Text = "Heavy hits no longer stop it.", Heal = { Share = 0.3, Time = 6 } },
}
M.R_ToxicMantle = {
	Name = "Toxic Mantle", Element = "Poison", Lane = R, Cost = 20, Cooldown = 13,
	Mantle = { Share = 0.25, Time = 5 },
	Animation = "Buff", IconSource = "AcidSpray",
	Description = "For 5s, melee attackers are poisoned for 25% of the damage they deal you.",
	Flourish = { Text = "40% instead.", Mantle = { Share = 0.4, Time = 5 } },
}
-- The showcase defenses: each element's barrier and escape. Every one
-- puts something into the world you can see from across the arena.
M.R_RingOfFire = {
	Name = "Ring of Fire", Element = "Fire", Lane = R, Cost = 24, Cooldown = 14, Showcase = true,
	Ring = { Radius = 7, Time = 4, Burn = { Power = 0.15, Time = 3 }, Push = 45 },
	Animation = "Wall", IconSource = "SolarFlare",
	Description = "Flames circle you for 4s: whoever crosses the ring catches fire and is thrown back.",
	Flourish = { Text = "The ring burns for 5.5s.", Ring = { Radius = 7, Time = 5.5, Burn = { Power = 0.15, Time = 3 }, Push = 45 } },
}
M.R_IcePillar = {
	Name = "Ice Pillar", Element = "Frost", Lane = R, Cost = 24, Cooldown = 14, Showcase = true,
	Pillar = { Height = 9, Time = 2.5, Radius = 8, Slow = 0.5, SlowTime = 2 },
	Animation = "Wall", IconSource = "CryoShield",
	Description = "An ice column bursts up under you: out of reach for 2.5s, then it shatters and slows everyone near you 50%.",
	Flourish = {
		Text = "The shatter freezes them for 0.6s.",
		Pillar = { Height = 9, Time = 2.5, Radius = 8, Slow = 0.5, SlowTime = 2, Freeze = 0.6 },
	},
}
M.R_TeslaFence = {
	Name = "Tesla Fence", Element = "Shock", Lane = R, Cost = 24, Cooldown = 14, Showcase = true,
	Wall = { Kind = "Tesla", Time = 3, Width = 10, Distance = 5, Stun = 0.6 },
	Animation = "Wall", IconSource = "IonSpark",
	Description = "A curtain of lightning strikes down for 3s: it stops bolts and stuns whoever crosses.",
	Flourish = { Text = "The fence stands for 4.5s.", Wall = { Kind = "Tesla", Time = 4.5, Width = 10, Distance = 5, Stun = 0.6 } },
}
M.R_HoloDecoy = {
	Name = "Hologram Decoy", Element = "Shock", Lane = R, Cost = 22, Cooldown = 13, Showcase = true,
	Dash = { Dir = "Back", Distance = 9, MoveTime = 0.15 }, Untargetable = 0.4,
	Decoy = { Time = 3, Trigger = 4, Radius = 6, Stun = 1, Damage = 0.6 },
	Animation = "Dodge", IconSource = "ThrusterLeap",
	Description = "Blink back 9 studs and leave a hologram of yourself. When a foe gets close (or after 3s) it bursts: 60% damage and a 1s stun.",
	Flourish = { Text = "The burst stuns for 1.4s.", Decoy = { Time = 3, Trigger = 4, Radius = 6, Stun = 1.4, Damage = 0.6 } },
}
M.R_SporeWall = {
	Name = "Spore Wall", Element = "Poison", Lane = R, Cost = 24, Cooldown = 14, Showcase = true,
	Wall = { Kind = "Spore", Time = 3.5, Width = 10, Distance = 5, Poison = { Power = 0.15, Time = 4 } },
	Animation = "Wall", IconSource = "BioCorrosion",
	Description = "A wall of toxic fog for 3.5s: it stops bolts and poisons whoever walks through.",
	Flourish = { Text = "The wall stands for 5s.", Wall = { Kind = "Spore", Time = 5, Width = 10, Distance = 5, Poison = { Power = 0.15, Time = 4 } } },
}
M.R_AcidSlick = {
	Name = "Acid Slick", Element = "Poison", Lane = R, Cost = 22, Cooldown = 13, Showcase = true,
	Slick = { Radius = 7, Time = 4, Slow = 0.5, Shred = 0.1 },
	Animation = "Wall", IconSource = "AcidSpray",
	Description = "Spill an acid slick around you for 4s: foes on it slide, slowed 50%, and lose 10% defense.",
	Flourish = { Text = "The slick lasts 5.5s.", Slick = { Radius = 7, Time = 5.5, Slow = 0.5, Shred = 0.1 } },
}

-- The intro moves: what a new player's kit rolls (GemTraits.Intro). Every one
-- pays off against a single opponent, and looks it (TriadVfx.show).
M.Q_MeteorLeap = {
	Name = "Meteor Leap", Element = "Fire", Lane = Q, Cost = 28, Cooldown = 9, Show = "MeteorLeap",
	Pounce = { Distance = 14, Time = 0.5, Lift = 44 },
	Damage = 1.5, Radius = 6, Self = true, Push = 40, Burn = { Power = 0.12, Time = 3 },
	Crater = { Radius = 5, Time = 3, Burn = { Power = 0.1, Time = 2 } },
	Animation = "Leap", IconSource = "MeteorLeap",
	Description = "Leap up to 14 studs and crash down like a meteor: 150% around you, foes thrown back, and the crater burns for 3s.",
	Flourish = { Text = "The crater burns for 5s.", Crater = { Radius = 5, Time = 5, Burn = { Power = 0.1, Time = 2 } } },
}
M.E_FlameTornado = {
	Name = "Flame Tornado", Element = "Fire", Lane = E, Type = "Strike", Cost = 36, Cooldown = 14, Show = "FlameTornado",
	Damage = 0.22, Range = 22, Windup = 0.5, Burn = { Power = 0.08, Time = 2 },
	Vortex = { Distance = 22, Time = 2.2, Radius = 4.5, Every = 0.35, Pull = 16, End = 4, EndRadius = 6 },
	Animation = "Spin", IconSource = "FlameTornado",
	Description = "A tornado of fire tears across 22 studs, dragging foes along and burning them, then bursts at 90%.",
	Flourish = { Text = "The final burst hits at 130%.", Vortex = { Distance = 22, Time = 2.2, Radius = 4.5, Every = 0.35, Pull = 16, End = 6, EndRadius = 7 } },
}
M.Q_FrostChakram = {
	Name = "Frost Chakram", Element = "Frost", Lane = Q, Cost = 24, Cooldown = 8, Show = "FrostChakram",
	Damage = 0.85, Range = 16, Windup = 0.3, Chill = 1,
	Disc = { Distance = 16, Time = 1.1, Radius = 3 },
	Animation = "Sweep", IconSource = "FrostChakram",
	Description = "Hurl a spinning blade of ice out 16 studs and back: 85% each way, and every hit Chills (3 Chills freeze).",
	Flourish = { Text = "Each hit adds 2 Chills.", Chill = 2 },
}
M.E_Hailstorm = {
	Name = "Hailstorm", Element = "Frost", Lane = E, Type = "Strike", Cost = 38, Cooldown = 15, Show = "Hailstorm",
	Damage = 0.24, Radius = 9, Range = 30, Windup = 0.6,
	Hail = { Time = 3, Every = 0.5, Chill = 0.75 },
	Animation = "Nova", IconSource = "Hailstorm",
	Description = "Ice rains on an area for 3s: 24% every half second, and anyone who stays 2s is frozen solid.",
	Flourish = { Text = "The storm lasts 4s.", Hail = { Time = 4, Every = 0.5, Chill = 0.75 } },
}
M.Q_ThunderDash = {
	Name = "Thunder Dash", Element = "Shock", Lane = Q, Cost = 26, Cooldown = 8, Show = "ThunderDash",
	Dash = { Dir = "Aim", Distance = 13, MoveTime = 0.14 }, Untargetable = 0.05,
	Damage = 1.3, PathHit = true, Stun = 0.45, StunKind = "Shocked",
	Trail = { Time = 2, Width = 3, Stun = 0.3 },
	Animation = "Lunge", IconSource = "ThunderDash",
	Description = "Become lightning: flash 13 studs through your foe for 130% and a stun, leaving a crackling trail.",
	Flourish = { Text = "Flash 17 studs.", Dash = { Dir = "Aim", Distance = 17, MoveTime = 0.16 } },
}
M.Q_Skybreaker = {
	Name = "Skybreaker", Element = "Shock", Lane = Q, Cost = 30, Cooldown = 10, Show = "Skybreaker",
	Damage = 1.7, Radius = 4.5, Range = 16, Windup = 0.55, Stun = 0.7, StunKind = "Shocked",
	Animation = "Heavy", IconSource = "Skybreaker",
	Description = "Raise your blade to the sky and bring down a bolt of lightning on your foe: 170% and stunned 0.7s.",
	Flourish = { Text = "Stuns for 1s.", Stun = 1 },
}
M.E_StormCall = {
	Name = "Storm Call", Element = "Shock", Lane = E, Type = "Strike", Cost = 38, Cooldown = 15, Show = "StormCall",
	Damage = 0.55, Radius = 11, Range = 30, Windup = 0.5,
	Storm = { Strikes = 5, Every = 0.45, Delay = 0.4, Radius = 3.2, Stun = 0.7 },
	Animation = "Nova", IconSource = "StormCall",
	Description = "A storm over the area: 5 bolts hunt the nearest foe, 55% each (marked just before), the last one stuns.",
	Flourish = { Text = "7 bolts.", Storm = { Strikes = 7, Every = 0.45, Delay = 0.4, Radius = 3.2, Stun = 0.7 } },
}
M.E_IonCannon = {
	Name = "Ion Cannon", Element = "Shock", Lane = E, Type = "Strike", Cost = 42, Cooldown = 16, Show = "IonCannon",
	Damage = 2.3, Range = 45, Piercing = true, Width = 3.5, Windup = 0.9, Push = 36,
	Animation = "Bolt", IconSource = "IonCannon",
	Description = "Charge for a moment, then fire a beam that pierces everything in a 45-stud line: 230% and blown back.",
	Flourish = { Text = "The beam also stuns for 0.6s.", Stun = 0.6, StunKind = "Shocked" },
}
M.Q_ViperLash = {
	Name = "Viper Lash", Element = "Poison", Lane = Q, Cost = 26, Cooldown = 9, Show = "ViperLash",
	Damage = 0.9, Range = 16, Width = 3, Pull = 4, Slow = 0.4, SlowTime = 1.5, Poison = { Power = 0.14, Time = 4 },
	Animation = "Bolt", IconSource = "ViperLash",
	Description = "A venom whip snaps out 16 studs and drags your foe to you: 90%, poisoned and slowed.",
	Flourish = { Text = "Reaches 22 studs.", Range = 22 },
}
M.Q_ToxicFlask = {
	Name = "Toxic Flask", Element = "Poison", Lane = Q, Cost = 26, Cooldown = 8, Show = "ToxicFlask",
	Damage = 1.2, Radius = 5, Range = 22, Lob = 0.4, Poison = { Power = 0.12, Time = 4 },
	Puddle = { Radius = 5, Time = 3, Slow = 0.35, Poison = { Power = 0.1, Time = 2 } },
	Animation = "Bolt", IconSource = "ToxicFlask",
	Description = "Lob a flask of acid: it bursts for 120% and poison, and leaves a pool that slows for 3s.",
	Flourish = { Text = "The pool lasts 5s.", Puddle = { Radius = 5, Time = 5, Slow = 0.35, Poison = { Power = 0.1, Time = 2 } } },
}
M.E_ToxicTide = {
	Name = "Toxic Tide", Element = "Poison", Lane = E, Type = "Strike", Cost = 38, Cooldown = 15, Show = "ToxicTide",
	Damage = 1.4, Range = 24, Windup = 0.55, Poison = { Power = 0.12, Time = 4 }, Vulnerable = { Amount = 0.15, Time = 4 },
	Wave = { Distance = 24, Time = 1.2, Width = 11, Push = 30 },
	Animation = "Sweep", IconSource = "ToxicTide",
	Description = "A towering wave of acid rolls out 24 studs: 140%, poisoned, carried along and taking 15% more damage for 4s.",
	Flourish = { Text = "The wave is 16 studs wide.", Wave = { Distance = 24, Time = 1.2, Width = 16, Push = 30 } },
}
M.E_Maneater = {
	Name = "Maneater", Element = "Poison", Lane = E, Type = "Strike", Cost = 40, Cooldown = 16, Show = "Maneater",
	Damage = 1.6, Radius = 4.5, Range = 26, Windup = 0.7, Root = 1.3, Poison = { Power = 0.15, Time = 5 },
	Animation = "Erupt", IconSource = "Maneater",
	Description = "A giant flytrap bursts from the ground under your foe and snaps shut: 160%, held 1.3s, deeply poisoned.",
	Flourish = { Text = "You heal 25% of the damage.", Leech = 0.25 },
}

-- The intro's Q and E moves the old pools gave (and their place in the new
-- ones): starter stones that still carry one are moved over
-- (GemTraits.upgradeStarter).
GemTraits.IntroReplaced = {
	Q_FurnaceCrescent = "Q_MeteorLeap", E_HeatHaze = "E_FlameTornado",
	Q_GlacierFan = "Q_FrostChakram", E_CryoStream = "E_Hailstorm",
	Q_CircuitCleave = "Q_ThunderDash", Q_Railstorm = "Q_Skybreaker",
	E_ChainLightning = "E_StormCall", E_ThunderPylon = "E_IonCannon",
	Q_CausticDart = "Q_ViperLash", Q_VitriolSweep = "Q_ToxicFlask",
	E_ToxicCloud = "E_ToxicTide", E_LeechBloom = "E_Maneater",
}

GemTraits.Moves = M

-- A new player's starter kit rolls each key from these: the moves made to
-- be seen (walls, rings, pillars, blasts, beams, turrets), never a plain
-- shield or a number. Two per key per element (Shared.StarterLottery).
GemTraits.Intro = {
	Fire = {
		Offense = { "Q_MeteorLeap", "Q_MagmaFault" },
		Ability = { "E_Supernova", "E_FlameTornado" },
		Defense = { "R_FireWall", "R_RingOfFire" },
	},
	Frost = {
		Offense = { "Q_FrostChakram", "Q_PermafrostSpire" },
		Ability = { "E_AbsoluteZero", "E_Hailstorm" },
		Defense = { "R_FrozenWall", "R_IcePillar" },
	},
	Shock = {
		Offense = { "Q_ThunderDash", "Q_Skybreaker" },
		Ability = { "E_StormCall", "E_IonCannon" },
		Defense = { "R_TeslaFence", "R_HoloDecoy" },
	},
	Poison = {
		Offense = { "Q_ViperLash", "Q_ToxicFlask" },
		Ability = { "E_ToxicTide", "E_Maneater" },
		Defense = { "R_SporeWall", "R_AcidSlick" },
	},
}

-- Lane defaults: what each key pays with and its lockout.
GemTraits.LaneRules = {
	Offense = { Resource = "Charge", Recovery = 0.6 },
	Ability = { Resource = "Charge", Recovery = 0.6 },
	Defense = { Resource = "Stamina", Recovery = 0.4 },
}
for id, move in M do
	local rules = GemTraits.LaneRules[move.Lane]
	move.Id = id
	move.Triad = true
	move.Resource = rules.Resource
	move.Recovery = move.Recovery or rules.Recovery
	move.Range = move.Range or 0
	move.Key = GemTraits.KeyOfLane[move.Lane]
	-- A sword technique comes out quick: a short wind-up, not a cast.
	if move.Lane == "Offense" and move.Damage and not move.Windup and not move.Dash and not move.Pounce then
		move.Windup = if move.Radius or move.Piercing then 0.45 else 0.35
	end
end

-- The element each move belongs to, and its slot in its lane.
GemTraits.Index = {}
for element, lanes in GemTraits.Matrix do
	for lane, ids in lanes do
		for i, id in ids do
			GemTraits.Index[id] = { Element = element, Lane = lane, Slot = i }
		end
	end
end

local function weightOf(id: string): number
	local move = M[id]
	return if move and move.Rare then GemTraits.SignatureWeight else 1
end

-- The odds of each move in an element's lane (adds to 1).
function GemTraits.odds(element: string, lane: string): { [string]: number }
	local ids = GemTraits.Matrix[element] and GemTraits.Matrix[element][lane]
	local out, total = {}, 0
	for _, id in ids or {} do
		total += weightOf(id)
	end
	for _, id in ids or {} do
		out[id] = weightOf(id) / total
	end
	return out
end

-- A move picked by weight; `roll` is 0-1.
local function pickWeighted(ids: { string }, roll: number): string
	local total = 0
	for _, id in ids do
		total += weightOf(id)
	end
	local at = roll * total
	for _, id in ids do
		at -= weightOf(id)
		if at < 0 then
			return id
		end
	end
	return ids[#ids]
end

-- Three fresh traits for a gem of `element` (a Random).
function GemTraits.roll(rng, element: string)
	local lanes = GemTraits.Matrix[element]
	if not lanes then
		return nil
	end
	return {
		Offense = pickWeighted(lanes.Offense, rng:NextNumber()),
		Ability = pickWeighted(lanes.Ability, rng:NextNumber()),
		Defense = pickWeighted(lanes.Defense, rng:NextNumber()),
	}
end

-- A steady 0-1 number for a gem and a lane, from the gem's id.
local function seeded(gem, salt: number): number
	local seed = 7919 + salt * 104729
	local id = tostring(gem.Id or gem.Surge or "")
	for i = 1, #id do
		seed = (seed * 31 + string.byte(id, i) + salt) % 2147483647
	end
	-- One more scramble so neighbouring ids spread out.
	seed = (seed * 1103515245 + 12345) % 2147483648
	return (seed % 100000) / 100000
end

local LANE_SALT = { Offense = 1, Ability = 2, Defense = 3 }
-- A gem with no saved traits picks from its lanes as they stood before the
-- intro moves joined them (the first this many), so no one's moves change
-- under them.
GemTraits.SeedLength = { Offense = 5, Ability = 5 }
local function seedPool(ids: { string }, lane: string): { string }
	local length = GemTraits.SeedLength[lane]
	if not length or #ids <= length then
		return ids
	end
	return table.move(ids, 1, length, 1, {})
end

-- A gem's three traits: its saved roll, else seeded from its id (so the
-- server and every client agree without a migration). A gem whose surge is
-- in the matrix keeps it in that lane. A kaiju's Gemsoul keeps to the
-- moves a kaiju can cast (SoulMoves): one saved from before (when only its
-- E woke) that isn't one is seeded from them.
function GemTraits.traitsOf(gem)
	if not gem or not gem.Element or not GemTraits.Matrix[gem.Element] then
		return nil
	end
	local soul = type(gem.Soul) == "table" and gem.Soul.Kind == "Kaiju"
	local lanes = if soul then GemTraits.SoulMoves[gem.Element] else GemTraits.Matrix[gem.Element]
	local saved = type(gem.Traits) == "table" and gem.Traits or {}
	local kept = if soul then nil else GemTraits.FromSurge[gem.Surge or ""]
	local keptInfo = kept and GemTraits.Index[kept]
	local out = {}
	for lane, ids in lanes do
		local id = saved[lane]
		if not (type(id) == "string" and table.find(ids, id)) then
			if keptInfo and keptInfo.Lane == lane and keptInfo.Element == gem.Element then
				id = kept
			else
				id = pickWeighted(seedPool(ids, lane), seeded(gem, LANE_SALT[lane]))
			end
		end
		out[lane] = id
	end
	return out
end

-- The trait a gem gives a key (Q, E or R).
function GemTraits.traitFor(gem, key: string): string?
	local traits = GemTraits.traitsOf(gem)
	local lane = GemTraits.Lanes[key]
	return traits and lane and traits[lane]
end

-- Is the loadout on the classic surge array (a DEV comparison switch)?
function GemTraits.active(loadout): boolean
	return GemTraits.Enabled and not (loadout and loadout.LegacySurges == true)
end

-- The gem a key reads (from the sword, the chest or the shield). With
-- no shield carried (a two-handed weapon), the weapon is its own guard: R
-- reads the weapon's gem.
function GemTraits.socketGem(loadout, key: string)
	local slot = GemTraits.Sockets[key]
	if not slot or not loadout then
		return nil
	end
	local gem = loadout[slot .. "Gem"]
	if not gem and key == "R" and not loadout.Shield then
		gem = loadout.WeaponGem
	end
	return gem
end

-- A save from before E came from the chest: the old core socket's gem goes
-- onto the chest worn when it has none, else back to the pouch (`maxGems`
-- is the pouch's size); with no room it stays saved where it is. Returns
-- where it went ("Chest", "Stash", or nil) and whether the old socket is
-- clear.
function GemTraits.moveCoreGem(profile, maxGems: number): (string?, boolean)
	local c = profile.Character
	local gem = c.Surge2Gem
	if not gem then
		return nil, true
	end
	if c.Armor and not c.ArmorGem then
		c.ArmorGem, c.Surge2Gem = gem, nil
		c.ItemGems = c.ItemGems or {}
		c.ItemGems.Armor = c.ItemGems.Armor or {}
		c.ItemGems.Armor[c.Armor] = gem
		return "Chest", true
	end
	if #profile.Gems < maxGems then
		table.insert(profile.Gems, gem)
		c.Surge2Gem = nil
		return "Stash", true
	end
	return nil, false
end

-- What a key fires: a copy of the socket's gem carrying the trait id as its
-- surge (Surge), its own surge kept as LegacySurge. The saved gem is untouched.
function GemTraits.project(gem, key: string)
	local id = gem and GemTraits.traitFor(gem, key)
	if not id then
		return nil
	end
	local projected = table.clone(gem)
	projected.Surge, projected.LegacySurge = id, gem.Surge
	projected.TraitKey, projected.TraitLane, projected.SourceId = key, GemTraits.Lanes[key], gem.Id
	return projected
end

-- Output (0-1) for a gem's rarity.
function GemTraits.output(gem, normalized: boolean?): number
	if normalized then
		return GemTraits.NormalizedOutput
	end
	return GemTraits.Output[gem and gem.Tier or "Common"] or GemTraits.Output.Common
end

-- Size / Clarity / Cut (1-10) as fractions of their full effect.
local function metric(gem, key: string): number
	return (math.clamp((gem and gem[key]) or 1, 1, 10) - 1) / 9
end

local POTENCY = { "Damage", "Absorb", "HealPerEnemy", "BurstPoison", "ConsumeCharge", "DrainCharge" }
local function scaleTable(value, factor: number, keys: { string })
	if type(value) ~= "table" then
		return value
	end
	local copy = table.clone(value)
	for _, key in keys do
		if type(copy[key]) == "number" then
			copy[key] *= factor
		end
	end
	return copy
end
local function longer(value, factor: number, keys: { string })
	return scaleTable(value, factor, keys)
end

--[[
	A move's numbers for one gem (a copy). Output scales what it does, not
	what it costs: damage, absorb, healing, burns and poisons, steals and
	drains, reflect and damage-reduction shares. Size adds potency, Clarity
	stretches durations, Cut trims the cooldown. A Legendary adds its Flourish.
]]
function GemTraits.stats(id: string, gem, normalized: boolean?)
	local base = M[id]
	if not base then
		return nil
	end
	local d = table.clone(base)
	local rarity = gem and gem.Tier or "Common"
	if rarity == "Legendary" and not normalized and base.Flourish then
		for key, value in base.Flourish do
			if key ~= "Text" then
				d[key] = value
			end
		end
		d.Flourished = true
	end
	local output = GemTraits.output(gem, normalized)
	local potency = output * (1 + GemTraits.SizePotency * metric(gem, "Size"))
	local stretch = 1 + GemTraits.ClarityDuration * metric(gem, "Clarity")
	d.Output, d.Potency, d.Stretch = output, potency, stretch
	for _, key in POTENCY do
		if type(d[key]) == "number" then
			d[key] *= potency
		end
	end
	for _, key in { "StealCharge", "StealStamina" } do
		if type(d[key]) == "number" then
			d[key] *= output
		end
	end
	d.Burn = scaleTable(d.Burn, potency, { "Power" })
	d.LastBurn = scaleTable(d.LastBurn, potency, { "Power" })
	d.Poison = scaleTable(d.Poison, potency, { "Power" })
	if d.Cloud then
		d.Cloud = scaleTable(d.Cloud, potency, { "Damage" })
		d.Cloud.Duration *= stretch
		d.Duration = d.Cloud.Duration
	end
	if d.Trail then
		d.Trail = table.clone(d.Trail)
		d.Trail.Time *= stretch
		d.Trail.Burn = scaleTable(d.Trail.Burn, potency, { "Power" })
		d.Trail.Poison = scaleTable(d.Trail.Poison, potency, { "Power" })
	end
	d.Ward = scaleTable(d.Ward, potency, { "Power", "Shield" })
	d.Guard = longer(scaleTable(d.Guard, potency, { "Share" }), stretch, { "Time" })
	d.Wall = longer(d.Wall, stretch, { "Time" })
	if d.Wall then
		d.Wall.Burn = scaleTable(d.Wall.Burn, potency, { "Power" })
	end
	d.Heal = scaleTable(d.Heal, potency, { "Share" })
	d.Phoenix = longer(scaleTable(d.Phoenix, potency, { "Heal" }), stretch, { "Time" })
	d.DamageCut = longer(scaleTable(d.DamageCut, potency, { "Amount" }), stretch, { "Time" })
	d.ResistAll = longer(scaleTable(d.ResistAll, potency, { "Amount" }), stretch, { "Time" })
	d.DamageBoost = longer(scaleTable(d.DamageBoost, potency, { "Amount" }), stretch, { "Time" })
	d.Vulnerable = longer(scaleTable(d.Vulnerable, potency, { "Amount" }), stretch, { "Time" })
	d.Mark = longer(scaleTable(d.Mark, potency, { "Arc", "Steal" }), stretch, { "Time" })
	d.Mantle = longer(scaleTable(d.Mantle, potency, { "Share" }), stretch, { "Time" })
	d.CorrosionAura = longer(scaleTable(d.CorrosionAura, potency, { "Stamina", "Shred" }), stretch, { "Time" })
	d.Catch = longer(scaleTable(d.Catch, output, { "Steal" }), stretch, { "Time" })
	d.Deflect = longer(scaleTable(d.Deflect, potency, { "Share" }), stretch, { "Time" })
	d.Grounding = longer(d.Grounding, stretch, { "Time" })
	d.FrostRiposte = longer(d.FrostRiposte, stretch, { "Time" })
	d.Pylon = longer(scaleTable(d.Pylon, potency, { "Damage" }), stretch, { "Time" })
	d.IceField = longer(d.IceField, stretch, { "Time" })
	if d.Crater then
		d.Crater = longer(d.Crater, stretch, { "Time" })
		d.Crater.Burn = scaleTable(d.Crater.Burn, potency, { "Power" })
	end
	if d.Puddle then
		d.Puddle = longer(d.Puddle, stretch, { "Time" })
		d.Puddle.Poison = scaleTable(d.Puddle.Poison, potency, { "Power" })
	end
	d.Hail = longer(d.Hail, stretch, { "Time" })
	d.EndBurst = scaleTable(d.EndBurst, potency, { "Damage" })
	d.Empower = scaleTable(d.Empower, potency, { "Power", "Steal", "Bonus" })
	if d.Empower and d.Empower.Poison then
		d.Empower.Poison = scaleTable(d.Empower.Poison, potency, { "Power" })
	end
	d.ArcExtra = scaleTable(d.ArcExtra, potency, { "Share" })
	if type(d.Siphon) == "number" then
		d.Siphon *= output
	end
	if d.Duration and not d.Cloud then
		d.Duration *= stretch
	end
	if d.Immune then
		d.Immune *= stretch
	end
	if d.Aura then
		d.Aura = scaleTable(d.Aura, output, { "AttackSpeed", "Damage", "SlowLonger", "ChargeGain", "PoisonLonger" })
	end
	d.Cooldown = base.Cooldown * (1 - GemTraits.CutCooldown * metric(gem, "Cut"))
	d.Crit = 0
	d.Echo = 0
	return d
end

-- The words for a move at a gem's numbers, e.g. "120% damage · 26 Charge".
function GemTraits.summary(d): string
	local parts = {}
	if d.Damage then
		local hits = d.Hits
			or (d.Storm and d.Storm.Strikes)
			or (d.Hail and math.floor(d.Hail.Time / d.Hail.Every + 0.5))
			or (d.Disc and 2)
			or 1
		table.insert(
			parts,
			string.format("%d%% damage%s", math.floor(d.Damage * 100 + 0.5), if hits > 1 then " x" .. hits else "")
		)
	end
	if d.Absorb then
		table.insert(parts, string.format("absorb %d", math.floor(d.Absorb + 0.5)))
	end
	if d.Heal then
		table.insert(parts, string.format("heal %d%%", math.floor(d.Heal.Share * 100 + 0.5)))
	end
	table.insert(parts, string.format("%d %s", math.floor(d.Cost + 0.5), d.Resource))
	table.insert(parts, string.format("%gs", math.floor(d.Cooldown * 10 + 0.5) / 10))
	return table.concat(parts, " · ")
end

-- A move's type label: Offense / Strike / Shift / Aura / Defense.
function GemTraits.typeOf(id: string): string
	local move = M[id]
	if not move then
		return ""
	end
	return if move.Lane == "Ability" then (move.Type or "Strike") else move.Lane
end

-- Every trait id, in matrix order (for catalogs and tests).
function GemTraits.all(): { string }
	local list = {}
	for _, element in { "Fire", "Frost", "Shock", "Poison" } do
		for _, lane in { "Offense", "Ability", "Defense" } do
			for _, id in GemTraits.Matrix[element][lane] do
				table.insert(list, id)
			end
		end
	end
	return list
end

-- A starter stone still carrying one of the old intro moves gets its
-- replacement (GemTraits.IntroReplaced) in the same lane. Returns whether
-- anything changed.
function GemTraits.upgradeStarter(gem): boolean
	if type(gem) ~= "table" or gem.CutMethod ~= "Starter" or type(gem.Traits) ~= "table" then
		return false
	end
	local changed = false
	for lane, id in gem.Traits do
		local new = GemTraits.IntroReplaced[id]
		local index = new and GemTraits.Index[new]
		if index and index.Lane == lane and index.Element == gem.Element then
			gem.Traits[lane] = new
			changed = true
		end
	end
	return changed
end

-- Every starter stone in a save (pouch, worn and spare gear, every miner,
-- and a kit not yet claimed): upgradeStarter on each. Returns how many changed.
function GemTraits.upgradeStarterProfile(profile): number
	local changed = 0
	local function stone(gem)
		if GemTraits.upgradeStarter(gem) then
			changed += 1
		end
	end
	local function character(c)
		if type(c) ~= "table" then
			return
		end
		for key, value in c do
			if type(key) == "string" and string.sub(key, -3) == "Gem" and type(value) == "table" then
				stone(value)
			end
		end
		for _, byId in type(c.ItemGems) == "table" and c.ItemGems or {} do
			for _, gem in type(byId) == "table" and byId or {} do
				stone(gem)
			end
		end
	end
	for _, gem in type(profile.Gems) == "table" and profile.Gems or {} do
		stone(gem)
	end
	character(profile.Character)
	local miners = profile.Miners
	for _, miner in type(miners) == "table" and type(miners.Slots) == "table" and miners.Slots or {} do
		character(miner.Character)
	end
	local kit = type(profile.Intro) == "table" and profile.Intro.Lottery
	if type(kit) == "table" then
		for _, entry in type(kit.Gems) == "table" and kit.Gems or {} do
			stone(entry.Gem)
		end
		if type(kit.Moves) == "table" then
			for i, id in kit.Moves do
				kit.Moves[i] = GemTraits.IntroReplaced[id] or id
			end
		end
	end
	return changed
end

-- A gem with a new element keeps each trait's slot in its lane.
-- Each element's showcase defenses by role, so a recut keeps the kind of
-- move (a barrier stays a barrier) though the lanes differ in length.
GemTraits.Showcase = {
	R_FireWall = "Barrier", R_FrozenWall = "Barrier", R_TeslaFence = "Barrier", R_SporeWall = "Barrier",
	R_RingOfFire = "Escape", R_IcePillar = "Escape", R_HoloDecoy = "Escape", R_AcidSlick = "Escape",
}
function GemTraits.reElement(traits, from: string, to: string)
	if type(traits) ~= "table" or not GemTraits.Matrix[from] or not GemTraits.Matrix[to] then
		return nil
	end
	local out = {}
	for lane, id in traits do
		local target = GemTraits.Matrix[to][lane]
		local role = GemTraits.Showcase[id]
		if role and target then
			for _, other in target do
				if GemTraits.Showcase[other] == role then
					out[lane] = other
				end
			end
		end
		if not out[lane] then
			local index = GemTraits.Matrix[from][lane] and table.find(GemTraits.Matrix[from][lane], id)
			-- (a slot past the end of a shorter lane takes its last move)
			out[lane] = if index and target then target[math.min(index, #target)] else nil
		end
	end
	return out
end

return GemTraits
