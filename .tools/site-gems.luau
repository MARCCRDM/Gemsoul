local colorMt = { __index = {
	Lerp = function(self, other, amount)
 return setmetatable({R=self.R*(1-amount)+other.R*amount,G=self.G*(1-amount)+other.G*amount,B=self.B*(1-amount)+other.B*amount,kind="Color3"},getmetatable(self))
 end,
} }
local Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r, G = g, B = b, kind = "Color3" }, colorMt)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local vmt = {}
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vmt)
	end,
}
vmt.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

local cmt = {}
local CFrame = {}
function CFrame.new(x,y,z)
 return setmetatable({t={x or 0,y or 0,z or 0},r={1,0,0,0,1,0,0,0,1}},cmt)
end
function CFrame.Angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local a=CFrame.new(); a.r={cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy}; return a
end
cmt.__mul=function(a,b)
 local c=CFrame.new()
 for i=1,3 do
  c.t[i]=a.t[i]
  for k=1,3 do c.t[i]+=a.r[(i-1)*3+k]*b.t[k] end
  for j=1,3 do
   local v=0
   for k=1,3 do v+=a.r[(i-1)*3+k]*b.r[(k-1)*3+j] end
   c.r[(i-1)*3+j]=v
  end
 end
 return c
end
CFrame.identity=CFrame.new()
local enumMt = {
	__index = function(_self, key)
		return key
	end,
}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({}, enumMt)
		rawset(self, key, t)
		return t
	end,
})
local built = 0
local builtParts = {}
local Instance = {
	new = function(className)
		local values = { ClassName = className }
		return setmetatable({}, {
			__index = values,
			__newindex = function(_self, key, value)
				if key == "Color" then
					assert(
						type(value) == "table" and value.kind == "Color3",
						"Invalid Color assignment: " .. type(value)
					)
				end
				if key == "Size" then
					assert(value.X > 0 and value.Y > 0 and value.Z > 0, "Invalid part size")
				end
				values[key] = value
				if key == "Parent" and (className == "Part" or className == "WedgePart") then
					built += 1
					table.insert(builtParts, values)
				end
			end,
		})
	end,
}

local randomSeed = 123
local Random = {
	new = function(seed)
		randomSeed += 1
		local state = seed or randomSeed
		return {
			NextNumber = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return (low or 0) + state / 2147483647 * ((high or 1) - (low or 0))
			end,
			NextInteger = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return low + state % (high - low + 1)
			end,
		}
	end,
}


vmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
Vector3.zero=Vector3.new(0,0,0)
vmt.__index=function(a,k) if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) elseif k=="Unit" then local n=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z);return a/n end end

local ExpeditionEconomy=(function()
-- Migration and reward compatibility for the loot-and-trade expedition economy.
local Economy = {}
local rates = { Iron = 12, Timber = 8, Leather = 10, Cloth = 10, Mithril = 60, Shards = 20 }

--[[
	Gem potency is an economy number only; combat reads Size, Clarity and Cut
	directly (GemConfig.stats). Cut weighs most because precision is the
	rarest endgame stat.
	  Value = Base Tier Value x (Size x 10 + Clarity x 5 + Cut x 15) x scale
	The scale keeps the average mined gem's price where the economy expects it.
]]
Economy.GemValueScale = 0.045
function Economy.gemPotency(gem)
	return gem.Size * 10 + gem.Clarity * 5 + (gem.Cut or 0) * 15
end
function Economy.gemValue(gem, tierValue)
	return math.max(1, math.floor(tierValue * Economy.gemPotency(gem) * Economy.GemValueScale + 0.5))
end
function Economy.legacyCredits(marks, materials)
	local coins = math.max(0, marks or 0)
	for id, count in materials or {} do
		coins += math.max(0, count) * (rates[id] or 1)
	end
	return math.floor(coins)
end
function Economy.migrate(profile, rng)
	local gems, seen = {}, {}
	local function collect(gem)
		if not gem then
			return
		end
		table.insert(gems, gem)
		if gem.Cut then
			seen[gem.Id] = gem.Cut
		end
	end
	for _, gem in profile.Gems or {} do
		collect(gem)
	end
	local c = profile.Character
	for _, slot in { "Weapon", "Armor", "Helmet", "Gloves", "Boots", "Shield" } do
		collect(c[slot .. "Gem"])
		for _, gem in c.ItemGems and c.ItemGems[slot] or {} do
			collect(gem)
		end
	end
	for _, gem in gems do
		if not gem.Cut then
			gem.Cut = seen[gem.Id] or rng:NextInteger(1, 10)
			gem.CutMethod = "Natural"
			seen[gem.Id] = gem.Cut
		end
	end
	if profile.ExpeditionEconomyVersion ~= 1 then
		profile.Coins += Economy.legacyCredits(profile.Marks, profile.Materials)
		profile.Marks = 0
		profile.Materials = {}
		profile.ExpeditionEconomyVersion = 1
	end
end
return Economy

end)()

