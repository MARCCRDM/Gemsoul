-- The townsfolk who stand outside each shop. The server builds a robot for
-- each entry; the client shows its dialogue when a player talks to it.
--
-- Each option either has a Reply (text shown back) or an Action the client
-- handles in code: "Quota", "BuyStone", "Pouch", "HandCut", "AutoCut",
-- "Enchant", "Forge", "Materials", "SellGems", "MarketSell" or "RigManeuvers";
-- and for the Saga Shelter's crew, "Appraise", "Store", "Market" or "Duels".

export type Option = { Text: string, Reply: string?, Action: string? }
export type Vendor = {
	Name: string,
	Role: string,
	Color: Color3,
	Tunic: Color3,
	Face: string,
	Greeting: string,
	Options: { Option },
}

local Vendors: { [string]: Vendor } = {
	Mining = {
		Name = "Garrick",
		Role = "Mining Foreman",
		Color = Color3.fromRGB(0, 240, 255),
		Tunic = Color3.fromRGB(70, 90, 110),
		Face = "o_o",
		Greeting = "Welcome to Gemsoul, miner! Every miner gets free mines each day and week. Hold [E] on a crystal node in the quarry up the road.",
		Options = {
			{ Text = "How many free mines do I have left?", Action = "Quota" },
			{ Text = "Show me my gems", Action = "Pouch" },
			{
				Text = "What makes a stone valuable?",
				Reply = "Colour, size, clarity and cut. Each element has common, uncommon and rare colours. Size matters most: every grade is worth far more than the last.",
			},
			{
				Text = "What's behind the pink energy gate?",
				Reply = "The VIP pit. Only VIP miners pass the gate, and its stones roll rarer colours and better grades.",
			},
		},
	},
	Cutting = {
		Name = "Ilsa",
		Role = "Gem Analyst",
		Color = Color3.fromRGB(255, 160, 30),
		Tunic = Color3.fromRGB(120, 70, 40),
		Face = "^_^",
		Greeting = "Moon pressure forms diamond-cut Saga Stones naturally. Their facets are fixed when recovered.",
		Options = {
			{ Text = "Inspect my gems", Action = "Pouch" },
			{
				Text = "What does cut quality mean?",
				Reply = "Natural facet quality runs from 1 to 10. Better facets strengthen enchantments and increase exchange value. Gems arrive ready to socket; there is no cutting service.",
			},
		},
	},
	Quartermaster = {
		Name = "Hilde",
		Role = "Expedition Quartermaster",
		Color = Color3.fromRGB(255, 200, 60),
		Tunic = Color3.fromRGB(110, 80, 40),
		Face = "-_-",
		Greeting = "Equipment comes from your colony-issued random kit, recovery caches and other explorers. Spare gems fund the next expedition.",
		Options = {
			{ Text = "Sell gems for coins", Action = "SellGems" },
			{ Text = "Inspect equipment", Action = "Equipment" },
		},
	},
	Forge = {
		Name = "Borin",
		Role = "Equipment Specialist",
		Color = Color3.fromRGB(255, 120, 30),
		Tunic = Color3.fromRGB(90, 56, 36),
		Face = "o_O",
		Greeting = "We recover equipment instead of manufacturing it here. Every helmet, chest, glove, boot, pistol and shield carries its own roll and socket.",
		Options = {
			{ Text = "Manage my loadout", Action = "Equipment" },
			{ Text = "Trade equipment", Action = "Trade" },
			{
				Text = "How do I find better gear?",
				Reply = "Mine recovery seams and lucky rocks. Deeper expeditions can recover better quality equipment. Rarity and bonus stats are rolled once and stay with each item.",
			},
		},
	},
	Market = {
		Name = "Tamsin",
		Role = "Trade Broker",
		Color = Color3.fromRGB(60, 255, 120),
		Tunic = Color3.fromRGB(40, 100, 70),
		Face = "$_$",
		Greeting = "Buying? Selling? Every trade in Gemsoul goes up on my board.",
		Options = {
			{ Text = "Sell stones for coins", Action = "MarketSell" },
			{
				Text = "Show me the trade listings",
				Action = "Trade",
			},
			{
				Text = "How does trading work?",
				Reply = "Open Trade, select a player and equipment, then review their same-slot counteroffer. Both players must confirm. Item stats and socketed gems travel with the equipment.",
			},
		},
	},
	Enchanting = {
		Name = "Vey",
		Role = "Arcanist",
		Color = Color3.fromRGB(150, 70, 255),
		Tunic = Color3.fromRGB(70, 40, 110),
		Face = "*_*",
		Greeting = "The runes hum today. Bring me a cut gem and I'll bind it to your six equipment slots.",
		Options = {
			{ Text = "Enchant my gear", Action = "Enchant" },
			{
				Text = "Which gems make the strongest enchantments?",
				Reply = "Depends what you need. Size is how hard it hits, Clarity is how long it lasts, Cut is how often it triggers. Thermal burns, Cryo slows, Corrosive shreds armor and Ion arcs and executes.",
			},
		},
	},
	Arena = {
		Name = "Brutus",
		Role = "Arena Master",
		Color = Color3.fromRGB(255, 45, 70),
		Tunic = Color3.fromRGB(110, 30, 40),
		Face = ">_<",
		Greeting = "Looking for a fight? Warm up against a sparring partner inside, then go hunt the crystal beasts past the south gate.",
		Options = {
			{ Text = "Open my Augment Tree", Action = "AugmentTree" },
			{ Text = "Review my combat rig", Action = "CombatGuide" },
			{
				Text = "How do I fight?",
				Reply = "LMB swings (Shift+LMB for your off-hand); hold and release on gold for a perfect hit. RMB guards, Space dodges. Keys 1, 2 and 3 fire your Rig Maneuvers (Stamina). Q, E and R fire the gems in your Surge Array (Charge). Press L for your Loadout and K for your Augment Tree.",
			},
			{
				Text = "What's out past the south gate?",
				Reply = "The Crystal Wilds. Crawlers and Shard Brutes, each tied to an element. Beat them for coins and ready gems; brutes always drop one. A matching armor gem blunts their bite.",
			},
			{
				Text = "Join a PvP duel (collateral)",
				Reply = "Each fighter wagers a gem. The winner walks away with the loser's stone, every property intact. Duels open soon!",
			},
		},
	},
}

