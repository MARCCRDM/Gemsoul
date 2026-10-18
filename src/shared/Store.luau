--[[
	The store: weapon skins, suits, pickaxes and bundles, sold for Robux,
	plus the Free rewards. Looks only, never stats. (PROBE-7's swing refills
	are Robux products too: Shared.Outpost.Refills, sold at the Probe.)

	  Bundles      new-player offers (the Welcome Kit, the Starter Pack), the
	               squad kits (one, two or all three miners), themed
	               collections, and the premium sets (Royal Treasury, The
	               Vault: everything in the store)
	  Weapon Skins, Suits, Pickaxes
	               every look sold on its own (Cosmetics, Robux)
	  Free         the group, friends, the login streak and promo codes

	Trims and back pieces aren't sold on their own: they come as extras in
	bundles (and on the Season Path). Nothing random is sold.

	Robux: every product key below needs a Developer Product. Create it on
	the game's page on Roblox (Monetization > Developer Products) at the
	price shown (a cosmetic's own Robux, or RobuxPrices), and paste its id
	in RobuxProducts (0 = not on sale yet). The server grants it when the
	purchase goes through (server Systems/StoreServer), once per receipt.
	While testing (Config.TestCosmeticPrice), anything for sale can also be
	bought for that many coins, through the same grant.

	A Reward is any mix of:
	  Coins, Cosmetics = { id, ... }, XPBoostMinutes, Swings (a refill's)
	  (and, from old saves and season tracks: Marks, Stones, CutGems,
	  Materials)
]]
export type Reward = {
	Coins: number?,
	Marks: number?,
	Stones: number?,
	CutGems: number?,
	Materials: { [string]: number }?,
	Cosmetics: { string }?,
	XPBoostMinutes: number?,
	Swings: number?,
}
export type Bundle = {
	Id: string,
	Name: string,
	Tagline: string,
	Section: string, -- "Offer", "Collection" or "Premium"
	Color: Color3,
	Hero: string, -- the cosmetic shown big on its card
	Contents: Reward,
	NewPlayersOnly: boolean?, -- the Welcome Kit: within WelcomeHours of joining, once
	Once: string?, -- bought once per account (the profile flag that records it)
}
export type Kit = {
	Id: string,
	Name: string,
	Style: string, -- the fighting style it's themed on (the intro's styles)
	Tagline: string,
	Color: Color3,
	Contents: Reward,
}

local Config = require(script.Parent.Config)
local Cosmetics = require(script.Parent.Cosmetics)
local Outpost = require(script.Parent.Outpost)

local Store = {}

Store.Tabs = { "Bundles", "Skins", "Suits", "Helmets", "Visors", "Picks", "Free" }
Store.TabNames = {
	Bundles = "Bundles",
	Skins = "Weapon Skins",
	Suits = "Suits",
	Helmets = "Helmets",
	Visors = "Visors",
	Picks = "Pickaxes",
	Free = "Free",
}
-- The cosmetic kind each catalog tab sells.
Store.TabKinds = { Skins = "Skin", Suits = "Suit", Helmets = "Helmet", Visors = "Visor", Picks = "Pick" }

-- New players can buy the Welcome Kit once, within this long of joining.
Store.WelcomeHours = 24

-- Bundles ---------------------------------------------------------------------------------------------

Store.Bundles = {
	{
		Id = "Welcome",
		Name = "Welcome Kit",
		Tagline = "A full camo look, a war banner and an hour of double XP. For new miners, once.",
		Section = "Offer",
		Color = Color3.fromRGB(0, 170, 190),
		Hero = "SuitCamo",
		NewPlayersOnly = true,
		Contents = {
			Cosmetics = { "SuitCamo", "SkinCamo", "BackBanner" },
			XPBoostMinutes = 60,
		},
	},
	{
		Id = "Rustbucket",
		Name = "Rustbucket Set",
		Tagline = "Scrapyard chic: a rusted rig, a matching blade and a survey pack.",
		Section = "Collection",
		Color = Color3.fromRGB(196, 110, 58),
		Hero = "SuitRust",
		Contents = { Cosmetics = { "SuitRust", "SkinRust", "BackPack" } },
	},
	{
		Id = "Brainrot",
		Name = "Brainrot Duo",
		Tagline = "Two of the silliest weapons in the arena. Bonk them both.",
		Section = "Collection",
		Color = Color3.fromRGB(255, 196, 64),
		Hero = "SkinBanana",
		Contents = { Cosmetics = { "SkinBanana", "SkinBonk" } },
	},
	{
		Id = "Circuit",
		Name = "Circuit & Copper",
		Tagline = "Two wired-up looks, suit and blade each: circuit green and copper coil.",
		Section = "Collection",
		Color = Color3.fromRGB(60, 200, 140),
		Hero = "SuitCircuit",
		Contents = { Cosmetics = { "SuitCircuit", "SkinCircuit", "SuitCopper", "SkinCopper" } },
	},
	{
		Id = "DeepSpace",
		Name = "Deep Space Set",
		Tagline = "Nebula suit and blade, a void crystal edge and the Void Reaper pick.",
		Section = "Collection",
		Color = Color3.fromRGB(130, 90, 255),
		Hero = "SuitNebula",
		Contents = { Cosmetics = { "SuitNebula", "SkinNebula", "SkinVoid", "PickVoid" } },
	},
	{
		Id = "SolarForge",
		Name = "Solar Forge Set",
		Tagline = "Obsidian plate, the Solar Flare blade and the Magma Heart pick.",
		Section = "Collection",
		Color = Color3.fromRGB(255, 120, 40),
		Hero = "SuitObsidian",
		Contents = { Cosmetics = { "SuitObsidian", "SkinSolar", "PickMagma" } },
	},
	{
		Id = "Royal",
		Name = "Royal Treasury",
		Tagline = "Royal Gold plate and six more looks, the Ember Cape, 5,000 coins and a day of double XP.",
		Section = "Premium",
		Color = Color3.fromRGB(255, 200, 80),
		Hero = "SuitRoyal",
		Contents = {
			Cosmetics = {
				"SuitRoyal",
				"SuitChrome",
				"SuitStealth",
				"SkinGalaxy",
				"PickStorm",
				"PickPrism",
				"PickGilded",
				"BackCape",
			},
			Coins = 5000,
			XPBoostMinutes = 1440,
		},
	},
	{
		Id = "Vault",
		Name = "The Vault",
		Tagline = "Every weapon skin, suit, helmet, visor and pickaxe in the store, every bundle extra, the COLLECTOR title and 10,000 coins.",
		Section = "Premium",
		Color = Color3.fromRGB(255, 214, 120),
		Hero = "SkinSolar",
		Once = "VaultBought",
		Contents = { Cosmetics = {}, Coins = 10000, XPBoostMinutes = 1440 }, -- (filled in below)
	},
} :: { Bundle }

-- Squad kits: one look per fighting style (a suit, a weapon skin, a pickaxe
-- and a trim). Buy one, two or all three: each goes on one of your miners.
Store.Kits = {
	{
		Id = "Prospector",
		Name = "Toxic Prospector",
		Style = "Prospector",
		Tagline = "Steady and hard to put down.",
		Color = Color3.fromRGB(120, 220, 90),
		Contents = { Cosmetics = { "SuitBiohazard", "SkinToxic", "PickGeode", "TrimVenom" } },
	},
	{
		Id = "Skirmisher",
		Name = "Storm Skirmisher",
		Style = "Skirmisher",
		Tagline = "In and out before the thunder.",
		Color = Color3.fromRGB(90, 170, 255),
		Contents = { Cosmetics = { "SuitStorm", "SkinPlasma", "PickNeon", "TrimStorm" } },
	},
	{
		Id = "Juggernaut",
		Name = "Glacier Juggernaut",
		Style = "Juggernaut",
		Tagline = "Cold, heavy and unmovable.",
		Color = Color3.fromRGB(150, 225, 255),
		Contents = { Cosmetics = { "SuitArctic", "SkinGlacier", "PickGlacier", "TrimGlacier" } },
	},
} :: { Kit }
-- One kit, two or all three.
Store.KitPrices = { 349, 599, 799 }
-- All three: the squad's own title too.
Store.SquadBonus = { Cosmetics = { "TitleSquad" } }

-- The Starter Pack: offered once, right after your first win, for 48 hours.
-- Its suit is only ever in this pack.
Store.StarterPack = {
	Id = "StarterPack",
	Name = "Starter Pack",
	Tagline = "Your first win deserves a look: a suit you can't get anywhere else, two more looks and coins.",
	Section = "Offer",
	Color = Color3.fromRGB(255, 96, 64),
	Hero = "SuitIgnition",
	Hours = 48,
	Contents = {
		Cosmetics = { "SuitIgnition", "SkinMolten", "PickBone", "TrimEmber" },
		Coins = 1000,
	},
}

-- Robux --------------------------------------------------------------------------------------------------

-- Each product's Developer Product id (0 = not on sale yet).
Store.RobuxProducts = {
	-- Bundles
	Welcome = 0,
	Rustbucket = 0,
	Brainrot = 0,
	Circuit = 0,
	DeepSpace = 0,
	SolarForge = 0,
	Royal = 0,
	Vault = 0,
	-- Squad kits: one, two or all three
	KitProspector = 0,
	KitSkirmisher = 0,
	KitJuggernaut = 0,
	KitProspectorSkirmisher = 0,
	KitProspectorJuggernaut = 0,
	KitSkirmisherJuggernaut = 0,
	KitProspectorSkirmisherJuggernaut = 0,
	-- Weapon skins
	SkinRust = 0,
	SkinCamo = 0,
	SkinCopper = 0,
	SkinPlasma = 0,
	SkinMolten = 0,
	SkinToxic = 0,
	SkinGlacier = 0,
	SkinCircuit = 0,
	SkinVoid = 0,
	SkinBonk = 0,
	SkinBanana = 0,
	SkinGalaxy = 0,
	SkinNebula = 0,
	SkinSolar = 0,
	-- Suits
	SuitRust = 0,
	SuitCamo = 0,
	SuitCopper = 0,
	SuitStealth = 0,
	SuitCircuit = 0,
	SuitChrome = 0,
	SuitArctic = 0,
	SuitStorm = 0,
	SuitBiohazard = 0,
	SuitObsidian = 0,
	SuitNeon = 0,
	SuitNebula = 0,
	SuitRoyal = 0,
	-- Pickaxes
	PickBone = 0,
	PickNeon = 0,
	PickGeode = 0,
	PickGlacier = 0,
	PickPrism = 0,
	PickGilded = 0,
	PickMagma = 0,
	PickStorm = 0,
	PickVoid = 0,
	-- Visors
	VisorTangerine = 0,
	VisorRose = 0,
	VisorGoldMirror = 0,
	VisorLime = 0,
	VisorHotPink = 0,
	VisorHeartbeat = 0,
	VisorScanner = 0,
	VisorTwilight = 0,
	VisorThermal = 0,
	VisorCryo = 0,
	VisorIon = 0,
	VisorToxic = 0,
	VisorAurora = 0,
	VisorSpectrum = 0,
	VisorSupernova = 0,
	-- Helmets
	HelmetHardHat = 0,
	HelmetStarBubble = 0,
	HelmetArenaPlume = 0,
	HelmetDeepDiver = 0,
	HelmetJarlHorns = 0,
	HelmetSharkBite = 0,
	HelmetShogun = 0,
	HelmetPharaoh = 0,
	HelmetMechAce = 0,
	HelmetWyrmking = 0,
	HelmetJackOLantern = 0,
	HelmetGrimReaper = 0,
	-- One-time offers and the Season Path
	StarterPack = 0,
	SeasonPremium = 0,
	-- PROBE-7's swing refills (Shared.Outpost.Refills: their Product keys)
	SwingRefill = 0,
	SwingMega = 0,
}
-- The Robux price of each bundle and offer (a cosmetic's is its own Robux).
Store.RobuxPrices = {
	Welcome = 49,
	Rustbucket = 99,
	Brainrot = 199,
	Circuit = 349,
	DeepSpace = 599,
	SolarForge = 699,
	Royal = 1499,
	Vault = 4999,
	StarterPack = 99,
	SeasonPremium = 399,
}
-- (A refill's price is its own: Outpost.Refills.)
for _, refill in Outpost.Refills do
	Store.RobuxPrices[refill.Product] = refill.Robux
end

-- The PROBE-7 refill a product key is (nil if it isn't one).
function Store.refill(key: any)
	for _, refill in Outpost.Refills do
		if refill.Product == key then
			return refill
		end
	end
	return nil
end

-- Kit products ------------------------------------------------------------------------------------------

local KIT_ORDER = {}
for i, kit in Store.Kits do
	KIT_ORDER[kit.Id] = i
end

-- The product key for a choice of kits ("KitProspectorJuggernaut"), in
-- Store.Kits order whatever order they were picked in. Nil for none or an
-- unknown kit.
function Store.kitKey(ids: { string }): string?
	local chosen, seen = {}, {}
	for _, id in ids do
		if not KIT_ORDER[id] then
			return nil
		end
		if not seen[id] then
			seen[id] = true
			table.insert(chosen, id)
		end
	end
	if #chosen == 0 then
		return nil
	end
	table.sort(chosen, function(a, b)
		return KIT_ORDER[a] < KIT_ORDER[b]
	end)
	return "Kit" .. table.concat(chosen)
end

-- The kits a kit product holds, in order (nil if it isn't one).
function Store.kitsOf(key: any): { Kit }?
	if type(key) ~= "string" or string.sub(key, 1, 3) ~= "Kit" or Store.RobuxProducts[key] == nil then
		return nil
	end
	local rest, kits = string.sub(key, 4), {}
	for _, kit in Store.Kits do
		if string.sub(rest, 1, #kit.Id) == kit.Id then
			table.insert(kits, kit)
			rest = string.sub(rest, #kit.Id + 1)
		end
	end
	return if rest == "" and #kits > 0 then kits else nil
end

for i = 1, #Store.Kits do
	assert(Store.KitPrices[i], "Store.KitPrices needs a price for every number of kits")
end

-- The Vault: everything sold on its own, every extra the bundles and kits
-- carry (not the exclusives), and its own title.
do
	local vault = Store.Bundles[#Store.Bundles]
	assert(vault.Id == "Vault")
	local list, seen = {}, {}
	local function add(id: string)
		local cosmetic = Cosmetics.get(id)
		if cosmetic and not seen[id] and not cosmetic.Exclusive then
			seen[id] = true
			table.insert(list, id)
		end
	end
	for _, kind in { "Suit", "Skin", "Pick", "Visor", "Helmet" } do
		for _, id in Cosmetics.ofKind(kind) do
			if Cosmetics.List[id].Robux then
				add(id)
			end
		end
	end
	local function extras(reward)
		for _, id in reward.Cosmetics or {} do
			local kind = Cosmetics.List[id] and Cosmetics.List[id].Kind
			if kind == "Trim" or kind == "Back" then
				add(id)
			end
		end
	end
	for _, bundle in Store.Bundles do
		extras(bundle.Contents)
	end
	for _, kit in Store.Kits do
		extras(kit.Contents)
	end
	extras(Store.StarterPack.Contents)
	table.insert(list, "TitleCollector")
	vault.Contents.Cosmetics = list
end

-- Products -------------------------------------------------------------------------------------------------

function Store.bundle(id: any): Bundle?
	for _, bundle in Store.Bundles do
		if bundle.Id == id then
			return bundle
		end
	end
	return nil
end

-- What a product grants (a cosmetic, a bundle, kits, the Starter Pack, a
-- refill's swings). Nil for a key that isn't one (SeasonPremium unlocks a
-- track instead).
function Store.contents(key: any): Reward?
	local cosmetic = Cosmetics.get(key)
	if cosmetic and cosmetic.Robux then
		return { Cosmetics = { cosmetic.Id } }
	end
	local refill = Store.refill(key)
	if refill then
		return { Swings = refill.Swings }
	end
	local bundle = Store.bundle(key)
	if bundle then
		return bundle.Contents
	end
	if key == "StarterPack" then
		return Store.StarterPack.Contents
	end
	local kits = Store.kitsOf(key)
	if kits then
		local list, seen = {}, {}
		for _, kit in kits do
			for _, id in kit.Contents.Cosmetics or {} do
				if not seen[id] then
					seen[id] = true
					table.insert(list, id)
				end
			end
		end
		if #kits == #Store.Kits then
			for _, id in Store.SquadBonus.Cosmetics do
				table.insert(list, id)
			end
		end
		return { Cosmetics = list }
	end
	return nil
end

-- The Robux price of a product key (a cosmetic's own, a kit choice's, or
-- RobuxPrices).
function Store.robuxPrice(key: string): number?
	local cosmetic = Cosmetics.get(key)
	if cosmetic and cosmetic.Robux then
		return cosmetic.Robux
	end
	local kits = Store.kitsOf(key)
	if kits then
		return Store.KitPrices[#kits]
	end
	return Store.RobuxPrices[key]
end

-- Its price in coins while testing (Config.TestCosmeticPrice): anything for
-- sale. Nil otherwise.
function Store.testPrice(key: string): number?
	local test = Config.TestCosmeticPrice
	if type(test) ~= "number" or key == "SeasonPremium" or not Store.robuxPrice(key) then
		return nil
	end
	return test
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

-- What a reward's looks cost bought one by one, and how many of them can't
-- be bought on their own (bundle extras and exclusives).
function Store.separatePrice(reward: Reward): (number, number)
	local total, extras = 0, 0
	for _, id in reward.Cosmetics or {} do
		local cosmetic = Cosmetics.get(id)
		if cosmetic and cosmetic.Robux then
			total += cosmetic.Robux
		elseif cosmetic then
			extras += 1
		end
	end
	return total, extras
end

-- How much cheaper a product is than its looks bought separately, as a
-- whole percent (0 when it isn't).
function Store.savings(key: string): number
	local reward, price = Store.contents(key), Store.robuxPrice(key)
	if not reward or not price or Cosmetics.get(key) then
		return 0
	end
	local separate = Store.separatePrice(reward)
	if separate <= price then
		return 0
	end
	return math.floor((1 - price / separate) * 100)
end

-- How many of a reward's looks you own already, of how many.
function Store.ownedCount(reward: Reward, owned: { [string]: boolean }?): (number, number)
	local have, total = 0, 0
	for _, id in reward.Cosmetics or {} do
		total += 1
		if owned and owned[id] then
			have += 1
		end
	end
	return have, total
end

-- Bundles (and kits) that include a cosmetic, best saving first: for the
-- "save with a bundle" note on a product. (Not The Vault, which holds
-- everything, nor the one-time offers.)
function Store.bundlesWith(cosmeticId: string): { string }
	local keys = {}
	for _, bundle in Store.Bundles do
		if bundle.Section == "Collection" or bundle.Id == "Royal" then
			if table.find(bundle.Contents.Cosmetics or {}, cosmeticId) then
				table.insert(keys, bundle.Id)
			end
		end
	end
	for _, kit in Store.Kits do
		if table.find(kit.Contents.Cosmetics or {}, cosmeticId) then
			table.insert(keys, "Kit" .. kit.Id)
		end
	end
	table.sort(keys, function(a, b)
		return Store.savings(a) > Store.savings(b)
	end)
	return keys
end

-- The product's display name.
function Store.productName(key: string): string
	local cosmetic = Cosmetics.get(key)
	if cosmetic then
		return cosmetic.Name
	end
	local bundle = Store.bundle(key)
	if bundle then
		return bundle.Name
	end
	if key == "StarterPack" then
		return Store.StarterPack.Name
	end
	if key == "SeasonPremium" then
		return "Season Path Premium"
	end
	local refill = Store.refill(key)
	if refill then
		return refill.Name
	end
	local kits = Store.kitsOf(key)
	if kits then
		if #kits == #Store.Kits then
			return "Squad Bundle"
		end
		local names = {}
		for _, kit in kits do
			table.insert(names, kit.Name)
		end
		return table.concat(names, " + ") .. (if #kits == 1 then " Kit" else " Kits")
	end
	return key
end

-- Is the Starter Pack still on offer? (Offered at `offeredAt`, os.time.)
function Store.starterOpen(offeredAt: number?, bought: boolean?, now: number): boolean
	return not bought
		and type(offeredAt) == "number"
		and offeredAt > 0
		and now < offeredAt + Store.StarterPack.Hours * 3600
end

-- Is the Welcome Kit on offer to a player who first joined at `firstJoin`?
function Store.welcomeOpen(firstJoin: number?, bought: boolean?, now: number): boolean
	return not bought and type(firstJoin) == "number" and firstJoin > 0 and now < firstJoin + Store.WelcomeHours * 3600
end

-- Can this player buy `key` now? Shared by the store's buttons and the
-- server. Returns false and why not: a one-time offer that's closed or
-- bought, or a product whose every look you own already.
function Store.canBuy(key: string, profile: any, now: number): (boolean, string?)
	profile = profile or {}
	local owned = profile.Cosmetics and profile.Cosmetics.Owned or {}
	if key == "SeasonPremium" then
		if profile.Season and profile.Season.Premium then
			return false, "The premium track is already yours."
		end
		return true
	end
	local reward = Store.contents(key)
	if not reward or not Store.robuxPrice(key) then
		return false, "That isn't for sale."
	end
	local bundle = Store.bundle(key)
	if key == "StarterPack" and not Store.starterOpen(profile.StarterOfferAt, profile.StarterBought, now) then
		return false,
			if profile.StarterBought then "You have the Starter Pack already." else "The Starter Pack isn't on offer."
	end
	if bundle and bundle.NewPlayersOnly and not Store.welcomeOpen(profile.FirstJoin, profile.WelcomeBought, now) then
		return false, "The Welcome Kit is for new miners, once."
	end
	if bundle and bundle.Once and profile[bundle.Once] then
		return false, "You have " .. bundle.Name .. " already."
	end
	local have, total = Store.ownedCount(reward, owned)
	if total > 0 and have >= total and not reward.Coins and not reward.XPBoostMinutes then
		return false, if total == 1 then "You own it already." else "You own everything in it already."
	end
	return true
end

-- Old saves: unopened crates (no longer sold or given) are refunded as
-- coins, at what they cost. Returns the coins refunded.
Store.CrateRefund = { GeodeCrate = 250, MasterworkCrate = 800 }
function Store.refundCrates(profile: any): number
	local coins = 0
	for id, count in profile.Crates or {} do
		if type(count) == "number" and count > 0 then
			coins += (Store.CrateRefund[id] or 0) * math.floor(count)
		end
	end
	profile.Crates = {}
	if coins > 0 then
		profile.Coins = (profile.Coins or 0) + coins
	end
	return coins
end

-- A cosmetic you already own, from a bundle, becomes this many coins.
Store.DuplicateRefund = 120

-- Lines describing a reward, for bundle cards and "you got" messages.
export type RewardItem = { Kind: string, Id: string?, Count: number?, Text: string }

-- A reward as separate pieces (for drawing a tile per piece).
function Store.items(reward: Reward, cosmeticName: ((string) -> string)?): { RewardItem }
	local items = {}
	local function add(kind: string, id: string?, count: number?, label: string)
		table.insert(items, { Kind = kind, Id = id, Count = count, Text = label })
	end
	for _, id in reward.Cosmetics or {} do
		add("Cosmetic", id, nil, if cosmeticName then cosmeticName(id) else id)
	end
	if reward.Coins then
		add("Coins", nil, reward.Coins, "Coins")
	end
	if reward.XPBoostMinutes then
		local hours = reward.XPBoostMinutes // 60
		add(
			"XPBoost",
			nil,
			nil,
			if reward.XPBoostMinutes % 60 == 0
				then string.format("2x XP · %d hour%s", hours, if hours == 1 then "" else "s")
				else string.format("2x XP · %d min", reward.XPBoostMinutes)
		)
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
	return items
end

function Store.describe(reward: Reward, cosmeticName: ((string) -> string)?): { string }
	local lines = {}
	for _, id in reward.Cosmetics or {} do
		table.insert(lines, if cosmeticName then cosmeticName(id) else id)
	end
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
	if reward.XPBoostMinutes then
		table.insert(lines, string.format("2x XP for %d min", reward.XPBoostMinutes))
	end
	return lines
end

return Store
