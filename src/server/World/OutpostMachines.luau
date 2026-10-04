--[[
	The big machines at the Outpost's Motor Pool: an HX-9 Hauler dump truck,
	a Mole drill crawler (its drill really spins), an EX-4 Digger excavator
	and a Skipper moon rover. They're for driving around the quarry, nothing
	more.

	Each machine is one physics assembly: an invisible box "Chassis" that
	slides on the ground (its PrimaryPart), with the bodywork welded on and
	massless. A VehicleSeat "Seat" takes the driver's input; the driver's
	client steers through two constraints on the chassis:
	  Drive  (LinearVelocity, Plane mode)   horizontal velocity (gravity is free,
	                                        so it falls off ramps and jumps)
	  Steer  (AlignOrientation)             heading, kept level
	The seat carries the machine's kind in its "OutpostMachine" attribute.

	  OutpostMachines.build(kind, cframe) -> Model   standing on `cframe`
	                                                 (its bottom on the ground)
]]
local OutpostMachines = {}

local YELLOW = Color3.fromRGB(242, 182, 36)
local ORANGE = Color3.fromRGB(236, 128, 40)
local DARK = Color3.fromRGB(38, 40, 46)
local RUBBER = Color3.fromRGB(22, 22, 26)
local STEEL = Color3.fromRGB(150, 156, 166)
local GLASS = Color3.fromRGB(70, 110, 150)
local WHITE = Color3.fromRGB(232, 234, 238)
local LAMP = Color3.fromRGB(255, 246, 214)

-- The chassis box for each machine (width, height, length; forward is -Z).
local CHASSIS = {
	Hauler = Vector3.new(15, 5, 30),
	Mole = Vector3.new(14, 6, 26),
	Digger = Vector3.new(13, 4, 20),
	Skipper = Vector3.new(9, 2.4, 13),
}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- A piece of bodywork welded to `base`, at `offset` from it.
local function piece(model, base: BasePart, offset: CFrame, size: Vector3, color, material, shape)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	if shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = base.CFrame * offset
	p.Anchored = false
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Massless = true
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 2
	p.Parent = model
	weld(base, p)
	return p
end

-- A wheel: a cylinder whose axis runs across the machine, with a hub cap.
local function wheel(model, base, x: number, y: number, z: number, radius: number, width: number)
	piece(
		model,
		base,
		CFrame.new(x, y, z),
		Vector3.new(width, radius * 2, radius * 2),
		RUBBER,
		Enum.Material.Rubber,
		"Cylinder"
	)
	piece(
		model,
		base,
		CFrame.new(x + math.sign(x) * (width / 2 + 0.05), y, z),
		Vector3.new(0.2, radius * 0.9, radius * 0.9),
		STEEL,
		Enum.Material.Metal,
		"Cylinder"
	)
end

-- A crawler track down one side: a rubber belt with tread bars.
local function track(model, base, x: number, height: number, length: number, bottom: number)
	piece(
		model,
		base,
		CFrame.new(x, bottom + height / 2, 0),
		Vector3.new(3.4, height, length),
		RUBBER,
		Enum.Material.Rubber
	)
	local bars = math.floor(length / 2.4)
	for i = 0, bars - 1 do
		local z = -length / 2 + 1.2 + i * 2.4
		piece(
			model,
			base,
			CFrame.new(x + math.sign(x) * 1.75, bottom + height / 2, z),
			Vector3.new(0.2, height - 0.6, 0.9),
			DARK,
			Enum.Material.Metal
		)
	end
	for _, z in { -length / 2 + height / 2, length / 2 - height / 2 } do
		piece(
			model,
			base,
			CFrame.new(x, bottom + height / 2, z),
			Vector3.new(3.6, height * 0.8, height * 0.8),
			STEEL,
			Enum.Material.Metal,
			"Cylinder"
		)
	end
end

local function lamp(model, base, offset: CFrame)
	local p = piece(model, base, offset, Vector3.new(1.4, 0.9, 0.2), LAMP, Enum.Material.Neon)
	local l = Instance.new("SpotLight")
	l.Face, l.Range, l.Brightness, l.Angle = Enum.NormalId.Front, 40, 2, 50
	l.Color = LAMP
	l.Parent = p
	return p
end

-- The bodywork of each machine, around its chassis (bottom at -h/2).
local BODY = {}

