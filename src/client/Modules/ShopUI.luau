--[[
	The Gem Shop [B].
	  Featured      the Geode Crate hero card: odds, 1 / 5 / 10 buy buttons,
	                open buttons; plus the Masterwork Crate and a bundle
	  Bundles       big coloured cards with value ribbons
	  Back Pieces   rarity tiles that bounce; preview, buy / equip / take off
	  Trims         the same, for glow colours
	  Passes        the VIP pass
	Opening crates plays the full-screen reveal (CrateReveal). New players
	also get the Welcome Bundle popup with its 24-hour countdown.
	Prices are coins; Robux buttons appear for products switched on in
	Store.RobuxProducts.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Store = require(ReplicatedStorage.Shared.Store)
local CrateReveal = require(script.Parent.CrateReveal)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local ShopArt = require(script.Parent.ShopArt)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local CHUNKY = IronUi.Chunky
local new, text, title, clear = IronUi.new, IronUi.text, IronUi.title, IronUi.clear

local WIDTH, HEIGHT = 1040, 640
local RARITY_NAMES = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare", UltraRare = "Ultra Rare" }

local ShopUI = {}

local window = IronUi.window("Shop", 10, WIDTH, HEIGHT, "🛒", P.Amethyst)
local gui, panel = window.Gui, window.Panel
window.Title.Text = "GEM SHOP"
window.Subtitle.Text = "Crates, cosmetics and bundles. Everything costs coins."

local tab = "Featured"
local selected: string? = nil
local busy = false

local wallet = text(panel, "", 18, P.Gold, CHUNKY)
wallet.AnchorPoint = Vector2.new(1, 0)
wallet.Position = UDim2.new(1, -56, 0, 22)
wallet.Size = UDim2.fromOffset(320, 24)
wallet.AutomaticSize = Enum.AutomaticSize.None
wallet.TextXAlignment = Enum.TextXAlignment.Right
wallet.ZIndex = 4

local tabBar = new(
	"Frame",
	{ BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 80), Size = UDim2.fromOffset(900, 36) },
	panel
)
local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(26, 128),
	Size = UDim2.fromOffset(WIDTH - 52, HEIGHT - 152),
}, panel)

-- Helpers -----------------------------------------------------------------------------------------

local function profile()
	return GemClient.Profile or {}
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

-- Text that floats up from a spot and fades, e.g. "+5 CRATES!".
local function floatText(from: GuiObject, message: string, color: Color3)
	local label = IronUi.title(panel, message, 22, color)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.AnchorPoint = Vector2.new(0.5, 1)
	local offset = from.AbsolutePosition - panel.AbsolutePosition
	local s = window.Scale.Scale
	label.Position = UDim2.fromOffset((offset.X + from.AbsoluteSize.X / 2) / s, offset.Y / s)
	label.ZIndex = 30
	label.Rotation = math.random(-8, 8)
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
	}):Play()
	task.delay(0.95, function()
		label:Destroy()
	end)
end

local function run(from: GuiObject?, success: string?, action: string, ...: any)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		if result.Ok and from and success then
			pcall(floatText, from, success, P.Gold)
		end
		UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
		busy = false
		ShopUI.refresh()
	end)
end

local function welcomeSecondsLeft(): number
	local p = profile()
	if not p.FirstJoin or p.FirstJoin == 0 or p.WelcomeBought then
		return 0
	end
	local offset = (p.ServerTime or os.time()) - os.time()
	return math.max(0, p.FirstJoin + Store.WelcomeHours * 3600 - (os.time() + offset))
end

local function clock(seconds: number): string
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

-- A chunky card: saturated gradient, dark ink edge, glossy top and diagonal sheen.
local function card(parent: Instance, color: Color3, order: number?): Frame
	local c = new(
		"Frame",
		{ BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order or 0, ClipsDescendants = true },
		parent
	)
	UiKit.round(c, 14)
	new("UIStroke", { Color = P.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, c)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.5)),
	}, c)
	for i, x in { 0.15, 0.55, 0.85 } do
		new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = if i == 2 then 0.9 else 0.94,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.new(0, if i == 2 then 70 else 30, 2, 0),
			Rotation = 25,
		}, c)
	end
	local gloss = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.85,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 12),
	}, c)
	UiKit.round(gloss, 6)
	return c
end

