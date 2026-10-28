-- Station dialogue: expedition quota, gem analysis, equipment, trading and exchange.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local CombatGuide = require(script.Parent.Modules.CombatGuide)
local AugmentTreeUI = require(script.Parent.Modules.AugmentTreeUI)
local CharacterUI = require(script.Parent.Modules.CharacterUI)
local TradeUI = require(script.Parent.Modules.TradeUI)
local ForgeUI = require(script.Parent.Modules.ForgeUI)
local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer

local WALK_AWAY_DISTANCE = 16
local TYPE_SPEED = 60 -- characters per second
-- The game's window look (IronUi.window): navy, a hairline edge, the
-- speaker's station colour as a short bar under the name. The words sit
-- in an inset, in plain Gotham.
local SCREEN_BG = IronUi.Colors.Inset
local TEXT = Color3.fromRGB(226, 230, 238)

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
gui.DisplayOrder = 20 -- (over the Outpost's HUD, where the Shelter's crew talk)
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -24)
panel.Size = UDim2.fromScale(0.92, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.new(1, 1, 1)
panel.Parent = gui
local shade = Instance.new("UIGradient")
shade.Rotation = 90
shade.Color = ColorSequence.new(Color3.fromRGB(14, 18, 28), Color3.fromRGB(7, 9, 15))
shade.Parent = panel

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(620, math.huge)
sizeLimit.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Color = Color3.new(1, 1, 1)
stroke.Transparency = 0.86
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

local header = label(1, IronUi.Heading, 20)
-- (The speaker's colour, a short bar under their name.)
local accent = Instance.new("Frame")
accent.Size = UDim2.fromOffset(44, 3)
accent.Position = UDim2.new(0, 0, 1, 4)
accent.BorderSizePixel = 0
accent.Parent = header
local body = label(2, IronUi.Body, 17)
body.LineHeight = 1.15
body.BackgroundColor3 = SCREEN_BG
body.BackgroundTransparency = 0
local bodyCorner = Instance.new("UICorner")
bodyCorner.CornerRadius = UDim.new(0, 8)
bodyCorner.Parent = body
local bodyPad = Instance.new("UIPadding")
for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
	bodyPad[side] = UDim.new(0, 12)
end
bodyPad.Parent = body
local bodyStroke = Instance.new("UIStroke")
bodyStroke.Color = IronUi.Colors.Edge
bodyStroke.Transparency = 0.5
bodyStroke.Thickness = 1
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

-- A reply to pick: a slab in the game's slate, the text on the left.
local function optionButton(order: number, text: string, color: Color3, onClick: () -> ())
	local button, face = IronUi.chunk(options, {
		Color = IronUi.Colors.Slot,
		Rim = IronUi.Colors.Edge,
		Size = UDim2.new(1, 0, 0, 40),
		Radius = 8,
		Lip = 2,
		Stripes = "None",
	})
	button.LayoutOrder = order
	local reply = IronUi.label(button, face, text, 16)
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

function actions.CombatGuide()
	close()
	CombatGuide.open()
end
function actions.AugmentTree()
	close()
	AugmentTreeUI.open()
end

function actions.MarketSell()
	close()
	ForgeUI.open("Sell", true)
end

local mainMenu: () -> ()

-- The Saga Shelter's crew ---------------------------------------------------------

local GOLD = Color3.fromRGB(255, 214, 120)

-- Ilsa's offer for your spare gems of a tier: the loose ones no loadout
-- uses (GemInventory.spare), at the Market's rate. -> how many, coins
local function spareOffer(tier: string): (number, number)
	local count, coins = 0, 0
	for _, gem in GemInventory.spare(GemClient.Profile, tier) do
		count += 1
		coins += Crafting.marketPrice(gem)
	end
	return count, coins
end

local selling = false
-- Ilsa looks over your spares, names her price for each lot, and buys a
-- lot when you say so (the server checks it all again: Forge's SellSpare).
function actions.Appraise()
	local commons, commonCoins = spareOffer("Common")
	local uncommons, uncommonCoins = spareOffer("Uncommon")
	if commons + uncommons == 0 then
		say("No spare Commons or Uncommons in your pouch. Choose a gem to sell, or bring more from the quarry.")
	elseif uncommons == 0 then
		say(string.format("Spare Commons: %d. My offer: %d coins.", commons, commonCoins))
	elseif commons == 0 then
		say(string.format("Spare Uncommons: %d. My offer: %d coins.", uncommons, uncommonCoins))
	else
		say(
			string.format(
				"Spare Commons: %d, %d coins. Spare Uncommons: %d, %d coins.",
				commons,
				commonCoins,
				uncommons,
				uncommonCoins
			)
		)
	end
	local function sell(tier: string)
		if selling then
			return
		end
		selling = true
		task.spawn(function()
			local result = GemClient.request("SellSpare", tier)
			selling = false
			if current then
				say(result.Message or "")
				mainMenu()
			end
		end)
	end
	local items: { MenuItem } = {}
	if commons > 0 then
		table.insert(items, {
			Text = string.format("Sell my spare Commons (%d) for %d coins", commons, commonCoins),
			Color = GOLD,
			Run = function()
				sell("Common")
			end,
		})
	end
	if uncommons > 0 then
		table.insert(items, {
			Text = string.format("Sell my spare Uncommons (%d) for %d coins", uncommons, uncommonCoins),
			Color = GOLD,
			Run = function()
				sell("Uncommon")
			end,
		})
	end
	table.insert(items, { Text = "Pick a gem to sell", Run = actions.MarketSell })
	table.insert(items, {
		Text = "Back",
		Color = UiKit.Colors.Dim,
		Run = function()
			mainMenu()
		end,
	})
	showMenu(items)
end

-- Borin's stands: straight to that section of the Store.
function actions.Store()
	say("Which section of the Store?")
	local items: { MenuItem } = {}
	for _, aisle in
		{
			{ "Suits", "Suits" },
			{ "Helmets", "Helmets" },
			{ "Picks", "Picks" },
			{ "Weapon skins", "Skins" },
			{ "Bundles", "Bundles" },
		}
	do
		table.insert(items, {
			Text = aisle[1],
			Run = function()
				close()
				require(script.Parent.Modules.ShopUI).open(aisle[2])
			end,
		})
	end
	table.insert(items, {
		Text = "Back",
		Color = UiKit.Colors.Dim,
		Run = function()
			mainMenu()
		end,
	})
	showMenu(items)
end

function actions.Market()
	close()
	require(script.Parent.Modules.MarketBoardUI).open()
end

-- Wren's kaiju on the Market: the Browse tab, kaiju only.
function actions.KaijuMarket()
	close()
	require(script.Parent.Modules.MarketBoardUI).open("Browse", "Kaiju")
end

-- Who's in the Kaiju Kennel today (Shared.KaijuKennel).
function actions.KennelToday()
	local Kennel = require(ReplicatedStorage.Shared.KaijuKennel)
	local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
	local names = {}
	for _, entry in Kennel.residents(Kennel.day(workspace:GetServerTimeNow())) do
		local kind = Kaiju.Species[entry.Species]
		table.insert(names, if kind then kind.Name else entry.Species)
	end
	say("In the pen today: " .. table.concat(names, ", ") .. ". They change every day.")
end

-- INFO-9's tips and insights, one after another from a random start.
local tipAt = math.random(1, #Vendors.Tips) - 1
function actions.Tip()
	tipAt = tipAt % #Vendors.Tips + 1
	say(Vendors.Tips[tipAt])
end

-- A crew member's own tips about their station (its Tips), the same way.
local roleTipAt = {}
function actions.RoleTip()
	local vendor = current and current.vendor
	local tips = vendor and vendor.Tips
	if not tips or #tips == 0 then
		return
	end
	local at = (roleTipAt[vendor] or math.random(1, #tips) - 1) % #tips + 1
	roleTipAt[vendor] = at
	say(tips[at])
end

-- COACH-4's battle tips downstairs, the same way.
local arenaTipAt = math.random(1, #Vendors.ArenaTips) - 1
function actions.ArenaTip()
	arenaTipAt = arenaTipAt % #Vendors.ArenaTips + 1
	say(Vendors.ArenaTips[arenaTipAt])
end

function actions.Duels()
	close()
	require(script.Parent.Modules.SocialUI).open("Arena")
end

-- Brutus's bounty board (every Rift boss: Client.RiftClient), at his counter.
function actions.Bounties()
	local part = current and current.part
	close()
	require(script.Parent.Modules.RiftClient).openGate("Bounty", if part then part.Position else nil)
end

-- Garrick's swing refills.
function actions.Exchange()
	close()
	require(script.Parent.Modules.OutpostScene).openRefills()
end

local function open(vendorId: string, part: BasePart)
	local vendor = Vendors[vendorId]
	if not vendor then
		return
	end
	current = { vendor = vendor, part = part }
	header.TextColor3 = TEXT
	accent.BackgroundColor3 = vendor.Color
	header.Text = string.upper(vendor.Name .. " // " .. vendor.Role)

	-- Its options; a topic's (an option with Options of its own) shown in
	-- place of them, with a way back.
	local function menu(list: { any }, topic: boolean)
		local items: { MenuItem } = {}
		for _, option in list do
			table.insert(items, {
				Text = option.Text,
				Run = function()
					if option.Options then
						say("What would you like to know?")
						menu(option.Options, true)
						return
					end
					local action = option.Action and actions[option.Action]
					if action then
						action()
					else
						say(option.Reply or "...")
					end
				end,
			})
		end
		if topic then
			table.insert(items, { Text = "Back", Color = UiKit.Colors.Dim, Run = mainMenu })
		else
			table.insert(items, { Text = "Goodbye", Color = UiKit.Colors.Dim, Run = close })
		end
		showMenu(items)
	end
	mainMenu = function()
		menu(vendor.Options, false)
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
