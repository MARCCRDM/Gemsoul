--[[
	Daily challenges: three a day for each player, one from each group
	(mining, fighting, gear), new every UTC day. Each pays coins once when
	done, and clearing all three pays a bonus. They count the same events as
	Tasks (PlayerData.training), so nothing a client says counts.

	Pure, for the server, the lobby and tests.

	  Daily.today(now)                     the UTC day number
	  Daily.roll(userId, day)              -> the day's three ids (the same
	                                          for that player all day)
	  Daily.state(profile, userId, day)    profile.Challenges, reset for a
	                                       new day
	  Daily.record(profile, userId, event, day)
	                                       -> challenges just finished, bonus
	                                          coins (or nil), changed?
	  Daily.view(profile, userId, day)     what the lobby shows
]]
local Daily = {}

Daily.Groups = {
	{
		Name = "Mining",
		{
			Id = "Rocks",
			Event = "Mine",
			Goal = 10,
			Coins = 40,
			Name = "Break 10 rocks",
			Hint = "Any rock in the Outpost counts.",
		},
		{
			Id = "Gems",
			Event = "MineGem",
			Goal = 4,
			Coins = 50,
			Name = "Mine 4 gems",
			Hint = "Rocks that drop a gem count.",
		},
		{
			Id = "Rare",
			Event = "RareGem",
			Goal = 1,
			Coins = 75,
			Name = "Find a Rare gem",
			Hint = "Rare, Ultra Rare or Legendary, mined today.",
		},
	},
	{
		Name = "Fighting",
		{
			Id = "Rivals",
			Event = "RivalWin",
			Goal = 2,
			Coins = 60,
			Name = "Beat 2 rivals",
			Hint = "Win 1v1 Practice: PLAY, then Practice.",
		},
		{
			Id = "Surges",
			Event = "Surge",
			Goal = 8,
			Coins = 45,
			Name = "Cast 8 Surges",
			Hint = "In any fight: Q, E or R (gem buttons on a phone).",
		},
		{
			Id = "Guard",
			Event = "Block",
			Goal = 12,
			Coins = 40,
			Name = "Guard 12 hits",
			Hint = "Hold guard as a hit lands.",
		},
		{
			Id = "Timed",
			Event = "TimedBlock",
			Goal = 3,
			Coins = 50,
			Name = "3 perfect guards",
			Hint = "Raise your guard just before the hit.",
		},
	},
	{
		Name = "Gear",
		{
			Id = "Socket",
			Event = "Enchant",
			Goal = 2,
			Coins = 40,
			Name = "Socket 2 gems",
			Hint = "Drag gems onto gear sockets in Inventory.",
		},
		{
			Id = "Rearm",
			Event = "EquipSurge",
			Goal = 1,
			Coins = 30,
			Name = "Ready a Surge",
			Hint = "Move a gem into Q, E or R in Inventory.",
		},
		{
			Id = "Hits",
			Event = "Hit",
			Goal = 30,
			Coins = 35,
			Name = "Land 30 hits",
			Hint = "Light and heavy weapon hits, any fight.",
		},
	},
}
-- All three done.
Daily.Bonus = 50

Daily.ById = {}
for _, group in Daily.Groups do
	for _, challenge in ipairs(group) do
		Daily.ById[challenge.Id] = challenge
	end
end

function Daily.today(now: number): number
	return math.floor(now / 86400)
end

-- The day's three: one per group, picked by the player and the day so a
-- rejoin (or another server) shows the same ones.
function Daily.roll(userId: number, day: number): { string }
	local ids = {}
	for index, group in Daily.Groups do
		local mix = (day * 7919 + math.abs(userId) % 1000003 * 104729 + index * 15485863) % 2147483647
		table.insert(ids, group[mix % #group + 1].Id)
	end
	return ids
end

function Daily.state(profile, userId: number, day: number)
	local state = profile.Challenges
	if type(state) ~= "table" or state.Day ~= day then
		state = { Day = day, Ids = Daily.roll(userId, day), Counts = {}, Paid = {}, Bonus = false }
		profile.Challenges = state
	end
	state.Counts = state.Counts or {}
	state.Paid = state.Paid or {}
	return state
end

function Daily.record(profile, userId: number, event: string, day: number)
	if event == "Heavy" then
		event = "Hit"
	end
	local state = Daily.state(profile, userId, day)
	local finished, changed, counted = {}, false, {}
	for _, id in state.Ids do
		local challenge = Daily.ById[id]
		if challenge and challenge.Event == event and not state.Paid[id] and not counted[id] then
			counted[id] = true
			state.Counts[id] = math.min(challenge.Goal, (state.Counts[id] or 0) + 1)
			changed = true
			if state.Counts[id] >= challenge.Goal then
				state.Paid[id] = true
				profile.Coins = (profile.Coins or 0) + challenge.Coins
				table.insert(finished, challenge)
			end
		end
	end
	local bonus = nil
	if #finished > 0 and not state.Bonus then
		local all = true
		for _, id in state.Ids do
			all = all and state.Paid[id] == true
		end
		if all then
			state.Bonus = true
			profile.Coins = (profile.Coins or 0) + Daily.Bonus
			bonus = Daily.Bonus
		end
	end
	return finished, bonus, changed
end

function Daily.view(profile, userId: number, day: number)
	local state = Daily.state(profile, userId, day)
	local list = {}
	for _, id in state.Ids do
		local challenge = Daily.ById[id]
		if challenge then
			table.insert(list, {
				Id = id,
				Name = challenge.Name,
				Hint = challenge.Hint,
				Goal = challenge.Goal,
				Coins = challenge.Coins,
				Count = state.Counts[id] or 0,
				Done = state.Paid[id] == true,
			})
		end
	end
	return { Day = day, List = list, Bonus = Daily.Bonus, BonusDone = state.Bonus == true }
end

return Daily
