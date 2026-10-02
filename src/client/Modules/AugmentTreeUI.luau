--[[
	The Augment Tree: spend Augment Points on Rig Maneuvers, Gem Surges and
	Passive Augments. One branch at a time, chosen from three branch tabs that
	show how far along each one is; the selected node's details, stats and
	Unlock button sit on the right.

	  header   points to spend and progress toward the next point
	  tabs     a card per branch: icon, blurb, unlocked count and a bar
	  tree     three tiers of two node cards, joined by glowing connectors
	  detail   the selected node: description, stats, requirement, Unlock
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Combat = require(ReplicatedStorage.Shared.Combat)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local UI = {}
local player = Players.LocalPlayer
local P = IronUi.Colors
local new, text = IronUi.new, IronUi.text

local WIDTH, HEIGHT = 1100, 700
local window = IronUi.window("AugmentTree", 12, WIDTH, HEIGHT, "✦", P.Gold)
local gui, panel = window.Gui, window.Panel
window.Title.Text = "AUGMENT TREE"
window.Subtitle.Text = "Spend Augment Points on rig maneuvers, gem surges and passive upgrades."

local BRANCH = {
	RigManeuvers = { Color = Color3.fromRGB(65, 195, 112), Icon = "✊", Blurb = "Stamina-powered rig techniques" },
	GemSurges = { Color = Color3.fromRGB(70, 130, 255), Icon = "◆", Blurb = "Charge-powered gem abilities" },
	PassiveAugments = { Color = P.Gold, Icon = "⚙", Blurb = "Always-on upgrades" },
}
local TIERS = { "I", "II", "III" }
local PASSIVE_LABELS = {
	Slashing = "SWORD DAMAGE",
	Cleaving = "AXE DAMAGE",
	Mobility = "MOVE SPEED",
	ChargeRegen = "CHARGE REGEN",
	StaminaRegen = "STAMINA REGEN",
	Thermal = "THERMAL DAMAGE",
}
local LOCKED_FILL = Color3.fromRGB(19, 17, 32)
local MUTED = Color3.fromRGB(110, 104, 136)

local function fixed(label: TextLabel): TextLabel
	label.AutomaticSize = Enum.AutomaticSize.None
	return label
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- A round icon badge: filled in `color` when lit, an outline when not.
local function badge(parent: Instance, icon: string, size: number, color: Color3, lit: boolean): Frame
	local circle = new("Frame", {
		BackgroundColor3 = if lit then color:Lerp(P.Inset, 0.25) else P.Slot,
		Size = UDim2.fromOffset(size, size),
	}, parent)
	UiKit.round(circle, size)
	stroke(circle, if lit then color:Lerp(Color3.new(1, 1, 1), 0.35) else MUTED, 1.5, if lit then 0 else 0.4)
	if lit then
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
		}, circle)
	end
	local glyph = fixed(text(circle, icon, math.floor(size * 0.48), if lit then Color3.new(1, 1, 1) else P.Dim))
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	glyph.TextYAlignment = Enum.TextYAlignment.Center
	return circle
end

-- A small rounded tag of text.
local function pill(parent: Instance, value: string, color: Color3, filled: boolean?): TextLabel
	local tag = new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = color,
		BackgroundTransparency = if filled then 0.15 else 0.82,
		Text = value,
		TextSize = 11,
		Font = IronUi.Bold,
		TextColor3 = if filled then P.Ink else color:Lerp(Color3.new(1, 1, 1), 0.2),
	}, parent)
	UiKit.round(tag, 11)
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, tag)
	return tag
end

-- Header: points to spend and progress toward the next one ------------------------------

