--[[
	The Rift on your screen (Server.RiftServer runs it; Shared.RiftRun has
	the rules).

	  The gate     a Rift Gate's prompt (PromptKind Rift) opens its card:
	               what's through it, who's going (your party's trip, if
	               one of them is on the way), and going alone, a warning
	               sign: GOING ALONE IS VERY DIFFICULT, with INVITE A FRIEND
	               right beside it. ENTER (ENTER ALONE) goes in.
	  Crossing     the screen goes dark while you go through ("THE RIFT",
	               and the same warning when you're alone), then clears on
	               the other side.
	  In there     everything lit like the place (RiftClient.hellLighting:
	               a burning dusk, no stars, the sky red at its edges and
	               violet overhead; Scenes.outpostLighting puts the
	               Outpost's back), and a strip along the top: which cave
	               (its pips: the four and the throne), how many foes are
	               left, the boss, the gems you've found and how many of
	               you are in. Your combat kit is out the whole way (the
	               server's). Through a way home (PromptKind RiftExit) and
	               you're out.
	  Down         knocked out at the boss: YOU'RE DOWN, the boss still
	               standing, and what now: RESTORE (its cost: your health and
	               your kaiju's), INVITE A FRIEND or BACK TO BASE (keeping
	               what you found), the time left to choose running down.

	  RiftClient.start()            watch your Rift attributes (once)
	  RiftClient.openGate(vein)     the gate's card
	  RiftClient.leave()            through a way home
	  RiftClient.stripText(state) -> (string, string)   the strip's two lines (pure)
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RiftRun = require(ReplicatedStorage.Shared.RiftRun)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local MobileLayout = require(script.Parent.MobileLayout)

local RiftClient = {}

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new
local EMBER = Color3.fromRGB(255, 120, 48)
local HELL = Color3.fromRGB(214, 52, 30)
local WARN = Color3.fromRGB(255, 186, 72)
local BOLD, BODY = IronUi.Bold, IronUi.Body

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function narrow(gui: ScreenGui): boolean
	return gui.AbsoluteSize.X < 700 or gui.AbsoluteSize.Y < 480
end

local function text(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or BODY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, size + 4),
	}, parent)
end

local function button(
	parent: Instance,
	label: string,
	color: Color3,
	order: number,
	onClick: () -> (),
	tall: number?
): TextButton
	local b, face =
		IronUi.chunk(parent, { Color = color, Size = UDim2.new(1, 0, 0, tall or 44), Radius = 8, Stripes = "None" })
	b.LayoutOrder = order
	IronUi.label(b, face, label, 15, BOLD)
	b.Activated:Connect(onClick)
	return b
end

-- The colours of the place ------------------------------------------------------------------------------------

-- A burning dusk: the sun just down (no disc, no stars), the air glowing
-- orange-red at the horizon and bruised violet overhead, round the scar torn
-- across the sky (World.RiftWorld's); the braziers' fire blooming.
RiftClient.Hell = {
	Clock = 17.8,
	Ambient = Color3.fromRGB(96, 42, 40),
	Outdoor = Color3.fromRGB(140, 64, 52),
	Brightness = 1.6,
	Exposure = 0.1,
	Haze = { Density = 0.36, Offset = 0.15, Haze = 2.8, Glare = 0.5 },
	HazeColor = Color3.fromRGB(215, 84, 52),
	HazeDecay = Color3.fromRGB(92, 24, 64),
	Grade = { Contrast = 0.14, Saturation = 0.12, Tint = Color3.fromRGB(255, 222, 205) },
	Bloom = { Intensity = 0.6, Size = 28, Threshold = 1.2 },
	Stars = 0,
}

local function effect(kind: string): any
	local found = Lighting:FindFirstChildOfClass(kind)
	if not found then
		found = Instance.new(kind)
		found.Parent = Lighting
	end
	return found
end

function RiftClient.hellLighting()
	local hell = RiftClient.Hell
	Lighting.ClockTime = hell.Clock
	Lighting.Brightness = hell.Brightness
	Lighting.Ambient = hell.Ambient
	Lighting.OutdoorAmbient = hell.Outdoor
	Lighting.ExposureCompensation = hell.Exposure
	local haze = effect("Atmosphere")
	for key, value in hell.Haze do
		haze[key] = value
	end
	haze.Color, haze.Decay = hell.HazeColor, hell.HazeDecay
	local grade = effect("ColorCorrectionEffect")
	grade.Contrast, grade.Saturation, grade.TintColor = hell.Grade.Contrast, hell.Grade.Saturation, hell.Grade.Tint
	local bloom = effect("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = hell.Bloom.Intensity, hell.Bloom.Size, hell.Bloom.Threshold
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.StarCount = hell.Stars
		sky.CelestialBodiesShown = false
	end
end

local function outpostLighting()
	local ok, Scenes = pcall(require, script.Parent.Scenes)
	if ok and Scenes then
		Scenes.outpostLighting()
	end
end

-- Screens --------------------------------------------------------------------------------------------------

local gui: ScreenGui? = nil
local cover: ScreenGui? = nil
local strip: Frame? = nil
local gateCard: Frame? = nil
local downCard: Frame? = nil

local function screen(): ScreenGui
	if not gui then
		gui = UiKit.gui("Rift", 30)
	end
	return gui :: ScreenGui
end

local function close(card: Frame?)
	if card and card.Parent then
		card.Parent:Destroy()
	end
end

-- A card in the middle of the screen over a dimmed backdrop: its panel's
-- body (a list) to fill. `dismiss` closes it from the backdrop.
local function modal(name: string, width: number, accent: Color3, dismiss: boolean, compact: boolean?): (Frame, Frame)
	local holder = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen())
	local backdrop = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	}, holder)
	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = P.Frame,
	}, holder)
	UiKit.round(panel, 12)
	new("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.1 }, panel)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(accent:Lerp(P.Frame, 0.78), P.Frame),
	}, panel)
	UiKit.pad(panel, if compact then 10 else 14)
	UiKit.list(panel, if compact then 5 else 8)
	if dismiss then
		backdrop.Activated:Connect(function()
			holder:Destroy()
		end)
	end
	return panel, holder
