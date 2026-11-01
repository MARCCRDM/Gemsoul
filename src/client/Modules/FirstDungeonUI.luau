--[[
	The new player's first dungeon, the Rot Beachhead (Shared.DungeonRules
	.First, Server Dungeons' "First" mode): for now from the DEV panel's
	FIRST DUNGEON, as it'll play after the intro fights.

	  FirstDungeonUI.play() -> message?   the kaiju roll if one's owed, then
	                        the loading screens (YOUR KAIJU, then the SCOUT
	                        MISSION), then into the dungeon (the pod drop is
	                        the server's). A tap skips a screen. Returns the
	                        server's message when it couldn't start.
	  FirstDungeonUI.start()   listens for the knock-down (Remotes.Social
	                        "FirstDungeon", Phase "Down"): a card with RECOVER
	                        (back at the start of the room, its fighters at
	                        full too) and, while intro rounds are left to win,
	                        FINISH THE INTRO FIGHTS (out, and into the next
	                        round). RECOVER by itself when its time's up.
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

function FirstDungeonUI.play(): string?
	if playing then
		return "Already on the way in."
	end
	playing = true
	FirstDungeonUI.start()
	local ok, message = pcall(function()
		-- (A new player's kaiju come first: the roll they're owed.)
		local profile = GemClient.Profile
		if profile and Kaiju.rollsOwed(profile) > 0 then
			local rolled = false
			require(script.Parent.KaijuRoll).play(function()
				rolled = true
			end)
			while not rolled do
				task.wait(0.1)
			end
		end
		local screen = UiKit.gui("FirstDungeonIntro", 70)
		screen.IgnoreGuiInset = true
		local last
		for i, spec in FirstDungeonUI.Slides do
			local shown = slide(screen, spec, i, #FirstDungeonUI.Slides)
			if last then
				last:Destroy()
			end
			last = shown
		end
		-- In: the server drops you in (its pod); the last screen fades as it does.
		local result = GemClient.request("DungeonTest", "First")
		if last then
			local fade = new("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 30,
			}, last)
			tween(fade, 0.35, { BackgroundTransparency = 0 }).Completed:Wait()
		end
		screen:Destroy()
		if not result.Ok then
			return result.Message or "Couldn't start the Rot Beachhead."
		end
		return nil
	end)
	playing = false
	if not ok then
		error(message, 0)
	end
	return message
end

-- The knock-down card ----------------------------------------------------------------

local card: ScreenGui? = nil

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

function FirstDungeonUI.showDown(event: { [string]: any })
	closeCard()
	local screen = UiKit.gui("FirstDungeonDown", 75)
	card = screen
	new("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
	}, screen)
	local body = Gilt.frame(screen, 380)
	local kicker = Gilt.heading(body, if event.Room then tostring(event.Room) else "THE ROT BEACHHEAD", 1, true)
	kicker.TextColor3 = ROT
	local title = Gilt.words(body, "KNOCKED DOWN", 30, Gilt.Red)
	title.Font = Gilt.Display
	title.LayoutOrder = 2
	local line = Gilt.words(
		body,
		if event.Boss
			then string.format("%s put you down. Watch for its wind-up, then hit it while it recovers.", tostring(event.Boss))
			else "The rot-spawn got you. Stay by your kaiju: they heal you.",
		14,
		Gilt.Faded
	)
	line.TextWrapped, line.TextTruncate = true, Enum.TextTruncate.None
	line.Size, line.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	line.LayoutOrder = 3
	local seconds = math.max(1, math.floor(tonumber(event.Seconds) or 30))
	local ends = os.clock() + seconds
	local sent = false
	local recover = Gilt.button(body, "RECOVER", true, 4, function()
		if sent then
			return
		end
		sent = true
		closeCard()
		GemClient.request("FirstDungeonRecover")
	end, 46, 18)
	recover.Name = "Recover"
	local roundsLeft = tonumber(event.RoundsLeft) or 0
	if roundsLeft > 0 then
		local quit = Gilt.button(
			body,
			string.format("FINISH THE INTRO FIGHTS (%d LEFT)", roundsLeft),
			false,
			5,
			function()
				if sent then
					return
				end
				sent = true
				closeCard()
				local result = GemClient.request("FirstDungeonQuit")
				if result.Ok then
					task.spawn(nextRound)
				end
			end,
			40,
			13
		)
		quit.Name = "Quit"
	end
	local timer = Gilt.words(body, "", 12, Gilt.Dusk)
	timer.Name = "Timer"
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.LayoutOrder = 6
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
		if event.Phase == "Down" then
			FirstDungeonUI.showDown(event)
		end
	end)
	-- (out of the dungeon: the card goes with it)
	player:GetAttributeChangedSignal("DungeonId"):Connect(function()
		if player:GetAttribute("DungeonId") == nil then
			closeCard()
		end
	end)
end

return FirstDungeonUI
