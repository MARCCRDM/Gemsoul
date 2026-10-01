--[[
	The new-player intro for Saga Miners:

	  1  The lore "video": a short cinematic. The Saga Miners' colony, the
	     pulsing Saga Stones, the rift, the brainrot entities. (Skippable.)
	  2  Aboard the colony ship: you wake up to alarms. A brainrot alligator
	     bomber is strafing the ship outside the window. The tutorial walks
	     you through the core mechanics, one station at a time:
	       suit up (Scrap Suit, Saga Pistol and Shield)   "SuitUp"
	       collect your Saga Stone ration (a slot spin)    "StarterSpin"
	       enchant your blaster with your best stone       "SocketGem"
	       drive off the bomber (shoot it)                 (client only)
	       teleport out                                    "QuickStart" (done)
	  3  You beam down to the moon base (the dashboard, with the base behind
	     it: see MenuCamera).

	The ship and the bomber are built on the client (Modules/Scenes). Your
	figure in the ship is a copy of your character, so it wears whatever the
	server has dressed it in. Leaving part-way picks up where you left off.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local Scenes = require(script.Parent.Modules.Scenes)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors
local HEADING, CHUNKY = IronUi.Heading, IronUi.Chunky
local LIGHT = Color3.fromRGB(200, 214, 230)
local INK = P.Ink
local SAGA = P.Gold
local HOLO = Color3.fromRGB(90, 210, 255)
local ALARM = Color3.fromRGB(255, 70, 60)

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

-- Everything is laid out on a 1280x720 canvas scaled to the screen.
local W, H = 1280, 720
local canvas = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
}, gui)
local canvasScale = new("UIScale", {}, canvas)
local function fit()
	local screen = gui.AbsoluteSize
	if screen.X > 0 then
		canvasScale.Scale = math.min(screen.X / W, screen.Y / H)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local function label(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local t = text(parent, value, size, color or Color3.new(1, 1, 1), font or CHUNKY)
	t.AutomaticSize = Enum.AutomaticSize.None
	return t
end

local function place(object: GuiObject, x: number, y: number, w: number, h: number)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
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
	local name = text(c, "", 17, Color3.new(1, 1, 1), CHUNKY)
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

-- 1  The lore "video" ------------------------------------------------------------------------

-- A field of drifting stars on a black frame.
local function starfield(parent: GuiObject, count: number, drift: number)
	local rng = Random.new(11)
	for _ = 1, count do
		local size = rng:NextInteger(1, 3)
		local star = new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = rng:NextNumber(0, 0.6),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber()),
			Size = UDim2.fromOffset(size, size),
		}, parent)
		local speed = rng:NextNumber(0.2, 1) * drift
		local x0 = star.Position.X.Scale
		IronUi.animate(star, function(t)
			star.Position = UDim2.fromScale((x0 - t * speed * 0.01) % 1, star.Position.Y.Scale)
		end)
	end
end

local function circle(parent: Instance, x: number, y: number, size: number, top: Color3, bottom: Color3): Frame
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, parent)
	UiKit.round(f, size / 2)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) }, f)
	return f
end

-- A soft round glow.
local function halo(parent: Instance, x: number, y: number, size: number, color: Color3): Frame
	local f = circle(parent, x, y, size, color, color)
	f:FindFirstChildOfClass("UIGradient"):Destroy()
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0.8
	return f
end