end

-- The warning sign and its words (going in alone).
local function warning(parent: Instance, order: number, compact: boolean?)
	local box = new("Frame", {
		Name = "Warning",
		BackgroundColor3 = Color3.fromRGB(64, 22, 14),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, parent)
	UiKit.round(box, 8)
	new("UIStroke", { Color = WARN, Thickness = 1.5 }, box)
	local sign = if compact then 26 else 34
	new("UIPadding", {
		PaddingTop = UDim.new(0, if compact then 6 else 10),
		PaddingBottom = UDim.new(0, if compact then 6 else 10),
		PaddingLeft = UDim.new(0, sign + 20),
		PaddingRight = UDim.new(0, 10),
	}, box)
	local mark = IronUi.emblem(box, "Warning", WARN, sign)
	mark.Position = UDim2.new(0, -sign - 10, 0.5, -sign / 2)
	UiKit.list(box, 2)
	local head = text(box, "GOING ALONE IS VERY DIFFICULT", if compact then 13 else 15, WARN, BOLD)
	head.LayoutOrder = 1
	local why = text(
		box,
		"Invite a friend, or bring your party: up to 4 can go in together.",
		if compact then 11 else 12,
		P.Text
	)
	why.LayoutOrder = 2
	return box
end

-- Crossing: dark for a moment while you go through.
local function crossing(alone: boolean): () -> ()
	if cover then
		cover:Destroy()
	end
	local layer = UiKit.gui("RiftCrossing", 40)
	layer.IgnoreGuiInset = true
	cover = layer
	local shade = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 2, 2),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, layer)
	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.8, 0, 0, 44),
		Text = "THE RIFT",
		TextSize = 38,
		Font = IronUi.Heading,
		TextColor3 = EMBER,
		TextTransparency = 1,
	}, shade)
	local sub = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.8, 0, 0, 20),
		Text = "Through the tear, into the critters' world.",
		TextSize = 15,
		Font = BODY,
		TextColor3 = P.Dim,
		TextTransparency = 1,
	}, shade)
	sub.Position = UDim2.new(0.5, 0, 0.42, 36)
	local alert = nil
	if alone then
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.42, 64),
			Size = UDim2.new(0, math.min(420, layer.AbsoluteSize.X - 40), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, shade)
		alert = warning(holder, 1)
		new("UIListLayout", {}, holder)
		alert.Visible = false
	end
	local fade = TweenInfo.new(0.25)
	TweenService:Create(shade, fade, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(title, fade, { TextTransparency = 0 }):Play()
	TweenService:Create(sub, fade, { TextTransparency = 0 }):Play()
	if alert then
		alert.Visible = true
	end
	return function()
		local out = TweenInfo.new(if alone then 2.2 else 1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(if alone then 1.6 else 0.5, function()
			TweenService:Create(shade, out, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(title, out, { TextTransparency = 1 }):Play()
			TweenService:Create(sub, out, { TextTransparency = 1 }):Play()
			if alert then
				alert.Visible = false
			end
			task.delay(out.Time, function()
				if cover == layer then
					cover = nil
				end
				layer:Destroy()
			end)
		end)
	end
end

local function invite()
	local ok, Referral = pcall(require, script.Parent.ReferralUI)
	if ok and Referral and Referral.invite then
		Referral.invite()
	end
end

-- The gate ----------------------------------------------------------------------------------------------------

-- What going through looks like from here: { Party (how many in it),
-- Joining (their trip's on the path), Solo }.
local function peek(): { [string]: any }
	local result = GemClient.request("RiftPeek")
	if type(result) ~= "table" or not result.Ok then
		return { Party = 1, Joining = false, Solo = true }
	end
	return result
end

function RiftClient.openGate(vein: any)
	if gateCard and gateCard.Parent or player:GetAttribute("RiftRun") then
		return
	end
	local info = peek()
	local alone = info.Solo == true
	local s = screen()
	local small = narrow(s)
	local panel = modal("RiftGate", math.min(440, s.AbsoluteSize.X - 32), EMBER, true, small)
	gateCard = panel
	local title = text(panel, "RIFT GATE", if small then 20 else 24, EMBER, IronUi.Heading)
	title.LayoutOrder = 1
	-- (A phone's screen is short: the essentials in a line.)
	local lines = if small
		then {
			string.format("%d caves of critters and fighters, then a boss. Fall and they rob you.", RiftRun.Rooms),
		}
		else {
			"Through the tear: the critters' own world, caves under a burning sky.",
			string.format(
				"%d caves of brainrot critters and fighters, then one of the big ones on its throne.",
				RiftRun.Rooms
			),
			"Go in with your combat kit and your kaiju. Clear a cave and you each find a gem.",
			"Knocked out on the way, the critters rob you of what you found in there.",
		}
	for i, line in lines do
		local l = text(panel, line, if i == 1 and not small then 13 else 12, if i == 1 then P.Text else P.Dim)
		l.LayoutOrder = 1 + i
	end
	if info.Joining then
		local l = text(panel, "Your party's on the path in there: you'll join them.", 13, P.Good, BOLD)
		l.LayoutOrder = 7
	elseif (info.Party or 1) > 1 then
		local l = text(
			panel,
			string.format("Your party: %d. They can follow you through any gate.", info.Party),
			13,
			P.Teal,
			BOLD
		)
		l.LayoutOrder = 7
	end
	if alone then
		warning(panel, 8, small)
	end
	local tall = if small then 38 else 44
	local row = new("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tall),
		LayoutOrder = 9,
	}, panel)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, tall),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	button(row, "INVITE A FRIEND", P.Teal, 1, invite)
	local go = button(row, if alone then "ENTER ALONE" else "ENTER", HELL, 2, function() end)
	local cancel = new("TextButton", {
		Text = "Not now",
		TextSize = 13,
		Font = BOLD,
		TextColor3 = P.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 18 else 22),
		LayoutOrder = 10,
	}, panel)
	cancel.Activated:Connect(function()
		close(gateCard)
	end)
	local busy = false
	go.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local clear = crossing(alone)
		task.wait(0.25)
		local result = GemClient.request("RiftEnter", vein)
		if result.Ok then
			close(gateCard)
		else
			UiKit.toast(result.Message or "The gate won't open.", P.Bad)
			busy = false
		end
		clear()
	end)
end

function RiftClient.leave()
	task.spawn(function()
		local result = GemClient.request("RiftLeave")
		if not result.Ok and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Bad)
		end
	end)
end

-- The strip ---------------------------------------------------------------------------------------------------

-- Its two lines from the Rift attributes: { Room, Left, Boss, Found,
-- Runners, Won, ExitIn (seconds; nil while the boss's loot is still up) }.
function RiftClient.stripText(state): (string, string)
	local where
	if state.Won and state.ExitIn == nil then
		where = "BOSS DOWN  ·  CLAIM, ROLL OR PASS"
	elseif state.Won then
		where = string.format("BOSS DOWN  ·  HOME IN %d:%02d", state.ExitIn // 60, state.ExitIn % 60)
	elseif (state.Room or 1) > RiftRun.Rooms then
		where = string.format("THRONE CAVE  ·  %s", string.upper(state.Boss or "?"))
	elseif (state.Left or 0) > 0 then
		where = string.format(
			"CAVE %d OF %d  ·  %d FOE%s LEFT",
			state.Room,
			RiftRun.Rooms,
			state.Left,
			if state.Left == 1 then "" else "S"
		)
	else
		where = string.format("CAVE %d OF %d", state.Room or 1, RiftRun.Rooms)
	end
	local who = if (state.Runners or 1) <= 1 then "ALONE" else string.format("%d IN", state.Runners)
	return where, string.format("FOUND %d  ·  %s", state.Found or 0, who)
end

local function stateOf()
	local exit = player:GetAttribute("RiftExitAt")
	return {
		Room = player:GetAttribute("RiftRoom") or 1,
		Left = player:GetAttribute("RiftLeft") or 0,
		Boss = player:GetAttribute("RiftBoss"),
		Found = player:GetAttribute("RiftFound") or 0,
		Runners = player:GetAttribute("RiftRunners") or 1,
		Won = player:GetAttribute("RiftWon") == true,
		ExitIn = if type(exit) == "number" then math.max(0, math.ceil(exit - serverNow())) else nil,
	}
end

local pips: { Frame } = {}
local whereLabel: TextLabel? = nil
local tallyLabel: TextLabel? = nil

local function buildStrip()
	local s = screen()
	local small = narrow(s)
	local bar = new("Frame", {
		Name = "RiftStrip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if small then 4 else 8),
		Size = UDim2.fromOffset(if small then 300 else 430, if small then 44 else 50),
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.12,
	}, s)
	UiKit.round(bar, 10)
	new("UIStroke", { Color = EMBER, Thickness = 1.2, Transparency = 0.25 }, bar)
	local tag = text(bar, "THE RIFT", if small then 10 else 11, EMBER, BOLD)
	tag.AutomaticSize = Enum.AutomaticSize.None
	tag.Position, tag.Size = UDim2.fromOffset(12, 5), UDim2.fromOffset(80, 14)
	-- The caves as pips, the throne's a bigger one: lit up to where you are.
	table.clear(pips)
	for i = 1, RiftRun.Rooms + 1 do
		local throne = i > RiftRun.Rooms
		local size = if throne then 10 else 7
		local pip = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, (if small then 92 else 104) + (i - 1) * 15, 0, 12),
			Size = UDim2.fromOffset(size, size),
			Rotation = 45,
			BackgroundColor3 = P.Slot,
		}, bar)
		table.insert(pips, pip)
	end
	local where = text(bar, "", if small then 12 else 14, P.Text, BOLD)
	where.AutomaticSize, where.TextWrapped = Enum.AutomaticSize.None, false
	where.TextTruncate = Enum.TextTruncate.AtEnd
	where.Position, where.Size = UDim2.fromOffset(12, if small then 21 else 24), UDim2.new(1, -24, 0, 18)
	local tally = text(bar, "", if small then 10 else 11, P.Gold, BOLD)
	tally.AutomaticSize = Enum.AutomaticSize.None
	tally.TextXAlignment = Enum.TextXAlignment.Right
	tally.AnchorPoint = Vector2.new(1, 0)
	tally.Position, tally.Size = UDim2.new(1, -12, 0, 5), UDim2.fromOffset(150, 14)
	whereLabel, tallyLabel = where, tally
	strip = bar
end

local function refreshStrip()
	if not strip then
		return
	end
	local state = stateOf()
	local where, tally = RiftClient.stripText(state);
	(whereLabel :: TextLabel).Text = where;
	(tallyLabel :: TextLabel).Text = tally
	for i, pip in pips do
		local done = i < state.Room or state.Won
		local here = i == state.Room and not state.Won
		pip.BackgroundColor3 = if done then EMBER elseif here then WARN else P.Slot
		pip.BackgroundTransparency = if here or done then 0 else 0.2
	end
end

-- Down at the boss --------------------------------------------------------------------------------------------

local downClock: TextLabel? = nil
local downFill: Frame? = nil
local restoreButton: TextButton? = nil

local function choose(choice: string)
	task.spawn(function()
		local result = GemClient.request("RiftChoice", choice)
		if not result.Ok and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Bad)
		end
	end)
