--[[
	The Market board: browse what everyone has up (any server), buy for
	coins or make a trade offer; put your own gear and gems up; and answer
	offers on your listings. Listed and offered items wait in escrow, out of
	your bag, until they sell, trade or come back (see Shared.Market).

	  BROWSE       everyone's listings, filtered by GEAR / GEMS / POWERS
	  SELL         pick an item, set a price or open it to trade, list it
	  MY LISTINGS  your listings with their offers, and your offers out
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Rules = require(ReplicatedStorage.Shared.Market)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GearArt = require(script.Parent.GearArt)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local MarketBoardUI = {}

local P = IronUi.Colors
local new = IronUi.new
local BOLD, BODY = IronUi.Bold, IronUi.Body
local GOLD = Color3.fromRGB(232, 168, 52)
local TRADE = Color3.fromRGB(110, 170, 255)
local READY = Color3.fromRGB(64, 196, 110)
local PANEL = Color3.fromRGB(16, 18, 32)
local W, H = 900, 640

local window = IronUi.window("MarketBoard", 10, W, H, "⚖", GOLD)
window.Title.Text = "MARKET"
window.Subtitle.Text = "Buy, sell and trade with players on every server."

local bar = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 78),
	Size = UDim2.fromOffset(860, 46),
}, window.Panel)
local content = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 134),
	Size = UDim2.fromOffset(860, 490),
}, window.Panel)

local tab = "Browse"
local filter = "All" -- All / Gear / Gems / Powers
local mode = "All" -- All / Sell / Trade (browse)
local listings, shared, serverNow, fetchedAt = {}, true, os.time(), 0
local sellPick = nil -- { Kind, Slot?, Id }
local sellMode, sellPrice, sellWant = "Sell", 100, "Any"
local offerFor = nil -- a listing we're picking an offer for
local inspect = nil -- a listing shown up close
local busy = false
local draw

-- Building blocks ----------------------------------------------------------------

local function label(parent, value, size, color, font, x, y, w, h, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color or P.Text,
		Font = font or BODY,
		Position = UDim2.fromOffset(x or 0, y or 0),
		Size = UDim2.fromOffset(w or 100, h or size + 4),
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function panel(parent, x, y, w, h, color)
	local f = new("Frame", {
		BackgroundColor3 = color or PANEL,
		BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	UiKit.round(f, 8)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.4 }, f)
	return f
end

local function button(parent, value, color, x, y, w, h, callback)
	local b, face = IronUi.chunk(parent, {
		Color = color,
		Size = UDim2.fromOffset(w, h),
		Radius = 8,
		Lip = 3,
		Stripes = "None",
	})
	b.Position = UDim2.fromOffset(x, y)
	IronUi.label(b, face, value, if h < 34 then 13 else 15)
	b:SetAttribute("UiSound", "Confirm")
	b.Activated:Connect(callback)
	return b
end

-- A small rounded toggle chip.
local function chip(parent, value, on, color, x, y, w, callback)
	local c = new("TextButton", {
		Text = value,
		TextSize = 12,
		Font = BOLD,
		TextColor3 = if on then P.Text else P.Dim,
		AutoButtonColor = false,
		BackgroundColor3 = if on then color:Lerp(PANEL, 0.55) else P.Inset,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 26),
	}, parent)
	UiKit.round(c, 13)
	new("UIStroke", {
		Color = if on then color else P.Edge,
		Transparency = if on then 0 else 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, c)
	IronUi.highlight(c)
	c:SetAttribute("UiSound", "Tab")
	c.Activated:Connect(callback)
	return c
end

local function scroller(parent, x, y, w, h)
	return new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = P.Edge,
	}, parent)
end

-- Items ---------------------------------------------------------------------------

local function gearOf(payload)
	local profile = GemClient.Profile
	local def = Slots.Definitions[payload.Slot]
	local class = profile and profile.Character and profile.Character.Class or Config.OnlyClass or "Warrior"
	return def and Classes.gear(class, def.Kind, payload.Id)
end

local function surgeName(gem): string?
	if not gem.Cut then
		return nil
	end
	local ok, id = pcall(Tech.surgeOf, gem)
	if not ok or not id then
		return nil
	end
	local surge = Tech.Catalog and Tech.Catalog[id]
	return surge and surge.Name or id
end

local function itemName(payload): string
	if payload.Kind == "Gem" then
		return GemConfig.displayName(payload.Gem)
	end
	local gear = gearOf(payload)
	return if gear then gear.Name else tostring(payload.Id)
end

local function itemColor(payload): Color3
	if payload.Kind == "Gem" then
		return GemConfig.shade(payload.Gem).Color
	end
	local rarity = GearRolls.Rarities[payload.Roll and payload.Roll.Rarity or 1] or GearRolls.Rarities[1]
	return rarity.Color
end

