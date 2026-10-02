-- Grounded mining technology. Costs follow the approved universe conversion;
-- recovery, regeneration and unspecified damage are first-playtest tuning.
local Tech = {}
Tech.Resources = {
	Stamina = { Max = 100, Start = 100, Regen = 12, Color = Color3.fromRGB(65, 195, 112) },
	Charge = { Max = 100, Start = 100, Regen = 7, Color = Color3.fromRGB(70, 130, 255) },
}
Tech.DodgeCost = 15
Tech.ProgressionTerms = {
	Tree = "Augment Tree",
	Points = "Augment Points",
	Branches = { "Rig Maneuvers", "Gem Surges", "Passive Augments" },
}
Tech.Order = {
	RigManeuvers = { "HydraulicSlam", "ServoFlurry", "KineticRam", "StimDodge", "BreachHammer", "ArmorPiercer" },
	GemSurges = { "ThermalBurst", "EnergySiphon", "CryoLance", "CryoStream", "CryoShield", "ResonanceEcho" },
}
Tech.Catalog = {
	HydraulicSlam = {
		Name = "Hydraulic Slam",
		Resource = "Stamina",
		Cost = 30,
		Damage = 1.8,
		Heavy = true,
		Recovery = 1.2,
		Range = 7,
		Icon = "✊",
		Description = "Hydraulic strike; 180% weapon damage and breaks guard.",
	},
	ServoFlurry = {
		Name = "Servo Flurry",
		Resource = "Stamina",
		Cost = 20,
		Damage = 0.7,
		Hits = 2,
		Recovery = 0.9,
		Range = 7,
		Icon = "✊",
		Description = "Two servo-assisted strikes, each dealing 70% weapon damage.",
	},
	KineticRam = {
		Name = "Kinetic Ram",
		Resource = "Stamina",
		Cost = 25,
		Damage = 1.2,
		Stun = 0.5,
		Shield = true,
		Recovery = 1.1,
		Range = 5,
		Icon = "🛡",
		Description = "Shield-mounted kinetic pulse; 120% weapon damage and stagger.",
	},
	StimDodge = {
		Name = "Stim Dodge",
		Resource = "Stamina",
		Cost = 15,
		Heal = 0.1,
		Recovery = 3,
		Icon = "🥾",
		Description = "Dodge with a medical injector restoring 10% maximum Health.",
	},
	BreachHammer = {
		Name = "Breach Hammer",
		Resource = "Stamina",
		Cost = 40,
		Damage = 2.5,
		Windup = 1,
		Recovery = 2,
		Range = 7,
		Icon = "🔨",
		Description = "One-second hydraulic wind-up, followed by a 250% overhead strike.",
	},
	ArmorPiercer = {
		Name = "Armor Piercer",
		Resource = "Stamina",
		Cost = 35,
		Damage = 1,
		Pierce = true,
		Recovery = 1.2,
		Range = 7,
		Icon = "🔨",
		Description = "Directed energy pulse bypasses guard.",
	},
	ThermalBurst = {
		Name = "Thermal Burst",
		Resource = "Charge",
		Cost = 25,
		Element = "Fire",
		Damage = 1,
		Radius = 8,
		Range = 35,
		Recovery = 1.2,
		Icon = "🔥",
		Description = "Socket-powered plasma detonation at the aimed surface.",
	},
	EnergySiphon = {
		Name = "Energy Siphon",
		Resource = "Charge",
		Cost = 20,
		Duration = 4,
		Recovery = 1,
		Icon = "⚡",
		Description = "Absorption field converts intercepted damage into stored Charge.",
	},
	CryoLance = {
		Name = "Cryo Lance",
		Resource = "Charge",
		Cost = 25,
		Element = "Frost",
		Damage = 1,
		Stun = 0.5,
		Range = 45,
		Recovery = 1.2,
		Icon = "❄",
		Description = "Cryogenic accelerator launches a shard and briefly stuns.",
	},
	CryoStream = {
		Name = "Cryo Stream",
		Resource = "Charge",
		Cost = 15,
		PerSecond = true,
		Element = "Frost",
		Damage = 0.45,
		Slow = 0.25,
		Range = 24,
		Recovery = 0.25,
		Icon = "❄",
		Description = "Hold to channel a cryogenic beam; costs 15 Charge per second.",
	},
	CryoShield = {
		Name = "Cryo Shield",
		Resource = "Charge",
		Cost = 30,
		Element = "Frost",
		Duration = 5,
		Recovery = 1,
		Icon = "❄",
		Description = "Cryogenic barrier absorbs damage for five seconds.",
	},
	ResonanceEcho = {
		Name = "Resonance Echo",
		Resource = "Charge",
		Cost = 40,
		Duration = 5,
		Recovery = 1,
		Icon = "⚡",
		Description = "Stored gemstone resonance duplicates weapon strikes for five seconds.",
	},
}
Tech.PassiveAugments = {
	{ Name = "Blade Calibration", Description = "Slashing weapon damage." },
	{ Name = "Cleaver Calibration", Description = "Cleaving weapon damage." },
	{ Name = "Mobility Augment", Description = "Movement speed." },
	{ Name = "Stamina Recycler", Description = "Stamina regeneration." },
	{ Name = "Charge Recycler", Description = "Charge regeneration." },
	{ Name = "Thermal Overcharge", Description = "Thermal damage." },
}
Tech.Consumables = {
	StimShot = { Name = "Stim Shot", Resource = "Health" },
	ChargeCell = { Name = "Charge Cell", Resource = "Charge" },
	EnergyDrink = { Name = "Energy Drink", Resource = "Stamina" },
}
function Tech.hasGem(loadout, element)
	for _, slot in { "Weapon", "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
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
