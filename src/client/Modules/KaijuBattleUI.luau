--[[
	A kaiju battle, on screen (KaijuBattles runs it; Shared.KaijuBattle has
	the rules). Battles are fought downstairs in the Kaiju Arena, on a
	court (Client.KaijuPitClient has its pads and boards). Once both agree:

	  Formation  PLACE YOUR KAIJU, with the clock (KaijuBattle.FormationSeconds,
	             a bar draining under it). On the left the court from above:
	             your foe's half at the top (hidden till it starts), the
	             middle line, then your front row and your back row, nearest
	             you. On the right your kaiju, each on a card: drawn in 3D,
	             its name, level, what it does (FRONT LINE, SHOOTER), its
	             health and where it stands. Drag a card, or a kaiju already
	             on the court, onto a spot to put it there (onto another, they
	             swap); or tap one, then a spot. AUTO puts them back where
	             they start (the sturdy ones in front), READY (both ready
	             starts it now), LEAVE. The stake, if you're playing for one,
	             sits under the title. On the ground, both sides' places are
	             marked, yours lit where a kaiju stands.
	  Battle     a bar at the top: your kaiju's faces and health on the left,
	             your foe's on the right, the clock in the middle, LEAVE.
	  Over       VICTORY, DEFEAT or DRAW; the EXP your kaiju earned; YOUR
	             KAIJU ARE HEALED for the winner; what the stake came to.

	  KaijuBattleUI.start()       once (Lobby.client, with KaijuHud)
	  KaijuBattleUI.state()       the battle you're in, as last told (nil: none)
	  KaijuBattleUI.show(state)   draws `state` (the Social remote's)
	  KaijuBattleUI.tick()        the clock and the health bars
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local KaijuBattle = require(ReplicatedStorage.Shared.KaijuBattle)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local KaijuPit = require(ReplicatedStorage.Shared.KaijuPit)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local new = IronUi.new

local KaijuBattleUI = {}

local ORANGE = Color3.fromRGB(255, 132, 64)
local HAZARD = Color3.fromRGB(240, 178, 48)
local MINE = Color3.fromRGB(70, 160, 255) -- your side, the court's blue
local THEIRS = Color3.fromRGB(255, 84, 72) -- theirs, red
-- What each kind does in a formation (Shared.KaijuBattle.FrontKinds).
local ROLES = { Bulwark = "FRONT LINE", Razorback = "SHOOTER", Carapace = "FRONT LINE" }
local CELL_NAMES = {
	FrontLeft = "FRONT LEFT",
	FrontCentre = "FRONT MIDDLE",
	FrontRight = "FRONT RIGHT",
	BackLeft = "BACK LEFT",
	BackCentre = "BACK MIDDLE",
	BackRight = "BACK RIGHT",
}

local current = nil -- the state last told
local picked: string? = nil -- the kaiju tapped, to move
local hovered: string? = nil -- the place under a dragged kaiju

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function elementColor(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or P.Edge
end

local function line(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local label = IronUi.text(parent, value, size, color, font or IronUi.Bold)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	return label
end

local function button(parent: Instance, value: string, color: Color3, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Text = value,
		Font = IronUi.Heading,
		TextSize = 15,
		TextColor3 = P.Text,
		AutoButtonColor = true,
		BackgroundColor3 = color:Lerp(P.Frame, 0.55),
	}, parent)
	UiKit.round(b, 8)
	new("UIStroke", { Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
	return b
end

-- Portraits: each kaiju's model built once per place it's shown (`key`) and
-- kept, so redrawing doesn't rebuild them.
local built: { [string]: { Look: string, Model: Model } } = {}
local function modelFor(key: string, unit): Model?
	local look = tostring(unit.Species) .. "/" .. tostring(unit.Element)
	local entry = built[key]
	if entry and entry.Look == look then
		return entry.Model
	end
	if entry then
		entry.Model:Destroy()
	end
	local ok, model = pcall(function()
		return KaijuModels.forPortrait(KaijuModels.build(unit.Species, unit.Element))
	end)
	if not ok or not model then
		return nil
	end
	built[key] = { Look = look, Model = model }
	return model
end
local function viewport(parent: Instance, props): ViewportFrame
	local look = KaijuModels.Portrait
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Ambient, props.LightColor, props.LightDirection = look.Ambient, look.LightColor, look.LightDirection
	return new("ViewportFrame", props, parent)
end
-- A model in a ViewportFrame, framed from the front quarter (`close`: nearer).
local function portrait(frame: ViewportFrame, model: Model?, close: number?)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") and child ~= model then
			child.Parent = nil
		elseif child:IsA("Camera") then
			child:Destroy()
		end
	end
	if not model then
		return
	end
	model.Parent = frame
	local camera = Instance.new("Camera")
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z) * (close or 1)
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(reach * 0.9, reach * 0.35, -reach * 1.25), cf.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
end

local gui = UiKit.gui("KaijuBattle", 15)
gui.Enabled = false

-- The formation board --------------------------------------------------------------------------------------

local board = new("Frame", {
	Name = "Formation",
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.04,
	Visible = false,
}, gui)
UiKit.round(board, 12)
new("UIStroke", { Color = ORANGE, Thickness = 1.5 }, board)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(ORANGE:Lerp(P.Frame, 0.86), P.Frame) }, board)
local title = line(board, "PLACE YOUR KAIJU", 18, P.Text, IronUi.Heading)
local versus = line(board, "", 12, P.Dim, IronUi.Body)
versus:SetAttribute("NoTranslate", true)
local stakeChip =
	new("Frame", { Name = "Stake", BackgroundColor3 = P.Gold:Lerp(P.Frame, 0.78), Visible = false }, board)
UiKit.round(stakeChip, 6)
new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.3 }, stakeChip)
local stakeText = line(stakeChip, "", 11, P.Gold, IronUi.Heading)
stakeText.Size = UDim2.new(1, -12, 1, 0)
stakeText.Position = UDim2.fromOffset(6, 0)
stakeText.TextXAlignment = Enum.TextXAlignment.Center
UiKit.fit(stakeText)
local countdown = line(board, "", 26, P.Text, Enum.Font.GothamBlack)
countdown.TextXAlignment = Enum.TextXAlignment.Right
countdown:SetAttribute("NoTranslate", true)
local countdownNote = line(board, "TILL THE FIGHT", 9, P.Dim)
countdownNote.TextXAlignment = Enum.TextXAlignment.Right
local timeBar = new("Frame", { Name = "Time", BackgroundColor3 = P.Slot, BorderSizePixel = 0 }, board)
UiKit.round(timeBar, 2)
local timeFill = new("Frame", { BackgroundColor3 = ORANGE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, timeBar)
UiKit.round(timeFill, 2)

-- The court from above: the foe's half (hidden), the middle line, then your
-- front row and back row.
local court = new("Frame", { Name = "Court", BackgroundColor3 = Color3.fromRGB(28, 34, 44) }, board)
UiKit.round(court, 10)
new("UIStroke", { Color = HAZARD, Thickness = 1.5, Transparency = 0.2 }, court)
local foeHalf = new("Frame", { Name = "FoeHalf", BackgroundColor3 = THEIRS:Lerp(P.Frame, 0.8) }, court)
UiKit.round(foeHalf, 8)
local foeText = line(foeHalf, "YOUR FOE'S SIDE: HIDDEN TILL THE FIGHT", 10, THEIRS:Lerp(P.Text, 0.35))
foeText.TextWrapped = true
foeText.Size = UDim2.new(1, -8, 1, 0)
foeText.Position = UDim2.fromOffset(4, 0)
foeText.TextXAlignment = Enum.TextXAlignment.Center
local middle = new("Frame", { Name = "Middle", BackgroundColor3 = HAZARD, BorderSizePixel = 0 }, court)
local mineHalf = new("Frame", { Name = "MineHalf", BackgroundColor3 = MINE:Lerp(P.Frame, 0.84) }, court)
UiKit.round(mineHalf, 8)
local youText = line(court, "YOUR SIDE", 9, MINE:Lerp(P.Text, 0.3))
youText.TextXAlignment = Enum.TextXAlignment.Center

type CellUi = { Button: TextButton, Stroke: UIStroke, Row: TextLabel, View: ViewportFrame, Name: TextLabel }
local cellUi: { [string]: CellUi } = {}
for _, cell in KaijuBattle.cells() do
	local b = new("TextButton", {
		Name = cell.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = P.Inset,
		BackgroundTransparency = 0.15,
	}, court)
	UiKit.round(b, 8)
	local stroke =
		new("UIStroke", { Color = P.Edge, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	local row = line(b, if cell.Row == "Front" then "FRONT" else "BACK", 9, P.Edge)
	row.Size = UDim2.fromScale(1, 1)
	row.TextXAlignment = Enum.TextXAlignment.Center
	row.TextWrapped = true
	local view = viewport(b, { Name = "Kaiju", Visible = false })
	local name = line(b, "", 9, P.Text, IronUi.Heading)
	name.Name = "KaijuName"
	name.TextXAlignment = Enum.TextXAlignment.Center
	name:SetAttribute("NoTranslate", true)
	UiKit.fit(name)
	b:SetAttribute("UiSound", "Click")
	cellUi[cell.Id] = { Button = b, Stroke = stroke, Row = row, View = view, Name = name }
end

-- Your kaiju, each on a card.
local bench = new("Frame", { Name = "Bench", BackgroundTransparency = 1 }, board)
type CardUi = {
	Frame: TextButton,
	Stroke: UIStroke,
	Stripe: Frame,
	View: ViewportFrame,
	Name: TextLabel,
	Info: TextLabel,
	Track: Frame,
	Fill: Frame,
	Spot: TextLabel,
	Id: string?,
}
local cards: { CardUi } = {}
for i = 1, 3 do
	local frame = new("TextButton", {
		Name = "Card" .. i,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = P.Inset,
	}, bench)
	UiKit.round(frame, 10)
	local stroke =
		new("UIStroke", { Color = P.Edge, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	local stripe = new("Frame", { Name = "Stripe", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 4) }, frame)
	UiKit.round(stripe, 2)
	local view = viewport(frame, { Name = "Portrait" })
	local name = line(frame, "", 12, P.Text, IronUi.Heading)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name:SetAttribute("NoTranslate", true)
	UiKit.fit(name)
	local info = line(frame, "", 9, P.Dim)
	info.TextXAlignment = Enum.TextXAlignment.Center
	local track = new("Frame", { Name = "Health", BackgroundColor3 = P.Slot, BorderSizePixel = 0 }, frame)
	UiKit.round(track, 3)
	local fill = new("Frame", { BackgroundColor3 = P.Good, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, track)
	UiKit.round(fill, 3)
	local spot = line(frame, "", 9, MINE:Lerp(P.Text, 0.4), IronUi.Heading)
	spot.TextXAlignment = Enum.TextXAlignment.Center
	frame:SetAttribute("UiSound", "Click")
	cards[i] = {
		Frame = frame,
		Stroke = stroke,
		Stripe = stripe,
		View = view,
		Name = name,
		Info = info,
		Track = track,
		Fill = fill,
		Spot = spot,
	}
end

local hint = line(board, "", 10, P.Dim, IronUi.Body)
hint.TextWrapped = true
local leaveButton = button(board, "LEAVE", P.Bad, function()
	task.spawn(GemClient.request, "KaijuBattleLeave")
end)
local autoButton: TextButton
local readyButton = button(board, "READY", P.Good, function()
	task.spawn(GemClient.request, "KaijuBattleReady")
end)
readyButton.TextSize = 17

-- The battle bar -------------------------------------------------------------------------------------------

local bar = new("Frame", {
	Name = "Battle",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.08,
	Visible = false,
}, gui)
UiKit.round(bar, 12)
new("UIStroke", { Color = ORANGE, Thickness = 1.5 }, bar)
local barClock = line(bar, "", 20, P.Text, Enum.Font.GothamBlack)
barClock.TextXAlignment = Enum.TextXAlignment.Center
barClock:SetAttribute("NoTranslate", true)
local barTitle = line(bar, "KAIJU BATTLE", 10, ORANGE, IronUi.Heading)
barTitle.TextXAlignment = Enum.TextXAlignment.Center
local barStake = line(bar, "", 9, P.Gold, IronUi.Heading)
barStake.TextXAlignment = Enum.TextXAlignment.Center
local barLeave = button(bar, "LEAVE", P.Bad, function()
	task.spawn(GemClient.request, "KaijuBattleLeave")
end)
type Gauge = { Frame: Frame, Track: Frame, Fill: Frame, Name: TextLabel, View: ViewportFrame }
local gauges: { Gauge } = {}
for i = 1, 6 do
	local frame = new("Frame", { Name = "Gauge" .. i, BackgroundColor3 = P.Slot }, bar)
	UiKit.round(frame, 6)
	new("UIStroke", { Color = P.Edge, Transparency = 0.4, Thickness = 1 }, frame)
	local view = viewport(frame, { Name = "Face", BackgroundColor3 = P.Inset, BackgroundTransparency = 0 })
	UiKit.round(view, 6)
	local track = new("Frame", { Name = "Track", BackgroundColor3 = P.Frame, BorderSizePixel = 0 }, frame)
	UiKit.round(track, 3)
	local fill = new(
		"Frame",
		{ Name = "Fill", BackgroundColor3 = P.Good, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
		track
	)
	UiKit.round(fill, 3)
	local name = line(frame, "", 10, P.Text, IronUi.Heading)
	name.TextStrokeTransparency = 0.4
	name:SetAttribute("NoTranslate", true)
	UiKit.fit(name)
	gauges[i] = { Frame = frame, Track = track, Fill = fill, Name = name, View = view }
end

-- The result -----------------------------------------------------------------------------------------------

local resultCard = new("Frame", {
	Name = "Result",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.08,
	Visible = false,
	AutomaticSize = Enum.AutomaticSize.Y,
}, gui)
UiKit.round(resultCard, 12)
local resultStroke = new("UIStroke", { Color = P.Gold, Thickness = 1.5 }, resultCard)
UiKit.pad(resultCard, 14)
UiKit.list(resultCard, 4)
local result = line(resultCard, "", 46, P.Gold, Enum.Font.GothamBlack)
result.Size = UDim2.new(1, 0, 0, 52)
result.TextXAlignment = Enum.TextXAlignment.Center
result.TextStrokeTransparency = 0.3
result.LayoutOrder = 1
local resultExp = line(resultCard, "", 15, P.Text, IronUi.Heading)
resultExp.Size = UDim2.new(1, 0, 0, 20)
resultExp.TextXAlignment = Enum.TextXAlignment.Center
resultExp.LayoutOrder = 2
local resultHealed = line(resultCard, "YOUR KAIJU ARE HEALED", 13, P.Good, IronUi.Heading)
resultHealed.Size = UDim2.new(1, 0, 0, 18)
resultHealed.TextXAlignment = Enum.TextXAlignment.Center
resultHealed.LayoutOrder = 3
local resultStake = line(resultCard, "", 13, P.Gold, IronUi.Heading)
resultStake.Size = UDim2.new(1, 0, 0, 18)
resultStake.TextXAlignment = Enum.TextXAlignment.Center
resultStake.LayoutOrder = 4

-- Layout ---------------------------------------------------------------------------------------------------

local function layout()
	local short = UiKit.short()
	local screen = gui.AbsoluteSize
	local edge = if short then 10 else 14
	local width = math.min(if short then 620 else 780, math.max(screen.X - 24, 300))
	local headH = if short then 30 else 44
	local bodyH = if short then 150 else 236
	local footH = if short then 32 else 40
	local top = edge
	title.Position, title.Size =
		UDim2.fromOffset(edge, top - 2), UDim2.fromOffset(width * 0.5, if short then 18 else 22)
	title.TextSize = if short then 15 else 19
	versus.Position = UDim2.fromOffset(edge, top + (if short then 17 else 21))
	versus.Size = UDim2.fromOffset(width * 0.26, 16)
	stakeChip.Position = UDim2.fromOffset(edge + width * 0.26 + 4, top + (if short then 16 else 20))
	stakeChip.Size = UDim2.fromOffset(math.min(width * 0.4, 280), if short then 16 else 18)
	countdown.Position, countdown.Size =
		UDim2.new(1, -edge - 110, 0, top - 4), UDim2.fromOffset(110, if short then 24 else 30)
	countdown.TextSize = if short then 22 else 28
	countdownNote.Position = UDim2.new(1, -edge - 110, 0, top + (if short then 20 else 26))
	countdownNote.Size = UDim2.fromOffset(110, 12)
	top += headH
	timeBar.Position, timeBar.Size = UDim2.fromOffset(edge, top), UDim2.new(1, -edge * 2, 0, 4)
	top += 10
	-- The court on the left, the cards on the right.
	local courtW = if short then 214 else 300
	court.Position, court.Size = UDim2.fromOffset(edge, top), UDim2.fromOffset(courtW, bodyH)
	local inner, gap = 8, if short then 5 else 7
	local foeH = if short then 26 else 40
	foeHalf.Position, foeHalf.Size = UDim2.fromOffset(inner, inner), UDim2.new(1, -inner * 2, 0, foeH)
	foeText.TextSize = if short then 8 else 10
	middle.Position, middle.Size = UDim2.fromOffset(inner, inner + foeH + 4), UDim2.new(1, -inner * 2, 0, 2)
	local rowsTop = inner + foeH + 11
	local youH = 11
	local cellW = (courtW - inner * 2 - gap * 2) / 3
	local cellH = (bodyH - rowsTop - inner - gap - youH) / 2
	mineHalf.Position = UDim2.fromOffset(inner - 3, rowsTop - 3)
	mineHalf.Size = UDim2.new(1, -inner * 2 + 6, 0, cellH * 2 + gap + 6)
	youText.Position, youText.Size = UDim2.new(0, 0, 1, -youH - 3), UDim2.new(1, 0, 0, youH)
	for _, cell in KaijuBattle.cells() do
		local ui = cellUi[cell.Id]
		local row = if cell.Row == "Front" then 0 else 1
		ui.Button.Position = UDim2.fromOffset(inner + (cell.Column + 1) * (cellW + gap), rowsTop + row * (cellH + gap))
		ui.Button.Size = UDim2.fromOffset(cellW, cellH)
		local face = math.max(10, math.min(cellW - 8, cellH - 15))
		ui.View.Size = UDim2.fromOffset(face, face)
		ui.View.Position = UDim2.new(0.5, -face / 2, 0, 2)
		ui.Name.Position, ui.Name.Size = UDim2.new(0, 3, 1, -13), UDim2.new(1, -6, 0, 12)
	end
	-- The cards.
	local benchX = edge + courtW + (if short then 10 else 16)
	local benchW = width - benchX - edge
	bench.Position, bench.Size = UDim2.fromOffset(benchX, top), UDim2.fromOffset(benchW, bodyH)
	local cardGap = if short then 6 else 10
	local cardW = (benchW - cardGap * 2) / 3
	for i, card in cards do
		card.Frame.Position = UDim2.fromOffset((i - 1) * (cardW + cardGap), 0)
		card.Frame.Size = UDim2.fromOffset(cardW, bodyH)
		local face = math.max(20, math.min(cardW - 12, bodyH - (if short then 66 else 84)))
		card.View.Size = UDim2.fromOffset(face, face)
		card.View.Position = UDim2.new(0.5, -face / 2, 0, 8)
		local y = face + 12
		card.Name.Position, card.Name.Size = UDim2.fromOffset(4, y), UDim2.new(1, -8, 0, if short then 14 else 16)
		card.Name.TextSize = if short then 11 else 13
		card.Info.Position, card.Info.Size =
			UDim2.fromOffset(4, y + (if short then 15 else 18)), UDim2.new(1, -8, 0, 12)
		card.Track.Position = UDim2.fromOffset(10, y + (if short then 30 else 36))
		card.Track.Size = UDim2.new(1, -20, 0, 5)
		card.Spot.Position, card.Spot.Size = UDim2.new(0, 4, 1, -(if short then 15 else 19)), UDim2.new(1, -8, 0, 12)
	end
	top += bodyH + (if short then 8 else 12)
	local buttonH = footH - 4
	hint.Position, hint.Size = UDim2.fromOffset(edge, top), UDim2.new(1, -edge * 2 - 352, 0, buttonH)
	hint.Visible = width > 560
	hint.TextSize = if short then 9 else 11
	leaveButton.Position, leaveButton.Size = UDim2.new(1, -edge - 340, 0, top), UDim2.fromOffset(80, buttonH)
	autoButton.Position, autoButton.Size = UDim2.new(1, -edge - 252, 0, top), UDim2.fromOffset(80, buttonH)
	readyButton.Position, readyButton.Size = UDim2.new(1, -edge - 164, 0, top), UDim2.fromOffset(164, buttonH)
	top += footH + edge - 4
	board.Size = UDim2.fromOffset(width, top)
	-- (Centred on a phone, clear of the screen's bottom edge.)
	board.Position = if short then UDim2.new(0.5, 0, 0.5, top / 2) else UDim2.new(0.5, 0, 1, -18)

	-- The battle bar: three faces a side, the clock between.
	local gh = if short then 36 else 42
	local middleW = if short then 104 else 140
	-- (Narrow enough to clear the lobby's side panels.)
	local barW = math.min((if short then 92 else 104) * 6 + 16 + middleW + 20, screen.X - 12)
	local gw = (barW - middleW - 20 - 16) / 6
	local barH = gh + (if short then 16 else 18)
	bar.Size = UDim2.fromOffset(barW, barH)
	bar.Position = UDim2.new(0.5, 0, 0, if short then 4 else 70)
	barTitle.Position, barTitle.Size =
		UDim2.new(0.5, -middleW / 2, 0, if short then 2 else 3), UDim2.fromOffset(middleW, 11)
	barClock.Position = UDim2.new(0.5, -middleW / 2, 0, if short then 10 else 12)
	barClock.Size = UDim2.fromOffset(middleW, if short then 18 else 20)
	barClock.TextSize = if short then 17 else 20
	barStake.Position = UDim2.new(0.5, -middleW / 2, 0, if short then 27 else 31)
	barStake.Size = UDim2.fromOffset(middleW, if short then 9 else 10)
	barStake.TextSize = if short then 8 else 9
	barLeave.Position = UDim2.new(0.5, -32, 1, -(if short then 13 else 15))
	barLeave.Size = UDim2.fromOffset(64, if short then 11 else 13)
	barLeave.TextSize = 9
	for i, g in gauges do
		local mine = i <= 3
		local slot = if mine then i - 1 else i - 4
		local x = if mine then 10 + slot * (gw + 4) else barW - 10 - (3 - slot) * (gw + 4) + 4
		g.Frame.Position = UDim2.fromOffset(x, (barH - gh) / 2)
		g.Frame.Size = UDim2.fromOffset(gw, gh)
		g.View.Size = UDim2.fromOffset(gh - 6, gh - 6)
		g.View.Position = UDim2.fromOffset(3, 3)
		g.Name.Position, g.Name.Size = UDim2.fromOffset(gh, 3), UDim2.new(1, -gh - 4, 0, 13)
		g.Track.Position, g.Track.Size = UDim2.new(0, gh, 1, -11), UDim2.new(1, -gh - 6, 0, 6)
	end
	resultCard.Size = UDim2.fromOffset(math.min(420, screen.X - 40), 0)
end

-- The ground: both sides' places ---------------------------------------------------------------------------

local field: Folder? = nil
local marks: { [string]: BasePart } = {}

local function clearField()
	if field then
		field:Destroy()
	end
	field = nil
	table.clear(marks)
end

local function groundAt(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	for _, name in { "Kaiju", "Enemies", "KaijuBattleField" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(skip, folder)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), params)
	return if hit then hit.Position else at
end

local function disc(at: Vector3, diameter: number, color: Color3, transparency: number): Part
	return new("Part", {
		Name = "Place",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Transparency = transparency,
		Size = Vector3.new(0.08, diameter, diameter),
		CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}, field)
end

local function drawField(state)
	if field and field:GetAttribute("BattleId") == state.Id then
		return
	end
	clearField()
	local folder = new("Folder", { Name = "KaijuBattleField" }, workspace)
	folder:SetAttribute("BattleId", state.Id)
	field = folder
	local shape = { Center = state.Center, Axis = state.Axis }
	for _, side in { "A", "B" } do
		local mine = side == state.Side
		for _, cell in KaijuBattle.cells() do
			local at = groundAt(KaijuBattle.cellSpot(shape, side, cell.Id))
			marks[side .. cell.Id] = disc(at, 2.6, if mine then MINE else THEIRS, 0.7)
		end
	end
	-- (Off a court, a middle line across the field: a court has its own.)
	if not state.Court then
		local across = state.Axis:Cross(Vector3.new(0, 1, 0))
		local mid = groundAt(state.Center)
		new("Part", {
			Name = "MiddleLine",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = ORANGE,
			Transparency = 0.55,
			Size = Vector3.new(0.25, 0.06, KaijuBattle.Field.Across * 3.4),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.06, 0), mid + Vector3.new(0, 0.06, 0) + across),
		}, folder)
	end
end

-- Drawing the state ----------------------------------------------------------------------------------------

local unitOrder: { any } = {}

local function unitsById(state): { [string]: any }
	local byId = {}
	for _, unit in state.Units or {} do
		byId[unit.Id] = unit
	end
	return byId
end

-- Your kaiju in it, in the order the server lists them.
local function yours(state): { any }
	local list = {}
	for _, unit in state.Units or {} do
		if unit.Side == state.Side then
			table.insert(list, unit)
		end
	end
	return list
end

local function healthOf(unit): number
	local model = unit.Model
	local humanoid = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 1
end

local function levelOf(unit): number?
	local roster = GemClient.Profile and GemClient.Profile.Kaiju
	for _, record in (roster and roster.List) or {} do
		if record.Id == unit.Id then
			return record.Level
		end
	end
	return nil
end

local function drawBoard(state)
	local byCell = {}
	for id, cellId in state.Mine or {} do
		byCell[cellId] = id
	end
	local byId = unitsById(state)
	for _, cell in KaijuBattle.cells() do
		local ui = cellUi[cell.Id]
		local id = byCell[cell.Id]
		local unit = id and byId[id]
		if unit then
			local color = elementColor(unit.Element)
			ui.Button.BackgroundColor3 = color:Lerp(P.Frame, 0.7)
			ui.Name.Text = unit.Name
			ui.Row.Visible = false
			ui.View.Visible = true
			portrait(ui.View, modelFor("cell" .. cell.Id, unit), 0.9)
			ui.Stroke.Color = if picked == id then P.Gold else color
			ui.Stroke.Thickness = if picked == id then 3 else 1.4
		else
			ui.Button.BackgroundColor3 = P.Inset
			ui.Name.Text = ""
			ui.Row.Visible = true
			ui.Row.Text = if picked or hovered == cell.Id
				then "PUT IT HERE"
				else (if cell.Row == "Front" then "FRONT" else "BACK")
			ui.Row.TextColor3 = if picked or hovered == cell.Id then P.Gold else P.Edge
			ui.View.Visible = false
			portrait(ui.View, nil)
			ui.Stroke.Color, ui.Stroke.Thickness = P.Edge, 1.2
		end
		if hovered == cell.Id then
			ui.Stroke.Color, ui.Stroke.Thickness = P.Gold, 3
		end
		local mark = marks[state.Side .. cell.Id]
		if mark then
			mark.Color = if unit then elementColor(unit.Element) else MINE
			mark.Transparency = if unit then 0.35 else 0.75
		end
	end
	-- The cards.
	local list = yours(state)
	for i, card in cards do
		local unit = list[i]
		card.Frame.Visible = unit ~= nil
		card.Id = unit and unit.Id
		if unit then
			local color = elementColor(unit.Element)
			card.Stripe.BackgroundColor3 = color
			card.Frame.BackgroundColor3 = color:Lerp(P.Frame, 0.84)
			card.Stroke.Color = if picked == unit.Id then P.Gold else color:Lerp(P.Edge, 0.4)
			card.Stroke.Thickness = if picked == unit.Id then 3 else 1.2
			card.Name.Text = unit.Name
			local level = levelOf(unit)
			card.Info.Text = (if level then "Lv " .. level .. "  ·  " else "") .. (ROLES[unit.Species] or "")
			local share = healthOf(unit)
			card.Fill.Size = UDim2.fromScale(share, 1)
			card.Fill.BackgroundColor3 = if share > 0.5 then P.Good elseif share > 0.25 then P.Gold else P.Bad
			local cellId = (state.Mine or {})[unit.Id]
			card.Spot.Text = if cellId then CELL_NAMES[cellId] or "" else ""
			portrait(card.View, modelFor("card" .. i, unit))
		end
	end
	versus.Text = "vs " .. (state.Foe or "")
	local stake = state.Stake
	stakeChip.Visible = stake ~= nil
	if stake then
		stakeText.Text = string.upper(KaijuPit.stakeText(stake))
			.. "  ·  WINNER TAKES "
			.. string.upper(state.Pot or "")
	end
	local ready = state.Ready or {}
	local mineReady = ready[state.Side] == true
	local theirsReady = ready[if state.Side == "A" then "B" else "A"] == true
	readyButton.Text = if mineReady then "WAITING FOR FOE" else "READY"
	readyButton.AutoButtonColor = not mineReady
	hint.Text = if theirsReady and not mineReady
		then "Your foe is ready. Press READY to start now."
		elseif picked then "Now tap a spot for it."
		else "Drag a kaiju onto a spot, or tap it, then a spot. The front row takes the blows; a Razorback shoots from the back."
end

-- Moving one: `id` to `cellId` (onto another, they swap); the server told.
local function move(id: string, cellId: string)
	local state = current
	if not state or state.Phase ~= "Formation" then
		return
	end
	local formation = table.clone(state.Mine or {})
	local from = formation[id]
	if from == cellId then
		drawBoard(state)
		return
	end
	local there = nil
	for other, at in formation do
		if at == cellId then
			there = other
		end
	end
	formation[id] = cellId
	if there then
		formation[there] = from
	end
	state.Mine = formation
	drawBoard(state)
	task.spawn(function()
		local reply = GemClient.request("KaijuBattleFormation", formation)
		if reply and not reply.Ok and reply.Message and reply.Message ~= "" then
			UiKit.toast(reply.Message, P.Bad)
		end
	end)
end

autoButton = button(board, "AUTO", P.Teal, function()
	local state = current
	if not state or state.Phase ~= "Formation" then
		return
	end
	local records = {}
	for _, unit in yours(state) do
		table.insert(records, { Id = unit.Id, Species = unit.Species })
	end
	local formation = KaijuBattle.defaultFormation(records)
	state.Mine = formation
	picked = nil
	drawBoard(state)
	task.spawn(GemClient.request, "KaijuBattleFormation", formation)
end)

-- Dragging -------------------------------------------------------------------------------------------------
-- (An InputObject's position sits under the top bar's inset, as this gui's
-- AbsolutePositions do: they compare as they are.)

local ghost = new("Frame", {
	Name = "Dragged",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = P.Inset,
	Visible = false,
	ZIndex = 50,
}, gui)
UiKit.round(ghost, 32)
local ghostStroke = new("UIStroke", { Color = P.Gold, Thickness = 2 }, ghost)
local ghostView = viewport(ghost, { Name = "Kaiju", Size = UDim2.fromScale(1, 1), ZIndex = 51 })
local ghostName = line(ghost, "", 11, P.Gold, IronUi.Heading)
ghostName.Position, ghostName.Size = UDim2.new(0, -40, 1, 2), UDim2.new(1, 80, 0, 14)
ghostName.TextXAlignment = Enum.TextXAlignment.Center
ghostName.ZIndex = 52
ghostName:SetAttribute("NoTranslate", true)

local drag = nil -- { Id, Input, Touch, Start, Active }

local function cellAt(at: Vector2): string?
	for id, ui in cellUi do
		local pos, size = ui.Button.AbsolutePosition, ui.Button.AbsoluteSize
		if at.X >= pos.X and at.Y >= pos.Y and at.X < pos.X + size.X and at.Y < pos.Y + size.Y then
			return id
		end
	end
	return nil
end

local function endDrag()
	drag = nil
	hovered = nil
	ghost.Visible = false
	portrait(ghostView, nil)
	if current and current.Phase == "Formation" then
		drawBoard(current)
	end
end

local function pointOf(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function beginDrag(id: string?, input: InputObject)
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if not id or (not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then
		return
	end
	if not current or current.Phase ~= "Formation" then
		return
	end
	drag = { Id = id, Input = input, Touch = touch, Start = pointOf(input), Active = false }
end

local function moveDrag(at: Vector2)
	local state = current
	if not drag or not state or state.Phase ~= "Formation" then
		return
	end
	if not drag.Active then
		if (at - drag.Start).Magnitude < 8 then
			return
		end
		drag.Active = true
		picked = nil
		local unit = unitsById(state)[drag.Id]
		if unit then
			ghostStroke.Color = elementColor(unit.Element)
			ghost.BackgroundColor3 = elementColor(unit.Element):Lerp(P.Frame, 0.7)
			ghostName.Text = unit.Name
			portrait(ghostView, modelFor("ghost", unit), 0.9)
		end
		ghost.Visible = true
	end
	ghost.Position = UDim2.fromOffset(at.X, at.Y - (if drag.Touch then 40 else 0))
	local over = cellAt(at)
	if over ~= hovered then
		hovered = over
		drawBoard(state)
	end
end

-- Let go: on a place, it goes there. A tap (no drag) picks it up, or puts
-- the one picked up in its place (they swap).
local function dropDrag(at: Vector2)
	local held = drag
	if not held then
		return
	end
	if held.Active then
		local cellId = cellAt(at)
		endDrag()
		if cellId then
			move(held.Id, cellId)
		end
		return
	end
	endDrag()
	local state = current
	if picked and picked ~= held.Id and state then
		local target = (state.Mine or {})[held.Id]
		local id = picked
		picked = nil
		if target then
			move(id, target)
		end
	else
		picked = if picked == held.Id then nil else held.Id
		if state then
			drawBoard(state)
		end
	end
end

for i, card in cards do
	card.Frame.InputBegan:Connect(function(input)
		beginDrag(cards[i].Id, input)
	end)
end
for cellId, ui in cellUi do
	ui.Button.InputBegan:Connect(function(input)
		local here = nil
		for id, at in (current and current.Mine) or {} do
			if at == cellId then
				here = id
			end
		end
		if here then
			beginDrag(here, input)
		end
	end)
	-- (A tap on an empty place with one picked up puts it there.)
	ui.Button.Activated:Connect(function()
		if picked and not drag then
			local id = picked
			picked = nil
			move(id, cellId)
		end
	end)
end
UserInputService.InputChanged:Connect(function(input)
	if not drag then
		return
	end
	if drag.Touch then
		if input == drag.Input then
			moveDrag(pointOf(input))
		end
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		moveDrag(pointOf(input))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if not drag then
		return
	end
	if
		(drag.Touch and input == drag.Input)
		or (not drag.Touch and input.UserInputType == Enum.UserInputType.MouseButton1)
	then
		dropDrag(pointOf(input))
	end
end)

-- The battle bar and the result ----------------------------------------------------------------------------

local function drawBar(state)
	unitOrder = {}
	local mineList, theirs = {}, {}
	for _, unit in state.Units or {} do
		table.insert(if unit.Side == state.Side then mineList else theirs, unit)
	end
	for i = 1, 3 do
		unitOrder[i] = mineList[i] or false
		unitOrder[i + 3] = theirs[i] or false
	end
	for i, g in gauges do
		local unit = unitOrder[i]
		g.Frame.Visible = unit ~= false
		if unit then
			g.Name.Text = unit.Name
			g.Fill.BackgroundColor3 = if i <= 3 then MINE else THEIRS
			g.View.BackgroundColor3 = elementColor(unit.Element):Lerp(P.Frame, 0.6)
			portrait(g.View, modelFor("gauge" .. i, unit), 0.85)
		end
	end
	barStake.Text = if state.Stake then "FOR " .. string.upper(state.Pot or "") else ""
end

local function show(state)
	current = state
	if not state then
		gui.Enabled = false
		picked = nil
		if drag then
			endDrag()
		end
		clearField()
		return
	end
	gui.Enabled = true
	local over = state.Phase == "Over"
	board.Visible = state.Phase == "Formation"
	bar.Visible = state.Phase == "Battle" or over
	barLeave.Text = if over then "CLOSE" else "LEAVE"
	resultCard.Visible = over
	if over then
		clearField()
		local won, lost = state.Result == "Win", state.Result == "Lose"
		result.Text = if won then "VICTORY" elseif lost then "DEFEAT" else "DRAW"
		result.TextColor3 = if won then P.Gold elseif lost then P.Bad else P.Text
		resultStroke.Color = result.TextColor3
		resultExp.Text = string.format("+%d EXP for each of your kaiju", state.Exp or 0)
		resultHealed.Visible = state.Healed == true
		local stake = state.Stake
		resultStake.Visible = stake ~= nil
		if stake then
			resultStake.Text = if won
				then "YOU WON " .. string.upper(
					if state.Spoils then state.Spoils.Name or "their gem" else state.Pot or ""
				)
				elseif lost then "YOUR STAKE IS THEIRS"
				else "STAKES RETURNED"
		end
		if won then
			local scale = resultCard:FindFirstChildOfClass("UIScale") or new("UIScale", {}, resultCard)
			scale.Scale = 0.8
			TweenService
				:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
	else
		drawField(state)
	end
	if state.Phase == "Formation" then
		drawBoard(state)
	else
		picked = nil
		if drag then
			endDrag()
		end
		-- Both sides' places are known now: light the foe's too.
		for id, cellId in state.Theirs or {} do
			local mark = marks[(if state.Side == "A" then "B" else "A") .. cellId]
			if mark then
				local color = THEIRS
				for _, unit in state.Units or {} do
					if unit.Id == id then
						color = elementColor(unit.Element)
					end
				end
				mark.Color, mark.Transparency = color, 0.35
			end
		end
		drawBar(state)
	end
	KaijuBattleUI.tick()
end
KaijuBattleUI.show = show

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

function KaijuBattleUI.state()
	return current
end

-- The clock and the health, a few times a second.
function KaijuBattleUI.tick()
	local state = current
	if not state then
		return
	end
	local left = (state.EndsAt or 0) - serverNow()
	countdown.Text = clock(left)
	countdown.TextColor3 = if state.Phase == "Formation" and left <= 5 then P.Bad else P.Text
	timeFill.Size = UDim2.fromScale(math.clamp(left / KaijuBattle.FormationSeconds, 0, 1), 1)
	barClock.Text = if state.Phase == "Over" then "" else clock(left)
	if state.Phase == "Formation" then
		local list = yours(state)
		for i, card in cards do
			local unit = list[i]
			if unit then
				card.Fill.Size = UDim2.fromScale(healthOf(unit), 1)
			end
		end
	else
		for i, g in gauges do
			local unit = unitOrder[i]
			if unit then
				local share = healthOf(unit)
				g.Fill.Size = UDim2.fromScale(share, 1)
				g.Frame.BackgroundTransparency = if share <= 0 then 0.6 else 0
				g.Name.TextColor3 = if share <= 0 then P.Dim else P.Text
			end
		end
	end
end

function KaijuBattleUI.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Social").OnClientEvent:Connect(function(kind: string, state)
		if kind == "KaijuBattle" then
			show(state)
		end
	end)
	local nextTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if not current or now < nextTick then
			return
		end
		nextTick = now + 0.2
		KaijuBattleUI.tick()
	end)
end

return KaijuBattleUI
