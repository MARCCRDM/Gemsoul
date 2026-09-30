--[[
	The new-player intro, shown until it's finished once:
	  1 Welcome          title and story, over a flyover of the kingdom
	  2 Class            Warrior, Wizard, Archer or Tank
	  3 Weapon           three playstyles per class
	  4 Armor            three playstyles per class
	  5 Starter gems     a lottery spin for three already-cut gems
	  6 Gem school       cut a rough stone yourself; how gems and the town work
	  7 Enchant          socket a gem into your weapon
	  8 Ready            character sheet, then into the game
	Gear picks are saved as you go, so the preview shows your own avatar
	wearing them. Progress is saved, so leaving mid-way picks up again.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local AbilitiesUI = require(script.Parent.Modules.AbilitiesUI)
local CuttingGame = require(script.Parent.Modules.CuttingGame)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local K = UiKit.Colors
local HEADING = Enum.Font.Arcade
local BODY = Enum.Font.Gotham
local BOLD = Enum.Font.GothamBold

local STEPS = { "Welcome", "Class", "Weapon", "Armor", "Starter Gems", "Gem School", "Enchant", "Ready" }

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
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color or K.Text,
		Font = font or BODY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
end

local function button(parent: Instance, label: string, primary: boolean, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = if primary then K.Accent else K.Row,
		Text = label,
		Font = BOLD,
		TextSize = 16,
		TextColor3 = if primary then Color3.fromRGB(6, 20, 24) else K.Text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 42),
	}, parent)
	UiKit.round(b, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, b)
	b.Activated:Connect(onClick)
	return b
end

local function statBars(parent: Instance, stats: { [string]: number }, color: Color3)
	for _, name in Classes.StatNames do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16) }, parent)
		local caption = text(row, string.upper(name), 11, K.Dim, BOLD)
		caption.AutomaticSize = Enum.AutomaticSize.None
		caption.Size = UDim2.new(0, 64, 1, 0)
		local cells = new(
			"Frame",
			{ BackgroundTransparency = 1, Position = UDim2.fromOffset(66, 3), Size = UDim2.new(1, -66, 0, 10) },
			row
		)
		UiKit.list(cells, 3, true)
		for i = 1, 5 do
			local cell = new("Frame", {
				BackgroundColor3 = if i <= stats[name] then color else Color3.fromRGB(44, 54, 52),
				Size = UDim2.new(0.2, -3, 1, 0),
				LayoutOrder = i,
			}, cells)
			UiKit.round(cell, 3)
		end
	end
end

local function modsText(mods: { [string]: number }): string
	local parts = {}
	for _, name in Classes.StatNames do
		local change = mods[name]
		if change then
			table.insert(parts, string.format("%s%d %s", if change > 0 then "+" else "", change, name))
		end
	end
	return if #parts > 0 then table.concat(parts, "  ") else "No trade-offs"
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

local panel = UiKit.panel(gui)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(1000, 640)
local scale = new("UIScale", {}, panel)
local function fit()
	local screen = gui.AbsoluteSize
	scale.Scale = math.min(1, (screen.X - 24) / 1000, (screen.Y - 24) / 640)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local stepLabel = text(panel, "", 13, K.Accent, BOLD)
stepLabel.Position = UDim2.fromOffset(24, 18)
stepLabel.Size = UDim2.new(1, -48, 0, 16)

local progress = new(
	"Frame",
	{ BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 40), Size = UDim2.new(1, -48, 0, 4) },
	panel
)
UiKit.list(progress, 4, true)
local progressCells = {}
for i = 1, #STEPS do
	progressCells[i] = new("Frame", {
		BackgroundColor3 = K.Row,
		Size = UDim2.new(1 / #STEPS, -4, 1, 0),
		LayoutOrder = i,
	}, progress)
end

local body = new(
	"Frame",
	{ BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 58), Size = UDim2.new(1, -48, 1, -128) },
	panel
)

local footer = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -16),
	Size = UDim2.new(1, -48, 0, 42),
}, panel)
local backButton, nextButton

-- Live character preview ---------------------------------------------------------------

