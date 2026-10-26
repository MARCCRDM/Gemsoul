--[[
	The team's HYPERBEAM button (Server.KaijuBeamServer runs it; rules:
	Shared.KaijuBeam; the show: KaijuBeamFx). Shown with the kaiju strip
	(KaijuHud's) while your team's out, in mining and in fights alike: the
	bottom row of the kaiju card (KaijuHud.beamSlot()), under the team and
	its buttons.

	  Charging   a dark core filling with your team's colours (the emptiest
	             of them: all must be full), CHARGING and its percent, and a
	             pip for each kaiju out (its own mana, in its element's
	             colour).
	  Ready      the core lit, a ring of your team's colours spinning round
	             it, a glow that breathes, a band of light sweeping across,
	             READY! and its key (Z; on a pad, the d-pad's down; on a
	             phone, TAP). It pops and chimes the moment it's ready.
	  Blasting   BLASTING! while the blast is under way.
	  SAVE       the switch at its corner: ON, your kaiju fight with blows
	             alone and charge faster (the server's KaijuSaveCharge).

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

-- The pill: a glow behind, the core (charge and ring), its words, the pips
-- and the SAVE switch.
local button = new("TextButton", {
	Name = "Hyperbeam",
	AutoButtonColor = false,
	Text = "",
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.08,
	ZIndex = 3,
}, nil)
UiKit.round(button, 14)
local stroke = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.2 }, button)
local scale = new("UIScale", { Scale = 1 }, button)
local glow = new("Frame", {
	Name = "Glow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 18, 1, 18),
	BackgroundColor3 = READY_GOLD,
	BackgroundTransparency = 1,
	ZIndex = 2,
}, button)
UiKit.round(glow, 20)
local flash = new("Frame", {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	ZIndex = 9,
}, button)
UiKit.round(flash, 14)

-- The core: a spinning ring of the team's colours (ready), the dark well,
-- the charge rising in it, and a bright heart.
local ring = new("Frame", {
	Name = "Ring",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	ZIndex = 4,
}, button)
UiKit.round(ring, 999)
local ringGradient = new("UIGradient", {}, ring)
local well = new("Frame", {
	Name = "Well",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(20, 24, 40),
	ClipsDescendants = true,
	ZIndex = 5,
}, button)
UiKit.round(well, 999)
local fill = new("Frame", {
	Name = "Charge",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = WHITE,
	ZIndex = 5,
}, well)
local fillGradient = new("UIGradient", { Rotation = -90 }, fill)
local heart = new("Frame", {
	Name = "Heart",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.6,
	ZIndex = 6,
}, well)
UiKit.round(heart, 999)

local title = new("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Text = "HYPERBEAM",
	Font = IronUi.Heading,
	TextColor3 = P.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
}, button)
local titleGradient = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, READY_GOLD),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(1, READY_GOLD),
	}),
	Enabled = false,
}, title)
local state = new("TextLabel", {
	Name = "State",
	BackgroundTransparency = 1,
	Text = "CHARGING",
	Font = IronUi.Bold,
	TextColor3 = P.Dim,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
}, button)
local pipRow = new("Frame", {
	Name = "Pips",
	BackgroundTransparency = 1,
	ZIndex = 6,
}, button)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, pipRow)
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

local pips = {} -- [i] = { Back, Fill }
local busy = false
local wasReady = false
local colors = { CHARGE }

local function touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function layout()
	local size = button.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	-- (A short row, a phone's: title and SAVE on one line, the charge and
	-- the pips on the next.)
	local compact = size.Y < 40
	local core = size.Y - (if compact then 6 else 10)
	local left = if compact then 4 else 6
	ring.Size = UDim2.fromOffset(core + 6, core + 6)
	ring.Position = UDim2.fromOffset(left + core / 2, size.Y / 2)
	well.Size = UDim2.fromOffset(core, core)
	well.Position = ring.Position
	heart.Size = UDim2.fromOffset(math.floor(core * 0.32), math.floor(core * 0.32))
	local textX = left + core + (if compact then 6 else 10)
	local textW = size.X - textX - 6
	local saveW, saveH = if compact then 36 else 46, if compact then 13 else 20
	save.Size = UDim2.fromOffset(saveW, saveH)
	save.TextSize = if compact then 8 else 10
	if compact then
		local line = math.floor((size.Y - 4) / 2)
		save.Position = UDim2.new(1, -saveW - 4, 0, 2)
		title.Position, title.Size = UDim2.fromOffset(textX, 2), UDim2.fromOffset(textW - saveW - 6, line)
		title.TextSize = math.min(12, line)
		local stateW = math.min(80, textW - 40)
		state.Position, state.Size = UDim2.fromOffset(textX, 2 + line), UDim2.fromOffset(stateW, line)
		state.TextSize = math.min(9, line)
		pipRow.Position = UDim2.fromOffset(textX + stateW + 4, 2 + line + math.floor((line - 5) / 2))
		pipRow.Size = UDim2.fromOffset(textW - stateW - 4, 5)
	else
		save.Position = UDim2.new(1, -saveW - 8, 0.5, -saveH / 2)
		local wordsW = textW - saveW - 8
		title.Position, title.Size = UDim2.fromOffset(textX, 4), UDim2.fromOffset(wordsW, 18)
		title.TextSize = 15
		state.Position, state.Size = UDim2.fromOffset(textX, 22), UDim2.fromOffset(wordsW, 12)
		state.TextSize = 10
		pipRow.Position = UDim2.fromOffset(textX, size.Y - 9)
		pipRow.Size = UDim2.fromOffset(textW, 5)
	end
