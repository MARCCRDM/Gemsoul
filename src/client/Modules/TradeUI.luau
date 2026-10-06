-- The Market: face-to-face equipment trading. Pick a miner, pick an item from
-- your gear (shown in 3D with its full tooltip), send the offer; both players
-- see both items side by side and mark READY before anything changes hands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Features = require(ReplicatedStorage.Shared.Config).Features or {}
local GearArt = require(script.Parent.GearArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local TradeUI = {}
local P = IronUi.Colors
local new = IronUi.new
local BOLD, BODY = IronUi.Bold, IronUi.Body
local GOLD = Color3.fromRGB(232, 168, 52)
local READY = Color3.fromRGB(64, 196, 110)
local PANEL = Color3.fromRGB(16, 18, 32)

local window = IronUi.window("EquipmentTrade", 10, 900, 620, "⇄", GOLD)
window.Title.Text = "MARKET"
window.Subtitle.Text = "Trade gear face to face. Rolls, finishes and socketed gems travel with every item."
local content = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 80),
	Size = UDim2.fromOffset(860, 524),
}, window.Panel)

local state, target, selected = nil, nil, nil
local slot = "Weapon"
local busy, elapsed, lastKey = false, 0, ""
local draw

-- Small building blocks ----------------------------------------------------------------

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

-- A section heading with a thin gold rule under it.
local function heading(parent, value, x, y, w)
	local t = label(parent, value, 12, GOLD, BOLD, x, y, w, 16)
	new("Frame", {
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.6,
		Position = UDim2.fromOffset(x, y + 18),
		Size = UDim2.fromOffset(w, 1),
	}, parent)
	return t
end

local function bigButton(parent, value, color, x, y, w, h, callback)
	local b, face = IronUi.chunk(parent, {
		Color = color,
		Size = UDim2.fromOffset(w, h),
		Radius = 8,
		Lip = 4,
		Stripes = "None",
	})
	b.Position = UDim2.fromOffset(x, y)
	IronUi.label(b, face, value, 16)
	b:SetAttribute("UiSound", "Confirm")
	b.Activated:Connect(callback)
	return b
end

-- A disabled action: the same footprint, greyed, saying what is still missing.
local function waitingButton(parent, value, x, y, w, h)
	local f = new("Frame", {
		BackgroundColor3 = P.Slot,
		BackgroundTransparency = 0.3,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	UiKit.round(f, 8)
	new("UIStroke", { Color = P.Edge, Transparency = 0.5 }, f)
	label(f, value, 14, P.Dim, BOLD, 0, 0, w, h, Enum.TextXAlignment.Center).TextWrapped = true
	return f
end

-- Avatar headshots, fetched once per player.
local headshots = {}
local function avatar(parent, userId, size, x, y)
	local image = new("ImageLabel", {
		BackgroundColor3 = P.Slot,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		Image = headshots[userId] or "",
		ScaleType = Enum.ScaleType.Crop,
	}, parent)
	UiKit.round(image, size // 2)
	new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.3 }, image)
	-- Their initial shows until the headshot arrives.
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then player.DisplayName else ""
	local initial = label(image, string.upper(string.sub(name, 1, 1)), size // 2, GOLD, BOLD, 0, 0, size, size)
	initial.TextXAlignment = Enum.TextXAlignment.Center
	initial.Visible = image.Image == ""
	if not headshots[userId] and typeof(userId) == "number" and userId > 0 then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
			end)
			if ok and url then
				headshots[userId] = url
				if IronUi.alive(image) then
					image.Image = url
					initial.Visible = false
				end
			end
		end)
	end
	return image
end

-- Items --------------------------------------------------------------------------------

local function rarityRank(item): number
	local roll = item and item.Roll
	return if roll and GearRolls.Rarities[roll.Rarity] then roll.Rarity else 1
end
local function rarityOf(item)
	return GearRolls.Rarities[rarityRank(item)]
end

local function gearOf(item)
	local profile = GemClient.Profile
	local def = item and Slots.Definitions[item.Slot]
	if not profile or not def then
		return nil
	end
	return Classes.gear(profile.Character.Class, def.Kind, item.Id)
end
local function nameOf(item): string
	local gear = gearOf(item)
	return if gear then gear.Name else item.Id
end

