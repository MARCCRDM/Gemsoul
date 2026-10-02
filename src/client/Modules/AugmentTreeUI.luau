--[[
	The Augment Tree, laid out like an Elder Scrolls: Blades skill sheet in
	Saga Miners' colours: Rig Maneuvers (abilities), Gem Surges (gem spells)
	and Passive Augments (perks).

	  header   Augment Level, XP to the next level, Augment Points to spend
	  tabs     a card per branch with its ranks earned
	  sheet    three tier bands, each opening at an Augment Level; every
	           node is a medallion with its rank (I-III) as pips
	  detail   the selected node: rank, current and next-rank numbers side by
	           side, requirements, and Learn / Upgrade
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
window.Subtitle.Text = "Level up to open new tiers. Spend Augment Points to learn and rank up."

local BRANCH = {
	RigManeuvers = {
		Color = Color3.fromRGB(65, 195, 112),
		Icon = "✊",
		Kind = "Ability",
		Blurb = "Abilities  ·  powered by Stamina",
	},
	GemSurges = {
		Color = Color3.fromRGB(70, 130, 255),
		Icon = "◆",
		Kind = "Gem Spell",
		Blurb = "Gem spells  ·  powered by Charge",
	},
	PassiveAugments = { Color = P.Gold, Icon = "⚙", Kind = "Perk", Blurb = "Perks  ·  always on" },
}
local NUMERALS = { "I", "II", "III" }
local PASSIVE_LABELS = {
	Slashing = "Sword damage",
	Cleaving = "Axe damage",
	Mobility = "Move speed",
	ChargeRegen = "Charge regeneration",
	StaminaRegen = "Stamina regeneration",
	Thermal = "Thermal damage",
}
local BRONZE = Color3.fromRGB(196, 150, 82)
local LOCKED_FILL = Color3.fromRGB(19, 17, 32)
local MUTED = Color3.fromRGB(110, 104, 136)
local GOOD = Color3.fromRGB(120, 230, 150)

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

local function centered(label: TextLabel): TextLabel
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

local function costText(cost: number): string
	return string.format("%d POINT%s", cost, if cost == 1 then "" else "S")
end

--[[
	A medallion: a bronze ring around a dark disc holding the node's icon.
	Learned nodes glow in their branch colour; locked ones are grey.
	state: "learned" | "open" | "locked"
]]
local function medallion(parent: Instance, icon: string, size: number, color: Color3, state: string): Frame
	local lit = state == "learned"
	local ring = new("Frame", {
		BackgroundColor3 = if lit then BRONZE elseif state == "open" then Color3.fromRGB(92, 84, 112) else LOCKED_FILL,
		Size = UDim2.fromOffset(size, size),
	}, parent)
	UiKit.round(ring, size)
	stroke(
		ring,
		if lit then P.Gold elseif state == "open" then P.Text else MUTED,
		if lit then 2 else 1,
		if lit then 0 elseif state == "open" then 0.35 else 0.55
	)
	if lit then
		new("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(Color3.fromRGB(255, 226, 160), Color3.fromRGB(150, 104, 48)),
		}, ring)
	end
	local inset = math.max(4, math.floor(size * 0.09))
	local disc = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		BackgroundColor3 = if lit then color:Lerp(Color3.new(0, 0, 0), 0.35) else Color3.fromRGB(24, 21, 38),
	}, ring)
	UiKit.round(disc, size)
	if lit then
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.55)),
		}, disc)
	end
	local glyph =
		centered(fixed(text(disc, icon, math.floor(size * 0.42), if state == "locked" then MUTED else P.Text)))
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextTransparency = if state == "locked" then 0.35 else 0
	return ring
end

-- Rank pips: ◆ for each rank owned, ◇ for each still to earn.
local function pips(parent: Instance, rank: number, color: Color3, size: number): TextLabel
	local marks = {}
	for i = 1, Tree.MaxRank do
		table.insert(marks, if i <= rank then "◆" else "◇")
	end
	local label = centered(fixed(text(parent, table.concat(marks, " "), size, if rank > 0 then color else MUTED)))
	return label
