--[[
	The new-player intro, shown until it's finished once:
	  1 Welcome          title and story, over a flyover of the kingdom
	  2 Class            Warrior, Wizard, Archer or Tank
	  3 Starter gems     a lottery spin for three already-cut gems
	  4 First dig        a free wall in the Mine with your first rough stone
	  5 Gem school       cut that stone yourself; what makes a gem valuable
	  6 Enchant          socket a gem into your weapon
	  7 Ready            a tour of the menu, then into the game
	Gear picks are saved as you go, so the preview shows your own avatar
	wearing them. Progress is saved, so leaving mid-way picks up again.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CuttingGame = require(script.Parent.Modules.CuttingGame)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local MineUI = require(script.Parent.Modules.MineUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local K = UiKit.Colors
local P = IronUi.Colors
local HEADING = IronUi.Heading
local BODY = Enum.Font.Gotham
local BOLD = IronUi.Chunky
local ACCENT = Color3.fromRGB(255, 214, 90) -- headings and highlights
local LIGHT = Color3.fromRGB(236, 230, 250)
local DARK = Color3.fromRGB(14, 10, 22)

local CLASS_ICONS = { Warrior = "⚔️", Wizard = "🔮", Archer = "🏹", Tank = "🛡️" }
local ELEMENT_ICONS = { Fire = "🔥", Frost = "❄️", Shock = "⚡", Poison = "☠️" }

local STEPS = { "Welcome", "Class", "Starter Gems", "First Dig", "Gem School", "Enchant", "Ready" }

-- Wait for the profile, and only run for players who haven't finished.
while not GemClient.Profile do
	GemClient.Changed:Wait()
end
if GemClient.Profile.Intro and GemClient.Profile.Intro.Done then
	return
end

-- State --------------------------------------------------------------------------------

local saved = GemClient.Profile.Character or {}
local state = {
	Step = 1,
	Class = saved.Class,
	Weapon = saved.Weapon,
	Armor = saved.Armor,
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function text(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return IronUi.text(parent, value, size, color or P.Text, font or BODY)
end

-- Chunky 3D buttons, the same as every other screen.
local function button(parent: Instance, label: string, primary: boolean, onClick: () -> ()): TextButton
	local b = IronUi.button(parent, label, primary, onClick)
	b.Size = UDim2.fromOffset(0, 48)
	b.TextSize = 18
	return b
end

local function statBars(parent: Instance, stats: { [string]: number }, color: Color3)
	for _, name in Classes.StatNames do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18) }, parent)
		local caption = text(row, string.upper(name), 12, LIGHT, BOLD)
		caption.AutomaticSize = Enum.AutomaticSize.None
		caption.Size = UDim2.new(0, 64, 1, 0)
		local cells = new(
			"Frame",
			{ BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 3), Size = UDim2.new(1, -72, 0, 12) },
			row
		)
		UiKit.list(cells, 4, true)
		for i = 1, 5 do
			local on = i <= stats[name]
			local cell = new("Frame", {
				BackgroundColor3 = if on then color else Color3.fromRGB(40, 34, 56),
				Size = UDim2.new(0.2, -4, 1, 0),
				LayoutOrder = i,
			}, cells)
			UiKit.round(cell, 6)
			new("UIStroke", { Color = DARK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cell)
			if on then
				new("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
				}, cell)
			end
		end
	end
end

-- Screen -------------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "Intro",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 15, -- above the HUD and pouch, below pop-up messages
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

new("Frame", {
	BackgroundColor3 = Color3.fromRGB(4, 8, 10),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
}, gui)

-- The window: gold rim, dark crystal body, a glossy header with a big gem
-- badge, the step's name and a row of progress pips.
local PANEL_W, PANEL_H = 1000, 640
local BODY_TOP = 98
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, gui)
UiKit.round(panel, 18)
new("UIStroke", { Color = P.Gold, Thickness = 5 }, panel)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 30, 60), P.Frame) }, panel)
local scale = new("UIScale", {}, panel)
local function fit()
	local screen = gui.AbsoluteSize
	scale.Scale = math.min(1, (screen.X - 40) / PANEL_W, (screen.Y - 40) / PANEL_H)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local header = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.new(1, -12, 0, 78),
}, panel)
UiKit.round(header, 14)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, IronUi.lighter(P.Amethyst, 0.12)),
		ColorSequenceKeypoint.new(0.6, IronUi.darker(P.Amethyst, 0.25)),
		ColorSequenceKeypoint.new(1, IronUi.darker(P.Teal, 0.3)),
	}),
}, header)
local gloss = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.8,
	Position = UDim2.fromOffset(10, 5),
	Size = UDim2.new(1, -20, 0, 14),
}, header)
UiKit.round(gloss, 7)

local badge = IronUi.badge(panel, "💎", 96)
badge.Position = UDim2.fromOffset(-30, -34)
badge.Rotation = -8
badge.ZIndex = 5
for _, child in badge:GetDescendants() do
	if child:IsA("GuiObject") then
		child.ZIndex = 6
	end
end
IronUi.animate(badge, function(t)
	badge.Rotation = -8 + math.sin(t * 1.5) * 4
end)

local titleLabel = IronUi.title(panel, "", 34)
titleLabel.Position = UDim2.fromOffset(82, 14)
titleLabel.Size = UDim2.new(0.55, 0, 0, 38)
titleLabel.TextWrapped = false
titleLabel.ZIndex = 3
local stepLabel = text(panel, "", 14, LIGHT, BOLD)
stepLabel.Position = UDim2.fromOffset(84, 54)
stepLabel.Size = UDim2.new(0.5, 0, 0, 18)
stepLabel.ZIndex = 3

