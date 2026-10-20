--[[
	The quarry's life: what moves out in the Moon Quarry round the Shelter,
	drawn by each player's own client (the server sends nothing). Everything
	is timed by the server's clock, so everyone sees the same.

	  road lights   lights set in the edges of the six haul roads, a pulse
	                running out along each, every light in its frontier
	                band's colour (Shared.Frontier: cyan in the core, gold
	                in the Fringe, rose out at the Edge), so the way out and
	                how rich the ground is read from afar
	  meteors       a shower streaking over the crater every Shower seconds
	  the lifter    a cargo lifter carrying a container from the landing pad
	                to the north outpost and back, nav lights blinking
	  dust devils   three swirls of dust wandering the basin
	  vents         vapour bursting out of cracks in four craters, in turn
	  ore           crystal ore riding the conveyor from the drill rig
	  spires        clusters of glowing crystal on the crater's top bench,
	                rose and violet like the Edge's richest rocks, so the
	                rim catches the eye from the Shelter

	None of it collides, casts a shadow or can be clicked (CanQuery: a click
	in the Outpost swings at a rock). It is only there while you're in the
	Outpost, and the road lights only change near you.

	  QuarryLife.mount(at)   builds it for the quarry round `at` (once)
	  QuarryLife.show(on)    shows or hides it (hidden, nothing runs)
	  QuarryLife.step(dt)    animates it (20 updates a second at most)

	Pure, and tested without Roblox (tests/quarry_life_cases.luau), all in
	the quarry's frame (the Shelter's middle, OutpostWorld's `at`):
	  QuarryLife.lights() -> { { Position, Band, Road, Out } }   every road light
	  QuarryLife.glow(out, t) -> number   how lit a light `out` studs out is (0-1)
	  QuarryLife.lifterAt(t) -> (CFrame, string)   the lifter, and what it's doing
	  QuarryLife.meteorAt(k, t) -> (CFrame?, number)   meteor k of the shower
	                                      (its head, -Z the way it flies; nil
	                                      while it isn't in the sky) and how
	                                      far through its streak it is
	  QuarryLife.devilAt(k, t) -> Vector3   dust devil k, on the ground
	  QuarryLife.venting(k, t) -> boolean   whether vent k is bursting
	  QuarryLife.build(at) -> Life        every part, at rest
	  QuarryLife.pose(life, t)            poses it at server time t
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Frontier = require(Shared:WaitForChild("Frontier"))

local QuarryLife = {}

local V = Vector3.new
local HULL = Color3.fromRGB(196, 202, 214)
local DARK = Color3.fromRGB(44, 48, 58)
local HAZARD = Color3.fromRGB(255, 196, 40)
local WHITE = Color3.new(1, 1, 1)

-- Where things are, in the quarry's frame (Server OutpostWorld.build).
-- (The haul roads are the four spokes, Frontier.Spokes: north, east, south, west.)
QuarryLife.Roads = { From = 116, To = 404, Step = 24, Side = 8.4, Ring = 260 }
QuarryLife.Ramps = { { 1, 345 }, { 2, 215 }, { 3, 330 }, { 4, 200 } } -- (spoke, studs out)
QuarryLife.Pad = V(72, 1.15, 118) -- the landing pad's top
QuarryLife.Drop = V(56, 18, -90) -- where the lifter hovers at the north outpost
QuarryLife.Cruise = 62 -- the lifter's height between (well over the Shelter's skylight)
QuarryLife.Trip = 100 -- seconds, there and back with its rests
QuarryLife.Hang = 6.55 -- from the bottom of the container it carries up to its middle
QuarryLife.Shower = 45 -- seconds between meteor showers
QuarryLife.Meteors = 5 -- in each
QuarryLife.Vents = { V(200, 0, -260), V(-330, 0, 80), V(170, 0, 220), V(-150, 0, 330) } -- in craters, clear of the rocks
QuarryLife.VentEvery = 26
QuarryLife.Conveyor = { V(64, 4.9, -124), V(46, 4.9, -112) } -- the rig's conveyor, along its top
QuarryLife.Devils = 3
QuarryLife.Spires = { Count = 12, Out = 467, Top = 15 } -- clusters round the top bench (OutpostWorld.benches)

-- A road's way out (radians round the middle: 0 east, a quarter turn south).
local function roadAngle(road: number): number
	return Frontier.Spokes[road]
end

local function bandOf(out: number): string
	if out < Frontier.Core then
		return "Core"
	elseif out < Frontier.EdgeFrom then
		return "Fringe"
	end
	return "Edge"
end

-- Every road light: both edges of each haul road, Step studs apart, none
-- on the ring road's crossing or a jump ramp.
function QuarryLife.lights(): { { Position: Vector3, Band: string, Road: number, Out: number } }
	local spec = QuarryLife.Roads
	local list = {}
	for road = 1, #Frontier.Spokes do
		local a = roadAngle(road)
		local along, across = V(math.cos(a), 0, math.sin(a)), V(-math.sin(a), 0, math.cos(a))
		for out = spec.From, spec.To, spec.Step do
			local clear = math.abs(out - spec.Ring) > 12
			for _, ramp in QuarryLife.Ramps do
				if ramp[1] == road and math.abs(out - ramp[2]) < 18 then
					clear = false
				end
			end
			if clear then
				for _, side in { -1, 1 } do
					table.insert(list, {
						Position = along * out + across * (side * spec.Side) + V(0, 0.28, 0),
						Band = bandOf(out),
						Road = road,
						Out = out,
					})
				end
			end
		end
	end
	return list
end

-- How lit a road light `out` studs out is at t: a pulse running out along
-- the road (Speed studs a second), a soft glow between.
QuarryLife.PulseSpeed = 70
QuarryLife.PulseEvery = 2.4
function QuarryLife.glow(out: number, t: number): number
	local phase = ((t - out / QuarryLife.PulseSpeed) / QuarryLife.PulseEvery) % 1
	local pulse = math.max(0, 1 - phase / 0.35)
	return 0.25 + 0.75 * pulse
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- The lifter at t: resting on the pad, lifting off, flying north over the
-- Shelter, lowering to hover at the north outpost, and back. Returns its
-- frame (nose -Z) and what it's doing.
function QuarryLife.lifterAt(t: number): (CFrame, string)
	local s = t % QuarryLife.Trip
	-- (On the pad its container stands on the pad, the lifter over it.)
	local pad, drop, cruise = QuarryLife.Pad + V(0, QuarryLife.Hang, 0), QuarryLife.Drop, QuarryLife.Cruise
	local north = (drop - pad) * V(1, 0, 1)
	local heading = math.atan2(-north.X, -north.Z)
	local function at(p: Vector3, yaw: number, bank: number?): CFrame
		return CFrame.new(p) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, bank or 0)
	end
	local function flight(from: Vector3, to: Vector3, u: number): Vector3
		local k = smooth(u)
		local flat = from:Lerp(to, k)
		return V(flat.X, cruise + math.sin(k * math.pi) * 8, flat.Z)
	end
	if s < 10 then
		return at(pad, heading), "Resting"
	elseif s < 16 then
		local k = smooth((s - 10) / 6)
		return at(pad:Lerp(V(pad.X, cruise, pad.Z), k), heading), "Lifting"
	elseif s < 36 then
		local u = (s - 16) / 20
		return at(flight(V(pad.X, cruise, pad.Z), V(drop.X, cruise, drop.Z), u), heading, math.sin(u * math.pi) * 0.08),
			"Flying"
	elseif s < 42 then
		local k = smooth((s - 36) / 6)
		return at(V(drop.X, cruise, drop.Z):Lerp(drop, k), heading), "Lowering"
	elseif s < 52 then
		return at(drop + V(0, math.sin((s - 42) * 1.3) * 0.4, 0), heading), "Hovering"
	elseif s < 58 then
		local k = smooth((s - 52) / 6)
		return at(drop:Lerp(V(drop.X, cruise, drop.Z), k), heading + math.pi * k), "Rising"
	elseif s < 78 then
		local u = (s - 58) / 20
		return at(
			flight(V(drop.X, cruise, drop.Z), V(pad.X, cruise, pad.Z), u),
			heading + math.pi,
			math.sin(u * math.pi) * 0.08
		),
			"Flying"
	elseif s < 84 then
		local k = smooth((s - 78) / 6)
		return at(V(pad.X, cruise, pad.Z):Lerp(pad, k), heading + math.pi + math.pi * k), "Landing"
	end
	return at(pad, heading), "Resting"