-- A plain background: a UIGradient on a ViewportFrame would darken the
-- avatar along with it.
local preview = new("ViewportFrame", {
	BackgroundColor3 = Color3.fromRGB(44, 52, 62),
	Ambient = Color3.fromRGB(200, 200, 205),
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(-0.3, -0.8, -1),
	Visible = false,
}, panel)
UiKit.round(preview, 10)
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
-- fixed 1000x640 (scaled as a whole), and the page body starts at (24, 58).
local BODY_WIDTH = 1000 - 48
local function showPreview(fromFraction: number, top: number, height: number)
	local x = 24 + math.floor(BODY_WIDTH * fromFraction) + 12
	preview.Position = UDim2.fromOffset(x, 58 + top)
	preview.Size = UDim2.fromOffset(1000 - 24 - x, height)
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

-- A clickable option card; `selected` draws it highlighted.
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
		BackgroundColor3 = if selected then Color3.fromRGB(28, 40, 44) else Color3.fromRGB(20, 26, 30),
		LayoutOrder = order,
	}, parent)
	UiKit.round(card, 10)
	new("UIStroke", {
		Color = accent,
		Thickness = if selected then 3 else 1.5,
		Transparency = if selected then 0 else 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, card)
	UiKit.pad(card, 14)
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
	local list = UiKit.list(center, 18)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = text(center, "GEMSOUL", 72, K.Accent, HEADING)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local story = text(
		center,
		"Beneath the walled kingdom of Gemsoul lie stones that hold the power of the elements: Fire, Frost, Shock and Poison. Miners dig them, cutters shape them, and heroes bind them to their weapons.\n\nChoose your path, claim your first gems, and step through the gate.",
		18,
		K.Text
	)
	story.TextXAlignment = Enum.TextXAlignment.Center
	new("UISizeConstraint", { MaxSize = Vector2.new(700, math.huge) }, story)
	return true
end

pages[2] = function()
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, body)
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
		UiKit.list(card, 8)
		text(card, string.upper(class.Name), 24, class.Color, HEADING)
		text(card, class.Role .. "  |  " .. string.rep("*", class.Difficulty) .. " difficulty", 13, K.Dim, BOLD)
		text(card, class.Tagline, 14, K.Text)
		statBars(card, class.Stats, class.Color)
		text(card, "6 ABILITIES (EQUIP ANY 3)", 11, K.Dim, BOLD)
		local names = {}
		for _, ability in class.Abilities do
			table.insert(names, ability.Name)
		end
		text(card, table.concat(names, ", "), 13, K.Text)
		text(card, "ULTIMATE", 11, K.Dim, BOLD)
		text(card, class.Ultimate.Name, 14, K.Gold, BOLD)
		text(card, class.Ultimate.Description, 12, K.Dim)
	end
	return state.Class ~= nil
end

local function gearPage(kind: "Weapons" | "Armors")
	local class = Classes.List[state.Class]
	local list = column(body, 0, 0.62)
	local heading = if kind == "Weapons" then "Choose your weapon" else "Choose your armor"
	text(list, string.upper(heading), 20, class.Color, HEADING)
	local sub = if kind == "Weapons"
		then "Each weapon plays differently. Your weapon has one gem socket for an enchantment."
		else class.ArmorWeight .. " armor. Each set trades protection for mobility differently."
	text(list, sub, 14, K.Dim)
	for i, gear in class[kind] do
		local chosen = if kind == "Weapons" then state.Weapon == gear.Id else state.Armor == gear.Id
		local card = optionCard(list, class.Color, chosen, i + 2, function()
			if kind == "Weapons" then
				state.Weapon = gear.Id
			else
				state.Armor = gear.Id
			end
			saveLoadout()
			pages.redraw()
		end)
		card.Size = UDim2.new(1, 0, 0, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		UiKit.list(card, 4)
		text(card, gear.Name, 18, K.Text, BOLD)
		text(card, string.upper(gear.Style), 12, class.Color, BOLD)
		text(card, gear.Description, 14, K.Dim)
		if gear.Attack then
			text(card, AbilitiesUI.attackSummary(gear.Attack), 12, class.Color, BOLD)
		end
		text(card, gear.Passive.Name .. ": " .. gear.Passive.Text, 13, K.Text)
		text(card, modsText(gear.Mods), 13, K.Gold, BOLD)
	end
	local side = column(body, 0.62, 0.38, 8)
	local spacer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 300) }, side)
	showPreview(0.62, 0, 300)
	spacer.LayoutOrder = 0
	text(side, "YOUR STATS", 11, K.Dim, BOLD).LayoutOrder = 1
	local bars = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, side)
	UiKit.list(bars, 4)
	statBars(bars, Classes.stats(state.Class, state.Weapon, state.Armor), class.Color)
	return true