-- Progress pips: gold ticks behind you, a big bright pip for this step.
local pipRow = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0, 45),
	Size = UDim2.fromOffset(0, 34),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 3,
}, panel)
UiKit.list(pipRow, 8, true)
local pips = {}
for i = 1, #STEPS do
	local pip = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(24, 24),
		LayoutOrder = i,
	}, pipRow)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = pip
	new("UIStroke", { Color = DARK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pip)
	local mark = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = tostring(i),
		Font = BOLD,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
	}, pip)
	IronUi.outline(mark, 1.5)
	pips[i] = { Frame = pip, Mark = mark }
end
local function drawPips(step: number)
	for i, pip in pips do
		local done, current = i < step, i == step
		pip.Frame.Size = if current then UDim2.fromOffset(32, 32) else UDim2.fromOffset(24, 24)
		pip.Frame.BackgroundColor3 = if done then P.Gold elseif current then P.Emerald else Color3.fromRGB(44, 38, 62)
		pip.Mark.Text = if done then "✓" else tostring(i)
		pip.Mark.TextSize = if current then 16 else 13
		pip.Mark.TextTransparency = if done or current then 0 else 0.4
	end
end

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(28, BODY_TOP),
	Size = UDim2.new(1, -56, 1, -BODY_TOP - 88),
}, panel)

local footer = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 28, 1, -18),
	Size = UDim2.new(1, -56, 0, 60),
}, panel)
local backButton, nextButton

-- Live character preview ---------------------------------------------------------------

-- A plain background: a UIGradient on a ViewportFrame would darken the
-- avatar along with it.
local preview = new("ViewportFrame", {
	BackgroundColor3 = Color3.fromRGB(58, 48, 82),
	Ambient = Color3.fromRGB(200, 200, 205),
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(-0.3, -0.8, -1),
	Visible = false,
}, panel)
UiKit.round(preview, 14)
new("UIStroke", { Color = P.Gold, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, preview)
local previewWorld = new("WorldModel", {}, preview)
local previewCamera = new("Camera", { FieldOfView = 30 }, preview)
preview.CurrentCamera = previewCamera
local previewModel: Model? = nil

local function refreshPreview()
	local character = player.Character
	if not character then
		return
	end
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = false
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if previewModel then
		previewModel:Destroy()
	end
	previewModel = copy
	copy.Parent = previewWorld
	previewCamera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -11), Vector3.new(0, 0.6, 0))
end

-- Re-copy the avatar whenever the server rebuilds its gear.
local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "GemsoulGear" then
			task.wait(0.1)
			refreshPreview()
		end
	end)
	task.delay(1, refreshPreview)
end
if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

-- Places the preview over the right-hand part of the page. The panel is a
-- fixed size (scaled as a whole), and the page body starts at (28, BODY_TOP).
local BODY_WIDTH = PANEL_W - 56
local function showPreview(fromFraction: number, top: number, height: number)
	local x = 28 + math.floor(BODY_WIDTH * fromFraction) + 12
	preview.Position = UDim2.fromOffset(x, BODY_TOP + top)
	preview.Size = UDim2.fromOffset(PANEL_W - 28 - x, height)
	preview.Visible = true
end

-- Flyover camera and frozen controls while the intro is open ------------------------------

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
local flyover = RunService.RenderStepped:Connect(function()
	local t = os.clock() * 0.05
	camera.CFrame = CFrame.lookAt(Vector3.new(math.cos(t) * 150, 70, math.sin(t) * 150), Vector3.new(0, 10, 0))
	if previewModel and preview.Visible then
		-- The avatar faces the camera and turns gently side to side.
		previewModel:PivotTo(CFrame.Angles(0, math.sin(os.clock() * 0.6) * 0.5, 0))
	end
end)

-- Freeze movement and hide the HUD while the intro is open. This runs in the
-- background with a time limit so the screens never wait on it.
local controls = nil
local introOpen = true
task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts", 5)
	local module = scripts and scripts:WaitForChild("PlayerModule", 5)
	if module and introOpen then
		local ok, result = pcall(function()
			return require(module):GetControls()
		end)
		if ok and result then
			controls = result
			result:Disable()
		end
	end
end)
local function setHud(enabled: boolean)
	local hud = player.PlayerGui:FindFirstChild("Hud")
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = enabled
	end
end
setHud(false)
task.delay(2, function()
	if introOpen then
		setHud(false)
	end
end)

-- Pages --------------------------------------------------------------------------------

local pages = {}
local busy = false

local function clearBody()
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	-- Page-specific footer buttons (e.g. SPIN!).
	for _, child in footer:GetChildren() do
		if child.Name == "PageAction" then
			child:Destroy()
		end
	end
	preview.Visible = false
end

local function column(parent: Instance, x: number, width: number, gap: number?): Frame
	local frame = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.new(width, if x > 0 then -12 else 0, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, parent)
	UiKit.list(frame, gap or 10)
	new("UIPadding", { PaddingRight = UDim.new(0, 8) }, frame)
	return frame
end

