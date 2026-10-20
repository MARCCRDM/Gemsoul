--[[
	Catching a wild kaiju, on screen (players see "catch"; the code says
	tame: KaijuWilds runs it, Shared.Kaiju.Tame has the rules).

	  Ready     a wild kaiju near you worn down to half its health glows gold
	            (a pulsing Highlight) with READY TO CATCH and the chance over
	            it: it can be caught now. Not while someone's taming it.
	  The cast  while a tame is cast on one (its KaijuTameBy, till
	            KaijuTameEnds), everyone sees a beam of gold light from its
	            tamer to it and motes of light closing in round it as it
	            struggles (its "Bound" pose, CreatureMotion). The tamer gets
	            the cast bar: CATCHING, the chance, and to stay close and not
	            get hit.
	  The end   the tamer's TameResult (at TameResultAt): CAUGHT! with a burst,
	            IT BROKE FREE, IT FLED or CATCH BROKEN on the bar, then it fades.

	  KaijuTaming.start()                         once (KaijuHud.start)
	  KaijuTaming.cast(model, chance, seconds)    the tamer's bar, at once
	                                              (KaijuHud's CATCH)
	  KaijuTaming.casting() -> boolean            a cast of yours is under way
	  KaijuTaming.ready(model) -> boolean         this one can be tamed now
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local CombatSound = require(script.Parent.CombatSound)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local KaijuTaming = {}

local GOLD = Color3.fromRGB(255, 205, 80)
local PALE = Color3.fromRGB(255, 240, 190)
local SHOW = 140 -- studs: how far off a ready one glows
local MOTES = 12

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(model: Model?): BasePart?
	return model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

-- Can this wild kaiju be tamed now: alive, down to half, nobody taming it?
function KaijuTaming.ready(model: Model): boolean
	if not model:GetAttribute("KaijuWild") or model:GetAttribute("KaijuTameBy") ~= nil then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and Kaiju.tameChance(humanoid.Health, humanoid.MaxHealth) > 0
end

-- Ready: the glow and the words over it ----------------------------------------------------------------

type Mark = { Highlight: Highlight, Board: BillboardGui, Text: TextLabel }
local marks: { [Model]: Mark } = {}

local function markOf(model: Model, root: BasePart): Mark
	local mark = marks[model]
	if mark then
		return mark
	end
	local highlight = new("Highlight", {
		Name = "TameReady",
		Adornee = model,
		FillColor = GOLD,
		OutlineColor = GOLD,
		FillTransparency = 0.8,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, model)
	-- (In PlayerGui, so its words are translated: Translate.)
	local height = model:GetExtentsSize().Y
	local board = new("BillboardGui", {
		Name = "TameReadyBoard",
		Adornee = root,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = SHOW,
		Size = UDim2.fromOffset(200, 30),
		StudsOffsetWorldSpace = Vector3.new(0, height * 0.5 + 3.6, 0),
	}, player:WaitForChild("PlayerGui"))
	local text = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = GOLD,
		TextStrokeColor3 = Color3.fromRGB(40, 26, 0),
		TextStrokeTransparency = 0.2,
		Text = "",
	}, board)
	mark = { Highlight = highlight, Board = board, Text = text }
	marks[model] = mark
	return mark
end

local function unmark(model: Model)
	local mark = marks[model]
	if mark then
		marks[model] = nil
		mark.Highlight:Destroy()
		mark.Board:Destroy()
	end
end

-- The cast: a beam from the tamer, motes closing in -----------------------------------------------------

type Hold = {
	Folder: Folder,
	From: Attachment,
	To: Attachment,
	Beams: { Beam },
	Motes: { BasePart },
	Ends: number,
	Start: number,
	Radius: number,
}
local holds: { [Model]: Hold } = {}

local function handOf(tamer: Player): BasePart?
	local character = tamer.Character
	if not character then
		return nil
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return (hand or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

local function release(model: Model)
	local hold = holds[model]
	if hold then
		holds[model] = nil
		hold.Folder:Destroy()
		hold.From:Destroy()
		hold.To:Destroy()
	end
end

local function holdOf(model: Model, root: BasePart): Hold?
	local hold = holds[model]
	if hold then
		return hold
	end
	local tamer = Players:GetPlayerByUserId(model:GetAttribute("KaijuTameBy") or 0)
	local hand = tamer and handOf(tamer)
	if not hand then
		return nil
	end
	local folder = new("Folder", { Name = "TameHold" }, workspace)
	local from = new("Attachment", { Name = "TameFrom" }, hand)
	local to = new("Attachment", { Name = "TameTo" }, root)
	local beams = {}
	for i, spec in { { Width = 1.4, Transparency = 0.55 }, { Width = 0.35, Transparency = 0.05 } } do
		local beam = new("Beam", {
			Name = "TameBeam" .. i,
			Attachment0 = from,
			Attachment1 = to,
			Color = ColorSequence.new(PALE, GOLD),
			LightEmission = 1,
			LightInfluence = 0,
			FaceCamera = true,
			Segments = 24,
			Width0 = spec.Width * 0.5,
			Width1 = spec.Width,
			Transparency = NumberSequence.new(spec.Transparency),
		}, folder)
		table.insert(beams, beam)
	end
	local size = model:GetExtentsSize()
	local motes = {}
	for i = 1, MOTES do
		local mote = new("Part", {
			Name = "TameMote" .. i,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = if i % 3 == 0 then PALE else GOLD,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.55,
		}, folder)
		table.insert(motes, mote)
	end
	local ends = model:GetAttribute("KaijuTameEnds") or serverNow() + Kaiju.Tame.Cast
	hold = {
		Folder = folder,
		From = from,
		To = to,
		Beams = beams,
		Motes = motes,
		Ends = ends,
		Start = ends - Kaiju.Tame.Cast,
		Radius = math.max(size.X, size.Z) * 0.85 + 2,
	}
	holds[model] = hold
	return hold
end

-- The tamer's cast bar ----------------------------------------------------------------------------------

local gui = UiKit.gui("KaijuTaming", 12)
gui.Enabled = false
local bar = new("Frame", {
	Name = "Cast",
	-- (Over the middle of the lower screen: clear of the dock and the loot card.)
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.68),
	Size = UDim2.fromOffset(340, 62),
	BackgroundColor3 = Color3.fromRGB(16, 14, 24),
	BackgroundTransparency = 0.12,
}, gui)
UiKit.round(bar, 12)
local barStroke = new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.15 }, bar)
local title = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.new(1, -80, 0, 20),
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "",
}, bar)
local odds = new("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 6),
	Size = UDim2.fromOffset(70, 20),
	Font = IronUi.Bold,
	TextSize = 14,
	TextColor3 = P.Text,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
}, bar)
local track = new("Frame", {
	Position = UDim2.fromOffset(14, 30),
	Size = UDim2.new(1, -28, 0, 10),
	BackgroundColor3 = Color3.fromRGB(46, 40, 58),
	ClipsDescendants = true,
}, bar)
UiKit.round(track, 5)
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD }, track)
UiKit.round(fill, 5)
local hint = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 43),
	Size = UDim2.new(1, -28, 0, 14),
	Font = IronUi.Body,
	TextSize = 11,
	TextColor3 = P.Dim,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, bar)

