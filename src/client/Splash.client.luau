--[[
	The title screen on joining, classic style:
	  1. the intro: the animated SAGA MINERS logo set to the theme song's
	     build and final drop (tools/make_intro.py builds the video);
	  2. the title: the logo holds, the song carries on from the drop, and
	     "CLICK TO ENTER" pulses until you click, tap or press a key.
	A click during the intro jumps straight to the title. Everything else
	(the launch intro, the dashboard, the background music) waits until you
	enter.

	Roblox only plays uploaded media. Upload assets/video/saga_intro.mp4 in
	Creator Hub (Video) and put its id in VIDEO_ID; tools/upload_audio.py
	uploads the music (Music.Ids.Intro for the drop on its own, Music.Ids.Fight
	for the title loop). Whatever isn't uploaded yet, a drawn logo or silence
	stands in, so the screen always works.
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local IronUi = require(script.Parent.Modules.IronUi)
local Music = require(script.Parent.Modules.Music)

local VIDEO_ID = 0 -- saga_intro.mp4 (Creator Hub > Video)
local LENGTH = 9.9 -- seconds: six bars of the song
local BAR = 4 * 60 / 144.94
local DROP = BAR -- the drop lands one bar in
-- The title loop is fight_theme (bars 81-97); the intro ends at bar 86.
local TITLE_LOOP_FROM = 5 * BAR
local BACKGROUND = Color3.fromRGB(10, 8, 25) -- the video's own deep-space colour
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
gui.Parent = player:WaitForChild("PlayerGui")

local phase = "Intro" -- Intro, Title, Done
local video: VideoFrame? = nil
local introSound: Sound? = nil
local titleMusic: Sound? = nil
local drawn: CanvasGroup? = nil

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

-- The drawn wordmark: the stand-in when there's no video.
local function drawnLogo(): CanvasGroup
	if drawn then
		return drawn
	end
	local holder = Instance.new("CanvasGroup")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.44)
	holder.Size = UDim2.fromOffset(340, 48)
	holder.BackgroundTransparency = 1
	holder.GroupTransparency = 1
	holder.Parent = back
	local mark = IronUi.wordmark(holder)
	mark.Position = UDim2.fromOffset(5, 2)
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 2.2
	scale.Parent = holder
	drawn = holder
	return holder
end

-- Twinkling stars in the margins, so the held title never looks frozen.
local function stars()
	local rng = Random.new(7)
	for _ = 1, 46 do
		local star = Instance.new("Frame")
		local size = rng:NextInteger(2, 4)
		star.Size = UDim2.fromOffset(size, size)
		star.Position = UDim2.fromScale(rng:NextNumber(0.02, 0.98), rng:NextNumber(0.03, 0.97))
		star.BackgroundColor3 = if rng:NextNumber() < 0.3 then Color3.fromRGB(150, 230, 255) else Color3.new(1, 1, 1)
		star.BorderSizePixel = 0
		star.BackgroundTransparency = rng:NextNumber(0.3, 0.9)
		star.Parent = back
		local speed, offset = rng:NextNumber(0.6, 2.2), rng:NextNumber(0, 6.28)
		IronUi.animate(star, function(t)
			star.BackgroundTransparency = 0.45 + 0.45 * math.sin(t * speed + offset)
		end)
	end
end

local enter -- forward

-- The title: hold the logo, keep the song going, ask to enter.
local function showTitle(fromSkip: boolean)
	if phase ~= "Intro" then
		return
	end
	phase = "Title"
	if video then
		if fromSkip then
			-- Jump to the clean logo at the end and hold it.
			video.TimePosition = LENGTH - 0.25
		end
		video:Pause()
	else
		local logo = drawnLogo()
		TweenService:Create(logo, TweenInfo.new(0.3), { GroupTransparency = 0 }):Play()
	end
	if introSound then
		TweenService:Create(introSound, TweenInfo.new(0.3), { Volume = 0 }):Play()
	end
	-- The song carries on from the drop (from the top of the loop after a skip).
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
	prompt.Position = UDim2.fromScale(0.5, 0.74)
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
	prompt.ZIndex = 4
	prompt.Parent = back
	IronUi.animate(prompt, function(t)
		-- A classic arcade blink: a soft pulse with a hard off-beat.
		local pulse = 0.5 + 0.5 * math.sin(t * 4)
		prompt.TextTransparency = if pulse < 0.12 then 1 else 0.25 * (1 - pulse)
	end)
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Size = UDim2.fromOffset(600, 20)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(170, 176, 210)
	hint.Text = "or press any key"
	hint.ZIndex = 4
	hint.Position = UDim2.new(0.5, 0, 0.74, 46)
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
	credit.ZIndex = 4
	credit.Parent = back
end

enter = function()
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

-- The intro: the video if it's uploaded and loads, else the drawn logo.
local function playVideo(): boolean
	local frame = Instance.new("VideoFrame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Video = "rbxassetid://" .. VIDEO_ID
	frame.Volume = 0.8
	frame.Looped = false
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.Parent = frame
	frame.Parent = back
	local loaded = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, { frame })
		loaded = true
	end)
	local deadline = os.clock() + 4
	while not loaded and os.clock() < deadline and phase == "Intro" do
		task.wait(0.05)
	end
	if phase ~= "Intro" then
		-- Skipped while it loaded: the drawn title is already up.
		frame:Destroy()
		return true
	end
	if not frame.IsLoaded then
		frame:Destroy()
		return false
	end
	video = frame
	frame:Play()
	-- Pause on the clean logo just before the end, and hold it as the title.
	local watch
	watch = RunService.Heartbeat:Connect(function()
		if phase ~= "Intro" then
			watch:Disconnect()
		elseif frame.TimePosition >= LENGTH - 0.2 then
			watch:Disconnect()
			showTitle(false)
		end
	end)
	frame.Ended:Connect(function()
		showTitle(false)
	end)
	return true
end

local function playDrawn()
	local logo = drawnLogo()
	local scale = logo:FindFirstChild("Scale") :: UIScale
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = back
	introSound = sound(Music.Ids.Intro, 0.8)
	if introSound then
		introSound:Play()
	end
	TweenService:Create(logo, TweenInfo.new(DROP * 0.85, Enum.EasingStyle.Sine), { GroupTransparency = 0 }):Play()
	task.delay(DROP, function()
		if phase ~= "Intro" then
			return
		end
		flash.BackgroundTransparency = 0.35
		TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		scale.Scale = 2.5
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 2.3 }):Play()
	end)
	task.delay(LENGTH, function()
		showTitle(false)
	end)
end

stars()
if VIDEO_ID == 0 or not playVideo() then
	if phase == "Intro" then
		playDrawn()
	end
end