-- Every item you own in a slot, in the trade's item shape, best first.
local function ownedItems(which)
	local character = GemClient.Profile.Character
	local def = Slots.Definitions[which]
	local items = {}
	-- Every copy you own (a second copy of a model is "Model#2", Slots.freeKey).
	for order, gear in Classes.get(character.Class)[def.Kind] do
		for key, quality in GemClient.Profile.Owned[def.Kind] do
			if Slots.model(key) == gear.Id then
				local worn = character[which] == key
				table.insert(items, {
					Id = key,
					Slot = which,
					Quality = quality,
					Roll = character.GearRolls and character.GearRolls[def.Kind][key],
					Gem = if worn
						then character[which .. "Gem"]
						else character.ItemGems and character.ItemGems[which] and character.ItemGems[which][key],
					Worn = worn,
					Order = order,
				})
			end
		end
	end
	table.sort(items, function(a, b)
		if rarityRank(a) ~= rarityRank(b) then
			return rarityRank(a) > rarityRank(b)
		end
		return a.Order < b.Order
	end)
	return items
end

-- The item's picture: 3D when we have it (our own gear), else a drawn silhouette.
local function itemArt(parent, item, mine, x, y, w, h)
	local rarity = rarityOf(item)
	local stage = new("Frame", {
		BackgroundColor3 = rarity.Color:Lerp(P.Frame, 0.8),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ClipsDescendants = true,
	}, parent)
	UiKit.round(stage, 6)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140)),
	}, stage)
	new("UIStroke", { Color = rarity.Color, Thickness = 1.5, Transparency = 0.25 }, stage)
	-- A soft glow behind the item, in its rarity colour.
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundColor3 = rarity.Color,
		BackgroundTransparency = 0.82,
	}, stage)
	UiKit.round(glow, math.max(w, h))
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(185, 190, 210),
		LightColor = Color3.fromRGB(255, 235, 201),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, stage)
	local drawn = mine and GearArt.draw(view, item.Slot, item.Id, item.Worn == true)
	view.Visible = drawn == true
	if not drawn then
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 26),
		}, stage)
		new("UIScale", { Scale = math.min(w / 46, h / 40) }, holder)
		local icon = GearArt.icon(holder, item.Slot, gearOf(item) or {}, rarity.Color)
		if icon then
			icon.Position = UDim2.new()
		end
	end
	if item.Gem then
		local gem =
			label(stage, "◆", 14, GemConfig.ElementColors[item.Gem.Element] or P.Teal, BOLD, w - 20, 4, 16, 16)
		gem.ZIndex = 3
	end
	return stage
end

