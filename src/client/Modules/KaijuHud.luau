--[[
	Your mini kaiju on screen (KaijuServer and KaijuWilds run them; see
	docs/kaiju.md). Only in the Outpost.

	  The kaiju card  its portrait (the model itself), name and level, health
	                  and EXP, its E lighting up when it's ready, and RECALL
	                  (back to you for a moment) and HUNT (your kit out to
	                  fight beside it; 1 or HUNT again puts it away). Tap the
	                  card for the kaiju panel. Knocked out: when it's back.
	                  Computer: bottom left. Phone: under your level and
	                  coins, and at the top right while you hunt (the fight's
	                  foe list has the top left then).
	  TAME            beside the card when a wild kaiju near you is down to
	                  half its health (it glows gold then: KaijuTaming): the
	                  chance now, and the tries left. It casts the tame
	                  (KaijuTaming's bar), hidden while that's under way.
	  Challenge       a wild kaiju's prompt (hold E beside it): it leaves you
	                  and your kaiju alone till you start on it, here or by
	                  hitting it while you hunt.
	  The panel       the one out (stats, Gemsoul and its E), your others to
	                  send out instead, and FEED: stones from your pouch with
	                  the EXP each gives it (Shared.Kaiju.feedExp).
	  Wild nameplates the server's health bar over wild kaiju and moon bugs
	                  while you aren't hunting (FoeBars draws them while you are).

	  KaijuHud.start()   once, from Lobby.client
	  KaijuHud.open()    the panel
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local Spar = require(ReplicatedStorage.Shared.Spar)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local KaijuTaming = require(script.Parent.KaijuTaming)
local ChatFeed = require(script.Parent.ChatFeed)
local MobileLayout = require(script.Parent.MobileLayout)
local OutpostScene = require(script.Parent.OutpostScene)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local KaijuHud = {}

local INK = Color3.fromRGB(10, 12, 22)
local HEALTH = Color3.fromRGB(96, 214, 120)
local EXP = Color3.fromRGB(176, 132, 255)
local TAME_RANGE = Kaiju.Tame.Range

local function elementColor(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or P.Gold
end

local function touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or P.Text,
		Font = font or IronUi.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function bar(parent: Instance, color: Color3): (Frame, Frame)
	local back = new("Frame", { BackgroundColor3 = Color3.fromRGB(28, 32, 46) }, parent)
	UiKit.round(back, 3)
	local fill = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1) }, back)
	UiKit.round(fill, 3)
	return back, fill
end

local function smallButton(parent: Instance, text: string, color: Color3): TextButton
	local b = new("TextButton", {
		Text = text,
		TextSize = 12,
		Font = IronUi.Heading,
		TextColor3 = P.Text,
		AutoButtonColor = true,
		BackgroundColor3 = color:Lerp(INK, 0.55),
	}, parent)
	UiKit.round(b, 6)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.35 }, b)
	return b
end

-- A model in a ViewportFrame, framed from the front quarter.
local function portrait(frame: ViewportFrame, model: Model?)
	-- (Only the last model and its camera: the frame's corner and chip stay.)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	if not model then
		return
	end
	model.Parent = frame
	local camera = Instance.new("Camera")
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(reach * 0.9, reach * 0.35, -reach * 1.25), cf.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
end

-- The card -------------------------------------------------------------------------------------------------

local gui = UiKit.gui("KaijuHud", 6)
gui.Enabled = false

local card = new("TextButton", {
	Name = "KaijuCard",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.12,
	Size = UDim2.fromOffset(250, 60),
}, gui)
UiKit.round(card, 10)
local cardStroke = new("UIStroke", { Color = P.Edge, Thickness = 1.2, Transparency = 0.2 }, card)

local view = new("ViewportFrame", {
	BackgroundColor3 = Color3.fromRGB(20, 24, 38),
	Position = UDim2.fromOffset(5, 5),
	Size = UDim2.fromOffset(50, 50),
	Ambient = Color3.fromRGB(170, 170, 185),
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(-0.4, -1, 0.6),
}, card)
UiKit.round(view, 8)
-- Its E: a chip on the portrait's corner that fills as it readies.
local chip = new("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 3, 1, 3),
	Size = UDim2.fromOffset(20, 20),
	BackgroundColor3 = INK,
	ZIndex = 3,
}, view)
UiKit.round(chip, 10)
local chipStroke = new("UIStroke", { Color = P.Gold, Thickness = 1.5 }, chip)
local chipFill = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = P.Gold,
	BackgroundTransparency = 0.5,
	ZIndex = 3,
}, chip)
UiKit.round(chipFill, 10)
local chipText = label(chip, "E", 11, P.Text)
chipText.Size = UDim2.fromScale(1, 1)
chipText.TextXAlignment = Enum.TextXAlignment.Center
chipText.ZIndex = 4

