-- The Store's displays (Client StoreDisplays) on Roblox instances (lune's
-- roblox library): the stands round the Saga Shelter's Store, what each
-- shows and when, and how a preview is set on its stand. It lines up with
-- the Shelter the server builds (OutpostWorld): nothing in a wall, the
-- counter, a crew member or anyone's way, every item standing on its stand
-- facing the hall. Run by tests/run_store_displays.py.
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
	typeof = typeof,
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
local Store = load("StoreDisplays")
local Cosmetics = load("Cosmetics")

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
local Rules =
	luau.load(fs.readFile(ROOT .. "/src/shared/Outpost.luau"), { debugName = "Outpost", environment = worldEnv })()
World.Rules = Rules
local quarry = CFrame.new(40, 0, 7000)
local site = World.build(quarry, R.Instance.new("Folder"))
-- (The client mounts it in the Shelter's frame, as OutpostScene does: the
-- quarry's, lifted onto the Shelter's legs.)
local at = quarry * CFrame.new(0, Rules.ShelterLift, 0)
local shelter = site.Model:FindFirstChild("Shelter", true)
check(shelter, "No Shelter")
local function here(p: Vector3): Vector3
	return at:PointToObjectSpace(p)
end
-- A part's box, in the Shelter's frame (axis-aligned round its corners).
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
local function overlaps(aLow, aHigh, bLow, bHigh, gap)
	gap = gap or 0
	return aLow.X < bHigh.X - gap
		and aHigh.X > bLow.X + gap
		and aLow.Y < bHigh.Y - gap
		and aHigh.Y > bLow.Y + gap
		and aLow.Z < bHigh.Z - gap
		and aHigh.Z > bLow.Z + gap
end
-- Everything solid in the Shelter round the Store (not the floor).
local solids = {}
for _, d in shelter:GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide then
		local low, high = box(d)
		if high.Y > 1 and low.X < -50 and high.Z > -20 and low.Z < 34 then
			table.insert(solids, { d.Name, low, high })
		end
	end
