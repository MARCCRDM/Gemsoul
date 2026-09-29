-- The townsfolk who stand outside each shop. The server builds a robot for
-- each entry; the client shows its dialogue when a player talks to it.
--
-- Each option either has a Reply (text shown back) or an Action the client
-- handles in code (for example "Quota").

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
		Greeting = "Welcome to Gemsoul, miner! The quarry's just up the road. Hold [E] on a crystal node to mine it.",
		Options = {
			{ Text = "How am I doing on my daily quota?", Action = "Quota" },
			{
				Text = "How does mining work?",
				Reply = "Every node in the quarry holds gems, but once a node is mined it's gone for good. Mine them before the other miners do!",
			},
			{
				Text = "What's behind the pink energy gate?",
				Reply = "The VIP quarry. Only VIP miners can pass the gate, and its nodes are worth three gems each.",
			},
		},
	},
	Crafting = {
		Name = "Ilsa",
		Role = "Master Gemcutter",
		Color = Color3.fromRGB(255, 160, 30),
		Tunic = Color3.fromRGB(120, 70, 40),
		Face = "^_^",
		Greeting = "Rough gems are worth little. Cut them well and they'll shine. What can I do for you?",
		Options = {
			{
				Text = "Cut a gem by hand",
				Reply = "Hand-cutting takes timing: strike when the beam lines up. The cutting bench opens soon!",
			},
			{
				Text = "Use the laser cutters",
				Reply = "Our laser cutters come in three tiers. Higher tiers cut faster and cleaner. Coming soon!",
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
		Greeting = "The runes hum today. Bring me a gem and a piece of gear, and I'll bind them together.",
		Options = {
			{
				Text = "Fuse a gem onto my gear",
				Reply = "The containment fields aren't stable yet. Enchanting opens soon!",
			},
			{
				Text = "What do enchantments do?",
				Reply = "Each gem lends its power to your gear: speed, strength, luck and stranger things.",
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
				Reply = "Both fighters put gems on the line, and the winner takes all. Duels open soon!",
			},
			{
				Text = "Start PvE combat",
				Reply = "Waves of constructs, stronger every round. PvE opens soon!",
			},
		},
	},
}

return Vendors