-- A dark slab panel with an ink edge (for info blocks that aren't buttons).
local function slab(parent: Instance, tint: Color3?): Frame
	local frame = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
	UiKit.round(frame, 14)
	local base = tint or Color3.fromRGB(80, 66, 110)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(base:Lerp(DARK, 0.55), base:Lerp(DARK, 0.8)),
	}, frame)
	new("UIStroke", { Color = DARK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	return frame
end

-- A clickable option card tinted in `accent`; `selected` gets a gold rim.
local function optionCard(
	parent: Instance,
	accent: Color3,
	selected: boolean,
	order: number,
	onClick: () -> ()
): TextButton
	local card = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
	}, parent)
	UiKit.round(card, 14)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(
			accent:Lerp(DARK, if selected then 0.35 else 0.55),
			accent:Lerp(DARK, if selected then 0.7 else 0.82)
		),
	}, card)
	new("UIStroke", {
		Color = if selected then P.Gold else DARK,
		Thickness = if selected then 5 else 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, card)
	UiKit.pad(card, 14)
	IronUi.juice(card, 1.03, 0.98)
	IronUi.highlight(card)
	card.Activated:Connect(onClick)
	return card
end

local function saveLoadout(then_: (() -> ())?)
	task.spawn(function()
		GemClient.request("ChooseLoadout", state.Class, state.Weapon, state.Armor)
		if then_ then
			then_()
		end
	end)
end

pages[1] = function()
	local center = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, body)
	local list = UiKit.list(center, 16)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = text(center, "GEMSOUL", 96, P.Gold, HEADING)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.LayoutOrder = 1
	title:FindFirstChildOfClass("UIStroke").Thickness = 5
	local tagline = text(center, "A kingdom built on elemental gems", 24, Color3.new(1, 1, 1), BOLD)
	tagline.TextXAlignment = Enum.TextXAlignment.Center
	tagline.LayoutOrder = 2
	-- The four elements, as chunky chips.
	local chips = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
	}, center)
	UiKit.list(chips, 12, true)
	for i, element in GemConfig.Elements do
		local chip = new("Frame", {
			BackgroundColor3 = GemConfig.ElementColors[element],
			Size = UDim2.fromOffset(150, 44),
			LayoutOrder = i,
		}, chips)
		UiKit.round(chip, 12)
		new("UIStroke", { Color = DARK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
		}, chip)
		local label =
			text(chip, (ELEMENT_ICONS[element] or "") .. "  " .. string.upper(element), 18, Color3.new(1, 1, 1), BOLD)
		label.AutomaticSize = Enum.AutomaticSize.None
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		IronUi.animate(chip, function(t)
			chip.Rotation = math.sin(t * 2 + i) * 2
		end)
	end
	local card = slab(center)
	card.Size = UDim2.fromOffset(720, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = 4
	UiKit.pad(card, 20)
	local story = text(
		card,
		"Beneath the walled kingdom of Gemsoul lie stones that hold the power of the elements. Miners dig them, cutters shape them, and heroes bind them to their weapons.\n\nChoose your path, claim your first gems, and step through the gate.",
		18,
		LIGHT
	)
	story.TextXAlignment = Enum.TextXAlignment.Center
	return true
end

pages[2] = function()
	local heading = text(body, "CHOOSE YOUR HERO", 34, Color3.new(1, 1, 1), HEADING)
	heading.TextXAlignment = Enum.TextXAlignment.Center
	local sub = text(body, "Your class sets your look and your stats.", 16, LIGHT, BOLD)
	sub.Position = UDim2.fromOffset(0, 42)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	local grid = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 330),
	}, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -9, 1, 0),
		CellPadding = UDim2.fromOffset(12, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, classId in Classes.Order do
		local class = Classes.List[classId]
		local card = optionCard(grid, class.Color, state.Class == classId, i, function()
			if state.Class ~= classId then
				state.Class = classId
				state.Weapon = class.Weapons[1].Id
				state.Armor = class.Armors[1].Id
				saveLoadout()
			end
			pages.redraw()
		end)
		UiKit.list(card, 6)
		local icon = text(card, CLASS_ICONS[classId] or "✨", 64, Color3.new(1, 1, 1), BODY)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		IronUi.animate(icon, function(t)
			icon.Rotation = math.sin(t * 1.8 + i) * 6
		end)
		local name = text(card, string.upper(class.Name), 30, Color3.new(1, 1, 1), HEADING)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local role = text(
			card,
			class.Role .. "  •  " .. string.rep("★", class.Difficulty),
			14,
			class.Color:Lerp(Color3.new(1, 1, 1), 0.4),
			BOLD
		)
		role.TextXAlignment = Enum.TextXAlignment.Center
		local tagline = text(card, class.Tagline, 15, LIGHT, BOLD)
		tagline.TextXAlignment = Enum.TextXAlignment.Center
		statBars(card, class.Stats, class.Color)
	end
	return state.Class ~= nil
end

-- Little stars that burst out of `parent` when a gem lands.
local function sparkle(parent: GuiObject, color: Color3)
	for n = 1, 10 do
		local star = new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(28, 28),
			Text = if n % 2 == 0 then "✦" else "✧",
			TextSize = math.random(18, 30),
			TextColor3 = if n % 3 == 0 then Color3.new(1, 1, 1) else color,
			Font = BOLD,
			ZIndex = 8,
		}, parent)
		local angle = math.random() * math.pi * 2
		local distance = math.random(90, 170)
		TweenService:Create(star, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.4, math.sin(angle) * distance),
			TextTransparency = 1,
			Rotation = 180,
		}):Play()
		task.delay(0.85, function()
			star:Destroy()
		end)
	end
