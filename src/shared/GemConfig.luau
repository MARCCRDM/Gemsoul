--[[
	Gemstone definitions, from "GemSoul: Gemstone Property & Generation
	Architecture". Shared by the server (which generates and grades gems) and
	the client (which displays them).

	A gem is a plain table so it can be saved and sent to clients:
	{
		Id: string,
		Element: "Fire" | "Frost" | "Shock" | "Poison",
		Tier: "Common" | "Uncommon" | "Rare" | "UltraRare",
		Clarity: 1-10,   -- rolled on generation
		Size: 1-10,      -- rolled on generation
		Cut: 1-10,       -- natural facet quality, rolled at discovery
		CutMethod: "Natural" | "Starter" | "Crate",
		Source: "MiningNode" | "MiningStore" | "PvEDrop" | "PvPWager",
		Found: number,   -- os.time() when generated
	}
]]

export type Gem = {
	Id: string,
	Element: string,
	Tier: string,
	Clarity: number,
	Size: number,
	Cut: number?,
	CutMethod: string?,
	EnchantmentXPGranted: boolean?,
	Source: string,
	Found: number,
}

export type Shade = { Tier: string, Name: string, Color: Color3, Color2: Color3?, Prismatic: boolean? }

local ExpeditionEconomy = require(script.Parent.ExpeditionEconomy)

local GemConfig = {}
-- Retain saved element keys while presenting space-tech affinities everywhere.
GemConfig.ElementLabels = { Fire = "Thermal", Frost = "Cryo", Shock = "Ion", Poison = "Corrosive" }
-- Directive names back to the saved keys.
GemConfig.ElementKeys = { Thermal = "Fire", Cryo = "Frost", Ion = "Shock", Corrosive = "Poison" }
function GemConfig.elementKey(name: string): string
	return GemConfig.ElementKeys[name] or name
end
function GemConfig.elementName(element: string): string
	return GemConfig.ElementLabels[element] or element
end

GemConfig.Elements = { "Fire", "Frost", "Shock", "Poison" }

-- Each element's colour tiers, all inside its approved hue: Thermal red,
-- Cryo blue, Corrosive green, Ion yellow. Thermal and Cryo top out at Rare;
-- Ion and Corrosive top out at Ultra-Rare.
GemConfig.Shades = {
	Fire = {
		{ Tier = "Common", Name = "Ember Red", Color = Color3.fromRGB(232, 104, 92) },
		{ Tier = "Uncommon", Name = "Plasma Crimson", Color = Color3.fromRGB(222, 36, 42) },
		{ Tier = "Rare", Name = "Deep Ruby Red", Color = Color3.fromRGB(168, 6, 34) },
		{
			Tier = "UltraRare",
			Name = "Solar Garnet",
			Color = Color3.fromRGB(200, 20, 60),
			Color2 = Color3.fromRGB(120, 0, 24),
		},
		{ Tier = "Legendary", Name = "Starfire Ruby", Color = Color3.fromRGB(255, 46, 46), Prismatic = true },
	},
	Frost = {
		{ Tier = "Common", Name = "Glacier Blue", Color = Color3.fromRGB(150, 200, 246) },
		{ Tier = "Uncommon", Name = "Vivid Blue", Color = Color3.fromRGB(40, 140, 255) },
		{ Tier = "Rare", Name = "Deep Royal Sapphire Blue", Color = Color3.fromRGB(18, 40, 160) },
		{
			Tier = "UltraRare",
			Name = "Abyssal Sapphire",
			Color = Color3.fromRGB(10, 30, 120),
			Color2 = Color3.fromRGB(40, 110, 230),
		},
		{ Tier = "Legendary", Name = "Aurora Sapphire", Color = Color3.fromRGB(60, 120, 255), Prismatic = true },
	},
	Shock = {
		{ Tier = "Common", Name = "Pale Citrine", Color = Color3.fromRGB(240, 222, 132) },
		{ Tier = "Uncommon", Name = "Bright Yellow", Color = Color3.fromRGB(255, 220, 30) },
		{ Tier = "Rare", Name = "Golden Topaz", Color = Color3.fromRGB(230, 180, 20) },
		{
			Tier = "UltraRare",
			Name = "Prismatic Arc Gold",
			Color = Color3.fromRGB(255, 196, 0),
			Prismatic = true,
		},
		{ Tier = "Legendary", Name = "Stormheart Citrine", Color = Color3.fromRGB(255, 236, 90), Prismatic = true },
	},
	Poison = {
		{ Tier = "Common", Name = "Pale Lime", Color = Color3.fromRGB(184, 232, 128) },
		{ Tier = "Uncommon", Name = "Emerald Green", Color = Color3.fromRGB(20, 170, 80) },
		{ Tier = "Rare", Name = "Viridian Jade", Color = Color3.fromRGB(30, 140, 90) },
		{
			Tier = "UltraRare",
			Name = "Toxic Neon Emerald",
			Color = Color3.fromRGB(70, 250, 100),
			Color2 = Color3.fromRGB(0, 110, 60),
		},
		{ Tier = "Legendary", Name = "Venomheart Emerald", Color = Color3.fromRGB(0, 255, 120), Prismatic = true },
	},
} :: { [string]: { Shade } }

