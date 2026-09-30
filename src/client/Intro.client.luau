--[[
	The new-player intro: two screens.
	  1  Welcome, and your first dig: a free wall in the Mine with your first
	     stone in it (the Mine window opens on top).
	  2  "You're a miner!": your first stone and three free starter gems,
	     then into the dashboard.
	You play as a Warrior (Config.OnlyClass); the server sets it up.
	Leaving part-way picks up where you left off.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local MineUI = require(script.Parent.Modules.MineUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors
local HEADING, CHUNKY = IronUi.Heading, IronUi.Chunky
local LIGHT = Color3.fromRGB(214, 208, 196)
local INK = P.Ink

-- Wait for the profile, and only run for players who haven't finished.
while not GemClient.Profile do
	GemClient.Changed:Wait()
end
if GemClient.Profile.Intro and GemClient.Profile.Intro.Done then
	return
end

local gui = new("ScreenGui", {
	Name = "Intro",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 15,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

-- Full-screen background, like the dashboard's.
local backdrop = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1) }, gui)
new("UIGradient", {
	Rotation = 110,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 38, 44)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 20, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 20, 26)),
	}),
}, backdrop)

-- One centred panel, scaled to fit the screen.
local W, H = 860, 600
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, gui)
UiKit.round(panel, 10)
new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, panel)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 33, 39), P.Frame) }, panel)
local panelScale = new("UIScale", {}, panel)
local function fit()
	local screen = gui.AbsoluteSize
	if screen.X > 0 then
		panelScale.Scale = math.min(1, (screen.X - 40) / W, (screen.Y - 40) / H)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()
local badge = IronUi.badge(panel, "💎", 84)
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.new(0.5, 0, 0, 0)
badge.ZIndex = 5
for _, child in badge:GetDescendants() do
	if child:IsA("GuiObject") then
		child.ZIndex = 6
	end
end
IronUi.animate(badge, function(t)
	badge.Rotation = math.sin(t * 1.2) * 3
end)

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(40, 70),
	Size = UDim2.new(1, -80, 1, -110),
}, panel)
local list = UiKit.list(body, 14)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center

local busy = false

local function clear()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local pop = badge:FindFirstChild("Pop") or new("UIScale", { Name = "Pop" }, badge)
	pop.Scale = 0.8
	TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function line(value: string, size: number, color: Color3, font: Enum.Font, order: number): TextLabel
	local label = text(body, value, size, color, font)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.LayoutOrder = order
	return label
end

local function firstStone()
	for _, gem in GemClient.Profile.Gems or {} do
		if gem.Source == "FirstStone" then
			return gem
		end
	end
	return nil
end

local CARD_W, CARD_H = 170, 236
local STAGE_W, STAGE_H = 146, 124
local MYSTERY = Color3.fromRGB(86, 84, 94)

local function sound(id: string, speed: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = 0.4
	s.Parent = gui
	pcall(function()
		s:Play()
	end)
	task.delay(2, function()
		s:Destroy()
	end)
end

-- Little stars that burst out of a card.
local function sparkle(parent: GuiObject, color: Color3, amount: number)
	for n = 1, amount do
		local star = new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.35),
			Size = UDim2.fromOffset(28, 28),
			Text = if n % 2 == 0 then "✦" else "✧",
			TextSize = math.random(18, 30),
			TextColor3 = if n % 3 == 0 then Color3.new(1, 1, 1) else color,
			Font = CHUNKY,
			ZIndex = 20,
		}, parent)
		local angle = math.random() * math.pi * 2
		local distance = math.random(80, 170)
		TweenService:Create(star, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.35, math.sin(angle) * distance),
			TextTransparency = 1,
			Rotation = 180,
		}):Play()
		task.delay(0.85, function()
			star:Destroy()
		end)
	end
end

type Card = {
	Frame: Frame,
	Stroke: UIStroke,
	Shade: UIGradient,
	Ribbon: TextLabel,
	Stage: Frame,
	Name: TextLabel,
	Info: TextLabel,
	Scale: UIScale,
}