end

-- Size / Clarity / Cut as three little stat tiles.
local function statTiles(parent: Instance, order: number): (string, string, string) -> ()
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = order,
	}, parent)
	UiKit.list(row, 6, true)
	local values = {}
	for n, caption in { "SIZE", "CLARITY", "CUT" } do
		local tile = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(34, 28, 50),
			Size = UDim2.new(1 / 3, -4, 1, 0),
			LayoutOrder = n,
		}, row)
		UiKit.round(tile, 10)
		new("UIStroke", { Color = DARK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tile)
		local top = text(tile, caption, 11, P.Dim, BOLD)
		top.AutomaticSize = Enum.AutomaticSize.None
		top.Position = UDim2.fromOffset(0, 4)
		top.Size = UDim2.new(1, 0, 0, 14)
		top.TextXAlignment = Enum.TextXAlignment.Center
		local value = text(tile, "?", 22, Color3.new(1, 1, 1), HEADING)
		value.AutomaticSize = Enum.AutomaticSize.None
		value.Position = UDim2.fromOffset(0, 20)
		value.Size = UDim2.new(1, 0, 0, 26)
		value.TextXAlignment = Enum.TextXAlignment.Center
		values[n] = value
	end
	return function(size, clarity, cut)
		values[1].Text, values[2].Text, values[3].Text = size, clarity, cut
	end
end

-- A gem reveal card: a rarity ribbon, the gem on a glowing stage, its name,
-- element, stat tiles and value. Returns (card, land(gem), spin(), empty()).
local function gemReel(parent: Instance, order: number)
	local reel = slab(parent)
	reel.LayoutOrder = order
	local stroke = reel:FindFirstChildOfClass("UIStroke") :: UIStroke
	local ribbon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(140, 30),
		BackgroundColor3 = Color3.fromRGB(90, 80, 120),
		ZIndex = 6,
	}, reel)
	UiKit.round(ribbon, 10)
	new("UIStroke", { Color = DARK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ribbon)
	local ribbonText = text(ribbon, "???", 16, Color3.new(1, 1, 1), BOLD)
	ribbonText.AutomaticSize = Enum.AutomaticSize.None
	ribbonText.Size = UDim2.fromScale(1, 1)
	ribbonText.TextXAlignment = Enum.TextXAlignment.Center
	ribbonText.TextYAlignment = Enum.TextYAlignment.Center
	ribbonText.ZIndex = 7

	local stage = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(12, 24),
		Size = UDim2.new(1, -24, 0, 170),
		ClipsDescendants = true,
	}, reel)
	UiKit.round(stage, 12)
	local stageShade = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(90, 80, 120), Color3.fromRGB(22, 18, 34)),
	}, stage)
	local spot = GemArt.backdrop(stage):FindFirstChildOfClass("Frame")

	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 202),
		Size = UDim2.new(1, -24, 1, -210),
	}, reel)
	UiKit.list(info, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local title = text(info, "?", 22, Color3.new(1, 1, 1), HEADING)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.LayoutOrder = 1
	local element = text(info, "", 15, LIGHT, BOLD)
	element.TextXAlignment = Enum.TextXAlignment.Center
	element.LayoutOrder = 2
	local setStats = statTiles(info, 3)
	local worth = text(info, "", 22, P.Gold, BOLD)
	worth.TextXAlignment = Enum.TextXAlignment.Center
	worth.LayoutOrder = 4

	local spinning = false
	local function spin()
		spinning = true
		task.spawn(function()
			while spinning do
				local el = GemConfig.Elements[math.random(1, #GemConfig.Elements)]
				local shade = GemConfig.Shades[el][math.random(1, 3)]
				if spot then
					spot.BackgroundColor3 = shade.Color
				end
				title.Text = shade.Name
				element.Text = (ELEMENT_ICONS[el] or "") .. " " .. string.upper(el)
				task.wait(0.07)
			end
		end)
	end
	local function land(gem)
		spinning = false
		local tierColor = GemConfig.TierColors[gem.Tier]
		if spot then
			spot.BackgroundColor3 = tierColor
		end
		stageShade.Color = ColorSequence.new(tierColor:Lerp(DARK, 0.35), tierColor:Lerp(DARK, 0.85))
		GemArt.viewport(stage, gem, true)
		stroke.Color = tierColor
		stroke.Thickness = 5
		ribbon.BackgroundColor3 = tierColor
		ribbonText.Text = string.upper(GemConfig.TierLabels[gem.Tier])
		title.Text = GemConfig.shade(gem).Name
		element.Text = (ELEMENT_ICONS[gem.Element] or "") .. " " .. string.upper(gem.Element)
		element.TextColor3 = GemConfig.ElementColors[gem.Element]:Lerp(Color3.new(1, 1, 1), 0.3)
		setStats(tostring(gem.Size), tostring(gem.Clarity), if gem.Cut then tostring(gem.Cut) else "-")
		worth.Text = "💰 " .. tostring(GemConfig.value(gem))
		sparkle(reel, tierColor)
		local pop = reel:FindFirstChildOfClass("UIScale") or new("UIScale", {}, reel)
		pop.Scale = 1.15
		TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	-- Nothing to show here (e.g. that starter gem was sold or used).
	local function empty()
		spinning = false
		title.Text = "Used"
		element.Text = "Already in your pouch or sold"
		element.TextColor3 = P.Dim
		ribbonText.Text = "-"
	end
	return reel, land, spin, empty
end

local function gemsFrom(source: string)
	local found = {}
	for _, gem in (GemClient.Profile and GemClient.Profile.Gems or {}) do
		if gem.Source == source then
			table.insert(found, gem)
		end
	end
	local weaponGem = GemClient.Profile and GemClient.Profile.Character and GemClient.Profile.Character.WeaponGem
	if weaponGem and weaponGem.Source == source then
		table.insert(found, weaponGem)
	end
	return found
end

pages[3] = function()
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60) }, body)
	UiKit.list(top, 4).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local heading = text(top, "SPIN FOR YOUR STARTER GEMS!", 30, Color3.new(1, 1, 1), HEADING)
	heading.TextXAlignment = Enum.TextXAlignment.Center
	local sub =
		text(top, "Three gems, already cut and ready to use. At least one is Uncommon or better.", 15, LIGHT, BOLD)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	local reels = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -84) },
		body
	)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -14, 1, 0),
		CellPadding = UDim2.fromOffset(20, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, reels)
	local landers, spinners, empties = {}, {}, {}
	for i = 1, 3 do
		local _, land, spin, empty = gemReel(reels, i)
		landers[i], spinners[i], empties[i] = land, spin, empty
	end
	local function showAll(gems)
		for i = 1, 3 do
			if gems[i] then
				landers[i](gems[i])
			else
				empties[i]()
			end
		end
	end

	local existing = gemsFrom("StarterSpin")
	if GemClient.Profile.Intro.Spun then
		showAll(existing)
		return true
	end

	-- The big SPIN button sits in the footer, in NEXT's place, and pulses.
	local spinButton
	spinButton = IronUi.gemButton(footer, "🎰  SPIN!", Color3.fromRGB(255, 176, 30), function()
		if busy then
			return
		end
		busy = true
		spinButton:Destroy()
		for _, spin in spinners do
			spin()
		end
		task.spawn(function()
			local result = GemClient.request("StarterSpin")
			task.wait(1.2)
			if result.Ok then
				for i = 1, 3 do
					task.wait(0.6)
					if result.Gems[i] then
						landers[i](result.Gems[i])
					else
						empties[i]()
					end
				end
				nextButton.Visible = true
			else
				for _, empty in empties do
					empty()
				end
				UiKit.toast(result.Message, K.Bad)
			end
			busy = false
		end)
	end)
	spinButton.Name = "PageAction"
	spinButton.AnchorPoint = Vector2.new(1, 0.5)
	spinButton.Position = UDim2.new(1, 0, 0.5, 0)
	spinButton.Size = UDim2.fromOffset(0, 58)
	spinButton.TextSize = 26
	IronUi.animate(spinButton, function(t)
		spinButton.Rotation = math.sin(t * 6) * 2
	end)
	return false
