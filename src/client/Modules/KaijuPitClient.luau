--[[
	The Kaiju Arena downstairs, on your screen (Server.KaijuPitServer runs
	it, Shared.KaijuPit has its rules):

	  The courts' boards   each court's board, hung over its middle, says
	                       what's on: OPEN, WAITING FOR A CHALLENGER (and
	                       who), PLACING or FIGHT with the clock, BLUE vs RED
	                       with each side's kaiju's health, the winner, and
	                       the stake. (From the court's attributes.)
	  The pedestal         by each court: the stake shown over it, a gem
	                       turning in its colour or a stack of coins, and
	                       what the winner takes.
	  The pads             lit while someone stands on them.
	  Your pad's card      waiting: the court, and a stake to choose (coins
	                       or one of your loose gems, KaijuPitStake), then
	                       who's stepped up. Challenging: who's waiting and
	                       for what, your gem to match a gem stake with, and
	                       FIGHT (KaijuPitFight). Step off to stop.
	  The stairs           dark a moment going down or up.

	  KaijuPitClient.start()       once (Lobby.client)
	  KaijuPitClient.showPad(card) draw your pad's card (nil: none)
	  KaijuPitClient.drawBoard(model)   one court's board (renders)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local KaijuPit = require(ReplicatedStorage.Shared.KaijuPit)
local Lang = require(ReplicatedStorage.Shared.Lang)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local new = IronUi.new
local BOLD = IronUi.Bold

local KaijuPitClient = {}

local BLUE = Color3.fromRGB(70, 160, 255)
local RED = Color3.fromRGB(255, 84, 72)
local HAZARD = Color3.fromRGB(240, 178, 48)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function label(parent: Instance, props): TextLabel
	props.BackgroundTransparency = 1
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.Font = props.Font or Enum.Font.GothamBold
	return new("TextLabel", props, parent)
end

-- The boards -----------------------------------------------------------------------------------------------

type Board = {
	Model: Model,
	Faces: { any },
	Ring: { [string]: BasePart },
	Stake: Model?,
	StakeKey: string?,
	Billboard: BillboardGui?,
}
local boards: { [Model]: Board } = {}

-- One face of a court's board (a SurfaceGui on its Board part).
local function face(part: BasePart, side: Enum.NormalId)
	local surface = new("SurfaceGui", {
		Name = "Board" .. side.Name,
		Face = side,
		CanvasSize = Vector2.new(600, 240),
		LightInfluence = 0,
		Brightness = 1.2,
	}, part)
	local back = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 16, 22), BorderSizePixel = 0 },
		surface
	)
	local title = label(
		back,
		{
			Name = "Title",
			Position = UDim2.fromScale(0.04, 0.04),
			Size = UDim2.fromScale(0.5, 0.16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = HAZARD,
			Font = Enum.Font.Oswald,
		}
	)
	local status = label(
		back,
		{
			Name = "Status",
			Position = UDim2.fromScale(0.46, 0.04),
			Size = UDim2.fromScale(0.5, 0.16),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = P.Text,
		}
	)
	local blue = label(
		back,
		{
			Name = "Blue",
			Position = UDim2.fromScale(0.04, 0.27),
			Size = UDim2.fromScale(0.42, 0.2),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = BLUE,
		}
	)
	local versus = label(
		back,
		{
			Name = "Versus",
			Position = UDim2.fromScale(0.46, 0.29),
			Size = UDim2.fromScale(0.08, 0.16),
			TextColor3 = P.Dim,
			Text = "VS",
		}
	)
	local red = label(
		back,
		{
			Name = "Red",
			Position = UDim2.fromScale(0.54, 0.27),
			Size = UDim2.fromScale(0.42, 0.2),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = RED,
		}
	)
	local function track(x: number, color: Color3)
		local t = new(
			"Frame",
			{
				Position = UDim2.fromScale(x, 0.52),
				Size = UDim2.fromScale(0.42, 0.07),
				BackgroundColor3 = Color3.fromRGB(40, 44, 54),
				BorderSizePixel = 0,
			},
			back
		)
		local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, t)
		return t, f
	end
	local blueTrack, blueFill = track(0.04, BLUE)
	local redTrack, redFill = track(0.54, RED)
	local stake = label(
		back,
		{
			Name = "Stake",
			Position = UDim2.fromScale(0.04, 0.68),
			Size = UDim2.fromScale(0.92, 0.14),
			TextColor3 = P.Gold,
		}
	)
	local line = label(
		back,
		{
			Name = "Line",
			Position = UDim2.fromScale(0.04, 0.84),
			Size = UDim2.fromScale(0.92, 0.11),
			TextColor3 = P.Dim,
			Font = Enum.Font.GothamMedium,
		}
	)
	for _, l in { blue, red } do
		l:SetAttribute("NoTranslate", true)
	end
	return {
		Title = title,
		Status = status,
		Blue = blue,
		Red = red,
		Versus = versus,
		BlueTrack = blueTrack,
		BlueFill = blueFill,
		RedTrack = redTrack,
		RedFill = redFill,
		Stake = stake,
		Line = line,
	}
