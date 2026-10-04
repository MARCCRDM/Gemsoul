--[[
	The title screen on joining, classic style, drawn to match the SAGA
	MINERS logo video (no video upload needed):
	  1. the intro: the logo rises out of the dark over the theme song's
	     build, and the drop hits with a white flash;
	  2. the title: the logo stays, its animation keeps looping (the shine
	     sweeping across the letters, sparkles, a shooting star, twinkling
	     stars), the song carries on from the drop, and "CLICK TO ENTER"
	     blinks until you click, tap or press a key.
	A click during the intro jumps straight to the title. Everything else
	(the launch intro, the dashboard, the background music) waits until you
	enter.

	The picture is Modules.SplashArt: the video's steady frame cut into
	flat-coloured rectangles by tools/make_splash_art.py. The music is
	Music.Ids.Intro (the build and drop) then Music.Ids.Fight (the loop).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local IronUi = require(script.Parent.Modules.IronUi)
local Music = require(script.Parent.Modules.Music)
local Art = require(script.Parent.Modules.SplashArt)

local LENGTH = 9.9 -- seconds of intro: six bars of the song
local BAR = 4 * 60 / 144.94
local DROP = BAR -- the drop lands one bar in
-- The title loop is fight_theme (bars 81-97); the intro ends at bar 86.
local TITLE_LOOP_FROM = 5 * BAR
local CYCLE = 4.2 -- the logo animation's loop, as in the video
local BACKGROUND = Color3.fromRGB(10, 8, 25) -- the art's own deep-space colour
local GOLD = Color3.fromRGB(255, 202, 91)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Splash"
gui.DisplayOrder = 500
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local back = Instance.new("CanvasGroup")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = BACKGROUND
back.BorderSizePixel = 0
back.Parent = gui

-- A dark veil over everything while the art is built and the logo rises.
local veil = Instance.new("Frame")
veil.Size = UDim2.fromScale(1, 1)
veil.BackgroundColor3 = BACKGROUND
veil.BorderSizePixel = 0
veil.ZIndex = 8
veil.Parent = back
gui.Parent = player:WaitForChild("PlayerGui")

local function hex(value: string): Color3
	return Color3.fromRGB(
		tonumber(string.sub(value, 1, 2), 16) :: number,
		tonumber(string.sub(value, 3, 4), 16) :: number,
		tonumber(string.sub(value, 5, 6), 16) :: number
	)
end

-- The square picture, as big as fits the screen (its height on a monitor,
-- its width on a phone held upright), in the middle.
local stage = Instance.new("Frame")
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.Position = UDim2.fromScale(0.5, 0.5)
stage.BackgroundTransparency = 1
stage.ClipsDescendants = true
stage.Parent = back
local function fit()
	local screen = gui.AbsoluteSize
	local side = math.min(screen.X, screen.Y)
	if side <= 0 then
		side = 600
	end
	stage.Size = UDim2.fromOffset(side, side)
end
fit()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

-- Draws one layer of rectangles. A hair of overlap hides seams between them.
local built = 0
local function layer(
	name: string,
	spec,
	originX: number,
	originY: number,
	z: number
): { { Frame: Frame, Base: Color3, D: number } }
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = stage
	local palette = {}
	for i, value in spec.Palette do
		palette[i - 1] = hex(value)
	end
	local size, grid = Art.Size, spec.Grid
	local seam = 0.35 / size
	local made = {}
	local rects = spec.Rects
	for i = 1, #rects, 10 do
		local x = tonumber(string.sub(rects, i, i + 1), 16) :: number
		local y = tonumber(string.sub(rects, i + 2, i + 3), 16) :: number
		local w = tonumber(string.sub(rects, i + 4, i + 5), 16) :: number
		local h = tonumber(string.sub(rects, i + 6, i + 7), 16) :: number
		local c = tonumber(string.sub(rects, i + 8, i + 9), 16) :: number
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = palette[c]
		f.Position = UDim2.fromScale((originX + x * grid) / size, (originY + y * grid) / size)
		f.Size = UDim2.fromScale(w * grid / size + seam, h * grid / size + seam)
		f.ZIndex = z
		f.Parent = holder
		-- Where it sits along the shine's diagonal (0 at the left, 1 at the right).
		local cx = (originX + (x + w / 2) * grid) / size
		local cy = (originY + (y + h / 2) * grid) / size
		table.insert(made, { Frame = f, Base = palette[c], D = cx + (cy - 0.5) * 0.55 })
		built += 1
		if built % 500 == 0 then
			task.wait()
		end
	end
	return made
end

-- A twinkling star: a cross of two thin bars (the art's "+" stars), or a dot.
local function star(parent: Instance, x: number, y: number, size: number, color: Color3, z: number)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(x, y)
	holder.Size = UDim2.fromOffset(size * 3, size * 3)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = parent
	local bars = {}
	for i, dims in { { 1, 1 / 3 }, { 1 / 3, 1 } } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = if size >= 3 then UDim2.fromScale(dims[1], dims[2]) else UDim2.fromScale(1 / 3, 1 / 3)
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.ZIndex = z
		bar.Parent = holder
		bars[i] = bar
	end
	local speed, offset = 1 + (x * 7 % 1.6), (y * 31) % 6.28
	IronUi.animate(holder, function(t)
		local glow = 0.5 + 0.5 * math.sin(t * speed + offset)
		for _, bar in bars do
			bar.BackgroundTransparency = 0.1 + 0.75 * (1 - glow)
		end
	end)
end

-- A four-point sparkle that blooms and fades (the video's glints).
local function sparkle(x: number, y: number, size: number)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(x, y)
	holder.Size = UDim2.fromScale(size, size)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	holder.Parent = stage
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	for _, dims in { { 1, 0.12 }, { 0.12, 1 } } do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(dims[1], dims[2])
		ray.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
		ray.BorderSizePixel = 0
		ray.ZIndex = 6
		ray.Parent = holder
		local fade = Instance.new("UIGradient")
		fade.Rotation = if dims[1] > dims[2] then 0 else 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
	end
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.22, 0.22)
	core.Rotation = 45
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BorderSizePixel = 0
	core.ZIndex = 6
	core.Parent = holder
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.35, function()
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
			:Play()
		task.wait(0.35)
		holder:Destroy()
	end)
end

-- A shooting star streaking down to the left, top right of the sky.
local function shootingStar()
	local streak = Instance.new("Frame")
	streak.AnchorPoint = Vector2.new(1, 0.5)
	streak.Size = UDim2.fromScale(0.11, 0.004)
	streak.Rotation = -40
	streak.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
	streak.BorderSizePixel = 0
	streak.ZIndex = 2
	streak.Position = UDim2.fromScale(0.97, 0.16)
	streak.Parent = stage
	local tail = Instance.new("UIGradient")
	tail.Transparency = NumberSequence.new(1, 0)
	tail.Parent = streak
	local move = TweenService:Create(streak, TweenInfo.new(0.55, Enum.EasingStyle.Linear), {
		Position = UDim2.fromScale(0.84, 0.29),
		BackgroundTransparency = 1,
	})
	move.Completed:Connect(function()
		streak:Destroy()
	end)
	move:Play()
end

-- Build the picture (behind the veil), then the stars, the edge blend and
-- more stars in the margins for wide screens.
layer("Sky", Art.Background, 0, 0, 1)
local logo = layer("Logo", Art.Logo, Art.Logo.Origin[1], Art.Logo.Origin[2], 4)
for _, s in Art.Stars do
	star(stage, s[1], s[2], s[3], hex(s[4]), 3)
end
for side = 0, 1 do
	local edge = Instance.new("Frame")
	edge.AnchorPoint = Vector2.new(side, 0)
	edge.Position = UDim2.fromScale(side, 0)
	edge.Size = UDim2.fromScale(0.14, 1)
	edge.BackgroundColor3 = BACKGROUND
	edge.BorderSizePixel = 0
	-- Over the sky, under the stars and the logo (whose wings reach the edges).
	edge.ZIndex = 2
	edge.Parent = stage
	local blend = Instance.new("UIGradient")
	blend.Transparency = NumberSequence.new(side, 1 - side)
	blend.Parent = edge
end
do
	local rng = Random.new(7)
	for _ = 1, 60 do
		local x = if rng:NextNumber() < 0.5 then rng:NextNumber(0.01, 0.2) else rng:NextNumber(0.8, 0.99)
		star(back, x, rng:NextNumber(0.02, 0.98), rng:NextInteger(2, 3), Color3.fromRGB(120, 210, 230), 1)
	end
end

-- The logo's loop: the shine sweeps across, sparkles glint, a star shoots.
-- Logo pieces are bucketed along the diagonal so a sweep only touches the
-- pieces it's passing over.
local BUCKETS = 80
local buckets = {}
for _, piece in logo do
	local b = math.clamp(math.floor(piece.D * BUCKETS), 0, BUCKETS - 1)
	buckets[b] = buckets[b] or {}
	table.insert(buckets[b], piece)
end
local lit: { [number]: number } = {}
local WHITE = Color3.new(1, 1, 1)
local function shine(position: number?)
	-- position: the band's centre along the diagonal, or nil to clear it.
	local want = {}
	if position then
		for b = 0, BUCKETS - 1 do
			local d = math.abs((b + 0.5) / BUCKETS - position)
			if d < 0.07 then
				want[b] = math.floor((1 - d / 0.07) * 8 + 0.5) / 8 * 0.85
			end
		end
	end
	for b = 0, BUCKETS - 1 do
		local amount = want[b] or 0
		if (lit[b] or 0) ~= amount and buckets[b] then
			for _, piece in buckets[b] do
				piece.Frame.BackgroundColor3 = piece.Base:Lerp(WHITE, amount)
			end
			lit[b] = if amount > 0 then amount else nil
		end
	end
end

local phase = "Intro" -- Intro, Title, Done
local cycleStart = os.clock() + DROP
local nextEvent = 1
local EVENTS = {
	{
		0.45,
		function()
			sparkle(0.1, 0.49, 0.07)
		end,
	},
	{ 2.35, shootingStar },
	{
		3.0,
		function()
			sparkle(0.9, 0.38, 0.05)
		end,
	},
	{
		3.5,
		function()
			sparkle(0.6, 0.66, 0.04)
		end,
	},
}
RunService.Heartbeat:Connect(function()
	if phase == "Done" then
		return
	end
	local t = os.clock() - cycleStart
	if t < 0 then
		return
	end
	local inCycle = t % CYCLE
	if inCycle < 1.4 then
		shine(-0.15 + inCycle / 1.4 * 1.3)
	else
		shine(nil)
	end
	-- Timed glints, once per cycle.
	local event = EVENTS[nextEvent]
	if event and inCycle >= event[1] then
		event[2]()
		nextEvent += 1
	elseif inCycle < EVENTS[1][1] and nextEvent > #EVENTS then
		nextEvent = 1
	end
end)

local introSound: Sound? = nil
local titleMusic: Sound? = nil
local function sound(id: number?, volume: number): Sound?
	if not id or id == 0 then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = volume
	s.Parent = gui
	return s
end

-- The title: the logo stays, the song carries on, CLICK TO ENTER blinks.
local function showTitle(fromSkip: boolean)
	if phase ~= "Intro" then
		return
	end
	phase = "Title"
	TweenService:Create(veil, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	if introSound then
		TweenService:Create(introSound, TweenInfo.new(0.3), { Volume = 0 }):Play()
	end
	titleMusic = sound(Music.Ids.Fight, if fromSkip then 0 else 0.5)
	if titleMusic then
		titleMusic.Looped = true
		titleMusic.TimePosition = if fromSkip then 0 else TITLE_LOOP_FROM
		titleMusic:Play()
		if fromSkip then
			TweenService:Create(titleMusic, TweenInfo.new(1.2), { Volume = 0.5 }):Play()
		end
	end
	local prompt = Instance.new("TextLabel")
	prompt.AnchorPoint = Vector2.new(0.5, 0)
	prompt.Position = UDim2.fromScale(0.5, 0.76)
	prompt.Size = UDim2.fromOffset(600, 40)
	prompt.BackgroundTransparency = 1
	prompt.Font = Enum.Font.Arcade
	prompt.TextSize = 34
	prompt.TextColor3 = GOLD
	prompt.TextStrokeColor3 = Color3.fromRGB(59, 27, 109)
	prompt.TextStrokeTransparency = 0
	prompt.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "TAP TO ENTER"
		else "CLICK TO ENTER"
	prompt.ZIndex = 9
	prompt.Parent = back
	IronUi.animate(prompt, function(t)
		-- A classic arcade blink: a soft pulse with a hard off-beat.
		local pulse = 0.5 + 0.5 * math.sin(t * 4)
		prompt.TextTransparency = if pulse < 0.12 then 1 else 0.25 * (1 - pulse)
	end)
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.76, 46)
	hint.Size = UDim2.fromOffset(600, 20)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(170, 176, 210)
	hint.Text = "or press any key"
	hint.ZIndex = 9
	hint.Parent = back
	local credit = Instance.new("TextLabel")
	credit.AnchorPoint = Vector2.new(0.5, 1)
	credit.Position = UDim2.new(0.5, 0, 1, -18)
	credit.Size = UDim2.fromOffset(600, 16)
	credit.BackgroundTransparency = 1
	credit.Font = Enum.Font.Gotham
	credit.TextSize = 12
	credit.TextColor3 = Color3.fromRGB(110, 114, 150)
	credit.Text = "© SAGA MINERS"
	credit.ZIndex = 9
	credit.Parent = back
end

local function enter()
	if phase ~= "Title" then
		return
	end
	phase = "Done"
	if titleMusic then
		TweenService:Create(titleMusic, TweenInfo.new(0.6), { Volume = 0 }):Play()
	end
	local fade = TweenService:Create(back, TweenInfo.new(0.6), { GroupTransparency = 1 })
	fade.Completed:Connect(function()
		gui:Destroy()
	end)
	fade:Play()
end

-- Clicks, taps and keys: skip the intro, then enter.
UserInputService.InputBegan:Connect(function(input)
	if phase == "Done" then
		return
	end
	local t = input.UserInputType
	if
		t == Enum.UserInputType.Keyboard
		or t == Enum.UserInputType.MouseButton1
		or t == Enum.UserInputType.Touch
		or t == Enum.UserInputType.Gamepad1
	then
		if phase == "Intro" then
			showTitle(true)
		else
			enter()
		end
	end
end)

-- The intro: the logo rises out of the dark over the build; the drop
-- flashes white and starts the logo's loop.
if phase == "Intro" then
	introSound = sound(Music.Ids.Intro, 0.8)
	if introSound then
		introSound:Play()
	end
	cycleStart = os.clock() + DROP
	TweenService:Create(veil, TweenInfo.new(DROP * 0.9, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 9
	flash.Parent = back
	task.delay(DROP, function()
		if phase ~= "Intro" then
			return
		end
		flash.BackgroundTransparency = 0.35
		TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	end)
	task.delay(LENGTH, function()
		showTitle(false)
	end)
end
