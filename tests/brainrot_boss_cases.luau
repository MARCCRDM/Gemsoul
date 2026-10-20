-- lune run tests/brainrot_boss_cases.luau <repo>
-- The dungeons' ten bosses (DungeonRules.Bosses, dressed by BrainrotBosses):
-- the last room's and an open expedition's middle camp are always one of
-- them; each is built light and whole on the combat skeleton, with its
-- heads, wings, tails and knives on CreatureMotion joints.
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
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberRange = roblox.NumberRange,
}, { __index = _G })
local function read(path: string): string
	return fs.readFile(ROOT .. "/" .. path)
end
local function load(path: string, name: string, extra)
	local e = setmetatable(table.clone(env), getmetatable(env))
	for key, value in extra or {} do
		e[key] = value
	end
	return luau.load(read(path), { debugName = name, environment = e })()
end
local Skins = load("src/server/Systems/BrainrotSkins.luau", "BrainrotSkins")
local Bosses = load("src/server/Systems/BrainrotBosses.luau", "BrainrotBosses", {
	script = { Parent = { BrainrotSkins = Skins } },
	require = function(module)
		return module
	end,
})
local rules =
	read("src/shared/DungeonRules.luau"):gsub("local ElementMatchup = require%b()", "local ElementMatchup = {}")
local Rules = luau.load(rules, { debugName = "DungeonRules", environment = env })()
local Motion = load("src/shared/CreatureMotion.luau", "CreatureMotion")
local duelist = read("src/server/Systems/Duelist.luau")
local from = assert(string.find(duelist, "local BODY = {", 1, true), "Duelist has no BODY")
local _, to = string.find(duelist, "\nend\n", (string.find(duelist, "local function buildBody", from, true)), true)
local buildBody = luau.load(string.sub(duelist, from, to) .. "return buildBody\n", { environment = env })()
local maneuvers = {}
for name in string.gmatch(string.match(read("src/shared/CombatTechnology.luau"), "RigManeuvers = (%b{})"), '"(%w+)"') do
	maneuvers[name] = true
end

