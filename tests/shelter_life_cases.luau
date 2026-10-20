-- The Shelter's life (Client ShelterLife) on Roblox instances (lune's roblox
-- library): the hologram over the kaiju arena's stage, the gems in the Gem
-- Gallery's cases, the drones over the hall. It lines up with the Shelter
-- the server builds (OutpostWorld), stays in its places as it moves, never
-- gets in anyone's way, and stays light. Run by tests/run_shelter_life.py.
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
local Life = load("ShelterLife")
local GemRoller = load("GemRoller")

-- The Shelter as the server builds it.
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
World.Frontier =
	luau.load(fs.readFile(ROOT .. "/src/shared/Frontier.luau"), { debugName = "Frontier", environment = worldEnv })()
local at = CFrame.new(0, 0, 7000)
local site = World.build(at, R.Instance.new("Folder"))
local shelter = site.Model:FindFirstChild("Shelter", true)
check(shelter, "No Shelter")

local life = Life.build(at)
local function here(p: Vector3): Vector3
	return at:PointToObjectSpace(p)
end

-- Light: under its budget, and nothing in anyone's way (only the projector's
-- console is solid); nothing can be clicked (a click swings at a rock) or
-- casts a shadow.
local count = 0
for _, d in life.Model:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
		check(
			d.Anchored and not d.CanQuery and not d.CanTouch and not d.CastShadow,
			d.Name .. " can be clicked, touched or casts a shadow"
		)
		check(not d.CanCollide or d.Name == "ProjectorConsole", d.Name .. " is in the way")
	end
end
-- (The species not on the stage are set aside, built but not drawn.)
local built = count
for _, holo in life.Holograms do
	if holo.Model.Parent == nil then
		built += #holo.Group.Parts
	end
end
check(count <= 200 and built <= 320, "Too many parts: " .. count .. " drawn, " .. built .. " built")

