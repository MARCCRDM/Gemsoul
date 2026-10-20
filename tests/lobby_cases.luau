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
-- A new player on a desktop: streak and challenges (no task card: tasks open
-- from the menu's TASKS tile).
GemClient.Profile = {
	Coins = 300,
	Daily = { Streak = 1 },
	TrainingRewards = { Paid = {}, Counts = {} },
	Challenges = challengesView(0),
}
LobbyBoard.refresh()
check(shown() == "Challenges,Streak", "Desktop cards wrong: " .. shown())
check(card("NextTask") == nil, "The board still has a task card")
-- Folded to rows: each its title, one line and a thin bar.
check(LobbyBoard.layout() == 2 * 48 + 8, "The desktop cards aren't folded to rows: " .. LobbyBoard.layout())
-- What a card says (just what's on show).
local function strip(name)
	local root = card(name)
	local function seen(node)
		while node and node ~= root do
			if node.Visible == false then
				return false
			end
			node = node.Parent
		end
		return true
	end
	local words = {}
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextLabel" and d.Text ~= "" and seen(d) then
			table.insert(words, d.Text)
		end
	end
	table.sort(words)
	return table.concat(words, "|")
end
-- On a phone the board steps off the screen (the challenges are the Tasks
-- window's DAILY page there), learning or not.
LobbyBoard.setCompact(true)
check(LobbyBoard.layout() == 0 and column.Visible == false, "The board stayed up on a phone")
local paid = {}
for _, id in { "FirstRock", "ThreeRocks", "GemFind", "Enchant", "ThreeSlots", "EquipSurge" } do
	paid[id] = true
end
GemClient.Profile.TrainingRewards = { Paid = paid, Counts = {} }
LobbyBoard.refresh()
check(column.Visible == false, "The board came back on a phone after learning")
LobbyBoard.setCompact(false)
check(column.Visible == true and shown() == "Challenges,Streak", "The board didn't come back on a computer")
LobbyBoard.setCompact(true)
-- The PLAY menu open: the whole board steps aside.
LobbyBoard.setCompact(false)
LobbyBoard.setHidden(true)
check(column.Visible == false, "The board stayed over the PLAY menu")
LobbyBoard.setHidden(false)
check(column.Visible == true, "The board didn't come back")
check(card("Challenges"):FindFirstChild("Title").Text == "DAILY CHALLENGES", "The desktop title is wrong")
check(card("Challenges"):FindFirstChild("Title").Visible == true, "The desktop lost the heading")
-- Folded, the challenges row names the next one to do; tapping a row opens
-- that card, tapping another folds it, and tapping the open one folds it.
local function openRows()
	local n = 0
	for i = 1, 3 do
		if card("Challenges"):FindFirstChild("Row" .. i).Visible then
			n += 1
		end
	end
	return n
end
local folded = strip("Challenges")
check(openRows() == 0, "The folded challenges card shows its rows")
check(
	string.find(folded, "Break 10 rocks", 1, true) and string.find(folded, "3/10", 1, true),
	"The folded challenges row doesn't name the next one: " .. folded
)
card("Challenges").Activated:Fire()
check(
	openRows() == 3 and LobbyBoard.layout() == (40 + 3 * 48 + 26) + 48 + 8,
	"Tapping the challenges didn't open them: " .. LobbyBoard.layout()
)
card("Streak").Activated:Fire()
check(openRows() == 0 and LobbyBoard.layout() == 88 + 48 + 8, "Opening the streak didn't fold the challenges")
card("Streak").Activated:Fire()
check(LobbyBoard.layout() == 2 * 48 + 8, "Tapping the open streak didn't fold it")
card("Challenges").Activated:Fire()

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
local before, streak = texts(card("Streak")), GemClient.Profile.Daily
GemClient.Profile.Daily = { Streak = 1 }
GemClient.Changed:Fire(GemClient.Profile)
check(texts(card("Streak")) == before, "The board redrew while the lobby was hidden")
gui.Enabled = true
check(texts(card("Streak")) ~= before, "The board didn't catch up as the lobby showed")
GemClient.Profile.Daily = streak
GemClient.Changed:Fire(GemClient.Profile)
check(texts(card("Streak")) == before, "The board didn't redraw with the lobby up")
print(
	"PASS: "
		.. checks
		.. " lobby board checks (cards per screen, none on a phone, challenges, bonus, streak, unlock)"
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
-- On a phone the feed steps aside while your loot card has the top middle
-- (MobileLayout.claimTop), and comes back after.
LobbyFeed.setCompact(true, { X = 230, W = 360 })
check(stack.Visible ~= false, "The phone feed hid with nothing at the top")
MobileLayout.claimTop("MinerLoot", true)
check(stack.Visible == false, "The feed stayed under the loot card")
MobileLayout.claimTop("MinerLoot", false)
check(stack.Visible == true, "The feed didn't come back after the loot card")
MobileLayout.claimTop("MinerLoot", true)
LobbyFeed.setCompact(false)
check(stack.Visible == true, "A computer's feed hid for a phone's loot card")
MobileLayout.claimTop("MinerLoot", false)

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
-- The track: every day of the week with its coins, today marked, and the
-- rule for a missed day.
for day = 1, Config.DailyStreakMax do
	local coins = tostring(Config.DailyRewardBase + Config.DailyRewardPerStreak * (day - 1))
	local tile = nil
	for _, d in banner:GetDescendants() do
		if d.Name == "Day" .. day then
			tile = d
		end
	end
	local shown = {}
	for _, d in if tile then tile:GetDescendants() else {} do
		if d.ClassName == "TextLabel" then
			shown[d.Text] = true
		end
	end
	check(tile ~= nil and shown[coins] == true, "Day " .. day .. " doesn't show its " .. coins .. " coins")
	check((shown.TODAY == true) == (day == 3), "TODAY is on the wrong day (" .. day .. ")")
end
check(string.find(all, "DAY 7+", 1, true) ~= nil, "Day 7 doesn't say it keeps paying")
check(string.find(all, "Miss a day", 1, true) ~= nil, "The banner doesn't say what a missed day does")
for _, d in banner:GetDescendants() do
	if d.ClassName == "TextButton" and d.Text == "CONTINUE" then
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