local wallet = new("Frame", {
	BackgroundColor3 = P.Inset,
	BackgroundTransparency = 0.2,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -66, 0, 13),
	Size = UDim2.fromOffset(300, 46),
	ZIndex = 4,
}, panel)
UiKit.round(wallet, 10)
stroke(wallet, P.Gold, 1, 0.55)
local pointsValue = fixed(text(wallet, "0", 26, P.Gold, IronUi.Heading))
pointsValue.Position, pointsValue.Size = UDim2.fromOffset(12, 4), UDim2.fromOffset(44, 38)
pointsValue.TextXAlignment, pointsValue.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
pointsValue.ZIndex = 5
local pointsCaption = fixed(text(wallet, "POINTS TO SPEND", 11, P.Gold, IronUi.Bold))
pointsCaption.Position, pointsCaption.Size = UDim2.fromOffset(62, 6), UDim2.new(1, -72, 0, 14)
pointsCaption.ZIndex = 5
local xpTrack = new("Frame", {
	BackgroundColor3 = P.Slot,
	Position = UDim2.fromOffset(62, 24),
	Size = UDim2.new(1, -74, 0, 6),
	ZIndex = 5,
}, wallet)
UiKit.round(xpTrack, 3)
local xpFill = new("Frame", { BackgroundColor3 = P.Gold, Size = UDim2.fromScale(0, 1), ZIndex = 6 }, xpTrack)
UiKit.round(xpFill, 3)
local xpText = fixed(text(wallet, "", 10, P.Dim))
xpText.Position, xpText.Size = UDim2.fromOffset(62, 31), UDim2.new(1, -72, 0, 12)
xpText.TextTruncate = Enum.TextTruncate.AtEnd
xpText.TextWrapped = false
xpText.ZIndex = 5

-- Branch tabs ----------------------------------------------------------------------------

local TAB_Y, TAB_H = 80, 58
local tabs = {}
for index, id in Tree.Branches do
	local meta = BRANCH[id]
	local tab = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = P.Inset,
		Position = UDim2.new((index - 1) / 3, if index == 1 then 20 else 7, 0, TAB_Y),
		Size = UDim2.new(1 / 3, -27, 0, TAB_H),
	}, panel)
	tab:SetAttribute("UiSound", "Tab")
	UiKit.round(tab, 10)
	local edge = stroke(tab, meta.Color, 1, 0.6)
	local icon = badge(tab, meta.Icon, 34, meta.Color, true)
	icon.Position = UDim2.fromOffset(12, 12)
	local name = fixed(text(tab, Tree.BranchNames[id], 16, P.Text, IronUi.Heading))
	name.Position, name.Size = UDim2.fromOffset(56, 9), UDim2.new(1, -120, 0, 20)
	local blurb = fixed(text(tab, meta.Blurb, 11, P.Dim))
	blurb.Position, blurb.Size = UDim2.fromOffset(56, 30), UDim2.new(1, -120, 0, 14)
	blurb.TextTruncate = Enum.TextTruncate.AtEnd
	local count = fixed(text(tab, "0/6", 15, meta.Color, IronUi.Heading))
	count.AnchorPoint, count.Position, count.Size =
		Vector2.new(1, 0), UDim2.new(1, -12, 0, 10), UDim2.fromOffset(56, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right
	local unlockedCaption = fixed(text(tab, "UNLOCKED", 9, P.Dim, IronUi.Bold))
	unlockedCaption.AnchorPoint, unlockedCaption.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 31)
	unlockedCaption.Size, unlockedCaption.TextXAlignment = UDim2.fromOffset(60, 12), Enum.TextXAlignment.Right
	local track = new("Frame", {
		BackgroundColor3 = P.Slot,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -6),
		Size = UDim2.new(1, -24, 0, 3),
	}, tab)
	UiKit.round(track, 2)
	local fill = new("Frame", { BackgroundColor3 = meta.Color, Size = UDim2.fromScale(0, 1) }, track)
	UiKit.round(fill, 2)
	IronUi.juice(tab, 1.015, 0.98)
	tab.Activated:Connect(function()
		UI.selectBranch(id)
	end)
	tabs[id] = { Button = tab, Stroke = edge, Name = name, Count = count, Fill = fill }
end

-- Tree and detail panes ------------------------------------------------------------------

local BODY_Y = TAB_Y + TAB_H + 12
local BODY_H = HEIGHT - BODY_Y - 20
local TREE_W = 664
local treePane = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(16, 14, 30),
	Position = UDim2.fromOffset(20, BODY_Y),
	Size = UDim2.fromOffset(TREE_W, BODY_H),
	ClipsDescendants = true,
}, panel)
UiKit.round(treePane, 12)
stroke(treePane, P.Edge, 1, 0.55)
local tree = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, treePane)

