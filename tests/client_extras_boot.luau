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
	LocalizationService = { RobloxLocaleId = "en-us" },
}
local game = { GetService = function(_, n) return services[n] or error("no service " .. n) end }
local camera = { ViewportSize = roblox.Vector2.new(1280, 720) }
local workspaceStub = { CurrentCamera = camera, GetServerTimeNow = function() return os.clock() end }

local requests = {}
local drawnPiece = nil
local analyticsAnswer = nil -- (set below, once the shared modules load)
local GemClient = {
	Profile = { Intro = { Done = true }, Funnel = {}, TrainingRewards = { Counts = {} }, Settings = { Music = 0.4, MusicOn = false } },
	Changed = signal(),
	request = function(action, ...)
		table.insert(requests, { action, ... })
		if action == "AnalyticsReport" and analyticsAnswer then
			return analyticsAnswer(...)
		end
		return { Ok = true, Message = "" }
	end,
}
local stubs = {
	GemClient = GemClient,
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
social:Fire("IntroRound", { Phase = "Won", Round = 1, Piece = { Slot = "Weapon", Name = "Cryo-Edge Saber", Rarity = "Uncommon", Id = "w1" }, Gem = { Name = "Ember" }, View = IntroRounds.view(state) })
task.wait(3.2)
do
	local card = playerGui:FindFirstChild("IntroRounds")
	local piece = card and card:FindFirstChild("Piece", true)
	check(drawnPiece and drawnPiece[2] == "Weapon" and drawnPiece[3] == "w1", "The won piece wasn't drawn in 3D")
	check(piece ~= nil and piece:IsA("ViewportFrame"), "No 3D piece on the card")
	attrs.CombatSession = nil
end
social:Fire("IntroRound", { Phase = "Lost", Round = 2, View = IntroRounds.view(state) })
task.wait(2)
for _ = 2, 6 do IntroRounds.won(state, "Rare") end
social:Fire("IntroRound", { Phase = "Won", Round = 6, Piece = { Slot = "Helmet", Name = "Helm", Rarity = "Rare" }, Coins = 500, View = IntroRounds.view(state) })
task.wait(2.5)
local card = playerGui:FindFirstChild("IntroRounds")
check(card ~= nil and card.Enabled, "The intro rounds' card isn't up")
check(load(clientRef.IntroRoundsUI).busy(), "The set's card is up, but it doesn't hold back what comes after it")
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
}
analyticsAnswer = function(range)
	local answer = { Ok = true, Message = "", Range = range, Report = Report.build(rows), Now = day + 700 }
	if range == "Server" then
		answer.Here = { { Name = "Tester", User = "tester", Minutes = 4, New = true, Step = 2, StepName = "Element", Rounds = 1, Level = 2 }, { Name = "Vet", User = "vet", Minutes = 30, New = false } }
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
check(Analytics.commas(1234567) == "1,234,567" and Analytics.minutes(90) == "1h 30m" and Analytics.minutes(0.5) == "30s", "ANALYTICS' number formats")
print(string.format("PASS: %d client extras boot checks (they start, the rounds' card shows a win, a loss and a set, SETTINGS opens, ANALYTICS draws every range)", checks))
process.exit(0) -- (their loops, a button's shine, never end on their own)
