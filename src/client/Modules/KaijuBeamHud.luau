--[[
	The team's HYPERBEAM button (Server.KaijuBeamServer runs it; rules:
	Shared.KaijuBeam; the show: KaijuBeamFx). Shown with the kaiju strip
	(KaijuHud's) while your team's out, in mining and in fights alike: the
	bottom row of the kaiju card (KaijuHud.beamSlot()), under the team and
	its buttons.

	One bar, the row's width: it fills left to right in your team's
	colours (the team's charge, a meter of its own: KaijuCharge).

	  Charging   HYPERBEAM and its percent (CHARGING 42% on a computer).
	  Ready      the bar full and bright, its colours flowing, a glow that
	             breathes, a band of light sweeping across, READY! (and its
	             key on a computer: Z; on a pad, the d-pad's down). It pops
	             and chimes the moment it's ready.
	  Blasting   BLASTING! while the blast is under way.
	  SAVE       the switch at its end: on (green), your kaiju fight with
	             blows alone and charge faster (the server's KaijuSaveCharge).

	(Light to run: it redraws only when what it shows changes, and moves
	only while it's ready.)

	  KaijuBeamHud.start(slot)   once, from Lobby.client, with the card's
	                             row to draw in (KaijuHud.beamSlot())
	  KaijuBeamHud.aim() -> { X, Z }   where you're looking, flat (the
	                                   camera's look, else your facing)
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CombatSound = require(script.Parent.CombatSound)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local KaijuBeamHud = {}

local INK = Color3.fromRGB(9, 11, 22)
local WHITE = Color3.new(1, 1, 1)
local CHARGE = Color3.fromRGB(120, 196, 255) -- (a team with no colours yet)
local READY_GOLD = Color3.fromRGB(255, 226, 120)

local shownNow = false -- (with the kaiju card, while your team's out)

-- The bar: a glow behind, the charge filling it, its words and the SAVE
-- switch.
local button = new("TextButton", {
	Name = "Hyperbeam",
	AutoButtonColor = false,
	Text = "",
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.08,
	ZIndex = 3,
}, nil)
UiKit.round(button, 10)
local stroke = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.2 }, button)
local scale = new("UIScale", { Scale = 1 }, button)
local glow = new("Frame", {
	Name = "Glow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 14, 1, 14),
	BackgroundColor3 = READY_GOLD,
	BackgroundTransparency = 1,
	ZIndex = 2,
}, button)
UiKit.round(glow, 14)
local clip = new("Frame", {
	Name = "Track",
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 3,
}, button)
UiKit.round(clip, 10)
local fill = new("Frame", {
	Name = "Charge",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	ZIndex = 3,
}, clip)
local fillGradient = new("UIGradient", {}, fill)
local flash = new("Frame", {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	ZIndex = 9,
}, button)
UiKit.round(flash, 10)

local function words(name: string, font: Enum.Font, align: Enum.TextXAlignment): TextLabel
	local text = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Font = font,
		TextColor3 = P.Text,
		TextScaled = true,
		TextXAlignment = align,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0.55,
		ZIndex = 6,
	}, button)
	new("UITextSizeConstraint", { MinTextSize = 7, MaxTextSize = 15 }, text)
	return text
end
local title = words("Title", IronUi.Heading, Enum.TextXAlignment.Left)
title.Text = "HYPERBEAM"
local titleGradient = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, READY_GOLD),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(1, READY_GOLD),
	}),
	Enabled = false,
}, title)
local state = words("State", IronUi.Bold, Enum.TextXAlignment.Right)
local save = new("TextButton", {
	Name = "Save",
	AutoButtonColor = false,
	Text = "SAVE",
	Font = IronUi.Bold,
	TextColor3 = P.Dim,
	BackgroundColor3 = Color3.fromRGB(28, 32, 50),
	ZIndex = 8,
}, button)
UiKit.round(save, 6)
local saveStroke = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.3 }, save)
IronUi.juice(button, 1.03, 0.96)
IronUi.shine(button, 2.2)
local shineClip = button:FindFirstChild("ShineClip") :: Frame?