end

-- What's over the pedestal: a gem turning in its colour, or a stack of coins.
local function stakeModel(entry: Board, model: Model)
	local kind = model:GetAttribute("StakeKind")
	local key = tostring(kind)
		.. "/"
		.. tostring(model:GetAttribute("StakeElement"))
		.. "/"
		.. tostring(model:GetAttribute("StakeCoins"))
	if entry.StakeKey == key then
		return
	end
	entry.StakeKey = key
	if entry.Stake then
		entry.Stake:Destroy()
		entry.Stake = nil
	end
	if entry.Billboard then
		entry.Billboard:Destroy()
		entry.Billboard = nil
	end
	local pedestal = model:FindFirstChild("Pedestal") :: BasePart?
	if not kind or not pedestal then
		return
	end
	local holder = new("Model", { Name = "StakeShown" }, model)
	local top = pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + 1.6, 0)
	local function piece(size: Vector3, color: Color3, at: CFrame, material: Enum.Material, shape: Enum.PartType?)
		local p = new("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Size = size,
			Color = color,
			Material = material,
			CFrame = at,
		}, holder)
		if shape then
			p.Shape = shape
		end
		return p
	end
	if kind == "Gem" then
		local color = GemConfig.ElementColors[model:GetAttribute("StakeElement") or ""] or P.Gold
		local gem =
			piece(Vector3.new(1.1, 1.6, 1.1), color, top * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon)
		gem.Name = "Gem"
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = color, 8, 1
		light.Parent = gem
	else
		for i = 0, 2 do
			piece(
				Vector3.new(0.25, 1.4, 1.4),
				P.Gold,
				top * CFrame.new(0, -0.9 + i * 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
	end
	entry.Stake = holder
	-- What it is, over it.
	local billboard = new("BillboardGui", {
		Name = "Pot",
		Adornee = pedestal,
		Size = UDim2.fromOffset(170, 44),
		StudsOffset = Vector3.new(0, pedestal.Size.Y / 2 + 4.2, 0),
		MaxDistance = 90,
		AlwaysOnTop = false,
	}, model)
	local back = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.Frame, BackgroundTransparency = 0.2 },
		billboard
	)
	UiKit.round(back, 8)
	new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.3 }, back)
	label(
		back,
		{
			Name = "Head",
			Position = UDim2.fromScale(0.05, 0.08),
			Size = UDim2.fromScale(0.9, 0.38),
			Text = Lang.translate("STAKE"),
			TextColor3 = P.Dim,
		}
	)
	label(
		back,
		{
			Name = "Pot",
			Position = UDim2.fromScale(0.05, 0.48),
			Size = UDim2.fromScale(0.9, 0.44),
			Text = "",
			TextColor3 = P.Gold,
		}
	)
	entry.Billboard = billboard
end