-- A Blizzard-style tooltip: name in its rarity colour, stats in green, the
-- weapon's perk in gold, affixes in their element's colour, then the socket.
local function tooltip(parent, item, width)
	local list = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	UiKit.list(list, 3)
	local order = 0
	local function line(value, size, color, font)
		order += 1
		return new("TextLabel", {
			BackgroundTransparency = 1,
			Text = value,
			TextSize = size,
			TextColor3 = color,
			Font = font or BODY,
			Size = UDim2.fromOffset(width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		}, list)
	end
	local gear = gearOf(item)
	local rarity = rarityOf(item)
	local roll = item.Roll
	line(nameOf(item), 17, rarity.Color, BOLD)
	line(
		rarity.Name .. " " .. Slots.Definitions[item.Slot].Label .. "  ·  Quality " .. tostring(item.Quality or 1),
		12,
		P.Dim,
		BOLD
	)
	for _, stat in { "Health", "Power", "Defense", "Speed" } do
		if roll and roll.Stats and roll.Stats[stat] then
			line("+" .. roll.Stats[stat] .. " " .. stat, 14, P.Good, BOLD)
		end
	end
	if gear and gear.Passive and gear.Passive.Text ~= "" then
		line(gear.Passive.Name .. ": " .. gear.Passive.Text, 13, P.Gold)
	end
	for _, affix in roll and roll.Affixes or {} do
		local def = GemConfig.AffixById[affix.Id]
		if def then
			line(GemConfig.affixText(affix.Id, affix.Bonus), 13, GemConfig.ElementColors[def.Element] or P.Teal, BOLD)
		end
	end
	if item.Gem then
		line(
			"◆ " .. GemConfig.displayName(item.Gem) .. "  (cut " .. tostring(item.Gem.Cut) .. ")",
			13,
			GemConfig.ElementColors[item.Gem.Element] or P.Teal,
			BOLD
		)
	else
		line("◇ Empty gem socket", 13, P.Dim)
	end
	if roll then
		line(GearRolls.identity(roll), 11, Color3.fromRGB(150, 160, 185))
	end
	return list
end

-- Requests -------------------------------------------------------------------------------

local function key(s)
	return if s
		then s.Id .. tostring(s.Right and s.Right.Id) .. tostring(s.Revision) .. tostring(s.Saving) .. tostring(
			s.OwnConfirmed
		) .. tostring(s.PartnerConfirmed)
		else "none"
end

local function request(action, ...)
	if busy then
		return
	end
	busy = true
	local result = GemClient.request(action, ...)
	busy = false
	if result.Message ~= "" then
		UiKit.toast(result.Message)
	end
	if result.Ok then
		state = result.Trade
		lastKey = key(state)
	end
	draw()
end

-- Browsing: pick a miner, pick an item, send ---------------------------------------------

local function drawPlayers()
	local rail = panel(content, 0, 0, 228, 524)
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			table.insert(others, p)
		end
	end
	heading(rail, "MINERS IN THIS SERVER  ·  " .. #others, 12, 10, 204)
	if #others == 0 then
		label(rail, "⇄", 54, P.Edge, BOLD, 0, 150, 228, 60, Enum.TextXAlignment.Center)
		label(rail, "No other miners yet", 15, P.Text, BOLD, 0, 220, 228, 20, Enum.TextXAlignment.Center)
		local hint = label(
			rail,
			"Trade partners show up here as soon as they join your server. Invite a friend!",
			12,
			P.Dim,
			BODY,
			20,
			246,
			188,
			54,
			Enum.TextXAlignment.Center
		)
		hint.TextWrapped = true
		return
	end
	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 38),
		Size = UDim2.fromOffset(214, 478),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
	}, rail)
	UiKit.list(list, 6)
	for i, p in others do
		local chosen = target == p.UserId
		local fighting = p:GetAttribute("MatchId") ~= nil or p:GetAttribute("CombatSession") ~= nil
		local card = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if chosen then GOLD:Lerp(PANEL, 0.75) else P.Inset,
			Size = UDim2.fromOffset(204, 58),
			LayoutOrder = i,
		}, list)
		UiKit.round(card, 6)
		new("UIStroke", {
			Color = if chosen then GOLD else P.Edge,
			Thickness = if chosen then 2 else 1,
			Transparency = if chosen then 0 else 0.5,
		}, card)
		IronUi.highlight(card)
		avatar(card, p.UserId, 42, 8, 8)
		label(card, p.DisplayName, 14, P.Text, BOLD, 58, 9, 140, 18)
		local level = p:GetAttribute("SeasonLevel")
		label(
			card,
			"@" .. p.Name .. (if level then "  ·  Lv " .. tostring(level) else ""),
			11,
			P.Dim,
			BODY,
			58,
			27,
			140,
			14
		)
		label(
			card,
			if fighting then "● In a fight" else "● Available",
			11,
			if fighting then P.Bad else READY,
			BOLD,
			58,
			41,
			140,
			13
		)
		card.Activated:Connect(function()
			target = p.UserId
			draw()
		end)
	end
end

