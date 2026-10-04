--[[
	You vs the Arena rival: the numbers each side really fights with, and
	plain-language strengths and weaknesses for both (pure, for tests).

	Matchup.build(you, foe) with, for each side:
	  Name, Health (max), Hit (damage per quick hit on the other, after
	  armor), Speed (walk speed), Element (weapon gem), ArmorElement
	  (armor gem), Surges (list of
	  { Id, Name, Kind = "Bolt" | "Nova" | "Self" }), Moves (maneuver ids)
	returns {
	  Rows = { { Stat, You, Foe, Better = "You" | "Foe" | nil } },
	  FoeEdges = { strings }, FoeWeak = { strings },
	  YourEdges = { strings }, YourWeak = { strings },
	}
]]
local ElementMatchup = require(script.Parent.ElementMatchup)

local Matchup = {}

local ELEMENT_NAME = { Fire = "Thermal", Frost = "Cryo", Shock = "Ion", Poison = "Corrosive" }

local CLEAR = 1.12 -- a stat counts as an edge when it's this much better

local ELEMENT_EDGE = {
	Fire = "Thermal hits burn (damage over time)",
	Frost = "Cryo hits slow and can freeze",
	Poison = "Corrosive hits shred armor",
	Shock = "Ion hits arc and can stun",
}

local function better(a: number, b: number, lowerWins: boolean?): string?
	if lowerWins then
		a, b = b, a
	end
	if a >= b * CLEAR then
		return "You"
	elseif b >= a * CLEAR then
		return "Foe"
	end
	return nil
end

local function hitsToWin(hit: number, health: number): number
	return math.max(1, math.ceil(health / math.max(1, hit)))
end

local function has(list, predicate): boolean
	for _, item in list or {} do
		if predicate(item) then
			return true
		end
	end
	return false
end

local function names(list, predicate): { string }
	local out = {}
	for _, item in list or {} do
		if predicate(item) then
			table.insert(out, item.Name)
		end
	end
	return out
end

local function heals(side): boolean
	return has(side.Surges, function(s)
		return s.Id == "EnergySiphon"
	end) or has(side.Moves, function(m)
		return m == "StimDodge"
	end)
end

local function cutsHealing(side): boolean
	return side.Element == "Fire" or side.Element == "Poison"
end

function Matchup.build(you, foe)
	local yourHits = hitsToWin(you.Hit, foe.Health) -- your hits to beat it
	local foeHits = hitsToWin(foe.Hit, you.Health) -- its hits to beat you
	local result = {
		Rows = {
			{ Stat = "Health", You = you.Health, Foe = foe.Health, Better = better(you.Health, foe.Health) },
			{ Stat = "Damage / hit", You = you.Hit, Foe = foe.Hit, Better = better(you.Hit, foe.Hit) },
			{ Stat = "Hits to win", You = yourHits, Foe = foeHits, Better = better(yourHits, foeHits, true) },
			{ Stat = "Speed", You = you.Speed, Foe = foe.Speed, Better = better(you.Speed, foe.Speed) },
		},
		FoeEdges = {},
		FoeWeak = {},
		YourEdges = {},
		YourWeak = {},
	}
	local function add(list, text)
		if #list < 4 then
			table.insert(list, text)
		end
	end

	-- Raw numbers.
	if better(yourHits, foeHits, true) == "Foe" then
		add(result.FoeEdges, string.format("Wins the trade: beats you in %d hits, you need %d", foeHits, yourHits))
	elseif better(yourHits, foeHits, true) == "You" then
		add(result.YourEdges, string.format("You win the trade: %d hits to beat it, it needs %d", yourHits, foeHits))
	end
	-- Healing, and whether you can cut it.
	if heals(foe) then
		if cutsHealing(you) then
			add(result.YourEdges, "Your gem cuts its healing (Grievous Wounds / Mortal Strike)")
		else
			add(result.FoeWeak, "Heals itself: burst it down between heals")
		end
	end
	if better(you.Health, foe.Health) == "Foe" then
		add(
			result.FoeEdges,
			string.format("Tougher: %d%% more health", math.floor((foe.Health / you.Health - 1) * 100))
		)
	elseif better(you.Health, foe.Health) == "You" then
		add(
			result.FoeWeak,
			string.format("Fragile: %d%% less health than you", math.floor((1 - foe.Health / you.Health) * 100))
		)
	end
	if better(you.Hit, foe.Hit) == "Foe" then
		add(result.YourWeak, "Its quick hits hit harder than yours: don't trade blow for blow")
	elseif better(you.Hit, foe.Hit) == "You" then
		add(result.YourEdges, "Your hits are heavier than its")
	end
	if better(you.Speed, foe.Speed) == "Foe" then
		add(result.FoeEdges, "Faster than you: you can't outrun it")
	elseif better(you.Speed, foe.Speed) == "You" then
		add(result.YourEdges, "You're faster: step out of its casts")
	end

	-- Elements and kits.
	if ELEMENT_EDGE[foe.Element] then
		add(result.FoeEdges, ELEMENT_EDGE[foe.Element])
	end
	if ELEMENT_EDGE[you.Element] then
		add(result.YourEdges, ELEMENT_EDGE[you.Element])
	end
	if has(foe.Surges, function(s)
		return s.Id == "CryoShield"
	end) then
		add(result.FoeWeak, "Cryo Shield halves your damage for 4s: dodge and wait it out")
	end
	local casts = names(foe.Surges, function(s)
		return s.Kind ~= "Self"
	end)
	if #casts > 0 then
		add(result.FoeWeak, "Telegraphs " .. table.concat(casts, ", ") .. ": dodge on the red cue")
	end
	-- How it fights, always true.
	add(result.FoeWeak, "Heavy attacks break its guard")
	add(result.FoeWeak, "Stuns and parries cancel its wind-ups")
	if heals(you) and not heals(foe) then
		add(result.YourEdges, "You can heal mid-fight; it can't")
	end
	if not ELEMENT_EDGE[you.Element] then
		add(result.YourWeak, "No weapon gem: your hits carry no element")
	end
	-- Elements against armor (ElementMatchup).
	local function armorLine(attack, armor, whose)
		local mult, tag = ElementMatchup.multiplier(attack, armor)
		if not tag then
			return nil, nil
		end
		local a, b = ELEMENT_NAME[attack] or attack, ELEMENT_NAME[armor] or armor
		if tag == "Resist" then
			return tag, string.format("%s %s armor resists %s hits (%d%%)", whose, b, a, math.floor(mult * 100 + 0.5))
		end
		return tag, string.format("%s %s armor is weak to %s (%d%% damage)", whose, b, a, math.floor(mult * 100 + 0.5))
	end
	local tag, line = armorLine(you.Element, foe.ArmorElement, "Its")
	if tag == "Resist" then
		add(result.YourWeak, line)
	elseif tag == "Weak" then
		add(result.YourEdges, line)
	end
	tag, line = armorLine(foe.Element, you.ArmorElement, "Your")
	if tag == "Resist" then
		add(result.FoeWeak, line)
	elseif tag == "Weak" then
		add(result.FoeEdges, line)
	end
	if #result.YourWeak == 0 then
		add(
			result.YourWeak,
			if foeHits <= 8 then "Low margin: it beats you in " .. foeHits .. " hits" else "Nothing glaring"
		)
	end
	return result
end

return Matchup
