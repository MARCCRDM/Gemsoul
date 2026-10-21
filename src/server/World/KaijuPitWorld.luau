--[[
	The Kaiju Arena's hall, downstairs under the Shelter (Shared.KaijuPit has
	its measures; Server.KaijuPitServer runs it). You come down the Shelter's
	stairs onto a balcony along its north wall, and the courts lie below you
	in two rows of four, like ping-pong tables: each a low-railed mat, its
	halves tinted blue and red, a pad at either end (the BLUE and RED
	corners), its six places a side painted on, a board hung over its
	middle (each client draws who's on it: Client.KaijuPitClient) and a
	pedestal by its side where the stake is shown. Bleachers along every
	court's sides, wide aisles between them. Floodlights over each court, a
	steel roof, armour-plate walls with the Shelter's rust band.

	Invisible walls stand over each court's rails, so a kaiju can't hop out
	(and nobody hops in); they don't stop the camera.

	  KaijuPitWorld.build(origin, parent) -> {
	      Folder, Origin (the hall's frame: Shared.KaijuPit.origin),
	      Arrive (CFrame: on the balcony, facing the courts),
	      Courts ({ Shared.KaijuPit court, with Model: its model, holding
	          PadA, PadB, Board and Pedestal }),
	  }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KaijuPit = require(ReplicatedStorage.Shared.KaijuPit)

local KaijuPitWorld = {}

local CONCRETE = Color3.fromRGB(62, 64, 70)
local MAT = Color3.fromRGB(46, 52, 60)
local ARMOR = Color3.fromRGB(96, 100, 110)
local RUST = Color3.fromRGB(128, 76, 50)
local HULL_DARK = Color3.fromRGB(58, 62, 72)
local STEEL = Color3.fromRGB(150, 158, 170)
local HAZARD = Color3.fromRGB(240, 178, 48)
local LAMP = Color3.fromRGB(255, 236, 200)
KaijuPitWorld.Blue = Color3.fromRGB(70, 160, 255)
KaijuPitWorld.Red = Color3.fromRGB(255, 84, 72)
local BLUE, RED = KaijuPitWorld.Blue, KaijuPitWorld.Red

local function part(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: string?
)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	if shape == "Cylinder" then
		(p :: Part).Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 3
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function solid(p: BasePart): BasePart
	p.CanCollide = true
	p.CanQuery = true
	return p
end
-- A flat disc lying on the floor (a cylinder on its side).
local function disc(
	parent: Instance,
	at: CFrame,
	radius: number,
	height: number,
	color: Color3,
	material: Enum.Material?
)
	return part(
		parent,
		at * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(height, radius * 2, radius * 2),
		color,
		material,
		"Cylinder"
	)
end
local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
-- A sign: a dark board with big words on its face (and its back, if `both`).
local function sign(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	title: string,
	sub: string?,
	color: Color3,
	both: boolean?
)
	local board = part(parent, cframe, size, HULL_DARK, Enum.Material.Metal)
	board.Name = "Sign"
	for _, face in if both then { Enum.NormalId.Front, Enum.NormalId.Back } else { Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(size.X * 40, size.Y * 40)
		gui.LightInfluence = 0
		gui.Parent = board
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BorderSizePixel = 0
		back.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
		back.Parent = gui
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0.08, 0)
		bar.Position = UDim2.fromScale(0, 0.92)
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = color
		bar.Parent = back
		local head = Instance.new("TextLabel")
		head.Name = "Title"
		head.BackgroundTransparency = 1
		head.Position = UDim2.fromScale(0.04, if sub then 0.06 else 0.12)
		head.Size = UDim2.fromScale(0.92, if sub then 0.52 else 0.72)
		head.Text = title
		head.TextScaled = true
		head.Font = Enum.Font.Oswald
		head.TextColor3 = Color3.fromRGB(238, 234, 224)
		head.Parent = back
		if sub then
			local line = Instance.new("TextLabel")
			line.Name = "Line"
			line.BackgroundTransparency = 1
			line.Position = UDim2.fromScale(0.04, 0.6)
			line.Size = UDim2.fromScale(0.92, 0.26)
			line.Text = sub
			line.TextScaled = true
			line.Font = Enum.Font.GothamMedium
			line.TextColor3 = Color3.fromRGB(170, 176, 186)
			line.Parent = back
		end
	end
	return board
end
local function spot(parent: BasePart, color: Color3, range: number, brightness: number, angle: number)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Color, light.Range, light.Brightness, light.Angle = color, range, brightness, angle
	light.Shadows = false
	light.Parent = parent
	return light
end

-- One court, in `hall` (the hall's frame) at its middle (x, z).
local function court(parent: Instance, hall: CFrame, info, number: number)
	local spec = KaijuPit.Court
	local hl, hw = spec.HalfLength, spec.HalfWidth
	local m = model(parent, "Court" .. number)
	m:SetAttribute("Court", number)
	local mid = CFrame.new(info.Center) * (hall - hall.Position)
	local function at(x, y, z)
		return mid * CFrame.new(x, y, z)
	end
	-- The mat: its halves tinted blue (A, north) and red (B, south), the
	-- middle line and circle, a frame of hazard paint.
	solid(part(m, at(0, 0.06, 0), Vector3.new(hw * 2, 0.12, hl * 2), MAT, Enum.Material.SmoothPlastic))
	for _, s in { -1, 1 } do
		local tint = (if s < 0 then BLUE else RED):Lerp(MAT, 0.82)
		part(m, at(0, 0.125, s * hl / 2), Vector3.new(hw * 2 - 1, 0.02, hl - 0.6), tint)
		-- (the side's six places, painted: Shared.KaijuBattle.cellSpot's)
		for _, row in { 4.5, 9.5 } do
			for _, col in { -5.5, 0, 5.5 } do
				disc(m, at(col, 0.14, s * row), 1.25, 0.02, tint:Lerp(Color3.new(1, 1, 1), 0.12))
			end
		end
		-- (its court number at each end, big on the mat)
		-- (lying face up, its top away from that end's pad: read from the pad)
		local plate = part(
			m,
			at(0, 0.15, s * (hl - 2.2))
				* CFrame.Angles(0, if s < 0 then 0 else math.pi, 0)
				* CFrame.Angles(math.rad(90), 0, 0),
			Vector3.new(4, 2.4, 0.02),
			MAT
		)
		plate.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(160, 96)
		gui.Parent = plate
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = tostring(number)
		text.TextScaled = true
		text.Font = Enum.Font.Oswald
		text.TextColor3 = Color3.fromRGB(200, 204, 212)
		text.TextTransparency = 0.45
		text.Parent = gui
	end
	part(m, at(0, 0.14, 0), Vector3.new(hw * 2 - 1, 0.03, 0.4), HAZARD)
	disc(m, at(0, 0.14, 0), 2.6, 0.03, HAZARD)
	disc(m, at(0, 0.15, 0), 2.2, 0.03, MAT)
	-- The rails: low steel walls round it, a hazard strip on top, and
	-- invisible walls over them so a kaiju can't hop out.
	for _, edge in
		{
			{ 0, hl + 0.3, hw * 2 + 1.2, 0.6 },
			{ 0, -hl - 0.3, hw * 2 + 1.2, 0.6 },
			{ hw + 0.3, 0, 0.6, hl * 2 },
			{ -hw - 0.3, 0, 0.6, hl * 2 },
		}
	do
		solid(part(m, at(edge[1], 0.8, edge[2]), Vector3.new(edge[3], 1.6, edge[4]), STEEL, Enum.Material.Metal))
		part(m, at(edge[1], 1.65, edge[2]), Vector3.new(edge[3] + 0.04, 0.1, edge[4] + 0.04), HAZARD)
		local wall = solid(part(m, at(edge[1], 6, edge[2]), Vector3.new(edge[3], 9, edge[4]), STEEL))
		wall.Name = "Keep"
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false
	end
	-- The pads, a little out from each end: BLUE corner (A), RED corner (B).
	for _, side in { "A", "B" } do
		local s = if side == "A" then -1 else 1
		local color = if side == "A" then BLUE else RED
		local base = at(0, 0, s * spec.Pad)
		solid(disc(m, base * CFrame.new(0, 0.15, 0), spec.PadRadius + 0.5, 0.3, HULL_DARK, Enum.Material.DiamondPlate))
		local ring = disc(m, base * CFrame.new(0, 0.31, 0), spec.PadRadius, 0.04, color, Enum.Material.Neon)
		ring.Name = "Pad" .. side
		ring:SetAttribute("Side", side)
		disc(m, base * CFrame.new(0, 0.33, 0), spec.PadRadius - 0.45, 0.04, HULL_DARK, Enum.Material.DiamondPlate)
		-- (a post with its corner's colour and the court's number, behind the pad)
		local post = at(0, 0, s * (spec.Pad + spec.PadRadius + 1.4))
		part(m, post * CFrame.new(0, 2, 0), Vector3.new(0.5, 4, 0.5), HULL_DARK, Enum.Material.Metal)
		local face = sign(
			m,
			post * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, if s < 0 then math.pi else 0, 0),
			Vector3.new(4.6, 1.6, 0.25),
			if side == "A" then "BLUE CORNER" else "RED CORNER",
			"COURT " .. number,
			color,
			true
		)
		face.Name = "Corner" .. side
	end
	-- The board over its middle, facing both aisles (Client.KaijuPitClient
	-- draws on it), hung from the roof.
	local board = part(
		m,
		at(0, 21, 0) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(15, 6, 0.6),
		HULL_DARK,
		Enum.Material.Metal
	)
	board.Name = "Board"
	for _, s in { -1, 1 } do
		part(m, at(0, 29, s * 5.5), Vector3.new(0.2, 10, 0.2), STEEL, Enum.Material.Metal)
	end
	-- The pedestal by its east rail, where the stake is shown.
	local pedestal = at(hw + 3, 0, 0)
	solid(part(m, pedestal * CFrame.new(0, 1.5, 0), Vector3.new(2.4, 3, 2.4), HULL_DARK, Enum.Material.Metal)).Name =
		"Pedestal"
	disc(m, pedestal * CFrame.new(0, 3.05, 0), 1.0, 0.1, HAZARD, Enum.Material.Neon).Name = "PedestalGlow"
	-- Bleachers along both sides: two steps, a walkway between courts.
	for _, s in { -1, 1 } do
		for tier, spec2 in { { 6.8, 1.2 }, { 9.3, 2.4 } } do
			solid(
				part(
					m,
					at(s * (hw + spec2[1]), spec2[2] / 2, 0),
					Vector3.new(2.5, spec2[2], hl * 2 - 6),
					if tier == 1 then Color3.fromRGB(110, 114, 124) else Color3.fromRGB(86, 90, 100),
					Enum.Material.Metal
				)
			)
		end
	end
	-- Floodlights: a frame over the court, four lamps tipped down.
	local rig = at(0, 26, 0)
	part(m, rig, Vector3.new(hw * 2 - 4, 0.6, 0.6), HULL_DARK, Enum.Material.Metal)
	part(m, rig, Vector3.new(0.6, 0.6, hl * 2 - 6), HULL_DARK, Enum.Material.Metal)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local lamp = part(
			m,
			rig * CFrame.new(c[1] * (hw - 3), -0.6, c[2] * (hl - 4)),
			Vector3.new(2, 0.8, 1.4),
			HULL_DARK,
			Enum.Material.Metal
		)
		local face =
			part(m, lamp.CFrame * CFrame.new(0, -0.42, 0), Vector3.new(1.6, 0.06, 1.1), LAMP, Enum.Material.Neon)
		spot(face, LAMP, 34, 1.4, 75)
	end
	return m
end

function KaijuPitWorld.build(origin: CFrame, parent: Instance)
	local folder = Instance.new("Model")
	folder.Name = "KaijuPit"
	local hall = KaijuPit.Hall
	local X, Z, H = hall.HalfX, hall.HalfZ, hall.Height
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	local shell = model(folder, "Hall")
	-- Floor, roof, walls (armour plate, a rust band low down, hazard paint
	-- at the foot).
	solid(part(shell, at(0, -1, 0), Vector3.new(X * 2 + 4, 2, Z * 2 + 4), CONCRETE, Enum.Material.Concrete))
	solid(part(shell, at(0, H + 1, 0), Vector3.new(X * 2 + 4, 2, Z * 2 + 4), HULL_DARK, Enum.Material.Metal))
	for _, w in
		{
			{ 0, -Z - 1, X * 2 + 4, 2 },
			{ 0, Z + 1, X * 2 + 4, 2 },
			{ -X - 1, 0, 2, Z * 2 },
			{ X + 1, 0, 2, Z * 2 },
		}
	do
		solid(part(shell, at(w[1], H / 2, w[2]), Vector3.new(w[3], H, w[4]), ARMOR, Enum.Material.Metal))
		local inward = Vector3.new(-math.sign(w[1]), 0, -math.sign(w[2]))
		local skin = Vector3.new(w[1], 0, w[2]) + inward * 1.05
		part(
			shell,
			at(skin.X, 3.2, skin.Z),
			Vector3.new(math.max(w[3] - 4, 0.1), 2.4, math.max(w[4] - 4, 0.1)),
			RUST,
			Enum.Material.Metal
		)
		part(shell, at(skin.X, 0.4, skin.Z), Vector3.new(math.max(w[3] - 4, 0.1), 0.8, math.max(w[4] - 4, 0.1)), HAZARD)
	end
	-- Trusses under the roof.
	for x = -X + 12, X - 12, 24 do
		part(shell, at(x, H - 1.2, 0), Vector3.new(1, 2, Z * 2), HULL_DARK, Enum.Material.Metal)
	end
	-- The balcony you arrive on: a deck along the north wall, its face
	-- lit, a glass rail with a gap for the stairs down.
	local deep = hall.BalconyDepth
	local deckZ = -Z + deep / 2
	solid(
		part(shell, at(0, hall.Balcony / 2, deckZ), Vector3.new(X * 2, hall.Balcony, deep), ARMOR, Enum.Material.Metal)
	)
	part(shell, at(0, hall.Balcony + 0.05, deckZ), Vector3.new(X * 2, 0.1, deep), CONCRETE, Enum.Material.Concrete)
	part(shell, at(0, hall.Balcony - 0.6, -Z + deep + 0.06), Vector3.new(X * 2, 0.3, 0.1), HAZARD, Enum.Material.Neon)
	local stairs = hall.StairsHalf
	for _, s in { -1, 1 } do
		local from, to = s * (stairs + 0.5), s * X
		local mid, len = (from + to) / 2, math.abs(to - from)
		solid(
			part(
				shell,
				at(mid, hall.Balcony + 1.8, -Z + deep - 0.2),
				Vector3.new(len, 3.6, 0.3),
				STEEL,
				Enum.Material.Glass
			)
		).Transparency =
			0.55
		part(
			shell,
			at(mid, hall.Balcony + 3.65, -Z + deep - 0.2),
			Vector3.new(len, 0.2, 0.5),
			STEEL,
			Enum.Material.Metal
		)
	end
	-- The stairs down off the balcony to the courts.
	local run = hall.StairsRun
	local steps = 20
	for i = 1, steps do
		local top = hall.Balcony * (1 - i / steps)
		if top > 0.01 then
			local z = -Z + deep + (i - 0.5) * run / steps
			solid(
				part(
					shell,
					at(0, top / 2, z),
					Vector3.new(stairs * 2, top, run / steps),
					CONCRETE,
					Enum.Material.Concrete
				)
			)
			part(shell, at(0, top + 0.02, z - run / steps / 2 + 0.1), Vector3.new(stairs * 2, 0.04, 0.2), HAZARD)
		end
	end
	for _, s in { -1, 1 } do
		local a = at(s * (stairs + 0.3), hall.Balcony + 3, -Z + deep).Position
		local b = at(s * (stairs + 0.3), 3, -Z + deep + run).Position
		local rail = part(
			shell,
			CFrame.lookAt((a + b) / 2, b),
			Vector3.new(0.3, 0.3, (b - a).Magnitude),
			STEEL,
			Enum.Material.Metal
		)
		rail.Name = "Handrail"
	end
	-- The way back up: a lit doorway in the north wall, behind where you arrive.
	local leave = KaijuPit.Leave
	part(
		shell,
		at(leave.Center.X, leave.Center.Y + 5, -Z + 0.1),
		Vector3.new(leave.Half.X * 2, 10, 0.2),
		Color3.fromRGB(230, 236, 244),
		Enum.Material.Neon
	).Name =
		"WayUp"
	for _, s in { -1, 1 } do
		part(
			shell,
			at(s * (leave.Half.X + 0.6), leave.Center.Y + 5, -Z + 0.6),
			Vector3.new(1.2, 10.4, 1.2),
			HAZARD,
			Enum.Material.Metal
		)
	end
	-- (Signs on the north wall face south, into the hall: turned round.)
	local south = CFrame.Angles(0, math.pi, 0)
	sign(
		shell,
		at(0, leave.Center.Y + 12, -Z + 0.3) * south,
		Vector3.new(14, 2.4, 0.3),
		"UP TO THE SHELTER",
		nil,
		HAZARD
	)
	-- The arena's names: over the balcony on the north wall, and on the
	-- south wall facing you as you arrive.
	sign(shell, at(-40, 26, -Z + 0.3) * south, Vector3.new(34, 7, 0.4), "KAIJU ARENA", "STAND ON A PAD TO BATTLE", RED)
	sign(shell, at(40, 26, -Z + 0.3) * south, Vector3.new(34, 7, 0.4), "KAIJU ARENA", "WINNERS' KAIJU ARE HEALED", BLUE)
	sign(
		shell,
		at(0, 24, Z - 0.3),
		Vector3.new(48, 9, 0.4),
		"KAIJU ARENA",
		"STAND ON A PAD  ·  WAIT FOR A CHALLENGER  ·  25 S TO PLACE YOUR KAIJU",
		HAZARD
	)
	-- The rules, on the balcony's face beside the stairs (off the floor, out of the way).
	sign(
		shell,
		at(stairs + 7, 6, -Z + deep + 0.2) * south,
		Vector3.new(9, 4.2, 0.3),
		"HOW IT WORKS",
		"PAD · CHALLENGER · PLACE · FIGHT",
		HAZARD
	).Name =
		"Rules"
	-- Warm work lights along the walls.
	for x = -X + 18, X - 18, 36 do
		for _, s in { -1, 1 } do
			local lamp = part(shell, at(x, 18, s * (Z - 0.4)), Vector3.new(6, 0.5, 0.5), LAMP, Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Shadows = LAMP, 22, 0.5, false
			light.Parent = lamp
		end
	end

	-- The courts.
	local courts = KaijuPit.courts(origin)
	local holder = model(folder, "Courts")
	for i, info in courts do
		info.Model = court(holder, origin, info, i)
	end
	folder.Parent = parent
	return {
		Folder = folder,
		Origin = origin,
		-- (Turned round: the courts lie south, +z.)
		Arrive = origin * CFrame.new(KaijuPit.Arrive + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.pi, 0),
		Courts = courts,
	}
end

return KaijuPitWorld
