--[[
	The Shelter's life: what moves in the lobby, drawn by each player's own
	client (the server sends nothing). Everything is timed by the server's
	clock, so everyone sees the same kaiju on the stage and the same drones
	overhead.

	  the hologram  a kaiju in light over the kaiju arena's stage, turning
	                slowly. Every Hold seconds it flickers out and the next
	                species and element flickers in, a scan of light
	                sweeping up through it; its name hangs over it. The
	                projector's console by the stage skips to the next one
	                (for you alone)
	  the gallery   a gem spinning in each of the Gem Gallery's cases
	                (Server OutpostWorld builds the plinths), its rarity and
	                its odds on its plinth (Shared.GemRoller.MiningWeights),
	                sparkles round the Legendary
	  drones        three maintenance drones on slow loops round the hall,
	                their eyes blinking and a spotlight under each
	  the garden    fireflies over the Moon Garden
	  motes         dust drifting down through the skylight

	None of it casts a shadow or can be clicked (CanQuery: a click in the
	Outpost swings at a rock), and only the console collides. It is only there while you're
	in the Outpost and within Reach of the Shelter.

	  ShelterLife.mount(at)   builds it for the Shelter at `at` (once)
	  ShelterLife.show(on)    shows or hides it (hidden, nothing runs)
	  ShelterLife.step(dt)    animates it (30 updates a second at most)

	Pure, and tested without Roblox (tests/shelter_life_cases.luau):
	  ShelterLife.build(at) -> Life      every part, at rest
	  ShelterLife.pose(life, t, stage?)  poses it at server time t (the
	                                     hologram at `stage`, t if not given)
	  ShelterLife.kaijuAt(t) -> (index, flicker)   which of Kaiju the stage
	                                     shows, and how far it has flickered
	                                     in (0 to 1)
	  ShelterLife.droneAt(k, t) -> CFrame   drone k, in the Shelter's frame
	  ShelterLife.odds() -> { { Tier, Label, Color, Percent } }   the gallery's
	                                     cases, Common to Legendary
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuModels = require(Shared:WaitForChild("KaijuModels"))
local GemConfig = require(Shared:WaitForChild("GemConfig"))
local GemRoller = require(Shared:WaitForChild("GemRoller"))
local GemShapes = require(script.Parent:WaitForChild("GemShapes"))

local ShelterLife = {}

-- Where things are, in the Shelter's frame (Server OutpostWorld.shelter).
ShelterLife.Stage = Vector3.new(0, 2.35, 18) -- the top of the kaiju arena's stage
ShelterLife.Gallery = { Middle = Vector3.new(30, 0.86, 4), Radius = 13, From = -50, Step = 25 }
ShelterLife.Garden = Vector3.new(-42, 0.86, 14)
ShelterLife.Console = Vector3.new(-10.5, 0.86, 40.5) -- by the stage's way in, facing the door
ShelterLife.Reach = 320 -- studs from the Shelter's middle: past this it's put away

-- The hologram: every kaiju, species and element both changing each time.
ShelterLife.Kaiju = {}
do
	local species = { "Bulwark", "Razorback", "Carapace" }
	local elements = { "Fire", "Frost", "Shock", "Poison" }
	for i = 0, 11 do
		table.insert(ShelterLife.Kaiju, { Species = species[i % 3 + 1], Element = elements[i % 4 + 1] })
	end
end
ShelterLife.Hold = 12 -- seconds each kaiju shows
ShelterLife.Flicker = 0.7 -- seconds it takes to flicker in
ShelterLife.Scale = 2.2
ShelterLife.Turn = 26 -- seconds a turn

local V, C = Vector3.new, Color3.fromRGB
local WHITE = C(240, 246, 255)
local DARK = C(58, 62, 72)
local STEEL = C(150, 158, 170)

-- Which kaiju the stage shows at t, and how far it has flickered in.
function ShelterLife.kaijuAt(t: number): (number, number)
	local n = #ShelterLife.Kaiju
	local index = math.floor(t / ShelterLife.Hold) % n + 1
	local since = t % ShelterLife.Hold
	return index, math.clamp(since / ShelterLife.Flicker, 0, 1)
end

-- Drone k's place and heading at t, in the Shelter's frame: slow loops
-- under the bunting (y 24 at its lowest) and clear of the walls, the
-- lamps, the tree and the signs: two ellipses round the hall, one inside
-- the other, and a figure of eight inside both.
function ShelterLife.droneAt(k: number, t: number): CFrame
	local function at(time: number): Vector3
		if k == 1 then
			local a = time * math.pi * 2 / 70
			return V(math.cos(a) * 54, 19 + math.sin(time * 1.3) * 0.4, 22 + math.sin(a) * 28)
		elseif k == 2 then
			local a = -time * math.pi * 2 / 55 + 2
			return V(math.cos(a) * 40, 21.5 + math.sin(time * 1.1 + 1) * 0.4, 22 + math.sin(a) * 22)
		end
		-- (A figure of eight over the stage, inside the other two's loops.)
		local a = time * math.pi * 2 / 64 + 4
		return V(math.sin(a) * 30, 20 + math.sin(time * 1.5 + 2) * 0.4, 22 + math.sin(a * 2) * 10)
	end
	local here, ahead = at(t), at(t + 0.5)
	local flat = V(ahead.X - here.X, 0, ahead.Z - here.Z)
	local heading = if flat.Magnitude > 1e-3 then CFrame.lookAt(here, here + flat) else CFrame.new(here)
	-- (Leaning a little into its turns.)
	local behind = at(t - 0.5)
	local turn = (flat.Unit):Cross((V(here.X - behind.X, 0, here.Z - behind.Z)).Unit).Y
	return heading * CFrame.Angles(-0.12, 0, math.clamp(turn * 6, -0.35, 0.35))
end

-- The gallery's five cases: each rarity, its colour and its odds out of
-- every gem mined.
function ShelterLife.odds(): { { Tier: string, Label: string, Color: Color3, Percent: number } }
	local total = 0
	for _, w in GemRoller.MiningWeights do
		total += w
	end
	local out = {}
	for i, tier in GemConfig.TierOrder do
		table.insert(out, {
			Tier = tier,
			Label = GemConfig.TierLabels[tier] or tier,
			Color = GemConfig.TierColors[tier],
			Percent = GemRoller.MiningWeights[i] / total * 100,
		})
	end
	return out
end

local function percentText(p: number): string
	return if p >= 10 or p == math.floor(p)
		then string.format("%d%%", math.floor(p + 0.5))
		else string.format("%.1f%%", p)
end

-- Standing at `from`, turned to face `toward` (level).
local function facing(from: Vector3, toward: Vector3): CFrame
	return CFrame.new(from) * CFrame.Angles(0, math.atan2(-(toward.X - from.X), -(toward.Z - from.Z)), 0)
end

-- A part that's only there to be seen.
local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, shape: string?): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local q = Instance.new("Part")
		if shape == "Ball" then
			q.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			q.Shape = Enum.PartType.Cylinder
		end
		p = q
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

local function label(
	board: BasePart,
	face: Enum.NormalId,
	lines: { { Text: string, Color: Color3, Size: number, Font: Enum.Font } }
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(board.Size.X * 50, board.Size.Y * 50)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = board
	local y, made = 0, {}
	for _, line in lines do
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.04, y)
		text.Size = UDim2.fromScale(0.92, line.Size)
		text.Text = line.Text
		text.TextScaled = true
		text.Font = line.Font
		text.TextColor3 = line.Color
		text.Parent = gui
		table.insert(made, text)
		y += line.Size
	end
	return gui, made
end

export type Group = { Parts: { BasePart }, Rest: { CFrame } }
export type Life = {
	Model: Model,
	At: CFrame,
	Holograms: { [string]: { Model: Model, Group: Group, Glows: { [BasePart]: boolean } } },
	Shown: string?,
	ShownIndex: number?,
	Scan: BasePart,
	Beam: BasePart,
	Plate: BasePart,
	Prompt: ProximityPrompt,
	PlateName: TextLabel,
	PlateLine: TextLabel,
	Gems: { Group },
	Drones: { { Group: Group, Eye: BasePart } },
}

-- A kaiju of `species` in light, at the hologram's scale, its feet at the
-- origin and its middle over it (parts kept as offsets from there).
local function hologram(parent: Instance, species: string)
	local source = KaijuModels.build(species, "Fire")
	local list = {}
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(list, d)
			local p = d.CFrame.Position
			lo = V(math.min(lo.X, p.X), math.min(lo.Y, p.Y - d.Size.Y / 2), math.min(lo.Z, p.Z))
			hi = V(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
		end
	end
	local model = Instance.new("Model")
	model.Name = "Hologram" .. species
	local middle = V((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	local group: Group = { Parts = {}, Rest = {} }
	local glows = {}
	local s = ShelterLife.Scale
	for _, d in list do
		local p = part(model, d.Size * s, WHITE, Enum.Material.ForceField, if d:IsA("WedgePart") then "Wedge" else nil)
		if d:IsA("Part") and d.Shape ~= Enum.PartType.Block then
			(p :: Part).Shape = d.Shape
		end
		p.Name = d.Name
		local rotation = d.CFrame - d.CFrame.Position
		table.insert(group.Parts, p)
		table.insert(group.Rest, CFrame.new((d.CFrame.Position - middle) * s) * rotation)
		if d.Material == Enum.Material.Neon then
			glows[p] = true
			p.Material = Enum.Material.Neon
		end
	end
	source:Destroy()
	model.Parent = parent
	return { Model = model, Group = group, Glows = glows }
end

-- A gem: a cut crystal (eight facets, two wedges each) round a glowing core.
local function gem(parent: Instance, color: Color3, legendary: boolean): Group
	local group: Group = { Parts = {}, Rest = {} }
	local top, bottom = V(0, 1.1, 0), V(0, -1.1, 0)
	local ring = {}
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		table.insert(ring, V(math.cos(a) * 0.9, 0.12, math.sin(a) * 0.9))
	end
	local light, dark = color:Lerp(WHITE, 0.12), color:Lerp(C(20, 20, 30), 0.25)
	for k = 1, 4 do
		local a, b = ring[k], ring[k % 4 + 1]
		for half, apex in { top, bottom } do
			local first, second = GemShapes.wedges(apex, a, b, 0.05)
			for _, w in { first, second } do
				local p =
					part(parent, w.Size, if (k + half) % 2 == 0 then light else dark, Enum.Material.Glass, "Wedge")
				p.Transparency = 0.12
				table.insert(group.Parts, p)
				table.insert(group.Rest, w.CFrame)
			end
		end
	end
	local core = part(parent, V(0.7, 0.7, 0.7), color, Enum.Material.Neon, "Ball")
	table.insert(group.Parts, core)
	table.insert(group.Rest, CFrame.new(0, 0.05, 0))
	if legendary then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(C(255, 236, 170))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Rate = 5
		sparkle.Speed = NumberRange.new(0.6, 1.2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = core
	end
	return group
end

-- A maintenance drone: a dark body on a steel ring, four rotors, an eye
-- that blinks, and a spotlight underneath.
local function drone(parent: Instance): { Group: Group, Eye: BasePart }
	local group: Group = { Parts = {}, Rest = {} }
	local function add(p: BasePart, rest: CFrame)
		table.insert(group.Parts, p)
		table.insert(group.Rest, rest)
		return p
	end
	add(part(parent, V(1.4, 1.1, 1.6), DARK, Enum.Material.Metal, "Ball"), CFrame.new())
	add(part(parent, V(0.2, 2.3, 2.3), STEEL, Enum.Material.Metal, "Cylinder"), CFrame.Angles(0, 0, math.rad(90)))
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		add(
			part(parent, V(0.08, 1, 1), C(200, 210, 225), Enum.Material.SmoothPlastic, "Cylinder"),
			CFrame.new(math.cos(a) * 1.25, 0.3, math.sin(a) * 1.25) * CFrame.Angles(0, 0, math.rad(90))
		)
	end
	local eye =
		add(part(parent, V(0.42, 0.42, 0.42), C(110, 220, 255), Enum.Material.Neon, "Ball"), CFrame.new(0, 0.05, -0.72))
	local lens = add(part(parent, V(0.6, 0.12, 0.6), C(236, 242, 255), Enum.Material.Neon), CFrame.new(0, -0.55, 0))
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 40
	spot.Range = 26
	spot.Brightness = 1.6
	spot.Color = C(220, 236, 255)
	spot.Parent = lens
	return { Group = group, Eye = eye }
end

local function emitter(anchor: BasePart, spec)
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.LightInfluence = 0
	for key, value in spec do
		(e :: any)[key] = value
	end
	e.Parent = anchor
	return e
end

function ShelterLife.build(at: CFrame): Life
	local model = Instance.new("Model")
	model.Name = "ShelterLife"
	local function place(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	local stage = ShelterLife.Stage

	-- The hologram: a faint column of light over the stage, a scan, every
	-- species ready (one shown at a time), and the name plate over it.
	local holo = Instance.new("Model")
	holo.Name = "Hologram"
	holo.Parent = model
	local beam = part(holo, V(13, 9.8, 9.8), C(170, 120, 255), Enum.Material.Neon, "Cylinder")
	beam.Name = "ProjectorBeam"
	beam.Transparency = 0.93
	beam.CFrame = place(stage.X, stage.Y + 6.5, stage.Z) * CFrame.Angles(0, 0, math.rad(90))
	local scan = part(holo, V(0.08, 11, 11), C(170, 120, 255), Enum.Material.Neon, "Cylinder")
	scan.Name = "ScanPlane"
	scan.Transparency = 0.7
	local holograms = {}
	for _, entry in ShelterLife.Kaiju do
		if not holograms[entry.Species] then
			holograms[entry.Species] = hologram(holo, entry.Species)
			holograms[entry.Species].Model.Parent = nil
		end
	end
	local plate = part(holo, V(12, 2.4, 0.1), WHITE)
	plate.Name = "HologramName"
	plate.Transparency = 1
	plate.CFrame = place(stage.X, stage.Y + 13.2, stage.Z) * CFrame.Angles(0, math.pi, 0) -- (facing the door)
	local _, lines = label(plate, Enum.NormalId.Front, {
		{ Text = "", Color = WHITE, Size = 0.6, Font = Enum.Font.GothamBlack },
		{ Text = "", Color = WHITE, Size = 0.4, Font = Enum.Font.GothamMedium },
	})
	-- The projector's console: a pedestal with a lit screen, facing the door.
	local spot = ShelterLife.Console
	local console = part(holo, V(1.6, 3, 1.2), DARK, Enum.Material.Metal)
	console.Name = "ProjectorConsole"
	console.CanCollide = true
	console.CFrame = place(spot.X, spot.Y + 1.5, spot.Z)
	local screen = part(holo, V(2.2, 0.14, 1.5), C(170, 120, 255), Enum.Material.Neon)
	screen.Name = "ProjectorScreen"
	screen.CFrame = place(spot.X, spot.Y + 3.1, spot.Z) * CFrame.Angles(math.rad(30), 0, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Next kaiju", "HOLO PROJECTOR"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = console

	-- The gallery: a gem in each case, its rarity and odds on its plinth,
	-- and the gallery's name over the middle case.
	local gallery = Instance.new("Model")
	gallery.Name = "Gallery"
	gallery.Parent = model
	local spec = ShelterLife.Gallery
	local gems = {}
	for i, entry in ShelterLife.odds() do
		local a = math.rad(spec.From + (i - 1) * spec.Step)
		local foot = spec.Middle + V(math.cos(a) * spec.Radius, 0, math.sin(a) * spec.Radius)
		local toward = (spec.Middle - foot) * V(1, 0, 1)
		table.insert(gems, gem(gallery, entry.Color, entry.Tier == "Legendary"))
		local plaque = part(gallery, V(2.4, 1.05, 0.08), C(30, 34, 44), Enum.Material.SmoothPlastic)
		plaque.Name = "Odds" .. entry.Tier
		local front = foot + toward.Unit * 1.52 + V(0, 2.15, 0)
		plaque.CFrame = at * facing(front, front + toward)
		label(plaque, Enum.NormalId.Front, {
			{ Text = string.upper(entry.Label), Color = entry.Color, Size = 0.55, Font = Enum.Font.GothamBlack },
			{
				Text = percentText(entry.Percent) .. " OF GEMS",
				Color = WHITE,
				Size = 0.4,
				Font = Enum.Font.GothamMedium,
			},
		})
	end
	local header = part(gallery, V(11, 2.6, 0.1), WHITE)
	header.Name = "GalleryName"
	header.Transparency = 1
	do
		local a = math.rad(spec.From + 2 * spec.Step)
		local spot = spec.Middle + V(math.cos(a) * (spec.Radius + 1.5), 10.2, math.sin(a) * (spec.Radius + 1.5))
		header.CFrame = at * facing(spot, spec.Middle + V(0, 10.2, 0))
	end
	label(header, Enum.NormalId.Front, {
		{ Text = "GEM GALLERY", Color = C(110, 220, 255), Size = 0.6, Font = Enum.Font.GothamBlack },
		{ Text = "WHAT A ROCK CAN PAY", Color = WHITE, Size = 0.4, Font = Enum.Font.GothamMedium },
	})

	-- The drones.
	local fleet = Instance.new("Model")
	fleet.Name = "Drones"
	fleet.Parent = model
	local drones = {}
	for _ = 1, 3 do
		table.insert(drones, drone(fleet))
	end

	-- Fireflies over the garden, and dust drifting down from the skylight.
	local garden = ShelterLife.Garden
	local flies = part(model, V(22, 8, 22), WHITE)
	flies.Name = "Fireflies"
	flies.Transparency = 1
	flies.CFrame = place(garden.X, garden.Y + 6, garden.Z)
	emitter(flies, {
		Color = ColorSequence.new(C(220, 255, 150), C(150, 255, 220)),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.5, 0.26),
			NumberSequenceKeypoint.new(1, 0.06),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.15),
			NumberSequenceKeypoint.new(0.8, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(3, 6),
		Rate = 5,
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = V(0, 0.05, 0),
	})
	local motes = part(model, V(64, 1, 40), WHITE)
	motes.Name = "SkylightMotes"
	motes.Transparency = 1
	motes.CFrame = place(0, 30, 19)
	emitter(motes, {
		Color = ColorSequence.new(C(220, 232, 255)),
		LightEmission = 0.5,
		Size = NumberSequence.new(0.1),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(12, 16),
		Rate = 6,
		Speed = NumberRange.new(0.6, 1.2),
		EmissionDirection = Enum.NormalId.Bottom,
	})

	local life: Life = {
		Model = model,
		At = at,
		Holograms = holograms,
		Shown = nil,
		ShownIndex = nil,
		Scan = scan,
		Beam = beam,
		Plate = plate,
		Prompt = prompt,
		PlateName = lines[1],
		PlateLine = lines[2],
		Gems = gems,
		Drones = drones,
	}
	ShelterLife.pose(life, 0)
	return life
end

-- Moves every part of each group to `pivot * rest` (in one bulk move in the
-- game).
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

function ShelterLife.pose(life: Life, t: number, stageTime: number?)
	local at = life.At
	local parts, cframes = {}, {}
	local function put(group: Group, pivot: CFrame)
		for i, p in group.Parts do
			table.insert(parts, p)
			table.insert(cframes, pivot * group.Rest[i])
		end
	end

	-- The kaiju on the stage: the next one flickers in (and its name with
	-- it), the scan sweeping up through it.
	local holoT = stageTime or t
	local index, flicker = ShelterLife.kaijuAt(holoT)
	local entry = ShelterLife.Kaiju[index]
	local shown = life.Holograms[entry.Species]
	if life.ShownIndex ~= index then
		if life.Shown and life.Shown ~= entry.Species then
			life.Holograms[life.Shown].Model.Parent = nil
		end
		shown.Model.Parent = life.Beam.Parent
		local palette = KaijuModels.Palettes[entry.Element]
		for _, p in shown.Group.Parts do
			p.Color = if shown.Glows[p] then palette.Glow:Lerp(WHITE, 0.2) else palette.Glow:Lerp(palette.Plate, 0.35)
		end
		life.Beam.Color = palette.Glow
		life.Scan.Color = palette.Glow
		life.PlateName.Text = string.upper(entry.Species)
		life.PlateLine.Text = string.upper(entry.Element) .. " KAIJU  ·  ARENA OPENS SOON"
		life.PlateLine.TextColor3 = palette.Glow
		life.Shown, life.ShownIndex = entry.Species, index
	end
	-- (On, off, on as it comes in; then steady.)
	local on = flicker >= 1 or (math.floor(flicker * 9) % 2 == 0 and flicker > 0.15)
	local fade = if flicker >= 1 then 0 else 0.35 * (1 - flicker)
	for _, p in shown.Group.Parts do
		local base = if shown.Glows[p] then 0.15 else 0.05
		p.Transparency = if on then base + fade else 1
	end
	local stage = at * CFrame.new(ShelterLife.Stage)
	local spin = (t % ShelterLife.Turn) / ShelterLife.Turn * math.pi * 2
	put(shown.Group, stage * CFrame.new(0, 0.35 + math.sin(t * 1.2) * 0.25, 0) * CFrame.Angles(0, spin, 0))
	local sweep = ((holoT % ShelterLife.Hold) / 3) % 1
	life.Scan.CFrame = stage * CFrame.new(0, 0.3 + sweep * 11, 0) * CFrame.Angles(0, 0, math.rad(90))
	life.Scan.Transparency = 0.6 + 0.4 * sweep

	-- The gems, each turning at its own pace and bobbing in its case.
	local spec = ShelterLife.Gallery
	for i, group in life.Gems do
		local a = math.rad(spec.From + (i - 1) * spec.Step)
		local foot = spec.Middle + V(math.cos(a) * spec.Radius, 0, math.sin(a) * spec.Radius)
		local turn = t * (0.5 + i * 0.12)
		put(group, at * CFrame.new(foot + V(0, 5.4 + math.sin(t * 1.4 + i) * 0.18, 0)) * CFrame.Angles(0, turn, 0.12))
	end

	-- The drones: on their loops, the eye blinking every couple of seconds.
	for k, d in life.Drones do
		put(d.Group, at * ShelterLife.droneAt(k, t))
		d.Eye.Transparency = if (t + k * 0.7) % 2.2 < 0.12 then 0.85 else 0
	end
	bulkMove(parts, cframes)
end

-- In the game: built once, shown while you're in the Outpost and near
-- the Shelter.
local life: Life? = nil
local wanted = false
local clock = 0
local skip = 0 -- seconds the console has moved the hologram on, for this player
function ShelterLife.mount(at: CFrame)
	if life then
		return
	end
	life = ShelterLife.build(at)
	life.Prompt.Triggered:Connect(function()
		local now = workspace:GetServerTimeNow() + skip
		skip += ShelterLife.Hold - now % ShelterLife.Hold
	end)
end

local function near(): boolean
	local camera = workspace.CurrentCamera
	return life ~= nil and camera ~= nil and (camera.CFrame.Position - life.At.Position).Magnitude < ShelterLife.Reach
end

function ShelterLife.show(on: boolean)
	wanted = on
	if not life then
		return
	end
	local visible = on and near()
	local parent = if visible then workspace else nil
	if life.Model.Parent ~= parent then
		life.Model.Parent = parent
	end
end

function ShelterLife.step(dt: number)
	if not (life and wanted) then
		return
	end
	clock += dt
	if clock < 1 / 30 then
		return
	end
	clock = 0
	ShelterLife.show(wanted)
	if life.Model.Parent then
		local now = workspace:GetServerTimeNow()
		ShelterLife.pose(life, now, now + skip)
	end
end

return ShelterLife
