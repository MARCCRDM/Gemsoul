--[[
	The Kaiju Kennel's residents (Shared.KaijuKennel): today's kaiju in the
	pen on the Shelter's stage, wandering their wedges of it, stopping to
	sniff the ground, look about, lie down, nap or roar. Drawn by each
	player's own client from the server's clock (everyone sees the same),
	posed by CreatureAnimation like any kaiju (it walks them at their
	PacedSpeed: they're moved, not pushed, so they have no velocity of
	their own).

	None of them collides, casts about for clicks or can be hit; they're
	only there while you're in the Outpost and near the Shelter, and a new
	day brings new ones.

	The pen they're in is built here too, not by the server (the Shelter's
	server-built parts are at their budget): its fence (solid to you: your
	own character's, built on your own screen), the rock and troughs, the
	KENNEL arch over the gate, and in front of it the Daily Kaiju Sale: the
	Kaiju of the Day (KaijuKennel.special) turning on a plinth, its board
	beside it, and a prompt that opens the sale (Client.KennelSale).

	  KennelLife.mount(at)   the Shelter's frame (once)
	  KennelLife.show(on)    shows or hides them
	  KennelLife.step(dt)    moves them (30 times a second at most)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kennel = require(Shared:WaitForChild("KaijuKennel"))
local Kaiju = require(Shared:WaitForChild("Kaiju"))
local KaijuModels = require(Shared:WaitForChild("KaijuModels"))
local GemConfig = require(Shared:WaitForChild("GemConfig"))
local Store = require(Shared:WaitForChild("Store"))
local KennelSale = require(script.Parent.KennelSale)

local KennelLife = {}
KennelLife.Reach = 260 -- studs from the pen: past this they're put away

type Resident = { Model: Model, Root: BasePart, Lift: number, Mood: string?, MoodAt: number? }

local at: CFrame? = nil
local folder: Folder? = nil
local pen: Folder? = nil -- (the pen and the sale's display: built once, shown with them)
local display: Model? = nil -- (the Kaiju of the Day on its plinth: built again each day)
local board: { [string]: TextLabel } = {}
local residents: { Resident } = {}
local shownDay: number? = nil
local wanted = false
local clock = 0

-- One resident: its kind's model at the kennel's size, a Humanoid only so
-- CreatureAnimation takes it for a kaiju (it never runs: the root is
-- anchored and moved), nothing on it touchable.
local function resident(entry): Resident
	local model = KaijuModels.build(entry.Species, entry.Element)
	KaijuModels.scale(model, Kennel.Scale)
	model.Name = "Kennel" .. entry.Species
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		end
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	local humanoid = Instance.new("Humanoid")
	humanoid.EvaluateStateMachine = false
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	model:SetAttribute("PacedSpeed", 0)
	model:SetAttribute("Kennel", true)
	return {
		Model = model,
		Root = root,
		-- (its root's height over its feet: hips and any hover)
		Lift = (model:GetAttribute("KaijuHipHeight") or 1) + root.Size.Y / 2,
	}
end

local function clear()
	for _, r in residents do
		r.Model:Destroy()
	end
	table.clear(residents)
end

-- The pen's look: dark steel and the hall's hazard gold, the board in the
-- gilt look of the game's windows (Client GiltUi).
local STEEL = Color3.fromRGB(70, 74, 82)
local DARK = Color3.fromRGB(46, 48, 56)
local HAZARD = Color3.fromRGB(240, 178, 48)
local GOLD = Color3.fromRGB(228, 188, 100)
local IVORY = Color3.fromRGB(236, 224, 200)
local FADED = Color3.fromRGB(162, 146, 118)
local SERIF = Enum.Font.Merriweather

local function piece(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CanQuery = solid == true
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 2
	p.Size, p.CFrame, p.Color, p.Material = size, cframe, color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cylinder(parent: Instance, cframe: CFrame, radius: number, height: number, color: Color3, material: Enum.Material, solid: boolean?): Part
	local p = piece(parent, cframe * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, radius * 2, radius * 2), color, material, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Words on a face of `carrier`: one line, serif, in `color`.
local function line(gui: SurfaceGui, text: string, y: number, h: number, size: number, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position, l.Size = UDim2.fromScale(0.06, y), UDim2.fromScale(0.88, h)
	l.Font = font or SERIF
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Center
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = size
	cap.Parent = l
	l.Parent = gui
	return l
end

local function surface(carrier: BasePart, pixels: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0.2
	gui.Brightness = 1.2
	gui.Parent = carrier
	return gui
end

-- The pen: a fence of posts and two rails round the bed, a rock in the
-- middle, troughs by the fence, the KENNEL arch over the gate (facing the
-- hall's door, +Z). And the sale's plinth and board in front of it.
local function buildPen(frame: CFrame): Folder
	local made = Instance.new("Folder")
	made.Name = "KennelPen"
	local top = frame * CFrame.new(Kennel.Pen.Middle)
	local fenceR = Kennel.Pen.Fence
	for _, rock in { { 0, 0, 3.2, 2.2 }, { 1.4, -0.9, 2.2, 1.4 }, { -1.1, 1, 1.8, 1.1 } } do
		piece(made, top * CFrame.new(rock[1], rock[4] / 2 - 0.2, rock[2]) * CFrame.Angles(0.2, rock[1], 0.15),
			Vector3.new(rock[3], rock[4], rock[3] * 0.9), Color3.fromRGB(96, 90, 84), Enum.Material.Slate)
	end
	for _, a in { 30, 150, 230, 310 } do
		local spot = top * CFrame.Angles(0, math.rad(-a), 0) * CFrame.new(0, 0, -10)
		piece(made, spot * CFrame.new(0, 0.35, 0), Vector3.new(3, 0.7, 1.1), DARK, Enum.Material.Metal)
		piece(made, spot * CFrame.new(0, 0.66, 0), Vector3.new(2.6, 0.06, 0.8), Color3.fromRGB(70, 120, 150), Enum.Material.Glass)
	end
	local posts = 28
	for i = 0, posts - 1 do
		local a = math.rad(i * 360 / posts)
		local b = math.rad((i + 1) * 360 / posts)
		local pa = top * CFrame.new(math.cos(a) * fenceR, 0, math.sin(a) * fenceR)
		local pb = top * CFrame.new(math.cos(b) * fenceR, 0, math.sin(b) * fenceR)
		piece(made, pa * CFrame.new(0, 1.6, 0), Vector3.new(0.45, 3.2, 0.45), STEEL, Enum.Material.Metal, true)
		piece(made, pa * CFrame.new(0, 3.28, 0), Vector3.new(0.6, 0.16, 0.6), HAZARD, Enum.Material.Metal)
		local mid = (pa.Position + pb.Position) / 2
		local span = (pb.Position - pa.Position).Magnitude
		for _, h in { 1.1, 2.6 } do
			piece(made, CFrame.lookAt(mid, pb.Position) * CFrame.new(0, h, 0), Vector3.new(0.18, 0.22, span), STEEL, Enum.Material.Metal, true)
		end
	end
	-- The arch over the gate, KENNEL across its board.
	local front = top * CFrame.new(0, 0, fenceR + 0.2)
	local facingDoor = CFrame.lookAt(front.Position, front.Position + (front.Position - top.Position) * Vector3.new(1, 0, 1))
	for _, side in { -3.4, 3.4 } do
		piece(made, facingDoor * CFrame.new(side, 3, 0), Vector3.new(0.8, 6, 0.8), DARK, Enum.Material.Metal, true)
	end
	local sign = piece(made, facingDoor * CFrame.new(0, 6.3, 0), Vector3.new(8.4, 1.6, 0.4), DARK, Enum.Material.Metal)
	sign.Name = "KennelSign"
	line(surface(sign, 40), "KENNEL", 0.12, 0.76, 60, HAZARD, Enum.Font.GothamBlack)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 214, 150), 14, 0.6
	glow.Parent = sign
	-- The Daily Kaiju Sale: a plinth (its kaiju put on it by stockDisplay)
	-- and its board beside it, both turned to the door.
	local base = frame * CFrame.new(Kennel.Display)
	cylinder(made, base * CFrame.new(0, 0.3, 0), 2.3, 0.6, DARK, Enum.Material.Metal, true).Name = "SalePlinth"
	cylinder(made, base * CFrame.new(0, 0.63, 0), 2.1, 0.06, GOLD, Enum.Material.Metal)
	cylinder(made, base * CFrame.new(0, 0.67, 0), 1.9, 0.04, Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
	local stand = base * CFrame.new(4.6, 0, 0.6) * CFrame.Angles(0, math.rad(180 + 18), 0)
	for _, side in { -2.5, 2.5 } do
		piece(made, stand * CFrame.new(side, 1.9, 0.12), Vector3.new(0.28, 3.8, 0.28), DARK, Enum.Material.Metal)
	end
	local face = piece(made, stand * CFrame.new(0, 2.5, 0), Vector3.new(5.4, 3, 0.18), Color3.fromRGB(20, 17, 14), Enum.Material.SmoothPlastic, true)
	face.Name = "SaleBoard"
	local gui = surface(face, 60)
	local rim = Instance.new("UIStroke")
	rim.Color, rim.Thickness, rim.Transparency = GOLD, 3, 0.25
	local inset = Instance.new("Frame")
	inset.BackgroundTransparency = 1
	inset.Position, inset.Size = UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.94, 0.9)
	rim.Parent = inset
	inset.Parent = gui
	board.Kicker = line(gui, "DAILY KAIJU SALE", 0.1, 0.13, 40, GOLD)
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = GOLD
	rule.BackgroundTransparency = 0.45
	rule.Position, rule.Size = UDim2.fromScale(0.2, 0.26), UDim2.fromScale(0.6, 0.008)
	rule.Parent = gui
	board.Name = line(gui, "", 0.31, 0.22, 64, IVORY)
	board.Kind = line(gui, "", 0.54, 0.11, 30, FADED)
	board.Price = line(gui, "", 0.7, 0.16, 44, GOLD)
	board.Note = line(gui, "Only today  ·  a new kaiju every midnight", 0.86, 0.08, 22, FADED)
	-- (the prompt that opens the sale: on the plinth)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "View"
	prompt.ObjectText = "Daily Kaiju Sale"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		KennelSale.open()
	end)
	local anchor = piece(made, base * CFrame.new(0, 2.5, 0), Vector3.new(1, 1, 1), DARK, Enum.Material.SmoothPlastic)
	anchor.Transparency, anchor.Name = 1, "SalePrompt"
	prompt.Parent = anchor
	return made
end

-- The Kaiju of the Day on the plinth, and its board, for `day`.
local function stockDisplay(day: number)
	if not (at and pen) then
		return
	end
	if display then
		display:Destroy()
		display = nil
	end
	local special = Kennel.special(day)
	local model = KaijuModels.build(special.Species, special.Element)
	KaijuModels.scale(model, Kennel.Scale * 1.1)
	model.Name = "SaleKaiju"
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanTouch, p.CanQuery, p.Anchored = false, false, false, true
		end
	end
	model:SetAttribute("Lift", (model:GetAttribute("KaijuHipHeight") or 1) + (model.PrimaryPart :: BasePart).Size.Y / 2)
	model.Parent = pen
	display = model
	local kind = Kaiju.species(special.Species)
	board.Name.Text = string.upper(kind and kind.Name or special.Species)
	board.Kind.Text = string.format(
		"%s  ·  %s",
		GemConfig.elementName(special.Element),
		kind and kind.Role or "Kaiju"
	)
	board.Price.Text = string.format("R$ %d", Store.robuxPrice(Kaiju.Sale.Daily.Product) or 0)
end

-- The display's kaiju turns slowly on its plinth.
local function turnDisplay(now: number)
	if not (display and display.PrimaryPart and at) then
		return
	end
	local lift = display:GetAttribute("Lift") or 1
	local base = at * CFrame.new(Kennel.Display + Vector3.new(0, 0.7 + lift, 0))
	display:PivotTo(base * CFrame.Angles(0, (now * 0.35) % (math.pi * 2), 0))
end

-- Today's residents, built (again, when the day turns), and the sale's kaiju.
local function stock(now: number)
	local day = Kennel.day(now)
	if day == shownDay then
		return
	end
	shownDay = day
	clear()
	for _, entry in Kennel.residents(day) do
		local r = resident(entry)
		r.Model.Parent = folder
		table.insert(residents, r)
	end
	stockDisplay(day)
end

function KennelLife.pose(now: number)
	if not at then
		return
	end
	local parts, cframes = {}, {}
	for i, r in residents do
		local s = Kennel.state(i, #residents, now)
		table.insert(parts, r.Root)
		table.insert(cframes, at * CFrame.new(s.Position + Vector3.new(0, r.Lift, 0)) * CFrame.Angles(0, s.Yaw, 0))
		if r.Model:GetAttribute("PacedSpeed") ~= s.Speed then
			r.Model:SetAttribute("PacedSpeed", s.Speed)
		end
		if s.Mood ~= r.Mood or s.MoodAt ~= r.MoodAt then
			r.Mood, r.MoodAt = s.Mood, s.MoodAt
			r.Model:SetAttribute("KaijuMood", s.Mood)
			r.Model:SetAttribute("KaijuMoodAt", s.MoodAt)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function KennelLife.mount(frame: CFrame)
	if at then
		return
	end
	at = frame
	local made = Instance.new("Folder")
	made.Name = "KaijuKennel" -- (CreatureAnimation looks in here too)
	folder = made
	pen = buildPen(frame)
end

local function near(): boolean
	local camera = workspace.CurrentCamera
	if not (at and camera) then
		return false
	end
	local pen = at * CFrame.new(Kennel.Pen.Middle)
	return (camera.CFrame.Position - pen.Position).Magnitude < KennelLife.Reach
end

function KennelLife.show(on: boolean)
	wanted = on
	if not folder then
		return
	end
	local parent = if on and near() then workspace else nil
	if folder.Parent ~= parent then
		folder.Parent = parent
	end
	if pen and pen.Parent ~= parent then
		pen.Parent = parent
	end
end

function KennelLife.step(dt: number)
	if not (folder and wanted) then
		return
	end
	clock += dt
	if clock < 1 / 30 then
		return
	end
	clock = 0
	KennelLife.show(wanted)
	if folder.Parent then
		local now = workspace:GetServerTimeNow()
		stock(now)
		KennelLife.pose(now)
		turnDisplay(now)
	end
end

return KennelLife
