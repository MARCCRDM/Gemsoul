--[[
	The basics, on a giant LED screen in the arena: a new miner's first
	fight opens on a lesson (Client FirstFight, once the fight's in view),
	five of the narrator's lines (Modules.Narration: BasicsAttack,
	BasicsBlock, BasicsAbilities, BasicsDodge, BasicsResources, ending on
	"Your training begins now."), each shown on the screen as it's read
	(Shared.Led.basics, timed off the voice itself: Narration.elapsed and
	the line's Cues). The screen is this player's alone (built here, not by
	the server): it rises up just past their sparring partner, facing them,
	so it's in front of them wherever the fight put them, and sinks away
	when the lesson's done.

	While it plays the partner holds still ("BasicsLesson": Server.Duelist
	reads the player's Lesson attribute); the moment they land a hit on it
	the hold lets go (they're ready), the lesson carrying on. No music under
	it (the player attribute IntroVideo: Client Music), the music once it's
	over.

	A SKIP button (over the caption) cuts the line being read and goes on to
	the next one; on the last, it ends the lesson.

	  BasicsScreen.run(onLine?)   plays it through (yields); `onLine(name)`
	                              as each line starts (FirstFight's arrows)
	  BasicsScreen.Size, .Past, .Lift   the screen's size and where it stands
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Led = require(ReplicatedStorage.Shared.Led)
local GemClient = require(script.Parent.GemClient)
local Narration = require(script.Parent.Narration)
local UiKit = require(script.Parent.UiKit)

local BasicsScreen = {}
BasicsScreen.Size = Vector2.new(36, 15) -- studs (the LEDs' 72 x 30)
BasicsScreen.Past = 18 -- studs beyond the partner
BasicsScreen.Lift = 10 -- studs over the partner's feet, its middle
BasicsScreen.Fps = 20
BasicsScreen.Dot = 0.72

local player = Players.LocalPlayer
local OFF = Color3.fromRGB(22, 25, 34)

local function color(rgb: number?): Color3
	if not rgb then
		return OFF
	end
	return Color3.fromRGB(rgb // 65536 % 256, rgb // 256 % 256, rgb % 256)
end

-- The sparring partner (a rival's model, or a matched first fight's other
-- player): the same as FirstFight's.
local function partner(): Model?
	local folder = workspace:FindFirstChild("Enemies")
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("RivalOwner") == player.UserId then
			return model
		end
	end
	local mine = player:GetAttribute("MatchId")
	if mine then
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute("MatchId") == mine and other.Character then
				return other.Character
			end
		end
	end
	return nil
end

-- Where the screen stands: past the partner, on the line from you to it,
-- raised, its face to you. (No partner: straight ahead of the camera.)
local function spot(): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local from = root.Position
	local other = partner()
	local to
	if other then
		to = other:GetPivot().Position
	else
		local look = (workspace.CurrentCamera :: Camera).CFrame.LookVector
		to = from + Vector3.new(look.X, 0, look.Z).Unit * 18
	end
	local way = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if way.Magnitude < 0.1 then
		way = Vector3.new(0, 0, -1)
	end
	way = way.Unit
	local at = to + way * BasicsScreen.Past + Vector3.new(0, BasicsScreen.Lift, 0)
	return CFrame.lookAt(at, from + Vector3.new(0, BasicsScreen.Lift * 0.6, 0))
end

-- The screen: a dark slab with a gold rim, a SurfaceGui of dots on its face.
local function build(at: CFrame)
	local model = Instance.new("Model")
	model.Name = "BasicsScreen"
	local size = BasicsScreen.Size
	local panel = Instance.new("Part")
	panel.Name = "Panel"
	panel.Anchored, panel.CanCollide, panel.CanQuery, panel.CanTouch, panel.CastShadow = true, false, false, false, false
	panel.Size = Vector3.new(size.X, size.Y, 0.4)
	panel.CFrame = at
	panel.Color = Color3.fromRGB(8, 10, 16)
	panel.Material = Enum.Material.SmoothPlastic
	panel.Parent = model
	for _, edge in { { 0, size.Y / 2 + 0.2, size.X + 0.8, 0.4 }, { 0, -size.Y / 2 - 0.2, size.X + 0.8, 0.4 }, { size.X / 2 + 0.2, 0, 0.4, size.Y }, { -size.X / 2 - 0.2, 0, 0.4, size.Y } } do
		local rim = Instance.new("Part")
		rim.Anchored, rim.CanCollide, rim.CanQuery, rim.CanTouch, rim.CastShadow = true, false, false, false, false
		rim.Size = Vector3.new(edge[3], edge[4], 0.5)
		rim.CFrame = at * CFrame.new(edge[1], edge[2], 0)
		rim.Color = Color3.fromRGB(255, 202, 91)
		rim.Material = Enum.Material.Neon
		rim.Parent = model
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LedGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Brightness = 1.6
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
	return { Model = model, Dots = dots, Shown = {} }
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

-- The screen rising up out of the ground (or sinking back, `away`).
local function rise(screen, at: CFrame, away: boolean)
	local parts = {}
	for _, p in screen.Model:GetChildren() do
		if p:IsA("BasePart") then
			parts[p] = at:ToObjectSpace(p.CFrame)
		end
	end
	local drop = CFrame.new(0, -BasicsScreen.Lift - BasicsScreen.Size.Y, 0)
	local start = os.clock()
	local seconds = 0.8
	while os.clock() - start < seconds do
		local k = (os.clock() - start) / seconds
		k = if away then k * k else 1 - (1 - k) ^ 3
		local base = if away then at:Lerp(at * drop, k) else (at * drop):Lerp(at, k)
		for p, offset in parts do
			p.CFrame = base * offset
		end
		RunService.RenderStepped:Wait()
	end
	for p, offset in parts do
		p.CFrame = (if away then at * drop else at) * offset
	end
end

-- SKIP: over the narrator's caption, centred (clear of the HUD's buttons).
local function skipButton(onSkip: () -> ()): ScreenGui
	local gui = UiKit.gui("BasicsSkip", 31)
	local button = Instance.new("TextButton")
	button.Name = "Skip"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -224)
	button.Size = UDim2.fromOffset(132, 40)
	button.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
	button.BackgroundTransparency = 0.2
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(255, 202, 91)
	button.Text = "SKIP  \u{203A}"
	button.Parent = gui
	UiKit.round(button, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 202, 91)
	stroke.Transparency = 0.4
	stroke.Thickness = 1.5
	stroke.Parent = button
	button.Activated:Connect(onSkip)
	return gui
end

local running = false

-- The lesson itself; what it put up goes in `state`, for run to take down
-- however it ends.
local function play(onLine: ((string) -> ())?, state)
	local at = spot()
	if not at then
		return
	end
	local screen = build(at)
	state.Model = screen.Model
	pcall(function()
		GemClient.request("BasicsLesson", true)
	end)
	-- (a hit on the partner: they're ready, it can fight back)
	local other = partner()
	local otherHumanoid = other and other:FindFirstChildOfClass("Humanoid")
	local startHealth = otherHumanoid and otherHumanoid.Health
	local held = true
	local function letGo()
		if held then
			held = false
			pcall(function()
				GemClient.request("BasicsLesson", false)
			end)
		end
	end
	state.LetGo = letGo
	rise(screen, at, false)
	local skipped = false
	state.SkipGui = skipButton(function()
		skipped = true
	end)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for _, name in Led.BasicsOrder do
		if player:GetAttribute("FirstFight") ~= true then
			break
		end
		if onLine then
			pcall(onLine, name)
		end
		local seconds = Narration.Seconds[name] or 8
		local scene = Led.basics(name, Narration.Cues[name] or { 0 }, seconds, touch)
		local voiced = Narration.play(name) > 0
		local started = os.clock()
		local last = -1
		skipped = false
		while player:GetAttribute("FirstFight") == true and not skipped do
			local t = if voiced then Narration.elapsed() else os.clock() - started
			if t >= seconds or os.clock() - started > seconds + 4 then
				break
			end
			local frame = math.floor(t * BasicsScreen.Fps)
			if frame ~= last then
				last = frame
				local ok, buffer = pcall(scene.Draw, frame / BasicsScreen.Fps)
				if ok then
					paint(screen, buffer)
				end
			end
			if held and otherHumanoid and startHealth and otherHumanoid.Health < startHealth - 0.5 then
				letGo()
			end
			RunService.RenderStepped:Wait()
		end
		if skipped then
			Narration.stop()
		else
			task.wait(0.35)
		end
	end
	state.SkipGui:Destroy()
	state.SkipGui = nil
	letGo()
	if onLine then
		pcall(onLine, nil)
	end
	task.wait(0.8)
	rise(screen, at, true)
end

function BasicsScreen.run(onLine: ((string) -> ())?)
	if running then
		return
	end
	running = true
	-- (no music under it: Client Music stays quiet while this is set)
	player:SetAttribute("IntroVideo", true)
	local state = {}
	local ok, problem = pcall(play, onLine, state)
	if not ok then
		warn("[BasicsScreen] the basics stopped:", problem)
		Narration.stop()
		if onLine then
			pcall(onLine, nil)
		end
	end
	-- Taken down however it ended: the partner let go, SKIP and the screen gone.
	if state.LetGo then
		state.LetGo()
	end
	if state.SkipGui then
		state.SkipGui:Destroy()
	end
	if state.Model then
		state.Model:Destroy()
	end
	player:SetAttribute("IntroVideo", nil)
	running = false
end

return BasicsScreen
