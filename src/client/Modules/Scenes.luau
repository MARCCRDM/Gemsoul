--[[
	The 3D sets for Saga Miners, built on the client (only you see
	them, and nothing is sent over the network):

	  Scenes.croc()        the brainrot alligator bomber, a crocodile with
	                       plane wings and propellers. Faces -Z.
	  Scenes.ship(at)      the colony ship's crew room: a cryo bed, the suit
	                       locker, the ration dispenser, the enchanting console,
	                       a teleport pad and a big window onto space.
	  Scenes.moonBase(at)  the moon base station: domes, habitat modules,
	                       vendor kiosks and the Saga Stone pylon.
	  Scenes.miningSite(at) the terraformed moon cliff where expeditions dig.
	  Scenes.miningGun(hand) the mining laser, welded to a hand.
	  Scenes.spaceLighting()  a black, starry sky with cool light.
	  Scenes.terraformLighting()  the same sky with a thin new atmosphere.

	Each builder returns a table with the Model and named spots (CFrames) for
	cameras and stations. Everything is anchored and non-colliding.
]]
local Lighting = game:GetService("Lighting")

local Scenes = {}

local SAGA = Color3.fromRGB(255, 184, 72) -- the amber glow of Saga Stones
local HOLO = Color3.fromRGB(90, 210, 255)
local ALARM = Color3.fromRGB(255, 60, 50)
local HULL = Color3.fromRGB(96, 104, 118)
local HULL_DARK = Color3.fromRGB(46, 50, 60)
local PANEL = Color3.fromRGB(150, 158, 170)

type Props = { [string]: any }

-- One anchored part. `shape` is "Ball", "Cylinder" (along X), "Wedge",
-- "Sphere" or "Tube" (mesh ellipsoid / mesh tube along Y, filling the size).
local function part(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: string?,
	props: Props?
): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if shape == "Ball" then
			(p :: Part).Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			(p :: Part).Shape = Enum.PartType.Cylinder
		end
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 1
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape == "Sphere" or shape == "Tube" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = if shape == "Sphere" then Enum.MeshType.Sphere else Enum.MeshType.Cylinder
		mesh.Parent = p
	end
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end
Scenes.part = part

local function glow(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, shape: string?): BasePart
	local p = part(parent, cframe, size, color, Enum.Material.Neon, shape)
	p.CastShadow = false
	return p
end

