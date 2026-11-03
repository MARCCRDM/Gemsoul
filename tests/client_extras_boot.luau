-- lune run tests/client_extras_boot.luau <repo>
-- Boots the lobby's newer client extras (FirstStepsCoach, IntroRoundsUI,
-- ArenaBarrier, SettingsUI, DevAlerts) for real, with Roblox's own instances
-- (@lune/roblox: wrong property types fail as in the game), the game's real
-- UiKit / IronUi / UiSound, and stand-ins only for the network and services.
-- Then shows the intro rounds' card for a win, a loss and a whole set, and
-- opens SETTINGS. Any error here would have stopped the lobby script.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local ROOT = process.args[1] or "."
local checks = 0
local function check(v, m)
	checks += 1
	if not v then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(m) .. "\n")
		process.exit(1)
	end
end

local function signal()
	local fns = {}
	return {
		Connect = function(_, fn) table.insert(fns, fn); return { Disconnect = function() end } end,
		Wait = function() return nil end,
		Fire = function(_, ...) for _, fn in fns do fn(...) end end,
	}
end
local Enum = roblox.Enum
-- Roblox's instances (their properties type-checked as in the game), wrapped
-- so the events the UI connects (lune has none) are stand-ins.
local real = setmetatable({}, { __mode = "k" })
local function unwrap(v) return real[v] or v end
local EVENTS = { Activated = true, MouseEnter = true, MouseLeave = true, MouseButton1Click = true, MouseButton1Down = true,
	MouseButton1Up = true, InputBegan = true, InputEnded = true, InputChanged = true, Changed = true, ChildAdded = true,
	ChildRemoved = true, AncestryChanged = true, Destroying = true, DidLoop = true, Loaded = true, Ended = true, Played = true,
	FocusLost = true, SelectionGained = true }
local function wrap(inst)
	local p, sigs = {}, {}
	real[p] = inst
	return setmetatable(p, {
		__index = function(_, k)
			if EVENTS[k] then sigs[k] = sigs[k] or signal(); return sigs[k] end
			if k == "GetPropertyChangedSignal" or k == "GetAttributeChangedSignal" then return function() return signal() end end
			if k == "WaitForChild" then
				return function(_, n) local c = inst:FindFirstChild(n); return if c then wrap(c) else nil end
			end
			-- (Properties only a running game fills in: neutral values.)
			if k == "AbsoluteSize" or k == "AbsolutePosition" then
				return if k == "AbsoluteSize" then roblox.Vector2.new(1280, 720) else roblox.Vector2.new(0, 0)
			end
			if k == "TextBounds" then return roblox.Vector2.new(100, 16) end
			local v = inst[k]
			if type(v) == "function" then
				return function(_, ...)
					local args = table.pack(...)
					for i = 1, args.n do args[i] = unwrap(args[i]) end
					return v(inst, table.unpack(args, 1, args.n))
				end
			end
			return v
		end,
		__newindex = function(_, k, v) inst[k] = unwrap(v) end,
	})
