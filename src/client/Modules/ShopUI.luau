--[[
	The Supply Depot [B]: the station store, styled like the dashboard.
	  Featured      the Geode Crate: the cache, 1 / 5 / 10 purchase tiles and
	                its full drop table; then the Masterwork Crate and a bundle
	  Bundles       one card per bundle: contents with drawn icons, price
	  Back Pieces   a tile grid and a large preview; buy / equip / take off
	  Trims         the same, for glow colours
	  Passes        the VIP pass and the Season Path
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
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Season = require(ReplicatedStorage.Shared.Season)
local Store = require(ReplicatedStorage.Shared.Store)
local CrateReveal = require(script.Parent.CrateReveal)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local SeasonUI = require(script.Parent.SeasonUI)
local ShopArt = require(script.Parent.ShopArt)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new, clear = IronUi.new, IronUi.clear
local HEADING, BOLD, BODY, CHUNKY = IronUi.Heading, IronUi.Bold, IronUi.Body, IronUi.Chunky
local WHITE = Color3.new(1, 1, 1)

local WIDTH, HEIGHT = 1040, 640
local BODY_X, BODY_Y = 26, 132
local BODY_W, BODY_H = WIDTH - 52, HEIGHT - 156
local RARITY_NAMES = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare", UltraRare = "Ultra Rare" }
local TAB_LABELS = {
	Featured = "Featured",
	Bundles = "Bundles",
	Backs = "Back Pieces",
	Trims = "Trims",
	Passes = "Passes",
}

local ShopUI = {}

local window = IronUi.window("Shop", 10, WIDTH, HEIGHT, "◆", P.Amethyst)
local gui, panel = window.Gui, window.Panel
window.Title.Text = "SUPPLY DEPOT"
window.Subtitle.Text = "Supply caches, station cosmetics and bundles. Everything costs coins."

local tab = "Featured"
local selected: string? = nil
local busy = false

local tabBar = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(BODY_X, 80),
	Size = UDim2.fromOffset(BODY_W, 38),
}, panel)
local tabLine = new("Frame", {
	BackgroundColor3 = P.Edge,
	BackgroundTransparency = 0.55,
	Position = UDim2.fromOffset(BODY_X, 118),
	Size = UDim2.fromOffset(BODY_W, 1),
}, panel)
tabLine.Name = "TabRule"

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(BODY_X, BODY_Y),
	Size = UDim2.fromOffset(BODY_W, BODY_H),
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

local function rarityColor(rarity: string): Color3
	return GemConfig.TierColors[rarity] or P.Dim
end

local function place(object: GuiObject, x: number, y: number, w: number, h: number)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
end

-- A fixed-size label (IronUi.text grows to fit, which fights fixed layouts).
local function label(
	parent: Instance,
	value: string,
	size: number,
	color: Color3?,
	font: Enum.Font?,
	wrap: boolean?
): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color or P.Text,
		Font = font or BODY,
		TextWrapped = wrap == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if wrap then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
	}, parent)
end

-- The dashboard's panel: dark, tinted from the top, a thin edge and a lit rail.
local function panelCard(parent: Instance, tint: Color3, order: number?): Frame
	local frame = new("Frame", {
		BackgroundColor3 = WHITE,
		LayoutOrder = order or 0,
		ClipsDescendants = true,
	}, parent)
	UiKit.round(frame, 8)
	new("UIStroke", { Color = tint:Lerp(P.Edge, 0.45), Thickness = 1, Transparency = 0.2 }, frame)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(tint:Lerp(P.Inset, 0.72), P.Frame),
	}, frame)
	local rail = new("Frame", {
		BackgroundColor3 = tint,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -32, 0, 2),
	}, frame)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.3, 0),
			NumberSequenceKeypoint.new(1, 0.9),
		}),
	}, rail)
	return frame
end

-- A darker well for art to sit in, with a soft glow in the card's colour.
local function stage(parent: Instance, tint: Color3): Frame
	local well =
		new("Frame", { BackgroundColor3 = P.Frame, BackgroundTransparency = 0.25, ClipsDescendants = true }, parent)
	UiKit.round(well, 6)
	new("UIStroke", { Color = tint, Thickness = 1, Transparency = 0.7 }, well)
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.86,
	}, well)
	UiKit.round(glow, 999)
	-- Faint scan lines.
	for i = 1, 5 do
		new("Frame", {
			BackgroundColor3 = tint,
			BackgroundTransparency = 0.93,
			Position = UDim2.fromScale(0, i / 6),
			Size = UDim2.new(1, 0, 0, 1),
		}, well)
	end
	return well
end

-- A straight status chip, e.g. "SAVE 10%" or "NEW PLAYERS".
local function chip(parent: Instance, value: string, color: Color3, filled: boolean?): TextLabel
	local tag = new("TextLabel", {
		BackgroundColor3 = color,
		BackgroundTransparency = if filled == false then 0.82 else 0.05,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		Text = value,
		Font = BOLD,
		TextSize = 11,
		TextColor3 = if filled == false then color:Lerp(WHITE, 0.35) else P.Ink,
		ZIndex = 6,
	}, parent)
	UiKit.round(tag, 4)
	new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, tag)
	if filled == false then
		new("UIStroke", {
			Color = color,
			Thickness = 1,
			Transparency = 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, tag)
	end
	return tag
end

local function eyebrow(parent: Instance, value: string, color: Color3): TextLabel
	return label(parent, string.upper(value), 11, color, BOLD)
end

-- A coin, a number and "COINS" in a small inline group.
local function coinAmount(parent: Instance, amount: number, size: number, color: Color3?): Frame
	local group = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 4),
	}, parent)
	UiKit.list(group, 6, true)
	local holder =
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), LayoutOrder = 1 }, group)
	ShopArt.coin(holder, size)
	local value = label(group, commas(amount), size, color or WHITE, HEADING)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.Size = UDim2.fromOffset(0, size + 4)
	value.LayoutOrder = 2
	return group
