--[[
	The skill tree window (Shared.SkillTree): SKILLS in the lobby.

	  header    SKILL TREE and your element; your skill points (big, gold
	            while there are some), your level, RESET (twice to confirm)
	            and close
	  tabs      the four elements' trees, each a pill with its gem; yours
	            marked YOURS; the window takes the open tree's colour
	  tree      three branches side by side, each headed by its key (Q on
	            the sword, E on the chest, R on the shield) and the gem in
	            that socket; four tiers down each (I, II, III and the
	            capstone, the level each opens at down the left), every
	            move a painted icon (Client SurgeIcons) joined to the tier
	            above by a line that lights once it's reachable
	  move      on the right, the move picked: its icon, key, tier and kind,
	            what it does, its numbers with your gem (and +10% affinity
	            with one of its element), and EQUIP ON Q / LEARN / why not

	Every tree's first three moves are learned from the start. A save from
	before the tree chooses its element first (Modules.ElementPick).

	  SkillTreeUI.open() / close() / toggle()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local SkillTree = require(ReplicatedStorage.Shared.SkillTree)
local AugmentTree = require(ReplicatedStorage.Shared.AugmentTree)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)
local Icons = (function()
	local ok, module = pcall(function()
		return require(script.Parent.SurgeIcons)
	end)
	return if ok then module else nil
end)()

local SkillTreeUI = {}

local INK = Color3.fromRGB(7, 9, 15)
local PANEL = Color3.fromRGB(13, 16, 25)
local CARD = Color3.fromRGB(21, 26, 39)
local CARD_HI = Color3.fromRGB(29, 35, 52)
local LINE = Color3.fromRGB(48, 56, 76)
local TEXT = Color3.fromRGB(240, 244, 250)
local DIM = Color3.fromRGB(150, 162, 184)
local FAINT = Color3.fromRGB(92, 102, 122)
local GOLD = Color3.fromRGB(255, 202, 91)
local BAD = Color3.fromRGB(255, 128, 112)
local KEYS = { "Q", "E", "R" }
local KEY_COLORS = { Q = Color3.fromRGB(255, 138, 92), E = Color3.fromRGB(122, 196, 255), R = Color3.fromRGB(120, 230, 170) }
local LANE = { Q = "OFFENSE", E = "ABILITY", R = "DEFENSE" }
local SOCKET = { Q = "Sword", E = "Chest", R = "Shield" }
local NUMERALS = { "I", "II", "III", "IV" }
local RARITY_COLORS = {
	Common = Color3.fromRGB(190, 196, 208),
	Uncommon = Color3.fromRGB(110, 220, 120),
	Rare = Color3.fromRGB(90, 160, 255),
	UltraRare = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 190, 70),
}

-- Layout (the window's own pixels; a UIScale fits it to the screen).
local W, H = 1100, 660
local TREE_X, TREE_W = 72, 690 -- the branches' area (the tier gutter left of it)
local SIDE_X, SIDE_W = 792, 284 -- the move panel
local COL_GAP = 16
local COL_W = (TREE_W - 2 * COL_GAP) / 3
local HEAD_Y, HEAD_H = 140, 64 -- the branch headers
local ROW_Y, ROW_H = 220, 104 -- the tiers
local NODE = 56

local gui: ScreenGui? = nil
local state = { Tab = nil :: string?, Picked = nil :: string?, ResetArmed = false }
local override = nil -- (the server's word from the last request, till the profile catches up)
local refresh: () -> () = function() end

local function new(class: string, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	i.Parent = parent
	return i
end
local function text(parent, value: string, size: number, color: Color3, font: Enum.Font, props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font,
		TextWrapped = true,
	}, parent)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end
local function stroke(parent, color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
	}, parent)
end
local function gradient(parent, top: Color3, bottom: Color3, rotation: number?)
	return new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(top, bottom) }, parent)
end
local function label(element: string): string
	return string.upper(GemConfig.ElementLabels[element] or element)
end
local function colorOf(element: string?): Color3
	return element and GemConfig.ElementColors[element] or GOLD
end

local function profile()
	return GemClient.Profile
end
local function skills()
	if override then
		return SkillTree.clean(override)
	end
	local p = profile()
	return p and p.Character and SkillTree.clean(p.Character.Skills)