function KaijuPitClient.drawBoard(model: Model)
	local entry = boards[model]
	if not entry then
		local part = model:FindFirstChild("Board") :: BasePart?
		if not part then
			return
		end
		entry =
			{ Model = model, Faces = { face(part, Enum.NormalId.Front), face(part, Enum.NormalId.Back) }, Ring = {} }
		for _, side in { "A", "B" } do
			entry.Ring[side] = model:FindFirstChild("Pad" .. side) :: BasePart
		end
		boards[model] = entry
	end
	local number = model:GetAttribute("Court") or 0
	local state = model:GetAttribute("State") or "Open"
	local phase = model:GetAttribute("Phase")
	local endsAt = model:GetAttribute("EndsAt")
	local aName, bName = model:GetAttribute("AName"), model:GetAttribute("BName")
	local winner = model:GetAttribute("Winner")
	local stake = model:GetAttribute("Stake")
	local pot = model:GetAttribute("Pot")
	local status, statusColor = "OPEN", P.Good
	if state == "Waiting" then
		status, statusColor = "WAITING FOR A CHALLENGER", HAZARD
	elseif state == "Challenged" then
		status, statusColor = "CHALLENGER STEPPED UP", HAZARD
	elseif state == "Battle" then
		local left = if endsAt then clock(endsAt - serverNow()) else ""
		if winner then
			status, statusColor = if winner == "Draw" then "A DRAW" else string.upper(winner) .. " WINS", P.Gold
		elseif phase == "Formation" then
			status, statusColor = "PLACING  ·  " .. left, HAZARD
		else
			status, statusColor = "FIGHTING  ·  " .. left, RED
		end
	end
	local fighting = state == "Battle" and phase ~= "Formation"
	-- (Boards are in the world, not on screen: they're put in the player's language here.)
	local tr = Lang.translate
	for _, f in entry.Faces do
		f.Title.Text = tr("COURT " .. number)
		f.Status.Text = tr(status)
		f.Status.TextColor3 = statusColor
		f.Blue.Text = if aName
			then string.upper(aName)
			else (if state == "Open" then "" else tr("STEP ON THE BLUE PAD"))
		f.Red.Text = if bName then string.upper(bName) else (if state == "Open" then "" else tr("STEP ON THE RED PAD"))
		f.Versus.Visible = state ~= "Open"
		f.BlueTrack.Visible, f.RedTrack.Visible = fighting, fighting
		f.BlueFill.Size = UDim2.fromScale(math.clamp(model:GetAttribute("AShare") or 1, 0, 1), 1)
		f.RedFill.Size = UDim2.fromScale(math.clamp(model:GetAttribute("BShare") or 1, 0, 1), 1)
		f.Stake.Text = if stake and model:GetAttribute("StakeKind")
			then tr(string.upper(stake) .. "  ·  WINNER TAKES " .. string.upper(pot or ""))
			else ""
		f.Line.Text = if state == "Open" then tr("STAND ON A PAD TO WAIT FOR A CHALLENGER") else ""
	end
	-- The pads: lit while someone's on them.
	for side, ring in entry.Ring do
		local here = model:GetAttribute(side .. "Id") ~= nil
		ring.Transparency = if here then 0 else 0.45
	end
	stakeModel(entry, model)
	if entry.Billboard then
		local potLabel = entry.Billboard:FindFirstChild("Pot", true) :: TextLabel?
		if potLabel then
			potLabel.Text = Lang.translate(string.upper(pot or ""))
		end
	end
end

-- Your pad's card ------------------------------------------------------------------------------------------

local gui = UiKit.gui("KaijuPit", 14)
local card = new("Frame", {
	Name = "Pad",
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.05,
	Visible = false,
	AutomaticSize = Enum.AutomaticSize.Y,
}, gui)
UiKit.round(card, 12)
local cardStroke = new("UIStroke", { Color = HAZARD, Thickness = 1.5 }, card)
UiKit.pad(card, 12)
UiKit.list(card, 7)
local heading = IronUi.text(card, "", 16, P.Text, IronUi.Heading)
heading.LayoutOrder = 1
local sub = IronUi.text(card, "", 12, P.Dim, IronUi.Body)
sub.LayoutOrder = 2
sub.TextWrapped = true
local stakeRow =
	new("Frame", { Name = "Stakes", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3 }, card)