end

-- A small hash of whole numbers, 0-1, for the showers.
local function hash(a: number, b: number): number
	local x = math.sin(a * 127.1 + b * 311.7) * 43758.5453
	return x - math.floor(x)
end

-- Meteor k of the shower under way at t: high over the crater, streaking
-- down across the sky. Nil between showers.
QuarryLife.MeteorTime = 2.4 -- seconds each is in the sky
function QuarryLife.meteorAt(k: number, t: number): (CFrame?, number)
	local shower = math.floor(t / QuarryLife.Shower)
	local start = shower * QuarryLife.Shower + 3 + (k - 1) * 0.7 + hash(shower, k) * 0.5
	local u = (t - start) / QuarryLife.MeteorTime
	if u < 0 or u >= 1 then
		return nil, 0
	end
	local heading = hash(shower, 0) * math.pi * 2 + (hash(shower, k + 10) - 0.5) * 0.5
	local dir = V(math.cos(heading), -0.32, math.sin(heading)).Unit
	local across = V(-math.sin(heading), 0, math.cos(heading))
	local from = V(-math.cos(heading) * 520, 420 + hash(shower, k + 20) * 80, -math.sin(heading) * 520)
		+ across * ((hash(shower, k + 30) - 0.5) * 500)
	local head = from + dir * (u * 900)
	local right = dir:Cross(V(0, 1, 0)).Unit
	return CFrame.fromMatrix(head, right, right:Cross(dir), -dir), u
