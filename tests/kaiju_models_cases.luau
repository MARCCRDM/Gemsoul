-- lune run tests/kaiju_models_cases.luau <repo>
-- Kaiju models (Shared.KaijuModels, and Shared.KaijuShapes for the
-- roster's 28): every kind builds in every element with a root on the
-- ground (a flyer hovering over it), its joints marked for
-- CreatureAnimation (and a motion for each), its element's colour on it, a
-- hide of its own, and a part budget.
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

local loaded = {}
local env
local function load(name)
	if not loaded[name] then
		loaded[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env })()
	end
	return loaded[name]
end
env = setmetatable({
	Instance = roblox.Instance,
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	script = { Parent = setmetatable({}, { __index = function(_, name) return name end }) },
	require = function(name) return load(name) end,
}, { __index = _G })
local KaijuModels = load("KaijuModels")
local KaijuShapes = load("KaijuShapes")
local Roster = load("KaijuRoster")
local Motion = load("CreatureMotion")

local SPECIES = { "Bulwark", "Razorback", "Carapace", "Scythe" }
for _, kind in Roster.Order do
	table.insert(SPECIES, kind)
end
local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }
local KINDS = { Body = true, Stride = true, Arm = true, Jaw = true, Tail = true, Head = true, Wing = true }
local FIRST = { Bulwark = true, Razorback = true, Carapace = true, Scythe = true }
local LEGLESS = { Longcoil = true } -- a serpent on its coils
local BUDGET = 90 -- parts in one kaiju (up to 3 per player, plus the wild ones)