end
check(#solids >= 3, "The Store's counter and walls weren't found")

-- What the Store sells, and what each stand shows.
local kinds = { Helmet = 3, Skin = 3, Pick = 3, Suit = 2 }
local count = {}
for _, stand in Store.Stands do
	count[stand.Kind] = (count[stand.Kind] or 0) + 1
	check(stand.Slot >= 1 and stand.Slot <= stand.Slots and stand.Slots == kinds[stand.Kind], "A stand out of its row")
end
for kind, n in kinds do
	check(count[kind] == n, "Not " .. n .. " " .. kind .. " stands")
	local list = Store.onSale(kind)
	check(#list >= n, "Too few " .. kind .. "s on sale for its stands")
	for _, id in list do
		local cosmetic = Cosmetics.get(id)
		check(
			cosmetic and cosmetic.Kind == kind and cosmetic.Robux and not cosmetic.Exclusive,
			id .. " isn't sold in the Store"
		)
	end
	local all = 0
	for _, id in Cosmetics.ofKind(kind) do
		local cosmetic = Cosmetics.get(id)
		if cosmetic.Robux and not cosmetic.Exclusive then
			all += 1
		end
	end
	check(all == #list, "Something of " .. kind .. " on sale is never shown")
	-- Every one on sale comes round, within a turn per stand-load.
	local seen = {}
	for turn = 0, math.ceil(#list / n) do
		local shownNow = {}
		for _, stand in Store.Stands do
			if stand.Kind == kind then
				local id = Store.showing(stand, turn * Store.Every + 1)
				check(not shownNow[id], "Two " .. kind .. " stands show " .. id .. " at once")
				shownNow[id] = true
				seen[id] = true
			end
		end
	end
	for _, id in list do
		check(seen[id], id .. " never comes round")
	end
end
-- A stand keeps what it shows for its whole turn, then moves on.
do
	local stand = Store.Stands[1]
	local first = Store.showing(stand, 0)
	check(Store.showing(stand, Store.Every - 0.01) == first, "A stand changed in the middle of its turn")
	check(Store.showing(stand, Store.Every) ~= first, "A stand didn't move on")
	check(Store.showing(stand, 12345.6) == Store.showing(stand, 12345.6), "Not the same for everyone")
end

-- Stand-ins for the Shop's previews: the mannequin's frame faces -Z, and,
-- as on the server, its parts sit wherever its pivot was (here, high up).
local function preview(kind: string): Instance
	local folder = R.Instance.new("Folder")
	local function add(name, size, cf)
		local p = R.Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(3, 5000, -2) * cf
		p.CanCollide = true
		p.CastShadow = true
		p.Parent = folder
	end
	if kind == "Suit" then
		add("Torso", Vector3.new(2, 2.4, 1.2), CFrame.new(0, 1.2, 0))
		add("Legs", Vector3.new(2, 2, 1), CFrame.new(0, -1, 0))
		add("Arms", Vector3.new(4.2, 0.9, 0.9), CFrame.new(0, 1.9, 0))
		add("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 3, 0))
		add("Cape", Vector3.new(2.2, 3, 0.3), CFrame.new(0, 0.8, 1.4))
		add("Nose", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 3, -0.8))
	elseif kind == "Helmet" then
		add("Shell", Vector3.new(1.4, 1.5, 1.45), CFrame.new(0, 2.4, 0.05))
		add("Horn", Vector3.new(1.9, 0.3, 0.3), CFrame.new(0, 3.1, 0.2))
		add("Nose", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 2.3, -0.8))
	elseif kind == "Skin" then
		local hold = CFrame.new(1.8, 0.8, -0.3) * CFrame.Angles(math.rad(-12), 0, math.rad(-12))
		add("Blade", Vector3.new(0.32, 2.3, 0.12), hold * CFrame.new(0, 0.9, 0))
		add("Guard", Vector3.new(1.1, 0.2, 0.3), hold * CFrame.new(0, -0.3, 0))
		add("Grip", Vector3.new(0.2, 0.7, 0.2), hold * CFrame.new(0, -0.75, 0))
		add("Nose", Vector3.new(0.2, 0.2, 0.2), hold * CFrame.new(0, -0.3, -0.25))
	else
		local lean = CFrame.Angles(0, 0, math.rad(-30))
		add("Handle", Vector3.new(0.24, 2.5, 0.24), lean * CFrame.new(0, -0.2, 0))
		add("Head", Vector3.new(3, 0.4, 0.4), lean * CFrame.new(0, 1.1, 0))
		add("Nose", Vector3.new(0.3, 0.3, 0.3), lean * CFrame.new(0, 1.1, -0.3))
	end
	folder:SetAttribute("Parts", #folder:GetChildren())
	return folder
end

local displays = Store.build(at)
-- The stands themselves: light, nothing in anyone's way, nothing that can
-- be clicked (a click swings at a rock) or casts a shadow.
local standParts = 0
local function quiet(p)
	return p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow
end
for _, d in displays.Model:GetDescendants() do
	if d:IsA("BasePart") then
		standParts += 1
		check(quiet(d), d.Name .. " can be bumped, clicked or casts a shadow")
	end
end
check(standParts <= 60, "The stands are too many parts: " .. standParts)

-- Every stand dressed: each thing on its stand, facing the hall, at its
-- kind's size, out of the wall, the counter and the crew's way, at every
-- turn of the turntables.
local crew = {}
for _, spot in site.Crew do
	table.insert(crew, here(spot.CFrame.Position))
end
local WALL = -83.4
for i, shown in displays.Stands do
	local spec = shown.Spec
	local list = Store.onSale(spec.Kind)
	local id = list[spec.Slot]
	Store.dress(displays, i, id, preview(spec.Kind))
	check(#shown.Parts == #preview(spec.Kind):GetChildren(), spec.Kind .. " stand lost parts")
	local cosmetic = Cosmetics.get(id)
	check(
		shown.Name.Text == string.upper(cosmetic.Name) and shown.Price.Text == "R$ " .. cosmetic.Robux,
		"Its plate is wrong"
	)
	local plate = shown.Holder:FindFirstChild("Plate")
	check(at:VectorToObjectSpace(plate.CFrame.LookVector).X > 0.99, "A plate doesn't face the hall")
	local foot = spec.At.Position
	for step = 0, (if spec.Turn then 23 else 0) do
		Store.pose(displays, step * (math.pi * 2 / 24) / (spec.Turn or 1))
		local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, p in shown.Parts do
			check(quiet(p), "A display can be bumped, clicked or casts a shadow")
			local a, b = box(p)
			low = Vector3.new(math.min(low.X, a.X), math.min(low.Y, a.Y), math.min(low.Z, a.Z))
			high = Vector3.new(math.max(high.X, b.X), math.max(high.Y, b.Y), math.max(high.Z, b.Z))
			check(a.X > WALL - 0.05, spec.Kind .. " goes into the back wall")
			for _, solid in solids do
				check(
					not overlaps(a, b, solid[2], solid[3], 0.02),
					spec.Kind .. " " .. spec.Slot .. " is in the " .. solid[1]
				)
			end
			for _, c in crew do
				local q = Vector3.new((a.X + b.X) / 2 - c.X, 0, (a.Z + b.Z) / 2 - c.Z)
				check(q.Magnitude > 2.4, spec.Kind .. " " .. spec.Slot .. " is in a crew member")
			end
		end
		-- (standing on its stand: hung ones round their middle)
		if spec.Hung then
			check(math.abs((low.Y + high.Y) / 2 - foot.Y) < 0.6, "A hung " .. spec.Kind .. " isn't on its hook")
		else
			check(
				math.abs(low.Y - foot.Y) < 0.6,
				spec.Kind .. " doesn't stand on its stand: " .. low.Y .. " vs " .. foot.Y
			)
		end
		check(low.Y >= 0.86 - 0.05 and high.Y < 14.5, spec.Kind .. " goes through the floor or the booth's roof")
		check(low.X > -84 and high.X < -56 and low.Z > -13 and high.Z < 25, spec.Kind .. " strays from the Store")
	end
	-- Its size: the kind's height (a suit life size, never over 6.5).
	Store.pose(displays, 0)
	local low, high = math.huge, -math.huge
	for _, p in shown.Parts do
		local a, b = box(p)
		low, high = math.min(low, a.Y), math.max(high, b.Y)
	end
	if spec.Height and not spec.Hung then
		check(math.abs((high - low) - spec.Height) < 0.15, spec.Kind .. " isn't its height: " .. (high - low))
	elseif not spec.Height then
		check(high - low <= 6.55 and high - low > 4, "A suit isn't life size: " .. (high - low))
	end
	-- Facing the hall: its front (the nose) toward it (turntables at rest).
	if not spec.Turn then
		local nose
		for k, p in shown.Parts do
			if p.Name == "Nose" then
				nose = here(p.CFrame.Position)
			end
		end
		local mid = here((displays.At * spec.At).Position)
		check(nose and nose.X > mid.X, spec.Kind .. " faces the wall")
	end
	-- Dressed again, the old one goes.
	Store.dress(displays, i, list[spec.Slot + 1] or id, preview(spec.Kind))
	local inHolder = 0
	for _, d in shown.Holder:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "Plate" then
			inHolder += 1
		end
	end
	check(inHolder == #shown.Parts, spec.Kind .. " kept the last one's parts")
end
-- The picks and suits, turning, never meet each other.
Store.pose(displays, 0)
for t = 0, 60, 0.7 do
	Store.pose(displays, t)
	for i, a in displays.Stands do
		for j, b in displays.Stands do
			if i < j and (a.Spec.Turn or b.Spec.Turn) then
				for _, p in a.Parts do
					local pa, pb = box(p)
					for _, q in b.Parts do
						local qa, qb = box(q)
						check(not overlaps(pa, pb, qa, qb, 0.02), a.Spec.Kind .. " and " .. b.Spec.Kind .. " meet")
					end
				end
			end
		end
	end
end
-- (A preview's offsets: a suit's preview the server put a long way off
-- still lands on its turntable.)
do
	local stand
	for _, s in Store.Stands do
		if s.Kind == "Suit" then
			stand = s
		end
	end
	local parts = preview("Suit"):GetChildren()
	local cframes, sizes = {}, {}
	for k, p in parts do
		cframes[k] = CFrame.new(0, -9000, 400) * p.CFrame
		sizes[k] = p.Size
	end
	local rest, scale = Store.fit(cframes, sizes, stand)
	check(scale == 1, "A suit isn't life size")
	local low = math.huge
	for k, cf in rest do
		low = math.min(low, cf.Position.Y - sizes[k].Y / 2)
	end
	check(math.abs(low) < 0.01, "A far-off preview doesn't land on its stand")
end

print(
	"PASS: "
		.. checks
		.. " Store display checks ("
		.. standParts
		.. " stand parts; 3 helmets, 3 weapon skins, 3 picks and 2 suits, every one on sale coming round)"
)