-- The shots of the cinematic. Each builds its picture on `stage`.
type Shot = { Caption: string, Seconds: number, Build: (Frame) -> () }
local SAGA_GEM = { Id = "saga-lore", Element = "Fire", Tier = "Common", Size = 9, Clarity = 8, Cut = 9 }
local SHOTS: { Shot } = {
	{
		Caption = "Far beyond the known stars, the Saga Miners built a colony on a lonely moon.",
		Seconds = 5,
		Build = function(stage)
			starfield(stage, 90, 1)
			local moon = circle(stage, 640, 900, 1300, Color3.fromRGB(170, 172, 182), Color3.fromRGB(70, 72, 84))
			moon.ZIndex = 2
			for i, spec in { { 470, 58 }, { 560, 90 }, { 690, 70 }, { 790, 46 } } do
				local dome =
					circle(stage, spec[1], 268, spec[2], Color3.fromRGB(230, 236, 244), Color3.fromRGB(120, 140, 170))
				dome.ZIndex = 3
				local light = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(spec[1], 268 - spec[2] * 0.2),
					Size = UDim2.fromOffset(6, 6),
					BackgroundColor3 = if i % 2 == 0 then SAGA else HOLO,
					ZIndex = 4,
				}, stage)
				UiKit.round(light, 3)
			end
			circle(stage, 1030, 150, 150, Color3.fromRGB(90, 150, 230), Color3.fromRGB(30, 60, 120)).ZIndex = 1
		end,
	},
	{
		Caption = "They live on the ancient, pulsing Saga Stones: air, heat and light, all drawn from the stone.",
		Seconds = 5.5,
		Build = function(stage)
			starfield(stage, 60, 0.4)
			local glow = halo(stage, 640, 330, 420, SAGA)
			local holder = new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(640, 330),
				Size = UDim2.fromOffset(340, 340),
				ZIndex = 3,
			}, stage)
			pcall(GemArt.viewport, holder, SAGA_GEM, true)
			local pulse = new("UIScale", {}, holder)
			IronUi.animate(holder, function(t)
				local beat = (math.sin(t * 4) + 1) / 2
				pulse.Scale = 1 + beat * 0.06
				glow.BackgroundTransparency = 0.88 - beat * 0.12
				glow.Size = UDim2.fromOffset(420 + beat * 60, 420 + beat * 60)
			end)
		end,
	},
	{
		Caption = "Then, one night, reality tore open.",
		Seconds = 4,
		Build = function(stage)
			starfield(stage, 90, 2)
			-- A jagged crack of light across the sky.
			local points = { { 520, 60 }, { 600, 170 }, { 560, 260 }, { 690, 360 }, { 640, 470 }, { 760, 600 } }
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				local dx, dy = b[1] - a[1], b[2] - a[2]
				local length = math.sqrt(dx * dx + dy * dy)
				for _, spec in { { 22, Color3.fromRGB(200, 90, 255), 0.5 }, { 8, Color3.new(1, 1, 1), 0 } } do
					local seg = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset((a[1] + b[1]) / 2, (a[2] + b[2]) / 2),
						Size = UDim2.fromOffset(0, spec[1]),
						Rotation = math.deg(math.atan2(dy, dx)),
						BackgroundColor3 = spec[2],
						BackgroundTransparency = spec[3],
						BorderSizePixel = 0,
						ZIndex = 3,
					}, stage)
					task.delay(i * 0.18, function()
						TweenService:Create(seg, TweenInfo.new(0.2), { Size = UDim2.fromOffset(length + 8, spec[1]) })
							:Play()
					end)
				end
			end
			local flash = new("Frame", {
				BackgroundColor3 = Color3.fromRGB(230, 200, 255),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			}, stage)
			task.delay(1.2, function()
				flash.BackgroundTransparency = 0.1
				TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
			end)
		end,
	},
	{
		Caption = "Brainrot entities poured through the rift. They need the Saga Stones to exist.",
		Seconds = 5.5,
		Build = function(stage)
			starfield(stage, 90, 1.5)
			halo(stage, 640, 360, 700, Color3.fromRGB(170, 80, 255))
			-- The alligator bomber, flying through.
			local view = new("ViewportFrame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Ambient = Color3.fromRGB(150, 150, 170),
				LightColor = Color3.new(1, 1, 1),
				LightDirection = Vector3.new(-0.3, -1, -0.5),
				ZIndex = 3,
			}, stage)
			local camera = new("Camera", { FieldOfView = 40 }, view)
			view.CurrentCamera = camera
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 4, 40), Vector3.zero)
			local ok, croc = pcall(Scenes.croc)
			if ok and croc then
				croc.Parent = view
				local started = os.clock()
				IronUi.animate(view, function(t)
					local k = (t - started) / 5.5
					local at = CFrame.new(-40 + k * 80, math.sin(k * 6) * 2, -10 + k * 8)
						* CFrame.Angles(0, math.rad(-100), math.rad(math.sin(k * 5) * 12))
					croc:PivotTo(at)
					Scenes.spinPropellers(croc, t)
				end)
			end
		end,
	},
	{
		Caption = "Now the Saga Miners must defend their stones. Enchant your gear. Fight back. Secure the future.",
		Seconds = 5.5,
		Build = function(stage)
			starfield(stage, 120, 0.6)
			halo(stage, 640, 300, 520, SAGA)
			local title = label(stage, "BRAINROT\nCRUSADERS", 64, SAGA, HEADING)
			title.TextXAlignment = Enum.TextXAlignment.Center
			title.TextYAlignment = Enum.TextYAlignment.Center
			place(title, 140, 170, 1000, 200)
			title.ZIndex = 4
			local scale = new("UIScale", { Scale = 1.3 }, title)
			TweenService:Create(scale, TweenInfo.new(1.2, Enum.EasingStyle.Quint), { Scale = 1 }):Play()
			local sub = label(stage, "THE SAGA MINERS", 20, HOLO, HEADING)
			sub.TextXAlignment = Enum.TextXAlignment.Center
			place(sub, 140, 380, 1000, 30)
			sub.ZIndex = 4
		end,
	},
}

