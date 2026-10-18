-- Piloted quarry exosuits. Historical machine IDs keep parking and controls
-- compatible; every body is now a cockpit, articulated arms and walking legs.
-- One invisible chassis is the root (OutpostVehicles anchors it and moves the
-- mech); an invisible hull and foot are what it bumps into. Cosmetic limbs use Motor6Ds, with
-- distance-driven animation on each client (MechAnimation / Shared.MechMotion).
local OutpostMachines = {}
local DARK = Color3.fromRGB(32, 39, 42)
local STEEL = Color3.fromRGB(137, 151, 153)
local RUBBER = Color3.fromRGB(20, 25, 27)
local GLASS = Color3.fromRGB(78, 164, 185)
local PALE = Color3.fromRGB(204, 219, 214)
local HAZARD = Color3.fromRGB(242, 182, 65)
local KITS = {
	Hauler = { Scale = 1, Armor = Color3.fromRGB(103, 119, 82), Accent = HAZARD, Tool = "Fist" },
	Mole = { Scale = 1, Armor = Color3.fromRGB(70, 96, 111), Accent = Color3.fromRGB(91, 218, 238), Tool = "Drill" },
	Digger = { Scale = 0.95, Armor = Color3.fromRGB(167, 107, 64), Accent = HAZARD, Tool = "Claw" },
	Skipper = {
		Scale = 0.86,
		Armor = Color3.fromRGB(161, 176, 163),
		Accent = Color3.fromRGB(103, 232, 195),
		Tool = "Scanner",
	},
}

