-- A short welcome, simultaneous equipment reels, and nine guaranteed starter gems.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Classes = require(ReplicatedStorage.Shared.Classes)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
local UiSound = require(script.Parent.Modules.UiSound)
local player = Players.LocalPlayer
while not GemClient.Profile do
	GemClient.Changed:Wait()
end
if GemClient.Profile.Intro and GemClient.Profile.Intro.Done then
	return
end
local new = IronUi.new
local cyan = Color3.fromRGB(101, 218, 242)
local gui = UiKit.gui("Intro", 15)
local back = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(9, 15, 29) }, gui)
new(
	"UIGradient",
	{ Rotation = 35, Color = ColorSequence.new(Color3.fromRGB(13, 34, 52), Color3.fromRGB(25, 13, 40)) },
	back
)
local panel = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -24, 1, -24),
}, back)
new("UISizeConstraint", { MaxSize = Vector2.new(1080, 900) }, panel)
local function label(parent, value, size, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		Font = Enum.Font.GothamBold,
		TextSize = size,
		TextColor3 = color or Color3.fromRGB(236, 242, 251),
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}, parent)
end
local eyebrow = label(panel, "SAGA MINERS · LAUNCH LOTTERY", 11, cyan)
eyebrow.Position, eyebrow.Size = UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 22)
local title = label(panel, "Your adventure starts here", 28)
title.Position, title.Size = UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 64)
local subtitle = label(
	panel,
	"One Warrior. A random kit. Nine gemstones. Your build begins with a surprise.",
	13,
	Color3.fromRGB(166, 186, 210)
)
subtitle.Position, subtitle.Size = UDim2.fromOffset(0, 98), UDim2.new(1, 0, 0, 42)
local stage = new(
	"ScrollingFrame",
	{
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 1, -254),
	},
	panel
)
local grid =
	new("UIGridLayout", { CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, stage)
grid.Parent = nil
local primary = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -40),
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = cyan,
	TextColor3 = Color3.fromRGB(8, 24, 36),
	Text = "ROLL MY STARTER KIT",
	TextSize = 16,
	Font = Enum.Font.GothamBold,
}, panel)
UiKit.round(primary, 12)
local skip = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(168, 185, 211),
	Text = "Skip animation · keep every reward",
	TextSize = 12,
	Font = Enum.Font.Gotham,
}, panel)
local cards, phase, reward, busy, spin, heartbeat, keyboard = {}, "Welcome", nil, false, nil, nil
local symbols = {
	Boots = "⇧",
	Gloves = "✊",
	Weapon = "⚔",
	Shield = "◇",
	Armor = "▣",
	Helmet = "⬡",
	Surge1 = "⚡",
	Surge2 = "⚡",
	Surge3 = "⚡",
}
local function fit()
	local columns = if panel.AbsoluteSize.X < 480 then 3 else (if phase == "Gems" then 3 else 6)
	local rows = math.ceil((if phase == "Gems" then 9 else 6) / columns)
	grid.CellSize = UDim2.new(1 / columns, -8, 0, math.max(90, (stage.AbsoluteSize.Y - (rows - 1) * 8) / rows))
	title.TextSize = if panel.AbsoluteSize.X < 480 then 22 else 28
end
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
local welcome = label(
	stage,
	[[SUIT UP.
POWER UP.
MAKE IT YOURS.]],
	30,
	cyan
)
local function burst(card, color)
	for i = 1, 12 do
		local star = label(card, "✦", 16, color)
		star.AnchorPoint, star.Position, star.Size =
			Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.4), UDim2.fromOffset(20, 20)
		star.ZIndex = 8
		local angle = i * math.pi / 6
		TweenService:Create(
			star,
			TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.new(0.5, math.cos(angle) * 55, 0.4, math.sin(angle) * 55),
				TextTransparency = 1,
				Rotation = i * 35,
			}
		):Play()
		task.delay(0.7, function()
			star:Destroy()
		end)
	end