-- Rarity odds live in GemRoller (40 / 25 / 20 / 10 / 5).
GemConfig.TierOrder = { "Common", "Uncommon", "Rare", "UltraRare", "Legendary" }

GemConfig.TierLabels = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	UltraRare = "Ultra-Rare",
	Legendary = "Legendary",
}

-- Badge colours for each element.
GemConfig.ElementColors = {
	Fire = Color3.fromRGB(238, 62, 54), -- red
	Frost = Color3.fromRGB(64, 150, 255), -- blue
	Shock = Color3.fromRGB(255, 212, 40), -- yellow
	Poison = Color3.fromRGB(70, 205, 90), -- green
}

-- The element whose badge colour this is (element hits are tinted with it).
function GemConfig.elementOfColor(color: Color3?): string?
	if not color then
		return nil
	end
	for element, tint in GemConfig.ElementColors do
		if
			math.abs(tint.R - color.R) < 0.02
			and math.abs(tint.G - color.G) < 0.02
			and math.abs(tint.B - color.B) < 0.02
		then
			return element
		end
	end
	return nil
end

GemConfig.SourceLabels = {
	MiningNode = "Dug from the mine",
	MiningStore = "Bought at the Mining Store",
	PvEDrop = "Dropped by a monster",
	PvPWager = "Won in a PvP duel",
	StarterSpin = "Starter gem spin",
	FirstStone = "Your first stone, from the mine",
}

-- What a gem does when socketed into a weapon.
GemConfig.ElementEffects = {
	Fire = "Raw damage and anti-heal: burns targets over time.",
	Frost = "Crowd control: slows targets and can freeze them.",
	Shock = "Burst and execute: arcs between enemies and finishes them.",
	Poison = "Anti-tank: shreds armor and leaves targets vulnerable.",
}

GemConfig.TierRank = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }

GemConfig.TierColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 120),
	Rare = Color3.fromRGB(80, 160, 255),
	UltraRare = Color3.fromRGB(255, 90, 220),
	Legendary = Color3.fromRGB(255, 176, 60),
}

-- Clarity and size are graded 1-10. High grades are rarer: these are the
-- relative chances of grades 1..10.
GemConfig.GradeWeights = { 16, 16, 14, 12, 11, 9, 8, 6, 5, 3 }

-- How lucky each source is (0 = baseline, 1 = very lucky). Luck raises the
-- odds of rarer colour tiers and gives clarity/size a chance at a reroll.
GemConfig.SourceLuck = {
	MiningNode = 0,
	VipMiningNode = 0.5,
	MiningStore = 0.15,
	PvEDrop = 0.1, -- plus the monster's own bonus
	StarterSpin = 0.25,
	FirstStone = 0,
}

-- Natural facet quality: 1-10, rolled at recovery. Diamond cut is the only shape.

-- Base value in coins by colour tier, before size, clarity and cut.
GemConfig.TierValue = {
	Common = 10,
	Uncommon = 25,
	Rare = 60,
	UltraRare = 120,
	Legendary = 250,
}