-- A tilted ribbon tag, e.g. "5X VALUE" or "SEASON 1".
local function ribbon(parent: Instance, label: string, color: Color3?, x: number?, y: number?)
	local tag = new("TextLabel", {
		BackgroundColor3 = color or P.Gold,
		Position = UDim2.fromOffset(x or 10, y or 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		Text = label,
		Font = CHUNKY,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Rotation = -6,
		ZIndex = 6,
	}, parent)
	UiKit.round(tag, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tag)
	IronUi.outline(tag, 2)
	return tag
end

local function emoji(parent: Instance, glyph: string, size: number, position: UDim2): TextLabel
	-- A soft oval shadow under it (emoji ignore text colour, so a dark copy
	-- of the glyph would just show as a ghost).
	local shadow = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.72,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position + UDim2.fromOffset(0, math.floor(size * 0.46)),
		Size = UDim2.fromOffset(math.floor(size * 0.7), math.floor(size * 0.16)),
	}, parent)
	shadow.Name = "Shadow"
	UiKit.round(shadow, size)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		Text = glyph,
		TextSize = size,
		Font = CHUNKY,
	}, parent)
end

-- One reward as a colourful tile: its icon, a big "x15" and its name.
local function rewardTile(parent: Instance, item: Store.RewardItem, order: number): Frame
	local color = ShopArt.KindColors[item.Kind] or Color3.fromRGB(80, 90, 120)
	local glyph = ShopArt.KindIcons[item.Kind] or "✨"
	if item.Kind == "Materials" and item.Id then
		local material = Crafting.Materials[item.Id]
		color = if material then material.Color:Lerp(Color3.fromRGB(120, 80, 40), 0.35) else color
		glyph = ShopArt.MaterialIcons[item.Id] or glyph
	elseif item.Kind == "Crates" then
		glyph = "📦"
	elseif item.Kind == "XPBoost" then
		glyph = "⭐"
	end
	local cell = card(parent, color, order)
	if item.Kind == "Cosmetic" and item.Id then
		ShopArt.icon(cell, "Cosmetic", item.Id, 50).Position = UDim2.new(0.5, 0, 0, 36)
	else
		emoji(cell, glyph, 40, UDim2.new(0.5, 0, 0, 36))
	end
	if item.Count then
		local count = IronUi.title(cell, "x" .. commas(item.Count), 20)
		count.AutomaticSize = Enum.AutomaticSize.None
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -8, 0, 4)
		count.Size = UDim2.fromOffset(70, 22)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.Rotation = 6
		count.ZIndex = 4
	end
	local label = text(cell, item.Text, 13, Color3.new(1, 1, 1), CHUNKY)
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 4, 1, -6)
	label.Size = UDim2.new(1, -8, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return cell
end

local function robuxButton(parent: Instance, key: string)
	local id = Store.RobuxProducts[key]
	if id and id ~= 0 then
		IronUi.gemButton(
			parent,
			string.format("R$ %d", Store.RobuxPrices[key] or 0),
			Color3.fromRGB(40, 170, 90),
			function()
				MarketplaceService:PromptProductPurchase(player, id)
			end
		)
	end
end

-- Opens crates and plays the reveal.
local function openCrates(crate: Store.Crate, count: number)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("OpenCrate", crate.Id, count)
		busy = false
		if not result.Ok then
			UiKit.toast(result.Message, P.Bad)
			return
		end
		gui.Enabled = false
		CrateReveal.play(crate, result.Results or { result })
		gui.Enabled = true
		ShopUI.refresh()
	end)
end

-- Featured --------------------------------------------------------------------------------------------

-- A row of odds tiles for a crate: what can drop and how likely.
local function oddsRow(parent: Instance, crate: Store.Crate, tileSize: number): Frame
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, tileSize),
	}, parent)
	UiKit.list(row, 8, true)
	local total = 0
	for _, roll in crate.Rolls do
		total += roll.Weight
	end
	for i, roll in crate.Rolls do
		local rarity = roll.Cosmetic
			or (if roll.Reward and (roll.Reward.CutGems or roll.Reward.Marks) then "Uncommon" else "Common")
		local tile = ShopArt.rarityTile(row, rarity, tileSize)
		tile.LayoutOrder = i
		local kind = if roll.Cosmetic
			then "Cosmetic"
			elseif roll.Reward.CutGems then "CutGems"
			elseif roll.Reward.Stones then "Stones"
			elseif roll.Reward.Marks then "Marks"
			else "Materials"
		ShopArt.icon(tile, kind, nil, tileSize * 0.8).Position = UDim2.fromScale(0.5, 0.42)
		local pct = text(
			tile,
			string.format("%d%%", math.floor(roll.Weight / total * 100 + 0.5)),
			13,
			Color3.new(1, 1, 1),
			CHUNKY
		)
		pct.AnchorPoint = Vector2.new(0, 1)
		pct.Position = UDim2.new(0, 0, 1, -2)
		pct.TextXAlignment = Enum.TextXAlignment.Center
		local bob = new("UIScale", {}, tile)
		-- Tiles bob gently, one after another.
		local phase = i * 0.5
		IronUi.animate(tile, function(t)
			bob.Scale = 1 + math.sin(t * 3 + phase) * 0.03
		end)
	end
	return row