end
local function gearView(parent, slot)
	local character = player.Character
	local equipment = character and character:FindFirstChild("GemsoulGear")
	local source = equipment and equipment:FindFirstChild(slot)
	if not source then
		return false
	end
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.05, 0.13),
		Size = UDim2.fromScale(0.9, 0.56),
		Ambient = Color3.fromRGB(180, 190, 210),
		LightColor = Color3.new(1, 1, 1),
	}, parent)
	local model = new("Model", {}, view)
	for _, part in source:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local copy = part:Clone()
			for _, child in copy:GetDescendants() do
				if
					child:IsA("JointInstance")
					or child:IsA("WeldConstraint")
					or child:IsA("Script")
					or child:IsA("LocalScript")
				then
					child:Destroy()
				end
			end
			copy.Anchored, copy.CanCollide = true, false
			copy.Parent = model
		end
	end
	if #model:GetChildren() == 0 then
		view:Destroy()
		return false
	end
	local center, size = model:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 32 }, view)
	camera.CFrame = CFrame.lookAt(
		center.Position + Vector3.new(0.5, 0.3, -1).Unit * math.max(size.X, size.Y, size.Z) * 2.3,
		center.Position
	)
	view.CurrentCamera = camera
	return true
end
local function createCards(entries, isGem)
	grid.Parent = stage
	stage.CanvasPosition = Vector2.zero
	for _, card in cards do
		card.Frame:Destroy()
	end
	table.clear(cards)
	if welcome then
		welcome:Destroy()
		welcome = nil
	end
	for index, entry in entries do
		local frame = new(
			"Frame",
			{ LayoutOrder = index, BackgroundColor3 = Color3.fromRGB(19, 29, 46), BorderSizePixel = 0 },
			stage
		)
		UiKit.round(frame, 12)
		local stroke = new("UIStroke", { Color = cyan, Transparency = 0.6, Thickness = 1 }, frame)
		local slotLabel = label(
			frame,
			if Slots.SurgeDefinitions[entry.Slot]
				then Slots.SurgeDefinitions[entry.Slot].Label
				else Slots.Definitions[entry.Slot].Label,
			10,
			cyan
		)
		slotLabel.Position, slotLabel.Size = UDim2.fromScale(0, 0.02), UDim2.fromScale(1, 0.16)
		local glyph = label(frame, if isGem then "◆" else symbols[entry.Slot], 34, cyan)
		glyph.Position, glyph.Size = UDim2.fromScale(0, 0.19), UDim2.fromScale(1, 0.4)
		local name = label(frame, "ROLLING…", 11)
		name.TextWrapped, name.TextTruncate = false, Enum.TextTruncate.AtEnd
		name.Position, name.Size = UDim2.fromScale(0.04, 0.61), UDim2.fromScale(0.92, 0.23)
		local badge = label(frame, "? ? ?", 10, cyan)
		badge.Position, badge.Size = UDim2.fromScale(0.02, 0.84), UDim2.fromScale(0.96, 0.14)
		table.insert(cards, {
			Frame = frame,
			Stroke = stroke,
			Glyph = glyph,
			Name = name,
			Badge = badge,
			Entry = entry,
			Stopped = false,
			Scale = new("UIScale", {}, frame),
		})
	end
	fit()
