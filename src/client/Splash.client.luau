--[[
	The title screen on joining, classic style, built on the SAGA MINERS
	title art (assets/images/saga_title.png):
	  1. the intro: the art zooms gently out of the dark over the theme
	     song's build; the drop hits with a white flash and a punch;
	  2. the title: the art floats gently, a glint sweeps across it now and
	     then, stars twinkle around it, the song carries on from the drop, and
	     "CLICK TO ENTER" blinks until you click, tap or press a key.
	A click during the intro jumps straight to the title. Everything else
	(the launch intro, the dashboard, the background music) waits until you
	enter.

	Upload assets/images/saga_title.png in Creator Hub (Images or Decals) and
	put its id in IMAGE_ID. Until then the drawn wordmark stands in. The
	music is Music.Ids.Intro (the build and drop) then Music.Ids.Fight.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local IronUi = require(script.Parent.Modules.IronUi)
local Music = require(script.Parent.Modules.Music)

local IMAGE_ID = 123729911771910 -- saga_title.png
local LENGTH = 9.9 -- seconds of intro: six bars of the song
local BAR = 4 * 60 / 144.94
local DROP = BAR -- the drop lands one bar in
-- The title loop is fight_theme (bars 81-97); the intro ends at bar 86.
local TITLE_LOOP_FROM = 5 * BAR
local BACKGROUND = Color3.fromRGB(12, 11, 23) -- the art's own edge colour
local GOLD = Color3.fromRGB(255, 202, 91)

local player = Players.LocalPlayer
-- Phones and tablets play sideways: landscape either way up, never portrait.
pcall(function()
	(player:WaitForChild("PlayerGui") :: PlayerGui).ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)
pcall(function()
	game:GetService("StarterGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)
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
gui.Parent = player:WaitForChild("PlayerGui")

-- The art: a square as big as fits the screen, in the middle.
local stage = Instance.new("Frame")
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.Position = UDim2.fromScale(0.5, 0.5)
stage.BackgroundTransparency = 1
stage.ClipsDescendants = true
stage.ZIndex = 2
stage.Parent = back
local function fit()
	local screen = gui.AbsoluteSize
	local side = math.min(screen.X, screen.Y)
	stage.Size = UDim2.fromOffset(if side > 0 then side else 600, if side > 0 then side else 600)
end
fit()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

local art: GuiObject
if IMAGE_ID ~= 0 then
	local image = Instance.new("ImageLabel")
	image.Image = "rbxassetid://" .. IMAGE_ID
	image.ResampleMode = Enum.ResamplerMode.Pixelated -- keep the pixel art crisp
	image.BackgroundTransparency = 1
	art = image
else
	-- Stand-in until the art is uploaded.
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	local mark = IronUi.wordmark(holder)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	local markScale = Instance.new("UIScale")
	markScale.Scale = 2.2
	markScale.Parent = mark
	art = holder
end
art.AnchorPoint = Vector2.new(0.5, 0.5)
art.Position = UDim2.fromScale(0.5, 0.5)
art.Size = UDim2.fromScale(1, 1)
art.ZIndex = 2
art.Parent = stage
local zoom = Instance.new("UIScale")
zoom.Scale = 1.12
zoom.Parent = art

-- The square's sides fade into the backdrop on wide screens.
for side = 0, 1 do
	local edge = Instance.new("Frame")
	edge.AnchorPoint = Vector2.new(side, 0)
	edge.Position = UDim2.fromScale(side, 0)
	edge.Size = UDim2.fromScale(0.06, 1)
	edge.BackgroundColor3 = BACKGROUND
	edge.BorderSizePixel = 0
	edge.ZIndex = 3
	edge.Parent = stage
	local blend = Instance.new("UIGradient")
	blend.Transparency = NumberSequence.new(side, 1 - side)
	blend.Parent = edge
end

-- The glint: a soft diagonal band of light sweeping across the art.
local glint = Instance.new("Frame")
glint.AnchorPoint = Vector2.new(0.5, 0.5)
glint.Size = UDim2.fromScale(0.16, 1.8)
glint.Rotation = 20
glint.Position = UDim2.fromScale(-0.3, 0.5)
glint.BackgroundColor3 = Color3.fromRGB(255, 246, 220)
glint.BackgroundTransparency = 0.72
glint.BorderSizePixel = 0
glint.ZIndex = 4
glint.Parent = stage
local soft = Instance.new("UIGradient")
soft.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1),
})
soft.Parent = glint

-- Stars twinkling around the art (and a few over it).
do
	local rng = Random.new(7)
	for i = 1, 70 do
		local x = if i <= 12
			then rng:NextNumber(0.25, 0.75)
			elseif rng:NextNumber() < 0.5 then rng:NextNumber(0.01, 0.22)
			else rng:NextNumber(0.78, 0.99)
		local starFrame = Instance.new("Frame")
		local size = rng:NextInteger(2, 4)
		starFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		starFrame.Position = UDim2.fromScale(x, rng:NextNumber(0.02, 0.98))
		starFrame.Size = UDim2.fromOffset(size, size)
		starFrame.BackgroundColor3 = if rng:NextNumber() < 0.5
			then Color3.fromRGB(120, 220, 235)
			else Color3.new(1, 1, 1)
		starFrame.BorderSizePixel = 0
		starFrame.ZIndex = if i <= 12 then 5 else 1
		starFrame.Parent = back
		local speed, offset = rng:NextNumber(0.7, 2.4), rng:NextNumber(0, 6.28)
		IronUi.animate(starFrame, function(t)
			starFrame.BackgroundTransparency = 0.4 + 0.55 * (0.5 + 0.5 * math.sin(t * speed + offset))
		end)
	end
end

-- Darkness over everything, lifting as the build rises; a flash on the drop.
local veil = Instance.new("Frame")
veil.Size = UDim2.fromScale(1, 1)
veil.BackgroundColor3 = BACKGROUND
veil.BorderSizePixel = 0
veil.ZIndex = 8
veil.Parent = back
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 9
flash.Parent = back

local phase = "Intro" -- Intro, Title, Done
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

-- The loop once the drop has hit: a slow float and a glint every few seconds.
local looping = false
local function startLoop()
	if looping then
		return
	end
	looping = true
	-- A slow float, like it's drifting in space.
	IronUi.animate(art, function(t)
		art.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 1.1) * 4)
	end)
	task.spawn(function()
		while phase ~= "Done" and gui.Parent do
			glint.Position = UDim2.fromScale(-0.3, 0.5)
			TweenService:Create(glint, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(1.3, 0.5),
			}):Play()
			task.wait(4.5)
		end
	end)
