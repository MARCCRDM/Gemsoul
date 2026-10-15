--[[
	Cosmetics: purely for looks, never stats. Rarity uses the gem tiers, so a
	rare trim glows in the same colour as a rare gem.

	  Trims   recolour your class glow (armor trim, eye slits, weapon edges).
	          Enchanted gear still takes on its gem's element.
	  Backs   something worn on your back: packs, banners, capes, wings, halos.
	  Skins   restyle whatever weapon you hold (a Palette, or a Look).
	  Suits   restyle your whole armor, every piece, whatever its style.
	  Picks   restyle the pickaxe you mine with (Shared.PickaxeLooks builds
	          each one, and how its hits land); it keeps its tier's power.
	  Titles  a tag over your head that everyone sees.

	How each is had:
	  Robux      a weapon skin, suit or pickaxe sold in the store, directly,
	             never at random (Store.RobuxProducts holds each one's
	             Developer Product id; 0 = not on sale yet)
	  (bundles)  trims and back pieces aren't sold on their own: they come
	             with store bundles (Store.Bundles) and on the Season Path
	  Exclusive  earned one way only, never sold, so it shows you did it:
	             "Invite"   bring friends (Shared.Referrals.Tiers)
	             "Group"    join the game's Roblox group (Shared.FreeRewards)
	             "Streak"   log in 7 days running (Shared.FreeRewards)
	             "Code"     a promo code (server Systems/Codes)
	             "Starter"  the one-time Starter Pack (Shared.Store)
	             "Season"   the Season Path (Shared.Season)
	             "Default"  every miner has it from the start
	             "Squad"    the Squad Bundle (all three kits, Store.Kits)
	             "Vault"    The Vault, the store's complete collection
	             "Achievement", "Ranked", "Raid", "Mining"
	                        earned in play; How says exactly how

	Equipment draws them on your avatar.
]]
local Config = require(script.Parent.Config)
local GemConfig = require(script.Parent.GemConfig)

-- A skin's or suit's colours (Equipment repaints every part with them):
-- bright plates take Plate, dark ones and wood/leather Under, neon Glow.
export type Palette = {
	Plate: Color3,
	PlateMaterial: Enum.Material,
	Under: Color3,
	UnderMaterial: Enum.Material?,
	Glow: Color3,
	Reflect: number?, -- the plates' shine (0-1)
	Sparks: Color3?, -- particles drifting off it
	Trail: boolean?, -- (skins) a streak through every swing
	Accent: Color3?, -- a second plate colour, laid out by Pattern
	AccentMaterial: Enum.Material?,
	Pattern: ("Camo" | "Stripes" | "Trim")?, -- patches, bands by height, or the small plates
	Seams: boolean?, -- the biggest plates outlined in neon (12 per armor piece, 6 on a weapon)
	Blade: Color3?, -- (skins) the blade's own colour...
	BladeMaterial: Enum.Material?, -- ...and material
	Edge: boolean?, -- (skins) the blade outlined in neon
	SeamColor: Color3?, -- the neon outline's colour (default: Glow)
	SeamWidth: number?, -- its thickness in studs (default 0.025)
	SeamFx: ("Pulse" | "Shift" | "Flicker" | "Rainbow")?, -- how it moves (SeamVisibility)
}
export type Cosmetic = {
	Id: string,
	Kind: "Trim" | "Back" | "Skin" | "Suit" | "Pick" | "Title",
	Name: string,
	Description: string,
	Rarity: string, -- a gem tier: Common, Uncommon, Rare, UltraRare
	Price: number?, -- (retired: nothing is sold for coins)
	Robux: number?, -- sold for Robux (see Store.RobuxProducts)
	Color: Color3, -- the trim colour, the back piece's glow, a title's colour
	Look: string?, -- how Equipment builds a back piece or applies a skin
	Palette: Palette?, -- a skin's or suit's colours
	Exclusive: string?, -- earned one way only (see above)
	How: string?, -- (earned ones) exactly what earns it, for the Shop
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
}

