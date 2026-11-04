--[[
	What the main menu (Client Modules/MainMenu) shows: its banners (the
	slides), the GUIDE's pages, the UPDATES list and the CREDITS. Edit here
	and publish; nothing else needs changing for a new banner or update.

	  Banners    newest first; each one's picture (Images), its tag and words,
	             and what its button does (Action):
	               { Kind = "Redeem", Code = "X" }   redeems the code there and then
	               { Kind = "Page", Page = "Updates" }  opens a menu page
	               { Kind = "Bounty" }    in, then the bounty board
	               { Kind = "Ranked" }    in, then the PLAY picker (Ranked first)
	               { Kind = "Booth" }     in, then arrows to the DEV booth
	             Ends: os.time() after which it's taken down by itself (a
	             code's banner ends with the code). Live: "DevOnline" shows the
	             DEV desk's state in its tag.
	  Images     each banner's picture: tools/upload_audio.py uploads
	             assets/images/menu and writes the ids here; 0 = not yet (the
	             banner shows its colours and words instead)

	  MainMenuContent.live(now) -> { banner }   the banners up at `now`
	  MainMenuContent.codesOf(banner, now) -> { code }   its codes still on
	  MainMenuContent.version(build) -> "v1.10"
]]
local MainMenuContent = {}

-- Roblox ids of the uploaded pictures (assets/images/menu). 0 = not uploaded yet.
MainMenuContent.Images = {
	KaijuCodes = 129194255262205, -- kaiju_codes.png
	DevBooth = 137948280938606, -- dev_booth.png
	Updates = 75634600141967, -- updates.png
	Pickaxe = 109495894337355, -- pickaxe_code.png
}