function GemConfig.shade(gem: Gem): Shade
	for _, shade in GemConfig.Shades[gem.Element] do
		if shade.Tier == gem.Tier then
			return shade
		end
	end
	return GemConfig.Shades[gem.Element][1]
end

function GemConfig.displayName(gem: Gem): string
	local state = if gem.Cut then "" else "Rough "
	return state .. GemConfig.shade(gem).Name .. " (" .. GemConfig.elementName(gem.Element) .. ")"
end

-- Coin value: economy-only, see ExpeditionEconomy.gemValue.
function GemConfig.value(gem: Gem): number
	return ExpeditionEconomy.gemValue(gem, GemConfig.TierValue[gem.Tier] or 10)
end

--[[
	Combat enchanting runs on three grades, each with one job:
	  Size     magnitude    raw damage, shield amount, armor shred
	  Clarity  duration     burn length, cooldowns, recharge rate
	  Cut      precision    crit, freeze and stun chances (player-facing "Precision")
	Weapons take Offense enchantments; every other slot takes Defense.
	Potency is economy-only now (ExpeditionEconomy.gemPotency).
]]
GemConfig.MetricOrder = { "Size", "Clarity", "Cut" }
GemConfig.MetricLabels = { Size = "Size", Clarity = "Clarity", Cut = "Precision" }
GemConfig.MetricRoles = { Size = "Magnitude", Clarity = "Duration", Cut = "Trigger rate" }

function GemConfig.side(slot: string): string
	return if slot == "Weapon" then "Offense" else "Defense"
end