end

-- Header: Augment Level, XP and points ----------------------------------------------------

local wallet = new("Frame", {
	BackgroundColor3 = P.Inset,
	BackgroundTransparency = 0.15,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -66, 0, 12),
	Size = UDim2.fromOffset(340, 48),
	ZIndex = 4,
}, panel)
UiKit.round(wallet, 10)
stroke(wallet, BRONZE, 1, 0.4)
local function walletLabel(value: string, size: number, color: Color3, font, x: number, y: number, w: number, h: number)
	local label = fixed(text(wallet, value, size, color, font))
	label.Position, label.Size, label.ZIndex = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h), 5
	return label
end
walletLabel("LEVEL", 9, P.Dim, IronUi.Bold, 12, 6, 50, 10)
local levelValue = walletLabel("1", 22, P.Text, IronUi.Heading, 12, 16, 50, 26)
local xpText = walletLabel("", 10, P.Dim, IronUi.Body, 66, 8, 170, 12)
xpText.TextWrapped = false
local xpTrack = new("Frame", {
	BackgroundColor3 = P.Slot,
	Position = UDim2.fromOffset(66, 26),
	Size = UDim2.fromOffset(170, 8),
	ZIndex = 5,
}, wallet)
UiKit.round(xpTrack, 4)
local xpFill = new("Frame", { BackgroundColor3 = BRONZE, Size = UDim2.fromScale(0, 1), ZIndex = 6 }, xpTrack)
UiKit.round(xpFill, 4)
new("Frame", {
	BackgroundColor3 = BRONZE,
	BackgroundTransparency = 0.5,
	Position = UDim2.fromOffset(248, 8),
	Size = UDim2.fromOffset(1, 32),
	ZIndex = 5,
}, wallet)
local pointsValue = walletLabel("0", 22, P.Gold, IronUi.Heading, 258, 4, 72, 26)
pointsValue.TextXAlignment = Enum.TextXAlignment.Center
local pointsCaption = walletLabel("POINTS", 9, P.Gold, IronUi.Bold, 258, 31, 72, 10)
pointsCaption.TextXAlignment = Enum.TextXAlignment.Center

-- Branch tabs ----------------------------------------------------------------------------

local TAB_Y, TAB_H = 78, 56
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
	local icon = medallion(tab, meta.Icon, 36, meta.Color, "learned")
	icon.Position = UDim2.fromOffset(12, 10)
	local name = fixed(text(tab, Tree.BranchNames[id], 16, P.Text, IronUi.Heading))
	name.Position, name.Size = UDim2.fromOffset(58, 9), UDim2.new(1, -130, 0, 20)
	local blurb = fixed(text(tab, meta.Blurb, 11, P.Dim))
	blurb.Position, blurb.Size = UDim2.fromOffset(58, 30), UDim2.new(1, -130, 0, 14)
	blurb.TextTruncate = Enum.TextTruncate.AtEnd
	local count = fixed(text(tab, "0/18", 15, meta.Color, IronUi.Heading))
	count.AnchorPoint, count.Position, count.Size = Vector2.new(1, 0), UDim2.new(1, -12, 0, 9), UDim2.fromOffset(64, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right
	local caption = fixed(text(tab, "RANKS", 9, P.Dim, IronUi.Bold))
	caption.AnchorPoint, caption.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 30)
	caption.Size, caption.TextXAlignment = UDim2.fromOffset(64, 12), Enum.TextXAlignment.Right
	local track = new("Frame", {
		BackgroundColor3 = P.Slot,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -5),
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

-- Sheet and detail panes -----------------------------------------------------------------

local BODY_Y = TAB_Y + TAB_H + 12
local BODY_H = HEIGHT - BODY_Y - 20
local SHEET_W = 640
local sheetPane = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(15, 13, 28),
	Position = UDim2.fromOffset(20, BODY_Y),
	Size = UDim2.fromOffset(SHEET_W, BODY_H),
	ClipsDescendants = true,
}, panel)
UiKit.round(sheetPane, 12)
stroke(sheetPane, BRONZE, 1, 0.55)
local sheet = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, sheetPane)

