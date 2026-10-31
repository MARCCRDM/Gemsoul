--[[
	The Kaiju Daycare's pen, on the hall floor east of the Kennel's stage
	(Shared.Daycare.Pen): a low fence round a bed of grass, a DAYCARE arch
	over its gate, and the keeper's desk in front with its prompt (opens
	Client.DaycareUI). Built on each player's own screen, like the Kennel's
	pen (Client.KennelLife mounts, shows and steps it with its own).

	In it, every kaiju boarded by a player in this server
	(ReplicatedStorage.DaycarePen, kept by Server.DaycareServer), wandering
	like the Kennel's (Shared.KaijuKennel.state, in this pen), each with a
	plate over it: its name, level and owner, and TRAINING or STORED.

	  DaycarePen.mount(frame)   the Shelter's frame (once)
	  DaycarePen.show(on)
	  DaycarePen.step(now)      who's in it, and where (KennelLife's 30 a second)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daycare = require(Shared:WaitForChild("Daycare"))
local Kennel = require(Shared:WaitForChild("KaijuKennel"))
local KaijuModels = require(Shared:WaitForChild("KaijuModels"))
local GemConfig = require(Shared:WaitForChild("GemConfig"))

local DaycarePen = {}
DaycarePen.Reach = 220 -- studs from the pen: past this it's put away

local WOOD = Color3.fromRGB(124, 88, 58)
local WOOD_DARK = Color3.fromRGB(88, 62, 42)
local GRASS = Color3.fromRGB(92, 140, 70)
local SIGN = Color3.fromRGB(40, 34, 28)
local CREAM = Color3.fromRGB(246, 232, 200)
local TRAIN = Color3.fromRGB(120, 230, 140)
local STORE = Color3.fromRGB(120, 190, 255)

type Resident = { Key: string, Model: Model, Root: BasePart, Lift: number, Plate: BillboardGui, Mood: string?, MoodAt: number? }

local at: CFrame? = nil
local folder: Folder? = nil -- the residents (CreatureAnimation looks in "KaijuDaycare")
local pen: Folder? = nil
local residents: { Resident } = {}
local shownKey = ""
local wanted = false

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

local function words(carrier: BasePart, text: string, color: Color3, font: Enum.Font, max: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = carrier
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = max
	cap.Parent = l
	l.Parent = gui
	return l
end

-- The pen: a bed of grass, a ring of fence posts with two rails, a water
-- trough, the DAYCARE arch over the gate (facing -Z, the way into the hall)
-- and the keeper's desk in front of it with a board of the prices.
local function buildPen(frame: CFrame): Folder
	local made = Instance.new("Folder")
	made.Name = "DaycarePenBuilt"
	local spec = Daycare.Pen
	local middle = frame * CFrame.new(spec.Middle)
	local bed = piece(made, middle * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.1, spec.Fence * 2, spec.Fence * 2), GRASS, Enum.Material.Grass)
	bed.Shape = Enum.PartType.Cylinder
	bed.CastShadow = false
	local posts = 24
	local gate = math.rad(270) -- (the gap in the fence, at -Z)
	for i = 0, posts - 1 do
		local a = math.rad(i * 360 / posts)
		local b = math.rad((i + 1) * 360 / posts)
		local pa = middle * CFrame.new(math.cos(a) * spec.Fence, 0, math.sin(a) * spec.Fence)
		local pb = middle * CFrame.new(math.cos(b) * spec.Fence, 0, math.sin(b) * spec.Fence)
		piece(made, pa * CFrame.new(0, 1.2, 0), Vector3.new(0.4, 2.4, 0.4), WOOD_DARK, Enum.Material.Wood, true)
		local mid = (a + b) / 2
		local inGate = math.abs(((mid - gate + math.pi) % (math.pi * 2)) - math.pi) < math.rad(14)
		if not inGate then
			local centre = (pa.Position + pb.Position) / 2
			local span = (pb.Position - pa.Position).Magnitude
			for _, h in { 0.8, 1.9 } do
				piece(made, CFrame.lookAt(centre, pb.Position) * CFrame.new(0, h, 0), Vector3.new(0.16, 0.24, span), WOOD, Enum.Material.Wood, true)
			end
		end
	end
	-- A trough and a little hay at the back.
	local back = middle * CFrame.new(0, 0, spec.Fence - 2.2)
	piece(made, back * CFrame.new(0, 0.35, 0), Vector3.new(3.2, 0.7, 1), WOOD_DARK, Enum.Material.Wood)
	piece(made, back * CFrame.new(0, 0.66, 0), Vector3.new(2.8, 0.05, 0.7), Color3.fromRGB(80, 140, 170), Enum.Material.Glass)
	piece(made, middle * CFrame.new(-6, 0.5, 4) * CFrame.Angles(0, 0.4, 0), Vector3.new(2, 1, 1.4), Color3.fromRGB(214, 180, 96), Enum.Material.Fabric)
	-- The arch over the gate.
	local front = middle * CFrame.new(0, 0, -spec.Fence)
	local out = CFrame.lookAt(front.Position, front.Position + (front.Position - middle.Position) * Vector3.new(1, 0, 1))
	for _, side in { -2.6, 2.6 } do
		piece(made, out * CFrame.new(side, 2.4, 0), Vector3.new(0.6, 4.8, 0.6), WOOD_DARK, Enum.Material.Wood, true)
	end
	local sign = piece(made, out * CFrame.new(0, 5, 0), Vector3.new(7, 1.4, 0.35), SIGN, Enum.Material.Wood)
	sign.Name = "DaycareSign"
	words(sign, "KAIJU DAYCARE", CREAM, Enum.Font.GothamBlack, 46)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 220, 160), 12, 0.6
	glow.Parent = sign
	-- The desk, in front of the gate, and its board of prices.
	local deskAt = frame * CFrame.new(Daycare.Pen.Desk)
	local desk = CFrame.lookAt(deskAt.Position, deskAt.Position - (middle.Position - deskAt.Position) * Vector3.new(1, 0, 1))
	piece(made, desk * CFrame.new(0, 0.6, 0), Vector3.new(4.4, 1.2, 1.4), WOOD, Enum.Material.Wood, true)
	piece(made, desk * CFrame.new(0, 1.24, 0), Vector3.new(4.6, 0.1, 1.6), WOOD_DARK, Enum.Material.Wood)
	local board = piece(made, desk * CFrame.new(0, 2.7, 0.55) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(4.2, 2.2, 0.15), SIGN, Enum.Material.Wood)
	board.Name = "DaycareBoard"
	words(
		board,
		string.format("STORE  %d/h\nTRAIN  from %d/h", Daycare.Store.PerHour, Daycare.trainRate(1)),
		CREAM,
		Enum.Font.GothamBold,
		34
	)
	local anchor = piece(made, desk * CFrame.new(0, 1.8, 0), Vector3.new(1, 1, 1), SIGN, Enum.Material.SmoothPlastic)
	anchor.Transparency, anchor.Name = 1, "DaycarePrompt"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Kaiju Daycare"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		require(script.Parent.DaycareUI).open()
	end)
	prompt.Parent = anchor
	return made