end

-- The first dig: a free wall in the Mine with the player's first stone in
-- it. The mine opens on top of the intro; it comes back when they continue.
pages[4] = function()
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70) }, body)
	UiKit.list(top, 4).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local heading = text(top, "TIME TO DIG!", 34, Color3.new(1, 1, 1), HEADING)
	heading.TextXAlignment = Enum.TextXAlignment.Center
	local sub =
		text(top, "Gems grow inside the rock under Gemsoul. Swing your pickaxe and break them out.", 16, LIGHT, BOLD)
	sub.TextXAlignment = Enum.TextXAlignment.Center

	-- Three example rocks: what the hints mean.
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 230),
	}, body)
	UiKit.list(row, 24, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local examples = {
		{ "✦", Color3.fromRGB(190, 250, 255), "GLINTING ROCK", "A gem is inside. Keep hitting it!" },
		{ "◆", Color3.fromRGB(190, 195, 205), "SPECKLED ROCK", "Ore for crafting gear." },
		{ "💰", P.Gold, "PLAIN ROCK", "Often rubble, sometimes coins." },
	}
	for n, example in examples do
		local card = slab(row)
		card.Size = UDim2.fromOffset(250, 230)
		card.LayoutOrder = n
		local rock = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 18),
			Size = UDim2.fromOffset(100, 100),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Rotation = (n - 2) * 5,
		}, card)
		UiKit.round(rock, 30)
		new("UIStroke", { Color = DARK, Thickness = 3 }, rock)
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(150, 138, 128), Color3.fromRGB(84, 74, 70)),
		}, rock)
		local mark = text(rock, example[1], if n == 3 then 30 else 40, example[2], BOLD)
		mark.AutomaticSize = Enum.AutomaticSize.None
		mark.Size = UDim2.fromScale(1, 1)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextYAlignment = Enum.TextYAlignment.Center
		mark.TextTransparency = if n == 3 then 0.5 else 0
		if n == 1 then
			IronUi.animate(mark, function(t)
				mark.Rotation = t * 60
				mark.TextTransparency = 0.5 - (math.sin(t * 3) + 1) / 4
			end)
		end
		local name = text(card, example[3], 20, Color3.new(1, 1, 1), HEADING)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.Position = UDim2.fromOffset(10, 132)
		name.Size = UDim2.new(1, -20, 0, 24)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local what = text(card, example[4], 15, LIGHT, BOLD)
		what.Position = UDim2.fromOffset(14, 164)
		what.Size = UDim2.new(1, -28, 0, 0)
		what.TextXAlignment = Enum.TextXAlignment.Center
	end
	local status = text(body, "", 17, ACCENT, BOLD)
	status.Position = UDim2.fromOffset(0, 342)
	status.TextXAlignment = Enum.TextXAlignment.Center

	local function found(): boolean
		local stone = gemsFrom("FirstStone")[1]
		if stone then
			status.Text = string.format("You dug up %s! Next: cut it to make it shine.", GemConfig.displayName(stone))
			status.TextColor3 = P.Good
			nextButton.Visible = true
			return true
		end
		return false
	end
	if found() then
		return true
	end
	status.Text = "Your pickaxe is ready. Every new miner gets one free wall."
	local dig
	dig = IronUi.gemButton(footer, "⛏️  START DIGGING", Color3.fromRGB(255, 150, 30), function()
		if busy then
			return
		end
		busy = true
		gui.Enabled = false
		MineUI.tutorial()
		gui.Enabled = true
		-- If the dig couldn't start, Ilsa hands over a practice stone instead.
		if not gemsFrom("FirstStone")[1] and not GemClient.Profile.Intro.FirstStone then
			GemClient.request("FirstStone")
		end
		busy = false
		if found() then
			dig:Destroy()
		else
			status.Text = "No stone yet! Press START DIGGING and break the glinting rock."
		end
	end)
	dig.Name = "PageAction"
	dig.AnchorPoint = Vector2.new(1, 0.5)
	dig.Position = UDim2.new(1, 0, 0.5, 0)
	dig.Size = UDim2.fromOffset(0, 58)
	dig.TextSize = 24
	IronUi.animate(dig, function(t)
		dig.Rotation = math.sin(t * 6) * 2
	end)
	return false