UiKit.list(stakeRow, 6, true)
local staked = IronUi.text(card, "", 12, P.Gold, BOLD)
staked.LayoutOrder = 4
staked.TextWrapped = true
local gemRow = new("ScrollingFrame", {
	Name = "Gems",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 80),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 4,
	LayoutOrder = 5,
	Visible = false,
}, card)
UiKit.list(gemRow, 6, true)
local problem = IronUi.text(card, "", 12, P.Bad, BOLD)
problem.LayoutOrder = 6
problem.TextWrapped = true
local fightButton, fightFace =
	IronUi.chunk(card, { Color = P.Gold, Size = UDim2.new(1, 0, 0, 40), Radius = 8, Stripes = "None" })
fightButton.LayoutOrder = 7
IronUi.label(fightButton, fightFace, "FIGHT!", 17, BOLD)
local foot = IronUi.text(card, "", 10, P.Dim, IronUi.Body)
foot.LayoutOrder = 8
foot.TextWrapped = true

local shown = nil -- the card last told
local chosenGem: string? = nil -- the gem picked to match a gem stake

local function request(action: string, ...)
	local args = table.pack(...)
	task.spawn(function()
		local reply = GemClient.request(action, table.unpack(args, 1, args.n))
		if reply and not reply.Ok and reply.Message and reply.Message ~= "" then
			UiKit.toast(reply.Message, P.Bad)
		end
	end)
end