local nameText = label(card, "", 13)
nameText.Position, nameText.Size = UDim2.fromOffset(62, 5), UDim2.new(1, -140, 0, 16)
local levelText = label(card, "", 11, P.Dim, IronUi.Bold)
levelText.Position, levelText.Size = UDim2.fromOffset(62, 21), UDim2.new(1, -140, 0, 13)
local healthBack, healthFill = bar(card, HEALTH)
healthBack.Position, healthBack.Size = UDim2.fromOffset(62, 37), UDim2.new(1, -140, 0, 7)
local expBack, expFill = bar(card, EXP)
expBack.Position, expBack.Size = UDim2.fromOffset(62, 48), UDim2.new(1, -140, 0, 4)

local recall = smallButton(card, "RECALL", Color3.fromRGB(120, 200, 255))
recall.AnchorPoint = Vector2.new(1, 0)
recall.Position, recall.Size = UDim2.new(1, -6, 0, 6), UDim2.fromOffset(68, 22)
local hunt = smallButton(card, "HUNT", Color3.fromRGB(255, 92, 76))
hunt.AnchorPoint = Vector2.new(1, 1)
hunt.Position, hunt.Size = UDim2.new(1, -6, 1, -6), UDim2.fromOffset(68, 22)

-- Knocked out: a veil over the card (not HUNT) with when it's back.
local downVeil = new("Frame", {
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.04,
	Size = UDim2.new(1, -80, 1, 0),
	Visible = false,
	ZIndex = 5,
}, card)
UiKit.round(downVeil, 10)
local downText = label(downVeil, "", 12, P.Dim)
downText.Position, downText.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -12, 1, 0)
downText.TextWrapped = true
downText.ZIndex = 6

-- TAME: beside the card, when there's a wild kaiju to tame.
local tame = new("TextButton", {
	Name = "Tame",
	Text = "",
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(70, 52, 14),
	Size = UDim2.fromOffset(104, 60),
	Visible = false,
}, gui)
UiKit.round(tame, 10)
new("UIStroke", { Color = P.Gold, Thickness = 2 }, tame)
local tameTitle = label(tame, "TAME", 18, P.Gold, Enum.Font.GothamBlack)
tameTitle.Position, tameTitle.Size = UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 22)
tameTitle.TextXAlignment = Enum.TextXAlignment.Center
local tameOdds = label(tame, "", 11, P.Text, IronUi.Bold)
tameOdds.Position, tameOdds.Size = UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 13)
tameOdds.TextXAlignment = Enum.TextXAlignment.Center
local tameTries = label(tame, "", 10, P.Dim, IronUi.Body)
tameTries.Position, tameTries.Size = UDim2.fromOffset(0, 43), UDim2.new(1, 0, 0, 12)
tameTries.TextXAlignment = Enum.TextXAlignment.Center