function BODY.Hauler(model, c: BasePart)
	local b = -2.5 -- chassis bottom
	piece(model, c, CFrame.new(0, b + 3.5, 0), Vector3.new(12, 2.4, 29), DARK, Enum.Material.Metal)
	-- The dump bed.
	piece(model, c, CFrame.new(0, b + 5.4, 5), Vector3.new(15, 1, 19), YELLOW, Enum.Material.Metal)
	for side = -1, 1, 2 do
		piece(model, c, CFrame.new(side * 7, b + 8.6, 5), Vector3.new(1, 6.4, 19), YELLOW, Enum.Material.Metal)
		for i = 0, 3 do
			piece(
				model,
				c,
				CFrame.new(side * 7.55, b + 8.6, -2 + i * 4.6),
				Vector3.new(0.3, 6, 0.6),
				ORANGE,
				Enum.Material.Metal
			)
		end
	end
	piece(model, c, CFrame.new(0, b + 9.4, -4.6), Vector3.new(15, 8, 1), YELLOW, Enum.Material.Metal)
	piece(model, c, CFrame.new(0, b + 8.2, 14.6), Vector3.new(15, 5.6, 0.8), YELLOW, Enum.Material.Metal)
	piece(model, c, CFrame.new(0, b + 13.6, -7.4), Vector3.new(15, 0.8, 6), YELLOW, Enum.Material.Metal)
	-- Engine and cab up front.
	piece(model, c, CFrame.new(1.8, b + 6.4, -12.4), Vector3.new(11, 4.6, 5), YELLOW, Enum.Material.Metal)
	piece(model, c, CFrame.new(1.8, b + 6.2, -15.0), Vector3.new(9, 3.4, 0.3), DARK, Enum.Material.DiamondPlate)
	piece(model, c, CFrame.new(-4.6, b + 9, -11), Vector3.new(5.6, 7.4, 6.6), YELLOW, Enum.Material.Metal)
	piece(model, c, CFrame.new(-4.6, b + 10.4, -14.35), Vector3.new(4.8, 2.6, 0.2), GLASS, Enum.Material.Glass).Transparency =
		0.35
	piece(model, c, CFrame.new(-7.45, b + 10.4, -11), Vector3.new(0.2, 2.6, 5.2), GLASS, Enum.Material.Glass).Transparency =
		0.35
	piece(
		model,
		c,
		CFrame.new(5.8, b + 11, -12) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(6, 0.9, 0.9),
		RUBBER,
		Enum.Material.Metal,
		"Cylinder"
	)
	for _, x in { -6, 6 } do
		lamp(model, c, CFrame.new(x, b + 6, -15.1))
	end
	-- Six big wheels.
	for _, z in { -10, 4, 10 } do
		for side = -1, 1, 2 do
			wheel(model, c, side * 7.4, b + 4, z, 4, 3)
		end
	end
	-- A ladder up to the cab.
	for i = 0, 3 do
		piece(model, c, CFrame.new(-7.9, b + 2.2 + i * 1.3, -8), Vector3.new(0.2, 0.2, 1.6), STEEL, Enum.Material.Metal)
	end
	return CFrame.new(-4.6, b + 6.1, -10.6) -- the seat
end

function BODY.Mole(model, c: BasePart)
	local b = -3
	for side = -1, 1, 2 do
		track(model, c, side * 5.6, 5.4, 26, b)
	end
	piece(model, c, CFrame.new(0, b + 6.4, 2), Vector3.new(8.4, 6, 20), YELLOW, Enum.Material.Metal)
	piece(model, c, CFrame.new(0, b + 6.4, 12.2), Vector3.new(8, 4, 0.4), DARK, Enum.Material.DiamondPlate)
	-- The glass cab on top.
	piece(model, c, CFrame.new(0, b + 11.2, 5), Vector3.new(6.4, 3.6, 6.4), GLASS, Enum.Material.Glass).Transparency =
		0.4
	piece(model, c, CFrame.new(0, b + 13.2, 5), Vector3.new(7, 0.6, 7), YELLOW, Enum.Material.Metal)
	-- The drill mount.
	piece(model, c, CFrame.new(0, b + 6, -9.5), Vector3.new(9, 9, 3), DARK, Enum.Material.Metal)
	for _, x in { -3.4, 3.4 } do
		lamp(model, c, CFrame.new(x, b + 10.8, -11.1))
	end
	piece(model, c, CFrame.new(3, b + 14.4, 8), Vector3.new(0.3, 2.4, 0.3), STEEL, Enum.Material.Metal)
	local beacon = piece(model, c, CFrame.new(3, b + 15.8, 8), Vector3.one * 0.8, ORANGE, Enum.Material.Neon, "Ball")
	beacon.Name = "Beacon"
	return CFrame.new(0, b + 9.8, 5)
end