end

pages[3] = function()
	return gearPage("Weapons")
end

pages[4] = function()
	return gearPage("Armors")
end

-- Starter gems: three reels that spin and land on your gems.
local function gemReel(parent: Instance, order: number): (Frame, (any) -> (), () -> ())
	local reel = new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 26, 30), LayoutOrder = order }, parent)
	UiKit.round(reel, 10)
	local stroke = new("UIStroke", { Color = K.Accent, Transparency = 0.6, Thickness = 1.5 }, reel)
	local stage = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 170),
		ClipsDescendants = true,
	}, reel)
	UiKit.round(stage, 8)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(74, 84, 100), Color3.fromRGB(16, 20, 26)) },
		stage
	)
	GemArt.backdrop(stage)
	local info = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 188), Size = UDim2.new(1, -24, 1, -196) },
		reel
	)
	UiKit.list(info, 4)
	local title = text(info, "?", 16, K.Text, BOLD)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local detail = text(info, "", 13, K.Dim)
	detail.TextXAlignment = Enum.TextXAlignment.Center

	local spinning = false
	local function spin()
		spinning = true
		task.spawn(function()
			while spinning do
				local element = GemConfig.Elements[math.random(1, 4)]
				local shade = GemConfig.Shades[element][math.random(1, 3)]
				stage.BackgroundColor3 = shade.Color
				title.Text = shade.Name
				task.wait(0.07)
			end
		end)
	end
	local function land(gem)
		spinning = false
		stage.BackgroundColor3 = Color3.new(1, 1, 1)
		GemArt.viewport(stage, gem, true)
		local tierColor = GemConfig.TierColors[gem.Tier]
		stroke.Color = tierColor
		stroke.Transparency = 0
		stroke.Thickness = 3
		title.Text = GemConfig.shade(gem).Name
		title.TextColor3 = K.Text
		detail.Text = string.format(
			"%s %s\nSize %d  |  Clarity %d  |  Cut %d\nWorth %d coins",
			string.upper(GemConfig.TierLabels[gem.Tier]),
			string.upper(gem.Element),
			gem.Size,
			gem.Clarity,
			gem.Cut or 0,
			GemConfig.value(gem)
		)
		detail.TextColor3 = tierColor
		local pop = new("UIScale", { Scale = 1.12 }, reel)
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	return reel, land, spin
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

