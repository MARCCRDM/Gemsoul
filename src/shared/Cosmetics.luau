--[[
	Cosmetics: purely for looks. Rarity uses the gem tiers, so a rare trim
	glows in the same colour as a rare gem.

	  Trims  recolour your class glow (armor trim, eye slits, weapon edges).
	         Enchanted gear still takes on its gem's element.
	  Backs  something worn on your back: packs, banners, capes, wings, halos.

	Some are sold in the Shop for coins; the rest come from Geode Crates and
	the Season Path. Equipment draws them on your avatar.
]]
local GemConfig = require(script.Parent.GemConfig)

export type Cosmetic = {
	Id: string,
	Kind: "Trim" | "Back",
	Name: string,
	Description: string,
	Rarity: string, -- a gem tier: Common, Uncommon, Rare, UltraRare
	Price: number?, -- coins in the Shop; nil = crate / season only
	Color: Color3, -- the trim colour, or the back piece's glow
	Look: string?, -- how Equipment builds a back piece
	Exclusive: string?, -- earned one way only ("Referral": Shared.Referrals); never in crates
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
	"BackComrade",
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
	BackComrade = {
		Id = "BackComrade",
		Kind = "Back",
		Name = "Comrade Wings",
		Description = "Earned by bringing a friend into the Saga. Only recruiters wear these.",
		Rarity = "Rare",
		Color = Color3.fromRGB(60, 210, 240),
		Look = "Wings",
		Exclusive = "Referral",
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

return Cosmetics
