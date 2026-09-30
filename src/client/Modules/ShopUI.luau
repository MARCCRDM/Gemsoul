--[[
	The Shop [B]: five tabs.
	  Bundles       big coloured cards with a value tag and what's inside
	  Back Pieces   rarity-coloured tiles; buy, equip or take off
	  Trims         the same, for glow colours
	  Geode Crates  buy, then open with a reveal
	  Passes        the VIP pass (when you've set one up)
	Plus the Welcome Bundle popup for new players (ShopUI.showWelcome), with
	its 24-hour countdown.
	Prices are coins. When a Robux product is switched on in Store.luau, its
	card also gets a Robux button.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Store = require(ReplicatedStorage.Shared.Store)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD, HEADING = IronUi.Bold, IronUi.Heading
local new, text, box, button, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.button, IronUi.clear

local WIDTH, HEIGHT = 1000, 620
local BACK_ICONS = { Pack = "🎒", Banner = "🚩", Geode = "🔮", Cape = "🧥", Wings = "🦋", Halo = "💫" }

local ShopUI = {}

local window = IronUi.window("Shop", 10, WIDTH, HEIGHT, "🛒")
local gui, panel = window.Gui, window.Panel
window.Title.Text = "SHOP"
window.Subtitle.Text = "Everything here costs coins. Earn them daily, from monsters and from Tamsin."

local tab = "Bundles"
local selected: string? = nil -- cosmetic id on the Backs / Trims tabs
local busy = false

local coinsPill = text(panel, "", 16, P.Gold, BOLD)
coinsPill.AnchorPoint = Vector2.new(1, 0)
coinsPill.Position = UDim2.new(1, -44, 0, 24)
coinsPill.Size = UDim2.fromOffset(260, 22)
coinsPill.TextXAlignment = Enum.TextXAlignment.Right

local tabBar = new(
	"Frame",
	{ BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 76), Size = UDim2.fromOffset(700, 32) },
	panel
)
local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 122),
	Size = UDim2.fromOffset(WIDTH - 48, HEIGHT - 146),
}, panel)

local function profile()
	return GemClient.Profile or {}
end

local function run(action: string, ...: any)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
		busy = false
		ShopUI.refresh()
	end)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then
			return s
		end
	end
end

local function cosmeticName(id: string): string
	local c = Cosmetics.get(id)
	return if c then c.Name else id
end

local function welcomeSecondsLeft(): number
	local p = profile()
	if not p.FirstJoin or p.FirstJoin == 0 or p.WelcomeBought then
		return 0
	end
	-- Use the server's clock (sent with the profile) so the countdown is honest.
	local offset = (p.ServerTime or os.time()) - os.time()
	return math.max(0, p.FirstJoin + Store.WelcomeHours * 3600 - (os.time() + offset))
end

local function clock(seconds: number): string
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

-- A card with a coloured gradient background.
local function colorCard(parent: Instance, color: Color3, order: number?): Frame
	local card = new("Frame", { BackgroundColor3 = color, LayoutOrder = order or 0 }, parent)
	UiKit.round(card, 12)
	new("UIStroke", { Color = color:Lerp(Color3.new(1, 1, 1), 0.35), Thickness = 2 }, card)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.45)),
	}, card)
	return card
end

local function valueTag(parent: Instance, label: string)
	local tag = new("TextLabel", {
		BackgroundColor3 = P.Gold,
		Position = UDim2.fromOffset(10, 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		Text = label,
		Font = BOLD,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(40, 24, 8),
		Rotation = -4,
		ZIndex = 3,
	}, parent)
	UiKit.round(tag, 6)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tag)
end

local function bigIcon(parent: Instance, icon: string, y: number, size: number)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(size, size),
		Text = icon,
		TextSize = size,
		Font = BOLD,
	}, parent)
	return label
end