local function itemLine(payload): string
	if payload.Kind == "Gem" then
		local gem = payload.Gem
		local tier = GemConfig.TierLabels[gem.Tier] or gem.Tier
		local surge = surgeName(gem)
		local line = tier .. " gem" .. (if surge then "  ·  Power: " .. surge else "  ·  Rough")
		return if payload.Where then line .. "  ·  " .. payload.Where else line
	end
	local rarity = GearRolls.Rarities[payload.Roll and payload.Roll.Rarity or 1] or GearRolls.Rarities[1]
	local def = Slots.Definitions[payload.Slot]
	return rarity.Name
		.. " "
		.. (def and def.Label or payload.Slot)
		.. (if payload.Gem then "  ·  ◆ socketed" else "")
end

-- The item's picture. Gems are drawn in 3D from their data; gear comes
-- from the server's 3D previews: your own pieces by their key, Market
-- pieces as "M:<listing>[:<offer>]" (MarketPreviews). A drawn silhouette
-- stands in until a preview arrives.
local function itemIcon(parent, payload, x, y, size, preview: string?)
	local stage = new("Frame", {
		BackgroundColor3 = itemColor(payload):Lerp(P.Frame, 0.78),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		ClipsDescendants = true,
	}, parent)
	UiKit.round(stage, 8)
	new("UIStroke", { Color = itemColor(payload), Thickness = 1.5, Transparency = 0.2 }, stage)
	if payload.Kind == "Gem" then
		local ok = pcall(GemArt.viewport, stage, payload.Gem, size >= 120)
		if not ok then
			local swatch = UiKit.swatch(stage, GemConfig.shade(payload.Gem), math.floor(size * 0.46))
			swatch.AnchorPoint = Vector2.new(0.5, 0.5)
			swatch.Position = UDim2.fromScale(0.5, 0.5)
		end
		return stage
	end
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(185, 190, 210),
		LightColor = Color3.fromRGB(255, 235, 201),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, stage)
	local drawn = preview ~= nil and GearArt.draw(view, payload.Slot, preview, false)
	view.Visible = drawn == true
	if not drawn then
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 26),
		}, stage)
		new("UIScale", { Scale = size / 40 }, holder)
		local icon = GearArt.icon(holder, payload.Slot, gearOf(payload) or {}, itemColor(payload))
		if icon then
			icon.Position = UDim2.new()
		end
	end
	return stage
end

-- Everything there is to know about a piece, line by line, in the
-- inventory's style: stats in green, the perk in gold, affixes and the
-- socket in their element's colour, then the roll's finish and serial.
local function detailLines(payload)
	local lines = {}
	local function add(value, size, color, font)
		table.insert(lines, { value, size, color, font or BODY })
	end
	if payload.Kind == "Gem" then
		local gem = payload.Gem
		add(GemConfig.displayName(gem), 16, itemColor(payload), BOLD)
		add(
			(GemConfig.TierLabels[gem.Tier] or gem.Tier) .. " gem  ·  " .. GemConfig.elementName(gem.Element),
			12,
			P.Dim,
			BOLD
		)
		local surge = surgeName(gem)
		add(
			if surge then "Power: " .. surge .. " (on Q · E · R)" else "Rough: cut it to unlock its power",
			13,
			P.Gold,
			BOLD
		)
		for _, metric in GemConfig.MetricOrder do
			local grade = gem[metric]
			if grade then
				add(
					string.format(
						"%s %s/10  ·  %s",
						GemConfig.MetricLabels[metric],
						tostring(grade),
						string.lower(GemConfig.MetricRoles[metric])
					),
					13,
					P.Good,
					BOLD
				)
			end
		end
		local ok, worth = pcall(GemConfig.value, gem)
		if ok and worth then
			add("Worth about " .. worth .. " coins", 12, P.Dim)
		end
		if payload.Where then
			add("Now " .. payload.Where .. " (listing takes it out)", 12, P.Dim)
		end
		return lines
	end
	local gear = gearOf(payload)
	local roll = payload.Roll
	local rarity = GearRolls.Rarities[roll and roll.Rarity or 1] or GearRolls.Rarities[1]
	local def = Slots.Definitions[payload.Slot]
	add(itemName(payload), 16, rarity.Color, BOLD)
	add(
		rarity.Name .. " " .. (def and def.Label or payload.Slot) .. "  ·  Quality " .. tostring(payload.Quality or 1),
		12,
		P.Dim,
		BOLD
	)
	for _, stat in { "Health", "Power", "Defense", "Speed" } do
		if roll and roll.Stats and roll.Stats[stat] then
			add("+" .. roll.Stats[stat] .. " " .. stat, 14, P.Good, BOLD)
		end
	end
	if gear and gear.Passive and gear.Passive.Text and gear.Passive.Text ~= "" then
		add(gear.Passive.Name .. ": " .. gear.Passive.Text, 13, P.Gold)
	end
	for _, affix in roll and roll.Affixes or {} do
		local affixDef = GemConfig.AffixById[affix.Id]
		if affixDef then
			add(
				GemConfig.affixText(affix.Id, affix.Bonus),
				13,
				GemConfig.ElementColors[affixDef.Element] or P.Teal,
				BOLD
			)
		end
	end
	if payload.Gem then
		add(
			"◆ " .. GemConfig.displayName(payload.Gem) .. "  (comes with it)",
			13,
			GemConfig.ElementColors[payload.Gem.Element] or P.Teal,
			BOLD
		)
	else
		add("◇ Empty gem socket", 13, P.Dim)
	end
	if roll then
		local ok, identity = pcall(GearRolls.identity, roll)
		if ok and identity then
			add(identity, 11, Color3.fromRGB(150, 160, 185))
		end
	end
	return lines
