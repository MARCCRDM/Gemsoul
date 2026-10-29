--[[
	A Legendary mined: a window bursts open over the miner's head, for them
	and everyone near. A pillar of gold light shoots up out of them and a
	shockwave runs along the ground, confetti and sparks fly; then a gold
	line draws across the air over their head and snaps open into a window:
	LEGENDARY! bouncing in, the gem turning inside it, its name and worth,
	rays wheeling behind it, a shine sweeping across, the frame pulsing.
	After a few seconds it folds shut back into the line and is gone.

	  LegendaryWindow.play(character, gem, finder?)   `finder`: the name over
	                       it for someone else's find ("NAME FOUND A"); none
	                       for your own
	  LegendaryWindow.at(t)   the window's shape `t` seconds in (pure, for
	                       tests): Width and Height (0 to 1 of its full size),
	                       Title and Gem (their pop, a scale), Shine (the
	                       sweep's offset), Fade (0 shown, 1 gone), Done

	Your own find plays it from your loot card's landing (MinerLoot);
	someone else's from their box over their head (MiningWorldReveal),
	which steps aside for it. Its sound is CombatSound's LegendaryWindow.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CombatSound = require(script.Parent.CombatSound)
local GemArt = require(script.Parent.GemArt)

local LegendaryWindow = {}

local GOLD = Color3.fromRGB(255, 196, 70)
local LIGHT = Color3.fromRGB(255, 240, 190)
local INK = Color3.fromRGB(10, 12, 20)
-- Seconds: the line drawing across, the window opening, held open, folding.
LegendaryWindow.Line = 0.2
LegendaryWindow.Open = 0.35
LegendaryWindow.Hold = 3.6
LegendaryWindow.Close = 0.4
LegendaryWindow.Size = Vector2.new(10, 4.4) -- studs: it reads from across the quarry
LegendaryWindow.Above = 4.2 -- studs over the head
local RAYS = 12
local active = 0

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function outCubic(x: number): number
	return 1 - (1 - x) ^ 3
end
-- Overshoots a little, then settles (a pop).
local function outBack(x: number): number
	local c = 1.9
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

function LegendaryWindow.at(t: number)
	local W = LegendaryWindow
	local opened = W.Line + W.Open
	local closing = opened + W.Hold
	local state = { Width = 0, Height = 0, Title = 0, Gem = 0, Shine = -1, Fade = 0, Done = false }
	if t < 0 then
		return state
	end
	if t >= closing + W.Close then
		state.Done, state.Fade = true, 1
		return state
	end
	-- The line across, then the window opening out of it.
	state.Width = outCubic(clamp01(t / W.Line))
	state.Height = 0.05 + 0.95 * outBack(clamp01((t - W.Line) / W.Open))
	-- LEGENDARY! and the gem pop in once it's open.
	state.Title = outBack(clamp01((t - opened + 0.1) / 0.35))
	state.Gem = outBack(clamp01((t - opened) / 0.4))
	-- A shine sweeping across every 1.4 s.
	state.Shine = -1 + 2 * ((math.max(0, t - opened) % 1.4) / 1.4)
	if t >= closing then
		-- Folding: back to the line, then the line gone.
		local p = clamp01((t - closing) / W.Close)
		state.Height = 0.05 + 0.95 * (1 - outCubic(clamp01(p / 0.6)))
		state.Width = 1 - outCubic(clamp01((p - 0.6) / 0.4))
		state.Title, state.Gem = 1 - p, 1 - p
		state.Fade = p
	end
	return state
end

local function part(name: string, props): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function sparks(parent: Instance, colors: ColorSequence, count: number, speed: NumberRange, size: number, life: NumberRange)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = colors
	emitter.LightEmission, emitter.LightInfluence = 1, 0
	emitter.Rate = 0
	emitter.Lifetime, emitter.Speed = life, speed
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -14, 0)
	emitter.Drag = 1.5
	emitter.Rotation, emitter.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-260, 260)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Parent = parent
	emitter:Emit(count)
	return emitter
end

-- Gold light up out of them, a ring along the ground, sparks and confetti.
local function burst(folder: Instance, root: BasePart, color: Color3)
	local feet = root.Position - Vector3.new(0, 3, 0)
	local pillar = part("LegendaryPillar", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 3.2, 3.2),
		CFrame = CFrame.new(feet + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GOLD,
		Transparency = 0.15,
	})
	pillar.Parent = folder
	local core = part("LegendaryCore", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 1, 1),
		CFrame = pillar.CFrame,
		Color = LIGHT,
		Transparency = 0.05,
	})
	core.Parent = folder
	local ring = part("LegendaryRing", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2, 2),
		CFrame = CFrame.new(feet + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GOLD,
		Transparency = 0.2,
	})
	ring.Parent = folder
	local glow = Instance.new("PointLight")
	glow.Color, glow.Brightness, glow.Range = GOLD, 6, 24
	glow.Parent = core
	local spot = Instance.new("Attachment")
	spot.WorldPosition = root.Position
	spot.Parent = workspace.Terrain
	Debris:AddItem(spot, 4)
	sparks(spot, ColorSequence.new(LIGHT, GOLD), 70, NumberRange.new(14, 30), 0.7, NumberRange.new(0.8, 1.6))
	sparks(spot, ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	}), 50, NumberRange.new(8, 18), 0.45, NumberRange.new(1.5, 2.6))
	return { Pillar = pillar, Core = core, Ring = ring, Glow = glow, Feet = feet }
