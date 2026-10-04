--[[
	The Forge: the weapons found in the mine and traded between players.
	Five kinds, each fighting its own way, in five rarities. Every one of the
	25 carries its own signature perk: a different ability at a different
	strength, growing with rarity.

	  Cleaver    (Prospector)  balanced sword, three-hit combo
	  Twin Blades (Skirmisher) fast, light, both hands
	  Lance      (Skirmisher)  long reach, narrow thrust
	  Greataxe   (Juggernaut)  slow, heavy, a wide arc
	  Warhammer  (Prospector)  slowest, hardest, knocks foes back

	Two-handed types deal higher base damage per second to offset their lost shield; what changes is how
	(reach, arc, pace) and what their perk does. Perk effects are read by
	CombatServer from Passive.Effect (see WeaponForge.Perks for every key).

	  WeaponForge.Types        the five kinds, in order
	  WeaponForge.Catalog      the 25 weapons (gear entries)
	  WeaponForge.Perks        [key] = what the perk does, for the UI and tests
	  WeaponForge.perkText(weapon)  "Siphon Edge: heals you for 5% of ..."
]]
local WeaponForge = {}

WeaponForge.Types = {
	{
		Id = "Cleaver",
		Family = "Prospector",
		Attack = { Kind = "Melee", Damage = 18, Rate = 0.65, Range = 7, Arc = 95, Combo = 3 },
		Names = {
			"Rustbite Cleaver",
			"Ironvein Cutlass",
			"Quarrylord's Edge",
			"Starfall Claymore",
			"Eclipse Sunderblade",
		},
		Blurb = "A balanced sword: steady swings, a three-hit combo.",
	},
	{
		Id = "TwinBlades",
		Family = "Skirmisher",
		Attack = { Kind = "Melee", Damage = 14, Rate = 0.44, Range = 6, Arc = 85, Combo = 3 },
		Names = { "Scrapper Fangs", "Ion Twinfangs", "Viper Duet", "Phantom Shears", "Nebula Reapers" },
		Blurb = "A blade in each hand: quick, light cuts.",
	},
	{
		Id = "Lance",
		Family = "Skirmisher",
		Attack = { Kind = "Melee", Damage = 20, Rate = 0.62, Range = 10, Arc = 40, Combo = 3 },
		Names = { "Survey Pike", "Frostline Lance", "Arcspire Lance", "Voidpiercer", "Saga Starlance" },
		Blurb = "Long reach, a narrow thrust: hit them before they reach you.",
	},
	{
		Id = "Greataxe",
		Family = "Juggernaut",
		Attack = { Kind = "Melee", Damage = 31, Rate = 0.95, Range = 8.5, Arc = 140, Combo = 3 },
		Names = { "Pit Splitter", "Ember Reaver", "Bloodrage Maw", "Titan Cleft", "Worldbreaker" },
		Blurb = "Slow, brutal, and wide: every swing sweeps around you.",
	},
	{
		Id = "Warhammer",
		Family = "Prospector",
		Attack = { Kind = "Melee", Damage = 35, Rate = 1.05, Range = 7, Arc = 90, Combo = 3 },
		Names = { "Stone Knocker", "Piston Maul", "Thunder Gavel", "Gravitas Hammer", "Singularity Maul" },
		Blurb = "The slowest and hardest: blows that send foes flying.",
	},
}

-- What each perk does. `Value` is a fraction (0.05 = 5%) unless noted.
-- (TakenMult is a multiplier: 0.88 = 12% less damage taken.)
WeaponForge.Perks = {
	Lifesteal = { Name = "Siphon Edge", Text = "heals you for %d%% of the damage you deal" },
	StaminaOnHit = { Name = "Second Wind", Text = "each hit restores %d%% Stamina" },
	KillHeal = { Name = "Victor's Feast", Text = "a kill heals %d%% of your max health" },
	FirstStrike = { Name = "Opening Cut", Text = "+%d%% damage to foes at full health" },
	Execute = { Name = "Executioner", Text = "+%d%% damage to foes under 35%% health" },
	AttackSpeed = { Name = "Flurry", Text = "swings %d%% faster" },
	CritAdd = { Name = "Keen Edges", Text = "+%d%% critical chance" },
	ComboFinisher = { Name = "Crossfang", Text = "the third hit of a combo deals +%d%%" },
	Bleed = { Name = "Serrated", Text = "hits bleed for %d%% of their damage over 3s" },
	CritDamage = { Name = "Nebula Rend", Text = "critical hits deal +%d%% more" },
	ChargeOnHit = { Name = "Conductor", Text = "each hit restores %d%% Charge" },
	SlowOnHit = { Name = "Frost Tip", Text = "hits slow the target by %d%% for 2s" },
	StunOnHit = { Name = "Arc Jolt", Text = "%d%% chance on hit to stun for 0.6s" },
	Sunder = { Name = "Piercer", Text = "hits make the target take %d%% more damage for 5s" },
	SurgeBonus = { Name = "Saga Conduit", Text = "your surges deal +%d%% damage" },
	HeavyBonus = { Name = "Cleave", Text = "heavy blows deal +%d%% damage" },
	BurnOnHit = { Name = "Ember Bite", Text = "%d%% chance on hit to burn for 40%% of the hit over 3s" },
	Berserk = { Name = "Bloodrage", Text = "+%d%% damage while you're under 50%% health" },
	Duelist = { Name = "Gladiator", Text = "+%d%% damage against players and rivals" },
	TakenMult = { Name = "Titan Hide", Text = "take %d%% less damage", Inverse = true },
	Knockback = { Name = "Heavy Head", Text = "heavy blows knock foes %d%% farther" },
	GuardBreaker = { Name = "Shieldcrusher", Text = "+%d%% damage to foes who are blocking" },
	Thorns = { Name = "Retribution", Text = "melee attackers take %d%% of their hit back" },
	BlockStamina = { Name = "Iron Will", Text = "blocking costs %d%% less Stamina" },
	Tenacity = { Name = "Unstoppable", Text = "stuns and freezes on you last %d%% shorter" },
}

