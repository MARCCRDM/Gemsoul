--[[
	Everything there is to know about one gem, line by line, for a card that
	lists it in full (the Market's listing: MarketBoardUI):

	  name, then rarity, element and Prismatic, then its quality word and tier level
	  MOVES      the three it gives: Q on a sword, E on a chest, R on a shield,
	             each with its numbers at this gem (Shared.GemTraits)
	  GRADES     Size, Clarity and Precision out of 10, and what each sets
	  IN A WEAPON / IN ARMOR   what it does there (GemConfig.lines), and how
	             much of its element it resists in each armor piece
	             (ElementMatchup.gemResist)
	  VALUE      each grade's points, times its rarity's rate, = its worth
	  where it came from and who mined it

	  GemFacts.lines(gem) -> { { Text: string, Kind: string, Key: string? } }
	    Kind: Name, Sub, Head, Move, Stats, Grade, Effect, Worth, Total, Note
	    Key: "Q", "E" or "R" on a Move line

	Pieces of a line are joined with "  ·  ", so each is translated on its
	own (Shared.Lang).
]]
local CombatTechnology = require(script.Parent.CombatTechnology)
local ElementMatchup = require(script.Parent.ElementMatchup)
local GemConfig = require(script.Parent.GemConfig)
local GemRoller = require(script.Parent.GemRoller)
local GemTraits = require(script.Parent.GemTraits)

local GemFacts = {}

GemFacts.Keys = { "Q", "E", "R" }
GemFacts.Sockets = { Q = "Sword", E = "Chest", R = "Shield" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local SEP = "  ·  "

local function commas(n: number): string
	local s = tostring(math.floor(n + 0.5))
	while true do
		local swapped, count = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		s = swapped
		if count == 0 then
			return s
		end
	end
end

-- "7.2" or "7": one decimal place, none when it's whole.
local function short(n: number): string
	local tenth = math.floor(n * 10 + 0.5) / 10
	return if tenth == math.floor(tenth) then tostring(math.floor(tenth)) else string.format("%.1f", tenth)
end

function GemFacts.lines(gem): { { Text: string, Kind: string, Key: string? } }
	local lines = {}
	local function add(text: string, kind: string, key: string?)
		table.insert(lines, { Text = text, Kind = kind, Key = key })
	end
	if not gem then
		return lines
	end
	local shade = GemConfig.shade(gem)
	local rarity = GemConfig.TierLabels[gem.Tier] or tostring(gem.Tier)
	add(GemConfig.displayName(gem), "Name")
	add(
		rarity .. " gem" .. SEP .. GemConfig.elementName(gem.Element) .. (if shade.Prismatic then SEP .. "Prismatic" else ""),
		"Sub"
	)
	local tier, rank = GemRoller.surge(gem)
	add(
		"Quality: "
			.. GemConfig.gradeWord(gem)
			.. SEP
			.. string.format(
				"Tier level %s (%s, rank %s)",
				GemRoller.levelLabel(gem),
				GemRoller.TierNames[tier] or tostring(tier),
				GemRoller.Numerals[rank] or "I"
			),
		"Sub"
	)
	if not gem.Cut then
		add("Rough: cut it to unlock its power", "Note")
	end

	-- The three moves it gives, and their numbers at this gem.
	local traits = GemTraits.traitsOf(gem)
	if traits then
		add("MOVES", "Head")
		for _, key in GemFacts.Keys do
			local id = traits[GemTraits.Lanes[key]]
			local move = id and CombatTechnology.Catalog[id]
			if move then
				add(
					key .. SEP .. GemFacts.Sockets[key] .. SEP .. move.Name .. SEP .. GemTraits.typeOf(id),
					"Move",
					key
				)
				local ok, stats = pcall(GemTraits.stats, id, gem)
				if ok and stats then
					-- ("x3" hits as "× 3", so the number reads as one in Spanish)
					local summary = string.gsub(GemTraits.summary(stats), "damage x(%d+)", "damage × %1")
					add((string.gsub(summary, " · ", SEP)), "Stats", key)
				end
			end
		end
	end

	add("GRADES", "Head")
	for _, metric in GemConfig.MetricOrder do
		local grade = gem[metric]
		add(
			string.format(
				"%s %s/10%s%s",
				GemConfig.MetricLabels[metric],
				if grade then tostring(grade) else "--",
				SEP,
				string.lower(GemConfig.MetricRoles[metric])
			),
			"Grade"
		)
	end

	for _, side in { { "IN A WEAPON", "Weapon" }, { "IN ARMOR", "Armor" } } do
		local ok, effects = pcall(GemConfig.lines, gem, side[2])
		if ok and effects and #effects > 0 then
			add(side[1], "Head")
			for _, effect in effects do
				if effect.Metric == "Cut" and not gem.Cut then
					continue -- (a rough stone has no Precision yet)
				end
				local tag = if effect.Metric
					then SEP .. (GemConfig.MetricLabels[effect.Metric] or effect.Metric) .. " " .. tostring(effect.Grade or 0)
					else ""
				add(effect.Text .. tag, "Effect")
			end
			if side[2] == "Armor" then
				add(
					string.format(
						"Resists %s%% %s damage per armor piece",
						short(ElementMatchup.gemResist(gem) * 100),
						GemConfig.elementName(gem.Element)
					),
					"Effect"
				)
			end
		end
	end

	local ok, worth = pcall(GemConfig.worth, gem)
	if ok and worth then
		add("VALUE", "Head")
		for _, grade in worth.Grades do
			local label = GemConfig.MetricLabels[grade.Metric] or grade.Metric
			local value = if grade.Metric == "Cut" and not gem.Cut then "--" else tostring(grade.Grade)
			add(string.format("%s %s × %d = %s", label, value, grade.Weight, commas(grade.Points)), "Worth")
		end
		add(
			-- (the rate first: a line ending in "rate" is the "{*} rate" entry's, whole)
			rarity
				.. " rate"
				.. SEP
				.. string.format("%s points × %g = %s coins", commas(worth.Points), worth.Rate, commas(worth.Value)),
			"Total"
		)
	end

	local origin = gem.Source and (GemConfig.SourceLabels[gem.Source] or gem.Source)
	if origin then
		if type(gem.Found) == "number" and gem.Found > 0 then
			local date = os.date("!*t", gem.Found)
			origin ..= SEP .. MONTHS[date.month] .. " " .. date.day .. ", " .. date.year
		end
		add(origin, "Note")
	end
	if gem.MinedBy then
		add("Mined by " .. gem.MinedBy, "Note")
	end
	return lines
end

return GemFacts