-- Where the card and TAME go: see the header.
local function layout()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 then
		return
	end
	local phone = UiKit.short()
	local hunting = Spar.hunting(player)
	-- (Beside the chat box's CHAT button on a small keyboard screen, while it's on.)
	local spot = MobileLayout.kaiju(UserInputService.KeyboardEnabled and not ChatFeed.Enabled)
	local w, h = if phone then spot.W else 260, if phone then spot.H else 62
	card.Size = UDim2.fromOffset(w, h)
	tame.Size = UDim2.fromOffset(if phone then spot.TameW else 104, h)
	local x, y
	if not phone then
		x, y = 24, screen.Y - 24 - h
		tame.Position = UDim2.fromOffset(x, y - h - 8)
	elseif hunting then
		x, y = screen.X - 12 - w, 12
		tame.Position = UDim2.fromOffset(screen.X - 12 - tame.Size.X.Offset, y + h + 6)
	else
		x, y = spot.X, spot.Y
		tame.Position = UDim2.fromOffset(spot.TameX, y)
	end
	card.Position = UDim2.fromOffset(x, y)
	view.Size = UDim2.fromOffset(h - 10, h - 10)
	local left = h + 2
	nameText.Position = UDim2.fromOffset(left, if phone then 4 else 5)
	levelText.Position = UDim2.fromOffset(left, if phone then 19 else 21)
	healthBack.Position = UDim2.fromOffset(left, h - (if phone then 18 else 22))
	expBack.Position = UDim2.fromOffset(left, h - (if phone then 9 else 11))
	for _, item in { nameText, levelText, healthBack, expBack } do
		item.Size = UDim2.new(1, -(left + 80), 0, item.Size.Y.Offset)
	end
	recall.Size = UDim2.fromOffset(68, if phone then 20 else 22)
	hunt.Size = recall.Size
	downText.Position, downText.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -12, 1, 0)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
player:GetAttributeChangedSignal("Hunt"):Connect(layout)

-- State ------------------------------------------------------------------------------------------------------

local shownRecord = nil -- the record the portrait shows (Id .. Level)
local pet: Model? = nil -- your kaiju in the world

local function roster()
	local profile = GemClient.Profile
	return profile and profile.Kaiju
end

local function active()
	return Kaiju.active(roster())
end

local function findPet(): Model?
	if pet and pet.Parent then
		return pet
	end
	local folder = workspace:FindFirstChild("Kaiju")
	for _, model in if folder then folder:GetChildren() else {} do
		if model:GetAttribute("KaijuOwner") == player.UserId then
			pet = model
			return model
		end
	end
	pet = nil
	return nil
end

local function showPortrait(record)
	local key = if record then record.Id .. record.Element .. record.Species else ""
	if key == shownRecord then
		return
	end
	shownRecord = key
	if not record then
		portrait(view, nil)
		return
	end
	local model = KaijuModels.build(record.Species, record.Element)
	portrait(view, model)
	local color = elementColor(record.Element)
	cardStroke.Color = color:Lerp(P.Edge, 0.4)
	chipStroke.Color = color
	chipFill.BackgroundColor3 = color
end