end

-- The buy button: a coin and the price on an emerald slab.
local function priceButton(
	parent: Instance,
	price: number,
	width: number,
	height: number,
	onClick: () -> ()
): TextButton
	local b, face = IronUi.chunk(parent, {
		Color = P.Emerald,
		Size = UDim2.fromOffset(width, height),
		Radius = 8,
		Lip = 4,
		Dots = true,
	})
	b.Text = commas(price)
	b.TextTransparency = 1
	b:SetAttribute("UiSound", "Confirm")
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, face)
	local list = UiKit.list(row, 6, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local iconSize = math.floor(height * 0.42)
	local holder =
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(iconSize, iconSize), LayoutOrder = 1 }, row)
	ShopArt.coin(holder, iconSize)
	local value = label(row, commas(price), math.floor(height * 0.42), WHITE, HEADING)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.Size = UDim2.fromOffset(0, height - 6)
	value.LayoutOrder = 2
	b.Activated:Connect(onClick)
	return b
end

-- A secondary action, e.g. "OPEN 3".
local function actionButton(parent: Instance, caption: string, color: Color3, onClick: () -> ()): TextButton
	local b = IronUi.gemButton(parent, caption, color, onClick)
	b.Size = UDim2.fromOffset(0, 40)
	b.TextSize = 15
	return b
end

-- Text that floats up from a spot and fades, e.g. "+5 CRATES".
local function floatText(from: GuiObject, message: string, color: Color3)
	local float = IronUi.title(panel, message, 20, color)
	float.AutomaticSize = Enum.AutomaticSize.XY
	float.Size = UDim2.fromOffset(0, 0)
	float.AnchorPoint = Vector2.new(0.5, 1)
	local offset = from.AbsolutePosition - panel.AbsolutePosition
	local s = window.Scale.Scale
	float.Position = UDim2.fromOffset((offset.X + from.AbsoluteSize.X / 2) / s, offset.Y / s)
	float.ZIndex = 30
	TweenService:Create(float, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = float.Position - UDim2.fromOffset(0, 54),
		TextTransparency = 1,
	}):Play()
	task.delay(0.95, function()
		float:Destroy()
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

local function robuxButton(parent: Instance, key: string)
	local id = Store.RobuxProducts[key]
	if id and id ~= 0 then
		local b = actionButton(
			parent,
			string.format("R$ %d", Store.RobuxPrices[key] or 0),
			Color3.fromRGB(40, 170, 90),
			function()
				MarketplaceService:PromptProductPurchase(player, id)
			end
		)
		b.LayoutOrder = 5
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

-- One line of a crate's drop table: what it is, how it's drawn, its rarity.
type Drop = { Text: string, Kind: string, Rarity: string }
local function describeRoll(roll: Store.CrateRoll): Drop
	if roll.Cosmetic then
		return { Text = RARITY_NAMES[roll.Cosmetic] .. " cosmetic", Kind = "Cosmetic", Rarity = roll.Cosmetic }
	end
	local reward = roll.Reward or {}
	if reward.CutGems then
		return {
			Text = string.format("%d cut gem%s", reward.CutGems, if reward.CutGems == 1 then "" else "s"),
			Kind = "CutGems",
			Rarity = "Uncommon",
		}
	elseif reward.Stones then
		return {
			Text = string.format("%d ready gem%s", reward.Stones, if reward.Stones == 1 then "" else "s"),
			Kind = "Stones",
			Rarity = "Common",
		}
	elseif reward.Coins then
		return { Text = commas(reward.Coins) .. " coins", Kind = "Coins", Rarity = "Common" }
	end
	return { Text = "Supplies", Kind = "Materials", Rarity = "Common" }
end

-- The drop table: icon, name, chance and a bar, one row per roll.
local function dropTable(parent: Instance, crate: Store.Crate, rowHeight: number): Frame
	local list = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) }, parent)
	list.AutomaticSize = Enum.AutomaticSize.Y
	UiKit.list(list, 2)
	local total = 0
	for _, roll in crate.Rolls do
		total += roll.Weight
	end
	for i, roll in crate.Rolls do
		local drop = describeRoll(roll)
		local color = rarityColor(drop.Rarity)
		local chance = roll.Weight / total
		local row = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, rowHeight),
			LayoutOrder = i,
		}, list)
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.fromOffset(rowHeight - 6, rowHeight - 6),
		}, row)
		ShopArt.icon(holder, drop.Kind, nil, rowHeight - 6)
		local name = label(row, drop.Text, 12, if roll.Cosmetic then color else P.Text, CHUNKY)
		place(name, rowHeight + 2, 0, 160, rowHeight - 8)
		local pct = label(row, string.format("%d%%", math.floor(chance * 100 + 0.5)), 12, color, BOLD)
		pct.AnchorPoint = Vector2.new(1, 0)
		pct.Position = UDim2.new(1, 0, 0, 0)
		pct.Size = UDim2.fromOffset(40, rowHeight - 8)
		pct.TextXAlignment = Enum.TextXAlignment.Right
		local track = new("Frame", {
			BackgroundColor3 = P.Slot,
			Position = UDim2.new(0, rowHeight + 2, 1, -7),
			Size = UDim2.new(1, -(rowHeight + 2), 0, 3),
		}, row)
		UiKit.round(track, 2)
		-- Bars are scaled so the most common drop (about 40%) fills the track.
		local fill = new("Frame", {
			BackgroundColor3 = color,
			Size = UDim2.fromScale(math.clamp(chance / 0.4, 0.02, 1), 1),
		}, track)
		UiKit.round(fill, 2)
	end
	return list