Cosmetics.List = {
	TrimEmber = {
		Id = "TrimEmber",
		Kind = "Trim",
		Name = "Ember Trim",
		Description = "Glow like a banked forge.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(255, 120, 40),
	},
	TrimGlacier = {
		Id = "TrimGlacier",
		Kind = "Trim",
		Name = "Glacier Trim",
		Description = "Cold, clear blue from the northern peaks.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(130, 220, 255),
	},
	TrimVenom = {
		Id = "TrimVenom",
		Kind = "Trim",
		Name = "Venom Trim",
		Description = "A sickly green that warns people off.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(120, 255, 90),
	},
	TrimStorm = {
		Id = "TrimStorm",
		Kind = "Trim",
		Name = "Storm Trim",
		Description = "Crackling lightning yellow.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 235, 60),
	},
	TrimAmethyst = {
		Id = "TrimAmethyst",
		Kind = "Trim",
		Name = "Amethyst Trim",
		Description = "Deep violet, cut from a flawless stone.",
		Rarity = "Rare",
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
		Color = Color3.fromRGB(0, 240, 255),
		Look = "Pack",
	},
	BackBanner = {
		Id = "BackBanner",
		Kind = "Back",
		Name = "War Banner",
		Description = "Your class colours, carried high.",
		Rarity = "Uncommon",
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
	-- Not in Order: these are never sold for coins or found in crates.
	-- Bring 1 friend: the first reward, and the rarest look you can't buy.
	SkinKindred = {
		Id = "SkinKindred",
		Kind = "Skin",
		Name = "Kindred Edge",
		Description = "Forged for two: a starlit crystal blade with strands of teal and gold winding up it round each other, its edge pulsing with starlight. Bring a friend.",
		Rarity = "Legendary",
		Color = Color3.fromRGB(60, 230, 255),
		Look = "Kindred",
		Exclusive = "Invite",
		How = "Invite a friend who joins the game.",
		Palette = {
			Plate = Color3.fromRGB(244, 172, 40), -- the hilt, and the gold strand
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(22, 18, 44),
			Glow = Color3.fromRGB(60, 230, 255), -- the teal strand
			Reflect = 0.3,
			Blade = Color3.fromRGB(30, 26, 64),
			BladeMaterial = Enum.Material.Glass,
			Edge = true,
			Seams = true,
			SeamColor = Color3.fromRGB(225, 240, 255), -- starlight
			SeamWidth = 0.036,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(150, 240, 255),
			Trail = true,
		},
	},
	SkinCrusader = {
		Id = "SkinCrusader",
		Kind = "Skin",
		Name = "Crusader Gold",
		Description = "Burnished gold and obsidian, its edge burning gold to crusader red, with a trail of sparks. On any weapon. Bring 4 friends.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 214, 110),
		Look = "Crusader",
		Exclusive = "Invite",
	},
	-- The bring-a-friend rewards (Shared.Referrals.Tiers) -------------------------
	BackStandard = {
		Id = "BackStandard",
		Kind = "Back",
		Name = "Crusader's Standard",
		Description = "A black war banner on an iron pole, edged in gold. Bring 3 friends.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 205, 90),
		Look = "Standard",
		Exclusive = "Invite",
	},
	SuitCrusader = {
		Id = "SuitCrusader",
		Kind = "Suit",
		Name = "Crusader Plate",
		Description = "White enamel and burnished gold, its seams burning from gold to crusader red. Bring 5 friends.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 214, 110),
		Palette = {
			Plate = Color3.fromRGB(232, 228, 218),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(190, 144, 48),
			UnderMaterial = Enum.Material.Foil,
			Glow = Color3.fromRGB(230, 40, 56),
			Reflect = 0.15,
			Seams = true,
			SeamColor = Color3.fromRGB(255, 184, 40),
			SeamWidth = 0.03,
			SeamFx = "Shift",
			Sparks = Color3.fromRGB(255, 226, 140),
		},
		Exclusive = "Invite",
	},
	TitleLegend = {
		Id = "TitleLegend",
		Kind = "Title",
		Name = "CRUSADER LEGEND",
		Description = "Over your head, in gold, for everyone to see. Bring 10 friends.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 205, 90),
		Exclusive = "Invite",
	},
	-- Ranked win streaks (Shared.ArenaStreak) ----------------------------------------
	TitleStreak30 = {
		Id = "TitleStreak30",
		Kind = "Title",
		Name = "GLADIATOR",
		Description = "Over your head for everyone to see: 30 Ranked wins in a row.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 160, 90),
		Exclusive = "Ranked",
		How = "Win 30 Ranked 1v1 matches in a row.",
	},
	TitleStreak50 = {
		Id = "TitleStreak50",
		Kind = "Title",
		Name = "WARLORD",
		Description = "Over your head for everyone to see: 50 Ranked wins in a row.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 110, 80),
		Exclusive = "Ranked",
		How = "Win 50 Ranked 1v1 matches in a row.",
	},
	TitleStreak100 = {
		Id = "TitleStreak100",
		Kind = "Title",
		Name = "CENTURION",
		Description = "Over your head for everyone to see: 100 Ranked wins in a row. Almost nobody gets here.",
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 205, 90),
		Exclusive = "Ranked",
		How = "Win 100 Ranked 1v1 matches in a row.",
	},
	TitleStreak150 = {
		Id = "TitleStreak150",
		Kind = "Title",
		Name = "UNTOUCHABLE",
		Description = "Over your head for everyone to see: 150 Ranked wins in a row.",
		Rarity = "Legendary",
		Color = Color3.fromRGB(170, 120, 255),
		Exclusive = "Ranked",
		How = "Win 150 Ranked 1v1 matches in a row.",
	},
	TitleStreak200 = {
		Id = "TitleStreak200",
		Kind = "Title",
		Name = "ARENA LEGEND",
		Description = "Over your head for everyone to see: 200 Ranked wins in a row. The Arena remembers.",
		Rarity = "Legendary",
		Color = Color3.fromRGB(120, 240, 255),
		Exclusive = "Ranked",
		How = "Win 200 Ranked 1v1 matches in a row.",
	},
	-- Free, one way each (Shared.FreeRewards, Systems/Codes) ----------------------
	SkinStarforged = {
		Id = "SkinStarforged",
		Kind = "Skin",
		Name = "Starforged",
		Description = "Pale star-metal with an electric-blue edge. Join the group.",
		Rarity = "Rare",
		Color = Color3.fromRGB(190, 225, 255),
		Palette = {
			Plate = Color3.fromRGB(160, 180, 210),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(24, 34, 64),
			Glow = Color3.fromRGB(90, 120, 255),
			Reflect = 0.35,
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			Sparks = Color3.fromRGB(220, 240, 255),
			Trail = true,
		},
		Exclusive = "Group",
	},
	SkinDaybreak = {
		Id = "SkinDaybreak",
		Kind = "Skin",
		Name = "Daybreak",
		Description = "Sunrise on a blade: peach-gold edges warming into violet dawn light.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 160, 120),
		Palette = {
			Plate = Color3.fromRGB(214, 150, 124),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(56, 30, 80),
			Glow = Color3.fromRGB(190, 120, 255),
			Reflect = 0.2,
			Blade = Color3.fromRGB(246, 196, 170),
			BladeMaterial = Enum.Material.Foil,
			Edge = true,
			Seams = true,
			SeamColor = Color3.fromRGB(255, 180, 120),
			SeamWidth = 0.03,
			SeamFx = "Shift",
			Sparks = Color3.fromRGB(255, 196, 150),
			Trail = true,
		},
		Exclusive = "Streak",
	},
	TitleFounder = {
		Id = "TitleFounder",
		Kind = "Title",
		Name = "FOUNDER",
		Description = "You were here at the start. From a launch code.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(120, 230, 255),
		Exclusive = "Code",
	},
	TitleSquad = {
		Id = "TitleSquad",
		Kind = "Title",
		Name = "FULL SQUAD",
		Description = "All three miners kitted out. Only in the Squad Bundle.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 176, 72),
		Exclusive = "Squad",
	},
	TitleCollector = {
		Id = "TitleCollector",
		Kind = "Title",
		Name = "COLLECTOR",
		Description = "Every look in the store. Only in The Vault.",
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 214, 120),
		Exclusive = "Vault",
	},
	-- Weapon skins for Robux --------------------------------------------------------
	SkinPlasma = {
		Id = "SkinPlasma",
		Kind = "Skin",
		Name = "Plasma Edge",
		Description = "Gunmetal with a cyan plasma edge that streaks through every swing.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(80, 230, 255),
		Palette = {
			Plate = Color3.fromRGB(50, 56, 70),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(18, 22, 30),
			Glow = Color3.fromRGB(40, 235, 255),
			Reflect = 0.25,
			Blade = Color3.fromRGB(66, 72, 86),
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			Sparks = Color3.fromRGB(150, 245, 255),
			Trail = true,
		},
	},
	SkinMolten = {
		Id = "SkinMolten",
		Kind = "Skin",
		Name = "Molten Core",
		Description = "Cooling basalt split by rivers of lava. It drips embers.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(255, 120, 30),
		Palette = {
			Plate = Color3.fromRGB(46, 36, 34),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(20, 16, 16),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(255, 110, 20),
			Blade = Color3.fromRGB(70, 40, 30),
			BladeMaterial = Enum.Material.CrackedLava,
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(255, 160, 60),
			Trail = true,
		},
	},
	SkinToxic = {
		Id = "SkinToxic",
		Kind = "Skin",
		Name = "Toxic Ooze",
		Description = "Glowing green sludge over black steel. Handle with gloves.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(140, 255, 90),
		Palette = {
			Plate = Color3.fromRGB(44, 74, 40),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(16, 22, 18),
			Glow = Color3.fromRGB(150, 255, 90),
			Reflect = 0.3,
			Blade = Color3.fromRGB(120, 230, 80),
			BladeMaterial = Enum.Material.Glass,
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			Sparks = Color3.fromRGB(170, 255, 120),
			Trail = true,
		},
	},
	SkinVoid = {
		Id = "SkinVoid",
		Kind = "Skin",
		Name = "Void Crystal",
		Description = "Violet crystal from the far side of nothing, its edge flickering violet to cyan.",
		Rarity = "UltraRare",
		Robux = 149,
		Color = Color3.fromRGB(220, 90, 255),
		Palette = {
			Plate = Color3.fromRGB(70, 36, 124),
			PlateMaterial = Enum.Material.Glass,
			Under = Color3.fromRGB(20, 10, 34),
			Glow = Color3.fromRGB(90, 220, 255),
			Reflect = 0.4,
			Blade = Color3.fromRGB(120, 70, 210),
			Edge = true,
			Seams = true,
			SeamColor = Color3.fromRGB(230, 90, 255),
			SeamWidth = 0.034,
			SeamFx = "Shift",
			Sparks = Color3.fromRGB(240, 170, 255),
			Trail = true,
		},
	},
	SkinGalaxy = {
		Id = "SkinGalaxy",
		Kind = "Skin",
		Name = "Galaxy",
		Description = "A slice of the night sky, edged in light that runs through every colour.",
		Rarity = "UltraRare",
		Robux = 199,
		Color = Color3.fromRGB(150, 140, 255),
		Palette = {
			Plate = Color3.fromRGB(34, 30, 92),
			PlateMaterial = Enum.Material.Glass,
			Under = Color3.fromRGB(10, 10, 26),
			Glow = Color3.fromRGB(255, 120, 220),
			Reflect = 0.5,
			Blade = Color3.fromRGB(44, 40, 120),
			Edge = true,
			Seams = true,
			SeamWidth = 0.034,
			SeamFx = "Rainbow",
			Sparks = Color3.fromRGB(230, 230, 255),
			Trail = true,
		},
	},
	-- Armor suits for Robux -------------------------------------------------------------
	SuitChrome = {
		Id = "SuitChrome",
		Kind = "Suit",
		Name = "Chrome Knight",
		Description = "Mirror chrome, every plate edged in prismatic light that runs through every colour.",
		Rarity = "Rare",
		Robux = 299,
		Color = Color3.fromRGB(110, 230, 255),
		Palette = {
			Plate = Color3.fromRGB(168, 176, 188),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(30, 34, 42),
			Glow = Color3.fromRGB(90, 220, 255),
			Reflect = 0.55,
			Seams = true,
			SeamWidth = 0.028,
			SeamFx = "Rainbow",
		},
	},
	SuitArctic = {
		Id = "SuitArctic",
		Kind = "Suit",
		Name = "Arctic Ops",
		Description = "Deep-ice navy trimmed in frost, lit by glacier-blue seams.",
		Rarity = "Rare",
		Robux = 299,
		Color = Color3.fromRGB(170, 230, 255),
		Palette = {
			Plate = Color3.fromRGB(40, 66, 98),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(16, 26, 40),
			Glow = Color3.fromRGB(130, 235, 255),
			Reflect = 0.15,
			Accent = Color3.fromRGB(180, 220, 240),
			AccentMaterial = Enum.Material.SmoothPlastic,
			Pattern = "Trim",
			Seams = true,
			SeamWidth = 0.028,
			Sparks = Color3.fromRGB(220, 248, 255),
		},
	},
	SuitObsidian = {
		Id = "SuitObsidian",
		Kind = "Suit",
		Name = "Obsidian Lava",
		Description = "Black basalt over a molten core: its cracks breathe lava.",
		Rarity = "UltraRare",
		Robux = 399,
		Color = Color3.fromRGB(255, 110, 20),
		Palette = {
			Plate = Color3.fromRGB(62, 54, 56),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(32, 27, 27),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(255, 100, 20),
			Accent = Color3.fromRGB(120, 46, 22),
			AccentMaterial = Enum.Material.SmoothPlastic,
			Pattern = "Camo",
			Seams = true,
			SeamWidth = 0.032,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(255, 150, 50),
		},
	},
	SuitNeon = {
		Id = "SuitNeon",
		Kind = "Suit",
		Name = "Neon Runner",
		Description = "Matte black, outlined in hot magenta light that breathes.",
		Rarity = "UltraRare",
		Robux = 399,
		Color = Color3.fromRGB(255, 60, 200),
		Palette = {
			Plate = Color3.fromRGB(56, 50, 74),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(30, 27, 40),
			Glow = Color3.fromRGB(255, 60, 200),
			Reflect = 0.25,
			Seams = true,
			SeamWidth = 0.028,
			SeamFx = "Pulse",
		},
	},
	SuitRoyal = {
		Id = "SuitRoyal",
		Kind = "Suit",
		Name = "Royal Gold",
		Description = "Polished gold over royal violet, its seams shimmering from gold to amethyst.",
		Rarity = "UltraRare",
		Robux = 799,
		Color = Color3.fromRGB(255, 220, 120),
		Palette = {
			Plate = Color3.fromRGB(214, 166, 58),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(60, 24, 96),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(190, 120, 255),
			Reflect = 0.3,
			Accent = Color3.fromRGB(96, 40, 150),
			AccentMaterial = Enum.Material.SmoothPlastic,
			Pattern = "Trim",
			Seams = true,
			SeamColor = Color3.fromRGB(255, 232, 160),
			SeamWidth = 0.03,
			SeamFx = "Shift",
			Sparks = Color3.fromRGB(255, 230, 150),
		},
	},
	-- The Starter Pack's own suit (Store.StarterPack) -----------------------------------------
	SuitIgnition = {
		Id = "SuitIgnition",
		Kind = "Suit",
		Name = "Ignition",
		Description = "Racing red over carbon black, white-hot lines down every plate.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 70, 50),
		Palette = {
			Plate = Color3.fromRGB(170, 24, 28),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(18, 18, 22),
			Glow = Color3.fromRGB(255, 214, 170),
			Reflect = 0.3,
			Accent = Color3.fromRGB(32, 32, 38),
			Pattern = "Trim",
			Seams = true,
			SeamColor = Color3.fromRGB(255, 236, 210),
			SeamWidth = 0.028,
		},
		Exclusive = "Starter",
	},
	-- The Season Path's premium track (Season.Premium) ----------------------------------------
	SkinLunar = {
		Id = "SkinLunar",
		Kind = "Skin",
		Name = "Moonsteel",
		Description = "Silver from the lunar frontier with a violet edge. Season 1 premium.",
		Rarity = "Rare",
		Color = Color3.fromRGB(190, 210, 255),
		Palette = {
			Plate = Color3.fromRGB(184, 190, 204),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(44, 50, 66),
			Glow = Color3.fromRGB(130, 180, 255),
			SeamColor = Color3.fromRGB(160, 110, 255),
			Reflect = 0.45,
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			Trail = true,
		},
		Exclusive = "Season",
	},
	TitleLunar = {
		Id = "TitleLunar",
		Kind = "Title",
		Name = "LUNAR VANGUARD",
		Description = "Season 1 premium.",
		Rarity = "Rare",
		Color = Color3.fromRGB(180, 210, 255),
		Exclusive = "Season",
	},
	SuitLunar = {
		Id = "SuitLunar",
		Kind = "Suit",
		Name = "Lunar Frontier",
		Description = "Moon-white plates traced in breathing violet light, with a blue glow. Season 1 premium, level 30.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(170, 200, 255),
		Palette = {
			Plate = Color3.fromRGB(214, 218, 228),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(80, 86, 104),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(120, 170, 255),
			SeamColor = Color3.fromRGB(160, 110, 255),
			Reflect = 0.15,
			Seams = true,
			SeamWidth = 0.03,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(210, 225, 255),
		},
		Exclusive = "Season",
	},
	-- The full collection (docs: Skins & Cosmetics Design Proposal) --------------------------
	SkinFrontier = {
		Id = "SkinFrontier",
		Kind = "Skin",
		Name = "Frontier Steel",
		Description = "Brushed frontier steel with an amber lamp-lit edge. Every miner's first.",
		Rarity = "Common",
		Color = Color3.fromRGB(225, 232, 240),
		Palette = {
			Plate = Color3.fromRGB(150, 156, 166),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(40, 44, 52),
			Glow = Color3.fromRGB(255, 170, 60),
			Reflect = 0.2,
			Edge = true,
			SeamWidth = 0.02,
		},
		Exclusive = "Default",
	},
	SuitFrontier = {
		Id = "SuitFrontier",
		Kind = "Suit",
		Name = "Frontier Fatigues",
		Description = "Field khaki, its plates picked out in amber lamp-light. Every miner's first look.",
		Rarity = "Common",
		Color = Color3.fromRGB(214, 196, 150),
		Palette = {
			Plate = Color3.fromRGB(128, 114, 84),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(52, 54, 58),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(255, 170, 60),
			Accent = Color3.fromRGB(100, 90, 66),
			Pattern = "Trim",
			Seams = true,
			SeamWidth = 0.022,
		},
		Exclusive = "Default",
	},
	SkinVeteran = {
		Id = "SkinVeteran",
		Kind = "Skin",
		Name = "Veteran Steel",
		Description = "Gunmetal with a gold service stripe and a red battle edge. Win 100 duels.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 214, 120),
		Palette = {
			Plate = Color3.fromRGB(70, 74, 84),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(22, 24, 28),
			Glow = Color3.fromRGB(255, 50, 70),
			Reflect = 0.3,
			Accent = Color3.fromRGB(214, 170, 70),
			AccentMaterial = Enum.Material.Foil,
			Pattern = "Trim",
			Blade = Color3.fromRGB(88, 92, 104),
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			Trail = true,
		},
		Exclusive = "Achievement",
		How = "Win 100 duels.",
	},
	SkinChampion = {
		Id = "SkinChampion",
		Kind = "Skin",
		Name = "Champion's Edge",
		Description = "White gold engraved with laurels, leaving a gold streak. Finish a ranked season at Gold or higher.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 226, 140),
		Palette = {
			Plate = Color3.fromRGB(240, 232, 210),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(34, 46, 96),
			Glow = Color3.fromRGB(255, 214, 100),
			SeamColor = Color3.fromRGB(255, 180, 30),
			Reflect = 0.3,
			Accent = Color3.fromRGB(226, 180, 70),
			AccentMaterial = Enum.Material.Foil,
			Pattern = "Trim",
			Blade = Color3.fromRGB(246, 240, 222),
			Edge = true,
			Seams = true,
			SeamWidth = 0.034,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(255, 236, 170),
			Trail = true,
		},
		Exclusive = "Ranked",
		How = "Finish a ranked season at Gold or higher.",
	},
	SuitChampion = {
		Id = "SuitChampion",
		Kind = "Suit",
		Name = "Champion Plate",
		Description = "White gold and laurel trim with a gold glow. Finish a ranked season at Platinum or higher.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 226, 140),
		Palette = {
			Plate = Color3.fromRGB(236, 230, 212),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(30, 40, 90),
			Glow = Color3.fromRGB(255, 214, 100),
			SeamColor = Color3.fromRGB(255, 180, 30),
			Reflect = 0.15,
			Accent = Color3.fromRGB(214, 166, 60),
			AccentMaterial = Enum.Material.Foil,
			Pattern = "Trim",
			Seams = true,
			SeamWidth = 0.03,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(255, 236, 170),
		},
		Exclusive = "Ranked",
		How = "Finish a ranked season at Platinum or higher.",
	},
	SkinWarlord = {
		Id = "SkinWarlord",
		Kind = "Skin",
		Name = "Warlord's Edge",
		Description = "Black iron daubed with red war-paint, trailing embers. Clear a raid boss.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 90, 30),
		Palette = {
			Plate = Color3.fromRGB(40, 36, 36),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(14, 12, 12),
			Glow = Color3.fromRGB(255, 90, 30),
			Accent = Color3.fromRGB(150, 22, 18),
			AccentMaterial = Enum.Material.SmoothPlastic,
			Pattern = "Stripes",
			Blade = Color3.fromRGB(54, 48, 46),
			BladeMaterial = Enum.Material.Metal,
			Edge = true,
			Seams = true,
			SeamWidth = 0.034,
			SeamFx = "Flicker",
			Sparks = Color3.fromRGB(255, 120, 40),
			Trail = true,
		},
		Exclusive = "Raid",
		How = "Clear a raid boss for the first time.",
	},
	SuitRaid = {
		Id = "SuitRaid",
		Kind = "Suit",
		Name = "Raid Breaker",
		Description = "Scarred black iron split by red-hot seams. Embers rise off it. Clear every raid boss on Hard.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 90, 30),
		Palette = {
			Plate = Color3.fromRGB(44, 40, 40),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(110, 18, 14),
			Glow = Color3.fromRGB(255, 90, 30),
			Accent = Color3.fromRGB(70, 28, 22),
			AccentMaterial = Enum.Material.Metal,
			Pattern = "Camo",
			Seams = true,
			SeamWidth = 0.03,
			SeamFx = "Flicker",
			Sparks = Color3.fromRGB(255, 120, 40),
		},
		Exclusive = "Raid",
		How = "Clear every raid boss on Hard.",
	},
	SkinGeodeCrust = {
		Id = "SkinGeodeCrust",
		Kind = "Skin",
		Name = "Geode Crust",
		Description = "Rough rock on the outside, violet crystal along the edge. 1 in 800 crystals, any ring.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(200, 150, 255),
		Palette = {
			Plate = Color3.fromRGB(98, 90, 84),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(46, 40, 38),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(200, 150, 255),
			Blade = Color3.fromRGB(150, 110, 220),
			BladeMaterial = Enum.Material.Glass,
			Edge = true,
			Seams = true,
			SeamWidth = 0.024,
			Sparks = Color3.fromRGB(220, 190, 255),
		},
		Exclusive = "Mining",
		How = "Mining: about 1 in 800 crystals, in any ring.",
	},
	SkinFossil = {
		Id = "SkinFossil",
		Kind = "Skin",
		Name = "Fossil Bone",
		Description = "Bone-white, set with amber. 1 in 1,500 Deep Vein rocks.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 170, 60),
		Palette = {
			Plate = Color3.fromRGB(214, 202, 174),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(108, 84, 58),
			Glow = Color3.fromRGB(255, 160, 40),
			Accent = Color3.fromRGB(204, 126, 36),
			AccentMaterial = Enum.Material.Glass,
			Pattern = "Trim",
			Blade = Color3.fromRGB(226, 216, 190),
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			Trail = true,
		},
		Exclusive = "Mining",
		How = "Mining: about 1 in 1,500 Deep Vein rocks.",
	},
	SuitFossil = {
		Id = "SuitFossil",
		Kind = "Suit",
		Name = "Fossil Shell",
		Description = "Bone-white plates with amber seams. 1 in 2,000 Deep Vein rocks.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 170, 60),
		Palette = {
			Plate = Color3.fromRGB(206, 194, 164),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(96, 74, 50),
			Glow = Color3.fromRGB(255, 160, 40),
			Accent = Color3.fromRGB(196, 120, 36),
			AccentMaterial = Enum.Material.Glass,
			Pattern = "Trim",
			Seams = true,
			SeamWidth = 0.028,
		},
		Exclusive = "Mining",
		How = "Mining: about 1 in 2,000 Deep Vein rocks.",
	},
	SkinOreVein = {
		Id = "SkinOreVein",
		Kind = "Skin",
		Name = "Ore Vein Gold",
		Description = "Raw gold veins through dark stone. 1 in 5,000 Crystal Crown rocks.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 210, 100),
		Palette = {
			Plate = Color3.fromRGB(50, 46, 44),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(20, 18, 18),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(255, 200, 40),
			Accent = Color3.fromRGB(230, 180, 60),
			AccentMaterial = Enum.Material.Foil,
			Pattern = "Trim",
			Blade = Color3.fromRGB(58, 52, 48),
			BladeMaterial = Enum.Material.SmoothPlastic,
			Edge = true,
			Seams = true,
			SeamWidth = 0.034,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(255, 220, 130),
			Trail = true,
		},
		Exclusive = "Mining",
		How = "Mining: about 1 in 5,000 Crystal Crown rocks.",
	},
	SkinRust = {
		Id = "SkinRust",
		Kind = "Skin",
		Name = "Rust Bucket",
		Description = "Rusted scrap with an orange-hot edge.",
		Rarity = "Common",
		Color = Color3.fromRGB(230, 150, 80),
		Palette = {
			Plate = Color3.fromRGB(130, 68, 38),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(50, 34, 26),
			Glow = Color3.fromRGB(255, 140, 50),
			Accent = Color3.fromRGB(96, 90, 84),
			AccentMaterial = Enum.Material.Metal,
			Pattern = "Camo",
			Blade = Color3.fromRGB(122, 64, 38),
			Edge = true,
			SeamWidth = 0.022,
		},
		Robux = 49,
	},
	SuitRust = {
		Id = "SuitRust",
		Kind = "Suit",
		Name = "Rust Rig",
		Description = "Scrap iron held together by orange-hot welds.",
		Rarity = "Common",
		Color = Color3.fromRGB(230, 150, 80),
		Palette = {
			Plate = Color3.fromRGB(112, 60, 36),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(40, 28, 22),
			Glow = Color3.fromRGB(255, 140, 50),
			Accent = Color3.fromRGB(86, 82, 76),
			AccentMaterial = Enum.Material.Metal,
			Pattern = "Camo",
			Seams = true,
			SeamWidth = 0.02,
		},
		Robux = 99,
	},
	SkinCamo = {
		Id = "SkinCamo",
		Kind = "Skin",
		Name = "Camo Ops",
		Description = "Night-ops camo with a night-vision green edge.",
		Rarity = "Common",
		Color = Color3.fromRGB(200, 220, 140),
		Palette = {
			Plate = Color3.fromRGB(80, 88, 52),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(34, 36, 26),
			Glow = Color3.fromRGB(170, 255, 80),
			Accent = Color3.fromRGB(150, 134, 96),
			Pattern = "Camo",
			Blade = Color3.fromRGB(92, 98, 72),
			Edge = true,
			SeamWidth = 0.022,
		},
		Robux = 49,
	},
	SuitCamo = {
		Id = "SuitCamo",
		Kind = "Suit",
		Name = "Camo Ops",
		Description = "Night-ops camo, every plate traced in night-vision green.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(200, 220, 140),
		Palette = {
			Plate = Color3.fromRGB(66, 74, 44),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(30, 32, 24),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(170, 255, 80),
			Accent = Color3.fromRGB(122, 112, 80),
			AccentMaterial = Enum.Material.SmoothPlastic,
			Pattern = "Camo",
			Seams = true,
			SeamWidth = 0.022,
		},
		Robux = 149,
	},
	SkinCopper = {
		Id = "SkinCopper",
		Kind = "Skin",
		Name = "Copper Wire",
		Description = "Polished copper with a grip of wound wire.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(255, 170, 100),
		Palette = {
			Plate = Color3.fromRGB(196, 116, 66),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(62, 34, 22),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(255, 176, 90),
			Reflect = 0.35,
			Accent = Color3.fromRGB(120, 62, 34),
			AccentMaterial = Enum.Material.Metal,
			Pattern = "Trim",
			Edge = true,
			Seams = true,
			SeamWidth = 0.024,
		},
		Robux = 79,
	},
	SuitCopper = {
		Id = "SuitCopper",
		Kind = "Suit",
		Name = "Copper Coil",
		Description = "Burnished copper banded in dark wire, glowing amber at every join.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(255, 170, 100),
		Palette = {
			Plate = Color3.fromRGB(168, 94, 54),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(46, 28, 20),
			Glow = Color3.fromRGB(255, 176, 90),
			Reflect = 0.3,
			Accent = Color3.fromRGB(82, 46, 28),
			AccentMaterial = Enum.Material.Metal,
			Pattern = "Stripes",
			Seams = true,
			SeamWidth = 0.022,
		},
		Robux = 149,
	},
	SkinCircuit = {
		Id = "SkinCircuit",
		Kind = "Skin",
		Name = "Circuit Board",
		Description = "Green board with gold traces that pulse with power.",
		Robux = 99,
		Rarity = "Rare",
		Color = Color3.fromRGB(120, 255, 150),
		Palette = {
			Plate = Color3.fromRGB(20, 84, 46),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(10, 26, 16),
			Glow = Color3.fromRGB(110, 255, 150),
			Reflect = 0.15,
			Accent = Color3.fromRGB(220, 180, 70),
			AccentMaterial = Enum.Material.Foil,
			Pattern = "Trim",
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			SeamFx = "Pulse",
			Sparks = Color3.fromRGB(160, 255, 180),
			Trail = true,
		},
	},
	SuitCircuit = {
		Id = "SuitCircuit",
		Kind = "Suit",
		Name = "Circuit Rig",
		Description = "A circuit board you wear: gold traces, green data pulsing along every edge.",
		Rarity = "Rare",
		Color = Color3.fromRGB(120, 255, 150),
		Palette = {
			Plate = Color3.fromRGB(18, 70, 40),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(8, 22, 14),
			Glow = Color3.fromRGB(110, 255, 150),
			Reflect = 0.15,
			Accent = Color3.fromRGB(220, 180, 70),
			AccentMaterial = Enum.Material.Foil,
			Pattern = "Trim",
			Seams = true,
			SeamWidth = 0.028,
			SeamFx = "Pulse",
		},
		Robux = 249,
	},
	SkinNebula = {
		Id = "SkinNebula",
		Kind = "Skin",
		Name = "Nebula",
		Description = "Purple-pink gas clouds sealed in glass, shedding stardust.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 140, 230),
		Palette = {
			Plate = Color3.fromRGB(120, 56, 150),
			PlateMaterial = Enum.Material.Glass,
			Under = Color3.fromRGB(26, 12, 40),
			Glow = Color3.fromRGB(110, 210, 255),
			Reflect = 0.4,
			Accent = Color3.fromRGB(236, 116, 196),
			AccentMaterial = Enum.Material.Glass,
			Pattern = "Camo",
			Blade = Color3.fromRGB(170, 84, 190),
			BladeMaterial = Enum.Material.Glass,
			Edge = true,
			Seams = true,
			SeamColor = Color3.fromRGB(255, 130, 230),
			SeamWidth = 0.034,
			SeamFx = "Shift",
			Sparks = Color3.fromRGB(255, 210, 250),
			Trail = true,
		},
		Robux = 199,
	},
	SuitNebula = {
		Id = "SuitNebula",
		Kind = "Suit",
		Name = "Nebula Suit",
		Description = "Purple-pink glass with stars drifting through it, edged in shifting cosmic light.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 140, 230),
		Palette = {
			Plate = Color3.fromRGB(110, 52, 140),
			PlateMaterial = Enum.Material.Glass,
			Under = Color3.fromRGB(24, 12, 38),
			Glow = Color3.fromRGB(110, 210, 255),
			Reflect = 0.35,
			Accent = Color3.fromRGB(210, 100, 190),
			AccentMaterial = Enum.Material.Glass,
			Pattern = "Camo",
			Seams = true,
			SeamColor = Color3.fromRGB(255, 130, 230),
			SeamWidth = 0.03,
			SeamFx = "Shift",
			Sparks = Color3.fromRGB(240, 220, 255),
		},
		Robux = 399,
	},
	SkinGlacier = {
		Id = "SkinGlacier",
		Kind = "Skin",
		Name = "Glacier Shard",
		Description = "A blade of clear blue ice that breathes frost.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(190, 240, 255),
		Palette = {
			Plate = Color3.fromRGB(120, 170, 200),
			PlateMaterial = Enum.Material.Ice,
			Under = Color3.fromRGB(30, 56, 84),
			Glow = Color3.fromRGB(110, 190, 255),
			Reflect = 0.3,
			Blade = Color3.fromRGB(176, 226, 248),
			BladeMaterial = Enum.Material.Glass,
			Edge = true,
			Seams = true,
			SeamWidth = 0.03,
			Sparks = Color3.fromRGB(230, 250, 255),
			Trail = true,
		},
	},
	SkinSolar = {
		Id = "SkinSolar",
		Kind = "Skin",
		Name = "Solar Flare",
		Description = "A blade of living sunfire: it burns, flares and never cools.",
		Rarity = "Legendary",
		Robux = 399,
		Color = Color3.fromRGB(255, 190, 70),
		Look = "Solar",
		Palette = {
			Plate = Color3.fromRGB(255, 196, 90),
			PlateMaterial = Enum.Material.Foil,
			Under = Color3.fromRGB(110, 40, 12),
			Glow = Color3.fromRGB(255, 230, 140),
			Reflect = 0.35,
			Accent = Color3.fromRGB(255, 120, 30),
			AccentMaterial = Enum.Material.Neon,
			Pattern = "Trim",
			Blade = Color3.fromRGB(255, 170, 50),
			BladeMaterial = Enum.Material.Neon,
			Edge = true,
			Seams = true,
			SeamColor = Color3.fromRGB(255, 150, 40),
			SeamWidth = 0.036,
			SeamFx = "Flicker",
			Sparks = Color3.fromRGB(255, 170, 60),
			Trail = true,
		},
	},
	SuitStealth = {
		Id = "SuitStealth",
		Kind = "Suit",
		Name = "Stealth Black",
		Description = "Gunmetal black that swallows the light, cut by thin red lines.",
		Rarity = "Uncommon",
		Robux = 199,
		Color = Color3.fromRGB(90, 96, 104),
		Palette = {
			Plate = Color3.fromRGB(66, 68, 80),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(34, 35, 42),
			Glow = Color3.fromRGB(255, 40, 60),
			Accent = Color3.fromRGB(90, 92, 104),
			AccentMaterial = Enum.Material.SmoothPlastic,
			Pattern = "Trim",
			Seams = true,
			SeamWidth = 0.02,
		},
	},
	SuitStorm = {
		Id = "SuitStorm",
		Kind = "Suit",
		Name = "Storm Conductor",
		Description = "Gunmetal plate wired with live yellow current. It crackles.",
		Rarity = "Rare",
		Robux = 299,
		Color = Color3.fromRGB(255, 235, 90),
		Palette = {
			Plate = Color3.fromRGB(58, 62, 74),
			PlateMaterial = Enum.Material.Metal,
			Under = Color3.fromRGB(20, 22, 28),
			Glow = Color3.fromRGB(255, 236, 80),
			Reflect = 0.3,
			Accent = Color3.fromRGB(210, 176, 30),
			AccentMaterial = Enum.Material.Foil,
			Pattern = "Trim",
			Seams = true,
			SeamWidth = 0.028,
			SeamFx = "Flicker",
			Sparks = Color3.fromRGB(255, 240, 140),
		},
	},
	SuitBiohazard = {
		Id = "SuitBiohazard",
		Kind = "Suit",
		Name = "Biohazard",
		Description = "Hazard stripes on charcoal, sealed with toxic-green seams.",
		Rarity = "Rare",
		Robux = 299,
		Color = Color3.fromRGB(140, 255, 90),
		Palette = {
			Plate = Color3.fromRGB(66, 70, 58),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(34, 36, 30),
			Glow = Color3.fromRGB(130, 255, 80),
			Accent = Color3.fromRGB(226, 190, 30),
			Pattern = "Stripes",
			Seams = true,
			SeamWidth = 0.028,
			Sparks = Color3.fromRGB(160, 255, 110),
		},
	},
	SkinBonk = {
		Id = "SkinBonk",
		Kind = "Skin",
		Name = "Bonk Bat",
		Description = "A fat cartoon bat in neon-banded cyan. Bonk.",
		Rarity = "Rare",
		Robux = 149,
		Color = Color3.fromRGB(255, 200, 120),
		Look = "Bonk",
		Palette = {
			Plate = Color3.fromRGB(214, 160, 96),
			PlateMaterial = Enum.Material.Wood,
			Under = Color3.fromRGB(150, 40, 34),
			Glow = Color3.fromRGB(255, 230, 160),
			SeamColor = Color3.fromRGB(60, 230, 255),
		},
	},
	SkinBanana = {
		Id = "SkinBanana",
		Kind = "Skin",
		Name = "Banana Blade",
		Description = "A banana that cuts, striped in hot-pink neon.",
		Rarity = "Rare",
		Robux = 149,
		Color = Color3.fromRGB(255, 230, 90),
		Look = "Banana",
		Palette = {
			Plate = Color3.fromRGB(250, 222, 70),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(96, 72, 30),
			Glow = Color3.fromRGB(255, 240, 140),
			SeamColor = Color3.fromRGB(255, 70, 200),
		},
	},
	SkinCrater = {
		Id = "SkinCrater",
		Kind = "Skin",
		Name = "Crater Grey",
		Description = "Moon-rock grey from the crater floor, with a cold blue edge. Season 1, level 15.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(170, 200, 255),
		Palette = {
			Plate = Color3.fromRGB(132, 134, 140),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(60, 62, 70),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(110, 170, 255),
			Blade = Color3.fromRGB(100, 102, 110),
			BladeMaterial = Enum.Material.SmoothPlastic,
			Edge = true,
			Seams = true,
			SeamWidth = 0.024,
		},
		Exclusive = "Season",
		How = "Season 1 free track, level 15.",
	},
	SuitMoonDust = {
		Id = "SuitMoonDust",
		Kind = "Suit",
		Name = "Moon Dust",
		Description = "Regolith grey, traced in cold blue starlight.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(200, 215, 240),
		Palette = {
			Plate = Color3.fromRGB(96, 98, 106),
			PlateMaterial = Enum.Material.SmoothPlastic,
			Under = Color3.fromRGB(64, 66, 72),
			UnderMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(110, 170, 255),
			Accent = Color3.fromRGB(100, 102, 108),
			AccentMaterial = Enum.Material.SmoothPlastic,
			Pattern = "Camo",
			Seams = true,
			SeamWidth = 0.022,
		},
		Exclusive = "Season",
		How = "Season 1 free track, level 25.",
	},
	-- Pickaxe skins (Shared.PickaxeLooks has each one's model and hit).
	PickMagma = {
		Id = "PickMagma",
		Kind = "Pick",
		Name = "Magma Heart",
		Description = "Basalt split open on a river of lava. It smoulders in your hand and every swing leaves embers.",
		Rarity = "Legendary",
		Robux = 199,
		Color = Color3.fromRGB(255, 110, 20),
	},
	PickStorm = {
		Id = "PickStorm",
		Kind = "Pick",
		Name = "Stormbreaker",
		Description = "A thunder hammer-pick with tesla prongs. Every hit calls lightning down on the rock.",
		Rarity = "Legendary",
		Robux = 199,
		Color = Color3.fromRGB(255, 230, 90),
	},
	PickVoid = {
		Id = "PickVoid",
		Kind = "Pick",
		Name = "Void Reaper",
		Description = "A scythe of night-glass, runes circling the haft. Rock folds into the dark where it bites.",
		Rarity = "Legendary",
		Robux = 199,
		Color = Color3.fromRGB(170, 90, 255),
	},
	PickGlacier = {
		Id = "PickGlacier",
		Kind = "Pick",
		Name = "Glacier Fang",
		Description = "A jagged icicle the length of your arm, steaming cold. Hits burst into frost shards.",
		Rarity = "UltraRare",
		Robux = 149,
		Color = Color3.fromRGB(150, 225, 255),
	},
	PickPrism = {
		Id = "PickPrism",
		Kind = "Pick",
		Name = "Prism Shard",
		Description = "A cut-diamond pick that cycles through every colour, and throws them all when it hits.",
		Rarity = "UltraRare",
		Robux = 149,
		Color = Color3.fromRGB(200, 170, 255),
	},
	PickNeon = {
		Id = "PickNeon",
		Kind = "Pick",
		Name = "Neon Runner",
		Description = "Matte black cut with hot pink and cyan light. Sparks fly in both.",
		Rarity = "Rare",
		Robux = 99,
		Color = Color3.fromRGB(255, 70, 200),
	},
	PickGilded = {
		Id = "PickGilded",
		Kind = "Pick",
		Name = "Gilded Prospector",
		Description = "Polished gold set with rubies and an emerald. Every hit glitters.",
		Rarity = "UltraRare",
		Color = Color3.fromRGB(255, 200, 80),
		Robux = 149,
	},
	PickGeode = {
		Id = "PickGeode",
		Kind = "Pick",
		Name = "Amethyst Geode",
		Description = "A split geode whose crystals grow into the spike.",
		Rarity = "Rare",
		Color = Color3.fromRGB(190, 110, 255),
		Robux = 99,
	},
	PickBone = {
		Id = "PickBone",
		Kind = "Pick",
		Name = "Bone Crusher",
		Description = "A monster's tusk lashed to a spine, with a skull for a hammer.",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(240, 228, 200),
		Robux = 79,
	},
	PickTwinStar = {
		Id = "PickTwinStar",
		Kind = "Pick",
		Name = "Twin Star",
		Description = "Two stars, gold and teal, circle its head: you and your crew. Every hit crashes them together.",
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 215, 120),
		Exclusive = "Invite",
		How = "Invite 2 friends who join the game.",
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

-- Every cosmetic of a kind, in the order the Shop shows them: on sale first
-- (cheapest first), then the exclusives.
function Cosmetics.ofKind(kind: string): { string }
	local ids = {}
	for id, cosmetic in Cosmetics.List do
		if cosmetic.Kind == kind then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local x, y = Cosmetics.List[a], Cosmetics.List[b]
		local xs, ys = if x.Exclusive then 1 else 0, if y.Exclusive then 1 else 0
		if xs ~= ys then
			return xs < ys
		end
		local xp, yp = x.Robux or x.Price or 0, y.Robux or y.Price or 0
		if xp ~= yp then
			return xp < yp
		end
		return x.Name < y.Name
	end)
	return ids