end

-- The details in a scrolling box.
local function details(parent, payload, x, y, w, h, skipHeader: boolean?)
	local box = scroller(parent, x, y, w, h)
	UiKit.list(box, 3)
	for i, line in detailLines(payload) do
		if skipHeader and i <= 2 then
			continue
		end
		new("TextLabel", {
			BackgroundTransparency = 1,
			Text = line[1],
			TextSize = line[2],
			TextColor3 = line[3],
			Font = line[4],
			Size = UDim2.fromOffset(w - 10, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
		}, box)
	end
	return box
end

-- Everything you could put up (not worn, not socketed), in payload shape.
local function myItems()
	local profile = GemClient.Profile
	local items = {}
	if not profile then
		return items
	end
	for _, gem in profile.Gems or {} do
		table.insert(items, { Kind = "Gem", Id = gem.Id, Gem = gem })
	end
	local c = profile.Character or {}
	-- Socketed gems too: listing one takes it out of its socket.
	for i, slot in Slots.SurgeOrder do
		local gem = c[slot .. "Gem"]
		if type(gem) == "table" then
			table.insert(items, { Kind = "Gem", Id = gem.Id, Gem = gem, Where = "on " .. ({ "Q", "E", "R" })[i] })
		end
	end
	for _, slot in Slots.Order do
		local label = Slots.Definitions[slot].Label
		local gem = c[slot .. "Gem"]
		if type(gem) == "table" then
			table.insert(items, { Kind = "Gem", Id = gem.Id, Gem = gem, Where = "in your " .. label })
		end
		for key, spare in c.ItemGems and c.ItemGems[slot] or {} do
			if type(spare) == "table" and key ~= c[slot] then
				table.insert(items, { Kind = "Gem", Id = spare.Id, Gem = spare, Where = "in a spare " .. label })
			end
		end
	end
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		for id, quality in profile.Owned and profile.Owned[kind] or {} do
			if c[slot] ~= id then
				table.insert(items, {
					Kind = "Gear",
					Slot = slot,
					Id = id,
					Quality = quality,
					Roll = c.GearRolls and c.GearRolls[kind] and c.GearRolls[kind][id],
					Gem = c.ItemGems and c.ItemGems[slot] and c.ItemGems[slot][id],
				})
			end
		end
	end
	table.sort(items, function(a, b)
		if Rules.rank(a) ~= Rules.rank(b) then
			return Rules.rank(a) > Rules.rank(b)
		end
		return itemName(a) < itemName(b)
	end)
	return items
end

local function shown(payload): boolean
	return filter == "All" or Rules.tab(payload) == filter
end

local function timeLeft(row): string
	local left = row.Expires - (serverNow + (os.clock() - fetchedAt))
	if left <= 0 then
		return "ending"
	elseif left >= 3600 then
		return math.floor(left / 3600) .. "h left"
	end
	return math.max(1, math.floor(left / 60)) .. "m left"
end

-- Requests -------------------------------------------------------------------------

-- Redraw only when it can't wipe a price being typed.
local function calm(): boolean
	return window.Gui.Enabled and not busy and UserInputService:GetFocusedTextBox() == nil
end

local function refresh()
	local result = GemClient.request("MarketBrowse")
	if result.Ok then
		listings = result.Listings or {}
		shared = result.Shared ~= false
		serverNow, fetchedAt = result.Now or os.time(), os.clock()
	end
end

local function act(action, ...)
	if busy then
		return
	end
	busy = true
	local result = GemClient.request(action, ...)
	if result.Message and result.Message ~= "" then
		UiKit.toast(result.Message, if result.Ok then READY else P.Bad)
	end
	if result.Ok then
		refresh()
	end
	busy = false
	draw()
	return result.Ok
end

-- Filters row ----------------------------------------------------------------------

local function filters(parent, y, withMode)
	local x = 0
	for _, f in { { "All", "ALL" }, { "Gear", "GEAR" }, { "Gems", "GEMS" }, { "Powers", "POWERS" } } do
		chip(parent, f[2], filter == f[1], GOLD, x, y, 76, function()
			filter = f[1]
			draw()
		end)
		x += 82
	end
	if withMode then
		x += 20
		for _, m in { { "All", "EVERYTHING" }, { "Sell", "FOR COINS" }, { "Trade", "FOR TRADE" } } do
			chip(parent, m[2], mode == m[1], TRADE, x, y, 100, function()
				mode = m[1]
				draw()
			end)
			x += 106
		end
	end
end

-- BROWSE ---------------------------------------------------------------------------

local function listingCard(parent, row, order)
	local mine = row.Seller == Players.LocalPlayer.UserId
	local card = new("Frame", {
		BackgroundColor3 = P.Inset,
		Size = UDim2.fromOffset(204, 168),
		LayoutOrder = order,
	}, parent)
	UiKit.round(card, 8)
	new("UIStroke", { Color = itemColor(row.Item), Transparency = 0.45 }, card)
	itemIcon(card, row.Item, 10, 10, 54, "M:" .. row.Id)
	label(card, itemName(row.Item), 14, itemColor(row.Item), BOLD, 72, 10, 124, 18)
	-- Tap the card (above its button) to see everything about the piece.
	local look = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(204, 118),
		ZIndex = 4,
	}, card)
	look:SetAttribute("UiSound", "Tab")
	IronUi.highlight(look)
	look.Activated:Connect(function()
		inspect = row
		draw()
	end)
	local line = label(card, itemLine(row.Item), 11, P.Dim, BODY, 72, 28, 124, 30)
	line.TextWrapped = true
	line.TextYAlignment = Enum.TextYAlignment.Top
	label(card, "by " .. (row.SellerName or "?"), 11, P.Dim, BODY, 72, 56, 124, 14)
	if row.Mode == "Sell" then
		label(card, tostring(row.Price) .. " coins", 18, P.Gold, BOLD, 10, 74, 140, 24)
	else
		label(card, "⇄ FOR TRADE", 14, TRADE, BOLD, 10, 74, 120, 22)
		label(card, "Wants: " .. (Rules.WantLabels[row.Want] or "Any offer"), 11, P.Dim, BODY, 10, 96, 186, 14)
	end
	label(card, timeLeft(row), 11, P.Dim, BODY, 120, 78, 76, 14, Enum.TextXAlignment.Right)
	local offers = #(row.Offers or {})
	if row.Mode == "Trade" and offers > 0 then
		label(
			card,
			offers .. " offer" .. (if offers == 1 then "" else "s"),
			11,
			TRADE,
			BOLD,
			120,
			96,
			76,
			14,
			Enum.TextXAlignment.Right
		)
	end
	if mine then
		button(card, "YOURS · MANAGE", Color3.fromRGB(80, 84, 110), 10, 124, 184, 34, function()
			tab = "Mine"
			draw()
		end)
	elseif row.Mode == "Sell" then
		local coins = GemClient.Profile and GemClient.Profile.Coins or 0
		local afford = coins >= row.Price
		button(
			card,
			if afford then "BUY" else "NOT ENOUGH COINS",
			if afford then READY else Color3.fromRGB(90, 70, 70),
			10,
			124,
			184,
			34,
			function()
				if afford then
					act("MarketBuy", row.Id)
				end
			end
		)
	else
		button(card, "MAKE AN OFFER", TRADE, 10, 124, 184, 34, function()
			offerFor = row
			draw()
		end)
	end