local function robuxButton(parent: Instance, key: string)
	local id = Store.RobuxProducts[key]
	if id and id ~= 0 then
		button(parent, string.format("R$ %d", Store.RobuxPrices[key] or 0), false, function()
			MarketplaceService:PromptProductPurchase(player, id)
		end)
	end
end

-- Bundles ------------------------------------------------------------------------------------------

local function drawBundles()
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -10, 1, 0),
		CellPadding = UDim2.fromOffset(14, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for i, bundle in Store.Bundles do
		if not bundle.NewPlayersOnly then
			local card = colorCard(row, bundle.Color, i)
			valueTag(card, bundle.Value)
			bigIcon(card, bundle.Icon, 40, 70)
			local info = new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(14, 120),
				Size = UDim2.new(1, -28, 1, -176),
			}, card)
			UiKit.list(info, 3).HorizontalAlignment = Enum.HorizontalAlignment.Center
			local name = text(info, string.upper(bundle.Name), 18, Color3.new(1, 1, 1), HEADING)
			name.TextXAlignment = Enum.TextXAlignment.Center
			local tagline = text(info, bundle.Tagline, 12, Color3.fromRGB(230, 230, 230))
			tagline.TextXAlignment = Enum.TextXAlignment.Center
			local contents =
				text(info, table.concat(Store.describe(bundle.Contents, cosmeticName), "  •  "), 12, P.Gold, BOLD)
			contents.TextXAlignment = Enum.TextXAlignment.Center
			local buttons = new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -12),
				Size = UDim2.new(1, -24, 0, 34),
			}, card)
			UiKit.list(buttons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
			button(buttons, "💰 " .. commas(bundle.Price), true, function()
				run("BuyBundle", bundle.Id)
			end)
			robuxButton(buttons, bundle.Id)
		end
	end
	-- The Welcome Bundle, while it lasts.
	local left = welcomeSecondsLeft()
	if left > 0 then
		local banner = colorCard(body, Store.bundle("Welcome").Color)
		banner.Position = UDim2.new(0, 0, 1, -52)
		banner.Size = UDim2.new(1, 0, 0, 52)
		local b = new("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = string.format(
				"🎁  WELCOME BUNDLE  •  5X VALUE  •  ends in %s  •  new players only",
				clock(left)
			),
			Font = BOLD,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
		}, banner)
		b.Activated:Connect(ShopUI.showWelcome)
	end
end

-- Back pieces and trims -------------------------------------------------------------------------------

local function tileIcon(parent: Instance, cosmetic, size: number)
	if cosmetic.Kind == "Trim" then
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * 0.55, size * 0.55),
			BackgroundColor3 = cosmetic.Color,
		}, parent)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dot
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }, dot)
	else
		local label = bigIcon(parent, BACK_ICONS[cosmetic.Look] or "✨", size * 0.2, math.floor(size * 0.55))
		label.AnchorPoint = Vector2.new(0.5, 0)
	end
end