-- What the bar is showing: the cast (Model, Ends, Chance), or a result
-- fading (ResultAt).
local cast: { Model: Model?, Ends: number, Seconds: number, Chance: number }? = nil
local resultAt: number? = nil

local function showBar(on: boolean)
	gui.Enabled = on
end

function KaijuTaming.casting(): boolean
	return cast ~= nil
end

function KaijuTaming.cast(model: Model, chance: number, seconds: number)
	local name = (model.Name or "kaiju"):upper()
	cast = { Model = model, Ends = os.clock() + seconds, Seconds = seconds, Chance = chance }
	resultAt = nil
	title.Text = "CATCHING " .. name
	title.TextColor3 = GOLD
	barStroke.Color = GOLD
	odds.Text = string.format("%d%%", math.floor(chance * 100 + 0.5))
	hint.Text = "Stay close and don't get hit."
	fill.BackgroundColor3 = GOLD
	fill.Size = UDim2.fromScale(0, 1)
	showBar(true)
	local root = rootOf(model)
	CombatSound.play("Shield", root and root.Position)
end

-- How it ended (the server's TameResult on you).
local RESULTS = {
	Tamed = {
		Text = "CAUGHT!",
		Hint = "It's yours: find it in your kaiju panel.",
		Color = Color3.fromRGB(120, 230, 140),
	},
	Broke = { Text = "IT BROKE FREE", Hint = "Wear it down more and try again.", Color = Color3.fromRGB(255, 120, 90) },
	Fled = { Text = "IT FLED", Hint = "It burrowed away after its third escape.", Color = Color3.fromRGB(255, 120, 90) },
	Interrupted = { Text = "CATCH BROKEN", Hint = "Stay close and don't get hit.", Color = P.Dim },
}

local function showResult(kind: string)
	local spec = RESULTS[kind]
	if not spec then
		return
	end
	local model = cast and cast.Model
	cast = nil
	resultAt = os.clock()
	title.Text = spec.Text
	title.TextColor3 = spec.Color
	barStroke.Color = spec.Color
	hint.Text = spec.Hint
	odds.Text = ""
	fill.BackgroundColor3 = spec.Color
	fill.Size = UDim2.fromScale(1, 1)
	showBar(true)
	local root = rootOf(model)
	local at = root and root.Position
	if kind == "Tamed" then
		CombatSound.play("Combo", at)
	elseif kind ~= "Interrupted" then
		CombatSound.play("GuardBreak", at)
	end
end

-- Every frame: the glow's pulse, the beams' sway, the motes closing in and
-- the bar filling; a few times a second, which kaiju to mark.
local nextScan = 0
local function step()
	local now = os.clock()
	local inOutpost = player:GetAttribute("Outpost") == true
	if now >= nextScan then
		nextScan = now + 0.25
		local me = rootOf(player.Character :: Model?)
		local enemies = workspace:FindFirstChild("Enemies")
		local seen = {}
		for _, model in if enemies and inOutpost then enemies:GetChildren() else {} do
			if model:IsA("Model") and model:GetAttribute("KaijuWild") then
				local root = rootOf(model)
				if root then
					seen[model] = true
					-- Ready: the glow, if it's near.
					local near = me ~= nil and (root.Position - me.Position).Magnitude <= SHOW
					if near and KaijuTaming.ready(model) then
						local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
						local chance = Kaiju.tameChance(humanoid.Health, humanoid.MaxHealth)
						markOf(model, root).Text.Text =
							string.format("READY TO CATCH · %d%%", math.floor(chance * 100 + 0.5))
					else
						unmark(model)
					end
					-- Held by a tame: the beam and motes.
					if model:GetAttribute("KaijuTameBy") ~= nil then
						holdOf(model, root)
					else
						release(model)
					end
				end
			end
		end
		for model in marks do
			if not seen[model] then
				unmark(model)
			end
		end
		for model in holds do
			if not seen[model] then
				release(model)
			end
		end
	end
	-- The glow pulses.
	local pulse = 0.5 + 0.5 * math.sin(now * 4)
	for _, mark in marks do
		mark.Highlight.FillTransparency = 0.88 - pulse * 0.2
		mark.Highlight.OutlineTransparency = 0.25 - pulse * 0.25
	end
	-- The beams sway; the motes spiral in and up as the hold tightens.
	local server = serverNow()
	for model, hold in holds do
		local root = rootOf(model)
		if root then
			local progress = math.clamp((server - hold.Start) / Kaiju.Tame.Cast, 0, 1)
			for i, beam in hold.Beams do
				local sway = math.sin(now * (7 + i * 3)) * (2.4 - i)
				beam.CurveSize0, beam.CurveSize1 = sway, -sway * 0.6
			end
			local radius = hold.Radius * (1 - progress * 0.55)
			local base = root.Position - Vector3.new(0, root.Size.Y * 0.5, 0)
			for i, mote in hold.Motes do
				local angle = now * (2.2 + progress * 3) + i * (math.pi * 2 / MOTES)
				local rise = (i % 3) * 1.2 + progress * 3 + math.sin(now * 3 + i) * 0.4
				mote.Position = base + Vector3.new(math.cos(angle) * radius, rise, math.sin(angle) * radius)
			end
		end
	end
	-- The bar.
	if cast then
		local left = cast.Ends - now
		fill.Size = UDim2.fromScale(math.clamp(1 - left / cast.Seconds, 0, 1), 1)
		if left < -3 then
			-- (No word from the server: let it go.)
			cast = nil
			showBar(false)
		end
	elseif resultAt then
		local since = now - resultAt
		if since > 1.8 then
			resultAt = nil
			showBar(false)
		end
	end
end

local started = false
function KaijuTaming.start()
	if started then
		return
	end
	started = true
	player:GetAttributeChangedSignal("TameResultAt"):Connect(function()
		local kind = player:GetAttribute("TameResult")
		if type(kind) == "string" then
			showResult(kind)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[KaijuTaming]", err)
		end
	end)
end

return KaijuTaming
