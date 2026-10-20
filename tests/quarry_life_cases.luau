-- The quarry's life (Client QuarryLife) on Roblox instances (lune's roblox
-- library): the road lights (and no searchlights), the meteor showers, the
-- cargo lifter, the dust devils, the vents and the conveyor's ore. It
-- lines up with the quarry the server builds (OutpostWorld): lights on the
-- roads in their bands' colours, the lifter clear of everything, nothing
-- in anyone's way. Run by tests/run_quarry_life.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."
local CFrame, Vector3 = R.CFrame, R.Vector3

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- Modules load by name: Shared first, then the client's.
local mods = {}
local function proxy(name)
	return setmetatable({ __mod = name }, {
		__index = function(_, key)
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, child)
					return proxy(child)
				end
			end
			return proxy(key)
		end,
	})
end
local env
local function load(name)
	if mods[name] then
		return mods[name]
	end
	local path = ROOT .. "/src/shared/" .. name .. ".luau"
	if not fs.isFile(path) then
		path = ROOT .. "/src/client/Modules/" .. name .. ".luau"
	end
	mods[name] = luau.load(fs.readFile(path), { debugName = name, environment = env })()
	return mods[name]
end
env = {
	Instance = R.Instance,
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
	Vector2 = R.Vector2,
	Color3 = R.Color3,
	Enum = R.Enum,
	UDim2 = R.UDim2,
	ColorSequence = R.ColorSequence,
	NumberSequence = R.NumberSequence,
	NumberSequenceKeypoint = R.NumberSequenceKeypoint,
	NumberRange = R.NumberRange,
	game = {
		GetService = function(_, service)
			if service == "Workspace" then
				return nil
			end
			return proxy(service)
		end,
	},
	script = { Parent = proxy("Modules") },
	require = function(p)
		return load(p.__mod)
	end,
}
local Life = load("QuarryLife")
local Frontier = load("Frontier")

-- The quarry as the server builds it.
local Rand = {}
Rand.__index = Rand
function Rand.new(seed)
	return setmetatable({ x = (seed or 7) % 2147483647 + 1 }, Rand)
end
function Rand:_n()
	self.x = (self.x * 48271) % 2147483647
	return self.x / 2147483647
end
function Rand:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_n()
end
function Rand:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_n())
end
local worldEnv = {
	Instance = R.Instance,
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
	Vector2 = R.Vector2,
	Color3 = R.Color3,
	Enum = R.Enum,
	UDim2 = R.UDim2,
	NumberRange = R.NumberRange,
	NumberSequence = R.NumberSequence,
	NumberSequenceKeypoint = R.NumberSequenceKeypoint,
	ColorSequence = R.ColorSequence,
	Random = Rand,
	game = {
		GetService = function()
			error("offline")
		end,
	},
	script = { Parent = setmetatable({}, {
		__index = function()
			return nil
		end,
	}) },
}
local World = luau.load(
	fs.readFile(ROOT .. "/src/server/World/OutpostWorld.luau"),
	{ debugName = "OutpostWorld", environment = worldEnv }
)()
World.Frontier = Frontier
local Rules = load("Outpost")
World.Rules = Rules
local at = CFrame.new(-30, 0, 9000)
local site = World.build(at, R.Instance.new("Folder"))
local function here(p: Vector3): Vector3
	return at:PointToObjectSpace(p)