local function drawItems()
	local area = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(240, 0),
		Size = UDim2.fromOffset(392, 524),
	}, content)
	-- The three steps, lighting up as you complete them.
	local steps = { "PICK A MINER", "PICK AN ITEM", "SEND OFFER" }
	local done = { target ~= nil, selected ~= nil, false }
	for i, step in steps do
		local current = not done[i] and (i == 1 or done[i - 1])
		local color = if done[i] then READY elseif current then GOLD else P.Dim
		local chip = new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = if current then 0.75 else 0.9,
			Position = UDim2.fromOffset((i - 1) * 132, 0),
			Size = UDim2.fromOffset(126, 26),
		}, area)
		UiKit.round(chip, 13)
		new("UIStroke", { Color = color, Transparency = 0.3 }, chip)
		label(
			chip,
			(if done[i] then "✓ " else i .. "  ") .. step,
			11,
			color,
			BOLD,
			0,
			0,
			126,
			26,
			Enum.TextXAlignment.Center
		)
	end
	-- Slot tabs, each with its item silhouette.
	for i, name in Slots.Order do
		local active = slot == name
		local tab = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if active then GOLD:Lerp(PANEL, 0.7) else P.Inset,
			Position = UDim2.fromOffset((i - 1) * 66, 36),
			Size = UDim2.fromOffset(62, 58),
		}, area)
		UiKit.round(tab, 6)
		new("UIStroke", {
			Color = if active then GOLD else P.Edge,
			Thickness = if active then 2 else 1,
			Transparency = if active then 0 else 0.5,
		}, tab)
		IronUi.highlight(tab)
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 2),
			Size = UDim2.fromOffset(38, 34),
		}, tab)
		GearArt.icon(holder, name, { Look = "FrontierSword" }, if active then GOLD else P.Dim)
		label(
			tab,
			Slots.Definitions[name].Label,
			11,
			if active then P.Text else P.Dim,
			BOLD,
			0,
			38,
			62,
			16,
			Enum.TextXAlignment.Center
		)
		tab:SetAttribute("UiSound", "Tab")
		tab.Activated:Connect(function()
			slot = name
			selected = nil
			draw()
		end)
	end
	local grid = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.fromOffset(392, 420),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
	}, area)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(122, 132),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local items = ownedItems(slot)
	if #items == 0 then
		label(
			area,
			"You have no " .. Slots.Definitions[slot].Label .. " to trade yet.",
			13,
			P.Dim,
			BOLD,
			0,
			200,
			392,
			20,
			Enum.TextXAlignment.Center
		)
	end
	for i, item in items do
		local chosen = selected == item.Id
		local rarity = rarityOf(item)
		local card = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if chosen then GOLD:Lerp(PANEL, 0.8) else PANEL,
			LayoutOrder = i,
		}, grid)
		UiKit.round(card, 6)
		new("UIStroke", {
			Color = if chosen then GOLD else rarity.Color,
			Thickness = if chosen then 2.5 else 1,
			Transparency = if chosen then 0 else 0.45,
		}, card)
		IronUi.highlight(card)
		itemArt(card, item, true, 5, 5, 112, 84)
		label(card, nameOf(item), 12, P.Text, BOLD, 7, 92, 108, 18)
		label(card, string.upper(rarity.Name), 10, rarity.Color, BOLD, 7, 110, 90, 13)
		if item.Worn then
			local worn = label(card, "WORN", 9, P.Frame, BOLD, 9, 9, 38, 14, Enum.TextXAlignment.Center)
			worn.BackgroundTransparency = 0
			worn.BackgroundColor3 = P.Teal
			worn.ZIndex = 4
			UiKit.round(worn, 4)
		end
		if chosen then
			local tick = label(card, "✓", 13, P.Frame, BOLD, 96, 106, 20, 20, Enum.TextXAlignment.Center)
			tick.BackgroundTransparency = 0
			tick.BackgroundColor3 = GOLD
			UiKit.round(tick, 10)
		end
		card.Activated:Connect(function()
			selected = item.Id
			draw()
		end)
	end
	return items
end

local function drawDetails(items)
	local side = panel(content, 644, 0, 216, 524)
	heading(side, "ITEM DETAILS", 12, 10, 192)
	local item
	for _, each in items do
		if each.Id == selected then
			item = each
		end
	end
	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.fromOffset(198, 330),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
	}, side)
	if item then
		itemArt(scroll, item, true, 0, 0, 188, 110)
		tooltip(scroll, item, 186).Position = UDim2.fromOffset(0, 118)
	else
		local hint = label(
			scroll,
			"Select one of your items to see its stats, perk, finish and socketed gem.",
			13,
			P.Dim,
			BODY,
			0,
			100,
			188,
			60,
			Enum.TextXAlignment.Center
		)
		hint.TextWrapped = true
	end
	-- The offer: who gets what, and the button.
	local partner = target and Players:GetPlayerByUserId(target)
	if target and not partner then
		target = nil
	end
	new("Frame", {
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.5,
		Position = UDim2.fromOffset(12, 376),
		Size = UDim2.fromOffset(192, 1),
	}, side)
	local summary = label(
		side,
		if partner and item
			then "Offer " .. nameOf(item) .. " to " .. partner.DisplayName
			elseif partner then "Trading with " .. partner.DisplayName
			else "Choose a miner on the left",
		12,
		P.Text,
		BOLD,
		12,
		384,
		192,
		36
	)
	summary.TextWrapped = true
	summary.TextTruncate = Enum.TextTruncate.None
	if partner and item then
		bigButton(side, "SEND OFFER", GOLD, 12, 428, 192, 48, function()
			request("TradeOffer", target, slot, selected)
		end)
	else
		waitingButton(side, if partner then "Pick an item" else "Pick a miner", 12, 428, 192, 48)
	end
	label(side, "They answer with an item from the same slot.", 10, P.Dim, BODY, 12, 482, 192, 32).TextWrapped = true
end

-- Trading: both items side by side, both players mark READY ---------------------------

