--[[
	The Kaiju Daycare's pen, out on the quarry floor by the Shelter's main
	door (Shared.Daycare.Pen; Server.OutpostWorld keeps the ground there
	clear and flat). Built on each player's own screen (Client.OutpostScene
	mounts, shows and steps it, in the quarry's frame).

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
DaycarePen.Reach = 320 -- studs from the pen: past this it's put away

local WOOD = Color3.fromRGB(124, 88, 58)
local WOOD_DARK = Color3.fromRGB(88, 62, 42)
local GRASS = Color3.fromRGB(92, 140, 70)
local SIGN = Color3.fromRGB(40, 34, 28)
local CREAM = Color3.fromRGB(246, 232, 200)
local TRAIN = Color3.fromRGB(120, 230, 140)
local STORE = Color3.fromRGB(120, 190, 255)
local GOLD_TEXT = Color3.fromRGB(250, 208, 110)

type Resident = { Key: string, Model: Model, Root: BasePart, Lift: number, Plate: BillboardGui, Training: boolean, Mood: string?, MoodAt: number? }
-- How the Kennel's moods (Shared.KaijuKennel.Moods) come out here: the ones
-- training livelier (no naps: a roar), the ones stored lazier (a nap).
local TRAINING_MOOD = { Sleep = "Roar", Rest = "Look" }
local STORED_MOOD = { Roar = "Sleep", Look = "Rest" }

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

-- The pen, out on the quarry floor (Shared.Daycare.Pen): a stone border
-- round a lawn, a white rail fence with its gate to the east (Gate), a
-- sand path inside it, flower beds, a shade tree, a water trough and hay;
-- the KAIJU DAYCARE arch over the gate, strung with lights; a red barn
-- behind it (Barn); lamp posts round it; and the keeper's desk in front of
-- the gate (Desk) under a striped awning, the prices on its board and its
-- prompt (opens Client.DaycareUI).
local RED = Color3.fromRGB(168, 58, 48)
local WHITE = Color3.fromRGB(236, 232, 222)
local STONE = Color3.fromRGB(128, 124, 118)
local SAND = Color3.fromRGB(206, 182, 134)
local LEAF = Color3.fromRGB(78, 150, 72)
local BULB = Color3.fromRGB(255, 214, 140)
local LAWN = 0.33 -- the lawn's top over the quarry floor

local function disc(parent: Instance, cframe: CFrame, radius: number, height: number, color: Color3, material: Enum.Material): Part
	local p = piece(parent, cframe * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, radius * 2, radius * 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	p.CastShadow = false
	return p
end

local function lamp(parent: Instance, base: CFrame)
	piece(parent, base * CFrame.new(0, 3, 0), Vector3.new(0.45, 6, 0.45), WOOD_DARK, Enum.Material.Metal)
	local head = piece(parent, base * CFrame.new(0, 6.3, 0), Vector3.new(1.1, 0.9, 1.1), BULB, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = BULB, 18, 0.9
	light.Parent = head
end

local function buildPen(frame: CFrame): Folder
	local made = Instance.new("Folder")
	made.Name = "DaycarePenBuilt"
	local spec = Daycare.Pen
	-- (its middle, turned so +X is toward the gate)
	local middle = frame * CFrame.new(spec.Middle) * CFrame.Angles(0, -spec.Gate, 0)
	local R = spec.Fence
	-- The ground: a stone border, the lawn, the path ring.
	disc(made, middle * CFrame.new(0, 0.1, 0), R + 1.6, 0.2, STONE, Enum.Material.Cobblestone)
	disc(made, middle * CFrame.new(0, 0.22, 0), R + 0.4, 0.2, GRASS, Enum.Material.Grass)
	-- (a sand path ring, the lawn either side of it, and a sand patch
	-- round the training post)
	disc(made, middle * CFrame.new(0, 0.3, 0), spec.Outer + 1.3, 0.06, SAND, Enum.Material.Sand)
	disc(made, middle * CFrame.new(0, 0.33, 0), spec.Outer - 1.1, 0.06, GRASS, Enum.Material.Grass)
	disc(made, middle * CFrame.new(0, 0.36, 0), 2.6, 0.06, SAND, Enum.Material.Sand)
	-- The fence: dark posts, white rails, a gap for the gate at +X.
	local posts = 44
	local gateHalf = math.rad(9)
	for i = 0, posts - 1 do
		local a = i / posts * math.pi * 2
		local b = (i + 1) / posts * math.pi * 2
		local pa = middle * CFrame.new(math.cos(a) * R, 0, math.sin(a) * R)
		local pb = middle * CFrame.new(math.cos(b) * R, 0, math.sin(b) * R)
		local mid = (a + b) / 2
		local d = math.abs(((mid + math.pi) % (math.pi * 2)) - math.pi)
		local inGate = d < gateHalf
		if not (math.abs(((a + math.pi) % (math.pi * 2)) - math.pi) < gateHalf * 0.6) then
			piece(made, pa * CFrame.new(0, 1.6, 0), Vector3.new(0.5, 3.2, 0.5), WOOD_DARK, Enum.Material.Wood, true)
			if i % 2 == 0 then
				-- (a little lantern on every other post: the fence lit at night)
				piece(made, pa * CFrame.new(0, 3.3, 0), Vector3.new(0.7, 0.16, 0.7), WOOD_DARK, Enum.Material.Wood)
				piece(made, pa * CFrame.new(0, 3.62, 0), Vector3.new(0.42, 0.5, 0.42), BULB, Enum.Material.Neon)
			else
				piece(made, pa * CFrame.new(0, 3.28, 0), Vector3.new(0.7, 0.18, 0.7), WHITE, Enum.Material.SmoothPlastic)
			end
			if i % 4 == 1 then
				-- (a bush outside the fence)
				local bush = piece(made, middle * CFrame.new(math.cos(a) * (R + 1.3), 0.9, math.sin(a) * (R + 1.3)), Vector3.new(2.2, 1.9, 2.2), Color3.fromRGB(64, 128, 60), Enum.Material.Grass)
				bush.Shape = Enum.PartType.Ball
			end
		end
		if not inGate then
			local centre = (pa.Position + pb.Position) / 2
			local span = (pb.Position - pa.Position).Magnitude
			for _, h in { 1.1, 2.5 } do
				piece(made, CFrame.lookAt(centre, pb.Position) * CFrame.new(0, h, 0), Vector3.new(0.18, 0.3, span), WHITE, Enum.Material.SmoothPlastic, true)
			end
		end
	end
	-- Inside: a shade tree, flower beds, a trough and hay, by the fence
	-- (past where they walk: Outer).
	local ring = (spec.Outer + R) / 2 + 0.6
	local function at(angle: number): CFrame
		return middle * CFrame.new(math.cos(angle) * ring, 0, math.sin(angle) * ring)
	end
	local tree = at(math.rad(135))
	piece(made, tree * CFrame.new(0, 3, 0), Vector3.new(1.4, 6, 1.4), WOOD_DARK, Enum.Material.Wood)
	for _, blob in { { 0, 7.4, 0, 6 }, { 1.6, 6.6, 1, 4.2 }, { -1.5, 6.8, -0.8, 4.4 } } do
		local leaves = piece(made, tree * CFrame.new(blob[1], blob[2], blob[3]), Vector3.one * blob[4], LEAF, Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end
	-- A second, smaller tree across from the first.
	local tree2 = at(math.rad(55))
	piece(made, tree2 * CFrame.new(0, 2.2, 0), Vector3.new(1, 4.4, 1), WOOD_DARK, Enum.Material.Wood)
	for _, blob in { { 0, 5.4, 0, 4.2 }, { 1, 4.8, 0.6, 3 } } do
		local leaves = piece(made, tree2 * CFrame.new(blob[1], blob[2], blob[3]), Vector3.one * blob[4], Color3.fromRGB(96, 168, 80), Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end
	-- Straw beds by the barn, where the stored ones nap.
	for _, angle in { 168, 182 } do
		local bed = at(math.rad(angle))
		disc(made, bed * CFrame.new(0, 0.42, 0), 1.3, 0.18, Color3.fromRGB(222, 190, 110), Enum.Material.Fabric)
		disc(made, bed * CFrame.new(0, 0.5, 0), 1.0, 0.1, Color3.fromRGB(236, 206, 128), Enum.Material.Fabric)
	end
	for k, angle in { 25, 300, 335 } do
		local bed = at(math.rad(angle))
		disc(made, bed * CFrame.new(0, 0.4, 0), 1.6, 0.25, Color3.fromRGB(96, 64, 42), Enum.Material.Ground)
		for f = 0, 5 do
			local fa = f / 6 * math.pi * 2
			local bloom = piece(made, bed * CFrame.new(math.cos(fa) * 0.9, 0.75, math.sin(fa) * 0.9), Vector3.one * 0.5, ({ Color3.fromRGB(240, 90, 120), Color3.fromRGB(250, 210, 80), Color3.fromRGB(150, 110, 240) })[k], Enum.Material.SmoothPlastic)
			bloom.Shape = Enum.PartType.Ball
		end
	end
	local trough = at(math.rad(255)) * CFrame.Angles(0, math.rad(-255 - 90), 0)
	piece(made, trough * CFrame.new(0, 0.6, 0), Vector3.new(4, 1, 1.4), WOOD_DARK, Enum.Material.Wood)
	piece(made, trough * CFrame.new(0, 1.05, 0), Vector3.new(3.6, 0.06, 1.0), Color3.fromRGB(80, 150, 190), Enum.Material.Glass)
	for _, h in { { 98, 0 }, { 104, 0 }, { 101, 1.2 } } do
		piece(made, at(math.rad(h[1])) * CFrame.new(0, 0.7 + h[2], 0) * CFrame.Angles(0, math.rad(h[1]), 0), Vector3.new(2.4, 1.2, 1.6), Color3.fromRGB(214, 180, 96), Enum.Material.Fabric)
	end
	-- A pond, its stones round it.
	local pond = at(math.rad(195))
	disc(made, pond * CFrame.new(0, 0.36, 0), 2.6, 0.12, STONE, Enum.Material.Slate)
	local water = disc(made, pond * CFrame.new(0, 0.44, 0), 2.1, 0.08, Color3.fromRGB(70, 150, 200), Enum.Material.Glass)
	water.Transparency = 0.15
	for k = 0, 7 do
		local sa = k / 8 * math.pi * 2
		local stone = piece(made, pond * CFrame.new(math.cos(sa) * 2.5, 0.5, math.sin(sa) * 2.5), Vector3.new(0.9, 0.5, 0.7), STONE, Enum.Material.Slate)
		stone.Shape = Enum.PartType.Ball
	end
	-- The training post in the middle: a stump with a straw target, the
	-- ones training circle it.
	piece(made, middle * CFrame.new(0, 1.2, 0), Vector3.new(1.3, 2.4, 1.3), WOOD_DARK, Enum.Material.Wood, true)
	for k, size in { 2.2, 1.5, 0.8 } do
		-- (standing up on the stump, facing the gate: the disc turned back on its side)
		disc(made, middle * CFrame.new(0.66 + k * 0.04, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), size / 2, 0.08, if k % 2 == 1 then Color3.fromRGB(214, 180, 96) else RED, Enum.Material.Fabric)
	end
	-- Stepping stones from the gate out to the desk.
	for k = 0, 4 do
		local stone = disc(made, middle * CFrame.new(R + 1.2 + k * 1.5, 0.15, (k % 2) * 0.6 - 0.3), 0.85, 0.12, STONE, Enum.Material.Slate)
		stone.Name = "Step"
	end
	-- The arch over the gate, strung with lights.
	local gate = middle * CFrame.new(R, 0, 0)
	local out = CFrame.lookAt(gate.Position, gate.Position + (gate.Position - middle.Position) * Vector3.new(1, 0, 1))
	for _, side in { -3.6, 3.6 } do
		piece(made, out * CFrame.new(side, 3.6, 0), Vector3.new(0.9, 7.2, 0.9), WOOD_DARK, Enum.Material.Wood, true)
		piece(made, out * CFrame.new(side, 7.4, 0), Vector3.new(1.2, 0.4, 1.2), WHITE, Enum.Material.SmoothPlastic)
	end
	local sign = piece(made, out * CFrame.new(0, 7.9, 0), Vector3.new(10, 2, 0.45), SIGN, Enum.Material.Wood)
	sign.Name = "DaycareSign"
	words(sign, "KAIJU DAYCARE", CREAM, Enum.Font.GothamBlack, 64)
	piece(made, out * CFrame.new(0, 9.05, 0), Vector3.new(10.6, 0.3, 0.7), RED, Enum.Material.SmoothPlastic)
	for k = -4, 4 do
		piece(made, out * CFrame.new(k * 1.15, 6.75, -0.3), Vector3.one * 0.32, BULB, Enum.Material.Neon)
	end
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = BULB, 18, 0.8
	glow.Parent = sign
	-- The barn behind the pen (Barn), its doors to the pen.
	local barnAt = frame * CFrame.new(spec.Barn)
	local barn = CFrame.lookAt(barnAt.Position, (frame * CFrame.new(spec.Middle)).Position * Vector3.new(1, 0, 1) + Vector3.new(0, barnAt.Position.Y, 0))
	piece(made, barn * CFrame.new(0, 3.5, 0), Vector3.new(11, 7, 8), RED, Enum.Material.WoodPlanks, true)
	for _, side in { -1, 1 } do
		piece(made, barn * CFrame.new(side * 2.9, 9.1, 0) * CFrame.Angles(0, 0, math.rad(side * -38)), Vector3.new(7.4, 0.5, 8.8), Color3.fromRGB(60, 46, 40), Enum.Material.Slate, true)
	end
	piece(made, barn * CFrame.new(0, 7.6, 0), Vector3.new(10.4, 1.4, 7.6), RED, Enum.Material.WoodPlanks)
	piece(made, barn * CFrame.new(0, 2.6, -4.05), Vector3.new(4.4, 5.2, 0.2), Color3.fromRGB(40, 30, 26), Enum.Material.Wood)
	for _, side in { -1, 1 } do
		piece(made, barn * CFrame.new(side * 1.1, 2.6, -4.18) * CFrame.Angles(0, 0, math.rad(side * 50)), Vector3.new(0.25, 6.4, 0.1), WHITE, Enum.Material.SmoothPlastic)
	end
	piece(made, barn * CFrame.new(0, 6.2, -4.05), Vector3.new(1.6, 1.6, 0.2), WHITE, Enum.Material.SmoothPlastic)
	-- Lamp posts round it.
	for _, angle in { 45, 135, 225, 315 } do
		local a = math.rad(angle)
		lamp(made, middle * CFrame.new(math.cos(a) * (R + 3), 0, math.sin(a) * (R + 3)))
	end
	-- The keeper's desk in front of the gate, under a striped awning, its
	-- board of prices to the side.
	local deskAt = frame * CFrame.new(spec.Desk)
	local desk = CFrame.lookAt(deskAt.Position, deskAt.Position + (deskAt.Position - gate.Position) * Vector3.new(1, 0, 1))
	piece(made, desk * CFrame.new(0, 0.8, 0), Vector3.new(6, 1.6, 1.8), WOOD, Enum.Material.Wood, true)
	piece(made, desk * CFrame.new(0, 1.66, 0), Vector3.new(6.4, 0.14, 2.1), WOOD_DARK, Enum.Material.Wood)
	-- (the awning over the counter, on two posts behind it, sloping down
	-- to the front, a scalloped red trim along its edge)
	for _, side in { -3.1, 3.1 } do
		piece(made, desk * CFrame.new(side, 2.7, 1.1), Vector3.new(0.35, 5.4, 0.35), WOOD_DARK, Enum.Material.Wood)
	end
	for k = 0, 5 do
		piece(made, desk * CFrame.new(-2.75 + k * 1.1, 5.2, -0.2) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(1.1, 0.12, 3.2), if k % 2 == 0 then RED else WHITE, Enum.Material.Fabric)
	end
	piece(made, desk * CFrame.new(0, 4.62, -1.8), Vector3.new(6.6, 0.4, 0.1), RED, Enum.Material.Fabric)
	local board = piece(made, desk * CFrame.new(5.2, 2.2, 0.4) * CFrame.Angles(0, math.rad(-20), 0), Vector3.new(3.4, 3, 0.2), SIGN, Enum.Material.Wood, true)
	board.Name = "DaycareBoard"
	words(board, string.format("STORE\n%d coins / h\n\nTRAIN\nfrom %d coins / h", Daycare.Store.PerHour, Daycare.trainRate(1)), CREAM, Enum.Font.GothamBold, 26)
	local anchor = piece(made, desk * CFrame.new(0, 2.4, 0), Vector3.new(1, 1, 1), SIGN, Enum.Material.SmoothPlastic)
	anchor.Transparency, anchor.Name = 1, "DaycarePrompt"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Kaiju Daycare"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
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
	gui.Size = UDim2.fromOffset(150, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Adornee = root
	local training = entry:GetAttribute("Mode") == "Train"
	local element = GemConfig.ElementColors[entry:GetAttribute("Element")] or CREAM
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	back.BackgroundTransparency = 0.2
	back.Size = UDim2.new(1, 0, 0, 34)
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = back
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness, edge.Transparency = element, 1.5, 0.3
	edge.Parent = back
	local function text(parent: Instance, value: string, x: number, y: number, w: number, h: number, size: number, color: Color3, font: Enum.Font, align: Enum.TextXAlignment?)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromOffset(x, y), UDim2.new(0, w, 0, h)
		l.Font, l.Text, l.TextSize, l.TextColor3 = font, value, size, color
		l.TextXAlignment = align or Enum.TextXAlignment.Center
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l:SetAttribute("NoTranslate", true)
		l.Parent = parent
		return l
	end
	text(back, tostring(entry:GetAttribute("Name") or "Kaiju"), 8, 3, 104, 16, 14, element:Lerp(CREAM, 0.25), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	text(back, "Lv " .. tostring(entry:GetAttribute("Level") or 1), 108, 3, 36, 16, 12, GOLD_TEXT, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
	text(back, tostring(entry:GetAttribute("Owner") or ""), 8, 18, 134, 13, 11, Color3.fromRGB(200, 196, 186), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	-- TRAINING or STORED, a chip under it.
	local chip = Instance.new("Frame")
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position, chip.Size = UDim2.new(0.5, 0, 0, 36), UDim2.fromOffset(78, 14)
	chip.BackgroundColor3 = if training then TRAIN else STORE
	chip.Parent = gui
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(1, 0)
	chipCorner.Parent = chip
	local tag = text(chip, if training then "TRAINING" else "STORED", 0, 0, 78, 14, 10, Color3.fromRGB(14, 16, 22), Enum.Font.GothamBlack)
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
			KaijuModels.scale(model, Daycare.Scale)
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
				Training = c:GetAttribute("Mode") == "Train",
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
		-- (on the lawn: LAWN over the quarry floor)
		table.insert(cframes, at * CFrame.new(s.Position + Vector3.new(0, r.Lift + LAWN, 0)) * CFrame.Angles(0, s.Yaw, 0))
		if r.Model:GetAttribute("PacedSpeed") ~= s.Speed then
			r.Model:SetAttribute("PacedSpeed", s.Speed)
		end
		local mood = s.Mood and ((if r.Training then TRAINING_MOOD else STORED_MOOD)[s.Mood] or s.Mood)
		if mood ~= r.Mood or s.MoodAt ~= r.MoodAt then
			r.Mood, r.MoodAt = mood, s.MoodAt
			r.Model:SetAttribute("KaijuMood", mood)
			r.Model:SetAttribute("KaijuMoodAt", s.MoodAt)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- The ground under the pen: the quarry floor there is terrain, a little
-- over the quarry's frame (and only there once it's streamed in). The
-- middle of what's under its middle, its fence and its desk, as a lift over
-- `base` (nil till there's ground under it).
local function groundLift(base: CFrame): number?
	local spec = Daycare.Pen
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { folder :: Instance }
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for _, name in { "Kaiju", "Enemies", "MeteorGolems", "KaijuKennel" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	if workspace.CurrentCamera then
		table.insert(skip, workspace.CurrentCamera)
	end
	params.FilterDescendantsInstances = skip
	local points = { spec.Middle, spec.Desk }
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		table.insert(points, spec.Middle + Vector3.new(math.cos(a), 0, math.sin(a)) * (spec.Fence - 1))
	end
	local heights = {}
	for _, p in points do
		local top = (base * CFrame.new(p + Vector3.new(0, 60, 0))).Position
		local hit = workspace:Raycast(top, Vector3.new(0, -140, 0), params)
		if hit then
			table.insert(heights, hit.Position.Y - (base * CFrame.new(p)).Position.Y)
		end
	end
	if #heights < 4 then
		return nil
	end
	table.sort(heights)
	return heights[(#heights + 1) // 2]
end

local base: CFrame? = nil
local groundTry = 0
function DaycarePen.mount(frame: CFrame)
	if base then
		return
	end
	base = frame
	local made = Instance.new("Folder")
	made.Name = "KaijuDaycare" -- (CreatureAnimation looks in here)
	folder = made
end

-- Built once there's ground under it to stand on (tried once a second).
local function build(): boolean
	if pen then
		return true
	end
	if not base or os.clock() < groundTry then
		return false
	end
	groundTry = os.clock() + 1
	local lift = groundLift(base)
	if not lift then
		return false
	end
	at = base + Vector3.new(0, lift, 0)
	pen = buildPen(at :: CFrame)
	return true
end

local function near(): boolean
	local camera = workspace.CurrentCamera
	if not (base and camera) then
		return false
	end
	local middle = base * CFrame.new(Daycare.Pen.Middle)
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

local clock = 0
function DaycarePen.step(dt: number)
	if not (folder and wanted) then
		return
	end
	clock += dt
	if clock < 1 / 30 then
		return
	end
	clock = 0
	if not build() then
		return
	end
	DaycarePen.show(wanted)
	if folder.Parent then
		stock()
		pose(workspace:GetServerTimeNow())
	end
end

DaycarePen._buildPen = buildPen -- (tests and previews: the pen at a frame)
return DaycarePen