end

-- Featured --------------------------------------------------------------------------------------------

-- Buying 1, 5 or 10: a tile each with the count, any saving, and the price.
local function purchaseTiles(parent: Instance, crate: Store.Crate, x: number, y: number)
	for i, count in { 1, 5, 10 } do
		local tile = new("Frame", {
			BackgroundColor3 = P.Frame,
			BackgroundTransparency = 0.2,
			Position = UDim2.fromOffset(x + (i - 1) * 126, y),
			Size = UDim2.fromOffset(116, 112),
		}, parent)
		UiKit.round(tile, 6)
		new("UIStroke", {
			Color = if count == 10 then P.Gold else P.Edge,
			Thickness = 1,
			Transparency = if count == 10 then 0.3 else 0.55,
		}, tile)
		local big = label(tile, "x" .. count, 26, WHITE, HEADING)
		place(big, 12, 12, 70, 30)
		local unit = label(tile, if count == 1 then "CRATE" else "CRATES", 10, P.Dim, BOLD)
		place(unit, 13, 42, 80, 12)
		if count > 1 then
			local save = math.floor((1 - Store.CrateBulk[count] / count) * 100 + 0.5)
			local saving = chip(tile, string.format("SAVE %d%%", save), if count == 10 then P.Gold else P.Teal)
			saving.AnchorPoint = Vector2.new(1, 0.5)
			saving.Position = UDim2.new(1, -8, 0, 0)
		end
		local price = Store.cratePrice(crate, count) :: number
		local b
		b = priceButton(tile, price, 100, 40, function()
			run(b, string.format("+%d CRATE%s", count, if count == 1 then "" else "S"), "BuyCrate", crate.Id, count)
		end)
		b.Position = UDim2.fromOffset(8, 62)
	end
end

-- Open buttons for crates already in the hold.
local function openRow(parent: Instance, crate: Store.Crate, have: number): Frame
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
	}, parent)
	UiKit.list(row, 8, true)
	local one = actionButton(row, "OPEN 1", Color3.fromRGB(230, 140, 40), function()
		openCrates(crate, 1)
	end)
	one.LayoutOrder = 1
	if have > 1 then
		local many = actionButton(row, string.format("OPEN %d", math.min(have, 10)), P.Gold, function()
			openCrates(crate, math.min(have, 10))
		end)
		many.LayoutOrder = 2
	end
	return row
end

