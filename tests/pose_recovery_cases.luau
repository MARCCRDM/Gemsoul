-- lune run tests/pose_recovery_cases.luau <repo>
-- No body is left frozen part-way through a move: the real BodyPoses and
-- RivalPose on the body every player has (FighterRig), swinging a pick
-- (the Outpost's "Mine": arm overhead, then down).
--   * your own body is posed however far off the camera is (the menu's
--     orbit round the moon base, an arena drop's flight): a swing begun
--     near it and finished with the camera away still ends standing (it
--     loaded in stuck in the wind-up, pick overhead);
--   * anyone else's body that leaves the range mid-swing goes straight back
--     to rest, its walk and idle no longer held off, and picks up again
--     when it's back in range;
--   * the Arena rival and dungeon fighters the same;
--   * a body whose posing fails stands at rest, reported once.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3
local ROOT = process.args[1] or "."

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local RivalPose = luau.load(fs.readFile(ROOT .. "/src/shared/RivalPose.luau"), {
	debugName = "RivalPose",
	environment = setmetatable({ CFrame = CFrame, Vector3 = Vector3, Instance = Instance }, { __index = _G }),
})()
local FighterRig = luau.load(fs.readFile(ROOT .. "/src/server/Systems/FighterRig.luau"), {
	debugName = "FighterRig",
	environment = setmetatable({
		game = {
			GetService = function()
				return {}
			end,
		},
		Instance = Instance,
		CFrame = CFrame,
		Vector3 = Vector3,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
	}, { __index = _G }),
})()

-- The world: bodies stand in it, the Arena rival in its Enemies folder.
local world = Instance.new("Folder")
local enemies = Instance.new("Folder")
enemies.Name = "Enemies"
enemies.Parent = world
-- (Lune hands out a new wrapper for an instance each time it's looked up,
-- and the poses are kept per body: the folder hands back the same ones.)
local fighters = {}
local enemiesFolder = {
	GetChildren = function()
		return fighters
	end,
}
local function body(x: number, parent: Instance?)
	local model = FighterRig.build()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth, humanoid.Health = 100, 100
	model.HumanoidRootPart.CFrame = CFrame.new(x, 0, 0)
	model.HumanoidRootPart.Position = Vector3.new(x, 0, 0) -- (lune keeps the two apart)
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			d.Transform = CFrame.identity -- (no default in lune)
		end
	end
	model.Parent = parent or world
	return model
end

-- How far its most bent joint is from rest (radians).
local function bend(model): number
	local most = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local rest = d:GetAttribute("RestPose")
			if typeof(rest) == "CFrame" then
				local _, angle = (rest:Inverse() * d.C0):ToAxisAngle()
				most = math.max(most, math.abs(angle))
			end
		end
	end
	return most
end
local function shoulderBend(model): number
	local motor = model.RightUpperArm.RightShoulder
	local rest = motor:GetAttribute("RestPose")
	if typeof(rest) ~= "CFrame" then
		return 0
	end
	local _, angle = (rest:Inverse() * motor.C0):ToAxisAngle()
	return math.abs(angle)
end
-- A pick swing (as OutpostServer sets it): wind-up from `at` - 0.12.
local function swing(model, at: number)
	model:SetAttribute("ActionKind", "Mine")
	model:SetAttribute("ActionStart", at - 0.12)
	model:SetAttribute("ActionAt", at + 0.05)
end

-- Players, the camera and the clock.
local function player(name, x)
	local attributes = {}
	local p = { Name = name, UserId = #name }
	function p:GetAttribute(key)
		return attributes[key]
	end
	function p:SetAttribute(key, value)
		attributes[key] = value
	end
	function p:GetAttributeChangedSignal()
		return { Connect = function() end }
	end
	p.Character = body(x)
	return p
end
local me = player("Me", 0)
local them = player("Them", 30)
local Players = {
	LocalPlayer = me,
	PlayerAdded = { Connect = function() end },
	GetPlayers = function()
		return { me, them }
	end,
	GetPlayerByUserId = function()
		return nil
	end,
}
local now = 0
local camera = { CFrame = CFrame.new(0, 10, 20) }
local NEAR, FAR = CFrame.new(0, 10, 20), CFrame.new(0, 342, 1200) -- (the menu orbit's sort of distance)
local warnings = {}

-- RivalPose as BodyPoses sees it: the real one, made to fail on demand.
local failing = {}
local Posing = setmetatable({
	update = function(model, ...)
		if failing[model] then
			error("pose broke")
		end
		return RivalPose.update(model, ...)
	end,
}, { __index = RivalPose })
local BodyPoses = luau.load(fs.readFile(ROOT .. "/src/client/Modules/BodyPoses.luau"), {
	debugName = "BodyPoses",
	environment = setmetatable({
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return Players
				elseif name == "ReplicatedStorage" then
					return { Shared = { RivalPose = "RivalPose", Matchmaking = "Matchmaking" } }
				end
				return { PreSimulation = { Connect = function() end } }
			end,
		},
		require = function(module)
			if module == "RivalPose" then
				return Posing
			end
			return {
				versus = function()
					return false
				end,
				ownsRival = function()
					return false
				end,
			}
		end,
		workspace = {
			CurrentCamera = camera,
			GetServerTimeNow = function()
				return now
			end,
			FindFirstChild = function(_, name)
				return if name == "Enemies" then enemiesFolder else nil
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
		warn = function(message)
			table.insert(warnings, message)
		end,
		Enum = roblox.Enum,
	}, { __index = _G }),
})()
local function frames(to: number)
	while now < to - 1e-9 do
		now += 1 / 60
		BodyPoses.step(1 / 60)
		RivalPose.holdGuards()
	end
end

-- 1. Your own swing, the camera called away mid-wind-up (to the menu) and
-- kept there: the swing still plays out and the body ends standing.
local mine = me.Character
frames(0.5)
check(bend(mine) < 0.02, "your body doesn't start at rest")
swing(mine, 1)
frames(0.96)
check(shoulderBend(mine) > 1, "your pick swing's wind-up isn't posed (arm overhead)")
camera.CFrame = FAR
local mid = shoulderBend(mine)
frames(1.0)
check(shoulderBend(mine) ~= mid, "your body stopped being posed when the camera went far off")
frames(3)
check(bend(mine) < 0.02, string.format("your body stayed bent (%.2f rad) after its swing, the camera away", bend(mine)))
camera.CFrame = NEAR

-- 2. Someone else's swing, leaving the range part-way through the wind-up:
-- back to rest at once, the animations no longer held off, and posed again
-- (from rest) when they're back in range.
local theirs = them.Character
frames(3.5)
swing(theirs, 4)
frames(3.96)
check(shoulderBend(theirs) > 1, "their wind-up isn't posed")
camera.CFrame = CFrame.new(30, 10, 600)
frames(3.98)
check(bend(theirs) < 1e-3, "their body was left frozen mid-swing out of range")
local shoulder = theirs.RightUpperArm.RightShoulder
local walkPose = CFrame.Angles(0.4, 0, 0)
shoulder.Transform = walkPose
RivalPose.holdGuards()
check(
	(shoulder.Transform.LookVector - walkPose.LookVector).Magnitude < 1e-4,
	"their walk and idle are still held off out of range"
)
frames(4.5)
check(bend(theirs) < 1e-3, "a body out of range moved")
camera.CFrame = NEAR
swing(theirs, 5)
frames(4.96)
check(shoulderBend(theirs) > 1, "their next swing isn't posed back in range")
frames(6)
check(bend(theirs) < 0.02, "their body didn't stand again after the swing")
RivalPose.relax(theirs) -- (whatever's left of the ease back)
check(bend(theirs) < 1e-3 and RivalPose.relax(theirs) == false, "a body at rest was moved by relax")

-- 3. The Arena rival (the server marks it Posed) the same.
local rival = body(-20, enemies)
table.insert(fighters, rival)
rival:SetAttribute("Posed", true)
frames(6.5)
swing(rival, 7)
frames(6.96)
check(shoulderBend(rival) > 1, "the rival's swing isn't posed")
camera.CFrame = CFrame.new(-20, 10, 600)
frames(6.98)
check(bend(rival) < 1e-3, "the rival was left frozen mid-swing out of range")
camera.CFrame = NEAR

-- 4. Posing that fails part-way: the body stands at rest, reported once.
frames(7.5)
swing(theirs, 8)
frames(7.96)
check(shoulderBend(theirs) > 1, "the swing before the failure isn't posed")
failing[theirs] = true
frames(8.5)
check(bend(theirs) < 1e-3, "a body whose posing failed stayed frozen mid-swing")
check(
	#warnings == 1 and string.find(warnings[1], "pose broke", 1, true) ~= nil,
	"a failing body isn't reported exactly once"
)
failing[theirs] = nil

-- 5. Your body is posed with the camera far off from the start (the menu).
camera.CFrame = FAR
swing(mine, 9)
frames(8.96)
check(shoulderBend(mine) > 1, "your body isn't posed while the camera's far off")
frames(10)
check(bend(mine) < 0.02, "your body didn't stand again with the camera far off")

print(string.format("PASS: %d pose recovery checks (no body left frozen mid-swing)", checks))