end

local function drawBrowse()
	filters(content, 0, true)
	button(content, "REFRESH", Color3.fromRGB(70, 76, 100), 764, -2, 96, 30, function()
		task.spawn(function()
			refresh()
			draw()
		end)
	end)
	local rows = {}
	for _, row in listings do
		if shown(row.Item) and (mode == "All" or row.Mode == mode) then
			table.insert(rows, row)
		end
	end
	if not shared then
		label(
			content,
			"Studio test: listings are this server only (MemoryStores unavailable).",
			11,
			P.Dim,
			BODY,
			0,
			32,
			860,
			14
		)
	end
	if #rows == 0 then
		label(content, "⚖", 54, P.Edge, BOLD, 0, 150, 860, 60, Enum.TextXAlignment.Center)
		label(content, "Nothing up for this filter yet", 16, P.Text, BOLD, 0, 220, 860, 22, Enum.TextXAlignment.Center)
		label(
			content,
			"Be the first: open SELL and put up gear or a gem.",
			13,
			P.Dim,
			BODY,
			0,
			246,
			860,
			18,
			Enum.TextXAlignment.Center
		)
		return
	end
	local grid = scroller(content, 0, 50, 860, 440)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(204, 168),
		CellPadding = UDim2.fromOffset(9, 9),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, row in rows do
		listingCard(grid, row, i)
	end
end