local function drawFeatured()
	local geode = Store.Crates.GeodeCrate
	local crates = profile().Crates or {}
	local hero = panelCard(body, geode.Color)
	hero.Size = UDim2.fromOffset(BODY_W, 300)

	-- Left: the cache on its stage.
	local well = stage(hero, geode.Color)
	place(well, 14, 14, 270, 272)
	local seasonTag = chip(well, "SEASON 1", P.Amethyst)
	seasonTag.Position = UDim2.fromOffset(10, 10)
	local art = ShopArt.crate(well, 156, geode.Color)
	IronUi.animate(art, function(t)
		art.Position = UDim2.new(0.5, 0, 0, 106 + math.sin(t * 2) * 4)
	end)
	local have = crates.GeodeCrate or 0
	if have > 0 then
		local held = label(well, string.format("%d IN YOUR HOLD", have), 11, P.Gold, BOLD)
		place(held, 0, 202, 270, 14)
		held.TextXAlignment = Enum.TextXAlignment.Center
		local open = openRow(well, geode, have)
		open.AnchorPoint = Vector2.new(0.5, 0)
		open.Position = UDim2.fromOffset(135, 222)
	else
		local hint = label(well, "Open caches from your hold here", 12, P.Dim, BODY)
		place(hint, 0, 232, 270, 16)
		hint.TextXAlignment = Enum.TextXAlignment.Center
	end

	-- Middle: what it is, and the three ways to buy it.
	local info = eyebrow(hero, "Supply cache  ·  Lunar Frontier", geode.Color:Lerp(WHITE, 0.3))
	place(info, 304, 22, 380, 14)
	local name = label(hero, string.upper(geode.Name), 34, WHITE, HEADING)
	place(name, 302, 38, 390, 42)
	local blurb = label(hero, geode.Description, 14, P.Dim, BODY, true)
	place(blurb, 304, 84, 370, 40)
	purchaseTiles(hero, geode, 304, 150)
	robuxButton(hero, geode.Id)

	-- Right: the drop table.
	local divider = new("Frame", {
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.6,
		Position = UDim2.fromOffset(688, 22),
		Size = UDim2.fromOffset(1, 256),
	}, hero)
	divider.Name = "Divider"
	local oddsHead = eyebrow(hero, "Drop table", P.Gold)
	place(oddsHead, 708, 22, 200, 14)
	local column = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(706, 44),
		Size = UDim2.fromOffset(264, 240),
	}, hero)
	dropTable(column, geode, 33)

	-- Two feature cards underneath.
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 314),
		Size = UDim2.fromOffset(BODY_W, BODY_H - 314),
	}, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -7, 1, 0),
		CellPadding = UDim2.fromOffset(14, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)

	local master = Store.Crates.MasterworkCrate
	local mCard = panelCard(row, master.Color, 1)
	local mWell = stage(mCard, master.Color)
	place(mWell, 12, 12, 140, 146)
	ShopArt.crate(mWell, 118, master.Color).Position = UDim2.fromScale(0.5, 0.5)
	local mTag = eyebrow(mCard, "Deep-space cache", master.Color:Lerp(WHITE, 0.3))
	place(mTag, 168, 16, 300, 14)
	local mName = label(mCard, string.upper(master.Name), 20, WHITE, HEADING)
	place(mName, 168, 32, 300, 26)
	local mBlurb = label(mCard, master.Description, 12, P.Dim, BODY, true)
	place(mBlurb, 168, 60, 290, 32)
	local best = master.Rolls[#master.Rolls]
	local total = 0
	for _, roll in master.Rolls do
		total += roll.Weight
	end
	local odds = chip(
		mCard,
		string.format("%d%% %s", math.floor(best.Weight / total * 100 + 0.5), string.upper(describeRoll(best).Text)),
		rarityColor(best.Cosmetic or "Rare"),
		false
	)
	odds.Position = UDim2.fromOffset(168, 96)
	local mActions = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(168, 122),
		Size = UDim2.fromOffset(300, 40),
	}, mCard)
	UiKit.list(mActions, 8, true)
	local mBuy
	mBuy = priceButton(mActions, master.Price, 110, 38, function()
		run(mBuy, "+1 CRATE", "BuyCrate", master.Id, 1)
	end)
	mBuy.LayoutOrder = 1
	local mHave = crates.MasterworkCrate or 0
	if mHave > 0 then
		local mOpen = actionButton(mActions, string.format("OPEN (%d)", mHave), Color3.fromRGB(230, 140, 40), function()
			openCrates(master, math.min(mHave, 10))
		end)
		mOpen.LayoutOrder = 2
	end

	-- The Welcome Bundle while it lasts, otherwise the Legend Bundle.
	local left = welcomeSecondsLeft()
	local bundle = if left > 0 then Store.bundle("Welcome") else Store.bundle("Legend")
	if bundle then
		local bCard = panelCard(row, bundle.Color, 2)
		local bWell = stage(bCard, bundle.Color)
		place(bWell, 12, 12, 140, 146)
		local items = Store.items(bundle.Contents, cosmeticName)
		local lead = items[1]
		if lead then
			ShopArt.icon(bWell, lead.Kind, lead.Id, 96).Position = UDim2.fromScale(0.5, 0.48)
		end
		if items[2] then
			local side = ShopArt.icon(bWell, items[2].Kind, items[2].Id, 46)
			side.Position = UDim2.new(1, -28, 1, -28)
		end
		local bTag = eyebrow(
			bCard,
			if left > 0 then "New players  ·  ends in " .. clock(left) else "Bundle",
			if left > 0 then P.Gold else bundle.Color:Lerp(WHITE, 0.3)
		)
		place(bTag, 168, 16, 300, 14)
		local bName = label(bCard, string.upper(bundle.Name), 20, WHITE, HEADING)
		place(bName, 168, 32, 300, 26)
		local bBlurb = label(bCard, bundle.Tagline, 12, P.Dim, BODY, true)
		place(bBlurb, 168, 60, 290, 32)
		local value = chip(bCard, string.upper(bundle.Value), bundle.Color:Lerp(WHITE, 0.2), false)
		value.Position = UDim2.fromOffset(168, 96)
		local bActions = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(168, 122),
			Size = UDim2.fromOffset(300, 40),
		}, bCard)
		UiKit.list(bActions, 8, true)
		local bBuy
		bBuy = priceButton(bActions, bundle.Price, 110, 38, function()
			run(bBuy, "BUNDLE ADDED", "BuyBundle", bundle.Id)
		end)
		bBuy.LayoutOrder = 1
		robuxButton(bActions, bundle.Id)
	end
end

-- Bundles ------------------------------------------------------------------------------------------------