end

-- The drop: flash, a punch of the art, and the loop begins.
local function drop()
	flash.BackgroundTransparency = 0.3
	TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	zoom.Scale = 1.06
	TweenService:Create(zoom, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	startLoop()
end

-- The title: the art stays, the song carries on, CLICK TO ENTER blinks.
local function showTitle(fromSkip: boolean)
	if phase ~= "Intro" then
		return
	end
	phase = "Title"
	TweenService:Create(veil, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	if fromSkip then
		TweenService:Create(zoom, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		startLoop()
	end
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
	prompt.Position = UDim2.fromScale(0.5, 0.8)
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
	prompt.ZIndex = 10
	prompt.Parent = back
	IronUi.animate(prompt, function(t)
		-- A classic arcade blink: a soft pulse with a hard off-beat.
		local pulse = 0.5 + 0.5 * math.sin(t * 4)
		prompt.TextTransparency = if pulse < 0.12 then 1 else 0.25 * (1 - pulse)
	end)
	local credit = Instance.new("TextLabel")
	credit.AnchorPoint = Vector2.new(0.5, 1)
	credit.Position = UDim2.new(0.5, 0, 1, -18)
	credit.Size = UDim2.fromOffset(600, 16)
	credit.BackgroundTransparency = 1
	credit.Font = Enum.Font.Gotham
	credit.TextSize = 12
	credit.TextColor3 = Color3.fromRGB(110, 114, 150)
	credit.Text = "© SAGA MINERS"
	credit.ZIndex = 10
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
	TweenService:Create(zoom, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1.15 })
		:Play()
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

-- The intro: out of the dark over the build, then the drop.
introSound = sound(Music.Ids.Intro, 0.8)
if introSound then
	introSound:Play()
end
TweenService:Create(veil, TweenInfo.new(DROP * 0.9, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
TweenService:Create(zoom, TweenInfo.new(DROP, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.02 }):Play()
task.delay(DROP, function()
	if phase == "Intro" then
		drop()
	end
end)
task.delay(LENGTH, function()
	showTitle(false)
end)
