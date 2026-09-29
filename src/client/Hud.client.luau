-- Corner button showing coins and gem count; opens the gem pouch. [G] too.
local ContextActionService = game:GetService("ContextActionService")

local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local UiKit = require(script.Parent.Modules.UiKit)

local K = UiKit.Colors

local gui = UiKit.gui("Hud", 1)
local button = UiKit.button(gui, "GEMS", K.Accent, InventoryUI.toggle)
button.AnchorPoint = Vector2.new(0, 1)
button.Position = UDim2.new(0, 16, 1, -16)
button.BackgroundColor3 = K.Background
button.Font = Enum.Font.Arcade
local stroke = Instance.new("UIStroke")
stroke.Color = K.Accent
stroke.Thickness = 2
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button

local function refresh(profile)
	button.Text = string.format("GEMS %d  |  %d COINS  [G]", #profile.Gems, profile.Coins)
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