local function drawBundles()
	local p = profile()
	local owned = p.Cosmetics and p.Cosmetics.Owned or {}
	local list = {}
	for i, bundle in Store.Bundles do
		if not bundle.NewPlayersOnly or welcomeSecondsLeft() > 0 then
			table.insert(list, { Bundle = bundle, Order = if bundle.NewPlayersOnly then 0 else i })
		end
	end
	local columns = #list
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(BODY_W, BODY_H) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / columns, -12, 1, 0),
		CellPadding = UDim2.fromOffset(14, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for _, entry in list do
		local bundle = entry.Bundle
		local c = panelCard(row, bundle.Color, entry.Order)
		local well = stage(c, bundle.Color)
		well.Position = UDim2.fromOffset(12, 12)
		well.Size = UDim2.new(1, -24, 0, 150)
		local items = Store.items(bundle.Contents, cosmeticName)
		local lead = items[1]
		if lead then
			local icon = ShopArt.icon(well, lead.Kind, lead.Id, 104)
			icon.Position = UDim2.fromScale(0.5, 0.52)
			IronUi.animate(icon, function(t)
				icon.Position = UDim2.new(0.5, 0, 0.52, math.sin(t * 1.8 + entry.Order) * 3)
			end)
		end
		if items[2] then
			ShopArt.icon(well, items[2].Kind, items[2].Id, 48).Position = UDim2.new(1, -32, 1, -30)
		end
		local value = chip(well, string.upper(bundle.Value), bundle.Color:Lerp(WHITE, 0.25))
		value.Position = UDim2.fromOffset(8, 8)
		if bundle.NewPlayersOnly then
			local timer = chip(well, clock(welcomeSecondsLeft()), P.Gold, false)
			timer.AnchorPoint = Vector2.new(1, 0)
			timer.Position = UDim2.new(1, -8, 0, 8)
		end
		local name = label(c, string.upper(bundle.Name), 17, WHITE, HEADING, true)
		name.Position = UDim2.fromOffset(16, 174)
		name.Size = UDim2.new(1, -32, 0, 40)
		local tagline = label(c, bundle.Tagline, 12, P.Dim, BODY, true)
		tagline.Position = UDim2.fromOffset(16, 214)
		tagline.Size = UDim2.new(1, -32, 0, 46)
		-- Contents, one line each with a small icon.
		local contents = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 266),
			Size = UDim2.new(1, -32, 0, 140),
		}, c)
		UiKit.list(contents, 6)
		local head = eyebrow(contents, "Contains", P.Gold)
		head.Size = UDim2.new(1, 0, 0, 14)
		for i, item in items do
			local line = new("Frame", {
				BackgroundColor3 = P.Frame,
				BackgroundTransparency = 0.35,
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = i,
			}, contents)
			UiKit.round(line, 4)
			local holder = new(
				"Frame",
				{ BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(24, 24) },
				line
			)
			ShopArt.icon(holder, item.Kind, item.Id, 24)
			local text = label(line, item.Text, 12, WHITE, CHUNKY)
			place(text, 34, 0, 150, 30)
			text.TextTruncate = Enum.TextTruncate.AtEnd
			if item.Kind == "Cosmetic" and item.Id and owned[item.Id] then
				local have = chip(line, "OWNED", P.Good, false)
				have.AnchorPoint = Vector2.new(1, 0.5)
				have.Position = UDim2.new(1, -6, 0.5, 0)
			end
		end
		local buttons = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -28, 0, 42),
		}, c)
		UiKit.list(buttons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
		local b
		b = priceButton(buttons, bundle.Price, 140, 42, function()
			run(b, "BUNDLE ADDED", "BuyBundle", bundle.Id)
		end)
		b.LayoutOrder = 1
		robuxButton(buttons, bundle.Id)
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

	local GRID_W = 588
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(GRID_W, BODY_H) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(138, 150),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, id in ids do
		local cosmetic = Cosmetics.List[id]
		local color = Cosmetics.rarityColor(cosmetic)
		local isSelected = id == selected
		local tile = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = WHITE,
			LayoutOrder = i,
		}, grid)
		UiKit.round(tile, 8)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(P.Inset, 0.7), P.Frame) }, tile)
		new("UIStroke", {
			Color = if isSelected then P.Gold else color,
			Thickness = if isSelected then 2 else 1,
			Transparency = if isSelected then 0 else 0.55,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, tile)
		IronUi.highlight(tile)
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(32, 18),
			Size = UDim2.fromOffset(74, 74),
		}, tile)
		ShopArt.icon(holder, "Cosmetic", id, 74)
		local name = label(tile, cosmetic.Name, 12, WHITE, CHUNKY)
		place(name, 8, 94, 122, 16)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		-- Status line: equipped, owned, a price, or where to find it.
		local status = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 116),
			Size = UDim2.new(1, 0, 0, 24),
		}, tile)
		UiKit.list(status, 4, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
		if id == worn then
			chip(status, "EQUIPPED", P.Good)
		elseif owned[id] then
			chip(status, "OWNED", P.Good, false)
		elseif cosmetic.Price then
			coinAmount(status, cosmetic.Price, 14, P.Gold)
		elseif cosmetic.Exclusive == "Referral" then
			chip(status, "INVITE A FRIEND", P.Teal, false)
		else
			chip(status, "CRATE / SEASON", P.Dim, false)
		end
		local rarity = label(tile, string.upper(RARITY_NAMES[cosmetic.Rarity]), 9, color, BOLD)
		place(rarity, 8, 6, 120, 12)
		tile.Activated:Connect(function()
			selected = id
			ShopUI.refresh()
		end)
	end

	-- How much of this collection you have, under the grid.
	local have = 0
	for _, id in ids do
		if owned[id] then
			have += 1
		end
	end
	local footer = new("Frame", {
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(0, BODY_H - 58),
		Size = UDim2.fromOffset(GRID_W, 58),
	}, body)
	UiKit.round(footer, 8)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.6 }, footer)
	local footHead = eyebrow(footer, if kind == "Back" then "Back piece collection" else "Trim collection", P.Gold)
	place(footHead, 16, 10, 260, 14)
	local footCount = label(footer, string.format("%d / %d", have, #ids), 14, WHITE, HEADING)
	footCount.AnchorPoint = Vector2.new(1, 0)
	footCount.Position = UDim2.new(1, -16, 0, 6)
	footCount.Size = UDim2.fromOffset(80, 20)
	footCount.TextXAlignment = Enum.TextXAlignment.Right
	local footTrack = new("Frame", {
		BackgroundColor3 = P.Slot,
		Position = UDim2.fromOffset(16, 32),
		Size = UDim2.new(1, -32, 0, 6),
	}, footer)
	UiKit.round(footTrack, 3)
	local footFill = new("Frame", {
		BackgroundColor3 = P.Gold,
		Size = UDim2.fromScale(if #ids > 0 then math.max(have / #ids, 0.01) else 0, 1),
	}, footTrack)
	UiKit.round(footFill, 3)
	new("UIGradient", { Color = ColorSequence.new(P.Gold, Color3.fromRGB(240, 140, 50)) }, footFill)
	local wornLine = label(footer, "Wearing: " .. (if worn then cosmeticName(worn) else "nothing"), 11, P.Dim, CHUNKY)
	place(wornLine, 16, 40, 400, 14)

	-- The preview card.
	local cosmetic = Cosmetics.get(selected)
	if not cosmetic then
		return
	end
	local color = Cosmetics.rarityColor(cosmetic)
	local side = panelCard(body, color)
	place(side, GRID_W + 16, 0, BODY_W - GRID_W - 16, BODY_H)
	local well = stage(side, color)
	well.Position = UDim2.fromOffset(14, 14)
	well.Size = UDim2.new(1, -28, 0, 220)
	local art = ShopArt.icon(well, "Cosmetic", cosmetic.Id, 170)
	IronUi.animate(art, function(t)
		art.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2) * 5)
	end)
	local rarityTag = chip(well, string.upper(RARITY_NAMES[cosmetic.Rarity]), color)
	rarityTag.Position = UDim2.fromOffset(10, 10)
	local kindTag = chip(well, if kind == "Back" then "BACK PIECE" else "TRIM", P.Dim, false)
	kindTag.AnchorPoint = Vector2.new(1, 0)
	kindTag.Position = UDim2.new(1, -10, 0, 10)
	local name = label(side, cosmetic.Name, 26, WHITE, HEADING)
	name.Position = UDim2.fromOffset(20, 248)
	name.Size = UDim2.new(1, -40, 0, 32)
	local description = label(side, cosmetic.Description, 14, P.Dim, BODY, true)
	description.Position = UDim2.fromOffset(20, 284)
	description.Size = UDim2.new(1, -40, 0, 44)
	local source = label(
		side,
		if owned[cosmetic.Id]
			then (if worn == cosmetic.Id then "Equipped on your suit." else "In your collection.")
			elseif cosmetic.Price then "Sold here for coins."
			elseif cosmetic.Exclusive == "Referral" then "Earned by inviting a friend who joins."
			else "Found in supply caches and on the Season Path.",
		12,
		if owned[cosmetic.Id] then P.Good else P.Gold,
		CHUNKY
	)
	source.Position = UDim2.fromOffset(20, 336)
	source.Size = UDim2.new(1, -40, 0, 16)
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -28, 0, 46),
	}, side)
	UiKit.list(actions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	if owned[cosmetic.Id] then
		if worn == cosmetic.Id then
			IronUi.gemButton(actions, "TAKE OFF", Color3.fromRGB(110, 100, 130), function()
				run(nil, nil, "EquipCosmetic", kind, nil)
			end)
		else
			local b
			b = IronUi.gemButton(actions, "EQUIP", P.Teal, function()
				run(b, "EQUIPPED", "EquipCosmetic", kind, cosmetic.Id)
			end)
			b:SetAttribute("UiSound", "Confirm")
		end
	elseif cosmetic.Price then
		local b
		b = priceButton(actions, cosmetic.Price, 180, 46, function()
			run(b, "UNLOCKED", "BuyCosmetic", cosmetic.Id)
		end)
	elseif cosmetic.Exclusive == "Referral" then
		local b = IronUi.gemButton(actions, "INVITE A FRIEND", P.Teal, function()
			require(script.Parent.ReferralUI).open()
		end)
		b:SetAttribute("UiSound", "Tab")
	else
		local b = IronUi.gemButton(actions, "VIEW SUPPLY CACHES", P.Amethyst, function()
			tab = "Featured"
			selected = nil
			ShopUI.refresh()
		end)
		b:SetAttribute("UiSound", "Tab")
	end
end

-- Passes --------------------------------------------------------------------------------------------------

local function benefitList(parent: Instance, benefits: { string }, color: Color3, y: number)
	local list = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, y),
		Size = UDim2.new(1, -48, 0, 150),
	}, parent)
	UiKit.list(list, 10)
	for i, benefit in benefits do
		local line = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i }, list)
		local dot = new("Frame", {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(6, 10),
			Size = UDim2.fromOffset(7, 7),
			Rotation = 45,
		}, line)
		UiKit.round(dot, 1)
		local text = label(line, benefit, 14, P.Text, BODY)
		place(text, 20, 0, 400, 20)
	end