-- The Mole's drill: a separate spinning assembly on a motor hinge.
local function drill(model, c: BasePart)
	local b = -3
	local hub = Instance.new("Part")
	hub.Name = "DrillHub"
	hub.Size = Vector3.new(4, 4, 2)
	hub.Transparency = 1
	hub.CanCollide, hub.CanTouch, hub.CanQuery = false, false, false
	hub.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.3, 0)
	hub.CFrame = c.CFrame * CFrame.new(0, b + 6, -12)
	hub.Parent = model
	-- Stacked rings narrowing to a point, black and white with spikes.
	local rings = { { 4.8, 2.4, -1.2 }, { 4, 2.6, -3.6 }, { 3.2, 2.6, -6.2 }, { 2.4, 2.6, -8.8 }, { 1.5, 2.6, -11.2 } }
	for i, ring in rings do
		local p = piece(
			model,
			hub,
			CFrame.new(0, 0, ring[3]) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(ring[2], ring[1] * 2, ring[1] * 2),
			if i % 2 == 0 then WHITE else RUBBER,
			Enum.Material.Metal,
			"Cylinder"
		)
		p.Name = "Drill"
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + i * 0.5
			piece(
				model,
				hub,
				CFrame.new(math.cos(a) * ring[1], math.sin(a) * ring[1], ring[3]) * CFrame.Angles(0, 0, a - math.pi / 2),
				Vector3.new(0.8, 1.6, 1.4),
				if i % 2 == 0 then RUBBER else WHITE,
				Enum.Material.Metal,
				"Wedge"
			)
		end
	end
	piece(model, hub, CFrame.new(0, 0, -13), Vector3.one * 1.6, STEEL, Enum.Material.Metal, "Ball")
	-- The hinge: both attachments' primary axis along the machine's forward.
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.new(0, b + 6, -12) * CFrame.Angles(0, math.rad(90), 0)
	a0.Parent = c
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.Angles(0, math.rad(90), 0)
	a1.Parent = hub
	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "DrillMotor"
	hinge.Attachment0, hinge.Attachment1 = a0, a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.MotorMaxTorque = 1e5
	hinge.AngularVelocity = 1.5
	hinge.Parent = hub
	return hub
end