local function drawCosmetics(kind: string)
	local p = profile()
	local owned = p.Cosmetics and p.Cosmetics.Owned or {}
	local worn = p.Cosmetics and p.Cosmetics[kind]
	local ids = {}
	for _, id in Cosmetics.Order do
		if Cosmetics.List[id].Kind == kind then
			table.insert(ids, id)
		end
	end
	if not selected or not table.find(ids, selected) then
		selected = worn or ids[1]
	end

	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.62, 0, 1, 0) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 104),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, id in ids do
		local cosmetic = Cosmetics.List[id]
		local tile = new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Cosmetics.rarityColor(cosmetic):Lerp(Color3.new(0, 0, 0), 0.55),
			LayoutOrder = i,
		}, grid)
		UiKit.round(tile, 12)
		new("UIStroke", {
			Color = if id == selected then P.Gold else Cosmetics.rarityColor(cosmetic),
			Thickness = if id == selected then 3 else 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, tile)
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120)),
		}, tile)
		tileIcon(tile, cosmetic, 104)
		if id == worn then
			local check = IronUi.badge(tile, "✓", 26, P.Good)
			check.Position = UDim2.new(1, -30, 0, 4)
		elseif not owned[id] and not cosmetic.Price then
			local lock = text(tile, "🔒", 16, P.Text, BOLD)
			lock.Position = UDim2.fromOffset(6, 4)
			lock.Size = UDim2.fromOffset(20, 20)
		end
		tile.Activated:Connect(function()
			selected = id
			ShopUI.refresh()
		end)
	end

	-- Preview panel.
	local cosmetic = Cosmetics.get(selected)
	if not cosmetic then
		return
	end
	local side = colorCard(body, Cosmetics.rarityColor(cosmetic):Lerp(Color3.new(0, 0, 0), 0.4))
	side.Position = UDim2.new(0.62, 16, 0, 0)
	side.Size = UDim2.new(0.38, -16, 1, 0)
	local stage = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 190) }, side)
	tileIcon(stage, cosmetic, 190)
	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 196),
		Size = UDim2.new(1, -32, 1, -250),
	}, side)
	UiKit.list(info, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local rarity = new("TextLabel", {
		BackgroundColor3 = Cosmetics.rarityColor(cosmetic),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		Text = string.upper(Cosmetics.rarityName(cosmetic)),
		Font = BOLD,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(20, 16, 10),
	}, info)
	UiKit.round(rarity, 11)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, rarity)
	local name = text(info, cosmetic.Name, 20, Color3.new(1, 1, 1), BOLD)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local description = text(info, cosmetic.Description, 13, Color3.fromRGB(225, 225, 225))
	description.TextXAlignment = Enum.TextXAlignment.Center
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -24, 0, 34),
	}, side)
	UiKit.list(actions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	if owned[cosmetic.Id] then
		if worn == cosmetic.Id then
			button(actions, "TAKE OFF", false, function()
				run("EquipCosmetic", kind, nil)
			end)
		else
			button(actions, "EQUIP", true, function()
				run("EquipCosmetic", kind, cosmetic.Id)
			end)
		end
	elseif cosmetic.Price then
		button(actions, "BUY  💰 " .. commas(cosmetic.Price), true, function()
			run("BuyCosmetic", cosmetic.Id)
		end)
	else
		local note = text(actions, "Found in Geode Crates and the Season Path", 12, P.Gold, BOLD)
		note.TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- Crates ---------------------------------------------------------------------------------------------

local reveal: Frame? = nil

local function showReveal(result)
	if reveal then
		reveal:Destroy()
	end
	local color = if result.Rarity and result.Rarity ~= "Common" then GemConfig.TierColors[result.Rarity] else P.Gold
	local card = colorCard(panel, color:Lerp(Color3.new(0, 0, 0), 0.3))
	reveal = card
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.55)
	card.Size = UDim2.fromOffset(420, 260)
	card.ZIndex = 20
	local scale = new("UIScale", { Scale = 0.2 }, card)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local list = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 20),
		Size = UDim2.new(1, -40, 1, -80),
	}, card)
	UiKit.list(list, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local title = text(list, "YOU FOUND", 22, Color3.new(1, 1, 1), HEADING)
	title.TextXAlignment = Enum.TextXAlignment.Center
	if result.Cosmetic then
		local cosmetic = Cosmetics.get(result.Cosmetic)
		local rare = text(list, string.upper(cosmetic and Cosmetics.rarityName(cosmetic) or ""), 14, color, BOLD)
		rare.TextXAlignment = Enum.TextXAlignment.Center
	end
	for _, line in result.Lines or {} do
		local l = text(list, line, 16, P.Gold, BOLD)
		l.TextXAlignment = Enum.TextXAlignment.Center
	end
	local ok = button(card, "NICE!", true, function()
		card:Destroy()
		reveal = nil
	end)
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -16)
	for _, child in card:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 21
		end
	end
end