end

local function drawPasses()
	local half = (BODY_W - 14) / 2
	-- VIP.
	local vipColor = Color3.fromRGB(230, 90, 190)
	local c = panelCard(body, vipColor)
	place(c, 0, 0, half, BODY_H)
	local well = stage(c, vipColor)
	place(well, 14, 14, half - 28, 170)
	local crown = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(120, 120) }, well)
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Position = UDim2.fromScale(0.5, 0.5)
	-- A drawn crest: a gem over a shield-shaped plate.
	local plate = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45,
		BackgroundColor3 = WHITE,
	}, crown)
	UiKit.round(plate, 10)
	new(
		"UIGradient",
		{ Rotation = 45, Color = ColorSequence.new(vipColor:Lerp(WHITE, 0.4), vipColor:Lerp(P.Frame, 0.5)) },
		plate
	)
	new("UIStroke", { Color = P.Gold, Thickness = 2 }, plate)
	ShopArt.icon(crown, "CutGems", nil, 64)
	local best = chip(well, "BEST VALUE", P.Gold)
	best.Position = UDim2.fromOffset(10, 10)
	local name = label(c, "VIP PASS", 28, WHITE, HEADING)
	place(name, 24, 198, 300, 34)
	benefitList(c, {
		"Entry to the VIP shaft at the moon base",
		"VIP seams roll rarer colours and better grades",
		"Support Saga Miners' development",
	}, vipColor, 244)
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -28, 0, 46),
	}, c)
	UiKit.list(actions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	if player:GetAttribute("IsVIP") then
		chip(actions, "VIP ACTIVE", P.Good)
	elseif Config.VipGamePassId ~= 0 then
		IronUi.gemButton(actions, "GET VIP", P.Emerald, function()
			MarketplaceService:PromptGamePassPurchase(player, Config.VipGamePassId)
		end)
	else
		chip(actions, "COMING SOON", P.Gold, false).TextSize = 14
	end

	-- The Season Path: free rewards for playing (menu mode has no HUD button).
	local seasonColor = P.Teal
	local s = panelCard(body, seasonColor)
	place(s, half + 14, 0, half, BODY_H)
	local sWell = stage(s, seasonColor)
	place(sWell, 14, 14, half - 28, 170)
	local seasonData = profile().Season or { XP = 0, Claimed = {} }
	local level, into, need = Season.levelFor(seasonData.XP or 0)
	local big = label(sWell, "LV " .. level, 54, WHITE, HEADING)
	place(big, 0, 34, half - 28, 64)
	big.TextXAlignment = Enum.TextXAlignment.Center
	local track = new("Frame", {
		BackgroundColor3 = P.Slot,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(260, 8),
	}, sWell)
	UiKit.round(track, 4)
	local fill = new("Frame", {
		BackgroundColor3 = seasonColor,
		Size = UDim2.fromScale(if level >= Season.MaxLevel then 1 else math.clamp(into / need, 0, 1), 1),
	}, track)
	UiKit.round(fill, 4)
	new("UIGradient", { Color = ColorSequence.new(seasonColor, P.Emerald) }, fill)
	local xp = label(
		sWell,
		if level >= Season.MaxLevel then "MAX LEVEL" else string.format("%d / %d XP to level %d", into, need, level + 1),
		12,
		P.Dim,
		CHUNKY
	)
	place(xp, 0, 122, half - 28, 16)
	xp.TextXAlignment = Enum.TextXAlignment.Center
	local free = chip(sWell, "FREE", seasonColor)
	free.Position = UDim2.fromOffset(10, 10)
	local sName = label(s, string.upper(Season.Name), 22, WHITE, HEADING)
	place(sName, 24, 198, half - 48, 34)
	benefitList(s, {
		"Earn XP from mining, duels and daily visits",
		"Coins, caches, cut gems and cosmetics every level",
		"Exclusive trims and back pieces at levels 5 to 30",
	}, seasonColor, 244)
	local sActions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -28, 0, 46),
	}, s)
	UiKit.list(sActions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local unclaimed = 0
	for l = 1, level do
		if not (seasonData.Claimed or {})[tostring(l)] then
			unclaimed += 1
		end
	end
	local open = IronUi.gemButton(
		sActions,
		if unclaimed > 0
			then string.format("CLAIM %d REWARD%s", unclaimed, if unclaimed == 1 then "" else "S")
			else "OPEN SEASON PATH",
		if unclaimed > 0 then P.Gold:Lerp(Color3.fromRGB(230, 120, 30), 0.4) else P.Teal,
		function()
			ShopUI.close()
			SeasonUI.open()
		end
	)
	open:SetAttribute("UiSound", "Open")
end

-- Tabs and wallet ------------------------------------------------------------------------------------

local function drawTabs()
	clear(tabBar)
	UiKit.list(tabBar, 6, true)
	for i, id in Store.Tabs do
		local on = id == tab
		local b = new("TextButton", {
			Text = TAB_LABELS[id] or id,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 36),
			BackgroundColor3 = if on then P.Amethyst:Lerp(P.Inset, 0.45) else P.Frame,
			BackgroundTransparency = if on then 0 else 0.3,
			Font = if on then BOLD else CHUNKY,
			TextSize = 15,
			TextColor3 = if on then WHITE else P.Dim,
			LayoutOrder = i,
		}, tabBar)
		UiKit.round(b, 6)
		new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, b)
		new("UIStroke", {
			Color = if on then P.Amethyst:Lerp(WHITE, 0.3) else P.Edge,
			Thickness = 1,
			Transparency = if on then 0.2 else 0.65,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, b)
		if on then
			local underline = new("Frame", {
				BackgroundColor3 = P.Gold,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 2),
			}, b)
			UiKit.round(underline, 1)
		end
		b:SetAttribute("UiSound", "Tab")
		IronUi.highlight(b)
		b.Activated:Connect(function()
			if tab ~= id then
				tab = id
				selected = nil
				ShopUI.refresh()
			end
		end)
	end