-- The hologram: every kaiju, species and element both changing each time.
local seen = {}
for i, entry in Life.Kaiju do
	seen[entry.Species .. entry.Element] = true
	local nextOne = Life.Kaiju[i % #Life.Kaiju + 1]
	check(nextOne.Species ~= entry.Species and nextOne.Element ~= entry.Element, "Two kaiju alike in a row")
end
local combos = 0
for _ in seen do
	combos += 1
end
check(combos == 12 and #Life.Kaiju == 12, "Not every species in every element")
local index, flicker = Life.kaijuAt(Life.Hold * 5)
check(index == 6 and flicker == 0, "The sixth kaiju doesn't start flickering in on time")
index, flicker = Life.kaijuAt(Life.Hold * 5 + Life.Flicker + 0.01)
check(index == 6 and flicker == 1, "It's still flickering")
check(Life.kaijuAt(Life.Hold * 12 + 1) == 1, "The hologram doesn't loop")

-- It stands on the stage (the arena's middle, from the server's build),
-- inside it and under the arena's sign, the one shown and no other.
local stage = Life.Stage
local signBottom = 18.4 - 1.7
for t = 0, Life.Hold * 12, 1.7 do
	Life.pose(life, t)
	local entry = Life.Kaiju[(Life.kaijuAt(t))]
	local shownCount = 0
	for species, holo in life.Holograms do
		if holo.Model.Parent ~= nil then
			shownCount += 1
			check(species == entry.Species, "The wrong kaiju is on the stage")
			for _, p in holo.Group.Parts do
				local q = here(p.CFrame.Position)
				check(math.sqrt((q.X - stage.X) ^ 2 + (q.Z - stage.Z) ^ 2) < 11, "The hologram spills off the stage")
				check(q.Y > stage.Y - 0.5 and q.Y < signBottom, "The hologram sinks into the stage or reaches the sign")
			end
		end
	end
	check(shownCount == 1, "Not one kaiju on the stage")
	check(string.upper(entry.Species) == life.PlateName.Text, "Its name isn't over it")
end
local plate = here(life.Plate.CFrame.Position)
check(
	at:VectorToObjectSpace(life.Plate.CFrame.LookVector).Z > 0.99 and plate.Y < signBottom,
	"The name doesn't face the door, or it's in the sign"
)
check(
	life.Prompt and life.Prompt.ActionText ~= "" and life.Prompt.Parent.Name == "ProjectorConsole",
	"The projector's console has no prompt"
)
-- The stage it stands on: the server's arena disc.
do
	local found = false
	for _, d in shelter:GetDescendants() do
		if d:IsA("BasePart") and d.Material == R.Enum.Material.Neon and d.Shape == R.Enum.PartType.Cylinder then
			local q = here(d.CFrame.Position)
			if math.abs(q.X - stage.X) < 0.01 and math.abs(q.Z - stage.Z) < 0.01 and math.abs(q.Y - stage.Y) < 0.1 then
				found = true
			end
		end
	end
	check(found, "The hologram isn't over the arena's stage")
end

-- The gallery: a gem in each of the server's cases, staying inside it as it
-- turns and bobs; each plinth's odds, facing the hall, adding up to every
-- gem mined; sparkles round the Legendary.
local cases = {}
local gallery = shelter:FindFirstChild("GemGallery")
check(gallery, "No Gem Gallery")
for i = 1, 5 do
	local plinth = gallery:FindFirstChild("GalleryPlinth" .. i)
	check(plinth, "Gallery plinth " .. i .. " missing")
	cases[i] = here(plinth.CFrame.Position)
end
local odds = Life.odds()
local total = 0
for i, entry in odds do
	total += entry.Percent
	check(
		math.abs(entry.Percent - GemRoller.MiningWeights[i]) < 1e-9,
		"The " .. entry.Tier .. " plaque's odds are wrong"
	)
end
check(math.abs(total - 100) < 1e-9 and #odds == 5, "The gallery's odds don't add up")
for t = 0, 30, 0.9 do
	Life.pose(life, t)
	for i, group in life.Gems do
		for _, p in group.Parts do
			local q = here(p.CFrame.Position)
			check(math.abs(q.X - cases[i].X) < 1.25 and math.abs(q.Z - cases[i].Z) < 1.25, "A gem out of its case")
			check(q.Y > 4.5 and q.Y < 8, "A gem out of its case (height)")
		end
	end
end
for i, entry in odds do
	local plaque = life.Model:FindFirstChild("Odds" .. entry.Tier, true)
	check(plaque, "No odds on the " .. entry.Tier .. " plinth")
	local q = here(plaque.CFrame.Position)
	local toward = (Life.Gallery.Middle - q) * Vector3.new(1, 0, 1)
	check(
		at:VectorToObjectSpace(plaque.CFrame.LookVector):Dot(toward.Unit) > 0.95,
		"The " .. entry.Tier .. " odds face away from the hall"
	)
	check(
		math.abs(q.X - cases[i].X) < 2 and math.abs(q.Z - cases[i].Z) < 2,
		"The " .. entry.Tier .. " odds aren't on its plinth"
	)
	local sparkles = life.Gems[i].Parts[#life.Gems[i].Parts]:FindFirstChildOfClass("ParticleEmitter")
	check((sparkles ~= nil) == (entry.Tier == "Legendary"), "Sparkles on the wrong gem")
end

-- The garden's fireflies hang over the Moon Garden.
do
	local garden = shelter:FindFirstChild("MoonGarden")
	local flies = life.Model:FindFirstChild("Fireflies")
	check(garden and flies, "No garden or no fireflies")
	local q = here(flies.CFrame.Position)
	local benches = 0
	for _, d in garden:GetDescendants() do
		if d:IsA("Seat") then
			benches += 1
			local b = here(d.CFrame.Position)
			check(math.abs(math.sqrt((b.X - q.X) ^ 2 + (b.Z - q.Z) ^ 2) - 11.5) < 0.1, "A bench away from the garden")
		end
	end
	check(benches == 4, "The garden doesn't have four benches")
end

-- The drones: in the hall, under the bunting and over everyone's heads,
-- clear of the tree, the arena's sign, the lamps and each other, gliding
-- (never jumping).
local crown = Vector3.new(Life.Garden.X, Life.Garden.Y + 13.2, Life.Garden.Z)
local last = {}
for t = 0, 240, 0.25 do
	local spots = {}
	for k = 1, 3 do
		local q = Life.droneAt(k, t).Position
		spots[k] = q
		check(math.abs(q.X) < 78 and q.Z > -10 and q.Z < 56, "A drone leaves the hall")
		check(q.Y > 18 and q.Y < 23, "A drone flies too low or into the bunting")
		check((q - crown).Magnitude > 5, "A drone flies into the tree")
		check(not (math.abs(q.X) < 10 and math.abs(q.Z - 37.5) < 3), "A drone flies into the arena's sign")
		for _, s in { -1, 1 } do
			check((q - Vector3.new(s * 14, 28, 18)).Magnitude > 5, "A drone flies into a lamp")
		end
		if last[k] then
			check((q - last[k]).Magnitude < 2, "A drone jumps")
		end
		last[k] = q
	end
	for a = 1, 3 do
		for b = a + 1, 3 do
			check((spots[a] - spots[b]).Magnitude > 4, "Two drones collide")
		end
	end
end

print(
	"PASS: "
		.. checks
		.. " Shelter life checks ("
		.. count
		.. " parts drawn, "
		.. built
		.. " built: the hologram, the gallery's gems and odds, the garden, the drones)"
)