end

-- Dust devil k at t: wandering a loop of its own round the basin, out past
-- the Shelter and the floodlights, never as far as the crater's benches.
function QuarryLife.devilAt(k: number, t: number): Vector3
	local a = k * 2.1 + t * 0.011 + math.sin(t * 0.03 + k) * 0.6
	local r = 250 + math.sin(t * 0.017 + k * 1.7) * 110
	return V(math.cos(a) * r, 0.5, math.sin(a) * r)
end

-- Whether vent k is bursting at t: each for 5 seconds of every VentEvery,
-- in turn.
function QuarryLife.venting(k: number, t: number): boolean
	local s = (t + k * QuarryLife.VentEvery / #QuarryLife.Vents) % QuarryLife.VentEvery
	return s < 5
end

-- A part that's only there to be seen.
local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, shape: string?): BasePart
	local p = Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

export type Group = { Parts: { BasePart }, Rest: { CFrame } }
export type Life = {
	Model: Model,
	At: CFrame,
	Lights: { { Part: BasePart, Out: number, Here: Vector3 } },
	Lifter: Group,
	NavLights: { BasePart },
	Thrust: { BasePart },
	Meteors: { { Head: BasePart, Trail: BasePart } },
	Devils: { BasePart },
	Vents: { { Emitter: ParticleEmitter, Crack: BasePart } },
	Ore: { BasePart },
	Spires: { BasePart },
}

-- A group's parts kept as offsets from `pivot`.
local function group(parts: { BasePart }, pivot: CFrame): Group
	local rest = {}
	for i, p in parts do
		rest[i] = pivot:ToObjectSpace(p.CFrame)
	end
	return { Parts = parts, Rest = rest }
end

