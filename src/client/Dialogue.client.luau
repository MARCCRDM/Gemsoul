-- Station dialogue: expedition quota, gem analysis, equipment, trading and exchange.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local AbilitiesUI = require(script.Parent.Modules.AbilitiesUI)
local CharacterUI = require(script.Parent.Modules.CharacterUI)
local TradeUI = require(script.Parent.Modules.TradeUI)
local ForgeUI = require(script.Parent.Modules.ForgeUI)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer

local WALK_AWAY_DISTANCE = 16
local TYPE_SPEED = 60 -- characters per second
local SCREEN_BG = Color3.fromRGB(8, 14, 12)
local TEXT = Color3.fromRGB(210, 255, 225)

-- Quota --------------------------------------------------------------------

local function freeMines(): (number, number, number, number)
	local daily = player:GetAttribute("DailyQuota") or Config.DailyQuota
	local weekly = player:GetAttribute("WeeklyQuota") or Config.WeeklyQuota
	return player:GetAttribute("MinedToday") or 0, daily, player:GetAttribute("MinedThisWeek") or 0, weekly
end

local function quotaReply(): string
	local today, daily, week, weekly = freeMines()
	local left = math.max(0, math.min(daily - today, weekly - week))
	if left == 0 then
		return string.format(
			"You've used your free mines (%d/%d today, %d/%d this week). Use coins to fund another wall in the Moon Mine.",
			today,
			daily,
			week,
			weekly
		)
	end
	return string.format(
		"You have %d free mines left: %d/%d used today, %d/%d this week. Each discovery is already faceted and ready to enchant.",
		left,
		today,
		daily,
		week,
		weekly
	)
end

local function refreshTerminals()
	local today, daily, week, weekly = freeMines()
	for _, terminal in CollectionService:GetTagged(Tags.QuotaTerminal) do
		local label = terminal:FindFirstChild("Display", true)
		if label then
			label.Text = string.format("FREE MINES\nTODAY %d/%d\nWEEK %d/%d", today, daily, week, weekly)
		end
	end
end

for _, attribute in { "MinedToday", "DailyQuota", "MinedThisWeek", "WeeklyQuota" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshTerminals)
end
CollectionService:GetInstanceAddedSignal(Tags.QuotaTerminal):Connect(refreshTerminals)
refreshTerminals()

