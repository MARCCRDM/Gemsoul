--[[
	What the Shop sells. Everything is priced in coins so it works today.

	Robux-ready: to also sell a bundle for Robux, create a Developer Product
	on your game's page on Roblox, then put its id in RobuxProducts below
	(0 means off). The Shop then shows a Robux button, and the server grants
	the bundle when the purchase goes through (see server Systems/Store).

	A Reward is any mix of:
	  Coins, Marks, Stones (rough), CutGems, Materials = { Iron = 10, ... },
	  Cosmetics = { id, ... }, Crates = { GeodeCrate = 2 }, XPBoostMinutes
]]
export type Reward = {
	Coins: number?,
	Marks: number?,
	Stones: number?,
	CutGems: number?,
	Materials: { [string]: number }?,
	Cosmetics: { string }?,
	Crates: { [string]: number }?,
	XPBoostMinutes: number?,
}
export type Bundle = {
	Id: string,
	Name: string,
	Tagline: string,
	Price: number, -- coins
	Value: string, -- the "5X VALUE" tag
	Color: Color3,
	Icon: string,
	Contents: Reward,
	NewPlayersOnly: boolean?,
}
export type CrateRoll = { Weight: number, Reward: Reward?, Cosmetic: string? }
export type Crate = {
	Id: string,
	Name: string,
	Description: string,
	Price: number,
	Color: Color3,
	Icon: string,
	Rolls: { CrateRoll },
}

local Cosmetics = require(script.Parent.Cosmetics)

local Store = {}

Store.Tabs = { "Featured", "Free", "Skins", "Suits", "Picks", "Bundles", "Backs", "Trims", "Passes" }
Store.TabNames = {
	Featured = "⭐ Featured",
	Free = "🎁 Free",
	Skins = "⚔️ Weapon Skins",
	Suits = "🛡️ Suits",
	Picks = "⛏️ Pickaxes",
	Bundles = "🎁 Bundles",
	Backs = "🎒 Back Pieces",
	Trims = "✨ Trims",
	Passes = "👑 Passes",
}

-- New players can buy the Welcome Bundle once, within this long of joining.
Store.WelcomeHours = 24

Store.Bundles = {
	{
		Id = "Welcome",
		Name = "Welcome Bundle",
		Tagline = "A colony banner and an hour of expedition XP. Once only.",
		Price = 150,
		Value = "EXPEDITION",
		Color = Color3.fromRGB(0, 170, 190),
		Icon = "🎁",
		NewPlayersOnly = true,
		Contents = {
			Cosmetics = { "BackBanner" },
			XPBoostMinutes = 60,
		},
	},
	{
		Id = "Prospector",
		Name = "Prospector Bundle",
		Tagline = "A survey pack and matching station trim.",
		Price = 400,
		Value = "STYLE KIT",
		Color = Color3.fromRGB(40, 140, 170),
		Icon = "⛏️",
		Contents = { Cosmetics = { "BackPack", "TrimEmber" } },
	},
	{
		Id = "Forgemaster",
		Name = "Station Specialist Bundle",
		Tagline = "Geode back piece and radiant trim. Equipment is earned in expeditions.",
		Price = 1200,
		Value = "STYLE KIT",
		Color = Color3.fromRGB(190, 110, 40),
		Icon = "⚒️",
		Contents = { Cosmetics = { "BackGeode", "TrimRoseGold" } },
	},
	{
		Id = "Legend",
		Name = "Legend Bundle",
		Tagline = "Crystal Wings, Storm Trim and a double-XP hour.",
		Price = 3000,
		Value = "EXPEDITION",
		Color = Color3.fromRGB(150, 70, 220),
		Icon = "👑",
		Contents = {
			Cosmetics = { "BackWings", "TrimStorm" },
			XPBoostMinutes = 60,
		},
	},
} :: { Bundle }

