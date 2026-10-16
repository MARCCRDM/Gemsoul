-- The lobby's board (Modules/LobbyBoard) and live feed (Modules/LobbyFeed).
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local gui = new("ScreenGui", { Name = "LobbyHud", AbsoluteSize = Vector2.new(1366, 710) })
local column = LobbyBoard.mount(gui)
local function card(name)
	return column:FindFirstChild(name)
end
local function shown()
	local names = {}
	for _, child in column:GetChildren() do
		if child.ClassName == "TextButton" and child.Visible then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return table.concat(names, ",")
end
local function challengesView(done)
	return {
		Day = 20377,
		Bonus = 50,
		BonusDone = done == 3,
		List = {
			{
				Id = "Rocks",
				Name = "Break 10 rocks",
				Hint = "x",
				Goal = 10,
				Coins = 40,
				Count = if done >= 1 then 10 else 3,
				Done = done >= 1,
			},
			{
				Id = "Rivals",
				Name = "Beat 2 rivals",
				Hint = "x",
				Goal = 2,
				Coins = 60,
				Count = if done >= 2 then 2 else 0,
				Done = done >= 2,
			},
			{
				Id = "Socket",
				Name = "Socket 2 gems",
				Hint = "x",
				Goal = 2,
				Coins = 40,
				Count = if done >= 3 then 2 else 0,
				Done = done >= 3,
			},
		},
	}
end

-- No profile yet: nothing drawn, nothing breaks.
LobbyBoard.refresh()
-- A new player: streak, challenges and the first task on a desktop.
GemClient.Profile = {
	Coins = 300,
	Daily = { Streak = 1 },
	TrainingRewards = { Paid = {}, Counts = {} },
	Challenges = challengesView(0),
}
LobbyBoard.refresh()
check(shown() == "Challenges,NextTask,Streak", "Desktop cards wrong: " .. shown())
check(LobbyBoard.layout() > 300, "The column has no height")
-- On a phone, one card: the task while learning.
LobbyBoard.setCompact(true)
check(shown() == "NextTask", "Phone while learning should show the task: " .. shown())
-- Past the first pages: the phone shows the challenges.
local paid = {}
for _, id in { "FirstRock", "ThreeRocks", "GemFind", "Enchant", "ThreeSlots", "EquipSurge" } do
	paid[id] = true
end
GemClient.Profile.TrainingRewards = { Paid = paid, Counts = {} }
LobbyBoard.refresh()
check(shown() == "Challenges", "Phone after learning should show the challenges: " .. shown())
check(card("Challenges"):FindFirstChild("Title").Text == "CHALLENGES", "The phone keeps the long title")
-- The PLAY menu open: the whole board steps aside.
LobbyBoard.setHidden(true)
check(column.Visible == false, "The board stayed over the PLAY menu")
LobbyBoard.setHidden(false)
check(column.Visible == true, "The board didn't come back")
LobbyBoard.setCompact(false)
check(card("Challenges"):FindFirstChild("Title").Text == "DAILY CHALLENGES", "The desktop title is wrong")

-- Challenge rows: progress, done marks, the bonus line.
local rows = card("Challenges")
local function row(i)
	return rows:FindFirstChild("Row" .. i)
end
local function texts(node)
	local out = {}
	for _, d in node:GetDescendants() do
		if d.ClassName == "TextLabel" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, "|")
end
check(
	string.find(texts(row(1)), "3/10", 1, true) and string.find(texts(row(1)), "+40 ◆", 1, true),
	"Row 1 progress missing: " .. texts(row(1))
)
GemClient.Profile.Challenges = challengesView(1)
GemClient.ChallengesChanged:Fire(GemClient.Profile.Challenges)
check(
	string.find(texts(row(1)), "PAID", 1, true) and string.find(texts(row(1)), "✓", 1, true),
	"A done challenge isn't marked: " .. texts(row(1))
)
check(string.find(texts(rows), "ALL THREE", 1, true), "The bonus line is missing")
GemClient.Profile.Challenges = challengesView(3)
LobbyBoard.refresh()
check(
	string.find(texts(rows), "BONUS PAID", 1, true) and string.find(texts(rows), "ALL DONE", 1, true),
	"All done isn't shown: " .. texts(rows)
)
-- No challenges in the profile (an old server): the card hides.
GemClient.Profile.Challenges = nil
LobbyBoard.refresh()
check(not card("Challenges").Visible, "An empty challenges card showed")

