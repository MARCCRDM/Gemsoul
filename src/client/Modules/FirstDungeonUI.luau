--[[
	The new player's first dungeon, the Rot Beachhead (Shared.DungeonRules
	.First, Server Dungeons' "First" mode): for now from the DEV panel's
	FIRST DUNGEON, as it'll play after the intro fights.

	  FirstDungeonUI.allowed() -> bool   whether this player can go in (the
	                        Owners; everyone once Config.Features.FirstDungeon)
	  FirstDungeonUI.play() -> message?   the kaiju roll if one's owed, then
	                        the loading screens (YOUR KAIJU, then the SCOUT
	                        MISSION), then into the dungeon (the pod drop is
	                        the server's). A tap skips a screen. Returns the
	                        server's message when it couldn't start.
	  FirstDungeonUI.start()   in the dungeon (Remotes.Social "FirstDungeon",
	                        Phase "In"): the combat screen's LEAVE (top right)
	                        opens a card with the ways out. Knocked down (Phase "Down"): a
	                        card with RECOVER (back at the start of the room,
	                        its fighters at full too), or out; RECOVER by
	                        itself when its time's up. The ways out: FINISH
	                        THE INTRO FIGHTS (while intro rounds are left to
	                        win: out, and into the next round), GO TO LOBBY.
	  FirstDungeonUI.leave(where)   "Intro" or "Lobby"
	  FirstDungeonUI.Slides   the loading screens' words
	  FirstDungeonUI.SlideSeconds
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local GemClient = require(script.Parent.GemClient)
local Gilt = require(script.Parent.GiltUi)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new
local player = Players.LocalPlayer

local FirstDungeonUI = {}

FirstDungeonUI.SlideSeconds = 2.8
FirstDungeonUI.ShowSlides = false -- the kaiju and scout mission screens before going in (off: the game's own loading)
FirstDungeonUI.Slides = {
	{
		Kicker = "YOUR KAIJU",
		Title = "THEY FIGHT WITH YOU",
		Line = "Your kaiju will defend you and heal you. Keep them close.",
		Team = true,
	},
	{
		Kicker = "INCOMING TRANSMISSION",
		Title = "We don't know what they are.",
		Line = "Something has dug in on the coast. It's spreading.",
	},
	{
		Kicker = "SCOUT MISSION · THE ROT BEACHHEAD",
		Title = "Take these kaiju. Scout that base, then take it.",
		Line = "Two rooms of rot-spawn, then whatever's nesting at the heart of it.",
	},
}

local ROT = Color3.fromRGB(150, 236, 84)

local function tween(object: Instance, seconds: number, props: { [string]: any })
	local t = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextWrapped = if props.TextWrapped == nil then true else props.TextWrapped
	props.Font = props.Font or Gilt.Serif
	return new("TextLabel", props, parent) :: TextLabel
end

-- Your team out's names (the YOUR KAIJU screen).
local function teamNames(): { string }
	local roster = GemClient.Profile and GemClient.Profile.Kaiju
	local names = {}
	if roster and type(roster.List) == "table" then
		for _, id in Kaiju.teamIds(roster) do
			local record = roster.List[id]
			if record then
				table.insert(names, string.upper(Kaiju.nameOf(record)))
			end
		end
	end
	return names
end

-- One loading screen: night over everything, the words rising in, a bar
-- filling along the bottom. A tap moves on.
local function slide(screen: ScreenGui, spec, index: number, count: number)
	local root = new("TextButton", {
		Name = "Slide" .. index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Gilt.Deep,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, screen)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 22, 30)),
			ColorSequenceKeypoint.new(0.6, Gilt.Deep),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 30, 14)),
		}),
	}, root)
	-- (the rot's glow low on the screen)
	local glow = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1.15),
		Size = UDim2.fromScale(1.3, 0.55),
		BackgroundColor3 = ROT,
		BackgroundTransparency = 0.82,
		ZIndex = 10,
	}, root)
	UiKit.round(glow, 400)
	local column = new("Frame", {
		Name = "Words",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.86, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, root)
	new("UISizeConstraint", { MaxSize = Vector2.new(620, math.huge) }, column)
	UiKit.list(column, 12)
	local kicker = text(column, {
		Name = "Kicker",
		Text = spec.Kicker,
		TextSize = 13,
		TextColor3 = if spec.Team then Gilt.Gold else ROT,
		Font = Gilt.Display,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		ZIndex = 11,
	})
	local rule = Gilt.rule(column)
	rule.LayoutOrder, rule.ZIndex = 2, 11
	local title = text(column, {
		Name = "Title",
		Text = spec.Title,
		TextSize = 30,
		TextColor3 = Gilt.Ink,
		Font = Gilt.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		ZIndex = 11,
	})
	kicker.TextXAlignment = Enum.TextXAlignment.Left
	local line = text(column, {
		Name = "Line",
		Text = spec.Line,
		TextSize = 16,
		TextColor3 = Gilt.Faded,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		ZIndex = 11,
	})
	if spec.Team then
		local chips = new("Frame", {
			Name = "Team",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 5,
			ZIndex = 11,
		}, column)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, chips)
		local names = teamNames()
		if #names == 0 then
			names = { "NO KAIJU OUT YET" }
		end
		for i, name in names do
			local chip = new("TextLabel", {
				Name = "Kaiju" .. i,
				Text = name,
				TextSize = 13,
				Font = Gilt.Display,
				TextColor3 = Gilt.Ink,
				BackgroundColor3 = Gilt.Well,
				Size = UDim2.fromOffset(0, 32),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = i,
				ZIndex = 12,
			}, chips)
			UiKit.round(chip, 6)
			new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, chip)
			new("UIStroke", { Color = Gilt.Gold, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
		end
	end
	-- (where you are in the screens, and a bar for how long this one has)
	text(root, {
		Name = "Step",
		Text = string.format("%d / %d  ·  TAP TO SKIP", index, count),
		TextSize = 11,
		TextColor3 = Gilt.Dusk,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(240, 16),
		ZIndex = 11,
	})
	local track = new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -44),
		Size = UDim2.new(0.5, 0, 0, 3),
		BackgroundColor3 = Gilt.Bronze,
		ZIndex = 11,
	}, root)
	UiKit.round(track, 2)
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = if spec.Team then Gilt.Gold else ROT,
		ZIndex = 12,
	}, track)
	UiKit.round(fill, 2)

	-- In: the words rise a little and fade up.
	for _, label in { kicker, title, line } do
		label.TextTransparency = 1
		tween(label, 0.6, { TextTransparency = 0 })
	end
	column.Position = UDim2.fromScale(0.5, 0.56)
	tween(column, 0.7, { Position = UDim2.fromScale(0.5, 0.52) })
	TweenService:Create(fill, TweenInfo.new(FirstDungeonUI.SlideSeconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()

	local skipped = false
	root.Activated:Connect(function()
		skipped = true
	end)
	local ends = os.clock() + FirstDungeonUI.SlideSeconds
	while os.clock() < ends and not skipped do
		task.wait(0.05)
	end
	return root
end

local playing = false

function FirstDungeonUI.allowed(): boolean
	-- (Off for now, for everyone: Config.Features.FirstDungeon.)
	local Config = require(ReplicatedStorage.Shared.Config)
	return Config.Features ~= nil and Config.Features.FirstDungeon == true
end

function FirstDungeonUI.play(): string?
	if playing then
		return "Already on the way in."
	end
	playing = true
	FirstDungeonUI.start()
	local ok, message = pcall(function()
		-- (A new player's kaiju come first: the roll they're owed.)
		-- (one already up, from the lobby's own sequence: it finishes first)
		local KaijuRoll = require(script.Parent.KaijuRoll)
		while KaijuRoll.showing and KaijuRoll.showing() do
			task.wait(0.1)
		end
		local profile = GemClient.Profile
		if profile and Kaiju.rollsOwed(profile) > 0 then
			local rolled = false
			KaijuRoll.play(function()
				rolled = true
			end)
			while not rolled do
				task.wait(0.1)
			end
		end
		-- (Straight in: the game's own loading, the pod drop's. The kaiju and
		-- scout mission screens are kept for later: ShowSlides.)
		local screen, last = nil, nil
		if FirstDungeonUI.ShowSlides then
			screen = UiKit.gui("FirstDungeonIntro", 70)
			screen.IgnoreGuiInset = true
			for i, spec in FirstDungeonUI.Slides do
				local shown = slide(screen, spec, i, #FirstDungeonUI.Slides)
				if last then
					last:Destroy()
				end
				last = shown
			end
		end
		-- In: the server drops you in (its pod). (Out of the intro fights'
		-- queue and the Arena first: a dungeon won't take you from either.)
		FirstDungeonUI.free()
		local result = GemClient.request("FirstDungeon")
		if not result.Ok then
			-- (once more, in case the queue put you back meanwhile)
			FirstDungeonUI.free()
			result = GemClient.request("FirstDungeon")
		end
		if screen then
			screen:Destroy()
		end
		if not result.Ok then
			return result.Message or "Couldn't start the Rot Beachhead."
		end
		-- (In, then straight back out: the run closed itself. Say so.)
		local entered = os.clock()
		task.spawn(function()
			while os.clock() - entered < 10 do
				if player:GetAttribute("DungeonId") == nil then
					FirstDungeonUI.problem(
						"The Rot Beachhead closed as it opened. Open the server's output (F9, Server) and look for [Dungeon] lines."
					)
					return
				end
				task.wait(0.25)
			end
		end)
		return nil
	end)
	playing = false
	if not ok then
		FirstDungeonUI.problem(tostring(message))
		error(message, 0)
	end
	if message then
		FirstDungeonUI.problem(message)
	end
	return message
end

-- Out of the intro fights' queue and any Arena session (waits up to 3 s).
function FirstDungeonUI.free()
	if player:GetAttribute("DuelQueue") ~= nil then
		GemClient.request("DuelCancel")
	end
	local session = player:GetAttribute("CombatSession")
	if session ~= nil and session ~= "Raid" and player:GetAttribute("MatchId") == nil then
		GemClient.request("ArenaLeave")
	end
	local deadline = os.clock() + 3
	while os.clock() < deadline
		and (player:GetAttribute("DuelQueue") ~= nil or (player:GetAttribute("CombatSession") ~= nil and player:GetAttribute("MatchId") == nil))
	do
		task.wait(0.1)
	end
end

-- Why it didn't go in, on the screen (the DEV panel's closed by then).
local problemGui: ScreenGui? = nil
function FirstDungeonUI.problem(message: string)
	warn("[FirstDungeon] " .. message)
	if problemGui then
		problemGui:Destroy()
	end
	local screen = UiKit.gui("FirstDungeonProblem", 76)
	problemGui = screen
	local body = Gilt.frame(screen, 380)
	local kicker = Gilt.heading(body, "THE ROT BEACHHEAD", 1, true)
	kicker.TextColor3 = ROT
	local title = Gilt.words(body, "COULDN'T DROP IN", 24, Gilt.Red)
	title.Font = Gilt.Display
	title.LayoutOrder = 2
	local line = Gilt.words(body, message, 14, Gilt.Ink)
	line.Name = "Reason"
	line.TextWrapped, line.TextTruncate = true, Enum.TextTruncate.None
	line.Size, line.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	line.LayoutOrder = 3
	Gilt.button(body, "OK", true, 4, function()
		screen:Destroy()
	end, 40, 16)
end

-- Ways out: back to the intro fights (while rounds are left), the lobby ------------

local card: ScreenGui? = nil
local roundsLeft = 0 -- (intro rounds still to win: the server's, on the way in)

local function closeCard()
	if card then
		card:Destroy()
		card = nil
	end
end

-- After FINISH THE INTRO FIGHTS: once you're out of the dungeon, the next round.
local function nextRound()
	local deadline = os.clock() + 20
	while player:GetAttribute("CombatSession") ~= nil and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(1.5)
	GemClient.request("IntroRoundNext")
end

-- Out of the Rot Beachhead: "Intro" (then the next round) or "Lobby".
local leaving = false
function FirstDungeonUI.leave(where: string)
	if leaving then
		return
	end
	leaving = true
	closeCard()
	local result = GemClient.request("FirstDungeonQuit", where)
	leaving = false
	if result.Ok and result.To == "Intro" then
		task.spawn(nextRound)
	end
end

-- The card's buttons out, from `order` down.
local function exits(body: Frame, order: number, primaryIntro: boolean)
	if roundsLeft > 0 then
		local intro = Gilt.button(body, string.format("FINISH THE INTRO FIGHTS (%d LEFT)", roundsLeft), primaryIntro, order, function()
			FirstDungeonUI.leave("Intro")
		end, if primaryIntro then 46 else 40, if primaryIntro then 15 else 13)
		intro.Name = "Intro"
	end
	local lobby = Gilt.button(body, "GO TO LOBBY", false, order + 1, function()
		FirstDungeonUI.leave("Lobby")
	end, 40, 13)
	lobby.Name = "Lobby"
end

local function cardFrame(name: string, kickerText: string, titleText: string, titleColor: Color3, lineText: string): Frame
	closeCard()
	local screen = UiKit.gui(name, 75)
	card = screen
	new("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
	}, screen)
	local body = Gilt.frame(screen, 380)
	local kicker = Gilt.heading(body, kickerText, 1, true)
	kicker.TextColor3 = ROT
	local title = Gilt.words(body, titleText, 28, titleColor)
	title.Font = Gilt.Display
	title.LayoutOrder = 2
	local line = Gilt.words(body, lineText, 14, Gilt.Faded)
	line.TextWrapped, line.TextTruncate = true, Enum.TextTruncate.None
	line.Size, line.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	line.LayoutOrder = 3
	return body
end

-- LEAVE (the combat screen's own, top right: Client ArenaScene.leave), any
-- time in the dungeon: back to the intro fights or the lobby.
function FirstDungeonUI.showLeave()
	local body = cardFrame(
		"FirstDungeonLeaveCard",
		"THE ROT BEACHHEAD",
		"LEAVE THE DUNGEON?",
		Gilt.Ink,
		if roundsLeft > 0
			then "Your intro fights aren't finished: win them for more gear, then come back."
			else "You'll start the Rot Beachhead over next time."
	)
	exits(body, 4, true)
	local stay = Gilt.button(body, "STAY", false, 6, closeCard, 36, 12)
	stay.Name = "Stay"
end

-- The knock-down card: RECOVER, or out.
function FirstDungeonUI.showDown(event: { [string]: any })
	roundsLeft = tonumber(event.RoundsLeft) or roundsLeft
	local body = cardFrame(
		"FirstDungeonDown",
		if event.Room then tostring(event.Room) else "THE ROT BEACHHEAD",
		"KNOCKED DOWN",
		Gilt.Red,
		if event.Boss
			then string.format("%s put you down. Watch for its wind-up, then hit it while it recovers.", tostring(event.Boss))
			else "The rot-spawn got you. Stay by your kaiju: they heal you."
	)
	local screen = card
	local seconds = math.max(1, math.floor(tonumber(event.Seconds) or 30))
	local ends = os.clock() + seconds
	local recover = Gilt.button(body, "RECOVER", true, 4, function()
		closeCard()
		GemClient.request("FirstDungeonRecover")
	end, 46, 18)
	recover.Name = "Recover"
	exits(body, 5, false)
	local timer = Gilt.words(body, "", 12, Gilt.Dusk)
	timer.Name = "Timer"
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.LayoutOrder = 8
	task.spawn(function()
		while card == screen do
			local left = math.max(0, math.ceil(ends - os.clock()))
			timer.Text = string.format("Recovering by yourself in %ds", left)
			if left <= 0 then
				-- (the server recovers you itself then; this just closes)
				closeCard()
				break
			end
			task.wait(0.25)
		end
	end)
end


-- The tracker, top right under the combat screen's LEAVE, while you're in
-- the Rot Beachhead: its three rooms (done, here, to come), what to do now
-- (from the server's DungeonPhase, DungeonFoesLeft / DungeonFoesTotal) and
-- the latest word (DungeonObjective) for a few seconds.
local hud: ScreenGui? = nil
local hudParts: any = nil
local DungeonRules = require(ReplicatedStorage.Shared.DungeonRules)

local function objectiveText(): string
	local phaseName = player:GetAttribute("DungeonPhase")
	local left = tonumber(player:GetAttribute("DungeonFoesLeft")) or 0
	local total = math.max(left, tonumber(player:GetAttribute("DungeonFoesTotal")) or 0)
	local boss = player:GetAttribute("DungeonBoss")
	if phaseName == "Move" then
		return "Through the gate: follow the beam ▸"
	elseif phaseName == "Loot" then
		return "Open your boss cache"
	elseif type(boss) == "string" then
		return if left > 1 then string.format("Defeat %s  ·  %d left", boss, left) else "Defeat " .. boss
	end
	return string.format("Defeat the rot-spawn  ·  %d / %d", total - left, total)
end

local function drawHud()
	if not hud or not hudParts then
		return
	end
	local room = tonumber(player:GetAttribute("DungeonRoom")) or 1
	local phaseName = player:GetAttribute("DungeonPhase")
	for i, pip in hudParts.Pips do
		local done = i < room or (i == room and (phaseName == "Move" or phaseName == "Loot"))
		local here = i == room and not done
		pip.Bar.BackgroundColor3 = if done then ROT elseif here then Gilt.Gold else Gilt.Bronze
		pip.Name_.TextColor3 = if done then ROT elseif here then Gilt.Gold else Gilt.Dusk
	end
	hudParts.Goal.Text = objectiveText()
end

local wordShown = 0
local function sayWord()
	if not hudParts then
		return
	end
	local word = player:GetAttribute("DungeonObjective")
	wordShown += 1
	local mine = wordShown
	hudParts.Word.Text = if type(word) == "string" then word else ""
	hudParts.Word.TextTransparency = 0
	task.delay(6, function()
		if mine == wordShown and hudParts then
			tween(hudParts.Word, 0.6, { TextTransparency = 1 })
		end
	end)
end

local function placeHud()
	if not hud or not hudParts then
		return
	end
	local size = hud.AbsoluteSize
	local portrait = size.Y > size.X
	hudParts.Panel.Position = UDim2.new(1, -12, 0, if portrait then 124 else 62)
end

local function showHud(on: boolean)
	if not on then
		if hud then
			hud:Destroy()
			hud, hudParts = nil, nil
		end
		return
	end
	if hud then
		drawHud()
		return
	end
	local screen = UiKit.gui("FirstDungeonHud", 30)
	hud = screen
	local panel = new("Frame", {
		Name = "Tracker",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Gilt.Deep,
		BackgroundTransparency = 0.15,
	}, screen)
	UiKit.round(panel, 10)
	new("UIStroke", { Color = Gilt.Bronze, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 10),
	}, panel)
	UiKit.list(panel, 6)
	text(panel, {
		Name = "Title",
		Text = "THE ROT BEACHHEAD",
		TextSize = 11,
		TextColor3 = ROT,
		Font = Gilt.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 1,
	})
	local row = new("Frame", { Name = "Rooms", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2 }, panel)
	local pips = {}
	local names = DungeonRules.First.Short
	for i, name in names do
		local cell = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new((i - 1) / #names, if i > 1 then 3 else 0, 0, 0),
			Size = UDim2.new(1 / #names, -3, 1, 0),
		}, row)
		local bar = new("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Gilt.Bronze }, cell)
		UiKit.round(bar, 2)
		local label = text(cell, {
			Name = "Name",
			Text = name,
			TextSize = 10,
			TextColor3 = Gilt.Dusk,
			Font = Gilt.Display,
			Position = UDim2.fromOffset(0, 7),
			Size = UDim2.new(1, 0, 0, 14),
			TextWrapped = false,
		})
		pips[i] = { Bar = bar, Name_ = label }
	end
	local goal = text(panel, {
		Name = "Goal",
		Text = "",
		TextSize = 14,
		TextColor3 = Gilt.Ink,
		Font = Gilt.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	})
	local word = text(panel, {
		Name = "Word",
		Text = "",
		TextSize = 11,
		TextColor3 = Gilt.Faded,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
	})
	hudParts = { Panel = panel, Pips = pips, Goal = goal, Word = word }
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeHud)
	placeHud()
	drawHud()
	sayWord()
end

-- The victory card ----------------------------------------------------------------------

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- After the boss: once its cache is opened (or soon anyway), how it went
-- and the way on (the intro fights while rounds are left, or the lobby).
-- Out by itself as its time's up (the server's WinSeconds).
function FirstDungeonUI.showWon(event: { [string]: any })
	local ends = os.clock() + math.max(1, tonumber(event.Seconds) or 25)
	roundsLeft = tonumber(event.RoundsLeft) or roundsLeft
	-- (the boss cache's roll first: Client StreakRewards)
	local ok, StreakRewards = pcall(require, script.Parent.StreakRewards)
	local waitUntil = ends - 7
	task.wait(1.5)
	while ok and os.clock() < waitUntil and (StreakRewards.pending() or StreakRewards.isOpen()) do
		task.wait(0.25)
	end
	if player:GetAttribute("DungeonId") == nil then
		return
	end
	local body = cardFrame(
		"FirstDungeonWon",
		"THE ROT BEACHHEAD",
		"BEACHHEAD TAKEN",
		ROT,
		string.format("%s is down. That's one: there are more out there.", tostring(event.Boss or "The boss"))
	)
	local screen = card
	local stats = new("Frame", { Name = "Stats", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 4 }, body)
	local entries = {
		{ "TIME", clock(tonumber(event.Time) or 0) },
		{ "KNOCK-DOWNS", tostring(tonumber(event.Downs) or 0) },
		{ "COINS", "+" .. tostring(tonumber(event.Coins) or 0) },
	}
	for i, entry in entries do
		local cell = new("Frame", {
			Position = UDim2.new((i - 1) / 3, if i > 1 then 4 else 0, 0, 0),
			Size = UDim2.new(1 / 3, -4, 1, 0),
		}, stats)
		Gilt.well(cell)
		text(cell, { Text = entry[2], TextSize = 17, TextColor3 = Gilt.Ink, Font = Gilt.Display, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 20) })
		text(cell, { Text = entry[1], TextSize = 9, TextColor3 = Gilt.Dusk, Font = Gilt.Display, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 12) })
	end
	local function go(to: string)
		closeCard()
		local result = GemClient.request("FirstDungeonDone")
		if result.Ok and to == "Intro" then
			task.spawn(nextRound)
		end
	end
	if roundsLeft > 0 then
		local intro = Gilt.button(body, string.format("FINISH THE INTRO FIGHTS (%d LEFT)", roundsLeft), true, 5, function()
			go("Intro")
		end, 46, 15)
		intro.Name = "Intro"
		local lobby = Gilt.button(body, "BACK TO THE OUTPOST", false, 6, function()
			go("Lobby")
		end, 40, 13)
		lobby.Name = "Lobby"
	else
		local lobby = Gilt.button(body, "BACK TO THE OUTPOST", true, 5, function()
			go("Lobby")
		end, 46, 15)
		lobby.Name = "Lobby"
	end
	local timer = Gilt.words(body, "", 12, Gilt.Dusk)
	timer.Name = "Timer"
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.LayoutOrder = 8
	task.spawn(function()
		while card == screen do
			local left = math.max(0, math.ceil(ends - os.clock()))
			timer.Text = string.format("Heading out in %ds", left)
			if left <= 0 then
				closeCard()
				break
			end
			task.wait(0.25)
		end
	end)
end

local started = false
function FirstDungeonUI.start()
	if started then
		return
	end
	started = true
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Social").OnClientEvent:Connect(function(kind: string, event: any)
		if kind ~= "FirstDungeon" or type(event) ~= "table" then
			return
		end
		if event.Phase == "In" then
			roundsLeft = tonumber(event.RoundsLeft) or 0
			showHud(true)
		elseif event.Phase == "Down" then
			FirstDungeonUI.showDown(event)
		elseif event.Phase == "Won" then
			task.spawn(FirstDungeonUI.showWon, event)
		end
	end)
	-- The tracker follows the room's state.
	for _, name in { "DungeonRoom", "DungeonPhase", "DungeonFoesLeft", "DungeonFoesTotal", "DungeonBoss" } do
		player:GetAttributeChangedSignal(name):Connect(drawHud)
	end
	player:GetAttributeChangedSignal("DungeonObjective"):Connect(sayWord)
	player:GetAttributeChangedSignal("DungeonKaiju"):Connect(function()
		showHud(player:GetAttribute("DungeonKaiju") == true and player:GetAttribute("DungeonId") ~= nil)
	end)
	-- (out of the dungeon: its cards go with it)
	player:GetAttributeChangedSignal("DungeonId"):Connect(function()
		if player:GetAttribute("DungeonId") == nil then
			closeCard()
			showHud(false)
		end
	end)
end

return FirstDungeonUI
