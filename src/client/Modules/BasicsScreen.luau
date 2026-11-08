--[[
	The combat basics, full screen: a new miner's very first screen
	(Client Intro plays it once the loading's done, then the ability roll,
	then the six intro rounds). The narrator's lines in Led.BasicsOrder
	(Modules.Narration: BasicsAttack, BasicsBlock, BasicsAbilities), each
	shown on a full-screen LED panel as it's read
	(Shared.Led.basics, timed off the voice itself: Narration.elapsed and the
	line's Cues), its words under it phrase by phrase (its own caption: the
	narrator's usual one sits too low, over the panel on a phone).

	A SKIP button cuts the line being read and goes on to the next one; on
	the last, it ends the video. No music under it (the player attribute
	IntroVideo: Client Music), the music once it's over.

	  BasicsScreen.run(ready?)   plays it through (yields); `ready`, if
	                       given, is waited on once the screen's up, before
	                       the first line (Intro: till the loading's done)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Led = require(ReplicatedStorage.Shared.Led)
local Narration = require(script.Parent.Narration)
local UiKit = require(script.Parent.UiKit)

local BasicsScreen = {}
BasicsScreen.Fps = 20
BasicsScreen.Dot = 0.72
BasicsScreen.Order = 29

local OFF = Color3.fromRGB(22, 25, 34)
local INK = Color3.fromRGB(5, 7, 12)
local GOLD = Color3.fromRGB(255, 202, 91)

local function color(rgb: number?): Color3
	if not rgb then
		return OFF
	end
	return Color3.fromRGB(rgb // 65536 % 256, rgb // 256 % 256, rgb % 256)
end

-- The screen: dark all over, the LED panel in the upper middle (gold rim),
-- the words under it, SKIP in the bottom right corner.
local function build(onSkip: () -> ())
	local gui = UiKit.gui("BasicsVideo", BasicsScreen.Order)
	gui.IgnoreGuiInset = true
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = INK
	back.BorderSizePixel = 0
	back.Parent = gui
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.42)
	panel.Size = UDim2.fromScale(0.6, 0.44) -- (room round it: not right up in your face, clear of the screen's edge buttons)
	panel.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	panel.BorderSizePixel = 0
	panel.Parent = back
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = Led.W / Led.H
	aspect.Parent = panel
	UiKit.round(panel, 6)
	local rim = Instance.new("UIStroke")
	rim.Color = GOLD
	rim.Thickness = 3
	rim.Parent = panel
	-- (the LEDs inset a little from the rim)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(0.95, 0.9)
	face.BackgroundTransparency = 1
	face.Parent = panel
	local dots = {}
	local w, h = Led.W, Led.H
	local dotSize = UDim2.fromScale(BasicsScreen.Dot / w, BasicsScreen.Dot / h)
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local dot = Instance.new("Frame")
			dot.BorderSizePixel = 0
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromScale((x + 0.5) / w, (y + 0.5) / h)
			dot.Size = dotSize
			dot.BackgroundColor3 = OFF
			dot.Parent = face
			dots[y * w + x + 1] = dot
		end
	end
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.AnchorPoint = Vector2.new(0.5, 0)
	words.Position = UDim2.fromScale(0.5, 0.71)
	words.Size = UDim2.fromScale(0.6, 0.08)
	words.BackgroundTransparency = 1
	words.Font = Enum.Font.GothamBold
	words.TextColor3 = Color3.fromRGB(240, 244, 250)
	words.TextScaled = true
	words.TextWrapped = true
	words.Text = ""
	words.Parent = back
	local most = Instance.new("UITextSizeConstraint")
	most.MaxTextSize = 26
	most.Parent = words
	local button = Instance.new("TextButton")
	button.Name = "Skip"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -20, 1, -20)
	button.Size = UDim2.fromOffset(132, 40)
	button.BackgroundColor3 = Color3.fromRGB(14, 17, 26)
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = GOLD
	button.Text = "SKIP  \u{203A}"
	button.Parent = back
	UiKit.round(button, 8)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Transparency = 0.4
	edge.Thickness = 1.5
	edge.Parent = button
	button.Activated:Connect(onSkip)
	return { Gui = gui, Back = back, Dots = dots, Shown = {}, Words = words }
end

-- One frame on the screen (only the dots that change).
local function paint(screen, frame)
	for i, dot in screen.Dots do
		local want = frame and frame.P[i]
		if screen.Shown[i] ~= want then
			screen.Shown[i] = want
			dot.BackgroundColor3 = color(want)
		end
	end
end

local running = false

local function play(state, ready: (() -> ())?)
	local skipped = false
	local screen = build(function()
		skipped = true
	end)
	state.Gui = screen.Gui
	if ready then
		pcall(ready)
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for _, name in Led.BasicsOrder do
		local seconds = Narration.Seconds[name] or 8
		local scene = Led.basics(name, Narration.Cues[name] or { 0 }, seconds, touch)
		local voiced = Narration.play(name, true) > 0
		local phrases = Narration.Phrases[name] or { Narration.Lines[name] or "" }
		local cues = Narration.Cues[name] or { 0 }
		local started = os.clock()
		local last = -1
		skipped = false
		while not skipped do
			local t = if voiced then Narration.elapsed() else os.clock() - started
			if t >= seconds or os.clock() - started > seconds + 4 then
				break
			end
			local at = 1
			for i, start in cues do
				if t >= start - 0.05 and phrases[i] then
					at = i
				end
			end
			screen.Words.Text = phrases[at] or ""
			local frame = math.floor(t * BasicsScreen.Fps)
			if frame ~= last then
				last = frame
				local ok, buffer = pcall(scene.Draw, frame / BasicsScreen.Fps)
				if ok then
					paint(screen, buffer)
				end
			end
			RunService.RenderStepped:Wait()
		end
		if skipped then
			Narration.stop()
		else
			task.wait(0.35)
		end
	end
	-- Out: a fade to the dark, then gone.
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = INK
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 50
	fade.Parent = screen.Back
	local tween = TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 0 })
	tween:Play()
	tween.Completed:Wait()
end

function BasicsScreen.run(ready: (() -> ())?)
	if running then
		return
	end
	running = true
	local player = game:GetService("Players").LocalPlayer
	player:SetAttribute("IntroVideo", true)
	local state = {}
	local ok, problem = pcall(play, state, ready)
	if not ok then
		warn("[BasicsScreen] the basics stopped:", problem)
		Narration.stop()
	end
	-- (gone however it ended)
	if state.Gui then
		state.Gui:Destroy()
	end
	player:SetAttribute("IntroVideo", nil)
	running = false
end

return BasicsScreen
