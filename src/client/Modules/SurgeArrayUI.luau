--[[
	The Surge Array [L]: three gem sockets on Q, E and R, and the Rig
	Maneuvers on keys 1, 2 and 3.

	A socketed gem's element and surge tier decide its ability; its rank,
	Size (damage), Clarity (duration) and Cut (critical chance) set the
	numbers. Surge Amplifiers in the Augment Tree boost all three sockets.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Combat)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local AugmentTreeUI = require(script.Parent.AugmentTreeUI)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local SurgeIcons = require(script.Parent.SurgeIcons)

local P = IronUi.Colors
local BOLD, HEADING = IronUi.Bold, IronUi.Heading
local new, text, box, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.clear

local WIDTH, HEIGHT = 1060, 600
local KEYS = { "Q", "E", "R" }
local ROMAN = { "I", "II", "III" }
local AMPLIFIERS = {
	{ "SurgePower", "Surge Power", "damage" },
	{ "SurgeEfficiency", "Surge Efficiency", "cooldown" },
	{ "SurgeDuration", "Surge Duration", "duration" },
	{ "ElementalMastery", "Elemental Mastery", "all surges" },
	{ "ArcaneResonance", "Arcane Resonance", "double cast" },
}

local SurgeArrayUI = {}

local player = Players.LocalPlayer
local window = IronUi.window("SurgeArray", 10, WIDTH, HEIGHT, "◆", P.Teal)
local gui, panel = window.Gui, window.Panel
window.Title.Text = "SURGE ARRAY"
window.Subtitle.Text = "Gem Surges on Q · E · R   ·   Rig Maneuvers on 1 · 2 · 3"

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 80),
	Size = UDim2.fromOffset(WIDTH - 48, HEIGHT - 100),
}, panel)

local selectedKey, selectedSlot, busy = "Q", 1, false

local function label(parent, value, size, color, font)
	local t = text(parent, value, size, color, font or BOLD)
	t.AutomaticSize, t.TextWrapped, t.TextTruncate = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
	return t
end
local function place(object, x, y, w, h)
	object.Position, object.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return object
end
local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end
local function clickable(parent, onClick)
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}, parent)
	b.Activated:Connect(onClick)
	return b
end
local function canChange()
	if player:GetAttribute("CombatSession") or player:GetAttribute("Expedition") then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not Combat.canFight(root.Position)
end
local function request(action, ...)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		UiKit.toast(result.Message or "", if result.Ok then P.Gold else P.Bad)
		busy = false
		SurgeArrayUI.refresh()
	end)
end

-- "Ember Lance · T2 · II" and the gem's numbers for that surge.
local function surgeLine(gem, amps)
	local definition = Tech.surgeStats(gem, amps)
	if not definition then
		return nil
	end
	local cost = math.floor(definition.Cost * 10 + 0.5) / 10
	local parts = { string.format("%g Charge%s", cost, if definition.PerSecond then "/s" else "") }
	if definition.Damage then
		table.insert(parts, string.format("%d%% dmg", math.floor(definition.Damage * 100 + 0.5)))
	end
	table.insert(parts, string.format("%.1fs cooldown", definition.Cooldown or definition.Recovery))
	if definition.Crit > 0 then
		table.insert(parts, string.format("%d%% crit", math.floor(definition.Crit * 100 + 0.5)))
	end
	return definition, table.concat(parts, "  ·  ")
end