local function playCinematic()
	-- Black behind the canvas (ZIndex below it), letterbox bars above it.
	local screen = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = -1,
	}, gui)
	local stageHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, canvas)
	-- Letterbox bars and the caption.
	for _, edge in { 0, 1 } do
		new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, edge),
			Position = UDim2.fromScale(0, edge),
			Size = UDim2.new(1, 0, 0, 60),
			ZIndex = 3,
		}, gui)
	end
	local caption = label(canvas, "", 24, Color3.new(1, 1, 1), CHUNKY)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextWrapped = true
	place(caption, 160, 560, 960, 80)
	caption.ZIndex = 21
	caption.BackgroundColor3 = Color3.new(0, 0, 0)
	caption.BackgroundTransparency = 0.4
	UiKit.round(caption, 8)
	local skipped = false
	local skip = IronUi.button(canvas, "SKIP  ►", false, function()
		skipped = true
	end)
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.fromOffset(W - 24, 126)
	skip.ZIndex = 22

	for _, shot in SHOTS do
		if skipped then
			break
		end
		local stage = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(W, H),
			ClipsDescendants = true,
		}, stageHolder)
		shot.Build(stage)
		-- A slow push in, like a camera move.
		local push = new("UIScale", { Scale = 1 }, stage)
		TweenService:Create(push, TweenInfo.new(shot.Seconds, Enum.EasingStyle.Linear), { Scale = 1.06 }):Play()
		-- Typewriter caption.
		local started = os.clock()
		while not skipped and os.clock() - started < shot.Seconds do
			local shown = math.min(#shot.Caption, math.floor((os.clock() - started) * 45))
			caption.Text = string.sub(shot.Caption, 1, shown)
			task.wait(0.03)
		end
		caption.Text = shot.Caption
		stage:Destroy()
	end
	stageHolder:Destroy()
	for _, child in gui:GetChildren() do
		if child:IsA("Frame") and child.ZIndex == 3 then
			child:Destroy()
		end
	end
	caption:Destroy()
	skip:Destroy()
	screen:Destroy()
end

-- 2  The ship --------------------------------------------------------------------------------

local SHIP_AT = CFrame.new(0, 900, 0)
local ship: Scenes.Ship
local croc: Model
local camera = workspace.CurrentCamera
local cameraTween: Tween? = nil
local attacking = true -- the bomber strafes the ship until you drive it off
local retreating = false

local function shake(amount: number)
	task.spawn(function()
		for i = 1, 8 do
			local fade = 1 - i / 8
			camera.CFrame = camera.CFrame
				* CFrame.new((math.random() - 0.5) * amount * fade, (math.random() - 0.5) * amount * fade, 0)
			task.wait(0.03)
		end
	end)
end

-- A short-lived glowing beam between two points.
local function beam(from: Vector3, to: Vector3, color: Color3, width: number)
	local length = (to - from).Magnitude
	local p = Scenes.part(
		workspace,
		CFrame.lookAt((from + to) / 2, to),
		Vector3.new(width, width, length),
		color,
		Enum.Material.Neon
	)
	p.CastShadow = false
	task.delay(0.12, function()
		p:Destroy()
	end)
end

-- A burst of light that swells and fades.
local function blast(at: Vector3, color: Color3, size: number)
	local p = Scenes.part(workspace, CFrame.new(at), Vector3.one * size * 0.3, color, Enum.Material.Neon, "Ball")
	p.CastShadow = false
	TweenService:Create(p, TweenInfo.new(0.4), { Size = Vector3.one * size, Transparency = 1 }):Play()
	task.delay(0.45, function()
		p:Destroy()
	end)
end

-- The camera glides to a shot.
local function shot(cframe: CFrame, seconds: number?)
	camera.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(seconds or 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = cframe }
	)
	cameraTween = tween
	tween:Play()
	task.wait(seconds or 1.2)
	if cameraTween == tween then
		cameraTween = nil
	end