-- An empty card: coloured edge, a ribbon, a window (the stage) for the gem,
-- and name and value lines.
local function cardFrame(parent: Instance, order: number): Card
	local c = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		LayoutOrder = order,
	}, parent)
	UiKit.round(c, 8)
	local stroke = new("UIStroke", { Color = MYSTERY, Thickness = 2 }, c)
	local shade = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(MYSTERY:Lerp(Color3.new(0, 0, 0), 0.35), MYSTERY:Lerp(Color3.new(0, 0, 0), 0.8)),
	}, c)
	local ribbon = text(c, "???", 14, Color3.new(1, 1, 1), CHUNKY)
	ribbon.AutomaticSize = Enum.AutomaticSize.None
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromScale(0.5, 0)
	ribbon.Size = UDim2.fromOffset(126, 28)
	ribbon.BackgroundTransparency = 0
	ribbon.BackgroundColor3 = MYSTERY
	ribbon.TextXAlignment = Enum.TextXAlignment.Center
	ribbon.TextYAlignment = Enum.TextYAlignment.Center
	ribbon.ZIndex = 8
	UiKit.round(ribbon, 4)
	-- The window the gem sits in (and the reel spins behind).
	local stage = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(STAGE_W, STAGE_H),
		ClipsDescendants = true,
	}, c)
	UiKit.round(stage, 6)
	new("UIStroke", { Color = INK, Thickness = 1 }, stage)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(70, 68, 78), Color3.fromRGB(16, 16, 20)),
	}, stage)
	local name = text(c, "", 16, Color3.new(1, 1, 1), HEADING)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Position = UDim2.fromOffset(6, 158)
	name.Size = UDim2.new(1, -12, 0, 38)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Center
	local info = text(c, "", 13, LIGHT, CHUNKY)
	info.AutomaticSize = Enum.AutomaticSize.None
	info.Position = UDim2.fromOffset(6, 202)
	info.Size = UDim2.new(1, -12, 0, 18)
	info.TextXAlignment = Enum.TextXAlignment.Center
	local scale = new("UIScale", {}, c)
	return {
		Frame = c,
		Stroke = stroke,
		Shade = shade,
		Ribbon = ribbon,
		Stage = stage,
		Name = name,
		Info = info,
		Scale = scale,
	}
end

-- Fills a card with its gem: rarity colours, the 3D stone, name and value.
local function showGem(card: Card, gem, caption: string?)
	local tier = GemConfig.TierColors[gem.Tier] or P.Dim
	card.Stroke.Color = tier
	card.Shade.Color = ColorSequence.new(tier:Lerp(Color3.new(0, 0, 0), 0.55), tier:Lerp(Color3.new(0, 0, 0), 0.88))
	card.Ribbon.BackgroundColor3 = tier
	card.Ribbon.Text = caption or string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier)
	for _, child in card.Stage:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	GemArt.backdrop(card.Stage)
	GemArt.viewport(card.Stage, gem, true)
	card.Name.Text = GemConfig.shade(gem).Name
	local state = if gem.Cut then "Cut " .. gem.Cut else "Rough"
	card.Info.Text = string.format("%s  •  💰 %d", state, GemConfig.value(gem))
end