-- Per grade point. Kind: "flat", "pct" (a fraction shown as %), "sec", "count".
type Stat = { Key: string, Label: string, Per: number, Kind: string }
GemConfig.Stats = {
	Offense = {
		Fire = {
			Size = { Key = "BurnDamage", Label = "Burn Damage", Per = 1.5, Kind = "flat" },
			Clarity = { Key = "BurnDuration", Label = "Burn Duration", Per = 0.4, Kind = "sec" },
			Cut = { Key = "IgniteChance", Label = "Critical Burn Chance", Per = 0.01, Kind = "pct" },
		},
		Frost = {
			Size = { Key = "SlowAmount", Label = "Slow Amount", Per = 0.02, Kind = "pct" },
			Clarity = { Key = "SlowDuration", Label = "Slow Duration", Per = 0.5, Kind = "sec" },
			Cut = { Key = "FreezeChance", Label = "Freeze Chance", Per = 0.008, Kind = "pct" },
		},
		Poison = {
			Size = { Key = "ArmorShred", Label = "Armor Shred", Per = 0.015, Kind = "pct" },
			Clarity = { Key = "DebuffDuration", Label = "Debuff Duration", Per = 0.5, Kind = "sec" },
			Cut = { Key = "VulnerableChance", Label = "Vulnerability Chance", Per = 0.005, Kind = "pct" },
		},
		Shock = {
			Size = { Key = "ArcDamage", Label = "Arc Damage", Per = 1.2, Kind = "flat" },
			Clarity = { Key = "ChainLength", Label = "Chain Length", Per = 0.5, Kind = "count" },
			Cut = { Key = "StunChance", Label = "Stun Chance", Per = 0.005, Kind = "pct" },
		},
	},
	Defense = {
		Fire = {
			Size = { Key = "ShieldAmount", Label = "Heat Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "CooldownCut", Label = "Shield Cooldown", Per = 0.2, Kind = "sec" },
			Cut = { Key = "ReflectChance", Label = "Reflect Chance", Per = 0.005, Kind = "pct" },
		},
		Frost = {
			Size = { Key = "ShieldAmount", Label = "Cryo Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "ShieldDuration", Label = "Cryo Shield Duration", Per = 1, Kind = "sec" },
			Cut = { Key = "Resistance", Label = "Resistance", Per = 0.005, Kind = "pct" },
		},
		Poison = {
			Size = { Key = "ShieldAmount", Label = "Rad Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "CleanseRate", Label = "Cleanse Rate", Per = 1, Kind = "count" },
			Cut = { Key = "AuraShred", Label = "Corrosion Aura", Per = 0.005, Kind = "pct" },
		},
		Shock = {
			Size = { Key = "ShieldAmount", Label = "Ion Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "RechargeRate", Label = "Shield Recharge", Per = 0.02, Kind = "pct" },
			Cut = { Key = "DeflectChance", Label = "Deflect Chance", Per = 0.005, Kind = "pct" },
		},
	},
} :: { [string]: { [string]: { [string]: Stat } } }

-- Fixed rules the grades plug into.
GemConfig.Rules = {
	BurnTick = 1, -- seconds between burn ticks; a fresh hit refreshes the burn, never stacks it
	FreezeSeconds = 1.5,
	StunSeconds = 1,
	VulnerableAmount = 0.20, -- extra damage a Vulnerable target takes
	ExecuteThreshold = 0.10, -- Ion hits finish targets below this share of health
	ArcRange = 14,
	ShieldBaseDuration = 4, -- a gem shield holds this long once it raises
	ShieldBaseCooldown = 15, -- then recharges for this long
	ShieldMinCooldown = 5,
	CleanseMaxInterval = 12, -- Corrosive armor cleanses every (12 - Clarity) s, at least every 2 s
	CleanseMinInterval = 2,
	AuraRadius = 12,
	MaxSlow = 0.40,
}

-- PvP rides on top of the PvE numbers: multipliers, then caps.
GemConfig.PvP = {
	Mult = {
		BurnDamage = 0.5,
		SlowAmount = 0.75,
		FreezeChance = 0.6,
		ArmorShred = 0.5,
		ArcDamage = 0.8,
		StunChance = 0,
	},
	Caps = { SlowAmount = 0.30, ArmorShred = 0.30, VulnerableAmount = 0.20 },
	CrowdControlSeconds = 0.5,
	GrievousWounds = 0.30, -- Thermal critical burns
	MortalStrike = 0.20, -- Corrosive vulnerability
	NoChain = true,
}

local function grade(gem: Gem, metric: string): number
	return math.clamp(math.floor((gem :: any)[metric] or 0), 0, 10)
end

--[[
	The numbers behind a socketed gem, as a flat table of stat keys.
	opts.Affinity  { [affixId]: bonus } from equipped armor (see GemConfig.Affixes)
	opts.PvP       apply the PvP multipliers and caps
]]
function GemConfig.stats(
	gem: Gem,
	slot: string,
	opts: { Affinity: { [string]: number }?, PvP: boolean? }?
): { [string]: number }
	local o = opts or {}
	local side = GemConfig.side(slot)
	local values = {}
	for metric, stat in GemConfig.Stats[side][gem.Element] or {} do
		local value = grade(gem, metric) * stat.Per
		if stat.Kind == "count" then
			value = math.floor(value)
		end
		values[stat.Key] = value
	end
	if side == "Offense" then
		if gem.Element == "Shock" then
			values.ChainLength = math.max(1, values.ChainLength)
			values.ExecuteThreshold = GemConfig.Rules.ExecuteThreshold
		elseif gem.Element == "Poison" then
			values.VulnerableAmount = GemConfig.Rules.VulnerableAmount
		elseif gem.Element == "Frost" then
			values.SlowAmount = math.min(values.SlowAmount, GemConfig.Rules.MaxSlow)
			values.FreezeSeconds = GemConfig.Rules.FreezeSeconds
		end
		if gem.Element == "Shock" then
			values.StunSeconds = GemConfig.Rules.StunSeconds
		end
	end
	-- Elemental affinities from armor boost one stat of one element by a percentage.
	for id, bonus in o.Affinity or {} do
		local affix = GemConfig.AffixById[id]
		if affix and affix.Element == gem.Element and affix.Side == side and values[affix.Stat] then
			values[affix.Stat] *= 1 + bonus
		end
	end
	if o.PvP then
		for key, mult in GemConfig.PvP.Mult do
			if values[key] then
				values[key] *= mult
			end
		end
		for key, cap in GemConfig.PvP.Caps do
			if values[key] then
				values[key] = math.min(values[key], cap)
			end
		end
		if values.FreezeSeconds then
			values.FreezeSeconds = math.min(values.FreezeSeconds, GemConfig.PvP.CrowdControlSeconds)
		end
		if values.StunSeconds then
			values.StunSeconds = math.min(values.StunSeconds, GemConfig.PvP.CrowdControlSeconds)
		end
		if gem.Element == "Shock" and side == "Offense" then
			values.ChainLength = 1
		end
		if gem.Element == "Fire" and side == "Offense" then
			values.HealingReduction = GemConfig.PvP.GrievousWounds
		elseif gem.Element == "Poison" and side == "Offense" then
			values.HealingReduction = GemConfig.PvP.MortalStrike
		end
	end
	return values
end

local function percent(value: number): string
	local pct = value * 100
	if math.abs(pct - math.floor(pct + 0.5)) < 0.05 then
		return string.format("%d%%", math.floor(pct + 0.5))
	end
	return string.format("%.1f%%", pct)
end
GemConfig.percent = percent

local function number(value: number): string
	if math.abs(value - math.floor(value + 0.5)) < 0.05 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%.1f", value)
end

-- Tooltip lines: concrete effects, each tagged with the grade that drives it.
export type Line = { Metric: string?, Grade: number?, Text: string } -- no Metric: a fixed rule
function GemConfig.lines(gem: Gem, slot: string, opts: { Affinity: { [string]: number }?, PvP: boolean? }?): { Line }
	local v = GemConfig.stats(gem, slot, opts)
	local side = GemConfig.side(slot)
	local name = GemConfig.elementName(gem.Element)
	local s, c, p = grade(gem, "Size"), grade(gem, "Clarity"), grade(gem, "Cut")
	local lines = {}
	local function add(metric: string?, value: number?, text: string)
		table.insert(lines, { Metric = metric, Grade = value, Text = text })
	end
	if side == "Offense" then
		if gem.Element == "Fire" then
			add("Size", s, string.format("+%s %s damage per tick", number(v.BurnDamage), name))
			add("Clarity", c, string.format("Burns for %ss", number(v.BurnDuration)))
			add("Cut", p, string.format("%s critical burn chance", percent(v.IgniteChance)))
		elseif gem.Element == "Frost" then
			add("Size", s, string.format("Slows targets by %s", percent(v.SlowAmount)))
			add("Clarity", c, string.format("Slow lasts %ss", number(v.SlowDuration)))
			add(
				"Cut",
				p,
				string.format("%s chance to freeze for %ss", percent(v.FreezeChance), number(v.FreezeSeconds))
			)
		elseif gem.Element == "Poison" then
			add("Size", s, string.format("Shreds %s armor", percent(v.ArmorShred)))
			add("Clarity", c, string.format("Corrosion lasts %ss", number(v.DebuffDuration)))
			add(
				"Cut",
				p,
				string.format(
					"%s chance to make targets Vulnerable (+%s damage taken)",
					percent(v.VulnerableChance),
					percent(v.VulnerableAmount)
				)
			)
		else
			add("Size", s, string.format("+%s arc damage per hit", number(v.ArcDamage)))
			add(
				"Clarity",
				c,
				if v.ChainLength <= 1
					then "Arcs to 1 nearby enemy"
					else string.format("Chains through %d enemies", v.ChainLength)
			)
			if v.StunChance > 0 then
				add("Cut", p, string.format("%s chance to stun for %ss", percent(v.StunChance), number(v.StunSeconds)))
			else
				add("Cut", p, "Stun replaced by Execute in PvP")
			end
		end
	else
		local shield = GemConfig.EnchantNames.Armor[gem.Element] or "Shield"
		add("Size", s, string.format("%s absorbs %s damage", shield, number(v.ShieldAmount)))
		if gem.Element == "Fire" then
			add("Clarity", c, string.format("Shield recharges %ss sooner", number(v.CooldownCut)))
			add("Cut", p, string.format("%s chance to reflect a hit", percent(v.ReflectChance)))
		elseif gem.Element == "Frost" then
			add("Clarity", c, string.format("Shield holds %ss longer", number(v.ShieldDuration)))
			add("Cut", p, string.format("Take %s less damage", percent(v.Resistance)))
		elseif gem.Element == "Poison" then
			add(
				"Clarity",
				c,
				string.format("Cleanses a debuff every %ss", number(GemConfig.cleanseInterval(v.CleanseRate, 0)))
			)
			add("Cut", p, string.format("Nearby enemies take %s more damage", percent(v.AuraShred)))
		else
			add("Clarity", c, string.format("Shield recharges %s faster", percent(v.RechargeRate)))
			add("Cut", p, string.format("%s chance to deflect a hit", percent(v.DeflectChance)))
		end
	end
	if side == "Offense" and gem.Element == "Shock" then
		add(nil, nil, string.format("Executes targets below %s health", percent(v.ExecuteThreshold)))
	end
	if opts and opts.PvP and v.HealingReduction then
		add(nil, nil, string.format("Applies %s healing reduction for 4s", percent(v.HealingReduction)))
	end
	return lines
end

function GemConfig.cleanseInterval(clarityRate: number, bonus: number?): number
	local interval = math.max(GemConfig.Rules.CleanseMinInterval, GemConfig.Rules.CleanseMaxInterval - clarityRate)
	return interval / (1 + (bonus or 0))
end

-- What a socketed gem does, in one line, for toasts and compact labels.
GemConfig.EnchantNames = {
	Weapon = { Fire = "Thermal", Frost = "Cryogenic", Shock = "Ionized", Poison = "Corrosive" },
	Armor = { Fire = "Heat Shield", Frost = "Cryo Shield", Shock = "Ion Shield", Poison = "Rad Shield" },
}

function GemConfig.enchantment(
	gem: Gem,
	slot: string,
	opts: { Affinity: { [string]: number }?, PvP: boolean? }?
): (string, string)
	if slot == "Surge1" or slot == "Surge2" or slot == "Surge3" then
		return "Surge Capacitor", "Powers " .. (GemConfig.ElementLabels[gem.Element] or gem.Element) .. " Gem Surges."
	end
	local side = GemConfig.side(slot)
	local name = GemConfig.EnchantNames[if side == "Offense" then "Weapon" else "Armor"][gem.Element] or "Enchanted"
	local parts = {}
	for _, line in GemConfig.lines(gem, slot, opts) do
		table.insert(parts, line.Text)
	end
	return name, table.concat(parts, " · ")
end

-- Universal actions consume the independent Size/Clarity/Precision metrics.
function GemConfig.actionValues(gem: Gem, action: string, opts): { [string]: any }
	local v = GemConfig.stats(gem, if action == "Block" then "Shield" else "Weapon", opts)
	if action == "Block" then
		return {
			Shield = v.ShieldAmount,
			Duration = GemConfig.Rules.ShieldBaseDuration + (v.ShieldDuration or 0),
			Cooldown = math.max(
				GemConfig.Rules.ShieldMinCooldown,
				GemConfig.Rules.ShieldBaseCooldown - (v.CooldownCut or 0)
			) / (1 + (v.RechargeRate or 0)),
			ReflectThermal = if gem.Element == "Fire" then 0.10 else nil,
			ReflectChance = v.ReflectChance,
			Cleanse = gem.Element == "Poison",
			CleanseInterval = if v.CleanseRate then GemConfig.cleanseInterval(v.CleanseRate) else nil,
			Resist = v.Resistance,
			Deflect = v.DeflectChance,
			Aura = v.AuraShred,
		}
	end
	return {
		Burn = v.BurnDamage,
		Duration = v.BurnDuration or v.SlowDuration or v.DebuffDuration,
		Ignite = v.IgniteChance,
		Slow = v.SlowAmount,
		Freeze = v.FreezeChance,
		FreezeSeconds = v.FreezeSeconds,
		Sunder = v.ArmorShred,
		Vulnerable = v.VulnerableChance,
		VulnerableAmount = v.VulnerableAmount,
		Arc = v.ArcDamage,
		Chain = v.ChainLength,
		Stun = v.StunChance,
		StunSeconds = v.StunSeconds,
		Execute = v.ExecuteThreshold,
		HealingReduction = v.HealingReduction,
	}
end

-- Gems no longer add flat ratings; their power lives in their effects.
-- Kept so older callers still work.
function GemConfig.statBonuses(_gem: Gem, _slot: string): { [string]: number }
	return {}
end

--[[
	Elemental Affinity Affixes: random modifiers on Rare+ armor that boost one
	element's stat by a percentage. Each element has an offensive stat for
	every grade (boosting your weapon gem) and a defensive one (boosting
	armor gems), plus Ion's Execute Threshold.
]]
export type Affix = { Id: string, Element: string, Side: string, Stat: string, Metric: string?, Label: string }
GemConfig.Affixes = {} :: { Affix }
GemConfig.AffixById = {} :: { [string]: Affix }
do
	local function addAffix(element: string, side: string, stat: string, metric: string?, label: string)
		local affix = {
			Id = element .. side .. stat,
			Element = element,
			Side = side,
			Stat = stat,
			Metric = metric,
			Label = label,
		}
		table.insert(GemConfig.Affixes, affix)
		GemConfig.AffixById[affix.Id] = affix
	end
	for _, element in GemConfig.Elements do
		for _, side in { "Offense", "Defense" } do
			for _, metric in GemConfig.MetricOrder do
				local stat = GemConfig.Stats[side][element][metric]
				addAffix(element, side, stat.Key, metric, stat.Label)
			end
		end
		if element == "Shock" then
			addAffix(element, "Offense", "ExecuteThreshold", nil, "Execute Threshold")
		end
	end
end
-- Bonus ranges by gear rarity (1-5): Rare +5-10%, Ultra Rare +10-15%, Legendary +15-20%.
GemConfig.AffixCounts = { 0, 0, 1, 2, 3 }
GemConfig.AffixRanges = { [3] = { 5, 10 }, [4] = { 10, 15 }, [5] = { 15, 20 } }

function GemConfig.affixText(id: string, bonus: number): string
	local affix = GemConfig.AffixById[id]
	if not affix then
		return ""
	end
	return string.format("%s Affinity: +%s %s", GemConfig.elementName(affix.Element), percent(bonus), affix.Label)
end

-- "Flawless Thermal Gem": a quality word from the three grades together.
GemConfig.GradeWords = {
	{ 8, "Flawless" },
	{ 6.5, "Pristine" },
	{ 5, "Fine" },
	{ 3.5, "Clear" },
	{ 2, "Chipped" },
	{ 0, "Cracked" },
}
function GemConfig.title(gem: Gem): string
	local average = (gem.Size + gem.Clarity + (gem.Cut or 0)) / 3
	local word = "Cracked"
	for _, entry in GemConfig.GradeWords do
		if average >= entry[1] then
			word = entry[2]
			break
		end
	end
	return word .. " " .. GemConfig.elementName(gem.Element) .. " Gem"
end

-- How strongly a gem's enchantment shows on gear (glow, particles), 0-1.
function GemConfig.strength(gem: Gem): number
	return math.clamp((gem.Size + gem.Clarity + (gem.Cut or 0)) / 30, 0, 1)
end

-- Enchanted gear takes a name from its gem: "Burning Longsword",
-- "Iron Plate of Embers".
GemConfig.ItemAffixes = {
	Weapon = { Fire = "Thermal", Frost = "Cryogenic", Shock = "Ionized", Poison = "Corrosive" },
	Armor = {
		Fire = "of Thermal Shielding",
		Frost = "of Cryo Insulation",
		Shock = "of Ion Shielding",
		Poison = "of Corrosion Warding",
	},
}

function GemConfig.itemName(baseName: string, gem: Gem?, slot: string): string
	slot = if slot == "Weapon" then "Weapon" else "Armor"
	if not gem then
		return baseName
	end
	local affix = GemConfig.ItemAffixes[slot] and GemConfig.ItemAffixes[slot][gem.Element]
	if not affix then
		return baseName
	end
	return if slot == "Armor" then baseName .. " " .. affix else affix .. " " .. baseName
end

return GemConfig