end

-- Your figure in the ship: a copy of your character (with whatever gear the
-- server has put on it), standing at `spot`.
local hero: Model? = nil
local heroSpot = CFrame.identity
local function placeHero(spot: CFrame)
	heroSpot = spot
	local character = player.Character
	if not character then
		return
	end
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = false
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if hero then
		hero:Destroy()
	end
	hero = copy
	copy:PivotTo(spot * CFrame.new(0, 3, 0))
	copy.Parent = workspace
end

-- Where the pistol is (roughly): in front of the figure's right hand.
local function muzzle(): Vector3
	return (heroSpot * CFrame.new(1.4, 4.4, -2.2)).Position
end

-- Waits for the server to re-dress the character (new gear folder), then
-- copies it again.
local function refreshHero()
	local character = player.Character
	if character then
		local gear = character:FindFirstChild("GemsoulGear")
		local started = os.clock()
		while os.clock() - started < 3 do
			local now = character:FindFirstChild("GemsoulGear")
			if now and now ~= gear then
				break
			end
			task.wait(0.1)
		end
		task.wait(0.1)
	end
	placeHero(heroSpot)
end

-- The bomber's flight: loops past the window, strafing the hull. Once you
-- drive it off it peels away and is gone.
local crocAt = CFrame.identity
local lastShot = 0
local retreatStart = 0
local function flyCroc(t: number)
	if not croc or not croc.Parent then
		return
	end
	local outside = ship.Spots.Outside
	if retreating then
		local k = os.clock() - retreatStart
		crocAt = crocAt * CFrame.new(0, k * 0.05, -k * 2.2) * CFrame.Angles(0, 0, math.rad(6))
	else
		local a = t * 0.45
		local pos = (outside * CFrame.new(math.sin(a) * 38, math.sin(a * 2) * 5, math.cos(a) * 14)).Position
		local ahead = (
			outside * CFrame.new(math.sin(a + 0.1) * 38, math.sin((a + 0.1) * 2) * 5, math.cos(a + 0.1) * 14)
		).Position
		crocAt = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, math.rad(-math.cos(a) * 25))
	end
	croc:PivotTo(crocAt)
	Scenes.spinPropellers(croc, t)
	-- Strafing runs: red bolts at the hull, a boom, the room shakes.
	if attacking and not retreating and t - lastShot > 2.6 then
		lastShot = t
		local gun = croc:FindFirstChild("Gun") :: BasePart?
		local hit = (ship.Spots.Window * CFrame.new(math.random(-14, 14), math.random(-5, 5), -1.5)).Position
		if gun then
			beam(gun.Position, hit, ALARM, 0.5)
		end
		blast(hit, Color3.fromRGB(255, 160, 60), 8)
		shake(0.6)
	end
end

-- The alarm lights pulse red while the ship is under attack.
local function pulseAlarms(t: number)
	local beat = (math.sin(t * 5) + 1) / 2
	for _, light in ship.Alarms do
		light.Brightness = if attacking then 1 + beat * 4 else 0.6
		light.Color = if attacking then ALARM else HOLO
	end
	for _, strip in ship.AlarmStrips do
		strip.Color = if attacking then ALARM:Lerp(Color3.fromRGB(80, 10, 10), 1 - beat) else HOLO
	end
end

