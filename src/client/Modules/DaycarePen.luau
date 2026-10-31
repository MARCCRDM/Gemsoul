--[[
	The Kaiju Daycare's pen, out on the quarry floor by the Shelter's main
	door (Shared.Daycare.Pen; Server.OutpostWorld keeps the ground there
	clear and flat). Built on each player's own screen (Client.OutpostScene
	mounts, shows and steps it, in the quarry's frame).

	In it, every kaiju boarded by a player in this server
	(ReplicatedStorage.DaycarePen, kept by Server.DaycareServer), wandering
	like the Kennel's (Shared.KaijuKennel.state, in this pen), each with a
	plate over it: its name, level and owner, and TRAINING or STORED.

	  DaycarePen.mount(frame)   the quarry's frame, Shared.Outpost.Location (once)
	  DaycarePen.show(on)
	  DaycarePen.step(dt)       built once there's ground under it; who's in
	                            it, and where (30 times a second at most)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daycare = require(Shared:WaitForChild("Daycare"))
local Kennel = require(Shared:WaitForChild("KaijuKennel"))
local KaijuModels = require(Shared:WaitForChild("KaijuModels"))
local GemConfig = require(Shared:WaitForChild("GemConfig"))

local DaycarePen = {}
DaycarePen.Reach = 320 -- studs from the pen: past this it's put away

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

-- The pen, out on the quarry floor (Shared.Daycare.Pen), in the Outpost's
-- own look (the Kennel's and the Shelter's: dark steel, hazard gold, the
-- quarry's crystals, cyan light): a raised steel deck, its edge striped
-- in hazard paint; on it a bed of packed regolith with a cyan ring path
-- set in it, and a holo training pylon in the middle; round it a
-- containment fence (steel posts, hazard caps, two bars of cyan energy
-- between them) open to the east (Gate); crystal clusters, a coolant pool,
-- feeding troughs and cargo crates inside; the KAIJU DAYCARE gantry over
-- the gate; a habitat module behind it (Barn: a hull half-sunk in the
-- deck, lit portholes, a hazard-framed door); floodlight pylons round it;
-- and the keeper's terminal in front of the gate (Desk) under a canopy,
-- its screen with the prices and its prompt (opens Client.DaycareUI).
local HULL = Color3.fromRGB(196, 200, 208)
local HULL_DARK = Color3.fromRGB(58, 62, 72)
local STEEL = Color3.fromRGB(70, 74, 82)
local PLATE = Color3.fromRGB(96, 100, 110)
local HAZARD = Color3.fromRGB(240, 178, 48)
local INK = Color3.fromRGB(22, 24, 30)
local GLOW = Color3.fromRGB(110, 220, 255)
local AMBER = Color3.fromRGB(255, 203, 126)
local REGOLITH = Color3.fromRGB(92, 92, 104)
local DECK = 0.6 -- the deck's top over the quarry floor
local LAWN = DECK + 0.08 -- (what they walk on)
-- The quarry's crystal colours (its elements' gems).
local CRYSTALS = {
	Color3.fromRGB(255, 120, 70), -- Thermal
	Color3.fromRGB(110, 220, 255), -- Cryo
	Color3.fromRGB(190, 120, 255), -- Ion
	Color3.fromRGB(120, 240, 140), -- Toxic
}

local function disc(parent: Instance, cframe: CFrame, radius: number, height: number, color: Color3, material: Enum.Material): Part
	local p = piece(parent, cframe * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, radius * 2, radius * 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	p.CastShadow = false
	return p
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Parent = part
end

-- A crystal cluster: a few glowing shards leaning out of a rock.
local function crystals(parent: Instance, base: CFrame, color: Color3, size: number)
	local rock = piece(parent, base * CFrame.new(0, 0.4 * size, 0), Vector3.new(1.8, 0.9, 1.6) * size, REGOLITH, Enum.Material.Slate)
	rock.Shape = Enum.PartType.Ball
	for k, shard in { { 0, 0, 2.6, 0 }, { 0.5, 0.3, 1.8, 24 }, { -0.5, -0.2, 1.6, -28 }, { 0.1, -0.5, 1.2, 14 } } do
		local tilt = base
			* CFrame.new(shard[1] * size, 0.5 * size, shard[2] * size)
			* CFrame.Angles(math.rad(shard[4] * 0.6), math.rad(k * 70), math.rad(shard[4]))
		local p = piece(parent, tilt * CFrame.new(0, shard[3] * size / 2, 0), Vector3.new(0.5, shard[3], 0.5) * size, color, Enum.Material.Neon)
		p.Transparency = 0.1
		p.CastShadow = false
	end
	light(rock, color, 10 * size, 0.7)
end

-- A floodlight pylon: a lattice mast, its lamp tipped down at the pen.
local function pylon(parent: Instance, base: CFrame, aim: Vector3)
	piece(parent, base * CFrame.new(0, 0.3, 0), Vector3.new(1.6, 0.6, 1.6), STEEL, Enum.Material.DiamondPlate)
	piece(parent, base * CFrame.new(0, 4.5, 0), Vector3.new(0.6, 8.4, 0.6), PLATE, Enum.Material.Metal)
	piece(parent, base * CFrame.new(0, 3, 0), Vector3.new(0.9, 0.5, 0.9), HAZARD, Enum.Material.Metal)
	local top = (base * CFrame.new(0, 8.9, 0)).Position
	local head = CFrame.lookAt(top, aim) * CFrame.Angles(math.rad(-8), 0, 0)
	piece(parent, head, Vector3.new(1.8, 1.1, 1.3), HULL_DARK, Enum.Material.Metal)
	local lens = piece(parent, head * CFrame.new(0, 0, -0.68), Vector3.new(1.4, 0.75, 0.06), AMBER, Enum.Material.Neon)
	light(lens, AMBER, 26, 1)
end

local function buildPen(frame: CFrame): Folder
	local made = Instance.new("Folder")
	made.Name = "DaycarePenBuilt"
	local spec = Daycare.Pen
	-- (its middle, turned so +X is toward the gate)
	local middle = frame * CFrame.new(spec.Middle) * CFrame.Angles(0, -spec.Gate, 0)
	local R = spec.Fence
	-- The deck: steel, its edge in hazard paint; the bed and its ring path.
	local deck = disc(made, middle * CFrame.new(0, DECK / 2, 0), R + 1.4, DECK, STEEL, Enum.Material.DiamondPlate)
	deck.CanCollide, deck.CanQuery = true, true
	disc(made, middle * CFrame.new(0, DECK + 0.01, 0), R + 1.45, 0.04, HAZARD, Enum.Material.SmoothPlastic)
	disc(made, middle * CFrame.new(0, DECK + 0.02, 0), R + 1.05, 0.05, STEEL, Enum.Material.DiamondPlate)
	disc(made, middle * CFrame.new(0, DECK + 0.04, 0), R - 0.2, 0.06, REGOLITH, Enum.Material.Ground)
	disc(made, middle * CFrame.new(0, DECK + 0.06, 0), spec.Outer + 0.5, 0.05, GLOW, Enum.Material.Neon).Transparency = 0.55
	disc(made, middle * CFrame.new(0, DECK + 0.07, 0), spec.Outer - 0.3, 0.06, REGOLITH, Enum.Material.Ground)
	disc(made, middle * CFrame.new(0, DECK + 0.08, 0), 2.8, 0.05, PLATE, Enum.Material.DiamondPlate)
	-- The containment fence: steel posts with hazard caps, two bars of cyan
	-- energy between them, open to the east.
	local posts = 32
	local gateHalf = math.rad(12)
	for i = 0, posts - 1 do
		local a = i / posts * math.pi * 2
		local b = (i + 1) / posts * math.pi * 2
		local pa = middle * CFrame.new(math.cos(a) * R, DECK, math.sin(a) * R)
		local pb = middle * CFrame.new(math.cos(b) * R, DECK, math.sin(b) * R)
		local mid = (a + b) / 2
		local inGate = math.abs(((mid + math.pi) % (math.pi * 2)) - math.pi) < gateHalf
		local atGate = math.abs(((a + math.pi) % (math.pi * 2)) - math.pi) < gateHalf * 0.7
		if not atGate then
			piece(made, pa * CFrame.new(0, 1.7, 0), Vector3.new(0.7, 3.4, 0.7), STEEL, Enum.Material.Metal, true)
			piece(made, pa * CFrame.new(0, 3.5, 0), Vector3.new(0.85, 0.3, 0.85), HAZARD, Enum.Material.Metal)
			piece(made, pa * CFrame.new(0, 3.7, 0), Vector3.new(0.3, 0.12, 0.3), GLOW, Enum.Material.Neon)
		end
		if not inGate then
			local centre = (pa.Position + pb.Position) / 2
			local span = (pb.Position - pa.Position).Magnitude
			for _, h in { 1.2, 2.6 } do
				local bar = piece(made, CFrame.lookAt(centre, pb.Position) * CFrame.new(0, h, 0), Vector3.new(0.12, 0.18, span), GLOW, Enum.Material.Neon)
				bar.Transparency = 0.35
				bar.CastShadow = false
			end
			-- (and a solid kick plate, so it's a wall to walk into)
			local plate = piece(made, CFrame.lookAt(centre, pb.Position) * CFrame.new(0, 0.35, 0), Vector3.new(0.2, 0.7, span), PLATE, Enum.Material.Metal, true)
			plate.CastShadow = false
		end
	end
	-- Inside, past where they walk (Outer): crystal clusters, a coolant
	-- pool, feeding troughs and cargo crates.
	local ring = (spec.Outer + R) / 2 + 0.4
	local function at(angle: number): CFrame
		return middle * CFrame.new(math.cos(angle) * ring, DECK + 0.06, math.sin(angle) * ring)
	end
	crystals(made, at(math.rad(130)), CRYSTALS[2], 1.3)
	crystals(made, at(math.rad(55)), CRYSTALS[3], 1)
	crystals(made, at(math.rad(300)), CRYSTALS[1], 1.1)
	crystals(made, at(math.rad(235)), CRYSTALS[4], 0.9)
	-- The coolant pool: a steel tank, glowing cyan inside.
	local pool = at(math.rad(195))
	disc(made, pool * CFrame.new(0, 0.3, 0), 2.6, 0.6, STEEL, Enum.Material.Metal)
	disc(made, pool * CFrame.new(0, 0.62, 0), 2.2, 0.06, GLOW, Enum.Material.Neon).Transparency = 0.25
	disc(made, pool * CFrame.new(0, 0.64, 0), 2.62, 0.04, HAZARD, Enum.Material.SmoothPlastic).Transparency = 0.0
	disc(made, pool * CFrame.new(0, 0.66, 0), 2.2, 0.05, GLOW, Enum.Material.Neon).Transparency = 0.2
	-- Feeding troughs: steel, a heap of glowing gem kibble in each.
	for k, angle in { 100, 160 } do
		local trough = at(math.rad(angle)) * CFrame.Angles(0, math.rad(-angle - 90), 0)
		piece(made, trough * CFrame.new(0, 0.45, 0), Vector3.new(3.4, 0.9, 1.3), PLATE, Enum.Material.Metal)
		piece(made, trough * CFrame.new(0, 0.92, 0), Vector3.new(3.5, 0.08, 1.4), HAZARD, Enum.Material.Metal)
		for g = -1, 1 do
			local kibble = piece(made, trough * CFrame.new(g * 0.9, 0.92, 0), Vector3.new(0.7, 0.4, 0.6), CRYSTALS[(k + g + 1) % 4 + 1], Enum.Material.Neon)
			kibble.Shape = Enum.PartType.Ball
		end
	end
	-- Cargo crates by the module.
	for k, c in { { 205, 0, 0 }, { 213, 0, 0.3 }, { 209, 1.6, 0.6 } } do
		local crate = at(math.rad(c[1])) * CFrame.new(0, 0.8 + c[2], 0) * CFrame.Angles(0, c[3], 0)
		piece(made, crate, Vector3.new(1.6, 1.6, 1.6), if k == 2 then HAZARD else PLATE, Enum.Material.DiamondPlate)
	end
	-- The training pylon in the middle: a steel plinth, a glowing column,
	-- and two holo rings round it (the ones training circle it).
	piece(made, middle * CFrame.new(0, DECK + 0.5, 0), Vector3.new(1.8, 1, 1.8), STEEL, Enum.Material.DiamondPlate, true)
	piece(made, middle * CFrame.new(0, DECK + 2.2, 0), Vector3.new(0.6, 2.4, 0.6), GLOW, Enum.Material.Neon)
	piece(made, middle * CFrame.new(0, DECK + 3.6, 0), Vector3.new(1.1, 0.4, 1.1), HAZARD, Enum.Material.Metal)
	for k, h in { 1.6, 2.8 } do
		local holo = disc(made, middle * CFrame.new(0, DECK + h, 0), 1.3 + k * 0.25, 0.08, GLOW, Enum.Material.Neon)
		holo.Transparency = 0.45
	end
	-- The gantry over the gate: two steel towers, a beam with the sign,
	-- hazard stripes and a row of lights under it.
	local gate = middle * CFrame.new(R, DECK, 0)
	local out = CFrame.lookAt(gate.Position, gate.Position + (gate.Position - middle.Position) * Vector3.new(1, 0, 1))
	for _, side in { -3.8, 3.8 } do
		piece(made, out * CFrame.new(side, 4, 0), Vector3.new(1.2, 8, 1.2), STEEL, Enum.Material.Metal, true)
		for k = 0, 3 do
			-- (hazard bands round the foot of each tower)
			if k < 2 then
				piece(made, out * CFrame.new(side, 0.5 + k * 0.9, 0), Vector3.new(1.28, 0.45, 1.28), HAZARD, Enum.Material.SmoothPlastic)
			end
		end
		local beacon = piece(made, out * CFrame.new(side, 8.3, 0), Vector3.new(0.6, 0.6, 0.6), GLOW, Enum.Material.Neon)
		beacon.Shape = Enum.PartType.Ball
	end
	local sign = piece(made, out * CFrame.new(0, 8.4, 0), Vector3.new(11, 2.2, 0.6), INK, Enum.Material.Metal)
	sign.Name = "DaycareSign"
	words(sign, "KAIJU DAYCARE", HAZARD, Enum.Font.GothamBlack, 64)
	piece(made, out * CFrame.new(0, 9.65, 0), Vector3.new(11.6, 0.3, 0.8), STEEL, Enum.Material.Metal)
	piece(made, out * CFrame.new(0, 7.15, 0), Vector3.new(11.6, 0.3, 0.8), STEEL, Enum.Material.Metal)
	local strip = piece(made, out * CFrame.new(0, 6.9, -0.1), Vector3.new(7.4, 0.12, 0.5), GLOW, Enum.Material.Neon)
	light(sign, AMBER, 18, 0.8)
	light(strip, GLOW, 14, 0.6)
	-- The habitat module behind the pen (Barn): a hull half-sunk in the
	-- deck, its ends capped, lit portholes along it, a hazard-framed door
	-- facing the pen.
	local barnAt = frame * CFrame.new(spec.Barn)
	local inward = ((frame * CFrame.new(spec.Middle)).Position - barnAt.Position) * Vector3.new(1, 0, 1)
	local hab = CFrame.lookAt(barnAt.Position, barnAt.Position + inward)
	-- (its length across: X; the door at -Z, to the pen)
	piece(made, hab * CFrame.new(0, 0.3, 0), Vector3.new(13, 0.6, 9.4), STEEL, Enum.Material.DiamondPlate, true)
	local hull = piece(made, hab * CFrame.new(0, 0.6, 0), Vector3.new(12, 9, 9), HULL, Enum.Material.SmoothPlastic, true)
	hull.Shape = Enum.PartType.Cylinder
	for _, side in { -1, 1 } do
		local cap = piece(made, hab * CFrame.new(side * 6.1, 0.6, 0), Vector3.new(0.4, 9.3, 9.3), HULL_DARK, Enum.Material.Metal)
		cap.Shape = Enum.PartType.Cylinder
	end
	for _, x in { -3.6, 0, 3.6 } do
		local rib = piece(made, hab * CFrame.new(x, 0.6, 0), Vector3.new(0.35, 9.2, 9.2), HULL_DARK, Enum.Material.Metal)
		rib.Shape = Enum.PartType.Cylinder
	end
	for _, x in { -4.8, -1.8, 1.8, 4.8 } do
		for _, z in { -1, 1 } do
			local port = piece(made, hab * CFrame.new(x, 3.4, z * 2.85) * CFrame.Angles(math.rad(z * 38), 0, 0), Vector3.new(0.9, 0.9, 0.2), AMBER, Enum.Material.Neon)
			port.Shape = Enum.PartType.Ball
		end
	end
	piece(made, hab * CFrame.new(0, 2.5, -4.25), Vector3.new(3.4, 4.2, 0.4), INK, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		piece(made, hab * CFrame.new(side * 1.9, 2.5, -4.35), Vector3.new(0.4, 4.6, 0.3), HAZARD, Enum.Material.SmoothPlastic)
	end
	piece(made, hab * CFrame.new(0, 4.75, -4.35), Vector3.new(4.2, 0.4, 0.3), HAZARD, Enum.Material.SmoothPlastic)
	local doorLight = piece(made, hab * CFrame.new(0, 5.3, -4.4), Vector3.new(1.2, 0.3, 0.3), GLOW, Enum.Material.Neon)
	light(doorLight, GLOW, 12, 0.6)
	-- A dish on its roof.
	piece(made, hab * CFrame.new(3.6, 5.6, 1), Vector3.new(0.3, 1.6, 0.3), PLATE, Enum.Material.Metal)
	local dish = piece(made, hab * CFrame.new(3.6, 6.6, 1) * CFrame.Angles(0, 0, math.rad(60)), Vector3.new(0.3, 2.4, 2.4), HULL, Enum.Material.SmoothPlastic)
	dish.Shape = Enum.PartType.Cylinder
	-- Floodlight pylons round it, tipped at the middle.
	for _, angle in { 45, 135, 225, 315 } do
		local a = math.rad(angle)
		pylon(made, middle * CFrame.new(math.cos(a) * (R + 3.2), 0, math.sin(a) * (R + 3.2)), (middle * CFrame.new(0, 1, 0)).Position)
	end
	-- Rocks of regolith about the deck's edge.
	for k, angle in { 20, 100, 160, 250, 290, 340 } do
		local a = math.rad(angle)
		local size = 1.2 + (k % 3) * 0.5
		local rock = piece(made, middle * CFrame.new(math.cos(a) * (R + 2.4), size * 0.3, math.sin(a) * (R + 2.4)) * CFrame.Angles(0.3, k, 0.2), Vector3.new(size * 1.3, size, size * 1.1), REGOLITH, Enum.Material.Slate)
		rock.Shape = Enum.PartType.Ball
	end
	-- A walkway of deck plates from the gate out to the terminal, its
	-- edges lit.
	local walkFrom, walkTo = R + 1.4, (Vector3.new(spec.Desk.X, 0, spec.Desk.Z) - Vector3.new(spec.Middle.X, 0, spec.Middle.Z)).Magnitude - 1.6
	local walkLen = math.max(1, walkTo - walkFrom)
	piece(made, middle * CFrame.new(walkFrom + walkLen / 2, 0.25, 0), Vector3.new(walkLen, 0.5, 4), STEEL, Enum.Material.DiamondPlate, true)
	for _, side in { -1, 1 } do
		piece(made, middle * CFrame.new(walkFrom + walkLen / 2, 0.52, side * 1.95), Vector3.new(walkLen, 0.06, 0.12), GLOW, Enum.Material.Neon)
	end
	-- The keeper's terminal in front of the gate, under a canopy: a steel
	-- counter, a console with its screen, a sign screen with the prices.
	local deskAt = frame * CFrame.new(spec.Desk)
	local desk = CFrame.lookAt(deskAt.Position, deskAt.Position + (deskAt.Position - gate.Position) * Vector3.new(1, 0, 1))
	piece(made, desk * CFrame.new(0, 0.25, 0), Vector3.new(8, 0.5, 5), STEEL, Enum.Material.DiamondPlate, true)
	piece(made, desk * CFrame.new(0, 1.3, 0), Vector3.new(6, 1.6, 1.6), PLATE, Enum.Material.Metal, true)
	piece(made, desk * CFrame.new(0, 2.16, 0), Vector3.new(6.3, 0.14, 1.9), HULL_DARK, Enum.Material.Metal)
	piece(made, desk * CFrame.new(0, 1.3, -0.82), Vector3.new(6, 0.25, 0.06), HAZARD, Enum.Material.SmoothPlastic)
	local console = piece(made, desk * CFrame.new(0, 2.8, 0.3) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(2.2, 1.2, 0.15), INK, Enum.Material.Metal)
	local screen = piece(made, console.CFrame * CFrame.new(0, 0, -0.09), Vector3.new(2, 1, 0.04), GLOW, Enum.Material.Neon)
	screen.Transparency = 0.2
	for _, side in { -3.3, 3.3 } do
		piece(made, desk * CFrame.new(side, 3, 1.4), Vector3.new(0.4, 6, 0.4), STEEL, Enum.Material.Metal)
	end
	piece(made, desk * CFrame.new(0, 6.05, 0.2) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(7.4, 0.3, 3.4), HULL_DARK, Enum.Material.Metal)
	for k = -3, 3 do
		piece(made, desk * CFrame.new(k * 1.05, 5.82, -1.45), Vector3.new(0.55, 0.22, 0.12), if k % 2 == 0 then HAZARD else INK, Enum.Material.SmoothPlastic)
	end
	local canopyLight = piece(made, desk * CFrame.new(0, 5.85, 0.2), Vector3.new(5, 0.08, 0.3), GLOW, Enum.Material.Neon)
	light(canopyLight, GLOW, 14, 0.7)
	local board = piece(made, desk * CFrame.new(5.6, 2.6, 0.6) * CFrame.Angles(0, math.rad(-20), 0), Vector3.new(3.4, 3.2, 0.25), INK, Enum.Material.Metal, true)
	board.Name = "DaycareBoard"
	words(board, string.format("STORE\n%d coins / h\n\nTRAIN\nfrom %d coins / h", Daycare.Store.PerHour, Daycare.trainRate(1)), GLOW, Enum.Font.GothamBold, 26)
	piece(made, desk * CFrame.new(5.6, 0.5, 0.6), Vector3.new(0.4, 1, 0.4), STEEL, Enum.Material.Metal)
	local anchor = piece(made, desk * CFrame.new(0, 2.6, 0), Vector3.new(1, 1, 1), INK, Enum.Material.SmoothPlastic)
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