end
-- A part's box, in the quarry's frame (axis-aligned round its corners).
local function box(p): (Vector3, Vector3)
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local half = p.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local q = here(p.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				low = Vector3.new(math.min(low.X, q.X), math.min(low.Y, q.Y), math.min(low.Z, q.Z))
				high = Vector3.new(math.max(high.X, q.X), math.max(high.Y, q.Y), math.max(high.Z, q.Z))
			end
		end
	end
	return low, high
end
local function overlaps(aLow, aHigh, bLow, bHigh)
	return aLow.X < bHigh.X
		and aHigh.X > bLow.X
		and aLow.Y < bHigh.Y
		and aHigh.Y > bLow.Y
		and aLow.Z < bHigh.Z
		and aHigh.Z > bLow.Z
end
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Built: light, and nothing in anyone's way, clickable or shadowed.
local life = Life.build(at)
local count = 0
for _, d in life.Model:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
		check(
			d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch and not d.CastShadow,
			d.Name .. " can be bumped, clicked or casts a shadow"
		)
	end
end
check(count <= 280, "Too many parts: " .. count)

-- The road lights: on the haul roads the server lays (inside a road's
-- edges), off the ring road's crossing and the jump ramps, each in its
-- frontier band's colour, and a pulse running out along them.
local roads, ramps = {}, {}
for _, d in site.Model:FindFirstChild("Roads"):GetChildren() do
	if d:IsA("BasePart") and d.Size.Z > 40 and d.Size.Y < 0.5 then
		table.insert(roads, d)
	elseif d:IsA("WedgePart") then
		table.insert(ramps, d)
	end
end
check(#roads >= #Frontier.Spokes and #ramps == #Frontier.Spokes, "The roads or ramps weren't found")
-- Where a point is on a road: across it (X) and along it (Z) from its
-- middle. (Read from the road's middle and length, not its turn: lune's
-- lookAt faces the other way. A haul road runs straight out from the
-- middle; a ring road's piece runs round it.)
local function across(road, p: Vector3): Vector3
	local mid = flat(here(road.CFrame.Position))
	local out = mid.Unit
	local along = if road.Size.Z > 100 then out else Vector3.new(-out.Z, 0, out.X)
	local side = Vector3.new(-along.Z, 0, along.X)
	local d = flat(p) - mid
	return Vector3.new(d:Dot(side), 0, d:Dot(along))
end
local lights = Life.lights()
check(#lights >= 20 * #Frontier.Spokes, "Too few road lights: " .. #lights)
local perRoad = {}
for _, light in lights do
	local p = light.Position
	local out = flat(p).Magnitude
	perRoad[light.Road] = (perRoad[light.Road] or 0) + 1
	local onRoad = false
	for _, road in roads do
		local q = across(road, p)
		if math.abs(q.X) <= road.Size.X / 2 - 0.4 and math.abs(q.Z) <= road.Size.Z / 2 then
			onRoad = true
		end
	end
	check(onRoad, "A road light off the road, " .. math.floor(out) .. " out")
	for _, ramp in ramps do
		local low, high = box(ramp)
		check(
			not (p.X > low.X - 3 and p.X < high.X + 3 and p.Z > low.Z - 3 and p.Z < high.Z + 3),
			"A road light on a jump ramp"
		)
	end
	check(math.abs(out - Life.Roads.Ring) > 9, "A road light on the ring road's crossing")
	local band = if out < Frontier.Core then "Core" elseif out < Frontier.EdgeFrom then "Fringe" else "Edge"
	check(light.Band == band, "A road light in the wrong band's colour")
	check(p.Y > 0.16 and p.Y < 0.6, "A road light isn't set in the road")
end
for road = 1, #Frontier.Spokes do
	check((perRoad[road] or 0) >= 16, "Road " .. road .. " has too few lights")
end
for i, light in life.Lights do
	check(light.Part.Color == Frontier.Bands[lights[i].Band].Color, "A road light's colour isn't its band's")
end
-- (the pulse: every light glows, brightest as the pulse passes, and it
-- passes further out later)
for out = 120, 400, 40 do
	for t = 0, 5, 0.25 do
		local g = Life.glow(out, t)
		check(g >= 0.25 and g <= 1, "A road light's glow out of range")
	end
end
local function peak(out)
	local best, when = -1, 0
	for t = 0, Life.PulseEvery, 0.01 do
		local g = Life.glow(out, t + 100)
		if g > best then
			best, when = g, t
		end
	end
	return when
end
check((peak(200) - peak(130)) % Life.PulseEvery > 0.5, "The pulse doesn't run out along the road")
Life.pose(life, 3.3, Vector3.new(0, 0, 0))
local lit, dim = 0, 0
for _, light in life.Lights do
	if light.Part.Transparency < 0.3 then
		lit += 1
	elseif light.Part.Transparency > 0.5 then
		dim += 1
	end
end
check(lit > 0 and dim > 0, "The road lights don't pulse")

-- Everything standing in the quarry (for the lifter to
-- keep clear of): every part that rises off the ground, but the crater's
-- benches and rim, the invisible walls and the rocks' room.
local standing = {}
for _, d in site.Model:GetDescendants() do
	if d:IsA("BasePart") and not (d.Transparency >= 1 and not d.CanCollide) then
		local low, high = box(d)
		local r = flat((low + high) / 2).Magnitude
		if high.Y > 1.4 and r < 420 and (high - low).Magnitude < 200 then
			table.insert(standing, { d, low, high })
		end
	end
end
-- Whether a box (low, high) is clear of a standing part. A long pipe laid
-- on the slant fills only a strip across its own box: it's clear of
-- whatever is clear of both of that box's diagonals.
local function clearOf(low: Vector3, high: Vector3, s): boolean
	if not overlaps(low, high, s[2], s[3]) then
		return true
	end
	local size = s[1].Size
	local span = s[3] - s[2]
	local long = math.max(size.X, size.Y, size.Z)
	if long < 20 or span.X * span.Y * span.Z < 12 * size.X * size.Y * size.Z then
		return false
	end
	local thick = math.min(size.X, size.Y, size.Z) / 2
	local centre = flat((low + high) / 2)
	local reach = flat(high - low).Magnitude / 2 + thick + 0.5
	for _, diagonal in { { s[2], s[3] }, { Vector3.new(s[2].X, 0, s[3].Z), Vector3.new(s[3].X, 0, s[2].Z) } } do
		local a, b = flat(diagonal[1]), flat(diagonal[2])
		local u = math.clamp((centre - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
		if (a:Lerp(b, u) - centre).Magnitude < reach then
			return false
		end
	end
	return true
end

-- The lifter: rests with its container on the landing pad, lifts off,
-- flies over the Shelter, hovers at the north outpost and comes back, never
-- jumping, never touching anything.
local trip = Life.Trip
local last = nil
local seen = {}
for t = 0, trip * 2, 0.25 do
	local frame, doing = Life.lifterAt(t)
	seen[doing] = true
	if last then
		check((frame.Position - last.Position).Magnitude < 6, "The lifter jumps at " .. t)
		local _, yaw0 = last:ToEulerAnglesYXZ()
		local _, yaw1 = frame:ToEulerAnglesYXZ()
		local turn = math.abs((yaw1 - yaw0 + math.pi) % (2 * math.pi) - math.pi)
		check(turn < 0.4, "The lifter spins round at " .. t)
	end
	last = frame
	if doing == "Resting" then
		check(
			(flat(frame.Position) - flat(Life.Pad)).Magnitude < 0.01
				and math.abs(frame.Position.Y - Life.Hang - Life.Pad.Y) < 0.01,
			"The lifter isn't resting on the pad"
		)
	elseif doing == "Hovering" then
		check((frame.Position - Life.Drop).Magnitude < 1, "The lifter doesn't hover at the north outpost")
	end
	Life.pose(life, t)
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in life.Lifter.Parts do
		local a, b = box(p)
		low = Vector3.new(math.min(low.X, a.X), math.min(low.Y, a.Y), math.min(low.Z, a.Z))
		high = Vector3.new(math.max(high.X, b.X), math.max(high.Y, b.Y), math.max(high.Z, b.Z))
	end
	check(low.Y >= Life.Pad.Y - 0.05, "The lifter's container goes into the ground")
	for _, s in standing do
		local name = s[1].Name
		-- (it stands on its pad)
		local pad = flat((s[2] + s[3]) / 2) - flat(Life.Pad)
		if not (pad.Magnitude < 21 and s[3].Y < 1.6) then
			check(clearOf(low, high, s), "The lifter hits " .. name .. " at " .. t .. " (" .. doing .. ")")
		end
	end
end
for _, doing in { "Resting", "Lifting", "Flying", "Lowering", "Hovering", "Rising", "Landing" } do
	check(seen[doing], "The lifter never does " .. doing)
end
-- (over the Shelter, well clear of its skylight and upper deck, up on its legs)
for t = 0, trip, 0.5 do
	local frame = Life.lifterAt(t)
	local p = frame.Position
	if math.abs(p.X) < 90 and math.abs(p.Z) < 66 then
		check(p.Y - Life.Hang > 46 + Rules.ShelterLift, "The lifter flies low over the Shelter")
	end
end

-- No searchlights: nothing sweeps the sky over the quarry.
check(Life.Searchlights == nil and Life.searchAt == nil, "The searchlights are back")

-- The meteors: every shower all of them, high over the crater, falling,
-- and none between showers.
for shower = 0, 6 do
	local shown = {}
	for t = shower * Life.Shower, (shower + 1) * Life.Shower, 0.1 do
		for k = 1, Life.Meteors do
			local head, u = Life.meteorAt(k, t)
			if head then
				shown[k] = true
				check(u >= 0 and u < 1, "A meteor past its streak")
				check(head.Position.Y > 140, "A meteor comes down too low")
				check(head.LookVector.Y < -0.1, "A meteor doesn't fall")
				check(t - shower * Life.Shower < 10, "A meteor between showers")
			end
		end
	end
	for k = 1, Life.Meteors do
		check(shown[k], "Meteor " .. k .. " missed a shower")
	end
end

-- The dust devils: out in the basin, clear of the Shelter, inside the benches.
for k = 1, Life.Devils do
	for t = 0, 3000, 7 do
		local p = Life.devilAt(k, t)
		local r = flat(p).Magnitude
		check(r > 120 and r < 380, "A dust devil strays: " .. r)
		check(not (math.abs(p.X) < 100 and math.abs(p.Z) < 76), "A dust devil in the Shelter")
	end
end

-- The vents: in the craters, off the roads and clear of where rocks grow,
-- bursting in turn.
for k, spot in Life.Vents do
	for _, rock in site.Spots do
		check(flat(here(rock.Position) - spot).Magnitude > 7, "Vent " .. k .. " is where a rock grows")
	end
	for _, road in roads do
		local q = across(road, spot)
		check(
			not (math.abs(q.X) < road.Size.X / 2 + 4 and math.abs(q.Z) < road.Size.Z / 2),
			"Vent " .. k .. " is on a road"
		)
	end
	local on = 0
	for t = 0, Life.VentEvery * 4, 0.25 do
		if Life.venting(k, t) then
			on += 1
		end
	end
	check(on > 0 and on < Life.VentEvery * 4 * 4 * 0.4, "Vent " .. k .. " never bursts, or never stops")
end
for t = 0, 200, 0.5 do
	local bursting = 0
	for k = 1, #Life.Vents do
		if Life.venting(k, t) then
			bursting += 1
		end
	end
	check(bursting <= 1, "Vents bursting all at once")
end

-- The crystal spires: on the crater's top bench (the server's), none on a
-- ramp up to it, none floating or sunk.
do
	local benchTop, ramps = nil, {}
	for _, d in site.Model:FindFirstChild("Ground"):GetChildren() do
		if d:IsA("BasePart") and d.CanCollide then
			local low, high = box(d)
			local r = flat((low + high) / 2).Magnitude
			if d:IsA("WedgePart") then
				table.insert(ramps, flat((low + high) / 2))
			elseif r > Life.Spires.Out - 5 and r < Life.Spires.Out + 5 and high.Y < 40 then
				benchTop = math.max(benchTop or 0, high.Y)
			end
		end
	end
	check(benchTop and math.abs(benchTop - Life.Spires.Top) < 0.01, "The spires aren't at the top bench's height")
	check(#life.Spires == Life.Spires.Count * 6, "Not three shards in every spire cluster")
	for i = 1, #life.Spires, 2 do
		local shard = life.Spires[i]
		local low, high = box(shard)
		local r = flat((low + high) / 2).Magnitude
		check(r > Life.Spires.Out - 9 and r < Life.Spires.Out + 7, "A spire off the top bench: " .. r)
		check(low.Y < Life.Spires.Top + 0.1 and low.Y > Life.Spires.Top - 3, "A spire floats or sinks")
		for _, ramp in ramps do
			check((flat((low + high) / 2) - ramp).Magnitude > 20, "A spire on a ramp")
		end
	end
end

-- The ore rides along the conveyor, between its ends.
local a, b = Life.Conveyor[1], Life.Conveyor[2]
for t = 0, 30, 0.7 do
	Life.pose(life, t)
	for _, chunk in life.Ore do
		local p = here(chunk.CFrame.Position)
		local u = (p - a):Dot(b - a) / (b - a):Dot(b - a)
		check(u >= -0.01 and u <= 1.01 and (a:Lerp(b, u) - p).Magnitude < 0.05, "Ore falls off the conveyor")
	end
end

print(
	"PASS: "
		.. checks
		.. " quarry life checks ("
		.. count
		.. " parts: "
		.. #lights
		.. " road lights, no searchlights, "
		.. Life.Meteors
		.. " meteors, the lifter, "
		.. Life.Devils
		.. " dust devils, "
		.. #Life.Vents
		.. " vents, the conveyor's ore, "
		.. Life.Spires.Count
		.. " crystal spires)"
)