-- The tutorial HUD: an objectives list, a caption and one action button.
local OBJECTIVES = {
	"Wake up",
	"Suit up",
	"Collect your Saga Stone ration",
	"Attune your weapon",
	"Drive off the bomber",
	"Teleport to the moon base",
}
local hud = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, canvas)
local objectives = IronUi.box(hud, UDim2.fromOffset(24, 90), UDim2.fromOffset(330, 60 + #OBJECTIVES * 30), P.Frame)
objectives.BackgroundTransparency = 0.15
local objTitle = label(objectives, "OBJECTIVES", 14, SAGA, HEADING)
place(objTitle, 16, 12, 300, 20)
local objLines = {}
for i, textValue in OBJECTIVES do
	local line = label(objectives, "○  " .. textValue, 16, P.Dim, CHUNKY)
	place(line, 16, 40 + (i - 1) * 30, 300, 26)
	objLines[i] = line
end
local function objective(index: number)
	for i, line in objLines do
		local mark = if i < index then "✓" elseif i == index then "►" else "○"
		line.Text = mark .. "  " .. OBJECTIVES[i]
		line.TextColor3 = if i < index then P.Good elseif i == index then Color3.new(1, 1, 1) else P.Dim
	end
end

local promptBox = IronUi.box(hud, UDim2.fromOffset(W / 2 - 330, H - 200), UDim2.fromOffset(660, 170), P.Frame)
promptBox.BackgroundTransparency = 0.1
local promptTitle = label(promptBox, "", 22, SAGA, HEADING)
place(promptTitle, 24, 16, 612, 30)
local promptText = label(promptBox, "", 17, LIGHT, CHUNKY)
place(promptText, 24, 50, 612, 52)
promptText.TextWrapped = true
promptText.TextYAlignment = Enum.TextYAlignment.Top
local pressed = false
local promptButton = IronUi.gemButton(promptBox, "OK", SAGA, function()
	pressed = true
end)
promptButton.AnchorPoint = Vector2.new(0.5, 1)
promptButton.Position = UDim2.new(0.5, 0, 1, -14)
promptButton.Size = UDim2.fromOffset(0, 48)

-- Shows a prompt and waits for its button.
local function prompt(title: string, body: string, button: string)
	promptBox.Visible = true
	promptTitle.Text = title
	promptText.Text = body
	promptButton.Text = button
	promptButton.Visible = true
	pressed = false
	while not pressed do
		task.wait(0.05)
	end
	promptButton.Visible = false
end

local function fade(to: number, seconds: number)
	local cover = gui:FindFirstChild("Fade")
		or new("Frame", {
			Name = "Fade",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 50,
		}, gui)
	TweenService:Create(cover, TweenInfo.new(seconds), { BackgroundTransparency = to }):Play()
	task.wait(seconds)
end

-- The Saga Stone ration: the slot machine, in a panel over the ship.
local function rationSpin()
	local panel = IronUi.box(canvas, UDim2.fromOffset(W / 2 - 430, 90), UDim2.fromOffset(860, 520), P.Frame)
	panel.ZIndex = 30
	local title = label(panel, "SAGA STONE RATION", 30, SAGA, HEADING)
	title.TextXAlignment = Enum.TextXAlignment.Center
	place(title, 0, 22, 860, 40)
	local sub = label(panel, "Three cut Saga Stones, straight from the colony's reserve.", 17, LIGHT, CHUNKY)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	place(sub, 0, 66, 860, 24)
	local body = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, 100),
		Size = UDim2.fromOffset(780, 400),
	}, panel)
	local list = UiKit.list(body, 12)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local lights = { marquee(body, 1, 700) }
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, CARD_H + 16),
		LayoutOrder = 2,
	}, body)
	local rowList = UiKit.list(row, 20, true)
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	table.insert(lights, marquee(body, 3, 700))
	local spins = {}
	for i = 1, 3 do
		local _, spin = reelCard(row, i)
		spins[i] = spin
	end
	local go = false
	local button = IronUi.gemButton(body, "SPIN THE RATION", SAGA, function()
		go = true
	end)
	button.LayoutOrder = 4
	button.Size = UDim2.fromOffset(0, 52)
	while not go do
		task.wait(0.05)
	end
	button.Visible = false
	local result = GemClient.request("StarterSpin")
	if not result.Ok then
		UiKit.toast(result.Message, P.Bad)
		panel:Destroy()
		return
	end
	-- Each reel runs longer than the last; the rarest stone lands last.
	local gems = table.clone(result.Gems or {})
	table.sort(gems, function(a, b)
		return (TIER_RANK[a.Tier] or 1) < (TIER_RANK[b.Tier] or 1)
	end)
	for _, bar in lights do
		bar.Mode = "Spin"
	end
	local done = 0
	for i, spin in spins do
		local gem = gems[i]
		if gem then
			local tease = i == #spins and (TIER_RANK[gem.Tier] or 1) > 1
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
	local best = gems[#gems]
	for _, bar in lights do
		bar.Mode = "Win"
		bar.Color = best and GemConfig.TierColors[best.Tier] or SAGA
	end
	local total = 0
	for _, gem in gems do
		total += GemConfig.value(gem)
	end
	for n = 1, 20 do
		sub.Text = string.format("Your ration is worth  💰 %d", math.floor(total * n / 20))
		task.wait(0.03)
	end
	local taken = false
	local take = IronUi.gemButton(body, "TAKE RATION  ►", P.Emerald, function()
		taken = true
	end)
	take.LayoutOrder = 5
	take.Size = UDim2.fromOffset(0, 52)
	while not taken do
		task.wait(0.05)
	end
	panel:Destroy()
end

-- The best cut stone in the pouch (by value).
local function bestCutStone()
	local best, bestValue = nil, -1
	for _, gem in GemClient.Profile.Gems or {} do
		if gem.Cut and GemConfig.value(gem) > bestValue then
			best, bestValue = gem, GemConfig.value(gem)
		end
	end
	return best
end

local function playShip()
	Scenes.spaceLighting()
	ship = Scenes.ship(SHIP_AT)
	croc = Scenes.croc()
	croc.Parent = workspace
	IronUi.animate(gui, function(t)
		flyCroc(t)
		pulseAlarms(t)
	end)
	local spots = ship.Spots
	local profile = GemClient.Profile
	hud.Visible = true
	promptBox.Visible = false

	-- Wake up: eyes open on the ceiling, alarms blaring.
	objective(1)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame =
		CFrame.lookAt((spots.Bed * CFrame.new(0, 1.5, 3)).Position, (spots.Bed * CFrame.new(0, 12, -2)).Position)
	fade(0, 0.01)
	fade(1, 1.5)
	shake(1)
	prompt(
		"⚠  HULL BREACH",
		"Crusader, wake up! Something came through the rift and it's attacking the ship. Get up!",
		"GET UP"
	)

	-- Suit up at the locker.
	objective(2)
	placeHero(spots.Locker)
	shot(CFrame.lookAt((spots.Locker * CFrame.new(3, 6, -12)).Position, (spots.Locker * CFrame.new(0, 4, 0)).Position))
	if not profile.Character.Class then
		prompt(
			"SUIT UP",
			"Collect your randomized expedition loadout: helmet, chest suit, gloves, boots, weapon and shield.",
			"SUIT UP"
		)
		local result = GemClient.request("SuitUp")
		if not result.Ok then
			UiKit.toast(result.Message, P.Bad)
		end
		refreshHero()
		UiKit.toast("Your randomized expedition gear is equipped.", SAGA)
	end

	-- The daily Saga Stone ration.
	objective(3)
	placeHero(spots.Ration)
	shot(CFrame.lookAt((spots.Ration * CFrame.new(-3, 6, -12)).Position, (spots.Ration * CFrame.new(0, 4, 0)).Position))
	if not profile.Intro.Spun then
		prompt(
			"DAILY RATION",
			"Every colonist gets a Saga Stone ration. Today's is on the house: spin for three cut stones.",
			"OPEN RATION"
		)
		promptBox.Visible = false
		rationSpin()
	end

	-- Enchant the blaster at the console.
	objective(4)
	placeHero(spots.Console * CFrame.new(0, 0, 5))
	shot(CFrame.lookAt((spots.Console * CFrame.new(-8, 8, 8)).Position, (spots.Console * CFrame.new(0, 4, 0)).Position))
	local stone = bestCutStone()
	if not profile.Character.WeaponGem and stone then
		prompt(
			"ENCHANT",
			string.format(
				"Set your best stone, the %s, into your weapon. Its element empowers every attack.",
				GemConfig.shade(stone).Name
			),
			"ENCHANT BLASTER"
		)
		local result = GemClient.request("SocketGem", stone.Id, "Weapon")
		UiKit.toast(result.Message, if result.Ok then SAGA else P.Bad)
		blast((spots.Console * CFrame.new(0, 4.6, 0)).Position, HOLO, 6)
		refreshHero()
	end

	-- Drive off the bomber: shoot it through the window.
	objective(5)
	placeHero(spots.Stand * CFrame.new(0, 0, -6))
	shot(CFrame.lookAt((spots.Stand * CFrame.new(3, 7, 4)).Position, spots.Outside.Position), 1.4)
	prompt("DEFEND THE SHIP", "Shoot the bomber through the window! Hit it five times to drive it off.", "READY")
	local hits = 0
	promptTitle.Text = "HITS  0 / 5"
	promptText.Text = "Press FIRE to shoot."
	local fire = IronUi.gemButton(promptBox, "FIRE", ALARM, function()
		if hits >= 5 or not croc.Parent then
			return
		end
		hits += 1
		local target = crocAt.Position
		beam(muzzle(), target, HOLO, 0.35)
		blast(target, Color3.fromRGB(255, 200, 90), 10)
		promptTitle.Text = string.format("HITS  %d / 5", hits)
	end)
	fire.AnchorPoint = Vector2.new(0.5, 1)
	fire.Position = UDim2.new(0.5, 0, 1, -14)
	fire.Size = UDim2.fromOffset(0, 48)
	while hits < 5 do
		task.wait(0.05)
	end
	fire:Destroy()
	retreating = true
	retreatStart = os.clock()
	blast(crocAt.Position, Color3.fromRGB(255, 120, 40), 18)
	shake(0.8)
	promptTitle.Text = "THE BOMBER RETREATS!"
	promptText.Text = "It's smoking and heading back to the rift. The ship is safe, for now."
	task.wait(2)
	attacking = false

	-- Teleport out.
	objective(6)
	placeHero(spots.Pad)
	shot(CFrame.lookAt((spots.Pad * CFrame.new(0, 7, -14)).Position, (spots.Pad * CFrame.new(0, 4, 0)).Position))
	prompt(
		"TELEPORT",
		"The colony needs every miner at the moon base: the Saga Stone mines, the forge and the market are all there.",
		"TELEPORT"
	)
	local beamColumn = Scenes.part(
		workspace,
		spots.Pad * CFrame.new(0, 6, 0),
		Vector3.new(6, 12, 6),
		HOLO,
		Enum.Material.Neon,
		"Tube",
		{ Transparency = 0.5 }
	)
	TweenService:Create(beamColumn, TweenInfo.new(1), { Size = Vector3.new(1, 14, 1), Transparency = 0.1 }):Play()
	task.wait(1)
	local result = GemClient.request("QuickStart")
	if not result.Ok then
		UiKit.toast(result.Message, P.Bad)
	end
	local flash = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	}, gui)
	task.wait(0.2)
	beamColumn:Destroy()
	if hero then
		hero:Destroy()
	end
	croc:Destroy()
	ship.Model:Destroy()
	hud.Visible = false
	TweenService:Create(flash, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
	task.wait(1)
end

-- Skip the whole intro through the existing server-authoritative quick start.
-- Only remove the scenes after the server confirms the starter kit and rewards.
local introThread: thread? = nil
local skipping = false
local finished = false
local skipInput: RBXScriptConnection? = nil
local function skipIntro()
	if skipping or finished then
		return
	end
	skipping = true
	local ok, result = pcall(GemClient.request, "QuickStart")
	if not ok or not result.Ok then
		skipping = false
		UiKit.toast(if ok then result.Message else "Could not skip the intro. Try again.", P.Bad)
		return
	end
	if finished then
		return
	end
	finished = true
	if introThread and coroutine.status(introThread) ~= "dead" then
		task.cancel(introThread)
	end
	if cameraTween then
		cameraTween:Cancel()
	end
	if skipInput then
		skipInput:Disconnect()
	end
	if hero then
		hero:Destroy()
	end
	if croc then
		croc:Destroy()
	end
	if ship then
		ship.Model:Destroy()
	end
	camera.CameraType = Enum.CameraType.Custom
	gui:Destroy()
	UiKit.toast("Intro skipped. Your starter kit is ready — welcome to the moon base!", SAGA)
end
local skipAll = IronUi.button(canvas, "Skip intro [Space]", false, skipIntro)
skipAll.AnchorPoint = Vector2.new(1, 0)
skipAll.Position = UDim2.fromOffset(W - 24, 78)
skipAll.ZIndex = 30
skipInput = UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		skipIntro()
	end
end)
introThread = task.defer(function()
	playCinematic()
	playShip()
	finished = true
	if skipInput then
		skipInput:Disconnect()
	end
	gui:Destroy()
	UiKit.toast("Welcome to the moon base, Crusader! Press M or click DIG to mine Saga Stones.", SAGA)
end)