local GemConfig=(function()
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

end)()

local GemShapes=(function()
--[[
	3D shapes for gems, as plain triangles (no Instances), so they can be
	built into parts by GemArt and tested outside Roblox.

	Every visual comes from the gem's properties:
	  Colour   the gem's shade; fusion stones are two-tone, prismatic stones
	           have rainbow facets
	  Size     overall scale (grade 10 is about twice grade 1)
	  Clarity  how see-through the stone is, plus dark inclusions and a
	           milky cloud inside low-clarity stones; clear stones (7+)
	           glow from a core that brightens with clarity
	  Cut      rough stones are water-worn pebbles shaped by their id; cut
	           stones are round brilliants whose symmetry, proportions and
	           facet count improve with the cut grade, sparkling at 9-10

	GemShapes.build(gem, detailed) returns:
	  {
	    Triangles = { { A, B, C: Vector3, Color: Color3 } },
	    Transparency = number,     -- for every facet
	    Material = "Glass" | "SmoothPlastic",
	    Specks = { { Position: Vector3, Radius: number, Color: Color3, Transparency: number, Glow: boolean? } },
	    Sparkles = { Vector3 },    -- points that get a small glint
	    Radius = number,           -- bounding radius, for framing a camera
	  }
]]


local GemShapes = {}

export type Triangle = { A: Vector3, B: Vector3, C: Vector3, Color: Color3 }

local function seedOf(gem): number
	local seed = 7
	for i = 1, #gem.Id do
		seed = (seed * 31 + string.byte(gem.Id, i)) % 2147483647
	end
	return seed
end

-- Size grade to scale: grade 1 is 0.67, grade 10 is 1.3.
GemShapes.MaxRadius = 1.45 * 1.3 -- the biggest any gem can be, for fixed cameras
function GemShapes.scale(size: number): number
	return 0.6 + 0.07 * math.clamp(size, 1, 10)
end

-- Clarity 1 is nearly opaque and cloudy; clarity 10 is glass-clear.
local function transparencyFor(clarity: number): number
	return 0.02 + (math.clamp(clarity, 1, 10) - 1) * 0.062
end

-- Low-clarity stones look frosted: their colour is washed toward milky white.
local function frosted(color: Color3, clarity: number): Color3
	return color:Lerp(Color3.fromRGB(235, 235, 235), (10 - math.clamp(clarity, 1, 10)) * 0.035)
end

-- Picks each facet's colour from the gem's shade.
local function colorer(shade)
	if shade.Prismatic then
		return function(centroid: Vector3): Color3
			local hue = (math.atan2(centroid.Z, centroid.X) / (2 * math.pi) + 0.5 + centroid.Y * 0.15) % 1
			return Color3.fromHSV(hue, 0.55, 1):Lerp(shade.Color, 0.6)
		end
	elseif shade.Color2 then
		return function(centroid: Vector3): Color3
			return if centroid.Y > 0 then shade.Color else shade.Color2
		end
	end
	return function(): Color3
		return shade.Color
	end
end

-- Inclusions: dark specks and a milky cloud, more of them at low clarity.
local function inclusions(rng: Random, clarity: number, radius: number, color: Color3)
	local specks = {}
	local count = math.max(0, 7 - clarity)
	for _ = 1, count do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-1, 1))
		table.insert(specks, {
			Position = direction.Unit * rng:NextNumber(0.1, 0.5) * radius,
			Radius = rng:NextNumber(0.04, 0.09) * radius,
			Color = Color3.fromRGB(40, 34, 30),
			Transparency = 0.1,
		})
	end
	if clarity <= 6 then
		table.insert(specks, {
			Position = Vector3.new(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)) * radius,
			Radius = (0.2 + (6 - clarity) * 0.06) * radius,
			Color = color:Lerp(Color3.new(1, 1, 1), 0.6),
			Transparency = 0.45,
		})
	end
	return specks
end

-- Rough stones -------------------------------------------------------------------