local function lamp(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- The brainrot alligator bomber --------------------------------------------------------------

function Scenes.croc(): Model
	local m = model("CrocBomber")
	local GREEN = Color3.fromRGB(74, 120, 58)
	local BELLY = Color3.fromRGB(196, 190, 140)
	local WING = Color3.fromRGB(128, 136, 120)
	local o = CFrame.identity
	-- Body and belly, a long snout with teeth, bulging eyes.
	part(m, o, Vector3.new(4, 3.4, 11), GREEN, Enum.Material.SmoothPlastic, "Sphere")
	part(m, o * CFrame.new(0, -0.7, 0), Vector3.new(3.4, 2.2, 9.4), BELLY, Enum.Material.SmoothPlastic, "Sphere")
	part(m, o * CFrame.new(0, 0.1, -7), Vector3.new(2.4, 1.3, 6), GREEN, Enum.Material.SmoothPlastic, "Sphere")
	part(m, o * CFrame.new(0, -0.45, -6.8), Vector3.new(2.2, 0.7, 5.6), BELLY, Enum.Material.SmoothPlastic, "Sphere")
	for i = 0, 5 do
		for _, side in { -1, 1 } do
			part(
				m,
				o * CFrame.new(side * 0.95, -0.15, -4.6 - i * 0.8) * CFrame.Angles(0, 0, math.rad(180)),
				Vector3.new(0.18, 0.4, 0.3),
				Color3.new(1, 1, 1),
				Enum.Material.SmoothPlastic,
				"Wedge"
			)
		end
	end
	for _, side in { -1, 1 } do
		part(
			m,
			o * CFrame.new(side * 0.9, 1.5, -3.2),
			Vector3.one * 1.2,
			Color3.fromRGB(240, 220, 90),
			Enum.Material.SmoothPlastic,
			"Ball"
		)
		part(
			m,
			o * CFrame.new(side * 0.95, 1.6, -3.75),
			Vector3.one * 0.5,
			Color3.new(0, 0, 0),
			Enum.Material.SmoothPlastic,
			"Ball"
		)
		-- Plane wings with a propeller engine under each.
		part(
			m,
			o * CFrame.new(side * 5.6, 0.2, 0.4) * CFrame.Angles(0, 0, math.rad(side * -6)),
			Vector3.new(8, 0.35, 3.2),
			WING,
			Enum.Material.Metal
		)
		part(
			m,
			o * CFrame.new(side * 9.4, 0.62, 0.4),
			Vector3.new(0.4, 0.4, 3.2),
			Color3.fromRGB(200, 60, 50),
			Enum.Material.SmoothPlastic
		)
		local engine = o * CFrame.new(side * 4.4, -0.8, -0.4)
		part(m, engine, Vector3.new(1.3, 3.2, 1.3), Color3.fromRGB(70, 74, 82), Enum.Material.Metal, "Tube", {
			CFrame = engine * CFrame.Angles(math.rad(90), 0, 0),
		})
		local hub = engine * CFrame.new(0, 0, -1.8)
		part(m, hub, Vector3.one * 0.5, Color3.fromRGB(40, 40, 44), Enum.Material.Metal, "Ball")
		local blade = part(m, hub, Vector3.new(3.4, 0.3, 0.1), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		blade.Name = "Propeller"
		-- Gun barrels, which glow when it fires.
		local gun = glow(m, o * CFrame.new(side * 1.6, -1.6, -3.4), Vector3.new(0.3, 0.3, 1.6), ALARM)
		gun.Name = "Gun"
	end
	-- Tail and fins.
	part(m, o * CFrame.new(0, 0.3, 7.4), Vector3.new(2.4, 1.8, 6), GREEN, Enum.Material.SmoothPlastic, "Sphere")
	part(
		m,
		o * CFrame.new(0, 2.1, 8.4) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(0.3, 2.6, 2.6),
		WING,
		Enum.Material.Metal,
		"Wedge"
	)
	for _, side in { -1, 1 } do
		part(m, o * CFrame.new(side * 1.8, 0.6, 9), Vector3.new(3, 0.25, 1.6), WING, Enum.Material.Metal)
	end
	-- Scales down the back.
	for i = -2, 3 do
		part(
			m,
			o * CFrame.new(0, 1.75, i * 1.3),
			Vector3.new(0.5, 0.5, 0.8),
			Color3.fromRGB(52, 90, 42),
			Enum.Material.SmoothPlastic,
			"Sphere"
		)
	end
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m.WorldPivot = CFrame.identity
	return m
end

-- Spin the croc's propellers (call every frame with the clock).
function Scenes.spinPropellers(croc: Model, t: number)
	for _, blade in croc:GetChildren() do
		if blade.Name == "Propeller" and blade:IsA("BasePart") then
			local base = blade:GetAttribute("Base") :: CFrame?
			if not base then
				base = croc:GetPivot():ToObjectSpace(blade.CFrame)
				blade:SetAttribute("Base", base)
			end
			blade.CFrame = croc:GetPivot() * (base :: CFrame) * CFrame.Angles(0, 0, t * 30)
		end
	end
end

-- The colony ship's crew room ------------------------------------------------------------------

export type Ship = {
	Model: Model,
	Spots: { [string]: CFrame }, -- where things are (world space)
	Stations: { [string]: BasePart }, -- the parts to label and click
	Alarms: { PointLight },
	AlarmStrips: { BasePart },
	Window: BasePart,
}

function Scenes.ship(at: CFrame): Ship
	local m = model("ColonyShip")
	local W, H, D = 34, 13, 26 -- the room: the window wall is at -Z
	local function c(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	-- Floor, ceiling and walls, with ribs.
	part(m, c(0, -0.5, 0), Vector3.new(W, 1, D), HULL_DARK, Enum.Material.DiamondPlate)
	part(m, c(0, H + 0.5, 0), Vector3.new(W, 1, D), HULL_DARK, Enum.Material.Metal)
	part(m, c(-W / 2 - 0.5, H / 2, 0), Vector3.new(1, H, D), HULL, Enum.Material.Metal)
	part(m, c(W / 2 + 0.5, H / 2, 0), Vector3.new(1, H, D), HULL, Enum.Material.Metal)
	part(m, c(0, H / 2, D / 2 + 0.5), Vector3.new(W, H, 1), HULL, Enum.Material.Metal)
	for x = -W / 2 + 4, W / 2 - 4, 6 do
		part(m, c(x, H - 0.3, 0), Vector3.new(0.8, 0.6, D), PANEL, Enum.Material.Metal)
	end
	-- The window wall: a frame around one big pane.
	local winW, winH, winY = 22, 8, 6.5
	part(m, c(0, (winY - winH / 2) / 2, -D / 2 - 0.5), Vector3.new(W, winY - winH / 2, 1), HULL, Enum.Material.Metal)
	part(
		m,
		c(0, (H + winY + winH / 2) / 2, -D / 2 - 0.5),
		Vector3.new(W, H - winY - winH / 2, 1),
		HULL,
		Enum.Material.Metal
	)
	for _, side in { -1, 1 } do
		part(
			m,
			c(side * (winW / 2 + (W - winW) / 4), winY, -D / 2 - 0.5),
			Vector3.new((W - winW) / 2, winH, 1),
			HULL,
			Enum.Material.Metal
		)
	end
	local window = part(
		m,
		c(0, winY, -D / 2 - 0.5),
		Vector3.new(winW, winH, 0.2),
		Color3.fromRGB(150, 200, 255),
		Enum.Material.Glass,
		nil,
		{
			Transparency = 0.85,
		}
	)
	part(m, c(0, winY, -D / 2 - 0.3), Vector3.new(0.4, winH, 0.4), PANEL, Enum.Material.Metal)
	-- Alarm strips along the ceiling, with red lights.
	local alarms, strips = {}, {}
	for _, x in { -W / 4, W / 4 } do
		local strip = glow(m, c(x, H - 0.1, 0), Vector3.new(0.5, 0.2, D - 4), ALARM)
		table.insert(strips, strip)
		table.insert(alarms, lamp(strip, ALARM, 30, 3))
	end
	-- Soft cool light so the room is readable.
	local fill = part(
		m,
		c(0, H - 1, 4),
		Vector3.one * 0.2,
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		nil,
		{ Transparency = 1 }
	)
	lamp(fill, Color3.fromRGB(170, 200, 255), 40, 0.8)

	local stations: { [string]: BasePart } = {}
	local spots: { [string]: CFrame } = {}

	-- Cryo bed (back left): where you wake up.
	local bed = c(-11, 0, 6)
	part(m, bed * CFrame.new(0, 1, 0), Vector3.new(5, 2, 9), PANEL, Enum.Material.Metal)
	part(
		m,
		bed * CFrame.new(0, 2.2, 0),
		Vector3.new(4.2, 0.5, 8.4),
		Color3.fromRGB(210, 214, 220),
		Enum.Material.Fabric
	)
	part(
		m,
		bed * CFrame.new(0, 3.3, 0),
		Vector3.new(4.6, 8.8, 2.4),
		Color3.fromRGB(160, 220, 255),
		Enum.Material.Glass,
		"Tube",
		{
			Transparency = 0.7,
			CFrame = bed * CFrame.new(0, 3.3, 0) * CFrame.Angles(math.rad(90), 0, 0),
		}
	)
	stations.Bed = glow(m, bed * CFrame.new(0, 2.05, -4.3), Vector3.new(4.4, 0.2, 0.3), HOLO)
	spots.Bed = bed * CFrame.new(0, 3, 0)

	-- Suit locker (left wall).
	local locker = c(-W / 2 + 1.5, 0, -4) * CFrame.Angles(0, math.rad(-90), 0)
	part(m, locker * CFrame.new(0, 4.5, 0), Vector3.new(6, 9, 2.4), PANEL, Enum.Material.Metal)
	part(
		m,
		locker * CFrame.new(0, 4.5, -1.25),
		Vector3.new(5, 7.6, 0.2),
		Color3.fromRGB(30, 40, 56),
		Enum.Material.Glass
	)
	stations.Locker = glow(m, locker * CFrame.new(0, 8.8, -1.3), Vector3.new(5, 0.3, 0.2), HOLO)
	spots.Locker = locker * CFrame.new(0, 0, -4)

	-- Ration dispenser (right wall): Saga Stones in a glowing tray.
	local ration = c(W / 2 - 1.5, 0, -2) * CFrame.Angles(0, math.rad(90), 0)
	part(m, ration * CFrame.new(0, 3.5, 0), Vector3.new(5, 7, 2.6), PANEL, Enum.Material.Metal)
	part(m, ration * CFrame.new(0, 3.2, -1.2), Vector3.new(3.6, 2, 0.4), HULL_DARK, Enum.Material.Metal)
	for i = -1, 1 do
		glow(
			m,
			ration * CFrame.new(i * 0.9, 3.2, -1.5) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(0.5, 0.5, 0.3),
			SAGA
		)
	end
	stations.Ration = glow(m, ration * CFrame.new(0, 6.2, -1.35), Vector3.new(4, 0.5, 0.2), SAGA)
	lamp(stations.Ration, SAGA, 10, 1.5)
	spots.Ration = ration * CFrame.new(0, 0, -4)

	-- Enchanting console (front right): a holo table.
	local console = c(8, 0, -6)
	part(m, console * CFrame.new(0, 1.6, 0), Vector3.new(3, 3.2, 3), HULL, Enum.Material.Metal, "Tube")
	part(m, console * CFrame.new(0, 3.3, 0), Vector3.new(4.4, 0.3, 4.4), PANEL, Enum.Material.Metal, "Tube")
	stations.Console = glow(m, console * CFrame.new(0, 4.6, 0), Vector3.new(1.6, 1.6, 1.6), HOLO, "Sphere")
	stations.Console.Transparency = 0.35
	lamp(stations.Console, HOLO, 12, 2)
	spots.Console = console

	-- Teleport pad (back middle).
	local pad = c(2, 0, 7)
	part(m, pad * CFrame.new(0, 0.2, 0), Vector3.new(7, 0.4, 7), HULL, Enum.Material.Metal, "Tube")
	stations.Pad = glow(m, pad * CFrame.new(0, 0.45, 0), Vector3.new(5.6, 0.1, 5.6), HOLO, "Tube")
	part(m, pad * CFrame.new(0, H - 0.6, 0), Vector3.new(6, 0.6, 6), PANEL, Enum.Material.Metal, "Tube")
	spots.Pad = pad

	-- Where the player's figure stands, and the camera shots.
	spots.Stand = c(0, 0, 0)
	spots.Window = c(0, winY, -D / 2 - 1)
	spots.Outside = c(0, winY + 4, -D / 2 - 70)

	-- A planet out of the window, far away.
	part(
		m,
		c(40, 30, -D / 2 - 700),
		Vector3.one * 420,
		Color3.fromRGB(70, 110, 170),
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	part(
		m,
		c(40, 30, -D / 2 - 700) * CFrame.Angles(math.rad(80), 0, math.rad(12)),
		Vector3.new(640, 2, 640),
		Color3.fromRGB(200, 180, 140),
		Enum.Material.Neon,
		"Tube",
		{
			Transparency = 0.88,
		}
	)

	m.Parent = workspace
	return {
		Model = m,
		Spots = spots,
		Stations = stations,
		Alarms = alarms,
		AlarmStrips = strips,
		Window = window,
	}
end

-- The moon base station ----------------------------------------------------------------------

export type Base = { Model: Model, Center: Vector3, Radius: number, Pylon: BasePart }

function Scenes.moonBase(at: CFrame): Base
	local m = model("MoonBase")
	local DUST = Color3.fromRGB(150, 150, 156)
	local WHITE = Color3.fromRGB(222, 226, 232)
	local function c(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	-- The moon's surface, with craters.
	part(m, c(0, -2, 0), Vector3.new(4, 700, 700), DUST, Enum.Material.Slate, "Cylinder", {
		CFrame = c(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local rng = Random.new(7)
	for _ = 1, 16 do
		local angle = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(90, 300)
		local size = rng:NextNumber(14, 40)
		part(
			m,
			c(math.cos(angle) * dist, 0.1, math.sin(angle) * dist),
			Vector3.new(size, 1.2, size),
			Color3.fromRGB(118, 118, 126),
			Enum.Material.Slate,
			"Sphere"
		)
		part(
			m,
			c(math.cos(angle) * dist, 0.5, math.sin(angle) * dist),
			Vector3.new(size * 0.7, 0.8, size * 0.7),
			Color3.fromRGB(96, 96, 104),
			Enum.Material.Slate,
			"Sphere"
		)
	end
	-- Rocks.
	for _ = 1, 24 do
		local angle = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(70, 320)
		local s = rng:NextNumber(3, 9)
		part(
			m,
			c(math.cos(angle) * dist, s * 0.3, math.sin(angle) * dist) * CFrame.Angles(0, rng:NextNumber() * 6, 0),
			Vector3.new(s, s * 0.7, s * 1.2),
			Color3.fromRGB(120, 120, 128),
			Enum.Material.Slate,
			"Sphere"
		)
	end

	-- The central plaza and the Saga Stone pylon.
	part(m, c(0, 0.3, 0), Vector3.new(1, 90, 90), Color3.fromRGB(70, 74, 84), Enum.Material.DiamondPlate, "Cylinder", {
		CFrame = c(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	glow(m, c(0, 0.85, 0), Vector3.new(0.2, 92, 92), HOLO, "Cylinder").CFrame = c(0, 0.85, 0)
		* CFrame.Angles(0, 0, math.rad(90))
	part(m, c(0, 0.95, 0), Vector3.new(0.3, 88, 88), Color3.fromRGB(70, 74, 84), Enum.Material.DiamondPlate, "Cylinder").CFrame = c(
		0,
		0.95,
		0
	) * CFrame.Angles(0, 0, math.rad(90))
	part(m, c(0, 6, 0), Vector3.new(8, 12, 8), WHITE, Enum.Material.Metal, "Tube")
	for _, side in { -1, 1 } do
		part(m, c(side * 3.5, 16, 0), Vector3.new(1.2, 20, 1.2), WHITE, Enum.Material.Metal, "Tube")
	end
	local pylon = glow(m, c(0, 22, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(7, 13, 7), SAGA, "Sphere")
	pylon.Name = "SagaPylon"
	lamp(pylon, SAGA, 60, 4)

	-- Domes and habitat modules in a ring, joined by tubes.
	local function dome(x: number, z: number, r: number, glass: boolean)
		part(
			m,
			c(x, 0, z),
			Vector3.new(r * 2, r * 2, r * 2),
			if glass then Color3.fromRGB(150, 210, 255) else WHITE,
			if glass then Enum.Material.Glass else Enum.Material.SmoothPlastic,
			"Ball",
			{
				Transparency = if glass then 0.45 else 0,
			}
		)
		part(
			m,
			c(x, 0.6, z),
			Vector3.new(1.2, r * 2 + 1, r * 2 + 1),
			Color3.fromRGB(80, 84, 94),
			Enum.Material.Metal,
			"Cylinder",
			{
				CFrame = c(x, 0.6, z) * CFrame.Angles(0, 0, math.rad(90)),
			}
		)
		if glass then
			-- Glowing gardens inside the glass domes.
			glow(m, c(x, 1.5, z), Vector3.new(r * 1.2, r * 0.5, r * 1.2), Color3.fromRGB(90, 220, 120), "Sphere")
		end
	end
	-- Domes around the plaza, each joined to it by a corridor tube.
	for _, spec in { { -70, -40, 26, true }, { 75, -30, 20, false }, { -40, 70, 18, false }, { 60, 65, 24, true } } do
		local x, z, r = spec[1], spec[2], spec[3]
		dome(x, z, r, spec[4])
		local from = Vector3.new(x, 0, z).Unit * 44
		local to = Vector3.new(x, 0, z) - Vector3.new(x, 0, z).Unit * r * 0.85
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		local corridor = c(mid.X, 3, mid.Z)
		local aim = CFrame.lookAt(corridor.Position, (c(to.X, 3, to.Z)).Position)
		part(m, aim, Vector3.new(6, length, 6), WHITE, Enum.Material.SmoothPlastic, "Tube", {
			CFrame = aim * CFrame.Angles(math.rad(90), 0, 0),
		})
	end

	-- Vendor kiosks around the plaza, each with a coloured holo sign.
	local kiosks = {
		{ "MARKET", SAGA, 0 },
		{ "FORGE", Color3.fromRGB(255, 120, 60), 72 },
		{ "ENCHANT", Color3.fromRGB(170, 110, 255), 144 },
		{ "SUPPLY", Color3.fromRGB(110, 220, 140), 216 },
		{ "MINE LIFT", HOLO, 288 },
	}
	for _, kiosk in kiosks do
		local k = c(0, 0, 0) * CFrame.Angles(0, math.rad(kiosk[3]), 0) * CFrame.new(0, 0, -34)
		part(m, k * CFrame.new(0, 3, 0), Vector3.new(9, 6, 5), WHITE, Enum.Material.SmoothPlastic)
		part(m, k * CFrame.new(0, 6.4, 0), Vector3.new(10, 0.8, 6), Color3.fromRGB(70, 74, 84), Enum.Material.Metal)
		local sign = glow(m, k * CFrame.new(0, 8.4, 0), Vector3.new(8, 2, 0.3), kiosk[2])
		lamp(sign, kiosk[2], 16, 1.5)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = kiosk[1]
		label.TextScaled = true
		label.Font = Enum.Font.Michroma
		label.TextColor3 = Color3.fromRGB(20, 20, 30)
		label.Parent = gui
		gui.Parent = sign
	end
	-- A landing pad with a parked shuttle, and a comms mast.
	part(m, c(0, 0.4, 120), Vector3.new(1, 50, 50), Color3.fromRGB(70, 74, 84), Enum.Material.Metal, "Cylinder", {
		CFrame = c(0, 0.4, 120) * CFrame.Angles(0, 0, math.rad(90)),
	})
	glow(m, c(0, 0.95, 120), Vector3.new(0.1, 40, 40), SAGA, "Cylinder").CFrame = c(0, 0.95, 120)
		* CFrame.Angles(0, 0, math.rad(90))
	part(m, c(0, 5, 120), Vector3.new(10, 7, 22), WHITE, Enum.Material.SmoothPlastic, "Sphere")
	for _, side in { -1, 1 } do
		part(m, c(side * 7, 3.5, 124), Vector3.new(8, 0.6, 7), Color3.fromRGB(80, 84, 94), Enum.Material.Metal)
	end
	part(m, c(-110, 22, -90), Vector3.new(1.5, 44, 1.5), WHITE, Enum.Material.Metal, "Tube")
	part(m, c(-110, 44, -90), Vector3.new(14, 2, 14), WHITE, Enum.Material.SmoothPlastic, "Sphere")
	glow(m, c(-110, 46, -90), Vector3.one * 1.4, ALARM, "Ball")
	-- A big planet hanging in the black sky.
	part(m, c(-500, 260, -900), Vector3.one * 520, Color3.fromRGB(60, 110, 180), Enum.Material.SmoothPlastic, "Ball")
	part(m, c(-470, 290, -880), Vector3.one * 460, Color3.fromRGB(90, 170, 110), Enum.Material.SmoothPlastic, "Ball", {
		Transparency = 0.55,
	})

	m.Parent = workspace
	return { Model = m, Center = at.Position + Vector3.new(0, 8, 0), Radius = 110, Pylon = pylon }
end

-- The mining site ------------------------------------------------------------------------------
-- A cliff on the moon where terraforming has begun: grey regolith and
-- craters, but green spreading out from a biodome with trees and a lake,
-- atmosphere processors breathing out air, Earth in the sky, and a rock face
-- veined with glowing Saga crystal under floodlights.

export type Site = {
	Model: Model,
	Stand: CFrame, -- where the miner stands (feet), facing the cliff
	Eye: Vector3, -- the camera, and what it looks at
	Look: Vector3,
	Face: CFrame, -- centre of the rock face, facing out (+Z toward the miner)
	FaceSize: Vector2,
}

function Scenes.miningSite(at: CFrame): Site
	local m = model("MiningSite")
	local REGOLITH = Color3.fromRGB(150, 150, 156)
	local ROCK = Color3.fromRGB(108, 104, 114)
	local GRASS = Color3.fromRGB(88, 156, 72)
	local GRASS_LIGHT = Color3.fromRGB(122, 182, 88)
	local WHITE = Color3.fromRGB(222, 226, 232)
	local METAL = Color3.fromRGB(80, 84, 94)
	local rng = Random.new(91)
	local function c(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	local function disc(x: number, y: number, z: number, w: number, d: number, h: number, color: Color3, material)
		return part(m, c(x, y, z), Vector3.new(w, h, d), color, material, "Sphere")
	end

	-- The ground: regolith with craters.
	part(m, c(0, -2, 0), Vector3.new(4, 760, 760), REGOLITH, Enum.Material.Slate, "Cylinder", {
		CFrame = c(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	for _ = 1, 14 do
		local angle = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(110, 320)
		local size = rng:NextNumber(16, 44)
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		disc(x, 0.1, z, size, size, 1.2, Color3.fromRGB(122, 122, 130), Enum.Material.Slate)
		disc(x, 0.5, z, size * 0.7, size * 0.7, 0.8, Color3.fromRGB(98, 98, 106), Enum.Material.Slate)
	end

	-- Terraforming: green spreading out across the regolith from the dome.
	for _ = 1, 30 do
		local x = rng:NextNumber(-150, 0)
		local z = rng:NextNumber(-130, 30)
		local s = rng:NextNumber(10, 34)
		disc(
			x,
			0.15,
			z,
			s,
			s * rng:NextNumber(0.6, 1),
			0.7,
			if rng:NextNumber() < 0.5 then GRASS else GRASS_LIGHT,
			Enum.Material.Grass
		)
	end
	-- Little tufts and flowers at the edges of the green.
	for _ = 1, 50 do
		local x = rng:NextNumber(-140, -6)
		local z = rng:NextNumber(-120, 26)
		disc(x, 0.6, z, 1.6, 1.6, 1.2, GRASS_LIGHT, Enum.Material.LeafyGrass)
		if rng:NextNumber() < 0.35 then
			local petal = ({
				Color3.fromRGB(255, 214, 90),
				Color3.fromRGB(255, 140, 190),
				Color3.fromRGB(170, 140, 255),
			})[rng:NextInteger(1, 3)]
			glow(m, c(x + 0.4, 1.3, z), Vector3.one * 0.5, petal, "Ball")
		end
	end

	-- The biodome: grass, a lake and trees under glass.
	local DOME_X, DOME_Z, DOME_R = -62, -44, 30
	disc(DOME_X, 0.3, DOME_Z, DOME_R * 2, DOME_R * 2, 1, GRASS, Enum.Material.Grass)
	part(
		m,
		c(DOME_X + 4, 0.25, DOME_Z + 8),
		Vector3.new(24, 0.6, 14),
		Color3.fromRGB(70, 150, 210),
		Enum.Material.Glass,
		"Sphere",
		{
			Transparency = 0.15,
			Reflectance = 0.2,
		}
	)
	local function tree(x: number, z: number, h: number)
		part(m, c(x, h / 2, z), Vector3.new(1.4, h, 1.4), Color3.fromRGB(110, 78, 52), Enum.Material.Wood, "Tube")
		for i = 1, 3 do
			local s = h * rng:NextNumber(0.45, 0.7)
			part(
				m,
				c(x + rng:NextNumber(-1.5, 1.5), h + rng:NextNumber(-1, 1.5) + i * 0.6, z + rng:NextNumber(-1.5, 1.5)),
				Vector3.new(s, s * 0.85, s),
				if i == 2 then Color3.fromRGB(66, 138, 64) else Color3.fromRGB(84, 160, 74),
				Enum.Material.LeafyGrass,
				"Ball"
			)
		end
	end
	for _, spec in
		{
			{ -74, -56, 10 },
			{ -66, -64, 8 },
			{ -50, -58, 9 },
			{ -78, -36, 8 },
			{ -54, -30, 7 },
			{ -70, -24, 9 },
			{ -42, -44, 6 },
			-- Young trees planted out in the open.
			{ -24, -18, 5 },
			{ -30, 4, 4 },
			{ -96, -10, 6 },
			{ -110, -60, 7 },
			{ -18, -40, 4 },
		}
	do
		tree(spec[1], spec[2], spec[3])
	end
	part(
		m,
		c(DOME_X, 0, DOME_Z),
		Vector3.one * DOME_R * 2,
		Color3.fromRGB(170, 220, 255),
		Enum.Material.Glass,
		"Ball",
		{
			Transparency = 0.72,
			CastShadow = false,
		}
	)
	part(
		m,
		c(DOME_X, 0.6, DOME_Z),
		Vector3.new(1.4, DOME_R * 2 + 1.5, DOME_R * 2 + 1.5),
		METAL,
		Enum.Material.Metal,
		"Cylinder",
		{
			CFrame = c(DOME_X, 0.6, DOME_Z) * CFrame.Angles(0, 0, math.rad(90)),
		}
	)

	-- Atmosphere processors breathing out the new air.
	for _, spec in { { -118, -110, 46 }, { 46, -86, 52 }, { -20, -150, 40 } } do
		local x, z, h = spec[1], spec[2], spec[3]
		part(m, c(x, h / 2, z), Vector3.new(7, h, 7), WHITE, Enum.Material.SmoothPlastic, "Tube")
		part(m, c(x, 1.5, z), Vector3.new(12, 3, 12), METAL, Enum.Material.DiamondPlate, "Tube")
		for i = 1, 3 do
			glow(m, c(x, h * i / 4, z), Vector3.new(7.6, 0.6, 7.6), HOLO, "Tube")
		end
		part(m, c(x, h + 1.5, z), Vector3.new(10, 3, 10), METAL, Enum.Material.Metal, "Tube")
		for i = 1, 4 do
			local puff = part(
				m,
				c(x + rng:NextNumber(-3, 3), h + 6 + i * 6, z + rng:NextNumber(-3, 3)),
				Vector3.one * (6 + i * 4),
				Color3.fromRGB(235, 242, 250),
				Enum.Material.SmoothPlastic,
				"Ball",
				{ Transparency = 0.55 + i * 0.1, CastShadow = false }
			)
			if i == 1 then
				local mist = Instance.new("ParticleEmitter")
				mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
				mist.Color = ColorSequence.new(Color3.fromRGB(230, 240, 250))
				mist.Transparency = NumberSequence.new(0.5, 1)
				mist.Size = NumberSequence.new(4, 14)
				mist.Lifetime = NumberRange.new(4, 6)
				mist.Rate = 3
				mist.Speed = NumberRange.new(3, 5)
				mist.SpreadAngle = Vector2.new(12, 12)
				mist.Parent = puff
			end
		end
	end

	-- The rock face, veined with Saga crystal.
	local FACE_Z = -14
	local FACE_X = 12
	part(m, c(FACE_X + 12, 11, FACE_Z - 9), Vector3.new(70, 24, 16), ROCK, Enum.Material.Slate)
	for _ = 1, 22 do
		local x = FACE_X + rng:NextNumber(-26, 34)
		local h = rng:NextNumber(8, 22)
		local w = rng:NextNumber(6, 13)
		part(
			m,
			c(x, h / 2 - 1, FACE_Z - rng:NextNumber(0, 4))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.3, 0.3)),
			Vector3.new(w, h, w * 0.8),
			ROCK:Lerp(Color3.fromRGB(140, 134, 128), rng:NextNumber(0, 0.6)),
			if rng:NextNumber() < 0.6 then Enum.Material.Slate else Enum.Material.Basalt
		)
	end
	-- Fallen rubble at the foot of the cliff.
	for _ = 1, 16 do
		local s = rng:NextNumber(1, 3)
		part(
			m,
			c(FACE_X + rng:NextNumber(-24, 10), s * 0.3, FACE_Z + rng:NextNumber(1, 6))
				* CFrame.Angles(rng:NextNumber() * 3, rng:NextNumber() * 3, 0),
			Vector3.new(s, s * 0.8, s * 1.1),
			ROCK:Lerp(REGOLITH, 0.4),
			Enum.Material.Slate
		)
	end
	-- Crystal veins across the face, and clusters breaking through.
	for i = 1, 7 do
		local color = if i % 3 == 0 then HOLO else SAGA
		glow(
			m,
			c(FACE_X + rng:NextNumber(-24, 2), rng:NextNumber(3, 13), FACE_Z + 3.6)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.9, 0.9)),
			Vector3.new(rng:NextNumber(5, 11), 0.3, 0.3),
			color
		)
	end
	for _, spec in { { -22, 4, SAGA }, { -16, 9, HOLO }, { -10, 3, SAGA }, { -4, 11, SAGA }, { 2, 7, HOLO } } do
		local cluster = c(FACE_X + spec[1], spec[2], FACE_Z + 3.4)
		for k = 1, 4 do
			local shard = part(
				m,
				cluster
					* CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.9, 0.9))
					* CFrame.new(0, 0.6 + k * 0.2, 0),
				Vector3.new(0.6, rng:NextNumber(1.6, 3), 0.6),
				spec[3],
				Enum.Material.Glass,
				nil,
				{ Transparency = 0.15, CastShadow = false }
			)
			if k == 1 then
				lamp(shard, spec[3], 10, 1.4)
			end
		end
		glow(m, cluster, Vector3.one * 0.9, spec[3], "Ball")
	end

	-- Floodlights on the face, an ore cart on rails and supply crates.
	for _, x in { -14, 20 } do
		part(m, c(x, 5, 1), Vector3.new(0.6, 10, 0.6), METAL, Enum.Material.Metal, "Tube")
		local head = part(
			m,
			CFrame.lookAt(c(x, 10, 1).Position, c(FACE_X, 5, FACE_Z).Position),
			Vector3.new(2.4, 1.4, 1.2),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		local lens =
			glow(m, head.CFrame * CFrame.new(0, 0, -0.65), Vector3.new(2, 1, 0.1), Color3.fromRGB(255, 244, 214))
		local beam = Instance.new("SpotLight")
		beam.Color = Color3.fromRGB(255, 240, 210)
		beam.Range = 40
		beam.Brightness = 3
		beam.Angle = 60
		beam.Face = Enum.NormalId.Front
		beam.Parent = lens
	end
	for _, x in { -1.4, 1.4 } do
		part(
			m,
			c(14 + x, 0.25, 6) * CFrame.Angles(0, math.rad(20), 0),
			Vector3.new(0.3, 0.3, 30),
			METAL,
			Enum.Material.Metal
		)
	end
	local cart = c(15, 1.8, 3) * CFrame.Angles(0, math.rad(20), 0)
	part(m, cart, Vector3.new(4, 2.2, 5.5), Color3.fromRGB(200, 120, 50), Enum.Material.Metal)
	for _, offset in { { -1.2, -1.6 }, { 1.2, -1.6 }, { -1.2, 1.6 }, { 1.2, 1.6 } } do
		part(
			m,
			cart * CFrame.new(offset[1] * 1.6, -1.2, offset[2]),
			Vector3.new(0.5, 1, 1),
			HULL_DARK,
			Enum.Material.Metal,
			"Cylinder"
		)
	end
	for k = 1, 5 do
		part(
			m,
			cart * CFrame.new(rng:NextNumber(-1.2, 1.2), 1.3, rng:NextNumber(-2, 2)),
			Vector3.one * rng:NextNumber(0.8, 1.4),
			ROCK,
			Enum.Material.Slate,
			"Ball"
		)
		if k <= 2 then
			glow(
				m,
				cart * CFrame.new(rng:NextNumber(-1, 1), 1.6, rng:NextNumber(-1.5, 1.5)),
				Vector3.new(0.4, 0.9, 0.4),
				SAGA
			)
		end
	end
	for _, spec in { { -15, 4 }, { -17.5, 5.5 }, { -16, 6.8 } } do
		part(
			m,
			c(spec[1], 1, spec[2]) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			Vector3.new(2, 2, 2),
			Color3.fromRGB(70, 78, 92),
			Enum.Material.DiamondPlate
		)
		glow(m, c(spec[1], 2.05, spec[2]), Vector3.new(1.6, 0.1, 0.3), HOLO)
	end

	-- Earth, already looking a little like home, hangs over the valley.
	part(m, c(-560, 330, -900), Vector3.one * 380, Color3.fromRGB(56, 112, 190), Enum.Material.SmoothPlastic, "Ball")
	part(m, c(-544, 352, -884), Vector3.one * 340, Color3.fromRGB(92, 170, 102), Enum.Material.SmoothPlastic, "Ball", {
		Transparency = 0.6,
	})
	part(m, c(-566, 338, -870), Vector3.one * 394, Color3.fromRGB(240, 246, 255), Enum.Material.SmoothPlastic, "Ball", {
		Transparency = 0.82,
	})

	m.Parent = workspace
	return {
		Model = m,
		Stand = CFrame.lookAt(c(-1, 0, 3).Position, c(FACE_X - 16, 0, FACE_Z).Position),
		Eye = c(6, 7, 14).Position,
		Look = c(5, 6, -30).Position,
		Face = c(FACE_X - 16, 6, FACE_Z + 3),
		FaceSize = Vector2.new(8, 6),
	}
end

-- The mining laser: a chunky emitter held in the right hand while digging.
-- Built pointing down -Y (along the arm), welded to `hand`; returns its parts
-- and the muzzle part (the beam starts there).
function Scenes.miningGun(hand: BasePart, accent: Color3?): ({ BasePart }, BasePart)
	local glowColor = accent or HOLO
	local parts = {}
	local function piece(offset: CFrame, size: Vector3, color: Color3, material: Enum.Material?, shape: string?)
		local p = part(hand.Parent :: Instance, hand.CFrame * offset, size, color, material, shape)
		p.Anchored = false
		p.Massless = true
		p.CastShadow = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		table.insert(parts, p)
		return p
	end
	local GUN = Color3.fromRGB(226, 160, 52)
	local DARK = Color3.fromRGB(48, 52, 62)
	-- Grip and body.
	piece(CFrame.new(0, -0.2, 0.15), Vector3.new(0.35, 0.7, 0.4), DARK, Enum.Material.SmoothPlastic)
	piece(CFrame.new(0, -0.9, -0.15), Vector3.new(0.6, 1.3, 0.7), GUN, Enum.Material.SmoothPlastic)
	piece(CFrame.new(0, -0.8, 0.35), Vector3.new(0.5, 0.9, 0.35), DARK, Enum.Material.Metal)
	-- The energy cell, glowing.
	piece(CFrame.new(0.38, -0.85, -0.15), Vector3.new(0.18, 0.8, 0.5), glowColor, Enum.Material.Neon)
	-- Emitter barrel with cooling rings.
	piece(CFrame.new(0, -1.8, -0.15), Vector3.new(0.42, 0.9, 0.42), DARK, Enum.Material.Metal, "Tube")
	for i = 0, 2 do
		piece(CFrame.new(0, -1.55 - i * 0.25, -0.15), Vector3.new(0.56, 0.08, 0.56), GUN, Enum.Material.Metal, "Tube")
	end
	local muzzle = piece(CFrame.new(0, -2.3, -0.15), Vector3.new(0.3, 0.12, 0.3), glowColor, Enum.Material.Neon, "Tube")
	muzzle.Name = "Muzzle"
	return parts, muzzle
end

-- Terraformed: still a starry sky, but with a thin new atmosphere and warm light.
function Scenes.terraformLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 116, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 168, 184)
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(150, 180, 220)
	atmosphere.Decay = Color3.fromRGB(70, 90, 130)
	atmosphere.Haze = 0.6
	atmosphere.Glare = 0
	atmosphere.Parent = Lighting
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
end

-- Space: a black, starry sky, no haze, cool light that still shows colours.
function Scenes.spaceLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(96, 102, 122)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 156, 176)
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0
		atmosphere.Haze = 0
		atmosphere.Glare = 0
	end
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 5000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = false
	end
end

return Scenes
