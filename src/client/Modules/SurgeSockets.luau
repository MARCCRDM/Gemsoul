-- Three real gem capacitors, separate from equipment enchantments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GemClient = require(script.Parent.GemClient)
local GemArt = require(script.Parent.GemArt)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local S = {}
local gui, selected, pending
local function draw()
	if not gui or not gui.Parent or not GemClient.Profile then
		return
	end
	local panel = gui:FindFirstChild("Panel")
	if panel then
		panel:Destroy()
	end
	panel = IronUi.new(
		"Frame",
		{
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -24, 1, -48),
			BackgroundColor3 = IronUi.Colors.Inset,
		},
		gui
	)
	IronUi.new("UISizeConstraint", { MaxSize = Vector2.new(650, 640) }, panel)
	UiKit.round(panel, 16)
	local title = IronUi.text(panel, "GEM SURGE CAPACITORS", 17, IronUi.Colors.Text, IronUi.Bold)
	title.Position, title.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -75, 0, 30)
	local close = IronUi.new(
		"TextButton",
		{
			Text = "×",
			TextSize = 24,
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.new(1, -50, 0, 6),
			BackgroundTransparency = 1,
			TextColor3 = IronUi.Colors.Text,
		},
		panel
	)
	close.Activated:Connect(function()
		gui:Destroy()
		gui = nil
	end)
	local hint = IronUi.text(
		panel,
		"Select a backpack gem, then a capacitor. Visit Vey to change gems after the intro.",
		12,
		IronUi.Colors.Dim
	)
	hint.Position, hint.Size = UDim2.fromOffset(16, 52), UDim2.new(1, -32, 0, 48)
	local c = GemClient.Profile.Character
	for index, slot in Slots.SurgeOrder do
		local button = IronUi.new(
			"TextButton",
			{
				Text = "",
				Size = UDim2.new(1 / 3, -14, 0, 145),
				Position = UDim2.new((index - 1) / 3, 10, 0, 110),
				BackgroundColor3 = Color3.fromRGB(21, 36, 51),
			},
			panel
		)
		UiKit.round(button, 10)
		local gem = c[slot .. "Gem"]
		local label = IronUi.text(button, "SURGE " .. index, 12, IronUi.Colors.Teal, IronUi.Bold)
		label.Position, label.Size = UDim2.fromOffset(8, 6), UDim2.new(1, -16, 0, 20)
		local name = IronUi.text(
			button,
			if gem then (GemConfig.ElementLabels[gem.Element] or gem.Element) else "EMPTY",
			11,
			IronUi.Colors.Text
		)
		name.Position, name.Size = UDim2.fromOffset(8, 108), UDim2.new(1, -16, 0, 30)
		if gem then
			local art = IronUi.new(
				"Frame",
				{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 74) },
				button
			)
			GemArt.viewport(art, gem)
		end
		button.Activated:Connect(function()
			if pending then
				return
			end
			pending = true
			local result = if selected
				then GemClient.request("SocketGem", selected, slot)
				else GemClient.request("UnsocketGem", slot)
			pending = false
			if result.Ok then
				selected = nil
			else
				UiKit.toast(result.Message)
			end
			draw()
		end)
	end
	local list = IronUi.new(
		"ScrollingFrame",
		{
			Position = UDim2.fromOffset(12, 272),
			Size = UDim2.new(1, -24, 1, -286),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		},
		panel
	)
	IronUi.new("UIListLayout", { Padding = UDim.new(0, 6) }, list)
	if #GemClient.Profile.Gems == 0 then
		local empty = IronUi.text(
			list,
			"Your starter gems are equipped. Recover more gemstones to change your capacitors. Tap an equipped capacitor to return its gem to the backpack at Vey.",
			13,
			IronUi.Colors.Dim
		)
		empty.Size = UDim2.new(1, -8, 0, 80)
	end
	for _, gem in GemClient.Profile.Gems do
		local button = IronUi.new(
			"TextButton",
			{
				Size = UDim2.new(1, -8, 0, 46),
				BackgroundColor3 = if selected == gem.Id then IronUi.Colors.Teal else Color3.fromRGB(31, 42, 61),
				TextColor3 = IronUi.Colors.Text,
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				Text = GemConfig.shade(gem).Name .. " · " .. (GemConfig.TierLabels[gem.Tier] or gem.Tier),
			},
			list
		)
		UiKit.round(button, 8)
		button.Activated:Connect(function()
			selected = gem.Id
			draw()
		end)
	end
end
function S.open()
	if gui then
		gui:Destroy()
	end
	selected = nil
	gui = UiKit.gui("SurgeSockets", 12)
	IronUi.new(
		"TextButton",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.25, Text = "", Modal = true },
		gui
	)
	draw()
end
GemClient.Changed:Connect(draw)
return S