-- The wild kaiju you could try to tame now: the weakest near you.
local function tameTarget(): (Model?, number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local enemies = workspace:FindFirstChild("Enemies")
	if not root or not enemies then
		return nil, 0
	end
	local best, bestChance = nil, 0
	for _, model in enemies:GetChildren() do
		if model:IsA("Model") and KaijuTaming.ready(model) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local body = model.PrimaryPart
			if humanoid and body and (body.CFrame.Position - root.CFrame.Position).Magnitude <= TAME_RANGE then
				local chance = Kaiju.tameChance(humanoid.Health, humanoid.MaxHealth)
				if chance > bestChance then
					best, bestChance = model, chance
				end
			end
		end
	end
	return best, bestChance
end

local tameModel: Model? = nil
local wantShown = false

local function refresh()
	local record = active()
	local inOutpost = OutpostScene.isActive() and player:GetAttribute("Outpost") == true
	local blocked = player.PlayerGui:FindFirstChild("Intro") ~= nil
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	local menu = dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled
	wantShown = record ~= nil and inOutpost and not blocked and not menu
	gui.Enabled = wantShown
	if not wantShown then
		return
	end
	showPortrait(record)
	local model = findPet()
	-- (Its kind in its element's colour: the full name is the panel's.)
	local species = Kaiju.species(record.Species)
	nameText.Text = if species then species.Name else Kaiju.title(record)
	nameText.TextColor3 = elementColor(record.Element):Lerp(P.Text, 0.35)
	local level = (model and model:GetAttribute("KaijuLevel")) or record.Level
	local exp = (model and model:GetAttribute("KaijuExp")) or record.Exp or 0
	local need = Kaiju.expToNext(level)
	levelText.Text = if need == math.huge
		then string.format("Lv %d · MAX", level)
		else string.format("Lv %d · %d/%d", level, exp, need)
	expFill.Size = UDim2.fromScale(if need == math.huge then 1 else math.clamp(exp / need, 0, 1), 1)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	healthFill.Size =
		UDim2.fromScale(if humanoid then math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1) else 1, 1)
	-- Its E: full once AbilityEvery has passed since it last cast.
	local castAt = model and model:GetAttribute("KaijuAbilityAt")
	local since = if castAt then workspace:GetServerTimeNow() - castAt else math.huge
	chipFill.Size = UDim2.fromScale(1, math.clamp(since / Kaiju.AbilityEvery, 0, 1))
	chipText.TextColor3 = if since >= Kaiju.AbilityEvery then INK else P.Text
	-- Knocked out.
	local back = player:GetAttribute("KaijuDownUntil")
	local wait = if type(back) == "number" then back - workspace:GetServerTimeNow() else 0
	downVeil.Visible = wait > 0
	if wait > 0 then
		downText.Text = string.format("Knocked out: back in its Gemsoul for %ds", math.ceil(wait))
	end
	hunt.Text = if Spar.hunting(player) then "STOP" else "HUNT"
	recall.Visible = model ~= nil
	-- TAME.
	local target, chance = tameTarget()
	tameModel = target
	tame.Visible = target ~= nil and not KaijuTaming.casting()
	if target then
		tameOdds.Text = string.format("%d%% chance", math.floor(chance * 100 + 0.5))
		local left = Kaiju.TameTries - (target:GetAttribute("KaijuTries") or 0)
		tameTries.Text = string.format("%d tr%s left", left, if left == 1 then "y" else "ies")
	end
end

-- Wild nameplates: the server's own bar while you're not hunting.
local function wildPlates()
	local enemies = workspace:FindFirstChild("Enemies")
	local show = not Spar.hunting(player) and wantShown
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:GetAttribute("KaijuWild") or model:GetAttribute("MoonBug") then
			local root = model.PrimaryPart
			local board = root and root:FindFirstChild("HealthBar")
			if board and board:IsA("BillboardGui") and board.Enabled ~= show then
				board.Enabled = show
			end
		end
	end
end

-- Actions ------------------------------------------------------------------------------------------------------

local busy = false
local function act(fn: () -> ())
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, err = pcall(fn)
		busy = false
		if not ok then
			warn("[KaijuHud]", err)
		end
	end)
end

local function say(result)
	if result and result.Message and result.Message ~= "" then
		UiKit.toast(result.Message, if result.Ok then P.Good else P.Gold)
	end
end

recall.Activated:Connect(function()
	act(function()
		say(GemClient.request("KaijuRecall"))
	end)
end)
hunt.Activated:Connect(function()
	act(function()
		say(GemClient.request("Hunt", not Spar.hunting(player)))
	end)
end)
-- A wild kaiju's Challenge prompt: your kaiju goes in (KaijuWilds).
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player or prompt:GetAttribute("PromptKind") ~= "KaijuChallenge" then
		return
	end
	local model = prompt.Parent and prompt.Parent.Parent
	act(function()
		say(GemClient.request("KaijuChallenge", model))
	end)
end)
tame.Activated:Connect(function()
	local target = tameModel
	if not target then
		return
	end
	act(function()
		local result = GemClient.request("KaijuTame", target)
		if result and result.Casting then
			-- The cast is on: its bar shows how it goes (KaijuTaming).
			KaijuTaming.cast(target, result.Chance or 0, result.Seconds or Kaiju.Tame.Cast)
			tame.Visible = false
		else
			say(result)
		end
	end)
end)

-- The panel -------------------------------------------------------------------------------------------------------