-- Dialogue box ---------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Dialogue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -24)
panel.Size = UDim2.fromScale(0.92, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.new(1, 1, 1)
panel.Parent = gui
-- The crystal window look; the shopkeeper's words stay on a green screen.
local shade = Instance.new("UIGradient")
shade.Rotation = 90
shade.Color = ColorSequence.new(Color3.fromRGB(34, 26, 48), IronUi.Colors.Frame)
shade.Parent = panel

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(620, math.huge)
sizeLimit.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = IronUi.Colors.Gold
stroke.Parent = panel

local padding = Instance.new("UIPadding")
for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
	padding[side] = UDim.new(0, 14)
end
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local function label(order: number, font: Enum.Font, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.LayoutOrder = order
	text.Size = UDim2.fromScale(1, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextSize = size
	text.TextColor3 = TEXT
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = panel
	return text
end

local header = label(1, IronUi.Heading, 24)
IronUi.outline(header, 3)
local body = label(2, Enum.Font.Code, 18)
body.BackgroundColor3 = SCREEN_BG
body.BackgroundTransparency = 0
local bodyCorner = Instance.new("UICorner")
bodyCorner.CornerRadius = UDim.new(0, 10)
bodyCorner.Parent = body
local bodyPad = Instance.new("UIPadding")
for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
	bodyPad[side] = UDim.new(0, 10)
end
bodyPad.Parent = body
local bodyStroke = Instance.new("UIStroke")
bodyStroke.Color = IronUi.Colors.Ink
bodyStroke.Thickness = 2
bodyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bodyStroke.Parent = body

local options = Instance.new("Frame")
options.LayoutOrder = 3
options.Size = UDim2.fromScale(1, 0)
options.AutomaticSize = Enum.AutomaticSize.Y
options.BackgroundTransparency = 1
options.Parent = panel

local optionLayout = Instance.new("UIListLayout")
optionLayout.Padding = UDim.new(0, 8)
optionLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionLayout.Parent = options

local current: { vendor: any, part: BasePart }? = nil
local typing = 0

local function say(text: string)
	typing += 1
	local token = typing
	body.Text = text
	body.MaxVisibleGraphemes = 0
	task.spawn(function()
		local shown = 0
		while token == typing and shown < #text do
			shown = math.min(#text, shown + math.max(1, math.floor(TYPE_SPEED * task.wait())))
			body.MaxVisibleGraphemes = shown
		end
		if token == typing then
			body.MaxVisibleGraphemes = -1
		end
	end)
end

local function close()
	current = nil
	typing += 1
	gui.Enabled = false
end

-- A reply to pick: a chunky slab with the text on the left.
local function optionButton(order: number, text: string, color: Color3, onClick: () -> ())
	local button, face = IronUi.chunk(options, {
		Color = Color3.fromRGB(40, 58, 52),
		Rim = Color3.fromRGB(110, 170, 150),
		Size = UDim2.new(1, 0, 0, 44),
		Radius = 10,
		Lip = 4,
		Stripes = "None",
	})
	button.LayoutOrder = order
	local reply = IronUi.label(button, face, "►  " .. text, 16)
	reply.TextColor3 = color
	reply.TextXAlignment = Enum.TextXAlignment.Left
	reply.TextWrapped = true
	reply.Position = UDim2.fromOffset(12, 0)
	reply.Size = UDim2.new(1, -20, 1, 0)
	button.Activated:Connect(onClick)
end

type MenuItem = { Text: string, Color: Color3?, Run: () -> () }

local function showMenu(items: { MenuItem })
	for _, child in options:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, item in items do
		optionButton(i, item.Text, item.Color or TEXT, item.Run)
	end
end

-- Runs an action that talks to the server, one at a time.
local actions = {}

function actions.Quota()
	say(quotaReply())
end

function actions.Pouch()
	InventoryUI.open()
end

function actions.Enchant()
	close()
	CharacterUI.open({ AtVey = true })
end

function actions.Equipment()
	close()
	CharacterUI.open()
end
function actions.Trade()
	close()
	TradeUI.open()
end
function actions.SellGems()
	close()
	ForgeUI.open()
end

function actions.Abilities()
	close()
	AbilitiesUI.open()
end

function actions.MarketSell()
	close()
	ForgeUI.open("Sell", true)
end

local mainMenu: () -> ()

local function open(vendorId: string, part: BasePart)
	local vendor = Vendors[vendorId]
	if not vendor then
		return
	end
	current = { vendor = vendor, part = part }
	bodyStroke.Color = vendor.Color
	header.TextColor3 = vendor.Color
	header.Text = string.upper(vendor.Name .. " // " .. vendor.Role)

	mainMenu = function()
		local items: { MenuItem } = {}
		for _, option in vendor.Options do
			table.insert(items, {
				Text = option.Text,
				Run = function()
					local action = option.Action and actions[option.Action]
					if action then
						action()
					else
						say(option.Reply or "...")
					end
				end,
			})
		end
		table.insert(items, { Text = "Goodbye", Color = UiKit.Colors.Dim, Run = close })
		showMenu(items)
	end
	mainMenu()

	say(vendor.Greeting)
	gui.Enabled = true
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local part = prompt.Parent
	local vendorId = part and part:GetAttribute("VendorId")
	if typeof(vendorId) == "string" and part:IsA("BasePart") then
		open(vendorId, part)
		-- Stations (the cutting bench, laser, terminal) jump to their option.
		local action = actions[part:GetAttribute("VendorAction")]
		if action then
			action()
		end
	end
end)

-- Close the dialogue when the player walks away.
RunService.Heartbeat:Connect(function()
	if not current then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - current.part.Position).Magnitude > WALK_AWAY_DISTANCE then
		close()
	end
end)