local busy = false
local wasReady = false
local compact = false -- (a phone's short row: shorter words)
local drawn = "" -- (what it shows now: redrawn only when that changes)
local paletteKey = ""

local function touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function layout()
	local size = button.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	-- HYPERBEAM on the left, its state on the right, SAVE at the end.
	compact = size.Y < 40
	local pad = if compact then 6 else 10
	local saveW, saveH = if compact then 32 else 46, if compact then 15 else 20
	save.Size = UDim2.fromOffset(saveW, saveH)
	save.Position = UDim2.new(1, -saveW - pad + 2, 0.5, -saveH / 2)
	save.TextSize = if compact then 8 else 10
	local textH = math.min(size.Y - 8, if compact then 14 else 18)
	local room = size.X - pad * 2 - saveW - 4
	local stateW = math.floor(room * (if compact then 0.38 else 0.45))
	title.Position = UDim2.new(0, pad, 0.5, -textH / 2)
	title.Size = UDim2.fromOffset(room - stateW - 4, textH)
	state.Position = UDim2.new(0, pad + room - stateW, 0.5, -textH / 2)
	state.Size = UDim2.fromOffset(stateW, textH)
	drawn = "" -- (its words change with its size)
end

-- Your kaiju out, in their slots' order: their element colours.
local function palette(): { Color3 }
	local folder = workspace:FindFirstChild("Kaiju")
	local list = {}
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("KaijuOwner") == player.UserId then
			table.insert(list, {
				Slot = model:GetAttribute("KaijuSlot") or 9,
				Color = GemConfig.ElementColors[model:GetAttribute("KaijuElement")] or CHARGE,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Slot < b.Slot
	end)
	local colors = {}
	for _, unit in list do
		table.insert(colors, unit.Color)
	end
	return if #colors > 0 then colors else { CHARGE }
end

-- A sequence of the team's colours, round (for the bar).
local function sequence(list: { Color3 }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(list[1], list[1]:Lerp(WHITE, 0.4))
	end
	local points = {}
	for i, color in list do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / #list, color))
	end
	table.insert(points, ColorSequenceKeypoint.new(1, list[1]))
	return ColorSequence.new(points)
end

local colors = { CHARGE }

local function pop()
	scale.Scale = 1.12
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	flash.BackgroundTransparency = 0.15
	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	CombatSound.play("Combo", nil, { Pitch = 0.75, Volume = 1.4 })
end

local function refresh()
	local hud = player.PlayerGui:FindFirstChild("KaijuHud")
	local charge = player:GetAttribute("KaijuCharge")
	local shown = hud ~= nil and hud:IsA("ScreenGui") and hud.Enabled and type(charge) == "number"
	shownNow = shown
	button.Visible = shown
	if not shown then
		wasReady = false
		return
	end
	-- The team's colours (set only when they change).
	local list = palette()
	local key = ""
	for _, color in list do
		key ..= color:ToHex()
	end
	if key ~= paletteKey then
		paletteKey, colors = key, list
		fillGradient.Color = sequence(list)
	end
	local blasting = player:GetAttribute("KaijuBeamAt") ~= nil
	local ready = charge >= 100 and not blasting
	local saving = player:GetAttribute("KaijuSave") == true
	local pct = math.floor(charge)
	local look = string.format("%d/%s/%s/%s/%s", pct, tostring(blasting), tostring(saving), tostring(compact), tostring(touch()))
	if look == drawn then
		return
	end
	drawn = look
	fill.Size = UDim2.fromScale(math.clamp(charge / 100, 0, 1), 1)
	fill.BackgroundTransparency = if ready then 0.1 else 0.45
	-- Its words.
	if blasting then
		state.Text = "BLASTING!"
		state.TextColor3 = READY_GOLD
	elseif ready then
		state.Text = if compact or touch() then "READY!" else "READY!  [ Z ]"
		state.TextColor3 = READY_GOLD
	else
		state.Text = if compact then string.format("%d%%", pct) else string.format("CHARGING  %d%%", pct)
		state.TextColor3 = if saving then P.Good else P.Text
	end
	save.Text = if saving and not compact then "SAVE ON" else "SAVE"
	save.TextColor3 = if saving then INK else P.Dim
	save.BackgroundColor3 = if saving then P.Good else Color3.fromRGB(28, 32, 50)
	saveStroke.Color = if saving then P.Good else P.Edge
	-- Ready: bright, the title shimmering, the glow on; it pops once.
	titleGradient.Enabled = ready
	if shineClip then
		shineClip.Visible = ready
	end
	stroke.Color = if ready then READY_GOLD elseif saving then P.Good else P.Edge
	stroke.Thickness = if ready then 2.5 else 1.5
	if ready and not wasReady then
		pop()
	end
	if not ready then
		glow.BackgroundTransparency = 1
		fillGradient.Offset = Vector2.zero
	end
	wasReady = ready
end

-- Where you're looking, flat: the camera's look, else your facing.
function KaijuBeamHud.aim(): { X: number, Z: number }
	local camera = workspace.CurrentCamera
	local look = camera and camera.CFrame.LookVector
	if not look or look.X * look.X + look.Z * look.Z < 1e-4 then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		look = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	end
	return { X = look.X, Z = look.Z }
end

local function fire()
	if busy or not shownNow then
		return
	end
	local charge = player:GetAttribute("KaijuCharge")
	if player:GetAttribute("KaijuBeamAt") ~= nil then
		return
	end
	if type(charge) ~= "number" or charge < 100 then
		UiKit.toast(string.format("Your kaiju are still charging: %d%%.", charge or 0), P.Gold)
		return
	end
	busy = true
	task.spawn(function()
		local ok, result = pcall(GemClient.request, "KaijuBeam", KaijuBeamHud.aim())
		busy = false
		if ok and result and not result.Ok and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Gold)
		end
	end)
end

local function toggleSave()
	if busy then
		return
	end
	busy = true
	local want = player:GetAttribute("KaijuSave") ~= true
	task.spawn(function()
		local ok, result = pcall(GemClient.request, "KaijuSaveCharge", want)
		busy = false
		if ok and result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then P.Good else P.Gold)
		end
		pcall(refresh)
	end)
end

local started = false
function KaijuBeamHud.start(slot: GuiObject)
	if started then
		return
	end
	started = true
	-- In the kaiju card's bottom row, filling it.
	button.Size = UDim2.fromScale(1, 1)
	button.Position = UDim2.fromScale(0, 0)
	button.Parent = slot
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	button.Activated:Connect(fire)
	save.Activated:Connect(toggleSave)
	ContextActionService:BindActionAtPriority("KaijuHyperbeam", function(_, inputState)
		if UserInputService:GetFocusedTextBox() or not shownNow then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Z, Enum.KeyCode.DPadDown)
	-- Ready: its colours flow, the glow breathes, the title shimmers
	-- (nothing moves while it charges).
	IronUi.animate(glow, function(now: number)
		if not wasReady then
			return
		end
		fillGradient.Offset = Vector2.new(((now * 0.35) % 2) - 1, 0)
		glow.BackgroundColor3 = colors[1 + math.floor(now * 1.5) % #colors]:Lerp(READY_GOLD, 0.35)
		glow.BackgroundTransparency = 0.62 + 0.18 * math.sin(now * 5)
		titleGradient.Offset = Vector2.new(((now * 0.8) % 2) - 1, 0)
	end)
	layout()
	pcall(refresh)
	for _, name in { "KaijuCharge", "KaijuSave", "KaijuBeamAt" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			pcall(refresh)
		end)
	end
	local nextTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextTick then
			return
		end
		nextTick = now + 0.5 -- (its own changes come by its attributes)
		local ok, err = pcall(refresh)
		if not ok then
			warn("[KaijuBeamHud]", err)
		end
	end)
end

return KaijuBeamHud