Store.Crates = {
	GeodeCrate = {
		Id = "GeodeCrate",
		Name = "Geode Crate",
		Description = "Recovered expedition cache: ready gems, credits or station cosmetics.",
		Price = 250,
		Color = Color3.fromRGB(80, 170, 200),
		Icon = "⛏️",
		Rolls = {
			{ Weight = 38, Reward = { Stones = 2 } },
			{ Weight = 24, Reward = { Coins = 160 } },
			{ Weight = 11, Reward = { Coins = 150 } },
			{ Weight = 11, Reward = { CutGems = 1 } },
			{ Weight = 4, Cosmetic = "Common" },
			{ Weight = 6, Cosmetic = "Uncommon" },
			{ Weight = 4, Cosmetic = "Rare" },
			{ Weight = 2, Cosmetic = "UltraRare" },
		},
	},
	MasterworkCrate = {
		Id = "MasterworkCrate",
		Name = "Masterwork Crate",
		Description = "Deep-space cache: ready gems, credits and rare station cosmetics.",
		Price = 800,
		Color = Color3.fromRGB(230, 150, 50),
		Icon = "💎",
		Rolls = {
			{ Weight = 30, Reward = { Coins = 450 } },
			{ Weight = 22, Reward = { CutGems = 2 } },
			{ Weight = 18, Reward = { Coins = 400 } },
			{ Weight = 14, Cosmetic = "Rare" },
			{ Weight = 10, Reward = { Stones = 5 } },
			{ Weight = 6, Cosmetic = "UltraRare" },
		},
	},
} :: { [string]: Crate }
Store.CrateOrder = { "GeodeCrate", "MasterworkCrate" }

-- Buying in bulk is cheaper: count -> price multiplier.
Store.CrateBulk = { [1] = 1, [5] = 4.5, [10] = 8.5 }

function Store.cratePrice(crate: Crate, count: number): number?
	local mult = Store.CrateBulk[count]
	return if mult then math.floor(crate.Price * mult) else nil
end

-- A cosmetic you already own becomes this many coins instead.
Store.DuplicateRefund = 120

-- What sells for Robux: direct purchases only, never random (crates use
-- earned coins). Each key needs its own Developer Product: create it on the
-- game's page on Roblox (Monetization > Developer Products) at the price in
-- RobuxPrices, and paste its id here. 0 = not on sale yet (the Shop shows
-- the price, greyed out). Keys are bundle ids, cosmetic ids (Cosmetics with
-- a Robux price), StarterPack and SeasonPremium.
Store.RobuxProducts = {
	Welcome = 0,
	Prospector = 0,
	Forgemaster = 0,
	Legend = 0,
	-- Weapon skins
	SkinPlasma = 0,
	SkinMolten = 0,
	SkinToxic = 0,
	SkinVoid = 0,
	SkinGalaxy = 0,
	SkinGlacier = 0,
	SkinBonk = 0,
	SkinBanana = 0,
	SkinSolar = 0,
	-- Armor suits
	SuitChrome = 0,
	SuitArctic = 0,
	SuitObsidian = 0,
	SuitNeon = 0,
	SuitRoyal = 0,
	SuitStealth = 0,
	SuitStorm = 0,
	SuitBiohazard = 0,
	-- Pickaxe skins
	PickMagma = 0,
	PickStorm = 0,
	PickVoid = 0,
	PickGlacier = 0,
	PickPrism = 0,
	PickNeon = 0,
	-- One-time offers and passes
	StarterPack = 0,
	SeasonPremium = 0,
}
-- The Robux price of each (shown on its button). A cosmetic's price is on
-- the cosmetic itself (Cosmetics, Robux).
Store.RobuxPrices = {
	Welcome = 99,
	Prospector = 149,
	Forgemaster = 399,
	Legend = 999,
	GeodeCrate = 49,
	MasterworkCrate = 149,
	StarterPack = 99,
	SeasonPremium = 399,
}

-- The Starter Pack: offered once, right after your first win, for 48 hours.
-- Its suit is only ever in this pack.
Store.StarterPack = {
	Id = "StarterPack",
	Name = "Starter Pack",
	Tagline = "Your first win deserves a look. One time only.",
	Hours = 48,
	Value = "5X VALUE",
	Contents = {
		Cosmetics = { "SuitIgnition", "SkinMolten", "TrimEmber" },
		Crates = { GeodeCrate = 3 },
		Coins = 1000,
	},
}