end

local function showDown()
	if downCard and downCard.Parent then
		return
	end
	local s = screen()
	local small = narrow(s)
	local panel = modal("RiftDown", math.min(400, s.AbsoluteSize.X - 32), HELL, false, small)
	downCard = panel
	local title = text(panel, "YOU'RE DOWN", if small then 20 else 24, P.Bad, IronUi.Heading)
	title.LayoutOrder = 1
	local boss = player:GetAttribute("RiftBoss") or "The boss"
	local line = text(panel, string.format("%s is still standing. Your kaiju fight on without you.", boss), 13, P.Text)
	line.LayoutOrder = 2
	-- The time left to choose, running down.
	local track = new("Frame", {
		BackgroundColor3 = P.Slot,
		Size = UDim2.new(1, 0, 0, 6),
		LayoutOrder = 3,
	}, panel)
	UiKit.round(track, 3)
	local fill = new("Frame", { BackgroundColor3 = HELL, Size = UDim2.fromScale(1, 1) }, track)
	UiKit.round(fill, 3)
	local clock = text(panel, "", 12, P.Dim, BOLD)
	clock.LayoutOrder = 4
	downClock, downFill = clock, fill
	local cost = player:GetAttribute("RiftRestore") or RiftRun.Restore.Coins
	local tall = if small then 38 else 44
	restoreButton = button(panel, string.format("RESTORE  ·  %d COINS", cost), P.Gold, 5, function()
		choose("Restore")
	end, tall)
	if not small then
		local note = text(panel, "You and your kaiju, back to full health, right here.", 11, P.Dim)
		note.LayoutOrder = 6
	end
	-- (Side by side on a phone: its screen is short.)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, tall), LayoutOrder = 7 }, panel)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, tall),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	button(row, "INVITE A FRIEND", P.Teal, 1, invite, tall)
	button(row, "BACK TO BASE", P.Edge, 2, function()
		choose("Home")
	end, tall)
	local keep = text(panel, "You and your kaiju back to full health, or home with the gems you found.", 11, P.Dim)
	keep.LayoutOrder = 9
