--[[
	What each kind of fight between players counts (the authoritative spec's
	PvP rule). Pure: the server applies it, the client shows it, tests check it.

	  kind        stats                      rated  rewards (coins)
	  Challenge   the challenger's choice:     no   Win 5 / Loss 0 (no farming
	              "Full" (everything you've          friends with uneven stats)
	              earned) or "Even"
	  Casual      Even                         no   Win 15 / Loss 5
	  Ranked      Even, rarity capped at        yes  Win 40 / Loss 10
	              Ultra Rare

	"Even": the base stats are the same for everyone. Today that means the
	Augment Tree's perks are off (as in every Arena session); when character
	levels arrive, Health, Charge and Stamina snap to the baseline here too.
	Your build (gear, gems and their grades) and your skill still count.
	"Full": your whole progression counts, the Augment Tree included.
	Ranked's rarity cap: a piece of gear rolled above Ultra Rare fights with
	Ultra Rare numbers (its stats scaled down to that tier); what a gem or
	piece unlocks still counts. PvE (the rival, dungeons) is never touched.

	  PvPRules.profile(kind, stats?)  -> { Kind, Name, Stats, Rated, RarityCap, Rewards }
	  PvPRules.label(profile)         -> what the match screen says ("EVEN STATS" ...)
	  PvPRules.capLoadout(loadout, cap) -> a copy fighting at most `cap`
	                                   (1-5); the original is untouched
	  PvPRules.forAttributes(stats, cap) -> the profile a fighter carries
	                                   (MatchStats / MatchRarityCap attributes)
]]
local PvPRules = {}

PvPRules.UltraRare = 4

PvPRules.Kinds = {
	Challenge = { Name = "Outpost duel", Rated = false, Rewards = { Win = 5, Loss = 0 } },
	Casual = { Name = "1v1 Casual", Rated = false, Stats = "Even", Rewards = { Win = 15, Loss = 5 } },
	Ranked = {
		Name = "Ranked",
		Rated = true,
		Stats = "Even",
		RarityCap = PvPRules.UltraRare,
		Rewards = { Win = 40, Loss = 10 },
	},
}

function PvPRules.profile(kind: string, stats: string?)
	local spec = PvPRules.Kinds[kind] or PvPRules.Kinds.Casual
	local chosen = spec.Stats or (if stats == "Full" then "Full" else "Even")
	return {
		Kind = if PvPRules.Kinds[kind] then kind else "Casual",
		Name = spec.Name,
		Stats = chosen,
		Rated = spec.Rated,
		RarityCap = spec.RarityCap,
		Rewards = spec.Rewards,
	}
end

function PvPRules.label(profile): string
	if profile.Stats == "Full" then
		return "FULL PROGRESSION"
	end
	return if profile.RarityCap then "EVEN STATS  ·  RARITY CAPPED" else "EVEN STATS"
end

-- The profile a fighter carries into a match, from its attributes.
function PvPRules.forAttributes(stats: any, cap: any)
	if stats ~= "Full" and stats ~= "Even" then
		return nil
	end
	return {
		Stats = stats,
		RarityCap = if type(cap) == "number" then cap else nil,
	}
end

function PvPRules.capLoadout(loadout, cap: number?)
	if not loadout or not cap or type(loadout.GearRolls) ~= "table" then
		return loadout
	end
	local copy = table.clone(loadout)
	copy.GearRolls = {}
	for kind, rolls in loadout.GearRolls do
		local capped = {}
		for id, roll in rolls do
			if type(roll) == "table" and type(roll.Rarity) == "number" and roll.Rarity > cap then
				local fewer = table.clone(roll)
				fewer.Rarity = cap
				if type(roll.Stats) == "table" then
					fewer.Stats = {}
					for stat, amount in roll.Stats do
						fewer.Stats[stat] = math.floor(amount * cap / roll.Rarity)
					end
				end
				capped[id] = fewer
			else
				capped[id] = roll
			end
		end
		copy.GearRolls[kind] = capped
	end
	return copy
end

return PvPRules
