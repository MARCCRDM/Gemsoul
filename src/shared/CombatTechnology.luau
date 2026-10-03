-- Grounded mining technology. Costs follow the approved universe conversion;
-- recovery, regeneration and unspecified damage are first-playtest tuning.
local GemRoller = require(script.Parent.GemRoller)
local Tech = {}
Tech.Resources = {
	Stamina = { Max = 100, Start = 100, Regen = 12, Color = Color3.fromRGB(65, 195, 112) },
	Charge = { Max = 100, Start = 100, Regen = 7, Color = Color3.fromRGB(70, 130, 255) },
}
Tech.DodgeCost = 15
Tech.ProgressionTerms = {
	Tree = "Augment Tree",
	Points = "Augment Points",
	Branches = { "Rig Maneuvers", "Surge Amplifiers", "Passive Augments" },
}
Tech.Order = {
	RigManeuvers = {
		"HydraulicSlam",
		"ServoFlurry",
		"KineticRam",
		"StimDodge",
		"BreachHammer",
		"ArmorPiercer",
		"SeismicBreaker",
		"TremorSlam",
		"PneumaticJab",
		"ThrusterLeap",
		"RiposteStance",
	},
	-- Gem Surges come from gems, not the tree: Tech.Surges[element][tier].
	GemSurges = {
		"ThermalBurst",
		"EmberLance",
		"SolarFlare",
		"Supernova",
		"CryoLance",
		"CryoStream",
		"CryoShield",
		"AbsoluteZero",
		"AcidSpray",
		"ArmorMelt",
		"ToxicCloud",
		"BioCorrosion",
		"IonSpark",
		"StaticField",
		"ChainLightning",
		"Overload",
		"EnergySiphon",
		"ResonanceEcho",
	},
}
-- The 16 elemental gem surges by element and surge tier (1-4), and the two
-- Resonance surges (tiers 2 and 3) any gem may carry. See GemRoller.
Tech.Surges = GemRoller.Surges
Tech.Resonance = GemRoller.Resonance
Tech.TierNames = GemRoller.TierNames
Tech.SurgeSlots = 3 -- Q, E, R
-- The Surge Array keys and the saved capacitor sockets they cast from
-- (Character.Surge1Gem, Surge2Gem, Surge3Gem).
Tech.SurgeSockets = { Q = "Surge1", E = "Surge2", R = "Surge3" }
function Tech.surgeGem(loadout, key: string)
	local slot = Tech.SurgeSockets[key]
	return if slot and loadout then loadout[slot .. "Gem"] else nil
end
Tech.ManeuverSlots = 3 -- 1, 2, 3
Tech.DefaultManeuvers = { "HydraulicSlam", "KineticRam", "StimDodge" }
--[[ Every ability's timing:
  Recovery  the short lockout after using it: no other ability or swing
            until it passes (a global cooldown)
  Cooldown  how long until this one ability is ready again
  Surges climb by tier: about 4s (Novice), 8s (Apprentice), 12s (Adept)
  and 20s (Master), each tier hitting harder per cast.
  Further fields (surges and maneuvers alike):
  Blind     a share of the target's attacks miss, for BlindTime seconds
  Ward      after the cast, a barrier { Kind = "Burn" | "Stun", Shield,
            Duration, Power (burn per second, x weapon damage) or Stun
            (seconds) } that punishes anyone who hits you, once a second
  Leech     you heal this share of the damage it deals
  Interrupt cancels a surge the target is casting or pouring and locks
            its surges for this many seconds (Pneumatic Jab)
  Leap      leaps up to this many studs at the aimed spot; the blow lands
            on touchdown (Thruster Leap)
  Riposte   braced this many seconds: the next blow is turned aside and
            answered for CounterDamage x weapon damage (Riposte Stance) ]]
