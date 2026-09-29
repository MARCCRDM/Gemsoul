-- Talking to shopkeepers. Pressing [E] on a vendor opens a retro terminal
-- style dialogue box with their greeting and a list of things to ask or do:
-- check free mines, buy rough stones, cut gems by hand or by laser.
-- Also keeps the quota terminal outside the Mining Guild up to date.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local CuttingGame = require(script.Parent.Modules.CuttingGame)
local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
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
			"You've used your free mines (%d/%d today, %d/%d this week). I can sell you rough stones for %d coins each.",
			today,
			daily,
			week,
			weekly,
			Config.RoughStonePrice
		)
	end
	return string.format(
		"You have %d free mines left: %d/%d used today, %d/%d this week. Each one gets you a rough stone.",
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
panel.BackgroundColor3 = SCREEN_BG
panel.BackgroundTransparency = 0.08
panel.Parent = gui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(620, math.huge)
sizeLimit.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
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

local header = label(1, Enum.Font.Arcade, 22)
local body = label(2, Enum.Font.Code, 18)

local options = Instance.new("Frame")
options.LayoutOrder = 3
options.Size = UDim2.fromScale(1, 0)
options.AutomaticSize = Enum.AutomaticSize.Y
options.BackgroundTransparency = 1
options.Parent = panel

local optionLayout = Instance.new("UIListLayout")
optionLayout.Padding = UDim.new(0, 6)
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

local function optionButton(order: number, text: string, color: Color3, onClick: () -> ())
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 0)
	button.AutomaticSize = Enum.AutomaticSize.Y
	button.BackgroundColor3 = Color3.fromRGB(24, 34, 30)
	button.AutoButtonColor = true
	button.Font = Enum.Font.Code
	button.TextSize = 18
	button.TextColor3 = color
	button.TextWrapped = true
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = "> " .. text
	button.Parent = options

	local inner = Instance.new("UIPadding")
	inner.PaddingTop = UDim.new(0, 8)
	inner.PaddingBottom = UDim.new(0, 8)
	inner.PaddingLeft = UDim.new(0, 10)
	inner.PaddingRight = UDim.new(0, 10)
	inner.Parent = button

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 6)
	round.Parent = button

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

local busy = false

-- Runs an action that talks to the server, one at a time.
local function perform(action: () -> ())
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, err = pcall(action)
		if not ok then
			warn("[Dialogue] " .. tostring(err))
		end
		busy = false
	end)
end

local function isRough(gem): boolean
	return gem.Cut == nil
end

local actions = {}

function actions.Quota()
	say(quotaReply())
end

function actions.BuyStone()
	perform(function()
		say("Let me find you a good one...")
		local result = GemClient.request("BuyRoughStone")
		say(result.Message)
	end)
end

function actions.Pouch()
	InventoryUI.open()
end

function actions.HandCut()
	InventoryUI.open({
		Title = "Choose a stone to cut by hand",
		Filter = isRough,
		ActionText = "Cut",
		Empty = "You have no rough stones. Mine some or buy one from Garrick.",
		OnPick = function(gem)
			perform(function()
				local start = GemClient.request("StartCut", gem.Id)
				if not start.Ok then
					say(start.Message)
					return
				end
				local times = CuttingGame.play(gem, start)
				if not times then
					say("Changed your mind? The stone will keep.")
					return
				end
				local result = GemClient.request("FinishCut", times)
				say(result.Message)
				UiKit.toast(result.Message, if result.Ok then UiKit.Colors.Gold else UiKit.Colors.Bad)
			end)
		end,
	})
end

local mainMenu: () -> ()

function actions.AutoCut()
	InventoryUI.open({
		Title = "Choose a stone for the laser",
		Filter = isRough,
		ActionText = "Laser",
		Empty = "You have no rough stones. Mine some or buy one from Garrick.",
		OnPick = function(gem)
			say(string.format("%s. Which laser?", GemConfig.displayName(gem)))
			local items: { MenuItem } = {}
			for _, laser in GemConfig.AutoCut do
				local grade = if laser.MinCut == laser.MaxCut
					then tostring(laser.MinCut)
					else laser.MinCut .. "-" .. laser.MaxCut
				table.insert(items, {
					Text = string.format("%s: cut %s for %d coins", laser.Name, grade, laser.Price),
					Run = function()
						perform(function()
							local result = GemClient.request("AutoCut", gem.Id, laser.Tier)
							say(result.Message)
							mainMenu()
						end)
					end,
				})
			end
			table.insert(items, { Text = "Never mind", Color = UiKit.Colors.Dim, Run = mainMenu })
			showMenu(items)
		end,
	})
end

local function open(vendorId: string, part: BasePart)
	local vendor = Vendors[vendorId]
	if not vendor then
		return
	end
	current = { vendor = vendor, part = part }
	stroke.Color = vendor.Color
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
