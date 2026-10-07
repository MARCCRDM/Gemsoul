-- lune run tests/fight_spacing_cases.luau <repo>
-- Nobody jumps in a fight, and bodies keep a body's width apart (so nobody
-- stands on their opponent): Shared.FightSpacing and Server.FighterBodies.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, Vector3 = roblox.Instance, roblox.Vector3
local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local env = setmetatable({ Vector3 = Vector3, Instance = Instance }, { __index = _G })
local FightSpacing =
	luau.load(fs.readFile(ROOT .. "/src/shared/FightSpacing.luau"), { debugName = "FightSpacing", environment = env })()

-- In a fight: an Arena session, a duel (MatchId) or a raid.
local player = Instance.new("Folder")
check(not FightSpacing.inFight(player), "Out of a fight counted as in one")
player:SetAttribute("CombatSession", "Duel")
check(FightSpacing.inFight(player), "A duel didn't count as a fight")
player:SetAttribute("CombatSession", nil)
player:SetAttribute("MatchId", "m1")
check(FightSpacing.inFight(player), "A match didn't count as a fight")

-- The push: none when clear, out to the gap when close, sideways off the top
-- of a body (height ignored), back the way you faced when dead centre.
local gap = 2.6
check(FightSpacing.push(Vector3.new(5, 0, 0), Vector3.zero, gap) == Vector3.zero, "Pushed a body that was clear")
local p = FightSpacing.push(Vector3.new(1, 0, 0), Vector3.zero, gap)
check(math.abs(p.X - 1.6) < 1e-6 and p.Y == 0 and p.Z == 0, "Close body not pushed out to the gap")
local onTop = FightSpacing.push(Vector3.new(0.5, 4.5, 0.2), Vector3.zero, gap)
check(onTop.Y == 0 and onTop.Magnitude > 2, "A body standing on its foe wasn't moved off")
local centre = FightSpacing.push(Vector3.zero, Vector3.zero, gap, Vector3.new(0, 0, -1))
check(math.abs(centre.Z - gap) < 1e-6, "Dead centre didn't step back the way it faced")
-- Gaps: two players about shoulder to shoulder; a big body keeps you further off.
local small = Instance.new("Part")
small.Size = Vector3.new(2, 2, 1)
local big = Instance.new("Part")
big.Size = Vector3.new(8, 8, 8)
check(math.abs(FightSpacing.gap(small) - 2.6) < 1e-6, "Wrong gap between two bodies")
check(FightSpacing.gap(big) > 5, "A big body didn't keep you further off")

-- The server: JumpPower 0 in a fight, back to normal after.
local services = {
	PhysicsService = {
		RegisterCollisionGroup = function() end,
		CollisionGroupSetCollidable = function() end,
	},
	Players = {},
	ReplicatedStorage = { Shared = { FightSpacing = FightSpacing } },
}
local serverEnv = setmetatable({
	game = {
		GetService = function(_, name)
			return services[name]
		end,
	},
	require = function(m)
		return m
	end,
	Instance = Instance,
}, { __index = _G })
local FighterBodies = luau.load(
	fs.readFile(ROOT .. "/src/server/Systems/FighterBodies.luau"),
	{ debugName = "FighterBodies", environment = serverEnv }
)()
local character = Instance.new("Model")
local humanoid = Instance.new("Humanoid")
humanoid.Parent = character
local fighter = {
	Character = character,
	GetAttribute = function(_, name)
		return player:GetAttribute(name)
	end,
}
FighterBodies.applyJump(fighter :: any)
check(humanoid.UseJumpPower and humanoid.JumpPower == 0, "Jumping wasn't turned off in a fight")
player:SetAttribute("MatchId", nil)
FighterBodies.applyJump(fighter :: any)
check(
	humanoid.JumpPower == FighterBodies.JumpPower and humanoid.JumpPower > 0,
	"Jumping wasn't turned back on after the fight"
)
print("PASS: " .. checks .. " fight spacing checks (no jumping in a fight, nobody standing on their foe)")