Tech.Catalog = {
	HydraulicSlam = {
		Name = "Hydraulic Slam",
		Resource = "Stamina",
		Cost = 15,
		Damage = 2,
		Heavy = true,
		Cooldown = 6,
		Recovery = 0.45,
		Range = 7,
		Icon = "✊",
		Description = "Hydraulic strike; 200% weapon damage and breaks guard.",
	},
	ServoFlurry = {
		Name = "Servo Flurry",
		Resource = "Stamina",
		Cost = 12,
		Damage = 0.9,
		Hits = 2,
		Cooldown = 5,
		Recovery = 0.45,
		Range = 7,
		Icon = "🤜",
		Description = "Two servo-assisted strikes, each dealing 90% weapon damage.",
	},
	KineticRam = {
		Name = "Kinetic Ram",
		Resource = "Stamina",
		Cost = 14,
		Damage = 1.65,
		Stun = 0.5,
		Shield = true,
		Cooldown = 8,
		Recovery = 0.45,
		Range = 5,
		Icon = "🛡",
		Description = "Shield-mounted kinetic pulse; 165% weapon damage and stagger.",
	},
	StimDodge = {
		Name = "Stim Dodge",
		Resource = "Stamina",
		Cost = 15, -- (the dodge's own cost)
		Heal = 0.08,
		Cooldown = 12,
		Recovery = 0.4,
		Icon = "💉",
		Description = "Dodge with a medical injector restoring 8% maximum Health.",
	},
	BreachHammer = {
		Name = "Breach Hammer",
		Resource = "Stamina",
		Cost = 22,
		Damage = 3.5,
		Windup = 1,
		Heavy = true,
		Cooldown = 10,
		Recovery = 1,
		Range = 7,
		Icon = "🔨",
		Description = "One-second hydraulic wind-up, then a 350% overhead strike that breaks guard.",
	},
	ArmorPiercer = {
		Name = "Armor Piercer",
		Resource = "Stamina",
		Cost = 15,
		Damage = 1.6,
		Pierce = true,
		Shred = 0.25,
		ShredTime = 4,
		Cooldown = 8,
		Recovery = 0.45,
		Range = 7,
		Icon = "🗡",
		Description = "Directed energy pulse: 160% damage that bypasses guard and shreds 25% armor for 4s.",
	},
	-- Counters: answer a cast, close the gap, turn a blow aside.
	PneumaticJab = {
		Name = "Pneumatic Jab",
		Resource = "Stamina",
		Cost = 8,
		Damage = 0.6,
		Interrupt = 2, -- cancels a surge being cast or poured; surges locked this long
		Range = 7,
		Cooldown = 10,
		Recovery = 0.4,
		Icon = "👊",
		Description = "A lightning jab: 60% damage, and it cancels a surge being cast and locks the caster's surges for 2s.",
	},
	ThrusterLeap = {
		Name = "Thruster Leap",
		Resource = "Stamina",
		Cost = 14,
		Damage = 2.5,
		Leap = 18, -- studs, at the aimed spot
		Windup = 0.4, -- in the air
		Range = 7,
		Cooldown = 12,
		Recovery = 0.45,
		Icon = "🚀",
		Description = "A thruster leap of up to 18 studs at your target, slamming down for 250% damage.",
	},
	RiposteStance = {
		Name = "Riposte Stance",
		Resource = "Stamina",
		Cost = 10,
		Riposte = 1, -- seconds braced
		CounterDamage = 1,
		Cooldown = 14,
		Recovery = 0.5,
		Icon = "🤺",
		Description = "Brace for 1s: the next blow is turned aside, its attacker staggered for 1s and struck back for 100%.",
	},
	ThermalBurst = {
		Name = "Thermal Burst",
		Resource = "Charge",
		Cost = 20,
		Element = "Fire",
		Damage = 0.9,
		Radius = 8,
		Range = 35,
		Cooldown = 4,
		Recovery = 0.6,
		Icon = "🔥",
		Description = "Socket-powered plasma detonation at the aimed surface.",
	},
	EmberLance = {
		Name = "Ember Lance",
		Resource = "Charge",
		Cost = 25,
		Element = "Fire",
		Damage = 1.35,
		Range = 45,
		Cooldown = 7,
		Recovery = 0.8,
		Icon = "🔥",
		Description = "A superheated plasma bolt that sets its target burning.",
	},
	SolarFlare = {
		Name = "Solar Flare",
		Resource = "Charge",
		Cost = 35,
		Element = "Fire",
		Damage = 1.55,
		Radius = 12,
		Range = 35,
		Windup = 0.6,
		Blind = 0.35,
		BlindTime = 2.5,
		Cooldown = 12,
		Recovery = 1,
		Icon = "☀",
		Description = "A searing flash at the aimed spot: 155% damage and Blinds (35% of attacks miss) for 2.5s.",
	},
	Supernova = {
		Name = "Supernova",
		Resource = "Charge",
		Cost = 55,
		Element = "Fire",
		Damage = 1.8,
		Radius = 14,
		Range = 30,
		Windup = 1.2,
		Ward = { Kind = "Burn", Shield = 15, Duration = 6, Power = 0.1 },
		Cooldown = 20,
		Recovery = 1.2,
		Icon = "💥",
		Description = "A colossal plasma blast, then a Burning Ward: a barrier that burns anyone who hits you.",
	},
	-- Resonance surges: no element; any gem can carry one (GemRoller.Resonance).
	EnergySiphon = {
		Name = "Energy Siphon",
		Resource = "Charge",
		Cost = 20,
		Duration = 4,
		Absorb = 35,
		Cooldown = 10,
		Recovery = 1,
		Icon = "🔋",
		Description = "An absorption field soaks up 35 incoming damage for four seconds and turns it into Charge.",
	},
	ResonanceEcho = {
		Name = "Resonance Echo",
		Resource = "Charge",
		Cost = 40,
		Duration = 2,
		Cooldown = 16,
		Recovery = 1,
		Icon = "〰",
		Description = "Stored gem resonance makes every weapon strike hit twice for two seconds.",
	},
	CryoLance = {
		Name = "Cryo Lance",
		Resource = "Charge",
		Cost = 20,
		Element = "Frost",
		Damage = 1.05,
		Stun = 0.5,
		Range = 45,
		Cooldown = 5,
		Recovery = 0.6,
		Icon = "❄",
		Description = "A cryogenic lance that freezes its target in place for half a second.",
	},
	CryoStream = {
		Name = "Cryo Stream",
		Resource = "Charge",
		Cost = 18,
		PerSecond = true,
		Element = "Frost",
		Damage = 1.65,
		Slow = 0.3,
		Range = 24,
		Cooldown = 8,
		Recovery = 0.25,
		Icon = "❄",
		Description = "Hold to channel a slowing cryogenic beam; costs 18 Charge per second.",
	},
	CryoShield = {
		Name = "Cryo Shield",
		Resource = "Charge",
		Cost = 30,
		Element = "Frost",
		Duration = 4,
		Cooldown = 14,
		Recovery = 0.6,
		Icon = "❄",
		Description = "Cryogenic barrier absorbs damage for four seconds.",
	},
	--[[ Gem Surge fields beyond the basics:
	  Cone      degrees: hits everyone in a cone in front, out to Range
	  Self      the Radius burst centres on you instead of the aimed spot
	  Shred     armor shred (fraction of Defense) for ShredTime seconds
	  Chain     bounces to this many more enemies within ChainRange
	  Execute   finishes a target left below this share of its health
	  Spread    shred and half the hit jump to everyone within this radius
	  Cloud     a lingering pool: { Duration, Every, Damage, Shred }
	  Piercing  the bolt hits everyone along its line, not just the first
	  SlowTime  how long Slow lasts (default 0.75s) ]]
	SeismicBreaker = {
		Name = "Seismic Breaker",
		Resource = "Stamina",
		Cost = 26,
		Damage = 3.8,
		Heavy = true,
		Windup = 1.2,
		Stun = 0.6,
		Cooldown = 16,
		Recovery = 1.2,
		Range = 8,
		Icon = "⛏",
		Description = "Long wind-up, then a 380% ground-breaker that smashes guard and staggers.",
	},
	TremorSlam = {
		Name = "Tremor Slam",
		Resource = "Stamina",
		Cost = 20,
		Damage = 2.3,
		Stun = 1,
		Cooldown = 14,
		Recovery = 0.6,
		Range = 8,
		Icon = "⚒",
		Description = "Ground slam: 230% damage and a 1s stun.",
	},
	AcidSpray = {
		Name = "Acid Spray",
		Resource = "Charge",
		Cost = 20,
		Element = "Poison",
		Damage = 1,
		Cone = 70,
		Range = 12,
		Shred = 0.15,
		ShredTime = 5,
		Cooldown = 5,
		Recovery = 0.6,
		Icon = "🧪",
		Description = "A cone of corrosive spray that eats 15% of armor for five seconds.",
	},
	ArmorMelt = {
		Name = "Armor Melt",
		Resource = "Charge",
		Cost = 25,
		Element = "Poison",
		Damage = 1.1,
		Range = 40,
		Shred = 0.30,
		ShredTime = 5,
		Slow = 0.3,
		SlowTime = 2,
		Cooldown = 9,
		Recovery = 0.8,
		Icon = "☣",
		Description = "Corrosive bolt: shreds 30% armor and slows the target 30% for 2s.",
	},
	ToxicCloud = {
		Name = "Toxic Cloud",
		Resource = "Charge",
		Cost = 35,
		Element = "Poison",
		Damage = 0.4,
		Radius = 9,
		Range = 30,
		Shred = 0.10,
		ShredTime = 2,
		Cloud = { Duration = 5, Every = 1, Damage = 0.35, Shred = 0.10 },
		Duration = 5,
		Leech = 0.5,
		Cooldown = 14,
		Recovery = 1,
		Icon = "☁",
		Description = "A lingering toxic pool; you drain half of the damage it deals as Health.",
	},
	BioCorrosion = {
		Name = "Bio-Corrosion",
		Resource = "Charge",
		Cost = 45,
		Element = "Poison",
		Damage = 3.8,
		Range = 40,
		Shred = 0.20,
		ShredTime = 6,
		Spread = 10,
		Cooldown = 20,
		Recovery = 1.2,
		Icon = "☣",
		Description = "Infect one target; its corrosion and half the hit spread to every enemy within 10 studs.",
	},
	IonSpark = {
		Name = "Ion Spark",
		Resource = "Charge",
		Cost = 20,
		Element = "Shock",
		Damage = 1.05,
		Range = 40,
		Chain = 1,
		ChainRange = 12,
		Cooldown = 4,
		Recovery = 0.5,
		Icon = "⚡",
		Description = "A quick ion bolt that arcs to one more enemy.",
	},
	StaticField = {
		Name = "Static Field",
		Resource = "Charge",
		Cost = 30,
		Element = "Shock",
		Damage = 0.5,
		Radius = 8,
		Self = true,
		Range = 0,
		Stun = 0.5,
		Ward = { Kind = "Stun", Shield = 15, Duration = 5, Stun = 0.4 },
		Cooldown = 10,
		Recovery = 0.6,
		Icon = "🌀",
		Description = "A static burst around you, then a Static Shell: a barrier that shocks anyone who hits you.",
	},
	ChainLightning = {
		Name = "Chain Lightning",
		Resource = "Charge",
		Cost = 35,
		Element = "Shock",
		Damage = 4,
		Range = 40,
		Chain = 3,
		ChainRange = 14,
		Cooldown = 12,
		Recovery = 1,
		Icon = "⚡",
		Description = "A bolt that bounces to up to three more enemies.",
	},
	Overload = {
		Name = "Overload",
		Resource = "Charge",
		Cost = 45,
		Element = "Shock",
		Damage = 2.4,
		Range = 40,
		Execute = 0.20,
		Cooldown = 20,
		Recovery = 1.2,
		Icon = "💥",
		Description = "A 240% ion blast that instantly finishes a target left below 20% health.",
	},
	AbsoluteZero = {
		Name = "Absolute Zero",
		Resource = "Charge",
		Cost = 50,
		Element = "Frost",
		Damage = 3.8,
		Radius = 10,
		Range = 30,
		Stun = 1.5,
		Slow = 0.4,
		Cooldown = 20,
		Recovery = 1.2,
		Icon = "🧊",
		Description = "Flash-freeze the aimed area: everything in it is frozen solid, then slowed.",
	},
}
Tech.PassiveAugments = {
	{ Name = "Blade Calibration", Description = "Slashing weapon damage." },
	{ Name = "Cleaver Calibration", Description = "Cleaving weapon damage." },
	{ Name = "Mobility Augment", Description = "Movement speed." },
	{ Name = "Stamina Recycler", Description = "Stamina regeneration." },
	{ Name = "Charge Recycler", Description = "Charge regeneration." },
	{ Name = "Thermal Overcharge", Description = "Thermal damage." },
	{ Name = "Corrosive Overcharge", Description = "Corrosive damage." },
	{ Name = "Ion Overcharge", Description = "Ion damage." },
	{ Name = "Cryo Overcharge", Description = "Cryo damage." },
	{ Name = "Elemental Harmony", Description = "Damage after switching elements." },
}
-- The surge a gem casts: its id, surge tier and rank. Rolled gems save the id;
-- older gems take their element's surge at their tier.
function Tech.surgeOf(gem): (string?, number, number)
	local tier, rank = GemRoller.surge(gem)
	local saved = gem.Surge and Tech.Catalog[gem.Surge]
	if saved and saved.Resource == "Charge" then
		return gem.Surge, tier, rank
	end
	local list = Tech.Surges[gem.Element]
	return list and list[tier], tier, rank
end

--[[
	A gem's surge, with its numbers for this gem (a copy; the catalog is untouched):
	  Rank     I x1 · II x1.25 damage, -10% recovery, -8% cost · III x1.5, -20%, -16%
	  Size     damage +3% per grade (applied per hit, with the Overcharge perk)
	  Clarity  pools, fields and barriers +0.5s per grade; stuns, slows and
	           shred +4% longer per grade; recovery -2% and reach +2% per grade
	  Cut      critical chance +0.5% per grade; shred and execute threshold
	           +0.5 points per grade
	amps: Surge Amplifier effects from the Augment Tree (Tree.effects).
]]
Tech.Ranks = {
	{ Damage = 1, Recovery = 1, Cost = 1 },
	{ Damage = 1.25, Recovery = 0.9, Cost = 0.92 },
	{ Damage = 1.5, Recovery = 0.8, Cost = 0.84 },
}
function Tech.surgeStats(gem, amps)
	local id, tier, rank = Tech.surgeOf(gem)
	local base = id and Tech.Catalog[id]
	if not base then
		return nil
	end
	amps = amps or {}
	local d = table.clone(base)
	local scale = Tech.Ranks[rank] or Tech.Ranks[1]
	local clarity = math.clamp(gem.Clarity or 1, 1, 10)
	local cut = math.clamp(gem.Cut or 0, 0, 10)
	if d.Damage then
		d.Damage *= scale.Damage * (1 + (amps.SurgePower or 0) + (amps.ElementalMastery or 0))
	end
	d.Cost *= scale.Cost
	local longer = 1 + (amps.SurgeDuration or 0)
	if d.Duration then
		d.Duration = (d.Duration + clarity * 0.5) * longer
	end
	if d.Cloud then
		d.Cloud = table.clone(d.Cloud)
		d.Cloud.Duration = (d.Cloud.Duration + clarity * 0.5) * longer
		if d.Cloud.Shred then
			d.Cloud.Shred += cut * 0.005
		end
	end
	for _, key in { "Stun", "SlowTime", "ShredTime", "BlindTime" } do
		if d[key] then
			d[key] *= (1 + clarity * 0.04) * longer
		end
	end
	for _, key in { "Radius", "Range" } do
		if d[key] then
			d[key] *= 1 + clarity * 0.02
		end
	end
	if d.Shred then
		d.Shred += cut * 0.005
	end
	if d.Execute then
		d.Execute += cut * 0.005
	end
	local quicker = scale.Recovery * (1 - clarity * 0.02) * (1 - math.clamp(amps.SurgeEfficiency or 0, 0, 0.6))
	d.Recovery *= quicker
	d.Cooldown = (d.Cooldown or d.Recovery) * quicker
	d.Crit = cut * 0.005
	d.Echo = amps.ArcaneResonance or 0
	d.Id, d.Tier, d.Rank, d.Gem = id, tier, rank, gem
	return d
end

-- A gem's tooltip lines for its surge (the directive's gem tooltip).
function Tech.surgeLines(gem, amps): { string }
	local d = Tech.surgeStats(gem, amps)
	if not d then
		return {}
	end
	local size = math.clamp(gem.Size or 1, 1, 10)
	local lines = {
		string.format(
			"Surge: %s (%s · Rank %s)",
			d.Name,
			Tech.TierNames[d.Tier] or "",
			({ "I", "II", "III" })[d.Rank]
		),
	}
	if d.Damage then
		table.insert(lines, string.format("%d%% base damage", math.floor(d.Damage * 100 + 0.5)))
		table.insert(lines, string.format("Size %d (+%d%% damage)", size, size * 3))
	else
		table.insert(lines, string.format("%gs effect", math.floor(d.Duration * 10 + 0.5) / 10))
	end
	table.insert(lines, string.format("Clarity %d (%.1fs recovery)", gem.Clarity or 0, d.Recovery))
	table.insert(lines, string.format("Cut %d (%g%% crit chance)", gem.Cut or 0, d.Crit * 100))
	table.insert(lines, "Sockets into any Surge Slot.")
	return lines
end

-- Is a gem (of `element`, or any) socketed in gear or the Surge Array?
function Tech.hasGem(loadout, element)
	for _, slot in { "Surge1", "Surge2", "Surge3", "Weapon", "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		local gem = loadout[slot .. "Gem"]
		if gem and (not element or gem.Element == element) then
			return true
		end
	end
	return false
end
function Tech.spend(resources, resource, cost)
	local available = resources[resource] or 0
	if cost < 0 or available < cost then
		return false
	end
	resources[resource] = available - cost
	return true
end
return Tech
