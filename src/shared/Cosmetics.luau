--[[
	Cosmetics: purely for looks, never stats. Rarity uses the gem tiers, so a
	rare trim glows in the same colour as a rare gem.

	  Trims   recolour your class glow (armor trim, eye slits, weapon edges).
	          Enchanted gear still takes on its gem's element.
	  Backs   something worn on your back: packs, banners, capes, wings, halos.
	  Skins   restyle whatever weapon you hold (a Palette, or a Look).
	  Suits   restyle your whole armor, every piece, whatever its style.
	  Titles  a tag over your head that everyone sees.

	How each is had:
	  Price      coins in the Shop (trims and back pieces)
	  Robux      sold for Robux, directly, never at random (Store.RobuxProducts
	             holds each one's Developer Product id; 0 = not on sale yet)
	  Exclusive  earned one way only, never sold, so it shows you did it:
	             "Invite"   bring friends (Shared.Referrals.Tiers)
	             "Group"    join the game's Roblox group (Shared.FreeRewards)
	             "Streak"   log in 7 days running (Shared.FreeRewards)
	             "Code"     a promo code (server Systems/Codes)
	             "Starter"  the one-time Starter Pack (Shared.Store)
	             "Season"   the Season Path's premium track (Shared.Season)
	  (none)     Geode Crates and the free Season Path

	Equipment draws them on your avatar.
]]
local GemConfig = require(script.Parent.GemConfig)

-- A skin's or suit's colours (Equipment repaints every part with them):
-- bright plates take Plate, dark ones and wood/leather Under, neon Glow.
export type Palette = {
	Plate: Color3,
	PlateMaterial: Enum.Material,
	Under: Color3,
	UnderMaterial: Enum.Material?,
	Glow: Color3,
	Reflect: number?, -- the plates' shine (0-1)
	Sparks: Color3?, -- particles drifting off it
	Trail: boolean?, -- (skins) a streak through every swing
}
export type Cosmetic = {
	Id: string,
	Kind: "Trim" | "Back" | "Skin" | "Suit" | "Title",
	Name: string,
	Description: string,
	Rarity: string, -- a gem tier: Common, Uncommon, Rare, UltraRare
	Price: number?, -- coins in the Shop
	Robux: number?, -- sold for Robux (see Store.RobuxProducts)
	Color: Color3, -- the trim colour, the back piece's glow, a title's colour
	Look: string?, -- how Equipment builds a back piece or applies a skin
	Palette: Palette?, -- a skin's or suit's colours
	Exclusive: string?, -- earned one way only (see above)
}

local Cosmetics = {}

Cosmetics.Order = {
	"TrimEmber",
	"TrimGlacier",
	"TrimVenom",
	"TrimStorm",
	"TrimAmethyst",
	"TrimRoseGold",
	"TrimPrismatic",
	"BackPack",
	"BackBanner",
	"BackGeode",
	"BackCape",
	"BackWings",
	"BackHalo",
}

Cosmetics.List = {
	TrimEmber = {
		Id = "TrimEmber",
		Kind = "Trim",
		Name = "Ember Trim",
		Description = "Glow like a banked forge.",
		Rarity = "Uncommon",
		Price = 300,
		Color = Color3.fromRGB(255, 120, 40),
	},
	TrimGlacier = {
		Id = "TrimGlacier",
		Kind = "Trim",
		Name = "Glacier Trim",
		Description = "Cold, clear blue from the northern peaks.",
		Rarity = "Uncommon",
		Price = 300,
		Color = Color3.fromRGB(130, 220, 255),
	},
	TrimVenom = {
		Id = "TrimVenom",
		Kind = "Trim",
		Name = "Venom Trim",
		Description = "A sickly green that warns people off.",
		Rarity = "Uncommon",
		Price = 300,
		Color = Color3.fromRGB(120, 255, 90),
	},
	TrimStorm = {
		Id = "TrimStorm",
		Kind = "Trim",
		Name = "Storm Trim",
		Description = "Crackling lightning yellow.",
		Rarity = "Rare",
		Price = 700,
		Color = Color3.fromRGB(255, 235, 60),
	},
	TrimAmethyst = {
		Id = "TrimAmethyst",
		Kind = "Trim",
		Name = "Amethyst Trim",
		Description = "Deep violet, cut from a flawless stone.",
		Rarity = "Rare",
		Price = 700,
		Color = Color3.fromRGB(190, 90, 255),
	},
	TrimRoseGold = {
		Id = "TrimRoseGold",
		Kind = "Trim",
		Name = "Rose Gold Trim",
		Description = "Warm metal for those who've made their fortune.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 160, 150),
	},
	TrimPrismatic = {
		Id = "TrimPrismatic",
		Kind = "Trim",
		Name = "Prismatic Trim",
		Description = "Every colour at once. Only the luckiest wear it.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 120, 230),
	},
	BackPack = {
		Id = "BackPack",
		Kind = "Back",
		Name = "Prospector's Pack",
		Description = "A sturdy pack with a pick strapped to the side.",
		Rarity = "Common",
		Price = 150,
		Color = Color3.fromRGB(0, 240, 255),
		Look = "Pack",
	},
	BackBanner = {
		Id = "BackBanner",
		Kind = "Back",
		Name = "War Banner",
		Description = "Your class colours, carried high.",
		Rarity = "Uncommon",
		Price = 450,
		Color = Color3.fromRGB(255, 200, 80),
		Look = "Banner",
	},
	BackGeode = {
		Id = "BackGeode",
		Kind = "Back",
		Name = "Geode Shell",
		Description = "A split geode, still glittering inside.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(170, 120, 255),
		Look = "Geode",
	},
	BackCape = {
		Id = "BackCape",
		Kind = "Back",
		Name = "Ember Cape",
		Description = "A long cape with a smouldering hem.",
		Rarity = "Rare",
		Price = 900,
		Color = Color3.fromRGB(255, 110, 40),
		Look = "Cape",
	},
	BackWings = {
		Id = "BackWings",
		Kind = "Back",
		Name = "Crystal Wings",
		Description = "Wings of living crystal. They don't fly. Yet.",
		Rarity = "Rare",
		Color = Color3.fromRGB(120, 240, 255),
		Look = "Wings",
	},
	BackHalo = {
		Id = "BackHalo",
		Kind = "Back",
		Name = "Gem Halo",
		Description = "A ring of perfect stones that follows you everywhere.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 220, 120),
		Look = "Halo",
	},
	-- Not in Order: these are never sold for coins or found in crates.
	SkinCrusader = {
		Id = "SkinCrusader",
		Kind = "Skin",
		Name = "Crusader Gold",
		Description = "Burnished gold and obsidian, white-hot edges and a trail of sparks. On any weapon.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 214, 110),
		Look = "Crusader",
		Exclusive = "Invite",
	},
	-- The bring-a-friend rewards (Shared.Referrals.Tiers) -------------------------
	BackStandard = {
		Id = "BackStandard",
		Kind = "Back",
		Name = "Crusader's Standard",
		Description = "A black war banner on an iron pole, edged in gold. Bring 3 friends.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 205, 90),
		Look = "Standard",
		Exclusive = "Invite",
	},
	SuitCrusader = {
		Id = "SuitCrusader",
		Kind = "Suit",
		Name = "Crusader Plate",
		Description = "White enamel and burnished gold on every piece you wear. Bring 5 friends.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 214, 110),
		Palette = {
			Plate = Color3.fromRGB(236, 232, 222),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(196, 150, 52),
			UnderMaterial = Enum.Material.Foil,
			Glow = Color3.fromRGB(255, 214, 110),
			Reflect = 0.15,
			Sparks = Color3.fromRGB(255, 226, 140),
		},
		Exclusive = "Invite",
	},
	TitleLegend = {
		Id = "TitleLegend",
		Kind = "Title",
		Name = "CRUSADER LEGEND",
		Description = "Over your head, in gold, for everyone to see. Bring 10 friends.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 205, 90),
		Exclusive = "Invite",
	},
	-- Free, one way each (Shared.FreeRewards, Systems/Codes) ----------------------
	SkinStarforged = {
		Id = "SkinStarforged",
		Kind = "Skin",
		Name = "Starforged",
		Description = "Pale star-metal with a white-blue edge. Join the group.",
		Rarity = "Rare",
		Color = Color3.fromRGB(190, 225, 255),
		Palette = {
			Plate = Color3.fromRGB(196, 212, 232),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(28, 40, 72),
			Glow = Color3.fromRGB(190, 225, 255),
			Reflect = 0.35,
			Sparks = Color3.fromRGB(220, 240, 255),
			Trail = true,
		},
		Exclusive = "Group",
	},
	SkinDaybreak = {
		Id = "SkinDaybreak",
		Kind = "Skin",
		Name = "Daybreak",
		Description = "Rose gold over dusk violet, glowing like sunrise. Log in 7 days running.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 160, 120),
		Palette = {
			Plate = Color3.fromRGB(232, 168, 140),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(60, 34, 84),
			Glow = Color3.fromRGB(255, 150, 110),
			Reflect = 0.2,
			Sparks = Color3.fromRGB(255, 196, 150),
			Trail = true,
		},
		Exclusive = "Streak",
	},
	TitleFounder = {
		Id = "TitleFounder",
		Kind = "Title",
		Name = "FOUNDER",
		Description = "You were here at the start. From a launch code.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(120, 230, 255),
		Exclusive = "Code",
	},
	-- Weapon skins for Robux --------------------------------------------------------
	SkinPlasma = {
		Id = "SkinPlasma",
		Kind = "Skin",
		Name = "Plasma Edge",
		Description = "Gunmetal with a cyan plasma edge that streaks through every swing.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(80, 230, 255),
		Palette = {
			Plate = Color3.fromRGB(70, 78, 92),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(22, 26, 34),
			Glow = Color3.fromRGB(80, 230, 255),
			Reflect = 0.25,
			Sparks = Color3.fromRGB(150, 245, 255),
			Trail = true,
		},
	},
	SkinMolten = {
		Id = "SkinMolten",
		Kind = "Skin",
		Name = "Molten Core",
		Description = "Cooling basalt split by rivers of lava. It drips embers.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(255, 120, 30),
		Palette = {
			Plate = Color3.fromRGB(46, 36, 34),
			PlateMaterial = Enum.Material.Basalt,
			Under = Color3.fromRGB(20, 16, 16),
			UnderMaterial = Enum.Material.Slate,
			Glow = Color3.fromRGB(255, 110, 20),
			Sparks = Color3.fromRGB(255, 160, 60),
			Trail = true,
		},
	},
	SkinToxic = {
		Id = "SkinToxic",
		Kind = "Skin",
		Name = "Toxic Ooze",
		Description = "Glowing green sludge over black steel. Handle with gloves.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(140, 255, 90),
		Palette = {
			Plate = Color3.fromRGB(88, 190, 70),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(18, 24, 20),
			Glow = Color3.fromRGB(150, 255, 90),
			Reflect = 0.3,
			Sparks = Color3.fromRGB(170, 255, 120),
			Trail = true,
		},
	},
	SkinVoid = {
		Id = "SkinVoid",
		Kind = "Skin",
		Name = "Void Crystal",
		Description = "A blade of violet crystal with a magenta heart.",
		Rarity = "UltraRare",
		Robux = 149,
		Color = Color3.fromRGB(220, 90, 255),
		Palette = {
			Plate = Color3.fromRGB(120, 70, 200),
			PlateMaterial = Enum.Material.Glass,
			Under = Color3.fromRGB(26, 14, 40),
			Glow = Color3.fromRGB(230, 90, 255),
			Reflect = 0.4,
			Sparks = Color3.fromRGB(240, 170, 255),
			Trail = true,
		},
	},
	SkinGalaxy = {
		Id = "SkinGalaxy",
		Kind = "Skin",
		Name = "Galaxy",
		Description = "Deep space in steel: a night-blue blade full of drifting stars.",
		Rarity = "UltraRare",
		Robux = 199,
		Color = Color3.fromRGB(150, 140, 255),
		Palette = {
			Plate = Color3.fromRGB(34, 30, 92),
			PlateMaterial = Enum.Material.Glass,
			Under = Color3.fromRGB(10, 10, 26),
			Glow = Color3.fromRGB(255, 120, 220),
			Reflect = 0.5,
			Sparks = Color3.fromRGB(230, 230, 255),
			Trail = true,
		},
	},
	-- Armor suits for Robux -------------------------------------------------------------
	SuitChrome = {
		Id = "SuitChrome",
		Kind = "Suit",
		Name = "Chrome Knight",
		Description = "Mirror chrome on every plate, a cold cyan glow underneath.",
		Rarity = "Rare",
		Robux = 299,
		Color = Color3.fromRGB(110, 230, 255),
		Palette = {
			Plate = Color3.fromRGB(214, 220, 228),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(44, 48, 58),
			Glow = Color3.fromRGB(110, 230, 255),
			Reflect = 0.6,
		},
	},
	SuitArctic = {
		Id = "SuitArctic",
		Kind = "Suit",
		Name = "Arctic Ops",
		Description = "Snow-white plates and ice-blue seams. Frost drifts off you.",
		Rarity = "Rare",
		Robux = 299,
		Color = Color3.fromRGB(170, 230, 255),
		Palette = {
			Plate = Color3.fromRGB(238, 244, 250),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(120, 170, 210),
			Glow = Color3.fromRGB(180, 240, 255),
			Reflect = 0.1,
			Sparks = Color3.fromRGB(230, 248, 255),
		},
	},
	SuitObsidian = {
		Id = "SuitObsidian",
		Kind = "Suit",
		Name = "Obsidian Lava",
		Description = "Black volcanic glass, cracked through with lava. Embers rise off it.",
		Rarity = "UltraRare",
		Robux = 399,
		Color = Color3.fromRGB(255, 110, 20),
		Palette = {
			Plate = Color3.fromRGB(30, 26, 28),
			PlateMaterial = Enum.Material.Basalt,
			Under = Color3.fromRGB(14, 12, 12),
			UnderMaterial = Enum.Material.Slate,
			Glow = Color3.fromRGB(255, 110, 20),
			Sparks = Color3.fromRGB(255, 150, 50),
		},
	},
	SuitNeon = {
		Id = "SuitNeon",
		Kind = "Suit",
		Name = "Neon Runner",
		Description = "Matte black, outlined in hot magenta light.",
		Rarity = "UltraRare",
		Robux = 399,
		Color = Color3.fromRGB(255, 60, 200),
		Palette = {
			Plate = Color3.fromRGB(24, 22, 30),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(10, 10, 14),
			Glow = Color3.fromRGB(255, 60, 200),
			Reflect = 0.25,
		},
	},
	SuitRoyal = {
		Id = "SuitRoyal",
		Kind = "Suit",
		Name = "Royal Gold",
		Description = "Polished gold over royal violet. Nobody misses you walking in.",
		Rarity = "UltraRare",
		Robux = 799,
		Color = Color3.fromRGB(255, 220, 120),
		Palette = {
			Plate = Color3.fromRGB(230, 184, 70),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(70, 30, 110),
			UnderMaterial = Enum.Material.Fabric,
			Glow = Color3.fromRGB(255, 236, 170),
			Reflect = 0.3,
			Sparks = Color3.fromRGB(255, 230, 150),
		},
	},
	-- The Starter Pack's own suit (Store.StarterPack) -----------------------------------------
	SuitIgnition = {
		Id = "SuitIgnition",
		Kind = "Suit",
		Name = "Ignition",
		Description = "Racing red and carbon black with a white-hot trim. Starter Pack only.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 70, 50),
		Palette = {
			Plate = Color3.fromRGB(200, 34, 30),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(22, 22, 26),
			Glow = Color3.fromRGB(255, 220, 190),
			Reflect = 0.3,
		},
		Exclusive = "Starter",
	},
	-- The Season Path's premium track (Season.Premium) ----------------------------------------
	SkinLunar = {
		Id = "SkinLunar",
		Kind = "Skin",
		Name = "Moonsteel",
		Description = "Silver from the lunar frontier with a pale blue edge. Season 1 premium.",
		Rarity = "Rare",
		Color = Color3.fromRGB(190, 210, 255),
		Palette = {
			Plate = Color3.fromRGB(200, 204, 214),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(50, 56, 72),
			Glow = Color3.fromRGB(180, 210, 255),
			Reflect = 0.45,
			Trail = true,
		},
		Exclusive = "Season",
	},
	TitleLunar = {
		Id = "TitleLunar",
		Kind = "Title",
		Name = "LUNAR VANGUARD",
		Description = "Season 1 premium.",
		Rarity = "Rare",
		Color = Color3.fromRGB(180, 210, 255),
		Exclusive = "Season",
	},
	SuitLunar = {
		Id = "SuitLunar",
		Kind = "Suit",
		Name = "Lunar Frontier",
		Description = "Moon-white plates with crater-grey seams and a blue glow. Season 1 premium, level 30.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(170, 200, 255),
		Palette = {
			Plate = Color3.fromRGB(226, 228, 236),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(90, 94, 108),
			UnderMaterial = Enum.Material.Slate,
			Glow = Color3.fromRGB(150, 190, 255),
			Reflect = 0.15,
			Sparks = Color3.fromRGB(210, 225, 255),
		},
		Exclusive = "Season",
	},
} :: { [string]: Cosmetic }

function Cosmetics.get(id: any): Cosmetic?
	return if typeof(id) == "string" then Cosmetics.List[id] else nil
end

function Cosmetics.rarityColor(cosmetic: Cosmetic): Color3
	return GemConfig.TierColors[cosmetic.Rarity]
end

function Cosmetics.rarityName(cosmetic: Cosmetic): string
	return GemConfig.TierLabels[cosmetic.Rarity]
end

-- Every cosmetic of a kind, in the order the Shop shows them: on sale first
-- (cheapest first), then the exclusives.
function Cosmetics.ofKind(kind: string): { string }
	local ids = {}
	for id, cosmetic in Cosmetics.List do
		if cosmetic.Kind == kind then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local x, y = Cosmetics.List[a], Cosmetics.List[b]
		local xs, ys = if x.Exclusive then 1 else 0, if y.Exclusive then 1 else 0
		if xs ~= ys then
			return xs < ys
		end
		local xp, yp = x.Robux or x.Price or 0, y.Robux or y.Price or 0
		if xp ~= yp then
			return xp < yp
		end
		return x.Name < y.Name
	end)
	return ids
end

-- How to get one you don't own, in a few words for the Shop.
Cosmetics.SourceText = {
	Invite = "Bring friends",
	Group = "Join the group",
	Streak = "7-day login streak",
	Code = "Promo code",
	Starter = "Starter Pack",
	Season = "Season premium",
}
function Cosmetics.source(cosmetic: Cosmetic): string
	if cosmetic.Exclusive then
		return Cosmetics.SourceText[cosmetic.Exclusive] or "Exclusive"
	elseif cosmetic.Robux then
		return string.format("R$ %d", cosmetic.Robux)
	elseif cosmetic.Price then
		return string.format("%d coins", cosmetic.Price)
	end
	return "Crates and Season Path"
end

return Cosmetics