-- One listing up close: the piece in 3D, everything about it, and what
-- you can do with it.
local function drawInspect()
	local row = inspect
	local box = panel(content, 0, 0, 860, 490)
	itemIcon(box, row.Item, 16, 16, 260, if row.Item.Kind == "Gear" then "M:" .. row.Id else nil)
	details(box, row.Item, 296, 16, 430, 456)
	button(box, "BACK", Color3.fromRGB(80, 84, 110), 744, 16, 100, 34, function()
		inspect = nil
		draw()
	end)
	label(box, "Listed by " .. (row.SellerName or "?") .. "  ·  " .. timeLeft(row), 13, P.Dim, BODY, 16, 290, 260, 18)
	if row.Mode == "Sell" then
		label(box, tostring(row.Price) .. " coins", 26, P.Gold, BOLD, 16, 316, 260, 32)
	else
		label(box, "⇄ FOR TRADE", 20, TRADE, BOLD, 16, 316, 260, 28)
		label(box, "Wants: " .. (Rules.WantLabels[row.Want] or "Any offer"), 13, P.Dim, BODY, 16, 346, 260, 18)
	end
	if row.Seller == Players.LocalPlayer.UserId then
		button(box, "YOURS · MANAGE", Color3.fromRGB(80, 84, 110), 16, 420, 260, 52, function()
			inspect = nil
			tab = "Mine"
			draw()
		end)
	elseif row.Mode == "Sell" then
		local afford = (GemClient.Profile and GemClient.Profile.Coins or 0) >= row.Price
		button(
			box,
			if afford then "BUY FOR " .. row.Price .. " COINS" else "NOT ENOUGH COINS",
			if afford then READY else Color3.fromRGB(90, 70, 70),
			16,
			420,
			260,
			52,
			function()
				if afford and act("MarketBuy", row.Id) then
					inspect = nil
					draw()
				end
			end
		)
	else
		button(box, "MAKE AN OFFER", TRADE, 16, 420, 260, 52, function()
			inspect = nil
			offerFor = row
			draw()
		end)
	end
end

-- The offer picker: one of your items for someone's trade listing.
local function drawOfferPicker()
	local row = offerFor
	local box = panel(content, 0, 0, 860, 490)
	label(box, "MAKE AN OFFER", 13, TRADE, BOLD, 16, 12, 400, 18)
	itemIcon(box, row.Item, 16, 40, 60, "M:" .. row.Id)
	label(box, itemName(row.Item), 17, itemColor(row.Item), BOLD, 88, 42, 500, 22)
	label(box, itemLine(row.Item) .. "  ·  by " .. (row.SellerName or "?"), 12, P.Dim, BODY, 88, 66, 560, 16)
	label(
		box,
		"They want: "
			.. (Rules.WantLabels[row.Want] or "Any offer")
			.. ".  Your item waits in escrow until they answer.",
		12,
		P.Text,
		BODY,
		88,
		84,
		700,
		16
	)
	button(box, "BACK", Color3.fromRGB(80, 84, 110), 744, 40, 100, 34, function()
		offerFor = nil
		draw()
	end)
	filters(box, 112, false)
	local grid = scroller(box, 16, 146, 828, 332)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(198, 70),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local n = 0
	for _, item in myItems() do
		if shown(item) then
			n += 1
			local fits = Rules.fits(row.Want, item)
			local cell = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = P.Inset,
				BackgroundTransparency = if fits then 0 else 0.5,
				LayoutOrder = n,
			}, grid)
			UiKit.round(cell, 8)
			new("UIStroke", { Color = itemColor(item), Transparency = if fits then 0.4 else 0.8 }, cell)
			IronUi.highlight(cell)
			itemIcon(cell, item, 8, 8, 54, item.Id)
			label(cell, itemName(item), 13, if fits then itemColor(item) else P.Dim, BOLD, 70, 10, 122, 18)
			local l = label(cell, if fits then "Offer this" else "Not what they want", 11, P.Dim, BODY, 70, 30, 122, 30)
			l.TextWrapped = true
			cell.Activated:Connect(function()
				if not fits then
					UiKit.toast("They're after " .. string.lower(Rules.WantLabels[row.Want] or "something else") .. ".")
					return
				end
				if act("MarketOffer", row.Id, item.Kind, item.Slot, item.Id) then
					offerFor = nil
					tab = "Mine"
					draw()
				end
			end)
		end
	end
	if n == 0 then
		label(box, "Nothing in your bag for this filter.", 14, P.Dim, BOLD, 0, 280, 860, 20, Enum.TextXAlignment.Center)
	end
end

-- SELL -----------------------------------------------------------------------------

local function same(a, b)
	return a and b and a.Kind == b.Kind and a.Id == b.Id and a.Slot == b.Slot
end