function OutpostMachines.build(kind: string, at: CFrame): Model
	local kit = KITS[kind]
	assert(kit, "No mech called " .. tostring(kind))
	local scale, armor, accent = kit.Scale, kit.Armor, kit.Accent
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("Mech", true)
	model:SetAttribute("MechScale", scale)
	model:SetAttribute("CameraFit", 25 * scale)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local function frame(x, y, z, rx, ry, rz)
		return CFrame.new(x * scale, y * scale, z * scale)
			* CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	end
	local function raw(name, cf, size, color, material, shape)
		local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
		p.Name, p.CFrame, p.Size = name, cf, size * scale
		p.Color, p.Material = color, material or Enum.Material.Metal
		p.Anchored, p.Massless = false, true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = model
		return p
	end
	local function weld(base, p)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1, w.Parent = base, p, p
	end
	local function piece(base, name, offset, size, color, material, shape)
		local p = raw(name, base.CFrame * offset, size, color, material, shape)
		weld(base, p)
		return p
	end
	local function joint(base, name, pivot, rest)
		rest = rest or CFrame.identity
		local p = raw(name .. "Link", base.CFrame * pivot * rest, Vector3.one * 0.35, DARK)
		p.Transparency = 1
		local motor = Instance.new("Motor6D")
		motor.Name, motor.Part0, motor.Part1 = name, base, p
		motor.C0, motor.C1 = pivot * rest, CFrame.identity
		motor:SetAttribute("MechRest", rest)
		motor.Parent = p
		return p
	end
	local function bar(base, name, a, b, width, color)
		local av, bv = Vector3.new(unpack(a)), Vector3.new(unpack(b))
		local mid = (av + bv) / 2
		return piece(
			base,
			name,
			CFrame.lookAt(mid * scale, bv * scale),
			Vector3.new(width, width, (bv - av).Magnitude),
			color
		)
	end
	local chassis = raw("Chassis", at * CFrame.new(0, 6 * scale + 0.2, 0), Vector3.new(7.6, 12, 6.2), DARK)
	chassis.Transparency, chassis.Massless, chassis.CanQuery = 1, false, true
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0, 100, 1)
	chassis.RootPriority = 127
	model.PrimaryPart = chassis
	-- What it bumps into. The chassis doesn't collide: a box from LIFT studs
	-- up does, the hull, which the server sweeps ahead as it moves the mech
	-- (so a kerb under it doesn't stop it, and it steps up instead), and a
	-- ball under it, so nobody walks through its legs.
	local LIFT, FOOT = 1.6, 6.2
	local hull = raw("Hull", chassis.CFrame * frame(0, LIFT / 2, 0), Vector3.new(7.6, 12 - LIFT, 6.2), DARK)
	local foot = raw("Foot", chassis.CFrame * frame(0, -6 + FOOT / 2, 0), Vector3.one * FOOT, DARK, nil, "Ball")
	for _, collider in { hull, foot } do
		-- (Queryable too: the server's sweep finds other mechs by them.)
		collider.Transparency, collider.CanCollide, collider.CanQuery = 1, true, true
		collider.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0, 100, 1)
		weld(chassis, collider)
	end
	-- Local offsets below are measured from the chassis centre.
	local torso = joint(chassis, "Waist", frame(0, 2, 0))
	piece(torso, "Pelvis", frame(0, 0, 0), Vector3.new(5.4, 1.3, 3.2), DARK)
	piece(torso, "BeltPlate", frame(0, 0.1, -1.75, -10), Vector3.new(4.2, 1.2, 0.6), armor)
	piece(torso, "CockpitRear", frame(0, 4.2, 1.65), Vector3.new(5.2, 7.2, 1.1), armor)
	piece(torso, "CockpitDeck", frame(0, 1.65, -0.25), Vector3.new(5.5, 0.6, 5.7), DARK)
	piece(torso, "CockpitRoof", frame(0, 8.2, -0.25, 5), Vector3.new(5.9, 0.65, 5.1), armor)
	piece(torso, "RoofBrow", frame(0, 7.8, -2.7, -12), Vector3.new(5.9, 0.7, 1), armor)
	-- An open interior behind clear glass, with a protective roll cage.
	local glass =
		piece(torso, "CockpitGlass", frame(0, 5, -2.65, -7), Vector3.new(4.6, 5.1, 0.16), GLASS, Enum.Material.Glass)
	glass.Transparency, glass.CastShadow = 0.65, false
	for _, side in { -1, 1 } do
		local pane = piece(
			torso,
			"SideGlass",
			frame(side * 2.5, 5, -0.25),
			Vector3.new(0.15, 5.2, 4.4),
			GLASS,
			Enum.Material.Glass
		)
		pane.Transparency, pane.CastShadow = 0.72, false
		bar(torso, "CockpitPillar", { side * 2.6, 2.2, -3 }, { side * 2.6, 7.8, -2.35 }, 0.3, STEEL)
		bar(torso, "RearCage", { side * 2.7, 1.9, 1.9 }, { side * 2.7, 8, 1.9 }, 0.4, DARK)
		piece(
			torso,
			"CockpitCheek",
			frame(side * 2.45, 2.1, -2.5, 12, 0, side * -8),
			Vector3.new(1.3, 1.6, 1.5),
			armor,
			nil,
			"Wedge"
		)
		piece(
			torso,
			"WorkLamp",
			frame(side * 2.45, 7.8, -3.22),
			Vector3.new(0.65, 0.35, 0.16),
			PALE,
			Enum.Material.Neon
		)
		-- Backpack power cells, cooling fins and shoulder braces.
		piece(
			torso,
			"PowerCell",
			frame(side * 1.65, 4.6, 2.8, 0, 0, 90),
			Vector3.new(4.4, 1.25, 1.25),
			DARK,
			nil,
			"Cylinder"
		)
		for y = 3.2, 6, 0.7 do
			piece(torso, "CoolingFin", frame(side * 1.65, y, 3.55), Vector3.new(1.65, 0.18, 0.55), STEEL)
		end
		piece(
			torso,
			"PowerStatus",
			frame(side * 1.65, 6.9, 2.8),
			Vector3.new(0.8, 0.22, 0.4),
			accent,
			Enum.Material.Neon
		)
		bar(torso, "ShoulderBrace", { side * 2.8, 4.8, 1 }, { side * 4.55, 5.6, 0 }, 0.65, STEEL)
	end
	piece(torso, "Console", frame(0, 3, -1.75, 25), Vector3.new(3.5, 0.6, 1.5), DARK)
	piece(torso, "InstrumentScreen", frame(0, 3.34, -1.8, 25), Vector3.new(1.6, 0.07, 0.65), accent, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		piece(torso, "ControlStick", frame(side * 1.3, 3.6, -1.45, -15), Vector3.new(0.18, 0.8, 0.18), STEEL)
	end
	piece(torso, "SeatBack", frame(0, 3.8, 1), Vector3.new(2.4, 3.2, 0.5), RUBBER, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder = joint(torso, prefix .. "Shoulder", frame(side * 4.5, 5.4, 0), CFrame.Angles(0, 0, side * 0.08))
		piece(shoulder, "ShoulderSocket", frame(-side * 0.65, 0, 0), Vector3.new(1.1, 2, 2), STEEL, nil, "Cylinder")
		piece(
			shoulder,
			"ShoulderArmor",
			frame(side * 0.3, 0.3, 0, 0, 0, side * -10),
			Vector3.new(3.5, 2.5, 3.7),
			armor,
			nil,
			"Wedge"
		)
		piece(shoulder, "ShoulderInset", frame(side * 0.35, 0.1, -1.92), Vector3.new(2.5, 0.65, 0.13), DARK)
		for i = -1, 1 do
			piece(
				shoulder,
				"HazardStripe",
				frame(side * 0.35 + i * 0.62, 0.1, -2, 0, 0, -25),
				Vector3.new(0.25, 0.55, 0.1),
				accent
			)
		end
		piece(shoulder, "UpperArm", frame(0, -1.5, 0), Vector3.new(1.5, 3, 1.6), DARK)
		piece(shoulder, "BicepArmor", frame(side * 0.3, -1.45, -0.25, 0, 0, side * 5), Vector3.new(2, 2, 1.9), armor)
		bar(shoulder, "ArmPiston", { side * 0.85, -0.3, 0.4 }, { side * 0.85, -2.85, 0.4 }, 0.25, STEEL)
		local forearm = joint(shoulder, prefix .. "Elbow", frame(0, -3, 0), CFrame.Angles(-0.18, 0, 0))
		piece(forearm, "ElbowHub", frame(0, 0, 0), Vector3.new(2.3, 1.3, 1.3), STEEL, nil, "Cylinder")
		piece(forearm, "Forearm", frame(0, -1.25, 0), Vector3.new(1.8, 2.5, 2.1), DARK)
		piece(forearm, "Bracer", frame(0, -1.2, -0.95, -8), Vector3.new(2.5, 2.1, 0.8), armor, nil, "Wedge")
		piece(forearm, "WristBand", frame(0, -2.45, 0), Vector3.new(2.2, 0.4, 2.3), STEEL)
		-- The right tool defines each silhouette; left hand is a manipulator.
		if side == 1 and kit.Tool == "Drill" then
			local rotor = joint(forearm, "ToolRotor", frame(0, -3, 0), CFrame.identity)
			for i = 0, 4 do
				local radius = 1.15 - i * 0.19
				piece(
					rotor,
					"DrillRing",
					frame(0, -i * 0.55, 0, 0, 0, 90),
					Vector3.new(0.6, radius * 2, radius * 2),
					if i % 2 == 0 then STEEL else DARK,
					nil,
					"Cylinder"
				)
				for tooth = 0, 2 do
					local angle = tooth * math.pi * 2 / 3 + i * 0.8
					piece(
						rotor,
						"DrillTooth",
						frame(math.cos(angle) * radius, -i * 0.55, math.sin(angle) * radius, 0, -math.deg(angle), 20),
						Vector3.new(0.35, 0.5, 0.5),
						accent,
						nil,
						"Wedge"
					)
				end
			end
		elseif side == 1 and kit.Tool == "Claw" then
			piece(forearm, "ToolMount", frame(0, -3, 0), Vector3.new(2.7, 0.8, 2.5), DARK)
			for _, finger in { -1, 1 } do
				piece(
					forearm,
					"GrabberJaw",
					frame(finger * 1.25, -4, -0.2, 0, 0, finger * -20),
					Vector3.new(0.65, 2.2, 2),
					armor,
					nil,
					"Wedge"
				)
				piece(forearm, "GrabberTip", frame(finger * 0.8, -5, -0.55), Vector3.new(0.9, 0.4, 1.5), STEEL)
			end
		else
			piece(forearm, "Palm", frame(0, -3, 0), Vector3.new(2.2, 1, 1.7), DARK)
			for finger = -1, 1 do
				piece(forearm, "Finger", frame(finger * 0.68, -3.75, -0.15, -10), Vector3.new(0.52, 1.1, 0.9), STEEL)
				piece(forearm, "Knuckle", frame(finger * 0.68, -3.25, -0.8), Vector3.new(0.55, 0.4, 0.35), armor)
			end
			piece(
				forearm,
				"Thumb",
				frame(-side * 1.2, -3.25, -0.5, 0, 0, side * 25),
				Vector3.new(0.55, 1.3, 0.8),
				STEEL
			)
			if side == 1 and kit.Tool == "Scanner" then
				piece(forearm, "Scanner", frame(0, -1.1, -1.55), Vector3.new(1.7, 1.2, 0.65), DARK)
				piece(
					forearm,
					"ScannerLens",
					frame(0, -1.1, -1.93, 0, 90),
					Vector3.new(0.15, 0.8, 0.8),
					accent,
					Enum.Material.Neon,
					"Cylinder"
				)
			elseif side == 1 then
				piece(forearm, "CargoGauntlet", frame(0, -3, -0.65), Vector3.new(2.9, 1.5, 1.3), armor)
			end
		end

		local bend = math.acos(6.8 / 7.2)
		local thigh = joint(chassis, prefix .. "Hip", frame(side * 2.05, 1.45, 0), CFrame.Angles(bend, 0, 0))
		piece(thigh, "HipHub", frame(0, 0, 0), Vector3.new(2.5, 1.4, 1.4), STEEL, nil, "Cylinder")
		piece(thigh, "ThighFrame", frame(0, -1.8, 0), Vector3.new(1.6, 3.6, 1.7), DARK)
		piece(thigh, "ThighArmor", frame(0, -1.6, -0.7, -8), Vector3.new(2.3, 2.6, 1.4), armor, nil, "Wedge")
		bar(thigh, "LegPiston", { side * 0.95, -0.25, 0.5 }, { side * 0.95, -3.25, 0.5 }, 0.3, STEEL)
		local shin = joint(thigh, prefix .. "Knee", frame(0, -3.6, 0), CFrame.Angles(-2 * bend, 0, 0))
		piece(shin, "KneeHub", frame(0, 0, 0), Vector3.new(2.4, 1.3, 1.3), STEEL, nil, "Cylinder")
		piece(shin, "KneeCap", frame(0, -0.05, -0.85, -12), Vector3.new(2.4, 1.35, 0.8), armor, nil, "Wedge")
		piece(shin, "ShinFrame", frame(0, -1.8, 0), Vector3.new(1.5, 3.6, 1.6), DARK)
		piece(shin, "ShinArmor", frame(0, -1.7, -0.7, 7), Vector3.new(2.25, 2.65, 1.05), armor, nil, "Wedge")
		for rib = 0, 2 do
			piece(shin, "ShinRib", frame(0, -1.1 - rib * 0.65, -1.3, 7), Vector3.new(1.8, 0.15, 0.18), STEEL)
		end
		local foot = joint(shin, prefix .. "Ankle", frame(0, -3.6, 0), CFrame.Angles(bend, 0, 0))
		piece(foot, "Ankle", frame(0, 0, 0), Vector3.new(1.8, 0.7, 1.6), STEEL, nil, "Cylinder")
		piece(foot, "BootSole", frame(0, -0.35, -0.65), Vector3.new(2.7, 0.7, 4.3), RUBBER)
		piece(foot, "ToeArmor", frame(0, 0.1, -1.55, 0, 180), Vector3.new(2.65, 0.9, 2.4), armor, nil, "Wedge")
		piece(foot, "Heel", frame(0, 0.15, 1), Vector3.new(2.3, 0.9, 1.2), armor)
		for tread = 0, 3 do
			piece(foot, "SoleTread", frame(0, -0.65, -2.1 + tread * 0.95), Vector3.new(2.85, 0.18, 0.35), STEEL)
		end
	end
	-- Asymmetric antennas and a sensor pod keep the silhouette industrial.
	piece(torso, "SensorPod", frame(-1.7, 8.8, 0.4), Vector3.new(1.3, 0.9, 1.8), DARK)
	piece(torso, "SensorEye", frame(-1.7, 8.8, -0.55), Vector3.new(0.8, 0.3, 0.15), accent, Enum.Material.Neon)
	piece(torso, "Antenna", frame(2.25, 9.5, 1.5, 0, 0, -8), Vector3.new(0.12, 3, 0.12), STEEL)
	local seat = Instance.new("VehicleSeat")
	seat.Name, seat.Size, seat.Transparency = "Seat", Vector3.new(2, 1, 2), 1
	seat.CanCollide, seat.CanTouch, seat.CanQuery, seat.Massless = false, false, false, true
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed, seat.HeadsUpDisplay = 0, 0, 0, false
	seat.CFrame = torso.CFrame * frame(0, 3.1, 0)
	seat:SetAttribute("OutpostMachine", kind)
	seat.Parent = model
	weld(torso, seat)
	-- (No drive constraints: the server anchors the chassis and moves the
	-- whole mech itself, Server OutpostVehicles.)
	return model
end

return OutpostMachines