-- The ten, from the picture (not the teacup ballerina nor the cows): how
-- many heads each has.
local HEADS = {
	TwinCat = 2,
	DragonCroc = 1,
	TwinDuck = 2,
	FrogAvocado = 2,
	Chimpanzini = 3,
	SahurTrio = 3,
	TwinShark = 2,
	TreeTrio = 3,
	Frigo = 2,
	Cappuccino = 1,
}
local BUDGET = 120 -- parts in one boss, its invisible skeleton included
local REACH = 4.6 -- studs out from its root (before it's scaled up)

-- The list -------------------------------------------------------------------------------------------
check(#Rules.Bosses == 10, "Ten bosses")
local weakness = {}
for _, spec in Rules.Roster do
	weakness[spec.Element] = spec.Weakness
end
local seen = { Id = {}, Name = {}, Shape = {} }
for _, spec in Rules.Bosses do
	for key, names in seen do
		check(not names[spec[key]], spec.Id .. ": its " .. key .. " is taken")
		names[spec[key]] = true
	end
	check(HEADS[spec.Shape], spec.Id .. ": not one of the ten")
	check(Bosses.Builders[spec.Shape], spec.Id .. ": nothing builds it")
	check(weakness[spec.Element] == spec.Weakness, spec.Id .. ": weak to the wrong element")
	check(#spec.Moves == 3, spec.Id .. ": three moves")
	for _, move in spec.Moves do
		check(maneuvers[move], spec.Id .. ": no maneuver " .. move)
	end
end
for shape in HEADS do
	check(seen.Shape[shape], shape .. " isn't a boss")
end

-- They're the bosses: the last room's, and the open map's middle camp.
-- (Lune has no Random: a small seeded one with the two calls they make.)
local Random = {}
function Random.new(seed: number)
	local state = seed * 7919 + 1
	local function next01()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextInteger = function(_, low: number, high: number)
			return low + math.floor(next01() * (high - low + 1))
		end,
		NextNumber = function(_, low: number, high: number)
			return low + next01() * (high - low)
		end,
	}
end
local met = {}
for seed = 1, 400 do
	local rooms = Rules.generate(Random.new(seed))
	for _, room in rooms do
		local spec = Rules.specOf(room)
		if room.Boss then
			check(spec == Rules.Bosses[room.Theme] and #room.Foes == 1, "A boss room's foe isn't a boss")
			check(Rules.specOf(room, room.Foes[1]) == spec, "The boss isn't its room's")
			met[spec.Id] = true
		else
			check(spec == Rules.Roster[room.Theme], "A room's fighters aren't the Roster's")
			for _, kind in room.Foes do
				check(Rules.specOf(room, kind) == Rules.Roster[kind], "A room fighter is a boss")
			end
		end
	end
	for _, camp in Rules.generateOpen(Random.new(seed)) do
		local list = if camp.Boss then Rules.Bosses else Rules.Roster
		check(Rules.specOf(camp) == list[camp.Theme] and Rules.specOf(camp) ~= nil, "A camp's foe is from the wrong list")
	end
end
for _, spec in Rules.Bosses do
	check(met[spec.Id], spec.Id .. " never comes up")
end

-- Their bodies ---------------------------------------------------------------------------------------
local accent = roblox.Color3.fromRGB(80, 200, 255)
for _, spec in Rules.Roster do
	check(Bosses.apply(buildBody(roblox.Color3.new(1, 1, 1)), spec, accent, false) == false, spec.Id .. ": dressed as a boss")
end
-- (Turned and moved, as Duelist has it when it dresses one: nothing may
-- be placed in the world's space instead of its bone's.)
local turn = roblox.CFrame.new(40, 6, -25) * roblox.CFrame.Angles(0, 2.2, 0)
-- Where each of its parts sits on its root, built in order.
local function layout(rig): { any }
	local root = rig:FindFirstChild("HumanoidRootPart")
	local list = {}
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(list, { p.Name, root.CFrame:ToObjectSpace(p.CFrame) })
		end
	end
	return list
end
for _, spec in Rules.Bosses do
	local name = spec.Id
	local straight = buildBody(roblox.Color3.new(1, 1, 1))
	Bosses.apply(straight, spec, accent, false)
	local rig = buildBody(roblox.Color3.new(1, 1, 1))
	-- (Lune hands out a new userdata for an instance each time: the
	-- skeleton's parts are marked rather than kept as table keys.)
	local function bone(p): boolean
		return p ~= nil and p:GetAttribute("TestBone") == true
	end
	for _, p in rig:GetChildren() do
		if p:IsA("BasePart") then
			p.CFrame = turn * p.CFrame
			p:SetAttribute("TestBone", true)
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	check(Bosses.apply(rig, spec, accent, false), name .. ": not dressed")
	-- Turned or not, it's the same body.
	local want, got = layout(straight), layout(rig)
	check(#want == #got, name .. ": built differently when turned")
	for i, entry in got do
		local offset = entry[2].Position - want[i][2].Position
		check(entry[1] == want[i][1] and offset.Magnitude < 1e-3, name .. ": " .. entry[1] .. " moves when it's turned")
	end
	check(rig:GetAttribute("CreatureShape") == spec.Shape, name .. ": CreatureAnimation won't find it")
	check(rig:GetAttribute("BrainrotCharacter") == spec.Id, name .. ": no BrainrotCharacter")
	check(rig:GetAttribute("CombatPoseProfile") == spec.PoseProfile, name .. ": wrong pose profile")
	local parts, heads, kinds = 0, {}, {}
	for _, p in rig:GetDescendants() do
		if not p:IsA("BasePart") then
			continue
		end
		parts += 1
		if bone(p) then
			check(p.Transparency == 1, name .. ": its skeleton shows (" .. p.Name .. ")")
			continue
		end
		check(not p.CanCollide and not p.CanTouch and not p.CanQuery and p.Massless, name .. ": " .. p.Name .. " gets in the way")
		local at = root.CFrame:PointToObjectSpace(p.CFrame.Position)
		check(
			math.abs(at.X) <= REACH and math.abs(at.Z) <= REACH and at.Y > -3.6 and at.Y < REACH,
			string.format("%s: %s is off its body (%.1f, %.1f, %.1f)", name, p.Name, at.X, at.Y, at.Z)
		)
		-- Held on a bone: welded, or on a joint that moves it.
		local weld = p:FindFirstChild("CreatureDetail")
		local joint = p:FindFirstChild("CreatureMotion")
		local hold = weld or joint
		check(hold and bone(hold.Part0) and hold.Part1 == p, name .. ": " .. p.Name .. " hangs loose")
		if joint then
			local kind = joint:GetAttribute("CreatureMotion")
			kinds[kind] = true
			check(joint:GetAttribute("CreatureRest") == joint.C0, name .. ": " .. p.Name .. " has no rest pose")
			-- At rest the joint keeps the part where it was built.
			local placed = joint.Part0.CFrame * joint.C0 * joint.C1:Inverse()
			check((placed.Position - p.CFrame.Position).Magnitude < 1e-3, name .. ": " .. p.Name .. " jumps on its joint")
			if kind == "Head" then
				heads[joint:GetAttribute("CreatureSide")] = true
			end
		end
	end
	local count = 0
	for _ in heads do
		count += 1
	end
	check(count == HEADS[spec.Shape], string.format("%s: %d heads that move (it has %d)", name, count, HEADS[spec.Shape]))
	check(parts <= BUDGET, string.format("%s: %d parts (budget %d)", name, parts, BUDGET))
	print(string.format("  %-13s %3d parts, %d head%s", name, parts, count, if count == 1 then "" else "s"))
end

-- How they move --------------------------------------------------------------------------------------
for _, kind in { "Head", "Wing", "Blade" } do
	local moved = false
	for i = 0, 120 do
		local x, y, z = Motion.angles(kind, 100 + i / 30, i / 9, (i % 10) / 10, if i % 2 == 0 then 1 else -1, 100.5)
		check(x == x and y == y and z == z and math.max(math.abs(x), math.abs(y), math.abs(z)) < 2, kind .. ": wild angle")
		moved = moved or math.abs(x) + math.abs(y) + math.abs(z) > 0.05
	end
	check(moved, kind .. " never moves")
	-- A blow shows: the angles differ from the same moment with no blow.
	local a = { Motion.angles(kind, 100.2, 0, 0, 1, nil) }
	local b = { Motion.angles(kind, 100.2, 0, 0, 1, 100) }
	check(math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3]) > 0.2, kind .. ": no reaction to a blow")
end
-- Two heads don't move as one.
local left = { Motion.angles("Head", 101.3, 0, 0, -1) }
local right = { Motion.angles("Head", 101.3, 0, 0, 1) }
check(math.abs(left[2] - right[2]) > 0.05, "Heads look about together")

print(string.format("PASS: %d boss checks (the ten, boss rooms and camps, bodies, heads, motion)", checks))