local function chip(text: string, on: boolean, enabled: boolean, onClick: () -> ()): TextButton
	-- (Tighter on a phone, so the whole row fits.)
	local short = UiKit.short()
	local b = new("TextButton", {
		Text = text,
		Font = BOLD,
		TextSize = if short then 11 else 12,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		TextColor3 = if on then P.Ink elseif enabled then P.Text else P.Dim,
		BackgroundColor3 = if on then P.Gold else P.Inset,
		AutoButtonColor = enabled,
	}, stakeRow)
	UiKit.round(b, 7)
	new(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, if short then 7 else 10), PaddingRight = UDim.new(0, if short then 7 else 10) },
		b
	)
	new(
		"UIStroke",
		{ Color = if on then P.Gold else P.Edge, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		b
	)
	b:SetAttribute("UiSound", "Click")
	if enabled then
		b.Activated:Connect(onClick)
	end
	return b
end

-- A gem as a tile (to stake, or to match one with).
local function gemTile(gem, on: boolean, onClick: () -> ())
	local tier = GemConfig.TierColors[gem.Tier] or P.Edge
	local b = new("TextButton", {
		Name = "Gem",
		Text = "",
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = if on then tier:Lerp(P.Frame, 0.6) else P.Inset,
		AutoButtonColor = true,
	}, gemRow)
	UiKit.round(b, 8)
	new("UIStroke", { Color = tier, Thickness = if on then 2.5 else 1, Transparency = if on then 0 else 0.4 }, b)
	local ok, view = pcall(GemArt.viewport, b, gem)
	if ok and view then
		view.Size = UDim2.fromOffset(44, 44)
		view.Position = UDim2.new(0.5, -22, 0, 3)
	end
	-- (Two lines, so the name reads whole.)
	local name = IronUi.text(b, GemConfig.displayName(gem), 9, tier, BOLD)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextWrapped = true
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Position, name.Size = UDim2.new(0, 2, 1, -23), UDim2.new(1, -4, 0, 20)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
end

local function clearRows()
	for _, row in { stakeRow, gemRow } do
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
end

local gemPicking = false -- the host's loose gems up, to stake one

function KaijuPitClient.showPad(state)
	shown = state
	clearRows()
	if not state then
		card.Visible = false
		chosenGem, gemPicking = nil, false
		return
	end
	card.Visible = true
	local short = UiKit.short()
	card.Size = UDim2.fromOffset(math.min(if short then 380 else 440, gui.AbsoluteSize.X - 24), 0)
	card.Position = UDim2.new(0.5, 0, 1, if short then -8 else -26)
	local stake = state.Stake
	local profile = GemClient.Profile
	local coins = (profile and profile.Coins) or 0
	if state.Host then
		cardStroke.Color = HAZARD
		heading.Text = if state.Foe then state.Foe .. " STEPPED UP!" else "WAITING ON COURT " .. state.Court
		heading:SetAttribute("NoTranslate", state.Foe ~= nil)
		sub.Text = if state.Foe
			then "They're deciding. When they say FIGHT, you'll both place your kaiju."
			else "Someone steps onto the other pad to take you on. Play for something?"
		stakeRow.Visible = true
		chip("NO STAKE", stake == nil, true, function()
			request("KaijuPitStake", nil)
		end)
		for _, amount in KaijuPit.CoinStakes do
			local on = stake ~= nil and stake.Kind == "Coins" and stake.Coins == amount
			chip(tostring(amount), on, coins >= amount, function()
				request("KaijuPitStake", { Kind = "Coins", Coins = amount })
			end)
		end
		local gemOn = stake ~= nil and stake.Kind == "Gem"
		chip("A GEM", gemOn, true, function()
			gemPicking = not gemPicking
			KaijuPitClient.showPad(shown)
		end)
		gemRow.Visible = gemPicking
		if gemPicking then
			for i, gem in GemInventory.available(profile) do
				if i > 16 then
					break
				end
				gemTile(gem, gemOn and stake.Gem.Id == tostring(gem.Id), function()
					gemPicking = false
					request("KaijuPitStake", { Kind = "Gem", GemId = tostring(gem.Id) })
				end)
			end
		end
		-- What's on the line, spelled out (the gem's also on the pedestal).
		staked.Text = if stake == nil
			then ""
			elseif stake.Kind == "Gem" then "YOUR STAKE: " .. string.upper(stake.Gem.Name or "")
			else "YOUR STAKE: " .. stake.Coins .. " COINS"
		staked.Visible = stake ~= nil
		problem.Text = state.Problem or ""
		problem.Visible = state.Problem ~= nil
		fightButton.Visible = false
		foot.Text = "Step off the pad to stop waiting."
	else
		cardStroke.Color = P.Gold
		heading.Text = string.upper(state.Foe or "Someone") .. " IS WAITING"
		heading:SetAttribute("NoTranslate", true)
		sub.Text = if stake
			then "For " .. KaijuPit.stakeText(stake) .. ": the winner takes " .. string.lower(
				KaijuPit.pot(stake, stake)
			) .. "."
			else "Just for the glory. Your kaiju battle on court " .. state.Court .. "."
		stakeRow.Visible = false
		staked.Visible = false
		gemRow.Visible = stake ~= nil and stake.Kind == "Gem"
		if gemRow.Visible then
			local mine = state.Mine or {}
			local ids = {}
			for _, gem in mine do
				ids[gem.Id] = true
			end
			-- (Your weakest one that matches, unless you've picked another.)
			if not chosenGem or not ids[chosenGem] then
				chosenGem = if mine[1] then mine[1].Id else nil
			end
			for _, gem in mine do
				gemTile(gem, gem.Id == chosenGem, function()
					chosenGem = gem.Id
					KaijuPitClient.showPad(shown)
				end)
			end
		end
		problem.Text = state.Problem or ""
		problem.Visible = state.Problem ~= nil
		fightButton.Visible = true
		fightButton.AutoButtonColor = state.Problem == nil
		fightFace.BackgroundColor3 = if state.Problem then P.Slot else P.Gold
		foot.Text = "Step off the pad to say no."
	end
end

fightButton.Activated:Connect(function()
	local state = shown
	if not state or state.Host or state.Problem then
		return
	end
	request("KaijuPitFight", if state.Stake and state.Stake.Kind == "Gem" then chosenGem else nil)
end)

-- The stairs: dark a moment.
local function crossing(down: boolean)
	local layer = UiKit.gui("KaijuPitCrossing", 40)
	layer.IgnoreGuiInset = true
	local shade = new(
		"Frame",
		{ BackgroundColor3 = Color3.fromRGB(6, 7, 10), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1) },
		layer
	)
	label(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0.8, 0, 0, 40),
		TextScaled = false,
		TextSize = 34,
		Text = if down then "KAIJU ARENA" else "THE SHELTER",
		TextColor3 = if down then RED else HAZARD,
		Font = IronUi.Heading,
	})
	label(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.45, 34),
		Size = UDim2.new(0.8, 0, 0, 20),
		TextScaled = false,
		TextSize = 14,
		Text = if down then "Stand on a pad to battle. Watch from anywhere." else "Back upstairs.",
		TextColor3 = P.Dim,
		Font = IronUi.Body,
	})
	task.delay(0.45, function()
		local fade = TweenInfo.new(0.5)
		TweenService:Create(shade, fade, { BackgroundTransparency = 1 }):Play()
		for _, child in shade:GetChildren() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, fade, { TextTransparency = 1 }):Play()
			end
		end
		task.delay(0.6, function()
			layer:Destroy()
		end)
	end)