-- A card that pops in already showing its gem.
local function gemCard(parent: Instance, gem, order: number, caption: string?): Card
	local card = cardFrame(parent, order)
	showGem(card, gem, caption)
	card.Scale.Scale = 0.3
	task.delay(0.12 * order, function()
		TweenService:Create(card.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
	return card
end

-- A lottery reel: a "?" card whose window spins a strip of 3D stones past a
-- gold payline. spin(gem, seconds, tease) sends the strip whizzing past,
-- ticking as each stone crosses the line, and lands it on `gem` with a
-- little overshoot and settle. A teased reel glows its gem's rarity colour
-- as it slows, so you know something good is coming.
local REEL_ITEMS = 12
local TICK = "rbxasset://sounds/clickfast.wav"
local TIER_RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4 }

-- A random stone for the strip (only its looks matter).
local reelSeed = 0
local function decoy()
	reelSeed += 1
	local element = GemConfig.Elements[math.random(1, #GemConfig.Elements)]
	local shade = GemConfig.Shades[element][math.random(1, #GemConfig.Shades[element])]
	return {
		Id = "reel-" .. reelSeed,
		Element = element,
		Tier = shade.Tier,
		Size = math.random(3, 8),
		Clarity = math.random(3, 8),
		Cut = math.random(4, 9),
	}
end

local function reelCard(parent: Instance, order: number)
	local card = cardFrame(parent, order)
	card.Name.Text = "?"
	card.Info.Text = "Spin to reveal"
	local strip = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(STAGE_W, STAGE_H * REEL_ITEMS),
	}, card.Stage)
	local names = {}
	local function item(k: number, gem)
		local slot = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, (k - 1) * STAGE_H),
			Size = UDim2.fromOffset(STAGE_W, STAGE_H),
		}, strip)
		GemArt.viewport(slot, gem, false)
		names[k] = GemConfig.shade(gem).Name
		return slot
	end
	for k = 1, REEL_ITEMS - 1 do
		item(k, decoy())
	end
	-- Depth: the window darkens towards its top and bottom edges.
	for _, edge in { 0, 1 } do
		local fade = new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			AnchorPoint = Vector2.new(0, edge),
			Position = UDim2.fromScale(0, edge),
			Size = UDim2.new(1, 0, 0.32, 0),
			ZIndex = 6,
		}, card.Stage)
		new("UIGradient", {
			Rotation = if edge == 0 then 90 else -90,
			Transparency = NumberSequence.new(0.2, 1),
		}, fade)
	end
	-- The payline: gold pointers either side of the window.
	local pointers = {}
	for _, side in { -1, 1 } do
		local pointer = new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * (STAGE_W / 2 + 6), 0, 24 + STAGE_H / 2),
			Size = UDim2.fromOffset(18, 24),
			Text = if side == -1 then "►" else "◄",
			TextSize = 18,
			TextColor3 = P.Gold,
			Font = IronUi.Bold,
			ZIndex = 9,
		}, card.Frame)
		table.insert(pointers, pointer)
	end
	-- A big "?" over the window until it spins.
	local mystery = text(card.Stage, "?", 70, Color3.new(1, 1, 1), HEADING)
	mystery.AutomaticSize = Enum.AutomaticSize.None
	mystery.Size = UDim2.fromScale(1, 1)
	mystery.TextXAlignment = Enum.TextXAlignment.Center
	mystery.TextYAlignment = Enum.TextYAlignment.Center
	mystery.ZIndex = 7
	strip.Visible = false
	IronUi.animate(mystery, function(t)
		mystery.Rotation = math.sin(t * 3 + order) * 6
	end)
	card.Scale.Scale = 0.3
	task.delay(0.12 * order, function()
		TweenService:Create(card.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)

	local function spin(gem, seconds: number, tease: boolean)
		-- The last slot on the strip is the real gem.
		item(REEL_ITEMS, gem)
		mystery:Destroy()
		strip.Visible = true
		card.Ribbon.Text = "SPINNING"
		local tier = GemConfig.TierColors[gem.Tier] or P.Gold
		local stop = -(REEL_ITEMS - 1) * STAGE_H
		local overshoot = 18
		TweenService:Create(strip, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(0, stop - overshoot),
		}):Play()
		-- Tick each time a stone crosses the payline; the pointers kick.
		local started = os.clock()
		local last = 1
		local teasing = false
		while os.clock() - started < seconds do
			local k = math.clamp(math.floor(-strip.Position.Y.Offset / STAGE_H + 0.5) + 1, 1, REEL_ITEMS)
			if k ~= last then
				last = k
				card.Name.Text = names[k] or "?"
				sound(TICK, 0.9 + k / REEL_ITEMS * 0.4)
				for _, pointer in pointers do
					pointer.TextSize = 24
					TweenService:Create(pointer, TweenInfo.new(0.12), { TextSize = 18 }):Play()
				end
			end
			if tease and not teasing and os.clock() - started > seconds * 0.55 then
				-- Slowing down... the card starts to glow.
				teasing = true
				card.Ribbon.Text = "..."
				TweenService
					:Create(
						card.Stroke,
						TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{
							Color = tier,
							Thickness = 5,
						}
					)
					:Play()
			end
			card.Frame.Rotation = math.sin(os.clock() * 40) * (1.2 * (1 - (os.clock() - started) / seconds))
			task.wait()
		end
		card.Frame.Rotation = 0
		-- Clunk: settle back onto the payline, flash, and show the real stone.
		TweenService:Create(strip, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(0, stop),
		}):Play()
		task.wait(0.22)
		local flash = new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 15,
		}, card.Frame)
		UiKit.round(flash, 18)
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		task.delay(0.5, function()
			flash:Destroy()
		end)
		TweenService:Create(card.Stroke, TweenInfo.new(0.2), { Thickness = 2 }):Play()
		showGem(card, gem)
		local rank = TIER_RANK[gem.Tier] or 1
		sparkle(card.Frame, tier, 6 + rank * 6)
		sound("rbxasset://sounds/electronicpingshort.wav", 0.9 + rank * 0.15)
		card.Scale.Scale = 1.15 + rank * 0.03
		TweenService:Create(card.Scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		if rank > 1 then
			local shout =
				text(card.Frame, string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier) .. "!", 26, tier, HEADING)
			shout.AutomaticSize = Enum.AutomaticSize.None
			shout.AnchorPoint = Vector2.new(0.5, 0.5)
			shout.Position = UDim2.fromScale(0.5, 0.3)
			shout.Size = UDim2.fromOffset(220, 32)
			shout.TextXAlignment = Enum.TextXAlignment.Center
			shout.ZIndex = 18
			TweenService:Create(shout, TweenInfo.new(1.2), {
				Position = UDim2.fromScale(0.5, -0.1),
				TextTransparency = 1,
			}):Play()
			local shoutStroke = shout:FindFirstChildOfClass("UIStroke")
			if shoutStroke then
				TweenService:Create(shoutStroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
			task.delay(1.3, function()
				shout:Destroy()
			end)
		end
	end
	return card, spin
end

-- Marquee bulbs along an edge of the reels, chasing while they spin.
type Marquee = { Bulbs: { Frame }, Color: Color3, Mode: string }
local function marquee(parent: Instance, order: number, width: number): Marquee
	local bar = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 10),
		LayoutOrder = order,
	}, parent)
	local row = UiKit.list(bar, 14, true)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local state: Marquee = { Bulbs = {}, Color = P.Gold, Mode = "Idle" }
	for i = 1, math.floor(width / 24) do
		local bulb = new("Frame", {
			BackgroundColor3 = P.Gold,
			Size = UDim2.fromOffset(10, 10),
			LayoutOrder = i,
		}, bar)
		UiKit.round(bulb, 5)
		table.insert(state.Bulbs, bulb)
	end
	IronUi.animate(bar, function(t)
		local speed = if state.Mode == "Spin" then 14 elseif state.Mode == "Win" then 6 else 2.5
		local step = math.floor(t * speed)
		for i, bulb in state.Bulbs do
			local lit = if state.Mode == "Win" then step % 2 == 0 else (i + step) % 3 == 0
			bulb.BackgroundColor3 = state.Color
			bulb.BackgroundTransparency = if lit then 0 else 0.75
		end
	end)
	return state