local W, H = 760, 470
local window = IronUi.window("KaijuPanel", 11, W, H, "K", P.Gold)
window.Title.Text = "YOUR KAIJU"
window.Subtitle.Text = "They fight beside you in the Outpost. Feed them stones to grow."
window.Close.Activated:Connect(function()
	window.Gui.Enabled = false
end)
window.Shade.Activated:Connect(function()
	window.Gui.Enabled = false
end)

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 78),
	Size = UDim2.new(1, -40, 1, -96),
}, window.Panel)

-- Left: the one out.
local hero = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(0, 300, 1, 0) }, body)
UiKit.round(hero, 10)
local heroView = new("ViewportFrame", {
	BackgroundColor3 = Color3.fromRGB(16, 20, 32),
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(1, -20, 0, 150),
	Ambient = Color3.fromRGB(170, 170, 185),
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(-0.4, -1, 0.6),
}, hero)
UiKit.round(heroView, 8)
local heroName = label(hero, "", 18, P.Text, Enum.Font.GothamBlack)
heroName.Position, heroName.Size = UDim2.fromOffset(12, 166), UDim2.new(1, -24, 0, 22)
local heroBlurb = label(hero, "", 11, P.Dim, IronUi.Body)
heroBlurb.Position, heroBlurb.Size = UDim2.fromOffset(12, 188), UDim2.new(1, -24, 0, 28)
heroBlurb.TextWrapped = true
heroBlurb.TextYAlignment = Enum.TextYAlignment.Top
local heroStats = label(hero, "", 12, P.Text, IronUi.Bold)
heroStats.Position, heroStats.Size = UDim2.fromOffset(12, 220), UDim2.new(1, -24, 0, 34)
heroStats.TextWrapped = true
heroStats.TextYAlignment = Enum.TextYAlignment.Top
local soulBox = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(14, 17, 28),
	Position = UDim2.fromOffset(10, 258),
	Size = UDim2.new(1, -20, 1, -268),
}, hero)
UiKit.round(soulBox, 8)
local soulTitle = label(soulBox, "GEMSOUL", 11, P.Gold)
soulTitle.Position, soulTitle.Size = UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 14)
local soulText = label(soulBox, "", 11, P.Text, IronUi.Body)
soulText.Position, soulText.Size = UDim2.fromOffset(10, 22), UDim2.new(1, -20, 1, -26)
soulText.TextWrapped = true
soulText.TextYAlignment = Enum.TextYAlignment.Top

-- Right: tabs for your kaiju and feeding.
local right = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(312, 0),
	Size = UDim2.new(1, -312, 1, 0),
}, body)
local tabRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) }, right)
UiKit.list(tabRow, 8, true)
local listFrame = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, 0, 1, -100),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, right)
UiKit.list(listFrame, 6)
local footer = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 52),
}, right)
local footerText = label(footer, "", 11, P.Dim, IronUi.Body)
footerText.Size = UDim2.new(1, -150, 1, 0)
footerText.TextWrapped = true
local feedButton = smallButton(footer, "FEED", P.Good)
feedButton.AnchorPoint = Vector2.new(1, 0.5)
feedButton.Position, feedButton.Size = UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(140, 38)
feedButton.TextSize = 15
-- One tap picks a mouthful of spare Commons (what mining mostly pays).
local commonsButton = smallButton(footer, "PICK COMMONS", P.Teal)
commonsButton.AnchorPoint = Vector2.new(1, 0.5)
commonsButton.Position, commonsButton.Size = UDim2.new(1, -150, 0.5, 0), UDim2.fromOffset(122, 38)
commonsButton.TextSize = 12

local tab = "Team"
local picked: { [string]: boolean } = {}
local tabButtons = {}
local drawPanel

for _, entry in { { "Team", "YOUR KAIJU" }, { "Feed", "FEED" } } do
	local b = smallButton(tabRow, entry[2], P.Gold)
	b.Size = UDim2.fromOffset(130, 30)
	b.Activated:Connect(function()
		tab = entry[1]
		table.clear(picked)
		drawPanel()
	end)
	tabButtons[entry[1]] = b
end

