--[[
	A new player's element (Shared.SkillTree, FastStart.ChooseElement): after
	the combat basics, before their kit, full screen. Four cards, one per
	element: its name and colour, what it does (GemConfig.ElementEffects)
	and the tree's tier-1 moves it starts them on, Q, E and R. Tapping a card
	picks it; CHOOSE (or Enter) confirms. Their three starting stones are
	Common gems of it, in the sword, the chest and the shield.

	  ElementPick.run() -> element   shows it and waits for the choice
	  ElementPick.Cards              the cards' order (SkillTree.Elements)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local SkillTree = require(ReplicatedStorage.Shared.SkillTree)
local UiKit = require(script.Parent.UiKit)
local Icons = (function()
	local ok, module = pcall(function()
		return require(script.Parent.SurgeIcons)
	end)
	return if ok then module else nil
end)()

local ElementPick = {}
ElementPick.Cards = SkillTree.Elements
ElementPick.Order = 60 -- (over the intro's own screens)

local INK = Color3.fromRGB(8, 10, 16)
local CARD = Color3.fromRGB(18, 22, 32)
local LINE = Color3.fromRGB(52, 60, 78)
local TEXT = Color3.fromRGB(238, 242, 248)
local DIM = Color3.fromRGB(160, 172, 190)
local GOLD = Color3.fromRGB(255, 202, 91)
local KEYS = { "Q", "E", "R" }
local KEY_WORDS = { Q = "Sword", E = "Chest", R = "Shield" }

local function new(class: string, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	i.Parent = parent
	return i
end
local function text(parent, value: string, size: number, color: Color3, font: Enum.Font, props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font,
		TextWrapped = true,
	}, parent)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

function ElementPick.run(): string
	local gui = UiKit.gui("ElementPick", ElementPick.Order)
	gui.IgnoreGuiInset = true
	local back = new("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0 }, gui)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(20, 26, 44), INK) }, back)
	local tint = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.6),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, back)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.82) }),
	}, tint)

	local holder = new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(980, 560),
		BackgroundTransparency = 1,
	}, back)
	local scale = new("UIScale", {}, holder)
	text(holder, "CHOOSE YOUR ELEMENT", 34, GOLD, Enum.Font.GothamBlack, {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 40),
	})
	text(holder, "Your skill tree, and three Common stones of it for your sword, chest and shield: they power Q, E and R.", 16, DIM, Enum.Font.GothamMedium, {
		Name = "Subtitle",
		Position = UDim2.fromOffset(60, 44),
		Size = UDim2.new(1, -120, 0, 44),
	})

	local chosen: string? = nil
	local done = false
	local cards = {}
	local cardW, cardH, gap = 230, 360, 20
	local confirm = new("TextButton", {
		Name = "Choose",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(320, 56),
		BackgroundColor3 = LINE,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = DIM,
		Text = "PICK ONE",
		Active = false,
	}, holder)
	UiKit.round(confirm, 12)

	local function refresh()
		for element, card in cards do
			local on = element == chosen
			local color = GemConfig.ElementColors[element] or GOLD
			card.Stroke.Color = if on then color:Lerp(Color3.new(1, 1, 1), 0.3) elseif chosen then LINE:Lerp(INK, 0.4) else LINE
			card.Stroke.Thickness = if on then 3 else 1
			card.Button.BackgroundColor3 = if on then CARD:Lerp(color, 0.16) else CARD
			card.Check.Visible = on
			card.Halo.Visible = on
			card.Pop.Scale = if on then 1.03 elseif chosen then 0.97 else 1
		end
		if chosen then
			local color = GemConfig.ElementColors[chosen] or GOLD
			confirm.Active = true
			confirm.BackgroundColor3 = GOLD
			confirm.TextColor3 = INK
			local keys = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
			confirm.Text = "CHOOSE " .. string.upper(GemConfig.ElementLabels[chosen] or chosen) .. (if keys then "  [ENTER]" else "")
			tint.BackgroundColor3 = color
			TweenService:Create(tint, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
		end
	end

	for i, element in ElementPick.Cards do
		local color = GemConfig.ElementColors[element] or GOLD
		local button = new("TextButton", {
			Name = element,
			Size = UDim2.fromOffset(cardW, cardH),
			BackgroundColor3 = CARD,
			AutoButtonColor = false,
			Text = "",
		}, holder)
		UiKit.round(button, 14)
		local pop = new("UIScale", {}, button)
		-- (picked: a glow round it)
		local halo = new("Frame", {
			Name = "Halo",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 22, 1, 22),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.78,
			ZIndex = 0,
			Visible = false,
		}, button)
		UiKit.round(halo, 22)
		local stroke = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = LINE, Thickness = 1 }, button)
		-- its colour along the top, a gem in it
		local band = new("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundColor3 = color, BorderSizePixel = 0 }, button)
		UiKit.round(band, 14)
		new("Frame", { Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = color, BorderSizePixel = 0 }, band)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(INK, 0.35)) }, band)
		-- a cut gem: a glow, the stone, a lighter table on it and a glint
		local aura = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(70, 70),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
		}, band)
		UiKit.round(aura, 35)
		local gem = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(44, 44),
			Rotation = 45,
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35),
			BorderSizePixel = 0,
		}, band)
		UiKit.round(gem, 7)
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.65), color:Lerp(INK, 0.15)) }, gem)
		new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.15, Thickness = 2 }, gem)
		local face = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
		}, gem)
		UiKit.round(face, 3)
		text(button, string.upper(GemConfig.ElementLabels[element] or element), 24, color:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Font.GothamBlack, {
			Name = "Label",
			Position = UDim2.fromOffset(12, 96),
			Size = UDim2.new(1, -24, 0, 28),
		})
		text(button, GemConfig.ElementEffects[element] or "", 13, DIM, Enum.Font.GothamMedium, {
			Position = UDim2.fromOffset(14, 126),
			Size = UDim2.new(1, -28, 0, 52),
		})
		-- the moves it starts you on
		local first = SkillTree.first(element) or {}
		for row, key in KEYS do
			local y = 190 + (row - 1) * 52
			local cap = new("TextLabel", {
				Position = UDim2.fromOffset(12, y + 6),
				Size = UDim2.fromOffset(32, 32),
				BackgroundColor3 = color:Lerp(INK, 0.55),
				Font = Enum.Font.GothamBlack,
				TextSize = 18,
				TextColor3 = TEXT,
				Text = key,
			}, button)
			UiKit.round(cap, 8)
			local move = GemTraits.Moves[first[key] or ""]
			-- its painted icon
			local art = new("TextLabel", {
				Position = UDim2.fromOffset(52, y + 2),
				Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = INK,
				Font = Enum.Font.GothamBlack,
				TextSize = 16,
				TextColor3 = TEXT,
				Text = move and string.sub(move.Name, 1, 1) or "",
			}, button)
			UiKit.round(art, 9)
			new("UIStroke", { Color = color, Transparency = 0.4, Thickness = 1 }, art)
			if Icons and first[key] then
				pcall(Icons.apply, art, first[key])
			end
			text(button, move and move.Name or "", 14, TEXT, Enum.Font.GothamBold, {
				Position = UDim2.fromOffset(100, y + 3),
				Size = UDim2.new(1, -106, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			text(button, KEY_WORDS[key], 11, DIM, Enum.Font.GothamMedium, {
				Position = UDim2.fromOffset(100, y + 23),
				Size = UDim2.new(1, -106, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
		local check = text(button, "✓", 22, INK, Enum.Font.GothamBlack, {
			Name = "Check",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(32, 32),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = false,
		})
		UiKit.round(check, 16)
		button.Activated:Connect(function()
			chosen = element
			refresh()
		end)
		cards[element] = { Button = button, Stroke = stroke, Check = check, Index = i, Halo = halo, Pop = pop }
	end

	-- Laid out for the screen: a row of four, or two by two on a narrow one.
	local function layout()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local columns = if view.X < 760 or view.X / math.max(1, view.Y) < 1.2 then 2 else 4
		local rows = math.ceil(#ElementPick.Cards / columns)
		local width = columns * cardW + (columns - 1) * gap
		local height = 100 + rows * cardH + (rows - 1) * gap + 24 + 56
		holder.Size = UDim2.fromOffset(math.max(width, 600), height)
		for _, card in cards do
			local index = card.Index - 1
			local col, row = index % columns, math.floor(index / columns)
			local left = (math.max(width, 600) - width) / 2
			card.Button.Position = UDim2.fromOffset(left + col * (cardW + gap), 100 + row * (cardH + gap))
		end
		scale.Scale = math.min(1, (view.X - 24) / math.max(width, 600), (view.Y - 24) / height)
	end
	layout()
	local camera = workspace.CurrentCamera
	local resized = camera and camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

	local function go()
		if chosen and not done then
			done = true
		end
	end
	confirm.Activated:Connect(go)
	local keyed = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter or input.KeyCode == Enum.KeyCode.ButtonA then
			go()
		end
	end)
	while not done do
		task.wait(0.05)
	end
	keyed:Disconnect()
	if resized then
		resized:Disconnect()
	end
	gui:Destroy()
	return chosen :: string
end

return ElementPick