end

local function buyRow(parent: Instance, crate: Store.Crate)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 62),
	}, parent)
	UiKit.list(row, 12, true)
	for i, count in { 1, 5, 10 } do
		local slot = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(150, 62),
			LayoutOrder = i,
		}, row)
		local price = Store.cratePrice(crate, count) :: number
		local b
		b = IronUi.gemButton(slot, "💰 " .. commas(price), P.Emerald, function()
			run(b, string.format("+%d CRATE%s!", count, if count == 1 then "" else "S"), "BuyCrate", crate.Id, count)
		end)
		b.AutomaticSize = Enum.AutomaticSize.None
		b.Size = UDim2.new(1, 0, 0, 40)
		local label = text(
			slot,
			string.format("%d Crate%s", count, if count == 1 then "" else "s"),
			13,
			Color3.new(1, 1, 1),
			CHUNKY
		)
		label.Position = UDim2.fromOffset(0, 44)
		label.TextXAlignment = Enum.TextXAlignment.Center
		if count > 1 then
			local save = math.floor((1 - Store.CrateBulk[count] / count) * 100 + 0.5)
			ribbon(slot, string.format("-%d%%", save), P.Bad, 110, -12).TextSize = 12
		end
	end
	return row
end

local function drawFeatured()
	local geode = Store.Crates.GeodeCrate
	local hero = card(body, geode.Color)
	hero.Size = UDim2.new(1, 0, 0, 290)
	ribbon(hero, "SEASON 1", P.Amethyst, 14, 14)
	local art = ShopArt.crate(hero, 210, Color3.fromRGB(120, 240, 255))
	art.Position = UDim2.fromOffset(140, 150)
	-- The crate floats gently.
	IronUi.animate(art, function(t)
		art.Position = UDim2.fromOffset(140, 150 + math.sin(t * 2) * 5)
		art.Rotation = math.sin(t * 1.3) * 3
	end)
	local right = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(280, 16),
		Size = UDim2.new(1, -300, 1, -32),
	}, hero)
	UiKit.list(right, 10)
	local heading = title(right, "GEODE CRATE!", 38, P.Gold)
	heading.LayoutOrder = 1
	local blurb = text(right, geode.Description, 14, Color3.new(1, 1, 1), IronUi.Bold)
	blurb.LayoutOrder = 2
	oddsRow(right, geode, 62).LayoutOrder = 3
	buyRow(right, geode).LayoutOrder = 4
	robuxButton(right, geode.Id)

	-- Crates you own, ready to open.
	local have = (profile().Crates or {}).GeodeCrate or 0
	if have > 0 then
		local open = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
		}, hero)
		UiKit.list(open, 8, true)
		IronUi.gemButton(open, "OPEN 1", P.Gold:Lerp(Color3.fromRGB(255, 140, 0), 0.4), function()
			openCrates(geode, 1)
		end)
		if have > 1 then
			IronUi.gemButton(
				open,
				string.format("OPEN %d", math.min(have, 10)),
				Color3.fromRGB(230, 120, 30),
				function()
					openCrates(geode, math.min(have, 10))
				end
			)
		end
		local owned = text(hero, string.format("You have %d", have), 14, Color3.new(1, 1, 1), CHUNKY)
		owned.AnchorPoint = Vector2.new(1, 0)
		owned.Position = UDim2.new(1, -18, 0, 60)
		owned.Size = UDim2.fromOffset(200, 0)
		owned.TextXAlignment = Enum.TextXAlignment.Right
	end

	-- Two feature cards underneath.
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 304),
		Size = UDim2.new(1, 0, 1, -304),
	}, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -7, 1, 0),
		CellPadding = UDim2.fromOffset(14, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local master = Store.Crates.MasterworkCrate
	local mCard = card(row, master.Color, 1)
	local mArt = ShopArt.crate(mCard, 120, Color3.fromRGB(255, 190, 80))
	mArt.Position = UDim2.fromOffset(80, 92)
	local mInfo = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(150, 14),
		Size = UDim2.new(1, -164, 1, -28),
	}, mCard)
	UiKit.list(mInfo, 6)
	title(mInfo, "MASTERWORK CRATE", 22, Color3.new(1, 1, 1)).LayoutOrder = 1
	text(mInfo, master.Description, 12, Color3.new(1, 1, 1), IronUi.Bold).LayoutOrder = 2
	local mButtons = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3 }, mInfo)
	UiKit.list(mButtons, 8, true)
	local mBuy
	mBuy = IronUi.gemButton(mButtons, "💰 " .. commas(master.Price), P.Emerald, function()
		run(mBuy, "+1 CRATE!", "BuyCrate", master.Id, 1)
	end)
	local mHave = (profile().Crates or {}).MasterworkCrate or 0
	if mHave > 0 then
		IronUi.gemButton(mButtons, string.format("OPEN (%d)", mHave), Color3.fromRGB(230, 120, 30), function()
			openCrates(master, math.min(mHave, 10))
		end)
	end

	-- The Welcome Bundle while it lasts, otherwise the Legend Bundle.
	local left = welcomeSecondsLeft()
	local bundle = if left > 0 then Store.bundle("Welcome") else Store.bundle("Legend")
	if bundle then
		local bCard = card(row, bundle.Color, 2)
		emoji(bCard, bundle.Icon, 80, UDim2.fromOffset(78, 92))
		ribbon(bCard, bundle.Value, P.Bad, 12, 12)
		local bInfo = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(150, 14),
			Size = UDim2.new(1, -164, 1, -28),
		}, bCard)
		UiKit.list(bInfo, 6)
		title(bInfo, string.upper(bundle.Name), 22, Color3.new(1, 1, 1)).LayoutOrder = 1
		local sub = if left > 0 then "⏰ Ends in " .. clock(left) .. "  •  new players only" else bundle.Tagline
		text(bInfo, sub, 12, Color3.new(1, 1, 1), IronUi.Bold).LayoutOrder = 2
		local bButtons =
			new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3 }, bInfo)
		UiKit.list(bButtons, 8, true)
		local bBuy
		bBuy = IronUi.gemButton(bButtons, "💰 " .. commas(bundle.Price), P.Emerald, function()
			run(bBuy, "BUNDLE GET!", "BuyBundle", bundle.Id)
		end)
		robuxButton(bButtons, bundle.Id)
	end