end

local showReady: () -> ()

-- Screen 1: welcome and the first dig.
local function showWelcome()
	clear()
	local title = line("GEMSOUL", 84, P.Gold, HEADING, 1)
	local titleStroke = title:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		titleStroke.Thickness = 2
	end
	line("Dig up gems. Cut them. Forge them into legendary gear.", 22, Color3.new(1, 1, 1), CHUNKY, 2)
	line(
		"Gems grow in the rock under the kingdom. Glinting rocks hide them:\nswing your pickaxe and break one out!",
		17,
		LIGHT,
		CHUNKY,
		3
	)
	local spacer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(10, 20), LayoutOrder = 4 }, body)
	spacer.Name = "Spacer"
	local dig
	dig = IronUi.gemButton(body, "⛏️  START DIGGING", Color3.fromRGB(255, 150, 30), function()
		if busy then
			return
		end
		busy = true
		gui.Enabled = false
		MineUI.tutorial()
		gui.Enabled = true
		-- If the dig couldn't start, a practice stone instead.
		if not firstStone() and not GemClient.Profile.Intro.FirstStone then
			GemClient.request("FirstStone")
		end
		busy = false
		if firstStone() then
			showReady()
		end
	end)
	dig.LayoutOrder = 5
	dig.Size = UDim2.fromOffset(0, 70)
	dig.TextSize = 30
	IronUi.animate(dig, function(t)
		dig.Rotation = math.sin(t * 6) * 2
	end)