pages[5] = function()
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70) }, body)
	UiKit.list(top, 4)
	text(top, "YOUR STARTER GEMS", 22, K.Accent, HEADING)
	text(
		top,
		"Every new arrival gets three gems, already cut and ready to use. Spin to see what fortune gives you: at least one is guaranteed Uncommon or better.",
		14,
		K.Dim
	)
	local reels = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -140) },
		body
	)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -10, 1, 0),
		CellPadding = UDim2.fromOffset(15, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, reels)
	local landers, spinners = {}, {}
	for i = 1, 3 do
		local _, land, spin = gemReel(reels, i)
		landers[i], spinners[i] = land, spin
	end

	local existing = gemsFrom("StarterSpin")
	if GemClient.Profile.Intro.Spun and #existing > 0 then
		for i, gem in existing do
			if landers[i] then
				landers[i](gem)
			end
		end
		return true
	end

	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(200, 42),
	}, body)
	local spinButton
	spinButton = button(actions, "SPIN!", true, function()
		if busy then
			return
		end
		busy = true
		spinButton.Visible = false
		for _, spin in spinners do
			spin()
		end
		task.spawn(function()
			local result = GemClient.request("StarterSpin")
			task.wait(1.2)
			if result.Ok then
				for i, gem in result.Gems do
					task.wait(0.6)
					landers[i](gem)
				end
				nextButton.Visible = true
			else
				UiKit.toast(result.Message, K.Bad)
			end
			busy = false
		end)
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

pages[6] = function()
	local left = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.38, 0, 1, 0) }, body)
	local right = column(body, 0.38, 0.62, 8)
	right.Position = UDim2.new(0.38, 16, 0, 0)
	right.Size = UDim2.new(0.62, -16, 1, 0)

	local stage = new(
		"Frame",
		{ BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 300), ClipsDescendants = true },
		left
	)
	UiKit.round(stage, 10)
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(74, 84, 100), Color3.fromRGB(16, 20, 26)) },
		stage
	)
	GemArt.backdrop(stage)
	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 312),
		Size = UDim2.new(1, 0, 1, -312),
	}, left)
	UiKit.list(info, 8).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local caption = text(info, "", 17, K.Text, BOLD)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.LayoutOrder = 1
	local valueLine = text(info, "", 15, K.Gold, BOLD)
	valueLine.TextXAlignment = Enum.TextXAlignment.Center
	valueLine.LayoutOrder = 2
	local status = text(info, "", 13, K.Dim)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.LayoutOrder = 3
	local actions = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 4 }, info)
	UiKit.list(actions, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center

	text(right, "GEM SCHOOL", 22, K.Accent, HEADING)
	text(
		right,
		"Ilsa, the town's Master Gemcutter, hands you a rough stone to practise on. Here's what makes a gem:",
		14,
		K.Dim
	)
	for _, help in PROPERTY_HELP do
		text(right, help[1], 13, K.Accent, BOLD)
		text(right, help[2], 14, K.Text)
	end
	text(right, "WHERE YOUR GEMS GO", 13, K.Accent, BOLD)
	for _, line in
		{
			"Mining Guild (north road): Garrick gives free daily mines in the quarry, and sells rough stones.",
			"Gem Cutter (north road, by the Mining Guild): Ilsa cuts rough stones by hand for free, or with lasers for coins.",
			"Crafting Hall (north road): sell stones to Hilde for Guild Marks, buy materials, and have Borin forge your gear.",
			"Marketplace (town square): Tamsin's board lists gems for trade between players.",
			"Arcanum (east road): Vey sockets gems into your weapon and armor to enchant them.",
			"Arena (west road): train on dummies; beyond the south gate, crystal monsters drop stones and coins.",
		}
	do
		text(right, line, 14, K.Text)
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
		local cut = if gem.Cut then "Cut " .. gem.Cut else "Rough"
		valueLine.Text = string.format(
			"Size %d  |  Clarity %d  |  %s\nWorth %d coins",
			gem.Size,
			gem.Clarity,
			cut,
			GemConfig.value(gem)
		)
	end

	local function cutButton()
		for _, child in actions:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		if stone and stone.Cut then
			status.Text = "Cut! Press NEXT to enchant your weapon."
			status.TextColor3 = K.Accent
			nextButton.Visible = true
			return
		end
		status.Text = "Rough stones are worth half. Cut it to see it shine."
		status.TextColor3 = K.Dim
		button(actions, "CUT IT NOW", true, function()
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
								K.Gold
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
			status.Text = "You can cut it later at Ilsa's. Press NEXT."
			nextButton.Visible = true
		end)
	end

	task.spawn(function()
		local existing = gemsFrom("FirstStone")[1]
		if existing then
			show(existing)
		else
			local result = GemClient.request("FirstStone")
			if result.Ok and result.Gem then
				show(result.Gem)
			end
		end
		cutButton()
	end)
	return false
end

pages[7] = function()
	local class = Classes.List[state.Class]
	local weapon = Classes.weapon(state.Class, state.Weapon)
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 74) }, body)
	UiKit.list(top, 4)
	text(top, "ENCHANT YOUR WEAPON", 22, class.Color, HEADING)
	text(
		top,
		string.format(
			"Your %s has one gem socket. A socketed gem adds its element to your hits, raises your stats and wreathes the weapon in its element. Pick one of your cut gems (you can swap it later at the Arcanum).",
			weapon and weapon.Name or "weapon"
		),
		14,
		K.Dim
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
				UiKit.toast(result.Message, if result.Ok then K.Gold else K.Bad)
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
		text(info, GemConfig.shade(gem).Name, 13, K.Text, BOLD)
		text(
			info,
			string.upper(gem.Element) .. (if isSocketed then "  |  SOCKETED" else ""),
			11,
			GemConfig.ElementColors[gem.Element],
			BOLD
		)
		text(info, GemConfig.ElementEffects[gem.Element], 11, K.Dim)
	end
	return socketed ~= nil
end

pages[8] = function()
	local class = Classes.List[state.Class]
	local weapon = Classes.weapon(state.Class, state.Weapon)
	local armor = Classes.armor(state.Class, state.Armor)
	local gem = GemClient.Profile.Character and GemClient.Profile.Character.WeaponGem
	local sheet = column(body, 0, 0.6, 8)
	text(sheet, "READY, " .. string.upper(player.DisplayName), 22, class.Color, HEADING)
	text(sheet, string.format("%s  |  %s", class.Name, class.Role), 15, K.Text, BOLD)
	text(sheet, class.Resource, 13, K.Dim)
	text(sheet, "GEAR", 12, K.Accent, BOLD)
	text(
		sheet,
		string.format("Weapon: %s (%s)", weapon and weapon.Name or "?", weapon and weapon.Style or ""),
		14,
		K.Text
	)
	if gem then
		text(
			sheet,
			string.format("   Enchanted with %s: %s", GemConfig.shade(gem).Name, GemConfig.ElementEffects[gem.Element]),
			13,
			GemConfig.ElementColors[gem.Element]
		)
	end
	text(sheet, string.format("Armor: %s (%s)", armor and armor.Name or "?", armor and armor.Style or ""), 14, K.Text)
	text(sheet, "ABILITIES  (press K in game to swap; 6 to choose from)", 12, K.Accent, BOLD)
	for i, ability in Classes.loadout(class.Id, nil) do
		text(sheet, string.format("[%s] %s: %s", Classes.AbilityKeys[i], ability.Name, ability.Description), 13, K.Text)
	end
	text(
		sheet,
		string.format("[%s] %s: %s", Classes.UltimateKey, class.Ultimate.Name, class.Ultimate.Description),
		13,
		K.Gold
	)
	text(sheet, "AT LEVEL 5, CHOOSE A SPECIALIZATION", 12, K.Accent, BOLD)
	for _, spec in class.Specs do
		text(sheet, string.format("%s (%s): unlocks %s", spec.Name, spec.Style, spec.Signature.Name), 13, K.Dim)
	end
	text(
		sheet,
		"Left click to attack. Practise on dummies in the Arena (west road), then hunt crystal monsters outside the south gate.",
		12,
		K.Dim
	)

	local side = column(body, 0.6, 0.4, 6)
	new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 330) }, side)
	showPreview(0.6, 0, 330)
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
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		introOpen = false
		if controls then
			controls:Enable()
		end
		setHud(true)
		gui:Destroy()
		UiKit.toast("Welcome to Gemsoul! Talk to Garrick at the Mining Guild, up the north road.", K.Accent)
	end)