end

-- Bundles ------------------------------------------------------------------------------------------------

local function drawBundles()
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -10, 1, 0),
		CellPadding = UDim2.fromOffset(15, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for i, bundle in Store.Bundles do
		if not bundle.NewPlayersOnly or welcomeSecondsLeft() > 0 then
			local c = card(row, bundle.Color, if bundle.NewPlayersOnly then 0 else i)
			ribbon(c, bundle.Value, P.Bad, 12, 12)
			local icon = emoji(c, bundle.Icon, 96, UDim2.new(0.5, 0, 0, 110))
			-- The icon breathes.
			IronUi.animate(icon, function(t)
				icon.Rotation = math.sin(t * 1.6 + i) * 6
			end)
			local info = new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(16, 176),
				Size = UDim2.new(1, -32, 1, -240),
			}, c)
			UiKit.list(info, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
			local name = title(info, string.upper(bundle.Name), 24, Color3.new(1, 1, 1))
			name.TextXAlignment = Enum.TextXAlignment.Center
			local tagline = text(info, bundle.Tagline, 13, Color3.new(1, 1, 1), IronUi.Bold)
			tagline.TextXAlignment = Enum.TextXAlignment.Center
			-- Contents as little chips.
			local chips = new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, info)
			local chipList = UiKit.list(chips, 6, true)
			chipList.Wraps = true
			chipList.HorizontalAlignment = Enum.HorizontalAlignment.Center
			for _, line in Store.describe(bundle.Contents, cosmeticName) do
				local chip = new("TextLabel", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.55,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 22),
					Text = line,
					Font = CHUNKY,
					TextSize = 12,
					TextColor3 = P.Gold,
				}, chips)
				UiKit.round(chip, 11)
				new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, chip)
			end
			local buttons = new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.new(1, -24, 0, 40),
			}, c)
			UiKit.list(buttons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
			local b
			b = IronUi.gemButton(buttons, "💰 " .. commas(bundle.Price), P.Emerald, function()
				run(b, "BUNDLE GET!", "BuyBundle", bundle.Id)
			end)
			robuxButton(buttons, bundle.Id)
		end
	end
end

-- Back pieces and trims -------------------------------------------------------------------------------------

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

	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 112),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, id in ids do
		local cosmetic = Cosmetics.List[id]
		local color = Cosmetics.rarityColor(cosmetic)
		local tile, face = IronUi.chunk(grid, {
			Color = color:Lerp(Color3.new(0, 0, 0), 0.15),
			Rim = if id == selected then P.Gold else color:Lerp(Color3.new(1, 1, 1), 0.5),
			Radius = 16,
			Lip = 6,
			Stripes = "None",
			Dots = true,
		})
		tile.LayoutOrder = i
		if id == selected then
			tile:FindFirstChildOfClass("UIStroke").Thickness = 4
		end
		ShopArt.icon(face, "Cosmetic", id, 80).Position = UDim2.fromScale(0.5, 0.4)
		local rarity = text(face, RARITY_NAMES[cosmetic.Rarity], 12, Color3.new(1, 1, 1), CHUNKY)
		rarity.AnchorPoint = Vector2.new(0, 1)
		rarity.Position = UDim2.new(0, 0, 1, -3)
		rarity.TextXAlignment = Enum.TextXAlignment.Center
		if id == worn then
			local check = IronUi.badge(tile, "✓", 28, P.Good)
			check.Position = UDim2.new(1, -32, 0, 4)
		elseif not owned[id] and not cosmetic.Price then
			local lock = text(tile, "🔒", 18, P.Text, CHUNKY)
			lock.Position = UDim2.fromOffset(6, 4)
			lock.Size = UDim2.fromOffset(22, 22)
		end
		tile.Activated:Connect(function()
			selected = id
			ShopUI.refresh()
		end)
	end

	-- The preview: a big glowing card.
	local cosmetic = Cosmetics.get(selected)
	if not cosmetic then
		return
	end
	local color = Cosmetics.rarityColor(cosmetic)
	local side = card(body, color)
	side.Position = UDim2.new(0.6, 16, 0, 0)
	side.Size = UDim2.new(0.4, -16, 1, 0)
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(190, 190),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
	}, side)
	UiKit.round(glow, 95)
	local stage = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(180, 180),
	}, side)
	ShopArt.icon(stage, "Cosmetic", cosmetic.Id, 160)
	IronUi.animate(stage, function(t)
		stage.Position = UDim2.new(0.5, 0, 0, 120 + math.sin(t * 2) * 6)
		stage.Rotation = math.sin(t * 1.2) * 5
	end)
	ribbon(side, string.upper(RARITY_NAMES[cosmetic.Rarity]), color:Lerp(Color3.new(0, 0, 0), 0.2), 12, 12)
	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 226),
		Size = UDim2.new(1, -32, 1, -290),
	}, side)
	UiKit.list(info, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local name = title(info, cosmetic.Name, 28, Color3.new(1, 1, 1))
	name.TextXAlignment = Enum.TextXAlignment.Center
	local description = text(info, cosmetic.Description, 14, Color3.new(1, 1, 1), IronUi.Bold)
	description.TextXAlignment = Enum.TextXAlignment.Center
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -24, 0, 40),
	}, side)
	UiKit.list(actions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	if owned[cosmetic.Id] then
		if worn == cosmetic.Id then
			IronUi.gemButton(actions, "TAKE OFF", Color3.fromRGB(110, 100, 130), function()
				run(nil, nil, "EquipCosmetic", kind, nil)
			end)
		else
			local b
			b = IronUi.gemButton(actions, "EQUIP", P.Emerald, function()
				run(b, "EQUIPPED!", "EquipCosmetic", kind, cosmetic.Id)
			end)
		end
	elseif cosmetic.Price then
		local b
		b = IronUi.gemButton(actions, "BUY  💰 " .. commas(cosmetic.Price), P.Emerald, function()
			run(b, "UNLOCKED!", "BuyCosmetic", cosmetic.Id)
		end)
	else
		local note = text(actions, "Found in crates and the Season Path", 14, P.Gold, CHUNKY)
		note.TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- Passes --------------------------------------------------------------------------------------------------

local function drawPasses()
	local c = card(body, Color3.fromRGB(210, 70, 170))
	c.Size = UDim2.new(0.55, 0, 1, 0)
	emoji(c, "👑", 110, UDim2.new(0.5, 0, 0, 100))
	ribbon(c, "BEST VALUE", P.Gold, 12, 12)
	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 170),
		Size = UDim2.new(1, -40, 1, -240),
	}, c)
	UiKit.list(info, 8).HorizontalAlignment = Enum.HorizontalAlignment.Center
	title(info, "VIP PASS", 34, Color3.new(1, 1, 1)).TextXAlignment = Enum.TextXAlignment.Center
	for _, perk in
		{
			"✦ Walk through the pink gate into the VIP pit",
			"✦ VIP nodes roll rarer colours and better grades",
			"✦ Support Brainrot Crusaders' development",
		}
	do
		text(info, perk, 15, Color3.new(1, 1, 1), CHUNKY).TextXAlignment = Enum.TextXAlignment.Center
	end
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(1, -24, 0, 40),
	}, c)
	UiKit.list(actions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	if player:GetAttribute("IsVIP") then
		title(actions, "✓ YOU'RE A VIP", 22, P.Good).TextXAlignment = Enum.TextXAlignment.Center
	elseif Config.VipGamePassId ~= 0 then
		IronUi.gemButton(actions, "GET VIP", P.Emerald, function()
			MarketplaceService:PromptGamePassPurchase(player, Config.VipGamePassId)
		end)
	else
		title(actions, "COMING SOON", 22, P.Gold).TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- Welcome popup ---------------------------------------------------------------------------------------------

local welcome = IronUi.window("WelcomeBundle", 12, 760, 420, "🎁", P.Teal)
welcome.Title.Text = "WELCOME BUNDLE"
welcome.Subtitle.Text = "Only for new players. One per player."
local welcomeTimer = text(welcome.Panel, "", 16, Color3.new(1, 1, 1), CHUNKY)
welcomeTimer.AnchorPoint = Vector2.new(1, 0)
welcomeTimer.Position = UDim2.new(1, -56, 0, 22)
welcomeTimer.Size = UDim2.fromOffset(220, 0)
welcomeTimer.TextXAlignment = Enum.TextXAlignment.Right
welcomeTimer.ZIndex = 4
local welcomeBody = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(26, 84),
	Size = UDim2.fromOffset(708, 312),
}, welcome.Panel)

