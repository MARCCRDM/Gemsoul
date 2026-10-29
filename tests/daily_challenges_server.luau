-- PlayerData.training with daily challenges: coins and notes when one is
-- done, a full sync then, and otherwise a light progress push at most once
-- a second.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local TrainingRewards = {
	record = function()
		return {}, false
	end,
}
local DailyChallenges = Daily
-- (Analytics: the coins each reason tagged.)
local tagged = {}
local Analytics = {
	coins = function(_, delta, reason)
		if delta ~= 0 then
			tagged[reason] = (tagged[reason] or 0) + delta
		end
	end,
}
local DAY = 20377
local function today()
	return DAY
end
local profiles, notes, pushes, syncs = {}, {}, {}, 0
local delayed = {}
local task = {
	delay = function(_, fn)
		table.insert(delayed, fn)
	end,
}
local function runDelayed()
	local now = delayed
	delayed = {}
	for _, fn in now do
		fn()
	end
end
local Players = { PlayerRemoving = { Connect = function() end } }
local Remotes = {
	Notify = {
		FireClient = function(_, _, text)
			table.insert(notes, text)
		end,
	},
	Challenges = {
		FireClient = function(_, _, view)
			table.insert(pushes, view)
		end,
	},
}
local trainedEvent = { Fire = function() end }
local function sync()
	syncs += 1
end
local PlayerData = {}
--[[GLUE]]

local player = { UserId = 4242, Parent = true }
profiles[player] =
	{ Coins = 0, Challenges = { Day = DAY, Ids = { "Rocks", "Guard", "Hits" }, Counts = {}, Paid = {}, Bonus = false } }
-- Hits in a fight: progress, but one push a second and no full syncs.
for _ = 1, 5 do
	PlayerData.training(player, "Hit")
end
check(syncs == 0 and #delayed == 1, "Hits synced the whole profile, or pushed more than once")
runDelayed()
check(#pushes == 1 and pushes[1].List[3].Count == 5, "The progress push was wrong")
-- Nothing to count: nothing sent.
PlayerData.training(player, "Nothing")
check(#delayed == 0 and syncs == 0, "An unrelated event sent progress")
-- Finishing one pays, notes it and syncs.
for _ = 1, 10 do
	PlayerData.training(player, "Mine")
end
check(profiles[player].Coins == Daily.ById.Rocks.Coins, "The finished challenge didn't pay")
check(syncs == 1 and string.find(notes[#notes], "Break 10 rocks", 1, true), "Finishing didn't note and sync")
-- All three: the bonus note.
for _ = 1, 12 do
	PlayerData.training(player, "Block")
end
for _ = 1, 25 do
	PlayerData.training(player, "Heavy")
end
check(string.find(notes[#notes], "ALL 3 DAILY CHALLENGES DONE", 1, true) ~= nil, "No bonus note")
check(
	profiles[player].Coins == Daily.ById.Rocks.Coins + Daily.ById.Guard.Coins + Daily.ById.Hits.Coins + Daily.Bonus,
	"Coins don't add up"
)
check(tagged.DailyChallenge == profiles[player].Coins and tagged.Tasks == nil, "Challenge coins weren't tagged for Analytics")
-- A player who left before the push: nothing sent.
local gone = { UserId = 7, Parent = nil }
profiles[gone] =
	{ Coins = 0, Challenges = { Day = DAY, Ids = { "Rocks", "Guard", "Hits" }, Counts = {}, Paid = {}, Bonus = false } }
runDelayed() -- (the first player's last push)
local before = #pushes
PlayerData.training(gone, "Hit")
runDelayed()
check(#pushes == before, "Pushed to a player who left")
-- No profile yet: ignored.
PlayerData.training({ UserId = 9, Parent = true }, "Mine")
print("PASS: " .. checks .. " server daily challenge checks (progress pushes, payouts, notes, the bonus)")