-- An icosphere: an icosahedron with each face split into four, on the unit sphere.
local function icosphere(): ({ Vector3 }, { { number } })
	local t = (1 + math.sqrt(5)) / 2
	local vertices = {
		Vector3.new(-1, t, 0),
		Vector3.new(1, t, 0),
		Vector3.new(-1, -t, 0),
		Vector3.new(1, -t, 0),
		Vector3.new(0, -1, t),
		Vector3.new(0, 1, t),
		Vector3.new(0, -1, -t),
		Vector3.new(0, 1, -t),
		Vector3.new(t, 0, -1),
		Vector3.new(t, 0, 1),
		Vector3.new(-t, 0, -1),
		Vector3.new(-t, 0, 1),
	}
	for i, v in vertices do
		vertices[i] = v.Unit
	end
	local faces = {
		{ 1, 12, 6 },
		{ 1, 6, 2 },
		{ 1, 2, 8 },
		{ 1, 8, 11 },
		{ 1, 11, 12 },
		{ 2, 6, 10 },
		{ 6, 12, 5 },
		{ 12, 11, 3 },
		{ 11, 8, 7 },
		{ 8, 2, 9 },
		{ 4, 10, 5 },
		{ 4, 5, 3 },
		{ 4, 3, 7 },
		{ 4, 7, 9 },
		{ 4, 9, 10 },
		{ 5, 10, 6 },
		{ 3, 5, 12 },
		{ 7, 3, 11 },
		{ 9, 7, 8 },
		{ 10, 9, 2 },
	}
	local midpoints = {}
	local function midpoint(i: number, j: number): number
		local key = if i < j then i .. ":" .. j else j .. ":" .. i
		if not midpoints[key] then
			table.insert(vertices, ((vertices[i] + vertices[j]) / 2).Unit)
			midpoints[key] = #vertices
		end
		return midpoints[key]
	end
	local split = {}
	for _, f in faces do
		local a, b, c = midpoint(f[1], f[2]), midpoint(f[2], f[3]), midpoint(f[3], f[1])
		table.insert(split, { f[1], a, c })
		table.insert(split, { f[2], b, a })
		table.insert(split, { f[3], c, b })
		table.insert(split, { a, b, c })
	end
	return vertices, split
end

local function roughStone(gem, shade)
	local rng = Random.new(seedOf(gem))
	local scale = GemShapes.scale(gem.Size)
	-- A water-worn pebble: stretched, flattened and lumpy, different for
	-- every stone. A few broad bulges give the overall shape; a little
	-- per-vertex noise roughens the surface.
	local radii = Vector3.new(rng:NextNumber(1, 1.25), rng:NextNumber(0.55, 0.78), rng:NextNumber(0.68, 0.92))
	local bulges = {}
	for i = 1, 3 do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1))
		bulges[i] = { Direction = direction.Unit, Amount = rng:NextNumber(-0.22, 0.28) }
	end
	local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25))
	local vertices, faces = icosphere()
	local shaped = {}
	for i, v in vertices do
		local r = 1 + rng:NextNumber(-0.045, 0.045)
		for _, bulge in bulges do
			r += bulge.Amount * math.max(0, v:Dot(bulge.Direction)) ^ 2
		end
		shaped[i] = tilt * (v * radii * r * scale)
	end
	local colorOf = colorer(shade)
	local triangles = {}
	for _, f in faces do
		local a, b, c = shaped[f[1]], shaped[f[2]], shaped[f[3]]
		-- Natural stones vary a little in tone across their surface.
		local tone = frosted(colorOf((a + b + c) / 3), gem.Clarity)
		tone = tone:Lerp(
			if rng:NextNumber() < 0.5 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1),
			rng:NextNumber(0, 0.07)
		)
		table.insert(triangles, { A = a, B = b, C = c, Color = tone })
	end
	return {
		Triangles = triangles,
		Transparency = transparencyFor(gem.Clarity),
		Material = "Glass",
		Specks = inclusions(rng, gem.Clarity, 0.8 * scale, shade.Color),
		Sparkles = {},
		Radius = 1.45 * scale,
	}
end

-- Cut stones -----------------------------------------------------------------------

