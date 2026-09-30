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

local Store = {}

Store.Tabs = { "Featured", "Bundles", "Backs", "Trims", "Passes" }
Store.TabNames = {
	Featured = "⭐ Featured",
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
		Tagline = "Everything a new miner needs. Once only.",
		Price = 150,
		Value = "5X VALUE",
		Color = Color3.fromRGB(0, 170, 190),
		Icon = "🎁",
		NewPlayersOnly = true,
		Contents = {
			Stones = 3,
			Materials = { Iron = 15, Timber = 15, Leather = 10, Cloth = 10 },
			Cosmetics = { "BackBanner" },
			Crates = { GeodeCrate = 2 },
			XPBoostMinutes = 60,
		},
	},
	{
		Id = "Prospector",
		Name = "Prospector Bundle",
		Tagline = "Stones, a pack and a crate to crack.",
		Price = 400,
		Value = "3X VALUE",
		Color = Color3.fromRGB(40, 140, 170),
		Icon = "⛏️",
		Contents = { Stones = 4, Cosmetics = { "BackPack" }, Crates = { GeodeCrate = 1 } },
	},
	{
		Id = "Forgemaster",
		Name = "Forgemaster Bundle",
		Tagline = "Mithril, shards and Marks for serious crafting.",
		Price = 1200,
		Value = "4X VALUE",
		Color = Color3.fromRGB(190, 110, 40),
		Icon = "⚒️",
		Contents = { Marks = 250, Materials = { Mithril = 10, Shards = 30, Iron = 20 } },
	},
	{
		Id = "Legend",
		Name = "Legend Bundle",
		Tagline = "Crystal Wings, Storm Trim and a double-XP hour.",
		Price = 3000,
		Value = "5X VALUE",
		Color = Color3.fromRGB(150, 70, 220),
		Icon = "👑",
		Contents = {
			Cosmetics = { "BackWings", "TrimStorm" },
			Crates = { GeodeCrate = 2, MasterworkCrate = 1 },
			XPBoostMinutes = 60,
		},
	},
} :: { Bundle }

Store.Crates = {
	GeodeCrate = {
		Id = "GeodeCrate",
		Name = "Geode Crate",
		Description = "Crack it open: stones, materials, Marks, a cut gem or a cosmetic.",
		Price = 250,
		Color = Color3.fromRGB(80, 170, 200),
		Icon = "⛏️",
		Rolls = {
			{ Weight = 38, Reward = { Stones = 2 } },
			{ Weight = 24, Reward = { Materials = { Iron = 10, Timber = 10, Leather = 8, Cloth = 8 } } },
			{ Weight = 15, Reward = { Marks = 150 } },
			{ Weight = 11, Reward = { CutGems = 1 } },
			{ Weight = 6, Cosmetic = "Uncommon" },
			{ Weight = 4, Cosmetic = "Rare" },
			{ Weight = 2, Cosmetic = "UltraRare" },
		},
	},
	MasterworkCrate = {
		Id = "MasterworkCrate",
		Name = "Masterwork Crate",
		Description = "For the forge: mithril, shards, gems, and better odds on rare cosmetics.",
		Price = 800,
		Color = Color3.fromRGB(230, 150, 50),
		Icon = "💎",
		Rolls = {
			{ Weight = 30, Reward = { Materials = { Mithril = 6, Shards = 15 } } },
			{ Weight = 22, Reward = { CutGems = 2 } },
			{ Weight = 18, Reward = { Marks = 400 } },
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

-- Developer Product ids, to also sell bundles and crates for Robux (0 = off).
Store.RobuxProducts = {
	Welcome = 0,
	Prospector = 0,
	Forgemaster = 0,
	Legend = 0,
	GeodeCrate = 0,
	MasterworkCrate = 0,
}
-- Shown next to the Robux button when the product is on.
Store.RobuxPrices =
	{ Welcome = 99, Prospector = 149, Forgemaster = 399, Legend = 999, GeodeCrate = 49, MasterworkCrate = 149 }

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
		add("Stones", nil, reward.Stones, if reward.Stones == 1 then "Rough Stone" else "Rough Stones")
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
		table.insert(lines, string.format("%d rough stone%s", reward.Stones, if reward.Stones == 1 then "" else "s"))
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
