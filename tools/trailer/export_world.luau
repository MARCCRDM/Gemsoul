-- lune run export_world.luau <gemsoul root> <out.json>
-- The Outpost as the server builds it (OutpostWorld.build), with a rock on
-- every spot, every visible part flattened to a list for the trailer renderer.
local fs, luau, roblox, serde, process = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox"), require("@lune/serde"), require("@lune/process")
local R = roblox
local ROOT, OUT = process.args[1], process.args[2]
local Rand = {}
Rand.__index = Rand
function Rand.new(seed)
	local s = { x = (seed or 1) % 2147483647 }
	if s.x <= 0 then s.x += 2147483646 end
	return setmetatable(s, Rand)
end
function Rand:_n() self.x = (self.x * 48271) % 2147483647 return self.x / 2147483647 end
function Rand:NextNumber(a, b) a, b = a or 0, b or 1 return a + (b - a) * self:_n() end
function Rand:NextInteger(a, b) return math.floor(a + (b - a + 1) * self:_n()) end
local env = setmetatable({
	Instance = R.Instance, CFrame = R.CFrame, Vector3 = R.Vector3, Vector2 = R.Vector2, Color3 = R.Color3, Enum = R.Enum,
	UDim2 = R.UDim2, UDim = R.UDim, NumberRange = R.NumberRange, NumberSequence = R.NumberSequence,
	NumberSequenceKeypoint = R.NumberSequenceKeypoint, ColorSequence = R.ColorSequence, ColorSequenceKeypoint = R.ColorSequenceKeypoint,
	Font = R.Font, PhysicalProperties = R.PhysicalProperties, Random = Rand,
	game = { GetService = function() error("offline") end },
	script = { Parent = setmetatable({}, { __index = function() return nil end }) },
}, { __index = _G })
local function load(path, name)
	return luau.load(fs.readFile(ROOT .. path), { debugName = name, environment = env })()
end
local Frontier = load("/src/shared/Frontier.luau", "Frontier")
local Outpost = load("/src/shared/Outpost.luau", "Outpost")
local W = load("/src/server/World/OutpostWorld.luau", "OutpostWorld")
W.Frontier = Frontier
local holder = R.Instance.new("Folder")
local origin = R.CFrame.new(0, 0, 0)
local site = W.build(origin, holder)
local rocks = R.Instance.new("Folder")
rocks.Parent = site.Model
local rng = Rand.new(9)
local placed = 0
for i, spot in site.Spots do
	local size = Outpost.rollSize(rng:NextNumber())
	local zone = site.Zones and site.Zones[i]
	local tint = nil
	if Frontier.Bands and zone and Frontier.Bands[zone] and Frontier.Bands[zone].Color then
		tint = Frontier.Bands[zone].Color
	end
	W.rock(size, spot, rng, tint).Parent = rocks
	placed += 1
end
local function shapeOf(d)
	if d.ClassName == "WedgePart" then return "Wedge" end
	if d.ClassName == "CornerWedgePart" then return "CornerWedge" end
	local mesh = d:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		if mesh.MeshType == R.Enum.MeshType.Sphere then return "MeshSphere" end
		if mesh.MeshType == R.Enum.MeshType.Cylinder then return "MeshCylinder" end
		if mesh.MeshType == R.Enum.MeshType.Wedge then return "Wedge" end
	end
	if d.ClassName == "Part" then return d.Shape.Name end
	return "Block"
end

if process.args[3] == "rock" then
	local holder2 = R.Instance.new("Folder")
	local rockModel = W.rock(process.args[4] or "Boulder", R.CFrame.new(0, 0, 0), Rand.new(tonumber(process.args[5]) or 5))
	rockModel.Parent = holder2
	local parts2, flat = {}, {}
	for _, d in rockModel:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf = d.CFrame
			local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			table.insert(parts2, { s = { d.Size.X, d.Size.Y, d.Size.Z }, c = { d.Color.R, d.Color.G, d.Color.B }, shape = shapeOf(d), mat = d.Material.Name, tr = d.Transparency })
			for _, v in { px, py, pz, r00, r10, r20, r01, r11, r21, r02, r12, r22 } do table.insert(flat, v) end
		end
	end
	fs.writeFile(OUT, serde.encode("json", { parts = parts2, frames = { flat }, dist = { 0 } }))
	print("rock parts", #parts2)
	return
end
local parts, lights = {}, {}
for _, d in site.Model:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local cf = d.CFrame
		table.insert(parts, {
			s = { d.Size.X, d.Size.Y, d.Size.Z },
			p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
			r = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z, cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z, -cf.LookVector.X, -cf.LookVector.Y, -cf.LookVector.Z },
			c = { d.Color.R, d.Color.G, d.Color.B },
			shape = shapeOf(d), mat = d.Material.Name, tr = d.Transparency,
		})
	elseif (d:IsA("PointLight") or d:IsA("SpotLight")) and d.Enabled and d.Parent and d.Parent:IsA("BasePart") then
		local p = d.Parent.CFrame.Position
		table.insert(lights, { p = { p.X, p.Y, p.Z }, c = { d.Color.R, d.Color.G, d.Color.B }, range = d.Range, b = d.Brightness })
	end
end
local spawn = site.Spawn.Position
local spots = {}
for _, s in site.Spots do table.insert(spots, { s.Position.X, s.Position.Y, s.Position.Z }) end
local scars = {}
for _, s in site.Scars or {} do
	table.insert(scars, { s.Position.X, s.Position.Y, s.Position.Z, s.LookVector.X, s.LookVector.Z })
end
local parking = {}
for _, p in site.Parking or {} do
	table.insert(parking, { p.Kind, p.CFrame.Position.X, p.CFrame.Position.Y, p.CFrame.Position.Z, p.CFrame.LookVector.X, p.CFrame.LookVector.Z })
end
fs.writeFile(OUT, serde.encode("json", { Parts = parts, Lights = lights, Spawn = { spawn.X, spawn.Y, spawn.Z }, Spots = spots, Scars = scars, Parking = parking }))
print("parts", #parts, "lights", #lights, "rocks", placed, "spots", #site.Spots)