end
local function reveal(card, isGem)
	local entry = card.Entry
	local color
	if isGem then
		color = GemConfig.TierColors[entry.Gem.Tier]
		card.Name.Text = GemConfig.shade(entry.Gem).Name
		card.Badge.Text = (GemConfig.TierLabels[entry.Gem.Tier] or entry.Gem.Tier) .. " · CUT " .. entry.Gem.Cut
		local holder = new(
			"Frame",
			{ BackgroundTransparency = 1, Position = UDim2.fromScale(0.05, 0.17), Size = UDim2.fromScale(0.9, 0.44) },
			card.Frame
		)
		GemArt.viewport(holder, entry.Gem)
	else
		local c = GemClient.Profile.Character
		local item = Classes.gear(c.Class, Slots.Definitions[entry.Slot].Kind, entry.Id)
		local roll = c.GearRolls
			and c.GearRolls[Slots.Definitions[entry.Slot].Kind]
			and c.GearRolls[Slots.Definitions[entry.Slot].Kind][entry.Id]
		local rarity = GearRolls.Rarities[(roll and roll.Rarity) or 1]
		color = rarity.Color
		card.Name.Text = if item then item.Name else entry.Id
		card.Badge.Text = rarity.Name
		card.Glyph.Visible = not gearView(card.Frame, entry.Slot)
	end
	if isGem then
		card.Glyph.Visible = false
	end
	card.Stroke.Color, card.Stroke.Transparency, card.Badge.TextColor3 = color, 0, color
	card.Scale.Scale = 0.86
	TweenService:Create(card.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	burst(card.Frame, color)
	UiSound.play(if entry.Slot == "Helmet" then "Reward" else "Confirm")
end
local function animate(entries, isGem)
	createCards(entries, isGem)
	local start = os.clock()
	spin = { Start = start, IsGem = isGem, NextTick = 0 }
	primary.Text, primary.Active = "REVEALING YOUR REWARDS…", false
end
heartbeat = RunService.RenderStepped:Connect(function()
	if not spin then
		return
	end
	local elapsed = os.clock() - spin.Start
	if elapsed > spin.NextTick then
		spin.NextTick = elapsed + 0.08
		for _, card in cards do
			if not card.Stopped then
				if spin.IsGem then
					local element = GemConfig.Elements[math.random(1, #GemConfig.Elements)]
					card.Glyph.TextColor3 = GemConfig.ElementColors[element]
					card.Name.Text = (GemConfig.ElementLabels[element] or element) .. " GEM"
				else
					local catalog =
						Classes.get(GemClient.Profile.Character.Class)[Slots.Definitions[card.Entry.Slot].Kind]
					card.Name.Text = catalog[math.random(1, #catalog)].Name
					card.Glyph.TextColor3 = GearRolls.Rarities[math.random(1, #GearRolls.Rarities)].Color
				end
				card.Glyph.Rotation = math.sin(elapsed * 13) * 12
			end
		end
		UiSound.play("Hover")
	end
	local allStopped = true
	for index, card in cards do
		if not card.Stopped and elapsed >= 1.8 + index * (if spin.IsGem then 0.33 else 0.65) then
			card.Stopped = true
			reveal(card, spin.IsGem)
			local bottom = card.Frame.AbsolutePosition.Y
				- stage.AbsolutePosition.Y
				+ stage.CanvasPosition.Y
				+ card.Frame.AbsoluteSize.Y
			local offset = math.max(0, bottom - stage.AbsoluteSize.Y)
			if bottom > stage.AbsoluteSize.Y then
				stage.CanvasPosition = Vector2.new(0, offset)
			end
			subtitle.Text = if card.Entry.Slot == "Helmet"
				then "Helmet locked! Your Warrior is ready for its gemstones."
				else "REVEALED " .. index .. " / " .. #cards .. " · " .. (if Slots.SurgeDefinitions[card.Entry.Slot]
					then Slots.SurgeDefinitions[card.Entry.Slot].Label
					else Slots.Definitions[card.Entry.Slot].Label)
		end
		allStopped = allStopped and card.Stopped
	end
	if allStopped then
		spin = nil
		primary.Active = true
		primary.Text = if phase == "Armor" then "ROLL MY NINE GEMSTONES" else "ATTUNE ALL NINE · ENTER THE MOON BASE"
		subtitle.Text = if phase == "Armor"
			then "Boots to helmet, one reveal at a time. Next: a gem for every socket."
			else "Six equipment gems + three Gem Surge gems. Every reward is yours."
	end
end)
local function finish()
	if busy then
		return
	end
	busy = true
	primary.Text = "PREPARING YOUR LOADOUT…"
	local result = GemClient.request("FinishStarterLottery")
	busy = false
	if not result.Ok then
		primary.Text = "RETRY · ENTER THE MOON BASE"
		UiKit.toast(result.Message)
		return
	end
	if heartbeat then
		heartbeat:Disconnect()
	end
	if keyboard then
		keyboard:Disconnect()
	end
	gui:Destroy()
	UiSound.play("Reward")
	UiKit.toast("Starter kit ready! Six equipment sockets and three Surge sockets filled.", cyan)
end
primary.Activated:Connect(function()
	if busy or spin then
		return
	end
	if phase == "Welcome" then
		busy = true
		local result = GemClient.request("PrepareStarterLottery")
		busy = false
		if not result.Ok then
			UiKit.toast(result.Message)
			return
		end
		reward = result.Lottery
		phase = "Armor"
		title.Text = "Your armor is rolling…"
		subtitle.Text = "All reels roll together. Boots finish first. Helmet finishes last."
		animate(reward.Gear, false)
	elseif phase == "Armor" then
		phase = "Gems"
		title.Text = "Nine gemstones. Nine surprises."
		subtitle.Text = "Six equipment sockets + three dedicated Gem Surge sockets."
		animate(reward.Gems, true)
	else
		finish()
	end
end)
skip.Activated:Connect(finish)
keyboard = UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Space and gui.Parent then
		finish()
	end
end)
fit()