end

local PROPERTY_HELP = {
	{
		"COLOUR AND ELEMENT",
		"Every gem holds Fire, Frost, Shock or Poison. Each element has common, uncommon and rare colours; rarer colours are worth much more.",
	},
	{
		"SIZE  (1-10)",
		"The biggest factor in value: each grade is worth about 45% more than the last. Big gems also make stronger enchantments, but are harder to cut.",
	},
	{
		"CLARITY  (1-10)",
		"How clear the stone is. Low clarity is cloudy, with specks inside; clarity 10 is flawless glass.",
	},
	{
		"CUT  (1-10)",
		"Rough stones come out of the ground uncut and worth half as much. Cutting shapes the facets: 1-8 by hand, 9 for mastery, 10 is Gem Mint.",
	},
}

local LESSON_ICONS = { "🎨", "📏", "💎", "✂️" }
local PLACES = {
	{ "⛏️", "Mine (M): dig walls of rock for gems, ore and coins. Deeper walls hold rarer gems." },
	{ "✂️", "Cut (X): shape rough stones by hand. A better cut is worth far more." },
	{ "⚒️", "Craft (F): buy materials and forge weapons and armor." },
	{ "💰", "Sell (V): trade stones you don't need for coins." },
	{ "💎", "Gems (G): your pouch. Set gems into your gear from the Character screen (C)." },
	{ "🛒", "Shop (B): crates, cosmetics and bundles." },
}

