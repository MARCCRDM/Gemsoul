-- Daily challenges (Shared.DailyChallenges): three a day, one per group,
-- the same all day, paid once, a bonus for all three, new the next day.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local DAY = Daily.today(1760572800) -- 2025-10-16 00:00 UTC
check(DAY == 20377, "Wrong day number: " .. DAY)

-- The roll: one per group, valid, stable, and varied across players and days.
local seen = {}
for userId = 1, 400 do
	for day = DAY, DAY + 6 do
		local ids = Daily.roll(userId * 7331, day)
		check(#ids == #Daily.Groups, "Not one per group")
		for index, id in ids do
			local challenge = Daily.ById[id]
			check(challenge ~= nil, "Unknown challenge " .. tostring(id))
			local inGroup = false
			for _, c in ipairs(Daily.Groups[index]) do
				inGroup = inGroup or c.Id == id
			end
			check(inGroup, id .. " came from the wrong group")
			seen[id] = true
		end
		check(
			table.concat(Daily.roll(userId * 7331, day), ",") == table.concat(ids, ","),
			"The roll changed within a day"
		)
	end
end
for id in Daily.ById do
	check(seen[id], id .. " never came up")
end
for _, group in Daily.Groups do
	for _, c in ipairs(group) do
		check(c.Goal >= 1 and c.Coins > 0 and #c.Hint > 0 and #c.Name > 0, c.Id .. " is incomplete")
	end
end

-- A day of play.
local profile = { Coins = 100 }
local userId = 4242
local state = Daily.state(profile, userId, DAY)
local ids = state.Ids
local function eventOf(id)
	return Daily.ById[id].Event
end
local first = Daily.ById[ids[1]]
local finished, bonus, changed = Daily.record(profile, userId, "Nothing", DAY)
check(#finished == 0 and bonus == nil and not changed and profile.Coins == 100, "An unrelated event counted")
for i = 1, first.Goal - 1 do
	finished, bonus, changed = Daily.record(profile, userId, first.Event, DAY)
	check(changed and #finished == 0, "Progress didn't count")
end
check(profile.Coins == 100, "Paid before the goal")
finished = Daily.record(profile, userId, first.Event, DAY)
check(
	#finished == 1 and finished[1].Id == first.Id and profile.Coins == 100 + first.Coins,
	"The finished challenge didn't pay"
)
finished, bonus, changed = Daily.record(profile, userId, first.Event, DAY)
check(#finished == 0 and not changed and profile.Coins == 100 + first.Coins, "A finished challenge paid twice")
check(profile.Challenges.Counts[first.Id] == first.Goal, "Counted past the goal")

-- Heavy blows count as hits.
local hits = {
	Coins = 0,
	Challenges = { Day = DAY, Ids = { "Rocks", "Rivals", "Hits" }, Counts = {}, Paid = {}, Bonus = false },
}
Daily.record(hits, userId, "Heavy", DAY)
Daily.record(hits, userId, "Hit", DAY)
check(hits.Challenges.Counts.Hits == 2, "Heavy blows didn't count as hits")

-- All three: the bonus, once.
local before = profile.Coins
local paid = 0
for index = 2, 3 do
	local c = Daily.ById[ids[index]]
	for _ = 1, c.Goal do
		finished, bonus = Daily.record(profile, userId, c.Event, DAY)
	end
	paid += c.Coins
end
check(bonus == Daily.Bonus and profile.Coins == before + paid + Daily.Bonus, "The all-three bonus wasn't paid")
check(profile.Challenges.Bonus, "The bonus wasn't marked")
local view = Daily.view(profile, userId, DAY)
check(
	#view.List == 3 and view.BonusDone and view.List[1].Done and view.List[3].Count == view.List[3].Goal,
	"The view is wrong"
)

-- Two challenges on the same event both count (a hand-made day).
local twin =
	{ Coins = 0, Challenges = { Day = DAY, Ids = { "Rocks", "Rocks", "Hits" }, Counts = {}, Paid = {}, Bonus = false } }
Daily.record(twin, userId, "Mine", DAY)
check(twin.Challenges.Counts.Rocks == 1, "A doubled id counted twice")

-- The next day: new challenges, fresh counts, a new bonus to earn.
local tomorrow = Daily.view(profile, userId, DAY + 1)
check(profile.Challenges.Day == DAY + 1 and not tomorrow.BonusDone, "The day didn't roll over")
for _, entry in tomorrow.List do
	check(entry.Count == 0 and not entry.Done, "Yesterday's progress carried over")
end
-- A saved state from an old version (no Counts or Paid) mends itself.
local old = { Coins = 0, Challenges = { Day = DAY, Ids = { "Rocks", "Guard", "Socket" } } }
Daily.record(old, userId, "Mine", DAY)
check(old.Challenges.Counts.Rocks == 1, "An old saved state broke counting")
-- A retired id in a saved day is skipped, not an error.
local retired = { Coins = 0, Challenges = { Day = DAY, Ids = { "Gone", "Guard", "Socket" }, Counts = {}, Paid = {} } }
check(#Daily.view(retired, userId, DAY).List == 2, "A retired challenge broke the view")
Daily.record(retired, userId, "Block", DAY)

print(
	"PASS: "
		.. checks
		.. " daily challenge checks (one per group, stable rolls, progress, paying once, the bonus, new days, old saves)"
)
