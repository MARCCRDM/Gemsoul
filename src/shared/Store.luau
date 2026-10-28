--[[
	The store: weapon skins, suits, pickaxes and bundles, sold for Robux,
	plus the Free rewards. Looks only, never stats. (The swing refills are
	Robux products too: Shared.Outpost.Refills, sold by Garrick.)

	  Bundles      new-player offers (the Welcome Kit, the Starter Pack), the
	               player bundles (a whole look for your miner: suit, weapon
	               skin, helmet, visor, pickaxe and often a trim or back
	               piece), and the premium sets (Royal Treasury, The Vault:
	               everything in the store)
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
	KaijuRevive: boolean?, -- every kaiju of yours that's knocked out, back now
}
export type Bundle = {
	Id: string,
	Name: string,
	Tagline: string,
	Section: string, -- "Offer", "Look" (a whole look for your miner), "Premium", or "Retired" (no longer sold)
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
		Id = "Scrapyard",
		Name = "Scrapyard Hauler",
		Tagline = "Hauler gear from the scrap heaps: rusted rig, rust blade, hard hat, hi-vis visor, bone pick and a survey pack.",
		Section = "Look",
		Color = Color3.fromRGB(196, 110, 58),
		Hero = "SuitRust",
		Contents = { Cosmetics = { "SuitRust", "SkinRust", "HelmetHardHat", "VisorLime", "PickBone", "BackPack" } },
	},
	{
		Id = "CopperShogun",
		Name = "Copper Shogun",
		Tagline = "Copper coil plate under a shogun's kabuto, a gold mirror visor, the gilded pick and a war banner.",
		Section = "Look",
		Color = Color3.fromRGB(214, 140, 70),
		Hero = "HelmetShogun",
		Contents = { Cosmetics = { "SuitCopper", "SkinCopper", "HelmetShogun", "VisorGoldMirror", "PickGilded", "BackBanner" } },
	},
	{
		Id = "ToxicProspector",
		Name = "Toxic Prospector",
		Tagline = "Hazmat from head to pick: Biohazard suit, Toxic Ooze blade, Deep Diver helmet, Toxic Bloom visor and Venom trim.",
		Section = "Look",
		Color = Color3.fromRGB(120, 220, 90),
		Hero = "SuitBiohazard",
		Contents = { Cosmetics = { "SuitBiohazard", "SkinToxic", "HelmetDeepDiver", "VisorToxic", "PickGeode", "TrimVenom" } },
	},
	{
		Id = "GlacierJuggernaut",
		Name = "Glacier Juggernaut",
		Tagline = "Cold and heavy: Arctic Ops, the Glacier Shard blade, Jarl's Horns, a Cryo Frost visor, Glacier Fang and Glacier trim.",
		Section = "Look",
		Color = Color3.fromRGB(150, 225, 255),
		Hero = "SuitArctic",
		Contents = { Cosmetics = { "SuitArctic", "SkinGlacier", "HelmetJarlHorns", "VisorCryo", "PickGlacier", "TrimGlacier" } },
	},
	{
		Id = "ReaperHarvest",
		Name = "Reaper's Harvest",
		Tagline = "For Halloween and after: Stealth Black, the Void Crystal blade, the Grim Reaper hood, a Twilight visor and the Void Reaper pick.",
		Section = "Look",
		Color = Color3.fromRGB(150, 90, 220),
		Hero = "HelmetGrimReaper",
		Contents = { Cosmetics = { "SuitStealth", "SkinVoid", "HelmetGrimReaper", "VisorTwilight", "PickVoid" } },
	},
	{
		Id = "StormCaller",
		Name = "Storm Caller",
		Tagline = "Storm Conductor plate, the Plasma Edge blade, a Mech Ace helmet, the Ion Storm visor, Stormbreaker and Storm trim.",
		Section = "Look",
		Color = Color3.fromRGB(90, 170, 255),
		Hero = "SuitStorm",
		Contents = { Cosmetics = { "SuitStorm", "SkinPlasma", "HelmetMechAce", "VisorIon", "PickStorm", "TrimStorm" } },
	},
	{
		Id = "NeonRush",
		Name = "Neon Rush",
		Tagline = "Lit up head to toe: the Neon Runner suit and pick, the Circuit Board blade, Shark Bite and the Spectrum visor.",
		Section = "Look",
		Color = Color3.fromRGB(255, 80, 200),
		Hero = "SuitNeon",
		Contents = { Cosmetics = { "SuitNeon", "SkinCircuit", "HelmetSharkBite", "VisorSpectrum", "PickNeon" } },
	},
	{
		Id = "DeepSpaceExplorer",
		Name = "Deep Space Explorer",
		Tagline = "Nebula suit and blade, a Star Bubble helmet, the Aurora visor and the Prism Shard pick.",
		Section = "Look",
		Color = Color3.fromRGB(130, 90, 255),
		Hero = "SuitNebula",
		Contents = { Cosmetics = { "SuitNebula", "SkinNebula", "HelmetStarBubble", "VisorAurora", "PickPrism" } },
	},
	{
		Id = "SolarWarlord",
		Name = "Solar Warlord",
		Tagline = "The store's hottest look: Obsidian Lava, the Solar Flare blade, the Wyrmking helm, a Supernova visor, Magma Heart and the Ember Cape.",
		Section = "Look",
		Color = Color3.fromRGB(255, 120, 40),
		Hero = "SuitObsidian",
		Contents = { Cosmetics = { "SuitObsidian", "SkinSolar", "HelmetWyrmking", "VisorSupernova", "PickMagma", "BackCape" } },
	},
	-- No longer sold (the launch collections): kept so a purchase still
	-- going through is granted.
	{
		Id = "Rustbucket",
		Name = "Rustbucket Set",
		Tagline = "Scrapyard chic: a rusted rig, a matching blade and a survey pack.",
		Section = "Retired",
		Color = Color3.fromRGB(196, 110, 58),
		Hero = "SuitRust",
		Contents = { Cosmetics = { "SuitRust", "SkinRust", "BackPack" } },
	},
	{
		Id = "Brainrot",
		Name = "Brainrot Duo",
		Tagline = "Two of the silliest weapons in the arena. Bonk them both.",
		Section = "Retired",
		Color = Color3.fromRGB(255, 196, 64),
		Hero = "SkinBanana",
		Contents = { Cosmetics = { "SkinBanana", "SkinBonk" } },
	},
	{
		Id = "Circuit",
		Name = "Circuit & Copper",
		Tagline = "Two wired-up looks, suit and blade each: circuit green and copper coil.",
		Section = "Retired",
		Color = Color3.fromRGB(60, 200, 140),
		Hero = "SuitCircuit",
		Contents = { Cosmetics = { "SuitCircuit", "SkinCircuit", "SuitCopper", "SkinCopper" } },
	},
	{
		Id = "DeepSpace",
		Name = "Deep Space Set",
		Tagline = "Nebula suit and blade, a void crystal edge and the Void Reaper pick.",
		Section = "Retired",
		Color = Color3.fromRGB(130, 90, 255),
		Hero = "SuitNebula",
		Contents = { Cosmetics = { "SuitNebula", "SkinNebula", "SkinVoid", "PickVoid" } },
	},
	{
		Id = "SolarForge",
		Name = "Solar Forge Set",
		Tagline = "Obsidian plate, the Solar Flare blade and the Magma Heart pick.",
		Section = "Retired",
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

-- Squad kits, from when every player had three miners: one look per
-- fighting style. No longer sold (Store.retired), kept so a purchase still
-- going through is granted.
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
	Tagline = "Your first win deserves a look: a suit you can't get anywhere else, a Thermal Core visor, two more looks and coins.",
	Section = "Offer",
	Color = Color3.fromRGB(255, 96, 64),
	Hero = "SuitIgnition",
	Hours = 48,
	Contents = {
		Cosmetics = { "SuitIgnition", "SkinMolten", "PickBone", "VisorThermal" },
		Coins = 1000,
	},
}

-- Robux --------------------------------------------------------------------------------------------------

-- Each product's Developer Product id (0 = not on sale yet).
Store.RobuxProducts = {
	-- Bundles
	Welcome = 3723018588,
	Scrapyard = 0,
	CopperShogun = 0,
	ToxicProspector = 0,
	GlacierJuggernaut = 0,
	ReaperHarvest = 0,
	StormCaller = 0,
	NeonRush = 0,
	DeepSpaceExplorer = 0,
	SolarWarlord = 0,
	-- (no longer sold, kept for purchases still going through: Store.retired)
	Rustbucket = 3723018366,
	Brainrot = 3723018237,
	Circuit = 3723018242,
	DeepSpace = 3723018245,
	SolarForge = 3723018447,
	Royal = 3723018359,
	Vault = 3723018522,
	-- Squad kits: one, two or all three (no longer sold either)
	KitProspector = 3723018297,
	KitSkirmisher = 3723018310,
	KitJuggernaut = 3723018293,
	KitProspectorSkirmisher = 3723018304,
	KitProspectorJuggernaut = 3723018301,
	KitSkirmisherJuggernaut = 3723018315,
	KitProspectorSkirmisherJuggernaut = 3723018308,
	-- Weapon skins
	SkinRust = 3723018432,
	SkinCamo = 3723018392,
	SkinCopper = 3723018399,
	SkinPlasma = 3723018422,
	SkinMolten = 3723018413,
	SkinToxic = 3723018438,
	SkinGlacier = 3723018405,
	SkinCircuit = 3723018396,
	SkinVoid = 3723018440,
	SkinBonk = 3723018388,
	SkinBanana = 3723018383,
	SkinGalaxy = 3723018403,
	SkinNebula = 3723018417,
	SkinSolar = 3723018433,
	-- Suits
	SuitRust = 3723018502,
	SuitCamo = 3723018462,
	SuitCopper = 3723018474,
	SuitStealth = 3723018505,
	SuitCircuit = 3723018468,
	SuitChrome = 3723018465,
	SuitArctic = 3723018455,
	SuitStorm = 3723018510,
	SuitBiohazard = 3723018458,
	SuitObsidian = 3723018490,
	SuitNeon = 3723018485,
	SuitNebula = 3723018481,
	SuitRoyal = 3723018494,
	-- Pickaxes
	PickBone = 3723018321,
	PickNeon = 3723018343,
	PickGeode = 3723018324,
	PickGlacier = 3723018332,
	PickPrism = 3723018346,
	PickGilded = 3723018328,
	PickMagma = 3723018335,
	PickStorm = 3723018349,
	PickVoid = 3723018351,
	-- Visors
	VisorTangerine = 3723018579,
	VisorRose = 3723018553,
	VisorGoldMirror = 3723018532,
	VisorLime = 3723018548,
	VisorHotPink = 3723018539,
	VisorHeartbeat = 3723018534,
	VisorScanner = 3723018561,
	VisorTwilight = 3723018587,
	VisorThermal = 3723018582,
	VisorCryo = 3723018528,
	VisorIon = 3723018541,
	VisorToxic = 3723018584,
	VisorAurora = 3723018525,
	VisorSpectrum = 3723018564,
	VisorSupernova = 3723018573,
	-- Helmets
	HelmetHardHat = 3723018261,
	HelmetStarBubble = 3723018288,
	HelmetArenaPlume = 3723018248,
	HelmetDeepDiver = 3723018252,
	HelmetJarlHorns = 3723018269,
	HelmetSharkBite = 3723018280,
	HelmetShogun = 3723018283,
	HelmetPharaoh = 3723018276,
	HelmetMechAce = 3723018271,
	HelmetWyrmking = 3723018291,
	HelmetJackOLantern = 3723018264,
	HelmetGrimReaper = 3723018258,
	-- One-time offers and the Season Path
	StarterPack = 3723018451,
	SeasonPremium = 3723018375,
	-- The swing refills (Shared.Outpost.Refills: their Product keys)
	SwingRefill = 3723018517,
	SwingMega = 3723018515,
	-- Your knocked-out kaiju back on their feet now (Shared.Kaiju.Revive)
	KaijuRevive = 3723018189,
	-- Down at a Rift boss: back on your feet there, kaiju and all (RiftServer)
	RiftRestore = 3723023347,
}
-- The Robux price of each bundle and offer (a cosmetic's is its own Robux).
Store.RobuxPrices = {
	Welcome = 49,
	Scrapyard = 199,
	CopperShogun = 349,
	ToxicProspector = 399,
	GlacierJuggernaut = 449,
	ReaperHarvest = 449,
	StormCaller = 499,
	NeonRush = 499,
	DeepSpaceExplorer = 549,
	SolarWarlord = 799,
	Rustbucket = 99,
	Brainrot = 199,
	Circuit = 349,
	DeepSpace = 599,
	SolarForge = 699,
	Royal = 1499,
	Vault = 4999,
	StarterPack = 99,
	SeasonPremium = 399,
	KaijuRevive = 25,
	RiftRestore = 100,
}
-- (A refill's price is its own: Outpost.Refills.)
for _, refill in Outpost.Refills do
	Store.RobuxPrices[refill.Product] = refill.Robux
end

-- The swing refill a product key is (nil if it isn't one).
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

-- The Vault: everything sold on its own, every extra the bundles carry
-- (not the exclusives), and its own title.
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

-- Is this a product no longer sold (a retired bundle, the squad kits)? It's
-- still granted when a purchase of it goes through, never offered again.
function Store.retired(key: any): boolean
	local bundle = Store.bundle(key)
	return (bundle ~= nil and bundle.Section == "Retired") or Store.kitsOf(key) ~= nil
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
	if key == "KaijuRevive" then
		return { KaijuRevive = true }
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

-- Bundles that include a cosmetic, best saving first: for the "save with
-- a bundle" note on a product. (Not The Vault, which holds everything, nor
-- the one-time offers, nor anything no longer sold.)
function Store.bundlesWith(cosmeticId: string): { string }
	local keys = {}
	for _, bundle in Store.Bundles do
		if bundle.Section == "Look" or bundle.Id == "Royal" then
			if table.find(bundle.Contents.Cosmetics or {}, cosmeticId) then
				table.insert(keys, bundle.Id)
			end
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
	if key == "KaijuRevive" then
		return "Kaiju Revive"
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
	if Store.retired(key) then
		return false, "That isn't sold any more."
	end
	if key == "KaijuRevive" then
		-- (Only with one of yours knocked out.)
		for _, record in profile.Kaiju and profile.Kaiju.List or {} do
			if record.Down then
				return true
			end
		end
		return false, "None of your kaiju is knocked out."
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