local countdown: TextLabel? = nil
local function updateClock()
	if countdown and state and state.Expires then
		local left = math.clamp(math.floor(state.Expires - workspace:GetServerTimeNow()), 0, 120)
		countdown.Text = string.format("⏱ %d:%02d", left // 60, left % 60)
		countdown.TextColor3 = if left <= 20 then P.Bad else GOLD
	end
end

local function tradeColumn(x, title, userId, item, mine, ready, picking)
	local col = panel(content, x, 64, 398, 384, if ready then READY:Lerp(PANEL, 0.82) else PANEL)
	if ready then
		local stroke = col:FindFirstChildOfClass("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Transparency = READY, 2, 0
	end
	avatar(col, userId, 30, 12, 9)
	label(col, title, 14, GOLD, BOLD, 50, 9, 330, 30)
	if item then
		itemArt(col, item, mine, 12, 48, 160, 128)
		local scroll = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(184, 46),
			Size = UDim2.fromOffset(204, if picking then 200 else 280),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 3,
		}, col)
		tooltip(scroll, item, 194)
	else
		local empty = new("Frame", {
			BackgroundColor3 = P.Inset,
			Position = UDim2.fromOffset(12, 48),
			Size = UDim2.fromOffset(160, 128),
		}, col)
		UiKit.round(empty, 6)
		new("UIStroke", { Color = P.Edge, Transparency = 0.3 }, empty)
		label(empty, "?", 48, P.Edge, BOLD, 0, 0, 160, 128, Enum.TextXAlignment.Center)
		local wait = label(
			col,
			if mine then "Choose what you give back from your gear below." else "Waiting for their item...",
			13,
			P.Dim,
			BOLD,
			184,
			90,
			200,
			40
		)
		wait.TextWrapped = true
	end
	-- The READY bar.
	local bar = new("Frame", {
		BackgroundColor3 = if ready then READY else P.Inset,
		BackgroundTransparency = if ready then 0.1 else 0,
		Position = UDim2.fromOffset(12, 340),
		Size = UDim2.fromOffset(374, 32),
	}, col)
	UiKit.round(bar, 6)
	label(
		bar,
		if ready then "✓  READY" else "NOT READY",
		14,
		if ready then P.Frame else P.Dim,
		BOLD,
		0,
		0,
		374,
		32,
		Enum.TextXAlignment.Center
	)
	return col
end