end
local Instance = { new = function(class, parent)
	local i = roblox.Instance.new(class)
	if parent then i.Parent = unwrap(parent) end
	return wrap(i)
end }
-- The local player and their PlayerGui (real instances where UI is parented).
local playerGui = roblox.Instance.new("Folder"); playerGui.Name = "PlayerGui"
do -- (the lobby's own ScreenGui, which the coach watches for the PLAY menu)
	local hud = roblox.Instance.new("ScreenGui"); hud.Name = "LobbyHud"; hud.Parent = playerGui
end
local playerGuiProxy = wrap(playerGui)
local attrs, attrSignals = {}, {}
local LocalPlayer = {
	UserId = 1, Name = "Tester", DisplayName = "Tester", Character = nil,
	WaitForChild = function(_, n) if n == "PlayerGui" then return playerGuiProxy end end,
	FindFirstChild = function(_, n) if n == "PlayerGui" then return playerGuiProxy end end,
	GetAttribute = function(_, k) return attrs[k] end,
	SetAttribute = function(_, k, v) attrs[k] = v; if attrSignals[k] then attrSignals[k]:Fire() end end,
	GetAttributeChangedSignal = function(_, k) attrSignals[k] = attrSignals[k] or signal(); return attrSignals[k] end,
}
-- (PlayerGui's WaitForChild for the lobby's ScreenGui: none in this boot.)
local social = signal()
local remotesFolder = {
	WaitForChild = function(_, n) return { OnClientEvent = social, FireServer = function() end, Name = n } end,
}
local sharedRef = setmetatable({}, { __index = function(_, k) return { Kind = "shared", Name = k } end })
local clientRef = setmetatable({}, { __index = function(_, k) return { Kind = "client", Name = k } end })
local soundService = roblox.Instance.new("Folder")
local tween = { Play = function() end, Completed = signal() }
local services = {
	Players = { LocalPlayer = LocalPlayer },
	ReplicatedStorage = { Shared = sharedRef, WaitForChild = function(_, n) if n == "Remotes" then return remotesFolder end end, FindFirstChild = function() return nil end },
	TweenService = { Create = function() return tween end },
	RunService = { Heartbeat = signal(), RenderStepped = signal(), IsStudio = function() return true end },
	TextService = { GetTextSize = function() return roblox.Vector2.new(100, 14) end },
	UserInputService = { TouchEnabled = false, KeyboardEnabled = true, GamepadEnabled = false, InputBegan = signal(), InputChanged = signal(), InputEnded = signal() },
	GuiService = { TopbarInset = roblox.Rect.new(290, 0, 1280, 58), GetPropertyChangedSignal = function() return signal() end },
	SoundService = soundService,
	StarterGui = { SetCore = function() end },
	Debris = { AddItem = function() end },
	CollectionService = { GetTagged = function() return {} end, HasTag = function() return false end, GetInstanceAddedSignal = function() return signal() end },
	LocalizationService = { RobloxLocaleId = "en-us" },
}
local game = { GetService = function(_, n) return services[n] or error("no service " .. n) end }
local camera = { ViewportSize = roblox.Vector2.new(1280, 720) }
local workspaceStub = { CurrentCamera = camera, GetServerTimeNow = function() return os.clock() end }

local requests = {}
local drawnPiece = nil
local analyticsAnswer = nil -- (set below, once the shared modules load)
local dungeonAnswer = nil -- (the Rot Beachhead's reply, when it's not a plain Ok)
local roundStateAnswer = nil -- (IntroRoundState's reply, for the lobby's "finish your fights")
local GemClient = {
	Profile = { Intro = { Done = true }, Funnel = {}, TrainingRewards = { Counts = {} }, Settings = { Music = 0.4, MusicOn = false } },
	Changed = signal(),
	request = function(action, ...)
		table.insert(requests, { action, ... })
		if action == "AnalyticsReport" and analyticsAnswer then
			return analyticsAnswer(...)
		end
		if action == "DuelCancel" then
			attrs.DuelQueue = nil
		elseif action == "ArenaLeave" then
			attrs.CombatSession = nil
		elseif action == "FirstDungeon" and dungeonAnswer then
			return dungeonAnswer
		elseif action == "IntroRoundState" and roundStateAnswer then
			return roundStateAnswer
		end
		return { Ok = true, Message = "" }
	end,
}
local kaijuRolled = 0
local stubs = {
	GemClient = GemClient,
	-- (the kaiju roll is its own screen: just that it's played)
	KaijuRoll = { play = function(after) kaijuRolled += 1; if after then after() end end },
	UpgradeHints = { Current = { Equipment = true, Surges = { Changes = 0 } }, Changed = signal() },
	LobbyUI = { openDashboard = function() end, openPicker = function() end },
	Music = { setVolume = function(v) stubsMusic = v end },
	CombatSound = { Volume = 0.85 },
	-- (the piece's 3D art: drawn, as far as the card can tell; GearArt's own
	-- framing is the Inventory's and runs in the game)
	GearArt = { draw = function(view, slot, id) drawnPiece = { view, slot, id }; return true end, icon = function() return nil end },
	Lang = { translate = function(s) return s end, format = function(k, ...) local a = { ... }; return (string.gsub(k, "{(%d)}", function(i) return tostring(a[tonumber(i)]) end)) end },
}
local loaded = {}
local function load(ref)
	local key = ref.Kind .. ":" .. ref.Name
	if loaded[key] ~= nil then return loaded[key] end
	if stubs[ref.Name] then return stubs[ref.Name] end
	local path = if ref.Kind == "shared" then "/src/shared/" else "/src/client/Modules/"
	local env = setmetatable({
		game = game, workspace = workspaceStub, script = { Parent = if ref.Kind == "shared" then sharedRef else clientRef },
		require = function(r) return load(r) end, task = task,
		Instance = Instance, Enum = Enum, Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim,
		Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, TweenInfo = roblox.TweenInfo or { new = function() return {} end },
		NumberRange = roblox.NumberRange, Rect = roblox.Rect, Font = roblox.Font, typeof = roblox.typeof or typeof,
	}, { __index = _G })
	local fn = luau.load(fs.readFile(ROOT .. path .. ref.Name .. ".luau"), { debugName = ref.Name, environment = env })
	loaded[key] = fn()
	return loaded[key]
end

attrs.AnalyticsOwner = true -- (this tester is an owner: the ANALYTICS button shows)
for _, name in { "FirstStepsCoach", "IntroRoundsUI", "ArenaBarrier", "SettingsUI", "DevAlerts", "AnalyticsUI" } do
	require("@lune/stdio").ewrite("starting " .. name .. "\n")
	local ok, problem = pcall(function() load(clientRef[name]).start() end)
	check(ok, name .. " didn't start: " .. tostring(problem))
end
task.wait(0.1)
-- The intro rounds' card: a win, a loss, the whole set.
local IntroRounds = load(sharedRef.IntroRounds)
local state = IntroRounds.state({ Funnel = {} })
IntroRounds.won(state, "Uncommon")
state.Pieces.Weapon = { Name = "Cryo-Edge Saber", Rarity = "Uncommon" }
attrs.CombatSession = "Training" -- (in the Arena: the card's up 1.2 s after the win)
local strip = {}
for i = 1, 28 do
	strip[i] = { Name = if i == 24 then "Cryo-Edge Saber" else "Blade " .. i, Rarity = if i % 5 == 0 then "Rare" else "Uncommon" }
end
social:Fire("IntroRound", { Phase = "Won", Round = 1, Piece = { Slot = "Weapon", Name = "Cryo-Edge Saber", Rarity = "Uncommon", Id = "w1" }, Reel = strip, ReelLand = 24, Gem = { Name = "Ember" }, View = IntroRounds.view(state), Hunt = true })
task.wait(2.5)
do -- (mid-roll: the strip's up, every piece on it, the marker over it)
	local card = playerGui:FindFirstChild("IntroRounds")
	local roll = card and card:FindFirstChild("Roll", true)
	local marker = card and card:FindFirstChild("Marker", true)
	local tiles = 0
	for _, d in (roll and roll:GetDescendants() or {}) do
		if string.match(d.Name, "^Tile%d+$") then
			tiles += 1
		end
	end
	check(roll ~= nil and roll.Visible and marker ~= nil and marker.Visible, "The items' roll isn't spinning on the card")
	check(tiles == 28, "The roll's strip has " .. tiles .. " pieces, not 28")
end
task.wait(3.2)
do
	local card = playerGui:FindFirstChild("IntroRounds")
	local piece = card and card:FindFirstChild("Piece", true)
	check(drawnPiece and drawnPiece[2] == "Weapon" and drawnPiece[3] == "w1", "The won piece wasn't drawn in 3D")
	check(piece ~= nil and piece:IsA("ViewportFrame"), "No 3D piece on the card")
	-- (the first fight won: one way on, HUNT BOUNTY, with its boss; no lobby,
	-- no countdown taking it for them)
	local go, leave, dungeon = card:FindFirstChild("Next", true), card:FindFirstChild("Leave", true), card:FindFirstChild("Dungeon", true)
	check(kaijuRolled == 0, "The kaiju roll played straight after the first win (it waits for their pick)")
	check(go and go.Text == "HUNT BOUNTY" and go.Visible, "No HUNT BOUNTY after the first win: " .. tostring(go and go.Text))
	local goSub = go and go:FindFirstChild("Sub")
	check(goSub and string.find(goSub.Text, "Bombardiro Drago", 1, true) ~= nil and string.find(goSub.Text, "starts in", 1, true) == nil, "HUNT BOUNTY's boss, or a countdown on it: " .. tostring(goSub and goSub.Text))
	local boss = false
	for _, d in card:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "BOMBARDIRO DRAGO" and d.Visible then
			boss = true
		end
	end
	check(boss, "The card doesn't show the bounty's boss")
	-- (the bounty on show: its boss in a window, what it pays; and beside
	-- HUNT BOUNTY, CONTINUE ROUNDS: the next 1v1. Still no lobby.)
	local bounty = card:FindFirstChild("Bounty", true)
	check(bounty and bounty.Visible and bounty:FindFirstChild("Boss"), "The bounty isn't on show on the card")
	check(leave and leave.Visible and leave.Text == "CONTINUE ROUNDS", "No CONTINUE ROUNDS beside HUNT BOUNTY: " .. tostring(leave and leave.Text))
	check(not (dungeon and dungeon.Visible), "A third way on beside HUNT BOUNTY")
	check(go.Modal == true, "HUNT BOUNTY can't be clicked with the camera locked")
	-- CONTINUE ROUNDS: their kaiju team first (the starter roll, owed), then
	-- the next round, not the dungeon.
	local before = #requests
	load(clientRef.IntroRoundsUI).continueRounds()
	task.wait(0.5)
	local asked = {}
	for i = before + 1, #requests do
		asked[requests[i][1]] = requests[i][2] or true
	end
	check(kaijuRolled == 1, "CONTINUE ROUNDS didn't roll their kaiju first")
	check(asked.IntroRoundNext and not asked.IntroRoundChoose, "CONTINUE ROUNDS didn't start the next round")
	-- The next win's card offers the bounty again: HUNT BOUNTY (Enter, or a
	-- click: both are next()) goes to the dungeon, never the next round.
	local again = IntroRounds.state({ Funnel = {} })
	IntroRounds.won(again, "Uncommon")
	IntroRounds.won(again, "Uncommon")
	social:Fire("IntroRound", { Phase = "Won", Round = 2, Piece = { Slot = "Shield", Name = "Shield", Rarity = "Uncommon" }, View = IntroRounds.view(again), Hunt = true })
	task.wait(1.5 + load(clientRef.IntroRoundsUI).RollSeconds + 1)
	check(card:FindFirstChild("Next", true).Text == "HUNT BOUNTY", "The next win's card doesn't offer the bounty again")
	before = #requests
	load(clientRef.IntroRoundsUI).next()
	task.wait(0.2)
	asked = {}
	for i = before + 1, #requests do
		asked[requests[i][1]] = requests[i][2] or true
	end
	check(asked.IntroRoundChoose == "Boss" and not asked.IntroRoundNext, "HUNT BOUNTY didn't go to the dungeon (it started the next round)")
	attrs.CombatSession = nil
end
-- The first dungeon cleared (the server sends no Hunt): a later win's card is
-- the next round, never HUNT BOUNTY again.
do
	attrs.CombatSession = "Training"
	local later = IntroRounds.state({ Funnel = {} })
	for _ = 1, 3 do IntroRounds.won(later, "Uncommon") end
	social:Fire("IntroRound", { Phase = "Won", Round = 3, Piece = { Slot = "Armor", Name = "Rig", Rarity = "Uncommon" }, View = IntroRounds.view(later) })
	task.wait(1.5 + load(clientRef.IntroRoundsUI).RollSeconds + 1)
	local card = playerGui:FindFirstChild("IntroRounds")
	local go = card and card:FindFirstChild("Next", true)
	check(go and go.Visible and string.find(go.Text, "HUNT BOUNTY", 1, true) == nil, "HUNT BOUNTY again after the first dungeon: " .. tostring(go and go.Text))
	check(string.find(go.Text, "CONTINUE INTRO ROUNDS", 1, true) ~= nil, "A later win isn't the next round: " .. tostring(go.Text))
	attrs.CombatSession = nil
	task.wait(2)
end
load(clientRef.IntroRoundsUI).AutoNext = 1 -- (the loss's card on its way before the set's: a round between them in the game)
social:Fire("IntroRound", { Phase = "Lost", Round = 2, View = IntroRounds.view(state) })
task.wait(2)
for _ = 2, 6 do IntroRounds.won(state, "Rare") end
social:Fire("IntroRound", { Phase = "Won", Round = 6, Piece = { Slot = "Helmet", Name = "Helm", Rarity = "Rare" }, Coins = 500, View = IntroRounds.view(state) })
task.wait(2.5)
local card = playerGui:FindFirstChild("IntroRounds")
check(card ~= nil and card.Enabled, "The intro rounds' card isn't up")
check(load(clientRef.IntroRoundsUI).busy(), "The set's card is up, but it doesn't hold back what comes after it")
do -- (the set done: CONTINUE, out to the mines; the first dungeon's off for now, an owner's too)
	task.wait(2.5) -- (out of the Arena, a card's up 4.5 s after its event)
	local go = card:FindFirstChild("Next", true)
	check(go.Text == "CONTINUE" and not card:FindFirstChild("Leave", true).Visible, "The set's card: " .. go.Text .. " " .. tostring(card:FindFirstChild("Leave", true).Visible))
	attrs.CanTestDungeon = true
	social:Fire("IntroRound", { Phase = "Lost", Round = 2, View = IntroRounds.view(IntroRounds.state({ Funnel = {} })) })
	task.wait(5)
	local dungeon = card:FindFirstChild("Dungeon", true)
	check(not dungeon.Visible and not card:FindFirstChild("Leave", true).Visible, "FIRST DUNGEON or GO TO LOBBY on a mid-set loss")
	check(card:FindFirstChild("Next", true).Text == "TRY AGAIN", "A loss's TRY AGAIN")
	attrs.CanTestDungeon = nil
end
-- SETTINGS: opens, and the saved settings were applied.
local Settings = load(clientRef.SettingsUI)
local ok, problem = pcall(Settings.open)
check(ok, "SETTINGS didn't open: " .. tostring(problem))
check(playerGui:FindFirstChild("Settings") and playerGui:FindFirstChild("SettingsButton"), "No SETTINGS window or gear")
check(stubsMusic == 0, "Music off wasn't applied (got " .. tostring(stubsMusic) .. ")")
check(playerGui:FindFirstChild("FirstSteps") ~= nil, "No NEXT STEP card")
-- ANALYTICS: the button, and the window drawing each range from a real report.
local Report = load(sharedRef.AnalyticsReport)
local day = 1793491200 -- (2026-11-01 00:00 UTC)
local rows = {
	{ day + 60, 1, "session_start", 0, "new", "US" }, { day + 61, 1, "device", 1, "phone", "844x390", "en-us" },
	{ day + 62, 1, "onboarding", 1, "Joined" }, { day + 70, 1, "onboarding", 2, "Element" }, { day + 80, 1, "IntroRound", 1, "Weapon", "Rare", "Won" },
	{ day + 90, 1, "coins", 250, "Duel", "Gameplay" }, { day + 91, 1, "coins", -50, "Store", "Shop" }, { day + 92, 1, "Purchase", 99, "Coins10k", "Robux" },
	{ day + 93, 1, "DuelFinished", 1, "Ranked", "Win", "1v1" }, { day + 660, 1, "session_end", 600, 3, 100, 80 },
	{ day + 61, 2, "session_start", 0, "returning", "BR" }, { day + 300, 0, "server", 2, 700 },
	{ day + 63, 1, "store_funnel", 1, "R1 start · Sword", "IntroRounds" }, { day + 81, 1, "store_funnel", 2, "R1 won · Sword", "IntroRounds" },
}
analyticsAnswer = function(range)
	local answer = { Ok = true, Message = "", Range = range, Report = Report.build(rows), Now = day + 700 }
	if range == "Server" then
		answer.Here = { { UserId = 5, Name = "Tester", User = "tester", Minutes = 4, New = true, Step = 2, StepName = "Element", Rounds = 1, Level = 2 }, { UserId = 6, Name = "Vet", User = "vet", Minutes = 30, New = false, Excluded = true }, { UserId = 1, Name = "Dev", User = "dev", Minutes = 9, Listed = true, Excluded = true } }
		answer.Since, answer.Server = day, "abcd1234"
	else
		answer.Loading = { Done = 3, Total = 7, Busy = true }
	end
	return answer
end
task.wait(0.1)
check(playerGui:FindFirstChild("AnalyticsButton") ~= nil, "No ANALYTICS button for an owner")
local Analytics = load(clientRef.AnalyticsUI)
for _, which in { "Server", "Today", "Week" } do
	local okOpen, why = pcall(Analytics.open, which)
	check(okOpen, "ANALYTICS didn't open on " .. which .. ": " .. tostring(why))
	task.wait(0.2)
end
local analytics = playerGui:FindFirstChild("Analytics")
check(analytics ~= nil and analytics.Enabled, "The ANALYTICS window isn't up")
local seen = {}
for _, d in analytics:GetDescendants() do
	if d:IsA("TextLabel") then
		seen[d.Text] = true
	end
end
check(seen["Reading the saved logs…  3 / 7"], "ANALYTICS didn't draw 7 DAYS' loading line")
check(seen["PLAYERS"] and seen["2"] and seen["99"] and seen["1  Joined"], "ANALYTICS didn't draw the report (tiles, funnel)")
check(seen["R1 start · Sword"] and seen["R1 won · Sword"], "ANALYTICS didn't draw the intro rounds' funnel")
do -- (who's in the numbers: a toggle each, a dev account just says so)
	local counted, notCounted = 0, 0
	for _, d in analytics:GetDescendants() do
		if d.Name == "Counted" and d:IsA("TextButton") then
			if d.Text == "COUNTED" then counted += 1 elseif d.Text == "NOT COUNTED" then notCounted += 1 end
		end
	end
	check(counted == 1 and notCounted == 1 and seen["DEV · NOT COUNTED"], "PLAYERS HERE NOW's COUNTED / NOT COUNTED")
end
check(Analytics.commas(1234567) == "1,234,567" and Analytics.minutes(90) == "1h 30m" and Analytics.minutes(0.5) == "30s", "ANALYTICS' number formats")
-- The dungeon path's cards (IntroRoundsUI): the second 1v1's says the
-- dungeon's next (CONTINUE); in the dungeon, a card a piece, one way on:
-- ON TO THE BOSS, then the boss's three one after another (NEXT PIECE),
-- the last TO THE LOBBY (FirstDungeonDone).
do
	local Cards = load(clientRef.IntroRoundsUI)
	local card = playerGui:FindFirstChild("IntroRounds")
	if card and card.Enabled then
		card.Enabled = false
	end
	local st = IntroRounds.state({ Funnel = {} })
	IntroRounds.won(st, "Uncommon")
	IntroRounds.won(st, "Uncommon")
	social:Fire("IntroRound", { Phase = "Won", Round = 2, Next = "Dungeon", Piece = { Slot = "Shield", Name = "Buckler", Rarity = "Uncommon" }, View = IntroRounds.view(st) })
	task.wait(9)
	card = playerGui:FindFirstChild("IntroRounds")
	check(card.Enabled and card:FindFirstChild("Next", true).Text == "CONTINUE", "The second 1v1's card doesn't say CONTINUE (to the dungeon)")
	check(not card:FindFirstChild("Dungeon", true).Visible, "FIRST DUNGEON beside the dungeon path's CONTINUE")
	card.Enabled = false
	local function dungeonCard(round, more, done)
		local s2 = IntroRounds.state({ Funnel = {} })
		for _ = 1, round do
			IntroRounds.won(s2, "Uncommon")
		end
		return { Phase = "Won", Round = round, Where = "Dungeon", More = more, Piece = { Slot = IntroRounds.slot(round), Name = "Piece " .. round, Rarity = "Uncommon" }, View = IntroRounds.view(s2), Coins = if done then 500 else nil }
	end
	social:Fire("IntroRound", dungeonCard(3, 0, false))
	task.wait(1.5)
	check(card.Enabled and card:FindFirstChild("Next", true).Text == "ON TO THE BOSS", "The first room's card isn't ON TO THE BOSS")
	check(not card:FindFirstChild("Leave", true).Visible, "GO TO LOBBY on a dungeon card")
	Cards.next()
	check(not card.Enabled, "ON TO THE BOSS didn't close the card")
	social:Fire("IntroRound", dungeonCard(4, 2, false))
	social:Fire("IntroRound", dungeonCard(5, 1, false))
	social:Fire("IntroRound", dungeonCard(6, 0, true))
	task.wait(1.5)
	check(card.Enabled and card:FindFirstChild("Next", true).Text == "NEXT PIECE", "The boss's first card isn't NEXT PIECE")
	check(Cards.busy(), "The boss's cards don't hold back what comes after")
	Cards.next()
	check(card.Enabled and card:FindFirstChild("Next", true).Text == "NEXT PIECE", "The boss's second card")
	Cards.next()
	check(card.Enabled and card:FindFirstChild("Next", true).Text == "TO THE LOBBY", "The last card isn't TO THE LOBBY")
	local before = #requests
	Cards.next()
	task.wait(0.2)
	local asked = false
	for i = before + 1, #requests do
		asked = asked or requests[i][1] == "FirstDungeonDone"
	end
	check(asked and not card.Enabled and not Cards.busy(), "TO THE LOBBY didn't take you out")
end

-- The Rot Beachhead (FirstDungeonUI): its loading screens, then in; the
-- knock-down card's RECOVER and FINISH THE INTRO FIGHTS.
do
	local First = load(clientRef.FirstDungeonUI)
	First.SlideSeconds = 0.15
	local rolledBefore = kaijuRolled
	attrs.DuelQueue, attrs.CombatSession = "Intro", "Training" -- (a new player, queued for the next round)
	local before = #requests
	local okPlay, message = pcall(First.play)
	check(okPlay and message == nil, "FIRST DUNGEON didn't play: " .. tostring(message))
	local asked = false
	for i = before + 1, #requests do
		if requests[i][1] == "FirstDungeon" then
			asked = true
		end
	end
	check(asked, "FIRST DUNGEON didn't ask to go in")
	check(kaijuRolled == rolledBefore + 1, "A new player's kaiju roll didn't come first")
	local order = {}
	for i = before + 1, #requests do
		table.insert(order, requests[i][1])
	end
	check(table.concat(order, ",") == "DuelCancel,ArenaLeave,FirstDungeon", "Not out of the queue and the Arena first: " .. table.concat(order, ","))
	-- Refused: the reason on the screen.
	attrs.DungeonId = nil
	dungeonAnswer = { Ok = false, Message = "Dungeon setup failed." }
	local okAgain, why = pcall(First.play)
	check(okAgain and why == "Dungeon setup failed.", "A refusal's reason: " .. tostring(why))
	local problem = playerGui:FindFirstChild("FirstDungeonProblem")
	local reason = problem and problem:FindFirstChild("Reason", true)
	check(reason ~= nil and reason.Text == "Dungeon setup failed.", "The refusal isn't on the screen")
	problem:Destroy()
	dungeonAnswer = nil
	check(playerGui:FindFirstChild("FirstDungeonIntro") == nil, "The loading screens stayed up")
	-- In: the combat screen's LEAVE opens its card: back to the intro fights, the lobby, or stay.
	social:Fire("FirstDungeon", { Phase = "In", RoundsLeft = 4 })
	task.wait(0.2)
	check(playerGui:FindFirstChild("FirstDungeonLeave") == nil, "A second LEAVE over the combat screen's own")
	First.showLeave()
	local leaveCard = playerGui:FindFirstChild("FirstDungeonLeaveCard")
	local intro = leaveCard and leaveCard:FindFirstChild("Intro", true)
	check(intro ~= nil and string.find(intro.Text, "4 LEFT", 1, true) ~= nil, "LEAVE's card: no FINISH THE INTRO FIGHTS (4 LEFT)")
	check(leaveCard:FindFirstChild("Lobby", true) ~= nil and leaveCard:FindFirstChild("Stay", true) ~= nil, "LEAVE's card: no GO TO LOBBY or STAY")
	local quitsBefore = #requests
	First.leave("Lobby")
	check(requests[quitsBefore + 1] and requests[quitsBefore + 1][1] == "FirstDungeonQuit" and requests[quitsBefore + 1][2] == "Lobby", "GO TO LOBBY didn't ask to leave for the lobby")
	check(playerGui:FindFirstChild("FirstDungeonLeaveCard") == nil, "LEAVE's card stayed up")
	-- Knocked down: RECOVER, or out (the intro fights while rounds are left, the lobby).
	social:Fire("FirstDungeon", { Phase = "Down", Room = "Room 1: The Gate", RoundsLeft = 4, Seconds = 30 })
	task.wait(0.2)
	local down = playerGui:FindFirstChild("FirstDungeonDown")
	check(down ~= nil, "No knock-down card")
	check(down and down:FindFirstChild("Recover", true) ~= nil, "No RECOVER")
	local quit = down and down:FindFirstChild("Intro", true)
	check(quit ~= nil and string.find(quit.Text, "4 LEFT", 1, true) ~= nil, "No FINISH THE INTRO FIGHTS (4 LEFT)")
	check(down and down:FindFirstChild("Lobby", true) ~= nil, "No GO TO LOBBY on the knock-down card")
	social:Fire("FirstDungeon", { Phase = "Down", Room = "The Nest", Boss = "Chimpanzini", RoundsLeft = 0, Seconds = 30 })
	task.wait(0.2)
	down = playerGui:FindFirstChild("FirstDungeonDown")
	check(down ~= nil and down:FindFirstChild("Intro", true) == nil, "Back to the intro fights offered with none left")
	check(down:FindFirstChild("Lobby", true) ~= nil, "No GO TO LOBBY with the intro done")
end
-- The first dungeon's window (IntroFinale), right after the kaiju's first
-- fight: its boss, what you'd win as tiles, ENTER DUNGEON or LATER; left
-- alone, LATER, and the answer goes to the server.
do
	local Finale = load(clientRef.IntroFinale)
	check(Finale.InviteAfter <= 5, "The first dungeon isn't asked shortly after the kaiju's fight")
	Finale.InviteFor = 0.4
	local before = #requests
	local picked = nil
	task.spawn(function()
		picked = Finale._invite()
	end)
	task.wait(0.15)
	local gui = playerGui:FindFirstChild("IntroFinale")
	local card = gui and gui:FindFirstChild("Card", true)
	check(card ~= nil, "No first dungeon window")
	if card then
		local name = card:FindFirstChild("BossName", true)
		check(name ~= nil and name.Text == "BOMBARDIRO DRAGO", "The window doesn't name its boss")
		local tiles = 0
		for i = 1, 6 do
			if card:FindFirstChild("Reward" .. i, true) then
				tiles += 1
			end
		end
		check(tiles == 4, "Not four reward tiles: " .. tiles)
		local coins = card:FindFirstChild("Reward1", true)
		local RiftRun = load(sharedRef.RiftRun)
		local shown = false
		for _, d in coins:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == tostring(RiftRun.rewardCoins(RiftRun.Rooms)) then
				shown = true
			end
		end
		check(shown, "The coins tile doesn't show what a boss run pays")
		check(card:FindFirstChild("Boss", true) ~= nil, "No boss figure on the window")
		local go = card:FindFirstChild("Go", true)
		check(go ~= nil and string.find(go.Text, "ENTER DUNGEON", 1, true) ~= nil, "No ENTER DUNGEON")
		check(card:FindFirstChild("Later", true) ~= nil, "No LATER")
	end
	task.wait(0.6)
	check(picked == "Later", "Left alone, the window wasn't LATER: " .. tostring(picked))
	local told = false
	for i = before + 1, #requests do
		told = told or (requests[i][1] == "IntroFinale" and requests[i][2] == "Invite" and requests[i][3] == "Later")
	end
	check(told, "The answer wasn't sent to the server")
	check(gui:FindFirstChild("FirstBoss") == nil, "The window stayed up")
	-- The first dungeon owed (HUNT BOUNTY): NEXT EVENT, one button, no LATER;
	-- it waits for them (Enter takes them in).
	local hunted = nil
	task.spawn(function()
		hunted = Finale._invite(true)
	end)
	task.wait(0.15)
	local hcard = gui:FindFirstChild("Card", true)
	local heading = hcard and hcard:FindFirstChild("Heading", true)
	check(heading ~= nil and string.find(heading.Text, "HUNT BOUNTY", 1, true) ~= nil, "The hunt's window isn't NEXT EVENT · HUNT BOUNTY")
	-- (and a way out of it: LATER and the corner's X)
	check(hcard and hcard:FindFirstChild("Later", true) ~= nil and hcard:FindFirstChild("Close", true) ~= nil, "No way out of the hunt's window (LATER, X)")
	local goHunt = hcard and hcard:FindFirstChild("Go", true)
	check(goHunt ~= nil and string.find(goHunt.Text, "HUNT BOUNTY", 1, true) ~= nil, "No HUNT BOUNTY button")
	-- (its prize: the first dungeon's purse and a new kaiju)
	local IR = load(sharedRef.IntroRounds)
	local seen = {}
	for _, d in hcard:GetDescendants() do
		if d:IsA("TextLabel") then
			seen[d.Text] = true
		end
	end
	check(seen[tostring(IR.FirstDungeonCoins)] and IR.FirstDungeonCoins == 1000, "The hunt's coins tile isn't 1000")
	check(seen["NEW KAIJU"] and seen["+1"], "The hunt's kaiju tile isn't +1 NEW KAIJU")
	task.wait(0.6)
	check(hunted == nil and gui:FindFirstChild("FirstBoss") ~= nil, "The hunt's window went by itself")
	services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Return })
	task.wait(0.2)
	check(hunted == "Go" and gui:FindFirstChild("FirstBoss") == nil, "Enter didn't take them to the hunt")
	-- The hunt with the starter roll still owed (a first win from before it
	-- was rolled there): the kaiju roll first, then the window.
	do
		local profile = GemClient.Profile
		local was = { profile.Kaiju, profile.KaijuRolled }
		profile.Kaiju, profile.KaijuRolled = { List = {}, Next = 1 }, nil
		local rolledBefore = kaijuRolled
		local huntDone = false
		task.spawn(function()
			Finale.hunt()
			huntDone = true
		end)
		task.wait(2)
		check(kaijuRolled == rolledBefore + 1, "The hunt let them into the dungeon without their kaiju")
		check(gui:FindFirstChild("FirstBoss") ~= nil, "No hunt window after the kaiju roll")
		services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Return })
		task.wait(0.3)
		check(huntDone, "The hunt didn't go on to the gate")
		profile.Kaiju, profile.KaijuRolled = was[1], was[2]
	end
	-- After the lobby's intro: RECOMMENDED, FINISH YOUR INTRO FIGHTS (5 left).
	roundStateAnswer = { Ok = true, Message = "", View = { Won = 1, Count = 6, Done = false } }
	Finale.FinishFor = 0.4
	local finish = nil
	task.spawn(function()
		finish = Finale._recommend()
	end)
	task.wait(0.15)
	local fcard = gui:FindFirstChild("FinishFights")
	local left = fcard and fcard:FindFirstChild("Left", true)
	check(left ~= nil and string.find(left.Text, "5 left", 1, true) ~= nil, "No FINISH YOUR INTRO FIGHTS (5 left)")
	check(fcard:FindFirstChild("Later", true) ~= nil and fcard:FindFirstChild("Go", true) ~= nil, "No LATER or CONTINUE FIGHTS")
	task.wait(0.6)
	check(finish == "Later" and gui:FindFirstChild("FinishFights") == nil, "Left alone, it wasn't LATER")
	local beforeGo = #requests
	task.spawn(function()
		finish = Finale._recommend()
	end)
	task.wait(0.15)
	services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Return })
	task.wait(0.2)
	local resumed = false
	for i = beforeGo + 1, #requests do
		resumed = resumed or requests[i][1] == "IntroRoundNext"
	end
	check(finish == "Go" and resumed, "CONTINUE FIGHTS didn't take them back to the rounds")
	-- (the set done: nothing to recommend)
	roundStateAnswer = { Ok = true, Message = "", View = { Won = 6, Count = 6, Done = true } }
	check(Finale._recommend() == nil and gui:FindFirstChild("FinishFights") == nil, "Recommended fights with the set done")
	roundStateAnswer = nil
end
print(string.format("PASS: %d client extras boot checks (they start, the rounds' card shows a win (HUNT BOUNTY, its one way on), a loss and a set, SETTINGS opens, ANALYTICS draws every range, the dungeon path's cards, the Rot Beachhead's screens and knock-down card, the first dungeon's window, the hunt, finish your fights)", checks))
process.exit(0) -- (their loops, a button's shine, never end on their own)