end

local started = false
function KaijuPitClient.start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Social").OnClientEvent:Connect(function(kind: string, value)
		if kind == "KaijuPitPad" then
			KaijuPitClient.showPad(value)
		elseif kind == "KaijuPitCross" then
			crossing(value == "Down")
			if value == "Up" then
				KaijuPitClient.showPad(nil)
			end
		end
	end)
	-- The boards: drawn as their courts change, the clocks and the turning
	-- gems a few times a second while you're down there.
	task.spawn(function()
		local hall = workspace:WaitForChild("KaijuPit", 60)
		local courts = hall and hall:WaitForChild("Courts", 30)
		if not courts then
			return
		end
		-- (Upstairs, someone starting to wait down here is news: once a
		-- minute at most. GroundGuide shows the way to the stairs.)
		local toldAt = -math.huge
		local me = Players.LocalPlayer
		local function watch(model: Instance)
			if not model:IsA("Model") then
				return
			end
			KaijuPitClient.drawBoard(model)
			local was = model:GetAttribute("State")
			model.AttributeChanged:Connect(function()
				KaijuPitClient.drawBoard(model)
				local state = model:GetAttribute("State")
				if
					state == "Waiting"
					and was ~= "Waiting"
					and not me:GetAttribute("KaijuPit")
					and not me:GetAttribute("RiftRun")
				then
					local name = model:GetAttribute("AName") or model:GetAttribute("BName")
					if name and os.clock() - toldAt > 60 then
						toldAt = os.clock()
						UiKit.toast(name .. " is waiting for a kaiju battle downstairs. Follow the arrows!", HAZARD)
					end
				end
				was = state
			end)
		end
		for _, model in courts:GetChildren() do
			watch(model)
		end
		courts.ChildAdded:Connect(watch)
		local nextTick, spin = 0, 0
		RunService.Heartbeat:Connect(function(dt)
			if Players.LocalPlayer:GetAttribute("KaijuPit") ~= true then
				return
			end
			spin += dt
			for model, entry in boards do
				local gem = entry.Stake and entry.Stake:FindFirstChild("Gem") :: BasePart?
				local pedestal = model:FindFirstChild("Pedestal") :: BasePart?
				if gem and pedestal then
					local top = pedestal.CFrame
						* CFrame.new(0, pedestal.Size.Y / 2 + 1.6 + math.sin(spin * 2) * 0.15, 0)
					gem.CFrame = top * CFrame.Angles(0, spin * 1.5, math.rad(45))
				end
			end
			local now = os.clock()
			if now >= nextTick then
				nextTick = now + 0.5
				for model in boards do
					if model:GetAttribute("State") == "Battle" then
						KaijuPitClient.drawBoard(model)
					end
				end
			end
		end)
	end)
end

return KaijuPitClient
