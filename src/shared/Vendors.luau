-- The townsfolk who stand outside each shop. The server builds a robot for
-- each entry; the client shows its dialogue when a player talks to it.
--
-- Each option either has a Reply (text shown back) or an Action the client
-- handles in code: "Quota", "BuyStone", "Pouch", "HandCut", "AutoCut",
-- "Enchant", "Forge", "Materials" or "SellGems".

local Config = require(script.Parent.Config)

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
			{
				Text = string.format("Buy a random rough stone (%d coins)", Config.RoughStonePrice),
				Action = "BuyStone",
			},
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
		Role = "Master Gemcutter",
		Color = Color3.fromRGB(255, 160, 30),
		Tunic = Color3.fromRGB(120, 70, 40),
		Face = "^_^",
		Greeting = "A rough stone is worth half its promise. Cut it well and it'll shine. What'll it be?",
		Options = {
			{ Text = "Cut a gem by hand (free)", Action = "HandCut" },
			{ Text = "Use a laser cutter", Action = "AutoCut" },
			{
				Text = "How is a cut graded?",
				Reply = "From 1 to 10. A steady hand earns up to 8. Land every strike near the line for a 9, and a flawless cut is a 10: Gem Mint. My precision laser always cuts a 9, the premium one a 10. Bigger stones are harder to cut by hand.",
			},
		},
	},
	Quartermaster = {
		Name = "Hilde",
		Role = "Guild Quartermaster",
		Color = Color3.fromRGB(255, 200, 60),
		Tunic = Color3.fromRGB(110, 80, 40),
		Face = "-_-",
		Greeting = "Welcome to the Crafting Hall. I pay Guild Marks for stones, and Marks buy the materials Borin needs to make your gear.",
		Options = {
			{ Text = "Sell stones for Guild Marks", Action = "SellGems" },
			{ Text = "Buy crafting materials", Action = "Materials" },
			{
				Text = "What are Guild Marks?",
				Reply = "The hall's own currency. You earn Marks only by selling stones here, and they pay for materials and Borin's forge fees. Coins won't buy anything in this hall.",
			},
			{
				Text = "Can I break stones down instead?",
				Reply = "Salvage them at my counter and you get Gem Shards. Borin needs shards for Masterwork gear.",
			},
		},
	},
	Forge = {
		Name = "Borin",
		Role = "Master Smith",
		Color = Color3.fromRGB(255, 120, 30),
		Tunic = Color3.fromRGB(90, 56, 36),
		Face = "o_O",
		Greeting = "Bring me materials from Hilde and a few Marks for the fire, and I'll forge you something worth wearing.",
		Options = {
			{ Text = "Craft or upgrade gear", Action = "Forge" },
			{
				Text = "How does gear quality work?",
				Reply = "Everything starts Standard. Upgrade it to Fine, then Superior with mithril, then Masterwork with gem shards. Each step hits harder or guards better, and looks it.",
			},
			{
				Text = "Where do I get materials?",
				Reply = "Hilde, out front of the hall. Sell her your spare stones for Guild Marks, then buy what the recipe needs.",
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
			{
				Text = "Show me the trade listings",
				Reply = "The board's empty for now. Player-to-player trading opens soon!",
			},
			{
				Text = "How does trading work?",
				Reply = "Post your gems on the board with a price, and other players can buy them from any kiosk.",
			},
		},
	},
	Enchanting = {
		Name = "Vey",
		Role = "Arcanist",
		Color = Color3.fromRGB(150, 70, 255),
		Tunic = Color3.fromRGB(70, 40, 110),
		Face = "*_*",
		Greeting = "The runes hum today. Bring me a cut gem and I'll bind it to your weapon or armor.",
		Options = {
			{ Text = "Enchant my gear", Action = "Enchant" },
			{
				Text = "Which gems make the strongest enchantments?",
				Reply = "Big ones. Size decides most of a gem's potency, then clarity and cut. Fire, Frost, Shock and Poison each grant their own power.",
			},
		},
	},
	Arena = {
		Name = "Brutus",
		Role = "Arena Master",
		Color = Color3.fromRGB(255, 45, 70),
		Tunic = Color3.fromRGB(110, 30, 40),
		Face = ">_<",
		Greeting = "Looking for a fight? The arena never sleeps.",
		Options = {
			{
				Text = "Join a PvP duel (collateral)",
				Reply = "Each fighter wagers a gem. The winner walks away with the loser's stone, every property intact. Duels open soon!",
			},
			{
				Text = "Start PvE combat",
				Reply = "Monsters drop loot, crafting materials and raw stones, and tougher ones drop better stones. PvE opens soon!",
			},
		},
	},
}

return Vendors
