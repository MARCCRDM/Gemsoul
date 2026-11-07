--[[
	The basics, as a video of their own, in the Arena: a new miner's very
	first sight (Client Intro plays it before the element roll, then the
	roll, then the first fight). A giant LED screen rises in the Intro Ring
	(Shared.Outpost.Settlement.Stages), the camera on it from the ring's
	edge, and plays five of the narrator's lines (Modules.Narration:
	BasicsAttack, BasicsBlock, BasicsAbilities, BasicsDodge,
	BasicsResources), each shown as it's read (Shared.Led.basics, timed off
	the voice itself: Narration.elapsed and the line's Cues), its words
	under it phrase by phrase. The screen's built here, for this player
	only, and goes when it's over; the camera comes back to them.

	While it plays: letterboxed, the rest of the HUD put away, and no music
	(the player attribute IntroVideo: Client Music stays silent).

	A SKIP button cuts the line being read and goes on to the next one; on
	the last, it ends the video.

	  BasicsScreen.run(ready?)   plays it through (yields); `ready`, if
	                       given, is waited on before the first line (Intro:
	                       till the loading's done)
	  BasicsScreen.spot() -> (panel: CFrame, eye: CFrame)   where the screen
	                       stands and where the camera looks from
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Led = require(ReplicatedStorage.Shared.Led)
local Outpost = require(ReplicatedStorage.Shared.Outpost)
local Narration = require(script.Parent.Narration)
local UiKit = require(script.Parent.UiKit)

local BasicsScreen = {}
BasicsScreen.Ring = "IntroRing" -- (the ring it rises in)
BasicsScreen.Size = Vector2.new(48, 20) -- studs (the LEDs' 72 x 30)
BasicsScreen.Lift = 15 -- studs: the screen's middle over the ring's floor
BasicsScreen.Back = 6 -- studs: the screen behind the ring's middle
BasicsScreen.Eye = 8 -- studs: the camera's height over the floor
BasicsScreen.Far = 44 -- studs: the camera from the ring's middle (it drifts in from Far + Drift)
BasicsScreen.Drift = 10
BasicsScreen.Fps = 20
BasicsScreen.Dot = 0.72
BasicsScreen.Order = 29

local player = Players.LocalPlayer
local OFF = Color3.fromRGB(22, 25, 34)
local INK = Color3.fromRGB(0, 0, 0)
local GOLD = Color3.fromRGB(255, 202, 91)
local BIND = "BasicsVideoCamera"

local function color(rgb: number?): Color3
	if not rgb then
		return OFF
	end
	return Color3.fromRGB(rgb // 65536 % 256, rgb // 256 % 256, rgb % 256)
end

-- The ring's middle, on its floor (its model's Center: Server.PrivateArenas),
-- else where Arena Row puts it.
local function ringCenter(): Vector3
	local folder = workspace:FindFirstChild("PrivateArenas")
	local ring = folder and folder:FindFirstChild(BasicsScreen.Ring)
	local center = ring and ring:GetAttribute("Center")
	if typeof(center) == "Vector3" then
		return center
	end
	for _, stage in Outpost.Settlement.Stages do
		if stage.Name == BasicsScreen.Ring then
			return (Outpost.Location * CFrame.new(stage.X, 0.7, stage.Z)).Position
		end
	end
	return Outpost.Location.Position
end

function BasicsScreen.spot(): (CFrame, CFrame)
	local center = ringCenter()
	local at = center + Vector3.new(0, BasicsScreen.Lift, -BasicsScreen.Back)
	local panel = CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
	local eye = center + Vector3.new(0, BasicsScreen.Eye, BasicsScreen.Far)
	return panel, CFrame.lookAt(eye, at)
end

-- The screen in the ring: a dark slab, a gold rim, two legs down to the
-- floor, a SurfaceGui of dots on its face.
local function buildPanel(at: CFrame)
	local model = Instance.new("Model")
	model.Name = "BasicsScreen"
	local size = BasicsScreen.Size
	local function part(name, cframe, s, c, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = s
		p.CFrame = cframe
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local panel = part("Panel", at, Vector3.new(size.X, size.Y, 0.6), Color3.fromRGB(8, 10, 16))
	for _, edge in { { 0, size.Y / 2 + 0.3, size.X + 1.2, 0.6 }, { 0, -size.Y / 2 - 0.3, size.X + 1.2, 0.6 }, { size.X / 2 + 0.3, 0, 0.6, size.Y }, { -size.X / 2 - 0.3, 0, 0.6, size.Y } } do
		part("Rim", at * CFrame.new(edge[1], edge[2], 0), Vector3.new(edge[3], edge[4], 0.8), GOLD, Enum.Material.Neon)
	end
	local legHeight = BasicsScreen.Lift - size.Y / 2
	for _, x in { -size.X * 0.32, size.X * 0.32 } do
		part("Leg", at * CFrame.new(x, -size.Y / 2 - legHeight / 2, -0.6), Vector3.new(1.4, legHeight, 1.4), Color3.fromRGB(40, 44, 54), Enum.Material.Metal)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LedGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 1.8
	gui.Adornee = panel
	gui.Parent = panel
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = gui
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
			dot.Parent = back
			dots[y * w + x + 1] = dot
		end
	end
	model.Parent = workspace
	return model, dots
end

-- Over the view: the letterbox, the words, SKIP, and a black to fade
-- through.
local function buildOverlay(onSkip: () -> ())
	local gui = UiKit.gui("BasicsVideo", BasicsScreen.Order)
	gui.IgnoreGuiInset = true
	local function bar(anchorY: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0.1)
		f.BackgroundColor3 = INK
		f.BorderSizePixel = 0
		f.Parent = gui
	end
	bar(0)
	bar(1)
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.AnchorPoint = Vector2.new(0.5, 1)
	words.Position = UDim2.fromScale(0.5, 0.88)
	words.Size = UDim2.fromScale(0.6, 0.08) -- (clear of SKIP in the corner, on a phone too)
	words.BackgroundTransparency = 1
	words.Font = Enum.Font.GothamBold
	words.TextColor3 = Color3.fromRGB(240, 244, 250)
	words.TextStrokeColor3 = Color3.new(0, 0, 0)
	words.TextStrokeTransparency = 0.3
	words.TextScaled = true
	words.TextWrapped = true
	words.Text = ""
	words.Parent = gui
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
	button.ZIndex = 5
	button.Parent = gui
	UiKit.round(button, 8)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Transparency = 0.4
	edge.Thickness = 1.5
	edge.Parent = button
	button.Activated:Connect(onSkip)
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = INK
	black.BorderSizePixel = 0
	black.ZIndex = 10
	black.Parent = gui
	return gui, words, black
end

-- One frame on the screen (only the dots that change).
local function paint(dots, shown, frame)
	for i, dot in dots do
		local want = frame and frame.P[i]
		if shown[i] ~= want then
			shown[i] = want
			dot.BackgroundColor3 = color(want)
		end
	end
end

local function fade(black: Frame, to: number, seconds: number)
	local tween = TweenService:Create(black, TweenInfo.new(seconds), { BackgroundTransparency = to })
	tween:Play()
	tween.Completed:Wait()
end

-- The rest of the HUD away while it plays (each put back as it was).
local function hideHud(except: ScreenGui): { ScreenGui }
	local hidden = {}
	for _, screen in player.PlayerGui:GetChildren() do
		if screen:IsA("ScreenGui") and screen ~= except and screen.Enabled and screen.DisplayOrder < BasicsScreen.Order and screen.Name ~= "Narration" then
			screen.Enabled = false
			table.insert(hidden, screen)
		end
	end
	return hidden
end

local running = false

-- The video itself: the overlay (black) at once, then, once `ready` (the
-- loading done), the screen in the ring and the camera on it, the HUD away,
-- the lines. What it put up goes in `state`, for cleanUp.
local function play(state, ready: (() -> ())?)
	local skipped = false
	local overlay, words, black = buildOverlay(function()
		skipped = true
	end)
	state.Overlay = overlay
	-- (not before the loading's done: its covers wait for the camera to be
	-- back with you, so moving it first would hold them up)
	if ready then
		pcall(ready)
	end
	local at, eye = BasicsScreen.spot()
	pcall(function()
		player:RequestStreamAroundAsync(eye.Position, 5)
	end)
	local model, dots = buildPanel(at)
	state.Model = model
	local shown = {}
	-- The camera: on the screen from the ring's edge, drifting in.
	local camera = workspace.CurrentCamera :: Camera
	local started = os.clock()
	local target = at.Position
	state.Bound = true
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 20, function()
		local k = math.clamp((os.clock() - started) / 8, 0, 1)
		k = 1 - (1 - k) ^ 2
		local from = eye.Position + (eye.Position - target).Unit * BasicsScreen.Drift * (1 - k)
		local sway = Vector3.new(math.sin(os.clock() * 0.3) * 0.6, math.sin(os.clock() * 0.23) * 0.3, 0)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(from + sway, target + Vector3.new(0, -1.5, 0))
		camera.Focus = CFrame.new(target)
	end)
	state.Hidden = hideHud(overlay)
	fade(black, 1, 0.6)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for _, name in Led.BasicsOrder do
		local seconds = Narration.Seconds[name] or 8
		local scene = Led.basics(name, Narration.Cues[name] or { 0 }, seconds, touch)
		local voiced = Narration.play(name, true) > 0
		local phrases = Narration.Phrases[name] or { Narration.Lines[name] or "" }
		local cues = Narration.Cues[name] or { 0 }
		local lineStart = os.clock()
		local last = -1
		skipped = false
		while not skipped do
			local t = if voiced then Narration.elapsed() else os.clock() - lineStart
			if t >= seconds or os.clock() - lineStart > seconds + 4 then
				break
			end
			local phrase = 1
			for i, start in cues do
				if t >= start - 0.05 and phrases[i] then
					phrase = i
				end
			end
			words.Text = phrases[phrase] or ""
			local frame = math.floor(t * BasicsScreen.Fps)
			if frame ~= last then
				last = frame
				local ok, buffer = pcall(scene.Draw, frame / BasicsScreen.Fps)
				if ok then
					paint(dots, shown, buffer)
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
	-- Out: to black first (cleanUp then hands the camera back).
	words.Text = ""
	fade(black, 0, 0.5)
end

-- Everything back as it was, however the video ended (an error included:
-- never a camera left on the ring or the HUD left away).
local function cleanUp(state)
	if state.Bound then
		pcall(function()
			RunService:UnbindFromRenderStep(BIND)
		end)
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end
	if state.Model then
		state.Model:Destroy()
	end
	for _, screen in state.Hidden or {} do
		if screen.Parent then
			screen.Enabled = true
		end
	end
	if state.Overlay then
		state.Overlay:Destroy()
	end
end

function BasicsScreen.run(ready: (() -> ())?)
	if running then
		return
	end
	running = true
	player:SetAttribute("IntroVideo", true)
	local state = {}
	local ok, problem = pcall(play, state, ready)
	if not ok then
		warn("[BasicsScreen] the basics' video stopped:", problem)
	end
	cleanUp(state)
	player:SetAttribute("IntroVideo", nil)
	running = false
end

return BasicsScreen