local function drawCrates()
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -8, 1, 0),
		CellPadding = UDim2.fromOffset(16, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for i, id in Store.CrateOrder do
		local crate = Store.Crates[id]
		local card = colorCard(row, crate.Color, i)
		bigIcon(card, crate.Icon, 26, 70)
		local info = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(20, 110),
			Size = UDim2.new(1, -40, 1, -170),
		}, card)
		UiKit.list(info, 4).HorizontalAlignment = Enum.HorizontalAlignment.Center
		local name = text(info, string.upper(crate.Name), 20, Color3.new(1, 1, 1), HEADING)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local description = text(info, crate.Description, 13, Color3.fromRGB(230, 230, 230))
		description.TextXAlignment = Enum.TextXAlignment.Center
		-- Odds, so players know what they're buying.
		local total = 0
		for _, roll in crate.Rolls do
			total += roll.Weight
		end
		local odds = {}
		for _, roll in crate.Rolls do
			local label = if roll.Cosmetic
				then string.format("%s cosmetic", roll.Cosmetic == "UltraRare" and "Ultra Rare" or roll.Cosmetic)
				else table.concat(Store.describe(roll.Reward or {}), ", ")
			table.insert(odds, string.format("%d%%  %s", math.floor(roll.Weight / total * 100 + 0.5), label))
		end
		local oddsText = text(info, table.concat(odds, "\n"), 12, P.Gold, BOLD)
		oddsText.TextXAlignment = Enum.TextXAlignment.Center
		local have = (profile().Crates or {})[id] or 0
		local buttons = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -24, 0, 34),
		}, card)
		UiKit.list(buttons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
		button(buttons, "BUY  💰 " .. commas(crate.Price), false, function()
			run("BuyCrate", id)
		end)
		robuxButton(buttons, id)
		if have > 0 then
			button(buttons, string.format("OPEN (%d)", have), true, function()
				if busy then
					return
				end
				busy = true
				task.spawn(function()
					local result = GemClient.request("OpenCrate", id)
					busy = false
					ShopUI.refresh()
					if result.Ok then
						showReveal(result)
					else
						UiKit.toast(result.Message, P.Bad)
					end
				end)
			end)
		end
	end
end

-- Passes -----------------------------------------------------------------------------------------------

local function drawPasses()
	local card = colorCard(body, Color3.fromRGB(200, 60, 160))
	card.Size = UDim2.new(0.5, 0, 1, 0)
	bigIcon(card, "👑", 30, 80)
	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 130),
		Size = UDim2.new(1, -40, 1, -190),
	}, card)
	UiKit.list(info, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local name = text(info, "VIP PASS", 24, Color3.new(1, 1, 1), HEADING)
	name.TextXAlignment = Enum.TextXAlignment.Center
	for _, perk in
		{
			"Walk through the pink energy gate into the VIP pit",
			"VIP nodes roll rarer colours and better grades",
			"Show your support for Gemsoul",
		}
	do
		local line = text(info, "•  " .. perk, 14, Color3.fromRGB(240, 240, 240))
		line.TextXAlignment = Enum.TextXAlignment.Center
	end
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -24, 0, 34),
	}, card)
	UiKit.list(actions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	if player:GetAttribute("IsVIP") then
		text(actions, "✓ You're a VIP", 16, P.Good, BOLD).TextXAlignment = Enum.TextXAlignment.Center
	elseif Config.VipGamePassId ~= 0 then
		button(actions, "GET VIP", true, function()
			MarketplaceService:PromptGamePassPurchase(player, Config.VipGamePassId)
		end)
	else
		text(actions, "Coming soon", 16, P.Gold, BOLD).TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- Welcome popup ----------------------------------------------------------------------------------------

local welcome = IronUi.window("WelcomeBundle", 12, 720, 400, "🎁")
welcome.Title.Text = "WELCOME BUNDLE"
welcome.Subtitle.Text = "Only for new players. One per player."
local welcomeTimer = text(welcome.Panel, "", 14, Color3.new(1, 1, 1), BOLD)
welcomeTimer.AnchorPoint = Vector2.new(1, 0)
welcomeTimer.Position = UDim2.new(1, -40, 0, 24)
welcomeTimer.Size = UDim2.fromOffset(200, 22)
welcomeTimer.TextXAlignment = Enum.TextXAlignment.Right
local welcomeBody = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 80),
	Size = UDim2.fromOffset(672, 296),
}, welcome.Panel)

