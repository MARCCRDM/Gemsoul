-- Expanded equipment identities from the supplied traits matrix.
-- Proposed effects remain metadata until their gameplay systems exist.
local EquipmentBalance = require(script.Parent.EquipmentBalance)
local Traits = {}
Traits.Catalog = {}
Traits.Visors = {}
Traits.Weights = { 40, 25, 20, 10, 5 }

Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets1",
	Name = "Zero-G Standard Helm",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Kinetic Resistance +5% Physical Defense",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets2",
	Name = "Platon Tactical Helm",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Shield Capacity +10 Max Energy Shield",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets3",
	Name = "Asterois Closed Helm",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Elemental Resist +8% Cryo Resistance",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets4",
	Name = "Intableed Visored Helm",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Critical Strike +4% Critical Hit Chance",
	BuffReady = true,
	Passive = { Name = "Signature", Text = "+4% critical hit chance.", Effect = { CritAdd = 0.04 } },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets5",
	Name = "Jutaim Command Helm",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Saga Resonance +15% Saga Stone Yield",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets6",
	Name = "Qutany Fpv Helm",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Sensor Array +5% Detection Range",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets7",
	Name = "Watten Speed Helm",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Agility Boost +6% Movement Acceleration",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets8",
	Name = "Photon Shield Helm",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Energy Barrier +12 Shield Rejuvenation",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets9",
	Name = "Photrin Perfect Helm",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Precision Lock +10% Weakpoint Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets10",
	Name = "Metron Meshed Helm",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Neural Sync +15% Cooldown Reduction",
	BuffReady = true,
	Passive = { Name = "Signature", Text = "Abilities recharge 15% faster.", Effect = { CooldownMult = 0.85 } },
})
table.insert(
	Traits.Visors,
	{ Id = "MatrixVisor1", Name = "Standard Amber", Rarity = 1, ProposedBuff = "Accuracy +2% Ranged Accuracy" }
)
table.insert(
	Traits.Visors,
	{ Id = "MatrixVisor2", Name = "Glacial Cyan (Cryo)", Rarity = 2, ProposedBuff = "Cryo Potency +5% Freeze Buildup" }
)
table.insert(
	Traits.Visors,
	{ Id = "MatrixVisor3", Name = "Electric Amber (Volt)", Rarity = 3, ProposedBuff = "Volt Potency +5% Stun Duration" }
)
table.insert(Traits.Visors, {
	Id = "MatrixVisor4",
	Name = "Corrosive Emerald (Radiation)",
	Rarity = 4,
	ProposedBuff = "Radiation Potency +8% DoT Tick Rate",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor5",
	Name = "Void Violet (Plasma)",
	Rarity = 5,
	ProposedBuff = "Thermal Potency +12% Plasma Burn Damage",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor6",
	Name = "Crimson Infrared",
	Rarity = 1,
	ProposedBuff = "Threat Detection +6% Vision Through Smoke",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor7",
	Name = "Cobalt Deep-Space",
	Rarity = 2,
	ProposedBuff = "Vacuum Seal Immunity to Asphyxiation Hazards",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor8",
	Name = "Solar Gold",
	Rarity = 3,
	ProposedBuff = "Energy Reflection Reflects 3% Projectile Damage",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor9",
	Name = "Matrix Green",
	Rarity = 4,
	ProposedBuff = "Data Scans Reveals Enemy Weak Points Automatically",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor10",
	Name = "Prismatic Opaque",
	Rarity = 5,
	ProposedBuff = "Refraction Shield Negates 1st Hit Every 30s",
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors1",
	Name = "Zero-G Bulk Suit",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Armor Plating +20 Flat Armor",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors2",
	Name = "Platon Armor Rig",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Stamina Regeneration +10% Stamina Regen",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors3",
	Name = "Asterois Exosuit",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Mobility +5% Movement Speed",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors4",
	Name = "Intableed Combat Rig",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Lifesteal / Bio +3% Damage Converted to Health",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors5",
	Name = "Jutaim Heavy Vanguard",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Damage Reduction +15% Overall Damage Reduction",
	BuffReady = true,
	Passive = { Name = "Signature", Text = "Take 15% less damage.", Effect = { TakenMult = 0.85 } },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors6",
	Name = "Qutany Fpv Suit",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Power Conduit +10 Max Power Pool",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors7",
	Name = "Watten Speed Suit",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Velocity Matrix +8% Dash Speed",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors8",
	Name = "Photon Shield Suit",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Barrier Generator +25 Max Energy Shield",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors9",
	Name = "Photrin Reflective Suit",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Energy Deflection +10% Elemental Resistance",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors10",
	Name = "Metron Meshed Suit",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Nanite Repair Regenerates 1% HP per second",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves1",
	Name = "Reinforced Grips",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Melee Impact +5% Shield Bash Stagger",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves2",
	Name = "Capacitor Liners",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Volt Synergy +6% Electrical Arc Chance",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves3",
	Name = "Cryo-Cooler Gauntlets",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Chill Infusion +8% Slow Application",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves4",
	Name = "Thermal Conduit Gloves",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Plasma Overcharge +10% Critical Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves5",
	Name = "Saga-Tuned Handwraps",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Attack Speed +12% Weapon Cycle Speed",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves6",
	Name = "Hydraulic Crushers",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Stagger Force +15% Heavy Melee Knockback",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves7",
	Name = "Nanite Weave Gloves",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Self-Cleaning Immunity to Corrosive Sludge",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves8",
	Name = "Kinetic Shock Mitts",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Impact Absorption Reduces Melee Damage Taken by 10%",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves9",
	Name = "Void-weave Bracers",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Phase Strike Melee Attacks Ignore 20% Armor",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves10",
	Name = "Overclocked Servos",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Burst Action +20% Attack Speed for 5s on Kill",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots1",
	Name = "Mag-Lock Greaves",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Knockback Resist +10% Stability against Shoves",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots2",
	Name = "Hydraulic Striders",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Sprint Efficiency -10% Stamina Drain on Sprint",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots3",
	Name = "Phase-Dodge Treads",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Evade Distance +15% Dodge Roll I-Frames",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots4",
	Name = "Reactor-Core Boots",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Energy Recharge +8% Shield Recharge Rate",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots5",
	Name = "Void-Strider Sabatons",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Traversal Speed +20% Movement Speed in Combat",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots6",
	Name = "Gravity-Stabilized Treads",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Fall Mitigation -25% Fall Damage Taken",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots7",
	Name = "Aero-Stream Greaves",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Slipstream +10% Movement Speed after Sprinting 3s",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots8",
	Name = "Crystalline Striders",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Saga Resonance +5% Extra Saga Stones on Pickup",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots9",
	Name = "Thermal-Insulated Boots",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Thermal Shielding Immunity to Lava and Fire Hazards",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots10",
	Name = "Quantum-Step Sabatons",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Teleport Dodge Dodge Roll Leaves a Decoy Explosion",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons1",
	Name = "Standard Sidearm",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Base Kinetic 100% Base Weapon Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons2",
	Name = "Cryo-Pistol Sub-Zero",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SurveyorKit",
	Mods = {},
	ProposedBuff = "Cryo Application Applies Slow on Hit",
	BuffReady = true,
	Passive = {
		Name = "Signature",
		Text = "Hits slow targets by 15% for 2 seconds.",
		Effect = { SlowOnHit = 0.15 },
	},
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons3",
	Name = "Volt-Spark Blaster",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SurveyorKit",
	Mods = {},
	ProposedBuff = "Volt Stun Chain Lightning on Crit",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons4",
	Name = "Radiation Corrupter",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Armor Shred Reduces Target Armor by 15%",
	BuffReady = true,
	Passive = {
		Name = "Signature",
		Text = "Hits apply +15% damage vulnerability for 5 seconds, stacking to +45%.",
		Effect = { Sunder = 0.15 },
	},
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons5",
	Name = "Plasma Melter",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "BulwarkKit",
	Mods = {},
	ProposedBuff = "Thermal Burn Applies Stackable Burn Over Time",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons6",
	Name = "Pulse-Laser Repeater",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Rapid Fire +25% Fire Rate, -10% Base Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons7",
	Name = "Heavy Mag-Driver",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "BulwarkKit",
	Mods = {},
	ProposedBuff = "Impact Slug Staggers Light Targets on Hit",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons8",
	Name = "Void-Caster Handgun",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Spatial Distortion Pulls Targets Toward Impact Point",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons9",
	Name = "Saga-Infused Repeater",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SurveyorKit",
	Mods = {},
	ProposedBuff = "Energy Surge Generates Shield on Kills with Pistol",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons10",
	Name = "Omega-Protocol Handcannon",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Annihilation Round Fires Explosive Rounds every 5th Shot",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields1",
	Name = "Titanium Breach Shield",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Block Stability +50 Shield Block Health",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields2",
	Name = "Cryo-Barrier Aegis",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Chill Deflection Chills Attackers on Block",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields3",
	Name = "Volt-Field Bulwark",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Shock Retaliation Shocks Melee Attackers",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields4",
	Name = "Radiation-Vented Wall",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Corrosive Aura Deals Radiation AoE when Raised",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields5",
	Name = "Saga-Reactor Aegis",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Energy Reflection Reflects 10% Ranged Damage Back",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields6",
	Name = "Composite Riot Gate",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Coverage Area +15% Shield Width",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields7",
	Name = "Kinetic Deflector Wall",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Projectile Redirect Deflects Minor Projectiles Automatically",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields8",
	Name = "Plasma-Edge Bulwark",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Thermal Counter Melee Attackers Take Plasma Burn",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields9",
	Name = "Phase-Shield Barrier",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Ethereal Guard Allows Ranged Shots Through Shield at 50% Penalty",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields10",
	Name = "World-Breaker Aegis",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Bulwark Slam Shield Bash Creates a Shockwave Stun",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})

-- Swords supplement the original pistol catalog with distinct persistent IDs.
local swordNames = {
	"Frontier Sword",
	"Cryo-Edge Saber",
	"Volt-Spark Blade",
	"Radium Cleaver",
	"Solarbrand",
	"Scout Shortsword",
	"Impact Falchion",
	"Void-Edge Sword",
	"Saga Runeblade",
	"Omega Greatblade",
}
local pistols = table.clone(Traits.Catalog.Weapons)
for index, pistol in pistols do
	pistol.WeaponType = "Pistol"
	if index == 1 then
		pistol.BuffReady = true
		pistol.Passive = { Name = "Base Kinetic", Text = "Standard kinetic sidearm damage.", Effect = {} }
	elseif index == 6 then
		pistol.BuffReady = true
		pistol.Attack.Rate = 0.36
		pistol.Attack.Damage = 9.9
		pistol.Passive = { Name = "Rapid Fire", Text = "+25% fire rate; -10% base damage.", Effect = {} }
	end
	local weapon = table.clone(pistol)
	weapon.Id = "MatrixSwords" .. index
	weapon.Passive = table.clone(pistol.Passive)
	weapon.Name = swordNames[index]
	weapon.Look = "FrontierSword"
	weapon.WeaponType = "Sword"
	weapon.Attack = { Kind = "Melee", Damage = 18, Rate = 0.65, Range = 7, Arc = 90, Combo = 3 }
	weapon.ProposedBuff = "Three-strike sword combo. Socket a gem to attune its attacks."
	if index == 1 then
		weapon.Passive = { Name = "Tempered Edge", Text = "Three-strike melee combo.", Effect = {} }
	end
	if not weapon.BuffReady then
		weapon.Passive = { Name = "Tempered Edge", Text = "Three-strike melee combo.", Effect = {} }
		weapon.BuffReady = true
	end
	if index == 6 then
		weapon.Attack = { Kind = "Melee", Damage = 15, Rate = 0.52, Range = 6, Arc = 80, Combo = 3 }
		weapon.Passive = { Name = "Quick Edge", Text = "Faster swings with less damage and reach.", Effect = {} }
	elseif index == 7 or index == 10 then
		weapon.Attack = { Kind = "Melee", Damage = 23, Rate = 0.85, Range = 7.5, Arc = 100, Combo = 3 }
	end
	table.insert(Traits.Catalog.Weapons, weapon)
end

local visorColors = {
	Color3.fromRGB(255, 178, 62),
	Color3.fromRGB(87, 220, 255),
	Color3.fromRGB(255, 199, 63),
	Color3.fromRGB(82, 230, 139),
	Color3.fromRGB(168, 99, 246),
	Color3.fromRGB(243, 77, 93),
	Color3.fromRGB(78, 124, 234),
	Color3.fromRGB(255, 216, 103),
	Color3.fromRGB(103, 248, 154),
	Color3.fromRGB(225, 228, 255),
}
for index, visor in Traits.Visors do
	visor.Index = index
	visor.Color = visorColors[index]
	visor.StartPool = true
	visor.RarityTier = visor.Rarity
end

-- Render the equipment matrix through three restrained, interchangeable asset families.
for kind, entries in Traits.Catalog do
	if kind ~= "Weapons" then
		for _, item in entries do
			item.AssetFamily = if item.RarityTier == 1
				then "UtilityMiner"
				elseif item.RarityTier <= 3 then "FrontierRanger"
				else "HeavyVanguard"
			item.Look = item.AssetFamily
		end
	end
end

-- Simplify future signatures into a small set of shared systems.
for _, entries in Traits.Catalog do
	for _, item in entries do
		local description = string.lower(item.ProposedBuff)
		item.TraitFamily = if string.find(description, "shield", 1, true)
				or string.find(description, "barrier", 1, true)
			then "Barrier"
			elseif
				string.find(description, "speed", 1, true) or string.find(description, "dodge", 1, true)
			then "Mobility"
			elseif string.find(description, "saga", 1, true) then "Recovery"
			elseif
				string.find(description, "critical", 1, true) or string.find(description, "precision", 1, true)
			then "Precision"
			elseif
				string.find(description, "regen", 1, true) or string.find(description, "health", 1, true)
			then "Recovery"
			else "Combat"
		if string.find(description, "immunity", 1, true) then
			item.TraitFamily = "HazardResistance"
			item.PlannedHazardResistance = EquipmentBalance.MaxHazardResistance
			item.ProposedBuff = if item.Id == "MatrixBoots9"
				then "Thermal resistance: reduce fire and lava hazard damage by up to 60%."
				else "Corrosive resistance: reduce corrosive hazard damage by up to 60%."
		end
		local utility = if item.Id == "MatrixBoots10"
			then "PhaseDodge"
			elseif item.Id == "MatrixShields5" or item.Id == "MatrixShields7" then "Reflection"
			else nil
		if utility then
			item.TraitFamily = "Utility"
			item.PlannedUtility = utility
			item.InternalCooldown = EquipmentBalance.UtilityCooldowns[utility]
		end
	end
end
for _, visor in Traits.Visors do
	if visor.Index == 7 then
		visor.ProposedBuff = "Vacuum endurance: slow environmental air depletion by up to 60%; never grant immunity."
		visor.PlannedHazardResistance = EquipmentBalance.MaxHazardResistance
	elseif visor.Index == 8 then
		visor.PlannedUtility = "Reflection"
		visor.InternalCooldown = EquipmentBalance.UtilityCooldowns.Reflection
	elseif visor.Index == 10 then
		visor.PlannedUtility = "FirstHitGuard"
		visor.InternalCooldown = EquipmentBalance.UtilityCooldowns.FirstHitGuard
	end
end

function Traits.pick(catalog, rng)
	local groups = {}
	for _, gear in catalog do
		if gear.StartPool then
			local rarity = gear.RarityTier
			groups[rarity] = groups[rarity] or {}
			table.insert(groups[rarity], gear)
		end
	end
	local total = 0
	for rarity, weight in Traits.Weights do
		if groups[rarity] then
			total += weight
		end
	end
	if total == 0 then
		return nil
	end
	local pick = rng:NextNumber(0, total)
	for rarity, weight in Traits.Weights do
		local group = groups[rarity]
		if group then
			pick -= weight
			if pick <= 0 then
				return group[rng:NextInteger(1, #group)]
			end
		end
	end
	return nil
end
return Traits
