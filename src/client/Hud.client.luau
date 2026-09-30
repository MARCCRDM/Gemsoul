-- Corner buttons: the gem pouch [G] with coins and gem count, and the
-- character screen [C] (which binds its own key).
local ContextActionService = game:GetService("ContextActionService")

local CharacterUI = require(script.Parent.Modules.CharacterUI)
local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local UiKit = require(script.Parent.Modules.UiKit)

local K = UiKit.Colors
local GOLD = Color3.fromRGB(214, 170, 92)

local gui = UiKit.gui("Hud", 1)
local bar = Instance.new("Frame")
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0, 1)
bar.Position = UDim2.new(0, 16, 1, -16)
bar.Size = UDim2.fromOffset(0, 0)
bar.AutomaticSize = Enum.AutomaticSize.XY
bar.Parent = gui
UiKit.list(bar, 10, true)

local function hudButton(label: string, color: Color3, onClick: () -> ()): TextButton
	local button = UiKit.button(bar, label, color, onClick)
	button.BackgroundColor3 = K.Background
	button.Font = Enum.Font.Arcade
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return button
end

local character = hudButton("CHARACTER [C]", GOLD, CharacterUI.toggle)
character.LayoutOrder = 1
local gems = hudButton("GEMS", K.Accent, InventoryUI.toggle)
gems.LayoutOrder = 2

local function refresh(profile)
	gems.Text = string.format("GEMS %d  |  %d COINS  [G]", #profile.Gems, profile.Coins)
end
GemClient.Changed:Connect(refresh)
if GemClient.Profile then
	refresh(GemClient.Profile)
end

ContextActionService:BindAction("GemsoulPouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		InventoryUI.toggle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.G)