pages[5] = function()
	-- Left: the stone on a stage, its stats, and the cut buttons.
	local left = slab(body)
	left.Size = UDim2.new(0.4, -8, 1, 0)
	local right = column(body, 0.4, 0.6, 10)
	right.Position = UDim2.new(0.4, 12, 0, 0)
	right.Size = UDim2.new(0.6, -12, 1, 0)

	local stage = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 200),
		ClipsDescendants = true,
	}, left)
	UiKit.round(stage, 12)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(110, 90, 150), Color3.fromRGB(22, 18, 34)),
	}, stage)
	GemArt.backdrop(stage)
	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 220),
		Size = UDim2.new(1, -24, 1, -228),
	}, left)
	UiKit.list(info, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local caption = text(info, "", 20, Color3.new(1, 1, 1), HEADING)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.LayoutOrder = 1
	local setStats = statTiles(info, 2)
	local valueLine = text(info, "", 18, P.Gold, BOLD)
	valueLine.TextXAlignment = Enum.TextXAlignment.Center
	valueLine.LayoutOrder = 3
	local status = text(info, "", 13, LIGHT, BOLD)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.LayoutOrder = 4
	local actions = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 5 }, info)
	UiKit.list(actions, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Right: the gem lessons as cards.
	local intro = text(
		right,
		"Ilsa, the town's Master Gemcutter, hands you a rough stone to practise on. Here's what makes a gem:",
		15,
		LIGHT,
		BOLD
	)
	intro.LayoutOrder = 0
	for n, help in PROPERTY_HELP do
		local card = slab(right)
		card.Size = UDim2.new(1, 0, 0, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.LayoutOrder = n
		new("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 58),
			PaddingRight = UDim.new(0, 12),
		}, card)
		UiKit.list(card, 2)
		local icon = text(card, LESSON_ICONS[n] or "💎", 30, Color3.new(1, 1, 1), BODY)
		icon.AutomaticSize = Enum.AutomaticSize.None
		icon.Position = UDim2.fromOffset(-48, 0)
		icon.Size = UDim2.fromOffset(40, 40)
		-- Keep the icon out of the list flow.
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) }, card)
		holder.LayoutOrder = 0
		icon.Parent = holder
		text(card, help[1], 16, ACCENT, BOLD).LayoutOrder = 1
		text(card, help[2], 14, LIGHT).LayoutOrder = 2
	end
	text(right, "ALL FROM THE MENU", 18, Color3.new(1, 1, 1), HEADING).LayoutOrder = 10
	for n, place in PLACES do
		local row = slab(right, Color3.fromRGB(60, 90, 110))
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = 10 + n
		new("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 46),
			PaddingRight = UDim.new(0, 10),
		}, row)
		local icon = text(row, place[1], 22, Color3.new(1, 1, 1), BODY)
		icon.AutomaticSize = Enum.AutomaticSize.None
		icon.Position = UDim2.fromOffset(-38, -2)
		icon.Size = UDim2.fromOffset(30, 30)
		text(row, place[2], 13, LIGHT)
	end

	local stone = nil
	local function show(gem)
		stone = gem
		for _, child in stage:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		GemArt.viewport(stage, gem, true)
		caption.Text = GemConfig.displayName(gem)
		setStats(tostring(gem.Size), tostring(gem.Clarity), if gem.Cut then tostring(gem.Cut) else "ROUGH")
		valueLine.Text = "💰 Worth " .. tostring(GemConfig.value(gem)) .. " coins"
	end

	local function cutButton()
		for _, child in actions:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		if stone and stone.Cut then
			status.Text = "Cut! Press NEXT to enchant your weapon."
			status.TextColor3 = P.Good
			nextButton.Visible = true
			return
		end
		status.Text = "Rough stones are worth half. Cut it to see it shine."
		status.TextColor3 = LIGHT
		IronUi.gemButton(actions, "✂️  CUT IT NOW", Color3.fromRGB(255, 176, 30), function()
			if busy or not stone then
				return
			end
			busy = true
			task.spawn(function()
				local before = GemConfig.value(stone)
				local start = GemClient.request("StartCut", stone.Id)
				if start.Ok then
					gui.Enabled = false
					local times = CuttingGame.play(stone, start)
					gui.Enabled = true
					if times then
						local result = GemClient.request("FinishCut", times)
						if result.Ok and result.Gem then
							show(result.Gem)
							UiKit.toast(
								string.format(
									"Cut grade %d! Value %d -> %d coins.",
									result.Gem.Cut,
									before,
									GemConfig.value(result.Gem)
								),
								P.Gold
							)
						else
							UiKit.toast(result.Message, K.Bad)
						end
					end
				else
					UiKit.toast(start.Message, K.Bad)
				end
				busy = false
				cutButton()
			end)
		end)
		button(actions, "Skip", false, function()
			status.Text = "You can cut it any time: Cut (X) in the menu. Press NEXT."
			nextButton.Visible = true
		end)
	end

	task.spawn(function()
		local existing = gemsFrom("FirstStone")[1]
		if existing then
			show(existing)
		else
			-- Skipped the dig? Ilsa hands over a practice stone instead.
			local result = GemClient.request("FirstStone")
			if result.Ok and result.Gem then
				show(result.Gem)
			end
		end
		cutButton()
	end)
	return false
end

pages[6] = function()
	local class = Classes.List[state.Class]
	local weapon = Classes.weapon(state.Class, state.Weapon)
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 74) }, body)
	UiKit.list(top, 4)
	text(top, "ENCHANT YOUR WEAPON", 22, class.Color, HEADING)
	text(
		top,
		string.format(
			"Your %s has one gem socket. A socketed gem adds its element to your hits, raises your stats and wreathes the weapon in its element. Pick one of your cut gems (swap it any time from your Character screen, C).",
			weapon and weapon.Name or "weapon"
		),
		14,
		P.Dim
	)
	local grid = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(0.62, 0, 1, -86),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, body)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(180, 230),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	showPreview(0.62, 86, 330)

	local socketed = GemClient.Profile.Character and GemClient.Profile.Character.WeaponGem
	local gems = {}
	if socketed then
		table.insert(gems, socketed)
	end
	for _, gem in GemClient.Profile.Gems do
		if gem.Cut then
			table.insert(gems, gem)
		end
	end
	for i, gem in gems do
		local isSocketed = socketed ~= nil and gem.Id == socketed.Id
		local card = optionCard(grid, GemConfig.TierColors[gem.Tier], isSocketed, i, function()
			if busy or isSocketed then
				return
			end
			busy = true
			task.spawn(function()
				local result = GemClient.request("SocketGem", gem.Id)
				UiKit.toast(result.Message, if result.Ok then P.Gold else K.Bad)
				busy = false
				pages.redraw()
			end)
		end)
		local stage = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 100) }, card)
		GemArt.backdrop(stage)
		GemArt.viewport(stage, gem, false)
		local info = new(
			"Frame",
			{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 1, -104) },
			card
		)
		UiKit.list(info, 2)
		text(info, GemConfig.shade(gem).Name, 13, LIGHT, BOLD)
		text(
			info,
			string.upper(gem.Element) .. (if isSocketed then "  |  SOCKETED" else ""),
			11,
			GemConfig.ElementColors[gem.Element],
			BOLD
		)
		text(info, GemConfig.ElementEffects[gem.Element], 11, P.Dim)
	end
	return socketed ~= nil
end