end
local function level(): number
	local p = profile()
	return AugmentTree.level(p and p.Augments and p.Augments.XP or 0)
end

local function ask(action: string, ...)
	local result = GemClient.request(action, ...)
	if result and result.Ok then
		if type(result.Skills) == "table" then
			override = result.Skills
		end
	else
		UiKit.toast(result and result.Message or "Couldn't do that.", BAD)
	end
	task.defer(refresh)
	return result
end

-- A move's icon in `holder` (the painted one, else its first letter).
local function icon(holder: GuiObject, id: string, inset: number?)
	local move = GemTraits.Moves[id]
	local pad = inset or 4
	local glyph = text(holder, move and string.sub(move.Name, 1, 1) or "?", 22, TEXT, Enum.Font.GothamBlack, {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
		ZIndex = holder.ZIndex + 1,
	})
	UiKit.round(glyph, 10)
	if Icons then
		pcall(Icons.apply, glyph, id)
	end
	return glyph
end

local function build()
	local screen = UiKit.gui("SkillTree", 30)
	local shade = new("TextButton", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = "",
	}, screen)
	local window = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = PANEL,
		ClipsDescendants = true,
	}, shade)
	UiKit.round(window, 18)
	local rim = stroke(window, GOLD, 2, 0.35)
	local fit = new("UIScale", {}, window)
	local function scaleIt()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		fit.Scale = math.min(1, (view.X - 16) / W, (view.Y - 16) / H)
	end
	scaleIt()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(scaleIt)
	end
	-- The open tree's colour: a glow down from the top, behind it all.
	local glow = new("Frame", {
		Name = "Glow",
		Size = UDim2.new(1, 0, 0, 300),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, window)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) }),
	}, glow)

	-- Header.
	text(window, "SKILL TREE", 30, TEXT, Enum.Font.GothamBlack, {
		Position = UDim2.fromOffset(28, 18),
		Size = UDim2.fromOffset(300, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local yours = text(window, "", 13, DIM, Enum.Font.GothamBold, {
		Name = "Yours",
		Position = UDim2.fromOffset(28, 54),
		Size = UDim2.fromOffset(420, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	})
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = CARD,
		Text = "X",
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = TEXT,
	}, window)
	UiKit.round(close, 12)
	stroke(close, LINE, 1)
	close.Activated:Connect(function()
		SkillTreeUI.close()
	end)
	local reset = new("TextButton", {
		Name = "Reset",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -74, 0, 20),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = CARD,
		Text = "RESET",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = DIM,
	}, window)
	UiKit.round(reset, 12)
	local resetEdge = stroke(reset, LINE, 1)
	reset.Activated:Connect(function()
		if state.ResetArmed then
			state.ResetArmed = false
			ask("SkillReset")
		else
			state.ResetArmed = true
			refresh()
			task.delay(4, function()
				state.ResetArmed = false
				refresh()
			end)
		end
	end)
	-- the points and the level
	local pointsPill = new("Frame", {
		Name = "Points",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -196, 0, 20),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = CARD,
	}, window)
	UiKit.round(pointsPill, 12)
	local pointsEdge = stroke(pointsPill, GOLD, 1.5)
	local pointsNumber = text(pointsPill, "0", 26, GOLD, Enum.Font.GothamBlack, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(40, 44),
	})
	local pointsWord = text(pointsPill, "SKILL POINTS", 12, TEXT, Enum.Font.GothamBlack, {
		Position = UDim2.fromOffset(54, 7),
		Size = UDim2.fromOffset(110, 15),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local levelWord = text(pointsPill, "LEVEL 1", 11, DIM, Enum.Font.GothamBold, {
		Position = UDim2.fromOffset(54, 23),
		Size = UDim2.fromOffset(110, 14),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- The element tabs.
	local tabs = {}
	for i, element in SkillTree.Elements do
		local color = colorOf(element)
		local tab = new("TextButton", {
			Name = element,
			Position = UDim2.fromOffset(28 + (i - 1) * 172, 86),
			Size = UDim2.fromOffset(162, 40),
			BackgroundColor3 = CARD,
			AutoButtonColor = false,
			Text = "",
		}, window)
		UiKit.round(tab, 20)
		local fill = gradient(tab, color, color:Lerp(INK, 0.45))
		local edge = stroke(tab, LINE, 1)
		local gem = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(24, 20),
			Size = UDim2.fromOffset(13, 13),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, tab)
		UiKit.round(gem, 3)
		local word = text(tab, label(element), 14, color, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -48, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local mark = text(tab, "YOURS", 9, INK, Enum.Font.GothamBlack, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(42, 16),
			BackgroundTransparency = 0,
			BackgroundColor3 = GOLD,
			Visible = false,
		})
		UiKit.round(mark, 8)
		tab.Activated:Connect(function()
			state.Tab, state.Picked = element, nil
			refresh()
		end)
		tabs[element] = { Button = tab, Fill = fill, Edge = edge, Gem = gem, Word = word, Mark = mark, Color = color }
	end

	-- The tree: tier badges down the left, branch headers, the nodes.
	local tree = new("Frame", {
		Name = "Tree",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, window)
	for tier = 1, 4 do
		local y = ROW_Y + (tier - 1) * ROW_H
		local badge = new("Frame", {
			Name = "Tier" .. tier,
			Position = UDim2.fromOffset(24, y + 8),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = if tier == 4 then GOLD:Lerp(INK, 0.55) else CARD,
			Rotation = 45,
		}, tree)
		UiKit.round(badge, 8)
		stroke(badge, if tier == 4 then GOLD else LINE, 1)
		text(tree, NUMERALS[tier], 14, if tier == 4 then GOLD else TEXT, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(24, y + 8),
			Size = UDim2.fromOffset(36, 36),
		})
		text(tree, "LV " .. SkillTree.Levels[tier], 10, FAINT, Enum.Font.GothamBold, {
			Name = "Opens" .. tier,
			Position = UDim2.fromOffset(16, y + 52),
			Size = UDim2.fromOffset(52, 14),
		})
	end
	local columns = {}
	for c, key in KEYS do
		local x = TREE_X + (c - 1) * (COL_W + COL_GAP)
		local head = new("Frame", {
			Name = key .. "Head",
			Position = UDim2.fromOffset(x, HEAD_Y),
			Size = UDim2.fromOffset(COL_W, HEAD_H),
			BackgroundColor3 = CARD,
		}, tree)
		UiKit.round(head, 14)
		stroke(head, LINE, 1)
		local cap = new("TextLabel", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = KEY_COLORS[key],
			Font = Enum.Font.GothamBlack,
			TextSize = 24,
			TextColor3 = INK,
			Text = key,
		}, head)
		UiKit.round(cap, 10)
		gradient(cap, KEY_COLORS[key]:Lerp(Color3.new(1, 1, 1), 0.25), KEY_COLORS[key]:Lerp(INK, 0.15))
		text(head, LANE[key], 14, TEXT, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(64, 11),
			Size = UDim2.fromOffset(COL_W - 72, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local gemLine = text(head, "", 11, DIM, Enum.Font.GothamBold, {
			Name = "Gem",
			Position = UDim2.fromOffset(78, 32),
			Size = UDim2.fromOffset(COL_W - 86, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
		})
		local gemDot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(69, 43),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BorderSizePixel = 0,
		}, head)
		columns[key] = { X = x, Head = head, GemLine = gemLine, GemDot = gemDot }
	end

	-- The move panel.
	local side = new("Frame", {
		Name = "Move",
		Position = UDim2.fromOffset(SIDE_X, 140),
		Size = UDim2.fromOffset(SIDE_W, H - 140 - 22),
		BackgroundColor3 = CARD,
		ZIndex = 2,
	}, window)
	UiKit.round(side, 16)
	local sideEdge = stroke(side, LINE, 1)
	local sideTop = new("Frame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, side)
	UiKit.round(sideTop, 16)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
	}, sideTop)
	local bigIcon = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.fromOffset(92, 92),
		BackgroundColor3 = INK,
		ZIndex = 3,
	}, side)
	UiKit.round(bigIcon, 20)
	local bigEdge = stroke(bigIcon, GOLD, 2)
	local name = text(side, "", 20, TEXT, Enum.Font.GothamBlack, {
		Name = "Name",
		Position = UDim2.fromOffset(16, 124),
		Size = UDim2.new(1, -32, 0, 26),
		ZIndex = 3,
	})
	local chips = new("Frame", {
		Name = "Chips",
		Position = UDim2.fromOffset(16, 156),
		Size = UDim2.new(1, -32, 0, 22),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, side)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, chips)
	local what = text(side, "", 13, DIM, Enum.Font.GothamMedium, {
		Name = "What",
		Position = UDim2.fromOffset(18, 190),
		Size = UDim2.new(1, -36, 0, 64),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
	})
	new("Frame", {
		Position = UDim2.fromOffset(18, 262),
		Size = UDim2.new(1, -36, 0, 1),
		BackgroundColor3 = LINE,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, side)
	local poweredBy = text(side, "", 11, FAINT, Enum.Font.GothamBlack, {
		Name = "Powered",
		Position = UDim2.fromOffset(18, 272),
		Size = UDim2.new(1, -36, 0, 28),
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		ZIndex = 3,
	})
	local stats = new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(18, 306),
		Size = UDim2.new(1, -36, 0, 110),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, side)
	new("UIListLayout", { Padding = UDim.new(0, 6) }, stats)
	local action = new("TextButton", {
		Name = "Action",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(1, -32, 0, 54),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = INK,
		Text = "",
		ZIndex = 3,
	}, side)
	UiKit.round(action, 14)
	local actionFill = gradient(action, GOLD:Lerp(Color3.new(1, 1, 1), 0.2), GOLD:Lerp(Color3.fromRGB(200, 120, 20), 0.35))
	local hint = text(side, "", 11, FAINT, Enum.Font.GothamBold, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -32, 0, 22),
		ZIndex = 3,
	})
	local actionKind, actionId = nil :: string?, nil :: string?
	action.Activated:Connect(function()
		if actionKind == "Learn" and actionId then
			ask("SkillLearn", actionId)
		elseif actionKind == "Equip" and actionId then
			local _, lane = SkillTree.where(actionId)
			ask("SkillEquip", SkillTree.KeyOfLane[lane or ""], actionId)
		end
	end)

	local drawn = {}
	local chipOrder = 0
	local function chip(parent, value: string, color: Color3)
		chipOrder += 1
		local c = text(parent, value, 10, color, Enum.Font.GothamBlack, {
			LayoutOrder = chipOrder,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = color:Lerp(INK, 0.82),
			TextWrapped = false,
			ZIndex = 3,
		})
		new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, c)
		UiKit.round(c, 11)
		stroke(c, color, 1, 0.5)
		table.insert(drawn, c)
		return c
	end
	local function bar(x: number, y: number, w: number, h: number, lit: boolean, color: Color3)
		local b = new("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = if lit then color else LINE,
			BackgroundTransparency = if lit then 0.15 else 0.2,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, tree)
		table.insert(drawn, b)
		return b
	end

	refresh = function()
		for _, d in drawn do
			d:Destroy()
		end
		table.clear(drawn)
		chipOrder = 0
		local mine = skills()
		local lv = level()
		local element = state.Tab or (mine and mine.Element) or SkillTree.Elements[1]
		local color = colorOf(element)
		local loadout = profile() and profile().Character or {}
		local left = if mine then SkillTree.left(mine, lv) else 0
		glow.BackgroundColor3 = color
		rim.Color = color:Lerp(GOLD, 0.5)
		yours.Text = if mine
			then string.format('YOUR ELEMENT  <font color="#%s">%s</font>', colorOf(mine.Element):ToHex(), label(mine.Element))
			else ""
		pointsNumber.Text = tostring(left)
		pointsNumber.TextColor3 = if left > 0 then GOLD else DIM
		pointsEdge.Color = if left > 0 then GOLD else LINE
		pointsWord.Text = if left == 1 then "SKILL POINT" else "SKILL POINTS"
		levelWord.Text = string.format("LEVEL %d", lv)
		reset.Text = if state.ResetArmed then "SURE?" else "RESET"
		reset.TextColor3 = if state.ResetArmed then BAD else DIM
		resetEdge.Color = if state.ResetArmed then BAD else LINE
		for el, tab in tabs do
			local on = el == element
			tab.Fill.Enabled = on
			tab.Button.BackgroundColor3 = if on then tab.Color else CARD
			tab.Edge.Color = if on then tab.Color:Lerp(Color3.new(1, 1, 1), 0.4) else LINE
			tab.Edge.Thickness = if on then 2 else 1
			tab.Word.TextColor3 = if on then Color3.new(1, 1, 1) else tab.Color
			tab.Gem.BackgroundColor3 = if on then Color3.new(1, 1, 1) else tab.Color
			tab.Mark.Visible = mine ~= nil and mine.Element == el
		end
		for tier = 1, 4 do
			local opens = tree:FindFirstChild("Opens" .. tier)
			if opens then
				opens.TextColor3 = if lv >= SkillTree.Levels[tier] then DIM else FAINT
				opens.Text = if lv >= SkillTree.Levels[tier] then "OPEN" else "LV " .. SkillTree.Levels[tier]
			end
		end
		-- the default pick: what's on Q in this tree, else its first move
		if not state.Picked or not SkillTree.Place[state.Picked] or SkillTree.Place[state.Picked].Element ~= element then
			local onQ = mine and mine.Moves.Q
			state.Picked = if onQ and SkillTree.Place[onQ] and SkillTree.Place[onQ].Element == element
				then onQ
				else SkillTree.Trees[element].Offense[1][1]
		end

		for _, key in KEYS do
			local col = columns[key]
			local lane = SkillTree.Lanes[key]
			local tiers = SkillTree.Trees[element][lane]
			-- the socket's gem
			local gem = GemTraits.socketGem(loadout, key)
			if gem then
				local gc = RARITY_COLORS[gem.Tier or "Common"] or TEXT
				col.GemLine.Text = string.format('<font color="#%s">%s</font>  %s GEM', gc:ToHex(), string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier or "Common"), label(gem.Element or ""))
				col.GemDot.BackgroundColor3 = colorOf(gem.Element)
				col.GemDot.Visible = true
			else
				col.GemLine.Text = string.format('<font color="#%s">NO GEM</font>  in your %s', BAD:ToHex(), string.lower(SOCKET[key]))
				col.GemDot.Visible = false
			end
			-- tier by tier: the line down from the tier above, the nodes
				for tier, ids in tiers do
				local y = ROW_Y + (tier - 1) * ROW_H
				local reachable = tier == 1
				if mine and tier > 1 then
					for _, above in tiers[tier - 1] do
						reachable = reachable or mine.Learned[above] == true
					end
				end
				local slot = COL_W / #ids
				if tier > 1 then
					-- (under the names of the tier above: a stem, a rail across, a drop into each)
					local above = #tiers[tier - 1]
					local aboveSlot = COL_W / above
					local rail = y - 9
					local xs = {}
					for i = 1, above do
						table.insert(xs, col.X + aboveSlot * (i - 0.5))
					end
					for i = 1, #ids do
						table.insert(xs, col.X + slot * (i - 0.5))
					end
					local lo, hi = math.min(table.unpack(xs)), math.max(table.unpack(xs))
					for i = 1, above do
						bar(col.X + aboveSlot * (i - 0.5) - 1.5, y - 14, 3, 5, reachable, color)
					end
					bar(lo - 1.5, rail, hi - lo + 3, 3, reachable, color)
					for i = 1, #ids do
						bar(col.X + slot * (i - 0.5) - 1.5, rail, 3, 9, reachable, color)
					end
				end
				for i, id in ids do
					local move = GemTraits.Moves[id]
					local learned = mine ~= nil and mine.Learned[id] == true
					local on = mine ~= nil and mine.Moves[key] == id
					local can = mine ~= nil and (SkillTree.canLearn(mine, id, lv))
					local picked = state.Picked == id
					local holder = new("TextButton", {
						Name = id,
						Position = UDim2.fromOffset(col.X + slot * (i - 1), y),
						Size = UDim2.fromOffset(slot, ROW_H - 6),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 3,
					}, tree)
					table.insert(drawn, holder)
					-- (ready to learn: a soft halo)
					if can and not learned then
						local halo = new("Frame", {
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, -4),
							Size = UDim2.fromOffset(NODE + 8, NODE + 8),
							BackgroundColor3 = color,
							BackgroundTransparency = 0.7,
							ZIndex = 3,
						}, holder)
						UiKit.round(halo, 18)
					end
					local tile = new("Frame", {
						Name = "Tile",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 0),
						Size = UDim2.fromOffset(NODE, NODE),
						BackgroundColor3 = if learned then color:Lerp(INK, 0.6) else INK,
						ZIndex = 4,
					}, holder)
					UiKit.round(tile, 14)
					stroke(
						tile,
						if picked then Color3.new(1, 1, 1) elseif on then GOLD elseif learned then color elseif can then color:Lerp(LINE, 0.3) else LINE,
						if picked or on then 3 else if learned then 2 else 1
					)
					local glyph = icon(tile, id)
					glyph.ZIndex = 5
					local art = glyph:FindFirstChild("AbilityArt")
					if art then
						art.ZIndex = 5
					end
					if Icons and not learned and not can then
						pcall(Icons.dim, glyph, true)
						glyph.TextColor3 = FAINT
					end
					if not learned and not can then
						local veil = new("Frame", {
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = INK,
							BackgroundTransparency = 0.45,
							ZIndex = 6,
						}, tile)
						UiKit.round(veil, 14)
					end
					-- (on a key: its letter in the corner)
					if on then
						local badge = text(tile, key, 12, INK, Enum.Font.GothamBlack, {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(1, -2, 0, 2),
							Size = UDim2.fromOffset(22, 22),
							BackgroundTransparency = 0,
							BackgroundColor3 = GOLD,
							ZIndex = 7,
						})
						UiKit.round(badge, 11)
						stroke(badge, INK, 2)
					end
					text(holder, move and move.Name or id, if #ids >= 3 then 10 else 11, if learned or can then TEXT else FAINT, Enum.Font.GothamBold, {
						Position = UDim2.new(0, 2, 0, NODE + 7),
						Size = UDim2.new(1, -4, 0, 26),
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 4,
					})
					-- what it is now, under its name
					local status, statusColor
					if on then
						status, statusColor = "EQUIPPED", GOLD
					elseif learned then
						status, statusColor = "LEARNED", color:Lerp(Color3.new(1, 1, 1), 0.3)
					elseif lv < SkillTree.Levels[tier] then
						status, statusColor = "LV " .. SkillTree.Levels[tier], FAINT
					elseif can then
						local cost = SkillTree.cost(mine, id)
						status, statusColor = string.format("%d PT%s", cost, if cost == 1 then "" else "S"), TEXT
					else
						status, statusColor = "LOCKED", FAINT
					end
					local tag = text(holder, status, 9, statusColor, Enum.Font.GothamBlack, {
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 0, NODE + 2),
						Size = UDim2.fromOffset(0, 14),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 0,
						BackgroundColor3 = INK,
						TextWrapped = false,
						ZIndex = 8,
					})
					new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, tag)
					UiKit.round(tag, 7)
					holder.Activated:Connect(function()
						state.Picked = id
						refresh()
					end)
				end
			end
		end

		-- The move panel.
		local id = state.Picked :: string
		local move = GemTraits.Moves[id]
		local _, lane, tier = SkillTree.where(id)
		local key = SkillTree.KeyOfLane[lane or ""] or "Q"
		for _, child in bigIcon:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		icon(bigIcon, id, 6).TextSize = 40
		bigEdge.Color = if mine and mine.Moves[key] == id then GOLD else color
		sideTop.BackgroundColor3 = color
		sideEdge.Color = color:Lerp(LINE, 0.5)
		name.Text = move and move.Name or id
		chip(chips, key .. "  ·  " .. string.upper(SOCKET[key]), KEY_COLORS[key])
		chip(chips, if tier == 4 then "CAPSTONE" else "TIER " .. NUMERALS[tier or 1], if tier == 4 then GOLD else TEXT)
		chip(chips, string.upper(GemTraits.typeOf(id)), color)
		what.Text = move and move.Description or ""
		local gem = GemTraits.socketGem(loadout, key)
		local numbers = gem and GemTraits.stats(id, GemTraits.project(gem, key, id))
		if gem then
			local gc = RARITY_COLORS[gem.Tier or "Common"] or TEXT
			poweredBy.Text = string.format('POWERED BY YOUR <font color="#%s">%s %s</font> GEM%s', gc:ToHex(), string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier or "Common"), label(gem.Element or ""), if numbers and numbers.Affinity then '\n<font color="#FFCA5B">+10% AFFINITY: SAME ELEMENT</font>' else "")
		else
			poweredBy.Text = string.format('<font color="#%s">NO GEM IN YOUR %s: IT WON\'T FIRE</font>', BAD:ToHex(), string.upper(SOCKET[key]))
		end
		for _, child in stats:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local base = numbers or GemTraits.stats(id, { Tier = "Common" })
		if base then
			local rows = {}
			if base.Damage then
				local hits = base.Hits or (base.Storm and base.Storm.Strikes) or (base.Hail and math.floor(base.Hail.Time / base.Hail.Every + 0.5)) or (base.Disc and 2) or 1
				table.insert(rows, { "DAMAGE", string.format("%d%%%s", math.floor(base.Damage * 100 + 0.5), if hits > 1 then "  ×" .. hits else "") })
			end
			if base.Absorb then
				table.insert(rows, { "ABSORB", tostring(math.floor(base.Absorb + 0.5)) })
			end
			if base.Heal and base.Heal.Share then
				table.insert(rows, { "HEAL", string.format("%d%%", math.floor(base.Heal.Share * 100 + 0.5)) })
			end
			table.insert(rows, { "COST", string.format("%d %s", math.floor((base.Cost or 0) + 0.5), string.upper(base.Resource or "")) })
			table.insert(rows, { "COOLDOWN", string.format("%gs", math.floor((base.Cooldown or 0) * 10 + 0.5) / 10) })
			for i, pair in rows do
				local row = new("Frame", {
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundColor3 = INK,
					BackgroundTransparency = 0.15,
					ZIndex = 3,
				}, stats)
				UiKit.round(row, 8)
				text(row, pair[1], 10, FAINT, Enum.Font.GothamBlack, {
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(0.5, -10, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 4,
				})
				text(row, pair[2], 13, TEXT, Enum.Font.GothamBlack, {
					Position = UDim2.new(0.5, 0, 0, 0),
					Size = UDim2.new(0.5, -10, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 4,
				})
			end
		end
		actionKind, actionId = nil, id
		action.Visible = mine ~= nil
		local function look(enabled: boolean, value: string)
			action.Text = value
			action.Active, action.AutoButtonColor = enabled, enabled
			actionFill.Enabled = enabled
			action.BackgroundColor3 = if enabled then GOLD else CARD_HI
			action.TextColor3 = if enabled then INK else DIM
		end
		hint.Text = ""
		if mine and mine.Moves[key] == id then
			look(false, "EQUIPPED ON " .. key)
			hint.Text = "Pick another learned move to swap it."
		elseif mine and mine.Learned[id] then
			actionKind = "Equip"
			look(true, "EQUIP ON " .. key)
			hint.Text = "Swap any time out of a fight."
		elseif mine then
			local ok, why = SkillTree.canLearn(mine, id, lv)
			if ok then
				actionKind = "Learn"
				local cost = SkillTree.cost(mine, id)
				look(true, string.format("LEARN  ·  %d POINT%s", cost, if cost == 1 then "" else "S"))
				hint.Text = "It goes on " .. key .. " once learned."
			else
				look(false, "LOCKED")
				hint.Text = why or ""
			end
		end
	end
	GemClient.Changed:Connect(function()
		override = nil
		if screen.Enabled then
			refresh()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and screen.Enabled then
			SkillTreeUI.close()
		end
	end)
	screen.Enabled = false
	return screen
end

local choosing = false
function SkillTreeUI.open()
	local p = profile()
	if p and p.Character and not p.Character.Skills and not override then
		-- (a save from before the tree: its element first)
		if choosing then
			return
		end
		choosing = true
		local ok, element = pcall(function()
			return require(script.Parent.ElementPick).run()
		end)
		choosing = false
		if not ok or not element then
			return
		end
		local result = ask("SkillChoose", element)
		if not (result and result.Ok) then
			return
		end
	end
	gui = gui or build()
	-- (open on your own tree)
	state.Tab, state.Picked, state.ResetArmed = nil, nil, false
	refresh()
	local window = (gui :: ScreenGui).Shade.Window
	;(gui :: ScreenGui).Enabled = true
	local pop = window:FindFirstChildOfClass("UIScale")
	if pop then
		local target = pop.Scale
		pop.Scale = target * 0.94
		TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
	end
end
function SkillTreeUI.close()
	if gui then
		gui.Enabled = false
	end
end
function SkillTreeUI.toggle()
	if gui and gui.Enabled then
		SkillTreeUI.close()
	else
		SkillTreeUI.open()
	end
end
SkillTreeUI._refresh = function()
	refresh()
end

return SkillTreeUI