end

-- Screen 2: your gems, then into the game.
function showReady()
	clear()
	line("YOU'RE A MINER!", 46, Color3.new(1, 1, 1), HEADING, 1)
	local sub = line("Your first stone! Now spin for 3 free cut gems.", 18, LIGHT, CHUNKY, 2)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, CARD_H + 16),
		LayoutOrder = 4,
	}, body)
	local rowList = UiKit.list(row, 16, true)
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local stone = firstStone()
	if stone then
		gemCard(row, stone, 1, "YOUR FIRST")
	end
	local function enter()
		gui:Destroy()
		UiKit.toast("Welcome to Gemsoul! Press M or click DIG to mine.", P.Gold)
	end
	local starters = {}
	for _, gem in GemClient.Profile.Gems or {} do
		if gem.Source == "StarterSpin" then
			table.insert(starters, gem)
		end
	end
	-- Already spun (came back part-way)? Show them; otherwise three reels.
	local claimed = #starters > 0 or GemClient.Profile.Intro.Done == true
	local spins = {}
	if claimed then
		sub.Text = "Your first stone, plus three cut gems to get you started."
		for i, gem in starters do
			gemCard(row, gem, i + 1)
		end
	else
		for i = 1, 3 do
			local _, spin = reelCard(row, i + 1)
			spins[i] = spin
		end
	end
	-- Chasing lights above and below the reels.
	local lights = if claimed then {} else { marquee(body, 3, 760), marquee(body, 5, 760) }
	local function lightsTo(mode: string, color: Color3?)
		for _, bar in lights do
			bar.Mode = mode
			bar.Color = color or P.Gold
		end
	end
	local button
	button = IronUi.gemButton(
		body,
		if claimed then "ENTER GEMSOUL  ►" else "SPIN THE REELS",
		if claimed then P.Emerald else Color3.fromRGB(255, 150, 30),
		function()
			if busy then
				return
			end
			if claimed then
				enter()
				return
			end
			busy = true
			button.Visible = false
			task.spawn(function()
				local result = GemClient.request("QuickStart")
				if not result.Ok then
					UiKit.toast(result.Message, P.Bad)
					button.Visible = true
					busy = false
					return
				end
				-- Each reel runs longer than the last, so they land one after
				-- another, and the rarest gem is saved for the last reel.
				local gems = table.clone(result.Gems or {})
				table.sort(gems, function(a, b)
					return (TIER_RANK[a.Tier] or 1) < (TIER_RANK[b.Tier] or 1)
				end)
				lightsTo("Spin")
				local done = 0
				for i, spin in spins do
					local gem = gems[i]
					if gem then
						local last = i == #spins
						local tease = last and (TIER_RANK[gem.Tier] or 1) > 1
						task.spawn(function()
							spin(gem, 1.8 + (i - 1) * 0.8 + (if tease then 1.2 else 0), tease)
							done += 1
						end)
					else
						done += 1
					end
				end
				while done < #spins do
					task.wait(0.1)
				end
				-- The lights flash in the best gem's colour, and the haul is totted up.
				local best = gems[#gems]
				lightsTo("Win", best and GemConfig.TierColors[best.Tier] or P.Gold)
				local total = 0
				for _, gem in gems do
					total += GemConfig.value(gem)
				end
				for n = 1, 20 do
					sub.Text = string.format("Your haul is worth  💰 %d", math.floor(total * n / 20))
					task.wait(0.03)
				end
				task.wait(0.6)
				claimed = true
				button.Text = "ENTER GEMSOUL  ►"
				button.Visible = true
				busy = false
			end)
		end
	)
	button.LayoutOrder = 6
	button.Size = UDim2.fromOffset(0, 64)
	button.TextSize = 26
	if not claimed then
		IronUi.animate(button, function(t)
			button.Rotation = if claimed then 0 else math.sin(t * 6) * 2
		end)
	end
end

if firstStone() then
	showReady()
else
	showWelcome()
end