check(#SPECIES == 32, "Not 32 kinds")
for _, kind in Roster.Order do
	local hide = KaijuShapes.Hides[kind]
	check(hide and hide[1] and hide[2], kind .. ": no hide")
end

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
		local hover = model:GetAttribute("KaijuHover") or 0
		check(hover == (KaijuShapes.Hover[species] or 0), name .. ": hovers wrong")

		local parts, low, high, left, right, kinds, plates, hides = 0, math.huge, -math.huge, math.huge, -math.huge, {}, 0, 0
		local palette = KaijuModels.Palettes[element]
		local hide = KaijuShapes.Hides[species]
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				check(not d.CanCollide and not d.CanTouch, name .. ": " .. d.Name .. " collides")
				if d ~= root then
					local at = d.CFrame.Position
					local reach = d.CFrame:VectorToWorldSpace(d.Size / 2)
					local extent = math.abs(d.CFrame.RightVector.Y) * d.Size.X / 2
						+ math.abs(d.CFrame.UpVector.Y) * d.Size.Y / 2
						+ math.abs(d.CFrame.LookVector.Y) * d.Size.Z / 2
					local _ = reach
					low = math.min(low, at.Y - extent)
					high = math.max(high, at.Y + extent)
					left, right = math.min(left, at.X - d.Size.X / 2), math.max(right, at.X + d.Size.X / 2)
					local joined = d:FindFirstChildOfClass("WeldConstraint") or d:FindFirstChildOfClass("Motor6D")
					check(joined, name .. ": " .. d.Name .. " isn't attached")
				end
				if d.Color == palette.Plate then
					plates += 1
				end
				if hide and (d.Color == hide[1] or d.Color == hide[2]) then
					hides += 1
				end
			elseif d:IsA("Motor6D") then
				local kind = d:GetAttribute("CreatureMotion")
				check(KINDS[kind], name .. ": a joint moves as " .. tostring(kind))
				check(d:GetAttribute("CreatureRest") == d.C0, name .. ": a joint's rest isn't its pose")
				check(d.Part0 and d.Part1 and d.Parent == d.Part1, name .. ": a loose joint")
				-- its two halves meet: the joint holds its part where it was built
				local seat = (d.Part0.CFrame * d.C0).Position - (d.Part1.CFrame * d.C1).Position
				check(seat.Magnitude < 1e-3, name .. ": " .. d.Part1.Name .. "'s joint pulls it out of place")
				kinds[kind] = (kinds[kind] or 0) + 1
			end
		end
		check(parts <= BUDGET, string.format("%s: %d parts (budget %d)", name, parts, BUDGET))
		check(plates >= 4, name .. ": too few plates in its element's colour")
		check(not hide or hides >= 8, name .. ": hardly any of its own hide")
		-- its feet are on the ground: the lowest part sits where the root's
		-- hip height puts it (less a flyer's hover)
		local ground = root.CFrame.Position.Y - root.Size.Y / 2 - (hip - hover)
		check(math.abs(low - ground) < 0.35, string.format("%s: feet at %.2f, ground at %.2f", name, low, ground))
		check(high - low > 2.4 and high - low < 6, string.format("%s: an odd height (%.2f)", name, high - low))
		check(kinds.Body == 1, name .. ": not one Body joint")
		check(kinds.Jaw, name .. ": no Jaw joint")
		check(LEGLESS[species] or kinds.Stride, name .. ": no legs")
		check((kinds.Stride or 0) % 2 == 0, name .. ": an odd number of legs")
		if FIRST[species] then
			check(kinds.Tail, name .. ": no Tail joint")
		end
		if hover > 0 then
			check((kinds.Wing or 0) >= 2 and (kinds.Wing or 0) % 2 == 0, name .. ": hovers without a pair of wings")
		end
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
-- The roster's own silhouettes: the tall ones tall, the low ones low.
check(shapes.Lankshade.Height > 3.8 and shapes.Bladebrow.Height > 4.5, "The tall kinds aren't tall")
check(shapes.Shellfire.Height < 3 and squat(shapes.Thornlob) > 1.3, "The low kinds aren't low")
check(squat(shapes.Stormwing) > 2, "The glider's wings aren't spread")

-- A dark hide is lifted in a portrait; a pale one is left as it is.
do
	local dark = KaijuModels.forPortrait(KaijuModels.build("Emberjaw", "Fire"))
	local pale = KaijuModels.forPortrait(KaijuModels.build("Moonmoth", "Fire"))
	local function has(model, color)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Color == color then
				return true
			end
		end
		return false
	end
	check(not has(dark, KaijuShapes.Hides.Emberjaw[1]), "A dark hide isn't lifted in a portrait")
	check(has(pale, KaijuShapes.Hides.Moonmoth[1]), "A pale hide is changed in a portrait")
end

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

-- Fighting: each kind's whole body winds up, strikes and settles (CreatureMotion.fight).
local function pose(species, kind, at, now, extra)
	local a = { Kind = kind, Start = 10, At = at, Side = 1 }
	for key, value in extra or {} do
		a[key] = value
	end
	return Motion.fight(species, a, now)
end
local still = Motion.fight("Bulwark", {}, 5)
for field, value in still do
	check(value == 0, "A kaiju out of a fight holds a pose: " .. field)
end
-- A stomp: it rears up (arms high) by the blow, then slams down.
local wind = pose("Bulwark", "Heavy", 10.8, 10.79)
local slam = pose("Bulwark", "Heavy", 10.8, 10.9)
check(wind.Pitch > 0.25 and wind.Arm > 1.5, "The brute doesn't rear up for its stomp")
check(slam.Pitch < -0.15 and slam.Lift < 0, "The brute's stomp doesn't slam down")
check(pose("Bulwark", "Heavy", 10.8, 10.4).Pitch < wind.Pitch, "A wind-up doesn't build")
local rested = pose("Bulwark", "Heavy", 10.8, 10.8 + Motion.Strike + Motion.Settle + 0.01)
for field, value in rested do
	check(value == 0 or field == "ArmSide", "A blow doesn't settle back: " .. field)
end
-- A swipe uses one arm, on its side; the other side mirrors it.
local swipe = pose("Bulwark", "Light", 10.3, 10.4)
check(swipe.ArmSide == 1 and swipe.Arm > 1, "A claw swipe isn't one arm")
local mirrored = Motion.fight("Bulwark", { Kind = "Light", Start = 10, At = 10.3, Side = -1 }, 10.4)
check(math.abs(mirrored.Yaw + swipe.Yaw) < 1e-9 and mirrored.ArmSide == -1, "The other side doesn't mirror it")
local _, _, _ = Motion.apply(swipe, "Arm", 1, 0, 0, 0)
check(
	select(1, Motion.apply(swipe, "Arm", 1, 0, 0, 0)) > select(1, Motion.apply(swipe, "Arm", -1, 0, 0, 0)),
	"Both arms swipe"
)
-- A bite: jaws wide on the wind-up, snapped shut on the blow; a counter bites the same way.
local open = pose("Razorback", "Light", 10.24, 10.23)
local snap = pose("Razorback", "Light", 10.24, 10.34)
check(open.Jaw > 0.5 and snap.Jaw < 0.1 and snap.Push > 0.4, "The runner doesn't bite")
check(pose("Razorback", "Punish", 10.24, 10.23).Jaw == open.Jaw, "A counter isn't a bite")
-- A tail lash spins it round; an E rears up to roar.
check(math.abs(pose("Razorback", "Heavy", 10.6, 10.7).Yaw) > 1.2, "The tail lash doesn't spin")
check(
	pose("Carapace", "Bolt", 10.7, 10.69).Jaw > 0.5 and pose("Carapace", "Nova", 10.7, 10.69).Pitch > 0.2,
	"No roar for an E"
)
-- Its guard: the shell sinks into itself; the brute raises its arms; a blow on it jolts it.
local shell = Motion.fight("Carapace", { GuardUntil = 12 }, 11)
check(shell.Lift < -0.3, "The shell doesn't tuck in")
check(Motion.fight("Bulwark", { GuardUntil = 12 }, 11).Arm > 1, "The brute doesn't raise its guard")
check(Motion.fight("Carapace", { GuardUntil = 12 }, 12.5).Lift == 0, "A guard that ran out stays up")
check(
	Motion.fight("Carapace", { GuardUntil = 12, BlockedAt = 10.95 }, 11).Push < shell.Push,
	"No jolt on a blocked blow"
)
-- A hop lifts and leans into it; a stagger throws it back; a hit makes it flinch.
local hop = pose("Razorback", "Dodge", 10, 10.17)
check(hop.Lift > 0.4 and hop.Roll < -0.3, "A hop doesn't hop")
check(pose("Razorback", "Dodge", 10, 10.5).Lift == 0, "A hop doesn't land")
check(pose("Bulwark", "Stagger", 10, 10.1).Pitch > 0.25, "A stagger doesn't reel")
check(Motion.fight("Bulwark", { HurtAt = 10 }, 10.05).Pitch > 0, "No flinch")
-- On the joints: the trunk rears and moves; the legs stay upright under it.
local x, _, _, lift = Motion.apply(wind, "Body", 1, 0, 0, 0)
check(x == wind.Pitch and lift == wind.Lift, "The trunk doesn't take the pose")
check(Motion.apply(wind, "Stride", 1, 0, 0, 0) == -wind.Pitch, "The legs rear up with the trunk")
check(Motion.apply(open, "Jaw", 1, 0, 0, 0) == -open.Jaw, "The jaw doesn't open")
-- Eased: a pose comes on fast but not at once.
local eased = Motion.blend(Motion.rest(), wind, 0.5)
check(math.abs(eased.Pitch - wind.Pitch / 2) < 1e-9, "Not eased")
eased = Motion.blend(nil, wind, 0.5)
check(eased.Pitch == wind.Pitch and eased ~= wind, "A first pose isn't its own")
for species in Motion.Fight do
	for i = 0, 60 do
		for _, kind in { "Light", "Heavy", "Punish", "Lunge", "Bolt", "Nova", "Dodge", "Stagger" } do
			local p = pose(species, kind, 10.5, 10 + i / 50, { GuardUntil = 11, HurtAt = 10.3 })
			for field, value in p do
				check(value == value and math.abs(value) < 3, species .. " " .. kind .. ": a wild " .. field)
			end
		end
	end
end

-- The roster's kinds fight in poses of their own: every blow, a cast and a
-- guard; a flyer's wings beat on a blow and a many-headed kind's heads snap
-- in on a bite.
for _, kind in Roster.Order do
	local keys = Motion.Fight[kind]
	check(keys, kind .. ": no fight poses")
	for _, blow in { "Light", "Heavy", "Lunge", "Cast" } do
		check(keys[blow] and keys[blow].Wind and keys[blow].Hit, kind .. ": no " .. blow)
	end
	check(keys.Guard, kind .. ": no guard")
end
check(Motion.Fight.Dreadmaw.Light.Wind.Jaw > Motion.Fight.Razorback.Light.Wind.Jaw, "Dreadmaw's jaw isn't its own")
do
	local beat = pose("Stormwing", "Heavy", 10.6, 10.59)
	local x, y, z = Motion.apply(beat, "Wing", 1, 0, 0, 0)
	local _, _, z2 = Motion.apply(beat, "Wing", -1, 0, 0, 0)
	check(x == 0 and y == 0 and z > 0.3 and z2 < -0.3, "A flyer's wings don't beat on a blow")
	local bite = pose("Triskull", "Light", 10.3, 10.29)
	check(Motion.apply(bite, "Head", 1, 0, 0, 0) < -0.2, "The heads don't snap in on a bite")
end

-- A wild one's day (KaijuMood): it settles into each over a moment; head
-- down sniffing, lower resting and lower still asleep, rearing to roar and
-- settling back; and no mood in a fight.
local function moodPose(mood: string, since: number, kind: string?)
	local a = { Mood = mood, MoodAt = 100, Kind = kind, Start = kind and 100, At = kind and 100.3 }
	return Motion.fight("Razorback", a, 100 + since)
end
check(moodPose("Sniff", 2).Pitch < -0.15, "Sniffing doesn't put its head down")
local resting, sleeping = moodPose("Rest", 2).Lift, moodPose("Sleep", 2).Lift
check(resting < -0.3 and sleeping < resting, "Resting and sleeping aren't lower")
check(math.abs(moodPose("Rest", 0.05).Lift) < math.abs(moodPose("Rest", 2).Lift) / 3, "It drops to rest at once")
check(moodPose("Roar", 0.6).Jaw > 0.6 and moodPose("Roar", 0.6).Pitch > 0.2, "A roar doesn't rear up, jaws wide")
-- Held by a tame (Bound): crouched low, twisting and snapping against it.
check(moodPose("Bound", 1.5).Lift < -0.15, "A held kaiju doesn't crouch")
do
	local twist = {}
	for i = 0, 8 do
		twist[i] = moodPose("Bound", 1 + i * 0.07).Yaw
	end
	local most, least = math.max(table.unpack(twist)), math.min(table.unpack(twist))
	check(most - least > 0.1, "A held kaiju doesn't struggle")
end
check(math.abs(moodPose("Roar", 2).Jaw) < 1e-6, "A roar doesn't settle")
local looks = {}
for t = 0, 6, 0.5 do
	table.insert(looks, moodPose("Look", t).Yaw)
end
check(math.max(table.unpack(looks)) > 0.2 and math.min(table.unpack(looks)) < -0.2, "Looking about doesn't turn")
check(moodPose("Sleep", 2, "Light").Lift > -0.2, "Its mood shows in a fight")
check(math.abs(Motion.fight("Razorback", { Mood = "Nope", MoodAt = 100 }, 102).Lift) < 1e-9, "An unknown mood poses")

print(
	string.format(
		"PASS: %d kaiju model checks (32 kinds x 4 elements, joints, ground, budget, motions, fight poses, moods)",
		checks
	)
)
