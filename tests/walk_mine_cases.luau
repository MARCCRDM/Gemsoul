-- Walking into a rock mines it (Shared.WalkMine), as a click or a tap does:
-- heading into it and up against it, it is; standing still, walking past,
-- backing away, too far off or on top of it, it isn't; a turned and a long
-- rock alike. Then that the Outpost (on foot and in a mech), the Rift's
-- healing crystals and an expedition's wall all use it, paced by the swing,
-- and that an empty pick doesn't throw PROBE-7 at you for walking.
-- Run by tests/run_walk_mine.py.
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

local WalkMine = luau.load(fs.readFile(ROOT .. "/src/shared/WalkMine.luau"), {
	debugName = "WalkMine",
	environment = setmetatable({ Vector3 = Vector3 }, { __index = _G }),
})()

check(WalkMine.Touch > 1 and WalkMine.Touch < 4, "Up against a rock from too near or too far: " .. WalkMine.Touch)
check(WalkMine.Facing > 0 and WalkMine.Facing < 0.7, "Too strict or too loose about heading into it")
check(WalkMine.Every > 0 and WalkMine.Every <= 0.15, "Looks too seldom to feel like a tap")
check(WalkMine.Shove > WalkMine.Every and WalkMine.Push > 0 and WalkMine.Push < 1, "A mech's shove")

-- A Crystal Boulder's body (6 wide) at the origin; you at waist height.
local rock = CFrame.new(0, 2.5, 0)
local size = Vector3.new(6, 5, 5.4)
local function at(x, z)
	return Vector3.new(x, 2.8, z)
end
local north = Vector3.new(0, 0, -1)

-- Walking straight at it from 10 studs off: not yet, then yes once up
-- against it (its side is 2.7 away from its middle that way).
local first
for step = 0, 80 do
	local z = 12 - step * 0.1
	if WalkMine.against(at(0, z), north, rock, size) then
		first = z
		break
	end