function BODY.Digger(model, c: BasePart)
	local b = -2
	for side = -1, 1, 2 do
		track(model, c, side * 4.8, 3.8, 20, b)
	end
	piece(
		model,
		c,
		CFrame.new(0, b + 4.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(1.2, 6, 6),
		DARK,
		Enum.Material.Metal,
		"Cylinder"
	)
	-- The house, counterweight and cab.
	piece(model, c, CFrame.new(0.6, b + 8, 2), Vector3.new(10.6, 6, 12), ORANGE, Enum.Material.Metal)
	piece(model, c, CFrame.new(0.6, b + 6.6, 8.8), Vector3.new(10.6, 3.6, 2), DARK, Enum.Material.Metal)
	piece(model, c, CFrame.new(-3, b + 9.6, -5.6), Vector3.new(4.6, 7, 4.6), ORANGE, Enum.Material.Metal)
	piece(model, c, CFrame.new(-3, b + 10.6, -7.95), Vector3.new(3.8, 3.4, 0.2), GLASS, Enum.Material.Glass).Transparency =
		0.35
	piece(model, c, CFrame.new(3.4, b + 12.4, 4), Vector3.new(0.6, 3, 0.6), RUBBER, Enum.Material.Metal)
	lamp(model, c, CFrame.new(-3, b + 13.4, -8))
	-- The boom, stick and bucket, held up as if mid-dig.
	piece(
		model,
		c,
		CFrame.new(2.4, b + 13, -8.6) * CFrame.Angles(math.rad(32), 0, 0),
		Vector3.new(2.2, 2.4, 16),
		ORANGE,
		Enum.Material.Metal
	)
	piece(
		model,
		c,
		CFrame.new(2.4, b + 12.6, -19.2) * CFrame.Angles(math.rad(-58), 0, 0),
		Vector3.new(1.8, 1.8, 12),
		ORANGE,
		Enum.Material.Metal
	)
	piece(
		model,
		c,
		CFrame.new(2.4, b + 10.4, -6.6) * CFrame.Angles(math.rad(45), 0, 0),
		Vector3.new(0.6, 0.6, 8),
		STEEL,
		Enum.Material.Metal
	)
	piece(model, c, CFrame.new(2.4, b + 4.4, -23), Vector3.new(5.6, 3.6, 3.6), DARK, Enum.Material.Metal)
	for i = -2, 2 do
		piece(
			model,
			c,
			CFrame.new(2.4 + i * 1.1, b + 2.2, -24.4),
			Vector3.new(0.6, 0.8, 0.9),
			STEEL,
			Enum.Material.Metal,
			"Wedge"
		)
	end
	return CFrame.new(-3, b + 6.6, -5.4)
end

function BODY.Skipper(model, c: BasePart)
	local b = -1.2
	piece(model, c, CFrame.new(0, b + 2, 0), Vector3.new(7.6, 0.8, 12.6), WHITE, Enum.Material.Metal)
	piece(model, c, CFrame.new(0, b + 2.6, -5.6), Vector3.new(7.6, 1.2, 1.6), ORANGE, Enum.Material.Metal)
	-- The roll cage.
	for _, x in { -3.4, 3.4 } do
		for _, z in { -2.6, 3.6 } do
			piece(model, c, CFrame.new(x, b + 4.8, z), Vector3.new(0.4, 4.8, 0.4), STEEL, Enum.Material.Metal)
		end
		piece(model, c, CFrame.new(x, b + 7.2, 0.5), Vector3.new(0.4, 0.4, 6.6), STEEL, Enum.Material.Metal)
	end
	for _, z in { -2.6, 3.6 } do
		piece(model, c, CFrame.new(0, b + 7.2, z), Vector3.new(7.2, 0.4, 0.4), STEEL, Enum.Material.Metal)
	end
	local bar = piece(model, c, CFrame.new(0, b + 7.5, -2.6), Vector3.new(5, 0.5, 0.5), ORANGE, Enum.Material.Neon)
	bar.Name = "LightBar"
	-- Seats, a spare tyre, an antenna with a flag.
	for _, x in { -1.6, 1.6 } do
		piece(model, c, CFrame.new(x, b + 3, 1), Vector3.new(2.4, 1, 2.4), DARK, Enum.Material.Fabric)
		piece(model, c, CFrame.new(x, b + 4.4, 2.2), Vector3.new(2.4, 2.6, 0.5), DARK, Enum.Material.Fabric)
	end
	piece(model, c, CFrame.new(0, b + 3.4, 5.6), Vector3.new(1, 3.4, 3.4), RUBBER, Enum.Material.Rubber, "Cylinder")
	piece(model, c, CFrame.new(-3.4, b + 10, 4), Vector3.new(0.15, 5.6, 0.15), STEEL, Enum.Material.Metal)
	piece(model, c, CFrame.new(-2.6, b + 12.1, 4), Vector3.new(1.6, 1, 0.1), ORANGE, Enum.Material.SmoothPlastic)
	for _, x in { -2.4, 2.4 } do
		lamp(model, c, CFrame.new(x, b + 2.6, -6.45))
	end
	for _, z in { -4.4, 4.4 } do
		for side = -1, 1, 2 do
			wheel(model, c, side * 4.6, b + 2.1, z, 2.1, 1.8)
		end
	end
	return CFrame.new(-1.6, b + 3, 1)
end

function OutpostMachines.build(kind: string, at: CFrame): Model
	local size = CHASSIS[kind]
	assert(size and BODY[kind], "No machine called " .. tostring(kind))
	local model = Instance.new("Model")
	model.Name = kind

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = size
	chassis.Transparency = 1
	chassis.CanCollide, chassis.CanTouch, chassis.CanQuery = true, false, true
	-- Slippery underneath (it slides; the constraints do the driving), and heavy.
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0, 100, 1)
	chassis.CFrame = at * CFrame.new(0, size.Y / 2 + 0.2, 0)
	chassis.Parent = model
	model.PrimaryPart = chassis

	local seatAt = BODY[kind](model, chassis)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	-- Not by touch (walking past shouldn't seat you): the Drive prompt seats you.
	seat.CanTouch = false
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0
	seat.HeadsUpDisplay = false
	seat.Massless = true
	seat.CFrame = chassis.CFrame * seatAt
	seat:SetAttribute("OutpostMachine", kind)
	seat.Parent = model
	weld(chassis, seat)

	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	drive.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	drive.PlaneVelocity = Vector2.zero
	drive.MaxForce = 6e5
	drive.Parent = chassis
	local steer = Instance.new("AlignOrientation")
	steer.Name = "Steer"
	steer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	steer.Attachment0 = attachment
	local _, yaw = at:ToOrientation()
	steer.CFrame = CFrame.Angles(0, yaw, 0)
	steer.MaxTorque = 1e8
	steer.Responsiveness = 30
	steer.Parent = chassis

	if kind == "Mole" then
		drill(model, chassis)
	end
	return model
end

return OutpostMachines
