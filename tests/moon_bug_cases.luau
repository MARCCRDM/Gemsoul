-- lune run tests/moon_bug_cases.luau <repo>
-- The Outpost's moon bugs (Duelist.creatureBody): dozens can be about at
-- once, coming through rifts every few seconds, so each brainrot creature
-- is built light: no armour, no details too small to see at its size
-- (BrainrotSkins.thin), no lights, and only its bigger parts cast shadows.
-- Its face stays, and nothing left hangs loose.
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
local Skins =
	luau.load(read("src/server/Systems/BrainrotSkins.luau"), { debugName = "BrainrotSkins", environment = env })()
local rules =
	read("src/shared/DungeonRules.luau"):gsub("local ElementMatchup = require%b()", "local ElementMatchup = {}")
local Rules = luau.load(rules, { debugName = "DungeonRules", environment = env })()

-- Duelist's own body and creatureBody, cut out of its source (the rest of
-- Duelist needs the whole server).
local duelist = read("src/server/Systems/Duelist.luau")
local from = assert(string.find(duelist, "local BODY = {", 1, true), "Duelist has no BODY")
local _, to = string.find(duelist, "function Duelist.creatureBody.-\nend\n", from)
assert(to, "Duelist has no creatureBody")
env.BrainrotSkins = Skins
-- (creatureBody dresses a boss as itself first: BrainrotBosses, on these Skins.)
env.BrainrotBosses = luau.load(
	read("src/server/Systems/BrainrotBosses.luau"):gsub("local Skins = require%b()", "local Skins = BrainrotSkins"),
	{ debugName = "BrainrotBosses", environment = env }
)()
local Duelist = luau.load(
	"local Duelist = {}\n" .. string.sub(duelist, from, to) .. "Duelist._buildBody = buildBody\nreturn Duelist\n",
	{ debugName = "Duelist", environment = env }
)()

local BUDGET = 180 -- parts in one moon bug (it was up to 214)
local SHADOWS = 70 -- of them casting shadows (it was every one)
-- BrainrotSkins' armour plates (each with its trim, socket and rivets).
local ARMOUR = {
	"ArmoredCarapace",
	"CranialArmor",
	"FlankGuard",
	"TailGreave",
	"AegisPlate",
	"HelmetCrown",
	"ChestArmor",
	"Gauntlet",
	"Greave",
	"ElementShield",
}
local FACE = { "Eye", "Pupil", "Iris", "Brow", "Smile", "Mouth", "Nose", "Fang", "Tooth" }
local function faceOf(rig): { [string]: number }
	local face = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			for _, word in FACE do
				if string.find(d.Name, word, 1, true) then
					face[d.Name] = (face[d.Name] or 0) + 1
					break
				end
			end
		end
	end
	return face
end
local function partsOf(rig): number
	local n = 0
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local accent = roblox.Color3.fromRGB(255, 120, 40)
for _, spec in Rules.Roster do
	local name = spec.Id
	-- The whole creature, as a dungeon dresses it (armour and all).
	local whole = Duelist._buildBody(roblox.Color3.fromRGB(150, 130, 110))
	Skins.apply(whole, spec, accent, false, 1, false)

	local bug = Duelist.creatureBody(spec, accent)
	local parts, shadows, lights = 0, 0, 0
	for _, d in bug:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.CastShadow and d.Transparency < 1 then
				shadows += 1
			end
			for _, plate in ARMOUR do
				check(not string.find(d.Name, plate, 1, true), name .. ": wears armour (" .. d.Name .. ")")
			end
		elseif d:IsA("Light") then
			lights += 1
		elseif d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			-- Nothing left hangs off a part that went.
			check(d.Part0 and d.Part0:IsDescendantOf(bug), name .. ": " .. d.Parent.Name .. " hangs loose")
			check(d.Part1 and d.Part1:IsDescendantOf(bug), name .. ": a joint lost its part")
		end
	end
	check(parts <= BUDGET, string.format("%s: %d parts (budget %d)", name, parts, BUDGET))
	check(parts < partsOf(whole), name .. ": the moon bug is no lighter than the whole creature")
	check(shadows <= SHADOWS, string.format("%s: %d parts cast shadows (budget %d)", name, shadows, SHADOWS))
	check(lights == 0, name .. ": a moon bug carries a light")
	check(bug:GetAttribute("CreatureShape") == spec.Shape, name .. ": CreatureAnimation won't find it")
	check(bug:FindFirstChild("HumanoidRootPart") and bug:FindFirstChildOfClass("Humanoid"), name .. ": no rig")
	-- Its face is all there: every eye, brow, mouth and tooth.
	local face, wholeFace = faceOf(bug), faceOf(whole)
	check(next(wholeFace) ~= nil, name .. ": no face at all")
	for part, count in wholeFace do
		check(face[part] == count, string.format("%s: %s went (%d of %d left)", name, part, face[part] or 0, count))
	end
	print(string.format("  %-10s %3d parts (from %d), %2d casting shadows", name, parts, partsOf(whole), shadows))
end

print(string.format("PASS: %d moon bug checks (budget, shadows, no armour or lights, nothing loose, the face)", checks))