end
check(first ~= nil, "Walked into a rock and it never counted")
check(first <= 2.7 + WalkMine.Touch + 1e-6 and first > 2.7 + WalkMine.Touch - 0.2, "Counted from " .. tostring(first))
-- Pressed against it (a body's half-width off its side).
check(WalkMine.against(at(0, 3.7), north, rock, size), "Pressed against it and it didn't count")
-- Standing still against it: no.
check(not WalkMine.against(at(0, 3.7), Vector3.zero, rock, size), "Standing still against it counted")
check(not WalkMine.against(at(0, 3.7), north * 0.05, rock, size), "A stick barely nudged counted")
-- Backing away from it, or walking along its side: no.
check(not WalkMine.against(at(0, 3.7), -north, rock, size), "Backing away from it counted")
check(not WalkMine.against(at(0, 3.7), Vector3.new(1, 0, 0), rock, size), "Walking along its side counted")
-- Glancing into it (about 60 degrees off): yes; skimming past (75): no.
local function turned(degrees)
	local a = math.rad(degrees)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end
check(WalkMine.against(at(0, 3.7), turned(60), rock, size), "Walking into it at an angle didn't count")
check(not WalkMine.against(at(0, 3.7), turned(75), rock, size), "Skimming past it counted")
-- How fast you're going doesn't matter, only where: a full stick and a half one.
check(WalkMine.against(at(0, 3.7), north * 16, rock, size), "Running into it didn't count")
check(WalkMine.against(at(0, 3.7), north * 0.5, rock, size), "Walking slowly into it didn't count")
-- Too far off: no; a bigger reach (say a mech's) and yes.
check(not WalkMine.against(at(0, 8), north, rock, size), "Counted from across the way")
check(WalkMine.against(at(0, 8), north, rock, size, 6), "A longer reach didn't count")
-- A corner: heading for it from off its diagonal.
check(WalkMine.against(at(4.5, 4.5), Vector3.new(-1, 0, -1), rock, size), "Walking into its corner didn't count")
check(not WalkMine.against(at(4.5, 4.5), Vector3.new(1, 0, -1), rock, size), "Walking past its corner counted")
-- On top of it: walking about up there isn't mining it.
check(not WalkMine.against(Vector3.new(0, 8, 0), north, rock, size), "Walking on top of it counted")
check(not WalkMine.against(Vector3.new(0, 8, 3.5), north, rock, size), "Walking off its top counted")
-- Inside it (a mech's cockpit over a pebble): yes.
check(WalkMine.against(at(0, 0.5), north, rock, size), "Inside its footprint didn't count")
-- Its height doesn't matter for where you stand beside it: a tall monolith.
local monolith = CFrame.new(0, 6, 0)
local tall = Vector3.new(8.5, 12, 7.6)
check(WalkMine.against(Vector3.new(0, 2.8, 5.5), north, monolith, tall), "Walking into a monolith didn't count")
-- A turned rock: measured from its sides, not its middle.
local yawed = CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(45), 0)
local long = Vector3.new(12, 5, 2)
local tip = yawed:PointToWorldSpace(Vector3.new(6, 0, 0))
local nearTip = tip + (tip - Vector3.new(0, 2.5, 0)).Unit * 1.5
local toTip = (tip - nearTip) * Vector3.new(1, 0, 1)
check(WalkMine.against(Vector3.new(nearTip.X, 2.8, nearTip.Z), toTip, yawed, long), "Walking into a turned rock's end didn't count")
local broad = yawed:PointToWorldSpace(Vector3.new(0, 0, 1 + 1.5))
local inward = (Vector3.new(0, 2.5, 0) - broad) * Vector3.new(1, 0, 1)
check(
	WalkMine.against(Vector3.new(broad.X, 2.8, broad.Z), inward, yawed, long),
	"Walking into a turned rock's side didn't count"
)
check(
	not WalkMine.against(Vector3.new(broad.X, 2.8, broad.Z), -inward, yawed, long),
	"Walking away from a turned rock's side counted"
)
-- (as an axis-aligned box it would be 6 across: 4 off its middle isn't touching)
local beside = Vector3.new(4.2, 2.8, -4.2)
check(
	not WalkMine.against(beside, Vector3.new(-1, 0, 1), yawed, Vector3.new(2, 5, 2)),
	"A small turned rock counted from off its side"
)

-- Where it's used ------------------------------------------------------------------------------

local outpost = fs.readFile(ROOT .. "/src/client/Modules/OutpostScene.luau")
check(outpost:find("local WalkMine = require(ReplicatedStorage.Shared.WalkMine)", 1, true) ~= nil, "The Outpost doesn't walk-mine")
check(outpost:find("function OutpostScene.swing(nodeId: number?, walked: boolean?)", 1, true) ~= nil, "No walked swing")
-- On foot: your Humanoid's MoveDirection (keys, thumbstick, pad alike) into the rock's body.
check(
	outpost:find("local heading = humanoid.MoveDirection", 1, true)
		and outpost:find("WalkMine.against(root.Position, heading, body.CFrame, body.Size)", 1, true),
	"On foot, walking into a rock isn't checked"
)
-- In a mech: the rock its hull is shoving.
check(outpost:find("VehicleDrive.shoving()", 1, true) ~= nil, "In a mech, shoving a rock isn't mining it")
-- Paced: looked for every WalkMine.Every, never sooner than the next swing,
-- through the same swing a tap makes (with `walked`).
check(
	outpost:find("walkLook = now + WalkMine.Every", 1, true)
		and outpost:find("now < nextSwing", 1, true)
		and outpost:find('OutpostScene.swing(rock:GetAttribute("NodeId"), true)', 1, true),
	"Walking into a rock doesn't swing the way a tap does"
)
-- Not at a popped rock; not at a critter (that's for a click); and an empty
-- pick says nothing while you walk about (no PROBE-7 popping up).
check(outpost:find('model:GetAttribute("Popped") == nil', 1, true) ~= nil, "Walk-mines a popped rock")
check(outpost:find("if mech or walked then nil else nearestCritter()", 1, true) ~= nil, "Walking into a rock bonks a critter instead")
check(
	outpost:find('if walked and not model:GetAttribute("HealRock") and state and ChargeMeter.read(state.Picks, state.SurveyAt) <= 0 then', 1, true)
		~= nil,
	"Walking into rocks with an empty pick opens PROBE-7"
)
-- The Rift's healing crystals are OutpostNodes too: walk into one and it heals.
local rift = fs.readFile(ROOT .. "/src/server/Systems/RiftServer.luau")
check(rift:find('CollectionService:AddTag(model, "OutpostNode")', 1, true) ~= nil, "The Rift's crystals aren't walk-minable")

local drive = fs.readFile(ROOT .. "/src/client/Modules/VehicleDrive.luau")
check(
	drive:find("if blockedBy and throttle >= WalkMine.Push then rockOf(d.Hit) else nil", 1, true)
		and drive:find("not (rock and d.Spec.Mine)", 1, true),
	"A mech pushes through a rock it's mining"
)

local mine = fs.readFile(ROOT .. "/src/client/Modules/MineScene.luau")
check(
	mine:find("WalkMine.against(root.Position, humanoid.MoveDirection, body.CFrame, body.Size)", 1, true)
		and mine:find("MineScene.swing(index, true)", 1, true)
		and mine:find("now - lastSwing < COOLDOWN", 1, true),
	"An expedition's rocks aren't walk-minable"
)
check(mine:find("if not walked then\n\t\t\tshowBanner(\"OUT OF SWINGS\"", 1, true) ~= nil, "OUT OF SWINGS flashes as you walk about")

print(string.format("PASS: %d walk-mining checks (into a rock, not past, away, still or on top; a turned rock; the Outpost on foot and in a mech, the Rift, expeditions)", checks))