local detailPane = new("Frame", {
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(20 + TREE_W + 12, BODY_Y),
	Size = UDim2.fromOffset(WIDTH - TREE_W - 52, BODY_H),
}, panel)
UiKit.round(detailPane, 12)
local detailStroke = stroke(detailPane, P.Edge, 1, 0.4)
local detail = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 18),
	Size = UDim2.new(1, -40, 1, -128),
}, detailPane)
local unlock = new("TextButton", {
	Text = "UNLOCK",
	TextColor3 = P.Ink,
	TextSize = 16,
	Font = IronUi.Heading,
	AutoButtonColor = false,
	BackgroundColor3 = BRANCH.RigManeuvers.Color,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -46),
	Size = UDim2.new(1, -40, 0, 48),
}, detailPane)
unlock:SetAttribute("UiSound", "Confirm")
UiKit.round(unlock, 10)
local unlockStroke = stroke(unlock, Color3.new(1, 1, 1), 1.5, 0.6)
IronUi.juice(unlock, 1.02, 0.97)
local reset = new("TextButton", {
	Text = "Reset & refund all points",
	TextColor3 = P.Gold,
	TextSize = 12,
	Font = IronUi.Bold,
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -12),
	Size = UDim2.new(1, -40, 0, 26),
}, detailPane)

-- State ----------------------------------------------------------------------------------

local branch = "RigManeuvers"
local selected = "HydraulicSlam"
local busy = false

local function canChange()
	if player:GetAttribute("CombatSession") or player:GetAttribute("Expedition") then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not Combat.canFight(root.Position)
end

local function costText(cost: number): string
	return string.format("%d POINT%s", cost, if cost == 1 then "" else "S")
end

-- One-line summary for a node card: what it costs to use and its headline number.
local function summary(node): string
	local tech = Tech.Catalog[node.Id]
	if not tech then
		return node.Description
	end
	local parts = { string.format("%d %s", tech.Cost or 0, tech.Resource or "") }
	if tech.Damage then
		table.insert(
			parts,
			if tech.Hits
				then string.format("%d × %d%%", tech.Hits, math.floor(tech.Damage * 100 + 0.5))
				else string.format("%d%% dmg", math.floor(tech.Damage * 100 + 0.5))
		)
	elseif tech.Heal then
		table.insert(parts, string.format("+%d%% HP", math.floor(tech.Heal * 100 + 0.5)))
	end
	return table.concat(parts, "  ·  ")
end

-- The stats grid in the detail pane: { value, caption, color? }.
local function stats(node): { { any } }
	local list = {}
	local tech = Tech.Catalog[node.Id]
	if tech then
		local resource = Tech.Resources[tech.Resource]
		table.insert(
			list,
			{ tostring(tech.Cost or 0), string.upper(tech.Resource or "") .. " COST", resource and resource.Color }
		)
		if tech.Damage then
			table.insert(list, {
				if tech.Hits
					then string.format("%d×%d%%", tech.Hits, math.floor(tech.Damage * 100 + 0.5))
					else string.format("%d%%", math.floor(tech.Damage * 100 + 0.5)),
				"WEAPON DAMAGE",
			})
		end
		if tech.Element then
			table.insert(list, {
				string.upper(GemConfig.elementName(tech.Element)),
				"ELEMENT",
				GemConfig.ElementColors[tech.Element],
			})
		end
		if tech.Heal then
			table.insert(list, { string.format("+%d%%", math.floor(tech.Heal * 100 + 0.5)), "HEALTH RESTORED" })
		end
		if tech.Stun then
			table.insert(list, { string.format("%gs", tech.Stun), "STAGGER" })
		end
		if tech.Slow then
			table.insert(list, { string.format("%d%%", math.floor(tech.Slow * 100 + 0.5)), "SLOW" })
		end
		if tech.Duration then
			table.insert(list, { string.format("%gs", tech.Duration), "DURATION" })
		end
		if tech.Range then
			table.insert(list, { tostring(tech.Range), "RANGE" })
		end
		if tech.Radius then
			table.insert(list, { tostring(tech.Radius), "RADIUS" })
		end
		if tech.Recovery then
			table.insert(list, { string.format("%gs", tech.Recovery), "RECOVERY" })
		end
	elseif node.Amount then
		table.insert(list, {
			string.format("+%d%%", math.floor(node.Amount * 100 + 0.5)),
			PASSIVE_LABELS[node.Effect] or "BONUS",
			BRANCH.PassiveAugments.Color,
		})
		table.insert(list, { "ALWAYS", "ON" })
	end
	return list