function ShopUI.showWelcome()
	if welcomeSecondsLeft() <= 0 then
		return
	end
	clear(welcomeBody)
	local bundle = Store.bundle("Welcome")
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.58, 0, 1, 0) }, welcomeBody)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(128, 96),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, item in Store.items(bundle.Contents, cosmeticName) do
		rewardTile(grid, item, i)
	end
	local side = card(welcomeBody, bundle.Color)
	side.Position = UDim2.new(0.6, 0, 0, 0)
	side.Size = UDim2.new(0.4, 0, 1, 0)
	ribbon(side, bundle.Value, P.Bad, 12, 12)
	emoji(side, bundle.Icon, 120, UDim2.new(0.5, 0, 0, 120))
	local buttons = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -20, 0, 40),
	}, side)
	UiKit.list(buttons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	IronUi.gemButton(buttons, "💰 " .. commas(bundle.Price), P.Emerald, function()
		welcome.Gui.Enabled = false
		run(nil, nil, "BuyBundle", "Welcome")
	end)
	robuxButton(buttons, "Welcome")
	welcome.Gui.Enabled = true
end
welcome.Close.Activated:Connect(function()
	welcome.Gui.Enabled = false
end)
welcome.Shade.Activated:Connect(function()
	welcome.Gui.Enabled = false
end)

-- Drawing and opening ---------------------------------------------------------------------------------------

local DRAW = {
	Featured = drawFeatured,
	Bundles = drawBundles,
	Backs = function()
		drawCosmetics("Back")
	end,
	Trims = function()
		drawCosmetics("Trim")
	end,
	Passes = drawPasses,
}

function ShopUI.refresh()
	if not gui.Enabled then
		return
	end
	local p = profile()
	wallet.Text = string.format("💰 %s    🎖️ %s", commas(p.Coins or 0), commas(p.Marks or 0))
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
	-- Slide the new page in.
	body.Position = UDim2.fromOffset(46, 128)
	TweenService:Create(body, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(26, 128),
	}):Play()
end

function ShopUI.open(which: string?)
	if which and DRAW[which] then
		tab = which
	end
	gui.Enabled = true
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

-- Tick the welcome countdown.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	elapsed = 0
	if welcome.Gui.Enabled then
		local left = welcomeSecondsLeft()
		welcomeTimer.Text = if left > 0 then "⏰ Ends in " .. clock(left) else "Offer ended"
	end
end)

return ShopUI