local function socketCard(parent, key, x, gem, amps)
	local active = key == selectedKey
	local card = box(parent, UDim2.fromOffset(x, 26), UDim2.fromOffset(196, 236), P.Inset, 12)
	if active then
		stroke(card, P.Gold, 2)
	end
	local definition, numbers = nil, nil
	if gem then
		definition, numbers = surgeLine(gem, amps)
	end
	local color = if gem then GemConfig.ElementColors[gem.Element] or P.Gold else P.Dim
	local socket = new("Frame", {
		BackgroundColor3 = P.Frame,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(92, 92),
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, socket)
	stroke(socket, color, 3, if gem then 0 else 0.4)
	local glyph = label(socket, if definition then "◆" else "+", 38, color)
	glyph.Size, glyph.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	SurgeIcons.apply(glyph, definition, color)
	local chip = new("Frame", {
		BackgroundColor3 = P.Gold,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(26, 26),
	}, card)
	UiKit.round(chip, 13)
	local keyText = label(chip, key, 14, P.Inset)
	keyText.Size, keyText.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	local name = place(
		label(card, if definition then definition.Name else "EMPTY SOCKET", 16, P.Text, HEADING),
		10,
		114,
		176,
		22
	)
	name.TextXAlignment = Enum.TextXAlignment.Center
	if definition then
		local tier = place(
			label(
				card,
				string.format(
					"%s SURGE  ·  RANK %s",
					string.upper(Tech.TierNames[definition.Tier] or ""),
					ROMAN[definition.Rank]
				),
				11,
				color
			),
			10,
			138,
			176,
			16
		)
		tier.TextXAlignment = Enum.TextXAlignment.Center
		local metrics = place(
			label(
				card,
				string.format(
					"%s  ·  S%d  ·  C%d  ·  Cut %d",
					GemConfig.TierLabels[gem.Tier] or gem.Tier,
					gem.Size or 0,
					gem.Clarity or 0,
					gem.Cut or 0
				),
				10,
				GemConfig.TierColors[gem.Tier] or P.Dim,
				IronUi.Body
			),
			10,
			158,
			176,
			16
		)
		metrics.TextXAlignment = Enum.TextXAlignment.Center
		local stats = place(label(card, numbers, 10, P.Dim, IronUi.Body), 10, 176, 176, 28)
		stats.TextWrapped, stats.TextXAlignment = true, Enum.TextXAlignment.Center
		local remove = new("TextButton", {
			Text = "REMOVE",
			TextSize = 11,
			Font = BOLD,
			TextColor3 = P.Text,
			BackgroundColor3 = P.Frame,
			Position = UDim2.fromOffset(58, 206),
			Size = UDim2.fromOffset(80, 22),
			ZIndex = 6,
		}, card)
		UiKit.round(remove, 6)
		remove.Activated:Connect(function()
			request("UnsocketSurge", key)
		end)
	else
		local hint = place(label(card, "Pick a gem below", 11, P.Dim, IronUi.Body), 10, 140, 176, 16)
		hint.TextXAlignment = Enum.TextXAlignment.Center
	end
	clickable(card, function()
		selectedKey = key
		SurgeArrayUI.refresh()
	end)
end

local function pouchList(parent, profile, amps)
	local heading = place(label(parent, "GEM POUCH  ·  SOCKET INTO " .. selectedKey, 13, P.Gold), 0, 272, 620, 18)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	local scroller = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 294),
		Size = UDim2.fromOffset(620, 206),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
	}, parent)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(302, 48),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroller)
	local gems = {}
	for _, gem in profile.Gems or {} do
		if gem.Cut ~= nil then
			table.insert(gems, gem)
		end
	end
	table.sort(gems, function(a, b)
		local _, tierA, rankA = Tech.surgeOf(a)
		local _, tierB, rankB = Tech.surgeOf(b)
		if tierA ~= tierB then
			return tierA > tierB
		end
		if rankA ~= rankB then
			return rankA > rankB
		end
		return (a.Id or "") < (b.Id or "")
	end)
	if #gems == 0 then
		local empty = place(
			label(scroller, "No gems yet. Mine rocks at the Outpost to find some.", 12, P.Dim, IronUi.Body),
			0,
			0,
			600,
			20
		)
		empty.TextXAlignment = Enum.TextXAlignment.Left
		return
	end
	for order, gem in gems do
		local definition = Tech.surgeStats(gem, amps)
		local color = GemConfig.ElementColors[gem.Element] or P.Gold
		local row = new("Frame", { BackgroundColor3 = P.Inset, LayoutOrder = order }, scroller)
		UiKit.round(row, 8)
		stroke(row, color, 1, 0.55)
		local dot = new("Frame", {
			BackgroundColor3 = color,
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(24, 24),
		}, row)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, dot)
		local icon = label(dot, "◆", 13, P.Inset)
		icon.Size, icon.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
		SurgeIcons.apply(icon, definition, P.Inset)
		place(
			label(
				row,
				if definition
					then string.format(
						"%s  ·  %s %s",
						definition.Name,
						Tech.TierNames[definition.Tier] or "",
						ROMAN[definition.Rank]
					)
					else "Unknown surge",
				13,
				P.Text
			),
			44,
			6,
			250,
			18
		)
		place(
			label(
				row,
				string.format(
					"%s %s  ·  S%d  C%d  Cut %d",
					GemConfig.TierLabels[gem.Tier] or gem.Tier,
					GemConfig.elementName(gem.Element),
					gem.Size or 0,
					gem.Clarity or 0,
					gem.Cut or 0
				),
				10,
				GemConfig.TierColors[gem.Tier] or P.Dim,
				IronUi.Body
			),
			44,
			26,
			250,
			16
		)
		clickable(row, function()
			request("SocketSurge", gem.Id, selectedKey)
		end)
	end