end

-- Its price in coins: only while testing (Config.TestCosmeticPrice), for a
-- weapon skin, suit or pick the store sells, so a purchase can be tried
-- without Robux. Nothing is sold for coins otherwise.
function Cosmetics.coinPrice(cosmetic: Cosmetic): number?
	local test = Config.TestCosmeticPrice
	if type(test) == "number" and cosmetic.Robux and Cosmetics.isMinerKind(cosmetic.Kind) then
		return test
	end
	return nil
end

-- What each miner wears for itself: a suit, a weapon skin and a pickaxe
-- (kept in its character as Wardrobe = { Suit, Skin, Pick }). Trims, backs
-- and titles are the account's. A miner with no Wardrobe yet wears the
-- account's current look.
Cosmetics.MinerKinds = { "Suit", "Skin", "Pick" }
function Cosmetics.isMinerKind(kind: any): boolean
	return kind == "Suit" or kind == "Skin" or kind == "Pick"
end
local function currentLook(cosmetics: any): { [string]: string? }
	local look = {}
	for _, kind in Cosmetics.MinerKinds do
		look[kind] = cosmetics[kind]
	end
	return look
end
function Cosmetics.forMiner(cosmetics: any, character: any): any
	local look = table.clone(cosmetics or {})
	local wardrobe = type(character) == "table" and character.Wardrobe
	if type(wardrobe) == "table" then
		for _, kind in Cosmetics.MinerKinds do
			look[kind] = wardrobe[kind]
		end
	end
	return look