-- The cargo lifter, built round its middle (nose -Z): a hull, a canopy,
-- four engine pods glowing underneath, nav lights, and a container slung
-- under it.
local function lifter(parent: Instance): (Group, { BasePart }, { BasePart })
	local made, nav, thrust = {}, {}, {}
	local function add(size, color, material, shape, cf)
		local p = part(parent, size, color, material, shape)
		p.CFrame = cf
		table.insert(made, p)
		return p
	end
	add(V(6, 2.6, 10), HULL, Enum.Material.Metal, nil, CFrame.new(0, 0, 0))
	add(V(5, 1.2, 8), DARK, Enum.Material.Metal, nil, CFrame.new(0, 1.8, 0.6))
	add(V(3.6, 2, 3), Color3.fromRGB(60, 120, 170), Enum.Material.Glass, "Ball", CFrame.new(0, 0.9, -4.6))
	add(V(6.2, 0.3, 0.4), HAZARD, Enum.Material.SmoothPlastic, nil, CFrame.new(0, -0.4, -5))
	for _, x in { -4.6, 4.6 } do
		for _, z in { -3, 3 } do
			add(
				V(1.6, 2.6, 2.6),
				DARK,
				Enum.Material.Metal,
				"Cylinder",
				CFrame.new(x, 0, z) * CFrame.Angles(0, 0, math.rad(90))
			)
			table.insert(
				thrust,
				add(
					V(0.2, 2.2, 2.2),
					Color3.fromRGB(120, 210, 255),
					Enum.Material.Neon,
					"Cylinder",
					CFrame.new(x, -0.85, z) * CFrame.Angles(0, 0, math.rad(90))
				)
			)
		end
		add(V(1.8, 0.4, 7), HULL, Enum.Material.Metal, nil, CFrame.new(x * 0.82, 0.2, 0))
	end
	table.insert(
		nav,
		add(V(0.6, 0.6, 0.6), Color3.fromRGB(255, 60, 60), Enum.Material.Neon, "Ball", CFrame.new(-5.6, 0.4, 0))
	)
	table.insert(
		nav,
		add(V(0.6, 0.6, 0.6), Color3.fromRGB(60, 255, 120), Enum.Material.Neon, "Ball", CFrame.new(5.6, 0.4, 0))
	)
	table.insert(nav, add(V(0.5, 0.5, 0.5), WHITE, Enum.Material.Neon, "Ball", CFrame.new(0, 2.5, 4.5)))
	-- The container, hung on two cables.
	for _, z in { -2, 2 } do
		add(V(0.12, 2.2, 0.12), DARK, Enum.Material.Metal, nil, CFrame.new(0, -2.4, z))
	end
	add(V(4, 3, 7), Color3.fromRGB(190, 70, 50), Enum.Material.CorrodedMetal, nil, CFrame.new(0, -5, 0))
	add(V(4.1, 0.3, 7.1), HAZARD, Enum.Material.SmoothPlastic, nil, CFrame.new(0, -3.4, 0))
	return group(made, CFrame.new()), nav, thrust
end