end

-- Detail pane --------------------------------------------------------------------------

local function drawDetail(data)
	IronUi.clear(detail)
	local node = Tree.Nodes[selected]
	if not node then
		return
	end
	local meta = BRANCH[node.Branch]
	local learned = data.Unlocked[selected] == true
	local parentMet = not node.Parent or data.Unlocked[node.Parent] == true
	local changeable = canChange()
	detailStroke.Color = meta.Color
	detailStroke.Transparency = if learned then 0.2 else 0.55

	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 72) }, detail)
	local icon = badge(top, node.Icon, 64, meta.Color, learned or parentMet)
	icon.Position = UDim2.fromOffset(0, 4)
	local tag = fixed(
		text(
			top,
			string.format("%s  ·  TIER %s", string.upper(Tree.BranchNames[node.Branch]), TIERS[node.Tier] or "?"),
			11,
			meta.Color,
			IronUi.Bold
		)
	)
	tag.Position, tag.Size = UDim2.fromOffset(80, 6), UDim2.new(1, -80, 0, 14)
	local name = fixed(text(top, node.Name, 22, P.Text, IronUi.Heading))
	name.Position, name.Size = UDim2.fromOffset(80, 22), UDim2.new(1, -80, 0, 28)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local status = pill(
		top,
		if learned then "✓  UNLOCKED" elseif parentMet then "AVAILABLE  ·  " .. costText(node.Cost) else "LOCKED",
		if learned then meta.Color elseif parentMet then P.Gold else MUTED,
		learned
	)
	status.Position = UDim2.fromOffset(80, 52)

	local about = text(detail, node.Description, 14, P.Text)
	about.Position = UDim2.fromOffset(0, 90)

	local grid = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 200),
	}, detail)
	local caption = fixed(text(grid, "STATS", 11, P.Dim, IronUi.Bold))
	caption.Size = UDim2.new(1, 0, 0, 14)
	local cells = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 1, -20),
	}, grid)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -5, 0, 52),
		CellPadding = UDim2.fromOffset(10, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, cells)
	for i, entry in stats(node) do
		local cell = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 16, 33), LayoutOrder = i }, cells)
		UiKit.round(cell, 8)
		stroke(cell, entry[3] or P.Edge, 1, if entry[3] then 0.5 else 0.75)
		local value = fixed(text(cell, entry[1], 18, entry[3] or P.Text, IronUi.Heading))
		value.Position, value.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -20, 0, 22)
		value.TextTruncate = Enum.TextTruncate.AtEnd
		local label = fixed(text(cell, entry[2], 10, P.Dim, IronUi.Bold))
		label.Position, label.Size = UDim2.fromOffset(12, 30), UDim2.new(1, -20, 0, 14)
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end

	-- Requirement, just above the button.
	local requirement = fixed(
		text(
			detail,
			if not changeable
				then "⚠  Return to the dashboard or town to change augments."
				elseif not node.Parent then "✓  Starting node, no prerequisite"
				elseif parentMet then "✓  Requires " .. Tree.Nodes[node.Parent].Name
				else "🔒  Requires " .. Tree.Nodes[node.Parent].Name,
			12,
			if not changeable then P.Bad elseif parentMet then P.Good else MUTED,
			IronUi.Bold
		)
	)
	requirement.AnchorPoint = Vector2.new(0, 1)
	requirement.Position, requirement.Size = UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0, 18)

	local ready = not busy and not learned and parentMet and data.Points >= node.Cost and changeable
	unlock.Text = if busy
		then "APPLYING…"
		elseif learned then "✓  UNLOCKED"
		elseif not parentMet then "🔒  PREREQUISITE LOCKED"
		elseif data.Points < node.Cost then "NEED " .. costText(node.Cost)
		else "UNLOCK  ·  " .. costText(node.Cost)
	unlock.Active = ready
	unlock.BackgroundColor3 = if ready then meta.Color elseif learned then meta.Color:Lerp(P.Inset, 0.7) else P.Slot
	unlock.TextColor3 = if ready then P.Ink elseif learned then meta.Color else P.Dim
	unlockStroke.Transparency = if ready then 0.4 else 1
	reset.Active = not busy and changeable and data.Spent > 0
	reset.TextColor3 = if reset.Active then P.Gold else MUTED
	reset.Text = if data.Spent > 0
		then string.format("Reset & refund %s", costText(data.Spent):lower())
		else "Nothing to refund yet"