local function drawSell()
	local profile = GemClient.Profile
	filters(content, 0, false)
	local up = Rules.count(profile, "Sell")
	label(
		content,
		string.format("%d / %d listings up", up, Rules.MaxListings),
		12,
		if up >= Rules.MaxListings then P.Bad else P.Dim,
		BOLD,
		340,
		4,
		180,
		18
	)
	local grid = scroller(content, 0, 36, 500, 454)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(242, 70),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local n = 0
	for _, item in myItems() do
		if shown(item) then
			n += 1
			local picked = same(item, sellPick)
			local cell = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = if picked then GOLD:Lerp(PANEL, 0.75) else P.Inset,
				LayoutOrder = n,
			}, grid)
			UiKit.round(cell, 8)
			new("UIStroke", {
				Color = if picked then GOLD else itemColor(item),
				Thickness = if picked then 2 else 1,
				Transparency = if picked then 0 else 0.5,
			}, cell)
			IronUi.highlight(cell)
			itemIcon(cell, item, 8, 8, 54, item.Id)
			label(cell, itemName(item), 13, itemColor(item), BOLD, 70, 8, 164, 18)
			local l = label(cell, itemLine(item), 11, P.Dim, BODY, 70, 27, 164, 34)
			l.TextWrapped = true
			l.TextYAlignment = Enum.TextYAlignment.Top
			cell.Activated:Connect(function()
				sellPick = item
				draw()
			end)
		end
	end
	if n == 0 then
		label(
			content,
			"Nothing to sell here. Worn gear and socketed gems stay with you.",
			13,
			P.Dim,
			BODY,
			0,
			200,
			500,
			40,
			Enum.TextXAlignment.Center
		).TextWrapped =
			true
	end

	-- The listing form.
	local form = panel(content, 516, 36, 344, 454)
	if not sellPick then
		label(form, "⚖", 48, P.Edge, BOLD, 0, 120, 344, 56, Enum.TextXAlignment.Center)
		label(form, "Pick an item to put up", 15, P.Text, BOLD, 0, 184, 344, 20, Enum.TextXAlignment.Center)
		local hint = label(
			form,
			"Listed items leave your bag and wait safely in escrow until they sell, trade, or you cancel.",
			12,
			P.Dim,
			BODY,
			24,
			210,
			296,
			48,
			Enum.TextXAlignment.Center
		)
		hint.TextWrapped = true
		return
	end
	local item = sellPick
	itemIcon(form, item, 14, 14, 64, item.Id)
	label(form, itemName(item), 15, itemColor(item), BOLD, 88, 16, 244, 20)
	local l = label(form, itemLine(item), 11, P.Dim, BODY, 88, 38, 244, 36)
	l.TextWrapped = true
	l.TextYAlignment = Enum.TextYAlignment.Top
	-- Everything about it (buyers see the same).
	local info = details(form, item, 14, 84, 322, 104, true)
	info.BackgroundTransparency = 0.5
	info.BackgroundColor3 = P.Inset
	UiKit.round(info, 6)
	UiKit.pad(info, 6)
	chip(form, "SELL FOR COINS", sellMode == "Sell", GOLD, 14, 196, 154, function()
		sellMode = "Sell"
		draw()
	end)
	chip(form, "OPEN TO TRADE", sellMode == "Trade", TRADE, 176, 196, 154, function()
		sellMode = "Trade"
		draw()
	end)
	if sellMode == "Sell" then
		label(form, "PRICE (COINS)", 11, P.Dim, BOLD, 14, 232, 200, 14)
		local box = new("TextBox", {
			Text = tostring(sellPrice),
			PlaceholderText = "Price",
			ClearTextOnFocus = false,
			TextSize = 22,
			Font = BOLD,
			TextColor3 = P.Gold,
			BackgroundColor3 = P.Inset,
			Position = UDim2.fromOffset(14, 250),
			Size = UDim2.fromOffset(316, 40),
		}, form)
		UiKit.round(box, 6)
		new("UIStroke", { Color = P.Edge, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		box.FocusLost:Connect(function()
			local value = tonumber((string.gsub(box.Text, "[^%d]", "")))
			sellPrice = math.clamp(math.floor(value or sellPrice), Rules.MinPrice, Rules.MaxPrice)
			draw()
		end)
		local x = 14
		for _, step in { -100, -10, 10, 100, 1000 } do
			chip(form, (if step > 0 then "+" else "") .. step, false, GOLD, x, 298, 58, function()
				sellPrice = math.clamp(sellPrice + step, Rules.MinPrice, Rules.MaxPrice)
				draw()
			end)
			x += 64
		end
		if item.Kind == "Gem" then
			local worth = GemConfig.value(item.Gem)
			label(
				form,
				"Shop pays about " .. math.floor(worth * Config.MarketSellRate) .. " · worth ~" .. worth,
				11,
				P.Dim,
				BODY,
				14,
				330,
				316,
				14
			)
		end
		label(
			form,
			string.format("You get %d after the %d%% market tax.", Rules.payout(sellPrice), math.floor(Rules.Tax * 100)),
			12,
			P.Good,
			BOLD,
			14,
			348,
			316,
			16
		)
	else
		label(form, "WHAT DO YOU WANT FOR IT?", 11, P.Dim, BOLD, 14, 232, 300, 14)
		for i, want in Rules.Wants do
			local col, rowY = (i - 1) % 2, (i - 1) // 2
			chip(form, want.Label, sellWant == want.Id, TRADE, 14 + col * 162, 250 + rowY * 34, 154, function()
				sellWant = want.Id
				draw()
			end)
		end
		local t = label(
			form,
			"Players send offers. You see each item and pick the one you like; the rest go back to their owners.",
			12,
			P.Dim,
			BODY,
			14,
			322,
			316,
			46
		)
		t.TextWrapped = true
	end
	local note = label(form, "Out of your bag while listed · lasts 48 hours", 11, P.Dim, BODY, 14, 372, 316, 16)
	note.TextWrapped = true
	button(
		form,
		if sellMode == "Sell" then "LIST FOR " .. sellPrice .. " COINS" else "LIST FOR TRADE",
		if sellMode == "Sell" then GOLD else TRADE,
		14,
		394,
		316,
		46,
		function()
			local value = if sellMode == "Sell" then sellPrice else sellWant
			if act("MarketList", item.Kind, item.Slot, item.Id, sellMode, value) then
				sellPick = nil
				draw()
			end
		end
	)
end

-- MY LISTINGS ----------------------------------------------------------------------

local function rowFor(id)
	for _, row in listings do
		if row.Id == id then
			return row
		end
	end
	return nil
end

local function drawMine()
	local profile = GemClient.Profile
	local escrow = profile and profile.Market and profile.Market.Escrow or {}
	local list = scroller(content, 0, 0, 860, 490)
	UiKit.list(list, 8)
	local order = 0
	local function heading(value)
		order += 1
		local h = label(list, value, 12, GOLD, BOLD, 0, 0, 840, 20)
		h.LayoutOrder = order
	end
	local sells, offers = {}, {}
	for _, entry in escrow do
		table.insert(if entry.Role == "Sell" then sells else offers, entry)
	end
	table.sort(sells, function(a, b)
		return (a.At or 0) > (b.At or 0)
	end)
	heading(string.format("MY LISTINGS  ·  %d / %d", #sells, Rules.MaxListings))
	if #sells == 0 then
		order += 1
		label(list, "Nothing up. Use SELL to list gear or gems.", 13, P.Dim, BODY, 0, 0, 840, 20).LayoutOrder = order
	end
	for _, entry in sells do
		local row = rowFor(entry.Listing)
		local offerList = row and row.Offers or {}
		order += 1
		local card = new("Frame", {
			BackgroundColor3 = P.Inset,
			Size = UDim2.fromOffset(840, 84 + #offerList * 62),
			LayoutOrder = order,
		}, list)
		UiKit.round(card, 8)
		new("UIStroke", { Color = itemColor(entry.Item), Transparency = 0.5 }, card)
		itemIcon(card, entry.Item, 12, 12, 60, "M:" .. entry.Listing)
		label(card, itemName(entry.Item), 15, itemColor(entry.Item), BOLD, 84, 12, 420, 20)
		label(card, itemLine(entry.Item), 12, P.Dim, BODY, 84, 34, 420, 16)
		local status = if not row
			then "Settling…"
			elseif row.Mode == "Sell" then row.Price .. " coins  ·  " .. timeLeft(row)
			else "⇄ For trade  ·  wants "
				.. string.lower(Rules.WantLabels[row.Want] or "any offer")
				.. "  ·  "
				.. timeLeft(row)
		label(card, status, 13, if row and row.Mode == "Sell" then P.Gold else TRADE, BOLD, 84, 54, 520, 18)
		button(card, "CANCEL", Color3.fromRGB(150, 60, 54), 716, 22, 110, 36, function()
			act("MarketCancel", entry.Listing)
		end)
		for i, offer in offerList do
			local y = 84 + (i - 1) * 62
			local strip = new("Frame", {
				BackgroundColor3 = PANEL,
				Position = UDim2.fromOffset(12, y),
				Size = UDim2.fromOffset(816, 54),
			}, card)
			UiKit.round(strip, 6)
			itemIcon(strip, offer.Item, 6, 5, 44, "M:" .. entry.Listing .. ":" .. offer.Id)
			label(strip, (offer.FromName or "?") .. " offers", 11, P.Dim, BODY, 58, 6, 300, 14)
			label(strip, itemName(offer.Item), 14, itemColor(offer.Item), BOLD, 58, 20, 420, 18)
			label(strip, itemLine(offer.Item), 11, P.Dim, BODY, 58, 37, 420, 14)
			button(strip, "ACCEPT", READY, 584, 9, 110, 36, function()
				act("MarketAccept", entry.Listing, offer.Id)
			end)
			button(strip, "DECLINE", Color3.fromRGB(90, 80, 96), 700, 9, 106, 36, function()
				act("MarketDecline", entry.Listing, offer.Id)
			end)
		end
	end
	heading(string.format("MY OFFERS  ·  %d / %d", #offers, Rules.MaxOffersOut))
	if #offers == 0 then
		order += 1
		label(list, "No offers out. Find a FOR TRADE listing in BROWSE.", 13, P.Dim, BODY, 0, 0, 840, 20).LayoutOrder =
			order
	end
	for _, entry in offers do
		local row = rowFor(entry.Listing)
		order += 1
		local card = new("Frame", {
			BackgroundColor3 = P.Inset,
			Size = UDim2.fromOffset(840, 76),
			LayoutOrder = order,
		}, list)
		UiKit.round(card, 8)
		new("UIStroke", { Color = TRADE, Transparency = 0.6 }, card)
		itemIcon(card, entry.Item, 10, 10, 56)
		label(card, "You offer", 11, P.Dim, BODY, 76, 10, 200, 14)
		label(card, itemName(entry.Item), 14, itemColor(entry.Item), BOLD, 76, 26, 300, 18)
		label(card, "⇄", 22, TRADE, BOLD, 380, 22, 30, 30)
		if row then
			itemIcon(card, row.Item, 414, 10, 56, "M:" .. row.Id)
			label(card, "for " .. (row.SellerName or "?") .. "'s", 11, P.Dim, BODY, 480, 10, 200, 14)
			label(card, itemName(row.Item), 14, itemColor(row.Item), BOLD, 480, 26, 220, 18)
		else
			label(card, "Waiting for an answer…", 13, P.Dim, BODY, 414, 26, 260, 18)
		end
		button(card, "WITHDRAW", Color3.fromRGB(90, 80, 96), 716, 20, 110, 36, function()
			act("MarketWithdraw", entry.Listing)
		end)
	end
end

-- Frame ----------------------------------------------------------------------------

draw = function()
	IronUi.clear(bar)
	IronUi.clear(content)
	if not GemClient.Profile then
		label(content, "Loading…", 15, P.Dim, BOLD, 0, 220, 860, 20, Enum.TextXAlignment.Center)
		return
	end
	local escrow = GemClient.Profile.Market and GemClient.Profile.Market.Escrow or {}
	local waiting = 0
	for _, entry in escrow do
		local row = entry.Role == "Sell" and rowFor(entry.Listing)
		waiting += if row then #(row.Offers or {}) else 0
	end
	IronUi.tabs(
		bar,
		{
			{ "Browse", "BROWSE" },
			{ "Sell", "SELL" },
			{ "Mine", if waiting > 0 then "MY LISTINGS (" .. waiting .. ")" else "MY LISTINGS" },
		},
		tab,
		function(id)
			tab = id
			offerFor = nil
			draw()
		end
	)
	label(
		bar,
		tostring(GemClient.Profile.Coins or 0) .. " coins",
		18,
		P.Gold,
		BOLD,
		560,
		0,
		120,
		44,
		Enum.TextXAlignment.Right
	)
	button(bar, "FACE TO FACE", Color3.fromRGB(70, 76, 100), 696, 4, 164, 36, function()
		window.Gui.Enabled = false
		require(script.Parent.TradeUI).open()
	end)
	if offerFor then
		drawOfferPicker()
	elseif inspect and tab == "Browse" then
		drawInspect()
	elseif tab == "Sell" then
		drawSell()
	elseif tab == "Mine" then
		drawMine()
	else
		drawBrowse()
	end
end

function MarketBoardUI.open(which: string?)
	if Config.Features and Config.Features.Market == false then
		UiKit.toast("The Market is closed for this playtest.")
		return
	end
	tab = which or tab
	offerFor, inspect = nil, nil
	window.Gui.Enabled = true
	window.Fit()
	draw()
	task.spawn(function()
		refresh()
		if window.Gui.Enabled then
			draw()
		end
		-- 3D pictures: your own gear, then the gear on the board.
		for _, action in { "GearPreviews", "MarketPreviews" } do
			local result = GemClient.request(action)
			if result.Ok and calm() then
				draw()
			end
		end
	end)
end

local function close()
	window.Gui.Enabled = false
end
window.Close.Activated:Connect(close)
window.Shade.Activated:Connect(close)

-- Keep the board fresh while it's open; redraw when the bag changes.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	if not window.Gui.Enabled or busy then
		return
	end
	elapsed += dt
	if elapsed < 8 then
		return
	end
	elapsed = 0
	task.spawn(function()
		refresh()
		if calm() and not offerFor then
			draw()
		end
		-- New gear on the board gets its 3D picture.
		local result = GemClient.request("MarketPreviews")
		if result.Ok and calm() and not offerFor then
			draw()
		end
	end)
end)
GemClient.Changed:Connect(function()
	if calm() then
		draw()
	end
end)

return MarketBoardUI