function QuarryLife.build(at: CFrame): Life
	local model = Instance.new("Model")
	model.Name = "QuarryLife"
	-- The road lights, set in the road's edges.
	local lights = {}
	local roadLights = Instance.new("Folder")
	roadLights.Name = "RoadLights"
	roadLights.Parent = model
	for _, spec in QuarryLife.lights() do
		local p = part(roadLights, V(0.9, 0.24, 0.9), Frontier.Bands[spec.Band].Color, Enum.Material.Neon)
		p.CFrame = at * CFrame.new(spec.Position)
		table.insert(lights, { Part = p, Out = spec.Out, Here = spec.Position })
	end
	-- The meteors: a white-hot head and a long trail behind it.
	local meteors = {}
	for _ = 1, QuarryLife.Meteors do
		local head = part(model, V(3.2, 3.2, 3.2), Color3.fromRGB(255, 238, 200), Enum.Material.Neon, "Ball")
		local trail = part(model, V(70, 1.4, 1.4), Color3.fromRGB(255, 170, 110), Enum.Material.Neon, "Cylinder")
		trail.Transparency = 0.35
		table.insert(meteors, { Head = head, Trail = trail })
	end
	-- The lifter.
	local carrier, nav, thrust = lifter(model)
	-- The dust devils: dust lifting off an unseen point, wandering.
	local devils = {}
	for _ = 1, QuarryLife.Devils do
		local core = part(model, V(1, 1, 1), WHITE)
		core.Transparency = 1
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromRGB(176, 168, 156))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
		dust.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(3, 4.5)
		dust.Rate = 16
		dust.Speed = NumberRange.new(4, 8)
		dust.SpreadAngle = Vector2.new(18, 18)
		dust.Acceleration = V(0, 2.5, 0)
		dust.RotSpeed = NumberRange.new(120, 220)
		dust.Rotation = NumberRange.new(0, 360)
		dust.LightInfluence = 1
		dust.Parent = core
		table.insert(devils, core)
	end
	-- The vents: a glowing crack in the crater's floor, vapour bursting out.
	local vents = {}
	for _, spot in QuarryLife.Vents do
		local crack = part(model, V(0.2, 5, 1.2), Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
		crack.CFrame = at * CFrame.new(spot + V(0, 0.32, 0)) * CFrame.Angles(0, 0.6, math.rad(90))
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Color = ColorSequence.new(Color3.fromRGB(226, 236, 248))
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 10) })
		steam.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		steam.Lifetime = NumberRange.new(2.5, 4)
		steam.Rate = 40
		steam.Speed = NumberRange.new(16, 26)
		steam.SpreadAngle = Vector2.new(9, 9)
		steam.Acceleration = V(0, -3, 0)
		steam.EmissionDirection = Enum.NormalId.Right -- (up: the crack lies on its side)
		steam.Enabled = false
		steam.Parent = crack
		table.insert(vents, { Emitter = steam, Crack = crack })
	end
	-- Ore riding the conveyor.
	local ore = {}
	for k = 1, 6 do
		local chunk = part(
			model,
			V(0.9, 0.9, 0.9),
			if k % 2 == 0 then Color3.fromRGB(110, 220, 255) else Color3.fromRGB(150, 140, 130),
			if k % 2 == 0 then Enum.Material.Neon else Enum.Material.Slate
		)
		table.insert(ore, chunk)
	end
	-- The crystal spires on the top bench: three shards a cluster, leaning
	-- out of the rock, each with a sharper tip, between the bench's ramps.
	local spires = {}
	local spec = QuarryLife.Spires
	local tints = { Frontier.Bands.Edge.Color, Frontier.Bands.Vein.Color }
	for c = 0, spec.Count - 1 do
		local a = (c + 0.5) / spec.Count * math.pi * 2
		local foot = V(math.cos(a) * spec.Out, spec.Top, math.sin(a) * spec.Out)
		for k = 1, 3 do
			local tall = 13 + ((c * 3 + k * 5) % 7) * 2
			local wide = 2.4 + (k % 2) * 1.1
			local lean = CFrame.Angles(math.rad(-12 + k * 9), a + k * 1.9, math.rad(-10 + ((c + k) % 3) * 9))
			local base = CFrame.new(foot + V(math.cos(a + k * 2.1) * 2.6, 0, math.sin(a + k * 2.1) * 2.6)) * lean
			local tint = tints[(c + k) % 2 + 1]
			local shard = part(model, V(wide, tall, wide), tint, Enum.Material.Glass)
			shard.Transparency = 0.15
			shard.CFrame = at * base * CFrame.new(0, tall / 2 - 0.8, 0) * CFrame.Angles(0, math.rad(45), 0)
			local tip = part(model, V(wide * 0.62, tall * 0.34, wide * 0.62), tint, Enum.Material.Neon)
			tip.CFrame = at * base * CFrame.new(0, tall - 0.3, 0) * CFrame.Angles(0, math.rad(45), 0)
			table.insert(spires, shard)
			table.insert(spires, tip)
		end
	end
	local life = {
		Model = model,
		At = at,
		Lights = lights,
		Lifter = carrier,
		NavLights = nav,
		Thrust = thrust,
		Meteors = meteors,
		Devils = devils,
		Vents = vents,
		Ore = ore,
		Spires = spires,
	}
	QuarryLife.pose(life, 0)
	return life