end

-- Tree --------------------------------------------------------------------------------

local GUTTER = 70 -- tier labels
local ROW_TOP = 18
local CARD_W, CARD_H = 250, 112

local function line(from: Vector2, to: Vector2, color: Color3, thickness: number, transparency: number)
	local delta = to - from
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2),
		Size = UDim2.fromOffset(delta.Magnitude, thickness),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		ZIndex = 1,
	}, tree)
end

local function drawTree(data)
	IronUi.clear(tree)
	local meta = BRANCH[branch]
	local rowH = (BODY_H - ROW_TOP * 2) / 3
	local area = TREE_W - GUTTER - 16
	local positions = {}
	for _, nodeId in Tree.Order[branch] do
		local node = Tree.Nodes[nodeId]
		positions[nodeId] =
			Vector2.new(GUTTER + area * (if node.Column == 1 then 0.25 else 0.75), ROW_TOP + (node.Tier - 0.5) * rowH)
	end

	-- Tier labels and faint row bands.
	for tier = 1, 3 do
		local y = ROW_TOP + (tier - 1) * rowH
		local band = new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = if tier % 2 == 1 then 0.985 else 1,
			Position = UDim2.fromOffset(10, y + 4),
			Size = UDim2.new(1, -20, 0, rowH - 8),
		}, tree)
		UiKit.round(band, 10)
		local label = fixed(text(tree, "TIER", 10, P.Dim, IronUi.Bold))
		label.Position, label.Size = UDim2.fromOffset(14, y + rowH / 2 - 20), UDim2.fromOffset(48, 12)
		label.TextXAlignment = Enum.TextXAlignment.Center
		local numeral = fixed(text(tree, TIERS[tier], 22, meta.Color, IronUi.Heading))
		numeral.Position, numeral.Size = UDim2.fromOffset(14, y + rowH / 2 - 8), UDim2.fromOffset(48, 26)
		numeral.TextXAlignment = Enum.TextXAlignment.Center
	end

	-- Connectors, under the cards: lit when unlocked, white when next, dim when locked.
	for _, nodeId in Tree.Order[branch] do
		local node = Tree.Nodes[nodeId]
		if node.Parent then
			local from, to = positions[node.Parent], positions[nodeId]
			if data.Unlocked[nodeId] then
				line(from, to, meta.Color, 10, 0.8)
				line(from, to, meta.Color, 4, 0)
			elseif data.Unlocked[node.Parent] then
				line(from, to, P.Text, 3, 0.5)
			else
				line(from, to, MUTED, 2, 0.6)
			end
		end
	end

	for _, nodeId in Tree.Order[branch] do
		local node, center = Tree.Nodes[nodeId], positions[nodeId]
		local learned = data.Unlocked[nodeId] == true
		local available = not learned and (not node.Parent or data.Unlocked[node.Parent] == true)
		local isSelected = nodeId == selected
		local card = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			BackgroundColor3 = if learned
				then meta.Color:Lerp(P.Inset, 0.8)
				elseif available then P.Inset
				else LOCKED_FILL,
			ZIndex = 2,
		}, tree)
		card:SetAttribute("UiSound", "Click")
		UiKit.round(card, 12)
		stroke(
			card,
			if isSelected then P.Gold elseif learned then meta.Color elseif available then P.Text else MUTED,
			if isSelected then 2.5 elseif learned then 1.5 else 1,
			if isSelected or learned then 0 elseif available then 0.45 else 0.6
		)
		if learned then
			new("UIGradient", {
				Rotation = 0,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
			}, card)
		end
		local icon = badge(card, node.Icon, 48, meta.Color, learned)
		icon.Position = UDim2.fromOffset(14, 16)
		icon.ZIndex = 3
		for _, child in icon:GetChildren() do
			if child:IsA("GuiObject") then
				child.ZIndex = 4
			end
		end
		local name = fixed(text(card, node.Name, 15, if learned or available then P.Text else P.Dim, IronUi.Heading))
		name.Position, name.Size = UDim2.fromOffset(74, 16), UDim2.new(1, -84, 0, 20)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 3
		local line2 = fixed(text(card, summary(node), 11, if learned or available then P.Dim else MUTED))
		line2.Position, line2.Size = UDim2.fromOffset(74, 38), UDim2.new(1, -84, 0, 28)
		line2.TextYAlignment = Enum.TextYAlignment.Top
		line2.TextTruncate = Enum.TextTruncate.AtEnd
		line2.ZIndex = 3
		local state = pill(
			card,
			if learned then "✓  ACTIVE" elseif available then "◆  " .. costText(node.Cost) else "🔒  LOCKED",
			if learned then meta.Color elseif available then P.Gold else MUTED,
			learned
		)
		state.Position = UDim2.fromOffset(74, CARD_H - 34)
		state.ZIndex = 3
		IronUi.juice(card, 1.03, 0.97)
		card.Activated:Connect(function()
			selected = nodeId
			UI.refresh()
		end)
	end