end

-- Coins, top right beside the close button.
local wallet = new("Frame", {
	BackgroundColor3 = P.Frame,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -62, 0, 18),
	Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 4,
}, panel)
UiKit.round(wallet, 6)
new("UIStroke", { Color = IronUi.mute(P.Gold), Thickness = 1, Transparency = 0.45 }, wallet)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }, wallet)
UiKit.list(wallet, 8, true)
local walletCoin =
	new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20), LayoutOrder = 1 }, wallet)
ShopArt.coin(walletCoin, 20)
local walletValue = label(wallet, "0", 18, WHITE, HEADING)
walletValue.AutomaticSize = Enum.AutomaticSize.X
walletValue.Size = UDim2.fromOffset(0, 36)
walletValue.LayoutOrder = 2
local walletUnit = label(wallet, "COINS", 11, P.Gold, BOLD)
walletUnit.AutomaticSize = Enum.AutomaticSize.X
walletUnit.Size = UDim2.fromOffset(0, 36)
walletUnit.LayoutOrder = 3

-- Welcome popup ---------------------------------------------------------------------------------------------

local welcome = IronUi.window("WelcomeBundle", 12, 760, 420, "◆", P.Teal)
welcome.Title.Text = "WELCOME BUNDLE"
welcome.Subtitle.Text = "For new Saga Miners. One per player."
local welcomeTimer = label(welcome.Panel, "", 13, P.Gold, BOLD)
welcomeTimer.AnchorPoint = Vector2.new(1, 0)
welcomeTimer.Position = UDim2.new(1, -62, 0, 26)
welcomeTimer.Size = UDim2.fromOffset(220, 20)
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
	local items = Store.items(bundle.Contents, cosmeticName)
	-- Left: what's inside, one large tile per item.
	local left = panelCard(welcomeBody, bundle.Color)
	place(left, 0, 0, 420, 312)
	local head = eyebrow(left, "Inside the bundle", P.Gold)
	place(head, 18, 16, 300, 14)
	local grid = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 40), Size = UDim2.fromOffset(388, 256) },
		left
	)
	local rows = math.max(1, math.ceil(#items / 2))
	local cellHeight = math.floor((256 - 14 * (rows - 1)) / rows)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(186, cellHeight),
		CellPadding = UDim2.fromOffset(14, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local iconSize = math.min(110, cellHeight - 60)
	for i, item in items do
		local tile = stage(grid, ShopArt.KindColors[item.Kind] or bundle.Color)
		tile.LayoutOrder = i
		ShopArt.icon(tile, item.Kind, item.Id, iconSize).Position = UDim2.new(0.5, 0, 0.5, -14)
		local name = label(tile, item.Text, 14, WHITE, CHUNKY)
		name.AnchorPoint = Vector2.new(0, 1)
		name.Position = UDim2.new(0, 6, 1, -12)
		name.Size = UDim2.new(1, -12, 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Center
	end
	-- Right: the offer.
	local side = panelCard(welcomeBody, bundle.Color)
	place(side, 434, 0, 274, 312)
	local tag = chip(side, string.upper(bundle.Value), bundle.Color:Lerp(WHITE, 0.25))
	tag.Position = UDim2.fromOffset(16, 16)
	local name = label(side, string.upper(bundle.Name), 22, WHITE, HEADING)
	place(name, 16, 48, 240, 28)
	local blurb = label(side, bundle.Tagline, 13, P.Dim, BODY, true)
	place(blurb, 16, 80, 240, 54)
	local once = chip(side, "ONE TIME OFFER", P.Gold, false)
	once.Position = UDim2.fromOffset(16, 140)
	local count = label(side, string.format("%d items, yours to keep", #items), 13, P.Text, CHUNKY)
	place(count, 16, 172, 240, 18)
	local buttons = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -28, 0, 46),
	}, side)
	UiKit.list(buttons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	priceButton(buttons, bundle.Price, 150, 46, function()
		welcome.Gui.Enabled = false
		run(nil, nil, "BuyBundle", "Welcome")
	end).LayoutOrder =
		1
	robuxButton(buttons, "Welcome")
	welcomeTimer.Text = "ENDS IN " .. clock(welcomeSecondsLeft())
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
	walletValue.Text = commas(p.Coins or 0)
	drawTabs()
	clear(body)
	DRAW[tab]()
	-- Fade the new page up.
	body.Position = UDim2.fromOffset(BODY_X, BODY_Y + 10)
	TweenService:Create(body, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(BODY_X, BODY_Y),
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
		welcomeTimer.Text = if left > 0 then "ENDS IN " .. clock(left) else "OFFER ENDED"
	end
end)

return ShopUI
