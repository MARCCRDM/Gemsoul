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
	LocalizationService = { RobloxLocaleId = "en-us" },
}
local game = { GetService = function(_, n) return services[n] or error("no service " .. n) end }
local camera = { ViewportSize = roblox.Vector2.new(1280, 720) }
local workspaceStub = { CurrentCamera = camera, GetServerTimeNow = function() return os.clock() end }

local requests = {}
local drawnPiece = nil
local analyticsAnswer = nil -- (set below, once the shared modules load)
local dungeonAnswer = nil -- (the Rot Beachhead's reply, when it's not a plain Ok)
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
social:Fire("IntroRound", { Phase = "Won", Round = 1, Piece = { Slot = "Weapon", Name = "Cryo-Edge Saber", Rarity = "Uncommon", Id = "w1" }, Reel = strip, ReelLand = 24, Gem = { Name = "Ember" }, View = IntroRounds.view(state) })
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
	-- (three ways on: the next round, the lobby; no first dungeon for a player it's not open to)
	local go, leave, dungeon = card:FindFirstChild("Next", true), card:FindFirstChild("Leave", true), card:FindFirstChild("Dungeon", true)
	check(go and go.Text == "CONTINUE INTRO ROUNDS" and go.Visible, "No CONTINUE INTRO ROUNDS")
	local goSub = go and go:FindFirstChild("Sub")
	check(goSub and string.find(goSub.Text, "Round 2 of 6", 1, true) ~= nil and string.find(goSub.Text, "starts in", 1, true) ~= nil, "CONTINUE INTRO ROUNDS' round and countdown: " .. tostring(goSub and goSub.Text))
	check(leave and leave.Text == "GO TO LOBBY" and leave.Visible, "No GO TO LOBBY")
	check(dungeon and not dungeon.Visible, "FIRST DUNGEON offered to a player it's not open to")
	attrs.CombatSession = nil
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
do -- (the set done: to the lobby; for an owner, TO THE FIRST DUNGEON and the lobby beside it)
	task.wait(2.5) -- (out of the Arena, a card's up 4.5 s after its event)
	local go = card:FindFirstChild("Next", true)
	check(go.Text == "GO TO LOBBY" and not card:FindFirstChild("Leave", true).Visible, "The set's card without the first dungeon: " .. go.Text .. " " .. tostring(card:FindFirstChild("Leave", true).Visible))
	attrs.CanTestDungeon = true
	social:Fire("IntroRound", { Phase = "Lost", Round = 2, View = IntroRounds.view(IntroRounds.state({ Funnel = {} })) })
	task.wait(5)
	local dungeon = card:FindFirstChild("Dungeon", true)
	check(dungeon.Visible and dungeon.Text == "FIRST DUNGEON" and card:FindFirstChild("Leave", true).Visible, "No FIRST DUNGEON beside GO TO LOBBY for an owner")
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
-- The Rot Beachhead (FirstDungeonUI): its loading screens, then in; the
-- knock-down card's RECOVER and FINISH THE INTRO FIGHTS.
do
	local First = load(clientRef.FirstDungeonUI)
	First.SlideSeconds = 0.15
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
	check(kaijuRolled == 1, "A new player's kaiju roll didn't come first")
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
print(string.format("PASS: %d client extras boot checks (they start, the rounds' card shows a win, a loss and a set, SETTINGS opens, ANALYTICS draws every range, the Rot Beachhead's screens and knock-down card)", checks))
process.exit(0) -- (their loops, a button's shine, never end on their own)
