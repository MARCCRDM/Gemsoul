-- lune run tests/kaiju_models_cases.luau <repo>
-- Kaiju models (Shared.KaijuModels): every species builds in every element
-- with a root on the ground, its joints marked for CreatureAnimation (and a
-- motion for each), plates in its element's colour, and a part budget.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local env = setmetatable({
	Instance = roblox.Instance,
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
}, { __index = _G })
local function load(name)
	return luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env })()
end
local KaijuModels = load("KaijuModels")
local Motion = load("CreatureMotion")

local SPECIES = { "Bulwark", "Razorback", "Carapace" }
local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }
local KINDS = { Stride = true, Arm = true, Jaw = true, Tail = true }
local BUDGET = 90 -- parts in one kaiju (up to 3 per player, plus the wild ones)

local shapes = {}
for _, species in SPECIES do
	for _, element in ELEMENTS do
		local name = element .. " " .. species
		local model = KaijuModels.build(species, element)
		check(model:GetAttribute("KaijuSpecies") == species, name .. ": no species")
		check(model:GetAttribute("KaijuElement") == element, name .. ": no element")
		check(model:GetAttribute("CreatureShape") == "Kaiju", name .. ": CreatureAnimation won't find it")
		local root = model:FindFirstChild("HumanoidRootPart")
		check(root and model.PrimaryPart == root and root.Transparency == 1, name .. ": no hidden root")
		local hip = model:GetAttribute("KaijuHipHeight")
		check(type(hip) == "number" and hip > 0, name .. ": no hip height")

		local parts, low, high, left, right, kinds, plates = 0, math.huge, -math.huge, math.huge, -math.huge, {}, 0
		local palette = KaijuModels.Palettes[element]
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				check(not d.CanCollide and not d.CanTouch, name .. ": " .. d.Name .. " collides")
				if d ~= root then
					local at = d.CFrame.Position
					low = math.min(low, at.Y - d.Size.Y / 2)
					high = math.max(high, at.Y + d.Size.Y / 2)
					left, right = math.min(left, at.X - d.Size.X / 2), math.max(right, at.X + d.Size.X / 2)
					local joined = d:FindFirstChildOfClass("WeldConstraint") or d:FindFirstChildOfClass("Motor6D")
					check(joined, name .. ": " .. d.Name .. " isn't attached")
				end
				if d.Color == palette.Plate then
					plates += 1
				end
			elseif d:IsA("Motor6D") then
				local kind = d:GetAttribute("CreatureMotion")
				check(KINDS[kind], name .. ": a joint moves as " .. tostring(kind))
				check(d:GetAttribute("CreatureRest") == d.C0, name .. ": a joint's rest isn't its pose")
				check(d.Part0 and d.Part1 and d.Parent == d.Part1, name .. ": a loose joint")
				kinds[kind] = (kinds[kind] or 0) + 1
			end
		end
		check(parts <= BUDGET, string.format("%s: %d parts (budget %d)", name, parts, BUDGET))
		check(plates >= 4, name .. ": too few plates in its element's colour")
		-- its feet are on the ground: the lowest part sits where the root's hip height puts it
		local ground = root.CFrame.Position.Y - root.Size.Y / 2 - hip
		check(math.abs(low - ground) < 0.35, string.format("%s: feet at %.2f, ground at %.2f", name, low, ground))
		check(high - low > 2.4 and high - low < 6, name .. ": an odd height")
		for _, kind in { "Stride", "Jaw", "Tail" } do
			check(kinds[kind], name .. ": no " .. kind .. " joint")
		end
		check((kinds.Stride or 0) % 2 == 0, name .. ": an odd number of legs")
		shapes[species] = shapes[species] or { Width = right - left, Height = high - low }
	end
end
-- Three different silhouettes: the brute the tallest, the shell low and wide
check(shapes.Razorback.Height < shapes.Bulwark.Height, "The runner stands as tall as the brute")
check(shapes.Carapace.Height < shapes.Bulwark.Height, "The shell stands as tall as the brute")
local function squat(s)
	return s.Width / s.Height
end
check(
	squat(shapes.Carapace) > squat(shapes.Bulwark) and squat(shapes.Carapace) > squat(shapes.Razorback),
	"The shell isn't the squattest"
)

-- The motions: still at rest, moving when walking, a blow swings the jaw and arms
for kind in KINDS do
	local x0, y0, z0 = Motion.angles(kind, 0, 0, 0, 1)
	local x1, y1, z1 = Motion.angles(kind, 1, 1.2, 1, 1)
	check(x1 ~= x0 or y1 ~= y0 or z1 ~= z0, kind .. " doesn't move")
end
check(Motion.angles("Stride", 5, 0, 0, 1) == 0, "Legs step when it stands still")
check(
	math.abs(Motion.angles("Stride", 5, 1, 1, 1) + Motion.angles("Stride", 5, 1, 1, -1)) < 1e-9,
	"Its legs don't step in turn"
)
check(Motion.angles("Arm", 0.2, 0, 0, 1, 0) > Motion.angles("Arm", 0.2, 0, 0, 1), "A blow doesn't swing its arms")
check(Motion.angles("Jaw", 0.2, 0, 0, 1, 0) < Motion.angles("Jaw", 0.2, 0, 0, 1), "A blow doesn't open its jaw")

print(string.format("PASS: %d kaiju model checks (3 species x 4 elements, joints, ground, budget, motions)", checks))
