-- The townsfolk who stand outside each shop. The server builds a robot for
-- each entry; the client shows its dialogue when a player talks to it.
--
-- Each option either has a Reply (text shown back), an Action the client
-- handles in code: "Quota", "BuyStone", "Pouch", "HandCut", "AutoCut",
-- "Enchant", "Forge", "Materials", "SellGems", "MarketSell" or "RigManeuvers";
-- for the Saga Shelter's crew, "Appraise", "Store", "Market", "Duels" or
-- "Tip" (INFO-9's next one, from Vendors.Tips); downstairs, "ArenaTip"
-- (COACH-4's next one, from Vendors.ArenaTips) - or Options of its own: a
-- topic, its questions shown in place of the menu (with a way back).

-- An option with Only shows just while that holds (the client checks it:
-- "KaijuRollOwed", the starter kaiju roll still owed, Kaiju.rollsOwed;
-- "KaijuRollDone", it isn't).
export type Option = { Text: string, Reply: string?, Action: string?, Options: { Option }?, Only: string? }
export type Vendor = {
	Name: string,
	Role: string,
	Color: Color3,
	Tunic: Color3,
	Face: string,
	Visor: boolean?, -- a visor slit in its colour on its screen, in place of a Face
	Greeting: string,
	OwedGreeting: string?, -- in place of Greeting while the starter kaiju roll is owed
	Options: { Option },
	Tips: { string }?, -- its own tips about its station, one at a time ("RoleTip")
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
-- shopkeepers, moved up to the moon (the same names), each by the station
-- they run now. OutpostServer builds them where OutpostWorld puts them
-- (site.Crew). On duty they wear the base's uniform: a charcoal tunic, a
-- visor instead of a face (Visor), and their station's colour (Color, the
-- same as the bar on its signs: Server OutpostWorld's STATION). They talk like staff on a working
-- base: short, plain and exact, no jokes and no exclamation marks.
local UNIFORM = Color3.fromRGB(52, 56, 64)
-- Each has tips of its own about what it does (Tips, "Give me a tip":
-- the dialogue's RoleTip), and its questions under one topic, so its
-- menu stays short.
local function crew(from: string, role: string, color: Color3, greeting: string, options: { Option }, tips: { string }?): Vendor
	return {
		Name = Vendors[from].Name,
		Role = role,
		Color = color,
		Tunic = UNIFORM,
		Face = "",
		Visor = true,
		Greeting = greeting,
		Options = options,
		Tips = tips,
	}
end
local TIP = { Text = "Give me a tip", Action = "RoleTip" }

Vendors.GemBuyer = crew(
	"Cutting",
	"Gem Buyer",
	Color3.fromRGB(226, 190, 112),
	"Ilsa, gem buyer. I grade loose gems and pay coins on the spot, at the Market rate. Gems your loadouts use are never part of an offer.",
	{
		{ Text = "Appraise my spare gems", Action = "Appraise" },
		{ Text = "Sell a specific gem", Action = "SellGems" },
		{
			Text = "Gems and prices",
			Options = {
				{
					Text = "How are gems valued?",
					Reply = "Rarity sets the base: one Legendary outweighs a pouch of Commons. Size, Clarity and Cut are each graded 1 to 10, and every point raises the price.",
				},
				{
					Text = "Which gems do you buy?",
					Reply = "Any loose gem in your pouch. An appraisal only counts spares: gems used by any of your loadouts are left out.",
				},
				{
					Text = "Which gems should I keep?",
					Reply = "A few Commons for your kaiju: AUTO HEAL spends them first. Gems of your kaiju's elements, to heal and enchant them. Anything rarer you might socket. Sell the rest.",
				},
			},
		},
		TIP,
	},
	{
		"Keep a few spare Commons. AUTO HEAL spends them first to heal your kaiju.",
		"A gem of your kaiju's own element heals it twice as much. Keep some of each element your team uses.",
		"A kaiju takes an enchant only from a gem of its own element. Bring me the ones that don't fit your team.",
		"Two gems of the same rarity can be worth very different amounts. Every point of Size, Clarity and Cut raises my offer.",
		"Gems your loadouts use are never part of my offer, so selling everything I appraise is safe.",
		"Check the Market before you sell me a Legendary. Another miner may pay more than I do.",
	}
)
Vendors.ArenaMaster = crew(
	"Arena",
	"Arena Master",
	Color3.fromRGB(214, 84, 70),
	"Brutus, arena master. I set up the 1v1 duels: ranked and casual. Say the word and I'll find you an opponent.",
	{
		{ Text = "Find me a duel", Action = "Duels" },
		{
			Text = "Duels and rewards",
			Options = {
				{
					Text = "How do duels work?",
					Reply = "Ranked puts your rating on the line, best of three rounds. Casual is the same fight with nothing at stake. Queue at my counter and I'll match you.",
				},
				{
					Text = "What do I get for winning?",
					Reply = "Every 1v1 you win from the queue pays a win reward: two pieces of gear, you keep one. The other goes to the Market and you get a quarter of its sale. The more 1v1s you play, the rarer the rolls.",
				},
				{
					Text = "What does a win streak pay?",
					Reply = "Ranked wins in a row. At 10, 20 and on up to 200 it opens an Arena Cache and pays coins, with titles at 30, 50, 100, 150 and 200. Your first, fifth and tenth wins of a run also restore swings. A loss ends the run.",
				},
				{
					Text = "Where are the bounties?",
					Reply = "Marlo's office, east wall, under the posters. Every boss behind the Rift Gates is up there.",
				},
			},
		},
		TIP,
	},
	{
		"Every 1v1 you finish counts toward your reward rolls, win or lose. At 10 you're a Regular, at 25 a Veteran, at 50 Elite.",
		"Beating the same player twice in a row pays nothing the second time. Find new opponents.",
		"Win rewards wait until you claim them, up to twelve. Claim them so the next ones can come.",
		"Ranked is best of three. Lose a round and you can AUTO COUNTER: your armor and gems change to resist what hit you.",
		"Casual has no rating at stake. Try a new loadout there before you take it into Ranked.",
		"Raise your guard just before a hit lands to parry: you take far less damage and stun your opponent.",
	}
)
Vendors.BountyClerk = {
	Name = "Marlo",
	Role = "Bounty Clerk",
	Color = Color3.fromRGB(240, 178, 48),
	Tunic = UNIFORM,
	Face = "",
	Visor = true,
	Greeting = "Marlo, bounty clerk. Every boss behind the Rift Gates is posted on this wall. Pick a target and I'll send you through.",
	Options = {
		{ Text = "Show me the bounties", Action = "Bounties" },
		{
			Text = "How do bounties work?",
			Reply = "Every boss on the wall is one of the Rift's. Pick a biome and a target and you go through from here, your party with you. Each one opens once you've beaten the one before it. Down it and its cache is yours.",
		},
		{
			Text = "Which one should I take first?",
			Reply = "The first on any ladder is built for one. The last on each is built for a party. Start where your gear is strongest against the biome's element.",
		},
		TIP,
	},
	Tips = {
		"Threat I bosses are built for one miner. Threat III is built for two to four of you.",
		"A boss cache is two pieces of gear: keep one, the other goes to the Market with your cut. Higher threats roll rarer: Uncommon at least on threat I, Rare on II, Ultra-Rare on III.",
		"Every boss has a favourite kind of gear. One of the two pieces in its cache is always that kind.",
		"Each biome has its own element. Socket gems that resist it before you go through.",
		"Everyone still standing when the boss falls gets a cache of their own. Bring your party.",
		"Once the boss falls you have 20 seconds to reach a way home, and nothing attacks you on the way.",
		"Your kaiju come with you. In a boss fight their HYPERBEAM goes into the boss alone.",
	},
}
-- Wren, the Kaiju Kennel's keeper (Shared.KaijuKennel), by the pen's gate:
-- who's in the pen today, the Kaiju of the Day, kaiju on the Market.
Vendors.KaijuKeeper = {
	Name = "Wren",
	Role = "Kaiju Keeper",
	Color = Color3.fromRGB(124, 214, 98),
	Tunic = UNIFORM,
	Face = "",
	Visor = true,
	Greeting = "Wren, kennel keeper. The rarest kinds on the moon live in this pen, a different few every day. Look all you like: they don't bite through the fence.",
	-- (The starter kaiju roll is Wren's to give: it isn't in the intro.)
	OwedGreeting = "New here? Every miner gets a team of kaiju to fight beside them, and yours are waiting. Let's roll them!",
	Options = {
		{ Text = "Roll my free kaiju", Action = "KaijuStarterRoll", Only = "KaijuRollOwed" },
		{ Text = "Daily Kaiju Sale", Action = "KennelSale" },
		{ Text = "Buy and sell kaiju", Action = "KaijuMarket" },
		{
			Text = "Kaiju and their kinds",
			Options = {
				{
					Text = "Why are these ones rare?",
					Reply = "They're from the first batch of kinds found past the starters: they turn up least in the wild and least in rolls. The pen only ever holds those.",
				},
				{
					Text = "How do I get one?",
					Reply = "Catch one out in the quarry when it's worn down, win it in a roll, buy one from another miner on the Market, or take today's from the plinth by the gate.",
				},
				{
					Text = "What's the Daily Kaiju Sale?",
					Reply = "Each day one of the rarest kinds stands on the plinth by the gate, and you can take one home, that day only. And once, a Starter Rare Roll: one roll on the rarest kinds.",
				},
				{ Text = "Who's in the pen today?", Action = "KennelToday" },
			},
		},
		-- (While the free roll's owed it takes the tip's row: five at most.)
		{ Text = TIP.Text, Action = TIP.Action, Only = "KaijuRollDone" },
	},
	Tips = {
		"The kaiju in the pen change at midnight, server time. Come back tomorrow for a new few.",
		"A kaiju's element decides what it resists and what it hits hardest. Mix elements in your team.",
		"Catch a wild kaiju when its health is low: the lower it is, the better your chances.",
		"A Warden heals and shields the rest of your team. Keep one in your support slot.",
		"Kaiju of the rarest kinds are worth the most on the Market. Check the prices before you sell.",
		"No two kaiju are the same: each is born with its own Might, Vigor, Guard and Speed. Grade S is the best there is.",
	},
}
Vendors.Broker = crew(
	"Market",
	"Trade Broker",
	Color3.fromRGB(96, 186, 156),
	"Tamsin, trade broker. Every player listing for gems and gear clears through this board.",
	{
		{ Text = "Open the Market", Action = "Market" },
		{
			Text = "How does the Market work?",
			Reply = "List a gem or a piece of gear at your asking price, or make an offer on another miner's listing. Coins change hands when the sale clears.",
		},
		{
			Text = "Where do I get coins?",
			Reply = "Sell spare gems to Ilsa at the Gem Gallery, complete your daily challenges, or sell on this board.",
		},
		TIP,
	},
	{
		"You can have six listings up at once. Each stays up for 48 hours, then comes back to you.",
		"The board keeps 5% of the price when something sells.",
		"A listed item leaves your bag at once and waits safely until it sells or comes back. Nothing can be sold twice.",
		"Gear goes up with an empty socket. Its gem comes back to your pouch first.",
		"The piece you don't keep from a reward goes up from the Arena Vault or the Rift Vault. When it sells, a quarter of the price is yours.",
		"Set a trade listing to ask for gear, gems or anything Rare or better, and let other miners make you offers.",
	}
)
Vendors.Outfitter = crew(
	"Forge",
	"Outfitter",
	Color3.fromRGB(122, 150, 214),
	"Borin, outfitter. Suits, helmets, picks and weapon skins. Everything on these stands is available in the Store.",
	{
		{ Text = "Open the Store", Action = "Store" },
		{
			Text = "Do skins change my stats?",
			Reply = "No. Everything here is cosmetic. Your gear's rolls and socketed gems stay exactly as they are.",
		},
		{
			Text = "What's on the stands?",
			Reply = "Suits, helmets, visors, picks and weapon skins, a few at a time. The stands change every 40 seconds.",
		},
		TIP,
	},
	{
		"Skins never change stats. Wear what you like.",
		"Every helmet's visor comes in the same standard colour. A visor skin is how you change it.",
		"The stands change every 40 seconds. Wait a few minutes to see everything on sale.",
		"A pick skin changes how your pick and its hits look. Your swings stay the same.",
		"The Season Path's free track gives skins just for playing.",
		"Animated skins move everywhere: in first person, in your Inventory and in the Store.",
	}
)
Vendors.Foreman = crew(
	"Mining",
	"Mining Foreman",
	Color3.fromRGB(240, 178, 48),
	"Garrick, mining foreman. The quarry is through the main door. Every rock you break yields one gem. The richer ground is farther out, and so is the rift activity.",
	{
		{ Text = "Buy swing refills", Action = "Exchange" },
		{
			Text = "The quarry",
			Options = {
				{
					Text = "Where is the best ground?",
					Reply = "Yield improves with distance. The Fringe starts 150 studs out, the Edge at 300. Three Rift Veins surface by the crater walls; one of them is guarded.",
				},
				{
					Text = "What are those critters?",
					Reply = "Rift critters. Activity rises the longer you work outside the Core. Keep your kaiju close: if your whole team goes down out there, the critters come for your gems.",
				},
				{
					Text = "My swings ran out",
					Reply = "Your pick recharges a swing every 24 seconds. I keep refills in stock, and ranked 1v1 win streaks restore swings.",
				},
			},
		},
		TIP,
	},
	{
		"Don't work past the Core with no kaiju out. Alone, the critters come at you harder.",
		"Rift Veins move from time to time. Their rocks are the luckiest in the quarry.",
		"Clear a wandering rift and everyone who helped is Rift Charged: luckier gems for 60 seconds.",
		"Only gems from this trip can be stolen. Get back to the Core and they're safe.",
		"Out in the quarry nothing mends. Come back to the Shelter when you're hurt.",
		"Refills you buy are used before your free charge.",
	}
)

-- INFO-9, the Shelter's information unit: a robot by its kiosk near the
-- door, with answers to what new miners ask (by topic) and a field tip
-- whenever you want one. Its answers keep to the rules as they are
-- (Shared.GemRoller's odds, Shared.Kaiju's healing and revives, Shared.
-- Frontier's bands, rifts and raids, Server HealthRegen's lobby healing,
-- the swing refills): change those and change these.
Vendors.InfoBot = {
	Name = "INFO-9",
	Role = "Information",
	Color = Color3.fromRGB(200, 214, 228),
	Tunic = UNIFORM,
	Face = "",
	Visor = true,
	Greeting = "INFO-9, base information. Choose a topic, or ask for a field tip.",
	Options = {
		{ Text = "Give me a field tip", Action = "Tip" },
		{
			Text = "Mining and gems",
			Options = {
				{
					Text = "How does mining work?",
					Reply = "Walk into a rock, or click or tap it, and your pick swings: in a mech too. Every rock yields one gem when it breaks, and broken rocks grow back. Crystal Boulders take more swings than Regolith Chunks, and their gems roll rarer.",
				},
				{
					Text = "What are the odds?",
					Reply = "For every gem: Common 60%, Uncommon 25%, Rare 11%, Ultra-Rare 3.5%, Legendary 0.5%. Luck shifts those odds toward the rarer tiers.",
				},
				{
					Text = "Why mine farther out?",
					Reply = "Luck. The Core around the Shelter is safe and adds none. Past 150 studs, the Fringe adds luck to every gem; past 300, the Edge adds more. Rift activity rises with it.",
				},
				{
					Text = "What do I do with spare gems?",
					Reply = "Sell them to Ilsa at the Gem Gallery for coins, list them on the Market, or use them to heal your kaiju.",
				},
			},
		},
		{
			Text = "Kaiju",
			Options = {
				{
					Text = "How do kaiju fight?",
					Reply = "Your team of three follows you and fights on its own: they split up the targets and flank them. They gain experience by fighting, not from your mining.",
				},
				{
					Text = "How do I heal them?",
					Reply = "Once you're clear of danger, open the kaiju panel's HEAL tab and give them gems. Rarer gems heal more, and a gem of their own element heals twice as much. AUTO HEAL spends Commons first, then Uncommons.",
				},
				{
					Text = "One got knocked out",
					Reply = "It recovers on its own after a cooldown, longer at higher levels, and comes back at 15% health: heal it with gems. Or revive it now for Robux, at half health.",
				},
				{
					Text = "How do I catch a wild kaiju?",
					Reply = "Challenge one in the quarry and wear it down below half health without knocking it out: it glows gold. Then press CATCH and hold it in your gem's light. Taking a hit or moving off breaks the catch.",
				},
			},
		},
		{
			Text = "Threats and safety",
			Options = {
				{
					Text = "What are rift critters?",
					Reply = "Hostiles that come through rifts beyond the Core, more often the longer you work out there. Hit them with your pick to drive them back: it costs no swings. Go out with no kaiju beside you and they come sooner, more of them, tougher, and hit you harder.",
				},
				{
					Text = "What is a gem raid?",
					Reply = "If your whole kaiju team is knocked out beyond the Core, more critters come for you. They never knock you down: you're killed or you're not. Killed out there, they rob the newest gems from your trip. Hit a thief before it reaches its rift and the gem comes back. Back in the Core, your gems are safe.",
				},
				{
					Text = "How do I recover health?",
					Reply = "Only back at base. Out in the quarry nothing mends: walk back into the Shelter (or down to the Kaiju Arena) and a couple of seconds after your last hit your health refills fast. Sparring and being knocked down pause it.",
				},
				{
					Text = "My swings ran out",
					Reply = "Your free pick gets a swing back every 24 seconds and is full again in four hours. Garrick sells refills, and ranked 1v1 win streaks restore swings.",
				},
			},
		},
	},
}

-- INFO-9's field tips, given in turn from a random start ("Tip"). Each is
-- one fact, stated plainly; like the answers above, they keep to the rules.
Vendors.Tips = {
	-- Mining
	"Crystal Boulders take more swings than Regolith Chunks, but their gems roll rarer.",
	"Every rock yields exactly one gem, and broken rocks grow back. A picked-over field fills up again.",
	"The Fringe starts 150 studs from the Shelter and adds luck to every gem. The Edge starts at 300 and adds more.",
	"Three Rift Veins surface by the crater walls and move from time to time. They are the richest ground in the quarry.",
	"One Rift Vein is guarded. Bring your whole team before you go near it.",
	"Clear a wandering rift and every miner who helped is Rift Charged: luckier gems for 60 seconds.",
	"Your free pick gets a swing back every 24 seconds. A full charge takes four hours.",
	"Swings bought as refills are used before your free charge.",
	-- Threats
	"Rift activity rises the longer you work beyond the Core.",
	"Your pick drives critters back, and hitting them costs no swings.",
	"A critter winding up a TRIP shows it on its cast bar. Step out of reach or hit it to cancel it.",
	"If your whole kaiju team goes down beyond the Core, critters raid your gems. Hit a thief before it reaches its rift to get the gem back.",
	"Only loose gems from your current trip can be stolen. Gems socketed in your gear are always safe.",
	"Gems from your trip are safe again once you're back in the Core.",
	"Back at the Shelter your health refills on its own a few seconds after your last hit. Out in the quarry nothing mends.",
	"A creature's outline shows its health: green is healthy, amber is worn down, red is nearly done.",
	"Wild kaiju and gem thieves stay outlined through rocks and walls, so you can track them.",
	-- Kaiju
	"Kaiju don't heal on their own. Give them gems once you're clear of danger.",
	"A gem of a kaiju's own element heals it twice as much.",
	"Your support kaiju mends you and your team only during a fight. Between fights, gems do the healing.",
	"AUTO HEAL spends spare Commons first, then Uncommons. It never uses a rarer gem or one your loadouts use.",
	"Kaiju gain experience by fighting. Your mining levels you, not them.",
	"You level fastest by beating bosses and other players, more for ones above your level. Mining gives less the more you mine.",
	"A knocked-out kaiju comes back on its own after a cooldown. The higher its level, the longer it takes.",
	"To catch a wild kaiju, wear it down below half health without knocking it out. It glows gold when it's ready.",
	"A catch breaks if you take a hit or move away. Clear the area first.",
	"Kaiju battles are in the Kaiju Arena, down the Shelter's west stairs. Stand on a pad and wait for a challenger: you both get 25 seconds to place your kaiju.",
	"Every kaiju fights a kaiju battle at full health, and goes back to its health from before once it's over, win or lose. The winner takes both stakes.",
	"Bulwarks and Carapaces take hits well: put them in the front row of a battle formation.",
	"Razorbacks fight at range: keep them in the back row of a battle formation.",
	"Scythes are assassins: at the start of a battle they leap over the front line onto the other side's ranged kaiju.",
	-- Combat
	"Raise your guard just before a melee hit lands to parry: you take far less damage, spend no stamina and stun your rival.",
	"Hold your swing and release it on gold for a perfect hit.",
	"Your sword's gem gives you Q, your chest's E and your shield's R. Swap a gem to swap the move.",
	"Thermal beats Cryo, Cryo beats Ion, Ion beats Corrosive and Corrosive beats Thermal.",
	"Press Z by another miner to ask to spar. In a spar, only the two of you can hit each other.",
	"Arena win streaks restore swings: a tenth on the first win, a quarter on the fifth, half on the tenth.",
	"A loss ends your win streak. Choose your duels carefully.",
	-- The base
	"Ilsa never makes an offer for gems your loadouts use, so selling your spares is safe.",
	"Skins never change stats. Your gear's rolls and gems stay as they are.",
	"The Store's stands change every 40 seconds. Wait a few minutes to see everything on sale.",
	"Mechs are parked in Bays 1 to 8. Drive out either garage door and down its ramp.",
	"Mechs are for getting around. They can't mine or fight.",
	"Daily challenges change every day. Finish all three for a bonus.",
}

-- COACH-4, the Kaiju Arena's guide: a robot on the hall's balcony, by
-- where you arrive downstairs, with answers on battles, placing, the
-- kinds of kaiju, elements and stakes, and a battle tip whenever you want
-- one ("ArenaTip", from Vendors.ArenaTips). Like INFO-9's, its answers
-- keep to the rules as they are (Shared.KaijuBattle's seconds, EXP and
-- sides, Shared.Kaiju's species and Shared.ElementMatchup's matchups,
-- Shared.KaijuPit's stakes, Server.KaijuServer's full health and back):
-- change those and change these.
Vendors.ArenaGuide = {
	Name = "COACH-4",
	Role = "Kaiju Arena Guide",
	Color = Color3.fromRGB(240, 178, 48),
	Tunic = UNIFORM,
	Face = "",
	Visor = true,
	Greeting = "COACH-4, Kaiju Arena. Ask me how battles work, or take a tip before your next one.",
	Options = {
		{ Text = "Give me a battle tip", Action = "ArenaTip" },
		{
			Text = "How battles work",
			Options = {
				{
					Text = "How do I start a battle?",
					Reply = "Stand on a pad at either end of a court and wait. When someone steps onto the other pad, they press FIGHT. Or press KAIJU on someone's player card upstairs: you're both brought down to a free court.",
				},
				{
					Text = "What happens in a battle?",
					Reply = "You both get 25 seconds to place your kaiju on your half of the court. Then they fight on their own for up to 90 seconds. A side whose kaiju are all down loses. If time runs out, the side with more health left wins.",
				},
				{
					Text = "What happens to my kaiju's health?",
					Reply = "Every kaiju fights at full health, even ones that were knocked out. When the battle ends, each goes back to the health it had before, win or lose.",
				},
				{
					Text = "Can we go again?",
					Reply = "When a battle ends, both press REMATCH within 12 seconds. You go again on the same court, on the same sides, for the same stake, taken again.",
				},
			},
		},
		{
			Text = "Placing and elements",
			Options = {
				{
					Text = "Front row or back row?",
					Reply = "The front row takes the blows: put your tanks (Carapaces) and warriors (Bulwarks) there. Keep a Razorback behind them: it shoots from the back row. A Scythe starts at the back too, then leaps over their front line.",
				},
				{
					Text = "How do I place them?",
					Reply = "Drag a kaiju onto a spot, or tap it and then tap a spot. Drop it on another kaiju to swap them. AUTO puts them back where they start. When you both press READY, the fight starts early.",
				},
				{
					Text = "Which kaiju is which?",
					Reply = "Carapace, TANK: shrugs off a quarter of every hit; its roar makes foes attack it. Bulwark, WARRIOR: heavy blows up close. Razorback, RANGED: shoots from the back, but it's fragile. Scythe, ASSASSIN: leaps onto their ranged kaiju and cuts fast, but falls fast.",
				},
				{
					Text = "Which element beats which?",
					Reply = "Thermal beats Cryo, Cryo beats Ion, Ion beats Corrosive, and Corrosive beats Thermal. A kaiju takes 125% damage from the element that beats its own and 75% from its own. Then its kind's guard comes off.",
				},
			},
		},
		{
			Text = "Sides, stakes and rewards",
			Options = {
				{
					Text = "Which side am I?",
					Reply = "The BLUE pad is the blue side, the RED pad the red side, and each kaiju stands on a ring in its side's colour. Once the fight starts, the camera rises over your end of the court: drag to look around, scroll or pinch to zoom.",
				},
				{
					Text = "What can we play for?",
					Reply = "Nothing, 50 to 1000 coins each, or one of your loose gems. The one waiting on the pad sets it. A gem stake is matched by a gem of the same rarity or better.",
				},
				{
					Text = "Who gets the stake?",
					Reply = "The winner takes both stakes. In a draw, each gets their own back. Going back up the stairs mid-battle counts as a loss. Only loose gems can be staked, never the gems in your gear.",
				},
				{
					Text = "What do I get for a battle?",
					Reply = "Experience for every kaiju of yours: 40 for a win, 24 for a draw, 14 for a loss. If you played for a stake, the winner takes both.",
				},
			},
		},
	},
}

-- COACH-4's battle tips, given in turn from a random start ("ArenaTip").
-- Each one fact, stated plainly; they keep to the rules, like its answers.
Vendors.ArenaTips = {
	"Every kaiju fights at full health, even knocked-out ones, and goes back to its health from before once the battle's over.",
	"Thermal beats Cryo, Cryo beats Ion, Ion beats Corrosive and Corrosive beats Thermal.",
	"A kaiju takes 125% damage from the element that beats its own, and only 75% from its own.",
	"Carapaces shrug off a quarter of every blow and Bulwarks a tenth. They hold the front row.",
	"A Razorback shoots from the back row. In front, it takes blows it can't survive.",
	"A Scythe leaps over the front line onto your ranged kaiju as the battle starts. It has the least health of any kaiju, so hit it back hard.",
	"If time runs out, the side with more health left wins. A sturdy front row wins long battles.",
	"Press READY once you're placed. If your foe is ready too, the fight starts at once.",
	"Both press REMATCH in the 12 seconds after a battle to go again on the same court, for the same stake.",
	"During a battle, drag to look around the court, and scroll or pinch to zoom.",
	"Every kaiju of yours earns experience from a battle: 40 for a win, 24 for a draw, 14 for a loss.",
	"Going back up the stairs mid-battle counts as a loss, and your stake goes to your foe.",
	"A kaiju's Q wakes at level 5 and its R at level 10. Higher-level kaiju bring more moves to a battle.",
	"Each kaiju casts its E when its mana is full. Mana fills as it hits and as it's hit, so a tank roars sooner the harder it's pushed.",
	"One foe down, a kaiju goes straight for the next one near it. Ranged kaiju pick off the weakest one in range.",
	"Your foe's places stay hidden until the fight starts, and so do yours.",
	"A team of mixed elements is hard to counter. In a rematch you've seen your foe's team: put the kaiju whose element beats theirs in front.",
	"Anyone down here can watch a battle from the aisles and the balcony. The board over each court shows both sides' health.",
}

return Vendors