--[[
	A round brilliant, table facing up (+Y), girdle at y = 0:
	  table     flat polygon on top
	  crown     angled facets from the table down to the girdle
	  pavilion  facets narrowing to the culet point underneath
	Poor cuts are lopsided with a shallow pavilion and oversized table;
	good cuts are symmetrical with ideal proportions.
]]
local function cutStone(gem, shade, detailed: boolean)
	local rng = Random.new(seedOf(gem) + 1)
	local cut = math.clamp(gem.Cut or 1, 1, 10)
	local scale = GemShapes.scale(gem.Size)
	local sides = if detailed and cut >= 9 then 12 else 8
	local quality = (cut - 1) / 9 -- 0 = crude, 1 = perfect
	local wobble = (1 - quality) * 0.11 -- random error in every vertex

	local radius = 1
	local tableRadius = 0.66 - 0.11 * quality -- ideal table is ~55% of the width
	local crownHeight = 0.24 + 0.1 * quality
	local midRadius = 0.5
	local midDepth = -(0.3 + 0.15 * quality)
	local culetDepth = -(0.55 + 0.31 * quality) -- ideal pavilion is ~43% of the width

	local function jitter(v: Vector3): Vector3
		if wobble <= 0 then
			return v * scale
		end
		return (v + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * wobble)
			* scale
	end
	local function ring(r: number, y: number, offset: number): { Vector3 }
		local points = {}
		for k = 0, sides - 1 do
			local angle = (k + offset) / sides * 2 * math.pi
			points[k + 1] = jitter(Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r))
		end
		return points
	end

	local girdle = ring(radius, 0, 0)
	local tableRing = ring(tableRadius, crownHeight, 0.5)
	local pavilion = ring(midRadius, midDepth, 0.5)
	local top = jitter(Vector3.new(0, crownHeight, 0))
	local culet = jitter(Vector3.new(0, culetDepth, 0))

	local colorOf = colorer(shade)
	local triangles = {}
	local function add(a: Vector3, b: Vector3, c: Vector3)
		table.insert(triangles, { A = a, B = b, C = c, Color = frosted(colorOf((a + b + c) / 3), gem.Clarity) })
	end
	for k = 1, sides do
		local n = k % sides + 1
		add(top, tableRing[k], tableRing[n]) -- table
		add(tableRing[k], girdle[k], girdle[n]) -- crown: bezel
		add(tableRing[k], girdle[n], tableRing[n]) -- crown: star
		add(girdle[k], pavilion[k], girdle[n]) -- pavilion: upper
		add(pavilion[k], girdle[n], pavilion[n]) -- pavilion: upper
		add(pavilion[k], culet, pavilion[n]) -- pavilion: main
	end

	local sparkles = {}
	if cut >= 9 then
		local count = if cut >= 10 then 5 else 3
		for i = 1, count do
			local k = (i * 3) % sides + 1
			table.insert(sparkles, (tableRing[k] + girdle[k]) / 2 + Vector3.new(0, 0.05, 0))
		end
	end

	local specks = inclusions(rng, gem.Clarity, 0.6 * scale, shade.Color)
	if gem.Clarity >= 7 then
		-- Clear stones glow from within; the clearer, the brighter the core.
		table.insert(specks, {
			Position = Vector3.zero,
			Radius = 0.28 * scale,
			Color = shade.Color:Lerp(Color3.new(1, 1, 1), 0.25),
			Transparency = 0.75 - (math.clamp(gem.Clarity, 7, 10) - 7) * 0.1,
			Glow = true,
		})
	end
	return {
		Triangles = triangles,
		Transparency = transparencyFor(gem.Clarity) * 0.8,
		Material = "Glass",
		Specks = specks,
		Sparkles = sparkles,
		Radius = 1.1 * scale,
	}
end

function GemShapes.build(gem, detailed: boolean?)
	local shade = GemConfig.shade(gem)
	if gem.Cut then
		return cutStone(gem, shade, detailed == true)
	end
	return roughStone(gem, shade)
end

--[[
	Two wedges that together fill triangle a-b-c (the standard technique for
	drawing any triangle with Roblox parts). Returns two { CFrame, Size }.
]]
function GemShapes.wedges(a: Vector3, b: Vector3, c: Vector3, thickness: number)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Make b-c the longest edge.
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	return {
		CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back),
		Size = Vector3.new(thickness, height, math.abs(ab:Dot(back))),
	}, {
		CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		Size = Vector3.new(thickness, height, math.abs(ac:Dot(back))),
	}
end

return GemShapes

end)()

for _,element in {"Fire","Frost","Shock","Poison"} do
 print("GEM|"..element)
 local shape=GemShapes.build({Id="Site"..element,Element=element,Tier=1,Size=8,Clarity=8,Cut=10},true)
 for _,t in shape.Triangles do
  print(string.format("%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f",t.A.X,t.A.Y,t.A.Z,t.B.X,t.B.Y,t.B.Z,t.C.X,t.C.Y,t.C.Z,t.Color.R,t.Color.G,t.Color.B))
 end
end