local detailPane = new("Frame", {
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(20 + SHEET_W + 12, BODY_Y),
	Size = UDim2.fromOffset(WIDTH - SHEET_W - 52, BODY_H),
}, panel)
UiKit.round(detailPane, 12)
local detailStroke = stroke(detailPane, BRONZE, 1, 0.45)
local detail = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 16),
	Size = UDim2.new(1, -36, 1, -122),
}, detailPane)
local action = new("TextButton", {
	Text = "LEARN",
	TextColor3 = P.Ink,
	TextSize = 16,
	Font = IronUi.Heading,
	AutoButtonColor = false,
	BackgroundColor3 = BRANCH.RigManeuvers.Color,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -44),
	Size = UDim2.new(1, -36, 0, 48),
}, detailPane)
action:SetAttribute("UiSound", "Confirm")
UiKit.round(action, 10)
local actionStroke = stroke(action, Color3.new(1, 1, 1), 1.5, 0.6)
IronUi.juice(action, 1.02, 0.97)
local reset = new("TextButton", {
	Text = "Nothing to refund yet",
	TextColor3 = P.Gold,
	TextSize = 12,
	Font = IronUi.Bold,
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -12),
	Size = UDim2.new(1, -36, 0, 24),
}, detailPane)

-- State ----------------------------------------------------------------------------------

local branch = "RigManeuvers"
local selected = "HydraulicSlam"
local busy = false
local nextAction: string? = nil -- "LearnAugment" | "UpgradeAugment" when the button can act

local function canChange()
	if player:GetAttribute("CombatSession") or player:GetAttribute("Expedition") then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not Combat.canFight(root.Position)
end

local function rankOf(data, id: string): number
	return if data.Unlocked[id] then (data.Ranks and data.Ranks[id] or 1) else 0
end

local function percent(value: number): string
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

local function seconds(value: number): string
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")) .. "s"
end

-- A node's numbers at `rank` as { label, value } rows, in a fixed order so
-- two ranks can be compared line by line.
local function rankRows(node, rank: number): { { string } }
	local rows = {}
	local tech = Tech.Catalog[node.Id]
	if tech then
		local s = Tree.scaled(tech, math.max(1, rank))
		table.insert(rows, { (tech.Resource or "Resource") .. " cost", tostring(math.floor((s.Cost or 0) + 0.5)) })
		if s.Damage then
			table.insert(rows, {
				"Weapon damage",
				if s.Hits then string.format("%d × %s", s.Hits, percent(s.Damage)) else percent(s.Damage),
			})
		end
		if s.Heal then
			table.insert(rows, { "Health restored", percent(s.Heal) })
		end
		if s.Duration then
			table.insert(rows, { "Duration", seconds(s.Duration) })
		end
		if s.Recovery then
			table.insert(rows, { "Recovery", seconds(s.Recovery) })
		end
	elseif node.Amount then
		table.insert(rows, { PASSIVE_LABELS[node.Effect] or "Bonus", "+" .. percent(node.Amount * math.max(1, rank)) })
	end
	return rows
end

-- Fixed traits that don't change with rank, shown as chips.
local function traits(node): { { any } }
	local list = {}
	local tech = Tech.Catalog[node.Id]
	if not tech then
		table.insert(list, { "ALWAYS ON" })
		return list
	end
	if tech.Element then
		table.insert(list, { string.upper(GemConfig.elementName(tech.Element)), GemConfig.ElementColors[tech.Element] })
	end
	if tech.Range then
		table.insert(list, { "RANGE " .. tech.Range })
	end
	if tech.Radius then
		table.insert(list, { "RADIUS " .. tech.Radius })
	end
	if tech.Stun then
		table.insert(list, { "STAGGER " .. seconds(tech.Stun) })
	end
	if tech.Slow then
		table.insert(list, { "SLOW " .. percent(tech.Slow) })
	end
	if tech.Heavy then
		table.insert(list, { "BREAKS GUARD" })
	end
	return list
end

-- Detail pane --------------------------------------------------------------------------