-- The Saga Shelter's crew, in the Outpost's lobby: the old town's
-- shopkeepers, moved up to the moon (the same names, faces and colours),
-- each by the station they run now. OutpostServer builds them where
-- OutpostWorld puts them (site.Crew).
local function crew(from: string, role: string, greeting: string, options: { Option }): Vendor
	local old = Vendors[from]
	return {
		Name = old.Name,
		Role = role,
		Color = old.Color,
		Tunic = old.Tunic,
		Face = old.Face,
		Greeting = greeting,
		Options = options,
	}
end

Vendors.GemBuyer = crew(
	"Cutting",
	"Gem Buyer",
	"Ilsa, gem buyer. Bring me the stones you don't need: I pay coins on the spot, and coins buy anything on the player Market.",
	{
		{ Text = "What will you give me for my gems?", Action = "Appraise" },
		{ Text = "Pick a gem to sell", Action = "SellGems" },
		{
			Text = "What makes a gem valuable?",
			Reply = "Rarity first: one Legendary is worth more than a pouch of Commons. Then its Size, Clarity and Cut, each graded out of ten. The higher, the more I pay.",
		},
		{
			Text = "Which gems do you buy?",
			Reply = "Any gem in your pouch. When I make an offer for your spares, I leave out the gems your loadouts use.",
		},
	}
)
Vendors.ArenaMaster = crew(
	"Arena",
	"Arena Master",
	"Brutus, arena master. Step through the Uplink for a 1v1. Win in a row and your swings come back.",
	{
		{ Text = "Find me a duel", Action = "Duels" },
		{
			Text = "What do win streaks give?",
			Reply = "Queue a 1v1 and win in a row. Your first win brings back a tenth of your swings, the fifth a quarter, the tenth half, and ten in a row wins the tournament. A loss ends the run.",
		},
		{
			Text = "Any advice?",
			Reply = "Guard when they wind up, then punish. And bring your best gems: they power your Q, E and R.",
		},
	}
)
Vendors.Broker =
	crew("Market", "Trade Broker", "Tamsin, trade broker. Every miner's gems and gear go up on my board.", {
		{ Text = "Open the Market", Action = "Market" },
		{
			Text = "How does the Market work?",
			Reply = "List a gem or a piece of gear at your price, or make an offer on someone else's. Coins change hands when a sale goes through.",
		},
		{
			Text = "Where do I get coins?",
			Reply = "Sell your spare gems to Ilsa, by the Gem Gallery.",
		},
	})
Vendors.Outfitter = crew(
	"Forge",
	"Outfitter",
	"Borin, outfitter. Suits, helmets, picks and weapon skins: everything on these stands is in the Store.",
	{
		{ Text = "Open the Store", Action = "Store" },
		{
			Text = "Do skins change my stats?",
			Reply = "No: a skin is looks only. Your gear's rolls and gems stay as they are.",
		},
	}
)
Vendors.Foreman = crew(
	"Mining",
	"Mining Foreman",
	"Garrick, foreman. Out that door is the quarry: every rock you break pays a gem.",
	{
		{
			Text = "Where are the best rocks?",
			Reply = "The further out, the richer. The Fringe starts 150 studs out, the Edge at 300, and three Rift Veins glow by the crater walls. One of them is guarded.",
		},
		{
			Text = "What are those critters?",
			Reply = "Rift critters. The longer you mine out there, the more come through. Keep your kaiju close: they fight for you.",
		},
		{
			Text = "My swings ran out",
			Reply = "PROBE-7 sells refills, and win streaks at Brutus's Uplink bring swings back.",
		},
	}
)

return Vendors