end

local function maneuverColumn(parent, profile, loadout)
	local x = 646
	local heading = place(label(parent, "RIG MANEUVERS  ·  STAMINA", 13, Tech.Resources.Stamina.Color), x, 0, 340, 18)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	local equipped = loadout.Maneuvers or Tech.DefaultManeuvers
	for slot = 1, Tech.ManeuverSlots do
		local id = equipped[slot]
		local definition = id and Tree.techStats(profile, id)
		local learned = id and Tree.isLearned(profile, id)
		local row = box(parent, UDim2.fromOffset(x, 26 + (slot - 1) * 54), UDim2.fromOffset(340, 48), P.Inset, 10)
		if slot == selectedSlot then
			stroke(row, P.Gold, 2)
		end
		local chip = new("Frame", {
			BackgroundColor3 = P.Gold,
			Position = UDim2.fromOffset(10, 11),
			Size = UDim2.fromOffset(26, 26),
		}, row)
		UiKit.round(chip, 6)
		local keyText = label(chip, tostring(slot), 14, P.Inset)
		keyText.Size, keyText.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
		local art = new("Frame", {
			BackgroundColor3 = P.Inset,
			Position = UDim2.fromOffset(44, 9),
			Size = UDim2.fromOffset(30, 30),
		}, row)
		UiKit.round(art, 6)
		art.Visible = SurgeIcons.apply(art, id)
		place(
			label(row, if definition then definition.Name else "Empty", 14, P.Text),
			if art.Visible then 82 else 46,
			6,
			280,
			18
		)
		place(
			label(
				row,
				if not definition
					then ""
					elseif learned then string.format(
						"Rank %s  ·  %d Stamina  ·  %.1fs cooldown",
						ROMAN[math.max(1, Tree.rank(profile, id))] or "I",
						math.floor(definition.Cost + 0.5),
						definition.Cooldown or definition.Recovery
					)
					else "Not learned yet: unlock it in the Augment Tree",
				10,
				if learned then P.Dim else P.Bad,
				IronUi.Body
			),
			if art.Visible then 82 else 46,
			26,
			280,
			16
		)
		clickable(row, function()
			selectedSlot = slot
			SurgeArrayUI.refresh()
		end)
	end
	local pick = place(label(parent, "LEARNED  ·  PUT ON KEY " .. selectedSlot, 11, P.Gold), x, 192, 340, 16)
	pick.TextXAlignment = Enum.TextXAlignment.Left
	local list = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 212),
		Size = UDim2.fromOffset(340, 116),
	}, parent)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(166, 26),
		CellPadding = UDim2.fromOffset(8, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	for order, id in Tree.available(profile, "RigManeuvers") do
		local definition = Tech.Catalog[id]
		local on = equipped[selectedSlot] == id
		local b = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if on then P.Gold else P.Frame,
			LayoutOrder = order,
		}, list)
		UiKit.round(b, 6)
		-- The icon and the name sit side by side (no padding tricks).
		local art = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.fromOffset(20, 20),
		}, b)
		UiKit.round(art, 4)
		local hasArt = SurgeIcons.apply(art, id)
		if not hasArt then
			art:Destroy()
		end
		local name = label(b, definition.Name, 11, if on then P.Inset else P.Text)
		name.Position = UDim2.fromOffset(if hasArt then 28 else 8, 0)
		name.Size = UDim2.new(1, if hasArt then -32 else -12, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		b.Activated:Connect(function()
			if not on then
				request("EquipManeuver", selectedSlot, id)
			end
		end)
	end
end

local function amplifierBox(parent, amps)
	local x = 646
	local card = box(parent, UDim2.fromOffset(x, 336), UDim2.fromOffset(340, 164), P.Inset, 12)
	stroke(card, Color3.fromRGB(84, 160, 255), 1, 0.4)
	place(label(card, "◆  SURGE AMPLIFIERS", 13, Color3.fromRGB(120, 180, 255)), 14, 10, 312, 18)
	for i, entry in AMPLIFIERS do
		local amount = amps[entry[1]] or 0
		local line = place(
			label(
				card,
				string.format(
					"%s  %s",
					entry[2],
					if amount > 0
						then string.format(
							"%s%d%% %s",
							if entry[1] == "SurgeEfficiency" then "-" else "+",
							math.floor(amount * 100 + 0.5),
							entry[3]
						)
						else "·  not learned"
				),
				11,
				if amount > 0 then P.Text else P.Dim,
				IronUi.Body
			),
			14,
			32 + (i - 1) * 17,
			312,
			16
		)
		line.TextXAlignment = Enum.TextXAlignment.Left
	end
	local open = new("TextButton", {
		Text = "OPEN AUGMENT TREE  ›",
		TextSize = 12,
		Font = BOLD,
		TextColor3 = P.Inset,
		BackgroundColor3 = P.Gold,
		Position = UDim2.fromOffset(14, 124),
		Size = UDim2.fromOffset(312, 28),
	}, card)
	UiKit.round(open, 8)
	open.Activated:Connect(function()
		SurgeArrayUI.close()
		AugmentTreeUI.open()
		AugmentTreeUI.selectBranch("SurgeAmplifiers")
	end)
end

function SurgeArrayUI.refresh()
	if not gui.Enabled then
		return
	end
	clear(body)
	local profile = GemClient.Profile or {}
	local loadout = profile.Character or {}
	local amps = Tree.effects(profile)
	local heading = place(label(body, "GEM SURGES  ·  CHARGE", 13, Tech.Resources.Charge.Color), 0, 0, 620, 18)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	for i, key in KEYS do
		socketCard(body, key, (i - 1) * 212, Tech.surgeGem(loadout, key), amps)
	end
	pouchList(body, profile, amps)
	maneuverColumn(body, profile, loadout)
	amplifierBox(body, amps)
	if not canChange() then
		local lock = place(
			label(body, "Return to the dashboard or town to change your loadout.", 11, P.Bad, IronUi.Body),
			0,
			HEIGHT - 116,
			620,
			14
		)
		lock.TextXAlignment = Enum.TextXAlignment.Left
	end
end

function SurgeArrayUI.isOpen()
	return gui.Enabled
end

function SurgeArrayUI.open()
	gui.Enabled = true
	window.Fit()
	SurgeArrayUI.refresh()
end

function SurgeArrayUI.close()
	gui.Enabled = false
	clear(body)
end

function SurgeArrayUI.toggle()
	if gui.Enabled then
		SurgeArrayUI.close()
	else
		SurgeArrayUI.open()
	end
end

window.Close.Activated:Connect(SurgeArrayUI.close)
window.Shade.Activated:Connect(SurgeArrayUI.close)
GemClient.Changed:Connect(function()
	if gui.Enabled and not busy then
		SurgeArrayUI.refresh()
	end
end)

return SurgeArrayUI