-- The part of a picture to show, in its pixels: { X, Y, Width, Height }
-- (none: all of it). KaijuCodes: above the code names baked into its
-- bottom (the banner's buttons say them).
MainMenuContent.Crops = {
	KaijuCodes = { 0, 0, 1024, 488 },
}

local GOLD = Color3.fromRGB(255, 202, 91)
local EMBER = Color3.fromRGB(255, 140, 70)

MainMenuContent.Banners = {
	{
		Id = "KaijuCodes",
		Tag = "CODES",
		TagColor = Color3.fromRGB(186, 140, 255),
		Title = "3 LEGENDARY KAIJU CODES",
		Line = "TRISKULL, BRIGHTSTEEL and STEAMHIDE: a Legendary kaiju each. First 100 players per code, ends Nov 16-17.",
		Short = "TRISKULL · BRIGHTSTEEL · STEAMHIDE. First 100 each.",
		Button = "REDEEM",
		Codes = { "TRISKULL", "BRIGHTSTEEL", "STEAMHIDE" },
		-- (each code's button goes when it ends, the banner with the last:
		-- Server.Codes)
		CodeEnds = {
			TRISKULL = os.time({ year = 2026, month = 11, day = 16, hour = 23, min = 59 }),
			BRIGHTSTEEL = os.time({ year = 2026, month = 11, day = 17, hour = 23, min = 59 }),
			STEAMHIDE = os.time({ year = 2026, month = 11, day = 17, hour = 23, min = 59 }),
		},
		Action = { Kind = "Redeem", Code = "TRISKULL" },
		Ends = os.time({ year = 2026, month = 11, day = 17, hour = 23, min = 59 }),
	},
	{
		Id = "DevBooth",
		Tag = "DEV BOOTH",
		LiveTag = "● DEV ONLINE",
		TagColor = Color3.fromRGB(96, 236, 170),
		Live = "DevOnline",
		Title = "THE DEV MIGHT BE ONLINE!",
		Line = "He might drop some cool stuff. Swing by the DEV booth in the Outpost to find out.",
		Short = "He might drop some cool stuff. Swing by the DEV booth.",
		Button = "GO TO THE BOOTH",
		Action = { Kind = "Booth" },
	},
	{
		Id = "Updates",
		Tag = "WHAT'S NEW",
		TagColor = EMBER,
		Title = "THE LATEST UPDATES",
		Line = "Starter kaiju team · Bounty hunts in the Rift · Glacier Dome for Frost · the Thunder Aura",
		Short = "Kaiju team · Bounty hunts · Glacier Dome · Thunder Aura",
		Button = "SEE ALL UPDATES",
		Action = { Kind = "Page", Page = "Updates" },
	},
	{
		Id = "Pickaxe",
		Tag = "CODE",
		TagColor = Color3.fromRGB(110, 210, 255),
		Title = "FREE THUNDERCLAP PICKAXE",
		Line = "Code THUNDER: a Legendary storm pick that calls blue lightning down on every hit. First 100 only.",
		Short = "Code THUNDER: a Legendary storm pick. First 100 only.",
		Button = "REDEEM THUNDER",
		Codes = { "THUNDER" },
		Action = { Kind = "Redeem", Code = "THUNDER" },
	},
}

-- The GUIDE: a few pages, each a title and its lines.
MainMenuContent.Guide = {
	{
		Title = "CONTROLS",
		Lines = {
			"Click: swing. Hold it for a heavy blow.",
			"Right-click: block.  Space: dodge.",
			"Q, E, R: your three abilities.",
			"T: switch target.  Shift + click: your off hand.",
			"On a phone or tablet, the same moves are buttons on the screen.",
		},
	},
	{
		Title = "YOUR KAIJU",
		Lines = {
			"Your kaiju fight beside you, in duels and in the Rift.",
			"Train them to level them up, and heal them with gemsouls.",
			"Win more from boss caches, rolls and codes.",
		},
	},
	{
		Title = "GEMS",
		Lines = {
			"Mine rock with your pickaxe for gems (1 or X swaps to it).",
			"The gems in your weapon, chest and shield are your Q, E and R.",
			"Better gems, stronger moves.",
		},
	},
	{
		Title = "THE RIFT",
		Lines = {
			"Walk up to a Rift Gate, or take a bounty from the board.",
			"Clear the caves, then beat the boss on its throne.",
			"Green crystals by the cave walls heal you: mine them.",
			"Every boss drops a cache of its own for everyone in.",
		},
	},
	{
		Title = "DUELS",
		Lines = {
			"1v1 Casual opens after 3 duels, Ranked after 10.",
			"Ranked wins climb your streak and its reward track.",
		},
	},
}

-- UPDATES: newest first.
MainMenuContent.Updates = {
	{
		Version = "1.11",
		Date = "Nov 4",
		Lines = {
			"This main menu: the news, a guide, feedback and codes in one place.",
		},
	},
	{
		Version = "1.10",
		Date = "Nov 4",
		Lines = {
			"A narrator for your first steps, and arrows on your abilities.",
			"Your first dungeon goes straight to its boss.",
			"You arrive in every dungeon facing the way in.",
		},
	},
	{
		Version = "1.2 - 1.9",
		Date = "Nov 3",
		Lines = {
			"A starter kaiju team, the prize for your first dungeon.",
			"HUNT BOUNTY takes you straight into your first dungeon.",
			"Glacier Dome: Frost's new starter move.",
			"Kaiju left far behind come back to your side.",
			"Code BRIGHTSTEEL: a Legendary Brightsteel.",
		},
	},
	{
		-- (before the build numbers)
		Date = "Nov 2",
		Lines = {
			"The Thunder Aura: a new Aura slot.",
			"Code TRISKULL: a Legendary Triskull.",
			"The new intro: two 1v1s, your kaiju, then a dungeon.",
		},
	},
}

MainMenuContent.Credits = {
	{ Title = "SAGA MINERS", Lines = { "Made by the Saga Miners team." } },
	{ Title = "NARRATION", Lines = { "George, voiced with Kokoro TTS." } },
	{ Title = "BUILT WITH", Lines = { "Roblox Studio, Rojo and Luau." } },
	{ Title = "THANK YOU", Lines = { "Every miner who plays, reports a bug or sends an idea." } },
}

-- The banners up at `now`: those not past their end, in order.
function MainMenuContent.live(now: number): { any }
	local list = {}
	for _, banner in MainMenuContent.Banners do
		if not banner.Ends or now <= banner.Ends then
			table.insert(list, banner)
		end
	end
	return list
end

-- A banner's codes still on at `now` (each goes at its CodeEnds).
function MainMenuContent.codesOf(banner, now: number): { string }
	local list = {}
	for _, code in banner.Codes or {} do
		local ends = banner.CodeEnds and banner.CodeEnds[code]
		if not ends or now <= ends then
			table.insert(list, code)
		end
	end
	return list
end

-- "v1.10" out of the build label ("1.10 · 2026-11-04 ...").
function MainMenuContent.version(build: any): string
	local number = if type(build) == "string" then string.match(build, "^%s*([%d%.]+)") else nil
	return if number then "v" .. number else ""
end

return MainMenuContent