-- Streak: tomorrow's reward grows with the streak, capped at a week.
GemClient.Profile.Daily = { Streak = 3 }
LobbyBoard.refresh()
local tomorrow = Config.DailyRewardBase + Config.DailyRewardPerStreak * 3
check(
	string.find(texts(card("Streak")), "+" .. tomorrow .. " ◆", 1, true),
	"Tomorrow's reward is wrong: " .. texts(card("Streak"))
)
GemClient.Profile.Daily = { Streak = 9 }
LobbyBoard.refresh()
local capped = Config.DailyRewardBase + Config.DailyRewardPerStreak * (Config.DailyStreakMax - 1)
check(string.find(texts(card("Streak")), "+" .. capped .. " ◆", 1, true), "The streak reward isn't capped")

-- Next unlock: only while a mode is still locked.
check(not card("Unlock").Visible, "Unlock showed with nothing locked")
LobbyBoard.unlock = { Name = "Ranked 1v1", Left = 2 }
LobbyBoard.refresh()
check(card("Unlock").Visible and string.find(texts(card("Unlock")), "2 DUELS", 1, true), "A locked mode isn't shown")
-- (LobbyUI's: a function of the profile, asked as the board redraws.)
LobbyBoard.unlock = function(profile)
	return if profile.Coins > 0 then { Name = "Casual 1v1", Left = 1 } else nil
end
LobbyBoard.refresh()
check(string.find(texts(card("Unlock")), "CASUAL 1V1", 1, true) and string.find(texts(card("Unlock")), "1 DUEL", 1, true), "The unlock function wasn't asked")
LobbyBoard.unlock = nil
-- A hidden lobby doesn't redraw as the profile changes (a fight syncs it
-- with nothing to see); it catches up as it shows.
gui.Enabled = false
local before, tasks = texts(card("NextTask")), GemClient.Profile.TrainingRewards
GemClient.Profile.TrainingRewards = { Paid = {}, Counts = {} }
GemClient.Changed:Fire(GemClient.Profile)
check(texts(card("NextTask")) == before, "The board redrew while the lobby was hidden")
gui.Enabled = true
check(texts(card("NextTask")) ~= before, "The board didn't catch up as the lobby showed")
GemClient.Profile.TrainingRewards = tasks
GemClient.Changed:Fire(GemClient.Profile)
check(texts(card("NextTask")) == before, "The board didn't redraw with the lobby up")
-- Every task done: the task card goes.
local all = {}
for _, o in Training.Objectives do
	all[o.Id] = true
end
GemClient.Profile.TrainingRewards = { Paid = all, Counts = {} }
LobbyBoard.refresh()
check(not card("NextTask").Visible, "The task card stayed with every task done")
-- Tapping the task opens the Tasks window (its OpenTasks event).
GemClient.Profile.TrainingRewards = { Paid = {}, Counts = {} }
LobbyBoard.refresh()
local tasksGui = new("ScreenGui", { Name = "TrainingRewards", Parent = playerGui })
local opened = 0
local openEvent = new("BindableEvent", { Name = "OpenTasks", Parent = tasksGui })
openEvent.Fire = function()
	opened += 1
end
card("NextTask").Activated:Fire()
check(opened == 1, "Tapping the task didn't open Tasks")
print(
	"PASS: "
		.. checks
		.. " lobby board checks (cards per screen, phone choice, challenges, bonus, streak, unlock, tasks)"
)

-- The live feed ------------------------------------------------------------------------------------
local feedChecks = checks
local stack = LobbyFeed.mount(gui)
local function lines()
	local out = {}
	for _, child in stack:GetChildren() do
		if child.ClassName == "Frame" and not child.Destroyed then
			table.insert(out, child:FindFirstChild("Words").Text)
		end
	end
	return out