end

-- Moves every part to its place in the game in one bulk move.
local bulkMove = (function()
	local ok, space = pcall(function()
		return game:GetService("Workspace")
	end)
	if ok and space and (space :: any).BulkMoveTo then
		return function(parts, cframes)
			space:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	return function(parts, cframes)
		for i, p in parts do
			p.CFrame = cframes[i]
		end
	end
end)()

-- Poses everything at server time t; `near` (in the quarry's frame), if
-- given, limits the road lights changed to those within Near of it.
QuarryLife.Near = 360
function QuarryLife.pose(life: Life, t: number, near: Vector3?)
	local at = life.At
	local parts, cframes = {}, {}
	local function put(p: BasePart, cf: CFrame)
		table.insert(parts, p)
		table.insert(cframes, cf)
	end
	-- The road lights.
	for _, light in life.Lights do
		if not near or (light.Here - near).Magnitude < QuarryLife.Near then
			local lit = QuarryLife.glow(light.Out, t)
			local want = math.floor((1 - lit) * 10 + 0.5) / 10 * 0.8
			if light.Part.Transparency ~= want then
				light.Part.Transparency = want
			end
		end
	end
	-- The meteors (out of the sky between showers).
	for k, m in life.Meteors do
		local head, u = QuarryLife.meteorAt(k, t)
		if head then
			put(m.Head, at * head)
			put(m.Trail, at * head * CFrame.new(0, 0, m.Trail.Size.X / 2) * CFrame.Angles(0, math.rad(90), 0))
			local fade = if u < 0.12 then 1 - u / 0.12 elseif u > 0.8 then (u - 0.8) / 0.2 else 0
			m.Head.Transparency = fade
			m.Trail.Transparency = 0.35 + 0.65 * fade
		else
			m.Head.Transparency, m.Trail.Transparency = 1, 1
		end
	end
	-- The lifter, its nav lights blinking and its engines bright while it
	-- flies.
	local frame, doing = QuarryLife.lifterAt(t)
	for i, p in life.Lifter.Parts do
		put(p, at * frame * life.Lifter.Rest[i])
	end
	for i, p in life.NavLights do
		p.Transparency = if (t * 1.4 + i * 0.33) % 1 < 0.18 then 0 else 0.8
	end
	local burning = doing ~= "Resting"
	for _, p in life.Thrust do
		p.Transparency = if burning then 0 else 0.7
	end
	-- The dust devils, and the vents.
	for k, core in life.Devils do
		put(core, at * CFrame.new(QuarryLife.devilAt(k, t)))
	end
	for k, vent in life.Vents do
		local on = QuarryLife.venting(k, t)
		if vent.Emitter.Enabled ~= on then
			vent.Emitter.Enabled = on
		end
	end
	-- The ore on the conveyor.
	local a, b = QuarryLife.Conveyor[1], QuarryLife.Conveyor[2]
	for k, chunk in life.Ore do
		local u = (t * 0.12 + k / #life.Ore) % 1
		put(chunk, at * CFrame.new(a:Lerp(b, u)) * CFrame.Angles(k, k * 2, 0))
	end
	bulkMove(parts, cframes)
end

-- In the game: built once, shown while you're in the Outpost.
local life: Life? = nil
local wanted = false
local clock = 0
function QuarryLife.mount(at: CFrame)
	if life then
		return
	end
	life = QuarryLife.build(at)
end

function QuarryLife.show(on: boolean)
	wanted = on
	if not life then
		return
	end
	local parent = if on then workspace else nil
	if life.Model.Parent ~= parent then
		life.Model.Parent = parent
	end
end

function QuarryLife.step(dt: number)
	if not (life and wanted) then
		return
	end
	clock += dt
	if clock < 1 / 20 then
		return
	end
	clock = 0
	local camera = workspace.CurrentCamera
	local near = if camera then life.At:PointToObjectSpace(camera.CFrame.Position) else nil
	QuarryLife.pose(life, workspace:GetServerTimeNow(), near)
end

return QuarryLife