local function chip(parent: Instance, value: string, color: Color3?, order: number)
	local tag = new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundColor3 = color or P.Slot,
		BackgroundTransparency = if color then 0.8 else 0.2,
		Text = value,
		TextSize = 10,
		Font = IronUi.Bold,
		TextColor3 = if color then color:Lerp(Color3.new(1, 1, 1), 0.25) else P.Dim,
		LayoutOrder = order,
	}, parent)
	UiKit.round(tag, 10)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tag)
end

local function drawDetail(data)
	IronUi.clear(detail)
	local node = Tree.Nodes[selected]
	if not node then
		return
	end
	local meta = BRANCH[node.Branch]
	local rank = rankOf(data, selected)
	local learned = rank > 0
	local parentMet = not node.Parent or data.Unlocked[node.Parent] == true
	local levelNeeded = Tree.tierLevel(selected)
	local levelMet = data.Level >= levelNeeded
	local changeable = canChange()
	detailStroke.Color = if learned then meta.Color else BRONZE
	detailStroke.Transparency = if learned then 0.25 else 0.55

	-- Medallion, kind and tier, name, rank.
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 84) }, detail)
	local badge = medallion(
		top,
		node.Icon,
		80,
		meta.Color,
		if learned then "learned" elseif parentMet and levelMet then "open" else "locked"
	)
	badge.Position = UDim2.fromOffset(0, 2)
	local kind = fixed(
		text(
			top,
			string.format("%s  ·  TIER %s", string.upper(meta.Kind), NUMERALS[node.Tier] or "?"),
			11,
			meta.Color,
			IronUi.Bold
		)
	)
	kind.Position, kind.Size = UDim2.fromOffset(94, 6), UDim2.new(1, -94, 0, 14)
	local name = fixed(text(top, node.Name, 22, P.Text, IronUi.Heading))
	name.Position, name.Size = UDim2.fromOffset(94, 22), UDim2.new(1, -94, 0, 28)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local rankLine = fixed(
		text(
			top,
			if learned then string.format("RANK %s / %s", NUMERALS[rank], NUMERALS[Tree.MaxRank]) else "NOT LEARNED",
			12,
			if learned then P.Gold else MUTED,
			IronUi.Bold
		)
	)
	rankLine.Position, rankLine.Size = UDim2.fromOffset(94, 54), UDim2.fromOffset(110, 18)
	local rankPips = pips(top, rank, P.Gold, 16)
	rankPips.Position, rankPips.Size = UDim2.fromOffset(204, 52), UDim2.fromOffset(70, 20)
	rankPips.TextXAlignment = Enum.TextXAlignment.Left

	local about = text(detail, node.Description, 13, P.Text)
	about.Position = UDim2.fromOffset(0, 92)

	local chips = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, 22),
	}, detail)
	UiKit.list(chips, 6, true)
	for i, entry in traits(node) do
		chip(chips, entry[1], entry[2], i)
	end

	-- Current rank vs next rank, Blades-style.
	local compare = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(16, 14, 30),
		Position = UDim2.fromOffset(0, 164),
		Size = UDim2.new(1, 0, 0, 160),
	}, detail)
	UiKit.round(compare, 10)
	stroke(compare, BRONZE, 1, 0.65)
	local nextRank = if rank < Tree.MaxRank then rank + 1 else nil
	local current = rankRows(node, rank)
	local upcoming = if nextRank then rankRows(node, nextRank) else nil
	local function heading(value: string, x: number, color: Color3)
		local label = fixed(text(compare, value, 10, color, IronUi.Bold))
		label.Position, label.Size = UDim2.new(x, 12, 0, 10), UDim2.new(0.5, -16, 0, 12)
	end
	heading(if learned then "CURRENT  ·  RANK " .. NUMERALS[rank] else "CURRENT  ·  NOT LEARNED", 0, P.Dim)
	heading(
		if nextRank then "NEXT  ·  RANK " .. NUMERALS[nextRank] else "MASTERED",
		0.5,
		if nextRank then GOOD else P.Gold
	)
	new("Frame", {
		BackgroundColor3 = BRONZE,
		BackgroundTransparency = 0.6,
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0, 1, 1, -20),
	}, compare)
	for i, row in (if learned then current else upcoming) or current do
		local y = 32 + (i - 1) * 31
		local label = fixed(text(compare, row[1], 10, P.Dim))
		label.Position, label.Size = UDim2.new(0, 12, 0, y), UDim2.new(0.5, -20, 0, 10)
		label.TextTruncate = Enum.TextTruncate.AtEnd
		local now = fixed(text(compare, if learned then current[i][2] else "—", 13, P.Text, IronUi.Bold))
		now.Position, now.Size = UDim2.new(0, 12, 0, y + 12), UDim2.new(0.5, -20, 0, 16)
		if upcoming and upcoming[i] then
			local changed = not learned or upcoming[i][2] ~= current[i][2]
			local nextValue = fixed(
				text(
					compare,
					upcoming[i][2] .. (if changed then "  ▲" else ""),
					13,
					if changed then GOOD else P.Dim,
					IronUi.Bold
				)
			)
			nextValue.Position, nextValue.Size = UDim2.new(0.5, 12, 0, y + 12), UDim2.new(0.5, -20, 0, 16)
			local nextLabel = fixed(text(compare, upcoming[i][1], 10, P.Dim))
			nextLabel.Position, nextLabel.Size = UDim2.new(0.5, 12, 0, y), UDim2.new(0.5, -20, 0, 10)
			nextLabel.TextTruncate = Enum.TextTruncate.AtEnd
		end
	end
	if not nextRank then
		local done = centered(fixed(text(compare, "Highest rank reached", 12, P.Gold, IronUi.Bold)))
		done.Position, done.Size = UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0.5, 0, 0, 20)
	end

	-- Requirements.
	local requirements = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 40),
	}, detail)
	UiKit.list(requirements, 4)
	local function requirement(ok: boolean, value: string, order: number)
		local line = fixed(
			text(
				requirements,
				(if ok then "✓  " else "🔒  ") .. value,
				12,
				if ok then P.Good else MUTED,
				IronUi.Bold
			)
		)
		line.Size, line.LayoutOrder = UDim2.new(1, 0, 0, 16), order
	end
	requirement(levelMet, string.format("Augment Level %d", levelNeeded), 1)
	if node.Parent then
		requirement(parentMet, "Learn " .. Tree.Nodes[node.Parent].Name, 2)
	elseif not changeable then
		requirement(false, "Return to the dashboard or town to change augments", 2)
	else
		requirement(true, "Starting node of its tier", 2)
	end

	-- The button: Learn, Upgrade, or why not.
	local cost = if learned then (if nextRank then Tree.rankCost(selected, nextRank) else 0) else node.Cost
	local affordable = data.Points >= cost
	nextAction = nil
	if busy then
		action.Text = "APPLYING…"
	elseif learned and not nextRank then
		action.Text = "✓  MASTERED"
	elseif not learned and not parentMet then
		action.Text = "🔒  PREREQUISITE LOCKED"
	elseif not learned and not levelMet then
		action.Text = "🔒  REACH LEVEL " .. levelNeeded
	elseif not affordable then
		action.Text = "NEED " .. costText(cost)
	elseif learned then
		action.Text = string.format("UPGRADE TO RANK %s  ·  %s", NUMERALS[nextRank], costText(cost))
		nextAction = "UpgradeAugment"
	else
		action.Text = "LEARN  ·  " .. costText(cost)
		nextAction = "LearnAugment"
	end
	if not changeable then
		nextAction = nil
	end
	local ready = nextAction ~= nil
	action.Active = ready
	action.BackgroundColor3 = if ready then meta.Color elseif learned then meta.Color:Lerp(P.Inset, 0.7) else P.Slot
	action.TextColor3 = if ready then P.Ink elseif learned then meta.Color else P.Dim
	actionStroke.Transparency = if ready then 0.4 else 1
	reset.Active = not busy and changeable and data.Spent > 0
	reset.TextColor3 = if reset.Active then P.Gold else MUTED
	reset.Text = if data.Spent > 0
		then string.format("Reset & refund %s", costText(data.Spent):lower())
		else "Nothing to refund yet"