-- The Robux price of a product key (a cosmetic's own, or RobuxPrices).
function Store.robuxPrice(key: string): number?
	local cosmetic = Cosmetics.get(key)
	return if cosmetic and cosmetic.Robux then cosmetic.Robux else Store.RobuxPrices[key]
end

-- The product key a Developer Product id buys (nil if it isn't ours).
function Store.productKey(productId: number): string?
	for key, id in Store.RobuxProducts do
		if id ~= 0 and id == productId then
			return key
		end
	end
	return nil
end

-- Is the Starter Pack still on offer? (Offered at `offeredAt`, os.time.)
function Store.starterOpen(offeredAt: number?, bought: boolean?, now: number): boolean
	return not bought
		and type(offeredAt) == "number"
		and offeredAt > 0
		and now < offeredAt + Store.StarterPack.Hours * 3600
end

function Store.bundle(id: any): Bundle?
	for _, bundle in Store.Bundles do
		if bundle.Id == id then
			return bundle
		end
	end
	return nil
end

-- Lines describing a reward, for bundle cards and "you got" messages.
export type RewardItem = { Kind: string, Id: string?, Count: number?, Text: string }

-- A reward as separate pieces (for drawing a tile per piece).
function Store.items(reward: Reward, cosmeticName: ((string) -> string)?): { RewardItem }
	local items = {}
	local function add(kind: string, id: string?, count: number?, label: string)
		table.insert(items, { Kind = kind, Id = id, Count = count, Text = label })
	end
	if reward.Coins then
		add("Coins", nil, reward.Coins, "Coins")
	end
	if reward.Marks then
		add("Marks", nil, reward.Marks, "Guild Marks")
	end
	if reward.Stones then
		add("Stones", nil, reward.Stones, if reward.Stones == 1 then "Ready Gem" else "Ready Gems")
	end
	if reward.CutGems then
		add("CutGems", nil, reward.CutGems, if reward.CutGems == 1 then "Cut Gem" else "Cut Gems")
	end
	local materials = {}
	for id in reward.Materials or {} do
		table.insert(materials, id)
	end
	table.sort(materials)
	for _, id in materials do
		add("Materials", id, (reward.Materials :: any)[id], id)
	end
	for id, count in reward.Crates or {} do
		local crate = Store.Crates[id]
		add("Crates", id, count, if crate then crate.Name else id)
	end
	for _, id in reward.Cosmetics or {} do
		add("Cosmetic", id, nil, if cosmeticName then cosmeticName(id) else id)
	end
	if reward.XPBoostMinutes then
		add("XPBoost", nil, nil, string.format("2x XP  %d min", reward.XPBoostMinutes))
	end
	return items
end

function Store.describe(reward: Reward, cosmeticName: ((string) -> string)?): { string }
	local lines = {}
	if reward.Coins then
		table.insert(lines, string.format("%d coins", reward.Coins))
	end
	if reward.Marks then
		table.insert(lines, string.format("%d Guild Marks", reward.Marks))
	end
	if reward.Stones then
		table.insert(lines, string.format("%d ready gem%s", reward.Stones, if reward.Stones == 1 then "" else "s"))
	end
	if reward.CutGems then
		table.insert(lines, string.format("%d cut gem%s", reward.CutGems, if reward.CutGems == 1 then "" else "s"))
	end
	for id, count in reward.Materials or {} do
		table.insert(lines, string.format("%d %s", count, id))
	end
	for _, id in reward.Cosmetics or {} do
		table.insert(lines, if cosmeticName then cosmeticName(id) else id)
	end
	for id, count in reward.Crates or {} do
		local crate = Store.Crates[id]
		table.insert(lines, string.format("%d %s", count, if crate then crate.Name else id))
	end
	if reward.XPBoostMinutes then
		table.insert(lines, string.format("2x XP for %d min", reward.XPBoostMinutes))
	end
	return lines
end

return Store