end
miningRoll.OnClientEvent:Fire({ MinerId = 9, MinerName = "Kade", Gem = { Tier = "Uncommon", Element = "Fire" } })
check(#lines() == 0, "An Uncommon find went in the feed")
miningRoll.OnClientEvent:Fire({ MinerId = 9, MinerName = "Kade", Gem = { Tier = "UltraRare", Element = "Fire" } })
check(
	#lines() == 1 and string.find(lines()[1], "Ultra Rare", 1, true) and string.find(lines()[1], "Thermal", 1, true),
	"A rare find isn't in the feed: " .. tostring(lines()[1])
)
miningRoll.OnClientEvent:Fire({ MinerId = 1, MinerName = "Marc", Gem = { Tier = "Rare", Element = "Frost" } })
check(string.find(lines()[2], "<b>You</b>", 1, true) ~= nil, "Your own find doesn't say You")
miningRoll.OnClientEvent:Fire({ MinerId = 9, MinerName = "<b>x</b>", Gem = { Tier = "Legendary", Element = "Fire" } })
check(string.find(lines()[3], "&lt;b&gt;x&lt;/b&gt;", 1, true) ~= nil, "A name's markup wasn't escaped")
social.OnClientEvent:Fire("Feed", "⚔ Mira defeated Orrin in a friendly duel (Casual).")
check(#lines() == 3, "More than three lines: " .. #lines())
check(
	string.find(lines()[3], "Mira defeated Orrin", 1, true) and not string.find(lines()[3], "⚔", 1, true),
	"The duel line is wrong"
)
social.OnClientEvent:Fire("Queue", { Mode = "1v1" })
check(#lines() == 3, "A non-feed social event went in")
miningRoll.OnClientEvent:Fire({ MinerId = 9, MinerName = "Kade" })
miningRoll.OnClientEvent:Fire("junk")
Players.PlayerAdded:Fire({ DisplayName = "Juno" })
check(string.find(lines()[3], "Juno", 1, true) ~= nil, "A new arrival isn't in the feed")
-- The lobby hidden: nothing piles up.
gui.Enabled = false
miningRoll.OnClientEvent:Fire({ MinerId = 9, MinerName = "Kade", Gem = { Tier = "Legendary", Element = "Fire" } })
check(string.find(lines()[3], "Juno", 1, true) ~= nil, "The feed took a line while the lobby was hidden")
gui.Enabled = true

-- The welcome banner: only with a reward paid this session, and only once.
LobbyFeed.welcome()
check(gui:FindFirstChild("Welcome") == nil, "A banner without a reward")
player:SetAttribute("DailyReward", 125)
player:SetAttribute("DailyStreak", 3)
LobbyFeed.welcome()
local banner = gui:FindFirstChild("Welcome")
check(banner ~= nil, "No welcome banner")
check(gui:GetAttribute("WelcomeOpen") == true, "The Tasks button wasn't told to step aside")
local words = {}
for _, d in banner:GetDescendants() do
	if d.ClassName == "TextLabel" then
		table.insert(words, d.Text)
	end
end
local all = table.concat(words, "|")
check(
	string.find(all, "DAY 3 STREAK", 1, true) and string.find(all, "+125 ◆", 1, true),
	"The banner is wrong: " .. all
)
local nextReward = Config.DailyRewardBase + Config.DailyRewardPerStreak * 3
check(string.find(all, "+" .. nextReward .. " ◆", 1, true) ~= nil, "Tomorrow's reward is missing from the banner")
for _, d in banner:GetDescendants() do
	if d.ClassName == "TextButton" and d.Text == "LET'S GO" then
		d.Activated:Fire()
	end
end
check(gui:GetAttribute("WelcomeOpen") == nil, "Closing the banner didn't bring the Tasks button back")
banner:Destroy()
LobbyFeed.welcome()
check(gui:FindFirstChild("Welcome") == nil, "The banner showed twice")
print(
	"PASS: "
		.. (checks - feedChecks)
		.. " lobby feed checks (rare finds only, You, escaped names, three lines, duels, arrivals, hidden lobby, welcome once)"
)