end


-- Your kaiju out, in their slots' order: { Model, Color, Mana }.
local function team()
	local folder = workspace:FindFirstChild("Kaiju")
	local list = {}
	if not folder then
		return list
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("KaijuOwner") == player.UserId then
			table.insert(list, {
				Model = model,
				Slot = model:GetAttribute("KaijuSlot") or 9,
				Color = GemConfig.ElementColors[model:GetAttribute("KaijuElement")] or CHARGE,
				Mana = tonumber(model:GetAttribute("Mana")) or 0,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Slot < b.Slot
	end)
	return list
end

-- A sequence of the team's colours, round (for the ring and the charge).
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

local function pipsFor(list)
	for i, unit in list do
		local pip = pips[i]
		if not pip then
			local back = new("Frame", {
				Name = "Pip" .. i,
				LayoutOrder = i,
				BackgroundColor3 = Color3.fromRGB(34, 40, 60),
				ZIndex = 6,
			}, pipRow)
			UiKit.round(back, 3)
			local inner = new("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = WHITE,
				ZIndex = 7,
			}, back)
			UiKit.round(inner, 3)
			pip = { Back = back, Fill = inner }
			pips[i] = pip
		end
		local width = math.floor((pipRow.AbsoluteSize.X - 3 * (#list - 1)) / math.max(1, #list))
		pip.Back.Size = UDim2.new(0, math.max(8, width), 1, 0)
		pip.Back.Visible = true
		pip.Fill.BackgroundColor3 = unit.Color
		pip.Fill.Size = UDim2.fromScale(math.clamp(unit.Mana / 100, 0, 1), 1)
		pip.Fill.BackgroundTransparency = if unit.Mana >= 100 then 0 else 0.15
	end
	for i = #list + 1, #pips do
		pips[i].Back.Visible = false
	end
end

local function pop()
	scale.Scale = 1.18
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
	local list = team()
	local palette = {}
	for _, unit in list do
		table.insert(palette, unit.Color)
	end
	if #palette == 0 then
		palette = { CHARGE }
	end
	colors = palette
	pipsFor(list)
	local blasting = player:GetAttribute("KaijuBeamAt") ~= nil
	local ready = charge >= 100 and not blasting
	local saving = player:GetAttribute("KaijuSave") == true
	-- The charge in the core, in the team's colours.
	fill.Size = UDim2.fromScale(1, math.clamp(charge / 100, 0, 1))
	fillGradient.Color = sequence(palette)
	ringGradient.Color = sequence(palette)
	-- Its words.
	if blasting then
		state.Text = "BLASTING!"
		state.TextColor3 = READY_GOLD
	elseif ready then
		state.Text = if touch() then "READY!  TAP" else "READY!  [ Z ]"
		state.TextColor3 = READY_GOLD
	else
		state.Text = string.format("CHARGING  %d%%", charge)
		state.TextColor3 = if saving then P.Good else P.Dim
	end
	save.Text = if saving then "SAVE ON" else "SAVE"
	save.TextColor3 = if saving then INK else P.Dim
	save.BackgroundColor3 = if saving then P.Good else Color3.fromRGB(28, 32, 50)
	saveStroke.Color = if saving then P.Good else P.Edge
	-- Ready: the ring and glow on, the title shimmering; it pops once.
	ring.BackgroundTransparency = if ready then 0 else 1
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
	-- Ready: the ring spins, the glow breathes, the heart beats.
	IronUi.animate(ring, function(now: number)
		if wasReady then
			ringGradient.Rotation = (now * 140) % 360
			glow.BackgroundColor3 = colors[1 + math.floor(now * 1.5) % #colors]:Lerp(READY_GOLD, 0.35)
			glow.BackgroundTransparency = 0.62 + 0.18 * math.sin(now * 5)
			titleGradient.Offset = Vector2.new(((now * 0.8) % 2) - 1, 0)
			local beat = 1 + 0.18 * math.max(0, math.sin(now * 7))
			heart.BackgroundTransparency = 0.05
			heart.Size = UDim2.fromOffset(
				math.floor(well.AbsoluteSize.X * 0.34 * beat),
				math.floor(well.AbsoluteSize.X * 0.34 * beat)
			)
		else
			heart.BackgroundTransparency = 0.6
			fillGradient.Offset = Vector2.new(0, 0.08 * math.sin(now * 3))
		end
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
		nextTick = now + 0.25
		local ok, err = pcall(refresh)
		if not ok then
			warn("[KaijuBeamHud]", err)
		end
	end)
end

return KaijuBeamHud