-- Ready: a tour of the menu, with your avatar alongside.
local TOUR = {
	{
		"⛏️",
		"MINE",
		"M",
		"Dig walls for gems, ore and coins. Go deeper for rarer finds.",
		Color3.fromRGB(240, 140, 40),
	},
	{ "✂️", "CUT", "X", "Cut rough stones by hand to multiply their value.", Color3.fromRGB(60, 160, 220) },
	{ "⚒️", "CRAFT", "F", "Forge weapons and armor from materials.", Color3.fromRGB(150, 100, 60) },
	{ "💰", "SELL", "V", "Turn spare stones into coins.", Color3.fromRGB(230, 180, 40) },
	{ "💎", "GEMS", "G", "Your pouch, with every stone in 3D.", Color3.fromRGB(150, 80, 220) },
	{ "🛒", "SHOP", "B", "Crates, cosmetics and bundles.", Color3.fromRGB(220, 70, 140) },
}

pages[7] = function()
	local class = Classes.List[state.Class]
	local left = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.62, 0, 1, 0) }, body)
	text(left, "READY, " .. string.upper(player.DisplayName) .. "!", 32, Color3.new(1, 1, 1), HEADING)
	local sub = text(left, class.Name .. "  •  everything is one click away in the menu:", 16, LIGHT, BOLD)
	sub.Position = UDim2.fromOffset(0, 42)
	local grid = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -76),
	}, left)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 104),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for n, stop in TOUR do
		local card = slab(grid, stop[5])
		card.LayoutOrder = n
		local icon = text(card, stop[1], 40, Color3.new(1, 1, 1), BODY)
		icon.AutomaticSize = Enum.AutomaticSize.None
		icon.Position = UDim2.fromOffset(12, 12)
		icon.Size = UDim2.fromOffset(52, 52)
		local name = text(card, stop[2], 22, Color3.new(1, 1, 1), HEADING)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.Position = UDim2.fromOffset(72, 12)
		name.Size = UDim2.new(1, -120, 0, 26)
		local key = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = P.Gold,
			Text = stop[3],
			Font = BOLD,
			TextSize = 14,
			TextColor3 = DARK,
		}, card)
		UiKit.round(key, 13)
		new("UIStroke", { Color = DARK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, key)
		local what = text(card, stop[4], 13, LIGHT, BOLD)
		what.Position = UDim2.fromOffset(72, 42)
		what.Size = UDim2.new(1, -84, 0, 0)
	end

	local side = column(body, 0.62, 0.38, 6)
	new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 330) }, side)
	showPreview(0.62, 0, 330)
	local bars = new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
		side
	)
	UiKit.list(bars, 4)
	statBars(bars, Classes.stats(state.Class, state.Weapon, state.Armor), class.Color)
	return true
end

-- Navigation ----------------------------------------------------------------------------

local function finish()
	busy = true
	task.spawn(function()
		local result = GemClient.request("FinishIntro")
		if not result.Ok then
			UiKit.toast(result.Message, K.Bad)
			busy = false
			return
		end
		flyover:Disconnect()
		introOpen = false
		if Config.MenuOnly then
			-- The menu camera takes over; the character stays put.
			setHud(true)
			gui:Destroy()
			UiKit.toast("Welcome to Gemsoul! Press M or click MINE to start digging.", ACCENT)
			return
		end
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		if controls then
			controls:Enable()
		end
		setHud(true)
		gui:Destroy()
		UiKit.toast("Welcome to Gemsoul! Talk to Garrick at the Mining Guild, up the north road.", ACCENT)
	end)
end

function pages.redraw()
	clearBody()
	local step = state.Step
	titleLabel.Text = string.upper(STEPS[step])
	stepLabel.Text = string.format("STEP %d OF %d", step, #STEPS)
	drawPips(step)
	-- Hidden until the page allows it. Some pages reveal it themselves once
	-- you've done something (spun, cut), possibly before they return.
	nextButton.Visible = false
	-- If a page fails, say so on screen rather than leaving it blank.
	local ok, result = pcall(pages[step])
	if not ok then
		warn("[Intro] Page " .. step .. " failed: " .. tostring(result))
		text(body, "Something went wrong on this page:\n" .. tostring(result), 14, K.Bad)
	end
	-- No going back once the one-time gem steps start (dig, school).
	backButton.Visible = step > 1 and step ~= 4 and step ~= 5
	if not ok or result then
		nextButton.Visible = true
	end
	nextButton.Text = if step == 1 then "BEGIN  ▶" elseif step == #STEPS then "ENTER GEMSOUL  ▶" else "NEXT  ▶"
end

local function go(delta: number)
	if busy then
		return
	end
	local target = math.clamp(state.Step + delta, 1, #STEPS)
	-- Can't go back past the one-time gem steps.
	if delta < 0 and state.Step >= 4 and target < 4 then
		return
	end
	state.Step = target
	pages.redraw()
end

backButton = button(footer, "◀  Back", false, function()
	go(-1)
end)
backButton.AnchorPoint = Vector2.new(0, 0.5)
backButton.Position = UDim2.fromScale(0, 0.5)
nextButton = IronUi.gemButton(footer, "NEXT", P.Emerald, function()
	if state.Step == #STEPS then
		finish()
	elseif state.Step == 2 then
		-- Make sure the final gear pick is saved before moving on.
		busy = true
		saveLoadout(function()
			busy = false
			go(1)
		end)
	else
		go(1)
	end
end)
nextButton.AnchorPoint = Vector2.new(1, 0.5)
nextButton.Position = UDim2.fromScale(1, 0.5)
nextButton.Size = UDim2.fromOffset(0, 58)
nextButton.TextSize = 24

-- The enchant page lists gems from the profile, so redraw it when that changes.
GemClient.Changed:Connect(function()
	if gui.Parent and state.Step == 7 and not busy then
		pages.redraw()
	end
end)

pages.redraw()