end

-- Refresh -----------------------------------------------------------------------------

function UI.refresh()
	if not gui.Enabled or not GemClient.Profile then
		return
	end
	local data = Tree.initialize(GemClient.Profile)
	if not Tree.Nodes[selected] or Tree.Nodes[selected].Branch ~= branch then
		selected = Tree.Order[branch][1]
	end

	pointsValue.Text = tostring(data.Points)
	pointsCaption.Text =
		string.format("POINT%s TO SPEND  ·  %d SPENT", if data.Points == 1 then "" else "S", data.Spent)
	if data.Earned >= Tree.MaxPoints then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "All Augment Points earned"
	else
		local into = data.XP % Tree.XPPerPoint
		xpFill.Size = UDim2.fromScale(into / Tree.XPPerPoint, 1)
		xpText.Text = string.format("%d / %d XP to next point  ·  mine, sell or fight", into, Tree.XPPerPoint)
	end

	for id, tab in tabs do
		local meta, on = BRANCH[id], id == branch
		local total, owned = #Tree.Order[id], 0
		for _, nodeId in Tree.Order[id] do
			if data.Unlocked[nodeId] then
				owned += 1
			end
		end
		tab.Count.Text = string.format("%d/%d", owned, total)
		tab.Fill.Size = UDim2.fromScale(owned / total, 1)
		tab.Button.BackgroundColor3 = if on then meta.Color:Lerp(P.Inset, 0.78) else P.Inset
		tab.Button.BackgroundTransparency = if on then 0 else 0.35
		tab.Stroke.Transparency = if on then 0 else 0.7
		tab.Stroke.Thickness = if on then 2 else 1
		tab.Name.TextColor3 = if on then Color3.new(1, 1, 1) else P.Dim
	end

	drawTree(data)
	drawDetail(data)
end

function UI.selectBranch(id)
	if not Tree.Order[id] then
		return
	end
	if id ~= branch then
		branch = id
		selected = Tree.Order[id][1]
	end
	UI.refresh()
end

local function request(action, id)
	if busy or not canChange() then
		return
	end
	busy = true
	UI.refresh()
	task.spawn(function()
		local result = GemClient.request(action, id)
		busy = false
		if result.Augments and GemClient.Profile then
			GemClient.Profile.Augments = result.Augments
		end
		UiKit.toast(result.Message, if result.Ok then P.Teal else UiKit.Colors.Bad)
		UI.refresh()
	end)
end

unlock.Activated:Connect(function()
	if unlock.Active then
		request("LearnAugment", selected)
	end
end)
reset.Activated:Connect(function()
	if reset.Active then
		request("ResetAugments")
	end
end)

function UI.isOpen()
	return gui.Enabled
end
function UI.open()
	gui.Enabled = true
	UI.refresh()
end
function UI.close()
	gui.Enabled = false
end
function UI.toggle()
	if gui.Enabled then
		UI.close()
	else
		UI.open()
	end
end
window.Close.Activated:Connect(UI.close)
window.Shade.Activated:Connect(UI.close)
GemClient.Changed:Connect(UI.refresh)
player:GetAttributeChangedSignal("CombatSession"):Connect(UI.refresh)
player:GetAttributeChangedSignal("Expedition"):Connect(UI.refresh)
return UI