-- [type][rarity] = { perk key, value }. 25 different perks, stronger with rarity.
local PERKS = {
	Cleaver = {
		{ "Lifesteal", 0.05 },
		{ "StaminaOnHit", 0.06 },
		{ "KillHeal", 0.15 },
		{ "FirstStrike", 0.30 },
		{ "Execute", 0.40 },
	},
	TwinBlades = {
		{ "AttackSpeed", 0.08 },
		{ "CritAdd", 0.07 },
		{ "ComboFinisher", 0.30 },
		{ "Bleed", 0.25 },
		{ "CritDamage", 0.50 },
	},
	Lance = {
		{ "ChargeOnHit", 0.04 },
		{ "SlowOnHit", 0.20 },
		{ "StunOnHit", 0.10 },
		{ "Sunder", 0.12 },
		{ "SurgeBonus", 0.25 },
	},
	Greataxe = {
		{ "HeavyBonus", 0.15 },
		{ "BurnOnHit", 0.18 },
		{ "Berserk", 0.25 },
		{ "Duelist", 0.18 },
		{ "TakenMult", 0.88 },
	},
	Warhammer = {
		{ "Knockback", 0.35 },
		{ "GuardBreaker", 0.35 },
		{ "Thorns", 0.15 },
		{ "BlockStamina", 0.30 },
		{ "Tenacity", 0.30 },
	},
}
WeaponForge.PerkTable = PERKS

local function percent(key: string, value: number): number
	local perk = WeaponForge.Perks[key]
	return math.floor((if perk and perk.Inverse then 1 - value else value) * 100 + 0.5)
end

-- "Siphon Edge: heals you for 5% of the damage you deal."
function WeaponForge.perkText(key: string, value: number): (string, string)
	local perk = WeaponForge.Perks[key]
	if not perk then
		return "", ""
	end
	local body = string.format(perk.Text, percent(key, value))
	return perk.Name, string.upper(string.sub(body, 1, 1)) .. string.sub(body, 2) .. "."
end

-- How much a weapon's perk changes one blow (pure, shared by CombatServer
-- and the Arena rival). `context`: Heavy, Crit, Combo (1-3), TargetRatio and
-- OwnRatio (health / max), Versus (a player or rival), TargetGuarding.
function WeaponForge.multiplier(effects, context): number
	local bonus = 0
	if context.Heavy then
		bonus += effects.HeavyBonus or 0
	end
	if (context.TargetRatio or 0) >= 0.99 then
		bonus += effects.FirstStrike or 0
	end
	if (context.TargetRatio or 1) < 0.35 then
		bonus += effects.Execute or 0
	end
	if (context.OwnRatio or 1) < 0.5 then
		bonus += effects.Berserk or 0
	end
	if context.Versus then
		bonus += effects.Duelist or 0
	end
	if (context.Combo or 0) >= 3 then
		bonus += effects.ComboFinisher or 0
	end
	if context.TargetGuarding then
		bonus += effects.GuardBreaker or 0
	end
	local multiplier = 1 + bonus
	if context.Crit then
		multiplier *= 1 + (effects.CritDamage or 0)
	end
	return multiplier
end

WeaponForge.Catalog = {}
for _, kind in WeaponForge.Types do
	for rarity = 1, 5 do
		local key, value = PERKS[kind.Id][rarity][1], PERKS[kind.Id][rarity][2]
		local name, text = WeaponForge.perkText(key, value)
		table.insert(WeaponForge.Catalog, {
			Id = "Forge" .. kind.Id .. rarity,
			Name = kind.Names[rarity],
			Tier = rarity,
			RarityTier = rarity,
			StartPool = true,
			Forge = true,
			Style = "Frontier",
			Look = "Forge" .. kind.Id,
			WeaponType = kind.Id,
			Hands = if kind.Id == "Cleaver" then 1 else 2,
			WeaponBlock = kind.Id ~= "Cleaver",
			ArmorFamily = kind.Family,
			Mods = {},
			BuffReady = true,
			ProposedBuff = text,
			Blurb = kind.Blurb,
			Passive = { Name = name, Text = text, Effect = { [key] = value } },
			Attack = table.clone(kind.Attack),
		})
	end
end

return WeaponForge
