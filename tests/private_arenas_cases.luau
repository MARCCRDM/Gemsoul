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
	Instance = R.Instance, Vector3 = R.Vector3, CFrame = R.CFrame, Color3 = R.Color3, Enum = R.Enum,
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

-- Arena Row (Shared.Outpost.Settlement.Stages): open rings on the ground,
-- built for good, taken first, the Intro Ring then the Grand Arena; fenced
-- while a fight's on; then a far copy as before.
local groundA, groundB = R.Vector3.new(-150, 0, 7245), R.Vector3.new(0, 0, 7290)
local sa = PrivateArenas.stage("IntroRing", groundA, 43)
local sb = PrivateArenas.stage("GrandArena", groundB, 43)
check((sa - (groundA + R.Vector3.new(0, FLOOR.Y, 0))).Magnitude < 1e-3 and (sb - (groundB + R.Vector3.new(0, FLOOR.Y, 0))).Magnitude < 1e-3, "A stage isn't where it was put")
local ring = workspace.PrivateArenas:FindFirstChild("IntroRing")
check(ring and ring:GetAttribute("Center") == sa and ring:GetAttribute("Stage") == true, "The Intro Ring isn't a stage with its centre")
local ringFloor = ring:FindFirstChild("Floor")
check(ringFloor and ringFloor.CanCollide and math.abs(ringFloor.CFrame.Position.Y + ringFloor.Size.X / 2 - sa.Y) < 1e-3, "The Intro Ring's floor top isn't at its centre")
check(((ringFloor.CFrame.Position - sa) * R.Vector3.new(1, 0, 1)).Magnitude < 1e-3 and ringFloor.Size.Y / 2 >= 30, "The Intro Ring's floor isn't round its centre, the Arena's width")
-- (open: nothing standing on it higher than the lamp posts round it, none on the floor)
for _, p in ring:GetDescendants() do
	if p:IsA("BasePart") and p.Parent == ring then
		check(p.CFrame.Position.Y - sa.Y < 6, "Something tall at the Intro Ring: " .. p.Name)
		local flat = ((p.CFrame.Position - sa) * R.Vector3.new(1, 0, 1)).Magnitude
		check(not (p.Name == "Post" and flat < 31), "A post on the fight floor")
	end
end
for _, d in ring:GetDescendants() do
	check(not d:IsA("ProximityPrompt") and not d:IsA("SpawnLocation") and not d:IsA("Script"), "A stage kept a " .. d.ClassName)
end
local fence = ring:FindFirstChild("StageFence")
check(fence and #fence:GetChildren() == 24, "No fence round the Intro Ring")
local function closed(stage)
	for _, p in stage.StageFence:GetChildren() do
		if not p.CanCollide then
			return false
		end
	end
	return true
end
for _, p in fence:GetChildren() do
	check(math.abs(((p.CFrame.Position - sa) * R.Vector3.new(1, 0, 1)).Magnitude - 43) < 0.1, "A barrier panel off its ring")
	-- (seen through, solid to walk into, no stop to a camera or a blow)
	check(p.Material == R.Enum.Material.ForceField and p.Transparency < 1 and p.CanCollide and not p.CanQuery, "A barrier panel isn't a see-through wall")
	check(p.CFrame.Position.Y - p.Size.Y / 2 <= sa.Y and p.CFrame.Position.Y + p.Size.Y / 2 >= sa.Y + 10, "A barrier panel doesn't stand from the floor up")
end
check(closed(ring), "The Intro Ring's barrier isn't up with no fight on")
local d, e, f, g = player(4), player(5), player(6), player(7)
check(PrivateArenas.claim(d) == sa and d:GetAttribute("ArenaCenter") == sa, "A fight didn't take the Intro Ring")
check(closed(ring) and ring:GetAttribute("Owner") == 4, "The Intro Ring's open with a fight on")
check(PrivateArenas.claim(e) == sb, "The next fight didn't take the Grand Arena")
local cf = PrivateArenas.claim(f)
check(typeof(cf) == "Vector3" and cf ~= sa and cf ~= sb and (cf - FLOOR).Magnitude > 1000, "With Arena Row full, no far copy")
PrivateArenas.release(d)
check(ring.Parent ~= nil and ring:GetAttribute("Owner") == nil and closed(ring), "The Intro Ring wasn't left standing, its barrier up")
check(PrivateArenas.claim(g) == sa, "The Intro Ring wasn't taken again")
for _, who in { e, f, g } do
	PrivateArenas.release(who)
end
-- A practice bout asks for its rings first (ArenaSessions.PracticeRings).
local pr = player(30)
check(PrivateArenas.claim(pr, { "GrandArena", "IntroRing" }) == sb, "A fight didn't take the ring it asked for first")
local pr2 = player(31)
check(PrivateArenas.claim(pr2, { "GrandArena" }) == sa, "With its ring taken, a fight didn't take another")
PrivateArenas.release(pr)
PrivateArenas.release(pr2)
-- A duel: one ring for both fighters, the one it asks for first; free again
-- only once they're both out of it; nil when every ring's taken.
local h, i, j, k = player(8), player(9), player(10), player(11)
check(PrivateArenas.claimStage({ h, i }, "GrandArena") == sb, "A duel didn't take the Grand Arena")
check(h:GetAttribute("ArenaCenter") == sb and i:GetAttribute("ArenaCenter") == sb, "A duel's fighters don't both have the ring")
check(PrivateArenas.claimStage({ j, k }, "GrandArena") == sa, "A second duel didn't take the other ring")
check(PrivateArenas.claimStage({ player(12), player(13) }, "GrandArena") == nil, "A duel took a ring that's taken")
PrivateArenas.release(h)
check(PrivateArenas.claimStage({ player(14), player(15) }) == nil, "A ring freed with a fighter still in it")
PrivateArenas.release(i)
local again = player(16)
check(PrivateArenas.claimStage({ again }, "GrandArena") == sb, "The Grand Arena wasn't free once both were out")
for _, who in { j, k, again } do
	PrivateArenas.release(who)
end

print(string.format("PASS: %d private arena checks (one each, far apart, scenery only, reused; Arena Row: open rings on the ground, a see-through barrier always up)", checks))