end

local function stepBurst(fx, t: number)
	-- The pillar shoots up thin and fades in a second; the ring runs out 30 studs.
	local p = clamp01(t / 1.1)
	local width = 3.2 * (1 - p) ^ 0.6
	fx.Pillar.Size = Vector3.new(60, math.max(width, 0.05), math.max(width, 0.05))
	fx.Pillar.Transparency = 0.15 + 0.85 * p
	fx.Core.Size = Vector3.new(60, math.max(width * 0.35, 0.05), math.max(width * 0.35, 0.05))
	fx.Core.Transparency = 0.05 + 0.95 * p
	fx.Glow.Brightness = 6 * (1 - p)
	local r = clamp01(t / 0.9)
	local across = 2 + 58 * outCubic(r)
	fx.Ring.Size = Vector3.new(0.2, across, across)
	fx.Ring.Transparency = 0.2 + 0.8 * r
end

local function label(parent: Instance, text: string, color: Color3, font: Enum.Font, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = font
	l.TextScaled = true
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- The window over their head (a BillboardGui sized in studs, so it's as big
-- in the world near or far).
local function window(anchor: BasePart, gem, finder: string?)
	local W = LegendaryWindow
	local board = Instance.new("BillboardGui")
	board.Name = "LegendaryWindow"
	board.Adornee = anchor
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 220
	board.Size = UDim2.fromScale(W.Size.X * 1.5, W.Size.Y * 2.2) -- (room round it for the rays)
	board.StudsOffsetWorldSpace = Vector3.new(0, W.Above, 0)
	board.ClipsDescendants = false
	board.Parent = anchor
	local ui = { Board = board, Rays = {} }
	-- Rays wheeling behind it.
	local halo = Instance.new("Frame")
	halo.Name = "Rays"
	halo.BackgroundTransparency = 1
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(1, 1)
	halo.Parent = board
	for i = 1, RAYS / 2 do
		local ray = Instance.new("Frame")
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(0.95, 0.045)
		ray.BackgroundColor3 = if i % 2 == 0 then LIGHT else GOLD
		ray.BackgroundTransparency = 1
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.2),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.65, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		ray.Parent = halo
		table.insert(ui.Rays, ray)
	end
	-- Diamond sparkles twinkling round it.
	ui.Stars = {}
	for i, spot in { { 0.2, 0.2 }, { 0.82, 0.16 }, { 0.12, 0.7 }, { 0.9, 0.78 }, { 0.5, 0.08 }, { 0.58, 0.92 } } do
		local star = Instance.new("Frame")
		star.Name = "Sparkle"
		star.BorderSizePixel = 0
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(spot[1], spot[2])
		star.Size = UDim2.fromScale(0.022, 0.034)
		star.Rotation = 45
		star.BackgroundColor3 = if i % 2 == 0 then LIGHT else GOLD
		star.ZIndex = 8
		star.Parent = board
		local twinkle = Instance.new("UIScale")
		twinkle.Parent = star
		table.insert(ui.Stars, { Frame = star, Scale = twinkle, Phase = i * 1.3 })
	end
	-- The window itself.
	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = Color3.new(1, 1, 1) -- (the gradient's own colours: it tints this)
	frame.BackgroundTransparency = 0.06
	frame.ClipsDescendants = true
	frame.ZIndex = 2
	frame.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = frame
	local back = Instance.new("UIGradient")
	back.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(104, 66, 14)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(34, 24, 12)),
		ColorSequenceKeypoint.new(1, INK),
	})
	back.Rotation = 90
	back.Parent = frame
	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 4
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = frame
	ui.Window, ui.Edge = frame, edge
	-- A shine sweeping across.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = 6
	shine.Parent = frame
	local sweep = Instance.new("UIGradient")
	sweep.Rotation = 20
	sweep.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.72),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sweep.Parent = shine
	ui.Sweep = sweep
	-- The gem, turning, on the left.
	local well = Instance.new("Frame")
	well.Name = "Gem"
	well.BackgroundTransparency = 1
	well.AnchorPoint = Vector2.new(0.5, 0.5)
	well.Position = UDim2.fromScale(0.18, 0.5)
	well.Size = UDim2.fromScale(0.3, 0.9)
	well.ZIndex = 3
	well.Parent = frame
	local gemScale = Instance.new("UIScale")
	gemScale.Parent = well
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = 3
	viewport.Parent = well
	local model, radius = GemArt.model(gem, true)
	GemArt.setupViewport(viewport, GemArt.cardDistance(radius) * 0.9)
	model.Parent = viewport
	ui.Model, ui.GemScale = model, gemScale
	-- Who found it (someone else's), LEGENDARY!, the gem's name and worth.
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromScale(0.34, 0.08)
	words.Size = UDim2.fromScale(0.62, 0.84)
	words.ZIndex = 3
	words.Parent = frame
	local top = label(words, if finder then string.upper(finder) .. " FOUND A" else "YOU FOUND A", LIGHT, Enum.Font.GothamBold, {
		Size = UDim2.fromScale(1, 0.16),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	if finder then
		top:SetAttribute("NoTranslate", true)
	end
	local title = label(words, "LEGENDARY!", GOLD, Enum.Font.GothamBlack, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.42),
		Size = UDim2.fromScale(1, 0.38),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(90, 40, 0)
	titleStroke.Thickness = 2.5
	titleStroke.Parent = title
	local titleShine = Instance.new("UIGradient")
	titleShine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, GOLD),
	})
	titleShine.Parent = title
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title
	ui.TitleScale, ui.TitleShine = titleScale, titleShine
	local name = label(words, GemConfig.shade(gem).Name, GemConfig.ElementColors[gem.Element] or LIGHT, Enum.Font.GothamBold, {
		Position = UDim2.fromScale(0, 0.64),
		Size = UDim2.fromScale(1, 0.18),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	name:SetAttribute("NoTranslate", true)
	label(words, string.format("≈ %d ◆", math.floor(GemConfig.value(gem))), LIGHT, Enum.Font.GothamBold, {
		Position = UDim2.fromScale(0, 0.84),
		Size = UDim2.fromScale(1, 0.15),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.15,
		ZIndex = 3,
	})
	ui.Texts = words:GetChildren()
	return ui
end

local function stepWindow(ui, gem, t: number)
	local W = LegendaryWindow
	local s = LegendaryWindow.at(t)
	local wide, tall = W.Size.X / (W.Size.X * 1.5), W.Size.Y / (W.Size.Y * 2.2)
	-- A gentle bob once it's open.
	local bob = math.sin(t * 2.2) * 0.012
	ui.Window.Size = UDim2.fromScale(wide * s.Width, tall * s.Height)
	ui.Window.Position = UDim2.fromScale(0.5, 0.5 + bob)
	ui.Window.Visible = s.Width > 0.01
	ui.Edge.Thickness = 3 + 1.5 * (0.5 + 0.5 * math.sin(t * 7))
	ui.Edge.Color = GOLD:Lerp(LIGHT, 0.5 + 0.5 * math.sin(t * 7))
	ui.Sweep.Offset = Vector2.new(s.Shine, 0)
	ui.TitleScale.Scale = math.max(0.01, s.Title)
	ui.TitleShine.Offset = Vector2.new(-1 + 2 * ((t * 0.7) % 1), 0)
	ui.GemScale.Scale = math.max(0.01, s.Gem)
	ui.Model:PivotTo(CFrame.new(0, math.sin(t * 2.4) * 0.08, 0) * GemArt.pose(gem, 0.6 + t * 1.8))
	-- The rays: out as it opens, wheeling, gone as it folds.
	local show = clamp01(s.Height) * (1 - s.Fade)
	for _, star in ui.Stars do
		local beat = math.max(0, math.sin(t * 4 + star.Phase))
		star.Scale.Scale = math.max(0.01, show * (0.4 + 1.1 * beat))
		star.Frame.BackgroundTransparency = 1 - show * (0.3 + 0.7 * beat)
	end
	for i, ray in ui.Rays do
		ray.Rotation = (i - 1) * (360 / RAYS) + t * 24
		ray.BackgroundTransparency = 1 - 0.55 * show * (0.75 + 0.25 * math.sin(t * 3 + i))
	end
end

-- (For tests and renders: the window built on `anchor`, and posed at `t`.)
LegendaryWindow._window, LegendaryWindow._pose = window, stepWindow

-- `character`: the miner's; `gem`: what they found; `finder`: their name if
-- it isn't you.
function LegendaryWindow.play(character: Model?, gem, finder: string?)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not root or type(gem) ~= "table" or active >= 3 then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude > 220 then
		return
	end
	active += 1
	local folder = Instance.new("Folder")
	folder.Name = "LegendaryFind"
	folder.Parent = workspace
	local color = GemConfig.ElementColors[gem.Element] or GOLD
	local fx = burst(folder, root, color)
	local ui = window(head or root, gem, finder)
	CombatSound.play("LegendaryWindow", if finder then root.Position else nil)
	local W = LegendaryWindow
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		local done = LegendaryWindow.at(t).Done
		if done or not ui.Board.Parent then
			connection:Disconnect()
			ui.Board:Destroy()
			folder:Destroy()
			active -= 1
			return
		end
		stepBurst(fx, t)
		stepWindow(ui, gem, t)
		-- A second shower as it opens.
		if not ui.Showered and t >= W.Line + W.Open * 0.6 then
			ui.Showered = true
			local spot = Instance.new("Attachment")
			spot.WorldPosition = (head or root).Position + Vector3.new(0, W.Above, 0)
			spot.Parent = workspace.Terrain
			Debris:AddItem(spot, 3)
			sparks(spot, ColorSequence.new(LIGHT, GOLD), 40, NumberRange.new(6, 14), 0.4, NumberRange.new(0.8, 1.6))
		end
	end)
end

return LegendaryWindow
