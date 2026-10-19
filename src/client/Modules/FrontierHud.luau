--[[
	The frontier on screen:

	  a banner     as you cross from one band of the Outpost into another
	               (the server's FrontierBand on your Player: Core, Fringe,
	               Edge; Shared.Frontier), in the band's colour, so you know
	               where the critters start and how rich the rocks run. The
	               same band's banner doesn't come back for a while
	               (crossing to and fro at a boundary).
	  the noise    a ring of twenty dots on the right, out past the core:
	               how close your mining is to drawing critters
	               (FrontierNoise, in twentieths). Nearly full, it glows red.
	  stirred up   under it, once your mining has the frontier restless
	               (FrontierStir; Frontier.Disturbance): its stage and a
	               bar, gold to orange to red as it swarms.
	  arrows       a rift coming for you (its Prey is you) that opens off
	               screen gets an arrow at the screen's edge, pointing at
	               it, till its critter is out.
	  Rift Charged a tag with the seconds left, after you helped clear a
	               wandering rift (RiftCharged: gems come luckier).
	  vein news    a banner when a Rift Vein surfaces somewhere new
	               (workspace's VeinNews, VeinNewsAt), saying which way.
	  sightings    the nearest wild kaiju within Sighting studs, off
	               screen, gets an arrow at the screen's edge with how far
	               it is (the vein guardian's in red), so you can find them.

	  FrontierHud.start()
	  FrontierHud.Lines[band] -> title, subtitle   (pure, for tests)
	  FrontierHud.lit(noise) -> dots lit (0..20)   (pure)
	  FrontierHud.stirRow(stir) -> text?, color, fill   the stirred-up row:
	      nil while calm (pure)
	  FrontierHud.edge(size, point, margin) -> Vector2, angle   where an
	      arrow sits for a point off screen (pure)
	  FrontierHud.nearest(spots, from, reach) -> index?, studs   the nearest
	      of `spots` (Vector3s) within `reach` across the ground (pure)
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Frontier = require(ReplicatedStorage.Shared.Frontier)

local FrontierHud = {}

FrontierHud.Lines = {
	Core = { "OUTPOST CORE", "Safe from the rifts" },
	Fringe = { "THE FRINGE", "Mining out here draws critters  ·  richer rocks" },
	Edge = { "THE EDGE", "Tougher critters, sooner  ·  the richest rocks" },
}
FrontierHud.Again = 20 -- seconds before the same band's banner shows again
FrontierHud.Hold = 2.6
FrontierHud.Dots = 20
local RED = Color3.fromRGB(255, 80, 90)
local DIM = Color3.fromRGB(60, 52, 76)

local shown: { [string]: number } = {}
FrontierHud.Sighting = 220 -- studs: how far off a wild kaiju gets an arrow
local WILD = Color3.fromRGB(255, 176, 70)

-- Dots lit for `noise` (0..1).
function FrontierHud.lit(noise: number?): number
	return math.clamp(math.floor((noise or 0) * FrontierHud.Dots + 0.5), 0, FrontierHud.Dots)
end

-- The stirred-up row's colour at each stage (none while calm).
FrontierHud.StirColors = {
	[2] = Color3.fromRGB(255, 206, 96),
	[3] = Color3.fromRGB(255, 142, 64),
	[4] = RED,
}

-- The stirred-up row for `stir` (0..1): its text, colour and how full its
-- bar is; nil text while calm.
function FrontierHud.stirRow(stir: number?): (string?, Color3, number)
	local fill = math.clamp(stir or 0, 0, 1)
	local index, stage = Frontier.stage(fill)
	local color = FrontierHud.StirColors[index]
	if not color then
		return nil, DIM, fill
	end
	return string.upper(stage.Name), color, fill
end

-- Where an arrow sits for `point` (a screen point, possibly off screen or
-- mirrored from behind the camera) on a screen of `size`, `margin` in from
-- its edge, and the angle it points (radians, 0 = right).
function FrontierHud.edge(size: Vector2, point: Vector2, margin: number): (Vector2, number)
	local middle = size / 2
	local d = point - middle
	if d.Magnitude < 1e-3 then
		d = Vector2.new(0, 1)
	end
	local halfW, halfH = math.max(1, middle.X - margin), math.max(1, middle.Y - margin)
	local scale = math.min(halfW / math.max(math.abs(d.X), 1e-3), halfH / math.max(math.abs(d.Y), 1e-3))
	return middle + d * scale, math.atan2(d.Y, d.X)
end

-- The nearest of `spots` within `reach` of `from`, across the ground.
function FrontierHud.nearest(spots: { Vector3 }, from: Vector3, reach: number): (number?, number)
	local best, bestDistance = nil, reach
	for i, spot in spots do
		local distance = Vector2.new(spot.X - from.X, spot.Z - from.Z).Magnitude
		if distance <= bestDistance then
			best, bestDistance = i, distance
		end
	end
	return best, bestDistance
end

local function banner(player: Player, gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.17)
	frame.Size = UDim2.fromOffset(460, 58)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local function label(y: number, height: number, size: number, font: Enum.Font): TextLabel
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(0, y)
		text.Size = UDim2.new(1, 0, 0, height)
		text.Font = font
		text.TextSize = size
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeColor3 = Color3.new(0, 0, 0)
		text.TextTransparency = 1
		text.TextStrokeTransparency = 1
		text.Parent = frame
		return text
	end
	local title = label(0, 32, 28, Enum.Font.GothamBlack)
	local subtitle = label(34, 20, 14, Enum.Font.GothamBold)
	local rule = Instance.new("Frame")
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, 32)
	rule.Size = UDim2.fromOffset(0, 2)
	rule.BorderSizePixel = 0
	rule.BackgroundTransparency = 1
	rule.Parent = frame
	local token = 0
	local function fade(to: number, seconds: number)
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad)
		for _, text in { title, subtitle } do
			TweenService:Create(text, info, { TextTransparency = to, TextStrokeTransparency = 0.35 + 0.65 * to }):Play()
		end
		TweenService:Create(rule, info, { BackgroundTransparency = to }):Play()
	end
	local function showLines(lines, color: Color3)
		token += 1
		local mine = token
		title.Text, subtitle.Text = lines[1], lines[2]
		title.TextColor3 = color
		rule.BackgroundColor3 = color
		rule.Size = UDim2.fromOffset(0, 2)
		frame.Visible = true
		fade(0, 0.35)
		TweenService:Create(rule, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(220, 2) }):Play()
		task.delay(FrontierHud.Hold, function()
			if mine == token then
				fade(1, 0.6)
				task.delay(0.65, function()
					if mine == token then
						frame.Visible = false
					end
				end)
			end
		end)
	end
	local function show(band: string)
		local lines = FrontierHud.Lines[band]
		local now = os.clock()
		if not lines or (shown[band] and now - shown[band] < FrontierHud.Again) then
			return
		end
		shown[band] = now
		showLines(lines, Frontier.Bands[band].Color)
	end
	-- A Rift Vein surfacing somewhere new (while you're in the Outpost).
	workspace:GetAttributeChangedSignal("VeinNewsAt"):Connect(function()
		local news = workspace:GetAttribute("VeinNews")
		if type(news) == "string" and player:GetAttribute("Outpost") == true then
			showLines({ "RIFT VEIN", news }, Frontier.RiftColor)
		end
	end)
	local last = player:GetAttribute("FrontierBand")
	player:GetAttributeChangedSignal("FrontierBand"):Connect(function()
		local band = player:GetAttribute("FrontierBand")
		-- (Arriving in the Outpost isn't crossing into the core.)
		if type(band) == "string" and last ~= nil then
			show(band)
		end
		last = band
	end)
end

-- The noise ring, and the Rift Charged tag under it.
local function noiseRing(player: Player, gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Name = "Noise"
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -18, 0.5, 30)
	holder.Size = UDim2.fromOffset(62, 80)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local dots = {}
	local radius = 24
	for i = 1, FrontierHud.Dots do
		local a = (i - 1) / FrontierHud.Dots * math.pi * 2 - math.pi / 2
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(31 + math.cos(a) * radius, 31 + math.sin(a) * radius)
		dot.Size = UDim2.fromOffset(6, 6)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = DIM
		dot.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		dots[i] = dot
	end
	local word = Instance.new("TextLabel")
	word.BackgroundTransparency = 1
	word.Position = UDim2.fromOffset(0, 22)
	word.Size = UDim2.fromOffset(62, 18)
	word.Font = Enum.Font.GothamBlack
	word.TextSize = 10
	word.Text = "NOISE"
	word.TextColor3 = Color3.fromRGB(230, 225, 240)
	word.TextStrokeTransparency = 0.5
	word.Parent = holder
	-- How stirred up: its stage over a thin bar.
	local stirRow = Instance.new("Frame")
	stirRow.Name = "Stirred"
	stirRow.AnchorPoint = Vector2.new(1, 0)
	stirRow.Position = UDim2.new(1, 0, 0, 62)
	stirRow.Size = UDim2.fromOffset(84, 22)
	stirRow.BackgroundTransparency = 1
	stirRow.Visible = false
	stirRow.Parent = holder
	local stirWord = Instance.new("TextLabel")
	stirWord.BackgroundTransparency = 1
	stirWord.Size = UDim2.new(1, 0, 0, 13)
	stirWord.Font = Enum.Font.GothamBlack
	stirWord.TextSize = 10
	stirWord.TextXAlignment = Enum.TextXAlignment.Right
	stirWord.TextStrokeTransparency = 0.5
	stirWord.Parent = stirRow
	local stirBar = Instance.new("Frame")
	stirBar.AnchorPoint = Vector2.new(1, 0)
	stirBar.Position = UDim2.new(1, 0, 0, 15)
	stirBar.Size = UDim2.new(1, 0, 0, 5)
	stirBar.BorderSizePixel = 0
	stirBar.BackgroundColor3 = DIM
	stirBar.Parent = stirRow
	local stirFill = Instance.new("Frame")
	stirFill.BorderSizePixel = 0
	stirFill.Size = UDim2.fromScale(0, 1)
	stirFill.Parent = stirBar
	for _, bar in { stirBar, stirFill } do
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = bar
	end
	local charged = Instance.new("TextLabel")
	charged.Name = "RiftCharged"
	charged.BackgroundColor3 = Color3.fromRGB(40, 16, 64)
	charged.BackgroundTransparency = 0.2
	charged.AnchorPoint = Vector2.new(1, 0)
	charged.Position = UDim2.new(1, 0, 0, 64)
	charged.Size = UDim2.fromOffset(132, 18)
	charged.Font = Enum.Font.GothamBlack
	charged.TextSize = 11
	charged.TextColor3 = Frontier.RiftColor:Lerp(Color3.new(1, 1, 1), 0.35)
	charged.Visible = false
	charged.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = charged

	local function refresh()
		local band = player:GetAttribute("FrontierBand")
		local noise = player:GetAttribute("FrontierNoise")
		local out = (band == "Fringe" or band == "Edge") and type(noise) == "number"
		local ends = player:GetAttribute("RiftCharged")
		local left = if type(ends) == "number" then ends - workspace:GetServerTimeNow() else 0
		charged.Visible = left > 0
		if left > 0 then
			charged.Text = string.format("RIFT CHARGED · %ds", math.ceil(left))
		end
		holder.Visible = out or left > 0
		local lit = FrontierHud.lit(noise)
		local color = if lit >= FrontierHud.Dots - 3 then RED else Frontier.Bands[band or "Fringe"].Color
		for i, dot in dots do
			dot.Visible = out
			dot.BackgroundColor3 = if i <= lit then color else DIM
		end
		word.Visible = out
		local stirText, stirColor, stirShare = FrontierHud.stirRow(player:GetAttribute("FrontierStir"))
		stirRow.Visible = out and stirText ~= nil
		if stirRow.Visible then
			stirWord.Text = stirText :: string
			stirWord.TextColor3 = stirColor
			stirFill.BackgroundColor3 = stirColor
			stirFill.Size = UDim2.fromScale(stirShare, 1)
		end
		-- (Rift Charged sits under the stirred-up row when it shows.)
		charged.Position = UDim2.new(1, 0, 0, if stirRow.Visible then 88 else 64)
	end
	for _, key in { "FrontierBand", "FrontierNoise", "FrontierStir", "RiftCharged" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
	-- (The Rift Charged seconds tick down.)
	task.spawn(function()
		while true do
			task.wait(1)
			if charged.Visible then
				refresh()
			end
		end
	end)
end

-- Arrows at the screen's edge for rifts coming for you, off screen.
local function arrows(player: Player, gui: ScreenGui)
	local watched: { [BasePart]: TextLabel } = {}
	local stepping: RBXScriptConnection? = nil
	local function arrow(): TextLabel
		local text = Instance.new("TextLabel")
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Size = UDim2.fromOffset(34, 34)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextSize = 28
		text.Text = "➤"
		text.TextColor3 = Frontier.RiftColor:Lerp(Color3.new(1, 1, 1), 0.2)
		text.TextStrokeTransparency = 0.3
		text.Visible = false
		text.Parent = gui
		return text
	end
	local function step()
		local camera = workspace.CurrentCamera
		local now = workspace:GetServerTimeNow()
		for anchor, label in watched do
			local done = not anchor.Parent or now > (anchor:GetAttribute("HopAt") or 0) + 1.5
			if done or not camera then
				label:Destroy()
				watched[anchor] = nil
				continue
			end
			-- (This screen sits below Roblox's top bar: its points are the
			-- viewport's, less the bar.)
			local point, onScreen = camera:WorldToViewportPoint(anchor.Position)
			local inset = GuiService:GetGuiInset()
			local size = camera.ViewportSize - Vector2.new(0, inset.Y)
			local y = point.Y - inset.Y
			local inside = onScreen and point.X >= 0 and y >= 0 and point.X <= size.X and y <= size.Y
			label.Visible = not inside
			if not inside then
				local flat = Vector2.new(point.X, y)
				if point.Z < 0 then
					flat = size - flat -- (behind the camera: mirrored)
				end
				local at, angle = FrontierHud.edge(size, flat, 40)
				label.Position = UDim2.fromOffset(at.X, at.Y)
				label.Rotation = math.deg(angle)
			end
		end
		if next(watched) == nil and stepping then
			stepping:Disconnect()
			stepping = nil
		end
	end
	local function track(anchor: Instance)
		-- (Its attributes arrive with it; a critter slipping back has no Prey.)
		if not anchor:IsA("BasePart") or anchor:GetAttribute("Dormant") then
			return
		end
		if anchor:GetAttribute("Prey") ~= player.UserId or watched[anchor] or not anchor.Parent then
			return
		end
		watched[anchor] = arrow()
		if not stepping then
			stepping = RunService.RenderStepped:Connect(step)
		end
	end
	task.spawn(function()
		local rifts = workspace:WaitForChild("Rifts", 120)
		if not rifts then
			return
		end
		rifts.ChildAdded:Connect(track)
	end)
end

-- An arrow at the screen's edge toward the nearest wild kaiju off screen
-- (within Sighting studs, in the Outpost, not in a fight), with how far.
local function sightings(player: Player, gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(70, 46)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.32)
	arrow.Size = UDim2.fromOffset(26, 26)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 22
	arrow.Text = "➤"
	arrow.TextStrokeTransparency = 0.3
	arrow.Parent = holder
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.62)
	label.Size = UDim2.fromOffset(90, 14)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextStrokeTransparency = 0.35
	label.Parent = holder
	local target: BasePart? = nil
	local guard = false
	local scanIn = 0
	RunService.RenderStepped:Connect(function(dt)
		scanIn -= dt
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local busy = player:GetAttribute("Outpost") ~= true or player:GetAttribute("CombatSession") ~= nil
		if scanIn <= 0 then
			scanIn = 0.25
			target = nil
			local enemies = workspace:FindFirstChild("Enemies")
			if me and not busy and enemies then
				local spots, parts = {}, {}
				for _, model in enemies:GetChildren() do
					local root = model:GetAttribute("KaijuWild") and (model :: Model).PrimaryPart
					if root then
						table.insert(spots, root.Position)
						table.insert(parts, root)
					end
				end
				local index = FrontierHud.nearest(spots, me.Position, FrontierHud.Sighting)
				target = if index then parts[index] else nil
				guard = target ~= nil and (target.Parent :: Instance):GetAttribute("KaijuGuardian") == true
			end
		end
		local camera = workspace.CurrentCamera
		if not target or not target.Parent or not me or busy or not camera then
			holder.Visible = false
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(target.Position)
		local inset = GuiService:GetGuiInset()
		local size = camera.ViewportSize - Vector2.new(0, inset.Y)
		local y = point.Y - inset.Y
		local inside = onScreen and point.X >= 0 and y >= 0 and point.X <= size.X and y <= size.Y
		holder.Visible = not inside
		if inside then
			return
		end
		local flat = Vector2.new(point.X, y)
		if point.Z < 0 then
			flat = size - flat -- (behind the camera: mirrored)
		end
		local at, angle = FrontierHud.edge(size, flat, 64)
		holder.Position = UDim2.fromOffset(at.X, at.Y)
		arrow.Rotation = math.deg(angle)
		local color = if guard then Frontier.Bands.Guarded.Color else WILD
		arrow.TextColor3, label.TextColor3 = color, color
		local studs = Vector2.new(target.Position.X - me.Position.X, target.Position.Z - me.Position.Z).Magnitude
		label.Text = string.format("%s %d", if guard then "GUARDIAN" else "KAIJU", math.floor(studs + 0.5))
	end)
end

function FrontierHud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "FrontierBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")
	banner(player, gui)
	noiseRing(player, gui)
	arrows(player, gui)
	sightings(player, gui)
end

return FrontierHud
