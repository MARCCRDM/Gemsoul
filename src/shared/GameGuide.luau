--[[
	The GUIDE window's words (Client GuideUI): what the game is and how to
	play it, a page a topic, a few short tips a page. Each tip has the key or
	button it's about (Key on a computer, Phone on a phone, Phone = false: not on
	a phone; none: a number in its place), a title and one or two short lines.

	  GameGuide.Sections   { Id, Title, Blurb, Tips = { { Key?, Phone?, Title, Text } } }
	  GameGuide.section(id) -> section?
	  GameGuide.closeFor(features)   leaves out tips for switched-off features
	                         (Config.Features: Needs on a tip)
]]
local GameGuide = {}

GameGuide.Sections = {
	{
		Id = "Start",
		Title = "START HERE",
		Blurb = "Mine gems, build your gear, fight with your kaiju.",
		Tips = {
			{ Title = "Mine", Text = "Break rocks in the Outpost. Every rock holds a gem." },
			{ Title = "Gear up", Text = "Socket gems into your gear in Inventory to get stronger." },
			{ Title = "Team up", Text = "Your kaiju fight beside you. Catch more in the wild.", Needs = "Kaiju" },
			{ Title = "Fight", Text = "Beat rivals, real players and Rift bosses for loot." },
			{ Title = "Not sure what's next?", Text = "Open TASKS: it shows your next step and pays coins." },
		},
	},
	{
		Id = "Controls",
		Title = "CONTROLS",
		Blurb = "Everything you press, in one place.",
		Tips = {
			{
				Key = "CLICK",
				Phone = "ATTACK",
				Title = "Attack or mine",
				Text = "Swing at an enemy or a rock. Keep swinging for combos.",
			},
			{
				Key = "R-CLICK",
				Phone = "GUARD",
				Title = "Block",
				Text = "Hold to guard. Block just before a hit for a perfect block.",
			},
			{ Key = "SPACE", Phone = "DODGE", Title = "Dodge", Text = "Roll out of the way of a big attack." },
			{
				Key = "Q E R",
				Phone = "GEMS",
				Title = "Surges",
				Text = "Cast your gems' powers when your Charge is full.",
			},
			{
				Key = "X",
				Phone = "FIGHT",
				Title = "Mine or fight",
				Text = "Swap between your pickaxe and your combat kit.",
			},
			{ Key = "TAB", Phone = false, Title = "Switch target", Text = "Lock onto the next enemy near you." },
			{
				Key = "1-4",
				Phone = "1-4",
				Title = "Kaiju teams",
				Text = "Swap which kaiju team is out.",
				Needs = "Kaiju",
			},
			{
				Key = "Z",
				Phone = "BEAM",
				Title = "HYPERBEAM",
				Text = "Your kaiju's combined blast, once it's charged.",
				Needs = "Kaiju",
			},
			{
				Key = "C",
				Phone = "CATCH",
				Title = "Catch",
				Text = "Catch a wild kaiju when its plate says CATCH.",
				Needs = "Kaiju",
			},
		},
	},
	{
		Id = "Mining",
		Title = "MINING & GEMS",
		Blurb = "Your next upgrade is in the rock.",
		Tips = {
			{
				Title = "Every rock pays",
				Text = "Each rock takes a few swings and always drops a gem. Walk into a rock to keep mining.",
			},
			{ Title = "Rarity", Text = "Common, Uncommon, Rare, Ultra Rare, Legendary. Rarer gems are stronger." },
			{
				Title = "Elements",
				Text = "Thermal, Cryo, Ion and Corrosive. Hit a weakness and it says WEAK!; a resisted hit says RESIST.",
			},
			{
				Title = "Richer further out",
				Text = "Rocks get richer the further you go from the Shelter, and so does the danger.",
			},
			{ Title = "Spare gems", Text = "Extra gems heal your kaiju or sell on the Market." },
		},
	},
	{
		Id = "Gear",
		Title = "GEAR & SURGES",
		Blurb = "Gems make your gear, and you, stronger.",
		Tips = {
			{
				Title = "Socket gems",
				Text = "In Inventory, pick a piece of gear and drop a gem into it. Its stats join yours.",
			},
			{
				Key = "Q E R",
				Phone = "GEMS",
				Title = "Surges",
				Text = "Gems in Q, E and R give you Surges: big moves you cast in fights.",
			},
			{ Title = "Charge", Text = "Landing hits builds Charge. Spend it on a Surge." },
			{ Title = "EQUIP BEST", Text = "One tap in Inventory puts your strongest gems where they count." },
		},
	},
	{
		Id = "Kaiju",
		Title = "KAIJU",
		Blurb = "Your team of monsters, fighting at your side.",
		Needs = "Kaiju",
		Tips = {
			{ Title = "Your team", Text = "Up to three kaiju fight beside you, plus a support that heals them." },
			{
				Key = "C",
				Phone = "CATCH",
				Title = "Catch more",
				Text = "Wear a wild kaiju down until it glows gold, then catch it.",
			},
			{
				Key = "Z",
				Phone = "BEAM",
				Title = "HYPERBEAM",
				Text = "Your kaiju charge it as they fight. Fire it at everything in front of you.",
			},
			{
				Title = "Healing",
				Text = "Kaiju don't heal by themselves. AUTO HEAL uses your spare gems out of combat.",
			},
			{
				Key = "1-4",
				Phone = "1-4",
				Title = "Four teams",
				Text = "Set up four teams in the kaiju menu and swap between them.",
			},
			{
				Title = "Kaiju Arena",
				Text = "Downstairs in the Shelter: place your kaiju on a pad and battle other players.",
			},
		},
	},
	{
		Id = "Outpost",
		Title = "THE OUTPOST",
		Blurb = "Your base, and the wild moon around it.",
		Tips = {
			{
				Title = "The Shelter",
				Text = "Your base: the Store, the Market, the Kennel, the garage and the bounty board. You heal here.",
			},
			{
				Title = "Critters",
				Text = "Mine long enough and critters come for you. Keep your kaiju out: alone is dangerous.",
			},
			{
				Title = "If you fall",
				Text = "Critters grab some of the gems you found most recently. Fight back or head home.",
			},
			{ Title = "Mechs", Text = "Climb into a mech in the garage to mine and smash faster.", Needs = "Mechs" },
		},
	},
	{
		Id = "Rift",
		Title = "RIFT & BOSSES",
		Blurb = "The toughest fights and the best loot.",
		Tips = {
			{
				Title = "Rift Veins",
				Text = "Glowing veins out in the quarry lead to a Rift gate. Step through to fight.",
			},
			{ Title = "Bosses", Text = "Each Rift ends in a giant boss. Watch for its big telegraphed attacks." },
			{ Title = "Better together", Text = "Bring friends from the gate's party lobby: bosses hit hard." },
			{ Title = "Loot", Text = "Beat a boss for a cache roll, and unlock the next boss on that ladder." },
		},
	},
	{
		Id = "PvP",
		Title = "1V1 & REWARDS",
		Blurb = "Test yourself, and get paid for playing.",
		Tips = {
			{ Title = "1v1 Practice", Text = "PLAY, then Practice: fight a computer miner. Safe, and it pays coins." },
			{ Title = "1v1 Ranked", Text = "Real players, best of three rounds. Swap your gear between rounds." },
			{ Title = "Daily challenges", Text = "Three a day, and a bonus for finishing all three." },
			{ Title = "Tasks", Text = "A step-by-step path through the game. Every step pays coins, once." },
		},
	},
}

function GameGuide.section(id: string)
	for _, section in GameGuide.Sections do
		if section.Id == id then
			return section
		end
	end
	return nil
end

-- Leaves out the pages and tips for switched-off features (Config.Features).
function GameGuide.closeFor(features)
	local off = {}
	for name, on in features or {} do
		if on == false then
			off[name] = true
		end
	end
	local kept = {}
	for _, section in GameGuide.Sections do
		if not (section.Needs and off[section.Needs]) then
			local tips = {}
			for _, tip in section.Tips do
				if not (tip.Needs and off[tip.Needs]) then
					table.insert(tips, tip)
				end
			end
			section.Tips = tips
			table.insert(kept, section)
		end
	end
	GameGuide.Sections = kept
end

return GameGuide