local function drawTrade()
	local s = state
	local mineItem = if s.Initiator then s.Left else s.Right
	local theirItem = if s.Initiator then s.Right else s.Left
	-- Banner: who, which slot, and the clock.
	local banner = panel(content, 0, 0, 860, 54)
	avatar(banner, s.PartnerId, 38, 10, 8)
	label(banner, "TRADING WITH " .. string.upper(s.Partner), 17, P.Text, BOLD, 58, 8, 500, 22)
	local slotName = Slots.Definitions[s.Slot].Label
	label(
		banner,
		slotName
			.. " for "
			.. slotName
			.. (if s.PartnerLevel then "  ·  " .. s.Partner .. " is Lv " .. tostring(s.PartnerLevel) else ""),
		12,
		P.Dim,
		BODY,
		58,
		30,
		500,
		16
	)
	local clock = new("Frame", {
		BackgroundColor3 = P.Inset,
		Position = UDim2.fromOffset(750, 12),
		Size = UDim2.fromOffset(96, 30),
	}, banner)
	UiKit.round(clock, 15)
	new("UIStroke", { Color = GOLD, Transparency = 0.4 }, clock)
	countdown = label(clock, "", 14, GOLD, BOLD, 0, 0, 96, 30, Enum.TextXAlignment.Center)
	updateClock()

	if s.Saving then
		local seal = panel(content, 230, 160, 400, 160)
		label(seal, "⇄", 46, GOLD, BOLD, 0, 18, 400, 56, Enum.TextXAlignment.Center)
		label(seal, "Sealing the exchange...", 18, P.Text, BOLD, 0, 80, 400, 24, Enum.TextXAlignment.Center)
		label(
			seal,
			"Both items are locked until it is saved.",
			13,
			P.Dim,
			BODY,
			0,
			108,
			400,
			20,
			Enum.TextXAlignment.Center
		)
		return
	end

	local picking = not s.Initiator and not s.OwnConfirmed
	tradeColumn(0, "YOU GIVE", Players.LocalPlayer.UserId, mineItem, true, s.OwnConfirmed, picking)
	tradeColumn(462, string.upper(s.Partner) .. " GIVES", s.PartnerId, theirItem, false, s.PartnerConfirmed)
	-- The swap emblem between the two.
	local swap = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL,
		Position = UDim2.fromOffset(430, 64 + 140),
		Size = UDim2.fromOffset(48, 48),
	}, content)
	UiKit.round(swap, 24)
	new("UIStroke", { Color = GOLD, Thickness = 2 }, swap)
	label(swap, "⇄", 24, GOLD, BOLD, 0, 0, 48, 48, Enum.TextXAlignment.Center)

	-- The recipient picks what to give back, straight from their own gear.
	if picking then
		label(content, "YOUR " .. string.upper(slotName) .. " ITEMS", 11, GOLD, BOLD, 12, 64 + 256, 200, 16)
		local strip = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 64 + 274),
			Size = UDim2.fromOffset(374, 60),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 3,
			ScrollingDirection = Enum.ScrollingDirection.X,
		}, content)
		UiKit.list(strip, 6, true)
		for i, item in ownedItems(s.Slot) do
			local chosen = mineItem and mineItem.Id == item.Id
			local tile = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = PANEL,
				Size = UDim2.fromOffset(54, 54),
				LayoutOrder = i,
			}, strip)
			UiKit.round(tile, 6)
			new("UIStroke", {
				Color = if chosen then GOLD else rarityOf(item).Color,
				Thickness = if chosen then 2.5 else 1,
				Transparency = if chosen then 0 else 0.4,
			}, tile)
			IronUi.highlight(tile)
			itemArt(tile, item, true, 3, 3, 48, 48)
			tile.Activated:Connect(function()
				request("TradeCounter", s.Id, item.Id)
			end)
		end
	end

	-- Bottom bar: the rule, then CANCEL and ACCEPT.
	local note = label(
		content,
		if s.OwnConfirmed and not s.PartnerConfirmed
			then "You're ready. Waiting for " .. s.Partner .. " to accept..."
			else "Changing an item clears both READY marks. Nothing moves until you both accept.",
		12,
		P.Dim,
		BODY,
		0,
		462,
		440,
		44
	)
	note.TextWrapped = true
	bigButton(content, "CANCEL", Color3.fromRGB(150, 60, 54), 480, 460, 160, 50, function()
		request("TradeCancel", s.Id)
	end)
	if s.Right and not s.OwnConfirmed then
		bigButton(content, "ACCEPT TRADE", READY, 652, 460, 208, 50, function()
			request("TradeConfirm", s.Id, s.Revision)
		end)
	else
		waitingButton(content, if s.OwnConfirmed then "✓ ACCEPTED" else "Waiting for an item", 652, 460, 208, 50)
	end
end

draw = function()
	IronUi.clear(content)
	countdown = nil
	if not GemClient.Profile then
		label(content, "Loading your gear...", 15, P.Dim, BOLD, 0, 240, 860, 20, Enum.TextXAlignment.Center)
		return
	end
	if state then
		drawTrade()
		return
	end
	drawPlayers()
	drawDetails(drawItems())
end

function TradeUI.open()
	if Features.Market == false then
		UiKit.toast("The Market is closed for this playtest.")
		return
	end
	window.Gui.Enabled = true
	window.Fit()
	request("TradeState")
	-- 3D pictures of spare gear come from the server; redraw once they land.
	task.spawn(function()
		local result = GemClient.request("GearPreviews")
		if result.Ok and window.Gui.Enabled and not busy then
			draw()
		end
	end)
end

-- Opens the Market with a trade partner already picked (from chat, say).
function TradeUI.openWith(userId: number)
	target = userId
	TradeUI.open()
end

local function close()
	window.Gui.Enabled = false
end
window.Close.Activated:Connect(close)
window.Shade.Activated:Connect(close)

RunService.Heartbeat:Connect(function(dt)
	updateClock()
	elapsed += dt
	if elapsed < 1.5 or busy or not window.Gui.Enabled then
		return
	end
	elapsed = 0
	task.spawn(function()
		busy = true
		local result = GemClient.request("TradeState")
		busy = false
		if result.Ok then
			state = result.Trade
			if key(state) ~= lastKey then
				lastKey = key(state)
				draw()
			end
		end
	end)
end)
-- The miner list follows people joining and leaving.
local function playersChanged()
	if window.Gui.Enabled and not state and not busy then
		task.defer(draw)
	end
end
Players.PlayerAdded:Connect(playersChanged)
Players.PlayerRemoving:Connect(playersChanged)
GemClient.Changed:Connect(function()
	if window.Gui.Enabled and not busy then
		draw()
	end
end)

return TradeUI