end

local function refreshDown()
	local deadline = player:GetAttribute("RiftFallen")
	if type(deadline) ~= "number" then
		close(downCard)
		downCard = nil
		return
	end
	showDown()
	local left = math.max(0, deadline - serverNow())
	if downClock then
		downClock.Text =
			string.format("Back to base by itself in %d:%02d", math.floor(left) // 60, math.floor(left) % 60)
	end
	if downFill then
		downFill.Size = UDim2.fromScale(math.clamp(left / RiftRun.Fallen, 0, 1), 1)
	end
	if restoreButton then
		local cost = player:GetAttribute("RiftRestore") or RiftRun.Restore.Coins
		restoreButton.Text = string.format("RESTORE  ·  %d COINS", cost)
	end
end

-- Watching your attributes ------------------------------------------------------------------------------------

local inside = false
local ticking = false

local function tick()
	if ticking then
		return
	end
	ticking = true
	task.spawn(function()
		while inside do
			refreshStrip()
			refreshDown()
			task.wait(0.25)
		end
		ticking = false
	end)
end

local function changed()
	local now = player:GetAttribute("RiftRun") ~= nil
	if now and not inside then
		inside = true
		close(gateCard)
		RiftClient.hellLighting()
		buildStrip()
		MobileLayout.claimTop("Rift", true)
		tick()
	elseif not now and inside then
		inside = false
		if strip then
			strip:Destroy()
			strip = nil
		end
		close(downCard)
		downCard = nil
		MobileLayout.claimTop("Rift", false)
		outpostLighting()
	end
	if inside then
		refreshStrip()
		refreshDown()
	end
end

local started = false
function RiftClient.start()
	if started then
		return
	end
	started = true
	for _, key in
		{
			"RiftRun",
			"RiftRoom",
			"RiftLeft",
			"RiftBoss",
			"RiftFound",
			"RiftRunners",
			"RiftWon",
			"RiftFallen",
			"RiftRestore",
		}
	do
		player:GetAttributeChangedSignal(key):Connect(changed)
	end
	changed()
end

return RiftClient
