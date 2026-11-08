--[[
	Ranked leagues: names for ranges of the Ranked 1v1 rating (Systems/Duels
	keeps the rating itself, Shared.Matchmaking's Elo, unchanged). Six
	leagues of the moon's ores, each but Titan split into tiers III, II and I
	(III the bottom), 50 rating apart. Everyone starts at 1000, the bottom of
	Copper III, so the first win already moves you.

	  Stone      0 - 999     (III below 900, II 900, I 950)
	  Copper     1000 - 1149
	  Cobalt     1150 - 1299
	  Crystal    1300 - 1449
	  Prism      1450 - 1599
	  Titan      1600 and up (no tiers: ranked by rating)

	The 16 steps (Stone III = 1 ... Titan = 16) are what's saved and shown.
	Rank demotion: drop below your tier's floor and you go down a tier; but
	having just reached a new league you're safe from falling out of it for
	your first SafeMatches matches in it.

	  Leagues.List                 { Id, Name, Color, Floor }, bottom first
	  Leagues.stepOf(rating) -> step
	  Leagues.info(step) -> { Step, League, Name, Tier, Label, Color, Floor, Ceiling }
	  Leagues.update(saved, rating, season, ratingBefore?) -> saved, change
	      after a ranked match: the saved league ({ Step, Safe, Season,
	      Best }) moved to the rating, safety counted down; change is
	      { Before, After, Promoted, Demoted, Shielded, NewLeague, Track }
	      (Track: the steps reached for the first time this season)
	  Leagues.progress(step, rating) -> fraction, toNext   through the tier
	  Leagues.Track[step]          the reward the first time a season
	  Leagues.Images.Sheet, Leagues.crest(step) -> offset, size   the crest image
	  Leagues.softReset(rating)    a new season: halfway back toward 1000
]]
local Leagues = {}

Leagues.Start = 1000 -- (Shared.Matchmaking.StartRating)
Leagues.Width = 50 -- rating per tier
Leagues.SafeMatches = 3 -- matches safe from dropping out of a league just reached

Leagues.List = {
	{ Id = "Stone", Name = "STONE", Color = Color3.fromRGB(154, 161, 173), Floor = 0 },
	{ Id = "Copper", Name = "COPPER", Color = Color3.fromRGB(217, 138, 78), Floor = 1000 },
	{ Id = "Cobalt", Name = "COBALT", Color = Color3.fromRGB(79, 141, 255), Floor = 1150 },
	{ Id = "Crystal", Name = "CRYSTAL", Color = Color3.fromRGB(155, 124, 255), Floor = 1300 },
	{ Id = "Prism", Name = "PRISM", Color = Color3.fromRGB(255, 122, 209), Floor = 1450 },
	{ Id = "Titan", Name = "TITAN", Color = Color3.fromRGB(255, 210, 90), Floor = 1600 },
}
local TIERS = { "III", "II", "I" }
Leagues.Steps = 16

-- Where each step starts: Stone III at 0, Stone II at 900, Stone I at 950,
-- then 50 a tier from Copper III (1000) to Prism I (1550), Titan at 1600.
local FLOORS = { 0, 900, 950 }
for step = 4, Leagues.Steps do
	FLOORS[step] = Leagues.Start + (step - 4) * Leagues.Width
end
Leagues.Floors = FLOORS

function Leagues.stepOf(rating: number): number
	local step = 1
	for s = Leagues.Steps, 1, -1 do
		if rating >= FLOORS[s] then
			step = s
			break
		end
	end
	return step
end

function Leagues.info(step: number)
	step = math.clamp(math.floor(step), 1, Leagues.Steps)
	local index = math.min(math.floor((step - 1) / 3) + 1, #Leagues.List)
	local league = Leagues.List[index]
	local tier = if index == #Leagues.List then nil else TIERS[(step - 1) % 3 + 1]
	return {
		Step = step,
		League = league.Id,
		Index = index,
		Name = league.Name,
		Tier = tier,
		Label = if tier then league.Name .. " " .. tier else league.Name,
		Color = league.Color,
		Floor = FLOORS[step],
		Ceiling = FLOORS[step + 1], -- (nil at Titan)
	}
end

-- How far through its tier `rating` is (0..1), and the rating to the next.
function Leagues.progress(step: number, rating: number): (number, number?)
	local info = Leagues.info(step)
	if not info.Ceiling then
		return 1, nil
	end
	local span = info.Ceiling - info.Floor
	return math.clamp((rating - info.Floor) / span, 0, 1), math.max(0, info.Ceiling - rating)
end

function Leagues.softReset(rating: number): number
	return math.floor(Leagues.Start + (rating - Leagues.Start) / 2 + 0.5)
end

-- The first time a season each step is reached: Coins at once; Cache (a
-- reward like a streak's Arena Cache: a free gem of GemTier and pieces of
-- gear at least Floor) at the first tier of a new league; Title at Titan.
-- (Stone pays nothing: you start above it.)
Leagues.Track = {
	[5] = { Coins = 1500 },
	[6] = { Coins = 2000 },
	[7] = { Coins = 3000, Cache = { GemTier = "Rare", Floor = "Rare" } },
	[8] = { Coins = 3500 },
	[9] = { Coins = 4000 },
	[10] = { Coins = 5000, Cache = { GemTier = "UltraRare", Floor = "Rare" } },
	[11] = { Coins = 5500 },
	[12] = { Coins = 6000 },
	[13] = { Coins = 8000, Cache = { GemTier = "UltraRare", Floor = "UltraRare" } },
	[14] = { Coins = 9000 },
	[15] = { Coins = 10000 },
	[16] = { Coins = 15000, Cache = { GemTier = "Legendary", Floor = "Legendary" }, Title = "TitleTitan" },
}

-- The next step above `step` with a reward.
function Leagues.nextReward(step: number): number?
	for s = step + 1, Leagues.Steps do
		if Leagues.Track[s] then
			return s
		end
	end
	return nil
end

function Leagues.update(saved, rating: number, season: string, ratingBefore: number?)
	saved = saved or {}
	local was = saved.Step or Leagues.stepOf(ratingBefore or rating)
	if saved.Season ~= season then
		-- (a new season: what this season's track has paid starts again)
		saved.Season, saved.Best = season, was
	end
	local want = Leagues.stepOf(rating)
	local before, after, shielded = was, want, false
	local oldLeague, newLeague = Leagues.info(was).Index, Leagues.info(want).Index
	if want < was and (saved.Safe or 0) > 0 and newLeague < oldLeague then
		-- Just reached this league: held at its bottom tier for now.
		after, shielded = (oldLeague - 1) * 3 + 1, true
	end
	local reachedLeague = Leagues.info(after).Index > oldLeague
	if reachedLeague then
		saved.Safe = Leagues.SafeMatches
	elseif (saved.Safe or 0) > 0 then
		saved.Safe -= 1
	end
	local track = {}
	for s = (saved.Best or was) + 1, after do
		if Leagues.Track[s] then
			table.insert(track, s)
		end
	end
	saved.Best = math.max(saved.Best or was, after)
	saved.Step = after
	saved.Played = (saved.Played or 0) + 1 -- (ranked 1v1s played: shown once there's one)
	return saved, {
		Before = before,
		After = after,
		Promoted = after > before,
		Demoted = after < before,
		Shielded = shielded,
		NewLeague = reachedLeague,
		Safe = saved.Safe or 0,
		Track = track,
	}
end

-- The crests: one image, 4 x 4 cells of 256 pixels, step 1 top left, row
-- by row (assets/images/crests/crests.png). 0 until it's uploaded (then a
-- drawn badge stands in: Client LeagueBadge).
Leagues.Images = {
	Sheet = 0, -- crests.png
}
Leagues.Cell = 256
function Leagues.crest(step: number): (Vector2, Vector2)
	local i = math.clamp(math.floor(step), 1, Leagues.Steps) - 1
	return Vector2.new((i % 4) * Leagues.Cell, math.floor(i / 4) * Leagues.Cell), Vector2.new(Leagues.Cell, Leagues.Cell)
end

return Leagues