function ShopUI.showWelcome()
	if welcomeSecondsLeft() <= 0 then
		return
	end
	clear(welcomeBody)
	local bundle = Store.bundle("Welcome")
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.58, 0, 1, 0) }, welcomeBody)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(120, 88),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local icons = { "🪨", "⚒️", "🚩", "📦", "⭐" }
	for i, line in Store.describe(bundle.Contents, cosmeticName) do
		local cell = box(grid, UDim2.new(), UDim2.new(), P.Slot, 10)
		cell.LayoutOrder = i
		bigIcon(cell, icons[((i - 1) % #icons) + 1], 6, 36)
		local label = text(cell, line, 12, P.Text, BOLD)
		label.Position = UDim2.fromOffset(0, 50)
		label.TextXAlignment = Enum.TextXAlignment.Center
	end
	local side = colorCard(welcomeBody, bundle.Color)
	side.Position = UDim2.new(0.6, 0, 0, 0)
	side.Size = UDim2.new(0.4, 0, 1, 0)
	valueTag(side, bundle.Value)
	bigIcon(side, bundle.Icon, 30, 110)
	local buttons = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -20, 0, 34),
	}, side)
	UiKit.list(buttons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	button(buttons, "💰 " .. commas(bundle.Price), true, function()
		welcome.Gui.Enabled = false
		run("BuyBundle", "Welcome")
	end)
	robuxButton(buttons, "Welcome")
	welcome.Gui.Enabled = true
	welcome.Fit()
end
welcome.Close.Activated:Connect(function()
	welcome.Gui.Enabled = false
end)
welcome.Shade.Activated:Connect(function()
	welcome.Gui.Enabled = false
end)

-- Drawing and opening -----------------------------------------------------------------------------------

local DRAW = {
	Bundles = drawBundles,
	Backs = function()
		drawCosmetics("Back")
	end,
	Trims = function()
		drawCosmetics("Trim")
	end,
	Crates = drawCrates,
	Passes = drawPasses,
}

function ShopUI.refresh()
	if not gui.Enabled then
		return
	end
	local p = profile()
	coinsPill.Text = string.format("💰 %s   🎖️ %s Marks", commas(p.Coins or 0), commas(p.Marks or 0))
	clear(tabBar)
	local entries = {}
	for _, id in Store.Tabs do
		table.insert(entries, { id, Store.TabNames[id] })
	end
	IronUi.tabs(tabBar, entries, tab, function(id)
		tab = id
		selected = nil
		ShopUI.refresh()
	end)
	clear(body)
	DRAW[tab]()
end

function ShopUI.open(which: string?)
	tab = which or tab
	gui.Enabled = true
	window.Fit()
	ShopUI.refresh()
end

function ShopUI.close()
	gui.Enabled = false
	clear(body)
end

function ShopUI.toggle()
	if gui.Enabled then
		ShopUI.close()
	else
		ShopUI.open()
	end
end

window.Close.Activated:Connect(ShopUI.close)
window.Shade.Activated:Connect(ShopUI.close)
GemClient.Changed:Connect(function()
	if gui.Enabled and not busy then
		ShopUI.refresh()
	end
end)

-- Tick the welcome countdowns once a second.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	elapsed = 0
	local left = welcomeSecondsLeft()
	if welcome.Gui.Enabled then
		welcomeTimer.Text = if left > 0 then "⏰ Ends in " .. clock(left) else "Offer ended"
	end
end)

return ShopUI
