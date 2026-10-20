--[[
	A kaiju battle, on screen (KaijuBattles runs it; Shared.KaijuBattle has
	the rules). Asking is KAIJU on another miner's card (PlayerCard); the
	card to accept is SocialUI's. Once both agree:

	  Formation  a board at the bottom: your side's six places, the front
	             row nearest your foe, your kaiju in theirs. Tap one of your
	             kaiju, then a place, to move it (onto another, they swap).
	             The clock till it starts, READY (both ready starts it now)
	             and LEAVE. Your foe's places are hidden till it starts. On
	             the ground, both sides' places are marked, yours lit where
	             a kaiju stands.
	  Battle     a bar at the top: your kaiju's health on the left, your
	             foe's on the right, the clock in the middle, and LEAVE.
	  Over       VICTORY, DEFEAT or DRAW, and the EXP your kaiju earned.

	  KaijuBattleUI.start()   once (Lobby.client, with KaijuHud)
	  KaijuBattleUI.state()   the battle you're in, as last told (nil: none)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local KaijuBattle = require(ReplicatedStorage.Shared.KaijuBattle)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local KaijuBattleUI = {}

local ORANGE = Color3.fromRGB(255, 132, 64)
local MINE = Color3.fromRGB(70, 205, 235)
local THEIRS = Color3.fromRGB(240, 92, 92)
-- What each kind does in a formation (Shared.KaijuBattle.FrontKinds).
local ROLES = { Bulwark = "FRONT LINE", Razorback = "SHOOTER", Carapace = "FRONT LINE" }

local current = nil -- the state last told
local picked: string? = nil -- the kaiju tapped, to move

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
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

local gui = UiKit.gui("KaijuBattle", 15)
gui.Enabled = false

-- The formation board -------------------------------------------------------------------------------

local board = new("Frame", {
	Name = "Formation",
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.06,
	Visible = false,
}, gui)
UiKit.round(board, 12)
new("UIStroke", { Color = ORANGE, Thickness = 1.5 }, board)
local title = line(board, "KAIJU BATTLE", 16, ORANGE, IronUi.Heading)
local foeName = line(board, "", 13, P.Dim)
foeName:SetAttribute("NoTranslate", true)
local versus = line(board, "against", 12, P.Dim, IronUi.Body)
local countdown = line(board, "", 18, P.Text, Enum.Font.GothamBlack)
countdown.TextXAlignment = Enum.TextXAlignment.Right
countdown:SetAttribute("NoTranslate", true)
local hint = line(
	board,
	"Tap a kaiju, then a place. The front row takes the blows; a Razorback shoots from the back.",
	11,
	P.Dim,
	IronUi.Body
)
hint.TextWrapped = true
local theirsStrip = new("Frame", { BackgroundColor3 = THEIRS:Lerp(P.Frame, 0.82) }, board)
UiKit.round(theirsStrip, 6)
local theirsText = line(theirsStrip, "YOUR FOE'S SIDE: HIDDEN TILL IT STARTS", 11, THEIRS:Lerp(P.Text, 0.3))
theirsText.TextXAlignment = Enum.TextXAlignment.Center
theirsText.Size = UDim2.fromScale(1, 1)
local rowLabels = {
	Front = UiKit.fit(line(board, "FRONT", 10, P.Dim)),
	Back = UiKit.fit(line(board, "BACK", 10, P.Dim)),
}
local cellButtons: { [string]: TextButton } = {}
for _, cell in KaijuBattle.cells() do
	local b = new("TextButton", {
		Name = cell.Id,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = P.Inset,
	}, board)
	UiKit.round(b, 8)
	new(
		"UIStroke",
		{ Name = "Edge", Color = P.Edge, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		b
	)
	local name = line(b, "", 12, P.Text, IronUi.Heading)
	name.Name = "KaijuName"
	name.TextXAlignment = Enum.TextXAlignment.Center
	name:SetAttribute("NoTranslate", true)
	UiKit.fit(name)
	local kind = line(b, "", 9, P.Dim)
	kind.Name = "Kind"
	kind.TextXAlignment = Enum.TextXAlignment.Center
	b:SetAttribute("UiSound", "Click")
	cellButtons[cell.Id] = b
end
local leaveButton, readyButton
leaveButton = button(board, "LEAVE", P.Bad, function()
	task.spawn(GemClient.request, "KaijuBattleLeave")
end)
readyButton = button(board, "READY", P.Good, function()
	task.spawn(GemClient.request, "KaijuBattleReady")
end)

-- The battle bar ----------------------------------------------------------------------------------------

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
local barLeave = button(bar, "LEAVE", P.Bad, function()
	task.spawn(GemClient.request, "KaijuBattleLeave")
end)
type Gauge = { Frame: Frame, Fill: Frame, Name: TextLabel }
local gauges: { Gauge } = {}
local function gauge(): Gauge
	local frame = new("Frame", { BackgroundColor3 = P.Slot }, bar)
	UiKit.round(frame, 5)
	new("UIStroke", { Color = P.Edge, Transparency = 0.4, Thickness = 1 }, frame)
	local fill = new("Frame", { BackgroundColor3 = P.Good, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, frame)
	UiKit.round(fill, 5)
	local name = line(frame, "", 10, P.Text, IronUi.Heading)
	name.Size = UDim2.new(1, -8, 1, 0)
	name.Position = UDim2.fromOffset(4, 0)
	name.TextStrokeTransparency = 0.4
	name:SetAttribute("NoTranslate", true)
	UiKit.fit(name)
	return { Frame = frame, Fill = fill, Name = name }
end
for i = 1, 6 do
	gauges[i] = gauge()
end

local result = line(gui, "", 54, P.Gold, Enum.Font.GothamBlack)
result.AnchorPoint = Vector2.new(0.5, 0.5)
result.Position = UDim2.fromScale(0.5, 0.38)
result.Size = UDim2.new(1, 0, 0, 64)
result.TextXAlignment = Enum.TextXAlignment.Center
result.TextStrokeTransparency = 0.2
result.Visible = false
local resultExp = line(gui, "", 18, P.Text, IronUi.Heading)
resultExp.AnchorPoint = Vector2.new(0.5, 0.5)
resultExp.Position = UDim2.new(0.5, 0, 0.38, 46)
resultExp.Size = UDim2.new(1, 0, 0, 24)
resultExp.TextXAlignment = Enum.TextXAlignment.Center
resultExp.TextStrokeTransparency = 0.3
resultExp.Visible = false

-- Layout -------------------------------------------------------------------------------------------------

local function layout()
	local short = UiKit.short()
	local cellW, cellH = if short then 92 else 112, if short then 40 else 48
	local gap, edge = 6, 10
	local width = cellW * 3 + gap * 2 + edge * 2 + 44
	local top = edge
	title.Position, title.Size = UDim2.fromOffset(edge, top), UDim2.fromOffset(150, 20)
	countdown.Position, countdown.Size = UDim2.new(1, -edge - 80, 0, top - 1), UDim2.fromOffset(80, 22)
	versus.Position, versus.Size = UDim2.fromOffset(edge + 128, top + 3), UDim2.fromOffset(56, 16)
	foeName.Position, foeName.Size = UDim2.fromOffset(edge + 180, top + 2), UDim2.new(1, -edge * 2 - 180 - 84, 0, 18)
	top += 24
	local hintH = if short then 0 else 28
	hint.Visible = not short
	hint.Position, hint.Size = UDim2.fromOffset(edge, top), UDim2.new(1, -edge * 2, 0, hintH)
	top += hintH + (if short then 0 else 4)
	theirsStrip.Position, theirsStrip.Size = UDim2.fromOffset(edge + 44, top), UDim2.new(1, -edge * 2 - 44, 0, 20)
	top += 26
	for row, label in rowLabels do
		local y = top + (if row == "Front" then 0 else cellH + gap)
		label.Position, label.Size = UDim2.fromOffset(edge, y), UDim2.fromOffset(40, cellH)
		label.TextYAlignment = Enum.TextYAlignment.Center
	end
	for _, cell in KaijuBattle.cells() do
		local b = cellButtons[cell.Id]
		local row = if cell.Row == "Front" then 0 else 1
		b.Position = UDim2.fromOffset(edge + 44 + (cell.Column + 1) * (cellW + gap), top + row * (cellH + gap))
		b.Size = UDim2.fromOffset(cellW, cellH)
		local name, kind = b:FindFirstChild("KaijuName") :: TextLabel, b:FindFirstChild("Kind") :: TextLabel
		name.Position, name.Size = UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, cellH * 0.45)
		kind.Position, kind.Size = UDim2.new(0, 4, 0, cellH * 0.45 + 5), UDim2.new(1, -8, 0, 12)
	end
	top += cellH * 2 + gap + 10
	local buttonH = if short then 32 else 36
	leaveButton.Position, leaveButton.Size = UDim2.fromOffset(edge, top), UDim2.fromOffset(96, buttonH)
	readyButton.Position, readyButton.Size = UDim2.new(1, -edge - 170, 0, top), UDim2.fromOffset(170, buttonH)
	top += buttonH + edge
	board.Size = UDim2.fromOffset(width, top)
	board.Position = UDim2.new(0.5, 0, 1, if short then -8 else -24)

	-- The battle bar.
	local gw, gh = if short then 74 else 92, if short then 16 else 18
	local barW = gw * 6 + 140 + 30
	bar.Size = UDim2.fromOffset(barW, if short then 58 else 66)
	bar.Position = UDim2.new(0.5, 0, 0, if short then 4 else 70)
	barTitle.Position, barTitle.Size = UDim2.new(0.5, -60, 0, 6), UDim2.fromOffset(120, 12)
	barClock.Position, barClock.Size = UDim2.new(0.5, -60, 0, 18), UDim2.fromOffset(120, 24)
	barLeave.Position, barLeave.Size =
		UDim2.new(0.5, -36, 1, -(if short then 16 else 20)), UDim2.fromOffset(72, if short then 14 else 16)
	barLeave.TextSize = 10
	for i, g in gauges do
		local mine = i <= 3
		local slot = if mine then i - 1 else i - 4
		local x = if mine then 10 + slot * (gw + 4) else barW - 10 - (3 - slot) * (gw + 4) + 4
		g.Frame.Position = UDim2.fromOffset(x, (if short then 58 else 66) / 2 - gh / 2)
		g.Frame.Size = UDim2.fromOffset(gw, gh)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

-- The ground: both sides' places -------------------------------------------------------------------------

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
	local p = new("Part", {
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
	return p
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
	-- The middle line, across the field.
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

-- Drawing the state -------------------------------------------------------------------------------------

local unitOrder: { any } = {}

local function elementColor(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or P.Edge
end

local function drawBoard(state)
	local byCell = {}
	for id, cellId in state.Mine or {} do
		byCell[cellId] = id
	end
	local units = {}
	for _, unit in state.Units or {} do
		units[unit.Id] = unit
	end
	for _, cell in KaijuBattle.cells() do
		local b = cellButtons[cell.Id]
		local id = byCell[cell.Id]
		local unit = id and units[id]
		local name, kind = b:FindFirstChild("KaijuName") :: TextLabel, b:FindFirstChild("Kind") :: TextLabel
		local edge = b:FindFirstChild("Edge") :: UIStroke
		if unit then
			local color = elementColor(unit.Element)
			b.BackgroundColor3 = color:Lerp(P.Frame, 0.62)
			name.Text = unit.Name
			kind.Text = ROLES[unit.Species] or ""
			edge.Color = if picked == id then P.Gold else color
			edge.Thickness = if picked == id then 3 else 1.2
		else
			b.BackgroundColor3 = P.Inset
			name.Text = ""
			kind.Text = if picked then "PLACE HERE" else ""
			edge.Color, edge.Thickness = P.Edge, 1.2
		end
		local mark = marks[state.Side .. cell.Id]
		if mark then
			mark.Color = if unit then elementColor(unit.Element) else MINE
			mark.Transparency = if unit then 0.35 else 0.75
		end
	end
	foeName.Text = state.Foe or ""
	local ready = state.Ready or {}
	local mineReady = ready[state.Side] == true
	readyButton.Text = if mineReady then "WAITING FOR FOE" else "READY"
	readyButton.AutoButtonColor = not mineReady
end

-- Tapping a place: pick up the kaiju there, or put the one picked up down
-- (onto another, they swap).
for cellId, b in cellButtons do
	b.Activated:Connect(function()
		local state = current
		if not state or state.Phase ~= "Formation" then
			return
		end
		local formation = table.clone(state.Mine or {})
		local here = nil
		for id, at in formation do
			if at == cellId then
				here = id
			end
		end
		if not picked then
			picked = here
			drawBoard(state)
			return
		end
		if here == picked then
			picked = nil
			drawBoard(state)
			return
		end
		local from = formation[picked]
		formation[picked] = cellId
		if here then
			formation[here] = from
		end
		picked = nil
		state.Mine = formation
		drawBoard(state)
		task.spawn(function()
			local reply = GemClient.request("KaijuBattleFormation", formation)
			if reply and not reply.Ok and reply.Message and reply.Message ~= "" then
				UiKit.toast(reply.Message, P.Bad)
			end
		end)
	end)
end

local function drawBar(state)
	unitOrder = {}
	local mine, theirs = {}, {}
	for _, unit in state.Units or {} do
		table.insert(if unit.Side == state.Side then mine else theirs, unit)
	end
	for i = 1, 3 do
		unitOrder[i] = mine[i] or false
		unitOrder[i + 3] = theirs[i] or false
	end
	for i, g in gauges do
		local unit = unitOrder[i]
		g.Frame.Visible = unit ~= false
		if unit then
			g.Name.Text = unit.Name
			g.Fill.BackgroundColor3 = if i <= 3 then MINE else THEIRS
		end
	end
end

local function show(state)
	current = state
	if not state then
		gui.Enabled = false
		picked = nil
		clearField()
		return
	end
	gui.Enabled = true
	local over = state.Phase == "Over"
	board.Visible = state.Phase == "Formation"
	bar.Visible = state.Phase == "Battle" or over
	barLeave.Text = if over then "CLOSE" else "LEAVE"
	result.Visible, resultExp.Visible = over, over
	if over then
		clearField()
		result.Text = if state.Result == "Win" then "VICTORY" elseif state.Result == "Lose" then "DEFEAT" else "DRAW"
		result.TextColor3 = if state.Result == "Win" then P.Gold elseif state.Result == "Lose" then P.Bad else P.Text
		resultExp.Text = string.format("+%d EXP for each of your kaiju", state.Exp or 0)
	else
		drawField(state)
	end
	if state.Phase == "Formation" then
		drawBoard(state)
	else
		picked = nil
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
end

function KaijuBattleUI.state()
	return current
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
		local state = current
		local now = os.clock()
		if not state or now < nextTick then
			return
		end
		nextTick = now + 0.2
		local left = clock((state.EndsAt or 0) - serverNow())
		countdown.Text = left
		barClock.Text = if state.Phase == "Over" then "" else left
		if state.Phase ~= "Formation" then
			for i, g in gauges do
				local unit = unitOrder[i]
				if unit then
					local model = unit.Model
					local humanoid = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
					local share = if humanoid and humanoid.MaxHealth > 0
						then humanoid.Health / humanoid.MaxHealth
						else 0
					g.Fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
					g.Frame.BackgroundTransparency = if share <= 0 then 0.6 else 0
					g.Name.TextColor3 = if share <= 0 then P.Dim else P.Text
				end
			end
		end
	end)
end

return KaijuBattleUI
