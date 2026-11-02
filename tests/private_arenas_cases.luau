-- lune run tests/private_arenas_cases.luau <root>
-- Server.PrivateArenas: a Training session's own copy of the Arena, far from
-- everyone else's, the scenery only, kept for reuse.
local fs, luau, roblox, process = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox"), require("@lune/process")
local ROOT = process.args[1] or "."
local R = roblox
local checks = 0
local function check(ok, message)
	checks += 1
	if not ok then
		error("FAIL: " .. message, 2)
	end
end

local workspace = R.Instance.new("Folder")
local replicated = R.Instance.new("Folder")
local landmarks = R.Instance.new("Folder")
landmarks.Name = "Landmarks"
landmarks.Parent = replicated
local FLOOR = R.Vector3.new(600, 0.7, 0)
landmarks:SetAttribute("ArenaFloor", FLOOR)
-- The Arena: floor, a wall, a vendor (a prompt), its keeper, a spawn pad and a script.
local arena = R.Instance.new("Folder")
arena.Name = "CombatArena"
arena.Parent = workspace
local function part(name, at, parent)
	local p = R.Instance.new("Part")
	p.Name = name
	p.Size = R.Vector3.new(4, 1, 4)
	p.CFrame = R.CFrame.new(at)
	p.Parent = parent or arena
	return p
end
part("Floor", FLOOR)
part("Wall", FLOOR + R.Vector3.new(30, 5, 0))
local stall = part("Stall", FLOOR + R.Vector3.new(0, 1, -6))
R.Instance.new("ProximityPrompt").Parent = stall
local keeper = R.Instance.new("Model")
keeper.Name = "Keeper"
R.Instance.new("Humanoid").Parent = keeper
part("Torso", FLOOR, keeper)
keeper.Parent = arena
local pad = R.Instance.new("SpawnLocation")
pad.Name = "Pad"
pad.Parent = arena
R.Instance.new("Script").Parent = arena

local tagged = {}
local env = setmetatable({
	Instance = R.Instance, Vector3 = R.Vector3, CFrame = R.CFrame,
	workspace = workspace,
	warn = function(...) local t = {} for _, v in { ... } do table.insert(t, tostring(v)) end error(table.concat(t, " ")) end,
	game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then return replicated end
		if name == "CollectionService" then
			return {
				GetTags = function(_, d) return tagged[d.Name] or {} end,
				RemoveTag = function(_, d, tag) tagged[d.Name] = nil end,
			}
		end
		return { PlayerRemoving = { Connect = function() end } }
	end },
}, { __index = _G })
local PrivateArenas = luau.load(fs.readFile(ROOT .. "/src/server/Systems/PrivateArenas.luau"), { debugName = "PrivateArenas", environment = env })()

local function player(id)
	local attrs = {}
	return { UserId = id, SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
end
local a, b, c = player(1), player(2), player(3)

local ca = PrivateArenas.claim(a)
check(typeof(ca) == "Vector3" and a:GetAttribute("ArenaCenter") == ca, "No arena of their own")
check((ca - FLOOR).Magnitude > 1000, "Their arena is near everyone else's")
local copy = PrivateArenas.of(a)
check(copy ~= nil and copy.Parent and copy.Parent.Name == "PrivateArenas", "The copy isn't under workspace.PrivateArenas")
local floor = copy:FindFirstChild("Floor")
check(floor and (floor.CFrame.Position - ca).Magnitude < 1e-3, "The copy's floor isn't at its centre")
check(copy:FindFirstChild("Wall") and (copy.Wall.CFrame.Position - (ca + R.Vector3.new(30, 5, 0))).Magnitude < 1e-3, "The copy's scenery moved out of shape")
for _, d in copy:GetDescendants() do
	check(not d:IsA("ProximityPrompt") and not d:IsA("SpawnLocation") and not d:IsA("Script") and not d:IsA("Humanoid"), "The copy kept a " .. d.ClassName)
end
check(copy:FindFirstChild("Keeper") == nil, "The vendor's keeper came along")
check((arena:FindFirstChild("Floor").CFrame.Position - FLOOR).Magnitude < 1e-3 and arena:FindFirstChild("Pad"), "The Arena itself changed")

local cb = PrivateArenas.claim(b)
check(cb ~= ca and (cb - ca).Magnitude >= PrivateArenas.Gap - 1, "Two players share an arena")
check(PrivateArenas.claim(a) == ca, "Asking again moved them")

PrivateArenas.release(a)
check(a:GetAttribute("ArenaCenter") == nil and PrivateArenas.of(a) == nil, "Still theirs after leaving")
local cc = PrivateArenas.claim(c)
check(cc == ca, "A spare wasn't reused")
check(cc ~= cb, "Reused one already taken")
PrivateArenas.release(b)
PrivateArenas.release(c)
PrivateArenas.release(c) -- (twice is harmless)

print(string.format("PASS: %d private arena checks (one each, far apart, scenery only, reused)", checks))
