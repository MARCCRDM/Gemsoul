--[[
	The skill tree window (Shared.SkillTree): SKILLS in the lobby.

	  header    SKILL TREE, your level and the points you have left, RESET
	            (twice to confirm: back to your element's tier 1, points back)
	  tabs      the four elements' trees, your own first and marked
	  body      three branches side by side (Q Offense on the sword, E
	            Ability on the chest, R Defense on the shield), four tiers
	            down each; a move is ON (on its key, gold), learned, ready to
	            learn (its cost) or locked (the level its tier opens at)
	  detail    the move picked: what it does, its numbers with the gem in
	            that key's socket (+affinity with a gem of its element), and
	            LEARN or EQUIP ON Q / E / R

	A save from before the tree chooses its element first (Modules.
	ElementPick), then the window opens on it.

	  SkillTreeUI.open() / close() / toggle()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local SkillTree = require(ReplicatedStorage.Shared.SkillTree)
local AugmentTree = require(ReplicatedStorage.Shared.AugmentTree)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)

local SkillTreeUI = {}

local INK = Color3.fromRGB(8, 10, 16)
local PANEL = Color3.fromRGB(14, 18, 28)
local CARD = Color3.fromRGB(22, 27, 40)
local LINE = Color3.fromRGB(52, 60, 78)
local TEXT = Color3.fromRGB(238, 242, 248)
local DIM = Color3.fromRGB(150, 162, 182)
local FAINT = Color3.fromRGB(96, 106, 124)
local GOLD = Color3.fromRGB(255, 202, 91)
local KEYS = { "Q", "E", "R" }
local BRANCH = { Q = "OFFENSE · SWORD", E = "ABILITY · CHEST", R = "DEFENSE · SHIELD" }
local W, H = 940, 600

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local state = { Tab = nil :: string?, Picked = nil :: string?, ResetArmed = false }
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
local function label(element: string): string
	return string.upper(GemConfig.ElementLabels[element] or element)
end

local function profile()
	return GemClient.Profile
end
local function skills()
	local p = profile()
	return p and p.Character and SkillTree.clean(p.Character.Skills)
end
local function level(): number
	local p = profile()
	return AugmentTree.level(p and p.Augments and p.Augments.XP or 0)
end

local function ask(action: string, ...)
	local result = GemClient.request(action, ...)
	if not (result and result.Ok) then
		UiKit.toast(result and result.Message or "Couldn't do that.", Color3.fromRGB(255, 120, 110))
	end
	task.defer(refresh)
	return result
end

local function build()
	local screen = UiKit.gui("SkillTree", 30)
	local shade = new("TextButton", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
	}, screen)
	local window = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = PANEL,
	}, shade)
	UiKit.round(window, 16)
	new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.2 }, window)
	local fit = new("UIScale", {}, window)
	local function scaleIt()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		fit.Scale = math.min(1, (view.X - 20) / W, (view.Y - 20) / H)
	end
	scaleIt()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(scaleIt)
	end

	text(window, "SKILL TREE", 28, GOLD, Enum.Font.GothamBlack, {
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(300, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local points = text(window, "", 15, TEXT, Enum.Font.GothamBold, {
		Name = "Points",
		Position = UDim2.fromOffset(24, 50),
		Size = UDim2.fromOffset(520, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = CARD,
		Text = "X",
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = TEXT,
	}, window)
	UiKit.round(close, 10)
	close.Activated:Connect(function()
		SkillTreeUI.close()
	end)
	local reset = new("TextButton", {
		Name = "Reset",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 14),
		Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = CARD,
		Text = "RESET",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = DIM,
	}, window)
	UiKit.round(reset, 10)
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

	-- the element tabs
	local tabs = {}
	for i, element in SkillTree.Elements do
		local color = GemConfig.ElementColors[element] or GOLD
		local tab = new("TextButton", {
			Name = element,
			Position = UDim2.fromOffset(24 + (i - 1) * 150, 80),
			Size = UDim2.fromOffset(142, 36),
			BackgroundColor3 = CARD,
			Text = label(element),
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextColor3 = color,
			AutoButtonColor = true,
		}, window)
		UiKit.round(tab, 10)
		local edge = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = LINE, Thickness = 1 }, tab)
		tab.Activated:Connect(function()
			state.Tab, state.Picked = element, nil
			refresh()
		end)
		tabs[element] = { Button = tab, Edge = edge, Color = color }
	end

	-- the branches
	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(24, 128),
		Size = UDim2.new(1, -48, 0, 318),
		BackgroundTransparency = 1,
	}, window)
	local colW = (W - 48 - 2 * 14) / 3
	local headers, cells = {}, {}
	for c, key in KEYS do
		local x = (c - 1) * (colW + 14)
		local head = text(body, key .. "   " .. BRANCH[key], 14, DIM, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(colW, 20),
		})
		headers[key] = head
		cells[key] = {}
		for tier = 1, 4 do
			local row = new("Frame", {
				Name = key .. "Tier" .. tier,
				Position = UDim2.fromOffset(x, 26 + (tier - 1) * 74),
				Size = UDim2.fromOffset(colW, 64),
				BackgroundTransparency = 1,
			}, body)
			cells[key][tier] = row
		end
	end
	-- (tier names down the left edge of the first branch's rows)

	-- the detail strip
	local detail = new("Frame", {
		Name = "Detail",
		Position = UDim2.new(0, 24, 1, -142),
		Size = UDim2.new(1, -48, 0, 124),
		BackgroundColor3 = CARD,
	}, window)
	UiKit.round(detail, 12)
	local dName = text(detail, "", 20, TEXT, Enum.Font.GothamBlack, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -260, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local dWhat = text(detail, "", 14, DIM, Enum.Font.GothamMedium, {
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -260, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local dNumbers = text(detail, "", 13, GOLD, Enum.Font.GothamBold, {
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -260, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local action = new("TextButton", {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(220, 52),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = INK,
		Text = "",
	}, detail)
	UiKit.round(action, 12)
	local actionKind, actionId = nil :: string?, nil :: string?
	action.Activated:Connect(function()
		if actionKind == "Learn" and actionId then
			ask("SkillLearn", actionId)
		elseif actionKind == "Equip" and actionId then
			local _, lane = SkillTree.where(actionId)
			ask("SkillEquip", SkillTree.KeyOfLane[lane or ""], actionId)
		end
	end)

	local nodes = {}
	refresh = function()
		local mine = skills()
		local lv = level()
		local element = state.Tab or (mine and mine.Element) or SkillTree.Elements[1]
		state.Tab = element
		local color = GemConfig.ElementColors[element] or GOLD
		local left = if mine then SkillTree.left(mine, lv) else 0
		points.Text = string.format("LEVEL %d  ·  %d SKILL POINT%s LEFT  ·  YOUR TREE: %s", lv, left, if left == 1 then "" else "S", if mine then label(mine.Element) else "-")
		reset.Text = if state.ResetArmed then "TAP AGAIN TO RESET" else "RESET"
		reset.TextColor3 = if state.ResetArmed then Color3.fromRGB(255, 140, 120) else DIM
		for el, tab in tabs do
			local on = el == element
			tab.Button.BackgroundColor3 = if on then CARD:Lerp(tab.Color, 0.25) else CARD
			tab.Edge.Color = if on then tab.Color else LINE
			tab.Edge.Thickness = if on then 2 else 1
			tab.Button.Text = label(el) .. (if mine and mine.Element == el then "  ◆" else "")
		end
		for _, node in nodes do
			node:Destroy()
		end
		table.clear(nodes)
		local loadout = profile() and profile().Character or {}
		for _, key in KEYS do
			local lane = SkillTree.Lanes[key]
			for tier, ids in SkillTree.Trees[element][lane] do
				local row = cells[key][tier]
				local n = #ids
				local w = (colW - (n - 1) * 8) / n
				for i, id in ids do
					local move = GemTraits.Moves[id]
					local learned = mine and mine.Learned[id]
					local on = mine and mine.Moves[key] == id
					local can = mine and SkillTree.canLearn(mine, id, lv)
					local opens = SkillTree.Levels[tier]
					local b = new("TextButton", {
						Name = id,
						Position = UDim2.fromOffset((i - 1) * (w + 8), 0),
						Size = UDim2.fromOffset(w, 64),
						BackgroundColor3 = if on then CARD:Lerp(GOLD, 0.22) elseif learned then CARD:Lerp(color, 0.2) else CARD,
						AutoButtonColor = true,
						Text = "",
					}, row)
					UiKit.round(b, 10)
					new("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = if state.Picked == id then TEXT elseif on then GOLD elseif learned then color elseif can then color:Lerp(LINE, 0.4) else LINE,
						Thickness = if state.Picked == id or on then 2 else 1,
					}, b)
					text(b, move and move.Name or id, if n >= 3 then 12 else 14, if learned or can then TEXT else FAINT, Enum.Font.GothamBold, {
						Position = UDim2.fromOffset(6, 6),
						Size = UDim2.new(1, -12, 0, 32),
					})
					local status = if on then "ON " .. key
						elseif learned then "LEARNED"
						elseif lv < opens then "LV " .. opens
						elseif can then string.format("%d PT", SkillTree.cost(mine, id))
						else "LOCKED"
					text(b, status, 11, if on then GOLD elseif learned then color elseif can then TEXT else FAINT, Enum.Font.GothamBlack, {
						Position = UDim2.new(0, 6, 1, -22),
						Size = UDim2.new(1, -12, 0, 16),
					})
					b.Activated:Connect(function()
						state.Picked = id
						refresh()
					end)
					table.insert(nodes, b)
				end
			end
		end
		-- the picked move
		local id = state.Picked
		local move = id and GemTraits.Moves[id]
		if not move then
			dName.Text = "Pick a move"
			dWhat.Text = "Learn moves with skill points (one each level). Equip a learned move on its key. Your gem in that key's socket powers it; a gem of the move's element adds +10%."
			dNumbers.Text = ""
			action.Visible = false
			return
		end
		local _, lane, tier = SkillTree.where(id :: string)
		local key = SkillTree.KeyOfLane[lane or ""]
		dName.Text = string.format("%s   ·   %s  %s", move.Name, key, SkillTree.TierNames[tier or 1])
		dWhat.Text = move.Description or ""
		local gem = GemTraits.socketGem(loadout, key)
		local powered = if gem then GemTraits.project(gem, key, id) else nil
		local stats = powered and GemTraits.stats(id, powered)
		dNumbers.Text = if stats
			then string.format("With your %s %s gem: %s%s", gem.Tier or "Common", GemConfig.ElementLabels[gem.Element] or "", GemTraits.summary(stats), if stats.Affinity then "  (+10% affinity)" else "")
			else string.format("Put a gem in your %s to power it.", string.lower(GemTraits.SocketNames[key] or "gear"))
		action.Visible = mine ~= nil
		actionKind, actionId = nil, id
		if mine and mine.Moves[key] == id then
			action.Text, action.Active, action.AutoButtonColor = "ON " .. key, false, false
			action.BackgroundColor3, action.TextColor3 = LINE, GOLD
		elseif mine and mine.Learned[id] then
			actionKind = "Equip"
			action.Text, action.Active, action.AutoButtonColor = "EQUIP ON " .. key, true, true
			action.BackgroundColor3, action.TextColor3 = GOLD, INK
		else
			local ok, why = SkillTree.canLearn(mine, id :: string, lv)
			if ok then
				actionKind = "Learn"
				action.Text = string.format("LEARN  ·  %d PT", SkillTree.cost(mine, id :: string))
				action.Active, action.AutoButtonColor = true, true
				action.BackgroundColor3, action.TextColor3 = GOLD, INK
			else
				action.Text = string.upper(why or "LOCKED")
				action.Active, action.AutoButtonColor = false, false
				action.BackgroundColor3, action.TextColor3 = LINE, DIM
			end
		end
	end
	GemClient.Changed:Connect(function()
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
	if p and p.Character and not p.Character.Skills then
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
	state.Tab, state.Picked = nil, nil
	refresh()
	;(gui :: ScreenGui).Enabled = true
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