local function row(height: number): Frame
	local frame = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, -8, 0, height) }, listFrame)
	UiKit.round(frame, 8)
	return frame
end

local function moveName(id: string?): string
	local move = id and GemTraits.Moves[id]
	return if move then move.Name else "?"
end

-- The stones it would eat, best EXP first, with what each gives.
local function feedList(record)
	local list = {}
	for _, gem in (GemClient.Profile and GemClient.Profile.Gems) or {} do
		table.insert(list, { Gem = gem, Exp = Kaiju.feedExp(gem, record) })
	end
	table.sort(list, function(a, b)
		return if a.Exp ~= b.Exp then a.Exp > b.Exp else (a.Gem.Id < b.Gem.Id)
	end)
	return list
end

function drawPanel()
	local data = roster()
	local record = Kaiju.active(data)
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == tab then P.Gold:Lerp(INK, 0.3) else P.Gold:Lerp(INK, 0.75)
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- The one out.
	if record then
		local model = KaijuModels.build(record.Species, record.Element)
		portrait(heroView, model)
		local species = Kaiju.species(record.Species)
		heroName.Text = string.format("%s · Lv %d", Kaiju.title(record), record.Level)
		heroName.TextColor3 = elementColor(record.Element)
		heroBlurb.Text = if species then species.Blurb else ""
		local stats = Kaiju.stats(record.Species, record.Level, record.Soul and record.Soul.Tier)
		heroStats.Text = string.format(
			"Health %d  ·  Damage %d  ·  Speed %d\nEXP %d / %s",
			stats.Health,
			math.floor(stats.Damage + 0.5),
			stats.Speed,
			record.Exp or 0,
			if Kaiju.expToNext(record.Level) == math.huge then "MAX" else tostring(Kaiju.expToNext(record.Level))
		)
		local soul = record.Soul
		local ability = Kaiju.ability(soul)
		local move = ability and GemTraits.Moves[ability]
		soulText.Text = string.format(
			"%s\nE: %s\n%s\nQ and R are sealed: only its E wakes, wherever it's socketed.",
			if soul then GemConfig.displayName(soul) else "?",
			moveName(ability),
			if move and move.Description then move.Description else ""
		)
	else
		portrait(heroView, nil)
		heroName.Text = "No kaiju yet"
		heroBlurb.Text = "Visit the Outpost: your first kaiju is waiting there."
		heroStats.Text, soulText.Text = "", ""
	end
	if tab == "Team" then
		feedButton.Visible, commonsButton.Visible = false, false
		footerText.Size = UDim2.fromScale(1, 1)
		footerText.Text = string.format(
			"%d of %d kaiju kept. Tame more in the far quarry: wear one down to half health without killing it.",
			Kaiju.count(data),
			Kaiju.MaxOwned
		)
		local ids = {}
		for id in (data and data.List) or {} do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local ra, rb = data.List[a], data.List[b]
			return if ra.Level ~= rb.Level then ra.Level > rb.Level else a < b
		end)
		for _, id in ids do
			local other = data.List[id]
			local frame = row(48)
			local stripe = new("Frame", {
				BackgroundColor3 = elementColor(other.Element),
				Size = UDim2.new(0, 4, 1, 0),
			}, frame)
			UiKit.round(stripe, 2)
			local title = label(frame, string.format("%s · Lv %d", Kaiju.title(other), other.Level), 14)
			title.Position, title.Size = UDim2.fromOffset(14, 5), UDim2.new(1, -140, 0, 18)
			local sub = label(frame, "E: " .. moveName(Kaiju.ability(other.Soul)), 11, P.Dim, IronUi.Body)
			sub.Position, sub.Size = UDim2.fromOffset(14, 25), UDim2.new(1, -140, 0, 14)
			if id == data.Active then
				local out = label(frame, "OUT", 12, P.Good)
				out.AnchorPoint = Vector2.new(1, 0.5)
				out.Position, out.Size = UDim2.new(1, -16, 0.5, 0), UDim2.fromOffset(60, 20)
				out.TextXAlignment = Enum.TextXAlignment.Right
			else
				local send = smallButton(frame, "SEND OUT", P.Teal)
				send.AnchorPoint = Vector2.new(1, 0.5)
				send.Position, send.Size = UDim2.new(1, -10, 0.5, 0), UDim2.fromOffset(100, 30)
				send.Activated:Connect(function()
					act(function()
						say(GemClient.request("KaijuActive", id))
						drawPanel()
					end)
				end)
			end
		end
		return
	end
	-- Feed.
	feedButton.Visible = true
	commonsButton.Visible = record ~= nil and #GemInventory.spare(GemClient.Profile, "Common") > 0
	footerText.Size = UDim2.new(1, if commonsButton.Visible then -282 else -150, 1, 0)
	if not record then
		footerText.Text = "No kaiju out to feed."
		return
	end
	local total, count = 0, 0
	for _, entry in feedList(record) do
		local gem, exp = entry.Gem, entry.Exp
		local chosen = picked[gem.Id] == true
		if chosen then
			total += exp
			count += 1
		end
		local frame = row(38)
		local b = new("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, frame)
		local tick = new("Frame", {
			BackgroundColor3 = if chosen then P.Good else Color3.fromRGB(28, 32, 46),
			Position = UDim2.fromOffset(10, 11),
			Size = UDim2.fromOffset(16, 16),
		}, frame)
		UiKit.round(tick, 4)
		local name = label(frame, GemConfig.displayName(gem), 13, elementColor(gem.Element))
		name.Position, name.Size = UDim2.fromOffset(36, 0), UDim2.new(1, -130, 1, 0)
		local worth = label(frame, string.format("+%d EXP", exp), 13, if exp > 0 then P.Gold else P.Dim)
		worth.AnchorPoint = Vector2.new(1, 0)
		worth.Position, worth.Size = UDim2.new(1, -12, 0, 0), UDim2.new(0, 90, 1, 0)
		worth.TextXAlignment = Enum.TextXAlignment.Right
		b.Activated:Connect(function()
			picked[gem.Id] = not picked[gem.Id] or nil
			drawPanel()
		end)
	end
	footerText.Text = if count > 0
		then string.format("%d stone%s: +%d EXP", count, if count == 1 then "" else "s", total)
		elseif commonsButton.Visible then "Pick stones to feed it, or a mouthful of Commons."
		else "Pick stones to feed it. Rarer ones keep their worth as it grows; its weakness element gives half."
end

commonsButton.Activated:Connect(function()
	table.clear(picked)
	for i, gem in GemInventory.spare(GemClient.Profile, "Common") do
		if i > Kaiju.FeedBatch then
			break
		end
		picked[gem.Id] = true
	end
	drawPanel()
end)

feedButton.Activated:Connect(function()
	local ids = {}
	for id in picked do
		table.insert(ids, id)
	end
	if #ids == 0 then
		return
	end
	act(function()
		local result = GemClient.request("KaijuFeed", ids)
		say(result)
		if result and result.Ok then
			table.clear(picked)
		end
	end)
end)

function KaijuHud.open()
	tab = "Team"
	table.clear(picked)
	drawPanel()
	window.Gui.Enabled = true
end

card.Activated:Connect(KaijuHud.open)

GemClient.Changed:Connect(function()
	if window.Gui.Enabled then
		-- (The pouch or the roster changed: what's picked may be gone.)
		local gems = {}
		for _, gem in (GemClient.Profile and GemClient.Profile.Gems) or {} do
			gems[gem.Id] = true
		end
		for id in picked do
			if not gems[id] then
				picked[id] = nil
			end
		end
		drawPanel()
	end
end)

local started = false
function KaijuHud.start()
	if started then
		return
	end
	started = true
	KaijuTaming.start()
	layout()
	local ok, err = pcall(refresh)
	if not ok then
		warn("[KaijuHud]", err)
	end
	local nextTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextTick then
			return
		end
		nextTick = now + 0.2
		local ok, err = pcall(refresh)
		if not ok then
			warn("[KaijuHud]", err)
		end
		pcall(wildPlates)
	end)
end

return KaijuHud
