--[[
	The splash intro on joining: the animated SAGA MINERS logo set to the
	theme song's final drop (tools/make_intro.py builds both). Click, tap or
	press any key to skip. Everything else (the launch intro, the dashboard,
	the background music) waits for it to finish.

	Plays assets/video/saga_intro.mp4 once it's uploaded (Creator Hub, Video:
	put the id in VIDEO_ID). Until then a drawn logo plays to the same music
	(Music.Ids.Intro, from tools/upload_audio.py), or silently.
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local IronUi = require(script.Parent.Modules.IronUi)
local Music = require(script.Parent.Modules.Music)

local VIDEO_ID = 0 -- saga_intro.mp4 (Creator Hub > Video)
local LENGTH = 9.9 -- seconds: six bars of the song
local DROP = 1.66 -- the drop lands one bar in
local BACKGROUND = Color3.fromRGB(10, 8, 25) -- the video's own deep-space colour

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

local finished = false
local cleanup: { () -> () } = {}
local function finish()
	if finished then
		return
	end
	finished = true
	for _, stop in cleanup do
		pcall(stop)
	end
	local fade = TweenService:Create(back, TweenInfo.new(0.45), { GroupTransparency = 1 })
	fade.Completed:Connect(function()
		gui:Destroy()
	end)
	fade:Play()
end

-- Skip: a hint in the corner, and any click, tap or key.
local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -24, 1, -22)
skip.Size = UDim2.fromOffset(110, 34)
skip.BackgroundColor3 = Color3.fromRGB(24, 20, 48)
skip.BackgroundTransparency = 0.2
skip.Text = "SKIP  ▸"
skip.Font = Enum.Font.GothamBold
skip.TextSize = 14
skip.TextColor3 = Color3.fromRGB(220, 226, 240)
skip.TextTransparency = 1
skip.ZIndex = 10
skip.Parent = back
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = skip
skip.Activated:Connect(finish)
task.delay(0.8, function()
	if not finished then
		TweenService:Create(skip, TweenInfo.new(0.3), { TextTransparency = 0.15 }):Play()
	end
end)
local inputConnection = UserInputService.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if
		t == Enum.UserInputType.Keyboard
		or t == Enum.UserInputType.MouseButton1
		or t == Enum.UserInputType.Touch
		or t == Enum.UserInputType.Gamepad1
	then
		finish()
	end
end)
table.insert(cleanup, function()
	inputConnection:Disconnect()
end)

local function playVideo(): boolean
	local video = Instance.new("VideoFrame")
	video.AnchorPoint = Vector2.new(0.5, 0.5)
	video.Position = UDim2.fromScale(0.5, 0.5)
	video.Size = UDim2.fromScale(1, 1)
	video.BackgroundTransparency = 1
	video.Video = "rbxassetid://" .. VIDEO_ID
	video.Volume = 0.8
	video.Looped = false
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.Parent = video
	video.Parent = back
	-- Give it a few seconds to load; if it can't, fall back to the drawn logo.
	local loaded = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, { video })
		loaded = true
	end)
	local deadline = os.clock() + 4
	while not loaded and os.clock() < deadline and not finished do
		task.wait(0.05)
	end
	if finished then
		video:Destroy()
		return true
	end
	if not video.IsLoaded then
		video:Destroy()
		return false
	end
	table.insert(cleanup, function()
		video:Pause()
	end)
	video:Play()
	video.Ended:Connect(finish)
	task.delay(LENGTH + 1, finish)
	return true
end

-- The fallback: the drawn wordmark rising out of the dark, flashing on the drop.
local function playDrawn()
	local holder = Instance.new("CanvasGroup")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(340, 48)
	holder.BackgroundTransparency = 1
	holder.GroupTransparency = 1
	holder.Parent = back
	local mark = IronUi.wordmark(holder)
	mark.Position = UDim2.fromOffset(5, 2)
	local scale = Instance.new("UIScale")
	scale.Scale = 2.2
	scale.Parent = holder
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = back
	local id = Music.Ids.Intro
	if id and id ~= 0 then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. id
		sound.Volume = 0.8
		sound.Parent = gui
		sound:Play()
		table.insert(cleanup, function()
			TweenService:Create(sound, TweenInfo.new(0.4), { Volume = 0 }):Play()
		end)
	end
	TweenService:Create(holder, TweenInfo.new(DROP * 0.85, Enum.EasingStyle.Sine), { GroupTransparency = 0 }):Play()
	task.delay(DROP, function()
		if finished then
			return
		end
		flash.BackgroundTransparency = 0.35
		TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		scale.Scale = 2.5
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 2.3 }):Play()
	end)
	task.delay(LENGTH, finish)
end

if VIDEO_ID == 0 or not playVideo() then
	if not finished then
		playDrawn()
	end
end