end

-- A resident's plate: its name and level, its owner, TRAINING or STORED.
local function plate(entry: Configuration, root: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "DaycarePlate"
	gui.Size = UDim2.fromOffset(140, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	gui.Adornee = root
	local training = entry:GetAttribute("Mode") == "Train"
	local function text(value: string, y: number, h: number, size: number, color: Color3, font: Enum.Font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, h)
		l.Font, l.Text, l.TextSize, l.TextColor3 = font, value, size, color
		l.TextStrokeTransparency, l.TextStrokeColor3 = 0.3, Color3.new(0, 0, 0)
		l:SetAttribute("NoTranslate", true)
		l.Parent = gui
		return l
	end
	local element = GemConfig.ElementColors[entry:GetAttribute("Element")] or CREAM
	text(string.format("%s  ·  Lv %d", tostring(entry:GetAttribute("Name") or "Kaiju"), entry:GetAttribute("Level") or 1), 0, 16, 14, element:Lerp(CREAM, 0.35), Enum.Font.GothamBold)
	text(tostring(entry:GetAttribute("Owner") or ""), 16, 13, 11, CREAM, Enum.Font.Gotham)
	local tag = text(if training then "TRAINING" else "STORED", 30, 14, 11, if training then TRAIN else STORE, Enum.Font.GothamBlack)
	tag:SetAttribute("NoTranslate", nil)
	return gui
end

local function clear()
	for _, r in residents do
		r.Model:Destroy()
		r.Plate:Destroy()
	end
	table.clear(residents)
end

-- Who's in it now (the server's list), drawn again when it changes.
local function stock()
	local list = ReplicatedStorage:FindFirstChild("DaycarePen")
	local entries = {}
	for _, c in if list then list:GetChildren() else {} do
		if c:IsA("Configuration") and c:GetAttribute("Species") then
			table.insert(entries, c)
		end
	end
	table.sort(entries, function(a, b)
		return a.Name < b.Name
	end)
	local key = {}
	for i = 1, math.min(#entries, Daycare.Shown) do
		local c = entries[i]
		table.insert(key, string.format("%s/%s/%s/%s", c.Name, tostring(c:GetAttribute("Level")), tostring(c:GetAttribute("Mode")), tostring(c:GetAttribute("Name"))))
	end
	local joined = table.concat(key, "|")
	if joined == shownKey then
		return
	end
	shownKey = joined
	clear()
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	for i = 1, math.min(#entries, Daycare.Shown) do
		local c = entries[i]
		local ok, model = pcall(KaijuModels.build, c:GetAttribute("Species"), c:GetAttribute("Element"))
		if ok and model then
			KaijuModels.scale(model, Kennel.Scale)
			model.Name = "Daycare" .. tostring(c:GetAttribute("Species"))
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
			model.Parent = folder
			local tag = plate(c, root)
			tag.Parent = playerGui
			table.insert(residents, {
				Key = c.Name,
				Model = model,
				Root = root,
				Lift = (model:GetAttribute("KaijuHipHeight") or 1) + root.Size.Y / 2,
				Plate = tag,
			})
		end
	end
end

local function pose(now: number)
	if not at then
		return
	end
	local parts, cframes = {}, {}
	for i, r in residents do
		-- (its own spells, apart from the Kennel's: index from 101)
		local s = Kennel.state(100 + i, #residents, now, Daycare.Pen)
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
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function DaycarePen.mount(frame: CFrame)
	if at then
		return
	end
	at = frame
	local made = Instance.new("Folder")
	made.Name = "KaijuDaycare" -- (CreatureAnimation looks in here)
	folder = made
	pen = buildPen(frame)
end

local function near(): boolean
	local camera = workspace.CurrentCamera
	if not (at and camera) then
		return false
	end
	local middle = at * CFrame.new(Daycare.Pen.Middle)
	return (camera.CFrame.Position - middle.Position).Magnitude < DaycarePen.Reach
end

function DaycarePen.show(on: boolean)
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
	for _, r in residents do
		r.Plate.Enabled = parent ~= nil
	end
end

function DaycarePen.step(now: number)
	if not (folder and wanted) then
		return
	end
	DaycarePen.show(wanted)
	if folder.Parent then
		stock()
		pose(now)
	end
end

return DaycarePen