end

-- Sheet --------------------------------------------------------------------------------

local MEDAL = 72
local NODE_W, NODE_H = 170, 128

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
	}, sheet)
end

local function drawSheet(data)
	IronUi.clear(sheet)
	local meta = BRANCH[branch]
	local bandH = (BODY_H - 24) / 3
	local centers = {}
	for _, nodeId in Tree.Order[branch] do
		local node = Tree.Nodes[nodeId]
		centers[nodeId] = Vector2.new(
			SHEET_W * (if node.Column == 1 then 0.33 else 0.72),
			12 + (node.Tier - 1) * bandH + 28 + MEDAL / 2
		)
	end

	-- Tier bands: a header with the level that opens them.
	for tier = 1, 3 do
		local y = 12 + (tier - 1) * bandH
		local open = data.Level >= Tree.TierLevels[tier]
		local band = new("Frame", {
			BackgroundColor3 = if open then meta.Color else Color3.new(0, 0, 0),
			BackgroundTransparency = if open then 0.95 else 0.6,
			Position = UDim2.fromOffset(12, y),
			Size = UDim2.new(1, -24, 0, bandH - 8),
			ZIndex = 0,
		}, sheet)
		UiKit.round(band, 10)
		stroke(band, if open then BRONZE else MUTED, 1, if open then 0.7 else 0.8)
		local title = fixed(text(band, "TIER " .. NUMERALS[tier], 13, if open then P.Gold else MUTED, IronUi.Heading))
		title.Position, title.Size = UDim2.fromOffset(14, 8), UDim2.fromOffset(90, 16)
		local gate = fixed(
			text(
				band,
				if open
					then string.format("LEVEL %d  ·  OPEN", Tree.TierLevels[tier])
					else string.format("🔒  REACH AUGMENT LEVEL %d", Tree.TierLevels[tier]),
				10,
				if open then P.Dim else MUTED,
				IronUi.Bold
			)
		)
		gate.Position, gate.Size = UDim2.fromOffset(14, 26), UDim2.fromOffset(170, 12)
	end

	-- Connectors under the medallions.
	for _, nodeId in Tree.Order[branch] do
		local node = Tree.Nodes[nodeId]
		if node.Parent then
			local from, to = centers[node.Parent], centers[nodeId]
			if data.Unlocked[nodeId] then
				line(from, to, P.Gold, 8, 0.8)
				line(from, to, BRONZE, 3, 0)
			elseif data.Unlocked[node.Parent] then
				line(from, to, P.Text, 2, 0.5)
			else
				line(from, to, MUTED, 2, 0.65)
			end
		end
	end

	for _, nodeId in Tree.Order[branch] do
		local node, center = Tree.Nodes[nodeId], centers[nodeId]
		local rank = rankOf(data, nodeId)
		local open = rank == 0
			and (not node.Parent or data.Unlocked[node.Parent] == true)
			and data.Level >= Tree.tierLevel(nodeId)
		local state = if rank > 0 then "learned" elseif open then "open" else "locked"
		local isSelected = nodeId == selected
		local holder = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(center.X, center.Y - MEDAL / 2 - 4),
			Size = UDim2.fromOffset(NODE_W, NODE_H),
			ZIndex = 2,
		}, sheet)
		holder:SetAttribute("AugmentNode", nodeId)
		holder:SetAttribute("UiSound", "Click")
		if isSelected then
			local halo = new("Frame", {
				BackgroundColor3 = P.Gold,
				BackgroundTransparency = 0.8,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, -2),
				Size = UDim2.fromOffset(MEDAL + 16, MEDAL + 16),
				ZIndex = 2,
			}, holder)
			UiKit.round(halo, MEDAL)
			stroke(halo, P.Gold, 2, 0)
		end
		local medal = medallion(holder, node.Icon, MEDAL, meta.Color, state)
		medal.AnchorPoint = Vector2.new(0.5, 0)
		medal.Position = UDim2.new(0.5, 0, 0, 6)
		medal.ZIndex = 3
		-- Rank numeral on the medallion's rim.
		if rank > 0 then
			local tag = centered(fixed(text(holder, NUMERALS[rank], 11, P.Ink, IronUi.Heading)))
			tag.BackgroundColor3, tag.BackgroundTransparency = P.Gold, 0
			tag.AnchorPoint = Vector2.new(0.5, 0.5)
			tag.Position = UDim2.new(0.5, MEDAL / 2 - 6, 0, 6 + MEDAL - 8)
			tag.Size, tag.ZIndex = UDim2.fromOffset(24, 18), 5
			UiKit.round(tag, 9)
		elseif state == "locked" then
			local lock = centered(fixed(text(holder, "🔒", 12, P.Text)))
			lock.BackgroundColor3, lock.BackgroundTransparency = LOCKED_FILL, 0
			lock.AnchorPoint = Vector2.new(0.5, 0.5)
			lock.Position = UDim2.new(0.5, MEDAL / 2 - 6, 0, 6 + MEDAL - 8)
			lock.Size, lock.ZIndex = UDim2.fromOffset(22, 22), 5
			UiKit.round(lock, 11)
		end
		local name =
			centered(fixed(text(holder, node.Name, 13, if state == "locked" then MUTED else P.Text, IronUi.Heading)))
		name.Position, name.Size, name.ZIndex = UDim2.fromOffset(0, MEDAL + 12), UDim2.new(1, 0, 0, 16), 3
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local sub = if rank > 0
			then pips(holder, rank, P.Gold, 12)
			else centered(
				fixed(
					text(
						holder,
						if state == "open" then "◆ " .. costText(node.Cost) else "LOCKED",
						10,
						if state == "open" then P.Gold else MUTED,
						IronUi.Bold
					)
				)
			)
		sub.Position, sub.Size, sub.ZIndex = UDim2.fromOffset(0, MEDAL + 29), UDim2.new(1, 0, 0, 14), 3
		IronUi.juice(holder, 1.04, 0.97)
		holder.Activated:Connect(function()
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

	levelValue.Text = tostring(data.Level)
	pointsValue.Text = tostring(data.Points)
	pointsCaption.Text = if data.Points == 1 then "POINT" else "POINTS"
	if data.Level >= Tree.MaxLevel then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "Highest Augment Level"
	else
		local into = data.XP % Tree.XPPerPoint
		xpFill.Size = UDim2.fromScale(into / Tree.XPPerPoint, 1)
		xpText.Text = string.format("%d / %d XP to level %d", into, Tree.XPPerPoint, data.Level + 1)
	end

	for id, tab in tabs do
		local meta, on = BRANCH[id], id == branch
		local owned, total = 0, #Tree.Order[id] * Tree.MaxRank
		for _, nodeId in Tree.Order[id] do
			owned += rankOf(data, nodeId)
		end
		tab.Count.Text = string.format("%d/%d", owned, total)
		tab.Fill.Size = UDim2.fromScale(owned / total, 1)
		tab.Button.BackgroundColor3 = if on then meta.Color:Lerp(P.Inset, 0.78) else P.Inset
		tab.Button.BackgroundTransparency = if on then 0 else 0.35
		tab.Stroke.Transparency = if on then 0 else 0.7
		tab.Stroke.Thickness = if on then 2 else 1
		tab.Name.TextColor3 = if on then Color3.new(1, 1, 1) else P.Dim
	end

	drawSheet(data)
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

local function request(name, id)
	if busy or not canChange() then
		return
	end
	busy = true
	UI.refresh()
	task.spawn(function()
		local result = GemClient.request(name, id)
		busy = false
		if result.Augments and GemClient.Profile then
			GemClient.Profile.Augments = result.Augments
		end
		UiKit.toast(result.Message, if result.Ok then P.Teal else UiKit.Colors.Bad)
		UI.refresh()
	end)
end

action.Activated:Connect(function()
	if action.Active and nextAction then
		request(nextAction, selected)
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