end
-- Switching miners: the one leaving keeps what it wore (recorded now if it
-- never had a Wardrobe), and the one arriving puts its own on (or, new to
-- wardrobes, takes the current look as its own). Looks you no longer own
-- come off.
function Cosmetics.leaveMiner(cosmetics: any, character: any)
	if type(character) == "table" and type(character.Wardrobe) ~= "table" then
		character.Wardrobe = currentLook(cosmetics)
	end
end
function Cosmetics.joinMiner(cosmetics: any, character: any)
	if type(character) ~= "table" then
		return
	end
	if type(character.Wardrobe) ~= "table" then
		character.Wardrobe = currentLook(cosmetics)
	end
	for _, kind in Cosmetics.MinerKinds do
		local id = character.Wardrobe[kind]
		cosmetics[kind] = if id and cosmetics.Owned and cosmetics.Owned[id] then id else nil
	end
end

-- How to get one you don't own, in a few words for the Shop.
Cosmetics.SourceText = {
	Invite = "Bring friends",
	Group = "Join the group",
	Streak = "7-day login streak",
	Code = "Promo code",
	Starter = "Starter Pack",
	Squad = "Squad Bundle",
	Vault = "The Vault",
	Season = "Season Path",
	Default = "Everyone",
	Achievement = "Achievement",
	Ranked = "Ranked reward",
	Raid = "Raid reward",
	Mining = "Mining find",
}
function Cosmetics.source(cosmetic: Cosmetic): string
	if cosmetic.Exclusive then
		return Cosmetics.SourceText[cosmetic.Exclusive] or "Exclusive"
	elseif cosmetic.Robux then
		return string.format("R$ %d", cosmetic.Robux)
	end
	return "Bundles & Season Path"
end

return Cosmetics