end

function pages.redraw()
	clearBody()
	local step = state.Step
	stepLabel.Text = string.format("STEP %d OF %d  |  %s", step, #STEPS, string.upper(STEPS[step]))
	for i, cell in progressCells do
		cell.BackgroundColor3 = if i <= step then K.Accent else K.Row
	end
	-- Hidden until the page allows it. Some pages reveal it themselves once
	-- you've done something (spun, cut), possibly before they return.
	nextButton.Visible = false
	-- If a page fails, say so on screen rather than leaving it blank.
	local ok, result = pcall(pages[step])
	if not ok then
		warn("[Intro] Page " .. step .. " failed: " .. tostring(result))
		text(body, "Something went wrong on this page:\n" .. tostring(result), 14, K.Bad)
	end
	backButton.Visible = step > 1 and step ~= 6
	if not ok or result then
		nextButton.Visible = true
	end
	nextButton.Text = if step == 1 then "BEGIN" elseif step == #STEPS then "ENTER GEMSOUL" else "NEXT"
end

local function go(delta: number)
	if busy then
		return
	end
	local target = math.clamp(state.Step + delta, 1, #STEPS)
	-- Can't go back past the one-time gem steps.
	if delta < 0 and state.Step >= 6 and target < 6 then
		return
	end
	state.Step = target
	pages.redraw()
end

UiKit.list(footer, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Right
backButton = button(footer, "Back", false, function()
	go(-1)
end)
nextButton = button(footer, "NEXT", true, function()
	if state.Step == #STEPS then
		finish()
	elseif state.Step == 4 then
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

-- The enchant page lists gems from the profile, so redraw it when that changes.
GemClient.Changed:Connect(function()
	if gui.Parent and state.Step == 7 and not busy then
		pages.redraw()
	end
end)

pages.redraw()
